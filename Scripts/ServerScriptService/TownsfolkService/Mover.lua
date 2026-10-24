-- TownsfolkService.Mover (Region Foundation Task 5, 2026-10-23; crowd movement Task 5b, owner: "I want the townsfolk
-- pathfinding to be the best you can make it x1000, I don't want them to walk through each other"). ALL townsfolk
-- walking lives here, behind two calls; TownsfolkService calls only WalkTo and Place.
--   * Mover.WalkTo(Rig, TargetCFrame, Opts) -> Handle
--       Walks the rig to TargetCFrame (a standing CFrame: root position + facing). Opts (all optional): Speed (default
--       Humanoid.WalkSpeed), Agent (CreatePath params, default Mover.Agent), OnDone(Result) where Result is
--       "arrived" | "failed" | "cancelled". Handle: {Status = "walking" | Result, Cancel = function(self)}; a newer
--       WalkTo / Place on the same rig cancels the older walk. "failed" leaves the rig standing where it is (the caller
--       decides); an error inside a walk ends it "failed" with the rig held still, upright.
--       Debug fields on the handle: Waypoints (the smoothed path), RawWaypoints (count before smoothing), Radius
--       (agent radius used), Yields, Replans.
--   * Mover.Place(Rig, TargetCFrame): cancels any walk, anchors the root and puts the rig exactly there.
--   * Mover.Handle(Rig) -> the walk in progress (debug), or nil.
--   * Mover.Stats() -> {Walkers, StepMs, MaxStepMs, HeartbeatMs, Ticks, PeakWalkers, Yields, Replans, Sidesteps,
--       Fails, Arrivals, PostWaits, Detours}; Mover.ResetStats(). StepMs = average time of one steering tick (all walkers).
--
-- How a walk works (Task 5b; every number below is a PROPOSAL):
--   1. Path planning: PathfindingService with Mover.Agent (radius 2.5, height 5.5, no jumping or climbing, a
--      waypoint every 4 studs) and Mover.Costs (streets cheapest, grass dearer, water and mud avoided). Labels of
--      PathfindingModifiers the builders add are looked up in the same Costs table. A 5-stud door has no path at
--      radius 2.5, so Mover.NarrowRadii are tried next, both when there is no path and when the path is a long way
--      round (a narrower path 25% shorter wins: people use the door). A path whose segments run through geometry
--      (the navmesh hasn't caught up with a change yet) is refused and asked for again.
--   2. Smoothing: each waypoint the walker can skip safely is dropped: a 1.5-radius spherecast at waist height
--      between the kept points is clear, and a ground ray every 2 studs finds walkable ground within 3 studs of the
--      line, never dearer (Costs) than the ground the path itself used. Open squares become straight lines.
--   3. Steering, 10 Hz on Heartbeat, walking townsfolk only (nothing runs while nobody walks): the desired velocity
--      points at the next waypoint at the walk speed, slowing over the last 4 studs. Every townsperson, player and
--      other character within 10 studs is checked: if the closest approach over the next 1.5 s would be under
--      Clearance, the walker side-steps, passing on the RIGHT by convention when it is head-on (so two walkers never
--      dodge into each other), otherwise away from the side the other is on. Closer than Separation pushes apart, and
--      nobody walks into a body ahead in its lane (it slows to that body's pace, then stops short). The result goes
--      to Humanoid:Move, smoothed, so the facing (AutoRotate) turns smoothly.
--   4. Narrow spots: two walkers blocked head-on (both under 1 stud/s for 0.75 s, facing each other within 4 studs):
--      the one with the lower priority (further from its goal, then the higher Id) steps back and to its right and
--      waits until the other has passed (their distance grows), then carries on.
--   5. Re-planning: Path.Blocked ahead, or a wall appearing between the walker and its next waypoint, re-plans from
--      where it stands. Stuck (under 0.5 studs of progress in 1.5 s, not just queueing behind someone moving): step
--      sideways, then re-plan; the 4th time without real progress in between, the walk ends "failed".
--   6. Posts: a post with someone already on it (within 2 studs) is waited for beside it, then walked onto. When
--      the last stretch to a post (or a stuck walker's way) runs past people standing still, a local route is planned
--      round them (A* on a 1-stud grid; PathfindingService doesn't know about characters).
--   7. Looks: the shared Walk animation (as EnemyService plays it) at a rate matched to the real ground speed
--      (TuningConfig.Locomotion, as LocomotionSync does for players). The facing turns at 360 degrees a second at
--      most (an AlignOrientation, every physics frame); a walker facing away from its way turns before it walks off.
--      On arrival the rig turns to the post's facing over 0.3 s (a turn-around over up to 0.6 s).
--   8. Bodies: the rigs keep colliding (the "Townsfolk" collision group); the server owns their physics.
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local TweenService = game:GetService("TweenService")

local Loco do
	local Ok, Tuning = pcall(require, ReplicatedStorage.Modules.Data.Rensei.TuningConfig)
	Loco = Ok and Tuning.Locomotion or {Min = 0.5, Max = 1.6, Design = {Walk = 12}}
end

local Mover = {}
-- ===== tuning (all PROPOSALS) =====
Mover.Agent = {AgentRadius = 2.5, AgentHeight = 5.5, AgentCanJump = false, AgentCanClimb = false, WaypointSpacing = 4}
Mover.NarrowRadii = {2, 1.5} -- tried in turn when there's no path at the agent's radius (a 5-stud door needs 2)...
Mover.DetourRatio, Mover.DetourSlack = 1.3, 8 -- ...or when its path is longer than this x the straight line + slack
Mover.Costs = { -- material (or PathfindingModifier label) -> cost; anything else costs 1
	Cobblestone = 1, Brick = 1, Concrete = 1, Pavement = 1,
	Ground = 1.5, WoodPlanks = 1.5,
	Grass = 3, LeafyGrass = 3,
	Water = 20, Mud = 20,
}
Mover.Hz = 10 -- steering ticks per second
Mover.SenseRadius = 10 -- bodies closer than this are steered around
Mover.Lookahead = 1.5 -- s: how far ahead closest approaches are predicted
Mover.Clearance = 4 -- closest approach under this -> side-step (an R6 is 4 studs shoulder to shoulder; 3 lets arms pass through)
Mover.Separation = 3 -- closer than this -> pushed apart
Mover.HardGap = 2.8 -- a walker never steps closer to a moving body than this (eased in from 0.4 further out)
Mover.LaneWidth = 3.6 -- a body less than this to the side of the walker's line is "in its lane": it won't walk into it
Mover.StopGap = 2.8 -- ...and stops this far short of it
Mover.ContactGap = 2.4 -- a walker only stops for a body standing still closer than this to its line
Mover.DodgeGain = 1.2 -- side-step strength (x walk speed)
Mover.PushGain = 1.5 -- separation strength (x walk speed)
Mover.Blend = 0.5 -- steering smoothing per tick (0..1, higher = snappier)
Mover.SlowRadius = 4 -- slows down over the last studs to the goal
Mover.MinSpeed = 1.5 -- never slower than this while still walking
Mover.Reach = 2 -- a waypoint counts as reached this close
Mover.ArriveDist = 0.5 -- then the final turn onto the post starts
Mover.TurnTime = 0.3 -- s: the turn to the post's facing on arrival (at least; a big turn goes at ArriveTurnRate)
Mover.ArriveTurnRate = 300 -- degrees a second, average, for the arrival turn
Mover.TurnRate = 360 -- degrees a second at most while walking (a turn-around takes half a second, never a snap)
Mover.WaistHeight = 2.5 -- above the ground, for the smoothing spherecast
Mover.SmoothRadius = 1.5
Mover.GroundStep = 2
Mover.GroundDrop = 3
Mover.SightEvery = 0.5 -- s: how often a walker checks for a new wall before its next waypoint
Mover.SightRange = 12
Mover.StuckWindow = 1.5 -- s
Mover.StuckProgress = 0.5 -- studs in StuckWindow
Mover.MaxReplans = 3 -- stuck re-plans before the walk fails
Mover.ProgressReset = 10 -- studs of real progress forgive earlier stuck events
Mover.MaxPlans = 15 -- re-plans of any kind in one walk before it fails (a runaway guard)
Mover.Sidestep = 2
Mover.LocalReach = 14 -- local routes (round standing bodies) are planned to waypoints this close...
Mover.LocalMargin = 8 -- ...on a 1-stud grid this far around the walker and the waypoint...
Mover.LocalCells = 1600 -- ...of at most this many cells
Mover.BlockedSpeed = 1 -- head-on block: both slower than this...
Mover.BlockedTime = 0.75 -- ...for this long...
Mover.FacingDist = 4 -- ...within this distance, facing each other
Mover.YieldBack = 1.5 -- the yielder steps back this far and...
Mover.YieldSide = 2.5 -- ...this far to its right
Mover.YieldMax = 8 -- s: never yields longer than this
Mover.OccupiedRadius = 2 -- someone this close to a post occupies it
Mover.WaitSide = 1.5 -- the waiting spot: this far clear of the occupant's shoulder
Mover.WaitMax = 5 -- s: re-check the post at least this often...
Mover.WaitCap = 20 -- s: ...and give up ("failed") after this long
Mover.WalkDesign = (Loco.Design and Loco.Design.Walk) or 12 -- the shared walk is designed at this ground speed

local UP = Vector3.new(0, 1, 0)
local LIFT = 3 -- R6 root height above the ground

local Active = {} -- [Rig] = Handle
local List = {} -- walking handles, in start order
local Tracks = {} -- [Rig] = walk AnimationTrack | false
local OthersGoalNear, WaitSpot -- (defined with the waiting logic below)
local Seq = 0

local Stats
function Mover.ResetStats()
	Stats = {Ticks = 0, Ms = 0, MaxMs = 0, Heartbeats = 0, HeartbeatMs = 0, PeakWalkers = 0, Yields = 0, Replans = 0,
		Sidesteps = 0, Fails = 0, Arrivals = 0, PostWaits = 0, Detours = 0}
end
Mover.ResetStats()

function Mover.Stats()
	return {
		Walkers = #List, StepMs = Stats.Ticks > 0 and Stats.Ms / Stats.Ticks or 0, MaxStepMs = Stats.MaxMs,
		HeartbeatMs = Stats.Heartbeats > 0 and Stats.Ms / Stats.Heartbeats or 0, Ticks = Stats.Ticks,
		PeakWalkers = Stats.PeakWalkers, Yields = Stats.Yields, Replans = Stats.Replans, Sidesteps = Stats.Sidesteps,
		Fails = Stats.Fails, Arrivals = Stats.Arrivals, PostWaits = Stats.PostWaits, Detours = Stats.Detours,
	}
end

local function Flat(V) return Vector3.new(V.X, 0, V.Z) end
local function FlatDist(A, B) return Vector3.new(A.X - B.X, 0, A.Z - B.Z).Magnitude end
local function RightOf(Dir) return Vector3.new(-Dir.Z, 0, Dir.X) end
local function Cost(Costs, Name) return (Name and Costs[Name]) or 1 end

-- ===== the world around the walkers =====
-- Bodies: every character a walker steers around (townsfolk, players, enemies, dummies): World.Live's characters,
-- World.Live.Townsfolk, player characters and the walkers themselves. Refreshed twice a second; positions and
-- velocities are read once per tick.
local Bodies = {} -- {Model, Root, Pos, Vel}
local BodiesAt = 0
local Obstacles = RaycastParams.new() -- geometry only: characters excluded, non-colliding parts ignored
Obstacles.FilterType = Enum.RaycastFilterType.Exclude
Obstacles.RespectCanCollide = true
Obstacles.IgnoreWater = true
local Ground = RaycastParams.new() -- the same, but water counts as ground (it has a cost)
Ground.FilterType = Enum.RaycastFilterType.Exclude
Ground.RespectCanCollide = true
Ground.IgnoreWater = false

local function Live()
	local World = workspace:FindFirstChild("World")
	return World and World:FindFirstChild("Live")
end

local Refreshed = false
local function RefreshBodies()
	Refreshed = true
	table.clear(Bodies)
	local Seen, Skip = {}, {}
	local function Add(M)
		if Seen[M] or not M:IsA("Model") then return end
		local R = M:FindFirstChild("HumanoidRootPart")
		if R and R:IsA("BasePart") and M:FindFirstChildOfClass("Humanoid") then
			Seen[M] = true
			table.insert(Bodies, {Model = M, Root = R})
			table.insert(Skip, M)
		end
	end
	local L = Live()
	if L then
		table.insert(Skip, L)
		for _, M in ipairs(L:GetChildren()) do Add(M) end
		local Folk = L:FindFirstChild("Townsfolk")
		if Folk then for _, M in ipairs(Folk:GetChildren()) do Add(M) end end
	end
	for _, P in ipairs(Players:GetPlayers()) do if P.Character then Add(P.Character) end end
	for Rig in pairs(Active) do Add(Rig) end
	Obstacles.FilterDescendantsInstances = Skip
	Ground.FilterDescendantsInstances = Skip
	local Group = PhysicsService:IsCollisionGroupRegistered("Townsfolk") and "Townsfolk" or "Default"
	Obstacles.CollisionGroup = Group
	Ground.CollisionGroup = Group
end

-- PathfindingModifier volumes, so smoothing never cuts across ground the builders made dearer
local Modifiers = {} -- [PathfindingModifier] = true
local ModifiersReady = false
local function WatchModifiers()
	if ModifiersReady then return end
	ModifiersReady = true
	local function Add(D) if D:IsA("PathfindingModifier") then Modifiers[D] = true end end
	workspace.DescendantAdded:Connect(Add)
	workspace.DescendantRemoving:Connect(function(D) Modifiers[D] = nil end)
	for _, D in ipairs(workspace:GetDescendants()) do Add(D) end
end
task.defer(WatchModifiers)

local function SegmentHitsBox(CF, Size, A, B)
	local P, Q = CF:PointToObjectSpace(A), CF:PointToObjectSpace(B)
	local D, H = Q - P, Size / 2
	local T0, T1 = 0, 1
	for _, Axis in ipairs({"X", "Y", "Z"}) do
		local Pa, Da, Ha = P[Axis], D[Axis], H[Axis]
		if math.abs(Da) < 1e-6 then
			if math.abs(Pa) > Ha then return false end
		else
			local Ta, Tb = (-Ha - Pa) / Da, (Ha - Pa) / Da
			if Ta > Tb then Ta, Tb = Tb, Ta end
			T0, T1 = math.max(T0, Ta), math.min(T1, Tb)
			if T0 > T1 then return false end
		end
	end
	return true
end

-- does the straight line A -> B (ground points) cross a modifier volume dearer than MaxCost?
local function CrossesDearModifier(Costs, A, B, MaxCost)
	for M in pairs(Modifiers) do
		local Parent = M.Parent
		if Parent and (M.PassThrough ~= true) and Cost(Costs, M.Label) > MaxCost then
			local Parts = Parent:IsA("BasePart") and {Parent} or Parent:GetDescendants()
			for _, P in ipairs(Parts) do
				if P:IsA("BasePart") then
					for _, Y in ipairs({0.5, Mover.WaistHeight}) do
						local Lift = Vector3.new(0, Y, 0)
						if SegmentHitsBox(P.CFrame, P.Size, A + Lift, B + Lift) then return true end
					end
				end
			end
		end
	end
	return false
end

-- can a walker go straight from A to B (ground points)? see the header (2. Smoothing)
local function Safe(Costs, A, B, MaxCost)
	local D = B - A
	local Len = Flat(D).Magnitude
	if Len < 0.1 then return true end
	local Waist = Vector3.new(0, Mover.WaistHeight, 0)
	if workspace:Spherecast(A + Waist, Mover.SmoothRadius, D, Obstacles) then return false end
	local N = math.max(1, math.ceil(Len / Mover.GroundStep))
	local Drop = Mover.GroundDrop
	for K = 1, N - 1 do
		local P = A:Lerp(B, K / N)
		local Hit = workspace:Raycast(P + Vector3.new(0, Drop, 0), Vector3.new(0, -2 * Drop, 0), Ground)
		if not Hit or Hit.Normal.Y < 0.7 or math.abs(Hit.Position.Y - P.Y) > Drop then return false end
		if Cost(Costs, Hit.Material.Name) > MaxCost then return false end
	end
	if next(Modifiers) and CrossesDearModifier(Costs, A, B, MaxCost) then return false end
	return true
end

-- is the raw path real? (a segment through geometry = the navmesh hasn't caught up, or a bogus jump)
local function Valid(Pts)
	local Waist = Vector3.new(0, Mover.WaistHeight, 0)
	for I = 1, #Pts - 1 do
		if workspace:Raycast(Pts[I] + Waist, Pts[I + 1] - Pts[I], Obstacles) then return false end
	end
	return true
end

local Tight = OverlapParams.new()
Tight.FilterType = Enum.RaycastFilterType.Exclude
Tight.RespectCanCollide = true

-- string-pulling: from each kept point, keep the furthest point it can reach safely. A point already within the
-- spherecast's radius of geometry (a walker pressed against a door jamb) skips nothing: a cast that starts inside a
-- part doesn't see it, and the raw path is what leads it out.
local function Smooth(Costs, Pts, Labels)
	local Out, Orig = {Pts[1]}, {1}
	Tight.FilterDescendantsInstances = Obstacles.FilterDescendantsInstances
	Tight.CollisionGroup = Obstacles.CollisionGroup
	local I = 1
	while I < #Pts do
		local Best = I + 1
		local MaxCost = math.max(Cost(Costs, Labels[I]), Cost(Costs, Labels[I + 1]))
		local Wedged = #workspace:GetPartBoundsInRadius(Pts[I] + Vector3.new(0, Mover.WaistHeight, 0), Mover.SmoothRadius, Tight) > 0
		for J = Wedged and math.huge or I + 2, #Pts do
			MaxCost = math.max(MaxCost, Cost(Costs, Labels[J]))
			if Safe(Costs, Pts[I], Pts[J], MaxCost) then Best = J else break end
		end
		table.insert(Out, Pts[Best])
		table.insert(Orig, Best)
		I = Best
	end
	return Out, Orig
end

-- a clear, walkable spot from P (root position) to Spot (root height)? (side-steps, yields, waiting spots)
local function SpotClear(H, P, Spot)
	local D = Spot - P
	if D.Magnitude > 0.05 and workspace:Spherecast(P - Vector3.new(0, LIFT - Mover.WaistHeight, 0), 1, D, Obstacles) then return false end
	local Hit = workspace:Raycast(Spot, Vector3.new(0, -(LIFT + Mover.GroundDrop), 0), Ground)
	if not Hit or Hit.Normal.Y < 0.7 then return false end
	for _, B in ipairs(Bodies) do
		if B.Model ~= H.Rig and B.Pos and FlatDist(B.Pos, Spot) < 2.5 then return false end
	end
	return true
end

-- ===== looks =====
local function WalkTrack(Rig)
	if Tracks[Rig] ~= nil then return Tracks[Rig] or nil end
	local Source = ReplicatedStorage.Assets.Animations.Shared:FindFirstChild("Walk", true)
	local Ok, Track = pcall(function() return Rig.Humanoid.Animator:LoadAnimation(Source) end)
	if Ok and Track then
		Track.Looped = true
		Track.Priority = Enum.AnimationPriority.Core -- as EnemyService plays it
	end
	Tracks[Rig] = Ok and Track or false
	Rig.Destroying:Once(function() Tracks[Rig] = nil end)
	return Tracks[Rig] or nil
end

-- the walk plays while the rig really moves, at the rate that matches its ground speed (LocomotionSync's rule)
local function Animate(H, Speed)
	local T = WalkTrack(H.Rig)
	if not T then return end
	if Speed > 0.6 then
		local Rate = math.clamp(Speed / Mover.WalkDesign, Loco.Min or 0.5, Loco.Max or 1.6)
		if not T.IsPlaying then T:Play(0.2, 1, Rate)
		elseif math.abs(T.Speed - Rate) > 0.03 then T:AdjustSpeed(Rate) end
	elseif Speed < 0.3 and T.IsPlaying then
		T:Stop(0.25)
	end
end

-- Facing: while walking, AutoRotate is off and an AlignOrientation on the root turns the rig towards the way it
-- moves (or the way it looks while it stands), at TurnRate at most. Physics runs it every frame, so turns are smooth
-- between the 10 Hz steering ticks and never snap.
local function Facer(H)
	local Root = H.Root
	local A = Root:FindFirstChild("MoverFacingAttachment")
	if not A then
		A = Instance.new("Attachment")
		A.Name = "MoverFacingAttachment"
		A.Parent = Root
	end
	local AO = Root:FindFirstChild("MoverFacing")
	if not AO then
		AO = Instance.new("AlignOrientation")
		AO.Name = "MoverFacing"
		AO.Mode = Enum.OrientationAlignmentMode.OneAttachment
		AO.Attachment0 = A
		AO.RigidityEnabled = false
		AO.MaxTorque = 1e7
		AO.Responsiveness = 30
		AO.Parent = Root
	end
	AO.MaxAngularVelocity = math.rad(Mover.TurnRate)
	return AO
end

local function FaceToward(H, Dir)
	if not H.Facer or Dir.Magnitude < 1e-3 then return end
	local Want = Flat(Dir)
	if Want.Magnitude < 1e-3 then return end
	H.Facer.CFrame = CFrame.lookAt(Vector3.zero, Want.Unit)
end

-- ===== walks =====
local Conn -- the Heartbeat connection (only while someone walks)

local function Put(Rig, TargetCFrame)
	local Root = Rig:FindFirstChild("HumanoidRootPart")
	if not Root then return end
	Root.Anchored = true
	Root.AssemblyLinearVelocity = Vector3.zero
	Rig:PivotTo(TargetCFrame)
end

local function Finish(H, Result)
	if H.Status ~= "walking" then return end
	H.Status = Result
	if Active[H.Rig] == H then Active[H.Rig] = nil end
	local I = table.find(List, H)
	if I then table.remove(List, I) end
	if H.BlockedConn then H.BlockedConn:Disconnect() H.BlockedConn = nil end
	if H.Tween then H.Tween:Cancel() H.Tween = nil end
	if H.Humanoid and H.Rig.Parent then
		pcall(function()
			H.Humanoid:Move(Vector3.zero)
			H.Humanoid.AutoRotate = true
			if H.Facer then H.Facer.Enabled = false end
		end)
	end
	local T = Tracks[H.Rig]
	if T and T.IsPlaying and not Active[H.Rig] then T:Stop(0.2) end
	if Result == "failed" then Stats.Fails += 1 elseif Result == "arrived" then Stats.Arrivals += 1 end
	if H.OnDone then
		local Ok, Err = pcall(H.OnDone, Result)
		if not Ok then warn("Mover OnDone:", Err) end
	end
end

local function Cancel(H) Finish(H, "cancelled") end

-- any error ends the walk as "failed", with the rig held still and upright where it is
local function Broke(H, Err)
	warn("Mover: walk failed:", Err)
	if H.Status == "walking" and H.Rig.Parent then
		pcall(function()
			local Here = H.Root.CFrame
			local L = Flat(Here.LookVector)
			Put(H.Rig, CFrame.lookAt(Here.Position, Here.Position + (L.Magnitude > 1e-3 and L or Vector3.new(0, 0, -1))))
		end)
	end
	Finish(H, "failed")
end

local function Alive(H, Gen) return H.Status == "walking" and H.Rig.Parent ~= nil and (Gen == nil or Gen == H.PlanGen) end

local function ResetWindow(H, P, Now)
	H.WinPos, H.WinT, H.Excused, H.SlowT, H.SlowRef = P, Now, false, 0, nil
end

local function PathLength(Pts)
	local L = 0
	for I = 1, #Pts - 1 do L += FlatDist(Pts[I], Pts[I + 1]) end
	return L
end

-- one path at one agent radius: {Path, Pts, Labels, Raw, Radius, Length}, "stale" (it runs through geometry: the
-- navmesh hasn't caught up yet, or a bogus jump) or nil (no path). From = the start (default: where the root is); a
-- start other than the root is joined to it with a straight first leg.
local function Compute(H, Agent, Costs, Radius, From)
	local Params = table.clone(Agent)
	Params.AgentRadius = Radius
	Params.Costs = Costs
	local Path = PathfindingService:CreatePath(Params)
	local Ok = pcall(Path.ComputeAsync, Path, From or H.Root.Position, H.Goal)
	if not (Ok and Path.Status == Enum.PathStatus.Success) then return nil end
	local Raw = Path:GetWaypoints()
	local Pts, Labels = {}, {}
	if From then
		Pts[1], Labels[1] = H.Root.Position - Vector3.new(0, LIFT, 0), Raw[1] and Raw[1].Label
	end
	for _, W in ipairs(Raw) do
		table.insert(Pts, W.Position)
		table.insert(Labels, W.Label)
	end
	if #Pts < 1 or not Valid(Pts) then return "stale" end
	if FlatDist(Pts[#Pts], H.Goal) > 0.05 then
		table.insert(Pts, H.Goal)
		table.insert(Labels, Labels[#Labels])
	end
	return {Path = Path, Pts = Pts, Labels = Labels, Raw = #Raw, Radius = Radius, Length = PathLength(Pts)}
end

local function PlanBody(H, Gen)
	local Agent = H.Agent
	local Costs = table.clone(Mover.Costs)
	for K, V in pairs(Agent.Costs or {}) do Costs[K] = V end
	local Radii = {Agent.AgentRadius or 2}
	for _, R in ipairs(Mover.NarrowRadii) do
		if R < Radii[1] then table.insert(Radii, R) end
	end
	if not Refreshed then RefreshBodies() end -- (the geometry filters; the tick keeps them fresh)
	local Straight = FlatDist(H.Root.Position, H.Goal)
	for Attempt = 1, 8 do
		local Stale, Best = false, nil
		for _, Radius in ipairs(Radii) do
			local Got = Compute(H, Agent, Costs, Radius)
			if not Alive(H, Gen) then return end
			if Got == "stale" then
				Stale = true
			elseif Got then
				if not Best then
					Best = Got
					-- a long way round: a narrower agent may fit a short cut (a door) the comfortable radius doesn't
					if Got.Length <= Straight * Mover.DetourRatio + Mover.DetourSlack then break end
				elseif Got.Length < Best.Length * 0.75 then
					Best = Got
					break
				end
			end
		end
		if not Best then
			-- no path from here (a walker pressed against a jamb or a neighbour is off the navmesh; a post between
			-- standing townsfolk may be inside their inflated outlines): a short, clear straight leg to the goal, or a
			-- path from a spot just behind or beside the walker
			local Here = H.Root.Position - Vector3.new(0, LIFT, 0)
			if Straight <= 15 and Valid({Here, H.Goal}) and Safe(Costs, Here, H.Goal, math.huge) then
				Best = {Pts = {Here, H.Goal}, Labels = {}, Raw = 2, Radius = 0, Length = Straight}
			else
				local Dir, Right = H.Dir, RightOf(H.Dir)
				for _, Off in ipairs({-Dir * 3, Right * 2.5, -Right * 2.5, -Dir * 6}) do
					local From = H.Root.Position + Off
					if Valid({Here, From - Vector3.new(0, LIFT, 0)}) then
						local Got = Compute(H, Agent, Costs, Radii[#Radii], From)
						if not Alive(H, Gen) then return end
						if type(Got) == "table" then Best = Got break end
					end
				end
			end
		end
		if Best then
			local Wps, Orig = Smooth(Costs, Best.Pts, Best.Labels)
			if not Alive(H, Gen) then return end
			local Remain = {}
			Remain[#Wps] = 0
			for I = #Wps - 1, 1, -1 do Remain[I] = Remain[I + 1] + FlatDist(Wps[I], Wps[I + 1]) end
			H.Wps, H.Orig, H.Remain, H.Wi = Wps, Orig, Remain, math.min(2, #Wps)
			H.Waypoints, H.RawWaypoints, H.Radius = Wps, Best.Raw, Best.Radius
			if H.BlockedConn then H.BlockedConn:Disconnect() H.BlockedConn = nil end
			H.BlockedConn = Best.Path and Best.Path.Blocked:Connect(function(Index)
				-- a waypoint on the rest of the way is blocked: re-plan (on the next tick)
				if H.Status == "walking" and H.Orig == Orig and Index >= (Orig[math.max(1, H.Wi - 1)] or 1) then
					H.NeedPlan = H.NeedPlan or "blocked"
				end
			end)
			H.Path = Best.Path
			H.Mode = "walk"
			ResetWindow(H, H.Root.Position, os.clock())
			return
		end
		if not Stale then break end
		task.wait(0.5) -- the navmesh is still catching up with a change: ask again
		if not Alive(H, Gen) then return end
	end
	Finish(H, "failed")
end

local function Plan(H, Why)
	H.PlanGen = (H.PlanGen or 0) + 1
	local Gen = H.PlanGen
	if Why ~= "start" then
		H.Replans += 1
		Stats.Replans += 1
		if H.Replans > Mover.MaxPlans then Finish(H, "failed") return end
	end
	H.Mode = "plan"
	H.NeedPlan = nil
	H.NextPlanAt = os.clock() + 1
	task.spawn(function()
		local Ok, Err = pcall(PlanBody, H, Gen)
		if not Ok and H.Status == "walking" then Broke(H, Err) end
	end)
end

-- arrival: stop, anchor, turn (and settle) onto the target over TurnTime, then "arrived"
local function Arrive(H)
	H.Mode = "arrive"
	H.Humanoid:Move(Vector3.zero)
	if H.Facer then H.Facer.Enabled = false end
	local T = Tracks[H.Rig]
	if T and T.IsPlaying then T:Stop(0.25) end
	H.Root.Anchored = true
	H.Root.AssemblyLinearVelocity = Vector3.zero
	local Look, Want = Flat(H.Root.CFrame.LookVector), Flat(H.Target.LookVector)
	local Angle = (Look.Magnitude > 1e-3 and Want.Magnitude > 1e-3) and math.acos(math.clamp(Look.Unit:Dot(Want.Unit), -1, 1)) or 0
	local Time = math.max(Mover.TurnTime, Angle / math.rad(Mover.ArriveTurnRate))
	local Tw = TweenService:Create(H.Root, TweenInfo.new(Time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {CFrame = H.Target})
	H.Tween = Tw
	Tw.Completed:Once(function(State)
		if H.Status ~= "walking" or H.Tween ~= Tw then return end
		H.Tween = nil
		if State == Enum.PlaybackState.Completed then
			Put(H.Rig, H.Target)
			Finish(H, "arrived")
		end
	end)
	Tw:Play()
end

local function HasPriority(A, B)
	local Ra, Rb = A.RemainDist or math.huge, B.RemainDist or math.huge
	if math.abs(Ra - Rb) > 0.5 then return Ra < Rb end
	if A.Id ~= B.Id then return A.Id < B.Id end
	return A.Seq < B.Seq
end

-- the first clear spot among Candidates (offsets from P); P itself when none is
local function PickSpot(H, P, Candidates)
	for _, Off in ipairs(Candidates) do
		if SpotClear(H, P, P + Off) then return P + Off end
	end
	return P
end

-- avoidance (header, 3): returns the steered velocity for a walker at P wanting Desired along Dir, Reach studs to go
-- on this straight line (to the next waypoint or spot)
local function Avoid(H, P, Desired, Dir, Reach, NearGoal)
	local Right = RightOf(Dir)
	local Lateral, Push, FwdCap = 0, Vector3.zero, math.huge
	local Hard = nil -- moving bodies inside HardGap: {unit direction to it, weight}
	local Clear = Mover.Clearance
	local SenseSq = Mover.SenseRadius * Mover.SenseRadius
	for _, B in ipairs(Bodies) do
		local BP = B.Pos
		if BP and B.Model ~= H.Rig then
			local D = Vector3.new(BP.X - P.X, 0, BP.Z - P.Z)
			local DistSq = D.X * D.X + D.Z * D.Z
			if DistSq < SenseSq and DistSq > 1e-6 and math.abs(BP.Y - P.Y) < 6 then
				local Dist = math.sqrt(DistSq)
				local BV = B.Vel
				local Still = BV.Magnitude < 0.3
				local Vr = BV - Desired
				local VV = Vr:Dot(Vr)
				local Tc = VV > 1e-4 and math.clamp(-D:Dot(Vr) / VV, 0, Mover.Lookahead) or 0
				local C = D + Vr * Tc
				local CD = C.Magnitude
				local Along = D:Dot(Dir)
				local Side = D:Dot(Right)
				-- 1) a predicted near miss: side-step (near the goal, bodies standing still are left alone: the posts
				-- may be 3 studs apart). Only where there is room to pass: in a door or a narrow lane there isn't, and
				-- the walker queues instead (2), which ends in one of the two giving way (header, 4).
				local NoRoom = false
				if CD < Clear and (Along > -1 or Tc > 0.05) and not (NearGoal and Still) then
					local Lat = C:Dot(Right)
					local Way = math.abs(Lat) > 0.3 and -math.sign(Lat) or 1 -- head-on: pass on the right
					local Need = math.max(0, Mover.LaneWidth - math.abs(Lat)) * (Still and 1 or 0.5) + 1 -- (1: half a torso)
					if Along > 0 and Need > 1.05 then
						local At = P + Desired * Tc - Vector3.new(0, LIFT - Mover.WaistHeight, 0)
						NoRoom = workspace:Spherecast(At, 0.75, Right * (Way * Need), Obstacles) ~= nil
					end
					if not NoRoom then
						local W = (Clear - CD) / Clear * (1 - Tc / Mover.Lookahead)
						Lateral += Way * W
					end
				end
				-- 2) a body ahead in the walker's lane: keep to its pace, stop short of it. The lane is the rest of this
				-- straight line. A body standing still only counts if the walker would touch it (the side-step above
				-- gives it a wider berth where there's room; posts may be 3 studs apart)
				local Off = Along <= Reach and math.abs(Side) or (D - Dir * Reach).Magnitude
				if Along > 0 and (NoRoom or Off < (Still and Mover.ContactGap or Mover.LaneWidth)) then
					local Pace = math.max(0, BV:Dot(Dir))
					local Cap = Pace + math.max(0, Along - Mover.StopGap) * 2
					if Cap < FwdCap then
						FwdCap = Cap
						H.Blocker = B
					end
				end
				-- 3) too close: push apart (near the goal, from a body standing still only at contact: posts may be 3
				-- studs apart; someone moving is always kept at Separation)
				local Sep = (NearGoal and Still) and Mover.ContactGap or Mover.Separation
				if Dist < Sep then Push -= D / Dist * ((Sep - Dist) / Sep) end
				-- 4) someone moving this close: never step any closer (whatever the other rules want)
				if not Still and Dist < Mover.HardGap + 0.4 then
					Hard = Hard or {}
					table.insert(Hard, {D / Dist, math.clamp((Mover.HardGap + 0.4 - Dist) / 0.4, 0, 1)})
				end
			end
		end
	end
	Lateral = math.clamp(Lateral, -1.5, 1.5)
	local Steer = Desired + Right * (Lateral * H.Speed * Mover.DodgeGain) + Push * (H.Speed * Mover.PushGain)
	-- smoothing (facing follows the move direction), then the hard forward cap
	Steer = H.Steer:Lerp(Steer, Mover.Blend)
	local Fwd = Steer:Dot(Dir)
	if Fwd > FwdCap then Steer += Dir * (FwdCap - Fwd) end
	for _, C in ipairs(Hard or {}) do
		local Toward = Steer:Dot(C[1])
		if Toward > 0 then Steer -= C[1] * (Toward * C[2]) end
	end
	if Steer.Magnitude > H.Speed then Steer = Steer.Unit * H.Speed end
	return Steer, FwdCap
end

local function Move(H, Steer)
	H.Steer = Steer
	if Steer.Magnitude > 1.5 then FaceToward(H, Steer) end -- (a slow shuffle, a push, doesn't turn the body)
	H.Humanoid:Move(Steer / H.Speed)
end

local function Hold(H, FaceDir)
	H.Steer = H.Steer * 0.4
	if H.Steer.Magnitude < 0.3 then
		H.Steer = Vector3.zero
		H.Humanoid:Move(Vector3.zero)
		if FaceDir then FaceToward(H, FaceDir) end
	else
		H.Humanoid:Move(H.Steer / H.Speed)
	end
end

-- someone else standing on (or walking over) the post?
local function Occupied(H)
	for _, B in ipairs(Bodies) do
		if B.Model ~= H.Rig and B.Pos and FlatDist(B.Pos, H.Goal) < Mover.OccupiedRadius and math.abs(B.Pos.Y - LIFT - H.Goal.Y) < 4 then
			return B
		end
	end
	return nil
end

-- ===== local routes around standing bodies =====
-- PathfindingService knows nothing about characters, so a post boxed in by townsfolk already standing at theirs, or a
-- player standing in an alley, needs a route of its own: A* over a 1-stud grid around the walker and its target, with
-- every body standing still (ContactGap) and the geometry (parts from the waist down to the ankles, a torso's width
-- around them) as obstacles, then string-pulled. Returns the points after P up to and including Target, or nil.
local LocalParams = OverlapParams.new()
LocalParams.FilterType = Enum.RaycastFilterType.Exclude
LocalParams.RespectCanCollide = true

local function Standing(Bd)
	if Bd.Vel.Magnitude < 0.3 then return true end
	local O = Active[Bd.Model]
	return O ~= nil and O.Mode == "walk" and (O.SlowT or 0) >= 0.5
end

local function SegDist(A, B, Q) -- flat distance from Q to the segment A-B
	local AB = Vector3.new(B.X - A.X, 0, B.Z - A.Z)
	local AQ = Vector3.new(Q.X - A.X, 0, Q.Z - A.Z)
	local L2 = AB:Dot(AB)
	local T = L2 > 1e-6 and math.clamp(AQ:Dot(AB) / L2, 0, 1) or 0
	return (AQ - AB * T).Magnitude
end

-- a body standing still within Gap of the straight line A-B (other than the walker and anything on B itself)?
local function StillBodyOnLine(H, A, B, Gap)
	for _, Bd in ipairs(Bodies) do
		if Bd.Model ~= H.Rig and Bd.Pos and Standing(Bd) and FlatDist(Bd.Pos, B) > Mover.OccupiedRadius
			and SegDist(A, B, Bd.Pos) < Gap then
			return true
		end
	end
	return false
end

local function LocalRoute(H, P, Target)
	local Gap = Mover.ContactGap
	local GroundY = Target.Y
	local MinX, MaxX = math.min(P.X, Target.X) - Mover.LocalMargin, math.max(P.X, Target.X) + Mover.LocalMargin
	local MinZ, MaxZ = math.min(P.Z, Target.Z) - Mover.LocalMargin, math.max(P.Z, Target.Z) + Mover.LocalMargin
	local NX, NZ = math.ceil(MaxX - MinX) + 1, math.ceil(MaxZ - MinZ) + 1
	if NX * NZ > Mover.LocalCells then return nil end
	local Blocked = {}
	local function Id(I, J) return J * NX + I end
	local function Centre(I, J) return Vector3.new(MinX + I, GroundY, MinZ + J) end
	-- bodies standing still (a body on the target is the post's occupant: the wait handles that)
	for _, Bd in ipairs(Bodies) do
		local Q = Bd.Pos
		if Bd.Model ~= H.Rig and Q and Standing(Bd) and FlatDist(Q, Target) > Mover.OccupiedRadius then
			for I = math.max(0, math.floor(Q.X - Gap - MinX)), math.min(NX - 1, math.ceil(Q.X + Gap - MinX)) do
				for J = math.max(0, math.floor(Q.Z - Gap - MinZ)), math.min(NZ - 1, math.ceil(Q.Z + Gap - MinZ)) do
					if FlatDist(Centre(I, J), Q) < Gap then Blocked[Id(I, J)] = true end
				end
			end
		end
	end
	-- geometry between the ankles and the waist (the floor itself is below the box)
	LocalParams.FilterDescendantsInstances = Obstacles.FilterDescendantsInstances
	LocalParams.CollisionGroup = Obstacles.CollisionGroup
	local Box = CFrame.new((MinX + MaxX) / 2, GroundY + 0.5 + (Mover.WaistHeight + 0.5) / 2, (MinZ + MaxZ) / 2)
	for _, Part in ipairs(workspace:GetPartBoundsInBox(Box, Vector3.new(MaxX - MinX, Mover.WaistHeight + 0.5, MaxZ - MinZ), LocalParams)) do
		local CF, S = Part.CFrame, Part.Size / 2
		local R, U, L = CF.RightVector, CF.UpVector, CF.LookVector
		local EX = math.abs(R.X) * S.X + math.abs(U.X) * S.Y + math.abs(L.X) * S.Z + 1
		local EZ = math.abs(R.Z) * S.X + math.abs(U.Z) * S.Y + math.abs(L.Z) * S.Z + 1
		local C = CF.Position
		for I = math.max(0, math.floor(C.X - EX - MinX)), math.min(NX - 1, math.ceil(C.X + EX - MinX)) do
			for J = math.max(0, math.floor(C.Z - EZ - MinZ)), math.min(NZ - 1, math.ceil(C.Z + EZ - MinZ)) do
				local K = Id(I, J)
				if not Blocked[K] then
					local L = CF:PointToObjectSpace(Centre(I, J) + Vector3.new(0, 1.5, 0))
					if math.abs(L.X) < S.X + 1 and math.abs(L.Y) < S.Y + 1.5 and math.abs(L.Z) < S.Z + 1 then Blocked[K] = true end
				end
			end
		end
	end
	local SI, SJ = math.floor(P.X - MinX + 0.5), math.floor(P.Z - MinZ + 0.5)
	local GI, GJ = math.floor(Target.X - MinX + 0.5), math.floor(Target.Z - MinZ + 0.5)
	Blocked[Id(SI, SJ)], Blocked[Id(GI, GJ)] = nil, nil -- (the walker may stand pressed against someone)
	-- A* (binary heap on F = G + straight-line distance)
	local function Hn(K) local I, J = K % NX, K // NX return math.sqrt((I - GI) ^ 2 + (J - GJ) ^ 2) end
	local Heap, HF = {}, {}
	local function Push(K, F)
		table.insert(Heap, K)
		table.insert(HF, F)
		local N = #Heap
		while N > 1 do
			local Up = N // 2
			if HF[Up] <= HF[N] then break end
			Heap[Up], Heap[N], HF[Up], HF[N] = Heap[N], Heap[Up], HF[N], HF[Up]
			N = Up
		end
	end
	local function Pop()
		local Top = Heap[1]
		local Last, LF = table.remove(Heap), table.remove(HF)
		if #Heap > 0 then
			Heap[1], HF[1] = Last, LF
			local N = 1
			while true do
				local A, B, M = N * 2, N * 2 + 1, N
				if A <= #Heap and HF[A] < HF[M] then M = A end
				if B <= #Heap and HF[B] < HF[M] then M = B end
				if M == N then break end
				Heap[M], Heap[N], HF[M], HF[N] = Heap[N], Heap[M], HF[N], HF[M]
				N = M
			end
		end
		return Top
	end
	local Start, Goal = Id(SI, SJ), Id(GI, GJ)
	local G, From, Closed = {[Start] = 0}, {}, {}
	Push(Start, Hn(Start))
	local Found = false
	while #Heap > 0 do
		local K = Pop()
		if K == Goal then Found = true break end
		if Closed[K] then continue end
		Closed[K] = true
		local I, J = K % NX, K // NX
		for _, D in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {1, -1}, {-1, 1}, {-1, -1}}) do
			local I2, J2 = I + D[1], J + D[2]
			if I2 >= 0 and I2 < NX and J2 >= 0 and J2 < NZ then
				local K2 = Id(I2, J2)
				local Diag = D[1] ~= 0 and D[2] ~= 0
				if not Blocked[K2] and not Closed[K2] and not (Diag and (Blocked[Id(I2, J)] or Blocked[Id(I, J2)])) then
					local G2 = G[K] + (Diag and 1.4142 or 1)
					if not G[K2] or G2 < G[K2] then
						G[K2], From[K2] = G2, K
						Push(K2, G2 + Hn(K2))
					end
				end
			end
		end
	end
	if not Found then return nil end
	local Cells = {}
	local K = Goal
	while K do
		table.insert(Cells, 1, K)
		K = From[K]
	end
	-- string-pull over the grid: keep the furthest cell each kept cell sees without crossing a blocked one
	local function Sees(A, B)
		local AI, AJ, BI, BJ = A % NX, A // NX, B % NX, B // NX
		local N = math.max(math.abs(BI - AI), math.abs(BJ - AJ)) * 2
		for S = 1, N - 1 do
			local T = S / N
			if Blocked[Id(math.floor(AI + (BI - AI) * T + 0.5), math.floor(AJ + (BJ - AJ) * T + 0.5))] then return false end
		end
		return true
	end
	local Out, At = {}, 1
	while At < #Cells do
		local Best = At + 1
		for N = #Cells, At + 2, -1 do
			if Sees(Cells[At], Cells[N]) then Best = N break end
		end
		local C = Cells[Best]
		table.insert(Out, Best == #Cells and Target or Centre(C % NX, C // NX))
		At = Best
	end
	return #Out > 0 and Out or nil
end

-- swaps the rest of the way to the current waypoint for a local route; true if it found one
local function Detour(H, P, Now)
	local Target = H.Wps[H.Wi]
	if FlatDist(P, Target) > Mover.LocalReach then return false end
	local Route = LocalRoute(H, P, Target)
	if not Route then return false end
	local Wps = {P - Vector3.new(0, LIFT, 0)}
	for _, Q in ipairs(Route) do table.insert(Wps, Q) end
	for I = H.Wi + 1, #H.Wps do table.insert(Wps, H.Wps[I]) end
	local Remain = {}
	Remain[#Wps] = 0
	for I = #Wps - 1, 1, -1 do Remain[I] = Remain[I + 1] + FlatDist(Wps[I], Wps[I + 1]) end
	H.Wps, H.Remain, H.Wi, H.Orig = Wps, Remain, 2, {}
	H.Waypoints = Wps
	H.DetourAt = Now
	H.Replans += 1
	Stats.Replans += 1
	Stats.Detours += 1
	ResetWindow(H, P, Now)
	return true
end

-- is Spot near the goal of another walker? (waiting there would block it)
OthersGoalNear = function(H, Spot, R)
	for _, O in ipairs(List) do
		if O ~= H and O.Goal and FlatDist(O.Goal, Spot) < R then return true end
	end
	return false
end

-- where to wait for an occupied post: 1.5 studs clear of the occupant's shoulder, back along the way the walker came
-- first (that side is open: it just walked there), then to either side, a little further out next; never on another
-- walker's post
WaitSpot = function(H, P, Dir)
	local Right = RightOf(Dir)
	local Base = Vector3.new(H.Goal.X, P.Y, H.Goal.Z)
	local Fallback
	for _, Off in ipairs({2 + Mover.WaitSide, 3 + Mover.WaitSide * 2}) do
		for _, Way in ipairs({-Dir, Right, -Right}) do
			local S = Base + Way * Off
			if SpotClear(H, P, S) then
				if not OthersGoalNear(H, S, Mover.OccupiedRadius + 1.5) then return S end
				Fallback = Fallback or S
			end
		end
	end
	return Fallback or P
end

local function Stuck(H, P, Now)
	if H.StuckReplans >= Mover.MaxReplans then Finish(H, "failed") return end
	H.StuckReplans += 1
	H.StuckFrom = P
	-- standing bodies in the way (a crowd at the posts, a player in an alley): a local route round them first
	if Detour(H, P, Now) then return end
	Stats.Sidesteps += 1
	local Right = RightOf(H.Dir)
	H.Spot = PickSpot(H, P, {Right * Mover.Sidestep, -Right * Mover.Sidestep, -H.Dir * Mover.Sidestep})
	H.SpotUntil = Now + 1.2
	H.Mode = "side"
end

-- steering towards Spot (sidestep / yield / wait); true when there
local function GoTo(H, P, Spot, Now)
	local To = Flat(Spot - P)
	local D = To.Magnitude
	if D < 0.4 then return true end
	local Dir = To / D
	local Desired = Dir * math.max(Mover.MinSpeed, H.Speed * math.min(1, D / 2))
	local Steer = Avoid(H, P, Desired, Dir, D, true)
	Move(H, Steer)
	return false
end

local function StepOne(H, Dt, Now)
	local Rig, Root, Hum = H.Rig, H.Root, H.Humanoid
	if not Rig.Parent or not Root.Parent or Hum.Health <= 0 then Finish(H, "cancelled") return end
	if H.Mode == "arrive" then return end
	if Root.Anchored then Root.Anchored = false end -- a deferred NpcIdles loosen landing after the walk began
	local P = Root.Position
	local SpeedNow = Flat(Root.AssemblyLinearVelocity).Magnitude
	Animate(H, SpeedNow)
	H.Blocker = nil

	if H.Mode == "plan" then -- (a path is being computed: coast)
		H.Steer = H.Steer * 0.8
		Hum:Move(H.Steer / H.Speed)
		return
	end
	if H.NeedPlan and Now >= H.NextPlanAt and (H.Mode == "walk" or H.Mode == "wait") then
		Plan(H, H.NeedPlan)
		return
	end

	if H.Mode == "side" then -- stepping sideways out of a jam, then a fresh path
		if GoTo(H, P, H.Spot, Now) or Now > H.SpotUntil then Plan(H, "stuck") end
		return
	end

	if H.Mode == "yield" then
		local O = H.YieldTo
		local OP = O.Root and O.Root.Position
		local Done = O.Status ~= "walking" or not OP or Now - H.YieldT0 > Mover.YieldMax
		if not Done then
			local D = FlatDist(P, OP)
			if D > H.YieldLast + 0.02 then H.Grow += 1 else H.Grow = 0 end
			H.YieldLast = D
			-- passed: the distance keeps growing and the other is behind the yielder's way (or well clear)
			if H.Grow >= 3 and (Flat(OP - P):Dot(H.Dir) < 0 or D > 6) then Done = true end
		end
		if Done then
			H.Mode = "walk"
			H.YieldCooldown = Now + 3
			ResetWindow(H, P, Now)
			return
		end
		if not H.Settled and GoTo(H, P, H.Spot, Now) then H.Settled = true end
		if H.Settled or Now - H.YieldT0 > 1.5 then
			H.Settled = true
			Hold(H, Flat(OP - P))
		end
		return
	end

	if H.Mode == "wait" then -- someone is on the post: wait beside it
		if Now >= H.WaitCheck then
			H.WaitCheck = Now + 0.5
			if not Occupied(H) then
				H.Mode = "walk"
				ResetWindow(H, P, Now)
				return
			end
			if Now - H.WaitT0 > Mover.WaitCap then Finish(H, "failed") return end
			-- standing on another walker's post while it waits for ours: step off it (else they wait on each other)
			if OthersGoalNear(H, P, Mover.OccupiedRadius + 0.5) then
				H.Spot, H.Settled = WaitSpot(H, P, Flat(H.Goal - P).Magnitude > 0.1 and Flat(H.Goal - P).Unit or H.Dir), false
			end
		end
		if not H.Settled and GoTo(H, P, H.Spot, Now) then H.Settled = true end
		if H.Settled then Hold(H, Flat(H.Goal - P)) end
		return
	end

	-- ===== walk =====
	local Wps, N = H.Wps, #H.Wps
	while H.Wi < N do
		local W = Wps[H.Wi]
		if FlatDist(P, W) < Mover.Reach then
			H.Wi += 1
		else
			local Prev = Wps[H.Wi - 1] or P
			local Seg = Flat(W - Prev)
			local L = Seg.Magnitude
			if L > 0.01 and Flat(P - Prev):Dot(Seg) / L >= L - 0.25 then H.Wi += 1 else break end -- (passed it)
		end
	end
	local Next = Wps[H.Wi]
	local ToNext = Flat(Next - P)
	local DN = ToNext.Magnitude
	local Dir = DN > 0.01 and ToNext / DN or H.Dir
	H.Dir = Dir
	local Remain = DN + H.Remain[H.Wi]
	H.RemainDist = Remain

	if H.Wi == N and DN < Mover.ArriveDist then Arrive(H) return end

	-- the last stretch runs past someone standing still (a post among others' posts): take a local route round them
	if H.Wi == N and DN < Mover.LocalReach and Now >= (H.ApproachCheck or 0) then
		H.ApproachCheck = Now + 0.5
		if StillBodyOnLine(H, P, Next, Mover.ContactGap) and Detour(H, P, Now) then return end
	end

	-- the post is taken: wait near it (1.5 studs clear of the occupant's shoulder), re-checking. Back along the way it
	-- came first (that side is open: it just walked there), then to either side
	if Remain < 5 and Occupied(H) then
		H.Mode, H.Spot, H.Settled = "wait", WaitSpot(H, P, Dir), false
		H.WaitT0, H.WaitCheck = Now, Now + 0.5
		Stats.PostWaits += 1
		return
	end

	-- a wall has appeared between the walker and its next waypoint: re-plan
	if Now >= H.SightAt then
		H.SightAt = Now + Mover.SightEvery
		local Look = Flat(Next - P)
		local Len = math.min(Look.Magnitude, Mover.SightRange)
		if Len > 1 and workspace:Spherecast(P - Vector3.new(0, LIFT - Mover.WaistHeight, 0), 1, Look.Unit * Len, Obstacles) then
			H.NeedPlan = H.NeedPlan or "sight"
		end
	end

	local Want = math.max(Mover.MinSpeed, H.Speed * math.min(1, Remain / Mover.SlowRadius))
	local Look = Flat(Root.CFrame.LookVector)
	if Look.Magnitude > 1e-3 then -- facing well away from the way to go: turn first, then walk (eased, not stopped)
		Want *= math.clamp(Look.Unit:Dot(Dir) + 0.3, 0.15, 1)
	end
	local Steer = Avoid(H, P, Dir * Want, Dir, DN, Remain < 3)
	Move(H, Steer)
	if Steer.Magnitude <= 1.5 then FaceToward(H, Dir) end -- (turning on the spot towards the way to go)

	-- narrow spots: blocked head-on with another walker -> the lower priority yields
	-- "slow" = no progress along the way at BlockedSpeed on average since the last real progress (jostling against
	-- a jamb jitters the speed, but it isn't getting anywhere)
	local Ref = H.SlowRef
	if not Ref or Remain > 2 and Remain < Ref[2] - Mover.BlockedSpeed * (Now - Ref[1]) - 0.3 or Remain <= 2 then
		H.SlowRef = {Now, Remain}
		H.SlowT = 0
	else
		H.SlowT = Now - Ref[1]
	end
	if H.SlowT >= Mover.BlockedTime and Now >= (H.YieldCooldown or 0) then
		for _, B in ipairs(Bodies) do
			local O = Active[B.Model]
			if O and O ~= H and O.Mode == "walk" and O.SlowT and O.SlowT >= Mover.BlockedTime and B.Pos then
				local D = Flat(B.Pos - P)
				local Dist = D.Magnitude
				if Dist <= Mover.FacingDist and Dist > 1e-3 and H.Dir:Dot(D / Dist) > 0.5 and O.Dir:Dot(-D / Dist) > 0.5
					and not HasPriority(H, O) then
					local Right = RightOf(Dir)
					local Back, Side = -Dir * Mover.YieldBack, Right * Mover.YieldSide
					H.Spot = PickSpot(H, P, {Back + Side, Back - Side, Side, -Side, -Dir * (Mover.YieldBack + Mover.YieldSide)})
					H.Mode, H.YieldTo, H.YieldT0, H.Settled = "yield", O, Now, false
					H.YieldLast, H.Grow = Dist, 0
					H.Yields += 1
					Stats.Yields += 1
					return
				end
			end
		end
	end

	-- stuck: under StuckProgress in StuckWindow, unless it was queueing behind someone moving or giving way
	local Bl = H.Blocker
	if Bl then
		local O = Active[Bl.Model]
		if Bl.Vel.Magnitude > 1 or (O and (O.Mode == "yield" or O.Mode == "arrive" or O.Mode == "plan")) then H.Excused = true end
	end
	if H.StuckFrom and FlatDist(P, H.StuckFrom) > Mover.ProgressReset then H.StuckReplans, H.StuckFrom = 0, nil end
	if Now - H.WinT >= Mover.StuckWindow then
		if FlatDist(P, H.WinPos) < Mover.StuckProgress and not H.Excused then
			Stuck(H, P, Now)
			if H.Status ~= "walking" then return end
		end
		H.WinPos, H.WinT, H.Excused = P, Now, false
	end
end

local Acc = 0
local function Tick(Dt)
	Stats.Heartbeats += 1
	Acc += Dt
	if Acc < 1 / Mover.Hz then return end
	local StepDt = math.min(Acc, 0.5)
	Acc = 0
	local T0 = os.clock()
	local Now = T0
	if Now >= BodiesAt then RefreshBodies() BodiesAt = Now + 0.5 end
	for _, B in ipairs(Bodies) do
		local R = B.Root
		if R.Parent then
			B.Pos = R.Position
			local V = R.AssemblyLinearVelocity
			B.Vel = Vector3.new(V.X, 0, V.Z)
		else
			B.Pos = nil
		end
	end
	for _, H in ipairs(table.clone(List)) do
		if H.Status == "walking" then
			local Ok, Err = pcall(StepOne, H, StepDt, Now)
			if not Ok and H.Status == "walking" then Broke(H, Err) end
		end
	end
	local Ms = (os.clock() - T0) * 1000
	if #List > 0 or Ms > 0 then
		Stats.Ticks += 1
		Stats.Ms += Ms
		Stats.MaxMs = math.max(Stats.MaxMs, Ms)
	end
	Stats.PeakWalkers = math.max(Stats.PeakWalkers, #List)
	if #List == 0 and Conn then
		Conn:Disconnect()
		Conn = nil
	end
end

-- ===== API =====
-- (debug) the rig's walk in progress, or nil
function Mover.Handle(Rig) return Active[Rig] end

function Mover.Place(Rig, TargetCFrame)
	local H = Active[Rig]
	if H then Cancel(H) end
	Put(Rig, TargetCFrame)
end

function Mover.WalkTo(Rig, TargetCFrame, Opts)
	Opts = Opts or {}
	local Old = Active[Rig]
	if Old then Cancel(Old) end
	local H = {Rig = Rig, Status = "walking", OnDone = Opts.OnDone, Cancel = Cancel, Target = TargetCFrame, Yields = 0, Replans = 0}
	Active[Rig] = H
	local Root = Rig:FindFirstChild("HumanoidRootPart")
	local Humanoid = Rig:FindFirstChildOfClass("Humanoid")
	if not (Root and Humanoid) then Finish(H, "failed") return H end
	Seq += 1
	H.Root, H.Humanoid, H.Seq = Root, Humanoid, Seq
	H.Id = tostring(Rig:GetAttribute("TownsfolkId") or Rig.Name)
	H.Speed = Opts.Speed or Humanoid.WalkSpeed
	H.Agent = Opts.Agent or Mover.Agent
	H.Goal = TargetCFrame.Position - Vector3.new(0, LIFT, 0) -- the ground under the standing root
	H.Steer = Vector3.zero
	local L = Flat(Root.CFrame.LookVector)
	H.Dir = L.Magnitude > 1e-3 and L.Unit or Vector3.new(0, 0, -1)
	H.SlowT, H.StuckReplans, H.SightAt, H.NextPlanAt = 0, 0, 0, 0
	ResetWindow(H, Root.Position, os.clock())
	Humanoid.WalkSpeed = H.Speed
	Humanoid.AutoRotate = false -- (the facing is ours: Facer)
	H.Facer = Facer(H)
	H.Facer.CFrame = CFrame.lookAt(Vector3.zero, H.Dir)
	H.Facer.Enabled = true
	Root.Anchored = false
	pcall(Root.SetNetworkOwner, Root, nil)
	-- a Humanoid held by an anchored root reads as Freefall and, once freed, drifts ~3 s before it lands: start it running
	Humanoid:ChangeState(Enum.HumanoidStateType.Running)
	table.insert(List, H)
	BodiesAt = 0 -- (a new walker: refresh the bodies on the next tick)
	if not Conn then Conn = RunService.Heartbeat:Connect(Tick) end
	Plan(H, "start")
	return H
end

return Mover

-- TownsfolkService.Mover (Region Foundation Task 5, 2026-10-23; crowd movement Task 5b, owner: "I want the townsfolk
-- pathfinding to be the best you can make it x1000, I don't want them to walk through each other"). ALL townsfolk
-- walking lives here, behind two calls; TownsfolkService calls only WalkTo and Place.
--   * Mover.WalkTo(Rig, TargetCFrame, Opts) -> Handle
--       Walks the rig to TargetCFrame (a standing CFrame: root position + facing). Opts (all optional): Speed (default
--       Humanoid.WalkSpeed; Mover.UrgentSpeed when Urgent), Agent (CreatePath params, default Mover.Agent), Urgent (Task 6:
--       someone running from a fight, see 4b), OnDone(Result) where Result is
--       "arrived" | "failed" | "cancelled". Handle: {Status = "walking" | Result, Cancel = function(self)}; a newer
--       WalkTo / Place on the same rig cancels the older walk. "failed" leaves the rig standing where it is (the caller
--       decides); an error inside a walk ends it "failed" with the rig held still, upright.
--       Debug fields on the handle: Waypoints (the smoothed path), RawWaypoints (count before smoothing), Radius
--       (agent radius used), Yields, Replans, Detours, Why (why it failed).
--   * Mover.Place(Rig, TargetCFrame): cancels any walk, anchors the root and puts the rig exactly there.
--   * Mover.Stop(Rig) (Task 6b): ends the rig's walk "cancelled" where it stands WITHOUT placing it: the root is left
--     unanchored, the facing constraint off, AutoRotate back on, no more Humanoid:Move. For a townsperson who is hit,
--     knocked, gripped or carried: the combat code owns the body from then on.
--   * Suspension (Task 6b; the rule is Mover.Pinned(Rig)): a walk whose rig is pinned (Knocked / GrippedBy / CarriedBy, PlatformStand, a Physics /
--     Ragdoll / FallingDown / PlatformStanding state, or MoverManager's Movement slow-or-pin active) is held: no
--     steering, the facing constraint off (it would fight knockback spin and knockdown tilt), the root never
--     re-anchored, and the stuck clock held. When the rig is free again the walk resumes at its own speed.
--   * Mover.Handle(Rig) -> the walk in progress (debug), or nil.
--   * Mover.P99StepMs() -> the 99th-percentile steering tick of the last 1000 (sorted on demand).
--   * Mover.Stats() -> {Walkers, StepMs, MaxStepMs, HeartbeatMs, Ticks, PeakWalkers, Yields, Replans, Sidesteps,
--       Fails, Arrivals, PostWaits, Detours, GiveWays (yields to urgent walkers, also counted in Yields), Repairs (plans
--       whose path needed the corner repair, 1b), RepairVertices, RepairMs, MaxRepairMs, RepairRefusedGround /
--       RepairRefusedCost (repair spots refused by the ground check: no ground or a drop / dearer ground)};
--       Mover.ResetStats(). StepMs = average time of one steering tick (all walkers).
--   * Mover.PlanPath(From, Goal, Agent, Opts) (Foundry Yard plan Task 4b): the planning a walk does (1, 1b and 2: the
--       real Compute, Repair and Smooth), with no rig. From = where a standing root is (Vector3); Goal = a standing
--       CFrame or root position (as WalkTo's TargetCFrame); Agent defaults to Mover.Agent; Opts.Attempts (default 8,
--       as a walk) caps the re-asks of 1b. Returns {Status = "ok" | "failed", Why, Waypoints (smoothed), Raw (the
--       planned points before smoothing, repaired), RawCount, Radius, Inserted (the repair's new vertices), Ms}.
--   * Mover.RepairPath(Pts, Labels) (Task 4b, tests): the corner repair (1b) of a polyline of ground points, exactly as
--       a plan runs it: a path that passes Valid comes back as it is; else the repaired points and the new vertices, or
--       nil and "stale". Labels (optional, Foundry Yard plan Task 9) are the points' waypoint labels (material names),
--       as a planned path carries them; without them every point counts as ordinary ground.
--
-- How a walk works (Task 5b; every number below is a PROPOSAL):
--   1. Path planning: PathfindingService with Mover.Agent (radius 2.5, height 5.5, no jumping or climbing, a
--      waypoint every 4 studs) and Mover.Costs (streets cheapest, grass dearer, water and mud avoided). Labels of
--      PathfindingModifiers the builders add are looked up in the same Costs table. A 5-stud door has no path at
--      radius 2.5, so Mover.NarrowRadii are tried next, both when there is no path and when the path is a long way
--      round (a narrower path 25% shorter wins: people use the door). A path whose segments run through geometry
--      (Valid: a waist-height ray along each leg), or where a walker's body would touch something (BodyClear), is
--      repaired (1b); one the repair can't fix (the navmesh hasn't caught up with a change yet) is refused and asked
--      for again, every 0.5 s, 8 times at most, each re-ask with another waypoint spacing (ReaskSpacings: a settled
--      navmesh gives the same path to the same question, and other spacings give other legs to repair).
--   1b. Corner repair (Foundry Yard plan Task 4b, Ruling 30): PathfindingService's rare long legs (over 4.5 studs,
--      mostly where the ground surface changes) cut convex building corners at waist height and run through thin
--      colliders (lamp and stall posts) the navmesh doesn't see. For each leg Valid's ray hits: the colliding parts
--      within RepairReach of the leg, the deepest point of the leg against their union (signed distance), and a new
--      vertex pushed out from it along the distance gradient to RepairClearances (2, then 1.5, then 1.25 studs) past
--      the surface; when something sticking out there (a downpipe, a door leaf) is nearer, it moves on by the
--      shortfall, RepairMarch times at most. The vertex needs walkable ground within RepairStep of the leg's height
--      (not water) and clearance to the geometry around it of at least (that clearance - RepairTolerance), never under
--      the last of them (1.25: Ruling 30's minimum, so no vertex sits in a gap under 2.5 studs), and both new legs
--      need walkable ground all along (smoothing's ground rays: a trench or a drop beside a corner refuses the vertex),
--      no dearer (Costs) than the ground at that leg's own ends (their labels; Task 9: no longer the dearest ground
--      anywhere on the path), or ordinary ground (RepairGroundCost).
--      When no spot along the gradient will do (or there is no gradient: a post dead on the line), the vertex is pushed
--      out square to the leg, either side (the street side of a stall post whose gradient side is the stall); a side
--      landing inside a solid part is given up (a wall, not a post). The legs are re-checked
--      from that one; at most RepairMax vertices a path. The result must pass Valid, else the path stays stale (a path
--      through a solid wall is still refused). Budget() runs between legs.
--      The body (measured 2026-10-25 in Play_FoundryWalks: walkers whose centre line passed a lamp post, a stall post or
--      a house's plinth and downpipes stuck there): a leg also needs the repair when a sphere of BodyRadius (1, half
--      the 2-stud root) swept down it at waist height hits something, leaving out BodyEndClear (3) round the path's
--      own start and goal (posts stand beside counters and carts). For such a leg, a waypoint at either end of it that
--      is closer than 1.25 to something (PathfindingService leaves corner waypoints 0.04-1.8 studs from walls) is
--      eased off first, along the gradient to the same clearances (each one once; never the path's ends); else a
--      vertex is inserted as above. The repaired path must pass BodyClear too.
--   2. Smoothing: each waypoint the walker can skip safely is dropped: a 1.5-radius spherecast at waist height
--      between the kept points is clear, and a ground ray every 2 studs finds walkable ground within 3 studs of the
--      line, never dearer (Costs) than the ground the path itself used. Open squares become straight lines. One
--      shortcut spans at most 60 studs, found by galloping search; all planning shares 2 ms a frame (PlanBudgetMs).
--   3. Steering, 10 Hz on Heartbeat, walking townsfolk only (nothing runs while nobody walks): the desired velocity
--      points at the next waypoint at the walk speed, slowing over the last 4 studs. Every townsperson, player and
--      other character within 10 studs is checked: if the closest approach over the next 1.5 s would be under
--      Clearance, the walker side-steps, passing on the RIGHT by convention when it is head-on (so two walkers never
--      dodge into each other), otherwise away from the side the other is on. Closer than Separation pushes apart, and
--      nobody walks into a body ahead in its lane (it slows to that body's pace, then stops short). The result goes
--      to Humanoid:Move, smoothed, so the facing (AutoRotate) turns smoothly.
--   4. Narrow spots: two walkers blocked head-on (both under 1 stud/s for 0.75 s, facing each other within 4 studs):
--      the one with the lower priority (further from its goal, then the higher Id) steps back and to its right; in an
--      alley with no room to the side it backs out along its own breadcrumbs until there is. It waits until the other
--      has gone past it (along the way it wants to go), then carries on.
--   4b. Urgent walkers (Task 6: fleeing a fight; not polite): an urgent walker never gives way to a normal one, runs
--      at UrgentSpeed (16), side-steps only for a closer miss (UrgentClearance), keeps a narrower lane and hard gap,
--      and has priority over every normal walker. A normal walker with an urgent one coming at it (ahead of it in its
--      lane, within GiveWayDist or GiveWayLead seconds of it) steps aside AT ONCE - in the same steering tick, its
--      forward steer dropped - the same way it gives way in a door, to the clear spot farthest from the urgent
--      walker's way (off it when there is one), and waits until it has gone past. Two urgent walkers settle a
--      head-on block between them by the usual priority.
--   5. Re-planning: Path.Blocked ahead, or a wall appearing between the walker and its next waypoint, re-plans from
--      where it stands. The sight check (Task 4b) is Valid's rule: a ray from the walker's waist to the next waypoint's
--      waist height, SightRange studs at most. Stuck (under 0.5 studs of progress in 1.5 s, not just queueing behind
--      someone moving): step sideways, then re-plan; the 4th time without real progress in between, the walk ends
--      "failed". (Task 4b) A sight or blocked re-plan doesn't restart the stuck window, and one made less than
--      ReplanProgress studs from where the last plan was made counts as a stuck event too (a re-plan loop is stuck).
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
local CollectionService = game:GetService("CollectionService")

local Loco do
	local Ok, Tuning = pcall(require, ReplicatedStorage.Modules.Data.Rensei.TuningConfig)
	Loco = Ok and Tuning.Locomotion or {Min = 0.5, Max = 1.6, Design = {Walk = 12}}
end

local Mover = {}
-- ===== tuning (all PROPOSALS) =====
Mover.Agent = {AgentRadius = 2.5, AgentHeight = 5.5, AgentCanJump = false, AgentCanClimb = false, WaypointSpacing = 4}
Mover.NarrowRadii = {2, 1.5} -- tried in turn when there's no path at the agent's radius (a 5-stud door needs 2)...
Mover.SqueezeRadius = 1 -- the last resort, only when no path exists at any of those: half a torso, squeezing between
-- crates (never chosen as a short cut: a 2-stud gap wedges an R6 whose arms are 4 across)
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
Mover.SlowRadius = 4 -- slows down over the last studs to the goal (at a stroll, 8; faster walkers start further out)
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
Mover.MaxDetours = 8 -- local routes in one walk at most
Mover.SmoothReach = 60 -- one smoothing shortcut spans at most this many studs...
Mover.SmoothSkip = 16 -- ...and this many raw waypoints
Mover.PlanBudgetMs = 2 -- planning work (all walkers together) per frame; more waits for the next frame
Mover.ModifierTag = "RenseiPathModifier" -- PathfindingModifiers added at runtime outside World.Map: tag them (or their part)
Mover.BlockedSpeed = 1 -- head-on block: both slower than this...
Mover.BlockedTime = 0.75 -- ...for this long...
Mover.FacingDist = 4 -- ...within this distance, facing each other
Mover.YieldBack = 1.5 -- the yielder steps back this far and...
Mover.YieldSide = 2.5 -- ...this far to its right
Mover.YieldMax = 15 -- s: never yields longer than this (backing out of an alley takes a while)
Mover.StepHeight = 1.5 -- a side spot this much higher or lower than where the walker stands is no pocket
Mover.TrailStep = 1 -- studs between the breadcrumbs a walker leaves (the way back out of an alley)...
Mover.TrailLength = 40 -- ...and how many it keeps
Mover.OccupiedRadius = 2 -- someone this close to a post occupies it
Mover.WaitSide = 1.5 -- the waiting spot: this far clear of the occupant's shoulder
Mover.WaitMax = 5 -- s: re-check the post at least this often...
Mover.WaitCap = 20 -- s: ...and give up ("failed") after this long
Mover.WalkDesign = (Loco.Design and Loco.Design.Walk) or 12 -- the shared walk is designed at this ground speed
-- urgent walkers (Task 6, header 4b; PROPOSALS)
Mover.UrgentSpeed = 16 -- running from a fight (a player's walk speed)
Mover.UrgentClearance = 2.5 -- side-steps only for a closer miss than this (normal: Clearance 4)
Mover.UrgentLane = 2.4 -- only a body this close to its line holds it up (normal: LaneWidth 3.6 / ContactGap 2.4)
Mover.UrgentHardGap = 2.2 -- never closer than this to a moving body (normal: HardGap 2.8): brushing past is fine
Mover.GiveWayDist = 14 -- a normal walker this close ahead of an urgent one, in its lane, steps aside at once...
Mover.GiveWayLead = 1.75 -- ...or (Lindenmoor import Task 8 fix round 2, PROPOSAL) once the urgent one would reach it
-- within this many seconds: the reach is max(GiveWayDist, its speed x GiveWayLead), so a fast runner is seen in time
Mover.YieldWide = 4 -- giving way to an urgent walker: the wider side spots tried (studs) when 2.5 is still in its lane
-- corner repair (Foundry Yard plan Task 4b, header 1b; Ruling 30; PROPOSALS)
Mover.RepairClearances = {2, 1.5, 1.25} -- a new vertex this far past the surface (tried in turn)...
Mover.RepairTolerance = 0.3 -- ...with at least (that - this) of clearance to everything around it (never under the last)
Mover.RepairMax = 12 -- new vertices in one path at most
Mover.RepairReach = 4 -- the colliding parts within this of a leg (and of a new vertex) are measured
Mover.RepairStep = 1.5 -- a new vertex's ground is within this of the leg's height
Mover.RepairMarch = 3 -- a vertex short of its clearance (something sticking out near it) moves on this many times at most
Mover.ReaskSpacings = {3, 6, 5, 2.5, 3.5, 4.5, 2} -- (fix round 1) waypoint spacings for the re-asks after a stale path
Mover.RepairGroundCost = 1.5 -- (fix round 1) a repaired leg may always cross ground this cheap (Ground, WoodPlanks)...
-- ...and dearer ground (Grass, Mud, Water) only where the planned path itself walks it
Mover.ReplanProgress = 10 -- (header 5) a sight or blocked re-plan this close to the last plan's start is a stuck event
Mover.BodyRadius = 1 -- (header 1b) a leg also needs the repair when a sphere this wide (half the 2-stud root) swept at
-- waist height along it hits something: Valid's ray is the body's centre line only, and walkers stuck on lamp posts,
-- stall posts and house plinths whose centre line passed them (measured 2026-10-25, Play_FoundryWalks)
Mover.BodyEndClear = 3 -- ...except within this of the path's own start and goal (posts stand beside counters and carts)

local UP = Vector3.new(0, 1, 0)
local LIFT = 3 -- R6 root height above the ground

local Active = {} -- [Rig] = Handle
local List = {} -- walking handles, in start order
local Tracks = {} -- [Rig] = walk AnimationTrack | false
local OthersGoalNear, WaitSpot -- (defined with the waiting logic below)
local Seq = 0
local UrgentCount = 0 -- urgent walkers walking (counted each tick; header 4b)
local InUrgentWay -- (defined with the steering below)

local Stats
function Mover.ResetStats()
	Stats = {Ticks = 0, Ms = 0, MaxMs = 0, Heartbeats = 0, HeartbeatMs = 0, PeakWalkers = 0, Yields = 0, Replans = 0,
		Sidesteps = 0, Fails = 0, Arrivals = 0, PostWaits = 0, Detours = 0, Plans = 0, PlanMs = 0, MaxPlanMs = 0,
		MaxPlanFrameMs = 0, Routes = 0, RouteMs = 0, MaxRouteMs = 0, WorstTick = "", Times = {}, TimeAt = 0, GiveWays = 0,
		Repairs = 0, RepairVertices = 0, RepairMs = 0, MaxRepairMs = 0, RepairRefusedGround = 0, RepairRefusedCost = 0}
end
Mover.ResetStats()

-- StepMs: one steering tick (all walkers); PlanMs: one plan's own work (its waits for the pathfinder and for the
-- frame budget excluded); MaxPlanFrameMs: all planning in one frame; RouteMs: one local route
function Mover.Stats()
	return {
		Walkers = #List, StepMs = Stats.Ticks > 0 and Stats.Ms / Stats.Ticks or 0, MaxStepMs = Stats.MaxMs,
		HeartbeatMs = Stats.Heartbeats > 0 and Stats.Ms / Stats.Heartbeats or 0, Ticks = Stats.Ticks, TotalMs = Stats.Ms,
		PeakWalkers = Stats.PeakWalkers, Yields = Stats.Yields, Replans = Stats.Replans, Sidesteps = Stats.Sidesteps,
		Fails = Stats.Fails, Arrivals = Stats.Arrivals, PostWaits = Stats.PostWaits, Detours = Stats.Detours,
		Plans = Stats.Plans, PlanMs = Stats.Plans > 0 and Stats.PlanMs / Stats.Plans or 0, MaxPlanMs = Stats.MaxPlanMs,
		MaxPlanFrameMs = Stats.MaxPlanFrameMs, Routes = Stats.Routes,
		RouteMs = Stats.Routes > 0 and Stats.RouteMs / Stats.Routes or 0, MaxRouteMs = Stats.MaxRouteMs,
		WorstTick = Stats.WorstTick, GiveWays = Stats.GiveWays,
		Repairs = Stats.Repairs, RepairVertices = Stats.RepairVertices,
		RepairMs = Stats.Repairs > 0 and Stats.RepairMs / Stats.Repairs or 0, MaxRepairMs = Stats.MaxRepairMs,
		RepairRefusedGround = Stats.RepairRefusedGround, RepairRefusedCost = Stats.RepairRefusedCost,
	}
end

-- the 99th percentile steering tick over the last Mover.TimeRing ticks (sorted on demand: call it now and then)
Mover.TimeRing = 1000
function Mover.P99StepMs()
	local T = table.clone(Stats.Times)
	table.sort(T)
	return T[math.max(1, math.ceil(#T * 0.99))] or 0
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

-- PathfindingModifier volumes, so smoothing never cuts across ground the builders made dearer. Cached once, lazily on
-- the first walk: the map's own modifiers (World.Map), plus any instance tagged Mover.ModifierTag (a modifier, or a
-- part / model holding modifiers) as it is tagged or untagged. Each entry keeps its parts and a world bounding box.
local Modifiers = {} -- [PathfindingModifier] = {Label, PassThrough, Parts = {{CFrame, Size}}, Min, Max, Source}
local ModifiersReady = false

local function Extents(CF, Size) -- half-size of a part's world-axis bounding box
	local S, R, U, L = Size / 2, CF.RightVector, CF.UpVector, CF.LookVector
	return Vector3.new(
		math.abs(R.X) * S.X + math.abs(U.X) * S.Y + math.abs(L.X) * S.Z,
		math.abs(R.Y) * S.X + math.abs(U.Y) * S.Y + math.abs(L.Y) * S.Z,
		math.abs(R.Z) * S.X + math.abs(U.Z) * S.Y + math.abs(L.Z) * S.Z)
end

local function CacheModifier(M, Source)
	local Parent = M.Parent
	if not Parent then return end
	local Parts, Min, Max = {}, Vector3.one * math.huge, -Vector3.one * math.huge
	for _, P in ipairs(Parent:IsA("BasePart") and {Parent} or Parent:GetDescendants()) do
		if P:IsA("BasePart") then
			table.insert(Parts, {P.CFrame, P.Size})
			local E = Extents(P.CFrame, P.Size)
			Min, Max = Min:Min(P.Position - E), Max:Max(P.Position + E)
		end
	end
	if #Parts > 0 then Modifiers[M] = {Label = M.Label, PassThrough = M.PassThrough, Parts = Parts, Min = Min, Max = Max, Source = Source} end
end

local function CacheTagged(I)
	if I:IsA("PathfindingModifier") then CacheModifier(I, I) return end
	for _, D in ipairs(I:GetDescendants()) do
		if D:IsA("PathfindingModifier") then CacheModifier(D, I) end
	end
end

-- The map's modifiers are found by walking World.Map a chunk at a time (ScanChunk instances a frame), in its own
-- thread, so the first walk never waits for it (smoothing simply sees no modifiers until it is done). When World.Map
-- is replaced (a region loads), the map's entries are dropped and the new map is scanned.
Mover.ScanChunk = 1000 -- (instances a frame: ~1.5 ms on Ye)
Mover.ScanInfo = {Instances = 0, Ms = 0, MaxSliceMs = 0, Done = false} -- (debug: the last map scan's cost)
local ScanGen = 0
local function ScanMap(Map)
	ScanGen += 1
	local Gen = ScanGen
	for M, E in pairs(Modifiers) do
		if E.FromMap then Modifiers[M] = nil end
	end
	if not Map then return end
	task.defer(function()
		local Stack, Seen = {Map}, 0
		local Info = {Instances = 0, Ms = 0, MaxSliceMs = 0, Done = false}
		Mover.ScanInfo = Info
		local Slice = os.clock()
		while #Stack > 0 do
			if Gen ~= ScanGen then return end -- (a newer map: that scan takes over)
			local I = table.remove(Stack)
			for _, C in ipairs(I:GetChildren()) do
				table.insert(Stack, C)
				if C:IsA("PathfindingModifier") then
					CacheModifier(C, C)
					if Modifiers[C] then Modifiers[C].FromMap = true end
				end
			end
			Seen += 1
			if Seen % Mover.ScanChunk == 0 then
				local Ms = (os.clock() - Slice) * 1000
				Info.Ms += Ms
				Info.MaxSliceMs = math.max(Info.MaxSliceMs, Ms)
				task.wait()
				Slice = os.clock()
			end
		end
		local Ms = (os.clock() - Slice) * 1000
		Info.Ms += Ms
		Info.MaxSliceMs = math.max(Info.MaxSliceMs, Ms)
		Info.Instances, Info.Done = Seen, true
	end)
end

local function WatchModifiers()
	if ModifiersReady then return end
	ModifiersReady = true
	task.defer(function()
		local World = workspace:WaitForChild("World", 30)
		if not World then return end
		ScanMap(World:FindFirstChild("Map"))
		World.ChildAdded:Connect(function(C) if C.Name == "Map" then ScanMap(C) end end)
		World.ChildRemoved:Connect(function(C) if C.Name == "Map" then ScanMap(World:FindFirstChild("Map")) end end)
	end)
	for _, I in ipairs(CollectionService:GetTagged(Mover.ModifierTag)) do CacheTagged(I) end
	CollectionService:GetInstanceAddedSignal(Mover.ModifierTag):Connect(CacheTagged)
	CollectionService:GetInstanceRemovedSignal(Mover.ModifierTag):Connect(function(I)
		for M, E in pairs(Modifiers) do
			if E.Source == I then Modifiers[M] = nil end
		end
	end)
end

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

-- does the straight line A -> B (ground points) cross a modifier volume dearer than MaxCost? (bounding boxes first)
local function CrossesDearModifier(Costs, A, B, MaxCost)
	local Lo = A:Min(B) + Vector3.new(0, 0.5, 0)
	local Hi = A:Max(B) + Vector3.new(0, Mover.WaistHeight, 0)
	for _, E in pairs(Modifiers) do
		if E.PassThrough ~= true and Cost(Costs, E.Label) > MaxCost
			and Hi.X >= E.Min.X and Lo.X <= E.Max.X and Hi.Y >= E.Min.Y and Lo.Y <= E.Max.Y and Hi.Z >= E.Min.Z and Lo.Z <= E.Max.Z then
			for _, P in ipairs(E.Parts) do
				for _, Y in ipairs({0.5, Mover.WaistHeight}) do
					local Lift = Vector3.new(0, Y, 0)
					if SegmentHitsBox(P[1], P[2], A + Lift, B + Lift) then return true end
				end
			end
		end
	end
	return false
end

-- walkable ground all along A-B (ground points)? A ray every GroundStep finds ground within GroundDrop of the line,
-- flat enough, and no dearer (Costs) than MaxCost (smoothing's rule; Task 4b fix round 1: the repair's new legs too)
local function GroundAlong(Costs, A, B, MaxCost)
	local Len = Flat(B - A).Magnitude
	local N = math.max(1, math.ceil(Len / Mover.GroundStep))
	local Drop = Mover.GroundDrop
	for K = 1, N - 1 do
		local P = A:Lerp(B, K / N)
		local Hit = workspace:Raycast(P + Vector3.new(0, Drop, 0), Vector3.new(0, -2 * Drop, 0), Ground)
		if not Hit or Hit.Normal.Y < 0.7 or math.abs(Hit.Position.Y - P.Y) > Drop then return false, "ground" end
		if Cost(Costs, Hit.Material.Name) > MaxCost then return false, "cost" end
	end
	return true
end
-- (fix round 1) the repair's ground check on a new vertex or eased point's two legs, counted in Stats when it refuses
local function RepairGround(Costs, A, P, B, MaxCost)
	local Ok, Why = GroundAlong(Costs, A, P, MaxCost)
	if Ok then Ok, Why = GroundAlong(Costs, P, B, MaxCost) end
	if not Ok then
		if Why == "cost" then Stats.RepairRefusedCost += 1 else Stats.RepairRefusedGround += 1 end
	end
	return Ok
end

-- can a walker go straight from A to B (ground points)? see the header (2. Smoothing)
local function Safe(Costs, A, B, MaxCost)
	local D = B - A
	local Len = Flat(D).Magnitude
	if Len < 0.1 then return true end
	local Waist = Vector3.new(0, Mover.WaistHeight, 0)
	if workspace:Spherecast(A + Waist, Mover.SmoothRadius, D, Obstacles) then return false end
	if not GroundAlong(Costs, A, B, MaxCost) then return false end
	if next(Modifiers) and CrossesDearModifier(Costs, A, B, MaxCost) then return false end
	return true
end

-- is the raw path real? (a segment through geometry = the navmesh hasn't caught up, or a bogus jump). Budget
-- (optional, Task 4b) is called every 16 legs: a long path is hundreds of rays
local function Valid(Pts, Budget)
	local Waist = Vector3.new(0, Mover.WaistHeight, 0)
	for I = 1, #Pts - 1 do
		if Budget and I % 16 == 0 then Budget() end
		if workspace:Raycast(Pts[I] + Waist, Pts[I + 1] - Pts[I], Obstacles) then return false end
	end
	return true
end

local Tight = OverlapParams.new()
Tight.FilterType = Enum.RaycastFilterType.Exclude
Tight.RespectCanCollide = true

-- ===== corner repair (header 1b; Foundry Yard plan Task 4b) =====
local Near = OverlapParams.new() -- the colliding parts around a leg (the geometry filters of Obstacles)
Near.FilterType = Enum.RaycastFilterType.Exclude
Near.RespectCanCollide = true

-- a part as a signed-distance shape: {inverse CFrame, half size, kind, radius, the part, exact}. Blocks, balls and
-- cylinders by their shape (exact); anything else (wedges, meshes, unions) by its box, which is never smaller than the
-- part (a ramp's box stands over the slope people walk up: not exact)
local CYL, BALL, BOX = 1, 2, 3
local function Shape(P)
	local Kind, Exact = BOX, false
	if P.ClassName == "Part" then
		local S = P.Shape
		if S == Enum.PartType.Cylinder then Kind = CYL elseif S == Enum.PartType.Ball then Kind = BALL end
		Exact = S == Enum.PartType.Block or Kind ~= BOX
	end
	local H = P.Size / 2
	return {P.CFrame:Inverse(), H, Kind, Kind == CYL and math.min(H.Y, H.Z) or math.min(H.X, H.Y, H.Z), P, Exact}
end

local function Dist(S, X) -- signed distance from X to one shape (negative inside)
	local Q = S[1] * X
	local H = S[2]
	if S[3] == CYL then
		local Ax = math.abs(Q.X) - H.X
		local Rad = math.sqrt(Q.Y * Q.Y + Q.Z * Q.Z) - S[4]
		return Vector2.new(math.max(Ax, 0), math.max(Rad, 0)).Magnitude + math.min(math.max(Ax, Rad), 0)
	elseif S[3] == BALL then
		return Q.Magnitude - S[4]
	end
	local DX, DY, DZ = math.abs(Q.X) - H.X, math.abs(Q.Y) - H.Y, math.abs(Q.Z) - H.Z
	return Vector3.new(math.max(DX, 0), math.max(DY, 0), math.max(DZ, 0)).Magnitude + math.min(math.max(DX, DY, DZ), 0)
end

local function Field(Shapes, X) -- the union: the nearest surface
	local M = math.huge
	for _, S in ipairs(Shapes) do
		local D = Dist(S, X)
		if D < M then M = D end
	end
	return M
end

-- the colliding parts at body height (1 stud over the lower end's ground up to a standing head) within RepairReach of
-- the ground segment A-B, as shapes (no floors: they are under the box)
local function ShapesNear(A, B)
	local R = Mover.RepairReach
	local Lo = Vector3.new(math.min(A.X, B.X) - R, math.min(A.Y, B.Y) + 1, math.min(A.Z, B.Z) - R)
	local Hi = Vector3.new(math.max(A.X, B.X) + R, math.max(A.Y, B.Y) + 5.5, math.max(A.Z, B.Z) + R)
	Near.FilterDescendantsInstances = Obstacles.FilterDescendantsInstances
	Near.CollisionGroup = Obstacles.CollisionGroup
	local Out = {}
	for _, P in ipairs(workspace:GetPartBoundsInBox(CFrame.new((Lo + Hi) / 2), Hi - Lo, Near)) do
		if not P:IsA("Terrain") then table.insert(Out, Shape(P)) end
	end
	return Out
end

-- a new vertex for the leg A-B (ground points) whose waist ray hit Hit, or nil: see the header (1b)
-- Costs, MaxCost: the new legs A-V and V-B need walkable ground no dearer than MaxCost (GroundAlong): Repair passes
-- the dearer of the leg's two end labels, never under RepairGroundCost (LegCost)
local function RepairVertex(A, B, Hit, Budget, Costs, MaxCost)
	if Hit.Instance:IsA("Terrain") then return nil end -- (a terrain bump: no shapes to push off; the leg stays stale)
	local Waist = Vector3.new(0, Mover.WaistHeight, 0)
	local Shapes = ShapesNear(A, B)
	if #Shapes == 0 then return nil end
	local AW, BW = A + Waist, B + Waist
	-- the deepest point: every 0.25 studs, then every 0.05 around the best
	local Len = (BW - AW).Magnitude
	local N = math.max(2, math.ceil(Len / 0.25))
	local Best, BT = math.huge, 0
	for K = 0, N do
		if Budget and K % 8 == 7 then Budget() end -- (a long leg past a row of houses: hundreds of parts a sample)
		local D = Field(Shapes, AW:Lerp(BW, K / N))
		if D < Best then Best, BT = D, K / N end
	end
	local Fine = 0.05 / math.max(Len, 1e-3)
	for K = -5, 5 do
		local T = math.clamp(BT + K * Fine, 0, 1)
		local D = Field(Shapes, AW:Lerp(BW, T))
		if D < Best then Best, BT = D, T end
	end
	local Q = AW:Lerp(BW, BT)
	local E = 0.05
	local G = Vector3.new(Field(Shapes, Q + Vector3.new(E, 0, 0)) - Field(Shapes, Q - Vector3.new(E, 0, 0)), 0,
		Field(Shapes, Q + Vector3.new(0, 0, E)) - Field(Shapes, Q - Vector3.new(0, 0, E)))
	-- (fix round 1) along the gradient first; then out to either side of the leg, square to it: the other side of a post
	-- (the gradient side is a neighbouring stall's inside), or a post dead on the line (no gradient). A side that lands
	-- inside a solid part is given up (the thing is wider than the push: a wall, not a post)
	local Ways = {}
	if G.Magnitude >= 1e-4 then table.insert(Ways, G.Unit) end
	local Along = Flat(B - A)
	if Along.Magnitude >= 1e-3 then
		local Right = RightOf(Along.Unit)
		table.insert(Ways, Right)
		table.insert(Ways, -Right)
	end
	local Ladder = Mover.RepairClearances
	local Floor = Ladder[#Ladder]
	for N, Way in ipairs(Ways) do
		local Sideways = N > (G.Magnitude >= 1e-4 and 1 or 0)
		for _, C in ipairs(Ladder) do
			-- C past the surface it is pushed off; something else sticking out there (a downpipe, a door leaf) can leave
			-- it closer than C to that: it marches on along the gradient by the shortfall, RepairMarch more times at
			-- most (in a gap the shortfall only grows: no spot)
			local Need = math.max(C - Mover.RepairTolerance, Floor)
			local Push = math.max(0, -Best) + C
			for _ = 0, Mover.RepairMarch do
				if Budget then Budget() end
				local V = Q + Way * Push - Waist
				local Down = workspace:Raycast(V + Vector3.new(0, 3, 0), Vector3.new(0, -6, 0), Ground)
				if not (Down and Down.Normal.Y >= 0.7 and Down.Material ~= Enum.Material.Water and math.abs(Down.Position.Y - V.Y) <= Mover.RepairStep) then break end
				local P = Down.Position
				local Clear = Field(ShapesNear(P, P), P + Waist)
				if Clear >= Need then
					-- (fix round 1) both new legs on walkable ground (a trench or a drop beside the corner refuses it)
					if Costs and not RepairGround(Costs, A, P, B, MaxCost) then break end
					return P
				end
				if Sideways and Clear < 0 then break end
				Push += C - Clear + 0.05
				if Push > math.max(0, -Best) + C + Mover.RepairReach then break end
			end
		end
	end
	return nil
end

-- what the walker's body (BodyRadius at waist height) hits along the leg A-B, leaving out the parts of it within
-- BodyEndClear of the path's own ends From and To. A cast ignores what it starts inside, so the body where the sweep
-- starts is measured too (the signed distance): a leg setting off pressed against a post (a stall's side entry) is a
-- hit as well, reported as {Instance, Normal (away from it), Position}.
local function BodyHit(A, B, From, To)
	local D = B - A
	local Len = D.Magnitude
	if Len < 1e-3 then return nil end
	local Clear = Mover.BodyEndClear
	local T0, T1 = 0, 1
	-- (the ends' balls cut the leg where it runs within Clear of them, flat)
	local function Cut(E)
		local Along = Flat(E - A):Dot(Flat(D)) / math.max(Flat(D):Dot(Flat(D)), 1e-6)
		local Off = FlatDist(A:Lerp(B, math.clamp(Along, 0, 1)), E)
		if Off >= Clear then return end
		local Half = math.sqrt(Clear * Clear - Off * Off) / math.max(Flat(D).Magnitude, 1e-6)
		local Lo, Hi = Along - Half, Along + Half
		if Lo <= T0 then T0 = math.max(T0, Hi) end
		if Hi >= T1 then T1 = math.min(T1, Lo) end
	end
	Cut(From)
	Cut(To)
	if T1 - T0 <= 1e-3 then return nil end
	local Waist = Vector3.new(0, Mover.WaistHeight, 0)
	local S = A:Lerp(B, T0)
	local SW = S + Waist
	local Best, Who = math.huge, nil
	for _, Sh in ipairs(ShapesNear(S, S)) do
		if Sh[6] then -- (exact shapes only: a ramp's box would stand over its slope)
			local D = Dist(Sh, SW)
			if D < Best then Best, Who = D, Sh end
		end
	end
	if Who and Best < Mover.BodyRadius then
		local E = 0.05
		local N = Vector3.new(Dist(Who, SW + Vector3.new(E, 0, 0)) - Dist(Who, SW - Vector3.new(E, 0, 0)), 0,
			Dist(Who, SW + Vector3.new(0, 0, E)) - Dist(Who, SW - Vector3.new(0, 0, E)))
		return {Instance = Who[5], Normal = N.Magnitude > 1e-4 and N.Unit or Vector3.zero, Position = SW}
	end
	return workspace:Spherecast(SW, Mover.BodyRadius, A:Lerp(B, T1) - S, Obstacles)
end

-- is every leg of Pts clear for the walker's body? (Pts[1] and Pts[#Pts] are the path's ends.) Budget (optional) is
-- called between legs: a long path is hundreds of them
local function BodyClear(Pts, Budget)
	for I = 1, #Pts - 1 do
		if Budget then Budget() end
		if BodyHit(Pts[I], Pts[I + 1], Pts[1], Pts[#Pts]) then return false end
	end
	return true
end

-- (body) an existing waypoint closer than the repair's floor (1.25) to something at waist height (PathfindingService
-- leaves corner waypoints 0.04-1.8 studs from walls): moved off it along the distance gradient to RepairClearances,
-- where there is ground, as a new vertex would be; nil when it is clear enough already or can't be moved
-- Prev, Next, Costs, MaxCost: the legs Prev-P and P-Next need walkable ground (GroundAlong) after the move, no dearer
-- than MaxCost (Repair passes the dearest of the three points' labels, never under RepairGroundCost)
local function Ease(P, Budget, Prev, Next, Costs, MaxCost)
	local Waist = Vector3.new(0, Mover.WaistHeight, 0)
	local Q = P + Waist
	local Shapes = ShapesNear(P, P)
	if #Shapes == 0 then return nil end
	local Here = Field(Shapes, Q)
	local Ladder = Mover.RepairClearances
	local Floor = Ladder[#Ladder]
	if Here >= Floor then return nil end
	local E = 0.05
	local G = Vector3.new(Field(Shapes, Q + Vector3.new(E, 0, 0)) - Field(Shapes, Q - Vector3.new(E, 0, 0)), 0,
		Field(Shapes, Q + Vector3.new(0, 0, E)) - Field(Shapes, Q - Vector3.new(0, 0, E)))
	if G.Magnitude < 1e-4 then return nil end
	G = G.Unit
	for _, C in ipairs(Ladder) do
		local Need = math.max(C - Mover.RepairTolerance, Floor)
		local Push = C - Here
		for _ = 0, Mover.RepairMarch do
			if Budget then Budget() end
			local V = Q + G * Push - Waist
			local Down = workspace:Raycast(V + Vector3.new(0, 3, 0), Vector3.new(0, -6, 0), Ground)
			if not (Down and Down.Normal.Y >= 0.7 and Down.Material ~= Enum.Material.Water and math.abs(Down.Position.Y - V.Y) <= Mover.RepairStep) then break end
			local NP = Down.Position
			local Clear = Field(ShapesNear(NP, NP), NP + Waist)
			if Clear >= Need then
				if Costs and not RepairGround(Costs, Prev, NP, Next, MaxCost) then break end
				return NP
			end
			Push += C - Clear + 0.05
			if Push > C - Here + Mover.RepairReach then break end
		end
	end
	return nil
end

-- the repair of a path that fails Valid or BodyClear: Pts (ground points), Labels and RawIdx (each point's index in
-- the path's own waypoints) with the new vertices inserted, and the vertices; nil when a leg can't be repaired or
-- RepairMax is used up. Budget (optional) is called between legs.
local function Repair(Pts, Labels, RawIdx, Budget, Costs)
	local Out, OL, OR, Tried = table.clone(Pts), {}, {}, {}
	for K = 1, #Pts do OL[K], OR[K], Tried[K] = Labels[K] or false, RawIdx[K] or K, false end
	local Added = {}
	local Waist = Vector3.new(0, Mover.WaistHeight, 0)
	local From, To = Pts[1], Pts[#Pts]
	-- (fix round 1; Task 9: per leg) the new legs' ground may be no dearer than the ground the planned path walks at
	-- that leg's own ends (their labels), and never less than RepairGroundCost: a corner pushed off a cobbled street
	-- onto plain Ground is fine, one into grass, mud or water off a street is not, even when the path crosses a lawn
	-- somewhere else
	local function LegCost(...)
		local M = Mover.RepairGroundCost
		for _, K in ipairs({...}) do
			if OL[K] ~= nil then M = math.max(M, Cost(Costs, OL[K])) end
		end
		return M
	end
	local I = 1
	while I < #Out do
		if Budget then Budget() end
		local A, B = Out[I], Out[I + 1]
		local Hit = workspace:Raycast(A + Waist, B - A, Obstacles) -- (Valid's ray)
		local Body = not Hit and BodyHit(A, B, From, To) -- (the body)
		if Hit or Body then
			-- a body hit next to a waypoint hugging something: that waypoint moves off it first (each one once; never
			-- the path's ends); moving Out[I] changes leg I - 1 too, so the check steps back one leg
			local Eased = false
			if Body then
				for _, K in ipairs({I + 1, I}) do
					if K > 1 and K < #Out and not Tried[K] then
						Tried[K] = true
						local NP = Ease(Out[K], Budget, Out[K - 1], Out[K + 1], Costs, LegCost(K - 1, K, K + 1))
						if NP then Out[K], Eased = NP, true break end
					end
				end
			end
			if Eased then
				I = math.max(1, I - 1)
			else
				if #Added >= Mover.RepairMax then return nil end
				local V = RepairVertex(A, B, Hit or Body, Budget, Costs, LegCost(I, I + 1))
				if not V then return nil end
				table.insert(Out, I + 1, V)
				table.insert(OL, I + 1, OL[I])
				table.insert(OR, I + 1, OR[I + 1]) -- (Path.Blocked: a vertex belongs to the leg's far end)
				table.insert(Tried, I + 1, true)
				table.insert(Added, V)
			end
		else
			I += 1
		end
	end
	return Out, OL, OR, Added
end

-- Valid and BodyClear, else the repair (whose result must pass both too): Pts, Labels, RawIdx, Added ({} when nothing
-- was needed), or nil (stale)
local function Mend(Pts, Labels, RawIdx, Budget, Costs)
	if Valid(Pts, Budget) and BodyClear(Pts, Budget) then return Pts, Labels, RawIdx, {} end
	local T0, Waited = os.clock(), 0
	local Wait = Budget and function()
		local T1 = os.clock()
		Budget()
		Waited += os.clock() - T1
	end
	local Out, OL, OR, Added = Repair(Pts, Labels, RawIdx, Wait, Costs or Mover.Costs)
	if Out and not (Valid(Out, Wait) and BodyClear(Out, Wait)) then Out = nil end
	local Ms = (os.clock() - T0 - Waited) * 1000 -- (its own work: the budget's waits left out)
	Stats.Repairs += 1
	Stats.RepairMs += Ms
	Stats.MaxRepairMs = math.max(Stats.MaxRepairMs, Ms)
	if Out then Stats.RepairVertices += #Added end
	return Out, OL, OR, Added
end

-- string-pulling: from each kept point, keep the furthest point it can reach safely. A point already within the
-- spherecast's radius of geometry (a walker pressed against a door jamb) skips nothing: a cast that starts inside a
-- part doesn't see it, and the raw path is what leads it out.
-- A shortcut spans at most SmoothReach studs / SmoothSkip waypoints, and the furthest one is found by galloping
-- (2, 4, 8 ... ahead) then halving, so a long boulevard costs a few dozen checks, not thousands of rays. Budget() is
-- called between checks (the per-frame planning budget).
local function Smooth(Costs, Pts, Labels, Budget)
	local Out, Orig = {Pts[1]}, {1}
	Tight.FilterDescendantsInstances = Obstacles.FilterDescendantsInstances
	Tight.CollisionGroup = Obstacles.CollisionGroup
	local I = 1
	while I < #Pts do
		local Lo = I + 1 -- the furthest point known to be reachable
		local Wedged = #workspace:GetPartBoundsInRadius(Pts[I] + Vector3.new(0, Mover.WaistHeight, 0), Mover.SmoothRadius, Tight) > 0
		if not Wedged then
			local function Reachable(J)
				if J - I > Mover.SmoothSkip or FlatDist(Pts[I], Pts[J]) > Mover.SmoothReach then return false end
				local MaxCost = 1
				for K = I, J do MaxCost = math.max(MaxCost, Cost(Costs, Labels[K])) end
				if Budget then Budget() end
				return Safe(Costs, Pts[I], Pts[J], MaxCost)
			end
			local Hi, Step = nil, 2
			while true do
				local J = math.min(I + Step, #Pts)
				if J <= Lo then break end
				if Reachable(J) then
					Lo = J
					if J == #Pts then break end
					Step *= 2
				else
					Hi = J
					break
				end
			end
			while Hi and Hi - Lo > 1 do
				local M = (Lo + Hi) // 2
				if Reachable(M) then Lo = M else Hi = M end
			end
		end
		table.insert(Out, Pts[Lo])
		table.insert(Orig, Lo)
		I = Lo
	end
	return Out, Orig
end

-- a clear, walkable spot from P (root position) to Spot (root height)? (side-steps, yields, waiting spots) Nothing in
-- the way, no one there, and ground the walker can stand on and walk back from: not water, no dearer (Costs) than the
-- ground it stands on now, and no more than StepHeight up or down (it can't jump or climb back)
local function SpotClear(H, P, Spot)
	local D = Spot - P
	if D.Magnitude > 0.05 and workspace:Spherecast(P - Vector3.new(0, LIFT - Mover.WaistHeight, 0), 1, D, Obstacles) then return false end
	local Down = Vector3.new(0, -(LIFT + Mover.GroundDrop), 0)
	local Hit = workspace:Raycast(Spot, Down, Ground)
	if not Hit or Hit.Normal.Y < 0.7 or Hit.Material == Enum.Material.Water then return false end
	local Here = workspace:Raycast(P, Down, Ground)
	local HereY = Here and Here.Position.Y or (P.Y - LIFT)
	if math.abs(Hit.Position.Y - HereY) > Mover.StepHeight then return false end
	local Costs = (H.Agent and H.Agent.Costs) or Mover.Costs
	local function C(M) return Costs[M.Name] or Mover.Costs[M.Name] or 1 end
	if C(Hit.Material) > math.max(1, Here and C(Here.Material) or 1) then return false end
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
	local Conn
	Conn = Rig.AncestryChanged:Connect(function()
		if not Rig.Parent then
			Tracks[Rig] = nil
			Conn:Disconnect()
		end
	end)
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

-- (Task 6b) the rig is held by combat: knocked, gripped, carried, tripped, ragdolled, or slowed / pinned by a hit
local PINNED_STATES = {
	[Enum.HumanoidStateType.Physics] = true, [Enum.HumanoidStateType.Ragdoll] = true,
	[Enum.HumanoidStateType.FallingDown] = true, [Enum.HumanoidStateType.PlatformStanding] = true,
}
-- Mover.Pinned(Rig): the one place this rule lives (TownsfolkService's Free uses it too, with the WCS stun on top)
function Mover.Pinned(Rig)
	local Hum = Rig:FindFirstChildOfClass("Humanoid")
	if not Hum then return true end
	return Hum.PlatformStand or PINNED_STATES[Hum:GetState()] == true or Rig:GetAttribute("Knocked") == true
		or Rig:GetAttribute("GrippedBy") ~= nil or Rig:GetAttribute("CarriedBy") ~= nil
		or (tonumber(Rig:GetAttribute("Movement")) or 0) > 0
end
local function Pinned(H) return Mover.Pinned(H.Rig) end

local function ResetWindow(H, P, Now)
	H.WinPos, H.WinT, H.Excused, H.SlowT, H.SlowRef = P, Now, false, 0, nil
end

-- ===== the planning budget =====
-- Plans run in their own threads. Their own work (not their waits) is timed per plan, and all of it shares
-- PlanBudgetMs per frame: once the frame's budget is spent, a plan waits for the next frame at its next check, so a
-- schedule change that sends everyone walking at once can't stall one frame.
local FrameNo = 0 -- counts physics frames (PreSimulation) while anyone walks
local PlanFrame, PlanFrameSpent = -1, 0
local Conn -- the Heartbeat connection (only while someone walks)
local FrameConn -- the frame counter for the planning budget (likewise)

local function NewClock() return {Spent = 0, Mark = os.clock()} end

local function Spend(Clock)
	local Now = os.clock()
	local D = Now - Clock.Mark
	Clock.Mark, Clock.Spent = Now, Clock.Spent + D
	if PlanFrame ~= FrameNo then PlanFrame, PlanFrameSpent = FrameNo, 0 end
	PlanFrameSpent += D
	-- (fix round 1) only while someone walks: FrameNo only counts frames then, and PlanPath's work with nobody walking
	-- (tests) would otherwise pile into one "frame"
	if Conn then Stats.MaxPlanFrameMs = math.max(Stats.MaxPlanFrameMs, PlanFrameSpent * 1000) end
end

local function PlanWait(Clock, Seconds) -- a wait inside a plan (not its own work)
	Spend(Clock)
	task.wait(Seconds)
	Clock.Mark = os.clock()
end

local function Budget(Clock)
	Spend(Clock)
	while Conn and PlanFrame == FrameNo and PlanFrameSpent * 1000 >= Mover.PlanBudgetMs do task.wait() end
	Clock.Mark = os.clock()
end

local function PathLength(Pts)
	local L = 0
	for I = 1, #Pts - 1 do L += FlatDist(Pts[I], Pts[I + 1]) end
	return L
end

-- one path at one agent radius: {Path, Pts, Labels, Raw, Radius, Length}, "stale" (it runs through geometry: the
-- navmesh hasn't caught up yet, or a bogus jump) or nil (no path). From = the start (default: where the root is); a
-- start other than the root is joined to it with a straight first leg.
local function Compute(H, Agent, Costs, Radius, Clock, From)
	local Params = table.clone(Agent)
	Params.AgentRadius = Radius
	Params.Costs = Costs
	local Path = PathfindingService:CreatePath(Params)
	Spend(Clock)
	local Ok = pcall(Path.ComputeAsync, Path, From or H.Root.Position, H.Goal) -- (yields: not our work)
	Clock.Mark = os.clock()
	Budget(Clock) -- (many paths come back in the same frame when a schedule sends everyone off at once)
	if not (Ok and Path.Status == Enum.PathStatus.Success) then return nil end
	local Raw = Path:GetWaypoints()
	local Pts, Labels, RawIdx = {}, {}, {}
	if From then
		Pts[1], Labels[1], RawIdx[1] = H.Root.Position - Vector3.new(0, LIFT, 0), Raw[1] and Raw[1].Label, 0
	end
	for K, W in ipairs(Raw) do
		table.insert(Pts, W.Position)
		Labels[#Pts], RawIdx[#Pts] = W.Label, K
	end
	if #Pts < 1 then return "stale" end
	-- (Task 4b) Valid, else the corner repair (header 1b); stale when neither passes
	local Added
	Pts, Labels, RawIdx, Added = Mend(Pts, Labels, RawIdx, function() Budget(Clock) end, Costs)
	if not Pts then return "stale" end
	if FlatDist(Pts[#Pts], H.Goal) > 0.05 then
		table.insert(Pts, H.Goal)
		Labels[#Pts], RawIdx[#Pts] = Labels[#Pts - 1], #Raw + 1
	end
	-- RawIdx: each point's index in the path's own waypoints (0: the root before them when it starts elsewhere;
	-- #Raw + 1: the goal), for Path.Blocked. Added: the repair's new vertices.
	return {Path = Path, Pts = Pts, Labels = Labels, RawIdx = RawIdx, Added = Added, Raw = #Raw, Radius = Radius,
		Length = PathLength(Pts), Off = From and 1 or 0}
end

-- The planning (header 1, 1b, 2), for a walk and for PlanPath: Best (the chosen path: {Path, Pts, Labels, RawIdx,
-- Added, Raw, Radius, Length, Off}), its smoothed waypoints and their indices in Best.Pts; or nil and why it failed; or
-- false once Alive() says the walk is over. H needs Agent, Goal (ground), Root.Position (read live: a walker coasts
-- while it plans) and Dir. Attempts: the asks of a stale path (default 8, 0.5 s apart).
local function PlanCore(H, Alive, Clock, Attempts)
	local Agent = H.Agent
	local Costs = table.clone(Mover.Costs)
	for K, V in pairs(Agent.Costs or {}) do Costs[K] = V end
	local Radii = {Agent.AgentRadius or 2}
	for _, R in ipairs(Mover.NarrowRadii) do
		if R < Radii[1] then table.insert(Radii, R) end
	end
	if not Refreshed then RefreshBodies() end -- (the geometry filters; the tick keeps them fresh)
	local Straight = FlatDist(H.Root.Position, H.Goal)
	local Why = "no path"
	local Base = Agent
	for Attempt = 1, Attempts or 8 do
		-- (Task 4b fix round 1) a re-ask after a stale result asks with another waypoint spacing: on a settled navmesh the
		-- same question gives the same path, which the repair can't fix again; other spacings give other legs
		if Attempt > 1 then
			Agent = table.clone(Base)
			Agent.WaypointSpacing = Mover.ReaskSpacings[(Attempt - 2) % #Mover.ReaskSpacings + 1]
		end
		local Stale, Best = false, nil
		for _, Radius in ipairs(Radii) do
			Budget(Clock)
			if not Alive() then return false end
			local Got = Compute(H, Agent, Costs, Radius, Clock)
			if not Alive() then return false end
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
			-- path from a spot just behind or beside the walker (at the narrowest comfortable radius, then squeezing)
			local Here = H.Root.Position - Vector3.new(0, LIFT, 0)
			if Straight <= 15 and Valid({Here, H.Goal}) and Safe(Costs, Here, H.Goal, math.huge) then
				Best = {Pts = {Here, H.Goal}, Labels = {}, RawIdx = {}, Added = {}, Raw = 2, Radius = 0, Length = Straight, Off = 0}
			else
				local Dir, Right = H.Dir, RightOf(H.Dir)
				for _, Radius in ipairs({Radii[#Radii], Mover.SqueezeRadius}) do
					for _, Off in ipairs({Vector3.zero, -Dir * 3, Right * 2.5, -Right * 2.5, -Dir * 6}) do
						if Radius == Radii[#Radii] and Off == Vector3.zero then continue end -- (tried above)
						local From = H.Root.Position + Off
						if Off == Vector3.zero or Valid({Here, From - Vector3.new(0, LIFT, 0)}) then
							Budget(Clock)
							if not Alive() then return false end
							local Got = Compute(H, Agent, Costs, Radius, Clock, Off ~= Vector3.zero and From or nil)
							if not Alive() then return false end
							if type(Got) == "table" then Best = Got break end
							if Got == "stale" then Stale = true end
						end
					end
					if Best then break end
				end
			end
		end
		if Best then
			local Wps, Orig = Smooth(Costs, Best.Pts, Best.Labels, function() Budget(Clock) end)
			if not Alive() then return false end
			return Best, Wps, Orig
		end
		Why = Stale and "paths kept running through geometry" or "no path"
		if not Stale then break end
		PlanWait(Clock, 0.5) -- the navmesh is still catching up with a change: ask again
		if not Alive() then return false end
	end
	return nil, Why
end

-- Reason: why this plan was made (Plan's Why). A sight or blocked re-plan leaves the stuck window running (header 5)
local function PlanBody(H, Gen, Clock, Reason)
	local Best, Wps, Orig = PlanCore(H, function() return Alive(H, Gen) end, Clock)
	if Best == false then return end
	if not Best then
		H.Why = Wps
		Finish(H, "failed")
		return
	end
	local Remain = {}
	Remain[#Wps] = 0
	for I = #Wps - 1, 1, -1 do Remain[I] = Remain[I + 1] + FlatDist(Wps[I], Wps[I + 1]) end
	H.Wps, H.Orig, H.Remain, H.Wi = Wps, Orig, Remain, math.min(2, #Wps)
	H.Waypoints, H.RawWaypoints, H.Radius = Wps, Best.Raw, Best.Radius
	H.Repaired = #(Best.Added or {})
	H.PathId, H.RawIdx = Gen, Best.RawIdx
	if H.BlockedConn then H.BlockedConn:Disconnect() H.BlockedConn = nil end
	H.BlockedConn = Best.Path and Best.Path.Blocked:Connect(function(Index)
		-- a waypoint on the rest of the way is blocked: re-plan (on the next tick). H.Orig maps each kept waypoint to
		-- its index in Pts (and survives a local detour); RawIdx maps that to the path's own waypoint index
		if H.Status == "walking" and H.PathId == Gen and Index >= (H.RawIdx[H.Orig[math.max(1, H.Wi - 1)] or 1] or 0) then
			H.NeedPlan = H.NeedPlan or "blocked"
		end
	end)
	H.Path = Best.Path
	H.Mode = "walk"
	if Reason ~= "sight" and Reason ~= "blocked" then ResetWindow(H, H.Root.Position, os.clock()) end
end

local function Plan(H, Why)
	H.PlanGen = (H.PlanGen or 0) + 1
	local Gen = H.PlanGen
	local P = H.Root.Position
	if Why ~= "start" then
		H.Replans += 1
		Stats.Replans += 1
		if H.Replans > Mover.MaxPlans then H.Why = "too many re-plans" Finish(H, "failed") return end
		-- (Task 4b, header 5) a sight or blocked re-plan with little progress since the last plan: a stuck event
		if (Why == "sight" or Why == "blocked") and H.PlanFrom and FlatDist(P, H.PlanFrom) < Mover.ReplanProgress then
			if H.StuckReplans >= Mover.MaxReplans then H.Why = "stuck (re-planning without progress)" Finish(H, "failed") return end
			H.StuckReplans += 1
			H.StuckFrom = H.StuckFrom or P
		end
	end
	H.PlanFrom = P
	H.Mode = "plan"
	H.NeedPlan = nil
	H.NextPlanAt = os.clock() + 1
	task.defer(function() -- (never inside the steering tick)
		local Clock = NewClock()
		local Ok, Err = pcall(PlanBody, H, Gen, Clock, Why)
		Spend(Clock)
		Stats.Plans += 1
		Stats.PlanMs += Clock.Spent * 1000
		Stats.MaxPlanMs = math.max(Stats.MaxPlanMs, Clock.Spent * 1000)
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
	if (A.Urgent == true) ~= (B.Urgent == true) then return A.Urgent == true end -- (header 4b: urgent first)
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
	local Urgent = H.Urgent == true
	local Clear = Urgent and Mover.UrgentClearance or Mover.Clearance
	local SenseSq = Mover.SenseRadius * Mover.SenseRadius
	for _, B in ipairs(Bodies) do
		local BP = B.Pos
		if BP and B.Model ~= H.Rig then
			local D = Vector3.new(BP.X - P.X, 0, BP.Z - P.Z)
			local DistSq = D.X * D.X + D.Z * D.Z
			if DistSq < SenseSq and DistSq > 1e-6 and math.abs(BP.Y - P.Y) < 6 then
				local Dist = math.sqrt(DistSq)
				local BV = B.Vel
				-- standing: not moving, or a walker that is itself held up (the same test the local routes use)
				local BO = Active[B.Model]
				local Still = BV.Magnitude < 0.3 or (BO ~= nil and BO.Mode == "walk" and (BO.SlowT or 0) >= 0.5)
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
				-- (an urgent walker doesn't dodge a walker that is giving way: that one is getting out of its way, so it
				-- follows it (2) until it has stepped aside, rather than swerving into whatever is beside a door)
				local GivingWay = Urgent and BO ~= nil and BO.Mode == "yield"
				if CD < Clear and (Along > -1 or Tc > 0.05) and not (NearGoal and Still) and not GivingWay then
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
				-- (no room to side-step only stops it for someone moving: one standing still is passed if it won't be touched;
				-- an urgent walker only stops for a body right on its line: the others give way)
				local Lane = Urgent and Mover.UrgentLane or (Still and Mover.ContactGap or Mover.LaneWidth)
				if Along > 0 and ((NoRoom and not Still and not Urgent) or Off < Lane) then
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
				-- 4) this close: never step any closer, whatever the other rules want (someone moving: HardGap; someone
				-- standing: ContactGap, so posts 3 studs apart can still be reached)
				local Floor = Still and Mover.ContactGap or (Urgent and Mover.UrgentHardGap or Mover.HardGap)
				if Dist < Floor + 0.4 then
					Hard = Hard or {}
					table.insert(Hard, {D / Dist, math.clamp((Floor + 0.4 - Dist) / 0.4, 0, 1)})
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

-- swaps the rest of the way to the current waypoint for a local route: true if it found one, false if not, "later" if
-- this tick already planned one (at most one per tick: a local route is the costliest thing a tick does)
local RoutesThisTick, RouteMsThisTick = 0, 0
local function Detour(H, P, Now)
	local Target = H.Wps[H.Wi]
	if FlatDist(P, Target) > Mover.LocalReach or (H.Detours or 0) >= Mover.MaxDetours then return false end
	if RoutesThisTick >= 1 then return "later" end
	RoutesThisTick += 1
	local T0 = os.clock()
	local Route = LocalRoute(H, P, Target)
	local Ms = (os.clock() - T0) * 1000
	RouteMsThisTick += Ms
	Stats.Routes += 1
	Stats.RouteMs += Ms
	Stats.MaxRouteMs = math.max(Stats.MaxRouteMs, Ms)
	if not Route then return false end
	-- the new waypoints keep pointing into the planned path (Orig), so Path.Blocked still works after the detour
	local Into = H.Orig[H.Wi] or 1
	local Wps, Orig = {P - Vector3.new(0, LIFT, 0)}, {H.Orig[H.Wi - 1] or 1}
	for _, Q in ipairs(Route) do
		table.insert(Wps, Q)
		table.insert(Orig, Into)
	end
	for I = H.Wi + 1, #H.Wps do
		table.insert(Wps, H.Wps[I])
		table.insert(Orig, H.Orig[I] or Into)
	end
	local Remain = {}
	Remain[#Wps] = 0
	for I = #Wps - 1, 1, -1 do Remain[I] = Remain[I + 1] + FlatDist(Wps[I], Wps[I + 1]) end
	H.Wps, H.Remain, H.Wi, H.Orig = Wps, Remain, 2, Orig
	H.Waypoints = Wps
	H.DetourAt = Now
	H.Detours = (H.Detours or 0) + 1
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

-- Where a yielder goes: back and to its right, or any side with room. In an alley there is none: it backs out along
-- its own breadcrumbs until there is room to the side (or as far back as it has been), then steps aside there.
-- Away (optional; giving way to an urgent walker): Away(Spot) -> how far Spot is from that walker's way. Then every
-- clear spot is scored, the wider side spots are tried too, and the one off its way (LaneWidth or more), else the
-- farthest from it, wins (ties: the order below, right side first); the breadcrumbs only when no spot is clear.
local function YieldPath(H, P, Dir, Away)
	local Right = RightOf(Dir)
	local Back, Side = -Dir * Mover.YieldBack, Right * Mover.YieldSide
	local Offs = {Back + Side, Back - Side, Side, -Side}
	if Away then
		local Wide = Right * Mover.YieldWide
		table.insert(Offs, Back + Wide)
		table.insert(Offs, Back - Wide)
	end
	local Best, BestD
	for _, Off in ipairs(Offs) do
		if SpotClear(H, P, P + Off) then
			if not Away then return {P + Off} end
			local D = Away(P + Off) or math.huge
			if not Best or D > BestD + 0.05 and BestD < Mover.LaneWidth then Best, BestD = P + Off, D end
		end
	end
	if Best then return {Best} end
	-- (the trail is cut back to the crumb it backs out to: what lies beyond is the way towards the other walker)
	local Path, From = {}, P
	local Trail = H.Trail
	local function Keep(K)
		for I = #Trail, K + 1, -1 do Trail[I] = nil end
	end
	for K = #Trail, 1, -1 do
		local C = Trail[K]
		if FlatDist(C, From) >= 1.5 then
			table.insert(Path, C)
			From = C
			if #Path % 2 == 0 or K == 1 then -- (every other crumb: room to the side here?)
				local R2 = Right
				local Prev = Path[#Path - 1] or P
				local Way = Flat(Prev - C) -- the way it came along this stretch (towards the other walker)
				if Way.Magnitude > 0.1 then R2 = RightOf(Way.Unit) end
				for _, Off in ipairs({R2 * Mover.YieldSide, -R2 * Mover.YieldSide}) do
					if SpotClear(H, C, C + Off) then
						table.insert(Path, C + Off)
						Keep(K)
						return Path
					end
				end
			end
		end
	end
	if #Path == 0 then
		table.insert(Path, P - Dir * (Mover.YieldBack + Mover.YieldSide))
	else
		Keep(1)
	end
	return Path
end

local function Stuck(H, P, Now)
	if H.StuckReplans >= Mover.MaxReplans then H.Why = "stuck" Finish(H, "failed") return end
	-- standing bodies in the way (a crowd at the posts, a player in an alley): a local route round them first
	local Routed = Detour(H, P, Now)
	if Routed == "later" then return "later" end -- (another walker's route this tick: try again next tick)
	H.StuckReplans += 1
	H.StuckFrom = P
	if Routed then return end
	Stats.Sidesteps += 1
	local Right = RightOf(H.Dir)
	H.Spot = PickSpot(H, P, {Right * Mover.Sidestep, -Right * Mover.Sidestep, -H.Dir * Mover.Sidestep})
	H.SpotUntil = Now + 1.2
	H.Mode = "side"
end

-- steering towards Spot (sidestep / yield / wait); true when within Near (default 0.4) of it
local function GoTo(H, P, Spot, Now, Near)
	local To = Flat(Spot - P)
	local D = To.Magnitude
	if D < (Near or 0.4) then return true end
	local Dir = To / D
	local Desired = Dir * math.max(Mover.MinSpeed, H.Speed * math.min(1, D / 2))
	local Steer = Avoid(H, P, Desired, Dir, D, true)
	Move(H, Steer)
	return false
end

-- is P on the urgent walker O's way: within LaneWidth of the rest of its path from OP (its current segment, then the
-- next ones), no further along it than GiveWayDist or the way it has left to go + 2 studs? (header 4b) Also while it
-- side-steps or re-plans, on its last known waypoints (so nobody waits for its next plan to step aside)
-- (fix round 2) how far Q is from that way (Reach: how far along it to look, default GiveWayDist); nil when unknown
local function UrgentWayDist(O, OP, Q, Reach)
	local Wps = (O.Mode == "walk" or O.Mode == "side" or O.Mode == "plan") and O.Wps
	if not (Wps and O.Wi and Wps[O.Wi]) then return nil end
	local Budget = math.min(Reach or Mover.GiveWayDist, (O.RemainDist or math.huge) + 2)
	local A, Near = OP, math.huge
	for I = O.Wi, #Wps do
		local B = Wps[I]
		local Seg = Flat(B - A)
		local L = Seg.Magnitude
		if I == #Wps and L > 0.01 then -- (the last stretch reaches 2 studs past the end)
			B = B + Seg / L * 2
			L += 2
		end
		local Use = math.min(L, Budget)
		if Use > 0.01 then
			local Cut = A + Flat(B - A).Unit * Use
			Near = math.min(Near, SegDist(A, Cut, Q))
		end
		Budget -= Use
		if Budget <= 0 then break end
		A = B
	end
	return Near
end
function InUrgentWay(O, OP, P, Reach)
	local D = UrgentWayDist(O, OP, P, Reach)
	return D ~= nil and D < Mover.LaneWidth
end

local function StepOne(H, Dt, Now)
	local Rig, Root, Hum = H.Rig, H.Root, H.Humanoid
	if not Rig.Parent or not Root.Parent or Hum.Health <= 0 then Finish(H, "cancelled") return end
	if H.Mode == "arrive" then return end
	if Pinned(H) then
		-- (Task 6b) held by combat: no steering, no facing, never re-anchored, and it doesn't count as stuck
		if not H.Suspended then
			H.Suspended = true
			pcall(function()
				Hum:Move(Vector3.zero)
				if H.Facer then H.Facer.Enabled = false end
			end)
			local T = Tracks[Rig]
			if T and T.IsPlaying then T:Stop(0.2) end
		end
		ResetWindow(H, Root.Position, Now)
		return
	elseif H.Suspended then
		H.Suspended = false
		if H.Facer then H.Facer.Enabled = true end
		Hum.AutoRotate = false
		Hum.WalkSpeed = H.Speed -- (the hit's slow handed back MoverManager's own default when it ended)
		ResetWindow(H, Root.Position, Now)
	end
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
			-- passed: the other's progress has taken it past the yielder, along the way the yielder wants to go
			if Flat(OP - P):Dot(H.YieldDir) < -1 then Done = true end
			-- or it went off another way: well clear and still getting further BY ITS OWN GOING (fix round 4, review
			-- Minor 2: the gap also grows while the yielder backs off and the urgent one is stopped, side-stepping or
			-- re-planning ahead; ending the yield then let the 3 s cooldown block the next give-way as it came on)
			local D = FlatDist(P, OP)
			local Away = D > 1e-3 and Flat(O.Root.AssemblyLinearVelocity):Dot(Flat(OP - P) / D) or 0
			if D > H.YieldLast + 0.02 and Away > 1 then H.Grow += 1 else H.Grow = 0 end -- (PROPOSAL: 1 stud/s away)
			H.YieldLast = D
			if D > 8 and H.Grow >= 3 then Done = true end
		end
		if Done then
			H.Mode = "walk"
			H.YieldCooldown = Now + 3
			if FlatDist(P, H.YieldFrom) > 6 then H.NeedPlan = H.NeedPlan or "yield" end -- (it backed out a long way)
			ResetWindow(H, P, Now)
			return
		end
		if not H.Settled then
			local Last = H.YieldIdx >= #H.YieldPath
			if GoTo(H, P, H.YieldPath[H.YieldIdx], Now, Last and 0.4 or 1) or Now > H.YieldStepUntil then
				if Last then
					H.Settled = true
				else
					H.YieldIdx += 1
					H.YieldStepUntil = Now + 3
				end
			end
		end
		if H.Settled then Hold(H, Flat(OP - P)) end
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
			if Now - H.WaitT0 > Mover.WaitCap then H.Why = "its post stayed occupied" Finish(H, "failed") return end
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
	local Trail = H.Trail
	if FlatDist(P, Trail[#Trail]) >= Mover.TrailStep then
		table.insert(Trail, P)
		if #Trail > Mover.TrailLength then table.remove(Trail, 1) end
	end
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
	-- (Task 6) ran past the end at speed (someone fleeing): it has arrived; the arrival turn puts it on the spot. Not
	-- when someone has just taken the post, nor across a floor (the tween would go through it)
	if H.Wi == N and N >= 2 and DN < 3 and math.abs(P.Y - LIFT - Next.Y) < 3 and not Occupied(H) then
		local Prev = Wps[N - 1]
		local Seg = Flat(Next - Prev)
		local L = Seg.Magnitude
		if L > 0.01 and Flat(P - Prev):Dot(Seg) / L > L then Arrive(H) return end
	end

	-- the last stretch runs past someone standing still (a post among others' posts): take a local route round them
	if H.Wi == N and DN < Mover.LocalReach and Now >= (H.ApproachCheck or 0) then
		H.ApproachCheck = Now + 0.5
		if StillBodyOnLine(H, P, Next, Mover.ContactGap) then
			local Routed = Detour(H, P, Now)
			if Routed == true then return end
			if Routed == "later" then H.ApproachCheck = Now end -- (next tick)
		end
	end

	-- the post is taken: wait near it (1.5 studs clear of the occupant's shoulder), re-checking. Back along the way it
	-- came first (that side is open: it just walked there), then to either side
	if Remain < 5 and Occupied(H) then
		H.Mode, H.Spot, H.Settled = "wait", WaitSpot(H, P, Dir), false
		H.WaitT0, H.WaitCheck = Now, Now + 0.5
		Stats.PostWaits += 1
		return
	end

	-- a wall has appeared between the walker and its next waypoint: re-plan. (Task 4b) Valid's rule: a ray from the
	-- walker's waist to the waypoint's waist height (the old radius-1 flat spherecast fired on most good paths)
	if Now >= H.SightAt then
		H.SightAt = Now + Mover.SightEvery
		local Eye = P - Vector3.new(0, LIFT - Mover.WaistHeight, 0)
		local Look = Next + Vector3.new(0, Mover.WaistHeight, 0) - Eye
		local Len = math.min(Look.Magnitude, Mover.SightRange)
		if Len > 1 and workspace:Raycast(Eye, Look.Unit * Len, Obstacles) then
			H.NeedPlan = H.NeedPlan or "sight"
		end
	end

	local Want = math.max(Mover.MinSpeed, H.Speed * math.min(1, Remain / (Mover.SlowRadius * math.max(1, H.Speed / 8))))
	local Look = Flat(Root.CFrame.LookVector)
	if Look.Magnitude > 1e-3 then -- facing well away from the way to go: turn first, then walk (eased, not stopped)
		Want *= math.clamp(Look.Unit:Dot(Dir) + 0.3, 0.15, 1)
	end
	local Steer = Avoid(H, P, Dir * Want, Dir, DN, Remain < 3)
	Move(H, Steer)
	if Steer.Magnitude <= 1.5 then FaceToward(H, Dir) end -- (turning on the spot towards the way to go)

	-- an urgent walker coming at this one (header 4b): step aside at once, as in a door, until it has gone past
	if not H.Urgent and UrgentCount > 0 and Now >= (H.YieldCooldown or 0) then
		for _, O in ipairs(List) do
			if O ~= H and O.Urgent and O.Status == "walking" and O.Root and O.Root.Parent and O.Mode ~= "arrive" then
				local OP = O.Root.Position
				local D = Flat(P - OP) -- from the urgent walker to this one
				local Dist = D.Magnitude
				-- (fix round 2) on time to meet: the reach grows with the urgent walker's speed
				local Reach = math.max(Mover.GiveWayDist, (O.Speed or Mover.UrgentSpeed) * Mover.GiveWayLead)
				if Dist > 1e-3 and Dist <= Reach and math.abs(OP.Y - P.Y) < 6 and D:Dot(O.Dir) > 0
					and InUrgentWay(O, OP, P, Reach) then
					local Toward = -D / Dist
					H.YieldPath = YieldPath(H, P, Toward, function(Spot) return UrgentWayDist(O, OP, Spot, Reach) end)
					H.YieldIdx, H.YieldStepUntil = 1, Now + 3
					H.YieldDir, H.YieldFrom = Toward, P
					H.Mode, H.YieldTo, H.YieldT0, H.Settled = "yield", O, Now, false
					H.YieldLast, H.Grow = Dist, 0
					H.Yields += 1
					Stats.Yields += 1
					Stats.GiveWays += 1
					-- (fix round 2) the step-aside starts in this tick: the forward steer is dropped (the steering blend
					-- would otherwise carry it on for a few ticks) and the walker heads for the spot now
					local To = Flat(H.YieldPath[1] - P)
					H.Steer = To.Magnitude > 0.05 and To.Unit * H.Speed or Vector3.zero
					GoTo(H, P, H.YieldPath[1], Now, #H.YieldPath == 1 and 0.4 or 1)
					return
				end
			end
		end
	end

	-- narrow spots: blocked head-on with another walker -> the lower priority yields (an urgent walker never yields
	-- to a normal one: HasPriority puts urgent first)
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
					H.YieldPath, H.YieldIdx, H.YieldStepUntil = YieldPath(H, P, Dir), 1, Now + 3
					H.YieldDir, H.YieldFrom = Dir, P
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
			if Stuck(H, P, Now) == "later" then return end -- (the window stays open: it tries again next tick)
			if H.Status ~= "walking" then return end
		end
		H.WinPos, H.WinT, H.Excused = P, Now, false
	end
end

local Acc = 0
local function Tick(Dt)
	Stats.Heartbeats += 1
	Acc += Dt
	local Period = 1 / Mover.Hz
	if Acc < Period then return end
	Acc = math.min(Acc - Period, Period) -- (keeps the 10 Hz cadence; never more than one catch-up tick)
	local StepDt = Period
	local T0 = os.clock()
	local Now = T0
	local Mem0 = gcinfo()
	RoutesThisTick, RouteMsThisTick = 0, 0
	local RefreshMs = 0
	if Now >= BodiesAt then
		RefreshBodies()
		BodiesAt = Now + 0.5
		RefreshMs = (os.clock() - T0) * 1000
	end
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
	UrgentCount = 0
	for _, H in ipairs(List) do if H.Urgent and H.Status == "walking" then UrgentCount += 1 end end
	local Slowest, SlowestMs, SlowestMode, SumMs, Count = nil, 0, "", 0, 0
	for _, H in ipairs(table.clone(List)) do
		if H.Status == "walking" then
			local Mode = H.Mode
			local T1 = os.clock()
			local Ok, Err = pcall(StepOne, H, StepDt, Now)
			if not Ok and H.Status == "walking" then Broke(H, Err) end
			local One = (os.clock() - T1) * 1000
			SumMs, Count = SumMs + One, Count + 1
			if One > SlowestMs then Slowest, SlowestMs, SlowestMode = H, One, Mode .. ">" .. tostring(H.Mode) end
		end
	end
	local Ms = (os.clock() - T0) * 1000
	if #List > 0 or Ms > 0 then
		Stats.Ticks += 1
		Stats.Ms += Ms
		Stats.TimeAt = Stats.TimeAt % Mover.TimeRing + 1
		Stats.Times[Stats.TimeAt] = Ms
		if Ms > Stats.MaxMs then
			Stats.MaxMs = Ms
			Stats.WorstTick = ("%.2f ms: %d walkers (%.3f ms each on average, slowest %.2f ms %s), bodies refresh %.2f ms (%d bodies), %d local route(s) %.2f ms, Lua heap %+d KB"):format(
				Ms, #List, Count > 0 and SumMs / Count or 0, SlowestMs, SlowestMode, RefreshMs, #Bodies, RoutesThisTick, RouteMsThisTick, gcinfo() - Mem0)
		end
	end
	Stats.PeakWalkers = math.max(Stats.PeakWalkers, #List)
	if #List == 0 and Conn then
		Conn:Disconnect()
		Conn = nil
		if FrameConn then FrameConn:Disconnect() FrameConn = nil end
	end
end

WatchModifiers() -- (the scan runs deferred, in chunks)

-- ===== API =====
-- (debug) the rig's walk in progress, or nil
function Mover.Handle(Rig) return Active[Rig] end

-- (Task 4b) the planning a walk from From (a standing root position) to Goal (a standing CFrame or root position)
-- would do, with no rig: see the header
function Mover.PlanPath(From, Goal, Agent, Opts)
	Opts = Opts or {}
	local GoalPos = typeof(Goal) == "CFrame" and Goal.Position or Goal
	local H = {Agent = Agent or Mover.Agent, Root = {Position = From}, Goal = GoalPos - Vector3.new(0, LIFT, 0)}
	local D = Flat(H.Goal - From)
	H.Dir = Opts.Dir or (D.Magnitude > 1e-3 and D.Unit or Vector3.new(0, 0, -1))
	local Clock = NewClock()
	local Best, Wps = PlanCore(H, function() return true end, Clock, Opts.Attempts)
	Spend(Clock)
	local Ms = Clock.Spent * 1000
	if not Best then return {Status = "failed", Why = Wps, Ms = Ms} end
	return {Status = "ok", Waypoints = Wps, Raw = Best.Pts, RawCount = Best.Raw, Radius = Best.Radius,
		Inserted = Best.Added or {}, Ms = Ms}
end

-- (Task 4b, tests) the corner repair of a polyline of ground points, as a plan runs it (Valid first)
function Mover.RepairPath(Pts, Labels)
	if not Refreshed then RefreshBodies() end
	local Raw = {}
	for K = 1, #Pts do Raw[K] = K end
	local Out, _, _, Added = Mend(Pts, Labels or {}, Raw, nil, Mover.Costs)
	if not Out then return nil, "stale" end
	return Out, Added
end

function Mover.Place(Rig, TargetCFrame)
	local H = Active[Rig]
	if H then Cancel(H) end
	Put(Rig, TargetCFrame)
end

-- (Task 6b) ends the walk where the rig stands, without placing (or anchoring) it
function Mover.Stop(Rig)
	local H = Active[Rig]
	if H then Cancel(H) end
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
	H.Urgent = Opts.Urgent == true
	H.Speed = Opts.Speed or (H.Urgent and Mover.UrgentSpeed) or Humanoid.WalkSpeed
	H.Agent = Opts.Agent or Mover.Agent
	H.Goal = TargetCFrame.Position - Vector3.new(0, LIFT, 0) -- the ground under the standing root
	H.Steer = Vector3.zero
	local L = Flat(Root.CFrame.LookVector)
	H.Dir = L.Magnitude > 1e-3 and L.Unit or Vector3.new(0, 0, -1)
	H.SlowT, H.StuckReplans, H.SightAt, H.NextPlanAt, H.Detours = 0, 0, 0, 0, 0
	H.Trail = {Root.Position}
	WatchModifiers() -- (already started at load; this only guards)
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
	if not FrameConn then
		FrameNo += 1 -- (fix round 1) a fresh frame: the counter stood still while nobody walked
		FrameConn = RunService.PreSimulation:Connect(function() FrameNo += 1 end)
	end
	Plan(H, "start")
	return H
end

return Mover

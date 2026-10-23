-- TownsfolkService.Mover (Region Foundation Task 5, 2026-10-23): ALL townsfolk walking lives here, behind two calls,
-- so the pathfinding follow-up (Task 5b: crowd avoidance, smoothing, re-planning, stuck recovery) can replace this
-- module without touching spawning or schedules. TownsfolkService calls only WalkTo and Place.
--   * Mover.WalkTo(Rig, TargetCFrame, Opts) -> Handle
--       Walks the rig to TargetCFrame (a standing CFrame: root position + facing) with PathfindingService and
--       Humanoid:MoveTo, in its own task. On arrival the rig is placed exactly on TargetCFrame (Place).
--       Opts (all optional): Speed (default Humanoid.WalkSpeed), WaypointTimeout (s, default Mover.WaypointTimeout),
--       Agent (CreatePath params, default Mover.Agent), OnDone(Result) where Result is "arrived" | "failed" | "cancelled".
--       A failed path or a stuck waypoint ends with "failed" and leaves the rig where it is (the caller decides).
--       Handle: {Status = "walking" | Result, Cancel = function(self)}. A newer WalkTo / Place on the same rig
--       cancels the older walk.
--   * Mover.Place(Rig, TargetCFrame): cancels any walk, anchors the root and puts the rig exactly there.
-- The caller handles everything else about the rig (idle poses, states). A walking rig needs its root unanchored, so
-- the caller clears IdleAnim before WalkTo (NpcIdles re-anchors the root only while an idle is playing).
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mover = {}
Mover.WaypointTimeout = 4 -- PROPOSAL: seconds per waypoint before the walk counts as stuck
Mover.Agent = {AgentRadius = 2, AgentHeight = 5, AgentCanJump = false}
Mover.WalkDesign = 12 -- the walk animation is designed at this speed (TuningConfig.Locomotion.Design.Walk)

local Active = {} -- [Rig] = Handle
local Tracks = {} -- [Rig] = walk AnimationTrack

local function WalkTrack(Rig)
	if Tracks[Rig] ~= nil then return Tracks[Rig] or nil end
	local Source = ReplicatedStorage.Assets.Animations.Shared:FindFirstChild("Walk", true)
	local Ok, Track = pcall(function() return Rig.Humanoid.Animator:LoadAnimation(Source) end)
	if Ok and Track then
		Track.Looped = true
		Track.Priority = Enum.AnimationPriority.Movement
	end
	Tracks[Rig] = Ok and Track or false
	Rig.Destroying:Once(function() Tracks[Rig], Active[Rig] = nil, nil end)
	return Tracks[Rig] or nil
end

local function Finish(H, Result)
	if H.Status ~= "walking" then return end
	H.Status = Result
	if Active[H.Rig] == H then Active[H.Rig] = nil end
	local T = Tracks[H.Rig]
	if T and T.IsPlaying and not Active[H.Rig] then T:Stop(0.2) end
	if H.OnDone then
		local Ok, Err = pcall(H.OnDone, Result)
		if not Ok then warn("Mover OnDone:", Err) end
	end
end

local function Cancel(H) Finish(H, "cancelled") end

-- held still, exactly on TargetCFrame
local function Put(Rig, TargetCFrame)
	local Root = Rig:FindFirstChild("HumanoidRootPart")
	if not Root then return end
	Root.Anchored = true
	Root.AssemblyLinearVelocity = Vector3.zero
	Rig:PivotTo(TargetCFrame)
end

function Mover.Place(Rig, TargetCFrame)
	local H = Active[Rig]
	if H then Cancel(H) end
	Put(Rig, TargetCFrame)
end

function Mover.WalkTo(Rig, TargetCFrame, Opts)
	Opts = Opts or {}
	local Old = Active[Rig]
	if Old then Cancel(Old) end
	local H = {Rig = Rig, Status = "walking", OnDone = Opts.OnDone, Cancel = Cancel}
	Active[Rig] = H
	local Root = Rig:FindFirstChild("HumanoidRootPart")
	local Humanoid = Rig:FindFirstChildOfClass("Humanoid")
	if not (Root and Humanoid) then Finish(H, "failed") return H end
	Root.Anchored = false
	pcall(Root.SetNetworkOwner, Root, nil)
	-- a Humanoid held by an anchored root reads as Freefall and, once freed, drifts ~3 s before it lands: start it running
	Humanoid:ChangeState(Enum.HumanoidStateType.Running)
	local Timeout = Opts.WaypointTimeout or Mover.WaypointTimeout
	local function Live() return H.Status == "walking" and Rig.Parent ~= nil end
	task.spawn(function()
		local Path = PathfindingService:CreatePath(Opts.Agent or Mover.Agent)
		local Goal = TargetCFrame.Position - Vector3.new(0, 3, 0) -- the ground under the standing root
		local Ok = pcall(Path.ComputeAsync, Path, Root.Position, Goal)
		if not Live() then return end
		if not Ok or Path.Status ~= Enum.PathStatus.Success then Finish(H, "failed") return end
		local Speed = Opts.Speed or Humanoid.WalkSpeed
		Humanoid.WalkSpeed = Speed
		local T = WalkTrack(Rig)
		if T then T:Play(0.2, 1, Speed / Mover.WalkDesign) end
		for _, Wp in ipairs(Path:GetWaypoints()) do
			if not Live() then return end
			Root.Anchored = false -- in case a deferred NpcIdles loosen landed after the walk began
			local Done = false
			local Conn = Humanoid.MoveToFinished:Once(function() Done = true end)
			Humanoid:MoveTo(Wp.Position)
			local T0 = os.clock()
			while not Done and Live() and os.clock() - T0 < Timeout do task.wait(0.1) end
			Conn:Disconnect()
			if not Live() then return end
			if not Done then Finish(H, "failed") return end
		end
		Put(Rig, TargetCFrame)
		Finish(H, "arrived")
	end)
	return H
end

return Mover

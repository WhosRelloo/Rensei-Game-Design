-- GuardService (stealth missions Plan 1 Task 4, 2026-10-29; spec Documents/specs/2026-10-25-stealth-missions-design.md
-- §3.1, §3.4): guards on radio nets and their routine. Numbers: Rensei.Guard (every one a PROPOSAL). Tasks 5-6 add the
-- radio (check-ins, the call, the alarm, reinforcements) and the memory (noises, last known spots, lines).
--
-- ENEMIES WITHOUT A NET ARE UNTOUCHED (the plan's safety rule): everything here is keyed on Guards[Rig], which exists only
-- for a rig with a net (EnemyService.Spawn reads a RenseiEnemySpawn part's Net attribute; tests call Track). EnemyService's
-- Brain asks Idle(Rig) in its no-target, no-goal branch before the old walk home; nil means "not a guard, do the old thing".
--
-- * Guards[Rig] = G: {Rig, Net, Route = {CFrame...} | nil, Pauses = {seconds?...}, Loop, Lookout, Post (a standing CFrame),
--   Speed (the def's WalkSpeed); Index, Dir, PauseUntil, Fails; LastCheckIn, Missed, LastLineAt; Reinforcement;
--   Walk (the Mover handle of a routine walk, or nil)}.
-- * Nets[Name] = {Name, Guards = {[Rig] = G}, Barracks = {Part...}, Alarm, AlarmAt, TightUntil, Calling, Lost, Reinforced}.
-- * Track(Rig, Info) -> G | nil. Info = {Net (required, a non-empty string), Route?, Pauses?, Loop?, Lookout?, Post?, Speed?,
--   Reinforcement?}. Without Post the post is the rig's root CFrame now (EnemyService: where BuildRig stood it on its spawn
--   part). A death or the rig's removal untracks it. Untrack(Rig, Why). Reset() (tests): every guard untracked, walks
--   stopped, nets cleared (the world's barracks read back in).
-- * Idle(Rig) -> nil | "walking" | "standing" (the routine; real movement, so its timing is os.clock()):
--   - a look-out or a post guard (no route) more than Guard.PostSlack from its post walks back to it at its own speed;
--     at the post a look-out sweeps its facing about the post's (Guard.Sweep, D8); a post guard faces its post (the
--     Mover's arrival turn);
--   - a patrol walks Route[Index] at Guard.PatrolSpeed (D8), pauses there (the point's Pause, else Guard.PatrolPause),
--     and steps on with Guard.NextPoint (a loop, or back and forth). A failed leg steps on too, after 2 s (PROPOSAL);
--     Guard.MaxWalkFails failed legs in a row and it stands where it is for good, with one warn.
-- * Interrupt(Rig): the Brain has a target or a perception goal: the routine walk stops (Mover.Stop) and the def's
--   WalkSpeed is put back. Every routine walk that ends puts it back too.
-- * A4 (Task 1's probe, the controller's ruling): guards walk with the Mover, no fallback. Two walkers at once fight (the
--   Brain's Humanoid:MoveTo every 0.1 s against the Mover's steering), so while a routine walk runs the Brain issues no
--   MoveTo: Idle answers before its walk home, and its goal and target branches Interrupt first. Mover.Place is never
--   used on a guard (it anchors the root). The Mover's arrival anchors the root too (Put), and its Stop/Cancel doesn't
--   free it: GuardService frees the root of a guard that is free to act (Free) whenever a routine walk ends or stops.
-- * A5: a look-out holds its post (back within PostSlack), sweeping +-Guard.LookoutSweep over Guard.LookoutPeriod.
--   (Task 6: it never leaves the post for a noise.)
-- * D8: patrol speed 8, a 3 s pause at each point, the look-out's +-45 deg sweep over 6 s (Rensei.Guard).
-- * World data (read by EnemyService.Spawn / Start): a RenseiEnemySpawn part's Net (string), Route (string) and Lookout
--   (bool); a route is a Model or Folder tagged RenseiPatrolRoute with attributes Route (its name) and Loop (bool), its
--   BasePart children named "1", "2", ... in order, each a standing spot placed like a spawn mark (the root stands 3
--   studs above the part, PROPOSAL, as BuildRig stands a rig on its spawn) facing the part's way, with an optional Pause
--   (seconds). RouteFor(Name) -> {Points, Pauses, Loop} | nil. A barracks is a BasePart tagged RenseiBarracks with Net
--   and an optional ReinforceType (default "StateGuard"), listed on its net (Task 5 opens it).
-- * The clock: Now(), Step(Dt) (Tasks 5-6 run the radio and the memory there), SetAuto(On); Start() steps it on
--   Heartbeat every 0.2 s while Auto, in a pcall. Only the radio and the memory use this clock.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Guard = require(ReplicatedStorage.Modules.Data.Rensei.Guard)
local PerceptionService = require(ServerScriptService.PerceptionService) -- (Tasks 5-6: PhaseOf, Now, the listeners)
local Mover = require(ServerScriptService.TownsfolkService.Mover)

local ROUTE_TAG = "RenseiPatrolRoute"
local BARRACKS_TAG = "RenseiBarracks"
local POINT_LIFT = 3 -- PROPOSAL: a route point stands a root this high above its part, as a spawn mark does (BuildRig)
local FAIL_PAUSE = 2 -- PROPOSAL: seconds a guard stands after a failed leg before the next

local GuardService = {}
local Guards, Nets = {}, {}
GuardService.Guards, GuardService.Nets = Guards, Nets
local Routes = {} -- [Name] = {Points = {CFrame...}, Pauses = {number?...}, Loop}

local Clock = 0
function GuardService.Now() return Clock end

local function Flat(V) return Vector3.new(V.X, 0, V.Z) end
local function Alive(M) local H = M and M:FindFirstChildOfClass("Humanoid") return H ~= nil and H.Health > 0 end
local function Free(Rig) -- can act on its own: not down, held or being taken
	return Alive(Rig) and Rig:IsDescendantOf(workspace) and not Rig:GetAttribute("Knocked")
		and not Rig:GetAttribute("TakenDownBy") and not Rig:GetAttribute("GrippedBy") and not Rig:GetAttribute("CarriedBy")
end
GuardService.Free = Free

local function NetOf(Name)
	local N = Nets[Name]
	if not N then
		N = {Name = Name, Guards = {}, Barracks = {}, Alarm = false, AlarmAt = nil, TightUntil = 0, Calling = nil, Lost = {}, Reinforced = {}}
		Nets[Name] = N
	end
	return N
end
GuardService.NetOf = NetOf

-- a routine walk ended or was stopped: the def's walk speed back, and the root free (the Mover's arrival anchors it)
local function Release(Gd)
	local Rig = Gd.Rig
	local Hum = Rig:FindFirstChildOfClass("Humanoid")
	if Hum and Hum.Health > 0 then Hum.WalkSpeed = Gd.Speed end
	local Root = Rig:FindFirstChild("HumanoidRootPart")
	if Root and Root.Anchored and Free(Rig) then Root.Anchored = false end
end

function GuardService.Untrack(Rig, Why)
	local Gd = Guards[Rig]
	if not Gd then return end
	Guards[Rig] = nil
	if Gd.Net and Gd.Net.Guards[Rig] == Gd then Gd.Net.Guards[Rig] = nil end
	if Gd.Walk then
		Gd.Walk = nil
		pcall(Mover.Stop, Rig)
		pcall(Release, Gd)
	end
end

function GuardService.Track(Rig, Info)
	if type(Info) ~= "table" or type(Info.Net) ~= "string" or Info.Net == "" then return nil end
	local Root = Rig:FindFirstChild("HumanoidRootPart")
	local Hum = Rig:FindFirstChildOfClass("Humanoid")
	if not (Root and Hum) then return nil end
	if Guards[Rig] then GuardService.Untrack(Rig, "retracked") end
	local Net = NetOf(Info.Net)
	local Route = type(Info.Route) == "table" and #Info.Route > 0 and Info.Route or nil
	local Gd = {
		Rig = Rig, Net = Net, Route = Route, Pauses = Info.Pauses or {}, Loop = Info.Loop == true, Lookout = Info.Lookout == true,
		Post = Info.Post or Root.CFrame, Speed = Info.Speed or Hum.WalkSpeed,
		Index = 1, Dir = 1, PauseUntil = 0, Fails = 0, SweepT = 0,
		LastCheckIn = Clock, Missed = false, LastLineAt = -math.huge, Reinforcement = Info.Reinforcement == true,
		Walk = nil,
	}
	Guards[Rig], Net.Guards[Rig] = Gd, Gd
	Hum.Died:Once(function() GuardService.Untrack(Rig, "died") end)
	Rig.Destroying:Once(function() GuardService.Untrack(Rig, "gone") end)
	return Gd
end

function GuardService.Interrupt(Rig)
	local Gd = Guards[Rig]
	if not (Gd and Gd.Walk) then return end
	Gd.Walk = nil -- (first: the "cancelled" OnDone below finds no walk of its own)
	Mover.Stop(Rig)
	Release(Gd)
end

-- one routine walk to Target; OnArrive / OnFail run when it ends that way (and the guard is still this record)
local function Leg(Gd, Target, Speed, OnArrive, OnFail)
	local Rig = Gd.Rig
	local Handle
	Handle = Mover.WalkTo(Rig, Target, {Speed = Speed, OnDone = function(Result)
		if Guards[Rig] ~= Gd then return end
		if Handle ~= nil and Gd.Walk ~= Handle then return end -- (an Interrupt took it, or a newer walk)
		Gd.Walk = nil
		if Result == "cancelled" then return end -- (whoever cancelled it owns the body)
		Release(Gd)
		if Result == "arrived" then
			Gd.Fails = 0
			OnArrive()
		else
			Gd.Fails += 1
			Gd.PauseUntil = os.clock() + FAIL_PAUSE
			OnFail()
			if Gd.Fails >= Guard.MaxWalkFails then
				warn(("GuardService: %s stands where it is after %d failed legs (the last to %s, %s)"):format(
					Rig:GetFullName(), Gd.Fails, tostring(Target.Position), tostring(Handle and Handle.Why or "?")))
			end
		end
	end})
	if Handle.Status == "walking" then Gd.Walk = Handle end
end

local function StepIndex(Gd)
	Gd.Index, Gd.Dir = Guard.NextPoint(#Gd.Route, Gd.Index, Gd.Dir, Gd.Loop)
end

function GuardService.Idle(Rig)
	local Gd = Guards[Rig]
	if not Gd then return nil end
	local Root = Rig:FindFirstChild("HumanoidRootPart")
	if not Root then return "standing" end
	local Now = os.clock()
	local Dt = math.clamp(Now - (Gd.IdleAt or Now), 0, 0.5)
	Gd.IdleAt = Now
	if Gd.Walk then
		if Gd.Walk.Status == "walking" then return "walking" end
		Gd.Walk = nil -- (ended without reaching OnDone: never expected)
	end
	if Gd.Fails >= Guard.MaxWalkFails then return "standing" end -- (for good)
	if Gd.PauseUntil > Now then return "standing" end
	-- a look-out or a post guard
	if Gd.Lookout or not Gd.Route then
		if Flat(Root.Position - Gd.Post.Position).Magnitude > Guard.PostSlack then
			Leg(Gd, Gd.Post, Gd.Speed, function() end, function() end)
			return Gd.Walk and "walking" or "standing"
		end
		if Gd.Lookout then
			Gd.SweepT += Dt
			Root.CFrame = CFrame.new(Root.Position) * Gd.Post.Rotation * CFrame.Angles(0, math.rad(Guard.Sweep(Gd.SweepT)), 0)
		end
		return "standing"
	end
	-- a patrol
	local I = Gd.Index
	Leg(Gd, Gd.Route[I], Guard.PatrolSpeed, function()
		Gd.PauseUntil = os.clock() + (tonumber(Gd.Pauses[I]) or Guard.PatrolPause)
		StepIndex(Gd)
	end, function()
		StepIndex(Gd)
	end)
	return Gd.Walk and "walking" or "standing"
end

-- ===== world data =====
local function ReadRoute(M)
	if not (M:IsA("Model") or M:IsA("Folder")) then return end
	local Name = M:GetAttribute("Route")
	if type(Name) ~= "string" or Name == "" then return end
	local Numbered = {}
	for _, P in ipairs(M:GetChildren()) do
		local N = tonumber(P.Name)
		if P:IsA("BasePart") and N then table.insert(Numbered, {N = N, Part = P}) end
	end
	table.sort(Numbered, function(A, B) return A.N < B.N end)
	local Points, Pauses = {}, {}
	for I, X in ipairs(Numbered) do
		local C = X.Part.CFrame
		local Look = Flat(C.LookVector)
		local At = C.Position + Vector3.new(0, POINT_LIFT, 0)
		Points[I] = CFrame.lookAt(At, At + (Look.Magnitude > 1e-3 and Look.Unit or Vector3.new(0, 0, -1)))
		local Pause = X.Part:GetAttribute("Pause")
		Pauses[I] = type(Pause) == "number" and Pause or nil
	end
	if #Points == 0 then return end
	Routes[Name] = {Points = Points, Pauses = Pauses, Loop = M:GetAttribute("Loop") == true}
end

local function ReadRoutes()
	for _, M in ipairs(CollectionService:GetTagged(ROUTE_TAG)) do
		if M:IsDescendantOf(workspace) then ReadRoute(M) end
	end
end

function GuardService.RouteFor(Name)
	if type(Name) ~= "string" or Name == "" then return nil end
	if not Routes[Name] then ReadRoutes() end -- (a spawn can come before Start)
	return Routes[Name]
end

local function AddBarracks(P)
	if not P:IsA("BasePart") or not P:IsDescendantOf(workspace) then return end
	local Net = P:GetAttribute("Net")
	if type(Net) ~= "string" or Net == "" then return end
	local B = NetOf(Net).Barracks
	if not table.find(B, P) then table.insert(B, P) end
end

local function ReadBarracks()
	for _, P in ipairs(CollectionService:GetTagged(BARRACKS_TAG)) do AddBarracks(P) end
end

function GuardService.Reset()
	local List = {}
	for Rig in pairs(Guards) do table.insert(List, Rig) end
	for _, Rig in ipairs(List) do GuardService.Untrack(Rig, "reset") end
	table.clear(Nets)
	ReadBarracks()
end

-- ===== the clock =====
function GuardService.Step(Dt)
	Clock += Dt
	-- (Tasks 5-6: check-ins, the radio call, the alarm, reinforcements, the memory)
end

local Auto = true
function GuardService.SetAuto(On) Auto = On end

local Started = false
function GuardService.Start()
	if Started then return end
	Started = true
	ReadRoutes()
	CollectionService:GetInstanceAddedSignal(ROUTE_TAG):Connect(function(M)
		if M:IsDescendantOf(workspace) then ReadRoute(M) end
	end)
	ReadBarracks()
	CollectionService:GetInstanceAddedSignal(BARRACKS_TAG):Connect(AddBarracks)
	local Acc = 0
	RunService.Heartbeat:Connect(function(Dt)
		if not Auto then return end
		Acc += Dt
		if Acc < 0.2 then return end
		local Step = math.min(Acc, 1)
		Acc = 0
		local Ok, Err = pcall(GuardService.Step, Step)
		if not Ok then warn("GuardService:", Err) end
	end)
end

return GuardService

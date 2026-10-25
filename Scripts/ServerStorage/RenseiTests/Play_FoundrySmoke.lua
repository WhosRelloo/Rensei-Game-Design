-- Play_FoundrySmoke (Foundry Yard plan Task 9, 2026-10-25): a smoke test of the Foundry Yard place, in the game VM
-- (LMRunSuite) with the Play client connected, inside the save snapshot / restore harness. Foundry only (its map, its
-- compass: north -Z, east +X). Every check names its RED control; a control that is cheap and changes nothing for long
-- runs inside the check every time (marked "control:"), the others (they move or break the world) were run once in
-- Play from a temporary module (Task 9's report). The suite exposes Opt (the switches those controls set) and its
-- helpers through its metatable: TestKit runs only the suite's own keys.
--   * EveryPostIsReachable   the 88 RenseiPosts of Map.Foundry each have a path from the hub (errand_square + (0, 2, 0);
--                            guard_square's for errand_square itself), PathfindingService at the Mover's own radii in
--                            turn (Mover.Agent 2.5, NarrowRadii 2 and 1.5, SqueezeRadius 1; its height, spacing and
--                            Costs), ending within 2.5 of the post's foot (Task 4's reach test, Ruling 25 (3): the last
--                            waypoint sits on the navmesh, under the stand point). And (Ruling 39) a rig-sized box where
--                            a townsperson stands at the post overlaps no colliding part: 3 x 3 (Task 4's spot test),
--                            from the post's foot (post - 1) + Mover.StepHeight (1.5: a kerb a rig steps beside or onto
--                            isn't in the way; 11 Workers' Row posts stand beside 0.5-stud kerbs) up to the foot +
--                            Mover.Agent.AgentHeight (5.5). Controls (run once): a post pivoted into the great
--                            hall's Back wall at floor level, (400, 5, -394), fails the box (the reach alone passes it:
--                            the 2-stud wall is within the path's 2.5 tolerance); one at the wall's centre, (400, 19,
--                            -394), fails the reach.
--   * EveryPostHasAShelter   each post's nearest Shelter post (from where a rig's root stands, 3 over the post) is at
--                            most 145 studs off (Ruling 37). Control (inline): the same function given a synthetic post
--                            at (0, 5, 760) reports it.
--   * EdgesCantBeGrabbed     one spot per map edge, chosen without reading the tag: a ray from (0, ground + 3, -400)
--                            toward -X and +X, from (-400, ground + 3, 0) toward -Z and from (300, ground + 3, 0) toward
--                            +Z (clear of the road portal) meets its first part of Map.Foundry.Edges.Edge_<W|E|N|S>; the
--                            root stands 2 studs short of it, facing it. MovementState.Grippable is false for that part
--                            and the server refuses a climb and a wall run (Refused:NoWall), through SmokeKit.Ask and
--                            SmokeKit.WithRoot. Control (inline, at the west spot): with the RenseiNoGrip tags within 12
--                            studs taken off, the climb is accepted; the tags go back and the tagged count is the same.
--   * LedgesFaceTheirWalls   every RenseiLedge of Map.Foundry (377): a ray from its centre along its LookVector meets
--                            a part within 1.5 studs, and the hit normal . LookVector < -0.7. Control: a ledge turned
--                            180 degrees fails. (The clean run found no misfaced ledge: fix_ledges.lua isn't needed.)
--   * LampsFollowTheClock    the 154 NightOnly parts of Map.Foundry are all in WorldClock.NightParts; held at 23:00
--                            each has an enabled Light and isn't WorldClock.DayMaterial, held at 12:00 each Light is
--                            off and the material is DayMaterial; the clock is put back. Control: a lamp without its
--                            NightOnly fails the count.
--   * PondSwims              terrain Water at (490, 0, -148), (440, -2, -120) and (540, -4, -180), Air at (490, 6, -148);
--                            the player pivoted to (490, 1, -148) is in deep water (SwimService.InDeepWater) and in the
--                            server's swim state (MovementState.Get == "Swim", as SwimService sets it) within 3 s;
--                            pivoted to (-648, 9, 360), out of it within ExitChecks x CheckEvery + 1 s. Control
--                            (inline): at (490, 9, -60), dry ground, InDeepWater is false.
--   * TravelIsSingle         one RenseiArrival RoadStart (under Map.Foundry.Travel.SouthRoad) and one Platform (under
--                            Travel.Station) in workspace, one RenseiPlatformTrain with Route LindenmoorFoundry, and
--                            TravelService.ArrivalPoint returns those. Control: a duplicated Platform arrival fails.
--   * TrialsAreInTheWorld    one RenseiTrial in workspace (metal_experiment) with its TrialPrompt, none outside
--                            workspace. Control: a tagged clone in ServerStorage fails.
--   * BrannocCanBeTalkedTo   Play_FoundryForge's BrannocTalks (required, not copied). Control: Brannoc pivoted 10
--                            studs off his spot fails the "within 6 studs" assertion.
--   * EnemiesStandInTheWorld the RenseiEnemySpawns in workspace are 4 Grunts and 1 WardAlchemist (decision B); the area
--                            at each Grunt spawn is The Underworks and at the Ward spawn Silent Forge, no spawn lies in
--                            another area (none in the town above); the Ward spawn is inside the Silent Forge interior;
--                            each has a live enemy within 30 s of Start; then SmokeKit.EnemiesStandInTheWorld with
--                            ExpectSpawns and AreaOf. Control: a tagged Grunt spawn clone on Foundry Square fails "no
--                            spawn in another area" (the clone and its enemy are removed).
--   * CompassMarksPointTrue  Regions.NorthOf() is "-Z"; ReplicatedStorage.CompassPoints has a Spawn point within 0.5 of
--                            each spawn, a Talk point trainer_metal within 3 of Brannoc, a Trial point
--                            metal_experiment, Inspect points for the two ledger clues and the four metal_* parts, and
--                            an Area point for each of the 11 area names and Silent Forge. Bearings from live positions
--                            only: from the TrainerSpot marker every Grunt spawn bears |b| > 90 (south), the hall's
--                            pivot and the Ward spawn (0, 90) (north-east). Control (inline): on a "+Z" compass the hall
--                            is not north-east.
--   * TownsfolkAtTheirPosts  held at 10:00, LoadRegion("Foundry", the roster) is true; 1.5 s later all 26 are spawned,
--                            each within 1.5 studs of its 10:00 post. Control (inline): every townsperson whose 16:00
--                            post is another post (17 of the 26; at least half) is more than 1.5 studs from it.
--   * CommuteWalks           the player at (-300, 7, -440); held at 10:00 (LoadRegion places everyone) fy_runner_1 is
--                            AtPost at errand_square; held at 11:00, within 90 s (PROPOSAL; the 380-stud walk at
--                            WalkSpeed 8 is about 48 s) it passes Walking and ends AtPost at errand_row, within 1.5
--                            studs of the post. Control (Opt.CommuteAway): the player 600 studs up, nobody within 300 of
--                            the runner: it is placed, not walked, and "passes through Walking" fails.
--   * TownsfolkLoopIsCheap   (spec §9) TownsfolkService.Step wrapped with an os.clock timer for 60 s, the player in
--                            Foundry Square (-90, 7, -509), the clock running: the average Step under 1 ms. Reports
--                            Mover.Stats().StepMs, Mover.P99StepMs() and Walkers (printed, and ServerStorage's attribute
--                            FoundrySmokeLoop). Control (Opt.BusyMs = 2): a 2 ms busy-wait inside the wrapper fails.
--   * UnderworksIsShaded     (Ruling 13) held at 12:00, LightService.ExposureAt at the docket clue + (0, 2, 0), in the
--                            underworks tunnel, is lower than at the square_shelter post + (0, 2, 0) on the open square.
--                            Control (inline): the tunnel point with Map.Foundry.Landmarks and Ground left out of the
--                            rays (the roof gone) does not read lower than the square.
-- Everything a check changes (the root, the clock hold, tags, Step) is put back.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local SSS = game:GetService("ServerScriptService")
local Rensei = ReplicatedStorage.Modules.Data.Rensei
local Tuning = require(Rensei.TuningConfig)
local MovementState = require(ReplicatedStorage.Modules.Managers.MovementState)
local SmokeKit = require(script.Parent.SmokeKit)
local Player = game.Players:GetPlayers()[1]

local POSTS = 88 -- 76 imported + the 12 shelters (Task 4)
local LEDGES = 377 -- measured 2026-10-25 (Map.Foundry)
local NIGHT = 154 -- NightOnly parts of Map.Foundry, measured 2026-10-25
local SHELTER_REACH = 145 -- PROPOSAL (Ruling 37): under TownsfolkService.ShelterRadius 150
local ARRIVE = 2.5 -- the reach test's end tolerance (Task 4)
local SF = {X0 = 353.6, X1 = 392.4, Z0 = -389.4, Z1 = -339.6} -- the Silent Forge interior (as Play_FoundryForge)
local AREAS = {"Foundry Station", "The Underworks", "Practice Court", "Cinder Lane", "Lower Town", "Freight Yard",
	"South Road", "Rail Yards", "Workers' Row", "Foundry Square", "The Foundry", "Silent Forge"}
local CLUES = {"foundry_shift_ledger", "foundry_altered_docket"}
local INSPECTS = {"metal_note", "metal_gear", "metal_samples", "metal_shaft"}
local SPAWN_WAIT = 30 -- s after Start
local COMMUTE_WAIT = 90 -- s, PROPOSAL
local LOOP_SECONDS = 60
local LOOP_MS = 1 -- the average Step (spec §9)

-- the switches the run-once controls set (nil: the real check)
local Opt = {}

local function FD() return workspace.World.Map:FindFirstChild("Foundry") end
local function f1(V) return ("(%.1f, %.1f, %.1f)"):format(V.X, V.Y, V.Z) end
local function Flat(V) return Vector3.new(V.X, 0, V.Z) end
local function Skip()
	local L = {}
	for _, P in ipairs(game.Players:GetPlayers()) do if P.Character then table.insert(L, P.Character) end end
	local Live = workspace.World:FindFirstChild("Live")
	if Live then table.insert(L, Live) end
	return L
end
-- tagged instances in workspace (any new code reading a tag ignores instances outside workspace)
local function InWorld(Tag, Attr, Value)
	local Out = {}
	for _, I in ipairs(CollectionService:GetTagged(Tag)) do
		if I:IsDescendantOf(workspace) and (Attr == nil or I:GetAttribute(Attr) == Value) then table.insert(Out, I) end
	end
	return Out
end
local function Posts()
	local ById, List = {}, {}
	for _, P in ipairs(CollectionService:GetTagged("RenseiPost")) do
		if P:IsDescendantOf(FD()) then
			ById[P:GetAttribute("PostId")] = P
			table.insert(List, P)
		end
	end
	return ById, List
end
local function StandOf(Post) return (Post.CFrame * CFrame.new(0, 3, 0)).Position end
local function NameAt(Pos)
	local A = require(SSS.WorldService).AreaAt(Pos)
	return A and (A:GetAttribute("AreaName") or A.Name) or nil
end
local function Inside(Box, P) return P.X > Box.X0 and P.X < Box.X1 and P.Z > Box.Z0 and P.Z < Box.Z1 end
-- runs Fn with the clock held at Hour, then puts the clock back as it was
local function Held(Hour, Fn)
	local WorldClock = require(SSS.WorldClock)
	local WasHeld, WasHour = WorldClock.IsHeld(), WorldClock.Now()
	if Hour then WorldClock.Hold(Hour) end
	local Ok, Err = pcall(Fn, WorldClock)
	pcall(function() if WasHeld then WorldClock.Hold(WasHour) else WorldClock.Release() end end)
	if not Ok then error(Err, 0) end
end

-- ===== 1. reach =====
local function Radii()
	local Mover = require(SSS.TownsfolkService.Mover)
	local R = {Mover.Agent.AgentRadius}
	for _, X in ipairs(Mover.NarrowRadii) do table.insert(R, X) end
	table.insert(R, Mover.SqueezeRadius)
	return R
end
-- a path from Hub to Stand at the Mover's radii in turn: the radius used, or nil and the last miss
local function Reach(Hub, Stand)
	local Mover = require(SSS.TownsfolkService.Mover)
	local Foot = Stand - Vector3.new(0, 3, 0)
	local Miss
	for _, R in ipairs(Radii()) do
		local Path = PathfindingService:CreatePath({AgentRadius = R, AgentHeight = Mover.Agent.AgentHeight, AgentCanJump = false,
			AgentCanClimb = false, WaypointSpacing = Mover.Agent.WaypointSpacing, Costs = Mover.Costs})
		local Ok = pcall(Path.ComputeAsync, Path, Hub, Stand)
		if Ok and Path.Status == Enum.PathStatus.Success then
			local W = Path:GetWaypoints()
			local Last = W[#W]
			if Last then
				local D = (Last.Position - Foot).Magnitude
				if D <= ARRIVE then return R, D end
				Miss = D
			end
		end
	end
	return nil, Miss
end
-- (Ruling 39) the posts whose standing box (3 x 3, from the post's foot + the Mover's step height up to the foot + its
-- agent height) overlaps a colliding part other than the markers, the players and the live rigs:
-- {"id at (x, y, z): solid where a rig stands [names]"}
local function SolidStands(List)
	local Op = OverlapParams.new()
	Op.FilterType = Enum.RaycastFilterType.Exclude
	local Ex = Skip()
	table.insert(Ex, FD():FindFirstChild("Markers"))
	Op.FilterDescendantsInstances = Ex
	Op.RespectCanCollide = true
	local Mover = require(SSS.TownsfolkService.Mover)
	local Lo, Hi = Mover.StepHeight, Mover.Agent.AgentHeight
	local Out = {}
	for _, P in ipairs(List) do
		local Foot = P.Position - Vector3.new(0, 1, 0)
		local Hit = {}
		for _, X in ipairs(workspace:GetPartBoundsInBox(CFrame.new(Foot + Vector3.new(0, (Lo + Hi) / 2, 0)), Vector3.new(3, Hi - Lo, 3), Op)) do
			if X ~= P and not X:IsA("Terrain") then table.insert(Hit, X.Name) end
		end
		if #Hit > 0 then table.insert(Out, ("%s at %s: solid where a rig stands [%s]"):format(tostring(P:GetAttribute("PostId")), f1(P.Position), table.concat(Hit, ","))) end
	end
	return Out
end

-- the posts with no path from the hub: {"id at (x, y, z) (ends d off)"}
local function Unreached(ById, List)
	local Out = {}
	for _, P in ipairs(List) do
		local Id = P:GetAttribute("PostId")
		local Hub = ById[Id == "errand_square" and "guard_square" or "errand_square"]
		local R, Miss = Reach(Hub.Position + Vector3.new(0, 2, 0), P.Position + Vector3.new(0, 2, 0))
		if not R then table.insert(Out, ("%s at %s%s"):format(Id, f1(P.Position), Miss and (" (ends %.2f off)"):format(Miss) or "")) end
	end
	return Out
end

-- ===== 2. shelters =====
-- {"id: d to its nearest shelter"} for every post in List farther than SHELTER_REACH from every shelter
local function FarFromShelter(List)
	local Shelters = {}
	for _, P in ipairs(select(2, Posts())) do
		if P:GetAttribute("Kind") == "Shelter" then table.insert(Shelters, P) end
	end
	local Out = {}
	for _, P in ipairs(List) do
		local At = StandOf(P)
		local Best = math.huge
		for _, S in ipairs(Shelters) do Best = math.min(Best, (S.Position - At).Magnitude) end
		if Best > SHELTER_REACH then table.insert(Out, ("%s: %.0f"):format(tostring(P:GetAttribute("PostId")), Best)) end
	end
	return Out, #Shelters
end

-- ===== 4. ledges =====
local function LedgeProblems()
	local RP = RaycastParams.new()
	RP.FilterType = Enum.RaycastFilterType.Exclude
	local Out, N = {}, 0
	for _, L in ipairs(CollectionService:GetTagged(Tuning.LedgeWalk.Tag)) do
		if L:IsA("BasePart") and L:IsDescendantOf(FD()) then
			N += 1
			local Ex = Skip()
			table.insert(Ex, L)
			RP.FilterDescendantsInstances = Ex
			local Look = L.CFrame.LookVector
			local Hit = workspace:Raycast(L.Position, Look * 1.5, RP)
			if not Hit then
				table.insert(Out, L:GetFullName() .. ": no wall within 1.5 in front")
			elseif Hit.Normal:Dot(Look) >= -0.7 then
				table.insert(Out, ("%s: %s's face looks %.2f along it, not back at it"):format(L:GetFullName(), Hit.Instance.Name, Hit.Normal:Dot(Look)))
			end
		end
	end
	return Out, N
end

local Suite = {}

function Suite.EveryPostIsReachable(T)
	local ById, List = Posts()
	T.Eq(#List, POSTS, "RenseiPosts in Map.Foundry")
	T.True(ById.errand_square ~= nil and ById.guard_square ~= nil, "the hub posts errand_square and guard_square")
	local Solid = SolidStands(List)
	T.Eq(#Solid, 0, "posts with something solid where a townsperson stands: " .. table.concat(Solid, "; "))
	local Bad = Unreached(ById, List)
	T.Eq(#Bad, 0, "posts with no path from the hub at radii " .. table.concat(Radii(), "/") .. ": " .. table.concat(Bad, "; "))
end

function Suite.EveryPostHasAShelter(T)
	local _, List = Posts()
	local Far, NS = FarFromShelter(List)
	T.True(NS >= 1, "Map.Foundry has Shelter posts")
	T.Eq(#Far, 0, ("posts over %d from a shelter: %s"):format(SHELTER_REACH, table.concat(Far, ", ")))
	-- control: the same function reports a post at the south edge
	local Fake = Instance.new("Part")
	Fake.Anchored, Fake.CanCollide, Fake.CanQuery = true, false, false
	Fake.CFrame = CFrame.new(0, 5, 760)
	Fake:SetAttribute("PostId", "control_far_post")
	local Ctl = FarFromShelter({Fake})
	Fake:Destroy()
	T.Eq(#Ctl, 1, "control: a synthetic post at (0, 5, 760) is reported")
end

-- the four edge spots: {Name, Origin XZ, Dir, Edge model name}
local EDGES = {
	{Name = "west", From = Vector2.new(0, -400), Dir = Vector3.new(-1, 0, 0), Edge = "Edge_W"},
	{Name = "east", From = Vector2.new(0, -400), Dir = Vector3.new(1, 0, 0), Edge = "Edge_E"},
	{Name = "north", From = Vector2.new(-400, 0), Dir = Vector3.new(0, 0, -1), Edge = "Edge_N"},
	{Name = "south", From = Vector2.new(300, 0), Dir = Vector3.new(0, 0, 1), Edge = "Edge_S"},
}
function Suite.EdgesCantBeGrabbed(T)
	local NOGRIP = Tuning.Parkour.NoGripTag
	local Edges = FD():FindFirstChild("Edges")
	T.True(Edges ~= nil, "Map.Foundry.Edges")
	local GP = RaycastParams.new()
	GP.FilterType = Enum.RaycastFilterType.Exclude
	GP.FilterDescendantsInstances = Skip()
	GP.RespectCanCollide = true
	local EP = RaycastParams.new()
	EP.FilterType = Enum.RaycastFilterType.Include
	for I, E in ipairs(EDGES) do
		local Model = Edges:FindFirstChild(E.Edge)
		T.True(Model ~= nil, "Map.Foundry.Edges." .. E.Edge)
		local Down = workspace:Raycast(Vector3.new(E.From.X, 200, E.From.Y), Vector3.new(0, -400, 0), GP)
		T.True(Down ~= nil, E.Name .. ": ground under the spot's origin")
		local O = Vector3.new(E.From.X, Down.Position.Y + 3, E.From.Y)
		EP.FilterDescendantsInstances = {Model}
		local Hit = workspace:Raycast(O, E.Dir * 1200, EP)
		T.True(Hit ~= nil, ("%s: a ray from %s meets %s"):format(E.Name, f1(O), E.Edge))
		local Stand = Hit.Position - E.Dir * 2
		local Where = ("%s edge: %s at %s, the root at %s"):format(E.Name, Hit.Instance.Name, f1(Hit.Position), f1(Stand))
		T.Eq(MovementState.Grippable(Hit.Instance), false, Where .. ": Grippable")
		SmokeKit.WithRoot(Player, function(Character, Root)
			Root.Anchored = true
			Root.CFrame = CFrame.lookAt(Stand, Stand + E.Dir)
			task.wait(0.1)
			local Kind, Why = SmokeKit.Ask(Player, Character, "Climb")
			T.Eq(Kind, "None", Where .. ": a climb is refused (" .. tostring(Why) .. ")")
			T.Eq(Why, "Refused:NoWall", Where .. ": refused as if no wall were there")
			Kind, Why = SmokeKit.Ask(Player, Character, "WallRun")
			T.Eq(Kind, "None", Where .. ": a wall run is refused (" .. tostring(Why) .. ")")
			T.Eq(Why, "Refused:NoWall", Where .. ": wall run refused as if no wall were there")
			if I == 1 then
				-- control: the tags within 12 studs off for a moment, the same climb is accepted
				local Untagged = {}
				local Before = #CollectionService:GetTagged(NOGRIP)
				local Ok, Err = pcall(function()
					for _, P in ipairs(workspace:GetPartBoundsInRadius(Stand, 12)) do
						if CollectionService:HasTag(P, NOGRIP) then
							CollectionService:RemoveTag(P, NOGRIP)
							table.insert(Untagged, P)
						end
					end
					T.True(#Untagged > 0, Where .. ": control: tagged edge parts within 12 studs")
					local K2, W2 = SmokeKit.Ask(Player, Character, "Climb")
					T.Eq(K2, "Climb", Where .. ": control: untagged, the same climb is accepted (" .. tostring(W2) .. ")")
				end)
				for _, P in ipairs(Untagged) do CollectionService:AddTag(P, NOGRIP) end
				if not Ok then error(Err, 0) end
				T.Eq(#CollectionService:GetTagged(NOGRIP), Before, Where .. ": control: every RenseiNoGrip tag is back")
			end
		end)
	end
end

function Suite.LedgesFaceTheirWalls(T)
	local Bad, N = LedgeProblems()
	T.Eq(N, LEDGES, "RenseiLedges in Map.Foundry")
	T.Eq(#Bad, 0, #Bad .. " ledges don't face their walls: " .. table.concat(Bad, "; ", 1, math.min(#Bad, 8)))
end

function Suite.LampsFollowTheClock(T)
	Held(nil, function(WorldClock)
		local Lamps = {}
		for _, D in ipairs(FD():GetDescendants()) do
			if D:IsA("BasePart") and D:GetAttribute("NightOnly") then table.insert(Lamps, D) end
		end
		T.Eq(#Lamps, NIGHT, "NightOnly parts in Map.Foundry")
		for _, P in ipairs(Lamps) do T.True(WorldClock.NightParts[P] == true, P:GetFullName() .. " is in WorldClock.NightParts") end
		local function Lights(P)
			local L = {}
			for _, X in ipairs(P:GetDescendants()) do if X:IsA("Light") then table.insert(L, X) end end
			return L
		end
		for _, Case in ipairs({{23, true}, {12, false}}) do
			local Hour, Night = Case[1], Case[2]
			WorldClock.Hold(Hour)
			task.wait(1.6) -- (the clock's 1 s tick sweeps the lamps)
			for _, P in ipairs(Lamps) do
				local L = Lights(P)
				if Night then
					local On = false
					for _, X in ipairs(L) do On = On or X.Enabled end
					T.True(On, ("%s has an enabled Light at %02d:00"):format(P:GetFullName(), Hour))
					T.True(P.Material ~= WorldClock.DayMaterial, ("%s keeps its night material at %02d:00"):format(P:GetFullName(), Hour))
				else
					for _, X in ipairs(L) do T.Eq(X.Enabled, false, ("%s's %s at %02d:00"):format(P:GetFullName(), X.ClassName, Hour)) end
					T.Eq(P.Material, WorldClock.DayMaterial, ("%s's material at %02d:00"):format(P:GetFullName(), Hour))
				end
			end
		end
	end)
end

function Suite.PondSwims(T)
	local SwimService = require(SSS.SwimService)
	local Swim = Tuning.Swim
	local Terrain = workspace.Terrain
	local function Voxel(P)
		local X0, Y0, Z0 = math.floor(P.X / 4) * 4, math.floor(P.Y / 4) * 4, math.floor(P.Z / 4) * 4
		local M, O = Terrain:ReadVoxels(Region3.new(Vector3.new(X0, Y0, Z0), Vector3.new(X0 + 4, Y0 + 4, Z0 + 4)), 4)
		return M[1][1][1], O[1][1][1]
	end
	for _, P in ipairs({Vector3.new(490, 0, -148), Vector3.new(440, -2, -120), Vector3.new(540, -4, -180)}) do
		T.Eq(Voxel(P), Enum.Material.Water, "the terrain at " .. f1(P))
	end
	T.Eq(Voxel(Vector3.new(490, 6, -148)), Enum.Material.Air, "the terrain over the pond at (490, 6, -148)")
	SmokeKit.WithRoot(Player, function(Character, Root)
		Root.Anchored = true
		-- control: dry ground
		Character:PivotTo(CFrame.new(490, 9, -60))
		task.wait(0.2)
		T.Eq(SwimService.InDeepWater(Character), false, "control: InDeepWater on dry ground at (490, 9, -60)")
		Character:PivotTo(CFrame.new(490, 1, -148))
		local T0 = os.clock()
		while not (SwimService.InDeepWater(Character) and MovementState.Get(Character) == "Swim") and os.clock() - T0 < 3 do task.wait(0.05) end
		T.Eq(SwimService.InDeepWater(Character), true, "in deep water at (490, 1, -148) within 3 s")
		T.Eq(MovementState.Get(Character), "Swim", "the server's swim state is on within 3 s")
		Character:PivotTo(CFrame.new(-648, 9, 360))
		local Limit = Swim.ExitChecks * Swim.CheckEvery + 1
		T0 = os.clock()
		while MovementState.Get(Character) == "Swim" and os.clock() - T0 < Limit do task.wait(0.05) end
		T.True(MovementState.Get(Character) ~= "Swim", ("the swim state is off within %.2f s on land"):format(Limit))
	end)
end

function Suite.TravelIsSingle(T)
	local Travel = FD():FindFirstChild("Travel")
	T.True(Travel ~= nil, "Map.Foundry.Travel")
	local RoadStart = InWorld("RenseiArrival", "Point", "RoadStart")
	local Platform = InWorld("RenseiArrival", "Point", "Platform")
	T.Eq(#RoadStart, 1, "RoadStart arrivals in workspace")
	T.Eq(#Platform, 1, "Platform arrivals in workspace")
	T.True(Travel:FindFirstChild("SouthRoad") and RoadStart[1]:IsDescendantOf(Travel.SouthRoad), "the RoadStart is under Travel.SouthRoad")
	T.True(Travel:FindFirstChild("Station") and Platform[1]:IsDescendantOf(Travel.Station), "the Platform is under Travel.Station")
	local Trains = InWorld("RenseiPlatformTrain")
	T.Eq(#Trains, 1, "platform trains in workspace")
	T.Eq(Trains[1]:GetAttribute("Route"), "LindenmoorFoundry", "the train's Route")
	local TS = require(SSS.TravelService)
	T.Eq(TS.ArrivalPoint("RoadStart"), RoadStart[1], "TravelService.ArrivalPoint(RoadStart)")
	T.Eq(TS.ArrivalPoint("Platform"), Platform[1], "TravelService.ArrivalPoint(Platform)")
end

function Suite.TrialsAreInTheWorld(T)
	local In, Out = {}, {}
	for _, P in ipairs(CollectionService:GetTagged("RenseiTrial")) do
		if P:IsDescendantOf(workspace) then table.insert(In, P) else table.insert(Out, P:GetFullName()) end
	end
	T.Eq(#In, 1, "RenseiTrials in workspace")
	T.Eq(In[1]:GetAttribute("TrialId"), "metal_experiment", "the trial's TrialId")
	T.True(In[1]:FindFirstChild("TrialPrompt") ~= nil, "the trial marker got its TrialPrompt")
	T.Eq(#Out, 0, "RenseiTrials outside workspace: " .. table.concat(Out, ", "))
end

function Suite.BrannocCanBeTalkedTo(T)
	-- Task 7's check, required (not copied): DialogueId, TalkPrompt, within 6 studs of the TrainerSpot, his look, Open
	require(script.Parent.Play_FoundryForge).BrannocTalks(T)
end

function Suite.EnemiesStandInTheWorld(T)
	local ES = require(SSS.EnemyService)
	local Spawns = InWorld("RenseiEnemySpawn")
	local Want = {Grunt = "The Underworks", WardAlchemist = "Silent Forge"}
	-- no spawn in any other area (none in the town above): checked first, so the control fails here
	local Elsewhere = {}
	for _, P in ipairs(Spawns) do
		local Name = NameAt(P.Position)
		if Name ~= "The Underworks" and Name ~= "Silent Forge" then
			table.insert(Elsewhere, ("%s (%s) at %s in %s"):format(P.Name, tostring(P:GetAttribute("EnemyType")), f1(P.Position), tostring(Name)))
		end
	end
	T.Eq(#Elsewhere, 0, "RenseiEnemySpawns in another area: " .. table.concat(Elsewhere, "; "))
	local Count = {}
	for _, P in ipairs(Spawns) do
		local Kind = P:GetAttribute("EnemyType")
		Count[Kind] = (Count[Kind] or 0) + 1
		T.Eq(NameAt(P.Position), Want[Kind], P:GetFullName() .. "'s area")
		if Kind == "WardAlchemist" then T.True(Inside(SF, P.Position), "the Ward spawn " .. f1(P.Position) .. " is inside the Silent Forge interior") end
	end
	T.Eq(#Spawns, 5, "RenseiEnemySpawns in workspace")
	T.Eq(Count.Grunt, 4, "Grunt spawns")
	T.Eq(Count.WardAlchemist, 1, "WardAlchemist spawns")
	-- each has a live enemy within SPAWN_WAIT s of Start
	local Missing
	repeat
		Missing = {}
		local Live = {}
		for Rig, E in pairs(ES.Active) do
			local H = Rig:FindFirstChildOfClass("Humanoid")
			if H and H.Health > 0 then Live[E.Home] = true end
		end
		for _, P in ipairs(Spawns) do if not Live[P] then table.insert(Missing, P.Name) end end
		if #Missing > 0 then task.wait(0.5) end
	until #Missing == 0 or workspace.DistributedGameTime > SPAWN_WAIT
	T.Eq(#Missing, 0, ("spawns with no live enemy %d s after Start: %s"):format(SPAWN_WAIT, table.concat(Missing, ", ")))
	SmokeKit.EnemiesStandInTheWorld(T, {ExpectSpawns = {Grunt = 4, WardAlchemist = 1},
		AreaOf = function(P) return Want[P:GetAttribute("EnemyType")] end})
end

function Suite.CompassMarksPointTrue(T)
	local Regions = require(Rensei.Regions)
	T.Eq(Regions.NorthOf(), "-Z", "Foundry's north")
	local Folder = ReplicatedStorage:WaitForChild("CompassPoints", 10)
	T.True(Folder ~= nil, "ReplicatedStorage.CompassPoints")
	local T0 = os.clock()
	while (Folder:GetAttribute("Count") or 0) == 0 and os.clock() - T0 < 10 do task.wait(0.25) end
	local Points = {}
	for _, F in ipairs(Folder:GetChildren()) do
		local K = F:GetAttribute("Kind")
		Points[K] = Points[K] or {}
		table.insert(Points[K], {Key = F:GetAttribute("Key"), Pos = F:GetAttribute("Position")})
	end
	local function Near(Kind, Key, Pos, Within)
		local Best = math.huge
		for _, P in ipairs(Points[Kind] or {}) do
			if P.Key == Key and typeof(P.Pos) == "Vector3" then Best = math.min(Best, Pos and (P.Pos - Pos).Magnitude or 0) end
		end
		return Best < math.huge and Best <= (Within or math.huge), Best
	end
	local Spawns = InWorld("RenseiEnemySpawn")
	for _, P in ipairs(Spawns) do
		local Ok, D = Near("Spawn", P:GetAttribute("EnemyType"), P.Position, 0.5)
		T.True(Ok, ("a Spawn point within 0.5 of %s (nearest %.2f)"):format(P.Name, D))
	end
	local Brannoc
	for _, D in ipairs(workspace:GetDescendants()) do
		if D:IsA("Model") and D:GetAttribute("DialogueId") == "trainer_metal" then Brannoc = D end
	end
	T.True(Brannoc ~= nil, "Brannoc in workspace")
	local Ok, D = Near("Talk", "trainer_metal", Brannoc:GetPivot().Position, 3)
	T.True(Ok, ("a Talk point trainer_metal within 3 of Brannoc (nearest %.2f)"):format(D))
	T.True((Near("Trial", "metal_experiment")), "a Trial point metal_experiment")
	for _, Id in ipairs(CLUES) do T.True((Near("Inspect", Id)), "an Inspect point " .. Id) end
	for _, Id in ipairs(INSPECTS) do T.True((Near("Inspect", Id)), "an Inspect point " .. Id) end
	for _, Name in ipairs(AREAS) do T.True((Near("Area", Name)), "an Area point " .. Name) end
	-- bearings, from live positions only
	local Spot
	for _, P in ipairs(InWorld("RenseiMarker", "Piece", "TrainerSpot")) do
		if P:GetAttribute("Element") == "Metal" then Spot = P end
	end
	T.True(Spot ~= nil, "the Metal TrainerSpot marker")
	local From = Spot.Position
	local function B(To, North) return Regions.Bearing(To.X - From.X, To.Z - From.Z, North or Regions.NorthOf()) end
	for _, P in ipairs(Spawns) do
		local Bear = B(P.Position)
		if P:GetAttribute("EnemyType") == "Grunt" then
			T.True(math.abs(Bear) > 90, ("the Grunt spawn %s bears %.1f from the TrainerSpot (south: |b| > 90)"):format(P.Name, Bear))
		else
			T.True(Bear > 0 and Bear < 90, ("the Ward spawn bears %.1f from the TrainerSpot (north-east: 0..90)"):format(Bear))
		end
	end
	local Hall = FD().Landmarks:FindFirstChild("GreatHall_great_hall")
	T.True(Hall ~= nil, "Map.Foundry.Landmarks.GreatHall_great_hall")
	local HB = B(Hall:GetPivot().Position)
	T.True(HB > 0 and HB < 90, ("the great hall bears %.1f from the TrainerSpot (north-east: 0..90)"):format(HB))
	-- control: on a +Z compass the hall would be in the south half
	local C = B(Hall:GetPivot().Position, "+Z")
	T.True(not (C > 0 and C < 90), ("control: on a +Z compass the hall bears %.1f, not north-east"):format(C))
end

function Suite.TownsfolkAtTheirPosts(T)
	local TS = require(SSS.TownsfolkService)
	local TownsfolkLogic = require(Rensei.TownsfolkLogic)
	local Roster = require(Rensei.Townsfolk).Regions.Foundry
	local ById = Posts()
	Held(10, function()
		T.Eq(TS.LoadRegion("Foundry", Roster), true, "LoadRegion accepts Foundry's roster at 10:00")
		task.wait(1.5) -- (the service's own 1 Hz Step runs on the same held hour)
		T.Eq(#Roster, 26, "Foundry's roster")
		local Wrong16, Moves = 0, 0
		for _, D in ipairs(Roster) do
			local Rig = TS.Get(D.Id)
			T.True(Rig ~= nil, D.Id .. " is spawned")
			local Root = Rig:FindFirstChild("HumanoidRootPart")
			local Want = TownsfolkLogic.PostAt(D.Schedule, 10)
			local Off = Flat(Root.Position - StandOf(ById[Want])).Magnitude
			T.True(Off <= 1.5, ("%s stands %.1f studs from its 10:00 post %s"):format(D.Id, Off, Want))
			local Post16 = TownsfolkLogic.PostAt(D.Schedule, 16)
			if Post16 ~= Want then
				Moves += 1
				local Off16 = Flat(Root.Position - StandOf(ById[Post16])).Magnitude
				if Off16 > 1.5 then Wrong16 += 1 end -- (Ruling 39: counted only when it holds)
				T.True(Off16 > 1.5, ("control: %s is %.1f studs from its 16:00 post %s, so that comparison fails"):format(D.Id, Off16, Post16))
			end
		end
		-- (17 of the 26 have another post at 16:00 than at 10:00, measured 2026-10-25: the brief's "at least 20" can't
		-- hold for this roster; every one of those must fail the 16:00 comparison, and they must be at least half)
		T.True(Moves >= #Roster / 2, ("control: %d of %d townsfolk have another post at 16:00 (at least half)"):format(Moves, #Roster))
		T.Eq(Wrong16, Moves, "control: every townsperson with another 16:00 post is off it")
	end)
end

function Suite.CommuteWalks(T)
	local TS = require(SSS.TownsfolkService)
	local Roster = require(Rensei.Townsfolk).Regions.Foundry
	local ById = Posts()
	local Id = "fy_runner_1"
	SmokeKit.WithRoot(Player, function(Character, Root)
		Root.Anchored = true
		Held(10, function(WorldClock)
			Character:PivotTo(CFrame.new(-300, 7, -440))
			T.Eq(TS.LoadRegion("Foundry", Roster), true, "LoadRegion at 10:00")
			local T0 = os.clock()
			local function AtPost(Post)
				local Rig = TS.Get(Id)
				return Rig and TS.State(Id) == "AtPost" and Rig:GetAttribute("PostId") == Post
			end
			while not AtPost("errand_square") and os.clock() - T0 < 10 do task.wait(0.1) end
			T.True(AtPost("errand_square"), Id .. " is AtPost at errand_square at 10:00")
			if Opt.CommuteAway then Character:PivotTo(CFrame.new(-300, 607, -440)) task.wait(0.2) end -- (control)
			WorldClock.Hold(11)
			local Walked, States = false, {}
			T0 = os.clock()
			while os.clock() - T0 < COMMUTE_WAIT do
				local S = TS.State(Id)
				if States[#States] ~= S then table.insert(States, tostring(S)) end
				if S == "Walking" then Walked = true end
				if AtPost("errand_row") then break end
				task.wait(0.1)
			end
			local Took = os.clock() - T0
			T.True(Walked, ("%s passes through Walking (states: %s)"):format(Id, table.concat(States, " > ")))
			T.True(AtPost("errand_row"), ("%s ends AtPost at errand_row within %d s (%.0f s; states %s)"):format(Id, COMMUTE_WAIT, Took, table.concat(States, " > ")))
			local Off = Flat(TS.Get(Id).HumanoidRootPart.Position - StandOf(ById.errand_row)).Magnitude
			T.True(Off <= 1.5, ("%s stands %.2f studs from errand_row"):format(Id, Off))
			print(("[FoundrySmoke] CommuteWalks: %s errand_square -> errand_row in %.1f s, %.2f off; states %s"):format(Id, Took, Off, table.concat(States, " > ")))
		end)
	end)
end

function Suite.TownsfolkLoopIsCheap(T)
	local TS = require(SSS.TownsfolkService)
	local Mover = require(SSS.TownsfolkService.Mover)
	local Times = {}
	local Real = TS.Step
	SmokeKit.WithRoot(Player, function(Character, Root)
		Root.Anchored = true
		Character:PivotTo(CFrame.new(-90, 7, -509))
		Held(nil, function(WorldClock)
			WorldClock.Release() -- the clock running
			Mover.ResetStats()
			local Busy = Opt.BusyMs and Opt.BusyMs / 1000 or 0
			TS.Step = function(...)
				local T0 = os.clock()
				while os.clock() - T0 < Busy do end -- (the control's busy-wait)
				local R = table.pack(Real(...))
				table.insert(Times, os.clock() - T0)
				return table.unpack(R, 1, R.n)
			end
			local Ok, Err = pcall(task.wait, LOOP_SECONDS)
			TS.Step = Real
			if not Ok then error(Err, 0) end
		end)
	end)
	TS.Step = Real
	local Sum = 0
	for _, X in ipairs(Times) do Sum += X end
	local Avg = #Times > 0 and Sum / #Times * 1000 or math.huge
	local St = Mover.Stats()
	local Line = ("Step avg %.3f ms over %d calls (%d s); Mover StepMs %.3f, P99StepMs %.3f, Walkers %d, PeakWalkers %d, Ticks %d"):format(
		Avg, #Times, LOOP_SECONDS, St.StepMs, Mover.P99StepMs(), St.Walkers, St.PeakWalkers or -1, St.Ticks or -1)
	print("[FoundrySmoke] TownsfolkLoopIsCheap: " .. Line)
	game.ServerStorage:SetAttribute("FoundrySmokeLoop", Line)
	T.True(#Times >= LOOP_SECONDS - 5, ("Step ran about once a second (%d calls)"):format(#Times))
	T.True(Avg < LOOP_MS, ("the average Step is under %d ms: %s"):format(LOOP_MS, Line))
end

function Suite.UnderworksIsShaded(T)
	local LightService = require(SSS.LightService)
	local Docket = InWorld("RenseiClue", "ClueId", "foundry_altered_docket")
	T.Eq(#Docket, 1, "the docket clue in workspace")
	local ById = Posts()
	T.True(ById.square_shelter ~= nil, "the square_shelter post")
	local Tunnel = Docket[1].Position + Vector3.new(0, 2, 0)
	local Square = ById.square_shelter.Position + Vector3.new(0, 2, 0)
	T.Eq(NameAt(Tunnel), "The Underworks", "the docket's point is in The Underworks")
	Held(12, function()
		task.wait(0.2)
		local Ignore = Skip()
		local In, Out = LightService.ExposureAt(Tunnel, Ignore), LightService.ExposureAt(Square, Ignore)
		print(("[FoundrySmoke] UnderworksIsShaded: tunnel %.3f, square %.3f"):format(In, Out))
		T.True(In < Out, ("at 12:00 the tunnel (%.3f) is darker than the open square (%.3f)"):format(In, Out))
		-- control: the roof left out of the rays
		local NoRoof = Skip()
		table.insert(NoRoof, FD().Landmarks)
		table.insert(NoRoof, FD().Ground)
		local Ctl = LightService.ExposureAt(Tunnel, NoRoof)
		T.True(not (Ctl < Out), ("control: with Landmarks and Ground left out the tunnel reads %.3f, not darker than the square (%.3f)"):format(Ctl, Out))
	end)
end

-- (the run-once controls' switches and the suite's helpers; not tests: TestKit runs only the suite's own keys)
return setmetatable(Suite, {__index = {Opt = Opt, Posts = Posts, Unreached = Unreached, SolidStands = SolidStands, LedgeProblems = LedgeProblems}})

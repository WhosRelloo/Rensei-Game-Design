-- Play_LindenmoorSmoke (Lindenmoor import Task 9, 2026-10-24): a smoke test of the Lindenmoor expansion in Ye, in the
-- game VM (LMRunSuite) with the Play client connected, inside the save snapshot / restore harness.
--   * CragCantBeGrabbed: at one point on each of the four edges, the player's root stands on the last ground cell
--     before the crag, facing it. The crag face is within the server's reach (TuningConfig.Traversal.ValidateReach),
--     MovementState.Grippable says no, and the server refuses a climb and a wall run ("Refused:NoWall"). Control: with
--     the RenseiNoGrip tags near that spot taken off for a moment, the same climb is accepted, so the refusal is the
--     tag's doing and not a missing wall. The tags are always put back (the tagged count is the same after). The
--     spot is chosen without reading the tag (see "the crag" below).
--   * WaterIsReal: terrain Water voxels at three points in the west creek and three in the Mill Creek gorge (the
--     water_segments.json centrelines), and a downward ray there meets the water's surface at about Top 5.2.
--   * LampsFollowTheClock: every NightOnly lamp of the expansion is in WorldClock's lamp set; with the clock held at
--     23:00 its lights are on and it has its own (night) material; held at 12:00 its lights are off and it has
--     WorldClock.DayMaterial. The clock is held through WorldClock (the game's own time service) and put back after.
--   * TravelIsSingle: exactly one RoadStart arrival (on the RoadLindenmoorFoundry road), one Platform arrival, and one
--     platform train for the LindenmoorFoundry line, in workspace.
--   * LedgeWorks: the gorge's RenseiLedge strip exists in the expansion, and its front face (LookVector) points at
--     its wall: rays from the foothold along the front meet a near wall face at both ends and the middle, and the
--     back is open.
--   * EveryTrialStarts: each RenseiTrial is in workspace with a known TrialId and got its "Begin Trial" prompt at
--     Start; each of the five trials has exactly one.
--   * TrainersCanBeTalkedTo: each of the five elemental trainers has its DialogueId (a dialogue that exists), got its
--     talk prompt at Start, and stands within 6 studs of its TrainerSpot.
--   * EnemiesStandInTheWorld (final review C1, 2026-10-24): every enemy EnemyService has live has its Home (the part
--     it spawned from) in workspace, or outside the DataModel altogether (a runtime mark: RoadService's ambushes,
--     RideEvents' holdups); never in the DataModel outside workspace (the retired old-hub GruntSpawns in RenseiBackups
--     keep their tag). No tagged spawn outside workspace has an enemy, and a downward ray from each RenseiEnemySpawn
--     in use meets ground within SPAWN_GROUND studs. Before the fix, the two retired GruntSpawns spawned Grunts from
--     ServerStorage.
-- Everything the tests change (the player's root, the clock hold, the crag tags) is put back.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local SSS = game:GetService("ServerScriptService")
local Rensei = ReplicatedStorage.Modules.Data.Rensei
local Tuning = require(Rensei.TuningConfig)
local MovementState = require(ReplicatedStorage.Modules.Managers.MovementState)
local Player = game.Players:GetPlayers()[1]

local NOGRIP = "RenseiNoGrip"

local function Expansion()
	return workspace.World.Map:FindFirstChild("LindenmoorExpansion")
end

-- ===== the crag =====
-- One point per edge: outward direction, and the spot t studs in from the edge at s along it (world studs; the
-- expansion fills x -1024..1024, z -1024..1024). Nothing in choosing the spot reads the RenseiNoGrip tag, so an
-- untagged crag part fails the test instead of being skipped:
--   * the crag's foot is found by height: walking outward, the last expansion Ground cell before the ground rises
--     more than CRAG_RISE in one step (the crag stands 80+ studs over the ground beside it);
--   * the wall in front of the player there must be an expansion Ground part facing the player;
--   * a spot is skipped only when the server's own wall rays meet a grippable part that is NOT expansion Ground
--     (a forest trunk, a lamp, a rock): that is a fair climb, and isn't the crag. The +Z edge's s -400 has an oak
--     3.5 studs off (2026-10-24). A grippable Ground part in reach is never skipped: the server takes it and the
--     refusal asserts fail.
local EDGES = {
	{Name = "+X edge", Out = Vector3.new(1, 0, 0), At = function(T, S) return Vector3.new(1024 - T, 0, S) end},
	{Name = "-X edge", Out = Vector3.new(-1, 0, 0), At = function(T, S) return Vector3.new(-1024 + T, 0, S) end},
	{Name = "+Z edge", Out = Vector3.new(0, 0, 1), At = function(T, S) return Vector3.new(S, 0, 1024 - T) end},
	{Name = "-Z edge", Out = Vector3.new(0, 0, -1), At = function(T, S) return Vector3.new(S, 0, -1024 + T) end},
}
local CRAG_RISE = 40 -- (studs in one 2-stud step: far more than any ramp or terrace step, far less than the crag)

-- the last ground cell before the crag along the edge's line at S (walking outward), from the expansion's Ground only
local function CragFoot(E, S)
	local GP = RaycastParams.new()
	GP.FilterType = Enum.RaycastFilterType.Include
	GP.FilterDescendantsInstances = {Expansion().Ground}
	local Last
	for T = 120, 2, -2 do
		local P = E.At(T, S)
		local Hit = workspace:Raycast(P + Vector3.new(0, 400, 0), Vector3.new(0, -500, 0), GP)
		if Hit then
			if Last and Hit.Position.Y - Last.Y > CRAG_RISE then return Last end -- the next cell is the crag
			Last = Vector3.new(P.X, Hit.Position.Y, P.Z)
		end
	end
	return nil
end

-- the server's own wall-in-reach rays (MovementState: 8 flat directions, at the root and 3 above, ValidateReach
-- long, any face steeper than 0.7): the first grippable wall they meet from Stand that is not expansion Ground
local function ClutterNear(Stand, Reach, MP)
	local Ground = Expansion().Ground
	for _, H in ipairs({0, 3}) do
		for I = 0, 7 do
			local A = I * math.pi / 4
			local Hit = workspace:Raycast(Stand + Vector3.new(0, H, 0), Vector3.new(math.cos(A), 0, math.sin(A)) * Reach, MP)
			if Hit and math.abs(Hit.Normal.Y) < 0.7 and MovementState.Grippable(Hit.Instance)
				and not Hit.Instance:IsDescendantOf(Ground) then
				return Hit.Instance
			end
		end
	end
	return nil
end

-- the first spot along the edge with an expansion Ground wall facing the player in reach, and no grippable clutter
-- in reach; returns the stand point, s, and why each earlier spot was skipped (for the failure message)
local function CragSpot(E, Reach, MP)
	local Ground = Expansion().Ground
	local Skipped = {}
	for S = -400, 400, 40 do
		local Foot = CragFoot(E, S)
		if Foot then
			local Stand = Foot + Vector3.new(0, 3, 0) -- (where a standing root is)
			local Front = workspace:Raycast(Stand, E.Out * Reach, MP)
			if Front and Front.Instance:IsDescendantOf(Ground) and Front.Normal:Dot(E.Out) < -0.7 then
				local Clutter = ClutterNear(Stand, Reach, MP)
				if not Clutter then return Stand, S, Skipped end
				table.insert(Skipped, ("s %d: %s"):format(S, Clutter.Name))
			else
				table.insert(Skipped, ("s %d: no Ground wall in front"):format(S))
			end
		end
	end
	return nil, nil, Skipped
end

-- asks the server for a traversal (as JumpRemote "TraversalState" does) and waits for its answer for this session:
-- the published Kind ("Climb" / "WallRun" when accepted, "None" when refused) and the reason (as Play_NoGrip)
local NextSeq = 900000
local function Ask(Character, Kind)
	NextSeq += 1
	local Seq = NextSeq
	MovementState.Request(Player, true, Kind, Seq)
	local T0 = os.clock()
	while os.clock() - T0 < 2 do
		local S, K, Why = MovementState.ParseSession(Character:GetAttribute("TraversalSession"))
		if S == Seq then
			MovementState.Clear(Character, "Test")
			return K, Why
		end
		task.wait(0.05)
	end
	return "Timeout", ""
end

-- runs Fn(Character, Root) and always clears the traversal and puts the root back
local function WithRoot(Fn)
	local Character = Player and Player.Character
	local Root = Character and Character:FindFirstChild("HumanoidRootPart")
	assert(Root, "no test player character")
	local Saved = {CFrame = Root.CFrame, Anchored = Root.Anchored}
	local Ok, Err = pcall(Fn, Character, Root)
	pcall(MovementState.Clear, Character, "Test")
	Root.Anchored = Saved.Anchored
	Root.CFrame = Saved.CFrame
	if not Ok then error(Err, 0) end
end

-- ===== water =====
-- (x, z) on the channel centrelines of Art/Regions/Lindenmoor/water_segments.json (Bed 1, Top 5.2)
local WATER = {
	{"creek_west_water_1", -470, -531}, {"creek_west_water_3", -655, -525}, {"creek_west_water_5", -834, -525},
	{"gorge_water_1", 470, -546}, {"gorge_water_3", 670, -548}, {"gorge_water_5", 885, -545},
}
local WATER_TOP = 5.2

local TRIALS = {"flame_apprentice", "ice_guardian", "earth_quarry", "wind_dancer", "metal_experiment"}

local Suite = {}

function Suite.CragCantBeGrabbed(T)
	T.True(Expansion() ~= nil, "World.Map.LindenmoorExpansion is there")
	T.Eq(Tuning.Parkour.NoGripTag, NOGRIP, "TuningConfig.Parkour.NoGripTag")
	local Reach = Tuning.Traversal.ValidateReach
	local MP = RaycastParams.new()
	MP.FilterType = Enum.RaycastFilterType.Include
	MP.FilterDescendantsInstances = {workspace.World.Map}
	for _, E in ipairs(EDGES) do
		local Stand, S, Skipped = CragSpot(E, Reach, MP)
		T.True(Stand ~= nil, E.Name .. ": a spot at the crag's foot without grippable clutter (" .. table.concat(Skipped, "; ") .. ")")
		WithRoot(function(Character, Root)
			Root.Anchored = true
			Root.CFrame = CFrame.lookAt(Stand, Stand + E.Out)
			task.wait(0.1)
			for _, H in ipairs({0, 3}) do
				local O = Stand + Vector3.new(0, H, 0)
				local Hit = workspace:Raycast(O, E.Out * Reach, MP)
				local Where = ("%s at (%.0f, %.0f, %.0f) +%d"):format(E.Name, O.X, O.Y, O.Z, H)
				T.True(Hit ~= nil, Where .. ": the crag face is within reach (" .. Reach .. ")")
				T.True(Hit.Instance:IsDescendantOf(Expansion().Ground), Where .. ": it is expansion Ground (" .. Hit.Instance.Name .. ")")
				T.True(Hit.Normal:Dot(E.Out) < -0.7, Where .. ": it is a wall facing the player")
				T.Eq(MovementState.Grippable(Hit.Instance), false, Where .. ": " .. Hit.Instance.Name .. " can't be gripped")
			end
			local Kind, Why = Ask(Character, "Climb")
			T.Eq(Kind, "None", E.Name .. ": a climb on the crag is refused")
			T.Eq(Why, "Refused:NoWall", E.Name .. ": refused as if no wall were there")
			Kind, Why = Ask(Character, "WallRun")
			T.Eq(Kind, "None", E.Name .. ": a wall run on the crag is refused")
			T.Eq(Why, "Refused:NoWall", E.Name .. ": wall run refused as if no wall were there")
			-- control: the same spot with the crag's tags off for a moment takes a climb
			local Untagged = {}
			local Before = #CollectionService:GetTagged(NOGRIP)
			local Ok, Err = pcall(function()
				for _, P in ipairs(workspace:GetPartBoundsInRadius(Stand, Reach + 16)) do
					if CollectionService:HasTag(P, NOGRIP) then
						CollectionService:RemoveTag(P, NOGRIP)
						table.insert(Untagged, P)
					end
				end
				T.True(#Untagged > 0, E.Name .. ": crag parts near the spot")
				T.True(MovementState.Grippable(Untagged[1]), E.Name .. ": untagged, the crag could be gripped")
				local K2, W2 = Ask(Character, "Climb")
				T.Eq(K2, "Climb", E.Name .. ": control: untagged, the same climb is accepted (" .. tostring(W2) .. ")")
			end)
			for _, P in ipairs(Untagged) do CollectionService:AddTag(P, NOGRIP) end
			if not Ok then error(Err, 0) end
			T.Eq(MovementState.Grippable(Untagged[1]), false, E.Name .. ": the tags are back")
			T.Eq(#CollectionService:GetTagged(NOGRIP), Before, E.Name .. ": every RenseiNoGrip tag is back")
		end)
	end
end

function Suite.WaterIsReal(T)
	local Terrain = workspace.Terrain
	local TP = RaycastParams.new()
	TP.FilterType = Enum.RaycastFilterType.Include
	TP.FilterDescendantsInstances = {Terrain}
	TP.IgnoreWater = false
	for _, W in ipairs(WATER) do
		local Id, X, Z = W[1], W[2], W[3]
		local X0, Z0 = math.floor(X / 4) * 4, math.floor(Z / 4) * 4
		local Mats, Occ = Terrain:ReadVoxels(Region3.new(Vector3.new(X0, 0, Z0), Vector3.new(X0 + 4, 4, Z0 + 4)), 4)
		local M, O = Mats[1][1][1], Occ[1][1][1]
		T.Eq(M, Enum.Material.Water, ("%s (%d, %d): the voxel at y 0..4"):format(Id, X, Z))
		T.True(O > 0, ("%s: water fills it (occupancy %.2f)"):format(Id, O))
		local Hit = workspace:Raycast(Vector3.new(X, 40, Z), Vector3.new(0, -60, 0), TP)
		T.True(Hit ~= nil and Hit.Material == Enum.Material.Water,
			("%s: a ray from above meets water (got %s)"):format(Id, Hit and Hit.Material.Name or "nothing"))
		T.True(math.abs(Hit.Position.Y - WATER_TOP) <= 1.5, ("%s: the surface at %.1f (Top %.1f)"):format(Id, Hit.Position.Y, WATER_TOP))
	end
end

function Suite.LampsFollowTheClock(T)
	local WorldClock = require(SSS.WorldClock)
	local Lamps = {}
	for _, D in ipairs(Expansion():GetDescendants()) do
		if D:IsA("BasePart") and D:GetAttribute("NightOnly") then table.insert(Lamps, D) end
	end
	T.True(#Lamps > 0, "the expansion has NightOnly lamps")
	local WasHeld, WasHour = WorldClock.IsHeld(), WorldClock.Now()
	local Ok, Err = pcall(function()
		for _, P in ipairs(Lamps) do
			T.True(WorldClock.NightParts[P] == true, P:GetFullName() .. " is in WorldClock's lamp set")
			local N = 0
			for _, L in ipairs(P:GetChildren()) do if L:IsA("Light") then N += 1 end end
			T.True(N > 0, P:GetFullName() .. " has a light")
		end
		local function Check(Hour, Night)
			WorldClock.Hold(Hour)
			task.wait(1.6) -- (the clock's 1 s tick sweeps the lamps)
			for _, P in ipairs(Lamps) do
				local Name = P.Parent.Name .. "." .. P.Name
				for _, L in ipairs(P:GetChildren()) do
					if L:IsA("Light") then T.Eq(L.Enabled, Night, ("%s: its %s at %02d:00"):format(Name, L.ClassName, Hour)) end
				end
				local Want = Night and Enum.Material[P:GetAttribute("NightMaterial") or "Neon"] or WorldClock.DayMaterial
				T.Eq(P.Material, Want, ("%s: its material at %02d:00"):format(Name, Hour))
			end
		end
		Check(23, true)
		Check(12, false)
	end)
	pcall(function()
		if WasHeld then WorldClock.Hold(WasHour) else WorldClock.Release() end
	end)
	if not Ok then error(Err, 0) end
	T.Eq(WorldClock.IsHeld(), WasHeld, "the clock hold is put back")
end

function Suite.TravelIsSingle(T)
	local RoadStart, Platform, Trains, LineTrains = {}, {}, {}, {}
	for _, P in ipairs(CollectionService:GetTagged("RenseiArrival")) do
		if P:IsDescendantOf(workspace) then
			if P:GetAttribute("Point") == "RoadStart" then table.insert(RoadStart, P) end
			if P:GetAttribute("Point") == "Platform" then table.insert(Platform, P) end
		end
	end
	for _, M in ipairs(CollectionService:GetTagged("RenseiPlatformTrain")) do
		if M:IsDescendantOf(workspace) then
			table.insert(Trains, M)
			if M:GetAttribute("Route") == "LindenmoorFoundry" then table.insert(LineTrains, M) end
		end
	end
	T.Eq(#RoadStart, 1, "RoadStart arrivals in workspace")
	T.Eq(#Platform, 1, "Platform arrivals in workspace")
	T.Eq(#LineTrains, 1, "platform trains for LindenmoorFoundry")
	T.Eq(#Trains, 1, "platform trains in workspace")
	-- the one RoadStart is the road's own, on RoadLindenmoorFoundry, in the expansion's Travel
	local Road = RoadStart[1]:FindFirstAncestorWhichIsA("Model")
	local Route
	for _, D in ipairs(Road:GetDescendants()) do
		if CollectionService:HasTag(D, "RenseiRoadPassage") then Route = Route or D:GetAttribute("Route") end
	end
	T.Eq(Route, "RoadLindenmoorFoundry", "the RoadStart is on the RoadLindenmoorFoundry road")
	T.True(RoadStart[1]:IsDescendantOf(Expansion().Travel), "the RoadStart is in LindenmoorExpansion.Travel")
	local TS = require(SSS.TravelService)
	T.Eq(TS.ArrivalPoint("RoadStart"), RoadStart[1], "TravelService finds that RoadStart")
	T.Eq(TS.ArrivalPoint("Platform"), Platform[1], "TravelService finds that Platform")
end

function Suite.LedgeWorks(T)
	local Gorge = Expansion():FindFirstChild("Gorge")
	T.True(Gorge ~= nil, "LindenmoorExpansion.Gorge")
	local Strips = {}
	for _, P in ipairs(CollectionService:GetTagged(Tuning.LedgeWalk.Tag)) do
		if P:IsA("BasePart") and P:IsDescendantOf(Gorge) then table.insert(Strips, P) end
	end
	T.Eq(#Strips, 1, "RenseiLedge strips in the expansion's gorge")
	local L = Strips[1]
	local Wall = Vector3.new(L.CFrame.LookVector.X, 0, L.CFrame.LookVector.Z) -- (LedgeWalk.Info's front: toward the wall)
	T.True(Wall.Magnitude > 0.99, "the strip is level (its front is flat)")
	Wall = Wall.Unit
	local MP = RaycastParams.new()
	MP.FilterType = Enum.RaycastFilterType.Include
	MP.FilterDescendantsInstances = {workspace.World.Map}
	MP.RespectCanCollide = true
	for _, F in ipairs({-0.45, 0, 0.45}) do
		local O = (L.CFrame * CFrame.new(L.Size.X * F, L.Size.Y / 2 + 2, 0)).Position
		local Where = ("ledge at %.0f%% of its length"):format((F + 0.5) * 100)
		local Hit = workspace:Raycast(O, Wall * 6, MP)
		T.True(Hit ~= nil, Where .. ": a wall in front")
		local Dist = (Hit.Position - O):Dot(Wall)
		T.True(Dist <= L.Size.Z / 2 + 1.5, ("%s: the wall is %.2f studs off the strip's middle"):format(Where, Dist))
		T.True(Hit.Normal:Dot(Wall) < -0.7, Where .. ": the wall's face looks back at the strip")
		local Back = workspace:Raycast(O, -Wall * 6, MP)
		T.True(Back == nil, Where .. ": open behind (got " .. (Back and Back.Instance.Name or "") .. ")")
	end
end

function Suite.EveryTrialStarts(T)
	local Defs = require(Rensei.Trials)
	local Count = {}
	for _, P in ipairs(CollectionService:GetTagged("RenseiTrial")) do
		local Id = P:GetAttribute("TrialId")
		T.True(P:IsDescendantOf(workspace), P:GetFullName() .. " is in workspace")
		T.True(Id ~= nil and Defs[Id] ~= nil, P:GetFullName() .. " has a known TrialId (" .. tostring(Id) .. ")")
		T.True(P:FindFirstChild("TrialPrompt") ~= nil, P:GetFullName() .. " got its Begin Trial prompt")
		Count[Id] = (Count[Id] or 0) + 1
	end
	for _, Id in ipairs(TRIALS) do T.Eq(Count[Id], 1, Id .. " sites") end
end

function Suite.TrainersCanBeTalkedTo(T)
	local Dialogues = require(Rensei.Dialogues)
	local Folder = workspace.World.NPCs:FindFirstChild("Alchemy Trainers")
	T.True(Folder ~= nil, "World.NPCs[\"Alchemy Trainers\"]")
	local Spots = {}
	for _, P in ipairs(CollectionService:GetTagged("RenseiMarker")) do
		if P:IsDescendantOf(workspace) and P:GetAttribute("Piece") == "TrainerSpot" then table.insert(Spots, P) end
	end
	T.Eq(#Spots, 5, "TrainerSpot markers")
	local Elements = {}
	for _, Spot in ipairs(Spots) do
		local El = Spot:GetAttribute("Element")
		T.True(El ~= nil and not Elements[El], "TrainerSpot " .. Spot.Name .. " has its own Element (" .. tostring(El) .. ")")
		Elements[El] = true
	end
	for _, Spot in ipairs(Spots) do
		local Element, Name = Spot:GetAttribute("Element"), Spot:GetAttribute("Trainer")
		local Trainer
		for _, M in ipairs(Folder:GetChildren()) do
			if M:GetAttribute("TrainerPath") == Element then
				T.True(Trainer == nil, "one trainer for " .. tostring(Element))
				Trainer = M
			end
		end
		T.True(Trainer ~= nil, ("the %s trainer (%s)"):format(tostring(Element), tostring(Name)))
		T.Eq(Trainer:GetAttribute("DisplayName"), Name, Element .. " trainer's name")
		local Id = Trainer:GetAttribute("DialogueId")
		T.Eq(Id, "trainer_" .. string.lower(Element), Name .. "'s DialogueId")
		local Def = Dialogues[Id]
		T.True(type(Def) == "table" and Def.Nodes and Def.Nodes[Def.Start or "start"] ~= nil, Id .. " is a dialogue")
		local Root = Trainer:FindFirstChild("HumanoidRootPart")
		T.True(Root ~= nil, Name .. " has a root")
		T.True(Root:FindFirstChild("TalkPrompt") ~= nil, Name .. " got the talk prompt")
		local Off = (Root.Position - Spot.Position).Magnitude
		T.True(Off <= 6, ("%s stands %.1f studs from the TrainerSpot (at most 6)"):format(Name, Off))
	end
end

-- ===== enemies =====
local SPAWN_GROUND = 6 -- PROPOSAL: studs from a spawn's centre down to the ground under it (Ye's spawns: 0.5..1.5)

function Suite.EnemiesStandInTheWorld(T)
	local ES = require(SSS.EnemyService)
	local Live = workspace.World:FindFirstChild("Live")
	-- the spawns in use: the Home of every live enemy
	local Used, Homes, N, Marks = {}, {}, 0, 0
	for Rig, E in pairs(ES.Active) do
		N += 1
		local Home = E.Home
		T.True(Home ~= nil, Rig.Name .. " has a Home")
		if Home:IsDescendantOf(game) then
			T.True(Home:IsDescendantOf(workspace), ("%s's Home %s is in workspace"):format(Rig.Name, Home:GetFullName()))
			if not Used[Home] then Used[Home] = true table.insert(Homes, Home) end
		else
			Marks += 1 -- (a runtime mark outside the DataModel: an ambush or holdup; it never respawns)
		end
	end
	T.True(N > 0, "EnemyService has live enemies")
	-- a tagged spawn outside workspace (a backup) has no enemy
	local Out = 0
	for _, P in ipairs(CollectionService:GetTagged("RenseiEnemySpawn")) do
		if not P:IsDescendantOf(workspace) then
			Out += 1
			T.True(not Used[P], P:GetFullName() .. " (not in workspace) has no enemy")
		end
	end
	-- no live enemy model stands on a spawn EnemyService doesn't know (a Grunt from a backup, before its Home check)
	if Live then
		for _, M in ipairs(Live:GetDescendants()) do
			if M:IsA("Model") and M:GetAttribute("EnemyType") and M:FindFirstChildOfClass("Humanoid")
				and M:FindFirstChildOfClass("Humanoid").Health > 0 and not M:GetAttribute("TownsfolkId") then
				T.True(ES.Active[M] ~= nil, M:GetFullName() .. " is one of EnemyService's live enemies")
			end
		end
	end
	-- each spawn in use stands on ground (not on a live rig or a player)
	local Skip = {Live}
	for _, Pl in ipairs(game.Players:GetPlayers()) do if Pl.Character then table.insert(Skip, Pl.Character) end end
	local RP = RaycastParams.new()
	RP.FilterType = Enum.RaycastFilterType.Exclude
	for _, Home in ipairs(Homes) do
		if not CollectionService:HasTag(Home, "RenseiEnemySpawn") then continue end -- (a trial / admin / test mark)
		local Where = Home:IsA("BasePart") and Home.Position or Home:GetPivot().Position
		local Ex = table.clone(Skip)
		table.insert(Ex, Home)
		RP.FilterDescendantsInstances = Ex
		local Hit = workspace:Raycast(Where, Vector3.new(0, -SPAWN_GROUND, 0), RP)
		T.True(Hit ~= nil, ("%s at (%.0f, %.1f, %.0f): ground within %d studs below"):format(Home:GetFullName(),
			Where.X, Where.Y, Where.Z, SPAWN_GROUND))
	end
	print(("[Play_LindenmoorSmoke] EnemiesStandInTheWorld: %d live enemies on %d spawns (+%d runtime marks); %d tagged spawns outside workspace")
		:format(N, #Homes, Marks, Out))
end

return Suite

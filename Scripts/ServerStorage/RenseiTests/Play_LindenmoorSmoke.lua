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
--     Start; each of the four trials Ye keeps has exactly one. (Foundry Yard plan Task 8, 2026-10-25: the Forge Floor and
--     its metal_experiment trial moved to Foundry, so no instance anywhere in the DataModel carries the RenseiTrial tag
--     with TrialId metal_experiment; Ye's copy waits in a backup with its tags set aside as RegionKitTags.)
--   * TrainersCanBeTalkedTo: five TrainerSpot markers, each with its own Element. The Flame, Ice, Earth and Wind
--     trainers each have their DialogueId (a dialogue that exists), got their talk prompt at Start, and stand within 6
--     studs of their TrainerSpot. Metal (Task 8, owner decision D): Brannoc teaches in Foundry now, so no model with
--     TrainerPath "Metal" is in workspace, and a part with InspectId "brannoc_moved" (his notice) stands within 6
--     studs of the Metal spot with its InspectPrompt.
--   * BrannocNoticeStartsTheQuest (Task 8): with acq_* cleared from the save and no path (Affinity ""), the player
--     standing within 9 studs of the notice inspects it (InvestigationService.Inspect, as the prompt does): acq_metal
--     starts at stage 1 (travel) with Progress.foundry 0, since TravelService.Here() is Lindenmoor. The notice's text
--     names the way the road leaves on Ye's compass (north +Z): the 8-point word for Regions.Bearing(dx, dz, "+Z")
--     from the board to the road's RoadStart arrival. The save's Quests and Identity are put back after.
--   * BrannocNoticeLeavesAPathAlone (Foundry Yard plan Task 9, Ruling 38): a player with Affinity "Flame" who inspects
--     the notice gets no acq_metal. And the direction word above is matched as a whole word (a hyphen is part of a
--     word; the roads' names "NORTH ROAD" / "SOUTH ROAD" are taken out first), with controls on the old notice text
--     (no direction word), "NORTH ROAD" and "NORTH-WEST".
--   * EnemiesStandInTheWorld (final review C1, 2026-10-24): SmokeKit.EnemiesStandInTheWorld with no Opts. Every enemy
--     EnemyService has live has its Home (the part it spawned from) in workspace, or outside the DataModel altogether
--     (a runtime mark: RoadService's ambushes, RideEvents' holdups); never in the DataModel outside workspace (the
--     retired old-hub GruntSpawns in RenseiBackups keep their tag). No tagged spawn outside workspace has an enemy,
--     and a downward ray from each RenseiEnemySpawn in use meets ground within SmokeKit.SPAWN_GROUND studs. Before the
--     fix, the two retired GruntSpawns spawned Grunts from ServerStorage.
-- The traversal and enemy helpers (Ask, WithRoot, EnemiesStandInTheWorld) and Copy / Stand live in RenseiTests.SmokeKit
-- (Task 8, Ruling 6), shared with Foundry's suites.
-- Everything the tests change (the player's root, the clock hold, the crag tags, the save's Quests and Identity) is put
-- back.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local SSS = game:GetService("ServerScriptService")
local Rensei = ReplicatedStorage.Modules.Data.Rensei
local Tuning = require(Rensei.TuningConfig)
local MovementState = require(ReplicatedStorage.Modules.Managers.MovementState)
local SmokeKit = require(script.Parent.SmokeKit)
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

-- ===== water =====
-- (x, z) on the channel centrelines of Art/Regions/Lindenmoor/water_segments.json (Bed 1, Top 5.2)
local WATER = {
	{"creek_west_water_1", -470, -531}, {"creek_west_water_3", -655, -525}, {"creek_west_water_5", -834, -525},
	{"gorge_water_1", 470, -546}, {"gorge_water_3", 670, -548}, {"gorge_water_5", 885, -545},
}
local WATER_TOP = 5.2

-- the trials Ye keeps (Task 8: metal_experiment moved to Foundry with the Forge Floor)
local TRIALS = {"flame_apprentice", "ice_guardian", "earth_quarry", "wind_dancer"}
local MOVED_TRIAL = "metal_experiment"
local NOTICE = "brannoc_moved" -- Brannoc's notice at the Metal TrainerSpot (owner decision D)
local COMPASS8 = {"NORTH", "NORTH-EAST", "EAST", "SOUTH-EAST", "SOUTH", "SOUTH-WEST", "WEST", "NORTH-WEST"}

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
		SmokeKit.WithRoot(Player, function(Character, Root)
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
			local Kind, Why = SmokeKit.Ask(Player, Character, "Climb")
			T.Eq(Kind, "None", E.Name .. ": a climb on the crag is refused")
			T.Eq(Why, "Refused:NoWall", E.Name .. ": refused as if no wall were there")
			Kind, Why = SmokeKit.Ask(Player, Character, "WallRun")
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
				local K2, W2 = SmokeKit.Ask(Player, Character, "Climb")
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
	-- (Task 8) the moved trial is nowhere in the DataModel: its backup carries no live tag
	local Moved = {}
	for _, P in ipairs(CollectionService:GetTagged("RenseiTrial")) do
		if P:GetAttribute("TrialId") == MOVED_TRIAL then table.insert(Moved, P:GetFullName()) end
	end
	T.Eq(#Moved, 0, "RenseiTrial instances with TrialId " .. MOVED_TRIAL .. " in the DataModel (it moved to Foundry): " .. table.concat(Moved, ", "))
	for _, P in ipairs(CollectionService:GetTagged("RenseiTrial")) do
		local Id = P:GetAttribute("TrialId")
		T.True(P:IsDescendantOf(workspace), P:GetFullName() .. " is in workspace")
		T.True(Id ~= nil and Defs[Id] ~= nil, P:GetFullName() .. " has a known TrialId (" .. tostring(Id) .. ")")
		T.True(P:FindFirstChild("TrialPrompt") ~= nil, P:GetFullName() .. " got its Begin Trial prompt")
		Count[Id] = (Count[Id] or 0) + 1
	end
	for _, Id in ipairs(TRIALS) do T.Eq(Count[Id], 1, Id .. " sites") end
end

-- the inspect point with InspectId Id in workspace nearest Pos, and its distance
local function NearestInspect(Id, Pos)
	local Best, Dist = nil, math.huge
	for _, P in ipairs(CollectionService:GetTagged("RenseiInspect")) do
		if P:IsDescendantOf(workspace) and P:IsA("BasePart") and P:GetAttribute("InspectId") == Id then
			local D = (P.Position - Pos).Magnitude
			if D < Dist then Best, Dist = P, D end
		end
	end
	return Best, Dist
end

-- the five TrainerSpot markers in workspace, each with its own Element: the list, and {[Element] = Spot}
local function TrainerSpots(T)
	local Spots = {}
	for _, P in ipairs(CollectionService:GetTagged("RenseiMarker")) do
		if P:IsDescendantOf(workspace) and P:GetAttribute("Piece") == "TrainerSpot" then table.insert(Spots, P) end
	end
	T.Eq(#Spots, 5, "TrainerSpot markers")
	local Elements = {}
	for _, Spot in ipairs(Spots) do
		local El = Spot:GetAttribute("Element")
		T.True(El ~= nil and not Elements[El], "TrainerSpot " .. Spot.Name .. " has its own Element (" .. tostring(El) .. ")")
		Elements[El] = Spot
	end
	return Spots, Elements
end

function Suite.TrainersCanBeTalkedTo(T)
	local Dialogues = require(Rensei.Dialogues)
	local Folder = workspace.World.NPCs:FindFirstChild("Alchemy Trainers")
	T.True(Folder ~= nil, "World.NPCs[\"Alchemy Trainers\"]")
	local Spots = TrainerSpots(T)
	for _, Spot in ipairs(Spots) do
		local Element, Name = Spot:GetAttribute("Element"), Spot:GetAttribute("Trainer")
		if Element == "Metal" then
			-- (Task 8, owner decision D) Brannoc teaches in Foundry: no Metal trainer here, his notice instead
			for _, M in ipairs(workspace:GetDescendants()) do
				if M:IsA("Model") and M:GetAttribute("TrainerPath") == "Metal" then
					T.True(false, "a Metal trainer is still in Ye's workspace: " .. M:GetFullName())
				end
			end
			local Board, Off = NearestInspect(NOTICE, Spot.Position)
			T.True(Board ~= nil, "a part with InspectId " .. NOTICE .. " in workspace")
			T.True(Off <= 6, ("the %s notice stands %.1f studs from the Metal TrainerSpot (at most 6)"):format(NOTICE, Off))
			T.True(Board:FindFirstChild("InspectPrompt") ~= nil, "the " .. NOTICE .. " notice got its InspectPrompt")
			continue
		end
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

-- ===== Brannoc's notice =====
-- the 8-point compass word for a bearing in degrees (0 north, 90 east)
local function Compass8(Deg)
	return COMPASS8[(math.floor((Deg % 360) / 45 + 0.5) % 8) + 1]
end

-- (Foundry Yard plan Task 9, Ruling 38) does Text name the way Word (an 8-point word: "NORTH", "NORTH-WEST", ...)?
-- Upper case; the roads' own names ("NORTH ROAD", "SOUTH ROAD") are taken out first; then Word must stand as a whole
-- word, where a hyphen counts as part of a word: "NORTH ROAD" can't satisfy NORTH, and "NORTH-WEST" satisfies neither
-- NORTH nor WEST.
local function NamesWay(Text, Word)
	local U = string.upper(Text):gsub("NORTH ROAD", ""):gsub("SOUTH ROAD", "")
	local Pat = "%f[%w%-]" .. Word:gsub("%-", "%%-") .. "%f[^%w%-]"
	return string.find(U, Pat) ~= nil
end
-- the notice's text as Task 8's brief first worded it (no direction word): NamesWay must refuse it (Ruling 38's control)
local OLD_NOTICE = "A notice nailed to the post where the Metal Alchemist used to stand, in square, careful capitals: \"GONE TO THE FOUNDRY YARD. A FORGE THERE NEEDS LOOKING AT. STUDENTS: TRAIN FROM LINDENMOOR STATION, OR THE NORTH ROAD. - B.\""

-- with acq_* cleared from the save and Affinity set to Affinity, the player stands within 9 studs of the notice and
-- runs Fn(Data, Board); the save's Quests and Identity, the character and the dialogue box are put back after
local function AtTheNotice(T, Affinity, Fn)
	local PS = require(SSS.ProgressionService)
	local _, Elements = TrainerSpots(T)
	local Spot = Elements.Metal
	T.True(Spot ~= nil, "the Metal TrainerSpot")
	local Board, Off = NearestInspect(NOTICE, Spot.Position)
	T.True(Board ~= nil and Off <= 6, "the " .. NOTICE .. " notice at the Metal TrainerSpot")
	local Data = Player and PS.GetData(Player)
	T.True(Data ~= nil and type(Data.Quests) == "table", "a player with a loaded save")
	local Char = Player.Character
	local Root = Char and Char:FindFirstChild("HumanoidRootPart")
	T.True(Root ~= nil, "the player has a character")
	local Home, WasAnchored = Char:GetPivot(), Root.Anchored
	local Saved = {
		Quests = {Was = Data.Quests, Copy = SmokeKit.Copy(Data.Quests)},
		Identity = {Was = Data.Identity, Copy = SmokeKit.Copy(Data.Identity)},
	}
	local Ok, Err = pcall(function()
		Data.Identity = Data.Identity or {}
		Data.Identity.Affinity = Affinity
		for _, Box in ipairs({Data.Quests.Active, Data.Quests.Completed}) do
			for Id in pairs(Box) do if string.sub(Id, 1, 4) == "acq_" then Box[Id] = nil end end
		end
		local Me = SmokeKit.Stand(Player, Board.Position)
		T.True((Me.Position - Board.Position).Magnitude <= 9, "the player stands within 9 studs of the notice")
		Fn(Data, Board)
	end)
	-- everything back: the save tables (in place), the character, the dialogue box
	local Back = {}
	local function Try(What, F)
		local K, E = pcall(F)
		if not K then table.insert(Back, What .. ": " .. tostring(E)) end
	end
	Try("save", function()
		for K, S in pairs(Saved) do
			if type(S.Was) == "table" then SmokeKit.PutBack(S.Was, S.Copy) end
			Data[K] = S.Was
		end
	end)
	Try("player", function()
		Char:PivotTo(Home)
		Root.AssemblyLinearVelocity = Vector3.zero
		Root.Anchored = WasAnchored
	end)
	Try("dialogue", function() require(SSS.DialogueService).Close(Player) end)
	Try("sync", function() PS.Sync(Player) end)
	if not Ok then error(Err, 0) end
	T.Eq(#Back, 0, "NOT PUT BACK: " .. table.concat(Back, " | "))
end

function Suite.BrannocNoticeStartsTheQuest(T)
	local Investigation = require(SSS.InvestigationService)
	local TravelService = require(SSS.TravelService)
	local Regions = require(Rensei.Regions)
	local Def = require(Rensei.Investigation).Inspects[NOTICE]
	T.True(Def ~= nil, NOTICE .. " has an inspect def")
	local _, Elements = TrainerSpots(T)
	local Board = NearestInspect(NOTICE, Elements.Metal.Position)
	-- the notice's direction word is Ye's (north +Z), toward where the road to Foundry leaves (read live, not written)
	local RoadStart = TravelService.ArrivalPoint("RoadStart")
	T.True(RoadStart ~= nil, "Ye's RoadStart arrival (the road to Foundry)")
	local D = RoadStart.Position - Board.Position
	local Deg = Regions.Bearing(D.X, D.Z, "+Z")
	local Word = Compass8(Deg)
	-- (Ruling 38) controls: the matcher refuses the old wording, a road's name and half of a hyphenated word
	T.Eq(NamesWay(OLD_NOTICE, Word), false, "control: the old notice text (no direction word) doesn't name " .. Word)
	T.Eq(NamesWay("WALK THE NORTH ROAD.", "NORTH"), false, "control: \"NORTH ROAD\" doesn't name NORTH")
	T.Eq(NamesWay("OUT NORTH-WEST.", "NORTH"), false, "control: \"NORTH-WEST\" doesn't name NORTH")
	T.Eq(NamesWay("OUT NORTH-WEST.", "WEST"), false, "control: \"NORTH-WEST\" doesn't name WEST")
	T.Eq(NamesWay("OUT NORTH-WEST.", "NORTH-WEST"), true, "control: \"OUT NORTH-WEST.\" names NORTH-WEST")
	T.True(NamesWay(Def.Text, Word), ("the notice names the road's way out on Ye's compass, %s (bearing %.0f): %s"):format(Word, Deg, Def.Text))
	T.Eq(TravelService.Here(), "Lindenmoor", "TravelService.Here()")
	AtTheNotice(T, "", function(Data, B)
		T.True(Investigation.Inspect(Player, NOTICE, B), "the notice was inspected")
		local State = Data.Quests.Active.acq_metal
		T.True(State ~= nil, "the notice started acq_metal")
		T.Eq(State.Stage, 1, "acq_metal at stage 1 (travel)")
		T.Eq(State.Progress and State.Progress.foundry, 0, "the travel objective is still open in Lindenmoor")
	end)
end

-- (Foundry Yard plan Task 9, Ruling 38) the behavioural negative: a player who already has a path reads the notice
-- and gets no acq_metal (its Requires is NoAffinity)
function Suite.BrannocNoticeLeavesAPathAlone(T)
	local Investigation = require(SSS.InvestigationService)
	AtTheNotice(T, "Flame", function(Data, B)
		T.True(Investigation.Inspect(Player, NOTICE, B), "the notice was inspected (its text is read)")
		T.Eq(Data.Quests.Active.acq_metal, nil, "a Flame student gets no acq_metal from the notice")
		T.Eq(Data.Quests.Completed.acq_metal, nil, "nor a completed one")
	end)
end

-- ===== enemies =====
-- (Task 8: the check's body is SmokeKit's; Ye passes no Opts)
function Suite.EnemiesStandInTheWorld(T)
	SmokeKit.EnemiesStandInTheWorld(T)
end

return Suite

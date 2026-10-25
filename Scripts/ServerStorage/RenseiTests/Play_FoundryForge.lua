-- Play_FoundryForge (Foundry data plan Task 7, 2026-10-25): the Silent Forge, the Forge Floor's trial and Brannoc in
-- Foundry, built by Art/Studio/Regions/Foundry/forge/build_forge.lua (Map.Foundry.ForgeRooms, and Brannoc in
-- World.NPCs["Alchemy Trainers"]). Run inside the game VM (LMRunSuite) with the Play client connected, inside the
-- snapshot / restore runner. Foundry only (its map, its compass: -Z north, +X east).
--   InspectPointsAttach      each of the 4 metal_* inspect parts has its InspectPrompt; metal_bench has its
--                            MechanismPrompt (PuzzleService).
--   TheForgeIsAnArea         WorldService.AreaAt names "Silent Forge" over the SilentForgeFloor, "The Foundry" in the
--                            hall's front (the GreatHall_great_hall pivot at y 8, 40 studs toward +Z) and "Practice
--                            Court" over the TrainerSpot marker.
--   TheForgeIsNorthEast      from the TrainerSpot marker, the hall's pivot and the Ward spawn bear north-east on
--                            Foundry's compass (Regions.Bearing in (0, 90), live positions only); the control: the
--                            same offsets read on Ye's "+Z" compass are not in (0, 90).
--   BrannocTalks             DialogueId trainer_metal, a TalkPrompt on his root, within 6 studs of the TrainerSpot;
--                            (Task 9, Ruling 35) his look was applied: LookGender set, and the Gender attribute
--                            DialogueService gives a dressed NPC equals it; DialogueService.Open with the player beside
--                            him opens; Close.
--   WardSpawnsInTheForge     the WardAlchemist spawn is in ForgeRooms.SilentForge and inside the room's interior; a
--                            live WardAlchemist whose Home is that spawn (within 30 s), standing inside the interior.
--   TrialFitsTheRoom         acq_metal on its trial stage and no path: TrialService.Begin from 3 studs off the marker;
--                            the foe stands inside the Forge Floor's interior; the player pivoted out to (325, 8, -300)
--                            (outside Radius x 1.35) ends the run within OUTSIDE_GRACE + 2 = 8 s. (Task 9, Ruling 35:
--                            the run is still on just before the pivot, and it ends lost, "You left the arena.")
--   ArenaIsOpen              (Task 9, Ruling 35) no colliding part but the floor and the marker stands at body height
--                            (the floor's top + 0.5 .. + 6) within the trial's FoeDistance of the marker: the fight's
--                            middle is open. Measured 2026-10-25: the shell's ForgeFloorAnvil stood 4.0 studs from the
--                            marker (hidden by Art/Studio/Regions/Foundry/forge/hide_anvil.lua); the hearth (19.3) and
--                            the side walls (20.2) are outside FoeDistance 14.
--   TrialIsLockedOtherwise   with no acq_metal, CanStart refuses with the trial's Locked line (not "isn't ready").
-- Quests and Identity are copied and put back in place; the character's pivot and anchoring are put back.
local SSS = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local Rensei = game.ReplicatedStorage.Modules.Data.Rensei
local TestKit = require(script.Parent.TestKit)

-- the rooms' interiors (the great hall's shells, measured 2026-10-24: the inside faces of the side, back and front walls)
local SF = {X0 = 353.6, X1 = 392.4, Z0 = -389.4, Z1 = -339.6} -- the Silent Forge
local FF = {X0 = 305.6, X1 = 344.4, Z0 = -389.4, Z1 = -339.6} -- the Forge Floor
local INSPECTS = {"metal_note", "metal_gear", "metal_samples", "metal_shaft"}
local TRIAL = "metal_experiment"
local WARD_WAIT = 30 -- s
local OUT_WAIT = 8 -- s: TrialService's OUTSIDE_GRACE (6) + 2
local OUT_AT = Vector3.new(325, 8, -300) -- 64.5 studs from the marker: outside Radius 24 x 1.35 = 32.4

local SmokeKit = require(script.Parent.SmokeKit) -- (Task 9, Ruling 37: Copy and PutBack are the shared helpers)
local Copy, PutBack = SmokeKit.Copy, SmokeKit.PutBack
local function Inside(Box, P) return P.X > Box.X0 and P.X < Box.X1 and P.Z > Box.Z0 and P.Z < Box.Z1 end
local function f1(V) return ("(%.1f, %.1f, %.1f)"):format(V.X, V.Y, V.Z) end

-- tagged parts in workspace whose Attr equals Value (any new code reading a tag ignores instances outside workspace)
local function Tagged(Tag, Attr, Value)
	local Out = {}
	for _, I in ipairs(CollectionService:GetTagged(Tag)) do
		if I:IsDescendantOf(workspace) and I:GetAttribute(Attr) == Value then table.insert(Out, I) end
	end
	return Out
end
local function One(T, Tag, Attr, Value)
	local L = Tagged(Tag, Attr, Value)
	T.Eq(#L, 1, ("%s parts with %s = %s in workspace"):format(Tag, Attr, tostring(Value)))
	return L[1]
end
local function ForgeRooms()
	local FD = workspace.World.Map:FindFirstChild("Foundry")
	return FD and FD:FindFirstChild("ForgeRooms")
end
local function TrainerSpot(T)
	local L = {}
	for _, P in ipairs(CollectionService:GetTagged("RenseiMarker")) do
		if P:IsDescendantOf(workspace) and P:GetAttribute("Piece") == "TrainerSpot" and P:GetAttribute("Element") == "Metal" then
			table.insert(L, P)
		end
	end
	T.Eq(#L, 1, "Metal TrainerSpot markers")
	return L[1]
end
local function HallPivot(T)
	local GH = workspace.World.Map.Foundry.Landmarks:FindFirstChild("GreatHall_great_hall")
	T.True(GH ~= nil, "Map.Foundry.Landmarks.GreatHall_great_hall")
	return GH:GetPivot().Position
end
local function GreatHallPart(T, Name)
	local P = workspace.World.Map.Foundry.Landmarks.GreatHall_great_hall:FindFirstChild(Name)
	T.True(P ~= nil and P:IsA("BasePart"), "GreatHall_great_hall." .. Name)
	return P
end
local function Brannoc()
	for _, D in ipairs(workspace:GetDescendants()) do
		if D:IsA("Model") and D:GetAttribute("DialogueId") == "trainer_metal" then return D end
	end
end
local function WardSpawn(T) return One(T, "RenseiEnemySpawn", "EnemyType", "WardAlchemist") end

local Suite = {}

function Suite.InspectPointsAttach(T)
	local Rooms = ForgeRooms()
	T.True(Rooms ~= nil, "Map.Foundry.ForgeRooms")
	for _, Id in ipairs(INSPECTS) do
		local P = One(T, "RenseiInspect", "InspectId", Id)
		T.True(P:IsDescendantOf(Rooms), Id .. " is in ForgeRooms")
		T.True(P:FindFirstChild("InspectPrompt") ~= nil, Id .. " has its InspectPrompt")
	end
	local Bench = One(T, "RenseiMechanism", "MechanismId", "metal_bench")
	T.True(Bench:IsDescendantOf(Rooms), "metal_bench is in ForgeRooms")
	T.True(Bench:FindFirstChild("MechanismPrompt") ~= nil, "metal_bench has its MechanismPrompt")
end

function Suite.TheForgeIsAnArea(T)
	local WorldService = require(SSS.WorldService)
	local function Name(P)
		local A = WorldService.AreaAt(P)
		return A and A:GetAttribute("AreaName")
	end
	local Floor = GreatHallPart(T, "SilentForgeFloor")
	T.Eq(Name(Floor.Position + Vector3.new(0, 3, 0)), "Silent Forge", "the area over the SilentForgeFloor")
	local Hall = HallPivot(T)
	T.Eq(Name(Vector3.new(Hall.X, 8, Hall.Z + 40)), "The Foundry", "the area in the hall's front, outside the forge rooms")
	local Spot = TrainerSpot(T)
	T.Eq(Name(Spot.Position + Vector3.new(0, 3, 0)), "Practice Court", "the area over the TrainerSpot")
end

function Suite.TheForgeIsNorthEast(T)
	local Regions = require(Rensei.Regions)
	T.Eq(Regions.NorthOf(), "-Z", "Foundry's north")
	local From = TrainerSpot(T).Position
	local Targets = {Hall = HallPivot(T), Ward = WardSpawn(T).Position}
	for What, To in pairs(Targets) do
		local DX, DZ = To.X - From.X, To.Z - From.Z
		local B = Regions.Bearing(DX, DZ, Regions.NorthOf())
		T.True(B > 0 and B < 90, ("the %s bears %.1f from the TrainerSpot (north-east is 0..90)"):format(What, B))
		local C = Regions.Bearing(DX, DZ, "+Z")
		T.True(not (C > 0 and C < 90), ("control: on a +Z compass the %s would bear %.1f, not north-east"):format(What, C))
	end
end

function Suite.BrannocTalks(T)
	local DialogueService = require(SSS.DialogueService)
	local Player = game.Players:GetPlayers()[1]
	T.True(Player ~= nil and Player.Character ~= nil, "a player with a character")
	local Model = Brannoc()
	T.True(Model ~= nil, "a model with DialogueId trainer_metal in workspace")
	T.Eq(Model:GetAttribute("DialogueId"), "trainer_metal", "Brannoc's DialogueId")
	local Root = Model:FindFirstChild("HumanoidRootPart")
	T.True(Root ~= nil, "Brannoc has a root")
	T.True(Root:FindFirstChild("TalkPrompt") ~= nil, "Brannoc's root has the TalkPrompt")
	local Off = (Root.Position - TrainerSpot(T).Position).Magnitude
	T.True(Off <= 6, ("Brannoc stands %.1f studs from the TrainerSpot (at most 6)"):format(Off))
	-- (Task 9, Ruling 35) his look: DialogueService dresses a model with LookNation and records the Gender it chose
	local Want = Model:GetAttribute("LookGender")
	T.True(Want == "Male" or Want == "Female", "Brannoc has a LookGender (" .. tostring(Want) .. ")")
	T.Eq(Model:GetAttribute("Gender"), Want, "Brannoc was dressed in his look (the Gender attribute)")
	local Opened, Open
	local Ok, Err = pcall(function()
		TestKit.Beside(Player, Model, function()
			Opened = DialogueService.Open(Player, Model)
			Open = DialogueService.IsOpen(Player)
			DialogueService.Close(Player)
		end)
	end)
	pcall(DialogueService.Close, Player)
	if not Ok then error(Err, 0) end
	T.Eq(Opened, true, "DialogueService.Open with the player beside him")
	T.Eq(Open, true, "the conversation is open")
	T.Eq(DialogueService.IsOpen(Player), false, "closed again")
end

function Suite.WardSpawnsInTheForge(T)
	local ES = require(SSS.EnemyService)
	local Rooms = ForgeRooms()
	T.True(Rooms ~= nil and Rooms:FindFirstChild("SilentForge") ~= nil, "Map.Foundry.ForgeRooms.SilentForge")
	local Spawn = WardSpawn(T)
	T.True(Spawn:IsDescendantOf(Rooms.SilentForge), "the WardAlchemist spawn is in ForgeRooms.SilentForge")
	T.True(Inside(SF, Spawn.Position), "the spawn " .. f1(Spawn.Position) .. " is inside the Silent Forge interior")
	local Rig
	local T0 = os.clock()
	repeat
		for R, E in pairs(ES.Active) do
			local H = R:FindFirstChildOfClass("Humanoid")
			if E.Type == "WardAlchemist" and E.Home == Spawn and H and H.Health > 0 then Rig = R end
		end
		if not Rig then task.wait(0.5) end
	until Rig or os.clock() - T0 > WARD_WAIT
	T.True(Rig ~= nil, "a live WardAlchemist whose Home is the spawn, within " .. WARD_WAIT .. " s")
	local Root = Rig:FindFirstChild("HumanoidRootPart")
	T.True(Root ~= nil, "the Ward Alchemist has a root")
	T.True(Inside(SF, Root.Position), "the Ward Alchemist stands at " .. f1(Root.Position) .. ", inside the Silent Forge interior")
end

-- acq_metal on Stage (nil: no acq_metal), no path; Fn(Data, Character, Root); everything put back after
local function WithQuest(T, Stage, Fn)
	local PS = require(SSS.ProgressionService)
	local Quests = require(Rensei.Quests)
	local Player = game.Players:GetPlayers()[1]
	local Data = Player and PS.GetData(Player)
	local C = Player and Player.Character
	local Root = C and C:FindFirstChild("HumanoidRootPart")
	T.True(Data ~= nil and Root ~= nil, "a player with a save and a character")
	local OldQuests, OldIdentity = Copy(Data.Quests), Copy(Data.Identity or {})
	local Pivot, Anchored = C:GetPivot(), Root.Anchored
	local Ok, Err = pcall(function()
		Data.Identity = Data.Identity or {}
		Data.Identity.Affinity = ""
		Data.Quests.Completed.acq_metal = nil
		Data.Quests.Active.acq_metal = Stage and {Stage = Stage, Progress = {}, Started = os.time(), Revision = Quests.acq_metal.Revision} or nil
		Fn(Player, Data, C, Root)
	end)
	pcall(function()
		local TS = require(SSS.TrialService)
		for _, R in pairs(TS.Runs) do if R.Player == Player then R:End(false, "Test over.") end end
	end)
	pcall(function()
		PutBack(Data.Quests, OldQuests)
		if Data.Identity then PutBack(Data.Identity, OldIdentity) end
		PS.Sync(Player)
	end)
	pcall(function()
		C:PivotTo(Pivot)
		Root.AssemblyLinearVelocity = Vector3.zero
		Root.Anchored = Anchored
	end)
	if not Ok then error(Err, 0) end
end
-- the player held still 3 studs in front (+Z) of the marker, over the floor
local function AtMarker(C, Root, Marker)
	Root.Anchored = true
	C:PivotTo(CFrame.lookAt(Marker.Position + Vector3.new(0, 3, 3), Marker.Position + Vector3.new(0, 3, 0)))
	Root.AssemblyLinearVelocity = Vector3.zero
	task.wait(0.1)
end

function Suite.TrialFitsTheRoom(T)
	local TS = require(SSS.TrialService)
	local StoryLogic = require(Rensei.StoryLogic)
	local Quests = require(Rensei.Quests)
	local Stage = StoryLogic.StageIndex(Quests.acq_metal, "trial")
	T.Eq(Stage, 5, "acq_metal's trial stage")
	local Marker = One(T, "RenseiTrial", "TrialId", TRIAL)
	WithQuest(T, Stage, function(Player, Data, C, Root)
		AtMarker(C, Root, Marker)
		local Ok, Why = TS.Begin(Player, TRIAL)
		T.Eq(Ok, true, "TrialService.Begin (" .. tostring(Why) .. ")")
		local Run
		for _, R in pairs(TS.Runs) do if R.Player == Player then Run = R end end
		local FoeRoot = Run and Run.Foe and Run.Foe:FindFirstChild("HumanoidRootPart")
		T.True(FoeRoot ~= nil, "the trial's foe has a root")
		T.True(Inside(FF, FoeRoot.Position), "the foe stands at " .. f1(FoeRoot.Position) .. ", inside the Forge Floor interior")
		-- (Task 9, Ruling 35) the end's reason is captured: the run's own End, wrapped on this run only
		local Ended
		local RealEnd = Run.End
		Run.End = function(Self, Won, Why)
			Ended = Ended or {Won = Won, Why = Why}
			return RealEnd(Self, Won, Why)
		end
		T.Eq(TS.InRun(Player), true, "the run is still on just before the player leaves")
		C:PivotTo(CFrame.new(OUT_AT))
		Root.AssemblyLinearVelocity = Vector3.zero
		local T0 = os.clock()
		while TS.InRun(Player) and os.clock() - T0 < OUT_WAIT do task.wait(0.25) end
		T.Eq(TS.InRun(Player), false, ("the run ended within %d s of the player leaving the arena"):format(OUT_WAIT))
		T.True(Ended ~= nil, "the run's End was called")
		T.Eq(Ended.Won, false, "the run ended lost")
		T.Eq(Ended.Why, "You left the arena.", "the run ended because the player left the arena")
	end)
end

function Suite.ArenaIsOpen(T)
	local Trials = require(Rensei.Trials)
	local Marker = One(T, "RenseiTrial", "TrialId", TRIAL)
	local Floor = GreatHallPart(T, "ForgeFloorFloor")
	local Top = Floor.Position.Y + Floor.Size.Y / 2
	local R = Trials[TRIAL].FoeDistance
	local Op = OverlapParams.new()
	Op.FilterType = Enum.RaycastFilterType.Exclude
	local Skip = {Marker}
	for _, P in ipairs(game.Players:GetPlayers()) do if P.Character then table.insert(Skip, P.Character) end end
	local Live = workspace.World:FindFirstChild("Live")
	if Live then table.insert(Skip, Live) end -- (rigs: a trial foe of an earlier run, townsfolk)
	Op.FilterDescendantsInstances = Skip
	Op.RespectCanCollide = true
	local Lo, Hi = Top + 0.5, Top + 6
	local In = {}
	for _, P in ipairs(workspace:GetPartBoundsInBox(CFrame.new(Marker.Position.X, (Lo + Hi) / 2, Marker.Position.Z),
		Vector3.new(2 * R, Hi - Lo, 2 * R), Op)) do
		-- (the box's corners reach past R: only what comes within R of the marker, flat, counts)
		local Q = P.CFrame:PointToObjectSpace(Marker.Position)
		local H = P.Size / 2
		local Near = Vector3.new(math.clamp(Q.X, -H.X, H.X), 0, math.clamp(Q.Z, -H.Z, H.Z))
		local W = P.CFrame:PointToWorldSpace(Vector3.new(Near.X, Q.Y, Near.Z))
		local D = Vector3.new(W.X - Marker.Position.X, 0, W.Z - Marker.Position.Z).Magnitude
		if D <= R and P ~= Floor then table.insert(In, ("%s (%.1f)"):format(P:GetFullName(), D)) end
	end
	T.Eq(#In, 0, ("colliding parts at body height within FoeDistance %d of the marker: %s"):format(R, table.concat(In, ", ")))
end

function Suite.TrialIsLockedOtherwise(T)
	local TS = require(SSS.TrialService)
	local Trials = require(Rensei.Trials)
	local Marker = One(T, "RenseiTrial", "TrialId", TRIAL)
	WithQuest(T, nil, function(Player, Data, C, Root)
		AtMarker(C, Root, Marker)
		local Ok, Why = TS.CanStart(Player, TRIAL)
		T.Eq(Ok, false, "CanStart with no acq_metal")
		T.Eq(Why, Trials[TRIAL].Locked, "refused with the trial's Locked line")
	end)
end

return Suite

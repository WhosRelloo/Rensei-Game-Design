-- Hostages Task 1 (plan Documents/plans/2026-10-27-hostages.md): the read-only survey.
-- Run in Edit, in each place (Ye 106992859583940, Foundry 109591196441030):
--   python -I Art/Tools/rbxc.py luau "placeId: <id>" Edit @Art/Studio/Hostage/survey_hostage.lua
-- It never writes: no instance is created, moved, parented or edited, and no attribute is set. It refuses while Play
-- runs. It requires only modules that hold data or plain functions (Rensei.Stats, Rensei.Dialogues, PartyService,
-- UIService, Fill, ResourceManager); none of them runs code at require time beyond building its tables (sources read
-- 2026-10-27; UIService waits on Remotes.UIRemote, so it and PartyService are required only when that remote exists).
-- It returns one JSON string (the caller writes survey_ye.json / survey_foundry.json from it):
--   Place            game.PlaceId and ServerStorage's PlayLock / TestNoSave
--   Scripts          each label hostages Task 1 pairs: does the Studio path exist, and its class
--   StudioOnly       PartyService, UIService, UI.Fill, Rensei.Stats and Managers.ResourceManager: exists, class,
--                    normalised hash (the sync tool's NormHash, to compare the places), the module's function names;
--                    Stats.Order; PartyService has Get / SameParty
--   Names            the four hostage slot names (absent, or where they are: a present one blocks Task 3), and the
--                    stand-ins Carrying, Gripping, Takedown_ChokeVictim (full name and AnimationId)
--   Requests         ServerHandler.Requests.Hostage (expected absent)
--   StarterCharacter exists, Humanoid, HumanoidRootPart, Archivable, RigType, and the scripts inside it
--   Stations         every RenseiTicketClerk / RenseiStationGate (part or model) and RenseiPlatformTrain: full name,
--                    Route, position and bounding box; for each clerk / gate, its train (the gate's Route, else the
--                    nearest train) and the distance to that train's far corner; the largest such distance
--   Desks            every model in workspace with a DialogueId whose Rensei.Dialogues tree has a choice with
--                    Action.Kind == "PayFine": full name, DialogueId, Jurisdiction, position; and whether the station
--                    safe zone (R6) would reach it: its distance to the nearest clerk / gate, and whether it lies in a
--                    platform train's box grown by 4 studs (TrainMargin, PROPOSAL)
--   HUD              StarterGui.Uis.HUD.BossHealth (Head, Text, HP, Bar) and StarterGui.Uis.Templates.NpcTemplate
--   SafeTag          the number of instances tagged RenseiSafeZone (expected 0)

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

if RunService:IsRunning() then return "REFUSED: Play is running (the survey runs in Edit)" end

local TRAIN_MARGIN = 4 -- PROPOSAL (plan decision 4): a platform train's box grown by this many studs is safe

local SCRIPTS = { -- label -> Studio path (sync_manifest.json, hostages Task 1)
	{"Managers.MovementState", "ReplicatedStorage/Modules/Managers/MovementState"},
	{"Rensei.Emotes", "ReplicatedStorage/Modules/Data/Rensei/Emotes"},
	{"UI.EmoteWheelUI", "ReplicatedStorage/Modules/UI/EmoteWheelUI"},
	{"Skills.Heavy", "ReplicatedStorage/Modules/Skills/Combat/Heavy"},
	{"Skills.Block", "ReplicatedStorage/Modules/Skills/Combat/Block"},
	{"Skills.FistSwing", "ReplicatedStorage/Modules/Skills/Combat/Fist/FistSwing"},
	{"RenseiServer.StyleService", "ServerStorage/RenseiServer/StyleService"},
	{"RenseiServer.AlchemyService", "ServerStorage/RenseiServer/AlchemyService"},
	{"RenseiServer.CombatDirector", "ServerStorage/RenseiServer/CombatDirector"},
	{"RenseiServer.HeatService", "ServerStorage/RenseiServer/HeatService"},
	{"RenseiServer.DialogueService", "ServerStorage/RenseiServer/DialogueService"},
	{"Requests.ClassSkill", "ServerStorage/RenseiServer/ServerHandler/Requests/ClassSkill"},
	{"ClientHandler.Run", "StarterPlayer/StarterPlayerScripts/ClientHandler/Run"},
	-- already pairs (the brief: nothing to add); listed so the survey shows them
	{"RenseiTests.Play_Road", "ServerStorage/RenseiTests/Play_Road"},
	{"RenseiTests.Play_Station", "ServerStorage/RenseiTests/Play_Station"},
	{"RenseiTests.Play_Gate", "ServerStorage/RenseiTests/Play_Gate"},
}
local STUDIO_ONLY = {
	{"PartyService", "ServerStorage/RenseiServer/PartyService"},
	{"UIService", "ServerStorage/RenseiServer/UIService"},
	{"Fill", "ReplicatedStorage/Modules/UI/Fill"},
	{"Stats", "ReplicatedStorage/Modules/Data/Rensei/Stats"},
	{"ResourceManager", "ReplicatedStorage/Modules/Managers/ResourceManager"},
}
local SLOTS = {"Hostage_Bind", "Hostage_Hold", "Hostage_Held", "Hostage_Struggle"} -- must be absent (Task 3)
local STAND_INS = {"Carrying", "Gripping", "Takedown_ChokeVictim"}

local function R(X, P) P = P or 0.01 return math.floor(X / P + 0.5) * P end
local function V3(V, P) return {R(V.X, P), R(V.Y, P), R(V.Z, P)} end

local function NormHash(S) -- the sync tool's NormHash (sync.py NORMHASH_LUA)
	S = S:gsub("\r\n", "\n")
	local H1, H2 = 0, 0
	for I = 1, #S do
		local B = string.byte(S, I)
		H1 = (H1 * 31 + B) % 1000000007
		H2 = (H2 * 131 + B) % 998244353
	end
	return #S .. ":" .. H1 .. ":" .. H2
end

local function At(Path) -- "Service/A/B" -> the one instance, or nil, why
	local Bits = string.split(Path, "/")
	local Node = game:GetService(Bits[1])
	for I = 2, #Bits do
		local Kids = {}
		for _, C in Node:GetChildren() do
			if C.Name == Bits[I] then table.insert(Kids, C) end
		end
		if #Kids ~= 1 then return nil, #Kids .. " named " .. Bits[I] .. " under " .. Node:GetFullName() end
		Node = Kids[1]
	end
	return Node
end

local function Keys(T)
	local L = {}
	for K, V in T do table.insert(L, tostring(K) .. ":" .. type(V)) end
	table.sort(L)
	return L
end

local Out = {}
Out.Place = {PlaceId = game.PlaceId, PlayLock = tostring(SS:GetAttribute("PlayLock")),
	TestNoSave = tostring(SS:GetAttribute("TestNoSave"))}

-- ===== Scripts =====
Out.Scripts = {}
for _, P in SCRIPTS do
	local I, Why = At(P[2])
	Out.Scripts[P[1]] = I and {Path = P[2], Exists = true, Class = I.ClassName} or {Path = P[2], Exists = false, Why = Why}
end

-- ===== StudioOnly =====
Out.StudioOnly = {}
local Mods = {}
local UIRemote = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("UIRemote")
for _, P in STUDIO_ONLY do
	local I, Why = At(P[2])
	local E = {Path = P[2], Exists = I ~= nil}
	if I then
		E.Class = I.ClassName
		E.NormHash = NormHash(I.Source)
		if (P[1] == "PartyService" or P[1] == "UIService") and not UIRemote then
			E.Require = "skipped: no ReplicatedStorage.Remotes.UIRemote (it would wait forever)"
		else
			local Ok, M = pcall(require, I)
			if Ok and type(M) == "table" then
				Mods[P[1]] = M
				E.Api = Keys(M)
			else
				E.Require = "failed: " .. tostring(M)
			end
		end
	else
		E.Why = Why
	end
	Out.StudioOnly[P[1]] = E
end
if Mods.Stats then
	Out.StudioOnly.Stats.Order = Mods.Stats.Order
	Out.StudioOnly.Stats.HasBody = Mods.Stats.Info ~= nil and Mods.Stats.Info.Body ~= nil
end
if Mods.PartyService then
	Out.StudioOnly.PartyService.HasGet = type(Mods.PartyService.Get) == "function"
	Out.StudioOnly.PartyService.HasSameParty = type(Mods.PartyService.SameParty) == "function"
end
-- every "function <Module>.<Name>(...)" line of each source (PartyService requires ServerScriptService.UIService,
-- which exists only in a running game, so its require can fail in Edit; the source still names its API)
for _, P in STUDIO_ONLY do
	local I = At(P[2])
	if I then
		local L = {}
		for Name, Args in I.Source:gmatch("\nfunction " .. P[1] .. "%.([%w_]+)(%b())") do table.insert(L, Name .. Args) end
		Out.StudioOnly[P[1]].Functions = L
	end
end
if Mods.ResourceManager then
	Out.StudioOnly.ResourceManager.Rules = Keys(Mods.ResourceManager.Rules or {})
	local St = Mods.ResourceManager.Rules and Mods.ResourceManager.Rules.Stamina
	Out.StudioOnly.ResourceManager.StaminaMax = St and St.Max
end

-- ===== Names =====
local Assets = RS:FindFirstChild("Assets")
local Root = Assets and Assets:FindFirstChild("Animations")
local ByName = {}
if Root then
	for _, A in Root:GetDescendants() do
		if A:IsA("Animation") then
			ByName[A.Name] = ByName[A.Name] or {}
			table.insert(ByName[A.Name], {FullName = A:GetFullName(), AnimationId = A.AnimationId})
		end
	end
end
Out.Names = {Root = Root and Root:GetFullName() or "none", Slots = {}, StandIns = {}}
for _, N in SLOTS do
	if ByName[N] then
		local L = {}
		for _, E in ByName[N] do table.insert(L, E.FullName) end
		Out.Names.Slots[N] = L -- a blocker for Task 3
	else
		Out.Names.Slots[N] = "absent"
	end
end
for _, N in STAND_INS do Out.Names.StandIns[N] = ByName[N] or "absent" end
local Shared = Root and Root:FindFirstChild("Shared")
Out.Names.SharedHostage = Shared and Shared:FindFirstChild("Hostage") and Shared.Hostage:GetFullName() or "absent"

-- ===== Requests =====
local Req = At("ServerStorage/RenseiServer/ServerHandler/Requests")
Out.Requests = {Folder = Req and Req:GetFullName() or "missing",
	Hostage = Req and Req:FindFirstChild("Hostage") and Req.Hostage.ClassName or "absent"}

-- ===== StarterCharacter =====
local SC = game:GetService("StarterPlayer"):FindFirstChild("StarterCharacter")
if SC then
	local Hum = SC:FindFirstChildOfClass("Humanoid")
	local Scripts = {}
	for _, D in SC:GetDescendants() do
		if D:IsA("LuaSourceContainer") then
			table.insert(Scripts, D:GetFullName() .. " (" .. D.ClassName .. (D:IsA("BaseScript") and (D.Enabled and "" or ", disabled") or "") .. ")")
		end
	end
	table.sort(Scripts)
	Out.StarterCharacter = {Exists = true, Class = SC.ClassName, Archivable = SC.Archivable,
		Humanoid = Hum ~= nil, RigType = Hum and tostring(Hum.RigType.Name) or "none",
		HumanoidRootPart = SC:FindFirstChild("HumanoidRootPart") ~= nil,
		PrimaryPart = SC.PrimaryPart and SC.PrimaryPart.Name or "none", Scripts = Scripts}
else
	Out.StarterCharacter = {Exists = false}
end

-- ===== Stations =====
local function Box(I) -- CFrame, Size of a part or model
	if I:IsA("BasePart") then return I.CFrame, I.Size end
	if I:IsA("Model") then return I:GetBoundingBox() end
	return nil
end
local function Pos(I)
	if I:IsA("BasePart") then return I.Position end
	if I:IsA("Model") then return I:GetPivot().Position end
	return nil
end
local function Corners(CF, Size)
	local L = {}
	for _, X in {-1, 1} do
		for _, Y in {-1, 1} do
			for _, Z in {-1, 1} do
				table.insert(L, (CF * CFrame.new(X * Size.X / 2, Y * Size.Y / 2, Z * Size.Z / 2)).Position)
			end
		end
	end
	return L
end
local function Inside(P, CF, Size, Margin) -- P inside the box grown by Margin on every side
	local L = CF:PointToObjectSpace(P)
	return math.abs(L.X) <= Size.X / 2 + Margin and math.abs(L.Y) <= Size.Y / 2 + Margin
		and math.abs(L.Z) <= Size.Z / 2 + Margin
end
local function NearDist(P, CF, Size) -- distance from P to the box (0 inside)
	local L = CF:PointToObjectSpace(P)
	local D = Vector3.new(math.max(math.abs(L.X) - Size.X / 2, 0), math.max(math.abs(L.Y) - Size.Y / 2, 0),
		math.max(math.abs(L.Z) - Size.Z / 2, 0))
	return D.Magnitude
end

local Trains = {}
Out.Stations = {Clerks = {}, Gates = {}, Trains = {}}
for _, T in CollectionService:GetTagged("RenseiPlatformTrain") do
	if T:IsDescendantOf(workspace) then
		local CF, Size = Box(T)
		if CF then
			table.insert(Trains, {I = T, CF = CF, Size = Size})
			table.insert(Out.Stations.Trains, {FullName = T:GetFullName(), Class = T.ClassName,
				Route = tostring(T:GetAttribute("Route")), Centre = V3(CF.Position, 0.1), Size = V3(Size, 0.1)})
		end
	end
end
local Points = {} -- every clerk and gate position (Desks reads these)
local Largest = {Studs = 0}
for _, Kind in {{"RenseiTicketClerk", "Clerks"}, {"RenseiStationGate", "Gates"}} do
	for _, C in CollectionService:GetTagged(Kind[1]) do
		if C:IsDescendantOf(workspace) then
			local P = Pos(C)
			local CF, Size = Box(C)
			local E = {FullName = C:GetFullName(), Class = C.ClassName, Route = tostring(C:GetAttribute("Route")),
				Position = P and V3(P, 0.1), Size = Size and V3(Size, 0.1)}
			if P then
				table.insert(Points, {P = P, Name = C:GetFullName()})
				-- its train: the same Route when it has one, else the nearest platform train
				local Mine, Why
				local Route = C:GetAttribute("Route")
				if Route ~= nil then
					for _, T in Trains do
						if T.I:GetAttribute("Route") == Route then Mine, Why = T, "same Route" break end
					end
				end
				if not Mine then
					local Best = math.huge
					for _, T in Trains do
						local D = NearDist(P, T.CF, T.Size)
						if D < Best then Best, Mine, Why = D, T, "nearest" end
					end
				end
				if Mine then
					local Far, FarH = 0, 0
					for _, K in Corners(Mine.CF, Mine.Size) do
						Far = math.max(Far, (K - P).Magnitude)
						FarH = math.max(FarH, Vector3.new(K.X - P.X, 0, K.Z - P.Z).Magnitude)
					end
					E.Train = {FullName = Mine.I:GetFullName(), How = Why, NearStuds = R(NearDist(P, Mine.CF, Mine.Size), 0.1),
						FarCornerStuds = R(Far, 0.1), FarCornerLevelStuds = R(FarH, 0.1)}
					if Far > Largest.Studs then
						Largest = {Studs = R(Far, 0.1), LevelStuds = R(FarH, 0.1), From = C:GetFullName(), Train = Mine.I:GetFullName()}
					end
				else
					E.Train = "no platform train in this place"
				end
			end
			table.insert(Out.Stations[Kind[2]], E)
		end
	end
end
Out.Stations.LargestFarCorner = Largest
Out.Stations.RideTrains = #CollectionService:GetTagged("RenseiRideTrain")

-- ===== Desks =====
local Dialogues
do
	local DI = At("ReplicatedStorage/Modules/Data/Rensei/Dialogues")
	local Ok, M = pcall(require, DI)
	Dialogues = Ok and type(M) == "table" and M or nil
	if not Dialogues then Out.DialoguesError = tostring(M) end
end
local function PayFineOf(Def) -- the first PayFine choice's Jurisdiction, or nil
	if type(Def) ~= "table" or type(Def.Nodes) ~= "table" then return nil end
	for _, Node in Def.Nodes do
		for _, C in (type(Node) == "table" and type(Node.Choices) == "table" and Node.Choices or {}) do
			if type(C) == "table" and type(C.Action) == "table" and C.Action.Kind == "PayFine" then
				return tostring(C.Action.Jurisdiction)
			end
		end
	end
	return nil
end
Out.Desks = {List = {}, DialogueModels = 0, PayFineDialogues = {}}
if Dialogues then
	for Id, Def in Dialogues do
		local J = PayFineOf(Def)
		if J then table.insert(Out.Desks.PayFineDialogues, tostring(Id) .. " (" .. J .. ")") end
	end
	table.sort(Out.Desks.PayFineDialogues)
end
for _, M in workspace:GetDescendants() do
	if M:IsA("Model") and M:GetAttribute("DialogueId") ~= nil then
		Out.Desks.DialogueModels += 1
		local Id = M:GetAttribute("DialogueId")
		local J = Dialogues and PayFineOf(Dialogues[Id])
		if J then
			local P = M:GetPivot().Position
			local Near, NearName = math.huge, "none"
			for _, X in Points do
				local D = (X.P - P).Magnitude
				if D < Near then Near, NearName = D, X.Name end
			end
			local InTrain = {}
			for _, T in Trains do
				if Inside(P, T.CF, T.Size, TRAIN_MARGIN) then table.insert(InTrain, T.I:GetFullName()) end
			end
			table.insert(Out.Desks.List, {FullName = M:GetFullName(), DialogueId = tostring(Id), Jurisdiction = J,
				Position = V3(P, 0.1), NearestClerkOrGate = NearName, NearestStuds = Near < math.huge and R(Near, 0.1) or "none",
				InTrainBoxPlusMargin = InTrain})
		end
	end
end

-- ===== HUD =====
local SG = game:GetService("StarterGui")
local Uis = SG:FindFirstChild("Uis")
local HUD = Uis and Uis:FindFirstChild("HUD")
local Boss = HUD and HUD:FindFirstChild("BossHealth")
local Tpl = Uis and Uis:FindFirstChild("Templates")
Out.HUD = {Uis = Uis and Uis.ClassName or "absent", BossHealth = Boss and Boss.ClassName or "absent", BossParts = {},
	NpcTemplate = Tpl and Tpl:FindFirstChild("NpcTemplate") and Tpl.NpcTemplate.ClassName or "absent"}
for _, N in {"Head", "Text", "HP", "Bar"} do
	local C = Boss and Boss:FindFirstChild(N, true)
	Out.HUD.BossParts[N] = C and (C:GetFullName():sub(#Boss:GetFullName() + 2) .. " (" .. C.ClassName .. ")") or "absent"
end

-- ===== SafeTag =====
Out.SafeTag = #CollectionService:GetTagged("RenseiSafeZone")

return HttpService:JSONEncode(Out)

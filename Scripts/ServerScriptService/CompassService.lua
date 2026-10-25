-- CompassService (server, owner 2026-10-18): publishes the places the top-of-screen compass (CompassUI) can
-- point at, as a static list in ReplicatedStorage.CompassPoints. The place streams (StreamingEnabled), so a
-- client can't find far-off parts itself; ReplicatedStorage always replicates.
-- Each point is a Folder with attributes: Kind, Key, Label, Position (Vector3), and per kind:
--   Area      RenseiArea parts            Key = AreaName, Radius = half the region's smaller side
--   Talk      models with DialogueId      Key = DialogueId, Label = DisplayName
--   Inspect   RenseiInspect               Key = InspectId, Evidence = the evidence it gives (Investigation)
--   Mechanism RenseiMechanism             Key = MechanismId
--   Trial     RenseiTrial                 Key = TrialId
--   Minigame  anything with MinigameId    Key = MinigameId
--   Spawn     RenseiEnemySpawn            Key = EnemyType, Names = "|EnemyType|DisplayName|QuestTarget|"
-- Rebuilt every REFRESH seconds (NPCs that moved, enemy display names once their rigs exist). Which point
-- matters to which player (quest state, discovered areas) is decided on the client from the profile copy
-- it already has; nothing here is secret (every point is a visible place in the world).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Investigation = require(ReplicatedStorage.Modules.Data.Rensei.Investigation)

local REFRESH = 30

local CompassService = {}

local Folder
local Existing = {} -- [Id] = point Folder

local function Pos(I)
	if I:IsA("BasePart") then return I.Position end
	if I:IsA("Model") then
		local Ok, P = pcall(function() return I:GetPivot().Position end)
		return Ok and P or nil
	end
	local Part = I:FindFirstAncestorWhichIsA("BasePart") or I:FindFirstChildWhichIsA("BasePart", true)
	return Part and Part.Position or nil
end

local function Build()
	local Points = {} -- [Id] = attributes
	local Count = {}
	local function Add(Kind, Key, Label, I, Extra)
		-- only what is in the world (final review C1, 2026-10-24): RenseiBackups keep their tags (the retired old-hub
		-- GruntSpawns), and a point there is somewhere no player can go
		if not I:IsDescendantOf(workspace) then return end
		local P = Pos(I)
		if not P or Key == nil or Key == "" then return end
		local Base = Kind .. "_" .. tostring(Key)
		Count[Base] = (Count[Base] or 0) + 1
		local A = {Kind = Kind, Key = tostring(Key), Label = tostring(Label or Key), Position = P}
		for K, V in pairs(Extra or {}) do A[K] = V end
		Points[Base .. "_" .. Count[Base]] = A
	end

	for _, P in ipairs(CollectionService:GetTagged("RenseiArea")) do
		-- Radius: big regions count as near once you reach their edge, not their centre
		if P:IsA("BasePart") then Add("Area", P:GetAttribute("AreaName") or P.Name, nil, P, {Radius = math.min(P.Size.X, P.Size.Z) / 2}) end
	end
	for _, I in ipairs(CollectionService:GetTagged("RenseiInspect")) do
		local Id = I:GetAttribute("InspectId")
		local Def = Id and Investigation.Inspects[Id]
		Add("Inspect", Id, Def and Def.Title, I, {Evidence = Def and Def.Evidence or ""})
	end
	for _, I in ipairs(CollectionService:GetTagged("RenseiMechanism")) do Add("Mechanism", I:GetAttribute("MechanismId"), nil, I) end
	for _, I in ipairs(CollectionService:GetTagged("RenseiTrial")) do Add("Trial", I:GetAttribute("TrialId"), nil, I) end

	-- enemy display names, from rigs already spawned (EnemyService names them)
	local Display = {}
	local Live = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Live")
	if Live then
		for _, M in ipairs(Live:GetChildren()) do
			local T = M:GetAttribute("EnemyType")
			if T and not Display[T] then Display[T] = M:GetAttribute("QuestTarget") or M:GetAttribute("DisplayName") end
		end
	end
	for _, I in ipairs(CollectionService:GetTagged("RenseiEnemySpawn")) do
		local T = I:GetAttribute("EnemyType")
		if T then
			local Names = "|" .. T .. "|" .. (Display[T] or "") .. "|" .. (I:GetAttribute("QuestTarget") or I:GetAttribute("DisplayName") or "") .. "|"
			Add("Spawn", T, Display[T] or T, I, {Names = Names})
		end
	end

	-- dialogue NPCs and minigame stations: by attribute, anywhere in the world (not the live enemies)
	for _, D in ipairs(workspace:GetDescendants()) do
		if D:IsA("Model") and D:GetAttribute("DialogueId") and not (Live and D:IsDescendantOf(Live)) then
			Add("Talk", D:GetAttribute("DialogueId"), D:GetAttribute("DisplayName") or D.Name, D)
		elseif D:GetAttribute("MinigameId") and (D:IsA("BasePart") or D:IsA("Model")) then
			Add("Minigame", D:GetAttribute("MinigameId"), nil, D)
		end
	end

	-- update in place (clients keep their references; no churn every refresh)
	for Id, A in pairs(Points) do
		local F = Existing[Id]
		if not F then
			F = Instance.new("Folder")
			F.Name = Id
			Existing[Id] = F
		end
		for K, V in pairs(A) do
			if F:GetAttribute(K) ~= V then F:SetAttribute(K, V) end
		end
		F.Parent = Folder
	end
	for Id, F in pairs(Existing) do
		if not Points[Id] then F:Destroy() Existing[Id] = nil end
	end
	Folder:SetAttribute("Count", (function() local N = 0 for _ in pairs(Points) do N += 1 end return N end)())
end

function CompassService.Start()
	Folder = ReplicatedStorage:FindFirstChild("CompassPoints") or Instance.new("Folder")
	Folder.Name = "CompassPoints"
	Folder.Parent = ReplicatedStorage
	task.spawn(function()
		task.wait(3) -- let the map, NPCs and enemy spawns load
		while true do
			local Ok, Err = pcall(Build)
			if not Ok then warn("[CompassService] " .. tostring(Err)) end
			task.wait(REFRESH)
		end
	end)
end

return CompassService

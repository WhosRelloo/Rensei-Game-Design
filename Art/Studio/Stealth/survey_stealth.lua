-- Stealth Missions 1, Task 1 (plan "Stealth Missions 1: guards that think, and seeing what they see", 2026-10-29): the
-- read-only survey. Run in Edit, in each place (Ye 106992859583940, Foundry 109591196441030):
--   python -I Art/Tools/rbxc.py luau "placeId: <id>" Edit @Art/Studio/Stealth/survey_stealth.lua
-- It never writes: no instance is parented, moved or edited and no attribute is set. The one instance it makes,
-- Instance.new("UnreliableRemoteEvent"), is made and destroyed inside a pcall and never parented. It requires the Mover
-- module (the established Edit pattern: Test_MoverRepair, PathKit) only to read typeof(Mover.WalkTo). It refuses while
-- Play runs. It returns one JSON string (the caller writes survey_ye.json / survey_foundry.json from it):
--   Place      game.PlaceId and ServerStorage's PlayLock and TestNoSave
--   Remotes    Remotes.TownsfolkSay (exists, class), Remotes.GuardSight (must not exist), and whether
--              Instance.new("UnreliableRemoteEvent") succeeds
--   Tags       RenseiEnemySpawn parts in workspace by EnemyType; parts with a Net / Route / Lookout attribute (expect
--              none); RenseiPatrolRoute / RenseiBarracks tagged instances anywhere (expect none)
--   Mover      TownsfolkService.Mover's path and typeof(Mover.WalkTo) (also Stop, Place, PlanPath, Handle)
--   StealthUI  the Studio path of Modules.UI.StealthUI, its length and normalised hash (sync.py's NormHash, which the
--              caller compares with sync.norm_hash of the repo file) and whether the pair is in the manifest is for
--              the caller (it isn't today: Task 8 adds it)
--   Kit        TakedownKit.Spot()'s X/Z for this place, read from the SURVEY table in TakedownKit's Studio source, and
--              SPOT_Y
--   Speech     TownsfolkService.SayRadius, read from the module's source (a number literal; the module itself is not
--              required: it is a whole service)
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local SSS = game:GetService("ServerScriptService")

if RunService:IsRunning() then return "REFUSED: Play is running (the survey runs in Edit)" end

-- sync.py's NormHash, byte for byte
local function NormHash(S)
	S = S:gsub("\r\n", "\n")
	local H1, H2 = 0, 0
	for I = 1, #S do
		local B = string.byte(S, I)
		H1 = (H1 * 31 + B) % 1000000007
		H2 = (H2 * 131 + B) % 998244353
	end
	return #S .. ":" .. H1 .. ":" .. H2
end

local function Find(Root, Path)
	local Node = Root
	for _, Name in ipairs(string.split(Path, ".")) do
		Node = Node and Node:FindFirstChild(Name)
	end
	return Node
end

local Out = {}

Out.Place = {PlaceId = game.PlaceId, PlayLock = SS:GetAttribute("PlayLock"), TestNoSave = SS:GetAttribute("TestNoSave")}

-- ===== Remotes =====
do
	local Remotes = RS:FindFirstChild("Remotes")
	local Say = Remotes and Remotes:FindFirstChild("TownsfolkSay")
	local Sight = Remotes and Remotes:FindFirstChild("GuardSight")
	local Made, Why = pcall(function()
		local R = Instance.new("UnreliableRemoteEvent")
		local Class = R.ClassName
		R:Destroy()
		return Class
	end)
	Out.Remotes = {
		RemotesFolder = Remotes ~= nil,
		TownsfolkSay = Say ~= nil,
		TownsfolkSayClass = Say and Say.ClassName or nil,
		GuardSightExists = Sight ~= nil, -- must be false
		UnreliableRemoteEventMakes = Made,
		UnreliableRemoteEventResult = tostring(Why),
	}
end

-- ===== Tags =====
do
	local Spawns, Total = {}, 0
	for _, I in ipairs(CollectionService:GetTagged("RenseiEnemySpawn")) do
		if I:IsDescendantOf(workspace) then
			local T = tostring(I:GetAttribute("EnemyType"))
			Spawns[T] = (Spawns[T] or 0) + 1
			Total += 1
		end
	end
	local Attrs = {}
	for _, D in ipairs(workspace:GetDescendants()) do
		if D:GetAttribute("Net") ~= nil or D:GetAttribute("Route") ~= nil or D:GetAttribute("Lookout") ~= nil then
			table.insert(Attrs, {Path = D:GetFullName(), Class = D.ClassName, Net = D:GetAttribute("Net"),
				Route = D:GetAttribute("Route"), Lookout = D:GetAttribute("Lookout")})
		end
	end
	local function Tagged(Tag)
		local L = {}
		for _, I in ipairs(CollectionService:GetTagged(Tag)) do table.insert(L, I:GetFullName()) end
		return L
	end
	Out.Tags = {
		RenseiEnemySpawnTotal = Total,
		RenseiEnemySpawnByType = Spawns,
		NetRouteLookoutAttributes = Attrs, -- expect none
		RenseiPatrolRoute = Tagged("RenseiPatrolRoute"), -- expect none
		RenseiBarracks = Tagged("RenseiBarracks"), -- expect none
	}
end

-- ===== Mover and Speech =====
do
	-- in Edit the services sit in ServerStorage.RenseiServer (the package); RenseiBoot moves them to ServerScriptService in Play
	local RSrv = SS:FindFirstChild("RenseiServer")
	local TS = SSS:FindFirstChild("TownsfolkService") or (RSrv and RSrv:FindFirstChild("TownsfolkService"))
	local Mover = TS and TS:FindFirstChild("Mover")
	local M = {Path = Mover and Mover:GetFullName() or nil, Class = Mover and Mover.ClassName or nil}
	if Mover then
		local Ok, Mod = pcall(require, Mover)
		M.Required = Ok
		if Ok and type(Mod) == "table" then
			for _, K in ipairs({"WalkTo", "Stop", "Place", "Handle", "PlanPath"}) do M["typeof_" .. K] = typeof(Mod[K]) end
		else
			M.RequireError = tostring(Mod)
		end
	end
	Out.Mover = M
	local Say = {TownsfolkServicePath = TS and TS:GetFullName() or nil}
	if TS and TS:IsA("LuaSourceContainer") then
		local Lit = TS.Source:match("TownsfolkService%.SayRadius%s*=%s*([%d%.]+)")
		Say.SayRadiusFromSource = Lit and tonumber(Lit) or nil
	end
	Out.Speech = Say
end

-- ===== StealthUI =====
do
	local Mods = RS:FindFirstChild("Modules")
	local UI = Mods and Find(Mods, "UI.StealthUI")
	Out.StealthUI = {
		StudioPath = UI and UI:GetFullName() or nil,
		Class = UI and UI.ClassName or nil,
		Length = UI and #UI.Source or nil,
		NormHash = UI and NormHash(UI.Source) or nil, -- the caller compares sync.norm_hash(repo file)
	}
end

-- ===== Kit =====
do
	local Tests = SS:FindFirstChild("RenseiTests")
	local Kit = Tests and Tests:FindFirstChild("TakedownKit")
	local K = {Path = Kit and Kit:GetFullName() or nil}
	if Kit then
		local Src = Kit.Source
		local X, Z = Src:match("%[" .. game.PlaceId .. "%]%s*=%s*Vector3%.new%(%s*(%-?[%d%.]+)%s*,%s*0%s*,%s*(%-?[%d%.]+)%s*%)")
		K.SpotX = X and tonumber(X) or nil
		K.SpotZ = Z and tonumber(Z) or nil
		local Y = Src:match("local SPOT_Y = (%-?[%d%.]+)")
		K.SpotY = Y and tonumber(Y) or nil
	end
	Out.Kit = K
end

return HttpService:JSONEncode(Out)

--!nocheck
-- export_forge.lua: Foundry Yard game-data plan Task 7. Reads Ye's forge pieces, Brannoc and the Ward Alchemist's
-- spawn and writes them as JSON (the kit, Art/Studio/Regions/Foundry/forge/forge_kit.json) into the temporary
-- StringValue ServerStorage.FoundryForgeExport. Read it back in 25,000-character chunks, save it as forge_kit.json,
-- then delete the StringValue. That StringValue is the only thing this script changes: the place is otherwise
-- read-only to it.
-- Runs in Ye (placeId 106992859583940), Edit only:
--   python -I Art/Tools/rbxc.py luau "placeId: 106992859583940" Edit @Art/Studio/Regions/Foundry/forge/export_forge.lua
-- It returns "exported <n> chars: ..." or "export_forge REFUSED: <why>".
-- What it exports (the brief's list; anything else under SilentForge is the shell the great hall replaces):
--   * the 20 SilentForge pieces: Interactables and everything in it (WorkshopRecord and its Model's 3 MeshParts,
--     MaterialBench, RepairedGear, SampleRack, DriveShaft), Sample1..5, Iron Alchemy's 3 MeshParts, Machine, Desk,
--     Anvil and "Silent ForgeArea". Left out on purpose: WestA, WestB, EastA, SouthA, SouthB, North, Floor, Furnace
--     and FurnaceMouth;
--   * ForgeFloor.TrialMarker (Group "ForgeFloor");
--   * Brannoc (World.NPCs["Alchemy Trainers"]["Metal Alchemist"]): his attributes (without LindenmoorPrepFrom), his
--     root's CFrame, his Humanoid's display fields, and his props ScrollStand and the Metal Alchemy Model's Paper
--     (Group "Brannoc");
--   * the Ward Alchemist's spawn (Group "Ward"): Map.AlchemistSpawns.WardAlchemist_SilentForge.
-- Every non-part container on a piece's path is a "Models" entry with its Class (Folder or Model); any other
-- container class refuses and names it. Attributes: string, number and boolean only (any other type refuses and names
-- it); LindenmoorPrepFrom is dropped. A piece with a child that is neither a piece nor a container refuses (nothing
-- is dropped silently). Ye world CFrames throughout; build_forge.lua does the moving.
-- The JSON is written by this script's own encoder: keys in a fixed order, numbers as %.17g (exact round trip).
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local function refuse(Why) return "export_forge REFUSED: " .. Why end
if game.PlaceId ~= 106992859583940 then return refuse("this is not Ye") end
if RunService:IsRunning() then return refuse("Play is running; Edit only") end

local Map = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map")
local SF = Map and Map:FindFirstChild("SilentForge")
local FF = Map and Map:FindFirstChild("ForgeFloor")
local Spawns = Map and Map:FindFirstChild("AlchemistSpawns")
local Trainers = workspace.World:FindFirstChild("NPCs") and workspace.World.NPCs:FindFirstChild("Alchemy Trainers")
local Brannoc = Trainers and Trainers:FindFirstChild("Metal Alchemist")
if not SF then return refuse("no World.Map.SilentForge") end
if not FF then return refuse("no World.Map.ForgeFloor") end
if not (Spawns and Spawns:FindFirstChild("WardAlchemist_SilentForge")) then return refuse("no World.Map.AlchemistSpawns.WardAlchemist_SilentForge") end
if not Brannoc then return refuse("no World.NPCs[\"Alchemy Trainers\"][\"Metal Alchemist\"]") end

local SHELL = {WestA = true, WestB = true, EastA = true, SouthA = true, SouthB = true, North = true, Floor = true,
	Furnace = true, FurnaceMouth = true}
local SF_PIECES = 20
local DROP = {LindenmoorPrepFrom = true}

-- ------------------------------------------------------------------ a small JSON encoder (fixed key order)
local NULL = {}
local function enc(V, Order)
	local T = typeof(V)
	if V == NULL then return "null" end
	if T == "string" then
		return '"' .. V:gsub('[%c"\\]', function(C)
			local M = {['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t"}
			return M[C] or ("\\u%04x"):format(string.byte(C))
		end) .. '"'
	elseif T == "number" then
		if V ~= V or V == math.huge or V == -math.huge then error("not a finite number") end
		if V == math.floor(V) and math.abs(V) < 1e15 then return ("%d"):format(V) end
		return ("%.17g"):format(V)
	elseif T == "boolean" then return tostring(V)
	elseif T == "table" then
		local Meta = getmetatable(V)
		if next(V) == nil and Meta and Meta.__obj then return "{}" end
		if V[1] ~= nil or next(V) == nil then
			local Out = {}
			for _, X in ipairs(V) do table.insert(Out, enc(X)) end
			return "[" .. table.concat(Out, ", ") .. "]"
		end
		local Keys = {}
		if Order then
			for _, K in ipairs(Order) do if V[K] ~= nil then table.insert(Keys, K) end end
		else
			for K in pairs(V) do table.insert(Keys, K) end
			table.sort(Keys)
		end
		local Out = {}
		for _, K in ipairs(Keys) do table.insert(Out, enc(K) .. ": " .. enc(V[K])) end
		return "{" .. table.concat(Out, ", ") .. "}"
	end
	error("cannot encode a " .. T)
end
local function obj(T) return setmetatable(T, {__obj = true}) end

-- ------------------------------------------------------------------ readers
local Problems = {}
local function attrs(I)
	local A = {}
	for K, V in pairs(I:GetAttributes()) do
		if not DROP[K] then
			local T = typeof(V)
			if T == "string" or T == "number" or T == "boolean" then A[K] = V
			else table.insert(Problems, ("%s: attribute %s is a %s"):format(I:GetFullName(), K, T)) end
		end
	end
	return A
end
local function tags(I)
	local T = CS:GetTags(I)
	table.sort(T)
	return T
end
local function cf12(CF) return {CF:GetComponents()} end
local function v3(V) return {V.X, V.Y, V.Z} end
local function rel(I, Root)
	local Bits = {}
	local N = I
	while N and N ~= Root do table.insert(Bits, 1, N.Name) N = N.Parent end
	return table.concat(Bits, "/")
end
local PIECE_ORDER = {"Group", "Path", "Class", "CFrame", "Size", "Color", "Material", "MaterialVariant", "Transparency",
	"Reflectance", "CanCollide", "CanQuery", "CanTouch", "CastShadow", "Anchored", "Shape", "MeshId", "TextureID",
	"Attributes", "Tags"}
local function piece(Group, P, Root)
	if not (P.ClassName == "Part" or P.ClassName == "MeshPart") then
		table.insert(Problems, P:GetFullName() .. " is a " .. P.ClassName .. " (Part or MeshPart only)")
	end
	local A = attrs(P)
	return {Group = Group, Path = rel(P, Root), Class = P.ClassName, CFrame = cf12(P.CFrame), Size = v3(P.Size),
		Color = {P.Color.R, P.Color.G, P.Color.B}, Material = P.Material.Name, MaterialVariant = P.MaterialVariant,
		Transparency = P.Transparency, Reflectance = P.Reflectance, CanCollide = P.CanCollide, CanQuery = P.CanQuery,
		CanTouch = P.CanTouch, CastShadow = P.CastShadow, Anchored = P.Anchored,
		Shape = P:IsA("Part") and P.Shape.Name or NULL,
		MeshId = P:IsA("MeshPart") and P.MeshId or NULL, TextureID = P:IsA("MeshPart") and P.TextureID or NULL,
		Attributes = next(A) and A or obj({}), Tags = tags(P)}
end

local Pieces, Models, Seen = {}, {}, {}
-- the containers on I's path below Root, as Models entries (once each)
local function containers(Group, I, Root)
	local N = I.Parent
	local Chain = {}
	while N and N ~= Root do table.insert(Chain, 1, N) N = N.Parent end
	for _, C in ipairs(Chain) do
		if not C:IsA("BasePart") and not Seen[C] then
			Seen[C] = true
			if not (C.ClassName == "Folder" or C.ClassName == "Model") then
				table.insert(Problems, C:GetFullName() .. " is a " .. C.ClassName .. " container (Folder or Model only)")
			end
			local A = attrs(C)
			table.insert(Models, {Group = Group, Path = rel(C, Root), Class = C.ClassName, Attributes = next(A) and A or obj({})})
		end
	end
end
-- every descendant of Under is a piece (BasePart) or a container (Folder / Model); anything else refuses
local function walk(Group, Under, Root, Skip)
	for _, C in ipairs(Under:GetChildren()) do
		if not (Skip and Skip[C.Name] and Under == Root) then
			if C:IsA("BasePart") then
				containers(Group, C, Root)
				table.insert(Pieces, piece(Group, C, Root))
				walk(Group, C, Root)
			elseif C:IsA("Folder") or C:IsA("Model") then
				walk(Group, C, Root)
			else
				table.insert(Problems, C:GetFullName() .. " is a " .. C.ClassName .. " (neither a piece nor a container)")
			end
		end
	end
end

-- the Silent Forge (the shell left out)
for Name in pairs(SHELL) do
	if not SF:FindFirstChild(Name) then table.insert(Problems, "SilentForge." .. Name .. " (a shell part) is missing") end
end
walk("SilentForge", SF, SF, SHELL)
local NSF = #Pieces
if NSF ~= SF_PIECES then table.insert(Problems, ("%d SilentForge pieces, not %d"):format(NSF, SF_PIECES)) end
-- the Forge Floor's trial marker only
local TM = FF:FindFirstChild("TrialMarker")
if not (TM and TM:IsA("BasePart")) then table.insert(Problems, "ForgeFloor.TrialMarker is missing")
else
	if #TM:GetChildren() > 0 then table.insert(Problems, "ForgeFloor.TrialMarker has children") end
	table.insert(Pieces, piece("ForgeFloor", TM, FF))
end
-- Brannoc's props
for _, Name in ipairs({"ScrollStand", "Metal Alchemy"}) do
	local P = Brannoc:FindFirstChild(Name)
	if not P then table.insert(Problems, "Brannoc's " .. Name .. " is missing")
	elseif P:IsA("BasePart") then
		table.insert(Pieces, piece("Brannoc", P, Brannoc))
		walk("Brannoc", P, Brannoc)
	else
		walk("Brannoc", P, Brannoc)
	end
end
-- the Ward spawn
local Ward = Spawns.WardAlchemist_SilentForge
if #Ward:GetChildren() > 0 then table.insert(Problems, "the Ward spawn has children") end
local WardPiece = piece("Ward", Ward, Spawns)

local Root = Brannoc:FindFirstChild("HumanoidRootPart")
local Hum = Brannoc:FindFirstChildOfClass("Humanoid")
if not (Root and Hum) then table.insert(Problems, "Brannoc has no HumanoidRootPart or Humanoid") end
if #Problems > 0 then return refuse(table.concat(Problems, "; ")) end

local BA = attrs(Brannoc)
local Kit = {
	Source = "Ye 106992859583940, " .. os.date("!%Y-%m-%d"),
	Pieces = Pieces,
	Models = Models,
	Brannoc = {Attributes = BA, Root = cf12(Root.CFrame), FolderClass = Trainers.ClassName,
		Humanoid = {DisplayName = Hum.DisplayName, DisplayDistanceType = Hum.DisplayDistanceType.Name,
			NameDisplayDistance = Hum.NameDisplayDistance, HealthDisplayDistance = Hum.HealthDisplayDistance}},
	Ward = WardPiece,
}
-- encode with the fixed orders
local function encPiece(P) return enc(P, PIECE_ORDER) end
local Lines = {}
table.insert(Lines, '{"Source": ' .. enc(Kit.Source) .. ', "Pieces": [')
for I, P in ipairs(Pieces) do table.insert(Lines, "  " .. encPiece(P) .. (I < #Pieces and "," or "")) end
table.insert(Lines, '], "Models": [')
for I, M in ipairs(Models) do table.insert(Lines, "  " .. enc(M, {"Group", "Path", "Class", "Attributes"}) .. (I < #Models and "," or "")) end
table.insert(Lines, '], "Brannoc": ' .. enc(Kit.Brannoc, {"Attributes", "Root", "FolderClass", "Humanoid"}) .. ",")
table.insert(Lines, ' "Ward": ' .. encPiece(WardPiece) .. "}")
local Json = table.concat(Lines, "\n") .. "\n"

local Old = SS:FindFirstChild("FoundryForgeExport")
if Old then Old:Destroy() end
local V = Instance.new("StringValue")
V.Name = "FoundryForgeExport"
V.Value = Json
V.Parent = SS
local NA = 0
for _ in pairs(BA) do NA += 1 end
return ("exported %d chars into ServerStorage.FoundryForgeExport: %d SilentForge pieces, %d pieces in all, %d Models, Brannoc %d attributes, the Ward"):format(#Json, NSF, #Pieces, #Models, NA)

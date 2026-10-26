-- Swim revamp Task 1 (2026-10-26): a READ-ONLY survey of one place (Ye or Foundry Yard) for the swimming revamp.
-- Run in Edit (never in Play):
--   python -I Art/Tools/rbxc.py luau "placeId: <id>" Edit @Art/Studio/Swim/survey_swim.lua
-- It returns one JSON string. Over 25,000 characters it is parked in ServerStorage.SwimSurveyOut (a StringValue, the
-- only thing this script ever writes) and the return says so: read it back in 25,000-character chunks with
--   return game.ServerStorage.SwimSurveyOut.Value:sub(a, b)
-- and delete the StringValue after. The answers become Art/Studio/Swim/survey_ye.json / survey_foundry.json, the
-- measured facts every later task of the plan uses (Documents/plans/2026-10-25-swimming-revamp.md).
local MODE = "survey"

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local StarterGui = game:GetService("StarterGui")

if MODE ~= "survey" then return "REFUSED: MODE must be \"survey\"" end
if RunService:IsRunning() then return "REFUSED: Play is running (the survey reads Edit)" end

local YE, FOUNDRY = 106992859583940, 109591196441030
local Out = {PlaceId = game.PlaceId, Mode = MODE, Date = "2026-10-26"}

local function R(N, D) D = D or 2 local M = 10 ^ D return math.floor(N * M + 0.5) / M end
local function V3(V) return {R(V.X), R(V.Y), R(V.Z)} end
local function UD2(U) return {R(U.X.Scale, 4), U.X.Offset, R(U.Y.Scale, 4), U.Y.Offset} end

-- ===== places and safety =====
Out.PlayLock = ServerStorage:GetAttribute("PlayLock")
local Parts = 0
for _, D in workspace:GetDescendants() do if D:IsA("BasePart") then Parts += 1 end end
Out.WorkspaceParts = Parts

-- ===== scripts (the plan's pairs) =====
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
local function Resolve(Path)
	local Bits = string.split(Path, "/")
	local Ok, Node = pcall(function() return game:GetService(Bits[1]) end)
	if not Ok or not Node then return nil end
	for I = 2, #Bits do
		Node = Node:FindFirstChild(Bits[I])
		if not Node then return nil end
	end
	return Node
end
local Paths = {
	"ReplicatedStorage/Modules/Data/Rensei/TuningConfig", "ReplicatedStorage/Modules/Data/Rensei/Perception",
	"ReplicatedStorage/Modules/UI/MobileControls", "ReplicatedStorage/Modules/UI/SettingsUI",
	"ServerStorage/RenseiServer/SwimService", "ServerStorage/RenseiServer/PerceptionService",
	"ServerStorage/RenseiServer/NoiseService", "StarterPlayer/StarterPlayerScripts/SwimClient",
	"ReplicatedStorage/Modules/Data/Rensei/SwimLogic", "ReplicatedStorage/Modules/Managers/SwimController",
	"ServerStorage/RenseiTests/Test_SwimLogic", "ServerStorage/RenseiTests/SwimKit", "ServerStorage/RenseiTests/Play_Swim",
	"ServerStorage/RenseiTests/Test_Perception", "ServerStorage/RenseiTests/Test_Sound",
	"ServerStorage/RenseiTests/Play_Stealth", "ServerStorage/RenseiTests/Play_Perception",
	"ReplicatedStorage/Modules/UI/Fill", "ReplicatedStorage/Modules/Managers/AnimationManager",
}
Out.Scripts = {}
for _, P in Paths do
	local S = Resolve(P)
	Out.Scripts[P] = S and {Class = S.ClassName, Hash = S:IsA("LuaSourceContainer") and NormHash(S.Source) or nil} or false
end
do
	local Found = {}
	for _, Root in {ServerStorage, game:GetService("ServerScriptService")} do
		for _, D in Root:GetDescendants() do
			if D.Name == "Swim" and D:IsA("LuaSourceContainer") and D.Parent and D.Parent.Name == "Requests"
				and not D:FindFirstAncestor("RenseiBackups") then
				table.insert(Found, D:GetFullName())
			end
		end
	end
	Out.RequestsSwim = Found
end

-- ===== animations =====
local Anims = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Animations")
Out.Animations = {Root = Anims and Anims:GetFullName() or false}
if Anims then
	local SwimDir = Anims:FindFirstChild("Shared") and Anims.Shared:FindFirstChild("Movement")
		and Anims.Shared.Movement:FindFirstChild("Swim")
	Out.Animations.SwimFolder = SwimDir and SwimDir:GetFullName() or false
	Out.Animations.Swim = {}
	if SwimDir then
		for _, A in SwimDir:GetChildren() do
			table.insert(Out.Animations.Swim, {Name = A.Name, Class = A.ClassName,
				Id = A:IsA("Animation") and A.AnimationId or nil, Attributes = A:GetAttributes()})
		end
		table.sort(Out.Animations.Swim, function(a, b) return a.Name < b.Name end)
		Out.Animations.SwimFolderAttributes = SwimDir:GetAttributes()
	end
	local Want = {Swim_Dive = true, Swim_UnderIdle = true, Swim_Surface = true, Swim_ClimbOut = true}
	local Taken, Vault, LedgeLike, Count = {}, {}, {}, 0
	for _, D in Anims:GetDescendants() do
		if D:IsA("Animation") then Count += 1 end
		if Want[D.Name] then table.insert(Taken, D:GetFullName()) end
		if D.Name == "Vault1" or D.Name == "Vault2" then
			table.insert(Vault, {Path = D:GetFullName(), Id = D:IsA("Animation") and D.AnimationId or D.ClassName})
		end
		local L = D.Name:lower()
		if D:IsA("Animation") and (L:find("ledge") or L:find("mantle") or L:find("pullup") or L:find("climbup")
			or L:find("climbout") or L:find("vault")) then
			table.insert(LedgeLike, {Path = D:GetFullName(), Id = D.AnimationId})
		end
	end
	Out.Animations.NewNamesTaken = Taken -- must be empty: AnimationManager keys animations by name
	Out.Animations.Vault = Vault
	Out.Animations.LedgeLike = LedgeLike
	Out.Animations.Count = Count
	local Pkg = ReplicatedStorage.Assets:FindFirstChildOfClass("PackageLink")
	Out.Animations.AssetsPackage = Pkg and tostring(Pkg.PackageId) or false
end

-- ===== player scripts =====
local SPS = StarterPlayer:FindFirstChild("StarterPlayerScripts")
local PM = SPS and SPS:FindFirstChild("PlayerModule")
Out.PlayerModule = PM and {Class = PM.ClassName, Children = (function()
	local T = {}
	for _, C in PM:GetChildren() do table.insert(T, C.Name .. ":" .. C.ClassName) end
	table.sort(T)
	return T
end)(), ControlModule = PM:FindFirstChild("ControlModule") and PM.ControlModule.ClassName or false} or false
local SC = StarterPlayer:FindFirstChild("StarterCharacter")
Out.StarterWalkSpeed = SC and SC:FindFirstChildOfClass("Humanoid") and SC:FindFirstChildOfClass("Humanoid").WalkSpeed or false
Out.StarterCharacterHead = SC and SC:FindFirstChild("Head") and V3(SC.Head.Size) or false

-- ===== UI =====
local Uis = StarterGui:FindFirstChild("Uis")
local HUD = Uis and Uis:FindFirstChild("HUD")
local Stats = HUD and HUD:FindFirstChild("Stats")
Out.HUDStats = false
if Stats then
	local Kids = {}
	for _, C in Stats:GetChildren() do
		local E = {Name = C.Name, Class = C.ClassName}
		if C:IsA("GuiObject") then
			E.Position, E.Size, E.AnchorPoint, E.Visible, E.ZIndex = UD2(C.Position), UD2(C.Size), {C.AnchorPoint.X, C.AnchorPoint.Y}, C.Visible, C.ZIndex
		end
		if C:IsA("UIListLayout") or C:IsA("UIGridLayout") then
			E.FillDirection = tostring(C.FillDirection)
			E.SortOrder = tostring(C.SortOrder)
			E.Padding = C:IsA("UIListLayout") and {C.Padding.Scale, C.Padding.Offset} or nil
		end
		table.insert(Kids, E)
	end
	table.sort(Kids, function(a, b) return a.Name < b.Name end)
	Out.HUDStats = {Path = Stats:GetFullName(), Class = Stats.ClassName, Position = Stats:IsA("GuiObject") and UD2(Stats.Position) or nil,
		Size = Stats:IsA("GuiObject") and UD2(Stats.Size) or nil, Children = Kids}
	local Blue = Stats:FindFirstChild("BlueBar")
	if Blue then
		local Ds = {}
		local All = Blue:GetDescendants()
		table.insert(All, 1, Blue)
		for _, D in All do
			local E = {Path = D:GetFullName():sub(#Stats:GetFullName() + 2), Class = D.ClassName}
			if D:IsA("ImageLabel") or D:IsA("ImageButton") then E.Image = D.Image E.ImageColor3 = {R(D.ImageColor3.R, 3), R(D.ImageColor3.G, 3), R(D.ImageColor3.B, 3)} E.ScaleType = tostring(D.ScaleType) end
			if D:IsA("TextLabel") or D:IsA("TextButton") then E.Font = tostring(D.FontFace.Family) E.Text = D.Text end
			if D:IsA("GuiObject") then E.Position, E.Size, E.Visible = UD2(D.Position), UD2(D.Size), D.Visible end
			if D:IsA("UIGradient") then E.Offset = {D.Offset.X, D.Offset.Y} end
			table.insert(Ds, E)
		end
		Out.BlueBar = Ds
	end
end
local Fill = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("UI")
	and ReplicatedStorage.Modules.UI:FindFirstChild("Fill")
Out.Fill = Fill and table.concat({table.unpack(string.split(Fill.Source, "\n"), 1, 40)}, "\n") or false

-- ===== water =====
local Terrain = workspace.Terrain
local Map = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map")
local WaterRay = RaycastParams.new()
WaterRay.FilterType = Enum.RaycastFilterType.Include
WaterRay.FilterDescendantsInstances = {Terrain}
WaterRay.IgnoreWater = false
local BedRay = RaycastParams.new()
BedRay.FilterType = Enum.RaycastFilterType.Include
BedRay.FilterDescendantsInstances = {Map or workspace, Terrain}
BedRay.IgnoreWater = true

-- the water top (terrain water only) and the first non-water hit below, for one column
local PathIx, Paths2 = {}, {}
local function PIx(Inst)
	local P = Inst:GetFullName()
	if not PathIx[P] then table.insert(Paths2, P) PathIx[P] = #Paths2 end
	return PathIx[P]
end
local function Column(X, Z)
	local W = workspace:Raycast(Vector3.new(X, 30, Z), Vector3.new(0, -60, 0), WaterRay)
	local Top = (W and W.Material == Enum.Material.Water) and W.Position.Y or nil
	local B = workspace:Raycast(Vector3.new(X, 30, Z), Vector3.new(0, -60, 0), BedRay)
	return Top, B
end
local function Grid(X0, X1, Z0, Z1)
	local Cols, Tops, Beds = {}, {}, {}
	for X = X0, X1, 4 do
		for Z = Z0, Z1, 4 do
			local Top, B = Column(X, Z)
			local E = {X, Z, Top and R(Top) or false, B and R(B.Position.Y) or false, B and B.Material.Name or false, B and PIx(B.Instance) or false}
			table.insert(Cols, E)
			if Top then table.insert(Tops, Top) end
			if Top and B then table.insert(Beds, B.Position.Y) end
		end
	end
	local function Range(T) if #T == 0 then return false end table.sort(T) return {R(T[1]), R(T[#T])} end
	return {Box = {X0, X1, Z0, Z1}, Step = 4, Columns = Cols, Format = "x, z, waterTop, bedY, bedMaterial, bedPathIndex",
		TopRange = Range(Tops), WetBedRange = Range(Beds), WetColumns = #Tops}
end
-- voxel check of the liquid at one point (resolution 4)
local function Liquid(P)
	local Reg = Region3.new(P - Vector3.new(2, 2, 2), P + Vector3.new(2, 2, 2)):ExpandToGrid(4)
	local Ok, Ch = pcall(function() return Terrain:ReadVoxelChannels(Reg, 4, {"LiquidOccupancy"}) end)
	if not Ok then return "err " .. tostring(Ch) end
	return R(Ch.LiquidOccupancy[1][1][1], 3)
end

if game.PlaceId == YE then
	local BP = Map and Map:FindFirstChild("Baseplate")
	if BP then
		local CF = BP.CFrame
		local Kids = {}
		for _, C in BP:GetChildren() do
			local E = {Name = C.Name, Class = C.ClassName}
			if C:IsA("Texture") then
				E.Face, E.StudsPerTileU, E.StudsPerTileV, E.OffsetStudsU, E.OffsetStudsV, E.Texture =
					C.Face.Name, C.StudsPerTileU, C.StudsPerTileV, C.OffsetStudsU, C.OffsetStudsV, C.Texture
			elseif C:IsA("Decal") then
				E.Face, E.Texture = C.Face.Name, C.Texture
			end
			table.insert(Kids, E)
		end
		Out.Baseplate = {Path = BP:GetFullName(), CFrame = {CF:GetComponents()}, Size = V3(BP.Size), Material = BP.Material.Name,
			Color = {R(BP.Color.R, 4), R(BP.Color.G, 4), R(BP.Color.B, 4)}, MaterialVariant = BP.MaterialVariant,
			Anchored = BP.Anchored, CanCollide = BP.CanCollide, Transparency = BP.Transparency,
			Tags = CollectionService:GetTags(BP), Attributes = BP:GetAttributes(), Children = Kids}
	else
		Out.Baseplate = false
	end
	Out.GorgePool = Grid(192, 260, -572, -532)
	Out.MillPond = Grid(-136, -84, -580, -524)
	-- creek / gorge channel spots (the import's segment midpoints; 4.2 deep by design)
	Out.Channels = {}
	for _, S in {{"creek_west_water_0", -375, -527}, {"creek_west_water_2", -565, -534}, {"gorge_water_1", 470, -546}} do
		local Top, B = Column(S[2], S[3])
		table.insert(Out.Channels, {Id = S[1], X = S[2], Z = S[3], Top = Top and R(Top) or false,
			Bed = B and R(B.Position.Y) or false, BedPath = B and B.Instance:GetFullName() or false,
			LiquidAt3 = Liquid(Vector3.new(S[2], 3, S[3]))})
	end
	-- the Gorge Pool's largest 4-aligned rectangle whose every sample (centre and corners of each 4x4 cell) has its bed
	-- at y <= 0.05 and water to 5.2 (>= 5.1); capped at 24 (x) x 12 (z)
	local OK = {}
	local function CellOk(X, Z) -- cell [X, X+4] x [Z, Z+4]
		for _, P in {{X + 2, Z + 2}, {X + 0.25, Z + 0.25}, {X + 3.75, Z + 0.25}, {X + 0.25, Z + 3.75}, {X + 3.75, Z + 3.75}} do
			local Top, B = Column(P[1], P[2])
			if not Top or Top < 5.1 or not B or B.Position.Y > 0.05 then return false end
		end
		return true
	end
	local GX0, GX1, GZ0, GZ1 = 192, 260, -572, -532
	for X = GX0, GX1 - 4, 4 do
		OK[X] = {}
		for Z = GZ0, GZ1 - 4, 4 do OK[X][Z] = CellOk(X, Z) end
	end
	local Best = nil
	for X0 = GX0, GX1 - 4, 4 do
		for Z0 = GZ0, GZ1 - 4, 4 do
			for W = 4, 24, 4 do
				for D = 4, 12, 4 do
					if X0 + W <= GX1 and Z0 + D <= GZ1 then
						local All = true
						for X = X0, X0 + W - 4, 4 do
							for Z = Z0, Z0 + D - 4, 4 do
								if not OK[X][Z] then All = false break end
							end
							if not All then break end
						end
						if All then
							local Area = W * D
							local Cx, Cz = X0 + W / 2, Z0 + D / 2
							local Dist = (Cx - 226) ^ 2 + (Cz + 551.5) ^ 2
							if not Best or Area > Best.Area or (Area == Best.Area and Dist < Best.Dist) then
								Best = {X0 = X0, X1 = X0 + W, Z0 = Z0, Z1 = Z0 + D, Area = Area, Dist = R(Dist)}
							end
						end
					end
				end
			end
		end
	end
	local OkCells = 0
	for _, Row in OK do for _, V in Row do if V then OkCells += 1 end end end
	Out.GorgeRect = (Best and Best.X1 - Best.X0 >= 12 and Best.Z1 - Best.Z0 >= 8) and Best
		or (Best and {None = "none >= 12 x 8", Largest = Best} or {None = "none >= 12 x 8"})
	Out.GorgeOkCells = OkCells
	if Best then
		-- what else is in the hole's box from y -16 to 0, other than the Baseplate
		local Box = CFrame.new((Best.X0 + Best.X1) / 2, -8, (Best.Z0 + Best.Z1) / 2)
		local OP = OverlapParams.new()
		local Hits = {}
		for _, P in workspace:GetPartBoundsInBox(Box, Vector3.new(Best.X1 - Best.X0, 16, Best.Z1 - Best.Z0), OP) do
			if P ~= BP then table.insert(Hits, P:GetFullName()) end
		end
		Out.HoleBoxOthers = Hits
		Out.HoleCentreLiquid = {At3 = Liquid(Vector3.new((Best.X0 + Best.X1) / 2, 3, (Best.Z0 + Best.Z1) / 2)),
			AtMinus6 = Liquid(Vector3.new((Best.X0 + Best.X1) / 2, -6, (Best.Z0 + Best.Z1) / 2))}
	end
	-- the ledge-walk strips (RenseiLedge) near the Gorge Pool
	Out.Ledges = {}
	for _, P in CollectionService:GetTagged("RenseiLedge") do
		if P:IsA("BasePart") and math.abs(P.Position.X - 226) < 80 and math.abs(P.Position.Z + 551.5) < 60 then
			table.insert(Out.Ledges, {Path = P:GetFullName(), CFrame = {P.CFrame:GetComponents()}, Size = V3(P.Size)})
		end
	end
elseif game.PlaceId == FOUNDRY then
	Out.Pond = Grid(412, 568, -204, -92)
	-- the bed parts under the pond
	local Beds = {}
	local Seen = {}
	for _, C in Out.Pond.Columns do
		if C[3] and C[6] and not Seen[C[6]] then Seen[C[6]] = true table.insert(Beds, C[6]) end
	end
	Out.PondBedPaths = Beds
	-- lips: the ground top just outside each edge midpoint minus the water top
	local Lips = {}
	for _, E in {{"West", 418, -148}, {"East", 562, -148}, {"North", 490, -94}, {"South", 490, -198}} do
		local B = workspace:Raycast(Vector3.new(E[2], 30, E[3]), Vector3.new(0, -60, 0), BedRay)
		local InTop = Column(E[2] + (E[1] == "West" and 4 or E[1] == "East" and -4 or 0), E[3] + (E[1] == "North" and -4 or E[1] == "South" and 4 or 0))
		Lips[E[1]] = {Ground = B and R(B.Position.Y) or false, GroundPath = B and B.Instance:GetFullName() or false,
			WaterTop = InTop and R(InTop) or false, Lip = (B and InTop) and R(B.Position.Y - InTop) or false}
	end
	Out.Lips = Lips
	-- low ledges: perimeter samples 1.5 studs outside the edge whose top is at most 4.5 above the water (top 3)
	local Low, Perim = {}, {}
	local function Sample(X, Z, Side)
		local B = workspace:Raycast(Vector3.new(X, 30, Z), Vector3.new(0, -60, 0), BedRay)
		if B then
			local H = R(B.Position.Y - 3)
			table.insert(Perim, {Side, X, Z, H})
			if H > 0 and H <= 4.5 then table.insert(Low, {Side = Side, X = X, Z = Z, Above = H, Path = B.Instance:GetFullName()}) end
		end
	end
	for X = 422, 558, 4 do Sample(X, -98.5, "North") Sample(X, -197.5, "South") end
	for Z = -194, -102, 4 do Sample(418.5, Z, "West") Sample(561.5, Z, "East") end
	Out.LowLedges = Low
	Out.Perimeter = Perim
	Out.PondCentreLiquid = {At0 = Liquid(Vector3.new(490, 0, -148)), AtMinus4 = Liquid(Vector3.new(490, -4, -148))}
end
Out.BedPaths = Paths2

local Json = HttpService:JSONEncode(Out)
if #Json <= 25000 then return Json end
local SV = ServerStorage:FindFirstChild("SwimSurveyOut") or Instance.new("StringValue")
SV.Name = "SwimSurveyOut"
SV.Value = Json
SV.Parent = ServerStorage
return "PARKED " .. #Json .. " characters in ServerStorage.SwimSurveyOut"

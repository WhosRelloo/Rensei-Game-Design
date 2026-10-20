-- Lindenmoor kit swap (2026-10-20). Run in Ye (Edit) after import/chunk_01..07.lua have built ServerStorage.LindenmoorStaging.
--   1. backs up what it replaces to ServerStorage.RenseiBackups["Pre-LindenmoorKit_2026-10-20"]
--      (Houses, Trees, Lamps, the barn parts of Farm, the tent wedges of Camp, and the Lighting/Atmosphere values)
--   2. moves the new models into Workspace.World.Map.Lindenmoor (Houses, Trees, Lamps, Farm, Camp, Square, new Scenery)
--   3. re-skins the kept parts (Station, Bridge, Fences, Farm crops, Square, Gorge, Camp seats) by name: material and
--      colour only, geometry untouched; the old values are kept as attributes PreKitMaterial / PreKitColor
--   4. fills ServerStorage.LindenmoorKit with one copy of each kit piece, pivot at the origin, for hand placement
--   5. moves the look toward the reference: teal haze (Atmosphere), every value a PROPOSAL
-- Kept exactly: terrain, water, LindenmoorSpawn, bandit spawns, GorgeLedge, Workshop, StyleTrainers, LindenmoorRun,
-- HubRoad, Areas, the camp FirePit / Embers / Fire. Refuses to run twice (the backup folder is the marker).
local SS = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local L = workspace.World.Map.Lindenmoor
local Stage = SS:FindFirstChild("LindenmoorStaging")
assert(Stage, "run import/chunk_01..07.lua first")

local EXPECT = {Houses = 9, Trees = 158, Forest = 69, Ridge = 28, CreekBanks = 118, Edging = 77, Square = 1, Lamps = 17, Farm = 1, Camp = 6}
for G, N in pairs(EXPECT) do
	local F = Stage:FindFirstChild(G)
	assert(F and #F:GetChildren() == N, ("staging %s has %d models, expected %d"):format(G, F and #F:GetChildren() or -1, N))
end

local Backups = SS:FindFirstChild("RenseiBackups") or Instance.new("Folder")
Backups.Name = "RenseiBackups"
Backups.Parent = SS
assert(not Backups:FindFirstChild("Pre-LindenmoorKit_2026-10-20"), "already swapped (backup exists)")
local B = Instance.new("Folder")
B.Name = "Pre-LindenmoorKit_2026-10-20"
B.Parent = Backups

-- 1 + 2: replace whole groups
for _, N in ipairs({"Houses", "Trees", "Lamps"}) do
	local Old = L:FindFirstChild(N)
	local New = Instance.new(Old and Old.ClassName or "Model")
	New.Name = N
	if Old then Old.Parent = B end
	for _, M in ipairs(Stage[N]:GetChildren()) do M.Parent = New end
	New.Parent = L
end
-- the barn and the tents are rebuilt; crops, hay, logs, crates, spawns and the fire stay
local function Pull(Group, Pred, Into)
	local F = Instance.new("Folder")
	F.Name = Into
	for _, C in ipairs(L[Group]:GetChildren()) do
		if Pred(C) then C.Parent = F end
	end
	F.Parent = B
end
Pull("Farm", function(C) return C.Name:sub(1, 4) == "Barn" end, "Farm_Barn")
Pull("Camp", function(C) return C.Name == "Tent" end, "Camp_Tents")
for _, G in ipairs({"Farm", "Camp", "Square"}) do
	for _, M in ipairs(Stage[G]:GetChildren()) do M.Parent = L[G] end
end
-- the camp keeps its original fire light; the new ring of stones doesn't add a second one
for _, D in ipairs(L.Camp:FindFirstChild("FirePit_Main"):GetDescendants()) do
	if D:IsA("PointLight") then D:Destroy() end
end
local Scenery = Instance.new("Model")
Scenery.Name = "Scenery"
for _, G in ipairs({"Forest", "Ridge", "CreekBanks", "Edging"}) do
	local F = Instance.new("Model")
	F.Name = G
	for _, M in ipairs(Stage[G]:GetChildren()) do M.Parent = F end
	F.Parent = Scenery
end
Scenery.Parent = L

-- 3: re-skin kept parts by name (material, hex colour); names not listed are left alone
local W, P, C, R, G, LG, M, PL, CR = "Wood", "WoodPlanks", "Cobblestone", "Rock", "Grass", "LeafyGrass", "Metal", "SmoothPlastic", "ClayRoofTiles"
local RESKIN = {
	Station = {Sleeper = {W, "5a4030"}, Rail = {M, "3a3835"}, BufferStop = {M, "3a3835"}, TrestlePier = {C, "8d8577"},
		TrestleBeam = {W, "5a4030"}, StationHouse = {C, "8d8577"}, StationRoof = {"RoofShingles", "5d6870"}, Canopy = {P, "8a6a48"},
		CanopyPost = {W, "5a4030"}, StationTrim = {W, "5a4030"}, StationDoor = {P, "7a5a3e"}, PlatformEdge = {C, "8d8577"},
		Platform = {C, "9a958a"}, PlatformRamp = {C, "9a958a"}},
	Bridge = {ArchStone = {C, "8d8577"}, Parapet = {C, "8d8577"}, Pier = {C, "8d8577"}, Deck = {C, "8a8a7e"}, Ramp = {C, "8a8a7e"}},
	Fences = {FenceRail = {W, "5a4030"}, FencePost = {W, "4e3828"}},
	Farm = {Wheat = {G, "d9b95e"}, Cabbages = {LG, "4a6b30"}, HayBale = {G, "cfae5c"}},
	Square = {BenchSeat = {P, "8a6a48"}, BenchBack = {P, "8a6a48"}, BenchLeg = {M, "2e2c29"}, WellPost = {W, "5a4030"},
		WellBeam = {W, "5a4030"}, WellRoof = {CR, "a2553c"}, WellRing = {C, "8d8577"}, NoticeBoard = {P, "7a5a3e"},
		NoticePost = {W, "5a4030"}, Notice = {PL, "e6dcc2"}},
	Gorge = {Cliff = {R, "6a6c62"}, WestShelf = {R, "6f7566"}, EastShelf = {R, "6f7566"}, WestRamp = {R, "6f7566"},
		BenchSeat = {P, "8a6a48"}, BenchBack = {P, "8a6a48"}},
	Camp = {LogSeat = {W, "4a3a2c"}, Crate = {P, "8a6a48"}},
}
local Skinned = 0
for Group, Map in pairs(RESKIN) do
	for _, Part in ipairs(L[Group]:GetChildren()) do
		local S = Part:IsA("BasePart") and Map[Part.Name]
		if S then
			Part:SetAttribute("PreKitMaterial", Part.Material.Name)
			Part:SetAttribute("PreKitColor", Part.Color)
			Part.Material = Enum.Material[S[1]]
			Part.Color = Color3.fromHex(S[2])
			Skinned += 1
		end
	end
end

-- 4: the kit (one copy per piece, pivot at the origin)
local KIT = {Farmhouse = 9, Oak = 4, OakBig = 3, Cypress = 3, LampPost = 1, Barn = 1, TentHalf = 1, FirePit = 1, CampProps = 1,
	RidgeTerrace = 3, BankStones = 3, EdgeStone = 3, Square = 1}
local Kit = SS:FindFirstChild("LindenmoorKit")
if Kit then Kit.Parent = B end
Kit = Instance.new("Folder")
Kit.Name = "LindenmoorKit"
local Found = {}
for _, D in ipairs(L:GetDescendants()) do
	local K = D:IsA("Model") and D:GetAttribute("LindenmoorKit")
	if K and KIT[K] then
		Found[K] = Found[K] or {}
		table.insert(Found[K], D)
	end
end
local Pieces = 0
for K, List in pairs(Found) do
	table.sort(List, function(A, Bm) return A.Name < Bm.Name end)
	local F = Instance.new("Folder")
	F.Name = K
	for I = 1, math.min(KIT[K], #List) do
		local Copy = List[I]:Clone()
		Copy:PivotTo(CFrame.new())
		Copy.Parent = F
		Pieces += 1
	end
	F.Parent = Kit
end
Kit.Parent = SS

-- 5: lighting (old values kept on the backup folder)
local Atm = Lighting:FindFirstChildOfClass("Atmosphere")
if Atm then
	for _, N in ipairs({"Density", "Offset", "Color", "Decay", "Glare", "Haze"}) do B:SetAttribute("Atmosphere_" .. N, Atm[N]) end
	Atm.Density, Atm.Offset, Atm.Glare, Atm.Haze = 0.42, 0.12, 0.35, 1.8
	Atm.Color, Atm.Decay = Color3.fromHex("a9c2bf"), Color3.fromHex("5e7a78")
end
B:SetAttribute("OutdoorAmbient", Lighting.OutdoorAmbient)
Lighting.OutdoorAmbient = Color3.fromHex("5c6a68")

Stage:Destroy()
local Parts = 0
for _, D in ipairs(L:GetDescendants()) do if D:IsA("BasePart") then Parts += 1 end end
return ("swapped: backup %s, re-skinned %d parts, kit %d pieces, Lindenmoor now %d parts"):format(B:GetFullName(), Skinned, Pieces, Parts)

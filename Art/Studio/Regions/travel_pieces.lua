-- travel_pieces (Region Foundation Task 12, 2026-10-24): the travel builders of Art/Studio/Travel/station_foundry.lua,
-- extracted as a ModuleScript source and parameterised. setup.lua builds a region's travel pieces with them from its
-- RenseiMarker parts. station_foundry.lua is left as it is (Foundry's own build script still works), so the builders
-- exist twice: a change to one must be made in the other (the final review decides whether station_foundry.lua should
-- call this module instead).
-- What changed from station_foundry.lua (behaviour and output are otherwise the same; every size is still a PROPOSAL):
--   * part(name, size, cf, mat, color, parent): parent is required (it defaulted to Foundry's model F).
--   * arrival(point, pos, parent): the parent is an argument; it returns the part.
--   * lay(Name, Origin, Route, Tag, Parent, Kit): the parent model and the kit folder (ServerStorage.TrainKit, the seven
--     *_Main cars) are arguments; checkKit(Kit) asserts the kit holds them.
--   * booth(CF, Station, Parent), board(Pos, Facing, Parent), roadGate(Pos, Out, Parent): the parent is an argument.
--   * Passage, PapersGate, FreightYard and Railing already took everything in their C table; unchanged.
-- The data tables (ORDER, LEN, KITDATA, PTOP, PSIDE, ROAD_HALF, VERGE, T9_*) are exported as they are.
local CS = game:GetService("CollectionService")

local function part(name, size, cf, mat, color, parent)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Material, p.Color = name, size, cf, mat, color
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function arrival(point, pos, parent)
	local a = part("Arrival_" .. point, Vector3.new(4, 1, 4), CFrame.new(pos), Enum.Material.SmoothPlastic, Color3.new(1, 1, 1), parent)
	a.Transparency, a.CanCollide, a.CanQuery, a.CanTouch = 1, false, false, false
	a:SetAttribute("Point", point)
	CS:AddTag(a, "RenseiArrival")
	return a
end


local ORDER = {"Locomotive_Main", "Tender_Main", "BaggageCar_Main", "ThirdClass_Main", "DiningCar_Main", "SecondClass_Main", "CabinCar_Main"}
local LEN = {Locomotive_Main = 72, Tender_Main = 30} -- the coaches are 64; 3 between cars (the kit's spacing)

local function checkKit(Kit)
	assert(Kit, "the train kit (ServerStorage.TrainKit) is missing: copy it from Ye first")
	for _, N in ipairs(ORDER) do
		assert(Kit:FindFirstChild(N), "the train kit has no " .. N)
	end
	return Kit
end

-- invisible walls in the ride train's open side doors and open end gangways, so nobody steps off at 400 studs
local function blockRide(T)
	for _, Z in ipairs(T:GetDescendants()) do
		if Z:IsA("BasePart") and Z.Name:find("BoardZone") then
			for _, S in ipairs({-1, 1}) do
				local W = part("RideBlock", Vector3.new(Z.Size.X + 0.4, Z.Size.Y + 1, 0.4), Z.CFrame * CFrame.new(0, 0.5, S * 5.95), Enum.Material.SmoothPlastic, Color3.new(1, 1, 1), T) -- PROPOSAL: in the side opening (jambs at 5.7, grabs at 6.15)
				W.Transparency, W.CanQuery, W.CanTouch, W.CastShadow = 1, false, false, false
			end
		end
	end
	for _, E in ipairs({{"BaggageCar_Main", 1}, {"CabinCar_Main", -1}}) do -- the open gangways at the ends of the coaches
		local Car = T:FindFirstChild(E[1])
		if Car then
			local W = part("RideBlock", Vector3.new(0.4, 10, 7), Car:GetPivot() * CFrame.new(E[2] * 33.3, 8.5, 0), Enum.Material.SmoothPlastic, Color3.new(1, 1, 1), T) -- PROPOSAL
			W.Transparency, W.CanQuery, W.CanTouch, W.CastShadow = 1, false, false, false
		end
	end
	-- (Task 9) the baggage car's open side door: the stowaway's way in at the station, shut on the ride
	local Bag = T:FindFirstChild("BaggageCar_Main")
	local Stow = Bag and Bag:FindFirstChild("StowZone", true)
	if Stow then
		local CF = Bag:GetPivot()
		local L = CF:PointToObjectSpace(Stow.Position)
		local W = part("RideBlock", Vector3.new(6.2, 8, 0.4), CF * CFrame.new(L.X, L.Y + 0.5, (L.Z >= 0 and 1 or -1) * 5.95), Enum.Material.SmoothPlastic, Color3.new(1, 1, 1), T) -- PROPOSAL: in the door (frames at Along +-2.7)
		W.Transparency, W.CanQuery, W.CanTouch, W.CastShadow = 1, false, false, false
	end
end

local function lay(Name, Origin, Route, Tag, Parent, Kit)
	local T = Instance.new("Model")
	T.Name = Name
	T:SetAttribute("Route", Route)
	T:SetAttribute("Length", 440)
	local Z = 0
	for _, N in ipairs(ORDER) do
		local Len = LEN[N] or 64
		local Car = Kit[N]:Clone()
		Car:PivotTo(CFrame.new(Origin + Vector3.new(0, 0, -(Z + Len / 2))) * CFrame.Angles(0, -math.rad(90), 0))
		Car.Parent = T
		Z += Len + 3
	end
	T.WorldPivot = CFrame.new(Origin) -- the nose, at rail top: StationService maps platform -> ride by the pivots
	if Tag == "RenseiRideTrain" then blockRide(T) end
	CS:AddTag(T, Tag)
	T.Parent = Parent
	return T
end

local function booth(CF, Station, Parent)
	local M = Instance.new("Model")
	M.Name = "TicketBooth"
	local WOOD, TRIM = Color3.fromRGB(122, 90, 62), Color3.fromRGB(86, 62, 44)
	local Clerk = part("TicketClerk", Vector3.new(6, 3, 1.2), CF * CFrame.new(0, 1.5, 0), Enum.Material.WoodPlanks, WOOD, M)
	Clerk:SetAttribute("Station", Station)
	CS:AddTag(Clerk, "RenseiTicketClerk")
	part("BoothBack", Vector3.new(6, 7.5, 0.3), CF * CFrame.new(0, 3.75, 3.2), Enum.Material.WoodPlanks, TRIM, M)
	for _, S in ipairs({-1, 1}) do
		part("BoothSide", Vector3.new(0.3, 7.5, 3.8), CF * CFrame.new(S * 3.15, 3.75, 1.45), Enum.Material.WoodPlanks, TRIM, M)
	end
	part("BoothRoof", Vector3.new(7, 0.4, 4.8), CF * CFrame.new(0, 7.7, 1.2), Enum.Material.WoodPlanks, TRIM, M)
	local Sign = part("BoothSign", Vector3.new(6, 1.2, 0.3), CF * CFrame.new(0, 6.9, -0.1), Enum.Material.Wood, Color3.fromRGB(40, 34, 30), M)
	local SG = Instance.new("SurfaceGui")
	SG.Face, SG.PixelsPerStud, SG.SizingMode = Enum.NormalId.Front, 50, Enum.SurfaceGuiSizingMode.PixelsPerStud
	SG.Parent = Sign
	local Tx = Instance.new("TextLabel")
	Tx.Size, Tx.BackgroundTransparency, Tx.Text, Tx.TextScaled = UDim2.fromScale(1, 1), 1, "TICKETS", true
	Tx.Font, Tx.TextColor3 = Enum.Font.Antique, Color3.fromRGB(214, 176, 92)
	Tx.Parent = SG
	-- the clerk: R6, State-blue uniform (PROPOSAL colours; the Heat UI's State blue, darkened for cloth)
	local D = Instance.new("HumanoidDescription")
	local SKIN, COAT, TROUSERS = Color3.fromRGB(234, 190, 152), Color3.fromRGB(44, 62, 104), Color3.fromRGB(30, 36, 54)
	D.HeadColor, D.TorsoColor, D.LeftArmColor, D.RightArmColor = SKIN, COAT, COAT, COAT
	D.LeftLegColor, D.RightLegColor = TROUSERS, TROUSERS
	local N = game:GetService("Players"):CreateHumanoidModelFromDescription(D, Enum.HumanoidRigType.R6)
	N.Name = "Clerk"
	local A = N:FindFirstChild("Animate")
	if A then A:Destroy() end
	for _, P in ipairs(N:GetDescendants()) do
		if P:IsA("BasePart") then P.Anchored = true end
	end
	N.PrimaryPart = N:FindFirstChild("HumanoidRootPart")
	N.Humanoid.DisplayName = "Ticket clerk"
	N.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	N:PivotTo(CF * CFrame.new(0, 3, 1.9))
	N.Parent = M
	M.Parent = Parent
	return M
end

local function board(Pos, Facing, Parent)
	local M = Instance.new("Model")
	M.Name = "DepartureBoardStand"
	local CF = CFrame.lookAt(Pos, Pos + Facing)
	local Board = part("DepartureBoard", Vector3.new(8, 4, 0.4), CF, Enum.Material.Wood, Color3.fromRGB(40, 34, 30), M)
	CS:AddTag(Board, "RenseiDepartureBoard")
	local Foot = Pos.Y - 2 - 6 -- the posts go from the board's bottom down to the platform top (8 below the centre)
	for _, S in ipairs({-1, 1}) do
		local At = (CF * CFrame.new(S * 3.6, 0, 0.35)).Position
		part("BoardPost", Vector3.new(0.5, (Pos.Y + 2) - Foot, 0.5), CFrame.new(At.X, (Pos.Y + 2 + Foot) / 2, At.Z), Enum.Material.Metal, Color3.fromRGB(58, 56, 53), M)
	end
	M.Parent = Parent
	return M
end

local function roadGate(Pos, Out, Parent) -- Pos: on the road surface; Out: the way the road leaves
	local M = Instance.new("Model")
	M.Name = "RoadGate"
	local CF = CFrame.lookAt(Pos, Pos + Out)
	local STONE = Color3.fromRGB(141, 133, 119)
	for _, S in ipairs({-1, 1}) do -- PROPOSAL sizes, clear of the 12-wide road
		part("GatePillar", Vector3.new(3, 12, 3), CF * CFrame.new(S * 8.5, 6, 0), Enum.Material.Cobblestone, STONE, M)
	end
	part("GateLintel", Vector3.new(20, 2.5, 3.5), CF * CFrame.new(0, 13.25, 0), Enum.Material.Cobblestone, STONE, M)
	M.Parent = Parent
	return M
end

local KITDATA = { -- measured in Ye (ServerStorage.LindenmoorKit, World.Map.Lindenmoor.Fences): {Name, SizeX, SizeY, SizeZ, CFrame from the pivot, Material, R, G, B, CanCollide, Transparency}
	Cypress = {
		{{"Tier0",7.572,6.228,6.815,{0,8.384,0,0.974,0,-0.229,0,1,0,0.229,0,0.974},"LeafyGrass",45,74,48,true,0},{"Tier1",6.032,6.228,5.429,{0,13.894,0,0.982,0,-0.188,0,1,0,0.188,0,0.982},"LeafyGrass",45,74,48,true,0},{"Tier2",5.849,6.228,5.264,{0,19.403,0,0.923,0,-0.386,0,1,0,0.386,0,0.923},"LeafyGrass",45,74,48,true,0},{"Tier3",4.663,6.228,4.197,{0,24.913,0,1,0,-0.027,0,1,0,0.027,0,1},"LeafyGrass",45,74,48,true,0},{"Tier4",3.72,6.228,3.348,{0,30.422,0,0.837,0,-0.547,0,1,0,0.547,0,0.837},"LeafyGrass",45,74,48,true,0},{"Tier5",2.836,6.228,2.552,{0,35.932,0,0.853,0,-0.522,0,1,0,0.522,0,0.853},"LeafyGrass",45,74,48,true,0},{"Trunk",1.6,9.582,1.6,{0,4.291,0,1,0,0,0,1,0,0,0,1},"Wood",74,58,44,true,0}},
		{{"Tier0",7.799,6.119,7.02,{0,8.237,0,0.943,0,-0.331,0,1,0,0.331,0,0.943},"LeafyGrass",45,74,48,true,0},{"Tier1",7.095,6.119,6.385,{0,13.65,0,0.667,0,-0.745,0,1,0,0.745,0,0.667},"LeafyGrass",45,74,48,true,0},{"Tier2",5.111,6.119,4.6,{0,19.063,0,0.575,0,-0.818,0,1,0,0.818,0,0.575},"LeafyGrass",45,74,48,true,0},{"Tier3",4.816,6.119,4.335,{0,24.477,0,0.68,0,-0.733,0,1,0,0.733,0,0.68},"LeafyGrass",45,74,48,true,0},{"Tier4",3.395,6.119,3.056,{0,29.89,0,0.954,0,-0.298,0,1,0,0.298,0,0.954},"LeafyGrass",45,74,48,true,0},{"Tier5",2.468,6.119,2.221,{0,35.303,0,0.955,0,-0.297,0,1,0,0.297,0,0.955},"LeafyGrass",45,74,48,true,0},{"Trunk",1.6,9.414,1.6,{0,4.207,0,1,0,0,0,1,0,0,0,1},"Wood",74,58,44,true,0}},
		{{"Tier0",7.945,6.16,7.151,{0,8.292,0,0.769,0,-0.639,0,1,0,0.639,0,0.769},"LeafyGrass",45,74,48,true,0},{"Tier1",6.206,6.16,5.585,{0,13.741,0,0.761,0,-0.649,0,1,0,0.649,0,0.761},"LeafyGrass",45,74,48,true,0},{"Tier2",5.735,6.16,5.161,{0,19.189,0,0.991,0,-0.131,0,1,0,0.131,0,0.991},"LeafyGrass",45,74,48,true,0},{"Tier3",5.003,6.16,4.503,{0,24.638,0,0.94,0,-0.342,0,1,0,0.342,0,0.94},"LeafyGrass",45,74,48,true,0},{"Tier4",3.379,6.16,3.041,{0,30.087,0,0.977,0,-0.214,0,1,0,0.214,0,0.977},"LeafyGrass",45,74,48,true,0},{"Tier5",2.773,6.16,2.496,{0,35.536,0,0.6,0,-0.8,0,1,0,0.8,0,0.6},"LeafyGrass",45,74,48,true,0},{"Trunk",1.6,9.476,1.6,{0,4.238,0,1,0,0,0,1,0,0,0,1},"Wood",74,58,44,true,0}},
	},
	Oak = {
		{{"Bit0_0",3.869,3.271,4.41,{3.459,15.852,7.115,-0.806,0,-0.592,0,1,0,0.592,0,-0.806},"LeafyGrass",74,107,48,true,0},{"Bit0_1",5.083,3.453,4.838,{2.087,17.285,-6.682,-0.412,0,-0.911,0,1,0,0.911,0,-0.412},"LeafyGrass",74,107,48,true,0},{"Bit0_2",4.373,4.58,3.9,{7.576,15.894,1.645,0.948,0,-0.319,0,1,0,0.319,0,0.948},"LeafyGrass",74,107,48,true,0},{"Bit1_0",5.961,3.136,3.189,{5.627,20.054,6.064,0.96,0,-0.279,0,1,0,0.279,0,0.96},"LeafyGrass",74,107,48,true,0},{"Bit1_1",5.045,3.63,3.153,{1.923,21.511,6.111,-0.878,0,-0.48,0,1,0,0.48,0,-0.878},"LeafyGrass",74,107,48,true,0},{"Bit1_2",4.997,3.669,3.94,{5.948,20.074,3.976,0.773,0,-0.635,0,1,0,0.635,0,0.773},"LeafyGrass",74,107,48,true,0},{"Bit2_0",4.607,3.508,4.207,{-3.969,24.027,-3.986,0.47,0,-0.883,0,1,0,0.883,0,0.47},"LeafyGrass",74,107,48,true,0},{"Bit2_1",3.91,4.516,4.426,{-5.494,25.253,3.859,0.107,0,-0.994,0,1,0,0.994,0,0.107},"LeafyGrass",74,107,48,true,0},{"Bit2_2",3.807,4.319,3.392,{-2.586,24.488,-5.698,-0.622,0,-0.783,0,1,0,0.783,0,-0.622},"LeafyGrass",74,107,48,true,0},{"Branch0",1.256,7.609,1.256,{3.277,14.926,-0.992,0.43,0.855,0.29,-0.893,0.45,0,-0.13,-0.259,0.957},"Wood",74,58,44,true,0},{"Branch1",1.256,6.816,1.256,{0.559,15.672,3.016,0.082,0.163,-0.983,-0.894,0.447,0,0.44,0.879,0.182},"Wood",74,58,44,true,0},{"Branch2",1.256,6.363,1.256,{-2.81,15.208,-0.553,-0.44,-0.877,0.193,-0.894,0.448,0,-0.087,-0.173,-0.981},"Wood",74,58,44,true,0},{"Branch3",1.256,8.333,1.256,{0.641,15.457,-3.694,0.091,0.145,0.985,-0.847,0.531,0,-0.523,-0.835,0.171},"Wood",74,58,44,true,0},{"Canopy0",19.586,4.503,15.041,{0.547,18.837,-0.51,0.831,0,-0.556,0,1,0,0.556,0,0.831},"LeafyGrass",74,107,48,true,0},{"Canopy1",16.841,5.356,13.283,{-0.319,22.566,-0.079,0.628,0,-0.778,0,1,0,0.778,0,0.628},"LeafyGrass",74,107,48,true,0},{"Canopy2",14.016,5.434,11.933,{1.628,26.295,-0.043,0.221,0,-0.975,0,1,0,0.975,0,0.221},"LeafyGrass",74,107,48,true,0},{"Root0",2.827,1.864,1.728,{1.701,0.8,-0.304,0.977,0.132,0.165,-0.12,0.989,-0.081,-0.174,0.059,0.983},"Wood",74,58,44,true,0},{"Root1",2.827,1.864,1.728,{-0.674,0.8,1.591,-0.387,0.133,-0.912,0.122,0.988,0.092,0.914,-0.076,-0.399},"Wood",74,58,44,true,0},{"Root2",2.827,1.864,1.728,{-0.964,0.8,-1.434,-0.548,-0.076,0.833,-0.186,0.982,-0.033,-0.815,-0.173,-0.552},"Wood",74,58,44,true,0},{"Trunk",3.141,20.337,3.141,{0,9.669,0,0.871,0,-0.492,0,1,0,0.492,0,0.871},"Wood",74,58,44,true,0},{"Vine0",0.435,5.909,0.527,{-3.097,14.383,-4.016,1,0,0,0,1,0,0,0,1},"LeafyGrass",42,68,36,false,0},{"Vine1",0.687,6.849,0.403,{-2.836,13.913,-3.672,1,0,0,0,1,0,0,0,1},"LeafyGrass",42,68,36,false,0},{"Vine2",0.452,9.528,0.671,{8.247,12.574,2.029,1,0,0,0,1,0,0,0,1},"LeafyGrass",42,68,36,false,0},{"Vine3",0.581,6.701,0.454,{3.605,13.987,-1.285,1,0,0,0,1,0,0,0,1},"LeafyGrass",42,68,36,false,0}},
		{{"Bit0_0",5.732,3.775,3.41,{7.512,19.407,-6.261,0.214,0,-0.977,0,1,0,0.977,0,0.214},"LeafyGrass",74,107,48,true,0},{"Bit0_1",5.742,4.411,3.874,{-3.338,19.414,7.791,0.918,0,-0.396,0,1,0,0.396,0,0.918},"LeafyGrass",74,107,48,true,0},{"Bit0_2",6.303,3.531,5.329,{10.414,19.111,-3.5,0.999,0,-0.042,0,1,0,0.042,0,0.999},"LeafyGrass",74,107,48,true,0},{"Bit1_0",4.111,3.532,4.46,{0.035,24.276,-8.833,1,0,-0.025,0,1,0,0.025,0,1},"LeafyGrass",74,107,48,true,0},{"Bit1_1",4.884,4.38,4.907,{-4.983,23.331,4.079,1,0,-0.001,0,1,0,0.001,0,1},"LeafyGrass",74,107,48,true,0},{"Bit1_2",5.787,4.269,4.627,{5.87,24.771,2.102,0.033,0,-0.999,0,1,0,0.999,0,0.033},"LeafyGrass",74,107,48,true,0},{"Bit2_0",4.488,3.066,4.076,{3.403,29.087,5.065,-0.079,0,-0.997,0,1,0,0.997,0,-0.079},"LeafyGrass",74,107,48,true,0},{"Bit2_1",5.298,4.793,4.937,{-6.698,27.227,-0.149,0.31,0,-0.951,0,1,0,0.951,0,0.31},"LeafyGrass",74,107,48,true,0},{"Bit2_2",4.963,3.16,4.037,{5.187,28.788,2.751,0.717,0,-0.697,0,1,0,0.697,0,0.717},"LeafyGrass",74,107,48,true,0},{"Branch0",1.499,8.845,1.499,{3.931,20.184,-0.621,0.39,0.908,0.156,-0.919,0.394,0,-0.062,-0.143,0.988},"Wood",74,58,44,true,0},{"Branch1",1.499,8.763,1.499,{-0.118,20.16,3.941,-0.016,-0.025,-1,-0.846,0.533,0,0.533,0.846,-0.03},"Wood",74,58,44,true,0},{"Branch2",1.499,7.104,1.499,{-3.196,19.918,0.077,-0.359,-0.933,-0.024,-0.933,0.359,0,0.009,0.022,-1},"Wood",74,58,44,true,0},{"Branch3",1.499,7.746,1.499,{0.255,18.466,-3.476,0.026,0.069,0.997,-0.935,0.355,0,-0.354,-0.932,0.073},"Wood",74,58,44,true,0},{"Canopy0",23.302,5.647,19.996,{0.844,21.457,0.569,0.647,0,-0.762,0,1,0,0.762,0,0.647},"LeafyGrass",74,107,48,true,0},{"Canopy1",17.694,5.86,13.722,{1.202,25.808,-0.964,-0.999,0,-0.051,0,1,0,0.051,0,-0.999},"LeafyGrass",74,107,48,true,0},{"Canopy2",16.052,4.216,13.468,{1.165,30.159,-1.311,-0.816,0,-0.579,0,1,0,0.579,0,-0.816},"LeafyGrass",74,107,48,true,0},{"Root0",3.372,2.175,2.061,{2.057,0.8,-0.128,0.987,0.143,0.074,-0.149,0.985,0.083,-0.061,-0.093,0.994},"Wood",74,58,44,true,0},{"Root1",3.372,2.175,2.061,{-1.144,0.8,1.714,-0.555,0.031,-0.831,-0.029,0.998,0.057,0.832,0.056,-0.553},"Wood",74,58,44,true,0},{"Root2",3.372,2.175,2.061,{-0.804,0.8,-1.898,-0.388,-0.04,0.921,-0.109,0.994,-0.002,-0.915,-0.101,-0.39},"Wood",74,58,44,true,0},{"Trunk",3.747,22.957,3.747,{0,10.979,0,0.833,0,-0.554,0,1,0,0.554,0,0.833},"Wood",74,58,44,true,0},{"Vine0",0.402,15.604,0.462,{0.213,12.155,3.486,1,0,0,0,1,0,0,0,1},"LeafyGrass",42,68,36,false,0},{"Vine1",0.627,10.106,0.689,{4.831,14.905,-1.577,1,0,0,0,1,0,0,0,1},"LeafyGrass",42,68,36,false,0},{"Vine2",0.505,9.473,0.644,{4.376,15.221,-4.333,1,0,0,0,1,0,0,0,1},"LeafyGrass",42,68,36,false,0},{"Vine3",0.441,16.081,0.532,{0.115,11.917,3.526,1,0,0,0,1,0,0,0,1},"LeafyGrass",42,68,36,false,0}},
	},
	OakBig = {
		{{"Bit0_0",12.83,4.087,11.112,{5.172,36.485,17.853,-0.991,0,-0.137,0,1,0,0.137,0,-0.991},"LeafyGrass",74,107,48,true,0},{"Bit0_1",12.086,4.906,10.658,{-1.204,37.259,19.615,0.444,0,-0.896,0,1,0,0.896,0,0.444},"LeafyGrass",74,107,48,true,0},{"Bit0_2",12.68,4.662,7.945,{20.294,38.141,5.915,0.873,0,-0.488,0,1,0,0.488,0,0.873},"LeafyGrass",74,107,48,true,0},{"Bit0_3",12.244,4.768,7.691,{-12.48,37.132,-17.609,0.875,0,-0.484,0,1,0,0.484,0,0.875},"LeafyGrass",74,107,48,true,0},{"Bit1_0",11.908,3.904,9.558,{9.936,40.652,17.786,-0.22,0,-0.975,0,1,0,0.975,0,-0.22},"LeafyGrass",74,107,48,true,0},{"Bit1_1",10.249,3.759,6.84,{-19.116,39.504,0.251,0.325,0,-0.946,0,1,0,0.946,0,0.325},"LeafyGrass",74,107,48,true,0},{"Bit1_2",8.894,4.142,8.03,{-18.187,40.957,0.894,0.113,0,-0.994,0,1,0,0.994,0,0.113},"LeafyGrass",74,107,48,true,0},{"Bit1_3",9.182,4.378,8.591,{-12.03,40.277,13.556,0.991,0,-0.134,0,1,0,0.134,0,0.991},"LeafyGrass",74,107,48,true,0},{"Bit2_0",9.577,3.782,6.915,{-14.568,43.691,1.283,0.849,0,-0.529,0,1,0,0.529,0,0.849},"LeafyGrass",74,107,48,true,0},{"Bit2_1",11.272,4.457,11.079,{9.708,42.827,10.163,0.619,0,-0.785,0,1,0,0.785,0,0.619},"LeafyGrass",74,107,48,true,0},{"Bit2_2",13.503,4.591,8.619,{11.273,43.769,-6.622,0.873,0,-0.488,0,1,0,0.488,0,0.873},"LeafyGrass",74,107,48,true,0},{"Bit2_3",8.319,4.054,7.421,{-9.136,44.056,9.031,0.935,0,-0.355,0,1,0,0.355,0,0.935},"LeafyGrass",74,107,48,true,0},{"Bit3_0",12.541,4.27,7.869,{-10.265,46.169,3.954,0.914,0,-0.407,0,1,0,0.407,0,0.914},"LeafyGrass",74,107,48,true,0},{"Bit3_1",8.444,4.23,9.047,{11.873,46.399,5.296,-0.18,0,-0.984,0,1,0,0.984,0,-0.18},"LeafyGrass",74,107,48,true,0},{"Bit3_2",9.472,3.193,8.924,{-1.254,45.808,12.139,-1,0,-0.014,0,1,0,0.014,0,-1},"LeafyGrass",74,107,48,true,0},{"Bit3_3",13.502,3.208,7.753,{-7.465,46.04,-8.847,0.565,0,-0.825,0,1,0,0.825,0,0.565},"LeafyGrass",74,107,48,true,0},{"Branch0",2.131,14.629,2.131,{6.578,29.716,-0.246,0.353,0.935,0.037,-0.935,0.354,0,-0.013,-0.035,0.999},"Wood",74,58,44,true,0},{"Branch1",2.131,13.933,2.131,{3.456,31.571,5.232,0.279,0.475,-0.834,-0.862,0.507,0,0.423,0.719,0.551},"Wood",74,58,44,true,0},{"Branch2",2.131,15.526,2.131,{-6.02,30.821,3.545,-0.491,-0.708,-0.507,-0.822,0.569,0,0.289,0.417,-0.862},"Wood",74,58,44,true,0},{"Branch3",2.131,17.043,2.131,{-5.243,31.084,-5.597,-0.32,-0.604,0.73,-0.884,0.468,0,-0.342,-0.645,-0.684},"Wood",74,58,44,true,0},{"Branch4",2.131,18.57,2.131,{2.256,34.79,-8.046,0.152,0.223,0.963,-0.826,0.563,0,-0.542,-0.796,0.27},"Wood",74,58,44,true,0},{"Canopy0",44.04,7.092,34.319,{-0.596,39.461,1.086,-0.515,0,-0.857,0,1,0,0.857,0,-0.515},"LeafyGrass",74,107,48,true,0},{"Canopy1",40.88,6.216,34.482,{-0.926,42.333,1.319,-0.449,0,-0.894,0,1,0,0.894,0,-0.449},"LeafyGrass",74,107,48,true,0},{"Canopy2",29.908,6.554,23.785,{-0.345,45.205,1.147,-0.905,0,-0.425,0,1,0,0.425,0,-0.905},"LeafyGrass",74,107,48,true,0},{"Canopy3",26.819,5.47,24.041,{-0.513,48.077,-0.648,0.973,0,-0.23,0,1,0,0.23,0,0.973},"LeafyGrass",74,107,48,true,0},{"Root0",4.794,1.436,2.93,{2.869,0.8,-0.592,0.973,-0.134,0.19,0.117,0.988,0.099,-0.201,-0.074,0.977},"Wood",74,58,44,true,0},{"Root1",4.794,1.436,2.93,{0.551,0.8,2.877,0.185,0.019,-0.982,-0.17,0.985,-0.013,0.968,0.169,0.186},"Wood",74,58,44,true,0},{"Root2",4.794,1.436,2.93,{-2.882,0.8,-0.529,-0.982,0.053,0.181,0.056,0.998,0.01,-0.18,0.02,-0.983},"Wood",74,58,44,true,0},{"Root3",4.794,1.436,2.93,{-0.69,0.8,-2.847,-0.235,0.122,0.964,0.031,0.992,-0.118,-0.971,0.002,-0.237},"Wood",74,58,44,true,0},{"Trunk",5.327,40.961,5.327,{0,19.981,0,0.966,0,-0.26,0,1,0,0.26,0,0.966},"Wood",74,58,44,true,0},{"Vine0",0.628,9.802,0.557,{7.07,33.06,-15.245,1,0,0,0,1,0,0,0,1},"LeafyGrass",42,68,36,false,0},{"Vine1",0.566,8.111,0.53,{-2.623,33.906,7.96,1,0,0,0,1,0,0,0,1},"LeafyGrass",42,68,36,false,0},{"Vine2",0.425,10.607,0.555,{6.113,32.658,-3.569,1,0,0,0,1,0,0,0,1},"LeafyGrass",42,68,36,false,0},{"Vine3",0.659,7.368,0.538,{-2.776,34.277,14.966,1,0,0,0,1,0,0,0,1},"LeafyGrass",42,68,36,false,0},{"Vine4",0.687,8.5,0.685,{7.094,33.711,0.421,1,0,0,0,1,0,0,0,1},"LeafyGrass",42,68,36,false,0},{"Vine5",0.667,7.811,0.667,{6.255,34.056,9.988,1,0,0,0,1,0,0,0,1},"LeafyGrass",42,68,36,false,0}},
		{{"Bit0_0",9.978,4.159,10.507,{13.874,42.784,8.419,0.307,0,-0.952,0,1,0,0.952,0,0.307},"LeafyGrass",74,107,48,true,0},{"Bit0_1",12.884,3.269,7.608,{-16.07,41.519,13.547,-0.905,0,-0.426,0,1,0,0.426,0,-0.905},"LeafyGrass",74,107,48,true,0},{"Bit0_2",12.062,4.503,10.047,{-18.483,41.94,-1.572,0.454,0,-0.891,0,1,0,0.891,0,0.454},"LeafyGrass",74,107,48,true,0},{"Bit0_3",10.36,4.562,10.441,{20.334,42.905,2.179,-0.941,0,-0.337,0,1,0,0.337,0,-0.941},"LeafyGrass",74,107,48,true,0},{"Bit1_0",8.664,4.06,8.443,{14.247,45.244,-4.382,-0.858,0,-0.513,0,1,0,0.513,0,-0.858},"LeafyGrass",74,107,48,true,0},{"Bit1_1",9.097,3.396,10.021,{-16.728,46.033,2.631,0.374,0,-0.928,0,1,0,0.928,0,0.374},"LeafyGrass",74,107,48,true,0},{"Bit1_2",10.968,4.609,10.128,{7.02,46.475,-15.354,-0.973,0,-0.23,0,1,0,0.23,0,-0.973},"LeafyGrass",74,107,48,true,0},{"Bit1_3",10.618,4.54,7.871,{7.655,46.339,-13.259,-0.407,0,-0.913,0,1,0,0.913,0,-0.407},"LeafyGrass",74,107,48,true,0},{"Bit2_0",12.927,4.521,9.256,{7.879,47.691,-8.196,0.018,0,-1,0,1,0,1,0,0.018},"LeafyGrass",74,107,48,true,0},{"Bit2_1",12.796,4.579,10.888,{-4.287,48.839,-10.809,0.788,0,-0.616,0,1,0,0.616,0,0.788},"LeafyGrass",74,107,48,true,0},{"Bit2_2",8.388,4.245,8.079,{2.847,48.077,10.162,-0.425,0,-0.905,0,1,0,0.905,0,-0.425},"LeafyGrass",74,107,48,true,0},{"Bit2_3",11.291,3.446,9.193,{-8.688,47.847,-8.387,0.125,0,-0.992,0,1,0,0.992,0,0.125},"LeafyGrass",74,107,48,true,0},{"Bit3_0",8.199,3.226,9.413,{4.412,51.057,8.9,-0.72,0,-0.694,0,1,0,0.694,0,-0.72},"LeafyGrass",74,107,48,true,0},{"Bit3_1",10.847,3.901,9.769,{-4.434,52.273,9.017,0.559,0,-0.829,0,1,0,0.829,0,0.559},"LeafyGrass",74,107,48,true,0},{"Bit3_2",12.966,3.646,9.691,{6.972,50.711,6.096,0.459,0,-0.889,0,1,0,0.889,0,0.459},"LeafyGrass",74,107,48,true,0},{"Bit3_3",8.718,3.162,8.131,{3.652,52.425,7.961,0.825,0,-0.565,0,1,0,0.565,0,0.825},"LeafyGrass",74,107,48,true,0},{"Branch0",2.277,18.198,2.277,{8.15,36.358,-0.801,0.455,0.885,0.098,-0.889,0.457,0,-0.045,-0.087,0.995},"Wood",74,58,44,true,0},{"Branch1",2.277,17.206,2.277,{0.9,41.816,7.69,0.063,0.098,-0.993,-0.841,0.54,0,0.537,0.836,0.116},"Wood",74,58,44,true,0},{"Branch2",2.277,16.6,2.277,{-6.172,33.961,4.209,-0.331,-0.757,-0.563,-0.916,0.401,0,0.226,0.516,-0.826},"Wood",74,58,44,true,0},{"Branch3",2.277,16.869,2.277,{-5.05,32.977,-5.668,-0.27,-0.608,0.747,-0.914,0.406,0,-0.303,-0.682,-0.665},"Wood",74,58,44,true,0},{"Branch4",2.277,13.352,2.277,{3.407,41.066,-4.949,0.282,0.492,0.824,-0.868,0.497,0,-0.409,-0.715,0.567},"Wood",74,58,44,true,0},{"Canopy0",42.826,6.65,36.267,{0.116,44.405,-0.6,-0.779,0,-0.627,0,1,0,0.627,0,-0.779},"LeafyGrass",74,107,48,true,0},{"Canopy1",35.492,4.846,29.373,{-0.014,47.489,0.299,0.146,0,-0.989,0,1,0,0.989,0,0.146},"LeafyGrass",74,107,48,true,0},{"Canopy2",28.414,6.513,24.659,{-0.108,50.573,0.843,0.574,0,-0.819,0,1,0,0.819,0,0.574},"LeafyGrass",74,107,48,true,0},{"Canopy3",23.104,5.179,20.607,{-1.09,53.657,0.942,0.367,0,-0.93,0,1,0,0.93,0,0.367},"LeafyGrass",74,107,48,true,0},{"Root0",5.123,1.542,3.131,{3.03,0.8,-0.789,0.952,0.189,0.24,-0.179,0.982,-0.065,-0.248,0.019,0.969},"Wood",74,58,44,true,0},{"Root1",5.123,1.542,3.131,{0.334,0.8,3.113,0.107,0.058,-0.993,0.026,0.998,0.061,0.994,-0.033,0.105},"Wood",74,58,44,true,0},{"Root2",5.123,1.542,3.131,{-3.13,0.8,-0.087,-0.998,-0.06,0.034,-0.063,0.992,-0.105,-0.028,-0.107,-0.994},"Wood",74,58,44,true,0},{"Root3",5.123,1.542,3.131,{0.044,0.8,-3.131,0.014,-0.043,0.999,0.193,0.98,0.04,-0.981,0.192,0.022},"Wood",74,58,44,true,0},{"Trunk",5.692,45.905,5.692,{0,22.452,0,0.955,0,-0.295,0,1,0,0.295,0,0.955},"Wood",74,58,44,true,0},{"Vine0",0.574,6.989,0.693,{4.354,39.41,5.223,1,0,0,0,1,0,0,0,1},"LeafyGrass",42,68,36,false,0},{"Vine1",0.429,4.483,0.475,{-0.067,40.663,-18.397,1,0,0,0,1,0,0,0,1},"LeafyGrass",42,68,36,false,0},{"Vine2",0.583,10.668,0.689,{-6.883,37.571,8.561,1,0,0,0,1,0,0,0,1},"LeafyGrass",42,68,36,false,0},{"Vine3",0.53,9.116,0.524,{-5.635,38.347,14.688,1,0,0,0,1,0,0,0,1},"LeafyGrass",42,68,36,false,0},{"Vine4",0.59,5.32,0.618,{-1.28,40.245,-16.19,1,0,0,0,1,0,0,0,1},"LeafyGrass",42,68,36,false,0},{"Vine5",0.604,5.959,0.443,{7.254,39.925,14.476,1,0,0,0,1,0,0,0,1},"LeafyGrass",42,68,36,false,0}},
	},
	RidgeTerrace = {
		{{"Slab0",19.557,3.003,13.425,{-0.277,1.502,0,0.999,0,-0.046,0,1,0,0.046,0,0.999},"Rock",107,114,98,true,0},{"Slab1",16.621,2.725,11.223,{-0.64,4.215,-4.576,0.997,0,-0.075,0,1,0,0.075,0,0.997},"Rock",107,114,98,true,0},{"Slab2",15.743,2.61,8.53,{0.047,6.747,-6.989,0.999,0,-0.054,0,1,0,0.054,0,0.999},"Rock",107,114,98,true,0}},
		{{"Slab0",19.973,2.62,15.381,{0.45,1.31,0,0.997,0,-0.078,0,1,0,0.078,0,0.997},"Rock",107,114,98,true,0},{"Slab1",15.123,3.312,11.97,{-0.844,4.145,-3.93,0.997,0,0.071,0,1,0,-0.071,0,0.997},"Rock",107,114,98,true,0}},
		{{"Slab0",20.145,3.182,12.251,{-0.829,1.591,0,0.999,0,-0.035,0,1,0,0.035,0,0.999},"Rock",107,114,98,true,0},{"Slab1",22.336,2.79,11.734,{0.312,4.418,-3.217,0.998,0,-0.062,0,1,0,0.062,0,0.998},"Rock",107,114,98,true,0},{"Slab2",13.225,2.867,11.498,{0.668,7.107,-6.579,0.999,0,0.054,0,1,0,-0.054,0,0.999},"Rock",107,114,98,true,0}},
	},
	BankStones = {
		{{"Stone0",4.134,1.707,2.833,{-0.81,-0.8,-0.764,0.133,-0.029,-0.991,-0.062,0.997,-0.038,0.989,0.067,0.131},"Rock",111,117,102,true,0},{"Stone1",5.416,1.888,4.182,{-1.153,0.4,1.067,0.831,0.056,-0.553,0,0.995,0.101,0.556,-0.084,0.827},"Rock",111,117,102,true,0},{"Stone2",4.055,2.039,3.498,{1.425,1.6,1.43,0.811,-0.023,-0.584,-0.07,0.988,-0.136,0.581,0.152,0.8},"Rock",111,117,102,true,0}},
		{{"Stone0",4.376,2.706,3.454,{-1.27,-0.8,1.244,-0.763,-0.04,-0.645,0.069,0.987,-0.142,0.643,-0.153,-0.751},"Rock",111,117,102,true,0},{"Stone1",5.154,3.111,3.453,{-1.327,0.4,-0.525,0.964,-0.187,-0.19,0.185,0.982,-0.027,0.192,-0.009,0.981},"Rock",111,117,102,true,0}},
		{{"Stone0",4.359,2.051,3.451,{0.962,-0.8,-0.801,0.768,0.181,-0.614,-0.102,0.981,0.162,0.632,-0.062,0.772},"Rock",111,117,102,true,0},{"Stone1",3.946,2.069,2.347,{-0.192,0.4,1.148,0.816,0.109,-0.568,-0.11,0.993,0.033,0.567,0.036,0.823},"Rock",111,117,102,true,0}},
	},
	FencePost = {"FencePost",0.5,4.28,0.5,{0,0,0,1,0,0,0,1,0,0,0,1},"Wood",78,56,40,true,0},
	FenceRail = {"FenceRail",0.25,0.4,15.091,{0,0,0,1,0,0,0,1,0,0,0,1},"Wood",90,64,48,true,0},
}
local function kitPart(D, Parent)
	local P = Instance.new("Part")
	P.Name, P.Size = D[1], Vector3.new(D[2], D[3], D[4])
	P.CFrame = CFrame.new(table.unpack(D[5]))
	P.Material, P.Color = Enum.Material[D[6]], Color3.fromRGB(D[7], D[8], D[9])
	P.CanCollide, P.Transparency, P.Anchored = D[10], D[11], true
	P.TopSurface, P.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	P.Parent = Parent
	return P
end
local KitTemplates = {}
local function kitPiece(Kind, Rng)
	local List = KITDATA[Kind]
	if not List then return nil end
	local I = Rng:NextInteger(1, #List)
	KitTemplates[Kind] = KitTemplates[Kind] or {}
	local T = KitTemplates[Kind][I]
	if not T then
		T = Instance.new("Model")
		T.Name = Kind .. "_" .. (I - 1)
		for _, D in ipairs(List[I]) do kitPart(D, T) end
		T.WorldPivot = CFrame.new()
		KitTemplates[Kind][I] = T
	end
	return T:Clone()
end

-- ===== Roads on foot (World Plan 1 Task 8b, 2026-10-21; world spec §3b). The same builder is in station_lindenmoor.lua
-- and station_foundry.lua. =====
-- A real, walkable stretch of road that leaves the region, in the part-ground style of Art/Studio/Lindenmoor/ground.lua:
-- 4-stud cells of flat slabs in 1-stud steps over stone sides, merged into rectangles; a dirt road down the middle; mossy
-- banks that rise into a cutting towards the far end; kit trees, rocks and fences cloned along it. It carries:
--   * RenseiRoadPassage parts (Route, To, RoadName, Leg = 1 at the mouth .. n at the threshold) covering it, one per
--     leg; they carry RoadPoint attachments on the road's centre line every 8 studs, facing the way out (RoadService
--     walks crossers along the nearest one);
--   * RenseiRoadEncounter parts (Route, Order = 1 nearest the mouth) along it, each with hidden SpawnPoint attachments
--     (Side = "Out" ahead of someone walking out, "In" ahead of someone walking in) behind cover;
--   * a RenseiRoadThreshold part (Route, To) at the far end, round a bend whose far side can't be seen;
--   * the RenseiArrival "RoadStart" (Point) on the road before that bend, facing inward: where travellers from the
--     other place appear.
-- Kit decor (trees, rocks, fences, the gate, the sign) is CanTouch false (fix round 1). CanQuery stays on (controller's
-- ruling): enemy sight raycasts must still hit the trees and cover stones, or stealth breaks.
-- Server code: RoadService; client: TravelClient. Every number is a PROPOSAL.
local function Decor(I) -- no touches on decor (queries stay on: sight lines)
	for _, D in ipairs(I:IsA("BasePart") and {I} or I:GetDescendants()) do
		if D:IsA("BasePart") then D.CanTouch = false end
	end
	return I
end
local PTOP = { -- ground.lua's palette
	grass = {Enum.Material.Grass, {Color3.fromRGB(74, 98, 50), Color3.fromRGB(82, 106, 54), Color3.fromRGB(68, 92, 48), Color3.fromRGB(90, 112, 58)}},
	path = {Enum.Material.Ground, {Color3.fromRGB(98, 84, 64), Color3.fromRGB(90, 78, 60)}},
	stone = {Enum.Material.Slate, {Color3.fromRGB(86, 90, 88), Color3.fromRGB(78, 82, 80), Color3.fromRGB(92, 94, 90)}},
}
local PSIDE = {Color3.fromRGB(66, 60, 52), Color3.fromRGB(60, 56, 50), Color3.fromRGB(72, 66, 56)}
local ROAD_HALF, VERGE = 6, 9 -- PROPOSAL: a 12-wide dirt road (as the hub road), level grass to 9 from the middle

-- C = {Parent, Name, Route, To, RoadName, RoadY, FloorY, Half, Legs, Skip(x, z), Clip {MinX, MaxX, MinZ, MaxZ},
--      Cut, Threshold, RoadStart, Encounters {s, ...}, Gate, Fence, Kit(Kind, Rng) -> Model, Post, Rail, Seed}
-- Legs: {"line", x1, z1, x2, z2} or {"arc", cx, cz, r, a1, a2} (degrees), joined end to end. Distances along the road
-- (s) are in studs from the mouth.
local function Passage(C)
	local Rng = Random.new(C.Seed or 8)
	local M = Instance.new("Model")
	M.Name = C.Name
	local function put(Name, Size, CF, Mat, Color, Parent)
		local P = Instance.new("Part")
		P.Name, P.Size, P.CFrame, P.Material, P.Color = Name, Size, CF, Mat, Color
		P.Anchored = true
		P.TopSurface, P.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		P.Parent = Parent or M
		return P
	end
	local function marker(Name, Size, CF, Tag)
		local P = put(Name, Size, CF, Enum.Material.SmoothPlastic, Color3.new(1, 1, 1))
		P.Transparency, P.CanCollide, P.CanQuery, P.CanTouch, P.CastShadow = 1, false, false, false, false
		if Tag then CS:AddTag(P, Tag) end
		return P
	end

	-- 1. the road's centre line, sampled every 2 studs: {x, z, s, tx, tz}
	local S, LegOf, Len = {}, {}, 0
	for LI, G in ipairs(C.Legs) do
		local Pts = {}
		if G[1] == "line" then
			local L = math.sqrt((G[4] - G[2]) ^ 2 + (G[5] - G[3]) ^ 2)
			local N = math.max(1, math.ceil(L / 2))
			for I = 0, N do
				local F = I / N
				table.insert(Pts, {G[2] + (G[4] - G[2]) * F, G[3] + (G[5] - G[3]) * F})
			end
		else
			local A1, A2 = math.rad(G[5]), math.rad(G[6])
			local N = math.max(1, math.ceil(math.abs(A2 - A1) * G[4] / 2))
			for I = 0, N do
				local A = A1 + (A2 - A1) * I / N
				table.insert(Pts, {G[2] + G[4] * math.cos(A), G[3] + G[4] * math.sin(A)})
			end
		end
		for I, P in ipairs(Pts) do
			if not (LI > 1 and I == 1) then -- a leg starts where the last one ended
				local Prev = S[#S]
				if Prev then Len += math.sqrt((P[1] - Prev[1]) ^ 2 + (P[2] - Prev[2]) ^ 2) end
				table.insert(S, {P[1], P[2], Len})
				LegOf[#S] = LI
			end
		end
	end
	for I, P in ipairs(S) do
		local A, B = S[math.max(1, I - 1)], S[math.min(#S, I + 1)]
		local DX, DZ = B[1] - A[1], B[2] - A[2]
		local L = math.max(math.sqrt(DX * DX + DZ * DZ), 1e-6)
		P[4], P[5] = DX / L, DZ / L
	end
	local function at(SS) -- the road point and its outward direction at distance SS
		SS = math.clamp(SS, 0, Len)
		for I = 2, #S do
			if S[I][3] >= SS then
				local A, B = S[I - 1], S[I]
				local F = (SS - A[3]) / math.max(B[3] - A[3], 1e-6)
				return Vector3.new(A[1] + (B[1] - A[1]) * F, 0, A[2] + (B[2] - A[2]) * F), Vector3.new(B[4], 0, B[5]).Unit
			end
		end
		local E = S[#S]
		return Vector3.new(E[1], 0, E[2]), Vector3.new(E[4], 0, E[5])
	end
	local function nearest(X, Z) -- distance to the centre line, s there, and which side (1 = left of the way out)
		local BD, BP = math.huge, S[1]
		for _, P in ipairs(S) do
			local D = (P[1] - X) ^ 2 + (P[2] - Z) ^ 2
			if D < BD then BD, BP = D, P end
		end
		local Left = (X - BP[1]) * -BP[5] + (Z - BP[2]) * BP[4] > 0
		return math.sqrt(BD), BP[3], Left and 1 or -1
	end
	local function side(T) return Vector3.new(-T.Z, 0, T.X) end -- left of the way out

	-- 2. cells: road, verge, then banks stepping up a stud at a time; on the open stretch the left bank (C.High, the side
	-- away from town) stands higher than the right; from Cut on both rise steeply into a cutting
	local function height(D, SS, Side)
		if D <= ROAD_HALF then return C.RoadY, "path" end
		if D <= VERGE then return C.RoadY, "grass" end
		local Cut = math.clamp((SS - C.Cut) / 40, 0, 1)
		local High = Side == (C.High or 1)
		local K = (High and 0.4 or 0.25) * (1 - Cut) + 1 * Cut -- PROPOSAL: rise per stud away from the road
		local Cap = (High and 6 or 3) * (1 - Cut) + 12 * Cut -- PROPOSAL: studs above the road (12 in the cutting)
		local Mouth = math.clamp(SS / 30, 0.34, 1) -- low banks where the passage leaves town
		local H = math.min(math.floor(Cap + 0.5), math.floor((D - VERGE) * K) + 1)
		H = math.max(1, math.floor(H * Mouth + 0.5))
		return C.RoadY + H, (Cut > 0.5 and D > 15) and "stone" or "grass"
	end
	local MinX, MaxX, MinZ, MaxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, P in ipairs(S) do
		MinX, MaxX = math.min(MinX, P[1]), math.max(MaxX, P[1])
		MinZ, MaxZ = math.min(MinZ, P[2]), math.max(MaxZ, P[2])
	end
	local X0 = math.floor((MinX - C.Half - 4) / 4) * 4
	local Z0 = math.floor((MinZ - C.Half - 4) / 4) * 4
	local NX = math.ceil((MaxX + C.Half + 4 - X0) / 4)
	local NZ = math.ceil((MaxZ + C.Half + 4 - Z0) / 4)
	local Top, Kind = {}, {}
	for I = 1, NX do
		Top[I], Kind[I] = {}, {}
		for K = 1, NZ do
			local X, Z = X0 + (I - 0.5) * 4, Z0 + (K - 0.5) * 4
			if not C.Skip(X, Z) then
				local D, SS, Side = nearest(X, Z)
				if D <= C.Half then Top[I][K], Kind[I][K] = height(D, SS, Side) end
			end
		end
	end
	local function cellTop(X, Z) -- the walkable top at (X, Z) (the floor where there is no cell)
		local I, K = math.floor((X - X0) / 4) + 1, math.floor((Z - Z0) / 4) + 1
		return Top[I] and Top[I][K] or C.FloorY
	end
	-- merge equal neighbours into rectangles (ground.lua's merge)
	local Ground = Instance.new("Model")
	Ground.Name = "Ground"
	Ground.Parent = M
	local Used, Slabs = {}, 0
	for I = 1, NX do Used[I] = {} end
	for K = 1, NZ do
		for I = 1, NX do
			local T = Top[I][K]
			if T and not Used[I][K] then
				local KD = Kind[I][K]
				local function same(II, KK) return Top[II] and Top[II][KK] == T and Kind[II][KK] == KD and not Used[II][KK] end
				local W = 1
				while I + W <= NX and same(I + W, K) and W < 40 do W += 1 end
				local D, Ok = 1, true
				while Ok and K + D <= NZ and D < 40 do
					for II = I, I + W - 1 do if not same(II, K + D) then Ok = false break end end
					if Ok then D += 1 end
				end
				for II = I, I + W - 1 do for KK = K, K + D - 1 do Used[II][KK] = true end end
				local CX, CZ = X0 + (I - 1 + W / 2) * 4, Z0 + (K - 1 + D / 2) * 4
				local Spec = PTOP[KD]
				put("Top", Vector3.new(W * 4, 1, D * 4), CFrame.new(CX, T - 0.5, CZ), Spec[1], Spec[2][Rng:NextInteger(1, #Spec[2])], Ground)
				if T - 1 > C.FloorY + 0.01 then
					put("Side", Vector3.new(W * 4, T - 1 - C.FloorY, D * 4), CFrame.new(CX, (T - 1 + C.FloorY) / 2, CZ), Enum.Material.Slate, PSIDE[Rng:NextInteger(1, #PSIDE)], Ground)
				end
				Slabs += 1
			end
		end
	end

	-- 3. markers
	local Clip = C.Clip or {}
	local LegParts = {}
	for LI = 1, #C.Legs do -- RenseiRoadPassage: one box per leg
		local A, B, E, F = math.huge, -math.huge, math.huge, -math.huge
		for I, P in ipairs(S) do
			if LegOf[I] == LI or LegOf[I + 1] == LI then
				A, B = math.min(A, P[1]), math.max(B, P[1])
				E, F = math.min(E, P[2]), math.max(F, P[2])
			end
		end
		A, B = math.max(A - C.Half - 2, Clip.MinX or -math.huge), math.min(B + C.Half + 2, Clip.MaxX or math.huge)
		E, F = math.max(E - C.Half - 2, Clip.MinZ or -math.huge), math.min(F + C.Half + 2, Clip.MaxZ or math.huge)
		if B > A and F > E then
			local P = marker("Passage", Vector3.new(B - A, 70, F - E), CFrame.new((A + B) / 2, C.RoadY + 25, (E + F) / 2), "RenseiRoadPassage")
			P:SetAttribute("Route", C.Route)
			P:SetAttribute("To", C.To)
			P:SetAttribute("RoadName", C.RoadName)
			P:SetAttribute("Leg", LI)
			LegParts[LI] = P
		end
	end
	-- RoadPoints: the centre line every 8 studs, each under the leg it belongs to, facing the way out
	for SS = 0, Len, 8 do
		local P, T = at(SS)
		local Leg = #C.Legs
		for I = 2, #S do if S[I][3] >= SS then Leg = LegOf[I] break end end
		local Box = LegParts[Leg] or LegParts[#C.Legs]
		if Box then
			local A = Instance.new("Attachment")
			A.Name = "RoadPoint"
			A:SetAttribute("S", SS) -- studs from the mouth
			A.Parent = Box
			local Q = Vector3.new(P.X, C.RoadY, P.Z)
			A.WorldCFrame = CFrame.lookAt(Q, Q + T)
		end
	end
	local Reserved = {} -- spots kept clear of trees (spawn points, cover, the arrival)
	local function reserve(Pos, R) table.insert(Reserved, {Pos, R}) end
	local function clear(Pos, R)
		for _, V in ipairs(Reserved) do
			if (Vector3.new(V[1].X, 0, V[1].Z) - Vector3.new(Pos.X, 0, Pos.Z)).Magnitude < V[2] + R then return false end
		end
		return true
	end
	local function onGround(Pos) return Vector3.new(Pos.X, cellTop(Pos.X, Pos.Z), Pos.Z) end
	local function kit(Kind, CF)
		local K = C.Kit(Kind, Rng)
		if not K then return nil end
		K:PivotTo(CF)
		Decor(K)
		K.Parent = M
		return K
	end

	-- the threshold, round the last bend, and the arrival on the road before it, facing back into the region
	local TP, TT = at(C.Threshold)
	local Th = marker("Threshold", Vector3.new(C.Half * 2 + 10, 28, 10), CFrame.lookAt(TP + Vector3.new(0, C.RoadY + 13, 0), TP + Vector3.new(0, C.RoadY + 13, 0) + TT), "RenseiRoadThreshold")
	Th:SetAttribute("Route", C.Route)
	Th:SetAttribute("To", C.To)
	local RP, RT = at(C.RoadStart)
	local Arr = marker("Arrival_RoadStart", Vector3.new(4, 1, 4), CFrame.lookAt(RP + Vector3.new(0, C.RoadY + 0.5, 0), RP + Vector3.new(0, C.RoadY + 0.5, 0) - RT), "RenseiArrival")
	Arr:SetAttribute("Point", "RoadStart")
	reserve(RP, 8)

	-- encounters: a box along the road; SpawnPoints 20 ahead and 20 behind its middle, 16 off the road on the banks,
	-- each behind kit stones (cover) between it and the road
	local Encounters = {}
	for EI, ES in ipairs(C.Encounters) do
		local P, T = at(ES)
		local E = marker("Encounter" .. EI, Vector3.new(C.Half * 2 + 8, 30, 48), CFrame.lookAt(P + Vector3.new(0, C.RoadY + 12, 0), P + Vector3.new(0, C.RoadY + 12, 0) + T), "RenseiRoadEncounter")
		E:SetAttribute("Route", C.Route)
		E:SetAttribute("Order", EI)
		table.insert(Encounters, E)
		for _, Way in ipairs({{"Out", 1}, {"In", -1}}) do
			local Q, QT = at(ES + Way[2] * 20)
			for _, Lat in ipairs({-1, 1}) do
				local N = side(QT) * Lat
				local Spot = onGround(Q + N * 16)
				local A = Instance.new("Attachment")
				A.Name = "SpawnPoint"
				A:SetAttribute("Side", Way[1])
				A.Parent = E
				A.WorldCFrame = CFrame.lookAt(Spot, Vector3.new(Q.X, Spot.Y, Q.Z)) -- facing the road
				reserve(Spot, 4)
				local Cover = onGround(Q + N * 11.5)
				kit("BankStones", CFrame.new(Cover) * CFrame.Angles(0, math.atan2(QT.X, QT.Z) + Rng:NextNumber(-0.3, 0.3), 0))
				reserve(Cover, 4)
			end
		end
	end

	-- the gate at the mouth (Task 8's arch, reused as the passage gate; no exit part now)
	if C.Gate then
		local P, T = at(C.Gate)
		local Base = Vector3.new(P.X, C.RoadY, P.Z)
		local CF = CFrame.lookAt(Base, Base + T)
		local STONE = Color3.fromRGB(141, 133, 119)
		local Gate = Instance.new("Model")
		Gate.Name = "RoadGate"
		for _, SG in ipairs({-1, 1}) do
			put("GatePillar", Vector3.new(3, 12, 3), CF * CFrame.new(SG * 8.5, 6, 0), Enum.Material.Cobblestone, STONE, Gate)
		end
		put("GateLintel", Vector3.new(20, 2.5, 3.5), CF * CFrame.new(0, 13.25, 0), Enum.Material.Cobblestone, STONE, Gate)
		Decor(Gate)
		Gate.Parent = M
		reserve(P, 12)
	end
	-- a short fence along both sides where it leaves town: kit posts every 15, two rails between
	if C.Fence and C.Post and C.Rail then
		for _, Lat in ipairs({-1, 1}) do
			local Last
			for SS = C.Fence[1], C.Fence[2], 15 do
				local P, T = at(SS)
				local Pos = P + side(T) * Lat * (VERGE - 1)
				local Y = cellTop(Pos.X, Pos.Z)
				local Post = C.Post:Clone()
				Post.CFrame = CFrame.new(Pos.X, Y + Post.Size.Y / 2, Pos.Z)
				Decor(Post)
				Post.Parent = M
				if Last then
					for _, H in ipairs({0.3, 0.7}) do
						local R = C.Rail:Clone()
						local From, To2 = Vector3.new(Last.X, Y + Post.Size.Y * H, Last.Z), Vector3.new(Post.Position.X, Y + Post.Size.Y * H, Post.Position.Z)
						R.Size = Vector3.new(R.Size.X, R.Size.Y, (To2 - From).Magnitude)
						R.CFrame = CFrame.lookAt((From + To2) / 2, To2)
						Decor(R)
						R.Parent = M
					end
				end
				Last = Post.Position
			end
		end
	end

	-- trees along both banks: cypress and oak on the open stretch; big oaks over the cutting (a tree tunnel); a dense
	-- wall of cypress round the last bend and past the threshold, so its far side can't be seen
	local Trees = 0
	local function tree(Kind, Pos)
		if C.Skip(Pos.X, Pos.Z) or not clear(Pos, Kind == "OakBig" and 6 or 3) then return end
		local D = nearest(Pos.X, Pos.Z)
		if D < (Kind == "OakBig" and 15 or 11) then return end -- off the road, also where the road bends back near
		if kit(Kind, CFrame.new(onGround(Pos)) * CFrame.Angles(0, Rng:NextNumber(0, math.pi * 2), 0)) then
			Trees += 1
			reserve(Pos, Kind == "OakBig" and 8 or 4)
		end
	end
	local SS = 10
	while SS < C.Threshold - 30 do
		local P, T = at(SS)
		for _, Lat in ipairs({-1, 1}) do
			local Big = SS > C.Cut - 10
			local Kind = Big and ((math.floor(SS / 22) + (Lat > 0 and 1 or 0)) % 2 == 0 and "OakBig" or "Cypress")
				or (Rng:NextNumber() < 0.3 and "Oak" or "Cypress")
			local D = (Kind == "OakBig" and 19 or Kind == "Oak" and 18 or 14) + Rng:NextNumber(0, 3)
			tree(Kind, P + side(T) * Lat * D + T * Rng:NextNumber(-3, 3))
		end
		SS += SS > C.Cut - 10 and 11 or Rng:NextNumber(14, 20)
	end
	for SS2 = C.Threshold - 30, Len + 8, 7 do
		local P, T = at(SS2)
		for _, Lat in ipairs({-1, 1}) do tree("Cypress", P + side(T) * Lat * (12 + Rng:NextNumber(0, 2))) end
	end
	local EP, ET = at(Len)
	for _, Off in ipairs({{6, 0, "OakBig"}, {14, -10, "Cypress"}, {14, 10, "Cypress"}, {8, -18, "Cypress"}, {8, 18, "Cypress"}, {22, 0, "Cypress"}}) do
		local Pos = EP + ET * Off[1] + side(ET) * Off[2]
		local K = kit(Off[3], CFrame.new(onGround(Pos)) * CFrame.Angles(0, Rng:NextNumber(0, math.pi * 2), 0))
		if K then Trees += 1 end
	end
	-- rocks: kit ridge stones on the cutting's high banks, bank stones scattered along the open verges
	local Rocks = 0
	for SS2 = C.Cut, Len, 36 do
		local P, T = at(SS2)
		for _, Lat in ipairs({-1, 1}) do
			local Pos = P + side(T) * Lat * (C.Half + 2)
			if not C.Skip(Pos.X, Pos.Z) and clear(Pos, 6) and kit("RidgeTerrace", CFrame.new(onGround(Pos) - Vector3.new(0, 1, 0)) * CFrame.Angles(0, math.atan2(T.X, T.Z), 0)) then Rocks += 1 end
		end
	end
	local EP2 = EP + ET * 16
	if kit("RidgeTerrace", CFrame.new(onGround(EP2) - Vector3.new(0, 1, 0)) * CFrame.Angles(0, math.atan2(ET.X, ET.Z) + math.pi / 2, 0)) then Rocks += 1 end
	for SS2 = 30, C.Cut, 34 do
		local P, T = at(SS2 + Rng:NextNumber(-6, 6))
		local Lat = Rng:NextNumber() < 0.5 and -1 or 1
		local Pos = P + side(T) * Lat * (VERGE + 2)
		if not C.Skip(Pos.X, Pos.Z) and clear(Pos, 3) and kit("BankStones", CFrame.new(onGround(Pos)) * CFrame.Angles(0, Rng:NextNumber(0, math.pi * 2), 0)) then Rocks += 1 end
	end

	M.Parent = C.Parent
	local Parts = 0
	for _, D in ipairs(M:GetDescendants()) do if D:IsA("BasePart") then Parts += 1 end end
	return M, {Length = math.floor(Len + 0.5), Threshold = C.Threshold, Slabs = Slabs, Trees = Trees, Rocks = Rocks, Parts = Parts,
		Encounters = #Encounters, ThresholdAt = Th.Position, RoadStart = Arr.Position}
end

-- ===== The papers check and the freight yard (World Plan 1 Task 9, 2026-10-23; world spec §4). The same builder is in
-- station_lindenmoor.lua and station_foundry.lua. =====
--   * StationGate: an invisible 8 x 8 x 1 part (tag RenseiStationGate; its LookVector points onto the platform) across the
--     way from the ticket hall onto the platform, between two posts, and the gate guard beside it (R6 in State blue,
--     anchored, IdleAnim NPC_CrossArms for NpcIdles; a non-combat Authority watcher). StationService runs the papers
--     check on its Touched (and again at boarding). PlatformRailing (fix round 1): a kit-fence railing round the
--     platform's back edge and ends, with an invisible wall over it, so the gate is the way on.
--   * FreightYard, on the far side of the tracks by the baggage car's open side door (the stowaway route): crates, a
--     fence along the tracks with one gap at the door (crate steps up to it), the kit lamp over the door, a yard
--     watchman (a RenseiWatcher: Witness sight, Authority, Carrier; IdleAnim NPC_HandInPocket) looking at the gap, and
--     the yard's zone (tag RenseiFreightYard; StationService raises State Heat when the watchman notices someone in it).
--     Cover crates stand between him and the gap; the yard behind him is his blind side.
--     Positions are measured from the platform train's baggage car: Along = towards the locomotive, Out = away from the
--     platform (the side the StowZone is on; the side door opens at Out 5.7, Along -2.7..2.7).
-- Every number is a PROPOSAL unless marked measured.
local T9_SKIN, T9_COAT, T9_TROUSERS = Color3.fromRGB(234, 190, 152), Color3.fromRGB(44, 62, 104), Color3.fromRGB(30, 36, 54) -- the clerk's State blue
local T9_CRATE = Color3.fromRGB(90, 58, 38) -- measured: the baggage car's crates (Wood)
local T9_LAMP = { -- measured: ServerStorage.LindenmoorKit.LampPost.LampPost_0, from its foot; the lamp hangs towards +Z
	{"Post", 0.8, 12, 0.8, 0, 6, 0, "Wood", 90, 64, 48},
	{"Base", 1.6, 1.2, 1.6, 0, 0.6, 0, "Cobblestone", 141, 133, 119},
	{"Arm", 0.4, 0.4, 2.7, 0, 11.6, 1.15, "Metal", 46, 44, 41},
	{"Cap", 1.5, 0.3, 1.5, 0, 11.3, 2.3, "Metal", 46, 44, 41},
	{"Glow", 0.9, 1.2, 0.9, 0, 10.4, 2.3, "Neon", 255, 179, 92},
	{"Bar0", 0.15, 1.6, 0.15, -0.6, 10.4, 1.7, "Metal", 46, 44, 41},
	{"Bar1", 0.15, 1.6, 0.15, 0.6, 10.4, 1.7, "Metal", 46, 44, 41},
	{"Bar2", 0.15, 1.6, 0.15, -0.6, 10.4, 2.9, "Metal", 46, 44, 41},
	{"Bar3", 0.15, 1.6, 0.15, 0.6, 10.4, 2.9, "Metal", 46, 44, 41},
}

local function T9Part(Parent, Name, Size, CF, Mat, Color)
	local P = Instance.new("Part")
	P.Name, P.Size, P.CFrame, P.Material, P.Color = Name, Size, CF, Mat, Color
	P.Anchored = true
	P.TopSurface, P.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	P.Parent = Parent
	return P
end

-- an R6 in the State's uniform (as the ticket clerk), anchored, standing with its feet at Feet
local function T9Npc(Parent, Name, Display, Feet, Attrs)
	local D = Instance.new("HumanoidDescription")
	D.HeadColor, D.TorsoColor, D.LeftArmColor, D.RightArmColor = T9_SKIN, T9_COAT, T9_COAT, T9_COAT
	D.LeftLegColor, D.RightLegColor = T9_TROUSERS, T9_TROUSERS
	local N = game:GetService("Players"):CreateHumanoidModelFromDescription(D, Enum.HumanoidRigType.R6)
	N.Name = Name
	local A = N:FindFirstChild("Animate")
	if A then A:Destroy() end
	for _, P in ipairs(N:GetDescendants()) do
		if P:IsA("BasePart") then P.Anchored = true end
	end
	N.PrimaryPart = N:FindFirstChild("HumanoidRootPart")
	N.Humanoid.DisplayName = Display
	N.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	for K, V in pairs(Attrs or {}) do N:SetAttribute(K, V) end
	N:PivotTo(Feet * CFrame.new(0, 3, 0)) -- an R6's root is 3 above its feet
	N.Parent = Parent
	return N
end

-- C = {Parent, Gate = CFrame (the gate's centre, LookVector onto the platform), PostFloor, PostTop (y of the posts' foot
--      and top), Guard = CFrame (the guard's feet, facing), Sign = text over the posts or nil, Route = the line the bribe
--      is priced on (optional; StationService defaults to the cheapest line from here)}
local function PapersGate(C)
	local M = Instance.new("Model")
	M.Name = "StationGate"
	local G = T9Part(M, "StationGate", Vector3.new(8, 8, 1), C.Gate, Enum.Material.SmoothPlastic, Color3.new(1, 1, 1)) -- brief: 8 x 8 x 1
	G.Transparency, G.CanCollide, G.CanQuery, G.CanTouch, G.CastShadow = 1, false, false, true, false
	if C.Route then G:SetAttribute("Route", C.Route) end
	CS:AddTag(G, "RenseiStationGate")
	for _, S in ipairs({-1, 1}) do
		local At = (C.Gate * CFrame.new(S * 4.4, 0, 0)).Position
		Decor(T9Part(M, "GatePost", Vector3.new(0.6, C.PostTop - C.PostFloor, 0.6), CFrame.new(At.X, (C.PostTop + C.PostFloor) / 2, At.Z), Enum.Material.Metal, Color3.fromRGB(58, 56, 53)))
	end
	if C.Sign then -- a board across the post tops, lettered like the booth's sign, on both faces
		local Pos = Vector3.new(C.Gate.Position.X, C.PostTop + 0.6, C.Gate.Position.Z)
		local B = Decor(T9Part(M, "GateSign", Vector3.new(9.4, 1.2, 0.3), CFrame.lookAt(Pos, Pos - C.Gate.LookVector), Enum.Material.Wood, Color3.fromRGB(40, 34, 30)))
		for _, Face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
			local SG = Instance.new("SurfaceGui")
			SG.Face, SG.PixelsPerStud, SG.SizingMode = Face, 50, Enum.SurfaceGuiSizingMode.PixelsPerStud
			SG.Parent = B
			local Tx = Instance.new("TextLabel")
			Tx.Size, Tx.BackgroundTransparency, Tx.Text, Tx.TextScaled = UDim2.fromScale(1, 1), 1, C.Sign, true
			Tx.Font, Tx.TextColor3 = Enum.Font.Antique, Color3.fromRGB(214, 176, 92)
			Tx.Parent = SG
		end
	end
	local Guard = T9Npc(M, "GateGuard", "Gate guard", C.Guard, { -- a non-combat Authority watcher (fix round 1 ruling)
		IdleAnim = "NPC_CrossArms", WatcherType = "Witness", Faction = "Authority", Carrier = true,
	})
	CS:AddTag(Guard, "RenseiWatcher")
	M.Parent = C.Parent
	return M, G
end

-- C = {Parent, Car = the platform train's BaggageCar_Main, Ground(X, Z) -> the ground's top y there, Post, Rail (fence kit
--      pieces, cloned)}
local function FreightYard(C)
	local M = Instance.new("Model")
	M.Name = "FreightYard"
	local Base = C.Car:GetPivot() -- measured: X along the car (towards the locomotive), Z across it
	local Stow = C.Car:FindFirstChild("StowZone", true)
	assert(Stow, "the baggage car has no StowZone")
	local Side = Base:PointToObjectSpace(Stow.Position).Z >= 0 and 1 or -1 -- the side door's side
	local function At(Along, Out)
		local P = (Base * CFrame.new(Along, 0, Side * Out)).Position
		return Vector3.new(P.X, C.Ground(P.X, P.Z), P.Z)
	end
	local OutDir = (Base:VectorToWorldSpace(Vector3.new(0, 0, Side)) * Vector3.new(1, 0, 1)).Unit
	local Turn = CFrame.new(Vector3.zero, Base:VectorToWorldSpace(Vector3.new(1, 0, 0)) * Vector3.new(1, 0, 1)) -- level, along the car
	local function Crate(Along, Out, Size, Lift)
		local G = At(Along, Out)
		return T9Part(M, "Crate", Vector3.new(Size, Size, Size), CFrame.new(G + Vector3.new(0, (Lift or 0) + Size / 2, 0)) * Turn, Enum.Material.Wood, T9_CRATE)
	end
	-- the fence along the tracks (Out 8.4: clear of the car's side, its door rail at 6.15), kit posts every 7.5 at most,
	-- two rails between; one gap at the door (Along -3.5..3.5)
	local function Fence(A, B)
		local N = math.max(1, math.ceil(math.abs(B - A) / 7.5))
		local Last
		for I = 0, N do
			local G = At(A + (B - A) * I / N, 8.4)
			local Post = C.Post:Clone()
			Post.CFrame = CFrame.new(G + Vector3.new(0, Post.Size.Y / 2, 0))
			Post.Parent = M
			if Last then
				for _, H in ipairs({0.3, 0.7}) do
					local R = C.Rail:Clone()
					local From, To = Last + Vector3.new(0, Post.Size.Y * H, 0), G + Vector3.new(0, Post.Size.Y * H, 0)
					R.Size = Vector3.new(R.Size.X, R.Size.Y, (To - From).Magnitude)
					R.CFrame = CFrame.lookAt((From + To) / 2, To)
					R.Parent = M
				end
			end
			Last = G
		end
	end
	Fence(3.5, 63) -- towards the locomotive
	Fence(-3.5, -25) -- the other way
	-- crate steps up to the door (its sill is about 5.4 above the ground: measured, Ye), in the gap
	Crate(0, 9.6, 3)
	Crate(0.4, 12.2, 2.2)
	-- cover between the watchman and the gap, a hiding place by the fence, and stacks along the yard
	Crate(7.5, 12, 3)
	Crate(10.5, 12.2, 3)
	Crate(9, 12.1, 2.6, 3)
	Crate(14, 10, 2.6)
	Crate(26, 12, 3)
	Crate(27.6, 15.2, 2.4)
	Crate(38, 10, 3)
	Crate(38.2, 10.1, 2.4, 3)
	Crate(50, 13, 3)
	Crate(58, 10, 2.8)
	-- the lamp over the door (the kit's LampPost, hanging towards the tracks): at night the door is lit
	local Foot = At(1, 15)
	local LampCF = CFrame.lookAt(Foot, Foot + OutDir) -- +Z (where the lamp hangs) points back at the door
	local Lamp = Instance.new("Model")
	Lamp.Name = "YardLamp"
	for _, D in ipairs(T9_LAMP) do
		local P = T9Part(Lamp, D[1], Vector3.new(D[2], D[3], D[4]), LampCF * CFrame.new(D[5], D[6], D[7]), Enum.Material[D[8]], Color3.fromRGB(D[9], D[10], D[11]))
		if D[1] == "Glow" then
			local L = Instance.new("PointLight") -- measured: the kit lamp's light
			L.Range, L.Brightness, L.Color = 22, 1.2, Color3.fromRGB(255, 179, 92)
			L.Parent = P
		end
	end
	Decor(Lamp)
	Lamp.Parent = M
	-- the yard watchman, looking at the gap
	local Stand, Look = At(18, 17), At(0, 8)
	local W = T9Npc(M, "YardWatchman", "Yard watchman", CFrame.lookAt(Stand, Vector3.new(Look.X, Stand.Y, Look.Z)), {
		IdleAnim = "NPC_HandInPocket", WatcherType = "Witness", Faction = "Authority", Carrier = true,
	})
	CS:AddTag(W, "RenseiWatcher")
	-- the yard: Along -22..65, Out 6..20 (the flat strip by the tracks, not the hillside behind it: Ye's ground starts to
	-- climb at about Out 19, measured), from 7 below to 13 above the rail top
	local Zone = T9Part(M, "FreightYardZone", Vector3.new(87, 20, 14), Base * CFrame.new(21.5, 3, Side * 13), Enum.Material.SmoothPlastic, Color3.new(1, 1, 1))
	Zone.Transparency, Zone.CanCollide, Zone.CanQuery, Zone.CanTouch, Zone.CastShadow = 1, false, false, false, false
	CS:AddTag(Zone, "RenseiFreightYard")
	for _, D in ipairs(M:GetDescendants()) do -- decor: no touches (queries stay on, so the crates block sight)
		if D:IsA("BasePart") and D ~= Zone and not D:IsDescendantOf(W) then D.CanTouch = false end
	end
	M.Parent = C.Parent
	return M
end

-- (fix round 1) the platform's railing: kit fence posts and rails along the back edge and across the ends, with an
-- invisible wall over each run (to WallTop) so it can't be jumped; it leaves the gate's opening free. The track side of
-- the platform (the train doors) is never fenced. C = {Parent, Runs = {{From, To}, ...} (Vector3s, y ignored),
-- Ground(X, Z), Post, Rail, WallTop}
local function Railing(C)
	local M = Instance.new("Model")
	M.Name = "PlatformRailing"
	for _, Run in ipairs(C.Runs) do
		local A, B = Run[1], Run[2]
		local N = math.max(1, math.ceil((B - A).Magnitude / 7.5))
		local Last
		for I = 0, N do
			local X = A:Lerp(B, I / N)
			local G = Vector3.new(X.X, C.Ground(X.X, X.Z), X.Z)
			local Post = C.Post:Clone()
			Post.CFrame = CFrame.new(G + Vector3.new(0, Post.Size.Y / 2, 0))
			Post.CanTouch = false
			Post.Parent = M
			if Last then
				for _, H in ipairs({0.3, 0.7}) do
					local R = C.Rail:Clone()
					local From, To = Last + Vector3.new(0, Post.Size.Y * H, 0), G + Vector3.new(0, Post.Size.Y * H, 0)
					R.Size = Vector3.new(R.Size.X, R.Size.Y, (To - From).Magnitude)
					R.CFrame = CFrame.lookAt((From + To) / 2, To)
					R.CanTouch = false
					R.Parent = M
				end
			end
			Last = G
		end
		local Low = math.min(C.Ground(A.X, A.Z), C.Ground(B.X, B.Z))
		local Mid = (A + B) / 2
		local W = T9Part(M, "RailingWall", Vector3.new(0.4, C.WallTop - Low, (B - A).Magnitude),
			CFrame.lookAt(Vector3.new(Mid.X, (C.WallTop + Low) / 2, Mid.Z), Vector3.new(B.X, (C.WallTop + Low) / 2, B.Z)),
			Enum.Material.SmoothPlastic, Color3.new(1, 1, 1))
		W.Transparency, W.CanQuery, W.CanTouch, W.CastShadow = 1, false, false, false -- sight passes the railing
	end
	M.Parent = C.Parent
	return M
end

return {
	part = part, arrival = arrival, checkKit = checkKit, blockRide = blockRide, lay = lay, booth = booth, board = board,
	roadGate = roadGate, kitPart = kitPart, kitPiece = kitPiece, Decor = Decor, Passage = Passage, T9Part = T9Part,
	T9Npc = T9Npc, PapersGate = PapersGate, FreightYard = FreightYard, Railing = Railing,
	ORDER = ORDER, LEN = LEN, KITDATA = KITDATA, PTOP = PTOP, PSIDE = PSIDE, ROAD_HALF = ROAD_HALF, VERGE = VERGE,
	T9_SKIN = T9_SKIN, T9_COAT = T9_COAT, T9_TROUSERS = T9_TROUSERS, T9_CRATE = T9_CRATE, T9_LAMP = T9_LAMP,
}

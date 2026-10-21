-- Foundry Yard placeholder (World Plan 1 Task 4, 2026-10-20; station added by Task 6, 2026-10-21): run in the Foundry
-- Yard place (109591196441030), Edit. Needs ServerStorage.TrainKit (copy it from Ye first; the script stops if missing).
-- The same World skeleton as Ye (Live, Visuals, Map, EnemySpawns, NPCs), a part ground, a cobbled platform with
-- rails, two RenseiArrival points (Platform, SouthGate) with a gate arch, a spawn and the "Foundry Yard" area, and the
-- station (Task 6): PlatformTrain + RideTrain (Route = "LindenmoorFoundry"), a ticket booth (RenseiTicketClerk,
-- Station = "Foundry") with an R6 clerk, and a DepartureBoard. Server code: StationService (in RenseiServer).
-- Task 8 (2026-10-21): the south road: a dirt road out through the gate, a RoadGate arch over it with RoadExit (tag
-- RenseiRoadExit, Route = "RoadLindenmoorFoundry", Arrive = "NorthGate"; RoadService gives it a prompt), and
-- AmbushArena (tag RenseiAmbushArena), an invisible 60 x 1 x 60 marker outside the gate, ringed by fence posts and
-- stones (walking out past them is fleeing), on more ground south of the gate. Server code: RoadService (RenseiServer).
-- The template Baseplate and SpawnLocation go to ServerStorage.RenseiBackups["Pre-WorldPlan1_2026-10-20"].
-- Re-runnable: rebuilds World.Map.Foundry (all Foundry content comes from this script). The real region is a later
-- plan; every size is a PROPOSAL.
assert(game.PlaceId == 109591196441030, "station_foundry.lua is for Foundry Yard (109591196441030) only")
local CS = game:GetService("CollectionService")
local SS = game:GetService("ServerStorage")
local Kit = SS:FindFirstChild("TrainKit")
assert(Kit, "ServerStorage.TrainKit is missing in Foundry Yard: copy it from Ye (ServerStorage.TrainKit) first, then re-run")
for _, N in ipairs({"Locomotive_Main", "Tender_Main", "BaggageCar_Main", "ThirdClass_Main", "DiningCar_Main", "SecondClass_Main", "CabinCar_Main"}) do
	assert(Kit:FindFirstChild(N), "ServerStorage.TrainKit." .. N .. " is missing")
end
local Backups = SS:FindFirstChild("RenseiBackups") or Instance.new("Folder")
Backups.Name = "RenseiBackups"
Backups.Parent = SS
local B = Backups:FindFirstChild("Pre-WorldPlan1_2026-10-20") or Instance.new("Folder")
B.Name = "Pre-WorldPlan1_2026-10-20"
B.Parent = Backups
for _, n in ipairs({"Baseplate", "SpawnLocation"}) do
	local o = workspace:FindFirstChild(n)
	if o then o.Parent = B end
end
local World = workspace:FindFirstChild("World") or Instance.new("Folder")
World.Name = "World"
World.Parent = workspace
for _, n in ipairs({"Live", "Visuals", "Map", "EnemySpawns", "NPCs"}) do
	if not World:FindFirstChild(n) then
		local f = Instance.new("Folder")
		f.Name = n
		f.Parent = World
	end
end
local old = World.Map:FindFirstChild("Foundry")
if old then old:Destroy() end
local F = Instance.new("Model")
F.Name = "Foundry"
local function part(name, size, cf, mat, color, parent)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Material, p.Color = name, size, cf, mat, color
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent or F
	return p
end

-- Track and platform (Task 6). The track centre is 6 from the platform edge, as in Ye (the coaches' steps reach 7).
local TRACK_X = -12 -- PROPOSAL (Task 4 had -10: only 4 from the platform edge, too close for the coaches)
local RAIL_TOP = 4.6 -- rail centre 4.3 + half its 0.6 height; the kit's pivot is at the wheel bottoms
local NOSE_Z = 240 -- PROPOSAL: the locomotive's nose, 6 short of the buffer stop; the 440-long train ends at z -200
local PLAT_Z = -35 -- PROPOSAL: the 340-long platform runs z -205..135, under the five cars behind the tender
part("Ground", Vector3.new(400, 4, 520), CFrame.new(0, 2, 0), Enum.Material.Grass, Color3.fromRGB(82, 106, 54)) -- 520 on Z (was 400) for the 500-long track
part("Platform", Vector3.new(12, 2.4, 340), CFrame.new(0, 5.2, PLAT_Z), Enum.Material.Cobblestone, Color3.fromRGB(122, 118, 108))
for _, x in ipairs({TRACK_X - 2.6, TRACK_X + 2.6}) do
	part("Rail", Vector3.new(0.5, 0.6, 500), CFrame.new(x, 4.3, 0), Enum.Material.Metal, Color3.fromRGB(58, 56, 53))
end
for _, z in ipairs({-251, 251}) do
	part("BufferStop", Vector3.new(7, 2.6, 1.6), CFrame.new(TRACK_X, 5.6, z), Enum.Material.Wood, Color3.fromRGB(110, 40, 32))
end
local function arrival(point, pos)
	local a = part("Arrival_" .. point, Vector3.new(4, 1, 4), CFrame.new(pos), Enum.Material.SmoothPlastic, Color3.new(1, 1, 1))
	a.Transparency, a.CanCollide, a.CanQuery, a.CanTouch = 1, false, false, false
	a:SetAttribute("Point", point)
	CS:AddTag(a, "RenseiArrival")
end
arrival("Platform", Vector3.new(0, 7, 0))
arrival("SouthGate", Vector3.new(150, 5, 190))
for _, x in ipairs({144, 156}) do
	part("GatePillar", Vector3.new(3, 12, 3), CFrame.new(x, 10, 190), Enum.Material.Cobblestone, Color3.fromRGB(141, 133, 119))
end
part("GateLintel", Vector3.new(15, 2.5, 3.5), CFrame.new(150, 17, 190), Enum.Material.Cobblestone, Color3.fromRGB(141, 133, 119))
local sp = Instance.new("SpawnLocation")
sp.Name, sp.Size, sp.CFrame, sp.Anchored, sp.Neutral, sp.Duration = "Spawn", Vector3.new(8, 1, 8), CFrame.new(0, 6.9, 20), true, true, 0
sp.Transparency, sp.CanCollide = 1, false
sp.Parent = F
local area = part("Foundry YardArea", Vector3.new(400, 120, 400), CFrame.new(0, 60, 0), Enum.Material.SmoothPlastic, Color3.new(1, 1, 1))
area.Transparency, area.CanCollide, area.CanQuery, area.CanTouch = 1, false, false, false
area:SetAttribute("AreaName", "Foundry Yard")
CS:AddTag(area, "RenseiArea")

-- ===== The station (World Plan 1 Task 6). Same layout code as station_lindenmoor.lua. =====
local St = Instance.new("Model")
St.Name = "Station"
St.Parent = F
local ORDER = {"Locomotive_Main", "Tender_Main", "BaggageCar_Main", "ThirdClass_Main", "DiningCar_Main", "SecondClass_Main", "CabinCar_Main"}
local LEN = {Locomotive_Main = 72, Tender_Main = 30} -- the coaches are 64; 3 between cars (the kit's spacing)

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
end

local function lay(Name, Origin, Route, Tag)
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
	T.Parent = St
	return T
end
lay("PlatformTrain", Vector3.new(TRACK_X, RAIL_TOP, NOSE_Z), "LindenmoorFoundry", "RenseiPlatformTrain")
lay("RideTrain", Vector3.new(0, 400, -1600), "LindenmoorFoundry", "RenseiRideTrain")

local function booth(CF, Station)
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
	M.Parent = St
	return M
end
-- PROPOSAL: on the platform's back half (x 2..6, top 6.4), facing the track (-X)
booth(CFrame.lookAt(Vector3.new(2.5, 6.4, 40), Vector3.new(1.5, 6.4, 40)), "Foundry")

local function board(Pos, Facing)
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
	M.Parent = St
	return M
end
board(Vector3.new(5.6, 6.4 + 8, 70), Vector3.new(-1, 0, 0)) -- PROPOSAL: at the platform's back edge, facing the track; bottom 12.4

-- ===== The south road (World Plan 1 Task 8). Same RoadGate as station_lindenmoor.lua. =====
-- The brief puts the exit at the gate itself (150, 5, 190), which is also the SouthGate arrival point: someone who
-- has just arrived would stand in the exit's prompt. The exit moved 32 out along the road (prompt reach 12).
local EXIT_Z = 222 -- PROPOSAL
part("GroundSouth", Vector3.new(400, 4, 120), CFrame.new(0, 2, 320), Enum.Material.Grass, Color3.fromRGB(82, 106, 54)) -- PROPOSAL (fix round 1): room outside the gate for the arena and a flee
part("Road", Vector3.new(12, 0.2, 196), CFrame.new(150, 4.1, 282), Enum.Material.Ground, Color3.fromRGB(110, 92, 70)) -- PROPOSAL: gate (z 184) to the ground's edge (z 380)
local function roadGate(Pos, Out, Route, Arrive) -- Pos: on the road surface; Out: the way the road leaves
	local M = Instance.new("Model")
	M.Name = "RoadGate"
	local CF = CFrame.lookAt(Pos, Pos + Out)
	local STONE = Color3.fromRGB(141, 133, 119)
	for _, S in ipairs({-1, 1}) do -- PROPOSAL sizes, clear of the 12-wide road
		part("GatePillar", Vector3.new(3, 12, 3), CF * CFrame.new(S * 8.5, 6, 0), Enum.Material.Cobblestone, STONE, M)
	end
	part("GateLintel", Vector3.new(20, 2.5, 3.5), CF * CFrame.new(0, 13.25, 0), Enum.Material.Cobblestone, STONE, M)
	local E = part("RoadExit", Vector3.new(6, 8, 2), CF * CFrame.new(0, 4, 0), Enum.Material.SmoothPlastic, Color3.new(1, 1, 1), M) -- brief size
	E.Transparency, E.CanCollide, E.CanQuery, E.CanTouch, E.CastShadow = 1, false, false, false, false
	E:SetAttribute("Route", Route)
	E:SetAttribute("Arrive", Arrive)
	CS:AddTag(E, "RenseiRoadExit")
	M.Parent = F
	return E
end
roadGate(Vector3.new(150, 4.2, EXIT_Z), Vector3.new(0, 0, 1), "RoadLindenmoorFoundry", "NorthGate")
-- the ambush arena (fix round 1: outside the town gate, away from the SouthGate arrival at (150, 190)): x 50..110,
-- z 220..280, its bottom on the ground (top 4); 34 from the road, 50 from the arrival, with room around it to flee
local arena = part("AmbushArena", Vector3.new(60, 1, 60), CFrame.new(80, 4.5, 250), Enum.Material.SmoothPlastic, Color3.new(1, 1, 1)) -- PROPOSAL position
arena.Transparency, arena.CanCollide, arena.CanQuery, arena.CanTouch, arena.CastShadow = 1, false, false, false, false
CS:AddTag(arena, "RenseiAmbushArena")
-- its edge, made visible: this placeholder place has no village kit, so the posts copy Lindenmoor's kit FencePost
-- (0.5 x 4.47 x 0.5, Wood, measured in Ye) and the corners get rock piles in the gate's stone colour
local ring = Instance.new("Model")
ring.Name = "AmbushRing"
local POST_GAP = 7.5 -- PROPOSAL: studs between posts (an R6 is 4 wide, so there is always a way out)
for side = 0, 3 do
	for i = 0, 7 do
		local along = -30 + (i + 0.5) * POST_GAP -- half a gap in from each corner: the middle of each side is open
		local x, z = along, -30
		if side == 1 then x, z = 30, along elseif side == 2 then x, z = -along, 30 elseif side == 3 then x, z = -30, -along end
		part("RingPost", Vector3.new(0.5, 4.47, 0.5), CFrame.new(80 + x, 4 + 2.235, 250 + z), Enum.Material.Wood, Color3.fromRGB(78, 56, 40), ring)
	end
end
for _, c in ipairs({{-1, -1}, {1, -1}, {1, 1}, {-1, 1}}) do
	part("RingStone", Vector3.new(5, 3, 4), CFrame.new(80 + c[1] * 33, 5.3, 250 + c[2] * 33) * CFrame.Angles(0, math.rad(25 * c[1]), 0), Enum.Material.Rock, Color3.fromRGB(111, 117, 102), ring)
end
ring.Parent = F

F.Parent = World.Map
return "foundry placeholder + station + south road built; template baseplate + spawn backed up"

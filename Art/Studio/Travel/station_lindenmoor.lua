-- Lindenmoor station (World Plan 1 Task 6, 2026-10-21): run in Ye (106992859583940), Edit. Re-runnable.
-- Builds, in World.Map.Lindenmoor.Station (local origin O = (0, 4, -650), the same as the Lindenmoor kit):
--   * Platform + PlatformEdge extended along the track (the 90-long originals go to the backup folder);
--   * PlatformTrain (tag RenseiPlatformTrain) and RideTrain (tag RenseiRideTrain), Route = "LindenmoorFoundry",
--     cloned car by car from ServerStorage.TrainKit; nose north (+Z), each car turned so its +X points to +Z;
--   * TicketBooth: a counter part TicketClerk (tag RenseiTicketClerk, Station = "Lindenmoor") and an R6 clerk in
--     State blue, beside the station house;
--   * DepartureBoard (tag RenseiDepartureBoard; TravelClient draws the times on it).
--   * (Task 8) RoadGate: a stone arch over the north road with RoadExit (tag RenseiRoadExit, Route =
--     "RoadLindenmoorFoundry", Arrive = "SouthGate"; RoadService gives it a prompt), and AmbushArena (tag
--     RenseiAmbushArena), an invisible 60 x 1 x 60 marker on the flat ground west of the north road. Both sit
--     directly in World.Map.Lindenmoor, on the ground found by a ray down. (Fix round 1) AmbushRing: the village's
--     fence posts and creek stones around the arena's edge, since walking out past it is fleeing.
-- Server code: StationService. Every number here is a PROPOSAL unless it was measured in Ye (marked "measured").
assert(game.PlaceId == 106992859583940, "station_lindenmoor.lua is for Ye (106992859583940) only")
local CS = game:GetService("CollectionService")
local SS = game:GetService("ServerStorage")
local Kit = SS:FindFirstChild("TrainKit")
assert(Kit, "ServerStorage.TrainKit is missing (World Plan 1 Task 2 imports it)")
local Backups = SS:FindFirstChild("RenseiBackups") or Instance.new("Folder")
Backups.Name = "RenseiBackups"
Backups.Parent = SS
local B = Backups:FindFirstChild("Pre-Stations_2026-10-21") or Instance.new("Folder")
B.Name = "Pre-Stations_2026-10-21"
B.Parent = Backups

local O = Vector3.new(0, 4, -650) -- measured: the Lindenmoor kit origin
local L = workspace.World.Map.Lindenmoor
local St = L.Station
local GEN = "station_lindenmoor" -- parts this script made carry Generated = GEN and are rebuilt on a re-run

local TRACK_X = -270 -- measured: the rails' centre line (rails at -272.6 / -267.4)
local RAIL_TOP = 5.2 -- measured: rail centre 4.9 + half its 0.6 height; the kit's pivot is at the wheel bottoms
local NOSE_Z = 275 -- PROPOSAL: the locomotive's nose, 5 short of the north buffer stop (its face is at 280.2);
                   -- the 440-long train then ends at -165, inside the rails (they end at -240)
local PLAT_S, PLAT_N = -170, 104 -- PROPOSAL: the platform runs under the five cars behind the tender and stops
                                 -- short of the creek (the trestle starts at about z 108)

local ORDER = {"Locomotive_Main", "Tender_Main", "BaggageCar_Main", "ThirdClass_Main", "DiningCar_Main", "SecondClass_Main", "CabinCar_Main"}
local LEN = {Locomotive_Main = 72, Tender_Main = 30} -- the coaches are 64; 3 between cars (the kit's spacing)

local function mark(I)
	I:SetAttribute("Generated", GEN)
	return I
end

-- remove what an earlier run made; anything else with that name is moved to the backup folder
local function clear(Parent, Name)
	local Old = Parent:FindFirstChild(Name)
	while Old do
		if Old:GetAttribute("Generated") == GEN then
			Old:Destroy()
		else
			Old.Name = Name .. "_Lindenmoor"
			Old.Parent = B
		end
		Old = Parent:FindFirstChild(Name)
	end
end

local function part(Parent, Name, Size, CF, Mat, Color)
	local P = Instance.new("Part")
	P.Name, P.Size, P.CFrame, P.Material, P.Color = Name, Size, CF, Mat, Color
	P.Anchored = true
	P.TopSurface, P.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	P.Parent = Parent
	return P
end

-- invisible walls in the ride train's open side doors and open end gangways, so nobody steps off at 400 studs
local function blockRide(T)
	for _, Z in ipairs(T:GetDescendants()) do
		if Z:IsA("BasePart") and Z.Name:find("BoardZone") then
			for _, S in ipairs({-1, 1}) do
				local W = part(T, "RideBlock", Vector3.new(Z.Size.X + 0.4, Z.Size.Y + 1, 0.4), Z.CFrame * CFrame.new(0, 0.5, S * 5.95), Enum.Material.SmoothPlastic, Color3.new(1, 1, 1)) -- PROPOSAL: in the side opening (jambs at 5.7, grabs at 6.15)
				W.Transparency, W.CanQuery, W.CanTouch, W.CastShadow = 1, false, false, false
			end
		end
	end
	for _, E in ipairs({{"BaggageCar_Main", 1}, {"CabinCar_Main", -1}}) do -- the open gangways at the ends of the coaches
		local Car = T:FindFirstChild(E[1])
		if Car then
			local W = part(T, "RideBlock", Vector3.new(0.4, 10, 7), Car:GetPivot() * CFrame.new(E[2] * 33.3, 8.5, 0), Enum.Material.SmoothPlastic, Color3.new(1, 1, 1)) -- PROPOSAL
			W.Transparency, W.CanQuery, W.CanTouch, W.CastShadow = 1, false, false, false
		end
	end
end

local function lay(Name, Origin, Route, Tag)
	clear(St, Name)
	local T = mark(Instance.new("Model"))
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

-- 1. platform: extend it along the track (top stays at the measured 6.5)
local Plat = St:FindFirstChild("Platform")
local PLAT_LEN, PLAT_Z = PLAT_N - PLAT_S, (PLAT_N + PLAT_S) / 2
if Plat and math.abs(Plat.Size.Z - PLAT_LEN) > 0.01 then
	local New = Plat:Clone()
	New.Size = Vector3.new(Plat.Size.X, 3.5, PLAT_LEN) -- PROPOSAL: 1 deeper, so it meets the lower ground at z -105..-135
	New.CFrame = CFrame.new(O + Vector3.new(-259, 6.5 - 3.5 / 2, PLAT_Z))
	Plat.Name = "Platform_Lindenmoor"
	Plat.Parent = B
	New.Parent = St
end
local Edge = St:FindFirstChild("PlatformEdge")
if Edge and math.abs(Edge.Size.Z - PLAT_LEN) > 0.01 then
	local New = Edge:Clone()
	New.Size = Vector3.new(Edge.Size.X, Edge.Size.Y, PLAT_LEN)
	New.CFrame = CFrame.new(O + Vector3.new(-263.7, 6.6, PLAT_Z))
	Edge.Name = "PlatformEdge_Lindenmoor"
	Edge.Parent = B
	New.Parent = St
end

-- 2-3. the trains
lay("PlatformTrain", O + Vector3.new(TRACK_X, RAIL_TOP, NOSE_Z), "LindenmoorFoundry", "RenseiPlatformTrain")
lay("RideTrain", O + Vector3.new(0, 400, -1600), "LindenmoorFoundry", "RenseiRideTrain")

-- 4. ticket booth: against the station house's south wall (the house is a solid block at x -250..-236, z 14..34,
--    so the brief's (-245, 7.5, 18) would be inside it), facing the platform ramp at z 0
local function booth(Parent, CF, Station)
	clear(Parent, "TicketBooth")
	local M = mark(Instance.new("Model"))
	M.Name = "TicketBooth"
	local WOOD, TRIM = Color3.fromRGB(122, 90, 62), Color3.fromRGB(86, 62, 44)
	local Clerk = part(M, "TicketClerk", Vector3.new(6, 3, 1.2), CF * CFrame.new(0, 1.5, 0), Enum.Material.WoodPlanks, WOOD)
	Clerk:SetAttribute("Station", Station)
	CS:AddTag(Clerk, "RenseiTicketClerk")
	part(M, "BoothBack", Vector3.new(6, 7.5, 0.3), CF * CFrame.new(0, 3.75, 3.2), Enum.Material.WoodPlanks, TRIM)
	for _, S in ipairs({-1, 1}) do
		part(M, "BoothSide", Vector3.new(0.3, 7.5, 3.8), CF * CFrame.new(S * 3.15, 3.75, 1.45), Enum.Material.WoodPlanks, TRIM)
	end
	part(M, "BoothRoof", Vector3.new(7, 0.4, 4.8), CF * CFrame.new(0, 7.7, 1.2), Enum.Material.WoodPlanks, TRIM)
	local Sign = part(M, "BoothSign", Vector3.new(6, 1.2, 0.3), CF * CFrame.new(0, 6.9, -0.1), Enum.Material.Wood, Color3.fromRGB(40, 34, 30))
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
booth(St, CFrame.new(O + Vector3.new(-245, 4, 9.5)), "Lindenmoor") -- LookVector -Z: the clerk faces south, to the ramp

-- departure board: on two posts at the platform's back edge, north of the canopy, facing the track
local function board(Parent, Pos, Facing)
	clear(Parent, "DepartureBoardStand")
	local M = mark(Instance.new("Model"))
	M.Name = "DepartureBoardStand"
	local CF = CFrame.lookAt(Pos, Pos + Facing)
	local Board = part(M, "DepartureBoard", Vector3.new(8, 4, 0.4), CF, Enum.Material.Wood, Color3.fromRGB(40, 34, 30))
	CS:AddTag(Board, "RenseiDepartureBoard")
	local Foot = Pos.Y - 2 - 6 -- the posts go from the board's bottom down to the platform top (8 below the centre)
	for _, S in ipairs({-1, 1}) do
		local At = (CF * CFrame.new(S * 3.6, 0, 0.35)).Position
		part(M, "BoardPost", Vector3.new(0.5, (Pos.Y + 2) - Foot, 0.5), CFrame.new(At.X, (Pos.Y + 2 + Foot) / 2, At.Z), Enum.Material.Metal, Color3.fromRGB(58, 56, 53))
	end
	M.Parent = Parent
	return M
end
board(St, O + Vector3.new(-254.8, 6.5 + 8, 30), Vector3.new(-1, 0, 0)) -- PROPOSAL: bottom 12.5, clear of heads

-- 5. the north road (World Plan 1 Task 8): the road exit under a stone arch, and the ambush arena.
--    The brief's exit (local z 340) was 10 from the NorthGate arrival (z 330), inside the prompt's reach, so the exit
--    moved out along the road to where it leaves the valley; the brief's arena (local (-80, 300)) is under the rim's
--    big oaks, so it moved to the open flat ground beside the road beyond the valley (both measured in Ye).
local EXIT_Z = 360 -- PROPOSAL: 30 out from the NorthGate arrival (prompt reach 12); the road (12 wide) starts at z 354
local ARENA_X, ARENA_Z = -50, 420 -- PROPOSAL: x -80..-20, 14 clear of the road's west edge (x -6); flat ground
local function ground(X, Z) -- the world Y of the walkable surface at local (X, Z), ignoring what a re-run replaces
	local Ray = RaycastParams.new()
	Ray.RespectCanCollide = true
	local Skip = {}
	for _, N in ipairs({"RoadGate", "AmbushArena", "AmbushRing"}) do
		for _, C in ipairs(L:GetChildren()) do
			if C.Name == N then table.insert(Skip, C) end
		end
	end
	Ray.FilterType = Enum.RaycastFilterType.Exclude
	Ray.FilterDescendantsInstances = Skip
	local Hit = workspace:Raycast(O + Vector3.new(X, 40, Z), Vector3.new(0, -120, 0), Ray)
	assert(Hit, ("no ground under local (%d, %d)"):format(X, Z))
	return Hit.Position.Y
end
local function roadGate(Parent, Pos, Out, Route, Arrive) -- Pos: on the road surface; Out: the way the road leaves
	clear(Parent, "RoadGate")
	local M = mark(Instance.new("Model"))
	M.Name = "RoadGate"
	local CF = CFrame.lookAt(Pos, Pos + Out)
	local STONE = Color3.fromRGB(141, 133, 119)
	for _, S in ipairs({-1, 1}) do -- PROPOSAL sizes (the same arch as the Foundry's gate), clear of the 12-wide road
		part(M, "GatePillar", Vector3.new(3, 12, 3), CF * CFrame.new(S * 8.5, 6, 0), Enum.Material.Cobblestone, STONE)
	end
	part(M, "GateLintel", Vector3.new(20, 2.5, 3.5), CF * CFrame.new(0, 13.25, 0), Enum.Material.Cobblestone, STONE)
	local E = part(M, "RoadExit", Vector3.new(6, 8, 2), CF * CFrame.new(0, 4, 0), Enum.Material.SmoothPlastic, Color3.new(1, 1, 1)) -- brief size
	E.Transparency, E.CanCollide, E.CanQuery, E.CanTouch, E.CastShadow = 1, false, false, false, false
	E:SetAttribute("Route", Route)
	E:SetAttribute("Arrive", Arrive)
	CS:AddTag(E, "RenseiRoadExit")
	M.Parent = Parent
	return E
end
local function ambushArena(Parent, Pos) -- Pos: on the ground; the marker's bottom sits on it
	clear(Parent, "AmbushArena")
	local A = mark(part(Parent, "AmbushArena", Vector3.new(60, 1, 60), CFrame.new(Pos + Vector3.new(0, 0.5, 0)), Enum.Material.SmoothPlastic, Color3.new(1, 1, 1)))
	A.Transparency, A.CanCollide, A.CanQuery, A.CanTouch, A.CastShadow = 1, false, false, false, false
	CS:AddTag(A, "RenseiAmbushArena")
	return A
end
-- the clearing's edge, made visible (fix round 1: walking out past it is fleeing): the village's own fence posts
-- (Lindenmoor.Fences.FencePost) every few studs, with gaps to walk through, and its creek-bank stones at the corners
local POST_GAP = 7.5 -- PROPOSAL: studs between posts (an R6 is 4 wide, so there is always a way out)
local function arenaRing(Parent, Arena)
	clear(Parent, "AmbushRing")
	local Post = L:FindFirstChild("Fences") and L.Fences:FindFirstChild("FencePost")
	local Stones
	for _, S in ipairs(L.Scenery.CreekBanks:GetChildren()) do
		if S:IsA("Model") and S.Name:find("^BankStones") then Stones = S break end
	end
	assert(Post and Stones, "the village's FencePost / BankStones kit pieces are missing")
	local M = mark(Instance.new("Model"))
	M.Name = "AmbushRing"
	local Half, Floor = Arena.Size.X / 2, Arena.Position.Y - Arena.Size.Y / 2
	local N = math.floor(Arena.Size.X / POST_GAP + 0.5)
	for Side = 0, 3 do
		for I = 0, N - 1 do
			local Along = -Half + (I + 0.5) * POST_GAP -- half a gap in from each corner: the middle of each side is open
			local X, Z = Along, -Half
			if Side == 1 then X, Z = Half, Along elseif Side == 2 then X, Z = -Along, Half elseif Side == 3 then X, Z = -Half, -Along end
			local P = Post:Clone()
			P.Name = "RingPost"
			P.CFrame = CFrame.new(Arena.Position.X + X, Floor + P.Size.Y / 2, Arena.Position.Z + Z)
			P.Parent = M
		end
	end
	for _, C in ipairs({{-1, -1}, {1, -1}, {1, 1}, {-1, 1}}) do
		local S = Stones:Clone()
		S.Name = "RingStones"
		local _, Size = S:GetBoundingBox()
		S:PivotTo(CFrame.new(Arena.Position.X + C[1] * (Half + 3), Floor + Size.Y / 2 - 0.5, Arena.Position.Z + C[2] * (Half + 3)))
		S.Parent = M
	end
	M.Parent = Parent
	return M
end
local Exit = roadGate(L, Vector3.new(O.X, ground(0, EXIT_Z), O.Z + EXIT_Z), Vector3.new(0, 0, 1), "RoadLindenmoorFoundry", "SouthGate")
local Arena = ambushArena(L, Vector3.new(O.X + ARENA_X, ground(ARENA_X, ARENA_Z), O.Z + ARENA_Z))
arenaRing(L, Arena)

return "lindenmoor station built: platform z " .. PLAT_S .. ".." .. PLAT_N .. ", trains, booth, board; road exit at "
	.. tostring(Exit.Position - O) .. ", arena at " .. tostring(Arena.Position - O)

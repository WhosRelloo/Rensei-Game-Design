-- Lindenmoor station (World Plan 1 Task 6, 2026-10-21): run in Ye (106992859583940), Edit. Re-runnable.
-- Builds, in World.Map.Lindenmoor.Station (local origin O = (0, 4, -650), the same as the Lindenmoor kit):
--   * Platform + PlatformEdge extended along the track (the 90-long originals go to the backup folder);
--   * PlatformTrain (tag RenseiPlatformTrain) and RideTrain (tag RenseiRideTrain), Route = "LindenmoorFoundry",
--     cloned car by car from ServerStorage.TrainKit; nose north (+Z), each car turned so its +X points to +Z;
--   * TicketBooth: a counter part TicketClerk (tag RenseiTicketClerk, Station = "Lindenmoor") and an R6 clerk in
--     State blue, beside the station house;
--   * DepartureBoard (tag RenseiDepartureBoard; TravelClient draws the times on it).
--   * (Task 8b, roads on foot) NorthRoad, in World.Map.Lindenmoor: the north road as a real, walkable passage out of
--     the region (part ground, kit trees, rocks and fences, a gate arch at its mouth), with its RenseiRoadPassage,
--     RenseiRoadEncounter and RenseiRoadThreshold markers and the RoadStart arrival (see step 5). It replaces Task 8's
--     RoadGate / RoadExit, AmbushArena and AmbushRing, which a run retires into the backups.
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

-- 5. the north road on foot (World Plan 1 Task 8b, 2026-10-21; world spec §3b; replaces Task 8's exit, arch and arena).
--    North of the valley the old hub road runs on to the hub (the training ground, the alchemy trainers), so the
--    passage branches east off it just past the valley's edge (world z -270), runs east, bends north into a cutting
--    under big oaks, and bends east again into the threshold. All of it stands on the hub's baseplate (top y 0).
--    Task 8's road gate (with its exit part), the ambush arena and its ring are retired into
--    RenseiBackups["Pre-RoadsOnFoot_2026-10-21"]; the arch is rebuilt at the passage's mouth as its gate.
local RB = Backups:FindFirstChild("Pre-RoadsOnFoot_2026-10-21") or Instance.new("Folder")
RB.Name = "Pre-RoadsOnFoot_2026-10-21"
RB.Parent = Backups
for _, N in ipairs({"RoadGate", "AmbushArena", "AmbushRing"}) do
	local Old = L:FindFirstChild(N)
	while Old do
		if not RB:FindFirstChild(N) then -- the first run keeps a copy of Task 8's piece
			local Copy = Old:Clone()
			Copy.Parent = RB
		end
		Old:Destroy()
		Old = L:FindFirstChild(N)
	end
end
clear(L, "NorthRoad")

-- ===== Roads on foot (World Plan 1 Task 8b, 2026-10-21; world spec §3b). The same builder is in station_lindenmoor.lua
-- and station_foundry.lua. =====
-- A real, walkable stretch of road that leaves the region, in the part-ground style of Art/Studio/Lindenmoor/ground.lua:
-- 4-stud cells of flat slabs in 1-stud steps over stone sides, merged into rectangles; a dirt road down the middle; mossy
-- banks that rise into a cutting towards the far end; kit trees, rocks and fences cloned along it. It carries:
--   * RenseiRoadPassage parts (Route, To, RoadName) covering it, one per leg;
--   * RenseiRoadEncounter parts (Route) along it, each with hidden SpawnPoint attachments (Side = "Out" ahead of
--     someone walking out, "In" ahead of someone walking in) behind cover;
--   * a RenseiRoadThreshold part (Route, To) at the far end, round a bend whose far side can't be seen;
--   * the RenseiArrival "RoadStart" (Point) on the road before that bend, facing inward: where travellers from the
--     other place appear.
-- Server code: RoadService; client: TravelClient. Every number is a PROPOSAL.
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
				Post.Parent = M
				if Last then
					for _, H in ipairs({0.3, 0.7}) do
						local R = C.Rail:Clone()
						local From, To2 = Vector3.new(Last.X, Y + Post.Size.Y * H, Last.Z), Vector3.new(Post.Position.X, Y + Post.Size.Y * H, Post.Position.Z)
						R.Size = Vector3.new(R.Size.X, R.Size.Y, (To2 - From).Magnitude)
						R.CFrame = CFrame.lookAt((From + To2) / 2, To2)
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

local KitRoot = SS:FindFirstChild("LindenmoorKit")
assert(KitRoot, "ServerStorage.LindenmoorKit is missing (the Lindenmoor kit import)")
local function kitPiece(Kind, Rng)
	local F = KitRoot:FindFirstChild(Kind)
	local List = F and F:GetChildren() or {}
	if #List == 0 then return nil end
	return List[Rng:NextInteger(1, #List)]:Clone()
end
local Fences = L:FindFirstChild("Fences")
local HubRoad = L:FindFirstChild("HubRoad")
local Road, Info = Passage({
	Parent = L, Name = "NorthRoad", Route = "RoadLindenmoorFoundry", To = "Foundry", RoadName = "The North Road",
	RoadY = 1, FloorY = 0, -- PROPOSAL: the road 1 above the baseplate (the valley's north edge is at y 1)
	Half = 22, -- PROPOSAL: the passage is 44 wide, bank to bank
	Legs = {
		{"line", 8, -270, 178, -270}, -- east, beside the town's north fields
		{"arc", 178, -225, 45, -90, 0}, -- bending north
		{"line", 223, -225, 223, -150}, -- the cutting
		{"arc", 248, -150, 25, 180, 90}, -- bending east, out of sight
		{"line", 248, -125, 275, -125}, -- into the trees (past the threshold)
	},
	Skip = function(X, Z) return X < 8 or Z < -293 end, -- the hub road (x -6..6) and the valley's ground (to z -296)
	Clip = {MinX = 8, MinZ = -293},
	Cut = 200, -- PROPOSAL: the banks rise into a cutting from here (round the first bend and up the north straight)
	High = 1, -- the left bank (the hub's side) stands higher on the open stretch; the right looks over the fields
	Threshold = 359, -- PROPOSAL: studs from the mouth (about 360, world spec §3b's 300-400)
	RoadStart = 305, -- PROPOSAL: 54 back from the threshold, before the last bend
	Encounters = {85, 195, 265}, -- PROPOSAL
	Gate = 4,
	Fence = {10, 55},
	Kit = kitPiece,
	Post = Fences and Fences:FindFirstChild("FencePost"),
	Rail = Fences and Fences:FindFirstChild("FenceRail"),
	Seed = 8,
})
mark(Road)
-- a signpost at the fork, cloned from the hub road's own "LINDENMOOR" sign
if HubRoad and HubRoad:FindFirstChild("SignPost") and HubRoad:FindFirstChild("SignBoard") then
	local Post, Board = HubRoad.SignPost:Clone(), HubRoad.SignBoard:Clone()
	local OldBase = HubRoad.SignPost.Position - Vector3.new(0, HubRoad.SignPost.Size.Y / 2, 0)
	local Delta = CFrame.new(Vector3.new(7, 0, -286) - OldBase) -- PROPOSAL: on the hub road's east verge, at the fork
	Post.CFrame = Delta * HubRoad.SignPost.CFrame
	Board.CFrame = Delta * HubRoad.SignBoard.CFrame
	for _, D in ipairs(Board:GetDescendants()) do
		if D:IsA("TextLabel") then D.Text = "FOUNDRY YARD" end
	end
	Post.Parent, Board.Parent = Road, Road
end

return ("lindenmoor station built: platform z %d..%d, trains, booth, board; north road %d studs (threshold at %d), %d slabs, %d trees, %d rocks, %d encounters, %d parts; threshold at %s, RoadStart at %s"):format(
	PLAT_S, PLAT_N, Info.Length, Info.Threshold, Info.Slabs, Info.Trees, Info.Rocks, Info.Encounters, Info.Parts,
	tostring(Info.ThresholdAt), tostring(Info.RoadStart))

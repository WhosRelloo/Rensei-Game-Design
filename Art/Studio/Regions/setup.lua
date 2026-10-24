-- setup (Region Foundation Task 12, 2026-10-24): builds a region's travel pieces from the RenseiMarker parts in its map.
-- Run in Studio Edit, in the region's place, AFTER the region import (Task 11's finish.lua) has built the map. It needs
-- travel_pieces.lua (the builders) bundled in front of it as a local, e.g.
--     { echo 'local TravelPieces = (function()'; cat travel_pieces.lua; echo 'end)()'; cat setup.lua; } > bundle.lua
--     python -I Art/Tools/rbxc.py luau "placeId: <place>" Edit @bundle.lua
-- (or a ModuleScript ServerStorage.TravelPieces holding travel_pieces.lua's source), and ServerStorage.TrainKit (the
-- seven *_Main cars; copy it from Ye).
--
-- Where it reads and builds:
--   * the map child: workspace.World.Map.<MAP_CHILD> (below: the region file's MapChild, Task 11; nil = REGION). For
--     Lindenmoor it is "LindenmoorExpansion" (beside the kept village, Map.Lindenmoor). Set REGION and MAP_CHILD first.
--   * a test run: when ServerStorage.RegionSetupRoot exists, it is the root instead (its attribute MapChild names the
--     child it stands for). A test run never touches workspace or RenseiBackups. Remove RegionSetupRoot afterwards:
--     its tagged parts are live CollectionService tags while it exists.
--   * it reads every RenseiMarker part under the root (outside Travel) and builds the pieces into <root>.Travel.
--   * idempotent: it builds a new Travel (unparented) first; only when every piece is built does it replace the old one.
--     In a real run, the first time it replaces a Travel it keeps a copy in
--     ServerStorage.RenseiBackups["Pre-RegionSetup_<MapChild>"] (named by the MapChild, which is the Region by default:
--     two children of one region, e.g. Lindenmoor and LindenmoorExpansion, must not share a backup). On any error, or
--     with no markers, nothing changes.
--   * returns a one-line summary.
--
-- Markers (Tag RenseiMarker, attribute Piece; region file Markers, see Art/Blender/region_builder/schema.py). A marker's
-- SPOT is the bottom centre of its part (the markers stage stands a 2 x 2 x 2 part on its At); its FACING is its level
-- LookVector (region file Yaw: 0 = -Z (north), 90 = -X, -90 = +X). Coordinates in attributes are region coordinates
-- (+ ORIGIN = world). Every derived number below comes from Foundry's build (station_foundry.lua) and is a PROPOSAL.
--   Station      Route, TrackX, RailTop, NoseZ, PlatformSide (must be 1: the trains' baggage door and StowZone face -X,
--                so the platform is on +X); optional Arrival (false: no Platform arrival, for a second station).
--                Builds the 12 x 2.4 x 340 platform (centre x TrackX + 12, top RailTop + 1.8, z NoseZ - 445 .. NoseZ - 105),
--                two 500-long rails (TrackX +- 2.6), buffer stops at NoseZ - 240 +- 251, the platform train (pivot =
--                the nose at (TrackX, RailTop, NoseZ)), the ride train at that pivot + (0, 400, -1600), and the Platform
--                arrival (on the platform at z NoseZ - 240). The spot is not used.
--   Clerk        Station. The ticket booth at the spot, its window facing the marker's facing.
--   Board        The departure board 8 above the spot (stand the marker on the floor under it), facing the facing.
--   Gate         Route (the gate's line). The spot is on the ground at the gate's foot, the facing onto the platform:
--                the 8 x 8 x 1 gate stands on the platform's top (centre 4 above it), the ramp (ground to platform top,
--                6 long) runs 3.5 behind, the posts from the ground to 6.6 above the platform top, the sign over them
--                (optional Sign; default "STATE CHECKPOINT"), the guard on the ground 4 behind and 6.5 to the right,
--                facing left (along the platform's edge). Needs a Station (its platform top).
--   Railing      Runs (JSON [[x1, z1, x2, z2], ...]), WallTop. The ground is the platform's top over the nearest
--                station's platform, else the spot's height.
--   FreightYard  Built beside the nearest station's platform-train baggage car; the yard's ground is the spot's height.
--   RoadPassage  Route, To, RoadName, Legs (JSON, the Passage leg format: ["line", x1, z1, x2, z2] or
--                ["arc", cx, cz, r, a1, a2]), Threshold, RoadStart, Encounters (JSON [s, ...]), Half, RoadY, Seed.
--                Optional: Name (the model; default "Road_<Route>"), FloorY (default RoadY - 1), Cut (default 200),
--                High (default 1), Gate (s of an arch on the road), Fence (JSON [s1, s2]), Skip (JSON [[x0, z0, x1, z1],
--                ...]: no road cells where x0 <= x < x1 and z0 <= z < z1), Clip (JSON {"MinX", "MaxX", "MinZ", "MaxZ"},
--                any of them: the leg boxes' limits).
-- A piece that needs a station takes the Station whose Route equals its own Route attribute, else the nearest one.
local REGION = "Foundry" -- the region id (the summary)
local MAP_CHILD = nil -- the World.Map child to read and build (Task 11's MapChild); nil = REGION
local ORIGIN = Vector3.zero -- finish.lua's ORIGIN: region coordinates + ORIGIN = world (region exports use (0, 0, 0))
local KIT_NAME = "TrainKit" -- ServerStorage.<KIT_NAME>: the train kit
local RIDE_OFFSET = Vector3.new(0, 400, -1600) -- the ride train from the platform train's pivot (the travel contract)

local CS = game:GetService("CollectionService")
local SS = game:GetService("ServerStorage")
local HS = game:GetService("HttpService")

local TP = TravelPieces -- bundled in front of this file (see the top)
if TP == nil then
	local M = SS:FindFirstChild("TravelPieces")
	if M and M:IsA("ModuleScript") then TP = require(M:Clone()) end
end
if type(TP) ~= "table" or type(TP.Passage) ~= "function" then
	return "setup refused: travel_pieces is missing (bundle it in front of setup.lua); nothing changed"
end

-- ===== the root =====
local TestRoot = SS:FindFirstChild("RegionSetupRoot")
local Testing = TestRoot ~= nil
local Child = MAP_CHILD or REGION
local Root
if Testing then
	Root = TestRoot
	Child = TestRoot:GetAttribute("MapChild") or Child
else
	local World = workspace:FindFirstChild("World")
	local Map = World and World:FindFirstChild("Map")
	Root = Map and Map:FindFirstChild(Child)
	if not Root then return "setup refused: no workspace.World.Map." .. Child .. " (set MAP_CHILD); nothing changed" end
end
local Kit = SS:FindFirstChild(KIT_NAME)
local KitOk, KitErr = pcall(TP.checkKit, Kit)
if not KitOk then return "setup refused: " .. tostring(KitErr) .. "; nothing changed" end

-- ===== the markers =====
local PIECES = {"Station", "Clerk", "Board", "Gate", "Railing", "FreightYard", "RoadPassage"} -- build order
local NEED = { -- required attributes: "string" / "number" / "json" (a JSON string)
	Station = {Route = "string", TrackX = "number", RailTop = "number", NoseZ = "number", PlatformSide = "number"},
	Clerk = {Station = "string"},
	Board = {},
	Gate = {Route = "string"},
	Railing = {Runs = "json", WallTop = "number"},
	FreightYard = {},
	RoadPassage = {Route = "string", To = "string", RoadName = "string", Legs = "json", Threshold = "number", RoadStart = "number",
		Encounters = "json", Half = "number", RoadY = "number", Seed = "number"},
}
local OPTIONAL = {
	Station = {Arrival = "boolean"},
	Gate = {Sign = "string"},
	RoadPassage = {Name = "string", FloorY = "number", Cut = "number", High = "number", Gate = "number", Fence = "json", Skip = "json", Clip = "json"},
}
local Travel0 = Root:FindFirstChild("Travel")
local ByPiece, Errors, Count = {}, {}, 0
for _, P in ipairs(PIECES) do ByPiece[P] = {} end
for _, D in ipairs(Root:GetDescendants()) do
	if D:IsA("BasePart") and CS:HasTag(D, "RenseiMarker") and not (Travel0 and D:IsDescendantOf(Travel0)) then
		local Piece = D:GetAttribute("Piece")
		local W = D:GetFullName()
		if not ByPiece[Piece] then
			table.insert(Errors, W .. ": Piece must be one of " .. table.concat(PIECES, ", ") .. ", got " .. tostring(Piece))
		else
			local A = {}
			local function read(K, Kind, Required)
				local V = D:GetAttribute(K)
				if V == nil then
					if Required then table.insert(Errors, W .. ": missing " .. K) end
					return
				end
				if Kind == "json" then
					local Ok, J = pcall(HS.JSONDecode, HS, V)
					if type(V) ~= "string" or not Ok or type(J) ~= "table" then
						table.insert(Errors, W .. ": " .. K .. " must be a JSON list or object (a string)")
						return
					end
					A[K] = J
				elseif typeof(V) ~= Kind then
					table.insert(Errors, W .. ": " .. K .. " must be a " .. Kind .. ", got " .. typeof(V))
				elseif Kind == "string" and V == "" then
					table.insert(Errors, W .. ": " .. K .. " is empty")
				else
					A[K] = V
				end
			end
			for K, Kind in pairs(NEED[Piece]) do read(K, Kind, true) end
			for K, Kind in pairs(OPTIONAL[Piece] or {}) do read(K, Kind, false) end
			-- shapes
			local function nums(T, N) -- a list of N numbers
				if type(T) ~= "table" or #T ~= N then return false end
				for I = 1, N do if type(T[I]) ~= "number" then return false end end
				return true
			end
			if Piece == "Station" and A.PlatformSide and A.PlatformSide ~= 1 then
				table.insert(Errors, W .. ": PlatformSide must be 1 (the platform on the track's +X side), got " .. tostring(A.PlatformSide))
			end
			if Piece == "Railing" and A.Runs then
				for I, R in ipairs(A.Runs) do
					if not nums(R, 4) then table.insert(Errors, W .. ": Runs[" .. I .. "] must be [x1, z1, x2, z2]") end
				end
				if #A.Runs == 0 then table.insert(Errors, W .. ": Runs is empty") end
			end
			if Piece == "RoadPassage" then
				if A.Legs then
					for I, G in ipairs(A.Legs) do
						local Ok = type(G) == "table" and ((G[1] == "line" and #G == 5) or (G[1] == "arc" and #G == 6))
						for J = 2, Ok and #G or 0 do if type(G[J]) ~= "number" then Ok = false end end
						if not Ok then table.insert(Errors, W .. ": Legs[" .. I .. "] must be [\"line\", x1, z1, x2, z2] or [\"arc\", cx, cz, r, a1, a2]") end
					end
					if #A.Legs == 0 then table.insert(Errors, W .. ": Legs is empty") end
				end
				if A.Encounters then
					for I, S in ipairs(A.Encounters) do
						if type(S) ~= "number" then table.insert(Errors, W .. ": Encounters[" .. I .. "] must be a number") end
					end
				end
				if A.Fence and not nums(A.Fence, 2) then table.insert(Errors, W .. ": Fence must be [s1, s2]") end
				for I, R in ipairs(A.Skip or {}) do
					if not nums(R, 4) then table.insert(Errors, W .. ": Skip[" .. I .. "] must be [x0, z0, x1, z1]") end
				end
				for K, V in pairs(A.Clip or {}) do
					if not (({MinX = 1, MaxX = 1, MinZ = 1, MaxZ = 1})[K] and type(V) == "number") then
						table.insert(Errors, W .. ": Clip." .. tostring(K) .. " must be MinX, MaxX, MinZ or MaxZ, a number")
					end
				end
			end
			local Spot = (D.CFrame * CFrame.new(0, -D.Size.Y / 2, 0)).Position
			local L = D.CFrame.LookVector * Vector3.new(1, 0, 1)
			table.insert(ByPiece[Piece], {Part = D, A = A, Spot = Spot, Look = L.Magnitude > 1e-6 and L.Unit or Vector3.new(0, 0, -1), Name = W})
			Count += 1
		end
	end
end
for _, P in ipairs(PIECES) do table.sort(ByPiece[P], function(X, Y) return X.Name < Y.Name end) end
local NeedStation = #ByPiece.Gate + #ByPiece.FreightYard
if NeedStation > 0 and #ByPiece.Station == 0 then table.insert(Errors, "a Gate or FreightYard marker needs a Station marker") end
local Arrivals = 0
for _, S in ipairs(ByPiece.Station) do if S.A.Arrival ~= false then Arrivals += 1 end end
if Arrivals > 1 then table.insert(Errors, "one Platform arrival per place: set Arrival = false on every Station but one") end
local Routes = {}
for _, S in ipairs(ByPiece.Station) do
	if S.A.Route and Routes[S.A.Route] then table.insert(Errors, "two Station markers for route " .. S.A.Route) end
	if S.A.Route then Routes[S.A.Route] = true end
end
if #Errors > 0 then
	return "setup refused (" .. #Errors .. " marker problem(s)); nothing changed:\n  " .. table.concat(Errors, "\n  ")
end
if Count == 0 then return "setup: no RenseiMarker parts under " .. Root:GetFullName() .. "; nothing changed" end

-- ===== build (into an unparented Travel) =====
local Travel = Instance.new("Model")
Travel.Name = "Travel"
Travel:SetAttribute("RegionSetup", Child)
local Info = {Stations = {}, Roads = {}}
local function Build()
	local OX, OY, OZ = ORIGIN.X, ORIGIN.Y, ORIGIN.Z
	local Stations = {}
	-- Station: Foundry's track and platform (station_foundry.lua:77-95) and the two trains (:164-165)
	for _, M in ipairs(ByPiece.Station) do
		local A = M.A
		local TX, RT, NZ = A.TrackX + OX, A.RailTop + OY, A.NoseZ + OZ
		local St = Instance.new("Model")
		St.Name = #ByPiece.Station > 1 and ("Station_" .. A.Route) or "Station"
		St.Parent = Travel
		local Plat = TP.part("Platform", Vector3.new(12, 2.4, 340), CFrame.new(TX + 12, RT + 0.6, NZ - 275), Enum.Material.Cobblestone, Color3.fromRGB(122, 118, 108), St)
		for _, X in ipairs({TX - 2.6, TX + 2.6}) do
			TP.part("Rail", Vector3.new(0.5, 0.6, 500), CFrame.new(X, RT - 0.3, NZ - 240), Enum.Material.Metal, Color3.fromRGB(58, 56, 53), St)
		end
		for _, DZ in ipairs({-251, 251}) do
			TP.part("BufferStop", Vector3.new(7, 2.6, 1.6), CFrame.new(TX, RT + 1, NZ - 240 + DZ), Enum.Material.Wood, Color3.fromRGB(110, 40, 32), St)
		end
		if A.Arrival ~= false then TP.arrival("Platform", Vector3.new(TX + 12, RT + 2.4, NZ - 240), St) end
		local Train = TP.lay("PlatformTrain", Vector3.new(TX, RT, NZ), A.Route, "RenseiPlatformTrain", St, Kit)
		TP.lay("RideTrain", Vector3.new(TX, RT, NZ) + RIDE_OFFSET, A.Route, "RenseiRideTrain", St, Kit)
		table.insert(Stations, {Route = A.Route, Model = St, Platform = Plat, Top = Plat.Position.Y + Plat.Size.Y / 2, Train = Train})
		table.insert(Info.Stations, A.Route)
	end
	local function stationFor(M)
		local Best, BD
		for _, S in ipairs(Stations) do
			if M.A.Route and S.Route == M.A.Route then return S end
			local D = (Vector3.new(S.Platform.Position.X, 0, S.Platform.Position.Z) - Vector3.new(M.Spot.X, 0, M.Spot.Z)).Magnitude
			if not BD or D < BD then Best, BD = S, D end
		end
		return Best
	end
	local function overPlatform(S, X, Z)
		if not S then return false end
		local L = S.Platform.CFrame:PointToObjectSpace(Vector3.new(X, S.Platform.Position.Y, Z))
		return math.abs(L.X) <= S.Platform.Size.X / 2 and math.abs(L.Z) <= S.Platform.Size.Z / 2
	end
	-- Clerk: the booth (:211)
	for _, M in ipairs(ByPiece.Clerk) do
		local S = stationFor(M)
		TP.booth(CFrame.lookAt(M.Spot, M.Spot + M.Look), M.A.Station, S and S.Model or Travel)
	end
	-- Board: the departure board (:227), 8 above its spot
	for _, M in ipairs(ByPiece.Board) do
		local S = stationFor(M)
		TP.board(M.Spot + Vector3.new(0, 8, 0), M.Look, S and S.Model or Travel)
	end
	-- Gate: the ramp, the papers gate, posts, sign and guard (:925-936)
	for _, M in ipairs(ByPiece.Gate) do
		local S = stationFor(M)
		local L, Ground, Top = M.Look, M.Spot.Y, S.Top
		local Right = L:Cross(Vector3.yAxis) -- the gate's RightVector
		local Ramp = Instance.new("WedgePart")
		Ramp.Name, Ramp.Size, Ramp.Anchored = "GateRamp", Vector3.new(8, Top - Ground, 6), true -- high end (+Z local) at the platform
		local RP = Vector3.new(M.Spot.X, (Top + Ground) / 2, M.Spot.Z) - L * 3.5
		Ramp.CFrame = CFrame.lookAt(RP, RP - L)
		Ramp.Material, Ramp.Color = Enum.Material.Cobblestone, Color3.fromRGB(122, 118, 108) -- the platform's
		Ramp.Parent = S.Model
		local GC = Vector3.new(M.Spot.X, Top + 4, M.Spot.Z)
		local Feet = Vector3.new(M.Spot.X, Ground, M.Spot.Z) - L * 4 + Right * 6.5
		TP.PapersGate({
			Parent = S.Model, Gate = CFrame.lookAt(GC, GC + L), PostFloor = Ground, PostTop = Top + 6.6,
			Sign = M.A.Sign or "STATE CHECKPOINT", Route = M.A.Route, Guard = CFrame.lookAt(Feet, Feet - Right),
		})
	end
	-- Railing (:937-948)
	for _, M in ipairs(ByPiece.Railing) do
		local S = stationFor(M)
		local Runs = {}
		for _, R in ipairs(M.A.Runs) do
			table.insert(Runs, {Vector3.new(R[1] + OX, M.Spot.Y, R[2] + OZ), Vector3.new(R[3] + OX, M.Spot.Y, R[4] + OZ)})
		end
		TP.Railing({
			Parent = S and S.Model or Travel, Runs = Runs, WallTop = M.A.WallTop + OY,
			Ground = function(X, Z) return overPlatform(S, X, Z) and S.Top or M.Spot.Y end,
			Post = TP.kitPart(TP.KITDATA.FencePost), Rail = TP.kitPart(TP.KITDATA.FenceRail),
		})
	end
	-- FreightYard (:949-954)
	for _, M in ipairs(ByPiece.FreightYard) do
		local S = stationFor(M)
		local Car = S.Train:FindFirstChild("BaggageCar_Main")
		assert(Car, "the platform train has no BaggageCar_Main")
		TP.FreightYard({
			Parent = S.Model, Car = Car, Ground = function() return M.Spot.Y end,
			Post = TP.kitPart(TP.KITDATA.FencePost), Rail = TP.kitPart(TP.KITDATA.FenceRail),
		})
	end
	-- RoadPassage (:677-695)
	for _, M in ipairs(ByPiece.RoadPassage) do
		local A = M.A
		local Legs = {}
		for _, G in ipairs(A.Legs) do
			if G[1] == "line" then
				table.insert(Legs, {"line", G[2] + OX, G[3] + OZ, G[4] + OX, G[5] + OZ})
			else
				table.insert(Legs, {"arc", G[2] + OX, G[3] + OZ, G[4], G[5], G[6]})
			end
		end
		local Skip = {}
		for _, R in ipairs(A.Skip or {}) do table.insert(Skip, {R[1] + OX, R[2] + OZ, R[3] + OX, R[4] + OZ}) end
		local Clip
		if A.Clip then
			Clip = {}
			for K, V in pairs(A.Clip) do Clip[K] = V + ((K == "MinX" or K == "MaxX") and OX or OZ) end
		end
		local _, R = TP.Passage({
			Parent = Travel, Name = A.Name or ("Road_" .. A.Route), Route = A.Route, To = A.To, RoadName = A.RoadName,
			RoadY = A.RoadY + OY, FloorY = (A.FloorY or A.RoadY - 1) + OY, Half = A.Half, Legs = Legs,
			Skip = function(X, Z)
				for _, Q in ipairs(Skip) do
					if X >= Q[1] and X < Q[3] and Z >= Q[2] and Z < Q[4] then return true end
				end
				return false
			end,
			Clip = Clip, Cut = A.Cut or 200, High = A.High or 1, -- PROPOSAL defaults (Foundry's and Lindenmoor's roads)
			Threshold = A.Threshold, RoadStart = A.RoadStart, Encounters = A.Encounters, Gate = A.Gate, Fence = A.Fence,
			Kit = TP.kitPiece, Post = TP.kitPart(TP.KITDATA.FencePost), Rail = TP.kitPart(TP.KITDATA.FenceRail), Seed = A.Seed,
		})
		table.insert(Info.Roads, ("%s %d studs, %d slabs, %d trees, %d rocks, %d encounters"):format(A.Name or A.Route, R.Length, R.Slabs, R.Trees, R.Rocks, R.Encounters))
	end
end
local Ok, Err = pcall(Build)
if not Ok then
	Travel:Destroy()
	return "setup failed (" .. tostring(Err) .. "); nothing changed"
end

-- ===== swap =====
local Backup = "none"
local Old = Root:FindFirstChild("Travel")
if Old and not Testing then
	local Backups = SS:FindFirstChild("RenseiBackups")
	if not Backups then
		Backups = Instance.new("Folder")
		Backups.Name = "RenseiBackups"
		Backups.Parent = SS
	end
	local BName = "Pre-RegionSetup_" .. Child
	if not Backups:FindFirstChild(BName) then
		local B = Instance.new("Folder")
		B.Name = BName
		Old:Clone().Parent = B
		B.Parent = Backups
		Backup = "RenseiBackups." .. BName
	else
		Backup = "kept RenseiBackups." .. BName .. " (the first Travel)"
	end
end
if Old then Old:Destroy() end
Travel.Parent = Root

local Parts, Tags = 0, {}
for _, D in ipairs(Travel:GetDescendants()) do
	if D:IsA("BasePart") then Parts += 1 end
	for _, T in ipairs(CS:GetTags(D)) do Tags[T] = (Tags[T] or 0) + 1 end
end
for _, T in ipairs(CS:GetTags(Travel)) do Tags[T] = (Tags[T] or 0) + 1 end
local TagList = {}
for T, N in pairs(Tags) do table.insert(TagList, T .. " " .. N) end
table.sort(TagList)
return ("setup ok (%s): %s.Travel from %d markers (%s), %d parts; stations %s; roads: %s; tags: %s; replaced old Travel: %s; backup: %s"):format(
	Testing and "test root" or "Map." .. Child, Root:GetFullName(), Count,
	(function()
		local L = {}
		for _, P in ipairs(PIECES) do if #ByPiece[P] > 0 then table.insert(L, P .. " " .. #ByPiece[P]) end end
		return table.concat(L, ", ")
	end)(), Parts, table.concat(Info.Stations, ", "), table.concat(Info.Roads, "; "), table.concat(TagList, ", "),
	Old and "yes" or "no", Backup)

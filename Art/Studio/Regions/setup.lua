-- setup (Region Foundation Task 12, 2026-10-24; fix round 1): builds a region's travel pieces from the RenseiMarker parts
-- in its map. Run in Studio Edit, in the region's place, AFTER the region import (Task 11's finish.lua) has built the map.
-- It needs travel_pieces.lua (the builders) in front of it and ServerStorage.TrainKit (the seven *_Main cars; copy it
-- from Ye) when there is a Station marker. Bundle and run it with:
--     python -I Art/Studio/Regions/bundle_setup.py setup <scratch>/setup_bundle.lua
--     python -I Art/Tools/rbxc.py luau "placeId: <place>" Edit @<scratch>/setup_bundle.lua
-- (A ModuleScript ServerStorage.TravelPieces holding travel_pieces.lua's source also works.) Check the result with
--     python -I Art/Studio/Regions/bundle_setup.py contract <scratch>/check.lua workspace.World.Map.<MapChild>
--
-- Where it reads and builds:
--   * the map child: workspace.World.Map.<MAP_CHILD> (below: the region file's MapChild, Task 11; nil = REGION). For
--     Lindenmoor it is "LindenmoorExpansion" (beside the kept village, Map.Lindenmoor). Set REGION and MAP_CHILD first.
--   * a test run: ServerStorage.RegionSetupRoot with the attribute TEST = true is the root instead (its attribute
--     MapChild names the child it stands for); ServerStorage.RegionSetupPlace (optional) stands in for the rest of the
--     place. A test run never touches workspace or RenseiBackups. A RegionSetupRoot WITHOUT TEST = true makes setup
--     refuse (a forgotten test root must not turn a real run into a test run). Remove both afterwards: their tagged
--     parts are live CollectionService tags while they exist.
--   * it reads every RenseiMarker part under the root (outside Travel) and builds the pieces into <root>.Travel.
--     A marker whose Piece is in SKIP (not a travel piece: e.g. Lindenmoor's TrainerSpot, where a hub trainer is moved
--     to by hand) is left alone and counted in the summary; any other unknown Piece is refused.
--   * one per place: TravelService.ArrivalPoint and StationService.TrainOf take the first match, so setup refuses if the
--     build would add a Platform or RoadStart arrival, or a platform or ride train for a Route, that the place already has
--     outside the old Travel (a real run scans all of workspace: e.g. the kept Map.Lindenmoor beside
--     LindenmoorExpansion), or more than one of either arrival.
--   * idempotent: it builds a new Travel (unparented) first; only when every piece is built does it replace the old one.
--     A real run backs up a hand-made Travel (one without the RegionSetup attribute setup writes) the first time it
--     replaces it, in ServerStorage.RenseiBackups["Pre-RegionSetup_<MapChild>"] (named by the MapChild: two children of
--     one region must not share a backup); setup's own earlier Travel is simply rebuilt. On any problem, or with no
--     markers, nothing changes.
--   * returns a one-line summary (with any warnings).
--
-- Markers (Tag RenseiMarker, attribute Piece; region file Markers, see Art/Blender/region_builder/schema.py, which checks
-- the same rules). A marker's SPOT is the bottom centre of its part (the markers stage stands a 2 x 2 x 2 part on its
-- At); its FACING is its level LookVector (region file Yaw: 0 = -Z, 90 = -X, -90 = +X; in Ye +Z is north, so Yaw 0
-- faces south there). Coordinates in attributes are the file's own frame (+ ORIGIN = world). Unknown attributes are
-- refused. Every derived number below
-- comes from Foundry's build (station_foundry.lua) and is a PROPOSAL. The ground under a Gate, Railing or FreightYard
-- is taken as flat at its marker's height (no raycasts: the build is unparented).
--   Station      Route, TrackX, RailTop, NoseZ, PlatformSide (must be 1: the trains' baggage door and StowZone face -X,
--                so the platform is on +X); optional Arrival (false: no Platform arrival, for a second station).
--                Builds the 12 x 2.4 x 340 platform (centre x TrackX + 12, top RailTop + 1.8, z NoseZ - 445 .. NoseZ - 105),
--                two 500-long rails (TrackX +- 2.6), buffer stops at NoseZ - 240 +- 251, the platform train (pivot =
--                the nose at (TrackX, RailTop, NoseZ)), the ride train at that pivot + RIDE_OFFSET, and the Platform
--                arrival (on the platform at z NoseZ - 240). The station is axis-aligned: the spot is not used, and a
--                marker Yaw other than 0 is ignored (a warning).
--   Clerk        Station. The ticket booth at the spot, its window facing the marker's facing.
--   Board        The departure board 8 above the spot (stand the marker on the floor under it), facing the facing.
--   Gate         Route (the gate's line: a Station marker's Route, or a platform train's already in the place). The spot
--                is on the ground at the gate's foot (below the platform top), the facing onto the platform: the 8 x 8 x 1
--                gate stands on the platform's top (centre 4 above it), the ramp (ground to platform top, 6 long) runs 3.5
--                behind, the posts from the ground to 6.6 above the platform top, the sign over them (optional Sign;
--                default "STATE CHECKPOINT"), the guard on the ground 4 behind and 6.5 to the right, facing left (along the
--                platform's edge). Needs a Station (its platform top).
--   Railing      Runs (JSON [[x1, z1, x2, z2], ...]), WallTop. The ground is the platform's top over the nearest
--                station's platform, else the spot's height.
--   FreightYard  Built beside the nearest station's platform-train baggage car; the yard's ground is the spot's height.
--   RoadPassage  Route, To, RoadName, Legs (JSON, the Passage leg format: ["line", x1, z1, x2, z2] or
--                ["arc", cx, cz, r, a1, a2]), Threshold, RoadStart (0 <= RoadStart < Threshold <= the road's length),
--                Encounters (JSON [s, ...]), Half, RoadY, Seed (whole). Optional: Arrival (false: no RoadStart arrival,
--                for a second road), Name (the model; default "Road_<Route>"), FloorY (default RoadY - 1), Cut (default
--                200), High (default 1), Gate (s of an arch on the road), Fence (JSON [s1, s2]), Skip (JSON [[x0, z0, x1,
--                z1], ...]: no road cells where x0 <= x < x1 and z0 <= z < z1), Clip (JSON {"MinX", "MaxX", "MinZ",
--                "MaxZ"}, any of them: the leg boxes' limits).
-- A piece that needs a station takes the Station whose Route equals its own Route attribute, else the nearest one.
local REGION = "Foundry" -- the region id (the summary)
local MAP_CHILD = nil -- the World.Map child to read and build (Task 11's MapChild); nil = REGION
-- ORIGIN is added to every coordinate held in a marker ATTRIBUTE (Legs, RoadY, FloorY, Skip, Clip, Runs, WallTop,
-- TrackX, RailTop, NoseZ); the marker parts themselves are already in world space. Use (0, 0, 0) whenever those
-- attributes are written in world studs: every region_builder region (exported with origin (0, 0, 0)) and
-- Lindenmoor's expansion (its region file is in world studs: its RoadPassage Legs start at the marker's own At). It is
-- non-zero only when the attributes are in region coordinates that the export moved, e.g. a test import moved by
-- kit.py --offset (then ORIGIN = that offset). Not the same as finish.lua's ORIGIN (the export's origin, added to the
-- water boxes). bundle_setup.py setup --origin x,y,z sets it in the bundle without editing this file.
local ORIGIN = Vector3.zero
local KIT_NAME = "TrainKit" -- ServerStorage.<KIT_NAME>: the train kit
local RIDE_OFFSET = Vector3.new(0, 400, -1600) -- PROPOSAL: the ride train from the platform train's pivot (well clear)

local CS = game:GetService("CollectionService")
local SS = game:GetService("ServerStorage")
local HS = game:GetService("HttpService")

local TP = TravelPieces -- bundled in front of this file (see the top)
if TP == nil then
	local M = SS:FindFirstChild("TravelPieces")
	if M and M:IsA("ModuleScript") then TP = require(M:Clone()) end
end
if type(TP) ~= "table" or type(TP.Passage) ~= "function" then
	return "setup refused: travel_pieces is missing (bundle it: bundle_setup.py setup); nothing changed"
end

-- ===== the root =====
local TestRoot = SS:FindFirstChild("RegionSetupRoot")
local Testing = false
if TestRoot then
	if TestRoot:GetAttribute("TEST") ~= true then
		return "setup refused: ServerStorage.RegionSetupRoot exists without the attribute TEST = true (a forgotten test root?): remove it, or set TEST = true for a test run; nothing changed"
	end
	Testing = true
end
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
local Travel0 = Root:FindFirstChild("Travel")

-- ===== the markers =====
local PIECES = {"Station", "Clerk", "Board", "Gate", "Railing", "FreightYard", "RoadPassage"} -- build order
-- markers that are not travel pieces: left alone (and listed in the summary). schema.py's NON_TRAVEL_PIECES is the
-- same list. TrainerSpot: Lindenmoor's five spots in the training field, where the hub's trainers are moved to by hand.
local SKIP = {TrainerSpot = true}
-- kinds: string (non-empty), number, integer, boolean, list / object (a STRING holding a JSON list / object)
local NEED = {
	Station = {Route = "string", TrackX = "number", RailTop = "number", NoseZ = "number", PlatformSide = "number"},
	Clerk = {Station = "string"},
	Board = {},
	Gate = {Route = "string"},
	Railing = {Runs = "list", WallTop = "number"},
	FreightYard = {},
	RoadPassage = {Route = "string", To = "string", RoadName = "string", Legs = "list", Threshold = "number", RoadStart = "number",
		Encounters = "list", Half = "number", RoadY = "number", Seed = "integer"},
}
local OPTIONAL = {
	Station = {Arrival = "boolean"},
	Gate = {Sign = "string"},
	RoadPassage = {Arrival = "boolean", Name = "string", FloorY = "number", Cut = "number", High = "number", Gate = "number",
		Fence = "list", Skip = "list", Clip = "object"},
}
local function isList(T) -- a JSON list (an empty table counts: JSON [] and {} decode alike)
	if type(T) ~= "table" then return false end
	local N = 0
	for K in pairs(T) do
		if type(K) ~= "number" or K % 1 ~= 0 or K < 1 then return false end
		N += 1
	end
	return N == #T
end
local function nums(T, N) -- a list of N numbers
	if not isList(T) or #T ~= N then return false end
	for I = 1, N do if type(T[I]) ~= "number" then return false end end
	return true
end
-- the road's length, sampled exactly as Passage samples its centre line (travel_pieces.lua, Passage step 1)
local function roadLength(Legs)
	local S, Len = {}, 0
	for LI, G in ipairs(Legs) do
		local Pts = {}
		if G[1] == "line" then
			local L = math.sqrt((G[4] - G[2]) ^ 2 + (G[5] - G[3]) ^ 2)
			local N = math.max(1, math.ceil(L / 2))
			for I = 0, N do table.insert(Pts, {G[2] + (G[4] - G[2]) * I / N, G[3] + (G[5] - G[3]) * I / N}) end
		else
			local A1, A2 = math.rad(G[5]), math.rad(G[6])
			local N = math.max(1, math.ceil(math.abs(A2 - A1) * G[4] / 2))
			for I = 0, N do
				local A = A1 + (A2 - A1) * I / N
				table.insert(Pts, {G[2] + G[4] * math.cos(A), G[3] + G[4] * math.sin(A)})
			end
		end
		for I, P in ipairs(Pts) do
			if not (LI > 1 and I == 1) then
				local Prev = S[#S]
				if Prev then Len += math.sqrt((P[1] - Prev[1]) ^ 2 + (P[2] - Prev[2]) ^ 2) end
				table.insert(S, P)
			end
		end
	end
	return Len
end

local ByPiece, Errors, Warnings, Count, Skipped = {}, {}, {}, 0, {}
for _, P in ipairs(PIECES) do ByPiece[P] = {} end
local function skipText()
	local L = {}
	for P, N in pairs(Skipped) do table.insert(L, P .. " " .. N) end
	table.sort(L)
	return #L > 0 and ("; skipped (not travel pieces): " .. table.concat(L, ", ")) or ""
end
for _, D in ipairs(Root:GetDescendants()) do
	if D:IsA("BasePart") and CS:HasTag(D, "RenseiMarker") and not (Travel0 and D:IsDescendantOf(Travel0)) then
		local Piece = D:GetAttribute("Piece")
		local W = D:GetFullName()
		local function err(Msg) table.insert(Errors, W .. ": " .. Msg) end
		if type(Piece) == "string" and SKIP[Piece] then
			Skipped[Piece] = (Skipped[Piece] or 0) + 1
		elseif not NEED[Piece] then
			local Known = table.clone(PIECES)
			for P in pairs(SKIP) do table.insert(Known, P .. " (skipped)") end
			err("Piece must be one of " .. table.concat(Known, ", ") .. ", got " .. tostring(Piece))
		else
			local A = {}
			local Need, Opt = NEED[Piece], OPTIONAL[Piece] or {}
			for K, V in pairs(D:GetAttributes()) do
				local Kind = Need[K] or Opt[K]
				if K == "Piece" then
					-- read above
				elseif not Kind then
					local Takes = {}
					for N in pairs(Need) do table.insert(Takes, N) end
					for N in pairs(Opt) do table.insert(Takes, N) end
					table.sort(Takes)
					err("unknown attribute " .. K .. " (a " .. Piece .. " takes " .. (#Takes > 0 and table.concat(Takes, ", ") or "none") .. ")")
				elseif Kind == "list" or Kind == "object" then
					local Ok, J = pcall(HS.JSONDecode, HS, V)
					if type(V) ~= "string" or not Ok or type(J) ~= "table" then
						err(K .. " must be a string holding a JSON " .. Kind)
					elseif Kind == "list" and not isList(J) then
						err(K .. " must be a JSON list, not an object")
					elseif Kind == "object" and (isList(J) or next(J) == nil) then
						err(K .. " must be a non-empty JSON object, not a list")
					else
						A[K] = J
					end
				elseif Kind == "integer" then
					if type(V) ~= "number" or V % 1 ~= 0 then err(K .. " must be a whole number, got " .. tostring(V)) else A[K] = V end
				elseif typeof(V) ~= Kind then
					err(K .. " must be a " .. Kind .. ", got " .. typeof(V))
				elseif Kind == "string" and V == "" then
					err(K .. " is empty")
				else
					A[K] = V
				end
			end
			for K in pairs(Need) do
				if D:GetAttribute(K) == nil then err("missing " .. K) end
			end
			-- shapes
			if Piece == "Station" and A.PlatformSide and A.PlatformSide ~= 1 then
				err("PlatformSide must be 1 (the platform on the track's +X side), got " .. tostring(A.PlatformSide))
			end
			if Piece == "Railing" and A.Runs then
				for I, R in ipairs(A.Runs) do
					if not nums(R, 4) then err("Runs[" .. I .. "] must be [x1, z1, x2, z2]") end
				end
				if #A.Runs == 0 then err("Runs is empty") end
			end
			if Piece == "RoadPassage" then
				local LegsOk = A.Legs ~= nil and #A.Legs > 0
				if A.Legs then
					for I, G in ipairs(A.Legs) do
						local Ok = isList(G) and ((G[1] == "line" and #G == 5) or (G[1] == "arc" and #G == 6))
						for J = 2, Ok and #G or 0 do if type(G[J]) ~= "number" then Ok = false end end
						if not Ok then
							LegsOk = false
							err("Legs[" .. I .. "] must be [\"line\", x1, z1, x2, z2] or [\"arc\", cx, cz, r, a1, a2]")
						end
					end
					if #A.Legs == 0 then err("Legs is empty") end
				end
				for I, S in ipairs(A.Encounters or {}) do
					if type(S) ~= "number" then err("Encounters[" .. I .. "] must be a number") end
				end
				if A.Fence and not nums(A.Fence, 2) then err("Fence must be [s1, s2]") end
				for I, R in ipairs(A.Skip or {}) do
					if not (nums(R, 4) and R[1] < R[3] and R[2] < R[4]) then err("Skip[" .. I .. "] must be [x0, z0, x1, z1] with x0 < x1, z0 < z1") end
				end
				for K, V in pairs(A.Clip or {}) do
					if not (({MinX = 1, MaxX = 1, MinZ = 1, MaxZ = 1})[K] and type(V) == "number") then
						err("Clip." .. tostring(K) .. " must be MinX, MaxX, MinZ or MaxZ, a number")
					end
				end
				if LegsOk and A.RoadStart and A.Threshold then
					local Len = roadLength(A.Legs)
					if not (A.RoadStart >= 0 and A.RoadStart < A.Threshold and A.Threshold <= Len) then
						err(("needs 0 <= RoadStart (%s) < Threshold (%s) <= the road's length (%.1f)"):format(tostring(A.RoadStart), tostring(A.Threshold), Len))
					end
				end
			end
			local Spot = (D.CFrame * CFrame.new(0, -D.Size.Y / 2, 0)).Position
			local L = D.CFrame.LookVector * Vector3.new(1, 0, 1)
			local Look = L.Magnitude > 1e-6 and L.Unit or Vector3.new(0, 0, -1)
			if Piece == "Station" and not Look:FuzzyEq(Vector3.new(0, 0, -1), 1e-3) then
				table.insert(Warnings, W .. ": a Station marker's Yaw is ignored (the station is axis-aligned; set Yaw 0)")
			end
			table.insert(ByPiece[Piece], {Part = D, A = A, Spot = Spot, Look = Look, Name = W})
			Count += 1
		end
	end
end
for _, P in ipairs(PIECES) do table.sort(ByPiece[P], function(X, Y) return X.Name < Y.Name end) end

-- the stations, from their markers (before anything is built)
local OX, OY, OZ = ORIGIN.X, ORIGIN.Y, ORIGIN.Z
local Stations = {}
for _, M in ipairs(ByPiece.Station) do
	local A = M.A
	if A.TrackX and A.RailTop and A.NoseZ and A.Route then
		local TX, RT, NZ = A.TrackX + OX, A.RailTop + OY, A.NoseZ + OZ
		table.insert(Stations, {M = M, Route = A.Route, TX = TX, RT = RT, NZ = NZ, Top = RT + 1.8,
			Centre = Vector3.new(TX + 12, 0, NZ - 275), Arrival = A.Arrival ~= false})
	end
end
local function stationFor(M)
	local Best, BD
	for _, S in ipairs(Stations) do
		if M.A.Route and S.Route == M.A.Route then return S end
		local D = (S.Centre - Vector3.new(M.Spot.X, 0, M.Spot.Z)).Magnitude
		if not BD or D < BD then Best, BD = S, D end
	end
	return Best
end

-- the place outside the build: a real run scans workspace, a test run RegionSetupRoot and ServerStorage.RegionSetupPlace
-- (both outside the old Travel, which the build replaces)
local Have = {Point = {}, Platform = {}, Ride = {}}
do
	local Scopes = Testing and {Root, SS:FindFirstChild("RegionSetupPlace")} or {workspace}
	for _, Sc in ipairs(Scopes) do
		if Sc then
			for _, D in ipairs(Sc:GetDescendants()) do
				if not (Travel0 and D:IsDescendantOf(Travel0)) then
					if CS:HasTag(D, "RenseiArrival") and D:GetAttribute("Point") then
						Have.Point[D:GetAttribute("Point")] = D:GetFullName()
					end
					if CS:HasTag(D, "RenseiPlatformTrain") and D:GetAttribute("Route") then
						Have.Platform[D:GetAttribute("Route")] = D:GetFullName()
					end
					if CS:HasTag(D, "RenseiRideTrain") and D:GetAttribute("Route") then
						Have.Ride[D:GetAttribute("Route")] = D:GetFullName()
					end
				end
			end
		end
	end
end

-- whole-set rules
if (#ByPiece.Gate + #ByPiece.FreightYard) > 0 and #Stations == 0 then
	table.insert(Errors, "a Gate or FreightYard marker needs a Station marker")
end
local Platforms, RoadStarts = 0, 0
for _, S in ipairs(Stations) do if S.Arrival then Platforms += 1 end end
for _, M in ipairs(ByPiece.RoadPassage) do if M.A.Arrival ~= false then RoadStarts += 1 end end
if Platforms > 1 then table.insert(Errors, "one Platform arrival per place: set Arrival = false on every Station but one") end
if RoadStarts > 1 then table.insert(Errors, "one RoadStart arrival per place: set Arrival = false on every RoadPassage but one") end
if Platforms > 0 and Have.Point.Platform then
	table.insert(Errors, "the place already has a Platform arrival (" .. Have.Point.Platform .. "): set Arrival = false on the Station")
end
if RoadStarts > 0 and Have.Point.RoadStart then
	table.insert(Errors, "the place already has a RoadStart arrival (" .. Have.Point.RoadStart .. "): set Arrival = false on the RoadPassage")
end
local Routes = {}
for _, S in ipairs(Stations) do
	if Routes[S.Route] then table.insert(Errors, "two Station markers for route " .. S.Route) end
	Routes[S.Route] = true
	if Have.Platform[S.Route] or Have.Ride[S.Route] then
		table.insert(Errors, "the place already has a train for route " .. S.Route .. " (" .. (Have.Platform[S.Route] or Have.Ride[S.Route]) .. ")")
	end
end
for _, M in ipairs(ByPiece.Gate) do
	if M.A.Route and not (Routes[M.A.Route] or Have.Platform[M.A.Route]) then
		table.insert(Errors, M.Name .. ": Route " .. M.A.Route .. " is no platform train's Route here (a Station marker's, or one already in the place)")
	end
	local S = stationFor(M)
	if S and not (S.Top - M.Spot.Y > 0) then
		table.insert(Errors, ("%s: the spot (y %.2f) must be below the platform top (%.2f): the ramp runs from the ground up to it"):format(M.Name, M.Spot.Y, S.Top))
	end
end
local Kit
if #Stations > 0 then
	Kit = SS:FindFirstChild(KIT_NAME)
	local KitOk, KitErr = pcall(TP.checkKit, Kit)
	if not KitOk then table.insert(Errors, tostring(KitErr)) end
end
if #Errors > 0 then
	return "setup refused (" .. #Errors .. " problem(s)); nothing changed:\n  " .. table.concat(Errors, "\n  ")
end
if Count == 0 then return "setup: no travel RenseiMarker parts under " .. Root:GetFullName() .. "; nothing changed" .. skipText() end

-- ===== build (into an unparented Travel) =====
local Travel = Instance.new("Model")
Travel.Name = "Travel"
Travel:SetAttribute("RegionSetup", Child)
local Info = {Stations = {}, Roads = {}}
local function Build()
	-- Station: Foundry's track and platform (station_foundry.lua:77-95) and the two trains (:164-165)
	for _, S in ipairs(Stations) do
		local St = Instance.new("Model")
		St.Name = #Stations > 1 and ("Station_" .. S.Route) or "Station"
		St.Parent = Travel
		local TX, RT, NZ = S.TX, S.RT, S.NZ
		S.Platform = TP.part("Platform", Vector3.new(12, 2.4, 340), CFrame.new(TX + 12, RT + 0.6, NZ - 275), Enum.Material.Cobblestone, Color3.fromRGB(122, 118, 108), St)
		for _, X in ipairs({TX - 2.6, TX + 2.6}) do
			TP.part("Rail", Vector3.new(0.5, 0.6, 500), CFrame.new(X, RT - 0.3, NZ - 240), Enum.Material.Metal, Color3.fromRGB(58, 56, 53), St)
		end
		for _, DZ in ipairs({-251, 251}) do
			TP.part("BufferStop", Vector3.new(7, 2.6, 1.6), CFrame.new(TX, RT + 1, NZ - 240 + DZ), Enum.Material.Wood, Color3.fromRGB(110, 40, 32), St)
		end
		if S.Arrival then TP.arrival("Platform", Vector3.new(TX + 12, RT + 2.4, NZ - 240), St) end
		S.Train = TP.lay("PlatformTrain", Vector3.new(TX, RT, NZ), S.Route, "RenseiPlatformTrain", St, Kit)
		TP.lay("RideTrain", Vector3.new(TX, RT, NZ) + RIDE_OFFSET, S.Route, "RenseiRideTrain", St, Kit)
		S.Model = St
		table.insert(Info.Stations, S.Route)
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
		local Road, R = TP.Passage({
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
		if A.Arrival == false then -- Passage always lays one; this road's travellers arrive elsewhere
			local Arr = Road:FindFirstChild("Arrival_RoadStart")
			if Arr then Arr:Destroy() end
		end
		table.insert(Info.Roads, ("%s %d studs, %d slabs, %d trees, %d rocks, %d encounters%s"):format(A.Name or A.Route, R.Length, R.Slabs,
			R.Trees, R.Rocks, R.Encounters, A.Arrival == false and ", no arrival" or ""))
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
	if Old:GetAttribute("RegionSetup") ~= nil then
		Backup = "none (the old Travel was setup's own)"
	else
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
			Backup = "kept RenseiBackups." .. BName .. " (the first hand-made Travel)"
		end
	end
end
if Old then Old:Destroy() end
Travel.Parent = Root

local Parts, Tags = 0, {}
for _, D in ipairs(Travel:GetDescendants()) do
	if D:IsA("BasePart") then Parts += 1 end
	for _, T in ipairs(CS:GetTags(D)) do Tags[T] = (Tags[T] or 0) + 1 end
end
local TagList = {}
for T, N in pairs(Tags) do table.insert(TagList, T .. " " .. N) end
table.sort(TagList)
local PieceList = {}
for _, P in ipairs(PIECES) do if #ByPiece[P] > 0 then table.insert(PieceList, P .. " " .. #ByPiece[P]) end end
return ("setup ok (%s): %s.Travel from %d markers (%s), %d parts; stations %s; roads: %s; tags: %s; replaced old Travel: %s; backup: %s%s%s"):format(
	Testing and "test root" or "Map." .. Child, Root:GetFullName(), Count, table.concat(PieceList, ", "), Parts,
	#Info.Stations > 0 and table.concat(Info.Stations, ", ") or "none", #Info.Roads > 0 and table.concat(Info.Roads, "; ") or "none",
	table.concat(TagList, ", "), Old and "yes" or "no", Backup, skipText(),
	#Warnings > 0 and ("\n  WARNING " .. table.concat(Warnings, "\n  WARNING ")) or "")

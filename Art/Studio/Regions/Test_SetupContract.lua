-- Test_SetupContract (Region Foundation Task 12, 2026-10-24; fix round 1): the travel contract the services read, checked
-- on a built region. A ModuleScript source returning Check(ROOT, PLACE) -> "PASS n / FAIL n" plus one line per failed
-- check (and a "SKIP" line per rule that doesn't apply).
--   ROOT: the region's map child (workspace.World.Map.<MapChild>), or ServerStorage.RegionSetupRoot in a test run.
--   PLACE (optional): what else is in the place. Default: workspace when ROOT is under workspace, else nothing. In a test
--     run pass ServerStorage.RegionSetupPlace (setup's stand-in for the rest of the place).
-- The pieces are checked in ROOT. The one-per-place rules (exactly one arrival per Point, one platform and one ride train
-- per Route) and the lookups they need (a gate's line, the ride trains' clearance) are checked over ROOT + PLACE, since
-- TravelService.ArrivalPoint and StationService.TrainOf take the first match in workspace.
-- A root without a station (no Station marker, no platform train) skips the station rules, and one without a road skips
-- the road rules, so an expansion beside a kept village (Lindenmoor) can pass; "exactly one Platform / RoadStart" still
-- applies when the root or the place has a station / road.
-- Bundle and run: python -I Art/Studio/Regions/bundle_setup.py contract <out.lua> <root> [<place>].
-- The rules (TravelService, StationService, RoadService, TravelClient; the plan's contract list) are the named checks below.
local CS = game:GetService("CollectionService")

local EPS = 0.01 -- studs (and unit-vector components)
local RIDE_CLEAR = 300 -- PROPOSAL (the contract): a ride train's bottom stands at least this far above every map part
local RIDE_GAP = 50 -- PROPOSAL: ride trains' boxes stay at least this far apart

return function(ROOT, PLACE)
	local Pass, Fails, Skips = 0, {}, {}
	local function check(Name, Ok, Detail)
		if Ok then
			Pass += 1
		else
			table.insert(Fails, Name .. (Detail ~= nil and (": " .. tostring(Detail)) or ""))
		end
	end
	local function skip(Name, Why) table.insert(Skips, Name .. " (" .. Why .. ")") end
	if typeof(ROOT) ~= "Instance" then
		return "PASS 0 / FAIL 1\nFAIL ROOT is not an Instance"
	end
	if PLACE == nil and ROOT:IsDescendantOf(workspace) then PLACE = workspace end
	local All = ROOT:GetDescendants()
	local Everything = All -- ROOT + PLACE
	if PLACE then
		Everything = {}
		for _, D in ipairs(All) do table.insert(Everything, D) end
		if not ROOT:IsDescendantOf(PLACE) then
			for _, D in ipairs(PLACE:GetDescendants()) do table.insert(Everything, D) end
		else
			Everything = PLACE:GetDescendants()
		end
	end
	local function tagged(Tag, List)
		local L = {}
		for _, D in ipairs(List or All) do
			if CS:HasTag(D, Tag) then table.insert(L, D) end
		end
		return L
	end
	local function near(A, B, E) return math.abs(A - B) <= (E or EPS) end
	local function nearV(A, B, E) return (A - B).Magnitude <= (E or EPS) end
	local function str(V) return type(V) == "string" and V ~= "" end
	local function inBox(Part, Pos) -- Pos inside Part's box
		local L = Part.CFrame:PointToObjectSpace(Pos)
		return math.abs(L.X) <= Part.Size.X / 2 and math.abs(L.Y) <= Part.Size.Y / 2 and math.abs(L.Z) <= Part.Size.Z / 2
	end
	local function inXZ(Part, Pos) -- Pos over Part's footprint (any height)
		local L = Part.CFrame:PointToObjectSpace(Pos)
		return math.abs(L.X) <= Part.Size.X / 2 and math.abs(L.Z) <= Part.Size.Z / 2
	end
	local function markers(Piece)
		local N = 0
		for _, D in ipairs(All) do
			if CS:HasTag(D, "RenseiMarker") and D:GetAttribute("Piece") == Piece then N += 1 end
		end
		return N
	end

	local Platforms, Rides = tagged("RenseiPlatformTrain"), tagged("RenseiRideTrain")
	local PlacePlatforms, PlaceRides = tagged("RenseiPlatformTrain", Everything), tagged("RenseiRideTrain", Everything)
	local RootStation = #Platforms > 0 or markers("Station") > 0
	local PlaceStation = #PlacePlatforms > 0 or RootStation
	local RootRoad = #tagged("RenseiRoadPassage") > 0 or markers("RoadPassage") > 0
	local PlaceRoad = #tagged("RenseiRoadPassage", Everything) > 0 or RootRoad
	local PlatformParts = {}
	for _, D in ipairs(All) do
		if D:IsA("BasePart") and D.Name == "Platform" then table.insert(PlatformParts, D) end
	end
	local RailParts = {}
	for _, D in ipairs(All) do
		if D:IsA("BasePart") and D.Name == "Rail" then table.insert(RailParts, D) end
	end

	-- ===== Trains =====
	if RootStation then
		check("trains: a RenseiPlatformTrain exists", #Platforms >= 1, #Platforms)
	else
		skip("trains: a RenseiPlatformTrain exists", "the root has no station")
	end
	if RootStation or #PlacePlatforms > 0 then
		check("trains: a RenseiRideTrain exists", #PlaceRides >= 1, #PlaceRides)
	else
		skip("trains: a RenseiRideTrain exists", "no station in the root or the place")
	end
	local function trainChecks(T, Kind)
		local W = T:GetFullName()
		check(Kind .. " is a Model", T:IsA("Model"), W)
		if not T:IsA("Model") then return end
		check(Kind .. " has a Route", str(T:GetAttribute("Route")), W)
		check(Kind .. " has Length = 440", T:GetAttribute("Length") == 440, T:GetAttribute("Length"))
		local P = T.WorldPivot
		check(Kind .. " pivot has identity rotation", P.LookVector:FuzzyEq(Vector3.new(0, 0, -1), EPS) and P.UpVector:FuzzyEq(Vector3.new(0, 1, 0), EPS), tostring(P))
		local Cars, AllCarsModels, Behind = 0, true, true
		local Loco
		for _, C in ipairs(T:GetChildren()) do
			if C:IsA("Model") then
				Cars += 1
				if C:GetPivot().Position.Z > P.Position.Z + EPS then Behind = false end
				if C.Name == "Locomotive_Main" then Loco = C end
			elseif C:IsA("BasePart") and C.Name ~= "RideBlock" then
				AllCarsModels = false
			end
		end
		check(Kind .. " cars are direct child Models", Cars >= 7 and AllCarsModels, Cars)
		check(Kind .. " runs along -Z of its pivot", Behind)
		-- the nose at the pivot: the locomotive's middle is half its 72 behind, on the pivot's line (the kit's pivots are at
		-- the wheel bottoms, i.e. rail top)
		check(Kind .. " pivot is the nose (the locomotive 36 behind it)", Loco ~= nil and nearV(Loco:GetPivot().Position, P.Position + Vector3.new(0, 0, -36)),
			Loco and tostring(Loco:GetPivot().Position - P.Position))
		if Kind == "platform train" then
			-- rail top: the Rail parts under the train (centre 2.6 either side of the track) reach the pivot's height
			local Tops, Under = {}, 0
			for _, R in ipairs(RailParts) do
				if math.abs(math.abs(R.Position.X - P.Position.X) - 2.6) <= 0.5 then
					Under += 1
					table.insert(Tops, R.Position.Y + R.Size.Y / 2)
				end
			end
			local Ok = Under >= 2
			for _, Y in ipairs(Tops) do if not near(Y, P.Position.Y) then Ok = false end end
			check(Kind .. " pivot is at rail top (two Rails, top = pivot y)", Ok, ("%d rails, tops %s, pivot y %.3f"):format(Under, table.concat(Tops, "/"), P.Position.Y))
		end
		local CarKinds, Zones, ZonesOk, Doors, DoorsOk, Stow = 0, 0, true, 0, true, nil
		for _, D in ipairs(T:GetDescendants()) do
			if D:GetAttribute("CarKind") ~= nil then CarKinds += 1 end
			if D:IsA("BasePart") and D.Name:find("BoardZone") then
				Zones += 1
				if not str(D:GetAttribute("CarKind")) then ZonesOk = false end
			end
			if D:IsA("BasePart") and D.Name:find("CarDoor") then
				Doors += 1
				if not str(D:GetAttribute("CarKind")) then DoorsOk = false end
			end
			if D:IsA("BasePart") and D.Name:find("StowZone") then Stow = D end
		end
		check(Kind .. " has CarKind descendants", CarKinds > 0, CarKinds)
		check(Kind .. " BoardZone parts carry CarKind", Zones > 0 and ZonesOk, Zones)
		check(Kind .. " CarDoor parts carry CarKind", Doors > 0 and DoorsOk, Doors)
		check(Kind .. " has a StowZone", Stow ~= nil)
		if Kind == "platform train" and Stow then
			check(Kind .. " StowZone faces -X (the platform is on +X)", Stow.Position.X < P.Position.X - EPS, Stow.Position.X - P.Position.X)
		end
	end
	for _, T in ipairs(Platforms) do trainChecks(T, "platform train") end
	for _, T in ipairs(Rides) do trainChecks(T, "ride train") end
	-- one platform and one ride train per Route, place-wide
	local PerRoute = {}
	for _, T in ipairs(PlacePlatforms) do
		local R = tostring(T:GetAttribute("Route"))
		PerRoute[R] = PerRoute[R] or {0, 0}
		PerRoute[R][1] += 1
	end
	for _, T in ipairs(PlaceRides) do
		local R = tostring(T:GetAttribute("Route"))
		PerRoute[R] = PerRoute[R] or {0, 0}
		PerRoute[R][2] += 1
	end
	for R, N in pairs(PerRoute) do
		check("route " .. R .. ": one platform train and one ride train" .. (PLACE and " in the place" or ""), N[1] == 1 and N[2] == 1, ("%d platform, %d ride"):format(N[1], N[2]))
	end
	-- the ride trains: identity rotation (above), well clear of the place (the contract: StationService only uses the
	-- ride-to-platform offset): their bottoms RIDE_CLEAR above every visible or solid map part, and apart from each other
	if #Rides > 0 then
		local RideSet = {}
		for _, T in ipairs(PlaceRides) do RideSet[T] = true end
		local function inRide(D)
			for T in pairs(RideSet) do if D:IsDescendantOf(T) then return true end end
			return false
		end
		local MapList = All
		if PLACE then
			local World = workspace:FindFirstChild("World")
			local Map = PLACE == workspace and World and World:FindFirstChild("Map")
			MapList = {}
			for _, D in ipairs(All) do table.insert(MapList, D) end
			for _, D in ipairs(Map and Map:GetDescendants() or PLACE:GetDescendants()) do
				if not D:IsDescendantOf(ROOT) then table.insert(MapList, D) end
			end
		end
		local High, HighName = -math.huge, "nothing"
		for _, D in ipairs(MapList) do
			if D:IsA("BasePart") and (D.CanCollide or D.Transparency < 1) and not inRide(D) then
				local _, Size = D.CFrame, D.Size
				local Top = D.Position.Y + (math.abs(D.CFrame.RightVector.Y) * Size.X + math.abs(D.CFrame.UpVector.Y) * Size.Y + math.abs(D.CFrame.LookVector.Y) * Size.Z) / 2
				if Top > High then High, HighName = Top, D:GetFullName() end
			end
		end
		local Boxes = {}
		for _, T in ipairs(PlaceRides) do
			local CF, Size = T:GetBoundingBox()
			table.insert(Boxes, {T, CF.Position - Size / 2, CF.Position + Size / 2})
		end
		for _, B in ipairs(Boxes) do
			if B[1]:IsDescendantOf(ROOT) then
				check("ride train " .. tostring(B[1]:GetAttribute("Route")) .. " stands " .. RIDE_CLEAR .. "+ above every map part",
					B[2].Y - High >= RIDE_CLEAR, ("bottom %.1f, highest %.1f (%s)"):format(B[2].Y, High, HighName))
				for _, C in ipairs(Boxes) do
					if C[1] ~= B[1] then
						local Apart = B[3].X + RIDE_GAP < C[2].X or C[3].X + RIDE_GAP < B[2].X or B[3].Y + RIDE_GAP < C[2].Y or C[3].Y + RIDE_GAP < B[2].Y
							or B[3].Z + RIDE_GAP < C[2].Z or C[3].Z + RIDE_GAP < B[2].Z
						check("ride train " .. tostring(B[1]:GetAttribute("Route")) .. " is clear of ride train " .. tostring(C[1]:GetAttribute("Route")), Apart)
					end
				end
			end
		end
	end
	-- the platform (a part named Platform) stands on the +X side of each platform train's track
	for _, T in ipairs(Platforms) do
		local X = T.WorldPivot.Position.X
		local Best
		for _, P in ipairs(PlatformParts) do
			if not Best or math.abs(P.Position.X - X) < math.abs(Best.Position.X - X) then Best = P end
		end
		check("platform part is on the track's +X side", Best ~= nil and Best.Position.X - Best.Size.X / 2 > X + EPS,
			Best and (Best.Position.X - Best.Size.X / 2 - X))
	end

	-- ===== Station pieces =====
	local PlaceRoutes = {}
	for _, T in ipairs(PlacePlatforms) do PlaceRoutes[T:GetAttribute("Route") or ""] = true end
	local Clerks, Boards, Gates, Yards = tagged("RenseiTicketClerk"), tagged("RenseiDepartureBoard"), tagged("RenseiStationGate"), tagged("RenseiFreightYard")
	if RootStation then
		check("station: a RenseiTicketClerk exists", #Clerks >= 1, #Clerks)
		check("station: a RenseiDepartureBoard exists", #Boards >= 1, #Boards)
		check("station: a RenseiStationGate exists", #Gates >= 1, #Gates)
		check("freight yard: a RenseiFreightYard zone exists", #Yards >= 1, #Yards)
	else
		skip("station: clerk, board, gate and freight yard exist", "the root has no station")
	end
	for _, C in ipairs(Clerks) do
		check("clerk is a BasePart", C:IsA("BasePart"), C.ClassName)
		check("clerk has a Station", str(C:GetAttribute("Station")), C:GetAttribute("Station"))
	end
	for _, B in ipairs(Boards) do
		check("board is a BasePart", B:IsA("BasePart"), B.ClassName)
		if B:IsA("BasePart") then
			-- readable: its Front face is upright (level LookVector), and what it faces is a standing area (the platform
			-- or the hall), not the track bed: 6 studs ahead is over a Platform part or more than 4 from every track
			local L = B.CFrame.LookVector
			check("board's Front face is upright", near(L.Y, 0), L.Y)
			local Ahead = B.Position + Vector3.new(L.X, 0, L.Z).Unit * 6
			local Ok = false
			for _, P in ipairs(PlatformParts) do
				if inXZ(P, Ahead) then Ok = true end
			end
			if not Ok then
				Ok = true
				for _, T in ipairs(PlacePlatforms) do
					if math.abs(Ahead.X - T.WorldPivot.Position.X) <= 4 then Ok = false end
				end
			end
			check("board's Front face looks at a standing area, not the track", Ok, tostring(Ahead))
		end
	end
	for _, G in ipairs(Gates) do
		check("gate is a BasePart", G:IsA("BasePart"), G.ClassName)
		if G:IsA("BasePart") then
			check("gate is 8 x 8 x 1", nearV(G.Size, Vector3.new(8, 8, 1)), tostring(G.Size))
			check("gate CanTouch is true", G.CanTouch == true)
			local R = G:GetAttribute("Route")
			check("gate Route is absent or a platform train's Route in the place", R == nil or (str(R) and PlaceRoutes[R] == true), R)
			-- LookVector onto the platform: 3 studs ahead (gate level) is over a Platform part
			local Ahead = G.Position + G.CFrame.LookVector * 3
			local On = false
			for _, P in ipairs(PlatformParts) do
				if inXZ(P, Ahead) then On = true end
			end
			check("gate LookVector points onto the platform", On, tostring(Ahead))
		end
	end
	for _, Y in ipairs(Yards) do
		check("freight yard zone is a BasePart", Y:IsA("BasePart"), Y.ClassName)
		local Man = Y.Parent and Y.Parent:FindFirstChild("YardWatchman")
		check("YardWatchman is under the zone's parent model", Man ~= nil and Man:IsA("Model") and Y.Parent:IsA("Model"))
		check("YardWatchman is a RenseiWatcher", Man ~= nil and CS:HasTag(Man, "RenseiWatcher"))
	end

	-- ===== Arrivals: exactly one per Point (place-wide when there is a place) =====
	local Arrivals, PlaceArrivals = tagged("RenseiArrival"), tagged("RenseiArrival", Everything)
	local ByPoint, RootByPoint = {}, {}
	for _, A in ipairs(PlaceArrivals) do
		local P = tostring(A:GetAttribute("Point"))
		ByPoint[P] = ByPoint[P] or {}
		table.insert(ByPoint[P], A)
	end
	for _, A in ipairs(Arrivals) do
		local P = tostring(A:GetAttribute("Point"))
		RootByPoint[P] = RootByPoint[P] or {}
		table.insert(RootByPoint[P], A)
	end
	local Where = PLACE and " in the place" or ""
	if PlaceStation then
		check("arrivals: exactly one Platform" .. Where, ByPoint.Platform ~= nil and #ByPoint.Platform == 1, ByPoint.Platform and #ByPoint.Platform or 0)
	else
		skip("arrivals: exactly one Platform", "no station in the root or the place")
	end
	if PlaceRoad then
		check("arrivals: exactly one RoadStart" .. Where, ByPoint.RoadStart ~= nil and #ByPoint.RoadStart == 1, ByPoint.RoadStart and #ByPoint.RoadStart or 0)
	else
		skip("arrivals: exactly one RoadStart", "no road in the root or the place")
	end
	for P, L in pairs(ByPoint) do
		if P ~= "Platform" and P ~= "RoadStart" then
			check("arrivals: at most one " .. P .. Where, #L == 1, #L)
		end
	end
	for _, A in ipairs(Arrivals) do
		check("arrival " .. tostring(A:GetAttribute("Point")) .. " is a BasePart", A:IsA("BasePart"))
		if A:IsA("BasePart") then
			check("arrival " .. tostring(A:GetAttribute("Point")) .. " stands upright (level LookVector)", near(A.CFrame.LookVector.Y, 0), A.CFrame.LookVector.Y)
		end
	end
	for _, A in ipairs(RootByPoint.Platform or {}) do
		if A:IsA("BasePart") then
			local On = false
			for _, P in ipairs(PlatformParts) do
				if inXZ(P, A.Position) and A.Position.Y > P.Position.Y + P.Size.Y / 2 - EPS then On = true end
			end
			check("arrival Platform stands on the platform", On, tostring(A.Position))
			-- inward on a platform: along the track (the platform's length), so arrivals face down the platform
			check("arrival Platform faces along the platform (the track's axis)", math.abs(A.CFrame.LookVector.Z) > 1 - EPS, tostring(A.CFrame.LookVector))
		end
	end

	-- ===== Road passage =====
	local Legs, Points = tagged("RenseiRoadPassage"), {}
	if RootRoad then
		check("road: RenseiRoadPassage legs exist", #Legs >= 1, #Legs)
	else
		skip("road: passage, threshold and encounters exist", "the root has no road")
	end
	local Routes = {}
	for _, L in ipairs(Legs) do
		local W = L:GetFullName()
		check("road leg is a BasePart", L:IsA("BasePart"), W)
		check("road leg has Route, To, RoadName", str(L:GetAttribute("Route")) and str(L:GetAttribute("To")) and str(L:GetAttribute("RoadName")), W)
		check("road leg has a whole Leg >= 1", type(L:GetAttribute("Leg")) == "number" and L:GetAttribute("Leg") >= 1 and L:GetAttribute("Leg") % 1 == 0, L:GetAttribute("Leg"))
		local R = L:GetAttribute("Route")
		if R then
			Routes[R] = Routes[R] or {}
			Routes[R][L:GetAttribute("Leg") or 0] = L
		end
		for _, A in ipairs(L:GetChildren()) do
			if A:IsA("Attachment") and A.Name == "RoadPoint" then
				table.insert(Points, {A, R})
			end
		end
	end
	if RootRoad then
		local PointsOk = #Points > 0
		for _, P in ipairs(Points) do
			if type(P[1]:GetAttribute("S")) ~= "number" then PointsOk = false end
		end
		check("road: RoadPoint attachments carry S", PointsOk, #Points)
	end
	local function nearestPoint(Route, Pos)
		local Best, BD
		for _, P in ipairs(Points) do
			if P[2] == Route then
				local D = (P[1].WorldPosition - Pos).Magnitude
				if not BD or D < BD then Best, BD = P[1], D end
			end
		end
		return Best
	end
	for Route, ByLeg in pairs(Routes) do
		local Leg1 = ByLeg[1]
		check("road " .. Route .. " has a Leg 1 (the mouth)", Leg1 ~= nil)
		local Mouth
		for _, P in ipairs(Points) do
			if P[2] == Route and P[1]:GetAttribute("S") == 0 then Mouth = P[1] end
		end
		check("road " .. Route .. " has a RoadPoint at S = 0", Mouth ~= nil)
		if Leg1 and Mouth then
			-- the walk starts only in leg 1 alone: across the mouth and the first 16 studs in (every 2 studs along, every 2
			-- across to 12 each side, at 1, 3 and 5 above the road: where a walker's root is), every sample inside leg 1 is
			-- inside no other leg; the mouth itself must be inside leg 1
			local CF = Mouth.WorldCFrame
			local Alone, Bad, Samples = inBox(Leg1, CF.Position + Vector3.new(0, 3, 0)), nil, 0
			for Along = 0, 16, 2 do
				for Lat = -12, 12, 2 do
					for _, Up in ipairs({1, 3, 5}) do
						local Q = CF.Position + CF.LookVector * Along + CF.RightVector * Lat + Vector3.new(0, Up, 0)
						if inBox(Leg1, Q) then
							Samples += 1
							for N, L in pairs(ByLeg) do
								if N ~= 1 and inBox(L, Q) then Alone, Bad = false, tostring(Q) .. " in leg " .. N end
							end
						end
					end
				end
			end
			check("road " .. Route .. " Leg 1 alone at the mouth (" .. Samples .. " samples)", Alone and Samples > 0, Bad)
		end
	end
	local Ths, Encs = tagged("RenseiRoadThreshold"), tagged("RenseiRoadEncounter")
	if RootRoad then
		check("road: a RenseiRoadThreshold exists", #Ths >= 1, #Ths)
		check("road: RenseiRoadEncounter parts exist", #Encs >= 1, #Encs)
	end
	for _, T in ipairs(Ths) do
		check("threshold has Route and To", str(T:GetAttribute("Route")) and str(T:GetAttribute("To")))
		local P = T:IsA("BasePart") and nearestPoint(T:GetAttribute("Route"), T.Position)
		check("threshold LookVector points out (along the road's way out)", P and T.CFrame.LookVector:Dot(P.WorldCFrame.LookVector) > 0.9,
			P and T.CFrame.LookVector:Dot(P.WorldCFrame.LookVector))
	end
	for _, E in ipairs(Encs) do
		local W = E.Name
		check("encounter " .. W .. " has Route and Order", str(E:GetAttribute("Route")) and type(E:GetAttribute("Order")) == "number")
		local Out, In, Bad = 0, 0, 0
		for _, A in ipairs(E:GetChildren()) do
			if A:IsA("Attachment") and A.Name == "SpawnPoint" then
				local S = A:GetAttribute("Side")
				if S == "Out" then Out += 1 elseif S == "In" then In += 1 else Bad += 1 end
			end
		end
		check("encounter " .. W .. " has SpawnPoints on both Sides (Out and In only)", Out > 0 and In > 0 and Bad == 0, ("%d/%d/%d"):format(Out, In, Bad))
		local P = E:IsA("BasePart") and nearestPoint(E:GetAttribute("Route"), E.Position)
		-- local +Z = the town side: LookVector (-Z) along the way out
		check("encounter " .. W .. " local +Z is the town side", P and E.CFrame.LookVector:Dot(P.WorldCFrame.LookVector) > 0.9,
			P and E.CFrame.LookVector:Dot(P.WorldCFrame.LookVector))
	end
	for _, A in ipairs(RootByPoint.RoadStart or {}) do
		local Route
		for _, L in ipairs(Legs) do
			if L:IsA("BasePart") and inXZ(L, A.Position) then Route = L:GetAttribute("Route") end
		end
		local P = Route and nearestPoint(Route, A.Position)
		check("arrival RoadStart is on a passage and looks inward (against the way out)", P and A.CFrame.LookVector:Dot(P.WorldCFrame.LookVector) < -0.9,
			P and A.CFrame.LookVector:Dot(P.WorldCFrame.LookVector))
	end

	-- ===== Areas =====
	local Areas = tagged("RenseiArea")
	check("areas: a RenseiArea exists", #Areas >= 1, #Areas)
	for _, A in ipairs(Areas) do
		check("area " .. A.Name .. " has an AreaName", str(A:GetAttribute("AreaName")))
	end

	local Lines = {("PASS %d / FAIL %d"):format(Pass, #Fails)}
	for _, F in ipairs(Fails) do table.insert(Lines, "FAIL " .. F) end
	for _, S in ipairs(Skips) do table.insert(Lines, "SKIP " .. S) end
	return table.concat(Lines, "\n")
end

-- Test_SetupContract (Region Foundation Task 12, 2026-10-24): the travel contract the services read, checked on a built
-- region. A ModuleScript source returning Check(ROOT) -> "PASS n / FAIL n" plus one line per failed check.
-- ROOT: the region's map child (workspace.World.Map.<MapChild>), or ServerStorage.RegionSetupRoot in a test run. Only
-- ROOT's descendants count (CollectionService:HasTag on each), so a test root in ServerStorage is checked alone.
-- Run it in Edit, e.g. a bundle of
--     local Check = (function() <this file> end)()
--     return Check(game.ServerStorage.RegionSetupRoot)
-- The rules (from TravelService, StationService, RoadService and TravelClient; the brief's contract list):
--   trains, station pieces, freight yard, arrivals, road passage, areas. Each rule is one named check below.
local CS = game:GetService("CollectionService")

local EPS = 0.01 -- studs (and unit-vector components)

return function(ROOT)
	local Pass, Fails = 0, {}
	local function check(Name, Ok, Detail)
		if Ok then
			Pass += 1
		else
			table.insert(Fails, Name .. (Detail and (": " .. tostring(Detail)) or ""))
		end
	end
	if typeof(ROOT) ~= "Instance" then
		return "PASS 0 / FAIL 1\nFAIL ROOT is not an Instance"
	end
	local All = ROOT:GetDescendants()
	local function tagged(Tag)
		local L = {}
		for _, D in ipairs(All) do
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

	-- ===== Trains =====
	local Platforms, Rides = tagged("RenseiPlatformTrain"), tagged("RenseiRideTrain")
	check("trains: a RenseiPlatformTrain exists", #Platforms >= 1, #Platforms)
	check("trains: a RenseiRideTrain exists", #Rides >= 1, #Rides)
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
		-- the nose at the pivot: the locomotive's middle is half its 72 behind, on the pivot's line, at rail top
		check(Kind .. " pivot is the nose at rail top", Loco ~= nil and nearV(Loco:GetPivot().Position, P.Position + Vector3.new(0, 0, -36)),
			Loco and tostring(Loco:GetPivot().Position - P.Position))
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
	for _, T in ipairs(Platforms) do
		local Route = T:GetAttribute("Route")
		local Ride
		for _, R in ipairs(Rides) do
			if R:GetAttribute("Route") == Route then Ride = R end
		end
		check("ride train for " .. tostring(Route) .. " exists", Ride ~= nil)
		if Ride then
			local Want = T.WorldPivot.Position + Vector3.new(0, 400, -1600)
			check("ride train sits at platform pivot + (0, 400, -1600)", nearV(Ride.WorldPivot.Position, Want), tostring(Ride.WorldPivot.Position - Want))
		end
	end

	-- the platform parts (named Platform) and the arrival Platform stand on the +X side of each platform train's track
	local PlatformParts = {}
	for _, D in ipairs(All) do
		if D:IsA("BasePart") and D.Name == "Platform" then table.insert(PlatformParts, D) end
	end
	local Arrivals = tagged("RenseiArrival")
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
	local Clerks = tagged("RenseiTicketClerk")
	check("station: a RenseiTicketClerk exists", #Clerks >= 1, #Clerks)
	for _, C in ipairs(Clerks) do
		check("clerk is a BasePart", C:IsA("BasePart"), C.ClassName)
		check("clerk has a Station", str(C:GetAttribute("Station")), C:GetAttribute("Station"))
	end
	local Boards = tagged("RenseiDepartureBoard")
	check("station: a RenseiDepartureBoard exists", #Boards >= 1, #Boards)
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
				for _, T in ipairs(Platforms) do
					if math.abs(Ahead.X - T.WorldPivot.Position.X) <= 4 then Ok = false end
				end
			end
			check("board's Front face looks at a standing area, not the track", Ok, tostring(Ahead))
		end
	end
	local Gates = tagged("RenseiStationGate")
	check("station: a RenseiStationGate exists", #Gates >= 1, #Gates)
	for _, G in ipairs(Gates) do
		check("gate is a BasePart", G:IsA("BasePart"), G.ClassName)
		if G:IsA("BasePart") then
			check("gate is 8 x 8 x 1", nearV(G.Size, Vector3.new(8, 8, 1)), tostring(G.Size))
			check("gate CanTouch is true", G.CanTouch == true)
			local R = G:GetAttribute("Route")
			check("gate Route is absent or a route id", R == nil or str(R), R)
			-- LookVector onto the platform: 3 studs ahead (gate level) is over a Platform part
			local Ahead = G.Position + G.CFrame.LookVector * 3
			local On = false
			for _, P in ipairs(PlatformParts) do
				if inXZ(P, Ahead) then On = true end
			end
			check("gate LookVector points onto the platform", On, tostring(Ahead))
		end
	end

	-- ===== Freight yard =====
	local Yards = tagged("RenseiFreightYard")
	check("freight yard: a RenseiFreightYard zone exists", #Yards >= 1, #Yards)
	for _, Y in ipairs(Yards) do
		check("freight yard zone is a BasePart", Y:IsA("BasePart"), Y.ClassName)
		local Man = Y.Parent and Y.Parent:FindFirstChild("YardWatchman")
		check("YardWatchman is under the zone's parent model", Man ~= nil and Man:IsA("Model") and Y.Parent:IsA("Model"))
		check("YardWatchman is a RenseiWatcher", Man ~= nil and CS:HasTag(Man, "RenseiWatcher"))
	end

	-- ===== Arrivals =====
	local ByPoint = {}
	for _, A in ipairs(Arrivals) do
		local P = A:GetAttribute("Point")
		ByPoint[P] = ByPoint[P] or {}
		table.insert(ByPoint[P], A)
	end
	check("arrivals: exactly one Platform", ByPoint.Platform ~= nil and #ByPoint.Platform == 1, ByPoint.Platform and #ByPoint.Platform or 0)
	check("arrivals: exactly one RoadStart", ByPoint.RoadStart ~= nil and #ByPoint.RoadStart == 1, ByPoint.RoadStart and #ByPoint.RoadStart or 0)
	for _, A in ipairs(Arrivals) do
		check("arrival " .. tostring(A:GetAttribute("Point")) .. " is a BasePart", A:IsA("BasePart"))
		if A:IsA("BasePart") then
			check("arrival " .. tostring(A:GetAttribute("Point")) .. " stands upright (level LookVector)", near(A.CFrame.LookVector.Y, 0), A.CFrame.LookVector.Y)
		end
	end
	if ByPoint.Platform and #ByPoint.Platform == 1 then
		local A = ByPoint.Platform[1]
		local On = false
		for _, P in ipairs(PlatformParts) do
			if inXZ(P, A.Position) and A.Position.Y > P.Position.Y + P.Size.Y / 2 - EPS then On = true end
		end
		check("arrival Platform stands on the platform", On, tostring(A.Position))
	end

	-- ===== Road passage =====
	local Legs, Points = tagged("RenseiRoadPassage"), {}
	check("road: RenseiRoadPassage legs exist", #Legs >= 1, #Legs)
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
	local PointsOk = #Points > 0
	for _, P in ipairs(Points) do
		if type(P[1]:GetAttribute("S")) ~= "number" then PointsOk = false end
	end
	check("road: RoadPoint attachments carry S", PointsOk, #Points)
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
			-- the walk starts only in leg 1 alone: the mouth (on the road, and 3 studs up where a walker's root is) is in
			-- leg 1 and in no other leg
			local Alone = inBox(Leg1, Mouth.WorldPosition + Vector3.new(0, 3, 0))
			for N, L in pairs(ByLeg) do
				if N ~= 1 and inBox(L, Mouth.WorldPosition + Vector3.new(0, 3, 0)) then Alone = false end
			end
			check("road " .. Route .. " Leg 1 alone at the mouth", Alone)
		end
	end
	local Ths = tagged("RenseiRoadThreshold")
	check("road: a RenseiRoadThreshold exists", #Ths >= 1, #Ths)
	for _, T in ipairs(Ths) do
		check("threshold has Route and To", str(T:GetAttribute("Route")) and str(T:GetAttribute("To")))
		local P = T:IsA("BasePart") and nearestPoint(T:GetAttribute("Route"), T.Position)
		check("threshold LookVector points out (along the road's way out)", P and T.CFrame.LookVector:Dot(P.WorldCFrame.LookVector) > 0.9,
			P and T.CFrame.LookVector:Dot(P.WorldCFrame.LookVector))
	end
	local Encs = tagged("RenseiRoadEncounter")
	check("road: RenseiRoadEncounter parts exist", #Encs >= 1, #Encs)
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
	if ByPoint.RoadStart and #ByPoint.RoadStart == 1 then
		local A = ByPoint.RoadStart[1]
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
	return table.concat(Lines, "\n")
end

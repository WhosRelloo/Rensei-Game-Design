-- Play_Gate (World Plan 1 Task 9, 2026-10-23): the papers check at the station gate, the stowaway route, ThrownOff and
-- the freight yard's watchman. Runs in the game VM (LMRunSuite). Controller ruling: any ticket the tester holds for the
-- test route is put aside first and given back afterwards, so a saved ticket can't turn the stowaway into a passenger.
local SSS = game.ServerScriptService
local ROUTE = "LindenmoorFoundry"

local function Mine(K) return K:sub(1, #ROUTE + 1) == ROUTE .. "|" end
local function NoTickets(P, Body) -- the route's tickets put aside, then given back (whatever Body did)
	local Tk = require(SSS.TravelService).Tickets(P)
	local Saved = {}
	for K, V in pairs(Tk) do
		if Mine(K) then Saved[K] = V end
	end
	for K in pairs(Saved) do Tk[K] = nil end
	local Ok, Err = pcall(Body)
	for K in pairs(Tk) do
		if Mine(K) then Tk[K] = nil end
	end
	for K, V in pairs(Saved) do Tk[K] = V end
	if not Ok then error(Err, 0) end
end
local function StowZone()
	for _, d in ipairs(workspace:GetDescendants()) do
		if d.Name:find("StowZone") and d:FindFirstAncestor("PlatformTrain") then return d end
	end
end
local function TheGate()
	return game:GetService("CollectionService"):GetTagged("RenseiStationGate")[1]
end
local function HallSide(Gate, Root) return (Root.Position - Gate.Position):Dot(Gate.CFrame.LookVector) end
local function Toasts(Body) -- the toasts sent while Body runs
	local US = require(SSS.UIService)
	local Old = US.Notify
	local Got = {}
	US.Notify = function(P, Kind, Data)
		if Kind == "Toast" and type(Data) == "table" then table.insert(Got, Data.Text) end
		return Old(P, Kind, Data)
	end
	local Ok, Err = pcall(Body)
	US.Notify = Old
	if not Ok then error(Err, 0) end
	return Got
end
-- a stowaway's ride with a forced event; returns {Sent = left through TravelService.Depart, Arrived = Arrived fired}
local function StowRide(P, Event, Money)
	local SS, TS, RE = require(SSS.StationService), require(SSS.TravelService), require(SSS.RideEvents)
	local D = require(SSS.ProgressionService).GetData(P)
	local Was = D.Money
	local Out = {Sent = false, Arrived = false}
	local OldDepart = TS.Depart
	TS.Depart = function(List, ...)
		if table.find(List, P) then Out.Sent = true end
		return OldDepart(List, ...)
	end
	local C = TS.Arrived.Event:Connect(function(Who) if Who == P then Out.Arrived = true end end)
	SS.HoldClock = true
	local Ok, Err = pcall(function()
		D.Money = Money
		P.Character:PivotTo(StowZone().CFrame)
		task.wait(0.5)
		RE.Force = Event
		SS.DepartNow(ROUTE, 6)
		task.wait(1.5)
		Out.Riding = SS.Riding(P)
		Out.MidY = P.Character.HumanoidRootPart.Position.Y
		local t0 = os.clock()
		while SS.Riding(P) and os.clock() - t0 < 12 do task.wait(0.2) end
		task.wait(1)
		Out.Money = D.Money
	end)
	SS.HoldClock = false
	RE.Force = nil
	TS.Depart = OldDepart
	C:Disconnect()
	D.Money = Was
	if not Ok then error(Err, 0) end
	return Out
end

return {
	-- the brief's two tests
	GateFollowsWanted = function(T)
		local SS, HS = require(SSS.StationService), require(SSS.HeatService)
		local P = game.Players:GetPlayers()[1]
		HS.Clear(P, "State")
		T.Eq(SS.Gate(P), "Pass")
		HS.Add(P, "State", 25, "Lindenmoor") -- Wanted 1 (threshold 20)
		T.Eq(SS.Gate(P), "Bribe")
		HS.Add(P, "State", 100, "Lindenmoor") -- 125: Wanted 3 (threshold 100)
		T.Eq(SS.Gate(P), "Refuse")
		HS.Clear(P, "State")
	end,
	StowawayIsAboardWithoutATicket = function(T)
		local SS = require(SSS.StationService)
		local P = game.Players:GetPlayers()[1]
		SS.HoldClock = true -- a scheduled departure would take the stowaway on a 50 s ride
		local Aboard, Stow
		local Ok, Err = pcall(NoTickets, P, function()
			local Zone = StowZone()
			P.Character:PivotTo(Zone.CFrame)
			task.wait(0.5)
			Aboard, Stow = SS.Aboard(ROUTE)
		end)
		SS.HoldClock = false
		T.True(Ok, tostring(Err))
		T.True(table.find(Aboard, P) ~= nil and Stow[P] == true, "aboard as a stowaway")
	end,

	-- Wanted 3+: pushed back to the hall side, the guard's line, +10 State Heat once (not on every touch)
	RefusedAtWantedThree = function(T)
		local SS, HS = require(SSS.StationService), require(SSS.HeatService)
		local P = game.Players:GetPlayers()[1]
		local Gate = TheGate()
		T.True(Gate ~= nil, "a RenseiStationGate")
		local Root = P.Character.HumanoidRootPart
		HS.Clear(P, "State")
		HS.Add(P, "State", 125, "Lindenmoor")
		SS.ResetGate(P)
		local V1, V2, Side1
		local Got = Toasts(function()
			P.Character:PivotTo(Gate.CFrame * CFrame.new(0, -0.5, 0.2)) -- just past the gate's middle, on the hall side
			task.wait(0.1)
			T.Eq(SS.GateTouch(P, Gate), "Refuse")
			Side1 = HallSide(Gate, Root)
			V1 = HS.Value(P, "State")
			SS.GateTouch(P, Gate) -- a second touch at once: pushed again, no more Heat
			V2 = HS.Value(P, "State")
		end)
		HS.Clear(P, "State")
		SS.ResetGate(P)
		T.True(Side1 <= -(Gate.Size.Z / 2 + SS.GatePush) + 0.5, "pushed back to the hall side (" .. Side1 .. ")")
		T.Near(V1, 135, 0.5, "+10 State Heat")
		T.Near(V2, V1, 0.01, "once, not on every touch")
		T.True(table.find(Got, "Guard: \"Your face is on a poster. Not on my platform.\"") ~= nil, "the guard's line")
	end,
	-- Wanted 1-2: pushed back until they pay (2x the 3rd-class price) or are searched; then the gate lets them by
	BribeOrSearchClearsTheGate = function(T)
		local SS, HS, PS = require(SSS.StationService), require(SSS.HeatService), require(SSS.ProgressionService)
		local P = game.Players:GetPlayers()[1]
		local Gate = TheGate()
		local D = PS.GetData(P)
		local Money = D.Money
		HS.Clear(P, "State")
		HS.Add(P, "State", 25, "Lindenmoor")
		SS.ResetGate(P)
		P:SetAttribute("GateCleared", nil)
		local Ok, Err = pcall(function()
			P.Character:PivotTo(Gate.CFrame * CFrame.new(0, -0.5, 0.2))
			task.wait(0.1)
			T.Eq(SS.GateTouch(P, Gate), "Bribe", "offered a bribe")
			T.True(HallSide(Gate, P.Character.HumanoidRootPart) < -1, "pushed back")
			D.Money = 29
			T.Eq(SS.PayBribe(P, ROUTE), false, "can't pay $30 with $29")
			T.Eq(D.Money, 29, "nothing taken")
			D.Money = 100
			T.Eq(SS.PayBribe(P, "NoSuchLine"), false, "no such line: no free pass")
			T.Eq(SS.PayBribe(P, "RoadLindenmoorFoundry"), false, "a road isn't a line from this station")
			T.Eq(D.Money, 100, "still nothing taken")
			T.Eq(SS.PayBribe(P, ROUTE), true, "paid")
			T.Eq(D.Money, 70, "2x the 3rd-class price ($15)")
			P.Character:PivotTo(Gate.CFrame * CFrame.new(0, -0.5, 0.2))
			task.wait(0.1)
			T.Eq(SS.GateTouch(P, Gate), "Pass", "cleared: walks through")
			T.True(HallSide(Gate, P.Character.HumanoidRootPart) > -1, "not pushed")
			P:SetAttribute("GateCleared", os.time() - SS.GateClearFor - 1)
			T.Eq(SS.GateTouch(P, Gate), "Bribe", "10 minutes on, asked again")
			T.Eq(SS.Search(P), true, "searched")
			T.Eq(SS.GateTouch(P, Gate), "Pass", "a search clears it too")
			HS.Clear(P, "State")
			P:SetAttribute("GateCleared", nil)
			T.Eq(SS.GateTouch(P, Gate), "Pass", "Wanted 0 walks through")
		end)
		D.Money = Money
		HS.Clear(P, "State")
		SS.ResetGate(P)
		P:SetAttribute("GateCleared", nil)
		T.True(Ok, tostring(Err))
	end,
	-- the real Touched: walking up the ramp into the gate with Wanted 3 never gets you onto the platform
	WalkingIntoTheGateIsStopped = function(T)
		local SS, HS = require(SSS.StationService), require(SSS.HeatService)
		local P = game.Players:GetPlayers()[1]
		local Gate = TheGate()
		local H, Root = P.Character.Humanoid, P.Character.HumanoidRootPart
		HS.Clear(P, "State")
		HS.Add(P, "State", 125, "Lindenmoor")
		SS.ResetGate(P)
		local Look = Gate.CFrame.LookVector
		local From = Gate.Position - Look * 7
		P.Character:PivotTo(CFrame.lookAt(From, From + Look))
		task.wait(0.4)
		local Furthest = -math.huge
		local Ok, Err = pcall(function()
			H:MoveTo(Gate.Position + Look * 8)
			local t0 = os.clock()
			while os.clock() - t0 < 3 do
				Furthest = math.max(Furthest, HallSide(Gate, Root))
				task.wait()
			end
		end)
		H:MoveTo(Root.Position)
		local Heat = HS.Value(P, "State")
		HS.Clear(P, "State")
		SS.ResetGate(P)
		T.True(Ok, tostring(Err))
		T.True(Furthest < 3, "never got past the gate (furthest " .. Furthest .. ")")
		T.Near(Heat, 135, 0.5, "+10 once while walking into it")
	end,

	-- the controller's ruling: getting caught raises Heat
	InspectionCatchingAStowawayRaisesHeat = function(T)
		local RE, HS, PS = require(SSS.RideEvents), require(SSS.HeatService), require(SSS.ProgressionService)
		local P = game.Players:GetPlayers()[1]
		local D = PS.GetData(P)
		local Money = D.Money
		HS.Clear(P, "State")
		D.Money = 100
		RE.Run("Inspection", ROUTE, {P}, {[P] = false})
		local Fined, Caught = D.Money, HS.Value(P, "State")
		HS.Clear(P, "State")
		RE.Run("Inspection", ROUTE, {P}, {[P] = true})
		local Ticketed = HS.Value(P, "State")
		D.Money = Money
		HS.Clear(P, "State")
		T.Eq(Fined, 55, "fined $45")
		T.Near(Caught, 5, 0.1, "+5 State Heat for the stowaway")
		T.Near(Ticketed, 0, 0.01, "a ticket holder gains nothing")
	end,
	-- the full stowaway ride: hidden in the baggage car, carried in it, fined (and Heat) at the inspection, arrives
	StowawayRidesAndArrives = function(T)
		local HS = require(SSS.HeatService)
		local P = game.Players:GetPlayers()[1]
		HS.Clear(P, "State")
		local R
		NoTickets(P, function() R = StowRide(P, "Inspection", 100) end)
		local Heat = HS.Value(P, "State")
		HS.Clear(P, "State")
		T.Eq(R.Riding, ROUTE, "riding")
		T.True(R.MidY > 300, "carried in the ride train (y " .. R.MidY .. ")")
		T.Eq(R.Money, 55, "fined $45 at the inspection")
		T.Near(Heat, 5, 0.1, "caught: +5 State Heat")
		T.True(R.Sent and R.Arrived, "arrived like everyone else")
	end,
	-- the controller's ruling: ThrownOff (no ticket, no money) is put back on this platform instead of arriving
	ThrownOffRiderIsPutBackOnThePlatform = function(T)
		local TS, HS = require(SSS.TravelService), require(SSS.HeatService)
		local P = game.Players:GetPlayers()[1]
		HS.Clear(P, "State")
		local R
		NoTickets(P, function() R = StowRide(P, "Inspection", 0) end)
		HS.Clear(P, "State")
		local d = (P.Character.HumanoidRootPart.Position - TS.ArrivalPoint("Platform").Position).Magnitude
		T.Eq(R.Riding, ROUTE, "riding")
		T.Eq(R.Sent, false, "not sent on")
		T.Eq(R.Arrived, false, "didn't arrive")
		T.Eq(P:GetAttribute("ThrownOff"), nil, "the mark is cleared")
		T.True(d < 8, "back on the departure platform (" .. d .. ")")
		T.Eq(R.Money, 0, "never below $0")
	end,
	-- a stowaway who walks into the coaches during the ride is put back with the baggage
	StowawayStaysWithTheBaggage = function(T)
		local SS, RE = require(SSS.StationService), require(SSS.RideEvents)
		local P = game.Players:GetPlayers()[1]
		local Where
		NoTickets(P, function()
			SS.HoldClock = true
			local Ok, Err = pcall(function()
				P.Character:PivotTo(StowZone().CFrame)
				task.wait(0.5)
				RE.Force = "Quiet"
				SS.DepartNow(ROUTE, 5)
				task.wait(1.5)
				local Ride
				for _, R in ipairs(game:GetService("CollectionService"):GetTagged("RenseiRideTrain")) do
					if R:GetAttribute("Route") == ROUTE then Ride = R end
				end
				local Zone
				for _, d in ipairs(Ride:GetDescendants()) do
					if d.Name:find("BoardZone") and d:GetAttribute("CarKind") == "ThirdClass" then Zone = d break end
				end
				P.Character:PivotTo(Zone.CFrame)
				task.wait(1.2)
				local Car = SS.CarAt(Ride, P.Character.HumanoidRootPart.Position)
				Where = Car and SS.CarKind(Car)
				local t0 = os.clock()
				while SS.Riding(P) and os.clock() - t0 < 10 do task.wait(0.2) end
			end)
			SS.HoldClock = false
			RE.Force = nil
			if not Ok then error(Err, 0) end
		end)
		T.Eq(Where, "BaggageCar", "back in the baggage car")
	end,

	-- the controller's ruling: the yard watchman uses the game's perception (sight cone, light, crouching): a player
	-- he notices in the freight yard gains State Heat +5 once per visit; one behind him, or crouched in deep shadow,
	-- doesn't. Perception and light are stepped by hand, as Play_Stealth does.
	YardWatchmanSightingRaisesHeat = function(T)
		local SS, HS = require(SSS.StationService), require(SSS.HeatService)
		local PS, LS = require(SSS.PerceptionService), require(SSS.LightService)
		local P = game.Players:GetPlayers()[1]
		local C = P.Character
		local W, Zone
		for _, M in ipairs(game:GetService("CollectionService"):GetTagged("RenseiWatcher")) do
			if M.Name == "YardWatchman" and M:IsDescendantOf(workspace) then W = M end
		end
		Zone = game:GetService("CollectionService"):GetTagged("RenseiFreightYard")[1]
		T.True(W ~= nil and Zone ~= nil, "a yard watchman and the yard")
		T.True(PS.Tracks(W), "registered with PerceptionService")
		local Root = W.HumanoidRootPart
		local function InYard(Pos)
			local L = Zone.CFrame:PointToObjectSpace(Pos)
			return math.abs(L.X) <= Zone.Size.X / 2 and math.abs(L.Y) <= Zone.Size.Y / 2 and math.abs(L.Z) <= Zone.Size.Z / 2
		end
		-- a free spot in the yard Dist from him, Angle degrees off his look (0 = straight ahead, 180 = behind), from which
		-- his eyes have a clear line to a standing player's head and chest (the crates are cover, so not every spot is)
		local Head = W.Head
		local function Clear(Pos)
			local Rays = RaycastParams.new()
			Rays.FilterType = Enum.RaycastFilterType.Exclude
			Rays.FilterDescendantsInstances = {W, C}
			for _, Up in ipairs({1.5, 0}) do
				local To = Pos + Vector3.new(0, Up, 0)
				if workspace:Raycast(Head.Position, To - Head.Position, Rays) then return false end
			end
			local Box = OverlapParams.new()
			Box.FilterType = Enum.RaycastFilterType.Exclude
			Box.FilterDescendantsInstances = {W, C}
			Box.RespectCanCollide = true
			return #workspace:GetPartBoundsInBox(CFrame.new(Pos), Vector3.new(2.5, 4.5, 2.5), Box) == 0
		end
		local function Spot(Angles, Dists)
			local Look = Root.CFrame.LookVector * Vector3.new(1, 0, 1)
			for _, D in ipairs(Dists) do
				for _, A in ipairs(Angles) do
					local Dir = (CFrame.Angles(0, math.rad(A), 0) * Look).Unit
					local Pos = Root.Position + Dir * D + Vector3.new(0, 0.6, 0)
					if InYard(Pos) and Clear(Pos) then return Pos end
				end
			end
			return nil
		end
		local function Stand(Pos) -- facing him
			C:PivotTo(CFrame.lookAt(Pos, Vector3.new(Root.Position.X, Pos.Y, Root.Position.Z)))
			C.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
			task.wait(0.4)
			return C.HumanoidRootPart.Position
		end
		local function Watch(Seconds) for _ = 1, math.floor(Seconds / 0.2 + 0.5) do PS.Step(0.2) end end
		local function Fresh()
			PS.Reset(W)
			SS.ResetYard(P)
			HS.Clear(P, "State")
		end
		local Home = C:GetPivot()
		PS.SetAuto(false)
		LS.SetAuto(false)
		local R = {}
		local Ok, Err = pcall(function()
			-- 1. standing in plain view, lit, 12 studs in front of him
			local Front = Spot({0, 20, -20, 35, -35, 50, -50}, {10, 12, 8, 14, 6})
			local Back = Spot({180, 160, -160}, {7, 9, 5})
			assert(Front and Back, "no clear spot in front of / behind the watchman")
			Fresh()
			C:SetAttribute("Exposure", 1)
			R.FrontIn = InYard(Stand(Front))
			Watch(2)
			R.SeenAware = PS.Awareness(W, P)
			SS.YardCheck()
			R.Seen = HS.Value(P, "State")
			Watch(1)
			SS.YardCheck()
			R.Again = HS.Value(P, "State")
			-- 2. behind him (out of his view cone)
			Fresh()
			R.BackIn = InYard(Stand(Back))
			Watch(2)
			SS.YardCheck()
			R.Behind = HS.Value(P, "State")
			-- 3. the same spot in front of him, crouched in deep shadow
			Fresh()
			C:SetAttribute("Crouching", true)
			C:SetAttribute("Exposure", 0)
			Stand(Front)
			Watch(2)
			R.SneakAware = PS.Awareness(W, P)
			SS.YardCheck()
			R.Sneak = HS.Value(P, "State")
		end)
		C:SetAttribute("Crouching", nil)
		C:SetAttribute("Exposure", nil)
		PS.Reset(W)
		SS.ResetYard(P)
		HS.Clear(P, "State")
		PS.SetAuto(true)
		LS.SetAuto(true)
		C:PivotTo(Home)
		T.True(Ok, tostring(Err))
		T.True(R.FrontIn and R.BackIn, "both spots are in the yard")
		T.True(R.SeenAware >= 0.35, "noticed (" .. R.SeenAware .. ")")
		T.Near(R.Seen, 5, 0.1, "seen: +5 State Heat")
		T.Near(R.Again, 5, 0.1, "once per visit")
		T.Near(R.Behind, 0, 0.01, "behind him: unseen")
		T.True(R.SneakAware < 0.35, "crouched in shadow stays under his notice (" .. R.SneakAware .. ")")
		T.Near(R.Sneak, 0, 0.01, "stealth beats him")
	end,
}

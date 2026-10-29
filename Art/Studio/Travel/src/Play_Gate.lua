-- Play_Gate (World Plan 1 Task 9, 2026-10-23): the papers check at the station gate (and, fix round 1, at boarding),
-- (final fix wave, 2026-10-23: a ticket holder who stows away keeps the ticket and pays no fine; the refusal lines)
-- the stowaway route, ThrownOff and the freight yard's watchman (sight and, fix round 1, footsteps). Runs in the game VM (LMRunSuite). Controller ruling: any ticket the tester holds for the
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
-- (hostages Task 13 fix round 1, review m4) a case that ends with the player on the train: whether they are still aboard
-- once put back where the case found them (Home), asked while the clock is still held, so a scheduled departure can't
-- carry them into the next case
local function OffTheTrain(P, Home)
	P.Character:PivotTo(Home)
	P.Character.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
	return table.find((require(SSS.StationService).Aboard(ROUTE)), P) ~= nil
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
		if table.find(List, P) then
			Out.Sent = true
			local Opts = select(3, ...) -- (final fix wave) Opts.NoTicket: the ride uses no ticket of theirs
			Out.NoTicket = type(Opts) == "table" and type(Opts.NoTicket) == "table" and Opts.NoTicket[P] == true
		end
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
		local Home = P.Character:GetPivot()
		local Ok, Err = pcall(NoTickets, P, function()
			local Zone = StowZone()
			P.Character:PivotTo(Zone.CFrame)
			task.wait(0.5)
			Aboard, Stow = SS.Aboard(ROUTE)
		end)
		local LeftAboard = OffTheTrain(P, Home)
		SS.HoldClock = false
		T.True(Ok, tostring(Err))
		T.Eq(LeftAboard, false, "put back off the train before the clock runs again")
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
	-- final fix wave (ledger ruling :241): the inspection catches a ticket holder hiding from the papers check: Heat
	-- and a papers line, no fine, and never thrown off, even with no money at all
	InspectionOfATicketHolderWithoutPapers = function(T)
		local RE, HS, PS = require(SSS.RideEvents), require(SSS.HeatService), require(SSS.ProgressionService)
		local P = game.Players:GetPlayers()[1]
		local D = PS.GetData(P)
		local Money = D.Money
		local R = {}
		HS.Clear(P, "State")
		P:SetAttribute("ThrownOff", nil)
		local Ok, Err = pcall(function()
			D.Money = 100
			R.Toasts = Toasts(function() RE.Run("Inspection", ROUTE, {P}, {[P] = false}, {[P] = true}) end)
			R.Money, R.Heat = D.Money, HS.Value(P, "State")
			D.Money = 0
			RE.Run("Inspection", ROUTE, {P}, {[P] = false}, {[P] = true})
			R.Broke, R.Thrown = D.Money, P:GetAttribute("ThrownOff")
		end)
		D.Money = Money
		HS.Clear(P, "State")
		P:SetAttribute("ThrownOff", nil)
		T.True(Ok, tostring(Err))
		T.Eq(R.Money, 100, "no fine")
		T.Near(R.Heat, 5, 0.1, "+5 State Heat")
		T.True(table.find(R.Toasts, "Conductor: \"A ticket, but hiding with the baggage? Your papers will be reported.\"") ~= nil, "the papers line")
		T.Eq(R.Broke, 0, "nothing taken from an empty purse")
		T.Eq(R.Thrown, nil, "never thrown off for the fare")
	end,
	-- final fix wave (I1, ledger ruling :241): the whole ride of a Wanted 1 ticket holder who hid in the StowZone:
	-- a stowaway in law (baggage car, Heat at the inspection) who pays no fine, arrives, and still holds the ticket
	TicketHolderStowawayKeepsTheTicket = function(T)
		local TS, HS = require(SSS.TravelService), require(SSS.HeatService)
		local P = game.Players:GetPlayers()[1]
		local R, Ticket, Heat
		HS.Clear(P, "State")
		P:SetAttribute("GateCleared", nil)
		local Ok, Err = pcall(NoTickets, P, function()
			TS.AddTicket(P, ROUTE, "Third")
			HS.Add(P, "State", 25, "Lindenmoor") -- Wanted 1, not cleared: no papers
			R = StowRide(P, "Inspection", 100)
			Ticket = TS.HasTicket(P, ROUTE)
			Heat = HS.Value(P, "State")
		end)
		HS.Clear(P, "State")
		P:SetAttribute("GateCleared", nil)
		P:SetAttribute("ThrownOff", nil)
		T.True(Ok, tostring(Err))
		T.Eq(R.Riding, ROUTE, "riding")
		T.True(R.MidY > 300, "carried in the ride train (y " .. R.MidY .. ")")
		T.Eq(R.Money, 100, "no fine")
		T.Near(Heat, 30, 0.5, "caught: +5 State Heat on top of 25")
		T.True(R.Sent and R.Arrived, "arrived")
		T.Eq(R.NoTicket, true, "Depart was told the ride uses no ticket")
		T.Eq(Ticket, "Third", "the ticket wasn't used")
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
		T.Eq(R.NoTicket, true, "no ticket to use")
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
	-- doesn't. Perception and light are stepped by hand, as Play_Stealth does. Fix round 1 (footsteps count): a loud
	-- player behind him turns him round (he's anchored: he turns on the spot) and, once seen, gains the Heat; a crouched,
	-- quiet one doesn't.
	YardWatchmanSightingRaisesHeat = function(T)
		local SS, HS = require(SSS.StationService), require(SSS.HeatService)
		local PS, LS, NS = require(SSS.PerceptionService), require(SSS.LightService), require(SSS.NoiseService)
		local Rules = require(game.ReplicatedStorage.Modules.Data.Rensei.Perception)
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
			SS.ResetWatch(W)
			SS.ResetYard(P)
			HS.Clear(P, "State")
			C:SetAttribute("Crouching", nil)
		end
		local function Facing(Pos) -- how squarely he faces Pos (1 = straight at it)
			local To = (Pos - Root.Position) * Vector3.new(1, 0, 1)
			return (Root.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit:Dot(To.Unit)
		end
		local function Steps(Move) -- one footstep of this player as NoiseService makes it (no sound when crouching)
			local Floor = C.Humanoid.FloorMaterial
			local Radius = Rules.StepNoise(Floor ~= Enum.Material.Air and Floor.Name or "Grass", Move, C:GetAttribute("Crouching"))
			if Radius > 0 then NS.Emit(C.HumanoidRootPart.Position - Vector3.new(0, 3, 0), Radius, C) end
			return Radius
		end
		local Home = C:GetPivot()
		PS.SetAuto(false)
		LS.SetAuto(false)
		NS.SetAuto(false)
		SS.ResetWatch(W)
		local R = {}
		local Ok, Err = pcall(function()
			-- 1. standing in plain view, lit, 12 studs in front of him
			local Front = Spot({0, 20, -20, 35, -35, 50, -50}, {10, 12, 8, 14, 6})
			local Back = Spot({180, 155, -155, 130, -130, 110, -110}, {7, 9, 5, 11}) -- (more than 80 off his look: unseen)
			-- running footsteps on the yard's grass carry 8 studs (Perception.Steps, measured from his head to the feet): close
			local Near = Spot({180, 155, -155, 130, -130, 110, -110}, {4.5, 5.5, 6, 3.5})
			assert(Front and Back and Near, "no clear spot in front of / behind the watchman")
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
			-- 4. close behind him, lit, running footsteps: he turns round, then sees
			Fresh()
			C:SetAttribute("Exposure", 1)
			local At = Stand(Near)
			R.NearDist = (W.Head.Position - (At - Vector3.new(0, 3, 0))).Magnitude
			Watch(1)
			R.LoudBefore = PS.Awareness(W, P)
			R.LoudRadius = Steps(1.5)
			R.LoudPhase = PS.PhaseOf(W)
			for _ = 1, 6 do SS.YardCheck() end -- 45 degrees a check
			R.LoudFacing = Facing(At)
			Watch(2)
			SS.YardCheck()
			R.Loud = HS.Value(P, "State")
			-- 5. the same spot, crouched (a crouch makes no footstep sound)
			Fresh()
			C:SetAttribute("Crouching", true)
			At = Stand(Near)
			local Before = Facing(At)
			R.QuietRadius = Steps(1)
			for _ = 1, 6 do SS.YardCheck() end
			R.QuietTurn = Facing(At) - Before
			Watch(2)
			SS.YardCheck()
			R.Quiet = HS.Value(P, "State")
		end)
		C:SetAttribute("Crouching", nil)
		C:SetAttribute("Exposure", nil)
		NS.SetAuto(true)
		PS.Reset(W)
		SS.ResetWatch(W)
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
		T.True(R.LoudBefore < 0.01, "behind him, unheard: unseen")
		T.True(R.LoudRadius > 0 and R.LoudPhase == "Suspicious", ("heard the footsteps (radius %s at %.1f: %s)"):format(tostring(R.LoudRadius), R.NearDist or -1, tostring(R.LoudPhase)))
		T.True(R.LoudFacing > 0.95, "turned to face the sound (" .. R.LoudFacing .. ")")
		T.Near(R.Loud, 5, 0.1, "then seen: +5 State Heat")
		T.Eq(R.QuietRadius, 0, "a crouch makes no footstep")
		T.True(math.abs(R.QuietTurn) < 0.01, "didn't turn (" .. R.QuietTurn .. ")")
		T.Near(R.Quiet, 0, 0.01, "crouched and quiet behind him: no Heat")
	end,

	-- (hostages Task 13 fix round 1, review I1 and m2) the gate's own check for an approacher whose touch reaches the
	-- server with its copy of the root still short of the gate on the hall side (a sprint at 24-30 studs/s, or lag):
	-- Wanted 3, the root 6 and then 14 studs short (the second moving at 30 studs/s toward the platform) is refused there:
	-- the guard's line, +10 State Heat, put GatePush clear on the hall side. 10 studs past the gate on the platform
	-- side (where the stale touches came from) a touch is ignored: not moved, no Heat. The spots (6, 14, 10) and the
	-- speed 30 are PROPOSAL test values; the expected numbers are written by hand (gate 1 stud thick, GatePush 4).
	GateChecksAHallSideApproach = function(T)
		local SS, HS = require(SSS.StationService), require(SSS.HeatService)
		local P = game.Players:GetPlayers()[1]
		local Gate = TheGate()
		T.True(Gate ~= nil, "a RenseiStationGate")
		local Root = P.Character.HumanoidRootPart
		local Home = P.Character:GetPivot()
		local N = Gate.CFrame.LookVector
		local LINE = "Guard: \"Your face is on a poster. Not on my platform.\""
		local function Touch(Side, Speed) -- the root Side studs along N from the gate's middle (negative: the hall side)
			SS.ResetGate(P)
			local Pos = (Gate.CFrame * CFrame.new(0, -0.5, 0)).Position + N * Side
			P.Character:PivotTo(CFrame.lookAt(Pos, Pos + N))
			Root.AssemblyLinearVelocity = N * Speed
			local H0 = HS.Value(P, "State")
			local V
			local Said = Toasts(function() V = SS.GateTouch(P, Gate) end)
			local Out = {V = V, Heat = HS.Value(P, "State") - H0, Side = HallSide(Gate, Root),
				Moved = (Root.Position - Pos).Magnitude, Line = table.find(Said, LINE) ~= nil}
			Root.AssemblyLinearVelocity = Vector3.zero
			return Out
		end
		local R = {}
		HS.Clear(P, "State")
		HS.Add(P, "State", 125, "Lindenmoor") -- Wanted 3
		local Ok, Err = pcall(function()
			R.Near = Touch(-6, 0)
			R.Sprint = Touch(-14, 30)
			R.Past = Touch(10, 0)
		end)
		P.Character:PivotTo(Home)
		Root.AssemblyLinearVelocity = Vector3.zero
		HS.Clear(P, "State")
		SS.ResetGate(P)
		T.True(Ok, tostring(Err))
		for _, K in ipairs({"Near", "Sprint"}) do
			local X = R[K]
			T.Eq(X.V, "Refuse", K .. ": refused")
			T.True(X.Line, K .. ": the guard's line")
			T.Near(X.Heat, 10, 0.5, K .. ": +10 State Heat")
			T.Near(X.Side, -4.5, 0.6, K .. ": put 4 studs clear on the hall side (" .. X.Side .. ")")
		end
		T.Eq(R.Past.V, "Refuse", "past the gate: the verdict is still returned")
		T.True(R.Past.Moved < 0.5, ("past the gate on the platform side: a touch is ignored (moved %.2f)"):format(R.Past.Moved))
		T.Near(R.Past.Heat, 0, 0.01, "past the gate: no Heat")
		T.Eq(R.Past.Line, false, "past the gate: no line")
	end,

	-- (hostages Task 13) a gate touch that reaches the server once the player is somewhere else (the client owns the
	-- character, so a touch it saw at the gate can arrive after a server move) changes nothing: GateTouch, which the gate's
	-- Touched handler calls, acts only on a root at the gate. Here the root is well inside the 3rd-class car with papers
	-- the gate would push back (Wanted 1, uncleared). Control: the same papers at the gate are pushed to the hall side.
	StaleGateTouchLeavesABoardedPlayer = function(T)
		local SS, HS, TS = require(SSS.StationService), require(SSS.HeatService), require(SSS.TravelService)
		local P = game.Players:GetPlayers()[1]
		local Gate = TheGate()
		T.True(Gate ~= nil, "a RenseiStationGate")
		local Root = P.Character.HumanoidRootPart
		local Home = P.Character:GetPivot()
		local R = {}
		SS.HoldClock = true
		local Ok, Err = pcall(NoTickets, P, function()
			TS.AddTicket(P, ROUTE, "Third")
			HS.Clear(P, "State")
			HS.Add(P, "State", 25, "Lindenmoor") -- Wanted 1, not cleared
			P:SetAttribute("GateCleared", nil)
			SS.ResetGate(P)
			local Zone
			for _, d in ipairs(workspace:GetDescendants()) do
				if d.Name:find("BoardZone") and d:GetAttribute("CarKind") == "ThirdClass" and d:FindFirstAncestor("PlatformTrain") then Zone = d break end
			end
			P.Character:PivotTo(Zone.CFrame)
			task.wait(0.3)
			Root.AssemblyLinearVelocity = Vector3.zero -- (fix round 1, review m1) no stale velocity: never "Leaving"
			local Before = Root.Position
			R.Far = (Before - Gate.Position).Magnitude
			R.Verdict = SS.GateTouch(P, Gate)
			R.Moved = (Root.Position - Before).Magnitude
			SS.ResetGate(P)
			P.Character:PivotTo(Gate.CFrame * CFrame.new(0, -0.5, 0.2)) -- the control: just past the gate's middle
			task.wait(0.1)
			R.AtGate = SS.GateTouch(P, Gate)
			R.Side = HallSide(Gate, Root)
		end)
		P.Character:PivotTo(Home)
		Root.AssemblyLinearVelocity = Vector3.zero
		SS.HoldClock = false
		HS.Clear(P, "State")
		P:SetAttribute("GateCleared", nil)
		SS.ResetGate(P)
		T.True(Ok, tostring(Err))
		T.True(R.Far > 20, ("setup: the root is well inside the car, %.1f studs from the gate"):format(R.Far))
		T.Eq(R.Verdict, "Bribe", "the verdict is still returned (not an early Leaving or Pass)")
		T.True(R.Moved < 0.5, ("a touch from away from the gate doesn't push (moved %.2f studs)"):format(R.Moved))
		T.Eq(R.AtGate, "Bribe", "control: at the gate, the same papers are offered a bribe")
		T.True(R.Side <= -(Gate.Size.Z / 2 + SS.GatePush) + 0.5, "control: and pushed back to the hall side (" .. R.Side .. ")")
	end,

	-- fix round 1 (the papers check is binding): a ticket holder whose papers aren't in order isn't boarded, wherever
	-- they got on; once cleared they are. Hidden in the StowZone, they ride as a stowaway.
	PapersAreCheckedAtBoarding = function(T)
		local SS, HS, TS, PS = require(SSS.StationService), require(SSS.HeatService), require(SSS.TravelService), require(SSS.ProgressionService)
		local P = game.Players:GetPlayers()[1]
		local D = PS.GetData(P)
		local Money = D.Money
		local R = {}
		local Home = P.Character:GetPivot() -- (hostages Task 13) where the case found the player, for the put-back
		SS.HoldClock = true
		local Ok, Err = pcall(NoTickets, P, function()
			TS.AddTicket(P, ROUTE, "Third")
			HS.Clear(P, "State")
			HS.Add(P, "State", 25, "Lindenmoor") -- Wanted 1, not cleared
			P:SetAttribute("GateCleared", nil)
			SS.ResetGate(P)
			local Zone
			for _, d in ipairs(workspace:GetDescendants()) do
				if d.Name:find("BoardZone") and d:GetAttribute("CarKind") == "ThirdClass" and d:FindFirstAncestor("PlatformTrain") then Zone = d break end
			end
			P.Character:PivotTo(Zone.CFrame)
			task.wait(0.5)
			SS.ResetGate(P) -- (the departure clock's own Aboard may have just told them: its line is rate-limited)
			R.Toasts = Toasts(function()
				local A = SS.Aboard(ROUTE)
				R.Uncleared = table.find(A, P) ~= nil
			end)
			D.Money = 100
			R.Paid = SS.PayBribe(P, ROUTE)
			local A, Stow = SS.Aboard(ROUTE)
			R.Cleared = table.find(A, P) ~= nil and not Stow[P]
			-- Wanted 3 with a ticket, hidden in the StowZone: a stowaway
			HS.Add(P, "State", 100, "Lindenmoor")
			-- (final fix wave, review minor 1) Wanted 3 inside a car: refused, and not sent to a guard who'd refuse too;
			-- the line comes once per boarding, not on every check
			local Zone3
			for _, d in ipairs(workspace:GetDescendants()) do
				if d.Name:find("BoardZone") and d:GetAttribute("CarKind") == "ThirdClass" and d:FindFirstAncestor("PlatformTrain") then Zone3 = d break end
			end
			P.Character:PivotTo(Zone3.CFrame)
			task.wait(0.3)
			SS.ResetGate(P)
			R.Refused = Toasts(function()
				SS.Aboard(ROUTE)
				SS.Aboard(ROUTE)
			end)
			P.Character:PivotTo(StowZone().CFrame)
			task.wait(0.5)
			A, Stow = SS.Aboard(ROUTE)
			R.Stowed = table.find(A, P) ~= nil and Stow[P] == true
		end)
		-- (hostages Task 13) the case ends off the train, with the clock still held: a scheduled departure must not carry
		-- the player (still in the StowZone) into the next case
		R.LeftAboard = OffTheTrain(P, Home)
		SS.HoldClock = false
		D.Money = Money
		HS.Clear(P, "State")
		P:SetAttribute("GateCleared", nil)
		SS.ResetGate(P)
		T.True(Ok, tostring(Err))
		T.Eq(R.LeftAboard, false, "put back off the train before the clock runs again")
		T.Eq(R.Uncleared, false, "Wanted 1, uncleared, inside the train: not aboard")
		T.True(table.find(R.Toasts, "Conductor: \"Papers first — see the gate guard.\"") ~= nil, "told to see the gate guard")
		T.Eq(R.Paid, true, "paid the guard")
		T.Eq(R.Cleared, true, "then aboard, as a passenger")
		local Won = 0
		for _, L in ipairs(R.Refused) do if L == "Conductor: \"Your papers won't pass here.\"" then Won += 1 end end
		T.Eq(Won, 1, "Wanted 3 hears their papers won't pass, once")
		T.Eq(R.Stowed, true, "Wanted 3 with a ticket in the StowZone: aboard as a stowaway")
	end,
}

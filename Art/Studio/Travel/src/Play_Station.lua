local SSS = game.ServerScriptService
-- (final fix wave 2026-10-23: held players, the ride-end sweep, the stalled-teleport watchdog; held tickets put aside)
-- task 6b (owner, 2026-10-21): seats sit you only through their prompt
local function SitPrompt(Seat) return Seat:FindFirstChild("SitPrompt", true) end -- (on its SitPoint attachment)
local function FreeSeat(Car)
	for _, S in ipairs(Car:GetDescendants()) do
		if S:IsA("Seat") and not S.Occupant then return S end
	end
	return nil
end
local function StandUp(H)
	local S = H.SeatPart
	if not S then return end
	H.Sit = false
	local W = S:FindFirstChild("SeatWeld")
	if W then W:Destroy() end
	local t0 = os.clock()
	repeat task.wait(0.1) until not H.SeatPart or os.clock() - t0 > 1
end
local function Near(Seat) -- standing on the seat, inside the Sit reach
	return CFrame.new(Seat.Position + Vector3.new(0, 3.5, 0))
end
-- final fix wave (2026-10-23)
local ROUTE = "LindenmoorFoundry"
local HELD = {"Knocked", "GrippedBy", "CarriedBy", "Gripping", "Carrying"}
local function Zone(TrainName, Kind) -- a BoardZone of that car kind in the platform or ride train
	for _, d in ipairs(workspace:GetDescendants()) do
		if d.Name:find("BoardZone") and d:GetAttribute("CarKind") == Kind and d:FindFirstAncestor(TrainName) then return d end
	end
end
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
local function PlatformDist(P)
	local At = require(SSS.TravelService).ArrivalPoint("Platform")
	return (P.Character.HumanoidRootPart.Position - At.Position).Magnitude
end
local Suite = {
	BuyChargesAndGivesATicket = function(T)
		local SS, TS, PS = require(SSS.StationService), require(SSS.TravelService), require(SSS.ProgressionService)
		local P = game.Players:GetPlayers()[1]
		local D = PS.GetData(P)
		local Money = D.Money
		D.Money = Money + 100
		local Ok = SS.Buy(P, "LindenmoorFoundry", "Second")
		T.True(Ok, "bought")
		T.Eq(PS.GetData(P).Money, Money + 100 - 30, "2nd class costs 30")
		T.Eq(TS.UseTicket(P, "LindenmoorFoundry"), "Second")
		D.Money = Money
	end,
	CantBuyWithoutMoneyOrLevel = function(T)
		local SS, PS = require(SSS.StationService), require(SSS.ProgressionService)
		local P = game.Players:GetPlayers()[1]
		local D = PS.GetData(P)
		local Money = D.Money
		D.Money = 0
		local Ok, Why = SS.Buy(P, "LindenmoorFoundry", "Third")
		T.True(not Ok and Why ~= nil, "no money")
		D.Money = Money
	end,
	BoardingNeedsATicketAndTheRightCar = function(T)
		local SS = require(SSS.StationService)
		local P = game.Players:GetPlayers()[1]
		T.True(not SS.CanEnter(P, "LindenmoorFoundry", "ThirdClass"), "no ticket")
		require(SSS.TravelService).AddTicket(P, "LindenmoorFoundry", "Third")
		T.True(SS.CanEnter(P, "LindenmoorFoundry", "ThirdClass"))
		T.True(SS.CanEnter(P, "LindenmoorFoundry", "DiningCar"))
		T.True(not SS.CanEnter(P, "LindenmoorFoundry", "SecondClass"), "3rd can't enter 2nd")
		require(SSS.TravelService).UseTicket(P, "LindenmoorFoundry")
	end,
	DepartureMovesTheAboardIntoTheRideTrain = function(T)
		local SS, TS = require(SSS.StationService), require(SSS.TravelService)
		SS.HoldClock = true -- a scheduled departure in the middle of this test would take the player on a 50 s ride
		local P = game.Players:GetPlayers()[1]
		TS.AddTicket(P, "LindenmoorFoundry", "Third")
		local Zone
		for _, d in ipairs(workspace:GetDescendants()) do
			if d.Name:find("BoardZone") and d:GetAttribute("CarKind") == "ThirdClass" and d:FindFirstAncestor("PlatformTrain") then Zone = d break end
		end
		P.Character:PivotTo(Zone.CFrame)
		task.wait(0.5)
		SS.DepartNow("LindenmoorFoundry", 3) -- test hook: depart now with a 3-second ride
		task.wait(1)
		local Ride = workspace:FindFirstChild("RideTrain", true)
		local d = (P.Character.HumanoidRootPart.Position - Ride:GetPivot().Position).Magnitude
		T.True(d < 400, "inside the ride train (" .. d .. ")")
		local t0 = os.clock()
		while TS.HasTicket(P, "LindenmoorFoundry") and os.clock() - t0 < 8 do task.wait(0.2) end
		SS.HoldClock = false
		T.Eq(TS.HasTicket(P, "LindenmoorFoundry"), nil, "arrived (loopback) and used the ticket")
	end,
	-- review fix 1 (2026-10-21): the class barrier holds even for someone who never touched a CarDoor
	ThirdClassInTheCabinCarRidesInAnAllowedCar = function(T)
		local SS, TS = require(SSS.StationService), require(SSS.TravelService)
		local Travel = require(game.ReplicatedStorage.Modules.Data.Rensei.Travel)
		SS.HoldClock = true
		local P = game.Players:GetPlayers()[1]
		TS.AddTicket(P, "LindenmoorFoundry", "Third")
		local Platform = workspace:FindFirstChild("PlatformTrain", true)
		local Cabin = Platform:FindFirstChild("CabinCar_Main")
		P.Character:PivotTo(Cabin:GetPivot() * CFrame.new(0, 7.5, 0)) -- the middle of the cabin car, not a vestibule
		task.wait(0.5)
		local Car = SS.CarAt(Platform, P.Character.HumanoidRootPart.Position)
		T.True(Car == Cabin, "starts in the cabin car (" .. tostring(Car and Car.Name) .. ")")
		SS.DepartNow("LindenmoorFoundry", 3)
		task.wait(1.2)
		local Ride = workspace:FindFirstChild("RideTrain", true)
		local In = SS.CarAt(Ride, P.Character.HumanoidRootPart.Position)
		local Kind = In and SS.CarKind(In)
		T.True(Kind ~= nil and Travel.ClassReaches("Third", Kind), "rides in a car 3rd class reaches (" .. tostring(In and In.Name) .. ")")
		local t0 = os.clock()
		while TS.HasTicket(P, "LindenmoorFoundry") and os.clock() - t0 < 8 do task.wait(0.2) end
		SS.HoldClock = false
		T.Eq(TS.HasTicket(P, "LindenmoorFoundry"), nil, "arrived and used the ticket")
	end,
	-- review fix 2: a seat taken before the fade, in another car than the one you're in at the move, isn't carried
	-- over. (Task 6b fix 1: a Third ticket can't stay in a cabin seat any more, so this uses a Cabin ticket.)
	CabinSeatBeforeTheFadeIsNotCarriedOver = function(T)
		local SS, TS = require(SSS.StationService), require(SSS.TravelService)
		SS.HoldClock = true
		local P = game.Players:GetPlayers()[1]
		local H = P.Character.Humanoid
		TS.AddTicket(P, "LindenmoorFoundry", "Cabin")
		local Platform = workspace:FindFirstChild("PlatformTrain", true)
		local CabinSeat
		for _, S in ipairs(Platform.CabinCar_Main:GetDescendants()) do if S:IsA("Seat") then CabinSeat = S break end end
		P.Character:PivotTo(CabinSeat.CFrame + Vector3.new(0, 2, 0))
		task.wait(0.3)
		CabinSeat:Sit(H)
		task.wait(0.5)
		T.True(H.SeatPart == CabinSeat, "sitting in a cabin seat")
		SS.DepartNow("LindenmoorFoundry", 3) -- stands them up (Was = the cabin seat) and fades
		task.wait(0.25)
		P.Character:PivotTo(Platform.ThirdClass_Main:GetPivot() * CFrame.new(0, 7.5, 0)) -- into 3rd class during the fade
		task.wait(1.2)
		local Ride = workspace:FindFirstChild("RideTrain", true)
		local In = SS.CarAt(Ride, P.Character.HumanoidRootPart.Position)
		local Kind = In and SS.CarKind(In)
		T.True(not (H.SeatPart and H.SeatPart:IsDescendantOf(Ride.CabinCar_Main)), "not seated in the ride train's cabin car")
		T.True(Kind == "ThirdClass", "rides in the car they stood in at the move (" .. tostring(In and In.Name) .. ")")
		local t0 = os.clock()
		while TS.HasTicket(P, "LindenmoorFoundry") and os.clock() - t0 < 8 do task.wait(0.2) end
		SS.HoldClock = false
		T.Eq(TS.HasTicket(P, "LindenmoorFoundry"), nil, "arrived and used the ticket")
	end,
	-- review fix 2: walking into a car the ticket doesn't reach during the ride gets you sent back
	DisallowedCarDuringTheRideIsCorrected = function(T)
		local SS, TS = require(SSS.StationService), require(SSS.TravelService)
		local Travel = require(game.ReplicatedStorage.Modules.Data.Rensei.Travel)
		SS.HoldClock = true
		local P = game.Players:GetPlayers()[1]
		TS.AddTicket(P, "LindenmoorFoundry", "Third")
		local Platform = workspace:FindFirstChild("PlatformTrain", true)
		local Zone
		for _, d in ipairs(Platform.ThirdClass_Main:GetChildren()) do if d.Name:find("BoardZone") then Zone = d break end end
		P.Character:PivotTo(Zone.CFrame)
		task.wait(0.5)
		SS.DepartNow("LindenmoorFoundry", 5)
		task.wait(1.2)
		local Ride = workspace:FindFirstChild("RideTrain", true)
		P.Character:PivotTo(Ride.CabinCar_Main:GetPivot() * CFrame.new(0, 7.5, 0)) -- into the cabin car mid-ride
		task.wait(1.2)
		local In = SS.CarAt(Ride, P.Character.HumanoidRootPart.Position)
		local Kind = In and SS.CarKind(In)
		T.True(Kind ~= nil and Travel.ClassReaches("Third", Kind), "back in a car 3rd class reaches (" .. tostring(In and In.Name) .. ")")
		local t0 = os.clock()
		while TS.HasTicket(P, "LindenmoorFoundry") and os.clock() - t0 < 10 do task.wait(0.2) end
		SS.HoldClock = false
		T.Eq(TS.HasTicket(P, "LindenmoorFoundry"), nil, "arrived and used the ticket")
	end,
	-- task 7 fix round 1 (controller ruling): dying aboard drops you from the ride, the ticket kept, and the
	-- character you respawn with is never pulled into the train. A real death: the humanoid's Health is set to 0.
	DeathAboardDropsYouFromTheRide = function(T)
		local SS, TS = require(SSS.StationService), require(SSS.TravelService)
		local P = game.Players:GetPlayers()[1]
		SS.HoldClock = true
		local Ok, Err = pcall(function()
			TS.AddTicket(P, "LindenmoorFoundry", "Third")
			local Zone
			for _, d in ipairs(workspace:GetDescendants()) do
				if d.Name:find("BoardZone") and d:GetAttribute("CarKind") == "ThirdClass" and d:FindFirstAncestor("PlatformTrain") then Zone = d break end
			end
			P.Character:PivotTo(Zone.CFrame)
			task.wait(0.5)
			local t0 = os.clock()
			SS.DepartNow("LindenmoorFoundry", 10)
			task.wait(1.5)
			T.Eq(SS.Riding(P), "LindenmoorFoundry", "riding")
			local Old = P.Character
			Old.Humanoid.Health = 0
			task.wait(0.3)
			T.Eq(SS.Riding(P), nil, "off the ride at death")
			local t1 = os.clock()
			while (P.Character == Old or not (P.Character and P.Character:FindFirstChild("HumanoidRootPart"))) and os.clock() - t1 < 12 do task.wait(0.2) end
			local New = P.Character
			T.True(New ~= Old and New:FindFirstChild("HumanoidRootPart"), "respawned")
			task.wait(2)
			T.True(os.clock() - t0 < 10, "still within the ride (" .. math.floor(os.clock() - t0) .. " s)")
			T.True(New.HumanoidRootPart.Position.Y < 300, "the new character stays in town (y " .. math.floor(New.HumanoidRootPart.Position.Y) .. ")")
			while os.clock() - t0 < 11 do task.wait(0.2) end
			T.True(New.HumanoidRootPart.Position.Y < 300, "still in town after the ride")
			T.Eq(TS.HasTicket(P, "LindenmoorFoundry"), "Third", "the ticket is kept")
		end)
		SS.HoldClock = false
		if TS.HasTicket(P, "LindenmoorFoundry") then TS.UseTicket(P, "LindenmoorFoundry") end
		local t2 = os.clock()
		while not (P.Character and P.Character:FindFirstChild("HumanoidRootPart")) and os.clock() - t2 < 10 do task.wait(0.2) end
		T.True(Ok, tostring(Err))
	end,
	-- task 6b: dropping onto (or brushing) a seat doesn't sit you; every seat has its Sit prompt
	BrushingASeatDoesNotSeatYou = function(T)
		local P = game.Players:GetPlayers()[1]
		local H = P.Character.Humanoid
		StandUp(H)
		local CS = game:GetService("CollectionService")
		local Bad, Count = 0, 0
		for _, Tag in ipairs({"RenseiPlatformTrain", "RenseiRideTrain"}) do
			for _, Train in ipairs(CS:GetTagged(Tag)) do
				for _, S in ipairs(Train:GetDescendants()) do
					if S:IsA("Seat") then
						Count += 1
						local Pr = SitPrompt(S)
						if S.CanTouch or not Pr or Pr.Style ~= Enum.ProximityPromptStyle.Custom or Pr.ActionText ~= "Sit"
							or Pr.MaxActivationDistance ~= 5 or Pr.HoldDuration ~= 0 or not Pr.RequiresLineOfSight
							or Pr.Exclusivity ~= Enum.ProximityPromptExclusivity.OnePerButton or Pr.KeyboardKeyCode ~= Enum.KeyCode.E
							or Pr.Enabled ~= (S.Occupant == nil) or not (Pr.Parent:IsA("Attachment") and Pr.Parent.Parent == S) then Bad += 1 end
					end
				end
			end
		end
		T.Eq(Count, 128, "seats in both trains")
		T.Eq(Bad, 0, "every seat: no touch, a Custom Sit prompt")
		local Platform = workspace:FindFirstChild("PlatformTrain", true)
		T.Eq(SitPrompt(FreeSeat(Platform.CabinCar_Main)).ObjectText, "Private cabin")
		T.Eq(SitPrompt(FreeSeat(Platform.ThirdClass_Main)).ObjectText, "3rd class")
		-- dropped onto three seats in turn, then walked across one: never seated
		local Seats = {FreeSeat(Platform.ThirdClass_Main), FreeSeat(Platform.DiningCar_Main), FreeSeat(Platform.SecondClass_Main)}
		for _, S in ipairs(Seats) do
			P.Character:PivotTo(CFrame.new(S.Position + Vector3.new(0, 3.2, 0)))
			task.wait(1)
			T.True(H.SeatPart == nil, "not seated after dropping onto " .. S:GetFullName())
		end
		local S = Seats[1]
		P.Character:PivotTo(CFrame.new(S.Position + Vector3.new(0, 3.2, 0) - S.CFrame.RightVector * 1.2))
		task.wait(0.4)
		H:MoveTo(S.Position + S.CFrame.RightVector * 1.2)
		task.wait(1.2)
		T.True(H.SeatPart == nil, "not seated after walking across the seat")
		-- control: the same drop onto a touchable seat does sit you (so the checks above mean something); with a ticket,
		-- since fix round 1 stands up anyone seated where their ticket doesn't reach
		local SS, TS = require(SSS.StationService), require(SSS.TravelService)
		SS.HoldClock = true
		TS.AddTicket(P, "LindenmoorFoundry", "Third")
		S.CanTouch = true
		P.Character:PivotTo(CFrame.new(S.Position + Vector3.new(0, 3.2, 0)))
		local t0 = os.clock()
		while H.SeatPart ~= S and os.clock() - t0 < 2 do task.wait(0.1) end
		local Control = H.SeatPart == S
		S.CanTouch = false
		StandUp(H)
		SS.HoldClock = false
		if TS.HasTicket(P, "LindenmoorFoundry") then TS.UseTicket(P, "LindenmoorFoundry") end
		T.True(Control, "control: a touchable seat sits you")
	end,
	-- task 6b: the prompt's request seats you (with a ticket for that car), hides the prompt, and standing frees it
	ThePromptSeatsYou = function(T)
		local SS, TS = require(SSS.StationService), require(SSS.TravelService)
		local P = game.Players:GetPlayers()[1]
		local H = P.Character.Humanoid
		StandUp(H)
		SS.HoldClock = true -- a scheduled departure would carry the seated tester into the ride train
		TS.AddTicket(P, "LindenmoorFoundry", "Third")
		local Ok, Err = pcall(function()
			local Platform = workspace:FindFirstChild("PlatformTrain", true)
			local S = FreeSeat(Platform.ThirdClass_Main)
			P.Character:PivotTo(Near(S))
			task.wait(0.7)
			local Sat, Why = SS.TrySit(P, S)
			T.True(Sat, "request accepted (" .. tostring(Why) .. ")")
			task.wait(0.5)
			T.True(H.SeatPart == S, "seated in the chosen seat")
			T.True(not SitPrompt(S).Enabled, "the prompt hides while the seat is taken")
			StandUp(H)
			T.True(H.SeatPart == nil, "stood up")
			T.True(SitPrompt(S).Enabled, "the prompt is back once the seat is free")
			-- refused: too far away, and too soon after a request
			P.Character:PivotTo(CFrame.new(S.Position + Vector3.new(0, 3, 0) + S.CFrame.LookVector * 12))
			task.wait(0.7)
			local Far, FarWhy = SS.TrySit(P, S)
			T.True(not Far and FarWhy == "too far", "too far (" .. tostring(FarWhy) .. ")")
			local Soon, SoonWhy = SS.TrySit(P, S)
			T.True(not Soon and SoonWhy == "too soon", "rate limited (" .. tostring(SoonWhy) .. ")")
			-- refused: knocked down
			P.Character:PivotTo(Near(S))
			task.wait(0.7)
			P.Character:SetAttribute("Knocked", true)
			local Down, DownWhy = SS.TrySit(P, S)
			P.Character:SetAttribute("Knocked", nil)
			T.True(not Down and DownWhy == "down", "not while knocked (" .. tostring(DownWhy) .. ")")
			T.True(H.SeatPart == nil, "still standing")
		end)
		SS.HoldClock = false
		StandUp(H)
		if TS.HasTicket(P, "LindenmoorFoundry") then TS.UseTicket(P, "LindenmoorFoundry") end
		T.True(Ok, tostring(Err))
	end,
	-- task 6b: a 3rd-class ticket can't sit in a cabin seat, and the conductor says why
	ThirdClassCantSitInACabinSeat = function(T)
		local SS, TS, UI = require(SSS.StationService), require(SSS.TravelService), require(SSS.UIService)
		local P = game.Players:GetPlayers()[1]
		local H = P.Character.Humanoid
		StandUp(H)
		SS.HoldClock = true
		TS.AddTicket(P, "LindenmoorFoundry", "Third")
		local Said = {}
		local Real = UI.Notify
		UI.Notify = function(Who, Kind, Data)
			if Who == P and Kind == "Toast" and type(Data) == "table" then table.insert(Said, tostring(Data.Text)) end
			return Real(Who, Kind, Data)
		end
		local Ok, Err = pcall(function()
			local Platform = workspace:FindFirstChild("PlatformTrain", true)
			local S = FreeSeat(Platform.CabinCar_Main)
			P.Character:PivotTo(Near(S))
			task.wait(0.7)
			local Sat, Why = SS.TrySit(P, S)
			task.wait(0.4)
			T.True(not Sat and Why == "class", "refused (" .. tostring(Why) .. ")")
			T.True(H.SeatPart == nil, "not seated")
			T.Eq(Said[#Said], "Conductor: \"That seat's for Private cabin passengers.\"", "the conductor's line")
		end)
		UI.Notify = Real
		SS.HoldClock = false
		StandUp(H)
		if TS.HasTicket(P, "LindenmoorFoundry") then TS.UseTicket(P, "LindenmoorFoundry") end
		T.True(Ok, tostring(Err))
	end,
	-- task 6b: someone who sat down through the prompt rides in the matching ride-train seat (CanTouch off there too)
	SeatedRiderRidesInTheMatchingSeat = function(T)
		local SS, TS = require(SSS.StationService), require(SSS.TravelService)
		local P = game.Players:GetPlayers()[1]
		local H = P.Character.Humanoid
		StandUp(H)
		SS.HoldClock = true
		TS.AddTicket(P, "LindenmoorFoundry", "Third")
		local Ok, Err = pcall(function()
			local Platform = workspace:FindFirstChild("PlatformTrain", true)
			local Ride = workspace:FindFirstChild("RideTrain", true)
			local S = FreeSeat(Platform.ThirdClass_Main)
			local Before = {}
			for _, R in ipairs(Ride:GetDescendants()) do if R:IsA("Seat") then Before[R] = R.Position end end
			P.Character:PivotTo(Near(S))
			task.wait(0.7)
			T.True(SS.TrySit(P, S), "sat down")
			task.wait(0.5)
			T.True(H.SeatPart == S, "seated on the platform train")
			local t0 = os.clock()
			SS.DepartNow("LindenmoorFoundry", 4)
			task.wait(1.5)
			local Want = (Ride:GetPivot() * Platform:GetPivot():Inverse() * S.CFrame).Position
			local In = H.SeatPart
			T.True(In ~= nil and In:IsDescendantOf(Ride.ThirdClass_Main) and (In.Position - Want).Magnitude < 0.2,
				"seated in the matching ride-train seat (" .. tostring(In and In:GetFullName()) .. ")")
			T.True(In ~= nil and not SitPrompt(In).Enabled, "its prompt hides")
			while TS.HasTicket(P, "LindenmoorFoundry") and os.clock() - t0 < 10 do task.wait(0.2) end
			T.Eq(TS.HasTicket(P, "LindenmoorFoundry"), nil, "arrived and used the ticket")
			T.True(H.SeatPart == nil, "stood up on arrival")
			local Moved = 0
			for R, At in pairs(Before) do if (R.Position - At).Magnitude > 0.01 then Moved += 1 end end
			T.Eq(Moved, 0, "no ride-train seat moved")
			T.True(In == nil or SitPrompt(In).Enabled, "the ride-train seat's prompt is back")
		end)
		SS.HoldClock = false
		StandUp(H)
		if TS.HasTicket(P, "LindenmoorFoundry") then TS.UseTicket(P, "LindenmoorFoundry") end
		T.True(Ok, tostring(Err))
	end,
	-- task 6b fix 1: a window seat is within reach of the platform edge, but you can't sit in it through the car wall
	SittingThroughTheWallFromThePlatformIsRefused = function(T)
		local SS, TS = require(SSS.StationService), require(SSS.TravelService)
		local P = game.Players:GetPlayers()[1]
		local H = P.Character.Humanoid
		StandUp(H)
		SS.HoldClock = true
		TS.AddTicket(P, "LindenmoorFoundry", "Third")
		local Ok, Err = pcall(function()
			local Platform = workspace:FindFirstChild("PlatformTrain", true)
			-- Task 11: Ye's station has a thin PlatformEdge strip; Foundry's placeholder has only the 12-wide Platform
			-- (World.Map.Foundry.Platform), so stand on its track-side edge, 0.4 in (on Ye's 0.8 strip that is its middle)
			local Edge = Platform.Parent:FindFirstChild("PlatformEdge") or Platform.Parent.Parent:FindFirstChild("Platform")
			local Side = math.sign(Edge.CFrame:PointToObjectSpace(Platform:GetPivot().Position).X)
			local EdgeX = Side * math.max(0, Edge.Size.X / 2 - 0.4)
			local Best, BestD, Stand
			for _, S in ipairs(Platform.ThirdClass_Main:GetDescendants()) do
				if S:IsA("Seat") and not S.Occupant then
					local L = Edge.CFrame:PointToObjectSpace(S.Position)
					local At = Edge.CFrame * Vector3.new(EdgeX, Edge.Size.Y / 2 + 3, math.clamp(L.Z, -Edge.Size.Z / 2, Edge.Size.Z / 2))
					local D = (At - S.Position).Magnitude
					if not BestD or D < BestD then Best, BestD, Stand = S, D, At end
				end
			end
			P.Character:PivotTo(CFrame.new(Stand))
			task.wait(0.7)
			local D = (P.Character.HumanoidRootPart.Position - Best.Position).Magnitude
			T.True(D <= SS.SitReach, "the window seat is within the server reach from the edge (" .. math.floor(D * 10) / 10 .. ")")
			T.True(SS.CarAt(Platform, P.Character.HumanoidRootPart.Position) == nil, "standing outside the train")
			local Sat, Why = SS.TrySit(P, Best)
			task.wait(0.3)
			T.True(not Sat and Why == "outside", "refused (" .. tostring(Why) .. ")")
			T.True(H.SeatPart == nil, "not seated")
		end)
		SS.HoldClock = false
		if TS.HasTicket(P, "LindenmoorFoundry") then TS.UseTicket(P, "LindenmoorFoundry") end
		T.True(Ok, tostring(Err))
	end,
	-- task 6b fix 1: dying in a seat frees it, and the new character can sit in it
	DeathWhileSeatedFreesTheSeat = function(T)
		local SS, TS = require(SSS.StationService), require(SSS.TravelService)
		local P = game.Players:GetPlayers()[1]
		StandUp(P.Character.Humanoid)
		SS.HoldClock = true
		TS.AddTicket(P, "LindenmoorFoundry", "Third")
		local Ok, Err = pcall(function()
			local Platform = workspace:FindFirstChild("PlatformTrain", true)
			local S = FreeSeat(Platform.ThirdClass_Main)
			P.Character:PivotTo(Near(S))
			task.wait(0.7)
			T.True(SS.TrySit(P, S), "sat down")
			task.wait(0.5)
			local Old = P.Character
			T.True(Old.Humanoid.SeatPart == S, "seated")
			Old.Humanoid.Health = 0
			local t1 = os.clock()
			while (P.Character == Old or not (P.Character and P.Character:FindFirstChild("HumanoidRootPart"))) and os.clock() - t1 < 12 do task.wait(0.2) end
			local New = P.Character
			T.True(New ~= Old and New:FindFirstChild("HumanoidRootPart"), "respawned")
			task.wait(0.5)
			T.True(S.Occupant == nil, "the seat is free")
			T.True(SitPrompt(S).Enabled, "its prompt is back")
			New:PivotTo(Near(S))
			task.wait(0.7)
			local Sat, Why = SS.TrySit(P, S)
			T.True(Sat, "the new character can sit (" .. tostring(Why) .. ")")
			task.wait(0.5)
			T.True(New.Humanoid.SeatPart == S, "the new character is seated")
		end)
		SS.HoldClock = false
		local t2 = os.clock()
		while not (P.Character and P.Character:FindFirstChild("HumanoidRootPart")) and os.clock() - t2 < 10 do task.wait(0.2) end
		if P.Character then StandUp(P.Character.Humanoid) end
		if TS.HasTicket(P, "LindenmoorFoundry") then TS.UseTicket(P, "LindenmoorFoundry") end
		T.True(Ok, tostring(Err))
	end,
	-- task 6b fix 1: seated by any other way where the ticket doesn't reach, you're stood up
	TheOccupantGuardStandsUpTheWrongClass = function(T)
		local SS, TS = require(SSS.StationService), require(SSS.TravelService)
		local P = game.Players:GetPlayers()[1]
		local H = P.Character.Humanoid
		StandUp(H)
		SS.HoldClock = true
		TS.AddTicket(P, "LindenmoorFoundry", "Third")
		local Ok, Err = pcall(function()
			local Platform = workspace:FindFirstChild("PlatformTrain", true)
			local S = FreeSeat(Platform.CabinCar_Main)
			P.Character:PivotTo(Near(S))
			task.wait(0.7)
			S:Sit(H) -- not through TrySit
			local t0 = os.clock()
			repeat task.wait(0.1) until (H.SeatPart ~= S and os.clock() - t0 > 0.2) or os.clock() - t0 > 2
			T.True(H.SeatPart ~= S, "stood up from the cabin seat")
			T.True(S.Occupant == nil and SitPrompt(S).Enabled, "the seat is free again")
		end)
		SS.HoldClock = false
		StandUp(H)
		if TS.HasTicket(P, "LindenmoorFoundry") then TS.UseTicket(P, "LindenmoorFoundry") end
		T.True(Ok, tostring(Err))
	end,
	-- task 6b fix 1: no sitting down while being moved (the departure fade)
	NoSittingDuringTheFade = function(T)
		local SS, TS = require(SSS.StationService), require(SSS.TravelService)
		local P = game.Players:GetPlayers()[1]
		local H = P.Character.Humanoid
		StandUp(H)
		SS.HoldClock = true
		TS.AddTicket(P, "LindenmoorFoundry", "Third")
		local Ok, Err = pcall(function()
			local Platform = workspace:FindFirstChild("PlatformTrain", true)
			local S = FreeSeat(Platform.ThirdClass_Main)
			P.Character:PivotTo(Near(S))
			task.wait(0.7)
			local t0 = os.clock()
			SS.DepartNow("LindenmoorFoundry", 3)
			task.wait(0.2)
			T.True(SS.NoSit(P), "in the no-sit window during the fade")
			local Sat, Why = SS.TrySit(P, S)
			T.True(not Sat and Why == "moving", "refused during the fade (" .. tostring(Why) .. ")")
			task.wait(1)
			T.True(not SS.NoSit(P), "free to sit again once moved")
			T.True(H.SeatPart == nil, "not seated")
			while TS.HasTicket(P, "LindenmoorFoundry") and os.clock() - t0 < 10 do task.wait(0.2) end
			T.Eq(TS.HasTicket(P, "LindenmoorFoundry"), nil, "arrived and used the ticket")
			T.True(not SS.NoSit(P), "the window is closed after the ride")
		end)
		SS.HoldClock = false
		StandUp(H)
		if TS.HasTicket(P, "LindenmoorFoundry") then TS.UseTicket(P, "LindenmoorFoundry") end
		T.True(Ok, tostring(Err))
	end,

	-- final fix wave (I2): nobody down, gripped, carried, gripping or carrying boards; the conductor says why
	HeldPlayersDontBoard = function(T)
		local SS, TS = require(SSS.StationService), require(SSS.TravelService)
		local P = game.Players:GetPlayers()[1]
		local C = P.Character
		local R = {}
		SS.HoldClock = true
		local Ok, Err = pcall(function()
			TS.AddTicket(P, ROUTE, "Third")
			C:PivotTo(Zone("PlatformTrain", "ThirdClass").CFrame)
			task.wait(0.5)
			R.Free = table.find((SS.Aboard(ROUTE)), P) ~= nil
			for _, Name in ipairs(HELD) do
				C:SetAttribute(Name, Name == "Knocked" and true or "Someone")
				SS.ResetGate(P)
				local Got = Toasts(function() R[Name] = table.find((SS.Aboard(ROUTE)), P) ~= nil end)
				R[Name .. "Told"] = table.find(Got, "Conductor: \"Not like that. Nobody boards down, held or holding someone.\"") ~= nil
				C:SetAttribute(Name, nil)
			end
		end)
		for _, Name in ipairs(HELD) do C:SetAttribute(Name, nil) end
		SS.HoldClock = false
		SS.ResetGate(P)
		T.True(Ok, tostring(Err))
		T.Eq(R.Free, true, "aboard when nothing holds them")
		for _, Name in ipairs(HELD) do
			T.Eq(R[Name], false, Name .. ": not aboard")
			T.Eq(R[Name .. "Told"], true, Name .. ": told why")
		end
	end,
	-- final fix wave (I2): knocked during the "doors closing" fade: left behind on the platform, the ticket kept
	KnockedDuringTheFadeStaysBehind = function(T)
		local SS, TS = require(SSS.StationService), require(SSS.TravelService)
		local P = game.Players:GetPlayers()[1]
		local C = P.Character
		local R = {}
		SS.HoldClock = true
		local Ok, Err = pcall(function()
			TS.AddTicket(P, ROUTE, "Third")
			C:PivotTo(Zone("PlatformTrain", "ThirdClass").CFrame)
			task.wait(0.5)
			SS.DepartNow(ROUTE, 3)
			R.Riding = SS.Riding(P)
			C:SetAttribute("Knocked", true) -- (in the fade: the move hasn't happened yet)
			task.wait(SS.FadeTime + 0.6)
			R.After = SS.Riding(P)
			R.Y = C.HumanoidRootPart.Position.Y
			C:SetAttribute("Knocked", nil)
			task.wait(3)
			R.Ticket = TS.HasTicket(P, ROUTE)
		end)
		C:SetAttribute("Knocked", nil)
		SS.HoldClock = false
		T.True(Ok, tostring(Err))
		T.Eq(R.Riding, ROUTE, "boarded before the fade")
		T.Eq(R.After, nil, "off the ride")
		T.True(R.Y < 300, "not moved into the ride train (y " .. math.floor(R.Y) .. ")")
		T.Eq(R.Ticket, "Third", "the ticket is kept")
	end,
	-- final fix wave (I2): someone in the ride train who isn't riding it (a carried non-rider) is put on the platform;
	-- riders still waiting for their teleport are left alone
	NonRiderInTheRideTrainIsPutBack = function(T)
		local SS = require(SSS.StationService)
		local P = game.Players:GetPlayers()[1]
		local R = {}
		local Ok, Err = pcall(function()
			P.Character:PivotTo(Zone("RideTrain", "ThirdClass").CFrame)
			task.wait(0.5)
			R.Kept = SS.Sweep(ROUTE, {[P] = true})
			R.Y = P.Character.HumanoidRootPart.Position.Y
			R.Swept = SS.Sweep(ROUTE)
			task.wait(0.3)
			R.D = PlatformDist(P)
		end)
		T.True(Ok, tostring(Err))
		T.Eq(R.Kept, 0, "a rider waiting for the teleport stays")
		T.True(R.Y > 300, "(was in the ride train, y " .. math.floor(R.Y) .. ")")
		T.Eq(R.Swept, 1, "the non-rider is swept out")
		T.True(R.D < 8, "back on the platform (" .. math.floor(R.D) .. ")")
	end,
	-- final fix wave (I6): live, a rider still here after HoldDeadline goes back to the platform if their save is
	-- loaded, and is kicked if it was released. (Watch runs only after a live "sent"; called directly here.)
	StalledTeleportWatchdog = function(T)
		local SS, PS = require(SSS.StationService), require(SSS.ProgressionService)
		local P = game.Players:GetPlayers()[1]
		local R = {}
		local OldGet, OldKick = PS.GetData, SS.Kick
		local Ok, Err = pcall(function()
			P.Character:PivotTo(Zone("RideTrain", "ThirdClass").CFrame)
			task.wait(0.3)
			SS.Watch({[P] = true}, "the Foundry Yard", 0.2, {[P] = true})
			task.wait(0.8)
			R.D = PlatformDist(P)
			SS.Kick = function(Q, Text) if Q == P then R.Kicked = Text end end
			PS.GetData = function(Q, ...) if Q == P then return nil end return OldGet(Q, ...) end -- a released save
			SS.Watch({[P] = true}, "the Foundry Yard", 0.05, {[P] = true})
			task.wait(0.3)
			PS.GetData = OldGet
		end)
		PS.GetData, SS.Kick = OldGet, OldKick
		T.True(Ok, tostring(Err))
		T.True(R.D < 8, "save loaded: back on the platform (" .. math.floor(R.D or -1) .. ")")
		T.True(type(R.Kicked) == "string" and R.Kicked:find("couldn't be completed") ~= nil, "save released: kicked (" .. tostring(R.Kicked) .. ")")
	end,
}

-- final fix wave (ledger note :188, as Play_Gate does): any ticket the tester's real save holds for the test route
-- is put aside for each test and given back afterwards, so a held (say, Private cabin) ticket can't change a result
local function Mine(K) return K:sub(1, #ROUTE + 1) == ROUTE .. "|" end
for Name, Fn in pairs(Suite) do
	Suite[Name] = function(T)
		local P = game.Players:GetPlayers()[1]
		local Tk = require(SSS.TravelService).Tickets(P)
		local Saved = {}
		for K, V in pairs(Tk) do
			if Mine(K) then Saved[K] = V end
		end
		for K in pairs(Saved) do Tk[K] = nil end
		local Ok, Err = pcall(Fn, T)
		for K in pairs(Tk) do
			if Mine(K) then Tk[K] = nil end
		end
		for K, V in pairs(Saved) do Tk[K] = V end
		if not Ok then error(Err, 0) end
	end
end
return Suite

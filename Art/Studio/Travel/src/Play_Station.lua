local SSS = game.ServerScriptService
return {
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
	-- review fix 2: a seat taken before the fade, in a car the ticket doesn't reach, isn't carried over
	CabinSeatBeforeTheFadeIsNotCarriedOver = function(T)
		local SS, TS = require(SSS.StationService), require(SSS.TravelService)
		local Travel = require(game.ReplicatedStorage.Modules.Data.Rensei.Travel)
		SS.HoldClock = true
		local P = game.Players:GetPlayers()[1]
		local H = P.Character.Humanoid
		TS.AddTicket(P, "LindenmoorFoundry", "Third")
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
		T.True(Kind ~= nil and Travel.ClassReaches("Third", Kind), "rides in a car 3rd class reaches (" .. tostring(In and In.Name) .. ")")
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
}

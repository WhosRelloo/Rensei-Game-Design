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
}

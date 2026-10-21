local SSS = game.ServerScriptService
return {
	InspectionFinesTheTicketless = function(T)
		local RE, PS = require(SSS.RideEvents), require(SSS.ProgressionService)
		local P = game.Players:GetPlayers()[1]
		local D = PS.GetData(P)
		local Money = D.Money
		D.Money = 100
		RE.Run("Inspection", "LindenmoorFoundry", {P}, {[P] = false}) -- false = boarded without a ticket (stowaway)
		T.Eq(PS.GetData(P).Money, 100 - 45, "fined 3x the base price")
		D.Money = Money
	end,
	RumourEventTellsSomething = function(T)
		local RE = require(SSS.RideEvents)
		local P = game.Players:GetPlayers()[1]
		local Said = RE.Run("Rumour", "LindenmoorFoundry", {P}, {[P] = true})
		T.True(type(Said) == "string" and #Said > 0, "a rumour line")
	end,
	HoldupSpawnsBandits = function(T)
		local RE = require(SSS.RideEvents)
		local P = game.Players:GetPlayers()[1]
		local Spawned = RE.Run("Holdup", "LindenmoorFoundry", {P}, {[P] = true})
		T.True(type(Spawned) == "number" and Spawned >= 1, "bandits in the aisle")
		RE.ClearHoldup()
	end,
	-- added (task 7): never fined below $0; whoever can't pay is marked to be thrown off
	InspectionNeverFinesBelowZero = function(T)
		local RE, PS = require(SSS.RideEvents), require(SSS.ProgressionService)
		local P = game.Players:GetPlayers()[1]
		local D = PS.GetData(P)
		local Money = D.Money
		D.Money = 10
		local Ok, Err = pcall(RE.Run, "Inspection", "LindenmoorFoundry", {P}, {[P] = false})
		local After, Off = PS.GetData(P).Money, P:GetAttribute("ThrownOff")
		P:SetAttribute("ThrownOff", nil)
		D.Money = Money
		T.True(Ok, tostring(Err))
		T.Eq(After, 10, "nothing taken")
		T.Eq(Off, true, "thrown off at the next stop")
	end,
	-- added (task 7): $5-15, and never more than they carry
	PickpocketLiftsFiveToFifteen = function(T)
		local RE, PS = require(SSS.RideEvents), require(SSS.ProgressionService)
		local P = game.Players:GetPlayers()[1]
		local D = PS.GetData(P)
		local Money = D.Money
		D.Money = 100
		local Took = RE.Run("Pickpocket", "LindenmoorFoundry", {P}, {[P] = true})
		local After = PS.GetData(P).Money
		D.Money = 3
		local Took2 = RE.Run("Pickpocket", "LindenmoorFoundry", {P}, {[P] = true})
		local After2 = PS.GetData(P).Money
		D.Money = Money
		T.True(type(Took) == "number" and Took >= 5 and Took <= 15, "took " .. tostring(Took))
		T.Eq(After, 100 - Took, "taken from the rider")
		T.True(Took2 <= 3 and After2 == 3 - Took2 and After2 >= 0, "only what they carry (" .. tostring(Took2) .. ")")
	end,
	-- added (task 7): the bandits stand in the ride train's dining car, are put back if they leave the train,
	-- and are removed (not killed) by ClearHoldup
	HoldupBanditsStayAboardAndAreCleared = function(T)
		local RE, SS = require(SSS.RideEvents), require(SSS.StationService)
		local ES = require(SSS.EnemyService)
		local P = game.Players:GetPlayers()[1]
		local Ok, Err = pcall(function()
			local N = RE.Run("Holdup", "LindenmoorFoundry", {P}, {[P] = true})
			local Rigs = RE.BanditsOf("LindenmoorFoundry")
			T.Eq(#Rigs, N, "every bandit listed")
			T.Eq(N, 2, "two bandits")
			local Ride = workspace:FindFirstChild("RideTrain", true)
			for _, Rig in ipairs(Rigs) do
				local Car = SS.CarAt(Ride, Rig.HumanoidRootPart.Position)
				T.True(Car and SS.CarKind(Car) == "DiningCar", "in the dining car (" .. tostring(Car and Car.Name) .. ")")
				T.True(ES.Active[Rig] ~= nil, "a live EnemyService enemy")
				Rig:SetAttribute("AIPassive", true)
			end
			local Rig = Rigs[1]
			Rig:PivotTo(Rig:GetPivot() - Vector3.new(0, 60, 0)) -- out of the train
			task.wait(1.2)
			local Car = SS.CarAt(Ride, Rig.HumanoidRootPart.Position)
			T.True(Car ~= nil, "put back in the train (y " .. math.floor(Rig.HumanoidRootPart.Position.Y) .. ")")
			RE.ClearHoldup()
			task.wait()
			for _, R in ipairs(Rigs) do
				T.True(R.Parent == nil and ES.Active[R] == nil, "removed")
			end
		end)
		RE.ClearHoldup()
		T.True(Ok, tostring(Err))
	end,
	-- added (task 7): a real departure runs the ride's event, and a holdup ends with the ride
	DepartureRunsTheEventAndTheHoldupEndsAtArrival = function(T)
		local RE, SS, TS = require(SSS.RideEvents), require(SSS.StationService), require(SSS.TravelService)
		local P = game.Players:GetPlayers()[1]
		SS.HoldClock = true
		local Ok, Err = pcall(function()
			RE.Force = "Holdup"
			TS.AddTicket(P, "LindenmoorFoundry", "Third")
			local Zone
			for _, d in ipairs(workspace:GetDescendants()) do
				if d.Name:find("BoardZone") and d:GetAttribute("CarKind") == "ThirdClass" and d:FindFirstAncestor("PlatformTrain") then Zone = d break end
			end
			P.Character:PivotTo(Zone.CFrame)
			task.wait(0.5)
			SS.DepartNow("LindenmoorFoundry", 8) -- the event comes 0.3 x 8 = 2.4 s in
			local t0, Rigs = os.clock(), {}
			while #Rigs == 0 and os.clock() - t0 < 6 do task.wait(0.2) Rigs = RE.BanditsOf("LindenmoorFoundry") end
			for _, Rig in ipairs(Rigs) do Rig:SetAttribute("AIPassive", true) end
			T.True(#Rigs >= 1, "a holdup mid-ride")
			T.True(SS.Riding(P) == "LindenmoorFoundry", "while the player rides")
			T.True(RE.Force == nil, "Force is used once")
			while TS.HasTicket(P, "LindenmoorFoundry") and os.clock() - t0 < 14 do task.wait(0.2) end
			T.Eq(TS.HasTicket(P, "LindenmoorFoundry"), nil, "arrived and used the ticket")
			task.wait(0.6)
			T.Eq(#RE.BanditsOf("LindenmoorFoundry"), 0, "bandits gone at arrival")
			for _, Rig in ipairs(Rigs) do T.True(Rig.Parent == nil, "rig removed") end
		end)
		RE.Force = nil
		RE.ClearHoldup()
		SS.HoldClock = false
		if TS.HasTicket(P, "LindenmoorFoundry") then TS.UseTicket(P, "LindenmoorFoundry") end
		T.True(Ok, tostring(Err))
	end,
}

local SSS = game.ServerScriptService
return {
	TicketsAddUseAndKeepCount = function(T)
		local TS = require(SSS.TravelService)
		local P = game.Players:GetPlayers()[1]
		local Before = TS.HasTicket(P, "LindenmoorFoundry")
		TS.AddTicket(P, "LindenmoorFoundry", "Second")
		T.Eq(TS.HasTicket(P, "LindenmoorFoundry"), "Second")
		T.Eq(TS.UseTicket(P, "LindenmoorFoundry"), "Second")
		T.Eq(TS.HasTicket(P, "LindenmoorFoundry"), Before)
	end,
	LoopbackArrivesAtThePlatform = function(T)
		local TS = require(SSS.TravelService)
		local P = game.Players:GetPlayers()[1]
		T.True(TS.ArrivalPoint("Platform") ~= nil, "this place has a Platform arrival point")
		TS.AddTicket(P, "LindenmoorFoundry", "Third")
		local Got
		local C = TS.Arrived.Event:Connect(function(Who, Region, Route) if Who == P then Got = {Region, Route} end end)
		T.Eq(TS.Depart({P}, "LindenmoorFoundry", "Platform"), "loopback")
		local t0 = os.clock()
		while not Got and os.clock() - t0 < 5 do task.wait(0.1) end
		C:Disconnect()
		T.True(Got ~= nil, "Arrived fired")
		T.Eq(Got[1], TS.Here(), "loopback stays in this region")
		local d = (P.Character.HumanoidRootPart.Position - TS.ArrivalPoint("Platform").Position).Magnitude
		T.True(d < 8, "standing at the platform (" .. d .. ")")
		T.Eq(TS.HasTicket(P, "LindenmoorFoundry"), nil, "ticket used on arrival")
	end,
	HereMatchesThePlace = function(T)
		local TS = require(SSS.TravelService)
		local Places = require(game.ReplicatedStorage.Modules.Data.Rensei.Places)
		T.Eq(TS.Here(), Places.RegionOf(game.PlaceId) or "Lindenmoor")
	end,
	-- review fix 2026-10-21: arrivals trust the save, never TeleportData
	ForgedJoinIsRefused = function(T)
		local TS = require(SSS.TravelService)
		local P = game.Players:GetPlayers()[1]
		local D = require(SSS.ProgressionService).GetData(P)
		local Saved = {Region = D.Travel.Region, Trip = D.Travel.Trip}
		local Other = TS.Here() == "Foundry" and "City" or "Foundry"
		D.Travel.Region, D.Travel.Trip = Other, nil
		local Fired = false
		local C = TS.Arrived.Event:Connect(function(Who) if Who == P then Fired = true end end)
		local Ok, Res = pcall(TS._Join, P, {Route = "LindenmoorFoundry", Arrive = "Platform", From = Other})
		task.wait(0.3)
		C:Disconnect()
		local Region = D.Travel.Region
		D.Travel.Region, D.Travel.Trip = Saved.Region, Saved.Trip
		T.True(Ok, tostring(Res))
		T.Eq(Res, "refused")
		T.Eq(Region, Other, "region unchanged")
		T.Eq(Fired, false, "no Arrived")
	end,
	TripHereArrivesAndBurnsThatClass = function(T)
		local TS = require(SSS.TravelService)
		local P = game.Players:GetPlayers()[1]
		local D = require(SSS.ProgressionService).GetData(P)
		local Tk = TS.Tickets(P)
		local K3, K2 = "LindenmoorFoundry|Third", "LindenmoorFoundry|Second"
		local B3, B2 = Tk[K3] or 0, Tk[K2] or 0
		TS.AddTicket(P, "LindenmoorFoundry", "Third")
		TS.AddTicket(P, "LindenmoorFoundry", "Second")
		D.Travel.Trip = {Route = "LindenmoorFoundry", To = TS.Here(), Arrive = "Platform", Class = "Third"}
		local Got
		local C = TS.Arrived.Event:Connect(function(Who, Region) if Who == P then Got = Region end end)
		local Res = TS._Join(P, nil)
		local t0 = os.clock()
		while not Got and os.clock() - t0 < 2 do task.wait(0.1) end -- deferred signals: handlers run after a yield
		C:Disconnect()
		local A3, A2, Trip, Region = Tk[K3] or 0, Tk[K2] or 0, D.Travel.Trip, D.Travel.Region
		TS.UseTicket(P, "LindenmoorFoundry", "Second")
		T.Eq(Res, "arrived")
		T.Eq(Got, TS.Here(), "Arrived fired here")
		T.Eq(A3, B3, "the Trip's Third ticket burned")
		T.Eq(A2, B2 + 1, "the better Second ticket kept")
		T.Eq(Trip, nil, "Trip cleared")
		T.Eq(Region, TS.Here(), "Region = here")
	end,
	StaleTripIsClearedTicketKept = function(T)
		local TS = require(SSS.TravelService)
		local P = game.Players:GetPlayers()[1]
		local D = require(SSS.ProgressionService).GetData(P)
		local Before = TS.HasTicket(P, "LindenmoorFoundry")
		TS.AddTicket(P, "LindenmoorFoundry", "Cabin")
		local Other = TS.Here() == "Foundry" and "Lindenmoor" or "Foundry"
		local OldRegion = D.Travel.Region
		D.Travel.Region = TS.Here() -- the save says "here" (Task 10: without it, Foundry's _Join would refuse)
		D.Travel.Trip = {Route = "LindenmoorFoundry", To = Other, Arrive = "Platform", Class = "Cabin"}
		local Res = TS._Join(P, nil)
		D.Travel.Region = OldRegion
		local Trip, Held = D.Travel.Trip, TS.HasTicket(P, "LindenmoorFoundry")
		TS.UseTicket(P, "LindenmoorFoundry", "Cabin")
		T.Eq(Res, "kept")
		T.Eq(Trip, nil, "stale Trip cleared")
		T.Eq(Held, "Cabin", "ticket kept")
		T.Eq(TS.HasTicket(P, "LindenmoorFoundry"), Before)
	end,
	UseTicketOfAClass = function(T)
		local TS = require(SSS.TravelService)
		local P = game.Players:GetPlayers()[1]
		T.Eq(TS.UseTicket(P, "CityIshval", "Cabin"), nil, "no such ticket held")
		TS.AddTicket(P, "CityIshval", "Third")
		TS.AddTicket(P, "CityIshval", "Cabin")
		T.Eq(TS.UseTicket(P, "CityIshval", "Third"), "Third")
		T.Eq(TS.HasTicket(P, "CityIshval"), "Cabin")
		T.Eq(TS.UseTicket(P, "CityIshval"), "Cabin", "no class = the best held")
		T.Eq(TS.HasTicket(P, "CityIshval"), nil)
	end,
}

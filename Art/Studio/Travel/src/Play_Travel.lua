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
}

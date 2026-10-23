-- R2 acceptance (spec §16) in the game VM, on a test-only deed injected into the Deeds table. Run inside the
-- snapshot / restore runner (Conventions §S).
local RumourService = require(game.ServerScriptService.RumourService)
local MoralityService = require(game.ServerScriptService.MoralityService)
local PS = require(game.ServerScriptService.ProgressionService)
local Deeds = require(game.ReplicatedStorage.Modules.Data.Rensei.Deeds)
local Player = game.Players:GetPlayers()[1]
return {
	R2 = function(T)
		Deeds.__test_rumour = {Text = "Test: a deed for rumours", Standing = {Authority = 12, Townsfolk = -6}, Scope = "Local"}
		local Base = os.time()
		RumourService.SetClock(function() return Base end)
		local Ok, Err = pcall(function()
			T.True(MoralityService.Record(Player, "__test_rumour", true, {Region = "Foundry", Strength = 2}))
			task.wait(0.2) -- the Recorded listener spawns the rumour
			local M = PS.GetData(Player).Morality
			local Live
			for _, R in ipairs(M.Rumours) do if R.Deed == "__test_rumour" then Live = R end end
			T.True(Live ~= nil, "a rumour started")
			local Before = M.Standing.Authority or 0
			RumourService.SetClock(function() return Base + 121 end)
			T.Eq(RumourService.Tick(Player), 1, "dispatch reached the City")
			-- World plan 1 Task 10: the Authority is now in 3 regions (City, Aerugo, North): heard in one, a third of 12
			T.Near((M.Standing.Authority or 0) - Before, 4, 1e-6, "Authority: the City is 1 of its 3 regions -> a third")
			-- Task 10: the train carries word to Lindenmoor and the City at 3 min; the 10 min gossip finds no one new
			RumourService.SetClock(function() return Base + 601 end)
			T.Eq(RumourService.Tick(Player), 2, "the train reached Lindenmoor and the City")
			RumourService.SetClock(function() return Base + 601 end)
			T.Eq(RumourService.Tick(Player), 0, "idempotent")
		end)
		RumourService.SetClock(nil)
		Deeds.__test_rumour = nil
		if not Ok then error(Err, 0) end
	end,
	ReportNeedsAWitness = function(T)
		local Ok, Why = RumourService.Report(Player, Player, "reported_lise", "City", "Authority")
		T.True(not Ok, "no recorded witness")
		T.True(Why ~= nil)
	end,
}

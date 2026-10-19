-- Run inside the game VM (a runtime Script in Play): returns a TestKit suite. Snapshot / restore around it.
local MoralityService = require(game.ServerScriptService.MoralityService)
local ProgressionService = require(game.ServerScriptService.ProgressionService)
local Deeds = require(game.ReplicatedStorage.Modules.Data.Rensei.Deeds)
local Player = game.Players:GetPlayers()[1]
return {
	JoinSeededAndBorn = function(T)
		local Data = ProgressionService.GetData(Player)
		T.True(Data.Morality.Seeded == true, "seeded on join")
		local Origin = Data.Identity and Data.Identity.Origin
		if Origin and Origin ~= "" then T.True(Data.Morality.Deeds["born_" .. Origin] ~= nil, "birth deed recorded") end
	end,
	LocalDeedLandsWhereItHappened = function(T)
		Deeds.__test_local = {Text = "Test: local deed", Standing = {Foundry = -6, Authority = 12}, Scope = "Local"}
		local Got
		table.insert(MoralityService.Recorded, function(_, Id, _, Info) if Id == "__test_local" then Got = Info end end)
		T.True(MoralityService.Record(Player, "__test_local", true, {Region = "Foundry"}))
		local M = ProgressionService.GetData(Player).Morality
		T.True(M.Places.Foundry.Known.__test_local.Foundry ~= nil, "heard in the Foundry")
		T.True(M.Places.City == nil or M.Places.City.Known.__test_local == nil, "not yet in the City")
		task.wait()
		T.Eq(Got and Got.Region, "Foundry"); T.Eq(Got and Got.Strength, 2, "Local default strength")
		Deeds.__test_local = nil
	end,
	PrivateDeedLandsNowhere = function(T)
		Deeds.__test_private = {Text = "Test: private", Standing = {Circle = 9}, Scope = "Private"}
		MoralityService.Record(Player, "__test_private", true, {Region = "City"})
		local M = ProgressionService.GetData(Player).Morality
		T.True(not (M.Places.City and M.Places.City.Known.__test_private), "unheard")
		Deeds.__test_private = nil
	end,
}

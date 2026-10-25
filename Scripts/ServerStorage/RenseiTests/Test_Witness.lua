-- server modules live in ServerStorage.RenseiServer in Edit mode (World Plan 1 Task 3); ServerScriptService at runtime
local W = require(game.ServerScriptService:FindFirstChild("WitnessService") or game.ServerStorage.RenseiServer.WitnessService)
return {
	StrengthCountsWitnessesAndEvidence = function(T)
		T.Eq(W.Strength({}, 0), 0, "a ghost")
		T.Eq(W.Strength({{Carrier = false, Faction = "Townsfolk"}, {Carrier = false, Faction = "Foundry"}}), 2, "two townsfolk")
		T.Eq(W.Strength({{Carrier = true, Faction = "Authority"}}, 1), 5, "an agent and one evidence")
	end,
	-- Plan 2 (owner default, 2026-10-20): hostile NPCs (no faction) notice you but don't talk to anyone
	HostilesAddNoStrength = function(T)
		T.Eq(W.Strength({{Carrier = false}, {Carrier = false, Faction = "Townsfolk"}}), 1, "a bandit and a townsperson")
	end,
	ReportsNeedARecordedWitness = function(T)
		W.Note(1, 2, "d", 1000)
		T.True(W.CanReport(1, 2, "d", 1000 + 60))
		T.True(not W.CanReport(3, 2, "d", 1060), "someone who didn't see it")
		T.True(not W.CanReport(1, 2, "other", 1060), "another deed")
		T.True(not W.CanReport(1, 2, "d", 1000 + W.ReportWindow + 1), "too late")
		W.Forget(1, 2, "d")
		T.True(not W.CanReport(1, 2, "d", 1060), "reported once")
	end,
}

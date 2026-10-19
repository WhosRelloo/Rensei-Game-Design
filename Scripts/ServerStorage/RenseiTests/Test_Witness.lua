local W = require(game.ServerScriptService.WitnessService)
return {
	StrengthCountsWitnessesAndEvidence = function(T)
		T.Eq(W.Strength({}, 0), 0, "a ghost")
		T.Eq(W.Strength({{Carrier = false}, {Carrier = false}}), 2, "two townsfolk")
		T.Eq(W.Strength({{Carrier = true}}, 1), 5, "an agent and one evidence")
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

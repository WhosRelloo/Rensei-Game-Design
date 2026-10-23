local L = require(game.ReplicatedStorage.Modules.Data.Rensei.TownsfolkLogic)
local S = { {6, 14, "work"}, {14, 15, "canteen"}, {15, 6, "home"} }
return {
	PostAtWraps = function(T)
		T.Eq(L.PostAt(S, 6), "work") T.Eq(L.PostAt(S, 13.99), "work")
		T.Eq(L.PostAt(S, 14.5), "canteen") T.Eq(L.PostAt(S, 23), "home") T.Eq(L.PostAt(S, 2), "home")
	end,
	GreetingByTier = function(T)
		T.True(#L.Greeting("Hostile", {}) > 0 and L.Greeting("Hostile", {}) ~= L.Greeting("Honoured", {}))
		T.Eq(L.Greeting("Neutral", {Greetings = {Neutral = "Hm."}}), "Hm.")
		T.Eq(L.Greeting("Nonsense", {}), L.Greeting("Neutral", {}))
	end,
	ValidateCatchesGaps = function(T)
		local Posts = {work = true, canteen = true, home = true}
		local Ok, Errs = L.Validate({ {Id = "a", Name = "A", Faction = "Foundry", Schedule = { {6, 14, "work"} }} }, {work = true})
		T.Eq(Ok, false) T.True(#Errs >= 1, "hours not covered")
		Ok = L.Validate({ {Id = "a", Name = "A", Faction = "Foundry", Schedule = S} }, Posts)
		T.Eq(Ok, true)
		Ok = L.Validate({ {Id = "a", Name = "A", Faction = "Foundry", Schedule = S} }, {work = true})
		T.Eq(Ok, false, "missing posts")
		-- a gap that only starts mid-hour (14 to 14.5) is still a gap
		Ok = L.Validate({ {Id = "a", Name = "A", Faction = "Foundry", Schedule = { {6, 14, "work"}, {14.5, 6, "home"} }} }, Posts)
		T.Eq(Ok, false, "half-hour gap")
		Ok = L.Validate({ {Id = "a", Name = "A", Faction = "Foundry", Schedule = S}, {Id = "a", Name = "B", Faction = "Foundry", Schedule = S} }, Posts)
		T.Eq(Ok, false, "duplicate id")
		Ok = L.Validate({ {Id = "a", Name = "A", Faction = "NoSuchFaction", Schedule = S} }, Posts)
		T.Eq(Ok, false, "unknown faction")
		Ok = L.Validate({ {Id = "a", Name = "A", Faction = "Foundry"} }, Posts)
		T.Eq(Ok, false, "no schedule")
	end,
}

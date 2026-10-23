local L = require(game.ReplicatedStorage.Modules.Data.Rensei.TownsfolkLogic)
local S = { {6, 14, "work"}, {14, 15, "canteen"}, {15, 6, "home"} }
local Look = {Nation = "Amestrian", Seed = 1}
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
		local Ok, Errs = L.Validate({ {Id = "a", Name = "A", Faction = "Foundry", Look = Look, Schedule = { {6, 14, "work"} }} }, {work = true})
		T.Eq(Ok, false) T.True(#Errs >= 1, "hours not covered")
		Ok = L.Validate({ {Id = "a", Name = "A", Faction = "Foundry", Look = Look, Schedule = S} }, Posts)
		T.Eq(Ok, true)
		Ok = L.Validate({ {Id = "a", Name = "A", Faction = "Foundry", Look = Look, Schedule = S} }, {work = true})
		T.Eq(Ok, false, "missing posts")
		-- a gap that only starts mid-hour (14 to 14.5) is still a gap
		Ok = L.Validate({ {Id = "a", Name = "A", Faction = "Foundry", Look = Look, Schedule = { {6, 14, "work"}, {14.5, 6, "home"} }} }, Posts)
		T.Eq(Ok, false, "half-hour gap")
		Ok = L.Validate({ {Id = "a", Name = "A", Faction = "Foundry", Look = Look, Schedule = S}, {Id = "a", Name = "B", Faction = "Foundry", Look = Look, Schedule = S} }, Posts)
		T.Eq(Ok, false, "duplicate id")
		Ok = L.Validate({ {Id = "a", Name = "A", Faction = "NoSuchFaction", Look = Look, Schedule = S} }, Posts)
		T.Eq(Ok, false, "unknown faction")
		Ok = L.Validate({ {Id = "a", Name = "A", Faction = "Foundry", Look = Look} }, Posts)
		T.Eq(Ok, false, "no schedule")
		-- a roster entry that isn't a table is reported, not thrown on (LoadRegion runs at Start, unguarded)
		local Ok2, Errs2 = L.Validate({ {Id = "a", Name = "A", Faction = "Foundry", Look = Look, Schedule = S}, 5 }, Posts)
		T.Eq(Ok2, false, "non-table entry") T.True(#Errs2 == 1, "only the bad entry is reported")
		-- townsfolk wear their own nation's clothes: a missing or unknown nation is refused (owner 2026-10-23)
		T.Eq(L.Validate({ {Id = "a", Name = "A", Faction = "Foundry", Look = {Nation = "Atlantis"}, Schedule = S} }, Posts), false, "unknown nation")
		T.Eq(L.Validate({ {Id = "a", Name = "A", Faction = "Foundry", Schedule = S} }, Posts), false, "no look")
		T.Eq(L.Validate({ {Id = "a", Name = "A", Faction = "Foundry", Look = {Nation = "Amestrian", Gender = "Other"}, Schedule = S} }, Posts), false, "unknown gender")
		T.Eq(L.Validate({ {Id = "a", Name = "A", Faction = "Foundry", Look = {Nation = "Amestrian", Gender = "Female"}, Schedule = S} }, Posts), true, "a known gender")
	end,
}

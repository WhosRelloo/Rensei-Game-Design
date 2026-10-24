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
	-- Task 5b: two townsfolk can't stand at the same post at the same hour (they'd walk into each other there)
	ValidateRejectsSharedPosts = function(T)
		local Posts = {work = true, canteen = true, home = true, shed = true}
		local function Folk(Id, Schedule) return {Id = Id, Name = Id, Faction = "Foundry", Look = Look, Schedule = Schedule} end
		local Ok, Errs = L.Validate({Folk("a", S), Folk("b", { {10, 18, "work"}, {18, 10, "shed"} })}, Posts)
		T.Eq(Ok, false, "a and b share work from 10 to 14")
		T.Eq(#Errs, 1, "reported once")
		T.True(string.find(Errs[1], "work", 1, true) ~= nil and string.find(Errs[1], "a", 1, true) ~= nil, "names the post and the other townsperson: " .. Errs[1])
		-- back to back is fine (slots are half-open): a leaves work at 14 as b arrives
		T.Eq(L.Validate({Folk("a", S), Folk("b", { {14, 20, "work"}, {20, 14, "shed"} })}, Posts), true, "back to back")
		-- across midnight: a is home 15-6, b is home 4-8
		T.Eq(L.Validate({Folk("a", S), Folk("b", { {4, 8, "home"}, {8, 4, "shed"} })}, Posts), false, "overlap across midnight")
		-- a swap (each walks to the other's post) is fine
		T.Eq(L.Validate({Folk("a", { {0, 12, "work"}, {12, 24, "shed"} }), Folk("b", { {0, 12, "shed"}, {12, 24, "work"} })}, Posts), true, "a swap")
		-- one townsperson at the same post in two slots is fine
		T.Eq(L.Validate({Folk("a", { {0, 8, "home"}, {8, 12, "work"}, {12, 24, "home"} })}, Posts), true, "own post twice")
	end,
}

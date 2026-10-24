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
	-- Task 6 (Task 4 review): pinned edges. The first matching slot wins; hour 24 is midnight.
	Edges = function(T)
		T.Eq(L.PostAt(S, 14), "canteen", "14 is the canteen slot's first hour")
		T.Eq(L.PostAt(S, 15), "home", "15: the canteen slot has ended")
		T.Eq(L.PostAt(S, 24), "home", "24 reads as midnight")
		T.Eq(L.PostAt({ {0, 24, "a"}, {10, 12, "b"} }, 11), "a", "the first matching slot wins")
		local Posts = {work = true, home = true}
		local function V(Schedule) return L.Validate({ {Id = "a", Name = "A", Faction = "Foundry", Look = Look, Schedule = Schedule} }, Posts) end
		T.Eq(V({ {0, 24, "home"} }), true, "{0, 24} is all day")
		T.Eq(V({ {6, 24, "work"}, {0, 6, "home"} }), true, "{6, 24} + {0, 6}")
		local Ok, Errs = V({ {6, 6, "home"} })
		T.Eq(Ok, false, "{6, 6} is empty")
		T.True(string.find(table.concat(Errs, " | "), "use {0, 24", 1, true) ~= nil, "says how to write all day: " .. table.concat(Errs, " | "))
		-- malformed schedules fail without throwing
		for _, Bad in ipairs({"broken", { "x" }, { {"a", 3, "home"} }, { {0 / 0, 24, "home"} }, { {0, 0 / 0, "home"} }, {}}) do
			local Fine, Res = pcall(V, Bad)
			T.True(Fine, "doesn't throw: " .. tostring(Res))
			T.Eq(Res, false, "a malformed schedule fails")
		end
		-- one uncovered end point is reported once, however many slots end there
		local _, Gap = V({ {6, 10, "work"}, {8, 10, "home"}, {12, 6, "home"} })
		local N = 0
		for _, E in ipairs(Gap) do if string.find(E, "from hour 10", 1, true) then N += 1 end end
		T.Eq(N, 1, "the gap at 10 is reported once")
	end,
	-- Task 6: talk rotation. Greeting -> rumour -> job -> greeting; the rumour step is skipped with none to tell (or
	-- none new); the clue line wins while the player is on the clue's stage.
	TalkRotation = function(T)
		local Def = {Id = "t", JobLine = "I mind the forge.", Clue = {Quest = "q", Stage = 2, Text = "I saw a cart at night.", Signal = "s"}}
		local Rumours = L.Rumours({ {At = 2, Text = "Struck a townsperson", Subject = "Ann"}, {At = 1, Text = "Struck a townsperson", Subject = "Ann"} }, "Me",
			function(Who) return Who end)
		T.Eq(#Rumours, 1, "the same (subject, text) is one rumour")
		T.Eq(Rumours[1].Text, "They say Ann struck a townsperson.", "worded, first letter lowered")
		local St = {}
		local Ctx = {Tier = "Trusted", Rumours = Rumours}
		local K1, L1 = L.NextTalk(Def, St, Ctx)
		local K2, L2 = L.NextTalk(Def, St, Ctx)
		local K3, L3 = L.NextTalk(Def, St, Ctx)
		local K4 = L.NextTalk(Def, St, Ctx)
		T.Eq(K1 .. ">" .. K2 .. ">" .. K3 .. ">" .. K4, "Greeting>Rumour>Job>Greeting")
		T.Eq(L1, L.Greeting("Trusted", Def)) T.Eq(L2, Rumours[1].Text) T.Eq(L3, "I mind the forge.")
		T.Eq((L.NextTalk(Def, St, Ctx)), "Job", "the rumour was told: skipped the second time round")
		local Fresh = {}
		T.Eq((L.NextTalk(Def, Fresh, {Tier = "Neutral"})), "Greeting")
		T.Eq((L.NextTalk(Def, Fresh, {Tier = "Neutral"})), "Job", "no rumours: straight to the job line")
		local Kc, Lc = L.NextTalk(Def, Fresh, {Tier = "Neutral", Clue = true})
		T.Eq(Kc, "Clue") T.Eq(Lc, "I saw a cart at night.")
		T.Eq((L.NextTalk(Def, Fresh, {Tier = "Neutral"})), "Greeting", "the clue doesn't move the rotation")
	end,
	RumourWording = function(T)
		T.Eq(L.RumourLine("Subject 03", "Struck a townsperson", false), "They say Subject 03 struck a townsperson.")
		T.Eq(L.RumourLine("x", "Struck a townsperson.", true), "They say you struck a townsperson.", "the listener is the subject")
		T.Eq(L.RumourLine("someone", "Promised Tobin you'd keep quiet about his nap", false), "They say someone promised Tobin they'd keep quiet about his nap.")
		local R = L.Rumours({ {Text = "Kept Lise's secret", Subject = "Me"} }, "Me")
		T.Eq(R[1].Text, "They say you kept Lise's secret.")
		T.Eq(L.Rumours({ {Text = "Kept Lise's secret", Subject = "Bo"} }, "Me")[1].Text, "They say someone kept Lise's secret.", "no NameOf: someone")
		T.Near(L.SpeechSeconds(string.rep("a", 40)), 5, 1e-9)
		for Kind, List in pairs(L.Chatter) do
			T.True(#List > 0, Kind)
			T.True(table.find(List, L.Chat(Kind, Random.new(1))) ~= nil, Kind .. " picks one of its lines")
		end
		T.Eq(L.Chat("Nonsense"), nil)
	end,
}

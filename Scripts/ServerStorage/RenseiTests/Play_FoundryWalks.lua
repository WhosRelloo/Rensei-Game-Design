-- Play_FoundryWalks (Foundry Yard plan Task 4b, 2026-10-25): every schedule change of Foundry's roster walked live by
-- the real TownsfolkService and Mover, all 26 townsfolk together, in the game VM (LMRunSuite) in Foundry.
--   * Set-up: TownsfolkService.SleepRadius and PlaceRadius go to math.huge for the run (everyone walks wherever the
--     player is, and nothing is ever placed: a placement would be a teleport), the player is held still 400 studs over
--     the yard (out of every walker's way), the clock is held at the first hour any schedule changes and the roster is
--     loaded there (TownsfolkService.LoadRegion: everyone placed at their post), and Mover.ResetStats().
--   * The day: the clock steps to each hour a schedule changes, in order round to the first again; at each one
--     TownsfolkService.Step() sends everyone whose post changes walking, and the run waits until every one of those
--     walks has ended (HOUR_WAIT at most). Every root is sampled each steering tick (0.1 s).
--   * Each walk (its first Mover handle; a retry after a failure isn't judged) fails on: a result other than
--     "arrived", any Why, more than MAX_REPLANS re-plans, one tick's step over MAX_STEP studs (a teleport), or ending
--     more than END_OFF from where a rig stands at its post.
--   * Coverage: the walks cover every schedule change (RenseiTests.PathKit.Pairs: 70).
--   * Performance (Ruling 18's Foundry check): Mover.Stats().StepMs (the average steering tick) at most STEP_MS; the
--     99th percentile (Mover.P99StepMs) and the rest of Mover.Stats() are reported in ServerStorage's attribute
--     FoundryWalksStats and printed as "[FoundryWalks] ..." lines.
--   * Quick mode (owner request, Foundry Yard plan Task 9: "one full walk of every route, then repeats only for routes
--     that needed repairs or failed before"; made stricter: "only recheck routes that failed or needed a replan, not
--     routine corner repairs"): opt-in only, with ServerStorage's attribute WalksQuick = true; without it
--     the suite runs the whole day as above. Quick mode reads the risky list (RenseiTests.RiskyWalks: {Id, From, To}
--     routes) and steps only the hours those routes change at: for each, the clock is held half an hour before
--     (everyone placed by LoadRegion at the post that covers it: every listed route's From), then at the hour
--     (TownsfolkService.Step sends everyone due walking, as in the full day). The same checks judge every walk made;
--     Coverage checks every listed route was walked (and is a schedule change) and reports the list's coverage. An
--     empty or missing list never passes: the run breaks with "no risky list".
--   * Every run (full or quick) writes the routes that failed or needed a replan (a corner repair alone doesn't count),
--     as RiskyWalks.lua lines, to
--     ServerStorage's attribute FoundryWalksRisky and prints them ("[FoundryWalks] risky: ..."): the list is updated by
--     copying those into Scripts/ServerStorage/RenseiTests/RiskyWalks.lua after a full run.
-- Everything is put back afterwards: the two radii, the clock, the player.
local SSS = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Rensei = game.ReplicatedStorage.Modules.Data.Rensei
local PathKit = require(script.Parent.PathKit)

local PAIRS = 70 -- Foundry's schedule changes (Test_FoundryPaths)
local MAX_REPLANS = 3 -- (the brief)
local MAX_STEP = 4 -- studs in one 0.1 s tick (the brief: more is a teleport)
local END_OFF = 0.5 -- (the brief)
local STEP_MS = 1.5 -- (Ruling 18) the average steering tick
local HOUR_WAIT = 240 -- s, PROPOSAL: the longest walk is about 1,100 studs at 8 studs a second
local START_WAIT = 3 -- s for a walk to start after Step

local TESTS = {"AllArrive", "Coverage", "OnTheirPosts", "Performance", "Replans", "Steps"}

local function Stand(Post) return (Post.CFrame * CFrame.new(0, 3, 0)).Position end

-- (quick mode) the switches a run-once control sets: Opt.Quick (quick mode without the attribute), Opt.List (a list
-- in place of RiskyWalks.Routes)
local Opt = {}
-- the hour Id's schedule moves it From -> To, or nil (not one of its schedule changes)
local function SwitchHour(Roster, Id, From, To)
	for _, D in ipairs(Roster) do
		if D.Id == Id then
			local S = D.Schedule
			for I = 1, #S do
				local Nx = S[I % #S + 1]
				if S[I][3] == From and Nx[3] == To then return Nx[1] end
			end
		end
	end
	return nil
end

local function RunDay()
	local TS = require(SSS.TownsfolkService)
	local Mover = require(SSS.TownsfolkService.Mover)
	local WorldClock = require(SSS.WorldClock)
	local TownsfolkLogic = require(Rensei.TownsfolkLogic)
	local Roster = require(Rensei.Townsfolk).Regions.Foundry
	local R = {Walks = {}, Problems = {}, Hours = {}}
	local Player = game.Players:GetPlayers()[1]
	local Char = Player and Player.Character
	local Root = Char and Char:FindFirstChild("HumanoidRootPart")
	assert(Root, "a player with a character")
	local Saved = {Sleep = TS.SleepRadius, Place = TS.PlaceRadius, Held = WorldClock.IsHeld(), Hour = WorldClock.Now(),
		Pivot = Char:GetPivot(), Anchored = Root.Anchored}
	local Conn
	local Ok, Err = pcall(function()
		TS.SleepRadius, TS.PlaceRadius = math.huge, math.huge
		Root.Anchored = true
		Char:PivotTo(CFrame.new(Saved.Pivot.Position.X, 400, Saved.Pivot.Position.Z))
		local Posts = TS.Posts
		-- one hour's walks: the clock to H, Step, wait until every walk started there has ended
		local function StepHour(H)
			WorldClock.Hold(H)
			-- who changes post now: {Id, From, To, Rig}
			local Movers = {}
			for _, D in ipairs(Roster) do
				local Rig = TS.Get(D.Id)
				local From = Rig and Rig:GetAttribute("PostId")
				local To = TownsfolkLogic.PostAt(D.Schedule, H)
				if Rig and From ~= To then
					table.insert(Movers, {Id = D.Id, From = From, To = To, Rig = Rig, Root = Rig.HumanoidRootPart, Last = Rig.HumanoidRootPart.Position, MaxStep = 0})
				end
			end
			-- sample every root each steering tick
			local Acc = 0
			Conn = RunService.Heartbeat:Connect(function(Dt)
				Acc += Dt
				if Acc < 0.1 then return end
				Acc = 0
				for _, M in ipairs(Movers) do
					if M.Root.Parent then
						local P = M.Root.Position
						local Step = (P - M.Last).Magnitude
						if Step > M.MaxStep then M.MaxStep = Step end
						M.Last = P
						if not M.H then
							local Hd = Mover.Handle(M.Rig)
							if Hd then M.H = Hd end
						end
					end
				end
			end)
			TS.Step(H)
			local T0 = os.clock()
			while os.clock() - T0 < HOUR_WAIT do
				task.wait(0.25)
				local Busy = false
				for _, M in ipairs(Movers) do
					if not M.H then
						M.H = Mover.Handle(M.Rig)
						if not M.H and os.clock() - T0 > START_WAIT then M.NoWalk = true end
					end
					if not M.NoWalk and (not M.H or M.H.Status == "walking") then Busy = true end
				end
				if not Busy then break end
			end
			task.wait(0.5) -- (the arrival settles the rig on its post)
			Conn:Disconnect()
			Conn = nil
			table.insert(R.Hours, ("%02d:00 %d walks, %.0f s"):format(H, #Movers, os.clock() - T0))
			for _, M in ipairs(Movers) do
				local Hd = M.H
				local W = {Id = M.Id, From = M.From, To = M.To, MaxStep = M.MaxStep,
					Result = M.NoWalk and "no walk" or (Hd and Hd.Status or "?"), Why = Hd and Hd.Why,
					Replans = Hd and Hd.Replans or 0, Repaired = Hd and Hd.Repaired or 0}
				local Post = Posts[M.To]
				W.Off = Post and M.Root.Parent and (M.Root.Position - Stand(Post)).Magnitude or math.huge
				table.insert(R.Walks, W)
			end
		end
		R.Quick = Opt.Quick == true or game.ServerStorage:GetAttribute("WalksQuick") == true
		if not R.Quick then
			-- the hours any schedule changes, in order
			local Hours, Seen = {}, {}
			for _, D in ipairs(Roster) do
				for _, E in ipairs(D.Schedule) do
					if not Seen[E[1]] then Seen[E[1]] = true table.insert(Hours, E[1]) end
				end
			end
			table.sort(Hours)
			table.insert(Hours, Hours[1]) -- (round to the first hour again: the night's last change)
			WorldClock.Hold(Hours[1])
			assert(TS.LoadRegion("Foundry", Roster), "LoadRegion accepted Foundry's roster")
			task.wait(1)
			Mover.ResetStats()
			for I = 2, #Hours do StepHour(Hours[I]) end
		else
			-- (quick mode) only the hours the risky routes change at, each from half an hour before
			local Ok0, List = pcall(function() return Opt.List or require(script.Parent.RiskyWalks).Routes end)
			if not Ok0 or type(List) ~= "table" or #List == 0 then error("no risky list", 0) end
			R.List, R.Unknown = List, {}
			local Need, Hours = {}, {}
			for _, E in ipairs(List) do
				local H = SwitchHour(Roster, E[1], E[2], E[3])
				if H == nil then
					table.insert(R.Unknown, ("%s %s>%s"):format(tostring(E[1]), tostring(E[2]), tostring(E[3])))
				elseif not Need[H] then
					Need[H] = true
					table.insert(Hours, H)
				end
			end
			table.sort(Hours)
			R.QuickHours = Hours
			Mover.ResetStats()
			for _, H in ipairs(Hours) do
				WorldClock.Hold((H - 0.5) % 24)
				assert(TS.LoadRegion("Foundry", Roster), "LoadRegion accepted Foundry's roster")
				task.wait(1)
				StepHour(H)
			end
		end
		local S = Mover.Stats()
		S.P99StepMs = Mover.P99StepMs()
		S.WalkFailures = TS.WalkFailures -- (nil before Task 4b)
		R.Stats = S
	end)
	if Conn then Conn:Disconnect() end
	-- everything back
	pcall(function() TS.SleepRadius, TS.PlaceRadius = Saved.Sleep, Saved.Place end)
	pcall(function() if Saved.Held then WorldClock.Hold(Saved.Hour) else WorldClock.Release() end end)
	pcall(function()
		Char:PivotTo(Saved.Pivot)
		Root.AssemblyLinearVelocity = Vector3.zero
		Root.Anchored = Saved.Anchored
	end)
	if not Ok then R.Error = tostring(Err) end
	-- the report
	local Lines = {}
	for _, W in ipairs(R.Walks) do
		table.insert(Lines, ("%s %s>%s %s why=%s replans %d repaired %d maxstep %.2f off %.2f"):format(W.Id, tostring(W.From),
			tostring(W.To), W.Result, tostring(W.Why), W.Replans, W.Repaired, W.MaxStep, W.Off))
	end
	local Report = {Hours = R.Hours, Stats = R.Stats, Error = R.Error, Walks = Lines, Quick = R.Quick}
	pcall(function() game.ServerStorage:SetAttribute("FoundryWalksStats", HttpService:JSONEncode(Report)) end)
	-- the routes that failed or needed a replan, as RiskyWalks.lua lines (the list is updated from a full run); a
	-- corner repair alone is routine and doesn't put a route on the list (owner, 2026-10-25)
	local Risky = {}
	for _, W in ipairs(R.Walks) do
		local Failed = W.Result ~= "arrived" or W.Why ~= nil or W.Replans > MAX_REPLANS or W.MaxStep > MAX_STEP or W.Off > END_OFF
		if Failed or W.Replans > 0 then
			table.insert(Risky, ('{"%s", "%s", "%s"}, -- %s'):format(W.Id, tostring(W.From), tostring(W.To),
				Failed and ("failed: " .. W.Result .. " " .. tostring(W.Why)) or ("replans " .. W.Replans)))
		end
	end
	pcall(function() game.ServerStorage:SetAttribute("FoundryWalksRisky", table.concat(Risky, "\n")) end)
	print(("[FoundryWalks] risky: %d routes failed or needed a replan%s"):format(#Risky, R.Quick and " (quick run)" or ""))
	for _, L in ipairs(Risky) do print("[FoundryWalks] risky: " .. L) end
	if R.Stats then
		local Keys = {}
		for K, V in pairs(R.Stats) do if type(V) == "number" then table.insert(Keys, ("%s %.3f"):format(K, V)) end end
		table.sort(Keys)
		print("[FoundryWalks] Mover.Stats: " .. table.concat(Keys, ", "))
	end
	for _, L in ipairs(R.Hours) do print("[FoundryWalks] " .. L) end
	return R
end

local function Bad(R, Pred, Fmt)
	local Out = {}
	for _, W in ipairs(R.Walks) do
		if Pred(W) then table.insert(Out, Fmt(W)) end
	end
	return Out
end

local Checks = {
	AllArrive = function(T, R)
		local Out = Bad(R, function(W) return W.Result ~= "arrived" or W.Why ~= nil end,
			function(W) return ("%s %s>%s %s (%s)"):format(W.Id, tostring(W.From), tostring(W.To), W.Result, tostring(W.Why)) end)
		T.Eq(#Out, 0, ("every walk arrives with no Why; not %d of %d: %s"):format(#Out, #R.Walks, table.concat(Out, " | ")))
	end,
	Coverage = function(T, R)
		if R.Quick then
			-- (quick mode) every listed route walked, and each one a schedule change
			T.Eq(#R.Unknown, 0, "listed routes that are no schedule change: " .. table.concat(R.Unknown, ", "))
			local Got = {}
			for _, W in ipairs(R.Walks) do Got[W.Id .. " " .. tostring(W.From) .. ">" .. tostring(W.To)] = true end
			local Missing, N = {}, 0
			for _, E in ipairs(R.List) do
				local K = ("%s %s>%s"):format(E[1], E[2], E[3])
				if Got[K] then N += 1 else table.insert(Missing, K) end
			end
			print(("[FoundryWalks] quick: %d of %d listed routes walked, at hours %s (%d walks in all)"):format(N, #R.List,
				table.concat(R.QuickHours, ","), #R.Walks))
			T.Eq(#Missing, 0, ("every listed route was walked (%d of %d); not: %s"):format(N, #R.List, table.concat(Missing, ", ")))
			return
		end
		local Want = PathKit.Pairs(require(Rensei.Townsfolk).Regions.Foundry)
		T.Eq(#Want, PAIRS, "Foundry's schedule changes")
		local Got = {}
		for _, W in ipairs(R.Walks) do Got[tostring(W.From) .. ">" .. tostring(W.To)] = true end
		local Missing = {}
		for _, P in ipairs(Want) do
			if not Got[P[2] .. ">" .. P[3]] then table.insert(Missing, P[1] .. " " .. P[2] .. ">" .. P[3]) end
		end
		T.Eq(#Missing, 0, "every schedule change was walked; not: " .. table.concat(Missing, ", "))
	end,
	OnTheirPosts = function(T, R)
		local Out = Bad(R, function(W) return W.Off > END_OFF end,
			function(W) return ("%s at %s: %.2f off"):format(W.Id, tostring(W.To), W.Off) end)
		T.Eq(#Out, 0, ("every walk ends within %.1f of its post; not: %s"):format(END_OFF, table.concat(Out, " | ")))
	end,
	Performance = function(T, R)
		T.True(R.Stats ~= nil, "Mover.Stats() was recorded")
		T.True(R.Stats.StepMs <= STEP_MS, ("the average steering tick %.3f ms (P99 %.3f ms) is at most %.1f ms (Ruling 18)")
			:format(R.Stats.StepMs, R.Stats.P99StepMs, STEP_MS))
	end,
	Replans = function(T, R)
		local Out = Bad(R, function(W) return W.Replans > MAX_REPLANS end,
			function(W) return ("%s %s>%s %d"):format(W.Id, tostring(W.From), tostring(W.To), W.Replans) end)
		T.Eq(#Out, 0, ("no walk re-plans more than %d times; not: %s"):format(MAX_REPLANS, table.concat(Out, " | ")))
	end,
	Steps = function(T, R)
		local Out = Bad(R, function(W) return W.MaxStep > MAX_STEP end,
			function(W) return ("%s %s>%s %.1f"):format(W.Id, tostring(W.From), tostring(W.To), W.MaxStep) end)
		T.Eq(#Out, 0, ("no tick's step over %d studs (a teleport); not: %s"):format(MAX_STEP, table.concat(Out, " | ")))
	end,
}

-- TestKit runs tests sorted by name: the first walks the whole day once, each test reads its share, the last forgets it
local Suite = {}
local Cache = nil
for _, Name in ipairs(TESTS) do
	Suite[Name] = function(T)
		if Name == TESTS[1] then Cache = RunDay() end
		local R = Cache
		if Name == TESTS[#TESTS] then Cache = nil end
		if not R then error("the day didn't run (run the suite through TestKit)", 0) end
		if R.Error then error("the run broke: " .. R.Error, 0) end
		Checks[Name](T, R)
	end
end
-- (quick mode's switches for the run-once controls; not a test: TestKit runs only the suite's own keys)
return setmetatable(Suite, {__index = {Opt = Opt, SwitchHour = SwitchHour}})

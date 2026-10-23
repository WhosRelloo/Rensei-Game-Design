-- Play_Arrive (World plan 1 Task 10): arriving somewhere signals quests ({Kind = "Arrive", Target = <region id>}),
-- and a ticket can only be bought for a loaded member of your party. Run in a Play server, through LMRunSuite.
-- Every test puts back what it changed (monkeypatches, test quests) even when a step throws, then rethrows.
local SSS = game.ServerScriptService

-- the quest signal is spawned after Arrived (fix 1): wait for it briefly
local function WaitFor(Fn, Seconds)
	local T0 = os.clock()
	while not Fn() and os.clock() - T0 < (Seconds or 2) do task.wait(0.05) end
	return Fn()
end

-- injects test quests, runs Body, then removes them and puts the tracked quest back
local function WithQuests(Defs, Body)
	local QS = require(SSS.QuestService)
	local P = game.Players:GetPlayers()[1]
	local D = require(SSS.ProgressionService).GetData(P)
	local OldTracked = D.Quests.Tracked
	for Id, Def in pairs(Defs) do QS.Definitions[Id] = Def end
	local Ok, Err = pcall(Body, QS, P, D)
	for Id in pairs(Defs) do
		D.Quests.Active[Id] = nil
		D.Quests.Completed[Id] = nil
		QS.Definitions[Id] = nil
	end
	D.Quests.Tracked = OldTracked
	if not Ok then error(Err, 0) end
end

return {
	ArriveSignalsQuests = function(T)
		local QS = require(game.ServerScriptService.QuestService)
		local Seen
		local Count = 0
		local Old = QS.Signal
		QS.Signal = function(P, Kind, Target, N) if Kind == "Arrive" then Seen = Target Count += 1 end return Old(P, Kind, Target, N) end
		local Ok, Err = pcall(function()
			require(game.ServerScriptService.TravelService).Arrive(game.Players:GetPlayers()[1], {Route = "RoadLindenmoorFoundry", Arrive = "Platform"})
			WaitFor(function() return Seen ~= nil end)
			task.wait(0.2) -- a second signal would have come by now
		end)
		QS.Signal = Old
		if not Ok then error(Err, 0) end
		T.Eq(Seen, require(game.ServerScriptService.TravelService).Here())
		T.Eq(Count, 1, "signalled once per arrival")
	end,
	-- ruling (fix 1): an Arrive objective counts as done when the quest starts in that region (QuestService AlreadyTrue)
	ArriveObjectiveDoneWhenStartedHere = function(T)
		local Here = require(SSS.TravelService).Here()
		local Started, Done
		WithQuests({
			__test_arrive_now = {Title = "Test arrival, already here", Description = "test",
				Objectives = {{Id = "arrive", Text = "Arrive", Kind = "Arrive", Target = Here}}},
		}, function(QS, P, D)
			Started = QS.Start(P, "__test_arrive_now")
			Done = D.Quests.Completed.__test_arrive_now ~= nil
		end)
		T.True(Started, "started")
		T.True(Done, "already in " .. Here .. ": done at once")
	end,
	-- QuestService.Signal matches Kind and Target generically: arriving completes a quest for here that was accepted
	-- somewhere else, and a quest for another region doesn't move
	ArrivingCompletesAQuestTakenElsewhere = function(T)
		local TS = require(SSS.TravelService)
		local Here = TS.Here()
		local Elsewhere = Here == "Foundry" and "City" or "Foundry"
		local Started, BeforeArrive, Done, OtherProgress
		WithQuests({
			__test_arrive_here = {Title = "Test arrival here", Description = "test",
				Objectives = {{Id = "arrive", Text = "Arrive", Kind = "Arrive", Target = Here}}},
			__test_arrive_elsewhere = {Title = "Test arrival elsewhere", Description = "test",
				Objectives = {{Id = "arrive", Text = "Arrive", Kind = "Arrive", Target = Elsewhere}}},
		}, function(QS, P, D)
			-- accepted "elsewhere": Here() reports another region while the quest starts
			local OldHere = TS.Here
			local Ok, Err = pcall(function()
				TS.Here = function() return Elsewhere == "City" and "Foundry" or "City" end
				Started = QS.Start(P, "__test_arrive_here")
			end)
			TS.Here = OldHere
			if not Ok then error(Err, 0) end
			Started = Started and QS.Start(P, "__test_arrive_elsewhere")
			BeforeArrive = D.Quests.Active.__test_arrive_here ~= nil
			TS.Arrive(P, {Route = "RoadLindenmoorFoundry", Arrive = "Platform"})
			Done = WaitFor(function() return D.Quests.Completed.__test_arrive_here ~= nil end)
			local Other = D.Quests.Active.__test_arrive_elsewhere
			OtherProgress = Other and Other.Progress.arrive
		end)
		T.True(Started, "test quests started")
		T.True(BeforeArrive, "not done before arriving")
		T.True(Done, "arriving in " .. Here .. " completed it")
		T.Eq(OtherProgress, 0, "the quest for " .. Elsewhere .. " didn't move")
	end,
	-- parties (Step 6): the ticket window offers party members; the server refuses anyone else
	TicketForSomeoneOutsideThePartyIsRefused = function(T)
		local SS = require(SSS.StationService)
		local P = game.Players:GetPlayers()[1]
		local Money = require(SSS.ProgressionService).GetData(P).Money
		local Ok, Why = SS.Buy(P, "LindenmoorFoundry", "Third", P.UserId + 1)
		T.Eq(Ok, false)
		T.Eq(Why, "They aren't in your party.")
		T.Eq(require(SSS.ProgressionService).GetData(P).Money, Money, "nothing charged")
	end,
	-- fix 1: a party member whose save isn't loaded can't be sold a ticket, and nobody pays (a stand-in member with no
	-- profile: PartyService.Get is wrapped); and if issuing the ticket fails after paying, the money comes back
	NoChargeWithoutTheRidersSave = function(T)
		local SS = require(SSS.StationService)
		local PartyService = require(SSS.PartyService)
		local TS = require(SSS.TravelService)
		local PS = require(SSS.ProgressionService)
		local P = game.Players:GetPlayers()[1]
		local D = PS.GetData(P)
		local OldMoney = D.Money
		local Standin = {UserId = P.UserId + 7, Name = "Standin", DisplayName = "Standin"}
		local OldGet, OldAdd = PartyService.Get, TS.AddTicket
		local R = {}
		local Ok, Err = pcall(function()
			D.Money = 1000
			PartyService.Get = function(Q) if Q == P then return {Leader = P, Members = {P, Standin}} end return OldGet(Q) end
			R.Ok1, R.Why1 = SS.Buy(P, "LindenmoorFoundry", "Third", Standin.UserId)
			R.Money1 = D.Money
			PartyService.Get = OldGet
			TS.AddTicket = function() return false end -- the save went away between the check and the ticket
			R.Held = TS.HasTicket(P, "LindenmoorFoundry")
			R.Ok2, R.Why2 = SS.Buy(P, "LindenmoorFoundry", "Third")
			R.Money2 = D.Money
			R.Held2 = TS.HasTicket(P, "LindenmoorFoundry")
		end)
		PartyService.Get, TS.AddTicket = OldGet, OldAdd
		D.Money = OldMoney
		if not Ok then error(Err, 0) end
		T.Eq(R.Ok1, false, "no ticket for a member without a loaded save")
		T.Eq(R.Why1, "The clerk can't issue their ticket right now.", "refused for the missing save, not earlier")
		T.Eq(R.Money1, 1000, "and nothing charged")
		T.Eq(R.Ok2, false, "issuing failed")
		T.Eq(R.Why2, "The clerk can't issue that ticket right now.", "refused after paying: the refund path")
		T.Eq(R.Money2, 1000, "refunded")
		T.Eq(R.Held2, R.Held, "no ticket appeared")
	end,
}

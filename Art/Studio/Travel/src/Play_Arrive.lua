-- Play_Arrive (World plan 1 Task 10): arriving somewhere signals quests ({Kind = "Arrive", Target = <region id>}),
-- and a ticket can only be bought for a member of your party. Run in a Play server, through LMRunSuite.
local SSS = game.ServerScriptService
return {
	ArriveSignalsQuests = function(T)
		local QS = require(game.ServerScriptService.QuestService)
		local Seen
		local Old = QS.Signal
		QS.Signal = function(P, Kind, Target, N) if Kind == "Arrive" then Seen = Target end return Old(P, Kind, Target, N) end
		require(game.ServerScriptService.TravelService).Arrive(game.Players:GetPlayers()[1], {Route = "RoadLindenmoorFoundry", Arrive = "Platform"})
		QS.Signal = Old
		T.Eq(Seen, require(game.ServerScriptService.TravelService).Here())
	end,
	-- QuestService.Signal matches Kind and Target generically: an Arrive objective for here completes on arrival,
	-- one for another region doesn't move
	ArriveObjectiveAdvancesAQuest = function(T)
		local QS = require(SSS.QuestService)
		local TS = require(SSS.TravelService)
		local P = game.Players:GetPlayers()[1]
		local D = require(SSS.ProgressionService).GetData(P)
		local Here = TS.Here()
		local Elsewhere = Here == "Foundry" and "City" or "Foundry"
		local OldTracked = D.Quests.Tracked
		local Ids = {"__test_arrive_here", "__test_arrive_elsewhere"}
		QS.Definitions[Ids[1]] = {Title = "Test arrival here", Description = "test",
			Objectives = {{Id = "arrive", Text = "Arrive", Kind = "Arrive", Target = Here}}}
		QS.Definitions[Ids[2]] = {Title = "Test arrival elsewhere", Description = "test",
			Objectives = {{Id = "arrive", Text = "Arrive", Kind = "Arrive", Target = Elsewhere}}}
		local Started = QS.Start(P, Ids[1]) and QS.Start(P, Ids[2])
		TS.Arrive(P, {Route = "RoadLindenmoorFoundry", Arrive = "Platform"})
		local HereDone = D.Quests.Completed[Ids[1]] ~= nil and D.Quests.Active[Ids[1]] == nil
		local Other = D.Quests.Active[Ids[2]]
		local OtherProgress = Other and Other.Progress.arrive
		for _, Id in ipairs(Ids) do
			D.Quests.Active[Id] = nil
			D.Quests.Completed[Id] = nil
			QS.Definitions[Id] = nil
		end
		D.Quests.Tracked = OldTracked
		T.True(Started, "both test quests started")
		T.True(HereDone, "arriving here completed the quest for " .. Here)
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
}

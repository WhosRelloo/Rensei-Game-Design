-- Test_QuestRevision (Foundry data plan Task 2, 2026-10-24): StoryLogic.UpgradeQuest, the pure rule by which a saved
-- quest state follows a revised quest (Revision = n, Prepended = {[r] = k}). No services; run in the Play VM
-- (LMRunSuite), as StoryLogic changes in this task. Fix round 1 (Ruling 22) adds: the clamp to the last stage and
-- non-number Prepended values (Minor 4); a state without a Stage, a second UpgradeAll and an untouched Completed
-- (Minor 6, through QuestService.UpgradeAll with injected defs); stale-revision states as "not yet known" to stage
-- gates (I1, StoryLogic.Stale / Meets). Task 3 adds AcqMetalOldSaveMoves (the real acq_metal at revision 2).
local StoryLogic = require(game.ReplicatedStorage.Modules.Data.Rensei.StoryLogic)

local function Copy(T)
	if type(T) ~= "table" then return T end
	local R = {}
	for K, V in pairs(T) do R[K] = Copy(V) end
	return R
end

-- runs Body(QuestService) with two revised test quests (__fy_tq, __fy_tq_done) injected, and removes them after
local function WithRevisedDefs(Body)
	local QuestService = require(game.ServerScriptService.QuestService)
	local Defs = QuestService.Definitions
	local Ok, Err = pcall(function()
		for _, Id in ipairs({"__fy_tq", "__fy_tq_done"}) do
			Defs[Id] = {Title = "T", Revision = 2, Prepended = {[2] = 1}, Stages = {
				{Id = "s1", Text = "1", Objectives = {{Id = "a", Text = "a", Kind = "Signal", Target = "__fy_never_a"}}},
				{Id = "s2", Text = "2", Objectives = {{Id = "b", Text = "b", Kind = "Signal", Target = "__fy_never_b"}}},
			}}
		end
		Body(QuestService)
	end)
	Defs.__fy_tq, Defs.__fy_tq_done = nil, nil
	if not Ok then error(Err, 0) end
end

return {
	-- 1. one stage put in front at revision 2: a revision-1 save on stage 2 moves to stage 3
	OldSaveMovesPastPrepended = function(T)
		local Def, State = {Revision = 2, Prepended = {[2] = 1}}, {Stage = 2}
		T.Eq(StoryLogic.UpgradeQuest(Def, State), true, "changed")
		T.Eq(State.Stage, 3, "the stage it was on, now one later")
		T.Eq(State.Revision, 2, "recorded at the definition's revision")
	end,
	-- 2. the same state again: already at the revision, nothing moves
	UpgradedSaveStays = function(T)
		local Def, State = {Revision = 2, Prepended = {[2] = 1}}, {Stage = 2}
		StoryLogic.UpgradeQuest(Def, State)
		T.Eq(StoryLogic.UpgradeQuest(Def, State), false, "a second upgrade changes nothing")
		T.Eq(State.Stage, 3, "still stage 3")
	end,
	-- 3. a state started at the current revision is left alone
	CurrentRevisionUnchanged = function(T)
		local State = {Stage = 1, Revision = 2}
		T.Eq(StoryLogic.UpgradeQuest({Revision = 2, Prepended = {[2] = 1}}, State), false, "no change")
		T.Eq(State.Stage, 1, "stage 1 kept")
	end,
	-- 4. a definition without Revision never touches a state
	NoRevisionNoChange = function(T)
		local State = {Stage = 2, Progress = {o = 1}}
		local Before = Copy(State)
		T.Eq(StoryLogic.UpgradeQuest({Prepended = {[2] = 1}}, State), false, "no Revision: false")
		T.Same(State, Before, "the state is untouched")
	end,
	-- 5. several revisions: only the ones after the save's own count (revision 3 adds 2, revision 2 is already in)
	ShiftsAddUpFromTheSavedRevision = function(T)
		local State = {Stage = 4, Revision = 2}
		T.Eq(StoryLogic.UpgradeQuest({Revision = 3, Prepended = {[2] = 1, [3] = 2}}, State), true, "changed")
		T.Eq(State.Stage, 6, "4 + 2")
		T.Eq(State.Revision, 3)
	end,
	-- 6. a non-table state (a corrupt save entry) is refused
	NonTableState = function(T)
		T.Eq(StoryLogic.UpgradeQuest({Revision = 2, Prepended = {[2] = 1}}, 5), false, "a number")
		T.Eq(StoryLogic.UpgradeQuest({Revision = 2, Prepended = {[2] = 1}}, nil), false, "nil")
	end,

	-- Foundry data plan Task 3: the real acq_metal (travel put in front at revision 2): a save from before it, on the
	-- old stage 3 (experiment), is on the experiment still, now stage 4
	AcqMetalOldSaveMoves = function(T)
		local Quests = require(game.ReplicatedStorage.Modules.Data.Rensei.Quests)
		local State = {Stage = 3, Progress = {}}
		T.Eq(StoryLogic.UpgradeQuest(Quests.acq_metal, State), true, "an old acq_metal save is upgraded")
		T.Eq(State.Stage, 4, "old stage 3 is now stage 4")
		T.Eq(State.Revision, 2, "recorded at revision 2")
		T.Eq(StoryLogic.Stages(Quests.acq_metal)[State.Stage].Id, "experiment", "still the experiment")
	end,

	-- ===== fix round 1 (Ruling 22) =====
	-- Minor 4: the new stage is never past the last one
	ClampsToTheLastStage = function(T)
		local State = {Stage = 2}
		T.Eq(StoryLogic.UpgradeQuest({Revision = 2, Prepended = {[2] = 5}, Stages = {{}, {}, {}}}, State), true, "changed")
		T.Eq(State.Stage, 3, "2 + 5 clamped to the 3 stages")
	end,
	-- Minor 4: a non-number Prepended value counts as 0
	IgnoresNonNumberPrepended = function(T)
		local State = {Stage = 1}
		T.Eq(StoryLogic.UpgradeQuest({Revision = 3, Prepended = {[2] = "x", [3] = 1}}, State), true, "changed")
		T.Eq(State.Stage, 2, "only revision 3's 1 counts")
		T.Eq(State.Revision, 3)
	end,
	-- Minor 6: a state without a Stage is on stage 1
	StatelessStageIsSafe = function(T)
		local State = {}
		T.Eq(StoryLogic.UpgradeQuest({Revision = 2, Prepended = {[2] = 1}}, State), true, "changed")
		T.Eq(State.Stage, 2, "stage 1 + 1")
	end,
	-- Minor 6: UpgradeAll a second time changes nothing
	UpgradeAllTwiceIsFalse = function(T)
		WithRevisedDefs(function(QuestService)
			local Data = {Quests = {Active = {__fy_tq = {Stage = 1, Progress = {}}}, Completed = {}}}
			T.Eq(QuestService.UpgradeAll(Data), true, "the first UpgradeAll changes the old state")
			T.Eq(Data.Quests.Active.__fy_tq.Stage, 2)
			T.Eq(QuestService.UpgradeAll(Data), false, "a second UpgradeAll changes nothing")
			T.Eq(Data.Quests.Active.__fy_tq.Stage, 2, "still stage 2")
		end)
	end,
	-- Minor 6: UpgradeAll never touches Completed (a completed revised quest included)
	UpgradeAllLeavesCompleted = function(T)
		WithRevisedDefs(function(QuestService)
			local Data = {Quests = {Active = {__fy_tq = {Stage = 1, Progress = {}}}, Completed = {__fy_tq_done = 123}}}
			QuestService.UpgradeAll(Data)
			T.Same(Data.Quests.Completed, {__fy_tq_done = 123}, "Completed is untouched")
		end)
	end,
	-- I1: a saved state from an older revision is "not yet known" to a stage gate until it is upgraded
	StaleStageGatesWait = function(T)
		local Defs = require(game.ReplicatedStorage.Modules.Data.Rensei.Quests)
		local Ok, Err = pcall(function()
			Defs.__fy_tg = {Title = "T", Revision = 2, Prepended = {[2] = 1}, Stages = {
				{Id = "s1", Text = "1", Objectives = {{Id = "a", Text = "a", Kind = "Signal", Target = "__fy_never_a"}}},
				{Id = "s2", Text = "2", Objectives = {{Id = "b", Text = "b", Kind = "Signal", Target = "__fy_never_b"}}},
			}}
			local Data = {Quests = {Active = {__fy_tg = {Stage = 1, Progress = {}}}, Completed = {}}, Story = {}}
			local function Gate(Q) Q.Id = "__fy_tg" return StoryLogic.Meets({Quest = Q}, Data) end
			T.Eq(StoryLogic.Stale(Defs.__fy_tg, Data.Quests.Active.__fy_tg), true, "the state is stale")
			T.Eq(Gate({Stage = 1}), false, "a stale state isn't on stage 1")
			T.Eq(Gate({Stage = 2}), false, "nor on stage 2 yet")
			T.Eq(Gate({StageAtLeast = 1}), false, "nor at least on stage 1")
			T.Eq(Gate({Is = "Active"}), true, "but it is active")
			StoryLogic.UpgradeQuest(Defs.__fy_tg, Data.Quests.Active.__fy_tg)
			T.Eq(StoryLogic.Stale(Defs.__fy_tg, Data.Quests.Active.__fy_tg), false, "upgraded: not stale")
			T.Eq(Gate({Stage = 2}), true, "upgraded: on stage 2")
			T.Eq(Gate({StageAtLeast = 2}), true, "upgraded: at least stage 2")
		end)
		Defs.__fy_tg = nil
		if not Ok then error(Err, 0) end
	end,
}

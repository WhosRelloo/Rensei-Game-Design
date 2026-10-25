-- Test_QuestRevision (Foundry data plan Task 2, 2026-10-24): StoryLogic.UpgradeQuest, the pure rule by which a saved
-- quest state follows a revised quest (Revision = n, Prepended = {[r] = k}). No services; run in the Play VM
-- (LMRunSuite), as StoryLogic changes in this task.
local StoryLogic = require(game.ReplicatedStorage.Modules.Data.Rensei.StoryLogic)

local function Copy(T)
	if type(T) ~= "table" then return T end
	local R = {}
	for K, V in pairs(T) do R[K] = Copy(V) end
	return R
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
}

-- Test_AcqMetal (Foundry data plan Task 3, 2026-10-24): acq_metal's data after its move to the Foundry Yard. Pure (no
-- services), but run in the Play VM (LMRunSuite), as the data modules change in this task.
--   * acq_metal gains a first "travel" stage (Arrive "Foundry") at revision 2 (Prepended {[2] = 1}, owner decision C);
--   * every stage number the other data modules need for it comes from StoryLogic.StageIndex (Ruling 6), so the
--     inspects, minigames, trial and Brannoc's lines all moved one stage on together;
--   * the forge trial fits its room (owner decision E): the great hall's Forge Floor shell is 38.8 x 49.8 studs;
--   * Brannoc's notice in Ye starts the quest (owner decision D);
--   * (Task 9, Ruling 37) the travel stage's text names the North Road's way out on Ye's compass: "out north-west".
local Rensei = game.ReplicatedStorage.Modules.Data.Rensei
local StoryLogic = require(Rensei.StoryLogic)
local Quests = require(Rensei.Quests)
local Investigation = require(Rensei.Investigation)
local Minigames = require(Rensei.Minigames)
local Trials = require(Rensei.Trials)
local Dialogues = require(Rensei.Dialogues)

-- the Forge Floor shell (Foundry Yard plan, owner decision E): half its diagonal, and half its length less 2 studs
local SHELL_X, SHELL_Z = 38.8, 49.8
local HALF_DIAGONAL = math.sqrt((SHELL_X / 2) ^ 2 + (SHELL_Z / 2) ^ 2) -- 31.57
local FOE_MAX = SHELL_Z / 2 - 2 -- 22.9

-- trainer_<Id>'s Starts, read as {[Stage] = Node} from the first entry naming each stage of acq_<Id>
local function StageNodes(Id)
	local Out = {}
	for _, S in ipairs(Dialogues["trainer_" .. Id].Starts) do
		local Q = S.Requires and S.Requires.Quest
		if Q and Q.Id == "acq_" .. Id and Q.Is == "Active" and Q.Stage ~= nil and Out[Q.Stage] == nil then Out[Q.Stage] = S.Node end
	end
	return Out
end

return {
	StagesInOrder = function(T)
		local Ids = {}
		for _, S in ipairs(StoryLogic.Stages(Quests.acq_metal)) do table.insert(Ids, S.Id) end
		T.Eq(table.concat(Ids, ","), "travel,invite,fieldwork,experiment,trial,exam,recognition", "acq_metal's stage ids, in order")
	end,
	TravelArrivesInFoundry = function(T)
		local S = StoryLogic.Stages(Quests.acq_metal)[1]
		T.Eq(S.Id, "travel", "the first stage is travel")
		T.Eq(#S.Objectives, 1, "one travel objective")
		T.Eq(S.Objectives[1].Kind, "Arrive", "the travel objective is an Arrive")
		T.Eq(S.Objectives[1].Target, "Foundry", "it arrives in the Foundry region")
		-- (Task 9, Ruling 37) the travel text names the road's way out on Ye's compass, as Brannoc's notice does
		-- (Play_LindenmoorSmoke checks the notice's word against live positions in Ye: NORTH-WEST)
		T.True(string.find(S.Text, "out north-west", 1, true) ~= nil, "the travel text says the North Road leaves \"out north-west\": " .. S.Text)
		local Notice = string.upper(Investigation.Inspects.brannoc_moved.Text)
		T.True(string.find(Notice, "OUT NORTH-WEST", 1, true) ~= nil, "the notice names the same way: " .. Notice)
	end,
	RevisionTwoPrependsOne = function(T)
		T.Eq(Quests.acq_metal.Revision, 2, "acq_metal is at revision 2")
		T.True(type(Quests.acq_metal.Prepended) == "table", "acq_metal has Prepended")
		T.Eq(Quests.acq_metal.Prepended[2], 1, "revision 2 put one stage in front")
	end,
	InspectsNeedFieldwork = function(T)
		for _, Id in ipairs({"metal_shaft", "metal_samples", "metal_gear", "metal_note"}) do
			local D = Investigation.Inspects[Id]
			T.True(D ~= nil and D.Requires and D.Requires.Quest, Id .. " has a quest gate")
			T.Eq(D.Requires.Quest.Id, "acq_metal", Id .. ": acq_metal")
			T.Eq(D.Requires.Quest.StageAtLeast, 3, Id .. ": StageAtLeast 3 (fieldwork)")
		end
	end,
	MinigamesOnTheirStages = function(T)
		for Id, N in pairs({metal_match = 4, metal_exam = 6}) do
			local Q = Minigames[Id].Requires.Quest
			T.Eq(Q.Id, "acq_metal", Id .. ": acq_metal")
			T.Eq(Q.Is, "Active", Id .. ": Active")
			T.Eq(Q.Stage, N, Id .. ": stage " .. N)
		end
	end,
	TrialOnItsStage = function(T)
		local Q = Trials.metal_experiment.Requires.Quest
		T.Eq(Q.Id, "acq_metal", "metal_experiment: acq_metal")
		T.Eq(Q.Is, "Active", "metal_experiment: Active")
		T.Eq(Q.Stage, 5, "metal_experiment: stage 5 (trial)")
	end,
	TrialFitsTheForgeFloor = function(T)
		local Tr = Trials.metal_experiment
		T.True(Tr.Radius * 1.35 >= HALF_DIAGONAL,
			("the arena (Radius %s x 1.35) reaches the shell's corners (%.1f)"):format(tostring(Tr.Radius), HALF_DIAGONAL))
		T.True(Tr.FoeDistance <= FOE_MAX,
			("the foe (%s studs out) starts inside the shell (at most %.1f)"):format(tostring(Tr.FoeDistance), FOE_MAX))
	end,
	TrialTakesDecisionE = function(T)
		T.Eq(Trials.metal_experiment.Radius, 24, "Radius 24 (PROPOSAL, owner decision E; was 34)")
		T.Eq(Trials.metal_experiment.FoeDistance, 14, "FoeDistance 14 (PROPOSAL, owner decision E; was 16)")
	end,
	BrannocLinesFollowTheStages = function(T)
		local N = StageNodes("metal")
		local Want = {"sent", "sent", "fieldwork", "experiment", "trial", "exam", "recognize"}
		for Stage, Node in ipairs(Want) do T.Eq(N[Stage], Node, "trainer_metal stage " .. Stage) end
		T.Eq(N[8], nil, "no stage 8")
	end,
	IceKeepsOffsetZero = function(T)
		local N = StageNodes("ice")
		T.Eq(N[1], "sent", "trainer_ice stage 1")
		T.Eq(N[2], "fieldwork", "trainer_ice stage 2")
	end,
	NoticeStartsTheQuest = function(T)
		local D = Investigation.Inspects.brannoc_moved
		T.True(D ~= nil, "the brannoc_moved notice exists")
		T.Eq(D.StartsQuest, "acq_metal", "the notice starts acq_metal")
		T.True(D.Requires ~= nil and D.Requires.NoAffinity == true, "only for a player with no path")
		T.Eq(D.Evidence, nil, "the notice gives no evidence")
	end,
	InviteNamesFoundryDirection = function(T)
		local Invite = StoryLogic.Stages(Quests.acq_metal)[StoryLogic.StageIndex(Quests.acq_metal, "invite")]
		T.True(Invite.Text:find("north-east", 1, true) ~= nil, "the invite text says north-east (" .. Invite.Text .. ")")
		T.Eq(Invite.Objectives[1].Kind, "Visit", "invite: Visit")
		T.Eq(Invite.Objectives[1].Target, "Silent Forge", "invite: the Silent Forge")
	end,
	StageIndexEdges = function(T)
		T.True(type(StoryLogic.StageIndex) == "function", "StoryLogic.StageIndex exists")
		T.Eq(StoryLogic.StageIndex(Quests.acq_metal, "no_such_stage"), nil, "an unknown stage id")
		T.Eq(StoryLogic.StageIndex(nil, "exam"), nil, "a nil Def")
		T.Eq(StoryLogic.StageIndex("acq_metal", "exam"), nil, "a string Def")
		T.Eq(StoryLogic.StageIndex(Quests.acq_flame, "exam"), 5, "control: acq_flame's exam is stage 5")
	end,
}

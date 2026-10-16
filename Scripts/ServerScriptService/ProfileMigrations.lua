-- Save-schema migrations for the "PlayerData" profiles. Every place that loads a profile (Ye's
-- DataManager, the menu's MenuData, the tutorial's FlowData) runs ProfileMigrations.Migrate(Data)
-- BEFORE Profile:Reconcile() (Reconcile would stamp the template's SchemaVersion onto an old profile
-- and the steps would never run).
-- KEEP THIS FILE THE SAME IN EVERY PLACE. Bump ProfileData.SchemaVersion and add a step here for
-- every breaking change; steps must be safe on any place (additive, no place-only modules).

local Migrations = {
	-- nil -> 1: the JJK template schema (StatTable/SkillTree/"CE" stats) becomes Rensei's.
	-- Those keys never held Rensei progress, so they are dropped rather than converted.
	[0] = function(Data)
		Data.StatTable = nil
		Data.SkillTree = nil
		Data.Race = nil
		Data.StatPoints = math.max(0, (Data.Level or 1) - 1) * 3
	end,
	-- 1 -> 2: the skill tree (AlchemyTree, never used, becomes SkillTree) + refundable stage spending.
	[1] = function(Data)
		Data.SkillTree = Data.SkillTree or Data.AlchemyTree or {}
		Data.AlchemyTree = nil
		if Data.Mastery then Data.Mastery.StageSpend = Data.Mastery.StageSpend or {} end
	end,
	-- 2 -> 3: story state (flags, evidence, deductions, puzzles, minigames) + staged quests. Additive.
	[2] = function(Data)
		Data.Story = Data.Story or {}
		for _, K in ipairs({"Flags", "Evidence", "Deductions", "Puzzles", "Minigames"}) do
			Data.Story[K] = Data.Story[K] or {}
		end
		if Data.Quests then
			for _, State in pairs(Data.Quests.Active or {}) do State.Stage = State.Stage or 1 end
		end
	end,
	-- 3 -> 4: the morality ledger. Additive; choices already made (Outcome_<QuestId> flags) are turned
	-- into their deeds by Ye's MoralityService when the player joins (it reads the quest data).
	[3] = function(Data)
		Data.Morality = Data.Morality or {}
		for _, K in ipairs({"Deeds", "Conduct", "Standing", "Trust", "Taboo"}) do
			Data.Morality[K] = Data.Morality[K] or {}
		end
		Data.Morality.Renown = Data.Morality.Renown or 0
	end,
}

local ProfileMigrations = {}

-- Upgrade a profile's data to the newest schema, one step at a time.
function ProfileMigrations.Migrate(Data)
	local Version = Data.SchemaVersion or 0
	while Migrations[Version] do
		Migrations[Version](Data)
		Version += 1
		Data.SchemaVersion = Version
	end
end

return ProfileMigrations

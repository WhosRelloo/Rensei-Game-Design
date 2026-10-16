-- Quest definitions (QuestService). PLACEHOLDER content, owner-approved 2026-10-15 as placeholders:
-- the Foundry Yard investigation and a repeatable bounty. Numbers are PROPOSALS.
-- Schema:
--   [QuestId] = {
--     Title, Description (journal), Category = "Main" | "Regional" | "Investigation" | "Puzzle" | "Contract",
--     Giver = "NPC name" (journal), Requires = {StoryLogic conditions} (checked on Start),
--     Stages = {   -- in order; a stage's objectives run in parallel; Optional ones don't block
--       {Id = "s1", Text = "Journal line", Objectives = {
--         {Id = "o1", Text = "Defeat bandits", Kind = "Defeat", Target = "Bandit", Count = 5, Optional = false, Hidden = false},
--       }},
--     },
--     (a flat Objectives = {...} list still works: one stage)
--     Rewards = {Exp, Money, Items = {{Name, Amount}}, Codex = {"Entry"}},
--     Outcomes = {[Value of flag Outcome_<QuestId>] = {Text, Rewards = {...}, Deeds = {"deedId"}}},  -- extra, per ending
--       (Deeds: Rensei.Deeds, recorded once by MoralityService when the quest completes)
--     Repeatable = false, Cooldown = seconds (repeatables only),
--   }
-- Objective kinds and who signals them:
--   Talk (dialogue opened, Target = dialogue id) · Visit (area) · Defeat (QuestTarget / DisplayName)
--   Inspect (inspect id) · Evidence (evidence id) · Deduce (deduction id) · Puzzle (puzzle id)
--   Minigame (minigame id) · Mechanism ("<id>:<state>") · Flag (flag id) · Signal (any id)
-- Ids must be unique across all stages of a quest.

return {
	chalk_foundry = {
		Title = "Chalk on the Foundry Wall",
		Category = "Investigation",
		Giver = "Foreman Brask",
		Description = "Someone has been drawing transmutation circles in the Foundry Yard at night, without an Authority licence. Foreman Brask wants it stopped before the Authority stops it for him.",
		Stages = {
			{Id = "marks", Text = "Examine the chalk marks around the Foundry Yard.", Objectives = {
				{Id = "wall", Text = "Examine the circle on the yard wall", Kind = "Evidence", Target = "chalk_sample"},
				{Id = "vent", Text = "Examine the circle behind the steam vent", Kind = "Evidence", Target = "half_array"},
				{Id = "prints", Text = "Examine the third mark", Kind = "Evidence", Target = "small_prints"},
			}},
			{Id = "shift", Text = "Question the night shift about what they saw.", Objectives = {
				{Id = "mirra", Text = "Talk to Mirra, the night smelter", Kind = "Talk", Target = "foundry_mirra"},
				{Id = "tobin", Text = "Get the truth out of Tobin, the stoker", Kind = "Evidence", Target = "tobin_admission"},
			}},
			{Id = "store", Text = "The prints lead into the sealed furnace store. Find a way in.", Objectives = {
				{Id = "open", Text = "Open the furnace store", Kind = "Puzzle", Target = "furnace_store"},
			}},
			{Id = "search", Text = "Search the furnace store.", Objectives = {
				{Id = "notebook", Text = "Search the store", Kind = "Evidence", Target = "apprentice_notebook"},
			}},
			{Id = "deduce", Text = "Put the evidence together on your Case Board (J).", Objectives = {
				{Id = "who", Text = "Work out who drew the circles", Kind = "Deduce", Target = "who_drew"},
			}},
			{Id = "confront", Text = "Find the apprentice, Lise, and decide what happens to her.", Objectives = {
				{Id = "decide", Text = "Confront Lise", Kind = "Flag", Target = "Outcome_chalk_foundry"},
			}},
		},
		Rewards = {Exp = 400, Money = 150, Codex = {"Unlicensed Alchemy", "Foundry Yard"}},
		Outcomes = {
			Report = {Text = "You reported Lise to the Authority. Brask paid the informant's bounty.", Rewards = {Money = 100}, Deeds = {"reported_lise"}},
			Secret = {Text = "You kept Lise's secret. She pressed her week's wages on you.", Rewards = {Money = 50}, Deeds = {"kept_lise_secret"}},
			Teach = {Text = "You offered to teach Lise properly. She'll remember it.", Rewards = {Exp = 150}, Deeds = {"taught_lise"}},
		},
	},

	bandit_bounty = {
		Title = "Bounty: Ore Road Bandits",
		Category = "Contract",
		Giver = "Foreman Brask",
		Description = "Bandits keep hitting the ore carts. Brask pays per head - well, per five heads.",
		Objectives = {
			{Id = "bandits", Text = "Defeat bandits", Kind = "Defeat", Target = "Bandit", Count = 5},
		},
		Rewards = {Exp = 150, Money = 60},
		Repeatable = true,
		Cooldown = 600,
	},
}

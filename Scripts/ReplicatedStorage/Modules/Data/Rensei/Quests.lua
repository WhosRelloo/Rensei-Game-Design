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
--   Arrive (region id, Rensei.Places / Regions: TravelService.Arrive signals it; it counts at once when the quest
--     starts, or its stage begins, in that region; World plan 1 Task 10)
-- Ids must be unique across all stages of a quest.

return {
	-- ===== Forgotten Sites (2026-10-18) =====
	-- Exploration quests: Category = "Exploration", Tier = 1-4 (I Forgotten, II Sealed, III Forbidden, IV Classified),
	-- StartOnVisit = the site's area (walking in starts it; a rumor can start it too). PROPOSAL numbers.
	forgotten_halvard = {
		Title = "Halvard's Adit", Category = "Exploration", Tier = 1,
		StartOnVisit = "Halvard's Adit",
		Description = "An old assay mine cut into Lindenmoor's eastern ridge, sealed by Authority order years ago. Someone has pried the boards loose.",
		Stages = {
			{Id = "s1", Text = "Find a way into the old adit on Lindenmoor's eastern ridge.", Objectives = {
				{Id = "visit", Text = "Enter Halvard's Adit", Kind = "Visit", Target = "Halvard's Adit"},
			}},
			{Id = "s2", Text = "The working is past a dead lift. Get the winch running.", Objectives = {
				{Id = "winch", Text = "Get the lift winch running", Kind = "Mechanism", Target = "adit_winch:Running"},
			}},
			{Id = "s3", Text = "Water has flooded the lower working. Find a way across the sump.", Objectives = {
				{Id = "sump", Text = "Drain or cross the flooded sump", Kind = "Puzzle", Target = "adit_drain"},
			}},
			{Id = "s4", Text = "Scavengers are picking over Halvard's laboratory.", Objectives = {
				{Id = "scav", Text = "Drive off the scavengers", Kind = "Defeat", Target = "Adit Scavenger", Count = 2},
				{Id = "notes", Text = "Find Halvard's notes", Kind = "Evidence", Target = "halvard_notes"},
				{Id = "hidden", Text = "Find what's behind the cracked wall", Kind = "Puzzle", Target = "adit_hidden", Optional = true},
			}},
			{Id = "s5", Text = "Halvard locked his vault with an array of his own.", Objectives = {
				{Id = "vault", Text = "Open the vault", Kind = "Puzzle", Target = "adit_vault"},
			}},
			{Id = "s6", Text = "Find out what Halvard sealed the mine over.", Objectives = {
				{Id = "ledger", Text = "Read Halvard's ledger", Kind = "Evidence", Target = "halvard_ledger"},
			}},
		},
		Rewards = {Exp = 450, Money = 120, Training = {Quest = 1}, Codex = {"Halvard's Adit", "Assay Rings"}},
	},
	-- ===== the Lindenmoor expansion's clue markers (Lindenmoor import Task 8, 2026-10-24) =====
	-- Started by inspecting the clue (Rensei.Investigation StartsQuest; the Evidence objective is caught up at once);
	-- finished by the townsperson whose Clue line answers it (Rensei.Townsfolk: the line signals the Signal objective).
	-- PROPOSAL wording and rewards.
	lm_ridge = {
		Title = "The Ridge Marker",
		Category = "Investigation",
		Description = "A standing stone on a knoll above the training field carries a surveyor's arrow that someone keeps scrubbed clean.",
		Stages = {
			{Id = "s1", Text = "Find out who looks after the ridge marker. Someone at the training field might know.", Objectives = {
				{Id = "mark", Text = "Examine the ridge marker", Kind = "Evidence", Target = "lm_ridge_survey"},
				{Id = "ask", Text = "Ask at the training field", Kind = "Signal", Target = "lm_ridge_told"},
			}},
		},
		Rewards = {Exp = 60},
	},
	lm_mine = {
		Title = "The Boarded Shaft",
		Category = "Investigation",
		Description = "A shaft under the headframe on the mine approach has been boarded and chained, with ore still lying around it.",
		Stages = {
			{Id = "s1", Text = "Find out why the shaft was closed. The mine hand might tell you.", Objectives = {
				{Id = "ore", Text = "Examine the boarded shaft", Kind = "Evidence", Target = "lm_shaft_ore"},
				{Id = "ask", Text = "Ask the mine hand", Kind = "Signal", Target = "lm_mine_told"},
			}},
		},
		Rewards = {Exp = 60},
	},
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

	-- ===== alchemy acquisition (2026-10-16; PROPOSAL content, owner to rewrite) =====
	-- One discipline per character (Identity.Affinity): starting needs no path and no other acquisition
	-- under way. The path is granted by the Affinity reward when the quest completes (QuestService).
	acq_flame = {
		Title = "The Unburned Lesson",
		Category = "Main",
		Giver = "Calda, Flame Alchemist",
		Description = "Calda won't teach a student who wants fire. She wants one who understands why fire gets away from people.",
		Requires = {NoAffinity = true, Quests = {
			{Id = "acq_ice", Is = "NotActive"}, {Id = "acq_earth", Is = "NotActive"},
			{Id = "acq_wind", Is = "NotActive"}, {Id = "acq_metal", Is = "NotActive"}}},
		Stages = {
			{Id = "invite", Text = "Go to the burned laboratory in Bramble Woods, the valley's far south-east corner past the mine.", Objectives = {
				{Id = "lab", Text = "Reach the burned laboratory", Kind = "Visit", Target = "Burned Laboratory"},
			}},
			{Id = "fieldwork", Text = "Work out how the laboratory fire happened.", Objectives = {
				{Id = "scorch", Text = "Read the scorch marks", Kind = "Evidence", Target = "burn_pattern"},
				{Id = "vent", Text = "Check the wall vent", Kind = "Evidence", Target = "open_vent"},
				{Id = "shelf", Text = "Check what was stored above the chamber", Kind = "Evidence", Target = "flash_powder"},
				{Id = "log", Text = "Find what the apprentice left behind", Kind = "Evidence", Target = "corin_log", Optional = true},
				{Id = "cause", Text = "Work out the cause on your Case Board (J)", Kind = "Deduce", Target = "lab_fire_cause"},
			}},
			{Id = "experiment", Text = "Bring the lab's reaction chamber to a clean ignition.", Objectives = {
				{Id = "chamber", Text = "Run the reaction chamber", Kind = "Minigame", Target = "flame_reaction"},
			}},
			{Id = "trial", Text = "Corin Vale is still in the ash pit just east of the lab. Stop him.", Objectives = {
				{Id = "corin", Text = "Face Corin in the ash pit", Kind = "Flag", Target = "Trial_flame_apprentice"},
			}},
			{Id = "exam", Text = "Return to Calda and take the examination.", Objectives = {
				{Id = "plate", Text = "Pass Calda's examination", Kind = "Minigame", Target = "flame_exam"},
			}},
			{Id = "recognition", Text = "Speak with Calda.", Objectives = {
				{Id = "calda", Text = "Speak with Calda", Kind = "Signal", Target = "acq_flame_recognized"},
			}},
		},
		Rewards = {Affinity = "Flame", Exp = 600, Training = {Quest = 2}, Codex = {"Flame Alchemy"}},
	},
	acq_ice = {
		Title = "The Stillness Beneath",
		Category = "Main",
		Giver = "Veyra, Ice Alchemist",
		Description = "Veyra's colleague vanished from a frozen research station. She won't say what she suspects until you've learned to look.",
		Requires = {NoAffinity = true, Quests = {{Id = "acq_flame", Is = "NotActive"}, {Id = "acq_earth", Is = "NotActive"}, {Id = "acq_wind", Is = "NotActive"}, {Id = "acq_metal", Is = "NotActive"}}},
		Stages = {
			{Id = "invite", Text = "Go to the frozen research station up on the Cypress ridge rim, at the valley's north-west end.", Objectives = {
				{Id = "site", Text = "Reach the frozen research station", Kind = "Visit", Target = "Frozen Research Station"},
			}},
			{Id = "fieldwork", Text = "Find out what froze the station.", Objectives = {
				{Id = "floor", Text = "Read the ice on the floor", Kind = "Evidence", Target = "uneven_ice"},
				{Id = "channels", Text = "Check the water channels", Kind = "Evidence", Target = "frozen_channels"},
				{Id = "pump", Text = "Examine the pump housing", Kind = "Evidence", Target = "frost_cycles"},
				{Id = "notes", Text = "Find what the researcher left behind", Kind = "Evidence", Target = "maren_notes", Optional = true},
				{Id = "cause", Text = "Work out the cause on your Case Board (J)", Kind = "Deduce", Target = "station_freeze"},
			}},
			{Id = "experiment", Text = "Restore the station's pumps without cracking the casings.", Objectives = {
				{Id = "station", Text = "Work the pump housing", Kind = "Minigame", Target = "ice_phase"},
			}},
			{Id = "trial", Text = "Something wakes in the frozen chamber east of the station. Face it.", Objectives = {
				{Id = "foe", Text = "Face the Crystallized Guardian", Kind = "Flag", Target = "Trial_ice_guardian"},
			}},
			{Id = "exam", Text = "Return to Veyra and take the examination.", Objectives = {
				{Id = "examined", Text = "Pass Veyra's examination", Kind = "Minigame", Target = "ice_exam"},
			}},
			{Id = "recognition", Text = "Speak with Veyra.", Objectives = {
				{Id = "trainer", Text = "Speak with Veyra", Kind = "Signal", Target = "acq_ice_recognized"},
			}},
		},
		Rewards = {Affinity = "Ice", Exp = 600, Training = {Quest = 2}, Codex = {"Ice Alchemy"}},
	},
	acq_earth = {
		Title = "The Weight of Foundations",
		Category = "Main",
		Giver = "Holt, Earth Alchemist",
		Description = "A footbridge the village depends on is failing. Holt wants to know why before anyone touches it - including you.",
		Requires = {NoAffinity = true, Quests = {{Id = "acq_flame", Is = "NotActive"}, {Id = "acq_ice", Is = "NotActive"}, {Id = "acq_wind", Is = "NotActive"}, {Id = "acq_metal", Is = "NotActive"}}},
		Stages = {
			{Id = "invite", Text = "Go to the cracked footbridge on the mine plateau, east of the training field across the gorge.", Objectives = {
				{Id = "site", Text = "Reach the cracked footbridge", Kind = "Visit", Target = "Cracked Footbridge"},
			}},
			{Id = "fieldwork", Text = "Find out why the footing is failing.", Objectives = {
				{Id = "cracks", Text = "Read the cracks in the footing", Kind = "Evidence", Target = "stress_cracks"},
				{Id = "pier", Text = "Test the middle pier", Kind = "Evidence", Target = "hollow_pier"},
				{Id = "soil", Text = "Check the east footing", Kind = "Evidence", Target = "washed_soil"},
				{Id = "report", Text = "Find the old survey report", Kind = "Evidence", Target = "survey_report", Optional = true},
				{Id = "cause", Text = "Work out the cause on your Case Board (J)", Kind = "Deduce", Target = "bridge_failure"},
			}},
			{Id = "experiment", Text = "Work out where the bridge needs support.", Objectives = {
				{Id = "station", Text = "Brace the footing at the survey table", Kind = "Minigame", Target = "earth_loads"},
			}},
			{Id = "trial", Text = "The quarry east of the bridge is coming apart, and someone is doing it on purpose. Stop him.", Objectives = {
				{Id = "foe", Text = "Face Dask in the unstable quarry", Kind = "Flag", Target = "Trial_earth_quarry"},
			}},
			{Id = "exam", Text = "Return to Holt and take the examination.", Objectives = {
				{Id = "examined", Text = "Pass Holt's examination", Kind = "Minigame", Target = "earth_exam"},
			}},
			{Id = "recognition", Text = "Speak with Holt.", Objectives = {
				{Id = "trainer", Text = "Speak with Holt", Kind = "Signal", Target = "acq_earth_recognized"},
			}},
		},
		Rewards = {Affinity = "Earth", Exp = 600, Training = {Quest = 2}, Codex = {"Earth Alchemy"}},
	},
	acq_wind = {
		Title = "The Invisible Equation",
		Category = "Main",
		Giver = "Ansel, Wind Alchemist",
		Description = "The observatory's machines stopped. Ansel knows why, and won't say. He wants to see if you can work it out from what the air left behind.",
		Requires = {NoAffinity = true, Quests = {{Id = "acq_flame", Is = "NotActive"}, {Id = "acq_ice", Is = "NotActive"}, {Id = "acq_earth", Is = "NotActive"}, {Id = "acq_metal", Is = "NotActive"}}},
		Stages = {
			{Id = "invite", Text = "Go to the silent observatory on the crest of the Cypress ridge rim, north-west of the training field.", Objectives = {
				{Id = "site", Text = "Reach the silent observatory", Kind = "Visit", Target = "Silent Observatory"},
			}},
			{Id = "fieldwork", Text = "Work out why the observatory stopped.", Objectives = {
				{Id = "flags", Text = "Watch the pennants", Kind = "Evidence", Target = "still_flags"},
				{Id = "dust", Text = "Read the dust on the floor", Kind = "Evidence", Target = "dust_lines"},
				{Id = "vents", Text = "Check the outlet shutters", Kind = "Evidence", Target = "closed_vents"},
				{Id = "log", Text = "Find the pressure log", Kind = "Evidence", Target = "pressure_log", Optional = true},
				{Id = "cause", Text = "Work out the cause on your Case Board (J)", Kind = "Deduce", Target = "observatory_stall"},
			}},
			{Id = "experiment", Text = "Route the air through the observatory's ducts again.", Objectives = {
				{Id = "station", Text = "Work the duct manifold", Kind = "Minigame", Target = "wind_routing"},
			}},
			{Id = "trial", Text = "Siv is still on the gale floor east of the observatory. Prove you can read what moves you.", Objectives = {
				{Id = "foe", Text = "Face Siv on the gale floor", Kind = "Flag", Target = "Trial_wind_dancer"},
			}},
			{Id = "exam", Text = "Return to Ansel and take the examination.", Objectives = {
				{Id = "examined", Text = "Pass Ansel's examination", Kind = "Minigame", Target = "wind_exam"},
			}},
			{Id = "recognition", Text = "Speak with Ansel.", Objectives = {
				{Id = "trainer", Text = "Speak with Ansel", Kind = "Signal", Target = "acq_wind_recognized"},
			}},
		},
		Rewards = {Affinity = "Wind", Exp = 600, Training = {Quest = 2}, Codex = {"Wind Alchemy"}},
	},
	acq_metal = {
		Title = "The Unyielding Principle",
		Category = "Main",
		Giver = "Brannoc, Metal Alchemist",
		Description = "A forge east of the Foundry Yard went cold mid-shift. Brannoc wants the failure understood before a single bolt is turned.",
		Requires = {NoAffinity = true, Quests = {{Id = "acq_flame", Is = "NotActive"}, {Id = "acq_ice", Is = "NotActive"}, {Id = "acq_earth", Is = "NotActive"}, {Id = "acq_wind", Is = "NotActive"}}},
		Stages = {
			{Id = "invite", Text = "Go to the silent forge in the north meadows by the gap, just east of the Foundry Yard.", Objectives = {
				{Id = "site", Text = "Reach the silent forge", Kind = "Visit", Target = "Silent Forge"},
			}},
			{Id = "fieldwork", Text = "Find out why the forge's machine failed.", Objectives = {
				{Id = "shaft", Text = "Examine the broken drive shaft", Kind = "Evidence", Target = "sheared_shaft"},
				{Id = "samples", Text = "Read the sample rack", Kind = "Evidence", Target = "sample_rack"},
				{Id = "gear", Text = "Look at the repaired gear", Kind = "Evidence", Target = "bad_weld"},
				{Id = "record", Text = "Find the workshop record", Kind = "Evidence", Target = "experiment_record", Optional = true},
				{Id = "cause", Text = "Work out the cause on your Case Board (J)", Kind = "Deduce", Target = "forge_failure"},
			}},
			{Id = "experiment", Text = "Choose the right materials for the forge's new parts.", Objectives = {
				{Id = "station", Text = "Work the material bench", Kind = "Minigame", Target = "metal_match"},
			}},
			{Id = "trial", Text = "Something armored is moving on the forge floor east of the workshop. Stop it.", Objectives = {
				{Id = "foe", Text = "Face the Armored Experiment", Kind = "Flag", Target = "Trial_metal_experiment"},
			}},
			{Id = "exam", Text = "Return to Brannoc and take the examination.", Objectives = {
				{Id = "examined", Text = "Pass Brannoc's examination", Kind = "Minigame", Target = "metal_exam"},
			}},
			{Id = "recognition", Text = "Speak with Brannoc.", Objectives = {
				{Id = "trainer", Text = "Speak with Brannoc", Kind = "Signal", Target = "acq_metal_recognized"},
			}},
		},
		Rewards = {Affinity = "Metal", Exp = 600, Training = {Quest = 2}, Codex = {"Metal Alchemy"}},
	},
}

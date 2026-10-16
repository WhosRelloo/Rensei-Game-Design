-- Evidence: clues a player can hold (profile Story.Evidence). Stable ids; never rename one that has
-- shipped. Given by StoryService.GiveEvidence (inspect points, dialogue actions, minigames).
-- PLACEHOLDER content (owner approved 2026-10-15 as placeholders): the Foundry Yard investigation.
--   [Id] = {Title, Text (journal), Quest (the quest it belongs to, for the journal's grouping)}

return {
	chalk_sample = {
		Quest = "chalk_foundry", Title = "Chalk Sample",
		Text = "Scraped from the yard wall. Grey, gritty, and it smells of the furnaces. Not the white stick chalk the Authority's clerks use.",
	},
	half_array = {
		Quest = "chalk_foundry", Title = "Half-Finished Array",
		Text = "A circle drawn with care but no training: the outer ring breaks off mid-line, as if the hand lost its nerve. Someone is practising.",
	},
	small_prints = {
		Quest = "chalk_foundry", Title = "Small Boot Prints",
		Text = "Prints in the soot beside the marks, smaller than any foundry hand's boots. They lead toward the sealed furnace store.",
	},
	tobin_admission = {
		Quest = "chalk_foundry", Title = "Tobin's Admission",
		Text = "Tobin slept through his shift. He woke to a lamp moving inside the furnace store, and said nothing so nobody would ask why he was asleep.",
	},
	apprentice_notebook = {
		Quest = "chalk_foundry", Title = "Apprentice's Notebook",
		Text = "Page after page of practice circles, each a little better than the last. Signed on the inside cover: \"L. - smelting apprentice, second year.\"",
	},
	-- optional side content (minigames): never required by the quest
	slag_chalk = {
		Quest = "chalk_foundry", Title = "Slag Chalk",
		Text = "Assayed at Mirra's bench: the wall chalk is ground furnace slag. Nobody outside the yard would have it - whoever drew the circles works here.",
	},
	voided_ledger = {
		Quest = "chalk_foundry", Title = "Voided Ledger Line",
		Text = "A State Authority shipping line, struck out in red wax and decoded: crates of licensed chalk, sent off the yard's books. The Authority is missing chalk too.",
	},
}

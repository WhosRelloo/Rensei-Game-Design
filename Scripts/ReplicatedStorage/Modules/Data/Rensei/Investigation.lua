-- Investigation content (InvestigationService).
--   Inspects[Id]: a part or model tagged "RenseiInspect" with attribute InspectId = Id gets an
--     "Inspect" prompt. {Title, Text, AfterText (shown once already examined), Evidence, Requires}
--     Requires (StoryLogic conditions) gates the evidence; without it the player just reads Locked
--     (or Text when Locked is absent).
--   Deductions[Id]: Case Board questions. {Title, Question, Slots = {{Label, Answer = evidence id}},
--     Requires (evidence needed before it shows), Wrong (line for a wrong answer)}
-- PLACEHOLDER content (Foundry Yard investigation).

local Q = {Quest = {Id = "chalk_foundry", Is = "Active"}}

return {
	Inspects = {
		mark_wall = {
			Title = "Chalk Circle", Evidence = "chalk_sample", Requires = Q,
			Text = "A circle drawn on the soot-black wall. You scrape a little of the chalk onto your thumb: grey, gritty, warm-smelling. Foundry chalk.",
			AfterText = "The circle you scraped. Grey foundry chalk.",
			Locked = "A chalk circle on the wall. Someone's been drawing where they shouldn't.",
		},
		mark_vent = {
			Title = "Half-Drawn Array", Evidence = "half_array", Requires = Q,
			Text = "Behind the vent, a bigger circle. The inner rings are neat, careful. The outer ring stops dead halfway round, the line wavering where the hand gave up.",
			AfterText = "The unfinished array. Careful, untrained, unfinished.",
			Locked = "A half-drawn circle behind the vent.",
		},
		mark_prints = {
			Title = "Prints in the Soot", Evidence = "small_prints", Requires = Q,
			Text = "Boot prints in the soot under the third mark. Small. Too small for a stoker or a smelter. They lead away toward the furnace store.",
			AfterText = "The small prints, leading to the furnace store.",
			Locked = "Soot, and footprints in it.",
		},
		store_notebook = {
			Title = "Notebook", Evidence = "apprentice_notebook", Requires = Q,
			Text = "A cheap notebook wedged behind the coal bins. Practice circles, dozens of them, each a little cleaner than the last. The cover is signed: \"L. - smelting apprentice, second year.\"",
			AfterText = "L.'s notebook of practice circles.",
			Locked = "A notebook behind the coal bins.",
		},
		-- the clue for the furnace store lock (PuzzleService furnace_store)
		store_engraving = {
			Title = "Engraving",
			Text = "Letters cut into the lintel, worn smooth by decades of soot: FIRE IN THE MOUTH, WEIGHT ON THE STONE. Below, scratched later by a different hand: \"...or mend the old seal, if you've the skill.\"",
		},
		-- the key for the Shipping Ledger (Minigames.ledger_cipher, Key = 5)
		authority_crate = {
			Title = "Authority Crate",
			Text = "A crate stamped with the State Authority seal. Around the seal's rim runs a clerk's ring of paired letters, half rubbed off; the clearest pair reads F over A. The ledger clerks key their books this way.",
		},
		yard_board = {
			Title = "Notice Board",
			Text = "STATE AUTHORITY NOTICE: The drawing of transmutation circles without a licence is an offence. Report unlicensed alchemy to your foreman. Below it, a fresher sheet: BOUNTY - bandits on the ore road. See Foreman Brask.",
		},
	},

	Deductions = {
		who_drew = {
			Title = "Who Drew the Circles",
			Question = "Who has been drawing circles in the Foundry Yard?",
			Requires = {Evidence = {"half_array", "small_prints", "apprentice_notebook"}},
			Slots = {
				{Label = "The hand: someone untrained", Answer = "half_array"},
				{Label = "The size: someone small", Answer = "small_prints"},
				{Label = "The name: someone who works here", Answer = "apprentice_notebook"},
			},
			Conclusion = "An apprentice. Young, untrained, and practising alone at night: the smelting apprentice who signs as \"L.\"",
			Wrong = "That doesn't hold together. Look at what each piece actually tells you.",
		},
	},
}

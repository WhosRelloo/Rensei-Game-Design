-- Evidence: clues a player can hold (profile Story.Evidence). Stable ids; never rename one that has
-- shipped. Given by StoryService.GiveEvidence (inspect points, dialogue actions, minigames).
-- PLACEHOLDER content (owner approved 2026-10-15 as placeholders): the Foundry Yard investigation.
--   [Id] = {Title, Text (journal), Quest (the quest it belongs to, for the journal's grouping)}
--   Technique = "<Path>" (optional, 2026-10-18): the evidence describes that alchemy. IdentityService links it,
--     as a hypothesis only, to Player Identities records where that technique was observed.

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
	-- ===== alchemy acquisition: Flame, "The Unburned Lesson" (PROPOSAL content) =====
	burn_pattern = {
		Quest = "acq_flame", Title = "Burn Pattern",
		Text = "The scorch fans out from the reaction bench, then runs in a straight black line up the wall to the vent. The fire went where the air went.",
	},
	open_vent = {
		Quest = "acq_flame", Title = "Wedged Vent",
		Text = "The vent shutters were jammed fully open with a chisel. Someone wanted more air in the chamber, not less.",
	},
	flash_powder = {
		Quest = "acq_flame", Title = "Blown Reagent Jars",
		Text = "FLASH POWDER - KEEP COOL, stored on the shelf right over the chamber. The glass burst outward: they went off after the chamber did.",
	},
	corin_log = {
		Quest = "acq_flame", Title = "Corin's Log", Research = true,
		Text = "Research note. \"Raised the heat again. She says patience. Patience is for Ice students. Tonight I'll show her what the chamber can really do.\" - C. Vale",
	},
	-- ===== alchemy acquisition: Ice, "The Stillness Beneath" =====
	uneven_ice = {Quest = "acq_ice", Title = "Uneven Ice",
		Text = "The floor ice is thick by the door and paper-thin by the pipes. The station froze from the outside in."},
	frozen_channels = {Quest = "acq_ice", Title = "Frozen Channels",
		Text = "The water channels froze drain-end first. The cold ran backwards along the pipes, against the flow."},
	frost_cycles = {Quest = "acq_ice", Title = "Frost Rings",
		Text = "Ring after ring of frost on the pump housing. It froze, thawed and froze again - dozens of times, on a cycle."},
	maren_notes = {Quest = "acq_ice", Title = "Maren's Notes", Research = true,
		Text = "Research note. \"The guardian holds the station's cold. If the cycle stops, it wakes. Do not let the pumps fail.\" - M. Ostrova"},
	-- ===== alchemy acquisition: Earth, "The Weight of Foundations" =====
	stress_cracks = {Quest = "acq_earth", Title = "Stress Cracks",
		Text = "The cracks fan out from the middle pier. Nearly the whole load was landing on one support."},
	hollow_pier = {Quest = "acq_earth", Title = "Hollow Pier",
		Text = "The middle pier rings hollow. It was transmuted from loose gravel and never compacted: it looks strong and isn't."},
	washed_soil = {Quest = "acq_earth", Title = "Washed-Out Soil",
		Text = "The ground under the west footing is washed away. Water has run under it for months."},
	survey_report = {Quest = "acq_earth", Title = "Survey Report", Research = true,
		Text = "Research note. \"Pier rebuilt by alchemy for speed. Recommend inspection before loading.\" Stamped, filed, never read."},
	-- ===== alchemy acquisition: Wind, "The Invisible Equation" =====
	still_flags = {Quest = "acq_wind", Title = "Still Pennants",
		Text = "Every pennant hangs dead except the one by the east vent. Air still comes in there, and nowhere else."},
	dust_lines = {Quest = "acq_wind", Title = "Dust Lines",
		Text = "Dust lies in long streaks pointing at the south duct. The air used to leave that way."},
	closed_vents = {Quest = "acq_wind", Title = "Wired Shutters",
		Text = "The outlet shutters are wired shut from the inside. Someone sealed the exits on purpose."},
	pressure_log = {Quest = "acq_wind", Title = "Pressure Log", Research = true,
		Text = "Research note. The readings climb for a week, then: \"Sealed the outlets to hold pressure for the experiment. Siv disagrees.\""},
	-- ===== alchemy acquisition: Metal, "The Unyielding Principle" =====
	sheared_shaft = {Quest = "acq_metal", Title = "Sheared Shaft",
		Text = "The drive shaft broke clean through, bright grains at the break. Too hard and brittle for the load - not too weak."},
	sample_rack = {Quest = "acq_metal", Title = "Sample Rack",
		Text = "Material samples, each tagged with strength, flex and heat. The shaft's tag: \"cast iron - DO NOT USE FOR SHAFTS\", in someone else's hand."},
	bad_weld = {Quest = "acq_metal", Title = "Soft Repair",
		Text = "The gear was soldered back on with soft solder. By the soot, it held about an hour."},
	experiment_record = {Quest = "acq_metal", Title = "Workshop Record", Research = true,
		Text = "Research note. \"Plated the subject with cast iron. It moves. It shouldn't.\" Under it, the forge's fire log, cut short."},

	-- ===== Forgotten Sites: Halvard's Adit (2026-10-18; placeholder lore) =====
	adit_survey_mark = {Quest = "forgotten_halvard", Title = "Survey Mark",
		Text = "Chiselled over the boarded adit: H. HALVARD - LICENSED ASSAYER - No. 4 WORKING. An Authority seal under it, and fresh scratches where someone pried at the boards."},
	halvard_notes = {Quest = "forgotten_halvard", Title = "Halvard's Field Notes", Research = true, Technique = "Earth",
		Text = "Research note. \"The seam holds its load because I tell it to. No clap, no circle: the array is in the rock itself, I only wake it.\" Load paths drawn straight onto bedrock."},
	halvard_ledger = {Quest = "forgotten_halvard", Title = "Halvard's Ledger",
		Text = "Eleven years of assay returns, then a last page: \"No. 4 is not ore. The array goes deeper than the mine. They will want it, so I am sealing it.\" The Authority sealed the adit a month later."},
	adit_visitor_note = {Quest = "forgotten_halvard", Title = "A Visitor's Note", Technique = "Flame",
		Text = "Recent, in charcoal on the back of an assay slip: \"Ring three answers to fire. Someone has been here before me.\" Scorch marks on the strongbox lock."},

	-- ===== the Lindenmoor expansion's clue markers (Lindenmoor import Task 8, 2026-10-24; PROPOSAL wording) =====
	lm_ridge_survey = {Quest = "lm_ridge", Title = "Surveyor's Mark",
		Text = "An arrow cut into the standing stone on the knoll, a row of figures beneath it. The grooves were scrubbed clean recently: someone in Lindenmoor still looks after the mark."},
	lm_shaft_ore = {Quest = "lm_mine", Title = "Spilled Ore",
		Text = "Ore lying around a boarded, chained shaft on the mine approach, never loaded. The cart rail still runs up to the boards. The shaft was closed in a hurry."},

	-- ===== Foundry Yard: the shift ledger (Foundry Yard plan, 2026-10-24; PROPOSAL wording) =====
	-- the ledger and the docket (Rensei.Investigation) and three townsfolk's clue lines (Rensei.Townsfolk) give these
	foundry_full_shift = {Quest = "foundry_ledger", Title = "A Full Shift Booked",
		Text = "The shift ledger books Furnace One's late crew for a full eight hours on the 14th. The same page says the furnace was banked at 18:00, four hours in."},
	foundry_banked_early = {Quest = "foundry_ledger", Title = "Sent Home at Six",
		Text = "Edmund Rusk, day furnace hand: Furnace One was banked by 18:00 on the 14th and the late crew sent home. Nobody worked it after six."},
	foundry_short_pay = {Quest = "foundry_ledger", Title = "Four Hours' Pay",
		Text = "Sella Marsh, late furnace hand: her pay packet for the 14th held four hours. The ledger books eight. Someone drew pay for hours nobody worked."},
	foundry_docket_round = {Quest = "foundry_ledger", Title = "Copied from the Dockets",
		Text = "Aldous Merriweather, the shift clerk, copies the ledger from the charge hands' dockets, word for word. Once copied, the dockets are filed in a store in the underworks."},
	foundry_scraped_docket = {Quest = "foundry_ledger", Title = "The Scraped Docket",
		Text = "Furnace One's late-shift docket for the 14th. Someone scraped the 4 off and wrote an 8 before the clerk copied it. Signed by the charge hand, C. Ashe."},
}

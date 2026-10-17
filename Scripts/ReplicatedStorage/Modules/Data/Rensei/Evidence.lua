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
		Text = "The ground under the east footing is washed away. Water has run under it for months."},
	survey_report = {Quest = "acq_earth", Title = "Survey Report", Research = true,
		Text = "Research note. \"Pier rebuilt by alchemy for speed. Recommend inspection before loading.\" Stamped, filed, never read."},
	-- ===== alchemy acquisition: Wind, "The Invisible Equation" =====
	still_flags = {Quest = "acq_wind", Title = "Still Pennants",
		Text = "Every pennant hangs dead except the one by the west vent. Air still comes in there, and nowhere else."},
	dust_lines = {Quest = "acq_wind", Title = "Dust Lines",
		Text = "Dust lies in long streaks pointing at the north duct. The air used to leave that way."},
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
}

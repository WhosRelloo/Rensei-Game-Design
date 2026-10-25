-- Investigation content (InvestigationService).
--   Inspects[Id]: a part or model tagged "RenseiInspect" with attribute InspectId = Id gets an
--     "Inspect" prompt. {Title, Text, AfterText (shown once already examined), Evidence, Requires}
--     Requires (StoryLogic conditions) gates the evidence; without it the player just reads Locked
--     (or Text when Locked is absent).
--     StartsQuest = "<QuestId>" (optional, 2026-10-23): after an inspect whose Requires pass (the evidence was
--     given, or it was already held and AfterText shown), the quest starts if QuestService.CanStart allows it.
--     A failed Requires never starts it: not a Locked inspect, and not a def with no Evidence either (on such a
--     def Requires gates only the quest; the text is the same either way). Put any other gate on the quest's own
--     Requires (CanStart checks it). An active or completed quest is never restarted, but a Repeatable quest
--     starts again on a later inspect once its Cooldown has passed.
--     Region-map clue markers: a part tagged "RenseiClue" with attribute ClueId = Id is an inspect point for
--     Inspects[Id] (InvestigationService gives it the RenseiInspect tag and InspectId = ClueId; ClueId wins over
--     an InspectId the part already carries).
--   Deductions[Id]: Case Board questions. {Title, Question, Slots = {{Label, Answer = evidence id}},
--     Requires (evidence needed before it shows), Wrong (line for a wrong answer)}
-- PLACEHOLDER content (Foundry Yard investigation).

local Q = {Quest = {Id = "chalk_foundry", Is = "Active"}}
-- (Foundry Yard plan, Ruling 6) acq_metal's stage numbers come from its stage ids; neither module requires this one
local StoryLogic = require(script.Parent.StoryLogic)
local Quests = require(script.Parent.Quests)

return {
	Inspects = {
		-- ===== Forgotten Sites: Halvard's Adit (2026-10-18) =====
		adit_mouth = {Title = "Boarded Adit", Evidence = "adit_survey_mark",
			Text = "Planks nailed over a mine mouth cut into the ridge. Two hang loose; a few good hits, or a little alchemy, would bring the lot down.", -- PROPOSAL wording (boards smash, 2026-10-20): the owner can reword
			AfterText = "H. Halvard, Licensed Assayer. Sealed by the Authority. Pried open since."},
		adit_shift_chart = {Title = "Shift Chart",
			Text = "A chart nailed by the sluices, the ink run but readable: \"No. 2 sump. To drain: north SHUT, middle OPEN, south SHUT. Never all three open or the gallery floods.\""},
		adit_halvard_desk = {Title = "Halvard's Desk", Evidence = "halvard_notes",
			Text = "A desk buried under assay slips. One notebook is newer than the rest, full of diagrams drawn straight onto rock.",
			AfterText = "Halvard's notes: arrays in the rock itself."},
		adit_ledger = {Title = "Assay Ledger", Evidence = "halvard_ledger", Requires = {Puzzle = "adit_vault"},
			Text = "A ledger on a lectern, its last page dated the month the adit was sealed.",
			AfterText = "\"No. 4 is not ore.\"", Locked = "A ledger behind the vault bars."},
		-- ===== the Lindenmoor expansion's clue markers (Lindenmoor import Task 8, 2026-10-24): RenseiClue parts in
		-- Map.LindenmoorExpansion. PROPOSAL wording; each starts a short quest a townsperson answers (Rensei.Townsfolk Clue) =====
		lm_ridge_marker = {Title = "Ridge Marker", Evidence = "lm_ridge_survey", StartsQuest = "lm_ridge",
			Text = "A standing stone on the knoll, taller than a man, with a cairn of field stones at its foot. A surveyor's arrow is cut into its face, and under it a row of figures. The grooves have been scrubbed clean, and not long ago.",
			AfterText = "The surveyor's arrow, scrubbed clean. Somebody looks after this stone."},
		lm_mine_shaft = {Title = "Boarded Shaft", Evidence = "lm_shaft_ore", StartsQuest = "lm_mine",
			Text = "A shaft under the headframe, planked over and chained shut. Ore lies spilled around the collar where it fell, and the cart rail runs right up to the boards. Whoever closed it didn't stop to tidy up.",
			AfterText = "The boarded shaft, the ore still lying where it fell."},
		-- ===== alchemy acquisition: Ice, Earth, Wind, Metal =====
		ice_floor = {
			Title = "Floor Ice", Evidence = "uneven_ice", Requires = {Quest = {Id = "acq_ice", StageAtLeast = 2}},
			Text = "You kneel and tap the ice. By the door it's a hand thick. By the pipes it's barely a skin. The cold came in from outside and worked its way in.",
			AfterText = "Thick by the door, thin by the pipes.",
			Locked = "Ice over the floor.",
		},
		ice_channels = {
			Title = "Water Channels", Evidence = "frozen_channels", Requires = {Quest = {Id = "acq_ice", StageAtLeast = 2}},
			Text = "The channels are frozen solid - but the drain end froze first. The cold ran backwards along the pipes, against the water.",
			AfterText = "Frozen from the drain end, backwards.",
			Locked = "Frozen water channels.",
		},
		ice_pump = {
			Title = "Pump Housing", Evidence = "frost_cycles", Requires = {Quest = {Id = "acq_ice", StageAtLeast = 2}},
			Text = "Frost rings on the pump housing, layer on layer, like tree rings. It froze, thawed and froze again. Dozens of times.",
			AfterText = "Frost rings: a freeze-thaw cycle.",
			Locked = "A pump housing furred with frost.",
		},
		ice_note = {
			Title = "Researcher's Desk", Evidence = "maren_notes", Requires = {Quest = {Id = "acq_ice", StageAtLeast = 2}},
			Text = "Notes in a careful hand: \"The guardian holds the station's cold. If the cycle stops, it wakes. Do not let the pumps fail.\" Signed M. Ostrova.",
			AfterText = "Maren Ostrova's notes about the guardian.",
			Locked = "A desk under a crust of frost.",
		},
		earth_cracks = {
			Title = "Cracked Footing", Evidence = "stress_cracks", Requires = {Quest = {Id = "acq_earth", StageAtLeast = 2}},
			Text = "The cracks fan out from the middle pier, like the spokes of a wheel. Nearly the whole load was landing on that one support.",
			AfterText = "Cracks fanning out from the middle pier.",
			Locked = "A cracked stone footing.",
		},
		earth_pier = {
			Title = "Middle Pier", Evidence = "hollow_pier", Requires = {Quest = {Id = "acq_earth", StageAtLeast = 2}},
			Text = "You knock on the pier. It rings hollow. Gravel, transmuted into the shape of stone and never compacted. Strong-looking. Weak inside.",
			AfterText = "The hollow, transmuted pier.",
			Locked = "A stone pier.",
		},
		earth_soil = {
			Title = "West Footing", Evidence = "washed_soil", Requires = {Quest = {Id = "acq_earth", StageAtLeast = 2}},
			Text = "The soil under the west footing is gone - washed into a gully. Water has been running under it for months.",
			AfterText = "The washed-out ground under the west footing.",
			Locked = "The west footing of the bridge.",
		},
		earth_note = {
			Title = "Survey Case", Evidence = "survey_report", Requires = {Quest = {Id = "acq_earth", StageAtLeast = 2}},
			Text = "A survey report in a dented case: \"Pier rebuilt by alchemy for speed. Recommend inspection before loading.\" Stamped. Filed. Never read.",
			AfterText = "The ignored survey report.",
			Locked = "A dented document case.",
		},
		wind_flags = {
			Title = "Pennants", Evidence = "still_flags", Requires = {Quest = {Id = "acq_wind", StageAtLeast = 2}},
			Text = "Every pennant hangs dead - except the one by the east vent, which stirs. Air still comes in there, and nowhere else.",
			AfterText = "Only the east pennant moves.",
			Locked = "Pennants hanging from the beams.",
		},
		wind_dust = {
			Title = "Dust on the Floor", Evidence = "dust_lines", Requires = {Quest = {Id = "acq_wind", StageAtLeast = 2}},
			Text = "Dust lies in long streaks, all pointing at the south duct. The air used to leave that way - it carried the dust with it.",
			AfterText = "Dust streaks pointing at the south duct.",
			Locked = "A dusty floor.",
		},
		wind_vents = {
			Title = "Outlet Shutters", Evidence = "closed_vents", Requires = {Quest = {Id = "acq_wind", StageAtLeast = 2}},
			Text = "The outlet shutters are wired shut - from the inside. Someone sealed the exits on purpose.",
			AfterText = "The shutters, wired shut from inside.",
			Locked = "Shuttered outlets.",
		},
		wind_note = {
			Title = "Instrument Desk", Evidence = "pressure_log", Requires = {Quest = {Id = "acq_wind", StageAtLeast = 2}},
			Text = "A pressure log. The readings climb for a week, then a note: \"Sealed the outlets to hold pressure for the experiment. Siv disagrees.\"",
			AfterText = "The pressure log and its last note.",
			Locked = "A desk of instruments.",
		},
		-- Brannoc's notice (Foundry Yard plan, owner decision D): on the post at Ye's Metal TrainerSpot, where he used to
		-- stand. PROPOSAL wording. No Evidence, so Requires gates only the quest: a player who already has a path reads it
		-- and gets no toast.
		brannoc_moved = {Title = "Brannoc's Notice", StartsQuest = "acq_metal", Requires = {NoAffinity = true},
			Text = "A notice nailed to the post where the Metal Alchemist used to stand, in square, careful capitals: \"GONE TO THE FOUNDRY YARD. A FORGE THERE NEEDS LOOKING AT. STUDENTS: TRAIN FROM LINDENMOOR STATION, OR THE NORTH ROAD. - B.\""},
		metal_shaft = {
			Title = "Drive Shaft", Evidence = "sheared_shaft", Requires = {Quest = {Id = "acq_metal", StageAtLeast = StoryLogic.StageIndex(Quests.acq_metal, "fieldwork")}},
			Text = "The drive shaft sheared clean through. The break is bright and grainy: it was too hard and brittle for the load, not too weak.",
			AfterText = "The brittle, sheared shaft.",
			Locked = "A broken drive shaft.",
		},
		metal_samples = {
			Title = "Sample Rack", Evidence = "sample_rack", Requires = {Quest = {Id = "acq_metal", StageAtLeast = StoryLogic.StageIndex(Quests.acq_metal, "fieldwork")}},
			Text = "A rack of material samples, each tagged: strength, flex, heat. The shaft's tag reads \"cast iron - DO NOT USE FOR SHAFTS\", in someone else's hand.",
			AfterText = "The tagged samples. Cast iron, marked not for shafts.",
			Locked = "A rack of metal samples.",
		},
		metal_gear = {
			Title = "Repaired Gear", Evidence = "bad_weld", Requires = {Quest = {Id = "acq_metal", StageAtLeast = StoryLogic.StageIndex(Quests.acq_metal, "fieldwork")}},
			Text = "The gear was soldered back on with soft solder. By the soot around it, the repair held about an hour.",
			AfterText = "The soft-soldered gear.",
			Locked = "A gear on a cold machine.",
		},
		metal_note = {
			Title = "Workshop Desk", Evidence = "experiment_record", Requires = {Quest = {Id = "acq_metal", StageAtLeast = StoryLogic.StageIndex(Quests.acq_metal, "fieldwork")}},
			Text = "A workshop record: \"Plated the subject with cast iron. It moves. It shouldn't.\" Under it, the forge's fire log, cut short.",
			AfterText = "The record of the plated experiment.",
			Locked = "A soot-black desk.",
		},
		-- ===== alchemy acquisition: Flame (the burned laboratory) =====
		flame_scorch = {
			Title = "Scorch Marks", Evidence = "burn_pattern", Requires = {Quest = {Id = "acq_flame", StageAtLeast = 2}},
			Text = "Black scorch fans out from the bench in a circle - then one straight line of it climbs the south wall to the vent, as if the fire ran up a rope.",
			AfterText = "The scorch line, bench to vent.",
			Locked = "Old scorch marks. Somebody's experiment ended badly.",
		},
		flame_vent = {
			Title = "Wall Vent", Evidence = "open_vent", Requires = {Quest = {Id = "acq_flame", StageAtLeast = 2}},
			Text = "The vent shutters are wide open, and they're meant to close. A chisel is still wedged in the hinge to hold them that way.",
			AfterText = "The vent, chiselled open.",
			Locked = "A blackened wall vent.",
		},
		flame_shelf = {
			Title = "Reagent Shelf", Evidence = "flash_powder", Requires = {Quest = {Id = "acq_flame", StageAtLeast = 2}},
			Text = "Burst jars, labels half-melted: FLASH POWDER - KEEP COOL. They sat right above the chamber. The glass blew outward.",
			AfterText = "The flash powder shelf, right above the chamber.",
			Locked = "A shelf of burst glass jars.",
		},
		flame_note = {
			Title = "Apprentice's Desk", Evidence = "corin_log", Requires = {Quest = {Id = "acq_flame", StageAtLeast = 2}},
			Text = "A notebook in a cramped hand: \"Raised the heat again. She says patience. Patience is for Ice students. Tonight I'll show her what the chamber can really do.\" Signed C. Vale.",
			AfterText = "Corin Vale's log. Impatient to the last line.",
			Locked = "A scorched desk with a notebook on it.",
		},
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
		adit_truth = {
			Title = "What Halvard Found",
			Question = "Halvard sealed his own mine. What was he hiding?",
			Requires = {Evidence = {"halvard_notes", "halvard_ledger"}},
			Slots = {
				{Label = "How he worked", Answer = "halvard_notes"},
				{Label = "What he found", Answer = "halvard_ledger"},
			},
			Conclusion = "Halvard wasn't assaying ore. He found an array older than the mine, set in the bedrock, and learned to wake it without a circle. He sealed No. 4 so the Authority couldn't have it.",
			Wrong = "That doesn't explain why he sealed it.",
		},
		station_freeze = {
			Title = "The Frozen Station",
			Question = "What happened to the research station?",
			Requires = {Evidence = {"uneven_ice", "frozen_channels", "frost_cycles"}},
			Slots = {
				{Label = "Where the cold came from", Answer = "uneven_ice"},
				{Label = "How it spread", Answer = "frozen_channels"},
				{Label = "Why it kept happening", Answer = "frost_cycles"},
			},
			Conclusion = "Something outside drove the cold in, back along the pipes, again and again on a cycle. Not a storm. Something keeping the station frozen on purpose.",
			Wrong = "That isn't what the evidence shows. Match each clue to what it actually tells you.",
		},
		bridge_failure = {
			Title = "The Failing Footing",
			Question = "Why is the bridge footing failing?",
			Requires = {Evidence = {"stress_cracks", "hollow_pier", "washed_soil"}},
			Slots = {
				{Label = "Where the load went", Answer = "stress_cracks"},
				{Label = "What gave way", Answer = "hollow_pier"},
				{Label = "What made it worse", Answer = "washed_soil"},
			},
			Conclusion = "The load was all on one pier, the pier was hollow, and the ground under it was washing away. It was never strong - it only looked strong.",
			Wrong = "That isn't what the evidence shows. Match each clue to what it actually tells you.",
		},
		observatory_stall = {
			Title = "The Silent Observatory",
			Question = "Why did the observatory's machines stop?",
			Requires = {Evidence = {"still_flags", "dust_lines", "closed_vents"}},
			Slots = {
				{Label = "Where air still enters", Answer = "still_flags"},
				{Label = "Where it used to leave", Answer = "dust_lines"},
				{Label = "Why it stopped", Answer = "closed_vents"},
			},
			Conclusion = "Air still comes in, but the exits were sealed. With nowhere to go, the pressure stalled every mechanism in the dome.",
			Wrong = "That isn't what the evidence shows. Match each clue to what it actually tells you.",
		},
		forge_failure = {
			Title = "The Silent Forge",
			Question = "Why did the forge's machine fail?",
			Requires = {Evidence = {"sheared_shaft", "sample_rack", "bad_weld"}},
			Slots = {
				{Label = "What broke", Answer = "sheared_shaft"},
				{Label = "Why it broke", Answer = "sample_rack"},
				{Label = "Why the repair failed", Answer = "bad_weld"},
			},
			Conclusion = "The wrong material for the job, then the wrong repair. Strength without understanding, twice over.",
			Wrong = "That isn't what the evidence shows. Match each clue to what it actually tells you.",
		},
		lab_fire_cause = {
			Title = "The Laboratory Fire",
			Question = "Why did a practice reaction become a fire?",
			Requires = {Evidence = {"burn_pattern", "open_vent", "flash_powder"}},
			Slots = {
				{Label = "What fed it", Answer = "open_vent"},
				{Label = "Where it went", Answer = "burn_pattern"},
				{Label = "What made it a disaster", Answer = "flash_powder"},
			},
			Conclusion = "Not too little power - too little judgment. The vent forced air in, the fire followed the air up the wall, and the flash powder he'd shelved above the chamber did the rest.",
			Wrong = "That isn't how the fire behaved. Match each clue to what it actually shows.",
		},
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

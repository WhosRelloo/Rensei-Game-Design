-- In-world UI minigames (MinigameService / MinigameUI). Server-seeded, server-validated, retryable;
-- a failed attempt costs nothing. Numbers are PROPOSALS.
--   PressureBoard: Valves (count), Steps (each valve 0..Steps), Band (width of the green band, 0..1).
--     Each valve adds or bleeds pressure by a hidden weight (one always bleeds); the client sends the
--     valve positions and the server recomputes the gauge.
--   ArrayRestoration: Rings (count), Positions (notches per turn). The rings are geared: turning a ring
--     drags the next ring inward with it. The client sends its moves; the server replays them from
--     the scramble it made and checks every mark lines up.
--   AssayBench: Tests (names), Chips (how many tests one sample allows), Table (reference rows:
--     {Id, Name, [Test] = reaction}), Sample (a fixed row id; nil = a random row each time).
--     The sample stays on the server: each test is asked for ("Act") and the server answers with
--     the reaction, one chip each. The client sends the row id it thinks matches. A wrong guess
--     refills the chips. Every two rows differ in at least two tests, so any three tests name the
--     sample -- keep that true when adding rows.
--   LedgerCipher: Key (the shift; found in the world, never sent by the server), Lines (how many
--     ledger lines), Cargo / Places / Counts (word pools), Marked (the cargo of the struck line).
--     The server writes the page and enciphers it; the client sends the place it decoded.
-- Shared optional fields: Requires (StoryLogic conditions to open it) + Locked (line when not met),
--   Evidence (given on the FIRST pass only).

-- (Foundry Yard plan, Ruling 6) acq_metal's stage numbers come from its stage ids; neither module requires this one
local StoryLogic = require(script.Parent.StoryLogic)
local Quests = require(script.Parent.Quests)

return {
	pressure_board = {
		Kind = "PressureBoard", Title = "VALVE BOARD",
		Valves = 3, Steps = 10, Band = 0.08,
		Hint = "Bring the needle into the green band, then seal the line. One valve bleeds pressure off instead of adding it.",
		Pass = "The line shudders and goes quiet. The vent is sealed for good.",
		Fail = "The needle isn't in the green. The line won't hold.",
	},
	array_restoration = {
		Kind = "ArrayRestoration", Title = "CRACKED SEAL",
		Rings = 3, Positions = 8,
		Hint = "Turn the rings until every mark points at the notch. The rings are geared: a ring drags the next one inward with it.",
		Pass = "The seal's lines meet and flare gold. Somewhere inside, a bolt slides back.",
		Fail = "The marks don't line up. The seal stays dark.",
	},
	assay_chalk = {
		Kind = "AssayBench", Title = "ASSAY BENCH",
		Tests = {"Flame", "Acid", "Magnet", "Water"}, Chips = 3, Sample = "slag_chalk",
		Table = {
			{Id = "clerk_chalk", Name = "Clerk's Chalk", Flame = "None", Acid = "Fizzes", Magnet = "None", Water = "Clouds"},
			{Id = "slag_chalk", Name = "Slag Chalk", Flame = "Orange", Acid = "Fizzes", Magnet = "Pulls", Water = "Sinks"},
			{Id = "iron_ore", Name = "Iron Ore", Flame = "None", Acid = "Smokes", Magnet = "Pulls", Water = "Sinks"},
			{Id = "copper_ore", Name = "Copper Ore", Flame = "Green", Acid = "Smokes", Magnet = "None", Water = "Sinks"},
			{Id = "bone_ash", Name = "Bone Ash", Flame = "White", Acid = "None", Magnet = "None", Water = "Clouds"},
			{Id = "sulphur", Name = "Sulphur", Flame = "Blue", Acid = "None", Magnet = "None", Water = "Floats"},
		},
		Requires = {Evidence = "chalk_sample"},
		Locked = "An assay bench: burner, acid, a lodestone, a water glass. You have nothing to test yet.",
		Evidence = "slag_chalk",
		Hint = "Test the chalk from the wall, then pick the row of the reference table it matches. Each test uses up a chip of the sample.",
		Pass = "It matches: slag chalk. Ground from furnace waste - nobody outside the yard would have it.",
		Fail = "That doesn't match what the sample did. Mirra slides you fresh chips.",
	},
	ledger_cipher = {
		Kind = "LedgerCipher", Title = "SHIPPING LEDGER",
		Key = 5, Lines = 4, Marked = "CHALK",
		Counts = {"TWO", "THREE", "FOUR", "SIX"},
		Cargo = {"COPPER", "COKE", "PIG IRON", "LIME", "BRASS"},
		Places = {"EAST KILN", "ORE ROAD", "SLAG HEAP", "NORTH GATE", "CANAL DOCK", "OLD MILL", "CASTING SHED"},
		Evidence = "voided_ledger",
		Hint = "State Authority shipping lines, written in the clerks' shift cipher. One line is struck out in red wax: decode it and write where that shipment went.",
		Pass = "The struck line reads plain now. Licensed chalk, sent somewhere it was never meant to go.",
		Fail = "That isn't what the struck line says.",
	},
	-- ===== alchemy acquisition (Rensei.AlchemyMinigames kinds; PROPOSALS) =====
	-- Flame, Act III: the trainer's practice chamber in the burned laboratory
	flame_reaction = {
		Kind = "ReactionControl", Title = "REACTION CHAMBER", Turns = 7,
		Hint = "Bring the heat and the air into their green bands, then ignite. Never let the heat reach the red.",
		Pass = "The chamber catches: one clean, steady flame. Exactly as much as you meant.",
		Fail = "The reaction got away from you.",
		LateHint = "Raise heat early while the vent is open; close the vent near the end so the air settles into its band.",
		Empty = "Take at least one turn first.",
		Requires = {Quest = {Id = "acq_flame", Is = "Active", Stage = 3}},
		Locked = "A scorched reaction chamber. Talk to the Flame trainer first.",
	},
	-- Flame, Act V: the trainer's examination (tighter bands, less margin, fewer turns)
	flame_exam = {
		Kind = "ReactionControl", Title = "THE UNBURNED LESSON", Turns = 6, IgnWidth = 8, AirWidth = 12, Margin = 6,
		Hint = "Ignite inside the narrow bands. The red line is the specimen's limit: cross it and the lesson burns.",
		Pass = "The flame stands still on the plate. The specimen beside it isn't even warm.",
		Fail = "Not good enough.",
		LateHint = "Count the turns backwards from the band: you only have six, and every Hold still adds heat.",
		Empty = "Take at least one turn first.",
		Requires = {Quest = {Id = "acq_flame", Is = "Active", Stage = 5}},
		Locked = "The examination plate. Not yet.",
	},
	-- Flame mastery: the daily lesson (TrainingService)
	lesson_flame = {
		Kind = "ReactionControl", Title = "REACTION DRILL", Turns = 6, IgnWidth = 9, AirWidth = 13, Margin = 7,
		Hint = "Again. Narrow bands, little margin. Precision is a habit.",
		Pass = "Clean.", Fail = "Sloppy.", Empty = "Take at least one turn first.",
		Requires = {SavedAffinity = "Flame"},
	},
	-- Ice (PhaseSequence)
	ice_phase = {Kind = "PhaseSequence", Title = "PUMP HOUSING", Pipes = 6, MaxMoves = 6, MinMoves = 3, Slack = 1,
		Hint = "Freeze and thaw the pipes until they match the pattern the pumps need. Never let three freeze side by side.",
		Pass = "The pumps shudder and start to turn. The frost on the casing stops spreading.", Fail = "The pipes are wrong.",
		LateHint = "Work right to left when you freeze (frost runs right), left to right when you thaw (meltwater runs left).",
		Empty = "Make at least one move first.", Requires = {Quest = {Id = "acq_ice", Is = "Active", Stage = 3}}, Locked = "A frozen pump housing. Talk to the Ice trainer first."},
	ice_exam = {Kind = "PhaseSequence", Title = "THE STILLNESS BENEATH", Pipes = 7, MaxMoves = 7, MinMoves = 4, Slack = 0,
		Hint = "Seven pipes, no spare moves. Plan every freeze and thaw before you make it.",
		Pass = "Every pipe holds its phase. The station is still, and stays still.", Fail = "Not yet.",
		LateHint = "Count the moves backwards from the pattern. Each move changes up to two pipes.",
		Empty = "Make at least one move first.", Requires = {Quest = {Id = "acq_ice", Is = "Active", Stage = 5}}, Locked = "Veyra's examination. Not yet."},
	lesson_ice = {Kind = "PhaseSequence", Title = "PHASE DRILL", Pipes = 7, MaxMoves = 7, MinMoves = 4, Slack = 0,
		Hint = "Again, with no margin.", Pass = "Patient.", Fail = "Hasty.", Empty = "Make at least one move first.", Requires = {SavedAffinity = "Ice"}},
	-- Earth (LoadPaths)
	earth_loads = {Kind = "LoadPaths", Title = "SURVEY TABLE", Columns = 7, Span = 2, Supports = 3, SoftCount = 2, Slack = 1,
		Hint = "Place supports under the beam. Read the loads and the ground before you place anything.",
		Pass = "The model beam holds. Every support carries its share, and no more.", Fail = "The beam won't hold like that.",
		LateHint = "Start with the heaviest loads: put a support close to them, on rock. Then cover what's left within reach.",
		Empty = "Place at least one support first.", Requires = {Quest = {Id = "acq_earth", Is = "Active", Stage = 3}}, Locked = "A survey table. Talk to the Earth trainer first."},
	earth_exam = {Kind = "LoadPaths", Title = "THE FOUNDATION TEST", Columns = 8, Span = 2, Supports = 3, SoftCount = 2, Slack = 0,
		Hint = "Eight columns, three supports, and each will carry exactly what it can. No margin.",
		Pass = "The model stands under the full load. Holt doesn't need to say anything.", Fail = "It won't stand.",
		LateHint = "A tie splits a load in half. Sometimes the best place for a support is between two heavy loads.",
		Empty = "Place at least one support first.", Requires = {Quest = {Id = "acq_earth", Is = "Active", Stage = 5}}, Locked = "Holt's examination. Not yet."},
	lesson_earth = {Kind = "LoadPaths", Title = "LOAD DRILL", Columns = 8, Span = 2, Supports = 3, SoftCount = 2, Slack = 0,
		Hint = "Again.", Pass = "Sound.", Fail = "It sags.", Empty = "Place at least one support first.", Requires = {SavedAffinity = "Earth"}},
	-- Wind (PressureRouting)
	wind_routing = {Kind = "PressureRouting", Title = "DUCT MANIFOLD", Depth = 2,
		Hint = "Set the valves so each vent gets exactly the pressure the instruments need.",
		Pass = "Air moves through the dome again. Somewhere above, a chime starts to ring.", Fail = "The vents read wrong.",
		LateHint = "Work from the vents up: a vent that needs nothing tells you which way its valve must NOT point.",
		Requires = {Quest = {Id = "acq_wind", Is = "Active", Stage = 3}}, Locked = "A duct manifold. Talk to the Wind trainer first."},
	wind_exam = {Kind = "PressureRouting", Title = "THE INVISIBLE EQUATION", Depth = 3,
		Hint = "Seven valves, eight vents. Every reading must be exact.",
		Pass = "Every needle settles on its mark. Ansel smiles like he already knew.", Fail = "Not exact.",
		LateHint = "Split twice and a vent gets a quarter. Find the vents that need halves and quarters first.",
		Requires = {Quest = {Id = "acq_wind", Is = "Active", Stage = 5}}, Locked = "Ansel's examination. Not yet."},
	lesson_wind = {Kind = "PressureRouting", Title = "PRESSURE DRILL", Depth = 3,
		Hint = "Again.", Pass = "Exact.", Fail = "Close isn't exact.", Requires = {SavedAffinity = "Wind"}},
	-- Metal (MaterialMatch)
	metal_match = {Kind = "MaterialMatch", Title = "MATERIAL BENCH", Parts = 3, Materials = 5,
		Hint = "Choose a material for each part. Each piece of stock can only be used once.",
		Pass = "The new parts seat with a sound like a lock closing.", Fail = "That part won't hold.",
		LateHint = "Start with the part only one material can meet. The rest follow.",
		Empty = "Choose a material for every part first.", Requires = {Quest = {Id = "acq_metal", Is = "Active", Stage = StoryLogic.StageIndex(Quests.acq_metal, "experiment")}},
		Locked = "A material bench. Talk to the Metal trainer first."},
	metal_exam = {Kind = "MaterialMatch", Title = "THE UNYIELDING PRINCIPLE", Parts = 4, Materials = 6,
		Hint = "Four parts, six materials, no second chances on stock.",
		Pass = "Brannoc turns the finished piece over twice and sets it down without a word. That's the highest praise he has.", Fail = "Wrong stock.",
		LateHint = "A 'at most' requirement rules out more than an 'at least'. Use it to narrow things first.",
		Empty = "Choose a material for every part first.", Requires = {Quest = {Id = "acq_metal", Is = "Active", Stage = StoryLogic.StageIndex(Quests.acq_metal, "exam")}},
		Locked = "Brannoc's examination. Not yet."},
	lesson_metal = {Kind = "MaterialMatch", Title = "MATERIAL DRILL", Parts = 4, Materials = 6,
		Hint = "Again.", Pass = "Acceptable.", Fail = "Wasteful.", Empty = "Choose a material for every part first.", Requires = {SavedAffinity = "Metal"}},
	-- ===== World challenges (MinigameService.WorldChallenges, 2026-10-17) =====
	-- World = true: played in the world (no panel; a small HUD tracker), judged by the server's tick.
	-- Track picks the difficulty tier from the player's matching stat (MinigameService.TierFor):
	-- 1 Initiate, 2 Apprentice, 3 Adept, 4 Expert, 5 Master. Tiers[n] overrides fields for that tier.
	-- Reward = Mastery training through ProgressionService.AddTraining (Source, Mult x the tier's
	-- multiplier), at most PerDay passes a day -- the stage's 20 MP cap and the Truth/Gate still apply.
	-- AllowCombat: being hit doesn't cancel it (Combat Read IS a fight). ALL numbers PROPOSALS.
	combat_read = {
		Kind = "CombatRead", Title = "COMBAT READ", World = true, Track = "Combat", AllowCombat = true,
		Hint = "Stay in Combat Mode (E) and read each attack: block or parry lights, parry or dodge heavies, dodge the unblockable (red flash, no guard can stop it).",
		Pass = "Clean reads. That's what keeps you alive out there.",
		Fail = "You guessed. Read the shoulders, not the fist.",
		Reward = {Source = "Exam", Mult = 0.5, PerDay = 2},
		MaxDrift = 14, -- studs from where it started before it counts as walking away
		-- Pattern pool per tier: Light, Heavy, Feint (a light that stops short -- don't bite), String (two lights
		-- back to back), Unblockable (dodge it). HeavyNeedsParry: a heavy blocked counts as a miss.
		Tiers = {
			{Name = "Initiate", Attacks = 4, Need = 3, Pool = {"Light"}, Gap = {1.8, 2.4}},
			{Name = "Apprentice", Attacks = 5, Need = 4, Pool = {"Light", "Light", "Heavy"}, Gap = {1.6, 2.2}},
			{Name = "Adept", Attacks = 6, Need = 5, Pool = {"Light", "Heavy", "Feint", "String"}, Gap = {1.4, 2.0}, HeavyNeedsParry = true},
			{Name = "Expert", Attacks = 7, Need = 6, Pool = {"Light", "Heavy", "Feint", "String", "Unblockable"}, Gap = {1.2, 1.8}, HeavyNeedsParry = true},
			{Name = "Master", Attacks = 8, Need = 8, Pool = {"Heavy", "Feint", "String", "String", "Unblockable"}, Gap = {1.0, 1.6}, HeavyNeedsParry = true},
		},
	},
	-- Phase 8 (2026-10-17): the village's course over the gorge ledge. Numbers PROPOSAL.
	lindenmoor_run = {
		Kind = "MovementGauntlet", Title = "LINDENMOOR RUN", World = true, Track = "Movement",
		Course = "lindenmoor_run", -- Workspace.World.Map.Lindenmoor.LindenmoorRun
		Hint = "Over the rock ramp, along the cliff ledge, up to the lookout, and back to the bridge.",
		Pass = "The whole valley in one breath.",
		Fail = "The creek's still there tomorrow. Again.",
		Reward = {Source = "Exam", Mult = 0.4, PerDay = 2},
		MaxDistance = 300,
		Tiers = {
			{Name = "Initiate", TimeLimit = 90},
			{Name = "Apprentice", TimeLimit = 80},
			{Name = "Adept", TimeLimit = 70},
			{Name = "Expert", TimeLimit = 80}, -- + wade down the creek
			{Name = "Master", TimeLimit = 70},
		},
	},
	foundation_run = {
		Kind = "MovementGauntlet", Title = "FOUNDATION RUN", World = true, Track = "Movement",
		Course = "foundation_run", -- a Model tagged RenseiGauntlet with attribute GauntletId = this
		Hint = "Touch the markers in order. Some ask for a move: walk the ledge, climb the wall.",
		Pass = "Clean route. Your feet know the yard now.",
		Fail = "Too slow, or you lost the route. Again.",
		Reward = {Source = "Exam", Mult = 0.4, PerDay = 2},
		MaxDistance = 160, -- leaving this far from the start ends the run
		-- TimeLimit per tier; markers with a MinTier attribute only count from that tier up.
		Tiers = {
			{Name = "Initiate", TimeLimit = 70}, -- platform, ledge, finish
			{Name = "Apprentice", TimeLimit = 70}, -- + climb from the ledge
			{Name = "Adept", TimeLimit = 85}, -- + the far ramp and the corner ledge
			{Name = "Expert", TimeLimit = 85}, -- + round the corner onto the upper ledge
			{Name = "Master", TimeLimit = 70}, -- the whole route, tight
		},
	},

	-- ===== Forgotten Sites: Halvard's Adit (Tier I, 2026-10-18; numbers and lines are PROPOSALS) =====
	adit_winch = {
		Kind = "PressureBoard", Title = "LIFT WINCH",
		Valves = 3, Steps = 10, Band = 0.1,
		Hint = "The winch runs on steam from the old boiler. Bring the needle into the green, then engage. One valve vents pressure instead of feeding it.",
		Pass = "The winch shudders, catches, and the cage starts to climb. The lift gate rattles open.",
		Fail = "The needle isn't in the green. The winch won't take the load.",
	},
	adit_assay_ring = {
		Kind = "ArrayRestoration", Title = "ASSAY RING",
		Rings = 3, Positions = 8,
		Hint = "Halvard locked his vault with his own array. Turn the rings until every mark points at the notch. The rings are geared together.",
		Pass = "The rings settle and the array flares. The vault's bolts slide back.",
		Fail = "The marks don't line up. The vault stays shut.",
	},
}

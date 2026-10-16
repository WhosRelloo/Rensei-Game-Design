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
}

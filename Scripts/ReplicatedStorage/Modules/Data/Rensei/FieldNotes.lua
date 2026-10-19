-- Field Notes (2026-10-18): one-time hints the first time a player meets a system the Tutorial can't
-- teach (the Tutorial place covers movement, climbing, combat and alchemy). Shown by Modules.UI.FieldNotesUI;
-- "seen" is saved on the profile (Flow.Hints) through Requests.Hint. PROPOSAL wording.
-- {Key} in a text is filled per input: keyboard key, or the touch wording.

local FieldNotes = {}

FieldNotes.Order = {"Inspect", "Journal", "Mechanism", "Identities", "Site", "Boss", "Mastery"}

FieldNotes.List = {
	Inspect = {Title = "A Closer Look",
		Text = "Things that seem out of place are worth a closer look. {Interact} to inspect them. What you learn goes in your Journal."},
	Journal = {Title = "Your Journal",
		Text = "{Journal} opens it. Evidence keeps every clue and where it came from. The Case Board is where you piece a case together."},
	Mechanism = {Title = "The World Answers",
		Text = "Machines and seals can be worked by hand ({Interact}), and many react to alchemy. Cast at steam, water or cracked stone and see what changes."},
	Identities = {Title = "An Unknown Subject",
		Text = "You don't know their name yet. Note how they fight, dress and transmute: Journal > Identities. Enough to go on, and you can name them. An introduction works too."},
	Site = {Title = "A Forgotten Site",
		Text = "Sealed places like this hold puzzles, guards and a hidden cache. Read what you find: the answer is usually written somewhere nearby."},
	Boss = {Title = "A Real Fight",
		Text = "Its health is at the top of the screen. Watch for its openings, and remember a guard cracks under heavy strikes."},
	Mastery = {Title = "A Mastery Point",
		Text = "You've earned a Mastery Point. {Mastery} opens the Mastery tree to spend it."},
}

FieldNotes.Keys = {
	Keyboard = {Interact = "press E", Journal = "J", Mastery = "K"},
	Touch = {Interact = "tap the prompt", Journal = "The Journal button", Mastery = "The Mastery button"},
}

return FieldNotes

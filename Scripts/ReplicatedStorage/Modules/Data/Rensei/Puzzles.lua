-- Environmental puzzles (PuzzleService). PLACEHOLDER content, owner-approved 2026-10-15 as
-- placeholders: the Foundry Yard. Ownership is PER-PLAYER (owner decision): every player has their
-- own mechanism states, so nobody blocks anyone else. Numbers are PROPOSALS.
--
-- Mechanisms[Id] -- a BasePart / Model tagged "RenseiMechanism" with attribute MechanismId = Id.
--   Kind = "SteamVent" | "Brazier" | "Plate" | "Array" | "Valve" | "Source" | "Bench" (nothing drawn)
--   Default = the starting state
--   Reactions = {[Element] = {State, For = seconds (nil = stays), Text = line shown}}
--       any alchemy cast of that element within Range of it (in front of the caster) triggers it.
--       Element = Flame | Ice | Wind | Earth | Metal. Out of combat, such a cast costs no meter.
--   Refuse = {[Element] = "line"}: a cast that does nothing, with a reason (a clue)
--   Prompt = {Action, Need (carried item attribute), Missing (line), State, Gives (attribute),
--             Minigame (opens one; on a pass the mechanism takes PassState, Permanent)}
--   Stand = {State, For}: a player standing on it holds that state
--   Permanent = true: reaching this state is saved (flag Mech_<Id>) and restored on rejoin
--   Blocks = true (vents): its Blocker child stops the player while the state is Default
--   Hint = the line a curious look gives (the Inspect-style text when there's nothing to do)
-- Puzzles[Id] -- {Title, Mechanisms = {ids}, Solved(States) -> bool, Door (a part tagged
--   "RenseiPuzzleDoor" with PuzzleId opens for that player), OpenText}

return {
	Range = 26, -- studs: how far a cast reaches a mechanism
	NearRange = 9, -- studs: within this, facing doesn't matter

	Mechanisms = {
		yard_vent = {
			Kind = "SteamVent", Title = "Steam Vent", Default = "On", Blocks = true,
			Reactions = {
				Ice = {State = "Frozen", For = 30, Text = "Frost races down the pipe. The vent chokes, hisses, and freezes shut."},
				Wind = {State = "Cleared", For = 15, Text = "The gust tears the steam apart. It won't stay clear for long."},
				Earth = {State = "Capped", For = 30, Text = "Stone heaves up over the vent mouth and holds the steam down."},
				Metal = {State = "Capped", For = 30, Text = "An iron cap folds itself over the vent. The steam thumps against it."},
			},
			Refuse = {Flame = "The steam only roars hotter. Fire won't shut a steam line."},
			Hint = "Scalding steam blocks the way behind the vent. The line runs back to a valve board on the wall.",
		},
		yard_valve = {
			Kind = "Valve", Title = "Valve Board",
			Prompt = {Action = "Work Valves", Minigame = "pressure_board", Target = "yard_vent", PassState = "Sealed"},
		},
		store_furnace = {
			Kind = "Brazier", Title = "Furnace Mouth", Default = "Cold",
			Reactions = {Flame = {State = "Lit", Text = "The furnace mouth catches with a roar."}},
			Refuse = {
				Ice = "Frost on a cold furnace does nothing.", Wind = "You stir ash. There's nothing in it to burn.",
				Earth = "Stone won't burn.", Metal = "Iron won't burn.",
			},
			Prompt = {Action = "Feed Coal", Need = "CarryingCoal", State = "Lit",
				Missing = "The furnace is cold. It needs something to burn - there's coal by the bins."},
		},
		coal_bins = {
			Kind = "Source", Title = "Coal Bins",
			Prompt = {Action = "Take Coal", Gives = "CarryingCoal", Text = "You take a shovel-load of coal."},
		},
		store_plate = {
			Kind = "Plate", Title = "Lock Stone", Default = "Up",
			Stand = {State = "Held", For = 0.6},
			Reactions = {
				Earth = {State = "Held", For = 25, Text = "A pillar of stone settles onto the lock stone and pins it down."},
				Metal = {State = "Held", For = 25, Text = "An iron weight forms on the lock stone and presses it down."},
			},
		},
		store_array = {
			Kind = "Array", Title = "Cracked Seal", Default = "Broken",
			Prompt = {Action = "Restore Seal", Minigame = "array_restoration", Target = "store_array", PassState = "Restored"},
		},
		-- optional side content: minigames that give extra evidence (not part of any puzzle)
		assay_bench = {
			Kind = "Bench", Title = "Assay Bench", Default = "Untested",
			Prompt = {Action = "Test Chalk", Minigame = "assay_chalk", Target = "assay_bench", PassState = "Assayed"},
		},
		yard_ledger = {
			Kind = "Bench", Title = "Shipping Ledger", Default = "Coded",
			Prompt = {Action = "Decode", Minigame = "ledger_cipher", Target = "yard_ledger", PassState = "Decoded"},
		},
	},

	Puzzles = {
		furnace_store = {
			Title = "The Furnace Store",
			Mechanisms = {"store_furnace", "store_plate", "store_array"},
			-- "Fire in the mouth, weight on the stone" -- or mend the old seal
			Solved = function(S)
				return (S.store_furnace == "Lit" and S.store_plate == "Held") or S.store_array == "Restored"
			end,
			OpenText = "Somewhere inside the wall a counterweight drops. The furnace store door grinds open.",
		},
	},
}

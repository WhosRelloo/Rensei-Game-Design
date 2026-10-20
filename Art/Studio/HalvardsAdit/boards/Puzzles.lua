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
--   Kind = "Breakable" (2026-10-20): boards and the like. Default "Whole"; Hits = n melee strikes break it
--       (PuzzleService.Strike: a heavy counts 2), to "Broken", saved; BreakText = the line the breaking strike
--       shows. Its parts named *Plank are drawn by PuzzleClient (collide while Whole, smash when Broken).
--   Party = true: a player's break (alchemy or melee) also breaks it for their party members in this server
-- Puzzles[Id] -- {Title, Mechanisms = {ids}, Solved(States) -> bool, Door (a part tagged
--   "RenseiPuzzleDoor" with PuzzleId opens for that player), OpenText}

return {
	Range = 26, -- studs: how far a cast reaches a mechanism
	NearRange = 9, -- studs: within this, facing doesn't matter

	Mechanisms = {
		ice_pumps = {
			Kind = "Bench", Title = "Pump Housing", Default = "Idle",
			Prompt = {Action = "Work the Pumps", Minigame = "ice_phase", Target = "ice_pumps", PassState = "Running"},
			Hint = "A pump housing furred with frost.",
		},
		earth_table = {
			Kind = "Bench", Title = "Survey Table", Default = "Idle",
			Prompt = {Action = "Brace the Model", Minigame = "earth_loads", Target = "earth_table", PassState = "Braced"},
			Hint = "A survey table with a model of the bridge.",
		},
		wind_manifold = {
			Kind = "Bench", Title = "Duct Manifold", Default = "Idle",
			Prompt = {Action = "Set the Valves", Minigame = "wind_routing", Target = "wind_manifold", PassState = "Flowing"},
			Hint = "A manifold of valves. The ducts behind it are silent.",
		},
		metal_bench = {
			Kind = "Bench", Title = "Material Bench", Default = "Idle",
			Prompt = {Action = "Choose the Stock", Minigame = "metal_match", Target = "metal_bench", PassState = "Fitted"},
			Hint = "A bench of material stock and broken parts.",
		},
		-- ===== alchemy acquisition: Flame (2026-10-16, PROPOSAL) =====
		flame_chamber = {
			Kind = "Bench", Title = "Reaction Chamber", Default = "Scorched",
			Prompt = {Action = "Run the Chamber", Minigame = "flame_reaction", Target = "flame_chamber", PassState = "Steady"},
			Hint = "A scorched reaction chamber. Its dials still turn.",
		},
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
		-- ===== Forgotten Sites: Halvard's Adit (Tier I, 2026-10-18; lines are PROPOSALS) =====
		adit_winch = {
			Kind = "Bench", Title = "Lift Winch", Default = "Jammed",
			Prompt = {Action = "Work the Winch", Minigame = "adit_winch", Target = "adit_winch", PassState = "Running"},
			Hint = "A steam winch, cold for years. The lift cage hangs at the bottom of the shaft.",
		},
		adit_prybar = {
			Kind = "Source", Title = "Tool Rack",
			Prompt = {Action = "Take the Pry Bar", Gives = "CarryingPryBar", Text = "You take a rusted pry bar from the rack."},
		},
		-- the sump: three sluices (the shift chart says which way each goes), or freeze the water and cross
		adit_sluice_n = {Kind = "Valve", Title = "North Sluice", Default = "Open",
			Prompt = {Action = "Turn the Sluice", Toggle = {"Open", "Shut"}, Text = "The north sluice grinds %s."}},
		adit_sluice_m = {Kind = "Valve", Title = "Middle Sluice", Default = "Shut",
			Prompt = {Action = "Turn the Sluice", Toggle = {"Open", "Shut"}, Text = "The middle sluice grinds %s."}},
		adit_sluice_s = {Kind = "Valve", Title = "South Sluice", Default = "Open",
			Prompt = {Action = "Turn the Sluice", Toggle = {"Open", "Shut"}, Text = "The south sluice grinds %s."}},
		adit_sump = {
			Kind = "Source", Title = "Flooded Sump", Default = "Flooded",
			Reactions = {Ice = {State = "Frozen", For = 20, Text = "The sump water locks into ice thick enough to cross."}},
			Refuse = {Flame = "Steam rolls off the water and it settles again.", Wind = "Ripples, nothing more.",
				Earth = "The silt shifts and the water finds its way back.", Metal = "Iron sinks."},
			Hint = "Black water to the knees, then deeper. Something upstream keeps it filling.",
		},
		adit_array = {
			Kind = "Array", Title = "Assay Ring", Default = "Locked",
			Prompt = {Action = "Restore the Array", Minigame = "adit_assay_ring", Target = "adit_array", PassState = "Restored"},
		},
		-- the hidden room: every path's alchemy breaks the wall, or the pry bar from the gallery does
		adit_cracked_wall = {
			Kind = "Plate", Title = "Cracked Wall", Default = "Whole",
			Reactions = {
				Earth = {State = "Broken", Permanent = true, Text = "The seam parts along the cracks and the wall slumps inward."},
				Metal = {State = "Broken", Permanent = true, Text = "Iron wedges drive into the cracks and the wall falls in."},
				Flame = {State = "Broken", Permanent = true, Text = "The heat splits the brittle seam and the wall crumbles."},
				Ice = {State = "Broken", Permanent = true, Text = "Ice swells in the cracks and bursts the wall open."},
				Wind = {State = "Broken", Permanent = true, Text = "A blast drives into the cracks and the loose wall collapses."},
			},
			Prompt = {Action = "Pry It Open", Need = "CarryingPryBar", State = "Broken",
				Missing = "Air whistles through the cracks. You'd need something to lever it with."},
			Hint = "Air moves through these cracks. There's space behind.",
		},
		-- the boarded mouth (owner request 2026-10-20): smash it with fists, any weapon, or any element. Per player,
		-- shared with the party. Hits is a PROPOSAL; the lines are PROPOSALS.
		adit_boards = {
			Kind = "Breakable", Title = "Boarded Mouth", Default = "Whole", Hits = 3, Party = true,
			Reactions = {
				Flame = {State = "Broken", Permanent = true, Text = "The dry planks catch and burst apart."},
				Earth = {State = "Broken", Permanent = true, Text = "A stone fist punches through the boards."},
				Wind = {State = "Broken", Permanent = true, Text = "A blast tears the planks off the frame."},
				Ice = {State = "Broken", Permanent = true, Text = "Ice splits the planks and they shatter."},
				Metal = {State = "Broken", Permanent = true, Text = "Iron spikes rip the boards away."},
			},
			BreakText = "The last plank splinters and the boards cave in.",
			Hint = "Old planks nailed across the mine mouth. They'd give to a few good hits.",
		},
		adit_cache = {
			Kind = "Bench", Title = "Halvard's Strongbox",
			Prompt = {Action = "Open the Strongbox", AfterPuzzle = "adit_hidden",
				Reward = {Money = 60, Exp = 100, Items = {{"Apple", 2}}, Codex = {"The Unlicensed Assayer"}}, Evidence = "adit_visitor_note",
				Text = "Inside: a purse of old coin, two wrapped apples and a folded note.", Empty = "The strongbox is empty."},
		},
	},

	Puzzles = {
		adit_lift = {
			Title = "The Ore Lift", Mechanisms = {"adit_winch"},
			Solved = function(S) return S.adit_winch == "Running" end,
			OpenText = "The lift cage clanks up to the gallery. The way down is open.",
		},
		adit_drain = {
			Title = "The Flooded Sump", Mechanisms = {"adit_sluice_n", "adit_sluice_m", "adit_sluice_s", "adit_sump"},
			-- the shift chart: "to drain: north SHUT, middle OPEN, south SHUT" -- or freeze the water and cross
			Solved = function(S)
				return (S.adit_sluice_n == "Shut" and S.adit_sluice_m == "Open" and S.adit_sluice_s == "Shut") or S.adit_sump == "Frozen"
			end,
			OpenText = "The sump drains with a long gurgle. The way to the laboratory is clear.",
		},
		adit_vault = {
			Title = "Halvard's Vault", Mechanisms = {"adit_array"},
			Solved = function(S) return S.adit_array == "Restored" end,
			OpenText = "The vault door swings open on oiled hinges.",
		},
		adit_hidden = {
			Title = "Behind the Cracked Wall", Mechanisms = {"adit_cracked_wall"},
			Solved = function(S) return S.adit_cracked_wall == "Broken" end,
			OpenText = "The wall gives way. There's a room behind it nobody was meant to find.",
		},
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

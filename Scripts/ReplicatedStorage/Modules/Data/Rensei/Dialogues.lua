-- Dialogue definitions. PROPOSAL content: only the tutorial drillmaster exists so far.
-- An NPC model gets a talk prompt when it carries the attribute DialogueId = "<id>".
-- Schema (DialogueService validates it):
--   [DialogueId] = {
--     Speaker = "State Authority",
--     Start = "start",
--     Nodes = {
--       start = {
--         Text = "...",
--         Choices = {
--           {Text = "\"If it's bandits, deal with them.\"", Next = "nodeId"},          -- Next = nil ends the conversation
--           {Text = "...", Action = {Kind = "StartQuest", Quest = "QuestId"}},
--         },
--       },
--     },
--   }
-- Action kinds: StartQuest, CompleteSignal (fires QuestService.Signal(Player, "Signal", Target)),
--   SetFlag, GiveEvidence, GiveItem, StartMinigame, Deed (records a Rensei.Deeds deed once).
-- Conditions: see StoryLogic (incl. morality: Deed, NotDeed, Standing, Trait, Trust, Renown).
-- Layout: the box fits about 240 characters of Text and 3-4 Choices before rows spill off-screen.
-- Key names below match Controls / Keybinds / CombatModeUI / UIHandler as of 2026-10-14; update
-- them here if a bind changes.

local Dialogues = {}

-- PROPOSAL: Drillmaster Vask, the training-yard instructor beside the practice posts. Teaches the
-- controls in character. No quest, no reward: pure explanation, reachable in any order.
local Back = {Text = "\"Something else.\"", Next = "menu"}
local Leave = {Text = "\"That's enough for now.\""}

Dialogues.tutorial_drillmaster = {
	Speaker = "Drillmaster Vask",
	Start = "start",
	Nodes = {
		start = {
			Text = "Off the ore barge, are you? Stand where I can see your hands. I'm Vask. The Authority pays me to keep "
				.. "new arrivals from dying on their first night shift. Most of them still manage it. Ask your questions.",
			Choices = {
				{Text = "\"How do I fight?\"", Next = "fight"},
				{Text = "\"How do I keep from getting hit?\"", Next = "guard"},
				{Text = "\"How do I get around this place?\"", Next = "move"},
				Leave,
			},
		},
		menu = {
			Text = "Go on. The furnaces don't stoke themselves, and neither does my patience.",
			Choices = {
				{Text = "\"Fighting.\"", Next = "fight"},
				{Text = "\"Defending.\"", Next = "guard"},
				{Text = "\"The streets.\"", Next = "move"},
				Leave,
			},
		},

		-- Combat Mode, light / heavy
		fight = {
			Text = "E puts you in Combat Mode. Out of it, E opens doors and talks to people like me. In it, left click "
				.. "strings your light strikes, and R throws the heavy. The heavy is slow. Don't swing it at a man who's watching you.",
			Choices = {
				{Text = "\"And the right click?\"", Next = "fight2"},
				{Text = "\"What about alchemy?\"", Next = "alchemy"},
				Back,
			},
		},
		fight2 = {
			Text = "Right click is a feint. You pull a light strike before it lands and he flinches at nothing. Ctrl with "
				.. "left click lifts a man off his feet. On a touch screen, the plates on the right do the same work.",
			Choices = {
				{Text = "\"Now teach me to defend.\"", Next = "guard"},
				Back,
			},
		},
		alchemy = {
			Text = "Z, X, C and V, if your hands have taken to a medium. Every circle drinks from your meter, and the meter "
				.. "only fills while you're fighting. Nobody charges up in a quiet corner. Real fights are what fill it.",
			Choices = {
				{Text = "\"Who decides who may draw?\"", Next = "alchemy2"},
				Back,
			},
		},
		alchemy2 = {
			Text = "The State Authority licenses circles. Draw one without a licence and you'll meet people less patient "
				.. "than me. Lately someone's been doing it anyway. Chalk marks on the foundry walls. Not my business. Not yours either.",
			Choices = {Back, Leave},
		},

		-- Block, parry, the practice posts
		guard = {
			Text = "Hold F to block. A guard isn't a wall. Take enough on it and it cracks, and then you're open. The post "
				.. "marked Blocking holds its guard all day. Beat on it until you feel the guard give.",
			Choices = {
				{Text = "\"And parrying?\"", Next = "parry"},
				Back,
			},
		},
		parry = {
			Text = "Tap F. Don't hold it. Time it to the instant the blow arrives and it rings off you. Mistime it and "
				.. "you've dropped your guard for nothing. The Parry post shows you what that costs. So does everyone in the foundry district.",
			Choices = {
				{Text = "\"There's a Perfect Parry post too.\"", Next = "perfect"},
				Back,
			},
		},
		perfect = {
			Text = "Tighter window, smaller margin. Most people quit before they find it. The ones who don't find it "
				.. "tend to get carried home. Practise on the posts. They don't bleed, and they don't hold grudges.",
			Choices = {Back, Leave},
		},

		-- Movement, downed bodies, menus
		move = {
			Text = "Q dashes. Shift runs. Space jumps. Jump at a wall and you'll find you can climb it, or run along it. Out of "
				.. "Combat Mode, Ctrl crouches and slides. The district was built for ore carts, not people. You'll climb a lot.",
			Choices = {
				{Text = "\"What if someone goes down?\"", Next = "downed"},
				{Text = "\"Where do I keep my things?\"", Next = "menus"},
				Back,
			},
		},
		downed = {
			Text = "Stand over them. B takes hold, V carries. Drag them to a medic, or don't. The Authority hasn't "
				.. "written that rule down yet, and I wouldn't trust the man who writes it.",
			Choices = {Back, Leave},
		},
		menus = {
			Text = "The ` key opens your bag. M shows what you're made of: stats, points, the lot. P for everything else. "
				.. "None of them open mid-fight, so sort your kit before the trouble starts, not during.",
			Choices = {Back, Leave},
		},
	},
}

-- ===== Foundry Yard (quest chalk_foundry + bounty) =====
-- PLACEHOLDER content, owner-approved 2026-10-15 as placeholders. New characters: Foreman Brask,
-- Mirra (night smelter), Tobin (stoker, lies until shown evidence), Lise (the apprentice).
local CHALK = "chalk_foundry"
local Leave2 = {Text = "\"I'll be going.\""}

-- Morality (Rensei.Deeds): telling Brask what Tobin / Lise asked you to keep quiet. Each can only
-- happen once, and which deed it records depends on whether you promised.
local TOLD_TOBIN = {"broke_promise_tobin", "told_on_tobin"}
local TellBrask = {
	{Text = "\"Tobin slept through his shift.\"", Next = "told_tobin",
		Requires = {Evidence = "tobin_admission", Deed = "promised_tobin", NotDeed = TOLD_TOBIN},
		Action = {Kind = "Deed", Deed = "broke_promise_tobin"}},
	{Text = "\"Tobin slept through his shift.\"", Next = "told_tobin",
		Requires = {Evidence = "tobin_admission", NotDeed = {"promised_tobin", "broke_promise_tobin", "told_on_tobin"}},
		Action = {Kind = "Deed", Deed = "told_on_tobin"}},
}
local TellLise = {Text = "\"It was Lise. The apprentice.\"", Next = "told_lise",
	Requires = {FlagIs = {Outcome_chalk_foundry = "Secret"}, NotDeed = "betrayed_lise"},
	Action = {Kind = "Deed", Deed = "betrayed_lise"}}
local AskInspectors = {Text = "\"Any word from the Authority's inspectors?\"", Next = "inspectors",
	Requires = {Standing = {Authority = "Trusted"}}, Show = "Locked"}

Dialogues.foundry_brask = {
	Speaker = "Foreman Brask",
	Start = "start",
	Starts = {
		{Requires = {Quest = {Id = CHALK, Is = "Completed"}}, Node = "after"},
		{Requires = {Quest = {Id = CHALK, Is = "Active"}}, Node = "progress"},
	},
	Nodes = {
		start = {
			Text = "You're not one of mine. Doesn't matter. Someone's been drawing circles on my walls at night. Chalk. Real arrays. If the Authority's inspectors see them, they shut the yard and take my licence with it. Find out who. Quietly.",
			Choices = {
				{Text = "\"I'll find out.\"", Action = {Kind = "StartQuest", Quest = CHALK}, Next = "accepted"},
				{Text = "\"What's in it for me?\"", Next = "pay"},
				{Text = "\"Any work for a sword arm?\"", Next = "bounty"},
				Leave2,
			},
		},
		pay = {
			Text = "Wages. And if this goes wrong, I never saw you near my yard.",
			Choices = {
				{Text = "\"Fair. I'll find out.\"", Action = {Kind = "StartQuest", Quest = CHALK}, Next = "accepted"},
				Leave2,
			},
		},
		accepted = {
			Text = "Start with the marks: one on the west wall, one behind the steam vent - that line's leaked for a week - and one by the south wall. Night shift is Mirra at the crucible and Tobin on the furnace. Ask them.",
			Choices = {{Text = "\"On it.\""}},
		},
		bounty = {
			Text = "Bandits on the ore road, north of here. Put five of them down and I'll pay. Bring one here breathing and the Authority pays me for it too - you'll get your cut.",
			Choices = {
				{Text = "\"Count me in.\"", Action = {Kind = "StartQuest", Quest = "bandit_bounty"}},
				Leave2,
			},
		},
		progress = {
			Text = "Well? Found my artist?",
			Alt = {{Requires = {Deduction = "who_drew"}, Text = "You've worked it out. I can see it on you. Deal with it, whatever you decide. I don't want to know the name."}},
			Choices = {
				{Text = "\"Where should I look again?\"", Next = "accepted"},
				TellBrask[1], TellBrask[2],
				{Text = "\"Any work for a sword arm?\"", Next = "bounty"},
				{Text = "\"Not yet.\""},
			},
		},
		told_tobin = {
			Text = "Asleep. On my furnace. With chalk-drawers walking past him. I'll dock him a week. ...You didn't have to tell me that. Noted.",
			Choices = {{Text = "\"Something else.\"", Next = "progress"}, Leave2},
		},
		told_lise = {
			Text = "Lise. I said I didn't want the name, and now I have it. She's off the night shift. Nobody else hears it from me.",
			Choices = {Leave2},
		},
		inspectors = {
			Text = "They asked after you. By name. Seems you're useful to them. Careful: the Authority remembers the useful ones longest.",
			Choices = {Leave2},
		},
		after = {
			Text = "The marks have stopped. That's all I asked.",
			Alt = {
				{Requires = {Deed = "betrayed_lise"}, Text = "Lise keeps to the day shift now. Quiet as a mouse. I haven't said a word to anyone."},
				{Requires = {FlagIs = {Outcome_chalk_foundry = "Report"}}, Text = "The Authority came and went. The yard stays open. I owe you, and I'll pretend I don't know what it cost."},
				{Requires = {FlagIs = {Outcome_chalk_foundry = "Secret"}}, Text = "The marks stopped. Whoever it was, I hope they learned. I won't ask."},
				{Requires = {FlagIs = {Outcome_chalk_foundry = "Teach"}}, Text = "Lise has been sharper on the smelting floor lately. Steadier hands. Don't tell me why."},
			},
			Choices = {
				TellLise, TellBrask[1], TellBrask[2], AskInspectors,
				{Text = "\"Any work for a sword arm?\"", Next = "bounty"},
				Leave2,
			},
		},
	},
}

Dialogues.foundry_mirra = {
	Speaker = "Mirra",
	Start = "start",
	Starts = {{Requires = {Quest = {Id = CHALK, Is = "Active", StageAtLeast = 2}}, Node = "questioned"}},
	Nodes = {
		start = {
			Text = "Crucible's at temperature and I've no time to chat, unless you're carrying ore.",
			Alt = {
				{Requires = {Deed = "reported_lise"}, Text = "You're the one who handed Lise to the inspectors. Crucible's hot. Mind your hands near it."},
				{Requires = {Deed = "taught_lise"}, Text = "Lise's circles close now. Don't look at me like that, I've got eyes. Whatever you're doing, do it carefully."},
			},
			Choices = {Leave2},
		},
		questioned = {
			Text = "The chalk? Two nights back I saw a lamp in the yard, low to the ground. Someone small, or crouching. Thought it was Tobin, but Tobin doesn't move that quiet. Ask him why he didn't see it. He was meant to be stoking.",
			Choices = {
				{Text = "\"Small, you said?\"", Next = "small"},
				{Text = "\"Thanks.\""},
			},
		},
		small = {
			Text = "Small as an apprentice. We've a couple on the smelting floor. Good kids. Don't go making trouble for them over a bit of chalk.",
			Choices = {{Text = "\"I'll be fair.\""}},
		},
	},
}

Dialogues.foundry_tobin = {
	Speaker = "Tobin",
	Start = "start",
	Starts = {
		{Requires = {Evidence = "tobin_admission"}, Node = "after"},
		{Requires = {Quest = {Id = CHALK, Is = "Active", StageAtLeast = 2}}, Node = "deny"},
	},
	Nodes = {
		start = {
			Text = "Furnace eats coal, I feed it. That's the job.",
			Choices = {Leave2},
		},
		-- the lie: two different pieces of evidence break it
		deny = {
			Text = "Chalk? Never saw a thing. I was at this furnace all night, stoking. Ask anyone.",
			Choices = {
				{Text = "\"Then who left small prints right past your furnace?\"", Requires = {Evidence = "small_prints"}, Show = "Locked",
					Action = {Kind = "GiveEvidence", Evidence = "tobin_admission"}, Next = "admit"},
				{Text = "\"Someone drew a whole array behind that vent while you were 'stoking'.\"", Requires = {Evidence = "half_array"}, Show = "Locked",
					Action = {Kind = "GiveEvidence", Evidence = "tobin_admission"}, Next = "admit"},
				{Text = "\"All right.\""},
			},
		},
		admit = {
			Text = "...Fine. I was asleep. Woke near dawn and there was a lamp moving inside the furnace store. The store's sealed. Nobody should be in there. I kept quiet so nobody'd ask why I was asleep. Don't tell Brask.",
			Choices = {
				{Text = "\"Your secret's safe.\"", Action = {Kind = "Deed", Deed = "promised_tobin"}},
				{Text = "\"I'm not promising anything.\""},
			},
		},
		after = {
			Text = "I told you what I saw. Now let me work.",
			Alt = {
				{Requires = {Deed = "broke_promise_tobin"}, Text = "You swore you'd keep quiet. A week's wages, gone. I'll remember whose word that was."},
				{Requires = {Deed = "told_on_tobin"}, Text = "Brask docked me a week. You never promised, I know. Doesn't make it sting less."},
				{Requires = {Trust = {Tobin = 15}}, Text = "You kept your word. Not many do, round here. If you need a furnace lit, it's lit."},
			},
			Choices = {Leave2},
		},
	},
}

local function Decide(Outcome, Question, Said)
	return {
		Text = Question,
		Choices = {
			{Text = "\"Yes. That's my decision.\"", Action = {Kind = "SetFlag", Flag = "Outcome_chalk_foundry", Value = Outcome}, Next = Said},
			{Text = "\"Wait. Let me think again.\"", Next = "confront"},
		},
	}
end

Dialogues.foundry_lise = {
	Speaker = "Lise",
	Start = "start",
	Starts = {
		{Requires = {Deed = "betrayed_lise"}, Node = "after_betrayed"},
		{Requires = {FlagIs = {Outcome_chalk_foundry = "Report"}}, Node = "after_report"},
		{Requires = {FlagIs = {Outcome_chalk_foundry = "Secret"}}, Node = "after_secret"},
		{Requires = {FlagIs = {Outcome_chalk_foundry = "Teach"}}, Node = "after_teach"},
		{Requires = {Quest = {Id = CHALK, Is = "Active", Stage = 6}}, Node = "confront"},
	},
	Nodes = {
		start = {
			Text = "Oh! Sorry. Just sweeping the yard. Somebody has to.",
			Choices = {Leave2},
		},
		confront = {
			Text = "You found my notebook. I only wanted to learn. The Authority won't license a smelting apprentice. They said alchemy isn't for people like us. I never hurt anything. I never even finished a circle.",
			Choices = {
				{Text = "\"The law is the law. I'm reporting you.\"", Next = "confirm_report"},
				{Text = "\"Stop drawing here and I'll keep quiet.\"", Next = "confirm_secret"},
				{Text = "\"Your inner rings are good. I could teach you properly.\"", Next = "confirm_teach"},
			},
		},
		confirm_report = Decide("Report", "[This can't be undone.] Report Lise to the Authority?", "said_report"),
		confirm_secret = Decide("Secret", "[This can't be undone.] Keep Lise's secret?", "said_secret"),
		confirm_teach = Decide("Teach", "[This can't be undone.] Offer to teach Lise?", "said_teach"),
		said_report = {Text = "...I understand. I'll go quietly. Please don't let them break my hands.", Choices = {{Text = "\"...\""}}},
		said_secret = {Text = "Thank you. I'll find somewhere nobody looks. Here, it's not much, but take it.", Choices = {{Text = "\"Be careful.\""}}},
		said_teach = {Text = "You'd really...? Then I'll be the best student you ever had. Nobody sees my circles again until they're perfect.", Choices = {{Text = "\"Tomorrow, then.\""}}},
		after_report = {Text = "The inspectors come for me tomorrow. You did what you thought was right. I hope it was.", Choices = {Leave2}},
		after_secret = {Text = "The walls are clean. I practise where nobody looks now.", Choices = {Leave2}},
		after_teach = {Text = "Look. The outer ring closes now. Every night I practise what you showed me.", Choices = {Leave2}},
		after_betrayed = {Text = "Brask moved me to days. He says he heard it from nobody. I know who nobody is.", Choices = {Leave2}},
	},
}

-- PLACEHOLDER: copy this block for a new NPC. Steps:
--   1. Put the NPC Model in workspace.World.NPCs (any rig with a HumanoidRootPart).
--   2. Give the Model attributes DisplayName = "Name On Prompt" and DialogueId = "<key below>".
--   3. Add an entry here keyed by that DialogueId. DialogueService adds the Talk prompt (E) itself.
Dialogues.placeholder_npc = {
	Speaker = "Placeholder NPC",
	Start = "start",
	Nodes = {
		start = {
			Text = "[Placeholder greeting. Replace with this NPC's opening line. Keep it under about 240 characters.]",
			Choices = {
				{Text = "\"[Option A]\"", Next = "branch_a"},
				{Text = "\"[Option B]\"", Next = "branch_b"},
				-- {Text = "\"[Accept quest]\"", Action = {Kind = "StartQuest", Quest = "QuestId"}},
				{Text = "\"[Leave]\""}, -- no Next: ends the conversation
			},
		},
		branch_a = {
			Text = "[Placeholder reply for Option A.]",
			Choices = {
				{Text = "\"[Back]\"", Next = "start"},
				{Text = "\"[Leave]\""},
			},
		},
		branch_b = {
			Text = "[Placeholder reply for Option B.]",
			Choices = {
				{Text = "\"[Back]\"", Next = "start"},
				{Text = "\"[Leave]\""},
			},
		},
	},
}

return Dialogues

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
--   SetFlag, GiveEvidence, GiveItem, StartMinigame, Deed (records a Rensei.Deeds deed once),
--   UnlockStyle {Style = "Boxing"} (a style trainer teaches a weapon style; requirements re-checked server-side).
-- Choice keys: Requires (greyed out unless met, with Show = "Locked"), ShowIf (hidden unless met).
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
				{Text = "\"Run me through a drill.\" (Combat Read)", Action = {Kind = "StartMinigame", Minigame = "combat_read"}},
				Leave,
			},
		},
		menu = {
			Text = "Go on. The furnaces don't stoke themselves, and neither does my patience.",
			Choices = {
				{Text = "\"Fighting.\"", Next = "fight"},
				{Text = "\"Defending.\"", Next = "guard"},
				{Text = "\"The streets.\"", Next = "move"},
				{Text = "\"A drill.\" (Combat Read)", Action = {Kind = "StartMinigame", Minigame = "combat_read"}},
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

-- PLACEHOLDER (2026-10-16): the five alchemy trainers east of spawn (Workspace.World.NPCs["Alchemy
-- Trainers"]), one per path, each beside a stand with their path's scroll from the Alchemist Assets.
-- Names, nations and lines are placeholders until the owner writes them. Training isn't built: a
-- trainer only describes their path (the move list comes from Rensei.Alchemy, so it stays current).
-- DialogueIds: trainer_flame, trainer_ice, trainer_earth, trainer_wind, trainer_metal.
do
	local Alchemy = require(script.Parent.Alchemy)
	for _, Path in ipairs(Alchemy.Affinities) do
		local Moves = {}
		for _, Move in ipairs(Alchemy.ForAffinity(Path) or {}) do
			table.insert(Moves, type(Move) == "table" and Move.Name or tostring(Move))
		end
		local MoveList = #Moves > 1 and (table.concat(Moves, ", ", 1, #Moves - 1) .. " and " .. Moves[#Moves]) or (Moves[1] or "[moves]")
		Dialogues["trainer_" .. Path:lower()] = {
			Speaker = Path .. " Alchemist",
			Start = "start",
			Nodes = {
				start = {
					Text = ("[Placeholder greeting for the %s trainer. They teach %s alchemy. Replace with their opening line.]"):format(Path, Path),
					Choices = {
						{Text = ("\"What can %s alchemy do?\""):format(Path), Next = "path"},
						{Text = "\"Will you train me?\"", Next = "train"},
						{Text = "\"[Leave]\""},
					},
				},
				path = {
					Text = ("[Placeholder] The %s path: %s."):format(Path, MoveList),
					Choices = {
						{Text = "\"[Back]\"", Next = "start"},
						{Text = "\"[Leave]\""},
					},
				},
				train = {
					Text = "[Placeholder: training isn't built yet. This is where the trainer will teach their path.]",
					Choices = {
						{Text = "\"[Back]\"", Next = "start"},
						{Text = "\"[Leave]\""},
					},
				},
			},
		}
	end
end

-- Flame trainer: Calda (PROPOSAL name and lines). Acquisition questline acq_flame, then mentor practice
-- (TrainingService). Starts are checked top to bottom; the first that passes opens the conversation.
do
	local function At(N) return {Quest = {Id = "acq_flame", Is = "Active", Stage = N}} end
	local Leave = {Text = "\"That's all.\""}
	local Back = {Text = "\"Something else.\"", Next = "menu_back"}
	Dialogues.trainer_flame = {
		Speaker = "Calda, Flame Alchemist",
		Start = "start",
		Starts = {
			{Requires = {SavedAffinity = "Flame"}, Node = "mentor"},
			{Requires = {SavedAffinity = {"Ice", "Earth", "Wind", "Metal"}}, Node = "other"},
			{Requires = At(6), Node = "recognize"},
			{Requires = At(5), Node = "exam"},
			{Requires = At(4), Node = "trial"},
			{Requires = At(3), Node = "experiment"},
			{Requires = At(2), Node = "fieldwork"},
			{Requires = At(1), Node = "sent"},
			{Requires = {Quest = {Id = "acq_ice", Is = "Active"}}, Node = "busy"},
			{Requires = {Quest = {Id = "acq_earth", Is = "Active"}}, Node = "busy"},
			{Requires = {Quest = {Id = "acq_wind", Is = "Active"}}, Node = "busy"},
			{Requires = {Quest = {Id = "acq_metal", Is = "Active"}}, Node = "busy"},
		},
		Nodes = {
			-- Act I: the invitation
			start = {
				Text = "You want fire. Everyone who comes to me wants fire. [She snaps; a flame blooms in her palm and stops dead a finger's width from the paper beside it.] That stop is the lesson. Most never learn it.",
				Choices = {
					{Text = "\"Teach me.\"", Next = "demo"},
					{Text = "\"Who are you?\"", Next = "who"},
					Leave,
				},
			},
			who = {
				Text = "Calda. State-licensed, Flame. I teach control, not spectacle. If you want spectacle, go watch a festival.",
				Choices = {{Text = "\"Teach me, then.\"", Next = "demo"}, Leave},
			},
			demo = {
				Text = "Then learn what happens without it. My last apprentice burned out the laboratory east of here. Go and tell me why it burned. And don't tell me 'too much fire'.",
				Choices = {
					{Text = "\"I'll find out.\"", Action = {Kind = "StartQuest", Quest = "acq_flame"}, Requires = {NoAffinity = true}, Show = "Locked"},
					{Text = "\"Not yet.\""},
				},
			},
			sent = {
				Text = "The laboratory is east of here, past the wall. Look at it the way you'd look at evidence, not a ruin.",
				Choices = {Leave},
			},
			-- Act II: fieldwork
			fieldwork = {
				Text = "Well? What burned it?",
				Alt = {{Requires = {Evidence = {"burn_pattern", "open_vent", "flash_powder"}}, Text = "You've seen it all. Now put it together - on your Case Board, not in my ear. What fed it, where it went, what made it a disaster."}},
				Choices = {
					{Text = "\"Where do I start?\"", Next = "hint_field"},
					{Text = "\"I found Corin's log.\"", Next = "corin", Requires = {Evidence = "corin_log"}},
					Leave,
				},
			},
			hint_field = {
				Text = "Fire leaves a record. Where it began, where it went, and what it found on the way. Read the floor, the wall, the shelf.",
				Choices = {{Text = "\"Something else.\"", Next = "fieldwork"}, Leave},
			},
			corin = {
				Text = "\"Patience is for Ice students.\" [A long breath.] He understood every word I ever said to him, and not one thing it meant.",
				Choices = {{Text = "\"Something else.\"", Next = "fieldwork"}, Leave},
			},
			-- Act III: experimentation
			experiment = {
				Text = "So you know why it burned. Now prove you can keep it from burning. The lab's chamber still works. Bring it to one clean flame.",
				Choices = {{Text = "\"Any advice?\"", Next = "hint_chamber"}, Leave},
			},
			hint_chamber = {
				Text = "Heat climbs on its own, even when you hold. Air is what you truly control. Close the vent too late and it flares; too early and it chokes.",
				Choices = {Leave},
			},
			-- Act IV: the trial
			trial = {
				Text = "Corin came back. He's in the ash pit south of the lab, burning anything that moves. He's strong. He's also reckless.",
				Choices = {{Text = "\"How do I beat him?\"", Next = "hint_trial"}, Leave},
			},
			hint_trial = {
				Text = "Don't trade blows while he's composed - he'll catch you. Every blaze costs him; that's your opening. And fire doesn't care whose it is.",
				Choices = {Leave},
			},
			-- Act V: the examination and recognition
			exam = {
				Text = "Corin's done, then. [She looks at you a long moment.] My plate, then. Light the reaction and keep the specimen whole. I'll be watching the specimen, not the flame.",
				Choices = {
					{Text = "\"I'm ready for the examination.\"", Action = {Kind = "StartMinigame", Minigame = "flame_exam"}},
					{Text = "\"Why the specimen?\"", Next = "hint_exam"},
					Leave,
				},
			},
			hint_exam = {
				Text = "Because anyone can make fire. The question is what you didn't burn. Narrow bands, little margin. Count your turns.",
				Choices = {Leave},
			},
			recognize = {
				Text = "The specimen isn't even warm. [She nods once.] You understood it. Fire is a decision, not a feeling. From today, you're mine to teach.",
				Choices = {{Text = "\"I'm ready.\"", Action = {Kind = "Signal", Target = "acq_flame_recognized"}}},
			},
			-- after acquisition: the mentor (TrainingService)
			mentor = {
				Text = "Student. What will it be?",
				Choices = {
					{Text = "\"A lesson.\" (Reaction Drill, once a day)", Action = {Kind = "Lesson", Lesson = "flame_lesson"}},
					{Text = "\"Breath control.\" (Exercise)", Action = {Kind = "Exercise", Exercise = "flame_exercise"}},
					{Text = "\"The research.\"", Next = "archive"},
					{Text = "\"How far can you take me?\"", Next = "gate"},
					Leave,
				},
			},
			menu_back = {Text = "What else?", Choices = {{Text = "\"Back.\"", Next = "mentor"}, Leave}},
			archive = {
				Text = "You left that laboratory with only what you needed. Some students go back for the rest.",
				Alt = {{Requires = {Evidence = "corin_log"}, Text = "Corin's log is still on my desk. Read it whenever you feel impatient. It's the best lesson he ever gave anyone."}},
				Choices = {Back},
			},
			gate = {
				Text = "Until you've faced the Gate, your mastery has a ceiling. I can sharpen you right up to it. I can't open it for you.",
				Choices = {Back},
			},
			other = {
				Text = "You already walk another path. I don't take students who are halfway out the door. [Almost a smile.] You're welcome to listen, though.",
				Choices = {{Text = "\"Tell me about fire.\"", Next = "who"}, Leave},
			},
			busy = {
				Text = "You're halfway through another master's teaching. Finish what you started. Then we'll see.",
				Choices = {Leave},
			},
		},
	}
end

-- Ice, Earth, Wind and Metal trainers (PROPOSAL names and lines): the same structure as Calda's above
-- (acquisition questline acq_<path>, then mentor practice), each with its own voice and content.
do
	local function Trainer(T)
		local Q = "acq_" .. T.Id
		local function At(N) return {Quest = {Id = Q, Is = "Active", Stage = N}} end
		local Leave = {Text = T.Leave or "\"That's all.\""}
		local Back = {Text = "\"Something else.\"", Next = "menu_back"}
		local Others = {}
		for _, P in ipairs({"Flame", "Ice", "Earth", "Wind", "Metal"}) do if P ~= T.Path then table.insert(Others, P) end end
		local Starts = {
			{Requires = {SavedAffinity = T.Path}, Node = "mentor"},
			{Requires = {SavedAffinity = Others}, Node = "other"},
			{Requires = At(6), Node = "recognize"}, {Requires = At(5), Node = "exam"}, {Requires = At(4), Node = "trial"},
			{Requires = At(3), Node = "experiment"}, {Requires = At(2), Node = "fieldwork"}, {Requires = At(1), Node = "sent"},
		}
		for _, P in ipairs({"flame", "ice", "earth", "wind", "metal"}) do
			if P ~= T.Id then table.insert(Starts, {Requires = {Quest = {Id = "acq_" .. P, Is = "Active"}}, Node = "busy"}) end
		end
		local L = T.Lines
		Dialogues["trainer_" .. T.Id] = {
			Speaker = T.Speaker, Start = "start", Starts = Starts,
			Nodes = {
				start = {Text = L.start, Choices = {{Text = "\"Teach me.\"", Next = "demo"}, {Text = "\"Who are you?\"", Next = "who"}, Leave}},
				who = {Text = L.who, Choices = {{Text = "\"Teach me, then.\"", Next = "demo"}, Leave}},
				demo = {Text = L.demo, Choices = {
					{Text = "\"I'll go.\"", Action = {Kind = "StartQuest", Quest = Q}, Requires = {NoAffinity = true}, Show = "Locked"},
					{Text = "\"Not yet.\""},
				}},
				sent = {Text = L.sent, Choices = {Leave}},
				fieldwork = {Text = L.fieldwork, Alt = {{Requires = {Evidence = T.Clues}, Text = L.fieldwork_all}},
					Choices = {{Text = "\"Where do I start?\"", Next = "hint_field"}, {Text = L.note_ask, Next = "note", Requires = {Evidence = T.Note}}, Leave}},
				hint_field = {Text = L.hint_field, Choices = {{Text = "\"Something else.\"", Next = "fieldwork"}, Leave}},
				note = {Text = L.note, Choices = {{Text = "\"Something else.\"", Next = "fieldwork"}, Leave}},
				experiment = {Text = L.experiment, Choices = {{Text = "\"Any advice?\"", Next = "hint_experiment"}, Leave}},
				hint_experiment = {Text = L.hint_experiment, Choices = {Leave}},
				trial = {Text = L.trial, Choices = {{Text = "\"How do I win?\"", Next = "hint_trial"}, Leave}},
				hint_trial = {Text = L.hint_trial, Choices = {Leave}},
				exam = {Text = L.exam, Choices = {
					{Text = "\"I'm ready for the examination.\"", Action = {Kind = "StartMinigame", Minigame = T.Exam}},
					{Text = "\"What are you looking for?\"", Next = "hint_exam"}, Leave}},
				hint_exam = {Text = L.hint_exam, Choices = {Leave}},
				recognize = {Text = L.recognize, Choices = {{Text = "\"I'm ready.\"", Action = {Kind = "Signal", Target = Q .. "_recognized"}}}},
				mentor = {Text = L.mentor, Choices = {
					{Text = ("\"A lesson.\" (%s, once a day)"):format(T.LessonTitle), Action = {Kind = "Lesson", Lesson = T.Id .. "_lesson"}},
					{Text = ("\"%s.\" (Exercise)"):format(T.ExerciseTitle), Action = {Kind = "Exercise", Exercise = T.Id .. "_exercise"}},
					{Text = "\"The research.\"", Next = "archive"},
					{Text = "\"How far can you take me?\"", Next = "gate"},
					Leave}},
				menu_back = {Text = "What else?", Choices = {{Text = "\"Back.\"", Next = "mentor"}, Leave}},
				archive = {Text = L.archive, Alt = {{Requires = {Evidence = T.Note}, Text = L.archive_note}}, Choices = {Back}},
				gate = {Text = L.gate, Choices = {Back}},
				other = {Text = L.other, Choices = {{Text = "\"Tell me about your path.\"", Next = "who"}, Leave}},
				busy = {Text = L.busy, Choices = {Leave}},
			},
		}
	end

	Trainer({Id = "ice", Path = "Ice", Speaker = "Veyra, Ice Alchemist", Exam = "ice_exam", LessonTitle = "Phase Drill", ExerciseTitle = "Stillness",
		Clues = {"uneven_ice", "frozen_channels", "frost_cycles"}, Note = "maren_notes", Lines = {
		start = "[She doesn't look up from the frost she's tracing on the stone.] You came quietly. Good. Most people arrive talking.",
		who = "Veyra. Ice. I study what holds still, and why. Things that look frozen rarely are.",
		demo = "A colleague of mine, Maren, ran a research station west of here. It froze, and she hasn't come back. Go and look. Don't touch anything until you understand it.",
		sent = "The station is west, past the hill. Look before you act. Then look again.",
		fieldwork = "What have you seen?",
		fieldwork_all = "You've seen enough to answer. Put it together on your Case Board. Where did the cold come from, how did it move, and why didn't it stop?",
		hint_field = "Ice remembers. Read where it's thick and where it's thin, which way the water froze, and how many times.",
		note_ask = "\"I found Maren's notes.\"",
		note = "[A long silence.] Then she knew the guardian was there, and stayed anyway. That was Maren.",
		experiment = "The station's pumps hold the cold in balance. Restore them. Ice spreads; meltwater runs back. Learn which way before you try.",
		hint_experiment = "Freezing a pipe frosts the one after it. Thawing one melts the one before. Three frozen together will crack. Plan, then act.",
		trial = "The guardian Maren wrote of is awake, in the frozen chamber south of the station. It isn't evil. It's doing its work too well.",
		hint_trial = "Its shell turns your blows. Watch it: after it sheds frost, the shell cracks. That is when you strike. Not before.",
		exam = "[She sets seven glass pipes on the stone.] The same principle, with no room for error. I'll be watching how long you wait before your first move.",
		hint_exam = "Patience. Count the moves backwards from what you need, and the answer usually shows itself.",
		recognize = "You waited. You looked. Then you acted, once, correctly. [She almost smiles.] Stillness is not the absence of motion. It's the absence of waste.",
		mentor = "Sit. What do you want to practise?",
		archive = "You found what you needed at the station, and no more. Some students go back.",
		archive_note = "Maren's notes are with me now. Read them when you're tempted to rush. She didn't, and she still lost.",
		gate = "I can teach you to be still. I can't teach you what the Gate wants. That, you face alone.",
		other = "You already practise another discipline. [She turns back to her frost.] You may watch. Watching is never wasted.",
		busy = "You're learning from someone else. Finish it. Half an education is worse than none.",
	}})

	Trainer({Id = "earth", Path = "Earth", Speaker = "Holt, Earth Alchemist", Exam = "earth_exam", LessonTitle = "Load Drill", ExerciseTitle = "Groundwork",
		Clues = {"stress_cracks", "hollow_pier", "washed_soil"}, Note = "survey_report", Lines = {
		start = "[He's crouched, palm flat on the ground.] Feel that? No. Nobody does, first time. That's the problem with most Earth students: they want to move it before they've felt it.",
		who = "Holt. Earth. I build things that stay up. That's less glamorous than it sounds and more important.",
		demo = "There's a footbridge north-west of here the village needs. It's cracking. Go and find out why - and don't you dare try to fix it first.",
		sent = "The footbridge is north-west, over the dry ditch. Look at what's holding it up, not at what's falling.",
		fieldwork = "Well. Why's it failing?",
		fieldwork_all = "You've got the pieces. Lay them out on your Case Board. Where did the weight go, what gave, and what made it worse?",
		hint_field = "Cracks point at the cause. A pier that rings hollow is lying to you. And always look at what's under the footing.",
		note_ask = "\"There was a survey report.\"",
		note = "\"Recommend inspection.\" [He laughs without humor.] Somebody wrote the right answer and nobody read it. That's how most bridges fall.",
		experiment = "Now show me where the supports should go. Use the survey table. Read the loads. Read the ground. Then place.",
		hint_experiment = "Every load goes to its nearest support. Soft ground takes nothing. Start with the heaviest loads and work out.",
		trial = "Someone's tearing up the quarry west of the bridge. Dask. Used to work for me. He thinks strength is the same as understanding.",
		hint_trial = "He'll break the ground under you. Watch for the ring. Stand close to him or well away - the band between is where it breaks. After every tremor he's rooted. That's your moment.",
		exam = "[He sets out a heavier model.] Same idea. Less room. I want every support carrying exactly what it can and not an ounce more.",
		hint_exam = "A tie splits a load. Sometimes the right place for a support is between two heavy loads, not under one.",
		recognize = "It held. [He pushes on the model. It doesn't move.] You understood it before you changed it. That's the whole discipline.",
		mentor = "What'll it be?",
		archive = "You read that bridge well enough. There's more out there, if you look.",
		archive_note = "That survey report's pinned over my bench now. Reminds me to read what's in front of me.",
		gate = "I can make you solid. The Gate's another matter. It weighs you differently.",
		other = "You've already got a discipline. I won't split your foundations. [He shrugs.] But stick around, if you like.",
		busy = "You're halfway through someone else's teaching. Finish that first. Half a foundation's worse than none.",
	}})

	Trainer({Id = "wind", Path = "Wind", Speaker = "Ansel, Wind Alchemist", Exam = "wind_exam", LessonTitle = "Pressure Drill", ExerciseTitle = "Core Hold",
		Clues = {"still_flags", "dust_lines", "closed_vents"}, Note = "pressure_log", Lines = {
		start = "Can you see the wind? [He waits.] No? Then how do you know it's there? [He waits again.] That's the first lesson. You'll find the rest yourself.",
		who = "Ansel. Wind. I teach people to see what can't be seen, by what it leaves behind.",
		demo = "There's an observatory north-east of here. Its machines stopped. I know why. Do you? Go and find out. I'm not going to tell you.",
		sent = "The observatory's north-east. Don't look for the wind. Look for what it moved.",
		fieldwork = "And? What did the air tell you?",
		fieldwork_all = "You've read it. Now say it - on your Case Board. Where does the air come in, where did it leave, and why did it stop leaving?",
		hint_field = "What still moves? What's lying in lines? What was closed that should be open? Those are three questions, not one.",
		note_ask = "\"There's a pressure log.\"",
		note = "\"Siv disagrees.\" [He smiles faintly.] She did. Loudly. She was right, and it didn't help her.",
		experiment = "Now route it. The manifold still works. Every vent needs exactly the pressure it needs. What does a valve do to the vents below it?",
		hint_experiment = "A valve sends everything left, everything right, or splits it. Start at the vents that need nothing. What does that tell you?",
		trial = "Siv's on the gale floor east of the observatory. She thinks I'm wrong about everything. Go and prove her wrong about you.",
		hint_trial = "The lanes show where the gusts will run. Step across a lane, never along it. After every gust, she's catching her breath.",
		exam = "[He hands you a wider schematic.] Seven valves. Eight vents. Every reading exact. Why exact? You tell me.",
		hint_exam = "Split twice and a vent gets a quarter. Which vents need quarters? Start there.",
		recognize = "You didn't guess once. [He nods slowly.] You can't see it. You don't need to. That's Wind.",
		mentor = "Well? What are we testing today?",
		archive = "You found what you needed at the observatory. Did you find everything? Hm.",
		archive_note = "Siv's pressure log. I keep it. Every number in it is a question someone didn't ask in time.",
		gate = "How far can I take you? Up to the Gate. What's past it? [He smiles.] Good question. Keep it.",
		other = "You already walk another path. Why would you want mine too? [A pause.] That's a real question, by the way.",
		busy = "You're studying with someone else. Finish. Then come back and tell me what you learned. I'll ask questions.",
	}})

	Trainer({Id = "metal", Path = "Metal", Speaker = "Brannoc, Metal Alchemist", Exam = "metal_exam", LessonTitle = "Material Drill", ExerciseTitle = "Forge Cadence",
		Clues = {"sheared_shaft", "sample_rack", "bad_weld"}, Note = "experiment_record", Lines = {
		start = "[He doesn't stop filing.] Strength is cheap. Precision isn't. If you came for strength, the Foundry's hiring.",
		who = "Brannoc. Metal. I shape what others break. I don't waste stock, and I don't waste words.",
		demo = "There's a forge east of the Foundry Yard. Went cold mid-shift. Find out why. Touch nothing until you can tell me what failed and why.",
		sent = "East of the Foundry Yard. Look at the break, the stock and the repair. In that order.",
		fieldwork = "Report.",
		fieldwork_all = "You've seen it all. Write it up on your Case Board. What broke, why, and why the repair failed.",
		hint_field = "A break tells you how it failed. The stock tells you why. A bad repair tells you who was in a hurry.",
		note_ask = "\"There was a workshop record.\"",
		note = "\"It moves. It shouldn't.\" [He sets the file down for the first time.] No. It shouldn't.",
		experiment = "New parts. The bench has stock. Choose right. One piece of each. No second tries on material.",
		hint_experiment = "Find the part only one material can satisfy. Start there. The rest follows.",
		trial = "The experiment from that record is on the forge floor east of the workshop. Armored. Don't hit the armor. Hit the joints.",
		hint_trial = "Its plating turns your blows. After every cleave it vents and the joints open - they glow. Strike then. Stand off the marked lines.",
		exam = "[He sets out six bars of stock and four drawings.] Same principle. More parts. Same rule: no waste.",
		hint_exam = "An 'at most' rules out more than an 'at least'. Use it.",
		recognize = "[He turns the piece over twice, then sets it down.] Acceptable. [A pause.] From me, that means good. You'll do.",
		mentor = "Work.",
		archive = "You found what you needed. Thoroughness would have found more.",
		archive_note = "The workshop record's in my drawer. I read it when I'm tempted to cut corners.",
		gate = "I can make you precise. The Gate isn't a material. I can't shape it for you.",
		other = "You already have a discipline. I don't take half-students. [He goes back to filing.]",
		busy = "You're mid-way through someone else's teaching. Finish the job.",
	}})
end

-- ===== Style trainers (owner 2026-10-18: styles are learned only from a style trainer + requirements) =====
-- PROPOSAL characters and lines. The requirements live in Rensei.Styles (Unlock); the "Teach me" choice is
-- greyed out with them until met (StyleReady), hidden once learned (ShowIf NotStyleUnlocked).
local function StyleTrainer(Speaker, Style, Lines)
	return {
		Speaker = Speaker,
		Start = "start",
		Nodes = {
			start = {
				Text = Lines.Start,
				Alt = {{Requires = {StyleUnlocked = Style}, Text = Lines.Known}},
				Choices = {
					{Text = Lines.Ask, Requires = {StyleReady = Style}, ShowIf = {NotStyleUnlocked = Style}, Show = "Locked",
						Action = {Kind = "UnlockStyle", Style = Style}, Next = "learned"},
					{Text = "\"What does it take?\"", ShowIf = {NotStyleUnlocked = Style}, Next = "needs"},
					{Text = "\"Tell me about the style.\"", Next = "about"},
					{Text = "\"That's all.\""},
				},
			},
			needs = {Text = Lines.Needs, Choices = {{Text = "\"Something else.\"", Next = "start"}, {Text = "\"I'll be back.\""}}},
			about = {Text = Lines.About, Choices = {{Text = "\"Something else.\"", Next = "start"}, {Text = "\"That's all.\""}}},
			learned = {Text = Lines.Learned, Choices = {{Text = "\"Thank you.\""}}},
		},
	}
end

Dialogues.style_boxing = StyleTrainer("Coach Harlan", "Boxing", {
	Start = "Chin down, hands up. I'm Harlan. I've taught half the farmhands in this valley to throw a straight punch. "
		.. "Most of them still can't.",
	Known = "Hands up. You know the work now. The rest is miles.",
	Ask = "\"Teach me Boxing.\"",
	Needs = "Feet before fists. Come back at level 4 with your Speed at 4, and I'll put you through the work.",
	About = "Pressure. Jab, jab, cross, and keep them in front of you. When they cover up, the peek-a-boo walks straight "
		.. "through. Your hits are lighter, so don't stop throwing them.",
	Learned = "That's the base. Keep the elbows in and your feet moving. Pick it when you train (Mastery, Class tab).",
})

Dialogues.style_lethwei = StyleTrainer("Master Thura", "Lethwei", {
	Start = "Where I was born, we fight with nine limbs: fists, elbows, knees, feet and the head. "
		.. "Here they call it brawling. I am Thura.",
	Known = "Your elbows remember. Good. Hard ground makes hard bones.",
	Ask = "\"Teach me Lethwei.\"",
	Needs = "Strength. Your arms must not break before their guard does. Level 6, Strength 5. Then come back.",
	About = "Short strikes, close. Break the guard, then put them down. If you miss, you are open. So don't miss.",
	Learned = "Now you have the shape of it. The rest you learn by being hit. Choose it when you train (Mastery, Class tab).",
})

return Dialogues

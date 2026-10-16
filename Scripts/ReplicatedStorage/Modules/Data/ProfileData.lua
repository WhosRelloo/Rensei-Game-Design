-- Rensei profile template. ProfileService:Reconcile() fills any key missing from a saved
-- profile; anything that needs converting goes through DataManager's Migrate step and
-- SchemaVersion. Bump SchemaVersion and add a migration step for every breaking change.
return {
	SchemaVersion = 4, -- 2: SkillTree (was AlchemyTree) + Mastery.StageSpend; 3: Story + quest stages; 4: Morality

	Level = 1,
	Exp = 0, -- progress inside the current level
	LifetimeExp = 0, -- never decreases; the Truth/Gate requirement reads this

	Stats = {
		Strength = 1,
		Intelligence = 1,
		Speed = 1,
		Vitality = 1,
		Alchemy = 1,
	},
	StatPoints = 0,

	Mastery = {
		Stage = 1, -- Truth/Gate stage; each stage holds 20 MP
		StageEarned = 0, -- MP earned in the current stage (0..20)
		Unspent = 0,
		Spent = 0,
		LifetimeEarned = 0,
		Progress = 0, -- training progress toward the next MP
		StageSpend = {}, -- [NodeId] = ranks bought this stage (refundable until the trial seals it)
		Windows = {}, -- [Source] = {Start = os.time(), Amount = TP}
	},

	Gate = {
		TrialsPassed = 0,
		PendingTrial = 0, -- stage number of a trial that has been started, 0 = none
		History = {},
	},

	Identity = { -- set once by character creation (Requests.CreateCharacter, Rensei.Customization)
		CharacterCreated = false,
		Origin = "", -- nation id (cosmetic)
		FirstName = "",
		LastName = "", -- the clan's surname (Rensei.Clans; rolled in character creation)
		Name = "", -- full character name (first [+ surname])
		Gender = "", -- "Male" | "Female" (Customization.Genders; pronouns for story text)
		Clan = "",
		FreeClanRollUsed = false,
		PaidClanRolls = 0,
		ClanPity = 0, -- +1 per roll; Rare+ resets it (Clans.Roll)
		MythicBonus = 0, -- hidden soft pity: +0.2% per Legendary roll; a Mythic resets it
		Affinity = "",
		Weapon = "", -- the starting-weapon choice ("" = fists)
		Appearance = {}, -- Customization.Clean shape: Skin, Hair, HairColor, Eyes, Brows, Mouth, Outfit
	},

	-- Start flow (owner 2026-10-14): Main Menu -> Customize (Character Customization place) ->
	-- Tutorial place -> cutscene -> Ye. Set by the place that finishes each step.
	Flow = {
		TutorialDone = false,
		IntroSeen = false, -- the post-tutorial cutscene
	},

	SkillTree = {}, -- [NodeId] = rank (Modules.Data.Rensei.SkillTree)

	Money = 0,
	Settings = {}, -- validated by Requests.Settings; defaults in Rensei.Settings
	Quests = {
		Active = {}, -- [QuestId] = {Stage = n, Progress = {[ObjectiveId] = n}, Started = os.time()}
		Completed = {}, -- [QuestId] = os.time()
		Tracked = "", -- the quest the HUD shows first ("" = oldest)
	},
	-- Story state (schema 3; QuestService / StoryService / InvestigationService / PuzzleService):
	Story = {
		Flags = {}, -- [FlagId] = value: choices and world states (Outcome_<QuestId> = the ending picked)
		Evidence = {}, -- [EvidenceId] = os.time() (Rensei.Evidence)
		Deductions = {}, -- [DeductionId] = os.time() (Rensei.Investigation.Deductions)
		Puzzles = {}, -- [PuzzleId] = os.time() solved (per-player puzzles, Rensei.Puzzles)
		Minigames = {}, -- [MinigameId] = {Passed = os.time(), Tries = n} (Rensei.Minigames)
	},
	-- Morality (schema 4; MoralityService is the only writer). Deeds is the ledger and the source of
	-- truth; the other tracks are caches rebuilt from it on every load (raw sums, read clamped).
	Morality = {
		Deeds = {}, -- [DeedId] = {At, Last, Count (applied), Seen, Day, DayCount, Known}
		Conduct = {}, -- [Axis] = sum (Mercy / Candor / Order)
		Standing = {}, -- [FactionId] = sum
		Trust = {}, -- [NpcName] = sum
		Renown = 0,
		Taboo = {}, -- reserved (owner canon pending)
	},
	Codex = {}, -- [EntryId] = os.time()
	Areas = {}, -- [AreaName] = os.time()

	Inventory = {
		{
			ItemName = "Katana",
			ItemID = "00000000",
		},
		{
			ItemName = "Apple",
			Amount = 3
		},
	},
	EquippedWeapon = "", -- inventory index of the equipped weapon, "" = fists (LoadoutService)
	Hotbar = { -- non-weapon items only; weapons are equipped from the inventory
		["1"] = "",
		["2"] = "",
		["3"] = "",
		["4"] = "",
		["5"] = "",
		["6"] = "",
		["7"] = "",
		["8"] = "",
		["9"] = "",
		["0"] = "",
	},
}

-- Rensei profile template. ProfileService:Reconcile() fills any key missing from a saved
-- profile; anything that needs converting goes through DataManager's Migrate step and
-- SchemaVersion. Bump SchemaVersion and add a migration step for every breaking change.
-- KEEP THIS FILE THE SAME IN EVERY PLACE (data-storage audit 2026-10-18: the menu and tutorial had an older copy;
-- harmless while Reconcile only adds keys, but a fresh slot made there started without the newer sections).
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
		-- Gate of Truth encounter (2026-10-18, TruthService; additive, Reconcile fills old saves)
		Acquisitions = {}, -- {Stage, Test, Quality = "Clean" | "Flawed", Corrupted, At}, one per passed trial
		ActiveTest = {}, -- the test in progress {Stage, Test, Taken, Died, Started}; {} = none (survives a rejoin)
		GateDeaths = 0, -- deaths inside the Gate (before 2026-10-19; since then a death there is permanent)
		Corruption = 0, -- Restraint tests failed
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
		-- a random id for this character (IdentityService fills it on first load; no account data). Other
		-- players' Identities records are keyed by it, so a deleted-and-recreated slot is a new subject.
		CharacterId = "",
	},

	-- Start flow (owner 2026-10-14): Main Menu -> Customize (Character Customization place) ->
	-- Tutorial place -> cutscene -> Ye. Set by the place that finishes each step.
	Flow = {
		TutorialDone = false,
		IntroSeen = false, -- the post-tutorial cutscene
	},

	SkillTree = {}, -- [NodeId] = rank (Modules.Data.Rensei.SkillTree)
	-- [Family] = {Id or "", ...}: the class skills on hotbar keys 1-4 in Combat Mode, kept per class family
	-- (Rensei.ClassSkills). Additive: Reconcile fills it on older saves.
	SkillLoadout = {},
	Styles = {}, -- [Class] = style id (Rensei.Styles; "Fists" = bare hands). Additive: Reconcile fills old saves.
	StyleUnlocks = {}, -- [StyleId] = true once its style trainer taught it (Rensei.Styles.Unlock). Additive.

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
	-- Player Identities (2026-10-18; IdentityService is the only writer): this investigator's records of
	-- other players' characters. Bounded (Rensei.Identities.MaxRecords). Additive: Reconcile fills old saves.
	Identities = {
		Next = 1, -- the next record number (Subject 01, 02, ...)
		Records = {}, -- [CharacterId] = {N, First, Last, Seen, Obs = {[Kind] = value}, Name, Src, Links, Log, Lock}
	},
	-- Automail (2026-10-18, AutomailService is the only writer; additive). A fitted prosthetic right arm.
	Automail = {
		Installed = false,
		Spec = "Balanced", -- Rensei.Automail.Specs
		Condition = 100, -- 0..100; wear from being knocked down and from water, repaired at the mechanic
		InstalledAt = 0,
	},
	-- The Alchemic Binding ritual (2026-10-18, RitualService is the only writer; additive).
	Binding = {
		Armor = false, -- true = this character's soul is bound to the Alchemic Armor (a failed ritual)
		At = 0,
		By = "", -- the caster's CharacterId
		CasterCooldownUntil = 0, -- os.time(): this character can't cast another binding before then
		TargetCooldownUntil = 0, -- os.time(): this character can't be a binding target before then
		Granted = "", -- the path a successful ritual gave this character ("" = none)
	},
	-- Characters of this slot that died at the Gate (2026-10-19, ProgressionService.Permadeath; additive). Survives
	-- the wipe: {Name, Clan, Affinity, Stage, TrialsPassed, LifetimeExp, At, Cause}, newest last, at most 20.
	Fallen = {},
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

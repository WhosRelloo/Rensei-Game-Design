-- Deeds: consequential acts, recorded once per player by MoralityService (the Deeds Ledger).
-- Morality and Reputation Proposal.md (owner approved the defaults 2026-10-16). Stable ids: never
-- rename a deed that has shipped. PLACEHOLDER content (Foundry Yard). Numbers are PROPOSALS.
--   [DeedId] = {
--     Text     = the reason line players see ("Reported Lise to the Authority"),
--     Conduct  = {Mercy = n, Candor = n, Order = n},       -- who you are
--     Standing = {[FactionId] = n},                         -- Rensei.Factions (Local / Public only)
--     Trust    = {[NpcName] = n},                           -- one person's opinion
--     Renown   = n,                                         -- Public deeds only
--     Scope    = "Private" | "Local" | "Public"
--       Private: only Conduct and Trust move; Standing / Renown wait until it is discovered.
--     Repeat   = {Cap = n}  -- repeatable: counts at most Cap times per day (nil = once ever)
--     Bonus    = {Money = n} -- paid with each counted repeat (PROPOSAL)
--     Birth    = true   -- an origin deed (born_<Origin>): heard everywhere at once, never a rumour
--   }
-- Deeds come from: dialogue actions {Kind = "Deed", Deed = id}, quest Outcomes[x].Deeds, and
-- MoralityService's combat hooks (Finishers below: grip vs deliver a knocked enemy).

local Deeds = {
	-- ===== "Chalk on the Foundry Wall": the Lise choice (quest Outcomes) =====
	reported_lise = {
		Text = "Reported Lise, the unlicensed apprentice, to the Authority",
		Conduct = {Mercy = -5, Order = 10},
		Standing = {Authority = 15, Foundry = -10, Circle = -15},
		Trust = {Lise = -60, Brask = 10},
		Scope = "Local", -- the yard knows who talked
	},
	kept_lise_secret = {
		Text = "Kept Lise's secret",
		Conduct = {Mercy = 5},
		Standing = {Foundry = 5}, -- only if it ever comes out
		Trust = {Lise = 30},
		Scope = "Private",
	},
	taught_lise = {
		Text = "Took Lise on as an alchemy student, without a licence",
		Conduct = {Mercy = 5, Order = -10},
		Standing = {Circle = 15, Authority = -20}, -- only if it ever comes out
		Trust = {Lise = 60},
		Scope = "Private",
	},
	-- after keeping the secret, Brask can still be told
	betrayed_lise = {
		Text = "Told Brask it was Lise, after promising her silence",
		Conduct = {Candor = -10, Mercy = -5},
		Standing = {Foundry = -5},
		Trust = {Lise = -50, Brask = 5},
		Scope = "Local",
	},

	-- ===== Tobin (slept on shift) =====
	promised_tobin = {
		Text = "Promised Tobin you'd keep quiet about his nap",
		Trust = {Tobin = 15},
		Scope = "Private",
	},
	broke_promise_tobin = {
		Text = "Told Brask that Tobin slept on shift, after promising not to",
		Conduct = {Candor = -10},
		Standing = {Foundry = -5},
		Trust = {Tobin = -50, Brask = 5},
		Scope = "Local",
	},
	told_on_tobin = {
		Text = "Told Brask that Tobin slept on shift",
		Conduct = {Order = 2},
		Standing = {Foundry = -3},
		Trust = {Tobin = -25, Brask = 5},
		Scope = "Local",
	},

	-- ===== Knocked enemies: grip (finish) vs deliver (carry them in alive) =====
	executed_bandit = {
		Text = "Finished off a beaten bandit",
		Conduct = {Mercy = -1},
		Scope = "Local",
		Repeat = {Cap = 10},
	},
	arrested_bandit = {
		Text = "Carried a beaten bandit in alive",
		Conduct = {Mercy = 1, Order = 1},
		Standing = {Authority = 1, Townsfolk = 1},
		Scope = "Local",
		Repeat = {Cap = 10},
		Bonus = {Money = 10},
	},

	-- ===== Birth (2026-10-19, spec §11): recorded once when the character first plays in Ye. Origin offsets
	-- cut both ways, each at most +-20, and each origin's add up to >= 0 so no origin is a net handicap.
	-- PLACEHOLDER values (spec §18.2: the owner sets the real table). Birth deeds are heard everywhere at
	-- once and never become rumours. =====
	born_Amestrian = {
		Text = "Born in Amestris",
		Standing = {AmestrianCitizenry = 10, Authority = 10, IshvalanCommunity = -10},
		Scope = "Public", Birth = true,
	},
	born_Ishvalan = {
		Text = "Born of Ishval",
		Standing = {IshvalanCommunity = 20, Authority = -15, Circle = 10},
		Scope = "Public", Birth = true,
	},
	born_Xingnese = {
		Text = "Born in Xing",
		Standing = {XingneseHouses = 15, Authority = -5},
		Scope = "Public", Birth = true,
	},
	born_Drachman = {
		Text = "Born in Drachma",
		Standing = {DrachmanFrontier = 15, Authority = -10},
		Scope = "Public", Birth = true,
	},
	born_Aerugonian = {
		Text = "Born in Aerugo",
		Standing = {AerugonianGuild = 15, Authority = -10},
		Scope = "Public", Birth = true,
	},
	born_Xerxian = {
		Text = "Of Xerxian blood",
		Standing = {XerxianRemnant = 10, Circle = 5, Authority = -10},
		Scope = "Public", Birth = true,
	},
}

-- Which deed a finisher on a knocked enemy records, by its EnemyType attribute (TuningConfig.Enemies).
-- Hostile mobs that just die are not deeds. Players are not covered here (PvP rules undecided).
Deeds.Finishers = {
	Grunt = {Grip = "executed_bandit", Deliver = "arrested_bandit"},
	Elite = {Grip = "executed_bandit", Deliver = "arrested_bandit"},
}

return Deeds

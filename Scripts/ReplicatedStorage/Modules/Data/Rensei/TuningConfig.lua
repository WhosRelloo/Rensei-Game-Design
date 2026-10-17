-- TuningConfig: every combat number lives here (controls doc: "TuningConfig.lua for all numbers").
-- Times are seconds, distances studs, resources 0..Max.
-- Damage is on the approved spreadsheet scale (580 HP at level 1). Everything else is a
-- PROPOSAL tuned toward the doc's target: fast, readable, 25-45s PvP fights.

local TuningConfig = {}

-- ===== Resources =====
TuningConfig.Stamina = {
	Max = 100,
	Regen = 24, -- per second, after RegenDelay
	RegenDelay = 0.8, -- seconds after the last spend
}

TuningConfig.Posture = {
	Max = 100,
	Regen = 14,
	RegenDelay = 1.5,
	BreakStun = 1.4, -- guard break stun
}

-- Transmutation Meter: alchemy only, filled by fighting only (no passive regen).
TuningConfig.Meter = {
	Max = 100,
	OnLightHit = 4,
	OnHeavyHit = 8,
	OnParry = 12,
	OnBlockedHit = 1, -- attacker, when the hit was blocked
	OnHitTaken = 2, -- defender, when hit
}

-- ===== Attacks =====
-- Startup: windup before the hitbox (interruptible: getting hit cancels it, RMB feints lights).
-- Active: frames the hitbox is live (sampled every server frame).
-- Recovery: endlag after the active frames.
-- Posture: posture damage dealt when the attack is blocked.
-- Hitbox: box size; it is centred Reach studs in front of the attacker.
local LightHitbox = Vector3.new(6, 6, 7)

-- Combat flow matched to Devil Hunter's code (user request 2026-10-14, "more like Devil Hunter"):
--   * hitstun 0.6s on lights (DH Stuntime), longer than the 0.42s swing-to-swing gap, so a landed
--     string stays a true combo instead of letting the target slip out or block between hits;
--   * the combo remembers its place for 2s (DH ComboReset);
--   * you keep moving while you fight: DH walk 15 -> 13 swinging, 10 heavy, 12 blocking, 4 stunned
--     (scaled to Rensei's 16 below).
TuningConfig.Light = {
	ComboReset = 2.0, -- seconds after a swing ends before the combo starts over (DH; was 1.0)
	WhiffRecovery = 0.15, -- extra recovery when a swing hits nothing (and the combo resets)
	AttackWalkSpeed = 14, -- walk speed while swinging (DH 13/15; was 6)
	MinStun = 0.6, -- every weapon's non-finisher lights stun at least this long (DH Stuntime)
	Hits = {
		{Anim = "FistCombo1", Startup = 0.22, Active = 0.08, Recovery = 0.16, Damage = 17, Posture = 8, Stun = 0.6, Velocity = "Pull", Hitbox = LightHitbox, Reach = 3.5},
		{Anim = "FistCombo2", Startup = 0.22, Active = 0.08, Recovery = 0.16, Damage = 17, Posture = 8, Stun = 0.6, Velocity = "Pull", Hitbox = LightHitbox, Reach = 3.5},
		{Anim = "FistCombo3", Startup = 0.22, Active = 0.08, Recovery = 0.16, Damage = 17, Posture = 8, Stun = 0.6, Velocity = "Pull", Hitbox = LightHitbox, Reach = 3.5},
		{Anim = "FistCombo5", Startup = 0.28, Active = 0.10, Recovery = 0.55, Damage = 24, Posture = 14, Stun = 0.9, Velocity = "Knockback", Hitbox = LightHitbox, Reach = 3.5},
	},
}

TuningConfig.Heavy = {
	Anim = "FistHeavy",
	Telegraph = true, -- crit warning flash during the windup (Effects.Combat.CritTelegraph)
	Startup = 0.5, Active = 0.12, Recovery = 0.55,
	Damage = 32, Posture = 38, Stun = 0.9, Velocity = "Knockback",
	Hitbox = Vector3.new(7, 7, 8), Reach = 4,
	Step = 15, -- forward step during startup
	Cooldown = 1.2,
	WalkSpeed = 11, -- walk speed while heaving (DH 10/15; was 4) -- also every weapon heavy
}

-- Walk speed while hit-stunned (DH lets a stunned fighter shuffle at 4/15; was 0). Jumping stays off.
TuningConfig.HitStun = {WalkSpeed = 4}

-- Launcher + jump attack.
--   Ctrl + LMB (ground or air) -> Uppercut: launches the target and you upward together
--     (air juggle; your next lights continue in the air).
--   LMB in the air -> Aerial: momentum bleeds off through the windup, then a forward dive slam
--     that ends the moment you land.

TuningConfig.Uppercut = {
	-- the group's Uppercut animation (its Hit marker at 0.28s lines up with the active frames)
	Anim = "Uppercut", AnimPeak = 0.28, Fallback = "FistUptilt",
	Startup = 0.2, Active = 0.1, Recovery = 0.3,
	Damage = 15, Posture = 8, Stun = 1.0, Velocity = "Uptilt",
	Hitbox = Vector3.new(9, 10, 9), Reach = 3.5,
	SelfLift = 45, -- upward boost on the active frame, hit or miss
	Cooldown = 3.0,
	Stamina = 8,
}

-- Jump attack: LMB while jumping (or within JumpWindow of pressing Space) -- every time.
-- Hover-then-dive slam (the system you preferred), smoothed: the hover eases your fall to a
-- stop instead of freezing, keeps most of your speed, and the dive ramps in over DiveRamp
-- seconds and lands cleanly. The target is knocked downward.
TuningConfig.Aerial = {
	Anim = "FistDownKick",
	Startup = 0.16, Active = 0.32, Recovery = 0.22,
	Damage = 20, Posture = 12, Stun = 0.7, Velocity = "Downslam",
	Hitbox = Vector3.new(9, 9, 9), Reach = 3,
	HoverCarry = 0.75, -- horizontal momentum kept through the hover
	DiveForward = 30, DiveDown = 110, -- dive keeps at least this forward speed (more if you were moving faster)
	DiveRamp = 0.12, -- seconds to ramp into the full dive speed
	JumpWindow = 0.3,
	Cooldown = 0.4,
	Stamina = 0,
}

TuningConfig.DashAttack = {
	Anim = "FistCombo1",
	Startup = 0.16, Active = 0.14, Recovery = 0.45,
	Damage = 22, Posture = 14, Stun = 0.6, Velocity = "Knockback",
	Hitbox = Vector3.new(7, 6, 8), Reach = 4,
	Cooldown = 2.0,
	Stamina = 12,
	MinSpeed = 20, -- horizontal speed that counts as running
	Lunge = 65, LungeTime = 0.26, -- eased out (cosine), stops at walls
}

-- ===== Defence =====
TuningConfig.Block = {
	StartDelay = 0.08, -- hold time before the guard is up
	DamageTaken = 0.2, -- chip damage fraction through a block
	WalkSpeed = 12, -- (DH 12/15; was 5)
}

-- Parry, matched to Devil Hunter's Combat/Parry code (user request 2026-10-14):
--   * pressing F opens the window (0.22s; +0.04s if your previous parry landed). At 100ms+ ping the
--     window becomes 0.2 + ping(ms) * 0.0005 (ping clamped to 300ms), as in Devil Hunter.
--   * every attempt starts a 1.3s parry cooldown -- unless it LANDED, which keeps parries chaining.
--     (Holding F still blocks during the cooldown; only the parry window is withheld.)
--   * a parried attacker loses 10 posture, is parry-stunned 0.7s and pushed back (30 speed, 0.12s);
--     the parrier pays 5 posture. No facing check: a parry catches hits from any side.
TuningConfig.Parry = {
	Window = 0.22,
	ChainBonus = 0.04,
	PingThreshold = 0.1, -- seconds
	PingBase = 0.2, PingPerMs = 0.0005, PingClampMs = 300,
	Cooldown = 1.3,
	AttackerPostureDamage = 10,
	AttackerStun = 0.7,
	AttackerPush = 30, AttackerPushTime = 0.12,
	DefenderPostureCost = 5,
}
TuningConfig.Parry.FailLockout = TuningConfig.Parry.Cooldown -- older name, read by the cooldown HUD / AI
-- Parrying while getting hit (user request 2026-10-14, "like VV and Devil Hunter"): Devil Hunter's
-- block gate doesn't include hitstun, so a fresh F press during hitstun still opens the parry window
-- (never while guard-broken, parry-stunned, frozen or knocked). It costs posture up front and always
-- starts the parry cooldown, even when it lands, so it can't be chained out of every combo.
TuningConfig.Parry.HitParry = {
	PostureCost = 10, -- PROPOSAL: paid on the attempt; needs this much posture left
	AlwaysCooldown = true, -- PROPOSAL: a landed hit-parry doesn't skip the 1.3s cooldown
}

TuningConfig.Dash = {
	Stamina = 20,
	Cooldown = 1.0,
	IFrames = 0.26,
	Duration = 0.325,
	MaxSpeed = 110, -- eases out along a cosine curve...
	MinSpeed = 24, -- ...to this
	AirDash = true, -- forward dash in the air follows the camera
}

-- Impact pause on hit (animation speed drops to ~0 on attacker and victim).
TuningConfig.Hitstop = {
	Light = 0.05,
	Heavy = 0.09,
}

TuningConfig.Movement = {
	DoubleJump = false, -- off: Devil Hunter has none and the doc asks for "not floaty"
}

-- Parkour stamina (controls doc). One climb and one wall run per airtime; landing resets both.
TuningConfig.Parkour = {
	-- Directional climb (controls doc: tap Space on a wall, WASD moves on it, stamina drain, no
	-- combat, touch the ground to reset). PROPOSAL speeds / drain.
	ClimbStart = 10,
	ClimbStep = 8, -- Space + W leap up the wall
	ClimbSpeed = 9, -- studs/s up and down
	ClimbSideSpeed = 8, -- studs/s sideways
	ClimbMove = 3, -- stamina per ClimbTickEvery while moving on the wall (12/s)
	ClimbHang = 1, -- stamina per ClimbTickEvery while hanging still (4/s)
	ClimbTickEvery = 0.25,
	ClimbReach = 5, -- how far in front a wall can be to grab it (Devil Hunter's climb ray is 5)
	MantleTime = 0.32, -- pulling up onto a ledge: up and over, placed on top (DH-style vault tween)
	-- Wall run (airborne + HOLD Space next to a side wall). Rides while Space is held and you
	-- have stamina (small start cost + a steady drain), up to WallRunDuration as a safety cap.
	-- Releasing Space kicks you off the wall.
	WallRun = 8, -- start cost
	WallRunTick = 4.5, -- charged every WallRunTickEvery seconds while riding (~18 stamina/s)
	WallRunTickEvery = 0.25,
	WallRunDuration = 3.0,
	WallRunSpeed = 40, -- minimum speed along the wall (you keep more if you arrive faster)
	WallRunRise = 10, -- starts rising this fast...
	WallRunRiseTime = 0.5, -- ...levelling off over this long...
	WallRunSink = 4, -- ...then sinks slowly at this speed
	WallRunReach = 5, -- how far to the side a wall can be to start
	KickUp = 35, KickAway = 30, KickAlong = 20, -- kick-off velocity on release
	WallRunChainDelay = 0.25, -- after kicking off, how soon you can catch a DIFFERENT wall
}

TuningConfig.Feint = {
	Stamina = 10,
	Cooldown = 2.0,
}

-- ===== Weapons (Phase 2) =====
-- EVERY number below is a PROPOSAL (nothing in the design docs gives weapon values). Damage sits on
-- the approved spreadsheet scale next to the fist numbers above (fist light = 17).
--
-- Each weapon class has:
--   Light.Hits  its M1 combo (same fields as TuningConfig.Light.Hits)
--   Heavy       R
--   Skill       the weapon skill (G, rebindable): stamina cost + short cooldown
--   Passive     a PROPOSAL passive, applied in WeaponManager.Passives
-- 2026-10-16 (sheet pass 2): Greatsword CRIT -> _Heavy (peak 0.85: its vfx/sfx/comboStep markers at 0.88),
-- Greatsword WEAPON SKILL -> _Skill (peak 1.31, first big swing; PROPOSAL), Caestus CRIT -> Gauntlets_Heavy
-- (its Hit marker, 0.88).
-- Anim fields name animations in ReplicatedStorage.Assets.Animations (the weapon sets live in
-- Animations.Weapons). AnimPeak = the moment of fastest limb motion measured from the source
-- KeyframeSequence (the swing); AttackRunner sets the playback speed so that moment lands in the
-- middle of the active window. Anims missing from the game fall back to Fallback (fist anims).
-- Uppercut, Jump Attack and Dash Attack stay the shared fist versions for every weapon.

local function Hit(T) return T end

TuningConfig.Weapons = {
	Sword = {
		Display = "Sword",
		-- Combat Mode (E) draws / sheathes. SwapAt = when the weapon moves between holster and hand.
		-- The draw animation starts with the right hand on the right hip, so the holster sits there
		-- and sheathing plays the draw backwards (the hand ends exactly on the holster).
		Draw = {Equip = "Sword_Equip", SwapAt = 0.05, Unequip = "Sword_Equip", UnequipReverse = true, UnequipSpeed = 1.2, UnequipSwapAt = 0.7},
		RunAnim = "Sword_Run",
		IdleAnim = "Sword_Idle", -- Animation ID's sheet (2026-10-16)
		HoldAnim = "Sword_Hold",
		-- M1 1-4 from the Animation ID's sheet (2026-10-16); AnimPeak re-measured from the new keyframes
		Light = {Hits = {
			Hit{Anim = "Sword_Light1", AnimPeak = 0.38, Startup = 0.24, Active = 0.08, Recovery = 0.18, Damage = 20, Posture = 9, Stun = 0.45, Velocity = "Pull", Hitbox = Vector3.new(7, 6, 8), Reach = 4},
			Hit{Anim = "Sword_Light2", AnimPeak = 0.31, Startup = 0.24, Active = 0.08, Recovery = 0.18, Damage = 20, Posture = 9, Stun = 0.45, Velocity = "Pull", Hitbox = Vector3.new(7, 6, 8), Reach = 4},
			Hit{Anim = "Sword_Light3", AnimPeak = 0.28, Startup = 0.24, Active = 0.08, Recovery = 0.18, Damage = 20, Posture = 9, Stun = 0.45, Velocity = "Pull", Hitbox = Vector3.new(7, 6, 8), Reach = 4},
			Hit{Anim = "Sword_Light4", AnimPeak = 0.38, Startup = 0.30, Active = 0.10, Recovery = 0.50, Damage = 27, Posture = 16, Stun = 0.9, Velocity = "Knockback", Hitbox = Vector3.new(8, 6, 9), Reach = 4},
		}},
		Heavy = {Anim = "Sword_Heavy", AnimPeak = 0.38, Startup = 0.42, Active = 0.12, Recovery = 0.5, Damage = 36, Posture = 40, Stun = 0.9, Velocity = "Knockback", Hitbox = Vector3.new(8, 7, 9), Reach = 4.5, Step = 18, Cooldown = 1.3},
		-- Dragonflash: a lunging slash.
		Skill = {Name = "Dragonflash", Anim = "Sword_Skill", AnimPeak = 0.97, Startup = 0.34, Active = 0.2, Recovery = 0.45, Damage = 30, Posture = 22, Stun = 0.8, Velocity = "Knockback", Hitbox = Vector3.new(8, 6, 10), Reach = 4.5, Lunge = 75, LungeTime = 0.3, Stamina = 20, Cooldown = 7},
		-- Keen Edge: blocked hits deal +30% posture damage.
		Passive = {Name = "Keen Edge", BlockedPostureMult = 1.3},
	},

	Rapier = {
		Display = "Rapier",
		-- Borrows the sword's draw / sheathe, run, idle and hold (same grip as the katana).
		Draw = {Equip = "Sword_Equip", SwapAt = 0.05, Unequip = "Sword_Equip", UnequipReverse = true, UnequipSpeed = 1.2, UnequipSwapAt = 0.7},
		RunAnim = "Sword_Run",
		IdleAnim = "Rapier_Idle", -- Animation ID's sheet (2026-10-16)
		WalkAnim = "Rapier_Walk", -- Animation ID's sheet (2026-10-16)
		HoldAnim = "Sword_Hold",
		-- No rapier M1 set exists yet: lights 1/3/4 BORROW the sword set, light 2 is "sTab M2".
		Light = {Hits = {
			Hit{Anim = "Sword_Light1", AnimPeak = 0.38, Startup = 0.18, Active = 0.07, Recovery = 0.14, Damage = 14, Posture = 6, Stun = 0.4, Velocity = "Pull", Hitbox = Vector3.new(4, 5, 10), Reach = 5},
			Hit{Anim = "Rapier_Light2", AnimPeak = 0.29, Startup = 0.18, Active = 0.07, Recovery = 0.14, Damage = 14, Posture = 6, Stun = 0.4, Velocity = "Pull", Hitbox = Vector3.new(4, 5, 10), Reach = 5},
			Hit{Anim = "Sword_Light3", AnimPeak = 0.28, Startup = 0.18, Active = 0.07, Recovery = 0.14, Damage = 14, Posture = 6, Stun = 0.4, Velocity = "Pull", Hitbox = Vector3.new(4, 5, 10), Reach = 5},
			Hit{Anim = "Sword_Light4", AnimPeak = 0.38, Startup = 0.24, Active = 0.08, Recovery = 0.45, Damage = 20, Posture = 12, Stun = 0.8, Velocity = "Knockback", Hitbox = Vector3.new(4, 5, 11), Reach = 5.5},
		}},
		-- Rapier CRIT from the Animation ID's sheet (2026-10-16): three thrusts; timed on the first (0.44s)
		Heavy = {Anim = "Rapier_Heavy", AnimPeak = 0.44, Startup = 0.34, Active = 0.1, Recovery = 0.4, Damage = 30, Posture = 30, Stun = 0.8, Velocity = "Knockback", Hitbox = Vector3.new(4, 5, 12), Reach = 6, Step = 22, Cooldown = 1.1},
		-- Flurry: five fast thrusts.
		Skill = {Name = "Flurry", Anim = "Rapier_Skill", AnimSpeed = 0.9, Startup = 0.18, Active = 0.45, MultiHit = 5, Recovery = 0.35, Damage = 6, Posture = 4, Stun = 0.35, Velocity = "Pull", Hitbox = Vector3.new(5, 5, 10), Reach = 5, Stamina = 18, Cooldown = 6},
		-- Precision: +25% damage against a target that is winding up or recovering (counter-hit).
		Passive = {Name = "Precision", CounterHitMult = 1.25},
	},

	Gauntlets = {
		Display = "Gauntlets",
		-- Worn: no draw animation, nothing to holster.
		Draw = {},
		IdleAnim = "Gauntlets_Idle", -- Caestus idle, Animation ID's sheet (2026-10-16)
		-- Lights use the fist combo (Caestus set only has a heavy and a barrage).
		Light = {Hits = {
			Hit{Anim = "FistCombo1", Startup = 0.2, Active = 0.08, Recovery = 0.14, Damage = 18, Posture = 9, Stun = 0.45, Velocity = "Pull", Hitbox = Vector3.new(6, 6, 7), Reach = 3.5},
			Hit{Anim = "FistCombo2", Startup = 0.2, Active = 0.08, Recovery = 0.14, Damage = 18, Posture = 9, Stun = 0.45, Velocity = "Pull", Hitbox = Vector3.new(6, 6, 7), Reach = 3.5},
			Hit{Anim = "FistCombo3", Startup = 0.2, Active = 0.08, Recovery = 0.14, Damage = 18, Posture = 9, Stun = 0.45, Velocity = "Pull", Hitbox = Vector3.new(6, 6, 7), Reach = 3.5},
			Hit{Anim = "FistCombo5", Startup = 0.26, Active = 0.1, Recovery = 0.5, Damage = 25, Posture = 16, Stun = 0.9, Velocity = "Knockback", Hitbox = Vector3.new(6, 6, 7), Reach = 3.5},
		}},
		-- Caestus CRIT from the Animation ID's sheet (2026-10-16); its swing peaks at 0.45s.
		Heavy = {Anim = "Gauntlets_Heavy", AnimPeak = 0.88, Startup = 0.38, Active = 0.1, Recovery = 0.45, Damage = 34, Posture = 45, Stun = 0.9, Velocity = "Knockback", Hitbox = Vector3.new(6, 6, 8), Reach = 3.5, Step = 16, Cooldown = 1.2},
		-- Barrage: "fist guy" carries Hit markers at 0.42 / 0.92 / 1.50 and Knockback at 2.67s.
		Skill = {Name = "Barrage", Anim = "Gauntlets_Skill", AnimSpeed = 1, Startup = 0.42, Active = 2.3, Recovery = 0.45, HitTimes = {0.42, 0.92, 1.50, 2.67}, Damage = 9, Posture = 8, Stun = 0.7, Velocity = "Pull", Hitbox = Vector3.new(6, 6, 7), Reach = 3.5,
			Final = {Damage = 16, Posture = 14, Stun = 0.9, Velocity = "Knockback"}, WalkSpeed = 3, Stamina = 22, Cooldown = 8},
		-- Momentum: +6% damage per hit in your current combo chain, up to 4 stacks.
		Passive = {Name = "Momentum", PerStack = 0.06, MaxStacks = 4},
	},

	Greatsword = {
		Display = "Greatsword",
		-- Its equip animation pulls it off the back (weapon in hand from frame 0); sheathing plays it backwards.
		Draw = {Equip = "Greatsword_Equip", SwapAt = 0, Unequip = "Greatsword_Equip", UnequipReverse = true, UnequipSpeed = 1.4, UnequipSwapAt = 0.85},
		RunAnim = "Greatsword_Run",
		HoldAnim = "Greatsword_Hold",
		-- Heavy feel (user request 2026-10-14; PROPOSAL numbers): carried on the shoulder with the blade
		-- just behind the head while idle / walking / running, slower to move with, every swing steps
		-- the body into it, and hits land with a longer impact pause.
		CarryAnim = "Greatsword_Carry",
		MoveSpeedMult = 0.85, -- walk / run speed while drawn
		SwingStep = 12, -- forward step (studs/s) late in each light's windup
		HitstopMult = 1.4,
		Light = {AttackWalkSpeed = 10, Hits = { -- slower than other weapons' 14 (heavy weapon; was 4)
			Hit{Anim = "Greatsword_Light1", AnimPeak = 0.78, Startup = 0.40, Active = 0.12, Recovery = 0.32, Damage = 30, Posture = 16, Stun = 0.55, Velocity = "Pull", Hitbox = Vector3.new(10, 7, 10), Reach = 5},
			Hit{Anim = "Greatsword_Light2", AnimPeak = 0.62, Startup = 0.40, Active = 0.12, Recovery = 0.32, Damage = 30, Posture = 16, Stun = 0.55, Velocity = "Pull", Hitbox = Vector3.new(10, 7, 10), Reach = 5},
			Hit{Anim = "Greatsword_Light3", AnimPeak = 1.11, Startup = 0.40, Active = 0.12, Recovery = 0.32, Damage = 30, Posture = 16, Stun = 0.55, Velocity = "Pull", Hitbox = Vector3.new(10, 7, 10), Reach = 5},
			Hit{Anim = "Greatsword_Light4", AnimPeak = 0.44, Startup = 0.46, Active = 0.14, Recovery = 0.6, Damage = 38, Posture = 28, Stun = 1.0, Velocity = "Knockback", Hitbox = Vector3.new(11, 7, 11), Reach = 5},
		}},
		Heavy = {Anim = "Greatsword_Heavy", AnimPeak = 0.85, Startup = 0.55, Active = 0.14, Recovery = 0.6, Damage = 50, Posture = 55, Stun = 1.0, Velocity = "Knockback", Hitbox = Vector3.new(10, 8, 11), Reach = 5, Step = 14, Cooldown = 1.6, HyperArmor = true},
		-- Whirlwind: two spinning hits all around you.
		Skill = {Name = "Whirlwind", Anim = "Greatsword_Skill", AnimPeak = 1.31, Startup = 0.45, Active = 0.35, MultiHit = 2, Recovery = 0.5, Damage = 22, Posture = 18, Stun = 0.6, Velocity = "Pull", Hitbox = Vector3.new(16, 8, 16), Reach = 0, HyperArmor = true, WalkSpeed = 4, Stamina = 25, Cooldown = 9},
		-- Unyielding: heavy and skill windups have hyper armour (you take damage but are not stunned).
		Passive = {Name = "Unyielding"},
	},

	Daggers = {
		Display = "Daggers",
		Draw = {Equip = "Daggers_Equip", EquipSpeed = 1.3, SwapAt = 0, Unequip = "Daggers_Equip", UnequipReverse = true, UnequipSpeed = 1.6, UnequipSwapAt = 0.95},
		RunAnim = "Daggers_Run",
		HoldAnim = "Daggers_Hold",
		Light = {Hits = {
			Hit{Anim = "Daggers_Light1", AnimPeak = 0.24, Startup = 0.15, Active = 0.07, Recovery = 0.12, Damage = 12, Posture = 5, Stun = 0.4, Velocity = "Pull", Hitbox = Vector3.new(6, 6, 6), Reach = 3.5},
			Hit{Anim = "Daggers_Light2", AnimPeak = 0.39, Startup = 0.15, Active = 0.07, Recovery = 0.12, Damage = 12, Posture = 5, Stun = 0.4, Velocity = "Pull", Hitbox = Vector3.new(6, 6, 6), Reach = 3.5},
			Hit{Anim = "Daggers_Light3", Startup = 0.15, Active = 0.07, Recovery = 0.12, Damage = 12, Posture = 5, Stun = 0.4, Velocity = "Pull", Hitbox = Vector3.new(6, 6, 6), Reach = 3.5},
			Hit{Anim = "Daggers_Light4", AnimPeak = 0.29, Startup = 0.2, Active = 0.08, Recovery = 0.42, Damage = 16, Posture = 10, Stun = 0.8, Velocity = "Knockback", Hitbox = Vector3.new(6, 6, 7), Reach = 3.5},
		}},
		Heavy = {Anim = "Daggers_Heavy", AnimPeak = 0.51, Startup = 0.3, Active = 0.1, Recovery = 0.45, Damage = 28, Posture = 26, Stun = 0.8, Velocity = "Knockback", Hitbox = Vector3.new(6, 6, 8), Reach = 4, Step = 20, Cooldown = 1.0},
		-- Scissor Rush: six quick cuts while moving in.
		Skill = {Name = "Scissor Rush", Anim = "Daggers_Skill", AnimSpeed = 1.35, Startup = 0.2, Active = 0.9, MultiHit = 6, Recovery = 0.35, Damage = 5, Posture = 4, Stun = 0.35, Velocity = "Pull", Hitbox = Vector3.new(6, 6, 7), Reach = 3.5, Lunge = 40, LungeTime = 0.25, Stamina = 20, Cooldown = 7},
		-- Lacerate: hits make the target bleed (3 ticks of 2 over 1.5s; refreshes).
		Passive = {Name = "Lacerate", BleedDamage = 2, BleedTicks = 3, BleedEvery = 0.5},
	},

	Guns = {
		Display = "Guns",
		-- No draw animation exists for the pistols: they move between hip holster and hand instantly.
		Draw = {},
		RunAnim = "Guns_Run",
		Ranged = true,
		-- One hitscan shot per click; the four "blatt" shot animations take turns. Damage, magazine,
		-- reload and fire rate (Recovery) come from Items below.
		Light = {Hits = {
			Hit{Shot = true, Anim = "Guns_Light1", AnimPeak = 0.24, Startup = 0.12, Active = 0.02, Recovery = 0.2, Damage = 15, Posture = 6, Stun = 0.3, Hitbox = Vector3.new(2, 2, 2), Range = 90, Class = "BLOCKABLE"},
			Hit{Shot = true, Anim = "Guns_Light2", AnimPeak = 0.19, Startup = 0.12, Active = 0.02, Recovery = 0.2, Damage = 15, Posture = 6, Stun = 0.3, Hitbox = Vector3.new(2, 2, 2), Range = 90, Class = "BLOCKABLE"},
			Hit{Shot = true, Anim = "Guns_Light3", AnimPeak = 0.18, Startup = 0.12, Active = 0.02, Recovery = 0.2, Damage = 15, Posture = 6, Stun = 0.3, Hitbox = Vector3.new(2, 2, 2), Range = 90, Class = "BLOCKABLE"},
			Hit{Shot = true, Anim = "Guns_Light4", AnimPeak = 0.16, Startup = 0.12, Active = 0.02, Recovery = 0.2, Damage = 15, Posture = 6, Stun = 0.3, Hitbox = Vector3.new(2, 2, 2), Range = 90, Class = "BLOCKABLE"},
		}},
		-- Pistol Whip: a close-range melee answer.
		Heavy = {Anim = "FistHeavy", Startup = 0.3, Active = 0.1, Recovery = 0.4, Damage = 22, Posture = 30, Stun = 0.8, Velocity = "Knockback", Hitbox = Vector3.new(6, 6, 7), Reach = 3.5, Step = 12, Cooldown = 1.2},
		-- Fan the Hammer: three rapid shots (uses 3 rounds).
		Skill = {Name = "Fan the Hammer", Anim = "Guns_Light2", AnimSpeed = 1.6, Startup = 0.12, Active = 0.36, Recovery = 0.3, HitTimes = {0.12, 0.27, 0.42}, Damage = 11, Posture = 5, Stun = 0.3, Hitbox = Vector3.new(2, 2, 2), Range = 70, Spread = 1.5, Class = "BLOCKABLE", Stamina = 15, Cooldown = 6},
		-- Point Blank: +20% shot damage within 12 studs.
		Passive = {Name = "Point Blank", Range = 12, Mult = 1.2},
		Items = {
			Revolver = {Damage = 24, Magazine = 6, Reload = 1.8, Recovery = 0.32},
			Renetti = {Damage = 12, Magazine = 15, Reload = 1.4, Recovery = 0.16},
			["Forge Tac"] = {Damage = 28, Magazine = 7, Reload = 1.7, Recovery = 0.38},
			Sykov = {Damage = 15, Magazine = 10, Reload = 1.5, Recovery = 0.2},
		},
	},
}

-- PROPOSAL: seconds each client takes to ease a weapon between holster and hand when the draw /
-- sheathe swap happens (WeaponManager), so the swap never pops.
TuningConfig.WeaponSwapBlend = 0.15
TuningConfig.WeaponSwapTurnRate = 720 -- deg/s: a bigger turn blends longer (up to 2x WeaponSwapBlend)

-- ===== Alchemy (controls doc: Z primary / X secondary / C utility / V ultimate; meter based,
-- cooldowns, telegraphed, utility/control focused, NOT the main damage source) =====
-- Each ability's damage, cooldown, cast time, class and extras come from the design sheet and live
-- in Modules.Data.Rensei.Alchemy (RECOVERED values). Everything here is a PROPOSAL for what the
-- sheet doesn't say. Abilities without an entry below are not built yet.
TuningConfig.Alchemy = {
	MeterCost = {Z = 25, X = 35, C = 35, V = 70}, -- Transmutation Meter per cast (a light hit earns 4)
	AimMaxYaw = 100, -- degrees a cast may aim away from where you face (else it fires straight ahead)
	AimMaxPitch = 35, -- degrees up / down a cast may aim
	CastWalkSpeed = 6, -- walk speed while casting
	-- Every cast starts with the transmutation (user request 2026-10-14): CLAP (hold the key to keep
	-- the clap going), then the release, then the move's own animation. Release (owner's rule):
	-- PROJECTILE moves (fireballs, anything launched) -> the arm EXTENDS; ground / body moves -> the
	-- hands SLAM the ground. Times are the animations' Hit markers (the user's group animations).
	Transmute = {
		Clap = "Alchemy_Clap", ClapHit = 0.28, -- hands meet
		Hold = "Alchemy_ClapLoop", -- looped while the key is held after the clap
		Releases = {
			GroundSlam = {Anim = "Alchemy_GroundSlam", Hit = 0.52}, -- hands reach the ground
			ArmExtend = {Anim = "Alchemy_ArmExtend", Hit = 0.12},
		},
		MaxHold = 3, -- PROPOSAL: a held clap releases itself after this long
		Speed = 1, -- PROPOSAL: clap + release playback speed (1 = as animated)
	},
	Abilities = {
		-- Kind = how the move resolves in AlchemyService: Projectile | Cone | Lunge | Phoenix | Counter |
		-- Melee | Trap | Nova. On-hit statuses: Burn = {Ticks, Every, Damage}; Freeze = seconds.
		-- Flame Z. Sheet: fireball, 60 dmg, 8s CD, 0.6s cast, burn 4s (20 total). Clap -> arm extend
		-- (a projectile), then the sheet's 0.6s cast is the throw's windup (the hands burn throughout;
		-- VFX = the user's Assets.VFX.FireElement).
		Ignite = {
			Kind = "Projectile", Release = "ArmExtend", Element = "FireElement",
			Anim = "Alchemy_Ignite", AnimPeak = 0.32, -- the user's "Fire 2" animation; its Hit marker
			Fallback = "FistCombo2", -- plays if the animation isn't published yet
			Active = 0.05, Recovery = 0.35,
			Speed = 110, Range = 90, Radius = 1.5, -- projectile (studs/s, studs, studs)
			SpawnOffset = Vector3.new(0.6, 0.7, -2.5), -- release point from the root (the throwing hand)
			Posture = 12, -- posture damage when blocked
			Stun = 0.35, -- flinch on a clean hit
			Burn = {Ticks = 4, Every = 1, Damage = 5}, -- sheet: burn 4s, 20 total
		},

		-- Flame X. Sheet: cone wave, 90 dmg, 10s CD, 0.8s cast, BLOCKABLE, "wide cone, small knockback
		-- (0.4s)". Clap -> ground slam -> the user's "Fire 1" (both hands thrust forward at 0.60s).
		ScorchingWave = {
			Kind = "Cone", Release = "GroundSlam", Element = "FireElement",
			Anim = "Alchemy_Fire1", AnimPeak = 0.60, Fallback = "FistHeavy",
			Active = 0.1, Recovery = 0.45,
			Range = 18, HalfAngle = 40, -- the cone (studs, degrees either side of the aim)
			Posture = 20, Stun = 0.4,
			Velocity = "Knockback", Knockback = 40, KnockbackTime = 0.4, -- sheet: small knockback (0.4s)
			Burn = {Ticks = 2, Every = 1, Damage = 5}, -- PROPOSAL: every Flame hit burns (owner: alchemy hits apply their status); the sheet only lists burn on Ignite / Phoenix Drive
		},

		-- Flame C. Sheet: lunge, 85 dmg, 12s CD, 0.4s cast, PARRYABLE, "dash gap-closer with 0.2s i-frame
		-- on start". Clap -> ground slam -> the user's "infernolance" thrust (Hit 0.28s), then a burning
		-- dash that hits along its path (FireElement infernolance burst).
		InfernoLance = {
			Kind = "Lunge", Release = "GroundSlam", Element = "FireElement",
			Anim = "Alchemy_InfernoLance", AnimPeak = 0.28, Fallback = "FistCombo1",
			Active = 0.25, Recovery = 0.4,
			Lunge = 75, LungeTime = 0.25, -- ~15 studs
			HitLag = 0.35, -- the hitbox keeps sweeping this long after the dash (the server sees the client's dash late)
			IFrames = 0.2, -- sheet: i-frames as the dash starts
			Hitbox = Vector3.new(6, 6, 8), Reach = 4,
			Posture = 18, Stun = 0.6,
			Burn = {Ticks = 2, Every = 1, Damage = 5}, -- PROPOSAL (see Scorching Wave)
		},

		-- Flame V (ultimate). Sheet: 260 total = "Phoenix crash: 70 immediate + 20 burn + explosion 170",
		-- 25s CD, 1.5s cast, UNBLOCKABLE, "large radius; vulnerable after cast". Clap -> arm extend (it
		-- launches the phoenix) -> the user's "Fire 4" (arms raised overhead, Hit 0.52s). The crash point is
		-- fixed when the key is released and marked on the ground for everyone (it can't be blocked, so it
		-- must be dodged); the phoenix flies there, crashes, and the ground explodes a moment later.
		PhoenixDrive = {
			Kind = "Phoenix", Release = "ArmExtend", Element = "FireElement",
			Anim = "Alchemy_Fire4", AnimPeak = 0.52, Fallback = "FistHeavy",
			Active = 0.1, Recovery = 1.2, -- sheet: vulnerable after the cast
			Range = 45, MinRange = 12, -- furthest / nearest crash point
			FlightTime = 0.6, CrashRadius = 10, ExplosionDelay = 0.8, ExplosionRadius = 20,
			SigilRadius = 8, -- the alchemy circle under the caster while the phoenix is summoned
			Posture = 0,
			Hits = {
				Crash = {Damage = 70, Stun = 0.8}, -- sheet
				Explosion = {Damage = 170, Stun = 1.0, Velocity = "Knockback", Knockback = 60, KnockbackTime = 0.5}, -- sheet damage
			},
			Burn = {Ticks = 4, Every = 1, Damage = 5}, -- sheet: 20 burn
		},

		-- ===== ICE (VFX: Assets.VFX.IceElement -- built for the kit from the owner's Freeze status
		-- textures plus part-built ice; swap in the owner's own Ice VFX when it exists. Animations are
		-- PLACEHOLDERS from the owner's existing set until Ice animations are made.) =====

		-- Ice Z. Sheet: reactive counter, 12s CD, cast 0, DEFENSIVE, "if hit during counter: freezes
		-- attacker 1.5s, user gets 20% damage resist for 2s (on trigger)", 40 dmg. Clap -> the counter is
		-- up the moment the hands meet (no slam: Release None) and holds for Window; the caster is glazed
		-- in frost so it can be read. The first hit that reaches them (not UNBLOCKABLE) is cancelled.
		CryoShift = {
			Kind = "Counter", Release = "None", Element = "IceElement",
			Window = 1.0, -- PROPOSAL: how long the counter stays up after the clap
			Active = 0.05, Recovery = 0.25,
			Posture = 0, Stun = 0,
			Hits = {
				Counter = {Damage = 40, Class = "UNBLOCKABLE"}, -- sheet damage; it answers a hit, so it can't be blocked
			},
			Freeze = 1.5, -- sheet: freezes the attacker 1.5s
			Resist = {Amount = 0.2, Duration = 2}, -- sheet: 20% damage resist for 2s
		},

		-- Ice X. Sheet: axe strike, 110 dmg, 9s CD, 0.7s cast, PARRYABLE, "heavy strike, slow windup,
		-- breaks minor shields". Clap -> ground slam (an ice greataxe forms in the hand) -> a heavy
		-- overhead swing. PLACEHOLDER animation: the greatsword heavy (FistHeavy where it isn't published).
		ColdsteelSmash = {
			Kind = "Melee", Release = "GroundSlam", Element = "IceElement",
			Anim = "Greatsword_Heavy", AnimPeak = 0.85, Fallback = "FistHeavy",
			Active = 0.15, Recovery = 0.5,
			Hitbox = Vector3.new(8, 7, 9), Reach = 4.5,
			Step = 28, StepTime = 0.15, -- a step into the swing
			Posture = 35, Stun = 0.7,
			Freeze = 0.6, -- PROPOSAL: Ice hits freeze briefly (owner: alchemy hits apply their status); not on the sheet
			BreaksShields = true, -- sheet: for Metal's Steel Guard (not built yet)
		},

		-- Ice C. Sheet: radius trap, 30 dmg, 13s CD, 0.6s cast, BLOCKABLE, "roots / 1.5s stun at feet
		-- (traps target; allows followup)". Clap -> ground slam -> a forward thrust that sends a frost
		-- circle to the aimed spot; it arms, and the first enemy to step in springs it: ice shards erupt
		-- and everyone inside is frozen in place. One trap per caster (a new one replaces the old).
		-- PLACEHOLDER animation: the owner's "Fire 1" thrust.
		IceShards = {
			Kind = "Trap", Release = "GroundSlam", Element = "IceElement",
			Anim = "Alchemy_Fire1", AnimPeak = 0.60, Fallback = "FistHeavy",
			Active = 0.05, Recovery = 0.35,
			Range = 22, MinRange = 4, -- PROPOSAL: furthest / nearest trap spot
			Radius = 6, -- PROPOSAL: trigger + hit radius
			ArmTime = 0.3, Life = 8, -- PROPOSAL: arms after, melts after (seconds)
			Posture = 10, Stun = 0,
			Freeze = 1.5, -- sheet: roots / 1.5s stun
		},

		-- Ice V (ultimate). Sheet: area freeze, 200 dmg, 28s CD, 1.2s cast, UNBLOCKABLE, "freeze 3s
		-- immobilize entire area". Clap -> ground slam -> arms raised; the alchemy circle opens under the
		-- caster and the area is marked for everyone (danger ring); then the ground freezes over and ice
		-- erupts -- everyone inside takes the hit and is frozen 3s. PLACEHOLDER animation: "Fire 4".
		AbsoluteZero = {
			Kind = "Nova", Release = "GroundSlam", Element = "IceElement",
			Anim = "Alchemy_Fire4", AnimPeak = 0.52, Fallback = "FistHeavy",
			Active = 0.1, Recovery = 1.0, -- PROPOSAL recovery (big ultimate, punishable)
			Radius = 20, -- PROPOSAL: "entire area"
			SigilRadius = 8,
			Posture = 0, Stun = 0,
			Freeze = 3, -- sheet
		},

		-- ===== WIND (VFX: Assets.VFX.WindElement -- built for the kit from uploaded wind textures: crescent
		-- rbxassetid://112975276475052, streaks 115359771901722, ring 114110531684635. Animations are
		-- PLACEHOLDERS from the owner's existing set until Wind animations are made.) =====

		-- Wind Z. Sheet: compressed air, 50 dmg, 7s CD, 0.5s cast, BLOCKABLE, "fast projectile, good poke
		-- & edge pressure". Clap -> arm extend (a projectile) -> the owner's "Fire 3" backhand swipe throws
		-- a crescent of air.
		AirSlash = {
			Kind = "Projectile", Visual = "AirSlash", Release = "ArmExtend", Element = "WindElement",
			Anim = "Alchemy_Fire3", AnimPeak = 0.35, Fallback = "FistCombo2", -- "Fire 3" Hit marker
			Active = 0.05, Recovery = 0.3,
			Speed = 160, Range = 75, Radius = 2, -- PROPOSAL: faster and wider than Ignite ("fast poke")
			SpawnOffset = Vector3.new(0.6, 0.7, -2.5),
			Posture = 10, Stun = 0.35,
		},

		-- Wind X. Sheet: circular burst, 85 dmg, 10s CD, 0.7s cast, BLOCKABLE, "push-back + multi-hit split
		-- (can interrupt channeled moves)". Clap -> ground slam -> arms up ("Fire 4", PLACEHOLDER): three
		-- blasts of wind around the caster (25 + 25 + 35 = the sheet's 85), the last one shoves everyone
		-- away. Every blast stuns, so it breaks a cast in progress.
		GaleBurst = {
			Kind = "Burst", Release = "GroundSlam", Element = "WindElement",
			Anim = "Alchemy_Fire4", AnimPeak = 0.52, Fallback = "FistHeavy",
			Active = 0.45, Recovery = 0.4,
			Radius = 12, -- PROPOSAL
			Pulses = 3, Every = 0.2, -- PROPOSAL: the multi-hit split
			Push = 55, PushTime = 0.3, -- PROPOSAL: the push-back on the last blast
			Posture = 10,
			Hits = {
				Pulse = {Damage = 25, Stun = 0.35},
				Final = {Damage = 35, Stun = 0.6},
			},
		},

		-- Wind C. Sheet: launcher, 70 dmg, 11s CD, 0.6s cast, PARRYABLE, "launches enemy into air, enables
		-- aerial followups, short knockback". Clap -> ground slam -> an uppercut (the group "Uppercut"
		-- animation, PLACEHOLDER) that rides a column of wind: the same launch + air juggle as the Uppercut,
		-- so the caster rises with the target for follow-ups.
		RisingWind = {
			Kind = "Melee", Release = "GroundSlam", Element = "WindElement", Updraft = true,
			Anim = "Uppercut", AnimPeak = 0.28, Fallback = "FistUptilt",
			Active = 0.12, Recovery = 0.45,
			Hitbox = Vector3.new(6, 7, 7), Reach = 4,
			Posture = 15, Stun = 0.9,
			Velocity = "Uptilt", -- launch + air juggle (DamageManager)
		},

		-- Wind V (ultimate). Sheet: tornado, 235 dmg, 24s CD, 1.4s cast, UNBLOCKABLE, "pulls/lifts enemies,
		-- multi-hit (~3 ticks). Great disruption & zoning". Clap -> ground slam -> thrust ("Fire 1",
		-- PLACEHOLDER): the circle opens under the caster and the target spot is marked (danger ring); a
		-- tornado rises there, drags everyone nearby into it and lifts them, hitting 3 times (60 + 60 + 115
		-- = the sheet's 235); the last hit throws them up and out.
		TempestBreak = {
			Kind = "Tornado", Release = "GroundSlam", Element = "WindElement",
			Anim = "Alchemy_Fire1", AnimPeak = 0.60, Fallback = "FistHeavy",
			Active = 0.1, Recovery = 1.0,
			Range = 35, MinRange = 10, -- PROPOSAL: furthest / nearest tornado spot
			Radius = 9, PullRadius = 18, -- PROPOSAL: hit radius / pull radius
			Pull = 18, Lift = 9, -- PROPOSAL: pull speed toward the centre, lift inside it
			Ticks = 3, Every = 0.45, -- the sheet's ~3 ticks
			Height = 26, SigilRadius = 8,
			Posture = 0,
			Hits = {
				Tick = {Damage = 60, Stun = 0.6},
				Final = {Damage = 115, Stun = 1.0},
			},
		},

		-- ===== METAL (VFX: Assets.VFX.MetalElement -- sparks + part-built steel made for the kit; swap in
		-- the owner's Metal VFX when it exists. Animations are PLACEHOLDERS from the owner's set.) =====

		-- Metal Z. Sheet: wall/shield, 10s CD, cast 0, DEFENSIVE, "1.5s shield wall blocking frontal attacks
		-- & projectiles. Breaks after 70 dmg absorbed". Clap -> the wall rises in front of the caster at the
		-- clap (no slam) and stays 1.5s; Coldsteel Smash (BreaksShields) shatters it outright.
		SteelGuard = {
			Kind = "Shield", Release = "None", Element = "MetalElement",
			Window = 1.5, -- sheet
			Absorb = 70, -- sheet
			Arc = 0.2, -- PROPOSAL: "frontal" = within ~78 degrees of where the caster faces
			Active = 0.05, Recovery = 0.2,
			Posture = 0, Stun = 0,
		},

		-- Metal X. Sheet: tracking ground strike, 100 dmg, 12s CD, 0.8s cast, BLOCKABLE, "trails ground
		-- steel that auto-tracks; small delay before homing". Clap -> ground slam -> a second slam (PLACEHOLDER)
		-- sends steel spikes racing along the ground; after HomeDelay they home on the nearest enemy ahead;
		-- when they reach someone (or run out of range) an anvil drops there.
		CrushingAnvil = {
			Kind = "Tracker", Release = "GroundSlam", Element = "MetalElement",
			Anim = "Alchemy_GroundSlam", AnimPeak = 0.52, Fallback = "FistHeavy",
			Active = 0.05, Recovery = 0.4,
			Speed = 42, Range = 36, -- PROPOSAL (studs/s, studs)
			HomeDelay = 0.25, -- sheet: small delay before homing (PROPOSAL length)
			TurnRate = 540, -- PROPOSAL: degrees/s while homing (~4.5-stud turning circle at Speed)
			SeekRange = 30, SeekArc = 70, -- PROPOSAL: who it homes on (studs, degrees off its path)
			Contact = 3, SlamRadius = 5, -- PROPOSAL: reach to trigger the anvil, its hit radius
			Posture = 25, Stun = 0.8,
		},

		-- Metal C. Sheet: straight thrust, 75 dmg, 10s CD, 0.5s cast, PARRYABLE, "pins target for 1s on hit
		-- (follow-up window)". Clap -> arm extend (it shoots out of the hands) -> thrust ("Fire 1",
		-- PLACEHOLDER): a steel lance to the first enemy in line; on a clean hit they're pinned in place.
		MetalBind = {
			Kind = "Thrust", Release = "ArmExtend", Element = "MetalElement",
			Anim = "Alchemy_Fire1", AnimPeak = 0.60, Fallback = "FistCombo1",
			Active = 0.05, Recovery = 0.35,
			Range = 15, Radius = 1.5, -- PROPOSAL: the lance's reach and thickness
			Pin = 1.0, -- sheet: pinned 1s (stunned, can't move)
			Posture = 15, Stun = 1.0,
		},

		-- Metal V (ultimate). Sheet: precision ultimate, 300 dmg, 26s CD, 1.2s cast + 0.4s delay,
		-- UNBLOCKABLE, "true-type damage; bypasses some defensive buffs. High-risk, high-reward". Clap ->
		-- ground slam -> a giant steel blade forms over the caster while the line ahead is marked; at the
		-- end of the cast + delay it cleaves down the whole line. True damage: ignores damage resist
		-- (Cryo Shift) and shields (Steel Guard); dodging / i-frames still avoid it. PLACEHOLDER animation:
		-- the greatsword heavy.
		AlloyDivider = {
			Kind = "Cleave", Release = "GroundSlam", Element = "MetalElement",
			Anim = "Greatsword_Heavy", AnimPeak = 0.85, Fallback = "FistHeavy",
			Active = 0.1, Recovery = 1.2, -- PROPOSAL recovery (high risk)
			Length = 30, Width = 6, -- PROPOSAL: the line
			TrueDamage = true,
			SigilRadius = 8,
			Posture = 0, Stun = 1.0,
		},

		-- ===== EARTH (approved proposal 2026-10-14, built from the owner's prototypes in the Assets place:
		-- their rock + spike meshes, "EarthRise" sound and crack decal, in Assets.VFX.EarthElement). Rock
		-- takes the colour / material of the ground it rises from, like the prototypes. Numbers are
		-- PROPOSALS; animations are PLACEHOLDERS from the owner's set. =====

		-- Earth Z. A spike bursts from the ground at the aimed point (the circle marks it for the windup):
		-- a short knock-up and a bleed (the prototype's Rising Thorn bled).
		RisingThorn = {
			Kind = "Thorn", Release = "GroundSlam", Element = "EarthElement",
			Anim = "Alchemy_Fire1", AnimPeak = 0.60, Fallback = "FistHeavy",
			Active = 0.05, Recovery = 0.35,
			Range = 18, MinRange = 4, -- PROPOSAL: furthest / nearest spike spot
			Radius = 4, Height = 8, -- PROPOSAL: hit radius, spike height
			Life = 2, -- PROPOSAL: seconds the spike stands
			Lift = 32, -- PROPOSAL: knock-up speed
			Posture = 12, Stun = 0.6,
			Bleed = {Duration = 3, Every = 0.5, Damage = 2}, -- PROPOSAL (Earth's status: the prototype bled)
		},

		-- Earth X. A ring of spikes erupts around the caster: everyone inside is hit and stunned, and the
		-- spikes stand a moment as a barrier (visual).
		TectonicShift = {
			Kind = "Ring", Release = "GroundSlam", Element = "EarthElement",
			Anim = "Alchemy_GroundSlam", AnimPeak = 0.52, Fallback = "FistHeavy",
			Active = 0.1, Recovery = 0.45,
			Radius = 10, Count = 12, Height = 6, Life = 3, -- PROPOSAL
			Push = 22, -- PROPOSAL: shove out to the ring
			Posture = 20, Stun = 1.2, -- stun: approved proposal
		},

		-- Earth C. A wall of rock rises in front of the caster: solid cover for Life seconds that blocks
		-- movement and projectiles and can be climbed. Anyone standing where it rises is thrown up (and
		-- hit). One wall per caster (a new one replaces the old).
		EarthWall = {
			Kind = "Wall", Release = "GroundSlam", Element = "EarthElement",
			Anim = "Alchemy_Fire4", AnimPeak = 0.52, Fallback = "FistHeavy",
			Active = 0.05, Recovery = 0.3,
			Distance = 5, Width = 6, Height = 7, Thickness = 1.6, -- PROPOSAL
			Life = 6, -- approved proposal (the prototype's 60s could wall off an arena)
			Lift = 45, -- PROPOSAL
			Posture = 0, Stun = 0.5,
			-- the wall itself is DEFENSIVE (no damage); being thrown up by it is a hit (PROPOSAL class)
			Hits = {Lift = {Damage = 30, Class = "BLOCKABLE", Stun = 0.5}},
		},

		-- Earth V (ultimate). The line ahead is marked for the whole cast; then pillars race along it in
		-- Waves (60 + 60 + 120): each wave hits everyone in the line and pops them up, the last throws
		-- them. UNBLOCKABLE (telegraphed by the line).
		EarthPillars = {
			Kind = "Fault", Release = "GroundSlam", Element = "EarthElement",
			Anim = "Alchemy_GroundSlam", AnimPeak = 0.52, Fallback = "FistHeavy",
			Active = 0.1, Recovery = 1.1, -- PROPOSAL recovery (big ultimate)
			Length = 45, Width = 6, -- approved proposal: 45 studs
			Waves = 3, Every = 0.3, Travel = 0.35, -- PROPOSAL: waves, gap, time to cross the line
			SigilRadius = 8,
			Posture = 0,
			Hits = {
				Wave = {Damage = 60, Stun = 0.6},
				Final = {Damage = 120, Stun = 1.0},
			},
		},
	},
}

-- ===== Status effects (user request 2026-10-14) =====
-- The user's Status Effects VFX (Assets place: Fire, Freeze, Bleed, Shock), each with a real effect.
-- Applied by StatusManager (alchemy hits, the daggers' bleed). A status shows its VFX on the victim for
-- as long as it lasts; re-applying refreshes it (never stacks). Damage ticks scale with the source's
-- Alchemy stat for alchemy. SHEET = from the alchemy design sheet; everything else is a PROPOSAL.
TuningConfig.Status = {
	-- damage over time: 5 per second for 4s = 20 (SHEET, Ignite)
	Burn = {VFX = "Fire", Every = 1, Damage = 5, Duration = 4},
	-- frozen solid: can't move, jump, attack, block or dash; the body locks in place (SHEET durations:
	-- Cryo Shift 1.5s, Absolute Zero 3s, set per move). Used by the Ice kit.
	Freeze = {VFX = "Freeze", Duration = 1.5},
	-- damage over time: 2 every 0.5s for 1.5s (the daggers' Lacerate passive)
	Bleed = {VFX = "Bleed", Every = 0.5, Damage = 2, Duration = 1.5},
	-- PROPOSAL (no source gives values): every 0.5s for 1.5s a jolt deals 2 and stuns for 0.15s,
	-- interrupting a windup in progress. Not applied by any move yet.
	Shock = {VFX = "Shock", Every = 0.5, Damage = 2, Jolt = 0.15, Duration = 1.5},
}

-- ===== Downed actions (controls doc: V carry / B grip, only on a knocked target in range) =====
-- PROPOSALS. A player (or an enemy with Knockable) whose health would hit 0 is KNOCKED instead:
-- they slump, can't act, and can't be hurt further. After KnockedTime they get back up with
-- RecoverHealth of their max health -- unless someone grips them (the finisher) first.
-- Grip ends in an ordinary death. The PvP / permadeath / anti-gank consequences of a grip are
-- NOT decided yet and are not implemented.
TuningConfig.Downed = {
	KnockedTime = 20,
	RecoverHealth = 0.15,
	GripRange = 6,
	GripTime = 2.0, -- length of the grip animations
	CarryRange = 6,
	CarryWalkSpeed = 11,
}

-- ===== PvE enemies (controls doc: Dummy, Grunt, Elite with block/parry AI; same combat rules as
-- players) =====
-- ALL numbers are PROPOSALS. Enemies attack through the same AttackRunner / hitbox / damage /
-- posture / stun code as players, using the fist (or their weapon's) attacks above.
-- The training dummies already in World.Live are the "Dummy" tier.
--   DamageMult      -> the enemy's PhysicalMultiplier (player damage scaling uses the same attribute)
--   AggroRange      start chasing a player this close; LeashRange: give up this far from the spawn
--   Combo           lights per string (min, max); HeavyChance per string
--   Pause           idle gap between strings (min, max seconds)
--   Elite only: ParryChance / BlockChance per incoming attack it sees coming; Reaction = how long
--   it takes to notice a windup; BlockHold = how long a held guard lasts.
TuningConfig.Enemies = {
	Grunt = {
		DisplayName = "Bandit", Level = 2, Health = 400, DamageMult = 0.8,
		WalkSpeed = 14, AggroRange = 40, LeashRange = 90, AttackRange = 5,
		Combo = {2, 4}, HeavyChance = 0.15, Pause = {0.7, 1.4},
		RespawnTime = 20, BodyColor = Color3.fromRGB(120, 92, 70),
	},
	Elite = {
		DisplayName = "Bandit Duelist", Level = 5, Health = 900, DamageMult = 1.0,
		WalkSpeed = 15, AggroRange = 50, LeashRange = 100, AttackRange = 6,
		Combo = {2, 4}, HeavyChance = 0.3, Pause = {0.4, 0.9},
		-- Tested: at 0.45 / 0.35 it stopped 9 of 10 fist lights (a guard press on a fast light also
		-- opens the parry window), so these are lowered.
		ParryChance = 0.25, BlockChance = 0.3, Reaction = {0.1, 0.2}, BlockHold = {0.4, 0.9},
		-- (weapon: every enemy rolls one of the creator's starting weapons; EnemyService.PickWeapon.
		-- Looks are rolled per spawn too, so BodyColor is no longer used.)
		Knockable = true, -- gets knocked like a player: grip it (B) to finish it
		RespawnTime = 45, BodyColor = Color3.fromRGB(45, 45, 55),
	},
}

-- Alchemy trial foes (TrialService, 2026-10-16): Duelist-based, each with its own name and numbers.
-- Their "alchemy" is the arena hazards TrialService runs (Rensei.Trials). All PROPOSALS.
for Name, Over in pairs({
	TrialFlame = {DisplayName = "Corin Vale, Burned Apprentice", Level = 6, Health = 1100, DamageMult = 0.9, WalkSpeed = 16,
		ParryChance = 0.45, BlockChance = 0.3, AggroRange = 70, LeashRange = 140},
	TrialIce = {DisplayName = "Crystallized Guardian", Level = 7, Health = 1300, DamageMult = 1.0, WalkSpeed = 12,
		ParryChance = 0.2, BlockChance = 0.5, AggroRange = 70, LeashRange = 140, HeavyChance = 0.45},
	TrialEarth = {DisplayName = "Dask, the Quarry Breaker", Level = 7, Health = 1250, DamageMult = 1.0, WalkSpeed = 14,
		ParryChance = 0.25, BlockChance = 0.35, AggroRange = 70, LeashRange = 140},
	TrialWind = {DisplayName = "Siv, the Gale Dancer", Level = 7, Health = 1000, DamageMult = 0.9, WalkSpeed = 19,
		ParryChance = 0.35, BlockChance = 0.2, Pause = {0.3, 0.7}, AggroRange = 70, LeashRange = 140},
	TrialMetal = {DisplayName = "The Armored Experiment", Level = 8, Health = 1600, DamageMult = 1.1, WalkSpeed = 12,
		ParryChance = 0.15, BlockChance = 0.45, HeavyChance = 0.4, AggroRange = 70, LeashRange = 140},
}) do
	local D = table.clone(TuningConfig.Enemies.Elite)
	for K, V in pairs(Over) do D[K] = V end
	D.RespawnTime = 1e9 -- trial foes are spawned per run, never respawned
	D.TrialFoe = true
	TuningConfig.Enemies[Name] = D
end

-- Weapon dash attacks (owner 2026-10-15: "dash attacks for weapons to make them feel more custom").
-- Running + LMB with a weapon drawn uses its class's dash attack instead of the fist one; each entry
-- overrides TuningConfig.DashAttack (anything left out is inherited). ALL numbers are PROPOSALS.
-- Animations are the weapons' own swings (fist fallback until they're published).
TuningConfig.WeaponDashAttacks = {
	Sword = {Name = "Rising Cut", Anim = "Sword_Light4", AnimPeak = 0.38, Startup = 0.18, Active = 0.12, Recovery = 0.42,
		Damage = 26, Posture = 16, Reach = 5, Hitbox = Vector3.new(8, 6, 9), Lunge = 70, LungeTime = 0.26, Cooldown = 2.2},
	Rapier = {Name = "Lunging Thrust", Anim = "Rapier_Light2", AnimPeak = 0.29, Startup = 0.14, Active = 0.1, Recovery = 0.35,
		Damage = 20, Posture = 10, Reach = 6.5, Hitbox = Vector3.new(4, 5, 11), Lunge = 85, LungeTime = 0.3, Velocity = "Pull", Cooldown = 1.8},
	Greatsword = {Name = "Cleaving Charge", Anim = "Greatsword_Light1", AnimPeak = 0.78, Startup = 0.32, Active = 0.16, Recovery = 0.6,
		Damage = 34, Posture = 24, Stun = 0.8, Reach = 5, Hitbox = Vector3.new(11, 7, 9), Lunge = 50, LungeTime = 0.3, HyperArmor = true,
		Stamina = 16, Cooldown = 3.0},
	Daggers = {Name = "Shadow Step", Anim = "Daggers_Light2", AnimPeak = 0.39, Startup = 0.12, Active = 0.16, MultiHit = 2, Recovery = 0.3,
		Damage = 11, Posture = 6, Reach = 4, Hitbox = Vector3.new(6, 6, 8), Lunge = 90, LungeTime = 0.22, Velocity = "Pull", Cooldown = 1.6},
	Gauntlets = {Name = "Shoulder Charge", Anim = "Gauntlets_Heavy", AnimPeak = 0.88, Startup = 0.18, Active = 0.14, Recovery = 0.45,
		Damage = 24, Posture = 22, Stun = 0.8, Reach = 4, Hitbox = Vector3.new(7, 6, 8), Lunge = 75, LungeTime = 0.26, Cooldown = 2.2},
	Guns = {Name = "Pistol Whip", Anim = "FistHeavy", Startup = 0.16, Active = 0.12, Recovery = 0.4,
		Damage = 18, Posture = 16, Reach = 4, Hitbox = Vector3.new(6, 6, 7), Lunge = 60, LungeTime = 0.24, Cooldown = 2.0},
}

-- Fist fallbacks for any weapon animation that is not in the game (or not published yet).
do
	local LightFallback = {"FistCombo1", "FistCombo2", "FistCombo3", "FistCombo5"}
	for Class, W in pairs(TuningConfig.Weapons) do
		W.Class = Class
		for I, H in ipairs(W.Light.Hits) do
			H.Fallback = H.Fallback or LightFallback[I] or "FistCombo1"
			-- combo hits (not the finisher, not gunshots) hold the target long enough to chain
			if I < #W.Light.Hits and not W.Ranged then H.Stun = math.max(H.Stun or 0, TuningConfig.Light.MinStun) end
		end
		W.Heavy.Fallback = W.Heavy.Fallback or "FistHeavy"
		W.Heavy.Telegraph = true -- crit warning flash during the windup
		-- IdleAnim: standing idle while drawn. HoldAnim: weapon-only pose kept under every other
		-- animation, so attacks that don't animate the weapon still hold it naturally.
		W.IdleAnim = W.IdleAnim or (Class .. "_Idle")
		W.Skill.Fallback = W.Skill.Fallback or "FistCombo5"
		-- the class's dash attack: the fist one with this weapon's overrides
		local Dash = table.clone(TuningConfig.DashAttack)
		for K, V in pairs(TuningConfig.WeaponDashAttacks[Class] or {}) do Dash[K] = V end
		Dash.Fallback = Dash.Fallback or "FistCombo1"
		W.DashAttack = Dash
	end
end

return TuningConfig

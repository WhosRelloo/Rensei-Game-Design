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
	OnShotHit = 2, -- PROPOSAL (gun rework): a gun shot that lands (melee hits stay OnLightHit 4)
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
--   * hitstun 0.6s on lights (DH Stuntime), longer than the swing-to-swing gap (0.37 s on fists since the 2026-10-19 M1 pass), so a landed
--     string stays a true combo instead of letting the target slip out or block between hits;
--   * the combo remembers its place for 2s (DH ComboReset);
--   * you keep moving while you fight: DH walk 15 -> 13 swinging, 10 heavy, 12 blocking, 4 stunned
--     (scaled to Rensei's 16 below).
TuningConfig.Light = {
	ComboReset = 2.0, -- seconds after a swing ends before the combo starts over (DH; was 1.0)
	JumpAttackLandLead = 0.25, -- s: an M1 this close to landing is a normal light, not a jump attack (it reached the
	-- server after landing and fizzled; fluidity pass 2026-10-18, PROPOSAL)
	WhiffRecovery = 0.15, -- extra recovery when a swing hits nothing (and the combo resets)
	AttackWalkSpeed = 14, -- walk speed while swinging (DH 13/15; was 6)
	MinStun = 0.6, -- every weapon's non-finisher lights stun at least this long (DH Stuntime)
	Hits = {
		{Anim = "FistCombo1", Startup = 0.19, Active = 0.08, Recovery = 0.10, Damage = 17, Posture = 8, Stun = 0.6, Velocity = "Pull", Hitbox = LightHitbox, Reach = 3.5}, -- PROPOSAL (2026-10-19 M1 pass): Startup 0.22 -> 0.19, Recovery 0.16 -> 0.10
		{Anim = "FistCombo2", Startup = 0.19, Active = 0.08, Recovery = 0.10, Damage = 17, Posture = 8, Stun = 0.6, Velocity = "Pull", Hitbox = LightHitbox, Reach = 3.5}, -- PROPOSAL (2026-10-19 M1 pass): Startup 0.22 -> 0.19, Recovery 0.16 -> 0.10
		{Anim = "FistCombo3", Startup = 0.19, Active = 0.08, Recovery = 0.10, Damage = 17, Posture = 8, Stun = 0.6, Velocity = "Pull", Hitbox = LightHitbox, Reach = 3.5}, -- PROPOSAL (2026-10-19 M1 pass): Startup 0.22 -> 0.19, Recovery 0.16 -> 0.10
		{Anim = "FistCombo5", Startup = 0.26, Active = 0.10, Recovery = 0.40, Damage = 24, Posture = 14, Stun = 0.9, Velocity = "Knockback", Hitbox = LightHitbox, Reach = 3.5}, -- PROPOSAL (2026-10-19 M1 pass): Startup 0.28 -> 0.26, Recovery 0.55 -> 0.40 (string 2.31 -> 1.87 s)
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
TuningConfig.HitStun = {
	WalkSpeed = 4,
	-- no infinite combos (owner 2026-10-18; DamageManager): after MaxChain s of unbroken hitstun, hits stop
	-- stunning for ChainBreak s so the target can act. A full string is ~1.8 s; string + heavy / skill ~2.6 s. PROPOSAL
	MaxChain = 3.0,
	ChainBreak = 0.6,
}

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
-- VV: Ultimatum rework (owner-approved 2026-10-19, "make the parrying more like VV ultimatum's"; numbers PROPOSAL):
--   * window 0.25s (ping allowance kept);
--   * a parry costs the parrier nothing; the attacker loses 30 posture and staggers 1.0s (ParryFlinch), so
--     3-4 parries break them -- a parry that empties their posture is a full guard break (Posture.BreakStun);
--   * a missed TAP is punished: WhiffTime s with no guard and no parry after the window closes (holding F
--     through the window just keeps blocking), and the parry is locked for Cooldown s after the window
--     (was 1.3s from the press). Landed parries still chain with no cooldown.
TuningConfig.Parry = {
	Window = 0.25, -- PROPOSAL (VV parry 2026-10-20): 0.22 -> 0.25
	ChainBonus = 0.04,
	PingThreshold = 0.1, -- seconds
	PingBase = 0.2, PingPerMs = 0.0005, PingClampMs = 300,
	Cooldown = 0.9, -- PROPOSAL (VV parry 2026-10-20): counted from the window's end (was 1.3 from the press)
	WhiffTime = 0.35, -- PROPOSAL (VV parry 2026-10-20): a missed tap leaves you with no guard this long
	AttackerPostureDamage = 30, -- PROPOSAL (VV parry 2026-10-20): 10 -> 30
	AttackerStun = 1.0, -- PROPOSAL (VV parry 2026-10-20): 0.7 -> 1.0
	AttackerPush = 30, AttackerPushTime = 0.12,
	DefenderPostureCost = 0, -- PROPOSAL (VV parry 2026-10-20): 5 -> 0, a parry never costs you posture
}
-- the whole lockout from the press (window + cooldown), read by the cooldown HUD
TuningConfig.Parry.FailLockout = TuningConfig.Parry.Window + TuningConfig.Parry.Cooldown
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
	GrabBuffer = 0.25, -- s: Space pressed in the air this long before a wall is in reach still grabs it (fluidity 2026-10-18)
	ClimbProbeExtra = 2, -- studs added to the climb's wall probe so it finds the wall behind a jutting ledge / trim
	ClimbOutRate = 10, -- studs/s the climber glides out from / back to the wall past a jutting ledge (was an instant jump)
	-- Directional climb (controls doc: tap Space on a wall, WASD moves on it, stamina drain, no
	-- combat, touch the ground to reset). PROPOSAL speeds / drain.
	ClimbStart = 10,
	ClimbStep = 8, -- Space + W leap up the wall
	ClimbSpeed = 9, -- studs/s up (pulled in steps)
	ClimbDownSpeed = 7, -- studs/s down (the ClimbDown loop, 2026-10-18)
	ClimbSideSpeed = 6, -- studs/s sideways (the ClimbSideRight / Left loops; 0.7 of it on a diagonal)
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
	-- Ungrippable edges (Region Foundation Task 10b, owner 2026-10-24: "Ungrippable edges"): a part with this
	-- CollectionService tag, or inside a Model with it, can't be grabbed by a climb, a climb leap or a wall run
	-- (JumpManager.Grippable = MovementState.Grippable, also used by the server's wall check). It can still be stood
	-- on and collided with. Region edge walls and cliffs carry it (the region builder's rs_tags).
	NoGripTag = "RenseiNoGrip",
}

-- Traversal state (Managers.MovementState, 2026-10-17). The server owns which traversal a character is in
-- and ends it on stun / knock / grip / carry / death or when the wall is gone. ALL PROPOSALS.
TuningConfig.Traversal = {
	ValidateReach = 9, -- server: a wall must be this close to start / keep a climb or wall run (client reach 5 + lag slack)
	CheckEvery = 0.5, -- server re-check interval while a traversal is active (nothing runs while none is)
	ValidateGrace = 0.5, -- s the server re-checks a start that failed only the wall / ledge check (it sees moving players late)
	MissesToEnd = 2, -- consecutive re-checks without a wall in reach before the server ends it
	WallRunGrace = 1.0, -- seconds past Parkour.WallRunDuration (x Acrobat) before the server ends a wall run
	FXMinInterval = 0.12, -- per effect type: the fastest one player may broadcast a movement effect (JumpRemote PlayFX)
}

-- Basic swimming (owner decision 6, 2026-10-18: "allow deep water with a swim state (no combat or alchemy while
-- swimming)"). Roblox's own terrain-water swimming moves the character; the SERVER (SwimService) decides the
-- Traversal = "Swim" state, which carries the Climbing status (no attacks, alchemy, skills, sprint, roll or crouch)
-- and puts the weapon away (Combat Mode off; it can't be turned on while swimming). Numbers are PROPOSAL.
TuningConfig.Swim = {
	CheckEvery = 0.15, -- server check interval per player
	WaterOccupancy = 0.6, -- a terrain-water cell at least this full at the root (or just below it) counts as deep water
	Below = 2, -- studs below the root also checked (a floating character's root sits near the surface)
	ExitChecks = 2, -- checks in a row out of deep water before the swim state ends (no flicker at the surface)
	AnimIdle = "Swim_Idle", AnimMove = "Swim_Forward", -- the owner's registry animations (now in Shared.Movement.Swim)
	MoveThreshold = 0.1, -- MoveDirection magnitude above which the forward stroke plays
	-- extras (owner 2026-10-18: "add swimming extras"), all PROPOSAL:
	-- swim sprint: hold the sprint key (Shift) while swimming and moving; costs stamina (server-drained)
	AnimSprint = "Swim_Sprint",
	SprintMult = 1.6, -- x your normal walk speed
	SprintStamina = 14, -- stamina per second while sprint-swimming
	SprintMinStamina = 10, -- needed to start a sprint
	-- breath: drains while your head is under the water's surface (diving), refills above it
	BreathMax = 15, -- seconds of air
	BreathRefill = 5, -- seconds of air regained per second at the surface / on land
	-- damage per DrownTick once out of air (through DownedManager: at 0 HP you're knocked out, not killed):
	-- DrownFraction of max health, at least DrownDamage. A flat 8 was out-healed by Roblox's own regen (~1% of
	-- max health per second, about 6/s at 580 HP), so drowning could never knock anyone out (tested 2026-10-18).
	DrownDamage = 8,
	DrownFraction = 0.06, -- 6% of max health per second: about 17 s from full health to knocked out
	DrownTick = 1,
	HeadAbove = 0.4, -- studs: the head counts as underwater when its centre is this far below the surface
}

-- Coordinated enemy squads (owner prompt "Advanced Swarm NPC Combat AI", 2026-10-18; VV Ultimatum / Archived as a
-- behaviour reference). ServerScriptService.CombatDirector runs one encounter per target player: enemies surround
-- the player, but only the holder of that encounter's ATTACK TOKEN may hurt that player (DamageManager enforces it).
-- The token passes on a strong knockback, death, a long stun, a knock-out, target loss, despawn or getting stuck.
-- All numbers are PROPOSAL.
TuningConfig.Squad = {
	Enabled = true,
	Tick = 0.2, -- director: token / handoff checks per encounter
	SlotTick = 0.45, -- director: surround positions (throttled; members walk there between updates)
	CommitDelay = 0.35, -- a new attacker waits this long after taking the token before its first hit (approach + face)
	HandoffDelay = 0.2, -- gap between one attacker losing the token and the next getting it (state cleanup, readability)
	Grace = 0.25, -- after a NORMAL release the old holder's last hit may still land (none after a forced revoke)
	CastLinger = 1.4, -- a holder that just cast keeps the token this long (its projectile / explosion is still out)
	Tenure = 9, -- a holder hands over at the next safe moment after this long, if someone else is ready
	StunHandoff = 0.8, -- seconds stunned (parry, guard break, long hitstun) before the token moves on
	KnockbackHandoff = 45, -- a knockback at least this strong (studs/s) moves the token at once
	Separation = 9, -- studs beyond its attack range a holder may be before it counts as separated
	SeparatedFor = 2.5, -- ... for this long (stuck behind something, or knocked away without a knockback)
	Recover = 1.2, -- after losing the token by force, seconds before it can take it again
	RecentPenalty = 6, -- selection: studs added to an enemy that held the token in the last RecentFor seconds
	RecentFor = 4,
	BehindPenalty = 5, -- selection: studs added to an enemy behind the player (attacks start where the player can see)
	MaxMembers = 8, -- per encounter; extra enemies keep their distance (outer reserve ring)
	ReactiveWindow = 1.5, -- a counter (Cryo Shift) triggered by the player's own hit may land without the token
	-- surround ring (studs from the player); melee members stand outside attack range while waiting
	Ring = {Melee = 8.5, Prepare = 6.5, Ranged = 16, Reserve = 13},
	-- slot angles (degrees) relative to the token holder's side of the player; never in the holder's lane
	Slots = {70, -70, 125, -125, 180, 35, -35},
	Drift = 14, -- degrees: slow circling of each waiting slot
	DriftSpeed = 0.35,
	SlotHysteresis = 25, -- degrees: a member keeps its slot unless another is this much closer to it
	TargetSwitchMargin = 8,
	FairnessCap = 20, FairnessWeight = 0.6, -- PROPOSAL: a waiting member's claim grows 0.6 per second waited, up to 20 s -- studs: an enemy changes target only for a player this much closer than its current one
	Debug = false, -- Studio only: slot markers + role labels (also: workspace attribute SquadDebug = true)
	-- personalities change decisions and positioning, not health or damage
	Personalities = {
		Aggressor = {Bias = -3, Tenure = 1.0, Ring = 1.0}, -- takes the token readily, presses in
		Duelist = {Bias = 0, Tenure = 0.8, Ring = 1.1}, -- shorter turns, circles wider
		Alchemist = {Bias = 1, Tenure = 0.9, Ring = 1.5, Ranged = true}, -- keeps casting distance while waiting
		Defender = {Bias = 3, Tenure = 0.7, Ring = 1.0}, -- prefers guarding; attacks last
		Gunner = {Bias = 1, Tenure = 0.9, Ring = 1.0, Ranged = true},
	},
	PersonalityOf = {
		Grunt = "Aggressor", AditScavenger = "Aggressor", Elite = "Duelist",
		FieldAlchemist = "Alchemist", FrostAlchemist = "Alchemist", GaleAlchemist = "Alchemist", StoneAlchemist = "Alchemist",
		WardAlchemist = "Defender",
	},
}

-- Narrow wall-ledge walk (JumpManager.LedgeWalk, owner 2026-10-17; the Tomb Raider cliff-ledge walk). AUTHORED
-- ledges only: parts tagged Tag, front face toward the wall, length = the path (see JumpManager.LedgeWalk for
-- the authoring rules). No stamina cost. ALL numbers PROPOSALS.
TuningConfig.LedgeWalk = {
	Enabled = true,
	Tag = "RenseiLedge", -- CollectionService tag for a ledge strip
	FaceWall = true, -- face the wall (the reference); kept for clarity
	-- Animation while on the ledge. The sheet's only ledge animation, "Wall Ledge Walk Left" (LedgeWalk_Left), is
	-- posed BACK to the wall; it's the closest asset until a face-the-wall sidestep exists (upload it, put its name
	-- here). It plays backwards for moving right and holds its first frame standing still.
	Anim = "LedgeWalk_Left", AnimRight = "LedgeWalk_Right",
	AnimSpeed = 1,
	WallGap = 1.0, -- how far the root sits from the strip's front edge (the wall); closer and the head / hair
	-- touch the wall and physics tips the body back
	Speed = 5, -- sidestep studs/s
	EndMargin = 0.6, -- how close to an end the body's centre may get
	JoinDistance = 1.5, -- ledge ends this close (and level within JoinHeight) continue into each other
	JoinHeight = 0.75,
	PlatformStep = 1.2, -- how far past an end to look for a platform to step off onto
	BodyHalfWidth = 1.1, -- obstacle probe along the ledge
	InputDeadzone = 0.35,
	CheckEvery = 0.15, -- entry check interval (client; only while on your feet and free)
	EnterChecks = 2, -- consecutive checks standing on a ledge before stepping in
	Responsiveness = 120, -- AlignPosition responsiveness
	StepOffHold = 0.3, -- hold away from the wall this long to step down
	StepOffSpeed = 10,
	HopAway = 18, HopUp = 28, -- Space: hop back off the wall
	ClimbHop = 26, -- Space while pushing toward the wall: hop up into the climb
	-- climb -> ledge walk hand-over (2026-10-18, owner: "make it smoother to go from a climb into a ledge walk")
	FromClimb = true,
	ClimbDownReach = 1.5, -- climbing down: a ledge this far (studs) below the feet takes over
	ClimbSideReach = 0.6, -- climbing sideways: only a ledge the feet are already at
	ClimbSettle = 0.3, -- seconds the body eases onto the strip (soft AlignPosition firming up)
	ClimbSettleResponsiveness = 20, -- AlignPosition responsiveness at the start of the settle
	ClimbBlend = 0.25, -- seconds the climb pose blends into the ledge pose
	RegrabCooldown = 0.8, -- after leaving, how soon you can step onto a ledge again
	RefusedCooldown = 2, -- after the server ends / refuses it
	ServerTolerance = 1.5, -- studs past an endpoint the server allows (lag) before it ends the ledge walk
	ServerAbove = 7, -- studs: highest the root may be over the strip's top for the server (was 6; the server sees a
	-- climber coming down onto the ledge slightly late, and refused the hand-over at 6.5)
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
-- 2026-10-17 (sheet pass 3): Katana M1 1-4, Greatsword M1 1-4 + CRIT, Dagger M1 1-4 + CRIT now play the
-- sheet ids (all published under the Rensei group); AnimPeak = each one's Hit keyframe (Dagger CRIT has none:
-- measured fastest motion, 0.54). The old greatsword overhead lives on as Alchemy_GreatswordOverhead.
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
		Draw = {Equip = "Sword_Equip", SwapAt = 0.05, Unequip = "Sword_Equip", UnequipReverse = true, UnequipSpeed = 1.2, UnequipSwapAt = 0.7}, -- Sword_Sheathe: sheet id broken (2026-10-18)
		RunAnim = "Sword_Run",
		WalkAnim = "Sword_Walk", -- Animation ID's sheet (2026-10-18)
		IdleAnim = "Sword_Idle", -- Animation ID's sheet (2026-10-16)
		HoldAnim = "Sword_Hold",
		-- M1 1-4 from the Animation ID's sheet (pass 3, 2026-10-17: Katana1-4); AnimPeak = each animation's Hit keyframe
		Light = {Hits = {
			Hit{Anim = "Sword_Light1", AnimPeak = 0.35, Startup = 0.22, Active = 0.08, Recovery = 0.10, Damage = 20, Posture = 9, Stun = 0.45, Velocity = "Pull", Hitbox = Vector3.new(7, 6, 8), Reach = 4}, -- PROPOSAL (2026-10-19 M1 pass): Startup 0.24 -> 0.22, Recovery 0.18 -> 0.10
			Hit{Anim = "Sword_Light2", AnimPeak = 0.32, Startup = 0.22, Active = 0.08, Recovery = 0.10, Damage = 20, Posture = 9, Stun = 0.45, Velocity = "Pull", Hitbox = Vector3.new(7, 6, 8), Reach = 4}, -- PROPOSAL (2026-10-19 M1 pass): Startup 0.24 -> 0.22, Recovery 0.18 -> 0.10
			Hit{Anim = "Sword_Light3", AnimPeak = 0.32, Startup = 0.22, Active = 0.08, Recovery = 0.10, Damage = 20, Posture = 9, Stun = 0.45, Velocity = "Pull", Hitbox = Vector3.new(7, 6, 8), Reach = 4}, -- PROPOSAL (2026-10-19 M1 pass): Startup 0.24 -> 0.22, Recovery 0.18 -> 0.10
			Hit{Anim = "Sword_Light4", AnimPeak = 0.30, Startup = 0.30, Active = 0.10, Recovery = 0.46, Damage = 27, Posture = 16, Stun = 0.9, Velocity = "Knockback", Hitbox = Vector3.new(8, 6, 9), Reach = 4}, -- PROPOSAL (2026-10-19 M1 pass): Recovery 0.50 -> 0.46 (string 2.40 -> 2.06 s)
		}},
		-- hotfix 2026-10-23 (owner: a crit more suited to the katana): the published katana "Quick Draw" (skill sheet) -- one
		-- iaido draw-cut; its cut lands at 0.88 s at 1x, here 1.25x -> 0.70 s, inside Startup 0.66 + Active 0.1. Was Sword_Heavy,
		-- an unpublished Studio save ("sword crit", plays nothing live). PROPOSAL: AnimSpeed 1.25, Startup 0.42 -> 0.66.
		Heavy = {Anim = "Sword_QuickDraw", AnimSpeed = 1.25, Startup = 0.66, Active = 0.1, Recovery = 0.5, Damage = 36, Posture = 40, Stun = 0.9, Velocity = "Knockback", Hitbox = Vector3.new(8, 7, 9), Reach = 4.5, Step = 18, Cooldown = 1.3},
		-- Dragonflash: a lunging slash.
		-- hotfix 2026-10-23: Sword_Skill is an unpublished Studio save (empty id: plays nothing in a live server, and in Studio it
		-- ran clamped at 2.2x). Now the published katana "Iaido Barrage" (skill sheet), its 4 cuts on its own markers at 1x.
		-- PROPOSAL: 8 dmg x 4 (was 30 x 1), Pull so the cuts connect; the opening lunge kept. Also the Sword class skill's anim.
		Skill = {Name = "Dragonflash", Anim = "Sword_IaidoBarrage", AnimSpeed = 1, Startup = 0.42, Active = 0.87, HitTimes = {0.47, 0.72, 0.99, 1.23}, Recovery = 0.45, Damage = 8, Posture = 6, Stun = 0.5, Velocity = "Pull", Hitbox = Vector3.new(8, 6, 10), Reach = 4.5, Lunge = 75, LungeTime = 0.3, Stamina = 20, Cooldown = 7},
		-- Keen Edge: blocked hits deal +30% posture damage.
		Passive = {Name = "Keen Edge", BlockedPostureMult = 1.3},
	},

	Rapier = {
		Display = "Rapier",
		-- Borrows the sword's draw / sheathe, run and hold (same grip as the katana); its idle is its own (Rapier_Idle).
		Draw = {Equip = "Sword_Equip", SwapAt = 0.05, Unequip = "Sword_Equip", UnequipReverse = true, UnequipSpeed = 1.2, UnequipSwapAt = 0.7}, -- Sword_Sheathe: sheet id broken (2026-10-18)
		RunAnim = "Sword_Run",
		IdleAnim = "Rapier_Idle", -- Animation ID's sheet (2026-10-16)
		WalkAnim = "Rapier_Walk", -- Animation ID's sheet (2026-10-16)
		HoldAnim = "Sword_Hold",
		-- Rapier M1 1-4 from the Animation ID's sheet (re-wired 2026-10-19). AnimPeak measured 2026-10-19 (was 0.37, the
		-- old ids' "Hit" markers): the keyframe where the blade tip moves fastest in the forward thrust, from the
		-- KeyframeSequence (R6 Torso > Right Arm > Hilt chain from the poses, Hilt at (0, -0.65, 0), tip 4.25 studs down
		-- the blade; a keyframe's speed = the mean of its two neighbouring keyframe intervals).
		Light = {Hits = {
			Hit{Anim = "Rapier_Light1", AnimPeak = 0.38, Startup = 0.21, Active = 0.07, Recovery = 0.10, Damage = 14, Posture = 6, Stun = 0.4, Velocity = "Pull", Hitbox = Vector3.new(4, 5, 10), Reach = 5}, -- PROPOSAL (2026-10-19 M1 pass): Startup 0.18 -> 0.21 (windup 1.77x -> 1.55x), Recovery 0.14 -> 0.10
			Hit{Anim = "Rapier_Light2", AnimPeak = 0.33, Startup = 0.18, Active = 0.07, Recovery = 0.10, Damage = 14, Posture = 6, Stun = 0.4, Velocity = "Pull", Hitbox = Vector3.new(4, 5, 10), Reach = 5}, -- PROPOSAL (2026-10-19 M1 pass): Recovery 0.14 -> 0.10
			Hit{Anim = "Rapier_Light3", AnimPeak = 0.38, Startup = 0.21, Active = 0.07, Recovery = 0.10, Damage = 14, Posture = 6, Stun = 0.4, Velocity = "Pull", Hitbox = Vector3.new(4, 5, 10), Reach = 5}, -- PROPOSAL (2026-10-19 M1 pass): Startup 0.18 -> 0.21 (windup 1.77x -> 1.55x), Recovery 0.14 -> 0.10 (string 1.94 -> 1.88 s)
			Hit{Anim = "Rapier_Light4", AnimPeak = 0.40, Startup = 0.24, Active = 0.08, Recovery = 0.45, Damage = 20, Posture = 12, Stun = 0.8, Velocity = "Knockback", Hitbox = Vector3.new(4, 5, 11), Reach = 5.5},
		}},
		-- Rapier CRIT from the Animation ID's sheet (2026-10-19 id, 1.35 s, no marker). AnimPeak measured 2026-10-19 the
		-- same way as the M1s (blade-tip speed peak at the 0.717 s keyframe; was 0.43 on the old id).
		Heavy = {Anim = "Rapier_Heavy", AnimPeak = 0.72, Startup = 0.47, Active = 0.1, Recovery = 0.4, Damage = 30, Posture = 30, Stun = 0.8, Velocity = "Knockback", Hitbox = Vector3.new(4, 5, 12), Reach = 6, Step = 22, Cooldown = 1.1}, -- PROPOSAL (2026-10-19 M1 pass): Startup 0.34 -> 0.47: the new CRIT played at 1.85x, now 1.38x (a longer windup on the punish)
		-- Flurry: five fast thrusts.
		Skill = {Name = "Flurry", Anim = "Rapier_Skill", AnimSpeed = 1, Startup = 0.43, Active = 0.96, HitTimes = {0.43, 0.64, 0.85, 1.05, 1.35}, Recovery = 0.4, Damage = 6, Posture = 4, Stun = 0.4, Velocity = "Pull", Hitbox = Vector3.new(5, 5, 10), Reach = 5, Stamina = 18, Cooldown = 6}, -- hotfix 2026-10-23: the 5 hits sit on the clip's markers at 1x (Barrage 0.43 .. BarrageEnd 1.05, FinalStab 1.35; was 0.9x with all 5 hits in 0.18-0.63 s, before the thrusts). PROPOSAL: Recovery 0.4, Stun 0.35 -> 0.4 (covers the 0.30 s gap before the final stab)
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
			Hit{Anim = "FistCombo1", Startup = 0.18, Active = 0.08, Recovery = 0.10, Damage = 18, Posture = 9, Stun = 0.45, Velocity = "Pull", Hitbox = Vector3.new(6, 6, 7), Reach = 3.5}, -- PROPOSAL (2026-10-19 M1 pass): Startup 0.2 -> 0.18, Recovery 0.14 -> 0.10
			Hit{Anim = "FistCombo2", Startup = 0.18, Active = 0.08, Recovery = 0.10, Damage = 18, Posture = 9, Stun = 0.45, Velocity = "Pull", Hitbox = Vector3.new(6, 6, 7), Reach = 3.5}, -- PROPOSAL (2026-10-19 M1 pass): Startup 0.2 -> 0.18, Recovery 0.14 -> 0.10
			Hit{Anim = "FistCombo3", Startup = 0.18, Active = 0.08, Recovery = 0.10, Damage = 18, Posture = 9, Stun = 0.45, Velocity = "Pull", Hitbox = Vector3.new(6, 6, 7), Reach = 3.5}, -- PROPOSAL (2026-10-19 M1 pass): Startup 0.2 -> 0.18, Recovery 0.14 -> 0.10
			Hit{Anim = "FistCombo5", Startup = 0.26, Active = 0.1, Recovery = 0.44, Damage = 25, Posture = 16, Stun = 0.9, Velocity = "Knockback", Hitbox = Vector3.new(6, 6, 7), Reach = 3.5}, -- PROPOSAL (2026-10-19 M1 pass): Recovery 0.5 -> 0.44 (string 2.12 -> 1.88 s)
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
		Draw = {Equip = "Greatsword_Equip", SwapAt = 0, Unequip = "Greatsword_Equip", UnequipReverse = true, UnequipSpeed = 1.4, UnequipSwapAt = 0.85}, -- Greatsword_Sheathe: sheet id broken (2026-10-18)
		RunAnim = "Greatsword_Run",
		WalkAnim = "Greatsword_Walk", -- Animation ID's sheet (2026-10-18)
		HoldAnim = "Greatsword_Hold",
		-- Heavy feel (user request 2026-10-14; PROPOSAL numbers): carried on the shoulder with the blade
		-- just behind the head while idle / walking / running, slower to move with, every swing steps
		-- the body into it, and hits land with a longer impact pause.
		CarryAnim = "Greatsword_Carry",
		MoveSpeedMult = 0.85, -- walk / run speed while drawn
		SwingStep = 12, -- forward step (studs/s) late in each light's windup
		HitstopMult = 1.4,
		Light = {AttackWalkSpeed = 10, Hits = { -- slower than other weapons' 14 (heavy weapon; was 4)
			Hit{Anim = "Greatsword_Light1", AnimPeak = 0.53, Startup = 0.32, Active = 0.12, Recovery = 0.13, Damage = 30, Posture = 16, Stun = 0.75, Velocity = "Pull", Hitbox = Vector3.new(10, 7, 10), Reach = 5}, -- PROPOSAL (2026-10-19 M1 pass): Startup 0.40 -> 0.32, Recovery 0.32 -> 0.13, Stun 0.55 -> 0.75 (holds the 0.57 s gap)
			Hit{Anim = "Greatsword_Light2", AnimPeak = 0.52, Startup = 0.32, Active = 0.12, Recovery = 0.13, Damage = 30, Posture = 16, Stun = 0.75, Velocity = "Pull", Hitbox = Vector3.new(10, 7, 10), Reach = 5}, -- PROPOSAL (2026-10-19 M1 pass): Startup 0.40 -> 0.32, Recovery 0.32 -> 0.13, Stun 0.55 -> 0.75 (holds the 0.57 s gap)
			Hit{Anim = "Greatsword_Light3", AnimPeak = 0.53, Startup = 0.32, Active = 0.12, Recovery = 0.13, Damage = 30, Posture = 16, Stun = 0.85, Velocity = "Pull", Hitbox = Vector3.new(10, 7, 10), Reach = 5}, -- PROPOSAL (2026-10-19 M1 pass): Startup 0.40 -> 0.32, Recovery 0.32 -> 0.13, Stun 0.55 -> 0.85 (holds the 0.77 s gap to the finisher)
			Hit{Anim = "Greatsword_Light4", AnimPeak = 0.78, Startup = 0.50, Active = 0.14, Recovery = 0.52, Damage = 38, Posture = 28, Stun = 1.0, Velocity = "Knockback", Hitbox = Vector3.new(11, 7, 11), Reach = 5}, -- PROPOSAL (2026-10-19 M1 pass): Startup 0.55 -> 0.50, Recovery 0.6 -> 0.52 (string 3.81 -> 2.87 s)
		}},
		Heavy = {Anim = "Greatsword_Heavy", AnimPeak = 0.83, Startup = 0.55, Active = 0.14, Recovery = 0.6, Damage = 50, Posture = 55, Stun = 1.0, Velocity = "Knockback", Hitbox = Vector3.new(10, 8, 11), Reach = 5, Step = 14, Cooldown = 1.6, HyperArmor = true},
		-- Whirlwind: two spinning hits all around you.
		Skill = {Name = "Whirlwind", Anim = "Greatsword_Skill", AnimPeak = 1.31, Startup = 0.45, Active = 0.35, MultiHit = 2, Recovery = 0.5, Damage = 22, Posture = 18, Stun = 0.6, Velocity = "Pull", Hitbox = Vector3.new(16, 8, 16), Reach = 0, HyperArmor = true, WalkSpeed = 4, Stamina = 25, Cooldown = 9},
		-- Unyielding: heavy and skill windups have hyper armour (you take damage but are not stunned).
		Passive = {Name = "Unyielding"},
	},

	Daggers = {
		Display = "Daggers",
		Draw = {Equip = "Daggers_Equip", EquipSpeed = 1.3, SwapAt = 0, Unequip = "Daggers_Equip", UnequipReverse = true, UnequipSpeed = 1.6, UnequipSwapAt = 0.95}, -- Daggers_Sheathe: sheet id broken (2026-10-18)
		RunAnim = "Daggers_Run",
		HoldAnim = "Daggers_Hold",
		Light = {Hits = {
			Hit{Anim = "Daggers_Light1", AnimPeak = 0.37, Startup = 0.15, Active = 0.07, Recovery = 0.10, Damage = 12, Posture = 5, Stun = 0.4, Velocity = "Pull", Hitbox = Vector3.new(6, 6, 6), Reach = 3.5}, -- PROPOSAL (2026-10-19 M1 pass): Recovery 0.12 -> 0.10
			Hit{Anim = "Daggers_Light2", AnimPeak = 0.40, Startup = 0.15, Active = 0.07, Recovery = 0.10, Damage = 12, Posture = 5, Stun = 0.4, Velocity = "Pull", Hitbox = Vector3.new(6, 6, 6), Reach = 3.5}, -- PROPOSAL (2026-10-19 M1 pass): Recovery 0.12 -> 0.10
			Hit{Anim = "Daggers_Light3", AnimPeak = 0.19, Startup = 0.15, Active = 0.07, Recovery = 0.10, Damage = 12, Posture = 5, Stun = 0.4, Velocity = "Pull", Hitbox = Vector3.new(6, 6, 6), Reach = 3.5}, -- PROPOSAL (2026-10-19 M1 pass): Recovery 0.12 -> 0.10 (string 1.72 -> 1.66 s); AnimPeak 0.45 -> 0.19 measured: the sheet id wired 2026-10-19 is 0.417 s long, its fastest arm / torso turn is between the 0.133 and 0.250 keyframes (0.45 was the old id's)
			Hit{Anim = "Daggers_Light4", AnimPeak = 0.42, Startup = 0.2, Active = 0.08, Recovery = 0.42, Damage = 16, Posture = 10, Stun = 0.8, Velocity = "Knockback", Hitbox = Vector3.new(6, 6, 7), Reach = 3.5},
		}},
		Heavy = {Anim = "Daggers_Heavy", AnimPeak = 0.54, Startup = 0.3, Active = 0.1, Recovery = 0.45, Damage = 28, Posture = 26, Stun = 0.8, Velocity = "Knockback", Hitbox = Vector3.new(6, 6, 8), Reach = 4, Step = 20, Cooldown = 1.0},
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
		WalkAnim = "Guns_Walk", -- Animation ID's sheet "Gun Walk" (2026-10-18)
		Ranged = true,
		-- M1 = PISTOL WHIP (owner 2026-10-17: "M1 is a pistol whip, never a shot"): a 4-hit melee string with
		-- the gun as a blunt weapon, through the normal light-attack pipeline (FistSwing -> AttackRunner,
		-- hitbox sweep, block / parry). It never fires, never spends a round. Animations: the sheet's Gun M1 1-4
		-- (2026-10-18; they replaced the fist-combo stand-ins, which stay as Fallback). AnimPeak = the frame the
		-- striking hand is furthest forward, read from each animation's keyframes. PROPOSAL numbers.
		Light = {Hits = {
			-- gun balance pass 2026-10-18 (owner: "completely audit and balance gun combat"): the whip is a fallback,
			-- not a full melee kit (was 31 DPS = a melee class's lights; now ~24). PROPOSAL.
			Hit{Anim = "Guns_Whip1", AnimPeak = 0.22, Fallback = "FistCombo1", Startup = 0.18, Active = 0.08, Recovery = 0.14, Damage = 11, Posture = 6, Stun = 0.45, Velocity = "Pull", Hitbox = Vector3.new(5, 6, 6), Reach = 3},
			Hit{Anim = "Guns_Whip2", AnimPeak = 0.13, Fallback = "FistCombo2", Startup = 0.18, Active = 0.08, Recovery = 0.14, Damage = 11, Posture = 6, Stun = 0.45, Velocity = "Pull", Hitbox = Vector3.new(5, 6, 6), Reach = 3},
			Hit{Anim = "Guns_Whip3", AnimPeak = 0.18, Fallback = "FistCombo3", Startup = 0.18, Active = 0.08, Recovery = 0.14, Damage = 11, Posture = 6, Stun = 0.45, Velocity = "Pull", Hitbox = Vector3.new(5, 6, 6), Reach = 3},
			Hit{Anim = "Guns_Whip4", AnimPeak = 0.10, Fallback = "FistCombo5", Startup = 0.24, Active = 0.1, Recovery = 0.45, Damage = 16, Posture = 12, Stun = 0.85, Velocity = "Knockback", Hitbox = Vector3.new(5, 6, 6), Reach = 3},
		}},
		-- SHOOTING MODE (Y toggles it, RMB fires while it's on; Requests.Shoot): one hitscan shot per press,
		-- the sheet's four Pistol Aim animations take turns (2026-10-18; they were Studio-only "blatt" saves). Damage, magazine, reload and fire rate (Recovery) come
		-- from Items below. Reload is automatic when the magazine runs dry (Decisions.md: no reload button).
		Shots = {
			Hit{Shot = true, Anim = "Guns_Light1", AnimPeak = 0.35, Startup = 0.12, Active = 0.02, Recovery = 0.2, Damage = 15, Posture = 3, Stun = 0.12, Hitbox = Vector3.new(2, 2, 2), Range = 90, Class = "BLOCKABLE", NoWhiffPenalty = true}, -- PROPOSAL (gun rework 2026-10-25)
			Hit{Shot = true, Anim = "Guns_Light2", AnimPeak = 0.35, Startup = 0.12, Active = 0.02, Recovery = 0.2, Damage = 15, Posture = 3, Stun = 0.12, Hitbox = Vector3.new(2, 2, 2), Range = 90, Class = "BLOCKABLE", NoWhiffPenalty = true}, -- PROPOSAL (gun rework 2026-10-25)
			Hit{Shot = true, Anim = "Guns_Light3", AnimPeak = 0.35, Startup = 0.12, Active = 0.02, Recovery = 0.2, Damage = 15, Posture = 3, Stun = 0.12, Hitbox = Vector3.new(2, 2, 2), Range = 90, Class = "BLOCKABLE", NoWhiffPenalty = true}, -- PROPOSAL (gun rework 2026-10-25)
			Hit{Shot = true, Anim = "Guns_Light4", AnimPeak = 0.35, Startup = 0.12, Active = 0.02, Recovery = 0.2, Damage = 15, Posture = 3, Stun = 0.12, Hitbox = Vector3.new(2, 2, 2), Range = 90, Class = "BLOCKABLE", NoWhiffPenalty = true}, -- PROPOSAL (gun rework 2026-10-25)
		},
		-- Pistol Whip: a close-range melee answer.
		Heavy = {Anim = "Guns_Heavy", AnimPeak = 0.70, Startup = 0.3, Active = 0.1, Recovery = 0.4, Damage = 22, Posture = 30, Stun = 0.8, Velocity = "Knockback", Hitbox = Vector3.new(6, 6, 7), Reach = 3.5, Step = 12, Cooldown = 1.2},
		-- Fan the Hammer: three rapid shots (uses 3 rounds). Its numbers are its own, the same for every gun (WeaponManager.Resolve).
		Skill = {Name = "Fan the Hammer", Anim = "Guns_Light2", AnimSpeed = 1.6, Startup = 0.12, Active = 0.36, Recovery = 0.3, HitTimes = {0.12, 0.27, 0.42}, Damage = 12, Posture = 5, Stun = 0.3, Hitbox = Vector3.new(2, 2, 2), Range = 40, Spread = 3, Class = "BLOCKABLE", Stamina = 15, Cooldown = 6}, -- PROPOSAL (gun rework 2026-10-25)
		-- Point Blank: +20% shot damage within 12 studs. Falloff (balance pass 2026-10-18): full damage to 25 studs,
		-- then down to 50% at 90 -- range buys safety, not damage.
		Passive = {Name = "Point Blank", Range = 12, Mult = 1.2, Falloff = {Start = 25, End = 90, Min = 0.5}},
		Items = {
			-- gun rework 2026-10-25 (PROPOSAL; Test_GunBalance): burst <= 37 (Revolver highest, 35.7), sustained 21-24 (reloads
			-- included) vs melee lights 30-37. Each gun has its own Range and Falloff (the shot's Range 90 / the passive's
			-- Falloff when absent): Forge Tac reaches furthest, Renetti fires fastest. Was burst 29-41, sustained 21-27 (2026-10-18).
			Revolver = {Damage = 20, Magazine = 6, Reload = 1.8, Recovery = 0.42, Range = 70, Falloff = {Start = 20, End = 70, Min = 0.5}, Kick = 1.5}, -- PROPOSAL (gun rework 2026-10-25)
			Renetti = {Damage = 10, Magazine = 12, Reload = 1.6, Recovery = 0.2, Range = 60, Falloff = {Start = 15, End = 60, Min = 0.5}, Kick = 0.5}, -- PROPOSAL (gun rework 2026-10-25)
			["Forge Tac"] = {Damage = 26, Magazine = 5, Reload = 1.8, Recovery = 0.62, Range = 110, Falloff = {Start = 40, End = 110, Min = 0.5}, Kick = 2.0}, -- PROPOSAL (gun rework 2026-10-25)
			Sykov = {Damage = 13, Magazine = 10, Reload = 1.7, Recovery = 0.24, Range = 90, Falloff = {Start = 25, End = 90, Min = 0.5}, Kick = 0.8}, -- PROPOSAL (gun rework 2026-10-25)
		},
		-- Aiming and the server's shot checks (gun rework 2026-10-25; Rensei.GunAim reads these).
		Aim = { -- PROPOSAL (gun rework 2026-10-25)
			MaxYaw = 100, MaxPitch = 70, -- degrees a shot may leave your facing / the horizon -- PROPOSAL (gun rework 2026-10-25)
			AimFresh = 0.75, -- seconds a stored aim stays good (was 2). Fan the Hammer's last shot is 0.42 s after its request: 0.33 s spare -- PROPOSAL (gun rework 2026-10-25)
			Interp = 0.1, MaxRewind = 0.25, -- lag compensation: one-way ping + Interp, capped -- PROPOSAL (gun rework 2026-10-25)
			-- a character's box around its root, from Task 1's measured R6 extents (StarterCharacter: min (-2, -3, -0.5),
			-- max (2, 2, 0.5) -> width 4 x height 5, centre 0.5 below the root; measured 2026-10-25). Depth 2, not the body's 1
			-- (gun rework Ruling 5): side-on shots get a little depth forgiveness; the height and top stay as measured.
			HitBox = Vector3.new(4, 5, 2), HitBoxOffset = Vector3.new(0, -0.5, 0), -- PROPOSAL (gun rework 2026-10-25)
			FlinchRange = 25, -- shots stun only this close -- PROPOSAL (gun rework 2026-10-25)
			FireRate = 5, FireBurst = 5, -- the Fire request's own limiter (GunAim.Limiter), per player -- PROPOSAL (gun rework 2026-10-25)
			HoldGap = 0.25, -- client hold-to-fire: at most one Fire request this often (4 a second, under ServerHandler's shared 8) -- PROPOSAL (gun rework 2026-10-25)
			Buffer = 0.2, -- client: a press this long before the gun is ready still fires -- PROPOSAL (gun rework 2026-10-25)
			ShoulderOffset = Vector3.new(1.75, 0.5, 0), -- the aim camera (Humanoid.CameraOffset) -- PROPOSAL (gun rework 2026-10-25)
			TouchAssist = 2.5, -- degrees; 0 = off -- PROPOSAL (gun rework 2026-10-25)
			SnapDeg = 120, SnapWindow = 0.1, -- the snap log -- PROPOSAL (gun rework 2026-10-25)
			-- flick-and-fire (Ruling 28): a Fire refused only for its yaw is held this long, re-checked each Heartbeat, while
			-- the server's copy of the root catches up with the client's turn (it lags about 0.20-0.27 s, measured in Studio
			-- Play 2026-10-25); then fired or dropped. 0 = off -- PROPOSAL (gun rework 2026-10-25)
			FlickGrace = 0.4,
		},
		-- the owner's animation 97563934064498 (Task 7). AnimLength: its Track.Length, measured 2026-10-25 (Task 1 survey).
		Reload = {Anim = "Guns_Reload", AnimLength = 4.07}, -- PROPOSAL (gun rework 2026-10-25): the slot name
		NpcShot = {Startup = 0.35, Telegraph = true, Spread = 2.5}, -- enemy gunners (Task 11) -- PROPOSAL (gun rework 2026-10-25)
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
			Anim = "Alchemy_GreatswordOverhead", AnimPeak = 0.85, Fallback = "FistHeavy",
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
			Anim = "Alchemy_GreatswordOverhead", AnimPeak = 0.85, Fallback = "FistHeavy",
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
	-- Combat Read's sparring partner (MinigameService.WorldChallenges): attacks only when the drill tells it to,
	-- can't be hurt (AdminGod), never respawns, gives nothing. PROPOSAL.
	Sparring = {
		Knockable = false, -- the sparring dummy is never knocked (owner 2026-10-20: every other enemy is)
		DisplayName = "Sparring Partner", Level = 0, Health = 1000, DamageMult = 0.15,
		WalkSpeed = 10, AggroRange = 25, LeashRange = 40, AttackRange = 5,
		Combo = {1, 1}, HeavyChance = 0, Pause = {1, 1},
		RespawnTime = 1e6, BodyColor = Color3.fromRGB(150, 140, 120),
	},
	-- Alchemist NPCs (2026-10-17): they cast REAL abilities through AlchemyService.CastAs, on the player's rules --
	-- Transmutation Meter earned by fighting (they start at 0, like a player), the slot cooldowns, the clap / slam
	-- telegraph, the abilities' own hitboxes and block / parry / dodge rules -- plus line of sight and range.
	--   Alchemy = {Affinity, Slots = {{Slot, Min, Max}, ...} (tried in order: the first in range, in sight and
	--   affordable is cast), Gap = {min, max} s between casts, Guard = a slot cast in answer to a nearby windup}.
	-- Between casts they fight with their fists (which is how they earn meter). ALL numbers PROPOSALS.
	FieldAlchemist = {
		DisplayName = "Field Alchemist", Level = 5, Health = 650, DamageMult = 0.9, WalkSpeed = 14,
		AggroRange = 45, LeashRange = 60, AttackRange = 5, Combo = {2, 3}, HeavyChance = 0.1, Pause = {0.8, 1.4},
		RespawnTime = 40, Nation = "Amestrian", BodyColor = Color3.fromRGB(120, 60, 50),
		-- controls space: Scorching Wave (a cone) when you crowd it, Ignite (a fireball) when you keep away
		Alchemy = {Affinity = "Flame", Slots = {{Slot = "X", Min = 0, Max = 14}, {Slot = "Z", Min = 7, Max = 40}}, Gap = {1.5, 3}},
	},
	WardAlchemist = {
		DisplayName = "Ward Alchemist", Level = 6, Health = 800, DamageMult = 0.85, WalkSpeed = 12,
		AggroRange = 40, LeashRange = 60, AttackRange = 5, Combo = {2, 3}, HeavyChance = 0.15, Pause = {0.9, 1.5},
		RespawnTime = 45, Nation = "Xerxian", BodyColor = Color3.fromRGB(90, 95, 105),
		-- defensive: raises Steel Guard (a frontal shield) when you start an attack close by -- go round it or wait
		-- it out; Metal Bind up close, Crushing Anvil at range
		Alchemy = {Affinity = "Metal", Slots = {{Slot = "C", Min = 0, Max = 12}, {Slot = "X", Min = 8, Max = 30}}, Gap = {2, 3.5}, Guard = "Z"},
	},
	-- Phase 8 roster (2026-10-17): one hostile alchemist per remaining path, at that path's investigation site.
	FrostAlchemist = {
		DisplayName = "Frost Alchemist", Level = 6, Health = 700, DamageMult = 0.85, WalkSpeed = 13,
		AggroRange = 40, LeashRange = 60, AttackRange = 5, Combo = {2, 3}, HeavyChance = 0.15, Pause = {0.9, 1.5},
		RespawnTime = 45, Nation = "Drachman", BodyColor = Color3.fromRGB(150, 175, 200),
		-- punishes greed: answers a close windup with Cryo Shift (a counter), lays Ice Shards traps at range,
		-- Coldsteel Smash (breaks shields) when you crowd it
		Alchemy = {Affinity = "Ice", Slots = {{Slot = "X", Min = 0, Max = 9}, {Slot = "C", Min = 6, Max = 22}}, Gap = {1.8, 3.2}, Guard = "Z"},
	},
	GaleAlchemist = {
		DisplayName = "Gale Alchemist", Level = 6, Health = 600, DamageMult = 0.85, WalkSpeed = 16,
		AggroRange = 50, LeashRange = 65, AttackRange = 5, Combo = {2, 3}, HeavyChance = 0.1, Pause = {0.7, 1.2},
		RespawnTime = 40, Nation = "Xingnese", BodyColor = Color3.fromRGB(170, 190, 160),
		-- keeps you out: Gale Burst pushes you off when you close in, Air Slash when you back off
		Alchemy = {Affinity = "Wind", Slots = {{Slot = "X", Min = 0, Max = 9}, {Slot = "Z", Min = 10, Max = 45}}, Gap = {1.5, 2.8}},
	},
	StoneAlchemist = {
		DisplayName = "Stone Alchemist", Level = 7, Health = 850, DamageMult = 0.9, WalkSpeed = 12,
		AggroRange = 40, LeashRange = 60, AttackRange = 5, Combo = {2, 3}, HeavyChance = 0.2, Pause = {1.0, 1.6},
		RespawnTime = 50, Nation = "Aerugonian", BodyColor = Color3.fromRGB(140, 115, 85),
		-- slow and solid: raises an Earth Wall against a close windup, Tectonic Shift (ring) up close,
		-- Rising Thorn under you at range
		Alchemy = {Affinity = "Earth", Slots = {{Slot = "X", Min = 0, Max = 9}, {Slot = "Z", Min = 6, Max = 18}}, Gap = {2, 3.5}, Guard = "C"},
	},
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
	-- Forgotten Sites (2026-10-18): Halvard's Adit, Tier I. Grunt-based scavengers picking over the assay lab,
	-- leashed to it so they don't follow players out of the mine. All PROPOSALS.
	AditScavenger = {
		DisplayName = "Adit Scavenger", Level = 3, Health = 450, DamageMult = 0.8,
		WalkSpeed = 14, AggroRange = 30, LeashRange = 45, AttackRange = 5,
		Combo = {2, 4}, HeavyChance = 0.15, Pause = {0.7, 1.3},
		RespawnTime = 120, BodyColor = Color3.fromRGB(90, 80, 70),
		Dungeon = true, -- Halvard's Adit: TuningConfig.DungeonRespawn decides when it comes back
	},
}

-- Dungeon enemies (Def.Dungeon = true; Forgotten Sites). Owner 2026-10-18: "a longer respawn rate so they
-- can't keep respawning so fast". After Time seconds the spawn also waits until no player is within
-- ClearRadius studs of it (EnemyService), so a site you are clearing stays cleared. PROPOSAL numbers.
TuningConfig.DungeonRespawn = {Time = 900, ClearRadius = 80}

-- Locomotion playback (2026-10-18 speed audit; Managers.LocomotionSync, EnemyService). Each walk / run
-- animation's DESIGN speed: the ground speed (studs/s) it looks right at, at 1x. While it plays, its rate
-- follows the character's real speed (speed / design, clamped to Min..Max), so the Speed stat, a heavy
-- weapon, hitstun, casting or carrying change the stride instead of sliding the feet. Design speeds are
-- the speeds each state was tuned at (walk 12, sprint 24, speedy run 30), so the default look is unchanged.
-- Weapon runs used to play at a flat 1.2x at sprint speed: design 20 keeps that look.
TuningConfig.Locomotion = {
	Min = 0.5, Max = 1.6,
	Design = {
		Walk = 12, WalkAnim = 12, Run = 24, SpeedyRun = 30, CrouchWalk = 6, Carrying = 11,
		Daggers_Run = 20, Greatsword_Run = 20, Guns_Run = 20, Sword_Run = 20,
		Greatsword_Walk = 10.2, Guns_Walk = 12, Rapier_Walk = 12, Sword_Walk = 12,
		Boxing_Walk = 12, Lethwei_Walk = 12,
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
	-- bosses (2026-10-18): the big bar at the top of the screen (HUDUI) instead of a small one in the list.
	-- "Name, Title" display names split into the bar's name and title; others keep the trial as the title.
	D.Boss = true
	local Short, Title = D.DisplayName:match("^(.-),%s*(.+)$")
	D.BossName = Short or D.DisplayName
	D.Title = Title or ("Trial of " .. Name:gsub("^Trial", ""))
	TuningConfig.Enemies[Name] = D
end

-- Weapon dash attacks (owner 2026-10-15: "dash attacks for weapons to make them feel more custom").
-- Running + LMB with a weapon drawn uses its class's dash attack instead of the fist one; each entry
-- overrides TuningConfig.DashAttack (anything left out is inherited). ALL numbers are PROPOSALS.
-- Animations are the weapons' own swings (fist fallback until they're published).
TuningConfig.WeaponDashAttacks = {
	Sword = {Name = "Rising Cut", Anim = "Sword_Light4", AnimPeak = 0.30, Startup = 0.18, Active = 0.12, Recovery = 0.42,
		Damage = 26, Posture = 16, Reach = 5, Hitbox = Vector3.new(8, 6, 9), Lunge = 70, LungeTime = 0.26, Cooldown = 2.2},
	Rapier = {Name = "Lunging Thrust", Anim = "Rapier_Light2", AnimPeak = 0.33, Startup = 0.14, Active = 0.1, Recovery = 0.35, -- PROPOSAL (2026-10-19 M1 pass): AnimPeak 0.29 -> 0.33, the new Rapier_Light2's measured peak
		Damage = 20, Posture = 10, Reach = 6.5, Hitbox = Vector3.new(4, 5, 11), Lunge = 85, LungeTime = 0.3, Velocity = "Pull", Cooldown = 1.8},
	Greatsword = {Name = "Cleaving Charge", Anim = "Greatsword_Light1", AnimPeak = 0.53, Startup = 0.32, Active = 0.16, Recovery = 0.6,
		Damage = 34, Posture = 24, Stun = 0.8, Reach = 5, Hitbox = Vector3.new(11, 7, 9), Lunge = 50, LungeTime = 0.3, HyperArmor = true,
		Stamina = 16, Cooldown = 3.0},
	Daggers = {Name = "Shadow Step", Anim = "Daggers_Light2", AnimPeak = 0.40, Startup = 0.12, Active = 0.16, MultiHit = 2, Recovery = 0.3,
		Damage = 11, Posture = 6, Reach = 4, Hitbox = Vector3.new(6, 6, 8), Lunge = 90, LungeTime = 0.22, Velocity = "Pull", Cooldown = 1.6},
	Gauntlets = {Name = "Shoulder Charge", Anim = "Gauntlets_Heavy", AnimPeak = 0.88, Startup = 0.18, Active = 0.14, Recovery = 0.45,
		Damage = 24, Posture = 22, Stun = 0.8, Reach = 4, Hitbox = Vector3.new(7, 6, 8), Lunge = 75, LungeTime = 0.26, Cooldown = 2.2},
	Guns = {Name = "Pistol Whip", Anim = "FistHeavy", Startup = 0.16, Active = 0.12, Recovery = 0.4,
		Damage = 18, Posture = 16, Reach = 4, Hitbox = Vector3.new(6, 6, 7), Lunge = 60, LungeTime = 0.24, Cooldown = 2.0},
}

-- ===== Class skills (owner 2026-10-17: Skill Tree "Class Skills" column + hotbar) =====
-- The skill sheet's class skills, learned in the Mastery menu's Class tab (Rensei.SkillTree, Tree "Class"),
-- equipped to a 4-slot loadout per class family (Rensei.ClassSkills) and used with hotbar keys 1-4 in
-- Combat Mode (Requests.ClassSkill -> AttackRunner). SkillData: Class_<Id>, Class_<Id>Final (last hit),
-- Class_<Id>Grab (the grab hit). Hit times are seconds from the start at AnimSpeed 1, taken from each
-- animation's own markers where it has them (HitFrame, Stab, Slash1/2, FirstHit/FinalHit) and from its
-- measured limb-motion peaks otherwise. EVERY number is a PROPOSAL.
--   Grab = {VictimAnim, Hold, Damage, Posture}: the first hit is a grab. On a hit the victim is held (stunned
--     for Hold seconds, placed in front, playing VictimAnim); on a whiff "Skill_GrabWhiff" plays and the
--     move ends. Final = the last hit's overrides. LungeAt / Lunge / LungeTime: a forward burst at that time.
--   Status = {Name, ...}: applied on hit (StatusManager), e.g. Blood Dash's bleed.
local GrabClass = "UNBLOCKABLE" -- grabs beat block and parry; a dodge or i-frames still avoid them
TuningConfig.ClassSkills = {
	-- Fists (unarmed and Gauntlets)
	-- owner 2026-10-18: Spin Kick is ONE hit (the big kick at 1.12 s of the animation, played at 1.25x -> 0.9 s),
	-- 540 Kick is THREE (its kicks at 0.13 / 0.40 / 0.82 s, leg-motion peaks). PROPOSAL numbers.
	SpinKick = {Anim = "Fist_SpinKick", AnimSpeed = 1.25, HitTimes = {0.9}, Startup = 0.85, Active = 0.1, Recovery = 0.35,
		Damage = 28, Posture = 18, Stun = 0.8, Velocity = "Knockback", Hitbox = Vector3.new(8, 6, 8), Reach = 2, WalkSpeed = 6, Stamina = 15, Cooldown = 8},
	Kick540 = {Anim = "Fist_540Kick", AnimSpeed = 1, HitTimes = {0.13, 0.40, 0.82}, Startup = 0.08, Active = 0.79, Recovery = 0.35,
		Damage = 12, Posture = 10, Stun = 0.6, Velocity = "Pull", Hitbox = Vector3.new(6, 6, 8), Reach = 4,
		Final = {Damage = 22, Posture = 22, Stun = 0.9, Velocity = "Knockback"}, Stamina = 20, Cooldown = 10},
	BearHug = {Anim = "Fist_BearHug", AnimSpeed = 1, HitTimes = {0.28, 0.69}, Startup = 0.23, Active = 0.52, Recovery = 0.75,
		Grab = {VictimAnim = "Fist_BearHugVictim", Hold = 1.4, Damage = 4, Posture = 0},
		Damage = 26, Posture = 20, Stun = 0.8, Hitbox = Vector3.new(5, 6, 5), Reach = 2.5, Stamina = 20, Cooldown = 12},
	SlamDunk = {Anim = "Fist_SlamDunk", AnimSpeed = 1, HitTimes = {0.44, 2.09}, Startup = 0.39, Active = 1.76, Recovery = 0.4,
		Grab = {VictimAnim = "Fist_SlamDunkVictim", Hold = 2.3, Damage = 4, Posture = 0},
		Damage = 40, Posture = 35, Stun = 1.0, Velocity = "Knockback", Hitbox = Vector3.new(5, 6, 5), Reach = 2.5, HyperArmor = true, Stamina = 25, Cooldown = 15},
	WhereYouGoing = {Anim = "Fist_WhereYouGoing", AnimSpeed = 1, HitTimes = {0.82, 1.10, 1.42, 1.94}, Startup = 0.77, Active = 1.23, Recovery = 0.6,
		Damage = 9, Posture = 6, Stun = 0.6, Velocity = "Pull", Hitbox = Vector3.new(6, 6, 8), Reach = 3.5,
		Final = {Damage = 20, Posture = 18, Stun = 0.9, Velocity = "Knockback"}, LungeAt = 0.6, Lunge = 50, LungeTime = 0.2, Stamina = 30, Cooldown = 18},
	-- Sword
	QuickDraw = {Anim = "Sword_QuickDraw", AnimSpeed = 1, HitTimes = {0.88}, Startup = 0.83, Active = 0.11, Recovery = 0.45,
		Damage = 34, Posture = 26, Stun = 0.9, Velocity = "Knockback", Hitbox = Vector3.new(7, 6, 10), Reach = 4.5, LungeAt = 0.7, Lunge = 80, LungeTime = 0.2, Stamina = 18, Cooldown = 9},
	IaidoBarrage = {Anim = "Sword_IaidoBarrage", AnimSpeed = 1, HitTimes = {0.47, 0.72, 0.99, 1.23}, Startup = 0.42, Active = 0.87, Recovery = 0.5,
		Damage = 9, Posture = 7, Stun = 0.5, Velocity = "Pull", Hitbox = Vector3.new(8, 6, 9), Reach = 4,
		Final = {Damage = 18, Posture = 16, Stun = 0.9, Velocity = "Knockback"}, WalkSpeed = 4, Stamina = 24, Cooldown = 13},
	-- Daggers
	SlipSlash = {Anim = "Daggers_SlipSlash", AnimSpeed = 1, HitTimes = {0.42, 0.89}, Startup = 0.37, Active = 0.58, Recovery = 0.45,
		Damage = 12, Posture = 6, Stun = 0.5, Velocity = "Pull", Hitbox = Vector3.new(6, 6, 7), Reach = 3.5,
		Final = {Damage = 18, Posture = 12, Stun = 0.8, Velocity = "Knockback"}, Stamina = 14, Cooldown = 7},
	BulletSlash = {Anim = "Daggers_BulletSlash", AnimSpeed = 1, HitTimes = {0.42, 0.71}, Startup = 0.37, Active = 0.40, Recovery = 0.5,
		Damage = 12, Posture = 6, Stun = 0.5, Velocity = "Pull", Hitbox = Vector3.new(6, 6, 8), Reach = 4,
		Final = {Damage = 18, Posture = 12, Stun = 0.8, Velocity = "Knockback"}, LungeAt = 0.3, Lunge = 90, LungeTime = 0.25, Stamina = 18, Cooldown = 9},
	BloodDash = {Anim = "Daggers_BloodDash", AnimSpeed = 1, HitTimes = {0.79}, Startup = 0.74, Active = 0.11, Recovery = 0.6,
		Damage = 22, Posture = 14, Stun = 0.7, Velocity = "Knockback", Hitbox = Vector3.new(6, 6, 9), Reach = 4,
		Status = {Name = "Bleed"}, LungeAt = 0.6, Lunge = 100, LungeTime = 0.25, Stamina = 18, Cooldown = 10},
	ComeHere = {Anim = "Daggers_ComeHere", AnimSpeed = 1, HitTimes = {0.19, 0.38, 0.61, 0.86}, Startup = 0.14, Active = 0.78, Recovery = 0.3,
		Damage = 7, Posture = 5, Stun = 0.5, Velocity = "Pull", Hitbox = Vector3.new(6, 6, 8), Reach = 4,
		Final = {Damage = 16, Posture = 14, Stun = 0.8, Velocity = "Knockback"}, Stamina = 24, Cooldown = 14},
	-- Greatsword
	HeavyDrop = {Anim = "Greatsword_HeavyDrop", AnimSpeed = 1, HitTimes = {0.92, 1.67}, Startup = 0.87, Active = 0.86, Recovery = 0.3,
		Damage = 30, Posture = 30, Stun = 0.8, Velocity = "Pull", Hitbox = Vector3.new(10, 8, 11), Reach = 5,
		Final = {Damage = 42, Posture = 40, Stun = 1.0, Velocity = "Knockback"}, LungeAt = 1.03, Lunge = 50, LungeTime = 0.2, HyperArmor = true, WalkSpeed = 4, Stamina = 25, Cooldown = 12},
	WhirlwindCleave = {Anim = "Greatsword_WhirlwindCleave", AnimSpeed = 1, HitTimes = {0.92, 1.65}, Startup = 0.87, Active = 0.84, Recovery = 0.6,
		Damage = 26, Posture = 22, Stun = 0.7, Velocity = "Pull", Hitbox = Vector3.new(16, 8, 16), Reach = 0,
		Final = {Damage = 36, Posture = 32, Stun = 1.0, Velocity = "Knockback"}, HyperArmor = true, WalkSpeed = 4, Stamina = 28, Cooldown = 14},
	-- Rapier
	SpeedLunge = {Anim = "Rapier_SpeedLunge", AnimSpeed = 1, HitTimes = {0.39}, Startup = 0.34, Active = 0.11, Recovery = 0.4,
		Damage = 26, Posture = 18, Stun = 0.8, Velocity = "Knockback", Hitbox = Vector3.new(4, 5, 12), Reach = 6, LungeAt = 0.2, Lunge = 110, LungeTime = 0.22, Stamina = 16, Cooldown = 8},
	Ren = {Anim = "Rapier_Ren", AnimSpeed = 1, HitTimes = {0.65, 0.93, 1.33}, Startup = 0.6, Active = 0.79, Recovery = 0.45,
		Damage = 14, Posture = 9, Stun = 0.6, Velocity = "Pull", Hitbox = Vector3.new(6, 6, 9), Reach = 4,
		Final = {Damage = 24, Posture = 18, Stun = 0.9, Velocity = "Knockback"}, LungeAt = 0.4, Lunge = 50, LungeTime = 0.2, Stamina = 24, Cooldown = 13},
	-- Guns
	IronRush = {Anim = "Guns_IronRush", AnimSpeed = 1, HitTimes = {1.97, 2.75}, Startup = 1.92, Active = 0.89, Recovery = 0.5,
		Grab = {VictimAnim = "Guns_IronRushVictim", Hold = 0.85, Damage = 10, Posture = 0},
		Damage = 30, Posture = 26, Stun = 0.9, Velocity = "Knockback", Hitbox = Vector3.new(5, 6, 6), Reach = 3, LungeAt = 0.08, Lunge = 70, LungeTime = 0.6, Stamina = 22, Cooldown = 14,
		LungeStopAt = 3.5}, -- (2026-10-18) the rush ends at the target instead of running past it from point blank
}
for Id, Def in pairs(TuningConfig.ClassSkills) do
	Def.Id = Id
	Def.Fallback = Def.Fallback or "FistCombo5"
	if Def.Grab then Def.GrabClass = GrabClass end
end

-- Fist fallbacks for any weapon animation that is not in the game (or not published yet).
do
	local LightFallback = {"FistCombo1", "FistCombo2", "FistCombo3", "FistCombo5"}
	for Class, W in pairs(TuningConfig.Weapons) do
		W.Class = Class
		for I, H in ipairs(W.Light.Hits) do
			H.Fallback = H.Fallback or LightFallback[I] or "FistCombo1"
			-- combo hits (not the finisher, not gunshots) hold the target long enough to chain
			if I < #W.Light.Hits and not H.Shot then H.Stun = math.max(H.Stun or 0, TuningConfig.Light.MinStun) end
		end
		for I, H in ipairs(W.Shots or {}) do H.Fallback = H.Fallback or LightFallback[I] or "FistCombo1" end
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

-- Grip finishers from the Animation ID's sheet (2026-10-18): GRIP + GRIP VICTIM per class, played as a pair
-- with the target attached (DownedManager "Weapon" style; bare hands = the Caestus (Fists) pair). Length = the
-- gripper animation's length: both play at Length / GripTime so the pair fills the grip. Standing = no victim
-- animation on the sheet: the body stays slumped and the gripper stands over it. No row = the class keeps
-- the Execution finisher (its heavy, twice).
TuningConfig.Downed.Grips = {
	Fists = {Grip = "Gauntlets_Grip", Victim = "Gauntlets_Gripped", Length = 2.23},
	Gauntlets = {Grip = "Gauntlets_Grip", Victim = "Gauntlets_Gripped", Length = 2.23},
	Daggers = {Grip = "Daggers_Grip", Victim = "Daggers_Gripped", Length = 1.2},
	Rapier = {Grip = "Rapier_Grip", Victim = "Rapier_Gripped", Length = 1.23}, -- sheet 2026-10-19; the grip keys Right Arm > Hilt and moves the blade (grip part renamed Hilt, 2026-10-19)
	Sword = {Grip = "Sword_Grip", Victim = "Sword_Gripped", Length = 2.0},
	Greatsword = {Grip = "Greatsword_Grip", Victim = "Greatsword_Gripped", Length = 1.33},
	Guns = {Grip = "Guns_Grip", Victim = "Guns_Gripped", Length = 3.0}, -- Gun Grip Victim: sheet 2026-10-18
}

-- ===== Weapon styles (Rensei.Styles; owner 2026-10-17: Boxing and Lethwei are BARE-FIST styles) =====
-- A style replaces its class's light combo and heavy; everything else (uppercut, aerial, dash attack, block
-- / parry rules, posture, hitstop) stays shared. Hit times come from each animation's authored "Punch"
-- marker (AnimPeak). The "Base" style is the class's existing moveset (TuningConfig.Light / Heavy).
-- ALL NUMBERS PROPOSAL until playtested.
TuningConfig.Styles = {
	Fists = {
		-- Boxing: tight, even jab chains, walking forward while punching, ending in a knockback hook (owner
		-- 2026-10-18); the Peek-a-boo heavy rolls through hits (hyper armour) but hits lighter.
		Boxing = {
			AttackWalkSpeed = 16,
			Light = {Hits = {
				{Anim = "Boxing_Light1", AnimPeak = 0.32, Startup = 0.19, Active = 0.08, Recovery = 0.10, Damage = 15, Posture = 6, Stun = 0.65, Velocity = "Pull", Reach = 3.2}, -- PROPOSAL (2026-10-19 M1 pass): Startup 0.22 -> 0.19, Recovery 0.16 -> 0.10
				{Anim = "Boxing_Light2", AnimPeak = 0.32, Startup = 0.19, Active = 0.08, Recovery = 0.10, Damage = 15, Posture = 6, Stun = 0.65, Velocity = "Pull", Reach = 3.2}, -- PROPOSAL (2026-10-19 M1 pass): Startup 0.22 -> 0.19, Recovery 0.16 -> 0.10
				{Anim = "Boxing_Light3", AnimPeak = 0.32, Startup = 0.19, Active = 0.08, Recovery = 0.10, Damage = 15, Posture = 6, Stun = 0.65, Velocity = "Pull", Reach = 3.2}, -- PROPOSAL (2026-10-19 M1 pass): Startup 0.22 -> 0.19, Recovery 0.16 -> 0.10 (string 2.15 -> 1.88 s)
				-- owner 2026-10-18 "fix boxing infinite combo'ing": the string looped because the finisher stunned (0.75 s)
				-- past its recovery + the next jab's startup (0.30 + 0.22 s). Now 0.35 s stun / 0.45 s recovery: after a full
				-- string the target is free ~0.32 s before the next jab can land (block / dodge window).
				-- owner 2026-10-18: "make it so the 4th in boxing does a knock back, I don't want any infinite combos" --
				-- the finisher now knocks back like every other class's (stun 0.8, as the Rapier / Daggers finishers).
				{Anim = "Boxing_Light4", AnimPeak = 0.32, Startup = 0.24, Active = 0.08, Recovery = 0.45, Damage = 20, Posture = 10, Stun = 0.8, Velocity = "Knockback", Reach = 3.4},
			}},
			Heavy = {Anim = "Boxing_Heavy", AnimPeak = 0.58, Startup = 0.46, Active = 0.12, Recovery = 0.45, Damage = 28, Posture = 30, Stun = 0.9,
				Velocity = "Knockback", Reach = 3.8, Step = 18, Cooldown = 1.2, WalkSpeed = 12, HyperArmor = true},
		},
		-- Lethwei: short, snappy elbows / knees / headbutts that crush guards (high posture damage) but leave
		-- you open on a whiff (longer recovery); the finisher and the heavy knock the target away.
		Lethwei = {
			AttackWalkSpeed = 12,
			Light = {Hits = {
				{Anim = "Lethwei_Light1", AnimPeak = 0.18, Startup = 0.16, Active = 0.06, Recovery = 0.14, Damage = 16, Posture = 12, Stun = 0.6, Velocity = "Pull", Reach = 3.2}, -- PROPOSAL (2026-10-19 M1 pass): Recovery 0.2 -> 0.14
				{Anim = "Lethwei_Light2", AnimPeak = 0.18, Startup = 0.16, Active = 0.06, Recovery = 0.14, Damage = 16, Posture = 12, Stun = 0.6, Velocity = "Pull", Reach = 3.2}, -- PROPOSAL (2026-10-19 M1 pass): Recovery 0.2 -> 0.14
				{Anim = "Lethwei_Light3", AnimPeak = 0.15, Startup = 0.14, Active = 0.06, Recovery = 0.14, Damage = 16, Posture = 12, Stun = 0.6, Velocity = "Pull", Reach = 3.2}, -- PROPOSAL (2026-10-19 M1 pass): Recovery 0.2 -> 0.14 (string 2.06 -> 1.88 s; the long finisher recovery stays)
				{Anim = "Lethwei_Light4", AnimPeak = 0.12, Startup = 0.14, Active = 0.08, Recovery = 0.6, Damage = 26, Posture = 20, Stun = 0.9, Velocity = "Knockback", Reach = 3.4},
			}},
			Heavy = {Anim = "Lethwei_Heavy", AnimPeak = 0.42, Startup = 0.42, Active = 0.12, Recovery = 0.6, Damage = 34, Posture = 55, Stun = 1.0,
				Velocity = "Knockback", Reach = 3.6, Step = 12, Cooldown = 1.5, WalkSpeed = 10},
		},
	},
}
do
	local LightFallback = {"FistCombo1", "FistCombo2", "FistCombo3", "FistCombo5"}
	for Class, List in pairs(TuningConfig.Styles) do
		for Id, S in pairs(List) do
			S.Class, S.Id = Class, Id
			-- the class's own hitbox boxes unless a style sets its own (the sweep needs one)
			local BaseHits = (TuningConfig.Weapons[Class] and TuningConfig.Weapons[Class].Light.Hits) or TuningConfig.Light.Hits
			local BaseHeavy = (TuningConfig.Weapons[Class] and TuningConfig.Weapons[Class].Heavy) or TuningConfig.Heavy
			for I, H in ipairs(S.Light.Hits) do
				H.Hitbox = H.Hitbox or (BaseHits[I] or BaseHits[1]).Hitbox
				H.Fallback = H.Fallback or LightFallback[I] or "FistCombo1"
				if I < #S.Light.Hits then H.Stun = math.max(H.Stun or 0, TuningConfig.Light.MinStun) end
			end
			S.Heavy.Hitbox = S.Heavy.Hitbox or BaseHeavy.Hitbox
			S.Heavy.Fallback = S.Heavy.Fallback or "FistHeavy"
			S.Heavy.Telegraph = true
		end
	end
end

return TuningConfig

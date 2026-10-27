# Combat System

Target feel (controls doc): **Devil Hunter.** Fast and responsive, smooth flowing combos, flashy but controlled, skill-based parry. Not floaty, not Souls-slow. All numbers live in `TuningConfig`; this page explains the rules. Values marked PROPOSAL were never given by the owner; values marked DH come from Devil Hunter's code.

## Controls (LOCKED doc + the owner's later changes)

| Input | Action |
|---|---|
| LMB | Light combo (hold to keep swinging). In the air: Aerial. While running: Dash Attack. |
| Ctrl + LMB | Uppercut (launch + air juggle) |
| RMB | Feint (cancels a light's windup). With guns in shooting mode: fire (hold to keep firing) |
| R | Heavy (crit telegraph during the windup). Pressed during an M1 swing, it comes out the moment that swing ends |
| F | Tap = Parry, hold = Block (holding re-raises the guard after a stun). A fresh press parries even while you're being hit. |
| Q | Dash (8 directions, camera-relative in shift lock) |
| Shift / Ctrl / Space | Run / slide (outside Combat Mode) / jump, climb, wall run |
| Alt | Shift lock |
| E | Combat Mode (draw/sheathe; attacks only land in Combat Mode). Also Interact out of combat. |
| T | Weapon skill |
| Y | Guns: shooting mode on or off (see "Guns" below) |
| Z / X / C / V | Alchemy. V = Carry first if a knocked target is near. |
| B | Grip (finisher on a knocked target) |

## Attack state machine (`AttackRunner`)

- **Startup:** the windup. Getting hit cancels it, so the faster attack wins. A light can be feinted here.
- **Active:** the server sweeps the hitbox every frame.
- **Recovery:** endlag. A whiff adds 0.15s. The combo carries on through whiffs (owner, 2026-10-14): holding or clicking into the air plays the whole 4-hit string. A feint, an interrupt or a 2s pause resets it.

## Lights

- 4-hit combo, hit to hit about 0.46s.
- **Hitstun 0.6s (DH)**, so a landed string is a true combo. The 4th hit knocks back.
- The combo remembers its place for **2s (DH)**.
- Walk speed while swinging **14 (DH 13/15)**; heavy 11; greatsword lights 10.

## Defence

- **Block:** chip damage 20%, drains posture. Posture 0 = guard break, a 1.4s stun.
- **Block facing:** a block faces the attack's source (projectiles use where they came from).
- **Parry (DH rules):**
  - 0.22s window; +0.04s if your last parry landed; ping-scaled above 100ms.
  - 1.3s cooldown per attempt unless it lands.
  - Attacker: −10 posture, 0.7s stun, pushback. Parrier pays 5 posture.
  - Only a **fresh press** opens a window. The guard re-raising itself while F is held never parries.
- **Parry while getting hit (owner, 2026-10-14, "like VV and Devil Hunter"):**
  - Devil Hunter's block gate doesn't include hitstun, so a fresh F press during hitstun still opens the parry window. The hit reaction keeps playing.
  - It **costs 10 posture up front** (PROPOSAL) and needs that much posture left.
  - It **always starts the 1.3s cooldown, even if it lands** (PROPOSAL), so it can't be chained out of every combo.
  - Not allowed while guard-broken, parry-stunned, frozen or knocked (Devil Hunter's gate excludes posture-broken and parry-stunned too).
  - Keep holding F and the guard comes up as soon as the stun ends.
  - Numbers: `TuningConfig.Parry.HitParry`.
- **Classes:**
  - **PARRYABLE** (the default): block mitigates, parry counters.
  - **BLOCKABLE:** a parry window only blocks.
  - **UNBLOCKABLE:** ignores both; dodge it.
- **Dash:** 110 → 24 speed over 0.325s, i-frames, 20 stamina, 1s cooldown.

## Mobile (touch) controls

`Modules.UI.MobileControls` shows on touch screens. In Studio, set the Player attribute `ForceMobileControls = true`, or use the Device Emulator.

Every button runs the same action as its key, through `Managers.ClientActions`:

| Button | Key it matches |
|---|---|
| Attack (hold keeps swinging; jump attack while jumping) | LMB |
| Upper | Ctrl+LMB |
| Heavy | R |
| Feint | RMB |
| Block (hold; tap = parry) | F |
| Dash | Q |
| Jump (hold = wall run; tap at a wall = climb) | Space |
| Fight / Calm | E |
| Run (toggle) | Shift |
| Slide (out of combat) | Ctrl |
| Skill (with a weapon) | T |
| Aim / Stop (with a gun, in Combat Mode) | Y |
| Fire (hold to keep firing; shows while shooting) | RMB |
| Z / X / C (hold = keep the clap) | Z / X / C |
| V (Carry, else the Ultimate) | V |
| Grip (near a knocked body) | B |

- **On a wall** the thumbstick moves you like WASD.
- **Layout:** combat buttons show in Combat Mode only. Alchemy runs as a column on the left of the cluster, with cooldown drains.
- **Roblox's own jump button is hidden**, because ours also climbs and wall-runs.
- **Server Info panel:** hidden while the touch controls show (it sits in the same corner), back when they hide. On touch screens the desktop alchemy slot bar is replaced by the buttons.

## Shields, counters and true damage

- **Shields** (`ShieldManager`, Steel Guard) soak damage from the front until their absorb runs out.
  - A `BreaksShields` strike (Coldsteel Smash) shatters one outright and lands.
  - UNBLOCKABLE and TrueDamage attacks ignore shields.
- **Counters** (`CounterManager`, Cryo Shift) catch the first hit that isn't UNBLOCKABLE.
- **True damage** (Alloy Divider) ignores damage resist and shields; i-frames and dodges still avoid it.

## Enemies (PvE)

- Enemies never damage each other (`DamageManager`). Before this fix their swings could kill the enemies beside them.
- They spread out around a target (4.5-stud spacing, PROPOSAL) instead of piling into one spot. Crowding only steers them; an enemy in range and ready still attacks.
- The Elite's block presses count as real presses again (`Block:Start(true)`), so it parries. That had broken with the hit-parry change.

## Heavies inside the M1 string

- R pressed during a light swing (any phase) is **queued**: the swing plays out in full, then the heavy starts straight away (`HeavyQueuedAt`, `Heavy.TakeQueued`).
  - Works while LMB is held (Heavy no longer waits for the held Fist skill to end).
  - Not after a stun or a feint; the heavy cooldown still applies.
- If the combo hasn't timed out, M1 continues the string after the heavy (e.g. L1, L2, Heavy, L3, L4).
- R no longer feints; feint is RMB only.

## Feint timing

- RMB right after LMB can reach the server before the light's windup starts. The feint is held for 0.15s and applied as the windup begins (`FeintQueuedAt`).

## Climbing (controls doc: tap Space at a wall, WASD on it)

- **Grab** reach 5 studs (Devil Hunter's climb ray). It used to be 3 from your centre, so you had to touch the wall.
- **Top of a wall:** a clean pull-up onto the ledge (`JumpManager:Mantle`, 0.32s, Devil Hunter-style vault tween). It used to be a velocity launch that threw you ~8 studs over the top, or dropped you when the ledge check missed.
- **Ledge pull-up:** tap Space at a ledge just above jump height (below hand height) to climb straight onto it (Devil Hunter's ledge climb).
- **Poses:** cleaned copies of the climb animations (head faces the wall, torso twist cut). Studio plays them; live keeps the published originals until the owner publishes the cleaned ones (`StudioPrefersSave`). The fall animation no longer plays under the hang. The looping hang pose can no longer get stuck after letting go.
- **Grip dust:** HangFX now adds only light dust at the hand. It used to add a black particle cloud around the arm, plus duplicate shoulder/grip attachments that were never removed.

## Status effects (`StatusManager`)

Owner request (2026-10-14): alchemy hits apply the owner's status effects (Assets place "Status Effects": Fire, Freeze, Bleed, Shock) with real effects. Numbers are in `TuningConfig.Status`; a move can override them.

| Status | VFX | Effect | Default numbers |
|---|---|---|---|
| Burn | Fire | Damage every tick, scaled by the caster's alchemy damage | 5 every 1s for 4s (sheet: Ignite / Phoenix Drive) |
| Freeze | Freeze + ice glaze | Frozen solid: stunned, can't move or jump, pose locked | 1.5s (the sheet's per-move durations); applied by the Ice kit |
| Bleed | Bleed | Damage every tick | 2 every 0.5s for 1.5s (daggers' Lacerate) |
| Shock | Shock | Damage every tick plus a 0.15s jolt stun each tick (interrupts windups) | 2 every 0.5s for 1.5s (PROPOSAL) |

- Re-applying refreshes the status instead of stacking it.
- Death or knock ends it early.
- The victim gets the attribute `Status<Name>` (server time it ends) for UI.
- While frozen, no other walk-speed change (e.g. hitstun's 4) can let the victim move.
- **Who applies what today:**
  - Burn: Ignite, Phoenix Drive (sheet), plus Scorching Wave and Inferno Lance (2 ticks; PROPOSAL).
  - Bleed: daggers.
  - Freeze and Shock: built, and wait for the Ice kit and whichever element gets Shock.

## Resources

| Resource | Rules |
|---|---|
| Health | Approved scale: 580 at level 1, +120 per level, +60 per Vitality |
| Stamina | 100; spent by dash, feint, skills and parkour |
| Posture | 100; drained by blocked hits |
| Transmutation Meter | 0–100; earned only by fighting (hits, parries); spent only by alchemy |

## Weapons (all numbers PROPOSAL)

| Weapon | Skill (T) | Passive |
|---|---|---|
| Sword (Katana) | Dragonflash lunge | Keen Edge: blocked hits +30% posture |
| Rapier | Flurry | Precision: +25% vs a target winding up or recovering |
| Gauntlets | Barrage | Momentum: +6% per combo hit, max 4 |
| Greatsword | Whirlwind | Unyielding: hyper armour on heavy and skill windups |
| Daggers | Scissor Rush | Lacerate: bleed |
| Guns | Fan the Hammer: 3 shots of 12, 40 studs (gun rework 2026-10-25) | Point Blank: +20% within 12 studs |

- **Greatsword feels heavy:** shoulder carry, ×0.85 movement, a step into each swing, 1.4× hit-pause.

## Guns (gun rework, 2026-10-25)

Every number here is **PROPOSAL** (the spec `Documents/specs/2026-10-25-gun-rework-design.md`, §8, lists them for the owner). They live in `TuningConfig.Weapons.Guns`; the pure maths is `Rensei.GunAim`. The owner's rules stay: M1 with a gun is the pistol whip and never fires; shooting is its own mode (Y); there is no reload button.

**Shooting mode, the aim camera and the crosshair**
- **Y** turns shooting mode on or off (Combat Mode, gun in hand, not swimming). While it's on and you aren't locked on:
  - the mouse locks to the screen's centre and the cursor hides;
  - the camera moves over the right shoulder (`Aim.ShoulderOffset` (1.75, 0.5, 0), PROPOSAL);
  - the character turns with the camera.
- Leaving shooting mode puts the camera back to your shift-lock setting. Shift lock's own loop waits while shooting mode owns the camera.
- **The crosshair is the game's own marker** (`Uis.Crosshair`); the old generated "+" is gone.
- **The shot goes to what's under the crosshair:** from the muzzle (root + 1.5 up, where the server fires from) to the point the crosshair's ray meets. So the bullet meets the crosshair whatever the camera's offset.
- **Locked on (G):** the shot aims at the target's centre, and the crosshair moves onto the target.
- **Blocked line:** if the line from your muzzle to the aim point is blocked (a corner your camera sees past), the crosshair dims.
- **Feedback** (existing UI only; PROPOSAL): a hit flashes the crosshair warm red and pulses it 1.35× over 0.15 s; a blocked shot flashes it grey; a miss shows nothing. A guard break counts as a hit. Every shot blooms the crosshair 1.25× for 0.1 s and kicks the camera by the gun's Kick, recovering over 0.18 s. With Settings > Camera Shake off, only the bloom shows.
- **Fire:** RMB (or FIRE on touch). Holding keeps firing at the gun's own rate, and a press up to 0.2 s (`Aim.Buffer`) before the gun is ready still fires.

**The guns** (fire interval = Startup 0.12 + Active 0.02 + the gun's Recovery; burst = damage ÷ interval; sustained counts the reload; all PROPOSAL):

| Gun | Damage | Magazine | Reload | Fire interval | Range | Falloff (full to → 50% at) | Kick | Burst | Sustained |
|---|---|---|---|---|---|---|---|---|---|
| Revolver (the hand cannon) | 20 | 6 | 1.8 s | 0.56 s | 70 | 20 → 70 | 1.5° | 35.7 | 23.3 |
| Renetti (quick and close) | 10 | 12 | 1.6 s | 0.34 s | 60 | 15 → 60 | 0.5° | 29.4 | 21.1 |
| Forge Tac (the marksman) | 26 | 5 | 1.8 s | 0.76 s | 110 | 40 → 110 | 2.0° | 34.2 | 23.2 |
| Sykov (the all-rounder) | 13 | 10 | 1.7 s | 0.38 s | 90 | 25 → 90 | 0.8° | 34.2 | 23.6 |

- **Bands** (`Test_GunBalance`): burst ≤ 37 and sustained 20–26, so a gun deals less than a melee string up close and earns its keep with range. Forge Tac reaches furthest, the Renetti fires fastest, the Revolver has the highest burst, and no gun beats another on damage, magazine, reload and range at once.
- **Falloff** never goes below 50% (range buys safety, not damage).
- **Point Blank** (the passive): +20% shot damage within 12 studs.
- **Weapon Mastery** strengthens a passive's bonus and never deepens the falloff penalty (it used to make long shots weaker).
- **Flinch within 25 studs** (`Aim.FlinchRange`): a shot's 0.12 s stun only lands this close. A shot from further away still deals damage, but it doesn't stun, play a hit reaction, cancel a windup or pause the victim (hitstop).
- **Meter:** a shot that lands gives 2 meter (`Meter.OnShotHit`); melee hits stay 4.
- **No whiff penalty** on shots: a miss already costs the round.
- **Hit box:** each character is a 4 × 5 × 2 box centred 0.5 below its root (`Aim.HitBox`, from Task 1's measured R6 body). Shots stop at the first wall and pass through knocked bodies.
- **Shots stay BLOCKABLE:** a block chips 20%, a parry window counts as a block, dodge i-frames avoid them. No headshot multiplier.

**Fan the Hammer (T):** three shots of **12** each (36 in all), the same for every gun, range **40**, spread **3°**, 15 stamina, cooldown 6. It doesn't need shooting mode. With fewer than 3 rounds it fires what's left, then reloads. Aimed behind you, the client turns you first and fires 0.4 s later; an aim the server refuses costs nothing (no stamina, cooldown or round).

**The reload** (automatic; no reload button, owner decision):
- **An empty magazine** reloads by itself.
- **The top-up:** leaving shooting mode with a part-empty magazine (Y, leaving Combat Mode, or the mode ending by itself) starts the same reload.
- **The interrupt:** things done to you cancel a reload: a stun, being knocked, gripped or carried, or swimming. The bar and the animation stop, and the reload starts over once you're free. Your own actions (the whip, the heavy, a dash, blocking) don't cancel it. Swapping or unequipping the gun cancels it; a reload never runs on a corpse.
- **The animation:** the owner's `Guns_Reload` (97563934064498, 4.07 s) plays at Action priority, sped up to fit the reload (`Reload.AnimLength / reload time`). The reload bar in CooldownUI is unchanged.

**Water:** shooting mode ends when you start swimming, and can't be turned on in water.

**The server's checks** (it owns the mode, the gun, ammo, the reload and the fire rate; the client sends only a direction):
- **The aim** must be a finite, unit-length direction at most 70° up or down and 100° from your facing (`Aim.MaxPitch`, `MaxYaw`). An aim that fails is **refused**: no shot, no round, no animation. A stored aim (Fan the Hammer) is good for 0.75 s (`Aim.AimFresh`).
- **Quick turns:** a shot refused only because the server hasn't seen your turn yet is held and re-checked each frame for up to 0.4 s (`Aim.FlickGrace`), then fired or dropped.
- **Lag compensation:** the server keeps every live character's root position (sampled 20 times a second) and tests a player's shot against where targets stood one-way ping + 0.1 s ago, **capped at 0.25 s** (`Aim.Interp`, `MaxRewind`). The time is taken when the Fire request arrives (the shot ticket), not at the strike. Walls are tested where they are now. Enemy gunners aren't rewound.
- **Fire limits:** the server takes at most **5 Fire requests a second** per player (`Aim.FireRate` / `FireBurst`, checked first); the client's hold sends at most **4 a second** (`Aim.HoldGap` 0.25 s), under ServerHandler's shared 8 a second.
- **The snap log:** two shots within 0.1 s whose directions differ by more than 120° add 1 to the character's `GunSnapCount`, for admins. Nothing is punished.

**Enemy gunners:** a 0.35 s windup with the crit telegraph flash, 2.5° spread, aimed at your centre (`NpcShot`). They keep their per-gun damage and fire rate.

**Touch screens:** AIM toggles shooting mode and FIRE shows while it's on; holding FIRE keeps firing. A shot whose crosshair ray passes within 2.5° of a visible, living enemy's or player's centre, within the gun's range + 10 studs, goes to that centre (`Aim.TouchAssist`, 0 = off). Townsfolk are never assisted.

## Downed

- A player (or an enemy flagged Knockable) at 0 HP is **knocked** instead of dying.
- **Grip (B)** finishes them. **Carry (V)** picks them up.
- They recover after 20s at 15% HP.
- **Crawl (owner, 2026-10-27: "Yes, slow crawl"; not live yet):** a knocked **player** crawls at `TuningConfig.Downed.CrawlSpeed` = 3 studs/s (PROPOSAL) instead of lying still, with the owner's Downed Crawl animation while moving and Downed Idle while still (crossfaded, `CrawlFade` 0.25 s, `CrawlStill` 0.12 s, PROPOSAL). The server owns the speed (`DownedManager.KnockedSpeed`, held by a watch every `CrawlCheck` 0.1 s while the knock lasts, and handed back by `MoverManager` after a movement change). Everything a knock blocked stays blocked: jump (JumpHeight 0), attacks, skills, alchemy, sprint, dash, crouch, climb, swim, and gripping or carrying someone. **No crawl:** knocked enemies and townsfolk (the assassinations' knockout too), anyone gripped or carried (WalkSpeed 0 at once, as before), and anyone in deep water (they float still). A road threshold (RoadService) and the train (StationService: boarding and departure) refuse a knocked player as before. Recovering gives back exactly the speed and jump you had.
- **Crawl guard (fix rounds 1 and 2, 2026-10-27; PROPOSAL numbers):** the server also clamps how far a knocked player's root travels across the ground: at most (`CrawlSpeed` x `CrawlClampMult` 1.5 + `CrawlClampSlack` 2.5/s) = 7 studs/s since the last allowed point, the time capped at `CrawlClampWindow` 1 s; further, the root is put back at that point (its full position). Skipped while the assembly is anchored or grounded, welded into another assembly, PlatformStand, seated, gripped or carried, and for `CrawlClampGrace` 0.5 s after the knock or after a `DownedManager.RebaseCrawl`. Every deliberate server move of a player's character calls `RebaseCrawl` (StationService's pushes, platform, ride watchdog and departure; RoadService's arrival spread; TravelService's arrival; AdminService's bring / goto / teleport; Drop). Attribute `KnockedStill` marks a knocked player the server holds at 0 (deep water, gripped, carried), so the client's `KnockedSpeed` (MoverManager's hand-back, the crouch guard) reads 0 too.
- **Carry pose:** the Carried body sits over the carrier's left shoulder, its root at `TuningConfig.Downed.CarryOffset` = (-1.5, 0.1, 0) in the carrier's root space (PROPOSAL, from the Play check of the owner's Carry / Carried animations; the old root-to-root weld buried the carrier's head in the body). Grips keep the shared root.
- The PvP / permadeath consequences of a grip are not decided.

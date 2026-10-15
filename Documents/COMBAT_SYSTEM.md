# Combat System

Target feel (controls doc): **Devil Hunter.** Fast and responsive, smooth flowing combos, flashy but controlled, skill-based parry. Not floaty, not Souls-slow. All numbers live in `TuningConfig`; this page explains the rules. Values marked PROPOSAL were never given by the owner; values marked DH come from Devil Hunter's code.

## Controls (LOCKED doc + the owner's later changes)

| Input | Action |
|---|---|
| LMB | Light combo (hold to keep swinging). In the air: Aerial. While running: Dash Attack. |
| Ctrl + LMB | Uppercut (launch + air juggle) |
| RMB | Feint (cancels a light's windup) |
| R | Heavy (crit telegraph during the windup) |
| F | Tap = Parry, hold = Block (holding re-raises the guard after a stun). A fresh press parries even while you're being hit. |
| Q | Dash (8 directions, camera-relative in shift lock) |
| Shift / Ctrl / Space | Run / slide (outside Combat Mode) / jump, climb, wall run |
| Alt | Shift lock |
| E | Combat Mode (draw/sheathe; attacks only land in Combat Mode). Also Interact out of combat. |
| T | Weapon skill |
| Z / X / C / V | Alchemy. V = Carry first if a knocked target is near. |
| B | Grip (finisher on a knocked target) |

## Attack state machine (`AttackRunner`)

- **Startup:** the windup. Getting hit cancels it, so the faster attack wins. A light can be feinted here.
- **Active:** the server sweeps the hitbox every frame.
- **Recovery:** endlag. Hit confirm: a whiff adds 0.15s and resets the combo.

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
| Guns | Fan the Hammer | Point Blank: +20% within 12 studs |

- **Greatsword feels heavy:** shoulder carry, ×0.85 movement, a step into each swing, 1.4× hit-pause.

## Downed

- A player (or an enemy flagged Knockable) at 0 HP is **knocked** instead of dying.
- **Grip (B)** finishes them. **Carry (V)** picks them up.
- They recover after 20s at 15% HP.
- The PvP / permadeath consequences of a grip are not decided.

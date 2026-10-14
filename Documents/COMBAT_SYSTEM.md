# Combat System

Target feel (controls doc): **Devil Hunter.** Fast and responsive, smooth flowing combos, flashy but controlled, skill-based parry. Not floaty, not Souls-slow. All numbers live in `TuningConfig`; this page explains the rules. Values marked PROPOSAL were never given by the owner; values marked DH come from Devil Hunter's code.

## Controls (LOCKED doc + the owner's later changes)

| Input | Action |
|---|---|
| LMB | Light combo (hold to keep swinging). In the air: Aerial. While running: Dash Attack. |
| Ctrl + LMB | Uppercut (launch + air juggle) |
| RMB | Feint (cancels a light's windup) |
| R | Heavy (crit telegraph during the windup) |
| F | Tap = Parry, hold = Block (holding re-raises the guard after a stun) |
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
- **Classes:**
  - **PARRYABLE** (the default): block mitigates, parry counters.
  - **BLOCKABLE:** a parry window only blocks.
  - **UNBLOCKABLE:** ignores both; dodge it.
- **Dash:** 110 → 24 speed over 0.325s, i-frames, 20 stamina, 1s cooldown.

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

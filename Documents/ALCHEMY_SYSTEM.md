# Alchemy System

Five paths: **Flame, Ice, Earth, Wind, Metal.** Each has four slots: Z primary, X secondary, C utility, V ultimate. Alchemy is meter based, on cooldowns, telegraphed, and utility/control focused. It is not the main damage source.

- **Ability numbers:** from the design sheet (damage, cooldown, cast, extras), recorded in `Modules.Data.Rensei.Alchemy`.
- **Implementation numbers:** `TuningConfig.Alchemy`, all PROPOSAL.

## How a cast works (owner's flow, 2026-10-14)

1. **Press the key → Clap** (the hands meet at 0.28s).
   - The custom transmutation circle unfolds in front of the hands, tinted to the element.
   - The hands catch fire (the owner's FireElement hand VFX).
2. **Keep holding → the clap holds** (clap loop) until you let go, up to 3s (PROPOSAL).
3. **Release:** the hand circle bursts.
   - **Projectile moves** (Ignite's fireball, the launched phoenix) **extend the arm** (owner rule, 0.12s).
   - **Ground and body moves** (Scorching Wave, Inferno Lance) **slam the ground** (0.52s); the transmutation flashes on the ground.
4. **The move itself:** its own animation and windup (the sheet's Cast), then the release. The aim is where you look when you let go of the key.

The whole cast is the attack's Startup, so **getting stunned anywhere in it cancels the ability**. Meter cost and cooldown are paid at the start, with no refund, so a read cast can be punished.

## Server rules (`ServerScriptService.AlchemyService`)

The server checks every cast:
- alive, in Combat Mode, free to act;
- has an affinity, and the slot's ability is built;
- the clan rule (Marcoh can't use Stone Abilities);
- cooldown and meter.

Refusals show a banner: no meter, not built, no affinity. Repeated messages are suppressed for 2s. The server decides every hit; clients only draw.

## Meter costs (PROPOSAL)

| Slot | Cost |
|---|---|
| Z | 25 |
| X | 35 |
| C | 35 |
| V | 70 |

A light hit earns 4. Alchemy hits never refill the meter.

## Built abilities

| Path | Slot | Ability | Release + animation | Status |
|---|---|---|---|---|
| Flame | Z | **Ignite**: fireball (60 dmg, 8s CD, BLOCKABLE) + burn 4×5 over 4s | Arm Extend + "Fire 2" | ✅ playtested |
| Flame | X | **Scorching Wave**: cone (90 dmg, 10s CD, 0.8s cast, BLOCKABLE), small knockback | Ground Slam + "Fire 1" | ✅ playtested |
| Flame | C | **Inferno Lance**: burning dash (85 dmg, 12s CD, 0.4s cast, PARRYABLE), 0.2s i-frames at the start | Ground Slam + `infernolance` | ✅ playtested |
| Flame | V | **Phoenix Drive**: ultimate (70 crash + 20 burn + 170 explosion, 25s CD, 1.5s cast, UNBLOCKABLE) | Arm Extend + "Fire 4" | ✅ playtested |
| Ice | Z | **Cryo Shift**: reactive counter (40 dmg, 12s CD, cast 0). Up from the clap for 1.0s (PROPOSAL), caster glazed in frost. The first hit that isn't UNBLOCKABLE is cancelled: the attacker takes 40 and is frozen 1.5s; the caster gets 20% damage resist for 2s (sheet) | Clap held as the stance (no slam) | ✅ playtested |
| Ice | X | **Coldsteel Smash**: an ice greataxe forms in the hand, heavy swing (110 dmg, 9s CD, 0.7s cast, PARRYABLE), freezes 0.6s (PROPOSAL) | Ground Slam + greatsword heavy (PLACEHOLDER) | ✅ playtested |
| Ice | C | **Ice Shards**: a frost-circle trap sent to the aimed spot (4–22 studs, PROPOSAL); arms after 0.3s, lasts 8s, radius 6. The first enemy to step in springs it: shards erupt, 30 dmg + frozen 1.5s (sheet) | Ground Slam + "Fire 1" (PLACEHOLDER) | ✅ playtested |
| Ice | V | **Absolute Zero**: area freeze around the caster (200 dmg, 28s CD, 1.2s cast, UNBLOCKABLE), radius 20 (PROPOSAL), frozen 3s (sheet); circle under the caster + red danger ring | Ground Slam + "Fire 4" (PLACEHOLDER) | ✅ playtested |
| Wind | Z | **Air Slash**: a fast crescent of air (50 dmg, 7s CD, 0.5s cast, BLOCKABLE); 160 studs/s, 75 range (PROPOSAL) | Arm Extend + "Fire 3" (PLACEHOLDER) | ✅ playtested |
| Wind | X | **Gale Burst**: three blasts around the caster, 25 + 25 + 35 = 85 (sheet), radius 12; every blast stuns (breaks casts), the last shoves everyone away | Ground Slam + "Fire 4" (PLACEHOLDER) | ✅ playtested |
| Wind | C | **Rising Wind**: an uppercut on a column of wind (70 dmg, 11s CD, 0.6s cast, PARRYABLE); launches the target and the caster for an air juggle, like the Uppercut | Ground Slam + "Uppercut" (PLACEHOLDER) | ✅ playtested |
| Wind | V | **Tempest Break**: a tornado at the aimed spot (10–35 studs); pulls everyone within 18 in and lifts those inside; 3 hits 60 + 60 + 115 = 235 (sheet), the last throws them up and out; UNBLOCKABLE, danger ring | Ground Slam + "Fire 1" (PLACEHOLDER) | ✅ playtested |
| Metal | Z | **Steel Guard**: a steel wall rises in front at the clap and stays 1.5s (sheet); absorbs 70 damage from the front, melee and projectiles (sheet), then breaks; Coldsteel Smash shatters it outright | Clap held (no slam) | ✅ playtested |
| Metal | X | **Crushing Anvil**: steel races along the ground (42 studs/s, 36 range), homes on the nearest enemy ahead after 0.25s, then an anvil drops: 100 dmg (sheet), radius 5 | Ground Slam + a second slam (PLACEHOLDER) | ✅ playtested |
| Metal | C | **Metal Bind**: a steel lance to the first enemy in line (15 studs): 75 dmg and pinned 1s (sheet; stunned, can't move or jump) | Arm Extend + "Fire 1" (PLACEHOLDER) | ✅ playtested |
| Metal | V | **Alloy Divider**: a giant blade forms overhead while a 30×6 line ahead is marked; after the cast + the sheet's 0.4s delay it cleaves the line: 300 **true damage** (ignores damage resist and shields; dodging still works); UNBLOCKABLE | Ground Slam + greatsword heavy (PLACEHOLDER) | ✅ playtested |
| Earth | Z | **Rising Thorn**: a rock spike bursts from the ground at the aimed spot (under the first character the aim crosses, 4–18 studs; the circle marks it): 55 dmg, BLOCKABLE, short knock-up, Bleed 3s (2 every 0.5s) | Ground Slam + "Fire 1" (PLACEHOLDER) | ✅ playtested |
| Earth | X | **Tectonic Shift**: a ring of 12 spikes around the caster (radius 10): 85 dmg, BLOCKABLE, stun 1.2s, shoved out to the ring | Ground Slam + a second slam (PLACEHOLDER) | ✅ playtested |
| Earth | C | **Earth Wall**: a rock wall (6 wide × 7 tall) rises 5 studs ahead for 6s. It is solid: it blocks movement, projectiles and line of sight, and is climbable (it's in `World.Map`). Anyone standing there is thrown up: 30, BLOCKABLE. One wall per caster | Ground Slam + "Fire 4" (PLACEHOLDER) | ✅ playtested (climbing not hand-tested) |
| Earth | V | **Earth Pillars**: the 45×6 line ahead is marked for the cast; then 3 waves of pillars race along it (60 + 60 + 120 = 240), UNBLOCKABLE. Each wave pops victims up; the last throws them | Ground Slam + a second slam (PLACEHOLDER) | ✅ playtested |

**Ice VFX:** `Assets.VFX.IceElement` was built for the kit from the owner's Freeze status textures, plus part-built ice: crystals, the greataxe, frost sheet, trap circle. It has the same layout as FireElement (Hands / shatter / mist), so the owner's own Ice VFX can replace it. **Ice animations are placeholders** from the existing set until real Ice animations exist.

**Wind VFX:** `Assets.VFX.WindElement` plus three textures made and uploaded for the kit (crescent `rbxassetid://112975276475052`, streaks `115359771901722`, ring `114110531684635`).
**Metal VFX:** `Assets.VFX.MetalElement` (sparks) plus part-built steel (spikes, wall, anvil, giant blade).
Both have the same layout as FireElement, so the owner's own VFX can replace them. **Wind and Metal animations are placeholders.**

**Implementation numbers (PROPOSAL):**
- **Ignite:** 110 studs/s, 90 range, radius 1.5. Hits characters or walls; fizzles at max range.
- **Scorching Wave:** 18-stud cone, 40° either side of the aim; knockback 40 for 0.4s (the sheet's 0.4s); no hitting through walls.
- **Inferno Lance:** a 75-speed lunge for 0.25s (about 13 studs); stops on contact. The dash runs on the client, so the server sees it late; the hitbox keeps sweeping for LungeTime + HitLag (0.35s). Before this fix it missed targets more than ~8 studs away. Its 2-tick burn (and Scorching Wave's) is now actually applied.
- **Phoenix Drive:**
  - The **alchemy circle opens under the caster** while the phoenix is summoned (owner request).
  - The crash point is fixed when the key is released, 12–45 studs out, and marked for everyone with a red danger ring that fills up. It's unblockable, so it must be dodged.
  - The phoenix flies 0.6s and crashes (70 + burn in 10 studs); 0.8s later the ground explodes (170 in 20 studs).
  - The caster has 1.2s of recovery after the cast (the sheet's "vulnerable after cast").

**Animation note:** `infernolance` is the owner's local animation and not yet published (it plays only in Studio; live falls back to a punch). The published Fire 5 can't stand in: it moves the body 11 studs inside the animation, which snaps back in Roblox.

## Status effects

Alchemy hits apply status effects through `StatusManager` (see COMBAT_SYSTEM.md): the owner's Fire / Freeze / Bleed / Shock VFX on the victim, with real effects.
- Flame burns (damage scaled by the caster's alchemy damage).
- Freeze (Ice) and Shock are built and ready for their kits.

## UI

- **Slot bar (bottom-right, like Devil Hunter's skill column):**
  - shows once the player has an alchemy path (`Player` attribute `Affinity`);
  - each slot: key, ability name, meter cost (red when short), cooldown drain with seconds, pulse on press;
  - abilities that aren't built are dimmed.

## Open questions

- How a player gets an affinity: character creation isn't built. In Studio, `AlchemyService.StudioTestAffinity` (default "Flame") stands in; it is never saved and is ignored live.
- Skill-tree unlocks for the slots (the old build's XP order for Earth is a starting point: Wall → Rise / Shatter → Spike Lunge → Pillars → Thorn → Tectonic). Final meter costs.

**Earth VFX:** `Assets.VFX.EarthElement`, made from the owner's prototypes: the rock mesh (543908753) and spike mesh (2720161649) as MeshParts, the EarthRise sound, the crack decal, dust from the SandDismantle texture, rock chips, and Hands. Rock takes the colour and material of the ground under it, like the prototypes. **Earth animations are placeholders.**

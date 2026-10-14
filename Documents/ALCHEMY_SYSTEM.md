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
| Wind / Metal | all | Sheet rows recorded | | ⬜ next |
| Earth | all | **No design yet** | | ⬜ |

**Ice VFX:** `Assets.VFX.IceElement` was built for the kit from the owner's Freeze status textures, plus part-built ice: crystals, the greataxe, frost sheet, trap circle. It has the same layout as FireElement (Hands / shatter / mist), so the owner's own Ice VFX can replace it. **Ice animations are placeholders** from the existing set until real Ice animations exist.

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
- Earth abilities. Skill-tree unlocks for the slots. Final meter costs.

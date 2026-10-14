# Alchemy System

Five paths: **Flame, Ice, Earth, Wind, Metal.** Each has four slots: Z primary, X secondary, C utility, V ultimate. Alchemy is meter based, on cooldowns, telegraphed, and utility/control focused. It is not the main damage source.

- **Ability numbers:** from the design sheet (damage, cooldown, cast, extras), recorded in `Modules.Data.Rensei.Alchemy`.
- **Implementation numbers:** `TuningConfig.Alchemy`, all PROPOSAL.

## How a cast works (owner's flow, 2026-10-14)

1. **Press the key → Clap** (the hands meet at 0.28s).
   - The custom transmutation circle unfolds in front of the hands, tinted to the element.
   - The hands catch fire (the owner's FireElement hand VFX).
2. **Keep holding → the clap holds** (clap loop) until you let go, up to 3s (PROPOSAL).
3. **Release → Ground Slam.** The hands hit the ground at 0.52s; the circle bursts and the transmutation flashes on the ground. Some moves can use Arm Extend instead.
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

| Path | Slot | Ability | Status |
|---|---|---|---|
| Flame | Z | **Ignite**: fireball (60 dmg, 8s CD, BLOCKABLE) + burn 4×5 over 4s | ✅ playtested |
| Flame | X | Scorching Wave (cone) | ⬜ next |
| Flame | C | Inferno Lance (dash; the owner's `infernolance` animation) | ⬜ |
| Flame | V | Phoenix Drive (ultimate, UNBLOCKABLE; FireElement `phoenixdrive` VFX) | ⬜ |
| Ice / Wind / Metal | all | Sheet rows recorded | ⬜ |
| Earth | all | **No design yet** | ⬜ |

- **Ignite projectile:** 110 studs/s, 90 range, radius 1.5 (PROPOSAL). Hits characters or walls; fizzles at max range.

## UI

- **Slot bar (bottom-right, like Devil Hunter's skill column):**
  - shows once the player has an alchemy path (`Player` attribute `Affinity`);
  - each slot: key, ability name, meter cost (red when short), cooldown drain with seconds, pulse on press;
  - abilities that aren't built are dimmed.

## Open questions

- How a player gets an affinity: character creation isn't built. In Studio, `AlchemyService.StudioTestAffinity` (default "Flame") stands in; it is never saved and is ignored live.
- Earth abilities. Skill-tree unlocks for the slots. Final meter costs.

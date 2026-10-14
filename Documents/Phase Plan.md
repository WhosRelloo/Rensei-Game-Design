# Rensei Phase Plan

Updated after every phase. Status as of **2026-10-14**.

Legend: ✅ done and playtested · 🟡 partly done · ⬜ not started · 💤 deferred by the owner

Rensei is developed on two tracks that share one codebase (the Roblox place **Ye**, placeId 106992859583940):

- **Track A — Combat & Movement commission.** Follows the owner's controls doc (marked "LOCKED").
  - Target feel: Devil Hunter. Fast, responsive, flowing combos, skill-based parry. Not floaty, not Souls-slow.
- **Track B — Master implementation plan.** Phases 0–11 of `Claude Implementation Plan.md`.

---

## Track A — Combat & Movement commission

| Phase | Status | What it delivered |
|---|---|---|
| A1 Combat core | ✅ 2026-10-13 | `TuningConfig` holds all numbers. Stamina, Posture and the Transmutation Meter. Startup→Active→Recovery state machine. Light (4 hits, hit confirm), Heavy, Feint, Block, Parry, Dash. Server-side hitboxes. |
| A1b Devil Hunter feel pass | ✅ 2026-10-13 | DH dash curve. Uppercut (Ctrl+LMB) with air juggle. Aerial dive. Hitstop. Dash attack. Shift lock copied from DH. |
| A2 Weapons | ✅ 2026-10-13 | Sword (Katana), Rapier, Gauntlets, Greatsword, Daggers, Guns. Each has a combo, heavy, skill (T) and passive. Combat Mode (E) draws and sheathes. |
| A3 PvE | ✅ 2026-10-13 | Dummy, Grunt ("Bandit"), Elite ("Bandit Duelist") with block/parry AI. Enemies use the same combat rules as players. |
| A4 Downed actions | ✅ 2026-10-14 | Knocked state. B = Grip (finisher). V = Carry, with priority over the Ultimate. |
| A5 Parkour | ✅ 2026-10-14 | Directional climb (tap Space at a wall, WASD). Wall run (hold Space). Chaining onto a different wall. Stamina costs. |
| A6 UI import | ✅ 2026-10-13/14 | Rebuilt from the PSDs: HUD, Stats (live polychart), Inventory, Hotbar, Settings, Party, Quest log, Server info. Readability pass. |
| A7 Bug / feel passes | ✅ 2026-10-14 | DH parry rules, M1 buffer, hitstop fix, crit telegraph, holdable-skill fix. |
| A8 Weapon position audit | ✅ 2026-10-14 | Grips, holsters, hold poses, greatsword carry, smooth holster↔hand swaps, joint-leak fix. |
| A9 Alchemy (Z/X/C/V) | 🟡 2026-10-14 | Built: Flame Z **Ignite**. Clap → (hold) → ground slam → throw, the FireElement VFX, and the Z/X/C/V slot bar. The rest of the kit is next. |
| A10 Combat fluidity vs Devil Hunter | ✅ 2026-10-14 | DH hitstun, combo-reset window and movement speeds. Hold F re-raises the guard. Shift-lock side dashes fixed. |
| A11 Ranked PvP arena | 💤 | Doc: "can be added later". |
| A12 Mobile buttons | ⬜ | |

## Track B — Master implementation plan

| Phase | Status | Notes |
|---|---|---|
| 0 Project audit | ✅ | Architecture mapped (see `ARCHITECTURE.md`). |
| 1 Core contracts & persistence | ✅ | `Modules.Data.Rensei.*` (Stats, Progression, Formulas, Alchemy, Clans). ProfileData SchemaVersion 1 with migration. `ProgressionService` is the only writer of stats, EXP, Mastery Points and the Gate. Several client-trust exploits fixed. |
| 2 Alchemy vertical slice | ✅ 2026-10-14 | Flame Z Ignite works end to end: input → server validation (meter, cooldown, clan rule) → cast → projectile → damage and burn → feedback → cleanup. Invalid and repeated requests are handled. |
| 3 Combat classifications & telegraphs | 🟡 | BLOCKABLE / PARRYABLE / UNBLOCKABLE are enforced in `DamageManager`. Heavies have a crit telegraph; alchemy uses the clap circle and ground flash. Still to do: UNBLOCKABLE moves (the alchemy ultimates) and enemy telegraphs. |
| 4 Connected skill tree | ⬜ | `Profile.AlchemyTree` exists; no nodes, costs or UI yet (design not documented). |
| 5 Complete alchemy progression | ⬜ | **Next.** Remaining Flame abilities, then Ice, Wind and Metal. Earth has no design yet. |
| 6 Quests / dialogue / investigation | 🟡 | `QuestService`, `DialogueService`, the journal UI and dialogue UI are wired. No approved content yet. |
| 7 Puzzles & environment | ⬜ | |
| 8 Main story | ⬜ | |
| 9 Cinematic choices | ⬜ | |
| 10 Endings & legacy | ⬜ | |
| 11 Polish & QA | ⬜ | Ongoing in small passes. |

## Next steps, in order

1. **Rest of the Flame kit.** Same pipeline as Ignite, using the owner's animations and FireElement VFX:
   - X Scorching Wave (cone);
   - C Inferno Lance (dash, the `infernolance` animation);
   - V Phoenix Drive (ultimate, UNBLOCKABLE).
2. **Ice, Wind, Metal kits.** The sheet rows are already in `Modules.Data.Rensei.Alchemy`.
3. **Character creation:** how a player gets an affinity (alchemy path). Needs design.
4. **Publish animations** to the group. Several weapon animations are still unpublished copies that only play in Studio.
5. Mobile buttons, then the ranked arena when the owner wants it.

## Visual status page

A visual version of this plan (tracks, alchemy matrix, open decisions) is kept at
https://claude.ai/artifact/LZdftKv8ZzySTLPd6uEovy (private to the owner) and is republished after every phase.

## How to update this file

After each phase, move its row to ✅ and add the date. Record what was built and tested in `Changelog.md`, and decisions in `Decisions.md`.

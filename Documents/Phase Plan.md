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
| A9 Alchemy (Z/X/C/V) | ✅ 2026-10-15 | **All five kits complete (20 of 20 slots):** Flame, Ice, Wind, Metal, Earth. Ice, Wind, Metal and Earth run on placeholder animations; Earth's VFX use the owner's own prototype meshes and sounds. |
| A10 Combat fluidity vs Devil Hunter | ✅ 2026-10-14 | DH hitstun, combo-reset window and movement speeds. Hold F re-raises the guard. Shift-lock side dashes fixed. |
| A10b Status effects + hit-parry | ✅ 2026-10-14 | Burn / Freeze / Bleed / Shock with real effects on the owner's VFX (`StatusManager`). Parry while getting hit, with a posture cost and the cooldown. |
| A13 Movement & combat bug pass + audit | ✅ 2026-10-14 | Climbing rebuilt (grab, mantle, ledge pull-up, poses). Enemy friendly fire and stacking fixed, Elite parries restored, feint queue, Inferno Lance hit lag. Full audit (`Audit 2026-10-14.md`). |
| A11 Ranked PvP arena | 💤 | Doc: "can be added later". |
| A14 Weapons + inventory pass | ✅ 2026-10-14 | Weapons equip from the inventory (saved, restored on spawn, old hotbar weapons migrated); hotbar = items only. Heavies queue mid-M1-string; full M1 string on whiffs. Holsters fixed (katana was through the right arm, daggers loose). Draw no longer freezes the legs. Respawn animation-loading bug fixed. Climb Space nil error fixed. |
| C Character creation + start flow | ✅ 2026-10-14 | Menu place (Character Customization): main menu + 6-step creation (nation, first name / surname / gender, look, alchemy path, starting weapon) with a live preview; server-validated, saved once. Tutorial place: dressed arrival + `FinishTutorial`. Ye: arrival routing, the look on every spawn, a placeholder intro cutscene. One shared save across the three places. |
| A12 Mobile buttons | ✅ 2026-10-14 | Touch cluster bottom-right in Rensei's slot art: Attack (hold), Heavy, Block (hold / tap = parry), Feint, Upper, Skill, Dash, Jump (hold = wall run; climb at walls), Fight/Calm, Run (toggle), Slide, Grip, Z/X/C/V with cooldowns. Same code as the keyboard (`ClientActions`). Thumbstick works on walls. |

## Track B — Master implementation plan

| Phase | Status | Notes |
|---|---|---|
| 0 Project audit | ✅ | Architecture mapped (see `ARCHITECTURE.md`). |
| 1 Core contracts & persistence | ✅ | `Modules.Data.Rensei.*` (Stats, Progression, Formulas, Alchemy, Clans). ProfileData SchemaVersion 1 with migration. `ProgressionService` is the only writer of stats, EXP, Mastery Points and the Gate. Several client-trust exploits fixed. |
| 2 Alchemy vertical slice | ✅ 2026-10-14 | Flame Z Ignite works end to end: input → server validation (meter, cooldown, clan rule) → cast → projectile → damage and burn → feedback → cleanup. Invalid and repeated requests are handled. |
| 3 Combat classifications & telegraphs | 🟡 | All three classes are in use and enforced in `DamageManager`. Telegraphs: heavy crit flash, alchemy clap circle and ground flash, and a red danger ring for UNBLOCKABLE moves (Phoenix Drive). Still to do: enemy telegraphs. |
| 4 Connected skill tree | ⬜ | `Profile.AlchemyTree` exists; no nodes, costs or UI yet (design not documented). |
| 5 Complete alchemy progression | 🟡 | All five paths complete (20/20 slots). Skill-tree unlocks not designed. |
| 6 Quests / dialogue / investigation | 🟡 | `QuestService`, `DialogueService`, the journal UI and dialogue UI are wired. No approved content yet. |
| 7 Puzzles & environment | ⬜ | |
| 8 Main story | ⬜ | |
| 9 Cinematic choices | ⬜ | |
| 10 Endings & legacy | ⬜ | |
| 11 Polish & QA | ⬜ | Ongoing in small passes. |

## Next steps, in order

1. **Skill tree design** (owner): nodes, costs, and whether slots unlock through it.
2. **Owner assets for Ice, Wind, Metal:** VFX folders and move animations to replace the placeholders.
3. **Publish** the cleaned climb animations (the `Save` under each climb Animation).
4. **Publish `infernolance`** to the group. Inferno Lance's animation currently plays only in Studio.
5. **Tutorial content + the real intro cutscene** (owner). The tutorial calls `FinishTutorial`. Publish the three places for the first live flow test.
6. **Publish animations** to the group. Several weapon animations are still unpublished copies that only play in Studio.
7. Mobile buttons, then the ranked arena when the owner wants it.

## Visual status page

A visual version of this plan (tracks, alchemy matrix, open decisions) is kept at
https://claude.ai/artifact/LZdftKv8ZzySTLPd6uEovy (private to the owner) and is republished after every phase.

## How to update this file

After each phase, move its row to ✅ and add the date. Record what was built and tested in `Changelog.md`, and decisions in `Decisions.md`.

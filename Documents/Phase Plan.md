# Rensei Phase Plan

Updated after every phase. Status as of **2026-10-18**.

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
| A15 Movement state + ledge walk | ✅ 2026-10-17 | Server-owned traversal state (`MovementState`, JumpRemote fixes); the authored narrow-ledge walk (Tomb Raider style, facing the wall). |
| A16 Guns rework | ✅ 2026-10-17 | M1 is a pistol whip; shooting is its own mode (Aim). Gun balance audit 2026-10-18. |
| A20 Directional climbing + speed audit | ✅ 2026-10-18 | Climb up / down / sideways on the sheet's animations; WCS default-walk-speed and sprint float fixes; `LocomotionSync`. Rensei and Tutorial. |
| A21 Fluidity pass | ✅ 2026-10-18 | Climb → ledge walk hand-over; climb latency grace, grab buffer, jutting-ledge fixes; M1 follow-through retime; landing blend; Boxing finisher knockback; anti-infinite (feint keeps combo place, 3 s stun-chain cap). Chained real-input tests. |
| A17 Weapon styles | ✅ 2026-10-18 | Bare fists: Brawler (base), Boxing, Lethwei; taught by style trainers with requirements; the Boxing infinite combo fixed. Other classes: base only until their styles are designed. |
| A18 Class skills | ✅ 2026-10-17/18 | Mastery menu Class column, 4-slot hotbar loadout; sticky skills (latch until parry / block), victim-animation grabs; Iron Rush and Phoenix Drive aim fixes. |
| A19 Swimming | ✅ 2026-10-18 | Deep-water swim state (no combat / alchemy, players and enemies), swim sprint, diving, breath and drowning, touch SPRINT / RISE. Mill Pond and Gorge Pool in Lindenmoor. |
| A12 Mobile buttons | ✅ 2026-10-14 | Touch cluster bottom-right in Rensei's slot art: Attack (hold), Heavy, Block (hold / tap = parry), Feint, Upper, Skill, Dash, Jump (hold = wall run; climb at walls), Fight/Calm, Run (toggle), Slide, Grip, Z/X/C/V with cooldowns. Same code as the keyboard (`ClientActions`). Thumbstick works on walls. |

## Track B — Master implementation plan

| Phase | Status | Notes |
|---|---|---|
| 0 Project audit | ✅ | Architecture mapped (see `ARCHITECTURE.md`). |
| 1 Core contracts & persistence | ✅ | `Modules.Data.Rensei.*` (Stats, Progression, Formulas, Alchemy, Clans). ProfileData SchemaVersion 1 with migration. `ProgressionService` is the only writer of stats, EXP, Mastery Points and the Gate. Several client-trust exploits fixed. |
| 2 Alchemy vertical slice | ✅ 2026-10-14 | Flame Z Ignite works end to end: input → server validation (meter, cooldown, clan rule) → cast → projectile → damage and burn → feedback → cleanup. Invalid and repeated requests are handled. |
| 3 Combat classifications & telegraphs | 🟡 | All three classes are in use and enforced in `DamageManager`. Telegraphs: heavy crit flash, alchemy clap circle and ground flash, and a red danger ring for UNBLOCKABLE moves (Phoenix Drive). Still to do: enemy telegraphs. |
| 4 Connected skill tree | ✅ 2026-10-15 | The Mastery tree (K): `Rensei.SkillTree`, `SkillTreeService`, `SkillMods`, `MasteryUI`; buy / refund, effects across combat, alchemy, body and movement (Rello's plan, `plans/2026-10-15-skill-tree.md`). |
| 5 Complete alchemy progression | 🟡 | All five paths complete (20/20 slots). Skill-tree unlocks not designed. |
| 6 Quests / dialogue / investigation | ✅ 2026-10-16 (slice) | Staged quests, prerequisites, outcomes, catch-up, conditional dialogue, evidence, Case Board, Journal (J). One complete placeholder quest ("Chalk on the Foundry Wall") + a repeatable bounty. See `Quests, Puzzles and Minigames Proposal.md`. Real content waits on the owner's lore and map. |
| 7 Puzzles & environment | ✅ 2026-10-16 (slice) | Per-player mechanisms that react to all five alchemy paths, each with a non-alchemy route; puzzles with doors; UI minigames (Pressure Board, Array Restoration, Assay Bench, Ledger Cipher). Graybox Foundry Yard. **Starter map Lindenmoor** (2026-10-17): a Countryside farm village south of the hub, with the owner's Blender workshop, a gorge ledge, a bandit camp and two swimmable pools. |
| 6b Player Identities | ✅ 2026-10-18 | Journal Identities tab, `IdentityService` (encounters, witnessed casts, introductions, naming, evidence leads). Two-player test still needed. See `Identities and Forgotten Sites.md`. |
| 7b Forgotten Sites | ✅ 2026-10-18 (Tier I) | Framework (`ForgottenSite` areas, `StartOnVisit`, caches, dungeon respawn, boss bar) and **Halvard's Adit**. More sites wait on the owner's lore and map. |
| 8 Main story | ⬜ | |
| 9 Cinematic choices | ⬜ | |
| 10 Endings & legacy | ⬜ | |
| 11 Polish & QA | ⬜ | Ongoing in small passes. |

## Next steps, in order

0. **Owner items from 2026-10-18** (`Owner Hand-off 2026-10-18.md`): upload the product icons (`Art/Market Icons`); confirm the Creator Plus free / paid split; re-upload the 12 broken sheet animations. (The five Developer Products are wired.)
1. **Skill tree design** (owner): nodes, costs, and whether slots unlock through it.
2. **Owner assets for Ice, Wind, Metal:** VFX folders and move animations to replace the placeholders.
3. **Publish** the cleaned climb animations (the `Save` under each climb Animation).
4. **Publish `infernolance`** to the group. Inferno Lance's animation currently plays only in Studio.
5. **Tutorial content + the real intro cutscene** (owner). The tutorial calls `FinishTutorial`. Publish the three places for the first live flow test.
6. **Publish animations** to the group. Several weapon animations are still unpublished copies that only play in Studio.
7. Two-player and real-device tests (now including Player Identities: naming and the wrong-name lock; and Forgotten Site saves after a rejoin) (leaderboard, swimming and styles seen by others, touch), then the ranked arena when the owner wants it.

## Visual status page

A visual version of this plan (tracks, alchemy matrix, open decisions) is kept at
https://claude.ai/artifact/LZdftKv8ZzySTLPd6uEovy (private to the owner) and is republished after every phase.

## How to update this file

After each phase, move its row to ✅ and add the date. Record what was built and tested in `Changelog.md`, and decisions in `Decisions.md`.

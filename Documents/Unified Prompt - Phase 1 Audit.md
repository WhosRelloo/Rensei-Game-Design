# Unified prompt (progression, traversal, alchemist NPCs, guns, starter map): Phase 1 audit

**Date:** 2026-10-17. Read live from Ye (106992859583940) in Studio, the GitHub docs, and the map slideshow (exported as PPTX; all 26 slides and their images read). This builds on the audits already done today (`Rensei Phase A Audit`, `Skill Tree Class Skills - Audit and Design`).

## Module map (verified)

Combat, movement and UI module locations are in `ARCHITECTURE.md`, plus today's additions:
- `Managers.MovementState` (server-owned traversal state);
- `JumpManager.LedgeWalk`;
- `Rensei.ClassSkills`, `Requests.ClassSkill`;
- `Animations.Registry` / `Shared.ClassSkills`.

The GitHub `Scripts/` export doesn't include most combat and movement modules. Ye is the only copy.

## Findings per requested system

| System | Current state | Verdict |
|---|---|---|
| **Gun M1** | `FistSwing` sends a gun's M1 down a `Ranged` branch, firing **a hitscan shot** (`WeaponManager.Fire`, which spends a round). The gun's "Light" hits *are* shots (`Guns_Light1-4`). Heavy (R) is already a melee "Pistol Whip" (FistHeavy). Enemy gunners (`EnemyService`) fire through the same shot hits. | **Broken by the new rule.** Repair in place (Phase 2). |
| Shooting / aim | `Requests.Aim` (camera direction, validated); `WeaponManager.Fire` (range, raycast, damage through DamageManager, tracer). No shooting mode exists. | Reuse for the new mode. |
| Ammo / reload | Per-gun magazine (`Items` table: Revolver 6, Renetti 15, Forge Tac 7, Sykov 10), remembered while holstered. **No reserve ammo.** **Automatic reload when empty**, per **`Decisions.md`: "Guns: no reload button, automatic only."** CooldownUI shows ammo and the reload bar. | Keep as designed: automatic reload, unlimited magazines. A manual reload would contradict an owner decision. |
| Gun animations / sounds | No pistol-whip animation on any sheet (the Gun row is empty). The shot animations (`Guns_Light1-4`, "blatt") are Studio-only saves. **No gunshot, muzzle-flash or reload sound or VFX asset exists.** | Missing assets, listed below. |
| **Narrow ledge traversal** | Built today as `JumpManager.LedgeWalk`: auto-detected from geometry, **back to the wall**, server-validated `LedgeWalk` kind in MovementState. | **Doesn't match the new brief.** The Tomb Raider reference **faces the wall**, wants **authored ledges with endpoints**, gaps, safe exits and supported corners, and **no attaching to arbitrary walls**. Rework in Phase 3. |
| Progression | Stats (5) + level/EXP (`ProgressionService`); Mastery Points from training with an hourly allowance per source and 20 per stage (`AddTraining`); Truth/Gate (`Progression.GateCheck`; the trial itself isn't built); Mastery menu (K) with **Alchemy / Arms / Body / Class** tabs (Class added today, equipped to hotbar keys 1–4). | The foundation exists. Phase 4 = the presentation layer ("what next / where / which trainer") plus the categories the brief names. |
| Alchemy acquisition | Affinity is set by `QuestService` (`Identity.Affinity = Path`, quest/trainer acquisition) and the admin panel. An "Alchemy Trainers" NPC folder exists. `TrainingService` lessons (minigame exams) and exercises pay training through `AddTraining`. Spec: `Alchemy Acquisition and Mastery.md`. | Preserve. Trainers are the acquisition path. |
| Minigames | `MinigameService` (server-seeded, server-validated) + `MinigameUI` (MenuKit) + `Rensei.Minigames`: Pressure Board, Array Restoration; Ledger Cipher and Assay Bench defined. `PuzzleService` (per-player mechanisms), `TrialService` (arena trials). | A framework exists. Phase 5 extends it (difficulty bands, Combat Read, Movement Gauntlet, ...), not a new one. |
| **Alchemist NPCs** | `EnemyService`: Grunt/Elite brains using the players' AttackRunner, block and parry. `TrialService` foes: the "alchemy" is **arena hazards**, not real abilities. `AlchemyService.Cast(Player, Slot, Aim)` is **bound to a Player** (profile affinity, clan rule, toasts, skill-tree unlocks). | Phase 6 needs the cast body factored out so an NPC character can run the same pipeline (meter, cooldowns, AttackRunner, hitboxes). |
| Dialogue | `DialogueService` (conditions, actions SetFlag / GiveItem / StartMinigame / Signal), `DialogueUI`. | Reuse for trainers. |
| **Map slideshow** | Accessible. It's a **game-design pitch deck** (pillars, story acts, races, clans, automail, alchemy, combat, regions). The map material is **two mood-board slides with no layout**: **Central City** (government complex with twin towers, dense European blocks, canal promenade with brick factories, skybridged streets, night alleys) + **Countryside** (Resembool-style farm village, fenced dirt roads, stone bridge, cypress hills); **Ishval** (domed desert city in a canyon, sandstone ruins around a fountain plaza) + **Corrupted Lands** (no distinct image). | **It doesn't say which region is the starter map, and gives no layout or scale.** Owner input needed before Phase 7. |
| Blender | No Blender connection or tool in this environment. Studio offers part building, `generate_mesh` and asset insertion. | Phase 7 can graybox in Studio. Modular art would need Blender run by the owner, or Studio-generated meshes. |
| Current map | Graybox: arena, FoundryYard, CrackedFootbridge, SilentObservatory, test walls. No real water. No authored narrow ledges. | |

## Missing assets (exact)

- Pistol-whip animation(s) for guns. Fallback: the published fist combo (FistCombo1/2/3/5), already the guns' heavy fallback.
- Published shot animations (`Guns_Light1-4` are Studio-only saves). Live uses the fist fallback.
- Gunshot sound, muzzle flash, reload sound, reload animation.
- **Ledge: face-the-wall sidestep animations.** The only ledge animation, "Wall Ledge Walk Left" (129382412379032), is posed back-to-wall (arms behind the body, head turned). Also missing: Right, ledge idle, entry, corner and pull-up animations.
- Swim idle (still open).

## Risks

- Changing the gun's "Light" hits from shots to melee affects SkillData names, enemy gunners and the Fan the Hammer skill. All three are repointed together in Phase 2.
- Reworking LedgeWalk to authored ledges means existing geometry no longer auto-attaches. That's intended by the brief.
- NPC alchemy refactor (Phase 6) touches the 58 KB `AlchemyService`. It needs its own backup and regression pass of all 20 abilities.
- Studio test profiles save. Every test snapshots and restores before Play stops (one slip earlier today was reversed and verified).

## Plan (follows the brief's order)

| Phase | Work | Blocked on |
|---|---|---|
| 2 | Gun M1 = pistol whip; **Y** toggles shooting mode (gun drawn); **RMB fires while in shooting mode** (RMB stays Feint otherwise); automatic reload kept; mobile AIM / FIRE buttons; enemy gunners repointed. | — |
| 3 | LedgeWalk reworked: **authored ledges** (tag `RenseiLedge` on a thin part = the foothold strip; its length is the path, its ends are the endpoints), **face the wall**, constrained to the strip, stop at ends, gap = stop (no auto-jump), joined segments hand over, corners only where two ledges are joined, safe exits at platforms, server validates against the authored strip. | Face-wall animations (state works without them) |
| 4 | Progression presentation: "Next unlocks" panel and where to get them (trainers, activities), categories mapped to the existing tabs. | — |
| 5 | Minigame framework: difficulty bands 1–5 in the existing `MinigameService`; first new kinds: Combat Read, Movement Gauntlet. | — |
| 6 | NPC alchemy: factor `AlchemyService` so NPCs cast the real abilities; one trainer and one hostile field alchemist as the vertical slice. | — |
| 7 | Starter map. | **Which region is the starter area, and any layout intent.** Blender availability. |

# Morality × Reputation + Stealth + Mecha Arm: Build Roadmap

**Date:** 2026-10-19.
**Spec:** `Documents/specs/2026-10-19-morality-reputation-consequences-design.md` (approved by the owner: "Continue").

The spec covers several independent subsystems. Each plan below produces working, tested game code on its own, in this order. Only **Plan 1** is written in full so far. Each later plan is written in detail when its turn comes, against the code as it stands then, so the plans never go stale.

## Order and contents

| # | Plan | Spec slices | Depends on | Status |
|---|---|---|---|---|
| 1 | **Foundation:** schema 5, regions, communities, birth deeds, place standing, NPC perception, witnesses, rumours | R1, S1, R2 | — | **written:** `2026-10-19-plan1-foundation.md` |
| 2 | **Heat and Wanted** + sound and light | R3, S2 | 1 | to write |
| 3 | **Consequences and the Exchange rule:** rules table, new conditions, price multipliers, trainer gates, checkpoints, the `Price` lint | R4 (+ the R10 lint) | 1, 2 | to write |
| 4 | **The Licence:** State Exam, Circle initiation, Silver Watch, Orders, revocation | R5 | 1, 3 | to write |
| 5 | **Stealth kit:** takedowns, bodies, hiding spots, alarm bells, throwables, alchemic lures, light control, Alchemic Sense | S3, S4, S5 | 1, 2 | to write |
| 6 | **Identification and hunters:** masks, anonymous rumours, linking; NPC hunters | S6, R6 | 2, 5 | to write |
| 7 | **PvP bounties:** desks, contracts, arrest via Carry, anti-collusion | R7 | 2, 4 | to write (multi-client tests) |
| 8 | **Allies, betrayal, stealth rewards:** call ally, testify, vouch, tip-off; ghost / no-kill tracking | R8, S7 | 1-7 | to write |
| 9 | **Taboo + Shadow Office** | R9 | owner's Taboo canon (spec §18.3) | **blocked** |
| 10 | **Journal Standing tab, Wanted HUD, polish, docs** | R10 | 1-8 | to write |

**Mecha Arm track** (the owner chose "Automail variant + grapple"). It is independent of the morality plans and can run in parallel:

| # | Plan | Contents | Status |
|---|---|---|---|
| M1 | **Mecha Arm variant** | The owner's model `Workspace."StarterCharacterMeca arm2"` (MecArm: `fake arm` + segments `1`–`4`, 5 FX) becomes an `Rensei.Automail` spec fitted by AutomailService, with idle / aim visuals. | to write |
| M2 | **Grapple** | The `graple` animation (Studio save on the first model, **unpublished**: needs an upload by the owner) + a hook-and-pull movement ability built on JumpManager. | to write; needs the upload |
| M3 | **Arm cannon** (PROPOSAL, from the owner's new animations) | Mecha Arm Aim `125033765857278`, Cannon Charge `70940393329813`, Cannon Shoot `117668751587041` (all load). Charge → shoot as an Automail skill. | needs the owner's OK that the cannon is wanted |

The first model's `trow` / `air trow` saves are the stealth throw animations for Plan 5 (throwables). They are unpublished, so the owner needs to upload them.

## Rules for every plan

These come from the spec and the owner's standing rules:
- every number is a PROPOSAL;
- back up every touched script to `ServerStorage.RenseiBackups`;
- snapshot and restore the tester's profile around Play tests;
- add a Changelog entry (newest first);
- update the status page;
- re-read the Animation ID's sheet before animation work;
- never publish the game, never touch live player data beyond the tester's own snapshot-restored profile.

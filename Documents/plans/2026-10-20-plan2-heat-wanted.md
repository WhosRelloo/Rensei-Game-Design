# Plan 2 — Heat and Wanted + Sound and Light

**Date:** 2026-10-20. **Spec slices:** R3 (Heat) + S2 (Sound + light). **Builds on:** Plan 1 (as built in Ye on 2026-10-19).
Every number is a **PROPOSAL**. **Approved** 2026-10-20 (ImWaymonTTK: "Approved. Build Plan 2 as drafted, using the default answer for all 6 questions") and **built** the same day: see the Changelog entry "Plan 2: Heat and Wanted + sound and light" and `2026-10-20-plan2-followups.md`. Small changes during the build: footsteps on other floors are 5; the sigil sits above the party-name row; Militia has no fine desk yet (decay only).

## What players will notice
- **Crimes now have Heat.** Two crimes for now:
  - **Unlicensed casting:** from level 6, without a State licence, in a State place (City, Foundry Yard), with a State agent watching (today only Foreman Brask). +10 Heat per cast, at most +30 per place per hour.
  - **Assault:** hitting a townsperson or watcher (Mirra, Tobin, Lise, Vask, ...). +15 Heat.
- **How Heat rises** (spec §6):
  - **At once** if an agent of that jurisdiction saw it. Today that means Brask → State.
  - **Otherwise when word arrives** at a place whose law hears it: State Heat when the Authority hears, Militia Heat when Townsfolk hear in Lindenmoor, Circle Heat when the Circle hears (for deeds against the Circle).
  - Each crime adds Heat at most once per jurisdiction, so a rumour reaching two State places doesn't count twice.
- **Wanted 0–5** per jurisdiction, from Heat thresholds 20 / 50 / 100 / 180 / 300.
- **Wanted HUD:** a small badge by the compass, coloured by jurisdiction (State blue, Militia brown, Circle dark red), with the level shown as pips. It's hidden at Wanted 0.
- **Getting clear in this plan:**
  - **Fine** at Foreman Brask, a new dialogue line ("Pay the fine", shown only while State Wanted is 1–2): costs 100 × level, and State Heat goes to 0.
  - **Decay:** −5 Heat per hour with no new crime, real time, offline included.
  - The **cell** depends on question Q5 below.
- **Sound:**
  - **Footsteps** depend on the floor: grass / dirt 4, wood 7, metal / gravel 9 studs. Running ×2, crouched 0.
  - **Other sounds:** landing from a height 12, roll / dash 10, water splash 12, melee hit 20, alchemy cast 30 (Agents hear it from twice as far), gunshot 60.
  - **Walls:** each wall between a sound and an NPC takes 40% off its radius.
  - **What an NPC learns:** it goes to look at **where** the sound was, not who made it (this already exists as `PerceptionService.Noise`).
- **Light:** your **Exposure** (0–1) comes from the tagged lamps nearby, with a shadow check, plus daylight when nothing is overhead.
  - **Sight multiplier:** ×0.2 in deep shadow up to ×1.2 in bright light.
  - **Lamps:** the 31 lanterns and the forge / crucible / embers glows are tagged `RenseiLight`, with their radius and strength taken from their PointLight.
  - **Daylight is fixed today:** the game has no day cycle (ClockTime 14.5), so outdoors always counts as bright.
- **Crouching** halves sight-based noticing and makes your steps silent.
- **Eye sigil HUD:** a small transmutation-circle eye in the bottom-left corner (original art). Its fill shows Exposure, and a ring shows how loud you are right now.

## Plan 1 follow-ups folded in
- `MoralityService.Recorded` now passes the full `WitnessService.Capture` result (`Info.Witnesses`), since agent witnesses raise Heat at once.
- `Record` is hardened:
  - `Capture` is pcalled and Evidence is coerced to a number;
  - an unknown `Ctx.Region` falls back to the default region.
- PerceptionService fixes:
  - `Call(S, nil, ...)` is guarded;
  - no more Alert↔Cautious churn beyond the leash;
  - crouch flag added;
  - movement breakpoints are scaled by the character's `SpeedMultiplier`, so a speed buff doesn't read as sprinting.
- RumourService:
  - warns on errors in the join catch-up instead of dropping them silently;
  - an optional "Word reached the City" toast on arrivals.
- Tests: Test_Schema5 extras, and a real failing-first `PerceivedNeedsRecentSight`.
- **Not covered:** the 20 NPC / 2 player performance test. Studio's MCP only runs solo Play. I'll measure 20 NPCs with 1 player and say so.

## Deferred (not in Plan 2)
| Wanted effect | Goes to |
|---|---|
| Prices +10%, State vendors refuse at Wanted 2 | Plan 3 |
| Guards demand surrender, checkpoints | Plan 3 |
| Squads (Wanted 3), the State Alchemist hunter (4), the elite (5) | Plan 6 |
| Player bounty posted at Wanted 2 | Plan 7 |
| Pardon, bribe, safehouse | Plans 4 and 8 |
| Murder, Escape, Contraband, Obstruction crimes | the plans that add knocking out NPCs, cells, contraband and suppression |

## Build (Rensei / Ye only; the Tutorial doesn't run morality)
| Piece | Kind | What it does |
|---|---|---|
| `Rensei.Heat` | new data + pure maths | thresholds, decay, `Wanted(Value)`, the jurisdiction faction map, the per-hour cap |
| `HeatService` | new server module | `Add`, `Value`, `Wanted`, `Fine`, `Clear`; listens to `Recorded` and rumour arrivals; publishes `Wanted_State` / `Wanted_Militia` / `Wanted_Circle` attributes on the player |
| `NoiseService` | new server module | `Emit(Pos, Radius, Kind)` with wall muffling; footstep / landing / roll / splash / hit / cast / gunshot hooks |
| `LightService` | new server module | tags the lights; `ExposureOf(Character)`; writes an `Exposure` attribute on the character every 0.5 s |
| `Rensei.Deeds` | edit | `unlicensed_cast`, `assault_townsfolk` (Repeat, `Crime = n`) |
| `Rensei.Perception` | edit | `ExposureMult`, `CrouchMult`, sound radii, the Agent hearing multiplier |
| `PerceptionService` | edit | `Hear` (walls, Cautious ×1.3, Agent ×2 for casts), crouch, the follow-up fixes |
| `MoralityService`, `RumourService`, `RumourService.Core` | edit | witness list, hardening, the heat hook on arrivals, the toast |
| `AlchemyService` | 1-line hook | the cast → `NoiseService` + the unlicensed-cast check |
| `CharacterHandler` | edit | `Crouching` attribute on the character |
| `StoryLogic` | edit | `Wanted` / `Heat` conditions |
| Brask's dialogue + `DialogueService` | edit | a `PayFine` action |
| `WantedUI`, `StealthUI` | new client UI | the badge and the eye sigil, started by UIHandler |
| `ServerHandler` | edit | starts the three new services |

Backups go to `ServerStorage.RenseiBackups["Pre-HeatWanted_2026-10-20"]`.

## Tests
- **Edit:**
  - `Test_Heat`: thresholds, decay, cap, once per jurisdiction;
  - `Test_Noise`: wall muffling;
  - `Test_Light`: exposure maths;
  - plus the existing suites.
- **Play** (the test profile is snapshotted and restored; level raised to 6 only inside the snapshot; real keyboard input):
  1. Walk to Brask, Combat Mode (E), cast Z in front of him: State Heat 10, Wanted 0. Three casts: 30 (the cap), Wanted 1, and the badge shows.
  2. Cast behind his back, or crouched in shadow: no Heat.
  3. Hit Tobin: Assault. Gossip carries it, and with the test clock State Heat lands when it reaches the City.
  4. Pay the fine at Brask: money −600 at level 6, Heat 0, the badge hides.
  5. Decay over a test clock.
  6. Sound and light:
     - running on metal pulls a Grunt from farther than walking on grass;
     - a wall cuts the radius;
     - a gunshot pulls guards;
     - snuffing a lamp (test toggle) lowers Exposure, and the sigil follows.

## Questions (answered: the defaults were taken)
1. **Alchemy Trainers (Veyra, Holt, Ansel, Calda, Brannoc): witnesses?** Default: **no** (unchanged). If yes, they'd be Townsfolk watchers: they can report, but they never raise Heat at once.
2. **Field / Frost / Gale / Stone / Ward Alchemists: State agents or rogues?** Default: **rogues.** They keep the Agent *sight* type but have no faction, so they never raise Heat, and fighting them isn't Assault. If they're State agents, casting near them raises State Heat at once, and hitting them is a crime, which makes their camps a no-go for unlicensed players.
3. **Rumour hops (strength N → N−1 hops):** this now decides Heat too. A crime seen only by one townsperson in the Foundry never reaches the City, so it gives no State Heat. Keep it, or switch to N hops?
4. **Hostile NPCs (no faction) as witnesses:** default: they still notice you, but don't add rumour strength. Bandits don't talk to the law.
5. **Cell:** (a) build a small placeholder cell now: "Turn yourself in" at Brask = 3 min locked in, then Heat 0; or (b) leave the cell for Plan 6/7, where arrests happen. Default: **(b)**.
6. **reported_lise and Circle Heat:** should betraying Lise also give Circle Heat (+15 PROPOSAL)? Default: **no**. Circle Heat starts with the first deed marked as one.

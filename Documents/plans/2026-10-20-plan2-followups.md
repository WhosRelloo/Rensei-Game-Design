# Plan 2 (Heat and Wanted + sound and light): follow-ups

Plan 2 was built and tested on 2026-10-20 (Changelog: "Plan 2: Heat and Wanted + sound and light"). This file keeps everything deferred, so later plans pick it up.

## For the owner
1. **Townsfolk can't be hit.** `HitboxManager` only counts targets under `workspace.World.Live`; the watchers live in `World.NPCs`.
   - The assault crime (`assault_townsfolk`) is wired, but can't happen in play.
   - Decide whether watchers become hittable. That means health, knockouts, respawns, and maybe Murder (a grip on an innocent), which the spec lists.
2. **Defaults taken. Confirm or change them:**
   - Alchemy Trainers aren't witnesses;
   - the camp alchemists are rogues;
   - the N−1 hop rule (it now also decides how far State Heat travels);
   - hostile NPCs add no rumour strength;
   - no cell yet;
   - no Circle Heat on `reported_lise`.
3. **Daylight sight.** In the open by day, enemies notice you ×1.2 faster than in Plan 1's timings (Exposure 1 → ×1.2).
   - Tune with `Perception.ExposureMax` / `ExposureMin`, or by giving the game a day cycle (`Perception.Daylight` already follows `Lighting.ClockTime`).
4. **Numbers to review** (all PROPOSAL):
   - Heat: thresholds 20/50/100/180/300, crime Heat 10 / 15, the cast cap 30 per place per hour, decay −5/h (real time, offline included), the fine 100 × level;
   - sound: step radii (4 / 7 / 9, other 5), the landing speed 45 studs/s, the wall cut 40%;
   - light: lamp strength from Brightness (0.4–1), indoor daylight 0.35, the night floor 0.05.
5. **Militia** has no desk, so Militia Heat only decays. Name a Lindenmoor NPC to take fines if wanted.

## For Plan 3 (Consequences and the Exchange rule)
- **Wanted effects:**
  - Wanted 1: prices +10% in that jurisdiction;
  - Wanted 2: State vendors refuse you, and guards demand surrender;
  - checkpoints.
- `StoryLogic` already has `Heat` / `HeatBelow` / `Wanted` / `WantedBelow` for the rules table.
- The `Price` lint should cover the new `PayFine` choice. It already shows "(Price: 100 per level)".

## For later plans
- **Plan 5:**
  - snuffing / relighting / shuttering just set the light's `Enabled` (LightService reads it live);
  - throwables and lures call `NoiseService.Emit(Position, Radius)`;
  - a guard relighting a lamp needs an NPC goal.
- **Plan 6:** hunters at Wanted 3 / 4 / 5 read `HeatService.Wanted`. The leash fix (`Lose(Rig, Home, Range)`) stops Alert↔Cautious flipping at the leash's edge.
- **Plans 6 / 7:**
  - the cell ("Turn yourself in", 3 min, Heat 0), then `HeatService.Clear`;
  - arrests;
  - the Escape crime.
- **Plan 7:** the player bounty at Wanted 2. Bounty pay must come only from real Heat: `Morality.Heat` holds only Heat that crimes created, and admin tools don't add any.
- **Plan 8:** pardons (−100) and bribes (−50) call `HeatService.Add` with a negative amount, or need a `Reduce`. Today `Add` ignores amounts ≤ 0.
- **Plan 9:** Taboo Heat must not decay. `Rensei.Heat.Current` needs an exemption flag.
- **Plan 10:** the Journal's "Wanted per jurisdiction, with how to clear it" can read `Heat_<J>` / `Wanted_<J>`.

## Known limits
- **A repeat crime while its rumour is still travelling.** `Core.Spawn` reuses the live rumour of the same deed and origin, so the second assault doesn't add Heat on arrival. Heat at once (agents, law present) still counts each time.
- **Not exercised with real input:**
  - a gunshot (the tester has no gun) and a splash (no swim);
  - walking on wood or metal (only concrete and dirt);
  - a real lamp being put out (Plan 5);
  - the assault (see 1).
  - All of these are covered by `Play_Stealth` / `Play_Assault` / `Test_Sound` through the same code.
- **Performance:** measured with 18 NPCs (4 near) and 1 player. The spec's 20 NPCs near 2 players still needs a two-client test.
- **The Tutorial** wasn't touched. Copy across, all at once, as a later sync:
  - AlchemyService, CharacterHandler, EnemyService, StoryLogic, Perception, PerceptionService, Shoot;
  - the new HeatService / NoiseService / LightService / Rensei.Heat / WantedUI / StealthUI;
  - the ServerHandler / UIHandler start lines.
- During testing, an Escape keypress (Roblox's menu) left a dialogue box on screen with nothing answering it. One Close request from the client cleared it. DialogueUI's `Open` flag and `Dialogue.Visible` drifted apart. Worth a look if players report a stuck box.

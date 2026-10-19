# Plan 1 (Foundation): follow-ups

Plan 1 was built task by task with a review gate on each task, then a final whole-plan review on 2026-10-19. The final verdict was **Ready**, with no blocking items. This file keeps everything that was deferred, so later plans pick it up.

## For the owner, before publishing
1. **Birth-deed offsets are placeholders, and they already apply.**
   - On their first join to Ye, every existing character quietly gets `born_<Origin>`. For example, Ishvalan gives Authority −15, which can drop a character below an `Authority = Trusted` dialogue gate (Dialogues.lua:158).
   - Your slot already has `born_Xerxian` (Authority −10).
   - Confirm the offsets (spec §18.2), or ask for a one-time banner for existing saves.
2. **Placeholders to review:**
   - the six community names;
   - the region "Wilds" (the Forgotten Sites);
   - all perception numbers;
   - the region link minutes;
   - the six watchers: Mirra, Tobin and Lise (Foundry); Drillmaster Vask and the Placeholder NPC (Townsfolk); Foreman Brask (Authority agent).
3. **Questions:**
   - Should the five Alchemy Trainers be witnesses?
   - Are Field / Frost / Gale / Stone / Ward Alchemists State agents or rogues?
   - The rumour hop rule: with strength N, a rumour travels N−1 hops, so a deed seen by one witness never leaves its region. Is that the intended reading of spec §5?

## For Plan 2 (Heat and Wanted + sound and light)
- **Pass the witness list along.** `MoralityService.Recorded` gets `Info = {Region, Strength, Scope}` only. Plan 2 needs the full `WitnessService.Capture` result: §6 says Heat rises at once if an agent witnessed the deed.
  - Also decide whether hostile NPCs (no Faction) count as witnesses. Today a bandit seeing a grip makes the deed land for every faction present.
- **Harden `Record`:**
  - pcall `WitnessService.Capture` and coerce Evidence to a number;
  - fall back to the default region when `Ctx.Region` isn't a real region.
- **PerceptionService:**
  - guard `Call(S, nil, ...)`, which throws once when the focus player leaves mid-fight;
  - stop the Alert↔Cautious churn against a player who stays visible beyond the leash;
  - decide how speed-boosted runs are treated (over 27 studs/s they read as sprinting), together with the crouch flag.
- **RumourService:** warn instead of silently dropping errors in the join catch-up.
- **Tests:**
  - Test_Schema5: existing Places/Heat data survives, and a schema-5 save is a no-op;
  - a real failing-first test for `PerceivedNeedsRecentSight`: Alarm the watcher, go out of sight, expect it absent after Memory.
- **Performance:** measure with 20 NPCs near 2 players (spec §17.10). This plan measured 12 NPCs and 1 player: 0.01–0.14 ms per step.
- **Reason lines:** optionally show a "Word reached …" toast. `Morality.News` already stores them.

## For later plans
- **Plan 6:** with more than 40 NPCs that have a player in view, the ones late in the order run out of sight rays and hold, then catch up in one step.
- **Plan 7:** `RumourService.Report` must refuse, and keep the witness, when nothing new lands (wrong desk, or already heard).
- **Plan 8:** `Regions.Reach` treats an unknown carrier as gossip; validate it when new carriers are added.
- **Plan 10:** `Regions.Hidden` is data only; the Journal should hide the Circle where it's hidden.
- **Whichever plan first calls `Silence`:** rumour ids can repeat within one second.
- **Nation regions plan:**
  - `Core.Push` keeps the first front sent per (place, carrier). Once the graph has loops, it must keep the earliest arrival instead.
  - Add a test that every faction is present in at least one region.
  - Add the border rule from §11 (−2 strength).
- **Spec update:** §13's save shape is now `Known[DeedId][Faction] = time`, and place standing is computed, not stored.
- **Repo mirror:** TruthService, AutomailService and RitualService are started by ServerHandler but aren't mirrored in `Scripts/`.

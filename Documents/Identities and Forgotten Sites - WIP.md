# Player Identities + Forgotten Sites: work in progress (2026-10-18)

Paused when the session's usage limit was reached. All changes are in Studio (Rensei place). None are published.

## Done in Studio (not yet playtested unless noted)
- **K menu fix (playtested):** `MasteryUI` line 124. A mid-line comment had swallowed `Position = Source.Position`.
- **Identities, server:**
  - New: `Rensei.Identities` (rules), `IdentityService` (started from ServerHandler).
  - Hooks: AlchemyService.Cast (witness), StoryService.GiveEvidence (Technique links), WorldService combat log (journal label instead of Roblox name), Requests.Investigation "Identify".
  - ProfileData: `Identity.CharacterId`, `Identities`.
  - Logic tested with a stand-in second player: records, encounter gap, stages, naming guard, introduction, combat-log label. The owner's profile was untouched.
- **Identities, UI:** MenuKit supports >4 tabs. JournalUI "Identities" tab (split list/record on desktop, list->detail on narrow; `ForceNarrow` attribute for testing). **Not yet seen in Play:** Play start hung in Studio.
- **Forgotten Site "Halvard's Adit" (data only):**
  - Minigames `adit_winch`, `adit_assay_ring`.
  - Mechanisms: winch, pry bar, 3 sluices (new `Toggle` prompt), sump (Ice route), array, cracked wall (any element / pry bar), strongbox (new `Reward` cache).
  - Puzzles `adit_lift` / `adit_drain` / `adit_vault` / `adit_hidden`.
  - 4 evidence, 4 inspects, deduction `adit_truth`.
  - Quest `forgotten_halvard` (Tier I, `StartOnVisit`).
  - Enemy type `AditScavenger`.
  - QuestService `Grant` + `StartOnVisit`.
  - All data modules compile.
- Backups: `ServerStorage.RenseiBackups["Pre-IdentitiesSites_2026-10-18"]`.

## Left to do
1. Build the site geometry behind Lindenmoor's east ridge (x≈330, z≈-560; interior on the baseplate x 345-490). Needs:
   - the `RenseiArea` "Halvard's Adit";
   - tagged mechanisms, inspects and puzzle doors (`RenseiPuzzleDoor` with PuzzleId `adit_lift` / `adit_drain` / `adit_vault` / `adit_hidden`);
   - 2 `RenseiEnemySpawn` with EnemyType `AditScavenger`.
2. Play test: the Journal (all 5 tabs, desktop + ForceNarrow), the site end to end, rewards, persistence. Two-player test of Identities (needs a multi-client Studio test or live).
3. Optional: a Brask rumor line with StartQuest; the Journal showing "Forgotten Site · Tier I".
4. Mirror the scripts to `Scripts/`, write the Changelog entry, republish the status page.

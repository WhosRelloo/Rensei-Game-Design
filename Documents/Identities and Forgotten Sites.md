# Player Identities and Forgotten Sites

Built 2026-10-18 in Studio (place **Ye**, shown as "Rensei" in the Studio title). **Not published.** All numbers are **PROPOSALS** unless the owner set them.

## 1. Audit (what existed before)

| System | What was there | Reused for |
|---|---|---|
| Journal (J), `JournalUI` + `MenuKit` | Quests, Evidence, Case Board, Codex tabs (MenuKit allowed 4 tabs) | the **Identities** tab (MenuKit now takes more than 4 tabs) |
| Investigation | `InvestigationService` inspect points (`RenseiInspect`), `Rensei.Evidence`, `Rensei.Investigation` deductions | the site's 4 inspects, 4 evidence and the deduction `adit_truth`; evidence links on identity records |
| Puzzles | `PuzzleService` per-player mechanisms (`RenseiMechanism`), `RenseiPuzzleDoor`, `PuzzleClient` drawing | every Adit mechanism. New prompt kinds: `Toggle` (levers, sluices) and `Reward` (a one-time cache). New client drawings: `Valve`, `Water` |
| Minigames | Pressure Board, Array Restoration (`MinigameService`, `Rensei.Minigames`) | `adit_winch` (Pressure Board), `adit_assay_ring` (Array Restoration) |
| Quests | `QuestService` staged quests, `Rensei.Quests` | the quest `forgotten_halvard` (Tier I). New: `StartOnVisit` and `QuestService.Grant` |
| Areas | `RenseiArea` parts and the area popup | "Halvard's AditArea" with `ForgottenSite = true` |
| Enemies | `EnemyService` spawns (`RenseiEnemySpawn`), `CombatDirector` squads | the enemy type `AditScavenger` and a slower dungeon respawn |
| Combat log | `WorldService.MarkCombat` showed the other player's display name | now shows the journal label ("Subject 03" until identified) |
| Owner assets (`ServerStorage["ASSETS TO EXPORT"]`) | VFX and models | **Used:** the gun muzzle VFX (Smoke / Sparks / Flash) and the water and flow emitters at the sluices and sump. **Not used:** Windup, WindStep, Icechainfx, IceEruption, Pale Assassin Cloak (no system uses them yet) |

## 2. Player Identities

### Rules (`Rensei.Identities`, `IdentityService`)
- **The server is the only witness.** The client never reports what it saw. Records come only from:
  - **Encounter:** a hit between two players. The player who was hit notes the weapon used on them, and both note the other's dress (nation outfit). Meetings less than **120 s** apart count as one encounter.
  - **Witness:** an alchemy cast seen within **60 studs** with a clear line of sight records the technique.
  - **Introduce:** every character has an "Introduce yourself" prompt (8 studs, out of Combat Mode only). Using it tells *that* player your character's name; using the prompt is the consent.
  - **Identify:** name a *Suspected* subject from the journal. The server checks the name against the subject's live character, so they must be in the same server. A wrong name locks the record for **10 min**.
  - **Evidence links:** evidence with a `Technique` field links to records where that technique was seen. The journal shows these as "Leads (not proof)", never as an accusation.
- **Stages:**
  - Unknown: no observations yet.
  - Observed: 1 kind of observation.
  - Suspected: 2 kinds of observation and 2 encounters.
  - Identified: named.
  - Investigated: named, plus 3 encounters, an evidence link, or all 3 kinds of observation.

### Storage (per investigator, bounded)
- **Where:** `Profile.Identities`, keyed by the subject's random `Identity.CharacterId` (a GUID, filled on first load).
- **What is never stored:** no Roblox user id or account name is stored or shown, and no live location. Only where past encounters happened is kept.
- **Limits:**
  - 40 records per investigator. When it's full, the oldest unnamed record is dropped first.
  - 4 logged encounters and 3 evidence links per record.

### Journal: the Identities tab
- **List:** grouped by stage, with the "Suspected (can be named)" group first.
- **Record:**
  - a 4-step stage track and what the current stage means;
  - a gold **Next:** line saying what moves the record on;
  - Confirmed (name, how it was learned, standing);
  - Seen (technique, weapon, dress);
  - Leads (not proof);
  - Encounters (when and where);
  - **Name them:** a cycler of possible names and the lock warning.
- **Layout:** desktop shows the list and the record side by side; on a narrow screen, picking from the list opens the record.

## 3. Forgotten Sites framework
- **What makes a site:** a `RenseiArea` with `ForgottenSite = true`. Its quest has `StartOnVisit = "<area>"` and starts the first time the player walks in.
- **Puzzle state:** each player has their own sluices and doors. Solved puzzles are saved (`Story.Puzzles`, `Story.Flags.Mech_*`).
- **Caches:** a `Reward` cache pays once per character (`Story.Flags.Cache_<Id>`), only after its puzzle is solved. The server checks this, not the client-side door, and pays through `QuestService.Grant`.
- **Enemies:** dungeon enemies (`Dungeon = true`) respawn after **15 min**, and only once no player is within **80 studs**. This was the owner's request ("longer respawn rate"). The settings are in `TuningConfig.DungeonRespawn`.
- **Bosses:** an enemy with `Boss = true` (every alchemy-trial foe is one) shows a large bar at the top of the screen (name, title, health) to whoever is fighting it. The combat log moves below the bar.

## 4. Site 1: Halvard's Adit (Tier I)
- **Where:** behind Lindenmoor's east ridge. The boarded mine mouth is near (298, 13, -660). The model is `Workspace.World.Map.HalvardsAdit`.
- **Story:** a flooded assay mine. Its foreman, Halvard, sealed a vault rather than hand over what was inside.
- **Route** (every step can be done without alchemy):
  1. **Boarded mouth:** inspect the boards.
  2. **Lift:** work the winch (a Pressure Board minigame) to raise the lift gate.
  3. **Sump:** flood water blocks the drain gate. Either:
     - drain it with the sluices, in the order the shift chart on the wall gives: **North shut, Middle open, South shut**;
     - or freeze it with Ice alchemy.
  4. **Guards:** two Adit Scavengers, one with daggers and one with caestus.
  5. **Desk and tool rack:** clues to the assay ring.
  6. **Assay ring (Array Restoration):** turn the outer ring right, the middle ring right, and the inner ring left twice. This opens the vault.
  7. **Vault lectern:** Halvard's ledger, the evidence for the deduction `adit_truth`.
  8. **Optional:** break the cracked wall (any element, or the pry bar) to reach a hidden strongbox.
- **Rewards (tested):** completing the quest gives +$180 and +775 EXP. The strongbox cache pays once per character.

## 5. Field Notes and the tutorial
- **Field Notes:** 7 one-time hint cards on the right of the screen (`Rensei.FieldNotes`, `FieldNotesUI`).
  - Each one shows once per account. This is saved in `Flow.Hints` through `Requests.Hint`, which accepts only known ids.
  - They trigger on the first: inspect prompt, mechanism, evidence, identity record, Mastery Point to spend, boss bar and Forgotten Site.
- **Tutorial place:**
  - The Wall beat now teaches climbing in every direction. Climbing up, down and sideways each count, and the beat ends at the top.
  - The Tutorial got the same climb code, speed fixes and `LocomotionSync` as the main place.
  - Backup: `Pre-TutorialUpdate_2026-10-18`.

## 6. Tests

| Done (Studio Play; the owner's profile was snapshotted and restored) | Still needed |
|---|---|
| Identities logic with a stand-in second player: records, encounter gap, stages, naming guard, introduction, combat-log label | **Two real players** (a Studio multi-client test or a live server) |
| The journal's Identities tab, desktop and narrow layouts | **A wrong name and the 10-minute lock** with a real second player |
| Halvard's Adit end to end; rewards; the cache pays only once | **A real rejoin or live save** of site state (Studio saves to the real profile, so it was restored after each test) |
| Boss bar, Field Notes, the tutorial's Wall beat, directional climbing | A real phone or tablet |

## 7. Limitations
- **Identify needs the subject in the same server.** Offline subjects can't be named; they can introduce themselves next time.
- **Evidence links need a `Technique` field.** Only evidence that has one creates links. So far that's two Adit clues: Halvard's Field Notes (Earth) and A Visitor's Note (Flame).
- **The site is "graybox plus":** real parts and the owner's VFX, but no custom meshes or audio.
- **Gun animations wait on loading.** The gun walk, whip and grip use sheet IDs, which play only once the IDs load for the group.

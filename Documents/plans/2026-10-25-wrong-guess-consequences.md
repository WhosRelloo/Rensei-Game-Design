# Wrong-Guess Consequences Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Every implementer gets the **Global Constraints** and the **Facts** below together with its own task.

**Goal:** the owner's Backlog item, "Consequences for wrong guesses in minigames and puzzles on quests". When this plan is done:
- a minigame, environmental puzzle or Case Board deduction can carry a `Consequence` and a `Strikes` count;
- on a quest with stakes (Act II or later, or Exploration Tier II or higher), wrong tries count against the player. When the strikes run out the consequence fires: a timed **Lockout**, an **Alarm** (noise, and optionally a crime), a **Backfire**, a **Waste** of money, a **ClamUp** flag or a **TipOff** flag;
- the warning and the tries left are shown **before** the attempt, in the game's existing UI;
- Chapter 1, Tier I content, drills, world challenges and trials behave exactly as today;
- day one arms one site: the Foundry ledger deduction (`foundry_ledger_who`), with a 60 s lockout after 3 wrong boards.

Both places get the same code. Nothing is published.

**Spec:** `Documents/specs/2026-10-25-wrong-guess-consequences-design.md`.
- Its §1 is the audit, with file:line evidence.
- Its §13 lists the decisions taken without the owner.
- Every number in it, and here, is **PROPOSAL** unless it quotes an owner decision.

**When to start:**
- **After** the gun rework (`Documents/plans/2026-10-25-gun-rework.md`), the swimming revamp (`Documents/plans/2026-10-25-swimming-revamp.md`), the assassinations (`Documents/plans/2026-10-25-assassinations.md`) **and the stealth missions plan** (not written yet) have all finished. That is the Backlog order: "After the swimming revamp", items 1–3.
- `sync.py`'s `--backup` option comes from whichever of the gun or swim plans ran first. This plan only adds pairs.
- `Documents/CLAUDE.md` asks for approval before scripts are rewritten. The owner's overnight go-ahead (Backlog, 2026-10-25) covers planning. **The controller confirms the owner has seen the spec before Task 4**, the first change a player could notice. Tasks 1–3 change nothing a player can see (see "Each task can be rejected on its own").

**Architecture:** four stages.
1. **Parity and survey** (Task 1): every script this plan touches is a manifest pair, equal to Studio in both places. A read-only survey confirms the Studio facts and records what the stealth missions plan built.
2. **Rules and effects** (Tasks 2–3):
   - `Rensei.WrongGuess`, a shared pure module: stakes, defaults, caps, the flag format, the strike step and the validator;
   - two StoryLogic conditions;
   - `WrongGuessService`, the server's only writer of strikes and locks, which runs the six effects;
   - one deed.
3. **Wiring** (Tasks 4–7): minigames, deductions, puzzles, then the client lines.
4. **Data and the close** (Tasks 8–10): arm `foundry_ledger_who`, the Foundry parity and full sweep, the docs and the one Changelog entry.

**Tech Stack:**
- Roblox Studio Luau, through `Art/Tools/rbxc.py`.
- Python 3.14 (stdlib only), only for `sync.py --check` and counting the Discord post.

---

## Facts (read from the repo, 2026-10-25; Task 1 confirms them in Studio)

**Places and windows:**
- **Ye:** placeId 106992859583940, window "[CLOSED TESTING] Rensei".
- **Foundry:** placeId 109591196441030, window "Foundry Yard".
- Get each window's `studio_id` from `python -I Art/Tools/rbxc.py studios`.
- Never touch the window "bloodydeadpool53's Place".

**The scripts this plan touches.** The repo path comes first, then the expected Studio path; Task 1 confirms each. "Pair" means it is already in `sync_manifest.json`; Task 1 adds the rest.

| Label | Repo | Studio | Task |
|---|---|---|---|
| `Rensei.WrongGuess` | `Scripts/ReplicatedStorage/Modules/Data/Rensei/WrongGuess.lua` | `ReplicatedStorage/Modules/Data/Rensei/WrongGuess` | new (2) |
| `Rensei.StoryLogic` | `.../Data/Rensei/StoryLogic.lua` | `ReplicatedStorage/Modules/Data/Rensei/StoryLogic` | 2 (pair) |
| `Rensei.Deeds` | `.../Data/Rensei/Deeds.lua` | `ReplicatedStorage/Modules/Data/Rensei/Deeds` | 3 (pair) |
| `Rensei.Investigation`, `Rensei.Quests` | `.../Data/Rensei/<X>.lua` | `ReplicatedStorage/Modules/Data/Rensei/<X>` | 8 (pairs) |
| `Rensei.Minigames`, `Rensei.Puzzles` | `.../Data/Rensei/<X>.lua` | `ReplicatedStorage/Modules/Data/Rensei/<X>` | read; changed only by Task 8's conditional step (pairs) |
| `RenseiServer.WrongGuessService` | `Scripts/ServerScriptService/WrongGuessService.lua` | `ServerStorage/RenseiServer/WrongGuessService` | new (3) |
| `RenseiServer.MinigameService` | `Scripts/ServerScriptService/MinigameService.lua` | `ServerStorage/RenseiServer/MinigameService` | 4 |
| `RenseiServer.InvestigationService` | `Scripts/ServerScriptService/InvestigationService.lua` | `ServerStorage/RenseiServer/InvestigationService` | 5 |
| `Requests.Investigation` | `Scripts/ServerScriptService/ServerHandler/Requests/Investigation.lua` | `ServerStorage/RenseiServer/ServerHandler/Requests/Investigation` | 5 |
| `RenseiServer.PuzzleService` | `Scripts/ServerScriptService/PuzzleService.lua` | `ServerStorage/RenseiServer/PuzzleService` | 6 |
| `UI.MinigameUI`, `UI.JournalUI` | `Scripts/ReplicatedStorage/Modules/UI/<X>.lua` | `ReplicatedStorage/Modules/UI/<X>` | 7 |
| `RenseiTests.Test_WrongGuess`, `Play_WrongGuess` | `Scripts/ServerStorage/RenseiTests/<X>.lua` | `ServerStorage/RenseiTests/<X>` | new (2, 3) |
| `RenseiTests.Play_FoundryLedger`, `Play_Exams` | `Scripts/ServerStorage/RenseiTests/<X>.lua` | `ServerStorage/RenseiTests/<X>` | regressions (pairs; not changed) |

**Read-only, not changed:**
- `NoiseService` (`Emit(Position, KindOrRadius, Source)`, `NoiseService.lua:39-56`; a number radius has no Kind; `NoiseService.Log` records emits when set);
- `MoralityService` (`Record(Player, DeedId, Quiet, Ctx)`, `:94`), `HeatService`, `RumourService`, `WitnessService`;
- `DownedManager` (`Damage(Victim, Amount)`, `DownedManager.lua:227-240`; it knocks down when the amount reaches health, and scales by `DamageTakenMult`);
- `ProgressionService` (`GetData`, `Sync`, `SpendMoney` `:128-136`);
- `StoryService` (`SetFlag(Player, Id, Value, Overwrite)`, `StoryService.lua:28-37`; it signals a `Flag` quest objective and syncs);
- `QuestService` (`Definitions` is the `Rensei.Quests` table itself, `QuestService.lua:27`, `:33`);
- `AlchemyMinigames`, `AlchemyMinigameUI` (their builders call the panel's `Result` callback, which Task 7 wraps);
- `PuzzleClient`, `WorldChallenges`, `TrialService`, `IdentityService`, `TownsfolkService`, `DialogueService`;
- the Adit boards kit, `Art/Studio/HalvardsAdit/boards/` (a 2026-10-20 record; spec §1.3).

**Studio-only modules this plan calls** (no repo copy; Task 1 confirms): `UIService.Notify(Player, "Toast" | "Banner" | "CaseResult", Payload)`, and `Managers.StatusManager.Apply(Character, Status, {Duration})` (TrialService uses it, `TrialService.lua:110-117`).

**What the code does today** (the spec's §1 has the line numbers):
- wrong answers cost nothing anywhere, attempts are unlimited, and there is no cooldown except the 0.3 s submit gap;
- closing a minigame and reopening it deals a fresh puzzle;
- the Assay Bench, the Ledger Cipher and the Case Board can be brute-forced;
- `LateHint` shows from the third try;
- the only told-first penalty in the game is Identities' 10-minute wrong-name lock.

---

## Global Constraints

**Owner rules:**
- "Do not publish the Roblox game or modify live player data."
- "Do not expose API keys, credentials, private player data, or other secrets."
- "Do not blindly copy another game's code or assets."
- **UI:** use only the game's existing UI assets. This plan's only visible text is drawn in labels that already exist: the minigame panel's result line, the Journal's paragraphs (`Kit:Paragraph`), and the toast. No new images, fonts, sounds, frames or ScreenGuis, and no `StarterGui` edits.
- **Never a dead end** (spec §3): every lock is timed, Waste falls back to a lock, Backfire never knocks down, and TipOff never gates anything. The validator (Task 2) enforces it, and a check fails the task if it doesn't hold.

**Labels and records:**
- Label every invented number, name and line **PROPOSAL** in code comments and docs.
- No task writes a Changelog entry except Task 10, which writes one entry for the whole plan.
- Implementers report to the controller in their final message.
- Implementers never dispatch subagents and never write under `.superpowers/`: the harness refuses it.

**Studio bridge:**
- Run Luau with `python -I C:/Users/Owner/Rensei-Game-Design/Art/Tools/rbxc.py luau "placeId: <id>" <Edit|Server|Client> @file.lua`.
  - Only the first return value prints, cut at 30,000 characters.
  - For a longer return, write it to a StringValue in ServerStorage, read it back in 25,000-character chunks, and delete it.
  - If `Client` isn't accepted by rbxc, client checks run as a TEMP LocalScript (the gun plan's Task 7 pattern).
- **Studio state:** `rbxc.py call get_studio_state '{"studio_id":"<id>"}'`.
- **Play:** `rbxc.py call start_stop_play '{"is_start":true|false,"studio_id":"<id>"}'`.
- **Foundry quirk:** rbxc sometimes returns "Target is not reachable (DMN_ID_EDIT)" even though the call ran. Before retrying anything that isn't idempotent, read the state the call would have changed.
- Put scratch files in `C:/Users/Owner/AppData/Local/Temp/claude/C--Users-Owner/ecd4cd55-01de-4070-9638-cb228809b769/scratchpad/wrongguess-plan/`.

**Play** is hooked and protected, because Play writes the owner's REAL save.

- **One Play session at a time across Ye and Foundry.** Before Play:
  - `get_studio_state` must show the **other** place in Edit;
  - Ye's `game.ServerStorage:GetAttribute("PlayLock")` must be nil.
- **The order, every session:**
  1. **Lock.** In Ye (Edit), `game.ServerStorage:SetAttribute("PlayLock", "<Ye|Foundry>:wg<task>")`. When playing Foundry, set the same attribute in Foundry too.
  2. **Hook.** In the playing place (Edit), run `C:/Users/Owner/.claude/jobs/0c39df78/tmp/blender/hook.lua`. Then install the dump helper: `rbxc.py luau "placeId: <id>" Edit @Art/Studio/Regions/Foundry/data/dumphelper.lua`. It returns "dump helper installed".
  3. **Start Play.** In the Server data model, wait until `game.ServerStorage:GetAttribute("LMSnapTaken")` is set. Then:
     - **take the dump:** `return game.ServerStorage:WaitForChild("LMQuestDump", 30):Invoke()`. Save it to the scratch folder as `quests_wg<task>_1.txt`;
     - **and the probe** (Server): one line holding the player's `Data.Money`, `Data.Morality.Deeds.tripped_alarm` (nil or its record), `Data.Morality.Heat` (canonical, keys sorted), and every `Data.Story.Flags` key that starts with `Guess_`, `Clam_` or `TipOff_`, with its value, sorted. Save it as `probe_wg<task>_1.txt`. Tests in this plan write strikes, flags, money, deeds and Heat into the real save.
  4. **Suites.** Run them with `game.ServerStorage.LMRunSuite:Invoke("<Suite>")` (Server).
  5. **Put things back.** Every test restores what it changed before it returns, in a `finally`: injected definitions, `WrongGuessService`'s clock, `NoiseService.Log`, the character's health, and any minigame session (`MinigameService.Cancel`).
  6. **Restore.** Run `game.ServerStorage.LMTestHook:Invoke("restore")` (Server). It must return "restored".
     - Dump again (`quests_wg<task>_2.txt`). It must equal the first dump, character for character.
     - Probe again (`probe_wg<task>_2.txt`). It must equal the first probe.
     - `LMTestHook:Invoke("diff")` may list only the known encode-quirk keys (Settings, Story, Morality). **Any other key**, or a dump or probe that differs, means stop: keep Play running and report both dumps, both probes and the diff to the controller. The owner's real save would be written wrong at Stop.
  7. **Stop** Play.
  8. **Unhook.** In Edit, run `C:/Users/Owner/.claude/jobs/0c39df78/tmp/blender/unhook.lua`. Then remove the helper: copy `dumphelper.lua` to the scratch folder, set its MODE line to `"remove"` there (only that line), and run the copy in Edit. It returns "removed <n>".
  9. **Unlock.** Only then, clear PlayLock in both places.
- **Script edits are refused while Play runs.**
- **In Play, the world is a copy.** Definitions injected into a required table in Play vanish at Stop. Save data is real: the hook's restore puts it back.
- **Edit's require cache.** Edit keeps a module's result between `execute_luau` calls. Every suite here runs **in the Play VM** (`LMRunSuite`), because each requires a module this plan changes. Edit runs are only for Task 1's survey.
- **Run Play_Boot first** in every Foundry session (the Foundry plan's note). **Known failures:** Play_Travel 5/2 and Play_RideEvents 8/1 fail only on the Cabin/Second ticket in the owner's save. They are not regressions.

**Scripts live in both places.**
- Every script is edited in the repo first, then set into **both** places with the sync tool:
  ```
  python -I Art/Studio/Regions/Foundry/data/sync.py --place ye|foundry --backup Pre-WrongGuess_2026-10-25 --only <label>[,<label>...] --run
  python -I Art/Studio/Regions/Foundry/data/sync.py --place ye|foundry --check
  ```
- **Start every task that touches a script with `--check` in both places.** If anything differs, stop and report: another plan's work may not be synced yet, and syncing over it would lose it.
- `--check` must print `DIFFER 0 / MISSING 0` for **both** places at the end of every task that touched a script.
- Each task adds its own pairs to `Art/Studio/Regions/Foundry/data/sync_manifest.json` (the Foundry plan's Task 1 format), with `Places: ["ye", "foundry"]`. New scripts get `Create: true`.
- **Backups:** with `--backup Pre-WrongGuess_2026-10-25`, the tool clones a script once, before its first change in this plan, into `ServerStorage.RenseiBackups["Pre-WrongGuess_2026-10-25"]` in that place. **Never sync this plan's scripts without `--backup`:** older plans' folders already hold older copies of some of them, so an undo from those would drop later work. A created script gets no backup and carries `FoundryDataAdd = true` (the tool's existing mark).
- **The normalised hash** (Studio == repo means these strings are equal) is the one in `sync.py` (`norm_hash`) and in the Foundry plan's Global Constraints.
- **Packages:** `Modules` and `RenseiServer` are packages. Syncing changes both places' package copies. Publishing them is the owner's (Task 10's checkpoint).

**Tests:**
- **RED then GREEN.** Every new check is run once where it **must fail**, and fails: before the change, or against a control that keeps today's rule. Then it passes after.
- **A check that cannot fail is not a check.**
  - Every "unarmed does nothing" check runs the **same** input against an **armed control** in the same test and sees a strike there. Without the control, today's code would pass it.
  - Every "refused while locked" check first sees the same action succeed with no lock.
  - Expected numbers (strikes, seconds, radius, share) are written by hand in the test, never read from `Rensei.WrongGuess` at check time.
- **Test definitions** (a minigame, a puzzle, a deduction, a quest) are injected into the required tables in Play and removed in `finally`. Nothing test-only is added to shipped data.
- **Time:** tests move `WrongGuessService`'s clock (`SetClock`), never wait out a lock.
- **No duplicated test logic.** Helpers live once, at the top of `Play_WrongGuess`; no other suite needs them.
- When a check fails, fix the cause in the task that owns it (the controller rules), never by loosening the check.

**Publish order** (`Documents/World Travel.md` §10):
1. packages from Ye;
2. Foundry's packages updated by hand and checked with `sync.py --check`;
3. the places;
4. Migrate to Latest Update last.

This plan never publishes.

**Git:**
- Commit by path only: `git add -- <new paths>`, then `git commit -m "<msg>" -- <paths>`. Never `git add -A`.
- Never stage `.blend` or `.blend1` files or `Art/Blender.rar`.
- End every commit message with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Implementers don't push.

---

## Shared files with the earlier plans

This plan runs **after** the gun rework, the swimming revamp, the assassinations and the stealth missions. The rule for every shared file: run `--check` first, edit the repo file (which already holds the earlier plans' changes), sync with this plan's `--backup`, `--check` again. Never sync an older copy.

| File | Gun rework | Swimming revamp | Assassinations | This plan | How they meet |
|---|---|---|---|---|---|
| `sync.py` | Task 1: `--backup` | Task 1: `--backup` (whichever runs first) | uses it | uses it; **no change** | — |
| `sync_manifest.json` | pairs | pairs | pairs | pairs | append only |
| `Rensei/Deeds.lua` | — | — | Task 6: `assassinated_bandit` | Task 3: `tripped_alarm` | different keys, a new block each |
| `Rensei/StoryLogic.lua` | — | — | — | Task 2: two conditions | the Foundry plan's `UpgradeQuest` is untouched |
| `NoiseService.lua` | — | Task 7: `StepPlayer` | read | **read only** (`Emit` with a number radius) | no edit here |
| `Rensei/Perception.lua` | — | Task 7: sounds | Task 4: sounds | **not touched** (a number radius needs no named sound) | — |
| `PerceptionService.lua` | — | Task 7 | Tasks 4–5 (`Glimpse`, `Raise`, bodies) | **not touched** (`Emit` calls its `Hear`) | an Alarm is judged by whatever hearing rules are live then |
| `DownedManager.lua` | — | — | Task 6: `Knock(Victim, Seconds)` | **read only** (`Damage`) | Backfire stays below the knock line, so a knock length never applies |
| `ServerHandler.server.lua` | Task 5: a start line | — | Task 7: a start line | **not touched** | `WrongGuessService` needs no `Start()`: its one connection (`PlayerRemoving`) is made when it is first required |
| `MoralityService`, `HeatService`, `RumourService`, `WitnessService` | — | — | read | read | — |
| Regression suites `Play_Stealth`, `Play_Heat`, `Play_Morality`, `Play_Rumours` | — | Task 7 adds tests | Task 4 adds tests | run only | — |
| `Changelog.md`, `Backlog.md`, `Scripts/README.md` | Task 12 | Task 10 | Task 12 | Task 10 | new entries and rows only |

**The stealth missions plan isn't written yet.** Its spec (`specs/2026-10-25-stealth-missions-design.md` §2.5, §6) names the Ledger Cipher minigame for "Copy a document", compounds with locks, and new deeds and quests. So it will probably touch `Rensei.Minigames`, `MinigameService`, `Rensei.Quests`, `Rensei.Deeds` and perhaps `PuzzleService`.
- **Task 1 reads that plan** (once it exists) and its commits, and lists every file it changed that this plan also changes. The same `--check`-first rule then applies.
- **If it changed `MinigameService.Submit` or `Open`,** Task 4 puts this plan's hooks at the same points in its version. It doesn't move them back.
- **Task 8 arms what it built** (compound locks, ciphers on mission quests) with an Alarm, using that plan's stakes, only if they exist.
- **The note for that plan's author:** call `WrongGuessService.Listen` for Loud grading rather than reading flags, and give mission quests an explicit `Stakes`.

**Not touched by this plan,** so no overlap: `TuningConfig`, `WeaponManager`, `SwimService`, `TakedownService`, `TownsfolkService` (other work is in flight there), `DialogueService` (ClamUp is read through `Requires` conditions it already evaluates), `AlchemyMinigames`, `AlchemyMinigameUI`, `PuzzleClient`, `WorldChallenges`, `TrialService`, `IdentityService`, and the Adit boards kit.

---

## Decisions taken without the owner, by task

The owner was asleep (overnight go-ahead, 2026-10-25). Each is a PROPOSAL, listed in the spec's §13, and built so the owner can change it by a number in `Rensei.WrongGuess` or one data line.

| | Decision (PROPOSAL) | Task |
|---|---|---|
| 1 | Stakes 0–3 per quest, from `Stakes`, a new `StoryAct` field, or the Exploration `Tier` | 2 |
| 2 | Armed only while the owning quest is Active; drills, world challenges, trials and optional side minigames never | 2 |
| 3 | Day one arms only `foundry_ledger_who` (`foundry_ledger` gets `StoryAct = 2`) | 8 |
| 4 | The defaults: strikes 3/2/2, lock 60/180/300 s, alarm 25/40/60 studs, backfire 5/10/15%, waste ×1/×1.5/×2, clam 120/300/600 s; caps 5 strikes, 600 s, 80 studs, 20%, 500, 900 s | 2 |
| 5 | Strikes saved in `Story.Flags`, cleared on a pass, reset when the consequence fires, no time decay | 2, 3 |
| 6 | Every server-rejected answer on an armed puzzle is a miss | 4, 5 |
| 7 | `LateHint` after the first miss on armed puzzles | 4 |
| 8 | Waste costs money and falls back to a lock | 3 |
| 9 | Backfire stops at 25% health, never knocks; Burn or Freeze for at most 2 s | 3 |
| 10 | Alarm is a number radius through `NoiseService.Emit`; `Crime` records `tripped_alarm` (Crime 5, HeatCap 15, Local, 3 a day) | 3 |
| 11 | ClamUp is a timed flag plus `Clammed` / `NotClammed`; townsfolk lines untouched | 2, 3 |
| 12 | TipOff is a flag only; the validator stops it gating anything | 2, 3 |
| 13 | Parties: per-player strikes and locks; an Alarm is heard in the world | 3 |
| 14 | A 1 s throttle on the `"Deduce"` request, armed or not | 5 |
| 15 | Warnings in the panel's result line, a Case Board paragraph and a first-touch toast | 6, 7 |
| 16 | Identities' wrong-name lock stays as it is | — |
| 17 | Trials and world challenges out of scope | — |
| 18 | Puzzle `Wrong` states built; no shipped puzzle uses one yet | 6 |

---

## File map

| File | Responsibility | Task |
|---|---|---|
| `Art/Studio/Regions/Foundry/data/sync_manifest.json` | This plan's pairs | 1 (pairs added in every task) |
| `Art/Studio/WrongGuess/survey_wrongguess.lua` (new), `survey_ye.json`, `survey_foundry.json` (new, written from its output) | Read-only survey | 1 |
| `Rensei/WrongGuess.lua` (new), `Rensei/StoryLogic.lua`, `RenseiTests/Test_WrongGuess.lua` (new) | The pure rules, `Clammed` / `NotClammed` | 2 |
| `ServerScriptService/WrongGuessService.lua` (new), `Rensei/Deeds.lua`, `RenseiTests/Play_WrongGuess.lua` (new) | Strikes, locks and the six effects; the deed | 3 |
| `ServerScriptService/MinigameService.lua`, `Play_WrongGuess.lua` | Minigames | 4 |
| `ServerScriptService/InvestigationService.lua`, `Requests/Investigation.lua`, `Play_WrongGuess.lua` | Deductions | 5 |
| `ServerScriptService/PuzzleService.lua`, `Play_WrongGuess.lua` | Puzzles: `Wrong` states, locks, the first-touch toast | 6 |
| `UI/MinigameUI.lua`, `UI/JournalUI.lua`, `Art/Studio/WrongGuess/client_checks.lua` (new) | The warning lines | 7 |
| `Rensei/Quests.lua`, `Rensei/Investigation.lua` (and, only if the stealth plan built them, `Rensei/Minigames.lua` / `Puzzles.lua`), `Test_WrongGuess.lua`, `Play_WrongGuess.lua` | Day-one data | 8 |
| (no new files) | Foundry parity and the full sweep | 9 |
| `Documents/Changelog.md`, `Backlog.md`, `Scripts/README.md`, `Quests, Puzzles and Minigames Proposal.md` (a pointer) | Docs | 10 |

All `Rensei/` paths are `Scripts/ReplicatedStorage/Modules/Data/Rensei/`. `UI/` is under `Scripts/ReplicatedStorage/Modules/`. `RenseiTests/` is `Scripts/ServerStorage/RenseiTests/`. `Requests/` is `Scripts/ServerScriptService/ServerHandler/Requests/`.

---

### Task 1: Parity and the read-only survey

**Files:**
- **Modify:** `sync_manifest.json`.
- **Create:** `Art/Studio/WrongGuess/survey_wrongguess.lua`, `survey_ye.json`, `survey_foundry.json`.
- **No Studio change. No game behaviour change.**

**Interfaces:**
- **Manifest pairs added** (each only if it isn't a pair yet), all with `Places: ["ye", "foundry"]` and `Create: false`:
  - `RenseiServer.MinigameService`, `RenseiServer.PuzzleService`, `RenseiServer.InvestigationService`;
  - `Requests.Investigation`;
  - `UI.MinigameUI`, `UI.JournalUI`;
  - the regression suites, so the sweep sees them: `RenseiTests.Play_Heat`, `Play_Morality`, `Play_Rumours`, `Play_Stealth` (if not already pairs).
- **`survey_wrongguess.lua`** (read-only, Edit, no MODE line: it never writes). It returns JSON with:
  - **`Scripts`:** for each label above, and for the expected paths of `WrongGuess`, `WrongGuessService`, `Test_WrongGuess`, `Play_WrongGuess`: whether the Studio path exists, and its class. The four new ones must be absent;
  - **`Modules`:** whether `UIService` and `Managers.StatusManager` exist where the repo code requires them, and the source lines that define `UIService.Notify` and `StatusManager.Apply` (path and line only);
  - **`Statuses`:** whether `StatusManager` knows `Burn` and `Freeze` (a string search of its Source);
  - **`AditBoards`:** whether `ServerStorage.RenseiTests.Play_AditBoards` exists (Ye only; it decides whether Task 6 can run it);
  - **`Stealth`:** every `Rensei.Minigames` and `Rensei.Puzzles.Puzzles` id that isn't in this plan's 2026-10-25 list (the spec's §1.7). Those are the stealth plan's additions, for Task 8;
  - **`SendData`:** the line in `DataManager` that sends the profile, so the report can say whether `Story.Flags` reaches the client whole.
- **The stealth plan check** (by reading the repo, not Studio): `git log --stat` since this plan was committed, and that plan's file map. List every file it changed that this plan changes.

**Steps:**
- [ ] **Step 1: `--check` both places** (the global rule). Report any DIFFER and stop.
- [ ] **Step 2: RED.** Add the manifest pairs, then run `sync.py --place ye --check`.
  - Any pair whose repo file is out of date with Ye shows as DIFFER.
  - If an **existing** repo copy differs from Ye, Studio wins: export Ye's copy over the repo file, byte for byte with CRLF normalised to LF, and list it in the report.
  - If Foundry differs from Ye on a pair, report it; the controller rules before any sync.
- [ ] **Step 3:** Run `--check` in both places. Expected: `DIFFER 0 / MISSING 0`.
- [ ] **Step 4:** Write `survey_wrongguess.lua`. Run it in Ye (Edit) and in Foundry (Edit). Save each output as `survey_ye.json` / `survey_foundry.json`.
- [ ] **Step 5:** Commit `sync_manifest.json`, `survey_wrongguess.lua`, `survey_ye.json`, `survey_foundry.json` and any re-exported files: `"Wrong-guess Task 1: parity pairs and the read-only survey"`.

**Report:**
- the survey's answers;
- the stealth plan's overlapping files, and whether it touched `MinigameService.Open` / `Submit`;
- any stealth-plan minigame, puzzle or quest that Task 8 might arm.

---

### Task 2: `Rensei.WrongGuess` and two StoryLogic conditions

**Files:**
- **Create:** `Rensei/WrongGuess.lua`, `RenseiTests/Test_WrongGuess.lua`.
- **Modify:** `Rensei/StoryLogic.lua`, `sync_manifest.json` (`Rensei.WrongGuess`, `RenseiTests.Test_WrongGuess`, both `Create: true`).

**Interfaces** (`Rensei.WrongGuess`; every number PROPOSAL):
```lua
WrongGuess.Enabled = true -- the kill switch: false = today's behaviour everywhere
WrongGuess.Kinds = {Lockout = true, Alarm = true, Backfire = true, Waste = true, ClamUp = true, TipOff = true}
WrongGuess.ActStakes  = {[1] = 0, [2] = 1, [3] = 2, [4] = 2, [5] = 3}
WrongGuess.TierStakes = {[1] = 0, [2] = 1, [3] = 2, [4] = 3}
WrongGuess.Defaults = {
	[1] = {Strikes = 3, Lock = 60,  Radius = 25, Share = 0.05, WasteMult = 1,   Clam = 120},
	[2] = {Strikes = 2, Lock = 180, Radius = 40, Share = 0.10, WasteMult = 1.5, Clam = 300},
	[3] = {Strikes = 2, Lock = 300, Radius = 60, Share = 0.15, WasteMult = 2,   Clam = 600},
}
WrongGuess.Caps = {Strikes = 5, Lock = 600, Radius = 80, Share = 0.20, Money = 500, Clam = 900, StatusTime = 2}
WrongGuess.Floor = 0.25 -- Backfire never takes health below this share of max
WrongGuess.Statuses = {Burn = true, Freeze = true}

WrongGuess.Key(Kind, Id)            -- Kind "M" | "P" | "D" -> "M:adit_winch"
WrongGuess.FlagName(Key)            -- "M:adit_winch" -> "Guess_M_adit_winch"
WrongGuess.Read(Flags, Key)         -- -> Used, Until (0, 0 when absent or unreadable)
WrongGuess.Write(Used, Until)       -- -> "<Used>:<Until>", or nil when both are 0 (the flag is removed)
WrongGuess.StakesOf(QuestDef)       -- explicit Stakes, else ActStakes[StoryAct], else (Exploration) TierStakes[Tier], else 0; clamped 0..3
WrongGuess.QuestOf(Kind, Id, Def, Quests) -- Def.Consequence.Quest, else the first quest with an objective of
                                    -- Kind Minigame (M) / Puzzle (P) / Deduce (D) whose Target == Id; else nil
WrongGuess.Armed(Kind, Id, Def, Data, Quests) -- -> Stakes (0 = off), QuestId.
                                    -- 0 unless Enabled, Def.Consequence, a quest found, that quest Active
                                    -- (StoryLogic.Meets({Quest = {Id = Q, Is = "Active"}}, Data)) and StakesOf >= 1
WrongGuess.StrikesFor(Def, Stakes, Mods) -- Def.Strikes or the default, + (Mods and Mods.Strikes or 0), clamped 1..Caps.Strikes
WrongGuess.LockFor(Def, Stakes)     -- Lockout: Lock or the default; other kinds: Lock (true = the default) or 0; capped
WrongGuess.Step(Used, Strikes)      -- a miss -> NewUsed, Fired (Fired: NewUsed reached Strikes; NewUsed is then 0)
WrongGuess.LockedFor(Flags, Key, Now) -- seconds left (0 = free)
WrongGuess.Line(Def, Stakes, Used, LockedFor) -- the player's line: Warn .. " (n tries left)", or "Come back to it in n min."
WrongGuess.Clammed(Flags, Npc, Now) -- (Flags["Clam_" .. Npc] or 0) > Now
WrongGuess.Validate(Minigames, Puzzles, Investigation, Quests) -- -> {problem strings}; empty = valid
```
- **`Validate` refuses:**
  - an unknown `Kind`;
  - a missing `Warn` or `Text`;
  - `Strikes` outside 1–5;
  - a `Lock` over 600, a `Radius` over 80, a `Share` over 0.2, `Money` over 500, a ClamUp `For` over 900;
  - a Backfire `Status` not in `Statuses`, or one lasting over 2 s;
  - a ClamUp with no `Npc`;
  - a `Consequence.Quest` that doesn't exist;
  - a puzzle `Wrong` that isn't a function;
  - **any `Requires`** (quest start, inspect, minigame, mechanism prompt) that names a TipOff flag (`TipOff_*`, or a `Consequence.Flag`) under `Flag` or `FlagIs`. Outcomes and dialogue `Alt` lines may read it.
- **StoryLogic:** two conditions, documented in its header list:
  - `Clammed = "Npc" | {...}`: each NPC's `Story.Flags["Clam_<Npc>"]` is a number greater than `os.time()`;
  - `NotClammed = "Npc" | {...}`: the opposite.

  StoryLogic must **not** require `WrongGuess` (`WrongGuess` requires StoryLogic), so the check is written inline.

**`Test_WrongGuess`** (pure; it runs in the Play VM by the global rule). Expected values are written by hand:
- **`StakesRule`:** `{Stakes = 2}` → 2; `{StoryAct = 1}` → 0; `{StoryAct = 2}` → 1; `{StoryAct = 5}` → 3; `{Category = "Exploration", Tier = 1}` → 0; `Tier = 4` → 3; `{}` → 0; `{Stakes = 9}` → 3.
- **`FlagRoundTrip`:** `Write(2, 1700000000)` reads back as 2, 1700000000; `Write(0, 0)` is nil; `Read` of `"junk"` is 0, 0.
- **`StepFires`:** with 3 strikes, `Step(0)` → 1, false; `Step(1)` → 2, false; `Step(2)` → 0, true.
- **`DefaultsAndCaps`:** `StrikesFor({}, 1)` is 3; `StrikesFor({Strikes = 9}, 1)` is 5; `LockFor({Consequence = {Kind = "Lockout"}}, 2)` is 180; `LockFor({Consequence = {Kind = "Lockout", Lock = 9999}}, 1)` is 600; `LockFor({Consequence = {Kind = "Alarm"}}, 1)` is 0; `LockFor({Consequence = {Kind = "Alarm", Lock = true}}, 3)` is 300.
- **`ArmedNeedsAnActiveQuestWithStakes`:** a hand-built `Quests` table with `wgq = {StoryAct = 2, Stages = {{Id = "s", Objectives = {{Id = "o", Kind = "Minigame", Target = "wgm"}}}}}` and a `Data` with `wgq` Active → `Armed("M", "wgm", Def)` is 1, "wgq". **The same call** with `wgq` not Active is 0; with `StoryAct = 1` is 0; with `Enabled = false` is 0; with no `Consequence` is 0. The first assertion is the control for the other four.
- **`QuestOfFindsObjectives`:** `D` finds a `Deduce` objective; `P` finds a `Puzzle` objective; an explicit `Consequence.Quest` wins.
- **`ValidatorCatches`:** one hand-made bad def per refusal listed above, each producing exactly one problem; one good def producing none.
- **`ClammedCondition`:** `StoryLogic.Meets({Clammed = "Tobin"}, Data)` with the flag at `os.time() + 60` is true, at `os.time() - 1` is false, absent is false; `NotClammed` is the opposite in all three.

**Steps:**
- [ ] **Step 1: RED.** Write `Test_WrongGuess`. Add the pairs. Sync `RenseiTests.Test_WrongGuess` to both places (`--backup`). Run it in Play in Ye (`Ye:wg2`, the full protocol). Expected: every test FAILs (no module).
- [ ] **Step 2: Implement** `WrongGuess.lua` and the StoryLogic conditions. Sync `Rensei.WrongGuess` and `Rensei.StoryLogic` to both places.
- [ ] **Step 3: GREEN** in the same kind of session: `Test_WrongGuess` 0 FAIL. Regressions: `Test_QuestRevision`, `Play_QuestEngine` (StoryLogic changed).
- [ ] **Step 4:** `--check` both places.
- [ ] **Step 5: Commit** `WrongGuess.lua`, `StoryLogic.lua`, `Test_WrongGuess.lua` and the manifest: `"Wrong-guess Task 2: Rensei.WrongGuess (stakes, strikes, validator) and Clammed conditions"`.

---

### Task 3: `WrongGuessService`, the six effects, and `tripped_alarm`

**Files:**
- **Create:** `ServerScriptService/WrongGuessService.lua`, `RenseiTests/Play_WrongGuess.lua`.
- **Modify:** `Rensei/Deeds.lua`, `sync_manifest.json` (`RenseiServer.WrongGuessService`, `RenseiTests.Play_WrongGuess`, both `Create: true`).

**Interfaces** (`WrongGuessService`, the only writer of `Guess_*`, `Clam_*` and TipOff flags):
```lua
WrongGuessService.SetClock(Fn)              -- tests; default os.time
WrongGuessService.Gate(Player, Kind, Id, Def)  -- -> true | false, line. Refuses while locked, armed or not
WrongGuessService.Info(Player, Kind, Id, Def)  -- -> nil (unarmed) | {Stakes, Strikes, Left, LockedFor, Line}
WrongGuessService.Miss(Player, Kind, Id, Def, Ctx) -- Ctx = {Position = Vector3?}
	-- -> nil when unarmed (nothing written); else {Left, Fired, Kind, Text, LockedFor, Line}
WrongGuessService.Clear(Player, Kind, Id)    -- a pass: removes the Guess_ flag
WrongGuessService.WarnOnce(Player, Kind, Id, Def) -- a toast with Info.Line, once per player per key per session
WrongGuessService.Listen(Fn)                -- Fn(Player, Key, Kind, Position) after a consequence fires; returns stop()
```
- **The strike flag** is written straight into `Data.Story.Flags[FlagName]`, then `ProgressionService.Sync`, as PuzzleService writes `Mech_` flags (`PuzzleService.lua:96-98`). It does **not** go through `StoryService.SetFlag`, so a strike never signals a quest `Flag` objective.
- **When a consequence fires** (`Miss` with `Fired`):
  - the strikes reset to 0;
  - a lock is written if `LockFor > 0`;
  - the effect runs, each in a `pcall`. An effect that errors still leaves the lock and the reset, and `warn`s.
- **The effects:**
  - **Lockout:** only the lock.
  - **Alarm:** `NoiseService.Emit(Ctx.Position or the root's position, Radius, Player.Character)`. With `Consequence.Crime`, also `MoralityService.Record(Player, "tripped_alarm", false, {Witness = true})`. Never `HeatService.Add`.
  - **Backfire:**
    - Amount = `min(Share × MaxHealth, Health − Floor × MaxHealth)`;
    - skipped when the amount is ≤ 0, or when the player is knocked down (`DownedManager.IsKnocked`);
    - divided by the character's `DamageTakenMult` if it is a positive number, so `DownedManager.Damage` lands the intended amount;
    - then `DownedManager.Damage(Character, Amount)`; with `Status`, `StatusManager.Apply(Character, Status, {Duration = min(StatusTime, 2)})`.
  - **Waste:** `ProgressionService.SpendMoney(Player, floor(Money × WasteMult))`. If that returns false, the player gets the stakes' default lock instead, and the line says so.
  - **ClamUp:** `StoryService.SetFlag(Player, "Clam_" .. Npc, Now + For, true)`.
  - **TipOff:** `StoryService.SetFlag(Player, Flag or ("TipOff_" .. QuestId), Now, true)`.
- **Parties:** nothing is shared. Each player has their own flags.
- **Lifetime:** a `PlayerRemoving` connection, made when the module is first required, clears the WarnOnce set. **No `Start()`**, so `ServerHandler.server.lua` is untouched.

**The deed** (`Rensei/Deeds.lua`, a new block `-- ===== Wrong-guess consequences (2026-10-25 plan). PROPOSAL numbers. =====`):
```lua
tripped_alarm = {Text = "Was heard forcing a lock", Conduct = {}, Scope = "Local",
	Crime = 5, HeatCap = 15, Repeat = {Cap = 3}}, -- PROPOSAL
```

**`Play_WrongGuess`** (Play, Ye, inside the hook). The shared helpers at the top:
- `Inject(Kind, Id, Def, QuestDef)`: adds the def and a test quest `wg_test_<n>` (with the objective that owns it) to the live tables, starts the quest with `QuestService.Start`, and returns an undo;
- `Clock(Seconds)`: offsets `WrongGuessService`'s clock;
- `Guard(Body)`: runs `Body` in a `pcall`; always undoes every injection, resets the clock, restores the character's health, and clears `NoiseService.Log`.

**Tests** (for this task, through `Miss` / `Gate` directly, on an injected minigame-shaped def `M:wg_m`):
- **`MissesCountThenFire`:** with `StoryAct = 2` (3 strikes, Lockout 60):
  - `Miss` returns Left 2, then 1, then Fired with LockedFor 60;
  - the flag reads `"0:<now+60>"`;
  - `Gate` is false;
  - after `Clock(61)`, `Gate` is true.
- **`UnarmedWritesNothing`:**
  - **the control first:** the armed def above gets a strike;
  - then the same def under a quest with `StoryAct = 1` → `Miss` returns nil, and no `Guess_` flag exists.
- **`ClearOnPass`:** two misses, then `Clear` → no flag; the next `Miss` returns Left 2.
- **`LockSurvivesTheSession`:** fire; drop the service's in-memory WarnOnce set (as a rejoin would); `Gate` is still false (the lock is in the save).
- **`Alarm`:** a def with `Kind = "Alarm", Radius = 30, Crime = true`, Strikes 1:
  - `NoiseService.Log` (set to `{}` for the test) holds one entry with Radius 30 at `Ctx.Position`;
  - `Data.Morality.Deeds.tripped_alarm` exists.
  - **Control:** the same def without `Crime` → a noise and no deed.
- **`BackfireStopsAtTheFloor`:**
  - health is read in the same frame as each fire, so regeneration can't blur it;
  - set health to 50% of max; a `Share = 0.2` backfire → health is 30% ± 0.5%;
  - fire again at 30% → health is 25% ± 0.5%, and the character is never `Knocked`;
  - fire at 25% → health doesn't change.
- **`WasteFallsBackToALock`:**
  - with money ≥ 40, `Money = 40` at Stakes 1 → money falls by 40, no lock;
  - with money set to 10 → money is unchanged and `Gate` is false (the default 60 s lock).
- **`ClamUpAndTipOff`:**
  - ClamUp `Npc = "WgTestNpc", For = 120`, with the service clock at real time → `Story.Flags.Clam_WgTestNpc` equals the clock's now + 120 (± 1), and `StoryLogic.Meets({Clammed = "WgTestNpc"}, Data)` is true. Expiry is checked with the pure function, not by waiting: `WrongGuess.Clammed(Flags, "WgTestNpc", now + 121)` is false. (StoryLogic reads `os.time()`, not the service clock.)
  - TipOff → the flag `TipOff_wg_test_<n>` is set.
- **`ListenHearsAFire`:** a listener sees exactly one call per fire, with the key and kind.

**Steps:**
- [ ] **Step 1: RED.** Write `Play_WrongGuess` with the tests above. Add the pairs; sync the suite and `Rensei.Deeds` to both places. Play in Ye (`Ye:wg3`): every test FAILs (no service; `tripped_alarm` unknown).
- [ ] **Step 2: Implement** the service and the deed. Sync `RenseiServer.WrongGuessService` and `Rensei.Deeds` to both places.
- [ ] **Step 3: GREEN** (`Ye:wg3`): `Play_WrongGuess` 0 FAIL, `Test_WrongGuess` 0 FAIL. Regressions: `Play_Morality`, `Play_Heat`, `Play_Rumours` (a new deed), and `Play_Stealth` (noise). The probe must match after restore.
- [ ] **Step 4:** `--check` both places.
- [ ] **Step 5: Commit** the service, the suite, `Deeds.lua` and the manifest: `"Wrong-guess Task 3: WrongGuessService, the six effects, tripped_alarm"`.

---

### Task 4: Minigames

**Files:** modify `ServerScriptService/MinigameService.lua` and `Play_WrongGuess.lua`.

**Interfaces** (lines refer to today's `MinigameService.lua`; if the stealth plan moved them, use the same points in its version):
- **`Open`** (`:216`):
  - after the `Requires` check (`:226-232`): `local Ok, Line = WrongGuessService.Gate(Player, "M", Id, Def)`. If not ok, toast the line and return false;
  - `Public.Stakes = WrongGuessService.Info(Player, "M", Id, Def)`.
- **`Submit`** (`:313-337`), on a wrong answer:
  - `local G = WrongGuessService.Miss(Player, "M", S.Id, Defs[S.Id], {Position = Root.Position})`;
  - **no `G`** (unarmed): today's behaviour exactly, including `LateHint` from the third try;
  - **`G` and not `Fired`:** the line is `Reason or Fail`, then `"  (" .. G.Left .. " tries left)"`, then `LateHint` (from the **first** miss);
  - **`G.Fired` with `LockedFor > 0`:** `MinigameService.Cancel(Player, G.Text)`, and return;
  - **`G.Fired` without a lock:** the line is `Reason or Fail` plus `"  " .. G.Text`. The session stays open.
  - The `"Result"` event carries the updated `Info` as a fifth argument (`Remote:FireClient(Player, "Result", false, Text, nil, Info)`), for Task 7.
- **`Pass`** (`:286`): `WrongGuessService.Clear(Player, "M", S.Id)`.
- **World kinds** never reach `Submit` (`:315`), so they are never armed. A test proves it (below).

**Tests** (added to `Play_WrongGuess`; injected `wg_board`, a PressureBoard def, `Valves = 3, Steps = 10, Band = 0.08`, with `Consequence = {Kind = "Lockout", Warn = "W", Text = "T"}` under a `StoryAct = 2` quest):
- **`PanelMissesAndLocks`:**
  - `MinigameService.Open(Player, "wg_board")`;
  - submit a wrong answer three times through the real Submit path. Call the module's submit handler (expose `MinigameService._Submit = Submit` for tests, as `MinigameService.Solve` is exposed) with `{0, 0, 0}`, after first checking with `Solve` that `{0, 0, 0}` is wrong this seed (re-open on the rare seed where it isn't);
  - after the third, `MinigameService.Current(Player)` is nil, and `Open` returns false.
- **`ReopenKeepsTheCount`:** one miss, `Cancel`, `Open` again, one miss → `Info.Left` is 1.
- **`PassClears`:** one miss, then submit `MinigameService.Solve(Player)` → the flag is gone.
- **`LateHintAfterTheFirstMiss`:** a def with `LateHint = "LH"`:
  - armed: the first miss's line contains "LH";
  - **control:** the same def unarmed (`StoryAct = 1`) → the first miss's line doesn't, and the third does.
- **`ChapterOneUnchanged`:** give the live `adit_winch` def a temporary `Consequence` (Lockout, with `Consequence.Quest = "forgotten_halvard"`) and put `forgotten_halvard` (Tier 1) Active. Three wrong submits leave the session open and write no `Guess_` flag.
  - **Control,** in the same test: set the live quest def's `Tier` to 2 for a moment → one wrong submit writes the flag.
  - Put back the def's `Consequence` (nil) and `Tier` (1) in `finally`.
- **Test hook:** `MinigameService._Submit = Submit` is exported, as `Solve` and `Current` are, so tests drive the real submit path.
- **`WorldChallengesNeverArmed`:** inject `wg_world`, a copy of `foundation_run` with `Course = "wg_none"` and a `Consequence`, owned by an Active `StoryAct = 3` quest through a `Minigame` objective.
  - Open it. With no course markers, its first tick fails it through the real watcher path ("This course has no markers yet.", `WorldChallenges.lua:189`). Also call `MinigameService._Submit(Player, {})` while it is open (`Submit` returns at once for world kinds, `:315`).
  - After 0.5 s, no `Guess_M_wg_world` flag exists.
  - **Control:** the same `_Submit` call on the armed panel `wg_board` writes its flag.

**Steps:**
- [ ] **Step 1: RED:** the new tests FAIL against today's `MinigameService` (`Ye:wg4`).
- [ ] **Step 2: Implement.** Sync `RenseiServer.MinigameService` to both places.
- [ ] **Step 3: GREEN** (`Ye:wg4`): `Play_WrongGuess` 0 FAIL; regressions `Play_Exams`, and `Play_AditBoards` if Task 1 found it in Ye.
- [ ] **Step 4:** `--check` both places.
- [ ] **Step 5: Commit** `MinigameService.lua` and the suite: `"Wrong-guess Task 4: minigames count strikes and lock (armed quests only)"`.

---

### Task 5: Deductions

**Files:** modify `ServerScriptService/InvestigationService.lua`, `Requests/Investigation.lua` and `Play_WrongGuess.lua`.

**Interfaces:**
- **`InvestigationService.Deduce(Player, Id, Answers)`** returns `ok, text, info`:
  - **already solved:** unchanged (`:72`);
  - **not enough evidence:** unchanged (`:73`), and no strike;
  - **locked:** `false, <the Gate line>` (after the solved check, before the evidence check);
  - **wrong:** `false, Def.Wrong or "That doesn't hold together.", Info` with `Info = WrongGuessService.Miss(Player, "D", Id, Def, {})`. **The text stays exactly `Def.Wrong`**: `Play_FoundryLedger.lua:176` asserts it;
  - **right:** `WrongGuessService.Clear(Player, "D", Id)`, then as today.
- **`Requests/Investigation.lua`:**
  - **a 1 s throttle per player on `"Deduce"`.** A request inside the second is dropped silently. The throttle table is cleared on `PlayerRemoving`;
  - `CaseResult` gains `Left`, `LockedFor` and `Fired` from `info`. When `info.Fired`, its `Text` is `Def.Wrong .. "  " .. info.Text`, so the toast shows both.
  - The `"Identify"` branch is unchanged.

**Tests** (added; injected deduction `wg_case`, with two slots and evidence the test gives through `StoryService.GiveEvidence`, under a `StoryAct = 2` quest that owns it through a `Deduce` objective):
- **`DeductionStrikesAndLock`:** two wrong boards return `Def.Wrong` exactly, with `info.Left` 2, then 1; the third returns `Fired`; a right board is then refused with the lock line; after `Clock(61)` the right board succeeds and the flag is gone.
- **`NotEnoughEvidenceIsNoStrike`:** without the evidence, three submits each return the existing "You don't have enough to go on yet." line, and no flag is written. **Control:** with the evidence, one wrong board writes the flag.
- **`RequestThrottle`:** two `"Deduce"` requests through the handler module (require it and call it with the player) in the same frame → exactly one `CaseResult` (wrap `UIService.Notify` for the test and restore it).
- **`ChapterOneUnchanged`:** give the live `adit_truth` def a temporary `Consequence` with `Quest = "forgotten_halvard"` (Tier 1, put Active), and give its two pieces of evidence. Three wrong boards return `Def.Wrong` and write no flag.
  - **Control,** in the same test: the quest's `Tier` set to 2 for a moment → one wrong board writes the flag.
  - Everything is put back in `finally`.

**Steps:**
- [ ] **Step 1: RED** (`Ye:wg5`).
- [ ] **Step 2: Implement.** Sync `RenseiServer.InvestigationService` and `Requests.Investigation` to both places.
- [ ] **Step 3: GREEN** in Ye (`Ye:wg5`): `Play_WrongGuess`, `Play_Clue`.
- [ ] **Step 4: Play in Foundry** (`Foundry:wg5`, with Ye in Edit): `Play_Boot` first, then **`Play_FoundryLedger` 0 FAIL**, unchanged. `foundry_ledger` isn't armed until Task 8, and its one wrong board stays a plain `Wrong`.
- [ ] **Step 5:** `--check` both places.
- [ ] **Step 6: Commit** both scripts and the suite: `"Wrong-guess Task 5: Case Board deductions count strikes; the Deduce request is throttled"`.

---

### Task 6: Puzzles

**Files:** modify `ServerScriptService/PuzzleService.lua` and `Play_WrongGuess.lua`.

**Interfaces:**
- **Which puzzles hold a mechanism** is computed on demand (a loop over `Content.Puzzles`, which holds a handful), never cached at start, so puzzles injected by tests are seen.
- **`PuzzleService.MayChange(Player, MechanismId)`** is exported for tests (below).
- **`CheckPuzzles`** (`:70-83`):
  - for each unsolved puzzle containing `ChangedId` with a `Wrong` function: compute `Wrong(S)`;
  - on a **false → true** edge (remembered per player per puzzle, cleared on leave), call `WrongGuessService.Miss(Player, "P", PuzzleId, P, {Position = <the changed mechanism's part>})`;
  - **if it fired with a lock,** every **non-permanent** mechanism of that puzzle goes back to its default (`Mine(Player)[Id] = nil`, `Send`), and the line is toasted;
  - on solve, `WrongGuessService.Clear(Player, "P", PuzzleId)`.
- **Player-driven changes are refused while a puzzle is locked.** A helper, `MayChange(Player, MechanismId)`, is true unless a puzzle containing it is locked (`Gate`). It is checked in `Prompted` (`:213`) before any action (toast the line), in `React` (`:144`) per mechanism (skip it, toast once), and in the Stand loop (`:339-351`; skip). **Timed reverts are never blocked** (`:355-359`).
- **The first-touch warning:** `Prompted` and `React` call `WrongGuessService.WarnOnce(Player, "P", PuzzleId, P)` for an armed puzzle.
- **Not changed:** `Strike` (Breakables), `OnMinigamePassed` (a bench's minigame has its own key, `M:`), `ShareWithParty`.

**Tests** (added; an injected puzzle `wg_sluices` with three injected Valve mechanisms `wg_v1..3` (Toggle `{"Open", "Shut"}`, defaults Open / Shut / Open), `Solved` = Shut / Open / Shut, `Wrong` = all three Open, and `Consequence = {Kind = "Lockout", Lock = 60, Warn = "W", Text = "T"}`, `Strikes = 1`, under a `StoryAct = 2` quest with a `Puzzle` objective). No instances are needed: the tests call `PuzzleService.SetState` and the exposed `MayChange`.
- **`WrongStateFiresOnce`:** set `wg_v2` Open (all three open) → one miss, fired, locked; the mechanisms are back to their defaults.
- **`LockedRefusesChanges`:**
  - **the control first:** before any lock, `MayChange(Player, "wg_v1")` is true;
  - after the fire it is false; after `Clock(61)`, it is true.
- **`EdgeNotLevel`:** with `Strikes = 3`, the all-open state counts once however many times the state is re-sent; leaving it and coming back counts again.
- **`SolveClears`:** one miss (Strikes 3), then the solved state → no flag.
- **`TimedRevertStillWorks`:** a timed state (`For = 0.5`) on a mechanism of a locked puzzle reverts on time.

**Steps:**
- [ ] **Step 1: RED** (`Ye:wg6`).
- [ ] **Step 2: Implement.** Sync `RenseiServer.PuzzleService` to both places.
- [ ] **Step 3: GREEN** in Ye: `Play_WrongGuess`; regressions `Play_LindenmoorSmoke` (the Adit route), and `Play_AditBoards` if Ye has it.
- [ ] **Step 4:** `--check` both places.
- [ ] **Step 5: Commit** `PuzzleService.lua` and the suite: `"Wrong-guess Task 6: puzzles: Wrong states, timed locks, first-touch warning"`.

---

### Task 7: The client lines (existing UI only)

**Files:**
- **Modify:** `UI/MinigameUI.lua`, `UI/JournalUI.lua`.
- **Create:** `Art/Studio/WrongGuess/client_checks.lua`.

**Interfaces:**
- **`MinigameUI`:**
  - **`Open(Id, Params)`:** `Warn = Params.Stakes and Params.Stakes.Line`;
  - a local `SetResult(T, Color)` that, when `T` is empty and `Warn` is set, shows `Warn` in the dim colour `Color3.fromRGB(165, 160, 150)` (JournalUI's `DIM_TEXT`);
  - the builders' `Ctx.Result` and the open path both go through `SetResult`;
  - on `"Result"` with a fifth argument, `Warn` becomes that `Info.Line`;
  - no new instances: it is the existing `ResultLabel`.
- **`JournalUI`** (the Case Board, under Submit, `:656-668`):
  - **armed** (`WrongGuess.Armed("D", Id, Def, D, QuestDefs)` > 0, with `D` being the client's data): one `Kit:Paragraph(Line)` in `DIM_TEXT`;
  - **locked** (`LockedFor > 0`): `Kit:Paragraph("Come back to it in n min.")` in `RED_TEXT`, `Submit.ImageTransparency = 0.5`, and Submit sets `Case.Hint` to the same line without sending a request;
  - **after a `CaseResult` with `Fired`:** the toast shows its text (unchanged path, `:944-948`).
  - **Unarmed cases draw exactly as today.**
- **`client_checks.lua`** (run in the Client data model during Play, or as a TEMP LocalScript): returns JSON describing the real UI. The server side of the session injects the defs as in the earlier tests.
  - **The panel:** after the server opens injected `wg_board` (armed), a TextLabel in the `Minigame` menu's canvas has exactly the text of the server's `Info.Line` (the server side passes that string to the check). **Control:** after opening injected `wg_board_off` (unarmed), no label there has that text.
  - **After one wrong submit:** a label there contains "(2 tries left)".
  - **The Case Board:** with the Journal open on injected `wg_case` (armed), a paragraph with the `Warn` text exists. After the server locks it, the "Come back to it" paragraph exists and Submit's `ImageTransparency` is 0.5. **Control:** on an unarmed case, neither paragraph exists.
  - **No new GUI objects:** the count of `ImageLabel` / `ImageButton` descendants of the player's GUI with a non-empty `Image` that isn't already in a list taken before the defs were injected is 0.

**Steps:**
- [ ] **Step 1: RED:** run `client_checks.lua` against today's UI in Play in Ye (`Ye:wg7`). The armed checks FAIL; the controls pass.
- [ ] **Step 2: Implement.** Sync `UI.MinigameUI` and `UI.JournalUI` to both places.
- [ ] **Step 3: GREEN** (`Ye:wg7`): `client_checks.lua` all PASS. Take one `screen_capture` of the panel line and one of the Case Board, as evidence for the controller (not committed).
- [ ] **Step 4:** `--check` both places.
- [ ] **Step 5: Commit** both UI scripts and `client_checks.lua`: `"Wrong-guess Task 7: the warning and tries-left lines in the existing panel and Case Board"`.

---

### Task 8: Day-one data

**Files:**
- **Modify:** `Rensei/Quests.lua`, `Rensei/Investigation.lua`, `Test_WrongGuess.lua` and `Play_WrongGuess.lua`.
- **Only if Task 1 found stealth-plan content:** `Rensei/Minigames.lua` and/or `Rensei/Puzzles.lua`.

**Interfaces** (PROPOSAL wording and numbers):
- `foundry_ledger` (`Quests.lua:94`) gains `StoryAct = 2, -- PROPOSAL: Foundry Yard is Act II in the story draft (wrong-guess plan)`.
- `foundry_ledger_who` (`Investigation.lua:309`) gains:
  ```lua
  Consequence = {Kind = "Lockout", -- PROPOSAL (wrong-guess plan): 3 strikes and 60 s from Stakes 1
  	Warn = "Three wrong boards and the pieces start to blur together.",
  	Text = "You've turned it over too many times. Step away and come back to it."},
  ```
- **The stealth plan's content** (only what Task 1 listed): each lock or cipher on a mission quest gets `Consequence = {Kind = "Alarm", Crime = true, Warn = ..., Text = ...}`, with wording written to its fiction (PROPOSAL). Its stakes come from that quest's own `Stakes`. If that plan set none, the content stays unarmed and the report says so. **This task doesn't invent stakes for another plan's quests.**
- **Nothing else** in today's data gets a `Consequence` (spec §8 lists the suggestions for the owner).

**Tests:**
- **`Test_WrongGuess.RealDataValid`:** `Validate(require(Minigames), require(Puzzles), require(Investigation), require(Quests))` returns no problems. **Control:** the same call with a copy of `foundry_ledger_who` whose `Warn` is removed returns exactly one problem.
- **`Test_WrongGuess.OnlyTheLedgerIsArmedToday`:** the set of `(Kind, Id)` with a `Consequence` whose quest's `StakesOf` ≥ 1 equals, written by hand, `{"D:foundry_ledger_who"}` plus Task 1's stealth list.
- **`Play_WrongGuess.FoundryLedgerArmed`** (Play in Foundry):
  - put `foundry_ledger` Active at stage 3 with its five pieces of evidence (as `Play_FoundryLedger` does);
  - three wrong boards → locked;
  - the right board is refused;
  - after `Clock(61)` the right board completes the quest, with `Rewards = {}` swapped in for the run and put back.

**Steps:**
- [ ] **Step 1: RED:** the three new tests FAIL (no `StoryAct`, no `Consequence`) in Play in Foundry (`Foundry:wg8`, `Play_Boot` first).
- [ ] **Step 2: Implement.** Sync `Rensei.Quests`, `Rensei.Investigation` (and any stealth-content data) to both places.
- [ ] **Step 3: GREEN** in Foundry: `Test_WrongGuess`, `Play_WrongGuess`, **`Play_FoundryLedger` unchanged and 0 FAIL** (its single wrong board is strike 1 of 3).
- [ ] **Step 4: Play in Ye** (`Ye:wg8`): `Test_WrongGuess`, `Play_WrongGuess` (minus the Foundry-only test, which skips itself when `Map.Foundry` is absent), `Play_LindenmoorData`, `Play_Clue`.
- [ ] **Step 5:** `--check` both places.
- [ ] **Step 6: Commit** the data and the tests: `"Wrong-guess Task 8: arm the Foundry ledger deduction (Act II): 3 boards, 60 s"`.

---

### Task 9: Foundry parity and the full sweep

**Files:** none new. This task fixes only what it finds, in the task that owns it (the controller rules).

**Steps:**
- [ ] **Step 1:** `sync.py --place ye --check` and `--place foundry --check`: `DIFFER 0 / MISSING 0` for both, for every pair, the earlier plans' included.
- [ ] **Step 2: Play in Ye** (`Ye:wg9`), in this order:
  - `Test_WrongGuess`, `Play_WrongGuess`;
  - the regressions: `Play_Exams`, `Play_Clue`, `Play_LindenmoorSmoke`, `Play_LindenmoorData`, `Play_Morality`, `Play_Heat`, `Play_Rumours`, `Play_Stealth`, `Play_QuestEngine`, `Play_AditBoards` (if present), and the gun, swim, assassination and stealth plans' Play suites;
  - then `client_checks.lua`.

  Record every result and the probe.
- [ ] **Step 3: Play in Foundry** (`Foundry:wg9`, with Ye in Edit):
  - `Play_Boot` first;
  - then `Test_WrongGuess`, `Play_WrongGuess`, `Play_FoundryLedger`, `Play_FoundryForge`;
  - the Foundry plan's final smoke suite by its name;
  - then `client_checks.lua`.
- [ ] **Step 4: A real walk-through in Foundry** (Play, the protocol), with real input only (`user_keyboard_input` / `user_mouse_input`):
  - with `foundry_ledger` at its last stage in the **hooked** save, open the Journal (J) and the Case Board;
  - read the warning;
  - pin a wrong board three times;
  - see the lock line and the dimmed Submit.

  Report what happened, with one capture. The hook's restore puts the save back.
- [ ] **Step 5: The checkpoint list for Task 10.** Write the package contents:
  - **`Modules`:** `Rensei.WrongGuess`, `Rensei.StoryLogic`, `Rensei.Deeds`, `Rensei.Quests`, `Rensei.Investigation` (plus any stealth data), `UI.MinigameUI`, `UI.JournalUI`;
  - **`RenseiServer`:** `WrongGuessService`, `MinigameService`, `PuzzleService`, `InvestigationService`, `Requests.Investigation`;
  - **place changes in both:** the RenseiTests suites.
- [ ] **Step 6:** No commit unless something was fixed. Any fix is committed with its owning task's files, with the message `"Wrong-guess Task 9: <what>"`.

---

### Task 10: Docs, the Changelog entry and the held Discord post

**Files:** modify `Documents/Changelog.md`, `Documents/Backlog.md`, `Scripts/README.md`, and `Documents/Quests, Puzzles and Minigames Proposal.md` (a one-line pointer).

**Interfaces.** The content each document must hold. Facts and counts come from Tasks 1–9's reports.

**`Backlog.md`:**
- Item 3 of "After the swimming revamp" is ticked, with a pointer to the Changelog entry and "**armed on day one: the Foundry ledger deduction only**".
- **Follow-ups:**
  - the owner picks which spec §8 suggestions to arm as the story places content in acts;
  - wrong-press dialogue choices and ClamUp on townsfolk (with "Reputation shapes investigations");
  - a Candor deed for accusing an innocent;
  - reagent items for Waste;
  - review the spec's §13 decisions.

**`Quests, Puzzles and Minigames Proposal.md`:** under design goal 3 (`:31`), one line: "Exception (2026-10-25): quests with stakes can carry told-first consequences; see `specs/2026-10-25-wrong-guess-consequences-design.md`."

**`Scripts/README.md`:** rows for `Rensei/WrongGuess` and `WrongGuessService`, with the date.

**`Changelog.md`:** one entry, `## <date> — Wrong-guess consequences on quests with stakes (not live)`. It holds:
- what existed and what was missing (the spec's §1.1 table and §1.9 findings, one line each);
- what changed: strikes, the six consequence types, stakes, the warnings, locks, throttle, day-one arming;
- the rules kept: never a dead end, told first, off in Chapter 1, existing UI only;
- **"Decisions taken without the owner"** (the spec's §13 list, short);
- every test count from Tasks 2–9;
- "Not tested": a phone, and two party members failing the same puzzle at once;
- the backups `RenseiBackups["Pre-WrongGuess_2026-10-25"]` in both places;
- **the rollback order** (Edit):
  1. set `WrongGuess.Enabled = false` (one line; everything behaves as before);
  2. or revert the scripts from that backup in both places, for this plan's labels;
  3. delete the scripts this plan created (`Rensei.WrongGuess`, `WrongGuessService`, `Test_WrongGuess`, `Play_WrongGuess`) in both places;
- **the publish checkpoint** (Task 9, step 5), in the World Travel.md §10 order:
  1. packages from Ye;
  2. Foundry's packages updated by hand and checked with `sync.py --check`;
  3. the places;
  4. Migrate to Latest Update last.

  It may be published only together with whatever hold is then in force.

**Its `### Discord announcement`:**
- It starts "Hold: not live yet. Post this when the owner publishes the wrong-guess update."
- Then a ```md block, under 2,000 characters, plain and player-facing, with no file names, test numbers or PROPOSAL tags. It covers:
  - from the Foundry Yard on, some puzzles and deductions have stakes: guess wrong too often and something happens;
  - you're always told before you try, and you can see how many tries you have left;
  - what can happen: a lock jams for a while, a noise brings guards to look, a reaction singes you, reagents cost you coin, a witness won't talk for a bit, or the person you're after hears you're asking;
  - nothing ever locks you out of a quest for good: every setback wears off or has another way round;
  - the starting village and the early sites are unchanged, so new players can learn without pressure;
  - in a party, everyone has their own tries;
  - first up: the Shift Ledger case board in the Foundry Yard.

**Steps:**
- [ ] **Step 1:** Write the docs. Every number comes from a task report or `Rensei.WrongGuess` as committed.
- [ ] **Step 2:** Check that the Discord block is under 2,000 characters (count it with `python -I -c`), and that it has no file names, test counts or PROPOSAL.
- [ ] **Step 3:** This is the plan's only Changelog entry.
- [ ] **Step 4:** The controller names the checkpoint to the owner in chat. This plan publishes nothing.
- [ ] **Step 5: Commit** the four docs: `"Wrong-guess Task 10: docs, changelog (held Discord post)"`.

---

## Self-review notes

**Coverage of the request:**
1. **"Consequences for wrong guesses in minigames and puzzles on quests":**
   - minigames (Task 4), environmental puzzles (Task 6), Case Board deductions (Task 5);
   - "on quests": armed only while the owning quest is Active (Task 2).
2. **Consequence types matched to fiction and severity:** the six effects (Task 3), scaled by stakes (Task 2):
   - a suspect clamming up → ClamUp; tipping off the culprit → TipOff;
   - a failed lock tripping an alarm → Alarm (noise, optional crime → Heat);
   - a failed alchemy minigame → Backfire or Waste;
   - a wrong vault code adding a delay → a 1-strike short Lockout;
   - strikes before a lockout → `Strikes` and Lockout.
3. **The rules:** never a dead end (the validator, the Backfire floor, Waste's fallback, timed locks); told first (Task 7, and the validator requires `Warn`); scaled (Task 2); off early (stakes 0; tests in Tasks 4 and 5 prove Chapter 1 is unchanged); the same rules for parties (per-player flags, Task 3).
4. **Ties:** Heat and rumours only through the `tripped_alarm` crime (Task 3); Morality (no conduct for a guess); reputation (`StrikesFor` mods, ClamUp; the hand-off in Backlog); stealth missions (Alarm, `Listen`, Task 8's conditional arming).
5. **Data shape:** `Consequence` and `Strikes` per minigame, puzzle and deduction; puzzles' `Wrong` (Task 2's interface, Task 8's data).
6. **Server validation and tests:** server-only strikes and locks, the throttle, no new remote (Tasks 3–6); RED with controls in every task.

**Rules kept:**
- existing UI assets only (Task 7 draws in existing labels and checks that no new image appears);
- no publishing;
- one Changelog entry with a held, player-facing post;
- the Play protocol with the save hook, `dumphelper` and the probe; one Play session at a time;
- `sync.py --check` clean in both places after every script task;
- PROPOSAL labels;
- commit by path with the trailer.

**Order and dependencies:**
- 1 before everything;
- 2 before 3 (the service uses the rules);
- 3 before 4, 5 and 6;
- 4, 5 and 6 are independent of each other, and serial only because Play is;
- 7 after 4 and 5 (the `Info` payloads);
- 8 after 5 (deductions) and 7 (the line shows);
- 9 after 1–8; 10 last.

**Each task can be rejected on its own:**
- Tasks 1–3 change nothing a player can see: parity and a survey; an unused module and two unused conditions; an unused service and a deed nothing records yet.
- Tasks 4–6 each wire one system. No shipped content is armed until Task 8, so each is invisible on its own. Reverting one leaves the others working.
- Task 7 is client-only, and draws nothing for unarmed content.
- Task 8 is two data lines. Removing them turns the feature off for players, with everything else in place.
- `WrongGuess.Enabled = false` turns the whole feature off in one line.

**Names used across tasks:**
- the backup `Pre-WrongGuess_2026-10-25`, the PlayLock label `wg<task>`;
- the flags `Guess_<M|P|D>_<id>` (`"<used>:<until>"`), `Clam_<Npc>`, `TipOff_<quest>`;
- the keys `M:`, `P:`, `D:`;
- `Rensei.WrongGuess` (`Key`, `FlagName`, `Read`, `Write`, `StakesOf`, `QuestOf`, `Armed`, `StrikesFor`, `LockFor`, `Step`, `LockedFor`, `Line`, `Clammed`, `Validate`, `Enabled`);
- `WrongGuessService` (`SetClock`, `Gate`, `Info`, `Miss`, `Clear`, `WarnOnce`, `Listen`);
- the quest fields `StoryAct` and `Stakes`; the def fields `Consequence` and `Strikes`, and puzzles' `Wrong`;
- the StoryLogic conditions `Clammed` and `NotClammed`;
- the deed `tripped_alarm`;
- `RenseiTests.Test_WrongGuess`, `Play_WrongGuess`; `Art/Studio/WrongGuess/survey_wrongguess.lua`, `client_checks.lua`.

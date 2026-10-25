# Assassinations Implementation Plan

> **Owner update (2026-10-25), overrides the empty-slot text below:** the owner supplied the takedown ids. Use them:
> - `Takedown_Choke` = 72960497872371 ("Knock out")
> - `Takedown_ChokeVictim` = 131914091661838 ("Hold")
> - `Misc_AssassinateVictim` = 132728216355683 ("Victim")
> - `Misc_Assassinate` = 83505608395055
>
> Task 3 creates the three slots with these ids, not empty. Task 1 checks that each one loads in Studio, and any id that fails keeps its fallback. The Bear Hug is now only a fallback. Task 3's undo refusal applies to these owner-given ids too. Nothing is left for the owner to upload for this plan.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Every implementer gets the **Global Constraints** and the **Facts** below together with its own task.

**Goal:** the owner's Backlog item, "Assassinations that work with the detection system (sight, light, sound)", **PvE only**. When this plan is done:
- behind an enemy that hasn't caught you, a prompt in the game's own art offers **N: tap to knock out, hold to assassinate**;
- the server checks every gate (rear arc, range, clear line, the enemy's phase, Calm, cooldown) and **never accepts a player as the target**;
- a knockout uses the existing knocked state for 300 s, then the enemy wakes and raises the alarm;
- an assassination kills quietly, credits once, records `assassinated_bandit`, and leaves a body for 120 s;
- enemies find bodies by sight (light counts) and search there;
- NPCs who see a takedown react (enemies go Alert, townsfolk remember), and the deed, Heat and rumour follow the existing deeds system;
- Elites take a 45% backstab; bosses and trial foes are immune; townsfolk are refused;
- four animation slots (one from the owner's sheet, three empty) with fallbacks.

Both places get the same code. Nothing is published.

**Spec:** `Documents/specs/2026-10-25-assassinations-design.md`. Its §2 is the audit (findings A1–A15, with file:line evidence), §16 lists the decisions taken without the owner, and §17 lists the Studio checks that Task 1 answers. Every number in it, and here, is **PROPOSAL** unless it quotes an owner decision.

**When to start:**
- **After the gun rework** (`Documents/plans/2026-10-25-gun-rework.md`) **and the swimming revamp** (`Documents/plans/2026-10-25-swimming-revamp.md`) have both finished (Backlog order: "After the swimming revamp", item 1).
- `sync.py`'s `--backup` option comes from whichever of those two plans ran first. This plan only adds pairs.
- `Documents/CLAUDE.md` asks for approval before scripts are rewritten. The owner's overnight go-ahead (Backlog, 2026-10-25) covers planning. **The controller confirms the owner has seen the spec before Task 7**, the first behaviour change. Tasks 1–6 change nothing a player can see (§ "Each task can be rejected on its own").

**Architecture:** five stages.
1. **Parity and survey** (Task 1): every script this plan touches is a manifest pair, equal to Studio in both places; a read-only survey answers the spec's §17 and picks the test spots.
2. **Pure rules and data** (Tasks 2, 3 and 6): `Rensei.Takedown` (numbers, slot names, the gate maths), the animation slots (a reversible Studio script), the deed, and an optional knock length in `DownedManager.Knock`.
3. **Perception** (Tasks 4–5): a rig being taken down stops perceiving; `Glimpse` (who sees a takedown), `Raise` (a search at a spot), bodies and `BodyFound`; takedown bodies stay 120 s.
4. **The server takedown** (Tasks 7–9): `TakedownService` and the `Takedown` request: assassinate, knock out, wake-up alarm, Elites, bosses, townsfolk, hooks.
5. **The client and the close** (Tasks 10–12): the prompt (`TakedownUI`), the E-key prompt fix, N reserved; Foundry parity and the full sweep; the docs and the one Changelog entry.

**Tech Stack:**
- Roblox Studio Luau, through `Art/Tools/rbxc.py`.
- Python 3.14 (stdlib only), only for `sync.py --check` and `test_sync.py` (unchanged by this plan).

---

## Facts (read from the repo, 2026-10-25; Task 1 confirms them in Studio)

**Places and windows:**
- **Ye:** placeId 106992859583940, window "[CLOSED TESTING] Rensei".
- **Foundry:** placeId 109591196441030, window "Foundry Yard".
- Get each window's `studio_id` from `python -I Art/Tools/rbxc.py studios`.
- Never touch the window "bloodydeadpool53's Place".

**The owner's sheets (read-only through Drive, 2026-10-25):**
- "Animation ID's" (general), Misc. column, row 29: **"Assassination: 83505608395055 / Victim:"**. The victim id is **empty**.
- "Skill ID's", Fist: **Bear Hug 140607038476506 / Victim 76737043223431** (the stand-in choke).
- No other assassination, takedown, choke or knockout row on any of the three sheets.
- `Documents/Animations.md:84`: `Misc_Assassinate` is 📦 (in `Animations.Registry`: loads, not preloaded, not played).

**The scripts this plan touches.** Repo path first, then the expected Studio path; Task 1 confirms each. "Pair" = already in `sync_manifest.json` (from the Foundry, gun or swim plans); Task 1 adds the rest.

| Label | Repo | Studio | Task |
|---|---|---|---|
| `Rensei.Takedown` | `Scripts/ReplicatedStorage/Modules/Data/Rensei/Takedown.lua` | `ReplicatedStorage/Modules/Data/Rensei/Takedown` | new (2) |
| `Rensei.Perception` | `.../Data/Rensei/Perception.lua` | `ReplicatedStorage/Modules/Data/Rensei/Perception` | 4 (swim pair) |
| `Rensei.Deeds` | `.../Data/Rensei/Deeds.lua` | `ReplicatedStorage/Modules/Data/Rensei/Deeds` | 6 (pair) |
| `Rensei.Settings` | `.../Data/Rensei/Settings.lua` | `ReplicatedStorage/Modules/Data/Rensei/Settings` | 10 |
| `Managers.DownedManager` | `Scripts/ReplicatedStorage/Modules/Managers/DownedManager.lua` | `ReplicatedStorage/Modules/Managers/DownedManager` | 6 |
| `UI.TakedownUI` | `Scripts/ReplicatedStorage/Modules/UI/TakedownUI.lua` | `ReplicatedStorage/Modules/UI/TakedownUI` | new (10) |
| `UI.CombatModeUI` | `.../UI/CombatModeUI.lua` | `ReplicatedStorage/Modules/UI/CombatModeUI` | 10 |
| `UI.PromptUI` | `.../UI/PromptUI.lua` | `ReplicatedStorage/Modules/UI/PromptUI` | read-only pair (1) |
| `SPScripts.UIHandler` | `Scripts/StarterPlayer/StarterPlayerScripts/UIHandler.client.lua` | `StarterPlayer/StarterPlayerScripts/UIHandler` (LocalScript) | 10 |
| `RenseiServer.PerceptionService` | `Scripts/ServerScriptService/PerceptionService.lua` | `ServerStorage/RenseiServer/PerceptionService` | 4, 5 (swim pair) |
| `RenseiServer.EnemyService` | `Scripts/ServerScriptService/EnemyService.lua` | `ServerStorage/RenseiServer/EnemyService` | 5, 7 (pair) |
| `RenseiServer.TakedownService` | `Scripts/ServerScriptService/TakedownService.lua` | `ServerStorage/RenseiServer/TakedownService` | new (7) |
| `Requests.Takedown` | `Scripts/ServerScriptService/ServerHandler/Requests/Takedown.lua` | `ServerStorage/RenseiServer/ServerHandler/Requests/Takedown` | new (7) |
| `RenseiServer.ServerHandler` | `Scripts/ServerScriptService/ServerHandler.server.lua` | `ServerStorage/RenseiServer/ServerHandler` | 7 (pair) |
| `RenseiTests.Test_Takedown`, `Play_Takedown`, `TakedownKit` | `Scripts/ServerStorage/RenseiTests/<X>.lua` | `ServerStorage/RenseiTests/<X>` | new (2, 4) |
| `RenseiTests.Test_Perception`, `Test_Sound`, `Play_Stealth` | `Scripts/ServerStorage/RenseiTests/<X>.lua` | `ServerStorage/RenseiTests/<X>` | 4 (swim pairs) |

**Read-only, not changed:** `WorldService` (`Credit`, `WorldService.lua:83-112`), `MoralityService` (`Record`, `:94-159`), `WitnessService`, `HeatService`, `RumourService`, `NoiseService`, `LightService` (`ExposureOf` works on any rig, `LightService.lua:104-111`), `AnimationManager`, `AttackRunner` (`CrouchStuns`), `CharacterHandler`, `ProgressionService`, `TownsfolkService`, `CombatDirector`.

**What the code does today** (the spec's §2 has the line numbers):
- the phase is the rig attribute `Awareness`; per-player awareness is server-only; no client shows either;
- a killed enemy's body is deleted after 4 s, and nothing notices bodies;
- the Grip finisher makes a 20-stud "Hit" sound through `RecordHit`;
- `Call` needs a player;
- crouch runs a real Stun status and works only out of Combat Mode;
- PromptUI ignores taps in Combat Mode;
- any shown prompt stops E from drawing.

**Animations:**
- `AnimationManager` keys animations by **name across all of `Assets.Animations`**, preloads `Shared` and `Weapons` on the client, and resolves `Registry` only on the server. A missing client name with a `Fallback` plays the fallback; with none it warns "Animation not found".
- An `Animation` with `AnimationId = ""` and no `Save` child is unplayable, so the caller's fallback plays.
- `Assets` is a package in both places (the swim plan's Facts).

---

## Global Constraints

**Owner rules:**
- "Do not publish the Roblox game or modify live player data."
- "Do not expose API keys, credentials, private player data, or other secrets."
- "Do not blindly copy another game's code or assets."
- **PvE only (owner):** players can never be assassinated or knocked out by a takedown. The server's first check refuses a player's character, whatever else is true.
- **UI:** use only the game's existing UI assets. The prompt is a `ProximityPrompt` with `Style = Custom`, drawn by the existing PromptUI. No new images, fonts, sounds or ScreenGuis, and no `StarterGui` edits.
- **Never invent an asset id.** The three new slots stay empty until the owner pastes the id of an animation they uploaded. The only id this plan writes is the sheet's 83505608395055, which is already in the game.

**Labels and records:**
- Label every invented number and name **PROPOSAL** in code comments and docs.
- No task writes a Changelog entry except Task 12, which writes one entry for the whole plan.
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
- Never touch the Studio window "bloodydeadpool53's Place".
- Put scratch files in `C:/Users/Owner/AppData/Local/Temp/claude/C--Users-Owner/ecd4cd55-01de-4070-9638-cb228809b769/scratchpad/assassination-plan/`.

**Play** is hooked and protected, because Play writes the owner's REAL save.

- **One Play session at a time across Ye and Foundry.** Before Play:
  - `get_studio_state` must show the **other** place in Edit;
  - Ye's `game.ServerStorage:GetAttribute("PlayLock")` must be nil.
- **The order, every session:**
  1. **Lock.** In Ye (Edit), `game.ServerStorage:SetAttribute("PlayLock", "<Ye|Foundry>:assn<task>")`. When playing Foundry, set the same attribute in Foundry too.
  2. **Hook.** In the playing place (Edit), run `C:/Users/Owner/.claude/jobs/0c39df78/tmp/blender/hook.lua`. Then install the dump helper: `rbxc.py luau "placeId: <id>" Edit @Art/Studio/Regions/Foundry/data/dumphelper.lua`. It returns "dump helper installed".
  3. **Start Play.** In the Server data model, wait until `game.ServerStorage:GetAttribute("LMSnapTaken")` is set. Then:
     - take the dump: `return game.ServerStorage:WaitForChild("LMQuestDump", 30):Invoke()`. Save it to the scratch folder as `quests_assn<task>_1.txt`;
     - **and the deed probe** (Server): the player's `Data.Morality.Deeds.assassinated_bandit`, `Data.Exp` (or the level / EXP fields `ProgressionService.GetData` holds) and `Data.Money`, written as one line to `deeds_assn<task>_1.txt`. Takedown tests credit kills and record deeds into the real save.
  4. **Suites.** Run them with `game.ServerStorage.LMRunSuite:Invoke("<Suite>")` (Server).
  5. **Put the character back.** Every test that moves the real character restores its CFrame, `Anchored`, `CombatMode`, `Crouching`, `TakingDown`, `TakedownReadyAt` and `LastTakedownResult` before it returns (`TakedownKit.Clean`).
  6. **Restore.** Run `game.ServerStorage.LMTestHook:Invoke("restore")` (Server). It must return "restored".
     - Dump again (`quests_assn<task>_2.txt`). It must equal the first dump character for character.
     - Probe again (`deeds_assn<task>_2.txt`). It must equal the first probe.
     - `LMTestHook:Invoke("diff")` may list only the known encode-quirk keys (Settings, Story, Morality). **Any other key**, or a dump or probe that differs, means stop: keep Play running and report both dumps, both probes and the diff to the controller.
  7. **Stop** Play.
  8. **Unhook.** In Edit, run `C:/Users/Owner/.claude/jobs/0c39df78/tmp/blender/unhook.lua`. Then remove the helper: copy `dumphelper.lua` to the scratch folder, set its MODE line to `"remove"` there (only that line), and run the copy in Edit. It returns "removed <n>".
  9. **Unlock.** Only then, clear PlayLock in both places.
- **Test enemies:** every server test takes down **enemies it spawned itself** through `TakedownKit.Spawn` (an unparented spawn mark, so they never respawn; `AIPassive` so they never attack; `Credited = true` unless the test checks credit). It never takes down a world enemy, a townsperson's real rig or the player.
- **Script edits are refused while Play runs.**
- **In Play, the world is a copy.** Instance changes made in Play (test rigs, walls, a stand-in animation id) vanish at Stop. Save data is real: the hook's restore puts it back.
- **Edit's require cache.** Edit keeps a module's result between `execute_luau` calls. Every suite here runs **in the Play VM** (`LMRunSuite`), because each requires a module this plan changes. Edit runs are only for Task 1's survey and Task 3's slots, which require no changed module.

**Scripts live in both places.**
- Every script is edited in the repo first, then set into **both** places with the sync tool:
  ```
  python -I Art/Studio/Regions/Foundry/data/sync.py --place ye|foundry --backup Pre-Assassinations_2026-10-25 --only <label>[,<label>...] --run
  python -I Art/Studio/Regions/Foundry/data/sync.py --place ye|foundry --check
  ```
- **Start every task that touches a script with `--check` in both places.** If anything differs, stop and report: another plan's work may not be synced yet, and syncing over it would lose it.
- `--check` must print `DIFFER 0 / MISSING 0` for **both** places at the end of every task that touched a script.
- Each task adds its own pairs to `Art/Studio/Regions/Foundry/data/sync_manifest.json` (the Foundry plan's Task 1 format), with `Places: ["ye", "foundry"]`.
- **Backups:** with `--backup Pre-Assassinations_2026-10-25`, the tool clones a script once, before its first change in this plan, into `ServerStorage.RenseiBackups["Pre-Assassinations_2026-10-25"]` in that place. **Never sync this plan's scripts without `--backup`:** the default folder (`Pre-FoundryData_2026-10-24`) and the gun and swim folders already hold older copies of some of them, so an undo from those would drop later work. A created script gets no backup and carries `FoundryDataAdd = true` (the tool's existing mark).
- **The normalised hash** (Studio == repo means these strings are equal) is the one in `sync.py` (`norm_hash`) and in the Foundry plan's Global Constraints.
- **Packages:** `Modules`, `RenseiServer` and `Assets` are packages. Syncing changes both places' package copies. Publishing them is the owner's (Task 12's checkpoint).

**Reversible Studio scripts** (only the animation slots, Task 3) follow the Lindenmoor fix scripts' contract (`Art/Studio/Regions/Lindenmoor/shelters.lua` is the model):
- `local MODE = "plan"` on its own line near the top. The modes:
  - `plan`: read-only;
  - `apply`;
  - `undo`;
  - `check`: read-only;
  - `test`: allowed only while not applied. It snapshots, applies, checks, undoes and snapshots again; the two snapshots must be equal; it leaves the place as it was.
- **`apply`:**
  - refuses, changing nothing, when its flag attribute is already set, while Play is running (`RunService:IsRunning()`), or while the place's `ServerStorage` attribute `PlayLock` is set. A Foundry run also checks that Ye's is nil;
  - runs inside a pcall with a journal, so an error mid-way is rolled back;
  - makes one ChangeHistoryService recording, and cancels it on a refusal;
  - marks every instance it creates with `TakedownAdd = true`, and every instance it moves with `TakedownFrom` (the old parent's full name).
- **`undo`:**
  - restores exactly those, and clears the flag;
  - refuses while Play runs or PlayLock is set.
- **`check`:**
  - lists failure conditions only, and returns `PASS n / FAIL n`;
  - compares against constants written in the script (names, the sheet id) or a baseline `apply` recorded, never against a value it reads at check time from the thing it checks.
- Each mode returns a one-paragraph summary.
- To run another MODE, copy the committed file to the scratch folder and edit only its MODE line there.

**Tests:**
- **RED then GREEN.** Every new check is run once where it **must fail** (before the change, or against a control that keeps today's rule), and fails. Then it passes after.
- **A check that cannot fail is not a check.** Never choose a test spot or input by reading the property under test. Test spots come from Task 1's survey files. Expected numbers are written by hand in the test, never read from `Rensei.Takedown` at check time.
- **No duplicated test logic.** Shared helpers live in `RenseiTests.TakedownKit` (Task 4), required, never copied. If the swim plan moved Play_Stealth's fixture helpers (`Find`, `Run`, `Put`, `Part`, `Guard`) into a shared kit, `TakedownKit` requires that kit. If it didn't, Task 4 moves them into `TakedownKit` and `Play_Stealth` requires them from there.
- When a check fails, fix the cause in the task that owns it (the controller rules), never by loosening the check.

**Publish order** (`Documents/World Travel.md` §10):
1. packages from Ye (Modules, RenseiServer, **Assets** for the slots);
2. Foundry's packages updated by hand and checked with `sync.py --check`;
3. the places;
4. Migrate to Latest Update last.

This plan never publishes.

**Git:**
- Commit by path only: `git commit -m "<msg>" -- <paths>`. New files need `git add -- <path>` first. Never `git add -A`.
- Never stage `.blend` or `.blend1` files or `Art/Blender.rar`.
- End every commit message with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Implementers don't push.

---

## Shared files with the gun rework and the swimming revamp

This plan runs **after** both. It changes no file only they change in a way that conflicts, but several files are shared. The rule for each: run `--check` first, edit the repo file (which already holds the earlier plans' changes), sync, `--check` again. Never sync an older copy.

| File | Gun rework | Swimming revamp | This plan | How they meet |
|---|---|---|---|---|
| `Rensei/Perception.lua` | — | Task 7: `SubmergedMult`, sounds `Surface` 6, `Stroke` 8, `StrokeEvery` | Task 4: sounds `Choke` 6, `Takedown` 4 | different keys in the same `Sounds` table |
| `PerceptionService.lua` | — | Task 7: `Rays.IgnoreWater`, the `Submerged` sight multiplier in `Update` | Tasks 4–5: one condition in `Update`'s early return, an Alert-branch line in `Decide`, new functions, bodies in `Step` | different lines. `Glimpse` reuses `Rays`, so a diver is judged the same way |
| `EnemyService.lua` | Task 10: enemy gunners (`Attack`, shots) | — | Task 5: corpse time; Task 7: `Busy()` | different functions |
| `ServerHandler.server.lua` | Task 5: `PositionHistory` start | — | Task 7: `TakedownService.Start()` line | one line each, at the end of the start list |
| `Test_Perception`, `Test_Sound`, `Play_Stealth` | — | Task 7 adds tests; may move Play_Stealth's helpers into `SwimKit` | Task 4 adds tests; reuses or moves the helpers | append only; one shared kit |
| `sync_manifest.json` | pairs | pairs | pairs | append only |
| Studio `Assets.Animations` (package) | Task 6: `Guns_Reload` | Task 4: four `Swim_*` slots | Task 3: `Shared.Takedown` | distinct names (Task 3 refuses a clash); one Assets publish |
| `Controls.md`, `Animations.md`, `Changelog.md`, `Backlog.md`, `COMBAT_SYSTEM.md` | Task 12 | Task 10 | Task 12 | new rows and sections only |

**Not touched by this plan,** so no overlap: `TuningConfig` (the numbers live in `Rensei.Takedown`), `MobileControls` (the prompt is the touch control), `ClientHandler` (UIHandler starts the UI), `SettingsUI` (only `Rensei.Settings` changes), `WeaponManager`, `SwimService`, `SwimClient`.

---

## Decisions taken without the owner, by task

The owner was asleep (overnight go-ahead, 2026-10-25). Each is a PROPOSAL, listed in the spec's §16, and built so the owner can change it by a number in `Rensei.Takedown` or by skipping a task.

| | Decision (PROPOSAL) | Task |
|---|---|---|
| 1 | Tap N: knock out; hold N 0.6 s: assassinate | 2, 10 |
| 2 | N is reserved, not rebindable yet | 10 |
| 3 | Gates: rear 140° arc, 4 studs (3 up or down), clear line, not Alert, from Calm only, crouch not required | 2, 7 |
| 4 | Suspicious and Cautious enemies can be taken down | 2, 7 |
| 5 | Knock out 2.0 s, assassinate 1.0 s, knocked out 300 s, cooldown 4 s (0.5 s after a refusal) | 2, 7, 8 |
| 6 | Sounds Choke 6, Takedown 4; the kill skips the 20-stud hit sound | 4, 7 |
| 7 | One quick look at the start: enemies that see it go Alert, townsfolk remember | 4, 7 |
| 8 | Dead bodies stay 120 s; enemies find bodies by sight with light; a found body starts a search there; townsfolk don't look; dead bodies can't be moved yet | 5 |
| 9 | Waking up raises the alarm as a search at that spot | 5, 8 |
| 10 | `assassinated_bandit` (Mercy −1, Local, cap 10 a day); knocking out a hostile mob is no deed | 6, 7 |
| 11 | Elites: 45% backstab and a 1.2 s stun, no knockout. Bosses and trial foes: immune | 2, 9 |
| 12 | Townsfolk can't be taken down | 2, 9 |
| 13 | The victim takes no damage during a takedown; the player can | 7 |
| 14 | The Bear Hug pair stands in for the choke | 3 |
| 15 | The prompt shows the enemy's state word | 10 |
| 16 | No drop takedowns in this version | — |
| 17 | Only E prompts stop E from drawing | 10 |

---

## File map

| File | Responsibility | Task |
|---|---|---|
| `Art/Studio/Regions/Foundry/data/sync_manifest.json` | This plan's pairs | 1 (pairs added in every task) |
| `Art/Studio/Takedown/survey_takedown.lua` (new), `survey_ye.json`, `survey_foundry.json` (new, written from its output) | Read-only survey: the spec's §17 and the test spots | 1 |
| `Rensei/Takedown.lua` (new), `RenseiTests/Test_Takedown.lua` (new) | Numbers, slot names, the pure rules | 2 |
| `Art/Studio/Takedown/anim_slots.lua` (new) | Reversible: `Shared.Takedown` and the four slots | 3 |
| `Rensei/Perception.lua`, `PerceptionService.lua`, `RenseiTests/TakedownKit.lua` (new), `Play_Takedown.lua` (new), `Test_Sound.lua`, `Play_Stealth.lua` | Sounds; skip during a takedown; `Glimpse`; `Raise`; searching NPCs take a new focus | 4 |
| `PerceptionService.lua`, `EnemyService.lua`, `Play_Takedown.lua` | Bodies, `BodyFound`, takedown bodies stay 120 s | 5 |
| `Managers/DownedManager.lua`, `Rensei/Deeds.lua`, `Test_Takedown.lua` | `Knock(Victim, Seconds)`; the deed | 6 |
| `ServerScriptService/TakedownService.lua` (new), `Requests/Takedown.lua` (new), `ServerHandler.server.lua`, `EnemyService.lua`, `Play_Takedown.lua` | Gates, assassinate, witnesses, cooldown, interrupt | 7 |
| `TakedownService.lua`, `Play_Takedown.lua` | Knock out and waking up | 8 |
| `TakedownService.lua`, `Play_Takedown.lua` | Elites, bosses, townsfolk, hooks | 9 |
| `UI/TakedownUI.lua` (new), `UIHandler.client.lua`, `UI/CombatModeUI.lua`, `Rensei/Settings.lua`, `Art/Studio/Takedown/client_checks.lua` (new) | The prompt, the E fix, N reserved | 10 |
| (no new files) | Foundry parity and the full sweep | 11 |
| `Documents/Changelog.md`, `Controls.md`, `Animations.md`, `COMBAT_SYSTEM.md`, `Backlog.md`, `Scripts/README.md` | Docs | 12 |

All `Rensei/` paths are `Scripts/ReplicatedStorage/Modules/Data/Rensei/`. `Managers/` and `UI/` are under `Scripts/ReplicatedStorage/Modules/`. `RenseiTests/` is `Scripts/ServerStorage/RenseiTests/`. `Requests/` is `Scripts/ServerScriptService/ServerHandler/Requests/`.

---

### Task 1: Parity and the read-only survey

**Files:**
- **Modify:** `sync_manifest.json`.
- **Create:** `Art/Studio/Takedown/survey_takedown.lua`, `survey_ye.json`, `survey_foundry.json`.
- **No Studio change. No game behaviour change.**

**Interfaces:**
- **Manifest pairs added** (each only if it isn't a pair yet), all with `Places: ["ye", "foundry"]` and `Create: false`:
  - `Rensei.Perception`, `Rensei.Settings`;
  - `Managers.DownedManager`;
  - `UI.CombatModeUI`, `UI.PromptUI` (read-only here; paired so the sweep covers it);
  - `SPScripts.UIHandler` (LocalScript);
  - `RenseiServer.PerceptionService`;
  - `RenseiTests.Test_Perception`, `Test_Sound`, `Play_Stealth`, `Play_Perception`, `Play_Morality`, `Play_Heat`, `Play_TownsfolkHurt` (the regression suites; paired so the sweep sees them).
- **`survey_takedown.lua`** (read-only, Edit, no MODE line: it never writes). It returns JSON with:
  - **`Scripts`:** for each label above, whether the Studio path exists and its class;
  - **`Anims`:** for each of `Misc_Assassinate`, `Fist_BearHug`, `Fist_BearHugVictim`, `Gripping`, `Gripped`, `Knocked`, `Gauntlets_Grip`, `Gauntlets_Gripped`: its full name and `AnimationId`; and for each of `Misc_AssassinateVictim`, `Takedown_Choke`, `Takedown_ChokeVictim`: `"absent"` or its full name (any present one is a blocker for Task 3);
  - **`Sequences`:** for 83505608395055, 140607038476506 and 76737043223431, read with `KeyframeSequenceProvider:GetKeyframeSequenceAsync("rbxassetid://<id>")` in a pcall: the length (the last keyframe's time), every `KeyframeMarker` name and time, the set of pose names (to spot a weapon bone such as `Hilt`), and the `HumanoidRootPart` and `Torso` pose translations at the first and last keyframe. The sequence is read only; it is never parented into the place;
  - **`KeyN`:** every script in `game` (both places) whose Source matches `KeyCode.N[^%w]` or `"N"` within a KeyCode or Keys context: path and line. Expected: none;
  - **`Spot`:** one test spot. The search is fixed: starting at the place's first `SpawnLocation` in workspace, walk a 16-stud grid outwards in rings to 400 studs. The first grid point where a ray down meets ground, the ground is within 1 stud of level over a 12-stud cross (5 rays), and a 12-stud-radius, 0.5–8-stud-high box above it holds no part (`GetPartBoundsInBox`, filtered to exclude characters), is the spot. It records `{X, Y, Z}` (ground top) and the spawn it started from. It never looks at enemies, light or perception;
  - **`Assets`:** whether `ReplicatedStorage.Assets` is a package (`PackageLink`).

**Steps:**
- [ ] **Step 1: `--check` both places** (the global rule). Report any DIFFER and stop.
- [ ] **Step 2: RED.** Add the manifest pairs, then run `sync.py --place ye --check`: any pair whose repo file is out of date with Ye shows as DIFFER. If an **existing** repo copy differs from Ye, Studio wins: export Ye's copy over the repo file, byte for byte with CRLF normalised to LF, and list it in the report. If Foundry differs from Ye on a pair, report it; the controller rules before any sync.
- [ ] **Step 3:** Run `--check` in both places. Expected: `DIFFER 0 / MISSING 0`.
- [ ] **Step 4:** Write `survey_takedown.lua`. Run it in Ye (Edit) and in Foundry (Edit). Save each output as `survey_ye.json` / `survey_foundry.json`.
- [ ] **Step 5: One Play session in Ye** (`Ye:assn1`, the full protocol). In it, answer the Play checks in the report:
  - **A client prompt:** a TEMP LocalScript (or rbxc Client) makes a `ProximityPrompt` with `Style = Custom`, `KeyboardKeyCode = N`, `HoldDuration = 0.6`, under a test part 3 studs in front of the character. Does PromptUI draw it (a `RenseiPrompt` BillboardGui appears)? Does `Prompt:InputHoldBegin()` then `InputHoldEnd()` after 0.1 s fire `PromptButtonHoldBegan` and `PromptButtonHoldEnded` without `Triggered`? Does a 0.8 s hold fire `Triggered`? Remove the part and script after;
  - **A dead rig:** spawn a Grunt through `EnemyService.Spawn` with an unparented mark at the survey spot, `AIPassive`, `Credited = true`; set its Health to 0; record its root's tilt from upright every second for 5 s;
  - **The Bear Hug pair:** on two test rigs at the spot, the second welded 1.6 studs in front of the first, play `Fist_BearHug` and `Fist_BearHugVictim` (server playback resolves Registry). Take one `screen_capture` mid-play for the controller (evidence only, not committed);
  - **Crouch and Grip:** with the character crouched (the `Stun` toggle through the real state path) beside a knocked test rig, does `DownedManager.Grip(Character)` return false? (Finding A15.)
- [ ] **Step 6:** Commit `sync_manifest.json`, `survey_takedown.lua`, `survey_ye.json`, `survey_foundry.json` and any re-exported files: `"Assassinations Task 1: parity pairs and the read-only takedown survey"`.

**Report:** the survey's answers, especially the three sequences (length, markers, root travel), the spot in each place, `KeyN`, and the Play answers. Task 2 uses the measured offset and kill moment; Task 3 refuses if a slot name exists.

---

### Task 2: `Rensei.Takedown`: the numbers and the pure rules

**Files:**
- **Create:** `Scripts/ReplicatedStorage/Modules/Data/Rensei/Takedown.lua`, `Scripts/ServerStorage/RenseiTests/Test_Takedown.lua`.
- **Manifest:** `Rensei.Takedown` and `RenseiTests.Test_Takedown`, both `Create: true`.
- **No game behaviour change:** nothing requires the module yet.

**Interfaces** (the whole module; Instances come in only as arguments). Replace `Offset`, `KillAt` (a "Kill" or "Hit" marker's time ÷ the length) and `AnimLength` with Task 1's measurements when it found them, and say so in the comment; otherwise keep these defaults. For the knockout, `AnimLength.Knockout` is the Bear Hug's length until the owner's choke is uploaded:

```lua
-- Takedown (assassinations, 2026-10-25; spec Documents/specs/2026-10-25-assassinations-design.md): the numbers, the
-- animation slot names and the pure rules of a stealth takedown. PvE only: Check refuses a player's character first.
-- TakedownService (server) decides; TakedownUI (client) only shows the prompt. Every number is a PROPOSAL.
-- No Instance is read here except through the arguments, so RenseiTests.Test_Takedown checks it without a game.
local Takedown = {}

Takedown.Key = "N" -- tap: knock out; hold HoldToKill: assassinate (reserved in Rensei.Settings)
Takedown.HoldToKill = 0.6 -- seconds
Takedown.Range = 4 -- studs, root to root on the ground plane
Takedown.RangeSlack = 1.5 -- server only: lag
Takedown.Height = 3 -- studs up or down
Takedown.BehindAngle = 70 -- degrees either side of straight behind (a 140 degree rear arc)
Takedown.AngleSlack = 10 -- server only
Takedown.BreakDistance = 6 -- farther apart mid-takedown: interrupted
Takedown.KnockoutTime = 2.0 -- seconds the choke takes
Takedown.LethalTime = 1.0 -- seconds the assassination takes
Takedown.KillAt = 0.6 -- share of LethalTime when the animation has no Kill / Hit marker (Task 1)
Takedown.KnockoutSeconds = 300 -- knocked out this long
Takedown.BodySeconds = 120 -- a takedown's dead body stays this long
Takedown.Cooldown = 4
Takedown.RefusedCooldown = 0.5
Takedown.ChunkShare = 0.45 -- an Elite's backstab: this share of its max health
Takedown.ChunkStun = 1.2
Takedown.Offset = CFrame.new(0, 0, -1.6) -- the victim's root in the player's root space (Task 1 measures)
Takedown.AnimLength = {Assassinate = 1.0, Knockout = 2.0} -- the player animations' lengths (Task 1 measures; defaults play at 1x)
Takedown.SpeedClamp = {0.6, 1.6} -- animation speed = length / time, clamped (as DownedManager.Grip)

Takedown.Kinds = {Knockout = true, Assassinate = true}
Takedown.Phases = {Unaware = true, Suspicious = true, Cautious = true} -- Alert: never
Takedown.ClassByPerception = {Grunt = "Full", Agent = "Full", Elite = "Chunk", Hunter = "Chunk"}

-- slots (Assets.Animations.Shared.Takedown, Task 3). Empty slots play the fallback; no id is ever invented.
Takedown.Anims = {
	Assassinate = {Player = "Misc_Assassinate", PlayerFallback = "Gripping", Victim = "Misc_AssassinateVictim", VictimFallback = "Gripped"},
	Knockout = {Player = "Takedown_Choke", PlayerFallback = "Fist_BearHug", Victim = "Takedown_ChokeVictim", VictimFallback = "Fist_BearHugVictim"},
}

local function Flat(V) return Vector3.new(V.X, 0, V.Z) end

-- Is the player in the victim's rear arc? VictimLook = its LookVector; ToPlayer = player root - victim root.
function Takedown.Behind(VictimLook, ToPlayer, Slack)
	local L, D = Flat(VictimLook), Flat(ToPlayer)
	if L.Magnitude < 1e-3 or D.Magnitude < 1e-3 then return false end
	local FromBack = math.deg(math.acos(math.clamp((-L.Unit):Dot(D.Unit), -1, 1)))
	return FromBack <= Takedown.BehindAngle + (Slack or 0)
end

-- "Full" | "Chunk" | "Immune". PerceptionType: the type PerceptionService tracks the rig as, or nil when it doesn't
-- track it (arena / trial foes). Attrs = {Boss, TrialFoe, TakedownClass}, read from the rig by the caller.
function Takedown.ClassOf(PerceptionType, Attrs)
	Attrs = Attrs or {}
	local Forced = Attrs.TakedownClass
	if Forced == "Full" or Forced == "Chunk" or Forced == "Immune" then return Forced end
	if Attrs.Boss or Attrs.TrialFoe or PerceptionType == nil then return "Immune" end
	return Takedown.ClassByPerception[PerceptionType] or "Full"
end

-- Ctx: plain values the caller gathered. Returns true, or false and the first failing reason. The PvE rule is first.
--   IsPlayer, IsTownsfolk, IsEnemy, Alive, Kind, Class, Ready, PlayerFree, PlayerCalm, TargetFree,
--   Phase, AwareOfYou (0..1), Dist, Height, Range (Range, or Range + RangeSlack on the server), Behind, Clear
function Takedown.Check(Ctx)
	if Ctx.IsPlayer then return false, "player" end
	if Ctx.IsTownsfolk then return false, "townsfolk" end
	if not Ctx.IsEnemy then return false, "not_enemy" end
	if not Ctx.Alive then return false, "dead" end
	if not Takedown.Kinds[Ctx.Kind] then return false, "kind" end
	if Ctx.Class == "Immune" then return false, "immune" end
	if Ctx.Class == "Chunk" and Ctx.Kind ~= "Assassinate" then return false, "kind" end
	if not Ctx.Ready then return false, "cooldown" end
	if not Ctx.PlayerFree then return false, "busy" end
	if not Ctx.PlayerCalm then return false, "combat" end
	if not Ctx.TargetFree then return false, "target_busy" end
	if not Takedown.Phases[Ctx.Phase] or (tonumber(Ctx.AwareOfYou) or 0) >= 1 then return false, "alert" end
	if (tonumber(Ctx.Dist) or math.huge) > Ctx.Range then return false, "far" end
	if math.abs(tonumber(Ctx.Height) or math.huge) > Takedown.Height then return false, "far" end
	if not Ctx.Behind then return false, "front" end
	if not Ctx.Clear then return false, "blocked" end
	return true
end

-- Hiding spots come with stealth missions (slice M3). Until then nothing is hidden.
function Takedown.IsHidden(Body) return false end

return Takedown
```

**`Test_Takedown`** (every expected value written by hand):
- **`BehindArc`:** with `VictimLook = (0, 0, -1)`: `ToPlayer = (0, 0, 3)` → true; at 70° from straight behind → true; at 71° → false; `(3, 0, 0)` (the side) → false; `(0, 0, -3)` (in front) → false; 75° with `Slack = 10` → true; 81° with `Slack = 10` → false. A zero vector → false.
- **`Classes`:** `("Grunt", {})` → Full; `("Agent", {})` → Full; `("Elite", {})` → Chunk; `("Hunter", {})` → Chunk; `(nil, {})` → Immune; `("Grunt", {Boss = true})` → Immune; `("Elite", {TrialFoe = true})` → Immune; `("Grunt", {TakedownClass = "Chunk"})` → Chunk; `("Elite", {TakedownClass = "Bogus"})` → Chunk.
- **`CheckOrder`:** a context where **every** gate passes returns true. Then, for each gate in order, a copy with only that field broken returns false and exactly that reason (16 cases).
- **`PlayerFirst`:** a context with `IsPlayer = true` **and** every other field broken returns `"player"`.
- **`ChunkNoKnockout`:** `Class = "Chunk"`, `Kind = "Knockout"`, everything else passing → `"kind"`.
- **`Numbers`:** `Range` 4, `Height` 3, `BehindAngle` 70, `HoldToKill` 0.6, `KnockoutTime` 2.0, `LethalTime` 1.0, `KnockoutSeconds` 300, `BodySeconds` 120, `Cooldown` 4, `ChunkShare` 0.45 (a guard against an accidental edit; the owner changes them here and in the test together).

**Steps:**
- [ ] **Step 1: RED.** Write `Test_Takedown` first and sync only it. Run it in a Ye Play session (`Ye:assn2`): every test fails (the module is missing).
- [ ] **Step 2:** Write `Takedown.lua`. Sync `Rensei.Takedown` and `RenseiTests.Test_Takedown` to both places.
- [ ] **Step 3: GREEN** in a new Ye Play session (script edits are refused while Play runs, so the RED session is stopped and unhooked first): `Test_Takedown` all pass.
- [ ] **Step 4:** `--check` both places.
- [ ] **Step 5: Commit** `Takedown.lua`, `Test_Takedown.lua`, `sync_manifest.json`: `"Assassinations Task 2: Rensei.Takedown, the numbers and pure gate rules (PvE check first)"`.

---

### Task 3: The animation slots (both places, reversible)

**Files:** create `Art/Studio/Takedown/anim_slots.lua`. In Studio, both places' `ReplicatedStorage.Assets.Animations`.

**Interfaces:**
- **The flag:** the attribute `TakedownAnimSlots` on `Assets.Animations`.
- **`apply`:**
  - creates the Folder `Assets.Animations.Shared.Takedown` (`TakedownAdd = true`);
  - **moves** `Misc_Assassinate`, `Fist_BearHug` and `Fist_BearHugVictim` into it from wherever Task 1 found them, each marked `TakedownFrom = <old parent's full name>`. Nothing is copied, so no name appears twice;
  - creates three `Animation` instances with `AnimationId = ""`, each with `TakedownAdd = true` and a `Fallback` attribute: `Misc_AssassinateVictim` (`"Gripped"`), `Takedown_Choke` (`"Fist_BearHug"`), `Takedown_ChokeVictim` (`"Fist_BearHugVictim"`);
  - **refuses** when any of the three new names exists anywhere under `Assets.Animations`, or when any of the three moved ones is missing, or when `Misc_Assassinate`'s id isn't `rbxassetid://83505608395055` (a constant in the script: the sheet's).
- **`undo`:** moves the three back to their `TakedownFrom` parents, deletes exactly the `TakedownAdd` instances, and only while each new slot's `AnimationId` is still `""`. If the owner has uploaded one, it refuses and names it.
- **`check`:** the folder exists; the six names are in it; `Misc_Assassinate` holds the sheet id; each new slot is empty or holds an `rbxassetid://<digits>` id and carries its Fallback; no other child of `Shared`, `Weapons` or `Registry` changed (the names recorded at apply).
- The fallbacks named in `Rensei.Takedown.Anims` (`Gripping`, `Gripped`) are where Task 1 found them; this script doesn't move them. If Task 1 found either outside `Shared` or `Weapons`, report it: the controller rules on moving it too.

**Steps:**
- [ ] **Step 1: RED.** `check` in Ye: FAIL (folder missing, six names missing).
- [ ] **Step 2:** In Ye, run `test`, then `apply`, then `check` (PASS). Repeat in Foundry.
- [ ] **Step 3: Play in Ye** (`Ye:assn3`). Client data model: `AnimationManager.Has(Character, "Misc_Assassinate")` and `Has(Character, "Fist_BearHug")` are true; `Has(Character, "Takedown_Choke")` and `Has(Character, "Misc_AssassinateVictim")` are false; the output has no animation errors for the six names. This proves the client preloads the slots and an empty slot falls back safely.
- [ ] **Step 4: Commit** `anim_slots.lua`: `"Assassinations Task 3: takedown animation slots (sheet id + three empty, with fallbacks; both places, reversible)"`.

---

### Task 4: Perception: sounds, a rig being taken down, `Glimpse`, `Raise`

**Files:**
- **Modify:** `Perception.lua`, `PerceptionService.lua`, `Test_Sound.lua`, `Play_Stealth.lua` (only if its helpers move).
- **Create:** `RenseiTests/TakedownKit.lua`, `RenseiTests/Play_Takedown.lua`.
- **Manifest:** `RenseiTests.TakedownKit` and `RenseiTests.Play_Takedown` (`Create: true`).
- **No change a player can see:** no rig carries `TakenDownBy` yet, and nothing calls `Glimpse` or `Raise`.

**Interfaces:**
- **`Perception.Sounds`** gains `Choke = 6` and `Takedown = 4` (PROPOSAL; spec §7.2).
- **`PerceptionService.Update`:** the early return (`PerceptionService.lua:161`) also returns when `Rig:GetAttribute("TakenDownBy")` is set. A rig being taken down perceives nothing.
- **`PerceptionService.Glimpse(Player, Except) -> {Rig}`:** one quick look at the player by every registered NPC except `Except`:
  - skips NPCs that are dead, knocked or taken down;
  - an NPC sees the player when the player's root is within its type's `Range` of its head, `P.ConeMult(Root.LookVector, To) > 0`, and at least one of head, torso and feet has a clear ray from its head (the same `Rays` params and filter as `Visible`, but **its own three rays**, never the tick `Budget`);
  - for each that sees: `S.Seen[Player] = Now()`, `S.Spot[Player] = root position`; if `S.Combat`, `PerceptionService.Alarm(Rig, Player)`;
  - returns the list. No light or movement multiplier: a glance at an attack (spec §6).
- **`PerceptionService.Raise(Rig, Where)`:** an Alert search at a spot with nobody to fight:
  - `S.Focus = nil`, `S.LastKnown = Where`, `S.SearchUntil = Now() + P.SearchTime`, `SetPhase(S, "Alert")`;
  - then a new local `CallSpot(S, Where)`: like `Call` (`:101-114`) but with no player: every other NPC of the same `Combat` kind within `P.CallRadius` that isn't Alert gets `LastKnown = Where`, `InvestigateUntil = Now() + P.InvestigateTime` and goes Suspicious. `Call` itself is unchanged.
- **`Decide`, the Alert branch** (`:123-137`): **new first line:** when `S.Focus == nil` and `Best >= 1`, take `BestPlayer` as the focus (`S.Focus, S.SearchUntil = BestPlayer, nil`, `S.LastKnown = S.Spot[BestPlayer] or S.LastKnown`, `Call(S, BestPlayer, S.LastKnown)`) and return. Without it, an NPC `Raise`d with nobody in focus would never fight a player it then sees. The only other way to reach a nil focus is the focus player leaving the server (`:388-393`); there it now also picks up another player it fully sees. Say so in the header comment.
- **`TakedownKit`** (shared helpers; required, never copied):
  - `Kit.Spot()`: the survey spot for this place (`survey_ye.json` / `survey_foundry.json` values, pasted into the kit as constants with the survey's date);
  - `Kit.Spawn(Type, CFrame, Opts) -> Rig`: an unparented spawn mark (`EnemyType = Type`), `EnemyService.Spawn(Mark)`, then `AIPassive = true` and `Credited = true` unless `Opts.Credit`; pivots the rig to `CFrame`; waits until `PerceptionService.Tracks(Rig)` (or 2 s for an untracked type) and resets it to Unaware;
  - `Kit.Face(Rig, Dir)`, `Kit.PutPlayer(CFrame)`, `Kit.PutBehind(Rig, Dist, AngleFromBack)`, `Kit.PutInFront(Rig, Dist)`;
  - `Kit.Wall(CFrame, Size)`: an anchored test part, removed by `Clean`;
  - `Kit.Run(Seconds)`: `PerceptionService.Step(0.2)` repeated, with `SetAuto(false)` held by `Guard`;
  - `Kit.Guard(Body)`: saves the character's pivot, `CombatMode`, `Crouching`, `Anchored`; sets `PerceptionService.SetAuto(false)` and `LightService.SetAuto(false)`; runs `Body` in a pcall; then `Clean`: destroys every rig and part the kit made, clears `TakingDown`, `TakedownReadyAt` and `LastTakedownResult` on the character, restores the saved values and `SetAuto(true)`; re-raises the error;
  - Play_Stealth's own helpers (`Find`, `Run`, `Put`, `Part`, `Guard`): if the swim plan moved them into a shared kit, `TakedownKit` requires it; otherwise move them into `TakedownKit` now and make `Play_Stealth` require them, with no change to its tests.

**Tests** (new, in `Play_Takedown` unless named):
- `Test_Sound.TakedownSounds`: `P.Sounds.Choke == 6`, `P.Sounds.Takedown == 4`.
- `SkipWhileTakenDown`: a Grunt at the spot faces the player 8 studs away in the open, `TakenDownBy` set by the test → after `Kit.Run(2)` its awareness of the player is still 0. Then cleared → after `Kit.Run(2)` it is above 0 (the control that proves the setup can notice).
- `GlimpseFront`: a Grunt facing the player at 8 studs → `Glimpse` returns it, its phase is Alert, `PerceptionService.Target(Rig)` is the character.
- `GlimpseBehind`: the same Grunt turned away → not returned, still Unaware.
- `GlimpseWall`: facing, with `Kit.Wall` between (a 1 × 12 × 12 part) → not returned.
- `RaiseSearches`: `Raise(Rig, Spot + (10, 0, 0))` → Alert, `Target(Rig)` nil, `Goal(Rig)` within 20 studs of that point; a second Grunt 30 studs away goes Suspicious with `Goal` at that point; a third 60 studs away stays Unaware.
- `RaiseThenSees`: after `Raise`, the player put in full view at 6 studs; `Kit.Run(3)` → `Target(Rig)` is the character (the new `Decide` line).

**Steps:**
- [ ] **Step 1:** `--check` both places.
- [ ] **Step 2: RED.** Write the kit and the tests; sync only the test modules. Run in Ye Play (`Ye:assn4`): `TakedownSounds`, `SkipWhileTakenDown`, `GlimpseFront`, `GlimpseBehind`, `GlimpseWall`, `RaiseSearches` and `RaiseThenSees` fail (`Glimpse` and `Raise` are nil; the skip doesn't exist). `GlimpseBehind` and `GlimpseWall` must fail for the missing function, not pass.
- [ ] **Step 3:** Make the changes. Sync `Rensei.Perception`, `RenseiServer.PerceptionService`, `RenseiTests.TakedownKit`, `Play_Takedown`, `Test_Sound` (and `Play_Stealth` if its helpers moved) to both places.
- [ ] **Step 4: GREEN** in Ye Play: `Play_Takedown` all pass; `Test_Sound`, `Test_Perception`, `Play_Stealth`, `Play_Perception` as their swim-plan baselines (no new FAIL).
- [ ] **Step 5:** `--check` both places.
- [ ] **Step 6: Commit** the changed and new files and `sync_manifest.json`: `"Assassinations Task 4: perception skips a rig being taken down; Glimpse, Raise, takedown sounds"`.

---

### Task 5: Bodies: found by sight, and takedown bodies stay

**Files:** modify `PerceptionService.lua`, `EnemyService.lua`, `Play_Takedown.lua`.
**No change a player can see:** no body is registered, and no rig carries `TakenDownBy`, until Task 7.

**Interfaces:**
- **`PerceptionService.Bodies`** (`[Model] = Info`). **`AddBody(Model, Info)`** with `Info = {Kind = "Dead" | "Out", By = Player}`; it adds `Info.Found = false`, `Info.Fill = {}` (`[Rig] = 0..1`), and removes the body on `Model.Destroying`. **`RemoveBody(Model)`**. **`BodyFound`**: a list of listeners `(Body, Finder, Info)`, each run in a pcall.
- **Finding, at the end of `Step`** (after the NPC updates, sharing the tick `Budget`):
  - skip a body that is `Found`, has no `Torso` / `HumanoidRootPart`, or for which `require(Rensei.Takedown).IsHidden(Model)` is true;
  - for each registered NPC with `S.Combat`, alive, not knocked, not taken down, phase not Alert, and its head within its type's `Range` of the body's torso:
    - `Cone = P.ConeMult(Root.LookVector, Torso - Head)`; skip when 0;
    - one ray from its head to the body's torso (filter: the NPC and the body), costing one from `Budget`; with no budget left, it waits for the next tick;
    - clear → `Info.Fill[Rig] += P.Rate(S.Type, Dist, Cone, 1, 1, P.ExposureMult(PerceptionService.ExposureOf(Model) or 1), Cautious) * Dt`;
    - at `>= 1`: `Info.Found = true`, `PerceptionService.Raise(Rig, torso position)`, fire `BodyFound`. One finder per body.
  - Townsfolk (`Combat = false`) never look (spec decision 8).
- **`EnemyService`, the `Died` handler** (`EnemyService.lua:481-487`): the corpse waits `Takedown.BodySeconds` instead of `CORPSE_SECONDS` when `Rig:GetAttribute("TakenDownBy")` is set (require `Rensei.Takedown` at the top). Everything else in the handler is unchanged: the respawn timer still starts at death.

**Tests** (`Play_Takedown`):
- `BodyFoundInView`: a test rig registered as a `"Dead"` body at the spot (killed by the test with `TakenDownBy` set); a Grunt 10 studs away facing it in the open, at noon (`Lighting.ClockTime = 12` held by the test, as Play_Stealth holds the clock) → within `Kit.Run(4)` it is Alert, `Goal` within 20 studs of the body, and `BodyFound` fired once with that Grunt.
- `BodyNotBehind`: the same Grunt facing away → after `Kit.Run(4)` still Unaware, not found.
- `BodyDarkIsSlower`: two runs at the same distance: at noon the time to found is `T1`; at night (`ClockTime = 0`, no lamp within 60 studs of the spot: the survey's spot has none, checked by the test before it starts, and the test fails if one is found) the body isn't found within `3 × T1`. The control proves light matters, not luck.
- `FoundOnce`: after a find, a second Grunt facing it doesn't fire `BodyFound` again.
- `TakedownBodyStays`: a test Grunt with `TakenDownBy` set, Health set to 0 → its model still exists after 6 s (today it is gone at 4 s). A control Grunt without the attribute is gone by 6 s.

**Steps:**
- [ ] **Step 1:** `--check` both places.
- [ ] **Step 2: RED.** Add the tests; sync `Play_Takedown`. Ye Play (`Ye:assn5`): all five fail (`AddBody` nil; the corpse is gone at 4 s). The `TakedownBodyStays` control passes.
- [ ] **Step 3:** Make the changes. Sync `RenseiServer.PerceptionService`, `RenseiServer.EnemyService`, `RenseiTests.Play_Takedown` to both places.
- [ ] **Step 4: GREEN** in Ye Play: `Play_Takedown` all pass; `Play_Stealth`, `Play_Perception` unchanged.
- [ ] **Step 5:** `--check` both places.
- [ ] **Step 6: Commit** the three files: `"Assassinations Task 5: NPCs find bodies by sight (light counts) and search there; takedown bodies stay 120 s"`.

---

### Task 6: An optional knock length, and the deed

**Files:** modify `DownedManager.lua`, `Deeds.lua`, `Test_Takedown.lua`; extend `Play_Takedown.lua`.
**No change a player can see:** every existing call passes no length, and the new deed is recorded by nothing yet.

**Interfaces:**
- **`DownedManager.Knock(Victim, Seconds)`:** `Seconds` (optional) is the knock length; when it's a positive number it wins over the `KnockedTime` attribute and `TuningConfig.Downed.KnockedTime` (`DownedManager.lua:173`). Second Wind (players only) is unchanged. Update the header comment.
- **`Deeds`:**
  ```lua
  -- ===== Takedowns (assassinations, 2026-10-25): an assassinated bandit weighs the same as a finished one (PROPOSAL) =====
  assassinated_bandit = {
  	Text = "Assassinated a bandit",
  	Conduct = {Mercy = -1},
  	Scope = "Local",
  	Repeat = {Cap = 10},
  },
  ```
  and `Finishers.Grunt.Assassinate = "assassinated_bandit"`, `Finishers.Elite.Assassinate = "assassinated_bandit"`. No `Knockout` entry (a knockout of a hostile mob is no deed). Update the Finishers comment.

**Tests:**
- `Test_Takedown.Deed`: `Deeds.assassinated_bandit` has Mercy −1, Local, cap 10, no `Crime`; `Deeds.Finishers.Grunt.Assassinate` and `.Elite.Assassinate` name it; `Finishers.Grunt.Knockout` is nil.
- `Play_Takedown.KnockLength`: a test Grunt knocked with `DownedManager.Knock(Rig, 7)` → `KnockedUntil − now` within 7 ± 0.2. A control knocked with no length → 20 ± 0.2.

**Steps:**
- [ ] **Step 1:** `--check` both places.
- [ ] **Step 2: RED.** Add both tests; sync the two test modules. Ye Play (`Ye:assn6`): `Deed` and `KnockLength` fail (the control passes).
- [ ] **Step 3:** Make the changes. Sync `Managers.DownedManager`, `Rensei.Deeds` and the two test modules to both places.
- [ ] **Step 4: GREEN** in Ye Play: both pass; `Play_Morality` and `Play_TownsfolkHurt` unchanged.
- [ ] **Step 5:** `--check` both places.
- [ ] **Step 6: Commit** `DownedManager.lua`, `Deeds.lua`, both tests: `"Assassinations Task 6: DownedManager.Knock takes a length; the assassinated_bandit deed"`.

---

### Task 7: The server takedown: gates and assassinate

**The first behaviour change.** The controller confirms the owner has seen the spec before this task starts. Players can't trigger it yet (no prompt until Task 10), but the request is live once synced.

**Files:**
- **Create:** `Scripts/ServerScriptService/TakedownService.lua`, `Scripts/ServerScriptService/ServerHandler/Requests/Takedown.lua`.
- **Modify:** `ServerHandler.server.lua` (one line), `EnemyService.lua` (`Busy`), `Play_Takedown.lua`.
- **Manifest:** `RenseiServer.TakedownService` and `Requests.Takedown` (`Create: true`).

**Interfaces:**
- **`Requests/Takedown.lua`:**
  ```lua
  -- Takedown (assassinations, 2026-10-25): the client asks to knock out or assassinate an enemy. Typed here; every rule
  -- is TakedownService's. PvE only: a player's character is refused there, first.
  return function(Player, Kind, Target)
  	if type(Kind) ~= "string" or typeof(Target) ~= "Instance" or not Target:IsA("Model") then return end
  	require(game:GetService("ServerScriptService").TakedownService).Request(Player, Kind, Target)
  end
  ```
- **`TakedownService`** (server; the header comment states the spec, the PvE rule and every attribute):
  - `TakedownService.Done = {}` and `TakedownService.Failed = {}`: listener lists, each called in a pcall: `Done(Kind, Player, Rig)`, `Failed(Player, Rig, Reason)`.
  - `TakedownService.Context(Player, Target, Kind) -> Ctx`: gathers `Rensei.Takedown.Check`'s fields, with the server's slack:
    - `IsPlayer = Players:GetPlayerFromCharacter(Target) ~= nil` — **computed first**;
    - `IsTownsfolk = Target:GetAttribute("TownsfolkId") ~= nil`; `IsEnemy = EnemyService.Active[Target] ~= nil`; `Alive`;
    - `Class = Takedown.ClassOf(PerceptionService.Tracks(Target) and PerceptionService.Npcs[Target].Type or nil, {Boss, TrialFoe, TakedownClass from the rig})`;
    - `Ready`: `os.clock() >=` this player's next allowed time;
    - `PlayerFree`: alive, not `Knocked`, `Gripping`, `Carrying` or `TakingDown`, `not AttackRunner.IsRunning(Character)`, no Stun status **other than** `AttackRunner.CrouchStuns[WC]` (finding A15), `Humanoid.FloorMaterial ~= Air`, `Traversal ~= "Swim"`;
    - `PlayerCalm = Character:GetAttribute("CombatMode") ~= true`;
    - `TargetFree`: not `Knocked`, `GrippedBy`, `CarriedBy`, `TakenDownBy`, not swimming;
    - `Phase = PerceptionService.PhaseOf(Target)`, `AwareOfYou = PerceptionService.Awareness(Target, Player)`;
    - `Dist` on the ground plane, `Height`, `Range = Takedown.Range + Takedown.RangeSlack`;
    - `Behind = Takedown.Behind(TargetRoot.CFrame.LookVector, PlayerRoot.Position - TargetRoot.Position, Takedown.AngleSlack)`;
    - `Clear`: one ray torso to torso (filter both characters, `RespectCanCollide`) meets nothing.
  - `TakedownService.Check(Player, Target, Kind) -> ok, reason`: `Takedown.Check(Context(...))`. Never yields.
  - `TakedownService.Request(Player, Kind, Target) -> ok, reason`:
    1. refuse quietly if the character or roots are missing;
    2. `Check`; on refusal: the next allowed time = now + `RefusedCooldown`, `LastTakedownResult = Kind .. ":" .. reason`, return;
    3. **in the same step, no yield:** `Target:SetAttribute("TakenDownBy", Player.Name)`, `Character:SetAttribute("TakingDown", Target.Name)`;
    4. `task.spawn(Run, Player, Target, Kind)`; return true, "started".
  - **`Run`, for `"Assassinate"` on a Full target** (this task):
    1. `PerceptionService.Glimpse(Player, Target)` (spec §6);
    2. lock the player (save and zero `WalkSpeed` and `JumpHeight`, as `DownedManager`'s `Lock` does) and protect the victim (save its `DamageTakenMult`, set 0; start a WCS Stun for the takedown's length; `AnimationManager.StopAllAnims(Target)`);
    3. place the player at `TargetRoot.CFrame * Takedown.Offset:Inverse()`, weld the victim's root to the player's root (`C0 = Takedown.Offset`), victim parts massless, `PlatformStand`, network owner = the player (as `DownedManager`'s `Attach`; restored after);
    4. play `Anims.Assassinate.Player` on the player and `.Victim` on the victim, each with its fallback, `Priority = Action4`, `Speed = clamp(Takedown.AnimLength.Assassinate / LethalTime, SpeedClamp)`;
    5. each Heartbeat until `LethalTime × KillAt`: interrupted when either is gone or dead, the player is knocked or has a Stun other than the crouch's, or the roots are more than `BreakDistance` apart;
    6. **the kill:** `WorldService.Credit(Target, Player)` (once; it respects `Credited`), then `MoralityService.Record(Player, Deeds.Finishers[EnemyType].Assassinate, false, {Witness = true})` when that entry exists, then `Target.Humanoid.Health = 0`, then `NoiseService.Emit(TargetRoot.Position, "Takedown", Character)`, then `PerceptionService.AddBody(Target, {Kind = "Dead", By = Player})`. **No `RecordHit`** (finding A4);
    7. release: unweld, restore the victim's parts and the player's lock; play `Knocked` looped on the corpse; `TakenDownBy` **stays** on the corpse (the body mark, Task 5); clear `TakingDown`;
    8. the next allowed time = now + `Cooldown`; `Character:SetAttribute("TakedownReadyAt", workspace:GetServerTimeNow() + Cooldown)`; `LastTakedownResult = "Assassinate:ok"`; fire `Done`.
  - **Interrupted** (any kind): release as in 7, but clear `TakenDownBy`, restore `DamageTakenMult`, stop the victim's Stun, `PerceptionService.Alarm(Target, Player)`, cooldown as in 8, `LastTakedownResult = Kind .. ":interrupted"`, fire `Failed(Player, Target, "interrupted")`.
  - `"Knockout"` and Chunk targets return `Kind .. ":todo"` until Tasks 8–9 (refused before anything is marked: `Check` passes, so `Request` checks for these two before step 3 and refuses with `"todo"`).
  - `TakedownService.Start()`: `PlayerRemoving` clears that player's cooldown and releases any takedown they're in (as an interrupt, without the Alarm).
- **`EnemyService.Busy`** (`EnemyService.lua:187-190`) also returns true for `Rig:GetAttribute("TakenDownBy")`.
- **`ServerHandler`:** after the `CombatDirector.Start()` line, `require(ServerScriptService.TakedownService).Start() -- stealth takedowns (assassinations), PvE only`.

**Tests** (`Play_Takedown`; each spawns its own Grunt at the spot with `TakedownKit`):
- **Refusals, each with its reason in `LastTakedownResult`:**
  - `RefuseFront`: player 3 studs in front → `"Assassinate:front"`;
  - `RefuseSide`: 3 studs at 90° → `"front"`;
  - `RefuseFar`: 6 studs behind → `"far"`;
  - `RefuseWall`: 3 studs behind with `Kit.Wall` between → `"blocked"`;
  - `RefuseAlert`: after `PerceptionService.Alarm(Rig, Player)` → `"alert"`;
  - `RefuseCombat`: `CombatMode = true` → `"combat"`;
  - `RefuseSelf` (**PvE**): `Request(Player, "Assassinate", Player.Character)` → `"player"`, and the character has no `TakenDownBy`;
  - `RefuseMalformed`: the request module called with `(Player, 5, Rig)`, `(Player, "Assassinate", "x")` and `(Player, "Fly", Rig)` → no error, nothing marked, the last one `"Fly:kind"`.
- `AssassinateFromBehind`: 3 studs straight behind an Unaware Grunt, crouched (a WCS Stun started the way `CharacterHandler.server.lua:150-157` does, stored in `AttackRunner.CrouchStuns`, with `Crouching = true`; stopped by `Clean`) → within `LethalTime + 1` s the Grunt is dead, `LastTakedownResult == "Assassinate:ok"`, `NoiseService.Log` (set by the test) holds one `Takedown` of radius 4 and **no** `Hit`.
- `AssassinateCredit` (spawned with `Opts.Credit`): the player's EXP grows by exactly the Grunt's `25 × Level` once (read before and after), and `Data.Morality.Deeds.assassinated_bandit.Count` grows by 1.
- `AssassinateSuspicious`: a Grunt sent Suspicious by `PerceptionService.Hear` at a spot 10 studs in front of it → allowed.
- `WitnessAlerts`: a second Grunt 10 studs away facing the player during an assassination → Alert with `Target` = the character. A third facing away → still Unaware.
- `Cooldown`: a second request 1 s after the first finished → `"cooldown"`; after 4.2 s → allowed.
- `OneTakedownPerTarget`: two requests for the same Grunt in the same frame → the second is `"target_busy"`.
- `InterruptByStun`: a WCS Stun started on the player mid-takedown → `"Assassinate:interrupted"`, the Grunt alive and Alert on the player, `Failed` fired once with `"interrupted"`.
- `VictimProtected`: `DownedManager.Damage(Rig, 999)` mid-takedown leaves its health unchanged.

**Steps:**
- [ ] **Step 1:** `--check` both places.
- [ ] **Step 2: RED.** Add the tests; sync `Play_Takedown`. Ye Play (`Ye:assn7`): every new test fails (no service, no request).
- [ ] **Step 3:** Write the service and the request; change `EnemyService` and `ServerHandler`. Sync `RenseiServer.TakedownService`, `Requests.Takedown`, `RenseiServer.ServerHandler`, `RenseiServer.EnemyService`, `RenseiTests.Play_Takedown` to both places.
- [ ] **Step 4: GREEN** in Ye Play: `Play_Takedown` all pass; `Play_Morality`, `Play_Heat`, `Play_Stealth`, `Play_TownsfolkHurt` unchanged. Report the deed and EXP probes from the protocol (they must equal before and after the restore).
- [ ] **Step 5:** `--check` both places.
- [ ] **Step 6: Commit** the new and changed files and `sync_manifest.json`: `"Assassinations Task 7: TakedownService and the Takedown request: gates (PvE first), assassinate, witnesses, cooldown, interrupt"`.

---

### Task 8: Knock out, and waking up raises the alarm

**Files:** modify `TakedownService.lua`, `Play_Takedown.lua`.

**Interfaces:**
- **`Run`, for `"Knockout"` on a Full target:**
  1. `Glimpse`, lock and protect as in Task 7; `NoiseService.Emit(TargetRoot.Position, "Choke", Character)` at the start;
  2. place, weld and play `Anims.Knockout` (player and victim, with fallbacks; `Speed = clamp(Takedown.AnimLength.Knockout / KnockoutTime, SpeedClamp)`) for `KnockoutTime`, with the same interrupt rules;
  3. at the end: release; restore `DamageTakenMult`; stop the Stun; clear `TakenDownBy`; `DownedManager.Knock(Target, Takedown.KnockoutSeconds)`; `Target:SetAttribute("KnockedOutBy", Player.UserId)`; `PerceptionService.AddBody(Target, {Kind = "Out", By = Player})`; cooldown; `"Knockout:ok"`; `Done`.
- **Waking up** (connected per victim at step 3):
  - when `Knocked` clears and the rig is alive with `KnockedOutBy` set: `RemoveBody`, clear `KnockedOutBy`, and, unless `Takedown.IsHidden(Target)`, `PerceptionService.Raise(Target, its root position)`;
  - when it dies (a grip, a delivery): `RemoveBody`, clear `KnockedOutBy`. A grip stays the existing loud finisher with its own deed (spec §4).
- Remove `"Knockout"` from Task 7's `"todo"` refusal.

**Tests:**
- `KnockoutFromBehind`: a Grunt → `"Knockout:ok"` after `KnockoutTime`; `Knocked` true; `KnockedUntil − now` within 300 ± 1; one `Choke` sound of radius 6 at the start; no deed recorded (`Data.Morality.Deeds` unchanged).
- `KnockedOutCanBeCarried`: `DownedManager.Carry(Character)` → true; drop it.
- `WakeRaisesAlarm`: knock out, then the test calls `DownedManager.Recover(Rig)` (the same path the timer takes) → Alert with `Target` nil, `Goal` within 20 studs of where it woke; a second Grunt 25 studs away goes Suspicious.
- `KnockedOutBodyFound`: a second Grunt facing the knocked-out one at 10 studs at noon → found (`BodyFound` fired, `Info.Kind == "Out"`).
- `InterruptKnockout`: a Stun on the player at 1 s → `"Knockout:interrupted"`, the Grunt not knocked, Alert on the player.

**Steps:**
- [ ] **Step 1:** `--check` both places.
- [ ] **Step 2: RED.** Add the tests; sync `Play_Takedown`. Ye Play (`Ye:assn8`): all fail (`"Knockout:todo"`).
- [ ] **Step 3:** Make the change. Sync `RenseiServer.TakedownService` and `Play_Takedown` to both places.
- [ ] **Step 4: GREEN** in Ye Play: `Play_Takedown` all pass.
- [ ] **Step 5:** `--check` both places.
- [ ] **Step 6: Commit** `TakedownService.lua`, `Play_Takedown.lua`: `"Assassinations Task 8: knock out (300 s), carryable; waking up raises the alarm"`.

---

### Task 9: Elites, bosses, townsfolk, and the hooks

**Files:** modify `TakedownService.lua`, `Play_Takedown.lua`.

**Interfaces:**
- **Chunk targets** (`"Assassinate"` only; `Check` already refuses a knockout):
  1. `Glimpse`; no weld; the player plays `Anims.Assassinate.Player` (fallback as before) for `LethalTime × KillAt`, then stops it;
  2. `DownedManager.Damage(Target, Humanoid.MaxHealth × ChunkShare)` and `ProgressionService.RecordHit(Character, Target, "Hit")`: the normal hit path, so the 20-stud Hit sound, the Alarm and last-hit credit happen as for any hit (spec §8);
  3. a WCS Stun on the target for `ChunkStun`; clear `TakenDownBy`; cooldown; `"Assassinate:backstab"`;
  4. if the target is alive and not knocked: `Failed(Player, Target, "survived")` (the Nemesis hook); otherwise `Done("Assassinate", Player, Target)`.
- Remove the Chunk `"todo"` refusal.
- **Immune** and **townsfolk** need no new code (`Check` refuses them); this task proves it.

**Tests:**
- `EliteBackstab`: a test Elite at full health → `"Assassinate:backstab"`; health = max × 0.55 ± 1; Alert on the player; `Failed` fired with `"survived"`; a `Hit` sound.
- `EliteNoKnockout`: `"Knockout"` on an Elite → `"Knockout:kind"`.
- `BossImmune`: a test rig spawned as `TrialFlame` (Boss, TrialFoe, untracked) → `"immune"`. Despawn it after.
- `ClassOverride`: a Grunt with `TakedownClass = "Immune"` → `"immune"`; with `"Chunk"` → backstab.
- `TownsfolkRefused`: in Ye, the nearest townsperson rig (found by `TownsfolkId`, read-only; it is never moved or hurt) as the target, with the player put behind it at 3 studs → `"townsfolk"`, and its health and state unchanged. In Foundry, the same with a Foundry townsperson.
- `DoneHook`: a listener added by the test sees `("Assassinate", Player, Rig)` once after an assassination, and is removed after.

**Steps:**
- [ ] **Step 1:** `--check` both places.
- [ ] **Step 2: RED.** Add the tests; sync `Play_Takedown`. Ye Play (`Ye:assn9`): `EliteBackstab` and `ClassOverride`'s Chunk half fail (`"todo"`); the refusal tests may already pass: **report which**, because they pass by Task 7's `Check`, and say so in the commit message (they are regression guards here, not new behaviour).
- [ ] **Step 3:** Make the change. Sync `RenseiServer.TakedownService`, `Play_Takedown`.
- [ ] **Step 4: GREEN** in Ye Play: `Play_Takedown` all pass; `Play_TownsfolkHurt` unchanged.
- [ ] **Step 5:** `--check` both places.
- [ ] **Step 6: Commit** `TakedownService.lua`, `Play_Takedown.lua`: `"Assassinations Task 9: Elite backstab, bosses immune, townsfolk refused; Done / Failed hooks"`.

---

### Task 10: The client: the prompt, the E fix, N reserved

**Files:**
- **Create:** `Scripts/ReplicatedStorage/Modules/UI/TakedownUI.lua`, `Art/Studio/Takedown/client_checks.lua`.
- **Modify:** `UIHandler.client.lua`, `CombatModeUI.lua`, `Settings.lua`.
- **Manifest:** `UI.TakedownUI` (`Create: true`).

**Interfaces:**
- **`TakedownUI`** (client; display and input only, the server decides):
  - `Start()`: every 0.1 s, picks a **candidate**: among the Models in `World.Live` with an `EnemyType` attribute (never a player's character, never a `TownsfolkId`): alive, not `Knocked` / `TakenDownBy` / `GrippedBy` / `CarriedBy`, `Awareness` in `Takedown.Phases`, `Takedown.ClassOf(Perception.EnemyTypes[EnemyType] or "Grunt", {Boss, TrialFoe, TakedownClass})` not Immune (an `AlwaysAware` type counts as untracked: Immune), `Takedown.Behind(...)` with **no** slack, within `Takedown.Range` and `Height`; the nearest wins;
  - the local player must be alive, not `Knocked` / `Gripping` / `Carrying` / `TakingDown`, not in Combat Mode, not swimming, and `workspace:GetServerTimeNow() >= TakedownReadyAt`;
  - no prompt while a conversation is open (`UIState.Gui.Dialogue.Visible`, the check CombatModeUI already makes) or the camera is `Scriptable` (a cutscene);
  - one `ProximityPrompt` named `TakedownPrompt`, made on the client under the candidate's `HumanoidRootPart`: `Style = Custom`, `KeyboardKeyCode = Enum.KeyCode[Takedown.Key]`, `HoldDuration = Takedown.HoldToKill`, `RequiresLineOfSight = false`, `MaxActivationDistance = Takedown.Range + 2`, `ObjectText = DisplayName .. " (" .. Awareness:lower() .. ")"`, `ActionText = "Knock out · hold to kill"` (Chunk: `"Backstab (hold)"`). It moves to the new candidate, or is destroyed when there is none;
  - **input:** `PromptButtonHoldBegan` notes the time; `PromptButtonHoldEnded` without a `Triggered` since → `RequestRemote:FireServer("Takedown", "Knockout", Rig)` (not for Chunk); `Triggered` → `FireServer("Takedown", "Assassinate", Rig)`.
- **`UIHandler`:** add `"TakedownUI"` to the start list, after `"StealthUI"`.
- **`CombatModeUI`** (`CombatModeUI.lua:66-73`): count a shown prompt only when `Prompt.KeyboardKeyCode == Enum.KeyCode.E` (the shown / hidden handlers receive the prompt). Comment: a takedown prompt on N must not stop E (spec A8).
- **`Settings`:** `Reserved` gains `N = true`, with the comment "takedown (assassinations, 2026-10-25; PROPOSAL: not rebindable yet)". A save that bound N falls back through `Settings.Resolve`, unchanged.

**`client_checks.lua`** (a TEMP LocalScript, or rbxc Client; it requires nothing it changes besides reading `TakedownUI`'s prompt from the workspace; the server side is set up by a Server snippet that uses `TakedownKit`):
- `PromptBehindOnly`: a test Grunt at the spot; the player 3 studs behind → a `TakedownPrompt` exists under its root within 0.5 s; moved to 3 studs in front → gone within 0.5 s.
- `PromptStateWord`: its `ObjectText` ends "(unaware)"; after the server sends the Grunt Suspicious → "(suspicious)".
- `PromptHidesOnAlert`: after `PerceptionService.Alarm(Rig, Player)` (Server) → gone within 0.5 s.
- `PromptCalmOnly`: Combat Mode on → gone; off → back.
- `TapKnocksOut`: `Prompt:InputHoldBegin()`, 0.1 s, `InputHoldEnd()` → the character's `LastTakedownResult` becomes `"Knockout:ok"` within `KnockoutTime + 1` s.
- `HoldAssassinates`: on a fresh Grunt, `InputHoldBegin()`, wait `HoldToKill + 0.2`, `InputHoldEnd()` → `"Assassinate:ok"`.
- `EStillDraws`: with the prompt showing, a real E press (rbxc `user_keyboard_input`) → `CombatMode` becomes true. Then E again to put it back.
- `NReserved` (Server, pure): `Settings.IsBindableKey("N")` is false.

**Steps:**
- [ ] **Step 1:** `--check` both places.
- [ ] **Step 2: RED.** Run `client_checks.lua` in Ye Play (`Ye:assn10`): all fail (no prompt; E is blocked when a prompt shows, so `EStillDraws` is tested with a TEMP E-less prompt the script makes and removes, and must fail today); `NReserved` fails.
- [ ] **Step 3:** Make the changes. Sync `UI.TakedownUI`, `SPScripts.UIHandler`, `UI.CombatModeUI`, `Rensei.Settings` to both places.
- [ ] **Step 4: GREEN** in Ye Play: every client check passes. Take one `screen_capture` of the prompt behind a Grunt for the controller (evidence only, not committed). The gun plan's `client_checks.lua` and the swim plan's client checks still pass.
- [ ] **Step 5:** `--check` both places.
- [ ] **Step 6: Commit** the five files and `sync_manifest.json`: `"Assassinations Task 10: the takedown prompt (tap N: knock out, hold N: kill; touch tap / hold); E no longer blocked by other prompts; N reserved"`.

---

### Task 11: Foundry parity and the full sweep

**Files:** none new. This task fixes only what it finds, in the task that owns it (the controller rules).

**Steps:**
- [ ] **Step 1:** `sync.py --place ye --check` and `--place foundry --check`: `DIFFER 0 / MISSING 0` for both, every pair (the Foundry, gun and swim plans' included). `anim_slots.lua` `check` in both places: `FAIL 0`.
- [ ] **Step 2: Play in Ye** (`Ye:assn11`), in this order:
  - `Test_Takedown`, `Test_Sound`, `Test_Perception`;
  - `Play_Takedown`;
  - the regressions: `Play_Stealth`, `Play_Perception`, `Play_Morality`, `Play_Heat`, `Play_Rumours`, `Play_TownsfolkHurt`, `Play_LindenmoorSmoke`, and the gun and swim plans' Play suites;
  - then `client_checks.lua`.

  Record every result, and the deed and EXP probes.
- [ ] **Step 3: Play in Foundry** (`Foundry:assn11`, with Ye in Edit):
  - `Play_Boot` first (it must lead: the Foundry plan's note);
  - then `Test_Takedown`, `Play_Takedown` (its spot is Foundry's survey spot; `TownsfolkRefused` uses a Foundry townsperson);
  - the Foundry plan's final smoke suite by its name, and `Play_Stealth`;
  - then `client_checks.lua`.

  The known failures (Play_Travel 5/2 and Play_RideEvents 8/1 on the owner's ticket) aren't regressions.
- [ ] **Step 4: A real walk-through in Ye** (Play, the protocol): with real input only (`user_keyboard_input`), crouch up behind a world Grunt you reached unseen (Unaware), hold N → it dies quietly; another, tap N → knocked out; V carries it. Report what happened and one capture. If no Grunt can be reached unseen from the spawn, say so: that is a finding, not a failure to hide.
- [ ] **Step 5: The checkpoint list for Task 12.** Write the package contents:
  - **`Modules`:** `Rensei.Takedown`, `Rensei.Perception`, `Rensei.Deeds`, `Rensei.Settings`, `DownedManager`, `TakedownUI`, `CombatModeUI`;
  - **`RenseiServer`:** `TakedownService`, `PerceptionService`, `EnemyService`, `ServerHandler`, `Requests.Takedown`;
  - **`Assets`:** `Animations.Shared.Takedown`;
  - **place changes in both:** `UIHandler` (StarterPlayerScripts) and the RenseiTests suites;
  - **plus** whether the Tutorial place carries `Modules` (the gun plan's Task 1 answered this): if it does, the Tutorial gets `TakedownUI` unused and N reserved, and nothing else changes there.
- [ ] **Step 6:** No commit unless something was fixed. Any fix is committed with its owning task's files, with the message `"Assassinations Task 11: <what>"`.

---

### Task 12: Docs, the Changelog entry and the held Discord post

**Files:** modify `Documents/Changelog.md`, `Documents/Controls.md`, `Documents/Animations.md`, `Documents/COMBAT_SYSTEM.md`, `Documents/Backlog.md`, `Scripts/README.md`.

**Interfaces.** The content each document must hold. Facts and counts come from Tasks 1–11's reports.

**`Controls.md`:**
- A new section after "Downed and knocked targets", **"Takedowns (PvE only)"**:

  | Key | Action |
  |---|---|
  | N (tap) | Knock out an enemy from behind (it hasn't caught you; you're in Calm) |
  | N (hold) | Assassinate it. Elites: a backstab instead |

- The touch table gains **Takedown → tap or hold the prompt over the enemy**.

**`Animations.md`:** a "Takedowns" table:

| Sheet | Game name | Status | Used by |
|---|---|---|---|
| Assassination (83505608395055) | `Misc_Assassinate`, now in `Shared.Takedown` | ✅ (moved from Registry) | assassinate; Elite backstab |
| Assassination Victim (owner, 2026-10-25: 132728216355683) | `Misc_AssassinateVictim` | ➖ | the victim; falls back to `Gripped` |
| Chokehold (**needs the owner's upload**) | `Takedown_Choke` (empty) | ➖ | knock out; falls back to `Fist_BearHug` |
| Chokehold Victim (**needs the owner's upload**) | `Takedown_ChokeVictim` (empty) | ➖ | the victim; falls back to `Fist_BearHugVictim` |
| Bear Hug / Victim (skill sheet) | `Fist_BearHug` / `Fist_BearHugVictim`, now in `Shared.Takedown` | ✅ | the stand-in choke |

and the Misc row's "Assassination victim: no id" note points at it.

**`COMBAT_SYSTEM.md`:** a short "Takedowns (PvE only)" section: the gates, the two kinds, the times, the sounds, bodies, Elites and bosses, the cooldown, every number marked PROPOSAL.

**`Backlog.md`:**
- Item 1 of "After the swimming revamp" and the two "Stealth and identity" items are ticked, with a pointer to the Changelog entry and "**three animations waiting for the owner's upload**".
- **Follow-ups:** carry dead bodies; a rebindable takedown key; drop takedowns (needs animations); townsfolk reacting to a takedown they saw; review the spec's §16 decisions.

**`Scripts/README.md`:** rows for the new scripts (`Rensei/Takedown`, `TakedownService`, `Requests/Takedown`, `UI/TakedownUI`) with the date.

**`Changelog.md`:** one entry, `## <date> — Assassinations: stealth takedowns, PvE only (not live)`. It holds:
- what existed and what was missing (the spec's A1–A15, one line each);
- what changed (gates, the two kinds, witnesses, sounds, bodies, waking up, Elites and bosses, cooldown, the prompt, touch, anti-exploit, PvE only);
- the owner's rules kept (PvE only, existing UI only, no invented ids);
- **"Decisions taken without the owner"** (the spec's §16 list, short);
- **"Owner action":** upload the Assassination Victim, the Chokehold and the Chokehold Victim; add them to the sheet; paste each id into its slot (`Misc_AssassinateVictim`, `Takedown_Choke`, `Takedown_ChokeVictim`);
- every test count from Tasks 2–11;
- "Not tested": a phone, and two real players taking down the same enemy;
- the backups `RenseiBackups["Pre-Assassinations_2026-10-25"]` in both places;
- **the rollback order** (Edit):
  1. revert the scripts from that backup in both places, for this plan's labels;
  2. delete the scripts this plan created (`Rensei.Takedown`, `TakedownService`, `Requests.Takedown`, `TakedownUI`, `TakedownKit`, `Test_Takedown`, `Play_Takedown`) in both places;
  3. `anim_slots.lua` undo in both places;
- **the publish checkpoint** (Task 11, step 5), in the World Travel.md §10 order:
  1. packages from Ye;
  2. Foundry's packages updated by hand and checked with `sync.py --check`;
  3. the places;
  4. Migrate to Latest Update last.

  It may be published only together with whatever hold is then in force.

**Its `### Discord announcement`:**
- It starts "Hold: not live yet. Post this when the owner publishes the assassinations update."
- Then a ```md block, under 2,000 characters, plain and player-facing, with no file names, test numbers or PROPOSAL tags. It covers:
  - sneak up behind an enemy who hasn't spotted you and a prompt appears;
  - tap N to knock them out, hold N to take them out for good (on touch, tap or hold the prompt);
  - it only works from behind, out of combat, and before they're on to you; the prompt shows whether they're unaware or suspicious;
  - knocked-out enemies wake up later and raise the alarm, so carry them somewhere dark or deal with them;
  - bodies left in the open get found, faster in the light, and their friends come looking;
  - anyone who sees you do it remembers it;
  - tougher enemies only take a heavy backstab, and bosses can't be assassinated;
  - only enemies can be taken down. Never other players.

**Steps:**
- [ ] **Step 1:** Write the docs. Every number comes from a task report or `Rensei.Takedown` as committed.
- [ ] **Step 2:** Check that the Discord block is under 2,000 characters (count it with `python -I -c`), and that it has no file names, test counts or PROPOSAL.
- [ ] **Step 3:** This is the plan's only Changelog entry.
- [ ] **Step 4:** The controller names the checkpoint and the owner action (the three uploads) to the owner in chat. This plan publishes nothing.
- [ ] **Step 5: Commit** the six docs: `"Assassinations Task 12: docs, changelog (held Discord post), three animation uploads asked of the owner"`.

---

## Self-review notes

**Coverage of the request:**
1. **"Assassinations that work with the detection system (sight, light, sound)":**
   - sight: the gates read the enemy's phase and per-player awareness (Task 7), the rear arc sits inside the blind zone (Task 2), witnesses use the sight rules (Task 4), bodies are found by sight (Task 5);
   - light: bodies in the dark are found slower (Task 5); crouching and shadow get you there;
   - sound: the two new sounds (Task 4); the kill skips the loud hit path (Task 7);
   - "I threw anims in the spreadsheet": the sheet's one assassination row is used and the missing victim is a named slot (Tasks 1, 3).
2. **Lethal and knockout** (the stealth design wants both): Tasks 7–8.
3. **PvE only:** the first check (Task 2), a test (Task 7), the client never offers it (Task 10), no NPC has a takedown.
4. **Elites and bosses, cooldown, touch, anti-exploit, tests, decisions:** Tasks 9, 7, 10, 7, every task, the table above.

**Rules kept:**
- existing UI assets only (PromptUI draws the prompt);
- no invented asset id (the sheet's one id; three empty slots);
- no publishing;
- one Changelog entry with a held, player-facing post;
- RED before GREEN in every task, with a control wherever a check could pass by construction (Tasks 4, 5, 6, 9);
- commit by path with the trailer.

**Order and dependencies:**
- 1 before everything;
- 2 before 7–10 (`Rensei.Takedown`);
- 3 before 7 (the slots it plays) and 10;
- 4 before 5 (`Raise`), 7 (`Glimpse`, the skip, the kit);
- 5 before 7 (bodies, the corpse time);
- 6 before 7 (the deed) and 8 (`Knock` length);
- 7 before 8, 9 and 10;
- 11 after 1–10; 12 last.

Play sessions are serial across the places. `anim_slots.lua` runs in Edit only.

**Each task can be rejected on its own:**
- Tasks 1–6 change nothing a player can see: 1 is parity and a survey; 2 is an unused module; 3 adds slots nothing plays; 4's and 5's new paths need a rig marked by Task 7; 6's knock length is optional and the deed unused.
- Task 7 is the server takedown (assassinate only). Without Task 10 no player can reach it except through a hand-made request.
- Task 8 (knock out) and Task 9 (Elites, bosses, hooks) each add one branch to `Run`; reverting either leaves its kind refused as `"todo"`.
- Task 10 is client-only, plus two small fixes (the E prompt rule, N reserved) that stand on their own.

**Names used across tasks:**
- the backup `Pre-Assassinations_2026-10-25`, the PlayLock label `assn<task>`;
- the flag `TakedownAnimSlots`, the marks `TakedownAdd` and `TakedownFrom`;
- the attributes `TakenDownBy`, `TakingDown`, `KnockedOutBy`, `TakedownReadyAt`, `LastTakedownResult`, `TakedownClass`;
- `Rensei.Takedown` (`Behind`, `ClassOf`, `Check`, `IsHidden`, `Anims`);
- `PerceptionService.Glimpse`, `.Raise`, `.AddBody`, `.RemoveBody`, `.Bodies`, `.BodyFound`;
- `TakedownService.Request`, `.Check`, `.Context`, `.Done`, `.Failed`;
- the request `"Takedown"`, the prompt `TakedownPrompt`;
- the sounds `Choke` and `Takedown`; the deed `assassinated_bandit`;
- `RenseiTests.TakedownKit`, `Test_Takedown`, `Play_Takedown`.

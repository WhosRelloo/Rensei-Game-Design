# Gun Rework Implementation Plan

> **Owner update (2026-10-25):** the gun reload animation id is **97563934064498**, supplied by the owner. Task 1 checks it read-only, Task 3 sets `AnimLength` to its measured length, and Task 7 writes it into the `Guns_Reload` slot. The slot is empty only if Task 1 finds the id unloadable.

> **Pre-flight amendment (2026-10-25):** this text builds in the controller's Rulings 1 and 2 on the pre-flight scan's 14 findings. The ledger is `.superpowers/sdd/2026-10-25-gun-rework/progress.md`.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Every implementer gets the **Global Constraints** and the **Facts** below together with its own task.

**Goal:** Fix guns' shooting-mode aiming, rebalance the gun class, and play the owner's reload animation on the automatic reload. That means:
- the shot goes where the crosshair is (parallax, shift lock and lock-on);
- no fire-straight-ahead fallback;
- bounded lag compensation;
- hold to fire;
- the PROPOSAL balance table;
- the `Guns_Reload` slot, with an interrupt rule and a top-up;
- hit and recoil feedback using only existing UI assets;
- touch fire and assist;
- fair enemy gunners.

**Spec:** `Documents/specs/2026-10-25-gun-rework-design.md`. Every number in it, and here, is **PROPOSAL** unless it quotes an owner decision. Its §8 lists the decisions taken without the owner, and its §9 lists the Studio checks that Task 1 answers.

**When to start (owner gates):**
- **Task 1 can run now.** It's a read-only survey of both places plus additions to the sync tool, the manifest and the repo. It writes nothing into either place.
- **Task 2 waits for the owner (Ruling 2).** Task 2 is the first change to a shared package (`Modules`). It waits until the owner has either:
  - run the joint Ye + Foundry publish and saved both places; or
  - agreed in chat to fold the gun work into that same checkpoint.

  Until then, any gun code synced into Ye's or Foundry's unsaved Edit session would ship with the held Lindenmoor and Foundry publish. The controller records the owner's answer in the ledger before dispatching Task 2.
- **Task 3 also waits** until the controller has confirmed the owner has seen the spec (`Documents/CLAUDE.md` asks for approval before scripts are rewritten). Task 3 changes the gun numbers, and **once synced, that changes live balance** at the next publish. Task 2 alone changes no behaviour: `GunAim` is unused until Task 5.
- **The swim plan** (`2026-10-25-swimming-revamp.md`) edits some of the same files: `TuningConfig`, `MobileControls`, `SettingsUI` and the sync tool. Whichever plan runs second:
  - starts each task by running `sync.py --check` in both places;
  - edits the repo file, which holds both plans' changes, then syncs it;
  - never syncs an older copy over the other plan's work.

**Architecture:** Five stages:
1. **Survey and tooling** (Task 1).
2. **Pure maths and data** (Tasks 2–3): `Rensei.GunAim` and the TuningConfig numbers, tested in the Play VM.
3. **The test kits** (Task 4), shared, not copied.
4. **The server** (Tasks 5–7, then 11):
   - the shot path;
   - lag compensation;
   - the reload;
   - enemy gunners.
5. **The client and the close** (Tasks 8–10, then 12–13):
   - the aim camera and crosshair, hold to fire, feedback, touch;
   - the sweep in both places;
   - the docs.

Nothing here publishes.

**Tech Stack:**
- Roblox Studio Luau, through `Art/Tools/rbxc.py`.
- Python 3.14 (stdlib only), for the sync tool and its test.

---

## Facts (read from the repo, 2026-10-25; Task 1 confirms them in Studio)

**Places and windows.**
- **Ye:** placeId 106992859583940, window "[CLOSED TESTING] Rensei".
- **Foundry:** placeId 109591196441030, window "Foundry Yard".
- Get each window's `studio_id` from `python -I Art/Tools/rbxc.py studios`.

**The sync manifest** (`Art/Studio/Regions/Foundry/data/sync_manifest.json`) has 59 pairs: 50 for Ye and 54 for Foundry. `test_sync.py` pins those counts (lines 98–99).

**`sync.py` today:**
- `BACKUP = "Pre-FoundryData_2026-10-24"` is a module constant, used by `bundle_text` (line 192).
- `do_check` calls `repo_bytes(p)` for every pair (line 271), so a pair whose Repo file doesn't exist yet crashes `--check`.

**The scripts this plan touches.** The repo path is given first, then the expected Studio path; Task 1 confirms each.

| Label | Repo | Studio | In repo? | In the manifest? |
|---|---|---|---|---|
| `Rensei.TuningConfig` | `Scripts/ReplicatedStorage/Modules/Data/Rensei/TuningConfig.lua` | `ReplicatedStorage/Modules/Data/Rensei/TuningConfig` | yes | no (the swim plan may add it) |
| `Rensei.GunAim` | `.../Data/Rensei/GunAim.lua` | `ReplicatedStorage/Modules/Data/Rensei/GunAim` | new (Task 2) | no |
| `Managers.WeaponManager`, `Managers.AttackRunner`, `Managers.DamageManager`, `Managers.AnimationManager` | `Scripts/ReplicatedStorage/Modules/Managers/<X>.lua` | `ReplicatedStorage/Modules/Managers/<X>` | yes | no |
| `Managers.SkillMods` | `.../Managers/SkillMods.lua` | `ReplicatedStorage/Modules/Managers/SkillMods` | **export** | no |
| `UI.HUDUI`, `UI.SettingsUI`, `UI.MobileControls` | `Scripts/ReplicatedStorage/Modules/UI/<X>.lua` | `ReplicatedStorage/Modules/UI/<X>` | yes | no (the swim plan may add two) |
| `UI.LockOn`, `UI.CooldownUI` | `.../UI/<X>.lua` | found by Task 1 | **export** | no |
| `UI.GunAimUI` | `.../UI/GunAimUI.lua` | `ReplicatedStorage/Modules/UI/GunAimUI` | new (Task 8) | no |
| `Requests.Shoot` | `Scripts/ServerScriptService/ServerHandler/Requests/Shoot.lua` | `ServerStorage/RenseiServer/ServerHandler/Requests/Shoot` | yes | no |
| `Requests.WeaponSkill`, and `Requests.Aim` if it exists | `.../Requests/<X>.lua` | `ServerStorage/RenseiServer/ServerHandler/Requests/<X>` | **export** | no |
| `RenseiServer.ServerHandler`, `RenseiServer.EnemyService` | `Scripts/ServerScriptService/<X>` | `ServerStorage/RenseiServer/<X>` | yes | **yes** |
| `RenseiServer.PositionHistory` | `Scripts/ServerScriptService/PositionHistory.lua` | `ServerStorage/RenseiServer/PositionHistory` | new (Task 6) | no |
| `SPScripts.ClientHandler` | `Scripts/StarterPlayer/StarterPlayerScripts/ClientHandler.client.lua` | `StarterPlayer/StarterPlayerScripts/ClientHandler` (LocalScript, a package; children Controls, Roll, Run, Crouch stay) | yes | no |
| `RenseiTests.SmokeKit` | `Scripts/ServerStorage/RenseiTests/SmokeKit.lua` | `ServerStorage/RenseiTests/SmokeKit` | yes | **yes** |
| `RenseiTests.Play_Stealth` | `.../RenseiTests/Play_Stealth.lua` | `ServerStorage/RenseiTests/Play_Stealth` | yes | no (Ye; Foundry per Task 1) |
| `RenseiTests.GunKit`, `Play_GunKit`, `Test_GunAim`, `Test_GunBalance`, `Play_Guns`, `Play_GunReload`, `Play_GunNpc` | `.../RenseiTests/<X>.lua` | `ServerStorage/RenseiTests/<X>` | new | no |

**What the code does today** (the spec's §§1–3 have the line numbers):
- the shot fires from `Root + (0, 1.5, 0)` along the camera's look;
- the server cone falls back to straight ahead;
- there's no rewind;
- one shot per press;
- NPCs never call `SetAim`;
- `Resolve` scales Fan the Hammer against the whip's damage;
- Mastery deepens falloff;
- the whiff penalty applies to shots (`AttackRunner.lua:292`);
- shots give 4 meter and flinch at any range;
- shooting mode survives water (`Shoot.lua:43` doesn't watch `Traversal`).

**Combat-ready rigs:**
- `DamageManager` returns "IFramed" for a victim with no WCS character (`DamageManager.lua:118`).
- `EnemyService.Spawn` makes a rig fight-ready with `WCS.Character.new`, `SetDefaultProps` and `BlockManager.Initiate(Rig)` (`EnemyService.lua:458-462`).

**Request limits:**
- `ServerHandler` passes every request through one shared token bucket per player, `Limiter(8, 16)` (`ServerHandler.server.lua:32-52`), before the request's own module.
- A Fire request that floods it also drops the Y mode request.

**Animations:**
- `AnimationManager` preloads everything in `Assets.Animations.Shared` and `.Weapons` on the client. It skips an `Animation` whose id is empty and that has no `Save`.
- On the server, `Play` on a player sends a remote to that player's client.
- The reload code asks to play `Guns_Reload` only when the slot's id isn't empty.

**The existing kits** (reuse them; never copy their logic):
- **`RenseiTests.TestKit`:** `Run`, `T.Eq` / `Near` / `True` / `Same`, `TestKit.Beside`.
- **`RenseiTests.SmokeKit`:** `Copy`, `PutBack`, `Stand`, `Ask`, `WithRoot`, `EnemiesStandInTheWorld`.
- **`RenseiTests.PathKit`:** `Params`, `Clearance`, and the path measures.

---

## Global Constraints

**Owner rules:**
- "Do not publish the Roblox game or modify live player data."
- "Do not expose API keys, credentials, private player data, or other secrets."
- "Do not blindly copy another game's code or assets."
- **UI:** use only the game's existing UI assets. The crosshair is the existing `Gui.Crosshair` marker. The hint and the touch buttons are the existing HUD text and MobileControls buttons. No new images, fonts or sounds.
- **Owner decisions kept:**
  - "Guns: no reload button, automatic only";
  - "M1 with a gun is a melee pistol whip and never fires a bullet";
  - Y toggles shooting mode and RMB fires while it's on.
- **The reload animation is the owner's id 97563934064498.** No other asset id is invented. The only stand-in is in Play, where the slot's id is blanked for the empty-slot case.

**Labels and records:**
- Label every invented number **PROPOSAL** in code comments and docs.
- No task writes a Changelog entry except Task 13, which writes one entry for the whole plan.
- Implementers report to the controller in their final message.
- Implementers never dispatch subagents and never write under `.superpowers/`.

**Studio bridge:**
- Run Luau with `python -I C:/Users/Owner/Rensei-Game-Design/Art/Tools/rbxc.py luau "placeId: <id>" <Edit|Server> @file.lua`.
  - Only the first return value prints, cut at 30,000 characters.
  - For a longer return, write it to a StringValue in ServerStorage, read it back in 25,000-character chunks, and delete it.
- **Studio state:** `rbxc.py call get_studio_state '{"studio_id":"<id>"}'`.
- **Play:** `rbxc.py call start_stop_play '{"is_start":true|false,"studio_id":"<id>"}'`.
- **Foundry quirk:** rbxc sometimes returns "Target is not reachable (DMN_ID_EDIT)" even though the call ran. Before retrying anything that isn't idempotent, read the state the call would have changed.
- Never touch the Studio window "bloodydeadpool53's Place".
- Put scratch files in `C:/Users/Owner/AppData/Local/Temp/claude/C--Users-Owner/ecd4cd55-01de-4070-9638-cb228809b769/scratchpad/gun-plan/`.

**Play** is hooked and protected, because Play writes the owner's REAL save. **Every Play session follows this protocol**, Task 1's and Task 10's included.

- **One Play session at a time across Ye and Foundry.** Before Play:
  - `get_studio_state` must show the **other** place in Edit;
  - Ye's `game.ServerStorage:GetAttribute("PlayLock")` must be nil.
- **The order, every session:**
  1. **Lock.** In Ye (Edit), `game.ServerStorage:SetAttribute("PlayLock", "<Ye|Foundry>:gun<task>")`. When playing Foundry, set the same attribute in Foundry too.
  2. **Hook.** In the playing place (Edit), run `C:/Users/Owner/.claude/jobs/0c39df78/tmp/blender/hook.lua`. Then install the dump helper: `rbxc.py luau "placeId: <id>" Edit @Art/Studio/Regions/Foundry/data/dumphelper.lua`. It returns "dump helper installed".
  3. **Start Play.** In the Server data model, wait until `game.ServerStorage:GetAttribute("LMSnapTaken")` is set. Then take the dump: `return game.ServerStorage:WaitForChild("LMQuestDump", 30):Invoke()`. Save it as `quests_gun<task>_1.txt`.
  4. **Check for a held Tool.** Before any suite, check that the player's character holds **no Tool** (`Character:FindFirstChildOfClass("Tool") == nil`).
     - `WeaponManager.Give` destroys every Tool in the character, so a held weapon or hotbar item would be destroyed.
     - If one is held, stop and report: never unequip it by script.
  5. **Suites.** Run them with `game.ServerStorage.LMRunSuite:Invoke("<Suite>")` (Server).
  6. **Restore.** Run `game.ServerStorage.LMTestHook:Invoke("restore")` (Server). It must return "restored".
     - Dump again (`quests_gun<task>_2.txt`). It must equal the first dump character for character.
     - `LMTestHook:Invoke("diff")` may list only the known encode-quirk keys (Settings, Story, Morality). **Any other key** means stop: keep Play running and report both dumps and the diff to the controller.
  7. **Stop** Play.
  8. **Unhook.** In Edit:
     - run `C:/Users/Owner/.claude/jobs/0c39df78/tmp/blender/unhook.lua`;
     - remove the dump helper: copy `dumphelper.lua` to the scratch folder, set its MODE line to `"remove"` there, and run the copy. It returns "removed <n>";
     - search the place's `StarterGui`, `StarterPlayer` and `ReplicatedStorage` for any instance named `GunChecks_TEMP` and destroy it. Report the count, which is expected to be 0: the client checks are made in Play and vanish at Stop.
  9. **Unlock.** Only then, clear PlayLock in both places.
- **Guns in tests:**
  - Test shooters are **NPC rigs** made with `RenseiTests.GunKit`.
  - The player's character gets a gun only through `WeaponManager.Give` in Play, after step 4's check, never through LoadoutService or the inventory.
- **Script edits are refused while Play runs.**
- **In Play, the world is a copy.** Instance changes made in Play vanish at Stop: dummies, blanking the slot's id, the TEMP client checker. Save data is real: the hook's restore puts it back.
- **Edit's require cache.** Edit keeps a module's result between `execute_luau` calls. Every suite here runs **in the Play VM** (`LMRunSuite`). Edit runs are only for the read-only survey and `reload_slot.lua`, which require no changed module.

**Scripts live in both places.**
- **The order:** every script is edited in the repo first, then set into **both** places with the sync tool, always with this plan's backup name:
  ```
  python -I Art/Studio/Regions/Foundry/data/sync.py --place ye|foundry --backup Pre-GunRework_2026-10-25 --only <label>[,<label>...] --run
  python -I Art/Studio/Regions/Foundry/data/sync.py --place ye|foundry --check
  ```
- **Start and end of every task:** `--check` in both places. At the start it shows what another plan may have changed (the swim-plan rule in the header). At the end it must print `DIFFER 0 / MISSING 0` for **both** places, for every task that touched a script.
- **Manifest rules for every task:**
  - add a pair only after its Repo file exists;
  - skip any label already present: the swim plan adds `Rensei.TuningConfig`, `UI.MobileControls` and `UI.SettingsUI`;
  - after adding, set `test_sync.py`'s pinned counts (`pair count ye` / `pair count foundry`) to the manifest's new counts, and say in the report what they were before;
  - rerun `test_sync.py`: it must be green.
- **Backups:** `--backup Pre-GunRework_2026-10-25` clones a script once, into `ServerStorage.RenseiBackups["Pre-GunRework_2026-10-25"]`, before its first change in this plan. **Never sync this plan's scripts without `--backup`.** The default folder holds older copies, so an undo from it would drop the Foundry plan's work. A created script gets no backup and carries `FoundryDataAdd = true`, the tool's existing mark.
- **The normalised hash** is the one in the Foundry plan's Global Constraints (`NormHash` / `norm_hash`).
- **Packages:** `Modules`, `RenseiServer` and `ClientHandler` are packages. Syncing changes both places' package copies; publishing them is the owner's (Task 13's checkpoint).

**Reversible Studio scripts** (only the reload slot, Task 7) follow the Foundry plan's contract:
- `local MODE = "plan"`, with the modes plan / apply / undo / check / test;
- refusals while Play runs or PlayLock is set;
- a pcall journal;
- one ChangeHistoryService recording;
- the mark `GunReworkAdd = true`;
- `check` written as failure conditions only, against constants in the script, never against values it reads from the thing it checks.

**Tests:**
- **RED then GREEN.** Every new check is run once where it **must fail** (before the change, or against a control that keeps today's rule), and fails. Then it passes after. Each task lists, per case, whether it is RED today or a guard that already passes, and why.
- **A check that cannot fail is not a check.**
  - Never choose a test spot or input by reading the property under test.
  - Expected numbers are worked by hand in the test, as constants.
  - A case that can't fail on its own is paired with a positive control that must.
- **No duplicated logic.** Shared helpers live in one module and are required:
  - TestKit (`Run`, `Beside`);
  - SmokeKit (`Copy` / `PutBack` / `WithRoot` / `Stand`, and from Task 4 `TempPart` / `ClearTemp` / `Guarded`);
  - PathKit (`Clearance`);
  - **`GunKit`** (Task 4), for gun suites.

  In game code, the shot candidates are `GunAim.Candidates`, the fight-ready rig setup is `EnemyService.MakeCombatant`, the shift-lock camera is `SettingsUI.CameraLock` / `CameraFree`, the touch test is `MobileControls.Active`, and the lock-on root is `GunAimUI.LockedRoot`, which ClientHandler's `AlchemyAim` also uses.
- When a check fails, fix the cause in the task that owns it (the controller rules), never by loosening the check.

**Git:**
- Commit by path only: `git commit -m "<msg>" -- <paths>`. Never `git add -A`.
- Never stage `.blend` or `.blend1` files or `Art/Blender.rar`.
- End every commit message with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Implementers don't push.

---

## File map

| File | Responsibility | Task |
|---|---|---|
| `Art/Studio/Regions/Foundry/data/sync.py`, `test_sync.py`, `sync_manifest.json` | `--backup` (keyword), `--check` with a missing Repo file, the gun pairs | 1 (pairs added in every task) |
| `Art/Studio/Guns/survey_guns.lua`, `survey_ye.json`, `survey_foundry.json` (new) | The read-only survey, including the reload id and the test spots | 1 |
| Exported: `UI/LockOn.lua`, CooldownUI, `Managers/SkillMods.lua`, `Requests/WeaponSkill.lua`, `Requests/Aim.lua` (if it exists); `Scripts/README.md` | Parity | 1 |
| `Rensei/GunAim.lua`, `RenseiTests/Test_GunAim.lua` (new) | The pure maths, `Candidates`, `Limiter` | 2 |
| `Rensei/TuningConfig.lua`, `Managers/WeaponManager.lua` (`Resolve`, `DamageMult`), `RenseiTests/Test_GunBalance.lua` (new) | The numbers | 3 |
| `ServerScriptService/EnemyService.lua` (`MakeCombatant`), `RenseiTests/SmokeKit.lua`, `Play_Stealth.lua`, `GunKit.lua`, `Play_GunKit.lua` (new) | The test kits | 4 |
| `Managers/WeaponManager.lua`, `Requests/Shoot.lua`, `RenseiTests/Play_Guns.lua` (new) | The server shot path | 5 |
| `ServerScriptService/PositionHistory.lua` (new), `ServerHandler.server.lua`, `Play_Guns.lua` | Lag compensation | 6 |
| `Art/Studio/Guns/reload_slot.lua` (new), `WeaponManager.lua`, `RenseiTests/Play_GunReload.lua` (new) | The reload | 7 |
| `UI/SettingsUI.lua`, `UI/GunAimUI.lua` (new), `ClientHandler.client.lua`, `UI/HUDUI.lua`, `Art/Studio/Guns/client_checks.lua` (new) | Client aim, hold to fire | 8 |
| `UI/GunAimUI.lua`, `client_checks.lua` | Feedback | 9 |
| `UI/GunAimUI.lua`, `UI/MobileControls.lua`, `UI/HUDUI.lua`, `client_checks.lua` | Touch | 10 |
| `ServerScriptService/EnemyService.lua` (`GunShot`), `RenseiTests/Play_GunNpc.lua` (new) | Enemy gunners | 11 |
| (no new files) | The sweep in both places | 12 |
| `Documents/Changelog.md`, `COMBAT_SYSTEM.md`, `Controls.md`, `Animations.md`, `Backlog.md` | Docs | 13 |

All `Rensei/` paths are `Scripts/ReplicatedStorage/Modules/Data/Rensei/`. `Managers/` and `UI/` are under `Scripts/ReplicatedStorage/Modules/`. `RenseiTests/` is `Scripts/ServerStorage/RenseiTests/`. `Requests/` is `Scripts/ServerScriptService/ServerHandler/Requests/`.

---

### Task 1: The survey, the sync tool, and parity

**Runs now:** it writes nothing into Ye or Foundry, apart from one hooked Play session that changes nothing.

**Files:**
- **Modify:**
  - `Art/Studio/Regions/Foundry/data/sync.py`;
  - `test_sync.py`;
  - `sync_manifest.json`;
  - `Scripts/README.md`.
- **Create:**
  - `Art/Studio/Guns/survey_guns.lua`, `survey_ye.json`, `survey_foundry.json`;
  - the exports (read-only from Ye): `Scripts/ReplicatedStorage/Modules/UI/LockOn.lua`, CooldownUI at its found path, `Scripts/ReplicatedStorage/Modules/Managers/SkillMods.lua`, `Scripts/ServerScriptService/ServerHandler/Requests/WeaponSkill.lua`, and `Requests/Aim.lua` if it exists.

**Interfaces:**

**`sync.py`** (skip any part the swim plan has already added; say so in the report):
- **`--backup NAME`:**
  - optional;
  - NAME must match `^Pre-[A-Za-z0-9]+_\d{4}-\d{2}-\d{2}$` (the swim plan's check), else exit 2 with "bad --backup name";
  - passed as the keyword `backup=` to `bundle_text(pair, date=None, backup=BACKUP)` and `write_bundle(pair, out_dir, date=None, backup=BACKUP)`;
  - the default stays `BACKUP` (`Pre-FoundryData_2026-10-24`), so every existing call produces the same bytes.
- **`do_check` with a missing Repo file:** a pair whose Repo file doesn't exist prints `<Label> MISSING (no repo file)` and counts as MISSING, instead of crashing in `repo_bytes`. The Studio side is still asked.

**`test_sync.py`**, new cases:
- `--backup Pre-GunRework_2026-10-25` appears on a generated bundle's `BACKUP` line;
- without it, the line says `Pre-FoundryData_2026-10-24`;
- `--backup Gun` is rejected;
- `do_check` with a stub runner and a fixture manifest whose Repo file is absent prints `MISSING (no repo file)` and returns 1, without raising;
- the pinned pair counts are updated to the counts after this task's pairs.

**Manifest pairs** added by this task (all `Places: ["ye", "foundry"]`, `Create: false`, skipping any label present):
- `Rensei.TuningConfig`;
- `Managers.WeaponManager`, `Managers.AttackRunner`, `Managers.DamageManager`, `Managers.AnimationManager`, `Managers.SkillMods`;
- `UI.HUDUI`, `UI.SettingsUI`, `UI.MobileControls`, `UI.LockOn`, `UI.CooldownUI`;
- `Requests.Shoot`, `Requests.WeaponSkill` (and `Requests.Aim` if found);
- `SPScripts.ClientHandler` (LocalScript).

Also `RenseiTests.Play_Stealth`, with Places `["ye"]`, plus `"foundry"` only if the survey finds it there with Ye's hash.

**`survey_guns.lua`** (read-only, `MODE = "survey"`, refuses while Play runs, Edit, both places). It returns one JSON string with:
- **places:** `game.PlaceId` and PlayLock;
- **scripts:** each Studio path in the table above (found or not, NormHash), plus the Studio paths of CooldownUI, the `"Aim"` request handler (or "none") and `Requests.WeaponSkill`. Does WeaponSkill call `WeaponManager.Resolve` for Fan the Hammer, and does Fan need `ShootingMode`?
- **the lock-on camera:** where LockOn puts the camera, whether it sets `AutoRotate` or an attribute while locked, and whether it works on touch at all (from its source);
- **UI:**
  - `StarterGui`'s `Crosshair` marker: its class, `AnchorPoint`, `Position`, `Size`, colour and transparency, and its ScreenGui's `IgnoreGuiInset`;
  - the HUD ScreenGui's `IgnoreGuiInset`;
- **animations:**
  - the children of `Assets.Animations.Weapons` (is there a `Guns` folder?);
  - whether anything named `Guns_Reload` already exists;
  - whether `ReplicatedStorage.Assets` is a package (a `PackageLink`);
- **the reload id 97563934064498, read-only:**
  - `KeyframeSequenceProvider:GetKeyframeSequenceAsync("rbxassetid://97563934064498")`, in a pcall: loads or not, and its **length** (the largest `Keyframe.Time`, to 0.01);
  - `MarketplaceService:GetProductInfo(97563934064498, Enum.InfoType.Asset)`: `Creator.CreatorType`, `CreatorTargetId` and `AssetTypeId`.

  It **can play in this experience** if the creator is the Rensei group (206818864, which owns the game) or the experience's owner. Otherwise record "may not play live".
- **R6 extents:** `game.StarterPlayer.StarterCharacter`'s parts relative to its HumanoidRootPart, as the min and max corner rounded to 0.1. This sets `Aim.HitBox` and `HitBoxOffset` in Task 3. Expected about (−2, −3, −0.5) to (2, 2.2, 0.5).
- **Camera Shake:** where client effects read Settings > Camera Shake (the module and the line).
- **Other places:** whether this place's `Modules` is a package, from its `PackageLink`. The Tutorial question is answered by the controller from the owner's place list, not by opening the Tutorial.
- **The test spot** for the gun suites, per place:
  - a 200 × 200 square on flat ground (ray hits at every 10-stud grid point within 0.5 of one height);
  - nothing within 12 studs above it (`PathKit.Params`-style raycasts up from each grid point);
  - **outside every `RenseiArea` box and at least 120 studs from every `RenseiPost` and `RenseiEnemySpawn`**, so townsfolk and enemies don't wander in.

  Give its centre. Search a grid of candidate centres every 50 studs, and stop at the first that passes. The rules are fixed above; nothing about the suites is read to choose it.

**One hooked Play session in Ye** (`Ye:gun1`, the full protocol) answers the Play-only checks, each read-only:
- **`World.Live`'s layout:** its children by class and name pattern, and the depth at which character Models sit (sets `GunAim.Candidates`).
- **RMB in shooting mode** with shift lock off: give the player a Revolver (`WeaponManager.Give`, after step 4), and set `CombatMode` and `ShootingMode` on the Server.
  - A TEMP LocalScript `GunChecks_TEMP` is made from the Server into `Player.PlayerGui` (never into StarterPlayerScripts). It records `Camera.CFrame` before and after a simulated RMB hold.
  - If input can't be simulated, record "not checked; owner checks by hand".
- **The reload id on a rig:** on a throwaway R6 model cloned from `StarterCharacter` into `World.Live`, `Animator:LoadAnimation` of an `Animation` with the id, then `Play()`. Record `Track.Length` once it's above 0 (wait up to 5 s) and `IsPlaying`. Destroy the model.

**Steps:**
- [ ] **Step 1: Write the `test_sync.py` cases; they fail.** Run them. Expected failures: `--backup` is unknown, and the missing-Repo case raises.
- [ ] **Step 2:** Add `--backup` and the missing-Repo report. Run `test_sync.py`: all pass, the old tests included.
- [ ] **Step 3:** Write `survey_guns.lua`. Run it in **Ye (Edit)**, then in **Foundry (Edit; Ye's PlayLock nil)**. Write `survey_ye.json` and `survey_foundry.json`, pretty-printed and sorted.
- [ ] **Step 4:** Run the Play session above in Ye. Add its answers to `survey_ye.json` under `"Play"`.
- [ ] **Step 5: Export** each Studio-only script's Source to its repo path, byte for byte with CRLF normalised to LF. Add the manifest pairs and update the pinned counts. Rerun `test_sync.py`.
- [ ] **Step 6: Parity.**
  - `sync.py --check` in both places. Expected: `DIFFER 0 / MISSING 0`.
  - If an **existing** repo copy differs from Ye, Studio wins: export Ye's copy over the repo file and list it.
  - If Foundry differs from Ye on a gun pair, report it; the controller rules before any sync.
- [ ] **Step 7: Report.**
  - The reload id's load result, its length, its creator, and "plays live: yes / may not".
  - **If the id doesn't load**, Task 7 writes an empty id, and Task 13 tells the owner it couldn't be loaded.
- [ ] **Step 8:** Add the exported files' rows to `Scripts/README.md`'s table (2026-10-25).
- [ ] **Step 9: Commit** `sync.py`, `test_sync.py`, `sync_manifest.json`, `Scripts/README.md`, `Art/Studio/Guns/survey_guns.lua`, both survey JSONs and the exports: `"Gun rework Task 1: survey (reload id, test spots), sync --backup and missing-repo check, gun scripts in the repo"`.

**— Owner gate (Ruling 2). Task 2 starts only after the owner's answer, recorded by the controller. —**

---

### Task 2: `Rensei.GunAim`: the pure maths of a shot

**Files:**
- **Create:**
  - `Scripts/ReplicatedStorage/Modules/Data/Rensei/GunAim.lua`;
  - `Scripts/ServerStorage/RenseiTests/Test_GunAim.lua`.
- **Manifest:** `Rensei.GunAim` and `RenseiTests.Test_GunAim` (`Create: true`), added once the files exist.

**Interfaces** (the whole module; Instances come in only as arguments):

```lua
-- GunAim (gun rework 2026-10-25): the pure maths of a gunshot, shared by the client (where the crosshair points) and the
-- server (what the shot may hit, how fast it may be asked for). Numbers live in TuningConfig.Weapons.Guns.Aim (PROPOSAL).
-- No Instance is read here except through the arguments.
local GunAim = {}

GunAim.MUZZLE = Vector3.new(0, 1.5, 0) -- the shot leaves from the head: root + this (WeaponManager.Fire's origin since 2026-10-17)

function GunAim.Muzzle(RootPosition)
	return RootPosition + GunAim.MUZZLE
end

local function Finite(V)
	return V.X == V.X and V.Y == V.Y and V.Z == V.Z
		and math.abs(V.X) < math.huge and math.abs(V.Y) < math.huge and math.abs(V.Z) < math.huge
end

-- The characters a shot or the touch assist may pick: Models with a Humanoid that are children of Live, or (unless
-- DirectOnly) children of a Folder directly in Live -- the townsfolk folder. One list for WeaponManager.ShotTarget,
-- PositionHistory and GunAimUI's assist, so they can't drift. (Task 1's survey recorded World.Live's layout; if characters
-- sit deeper, widen this here, once.)
function GunAim.Candidates(Live, DirectOnly)
	local Out = {}
	for _, C in ipairs(Live:GetChildren()) do
		if C:IsA("Model") and C:FindFirstChildOfClass("Humanoid") then
			table.insert(Out, C)
		elseif C:IsA("Folder") and not DirectOnly then
			for _, M in ipairs(C:GetChildren()) do
				if M:IsA("Model") and M:FindFirstChildOfClass("Humanoid") then table.insert(Out, M) end
			end
		end
	end
	return Out
end

-- A token bucket per key: Rate a second, Burst at once. Allow(Key, Now) -> bool; Forget(Key). Now is passed in, so a
-- test drives the clock. (ServerHandler's shared Limiter stays as it is; this one is the Fire request's own.)
function GunAim.Limiter(Rate, Burst)
	local Buckets = {}
	local function Allow(Key, Now)
		local B = Buckets[Key]
		if not B then
			B = {Tokens = Burst, At = Now}
			Buckets[Key] = B
		end
		B.Tokens = math.min(Burst, B.Tokens + (Now - B.At) * Rate)
		B.At = Now
		if B.Tokens < 1 then return false end
		B.Tokens -= 1
		return true
	end
	local function Forget(Key) Buckets[Key] = nil end
	return Allow, Forget
end

-- Where the crosshair points: the first thing the camera ray meets past the shooter. Cast(From, Vector) -> a hit position
-- or nil (the caller's raycast and filter). The ray starts level with the muzzle, so nothing between the camera and the
-- shooter counts.
function GunAim.AimPoint(CamOrigin, CamDir, Muzzle, Range, Cast)
	CamDir = CamDir.Unit
	local Skip = math.max(0, (Muzzle - CamOrigin):Dot(CamDir))
	local From = CamOrigin + CamDir * Skip
	local Hit = Cast and Cast(From, CamDir * Range)
	return Hit or (From + CamDir * Range)
end

-- The shot's direction: from the muzzle to the aim point. An aim point nearer than MinDist, or behind, falls back to the
-- camera's direction.
function GunAim.Direction(Muzzle, AimPoint, CamDir, MinDist)
	local To = AimPoint - Muzzle
	if To.Magnitude < (MinDist or 2) or To:Dot(CamDir) <= 0 then return CamDir.Unit end
	return To.Unit
end

-- Server: may this character shoot along Dir? Returns Dir.Unit, or nil and the reason.
function GunAim.Validate(Dir, RootLook, MaxYawDeg, MaxPitchDeg)
	if typeof(Dir) ~= "Vector3" or not Finite(Dir) then return nil, "malformed" end
	local M = Dir.Magnitude
	if M < 0.5 or M > 1.5 then return nil, "length" end
	Dir = Dir.Unit
	if math.abs(math.deg(math.asin(math.clamp(Dir.Y, -1, 1)))) > MaxPitchDeg then return nil, "pitch" end
	local Flat = Vector3.new(Dir.X, 0, Dir.Z)
	local Look = Vector3.new(RootLook.X, 0, RootLook.Z)
	if Flat.Magnitude > 1e-3 and Look.Magnitude > 1e-3 then
		if math.deg(math.acos(math.clamp(Flat.Unit:Dot(Look.Unit), -1, 1))) > MaxYawDeg then return nil, "behind" end
	end
	return Dir
end

-- Distance t along Origin + Dir * t (Dir unit, 0 <= t <= MaxDist) to the box (CFrame, Size), or nil. Slab test.
function GunAim.RayBox(Origin, Dir, MaxDist, BoxCFrame, Size)
	local O = BoxCFrame:PointToObjectSpace(Origin)
	local D = BoxCFrame:VectorToObjectSpace(Dir)
	local TMin, TMax = 0, MaxDist
	for _, Axis in ipairs({"X", "Y", "Z"}) do
		local Oa, Da, Ha = O[Axis], D[Axis], Size[Axis] / 2
		if math.abs(Da) < 1e-9 then
			if Oa < -Ha or Oa > Ha then return nil end
		else
			local T1, T2 = (-Ha - Oa) / Da, (Ha - Oa) / Da
			if T1 > T2 then T1, T2 = T2, T1 end
			TMin, TMax = math.max(TMin, T1), math.min(TMax, T2)
			if TMin > TMax then return nil end
		end
	end
	return TMin
end

-- History = {{T = time, CF = CFrame}, ...}, oldest first. The CFrame at time T: linear between samples, clamped to the ends.
function GunAim.Rewind(History, T)
	local N = #History
	if N == 0 then return nil end
	if T >= History[N].T then return History[N].CF end
	if T <= History[1].T then return History[1].CF end
	for I = N - 1, 1, -1 do
		local A, B = History[I], History[I + 1]
		if T >= A.T then return A.CF:Lerp(B.CF, (T - A.T) / math.max(B.T - A.T, 1e-6)) end
	end
	return History[1].CF
end

-- Seconds to rewind a player's shot: one-way ping (Player:GetNetworkPing(), as Block.lua reads it) + Interp, capped.
function GunAim.RewindTime(Ping, Cfg)
	return math.clamp((tonumber(Ping) or 0) + Cfg.Interp, 0, Cfg.MaxRewind)
end

-- Point Blank inside Passive.Range, else the gun's falloff {Start, End, Min} (or the class one).
function GunAim.RangeMult(D, Passive, Falloff)
	if D <= Passive.Range then return Passive.Mult end
	local F = Falloff or Passive.Falloff
	if F and D > F.Start then return 1 - (1 - F.Min) * math.clamp((D - F.Start) / (F.End - F.Start), 0, 1) end
	return 1
end

-- Weapon Mastery strengthens a passive's bonus only; it never deepens a penalty (falloff). Was 1 + (M - 1) * Mastery for all M.
function GunAim.Mastered(M, Mastery)
	if M > 1 then return 1 + (M - 1) * Mastery end
	return M
end

function GunAim.Flinches(D, Cfg)
	return D <= Cfg.FlinchRange
end

-- Touch aim assist: the centre nearest the ray within MaxDeg and MaxDist, or nil.
function GunAim.Assist(Origin, Dir, Centres, MaxDeg, MaxDist)
	local Best, BestDeg = nil, MaxDeg
	for _, P in ipairs(Centres) do
		local To = P - Origin
		local D = To.Magnitude
		if D > 1 and D <= MaxDist then
			local Deg = math.deg(math.acos(math.clamp(To.Unit:Dot(Dir.Unit), -1, 1)))
			if Deg < BestDeg then Best, BestDeg = P, Deg end
		end
	end
	return Best
end

-- Dir turned by up to Deg degrees on each axis at random (Rng: a Random, so tests can seed it).
function GunAim.Spread(Dir, Deg, Rng)
	if not Deg or Deg <= 0 then return Dir end
	local S = math.rad(Deg)
	local Yaw, Pitch = (Rng:NextNumber() * 2 - 1) * S, (Rng:NextNumber() * 2 - 1) * S
	return (CFrame.lookAt(Vector3.zero, Dir) * CFrame.Angles(Pitch, Yaw, 0)).LookVector
end

-- Seconds between two shots, and burst / sustained damage per second. Stats: a Guns.Items entry; Shot: a Guns.Shots def.
function GunAim.Interval(Shot, Stats)
	return Shot.Startup + Shot.Active + (Stats.Recovery or Shot.Recovery)
end
function GunAim.DPS(Shot, Stats)
	local I = GunAim.Interval(Shot, Stats)
	return Stats.Damage / I, Stats.Damage * Stats.Magazine / (I * Stats.Magazine + Stats.Reload)
end

return GunAim
```

**`Test_GunAim`** returns a TestKit suite. Numbers are worked by hand. Cases:
- **`ParallaxShotMeetsCrosshair`:**
  - Setup: muzzle M = (0, 6.5, 0). Camera C = (1.75, 8, 12), looking at P = (0, 6.5, −40), the centre of a **2 × 2 × 2 box (a head)**.
  - `AimPoint(C, (P − C).Unit, M, 120, Cast)`, where Cast is a stub running `RayBox` on that box and returning `From + Vec.Unit * t`.
  - `Direction(M, Point, CamDir)` hits the box.
  - **Control:** `RayBox(M, CamDir, 120, Box)` is nil. At z = −40 the parallel ray is at x ≈ −1.35 and y ≈ 5.35, outside ±1.
- **`AimPointSkipsBehindShooter`:** a stub wall 3 studs in front of the camera (between the camera and the muzzle) isn't the aim point.
- **`DirectionFallsBackWhenClose`:** an aim point 1 stud ahead returns `CamDir`.
- **`ValidateAccepts`:** `(0, 0, −1)` with look `(0, 0, −1)` returns a unit vector.
- **`ValidateRefuses`:** each is nil with its reason:
  - `Vector3.new(0/0, 0, 1)` ("malformed");
  - `Vector3.zero` ("length");
  - `(0, 0, −3)` ("length");
  - 80° up ("pitch");
  - 150° from the look ("behind").
- **`RayBoxHits`:**
  - from (0, 0, 10) along (0, 0, −1), a 2 × 2 × 2 box at the origin gives t = 9;
  - the box rotated 45° about Y gives 10 − √2;
  - from inside it gives 0;
  - parallel and outside gives nil.

  All within 1e-6.
- **`RewindInterpolates`:**
  - samples at T 0 and 1 at x 0 and 10;
  - T 0.25 gives 2.5;
  - T −1 gives 0, and T 5 gives 10;
  - an empty history gives nil.
- **`RewindTimeCapped`:** with `{Interp = 0.1, MaxRewind = 0.25}`, ping 0.05 → 0.15, 0.4 → 0.25, "x" → 0.1.
- **`RangeMult`:** with Passive `{Range = 12, Mult = 1.2}` and falloff `{Start = 20, End = 70, Min = 0.5}`: 5 → 1.2, 20 → 1, 45 → 0.75, 80 → 0.5.
- **`MasteredNeverDeepens`:**
  - `Mastered(0.5, 1.75)` = 0.5. Control: the old formula gives 0.125;
  - `Mastered(1.2, 1.75)` = 1.35.
- **`Flinch`:** 24.9 is true and 25.1 is false, with `{FlinchRange = 25}`.
- **`AssistPicks`:**
  - centres 2° and 1° off the ray at 30 studs: the 1° one is picked;
  - one at 3° alone gives nil;
  - one at 2° beyond MaxDist gives nil.
- **`SpreadBounded`:**
  - with `Random.new(7)`, 200 samples stay within 2.5° + 1e-6 per axis;
  - at least one exceeds 1.25° on some axis;
  - Deg 0 returns Dir.
- **`DPS`:** `Shot = {Startup = 0.12, Active = 0.02, Recovery = 0.2}` with `Stats = {Damage = 20, Magazine = 6, Reload = 2.0, Recovery = 0.36}` gives interval 0.5, burst 40, sustained 24.
- **`LimiterCaps`:** `Allow, Forget = Limiter(5, 5)`:
  - 5 × `Allow("a", 0)` are true, and a 6th is false;
  - `Allow("a", 0.2)` is true (one token back), then false again;
  - `Allow("b", 0.2)` is true (separate key);
  - after `Forget("a")`, `Allow("a", 0.2)` is true.
- **`CandidatesTwoLevels`:**
  - a Folder `Live` (made in the test, parented nowhere) with a Model A (Humanoid), a Model B (no Humanoid), and a Folder `Townsfolk` holding a Model C (Humanoid);
  - `Candidates(Live)` is {A, C} in any order;
  - `Candidates(Live, true)` is {A}.

**Steps:**
- [ ] **Step 1: Write `Test_GunAim` and a stub `GunAim`:**
  - `Direction` returns `CamDir.Unit` (today's rule);
  - `Limiter` returns `function() return true end, function() end`;
  - every other function does `error("todo")`.

  Add the two pairs and sync both files to Ye **and Foundry** (both places, the global rule).
- [ ] **Step 2: RED.** Play in Ye (`Ye:gun2`): `LMRunSuite("Test_GunAim")`. Expected:
  - `ParallaxShotMeetsCrosshair` fails: the stub's direction misses;
  - `LimiterCaps` fails: the stub allows the 6th;
  - `DirectionFallsBackWhenClose` **passes** (the stub is today's rule, which already returns the camera direction); it's a guard, and `ParallaxShotMeetsCrosshair` is its control;
  - every other case fails on "todo".

  Record the counts.
- [ ] **Step 3:** Write the module as above and sync it to both places. Play in Ye: all pass. Record `PASS n / FAIL 0`.
- [ ] **Step 4:** `--check` both places: `DIFFER 0 / MISSING 0`.
- [ ] **Step 5: Commit** `GunAim.lua`, `Test_GunAim.lua`, the manifest and `test_sync.py`: `"Gun rework Task 2: GunAim, the pure maths of a shot (candidates, limiter; PROPOSAL numbers)"`.

**— Spec gate: Task 3 starts only after the controller confirms the owner has seen the spec. —**

---

### Task 3: The numbers: TuningConfig, `Resolve` and the Mastery rule

**Changes live balance once synced** (the header's gate).

**Files:**
- **Modify:**
  - `Scripts/ReplicatedStorage/Modules/Data/Rensei/TuningConfig.lua`;
  - `Scripts/ReplicatedStorage/Modules/Managers/WeaponManager.lua` (`Resolve` and `DamageMult` only).
- **Create:** `Scripts/ServerStorage/RenseiTests/Test_GunBalance.lua`.
- **Manifest:** `RenseiTests.Test_GunBalance` (`Create: true`).

**Interfaces:**

**TuningConfig.** Make these exact changes in `Weapons.Guns`. Each line ends with `-- PROPOSAL (gun rework 2026-10-25)`.
- **`Shots`:** add `NoWhiffPenalty = true` to each of the four hits.
- **`Skill` (Fan the Hammer):** `Damage = 12, Range = 40, Spread = 3`.
- **`Items`:**
  ```lua
  Revolver = {Damage = 20, Magazine = 6, Reload = 1.8, Recovery = 0.42, Range = 70, Falloff = {Start = 20, End = 70, Min = 0.5}, Kick = 1.5},
  Renetti = {Damage = 10, Magazine = 12, Reload = 1.6, Recovery = 0.2, Range = 60, Falloff = {Start = 15, End = 60, Min = 0.5}, Kick = 0.5},
  ["Forge Tac"] = {Damage = 26, Magazine = 5, Reload = 1.8, Recovery = 0.62, Range = 110, Falloff = {Start = 40, End = 110, Min = 0.5}, Kick = 2.0},
  Sykov = {Damage = 13, Magazine = 10, Reload = 1.7, Recovery = 0.24, Range = 90, Falloff = {Start = 25, End = 90, Min = 0.5}, Kick = 0.8},
  ```
- **New in `Weapons.Guns`:**
  ```lua
  Aim = {
  	MaxYaw = 100, MaxPitch = 70, -- degrees a shot may leave your facing / the horizon
  	AimFresh = 0.75, -- seconds a stored aim stays good (was 2). Fan the Hammer's last shot is 0.42 s after its request: 0.33 s spare
  	Interp = 0.1, MaxRewind = 0.25, -- lag compensation: one-way ping + Interp, capped
  	HitBox = Vector3.new(4, 5.2, 2), HitBoxOffset = Vector3.new(0, -0.4, 0), -- a character's box around its root (Task 1 measured)
  	FlinchRange = 25, -- shots stun only this close
  	FireRate = 5, FireBurst = 5, -- the Fire request's own limiter (GunAim.Limiter), per player
  	HoldGap = 0.25, -- client hold-to-fire: at most one Fire request this often (4 a second, under ServerHandler's shared 8)
  	Buffer = 0.2, -- client: a press this long before the gun is ready still fires
  	ShoulderOffset = Vector3.new(1.75, 0.5, 0), -- the aim camera (Humanoid.CameraOffset)
  	TouchAssist = 2.5, -- degrees; 0 = off
  	SnapDeg = 120, SnapWindow = 0.1, -- the snap log
  },
  Reload = {Anim = "Guns_Reload", AnimLength = <Task 1's measured length>}, -- the owner's animation 97563934064498 (Task 7)
  NpcShot = {Startup = 0.35, Telegraph = true, Spread = 2.5}, -- enemy gunners (Task 11)
  ```
  - **The R6 box:** if Task 1's R6 measurement differs from (4, 5.2, 2) and (0, −0.4, 0), use the measured values, rounded up to 0.1.
  - **`AnimLength`:** if Task 1 found the id unloadable, it stays `nil`.
- **`TuningConfig.Meter`:** add `OnShotHit = 2, -- PROPOSAL (gun rework): a gun shot that lands (melee hits stay OnLightHit 4)`.

**`WeaponManager.Resolve`.** This replaces lines 61–73:
```lua
-- Copy of a gun SHOT's def with the held gun's damage, fire rate, range and falloff (gun rework 2026-10-25). Skills (Fan the
-- Hammer) keep their own numbers: the same for every gun. (They were scaled by the gun against Light.Hits[1], which has been the
-- pistol whip since 2026-10-17, so a Forge Tac's fan did 72.)
function WeaponManager.Resolve(Character, Def)
	local Stats = WeaponManager.ItemStats(Character)
	if not Stats or not Def.Shot then return Def end
	local Out = table.clone(Def)
	Out.Damage = Stats.Damage or Def.Damage
	Out.Recovery = Stats.Recovery or Def.Recovery
	Out.Range = Stats.Range or Def.Range
	Out.Falloff = Stats.Falloff
	return Out
end
```

**`WeaponManager.DamageMult`:**
- Its body becomes `return GunAim.Mastered(PassiveDamageMult(Attacker, Victim, SkillInfo), SkillMods.Mult(Attacker, "WeaponPassive"))`.
- `PassiveDamageMult`'s `Guns` branch becomes `return GunAim.RangeMult(SkillInfo.ShotDistance or math.huge, P, SkillInfo.Falloff)` when `SkillInfo.Ranged`.
- Add `local GunAim = require(ReplicatedStorage.Modules.Data.Rensei.GunAim)`.

**`Test_GunBalance`.** Its constants are in the test: `BURST_MAX = 37`, `SUSTAINED = {20, 26}`, `FAN = 12`, `ANIM_LENGTH` = Task 1's measured length (or nil), and `FAN_LAST_HIT = 0.42`. A gun with no `Range` uses `Shots[1].Range` (90). Cases:
- **`BurstAndSustainedInBand`:** each `Guns.Items` entry through `GunAim.DPS(Guns.Shots[1], Stats)`.
- **`Identities`:**
  - Forge Tac's Range is strictly the largest;
  - Renetti's interval is the smallest;
  - the Revolver's burst is strictly the highest.
- **`NoGunDominates`:** no gun A is ≥ another gun B on Damage, Magazine and Range and ≤ on Reload, while strictly better on one.
- **`FanSameForEveryGun`:** for each item, a fake character `{GetAttribute = function(_, K) return ({Weapon = "Guns", WeaponItem = X})[K] end}`. `WeaponManager.Resolve(Fake, Guns.Skill).Damage == FAN` (the constant 12).
- **`ShotMeter`:** `Meter.OnShotHit == 2` and `Meter.OnLightHit == 4`.
- **`ShotsNoWhiff`:** every `Guns.Shots[i].NoWhiffPenalty == true`.
- **`AimFreshCoversFan`:** `Guns.Aim.AimFresh >= FAN_LAST_HIT + 0.2`.
- **`ReloadAnimLength`:** `Guns.Reload.AnimLength == ANIM_LENGTH` (within 0.01, or both nil).

**Steps:**
- [ ] **Step 1: RED.**
  - Write `Test_GunBalance`, and sync it to both places. Play in Ye (`Ye:gun3`): `Test_GunBalance`.
  - **Expected failures** on today's numbers (each with its reason):
    - `BurstAndSustainedInBand` (Revolver 40.0; Forge Tac 40.7 and 27.4);
    - `Identities`: every Range falls back to 90, so "strictly largest" fails, and the Revolver's 40.0 is below the Forge Tac's 40.7;
    - `NoGunDominates` (the Forge Tac over the Revolver);
    - `FanSameForEveryGun` (today's `Resolve` gives 20 / 10 / 24 / 13);
    - `ShotMeter` (`OnShotHit` nil);
    - `ShotsNoWhiff`;
    - `AimFreshCoversFan` (`Aim` nil);
    - `ReloadAnimLength` (`Reload` nil).
  - Record them.
- [ ] **Step 2:** Make the TuningConfig, `Resolve` and `DamageMult` changes. Sync `Rensei.TuningConfig` and `Managers.WeaponManager` to both places.
- [ ] **Step 3: GREEN.** Play in Ye: `Test_GunBalance` and `Test_GunAim` all pass.
- [ ] **Step 4:** `--check` both places.
- [ ] **Step 5: Commit** TuningConfig, WeaponManager, `Test_GunBalance`, the manifest and `test_sync.py`: `"Gun rework Task 3: gun balance numbers, Fan the Hammer and Mastery fixes, reload length (PROPOSAL)"`.

---

### Task 4: The test kits (shared, not copied)

**Files:**
- **Modify:**
  - `Scripts/ServerScriptService/EnemyService.lua` (extract `MakeCombatant`);
  - `Scripts/ServerStorage/RenseiTests/SmokeKit.lua`;
  - `Scripts/ServerStorage/RenseiTests/Play_Stealth.lua`.
- **Create:**
  - `Scripts/ServerStorage/RenseiTests/GunKit.lua`;
  - `Scripts/ServerStorage/RenseiTests/Play_GunKit.lua`.
- **Manifest:** `RenseiTests.GunKit` and `RenseiTests.Play_GunKit` (`Create: true`).

**Interfaces:**

**`EnemyService.MakeCombatant(Rig, WalkSpeed)`:**
- Lines 458–462 of `Spawn`, moved into a function `Spawn` now calls:
  - `WCS.Character.new(Rig)`;
  - `SetDefaultProps` with `WalkSpeed`, JumpPower, JumpHeight and `AutoRotate = true`;
  - `BlockManager.Initiate(Rig)`.
- It returns the WCS character. **No behaviour change.**

**SmokeKit** (Play_Stealth's local `Part`, the temp list and the cleanup half of `Guard`, moved here):
- `SmokeKit.TempPart(Props)` → an anchored Part with Props, in `workspace`, remembered;
- `SmokeKit.ClearTemp()` destroys every remembered part;
- `SmokeKit.Guarded(Player, Body, Before, After)`:
  1. remembers the player's character pivot;
  2. runs `Before()`, then `pcall(Body)`;
  3. clears the temp parts;
  4. runs `After()`;
  5. puts the character back (pivot, zero velocity);
  6. re-raises Body's error.
- **`Play_Stealth`'s `Part` and `Guard`** become thin calls to these. `Guard`'s PerceptionService / LightService setup and teardown go in as Before and After. Its behaviour is unchanged.

**`GunKit`** (gun suites only; requires SmokeKit, EnemyService and WeaponManager):
- **`GunKit.Spot()`:** the test spot's centre for this place, from Task 1's survey: Ye's or Foundry's by `game.PlaceId`, written as constants with the survey's date in a comment. It errors in any other place.
- **`GunKit.Dummy(Offset, Name)`:**
  - an R6 clone of `game.StarterPlayer.StarterCharacter` at `Spot() + Offset`, anchored, in `World.Live`;
  - `Humanoid.MaxHealth = Health = 1000`;
  - `EnemyType` unset;
  - made fight-ready with `EnemyService.MakeCombatant(Rig, 0)`, so DamageManager doesn't call it IFramed.

  It returns the Model.
- **`GunKit.Shooter(Offset, LookAt, Item)`:** a Dummy facing LookAt, with `WeaponManager.Give(Model, Item)`, `CombatMode = true` and `PhysicalMultiplier = 1`.
- **`GunKit.Shot(Shooter, Dir)`:** `SetAim`, then `WeaponManager.Fire(Shooter, "Guns_Shot1", WeaponManager.Resolve(Shooter, Tuning.Weapons.Guns.Shots[1]))`. Returns the results, plus each victim's Health before minus after.
- **`GunKit.Clean()`:**
  - for every Model it made, destroys its WCS character (`WCS.Character.GetCharacterFromInstance(M):Destroy()`), then the Model;
  - then `SmokeKit.ClearTemp()`.
- **Every gun suite wraps its cases in `SmokeKit.Guarded`,** with `GunKit.Clean` as After.

**`Play_GunKit`** (the kit's own checks):
- **`DummyCanBeHit`:**
  - `DamageManager(Shooter, Dummy, SkillData.Guns_Shot1)` returns "Hit" and the dummy loses Health.
  - **Control in the same case:** a plain StarterCharacter clone with no `MakeCombatant`, in `World.Live`, returns "IFramed". It's made and removed inside the case.
- **`CleanLeavesNothing`:** after `Clean()`, no Model the kit made is in `World.Live`, and `WCS.Character.GetCharacterFromInstance` is nil for each.
- **`SpotIsThisPlace`:** `Spot()` gives the survey constant for this place. A ray down from 20 studs over it meets ground within 0.5 of the survey's height.

**Steps:**
- [ ] **Step 1: RED.**
  - Write GunKit and `Play_GunKit`, with `GunKit.Dummy` **without** `MakeCombatant`. Sync them to both places.
  - Play in Ye (`Ye:gun4`): `Play_GunKit`. Expected: `DummyCanBeHit` fails ("IFramed"), and the other two pass.
- [ ] **Step 2:** Extract `MakeCombatant`, use it in GunKit, and move the helpers into SmokeKit. Sync `RenseiServer.EnemyService`, `RenseiTests.SmokeKit`, `RenseiTests.Play_Stealth` (to its Places) and `RenseiTests.GunKit`.
- [ ] **Step 3: GREEN.** Play in Ye:
  - `Play_GunKit` all pass;
  - **`Play_Stealth` and `Play_LindenmoorSmoke` as before.** `EnemiesStandInTheWorld` guards the `Spawn` refactor; record its counts.
- [ ] **Step 4:** `--check` both places.
- [ ] **Step 5: Commit**: `"Gun rework Task 4: test kits: EnemyService.MakeCombatant, SmokeKit temp parts and Guarded (from Play_Stealth), GunKit"`.

---

### Task 5: The server shot path

**Files:**
- **Modify:**
  - `Scripts/ReplicatedStorage/Modules/Managers/WeaponManager.lua` (the gun section);
  - `Scripts/ServerScriptService/ServerHandler/Requests/Shoot.lua`.
- **Create:** `Scripts/ServerStorage/RenseiTests/Play_Guns.lua`.
- **Manifest:** `RenseiTests.Play_Guns` (`Create: true`).

**Interfaces:**

**`WeaponManager.SetAim(Character, Dir)`** validates and returns the unit direction or nil:
```lua
function WeaponManager.SetAim(Character, Dir)
	local Root = Character:FindFirstChild("HumanoidRootPart")
	local Cfg = Tuning.Weapons.Guns.Aim
	local Ok = Root and GunAim.Validate(Dir, Root.CFrame.LookVector, Cfg.MaxYaw, Cfg.MaxPitch)
	Aim[Character] = Ok and {Dir = Ok, At = os.clock()} or {Bad = true, At = os.clock()}
	return Ok
end
```

**`AimDirection(Character, Root)`:**
- a fresh (< `Aim.AimFresh`) valid aim gives its direction;
- a fresh bad aim gives **nil** (refused);
- no fresh aim gives the root's flat look. That's for NPCs, and for skills with no aim sent.

`MAX_AIM_ANGLE` goes.

**PositionHistory, found and required** (nil until Task 6, and nil in places without it):
```lua
local HistoryModule = nil
local function History()
	if HistoryModule then return HistoryModule end
	local M = game:GetService("ServerScriptService"):FindFirstChild("PositionHistory")
	if M then HistoryModule = require(M) end
	return HistoryModule
end
```

**`WeaponManager.ShotTarget(Shooter, Origin, Dir, MaxT, At)`**, exported for tests:
```lua
-- The nearest live character -- never the Shooter -- whose box the ray Origin + Dir * t meets before MaxT, each where it stood
-- at server time At (PositionHistory) or, without a history, where it stands now. Returns Model, t or nil.
function WeaponManager.ShotTarget(Shooter, Origin, Dir, MaxT, At)
	local Cfg = Tuning.Weapons.Guns.Aim
	local Live = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Live")
	local H = History()
	local Best, BestT = nil, MaxT
	for _, M in ipairs(Live and GunAim.Candidates(Live) or {}) do
		if M ~= Shooter then
			local Humanoid = M:FindFirstChildOfClass("Humanoid")
			local Root = Humanoid and Humanoid.Health > 0 and M:FindFirstChild("HumanoidRootPart")
			if Root then
				local CF = (H and H.At(M, At)) or Root.CFrame
				local T = GunAim.RayBox(Origin, Dir, BestT, CF * CFrame.new(Cfg.HitBoxOffset), Cfg.HitBox)
				if T and T < BestT then Best, BestT = M, T end
			end
		end
	end
	return Best, Best and BestT or nil
end
```

**`WeaponManager.Fire(Character, SkillName, Def)`.** This replaces lines 367–410:
```lua
	-- One hitscan shot (gun rework 2026-10-25). The direction is the validated aim (AimDirection); an aim that failed
	-- validation fires nothing and spends no round (it used to fire straight ahead). The shot stops at the first wall
	-- (World.Live excluded from that ray) and hits the nearest character box before it (ShotTarget; Task 6 rewinds them).
	-- A def with no Range now defaults to 90 (was 80); every Shots def and Fan the Hammer carry their own Range.
	function WeaponManager.Fire(Character, SkillName, Def)
		local Results = {}
		local Root = Character:FindFirstChild("HumanoidRootPart")
		if not Root or not WeaponManager.CanFire(Character) then return Results end
		local Cfg = Tuning.Weapons.Guns.Aim
		local Dir = AimDirection(Character, Root)
		if not Dir then return Results end
		Character:SetAttribute("Ammo", Character:GetAttribute("Ammo") - 1)
		Dir = GunAim.Spread(Dir, Def.Spread, ShotRandom)
		local Origin = GunAim.Muzzle(Root.Position)
		local Range = (Def.Range or 90) * SkillMods.Mult(Character, "GunRange") -- Marksman
		local Params = RaycastParams.new()
		Params.FilterType = Enum.RaycastFilterType.Exclude
		Params.FilterDescendantsInstances = {Character, workspace.World.Visuals, workspace.World.Live}
		local Wall = workspace:Raycast(Origin, Dir * Range, Params)
		local WallT = Wall and (Wall.Position - Origin).Magnitude or Range
		local Victim, T = WeaponManager.ShotTarget(Character, Origin, Dir, WallT, RewindAt(Character))
		local EndT = T or WallT
		local Tool = HeldTool(Character)
		local Barrel = Tool and Tool:FindFirstChild("Barrel", true)
		Barrel = Barrel and Barrel:IsA("BasePart") and Barrel or nil
		Tracer(Barrel and Barrel.Position or Origin, Origin + Dir * EndT)
		MuzzleFlash(Barrel, Dir)
		local Shown = "Miss"
		if Victim then
			local SkillData = require(ReplicatedStorage.Modules.Data.SkillData)
			local DamageManager = require(ReplicatedStorage.Modules.Managers.DamageManager)
			local Info = table.clone(SkillData[SkillName])
			Info.Damage = Def.Damage
			Info.Ranged = true
			Info.ShotDistance = T
			Info.Falloff = Def.Falloff
			Info.Meter = Tuning.Meter.OnShotHit
			if not GunAim.Flinches(T, Cfg) then Info.StunTime = 0 end -- no flinch past FlinchRange (DamageManager skips a 0 stun)
			local Result = DamageManager(Character, Victim, Info)
			table.insert(Results, {Victim = Victim, Result = Result})
			Shown = (Result == "Hit" and "Hit") or ((Result == "Blocked" or Result == "Shielded" or Result == "Countered") and "Blocked") or "Miss"
		end
		Character:SetAttribute("LastShotResult", Shown) -- the hit marker (GunAimUI, Task 9)
		Character:SetAttribute("LastShotAt", workspace:GetServerTimeNow())
		if Character:GetAttribute("Ammo") <= 0 then WeaponManager.Reload(Character) end
		return Results
	end
```

**Its helpers:**
- `local ShotRandom = Random.new()`.
- `local function RewindAt(Character) return workspace:GetServerTimeNow() end`. Task 6 replaces its body.
- The inline spread math at the old lines 375–378 goes.

**`Requests/Shoot.lua`:**
- **At the top:** `local AllowFire, ForgetFire = GunAim.Limiter(Cfg.FireRate, Cfg.FireBurst)`, and `Players.PlayerRemoving` calls `ForgetFire`.
- **The Fire branch:**
  1. **First line:** `if not AllowFire(Player, os.clock()) then return end`.
  2. **The aim:** `local Dir = WeaponManager.SetAim(Character, Arg); if not Dir then return end`. This replaces `if Arg ~= nil then ... end`. **An invalid aim returns before AttackRunner,** so there's no animation and no round.
  3. **The snap log:** if this character's previous Fire was under `Cfg.SnapWindow` ago and the angle between the two directions is over `Cfg.SnapDeg`, add 1 to its `GunSnapCount` attribute. That's all.
- **Water (spec B7):** add `"Traversal"` to the watched attributes at line 43. In `Check`, also end the mode when `Character:GetAttribute("Traversal") == "Swim"`.

**`Play_Guns`.** Every case uses GunKit at `GunKit.Spot()`, inside `SmokeKit.Guarded`. Each case says whether it is RED or a guard on the code after Task 3:
- **`HitsWhatItAimsAt`** (guard): Revolver, target 30 studs ahead, aimed at its root. 1 result, "Hit".
- **`BehindIsRefused`** (RED: today it fires forward and spends a round): aim (0, 0, +1) while facing −Z. No result, `Ammo` still 6, `LastShotAt` unchanged.
- **`RangePerGun`** (guard: green since Task 3, because `Resolve` copies the gun's Range): a target at 65 studs. The Renetti gets no result (60); the Forge Tac gets one (110).
- **`Falloff`** (RED: today's Fire sets no `Info.Falloff`, so the class falloff 25→90 gives about 0.85 → 16.9): Revolver at 45 studs on a fresh dummy. Damage 15 ± 0.5 (20 × 0.75, worked by hand).
- **`MasteryDoesNotDeepen`** (RED for the falloff reason above; its own positive control passes since Task 3):
  - with the shooter's `WeaponPassive` mod at its max, then at its min (no ranks), each on a fresh dummy at 45 studs, through the API `Managers.SkillMods` shows (exported in Task 1), on the dummy only;
  - both damages equal each other within 0.01 (the control);
  - both are 15 ± 0.5.
- **`FlinchOnlyClose`** (RED): at 10 studs the target gains the WCS Stun status; at 40 it doesn't.
- **`WallStops`** (RED: today there's no `LastShotResult`): a 10 × 10 × 1 `SmokeKit.TempPart` between the shooter and a target at 15 studs. No result, and `LastShotResult == "Miss"`.
- **`ResultAttribute`** (RED):
  - after a hit, `LastShotResult == "Hit"`;
  - after a blocked hit (the target's Blocking status started, facing the shooter), `"Blocked"`.
- **`ShootingModeEndsInWater`** (RED: `Traversal` isn't watched):
  - the shooter's `ShootingMode = true`. Then `Traversal = "Swim"` is set on it, as a server attribute the way MovementState sets it.
  - Within 0.2 s `ShootingMode` is nil.
  - `Watch` hooks players' characters, so this case uses the **test player's** character: no Tool held (step 4), a Revolver via `Give`, `CombatMode` true.
  - It puts `Traversal` back to nil afterwards.

The Fire limiter is tested purely (`Test_GunAim LimiterCaps`) and from the client (Task 8's `HoldLoopUnderBucket`). There's no Play rate-limit case, which could only pass by construction.

**Steps:**
- [ ] **Step 1: RED.** Write `Play_Guns` and sync it to both places. Play in Ye (`Ye:gun5`): `Play_Guns`. Expected as each case says above. Record each.
- [ ] **Step 2:** Make the WeaponManager and Shoot changes. Sync `Managers.WeaponManager` and `Requests.Shoot` to both places.
- [ ] **Step 3: GREEN.** Play in Ye: `Play_Guns`, `Test_GunAim`, `Test_GunBalance`, `Play_GunKit`, `Play_Stealth` and `Play_Assault`. The gun suites all pass; Stealth and Assault are as before (record the counts).
- [ ] **Step 4:** `--check` both places.
- [ ] **Step 5: Commit**: `"Gun rework Task 5: server shot path: Fire limiter, validated aim, per-gun range and falloff, flinch range, shot result, mode ends in water"`.

---

### Task 6: Lag compensation (`PositionHistory`)

**Files:**
- **Create:** `Scripts/ServerScriptService/PositionHistory.lua`.
- **Modify:**
  - `Scripts/ServerScriptService/ServerHandler.server.lua` (one line);
  - `WeaponManager.lua` (`RewindAt`);
  - `Play_Guns.lua` (new cases).
- **Manifest:** `RenseiServer.PositionHistory` (`ServerStorage/RenseiServer/PositionHistory`, ModuleScript, `Create: true`).

**Interfaces:**
```lua
-- PositionHistory (gun rework 2026-10-25): the last KEEP seconds of every live character's root CFrame, so a player's shot is
-- tested where its shooter saw the target (lag compensation, capped by TuningConfig.Weapons.Guns.Aim.MaxRewind). PROPOSAL.
-- The characters are GunAim.Candidates -- the same list WeaponManager.ShotTarget tests.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GunAim = require(ReplicatedStorage.Modules.Data.Rensei.GunAim)

local PositionHistory = {}
local KEEP = 0.5 -- seconds kept (PROPOSAL: twice MaxRewind)
local STEP = 1 / 30 -- seconds between samples
local Samples = {} -- [Model] = {{T, CF}, ...} oldest first
local Started = false

function PositionHistory.Sample(Now)
	local World = workspace:FindFirstChild("World")
	local Live = World and World:FindFirstChild("Live")
	if Live then
		for _, M in ipairs(GunAim.Candidates(Live)) do
			local Root = M:FindFirstChild("HumanoidRootPart")
			if Root then
				local H = Samples[M]
				if not H then
					H = {}
					Samples[M] = H
					M.Destroying:Once(function() Samples[M] = nil end)
				end
				table.insert(H, {T = Now, CF = Root.CFrame})
				while #H > 1 and Now - H[1].T > KEEP do table.remove(H, 1) end
			end
		end
	end
	for M in pairs(Samples) do
		if not M.Parent then Samples[M] = nil end
	end
end

-- Where Model's root was at server time At (nil when it has no history yet).
function PositionHistory.At(Model, At)
	local H = Samples[Model]
	return H and GunAim.Rewind(H, At) or nil
end

function PositionHistory.Start()
	if Started then return end
	Started = true
	local Last = 0
	RunService.Heartbeat:Connect(function()
		local Now = workspace:GetServerTimeNow()
		if Now - Last >= STEP then
			Last = Now
			PositionHistory.Sample(Now)
		end
	end)
end

return PositionHistory
```

**Wiring:**
- **`ServerHandler.server.lua`:** after its Requests load, add `task.spawn(function() local M = game:GetService("ServerScriptService"):WaitForChild("PositionHistory", 30) if M then require(M).Start() end end)`. If Task 1 found the RenseiServer modules in another run-time parent, use that parent.
- **`WeaponManager.RewindAt`:**
  ```lua
  local function RewindAt(Character)
  	local Player = Players:GetPlayerFromCharacter(Character)
  	if not Player then return workspace:GetServerTimeNow() end -- NPCs see the truth
  	local Ok, Ping = pcall(Player.GetNetworkPing, Player)
  	return workspace:GetServerTimeNow() - GunAim.RewindTime(Ok and Ping or 0, Tuning.Weapons.Guns.Aim)
  end
  ```

**New `Play_Guns` cases.** A GunKit dummy is moved by the test along +X at 16 studs/s for 1 s: `PivotTo` every Heartbeat, with its path computed by the test from x0. The shooter is 30 studs off the path on Z.
- **`HistoryTracksAMover`** (RED: no module): `PositionHistory.At(Dummy, Now − 0.2)` is within 0.6 studs of the test's own x for that time.
- **`RewindHitsWhereItWas`** (RED: `ShotTarget` ignores the time without a history):
  - Right after it stops at x1, `ShotTarget(Shooter, Origin, Dir, 200, Now − 0.2)`, with Dir aimed at the test's own position for Now − 0.2 (x1 − 3.2), hits.
  - **Control:** the same ray with `At = Now` misses. The box is 3.2 studs further, more than its 2-stud half-width.
- **`RewindCapped`:**
  - **Positive control (RED without the rewind):** a ray aimed at where the dummy was at Now − 0.25, with `At = Now − GunAim.RewindTime(2.0, Cfg)` (= 0.25), hits.
  - **Guard:** a ray at where it was at Now − 0.6 misses with that same `At`. That's the cap.

**Steps:**
- [ ] **Step 1: RED.** Add the cases and sync `Play_Guns` to both places. Play in Ye (`Ye:gun6`): the three new cases fail, `RewindCapped` on its positive control. Record.
- [ ] **Step 2:** Write PositionHistory and the wiring. Sync `RenseiServer.PositionHistory`, `RenseiServer.ServerHandler` and `Managers.WeaponManager` to both places.
- [ ] **Step 3: GREEN.**
  - Play in Ye: `Play_Guns` all pass.
  - **The cost:** record the server's Heartbeat time with 30 GunKit dummies in `World.Live`, with and without sampling: the mean over 300 frames. It must be **under 0.2 ms per frame**; otherwise report it.
- [ ] **Step 4:** `--check` both places.
- [ ] **Step 5: Commit**: `"Gun rework Task 6: lag compensation (PositionHistory on GunAim.Candidates, capped rewind)"`.

---

### Task 7: The reload: the owner's animation, the interrupt rule, the top-up

**Files:**
- **Create:**
  - `Art/Studio/Guns/reload_slot.lua` (reversible);
  - `Scripts/ServerStorage/RenseiTests/Play_GunReload.lua`.
- **Modify:** `WeaponManager.lua` (`Reload`, `CancelReload`, the top-up listener in `Track`).
- **Manifest:** `RenseiTests.Play_GunReload` (`Create: true`).

**Interfaces:**

**`reload_slot.lua`.** Its header constant is `local WANT_ID = "rbxassetid://97563934064498"`, or `""` if Task 1 found the id unloadable; the implementer writes whichever Task 1's report says.
- **`apply`** creates one `Animation` named `Guns_Reload`, with `AnimationId = WANT_ID`, no children and `GunReworkAdd = true`:
  - **where:** `ReplicatedStorage.Assets.Animations.Weapons.Guns` if Task 1 found a `Guns` folder, else `Assets.Animations.Weapons`;
  - **records:** it sets `Assets.Animations:SetAttribute("GunReloadSlot", WANT_ID)`, the flag and the value it wrote;
  - **refuses** if the flag is set, or if any `Animation` named `Guns_Reload` already exists under `Assets.Animations`.
- **`undo`** destroys only the instance carrying `GunReworkAdd` and clears the flag. **It refuses only if the slot's AnimationId differs from the flag's recorded value** (someone changed it since).
- **`check` fails when:**
  - there isn't exactly one `Guns_Reload`;
  - it isn't under `Weapons`;
  - it has a child;
  - its AnimationId isn't `WANT_ID`;
  - the flag isn't `WANT_ID`.
- **`test`:** as the contract says.
- **Run it in both places** (Edit).

**`WeaponManager`, the server branch:**
```lua
	local WCS = require(ReplicatedStorage.Modules.Framework.WCS)
	local StunState = require(ReplicatedStorage.Modules.Skills.States.Stun)
	local ReloadCfg = Tuning.Weapons.Guns.Reload
	local ReloadToken = {} -- [Character] = the running reload's token
	local Restarting = {} -- [Character] = a restart watcher is waiting

	-- the reload animation, only when the slot holds an id (an empty slot plays nothing and warns nothing)
	local function ReloadAnimReady()
		for _, A in ipairs(ReplicatedStorage.Assets.Animations:GetDescendants()) do
			if A:IsA("Animation") and A.Name == ReloadCfg.Anim then return A.AnimationId ~= "" end
		end
		return false
	end

	-- the interrupt rule (gun rework, PROPOSAL): things done to you cancel a reload; your own actions don't
	local function ReloadBlocked(Character)
		local WC = WCS.Character.GetCharacterFromInstance(Character)
		return (WC and WC:HasStatusEffects({StunState})) or Character:GetAttribute("Knocked") == true
			or Character:GetAttribute("GrippedBy") ~= nil or Character:GetAttribute("CarriedBy") ~= nil
			or Character:GetAttribute("Traversal") == "Swim"
	end
```

**`WeaponManager.Reload(Character)`:**
- **The guards:** today's (not already reloading, not full). Then `if ReloadBlocked(Character) then` start the restart watcher and return.
- **A new token.**
- **The attributes:** `ReloadTime` and `ReloadingUntil`, as today.
- **The animation:** if `ReloadAnimReady()`, play it:
  ```lua
  AnimationManager.Play(Character, ReloadCfg.Anim, {
  	Priority = Enum.AnimationPriority.Action,
  	Speed = ReloadCfg.AnimLength and ReloadCfg.AnimLength / ReloadTime or 1,
  })
  ```
- **The loop:** each Heartbeat until `ReloadingUntil`. If the token changed, stop. If `ReloadBlocked`, call `CancelReload` and start the watcher.
- **At the end:** if the token still holds and the same item is equipped, `Ammo = Magazine`. Clear both attributes and the token.

**`WeaponManager.CancelReload(Character)`:** if a token exists, clear it and the two attributes, and if `ReloadAnimReady()`, `AnimationManager.Stop(Character, ReloadCfg.Anim)`.

**The restart watcher:**
- One per character (`Restarting`).
- Heartbeat until `not ReloadBlocked`, or until the character or its `WeaponItem` changes.
- Then, if `Ammo < MaxAmmo`, `Reload`.

**The top-up lives in WeaponManager (choice for finding 5).** In `Track(Character)`, which runs for every armed character, NPCs included, connect `Character:GetAttributeChangedSignal("ShootingMode")`. When it turns nil while `WeaponManager.ItemStats(Character)` exists and `Ammo < MaxAmmo`, call `WeaponManager.Reload(Character)`. **`Shoot.lua` gets no top-up code.**

**Fan the Hammer:** with fewer than 3 rounds, `Fire` refuses the later strikes (`CanFire` false), and the reload starts on the last round, as today.

**`Play_GunReload`.** GunKit shooters; each case inside `SmokeKit.Guarded`.
- **`EmptyReloadsInTime`** (guard: the reload time is 1.8 since Task 3): a Revolver fired 6 times. `ReloadingUntil − now` is 1.8 ± 0.05; after 1.9 s, `Ammo == 6`.
- **`StunCancelsAndRestarts`** (RED):
  - at 0.5 s into the reload, a 0.4 s WCS Stun on the shooter;
  - within one frame, `ReloadingUntil` is nil;
  - after the stun, a new `ReloadingUntil` is about 1.8 s from its end (± 0.1);
  - `Ammo` is 6 only after that.
- **`OwnActionsDoNotCancel`** (guard): the whip `Guns_Light1` through AttackRunner at 0.3 s. `ReloadingUntil` is unchanged, and `Ammo == 6` at 1.9 s.
- **`TopUpOnModeOff`** (RED: no listener), on a **GunKit shooter**, which the WeaponManager listener reaches: fire 2 (4 left), then `ShootingMode` true then nil. A reload starts, and `Ammo == 6` after 1.9 s.
- **`FilledSlotPlays`** (RED: nothing plays the slot today), with the slot as applied (the owner's id):
  - a Play-only wrapper of `AnimationManager.Play`, installed by the case and removed after, counts calls named `Guns_Reload`;
  - during one reload the count is 1, and the shooter's Animator has a playing track whose `Animation.AnimationId` is the owner's id.
  - **If Task 1 found the id unloadable,** this case is skipped with that reason in its output.
- **`EmptySlotPlaysNothing`** (paired with `FilledSlotPlays`, its control):
  - in Play, set the slot's AnimationId to `""` (the world is a copy);
  - the same wrapper counts 0 during a reload;
  - the server log gains no "Animation not found" line (`LogService:GetLogHistory()` before and after);
  - put the id back.

  Today's code also counts 0, so this case can't fail alone. `FilledSlotPlays` with the same wrapper is what proves the gate reads the slot.

**Steps:**
- [ ] **Step 1:** Write `reload_slot.lua` with Task 1's `WANT_ID`. In **Ye (Edit)**: run `plan`, `test` (the snapshots must be equal), `apply`, then `check` (`FAIL 0`).
- [ ] **Step 2: RED.** Write `Play_GunReload` and sync it to both places. Play in Ye (`Ye:gun7`). Expected as each case says. Record.
- [ ] **Step 3:** Make the WeaponManager changes and sync them to both places.
- [ ] **Step 4: GREEN.** Play in Ye: `Play_GunReload` all pass (or `FilledSlotPlays` skipped as above), and `Play_Guns`.
- [ ] **Step 5:** `reload_slot.lua` `test`, `apply`, then `check` in **Foundry (Edit; Ye's PlayLock nil)**. `--check` both places.
- [ ] **Step 6: Commit**: `"Gun rework Task 7: Guns_Reload plays the owner's reload (97563934064498); interrupt rule; top-up in WeaponManager"`.

---

### Task 8: Client aim: the aim camera, the crosshair, lock-on, hold to fire

**Files:**
- **Create:**
  - `Scripts/ReplicatedStorage/Modules/UI/GunAimUI.lua`;
  - `Art/Studio/Guns/client_checks.lua`.
- **Modify:**
  - `UI/SettingsUI.lua` (extract the camera block);
  - `ClientHandler.client.lua`;
  - `UI/HUDUI.lua`.
- **Manifest:** `UI.GunAimUI` (`Create: true`).

**Interfaces:**

**`SettingsUI`, the shift-lock camera made shareable.** The body of the `ShiftConn` RenderStepped function moves into two exported functions with the same behaviour:
```lua
-- the shift-lock camera (Alt), shared with guns' shooting mode (GunAimUI, gun rework 2026-10-25)
function SettingsUI.CameraFree(Humanoid)
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	if Humanoid then Humanoid.CameraOffset = Vector3.zero end
	pcall(function() GameSettings.RotationType = Enum.RotationType.MovementRelative end)
end
-- Offset: Humanoid.CameraOffset. SprintTurns: while sprinting, turn with movement (shift lock) instead of the camera.
function SettingsUI.CameraLock(Character, Humanoid, Offset, SprintTurns)
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
	Humanoid.CameraOffset = Offset
	-- On a wall (climbing / wall running / a ledge) or swimming under water, the body keeps its own facing
	if JumpManager.ClimbConn or JumpManager.WallRunConn or JumpManager.LedgeConn or SwimActive() then return end
	Humanoid.AutoRotate = true
	local Sprinting = SprintTurns and not Character:GetAttribute("Dashing")
		and Humanoid.WalkSpeed > BaseWalk * (Character:GetAttribute("SpeedMultiplier") or 1) * 1.5
	pcall(function()
		GameSettings.RotationType = Sprinting and Enum.RotationType.MovementRelative or Enum.RotationType.CameraRelative
	end)
end
```
- **`SwimActive()`:** `local M = ReplicatedStorage.Modules.Managers:FindFirstChild("SwimController") return M ~= nil and require(M).Active()`. That's the swim plan's guard, in this one place.
  - If the swim plan has already added its guard line inside the old loop, it moves into `CameraLock` here.
  - If this plan runs first, the swim plan's Task 5 finds `SwimActive` already in place and skips its line.
- **`GameSettings` and `BaseWalk`** become module locals.
- **The ShiftConn loop becomes:**
  ```lua
  if Player.Character and Player.Character:GetAttribute("ShootingMode") then return end -- GunAimUI owns the camera
  if Gui.bg.Visible or Gui.Dialogue.Visible or LockOn.Target or not Humanoid then
  	SettingsUI.CameraFree(Humanoid) Gui.Crosshair.Visible = false return
  end
  Gui.Crosshair.Visible = true
  SettingsUI.CameraLock(Character, Humanoid, Vector3.new(0, 1.5, 0.5), true)
  ```
- **The shift-lock-off branch** calls `CameraFree` too.

**`GunAimUI`:**
```lua
-- GunAimUI (gun rework 2026-10-25): guns' shooting mode on the client. While ShootingMode is on:
--   * the aim camera (PROPOSAL): SettingsUI.CameraLock with the shoulder offset (no sprint turn), unless locked on;
--   * the crosshair is the game's own marker (UIState.Gui.Crosshair), drawn where the shot will go;
--   * AimDirection(): from the muzzle through what the crosshair covers, or at the lock-on target;
--   * FireInput(Began): hold to fire, buffered, capped at one request every Aim.HoldGap (under ServerHandler's shared limit).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)
local GunAim = require(ReplicatedStorage.Modules.Data.Rensei.GunAim)
local WeaponManager = require(ReplicatedStorage.Modules.Managers.WeaponManager)
local UIState = require(script.Parent.UIState)
local SettingsUI = require(script.Parent.SettingsUI)

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Cfg = Tuning.Weapons.Guns.Aim
local RequestRemote = ReplicatedStorage.Remotes.RequestRemote
local GunAimUI = {Sends = 0, HoldGap = Cfg.HoldGap, ForceAim = nil} -- Sends / HoldGap / ForceAim: client_checks seams

local function Char() return Player.Character end
local function Shooting()
	local C = Char()
	return C ~= nil and C:GetAttribute("ShootingMode") == true
end
-- the lock-on target's root, or nil (ClientHandler's AlchemyAim uses this too)
local LockOnModule = script.Parent:FindFirstChild("LockOn")
function GunAimUI.LockedRoot()
	local Ok, LockOn = pcall(function() return LockOnModule and require(LockOnModule) end)
	local T = Ok and LockOn and LockOn.Target
	return T and T.Parent and T:FindFirstChild("HumanoidRootPart") or nil
end
local function Crosshair() return UIState.Gui:FindFirstChild("Crosshair") end
local HomePosition = nil

-- the crosshair's centre as a camera ray (its ScreenGui decides whether the top-bar inset counts)
function GunAimUI.CrosshairRay()
	local Cross = Crosshair()
	local Gui = Cross and Cross:FindFirstAncestorOfClass("ScreenGui")
	local V = Camera.ViewportSize
	if not (Cross and Gui and Cross.Visible) then return Camera:ViewportPointToRay(V.X / 2, V.Y / 2) end
	local P = Cross.AbsolutePosition + Cross.AbsoluteSize / 2
	if Gui.IgnoreGuiInset then return Camera:ViewportPointToRay(P.X, P.Y) end
	return Camera:ScreenPointToRay(P.X, P.Y)
end

local function Cast(From, Vec)
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = {Char(), workspace.World.Visuals}
	local R = workspace:Raycast(From, Vec, Params)
	return R and R.Position or nil
end
GunAimUI.Cast = Cast

function GunAimUI.AimDirection()
	if GunAimUI.ForceAim then return GunAimUI.ForceAim end
	local C = Char()
	local Root = C and C:FindFirstChild("HumanoidRootPart")
	if not Root then return Camera.CFrame.LookVector end
	local Muzzle = GunAim.Muzzle(Root.Position)
	local Target = GunAimUI.LockedRoot()
	if Target then
		local To = Target.Position - Muzzle
		if To.Magnitude > 1 then return To.Unit end
	end
	local Ray = GunAimUI.CrosshairRay()
	local Stats = WeaponManager.ItemStats(C)
	local Point = GunAim.AimPoint(Ray.Origin, Ray.Direction, Muzzle, (Stats and Stats.Range or 90) + 10, Cast)
	Point = GunAimUI.Assist(Ray, Point) -- Task 10 (touch); Point unchanged until then
	return GunAim.Direction(Muzzle, Point, Ray.Direction.Unit, 2)
end
function GunAimUI.Assist(_, Point) return Point end
function GunAimUI.Kick() end -- Task 9

-- hold to fire (PROPOSAL): Began true = press (false when not shooting, so RMB falls back to Feint); false = release
local FireHeld, FireWanted, FireLoop = false, 0, nil
local function GunReady(C)
	return C:GetAttribute("CombatState") == nil and (C:GetAttribute("Ammo") or 0) > 0
		and (C:GetAttribute("ReloadingUntil") or 0) <= workspace:GetServerTimeNow()
end
local function SendShot(C)
	local Dir = GunAimUI.AimDirection()
	local Root = C:FindFirstChild("HumanoidRootPart")
	local Flat = Vector3.new(Dir.X, 0, Dir.Z)
	-- face the shot (the aim camera already turns you; this keeps the server's facing check safe), not while locked on
	if Root and Flat.Magnitude > 0.1 and not GunAimUI.LockedRoot() then
		Root.CFrame = CFrame.lookAt(Root.Position, Root.Position + Flat)
	end
	GunAimUI.Sends += 1
	RequestRemote:FireServer("Shoot", "Fire", Dir)
	GunAimUI.Kick()
end
function GunAimUI.FireInput(Began)
	if Began == false then FireHeld = false return true end
	local C = Char()
	if not C or C:GetAttribute("Knocked") or not Shooting() then return false end
	FireHeld, FireWanted = true, os.clock()
	if FireLoop then return true end
	FireLoop = task.spawn(function()
		local Sent = -math.huge
		while Shooting() and not C:GetAttribute("Knocked") and (FireHeld or os.clock() - FireWanted <= Cfg.Buffer) do
			if GunReady(C) and os.clock() - Sent >= GunAimUI.HoldGap then
				Sent, FireWanted = os.clock(), 0
				SendShot(C)
			end
			RunService.Heartbeat:Wait()
		end
		FireLoop = nil
	end)
	return true
end

local Owned = false
local function Release()
	if not Owned then return end
	Owned = false
	local C = Char()
	SettingsUI.CameraFree(C and C:FindFirstChildOfClass("Humanoid"))
	local Cross = Crosshair()
	if Cross then
		Cross.Visible = false
		if HomePosition then Cross.Position = HomePosition end
	end
end

function GunAimUI.Start()
	local Cross = Crosshair()
	HomePosition = Cross and Cross.Position
	RunService:BindToRenderStep("RenseiGunAim", Enum.RenderPriority.Camera.Value + 1, function()
		local Gui = UIState.Gui
		local MenuOpen = (Gui:FindFirstChild("bg") and Gui.bg.Visible) or (Gui:FindFirstChild("Dialogue") and Gui.Dialogue.Visible)
		local C = Char()
		local H = C and C:FindFirstChildOfClass("Humanoid")
		if not Shooting() or MenuOpen or not H then Release() return end
		Owned = true
		local CrossNow = Crosshair()
		if CrossNow then CrossNow.Visible = true end
		local Target = GunAimUI.LockedRoot()
		if Target then
			SettingsUI.CameraFree(H) -- LockOn owns the camera; the marker goes onto the target
			if CrossNow then
				local G = CrossNow:FindFirstAncestorOfClass("ScreenGui")
				local P = (G and G.IgnoreGuiInset) and Camera:WorldToViewportPoint(Target.Position) or Camera:WorldToScreenPoint(Target.Position)
				CrossNow.Position = UDim2.fromOffset(P.X, P.Y)
			end
			return
		end
		if CrossNow and HomePosition then CrossNow.Position = HomePosition end
		SettingsUI.CameraLock(C, H, Cfg.ShoulderOffset, false)
	end)
end

return GunAimUI
```

**Notes:**
- **The marker's placement:** `UDim2.fromOffset(P.X, P.Y)` assumes the marker's `AnchorPoint` is (0.5, 0.5) and its parent spans the screen (Task 1's survey). Otherwise convert through the parent's `AbsolutePosition` and say so.
- **The hold cap:** the 0.1 s loop the first draft had could send 10 requests a second while the server refused shots. That drains ServerHandler's shared `Limiter(8, 16)` in about 8 s and then drops the Y mode request. `HoldGap` 0.25 keeps it to 4 a second.

**`ClientHandler.client.lua`:**
- **The require:** `local GunAimUI = require(Modules.UI.GunAimUI)` is declared **above line 84** (after `InCombatMode`), because `SendAim` uses it. `GunAimUI.Start()` is called next to `WeaponManager.StartClient()`.
- **`SendAim()`** sends `GunAimUI.AimDirection()`.
- **`AlchemyAim()`'s target lookup** (lines 184–186) becomes `local TRoot = GunAimUI.LockedRoot()`. The `LockOnModule` local goes. The rest is unchanged.
- **`Shooting`, `FireInput` and the root snap** at lines 225–242 go. `AimToggle` stays.
- **`ClientActions.Register("Fire", function(Began) GunAimUI.FireInput(Began) end)`.**
- **The RMB branch:**
  ```lua
  if State == Enum.UserInputState.Begin then
  	if not GunAimUI.FireInput(true) then RequestRemote:FireServer("Feint") end
  elseif State == Enum.UserInputState.End then
  	GunAimUI.FireInput(false)
  end
  ```

**`HUDUI.lua` `UpdateShooting`:** no "+" `Crosshair` label. The `Hint` is built standalone with the same properties the clone had (`FontFace` from `HUD.CashFrame.Display`).

**`client_checks.lua`** (the harness, Tasks 8–10):
- It's run from the Server in Play. It makes a LocalScript named `GunChecks_TEMP` with this file's source (plugin security sets `Source`) and parents it to `Player.PlayerGui`. It never goes into StarterPlayerScripts.
- The LocalScript writes its result to a StringValue `ReplicatedStorage.GunChecks_TEMP_Out`, which the Server reads, then deletes both.
- Server-side setup (dummies, markers) uses GunKit.

**Checks (this task):**
- **`CrosshairRayMatchesMarker`:** with ShootingMode on and no lock-on, project `CrosshairRay()` 50 studs out back to the screen (per the inset). It lands within 1 px of the marker's centre.
- **`AimHitsMarkerUnderCrosshair`:**
  - a 1 × 1 × 1 anchored marker part (Server, `SmokeKit.TempPart`) 40 studs along `CrosshairRay()`'s direction from its origin;
  - `RayBox(Muzzle, AimDirection(), 120, Marker.CFrame, Marker.Size)` hits;
  - **control:** `RayBox(Muzzle, Camera.CFrame.LookVector, …)` misses.
- **`LockOnAimsAtTarget`:** with LockOn's target set to a GunKit dummy (through the module's own API, from Task 1's survey), the angle between `AimDirection()` and (dummy root − muzzle) is under 0.5°.
- **`ReleaseRestores`:** after ShootingMode goes nil (with the save's shift lock off), `MouseBehavior` is `Default`, `CameraOffset` is zero, and the marker is hidden.
- **`HoldLoopUnderBucket`:**
  - `GunAimUI.ForceAim = (behind the character)`, so the server refuses every shot;
  - `FireInput(true)`, then 10 s, then `FireInput(false)`;
  - `GunAimUI.Sends <= 41`;
  - then the check sends `RequestRemote:FireServer("Shoot", "Mode", false)`, and the Server sees `ShootingMode` nil within 0.5 s;
  - clears ForceAim.

**Steps:**
- [ ] **Step 1: RED.** Play in Ye (`Ye:gun8`). Give the player a Revolver (after step 4's check), and set `CombatMode` and `ShootingMode` (Server).
  - **Today's geometry:** the RED run of the first two checks sets `Humanoid.CameraOffset = Vector3.new(0, 1.5, 0.5)` and `MouseBehavior = LockCenter` **inside the check itself**, then puts both back. That reproduces shift lock's camera without relying on, or writing, the owner's Settings.
  - **The stand-in:** `GunAimUI` isn't there yet, so the checks fall back (pcall) to `Camera.CFrame.LookVector` for `AimDirection` and the viewport centre for `CrosshairRay`.
  - Expected: `AimHitsMarkerUnderCrosshair` fails, and `CrosshairRayMatchesMarker` fails or reports "no marker".
  - **`HoldLoopUnderBucket`'s RED** is run after Step 3, with `GunAimUI.HoldGap = 0.1` set by the check (the first draft's loop). The Mode request is dropped, so it fails.
  - Record.
- [ ] **Step 2:** Make the SettingsUI, GunAimUI, ClientHandler and HUDUI changes. Sync `UI.SettingsUI`, `UI.GunAimUI`, `SPScripts.ClientHandler` and `UI.HUDUI` to both places.
- [ ] **Step 3: GREEN.**
  - Play in Ye: every client check passes, and `HoldLoopUnderBucket` fails only with the 0.1 seam.
  - `Play_Guns` still passes.
  - **By hand:** hold RMB for 2 s with the Revolver. Count the `LastShotAt` changes: 3 or 4. Press Y: the camera returns to normal. With the save's shift lock state, Alt still toggles as before.
- [ ] **Step 4:** `--check` both places.
- [ ] **Step 5: Commit**: `"Gun rework Task 8: aim camera (shared shift-lock block), crosshair on the shot, lock-on aim, capped hold to fire"`.

---

### Task 9: Feedback: recoil, bloom, the hit marker, a blocked line of fire

**Files:**
- **Modify:**
  - `UI/GunAimUI.lua`;
  - `Art/Studio/Guns/client_checks.lua`.

**Interfaces** (existing assets only):
- **`GunAimUI.Kick()`:**
  - If the gun's `Items[WeaponItem].Kick` exists, store `KickLeft = Kick` and `KickAt = os.clock()`.
  - A RenderStep at `Camera.Value + 2` applies `Camera.CFrame *= CFrame.Angles(math.rad(KickLeft * K), 0, 0)`, with `K = 1 − (os.clock() − KickAt) / 0.18` clamped to 0..1.
  - Only while Settings > Camera Shake is on, read where Task 1 found it.
  - **The bloom always plays:** the marker's `Size` × 1.25 for 0.1 s, then its own size (saved at Start).
- **The hit marker:**
  - Watch `LastShotAt`; read `LastShotResult`.
  - **"Hit":** tint the marker (255, 90, 70) and pulse its size 1.35× → 1 over 0.15 s.
  - **"Blocked":** tint it (170, 170, 170).
  - **Then** restore its own colour.
  - **Tint:** `ImageColor3` or `BackgroundColor3`, per the survey's class.
- **The blocked line:** each frame in shooting mode, `Cast` from the muzzle to the aim point. If it hits more than 1.5 studs short, set the marker's transparency (`ImageTransparency`, or `BackgroundTransparency`) to 0.6; otherwise back to its own value.

**New client checks:**
- **`HitMarkerFlashes`:** the Server sets `LastShotResult = "Hit"` and bumps `LastShotAt`. Within 0.05 s the marker's colour differs from its own, and it's back by 0.3 s.
- **`BlockedLineDims`:**
  - a 10 × 10 × 1 `SmokeKit.TempPart` placed 3 studs to the side of the muzzle, on the camera's line of sight but not the head's;
  - the check computes the spot from the muzzle and the camera, not from the marker;
  - the marker's transparency becomes 0.6.
- **`KickRecovers`:** call `Kick()`. The pitch rises, then is back within 0.1° after 0.25 s.

**Steps:**
- [ ] **Step 1: RED.** Add the checks. Play in Ye (`Ye:gun9`): all three fail. Record.
- [ ] **Step 2:** Make the change. Sync `UI.GunAimUI` to both places.
- [ ] **Step 3: GREEN.** Play: every client check passes. By hand: shoot a GunKit dummy, and see the flash and the kick.
- [ ] **Step 4:** `--check` both places.
- [ ] **Step 5: Commit**: `"Gun rework Task 9: recoil, crosshair bloom, hit marker and blocked-line dim (existing marker only)"`.

---

### Task 10: Touch screens

**Files:**
- **Modify:**
  - `UI/MobileControls.lua` (export `Active`);
  - `UI/GunAimUI.lua` (`Assist`);
  - `UI/HUDUI.lua` (the hint);
  - `client_checks.lua`.

**Interfaces:**
- **`MobileControls.Active = Active`:** the existing local at line 166, exported unchanged. Its `ForceMobileControls` player attribute is the test seam; no new seam.
- **`GunAimUI.Assist(Ray, Point)`:**
  - only when `require(script.Parent.MobileControls).Active()` and `Cfg.TouchAssist > 0`;
  - **candidates:** `GunAim.Candidates(World.Live, true)` (direct children: never townsfolk), with a living Humanoid, not your own character, and visible (`GunAimUI.Cast` from the camera reaches it);
  - picks with `GunAim.Assist(Ray.Origin, Ray.Direction, Centres, Cfg.TouchAssist, range + 10)`;
  - returns the pick, or Point.
- **The hint:** when `MobileControls.Active()`, "SHOOTING MODE · hold FIRE to shoot · STOP to leave".
- **FIRE hold:** MobileControls already sends `Began = false` on release (`Press`, lines 91–101); Task 8's handler gets it.

**New client checks:**
- **`AssistOnTouchOnly`:**
  - with the player attribute `ForceMobileControls = true` (set by the check, cleared after), a GunKit dummy 2° off the crosshair at 30 studs is picked;
  - with it cleared, Point is unchanged.
- **`AssistIgnoresTownsfolk`:** a GunKit dummy parented into `World.Live`'s townsfolk folder (Task 1's survey name), at 1°, isn't picked.

**Steps:**
- [ ] **Step 1: RED.** Add the checks. Play in Ye (`Ye:gun10`): `AssistOnTouchOnly` fails (`Assist` is a no-op). `AssistIgnoresTownsfolk` passes alone (nothing is picked); `AssistOnTouchOnly` is its control. Record.
- [ ] **Step 2:** Make the changes. Sync `UI.MobileControls`, `UI.GunAimUI` and `UI.HUDUI` to both places.
- [ ] **Step 3: GREEN.** Play: every client check passes.
- [ ] **Step 4: Studio's device emulator, by hand** (a phone profile), as **its own Play session under the full protocol** (`Ye:gun10b`):
  - AIM shows;
  - hold FIRE fires repeatedly;
  - STOP leaves.

  If the emulator can't be driven, say so; it stays an owner check (Task 13).
- [ ] **Step 5:** `--check` both places.
- [ ] **Step 6: Commit**: `"Gun rework Task 10: touch: hold FIRE, aim assist (MobileControls.Active, never townsfolk), hint"`.

---

### Task 11: Enemy gunners: windup, telegraph, spread, aim at the centre

**Files:**
- **Modify:** `Scripts/ServerScriptService/EnemyService.lua`.
- **Create:** `Scripts/ServerStorage/RenseiTests/Play_GunNpc.lua`.
- **Manifest:** `RenseiTests.Play_GunNpc` (`Create: true`).

**Interfaces:**

**Step A: the seam, with no behaviour change.** Export `EnemyService.GunShot(Rig, WC, Target, Shot)`. It holds today's single-shot body from `Attack`'s gun loop (`Face(Target)` and the `AttackRunner.Run` call, lines 260–264), and `Attack` calls it. `Face` stays a local that `GunShot` uses.

**Step B: the behaviour.** `GunShot` becomes:
```lua
-- one enemy gunshot (gun rework 2026-10-25, PROPOSAL): a 0.35 s windup with the crit telegraph, aimed at the target's centre
-- (was the root's flat look: it missed anyone higher or lower), 2.5 deg spread. Exported for Play_GunNpc.
function EnemyService.GunShot(Rig, WC, Target, Shot)
	local Root = Rig:FindFirstChild("HumanoidRootPart")
	local TRoot = Target:FindFirstChild("HumanoidRootPart")
	local Weapon = WeaponManager.Def(Rig)
	if not (Root and TRoot and Weapon and Weapon.Shots) then return end
	Face(Target)
	local N = Tuning.Weapons.Guns.NpcShot
	local To = TRoot.Position - GunAim.Muzzle(Root.Position)
	if To.Magnitude > 1 then WeaponManager.SetAim(Rig, GunAim.Spread(To.Unit, N.Spread, NpcRandom)) end
	local Def = table.clone(WeaponManager.Resolve(Rig, Weapon.Shots[Shot]))
	Def.Startup, Def.Telegraph = N.Startup, N.Telegraph
	return AttackRunner.Run(WC, Def, Weapon.Class .. "_Shot" .. Shot, {WalkSpeed = 6, Strike = WeaponManager.Fire})
end
```
- Add `local GunAim = require(...Rensei.GunAim)` and `local NpcRandom = Random.new()`.
- **If `Face` is a closure inside the per-enemy function** (it is defined per rig), `GunShot` takes the facing step inline instead: turn the root flat toward the target, the same three lines `Face` uses. Say which in the report.

**`Play_GunNpc`.** A GunKit shooter (a Sykov) and a GunKit dummy as the target; `WC` is `WCS.Character.GetCharacterFromInstance(Shooter)`. Cases:
- **`WindupIsReadable`** (RED: 0.12 today): from the shot's `CombatState = "Startup"` to `"Active"`, 0.35 ± 0.05 s.
- **`HitsATargetAbove`** (RED: today's flat aim passes over the torso):
  - the dummy stands on a 4-stud `SmokeKit.TempPart` block, 15 studs away;
  - with `NpcShot.Spread` set to 0 in Play for this case, then put back, the shot hits.
- **`SpreadStaysInCone`** (RED: today's seam never calls `SetAim`, so the wrapper sees 0 calls):
  - a Play-only wrapper of `WeaponManager.SetAim`, installed and removed by the case, records 30 shots' directions;
  - each is within 2.5° per axis of the line to the target.

**The 60-second watch** (by hand, in the GREEN session):
- `EnemyService.Spawn(Mark)` with an **unparented** Part `Mark` at `GunKit.Spot() + (0, 3, 20)`, with the attributes `EnemyType = "Grunt"` and `Weapon = "Sykov"`.
- **God mode:** the player's character has `AdminGod = true` (Play only).
- It fires, misses sometimes, and reloads.
- Then remove it the way RoadService's ambushes clear theirs (cite the function in the session notes).

**Steps:**
- [ ] **Step 1:** Make Step A, the seam. Sync `RenseiServer.EnemyService` to both places. Write `Play_GunNpc` and sync it.
- [ ] **Step 2: RED.** Play in Ye (`Ye:gun11`): `Play_GunNpc`. All three fail as said. `Play_LindenmoorSmoke` is as before (the seam changed nothing). Record.
- [ ] **Step 3:** Make Step B. Sync it to both places.
- [ ] **Step 4: GREEN.** Play in Ye:
  - `Play_GunNpc` all pass;
  - `Play_Stealth`, `Play_Assault` and `Play_LindenmoorSmoke` as before;
  - the 60-second watch.
- [ ] **Step 5:** `--check` both places.
- [ ] **Step 6: Commit**: `"Gun rework Task 11: enemy gunners: GunShot seam, readable windup, centre aim, spread"`.

---

### Task 12: The sweep in both places

**Files:** none new. This task fixes only what it finds, in the task that owns it (the controller rules).

**Steps:**
- [ ] **Step 1:** `sync.py --check` for Ye and for Foundry: `DIFFER 0 / MISSING 0`. `reload_slot.lua` `check` in both places: `FAIL 0`. `test_sync.py`: green.
- [ ] **Step 2: Play in Ye** (`Ye:gun12`), in this order:
  - `Play_Boot`, then the travel suites as the Foundry plan runs them: Play_Station, Play_Road, Play_Gate, Play_Arrive, Play_Travel, Play_RideEvents;
  - `Test_GunAim`, `Test_GunBalance`;
  - `Play_GunKit`, `Play_Guns`, `Play_GunReload`, `Play_GunNpc`;
  - `Play_Stealth`, `Play_Assault`, `Play_TownsfolkHurt`, `Play_LindenmoorSmoke`;
  - `client_checks.lua`.

  Record every result.
- [ ] **Step 3: Play in Foundry** (`Foundry:gun12`, with Ye in Edit). Foundry runs its own copies of the suites, at GunKit's Foundry spot:
  - `Play_Boot` first (it must lead), then the travel suites as above;
  - `Test_GunAim`, `Test_GunBalance`;
  - `Play_GunKit`, `Play_Guns`, `Play_GunReload`, `Play_GunNpc`;
  - `Play_FoundrySmoke` and `Play_FoundryData`;
  - `client_checks.lua`.
- [ ] **Step 4:** The known failures (Play_Travel 5/2 and Play_RideEvents 8/1 on the owner's ticket) aren't regressions. Anything else is reported.
- [ ] **Step 5: The checkpoint list for Task 13.** Write the package contents:
  - **`Modules`:** TuningConfig, GunAim, WeaponManager, GunAimUI, SettingsUI, HUDUI, MobileControls;
  - **`RenseiServer`:** ServerHandler, `Requests.Shoot`, EnemyService, PositionHistory;
  - **`ClientHandler`;**
  - **place changes in both:** `Assets.Animations…Guns_Reload` (the owner's id) and the RenseiTests suites;
  - whether the Tutorial place carries `Modules` (the controller's answer).
- [ ] **Step 6:** No commit unless something was fixed. A fix is committed with its owning task's files: `"Gun rework Task 12: <what>"`.

---

### Task 13: Docs, the Changelog entry and the held Discord post

**Files:**
- **Modify:**
  - `Documents/Changelog.md`;
  - `Documents/COMBAT_SYSTEM.md`;
  - `Documents/Controls.md`;
  - `Documents/Animations.md`;
  - `Documents/Backlog.md`.

**Interfaces.** The content each document must hold. Facts and counts come from Tasks 1–12's reports.

**`COMBAT_SYSTEM.md`:** the Guns row and a short "Guns" section:
- shooting mode's aim camera and crosshair;
- the per-gun table (Damage, Magazine, Reload, fire interval, Range and falloff);
- Point Blank;
- flinch within 25;
- 2 meter per hit;
- Fan the Hammer 12 × 3;
- the reload (automatic, the top-up, the interrupt, the owner's animation);
- shooting mode ends in water;
- lag compensation's cap;
- the Fire limits (5 a second on the server, 4 a second from the hold).

Each number is marked PROPOSAL.

**`Controls.md`:**
- RMB: "With guns in shooting mode: fire (hold to keep firing)".
- Y: "the camera moves over your shoulder while it's on".
- The touch table gains **Aim / Stop (with a gun, in Combat Mode) → Y** and **Fire (hold to keep firing; shows while shooting) → Right Mouse**.
- A line: "On touch screens, shots near an enemy lean onto them."

**`Animations.md`:** a Weapons row:

| Sheet | Game name | Status | Used by |
|---|---|---|---|
| Gun Reload (owner, 2026-10-25) | `Guns_Reload` (97563934064498) | ✅ or ⏳ per Task 1 | the automatic reload, fitted to the reload time (`AnimLength`) |

**`Backlog.md`:**
- The gun class rework item is ticked, with a pointer to the Changelog entry.
- **Follow-ups:**
  - a touch lock-on button;
  - review the PROPOSAL decisions in the spec's §8.
- **If Task 1 found the id unloadable:** "the reload animation 97563934064498 didn't load: owner to check its upload".

**`Changelog.md`:** one entry, `## 2026-10-25 — Guns rework: aiming fixed, the class rebalanced, the reload animation (not live)`. It holds:
- what was wrong (the spec's A1–A8 and B1–B7, one line each);
- what changed;
- the owner's decisions kept, and the owner's reload id;
- **"Decisions taken without the owner"** (the spec's §8, short);
- every test count from Tasks 1–12;
- "Not tested": the phone, if Task 10 couldn't drive it, and two real players;
- the backups `RenseiBackups["Pre-GunRework_2026-10-25"]` in both places;
- **the rollback order** (Edit):
  1. revert the scripts from that backup in both places, for this plan's labels;
  2. delete the scripts this plan created (GunAim, GunAimUI, PositionHistory, GunKit, Play_GunKit and the five gun suites) in both places;
  3. `reload_slot.lua` undo in both places.

  SmokeKit and Play_Stealth go back from the backup like any other script.
- **the publish checkpoint** (Task 12, step 5), in the World Travel.md §10 order:
  1. packages from Ye;
  2. Foundry's packages updated by hand and checked with `sync.py --check`;
  3. the places;
  4. Migrate to Latest Update last.

  It goes **with whatever the owner chose at the Task 2 gate**: after the joint Ye + Foundry publish, or folded into it.

**Its `### Discord announcement`:**
- It starts "Hold: not live yet. Post this when the owner publishes the gun update."
- Then a ```md block, under 2,000 characters, plain and player-facing, with no file names, test numbers or PROPOSAL tags. It covers:
  - shooting mode now aims where your crosshair is: the camera moves over your shoulder, and locked-on shots go to your target;
  - hold right mouse (or FIRE) to keep shooting;
  - each gun feels different:
    - Revolver: a hard-hitting hand cannon;
    - Renetti: quick and close;
    - Forge Tac: a long-range marksman pistol;
    - Sykov: the all-rounder;
  - hits flash your crosshair, and guns kick;
  - **a new reload animation;** reloading is still automatic and now also tops up when you leave shooting mode; getting hit interrupts it;
  - Fan the Hammer is a close-range move now;
  - you can't shoot while swimming;
  - bandit gunners give you a moment to react and don't hit every shot;
  - touch players get a little aim help.

  If the id didn't load, drop the reload-animation line.

**Steps:**
- [ ] **Step 1:** Write the docs. Every number comes from a task report or from TuningConfig as committed.
- [ ] **Step 2:** Check that the Discord block is under 2,000 characters (count it with `python -I -c`), and that it has no file names, test counts or PROPOSAL.
- [ ] **Step 3:** This is the plan's only Changelog entry.
- [ ] **Step 4:** The controller names the checkpoint to the owner in chat. This plan publishes nothing.
- [ ] **Step 5: Commit** the five docs: `"Gun rework Task 13: docs, changelog (held Discord post)"`.

---

## Self-review notes

**Coverage of the request:**
1. **"Fix gun shoot mode aiming mechanics":**
   - parallax and shift lock: Tasks 2 and 8;
   - lock-on: Task 8;
   - the free mouse: Task 8's aim camera;
   - the crosshair tied to the shot: Task 8;
   - turn-and-shoot: Task 5's refusal plus Task 8's facing;
   - moving targets: Task 6;
   - eaten clicks: Task 8, capped;
   - NPC aim: Task 11;
   - touch: Task 10;
   - water: Task 5.
2. **"Balance out the gun class completely":**
   - the numbers and identities: Task 3, against bands;
   - Fan the Hammer and the Mastery bug: Task 3;
   - meter, whiff and flinch range: Tasks 3 and 5;
   - PvE fairness: Task 11;
   - anti-exploit: Tasks 2, 5 and 6.
3. **"Add a reload animation":** the owner's 97563934064498, checked in Task 1, length set in Task 3, played in Task 7, with an empty-id fallback only if it doesn't load.

**The pre-flight findings, and where each is built:**

| # | Finding | Where |
|---|---|---|
| 1 | Owner gate | Header (Task 2 after the owner's answer; Task 3 after the spec is seen; Task 3 changes live balance) |
| 2 | The reload id through the tasks | Tasks 1, 3, 7, 13; spec §5.3, §6, §8 #15 |
| 3 | IFramed dummies | Task 4 (`MakeCombatant`, `Play_GunKit`'s control) |
| 4 | The rate limit | `GunAim.Limiter` + `LimiterCaps` (Task 2); first in the Fire branch (Task 5); the hold cap + `HoldLoopUnderBucket` (Task 8) |
| 5 | Top-up for NPCs | WeaponManager `Track` listener (Task 7); `TopUpOnModeOff` on a GunKit shooter |
| 6 | Play_GunNpc | `EnemyService.GunShot` seam (Task 11); the watch via `EnemyService.Spawn` on an unparented mark |
| 7 | RED expectations | Each case's RED / guard status in Tasks 2–11; positive controls in `RewindCapped` and `MasteryDoesNotDeepen`; the Range fallback; `FAN = 12` |
| 8 | Sync tool | Task 1 (keyword `backup=`, the name check, skip if present, missing-Repo report); the manifest rules and the swim-plan rule in Global Constraints |
| 9 | ClientHandler and client checks | Task 8 (`GunAimUI` declared above line 84; CameraOffset set inside the RED check; TEMP in PlayerGui; removal in the unhook step) |
| 10 | No duplicated logic | `GunAim.Candidates`, `SettingsUI.CameraLock` / `CameraFree` with the wall and swim guard, `MobileControls.Active`, `EnemyService.MakeCombatant`, `GunAimUI.LockedRoot` for `AlchemyAim`, SmokeKit `TempPart` / `Guarded` from Play_Stealth |
| 11 | Water | Task 5 (`Traversal` watched; `ShootingModeEndsInWater`) |
| 12 | Foundry parity | `GunKit.Spot` per place (survey), the suites in both places, the travel suites with Play_Boot first (Task 12) |
| 13 | Minors | `History()` requires; `ReloadCfg`; `M ~= Shooter`; the 80→90 note; `AimFresh` 0.75 + `AimFreshCoversFan`; the held-Tool check (protocol step 4); Task 10b under the full protocol; the spec's `AttackRunner.lua:292` |

**Order and dependencies:**
- 1 now;
- the owner gate before 2; the spec gate before 3;
- 2 before 3–6, 8 and 11 (GunAim);
- 3 before 5 (the numbers);
- 4 before 5–7 and 11 (the kits);
- 5 before 6 (`ShotTarget`) and 7;
- 8 before 9 and 10;
- 12 after 1–11; 13 last.

Play sessions are serial across the places. `survey_guns.lua` and `reload_slot.lua` run in Edit.

**Each task can be rejected on its own:**
- Task 1: tooling and survey.
- Task 2: unused maths.
- Task 3: numbers (revert it alone to undo the balance).
- Task 4: kits, with a behaviour-neutral EnemyService refactor.
- Task 5: the server path.
- Task 6: removable (without PositionHistory, `ShotTarget` uses current positions).
- Task 7: a reversible slot plus the reload logic.
- Tasks 8–10: client only.
- Task 11: NPCs only.

**Names used across tasks:**
- the backup `Pre-GunRework_2026-10-25`;
- the flag `GunReloadSlot` (holds the id written) and the mark `GunReworkAdd`;
- the attributes `LastShotResult`, `LastShotAt` and `GunSnapCount`;
- `TuningConfig.Weapons.Guns.Aim`, `.Reload`, `.NpcShot` and `Meter.OnShotHit`;
- `GunAim.Candidates` and `.Limiter`;
- `WeaponManager.ShotTarget` and `CancelReload`;
- `PositionHistory.At`;
- `EnemyService.MakeCombatant` and `GunShot`;
- `SettingsUI.CameraLock` and `CameraFree`;
- `MobileControls.Active`;
- `GunAimUI.AimDirection`, `.FireInput`, `.LockedRoot`, `.CrosshairRay`, `.Kick`, `.Assist`, and the seams `Sends`, `HoldGap` and `ForceAim`;
- `SmokeKit.TempPart`, `ClearTemp` and `Guarded`;
- `RenseiTests.GunKit` (`Spot`, `Dummy`, `Shooter`, `Shot`, `Clean`);
- the TEMP client checker `GunChecks_TEMP`.

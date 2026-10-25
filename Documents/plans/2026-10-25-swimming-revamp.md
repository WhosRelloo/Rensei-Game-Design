# Swimming Revamp Implementation Plan

> **Owner update (2026-10-25), overrides the slot text below:**
> - **Climbing out:** use the game's existing **ledge-climb** animation, the one played when you pull up onto a ledge. In the repo's JumpManager that pull-up plays `Vault1`/`Vault2`. Task 1's Studio survey confirms which `Assets.Animations` entry is the ledge climb (and whether a dedicated ledge-climb id exists) and uses that one.
> - **Underwater idle:** use the surface idle, `Swim_Idle`.
> - So **`Swim_ClimbOut` and `Swim_UnderIdle` are not new slots any more**. The owner only needs to upload **two** animations: `Swim_Dive` and `Swim_Surface`.
> - **The Ye plunge hole is APPROVED** (owner, 2026-10-25: "The deep diving hole in Ye's gorge is a good idea (you can work on that in studio I don't want to open blender yet)"). The optional Task 8 is in scope. It is **Studio-only, with no Blender**: a reversible Studio script carves the terrain hole and resizes the Baseplate around it, with a restore guard, as planned.
> - **Placeholders (owner, 2026-10-25: "Use placeholders for the other 2 animations"):** `Swim_Dive` and `Swim_Surface` are created **filled**, not empty.
>   - `Swim_Dive` copies `Swim_Forward`'s AnimationId, played with the body pitched down.
>   - `Swim_Surface` copies `Swim_Idle`'s AnimationId, played once, briefly.
>   - Each slot carries the attribute `Placeholder = true` and the name of the animation it copies.
>   - To swap in a real animation later, paste its id into the slot and clear `Placeholder`. No code changes.
>   - The undo refusal for owner-filled slots does not apply while `Placeholder` is true.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Every implementer gets the **Global Constraints** and the **Studio facts** below together with its own task.

**Goal:** the owner's Backlog item, "Completely audit and revamp the swimming system. (I want it to be directional, with a dive system)". When this plan is done:
- swimming is directional: level at the surface, fully camera-relative in 3D underwater, and the body pitches into the dive;
- you dive with Ctrl (or a touch DIVE button), sink and rise with Ctrl and Space, surface, and climb out at low ledges;
- the air meter is built from the HUD's own bar;
- breath counts for anyone under water;
- diving is a deliberate stealth tool rather than an accidental cloak;
- the server sanity-checks swim speed;
- Foundry's 9-deep cooling pond is the dive site, and Ye optionally gets one 13.2-deep plunge hole.

Both places get the same code. Nothing is published.

**Spec:** `Documents/specs/2026-10-25-swimming-revamp-design.md`. Its §1 is the audit (findings A1–A18, with file:line evidence), and its §12 lists the decisions taken without the owner.

**When:** after the Foundry Yard plan's Task 10 (the joint Ye + Foundry publish checkpoint), in Backlog order, next to the gun class rework. **The gun rework plan (`2026-10-25-gun-rework*`) edits some of the same files** (`TuningConfig`, `MobileControls`, maybe `Perception`). Whichever plan runs second:
- starts each task by running `sync.py --check` in both places;
- edits the repo file (which holds both plans' changes), then syncs it;
- never syncs an older copy over the other plan's work.

**Architecture:** five layers.
1. **Pure maths:** `Rensei.SwimLogic` (velocity, mode switch, dive depth, breath, climb-out, speed strikes), tested with no character.
2. **Server rules** (`SwimService`):
   - `Submerged`;
   - breath for anyone under water;
   - `WaterDepthAt`;
   - the speed check.

   The Swim state, sprint and drowning are unchanged.
3. **Client movement:** the new `Managers.SwimController` (`LinearVelocity` + `AlignOrientation` on its own `SwimAttachment`), started by `SwimClient`. SettingsUI's shift lock yields to it underwater.
4. **Presentation:**
   - four empty animation slots with fallbacks (a reversible Studio script);
   - the air meter, cloned from `HUD.Stats.BlueBar`;
   - the touch DIVE button;
   - stealth (sight × 0.3 when submerged, water no longer blocks rays) and two noises.
5. **Water:** Foundry's pond needs nothing. Ye's optional plunge hole is a reversible Studio script.

**Tech Stack:** Roblox Studio Luau through `Art/Tools/rbxc.py`; Python 3.14 (stdlib only) for the sync tool and its tests; the Studio MCP's `user_keyboard_input` for the real-input checks.

---

## Studio facts (from the docs and the repo, 2026-10-25; Task 1 re-measures every one)

Implementers use Task 1's measured numbers once it reports. Until then, these are what the docs say.

**Places and windows:**
- Ye: placeId 106992859583940, window "[CLOSED TESTING] Rensei".
- Foundry: placeId 109591196441030, window "Foundry Yard".
- Get each window's `studio_id` from `python -I Art/Tools/rbxc.py studios`.
- Never touch the window "bloodydeadpool53's Place".

**Water:**

| Place | Water | Where | Top | Bed | Depth | Source |
|---|---|---|---|---|---|---|
| Ye | Mill Pond | centre (−110, −553), flat floor radius 11, banks to 19 | 5.2 | 0 (Baseplate top) | 5.2 | Changelog 2026-10-18 |
| Ye | Gorge Pool | centre (226, −551.5), about 46 × 20, under the village ledge walk | 5.2 | 0 | 5.2 | Changelog 2026-10-18 ("Swimming extras") |
| Ye | creek and gorge channels | `Art/Regions/Lindenmoor/water_segments.json` | 5.2 | 1 | 4.2 | the import |
| Foundry | cooling pond | Rect x 420..560, z −196..−100; ground top 4 around it | 3 | −6 (part slabs, `Map.Foundry.Ground`) | 9 | `Art/Regions/Foundry/water.json`, Foundry Yard Kit |

- **Ye's Baseplate:** `workspace.World.Map.Baseplate`, size 2048 × 16 × 2048 at (0, −8, 0), so its top is y 0 (`Art/Studio/Regions/Lindenmoor/ye_survey.json`).
- The gorge fix and bed fix regions start at x 336 (`gorge_fix.lua`, `bed_fix.lua`), so the Gorge Pool (x about 203..249) is outside them.

**Part budgets:** Ye had 76,373 BaseParts in workspace (ceiling 80,000), and Foundry's map 43,685 of its 45,000 (2026-10-24). Re-measure.

**Scripts (from the repo; Studio paths confirmed in Task 1):**
- `ServerStorage.RenseiServer.SwimService`;
- `ServerStorage.RenseiServer.ServerHandler.Requests.Swim` (unchanged by this plan);
- `StarterPlayer.StarterPlayerScripts.SwimClient` (a LocalScript, place-owned, in both places per the Foundry plan's "the same in both places");
- `ReplicatedStorage.Modules.Data.Rensei.TuningConfig`;
- `ReplicatedStorage.Modules.UI.MobileControls`;
- `ReplicatedStorage.Modules.UI.SettingsUI`;
- `ServerStorage.RenseiServer.PerceptionService`;
- `ServerStorage.RenseiServer.NoiseService`;
- `ReplicatedStorage.Modules.Data.Rensei.Perception`.

`Modules.UI.Fill` and `StarterGui.Uis` aren't in the repo; they are read in Studio.

**Animations:**
- `Assets.Animations.Shared.Movement.Swim` holds `Swim_Idle`, `Swim_Forward` (114885907475368) and `Swim_Sprint`. The other two ids aren't in the repo.
- `Assets` is a package in both places.
- `AnimationManager` keys animations by **name across all of `Assets.Animations`**, so a new name must not already exist anywhere there.

**Old swim backups in Ye's `RenseiBackups`:** `Pre-Swimming_2026-10-18`, `Pre-EnemySwim_2026-10-18`, `Pre-SwimExtras_2026-10-18`, `Pre-SwimTouch_2026-10-18` and `Pre-DrownTuning_2026-10-18`. Leave them alone.

---

## Global Constraints

**Owner rules:**
- "Do not publish the Roblox game or modify live player data."
- "Do not expose API keys, credentials, private player data, or other secrets."
- "Do not blindly copy another game's code or assets."
- **UI:** use only the game's existing UI assets. The air meter is a run-time clone of `HUD.Stats.BlueBar`; the DIVE button uses MobileControls' slot plate. No new images, fonts or ScreenGuis, and no `StarterGui` edits.
- **Owner decision 6 stands:** no combat or alchemy while swimming, at the surface or underwater, for players and enemies.
- **Kept owner-era numbers:** sprint ×1.6 for 14 stamina/s, 15 s of air, drowning at 6% of max HP per second.
- **`Documents/CLAUDE.md`:** don't delete, rename or rewrite a script without saying why. `SwimClient` keeps its name and job. The movement goes into the new `SwimController`, and the old SwimClient is backed up (spec §12, decision 14).

**Labels and records:**
- Label every invented number and name **PROPOSAL** in code comments and docs.
- No task writes a Changelog entry except Task 10, which writes one entry for the whole plan.
- Implementers report to the controller in their final message.
- Implementers never dispatch subagents and never write under `.superpowers/`: the harness refuses it.
- **No animation asset id is ever invented.** The new slots stay empty until the owner uploads.

**Studio bridge:**
- Run Luau with `python -I C:/Users/Owner/Rensei-Game-Design/Art/Tools/rbxc.py luau "placeId: <id>" <Edit|Server|Client> @file.lua`.
  - Only the first return value prints, cut at 30,000 characters.
  - Return compact summaries. To return more, write it to a StringValue in ServerStorage, read it back in 25,000-character chunks, and delete it.
- Studio state: `rbxc.py call get_studio_state '{"studio_id":"<id>"}'`.
- Play: `rbxc.py call start_stop_play '{"is_start":true|false,"studio_id":"<id>"}'`.
- Real input (Task 9 only): `rbxc.py call user_keyboard_input '<json>'`. Read the tool's schema first with `rbxc.py tools`.
- **Foundry quirk:** rbxc sometimes returns "Target is not reachable (DMN_ID_EDIT)" even though the call ran. Before retrying anything that isn't idempotent, read the state the call would have changed.
- Put scratch files in `C:/Users/Owner/AppData/Local/Temp/claude/C--Users-Owner/ecd4cd55-01de-4070-9638-cb228809b769/scratchpad/swim-plan/`.

**Play** is hooked and protected, because Play writes the owner's REAL save.
- **One Play session at a time across Ye and Foundry.** Before Play:
  - `get_studio_state` must show the **other** place in Edit;
  - Ye's `game.ServerStorage:GetAttribute("PlayLock")` must be nil.
- **The order, every session:**
  1. In Ye (Edit), set `game.ServerStorage:SetAttribute("PlayLock", "<Ye|Foundry>:swim<task>")`. When playing Foundry, set the same attribute in Foundry too.
  2. In the playing place (Edit), run `C:/Users/Owner/.claude/jobs/0c39df78/tmp/blender/hook.lua`, then install the dump helper: `rbxc.py luau "placeId: <id>" Edit @Art/Studio/Regions/Foundry/data/dumphelper.lua` (returns "dump helper installed").
  3. Start Play. In the Server data model, wait until `game.ServerStorage:GetAttribute("LMSnapTaken")` is set. **Then dump `Data.Quests`:** `return game.ServerStorage:WaitForChild("LMQuestDump", 30):Invoke()`, saved to the scratch folder as `quests_swim<task>_1.txt`.
  4. Run the suites: `game.ServerStorage.LMRunSuite:Invoke("<Suite>")` (Server), plus this task's Client checks.
  5. **Put the character back:** every test that moves, anchors or wets the real player's character restores its CFrame, its `Anchored`, its `Breath` and `Drowning` attributes (both nil) and its Combat Mode before it returns.
  6. `game.ServerStorage.LMTestHook:Invoke("restore")` (Server). It must return "restored".
     - `LMTestHook:Invoke("diff")` still lists Settings, Story, Morality and other keys after a restore. That is an encode quirk, not a real change.
     - **Dump `Data.Quests` again** (`quests_swim<task>_2.txt`). It must equal the first dump character for character. If it differs: stop, keep Play running, and report both dumps to the controller.
  7. Stop Play.
  8. In Edit, run `C:/Users/Owner/.claude/jobs/0c39df78/tmp/blender/unhook.lua`, then remove the dump helper: copy `dumphelper.lua` to the scratch folder, set only its MODE line to `"remove"`, and run the copy (returns "removed <n>").
  9. Only then, clear PlayLock in both places.
- **Script edits are refused while Play runs.**
- **The real player is never drowned.** Drowning and knock-outs are tested on an anchored test rig. A real-input dive (Task 9) stays under for less than 10 s, within the 15 s of air.
- **In Play, the world is a copy.** Map and terrain changes made in Play vanish at Stop. Save data is real: the hook's restore puts it back.

**Edit's require cache.** Edit keeps a module's result between `execute_luau` calls, so an Edit run after a script edit sees the old module. Run any suite that requires a module changed in this plan **in the Play VM** (`LMRunSuite`). Edit runs are only for Studio scripts that require no changed module (Task 1's survey, Task 4's slots, Task 8's plunge hole).

**Scripts live in both places.**
- **Every shared script** is edited in the repo first, then set into **both** places with the sync tool:
  ```
  python -I Art/Studio/Regions/Foundry/data/sync.py --place ye|foundry --backup Pre-SwimRevamp_2026-10-25 --only <label>[,<label>...] --run
  python -I Art/Studio/Regions/Foundry/data/sync.py --place ye|foundry --check
  ```
- `--check` must print `DIFFER 0 / MISSING 0` for **both** places at the end of every task that touched a script.
- Each task adds its own pairs to `Art/Studio/Regions/Foundry/data/sync_manifest.json` (the Foundry plan's Task 1 format).
- **Backups:** with `--backup Pre-SwimRevamp_2026-10-25` (Task 1 adds the option), the tool clones a script once, before its first change, into `ServerStorage.RenseiBackups["Pre-SwimRevamp_2026-10-25"]` in that place. **Never sync this plan's scripts without `--backup`:** the default folder, `Pre-FoundryData_2026-10-24`, already holds older copies of some of them, so an undo from it would drop the Foundry plan's work.
- **The normalised hash** (Studio == repo means these strings are equal) is the one in `sync.py` (`norm_hash`) and in the Foundry plan's Global Constraints.

**Reversible Studio scripts** (Task 4's animation slots and Task 8's plunge hole) follow the Lindenmoor fix scripts' contract (`Art/Studio/Regions/Lindenmoor/shelters.lua` is the model):
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
  - marks every instance it creates with its `...Add = true` attribute, and every instance it changes with its `...From` attribute (the old value, as JSON).
- **`undo`:**
  - restores exactly those, and clears the flag;
  - refuses while Play runs or PlayLock is set.
- **`check`:**
  - lists failure conditions only, and returns `PASS n / FAIL n`;
  - compares against measured values or a baseline `apply` recorded, never against a value it reads at check time from the thing it checks.
- Each mode returns a one-paragraph summary.
- To run another MODE, copy the committed file to the scratch folder and edit only its MODE line there.
- **Backups carry no live CollectionService tags.** Anything moved into `RenseiBackups` has its tags written into the attribute `RegionKitTags` and removed. Undo puts them back.

**Tests:**
- **No duplicated test logic.** Shared helpers live in one module (`RenseiTests.SwimKit`, made in Task 3) and are required, never copied. `SmokeKit` and `PathKit` are reused where they fit.
- **RED then GREEN.** Every new check is run once where it **must fail** (before the change, or with a deliberate break made in Play), and fails. Then it passes after.
- A check that cannot fail is not a check (Lindenmoor Ruling 41). Never pick a test spot or input by reading the property under test: water spots come from Task 1's survey files, not from the water at test time.
- When a check fails, fix the cause in the task that owns it (the controller rules), never by loosening the check.

**Publish order** (`Documents/World Travel.md` §10):
1. packages from Ye (Modules, RenseiServer, **Assets** for the animation slots);
2. Foundry's packages updated by hand and checked equal;
3. the places;
4. Migrate to Latest Update last.

This plan never publishes.

**Git:**
- Commit by path only: `git commit -m "<msg>" -- <paths>`. Never `git add -A`.
- Never stage `.blend` or `.blend1` files or `Art/Blender.rar`.
- End every commit message with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Implementers don't push.

---

## Decisions taken without the owner, by task

The owner was asleep (overnight go-ahead, 2026-10-25). Each is a PROPOSAL, listed in the spec's §12, and built so the owner can change it by a TuningConfig number or by skipping a task.

| | Decision (PROPOSAL) | Task |
|---|---|---|
| 1 | A client swim controller replaces Roblox's swim steering; the server keeps every rule | 2, 5 |
| 2 | Surface swimming is level; only a dive takes you under (looking down no longer dives) | 2, 5 |
| 3 | Dive = tap Ctrl at the surface; hold Ctrl to sink, Space to rise; touch DIVE in Slide's spot | 5, 6 |
| 4 | Underwater: camera-relative 3D, level strafe, a 1.5 studs/s drift up | 2, 5 |
| 5 | The new numbers (UnderSpeedMult 0.85, Ascend/Descend 10, Dive 16 for 0.35 s, DiveMinDepth 4.5, SurfaceBand 0.6, MaxPitch 80°, ClimbOut 4.5 / 3, sprint breath × 1.5) | 2 |
| 6 | Breath counts whenever the head is under water, not only in the Swim state | 3 |
| 7 | A low-ledge climb-out with Space | 2, 5 |
| 8 | Water no longer blocks sight; a submerged target is seen at × 0.3; noises Surface 6 and Stroke 8 | 7 |
| 9 | Enemies don't dive | — (unchanged) |
| 10 | The speed check only logs and stops the sprint; it never teleports | 3 |
| 11 | Foundry's pond is the dive site; Ye's plunge hole in the Gorge Pool is optional | 8 |
| 12 | Four new animation slots, empty, each with a fallback | 4 |
| 13 | The air meter is a clone of the HUD's Meter bar | 6 |
| 14 | SwimClient keeps its name and job; the movement goes into SwimController | 5 |

---

## File map

| File | Responsibility | Task |
|---|---|---|
| `Art/Studio/Regions/Foundry/data/sync.py`, `test_sync.py`, `sync_manifest.json` | `--backup`; this plan's pairs | 1 (pairs in each task) |
| `Art/Studio/Swim/survey_swim.lua` (new), `survey_ye.json`, `survey_foundry.json` (new, written from its output) | Read-only survey of both places | 1 |
| `Scripts/ReplicatedStorage/Modules/Data/Rensei/SwimLogic.lua` (new) | Pure swim maths | 2 |
| `Scripts/ReplicatedStorage/Modules/Data/Rensei/TuningConfig.lua` | `TuningConfig.Swim` new keys | 2 |
| `Scripts/ServerStorage/RenseiTests/Test_SwimLogic.lua` (new) | Pure tests | 2 |
| `Scripts/ServerScriptService/SwimService.lua` | `Submerged`, breath for all, `WaterDepthAt`, the speed check | 3 |
| `Scripts/ServerStorage/RenseiTests/SwimKit.lua`, `Play_Swim.lua` (new) | Test rig and spots; server suite | 3 (7 adds to Play_Swim) |
| `Art/Studio/Swim/anim_slots.lua` (new) | Reversible: four empty slots in `Shared.Movement.Swim` | 4 |
| `Scripts/ReplicatedStorage/Modules/Managers/SwimController.lua` (new) | Client movement | 5 |
| `Scripts/StarterPlayer/StarterPlayerScripts/SwimClient.client.lua` | Starts the controller; keys; animations; air meter | 5, 6 |
| `Scripts/ReplicatedStorage/Modules/UI/SettingsUI.lua` | Shift lock yields underwater | 5 |
| `Scripts/ReplicatedStorage/Modules/UI/MobileControls.lua` | DIVE button | 6 |
| `Scripts/ReplicatedStorage/Modules/Data/Rensei/Perception.lua`, `Scripts/ServerScriptService/PerceptionService.lua`, `NoiseService.lua`; `RenseiTests/Test_Perception.lua`, `Test_Sound.lua` | Stealth and noise | 7 |
| `Art/Studio/Regions/Lindenmoor/plunge_hole.lua` (new), `Art/Regions/Lindenmoor/layout.json` (`RestoreRefuseFlags`), `import/restore.lua` (regenerated), `test_ye_fixes.py` | Ye's optional plunge hole and its restore guard | 8 |
| `Documents/Changelog.md`, `Controls.md`, `Animations.md`, `ARCHITECTURE.md`, `Decisions.md`, `Project Status.md`, `Backlog.md`, `Lindenmoor Kit.md`, `Foundry Yard Kit.md` | Docs | 10 |

---

### Task 1: The survey, and the sync tool's backup folder

**Files:**
- Modify: `sync.py`, `test_sync.py`, `sync_manifest.json`.
- Create: `Art/Studio/Swim/survey_swim.lua`, `survey_ye.json`, `survey_foundry.json`.
- **No Studio change.**

**Interfaces:**
- **`sync.py --backup NAME`:**
  - optional; the default stays `Pre-FoundryData_2026-10-24`, so the Foundry plan's commands behave as before;
  - NAME must match `^Pre-[A-Za-z0-9]+_\d{4}-\d{2}-\d{2}$`;
  - it is written into the bundle's `BACKUP`.
  - If the gun rework plan has already added an equivalent option, use that and skip this part.
- **The manifest pairs this task adds** (Places ye and foundry, `Create` false):
  - `Rensei.TuningConfig`;
  - `Rensei.Perception`;
  - `UI.MobileControls`;
  - `UI.SettingsUI`;
  - `RenseiServer.SwimService`;
  - `RenseiServer.PerceptionService`;
  - `RenseiServer.NoiseService`;
  - `SPScripts.SwimClient`: Studio `StarterPlayer/StarterPlayerScripts/SwimClient`, LocalScript, repo `Scripts/StarterPlayer/StarterPlayerScripts/SwimClient.client.lua`.

  Plus, `Create: true`:
  - `Rensei.SwimLogic`;
  - `Managers.SwimController` (`ReplicatedStorage/Modules/Managers/SwimController`);
  - `RenseiTests.Test_SwimLogic`;
  - `RenseiTests.SwimKit`;
  - `RenseiTests.Play_Swim`;
  - `RenseiTests.Test_Perception`;
  - `RenseiTests.Test_Sound`. These two exist in Ye; Foundry may lack them, and they are pure.

  **Skip any label the manifest already has.** Each later task's new repo file must exist before its pair is checked: add a 1-line placeholder only if the tool requires the Repo file to exist, and say so in the report.
- **`survey_swim.lua`:**
  - read-only, `MODE = "survey"`, refuses while Play runs;
  - runs in Edit in each place, and returns one JSON string (through a StringValue if it is over 25,000 characters).
  - **Places and safety:** `game.PlaceId`; PlayLock; the workspace part count.
  - **Scripts:** whether each Studio path in the pair list exists, and its NormHash. Also the full path of `Requests.Swim`.
  - **Animations:**
    - every `Animation` under `Assets.Animations.Shared.Movement.Swim` with its `AnimationId`;
    - whether any instance named `Swim_Dive`, `Swim_UnderIdle`, `Swim_Surface` or `Swim_ClimbOut` exists anywhere under `Assets.Animations`;
    - `Vault1` and `Vault2`, found or not.
  - **Player scripts:** `StarterPlayer.StarterPlayerScripts.PlayerModule`, present or not, and the class of any custom ControlModule; `StarterPlayer.StarterCharacter.Humanoid.WalkSpeed`.
  - **UI:**
    - `StarterGui.Uis.HUD.Stats`'s children (name, class, Position, Size, AnchorPoint), and any UIListLayout or UIGridLayout;
    - `BlueBar`'s descendants (name, class, image ids, TextLabel fonts);
    - whether `ReplicatedStorage.Modules.UI.Fill` exists, with its source's first 40 lines.
  - **Water**, sampled with `Terrain:ReadVoxelChannels` (resolution 4, the `LiquidOccupancy` channel):
    - **Ye** (only when `PlaceId` is Ye's):
      - the Baseplate's full path, CFrame, Size, Material, Color, `MaterialVariant`, and every child (class, Face, StudsPerTileU/V, OffsetStudsU/V, Texture id);
      - for the Gorge Pool and the Mill Pond, a 4-stud grid of columns over a box 8 studs larger than the pool, giving for each column the water top, the first non-water hit (ray down from y 30, `IgnoreWater = true`) with its instance path, material and y;
      - **the Gorge Pool's largest 4-aligned rectangle** whose every column has its bed at y ≤ 0.05 (the Baseplate top) and water to 5.2. Cap it at 24 × 12; report it, or "none ≥ 12 × 8";
      - the `RenseiLedge` part over the Gorge Pool (path and CFrame);
      - any part, other than the Baseplate, within the hole's box from y −16 to 0.
    - **Foundry** (only when `PlaceId` is Foundry's): the same column grid over the pond's Rect, plus 8 studs; the bed parts' paths; the lip height (ground top minus water top) at the four edge midpoints; any low ledges (a top at most 4.5 above the water within 3 studs of the edge).
- **The survey files:** `Art/Studio/Swim/survey_ye.json` and `survey_foundry.json`, written from the returned JSON, pretty-printed and sorted. They are the measured facts every later task uses.

**Steps:**
- [ ] **Step 1: Failing tests in `test_sync.py`:**
  - `--backup Pre-SwimRevamp_2026-10-25` appears in a generated bundle's `BACKUP`;
  - without `--backup`, the bundle still says `Pre-FoundryData_2026-10-24`;
  - a bad name (`Swim`) is rejected;
  - every new manifest label is unique and its Places are `["ye", "foundry"]`.

  Run them: they fail.
- [ ] **Step 2:** Add `--backup` and the pairs. Run `test_sync.py`: all pass, the old tests included.
- [ ] **Step 3: RED in Studio.** Run `--check` in both places. Expected:
  - every existing pair is SAME;
  - the new files (`Rensei.SwimLogic`, `Managers.SwimController`, `Test_SwimLogic`, `SwimKit`, `Play_Swim`) are MISSING;
  - in Foundry, maybe `Test_Perception` and `Test_Sound` too.

  **If any existing pair DIFFERS, stop and report:** a place must equal the repo before this plan copies anything into it.
- [ ] **Step 4:** Run `survey_swim.lua` in Ye, then in Foundry (Edit, no Play). Write the two JSON files. Report:
  - the swim animation ids and the four free names;
  - whether PlayerModule is standard;
  - the HUD.Stats layout;
  - the Gorge Pool rectangle (or "none");
  - the Baseplate's children;
  - the Foundry pond's depth range and lips;
  - both part counts.
- [ ] **Step 5: Commit** `sync.py`, `test_sync.py`, `sync_manifest.json`, `survey_swim.lua` and both survey JSONs: `"Swim revamp Task 1: survey of both places; sync --backup; swim pairs"`.

---

### Task 2: `SwimLogic` and the new tuning (pure)

**Files:**
- Create: `Scripts/ReplicatedStorage/Modules/Data/Rensei/SwimLogic.lua`, `Scripts/ServerStorage/RenseiTests/Test_SwimLogic.lua`.
- Modify: `TuningConfig.lua`.

**Interfaces:**
- **`TuningConfig.Swim` gains** these keys (all PROPOSAL, one comment line each). Existing keys and values are unchanged.
  ```lua
  UnderSpeedMult = 0.85, AscendSpeed = 10, DescendSpeed = 10, Drift = 1.5,
  DiveSpeed = 16, DiveTime = 0.35, DiveMinDepth = 4.5, SurfaceBand = 0.6,
  RootBelowSurface = 1.5, -- (Task 5 re-measures: the root's height under the surface while floating)
  SurfaceHoldGain = 6, SurfaceHoldMax = 8,
  MaxPitch = 80, TurnResponsiveness = 12, MaxForce = 30000, -- (Task 5 tunes MaxForce in Play)
  ClimbOutHeight = 4.5, ClimbOutReach = 3, ClimbOutForward = 30, ClimbOutUp = 30,
  UnderSprintBreathMult = 1.5, SubmergedExitChecks = 2,
  SpeedSlackMult = 1.5, SpeedSlackFlat = 8, SpeedStrikes = 3,
  AnimDive = "Swim_Dive", AnimUnderIdle = "Swim_UnderIdle", AnimSurface = "Swim_Surface", AnimClimbOut = "Swim_ClimbOut",
  ```
  - Update the block's header comment: the controller (SwimController), the dive, and owner decision 6 unchanged.
- **`Rensei.SwimLogic`** (pure: no services, no Instances; takes Vector3 and CFrame values). `T` is `TuningConfig.Swim`.
  - `SwimLogic.Velocity(Mode, Move, CamCF, Input, Speed, T) -> Vector3`
    - Mode is `"Surface"` or `"Under"`.
    - `Move` is the control module's move vector: x = right, z = −forward, magnitude ≤ 1.
    - `Input = {Up, Down, Sprint}` (booleans). `Speed` is the walk speed × SpeedMultiplier.
    - **Surface:** forward and right come from the camera's look and right vectors flattened to Y = 0. The result has Y = 0, magnitude `|Move| × Speed × (Sprint and SprintMult or 1)`. Up and Down are ignored here.
    - **Under:**
      - forward = the camera's full look vector (pitch included, then pitch clamped to ±MaxPitch); right = the camera's right vector flattened;
      - horizontal and pitched part × Speed × UnderSpeedMult × (Sprint and SprintMult or 1);
      - plus Y + AscendSpeed if Up, − DescendSpeed if Down (both cancel);
      - plus Y + Drift **only when** `|Move| < MoveThreshold` and neither Up nor Down.
  - `SwimLogic.SurfaceHold(RootY, SurfaceY, T) -> number`: the vertical speed holding the root at `SurfaceY − RootBelowSurface`, = clamp((target − RootY) × SurfaceHoldGain, −SurfaceHoldMax, SurfaceHoldMax).
  - `SwimLogic.ModeFor(Current, HeadDepth, T) -> "Surface" | "Under"`. HeadDepth = the surface's Y − the head's Y (positive = under).
    - Under → Surface when HeadDepth ≤ 0 (the head breaks the surface).
    - Surface → Under only by a dive (`Current` stays `"Surface"` otherwise), **except** when HeadDepth > SurfaceBand × 4 (sunk by something else, like a knockback), which returns `"Under"`.
  - `SwimLogic.CanDive(WaterDepth, T) -> boolean`: WaterDepth ≥ DiveMinDepth.
  - `SwimLogic.Pitch(V, T) -> number`: the radians of V's pitch, clamped to ±MaxPitch. 0 for a level or zero V.
  - `SwimLogic.BreathStep(Breath, Under, Sprint, Dt, T) -> number`:
    - under: − Dt × (Sprint and UnderSprintBreathMult or 1);
    - else: + BreathRefill × Dt;
    - clamped to 0..BreathMax.
  - `SwimLogic.CanClimbOut(LedgeAbove, Distance, T) -> boolean`: 0 < LedgeAbove ≤ ClimbOutHeight and Distance ≤ ClimbOutReach.
  - `SwimLogic.MaxSpeed(Base, Mult, Sprinting, T) -> number`: Base × Mult × (Sprinting and SprintMult or 1).
  - `SwimLogic.SpeedStrike(Strikes, Moved, Dt, MaxSpeed, T) -> number`: Strikes + 1 when Moved > MaxSpeed × SpeedSlackMult × Dt + SpeedSlackFlat; else 0.

**Steps:**
- [ ] **Step 1: Write `Test_SwimLogic`** (TestKit format). Cases (inputs chosen by hand, never read from the module):
  1. **Surface ignores pitch:** a camera looking 60° down, Move (0, 0, −1), Speed 16 → Y == 0, magnitude 16.
  2. **Under follows pitch:** a camera 45° down, W → V.Unit dotted with the look vector > 0.99, and V.Y < 0.
  3. **Under strafe is level:** a camera 45° down, Move (1, 0, 0) → V.Y == 0.
  4. **Up / Down:** Up gives V.Y = +10 with no Move; Down −10; both 0.
  5. **Drift:** under, no input → (0, 1.5, 0). With Move: no drift term.
  6. **Sprint:** surface W with Sprint → magnitude 16 × 1.6.
  7. **Pitch clamp:** a camera looking straight down, under W → |Pitch| ≤ 80° + 1e-6.
  8. **CanDive:** 4.4 false, 4.5 true, 5.2 true, 4.2 false.
  9. **ModeFor:** Under with depth −0.1 → Surface; Surface with depth 1.0 → Surface; Surface with depth 3.0 → Under.
  10. **BreathStep:** (15, true, false, 1) → 14; (15, true, true, 1) → 13.5; (10, false, false, 1) → 15; (0.2, true, false, 1) → 0.
  11. **CanClimbOut:** (4.5, 3) true; (4.6, 1) false; (2, 3.1) false; (0, 1) false.
  12. **SpeedStrike:** MaxSpeed 16, Dt 0.15. Moved 3 → 0; Moved 20 (over 16 × 1.5 × 0.15 + 8 = 11.6) → Strikes + 1; three in a row → 3; then a normal step → 0.
  13. **SurfaceHold:** a root 2 below target → +8 (clamped); at target → 0.
- [ ] **Step 2: RED.** Sync `Test_SwimLogic` and TuningConfig to both places (with `--backup`). In a Ye Play session (the Play protocol), run `LMRunSuite:Invoke("Test_SwimLogic")`. Expected: every case FAILs (the require errors, or the keys are missing).
  - In the same session, run `Test_Sound` and `Test_Perception` and record their baselines for Task 7.
- [ ] **Step 3:** Write `SwimLogic.lua` and the TuningConfig keys. Sync `Rensei.SwimLogic` and `Rensei.TuningConfig` to both places.
- [ ] **Step 4: GREEN.** Run `Test_SwimLogic` in Play, in Ye, then in a separate Foundry session. Expected: PASS 13 / FAIL 0 in both.
- [ ] **Step 5:** `--check` both places: `DIFFER 0 / MISSING 0` (apart from the pairs whose files later tasks create; list them).
- [ ] **Step 6: Commit** `SwimLogic.lua`, `TuningConfig.lua`, `Test_SwimLogic.lua` and the manifest: `"Swim revamp Task 2: SwimLogic (pure swim maths) and the new swim tuning (PROPOSAL)"`.

---

### Task 3: The server: `Submerged`, breath for everyone under water, depth and the speed check

**Files:**
- Modify: `Scripts/ServerScriptService/SwimService.lua`.
- Create: `Scripts/ServerStorage/RenseiTests/SwimKit.lua`, `Play_Swim.lua`.

**Interfaces:**
- **`SwimService.WaterDepthAt(Position) -> number, number`** (depth, surface Y):
  - the surface is found by a downward ray from Position + (0, 20, 0) with `IgnoreWater = false` that meets terrain Water;
  - the bed by a ray from that surface point down 40 studs with `IgnoreWater = true`, filtered to `workspace.World.Map` plus `workspace.Terrain`;
  - returns 0 and nil where there is no water.
- **`SwimService.Step(Character, Breather)`** (now public). `Breather` is the Player, or `true` in tests:
  - **CombatMode** is turned off only when `typeof(Breather) == "Instance"`;
  - **sprint, breath, `Submerged`, drowning and the speed check** run when Breather is truthy;
  - **enemies** pass nil, as now.
- **`Submerged`:** set to true when `HeadUnderwater` holds; cleared (nil) after `SubmergedExitChecks` checks in a row without it.
- **Breath:**
  - `Under = HeadUnderwater(Character) and not Character:GetAttribute("Knocked")`, **no longer gated on the Swim state** (fixes A8);
  - it uses `SwimLogic.BreathStep`, with `Sprint = Character:GetAttribute("SwimSprint") == true`;
  - drowning is unchanged: `Drowning`, DownedManager.Damage, DrownFraction, at least DrownDamage, every DrownTick.
- **The speed check:**
  - a per-character table `Last = {Pos, Time}`, cleaned in `Forget` with the others;
  - each check while in Swim: `Moved` = the 3D distance, Dt = the time;
  - skipped (strikes reset) while stunned, while `Dashing`, for 1 s after the Humanoid's health last dropped (a hit's knockback), or when the last sample is older than 1 s. MoverManager's movers are made on the client and the server can't see them, so the health drop stands in for "being knocked back";
  - the attribute `SwimSpeedStrikes` = `SwimLogic.SpeedStrike(...)`. At `SpeedStrikes`, clear `SwimSprint`, `warn("SwimService: speed", Player.Name, Moved, Dt, Max)` once, and reset to 0. It never moves the character;
  - MaxSpeed comes from `StarterPlayer.StarterCharacter.Humanoid.WalkSpeed` (Task 1's measured base) × `SpeedMultiplier`, with Sprinting = `SwimSprint`.
- **The header comment** gains a paragraph for the revamp: the controller is client-side; the server owns these rules.
- **`RenseiTests.SwimKit`:**
  - `SwimKit.Spots(PlaceId) -> table`, **hard-coded from Task 1's survey JSONs**, never read at test time. Foundry: `PondDeep` (the pond's deepest surveyed column) and `PondEdge`. Ye: `MillPond` and `GorgePool` (centres), and `Plunge` (Task 8's hole centre; nil until Task 8);
  - `SwimKit.Rig(At) -> Model`: an R6 rig from `Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)`, named `__swimtest_rig`, with its root anchored and its head at `At`, parented to workspace. The caller destroys it;
  - `SwimKit.WithPlayerAt(Player, CF, Fn)`: anchors the real character's root at CF, runs Fn, then restores the CFrame, Anchored, Breath and Drowning (nil) and Combat Mode (pcall), even on error.
- **`RenseiTests.Play_Swim`** (server, Play VM; each test picks its spots from SwimKit for the current place, and skips with a PASS note when the place has none):
  - **`DepthAtTheDiveSite`:**
    - Foundry: `WaterDepthAt(PondDeep)` is within 0.5 of the surveyed depth (about 9);
    - Ye: MillPond and GorgePool are within 0.5 of 5.2.
  - **`SubmergedFollowsTheHead`:** a rig with its head 3 below the surface. Step it 3 times (`Breather = true`) → `Submerged` true. Raise the head 1 above → after 2 steps, nil.
  - **`BreathDrainsForACarrier`:** a rig with `Carrying = "x"` and its head 3 under. Step it 7 times (about 1 s) → `Breath` < BreathMax. **RED before this task:** the old Step leaves Breath nil.
  - **`DrowningHurtsTheRig`:** a rig with `Breath = 0.01` and its head under. Step it until a DrownTick passes → `Drowning` true and the rig's health has dropped by max(DrownDamage, MaxHealth × DrownFraction) ± 1. (Read DownedManager first. If it knocks non-player rigs, also assert that the health is ≥ 1 after enough ticks to empty it; otherwise assert only the drop.)
  - **`SprintRefusedOnLand`:** `Requests.Swim(Player, true)` with the real character on land → `SwimSprint` nil.
  - **`SpeedStrikes`:** on a rig in the Swim state (`MovementState.SetSwim(Rig, true)`): step it, move it 30 studs, step again, three times → `SwimSpeedStrikes` reached SpeedStrikes and reset, and `SwimSprint` cleared. A rig moved 1 stud per step keeps 0. Clear the Swim state after.
  - Every test destroys its rig and clears the attributes it set.

**Steps:**
- [ ] **Step 1:** Write `SwimKit` and `Play_Swim` (spots copied from the survey JSONs). Sync both to both places.
- [ ] **Step 2: RED.** Play in Foundry (the protocol). Run `Play_Swim`. Expected FAILs:
  - `DepthAtTheDiveSite` (no `WaterDepthAt`);
  - `SubmergedFollowsTheHead`;
  - `BreathDrainsForACarrier`;
  - `DrowningHurtsTheRig` (Step isn't public);
  - `SpeedStrikes`.

  `SprintRefusedOnLand` passes (unchanged behaviour), so it is a regression guard, not a new check. Record the counts.
- [ ] **Step 3:** Change `SwimService` and sync `RenseiServer.SwimService` to both places.
- [ ] **Step 4: GREEN.** Play in Foundry: `Play_Swim` 6/0. Then Play in Ye: `Play_Swim` 6/0 (`Plunge` absent) and `Play_LindenmoorSmoke` as before.
- [ ] **Step 5:** `--check` both places.
- [ ] **Step 6: Commit** `SwimService.lua`, `SwimKit.lua`, `Play_Swim.lua` and the manifest: `"Swim revamp Task 3: Submerged, breath for anyone under water, WaterDepthAt, the swim speed check"`.

---

### Task 4: The four animation slots (both places, reversible)

**Files:** create `Art/Studio/Swim/anim_slots.lua`. In Studio, both places' `Assets.Animations.Shared.Movement.Swim`.

**Interfaces:**
- **The flag:** the attribute `SwimAnimSlots` on `Assets.Animations.Shared.Movement.Swim`.
- **`apply` creates four `Animation` instances** with `AnimationId = ""`, each with the attributes `SwimSlotAdd = true` and `Fallback`:
  - `Swim_Dive` (Fallback `"Swim_Forward"`);
  - `Swim_UnderIdle` (Fallback `"Swim_Idle"`);
  - `Swim_Surface` (Fallback `""`, which means none);
  - `Swim_ClimbOut` (Fallback `"Vault1"`).
- **`apply` refuses** when any of the four names exists anywhere under `Assets.Animations` (AnimationManager keys by name).
- **`undo`** deletes exactly the instances with `SwimSlotAdd`, and only while their `AnimationId` is still `""`. If the owner has uploaded one, it refuses and names it.
- **`check`:** the four exist, are empty or hold an `rbxassetid://<digits>` id, and carry their Fallback; no other child of the folder changed (the names and ids recorded at apply).

**Steps:**
- [ ] **Step 1: RED.** `check` in Ye: FAIL 4 (missing).
- [ ] **Step 2:** In Ye, run `test`, then `apply`, then `check` (PASS). Repeat in Foundry.
- [ ] **Step 3: Play in Ye.** Client data model: `AnimationManager.Has(Character, "Swim_Dive")` is false, `Has(Character, "Swim_Idle")` is true, and the output has no animation errors for the four names. This proves an empty slot falls back safely.
- [ ] **Step 4: Commit** `anim_slots.lua`: `"Swim revamp Task 4: four empty swim animation slots with fallbacks (both places, reversible)"`.

---

### Task 5: The swim controller (client movement, dive, climb-out, shift lock)

**Files:**
- Create: `Scripts/ReplicatedStorage/Modules/Managers/SwimController.lua`.
- Modify: `SwimClient.client.lua`, `SettingsUI.lua`.

**Interfaces:**
- **`SwimController`** (client only):
  - `SwimController.Start(Character)` / `Stop(Character)`;
  - `SwimController.Mode` (`nil`, `"Surface"` or `"Under"`);
  - `SwimController.Active()` (true while Mode == "Under");
  - `SwimController.Dive()`, which returns true when the dive started;
  - `SwimController.ClimbOut()`, which returns true when it climbed;
  - `SwimController.Input = {Up, Down, Sprint}`, set by SwimClient each frame.
- **What `Start` builds:** under `HumanoidRootPart`, an Attachment `SwimAttachment`, a `LinearVelocity` (`VelocityConstraintMode = Vector`, `RelativeTo = World`, `MaxForce = T.MaxForce`) and an `AlignOrientation` (`Mode = OneAttachment`, `Responsiveness = T.TurnResponsiveness`, enabled only Underwater). `Stop` destroys them and restores `Humanoid.AutoRotate = true`.
- **Each `RenderStepped` while Started:**
  1. **The move vector:** from `require(Player.PlayerScripts.PlayerModule):GetControls():GetMoveVector()` when Task 1 found the standard PlayerModule; else from `Humanoid.MoveDirection`, converted to camera space.
  2. **The surface:** `SurfaceY` from a downward ray with `IgnoreWater = false` from root + 20 that meets Water. With no water, the controller idles (force 0).
  3. **The mode:** `HeadDepth` = SurfaceY − Head.Y; `Mode = SwimLogic.ModeFor(Mode, HeadDepth, T)`. On Under → Surface, play `AnimSurface` once if `Has`, and fire nothing to the server (the server sees the head itself).
  4. **The velocity:** V = `SwimLogic.Velocity(Mode, Move, Camera.CFrame, Input, Speed, T)`. At the surface, V.Y = `SwimLogic.SurfaceHold(Root.Y, SurfaceY, T)`.
     - Speed is the **base**, `DefaultWS × SpeedMultiplier`, never `Humanoid.WalkSpeed`. The sprint comes only through `Input.Sprint`, which SwimClient sets only while the server's `SwimSprint` attribute is on.
     - So SwimClient **stops changing WalkSpeed** for the sprint (its `SprintSpeed` / `EndSprintSpeed` code goes). The controller's velocity, not WalkSpeed, moves a swimmer now.
  5. **Underwater facing:** `AutoRotate = false`; the AlignOrientation's CFrame = `CFrame.lookAt` towards the flat move direction (or the camera's yaw when idle), rotated by `SwimLogic.Pitch(V, T)` about its right axis.
  6. **Pause:** force 0 while the character has the Stun status, `Dashing`, or any LinearVelocity or AlignPosition under `VelocityAttachment` (MoverManager's knockback and lunge).
- **`Dive()`:**
  - only in Surface, and only when `SwimLogic.CanDive(depth)`, with depth = SurfaceY − the bed (a ray down from the root, `IgnoreWater = true`, filtered to the map and Terrain);
  - it sets Mode = "Under" and plays `AnimDive` (when `Has`);
  - for DiveTime s, V = (look-down 60° along the facing) × DiveSpeed;
  - returns false otherwise.
- **`ClimbOut()`:**
  - only in Surface;
  - a ray forward from the head at the water's surface height, ClimbOutReach long, must hit a part of `World.Map`;
  - a ray down from that hit + (forward 1, up ClimbOutHeight + 1) gives the ledge top. `SwimLogic.CanClimbOut(top − SurfaceY, distance, T)` decides;
  - then: the controller pauses (force 0) for 0.4 s, `MoverManager.Velocity(Character, {D = 0.2, V = Look × ClimbOutForward + (0, ClimbOutUp, 0), Max = Vector3.new(4e4, 4e4, 4e4)})`, and `AnimClimbOut` if `Has`, else `"Vault" .. math.random(1, 2)` at Action4 priority (JumpManager's vault);
  - returns true.
- **`SwimClient`** keeps everything it does today **except Roblox-swim steering**. It:
  - starts and stops the controller on the server's `Traversal == "Swim"` (and the Swimming humanoid state, as now);
  - sets `Input` from Space / Ctrl / Shift (and the touch actions);
  - **Ctrl:** a tap (under 0.25 s) in Surface → `Dive()`; held in Under → Down;
  - **Space:** in Surface, `ClimbOut()` first; if that's false, the old `Humanoid.Jump = true` hop. In Under → Up;
  - **picks the loop animation:**
    - Surface: `Swim_Sprint` / `Swim_Forward` / `Swim_Idle`, as now;
    - Under: `Swim_Sprint` / `Swim_Forward` / `AnimUnderIdle` if `Has`, else `Swim_Idle`;
  - **no longer** sets `Humanoid.Jump` underwater;
  - registers the action `SwimDive` (touch; Began true = Ctrl down) next to SwimSprint and SwimRise.
  - Its header comment is rewritten for the revamp. The breath bar stays until Task 6.
- **`SettingsUI` shift lock:** in the RenderStepped loop, next to `JumpManager.ClimbConn or ...`, also return early when `require(ReplicatedStorage.Modules.Managers.SwimController).Active()`. Add one comment line.

**Steps:**
- [ ] **Step 1: The spike (Play in Foundry, Client data model, in a scratch LocalScript, nothing committed).** With the character floating in the pond:
  - create an AlignOrientation on a new attachment, pitched 45° down, for 2 s;
  - report whether the root really pitched (the root's LookVector.Y), and the root's height under the surface while floating (for `RootBelowSurface`);
  - give a LinearVelocity of (0, −10, 0) at MaxForce 30,000 for 1 s and report the depth reached.

  **If the root doesn't pitch,** the controller skips step 5's pitch (it keeps the yaw) and the report says so: that is spec §2's fallback.
  Update `RootBelowSurface` and `MaxForce` in TuningConfig from the measurements (PROPOSAL) and sync.
- [ ] **Step 2: The Client checks, RED.** Write `Art/Studio/Swim/client_checks.lua`, a Client-data-model script returning PASS/FAIL lines. It is a committed test script, not a RenseiTests suite, because the server VM can't see the client. It:
  - puts the character at `PondDeep`'s surface (in Play, with the anchored root released) with the camera pitched 60° down and a scripted move vector, through `SwimController.Input` and a test hook `SwimController.TestMove` (a Vector3 that replaces the control module's vector while set; documented as tests only);
  - **`LevelAtTheSurface`:** after 2 s with W held, the head is still within SurfaceBand of the surface;
  - **`DiveGoesUnder`:** `Dive()` returns true, and after 1 s HeadDepth > 2;
  - **`SteersDown`:** Under, camera 45° down, W for 1 s → the root's Y fell by more than 3;
  - **`RisesToSurface`:** Up for up to 3 s → Mode == "Surface";
  - **`NoDiveInTheShallows`:** in Ye, at a creek-channel spot from the survey (4.2 deep) → `Dive()` false;
  - **`ShiftLockYields`:** with the setting `ShiftLock` on and Under, `Humanoid.AutoRotate` stays false for 30 frames.

  Run it before the controller exists: every check FAILs (the require errors).
- [ ] **Step 3:** Write `SwimController`, and change `SwimClient` and `SettingsUI`. Sync `Managers.SwimController`, `SPScripts.SwimClient` and `UI.SettingsUI` to both places.
- [ ] **Step 4: GREEN.**
  - Foundry Play: `client_checks.lua` all PASS (`NoDiveInTheShallows` is skipped there), plus `Play_Swim` 6/0.
  - Ye Play: `client_checks.lua` (`NoDiveInTheShallows` and `LevelAtTheSurface` at the Mill Pond) all PASS; `Play_Swim` 6/0.
  - The output has no errors from SwimController, SwimClient or SettingsUI.
- [ ] **Step 5:** `--check` both places.
- [ ] **Step 6: Commit** `SwimController.lua`, `SwimClient.client.lua`, `SettingsUI.lua`, `client_checks.lua`, TuningConfig (if Step 1 changed it) and the manifest: `"Swim revamp Task 5: directional swim controller, dive, climb-out; shift lock yields underwater"`.

---

### Task 6: The air meter and the touch DIVE button (existing UI assets only)

**Files:** modify `SwimClient.client.lua` and `MobileControls.lua`; extend `client_checks.lua`.

**Interfaces:**
- **`SwimClient` removes the code-built `SwimHUD`** (Frame, Fill and TextLabel). In its place, it clones `PlayerGui.Uis.HUD.Stats.BlueBar` once per character into `HUD.Stats` as `AirBar`:
  - its placement comes from Task 1's survey: the next slot in the Stats layout if it has one, else directly under the lowest vitals bar, at the same size;
  - its fill goes through `require(ReplicatedStorage.Modules.UI.Fill).Set(AirBar.Bar, Breath / BreathMax)`;
  - it is visible while `Submerged` or `Breath` is set, and the character is alive;
  - its label is a TextLabel cloned from the bar's own text child, if it has one; otherwise from HUDUI's hover-value style (Guru font, from `MobileControls`' `FONT`). It reads "AIR", or "DROWNING" while `Drowning`;
  - while drowning the bar blinks (its own transparency, 0.25 s);
  - nothing else in `Uis` is touched, and HUDUI isn't changed.
- **`MobileControls`:**
  - the BUTTONS table gains `SwimDive = {0.20, 0.88, 0.16, "DIVE", "Swim"}` (Slide's spot: Slide, Calm, and Aim, Combat, are hidden while swimming);
  - it runs the action `"SwimDive"`. Holding works like the other swim buttons;
  - the header comment's swimming line becomes SPRINT, RISE and DIVE.

**Steps:**
- [ ] **Step 1: RED.** Add to `client_checks.lua`:
  - **`AirMeterIsTheHudBar`:** while Under for 2 s, `HUD.Stats.AirBar` exists and is visible, its image ids equal `BlueBar`'s (from the survey), and **no ScreenGui named `SwimHUD` exists**;
  - **`DiveButton`:** with the Player attribute `ForceMobileControls = true` and in Surface, the `SwimDive` button is visible. Pressing it through `ClientActions.Run("SwimDive", true)` then `false` (a tap) → Mode == "Under". The test switch is turned off afterwards.

  Run them: both FAIL.
- [ ] **Step 2:** Make the changes. Sync `SPScripts.SwimClient` and `UI.MobileControls` to both places.
- [ ] **Step 3: GREEN** in Foundry Play, then Ye Play: all client checks PASS. Report one `screen_capture` of the air meter in each place for the controller. That is evidence only: no image is committed.
- [ ] **Step 4:** `--check` both places.
- [ ] **Step 5: Commit**: `"Swim revamp Task 6: air meter from the HUD's own bar; touch DIVE button"`.

---

### Task 7: Stealth and noise underwater

**Files:**
- Modify: `Perception.lua`, `PerceptionService.lua`, `NoiseService.lua`, `Test_Perception.lua`, `Test_Sound.lua`, `Play_Swim.lua`.

**Interfaces:**
- **`Perception`:**
  - `Perception.SubmergedMult = 0.3` (PROPOSAL: sight of a target whose `Submerged` attribute is set);
  - `Perception.Sounds.Surface = 6`, `Perception.Sounds.Stroke = 8`;
  - `Perception.StrokeEvery = 0.8` (all PROPOSAL).
- **`PerceptionService`:**
  - `Rays.IgnoreWater = true` (one line after line 35, with a comment: water no longer hides a diver by blocking rays, finding A11);
  - in `Update`, `Move` becomes `C:GetAttribute("Submerged") and P.SubmergedMult or (crouch / MoveMult as now)`. Submerged wins over crouching. Update the header comment.
- **`NoiseService.StepPlayer`:**
  - **Surface:** when the `Submerged` attribute goes from true to nil while still in Swim, emit `"Surface"` at the head;
  - **Stroke:** while in Swim, not Submerged and `SwimSprint`, emit `"Stroke"` every `StrokeEvery` s (a per-character timer in `Track`);
  - footsteps stay off in traversal states.

**Steps:**
- [ ] **Step 1: RED.**
  - Add `Test_Sound.SwimSounds` (Surface 6, Stroke 8, StrokeEvery 0.8) and `Test_Perception.SubmergedSight` (`P.Rate` with Move = SubmergedMult is 0.3 / the walking MoveMult of the dry rate, ± 1e-6, using Test_Perception's existing inputs).
  - Add `Play_Swim.DiverIsHardToSee`. It registers a test NPC with PerceptionService (Play_Stealth's fixture pattern: read it and reuse its helper, don't copy it; if it isn't shared, move it into `SwimKit` and require it from both), 10 studs from the pond's edge, facing the water. `PerceptionService.SetAuto(false)` and manual `Step`.
    - With `SwimKit.WithPlayerAt`, put the real character's head 2.5 under the surface 8 studs in front of the NPC, set `Submerged` (by `SwimService.Step`), and step perception for 1 s → `GainUnder` = awareness gained.
    - Then the same spot with the root raised so the head is 1 above the water, and 1 s → `GainDry`.
    - Pass when `GainUnder > 0` and `GainUnder / GainDry` is within 0.3 ± 0.1.
    - Reset the NPC and `SetAuto(true)` after.
  - Add `Play_Swim.SurfaceMakesNoise`: watch `NoiseService.Emit` (wrap it for the test and restore it) while the rig's `Submerged` goes true → nil in Swim → one `"Surface"` emit.
  - Run them in Foundry Play. Expected FAILs: SwimSounds, SubmergedSight, DiverIsHardToSee (today `GainUnder` is 0, or equals `GainDry` if water doesn't block: **report which**, it settles A11), SurfaceMakesNoise.
- [ ] **Step 2:** Make the changes. Sync `Rensei.Perception`, `RenseiServer.PerceptionService`, `RenseiServer.NoiseService`, `RenseiTests.Test_Perception`, `RenseiTests.Test_Sound` and `RenseiTests.Play_Swim` to both places.
- [ ] **Step 3: GREEN.**
  - Foundry Play: `Play_Swim` 8/0, `Test_Sound` and `Test_Perception` all pass.
  - Ye Play: the same, plus `Play_Stealth` and `Play_Perception` as their Task 2 baselines (no new FAIL).
- [ ] **Step 4:** `--check` both places.
- [ ] **Step 5: Commit**: `"Swim revamp Task 7: divers are hard to see, not invisible; surfacing and sprint strokes make noise"`.

---

### Task 8 (optional, PROPOSAL): Ye's plunge hole in the Gorge Pool

**Skip this task** when Task 1 found no rectangle of at least 12 × 8, or when the controller or owner says to. Then `SwimKit.Spots` keeps `Plunge = nil`, and the docs say Foundry's pond is the only deep dive.

**Files:**
- Create: `Art/Studio/Regions/Lindenmoor/plunge_hole.lua`.
- Modify:
  - `Art/Regions/Lindenmoor/layout.json` (`RestoreRefuseFlags` gains `LindenmoorPlungeHole`);
  - the regenerated `Art/Studio/Regions/Lindenmoor/import/restore.lua` (through `kit.py`, as the Lindenmoor final fix pass did);
  - `test_ye_fixes.py`;
  - `SwimKit.lua` (`Plunge`);
  - `Play_Swim.lua`.

**Interfaces:**
- **The hole:** Task 1's rectangle `[x0, x1] × [z0, z1]` (4-aligned, at most 24 × 12), written into the script as constants with the survey's date.
- **The flag:** `LindenmoorPlungeHole` on `workspace.World.Map`.
- **The marks:** `PlungeHoleAdd = true`, and `PlungeHoleFrom` on the Baseplate (JSON: the old CFrame as 12 numbers, the Size, and each Texture child's `OffsetStudsU`/`V`).
- **The backup folder:** `RenseiBackups["Pre-PlungeHole_2026-10-25"]` holds a `TerrainRegion` of the box `[x0−4, x1+4] × [−16, 8] × [z0−4, z1+4]`, copied before apply.
- **`apply`:**
  1. **The Baseplate** (same instance and name) is resized and moved to the west strip `[−1024, x0] × [−1024, 1024]`. Clones (`PlungeHoleAdd`) cover the east strip `[x1, 1024] × [−1024, 1024]` and the south and north strips `[x0, x1] × [−1024, z0]` and `[x0, x1] × [z1, 1024]`, all 16 thick at y −16..0.
  2. **Textures:** each strip's Texture children keep their world alignment. Set `OffsetStudsU`/`V` so the tile phase at a world point equals the original's (the face's corner moved: the offset changes by that delta, mod StudsPerTile). Apply it per face.
  3. **The bed:** a slab (`PlungeHoleAdd`) filling `[x0, x1] × [z0, z1]` at y −16..−8.
  4. **Four liners:** 0.4 thick, y −8..0, on the hole's four sides. The bed and liners take the material, colour and variant of the pool floor's surveyed first non-water hit (if that was the Baseplate itself, use its look).
  5. **Water:** `Terrain:FillBlock` from y −8 to 0 over the rectangle.
- **`undo`:**
  - restores the Baseplate from `PlungeHoleFrom` (CFrame, Size and Texture offsets), and deletes every `PlungeHoleAdd`;
  - pastes the TerrainRegion back;
  - clears the flag;
  - refuses while Play runs, while PlayLock is set, or when the Baseplate's current CFrame or Size isn't the one apply set (someone moved it).
- **`check`** (failure conditions):
  - **The Baseplate:** the strips' union covers the old Baseplate's footprint minus the hole exactly (area and bounds against the recorded From);
  - **The water:** a ray down at the hole's centre (`IgnoreWater = true`) meets the bed at −8 ± 0.1, and the water at the centre reads Water at y −6;
  - **Nothing else moved:** no part outside the hole box has `PlungeHoleAdd`;
  - **The ledge:** the ledge walk's `RenseiLedge` CFrame equals the survey's;
  - **The budget:** the part count = the baseline + 8.
- **`SwimKit.Spots(Ye).Plunge`** = the hole's centre, at y 2 (surface 5.2).
- **`Play_Swim.PlungeHoleIsDeep`:** `WaterDepthAt(Plunge)` = 13.2 ± 0.5. RED before apply (5.2).

**Steps:**
- [ ] **Step 1: RED.** Add `PlungeHoleIsDeep` and the `test_ye_fixes.py` checks: the restore guard lists `LindenmoorPlungeHole`, and `plunge_hole.lua` has the MODE line and the refusals. Run `test_ye_fixes.py`: the new checks FAIL. The Play check comes in Step 4.
- [ ] **Step 2:** Write `plunge_hole.lua`. Update `layout.json` and regenerate `restore.lua` with `kit.py` (the Lindenmoor final fix pass's command; a region without the key gets byte-for-byte the same restore). Run `test_ye_fixes.py` and `test_kit.py`: all pass.
- [ ] **Step 3: In Ye (Edit):** `plan` (report the strips), `test` (snapshots equal), `apply`, `check` (PASS n / FAIL 0).
- [ ] **Step 4: Ye Play:**
  - `Play_Swim` 9/0 (`PlungeHoleIsDeep` passes);
  - a client check, `DiveInThePlungeHole`: `Dive()` there, Ctrl held for 2 s → HeadDepth > 8, then Space → Surface;
  - `Play_LindenmoorSmoke` as its baseline.
- [ ] **Step 5:** Sync `RenseiTests.SwimKit` and `RenseiTests.Play_Swim` to both places; `--check` both.
- [ ] **Step 6: Commit** `plunge_hole.lua`, `layout.json`, `restore.lua`, `test_ye_fixes.py`, `SwimKit.lua` and `Play_Swim.lua`: `"Swim revamp Task 8 (PROPOSAL): reversible 13.2-deep plunge hole in Ye's Gorge Pool"`.

---

### Task 9: Real input in both places, and the full sweep

**Files:** none new, unless a fix is needed (the controller rules which task owns it).

**Steps:**
- [ ] **Step 1: Foundry Play, real keyboard** (`user_keyboard_input`; the camera is set from the Client data model). At the pond:
  1. walk in → the Swim state, Combat Mode off;
  2. hold W with the camera pitched 60° down for 3 s → you stay at the surface;
  3. tap Ctrl → you dive (Swim_Dive or its fallback);
  4. W with the camera down → you descend; the air meter shows and drains;
  5. Shift → sprint, and the meter drains faster;
  6. Space → you rise and surface (Swim_Surface or none);
  7. Space facing a low lip (the survey's ledge, if any) → you climb out; otherwise walk out on the bank;
  8. stay under for no more than 8 s.

  Record root and head heights over time from the Client model. Report a pass/fail line per step.
- [ ] **Step 2: Touch (ForceMobileControls):** SPRINT, RISE and DIVE show only in water; DIVE dives; the on-foot buttons return on land. Turn the switch off.
- [ ] **Step 3: Ye Play:** steps 1–6 at the Gorge Pool (the plunge hole if Task 8 ran, otherwise a shallow dive), and a creek channel: Ctrl does nothing (too shallow).
- [ ] **Step 4: The suites, in the same sessions:**
  - **Foundry:** `Test_SwimLogic`, `Play_Swim`, `Test_Sound`, `Test_Perception`, Foundry's smoke suite (`Play_FoundrySmoke`, the Foundry plan's Task 9) and `Play_Boot`.
  - **Ye:** the same, plus `Play_LindenmoorSmoke`, `Play_Stealth` and `Play_Perception`.
  - Expected: every new suite 0 FAIL; every old suite at its baseline (Task 2 Step 2), and the known travel-ticket failures if those suites are run.
- [ ] **Step 5:** `sync.py --check` in both places: `DIFFER 0 / MISSING 0`. Report the counts.
- [ ] **Step 6:** Report every number the docs need: the measured dive depth reached, how long the air lasted, the speeds, the suites' counts, the part counts after, and which animation slots are still empty.

---

### Task 10: Docs and the Changelog

**Files:** modify
- `Documents/Changelog.md`;
- `Controls.md`;
- `Animations.md`;
- `ARCHITECTURE.md`;
- `Decisions.md`;
- `Project Status.md`;
- `Backlog.md`;
- `Lindenmoor Kit.md` (only if Task 8 ran);
- `Foundry Yard Kit.md`.

**Content:**
- **`Controls.md` "Swimming":**

  | Key | Action |
  |---|---|
  | W A S D | swim (level at the surface; underwater toward where the camera looks) |
  | Left Shift | swim faster (stamina) |
  | Left Ctrl | tap at the surface: dive; hold underwater: sink |
  | Space | hold underwater: rise; at the surface facing a low ledge: climb out |

  Touch: SPRINT, RISE and DIVE.
- **`Animations.md`:**
  - the Swim Forward row is fixed (Swim Idle and Swim Sprint have ids, from Task 1);
  - a "Swim (revamp)" table with the four slots, each with its Fallback and "owner uploads";
  - one line: **"The owner uploads four R6 animations: Swim_Dive, Swim_UnderIdle, Swim_Surface, Swim_ClimbOut; paste each id into its empty slot in `Shared.Movement.Swim`."**
- **`ARCHITECTURE.md`:** the SwimService line (Submerged, breath for all, WaterDepthAt, speed strikes); SwimController and SwimLogic; the SwimClient line; the Perception line (SubmergedMult, IgnoreWater).
- **`Decisions.md`:** under swimming, "Swimming revamp (2026-10-25, PROPOSAL, awaiting the owner)", with the 14 decisions from the spec's §12, each one line.
- **`Project Status.md`:** the movement line says directional swimming, diving, climb-out and the air meter.
- **`Backlog.md`:** the swimming revamp line gets *(Built 2026-10-2x in both places' Studio; not live; awaiting the owner's review of the PROPOSALs and the four animation uploads)*. Don't tick it: the owner ticks it.
- **`Foundry Yard Kit.md`:** the movement table's Swimming row says the pond is the dive site (dive with Ctrl), with the measured depth.
- **`Lindenmoor Kit.md`** (if Task 8 ran):
  - "Ye differs from the kit" lists the plunge hole;
  - "Rolling everything back" gains `plunge_hole.lua undo` as step 0 (`restore.lua` refuses until it has run);
  - the part count;
  - the publish checkpoint's package list gains `Assets` (the four slots).
- **`Changelog.md`:** one entry, `## 2026-10-2x — Swimming revamp: directional swimming and diving (not live)`. It holds:
  - the owner's request;
  - "Decisions taken without the owner" (the 14, briefly);
  - what changed in each place: the scripts, the slots, the plunge hole or "skipped";
  - the test counts from Tasks 1–9;
  - the backups (`Pre-SwimRevamp_2026-10-25`, `Pre-PlungeHole_2026-10-25`);
  - "Not tested" (two real players watching each other dive, a real phone);
  - the open questions (spec §13).

  It ends with `### Discord announcement`, which starts "**Hold: not live yet.** Post this when the owner publishes the swimming revamp." Then a ```md block, under 2,000 characters, plain and player-facing, with no file names, test numbers or PROPOSAL tags. It covers:
  - swimming now goes where you look underwater, and stays level at the surface, so looking down at the water no longer drags you under;
  - dive with Ctrl (DIVE on touch), sink and rise with Ctrl and Space, and sprint with Shift;
  - an air meter: come up before it runs out;
  - climb straight out onto low ledges;
  - Foundry Yard's cooling pond is deep enough for a proper dive (and the gorge pool's new deep spot in Lindenmoor, if Task 8 ran);
  - diving is a way to slip past people, but they can still spot you up close; splashes and hard swimming can be heard;
  - still no fighting or alchemy in the water.

**Steps:**
- [ ] **Step 1:** Write the docs. Every number comes from a task report.
- [ ] **Step 2:** Check the Discord block is under 2,000 characters (`python -I -c`), with no file names, test numbers or PROPOSAL.
- [ ] **Step 3:** This is the plan's only Changelog entry.
- [ ] **Step 4: Commit** the docs: `"Swim revamp Task 10: docs, controls, animation slots for the owner, changelog (held Discord post)"`.
- [ ] **Step 5:** After the commit, the controller pushes, updates the status page, and names to the owner in chat:
  - the decisions taken without the owner;
  - the four animation uploads;
  - that the Assets package needs publishing with the others.

  The implementer does none of these.

---

## Self-review notes

**Coverage of the request:**
- **Directional:** SwimLogic.Velocity (Task 2), the controller and body pitch (Task 5), checked by `SteersDown` and `LevelAtTheSurface` (Task 5) and real input (Task 9).
- **A dive system:** Dive / sink / rise / surface (Task 5), the air meter (Task 6), depth (Tasks 3 and 8), and the dive site in each place.
- **"Completely audit":** spec §1, A1–A18, each with file:line evidence. Every finding has an owner here:

| Findings | Task |
|---|---|
| A1–A5 (direction, pitch, dive, accidental dives, buoyancy) | 2, 5 |
| A6 (depth) | 1 (measured), 8 |
| A7 (breath bar) | 6 |
| A8 (carrier breath) | 3 |
| A9 (climb-out) | 5 |
| A10 (entry/exit feedback) | 4 (slots), 5, 7 (noises) |
| A11–A12 (stealth, silence) | 7 |
| A13 (shift lock) | 5 |
| A14 (ClearMovers) | 5 (SwimAttachment) |
| A15 (touch dive) | 6 |
| A16 (speed) | 3 |
| A17 (doc ids) | 1, 10 |
| A18 (no tests) | 2, 3, 5, 6, 7 |

**Studio checks the spec left open** (Task 1 or Task 5's spike):
- the swim animation ids;
- the PlayerModule;
- HUD.Stats and Fill;
- the Baseplate's children and the Gorge Pool's floor;
- whether AlignOrientation pitches a swimming humanoid (with a fallback);
- whether water blocks perception rays (settled by Task 7's RED).

**Names used across tasks:**
- `Rensei.SwimLogic`, `Managers.SwimController` (`Start`, `Stop`, `Mode`, `Active`, `Dive`, `ClimbOut`, `Input`, `TestMove`);
- `SwimService.WaterDepthAt`, `SwimService.Step(Character, Breather)`;
- the attributes `Submerged` and `SwimSpeedStrikes`;
- the actions `SwimDive`, `SwimSprint` and `SwimRise`; the button `SwimDive`; `AirBar`;
- the slots `Swim_Dive`, `Swim_UnderIdle`, `Swim_Surface` and `Swim_ClimbOut` (flag `SwimAnimSlots`, mark `SwimSlotAdd`);
- the flag `LindenmoorPlungeHole` and the marks `PlungeHoleAdd` / `PlungeHoleFrom`;
- the backups `Pre-SwimRevamp_2026-10-25` and `Pre-PlungeHole_2026-10-25`;
- `RenseiTests.SwimKit` and `Play_Swim`; `Art/Studio/Swim/client_checks.lua`.

**Order and dependencies:**
- 1 comes first.
- 2 before 3, 5 and 7 (SwimLogic, tuning).
- 3 before 5 (the server's `Submerged`) and 7.
- 4 before 5 (the slots `Has` checks).
- 5 before 6.
- 8 is optional and needs only 1 and 3.
- 9 after all; 10 last.
- Play sessions are serial across the places.
- Tasks 1, 4 and 8's Studio scripts run in Edit.

# Foundry Yard Game Data Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Every implementer gets the **Global Constraints** and the **Studio facts** below together with its own task.

**Goal:** Make Foundry Yard (place 109591196441030) a living town on its imported region map. That means:
- its areas, law and factions;
- 26 townsfolk on two shifts;
- the shift-ledger clue quest;
- the four underworks Grunts;
- Brannoc with the Silent Forge and the Forge Floor, moved out of Ye (place 106992859583940) into the practice court and the great hall's forge-room shells, with the forge's Ward Alchemist spawn inside the Silent Forge room.

Then a Foundry smoke suite, and one joint publish checkpoint for Ye and Foundry.

**Architecture:** Five stages:
1. **Foundry catches up with Ye's code.** Foundry's package copies are 16 scripts behind Ye's, and two place scripts are missing. A sync tool with a hash check (Task 1) brings them level, and every later task syncs its own scripts to both places with it.
2. **Shared code and data** (Tasks 2, 3, 5 and 6): edited in the repo, then set into **both** places' Studio copies. These are the `Modules` and `RenseiServer` package copies and the place-owned `RenseiTests`.
3. **Foundry's map gets reversible fixes** (Tasks 4 and 7). Each is an apply/undo/test script that only adds marked parts, or moves parts and records where they were:
   - Shelter posts and the unreachable posts (Task 4);
   - the forge rooms, Brannoc and the alchemist spawn, built from a JSON kit exported read-only from Ye (Task 7).
4. **Ye gives them up** with a reversible retire script (Task 8). The retired pieces go into a backup with their tags set aside, and a notice takes Brannoc's spot.
5. **Checks and docs:** the Foundry smoke suite, the end-to-end quests, the travel suites in both places and the Studio == repo sweep (Task 9). Then the docs and the joint checkpoint (Task 10).

Nothing here publishes. The owner publishes Ye and Foundry together at the end ("Hold both", 2026-10-24).

**Tech Stack:**
- Roblox Studio Luau, through `Art/Tools/rbxc.py`.
- Python 3.14 (stdlib only) for the sync tool, the forge bundler and the pure checks.
- The region tools: `Art/Studio/Regions/kit.py` and its generated `restore.lua`.

**Spec:**
- `Documents/specs/2026-10-23-region-builds-design.md`: §3.1 (with the north-per-place amendment), §§3.4–3.5, 5, 6, 7.2, 7.3, 7.4 and 9;
- `Documents/Foundry Yard Kit.md`, "Foundry import notes" items 5 and 10–13, and "Not done in this import";
- `Documents/Region Builder.md` §§6–8;
- the Lindenmoor lessons: `.superpowers/sdd/2026-10-24-lindenmoor-import/progress.md`, Rulings 8, 22, 25 and 33–43. They are folded into the Global Constraints below.

**Owner decisions (2026-10-24).** These are answered; the tasks build them.
- **A. Ye's `FoundryYard` model:** keep it, and the `chalk_foundry` quest in it, in Ye, unchanged. Spec §7.2 listed it for backup, but it is a working quest, not a graybox. Moving `chalk_foundry` into the Foundry is a later plan (Backlog).
- **B. The Ward Alchemist spawn (`WardAlchemist_SilentForge`):** it spawns **inside the Silent Forge room** in the great hall, as it belonged to the forge in Ye. Its spot is on the room's floor, clear of the hearth, the doorway and the room's pieces (Task 7). The four Grunts stay the only enemies in the underworks.
- **C. Saves mid-way through `acq_metal`:** their saved stage moves forward on join (`Revision` / `Prepended` in the quest def, `QuestService.Boot`), so the player stays on the stage they were on (controller ruling).
- **D. Ye's Metal trainer spot:** a notice, "Gone to the Foundry Yard", stands there and starts `acq_metal` at its travel stage (gated on having no path).
- **E. The Forge Floor fight:** shrunk to fit the shell, with Radius 24 and FoeDistance 14 (both PROPOSAL; were 34 and 16).

---

## Studio facts (measured read-only on 2026-10-24, both places in Edit)

Implementers use these numbers as given. Re-measure only where a step says so.

**Places and windows.**
- Ye: placeId 106992859583940, window "[CLOSED TESTING] Rensei".
- Foundry: placeId 109591196441030, window "Foundry Yard".
- Get each window's `studio_id` from `python -I Art/Tools/rbxc.py studios` (the ids change when Studio restarts).
- Both were in Edit. Ye's `ServerStorage.PlayLock` was nil.

**Foundry's map.**
- `World.Map` has one child, `Foundry` (Model). Workspace has 46,941 BaseParts.
- `Map.Foundry`'s parts by group: Ground 3,979, Routes 1,948, Buildings 31,323, Landmarks 2,165, Cover 3,777, Edges 391 and Markers 102 (the map's 43,685 of its 45,000 ceiling), plus Travel 3,254.
- `Map.Foundry.Spawn`: a SpawnLocation at (−648, 6.9, 360), placed by hand; it isn't in the export.
- `World.NPCs`, `World.Live`, `World.EnemySpawns` and `World.Visuals` are empty.

**Tags in Foundry's workspace:**

| Tag | Count |
|---|---|
| RenseiPost | 76 |
| RenseiArea | 12 (11 names; Foundry Station has two boxes) |
| RenseiClue | 2 |
| RenseiEnemySpawn | 4 |
| RenseiMarker | 8 |
| RenseiNoGrip | 391 (Edge_N 97, Edge_E 92, Edge_S 95, Edge_W 95, two portals with 6 each) |
| RenseiLedge | 377 (Buildings 352, Landmarks 25) |
| RenseiArrival | 2: `Travel.SouthRoad.Arrival_RoadStart` and `Travel.Station.Arrival_Platform` |
| RenseiPlatformTrain | 1 (Route `LindenmoorFoundry`) |
| RenseiTrial, RenseiInspect, RenseiTownsfolk | 0 |

- There are 154 parts with `NightOnly`, each with a Light; none of them are in the underworks.
- **Outside workspace:** only `RenseiAmbushArena` 1 and `RenseiRoadExit` 1, in the World Plan 1 backups. Nothing consumes those tags.

**Foundry's posts:**
- Every post marker is a 2-stud part centred 1 stud above the ground (ground top 4, or 4.4 on the hall and court floors).
- **Off the ground:**
  - `station_porter_platform` at y 7.4, on the platform (top 6.4);
  - `hall_gantry` at y 21, on the great hall's gantry (top 20);
  - **`yard_hand_2` (420, 9, 154) and `yard_hand_3` (560, 9, 154)**, on the raised goods platform (top 8).
- **Pathfinding in Edit** from `errand_square` + (0, 2, 0), with `Mover.Agent` (AgentRadius 2.5, AgentHeight 5.5, no jump, no climb):
  - 68 of 75 posts are reached.
  - `hall_gantry` is reached only at AgentRadius 2. The Mover tries 2 (`Mover.NarrowRadii = {2, 1.5}`), so it is reachable.
  - **No path at any radius, even with jumps:** `market_trader_1..4`. Each trader stands in a 2.3-stud slot between the stall's Counter and Shelf. For example, stall 1 has its Counter at (−250, 5.5, −313.6), size 8 × 3 × 1.6, and its Shelf at (−250, 5.1, −310), size 7 × 2.2 × 1.
  - **No path without jumps:** `yard_hand_2` and `yard_hand_3`. The platform's south face is at z 160, and south of it the ground top is 4 (part `Top4` of `Ground_18_14`, x 384..448, z 160..192).
- **Shelters.** There are 7 Shelter posts: station, yard, hall, foundry, square, workers and lower. **47 of the 76 posts have no shelter within 150 studs**; the worst is `cinder_home_6` at 473 studs.

**Foundry's areas.** The box centres and sizes, in world studs (y 50, height 140):

| Area | Centre (x, z) | Size (x × z) |
|---|---|---|
| Foundry Station | (−664, 360) and (−664, 704) | 208 × 560 and 208 × 128 |
| The Underworks | (−335, 704) | 450 × 128 |
| Practice Court | (−185, 540) | 150 × 200 |
| Cinder Lane | (−230, 260) | 660 × 360 |
| Lower Town | (−410, 540) | 300 × 200 |
| Freight Yard | (434, 260) | 668 × 360 |
| South Road | (329, 604) | 878 × 328 |
| Rail Yards | (0, −85) | 1,536 × 330 |
| Workers' Row | (−544, −509) | 448 × 518 |
| Foundry Square | (−90, −509) | 460 × 518 |
| The Foundry | (454, −509) | 628 × 518 |

**Foundry's markers.**
- **Clues:**
  - `foundry_shift_ledger` at (−145, 5, 465), beside the `shift_clerk` post (−149, 5, 465.5);
  - `foundry_altered_docket` at (−330, 5, 676), in the underworks tunnel.
- **Grunt spawns:** `RenseiEnemySpawn24..27` at x −500, −420, −280 and −220, all at (y 5, z 676). The tunnel floor (`Floor`) is at y 4.4 under each, and the roof is 10.8 above. The tunnel runs x −548..−160 at z 676, 10 wide.
- **TrainerSpot:** (−200, 5, 490), Yaw 0 (it faces −Z). The floor under it is y 4.4.
- **The pond:** terrain Water at (490, 0, −148), (440, −2, −120) and (540, −4, −180), and Air at (490, 6, −148). The water Rect is x 420..560, z −196..−100, top 3 and bed −6.

**The forge-room shells** (in `Map.Foundry.Landmarks.GreatHall_great_hall`; the hall's box is centred (400, 46.1, −343.4), size 202 × 84.2 × 122.3):

| Room | Floor part (`Room` attribute) | Interior | Doorway (front wall z −338.8) | Hearth |
|---|---|---|---|---|
| Silent Forge | `SilentForgeFloor`, top y 4.7 | x 353.6..392.4, z −389.4..−339.6 (38.8 × 49.8), centre (373, −364.5) | x 369..377 | 10 × 6 × 5 at (373, 7, −386.4) |
| Forge Floor | `ForgeFloorFloor`, top y 4.7 | x 305.6..344.4, z −389.4..−339.6, centre (325, −364.5) | x 321..329 | 10 × 6 × 5 at (325, 7, −386.4) |

The walls are 12 tall (y 4..16), and the rooms are open to the hall roof.

**Ye's pieces that move** (all in Ye's `World.Map`, each carrying `LindenmoorPrepFrom`):
- **`SilentForge`** (Model, 29 parts; box centred (521.5, 32.7, 900), size 44 × 21.4 × 36; floor top y 24.4):
  - `Interactables`:
    - `WorkshopRecord`, tagged RenseiInspect, `metal_note`, with a child Model of 3 MeshParts (meshes 4669623755, 4669620585 and 4669621896);
    - `MaterialBench`, tagged RenseiMechanism, `metal_bench`;
    - `RepairedGear`, tagged RenseiInspect, `metal_gear`;
    - `SampleRack`, tagged RenseiInspect, `metal_samples`;
    - `DriveShaft`, tagged RenseiInspect, `metal_shaft`.
  - Decor: `Sample1..5`, `Iron Alchemy` (3 MeshParts: meshes 4669611074, 4669609720 and 4669612326), `Machine`, `Desk` and `Anvil`.
  - The area box `Silent ForgeArea`, tagged RenseiArea, AreaName "Silent Forge", Description "A forge that went cold mid-shift.", size 44 × 20 × 36.
  - Shell parts: `WestA`, `WestB`, `EastA`, `SouthA`, `SouthB`, `North`, `Floor`, `Furnace` and `FurnaceMouth`.
- **`ForgeFloor`** (Model, 10 parts): a 72 × 72 plate, 8 posts on a ring of radius 35, and `TrialMarker` (4 × 1 × 4 Basalt, tagged RenseiTrial, TrialId `metal_experiment`) at (584, 22.9, 900).
- **Brannoc:** `World.NPCs["Alchemy Trainers"]["Metal Alchemist"]`, an R6 Model.
  - Its root is at (−130, 7, −135), facing −Z and anchored.
  - Its attributes: DialogueId `trainer_metal`, DisplayName "Brannoc", TrainerPath "Metal", LookNation "Xerxian", LookGender "Male", LookSeed 105, IdleAnim "NPC_Blacksmith", Posed "Standing" and Placeholder true.
  - Its props: `ScrollStand` (Part, 1.4 × 3 × 1.4 at (−127.4, 5.5, −137.2)) and the `Metal Alchemy` Model (MeshPart `Paper`, mesh 4669611074, at (−127.4, 7.2, −137.2)).
  - It has no scripts. DialogueService dresses it at run time from the Look attributes.
- **The alchemist spawn:** `World.Map.AlchemistSpawns.WardAlchemist_SilentForge`, a Part tagged RenseiEnemySpawn, EnemyType WardAlchemist, at (591.9, 22.5, 960.8). It is 2 × 1 × 2, invisible and non-colliding, with its centre 0.5 above the ground (y 22).
- **Its new spot in Foundry, measured:** (386, 5.2, −348), inside the Silent Forge shell. A ray down there meets `SilentForgeFloor` at y 4.7, and a 4 × 5 × 4 box over it holds nothing. That is 9 studs east of the doorway (x 369..377, z −338.8), 7.5 studs south of the moved MaterialBench (z −355.5) and 35 studs from the hearth.
- **Ye's Metal TrainerSpot** (stays): `Map.LindenmoorExpansion.Markers.Markers_Expansion.RenseiMarker16` at (−130, 5, −135), Element "Metal", Trainer "Brannoc".
- **Ye's `FoundryYard` model** (60 parts, box centred (300, 38, 880)) holds the whole of `chalk_foundry`: the furnace_store puzzle door, 5 chalk and store inspects, 9 mechanisms and its "Foundry Yard" area. It is not a graybox. See Owner decision A.
- Ye has 76,373 BaseParts in workspace, against the place's 80,000 ceiling.

**The code in the two places.**
- **Foundry is behind Ye** on these 16 package scripts (Ye's copies equal the repo; normalised hash, below):
  - `Rensei`: Dialogues, Evidence, Investigation, Puzzles, Quests, Regions, Townsfolk and TownsfolkLogic;
  - `UI`: CompassUI and MasteryUI;
  - `RenseiServer`: CompassService, EnemyService, MoralityService, TownsfolkService, TownsfolkService.Mover and WorldService.
- **Foundry has old copies of** `RenseiTests.Test_Regions` and `Play_Boot`.
- **Foundry is missing:**
  - `StarterPlayerScripts.TownsfolkClient` (the speech bubbles; repo `Art/Studio/Regions/TownsfolkClient.lua`);
  - `StarterCharacterScripts.Health` (the owner's no-regen-in-combat rule, 2026-10-23; repo `Scripts/StarterPlayer/StarterCharacterScripts/Health.server.lua`);
  - every Townsfolk, Clue, Clock, Exams and NoGrip suite.
- Foundry's RenseiTests holds TestKit, Play_Boot, Play_Travel, Play_Road, Play_RideEvents, Play_Arrive, Play_Gate, Play_Station (Play_Road and Play_Station are the d3606a5 versions) and Test_Regions.
- All other scripts under `ReplicatedStorage.Modules`, `StarterPlayer`, `StarterGui`, `ServerScriptService` and `ReplicatedStorage.Remotes` are the same in both places. `ReplicatedStorage.Assets` (v3, with `RELLO IMPORTED ASSETS`) is in both places.

---

## Global Constraints

**Owner rules:**
- "Do not publish the Roblox game or modify live player data."
- "Do not expose API keys, credentials, private player data, or other secrets."
- "Do not blindly copy another game's code or assets."
- **UI:** use only the game's existing UI assets. This plan adds no new UI: bubbles use TownsfolkClient, and inspect points use PromptUI.
- **Names:** every townsperson's name and line is original. None comes from another game or show, and none repeats a name already in the game (the trainers, Brask, Mirra, Tobin, Lise, Vask, the Lindenmoor roster, `TownsfolkLogic.NewcomerNames`).

**Labels and records:**
- Label every invented number **PROPOSAL** in code comments and docs.
- No task writes a Changelog entry except Task 10, which writes one entry for the whole plan.
- Implementers report to the controller in their final message.
- Implementers never dispatch subagents and never write under `.superpowers/`: the harness refuses it.

**Studio bridge:**
- Run Luau with `python -I C:/Users/Owner/Rensei-Game-Design/Art/Tools/rbxc.py luau "placeId: <id>" <Edit|Server> @file.lua`. Only the first return value prints, cut at 30,000 characters. Return compact summaries; to return more, write it to a StringValue in ServerStorage, read it back in 25,000-character chunks and delete it.
- Studio state: `rbxc.py call get_studio_state '{"studio_id":"<id>"}'`. Play: `rbxc.py call start_stop_play '{"is_start":true|false,"studio_id":"<id>"}'`.
- **Foundry quirk:** rbxc sometimes returns "Target is not reachable (DMN_ID_EDIT)" even though the call ran. Before retrying anything that isn't idempotent, read the state the call would have changed.
- Never touch the Studio window "bloodydeadpool53's Place".
- Put scratch files in `C:/Users/Owner/AppData/Local/Temp/claude/C--Users-Owner/ecd4cd55-01de-4070-9638-cb228809b769/scratchpad/foundry-plan/`.

**Play** is hooked and protected, because Play writes the owner's REAL save.
- **One Play session at a time across Ye and Foundry.** Before Play:
  - `get_studio_state` must show the **other** place in Edit;
  - Ye's `game.ServerStorage:GetAttribute("PlayLock")` must be nil.
- **The order, every session:**
  1. In Ye (Edit), set `game.ServerStorage:SetAttribute("PlayLock", "<Ye|Foundry>:<task>")`. When playing Foundry, set the same attribute in Foundry too.
  2. In the playing place (Edit), run `C:/Users/Owner/.claude/jobs/0c39df78/tmp/blender/hook.lua`.
  3. Start Play. In the Server data model, wait until `game.ServerStorage:GetAttribute("LMSnapTaken")` is set.
  4. Run the suites: `game.ServerStorage.LMRunSuite:Invoke("<Suite>")` (Server).
  5. `game.ServerStorage.LMTestHook:Invoke("restore")` (Server). It must return "restored".
     - `LMTestHook:Invoke("diff")` still lists Settings, Story, Morality and other keys after a restore. That is an encode quirk, not a real change.
  6. Stop Play.
  7. In Edit, run `C:/Users/Owner/.claude/jobs/0c39df78/tmp/blender/unhook.lua`.
  8. Only then, clear PlayLock in both places.
- Script edits are refused while Play runs.
- **Run Play_Boot first** in every travel run: Play_Station fails 4/20 when it is the first suite of a fresh session.
- **Known failures:** Play_Travel 5/2 and Play_RideEvents 8/1 fail only on the Cabin/Second ticket in the owner's real save. They are not regressions.
- **In Play, the world is a copy.** Map changes made in Play vanish at Stop, so RED controls that break the map belong in Play. Save data is real: the hook's restore puts it back.

**Edit's require cache.** Edit keeps a module's result between `execute_luau` calls, so an Edit run after a script edit sees the old module. Run any suite that requires a module changed in this session **in the Play VM** (`LMRunSuite`). Edit runs are only for Studio scripts that require no changed module (the Task 4 and Task 7 map scripts).

**Scripts live in both places.**
- **Every shared script** is edited in the repo first, then set into **both** places:
  - the `ReplicatedStorage.Modules` package copy;
  - the `ServerStorage.RenseiServer` package copy;
  - the place-owned `ServerStorage.RenseiTests`;
  - for Task 1, also the two StarterPlayer scripts.
- Use Task 1's tool:
  ```
  python -I Art/Studio/Regions/Foundry/data/sync.py --place ye|foundry --only <label>[,<label>...] --run
  python -I Art/Studio/Regions/Foundry/data/sync.py --place ye|foundry --check
  ```
  `--check` must print `DIFFER 0 / MISSING 0` for both places at the end of every task that touched a script.
- Each task **adds its own pairs** to `Art/Studio/Regions/Foundry/data/sync_manifest.json` (format in Task 1).
- **Backups:** before a script's Source changes, the tool clones it once into `ServerStorage.RenseiBackups["Pre-FoundryData_2026-10-24"]` in that place, under labels `Rensei.<Module>`, `UI.<Module>`, `RenseiServer.<Service>`, `TownsfolkService.Mover`, `RenseiTests.<Suite>`, `SPScripts.<Name>` or `SCScripts.<Name>`. The date in every backup name in this plan is fixed (2026-10-24), so every task finds the same folder.
- **The normalised hash** (Studio == repo means these strings are equal). In Luau:
  ```lua
  local function NormHash(S)
  	S = S:gsub("\r\n", "\n")
  	local H1, H2 = 0, 0
  	for I = 1, #S do
  		local B = string.byte(S, I)
  		H1 = (H1 * 31 + B) % 1000000007
  		H2 = (H2 * 131 + B) % 998244353
  	end
  	return #S .. ":" .. H1 .. ":" .. H2
  end
  ```
  The same in Python:
  ```python
  def norm_hash(data: bytes) -> str:
      data = data.replace(b"\r\n", b"\n")
      h1 = h2 = 0
      for b in data:
          h1 = (h1 * 31 + b) % 1000000007
          h2 = (h2 * 131 + b) % 998244353
      return f"{len(data)}:{h1}:{h2}"
  ```

**Reversible Studio scripts** (every map change in this plan) follow the Lindenmoor fix scripts' contract (`Art/Studio/Regions/Lindenmoor/shelters.lua` is the model):
- `local MODE = "plan"` on its own line near the top. The modes:
  - `plan`: read-only;
  - `apply`;
  - `undo`;
  - `check`: read-only;
  - `test`: allowed only while not applied. It snapshots, applies, checks, undoes and snapshots again; the two snapshots must be equal; it leaves the place as it was.
- **`apply`:**
  - refuses, changing nothing, when its flag attribute is already set;
  - runs inside a pcall with a journal, so an error mid-way is rolled back;
  - makes one ChangeHistoryService recording, and cancels it on a refusal;
  - marks every instance it creates with its `...Add = true` attribute, and every instance it moves or changes with its `...From` attribute (the old CFrame as 12 numbers, or the old value).
- **`undo`:**
  - restores exactly those, and clears the flag;
  - refuses while any fix that has to be undone first is applied (each task names its guards).
- Each mode returns a one-paragraph summary.
- **Generated scripts** carry the header `-- generated by <tool> from <inputs> (<date>): do not edit by hand.` To run another MODE, copy the committed file to the scratch folder and edit only its MODE line there. Never regenerate a generated script to undo it: the generator reads the current place.
- **A backup this plan makes carries no live CollectionService tags.**
  - Every instance moved into a `RenseiBackups` folder has its tags removed and written as JSON into the attribute `RegionKitTags`. That is the convention `Art/Studio/Regions/*/import/unstrip.lua` reads.
  - `undo` puts the tags back.
  - **Why:** InvestigationService, PuzzleService, TrialService's GetTagged and MinigameService don't filter to workspace, and backups otherwise keep their tags (Lindenmoor final review C1).
- **Any new code that reads a tag** ignores instances outside `workspace`.

**North per place** (spec §3.1 amendment; Lindenmoor Ruling 38b):
- **Foundry:** north is −Z and east is +X (`Regions.NorthOf` gives "-Z").
- **Ye:** north is +Z and east is −X.
- Every player-facing direction word uses **the place it describes**:
  - "north-east" in Foundry means +X, −Z;
  - in Ye the road and rails leave Lindenmoor to the north-west.
- **Tests that check a direction** compute it with `Regions.Bearing(dx, dz, "-Z")` for Foundry and `"+Z"` for Ye.

**Townsfolk rules:**
- `TownsfolkLogic.Validate` must pass on every roster. That means:
  - every hour of every schedule is covered;
  - no two townsfolk share a post at the same hour;
  - every post named exists.
- **Shelters:** every RenseiPost in Foundry has a Shelter post within **145 studs** (straight line; PROPOSAL margin under `TownsfolkService.ShelterRadius` 150, Ruling 37).
- **The Mover:** the time-to-meet give-way and same-tick step-aside (Ruling 36) come with Task 1's Mover sync. Don't change the Mover. Play_TownsfolkCrowd must stay green.

**Tests:**
- **RED then GREEN.** Every new check is run once where it **must fail** (before the change, or with a deliberate break made in Play), and fails. Then it passes after.
- A check that cannot fail is not a check (Lindenmoor decision 3, Ruling 41). Never pick a test spot or input by reading the property under test.
- When a check fails, fix the cause in the task that owns it (the controller rules), never by loosening the check.

**Publish order** (`Documents/World Travel.md` §10):
1. packages from Ye;
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

## The owner's decisions, by task

All five are answered (see "Owner decisions (2026-10-24)" in the header). This table says where each one is built.

| | Decision | Why it came up | Task |
|---|---|---|---|
| A | Keep Ye's `FoundryYard` model and `chalk_foundry` in Ye, unchanged. | The model is the whole `chalk_foundry` quest (Brask, the chalk marks, the furnace-store puzzle) and the bandit bounty's yard, not a graybox, though spec §7.2 lists it for backup. | 8 |
| B | The Ward Alchemist spawns inside the Silent Forge room, at (386, 5.2, −348). | It is the forge's alchemist spawn in Ye. The four Grunts stay the only enemies in the underworks. | 7, 9 |
| C | Saved `acq_metal` stages move forward on join (`Revision` / `Prepended`, `QuestService.Boot`). | The new first stage moves every later stage up by one, so a save mid-way through would otherwise land one stage back. | 2, 3 |
| D | A notice at Ye's Metal TrainerSpot starts `acq_metal` at its travel stage (gated on having no path). | A Ye player has no one to start `acq_metal` from once Brannoc leaves. | 3, 8 |
| E | Radius 24 and FoeDistance 14 (PROPOSAL; were 34 and 16). | The Forge Floor arena is 72 across in Ye, and the owner-chosen shell is 38.8 × 49.8. The "left the arena" ring (Radius × 1.35 = 32.4) then clears the room's corners (31.6), and the foe spawns 14 studs back inside the room. | 3 |

---

## File map

| File | Responsibility | Task |
|---|---|---|
| `Art/Studio/Regions/Foundry/data/sync.py`, `sync_manifest.json`, `test_sync.py` (new) | Sync and hash-check scripts, repo → Studio, in both places | 1 |
| `Scripts/ReplicatedStorage/Modules/Data/Rensei/StoryLogic.lua` | `UpgradeQuest` | 2 |
| `Scripts/ServerScriptService/QuestService.lua`, `ServerHandler.server.lua` | `Boot`, `UpgradeAll`, `Revision` on start, `Rewards.Deeds` | 2 |
| `Scripts/ServerScriptService/TownsfolkService.lua` | A roster `Clue.Evidence` gives evidence | 2 |
| `Scripts/ServerStorage/RenseiTests/Test_QuestRevision.lua`, `Play_QuestEngine.lua` (new) | Engine tests | 2 |
| `Rensei/Regions.lua`, `Quests.lua`, `Investigation.lua`, `Minigames.lua`, `Trials.lua`, `Dialogues.lua` | Areas, `acq_metal`'s travel stage, stage look-ups, the notice def, the trial fit, Brannoc's lines | 3 |
| `RenseiTests/Test_Regions.lua`, `Play_Exams.lua`, `Test_AcqMetal.lua` (new) | Data tests | 3 |
| `Art/Studio/Regions/Foundry/foundry_posts.lua` (new) | Reversible: 12 Shelter posts, 2 yard posts moved, 4 stall shelves walk-through | 4 |
| `Art/Regions/Foundry/layout.json`, `Art/Blender/region_builder/tests/foundry_check.py`, `Art/Studio/Regions/Foundry/import/restore.lua` (regenerated) | The posts in the region file, a shelter check, the restore guard | 4 |
| `Rensei/Townsfolk.lua`, `RenseiTests/Test_FoundryRoster.lua` (new) | Foundry's roster of 26 | 5 |
| `Rensei/Investigation.lua`, `Evidence.lua`, `Deeds.lua`, `Quests.lua`, `Townsfolk.lua`; `RenseiTests/Play_FoundryLedger.lua` (new) | The shift-ledger quest | 6 |
| `Art/Studio/Regions/Foundry/forge/export_forge.lua`, `forge_kit.json`, `bundle_forge.py`, `build_forge.lua.tmpl`, `build_forge.lua` (generated), `test_bundle_forge.py`; `RenseiTests/Play_FoundryForge.lua` (new) | The forge rooms, Brannoc and the Ward spawn in Foundry | 7 |
| `Art/Studio/Regions/Foundry/forge/retire_ye.lua` (new), `Art/Studio/Regions/Lindenmoor/prep_ye.lua` (guard), `test_ye_fixes.py`; `RenseiTests/Play_LindenmoorSmoke.lua` | Ye gives up the forge and Brannoc; Ye's smoke checks | 8 |
| `RenseiTests/Play_FoundrySmoke.lua`, `Play_FoundryData.lua` (new) | The Foundry smoke suite and the `acq_metal` end-to-end | 9 |
| `Documents/Foundry Yard Kit.md`, `Lindenmoor Kit.md`, `Changelog.md`, `Backlog.md`, `World Travel.md`, `Region Builder.md` | Docs and the joint checkpoint | 10 (Region Builder.md in 2) |

All `Rensei/` paths are `Scripts/ReplicatedStorage/Modules/Data/Rensei/`, and all `RenseiTests/` paths are `Scripts/ServerStorage/RenseiTests/`.

---

### Task 1: Foundry catches up with Ye's code (the sync tool)

**Files:**
- Create:
  - `Art/Studio/Regions/Foundry/data/sync.py`;
  - `Art/Studio/Regions/Foundry/data/sync_manifest.json`;
  - `Art/Studio/Regions/Foundry/data/test_sync.py`.
- Studio, Foundry only: the 16 package scripts listed in the Studio facts, `RenseiTests` (Test_Regions updated; 8 suites added), and `StarterPlayerScripts.TownsfolkClient` and `StarterCharacterScripts.Health` created.

**Interfaces:**
- **`sync_manifest.json`:** `{"Pairs": [{"Label": "Rensei.Quests", "Studio": "ReplicatedStorage/Modules/Data/Rensei/Quests", "Class": "ModuleScript", "Repo": "Scripts/ReplicatedStorage/Modules/Data/Rensei/Quests.lua", "Places": ["ye", "foundry"], "Create": false}, ...]}`.
  - `Studio` is a "/"-separated path from a service name. The last element is the script.
  - `Create: true` lets the tool create a missing script of `Class` in its parent. The parent must exist.
- **`sync.py`:**
  - `--place ye|foundry`, plus one of:
    - `--check`: prints one line per pair, `SAME`, `DIFFER <studio hash> vs <repo hash>` or `MISSING`, then `SAME n / DIFFER n / MISSING n`, and exits 1 when DIFFER or MISSING > 0;
    - `--only <labels>` or `--all`, with `--run`: generates and runs one bundle per pair, then re-runs `--check` for those labels;
    - `--out <dir>` without `--run`: generates only.
  - Place ids: ye 106992859583940, foundry 109591196441030. It calls `rbxc.py luau "placeId: <id>" Edit @<bundle>` through `subprocess`.
- **Each generated bundle:**
  - header `-- generated by Art/Studio/Regions/Foundry/data/sync.py from <Repo> (<date>): do not edit by hand.`;
  - the NormHash function from the Global Constraints;
  - `local PATH, CLASS, LABEL, CREATE, BACKUP, WANT = ...`, with BACKUP `"Pre-FoundryData_2026-10-24"`;
  - `local SRC = [=*[` + newline + the repo text with CRLF normalised to LF + `]=*]`.
    - The opening long bracket's first newline is dropped by Luau.
    - The number of `=` is the smallest such that `]` + n×`=` + `]` doesn't occur in the text.
- **What a bundle does:**
  1. Refuses when `RunService:IsRunning()`.
  2. Resolves PATH. If the script is missing and CREATE, it creates it; otherwise it refuses.
  3. Returns `same <LABEL>` when the hash already equals WANT.
  4. Otherwise it clones the current script into `RenseiBackups[BACKUP][LABEL]`, only if no backup of that label exists yet (a created script gets no backup).
  5. It sets `Source = SRC` and returns `synced <LABEL>` or `MISMATCH <LABEL> <hash>`.
- **Idempotent:** after a DMN_ID_EDIT error, re-running is safe.

- [ ] **Step 1: Write `test_sync.py`; it fails.** Pure checks, each RED until `sync.py` exists:
  - the long-bracket level for a text containing `]]` and `]=]` is 2;
  - a generated bundle's SRC round-trips: write it, parse the bracket body back in Python, and `norm_hash` equals the repo file's;
  - every manifest `Repo` file exists, and Labels are unique;
  - the Python `norm_hash` of `Art/Studio/Regions/TownsfolkClient.lua` is `6809:893158121:758120550` (the value Ye's Studio copy returned on 2026-10-24).
- [ ] **Step 2: Write `sync.py` and the manifest.** The manifest's Task 1 pairs (all `Places: ["ye","foundry"]`):
  - **Modules data** (`ReplicatedStorage/Modules/Data/Rensei/<X>`, ModuleScript), label `Rensei.<X>`, X = Dialogues, Evidence, Investigation, Puzzles, Quests, Regions, Townsfolk, TownsfolkLogic.
  - **UI** (`ReplicatedStorage/Modules/UI/<X>`), label `UI.<X>`, X = CompassUI, MasteryUI.
  - **RenseiServer** (`ServerStorage/RenseiServer/<X>`, repo `Scripts/ServerScriptService/<X>.lua`), label `RenseiServer.<X>`, X = CompassService, EnemyService, MoralityService, TownsfolkService, WorldService.
  - **The Mover:** `ServerStorage/RenseiServer/TownsfolkService/Mover`, repo `Scripts/ServerScriptService/TownsfolkService/Mover.lua`, label `TownsfolkService.Mover`.
  - **RenseiTests** (`ServerStorage/RenseiTests/<X>`, repo `Scripts/ServerStorage/RenseiTests/<X>.lua`, `Create: true`), label `RenseiTests.<X>`, X = Test_Regions, Test_TownsfolkLogic, Play_Townsfolk, Play_TownsfolkCrowd, Play_TownsfolkHurt, Play_Clue, Play_Clock, Play_Exams, Play_NoGrip.
  - **`SPScripts.TownsfolkClient`:** `StarterPlayer/StarterPlayerScripts/TownsfolkClient`, LocalScript, repo `Art/Studio/Regions/TownsfolkClient.lua`, `Create: true`.
  - **`SCScripts.Health`:** `StarterPlayer/StarterCharacterScripts/Health`, Script, repo `Scripts/StarterPlayer/StarterCharacterScripts/Health.server.lua`, `Create: true`.
- [ ] **Step 3: Run `test_sync.py`.** Expected: all pass.
- [ ] **Step 4: RED in Studio.**
  - `sync.py --place foundry --check`. Expected: DIFFER 17 (the 16, plus Test_Regions) and MISSING 10 (8 suites, TownsfolkClient and Health).
  - `sync.py --place ye --check`. Expected: `SAME 27 / DIFFER 0 / MISSING 0`. Ye isn't changed in this task. If Ye differs anywhere, stop and report: Ye must equal the repo before anything is copied from the repo.
- [ ] **Step 5: Sync Foundry** with `sync.py --place foundry --all --run`. Then run `--check` for both places. Expected: both `DIFFER 0 / MISSING 0`, and Foundry's `RenseiBackups["Pre-FoundryData_2026-10-24"]` holds 17 backups.
- [ ] **Step 6: Play in Foundry** (the Play protocol; PlayLock `Foundry:task1`). Suites, in this order: Play_Boot, Play_Station, Play_Road, Play_Gate, Play_Arrive, Play_Travel, Play_RideEvents, Test_Regions, Test_TownsfolkLogic, Play_Clock, Play_NoGrip, Play_Townsfolk, Play_TownsfolkCrowd, Play_TownsfolkHurt and Play_Clue.
  - Expected: the travel suites as before the import (Boot 2/0, Station 20/0, Road 11/0, Gate 13/0, Arrive 5/0; Travel 5/2 and RideEvents 8/1 on the known ticket), and every other suite 0 FAIL.
  - A suite that fails because it assumes Ye's map is reported, not changed. The controller rules.
  - Record each result.
- [ ] **Step 7: Commit** `sync.py`, `sync_manifest.json` and `test_sync.py`: `"Foundry data Task 1: sync tool; Foundry's package copies and place scripts caught up with Ye"`.

---

### Task 2: The quest engine: revised quests, quest deeds, clue evidence

**Files:**
- Modify:
  - `Scripts/ReplicatedStorage/Modules/Data/Rensei/StoryLogic.lua`;
  - `Scripts/ServerScriptService/QuestService.lua`;
  - `Scripts/ServerScriptService/ServerHandler.server.lua`;
  - `Scripts/ServerScriptService/TownsfolkService.lua`;
  - `Scripts/ReplicatedStorage/Modules/Data/Rensei/Quests.lua` (the header schema comment only);
  - `Documents/Region Builder.md` §6 ("The roster", the `Clue` line);
  - `sync_manifest.json`.
- Create: `Scripts/ServerStorage/RenseiTests/Test_QuestRevision.lua` and `Play_QuestEngine.lua`.

**Interfaces:**
- **`StoryLogic.UpgradeQuest(Def, State) -> boolean`** (pure):
  ```lua
  -- Saved quest states follow a revised quest (Foundry Yard plan, 2026-10-24). A definition with Revision = n and
  -- Prepended = {[r] = k} put k new stages in front of its stage list at revision r. A saved Active state from an older
  -- revision (State.Revision missing = 1) moves forward past those stages, so the player stays on the stage they were
  -- on. Returns true when it changed State.
  function StoryLogic.UpgradeQuest(Def, State)
  	if type(Def) ~= "table" or type(State) ~= "table" or type(Def.Revision) ~= "number" then return false end
  	local From = type(State.Revision) == "number" and State.Revision or 1
  	if From >= Def.Revision then return false end
  	local Shift = 0
  	for R = From + 1, Def.Revision do Shift += (type(Def.Prepended) == "table" and Def.Prepended[R]) or 0 end
  	State.Stage = (State.Stage or 1) + Shift
  	State.Revision = Def.Revision
  	return true
  end
  ```
- **`QuestService.UpgradeAll(Data) -> boolean`:** runs `UpgradeQuest` over every `Data.Quests.Active[QuestId]` with its definition, and returns whether any changed.
- **`QuestService.Boot()`:**
  - once only (a module-level `Booted` flag);
  - for every player now in the game and every `Players.PlayerAdded`, it polls `ProgressionService.GetData(Player)` every 0.5 s, up to 240 times, stopping when the player leaves;
  - when the data is there, it runs `UpgradeAll(Data)`, and calls `ProgressionService.Sync(Player)` if anything changed.
  - It isn't named `Start`, because `QuestService.Start(Player, QuestId)` already starts a quest.
- **`QuestService.Start`:** the new state is `{Stage = 1, Progress = Progress, Started = os.time(), Revision = Def.Revision}`.
- **`GiveRewards`:** after Training, `for _, Deed in ipairs(Rewards.Deeds or {}) do require(ServerScriptService.MoralityService).Record(Player, Deed) end`.
- **`ServerHandler.server.lua`:** directly after the `InvestigationService` Start line, add `require(ServerScriptService.QuestService).Boot() -- saved quest stages follow revised quests (Foundry Yard plan)`.
- **`TownsfolkService.Talk`:** when `Kind == "Clue"` and `type(Clue.Evidence) == "string"`, call `require(ServerScriptService.StoryService).GiveEvidence(Player, Clue.Evidence)` (pcall, warn on error) **before** the existing Signal block, so the next stage's catch-up sees the evidence. Update the header comment's Talk paragraph to say so.
- **`Quests.lua` header schema:**
  - `Rewards = {Exp, Money, Items, Codex, Deeds = {"deedId"} (recorded once each on completion)}`;
  - `Revision = n, Prepended = {[r] = k}` (see `StoryLogic.UpgradeQuest`).
- **Region Builder §6:** the `Clue` line gains `Evidence = "<evidence id>"` (optional: the evidence the line gives).

- [ ] **Step 1: Write the failing tests.**
  - **`Test_QuestRevision`** (pure, run in the Play VM), cases:
    1. Def `{Revision = 2, Prepended = {[2] = 1}}`, State `{Stage = 2}`: returns true; Stage 3, Revision 2.
    2. The same State again: false, Stage 3.
    3. State `{Stage = 1, Revision = 2}`: false.
    4. A Def without Revision: false, the State untouched.
    5. Def `{Revision = 3, Prepended = {[2] = 1, [3] = 2}}`, State `{Stage = 4, Revision = 2}`: Stage 6.
    6. A non-table State: false.
  - **`Play_QuestEngine`** (Play):
    - **`StartRecordsRevision`:** inject `QuestService.Definitions.__fy_q = {Title = "Test", Revision = 3, Stages = {{Id = "s1", Text = "t", Objectives = {{Id = "o", Text = "o", Kind = "Signal", Target = "__fy_sig"}}}}}`. `QuestService.Start(Player, "__fy_q")` then gives `Active.__fy_q.Revision == 3`.
    - **`UpgradeAllMovesOldStates`:** inject a 3-stage `__fy_q2` with `Revision = 2, Prepended = {[2] = 1}`, and set `Data.Quests.Active.__fy_q2 = {Stage = 1, Progress = {}}`. `UpgradeAll(Data)` gives true and Stage 2.
    - **`RewardsDeedsAreRecorded`:** inject `Deeds.__fy_deed = {Text = "Test deed", Conduct = {Order = 1}, Scope = "Private"}` into the required `Rensei.Deeds` table. `QuestService.Grant(Player, {Deeds = {"__fy_deed"}})` then gives `MoralityService.Has(Player, "__fy_deed")`.
    - **`ClueLineGivesEvidence`:** inject an evidence def `__fy_ev` into `Rensei.Evidence`, and a one-stage quest whose objectives are Evidence `__fy_ev` and Signal `__fy_sig`.
      - Spawn a test townsperson with `Clue = {Quest = "__fy_q3", Stage = 1, Signal = "__fy_sig", Evidence = "__fy_ev", Text = "x"}`, on a temporary RenseiPost on a floor at y 300. Use Play_Townsfolk's fixture pattern: its first free site.
      - Start the quest. `TownsfolkService.Talk` then gives Kind "Clue", the player holds `__fy_ev`, and the quest is Completed.
    - **Every test puts back** what it changed: the injected defs, `Data.Quests`, `Data.Story`, `Data.Morality` (deep copies taken first), the fixture parts, and the townsperson (`TownsfolkService.Despawn`).
- [ ] **Step 2: Add the pairs to the manifest.** Places ye and foundry:
  - `Rensei.StoryLogic`;
  - `RenseiServer.QuestService`;
  - `RenseiServer.ServerHandler`: Studio `ServerStorage/RenseiServer/ServerHandler`, Class Script, repo `Scripts/ServerScriptService/ServerHandler.server.lua`;
  - `RenseiTests.Test_QuestRevision` and `RenseiTests.Play_QuestEngine` (`Create: true`).
  - `RenseiServer.TownsfolkService` and `Rensei.Quests` are already listed.
- [ ] **Step 3: RED.** Sync **only the two test pairs** to Foundry. In Play in Foundry (PlayLock `Foundry:task2`), run Test_QuestRevision and Play_QuestEngine. Expected: Test_QuestRevision errors (no `UpgradeQuest`); Play_QuestEngine has 4 FAIL.
- [ ] **Step 4: Implement** as specified, then sync every changed pair to **both** places.
- [ ] **Step 5: GREEN.**
  - **Play in Foundry:** Test_QuestRevision 6/0 and Play_QuestEngine 4/0. Regressions: Play_Clue, Play_Townsfolk, Play_TownsfolkHurt and Play_Exams. Play_Exams: in Foundry no trainer exists yet, so record its result; it is fixed in Task 3.
  - **Then Play in Ye** (PlayLock `Ye:task2`): Test_QuestRevision, Play_QuestEngine, Play_LindenmoorData, Play_Clue, Play_Townsfolk, Play_Exams (5/0) and Play_LindenmoorSmoke (8/0).
- [ ] **Step 6:** `sync.py --check` in both places: `DIFFER 0 / MISSING 0`.
- [ ] **Step 7: Commit** the six repo files, the two tests, `Region Builder.md` and the manifest: `"Foundry data Task 2: revised quests keep saved stages, quest deeds, clue lines give evidence"`.

---

### Task 3: Areas, law, and `acq_metal`'s travel stage (data)

**Files:**
- Modify: `Rensei/Regions.lua`, `Quests.lua`, `Investigation.lua`, `Minigames.lua`, `Trials.lua` and `Dialogues.lua`; `RenseiTests/Test_Regions.lua` and `Play_Exams.lua`; `sync_manifest.json`.
- Create: `RenseiTests/Test_AcqMetal.lua`.

**Interfaces:**

**`Regions.Areas`:**
- `["Silent Forge"]` changes from `"Wilds"` to `"Foundry"`.
- Add a block with the comment `-- Foundry Yard's areas (Foundry Yard plan, 2026-10-24; Art/Regions/Foundry/layout.json): Foundry's law (State) and people (Foundry hands, townsfolk)`, mapping each of these to `"Foundry"`: Foundry Station, The Underworks, Practice Court, Cinder Lane, Lower Town, Freight Yard, South Road, Rail Yards, Workers' Row, Foundry Square and The Foundry.
- `Regions.Regions.Foundry` is unchanged: Factions Foundry and Townsfolk, Jurisdiction State.
- Foundry needs no `HubLaw`: `Regions.Default` in Foundry is already `"Foundry"`.

**`Quests.acq_metal`** (the other fields unchanged):
- `Revision = 2, Prepended = {[2] = 1}`, with a comment: "Foundry Yard plan: the travel stage was put in front at revision 2; QuestService.Boot moves older saves forward".
- `Description` = "A forge in the Foundry Yard's great hall went cold mid-shift. Brannoc wants the failure understood before a single bolt is turned."
- **A new first stage:** `{Id = "travel", Text = "Brannoc teaches at the Foundry Yard now. Take the train from Lindenmoor Station, or walk the North Road out of the valley.", Objectives = {{Id = "foundry", Text = "Travel to the Foundry Yard", Kind = "Arrive", Target = "Foundry"}}}`.
  - In Ye, the North Road leaves north-west; the text names no direction.
- **The `invite` stage text** = "Go to the silent forge at the back of the great hall, north-east of the practice court past the rail yards." Its objective is unchanged (Visit "Silent Forge").
- **The `trial` stage text** keeps "on the forge floor west of the workshop". It is still true in Foundry: the Forge Floor room (x 325) is west (−X) of the Silent Forge (x 373).
- The stage order is then travel, invite, fieldwork, experiment, trial, exam and recognition (1–7).

**Stage look-ups, by stage id, so no stage number is written by hand.** At the top of `Investigation.lua`, `Minigames.lua` and `Trials.lua` (before their `return`):
```lua
-- acq_metal's stage numbers by stage id (the Foundry Yard plan put a "travel" stage first)
local function MetalStage(Id)
	for I, S in ipairs(require(script.Parent.Quests).acq_metal.Stages) do
		if S.Id == Id then return I end
	end
	error("acq_metal has no stage " .. tostring(Id))
end
```
- **Investigation:** `metal_shaft`, `metal_samples`, `metal_gear` and `metal_note` get `Requires = {Quest = {Id = "acq_metal", StageAtLeast = MetalStage("fieldwork")}}` (3).
- **Minigames:** `metal_match` gets `Stage = MetalStage("experiment")` (4), and `metal_exam` gets `Stage = MetalStage("exam")` (6).
- **Trials:** `metal_experiment` gets `Requires = Stage("acq_metal", MetalStage("trial"))` (5). Also `Radius = 24` and `FoeDistance = 14`, with the comment `-- PROPOSAL (Foundry Yard plan, owner decision E): fits the great hall's 38.8 x 49.8 Forge Floor shell; were 34 / 16`. The rest is unchanged.

**The notice def** (Investigation, owner decision D):
```lua
brannoc_moved = {Title = "Brannoc's Notice", StartsQuest = "acq_metal", Requires = {NoAffinity = true},
	Text = "A notice nailed to the post where the Metal Alchemist used to stand, in square, careful capitals: \"GONE TO THE FOUNDRY YARD. A FORGE THERE NEEDS LOOKING AT. STUDENTS: TRAIN FROM LINDENMOOR STATION, OR THE NORTH ROAD. - B.\""},
```
- This is PROPOSAL wording.
- It has no Evidence, so `Requires` gates only the quest: a player who already has a path reads the notice and gets no toast.

**`Dialogues.lua`, the `Trainer(T)` helper:**
- `local O = T.Offset or 0`, and `At(N)` becomes `{Quest = {Id = Q, Is = "Active", Stage = N + O}}`.
- When `O > 0`, insert `{Requires = {Quest = {Id = Q, Is = "Active", Stage = 1}}, Node = "sent"}` directly after the `At(1)` entry in `Starts`.
- **Metal's call** passes `Offset = 1`.
- **Brannoc's lines:**
  - `demo` = "There's a forge at the back of the great hall, north-east of here past the rail yards. Went cold mid-shift. Find out why. Touch nothing until you can tell me what failed and why."
  - `sent` = "The great hall. Through the forge wing at the back, north-east past the rail yards. Look at the break, the stock and the repair. In that order."
  - Every other line is unchanged.

**Test changes:**
- **`Test_Regions`:**
  - "Silent Forge" maps to "Foundry";
  - each of the 11 names maps to "Foundry";
  - `Regions.Regions.Foundry.Jurisdiction == "State"`;
  - `Regions.Present("Foundry", "Foundry")`.
- **`Play_Exams`, the exam stage by id:** `local Stage = 0; for I, S in ipairs(require(game.ReplicatedStorage.Modules.Data.Rensei.Quests)["acq_" .. Path].Stages) do if S.Id == "exam" then Stage = I end end`, used instead of 5.
- **`Play_Exams`, per place:** `local WHERE = {flame = "Lindenmoor", ice = "Lindenmoor", earth = "Lindenmoor", wind = "Lindenmoor", metal = "Foundry"}`.
  - Each test runs `ExamOpens` when `WHERE[Path] == TravelService.Here()`.
  - Otherwise it asserts that **no** model with DialogueId `trainer_<path>` is in `workspace` (moved away). That assertion fails in Ye until Task 8, and in Foundry until Task 7, as it should.

**`Test_AcqMetal`** (new, pure, Play VM). Each assertion has its message:
- the stage ids in order: travel, invite, fieldwork, experiment, trial, exam, recognition;
- the travel objective is Arrive "Foundry";
- Revision 2, and `Prepended[2] == 1`;
- the four `metal_*` inspects' `StageAtLeast == 3`;
- `metal_match` Stage 4 and `metal_exam` Stage 6;
- the trial Stage 5;
- `Radius * 1.35 >= 31.6` (the shell's half-diagonal, `math.sqrt(19.4^2 + 24.9^2)`) and `FoeDistance <= 22.9` (half the room's 49.8, minus 2);
- in `trainer_metal`'s Starts, the first entry whose `Requires.Quest.Stage` is 1 and the first whose Stage is 2 both name "sent", then 3 fieldwork, 4 experiment, 5 trial, 6 exam and 7 recognize;
- `trainer_ice` still maps Stage 1 to "sent" (offset 0);
- `brannoc_moved.StartsQuest == "acq_metal"`;
- `Regions.Bearing(600, -830, "-Z")` (the court (−200, 490) to the hall (400, −340)) lies between 0 and 90, and the invite text contains "north-east".

**Steps:**
- [ ] **Step 1:** Write `Test_AcqMetal` and the `Test_Regions` additions. Add the pairs `Rensei.Minigames`, `Rensei.Trials` and `RenseiTests.Test_AcqMetal` (`Create: true`) to the manifest. Sync only the two tests to Foundry. In Play in Foundry (PlayLock `Foundry:task3`), expected: both FAIL.
- [ ] **Step 2:** Implement every data change. Run `luau-analyze` if it is on PATH; otherwise `require` each changed module once in the Play VM. Sync all changed pairs to **both** places.
- [ ] **Step 3: GREEN in Play in Foundry:**
  - Test_AcqMetal 0 FAIL and Test_Regions 0 FAIL;
  - Play_Exams: four "moved away" passes, and MetalExamOpens FAILS (no trainer in Foundry before Task 7, as expected);
  - Play_Clue 0 FAIL.
- [ ] **Step 4: Play in Ye:** Test_AcqMetal, Test_Regions, Play_LindenmoorData and Play_Clue. Don't run Play_Exams in Ye: it is red there until Task 8 moves Brannoc out. Record that.
- [ ] **Step 5:** `sync.py --check` in both places: `DIFFER 0 / MISSING 0`.
- [ ] **Step 6: Commit** the six data files, the three tests and the manifest: `"Foundry data Task 3: Foundry's areas, acq_metal's travel stage, the forge trial fits its shell"`.

---

### Task 4: Foundry's posts: shelters for everyone, every post reachable

**Files:**
- Create: `Art/Studio/Regions/Foundry/foundry_posts.lua` (hand-written; the MODE line as in the Global Constraints).
- Modify:
  - `Art/Regions/Foundry/layout.json`: the 12 new Shelter markers, the two moved posts, and a top-level `"RestoreRefuseFlags": ["FoundryPosts", "FoundryForge"]`;
  - `Art/Blender/region_builder/tests/foundry_check.py`;
  - `Art/Studio/Regions/Foundry/import/restore.lua`: regenerated with `python -I Art/Studio/Regions/kit.py Foundry --date 2026-10-24`. Only this file may change; check `git status --short Art/Studio/Regions/Foundry`.

**Interfaces** (Foundry, Edit; flag `World.Map.Foundry:SetAttribute("FoundryPosts", "applied")`):

**(a) 12 new Shelter posts** (PROPOSAL spots, Yaw 0):
- `freight_shelter` (300, 180)
- `crane_shelter` (303, −150)
- `stack_shelter` (350, −515)
- `casting_shelter` (600, −610)
- `square_east_shelter` (−90, −340)
- `boarding_shelter` (−400, −370)
- `row_north_shelter` (−560, −330)
- `row_south_shelter` (−480, −650)
- `court_shelter` (−170, 470)
- `shed_shelter` (−200, −120)
- `cinder_west_shelter` (−400, 280)
- `cinder_east_shelter` (−100, 280)

How each one is placed:
- **The spot:** take the target, or the first point within 6 studs of it on a 2-stud spiral, that meets all of these:
  - a ray down from y 60 meets a `Map.Foundry` part (outside `Markers`) whose top is between 3.9 and 4.6;
  - a 3 × 5.5 × 3 box over the stand point holds no CanCollide part;
  - a path exists from the hub (below) at the Mover's radii.
- **The part:** a clone of `station_shelter`'s properties (2-stud, invisible, CanCollide, CanQuery and CanTouch false), named `FoundryShelter_<PostId>`, with its centre at the top + 1. It goes in `Map.Foundry.Markers.Markers_Foundry`, tagged RenseiPost, with `PostId`, `Kind = "Shelter"` and `FoundryPostAdd = true`.
- **With these targets the farthest post from any shelter is 140 studs** (`yard_hand_4` to `yard_shelter`; `station_porter_platform` is 137.6 and `lower_home_3` 134.1).

**(b) Two posts move** off the goods platform, `yard_hand_2` from (420, 9, 154) and `yard_hand_3` from (560, 9, 154):
- They go to (420, _, 164) and (560, _, 164), centre at the ground top + 1, still facing −Z (Yaw 0).
- If a target fails the spot test, try z 144, also Yaw 0. If that fails too, refuse and report.
- Each moved part gets `FoundryPostFrom` = its old CFrame as 12 numbers.

**(c) The four trader stalls become walkable behind the counter:**
- For each `market_trader_N`, find the `MarketStall_*` model whose `Counter` lies within 3 studs (XZ) of the post. Set that model's `Shelf` to `CanCollide = false`, with `FoundryShelfFrom = true`.
- If the post still has no path, move it toward the stall's back (along −LookVector) by 0.8 and then 1.6 studs, and keep the first that works, with `FoundryPostFrom`. If neither works, refuse and report.

**The reach test**, used by `check` and by (a)–(c):
- from the hub `errand_square` + (0, 2, 0) (for `errand_square` itself, from `guard_square` + (0, 2, 0));
- `PathfindingService:CreatePath` with AgentHeight 5.5, AgentCanJump false and AgentCanClimb false, at AgentRadius 2.5, then 2, then 1.5, then 1 (`Mover.Agent`, `NarrowRadii`, `SqueezeRadius`);
- Success means the last waypoint is within 2.5 studs of the post's stand point (the post + 2).

**`check`** (read-only) reports and fails on:
- any of the 88 posts unreachable;
- any post whose nearest Shelter is more than 145 studs away;
- a duplicate PostId;
- a new shelter that isn't tagged, or isn't on the ground.

**`undo`:**
- destroys the `FoundryPostAdd` parts;
- moves the `FoundryPostFrom` parts back and clears the attribute;
- sets every `FoundryShelfFrom` Shelf back to CanCollide true;
- clears the flag.
- Guard: it refuses while `Map.Foundry` has `FoundryRoster` (set by nothing yet; reserved). There are no other guards.

**The region file** (`Art/Regions/Foundry/layout.json`):
- add 12 `{"Tag": "RenseiPost", "At": [x, 0, z], "Yaw": 0, "Attr": {"PostId": "<id>", "Kind": "Shelter"}}` markers, at the spots `apply` really used (rounded to 0.1);
- change `yard_hand_2` and `yard_hand_3`'s `At` to `[420, 0, 164]` and `[560, 0, 164]` (or the z the script chose);
- the stall shelves are kit-built geometry. Record the shelf change in the region file's top-level `"Notes"` list (create it if missing) as `"Foundry Yard plan Task 4: the four market stalls' Shelf parts are walk-through in Studio (foundry_posts.lua), so traders can reach their counters; the builder still makes them solid"`.

**`foundry_check.py`:** add a check, "every post has a Shelter within 145 studs (Foundry Yard plan)", on the layout's markers.

**Steps:**
- [ ] **Step 1: RED.**
  - Add the `foundry_check.py` check and run `python -I Art/Blender/region_builder/tests/foundry_check.py`. Expected: the new check FAILs, listing 47 posts; the 35 old checks pass.
  - Write `foundry_posts.lua`, and run it with `MODE = "check"` in Foundry (Edit) **before apply**. Expected: it FAILs on 6 unreachable posts (`market_trader_1..4` and `yard_hand_2/3`) and on 47 posts without a shelter in reach. This proves the check can fail.
- [ ] **Step 2: Test.** `MODE = "test"`. Expected: `0 FAIL`; the round trip is exact. The snapshot covers:
  - every BasePart under `Map.Foundry.Markers` and every `MarketStall_*` model: path, CFrame rounded to 0.01, CanCollide, sorted attributes and tags;
  - the per-tag counts in workspace;
  - the workspace BasePart count.
  Foundry stays un-applied after it.
- [ ] **Step 3: Apply** (`MODE = "apply"`), then `check`. Expected: 88 posts, all reachable, worst shelter distance ≤ 145. Record the 12 shelter spots used, the two yard posts' new z, and whether any trader post moved.
- [ ] **Step 4: Update** `layout.json` with the real spots. Re-run `foundry_check.py` (the new check passes; all checks pass) and `python -I Art/Blender/region_builder/tests/run.py` (expected: all pass).
- [ ] **Step 5: Regenerate** `restore.lua` with `kit.py Foundry --date 2026-10-24`. `git status` must show only `import/restore.lua` changed under `Art/Studio/Regions/Foundry/`. Read the diff: the guard lists `FoundryPosts` and `FoundryForge`.
- [ ] **Step 6: Commit** `foundry_posts.lua`, `layout.json`, `foundry_check.py` and `import/restore.lua`: `"Foundry data Task 4: shelters within reach of every post, every post reachable (reversible)"`.

---

### Task 5: Foundry's roster (26 townsfolk, two shifts)

**Files:**
- Modify: `Rensei/Townsfolk.lua` (add `local Foundry = {...}` and return `{Regions = {Lindenmoor = Lindenmoor, Foundry = Foundry}}`); `sync_manifest.json`.
- Create: `RenseiTests/Test_FoundryRoster.lua`.

**Interfaces:**
- **The shape:** each entry is `{Id, Name, Job, JobLine, Faction, Idle, Look = {Nation, Gender, Seed}, Schedule = {{From, To, PostId}, ...}}`, as in `Townsfolk.Regions.Lindenmoor`.
- Every name, line, hour and seed is a **PROPOSAL** (a comment says so).
- The `Clue` fields of `fy_furnace_d1`, `fy_furnace_l1` and `fy_clerk` are added by Task 6, not here.
- **The day** (comment it in the file, as Lindenmoor's block is):
  - the day crew works 06–14 and eats 14–15;
  - the late crew eats 13–14, works 14–22 and eats 22–23;
  - the furnace keeper holds the banked fires 22–06;
  - the canteen cooks cover 05–23;
  - the market is open 08–20;
  - the boarding keeper keeps the desk round the clock;
  - two errand runners work 08–19;
  - two off-duty guards idle 08–20 and spend the night on a bench or at home.
- The rigs are adult R6s (there is no child rig), so the runners are "errand runners".

| Id | Name (Gender) | Job | Faction | Nation, Seed | Idle | Schedule | JobLine |
|---|---|---|---|---|---|---|---|
| fy_crane_d1 | Hollis Brandt (M) | Crane hand | Foundry | Amestrian 3101 | NPC_HandInPocket | {6,14,crane_bay_1},{14,15,canteen_seat_1},{15,6,workers_row_1} | "Bay one, mornings. If the hook's moving, you're not standing under it." |
| fy_crane_l1 | Wren Coller (F) | Crane hand | Foundry | Amestrian 3102 | NPC_HandInPocket | {13,14,canteen_seat_1},{14,22,crane_bay_1},{22,23,canteen_seat_1},{23,13,workers_row_2} | "I take the bay crane after Hollis. He leaves the cab warm and the levers sticky." |
| fy_crane_d2 | Piotr Sabelev (M) | Crane hand | Foundry | Drachman 3103 | NPC_HandInPocket | {6,14,crane_bay_3},{14,15,square_seat_1},{15,6,workers_row_3} | "Came south for the wages. Stayed for the canteen, heaven help me." |
| fy_crane_l2 | Agna Thorley (F) | Crane hand | Foundry | Amestrian 3104 | NPC_CrossArms | {13,14,square_seat_2},{14,22,crane_bay_3},{22,13,workers_row_4} | "Bay three, afternoons. Don't wave at the cab. I can't wave back." |
| fy_furnace_d1 | Edmund Rusk (M) | Furnace hand | Foundry | Amestrian 3105 | NPC_Blacksmith | {6,14,furnace_1},{14,15,canteen_seat_2},{15,6,workers_row_5} | "Furnace One, mornings. Twelve years, and she's never once let me forget it's her shift, not mine." |
| fy_furnace_l1 | Sella Marsh (F) | Furnace hand | Foundry | Amestrian 3106 | NPC_Blacksmith | {13,14,canteen_seat_2},{14,22,furnace_1},{22,23,canteen_seat_2},{23,13,workers_row_6} | "Late shift at Furnace One. You get used to the heat. You never get used to the noise." |
| fy_furnace_d2 | Gideon Pell (M) | Furnace hand | Foundry | Amestrian 3107 | NPC_Blacksmith | {6,14,furnace_2},{14,15,canteen_seat_3},{15,6,workers_row_7} | "Furnace Two. Keep back from the mouth, unless you fancy losing your eyebrows." |
| fy_furnace_l2 | Tamsin Hale (F) | Furnace hand | Foundry | Amestrian 3108 | NPC_Blacksmith | {13,14,canteen_seat_3},{14,22,furnace_2},{22,23,canteen_seat_3},{23,13,workers_row_8} | "Afternoons on Two. I'll eat when the pour's done." |
| fy_keeper | Oswin Tarr (M) | Furnace keeper | Foundry | Amestrian 3109 | NPC_CrossArms | {22,6,furnace_3},{6,7,canteen_seat_4},{7,21,boarding_home_1},{21,22,canteen_seat_4} | "Somebody keeps the fires in overnight. Banked, not out. Out is a week's work to light again." |
| fy_gantry_d | Rhea Calloway (F) | Gantry hand | Foundry | Amestrian 3110 | NPC_HandInPocket | {6,14,hall_gantry},{14,15,canteen_seat_4},{15,6,workers_row_9} | "Up on the gantry you see everything. Mostly you see people standing where they shouldn't." |
| fy_casting_l | Bram Okonek (M) | Casting hand | Foundry | Amestrian 3111 | NPC_Blacksmith | {13,14,canteen_seat_4},{14,22,casting_floor},{22,23,canteen_seat_4},{23,13,workers_row_10} | "Pour's at four. If you're on the floor when the ladle tips, you'd best be quick." |
| fy_yard_d | Nell Ashgrove (F) | Yard hand | Foundry | Amestrian 3112 | NPC_HandInPocket | {6,14,yard_hand_1},{14,6,cinder_home_1} | "Wagons in, wagons out. Count them twice. The Authority counts them three times." |
| fy_yard_l | Ivo Kettle (M) | Yard hand | Foundry | Amestrian 3113 | NPC_HandInPocket | {14,22,yard_hand_4},{22,14,cinder_home_2} | "Evening freight's the worst. Nobody signs for anything after dark." |
| fy_porter | Dunstan Rook (M) | Station porter | Townsfolk | Amestrian 3114 | NPC_CrossArms | {6,14,station_porter_platform},{14,22,station_porter_yard},{22,6,lower_home_1} | "Platform in the morning, the freight side after. Bags, crates, lost children. I've carried all three." |
| fy_clerk | Aldous Merriweather (M) | Shift clerk | Foundry | Amestrian 3115 | NPC_CrossArms | {6,18,shift_clerk},{18,6,lower_home_3} | "Every hour worked in this yard goes through my pen. Every hour." |
| fy_cook_1 | Su Ling Pao (F) | Canteen cook | Townsfolk | Xingnese 3116 | NPC_CrossArms | {5,14,canteen_cook},{14,5,boarding_home_2} | "Breakfast at five, and the day crew eats it whether they're awake or not." |
| fy_cook_2 | Harlan Dace (M) | Canteen cook | Townsfolk | Amestrian 3117 | NPC_CrossArms | {14,23,canteen_cook},{23,14,boarding_home_3} | "Stew at two, stew at ten. Ask what's in it and you'll get less." |
| fy_trader_1 | Ottilie Brack (F) | Market trader | Townsfolk | Amestrian 3118 | NPC_CrossArms | {8,20,market_trader_1},{20,8,boarding_home_4} | "Gloves, aprons, goggles. Everything the Foundry wears out, I sell back to it." |
| fy_trader_2 | Cassio Benedetti (M) | Market trader | Townsfolk | Aerugonian 3119 | NPC_CrossArms | {8,20,market_trader_2},{20,8,cinder_home_4} | "Oil and olives from the south. The olives are real. The oil is mostly real." |
| fy_trader_3 | Mabel Ferris (F) | Market trader | Townsfolk | Amestrian 3120 | NPC_CrossArms | {8,20,market_trader_3},{20,8,cinder_home_5} | "Bread from the bakehouse on Mill Street. Still warm if you're early." |
| fy_trader_4 | Jonas Abernathy (M) | Market trader | Townsfolk | Amestrian 3121 | NPC_CrossArms | {8,20,market_trader_4},{20,8,cinder_home_6} | "Pots, pans, kettles, all cast in the hall. Seconds, mind. That's why they're cheap." |
| fy_boarding | Winifred Tull (F) | Boarding-house keeper | Townsfolk | Amestrian 3122 | NPC_CrossArms | {0,24,boarding_keeper} | "Rooms by the week, paid in advance. No cooking in the rooms, and no alchemy anywhere." |
| fy_runner_1 | Pip Garrow (M) | Errand runner | Townsfolk | Amestrian 3123 | NPC_HandInPocket | {8,11,errand_square},{11,14,errand_row},{14,17,court_seat_2},{17,19,errand_square},{19,8,workers_row_11} | "A copper a message, two if it's heavy, three if it's for the shift office." |
| fy_runner_2 | Tilly Mace (F) | Errand runner | Townsfolk | Amestrian 3124 | NPC_HandInPocket | {8,11,errand_row},{11,14,errand_square},{14,17,court_seat_1},{17,19,errand_row},{19,8,lower_home_2} | "I run for the canteen and the market both. They both pay late." |
| fy_guard_1 | Ewan Stroud (M) | Off-duty guard | Townsfolk | Amestrian 3125 | NPC_CrossArms | {8,20,guard_square},{20,8,square_seat_2} | "Off duty. If you need the watch, the watch is somewhere else." |
| fy_guard_2 | Hester Quayle (F) | Off-duty guard | Townsfolk | Amestrian 3126 | NPC_CrossArms | {8,20,guard_station},{20,8,cinder_home_3} | "I watch the trains come in. Habit. Don't read anything into it." |

Notes on the roster:
- **Shared posts at different hours** (allowed: Validate's half-open slots):
  - `canteen_seat_1..4`, `crane_bay_1/3`, `furnace_1/2` and `square_seat_2`;
  - `canteen_seat_4`, which has `fy_keeper` 06–07 and 21–22, `fy_casting_l` 13–14 and 22–23, and `fy_gantry_d` 14–15.
- **All 24 Home posts are used.** Unused (allowed): `crane_bay_2/4`, `canteen_cook_2`, `forge_wing_1/2`, `stack_yard`, `slag_lane`, `casting_shed_1/2`, `shed_hand_1/2`, `court_hand`, `yard_hand_2/3`, and every Shelter.
- **The guards' faction is Townsfolk** (PROPOSAL). An Authority agent counts as law and adds Heat on sight, and these two are off duty.

**`Test_FoundryRoster`** (Play VM), each failure named:
- **Validate:** `TownsfolkLogic.Validate(Townsfolk.Regions.Foundry, PostIds)` passes, where PostIds are the RenseiPosts in `workspace.World.Map.Foundry`.
- **Size:** 26 entries, ids unique and starting `fy_`.
- **Names:** no Name equals any name in `Townsfolk.Regions.Lindenmoor`, `TownsfolkLogic.NewcomerNames`, or the DisplayName of a DialogueId model in workspace.
- **Nations:** every Look.Nation is in `Customization.NationLooks`, and every Idle is a child of `ReplicatedStorage.Assets.Animations` (search its descendants by name).
- **Shelters:** for every post a schedule uses, the nearest Shelter in `Map.Foundry` is ≤ 145.
- **Hours:** at each hour h = 0..23, the posts in use are distinct (a direct check alongside Validate). The canteen seats hold at least 4 people at 13:00, 14:00 and 22:00 (the canteen fills at shift change), and every `market_trader_N` is in use at 08:00 and at 19:00, and at no hour from 20:00 to 07:00.

**Steps:**
- [ ] **Step 1: RED.** Write the test and add `RenseiTests.Test_FoundryRoster` (`Create: true`) to the manifest. Sync it to Foundry and run it in Play in Foundry (PlayLock `Foundry:task5`). Expected: it FAILs, with no roster.
- [ ] **Step 2: Implement** the roster. Sync `Rensei.Townsfolk` and the test to both places.
- [ ] **Step 3: GREEN in Play in Foundry:**
  - **Test_FoundryRoster:** 0 FAIL.
  - **The roster is live:** `TownsfolkService` has 26 townsfolk (`TownsfolkService.Get` for each Id), with no "refused" warning in the server output (`get_console_output`).
  - **At their posts:** with `WorldClock.Hold(10)`, 1.5 s later every rig's post is its 10:00 post and it stands within 1.5 studs of the post's stand point. Do this as Play_LindenmoorData's TownsfolkRoster test does: use the same calls, run inline from the session script. Put the clock back.
  - **Regressions:** Play_Townsfolk, Play_TownsfolkCrowd and Play_TownsfolkHurt, 0 FAIL, now with Foundry's roster live.
- [ ] **Step 4: Play in Ye:** Play_LindenmoorData and Play_Townsfolk, 0 FAIL. Ye's roster is unaffected.
- [ ] **Step 5:** `sync.py --check` in both places.
- [ ] **Step 6: Commit** `Townsfolk.lua`, `Test_FoundryRoster.lua` and the manifest: `"Foundry data Task 5: Foundry Yard's 26 townsfolk on two shifts"`.

---

### Task 6: The shift-ledger quest (spec §7.3)

**Files:**
- Modify: `Rensei/Investigation.lua`, `Evidence.lua`, `Deeds.lua`, `Quests.lua` and `Townsfolk.lua` (Clue fields on three entries); `sync_manifest.json`.
- Create: `RenseiTests/Play_FoundryLedger.lua`.

**Interfaces** (all wording and numbers PROPOSAL, original).

**The story:**
- On the 14th, Furnace One's tuyere cracked and the furnace was banked at 18:00, four hours into the late shift. The late crew was sent home and paid four hours.
- The late-shift charge hand, C. Ashe, scraped the 4 on his docket into an 8 and drew eight hours of wages.
- The clerk copied the docket into the ledger faithfully.
- Ashe is not a townsperson. The quest ends at the deduction.

**Inspects** (in Investigation's `Inspects`, a new block `-- ===== Foundry Yard: the shift ledger (Foundry Yard plan, 2026-10-24) =====`):
```lua
foundry_shift_ledger = {Title = "Shift Ledger", Evidence = "foundry_full_shift", StartsQuest = "foundry_ledger",
	Text = "The Foundry's shift ledger lies open on the lectern, copied out fair in the clerk's tidy hand. Furnace One, late shift, the 14th: six names, eight hours each. Further down the same page, the furnace log reads \"Furnace One banked 18:00, tuyere cracked.\" A banked furnace has no crew.",
	AfterText = "Furnace One's late crew, booked for eight hours on a day the furnace was banked four hours in."},
foundry_altered_docket = {Title = "Shift Docket", Evidence = "foundry_scraped_docket",
	Requires = {Quest = {Id = "foundry_ledger", StageAtLeast = 2}}, Locked = "A bundle of damp paper wedged behind a pipe.",
	Text = "A bundle of shift dockets, damp from the tunnel. The one for Furnace One, late shift, the 14th, reads \"8 hrs\". The paper under the 8 is scraped thin, and you can still make out a 4. It is signed by the late-shift charge hand: C. Ashe.",
	AfterText = "The docket for the 14th: a 4 scraped into an 8, signed C. Ashe."},
```

**Deduction** (in `Deductions`):
```lua
foundry_ledger_who = {
	Title = "The Shift Ledger",
	Question = "Who altered the shift ledger, and how?",
	Requires = {Evidence = {"foundry_full_shift", "foundry_banked_early", "foundry_short_pay", "foundry_docket_round", "foundry_scraped_docket"}},
	Slots = {
		{Label = "What the ledger claims", Answer = "foundry_full_shift"},
		{Label = "What the crew really worked", Answer = "foundry_short_pay"},
		{Label = "Where the false hours were written", Answer = "foundry_scraped_docket"},
	},
	Conclusion = "The clerk copied what he was given. The lie was written on the docket before it reached him: Ashe, the late-shift charge hand, scraped a 4 into an 8 and drew pay for hours his crew never worked.",
	Wrong = "That doesn't hold together. Look at what each piece actually tells you.",
},
```

**Evidence** (`Quest = "foundry_ledger"`):

| Id | Title | Text |
|---|---|---|
| foundry_full_shift | A Full Shift Booked | "The shift ledger books Furnace One's late crew for a full eight hours on the 14th. The same page says the furnace was banked at 18:00, four hours in." |
| foundry_banked_early | Sent Home at Six | "Edmund Rusk, day furnace hand: Furnace One was banked by 18:00 on the 14th and the late crew sent home. Nobody worked it after six." |
| foundry_short_pay | Four Hours' Pay | "Sella Marsh, late furnace hand: her pay packet for the 14th held four hours. The ledger books eight. Someone drew pay for hours nobody worked." |
| foundry_docket_round | Copied from the Dockets | "Aldous Merriweather, the shift clerk, copies the ledger from the charge hands' dockets, word for word. Once copied, the dockets are filed in a store in the underworks." |
| foundry_scraped_docket | The Scraped Docket | "Furnace One's late-shift docket for the 14th. Someone scraped the 4 off and wrote an 8 before the clerk copied it. Signed by the charge hand, C. Ashe." |

**Deed** (`Deeds.lua`, a new block):
```lua
foundry_ledger_cleared = {Text = "Found out who was faking hours in the Foundry's shift ledger",
	Conduct = {Candor = 5, Order = 5}, Standing = {Foundry = 10}, Scope = "Local"}, -- PROPOSAL
```

**Quest** (`Quests.lua`, after `lm_mine`):
```lua
foundry_ledger = {
	Title = "The Shift Ledger", Category = "Investigation",
	Description = "Someone has been changing the hours in the Foundry's shift ledger. The shift office would like to know who before the paymaster does.",
	Stages = {
		{Id = "ask", Text = "Find out what really happened on the 14th. Ask Furnace One's crews, Edmund Rusk (days) and Sella Marsh (the late shift), and Aldous Merriweather, the clerk at the shift office.", Objectives = {
			{Id = "ledger", Text = "Read the shift ledger", Kind = "Evidence", Target = "foundry_full_shift"},
			{Id = "rusk", Text = "Ask Edmund Rusk (Furnace One by day; Workers' Row after 15:00)", Kind = "Signal", Target = "foundry_ledger_rusk"},
			{Id = "marsh", Text = "Ask Sella Marsh (Furnace One, 14:00-22:00; Workers' Row in the morning)", Kind = "Signal", Target = "foundry_ledger_marsh"},
			{Id = "clerk", Text = "Ask Aldous Merriweather at the shift office (06:00-18:00)", Kind = "Signal", Target = "foundry_ledger_clerk"},
		}},
		{Id = "docket", Text = "The copied dockets are filed in a store in the underworks, the tunnel along the south edge of town. Find the one for the 14th.", Objectives = {
			{Id = "docket", Text = "Find the docket for the 14th", Kind = "Evidence", Target = "foundry_scraped_docket"},
		}},
		{Id = "deduce", Text = "Put it together on your Case Board (J).", Objectives = {
			{Id = "who", Text = "Work out who altered the ledger", Kind = "Deduce", Target = "foundry_ledger_who"},
		}},
	},
	Rewards = {Exp = 300, Money = 100, Deeds = {"foundry_ledger_cleared"}}, -- PROPOSAL
},
```
- The underworks is at +Z, which is south on Foundry's compass.
- `docket` is both the second stage's Id and its objective's Id. Quest objective ids must be unique only among objectives.

**Clue lines** (on the Task 5 roster entries; `Stage = 1`):
- **`fy_furnace_d1`:** `Clue = {Quest = "foundry_ledger", Stage = 1, Signal = "foundry_ledger_rusk", Evidence = "foundry_banked_early", Text = "The 14th? I was handing over to the late lot when the tuyere cracked. We banked her by six and sent them home. Nobody stood at Furnace One past six that night, and I'll swear to it."}`
- **`fy_furnace_l1`:** `Clue = {Quest = "foundry_ledger", Stage = 1, Signal = "foundry_ledger_marsh", Evidence = "foundry_short_pay", Text = "Four hours. That's what was in my packet for the 14th, and I didn't argue, because I'd only done four. If the ledger says eight, somebody drew wages for hours none of us worked."}`
- **`fy_clerk`:** `Clue = {Quest = "foundry_ledger", Stage = 1, Signal = "foundry_ledger_clerk", Evidence = "foundry_docket_round", Text = "I copy the ledger every morning from the charge hands' dockets, exactly as written. Once they're copied they go down to the store in the underworks. If the ledger's wrong, the docket was wrong. Go and look, if you can stomach the company down there."}`

**`Play_FoundryLedger`** (Play, in Foundry, inside the hook):
- **Setup:** take deep copies of `Data.Quests`, `Data.Story` and `Data.Morality`, and of `QuestService.Definitions.foundry_ledger.Rewards`. Set `Definitions.foundry_ledger.Rewards = {}` for the end-to-end run, and put everything back in a `finally` block.
- **Tests:**
  - **`DocketIsLockedFirst`:** with no quest, inspecting `foundry_altered_docket` (player within 9 studs; `InvestigationService.Inspect(Player, Id, Part)`) gives no evidence and doesn't start a quest.
  - **`LedgerStartsTheQuest`:** inspecting `foundry_shift_ledger` gives `foundry_full_shift`, the quest is Active at stage 1, and `ledger` is done.
  - **`CrewAndClerkAnswer`:** for each of the three tellers, `TownsfolkService.Talk(Player, Id)` returns Kind "Clue" and its Text; the player holds the evidence; the stage reaches 2 after the third.
    - Each Talk needs the player within the talk range: pivot the character beside the rig first.
    - Each Talk needs a calm state: wait up to 5 s for `TownsfolkService.State(Id)` to be AtPost or Asleep.
  - **`DocketFound`:** at stage 2, inspecting the docket gives `foundry_scraped_docket`; the stage reaches 3.
  - **`DeductionNeedsTheRightPieces`:**
    - `InvestigationService.Deduce(Player, "foundry_ledger_who", {"foundry_banked_early", "foundry_short_pay", "foundry_scraped_docket"})` returns false with the Wrong text;
    - the right answer returns true; the quest is Completed.
  - **`RewardsAsDesigned`** (with the real Rewards put back): `Rewards.Exp == 300`, `Money == 100` and `Deeds[1] == "foundry_ledger_cleared"`. `Deeds.foundry_ledger_cleared.Standing.Foundry == 10`. `QuestService.Grant(Player, {Deeds = {"foundry_ledger_cleared"}})` records the deed. Morality is put back afterwards.
  - **`CompassFindsTheClues`:** `ReplicatedStorage.CompassPoints` has an Inspect point for both clues, within 0.5 of the parts.

**Steps:**
- [ ] **Step 1: RED.** Write the suite and add `RenseiTests.Play_FoundryLedger` and `Rensei.Deeds` to the manifest. Sync the suite to Foundry and run it in Play (PlayLock `Foundry:task6`). Expected: every test FAILs (no defs).
- [ ] **Step 2: Implement.** Sync the five data pairs and the suite to **both** places.
- [ ] **Step 3: GREEN in Play in Foundry:**
  - Play_FoundryLedger 0 FAIL;
  - regressions: Play_Clue, Test_FoundryRoster and Play_Townsfolk;
  - the server output has no "InvestigationService: ... unknown InspectId" for the two clues.
- [ ] **Step 4: Play in Ye:** Play_LindenmoorData and Play_Clue, 0 FAIL. The new defs are inert there.
- [ ] **Step 5:** `sync.py --check` in both places.
- [ ] **Step 6: Commit** the five data files, the suite and the manifest: `"Foundry data Task 6: the shift-ledger quest"`.

---

### Task 7: The forge rooms, Brannoc and the alchemist spawn, in Foundry

**Files:**
- Create, in `Art/Studio/Regions/Foundry/forge/`:
  - `export_forge.lua`: Ye, read-only, apart from its temporary `ServerStorage.FoundryForgeExport` StringValue, which it removes;
  - `forge_kit.json`;
  - `bundle_forge.py`;
  - `build_forge.lua.tmpl`;
  - `build_forge.lua` (generated);
  - `test_bundle_forge.py`.
- Create: `RenseiTests/Play_FoundryForge.lua`.
- Modify: `sync_manifest.json`.

**Interfaces:**

**`forge_kit.json`** is written by `export_forge.lua` from Ye:
```json
{"Source": "Ye 106992859583940, 2026-10-24", "Pieces": [
  {"Group": "SilentForge", "Path": "Interactables/MaterialBench", "Class": "Part", "CFrame": [12 numbers, Ye world],
   "Size": [x, y, z], "Color": [r, g, b], "Material": "Metal", "MaterialVariant": "", "Transparency": 0, "Reflectance": 0,
   "CanCollide": true, "CanQuery": true, "CanTouch": true, "CastShadow": true, "Anchored": true, "Shape": "Block",
   "MeshId": null, "TextureID": null, "Attributes": {"MechanismId": "metal_bench"}, "Tags": ["RenseiMechanism"]}, ...],
 "Models": [{"Group": "SilentForge", "Path": "Interactables/WorkshopRecord/Model", "Attributes": {}}, ...],
 "Brannoc": {"Attributes": {...the 9 listed, without LindenmoorPrepFrom}, "Root": [12 numbers],
   "Humanoid": {"DisplayName": "...", "DisplayDistanceType": "...", "NameDisplayDistance": n, "HealthDisplayDistance": n}},
 "Ward": {...one piece, as above}}
```
- **The SilentForge pieces exported are these 20:**
  - `Interactables` and everything in it: WorkshopRecord and its Model's 3 MeshParts, MaterialBench, RepairedGear, SampleRack and DriveShaft;
  - Sample1..5, `Iron Alchemy` (its 3 MeshParts), Machine, Desk, Anvil and `Silent ForgeArea`.
  - **Left out on purpose** (the shell replaces them): WestA, WestB, EastA, SouthA, SouthB, North, Floor, Furnace and FurnaceMouth.
- **Also exported:**
  - `ForgeFloor.TrialMarker` only;
  - Brannoc's attributes, Humanoid display fields and props (`ScrollStand`, and the `Metal Alchemy` Model's Paper);
  - the Ward spawn.
- **Attributes:** only string, number and boolean are exported. Any other type makes the export refuse and name it. `LindenmoorPrepFrom` is dropped.

**`bundle_forge.py`** (`python -I .../bundle_forge.py <out.lua> [plan|apply|undo|check|test]`):
- fills `build_forge.lua.tmpl` with the kit as a Lua table literal;
- writes the generated header and the MODE line;
- also writes the committed `build_forge.lua` with `MODE = "plan"`;
- `test_bundle_forge.py` checks that the kit round-trips into the bundle, that the bundle's MODE line is the one asked for, and that `build_forge.lua` equals a fresh bundle with MODE "plan".

**`build_forge.lua`** (Foundry, Edit; flag `Map.Foundry` `FoundryForge = "applied"`; marks `FoundryForgeAdd = true`). Everything it builds goes in a new Model, `Map.Foundry.ForgeRooms`, with sub-models `SilentForge` and `ForgeFloor`, except Brannoc.

- **Silent Forge pieces:** `CFrame = T_SF * YeCFrame`, with
  ```lua
  local T_SF = CFrame.new(373, 4.7, -368) * CFrame.Angles(0, math.pi, 0) * CFrame.new(-521.5, -24.4, -900)
  ```
  - This maps Ye's floor centre (521.5, 24.4, 900) to (373, 4.7, −368) and turns the room 180° about Y, so Ye's back wall (+Z, where its machine and furnace were) faces Foundry's back wall (−Z, the hearth).
  - **Checked on paper:** the pieces span x 354.8..389.4 and z −382..−355.8. That is inside the interior (x 353.6..392.4, z −389.4..−339.6), clear of the hearth (x 368..378, z −388.9..−383.9) and of the doorway (x 369..377 at z −338.8). The Desk lands at x 359..363, the MaterialBench at x 381..387, and the SampleRack against the west wall at x 355.4.
  - **Parts** are created with `Instance.new(Class)` and the exported properties.
  - **MeshParts:**
    - Clone a MeshPart with the same `MeshId` found under `ReplicatedStorage.Assets` (search its descendants), then set the exported properties.
    - Otherwise use `AssetService:CreateMeshPartAsync(MeshId)`.
    - If both fail, refuse, changing nothing.
  - **Models** are recreated by Path.
  - **Tags and attributes** are set as exported.
- **The area box:** `Silent ForgeArea` with the same AreaName and Description, but `CFrame = CFrame.new(373, 13.7, -364.5)` and `Size = (38.8, 20, 49.8)`. That is the room's interior, from 1 below the floor to 19 above it, so it sits inside "The Foundry" and the smallest box wins.
- **`TrialMarker`:** the exported properties, with `CFrame = CFrame.lookAt(Vector3.new(325, 5.2, -364.5), Vector3.new(325, 5.2, -365.5))`. That is the Forge Floor's centre, with its bottom on the floor at 4.7, facing −Z. The foe then spawns at z −378.5 (FoeDistance 14, Task 3).
- **The Ward spawn** (owner decision B: inside the Silent Forge room, as it was the forge's spawn in Ye). It goes in `ForgeRooms.SilentForge`, with the exported size (2 × 1 × 2), properties, `EnemyType` WardAlchemist and `Weapon` "".
  - **The spot:** `CFrame.new(386, 5.2, -348)`, measured 2026-10-24.
    - A ray down from y 15 meets `SilentForgeFloor` at y 4.7, so the centre sits 0.5 above the floor, as it did in Ye.
    - A 4 × 5 × 4 box over it held nothing.
    - It is 9 studs east of the doorway (x 369..377 at z −338.8), 7.5 studs south of the moved MaterialBench, and 35 studs from the hearth.
  - **Re-measure at apply:**
    - the ray must meet `SilentForgeFloor` with a top between 4.6 and 4.8;
    - after the other pieces are placed, a 4 × 5 × 4 box over the spot must hold no CanCollide part.
  - **If either fails,** try (360, 5.2, −346), the west front corner, then (386, 5.2, −372), the east side beside the Anvil's row. Both read clear on 2026-10-24. If all three fail, refuse and report.
- **Brannoc:** `workspace.World.NPCs["Alchemy Trainers"]["Metal Alchemist"]`. Create the folder if missing, marked `FoundryForgeAdd`.
  - Clone `game.StarterPlayer.StarterCharacter`. Remove every LuaSourceContainer and PackageLink from the clone, and name it "Metal Alchemist".
  - Set the exported attributes and Humanoid fields.
  - Anchor the root and pivot so the root is at `CFrame.lookAt(Vector3.new(-200, 7.4, 490), Vector3.new(-200, 7.4, 489))`: the floor at 4.4 + 3, facing −Z (the TrainerSpot's Yaw 0).
  - **Props:** `ScrollStand` and `Metal Alchemy` (a Model with its MeshPart), at their Ye CFrames translated by (−70, +0.4, +625), as children of the rig, as in Ye.
- **`check`** (read-only) fails on any of:
  - a Silent Forge piece whose bounding box isn't inside the interior (inset 0.1), or that touches the hearth or a shell wall (`GetPartsInPart` against the shell parts named `SilentForge*` / `ForgeFloor*`, excluding the floor);
  - the counts in `Map.Foundry.ForgeRooms` not being RenseiInspect 4 (`metal_note`, `metal_gear`, `metal_samples`, `metal_shaft`), RenseiMechanism 1 (`metal_bench`), RenseiTrial 1 (`metal_experiment`), RenseiArea 1 ("Silent Forge") and RenseiEnemySpawn 1 (WardAlchemist);
  - workspace's RenseiArea count not being 13;
  - Brannoc's root not within 0.5 of (−200, 7.4, 490), not facing −Z (look vector Z < −0.99), or out of 6 studs of the TrainerSpot marker;
  - the trial marker not at the Forge Floor's centre;
  - the Ward spawn not inside the Silent Forge interior (x 353.6..392.4, z −389.4..−339.6), its ground ray not meeting `SilentForgeFloor` within 0.6, or it lying within 6 studs of the doorway's centre (373, −338.8) or within 4 studs of the hearth's box.
- **`undo`:** destroys every top-level `FoundryForgeAdd` instance (ForgeRooms, the Alchemy Trainers folder if this script made it, otherwise Brannoc alone) and clears the flag. No guard: nothing later builds on it. (Task 8's Ye retire is in another place.)
- **`test`:** snapshot → apply → check → undo → snapshot equal. The snapshot covers:
  - `Map.Foundry.Landmarks.GreatHall_great_hall` and `Map.Foundry.Markers` rows (path, CFrame to 0.01, sorted attributes, tags);
  - `World.NPCs` rows;
  - per-tag counts in workspace;
  - the BasePart count.

**`Play_FoundryForge`** (Play, in Foundry):
- **`InspectPointsAttach`:** each of the 4 `metal_*` parts has its `InspectPrompt`, and `metal_bench` has its mechanism prompt (`PuzzleService`).
- **`TheForgeIsAnArea`:** `WorldService.AreaAt` returns a part whose `AreaName` is:
  - "Silent Forge" at (373, 8, −364.5);
  - "The Foundry" at (400, 8, −300);
  - "Practice Court" at (−200, 8, 490).
- **`BrannocTalks`:**
  - the model has DialogueId `trainer_metal` and a `TalkPrompt` on its root;
  - it is within 6 studs of the TrainerSpot;
  - `DialogueService.Open(Player, Model)` opens with the player beside him; `DialogueService.Close`.
- **`WardSpawnsInTheForge`:**
  - the WardAlchemist RenseiEnemySpawn is in `ForgeRooms.SilentForge` and inside the room's interior;
  - within 30 s of Start, `EnemyService.Active` has a live WardAlchemist whose Home is that spawn;
  - its root stands inside the Silent Forge interior.
- **`TrialFitsTheRoom`:**
  - Save Quests and Identity. Set `Identity.Affinity = ""` and `Data.Quests.Active.acq_metal = {Stage = 5, Progress = {}, Started = os.time(), Revision = 2}`.
  - Stand the player 3 studs from the marker. `TrialService.Begin(Player, "metal_experiment")` returns true.
  - The foe's root is inside the Forge Floor interior (x 305.6..344.4, z −389.4..−339.6).
  - Pivot the player to (325, 8, −300), outside Radius × 1.35. Within `OUTSIDE_GRACE` + 2 = 8 s the run ends (`TrialService.InRun(Player)` false).
  - Put everything back.
- **`TrialIsLockedOtherwise`:** with no `acq_metal`, `TrialService.CanStart(Player, "metal_experiment")` is false.

**Steps:**
- [ ] **Step 1: RED.** Write `Play_FoundryForge` and add `RenseiTests.Play_FoundryForge` (`Create: true`) to the manifest. Sync it to Foundry and run it in Play (PlayLock `Foundry:task7`). Expected: every test FAILs (nothing built).
- [ ] **Step 2: Export.** Write `export_forge.lua`, run it in **Ye** (Edit), read the JSON back in chunks, save `forge_kit.json`, and remove `ServerStorage.FoundryForgeExport`. Check that the kit has 20 SilentForge pieces, 3 Models, the TrialMarker, Brannoc and the Ward.
- [ ] **Step 3: Bundle.** Write the bundler, the template and `test_bundle_forge.py`; run the tests (pass). Run `build_forge.lua` with `MODE = "check"` before apply: it must FAIL (nothing built), which shows check can fail.
- [ ] **Step 4: Test.** In Foundry (Edit), `MODE = "test"`. Expected: 0 FAIL, round trip exact.
- [ ] **Step 5: Apply, then check.** Expected: 0 FAIL. Record:
  - the MeshPart source used for each mesh (an Assets clone or CreateMeshPartAsync);
  - the Ward's final spot, and which of the three it is;
  - Foundry's BasePart count after (expected about 46,941 + 12 (Task 4) + about 33).
- [ ] **Step 6: GREEN.** In Play in Foundry:
  - Play_FoundryForge 0 FAIL;
  - Play_Exams: MetalExamOpens now passes in Foundry, and the four others pass as "moved away" here;
  - Play_FoundryLedger and Test_FoundryRoster (regressions).
- [ ] **Step 7: Commit** the six `forge/` files, the suite and the manifest: `"Foundry data Task 7: the Silent Forge, the Forge Floor and Brannoc in Foundry (reversible)"`.

---

### Task 8: Ye gives up Brannoc and the forge rooms

**Files:**
- Create: `Art/Studio/Regions/Foundry/forge/retire_ye.lua` (hand-written; Ye only).
- Modify:
  - `Art/Studio/Regions/Lindenmoor/prep_ye.lua`: an undo guard;
  - `Art/Studio/Regions/Lindenmoor/test_ye_fixes.py`: a check that the guard is in place;
  - `Scripts/ServerStorage/RenseiTests/Play_LindenmoorSmoke.lua`;
  - `sync_manifest.json`.

**Interfaces** (Ye, Edit; flag `World.Map` `FoundryMove = "applied"`; marks `FoundryMoveAdd` and `FoundryMoveFrom`):

**`apply`:**
- **Refuses when:**
  - `World.Map` has `FoundryMove`;
  - any of the four pieces below is missing;
  - Play is running.
- **Moves (not clones), so undo returns the same instances,** into `ServerStorage.RenseiBackups["Pre-FoundryMove_2026-10-24"]` (created if missing, and marked `FoundryMoveAdd` if this script created it):
  - `World.Map.SilentForge`;
  - `World.Map.ForgeFloor`;
  - `World.NPCs["Alchemy Trainers"]["Metal Alchemist"]`;
  - `World.Map.AlchemistSpawns.WardAlchemist_SilentForge`.
- For each piece:
  - a child ObjectValue `FoundryMoveFrom` holds its old parent, and the attribute `FoundryMoveFromPath` holds the old full name as a fallback label;
  - every tag on it and its descendants is removed and written into `RegionKitTags` (JSON).
- **`World.Map.FoundryYard` stays** (owner decision A).
- **Builds the notice** `World.Map.BrannocNotice` (Model, `FoundryMoveAdd`), PROPOSAL dressing:
  - **`NoticePost`:** Wood, 0.6 × 5 × 0.6, its centre at (−130, 6.5, −137.5), so it stands on Ye's ground at 4. It is 2.5 studs south of the Metal TrainerSpot, which faces −Z.
  - **`NoticeBoard`:** WoodPlanks, 2.4 × 1.6 × 0.2, centre (−130, 8.2, −137.6), facing +Z toward the training field. It is tagged RenseiInspect with `InspectId = "brannoc_moved"`.
  - Both are Anchored and CanCollide.

**`undo`:**
- destroys `BrannocNotice`;
- moves each piece back to its `FoundryMoveFrom` parent and restores its tags from `RegionKitTags`;
- deletes the backup folder if this script made it;
- clears the flag.

**`check`** fails on any of:
- the four pieces not in the backup, or any tag left on them or their descendants;
- no `trainer_metal` model and no RenseiTrial `metal_experiment` in Ye's workspace;
- the notice not tagged, or not within 6 studs of the Metal TrainerSpot;
- 4 trainers in `Alchemy Trainers`;
- workspace's RenseiInspect count = before + 1 − 4.

**`test`:** snapshot (all of `World` and the backup folder: rows with sorted attributes and tags; tag counts; BasePart count) → apply → check → undo → snapshot equal.

**The `prep_ye.lua` guard:** its `undo` refuses, changing nothing, while `World.Map:GetAttribute("FoundryMove")` is set: "undo the Foundry move first (`Art/Studio/Regions/Foundry/forge/retire_ye.lua` undo)". If `bundle_prep.py` builds `prep_ye.lua` from a template, put the guard in the template.

**`test_ye_fixes.py`:** a check that `prep_ye.lua` (and its template, if any) contains the `FoundryMove` guard in its undo path.

**`Play_LindenmoorSmoke` changes:**
- `TRIALS` = `{"flame_apprentice", "ice_guardian", "earth_quarry", "wind_dancer"}`.
- `EveryTrialStarts` also asserts that no instance in the DataModel has the tag RenseiTrial with TrialId `metal_experiment`.
- **`TrainersCanBeTalkedTo`:**
  - 5 TrainerSpots, each with its own Element;
  - for Flame, Ice, Earth and Wind, the trainer checks as today;
  - for **Metal**: no model with TrainerPath "Metal" in workspace, and a part with `InspectId == "brannoc_moved"` within 6 studs of the Metal spot, with its `InspectPrompt`.
- **New `BrannocNoticeStartsTheQuest`:**
  - Save Quests and Identity. Clear `acq_*` from Active and Completed, and set `Affinity = ""`.
  - Stand within 9 studs of the board. `InvestigationService.Inspect(Player, "brannoc_moved", Board)` starts `acq_metal` at Stage 1, with `Progress.foundry == 0`: Here() is Lindenmoor, so the travel stage stays open.
  - Put everything back.
- Update the header comment to match.

**Steps:**
- [ ] **Step 1: Owner decision A is answered: keep `FoundryYard` in Ye.** `retire_ye.lua` must not touch it, and its `check` fails if `World.Map.FoundryYard` is missing or changed: compare its BasePart count, 60, and its pivot before and after.
- [ ] **Step 2: RED.**
  - Write the smoke changes, sync `RenseiTests.Play_LindenmoorSmoke` to Ye, and run it in Play in Ye (PlayLock `Ye:task8`). Expected: TrainersCanBeTalkedTo, EveryTrialStarts and BrannocNoticeStartsTheQuest FAIL, because Brannoc and the forge are still in Ye.
  - Run `retire_ye.lua` with `MODE = "check"` before apply: FAIL.
  - Run `test_ye_fixes.py`: the new guard check FAILs.
- [ ] **Step 3: Implement** `retire_ye.lua` and the `prep_ye.lua` guard.
  - `test_ye_fixes.py` passes (27 checks).
  - Run `retire_ye.lua` with `MODE = "test"` in Ye (Edit): 0 FAIL, round trip exact.
- [ ] **Step 4: Apply, then check.** Record Ye's BasePart count after (expected about 76,373 − 29 − 10 − 10 − 1 + 2 ≈ 76,325).
- [ ] **Step 5: Prove the guard.** In Ye (Edit), run a fresh `prep_ye` bundle with MODE undo (`python -I Art/Studio/Regions/Lindenmoor/bundle_prep.py prep <scratch>/prep_undo.lua undo`). Expected: it refuses, naming FoundryMove, and Ye is unchanged (compare the BasePart count and `World.Map` attributes).
- [ ] **Step 6: GREEN in Play in Ye:**
  - Play_LindenmoorSmoke 9/0;
  - Play_Exams 5/0: four exams open, and Metal is "moved away";
  - Play_LindenmoorData and Play_Clue.
- [ ] **Step 7: Commit** `retire_ye.lua`, `prep_ye.lua` (and its template, if one was changed), `test_ye_fixes.py`, `Play_LindenmoorSmoke.lua` and the manifest: `"Foundry data Task 8: Brannoc and the forge rooms leave Ye (reversible); a notice points students to the Foundry"`.

---

### Task 9: The Foundry smoke suite, the `acq_metal` end-to-end, and the sweep

**Files:**
- Create: `Scripts/ServerStorage/RenseiTests/Play_FoundrySmoke.lua` and `Play_FoundryData.lua`.
- Modify: `sync_manifest.json` (both suites, `Create: true`, Places `["foundry"]`).

**Interfaces.** Each check below names its RED control. Run every control once, in Play, where world changes vanish at Stop.

**`Play_FoundrySmoke`:**

1. **`EveryPostIsReachable`:**
   - every RenseiPost in `Map.Foundry` (88) has a path from the hub, as Task 4's reach test: `errand_square` + (0, 2, 0); radii 2.5, 2, 1.5 and 1; the end within 2.5 of the post + 2.
   - **Control:** pivot one post 2 studs into the great hall's `Back` wall (400, 19, −394); it must be reported.
2. **`EveryPostHasAShelter`:**
   - the nearest Shelter to every post is ≤ 145 studs.
   - **Control:** the same function given a synthetic post at (0, 5, 760) reports it.
3. **`EdgesCantBeGrabbed`:**
   - **The spots:** one per edge, chosen without reading the tag. From (0, ground + 3, −400) toward −X and +X, and from (−400, ground + 3, 0) toward −Z, and from (300, ground + 3, 0) toward +Z (clear of the portals), find the first part under `Map.Foundry.Edges.Edge_<W|E|N|S>`. Stand 2 studs short of it, facing it.
   - **The check:** `MovementState.Grippable` is false for that part, and the server refuses a climb and a wall run (`Refused:NoWall`). Do this as `Play_LindenmoorSmoke.CragCantBeGrabbed` does: reuse its Ask and WithRoot helpers by copying them; they are this project's own code.
   - **Control:** with the RenseiNoGrip tags removed within 12 studs of one spot, the climb is accepted. Put the tags back, and the tagged count equals the before count.
4. **`LedgesFaceTheirWalls`:**
   - for every RenseiLedge in `Map.Foundry` (377), a ray from its centre along its LookVector meets a part within 1.5 studs, and that part's hit normal dotted with the LookVector is < −0.7.
   - **Control:** turn one ledge 180°; it must fail.
5. **`LampsFollowTheClock`:**
   - the 154 `NightOnly` parts in `Map.Foundry` are all in `WorldClock.NightParts`;
   - with `WorldClock.Hold(23)`, each has an enabled Light and is not `WorldClock.DayMaterial`; with `Hold(12)`, each Light is disabled and the material is `DayMaterial`;
   - `WorldClock.Release()` after.
   - **Control:** clear `NightOnly` on one lamp; the count check must fail.
6. **`PondSwims`:**
   - terrain Water at (490, 0, −148), (440, −2, −120) and (540, −4, −180), and Air at (490, 6, −148);
   - pivot the player to (490, 1, −148): within 3 s `SwimService.InDeepWater(Character)` is true, and the server's swim state is on (read it as SwimService sets it, through `MovementState`);
   - pivot back to (−648, 9, 360): within `TuningConfig.Swim` ExitChecks × CheckEvery + 1 s the state is off.
   - **Control:** at (490, 9, −60), on dry ground, `InDeepWater` is false.
7. **`TravelIsSingle`:**
   - exactly one `RenseiArrival` with Point RoadStart (under `Map.Foundry.Travel.SouthRoad`) and one with Point Platform (under `Travel.Station`) in workspace;
   - one `RenseiPlatformTrain` with Route `LindenmoorFoundry`;
   - `TravelService.ArrivalPoint` returns those.
   - **Control:** duplicate the Platform arrival; it must fail.
8. **`TrialsAreInTheWorld`:**
   - workspace has exactly one RenseiTrial (`metal_experiment`), with its `TrialPrompt`;
   - no RenseiTrial outside workspace.
9. **`BrannocCanBeTalkedTo`:** as Task 7's BrannocTalks.
10. **`EnemiesStandInTheWorld`:**
    - this is `Play_LindenmoorSmoke.EnemiesStandInTheWorld`, copied;
    - plus: the RenseiEnemySpawns in workspace are exactly the 4 Grunts and 1 WardAlchemist (decision B);
    - `WorldService.AreaAt` at each Grunt spawn is "The Underworks", and at the Ward spawn it is "Silent Forge";
    - the Ward spawn lies inside the Silent Forge interior (x 353.6..392.4, z −389.4..−339.6);
    - no RenseiEnemySpawn lies in any other area: none in the town above;
    - each has a live enemy within 30 s of Start: poll `EnemyService.Active`.
11. **`CompassMarksPointTrue`:**
    - `Regions.NorthOf() == "-Z"`;
    - `ReplicatedStorage.CompassPoints` has:
      - a Spawn point within 0.5 of each spawn;
      - a Talk point `trainer_metal` within 3 of Brannoc;
      - a Trial point `metal_experiment`;
      - Inspect points for the two clues and the four `metal_*` parts;
      - an Area point for each of the 11 area names and "Silent Forge";
    - from the court (−200, 490), `Regions.Bearing(dx, dz, "-Z")` to every Grunt spawn has |bearing| > 90 (south), and to the hall (400, −340) and to the Ward spawn (386, −348) it lies in (0, 90) (north-east).
    - **Control:** the same bearing with "+Z" puts the hall in the south half; it must fail the north-east assertion.
12. **`TownsfolkAtTheirPosts`:**
    - with `WorldClock.Hold(10)`, all 26 are spawned, Validate passed, and each stands within 1.5 studs of its 10:00 post within 1.5 s;
    - release the clock after.
13. **`CommuteWalks`:**
    - pivot the player to (−300, 7, −440). Hold 10, wait until `fy_runner_1` is AtPost at `errand_square`, then Hold 11.
    - Within 90 s (PROPOSAL; the 380-stud walk at WalkSpeed 8 takes about 48 s) its state passes Walking and ends AtPost at `errand_row`, within 1.5 studs of the post.
    - Release the clock and put the player back.
14. **`TownsfolkLoopIsCheap`** (spec §9):
    - wrap `TownsfolkService.Step` with an `os.clock` timer for 60 s, with the player standing in Foundry Square (−90, 7, −509) and the clock running; put the wrapper back after.
    - The average Step is < 1 ms.
    - Report `TownsfolkService.Mover.Stats().StepMs`, `P99StepMs()` and the Walkers count. Get the Mover through `require(game.ServerScriptService.TownsfolkService.Mover)`.

**`Play_FoundryData.AcqMetalFromFoundry`** (Play, in Foundry):
- **Setup:** save Quests, Story, Identity and Areas. Clear `acq_*` from Active and Completed. Set `Affinity = ""` and `Data.Areas["Silent Forge"] = nil`. Set `QuestService.Definitions.acq_metal.Rewards = {}` for the run, and put all of it back in a finally block.
- **The run:**
  1. Beside Brannoc, open the dialogue and take "Teach me." then "I'll go." (`DialogueService.Choose`). acq_metal is Active, and the travel stage is already done (Here() = Foundry): Stage 2.
  2. Pivot the player into the Silent Forge at (373, 8, −360) and wait up to 6 s for WorldService's discovery. Stage 3.
  3. Inspect the four `metal_*` points (within 9 studs each), then `InvestigationService.Deduce(Player, "forge_failure", {"sheared_shaft", "sample_rack", "bad_weld"})`. Stage 4.
  4. Pivot to the material bench. `MinigameService.Open(Player, "metal_match", ...)`, through the bench's mechanism prompt as PuzzleService does, opens (the Requires are met). Cancel it, then `QuestService.Signal(Player, "Minigame", "metal_match")`. Stage 5.
  5. `TrialService.Begin(Player, "metal_experiment")` from 3 studs off the marker returns true. End the run by leaving the arena (as Task 7). `StoryService.SetFlag(Player, "Trial_metal_experiment", os.time())`. Stage 6.
  6. Beside Brannoc, the dialogue's exam choice opens `metal_exam` (as Play_Exams does). Cancel it, then `QuestService.Signal(Player, "Minigame", "metal_exam")`. Stage 7 ("recognition"): **the exam is passed**. Stop here; recognition isn't run.
- **`AcqMetalFromYeSave`:** a save from Ye mid-way through the quest (`{Stage = 3, Progress = {}}`, with no Revision) goes to Stage 4 through `QuestService.UpgradeAll`. Brannoc's dialogue then opens his "experiment" node, the Starts entry for Stage 4.

**Steps:**
- [ ] **Step 1: RED.** Write both suites; sync them to Foundry. Run each RED control in Play (PlayLock `Foundry:task9`) and record that each check failed as designed. Then run the suites clean.
- [ ] **Step 2: GREEN.** In one Foundry Play session, in this order:
  - Play_Boot, Play_Station, Play_Road, Play_Gate, Play_Arrive, Play_Travel, Play_RideEvents;
  - Play_FoundrySmoke, Play_FoundryData, Play_FoundryLedger, Play_FoundryForge;
  - Test_FoundryRoster, Test_AcqMetal, Test_Regions, Test_QuestRevision, Play_QuestEngine;
  - Play_Exams, Play_Clue, Play_Townsfolk, Play_TownsfolkCrowd, Play_TownsfolkHurt, Play_Clock, Play_NoGrip.

  Expected: 0 FAIL, apart from the known Travel 5/2 and RideEvents 8/1. Record every count, and the step-time numbers.
- [ ] **Step 3: Ye's suites, in one Ye Play session:**
  - Play_Boot, Play_Station, Play_Road, Play_Gate, Play_Arrive, Play_Travel, Play_RideEvents;
  - Play_LindenmoorSmoke, Play_LindenmoorData, Play_Exams, Play_Clue, Test_Regions, Test_AcqMetal, Play_QuestEngine, Play_Townsfolk, Play_TownsfolkCrowd, Play_TownsfolkHurt.
- [ ] **Step 4: The Studio == repo sweep.** `sync.py --check` in both places over the whole manifest. Expected: `DIFFER 0 / MISSING 0`. Also hash every other `Scripts/` file the earlier Lindenmoor sweep covered (`Scripts/` except MainMenu and Tutorial, plus `Art/Studio/Travel/src`) against Ye. Report any drift, and change nothing outside this plan's files.
- [ ] **Step 5: Record the counts:**
  - BaseParts in each place's workspace;
  - `Map.Foundry`'s part count (it must stay ≤ 45,000);
  - per-tag counts in Foundry's workspace.
- [ ] **Step 6: Commit** the two suites and the manifest: `"Foundry data Task 9: Foundry smoke suite and acq_metal end to end; both places pass"`.

---

### Task 10: Docs and the joint publish checkpoint

**Files:**
- Modify:
  - `Documents/Foundry Yard Kit.md`;
  - `Documents/Lindenmoor Kit.md`;
  - `Documents/Changelog.md`;
  - `Documents/Backlog.md`;
  - `Documents/World Travel.md` (the §9 bullet "Foundry Yard is a placeholder").

**Interfaces:** the content each document must hold. Facts and counts come from Tasks 1–9's reports.

**`Foundry Yard Kit.md`, a new section "The game data (2026-10-24, Foundry Yard plan)":**
- **What's live in Studio:** the areas, the 26 townsfolk and their day, the shift-ledger quest, the forge rooms and Brannoc, the Ward Alchemist spawn inside the Silent Forge room (owner decision B), and the four Grunts, the only enemies in the underworks.
- **"Not done in this import":** tick each item.
- **A subsection "Foundry differs from the kit"**, as Lindenmoor Kit's. A re-import or Blender rebuild drops all of these, and the import's own checks don't warn:
  - the `Spawn` SpawnLocation at (−648, 6.9, 360): re-add it by hand;
  - `foundry_posts.lua`;
  - `build_forge.lua`.

  The re-apply order is Spawn, posts, forge.
- **The rollback order** (Edit, never Play):
  1. `build_forge.lua` undo;
  2. `foundry_posts.lua` undo;
  3. revert the scripts from `RenseiBackups["Pre-FoundryData_2026-10-24"]`, in both places, for this plan's labels;
  4. `import/restore.lua`, which refuses while `FoundryPosts` or `FoundryForge` is set.
- **The smoke table:** each check and what it proves.
- **Known issues:**
  - the errand runners are adult rigs;
  - the traders' shelves are walk-through;
  - an `Arrive` objective has no compass mark;
  - Ye's "Foundry Yard" area (Brask's yard) shares the town's name.

**`Lindenmoor Kit.md`:**
- **"Rolling everything back" gains step 0:** `Art/Studio/Regions/Foundry/forge/retire_ye.lua` undo. `prep_ye.lua` undo refuses until it has run.
- **The trainer counts:** four trainers in Ye; Brannoc's notice at the Metal spot.
- **The part count:** Ye after Task 8.
- **"Publish checkpoint"** becomes **"Joint publish checkpoint (Ye and Foundry Yard)"**, in the World Travel.md §10 order:
  - **First:**
    1. the owner saves Ye and Foundry Yard in Studio, without publishing;
    2. walks each once in Play. In Foundry: the station, Cinder Lane, the practice court and Brannoc, the great hall's forge wing, the underworks, the square at a shift change, and the pond.
  - **Then:**
    1. publish the packages from Ye: Modules, RenseiServer and ClientHandler;
    2. update Modules, RenseiServer and ClientHandler in Foundry Yard by hand, and check them with `sync.py --place foundry --check` (and `--place ye`);
    3. publish the places: Ye, then Foundry Yard (Menu and Tutorial unchanged);
    4. Migrate to Latest Update for Ye and Foundry Yard, last.
  - **The package contents:** the Lindenmoor lists, plus:
    - **Modules:** StoryLogic, Regions, Quests, Dialogues, Investigation, Evidence, Deeds, Trials, Minigames and Townsfolk;
    - **RenseiServer:** QuestService, TownsfolkService and ServerHandler.
  - **Ye's place:** the retired pieces in `Pre-FoundryMove_2026-10-24`, the notice, the RenseiTests changes, and `RenseiBackups`.
  - **Foundry's place:**
    - the new map with Task 4's and Task 7's fixes;
    - Brannoc;
    - `StarterPlayerScripts.TownsfolkClient` and `StarterCharacterScripts.Health`. Health is the owner's no-regen-in-combat rule, which Foundry lacked until now;
    - the RenseiTests suites;
    - `RenseiBackups`.
  - **The known ticket failures** in Play_Travel and Play_RideEvents, and the hook's `diff` quirk.

**`Changelog.md`:** one entry, `## 2026-10-24 — Foundry Yard comes alive: game data, Brannoc's move, the shift ledger (not live)`. It holds:
- the owner's decisions, A–E as answered;
- what changed in each place;
- the test counts from Tasks 1–9.

Its `### Discord announcement` starts "Hold: not live yet. Post this when the owner publishes Ye, Foundry Yard and the packages together." Then a ```md block, under 2,000 characters, plain and player-facing, with no file names, test numbers or PROPOSAL tags. It covers:
- Foundry Yard is a real town now: the station, Cinder Lane, the rail yards, Workers' Row, the square with its market and canteen, and the great hall;
- about two dozen people working two shifts, who eat at the canteen when shifts change, trade in the market from morning till evening, and hide when trouble starts;
- a mystery in the shift ledger;
- Brannoc and his forge have moved from Lindenmoor to the Foundry's practice court and great hall, and a notice in Lindenmoor points the way;
- bandits in the tunnels under the town, and an alchemist guarding the silent forge in the great hall;
- a cooling pond deep enough to swim and dive in;
- health only comes back out of combat in the Foundry too.

**The Lindenmoor entry's held post** (in place): "The five alchemy trial sites have new homes out in the valley" becomes "Four of the alchemy trial sites have new homes out in the valley. Brannoc and the forge have moved to Foundry Yard". "The alchemy trainers have a new training field" stays.

**`Backlog.md`:**
- item 2 (the Foundry Yard plan) is ticked, with a pointer to the joint checkpoint;
- add these follow-ups: move `chalk_foundry` (Brask's yard) into the Foundry (owner decision A kept it in Ye for now); compass marks for `Arrive` objectives; child rigs for the errand runners.

**`World Travel.md` §9:** the "Foundry Yard is a placeholder" bullet now says Foundry Yard is a full town on its region map (Foundry Yard Kit.md).

**Steps:**
- [ ] **Step 1:** Write the docs. Every number comes from a task report. Re-read every direction word against the place's compass.
- [ ] **Step 2:** Check that the Discord block is under 2,000 characters (count it with `python -I -c`), and that it has no file names, numbers of tests, or PROPOSAL.
- [ ] **Step 3: The controller names the joint checkpoint to the owner in chat,** with the hold, the order, and the two known ticket failures. This plan publishes nothing.
- [ ] **Step 4: Commit** the five docs: `"Foundry data Task 10: docs, changelog (held Discord post) and the joint Ye + Foundry publish checkpoint"`.

---

## Self-review notes

**Coverage of the request:**
1. **Brannoc and the forge out of Ye:**
   - Tasks 7 (Foundry) and 8 (Ye): reversible, with a backup and tags set aside, and the same evidence, minigame, mechanism and trial ids;
   - the fit is measured (Studio facts; Task 7's transform and check);
   - **the knock-ons in Ye:**
     - Play_LindenmoorSmoke goes to four trainers and Brannoc is checked in Foundry (Tasks 8 and 9);
     - the acq_metal and Brannoc text (Task 3);
     - the Metal TrainerSpot holds the notice (Tasks 3 and 8);
     - Ye's part budget goes down about 48 (Task 8);
     - `FoundryYard` is owner decision A.
2. **`acq_metal`'s Arrive stage and Silent Forge → Foundry:** Task 3, with the save upgrade in Task 2.
3. **The 11 areas, law and faction:** Task 3. Region Foundry already has State law and the Foundry and Townsfolk factions; Default = Foundry.
4. **The roster:**
   - Task 5: 26 people, with the shifts at 06, 14 and 22, the canteen at shift change, and the market 08–20;
   - every hour covered and no shared post (Validate plus a direct check);
   - the shelters, the platform and gantry posts, and the goods-platform and trader reach fixes: Task 4;
   - original names, checked by the test.
5. **The clues and the shift-ledger quest:** Task 6, with EXP, money and a Foundry standing deed (Task 2's `Rewards.Deeds`).
6. **The enemies:** the 4 Grunts stay live; ground and compass are checked in Task 9; the Ward spawn sits inside the Silent Forge room (decision B), checked in Tasks 7 and 9.
7. **The smoke and Play-testing:** Task 9 covers walkability, NoGrip, ledges, lamps, the pond, travel single, trials, Brannoc, enemies, the compass, the shift ledger end to end (Task 6's suite re-run), `acq_metal` through the exam, and performance. The travel suites run in both places.
8. **The docs and the joint checkpoint:** Task 10. The SpawnLocation note is in "Foundry differs from the kit".

**The Lindenmoor lessons folded in:**

| Lesson | Where |
|---|---|
| North per place | Global Constraints; Tasks 3 and 9 |
| Workspace filter / tags set aside in backups (C1) | Global Constraints; Tasks 8 and 9 |
| Shelters within the 150 cap (Ruling 37) | Task 4, with a 145 design margin |
| Validate | Task 5 |
| The time-to-meet Mover (Ruling 36) | Task 1's sync, the Crowd suite kept green |
| RED then GREEN, no pass-by-construction (Ruling 41) | Every task, with controls in Task 9 |
| Studio == repo by normalised hash | Task 1's tool, checked in every task |
| Reversible scripts with guards (I2) | Tasks 4, 7 and 8, the `restore.lua` flags, the `prep_ye.lua` guard |
| Generated-file rules | Global Constraints; Task 7 |
| The publish order (Ruling 42) | Task 10 |
| Edit's require cache | Global Constraints |
| The part budget (Ruling 25) | Tasks 7–9 |

**Found while planning, not in the request:**
- Foundry's package copies were 16 scripts behind Ye's (Task 1).
- Foundry lacks TownsfolkClient (without it no bubbles show) and the owner's Health script (Task 1).
- Ye's `FoundryYard` is a whole quest, not a graybox (decision A).
- The 72-wide arena doesn't fit the shell (decision E).
- Inserting a stage shifts saved stages (decision C).

**Names used across tasks:**
- the backups `Pre-FoundryData_2026-10-24` (scripts, both places) and `Pre-FoundryMove_2026-10-24` (Ye's pieces);
- the flags `FoundryPosts` and `FoundryForge` (on `Map.Foundry`) and `FoundryMove` (on Ye's `World.Map`);
- the marks `FoundryPostAdd`, `FoundryPostFrom`, `FoundryShelfFrom`, `FoundryForgeAdd`, `FoundryMoveAdd`, `FoundryMoveFrom` and `FoundryMoveFromPath`;
- the quest `foundry_ledger`, the deduction `foundry_ledger_who`, the deed `foundry_ledger_cleared` and the signals `foundry_ledger_rusk`, `_marsh` and `_clerk`;
- the roster ids `fy_*`;
- `MetalStage(Id)`, `StoryLogic.UpgradeQuest`, `QuestService.UpgradeAll` and `QuestService.Boot`.

**Order and dependencies:**
- 1 comes before everything.
- 2 before 3 (Revision), 6 (Deeds, Clue.Evidence) and 9.
- 3 before 7 (trial numbers) and 8 (the notice def).
- 4 before 5 (posts).
- 5 before 6 (tellers).
- 7 before 8: Brannoc exists in Foundry before he leaves Ye, so the game always has a Metal trainer.
- 9 after all; 10 last.
- Play sessions are serial across the places. Tasks 4, 7 and 8's Studio scripts run in Edit and need no Play.

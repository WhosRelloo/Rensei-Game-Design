# Region Foundation (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** everything a region build needs before Foundry Yard starts:
- a shared Blender region builder that turns a region layout file into a tagged, exported, importable map;
- a world clock, a 24-minute day;
- townsfolk with schedules, reactions and talk;
- clue quests;
- working trainer exams.

**Architecture:**
- **Blender side:** `Art/Blender/region_builder/`, a Python package generalized from `Art/Blender/lindenmoor/`.
  - Pure modules (schema, heightfield, merge) have no `bpy` import and are tested with plain Python.
  - The `bpy` stages build the scene and render it.
- **Export:** reuses `export.py` and `studio_kit.py`, extended to carry CollectionService tags and a per-region material table.
- **Studio side:** a generic staged import plus a `setup.lua` that builds the World Plan 1 travel pieces from markers.
- **Game code:** new services `WorldClock` and `TownsfolkService` in the `RenseiServer` package; a pure `Rensei.TownsfolkLogic` and data `Rensei.Townsfolk` in the `Modules` package; small extensions to `RumourService`, `NoiseService`, `InvestigationService`, `DialogueService` and `AdminService`.

**Tech stack:**
- Roblox Studio (Luau) through `Art/Tools/rbxc.py`;
- Blender through `Art/Tools/blender_mcpc.py` (bpy);
- Python 3 for the pure builder modules and their tests.

**Spec:** `Documents/specs/2026-10-23-region-builds-design.md`. This plan is the spec's "Foundation" (§2, items F1–F4; §3–§6). Foundry Yard (§7) gets its own plan once this one is complete, so that it can use the builder's real names. The world spec `Documents/specs/2026-10-20-world-travel-seasons-design.md` stays binding where this spec doesn't change it.

## Global Constraints

- **Hard rules (owner):**
  - Do not publish the Roblox game or modify live player data.
  - Do not expose API keys, credentials, private player data, or other secrets.
  - Do not blindly copy another game's code or assets.
- **PROPOSAL labels:** every number invented here is a PROPOSAL; label it so in code comments.
- **Mechanics:** never remove an established mechanic without the owner's approval.
- **Owner UI rule:** every UI is built only from existing UI assets and is animated (UIMotion). Townsfolk talk reuses the existing dialogue box (`DialogueService.Ask` / `Say`); no new panels.
- **Places (exact ids):**

  | Region id | Place | Place id |
  |---|---|---|
  | Lindenmoor | Ye | 106992859583940 |
  | Foundry | Foundry Yard | 109591196441030 |
  | City | Central City | 74075793529314 |
  | Aerugo | Aerugo Borderlands | 72020960130134 |
  | Ishval | Ishval | 133625615147752 |
  | North | Northern Wall | 132378034692557 |
  | Corrupted | Corrupted Lands | 138436167547886 |

  Menu is 123967384111466 and Tutorial is 74257385894576.
- **Studio access:**
  - Run code with `python -I C:/Users/Owner/Rensei-Game-Design/Art/Tools/rbxc.py luau "placeId: <id>" <Edit|Server> @file.lua`.
  - It returns only the first value, so return one string.
  - Never touch the Studio window "bloodydeadpool53's Place".
  - Script edits are refused while Play runs.
- **Editing scripts in Studio:**
  - Server code is edited in `ServerStorage.RenseiServer`; shared data and modules are in `ReplicatedStorage.Modules`. Both are Packages: the owner publishes them, then updates them in Foundry by hand.
  - Create new scripts fresh. To change an existing script with no children, destroy it and recreate it with the full source. If it has children, splice the source at unique anchors.
  - Before every change, copy the old version to that place's `ServerStorage.RenseiBackups["Pre-RegionFoundation_2026-10-23"]`.
  - Keep the repo copies (`Scripts/...`, `Art/Studio/...`) equal to Studio.
- **Saves:**
  - Studio Play writes the owner's REAL profile.
  - Before any Play test, install `C:/Users/Owner/.claude/jobs/0c39df78/tmp/blender/hook.lua`, wait for `LMSnapTaken`, run suites through `game.ServerStorage.LMRunSuite:Invoke(...)` (never through the execute_luau sandbox, which has its own require cache), then restore, Stop, and run `tmp/blender/unhook.lua`.
  - Every session ends restored and unhooked.
- **Tests:**
  - Pure Luau modules get `ServerStorage.RenseiTests.Test_<Name>`, run in Edit with `TestKit.Run(require(Suite))`.
  - Services get `Play_<Name>`.
  - TestKit helpers: `T.Eq(a,b,msg)`, `T.Near(a,b,eps,msg)`, `T.True(v,msg)`, `T.Same(a,b,msg)`.
  - Pure Python modules are tested by `python -I Art/Blender/region_builder/tests/run.py`.
  - Known flakes: Play_Station first run (seat/position), Play_Rumours after Play_Morality, Play_Stealth `GunshotPullsTheCamp`. Rerun once before reporting.
- **Blender:**
  - Run code with `python -I C:/Users/Owner/Rensei-Game-Design/Art/Tools/blender_mcpc.py code @file.py`; the script sets `result`.
  - Blender must be running with its MCP add-on.
  - Keep `Art/Blender/lindenmoor/` working: don't change its behaviour.
- **The game's numbers (`TuningConfig`):** R6 is 4×5×1; walk 16, run 24, sprint 30.
- **Docs:**
  - a `Documents/Changelog.md` entry per task, newest first;
  - `git fetch` and check origin before committing (a collaborator's uncommitted `Art/Blender/Lindenmoor_Full.blend` sits in the working tree; leave it alone);
  - commit trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`;
  - the status page is https://claude.ai/artifact/BfJv3WoTRYs8KLkrNCSsv8 (the controller republishes it).
- **Subagents** run on `model: "opus"`.
- **Never stage `Art/Blender.rar`** (147 MB) or the `.blend` files. Stage by path, never with `git add -A`.

---

## File structure

| File | Responsibility |
|---|---|
| `Scripts/ServerScriptService/DialogueService.lua` | (modify) `StartMinigame` closes the conversation first |
| `Scripts/ServerScriptService/WorldClock.lua` | (new) time of day from real time; Hold/Release; night lamps |
| `Scripts/ServerScriptService/AdminService.lua` | (modify) the Time command holds the clock; "run" releases it |
| `Scripts/ServerScriptService/RumourService.lua` | (modify) `HeardIn(Region, N)` |
| `Scripts/ServerScriptService/NoiseService.lua` | (modify) `NoiseService.Listen(Fn)`: listeners on every emitted noise |
| `Scripts/ReplicatedStorage/Modules/Data/Rensei/TownsfolkLogic.lua` | (new, pure) schedule lookup, greeting text, roster validation |
| `Scripts/ReplicatedStorage/Modules/Data/Rensei/Townsfolk.lua` | (new, data) rosters per region (empty for now; Foundry's comes in the Foundry plan) |
| `Scripts/ServerScriptService/TownsfolkService.lua` | (new) spawn, schedules, movement, sleep, flee, talk |
| `Scripts/ServerScriptService/InvestigationService.lua` | (modify) `RenseiClue` markers become inspect points; `StartsQuest` |
| `Scripts/ServerScriptService/ServerHandler.server.lua` | (modify) start WorldClock and TownsfolkService |
| `Scripts/ServerStorage/RenseiTests/Play_Exams.lua`, `Play_Clock.lua`, `Test_TownsfolkLogic.lua`, `Play_Townsfolk.lua`, `Play_Clue.lua` | (new) tests |
| `Art/Blender/region_builder/__init__.py` | (new) package |
| `Art/Blender/region_builder/schema.py` | (new, pure) load and validate `layout.json` |
| `Art/Blender/region_builder/heightfield.py` | (new, pure) heights → a cell grid → stepped slabs, ramps and sides |
| `Art/Blender/region_builder/merge.py` | (new, pure) greedy rectangle merge |
| `Art/Blender/region_builder/materials.py` | (new) palette keys → Blender materials and the Roblox material table (`materials.json`) |
| `Art/Blender/region_builder/stages.py` | (new, bpy) ground, routes, markers, buildings, landmarks, cover, edges, lighting, renders |
| `Art/Blender/region_builder/kits/railtown.py` | (new, bpy) the rail-town style kit (buildings, landmarks, props) |
| `Art/Blender/region_builder/build.py` | (new, bpy) `run(region, stages)` and the budget check |
| `Art/Blender/region_builder/tests/run.py` | (new) pure-module tests |
| `Art/Regions/Testbed/layout.json` | (new) a 256 × 256 test region exercising every key |
| `Art/Blender/lindenmoor/export.py` | (modify) optional `rs_tags` → row field 16; origin and output as parameters |
| `Art/Studio/Lindenmoor/studio_kit.py` | (modify) optional tags, a `materials.json` override, a staging folder name and region attribute as arguments |
| `Art/Studio/Regions/finish_region.lua.tmpl` | (new) the generic finish: count check, backup, swap, idempotency, dry run |
| `Art/Studio/Regions/travel_pieces.lua` | (new) station, gate, railing, freight yard, road passage and arrival builders, extracted from `station_foundry.lua` and parameterized |
| `Art/Studio/Regions/setup.lua` | (new) reads markers under a map root and calls `travel_pieces` |
| `Art/Studio/Regions/Test_SetupContract.lua` | (new) checks the built pieces against the travel services' contract |

---

### Task 1: Trainer exams open

**Root cause** (found by reading the code; confirm before fixing):
1. The exam opens from dialogue through the action `StartMinigame` (`Dialogues.lua:533`, `:618`).
2. `DialogueService` calls `MinigameService.Open` while the conversation is still open (`DialogueService.lua:155-157`), and `Open` fires the client at once (`MinigameService.lua:245`).
3. The client's `MinigameUI.Open` asks `UIState.ToggleMenu("Minigame")` (`MinigameUI:379`), which refuses while `Gui.Dialogue.Visible` (`UIState:70-72`).
4. So `MinigameUI` closes at once and fires `"Close"`, and the server's `MinigameService.Cancel` ends the session silently (`MinigameService.lua:347-348`).

The `Lesson` and `Exercise` actions already call `DialogueService.Close(Player)` first (`:190-199`); `StartMinigame` doesn't.

**Files:**
- Modify: `Scripts/ServerScriptService/DialogueService.lua` (the `StartMinigame` action, ~:155)
- Test: `Scripts/ServerStorage/RenseiTests/Play_Exams.lua`

**Interfaces:**
- **Consumes:** `DialogueService.Open(Player, Model)`, `DialogueService.Close(Player)`, `MinigameService.Open(Player, Id, Context)`.
- **Produces:** the `StartMinigame` action leaves no dialogue session open when the minigame opens.

- [ ] **Step 1: Confirm the cause in a real client.** In Ye Play (hooked), talk to Calda, reach the exam choice, and pick it. Expected (bug): the exam panel never shows. Take a `screen_capture`. Read the client output for the `MinigameUI` close. Note the result in the report.
- [ ] **Step 2: Write the failing test** `Play_Exams.lua`. For each exam id `flame_exam`, `ice_exam`, `earth_exam`, `wind_exam` and `metal_exam`:
  - put the player in a state where that exam is allowed (its quest active at stage 5; use the quest API, and restore afterwards);
  - run the `StartMinigame` action through the same code path the dialogue uses (`DialogueService.Open` on the trainer, then choose the exam choice by index through the same function the remote calls);
  - assert that the dialogue session is closed (`DialogueService` has no session for the player; add `DialogueService.IsOpen(Player) -> boolean` if no accessor exists);
  - assert that a minigame session for that id is active (use MinigameService's accessor, or add `MinigameService.Current(Player) -> Id?`).

  Restore all quest state with pcall cleanup, in the style of `Play_Rumours`.
- [ ] **Step 3: Run it.** Expected: FAIL for all 5 (the dialogue is still open when the minigame opens).
- [ ] **Step 4: Fix.** In the `StartMinigame` action, before the open:

```lua
		DialogueService.Close(Player) -- the minigame panel can't open over a conversation (UIState); the exams never showed
		MinigameService.Open(Player, A.Minigame, A.Context)
```

  Then make sure `Choose` doesn't reopen or advance a conversation that the action closed. If `Choose` goes on to `Next` after running actions, return early when the session is gone.
- [ ] **Step 5: Run `Play_Exams`.** Expected: PASS 5. Repeat Step 1 by hand: the exam panel shows. Take a `screen_capture` and save it to `Documents/images/Fixes/Trainer exam opens.jpg`.
- [ ] **Step 6: Run** Play_Boot, Play_Arrive and Play_Morality.
- [ ] **Step 7: Commit.** Commit `DialogueService.lua`, `Play_Exams.lua` (and any accessor files), with the message "Trainer exams open: close the conversation before the minigame". Add a Changelog entry.

---

### Task 2: The world clock

**Files:**
- Create: `Scripts/ServerScriptService/WorldClock.lua`
- Modify: `Scripts/ServerScriptService/ServerHandler.server.lua` (start it before LightService), `Scripts/ServerScriptService/AdminService.lua` (`Commands.Time`, ~:245-250), `Scripts/ServerStorage/RenseiTests/Play_Stealth.lua` (it sets `Lighting.ClockTime` at :129-150)
- Test: `Scripts/ServerStorage/RenseiTests/Play_Clock.lua`

**Interfaces:**
- **Consumes:** `Lighting.ClockTime`. LightService lamps are parts tagged `RenseiLight` with a `Light` child; a lamp counts only while `Light.Enabled` is true (`LightService:51-66`, `:82`).
- **Produces:**
  - `WorldClock.Hour(Now: number?) -> number` (0 ≤ h < 24);
  - `WorldClock.Hold(Hour: number)`, `WorldClock.Release()`, `WorldClock.IsHeld() -> boolean`;
  - `WorldClock.IsNight(Hour: number?) -> boolean` (night is before 06:00 or from 18:00);
  - `WorldClock.DayMinutes = 24` (PROPOSAL);
  - `WorldClock.Changed`: a BindableEvent fired when the whole game hour changes, with `(Hour)`;
  - lamps whose `Light`'s parent part has attribute `NightOnly = true` are enabled only at night.

- [ ] **Step 1: Write the failing test** `Play_Clock.lua`:

```lua
local Lighting = game:GetService("Lighting")
local SSS = game:GetService("ServerScriptService")
return {
	HourFollowsRealTime = function(T)
		local C = require(SSS.WorldClock)
		T.Near(C.Hour(0), 0, 1e-6)
		T.Near(C.Hour(60), 1, 1e-6) -- one real minute = one game hour (PROPOSAL 24-minute day)
		T.Near(C.Hour(24 * 60 + 90), 1.5, 1e-6)
	end,
	HoldAndRelease = function(T)
		local C = require(SSS.WorldClock)
		C.Hold(3)
		task.wait(1.2)
		T.Near(Lighting.ClockTime, 3, 0.01, "held")
		C.Release()
		task.wait(1.2)
		T.Near(Lighting.ClockTime, C.Hour(), 0.05, "released follows real time")
	end,
	NightLamps = function(T)
		local C = require(SSS.WorldClock)
		local P = Instance.new("Part") P.Anchored = true P.Position = Vector3.new(0, -400, 0) P.Parent = workspace
		P:SetAttribute("NightOnly", true)
		local L = Instance.new("PointLight", P)
		C.Hold(13) task.wait(1.2)
		T.Eq(L.Enabled, false, "off by day")
		C.Hold(23) task.wait(1.2)
		T.Eq(L.Enabled, true, "on at night")
		C.Release() P:Destroy()
	end,
	IsNight = function(T)
		local C = require(SSS.WorldClock)
		T.True(C.IsNight(2) and C.IsNight(18) and not C.IsNight(6) and not C.IsNight(12))
	end,
}
```

- [ ] **Step 2: Run it.** Expected: FAIL (no `WorldClock`).
- [ ] **Step 3: Implement** `WorldClock.lua`:

```lua
-- WorldClock (region builds spec §4): the time of day comes from real time, so every place and server
-- shows the same hour. DayMinutes real minutes = one game day (PROPOSAL 24). Hold(h) freezes it
-- (admin Time command, tests); Release() lets it run. Lamps whose part has NightOnly = true light at night.
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local WorldClock = {DayMinutes = 24} -- PROPOSAL
WorldClock.Changed = Instance.new("BindableEvent")
local Held, LastWhole

function WorldClock.Hour(Now)
	Now = Now or os.time()
	return ((Now / 60) * (24 / WorldClock.DayMinutes)) % 24
end
function WorldClock.IsNight(H)
	H = H or Lighting.ClockTime
	return H < 6 or H >= 18 -- PROPOSAL
end
function WorldClock.Hold(H) Held = H % 24 Lighting.ClockTime = Held end
function WorldClock.Release() Held = nil end
function WorldClock.IsHeld() return Held ~= nil end

local function Lamps(Night)
	for _, P in ipairs(CollectionService:GetTagged("RenseiLight")) do
		if P:GetAttribute("NightOnly") then
			for _, L in ipairs(P:GetChildren()) do if L:IsA("Light") then L.Enabled = Night end end
		end
	end
	-- NightOnly lamps that LightService hasn't tagged yet (no tag before LightService.Start)
	for _, L in ipairs(workspace:GetDescendants()) do
		if L:IsA("Light") and L.Parent:GetAttribute("NightOnly") and not CollectionService:HasTag(L.Parent, "RenseiLight") then L.Enabled = Night end
	end
end

function WorldClock.Tick()
	local H = Held or WorldClock.Hour()
	Lighting.ClockTime = H
	local Whole = math.floor(H)
	if Whole ~= LastWhole then
		LastWhole = Whole
		Lamps(WorldClock.IsNight(H))
		WorldClock.Changed:Fire(Whole)
	end
end

function WorldClock.Start()
	task.spawn(function()
		while true do
			local Ok, Err = pcall(WorldClock.Tick)
			if not Ok then warn("WorldClock:", Err) end
			task.wait(1)
		end
	end)
end

return WorldClock
```

  The lamp sweep only runs on an hour change, so the `GetDescendants` scan costs nothing per second. If it turns out slow in a big region, restrict it to parts tagged `RenseiLight`.
- [ ] **Step 4: Wire it in.**
  - **ServerHandler:** add `require(ServerScriptService.WorldClock).Start()` before LightService, in a pcall like the travel services.
  - **AdminService `Commands.Time`:** a number calls `WorldClock.Hold(N)`; the argument `"run"` calls `WorldClock.Release()`.
  - **Play_Stealth:** replace the direct `Lighting.ClockTime = …` sets with `WorldClock.Hold(…)`, and restore with `Release()`.
  - **Lindenmoor's street lamps** (`Workspace.World.Map.Lindenmoor.Lamps`, 17 posts): give each lamp part that holds the light `NightOnly = true`. Use a one-off script, back up first, and record it in the report. The camp fire and the house door lanterns stay always-on.
- [ ] **Step 5: Run** Play_Clock (PASS 4), Play_Stealth (9) and Play_Road (11). Check by hand: at a held 23:00, Lindenmoor's square lamps are lit and the sky is dark. Take a `screen_capture`.
- [ ] **Step 6: Commit and add a Changelog entry** ("A day and night: 24 minutes, the same time in every place").

---

### Task 3: Rumours a region has heard

**Files:**
- Modify: `Scripts/ServerScriptService/RumourService.lua`
- Test: add `HeardInFiltersAndSorts` to `Scripts/ServerStorage/RenseiTests/Play_Rumours.lua`

**Interfaces:**
- **Consumes:**
  - per-player `Data.Morality.News`: a list of `{At, Place, Deed, Heard={factions}, Report?}`, newest first, at most 10 (`RumourService/Core.lua:30-33, 97, 121`);
  - `Deeds[DeedId].Text` (`Deeds.lua:4-5`);
  - `ProgressionService.GetData(Player)`.
- **Produces:** `RumourService.HeardIn(Region: string, N: number?) -> {{At: number, Text: string, Subject: Player}}`, newest first, at most N (default 3). It reads the news of every player in this server, because rumour state is stored per player.

- [ ] **Step 1: Write the failing test.** Give the test player three `News` entries (two for `Foundry`, one for `City`, with different `At`) and a deed with known `Text`. Assert that `HeardIn("Foundry", 3)` returns 2 entries, newest first, with the deed texts. Restore the player's `News` afterwards.
- [ ] **Step 2: Run it.** Expected: FAIL.
- [ ] **Step 3: Implement:**

```lua
-- HeardIn (region builds spec §5): the latest word that reached Region, across everyone in this server.
-- Rumour state is per player (Data.Morality.News), so this reads each player's news. Read-only.
function RumourService.HeardIn(Region, N)
	local All = {}
	for _, P in ipairs(Players:GetPlayers()) do
		local D = ProgressionService.GetData(P)
		local News = D and D.Morality and D.Morality.News
		for _, A in ipairs(News or {}) do
			local Def = Deeds[A.Deed]
			if A.Place == Region and Def and Def.Text then
				table.insert(All, {At = A.At, Text = Def.Text, Subject = P})
			end
		end
	end
	table.sort(All, function(a, b) return a.At > b.At end)
	local Out = {}
	for i = 1, math.min(N or 3, #All) do Out[i] = All[i] end
	return Out
end
```

- [ ] **Step 4: Run** Play_Rumours (all pass; run it before Play_Morality, see the flakes note).
- [ ] **Step 5: Commit.**

---

### Task 4: Townsfolk rules (pure) and the roster format

**Files:**
- Create: `Scripts/ReplicatedStorage/Modules/Data/Rensei/TownsfolkLogic.lua`, `Scripts/ReplicatedStorage/Modules/Data/Rensei/Townsfolk.lua`
- Test: `Scripts/ServerStorage/RenseiTests/Test_TownsfolkLogic.lua`

**Interfaces:**
- **Produces:**
  - **The roster format** (`Townsfolk.Regions[RegionId] = { {…}, … }`). Each townsperson is:

```lua
{
	Id = "foundry_crane_1",            -- unique within the region
	Name = "Edda Varn",
	Job = "Crane hand",
	JobLine = "Third shift on the bay crane. Watch your head under the hooks.",
	Faction = "Foundry",               -- a Factions id; the greeting reads this faction's standing here
	Look = {Nation = "Amestrian", Gender = "Female", Seed = 11},
	Idle = "NPC_Blacksmith",           -- optional default idle at work posts
	Schedule = { {6, 14, "crane_bay_2"}, {14, 15, "canteen_seat_4"}, {15, 6, "workers_row_3"} },
	Greetings = nil,                   -- optional per-tier overrides {Hostile=..., Neutral=...}
	Clue = nil,                        -- optional {Quest = "<QuestId>", Stage = "<stage id>", Text = "...", Signal = "<target>"}
}
```

  - `TownsfolkLogic.PostAt(Schedule, Hour: number) -> PostId`. `{From, To, Post}` covers `From <= h < To`, wrapping past midnight when `From > To`.
  - `TownsfolkLogic.Greeting(Tier: string, Def) -> string`.
  - `TownsfolkLogic.Validate(Roster, PostIds: {[string]=true}) -> (boolean, {string})`. Every hour must be covered, every post must exist, ids must be unique, and every `Faction` must be a known faction.
  - `TownsfolkLogic.KindIdles = {Work = nil, Seat = "NPC_Chill", Counter = "NPC_CrossArms", Home = "NPC_Chill", Shelter = "NPC_CurledUp"}` (PROPOSAL; working idles per `Documents/Animations.md`).

- [ ] **Step 1: Write the failing test** `Test_TownsfolkLogic.lua`:

```lua
local L = require(game.ReplicatedStorage.Modules.Data.Rensei.TownsfolkLogic)
local S = { {6, 14, "work"}, {14, 15, "canteen"}, {15, 6, "home"} }
return {
	PostAtWraps = function(T)
		T.Eq(L.PostAt(S, 6), "work") T.Eq(L.PostAt(S, 13.99), "work")
		T.Eq(L.PostAt(S, 14.5), "canteen") T.Eq(L.PostAt(S, 23), "home") T.Eq(L.PostAt(S, 2), "home")
	end,
	GreetingByTier = function(T)
		T.True(#L.Greeting("Hostile", {}) > 0 and L.Greeting("Hostile", {}) ~= L.Greeting("Honoured", {}))
		T.Eq(L.Greeting("Neutral", {Greetings = {Neutral = "Hm."}}), "Hm.")
		T.Eq(L.Greeting("Nonsense", {}), L.Greeting("Neutral", {}))
	end,
	ValidateCatchesGaps = function(T)
		local Ok, Errs = L.Validate({ {Id = "a", Name = "A", Faction = "Foundry", Schedule = { {6, 14, "work"} }} }, {work = true})
		T.Eq(Ok, false) T.True(#Errs >= 1, "hours not covered")
		Ok = L.Validate({ {Id = "a", Name = "A", Faction = "Foundry", Schedule = S} }, {work = true, canteen = true, home = true})
		T.Eq(Ok, true)
		Ok = L.Validate({ {Id = "a", Name = "A", Faction = "Foundry", Schedule = S} }, {work = true})
		T.Eq(Ok, false, "missing posts")
	end,
}
```

- [ ] **Step 2: Run it in Edit.** Expected: FAIL.
- [ ] **Step 3: Implement** `TownsfolkLogic.lua`:

```lua
-- TownsfolkLogic (region builds spec §5): pure rules for townsfolk. No Instances.
local Factions = require(script.Parent.Factions)
local L = {}

function L.PostAt(Schedule, Hour)
	for _, S in ipairs(Schedule) do
		local F, T = S[1], S[2]
		if (F <= T and Hour >= F and Hour < T) or (F > T and (Hour >= F or Hour < T)) then return S[3] end
	end
	return Schedule[#Schedule] and Schedule[#Schedule][3]
end

L.Greetings = { -- PROPOSAL lines
	Hostile = "We've nothing to say to you. Move along.",
	Distrusted = "You again. Keep your hands where I can see them.",
	Neutral = "Afternoon. Need something?",
	Trusted = "Good to see you. What can I do for you?",
	Honoured = "Well met! Always a pleasure. Ask away.",
}
function L.Greeting(Tier, Def)
	return (Def and Def.Greetings and Def.Greetings[Tier]) or L.Greetings[Tier] or L.Greetings.Neutral
end

L.KindIdles = {Seat = "NPC_Chill", Counter = "NPC_CrossArms", Home = "NPC_Chill", Shelter = "NPC_CurledUp"} -- PROPOSAL

function L.Validate(Roster, PostIds)
	local Errs, Seen = {}, {}
	for _, D in ipairs(Roster) do
		if Seen[D.Id] then table.insert(Errs, "duplicate id " .. tostring(D.Id)) end
		Seen[D.Id] = true
		if not (Factions.Factions and Factions.Factions[D.Faction]) then table.insert(Errs, D.Id .. ": unknown faction " .. tostring(D.Faction)) end
		for H = 0, 23 do
			if not L.PostAt(D.Schedule, H + 0.5) or not (function()
				for _, S in ipairs(D.Schedule) do
					local F, T = S[1], S[2]
					if (F <= T and H + 0.5 >= F and H + 0.5 < T) or (F > T and (H + 0.5 >= F or H + 0.5 < T)) then return true end
				end
			end)() then table.insert(Errs, D.Id .. ": hour " .. H .. " not covered") break end
		end
		for _, S in ipairs(D.Schedule) do
			if not PostIds[S[3]] then table.insert(Errs, D.Id .. ": missing post " .. tostring(S[3])) end
		end
	end
	return #Errs == 0, Errs
end

return L
```

  Check the real shape of `Factions` (`Factions.lua:9-24`) and use its faction table. Adjust `Factions.Factions` to whatever the module exposes.

  `Townsfolk.lua`:

```lua
-- Townsfolk rosters per region (region builds spec §5). Format: see TownsfolkLogic / the Foundation plan, Task 4.
-- Foundry Yard's roster arrives with the Foundry plan.
return {Regions = {}}
```

- [ ] **Step 4: Run it.** Expected: PASS 3.
- [ ] **Step 5: Commit.**

---

### Task 5: The townsfolk service: spawn, schedules, movement

**Files:**
- Create: `Scripts/ServerScriptService/TownsfolkService.lua`
- Modify: `ServerHandler.server.lua` (start it after PerceptionService, NoiseService and DialogueService)
- Test: `Scripts/ServerStorage/RenseiTests/Play_Townsfolk.lua`

**Interfaces:**
- **Consumes:**
  - `TownsfolkLogic.*`, `Townsfolk.Regions`, `WorldClock.Hour()`, `WorldClock.Changed`;
  - `TravelService.Here() -> RegionId`;
  - `AppearanceService.Apply(Rig, Look, Name?)` and `Customization.RandomLook(Nation, Rng)` (`EnemyService:130-133` does the same for enemies);
  - the R6 rig source EnemyService uses (find it in `EnemyService` and use the same template);
  - posts: BaseParts tagged `RenseiPost` with attributes `PostId` (string) and `Kind` (Work/Seat/Counter/Home/Shelter). A post's LookVector is the facing.
  - **Watchers:** models tagged `RenseiWatcher` read the attributes `WatcherType` ("Witness"), `Faction` and `Carrier` (`PerceptionService:395-403`).
  - **Idles:** set `IdleAnim` on the model (`NpcIdles.server.lua`). It keeps the root anchored and loosens jointed parts; a walking townsperson needs an unanchored root (see Step 3).
- **Produces:**
  - `TownsfolkService.Spawn(Def, Region) -> Model`: the rig lives in `workspace.World.Live.Townsfolk`, tagged `RenseiTownsfolk` and `RenseiWatcher`, with attributes `TownsfolkId`, `DisplayName`, `WatcherType = "Witness"`, `Faction`, `Carrier = false`.
  - `TownsfolkService.Get(Id) -> Model?`, `TownsfolkService.Despawn(Id)`.
  - `TownsfolkService.Step(Hour: number?)`: one update for every townsperson (the 1 Hz loop calls it; tests call it directly).
  - `TownsfolkService.State(Id) -> "AtPost" | "Walking" | "Fleeing" | "Sheltering" | "Asleep"`.
  - `TownsfolkService.SleepRadius = 300`, `TownsfolkService.WalkSpeed = 8` (PROPOSAL).

- [ ] **Step 1: Write the failing test** `Play_Townsfolk.lua`. The fixture builds three posts 40 studs apart on clear, flat ground in Ye. Raycast down from 100 studs above a spot by the Lindenmoor square to find the ground, and destroy everything in cleanup. Tests:
  - **SpawnsAtCurrentPost:** spawn a test Def at a held hour; it stands within 4 studs of its scheduled post with the post's facing, and is tagged `RenseiWatcher` with `WatcherType = "Witness"`.
  - **WalksToNextPostOnScheduleChange:** with a player within 50 studs (the test player's character), change the held hour so the post changes, then `Step()`. `State` is `"Walking"`. Within 15 s (40 studs at WalkSpeed 8, plus a margin) it reaches the new post and `State` is `"AtPost"`.
  - **SleepsWithNoPlayerNear:** move the player's character more than 300 studs away (save and restore its pivot), change the hour, then `Step()`. It is placed at the new post at once, and `State` is `"Asleep"`.
  - **ValidRosterOnly:** `TownsfolkService.LoadRegion("Test", Roster)` with a roster that names a missing post returns false and spawns nothing.
- [ ] **Step 2: Run it.** Expected: FAIL.
- [ ] **Step 3: Implement** `TownsfolkService` with these rules:
  - **Posts:** read once at Start, then on `GetInstanceAddedSignal("RenseiPost")`, into `Posts[PostId] = Part`.
  - **Start():** `LoadRegion(TravelService.Here(), Townsfolk.Regions[Here])` when that roster exists. `LoadRegion` validates with `TownsfolkLogic.Validate`, warns and returns false on errors, and otherwise spawns everyone. Then start a 1 Hz loop calling `Step()` in a pcall.
  - **Spawn(Def):**
    - Build an R6 rig from the same template EnemyService uses. Apply the look with `Customization.RandomLook(Def.Look.Nation, Random.new(Def.Look.Seed))`; if `Def.Look.Gender` is set and RandomLook can't take it, pick a seed that matches.
    - Call `AppearanceService.Apply(Rig, Look, Def.Name)`.
    - Set `Humanoid.WalkSpeed = 8` and `DisplayDistanceType = Viewer`.
    - Set the tags and attributes listed above, plus `IdleAnim`.
    - Place it at its current post: `PivotTo(Post.CFrame * CFrame.new(0, 3, 0))` facing the post.
    - Call `RootPart:SetNetworkOwner(nil)`.
  - **Step(Hour):**
    - Hour = `Hour or WorldClock.Hour()` (when held, use `Lighting.ClockTime`).
    - For each townsperson not `Fleeing` or `Sheltering`: `Want = PostAt(Schedule, Hour)`. If `Want ~= Current`:
      - with no player within `SleepRadius`: `PivotTo` the new post, state `Asleep`;
      - otherwise: clear `IdleAnim`, unanchor the root, compute a path with `PathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = false})` and `ComputeAsync`, and walk the waypoints with `Humanoid:MoveTo` and `MoveToFinished`, in its own task with a timeout per waypoint (PROPOSAL 4 s). If the path fails, `PivotTo` the post and warn once.
      - On arrival: `PivotTo` exactly onto the post's facing, re-anchor the root, set `IdleAnim` to `Def.Idle` (for Work posts) or `KindIdles[Kind]`, and set state `AtPost`.
    - Townsfolk that are asleep wake when a player comes within `SleepRadius`. They are already at the right post, so set them to `AtPost`.
  - **Despawn(Id)** destroys the rig and clears state.
  - Keep each townsperson's walking task cancellable (a version counter), so a newer schedule change or a flee wins.
- [ ] **Step 4: Run** Play_Townsfolk (PASS 4), plus Play_Boot and Play_Stealth.
- [ ] **Step 5: Commit.**

---

### Task 5b: Crowd-quality movement (no walking through each other)

**Owner (2026-10-23):** "I want the townsfolk pathfinding to be the best you can make it x1000, I don't want them to walk through each other."

Roblox's `PathfindingService` plans only around static geometry. It knows nothing about other moving characters. This task adds a crowd layer on top of it. It replaces Task 5's walking unit (`TownsfolkService.Mover`) without changing spawning or schedules.

**Files:**
- Modify: `Scripts/ServerScriptService/TownsfolkService/Mover.lua` (the movement unit Task 5 created), `TownsfolkService.lua` (only where it calls the mover)
- Modify: `Scripts/ReplicatedStorage/Modules/Data/Rensei/TownsfolkLogic.lua`: `Validate` rejects two townsfolk at the same post at the same hour
- Test: `Scripts/ServerStorage/RenseiTests/Play_TownsfolkCrowd.lua`

**Interfaces:**
- **Consumes:** Task 5's `Mover.WalkTo(Rig, TargetCFrame, Opts) -> handle` (`handle:Cancel()`, done with "arrived" | "failed" | "cancelled"), `Mover.Place(Rig, TargetCFrame)`, and the `Townsfolk` collision group.
- **Produces:** the same `Mover` API with these behaviours, plus `Mover.Stats() -> {Walkers, StepMs}` for the performance check.

**The movement rules** (every number is a PROPOSAL):
1. **Path planning:**
   - `PathfindingService:CreatePath` with `AgentRadius 2.5`, `AgentHeight 5.5`, `AgentCanJump false`, `AgentCanClimb false`, `WaypointSpacing 4`.
   - Material costs prefer streets: Cobblestone, Brick, Concrete and Pavement 1; Ground and WoodPlanks 1.5; Grass and LeafyGrass 3; Water and Mud 20.
   - Respect any `PathfindingModifier` labels the builder adds later.
2. **Path smoothing:** after computing a path, drop each intermediate waypoint that the walker can skip safely. "Safely" means a 1.5-radius `Spherecast` at waist height between the earlier and later point is clear, and a ground ray every 2 studs finds walkable ground within 3 studs of the line's height. The result is direct lines across open squares and corners taken naturally.
3. **Local avoidance (steering):**
   - Only walking townsfolk are updated, at 10 Hz on Heartbeat.
   - Desired velocity = toward the next waypoint at WalkSpeed, slowing over the last 4 studs.
   - **Avoidance** of other townsfolk and players within 10 studs: predict each pair's closest approach over the next 1.5 s from current velocities. If it's under 3 studs, add a sideways correction that **passes on the right** by convention, so two walkers never both dodge into each other. Add a separation push when already closer than 3 studs.
   - **Moving onto the path:** the result goes to `Humanoid:Move(direction)` (not `MoveTo`), so steering is continuous.
4. **Narrow spots:** when two walkers are both blocked head-on in a gap (both slower than 1 stud/s for 0.75 s and facing each other within 4 studs), the one with the lower priority yields. Priority is the one closer to its own goal, then the lower `Id`. The yielder steps back and right about 2.5 studs and waits until the other has passed (their distance is growing), then resumes.
5. **Re-planning:**
   - On `Path.Blocked` for a waypoint ahead, compute a new path from the current position.
   - **Stuck detection:** less than 0.5 studs of progress in 1.5 s. Step sideways once, then re-plan. After 3 re-plans, mark the walk "failed".
   - TownsfolkService then places the townsperson at the post with `Mover.Place`, but only when no player is within 60 studs. Otherwise it keeps trying every 5 s, so nobody sees a teleport.
6. **Posts:** a walker arriving at an occupied post (another rig within 2 studs) waits up to 5 s nearby (1.5 studs to the side), then re-checks. `Validate` already makes shared posts impossible within one roster.
7. **Looks:**
   - The walk animation plays at a speed matched to the actual velocity, using the game's Animate / locomotion setup as enemies do.
   - Facing turns smoothly. At arrival, the rig turns to the post's facing over 0.3 s, not instantly.
8. **Bodies:** collisions stay on, so rigs physically can't overlap. Use the `Townsfolk` collision group (it collides with Default and itself). The server owns the physics (`SetNetworkOwner(nil)`).
9. **Cost:** with 20 walkers steering, the average steering time is at most 1.5 ms per Heartbeat. Townsfolk that are asleep or at their post cost nothing per frame.

- [ ] **Step 1: Write the failing tests** `Play_TownsfolkCrowd.lua`. Fixtures are built from parts on clear flat ground in Ye, using test-only rosters, and are cleaned up in pcall-guarded cleanup. Sample root positions at 10 Hz throughout.
  - **CorridorPassing:** a corridor 8 studs wide and 60 long. Two walkers start at opposite ends and swap. The closest their roots ever get is at least 2.5 studs, and both arrive within 20 s.
  - **Doorway:** a wall with a door 5 studs wide. Two walkers cross through it in opposite directions. Both arrive within 25 s, their roots never get closer than 2.2 studs, and exactly one of them yields (from the mover's debug stats).
  - **Converging:** 8 walkers start on a 30-stud ring and walk to 8 posts 3 studs apart near the centre. No pair is closer than 2.2 studs for more than 0.2 s in total, and all arrive within 30 s.
  - **PlayerInTheWay:** a stationary R6 dummy (standing in for a player) sits on the straight line between start and post. The walker passes it at 2.5 studs or more and arrives.
  - **BlockedRepath:** after the path is computed, a wall drops across it. The walker re-plans and arrives within 30 s, and its state never becomes "failed".
  - **Smoothing:** in a 60 × 60 open plaza, a diagonal walk keeps at most 3 waypoints after smoothing.
  - **Performance:** 20 walkers crossing a plaza, average `Mover.Stats().StepMs` ≤ 1.5.
  - **Validate (Edit, in `Test_TownsfolkLogic`):** two townsfolk sharing a post at overlapping hours is an error.
- [ ] **Step 2: Run them.** Expected: most FAIL with Task 5's basic mover.
- [ ] **Step 3: Implement** the movement rules in `Mover.lua`. Keep the public API unchanged.
- [ ] **Step 4: Run** Play_TownsfolkCrowd (all pass) and Play_Townsfolk (still passes). Record a short **video-like proof**: 6 screenshots, 1 s apart, of the Doorway test from above. Save them to `Documents/images/Townsfolk/`.
- [ ] **Step 5: Commit.**

---

### Task 6: Townsfolk reactions and talk (speech above their heads)

**Owner (2026-10-23):** "Make the townsfolk chat appear above their head with a custom font". The chosen font is **Special Elite**, with **bubbles only, no reply choices**. This replaces the dialogue-box talk described in the interfaces below wherever they differ. The bubble rules are in "Talk, as built" at the end of this task.

**Files:**
- Modify: `Scripts/ServerScriptService/NoiseService.lua` (a listener list), `Scripts/ServerScriptService/TownsfolkService.lua`, `Scripts/ReplicatedStorage/Modules/Data/Rensei/TownsfolkLogic.lua` (talk rotation and chatter lines)
- Create: `Art/Studio/Regions/TownsfolkClient.lua` (a LocalScript for `StarterPlayer.StarterPlayerScripts`, a plain copy in each region place like TravelClient) and the RemoteEvent `ReplicatedStorage.Remotes.TownsfolkSay` (add it to the Remotes package)
- Test: add tests to `Play_Townsfolk.lua` and `Test_TownsfolkLogic.lua`

**Interfaces:**
- **Consumes:**
  - `NoiseService.Emit(Position, Kind | Radius, Source)` (`NoiseService.lua:2`). Combat sound kinds and radii: Hit 20, Cast 30, Gunshot 60, Roll 10 (`Perception.lua:103-105`).
  - `DialogueService.Ask(Player, Model, Speaker, Text, Choices, OnAnswer)` (`DialogueService.lua:122`; `OnAnswer(Index | nil)` runs on the server) and `DialogueService.Say(Player, Model, Speaker, Text)` (`:108`). Check the exact `Choices` shape there.
  - `QuestService.Signal(Player, "Talk", Target)`.
  - Standing: `Reputation.PlaceStanding(Data.Morality, Deeds, Region)[Faction]` (`Reputation.lua:51-63`), then `Factions.TierOf(value)` (`Factions.lua:64-69`).
  - `RumourService.HeardIn(Region, N)` (Task 3).
  - Names: if `IdentityService` exposes the name a viewer knows another player by, use it for the rumour subject; otherwise say "someone". Check `IdentityService.lua` for the exact function.
- **Produces:**
  - `NoiseService.Listen(Fn: (Position, Radius, Kind, Source) -> ()) -> () -> ()`: returns a disconnect function and is called on every `Emit`.
  - **Flee:** a combat noise (Hit, Cast, Gunshot) within its radius + 20 studs (PROPOSAL) of a townsperson sends them to the nearest `Shelter` post at WalkSpeed 16, state `Fleeing`, then `Sheltering` with idle `NPC_CurledUp`. They return to their schedule 20 s (PROPOSAL) after the last combat noise within that range.
  - **Talk:** a `ProximityPrompt` named `TalkPrompt` on the townsperson's root (ActionText "Talk", ObjectText = Name, MaxActivationDistance 10). Triggering it:
    1. fires `QuestService.Signal(Player, "Talk", Def.Id)`;
    2. opens `DialogueService.Ask` with the greeting for the player's standing tier with `Def.Faction` in this region;
    3. offers the choices "Heard anything lately?", "What do you do here?", the clue line (if the player is on `Def.Clue.Quest` at `Def.Clue.Stage`) and "Goodbye".
  - **Answers:**
    - **Rumours:** up to 3 lines, `"They say <subject> <deed text>."`, or "Nothing worth repeating." when there are none.
    - **Job:** the job line.
    - **Clue:** `Def.Clue.Text`, then `QuestService.Signal(Player, "Signal", Def.Clue.Signal)`.
  - **While fleeing or sheltering**, the prompt is disabled.

- [ ] **Step 1: Write the failing tests:**
  - **FleesOnCombatNoiseAndReturns:** a townsperson at its post, a Shelter post 30 studs away, and a held hour. Call `NoiseService.Emit(TownspersonPos + Vector3.new(5,0,0), "Hit", nil)`, then `Step()`. Assert `State == "Fleeing"`, then `"Sheltering"` at the shelter within 10 s. Set `TownsfolkService.CalmSeconds = 2` for the test (restore it after). Within 2 + 15 s it is back `AtPost`.
  - **WitnessTagged:** the rig has the `RenseiWatcher` tag, and `PerceptionService` registered it. Check with whatever accessor PerceptionService has, or by whether `PerceptionService.Perceived(Player)` returns it after the player stands in front of it in daylight for 3 s.
  - **TalkGreetsByStanding:** trigger `TownsfolkService.Talk(Player, Id)` with the player's region standing for the faction forced to 70 (patch `Reputation.PlaceStanding` for the test). Assert `TownsfolkService.LastLine(Id)` equals `TownsfolkLogic.Greeting("Honoured", Def)`. Restore all patches.
  - **RumourIsTheSecondLine:** inject one `News` entry for this region, call `Talk` twice, and assert the second `LastLine` contains the deed's text. A third `Talk` gives the job line.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement.**
  - **NoiseService:** keep a `Listeners` list; `Emit` calls each listener in a pcall after its current work.
  - **TownsfolkService:** subscribe with `NoiseService.Listen`. Keep `LastNoise[Id]`. `Step()` returns sheltering townsfolk to their schedule when `os.clock() - LastNoise > CalmSeconds`.
  - **Talk:** add `TownsfolkService.Talk(Player, Id)` (also called by the prompt).
  - Don't make townsfolk hittable or killable. Whether they should be hittable is an open owner decision (Plan 2).
- [ ] **Step 4: Run** Play_Townsfolk (all pass), Play_Stealth, Play_Heat and Play_Morality.
- [ ] **Step 5: Commit and add a Changelog entry** ("Townsfolk: schedules, hiding from fights, talk").

#### Talk, as built (overrides the dialogue-box talk above)

- **Server**
  - `TownsfolkService.Talk(Player, Id)` makes the townsperson say one line, in this order:
    1. `QuestService.Signal(Player, "Talk", Def.Id)`.
    2. The clue line, if the player is on `Def.Clue.Quest` at `Def.Clue.Stage`. After it, `QuestService.Signal(Player, "Signal", Def.Clue.Signal)`.
    3. Otherwise the next line in that player's rotation for this townsperson: greeting (by standing tier) → a rumour (`HeardIn(Region, 3)`; pick one the player hasn't heard from this townsperson yet; skip the step when there is none) → the job line → greeting again.
  - Keep the rotation index per (Player, Id) in memory only. Nothing is saved.
  - `TownsfolkService.Say(Id, Text)` fires `Remotes.TownsfolkSay:FireAllClients(Rig, Text, Seconds)` to every player within 100 studs (PROPOSAL) of the rig, and records the last line for tests (`TownsfolkService.LastLine(Id)`).
  - `Seconds = 3 + 0.05 * #Text` (PROPOSAL).
  - The `TalkPrompt` stays (ActionText "Talk"). Talking again while a bubble is showing replaces it.
  - **Ambient chatter**, from `TownsfolkLogic.Chatter[Kind]`, where Kind is one of:
    - `Pass`: a player first comes within 12 studs; at most once per player per townsperson every 300 s (PROPOSAL);
    - `Shift`: their post changes because of the schedule; 50 % chance (PROPOSAL);
    - `Flee`: starting to flee;
    - `Return`: coming back from shelter.

    Each kind is a list of short lines (PROPOSAL text); pick one at random.
- **Client:** `TownsfolkClient` listens to `TownsfolkSay` and shows a `BillboardGui` named `SpeechBubble` on the rig's Head:
  - `StudsOffset (0, 2.6, 0)`, `MaxDistance 60`, `LightInfluence 0`, `AlwaysOnTop false` (PROPOSAL).
  - The background is a clone of the existing dialogue art: the choice-plate image from `StarterGui.Uis`'s Dialogue (find the ImageLabel with its 9-slice settings and reuse its Image and SliceCenter). No new assets and no drawn shapes.
  - A `TextLabel` with `FontFace = Font.new("rbxasset://fonts/families/SpecialElite.json")`, `TextWrapped`, and at most 260 px wide (the bubble grows in height).
  - It fades in and out with UIMotion (as the ticket window does). A new line on the same rig replaces the old one.
  - First check that the Special Elite family loads: `TextService:GetTextBoundsAsync` with that font, or `ContentProvider:PreloadAsync` on the label. If it doesn't, report it rather than falling back silently.
- **Tests:**
  - `Test_TownsfolkLogic`: the rotation order (greeting → rumour → job → greeting); the rumour step is skipped with no rumours; the clue line wins when the stage matches.
  - `Play_Townsfolk`: `Talk` produces the expected `LastLine` sequence; the `Pass` chatter fires once, then not again within 300 s; a flee produces a `Flee` line.
  - **Client check:** in Play, open a client view near a townsperson, trigger `Talk`, then check through the client datamodel that `SpeechBubble` exists under the Head, with the Special Elite FontFace and the expected text. The MCP screenshot tool doesn't render BillboardGuis, so verify by state and ask the owner to look at it in Play.
- **Not used:** `DialogueService.Ask` and the dialogue box. Townsfolk carry no `DialogueId`.

---

### Task 6b: Townsfolk can be hurt (Heat, standing, morality, witnesses, rumours)

**Owner (2026-10-23):** "The townsfolk should be hittable and integrate the heat, rep system, morality, etc." The answer to "when their health runs out" was "Knocked, can be finished": they're knocked like enemies, get up and flee if left, die if executed, and a newcomer takes the job at the next 06:00.

**Files:**
- Modify:
  - `Scripts/ServerScriptService/TownsfolkService.lua`: a WCS character per rig; health; hurt, knocked and death handling; newcomers.
  - `Scripts/ReplicatedStorage/Modules/Data/Rensei/Deeds.lua`: a new `murder_townsfolk` deed.
  - `Scripts/ReplicatedStorage/Modules/Data/Rensei/TownsfolkLogic.lua`: `Chatter.Hurt`, `Chatter.Help`, newcomer names per nation.
  - `Scripts/ServerScriptService/WorldService.lua`: no defeat rewards for townsfolk.
  - The DownedManager hooks where needed.
- Test: `Scripts/ServerStorage/RenseiTests/Play_TownsfolkHurt.lua`

**Interfaces:**
- **Consumes:**
  - **Combat:** `DamageManager` (needs the victim's WCS character state; Task 5's fix made a missing state a safe "no hit"). Give each townsperson a WCS character the way EnemyService or CharacterHandler's training dummies do (`WCSCharacter.new(Rig)`); find the exact pattern there.
  - **Assault already exists:** `ProgressionService.HitListeners` calls `HeatService`'s `OnHit` (`HeatService.lua:176-185`). Townsfolk are tagged `RenseiWatcher`, so every hit by a player records `assault_townsfolk` (`Deeds.lua:102-106`, "Struck a townsperson", `Standing {Townsfolk = -2}`), witnessed, at most once per victim per `AssaultCooldown`.
  - **Knocked and execution:** `DownedManager` (knocked state, grip B, carry V, execution). Use the same attributes and flow as enemies.
  - **Deeds:** `MoralityService.Record(Player, DeedId, Private, {Witness = true, Region = ...})` and `MoralityService.Recorded`. HeatService turns crimes into Heat by jurisdiction (`OnRecorded`). Make `murder_townsfolk` a crime the same way the existing crime deeds are; read how they're marked.
  - **Defeat credit:** `WorldService` credits EXP, money, codex and quest progress on any non-player Humanoid death in `World.Live` (`WorldService.lua:1-10`, `:89`).
  - **Flee:** Task 6's flee (to the nearest shelter), the chatter, and `PerceptionService` (`Alarm` on a hit).
- **Produces** (every number is a PROPOSAL):
  - **Health:** townsfolk have 100 MaxHealth and no regeneration while sheltering.
  - **Hurt reaction:** a townsperson hit by a player says a `Hurt` line, then flees to the shelter post that's farthest from the attacker among the 3 nearest shelters. Every other townsperson within 30 studs says a `Help` line (50 % of them) and flees too. Sheltering lasts until 20 s after the last hit or combat noise, as in Task 6.
  - **Knocked:** at 0 health a townsperson is knocked through `DownedManager`, as enemies are. They can be gripped and carried. Left alone for 30 s, they get up with 30 % health and flee to a shelter.
  - **Death:** executed, or killed outright by anything that kills enemies:
    - the killer (the last player to hit, grip or execute within 10 s) records `murder_townsfolk`, witnessed, in this region;
    - the body stays 60 s, then is removed;
    - nobody gets EXP, money, codex entries, quest "Defeat" progress or drops (WorldService skips any victim with a `TownsfolkId`).
  - **The `murder_townsfolk` deed:** `Text = "Killed a townsperson"`, `Standing = {Townsfolk = -15, Authority = -5}`, a Mercy conduct loss like the harshest existing deed, and a crime (Heat) in every jurisdiction. Follow the shape and fields of the existing deeds exactly; the numbers are PROPOSALs.
  - **Newcomers:** at the next 06:00 game time (`WorldClock.Changed` with hour 6), every dead townsperson's slot respawns with the same `Id`, job, faction, nation and schedule, but a new `Name` from `TownsfolkLogic.NewcomerNames[Nation]` (PROPOSAL lists, 8 names per nation, not reused while that name is alive in the region) and a new look seed. The new person greets people as Neutral, the same as everyone. The killer's deed stands.
  - **Gossip:** Task 6's rumour line already includes local deeds (Task 3 ruling), so townsfolk will talk about the killing. Check that `"They say <killer> killed a townsperson."` comes out.

- [ ] **Step 1: Write the failing tests** `Play_TownsfolkHurt.lua`. Use test rosters and fixtures as in `Play_Townsfolk`, with every timer shortened for tests and restored afterwards.
  - **HitIsAssault:** a melee hit from the test player on a townsperson lowers their health and records `assault_townsfolk` once. A second hit within the cooldown doesn't record it again.
  - **HurtFleesAndOthersFlee:** the hit townsperson's state becomes `Fleeing`, toward a shelter away from the attacker, and a second townsperson 15 studs away flees too.
  - **KnockedThenRecovers:** taking the health to 0 makes them knocked (the Downed attributes are set). After the shortened recovery they're up with 30 % health and fleeing.
  - **ExecuteIsMurder:** knock, grip and execute through the real DownedManager path. `murder_townsfolk` is recorded for the test player with witnesses when one is placed, Heat rises in a State region, and there's no EXP or money gain (compare before and after).
  - **NewcomerAtSix:** after a death, hold the clock at 05:59, then at 06:00. The slot respawns with a different `Name` and the same `Id` and job.
  - **Gossip:** after the murder, `Talk` on another townsperson eventually yields a line containing "killed a townsperson".
  - **SweepStillHitsEnemies:** one melee sweep through a townsperson and an enemy damages both, with no errors.
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** Play_TownsfolkHurt, Play_Townsfolk, Play_TownsfolkCrowd, Play_Heat, Play_Morality, Play_Rumours (first), Play_Stealth and a melee combat suite.
- [ ] **Step 5: Commit, with a Changelog entry** for the owner: townsfolk can be hurt; what each act costs (assault, murder); newcomers.

---

### Task 7: Clue points start quests

**Files:**
- Modify: `Scripts/ServerScriptService/InvestigationService.lua`, `Scripts/ReplicatedStorage/Modules/Data/Rensei/Investigation.lua` (document the new field)
- Test: `Scripts/ServerStorage/RenseiTests/Play_Clue.lua`

**Interfaces:**
- **Consumes:**
  - **Inspect points:** a BasePart or Model tagged `RenseiInspect` with attribute `InspectId` gets an "Inspect" prompt (`InvestigationService:71-96`).
  - **Inspect defs:** `{Title, Text, AfterText, Evidence, Requires, Locked}`.
  - `QuestService.CanStart(Player, Id)`, `QuestService.Start(Player, Id)`.
- **Produces:**
  - **Clue markers:** a BasePart tagged `RenseiClue` with attribute `ClueId` is treated as an inspect point with `InspectId = ClueId`. InvestigationService adds the `RenseiInspect` tag and the attribute at Start, and on `GetInstanceAddedSignal("RenseiClue")`.
  - **The `StartsQuest` field:** an inspect def may have `StartsQuest = "<QuestId>"`. After a successful inspect (evidence granted, or AfterText shown), if `QuestService.CanStart(Player, StartsQuest)`, the quest starts.

- [ ] **Step 1: Write the failing test** `Play_Clue.lua`. Inject a test inspect def `test_clue = {Title="Ledger", Text="Lines scratched out.", Evidence="test_ev", StartsQuest="test_clue_quest"}`, a test evidence def, and a one-stage test quest with an `Evidence` objective `test_ev`. Create a part tagged `RenseiClue` with `ClueId="test_clue"` 5 studs in front of the player. Call the inspect handler as the prompt would. Assert the player has the evidence and the quest is active, with that objective already done through CatchUp. Remove all injected defs, the part and the quest state.
- [ ] **Step 2: Run it.** Expected: FAIL.
- [ ] **Step 3: Implement** the clue tag mapping and `StartsQuest`.
- [ ] **Step 4: Run** Play_Clue (PASS 1) and every existing investigation-touching suite (search `RenseiTests` for `InvestigationService`).
- [ ] **Step 5: Commit.**

---

### Task 8: The region file and the pure builder modules

**Files:**
- Create: `Art/Blender/region_builder/__init__.py`, `schema.py`, `heightfield.py`, `merge.py`, `tests/run.py`
- Create: `Art/Regions/Testbed/layout.json`

**Interfaces:**
- **Produces, the region file (`layout.json`):**

```json
{
  "Region": "Testbed", "PlaceId": 0, "Footprint": [256, 256],
  "Palette": {"ground_top": "cinder", "ground_side": "slag", "path": "paving", "quiet": "cinder_dark"},
  "Heights": [
    {"Kind": "plane", "Y": 4},
    {"Kind": "box", "Rect": [-60, -60, -20, -20], "Y": 10, "Edge": 8},
    {"Kind": "ridge", "Line": [[-128, 100], [128, 100]], "Width": 24, "Y": 30},
    {"Kind": "cut", "Rect": [40, -40, 80, -8], "Y": -4},
    {"Kind": "water", "Rect": [60, 40, 100, 80], "Top": 3, "Bed": -6}
  ],
  "Districts": [{"Id": "row", "Poly": [[-110, -110], [-40, -110], [-40, -40], [-110, -40]], "Style": "railtown.house", "Density": 0.6, "Storeys": [2, 3]}],
  "Routes": [
    {"Id": "main", "Kind": "public", "Width": 12, "Line": [[-120, 0], [120, 0]]},
    {"Id": "alley", "Kind": "quiet", "Width": 6, "Line": [[-75, -40], [-75, 0]]},
    {"Id": "climb", "Kind": "public", "Width": 8, "Line": [[-40, -40], [-4, -4]]}
  ],
  "Landmarks": [{"Id": "court", "Kind": "railtown.practice_court", "At": [0, 40], "Yaw": 0}],
  "Markers": [
    {"Tag": "RenseiPost", "At": [10, 0, 20], "Yaw": 90, "Attr": {"PostId": "test_work", "Kind": "Work"}},
    {"Tag": "RenseiPost", "At": [-20, 0, 20], "Yaw": 0, "Attr": {"PostId": "test_shelter", "Kind": "Shelter"}},
    {"Tag": "RenseiClue", "At": [30, 0, 30], "Attr": {"ClueId": "test_clue"}},
    {"Tag": "RenseiArea", "Box": [[-128, -10, -128], [128, 80, 128]], "Attr": {"AreaName": "Testbed"}}
  ],
  "Budget": 12000
}
```

  - Coordinates are studs, with the origin at the footprint's centre: x = east, z = south (spec §3.1).
  - `Y` is the ground height. A marker's `At[1]` (y) of 0 means "on the ground" (snapped by the builder).
  - `Kind` values for routes: `public`, `quiet`, `rail`, `under`, `ledge`, `road`.
- **Produces, the Python API:**
  - `schema.load(path) -> dict`, which raises `SchemaError(list_of_messages)` on any problem;
  - `heightfield.sample(layout, cell=4) -> Grid` with `Grid.top[i][k]: int`, `Grid.kind[i][k]: str` (`"top" | "path" | "quiet" | "water"`), `Grid.water: list[(x0,z0,x1,z1,top,bed)]`, `Grid.origin`, `Grid.cell`;
  - `heightfield.columns(grid) -> list[(i, k, top, bottom, kind)]`, where `bottom = min(top-2, min(neighbour tops)-1)`, as `ground.lua` does;
  - `heightfield.ramps(grid, layout) -> set[(i,k)]`: route cells whose corner heights differ by more than 0.6 studs;
  - `merge.rects(cells: dict[(i,k)] -> key, max_span=40) -> list[(i0, k0, w, d, key)]`, a greedy merge of equal keys (as `ground.lua` does).

- [ ] **Step 1: Write the failing tests** `tests/run.py`. These are plain asserts; the script exits 1 on any failure and prints `PASS n / FAIL n`.
  - **schema:**
    - the Testbed file loads;
    - a file missing `Footprint` raises `SchemaError`;
    - a marker with an unknown `Tag` raises;
    - a route with fewer than 2 points raises;
    - a district polygon outside the footprint raises.
  - **heightfield:**
    - the plane gives top 4 everywhere outside the other shapes;
    - the box gives 10 inside, with a smooth step down over `Edge` (8 studs);
    - the ridge gives 30 at its line and falls off over `Width`;
    - the cut gives -4;
    - water cells are `kind == "water"` with their top and bed recorded;
    - route cells are `path` (public) or `quiet`;
    - a 1-stud step everywhere: `top` is an integer.
  - **columns:** every column's bottom is at least 1 below each neighbour's top.
  - **ramps:** the `climb` route (rising from 4 to 10) yields at least 1 ramp cell, and the flat `main` route yields none.
  - **merge:** a 10×10 block of one key merges into 1 rect; a checkerboard of two keys gives 100 rects; `max_span=4` on a 10×1 strip gives 3 rects.
- [ ] **Step 2: Run** `python -I Art/Blender/region_builder/tests/run.py`. Expected: FAIL (modules missing).
- [ ] **Step 3: Implement** the three modules: no `bpy`, no third-party imports.
  - **Shapes, in order (later wins):** plane sets Y; box sets Y inside, blending linearly over `Edge` outside; ridge raises to Y at distance 0 from the polyline, falling linearly to the base at `Width`; cut lowers to Y inside; water sets the bed and records the water box.
  - Then round to integers.
  - **Route cells:** a cell whose centre is within `Width/2` of the route polyline.
  - **The merge:** `ground.lua`'s greedy approach. Scan rows, extend the width while the key matches, then extend the depth while the whole row matches, up to `max_span`.
- [ ] **Step 4: Run the tests.** Expected: PASS (all).
- [ ] **Step 5: Commit** (the `.py` files and `Art/Regions/Testbed/layout.json`).

---

### Task 9: The Blender stages: ground, routes, markers, budget, renders

**Files:**
- Create: `Art/Blender/region_builder/materials.py`, `stages.py`, `build.py`
- Modify: `Art/Blender/lindenmoor/export.py`: export `rs_tags` as row field 16; make `origin` a parameter with today's default; skip nothing new

**Interfaces:**
- **Consumes:**
  - `lindenmoor.core`: `reset_scene()`, `coll(name)`, `box(name, size, loc, mat, c, rot, bevel, segs, chip, seed)`, `flat(name, color, ...)`, `srgb(hex)`;
  - the prefab convention: an Empty with `rs_prefab=kind` and `rs_id`, its parts parented, its collection name = the Roblox group;
  - the part properties `rs_kind`, `rs_size`, `rs_mat`, `rs_invisible`, `rs_attr` (JSON string).
- **Produces:**
  - **New part property `rs_tags`:** a comma-separated string of CollectionService tags. It travels as export row field 16 (the 16th element, after attr JSON; an empty string if there are none).
  - `materials.palette(layout) -> dict[key -> bpy material]`, with Blender material names `RG_<Region>_<key>`, and `materials.write_table(layout, path)`, which writes `materials.json`: `{ "<blender material name>": {"Material": "<Enum.Material name>", "Color": "<hex>", "Transparency": 0} }`. Base keys and their Roblox material + colour for the rail-town palette (from the brief: soot, iron, furnace brick, ember):

    | Key | Roblox material | Colour (PROPOSAL) |
    |---|---|---|
    | cinder | Ground | 4a4642 |
    | cinder_dark | Ground | 3a3633 |
    | slag | Slate | 2f2b29 |
    | paving | Cobblestone | 5c5853 |
    | brick | Brick | 7a3e2e |
    | brick_dark | Brick | 5e2f24 |
    | iron | Metal | 3d4247 |
    | timber | WoodPlanks | 5a4636 |
    | glass_warm | Glass (0.3) | 3a2a1c |
    | ember | Neon | e0782a |
    | lamp | Neon | ffb35c |

  - **Texture-pack images (owner, 2026-10-23):** a `Palette` value may be an object instead of a key, `{"Key": "brick", "Pack": "<pack item name>"}`, which names a block in `Art/Regions/texture_pack.json`. `materials.write_table` then adds `"PackImage": "rbxassetid://<I>"` and `"StudsPerTile": <U>` to that material's entry. The Blender material stays the flat palette colour, because Blender can't load Roblox images.
  - `stages.ground(layout, grid)`: one prefab per 64×64-stud tile (group `Ground`). It holds merged `Top` slabs (1 stud thick), `Side` blocks (from `top-1` down to `bottom`) and ramps (tilted 1.2-thick slabs over a side block, `ground.lua` style).
  - `stages.routes(layout, grid)`: paving and kerb strips on public routes (`paving`), cinder lanes on quiet routes, rails on `rail` routes, stairs where a route climbs more than 4 studs over 8 studs. Group `Routes`.
  - `stages.markers(layout, grid)`: one invisible, non-colliding 2×2×2 part per point marker (or the box size for `Box` markers), with `rs_invisible=True`, `rs_tags=<Tag>`, `rs_attr=json(Attr)`, and the yaw applied. Group `Markers`.
  - `stages.lighting(layout)` and `stages.render(layout, out_dir)`: an aerial view plus one street-level view per district and landmark (EEVEE, 1920×1080), saved as PNGs to `Documents/images/Regions/<Region>/`.
  - `build.run(region, stages="all") -> {"objects": n, "parts": n, "budget": b, "over": bool, "renders": [paths]}`, which reads `Art/Regions/<Region>/layout.json` and saves `Art/Blender/Regions/<Region>.blend`. Over budget, it returns `over=True`, and `export` must not be run.
  - Roblox water: the builder records water boxes in `Art/Regions/<Region>/water.json`, built from the cells that are still water (`Grid.water_of[i][k]`, merged with `merge.rects`), not the whole Rect, so no water is filled under ground a later shape raised; the Studio setup fills them with terrain water (SwimService reads terrain water).

- [ ] **Step 1: Write the failing check.** Add a Blender-side test script `Art/Blender/region_builder/tests/blender_check.py`, run through `blender_mcpc.py code @...`. It runs `build.run("Testbed", "ground,routes,markers")` and sets `result` to a JSON string with:
  - the Ground part count;
  - the number of objects with `rs_tags` containing `RenseiPost` (expected 2), `RenseiClue` (1) and `RenseiArea` (1);
  - whether every Top slab's top face is at an integer height;
  - `over` (expected false).

  It also checks that `export.py` (run with `out_path` in a temp folder) writes rows with field 16 = the tags for the marker parts.
- [ ] **Step 2: Run it.** Expected: an error (no `regions` package stages).
- [ ] **Step 3: Implement** `materials.py`, `stages.py` (ground, routes, markers, lighting, render) and `build.py`.
  - Put `Art/Blender` on `sys.path` and import `lindenmoor.core` for the primitives, but give the region scene its own name (`Region_<Region>`). Never reuse `Lindenmoor_Full`.
  - Extend `export.py` so that `export(scene_name, out_path, origin=(0,4,-650))` appends `rs_tags` as field 16 when present. Run Lindenmoor's export once to a temp path and check that its output is unchanged (byte-compare against a fresh export made before the change).
- [ ] **Step 4: Run** `blender_check.py` and `tests/run.py`. Expected: PASS. Render the Testbed and look at it: an aerial and one street view in `Documents/images/Regions/Testbed/`.
- [ ] **Step 5: Commit** (the `.py` files and renders; never a `.blend`).

---

### Task 10: The rail-town style kit: buildings, landmarks, cover, edges

**Files:**
- Create: `Art/Blender/region_builder/kits/__init__.py`, `Art/Blender/region_builder/kits/railtown.py`
- Modify: `Art/Blender/region_builder/stages.py` (add the buildings, landmarks, cover and edges stages)

**Interfaces:**
- **Consumes:** the Task 9 primitives and materials. Districts give `Style`, `Density` and `Storeys`; landmarks give `Kind`, `At` and `Yaw`.
- **Produces:**
  - **Style functions**, each `(root, rng, w, d, storeys) -> parts`, building a prefab at the origin:
    - `railtown.house`: a brick terrace house with a slate or iron roof, chimney, warm windows and a back door;
    - `railtown.boarding`: a long 3-storey boarding house;
    - `railtown.shed`: a corrugated iron shed;
    - `railtown.warehouse`: a brick warehouse with loading doors;
    - `railtown.stack`: a smokestack.
  - **Landmark functions**, each `(root, rng) -> parts`:
    - `railtown.practice_court`: a walled ring, about 40 studs across, with benches;
    - `railtown.foundry_hall`: a big brick hall with a sawtooth roof, furnace openings with ember glow, internal gantries and an open floor;
    - `railtown.crane_bay`: a gantry crane frame with climbable legs and a walkable girder;
    - `railtown.rail_walk`: a raised iron walkway on trestles;
    - `railtown.underworks`: a tunnel section with an arched brick roof, dim, used along `under` routes;
    - `railtown.canteen` and `railtown.market_stall`.
  - **The buildings stage:**
    - fills each district polygon with style buildings along its route frontage;
    - spacing comes from `Density` (PROPOSAL: frontage coverage = Density);
    - buildings face the nearest route;
    - alley gaps of at least 4 studs every 2–3 buildings;
    - no building within 2 studs of a route edge or a marker;
    - each building sits at the ground height under its footprint, with a plinth down to the lowest corner.
  - **The cover stage:** crate stacks and machinery along quiet routes and yards (PROPOSAL 1 cluster per 20 studs of quiet route).
  - **Traversal tags:** ledges and climbable or wall-run faces are tagged as the movement code expects. Read the movement code first: find what `RenseiLedge` needs (the tag plus any attributes, see `GorgeLedge` in Ye) and what makes a surface climbable or wall-runnable. Tag the crane legs, rail-walk sides and building ledges accordingly through `rs_tags` and `rs_attr`.
  - **The edges stage:** slag ridges around the footprint edge, at least 24 studs tall (PROPOSAL), broken only where an `Edge`-gap marker sits (`{"Tag":"EdgeGap", "Box":[...]}`, consumed by the builder and not exported).
  - **Street lamps** carry `rs_attr` `{"NightOnly": true}` and a light (they pair with the WorldClock lamp rule).

- [ ] **Step 1: Write the failing check.** Extend `blender_check.py` with `build.run("Testbed", "all")`. Assert:
  - the `row` district holds 3 or more buildings;
  - no building's footprint overlaps a route's corridor;
  - the practice court exists;
  - at least one object carries the ledge tag;
  - lamps carry `NightOnly`;
  - the total parts are within budget.
- [ ] **Step 2: Run it.** Expected: FAIL.
- [ ] **Step 3: Implement** the kit and the stages.
  - Use only built-in primitives through `core.box` and `core.cyl` (wedges via `world.wedge`'s pattern) and the region materials.
  - Keep each building under about 150 parts (PROPOSAL).
- [ ] **Step 4: Run the check.** Then render the Testbed: an aerial plus a street view of the row and the court. Look at the renders: buildings sit on the ground, face the street, and leave alleys.
- [ ] **Step 5: Commit** (code and renders).

---

### Task 11: Export and import into any place, with a dry run

**Files:**
- Modify: `Art/Studio/Lindenmoor/studio_kit.py`
- Create: `Art/Studio/Regions/finish_region.lua.tmpl`, `Art/Studio/Regions/kit.py` (a thin wrapper calling `studio_kit` with region arguments)

**Interfaces:**
- **Consumes:** `layout.json` from `export.py` (Task 9's field 16) and `materials.json`.
- **Produces:**
  - `python -I Art/Studio/Regions/kit.py <Region>` writes, in `Art/Studio/Regions/<Region>/`:
    - `import/chunk_NN.lua`;
    - `import/expected.json`;
    - `import/finish.lua`, generated from the template with the region name, place id, date and expected counts filled in.
  - Chunks build into `ServerStorage.RegionStaging/<group>/<kind>_<id>`.
  - **Tags:** field 16 tags are added with `CollectionService:AddTag`.
  - Every model gets attribute `RegionKit = <Region>`, not `LindenmoorKit`; Lindenmoor's own run keeps `LindenmoorKit`.
  - **Materials:** they come from `materials.json` when present, otherwise from the built-in table.
  - **Pack images:** for each `materials.json` entry with `PackImage`, the first chunk ensures a `MaterialVariant` named `RG_<Region>_<key>` exists in `MaterialService`, with `BaseMaterial` = the entry's material, `ColorMap` = `PackImage` and `StudsPerTile` = the entry's value. Parts of that material get `MaterialVariant = "RG_<Region>_<key>"`.
    - `finish.lua` backs up any existing variants it replaces.
    - The dry run checks that every expected variant exists.
    - The Testbed uses one pack image (Ceiling C) to prove this.
  - **`finish.lua`:**
    - with the attribute `DryRun = true` on `ServerStorage.RegionStaging`: checks counts and tags against `expected.json`, then destroys the staging folder, and returns `"dry run ok: …"`;
    - otherwise:
      - refuses if `ServerStorage.RenseiBackups["Pre-Region_<Region>_<date>"]` exists;
      - creates that backup and moves the current `workspace.World.Map` children into it (except any listed in a `KEEP` table, empty by default);
      - parents the staged groups under `workspace.World.Map.<Region>`;
      - fills terrain water from `water.json` (`Terrain:FillBlock` with `Enum.Material.Water`);
      - returns a summary.
  - `studio_kit.py` keeps its old command-line behaviour for `Art/Studio/Lindenmoor` and `Art/Studio/Train`. The new arguments are optional.

- [ ] **Step 1: Write the failing check.** Run `kit.py Testbed`, then run the chunks and a dry-run finish in **Foundry** (`placeId: 109591196441030`, Edit), setting `DryRun = true` on the staging folder before running `finish.lua`. Expected now: `kit.py` fails (no wrapper).
- [ ] **Step 2: Implement** the wrapper, the `studio_kit.py` arguments and the template.
- [ ] **Step 3: Run the dry run in Foundry.** Expected: `"dry run ok"`, counts equal to `expected.json`, the tags present (2 `RenseiPost`, 1 `RenseiClue`, 1 `RenseiArea`), and nothing changed in Foundry's `workspace` (compare the `World.Map` child count before and after). Then re-run `python -I Art/Studio/Lindenmoor/studio_kit.py` and diff its outputs against the committed ones: unchanged.
- [ ] **Step 4: Commit.**

---

### Task 12: Travel pieces from markers

**Files:**
- Create: `Art/Studio/Regions/travel_pieces.lua`, `Art/Studio/Regions/setup.lua`, `Art/Studio/Regions/Test_SetupContract.lua`

**Interfaces:**
- **Consumes:**
  - the builders in `Art/Studio/Travel/station_foundry.lua`: `part` :67, `arrival` :89, `blockRide` :118, `lay` :145, `booth` :167, `board` :213, `roadGate` :236, `kitPart` :276, `kitPiece` :287, `Decor` :319, `Passage` :337, `T9Part` :726, `T9Npc` :736, `PapersGate` :759, `FreightYard` :793, `Railing` :885, with their data tables ORDER/LEN, KITDATA, PTOP/PSIDE/ROAD_HALF/VERGE and T9_*;
  - `ServerStorage.TrainKit` (the seven `*_Main` cars).
- **The travel contract**, which the built pieces must satisfy (from the services):
  - **Trains:** a `RenseiPlatformTrain` / `RenseiRideTrain` Model with attrs `Route` and `Length=440`. WorldPivot = nose at rail top, identity rotation; the train runs along −Z of the pivot. Cars are direct child Models.
    - Inside: `CarKind` descendants, `BoardZone*` and `CarDoor*` parts with `CarKind`, and a `StowZone`.
    - The platform must be on the track's +X side (the baggage door and StowZone face −X).
    - The ride train sits at platform pivot + (0, 400, −1600).
  - **Station pieces:**
    - `RenseiTicketClerk` BasePart;
    - `RenseiDepartureBoard` BasePart, with its Front face readable from the hall;
    - `RenseiStationGate`: 8×8×1, CanTouch true, LookVector onto the platform, optional `Route`.
  - **Freight yard:** `RenseiFreightYard` zone, with the `YardWatchman` (`RenseiWatcher`) under the same parent model.
  - **Arrivals:** `RenseiArrival` with `Point` `"Platform"` and `"RoadStart"`; exactly one each per place. LookVector points inward.
  - **Road passage:**
    - `RenseiRoadPassage` leg boxes with `Route`, `To`, `RoadName` and `Leg` (1 = mouth). Leg 1 must not overlap other legs near the mouth (the walk starts only in leg 1 alone).
    - `RoadPoint` attachments with `S`.
    - `RenseiRoadThreshold` with `Route`, `To`, LookVector out.
    - `RenseiRoadEncounter` with `Route`, `Order` and `SpawnPoint` attachments (`Side` "Out"/"In"); local +Z = town side.
  - **Areas:** `RenseiArea` with `AreaName`.
- **Produces:**
  - `travel_pieces.lua`: a ModuleScript source returning the builders above, parameterized. The Foundry-only constants become arguments (origins, sizes, route ids, names, the kit source). Behaviour and output are otherwise unchanged.
  - **Marker conventions** in the region file (`Markers`, Tag `RenseiMarker`, attribute `Piece`):

    | Piece | Attributes | Builds |
    |---|---|---|
    | `Station` | `Route`, `TrackX`, `RailTop`, `NoseZ`, `PlatformSide` (+1) | rails, platform, buffer stops, both trains, the `Platform` arrival |
    | `Clerk` | `Station` | the booth, facing the marker's LookVector |
    | `Board` | | the departure board |
    | `Gate` | `Route` | the gate, ramp, posts, sign and guard |
    | `Railing` | `Runs` (JSON `[[x1,z1,x2,z2],…]`), `WallTop` | the platform railing |
    | `FreightYard` | | built beside the platform train's baggage car |
    | `RoadPassage` | `Route`, `To`, `RoadName`, `Legs` (JSON, the `Passage` leg format), `Threshold`, `RoadStart`, `Encounters` (JSON), `Half`, `RoadY`, `Seed` | the passage and its pieces |

  - `setup.lua`:
    - reads every `RenseiMarker` under `workspace.World.Map.<Region>` (or under a root given by `ServerStorage.RegionSetupRoot` for tests);
    - builds each piece into `workspace.World.Map.<Region>.Travel`;
    - is idempotent: it destroys and rebuilds `Travel`, backing up a first-ever existing `Travel` to `RenseiBackups["Pre-RegionSetup_<Region>"]`;
    - returns a summary.
  - `Test_SetupContract.lua`: given a root, checks every contract rule above and returns `"PASS n / FAIL n"` with messages.

- [ ] **Step 1: Write the contract test first.** `Test_SetupContract` takes `ROOT` and checks each rule in the contract list above as one named check.
- [ ] **Step 2: Build a synthetic marker set in Foundry, in Edit.** Create `ServerStorage.RegionSetupRoot` (a Model) holding `RenseiMarker` parts: one `Station`, `Clerk`, `Board`, `Gate`, `Railing`, `FreightYard` and `RoadPassage`. Use today's Foundry values from `station_foundry.lua:77-80`, `:211`, `:227`, `:925-954` and `:677-695`, so the result can be compared with today's build. Run `Test_SetupContract` on the empty root. Expected: FAIL (nothing built).
- [ ] **Step 3: Implement** `travel_pieces.lua` by extracting the functions, and `setup.lua`. Building under `RegionSetupRoot` in ServerStorage must not touch `workspace`.
- [ ] **Step 4: Run** setup on the synthetic root, then `Test_SetupContract`. Expected: all pass. Then compare the built pieces with Foundry's live ones (part counts per piece, gate, booth and arrival CFrames): equal within 0.01 studs. Remove `RegionSetupRoot`. Foundry's live map must be untouched.
- [ ] **Step 5: Commit.**

---

### Task 13: Docs, changelog and hand-over

**Files:**
- Create: `Documents/Region Builder.md`, a how-to:
  - the region file format with every key;
  - running the builder, renders, export, import (dry run first), then setup;
  - the marker table;
  - the townsfolk roster format;
  - the clue format;
  - the clock.
- Modify: `Documents/Changelog.md` (one entry for the foundation, with the owner-facing changes: the day cycle, trainer exams fixed, townsfolk ready for regions); `Documents/Lindenmoor Kit.md` (a note that `export.py` and `studio_kit.py` gained optional arguments)

- [ ] **Step 1: Write the docs.**
- [ ] **Step 2: Run every suite once more in Ye** (hooked): Boot, Travel, Station, Road, Gate, RideEvents, Arrive, Exams, Clock, Townsfolk, Clue, Stealth, Heat, Morality and Rumours (Rumours first), plus Edit `Test_TownsfolkLogic` and `tests/run.py`. Record the results in the changelog entry.
- [ ] **Step 3: Commit.** The controller pushes and republishes the status page.

---

## Self-review notes

- **Spec coverage:**
  - §3.1 the region file: Task 8.
  - §3.2 the builder stages: Tasks 8–10 (ground, routes, buildings, landmarks, cover and traversal, edges, markers, renders).
  - §3.3 style kits: Task 10 (rail town only; other kits come with their regions).
  - §3.4 markers and tags: Tasks 9 and 12.
  - §3.5 export, import and setup: Tasks 9, 11 and 12.
  - §3.6 the budget: Tasks 9 and 11.
  - §4 the clock: Task 2.
  - §5 townsfolk: Tasks 3–6.
  - §6 clues and exams: Tasks 1 and 7.
  - §7 Foundry and §9's region checks: the Foundry plan.
- **Deferred to the Foundry plan:** Foundry's `layout.json`; its renders for owner approval; the import and setup in Foundry; the travel suites in the new town; moving Brannoc and the forge rooms; Foundry's roster and the shift-ledger quest; the performance check with 25 townsfolk.
- **Types used across tasks:**
  - `PostId`/`Kind` on `RenseiPost`;
  - `ClueId` on `RenseiClue`;
  - `rs_tags` → row field 16 → CollectionService tags;
  - `TownsfolkService.Step(Hour?)`, `Talk(Player, Id)`, `State(Id)`;
  - `WorldClock.Hour/Hold/Release/IsNight/Changed`;
  - `RumourService.HeardIn(Region, N)`;
  - `NoiseService.Listen(Fn)`.

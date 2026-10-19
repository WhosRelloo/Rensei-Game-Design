# Plan 1 — Foundation: Regions, Place Standing, Perception, Witnesses, Rumours — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deeds stop changing Standing everywhere at once. A deed is heard where it happened, by whoever really perceived it, and word of it travels a graph of regions over real time (online and offline), while enemies notice players through sight and alert phases instead of distance aggro.

**Architecture:**
- **Data.** Three new shared data/maths modules: `Rensei.Regions` (the place graph), `Rensei.Reputation` (place-by-place standing) and `Rensei.Perception` (awareness numbers and pure maths).
- **Services.** Three new server services:
  - `PerceptionService`: per-NPC awareness and phases;
  - `WitnessService`: who saw a deed;
  - `RumourService`: a pure `Core` plus the 60 s tick.
- **The existing ledger.** `MoralityService` keeps its role as the only writer of `Morality`. Its `Standing` and `Renown` become caches computed from where deeds have been heard.

**Tech Stack:** Roblox Luau in Roblox Studio, edited through the Roblox Studio MCP (`execute_luau`, `script_read`, `start_stop_play`). Docs and script mirror live in the git repo `C:/Users/Owner/Rensei-Game-Design` (GitHub `WhosRelloo/Rensei-Game-Design`).

**Spec:** `Documents/specs/2026-10-19-morality-reputation-consequences-design.md`: §2–§5 and §13 (R1, R2); §17.1, §17.2, §17.10 (S1).

## Global Constraints

- **Numbers:** every number is a **PROPOSAL** and is labelled so in code comments.
- **New content:** every faction, place or title that's new is marked **(new)** and needs the owner's OK. Here that means the six communities (placeholder names from spec §11) and the region `Wilds`.
- **No removals:** no existing mechanic is removed. The old distance aggro stays for arena and trial foes (`Perception.AlwaysAware`).
- **Studio places:**
  - Rensei (Ye) `ad3d28a3-6ed6-4f17-99ba-abd3816ae40e`;
  - Tutorial `1489f891-2ba2-416e-8b99-1757c2a0b4cb`;
  - Main Menu `79c17fd7-1605-4b18-97ac-80fe6d4be692`.
  - Never touch the window titled "bloodydeadpool53's Place".
- **Shared files:** `ProfileMigrations` and `ProfileData` must stay **byte-identical in all three places** (check with the FNV hash in Conventions §H).
- **Players' data:**
  - Studio Play writes the tester's **real** profile, so every Play test snapshots `Data.Morality` first and restores it after (Conventions §S);
  - never publish the game;
  - never touch other players' data.
- **Backups:** before editing any existing script, clone it into `ServerStorage.RenseiBackups["Pre-Foundation_2026-10-19"]` (Conventions §B).
- **Code style:** match the codebase:
  - PascalCase locals and functions, tabs;
  - a header comment explaining the module, comments that say *why*;
  - the services' `X.Start()` pattern;
  - server-only writes.
- **Collaboration:** another collaborator's sessions edit the same places and repo. `git pull --rebase` before every commit. On a conflict, keep the most recent Studio-verified export.
- **Commits** end with:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01Qw6G3HMsnCaMFq4vZWvFZE
  ```
- **Changelog:** every task's commit adds or extends the `Documents/Changelog.md` entry "2026-10-xx — Plan 1: Foundation" (newest first).

## Conventions (read once; tasks refer to these by letter)

### §T: running tests

- **The kit.** Test modules live in `ServerStorage.RenseiTests` (Rensei place). Each returns `{[TestName] = function(T) ... end}` and is run by `TestKit` (Task 1).
- **Edit-mode run (pure modules).** Call `execute_luau` with `datamodel_type = "Edit"`:
  ```lua
  local Kit = require(game.ServerStorage.RenseiTests.TestKit)
  return (Kit.Run(require(game.ServerStorage.RenseiTests.Test_Regions)))
  ```
  `execute_luau` runs in a separate sandbox VM: `require` gives fresh copies of the modules. That's fine for pure modules. **Never** require a service (`ProgressionService`, `MoralityService`, ...) in Edit mode.
- **Play-mode run (services).** Start Play with `start_stop_play(true)`. Then, with `execute_luau` and `datamodel_type = "Server"`, create a runtime `Script` in `ServerScriptService` whose `Source` runs the test inside the **game VM** and writes its result to `workspace:SetAttribute("TestResult", Text)`. Poll that attribute from a second `execute_luau` call. Stop Play with `start_stop_play(false)`.
  - If Play start hangs ("Start play hasn't finished yet"), stop that background task and retry once.
- **Edits need Edit mode:** script edits are refused while Play is running.

### §S: profile snapshot and restore (inside a Play-mode test Script)

```lua
local HttpService = game:GetService("HttpService")
local ProgressionService = require(game.ServerScriptService.ProgressionService)
local Player = game.Players:GetPlayers()[1] or game.Players.PlayerAdded:Wait()
local Data
repeat Data = ProgressionService.GetData(Player); task.wait(0.5) until Data
local Snapshot = HttpService:JSONEncode(Data.Morality)
-- ... the test ...
Data.Morality = HttpService:JSONDecode(Snapshot)
require(game.ServerScriptService.MoralityService).Refresh(Player) -- (Refresh exists from Task 5 on; before that use .Rebuild(Data))
```

### §B: backup before editing an existing script

```lua
local B = game.ServerStorage.RenseiBackups
local F = B:FindFirstChild("Pre-Foundation_2026-10-19") or Instance.new("Folder")
F.Name = "Pre-Foundation_2026-10-19"; F.Parent = B
local function Backup(S)
	local Name = S:GetFullName():gsub("%.", "_")
	if F:FindFirstChild(Name) then return end
	local C = S:Clone(); C.Name = Name
	for _, K in ipairs(C:GetChildren()) do K:Destroy() end
	C.Parent = F
end
```

### §E: export to the repo (Studio is the source of truth)

1. **New files.** Fetch the script's source hex-encoded and padded, so the tool result is saved to a file:
   ```lua
   local S = <the script>.Source
   local Hex = S:gsub(".", function(C) return string.format("%02x", C:byte()) end)
   local Out = "BEGIN" .. Hex .. "END"
   return Out .. string.rep("z", 66000 - #Out)
   ```
   If a source is over about 32 KB, split it into parts.
2. **Decode it** with `python -I C:/Users/Owner/.claude/jobs/0c39df78/tmp/dehex_animate.py <saved result file> <repo path>`. Repo paths mirror Studio:
   - `Scripts/ServerScriptService/<Name>.lua`;
   - `Scripts/ReplicatedStorage/Modules/Data/Rensei/<Name>.lua`;
   - `Scripts/ServerStorage/RenseiTests/<Name>.lua`;
   - Tutorial: `Scripts/Tutorial/ServerScriptService/...`;
   - Main Menu: `Scripts/MainMenu/...`.
3. **Changed files.** Use the chunk mirror `C:/Users/Owner/.claude/jobs/0c39df78/tmp/chunksync.py`:
   1. compute chunk hashes in Studio (§H);
   2. `need`;
   3. fetch only the missing chunks as `@@@@ <path> <index>\n<chunk>\n` batches, hex-padded;
   4. `buildb` with a hashes file whose values are each file's hashes **concatenated into one string**.
4. **Verify:** the script prints `checked N chunks, 0 bad`.

### §H: exact FNV-1a in Luau (Luau numbers are doubles; this split keeps the multiply exact)

```lua
local function Fnv(S)
	local H = 2166136261
	for I = 1, #S do
		H = bit32.bxor(H, S:byte(I))
		H = (bit32.lshift(H, 24) + H * 403) % 4294967296
	end
	return string.format("%08x", H)
end
```

### §C: commit

```bash
cd /c/Users/Owner/Rensei-Game-Design && git add -A Scripts Documents && git commit -q -F - <<'EOF'
<message>

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Qw6G3HMsnCaMFq4vZWvFZE
EOF
git pull --rebase -q && git push -q && git log --oneline -1
```

## File structure

| File (Studio path) | New / Modify | Responsibility |
|---|---|---|
| `ServerStorage.RenseiTests.TestKit` | New | tiny assertion runner |
| `ServerStorage.RenseiTests.Test_*` | New | one test module per unit |
| `ServerScriptService.ProfileMigrations` (×3 places) | Modify | step `[4]` → schema 5 |
| `ReplicatedStorage.Modules.Data.ProfileData` (×3 places) | Modify | `SchemaVersion = 5`; template `Morality.Places/Rumours/Heat/News`, `Licence` |
| `ReplicatedStorage.Modules.Data.Rensei.Regions` | New | the region graph, carriers, area → region |
| `ReplicatedStorage.Modules.Data.Rensei.Factions` | Modify | the six communities (new, placeholder names) |
| `ReplicatedStorage.Modules.Data.Rensei.Deeds` | Modify | `born_<Origin>` deeds |
| `ReplicatedStorage.Modules.Data.Rensei.Reputation` | New | landing deeds in regions; place and global standing; renown; schema-5 seeding |
| `ServerScriptService.MoralityService` | Modify | standing from places; origin landing; birth deeds; `Recorded` listeners; `Refresh` |
| `ReplicatedStorage.Modules.Data.Rensei.Perception` | New | perception numbers and pure maths |
| `ServerScriptService.PerceptionService` | New | awareness, phases, `Target` / `Goal` / `Perceived` / `Noise` / `Alarm` |
| `ServerScriptService.EnemyService` | Modify | register enemies; targets through perception; investigate / search walking |
| `ServerScriptService.WitnessService` | New | capture witnesses, strength, player-witness memory |
| `ServerScriptService.RumourService` + child `Core` | New | rumour spread (pure Core) + tick, catch-up, reports |
| `ServerScriptService.ServerHandler` | Modify | start PerceptionService and RumourService |

---

### Task 1: Test kit

**Files:**
- Create: `ServerStorage.RenseiTests.TestKit` (ModuleScript) and `ServerStorage.RenseiTests.Test_TestKit`.

**Interfaces:**
- Produces: `TestKit.Run(Suite) -> (Text: string, Ok: boolean)`. `Text` starts with `PASS n / FAIL n`, then one `FAIL <name>: <error>` line per failure. Each test gets `T` with:
  - `T.Eq(A, B, Msg)`;
  - `T.Near(A, B, Eps, Msg)`;
  - `T.True(V, Msg)`;
  - `T.Same(A, B, Msg)` (deep equality of plain tables).

- [ ] **Step 1: Create the folder and the failing self-test.** Use `execute_luau`, Edit:

```lua
local F = game.ServerStorage:FindFirstChild("RenseiTests") or Instance.new("Folder")
F.Name = "RenseiTests"; F.Parent = game.ServerStorage
local T = Instance.new("ModuleScript"); T.Name = "Test_TestKit"
T.Source = [==[
return {
	EqPasses = function(T) T.Eq(1 + 1, 2) end,
	NearPasses = function(T) T.Near(0.1 + 0.2, 0.3, 1e-9) end,
	SamePasses = function(T) T.Same({A = {1, 2}, B = "x"}, {B = "x", A = {1, 2}}) end,
	SameCatchesDifference = function(T)
		local Ok = pcall(T.Same, {A = 1}, {A = 2})
		T.True(not Ok, "Same should fail on a difference")
	end,
}
]==]
T.Parent = F
return "ok"
```

- [ ] **Step 2: Run it and confirm it fails.** Run (§T) `require(game.ServerStorage.RenseiTests.TestKit)`. Expected: an error, `TestKit is not a valid member of Folder`.

- [ ] **Step 3: Write TestKit.** Use `execute_luau`, Edit:

```lua
local K = Instance.new("ModuleScript"); K.Name = "TestKit"
K.Source = [==[
-- TestKit (2026-10-19): a tiny assertion runner for Rensei's Studio tests (ServerStorage.RenseiTests).
-- A test module returns {[Name] = function(T) ... end}. Run() calls each test, sorted by name, and returns
-- "PASS n / FAIL n" plus one line per failure, and whether everything passed. Pure modules run in Edit mode
-- through execute_luau; services run inside a Play-mode Script (they need the game VM).
local TestKit = {}

local function Same(A, B, Path)
	if type(A) ~= type(B) then return false, Path .. ": " .. type(A) .. " vs " .. type(B) end
	if type(A) ~= "table" then
		if A ~= B then return false, Path .. ": " .. tostring(A) .. " vs " .. tostring(B) end
		return true
	end
	for K, V in pairs(A) do
		local Ok, Why = Same(V, B[K], Path .. "." .. tostring(K))
		if not Ok then return false, Why end
	end
	for K in pairs(B) do
		if A[K] == nil then return false, Path .. "." .. tostring(K) .. ": missing" end
	end
	return true
end

function TestKit.Run(Suite)
	local Names = {}
	for Name in pairs(Suite) do table.insert(Names, Name) end
	table.sort(Names)
	local Lines, Pass, Fail = {}, 0, 0
	for _, Name in ipairs(Names) do
		local T = {}
		function T.Eq(A, B, Msg)
			if A ~= B then error((Msg and Msg .. ": " or "") .. "expected " .. tostring(B) .. ", got " .. tostring(A), 2) end
		end
		function T.Near(A, B, Eps, Msg)
			if type(A) ~= "number" or math.abs(A - B) > (Eps or 1e-6) then
				error((Msg and Msg .. ": " or "") .. "expected ~" .. tostring(B) .. ", got " .. tostring(A), 2)
			end
		end
		function T.True(V, Msg) if not V then error(Msg or "expected true", 2) end end
		function T.Same(A, B, Msg)
			local Ok, Why = Same(A, B, "")
			if not Ok then error((Msg and Msg .. ": " or "") .. Why, 2) end
		end
		local Ok, Err = pcall(Suite[Name], T)
		if Ok then Pass += 1 else Fail += 1; table.insert(Lines, "FAIL " .. Name .. ": " .. tostring(Err)) end
	end
	table.insert(Lines, 1, string.format("PASS %d / FAIL %d", Pass, Fail))
	return table.concat(Lines, "\n"), Fail == 0
end

return TestKit
]==]
K.Parent = game.ServerStorage.RenseiTests
return "ok"
```

- [ ] **Step 4: Run the self-test.** Run (§T) `Test_TestKit`. Expected: `PASS 4 / FAIL 0`.

- [ ] **Step 5: Export and commit.** Export (§E) `TestKit` and `Test_TestKit` to `Scripts/ServerStorage/RenseiTests/`. Commit (§C): `Add TestKit for Studio tests`.

---

### Task 2: Schema 5 (all three places)

**Files:**
- Modify: `ServerScriptService.ProfileMigrations`: add step `[4]` (Rensei, Tutorial, Main Menu).
- Modify: `ReplicatedStorage.Modules.Data.ProfileData`: the `SchemaVersion` line, the `Morality` block and the new `Licence` block (all three places).
- Test: `ServerStorage.RenseiTests.Test_Schema5` (Rensei).

**Interfaces:**
- Produces, for any loaded profile:
  - `Data.SchemaVersion == 5`;
  - `Data.Morality.Places`, `.Rumours`, `.Heat`, `.News` are tables;
  - `Data.Licence = {Path = "", Since = 0, Orders = {}, Refused = {}, Revoked = 0}`.

- [ ] **Step 1: Write the failing test** (Rensei, Edit):

```lua
local T = Instance.new("ModuleScript"); T.Name = "Test_Schema5"
T.Source = [==[
local Migrations = require(game.ServerScriptService.ProfileMigrations)
return {
	FourToFive = function(T)
		local Data = {SchemaVersion = 4, Morality = {Deeds = {reported_lise = {At = 1, Count = 1, Seen = 1}}, Standing = {}, Renown = 0}}
		Migrations.Migrate(Data)
		T.Eq(Data.SchemaVersion, 5)
		for _, K in ipairs({"Places", "Rumours", "Heat", "News"}) do T.Eq(type(Data.Morality[K]), "table", K) end
		T.Same(Data.Licence, {Path = "", Since = 0, Orders = {}, Refused = {}, Revoked = 0})
		T.Eq(Data.Morality.Deeds.reported_lise.Count, 1, "the ledger is untouched")
	end,
	FullChainFromNothing = function(T)
		local Data = {Level = 3}
		Migrations.Migrate(Data)
		T.Eq(Data.SchemaVersion, 5)
		T.Eq(type(Data.Morality.Places), "table")
	end,
	KeepsExistingLicence = function(T)
		local Data = {SchemaVersion = 4, Licence = {Path = "State", Since = 9, Orders = {}, Refused = {}, Revoked = 0}}
		Migrations.Migrate(Data)
		T.Eq(Data.Licence.Path, "State")
	end,
	TemplateIsSchema5 = function(T)
		local Template = require(game.ReplicatedStorage.Modules.Data.ProfileData)
		T.Eq(Template.SchemaVersion, 5)
		T.Eq(type(Template.Morality.Places), "table")
		T.Eq(Template.Licence.Path, "")
	end,
}
]==]
T.Parent = game.ServerStorage.RenseiTests
return "ok"
```

- [ ] **Step 2: Run it** (§T). Expected: `PASS 0 / FAIL 4`, with `expected 5, got 4` on the migration tests.

- [ ] **Step 3: Implement it in Rensei** (Edit; back up both files first, §B).
  - In `ProfileMigrations`, insert after the `[3] = function(Data) ... end,` entry (before the closing `}` of `Migrations`):

```lua
	-- 4 -> 5: Morality × Reputation (2026-10-19): where deeds have been heard (Places), word on the road
	-- (Rumours), Heat per jurisdiction, the reason lines (News) + the Licence path. Additive.
	[4] = function(Data)
		Data.Morality = Data.Morality or {}
		for _, K in ipairs({"Places", "Rumours", "Heat", "News"}) do
			Data.Morality[K] = Data.Morality[K] or {}
		end
		Data.Licence = Data.Licence or {Path = "", Since = 0, Orders = {}, Refused = {}, Revoked = 0}
	end,
```

  - In `ProfileData`:
    - change `SchemaVersion = 4, -- 2: ...; 4: Morality` to `SchemaVersion = 5, -- 2: SkillTree (was AlchemyTree) + Mastery.StageSpend; 3: Story + quest stages; 4: Morality; 5: places, rumours, heat, licence`;
    - in the `Morality = {` block, after `Taboo = {}, -- reserved (owner canon pending)`, add:

```lua
		Places = {}, -- schema 5: [RegionId] = {Known = {[DeedId] = {[FactionId] = os.time() heard}}}
		Rumours = {}, -- schema 5: word on the road (RumourService), at most 20 live
		Heat = {}, -- schema 5: [Jurisdiction] = {Value, At} (HeatService, Plan 2)
		News = {}, -- schema 5: the last 10 "word reached <place>" reason lines
		Seeded = false, -- schema 5: deeds from before places existed were spread everywhere once
```

    - after the `Morality` block's closing `},`, add:

```lua
	-- The Licence path (schema 5; LicenceService, Plan 4, is the only writer). Path "" | "State" | "Circle".
	Licence = {Path = "", Since = 0, Orders = {}, Refused = {}, Revoked = 0},
```

- [ ] **Step 4: Run the test** (§T). Expected: `PASS 4 / FAIL 0`.

- [ ] **Step 5: Copy both files to the Tutorial and the Main Menu** (back up first, §B, in each place).
  - Fetch Rensei's two sources (§E step 1) and set each place's `Source` to exactly that text.
  - Check: `Fnv(Source)` (§H) is equal in all three places for both files, and print the hashes.
  - If `ProfileData` differed before, compare first. It was byte-identical after the 2026-10-18 data audit (hash `7d86af52`). If the other places changed since, stop and merge by hand.

- [ ] **Step 6: Export and commit.** Export (§E): `Scripts/ServerScriptService/ProfileMigrations.lua`, `Scripts/ReplicatedStorage/Modules/Data/ProfileData.lua` and the Tutorial / Main Menu mirror paths (only where the repo already mirrors those files), plus `Test_Schema5`. Commit (§C): `Schema 5: places, rumours, heat, news, licence (all three places)`.

---

### Task 3: Regions, communities, birth deeds

**Files:**
- Create: `ReplicatedStorage.Modules.Data.Rensei.Regions`.
- Modify: `ReplicatedStorage.Modules.Data.Rensei.Factions` (communities); `ReplicatedStorage.Modules.Data.Rensei.Deeds` (birth deeds).
- Test: `ServerStorage.RenseiTests.Test_Regions`.

**Interfaces:**
- Produces:
  - `Regions.Regions[Id] = {Name, Factions = {..}, Hidden = {[F] = true}?, Jurisdiction = "State"|"Militia"|"None", Safe = bool, Links = {{To, Carrier, Minutes}}}`
  - `Regions.Default = "City"`
  - `Regions.OfArea(AreaName: string?) -> RegionId`: unknown or nil gives `Default`.
  - `Regions.Present(Region, Faction) -> boolean`: diaspora communities are present everywhere.
  - `Regions.FactionsAt(Region) -> {FactionId}`
  - `Regions.Count(Faction) -> number`: how many regions the faction is present in.
  - `Regions.Reach(Region, Carrier) -> {FactionId}`: who a carrier's word reaches there.
  - `Regions.Links(Region) -> {{To, Carrier, Minutes}}`
  - `Factions.Communities = {[Origin] = FactionId}`; `Factions.Factions[Id].Diaspora = true` for communities.
  - `Deeds["born_" .. Origin] = {Text, Standing, Scope = "Public", Birth = true}`.

- [ ] **Step 1: Write the failing test** (Edit):

```lua
local T = Instance.new("ModuleScript"); T.Name = "Test_Regions"
T.Source = [==[
local Rensei = game.ReplicatedStorage.Modules.Data.Rensei
local Regions = require(Rensei.Regions)
local Factions = require(Rensei.Factions)
local Deeds = require(Rensei.Deeds)
return {
	LinksPointAtRealRegions = function(T)
		for Id, R in pairs(Regions.Regions) do
			for _, L in ipairs(R.Links) do
				T.True(Regions.Regions[L.To] ~= nil, Id .. " -> " .. L.To)
				T.True(Regions.Carriers[L.Carrier] ~= nil, Id .. " carrier " .. L.Carrier)
				T.True(L.Minutes > 0, Id .. " minutes")
			end
		end
	end,
	AreasMapToRegions = function(T)
		T.Eq(Regions.OfArea("Foundry Yard"), "Foundry")
		T.Eq(Regions.OfArea("Workshop Hill"), "Lindenmoor")
		T.Eq(Regions.OfArea("Halvard's Adit"), "Adit")
		T.Eq(Regions.OfArea("Silent Forge"), "Wilds")
		T.Eq(Regions.OfArea(nil), "City")
		T.Eq(Regions.OfArea("Somewhere New"), "City")
	end,
	PresenceAndCounts = function(T)
		T.True(Regions.Present("City", "Authority"))
		T.True(not Regions.Present("Foundry", "Authority"))
		T.True(Regions.Present("Lindenmoor", "Circle"))
		T.Eq(Regions.Count("Circle"), 2)
		T.True(Regions.Present("Adit", "IshvalanCommunity"), "communities live everywhere")
		T.Eq(Regions.Count("IshvalanCommunity"), 5)
	end,
	CarriersReachTheirFactions = function(T)
		T.Same(Regions.Reach("City", "Dispatch"), {"Authority"})
		T.Same(Regions.Reach("Foundry", "Dispatch"), {})
		local G = Regions.Reach("City", "Gossip")
		T.True(table.find(G, "Townsfolk") and table.find(G, "Circle") and table.find(G, "Authority"), "gossip reaches all")
		T.Same(Regions.Reach("Lindenmoor", "Whisper"), {"Circle"})
	end,
	EveryOriginHasABoundedBirthDeed = function(T)
		local Customization = require(Rensei.Customization)
		for Origin in pairs(Customization.Nations) do
			local D = Deeds["born_" .. Origin]
			T.True(D and D.Birth and D.Text, "born_" .. Origin)
			local Sum = 0
			for F, V in pairs(D.Standing) do
				T.True(Factions.Factions[F] ~= nil, F .. " is a faction")
				T.True(math.abs(V) <= 20, Origin .. " " .. F .. " within +-20")
				Sum += V
			end
			T.True(Sum >= 0, Origin .. " offsets add up to >= 0")
			T.True(D.Standing[Factions.Communities[Origin]] ~= nil, Origin .. " touches its own community")
		end
	end,
}
]==]
T.Parent = game.ServerStorage.RenseiTests
return "ok"
```

- [ ] **Step 2: Run it** (§T). Expected: an error, `Regions is not a valid member`.

- [ ] **Step 3: Create Regions** (Edit):

```lua
local M = Instance.new("ModuleScript"); M.Name = "Regions"
M.Source = [==[
-- Regions (2026-10-19, Morality × Reputation spec §3): the graph of places that word of a deed travels.
-- (Rensei.Places is the teleport place ids, so the graph lives here.) Each region lists the factions present
-- (they react when word arrives), its jurisdiction (whose Heat rises, Plan 2), whether it's a safe zone, and
-- its links: which carrier takes word to which region, in real minutes. Every region, link and minute is a
-- PROPOSAL; Wilds (the Forgotten Sites) is (new).
-- Carriers: Gossip reaches every faction present, slowly; Dispatch (the State's couriers) is fast but only
-- reaches the Authority; Whisper (the Circle's whisper-net) is fast but only reaches the Circle.
-- Communities (Factions.Communities) are diaspora: present in every region.

local Factions = require(script.Parent.Factions)

local Regions = {}

Regions.Carriers = {
	Gossip = {Name = "gossip"}, -- Reaches = nil: everyone present
	Dispatch = {Name = "State dispatch", Reaches = {"Authority"}},
	Whisper = {Name = "the Circle's whisper-net", Reaches = {"Circle"}},
}

Regions.Regions = {
	City = {
		Name = "the City", Factions = {"Authority", "Townsfolk", "Circle"}, Hidden = {Circle = true},
		Jurisdiction = "State", Safe = false,
		Links = {
			{To = "Foundry", Carrier = "Gossip", Minutes = 10}, {To = "Foundry", Carrier = "Dispatch", Minutes = 2},
			{To = "Lindenmoor", Carrier = "Gossip", Minutes = 20}, {To = "Lindenmoor", Carrier = "Dispatch", Minutes = 5},
			{To = "Lindenmoor", Carrier = "Whisper", Minutes = 3},
			{To = "Wilds", Carrier = "Gossip", Minutes = 30},
		},
	},
	Foundry = {
		Name = "the Foundry Yard", Factions = {"Foundry", "Townsfolk"},
		Jurisdiction = "State", Safe = false,
		Links = {{To = "City", Carrier = "Gossip", Minutes = 10}, {To = "City", Carrier = "Dispatch", Minutes = 2}},
	},
	Lindenmoor = {
		Name = "Lindenmoor", Factions = {"Townsfolk", "Circle"}, Hidden = {Circle = true},
		Jurisdiction = "Militia", Safe = false,
		Links = {
			{To = "City", Carrier = "Gossip", Minutes = 20}, {To = "City", Carrier = "Dispatch", Minutes = 5},
			{To = "City", Carrier = "Whisper", Minutes = 3},
			{To = "Adit", Carrier = "Gossip", Minutes = 30},
		},
	},
	Adit = {
		Name = "Halvard's Adit", Factions = {},
		Jurisdiction = "None", Safe = false,
		Links = {{To = "Lindenmoor", Carrier = "Gossip", Minutes = 30}},
	},
	Wilds = { -- (new) the Forgotten Sites
		Name = "the wilds", Factions = {},
		Jurisdiction = "None", Safe = false,
		Links = {{To = "City", Carrier = "Gossip", Minutes = 30}},
	},
}
Regions.Default = "City" -- anywhere outside an area volume is the City (the hub has no AreaName)

-- WorldService area names (AreaName attribute) -> region
Regions.Areas = {
	["Foundry Yard"] = "Foundry",
	["Lindenmoor"] = "Lindenmoor", ["Cypress Ridge"] = "Lindenmoor", ["Mill Creek Bridge"] = "Lindenmoor",
	["Workshop Hill"] = "Lindenmoor", ["Lindenmoor Station"] = "Lindenmoor", ["Bramble Hollow"] = "Lindenmoor",
	["Gorge Lookout"] = "Lindenmoor",
	["Halvard's Adit"] = "Adit",
	["Frozen Research Station"] = "Wilds", ["Cracked Footbridge"] = "Wilds", ["Burned Laboratory"] = "Wilds",
	["Silent Forge"] = "Wilds", ["Silent Observatory"] = "Wilds",
}

function Regions.OfArea(AreaName)
	return (AreaName and Regions.Areas[AreaName]) or Regions.Default
end

local function Diaspora(Faction)
	local F = Factions.Factions[Faction]
	return F ~= nil and F.Diaspora == true
end

function Regions.Present(Region, Faction)
	local R = Regions.Regions[Region]
	if not R then return false end
	return Diaspora(Faction) or table.find(R.Factions, Faction) ~= nil
end

function Regions.FactionsAt(Region)
	local Out = {}
	for _, F in ipairs(Factions.Order) do
		if Regions.Present(Region, F) then table.insert(Out, F) end
	end
	return Out
end

function Regions.Count(Faction)
	local N = 0
	for Id in pairs(Regions.Regions) do if Regions.Present(Id, Faction) then N += 1 end end
	return N
end

-- the factions in Region that word brought by Carrier reaches
function Regions.Reach(Region, Carrier)
	local C = Regions.Carriers[Carrier]
	local Out = {}
	for _, F in ipairs(Regions.FactionsAt(Region)) do
		if not C or not C.Reaches or table.find(C.Reaches, F) then table.insert(Out, F) end
	end
	return Out
end

function Regions.Links(Region)
	local R = Regions.Regions[Region]
	return R and R.Links or {}
end

return Regions
]==]
M.Parent = game.ReplicatedStorage.Modules.Data.Rensei
return "ok"
```

- [ ] **Step 4: Add the communities to Factions** (back up first, §B).
  - Replace the `Factions.Factions = {...}` block and the `Factions.Order` line with:

```lua
Factions.Factions = {
	Authority = {Name = "State Authority"},
	Foundry = {Name = "Foundry Hands"}, -- the yard's workers and smelters
	Circle = {Name = "Unlicensed Circle"}, -- alchemists working without a licence
	Townsfolk = {Name = "Townsfolk"}, -- ordinary people of the district
	-- (new, 2026-10-19) each origin's home community: PLACEHOLDER names from the spec (§11), owner to name them.
	-- Diaspora: their people live in every region, so they hear word anywhere (Rensei.Regions).
	AmestrianCitizenry = {Name = "Amestrian Citizenry", Diaspora = true},
	IshvalanCommunity = {Name = "Ishvalan Community", Diaspora = true},
	XingneseHouses = {Name = "Xingnese Merchant Houses", Diaspora = true},
	DrachmanFrontier = {Name = "Drachman Frontier", Diaspora = true},
	AerugonianGuild = {Name = "Aerugonian Guild", Diaspora = true},
	XerxianRemnant = {Name = "Xerxian Remnant", Diaspora = true},
}
Factions.Order = {"Authority", "Foundry", "Circle", "Townsfolk", "AmestrianCitizenry", "IshvalanCommunity",
	"XingneseHouses", "DrachmanFrontier", "AerugonianGuild", "XerxianRemnant"}
-- origin (Identity.Origin, Customization.Nations) -> its community
Factions.Communities = {
	Amestrian = "AmestrianCitizenry", Ishvalan = "IshvalanCommunity", Xingnese = "XingneseHouses",
	Drachman = "DrachmanFrontier", Aerugonian = "AerugonianGuild", Xerxian = "XerxianRemnant",
}
```

- [ ] **Step 5: Add the birth deeds to Deeds** (back up first).
  - Insert before the closing `}` of `local Deeds = {` (after `arrested_bandit = {...},`):

```lua

	-- ===== Birth (2026-10-19, spec §11): recorded once when the character first plays in Ye. Origin offsets
	-- cut both ways, each at most +-20, and each origin's add up to >= 0 so no origin is a net handicap.
	-- PLACEHOLDER values (spec §18.2: the owner sets the real table). Birth deeds are heard everywhere at
	-- once and never become rumours. =====
	born_Amestrian = {
		Text = "Born in Amestris",
		Standing = {AmestrianCitizenry = 10, Authority = 10, IshvalanCommunity = -10},
		Scope = "Public", Birth = true,
	},
	born_Ishvalan = {
		Text = "Born of Ishval",
		Standing = {IshvalanCommunity = 20, Authority = -15, Circle = 10},
		Scope = "Public", Birth = true,
	},
	born_Xingnese = {
		Text = "Born in Xing",
		Standing = {XingneseHouses = 15, Authority = -5},
		Scope = "Public", Birth = true,
	},
	born_Drachman = {
		Text = "Born in Drachma",
		Standing = {DrachmanFrontier = 15, Authority = -10},
		Scope = "Public", Birth = true,
	},
	born_Aerugonian = {
		Text = "Born in Aerugo",
		Standing = {AerugonianGuild = 15, Authority = -10},
		Scope = "Public", Birth = true,
	},
	born_Xerxian = {
		Text = "Of Xerxian blood",
		Standing = {XerxianRemnant = 10, Circle = 5, Authority = -10},
		Scope = "Public", Birth = true,
	},
```

  - Also add this line to the field list in Deeds' header comment, after `--     Bonus    = {Money = n} ...`:

```lua
--     Birth    = true   -- an origin deed (born_<Origin>): heard everywhere at once, never a rumour
```

- [ ] **Step 6: Run the test** (§T). Expected: `PASS 5 / FAIL 0`.

- [ ] **Step 7: Run the earlier suites again.** Run `Test_Schema5` and `Test_TestKit`; both should pass.
  - Then check that the client UI that lists factions still renders: search the client for `Factions.Order` (`script_grep "Factions.Order"`) and read each use. If a UI lists every faction, it now shows 10 entries. That's acceptable for now (the Journal tab is Plan 10). Note it in the Changelog.

- [ ] **Step 8: Export and commit.** Export (§E): Regions (new), Factions, Deeds, Test_Regions. Commit (§C): `Regions graph, origin communities and birth deeds (placeholders)`.

---

### Task 4: Reputation (place-by-place standing)

**Files:**
- Create: `ReplicatedStorage.Modules.Data.Rensei.Reputation`.
- Test: `ServerStorage.RenseiTests.Test_Reputation`.

**Interfaces:**
- Consumes: `Regions.Present`, `Regions.FactionsAt`, `Regions.Count`, `Regions.Regions` (Task 3).
- Produces (`M` = a profile's `Morality` table, `Deeds` = the `Rensei.Deeds` table):
  - `Reputation.Land(M, Region, DeedId, Factions: {string}, Now) -> {string}`: the factions that heard it just now.
  - `Reputation.LandEverywhere(M, DeedId, Now)`
  - `Reputation.Landed(M, DeedId) -> boolean`
  - `Reputation.PlaceStanding(M, Deeds, Region) -> {[Faction] = number}`
  - `Reputation.GlobalStanding(M, Deeds) -> {[Faction] = number}`: each faction's place standing summed over regions ÷ `Regions.Count(F)`.
  - `Reputation.Renown(M, Deeds) -> number`
  - `Reputation.Seed(M, Deeds, Now) -> boolean`: true the first time; sets `M.Seeded = true`.

- [ ] **Step 1: Write the failing test** (Edit):

```lua
local T = Instance.new("ModuleScript"); T.Name = "Test_Reputation"
T.Source = [==[
local Rensei = game.ReplicatedStorage.Modules.Data.Rensei
local Reputation = require(Rensei.Reputation)
local Regions = require(Rensei.Regions)
local Deeds = {
	d_local = {Text = "x", Standing = {Authority = 12, Foundry = -6, Circle = -8}, Scope = "Local"},
	d_public = {Text = "y", Standing = {Townsfolk = 4}, Renown = 10, Scope = "Public"},
	d_private = {Text = "z", Standing = {Circle = 20}, Scope = "Private"},
	d_birth = {Text = "b", Standing = {IshvalanCommunity = 20, Authority = -15}, Scope = "Public", Birth = true},
}
local function Fresh(Ledger)
	return {Deeds = Ledger or {}, Places = {}, Standing = {}, Renown = 0}
end
return {
	LandIsOncePerFactionPerPlace = function(T)
		local M = Fresh({d_local = {At = 0, Count = 1}})
		T.Same(Reputation.Land(M, "Foundry", "d_local", {"Foundry", "Townsfolk"}, 5), {"Foundry", "Townsfolk"})
		T.Same(Reputation.Land(M, "Foundry", "d_local", {"Foundry", "Townsfolk"}, 9), {})
		T.Eq(M.Places.Foundry.Known.d_local.Foundry, 5, "first time kept")
	end,
	LandIgnoresAbsentFactions = function(T)
		local M = Fresh({d_local = {At = 0, Count = 1}})
		T.Same(Reputation.Land(M, "Foundry", "d_local", {"Authority"}, 1), {}, "no Authority in the Foundry")
	end,
	PlaceAndGlobalStanding = function(T)
		local M = Fresh({d_local = {At = 0, Count = 2}})
		Reputation.Land(M, "Foundry", "d_local", Regions.FactionsAt("Foundry"), 1)
		T.Same(Reputation.PlaceStanding(M, Deeds, "Foundry"), {Foundry = -12})
		T.Near(Reputation.GlobalStanding(M, Deeds).Foundry, -12, 1e-9, "Foundry is only in the Foundry")
		Reputation.Land(M, "City", "d_local", {"Authority", "Circle"}, 2)
		local G = Reputation.GlobalStanding(M, Deeds)
		T.Near(G.Authority, 24, 1e-9, "Authority: only the City")
		T.Near(G.Circle, -8, 1e-9, "Circle: heard in 1 of its 2 regions -> half of -16")
	end,
	EverywhereIsFull = function(T)
		local M = Fresh({d_local = {At = 0, Count = 1}})
		Reputation.LandEverywhere(M, "d_local", 0)
		local G = Reputation.GlobalStanding(M, Deeds)
		T.Near(G.Authority, 12, 1e-9); T.Near(G.Foundry, -6, 1e-9); T.Near(G.Circle, -8, 1e-9)
	end,
	RenownNeedsAPublicDeedHeardSomewhere = function(T)
		local M = Fresh({d_public = {At = 0, Count = 1}, d_local = {At = 0, Count = 1}})
		T.Eq(Reputation.Renown(M, Deeds), 0)
		Reputation.Land(M, "City", "d_public", {"Townsfolk"}, 0)
		T.Eq(Reputation.Renown(M, Deeds), 10)
	end,
	SeedSpreadsOldKnownDeedsOnce = function(T)
		local M = Fresh({d_local = {At = 3, Count = 1}, d_private = {At = 3, Count = 1}})
		T.True(Reputation.Seed(M, Deeds, 100))
		T.True(not Reputation.Seed(M, Deeds, 200), "only once")
		T.True(Reputation.Landed(M, "d_local"))
		T.True(not Reputation.Landed(M, "d_private"), "private deeds stay unheard")
		T.Eq(M.Places.City.Known.d_local.Authority, 3, "stamped with the deed's own time")
	end,
	DiscoveredPrivateCountsAsItsKnownScope = function(T)
		local M = Fresh({d_private = {At = 0, Count = 1, Known = "Local"}})
		Reputation.Seed(M, Deeds, 0)
		T.True(Reputation.Landed(M, "d_private"))
	end,
}
]==]
T.Parent = game.ServerStorage.RenseiTests
return "ok"
```

- [ ] **Step 2: Run it** (§T). Expected: an error, `Reputation is not a valid member`.

- [ ] **Step 3: Create Reputation** (Edit):

```lua
local M = Instance.new("ModuleScript"); M.Name = "Reputation"
M.Source = [==[
-- Reputation (2026-10-19, Morality × Reputation spec §2-§5, §13): standing place by place. A deed's
-- Standing counts in a region only for the factions there that have heard of it:
--   Morality.Places[Region].Known[DeedId][Faction] = os.time() it was heard (once per faction per place).
-- The global Standing that conditions and the UI read stays a cache: each faction's standing summed over
-- the regions and divided by how many regions it's present in (equal weights, PROPOSAL), so a deed heard
-- everywhere its factions live counts in full, and one heard in half of them counts half.
-- Pure functions over a profile's Morality table: MoralityService and RumourService call them.

local Regions = require(script.Parent.Regions)

local Reputation = {}

local function Place(M, Region)
	M.Places = M.Places or {}
	local P = M.Places[Region]
	if not P then P = {Known = {}}; M.Places[Region] = P end
	P.Known = P.Known or {}
	return P
end

-- DeedId heard by those Factions in Region; returns the factions that heard it just now
function Reputation.Land(M, Region, DeedId, Factions, Now)
	local P = Place(M, Region)
	local Heard = P.Known[DeedId] or {}
	local New = {}
	for _, F in ipairs(Factions) do
		if Regions.Present(Region, F) and Heard[F] == nil then
			Heard[F] = Now
			table.insert(New, F)
		end
	end
	if #New > 0 then P.Known[DeedId] = Heard end
	return New
end

function Reputation.LandEverywhere(M, DeedId, Now)
	for Id in pairs(Regions.Regions) do Reputation.Land(M, Id, DeedId, Regions.FactionsAt(Id), Now) end
end

function Reputation.Landed(M, DeedId)
	for _, P in pairs(M.Places or {}) do
		local Heard = P.Known and P.Known[DeedId]
		if Heard and next(Heard) ~= nil then return true end
	end
	return false
end

function Reputation.PlaceStanding(M, Deeds, Region)
	local Out = {}
	local P = (M.Places or {})[Region]
	for DeedId, Heard in pairs(P and P.Known or {}) do
		local Def, E = Deeds[DeedId], M.Deeds and M.Deeds[DeedId]
		if type(Def) == "table" and E then
			for F, V in pairs(Def.Standing or {}) do
				if Heard[F] ~= nil then Out[F] = (Out[F] or 0) + V * (E.Count or 0) end
			end
		end
	end
	return Out
end

function Reputation.GlobalStanding(M, Deeds)
	local Sum = {}
	for Region in pairs(Regions.Regions) do
		for F, V in pairs(Reputation.PlaceStanding(M, Deeds, Region)) do Sum[F] = (Sum[F] or 0) + V end
	end
	local Out = {}
	for F, V in pairs(Sum) do Out[F] = V / math.max(1, Regions.Count(F)) end
	return Out
end

-- Renown: Public deeds (or deeds discovered as Public) count once they've been heard anywhere
function Reputation.Renown(M, Deeds)
	local R = 0
	for Id, E in pairs(M.Deeds or {}) do
		local Def = Deeds[Id]
		if type(Def) == "table" and (E.Known or Def.Scope) == "Public" and Reputation.Landed(M, Id) then
			R += (Def.Renown or 0) * (E.Count or 0)
		end
	end
	return R
end

-- Schema 5, once per profile: deeds that already counted in full before places existed (Local / Public or
-- discovered) are heard everywhere, stamped with the deed's own time, so no old save loses standing.
function Reputation.Seed(M, Deeds, Now)
	if M.Seeded then return false end
	for Id, E in pairs(M.Deeds or {}) do
		local Def = Deeds[Id]
		if type(Def) == "table" and (E.Known or Def.Scope or "Private") ~= "Private" then
			Reputation.LandEverywhere(M, Id, E.At or Now)
		end
	end
	M.Seeded = true
	return true
end

return Reputation
]==]
M.Parent = game.ReplicatedStorage.Modules.Data.Rensei
return "ok"
```

- [ ] **Step 4: Run the test** (§T). Expected: `PASS 7 / FAIL 0`.

- [ ] **Step 5: Export and commit.** Export (§E): Reputation, Test_Reputation. Commit (§C): `Reputation: place-by-place standing, global cache, schema-5 seeding`.

---

### Task 5: MoralityService on places (origin landing, birth deeds, listeners)

**Files:**
- Modify: `ServerScriptService.MoralityService` (read the whole file first; it is 207 lines as of 2026-10-19).
- Test: `ServerStorage.RenseiTests.Play_Morality` (a Play-mode test module, run by a runtime Script).

**Interfaces:**
- Consumes: `Reputation.*` (Task 4), `Regions.OfArea` (Task 3), `WorldService.AreaAt(Position) -> Part?` (an area part with the attribute `AreaName`).
- Produces:
  - `MoralityService.Record(Player, DeedId, Quiet, Ctx) -> boolean`. `Ctx` is optional:
    - `Region`: string, overrides where it happened;
    - `Strength`: number;
    - `Witness`: true captures witnesses through WitnessService (Task 9; until then, treat `Witness` as `Strength = 2`);
    - `Evidence`: number.
  - `MoralityService.Recorded`: a list of `function(Player, DeedId, Def, Info)`, called after a deed counts. `Info = {Region, Strength, Scope}`.
  - `MoralityService.Refresh(Player)`: rebuilds caches, shows tier-change banners, syncs.
  - `MoralityService.RecordBirth(Player) -> boolean`
  - `MoralityService.RegionOf(Character) -> RegionId`

- [ ] **Step 1: Write the Play test module** (Edit; it fails until Step 3):

```lua
local T = Instance.new("ModuleScript"); T.Name = "Play_Morality"
T.Source = [==[
-- Run inside the game VM (a runtime Script in Play): returns a TestKit suite. Snapshot / restore around it.
local MoralityService = require(game.ServerScriptService.MoralityService)
local ProgressionService = require(game.ServerScriptService.ProgressionService)
local Deeds = require(game.ReplicatedStorage.Modules.Data.Rensei.Deeds)
local Player = game.Players:GetPlayers()[1]
return {
	JoinSeededAndBorn = function(T)
		local Data = ProgressionService.GetData(Player)
		T.True(Data.Morality.Seeded == true, "seeded on join")
		local Origin = Data.Identity and Data.Identity.Origin
		if Origin and Origin ~= "" then T.True(Data.Morality.Deeds["born_" .. Origin] ~= nil, "birth deed recorded") end
	end,
	LocalDeedLandsWhereItHappened = function(T)
		Deeds.__test_local = {Text = "Test: local deed", Standing = {Foundry = -6, Authority = 12}, Scope = "Local"}
		local Got
		table.insert(MoralityService.Recorded, function(_, Id, _, Info) if Id == "__test_local" then Got = Info end end)
		T.True(MoralityService.Record(Player, "__test_local", true, {Region = "Foundry"}))
		local M = ProgressionService.GetData(Player).Morality
		T.True(M.Places.Foundry.Known.__test_local.Foundry ~= nil, "heard in the Foundry")
		T.True(M.Places.City == nil or M.Places.City.Known.__test_local == nil, "not yet in the City")
		task.wait()
		T.Eq(Got and Got.Region, "Foundry"); T.Eq(Got and Got.Strength, 2, "Local default strength")
		Deeds.__test_local = nil
	end,
	PrivateDeedLandsNowhere = function(T)
		Deeds.__test_private = {Text = "Test: private", Standing = {Circle = 9}, Scope = "Private"}
		MoralityService.Record(Player, "__test_private", true, {Region = "City"})
		local M = ProgressionService.GetData(Player).Morality
		T.True(not (M.Places.City and M.Places.City.Known.__test_private), "unheard")
		Deeds.__test_private = nil
	end,
}
]==]
T.Parent = game.ServerStorage.RenseiTests
return "ok"
```

- [ ] **Step 2: Run it in Play and confirm it fails** (§T, §S). Use this runtime Script source:

```lua
local HttpService = game:GetService("HttpService")
local PS = require(game.ServerScriptService.ProgressionService)
local Player = game.Players:GetPlayers()[1] or game.Players.PlayerAdded:Wait()
local Data
repeat Data = PS.GetData(Player); task.wait(0.5) until Data
task.wait(3) -- MoralityService's join work
local Snapshot = HttpService:JSONEncode(Data.Morality)
local Ok, Text = pcall(function()
	return (require(game.ServerStorage.RenseiTests.TestKit).Run(require(game.ServerStorage.RenseiTests.Play_Morality)))
end)
Data.Morality = HttpService:JSONDecode(Snapshot)
local MS = require(game.ServerScriptService.MoralityService)
if MS.Refresh then MS.Refresh(Player) else MS.Rebuild(Data) end
workspace:SetAttribute("TestResult", Ok and Text or ("ERROR " .. tostring(Text)))
```

  Expected: `FAIL JoinSeededAndBorn: seeded on join`.

- [ ] **Step 3: Implement it** (Edit; back up `MoralityService` first, §B).
  1. **Requires.** After `local Factions = require(Rensei.Factions)`, add:

```lua
local Regions = require(Rensei.Regions)
local Reputation = require(Rensei.Reputation)
```

  2. **`Ensure`.** Replace the whole `local function Ensure(Data) ... end` with:

```lua
local function Ensure(Data)
	Data.Morality = Data.Morality or {}
	local M = Data.Morality
	for _, K in ipairs({"Deeds", "Conduct", "Standing", "Trust", "Taboo", "Places", "Rumours", "Heat", "News"}) do M[K] = M[K] or {} end
	M.Renown = M.Renown or 0
	return M
end
```

  3. **`Apply` and `Rebuild`.** Replace `local function Apply(M, Def, Times, Known) ... end` and `function MoralityService.Rebuild(Data) ... end` with:

```lua
-- Conduct and Trust are personal: they move at once, wherever you are. Standing and Renown come from where
-- the deed has been heard (Rensei.Reputation): see Record and RumourService.
local function ApplyPersonal(M, Def, Times)
	Add(M.Conduct, Def.Conduct, Times)
	Add(M.Trust, Def.Trust, Times)
end

-- Recompute every cache from the ledger and the places that heard each deed.
function MoralityService.Rebuild(Data)
	local M = Ensure(Data)
	M.Conduct, M.Trust = {}, {}
	for Id, E in pairs(M.Deeds) do
		local Def = Deeds[Id]
		if type(Def) == "table" and Def.Text then ApplyPersonal(M, Def, E.Count or 0) end
	end
	M.Standing = Reputation.GlobalStanding(M, Deeds)
	M.Renown = Reputation.Renown(M, Deeds)
	return M
end
```

  4. **`RegionOf` and `Recorded`.** Add both after `Tiers`:

```lua
MoralityService.Recorded = {} -- function(Player, DeedId, Def, Info = {Region, Strength, Scope}) after a deed counts

-- the region a character stands in (Rensei.Regions; outside every area volume = the City)
function MoralityService.RegionOf(Character)
	local Root = Character and Character:FindFirstChild("HumanoidRootPart")
	if not Root then return Regions.Default end
	local Ok, Area = pcall(function() return require(ServerScriptService.WorldService).AreaAt(Root.Position) end)
	return Regions.OfArea(Ok and Area and Area:GetAttribute("AreaName") or nil)
end

-- how many witnesses' worth a deed has when nobody was captured (dialogue / quest deeds: the people you
-- spoke to). PROPOSAL: Local 2, Public 4, Private 0.
local DEFAULT_STRENGTH = {Local = 2, Public = 4, Private = 0}
```

  5. **`Record`.** Replace the whole `function MoralityService.Record(Player, DeedId, Quiet) ... end` with:

```lua
-- Returns true if the deed counted (false: unknown, already recorded, or today's cap reached).
-- Ctx (optional): Region (where it happened; default: where the player stands), Strength (witness weight),
-- Witness (true: capture who perceived it, WitnessService), Evidence (items left behind).
function MoralityService.Record(Player, DeedId, Quiet, Ctx)
	local Def = Deeds[DeedId]
	local Data = ProgressionService.GetData(Player)
	if type(Def) ~= "table" or not Def.Text or not Data then return false end
	Ctx = Ctx or {}
	local M = Ensure(Data)
	local E = M.Deeds[DeedId]
	if E and not Def.Repeat then return false end -- once ever
	E = E or {At = os.time(), Count = 0, Seen = 0}
	E.Seen += 1
	E.Last = os.time()
	if Def.Repeat then
		local Today = math.floor(os.time() / 86400)
		if E.Day ~= Today then E.Day, E.DayCount = Today, 0 end
		if E.DayCount >= (Def.Repeat.Cap or 1) then
			M.Deeds[DeedId] = E
			return false -- seen, but it no longer moves anything today (no farming)
		end
		E.DayCount += 1
	end
	E.Count += 1
	M.Deeds[DeedId] = E
	local Before = Tiers(M)
	ApplyPersonal(M, Def, 1)
	-- where it's heard: a birth deed everywhere; a Local / Public one by the factions where it happened, if
	-- anyone perceived it (word then travels: RumourService); a Private one nowhere until discovered
	local Scope = E.Known or Def.Scope or "Private"
	local Region = Ctx.Region or MoralityService.RegionOf(Player.Character)
	local Strength = Ctx.Strength
	if Strength == nil and Ctx.Witness then
		local Ok, W = pcall(function() return require(ServerScriptService.WitnessService) end)
		Strength = (Ok and W.Capture) and W.Capture(Player, DeedId, Ctx.Evidence).Strength or DEFAULT_STRENGTH.Local
	end
	Strength = Strength or DEFAULT_STRENGTH[Scope] or 0
	local Now = os.time()
	if Def.Birth then
		Reputation.LandEverywhere(M, DeedId, Now)
	elseif Scope ~= "Private" and Strength > 0 then
		Reputation.Land(M, Region, DeedId, Regions.FactionsAt(Region), Now)
	end
	M.Standing = Reputation.GlobalStanding(M, Deeds)
	M.Renown = Reputation.Renown(M, Deeds)
	if Def.Bonus and (Def.Bonus.Money or 0) > 0 then ProgressionService.GrantMoney(Player, Def.Bonus.Money) end
	if not Quiet then
		UIService.Notify(Player, "Toast", {Text = Def.Text})
		local After = Tiers(M)
		for _, F in ipairs(Factions.Order) do
			if After[F] ~= Before[F] then
				UIService.Notify(Player, "Banner", {Text = Factions.Factions[F].Name .. " - " .. After[F]})
			end
		end
	end
	ProgressionService.Sync(Player)
	local Info = {Region = Region, Strength = Strength, Scope = Scope}
	for _, Listener in ipairs(MoralityService.Recorded) do task.spawn(Listener, Player, DeedId, Def, Info) end
	return true
end

-- Caches rebuilt after word arrived somewhere (RumourService): banners for any tier that changed.
function MoralityService.Refresh(Player)
	local Data = ProgressionService.GetData(Player)
	if not Data then return end
	local M = Ensure(Data)
	local Before = Tiers(M)
	MoralityService.Rebuild(Data)
	local After = Tiers(M)
	for _, F in ipairs(Factions.Order) do
		if After[F] ~= Before[F] then
			UIService.Notify(Player, "Banner", {Text = Factions.Factions[F].Name .. " - " .. After[F]})
		end
	end
	ProgressionService.Sync(Player)
end

-- The origin's birth deed (Identity.Origin, set at character creation in the menu): once, quietly.
function MoralityService.RecordBirth(Player)
	local Data = ProgressionService.GetData(Player)
	local Origin = Data and Data.Identity and Data.Identity.Origin
	if type(Origin) ~= "string" or Origin == "" or not Deeds["born_" .. Origin] then return false end
	return MoralityService.Record(Player, "born_" .. Origin, true)
end
```

  6. **Grip deeds.** In `OnGrip`, change `MoralityService.Record(Player, F.Grip)` to `MoralityService.Record(Player, F.Grip, false, {Witness = true})`. A finisher is only heard if someone perceived it.
  7. **`Joined`.** Replace the `if Data then ... end` block inside `Joined` with:

```lua
			if Data then
				local M = Ensure(Data)
				Reputation.Seed(M, Deeds, os.time()) -- schema 5: old deeds heard everywhere, once
				MoralityService.RecordBirth(Player)
				MoralityService.Rebuild(Data)
				MoralityService.RecordOutcomes(Player, true)
				ProgressionService.Sync(Player)
				return
			end
```

  8. **Header comment.** Add to the top comment, after the `--   * Combat: ...` paragraph:

```lua
--   * Places (2026-10-19, schema 5): Standing and Renown count only where a deed has been heard
--     (Rensei.Reputation). A Local / Public deed is heard at once by the factions where it happened, if
--     anyone perceived it; RumourService carries the word on. Birth deeds (born_<Origin>) are heard
--     everywhere. Old saves are seeded once so nothing they had is lost.
```

- [ ] **Step 4: Run the Play test** (§T, §S). Expected: `PASS 3 / FAIL 0`. Also read the console (`get_console_output`) for `MoralityService` errors: expect none.

- [ ] **Step 5: Check that existing content still works.** Run the existing dialogue deed path once in Play. In the game VM, call `MoralityService.Record(Player, "told_on_tobin", true, {Region = "Foundry"})` inside the snapshot / restore. Then confirm that `ProgressionService.GetData(Player).Morality.Standing.Foundry` moved by −3 (full: Foundry is only in the Foundry).

- [ ] **Step 6: Export and commit.** Export (§E): MoralityService, Play_Morality. Commit (§C): `MoralityService: standing from where deeds are heard; birth deeds; Recorded listeners`.

---

### Task 6: Perception maths

**Files:**
- Create: `ReplicatedStorage.Modules.Data.Rensei.Perception`.
- Test: `ServerStorage.RenseiTests.Test_Perception`.

**Interfaces:**
- Produces:
  - the numbers: `Perception.Tick`, `.ActiveRange`, `.RaysPerNpc`, `.RaysPerTick`, `.Primary`, `.Peripheral`, `.Suspicious`, `.Drain`, `.Memory`, `.InvestigateTime`, `.SearchTime`, `.CautiousTime`, `.CautiousMult`, `.CallRadius`, `.Falloff`;
  - the tables: `.Move`, `.Types[Type] = {Range, Fill}`, `.EnemyTypes[EnemyType] = Type`, `.AlwaysAware[EnemyType] = true`;
  - `Perception.ConeMult(Look: Vector3, To: Vector3) -> 1 | 0.5 | 0`
  - `Perception.MoveMult(Speed) -> number`
  - `Perception.Rate(Type, Dist, Cone, Visible, Move, Exposure, Cautious) -> awareness per second`

- [ ] **Step 1: Write the failing test** (Edit):

```lua
local T = Instance.new("ModuleScript"); T.Name = "Test_Perception"
T.Source = [==[
local P = require(game.ReplicatedStorage.Modules.Data.Rensei.Perception)
local Fwd = Vector3.new(0, 0, -1)
local function Dir(Deg) local R = math.rad(Deg) return Vector3.new(math.sin(R), 0, -math.cos(R)) end
return {
	Cone = function(T)
		T.Eq(P.ConeMult(Fwd, Dir(0)), 1, "ahead")
		T.Eq(P.ConeMult(Fwd, Dir(54)), 1, "inside the 110 cone")
		T.Eq(P.ConeMult(Fwd, Dir(70)), 0.5, "peripheral")
		T.Eq(P.ConeMult(Fwd, Dir(90)), 0, "beside: outside 160")
		T.Eq(P.ConeMult(Fwd, Dir(180)), 0, "behind")
		T.Eq(P.ConeMult(Fwd, Vector3.new(0, 10, 0)), 1, "straight above counts as seen")
	end,
	Movement = function(T)
		T.Eq(P.MoveMult(0), 1); T.Eq(P.MoveMult(16), 1); T.Eq(P.MoveMult(20), 1.5); T.Eq(P.MoveMult(30), 2)
	end,
	RateFallsOffAndStopsAtRange = function(T)
		local Near = P.Rate("Grunt", 0, 1, 1, 1, 1, false)
		T.Near(Near, P.Types.Grunt.Fill, 1e-9)
		T.Near(P.Rate("Grunt", 15, 1, 1, 1, 1, false), P.Types.Grunt.Fill * (1 - P.Falloff * 0.5), 1e-9)
		T.Eq(P.Rate("Grunt", 31, 1, 1, 1, 1, false), 0, "beyond range")
		T.Eq(P.Rate("Grunt", 5, 0, 1, 1, 1, false), 0, "behind")
		T.Near(P.Rate("Grunt", 0, 1, 1 / 3, 1, 1, false), Near / 3, 1e-9, "a third visible")
		T.Near(P.Rate("Grunt", 0, 1, 1, 1, 1, true), Near * P.CautiousMult, 1e-9, "cautious")
	end,
	TypesCovered = function(T)
		for Enemy, Type in pairs(P.EnemyTypes) do T.True(P.Types[Type] ~= nil, Enemy .. " -> " .. Type) end
		T.True(P.AlwaysAware.TrialFlame and P.AlwaysAware.Sparring, "arena foes keep distance aggro")
	end,
}
]==]
T.Parent = game.ServerStorage.RenseiTests
return "ok"
```

- [ ] **Step 2: Run it** (§T). Expected: an error, `Perception is not a valid member`.

- [ ] **Step 3: Create Perception** (Edit):

```lua
local M = Instance.new("ModuleScript"); M.Name = "Perception"
M.Source = [==[
-- Perception (2026-10-19, Morality × Reputation spec §17.1, §17.2, §17.10): the numbers and the pure maths
-- of what NPCs notice. PerceptionService (server) runs it; the eye-sigil HUD (Plan 2) will read it too.
-- Every number is a PROPOSAL (spec §18.7). Light (Exposure) and crouching arrive in Plan 2 (S2).

local Perception = {}

Perception.Tick = 0.2 -- seconds between updates
Perception.ActiveRange = 80 -- only NPCs this close to some player perceive at all
Perception.RaysPerNpc = 3 -- sight rays per NPC per tick
Perception.RaysPerTick = 120 -- for every NPC together
Perception.Primary = 110 -- degrees of the full-rate view cone
Perception.Peripheral = 160 -- degrees of the half-rate cone; behind it, nothing
Perception.Suspicious = 0.35 -- awareness at which an NPC goes to look
Perception.Drain = 0.25 -- awareness lost per second while it perceives nothing
Perception.Memory = 3 -- seconds an Alert NPC keeps fighting someone it can't see
Perception.InvestigateTime = 8 -- a Suspicious NPC gives up after this long
Perception.SearchTime = 25 -- an Alert NPC that lost you searches this long, then turns Cautious
Perception.CautiousTime = 180
Perception.CautiousMult = 1.3 -- sight (and, in Plan 2, hearing) while Cautious
Perception.CallRadius = 40 -- an Alert NPC brings in the NPCs this close
Perception.Falloff = 0.75 -- at the edge of its range an NPC fills at 1 - 0.75 = 25% of the point-blank rate

-- movement by horizontal root speed (base walk 16): walking x1, running x1.5, sprinting x2
Perception.Move = {{Max = 17, Mult = 1}, {Max = 24, Mult = 1.5}, {Max = math.huge, Mult = 2}}

-- Range in studs; Fill = awareness per second at point blank, fully visible, in the primary cone
Perception.Types = {
	Grunt = {Range = 30, Fill = 0.8}, -- slow to notice
	Elite = {Range = 45, Fill = 1.4},
	Agent = {Range = 40, Fill = 1.4}, -- State alchemists / enforcers (they hear alchemy x2 in Plan 2)
	Hunter = {Range = 50, Fill = 1.8},
	Witness = {Range = 30, Fill = 1.0}, -- townsfolk and other watchers (tag RenseiWatcher)
}

-- TuningConfig.Enemies type -> perception type (unlisted: Grunt)
Perception.EnemyTypes = {
	Grunt = "Grunt", AditScavenger = "Grunt", Elite = "Elite",
	FieldAlchemist = "Agent", FrostAlchemist = "Agent", GaleAlchemist = "Agent",
	StoneAlchemist = "Agent", WardAlchemist = "Agent",
}

-- arena / trial foes keep the old distance aggro (spec: "always aware")
Perception.AlwaysAware = {
	Sparring = true, TrialEarth = true, TrialFlame = true, TrialIce = true, TrialMetal = true, TrialWind = true,
}

-- 1 inside the primary cone, 0.5 in the peripheral band, 0 behind. Horizontal angle only, so someone
-- straight above or below (a ledge, a drop) counts as ahead.
function Perception.ConeMult(Look, To)
	local L = Vector3.new(Look.X, 0, Look.Z)
	local D = Vector3.new(To.X, 0, To.Z)
	if D.Magnitude < 0.01 then return 1 end
	if L.Magnitude < 0.01 then return 0 end
	local Angle = math.deg(math.acos(math.clamp(L.Unit:Dot(D.Unit), -1, 1)))
	if Angle <= Perception.Primary / 2 then return 1 end
	if Angle <= Perception.Peripheral / 2 then return 0.5 end
	return 0
end

function Perception.MoveMult(Speed)
	for _, M in ipairs(Perception.Move) do
		if Speed <= M.Max then return M.Mult end
	end
	return 1
end

-- awareness per second. Visible = the fraction of head / torso / feet in clear line of sight (0..1).
function Perception.Rate(Type, Dist, Cone, Visible, Move, Exposure, Cautious)
	local T = Perception.Types[Type] or Perception.Types.Grunt
	if Dist > T.Range or Cone <= 0 or Visible <= 0 then return 0 end
	local Falloff = 1 - Perception.Falloff * (Dist / T.Range)
	return T.Fill * Falloff * Cone * Visible * Move * (Exposure or 1) * (Cautious and Perception.CautiousMult or 1)
end

return Perception
]==]
M.Parent = game.ReplicatedStorage.Modules.Data.Rensei
return "ok"
```

- [ ] **Step 4: Run the test** (§T). Expected: `PASS 4 / FAIL 0`.

- [ ] **Step 5: Export and commit.** Export (§E): Perception, Test_Perception. Commit (§C): `Perception: awareness numbers and maths (S1)`.

---

### Task 7: PerceptionService and enemies (slice S1)

**Files:**
- Create: `ServerScriptService.PerceptionService`.
- Modify: `ServerScriptService.EnemyService`: `Spawn` (≈ line 417–472), `Brain`'s `PickTarget` (≈ line 187–204) and the no-target branch (≈ line 276–287); `ServerScriptService.ServerHandler` (after line 93).
- Test: `ServerStorage.RenseiTests.Play_Perception`.

**Interfaces:**
- Consumes: `Perception.*` (Task 6); `ProgressionService.HitListeners` (a list of `function(Attacker: Model, Victim: Model, Result)`, fired for NPC victims too); `EnemyService.Active` (`[Rig] = E`).
- Produces:
  - `PerceptionService.Register(Rig, {Type, Faction?, Carrier?, Combat?}) -> State`; `.Unregister(Rig)`; `.Tracks(Rig) -> boolean`
  - `PerceptionService.Awareness(Rig, Player) -> number`; `.PhaseOf(Rig) -> "Unaware"|"Suspicious"|"Alert"|"Cautious"`
  - `PerceptionService.Target(Rig) -> Model?`: the character to fight now.
  - `PerceptionService.Goal(Rig) -> Vector3?`: where to walk when not fighting (investigate / search sweep).
  - `PerceptionService.Lose(Rig)`: gave up (leash) → Cautious.
  - `PerceptionService.Reset(Rig)`: back to Unaware with no memory (tests).
  - `PerceptionService.Alarm(Rig, Player)`: straight to Alert (it was hit).
  - `PerceptionService.Noise(Position, Radius)`: NPCs in radius go to look (Plan 2 feeds this).
  - `PerceptionService.Perceived(Player) -> {State}`: NPCs that perceive this player now (WitnessService).
  - `PerceptionService.ExposureOf`: a replaceable `function(Character) -> number` (1 until Plan 2).
  - `PerceptionService.SetAuto(On)`, `.Step(Dt)`: for tests.
  - Rig attribute `Awareness` = the phase name (for debugging and the future HUD).

- [ ] **Step 1: Write the Play test module** (Edit; it fails until Step 3):

```lua
local T = Instance.new("ModuleScript"); T.Name = "Play_Perception"
T.Source = [==[
-- S1 acceptance (spec §17.11), inside the game VM. Freezes the perception loop and steps it by hand so the
-- timings are exact; makes the test Grunt passive so it never swings at the tester.
local PS = require(game.ServerScriptService.PerceptionService)
local ES = require(game.ServerScriptService.EnemyService)
local P = require(game.ReplicatedStorage.Modules.Data.Rensei.Perception)
local Player = game.Players:GetPlayers()[1]
local C = Player.Character
local function FindGrunt()
	for Rig in pairs(ES.Active) do
		if Rig:GetAttribute("EnemyType") == "Grunt" and PS.Tracks(Rig) then return Rig end
	end
end
local function Run(Seconds) for _ = 1, math.floor(Seconds / 0.2 + 0.5) do PS.Step(0.2) end end
local function Put(Rig, Local) -- Local offset in the rig's space (-Z = in front)
	local Root = Rig.HumanoidRootPart
	local Pos = Root.Position + Root.CFrame:VectorToWorldSpace(Local)
	C:PivotTo(CFrame.lookAt(Pos, Root.Position))
	C.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
	task.wait(0.15)
end
return {
	S1 = function(T)
		local Rig = FindGrunt()
		T.True(Rig ~= nil, "a Grunt is registered with PerceptionService")
		local Home = C:GetPivot()
		Rig:SetAttribute("AIPassive", true)
		PS.SetAuto(false)
		PS.Reset(Rig) -- whatever it noticed before the test
		local Ok, Err = pcall(function()
			-- 1. behind it: unaware
			Put(Rig, Vector3.new(0, 0, 12))
			Run(3)
			T.Eq(PS.PhaseOf(Rig), "Unaware", "behind")
			T.True(PS.Awareness(Rig, Player) < 0.05, "behind: no awareness")
			-- 2. in front at 12 studs: fills at about the expected rate (Grunt 0.8 x (1 - 0.75 x 12/30) = 0.56/s)
			Put(Rig, Vector3.new(0, 0, -12))
			Run(1)
			T.Near(PS.Awareness(Rig, Player), 0.56, 0.15, "fill rate in front")
			Run(1.4)
			T.Eq(PS.PhaseOf(Rig), "Alert", "alert once full")
			T.Eq(PS.Target(Rig), C, "fights the player it sees")
			-- 3. out of sight and range: after Memory it searches, then turns Cautious
			Put(Rig, Vector3.new(0, 0, 70))
			Run(P.Memory + 0.4)
			T.Eq(PS.Target(Rig), nil, "lost")
			T.True(PS.Goal(Rig) ~= nil, "searching a spot")
			Run(P.SearchTime + 0.4)
			T.Eq(PS.PhaseOf(Rig), "Cautious", "cautious after a failed search")
		end)
		PS.Reset(Rig)
		PS.SetAuto(true)
		Rig:SetAttribute("AIPassive", nil)
		C:PivotTo(Home)
		if not Ok then error(Err, 0) end
	end,
	HitAlarms = function(T)
		local Rig = FindGrunt()
		PS.SetAuto(false)
		PS.Reset(Rig)
		PS.Alarm(Rig, Player)
		T.Eq(PS.PhaseOf(Rig), "Alert")
		PS.Lose(Rig)
		PS.SetAuto(true)
	end,
	NoiseSendsItToLook = function(T)
		local Rig = FindGrunt()
		PS.SetAuto(false)
		PS.Reset(Rig)
		local Spot = Rig.HumanoidRootPart.Position + Vector3.new(6, 0, 0)
		PS.Noise(Spot, 20)
		T.Eq(PS.PhaseOf(Rig), "Suspicious")
		T.True((PS.Goal(Rig) - Spot).Magnitude < 0.01, "goes where the sound was")
		Run(P.InvestigateTime + 0.4)
		T.True(PS.PhaseOf(Rig) ~= "Suspicious", "gives up")
		PS.Lose(Rig)
		PS.SetAuto(true)
	end,
}
]==]
T.Parent = game.ServerStorage.RenseiTests
return "ok"
```

- [ ] **Step 2: Run it in Play and confirm it fails** (§T; Morality isn't touched, so no snapshot is needed). Use the Task 5 runner Script with `Play_Perception` instead of `Play_Morality`; the snapshot lines are harmless. Expected: `ERROR ... PerceptionService is not a valid member`.

- [ ] **Step 3: Create PerceptionService** (Edit):

```lua
local S = Instance.new("ModuleScript"); S.Name = "PerceptionService"
S.Source = [==[
-- PerceptionService (2026-10-19, Morality × Reputation spec §17.1-17.2, §17.10; slice S1): what NPCs notice.
-- Every registered NPC keeps an awareness 0..1 per player. It fills while the NPC sees them (view cone, clear
-- lines to head / torso / feet, distance, movement; light in Plan 2) and drains otherwise. The NPC's phase:
--   Unaware -> Suspicious (>= 0.35): walks to what it noticed; gives up after 8 s
--   -> Alert (1): fights a player it sees (through EnemyService / CombatDirector, unchanged); if it loses
--      them it searches around the last known spot and brings in NPCs within 40 studs
--   -> Cautious (after a failed search): 3 min with sight x1.3, then Unaware.
-- Being hit puts an NPC straight to Alert on the attacker. Enemies ask Target(Rig) / Goal(Rig) instead of
-- the old distance aggro; arena and trial foes (Perception.AlwaysAware) keep the old rule. WitnessService
-- asks Perceived(Player). Watchers placed in the world (townsfolk, guards) are tagged RenseiWatcher with
-- attributes WatcherType / Faction / Carrier. Cost: only NPCs within 80 studs of a player update, every
-- 0.2 s, at most 3 sight rays each and 120 per tick (spec §17.10).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local P = require(ReplicatedStorage.Modules.Data.Rensei.Perception)

local PerceptionService = {}
local Npcs = {} -- [Rig] = state
PerceptionService.Npcs = Npcs

-- the light on a character, 0..1 (Plan 2 replaces this with lamps, daylight and shadow)
PerceptionService.ExposureOf = function() return 1 end

local Rays = RaycastParams.new()
Rays.FilterType = Enum.RaycastFilterType.Exclude
local Budget = 0 -- sight rays left this tick (all NPCs)

-- perception time: advanced by Step(Dt), so every timer (memory, investigate, search, cautious) follows the
-- steps exactly -- the live loop passes real time, the tests step it by hand
local Clock = 0
local function Now() return Clock end

local function Alive(Model)
	local H = Model and Model:FindFirstChildOfClass("Humanoid")
	return H ~= nil and H.Health > 0
end

local function SetPhase(S, Phase)
	if S.Phase == Phase then return end
	S.Phase = Phase
	S.Since = Now()
	S.Rig:SetAttribute("Awareness", Phase)
end

function PerceptionService.Register(Rig, Info)
	if Npcs[Rig] then return Npcs[Rig] end
	local S = {
		Rig = Rig, Type = Info.Type or "Grunt", Faction = Info.Faction, Carrier = Info.Carrier == true,
		Combat = Info.Combat ~= false,
		Aware = {}, Seen = {}, Spot = {}, -- [Player] = awareness / os.clock() last seen / position last seen
		Phase = "Unaware", Since = Now(), Focus = nil, LastKnown = nil,
		InvestigateUntil = 0, SearchUntil = nil, CautiousUntil = 0, Turn = 0, Seed = math.random() * math.pi * 2,
	}
	Npcs[Rig] = S
	Rig:SetAttribute("Awareness", "Unaware")
	Rig.Destroying:Once(function() Npcs[Rig] = nil end)
	return S
end

function PerceptionService.Unregister(Rig) Npcs[Rig] = nil end
function PerceptionService.Tracks(Rig) return Npcs[Rig] ~= nil end
function PerceptionService.Awareness(Rig, Player) local S = Npcs[Rig] return S and S.Aware[Player] or 0 end
function PerceptionService.PhaseOf(Rig) local S = Npcs[Rig] return S and S.Phase or "Unaware" end

-- head, torso and feet of a character
local function Points(Character)
	local Head = Character:FindFirstChild("Head")
	local Torso = Character:FindFirstChild("Torso") or Character:FindFirstChild("UpperTorso")
	local Root = Character:FindFirstChild("HumanoidRootPart")
	if not (Head and Torso and Root) then return nil end
	return {Head.Position, Torso.Position, Root.Position - Vector3.new(0, 2.6, 0)}
end

-- the fraction (0, 1/3, 2/3, 1) of those points the NPC has a clear line to, within its own ray budget
local function Visible(S, Eye, Character, Allowance)
	local Pts = Points(Character)
	if not Pts then return 0, Allowance end
	Rays.FilterDescendantsInstances = {S.Rig, Character}
	local Clear = 0
	for _, Pt in ipairs(Pts) do
		if Budget <= 0 or Allowance <= 0 then break end
		Budget -= 1
		Allowance -= 1
		if not workspace:Raycast(Eye, Pt - Eye, Rays) then Clear += 1 end
	end
	return Clear / 3, Allowance
end

-- an Alert NPC brings in the others close by: they come to look at Where
local function Call(S, Player, Where)
	local Root = S.Rig:FindFirstChild("HumanoidRootPart")
	if not Root or not Where then return end
	for Rig, O in pairs(Npcs) do
		local R = O ~= S and Rig:FindFirstChild("HumanoidRootPart")
		if R and (R.Position - Root.Position).Magnitude <= P.CallRadius and O.Phase ~= "Alert" then
			O.Aware[Player] = math.max(O.Aware[Player] or 0, P.Suspicious)
			O.LastKnown = Where
			O.InvestigateUntil = Now() + P.InvestigateTime
			SetPhase(O, "Suspicious")
		end
	end
end

local function Calm(S, T)
	for K, A in pairs(S.Aware) do S.Aware[K] = math.min(A, P.Suspicious - 0.01) end
	S.LastKnown = nil
	SetPhase(S, T < S.CautiousUntil and "Cautious" or "Unaware")
end

local function Decide(S, Best, BestPlayer, T)
	if S.Phase == "Alert" then
		local Seen = S.Focus and S.Seen[S.Focus]
		if Seen and T - Seen <= P.Memory then S.SearchUntil = nil return end
		if not S.SearchUntil then
			S.SearchUntil = T + P.SearchTime
			S.LastKnown = (S.Focus and S.Spot[S.Focus]) or S.LastKnown
			Call(S, S.Focus, S.LastKnown)
		elseif T >= S.SearchUntil then
			for K in pairs(S.Aware) do S.Aware[K] = 0 end
			S.Focus, S.SearchUntil, S.LastKnown = nil, nil, nil
			S.CautiousUntil = T + P.CautiousTime
			SetPhase(S, "Cautious")
		end
		return
	end
	if Best >= 1 then
		S.Focus, S.SearchUntil = BestPlayer, nil
		S.LastKnown = S.Spot[BestPlayer] or S.LastKnown
		SetPhase(S, "Alert")
		Call(S, BestPlayer, S.LastKnown)
	elseif Best >= P.Suspicious or (S.Phase == "Suspicious" and T < S.InvestigateUntil) then
		if S.Phase ~= "Suspicious" then
			SetPhase(S, "Suspicious")
			S.InvestigateUntil = T + P.InvestigateTime
		end
		if BestPlayer and Best >= P.Suspicious and S.Spot[BestPlayer] then S.LastKnown = S.Spot[BestPlayer] end
		if T >= S.InvestigateUntil then Calm(S, T) end
	elseif S.Phase == "Suspicious" then
		Calm(S, T)
	elseif S.Phase == "Cautious" and T >= S.CautiousUntil then
		SetPhase(S, "Unaware")
	end
end

local function Update(S, Dt, PlayerList)
	local Rig = S.Rig
	local Head = Rig:FindFirstChild("Head")
	local Root = Rig:FindFirstChild("HumanoidRootPart")
	if not (Head and Root) or not Alive(Rig) or Rig:GetAttribute("Knocked") then return end
	local T = Now()
	local Cautious = T < S.CautiousUntil
	local Type = P.Types[S.Type] or P.Types.Grunt
	local Allowance = P.RaysPerNpc
	local Best, BestPlayer = 0, nil
	-- rotate which player is checked first, so the ray allowance is shared fairly
	S.Turn = (S.Turn % math.max(1, #PlayerList)) + 1
	for I = 0, #PlayerList - 1 do
		local Player = PlayerList[((S.Turn + I - 1) % #PlayerList) + 1]
		local C = Player.Character
		local CR = C and C:FindFirstChild("HumanoidRootPart")
		local A = S.Aware[Player] or 0
		local Gain = 0
		if CR and Alive(C) and not C:GetAttribute("Knocked") then
			local To = CR.Position - Head.Position
			local Dist = To.Magnitude
			local Cone = Dist <= Type.Range and P.ConeMult(Root.CFrame.LookVector, To) or 0
			if Cone > 0 then
				local Vis
				Vis, Allowance = Visible(S, Head.Position, C, Allowance)
				if Vis > 0 then
					S.Seen[Player] = T
					S.Spot[Player] = CR.Position
					local V = CR.AssemblyLinearVelocity
					Gain = P.Rate(S.Type, Dist, Cone, Vis, P.MoveMult(Vector3.new(V.X, 0, V.Z).Magnitude),
						PerceptionService.ExposureOf(C), Cautious)
				end
			end
		end
		if Gain > 0 then
			A = math.min(1, A + Gain * Dt)
		elseif S.Phase ~= "Alert" then
			A = math.max(0, A - P.Drain * Dt)
		end
		S.Aware[Player] = A
		if A > Best then Best, BestPlayer = A, Player end
	end
	Decide(S, Best, BestPlayer, T)
end

function PerceptionService.Step(Dt)
	Clock += Dt
	Budget = P.RaysPerTick
	local List, Roots = {}, {}
	for _, Player in ipairs(Players:GetPlayers()) do
		local R = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
		if R then table.insert(List, Player); table.insert(Roots, R.Position) end
	end
	if #List == 0 then return end
	for Rig, S in pairs(Npcs) do
		local R = Rig:FindFirstChild("HumanoidRootPart")
		local Near = false
		if R then
			for _, Pos in ipairs(Roots) do
				if (Pos - R.Position).Magnitude <= P.ActiveRange then Near = true break end
			end
		end
		if Near or S.Phase ~= "Unaware" then Update(S, Dt, List) end
	end
end

local Auto = true
function PerceptionService.SetAuto(On) Auto = On end

-- the character this NPC fights now: Alert, and seen within the last Memory seconds
function PerceptionService.Target(Rig)
	local S = Npcs[Rig]
	if not S or S.Phase ~= "Alert" or not S.Focus then return nil end
	local Seen = S.Seen[S.Focus]
	if not Seen or Now() - Seen > P.Memory then return nil end
	local C = S.Focus.Character
	if C and Alive(C) and not C:GetAttribute("Knocked") then return C end
	return nil
end

-- where an NPC that isn't fighting should walk: the spot it's investigating, or a widening sweep around
-- where it lost you. nil = its own routine (home, patrol).
function PerceptionService.Goal(Rig)
	local S = Npcs[Rig]
	if not S then return nil end
	if S.Phase == "Suspicious" then return S.LastKnown end
	if S.Phase == "Alert" and S.SearchUntil and S.LastKnown then
		local Elapsed = P.SearchTime - (S.SearchUntil - Now())
		local Radius = 4 + Elapsed * 0.8
		local Angle = S.Seed + Elapsed * 0.9
		return S.LastKnown + Vector3.new(math.cos(Angle) * Radius, 0, math.sin(Angle) * Radius)
	end
	return nil
end

-- gave up on its target for good (the leash): Cautious
function PerceptionService.Lose(Rig)
	local S = Npcs[Rig]
	if not S then return end
	for K in pairs(S.Aware) do S.Aware[K] = 0 end
	S.Focus, S.SearchUntil, S.LastKnown = nil, nil, nil
	S.CautiousUntil = Now() + P.CautiousTime
	SetPhase(S, "Cautious")
end

-- back to a fresh, calm state (tests; a respawned NPC)
function PerceptionService.Reset(Rig)
	local S = Npcs[Rig]
	if not S then return end
	S.Aware, S.Seen, S.Spot = {}, {}, {}
	S.Focus, S.SearchUntil, S.LastKnown = nil, nil, nil
	S.InvestigateUntil, S.CautiousUntil = 0, 0
	SetPhase(S, "Unaware")
end

-- it was hit by this player: straight to Alert on them
function PerceptionService.Alarm(Rig, Player)
	local S = Npcs[Rig]
	local CR = S and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
	if not CR then return end
	local T = Now()
	S.Aware[Player], S.Seen[Player], S.Spot[Player] = 1, T, CR.Position
	S.Focus, S.SearchUntil, S.LastKnown = Player, nil, CR.Position
	SetPhase(S, "Alert")
end

-- a sound at Position: NPCs within Radius (x1.3 when Cautious) that aren't fighting go to look. They learn
-- where, not who (spec §17.3; Plan 2 adds the sound sources and wall muffling).
function PerceptionService.Noise(Position, Radius)
	local T = Now()
	for Rig, S in pairs(Npcs) do
		local R = Rig:FindFirstChild("HumanoidRootPart")
		local Reach = Radius * ((T < S.CautiousUntil) and P.CautiousMult or 1)
		if R and S.Phase ~= "Alert" and (R.Position - Position).Magnitude <= Reach then
			S.LastKnown = Position
			S.InvestigateUntil = T + P.InvestigateTime
			SetPhase(S, "Suspicious")
		end
	end
end

-- NPCs that perceive this player right now (they saw them in the last second, or are at least Suspicious
-- of them): the witnesses of whatever the player does (WitnessService)
function PerceptionService.Perceived(Player)
	local Out = {}
	local T = Now()
	for Rig, S in pairs(Npcs) do
		if Alive(Rig) and not Rig:GetAttribute("Knocked") then
			local Seen = S.Seen[Player]
			if (Seen and T - Seen <= 1) or (S.Aware[Player] or 0) >= P.Suspicious then table.insert(Out, S) end
		end
	end
	return Out
end

function PerceptionService.Start()
	local Acc = 0
	RunService.Heartbeat:Connect(function(Dt)
		if not Auto then return end
		Acc += Dt
		if Acc < P.Tick then return end
		local Step = math.min(Acc, 1)
		Acc = 0
		local Ok, Err = pcall(PerceptionService.Step, Step)
		if not Ok then warn("PerceptionService:", Err) end
	end)
	table.insert(require(ServerScriptService.ProgressionService).HitListeners, function(Attacker, Victim)
		local Player = Players:GetPlayerFromCharacter(Attacker)
		if Player and Npcs[Victim] then PerceptionService.Alarm(Victim, Player) end
	end)
	Players.PlayerRemoving:Connect(function(Player)
		for _, S in pairs(Npcs) do
			S.Aware[Player], S.Seen[Player], S.Spot[Player] = nil, nil, nil
			if S.Focus == Player then S.Focus = nil end
		end
	end)
	local function Watch(Model)
		if not Model:IsA("Model") then return end
		PerceptionService.Register(Model, {
			Type = Model:GetAttribute("WatcherType") or "Witness", Faction = Model:GetAttribute("Faction"),
			Carrier = Model:GetAttribute("Carrier") == true, Combat = false,
		})
	end
	for _, M in ipairs(CollectionService:GetTagged("RenseiWatcher")) do Watch(M) end
	CollectionService:GetInstanceAddedSignal("RenseiWatcher"):Connect(Watch)
end

return PerceptionService
]==]
S.Parent = game.ServerScriptService
return "ok"
```

- [ ] **Step 4: Wire EnemyService** (Edit; back up first, §B). Read lines 1–40 to find the existing `local` service variables (`ReplicatedStorage`, `ServerScriptService`); use them if present, else `game:GetService(...)`.
  1. **Requires.** Near the other requires at the top, add:

```lua
local PerceptionService = require(game:GetService("ServerScriptService").PerceptionService)
local Perception = require(game:GetService("ReplicatedStorage").Modules.Data.Rensei.Perception)
```

  2. **Register in `Spawn`.** In `function Spawn(Part)`, immediately before `task.spawn(Brain, E)`, add:

```lua
	-- notices players through sight and alert phases (PerceptionService); arena / trial foes keep distance aggro
	if not Perception.AlwaysAware[Type] then
		PerceptionService.Register(Rig, {Type = Perception.EnemyTypes[Type] or "Grunt", Faction = Def.Faction, Combat = true})
	end
```

  3. **Targets.** In `Brain`, rename `local function PickTarget()` to `local function NearestTarget()`. Keep its comment, which now applies to arena foes. Directly after its `end`, add:

```lua
	-- who to fight: perceived players only (PerceptionService), still inside the leash; arena / trial foes
	-- use the nearest player as before
	local function PickTarget()
		if not PerceptionService.Tracks(Rig) then return NearestTarget() end
		local C = PerceptionService.Target(Rig)
		local R = C and C:FindFirstChild("HumanoidRootPart")
		if not R then return nil end
		if (Flat(R.Position - E.Home.Position)).Magnitude > Def.LeashRange then
			PerceptionService.Lose(Rig) -- beyond the leash: give up, warily
			return nil
		end
		return C
	end
```

  4. **Investigate and search.** Replace this block:

```lua
		if not Target then
			-- leash: walk home and recover
			local Home = E.Home.Position
```

  with:

```lua
		if not Target then
			-- investigating a noise / sighting, or sweeping where it lost a player (inside the leash)
			local Goal = PerceptionService.Goal(Rig)
			if Goal and (Flat(Goal - E.Home.Position)).Magnitude <= Def.LeashRange then
				if (Flat(Goal - Root.Position)).Magnitude > 3 then
					Humanoid:MoveTo(Goal)
					SetWalking(true)
				else
					Humanoid:MoveTo(Root.Position)
					SetWalking(false)
				end
				continue
			end
			-- leash: walk home and recover
			local Home = E.Home.Position
```

- [ ] **Step 5: Start the service.** In `ServerScriptService.ServerHandler` (back up first), right after the line `require(ServerScriptService.MoralityService).Start() -- deeds ledger: ...`, add:

```lua
require(ServerScriptService.PerceptionService).Start() -- what NPCs notice: sight, alert phases (S1)
```

- [ ] **Step 6: Run the Play test** (§T). Expected: `PASS 3 / FAIL 0`.
  - Also read the console: no `PerceptionService:` warnings.
  - Measure the cost: in the game VM, time 50 calls of `PerceptionService.Step(0.2)` with `os.clock()` and report ms per step. Expect < 2 ms with today's enemy count.

- [ ] **Step 7: Play-feel check (manual, with real input).**
  - Walk up behind a Grunt camp: no aggro until it turns or you enter its cone.
  - Sprint in front of it: it notices about twice as fast.
  - Break line of sight: it searches, then wanders home and stays Cautious.
  - Hit one from behind: instant fight.
  - Record any surprises in the Changelog entry.

- [ ] **Step 8: Export and commit.** Export (§E): PerceptionService (new), EnemyService, ServerHandler, Play_Perception. Commit (§C): `PerceptionService: sight cones, awareness and alert phases; enemies aggro through it (S1)`.

---

### Task 8: WitnessService and the world's watchers

**Files:**
- Create: `ServerScriptService.WitnessService`.
- Modify: NPC models in `Workspace.World.NPCs` (tag `RenseiWatcher` + attributes; a one-off script).
- Test: `ServerStorage.RenseiTests.Test_Witness` (pure parts, Edit) + a Play check.

**Interfaces:**
- Consumes: `PerceptionService.Perceived(Player) -> {State{Rig, Faction, Carrier, Type}}` (Task 7); `Rensei.Identities.WitnessRange`.
- Produces:
  - `WitnessService.Weights = {Npc = 1, Agent = 2, Evidence = 3}`
  - `WitnessService.Strength(Npcs: {{Carrier: boolean}}, Evidence: number?) -> number` (pure)
  - `WitnessService.Capture(Player, DeedId, Evidence?) -> {Npcs = {...}, Players = {Player}, Strength = number}`
  - `WitnessService.Note(WitnessUserId, SubjectUserId, DeedId, At)`; `.CanReport(WitnessUserId, SubjectUserId, DeedId, Now) -> boolean`; `.Forget(WitnessUserId, SubjectUserId, DeedId)`
  - `WitnessService.ReportWindow = 1800` (seconds)

- [ ] **Step 1: Write the failing test** (Edit):

```lua
local T = Instance.new("ModuleScript"); T.Name = "Test_Witness"
T.Source = [==[
local W = require(game.ServerScriptService.WitnessService)
return {
	StrengthCountsWitnessesAndEvidence = function(T)
		T.Eq(W.Strength({}, 0), 0, "a ghost")
		T.Eq(W.Strength({{Carrier = false}, {Carrier = false}}), 2, "two townsfolk")
		T.Eq(W.Strength({{Carrier = true}}, 1), 5, "an agent and one evidence")
	end,
	ReportsNeedARecordedWitness = function(T)
		W.Note(1, 2, "d", 1000)
		T.True(W.CanReport(1, 2, "d", 1000 + 60))
		T.True(not W.CanReport(3, 2, "d", 1060), "someone who didn't see it")
		T.True(not W.CanReport(1, 2, "other", 1060), "another deed")
		T.True(not W.CanReport(1, 2, "d", 1000 + W.ReportWindow + 1), "too late")
		W.Forget(1, 2, "d")
		T.True(not W.CanReport(1, 2, "d", 1060), "reported once")
	end,
}
]==]
T.Parent = game.ServerStorage.RenseiTests
return "ok"
```

- [ ] **Step 2: Run it** (§T). Expected: an error, `WitnessService is not a valid member`.

- [ ] **Step 3: Create WitnessService** (Edit):

```lua
local S = Instance.new("ModuleScript"); S.Name = "WitnessService"
S.Source = [==[
-- WitnessService (2026-10-19, Morality × Reputation spec §4): who saw a deed. NPC witnesses come from
-- PerceptionService: an NPC only witnesses what it actually perceived (spec §17). Player witnesses are
-- players within Identities.WitnessRange with a clear line of sight (IdentityService's rule); they're
-- remembered here, in server memory, so they can report the deed at a desk later (RumourService.Report).
-- Strength (PROPOSAL): 1 per NPC witness, 2 per agent (Carrier: State / Circle agents), 3 per evidence.
-- No witness and no evidence = strength 0 = no rumour (a ghost).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Rules = require(ReplicatedStorage.Modules.Data.Rensei.Identities)

local WitnessService = {}
WitnessService.Weights = {Npc = 1, Agent = 2, Evidence = 3}
WitnessService.ReportWindow = 30 * 60 -- a player witness may report within 30 min (PROPOSAL)

local Seen = {} -- [WitnessUserId] = {[SubjectUserId .. ":" .. DeedId] = os.time()}

function WitnessService.Strength(Npcs, Evidence)
	local S = 0
	for _, W in ipairs(Npcs) do S += W.Carrier and WitnessService.Weights.Agent or WitnessService.Weights.Npc end
	return S + (Evidence or 0) * WitnessService.Weights.Evidence
end

function WitnessService.Note(WitnessId, SubjectId, DeedId, At)
	Seen[WitnessId] = Seen[WitnessId] or {}
	Seen[WitnessId][SubjectId .. ":" .. DeedId] = At
end

function WitnessService.CanReport(WitnessId, SubjectId, DeedId, Now)
	local At = Seen[WitnessId] and Seen[WitnessId][SubjectId .. ":" .. DeedId]
	return At ~= nil and Now - At <= WitnessService.ReportWindow
end

function WitnessService.Forget(WitnessId, SubjectId, DeedId)
	if Seen[WitnessId] then Seen[WitnessId][SubjectId .. ":" .. DeedId] = nil end
end

local Rays = RaycastParams.new()
Rays.FilterType = Enum.RaycastFilterType.Exclude

function WitnessService.Capture(Player, DeedId, Evidence)
	local PerceptionService = require(ServerScriptService.PerceptionService)
	local Npcs = {}
	for _, S in ipairs(PerceptionService.Perceived(Player)) do
		table.insert(Npcs, {Rig = S.Rig, Faction = S.Faction, Carrier = S.Carrier, Type = S.Type})
	end
	local Saw = {}
	local C = Player.Character
	local Head = C and C:FindFirstChild("Head")
	if Head then
		local Now = os.time()
		for _, Other in ipairs(Players:GetPlayers()) do
			local OC = Other ~= Player and Other.Character
			local Eye = OC and OC:FindFirstChild("Head")
			if Eye and (Eye.Position - Head.Position).Magnitude <= Rules.WitnessRange then
				Rays.FilterDescendantsInstances = {C, OC}
				if not workspace:Raycast(Eye.Position, Head.Position - Eye.Position, Rays) then
					table.insert(Saw, Other)
					WitnessService.Note(Other.UserId, Player.UserId, DeedId, Now)
				end
			end
		end
	end
	return {Npcs = Npcs, Players = Saw, Strength = WitnessService.Strength(Npcs, Evidence)}
end

Players.PlayerRemoving:Connect(function(Player) Seen[Player.UserId] = nil end)

return WitnessService
]==]
S.Parent = game.ServerScriptService
return "ok"
```

- [ ] **Step 4: Run the test** (§T). Expected: `PASS 2 / FAIL 0`.

- [ ] **Step 5: Tag the world's watchers** (Edit; this is content, listed for the owner to review). Run:

```lua
local CS = game:GetService("CollectionService")
local Foundry = workspace.World.Map:FindFirstChild("FoundryYard") and workspace.World.Map.FoundryYard:FindFirstChild("AreaVolume")
local function Inside(Part, Pos)
	if not Part then return false end
	local L = Part.CFrame:PointToObjectSpace(Pos)
	return math.abs(L.X) <= Part.Size.X / 2 and math.abs(L.Y) <= Part.Size.Y / 2 and math.abs(L.Z) <= Part.Size.Z / 2
end
local Out = {}
for _, M in ipairs(workspace.World.NPCs:GetChildren()) do
	local H = M:IsA("Model") and M:FindFirstChildOfClass("Humanoid")
	local R = M:FindFirstChild("HumanoidRootPart")
	if H and R and not M:GetAttribute("EnemyType") and not CS:HasTag(M, "RenseiWatcher") then
		local Faction = M:GetAttribute("Faction")
		local Carrier = false
		if not Faction then
			if M:GetAttribute("TakesPrisoners") then Faction, Carrier = "Authority", true -- captors are State officers
			elseif Inside(Foundry, R.Position) then Faction = "Foundry"
			else Faction = "Townsfolk" end
		end
		M:SetAttribute("Faction", Faction)
		M:SetAttribute("Carrier", Carrier)
		M:SetAttribute("WatcherType", Carrier and "Agent" or "Witness")
		CS:AddTag(M, "RenseiWatcher")
		table.insert(Out, M.Name .. " -> " .. Faction .. (Carrier and " (agent)" or ""))
	end
end
return table.concat(Out, "\n")
```

  - Paste the returned list into the Changelog entry under "Watchers (PROPOSAL, owner to review)".

- [ ] **Step 6: Play check.**
  1. Stand in front of a tagged Foundry NPC for 2 s.
  2. In the game VM, run `require(game.ServerScriptService.WitnessService).Capture(Player, "x").Strength`. Expected: ≥ 1.
  3. Stand behind it, out of its cone: the same call returns 0 after 6 s (awareness drained below Suspicious).

- [ ] **Step 7: Export and commit.** Export (§E): WitnessService, Test_Witness. Commit (§C): `WitnessService: perceived witnesses, strength, player-witness memory; watchers tagged`.

---

### Task 9: RumourService Core (pure spread)

**Files:**
- Create: `ServerScriptService.RumourService` (a placeholder module for now, replaced in Task 10) with the child ModuleScript `Core`.
- Test: `ServerStorage.RenseiTests.Test_RumourCore`.

**Interfaces:**
- Consumes: `Reputation.Land` (Task 4); `Regions.Links`, `Regions.Reach`, `Regions.Regions` (Task 3).
- Produces (`M` = a profile's `Morality`):
  - `Core.Spawn(M, DeedId, Origin, Strength, Now) -> Rumour?`. If a live rumour of the same deed from the same origin exists, it's returned unchanged. `Strength <= 0` → nil.
  - `Core.Advance(M, Now) -> {{Rumour, Place, Carrier, Heard = {Faction}, At}}`
  - `Core.Silence(M, RumourId, Weight) -> Rumour?`
  - `Core.LandReport(M, DeedId, Region, Faction, Now) -> {Faction}`
  - `Core.MaxLive = 20`, `Core.MaxNews = 10`
  - `Rumour = {Id, Deed, Origin, Strength, Born, Reached = {[Region] = time}, Fronts = {{Place, Carrier, ArrivesAt, Hops}}, Sent = {["To/Carrier"] = true}, Suppressed}`
  - News entries are written to `M.News` (newest first): `{At, Place, Deed, Heard = {...}, Report = true?}`.

- [ ] **Step 1: Write the failing test** (Edit):

```lua
local T = Instance.new("ModuleScript"); T.Name = "Test_RumourCore"
T.Source = [==[
local Rensei = game.ReplicatedStorage.Modules.Data.Rensei
local Core = require(game.ServerScriptService.RumourService.Core)
local Reputation = require(Rensei.Reputation)
local Regions = require(Rensei.Regions)
local function Fresh()
	local M = {Deeds = {d = {At = 0, Count = 1}}, Places = {}, Rumours = {}, News = {}}
	Reputation.Land(M, "Foundry", "d", Regions.FactionsAt("Foundry"), 0) -- heard where it happened
	return M
end
local function Heard(M, Region, F)
	local P = M.Places[Region]
	return P ~= nil and P.Known.d ~= nil and P.Known.d[F] ~= nil
end
return {
	DispatchThenGossip = function(T)
		local M = Fresh()
		T.True(Core.Spawn(M, "d", "Foundry", 2, 0) ~= nil)
		T.Eq(#Core.Advance(M, 119), 0, "nothing before 2 min")
		local A = Core.Advance(M, 120)
		T.Eq(#A, 1); T.Eq(A[1].Place, "City"); T.Same(A[1].Heard, {"Authority"}, "dispatch: only the Authority")
		T.True(not Heard(M, "City", "Townsfolk"))
		T.Eq(#Core.Advance(M, 599), 0)
		local B = Core.Advance(M, 600)
		T.Eq(#B, 1, "gossip at 10 min")
		T.True(table.find(B[1].Heard, "Circle") and table.find(B[1].Heard, "Townsfolk"), "gossip reaches the Circle and Townsfolk")
		T.True(table.find(B[1].Heard, "IshvalanCommunity") ~= nil, "and the communities (present everywhere)")
		T.True(not table.find(B[1].Heard, "Authority"), "the Authority heard already, by dispatch")
		T.Eq(#Core.Advance(M, 100000), 0, "strength 2: one hop, no further")
		T.True(not M.Places.Lindenmoor, "never reached Lindenmoor")
		T.Eq(#M.News, 2)
	end,
	OncePerPlace = function(T)
		local M = Fresh()
		Core.Spawn(M, "d", "Foundry", 5, 0)
		Core.Advance(M, 100000)
		local Count = 0
		for _, N in ipairs(M.News) do if N.Place == "City" then Count += 1 end end
		T.Eq(Count, 2, "City: dispatch once + gossip once, never repeated")
		T.True(Heard(M, "Lindenmoor", "Townsfolk"), "strength 5 goes further")
	end,
	OfflineCatchUpMatchesOnline = function(T)
		local A, B = Fresh(), Fresh()
		Core.Spawn(A, "d", "Foundry", 4, 0); Core.Spawn(B, "d", "Foundry", 4, 0)
		for Now = 0, 7200, 60 do Core.Advance(A, Now) end
		Core.Advance(B, 7200)
		T.Same(A.Places, B.Places, "same places")
		T.Same(A.News, B.News, "same news, same order")
	end,
	SilencingStopsIt = function(T)
		local M = Fresh()
		local R = Core.Spawn(M, "d", "Foundry", 2, 0)
		Core.Silence(M, R.Id, 1)
		T.Eq(#Core.Advance(M, 100000), 0, "strength 1: hop 1 lands nothing")
		local M2 = Fresh()
		local R2 = Core.Spawn(M2, "d", "Foundry", 2, 0)
		Core.Silence(M2, R2.Id, 2)
		T.True(R2.Suppressed, "suppressed at 0")
	end,
	SameDeedSameOriginReusesTheLiveRumour = function(T)
		local M = Fresh()
		local R1 = Core.Spawn(M, "d", "Foundry", 2, 0)
		local R2 = Core.Spawn(M, "d", "Foundry", 2, 30)
		T.Eq(R1, R2); T.Eq(#M.Rumours, 1)
	end,
	ReportLandsAtOnceForTheDesk = function(T)
		local M = Fresh()
		T.Same(Core.LandReport(M, "d", "City", "Authority", 50), {"Authority"})
		T.Same(Core.LandReport(M, "d", "City", "Authority", 60), {}, "once")
		T.True(M.News[1].Report)
	end,
	AtMostTwentyLive = function(T)
		local M = Fresh()
		for I = 1, 25 do
			M.Deeds["d" .. I] = {At = 0, Count = 1}
			Core.Spawn(M, "d" .. I, "Foundry", 3, I)
		end
		T.Eq(#M.Rumours, Core.MaxLive)
		T.Eq(M.Rumours[#M.Rumours].Deed, "d25", "newest kept")
	end,
	NewsIsBounded = function(T)
		local M = Fresh()
		for I = 1, 15 do Core.LandReport(M, "x" .. I, "City", "Authority", I) end
		T.Eq(#M.News, Core.MaxNews)
		T.Eq(M.News[1].Deed, "x15", "newest first")
	end,
}
]==]
T.Parent = game.ServerStorage.RenseiTests
return "ok"
```

- [ ] **Step 2: Create the placeholder parent and run the test.** Create `ServerScriptService.RumourService` as a ModuleScript whose Source is `return {}` (Task 10 replaces it). Run (§T). Expected: an error, `Core is not a valid member`.

- [ ] **Step 3: Create Core** (Edit):

```lua
local C = Instance.new("ModuleScript"); C.Name = "Core"
C.Source = [==[
-- RumourService.Core (2026-10-19, Morality × Reputation spec §5): how word of a deed travels the region
-- graph (Rensei.Regions). Pure: it works on a profile's Morality table and a time you pass in, so the same
-- code runs the online tick, the offline catch-up on join, and the tests with a fake clock.
--   * A rumour starts where the deed happened (already heard there) with a Strength (WitnessService).
--   * It sends a front down every link from its origin. A front arriving at a region lands the deed for the
--     factions its carrier reaches there (Rensei.Reputation: once per faction per place), then the rumour
--     sends that carrier on from there (gossip spreads gossip, dispatch relays dispatch).
--   * Each hop costs 1 Strength: a front lands only while Strength - Hops > 0.
--   * Fronts are processed in arrival-time order, so catching up after hours offline gives exactly what
--     being online would have.
--   * At most 20 live rumours (the oldest finished ones go first); the last 10 arrivals are kept as News
--     (the reason lines: "Word reached the City").

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rensei = ReplicatedStorage.Modules.Data.Rensei
local Regions = require(Rensei.Regions)
local Reputation = require(Rensei.Reputation)

local Core = {}
Core.MaxLive = 20
Core.MaxNews = 10

local function Ensure(M)
	M.Rumours = M.Rumours or {}
	M.Places = M.Places or {}
	M.News = M.News or {}
	return M
end

local function News(M, Item)
	table.insert(M.News, 1, Item)
	while #M.News > Core.MaxNews do table.remove(M.News) end
end

-- fronts down the links from Region (only Carrier's links when given), Hops hops from the origin
local function Push(R, Region, Now, Carrier, Hops)
	if R.Strength - Hops <= 0 then return end
	for _, L in ipairs(Regions.Links(Region)) do
		local Key = L.To .. "/" .. L.Carrier
		if (not Carrier or L.Carrier == Carrier) and not R.Sent[Key] then
			R.Sent[Key] = true
			table.insert(R.Fronts, {Place = L.To, Carrier = L.Carrier, ArrivesAt = Now + L.Minutes * 60, Hops = Hops})
		end
	end
end

local function Trim(M)
	while #M.Rumours > Core.MaxLive do
		local Drop = 1
		for I, R in ipairs(M.Rumours) do
			if #R.Fronts == 0 or R.Suppressed then Drop = I break end
		end
		table.remove(M.Rumours, Drop)
	end
end

function Core.Spawn(M, DeedId, Origin, Strength, Now)
	Ensure(M)
	if not Strength or Strength <= 0 or not Regions.Regions[Origin] then return nil end
	for _, R in ipairs(M.Rumours) do
		if R.Deed == DeedId and R.Origin == Origin and not R.Suppressed and #R.Fronts > 0 then return R end
	end
	local R = {
		Id = DeedId .. "@" .. Origin .. "@" .. tostring(Now), Deed = DeedId, Origin = Origin, Strength = Strength,
		Born = Now, Reached = {[Origin] = Now}, Fronts = {}, Sent = {}, Suppressed = false,
	}
	Push(R, Origin, Now, nil, 1)
	table.insert(M.Rumours, R)
	Trim(M)
	return R
end

function Core.Advance(M, Now)
	Ensure(M)
	local Out = {}
	while true do
		local BestR, BestI, BestT
		for _, R in ipairs(M.Rumours) do
			if not R.Suppressed then
				for I, F in ipairs(R.Fronts) do
					if F.ArrivesAt <= Now and (not BestT or F.ArrivesAt < BestT) then BestR, BestI, BestT = R, I, F.ArrivesAt end
				end
			end
		end
		if not BestR then break end
		local F = table.remove(BestR.Fronts, BestI)
		if BestR.Strength - F.Hops > 0 then
			local Heard = Reputation.Land(M, F.Place, BestR.Deed, Regions.Reach(F.Place, F.Carrier), F.ArrivesAt)
			BestR.Reached[F.Place] = BestR.Reached[F.Place] or F.ArrivesAt
			Push(BestR, F.Place, F.ArrivesAt, F.Carrier, F.Hops + 1)
			if #Heard > 0 then
				News(M, {At = F.ArrivesAt, Place = F.Place, Deed = BestR.Deed, Heard = Heard})
				table.insert(Out, {Rumour = BestR, Place = F.Place, Carrier = F.Carrier, Heard = Heard, At = F.ArrivesAt})
			end
		end
	end
	return Out
end

-- a witness silenced: the rumour loses that witness's weight; at 0 it's dead, fronts on the road included
function Core.Silence(M, RumourId, Weight)
	for _, R in ipairs(Ensure(M).Rumours) do
		if R.Id == RumourId then
			R.Strength -= Weight
			if R.Strength <= 0 then R.Suppressed = true; R.Fronts = {} end
			return R
		end
	end
	return nil
end

-- a player witness reported the deed at a desk: it lands at once there, for that desk's faction
function Core.LandReport(M, DeedId, Region, Faction, Now)
	Ensure(M)
	local Heard = Reputation.Land(M, Region, DeedId, {Faction}, Now)
	if #Heard > 0 then News(M, {At = Now, Place = Region, Deed = DeedId, Heard = Heard, Report = true}) end
	return Heard
end

return Core
]==]
C.Parent = game.ServerScriptService.RumourService
return "ok"
```

- [ ] **Step 4: Run the test** (§T). Expected: `PASS 8 / FAIL 0`.
  - The communities are diaspora (present in every region), so gossip lands for them too. That's intended: their people hear word anywhere.

- [ ] **Step 5: Export and commit.** Export (§E): `RumourService/Core.lua` (as `Scripts/ServerScriptService/RumourService/Core.lua`), Test_RumourCore. Commit (§C): `RumourService.Core: rumour spread over the region graph (pure, tested)`.

---

### Task 10: RumourService (tick, catch-up, deed hook, reports) — slice R2 acceptance

**Files:**
- Modify: `ServerScriptService.RumourService` (replace the placeholder Source); `ServerScriptService.MoralityService` (`Joined` catch-up); `ServerScriptService.ServerHandler`.
- Test: `ServerStorage.RenseiTests.Play_Rumours`.

**Interfaces:**
- Consumes: `Core.*` (Task 9); `MoralityService.Recorded`, `.Refresh` (Task 5); `WitnessService.CanReport` / `.Forget` (Task 8).
- Produces:
  - `RumourService.SetClock(Fn?)`: nil restores `os.time`. `RumourService.Now() -> number`.
  - `RumourService.Tick(Player) -> number`: the arrivals applied.
  - `RumourService.Report(Reporter, Subject, DeedId, Region, Faction) -> (boolean, string?)`
  - `RumourService.Start()`

- [ ] **Step 1: Write the Play test** (Edit):

```lua
local T = Instance.new("ModuleScript"); T.Name = "Play_Rumours"
T.Source = [==[
-- R2 acceptance (spec §16) in the game VM, on a test-only deed injected into the Deeds table. Run inside the
-- snapshot / restore runner (Conventions §S).
local RumourService = require(game.ServerScriptService.RumourService)
local MoralityService = require(game.ServerScriptService.MoralityService)
local PS = require(game.ServerScriptService.ProgressionService)
local Deeds = require(game.ReplicatedStorage.Modules.Data.Rensei.Deeds)
local Player = game.Players:GetPlayers()[1]
return {
	R2 = function(T)
		Deeds.__test_rumour = {Text = "Test: a deed for rumours", Standing = {Authority = 12, Townsfolk = -6}, Scope = "Local"}
		local Base = os.time()
		RumourService.SetClock(function() return Base end)
		local Ok, Err = pcall(function()
			T.True(MoralityService.Record(Player, "__test_rumour", true, {Region = "Foundry", Strength = 2}))
			task.wait(0.2) -- the Recorded listener spawns the rumour
			local M = PS.GetData(Player).Morality
			local Live
			for _, R in ipairs(M.Rumours) do if R.Deed == "__test_rumour" then Live = R end end
			T.True(Live ~= nil, "a rumour started")
			local Before = M.Standing.Authority or 0
			RumourService.SetClock(function() return Base + 121 end)
			T.Eq(RumourService.Tick(Player), 1, "dispatch reached the City")
			T.Near((M.Standing.Authority or 0) - Before, 12, 1e-6, "Authority: City is its only region -> full")
			RumourService.SetClock(function() return Base + 601 end)
			T.Eq(RumourService.Tick(Player), 1, "gossip reached the City")
			RumourService.SetClock(function() return Base + 601 end)
			T.Eq(RumourService.Tick(Player), 0, "idempotent")
		end)
		RumourService.SetClock(nil)
		Deeds.__test_rumour = nil
		if not Ok then error(Err, 0) end
	end,
	ReportNeedsAWitness = function(T)
		local Ok, Why = RumourService.Report(Player, Player, "reported_lise", "City", "Authority")
		T.True(not Ok, "no recorded witness")
		T.True(Why ~= nil)
	end,
}
]==]
T.Parent = game.ServerStorage.RenseiTests
return "ok"
```

- [ ] **Step 2: Run it in Play** (§T, §S). Expected: `FAIL R2: ... attempt to call a nil value (field 'SetClock')`.

- [ ] **Step 3: Replace the RumourService Source** (Edit):

```lua
game.ServerScriptService.RumourService.Source = [==[
-- RumourService (2026-10-19, Morality × Reputation spec §5; slice R2): word of a player's deeds travels
-- between regions over real time. The spread itself is RumourService.Core (pure); this runs it:
--   * a Local / Public deed that someone perceived (MoralityService.Recorded, Strength > 0) starts a rumour;
--   * every 60 s, and once on join (offline catch-up), each player's rumours advance to the current time
--     and MoralityService.Refresh rebuilds standing (tier banners for any change);
--   * Report: a player the server recorded as a witness (WitnessService) reports the deed at a State desk
--     or a Circle drop; it lands there at once. Reports for deeds they didn't witness are refused.
-- Silencing witnesses and vouching are the next plans' content (they call Core.Silence); the clock can be
-- swapped for tests (SetClock).

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Core = require(script.Core)
local ProgressionService = require(ServerScriptService.ProgressionService)

local RumourService = {Core = Core}
RumourService.TickSeconds = 60

local Clock = os.time
function RumourService.SetClock(Fn) Clock = Fn or os.time end
function RumourService.Now() return Clock() end

local function Morality(Player)
	local Data = ProgressionService.GetData(Player)
	return Data and Data.Morality
end

function RumourService.Tick(Player)
	local M = Morality(Player)
	if not M then return 0 end
	local Arrivals = Core.Advance(M, Clock())
	if #Arrivals > 0 then require(ServerScriptService.MoralityService).Refresh(Player) end
	return #Arrivals
end

function RumourService.Report(Reporter, Subject, DeedId, Region, Faction)
	local WitnessService = require(ServerScriptService.WitnessService)
	local Now = Clock()
	if not WitnessService.CanReport(Reporter.UserId, Subject.UserId, DeedId, Now) then
		return false, "You didn't witness that."
	end
	local M = Morality(Subject)
	if not M then return false, "They aren't here." end
	local Heard = Core.LandReport(M, DeedId, Region, Faction, Now)
	WitnessService.Forget(Reporter.UserId, Subject.UserId, DeedId)
	if #Heard > 0 then require(ServerScriptService.MoralityService).Refresh(Subject) end
	return true
end

local function OnRecorded(Player, DeedId, Def, Info)
	if Def.Birth or Info.Scope == "Private" or (Info.Strength or 0) <= 0 then return end
	local M = Morality(Player)
	if M then Core.Spawn(M, DeedId, Info.Region, Info.Strength, Clock()) end
end

function RumourService.Start()
	table.insert(require(ServerScriptService.MoralityService).Recorded, OnRecorded)
	task.spawn(function()
		while true do
			task.wait(RumourService.TickSeconds)
			for _, Player in ipairs(Players:GetPlayers()) do
				local Ok, Err = pcall(RumourService.Tick, Player)
				if not Ok then warn("RumourService:", Err) end
			end
		end
	end)
end

return RumourService
]==]
return "ok"
```

- [ ] **Step 4: Catch up on join.** In `MoralityService`'s `Joined`, after `MoralityService.RecordOutcomes(Player, true)`, add:

```lua
				-- word that travelled while they were away (offline catch-up)
				pcall(function() require(ServerScriptService.RumourService).Tick(Player) end)
```

- [ ] **Step 5: Start it.** In `ServerHandler`, after the PerceptionService line from Task 7, add:

```lua
require(ServerScriptService.RumourService).Start() -- word of deeds travelling between regions (R2)
```

- [ ] **Step 6: Run the Play test** (§T, §S). Expected: `PASS 2 / FAIL 0`.
  - Then run **all** suites again: Edit `Test_*` (6 suites) and Play `Play_Morality`, `Play_Perception`, `Play_Rumours`. All must pass. Read the console: no `RumourService:` / `PerceptionService:` / `MoralityService` errors.
  - Confirm the profile was restored: read `Data.Morality` in the game VM and compare with the snapshot, `HttpService:JSONEncode` equal.

- [ ] **Step 7: Rejoin catch-up (manual).**
  1. In Play, record `__test_rumour` (injected as in the test) with `{Region = "Foundry", Strength = 2}` inside the snapshot runner.
  2. Stop Play, wait 3 real minutes, start Play.
  3. Check that `Morality.Places.City.Known.__test_rumour.Authority` exists (dispatch, 2 min) and that Townsfolk hasn't heard yet (gossip, 10 min).
  4. Then restore the snapshot by hand: run §S's restore with the saved JSON. Write the JSON to a `StringValue` in `ServerStorage` before stopping Play the first time, so it survives the restart. Remove the `StringValue` afterwards.

- [ ] **Step 8: Export, document, commit.**
  - **Export** (§E): RumourService, MoralityService, ServerHandler, Play_Rumours.
  - **Changelog:** add the "Plan 1: Foundation" entry. Cover what changed for players:
    - standing now depends on where deeds are heard;
    - Lise's Circle hit lands in half the Circle's regions until word spreads;
    - enemies notice through sight;
    - the birth deeds;
    - the placeholders to review: communities, birth offsets, watchers, Wilds;
    - the tests run and their results;
    - backups.
  - **`Documents/Phase Plan.md`:** mark R1, S1, R2 done.
  - **Status page:** republish it (https://claude.ai/artifact/LZdftKv8ZzySTLPd6uEovy).
  - **Commit** (§C): `RumourService: tick, offline catch-up, deed hook, witness reports (R2)`.

---

## After Plan 1

Write **Plan 2 (Heat and Wanted + sound and light)** against the code as it stands then. It hooks `RumourService` arrivals (`Core.Advance` results carry `Place`; jurisdictions are on `Regions.Regions[Id].Jurisdiction`) and replaces `PerceptionService.ExposureOf` and the crouch / footstep inputs.

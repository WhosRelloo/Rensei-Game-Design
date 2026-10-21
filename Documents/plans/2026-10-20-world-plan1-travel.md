# World Plan 1: Travel Backbone and Station Tie-ins (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** a player in Lindenmoor buys a ticket, has their papers checked, boards a 5-car FMA-style train and rides it with their party, and arrives at the Foundry Yard place. They can also take the road (with ambushes) or stow away in the baggage car. Every system it touches (money, Heat and Wanted, rumours, quests, parties) is wired in.

**Architecture:**
- **Shared code:** every place runs the same code, shipped as Roblox Packages.
  - Server code moves into `ServerStorage.RenseiServer`.
  - A one-line boot loader in `ServerScriptService` clones it in at server start, so all 189 existing `ServerScriptService.<name>` paths keep working.
- **Pure rules:** routes, prices, the departure clock, the gate check and the ambush chance live in a data module, `Rensei.Travel`, with tests.
- **Server services:**
  - `TravelService` (group teleport, saves, arrival);
  - `StationService` (tickets, the papers check, boarding, the ride and its events);
  - `RoadService` (road exits, journeys, ambushes).
- **Client:** one `TravelClient` for all the travel screens.
- **The train:** a Blender part kit, exported through the Lindenmoor pipeline.

**Tech stack:**
- Roblox Studio (Luau), driven by the Studio MCP through `Art/Tools/rbxc.py`;
- Blender 5.2 through `Art/Tools/blender_mcpc.py` (bpy);
- ProfileService (the existing `DataManager`), TeleportService and Roblox Packages.

**Spec:** `Documents/specs/2026-10-20-world-travel-seasons-design.md`. Read sections 1–4, "The train model" and "Build order". This plan covers build steps 1 and 2 only. Seasons and region content are later plans.

## Global Constraints

- **Hard rules (owner):**
  - Do not publish the Roblox game or modify live player data.
  - Do not expose API keys, credentials, private player data, or other secrets.
  - Do not blindly copy another game's code or assets.
- **PROPOSAL labels:** every number invented here is a PROPOSAL; label it so in code comments.
- **Mechanics:** never remove an established mechanic without the owner's approval.
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

  - Menu is 123967384111466 and Tutorial is 74257385894576.
  - The region id for Central is **`City`**, the same as the existing `Rensei.Regions`.
- **Studio access:**
  - Run code with `python -I C:/Users/Owner/Rensei-Game-Design/Art/Tools/rbxc.py luau "placeId: <id>" <Edit|Server> @file.lua`.
  - It returns only the first value, so return one string.
  - Never touch the Studio window "bloodydeadpool53's Place".
  - Script edits are refused while Play runs.
- **Editing scripts in Studio:**
  - Create new scripts fresh.
  - To change an existing script: if it has no children, destroy it and recreate it with the full source. If it has children, splice the source in place at unique anchors with `string.find(src, anchor, 1, true)`, then confirm in a Play datamodel that the marker text is there.
  - Before every change, copy the old version to `ServerStorage.RenseiBackups["Pre-WorldPlan1_2026-10-20"]`.
- **Saves:**
  - Studio Play writes the owner's REAL profile.
  - Before any Play test, install the temporary profile hook (Task 3 has its code), take a snapshot, and restore it before Stop.
  - Delete the hook afterwards.
- **Teleports can't run in Studio:**
  - Every teleport path needs a Studio stand-in, a "loopback" that moves the players inside the same place and runs the arrival code.
  - The real cross-place hop is tested by the owner after they publish. We never publish.
- **Tests:**
  - Pure modules get `ServerStorage.RenseiTests.Test_<Name>`, run in Edit mode with `TestKit.Run(require(Suite))`.
  - Services get a `Play_<Name>` suite, run from a Server datamodel.
- **The game's numbers (`TuningConfig`):** R6 is 4×5×1; walk 16, run 24, sprint 30.
- **Docs:** after the plan, update the docs repo `C:/Users/Owner/Rensei-Game-Design`:
  - a `Documents/Changelog.md` entry, newest first, in the same turn as the change;
  - `git pull --rebase` before every commit;
  - commit trailers: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` and `Claude-Session: https://claude.ai/code/session_01Qw6G3HMsnCaMFq4vZWvFZE`.
  - Republish the status page https://claude.ai/artifact/LZdftKv8ZzySTLPd6uEovy.
- **Subagents** run on `model: "opus"`.
- **Never stage `Art/Blender.rar`** (147 MB; GitHub rejects it). Stage files by path, never with `git add -A`.

---

## File structure

| File | Responsibility |
|---|---|
| `ReplicatedStorage.Modules.Data.Rensei.Places` (modify) | place ids; **new** `Regions` table, `RegionOf`, `ResumePlace` |
| `ReplicatedStorage.Modules.Data.Rensei.Travel` (create) | pure travel rules: routes, classes, prices, the departure clock, the gate check, the ambush chance, ride events |
| `ReplicatedStorage.Modules.Data.Rensei.Regions` (modify) | new regions and links, a `Rail` carrier, the default region per place |
| `ReplicatedStorage.Modules.Data.ProfileData` (modify) | `Travel = {Region = "", Tickets = {}}` |
| `ServerStorage.RenseiServer` (create) | every former ServerScriptService child, moved here; becomes a Package |
| `ServerScriptService.RenseiBoot` (create) | clones `RenseiServer` into ServerScriptService at server start |
| `RenseiServer.FlowTeleport` (modify) | **new** `SendGroup` |
| `RenseiServer.TravelService` (create) | group departures, the save handover, arrival spawns, the Studio loopback |
| `RenseiServer.StationService` (create) | tickets, the papers check, boarding, the ride, ride events, the stowaway |
| `RenseiServer.RoadService` (create) | road exits, journeys, ambush arenas |
| `RenseiServer.QuestService` (modify) | an "Arrive" objective signal |
| `RenseiServer.ServerHandler` (modify) | start the three new services |
| `StarterPlayerScripts.TravelClient` (create) | ticket window, departure board, ride scenery, travel card, teleport screen |
| `ServerStorage.RenseiTests.Test_Travel` (create) | pure tests |
| `ServerStorage.RenseiTests.Play_Travel` (create) | Studio Play tests |
| `Art/Blender/train/train.py` (create) | the FMA train kit generator |
| `Art/Blender/lindenmoor/export.py` (modify) | scene and output arguments; `Seat` parts |
| `Art/Studio/Lindenmoor/studio_kit.py` (modify) | a folder argument; train materials; `Seat` |
| `Art/Studio/Train/` (create) | `layout.json`, `import/chunk_*.lua`, `kit/*.rbxmx` |
| `Art/Studio/Travel/place_setup.lua` (create) | copies Ye's place settings to a region place |
| `Art/Studio/Travel/station_lindenmoor.lua`, `station_foundry.lua` (create) | place the trains, platforms, gates and arrival points |

---

### Task 1: Travel rules and region places (pure data and tests)

**Files:**
- Modify: `ReplicatedStorage.Modules.Data.Rensei.Places`
- Create: `ReplicatedStorage.Modules.Data.Rensei.Travel`
- Test: `ServerStorage.RenseiTests.Test_Travel`

**Interfaces:**
- **Produces, `Places`:**
  - `Places.Regions[RegionId] = {PlaceId, Name, Climate, Station?}`;
  - `Places.RegionOf(PlaceId) -> RegionId?`;
  - `Places.ResumePlace(Data) -> PlaceId`.
- **Produces, `Travel`:**
  - `Travel.Routes[RouteId]`, `Travel.Classes[ClassId]`;
  - `Travel.Other(RouteId, From) -> RegionId`;
  - `Travel.RoutesFrom(Region, Kind) -> {RouteId}`;
  - `Travel.Price(RouteId, ClassId, Season) -> integer`;
  - `Travel.NextDeparture(RouteId, Now) -> integer`;
  - `Travel.BoardingOpen(RouteId, Now) -> boolean`;
  - `Travel.Fine(RouteId) -> integer`, `Travel.Bribe(RouteId, ClassId, Season) -> integer`;
  - `Travel.Gate(Wanted) -> "Pass" | "Bribe" | "Refuse"`;
  - `Travel.AmbushChance(Night, Winter, Wanted) -> number`;
  - `Travel.PickRideEvent(Roll) -> EventId`;
  - `Travel.CanTake(Level, RouteId) -> boolean, string?`;
  - `Travel.ClassReaches(ClassId, CarKind) -> boolean`;
  - `Travel.TicketKey(RouteId, ClassId) -> string`.

- [ ] **Step 1: Back up and read `Places`.** Copy `Rensei.Places` into `RenseiBackups["Pre-WorldPlan1_2026-10-20"]` as `Places`. Confirm it has no children (`#Places:GetChildren() == 0`).

- [ ] **Step 2: Write the failing test** (create `ServerStorage.RenseiTests.Test_Travel`):

```lua
local Rensei = game.ReplicatedStorage.Modules.Data.Rensei
local Travel = require(Rensei.Travel)
local Places = require(Rensei.Places)
return {
	PlacesKnowEveryRegion = function(T)
		T.Eq(Places.Regions.Lindenmoor.PlaceId, 106992859583940)
		T.Eq(Places.Regions.Foundry.PlaceId, 109591196441030)
		T.Eq(Places.Regions.City.PlaceId, 74075793529314)
		T.Eq(Places.Regions.Aerugo.PlaceId, 72020960130134)
		T.Eq(Places.Regions.Ishval.PlaceId, 133625615147752)
		T.Eq(Places.Regions.North.PlaceId, 132378034692557)
		T.Eq(Places.Regions.Corrupted.PlaceId, 138436167547886)
		T.Eq(Places.RegionOf(109591196441030), "Foundry")
		T.Eq(Places.RegionOf(123), nil)
		T.Eq(Places.Main, 106992859583940, "Main is still Ye")
	end,
	ResumeGoesToLastRegion = function(T)
		T.Eq(Places.ResumePlace({Travel = {Region = "Foundry"}}), 109591196441030)
		T.Eq(Places.ResumePlace({Travel = {Region = ""}}), Places.Main)
		T.Eq(Places.ResumePlace({}), Places.Main)
		T.Eq(Places.ResumePlace({Travel = {Region = "Nowhere"}}), Places.Main)
	end,
	RoutesJoinRealRegions = function(T)
		for Id, R in pairs(Travel.Routes) do
			T.True(Places.Regions[R.A] ~= nil and Places.Regions[R.B] ~= nil, Id)
			T.True(R.Kind == "Rail" or R.Kind == "Road", Id .. " kind")
		end
		T.Eq(Travel.Other("LindenmoorFoundry", "Lindenmoor"), "Foundry")
		T.Eq(Travel.Other("LindenmoorFoundry", "Foundry"), "Lindenmoor")
		T.Same(Travel.RoutesFrom("Lindenmoor", "Rail"), {"LindenmoorFoundry"})
	end,
	PricesByClassAndSeason = function(T)
		T.Eq(Travel.Price("LindenmoorFoundry", "Third", "Summer"), 15)
		T.Eq(Travel.Price("LindenmoorFoundry", "Second", "Summer"), 30)
		T.Eq(Travel.Price("LindenmoorFoundry", "Cabin", "Summer"), 75)
		T.Eq(Travel.Price("LindenmoorFoundry", "Third", "Winter"), 18)
		T.Eq(Travel.Price("RoadLindenmoorFoundry", "Third", "Summer"), 0, "roads are free")
		T.Eq(Travel.Fine("LindenmoorFoundry"), 45)
		T.Eq(Travel.Bribe("LindenmoorFoundry", "Third", "Summer"), 30)
	end,
	DepartureClock = function(T)
		T.Eq(Travel.NextDeparture("LindenmoorFoundry", 1000), 1050) -- every 150 s
		T.Eq(Travel.NextDeparture("LindenmoorFoundry", 1050), 1200, "a train leaving now has gone")
		T.True(Travel.BoardingOpen("LindenmoorFoundry", 1021), "30 s before")
		T.True(not Travel.BoardingOpen("LindenmoorFoundry", 1019))
	end,
	GateAndAmbush = function(T)
		T.Eq(Travel.Gate(0), "Pass")
		T.Eq(Travel.Gate(1), "Bribe")
		T.Eq(Travel.Gate(2), "Bribe")
		T.Eq(Travel.Gate(3), "Refuse")
		T.Near(Travel.AmbushChance(false, false, 0), 0.15)
		T.Near(Travel.AmbushChance(true, true, 1), 0.35)
		T.Near(Travel.AmbushChance(true, true, 5), 0.6, nil, "capped")
	end,
	RideEventsByWeight = function(T)
		T.Eq(Travel.PickRideEvent(0), "Inspection")
		T.Eq(Travel.PickRideEvent(0.399), "Inspection")
		T.Eq(Travel.PickRideEvent(0.4), "Rumour")
		T.Eq(Travel.PickRideEvent(0.7), "Pickpocket")
		T.Eq(Travel.PickRideEvent(0.85), "Quiet")
		T.Eq(Travel.PickRideEvent(0.95), "Holdup")
		T.Eq(Travel.PickRideEvent(0.9999), "Holdup")
	end,
	LevelGatesAndClasses = function(T)
		T.True(Travel.CanTake(1, "LindenmoorFoundry"))
		local Ok, Why = Travel.CanTake(7, "FoundryCity")
		T.True(not Ok and Why ~= nil, "needs level 8")
		T.True(Travel.CanTake(8, "FoundryCity"))
		T.True(Travel.ClassReaches("Third", "ThirdClass"))
		T.True(Travel.ClassReaches("Third", "DiningCar"))
		T.True(not Travel.ClassReaches("Third", "SecondClass"))
		T.True(Travel.ClassReaches("Second", "SecondClass"))
		T.True(not Travel.ClassReaches("Second", "CabinCar"))
		T.True(Travel.ClassReaches("Cabin", "CabinCar"))
		T.Eq(Travel.TicketKey("LindenmoorFoundry", "Second"), "LindenmoorFoundry|Second")
	end,
}
```

- [ ] **Step 3: Run it to see it fail.** In Edit mode, run:

```lua
local T = require(game.ServerStorage.RenseiTests.TestKit)
return (T.Run(require(game.ServerStorage.RenseiTests.Test_Travel:Clone())))
```

Expected: an error that `Rensei.Travel` doesn't exist.

- [ ] **Step 4: Write `Rensei.Travel`** (a new ModuleScript):

```lua
-- Travel (2026-10-20, world spec §2–4): the pure rules of getting between regions. Routes join two regions
-- (Rail = the train, Road = a road journey); a ticket is for one route and one class. Every number is a PROPOSAL.
local Travel = {}

Travel.Classes = {
	Third = {Name = "3rd class", Mult = 1, Cars = {ThirdClass = true, DiningCar = true}},
	Second = {Name = "2nd class", Mult = 2, Cars = {ThirdClass = true, DiningCar = true, SecondClass = true}},
	Cabin = {Name = "Private cabin", Mult = 5, Cars = {ThirdClass = true, DiningCar = true, SecondClass = true, CabinCar = true}},
}
Travel.ClassOrder = {"Third", "Second", "Cabin"}

-- Rail: Base = 3rd-class price, Every = seconds between departures, Ride = seconds aboard, Level = minimum level
-- Road: Seconds = the journey
Travel.Routes = {
	LindenmoorFoundry = {Kind = "Rail", A = "Lindenmoor", B = "Foundry", Base = 15, Every = 150, Ride = 50},
	FoundryCity = {Kind = "Rail", A = "Foundry", B = "City", Base = 15, Every = 150, Ride = 50, Level = 8},
	CityIshval = {Kind = "Rail", A = "City", B = "Ishval", Base = 40, Every = 180, Ride = 60, Level = 18},
	RoadLindenmoorFoundry = {Kind = "Road", A = "Lindenmoor", B = "Foundry", Seconds = 40},
	RoadFoundryCity = {Kind = "Road", A = "Foundry", B = "City", Seconds = 35, Level = 8},
	RoadCityAerugo = {Kind = "Road", A = "City", B = "Aerugo", Seconds = 50, Level = 12},
	RoadCityIshval = {Kind = "Road", A = "City", B = "Ishval", Seconds = 60, Level = 18},
	RoadCityNorth = {Kind = "Road", A = "City", B = "North", Seconds = 45, Level = 25},
	RoadNorthCorrupted = {Kind = "Road", A = "North", B = "Corrupted", Seconds = 40, Level = 30},
	RoadAerugoCorrupted = {Kind = "Road", A = "Aerugo", B = "Corrupted", Seconds = 45, Level = 30},
}

Travel.BoardingWindow = 30 -- seconds before departure that the doors open
Travel.WinterMult = 1.2
Travel.FineMult = 3
Travel.BribeMult = 2

Travel.RideEvents = { -- weights add up to 100
	{Id = "Inspection", Weight = 40},
	{Id = "Rumour", Weight = 30},
	{Id = "Pickpocket", Weight = 15},
	{Id = "Quiet", Weight = 10},
	{Id = "Holdup", Weight = 5},
}

function Travel.Other(RouteId, From)
	local R = Travel.Routes[RouteId]
	if not R then return nil end
	if R.A == From then return R.B end
	if R.B == From then return R.A end
	return nil
end

function Travel.RoutesFrom(Region, Kind)
	local Out = {}
	for Id, R in pairs(Travel.Routes) do
		if (R.A == Region or R.B == Region) and (not Kind or R.Kind == Kind) then table.insert(Out, Id) end
	end
	table.sort(Out)
	return Out
end

function Travel.Price(RouteId, ClassId, Season)
	local R, C = Travel.Routes[RouteId], Travel.Classes[ClassId]
	if not R or not C or R.Kind ~= "Rail" then return 0 end
	local P = R.Base * C.Mult * (Season == "Winter" and Travel.WinterMult or 1)
	return math.floor(P + 0.5)
end

function Travel.Fine(RouteId)
	local R = Travel.Routes[RouteId]
	return R and R.Base and R.Base * Travel.FineMult or 0
end

function Travel.Bribe(RouteId, ClassId, Season)
	return Travel.Price(RouteId, ClassId, Season) * Travel.BribeMult
end

function Travel.NextDeparture(RouteId, Now)
	local R = Travel.Routes[RouteId]
	if not R or not R.Every then return nil end
	return (math.floor(Now / R.Every) + 1) * R.Every
end

function Travel.BoardingOpen(RouteId, Now)
	local D = Travel.NextDeparture(RouteId, Now)
	return D ~= nil and D - Now <= Travel.BoardingWindow
end

function Travel.Gate(Wanted)
	if Wanted <= 0 then return "Pass" end
	if Wanted <= 2 then return "Bribe" end
	return "Refuse"
end

function Travel.AmbushChance(Night, Winter, Wanted)
	local C = 0.15 + (Night and 0.05 or 0) + (Winter and 0.05 or 0) + 0.10 * (Wanted or 0)
	return math.min(C, 0.6)
end

-- Roll in [0, 1)
function Travel.PickRideEvent(Roll)
	local Acc = 0
	for _, E in ipairs(Travel.RideEvents) do
		Acc += E.Weight / 100
		if Roll < Acc - 1e-9 then return E.Id end
	end
	return Travel.RideEvents[#Travel.RideEvents].Id
end

function Travel.CanTake(Level, RouteId)
	local R = Travel.Routes[RouteId]
	if not R then return false, "No such route." end
	if R.Level and (Level or 0) < R.Level then return false, ("You need to be level %d."):format(R.Level) end
	return true
end

function Travel.ClassReaches(ClassId, CarKind)
	local C = Travel.Classes[ClassId]
	return C ~= nil and C.Cars[CarKind] == true
end

function Travel.TicketKey(RouteId, ClassId)
	return RouteId .. "|" .. ClassId
end

return Travel
```

Note on `PickRideEvent(0.399)`: 0.399 < 0.4 − 1e-9, so it's an Inspection. 0.4 is not, so it's a Rumour.

- [ ] **Step 5: Rewrite `Places`.** Destroy it and recreate it with the existing functions kept, plus the regions:

```lua
-- Rensei places (one experience, 9509447316) and the start flow (owner 2026-10-14):
--   Main Menu + Customize (Menu) -> Tutorial -> cutscene -> Main game (Ye)
-- World plan 1 (2026-10-20): one place per region (ids from the owner). Region ids match Rensei.Regions.
-- Keep this file the same in every place.
local Places = {
	Menu = 123967384111466, -- "Character Customization": main menu + character creation
	Tutorial = 74257385894576,
	Main = 106992859583940, -- "RSEI" (Ye) = Lindenmoor
}

-- Climate drives seasons (world spec §5): Temperate, Desert, Frozen, Eclipse
Places.Regions = {
	Lindenmoor = {PlaceId = 106992859583940, Name = "Lindenmoor", Climate = "Temperate", Station = "Lindenmoor Station"},
	Foundry = {PlaceId = 109591196441030, Name = "the Foundry Yard", Climate = "Temperate", Station = "Foundry Junction"},
	City = {PlaceId = 74075793529314, Name = "Central City", Climate = "Temperate", Station = "Central Terminal"},
	Aerugo = {PlaceId = 72020960130134, Name = "the Aerugo Borderlands", Climate = "Temperate"},
	Ishval = {PlaceId = 133625615147752, Name = "Ishval", Climate = "Desert", Station = "Ishval Rail Halt"},
	North = {PlaceId = 132378034692557, Name = "the Northern Wall", Climate = "Frozen"},
	Corrupted = {PlaceId = 138436167547886, Name = "the Corrupted Lands", Climate = "Eclipse"},
}

function Places.RegionOf(PlaceId)
	for Id, R in pairs(Places.Regions) do
		if R.PlaceId == PlaceId then return Id end
	end
	return nil
end

-- Where a returning player goes: the region they were last in (Data.Travel.Region), else Lindenmoor.
function Places.ResumePlace(Data)
	local Region = Data and Data.Travel and Data.Travel.Region
	local R = type(Region) == "string" and Places.Regions[Region]
	return R and R.PlaceId or Places.Main
end

-- Where a profile should go next from the menu.
function Places.NextFor(Data)
	local Identity = Data and Data.Identity
	if not Identity or not Identity.CharacterCreated then return "Customize" end
	if not (Data.Flow and Data.Flow.TutorialDone) then return "Tutorial" end
	return "Main"
end

-- TeleportData every in-flow teleport carries, so a place can tell a flow arrival from a direct join.
Places.FlowTag = "RenseiFlow"

return Places
```

- [ ] **Step 6: Run the tests to see them pass.** Use the Step 3 command (clone the suite, and clone the modules too if the require cache is stale). Expected: `PASS 8 / FAIL 0`. Then run `Test_Regions` and `Test_Heat` to confirm nothing else broke.

- [ ] **Step 7: Save the sources to the repo and commit.**
  - Save the sources to `Art/Studio/Travel/src/Travel.lua`, `Places.lua` and `Test_Travel.lua`; these are the repo copies of the Studio scripts.
  - Commit: `git add Art/Studio/Travel/src && git commit -m "World plan 1 task 1: Travel rules and region places"`

---

### Task 2: The FMA train kit (Blender to Studio)

**Files:**
- Create: `Art/Blender/train/__init__.py` (empty) and `Art/Blender/train/train.py`
- Modify: `Art/Blender/lindenmoor/export.py`: add `export(scene_name, out_path)` arguments and a `Seat` kind
- Modify: `Art/Studio/Lindenmoor/studio_kit.py`: a folder argument, the train materials, and `Seat` (shape 3)
- Create: `Art/Studio/Train/layout.json`, `Art/Studio/Train/import/chunk_*.lua`, `Art/Studio/Train/kit/Train/*.rbxmx`
- Create: `Art/Blender/Train.blend` and `Documents/images/Map Concept/Train - *.png` (renders)

**Interfaces:**
- **Produces:** one Model per car, named `<Kind>_Main`:

  | Car | Length (studs) |
  |---|---|
  | Locomotive | 72 |
  | Tender | 30 |
  | BaggageCar | 64 |
  | ThirdClass | 64 |
  | DiningCar | 64 |
  | SecondClass | 64 |
  | CabinCar | 64 |

- **Model layout:** the pivot is at rail height in the middle of the car, and the car runs along its local X axis with the front at +X.
- **Every passenger car** has:
  - two `BoardZone` parts (invisible, CanCollide off, one per end vestibule, attribute `CarKind`);
  - `Seat` parts on its benches and chairs;
  - a `CarDoor` part at each internal doorway (attribute `CarKind`), used by the conductor's class check.
- **BaggageCar** also has a `StowZone` part (invisible) inside its open side door.

- [ ] **Step 1: Make export.py take arguments.** Change its signature to `export(scene_name="Lindenmoor_Full", out_path=OUT)` and write to `out_path`. In the part loop, map `k == "Seat"` to `shape = 3` (box sizing):

```python
            if k == "Cylinder":
                rel = rel @ CYL_FIX
                size = [sz[2], sz[0], sz[1]]
                shape = 1
            else:
                size = [sz[0], sz[2], sz[1]]
                shape = {"Wedge": 2, "Seat": 3}.get(k, 0)
```

Also export invisible helper parts. A Blender object with the custom property `rs_invisible = True` adds a 14th field, `1`, to its part row. A part with the property `rs_attr` (a JSON string) adds a 15th field holding that string. A part with an `rs_attr` but no `rs_invisible` still writes the 14th field (as `0`), so the attributes are always field 15.

- [ ] **Step 2: Make studio_kit.py take a folder.** It should take an optional folder argument (`python -I studio_kit.py <folder>`, default its own folder), read `<folder>/layout.json`, and write `<folder>/import` and `<folder>/kit`.
  - **Add these materials to `MATS`:**

    | Material | Roblox material | Colour |
    |---|---|---|
    | `LM_TrainNavy` | Metal | `23262d` |
    | `LM_TrainMaroon` | WoodPlanks | `6a1f24` |
    | `LM_TrainBlack` | Metal | `1b1c1e` |
    | `LM_TrainRoof` | Metal | `4a4d50` |
    | `LM_Brass` | Metal | `b08a3c` |
    | `LM_Cream` | Plaster | `e6dcc2` |
    | `LM_BenchGreen` | Fabric | `2f4a3a` |
    | `LM_TrainWood` | Wood | `5a3a26` |
    | `LM_Helper` | SmoothPlastic | `ffffff` |

    All have transparency 0.
  - **In the Lua body:**
    - `P[2] == 3` creates `Instance.new("Seat")`;
    - field 14 being `1` makes the part `Transparency = 1, CanCollide = false, CanQuery = true, CanTouch = true`;
    - field 15 (a JSON string) is decoded and every key is set as an attribute.
  - **In `rbxmx()`:** Seat parts get `class="Seat"`; helper parts get `Transparency 1` and `CanCollide false`.

- [ ] **Step 3: Write `Art/Blender/train/train.py`:**

```python
"""FMA-style train kit (2026-10-20, world spec "The train model"). Locomotive + tender + baggage, 3rd class, dining,
2nd class, private cabin. 1 Blender unit = 1 stud. Each car: an Empty root ["rs_prefab"] = kind at x along the train,
local +x = forward, rail top at z = 0, floor top at z = 4.2. Helper parts (BoardZone, StowZone, CarDoor) are invisible.
Every size and colour is a PROPOSAL (owner refs: the FMA locomotive, the maroon coach, the 3rd-class benches)."""
import bpy, math, json, importlib
from lindenmoor import core
importlib.reload(core)
from lindenmoor.core import box, cyl, srgb

SCENE = "Train"
M = {}
L, W, FLOOR = 64.0, 12.0, 4.2   # coach length, width, floor top
ROOF = 14.6                      # roof crown


def mats():
    M["navy"] = core.flat("LM_TrainNavy", srgb("#23262d"), rough=0.45, metal=0.6)
    M["maroon"] = core.pbr("LM_TrainMaroon", "brown_planks_05", tile=4, tint=srgb("#7a2228"), bump=0.3)
    M["black"] = core.flat("LM_TrainBlack", srgb("#1b1c1e"), rough=0.5, metal=0.7)
    M["roof"] = core.flat("LM_TrainRoof", srgb("#4a4d50"), rough=0.6, metal=0.4)
    M["brass"] = core.flat("LM_Brass", srgb("#b08a3c"), rough=0.3, metal=0.9)
    M["cream"] = core.pbr("LM_Cream", "plastered_wall_04", tile=8, tint=srgb("#e6dcc2"), bump=0.2)
    M["bench"] = core.flat("LM_BenchGreen", srgb("#2f4a3a"), rough=0.9)
    M["wood"] = core.pbr("LM_TrainWood", "medieval_wood", tile=5, tint=srgb("#5a3a26"), bump=0.3)
    M["glass"] = core.flat("LM_WindowGlass", srgb("#9fb4bf"), rough=0.05)
    M["glow"] = core.flat("LM_LanternGlow", srgb("#ffb35c"), rough=0.4, emit=(srgb("#ffad4d"), 18))
    M["helper"] = core.flat("LM_Helper", srgb("#ffffff"), rough=1)


def root(kind, x):
    e = bpy.data.objects.new(f"PF_{kind}_Main", None)
    e.location = (x, 0, 0)
    e["rs_prefab"], e["rs_id"] = kind, "Main"
    core.coll("Cars").objects.link(e)
    return e


def P(rt, name, size, loc, m, rot=(0, 0, 0), bevel=0.06, kind=None, invisible=False, attr=None):
    o = box(f"{rt.name}_{name}", size, loc, M[m], rt.users_collection[0], rot=rot, bevel=bevel)
    o.parent = rt
    if kind:
        o["rs_kind"] = kind
    if invisible:
        o["rs_invisible"] = True
        o.hide_render = True
    if attr:
        o["rs_attr"] = json.dumps(attr)
    return o


def C(rt, name, r, h, loc, m, rot=(0, 0, 0), verts=16):
    o = cyl(f"{rt.name}_{name}", r, h, loc, M[m], rt.users_collection[0], verts=verts, rot=rot)
    o.parent = rt
    return o


def bogie(rt, x):
    P(rt, f"Bogie{x}", (9, 8, 1.2), (x, 0, 2.2), "black")
    for dx in (-2.6, 2.6):
        for s in (-1, 1):
            C(rt, f"Wheel{x}_{dx}_{s}", 1.6, 0.6, (x + dx, s * 3.6, 1.6), "black", rot=(math.radians(90), 0, 0))
    P(rt, f"Spring{x}", (7, 0.6, 0.6), (x, 4.1, 2.6), "brass", bevel=0.02)


def coach_shell(rt, kind, windows=True, side_door_mid=False):
    """Underframe, floor, maroon sides with framed windows, end vestibules with side doors + steps, arched roof,
    cream lining, gangway bellows, two BoardZones."""
    P(rt, "Underframe", (L - 2, W - 1, 1.2), (0, 0, 3.0), "black")
    for x in (-L / 2 + 9, L / 2 - 9):
        bogie(rt, x)
    P(rt, "Floor", (L, W, 0.6), (0, 0, FLOOR - 0.3), "wood")
    vest = 5.0  # vestibule length at each end
    for s in (-1, 1):
        y = s * (W / 2 - 0.3)
        # lower panel full length, minus the door openings at each end
        P(rt, f"Lower{s}", (L - 2 * vest, 0.6, 3.6), (0, y, FLOOR + 1.8), "maroon")
        P(rt, f"Upper{s}", (L - 2 * vest, 0.6, 2.4), (0, y, FLOOR + 8.1), "maroon")
        n = int((L - 2 * vest) // 6)
        for i in range(n + 1):
            x = -L / 2 + vest + i * (L - 2 * vest) / n
            P(rt, f"Post{s}_{i}", (1.0, 0.7, 3.4), (x, y, FLOOR + 5.3), "maroon")
        for i in range(n):
            x = -L / 2 + vest + (i + 0.5) * (L - 2 * vest) / n
            if windows and not (side_door_mid and abs(x) < 4):
                P(rt, f"Glass{s}_{i}", (4.0, 0.2, 3.4), (x, y, FLOOR + 5.3), "glass", bevel=0)
                P(rt, f"Sill{s}_{i}", (4.6, 1.0, 0.3), (x, y - s * 0.4, FLOOR + 3.5), "wood", bevel=0.02)
            else:
                P(rt, f"Blank{s}_{i}", (4.0, 0.6, 3.4), (x, y, FLOOR + 5.3), "maroon")
        # end vestibules: a door opening (5 wide x 8.5 high) in each side, framed, with two steps down
        for e in (-1, 1):
            xe = e * (L / 2 - vest / 2)
            P(rt, f"DoorFrameTop{s}{e}", (vest, 0.6, 1.4), (xe, y, FLOOR + 9.2), "maroon")
            P(rt, f"Step{s}{e}a", (4.4, 1.2, 0.4), (xe, s * (W / 2 + 0.6), FLOOR - 1.6), "black")
            P(rt, f"Step{s}{e}b", (4.4, 1.2, 0.4), (xe, s * (W / 2 + 1.6), FLOOR - 3.0), "black")
            P(rt, f"Grab{s}{e}", (0.25, 0.25, 6), (xe - e * 2.4, s * (W / 2 + 0.2), FLOOR + 4), "brass", bevel=0)
        P(rt, f"Lining{s}", (L - 2 * vest, 0.2, 9.6), (0, s * (W / 2 - 0.75), FLOOR + 4.8), "cream", bevel=0)
    # end walls with a gangway opening (4 wide x 8.5)
    for e in (-1, 1):
        x = e * (L / 2 - 0.3)
        for s in (-1, 1):
            P(rt, f"EndWall{e}{s}", (0.6, (W - 4) / 2, 10.4), (x, s * ((W - 4) / 4 + 2), FLOOR + 5.2), "maroon")
        P(rt, f"EndTop{e}", (0.6, 4, 1.9), (x, 0, FLOOR + 9.45), "maroon")
        P(rt, f"Bellows{e}", (1.6, 5.2, 9.6), (x + e * 1.0, 0, FLOOR + 4.8), "black")
        # vestibule partitions with an inner doorway into the saloon
        xp = e * (L / 2 - vest)
        for s in (-1, 1):
            P(rt, f"Partition{e}{s}", (0.4, (W - 4) / 2, 10.0), (xp, s * ((W - 4) / 4 + 2), FLOOR + 5.0), "wood")
        P(rt, f"CarDoor{e}", (0.6, 4, 8.5), (xp, 0, FLOOR + 4.25), "helper", invisible=True, attr={"CarKind": kind})
        P(rt, f"BoardZone{e}", (vest - 0.6, W - 1.4, 8), (e * (L / 2 - vest / 2), 0, FLOOR + 4), "helper", invisible=True,
          attr={"CarKind": kind})
    # arched roof: 7 tilted slabs + ceiling + lamps
    for i in range(-3, 4):
        a = math.radians(i * 11)
        y = math.sin(a) * 7.0
        z = FLOOR + 10.4 + math.cos(a) * 1.8 - 1.5
        P(rt, f"Roof{i}", (L + 0.4, 2.3, 0.5), (0, y, z), "roof", rot=(a, 0, 0), bevel=0.04)
    P(rt, "Ceiling", (L - 2, W - 1.6, 0.2), (0, 0, FLOOR + 9.8), "cream", bevel=0)
    for x in range(-24, 25, 12):
        P(rt, f"Lamp{x}", (0.9, 0.9, 0.5), (x, 0, FLOOR + 9.45), "glow", bevel=0.1)


def bench_pair(rt, x, y, facing, tag):
    """A bench facing +x (facing=1) or -x: seat (Seat part) + back."""
    P(rt, f"BenchBase{tag}", (2.2, 3.8, 1.6), (x, y, FLOOR + 0.8), "wood")
    P(rt, f"Seat{tag}", (2.2, 3.8, 0.6), (x, y, FLOOR + 1.9), "bench", kind="Seat")
    P(rt, f"Back{tag}", (0.5, 3.8, 3.4), (x - facing * 1.2, y, FLOOR + 3.8), "bench")
    P(rt, f"BackTop{tag}", (0.7, 3.9, 0.4), (x - facing * 1.2, y, FLOOR + 5.6), "wood")


def third_class(rt):
    coach_shell(rt, "ThirdClass")
    for x in range(-22, 23, 8):
        for side in (-1, 1):
            y = side * 3.8
            bench_pair(rt, x - 1.6, y, 1, f"{x}{side}a")
            bench_pair(rt, x + 1.6, y, -1, f"{x}{side}b")
        P(rt, f"Rack{x}", (6, 0.2, 0.2), (x, 5.0, FLOOR + 7.6), "brass", bevel=0)
        P(rt, f"RackB{x}", (6, 0.2, 0.2), (x, -5.0, FLOOR + 7.6), "brass", bevel=0)


def dining(rt):
    coach_shell(rt, "DiningCar")
    for i, x in enumerate((-18, -6, 6)):
        for side in (-1, 1):
            y = side * 3.4
            P(rt, f"Table{i}{side}", (3.0, 2.8, 0.3), (x, y, FLOOR + 2.9), "wood")
            P(rt, f"Leg{i}{side}", (0.4, 0.4, 2.8), (x, y, FLOOR + 1.4), "brass", bevel=0)
            P(rt, f"TableLamp{i}{side}", (0.5, 0.5, 0.7), (x, y + side * 0.8, FLOOR + 3.4), "glow", bevel=0.1)
            for dx in (-2.4, 2.4):
                P(rt, f"Chair{i}{side}{dx}", (1.6, 1.8, 0.5), (x + dx, y, FLOOR + 1.8), "bench", kind="Seat")
                P(rt, f"ChairBack{i}{side}{dx}", (0.4, 1.8, 2.6), (x + dx + (1 if dx > 0 else -1) * 0.8, y, FLOOR + 3.2), "wood")
    P(rt, "Bar", (12, 2.4, 3.6), (17, -3.4, FLOOR + 1.8), "wood")
    P(rt, "BarTop", (12.4, 2.8, 0.3), (17, -3.4, FLOOR + 3.7), "brass")
    for k in range(6):
        P(rt, f"Bottle{k}", (0.4, 0.4, 1.0), (12.5 + k * 1.6, -5.2, FLOOR + 5.2), "glass", bevel=0)
    P(rt, "Shelf", (12, 0.8, 0.3), (17, -5.4, FLOOR + 4.6), "wood")


def second_class(rt):
    coach_shell(rt, "SecondClass")
    cy = 3.4  # side corridor along +y, 4 wide; compartments on -y
    for i in range(5):
        x = -20 + i * 10
        P(rt, f"Wall{i}", (0.4, 7.4, 9.6), (x, -1.0, FLOOR + 4.8), "wood")
    P(rt, "CorridorWallA", (40, 0.4, 2.2), (0, cy - 2.0, FLOOR + 1.1), "wood")
    for i in range(4):
        x = -15 + i * 10
        P(rt, f"CompDoorGlass{i}", (3.6, 0.2, 5.6), (x - 2.6, cy - 2.0, FLOOR + 5.0), "glass", bevel=0)
        P(rt, f"CompWall{i}", (3.4, 0.4, 9.6), (x + 2.8, cy - 2.0, FLOOR + 4.8), "wood")
        bench_pair(rt, x - 3.6, -2.0, 1, f"c{i}a")
        bench_pair(rt, x + 3.6, -2.0, -1, f"c{i}b")
        P(rt, f"CompLamp{i}", (0.6, 0.6, 0.5), (x, -2.0, FLOOR + 9.3), "glow", bevel=0.1)


def cabin_car(rt):
    coach_shell(rt, "CabinCar")
    for i, x in enumerate((-12, 4)):
        P(rt, f"CabinWallA{i}", (0.4, 11, 9.6), (x - 8, 0, FLOOR + 4.8), "wood")
        P(rt, f"CabinWallB{i}", (0.4, 7, 9.6), (x + 8, -2, FLOOR + 4.8), "wood")
        P(rt, f"Bed{i}", (7, 3.6, 1.4), (x - 3, -3.4, FLOOR + 1.4), "bench", kind="Seat")
        P(rt, f"BedHead{i}", (0.6, 3.6, 3), (x - 6.6, -3.4, FLOOR + 3), "wood")
        P(rt, f"CabinTable{i}", (2.4, 2.4, 0.3), (x + 3, -3.4, FLOOR + 2.8), "wood")
        P(rt, f"CabinLamp{i}", (0.5, 0.5, 0.8), (x + 3, -3.4, FLOOR + 3.4), "glow", bevel=0.1)
    for k, x in enumerate((18, 23)):
        P(rt, f"Armchair{k}", (2.4, 2.4, 0.8), (x, -3.2, FLOOR + 1.6), "bench", kind="Seat")
        P(rt, f"ArmchairBack{k}", (0.6, 2.4, 3), (x + 1.2, -3.2, FLOOR + 3), "bench")


def baggage_car(rt):
    coach_shell(rt, "BaggageCar", windows=False, side_door_mid=True)
    # open sliding door on +y = Roblox local +Z, the freight-yard side (Task 6 turns the cars by Angles(0, -90deg, 0),
    # so local +Z faces world -X, away from Ye's platform). Fix round 1: was -y, which faced the platform.
    P(rt, "DoorLeaf", (6, 0.4, 8), (5.5, (W / 2 + 0.4), FLOOR + 4), "maroon")
    P(rt, "StowZone", (5, 3, 7), (0, 3.6, FLOOR + 3.5), "helper", invisible=True, attr={"CarKind": "BaggageCar"})
    import random
    rnd = random.Random(7)
    for k in range(10):
        x, y = rnd.uniform(-24, 24), rnd.choice((-3.6, 3.6))
        if abs(x) < 5 and y < 0:
            continue
        s = rnd.uniform(2.2, 3.4)
        P(rt, f"Crate{k}", (s, s, s), (x, y, FLOOR + s / 2), "wood", rot=(0, 0, rnd.uniform(-0.2, 0.2)))
    for k in range(6):
        P(rt, f"Sack{k}", (1.8, 1.2, 1.2), (rnd.uniform(-20, 20), 4.0, FLOOR + 0.6), "cream", bevel=0.4)


def locomotive(rt):
    P(rt, "Frame", (70, 9, 1.6), (0, 0, 3.4), "black")
    P(rt, "Running", (60, 12, 0.4), (-2, 0, 5.4), "black", bevel=0.02)
    C(rt, "Boiler", 4.4, 38, (6, 0, 10.6), "navy", rot=(0, math.radians(90), 0), verts=24)
    C(rt, "Smokebox", 4.9, 8, (28, 0, 10.6), "navy", rot=(0, math.radians(90), 0), verts=24)
    C(rt, "SmokeboxDoor", 4.6, 0.8, (32.4, 0, 10.6), "navy", rot=(0, math.radians(90), 0), verts=24)
    for k in range(12):
        a = k / 12 * math.tau
        C(rt, f"Bolt{k}", 0.35, 0.5, (32.9, math.cos(a) * 3.9, 10.6 + math.sin(a) * 3.9), "brass", rot=(0, math.radians(90), 0), verts=8)
    P(rt, "DoorBar", (0.5, 0.6, 5.6), (33.0, 0, 10.6), "brass", bevel=0.02)
    for s in (-1, 1):
        C(rt, f"Headlamp{s}", 0.9, 1.2, (33.0, s * 3.4, 6.8), "glow", rot=(0, math.radians(90), 0), verts=12)
        P(rt, f"LampHousing{s}", (1.6, 2.2, 2.2), (32.2, s * 3.4, 6.8), "navy")
    C(rt, "Chimney", 1.4, 4.2, (28, 0, 16.6), "black", verts=14)
    C(rt, "Dome", 1.8, 2.4, (12, 0, 15.6), "brass", verts=14)
    # cab
    P(rt, "CabFloor", (12, 11, 0.6), (-24, 0, 6.0), "wood")
    for s in (-1, 1):
        P(rt, f"CabSide{s}", (12, 0.6, 9), (-24, s * 5.3, 10.8), "navy")
        P(rt, f"CabWindow{s}", (3.6, 0.2, 3.0), (-22, s * 5.4, 12.6), "glass", bevel=0)
    P(rt, "CabFront", (0.6, 11, 9), (-18.2, 0, 10.8), "navy")
    P(rt, "CabRoof", (14, 12.4, 0.6), (-24, 0, 15.6), "roof")
    # wheels and rods
    for i, x in enumerate((-8, 2, 12)):
        for s in (-1, 1):
            C(rt, f"Driver{i}{s}", 3.2, 0.8, (x, s * 4.9, 3.6), "black", rot=(math.radians(90), 0, 0), verts=20)
            C(rt, f"Hub{i}{s}", 0.8, 1.0, (x, s * 5.4, 3.6), "brass", rot=(math.radians(90), 0, 0), verts=10)
    for s in (-1, 1):
        P(rt, f"Rod{s}", (22, 0.4, 0.6), (2, s * 5.7, 3.6), "brass", bevel=0.02)
        P(rt, f"Rail{s}", (36, 0.3, 0.3), (6, s * 4.6, 13.8), "brass", bevel=0)
    for k in range(3):
        P(rt, f"Cowcatcher{k}", (3.6, 9 - k * 2, 0.5), (34.5 + k * 0.6, 0, 2.4 + k * 0.9), "black", rot=(0, math.radians(-30), 0))


def tender(rt):
    P(rt, "Frame", (28, 9, 1.4), (0, 0, 3.2), "black")
    P(rt, "Tank", (26, 11, 7), (0, 0, 8.0), "navy")
    P(rt, "Coal", (12, 9, 1.6), (6, 0, 12.2), "black", bevel=0.4)
    for x in (-8, 8):
        bogie(rt, x)


CARS = [("Locomotive", 72, locomotive), ("Tender", 30, tender), ("BaggageCar", L, baggage_car),
        ("ThirdClass", L, third_class), ("DiningCar", L, dining), ("SecondClass", L, second_class), ("CabinCar", L, cabin_car)]
GAP = 3.0


def run():
    global M
    core.SCENE = core.ROOT = SCENE
    core.reset_scene()
    mats()
    x = 0.0
    for kind, length, fn in CARS:
        rt = root(kind, x - length / 2)
        fn(rt)
        x -= length + GAP
    return {"objects": len(core.scene().objects), "length": -x}
```

- [ ] **Step 4: Build it and render it.**
  - Run in Blender: `import sys; sys.path.insert(0, r"C:/Users/Owner/Rensei-Game-Design/Art/Blender"); import train.train as T; result = T.run()`.
  - Expected: about 1,600 objects and a length of about 440.
  - Render three views and check each one by eye against the owner's references, then save it to `Documents/images/Map Concept/Train - <view>.png`:
    - the locomotive's front three-quarters (the round bolted smokebox door, the headlamps);
    - a coach side (maroon, framed windows, steps);
    - the 3rd-class interior (facing green benches, cream walls).
  - Fix anything that clips or reads wrong before exporting.

- [ ] **Step 5: Export.**
  - In Blender: `import lindenmoor.export as E; result = E.export("Train", r"C:/Users/Owner/Rensei-Game-Design/Art/Studio/Train/layout.json")`.
  - Then run `python -I Art/Studio/Lindenmoor/studio_kit.py Art/Studio/Train`.
  - Expected: 7 models, and kit files under `Art/Studio/Train/kit/Cars/`.
  - Save the blend file as `Art/Blender/Train.blend`.

- [ ] **Step 6: Test the import in Ye.**
  - Run the chunks in Ye. Staging goes to `ServerStorage.LindenmoorStaging` (the importer's folder); then move `Cars/*` to `ServerStorage.TrainKit`.
  - **Check:**
    - 7 models;
    - every passenger car has 2 `BoardZone` parts and 2 `CarDoor` parts;
    - the baggage car has 1 `StowZone`;
    - Seat count: ThirdClass 28, DiningCar 24 (six tables for four), SecondClass 8, CabinCar 4.
    - The Locomotive's `SteamOut` part holds a ParticleEmitter named `Steam`.
  - Check with:

```lua
local K = game.ServerStorage.TrainKit
local out = {}
for _, m in ipairs(K:GetChildren()) do
	local seats, zones, doors, stow = 0, 0, 0, 0
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Seat") then seats += 1 end
		if d.Name:find("BoardZone") then zones += 1 end
		if d.Name:find("CarDoor") then doors += 1 end
		if d.Name:find("StowZone") then stow += 1 end
	end
	table.insert(out, ("%s seats %d zones %d doors %d stow %d"):format(m.Name, seats, zones, doors, stow))
end
return table.concat(out, "\n")
```

- [ ] **Step 7: Commit.** Commit by path (never `Art/Blender.rar`): `Art/Blender/train`, `Art/Blender/Train.blend`, `Art/Blender/lindenmoor/export.py`, `Art/Studio/Lindenmoor/studio_kit.py`, `Art/Studio/Train`, and the renders.

---

### Task 3: The server boot loader (every place runs the same server code)

**Files:**
- Create: `ServerStorage.RenseiServer` (a Folder holding every current child of ServerScriptService)
- Create: `ServerScriptService.RenseiBoot` (a Script)
- Create: `ServerStorage.RenseiTests.Play_Boot`

**Interfaces:**
- **Produces:** at runtime, ServerScriptService holds a clone of every child of `RenseiServer`, so the 189 existing `ServerScriptService.<name>` references are unchanged. In **Edit** mode, server code now lives in `ServerStorage.RenseiServer.<name>`; every later task edits it there.

- [ ] **Step 1: Back up.** Clone every ServerScriptService child into `RenseiBackups["Pre-WorldPlan1_2026-10-20"].SSS`.

- [ ] **Step 2: Install the profile hook** (needed for every Play test in this plan). Create `ServerScriptService.LMTestHook_TEMP` with exactly the source used in the Lindenmoor kit tests: it snapshots each player's `Profile.Data` on load and exposes `ServerStorage.LMTestHook` with the `"diff"` and `"restore"` operations. Use the source in `Art/Studio/Travel/test_hook.lua`, created now from the code below:

```lua
local S = Instance.new("Script")
S.Name = "LMTestHook_TEMP"
S.Source = [==[
-- TEMP: snapshot the tester's profile on load, restore on demand. Delete after.
local Players = game:GetService("Players")
local DM = require(game.ServerScriptService:WaitForChild("CharacterHandler"):WaitForChild("DataManager"))
local function copy(t) if type(t) ~= "table" then return t end local r = {} for k, v in pairs(t) do r[k] = copy(v) end return r end
local Snap = {}
local BF = Instance.new("BindableFunction")
BF.Name = "LMTestHook"
BF.OnInvoke = function(Op)
	local P = Players:GetPlayers()[1]
	local Prof = P and DM:GetProfile(P)
	if not Prof then return "no profile" end
	if Op == "restore" then
		for k in pairs(Prof.Data) do if Snap[P][k] == nil then Prof.Data[k] = nil end end
		for k, v in pairs(Snap[P]) do Prof.Data[k] = copy(v) end
		return "restored"
	end
end
BF.Parent = game.ServerStorage
local function Take(P)
	local Prof = DM:WaitProfile(P, 60)
	if Prof then Snap[P] = copy(Prof.Data) game.ServerStorage:SetAttribute("LMSnapTaken", P.Name) end
end
Players.PlayerAdded:Connect(Take)
for _, P in ipairs(Players:GetPlayers()) do task.spawn(Take, P) end
]==]
S.Parent = game.ServerScriptService
return "hook installed"
```

After Step 3, the hook lives in `RenseiServer` like everything else; it is a Script, so it is cloned in too.

- [ ] **Step 3: Move server code into `RenseiServer` and add the boot loader.** Run in Edit mode:

```lua
local SSS = game:GetService("ServerScriptService")
local SS = game:GetService("ServerStorage")
assert(not SS:FindFirstChild("RenseiServer"), "already moved")
local Bundle = Instance.new("Folder")
Bundle.Name = "RenseiServer"
Bundle.Parent = SS
for _, C in ipairs(SSS:GetChildren()) do C.Parent = Bundle end
local Boot = Instance.new("Script")
Boot.Name = "RenseiBoot"
Boot.Source = [==[
-- RenseiBoot (World plan 1, 2026-10-20): every place ships the same server code as the Package
-- ServerStorage.RenseiServer; this copies it into ServerScriptService at server start, ModuleScripts first,
-- so every ServerScriptService.<Name> path in the code still works. Edit server code in RenseiServer, not here.
local SSS = game:GetService("ServerScriptService")
local Bundle = game:GetService("ServerStorage"):WaitForChild("RenseiServer")
local Later = {}
for _, C in ipairs(Bundle:GetChildren()) do
	if C:IsA("ModuleScript") or C:IsA("Folder") then C:Clone().Parent = SSS else table.insert(Later, C) end
end
for _, C in ipairs(Later) do C:Clone().Parent = SSS end
]==]
Boot.Parent = SSS
return ("moved %d; boot installed"):format(#Bundle:GetChildren())
```

Expected: `moved 45; boot installed` (44 children plus the hook).

- [ ] **Step 4: Write the failing Play test.** Create `ServerStorage.RenseiTests.Play_Boot`:

```lua
return {
	EveryServerScriptIsCopiedIn = function(T)
		local SSS, Bundle = game.ServerScriptService, game.ServerStorage.RenseiServer
		for _, C in ipairs(Bundle:GetChildren()) do
			T.True(SSS:FindFirstChild(C.Name) ~= nil, C.Name .. " in ServerScriptService")
		end
	end,
	ServicesStarted = function(T)
		T.True(game.ReplicatedStorage.Remotes:FindFirstChild("IntroRemote") ~= nil, "remotes exist")
		local P = game.Players:GetPlayers()[1]
		T.True(P ~= nil and P.Character ~= nil, "a character spawned")
		T.True(require(game.ServerScriptService.CharacterHandler.DataManager):GetProfile(P) ~= nil, "profile loaded")
	end,
}
```

- [ ] **Step 5: Run it in Play.**
  1. Start Play and wait for `LMSnapTaken`.
  2. In the Server datamodel, run `TestKit.Run(require(game.ServerStorage.RenseiTests.Play_Boot))`, then the existing `Play_Heat`, `Play_Morality`, `Play_Perception`, `Play_Rumours` and `Play_Stealth` suites.
  3. **Expected:** every suite passes with the same pass counts as before the move.
  4. Restore the profile (`LMTestHook:Invoke("restore")`), then Stop.
  5. **If anything fails, stop.** Undo by moving the `RenseiServer` children back to ServerScriptService and deleting `RenseiBoot`, then report what failed.

- [ ] **Step 6: Commit.**
  - Save `RenseiBoot`'s source to `Art/Studio/Travel/src/RenseiBoot.lua`.
  - Add a line to `Documents/Lindenmoor Kit.md` (the Studio tooling notes): "server code now lives in `ServerStorage.RenseiServer`".
  - Commit.
  - **Tell the owner and jenkins2bee-prog** that server code is now edited in `ServerStorage.RenseiServer`.

---

### Task 4: Packages and the Foundry place boots the full game

**Files:**
- Create: `Art/Studio/Travel/place_setup.lua`
- Create: `Art/Studio/Travel/station_foundry.lua` (placeholder ground and platform; extended in Task 6)

**Interfaces:**
- **Consumes:** Task 3's `RenseiServer` and `RenseiBoot`.
- **Produces:** the Foundry place (109591196441030), with every shared package, Ye's place settings, a 400 × 400 part-ground test area, a station platform, an arrival point (`RenseiArrival`, `Point = "Platform"`), and a road gate (`RenseiArrival`, `Point = "SouthGate"`).

- [ ] **Step 1 (owner):** convert these 13 roots in Ye to Packages (right-click, then "Convert to Package", with **AutoUpdate on**, owned by the Rensei group):
  - `ReplicatedStorage.Modules`
  - `ReplicatedStorage.Remotes`
  - `ReplicatedStorage.Assets`
  - `StarterGui.Uis`
  - `StarterPlayer.StarterPlayerScripts`: ClientHandler, PlayerData, PlayerModule, UIHandler and SwimClient (one package each)
  - `StarterPlayer.StarterCharacterScripts.Animate`
  - `ServerStorage.RenseiServer`
  - `ServerStorage.TruthAssets`
  - `ServerScriptService.RenseiBoot`

  Then open the Foundry Yard place (109591196441030) in Studio as well, so it shows up in `rbxc.py studios`. **The agent waits here** until both are true:
  - every root has a `PackageLink` child (check with `root:FindFirstChildOfClass("PackageLink")`);
  - the Foundry Studio is listed.

- [ ] **Step 2: Read the package ids in Ye.** Return `PackageLink.PackageId` for each root, along with its full path. Save the list to `Art/Studio/Travel/packages.json` (path to `rbxassetid`).

- [ ] **Step 3: Insert the packages into the Foundry place.** For each package, in the Foundry place (Edit):

```lua
local InsertService = game:GetService("InsertService")
local function place(id, parentPath)
	local parent = game
	for p in parentPath:gmatch("[^%.]+") do parent = parent:FindFirstChild(p) or parent:GetService(p) end
	local model = InsertService:LoadAsset(tonumber(id:match("%d+")))
	for _, c in ipairs(model:GetChildren()) do
		local old = parent:FindFirstChild(c.Name)
		if old then old:Destroy() end
		c.Parent = parent
	end
	model:Destroy()
end
-- one line per row of packages.json, e.g. place("rbxassetid://123", "ReplicatedStorage")
```

If `LoadAsset` refuses (Studio plugin permissions), use the MCP `insert_asset` tool with the same ids. If that also fails, the owner pastes the packages in from Ye (copy, then paste into the matching service).

- [ ] **Step 4: Copy the place settings.** Write `place_setup.lua`, which reads Ye's values and prints a Lua table. Run it in Ye, then run the printed table in Foundry to apply it. The settings:
  - `StarterPlayer` properties (CharacterWalkSpeed, CharacterJumpPower, CharacterUseJumpPower, CameraMaxZoomDistance, DevComputerMovementMode, LoadCharacterAppearance);
  - Workspace (Gravity, FallenPartsDestroyHeight; set `StreamingEnabled = true` in Foundry);
  - Lighting (Brightness, ClockTime, Ambient, OutdoorAmbient, EnvironmentDiffuseScale, EnvironmentSpecularScale, the Atmosphere values, and the ColorCorrection and Bloom effects, cloned);
  - SoundService (AmbientReverb).

  `Lighting.Technology` can't be set from the sandbox, so tell the owner its value from Ye.

```lua
-- run in Ye: prints the settings as Lua
local out = {"return function()"}
local function prop(inst, path, names)
	for _, n in ipairs(names) do
		local ok, v = pcall(function() return inst[n] end)
		if ok then
			local s
			if typeof(v) == "Color3" then s = ("Color3.new(%g,%g,%g)"):format(v.R, v.G, v.B)
			elseif typeof(v) == "EnumItem" then s = tostring(v)
			elseif type(v) == "string" then s = ("%q"):format(v)
			else s = tostring(v) end
			table.insert(out, ("  pcall(function() %s.%s = %s end)"):format(path, n, s))
		end
	end
end
prop(game.StarterPlayer, "game.StarterPlayer", {"CharacterWalkSpeed", "CharacterJumpPower", "CharacterUseJumpPower", "CameraMaxZoomDistance", "LoadCharacterAppearance"})
prop(workspace, "workspace", {"Gravity", "FallenPartsDestroyHeight"})
prop(game.Lighting, "game.Lighting", {"Brightness", "ClockTime", "Ambient", "OutdoorAmbient", "EnvironmentDiffuseScale", "EnvironmentSpecularScale", "GeographicLatitude"})
local atm = game.Lighting:FindFirstChildOfClass("Atmosphere")
if atm then
	table.insert(out, '  local a = game.Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere", game.Lighting)')
	prop(atm, "a", {"Density", "Offset", "Color", "Decay", "Glare", "Haze"})
end
table.insert(out, "  workspace.StreamingEnabled = true")
table.insert(out, "end")
return table.concat(out, "\n")
```

- [ ] **Step 5: Build the Foundry placeholder** with `station_foundry.lua`, run in the Foundry place (Edit):
  - a 400 × 400 slab ground: Grass material, top at Y = 4, in the part-ground style;
  - a cobbled platform, 340 × 12, top at Y = 6.4, along Z at X = 0, with rails at X = −10;
  - a `Workspace.World.Map.Foundry` model holding these;
  - two `RenseiArrival` points:
    - `Point = "Platform"`, at (0, 7, 0);
    - `Point = "SouthGate"`, at (150, 5, 190), with a stone gate arch over it;
  - a `SpawnLocation` at the platform (Neutral, Duration 0);
  - a `RenseiArea` volume covering everything, with `AreaName = "Foundry Yard"`.

```lua
local CS = game:GetService("CollectionService")
local Map = workspace:FindFirstChild("World") or Instance.new("Folder", workspace)
Map.Name = "World"
local MapF = Map:FindFirstChild("Map") or Instance.new("Folder", Map)
MapF.Name = "Map"
local old = MapF:FindFirstChild("Foundry")
if old then old:Destroy() end
local F = Instance.new("Model")
F.Name = "Foundry"
local function part(name, size, cf, mat, color, parent)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Material, p.Color = name, size, cf, mat, color
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent or F
	return p
end
part("Ground", Vector3.new(400, 4, 400), CFrame.new(0, 2, 0), Enum.Material.Grass, Color3.fromRGB(82, 106, 54))
part("Platform", Vector3.new(12, 2.4, 340), CFrame.new(0, 5.2, 0), Enum.Material.Cobblestone, Color3.fromRGB(122, 118, 108))
for _, x in ipairs({-12.6, -7.4}) do part("Rail", Vector3.new(0.5, 0.6, 400), CFrame.new(x, 4.3, 0), Enum.Material.Metal, Color3.fromRGB(58, 56, 53)) end
local function arrival(point, pos)
	local a = part("Arrival_" .. point, Vector3.new(4, 1, 4), CFrame.new(pos), Enum.Material.SmoothPlastic, Color3.new(1, 1, 1))
	a.Transparency, a.CanCollide = 1, false
	a:SetAttribute("Point", point)
	CS:AddTag(a, "RenseiArrival")
end
arrival("Platform", Vector3.new(0, 7, 0))
arrival("SouthGate", Vector3.new(150, 5, 190))
for _, x in ipairs({144, 156}) do part("GatePillar", Vector3.new(3, 12, 3), CFrame.new(x, 10, 190), Enum.Material.Cobblestone, Color3.fromRGB(141, 133, 119)) end
part("GateLintel", Vector3.new(15, 2.5, 3.5), CFrame.new(150, 17, 190), Enum.Material.Cobblestone, Color3.fromRGB(141, 133, 119))
local sp = Instance.new("SpawnLocation")
sp.Name, sp.Size, sp.CFrame, sp.Anchored, sp.Neutral, sp.Duration = "Spawn", Vector3.new(8, 1, 8), CFrame.new(0, 6.9, 20), true, true, 0
sp.Transparency = 1
sp.Parent = F
local area = part("Foundry YardArea", Vector3.new(400, 120, 400), CFrame.new(0, 60, 0), Enum.Material.SmoothPlastic, Color3.new(1, 1, 1))
area.Transparency, area.CanCollide, area.CanQuery, area.CanTouch = 1, false, false, false
area:SetAttribute("AreaName", "Foundry Yard")
CS:AddTag(area, "RenseiArea")
F.Parent = MapF
return "foundry placeholder built"
```

- [ ] **Step 6: Boot test in Foundry.**
  1. In the Foundry place, install the profile hook (Task 3 Step 2 source, with the parent `ServerStorage.RenseiServer`), then start Play.
  2. Run `Play_Boot` in its Server datamodel. The test suites aren't packaged, so copy `RenseiTests.TestKit` and `Play_Boot` into Foundry's ServerStorage first.
  3. **Expected:** PASS 2 / FAIL 0.
  4. Check `get_console_output` for errors. Any `ServerStorage.<missing>` error names a runtime dependency that isn't packaged yet. Add it to the package list, ask the owner to package it, and repeat.
  5. Restore the profile, then Stop.

- [ ] **Step 7: Commit.** Commit `Art/Studio/Travel/place_setup.lua`, `station_foundry.lua` and `packages.json`.

---

### Task 5: The group teleport and TravelService (saves, arrival, Studio loopback)

**Files:**
- Modify: `ServerStorage.RenseiServer.FlowTeleport` (add `SendGroup`; keep `Send` unchanged)
- Modify: `ReplicatedStorage.Modules.Data.ProfileData` (add `Travel = {Region = "", Tickets = {}}`)
- Create: `ServerStorage.RenseiServer.TravelService`
- Modify: `ServerStorage.RenseiServer.ServerHandler` (start TravelService after FlowService)
- Test: `ServerStorage.RenseiTests.Play_Travel`

**Interfaces:**
- **Consumes:** `Travel.*`, `Places.*`, `DataManager:Release(Player)`, `ProgressionService.GetData(Player)`, `UIService.Notify(Player, "Toast", {Text})`.
- **Produces:**
  - `FlowTeleport.SendGroup(List, PlaceId, Data, OnFail) -> Group`;
  - `TravelService.Depart(List, RouteId, ArriveAt) -> "sent" | "loopback"`;
  - `TravelService.Here() -> RegionId`;
  - `TravelService.ArrivalPoint(Point) -> BasePart?`;
  - `TravelService.Arrive(Player, Info)`, which also runs in the loopback;
  - `TravelService.Tickets(Player) -> table` (live `Data.Travel.Tickets`);
  - `TravelService.HasTicket(Player, RouteId) -> ClassId?`;
  - `TravelService.AddTicket(Player, RouteId, ClassId)`;
  - `TravelService.UseTicket(Player, RouteId) -> ClassId?`;
  - `TravelService.Arrived` (a BindableEvent: `Player, RegionId, RouteId`).

- [ ] **Step 1: Add the save field.** In `ProfileData`, add the field next to the other top-level tables (splice it in place at a unique anchor, then check it in Play):

```lua
	Travel = {Region = "", Tickets = {}}, -- World plan 1: last region (rejoin goes there) and unused tickets ["Route|Class"] = count
```

  ProfileService's Reconcile adds it to existing saves, and `ProfileGuard` accepts tables of numbers.

- [ ] **Step 2: Write the failing Play test.** Create `ServerStorage.RenseiTests.Play_Travel`:

```lua
local SSS = game.ServerScriptService
return {
	TicketsAddUseAndKeepCount = function(T)
		local TS = require(SSS.TravelService)
		local P = game.Players:GetPlayers()[1]
		local Before = TS.HasTicket(P, "LindenmoorFoundry")
		TS.AddTicket(P, "LindenmoorFoundry", "Second")
		T.Eq(TS.HasTicket(P, "LindenmoorFoundry"), "Second")
		T.Eq(TS.UseTicket(P, "LindenmoorFoundry"), "Second")
		T.Eq(TS.HasTicket(P, "LindenmoorFoundry"), Before)
	end,
	LoopbackArrivesAtThePlatform = function(T)
		local TS = require(SSS.TravelService)
		local P = game.Players:GetPlayers()[1]
		T.True(TS.ArrivalPoint("Platform") ~= nil, "this place has a Platform arrival point")
		TS.AddTicket(P, "LindenmoorFoundry", "Third")
		local Got
		local C = TS.Arrived.Event:Connect(function(Who, Region, Route) if Who == P then Got = {Region, Route} end end)
		T.Eq(TS.Depart({P}, "LindenmoorFoundry", "Platform"), "loopback")
		local t0 = os.clock()
		while not Got and os.clock() - t0 < 5 do task.wait(0.1) end
		C:Disconnect()
		T.True(Got ~= nil, "Arrived fired")
		T.Eq(Got[1], TS.Here(), "loopback stays in this region")
		local d = (P.Character.HumanoidRootPart.Position - TS.ArrivalPoint("Platform").Position).Magnitude
		T.True(d < 8, "standing at the platform (" .. d .. ")")
		T.Eq(TS.HasTicket(P, "LindenmoorFoundry"), nil, "ticket used on arrival")
	end,
	HereMatchesThePlace = function(T)
		local TS = require(SSS.TravelService)
		local Places = require(game.ReplicatedStorage.Modules.Data.Rensei.Places)
		T.Eq(TS.Here(), Places.RegionOf(game.PlaceId) or "Lindenmoor")
	end,
}
```

- [ ] **Step 3: Run it to see it fail.** In Play, expect an error that `TravelService` doesn't exist.

- [ ] **Step 4: Add `SendGroup` to FlowTeleport.** Splice it in after `FlowTeleport.Busy`, and extend the `TeleportInitFailed` and `PlayerRemoving` handlers:

```lua
-- ===== Groups (World plan 1): one TeleportAsync call for a train / party, so they land on one server =====
local Groups = {} -- [Player] = G; G = {PlaceId, Options, Tries, OnFail, Members = {[Player] = true}, Failing}

local GroupFailed
local function Remaining(G)
	local L = {}
	for P in pairs(G.Members) do if P.Parent then table.insert(L, P) end end
	return L
end
local function TryGroup(G)
	local L = Remaining(G)
	if #L == 0 then return end
	G.Tries += 1
	local Ok, Err = pcall(function() TeleportService:TeleportAsync(G.PlaceId, L, G.Options) end)
	if not Ok then GroupFailed(G, tostring(Err), false) end
end
function GroupFailed(G, Why, Final)
	if G.Failing then return end
	G.Failing = true
	warn(("[FlowTeleport] group -> %d failed (try %d of %d): %s"):format(G.PlaceId, G.Tries, FlowTeleport.Tries, Why))
	if Final or G.Tries >= FlowTeleport.Tries then
		for P in pairs(G.Members) do
			Groups[P] = nil
			if P.Parent and G.OnFail then task.spawn(G.OnFail, P, Why) end
		end
		return
	end
	task.wait(G.Tries * 2)
	G.Failing = false
	TryGroup(G)
end

-- Send every player in List to PlaceId together (does not yield). Same TeleportData rules as Send.
function FlowTeleport.SendGroup(List, PlaceId, Data, OnFail)
	local Options = Instance.new("TeleportOptions")
	local TeleportData = table.clone(Data or {})
	TeleportData.Flow = Places.FlowTag
	Options:SetTeleportData(TeleportData)
	local G = {PlaceId = PlaceId, Options = Options, Tries = 0, OnFail = OnFail, Members = {}}
	for _, P in ipairs(List) do
		if not Pending[P] and not Groups[P] then G.Members[P] = true Groups[P] = G end
	end
	task.spawn(TryGroup, G)
	return G
end
```

Change the existing `TeleportInitFailed` handler to:

```lua
TeleportService.TeleportInitFailed:Connect(function(Player, Result, Message)
	if Result == Enum.TeleportResult.IsTeleporting then return end
	local P = Pending[Player]
	if P then task.spawn(Failed, Player, P, Result.Name .. ": " .. tostring(Message), NoRetry[Result]) return end
	local G = Groups[Player]
	if G then task.spawn(GroupFailed, G, Result.Name .. ": " .. tostring(Message), NoRetry[Result]) end
end)
```

and add `Groups[Player] = nil` inside the `PlayerRemoving` handler. Keep the header's "KEEP THIS FILE THE SAME IN EVERY PLACE"; Menu and Tutorial don't need `SendGroup`, but copying it to them is harmless.

- [ ] **Step 5: Write TravelService** (a new ModuleScript in `RenseiServer`):

```lua
-- TravelService (World plan 1, 2026-10-20; world spec §2–3): getting a group from this region to another.
--   * Depart(List, RouteId, ArriveAt): the save is released (DataManager:Release) and the whole group goes in ONE
--     teleport (FlowTeleport.SendGroup) with TeleportData.Travel = {Route, Arrive, From}. A trip that still fails
--     kicks (the save was released); the ticket is only used on arrival, so nothing is lost.
--   * Arrival: a player who joins with TeleportData.Travel spawns at the RenseiArrival part whose Point matches,
--     uses one ticket for the route, and Data.Travel.Region becomes this region (a rejoin comes back here).
--   * Studio can't teleport: Depart runs Arrive in this place instead ("loopback"), at its own arrival point.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Places = require(ReplicatedStorage.Modules.Data.Rensei.Places)
local Travel = require(ReplicatedStorage.Modules.Data.Rensei.Travel)
local DataManager = require(ServerScriptService.CharacterHandler.DataManager)
local FlowTeleport = require(ServerScriptService.FlowTeleport)
local ProgressionService = require(ServerScriptService.ProgressionService)
local UIService = require(ServerScriptService.UIService)

local TravelService = {}
TravelService.Arrived = Instance.new("BindableEvent") -- (Player, RegionId, RouteId)

function TravelService.Here()
	return Places.RegionOf(game.PlaceId) or "Lindenmoor"
end

function TravelService.ArrivalPoint(Point)
	for _, P in ipairs(CollectionService:GetTagged("RenseiArrival")) do
		if P:GetAttribute("Point") == Point and P:IsDescendantOf(workspace) then return P end
	end
	return nil
end

local function TravelData(Player)
	local D = ProgressionService.GetData(Player)
	if not D then return nil end
	D.Travel = D.Travel or {Region = "", Tickets = {}}
	D.Travel.Tickets = D.Travel.Tickets or {}
	return D.Travel
end

function TravelService.Tickets(Player)
	local T = TravelData(Player)
	return T and T.Tickets or {}
end

-- the best class the player holds a ticket for on RouteId (Cabin > Second > Third), or nil
function TravelService.HasTicket(Player, RouteId)
	local Tickets = TravelService.Tickets(Player)
	for I = #Travel.ClassOrder, 1, -1 do
		local C = Travel.ClassOrder[I]
		if (Tickets[Travel.TicketKey(RouteId, C)] or 0) > 0 then return C end
	end
	return nil
end

function TravelService.AddTicket(Player, RouteId, ClassId)
	local T = TravelData(Player)
	if not T or not Travel.Routes[RouteId] or not Travel.Classes[ClassId] then return false end
	local K = Travel.TicketKey(RouteId, ClassId)
	T.Tickets[K] = (T.Tickets[K] or 0) + 1
	return true
end

function TravelService.UseTicket(Player, RouteId)
	local C = TravelService.HasTicket(Player, RouteId)
	if not C then return nil end
	local T = TravelData(Player)
	local K = Travel.TicketKey(RouteId, C)
	T.Tickets[K] -= 1
	if T.Tickets[K] <= 0 then T.Tickets[K] = nil end
	return C
end

local function Spawn(Player, Point)
	local Character = Player.Character or Player.CharacterAdded:Wait()
	local Root = Character:WaitForChild("HumanoidRootPart", 10)
	local At = TravelService.ArrivalPoint(Point) or TravelService.ArrivalPoint("Platform")
	if Root and At then Character:PivotTo(At.CFrame + Vector3.new(0, 3, 0)) end
end

-- Info = {Route = RouteId, Arrive = Point, From = RegionId}
function TravelService.Arrive(Player, Info)
	local Here = TravelService.Here()
	local T = TravelData(Player)
	if T then T.Region = Here end
	if Info.Route and Travel.Routes[Info.Route] and Travel.Routes[Info.Route].Kind == "Rail" then
		TravelService.UseTicket(Player, Info.Route)
	end
	Spawn(Player, Info.Arrive or "Platform")
	local Name = Places.Regions[Here] and Places.Regions[Here].Name or Here
	UIService.Notify(Player, "Toast", {Text = "You arrive in " .. Name .. "."})
	TravelService.Arrived:Fire(Player, Here, Info.Route)
end

function TravelService.Depart(List, RouteId, ArriveAt)
	local Here = TravelService.Here()
	local Dest = Travel.Other(RouteId, Here)
	assert(Dest, "route " .. tostring(RouteId) .. " doesn't leave " .. Here)
	if RunService:IsStudio() then
		for _, P in ipairs(List) do task.spawn(TravelService.Arrive, P, {Route = RouteId, Arrive = ArriveAt, From = Here}) end
		return "loopback"
	end
	local Name = Places.Regions[Dest].Name
	for _, P in ipairs(List) do DataManager:Release(P) end
	FlowTeleport.SendGroup(List, Places.Regions[Dest].PlaceId, {Travel = {Route = RouteId, Arrive = ArriveAt, From = Here}},
		function(P)
			P:Kick(("The journey to %s couldn't be completed. Your ticket is still valid; please rejoin."):format(Name))
		end)
	return "sent"
end

local function PlayerAdded(Player)
	local Join = Player:GetJoinData()
	local Data = Join and Join.TeleportData
	local Info = type(Data) == "table" and type(Data.Travel) == "table" and Data.Travel
	if not Info then
		-- a plain join into this region still records where they are, so a rejoin comes back here
		if DataManager:WaitProfile(Player, 30) then
			local T = TravelData(Player)
			if T then T.Region = TravelService.Here() end
		end
		return
	end
	if not DataManager:WaitProfile(Player, 30) then return end
	TravelService.Arrive(Player, Info)
end

function TravelService.Start()
	Players.PlayerAdded:Connect(PlayerAdded)
	for _, P in ipairs(Players:GetPlayers()) do task.spawn(PlayerAdded, P) end
end

return TravelService
```

- [ ] **Step 6: Start it.** Splice into `RenseiServer.ServerHandler`, right after the `FlowService.Start()` line:

```lua
require(ServerScriptService.TravelService).Start() -- World plan 1: arrivals from other regions, tickets, the group teleport
```

- [ ] **Step 7: Give Ye an arrival point.**
  - Add a `RenseiArrival` part with `Point = "Platform"` on Lindenmoor's station platform: local (−259, 7.5, 0), i.e. world (−259, 11.5, −650).
  - Add one with `Point = "NorthGate"` on the north road: local (0, 6, 330).
  - Save the snippet as `Art/Studio/Travel/arrivals_lindenmoor.lua`. It uses the same `arrival()` helper as `station_foundry.lua`, with `World.Map.Lindenmoor` as the parent.

- [ ] **Step 8: Play tests (Ye).**
  1. Start Play and run `Play_Travel`. Expected: `PASS 3 / FAIL 0`.
  2. Also run `Play_Boot`, `Play_Heat` and `Play_Rumours`, to check for regressions.
  3. Restore the profile, then Stop.

- [ ] **Step 9: Menu resume (Main Menu place, 123967384111466).**
  - Open the Menu place in Studio (owner) and find the line that sends "Main".
  - Use `script_grep` for `Places.Main` in its ServerScriptService.
  - Change the destination to `Places.ResumePlace(Data)`, where `Data` is the profile data the menu already holds.
  - Copy the new `Places` module (Task 1) into the Menu and Tutorial places too ("keep this file the same in every place").
  - Back up first. The live flow can only be tested once the owner publishes; in Studio, check the source change with `script_read`.

- [ ] **Step 10: Commit.** Commit the sources in `Art/Studio/Travel/src/` (TravelService.lua, FlowTeleport.lua, ProfileData snippet, Play_Travel.lua).

---

### Task 6: The station (tickets, boarding, the conductor, the ride)

**Files:**
- Create: `ServerStorage.RenseiServer.StationService`
- Create: `StarterPlayer.StarterPlayerScripts.TravelClient` (a LocalScript; becomes a Package after the plan)
- Create: `Art/Studio/Travel/station_lindenmoor.lua`; extend `station_foundry.lua`
- Modify: `ServerStorage.RenseiServer.ServerHandler` (start StationService after TravelService)
- Test: `ServerStorage.RenseiTests.Play_Station`

**Interfaces:**
- **Consumes:**
  - `TravelService.*`, `Travel.*`;
  - `ProgressionService.SpendMoney(Player, Amount) -> boolean`;
  - `UIService.Notify`;
  - `PartyService.Get(Player) -> {Leader, Members}?`;
  - the train kit (`ServerStorage.TrainKit`).
- **Produces:**
  - Remotes: `ReplicatedStorage.Remotes.Travel`, a RemoteFunction with the attribute `Ready = true` once `OnServerInvoke` is set; and `ReplicatedStorage.Remotes.TravelEvent`, a RemoteEvent.
  - `StationService.Buy(Player, RouteId, ClassId, ForName?) -> boolean, string?`;
  - `StationService.Aboard(RouteId) -> {Player}`;
  - `StationService.Departing` (a BindableEvent: `RouteId, {Player}`), which Task 7's events hook.
  - Station parts:
    - `RenseiTicketClerk` (a part with the attribute `Station = RegionId`);
    - `RenseiPlatformTrain` (a Model with the attribute `Route = RouteId`; its cars hold the `BoardZone` and `CarDoor` parts);
    - `RenseiRideTrain` (a Model with the attribute `Route = RouteId`).
  - Client events (`TravelEvent`, server to client):
    - `"Board", {Route, Departs}`;
    - `"RideStart", {Route, Seconds}`;
    - `"RideEnd", {Dest}`;
    - `"Message", {Text}`.

- [ ] **Step 1: Build Lindenmoor station** with `station_lindenmoor.lua`, run in Ye (Edit):
  1. **Extend the platform:** clone `World.Map.Lindenmoor.Station.Platform`, size it to 340 long on Z centred at Z = 0, and put the old one in the backup.
  2. **Platform train:** clone `ServerStorage.TrainKit` cars into a Model `PlatformTrain` (attribute `Route = "LindenmoorFoundry"`, tag `RenseiPlatformTrain`).
     - Lay them out nose-first to the north along the rails at local X = −270.
     - Rail height is local Y = 4.9; the kit's pivot is at rail height.
     - Each car is rotated so its +X points to +Z: `CFrame.Angles(0, -math.rad(90), 0)`.
     - Car centres start at local Z = +130 for the locomotive and step south by (length + 3).
  3. **Ride train:** a second copy, `RideTrain` (tag `RenseiRideTrain`, same `Route`), at local (0, 400, −1600). It's high above and far away; its windows face the scenery strip that `TravelClient` scrolls.
  4. **Ticket clerk:** a booth beside the station house at local (−245, 7.5, 18), with a `RenseiTicketClerk` part (attribute `Station = "Lindenmoor"`) and an R6 NPC in a State uniform colour.

```lua
local CS = game:GetService("CollectionService")
local O = Vector3.new(0, 4, -650)
local L = workspace.World.Map.Lindenmoor
local Kit = game.ServerStorage.TrainKit
local ORDER = {"Locomotive_Main", "Tender_Main", "BaggageCar_Main", "ThirdClass_Main", "DiningCar_Main", "SecondClass_Main", "CabinCar_Main"}
local LEN = {Locomotive_Main = 72, Tender_Main = 30}
local function lay(name, origin, route, tag)
	local old = L.Station:FindFirstChild(name)
	if old then old.Parent = game.ServerStorage.RenseiBackups["Pre-WorldPlan1_2026-10-20"] end
	local T = Instance.new("Model")
	T.Name = name
	T:SetAttribute("Route", route)
	local z = 0
	for _, n in ipairs(ORDER) do
		local len = LEN[n] or 64
		local car = Kit[n]:Clone()
		car:PivotTo(CFrame.new(origin + Vector3.new(0, 0, -(z + len / 2))) * CFrame.Angles(0, -math.rad(90), 0))
		car.Parent = T
		z += len + 3
	end
	CS:AddTag(T, tag)
	T.Parent = L.Station
	return T
end
lay("PlatformTrain", O + Vector3.new(-270, 4.9, 130), "LindenmoorFoundry", "RenseiPlatformTrain")
lay("RideTrain", O + Vector3.new(0, 400, -1600), "LindenmoorFoundry", "RenseiRideTrain")
local clerk = Instance.new("Part")
clerk.Name, clerk.Size, clerk.Anchored = "TicketClerk", Vector3.new(6, 6, 2), true
clerk.CFrame = CFrame.new(O + Vector3.new(-245, 7.5, 18))
clerk.Material, clerk.Color = Enum.Material.WoodPlanks, Color3.fromRGB(122, 90, 62)
clerk:SetAttribute("Station", "Lindenmoor")
CS:AddTag(clerk, "RenseiTicketClerk")
clerk.Parent = L.Station
return "lindenmoor station built"
```

Extend `station_foundry.lua` the same way, at its platform (X = −10 rails, `Route = "LindenmoorFoundry"`, `Station = "Foundry"`) and with the ride train at (0, 400, −1600).

- [ ] **Step 2: Write the failing Play test.** Create `Play_Station`:

```lua
local SSS = game.ServerScriptService
return {
	BuyChargesAndGivesATicket = function(T)
		local SS, TS, PS = require(SSS.StationService), require(SSS.TravelService), require(SSS.ProgressionService)
		local P = game.Players:GetPlayers()[1]
		local D = PS.GetData(P)
		local Money = D.Money
		D.Money = Money + 100
		local Ok = SS.Buy(P, "LindenmoorFoundry", "Second")
		T.True(Ok, "bought")
		T.Eq(PS.GetData(P).Money, Money + 100 - 30, "2nd class costs 30")
		T.Eq(TS.UseTicket(P, "LindenmoorFoundry"), "Second")
		D.Money = Money
	end,
	CantBuyWithoutMoneyOrLevel = function(T)
		local SS, PS = require(SSS.StationService), require(SSS.ProgressionService)
		local P = game.Players:GetPlayers()[1]
		local D = PS.GetData(P)
		local Money = D.Money
		D.Money = 0
		local Ok, Why = SS.Buy(P, "LindenmoorFoundry", "Third")
		T.True(not Ok and Why ~= nil, "no money")
		D.Money = Money
	end,
	BoardingNeedsATicketAndTheRightCar = function(T)
		local SS = require(SSS.StationService)
		local P = game.Players:GetPlayers()[1]
		T.True(not SS.CanEnter(P, "LindenmoorFoundry", "ThirdClass"), "no ticket")
		require(SSS.TravelService).AddTicket(P, "LindenmoorFoundry", "Third")
		T.True(SS.CanEnter(P, "LindenmoorFoundry", "ThirdClass"))
		T.True(SS.CanEnter(P, "LindenmoorFoundry", "DiningCar"))
		T.True(not SS.CanEnter(P, "LindenmoorFoundry", "SecondClass"), "3rd can't enter 2nd")
		require(SSS.TravelService).UseTicket(P, "LindenmoorFoundry")
	end,
	DepartureMovesTheAboardIntoTheRideTrain = function(T)
		local SS, TS = require(SSS.StationService), require(SSS.TravelService)
		local P = game.Players:GetPlayers()[1]
		TS.AddTicket(P, "LindenmoorFoundry", "Third")
		local Zone
		for _, d in ipairs(workspace:GetDescendants()) do
			if d.Name:find("BoardZone") and d:GetAttribute("CarKind") == "ThirdClass" and d:FindFirstAncestor("PlatformTrain") then Zone = d break end
		end
		P.Character:PivotTo(Zone.CFrame)
		task.wait(0.5)
		SS.DepartNow("LindenmoorFoundry", 3) -- test hook: depart now with a 3-second ride
		task.wait(1)
		local Ride = workspace:FindFirstChild("RideTrain", true)
		local d = (P.Character.HumanoidRootPart.Position - Ride:GetPivot().Position).Magnitude
		T.True(d < 400, "inside the ride train (" .. d .. ")")
		local t0 = os.clock()
		while TS.HasTicket(P, "LindenmoorFoundry") and os.clock() - t0 < 8 do task.wait(0.2) end
		T.Eq(TS.HasTicket(P, "LindenmoorFoundry"), nil, "arrived (loopback) and used the ticket")
	end,
}
```

- [ ] **Step 3: Run it to see it fail.** Expected: `StationService` doesn't exist.

- [ ] **Step 4: Write StationService:**

```lua
-- StationService (World plan 1, 2026-10-20; world spec §2, §4): the railway in this region.
--   * Ticket clerk (RenseiTicketClerk): Buy(Route, Class[, party member]) charges ProgressionService.SpendMoney.
--   * Departures run on the shared clock (Travel.NextDeparture on os.time()), so every server agrees.
--   * Boarding: from Travel.BoardingWindow seconds before departure, a player with a ticket standing in a car's
--     BoardZone (or anywhere inside the platform train) is aboard; the conductor stops anyone at a CarDoor whose
--     class doesn't reach that car (pushed back, told why).
--   * At departure: a "doors closing" fade, everyone aboard moves to the same spot in the ride train, the ride runs
--     Route.Ride seconds (events from Task 7 hook Departing), then TravelService.Depart sends them all together.
-- Every number is a PROPOSAL.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Travel = require(ReplicatedStorage.Modules.Data.Rensei.Travel)
local TravelService = require(ServerScriptService.TravelService)
local ProgressionService = require(ServerScriptService.ProgressionService)
local UIService = require(ServerScriptService.UIService)
local PartyService = require(ServerScriptService.PartyService)

local StationService = {}
StationService.Departing = Instance.new("BindableEvent") -- (RouteId, {Player}, RideSeconds)
StationService.Season = function() return "Summer" end -- the seasons plan replaces this

local Remote, Event
local Riding = {} -- [Player] = RouteId

local function Notify(P, Text) UIService.Notify(P, "Toast", {Text = Text}) end

local function Level(P)
	local D = ProgressionService.GetData(P)
	return D and D.Level or 1
end

local function FindPlayer(From, Name)
	local Party = PartyService.Get(From)
	if not Party then return nil end
	for _, M in ipairs(Party.Members) do
		if M.Name == Name or M.DisplayName == Name then return M end
	end
	return nil
end

function StationService.Buy(Player, RouteId, ClassId, ForName)
	local R = Travel.Routes[RouteId]
	if not R or R.Kind ~= "Rail" or not Travel.Classes[ClassId] then return false, "No such ticket." end
	if not Travel.Other(RouteId, TravelService.Here()) then return false, "That train doesn't stop here." end
	local Rider = Player
	if ForName then
		Rider = FindPlayer(Player, ForName)
		if not Rider then return false, "They aren't in your party." end
	end
	local Ok, Why = Travel.CanTake(Level(Rider), RouteId)
	if not Ok then return false, Why end
	local Price = Travel.Price(RouteId, ClassId, StationService.Season())
	if not ProgressionService.SpendMoney(Player, Price) then return false, ("A ticket costs $%d."):format(Price) end
	TravelService.AddTicket(Rider, RouteId, ClassId)
	if Rider ~= Player then Notify(Rider, Player.DisplayName .. " bought you a ticket.") end
	return true
end

function StationService.CanEnter(Player, RouteId, CarKind)
	local C = TravelService.HasTicket(Player, RouteId)
	return C ~= nil and Travel.ClassReaches(C, CarKind)
end

local function TrainOf(Tag, RouteId)
	for _, T in ipairs(CollectionService:GetTagged(Tag)) do
		if T:GetAttribute("Route") == RouteId and T:IsDescendantOf(workspace) then return T end
	end
	return nil
end

local function Inside(Model, Pos)
	local CF, Size = Model:GetBoundingBox()
	local L = CF:PointToObjectSpace(Pos)
	return math.abs(L.X) <= Size.X / 2 and math.abs(L.Y) <= Size.Y / 2 and math.abs(L.Z) <= Size.Z / 2
end

function StationService.Aboard(RouteId)
	local Train = TrainOf("RenseiPlatformTrain", RouteId)
	local Out = {}
	if not Train then return Out end
	for _, P in ipairs(Players:GetPlayers()) do
		local Root = P.Character and P.Character:FindFirstChild("HumanoidRootPart")
		if Root and not Riding[P] and TravelService.HasTicket(P, RouteId) and Inside(Train, Root.Position) then table.insert(Out, P) end
	end
	return Out
end

-- conductor: a CarDoor touched by someone whose class doesn't reach that car pushes them back
local function GuardDoors()
	for _, Door in ipairs(CollectionService:GetTagged("RenseiCarDoor")) do
		Door.Touched:Connect(function(Hit)
			local P = Players:GetPlayerFromCharacter(Hit.Parent)
			local Train = Door:FindFirstAncestorWhichIsA("Model") and Door:FindFirstAncestorWhichIsA("Model"):FindFirstAncestorWhichIsA("Model")
			local RouteId = Train and Train:GetAttribute("Route")
			if not P or not RouteId then return end
			local Kind = Door:GetAttribute("CarKind")
			if StationService.CanEnter(P, RouteId, Kind) then return end
			local Root = P.Character:FindFirstChild("HumanoidRootPart")
			if Root and not P:GetAttribute("ConductorWarned") then
				P:SetAttribute("ConductorWarned", true)
				Root.CFrame = Root.CFrame - Root.CFrame.LookVector * 4
				Notify(P, "Conductor: \"Ticket for this car, please.\"")
				task.delay(2, function() P:SetAttribute("ConductorWarned", nil) end)
			end
		end)
	end
end

local function Depart(RouteId, RideSeconds)
	local List = StationService.Aboard(RouteId)
	if #List == 0 then return end
	local Platform, Ride = TrainOf("RenseiPlatformTrain", RouteId), TrainOf("RenseiRideTrain", RouteId)
	if not (Platform and Ride) then return end
	local Offset = Ride:GetPivot() * Platform:GetPivot():Inverse()
	for _, P in ipairs(List) do
		Riding[P] = RouteId
		Event:FireClient(P, "RideStart", {Route = RouteId, Seconds = RideSeconds})
	end
	task.wait(0.6) -- the client fades to black ("doors closing")
	for _, P in ipairs(List) do
		local C = P.Character
		if C and C.Parent then C:PivotTo(Offset * C:GetPivot()) end
	end
	StationService.Departing:Fire(RouteId, List, RideSeconds)
	task.wait(RideSeconds)
	local Still = {}
	for _, P in ipairs(List) do
		if P.Parent and Riding[P] == RouteId then table.insert(Still, P) end
	end
	for _, P in ipairs(Still) do Event:FireClient(P, "RideEnd", {Route = RouteId}) end
	TravelService.Depart(Still, RouteId, "Platform")
	for _, P in ipairs(List) do Riding[P] = nil end
end

-- test hook: depart now with a short ride (Studio tests only)
function StationService.DepartNow(RouteId, RideSeconds)
	task.spawn(Depart, RouteId, RideSeconds or Travel.Routes[RouteId].Ride)
end

function StationService.Riding(Player) return Riding[Player] end

local function Clock()
	local Here = TravelService.Here()
	local Last = {}
	while true do
		local Now = os.time()
		for _, RouteId in ipairs(Travel.RoutesFrom(Here, "Rail")) do
			local R = Travel.Routes[RouteId]
			local Prev = math.floor(Now / R.Every) * R.Every -- the departure that just happened
			if Last[RouteId] ~= Prev and Now - Prev < 2 and TrainOf("RenseiPlatformTrain", RouteId) then
				Last[RouteId] = Prev
				task.spawn(Depart, RouteId, R.Ride)
			end
		end
		task.wait(1)
	end
end

function StationService.Start()
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	Remote = Remotes:FindFirstChild("Travel") or Instance.new("RemoteFunction")
	Remote.Name = "Travel"
	Remote.Parent = Remotes
	Event = Remotes:FindFirstChild("TravelEvent") or Instance.new("RemoteEvent")
	Event.Name = "TravelEvent"
	Event.Parent = Remotes
	Remote.OnServerInvoke = function(Player, Op, Args)
		Args = type(Args) == "table" and Args or {}
		if Op == "Buy" then
			return StationService.Buy(Player, Args.Route, Args.Class, type(Args.For) == "string" and Args.For or nil)
		elseif Op == "Prices" then
			local Out = {}
			for _, RouteId in ipairs(Travel.RoutesFrom(TravelService.Here(), "Rail")) do
				local Row = {Route = RouteId, To = Travel.Other(RouteId, TravelService.Here()), Prices = {}, Held = TravelService.HasTicket(Player, RouteId)}
				for _, C in ipairs(Travel.ClassOrder) do Row.Prices[C] = Travel.Price(RouteId, C, StationService.Season()) end
				table.insert(Out, Row)
			end
			return Out
		end
		return false, "Unknown request."
	end
	Remote:SetAttribute("Ready", true)
	for _, Clerk in ipairs(CollectionService:GetTagged("RenseiTicketClerk")) do
		local Prompt = Instance.new("ProximityPrompt")
		Prompt.ActionText, Prompt.ObjectText, Prompt.MaxActivationDistance = "Buy a ticket", "Ticket clerk", 10
		Prompt.Parent = Clerk
		Prompt.Triggered:Connect(function(P) Event:FireClient(P, "OpenTickets", {}) end)
	end
	for _, D in ipairs(workspace:GetDescendants()) do
		if D:IsA("BasePart") and D.Name:find("CarDoor") and D:FindFirstAncestor("PlatformTrain") then CollectionService:AddTag(D, "RenseiCarDoor") end
	end
	GuardDoors()
	Players.PlayerRemoving:Connect(function(P) Riding[P] = nil end)
	task.spawn(Clock)
end

return StationService
```

The kit importer names helper parts `CarDoor-1` and `CarDoor1`, which is why the code uses `Name:find("CarDoor")`.

- [ ] **Step 5: Write TravelClient** (a LocalScript in StarterPlayerScripts). It has four jobs:
  - **Ticket window** (on `OpenTickets`): one row per route, with a button per class showing its price. Clicking calls `Travel:InvokeServer("Buy", {Route, Class})` and shows the result.
  - **Departure board:** a SurfaceGui on any part named `DepartureBoard`, showing the next departure on each route from `workspace:GetServerTimeNow()` and `Travel.NextDeparture`.
  - **Ride:** on `RideStart`, fade to black for 0.6 s, then fade in. Scenery blocks scroll past the ride train's windows for the ride's length.
  - **Teleport screen:** on `RideEnd`, call `TeleportService:SetTeleportGui` with a "pulling into the station" screen.

  The client only asks the server once the remote's `Ready` attribute is set (memory gotcha), and releases its in-flight flag after a 10 s timeout.

```lua
-- TravelClient (World plan 1, 2026-10-20): ticket window, departure boards, the ride's scenery and fades, the
-- teleport screen. Server: StationService (Remotes.Travel / Remotes.TravelEvent). Style matches Modules.UI (Rensei
-- palette: dark panel, brass accents).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local Travel = require(ReplicatedStorage.Modules.Data.Rensei.Travel)
local Places = require(ReplicatedStorage.Modules.Data.Rensei.Places)

local Player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Remote = Remotes:WaitForChild("Travel")
local Event = Remotes:WaitForChild("TravelEvent")

local Gui = Instance.new("ScreenGui")
Gui.Name, Gui.ResetOnSpawn, Gui.IgnoreGuiInset, Gui.DisplayOrder = "TravelUI", false, true, 50
Gui.Parent = Player:WaitForChild("PlayerGui")

local PANEL, BRASS, INK = Color3.fromRGB(21, 26, 28), Color3.fromRGB(176, 138, 60), Color3.fromRGB(236, 226, 212)

local Fade = Instance.new("Frame")
Fade.Size, Fade.BackgroundColor3, Fade.BackgroundTransparency, Fade.ZIndex = UDim2.fromScale(1, 1), Color3.new(0, 0, 0), 1, 50
Fade.Parent = Gui
local function FadeTo(Alpha, Time)
	TweenService:Create(Fade, TweenInfo.new(Time), {BackgroundTransparency = Alpha}):Play()
end

local Busy = false
local function Ask(Op, Args)
	if Busy or not Remote:GetAttribute("Ready") then return false, "The clerk is busy." end
	Busy = true
	local Mine = {}
	local Token = Mine
	task.delay(10, function() if Token == Mine then Busy = false end end)
	local Ok, A, B = pcall(function() return Remote:InvokeServer(Op, Args) end)
	Token = nil
	Busy = false
	if not Ok then return false, "No answer from the clerk." end
	return A, B
end

local Window
local function Label(Parent, Text, Size, Pos, Bold)
	local L = Instance.new("TextLabel")
	L.BackgroundTransparency, L.Text, L.TextColor3, L.Size, L.Position = 1, Text, INK, Size, Pos
	L.Font, L.TextScaled, L.TextXAlignment = Bold and Enum.Font.GothamBold or Enum.Font.Gotham, true, Enum.TextXAlignment.Left
	L.Parent = Parent
	return L
end
local function OpenTickets()
	if Window then Window:Destroy() end
	local Rows = Ask("Prices")
	if type(Rows) ~= "table" then return end
	Window = Instance.new("Frame")
	Window.Size, Window.Position, Window.AnchorPoint = UDim2.fromOffset(460, 80 + #Rows * 70), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5)
	Window.BackgroundColor3 = PANEL
	Window.Parent = Gui
	Instance.new("UICorner", Window).CornerRadius = UDim.new(0, 6)
	local Stroke = Instance.new("UIStroke", Window)
	Stroke.Color = BRASS
	Label(Window, "Tickets", UDim2.fromOffset(300, 30), UDim2.fromOffset(16, 10), true)
	local Status = Label(Window, "", UDim2.fromOffset(428, 20), UDim2.new(0, 16, 1, -28), false)
	for I, Row in ipairs(Rows) do
		local Y = 50 + (I - 1) * 70
		local To = Places.Regions[Row.To] and Places.Regions[Row.To].Name or Row.To
		Label(Window, "To " .. To .. (Row.Held and ("  (holding " .. Travel.Classes[Row.Held].Name .. ")") or ""), UDim2.fromOffset(428, 22), UDim2.fromOffset(16, Y), false)
		for J, C in ipairs(Travel.ClassOrder) do
			local B = Instance.new("TextButton")
			B.Size, B.Position = UDim2.fromOffset(136, 32), UDim2.fromOffset(16 + (J - 1) * 144, Y + 26)
			B.BackgroundColor3, B.TextColor3, B.Font, B.TextScaled = Color3.fromRGB(36, 44, 47), INK, Enum.Font.Gotham, true
			B.Text = ("%s  $%d"):format(Travel.Classes[C].Name, Row.Prices[C])
			B.Parent = Window
			B.Activated:Connect(function()
				local Ok, Why = Ask("Buy", {Route = Row.Route, Class = C})
				Status.Text = Ok and "Bought. Board when the doors open." or (Why or "Couldn't buy that.")
			end)
		end
	end
	local Close = Instance.new("TextButton")
	Close.Size, Close.Position, Close.Text = UDim2.fromOffset(28, 28), UDim2.new(1, -36, 0, 8), "X"
	Close.BackgroundColor3, Close.TextColor3 = Color3.fromRGB(36, 44, 47), INK
	Close.Parent = Window
	Close.Activated:Connect(function() Window:Destroy() Window = nil end)
end

-- departure boards: any part named DepartureBoard gets a SurfaceGui with the next train on each route
local function Boards()
	while true do
		local Now = workspace:GetServerTimeNow()
		for _, B in ipairs(workspace:GetDescendants()) do
			if B:IsA("BasePart") and B.Name == "DepartureBoard" then
				local SG = B:FindFirstChild("Board") or Instance.new("SurfaceGui")
				SG.Name, SG.Face, SG.Parent = "Board", Enum.NormalId.Front, B
				local T = SG:FindFirstChild("T") or Instance.new("TextLabel")
				T.Name, T.Size, T.BackgroundColor3, T.TextColor3, T.TextScaled, T.Font = "T", UDim2.fromScale(1, 1), PANEL, BRASS, true, Enum.Font.Code
				T.Parent = SG
				local Lines = {}
				local Here = Places.RegionOf(game.PlaceId) or "Lindenmoor"
				for _, RouteId in ipairs(Travel.RoutesFrom(Here, "Rail")) do
					local D = Travel.NextDeparture(RouteId, Now)
					local To = Places.Regions[Travel.Other(RouteId, Here)].Name
					local Left = math.max(0, math.floor(D - Now))
					table.insert(Lines, ("%-22s %d:%02d%s"):format(To, Left // 60, Left % 60, Travel.BoardingOpen(RouteId, Now) and "  BOARDING" or ""))
				end
				T.Text = table.concat(Lines, "\n")
			end
		end
		task.wait(1)
	end
end

-- the ride: scenery blocks scroll past the ride train's windows
local Scenery
local function Ride(Seconds)
	FadeTo(0, 0.5)
	task.wait(0.7)
	FadeTo(1, 0.8)
	local Train = workspace:FindFirstChild("RideTrain", true)
	if not Train then return end
	local CF = Train:GetPivot()
	Scenery = Instance.new("Folder")
	Scenery.Name = "RideScenery"
	Scenery.Parent = workspace
	local Blocks = {}
	local rnd = Random.new()
	for I = 1, 60 do
		local P = Instance.new("Part")
		P.Anchored, P.CanCollide, P.CanQuery, P.CastShadow = true, false, false, false
		local Tree = rnd:NextNumber() < 0.6
		P.Size = Tree and Vector3.new(6, rnd:NextNumber(12, 24), 6) or Vector3.new(rnd:NextNumber(10, 30), rnd:NextNumber(2, 8), 8)
		P.Material = Tree and Enum.Material.LeafyGrass or Enum.Material.Grass
		P.Color = Tree and Color3.fromRGB(58, 86, 44) or Color3.fromRGB(96, 118, 64)
		local Side = (I % 2 == 0) and 1 or -1
		local Along = rnd:NextNumber(-260, 260)
		local Across = Side * rnd:NextNumber(20, 90)
		P.CFrame = CF * CFrame.new(Across, P.Size.Y / 2 - 6, Along)
		P.Parent = Scenery
		table.insert(Blocks, {Part = P, Across = Across, Along = Along, H = P.Size.Y / 2 - 6})
	end
	local Ground = Instance.new("Part")
	Ground.Anchored, Ground.CanCollide, Ground.Size = true, false, Vector3.new(400, 1, 600)
	Ground.Material, Ground.Color, Ground.CFrame = Enum.Material.Grass, Color3.fromRGB(82, 106, 54), CF * CFrame.new(0, -7, 0)
	Ground.Parent = Scenery
	local Speed, T0 = 70, os.clock()
	local Conn
	Conn = RunService.RenderStepped:Connect(function(Dt)
		if os.clock() - T0 > Seconds + 2 or not Scenery then Conn:Disconnect() return end
		for _, B in ipairs(Blocks) do
			B.Along -= Speed * Dt
			if B.Along < -280 then B.Along += 560 end
			B.Part.CFrame = CF * CFrame.new(B.Across, B.H, B.Along)
		end
	end)
end

local function TeleportScreen(Dest)
	local S = Instance.new("ScreenGui")
	S.IgnoreGuiInset = true
	local F = Instance.new("Frame")
	F.Size, F.BackgroundColor3 = UDim2.fromScale(1, 1), Color3.fromRGB(12, 14, 15)
	F.Parent = S
	local T = Instance.new("TextLabel")
	T.Size, T.Position, T.AnchorPoint = UDim2.fromScale(0.6, 0.1), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5)
	T.BackgroundTransparency, T.TextColor3, T.TextScaled, T.Font = 1, INK, true, Enum.Font.GothamBold
	T.Text = "Pulling into " .. (Dest or "the station") .. "..."
	T.Parent = F
	TeleportService:SetTeleportGui(S)
	FadeTo(0, 0.5)
end

Event.OnClientEvent:Connect(function(Kind, Data)
	if Kind == "OpenTickets" then OpenTickets()
	elseif Kind == "RideStart" then task.spawn(Ride, Data.Seconds)
	elseif Kind == "RideEnd" then
		local Here = Places.RegionOf(game.PlaceId) or "Lindenmoor"
		local Dest = Travel.Other(Data.Route, Here)
		TeleportScreen(Dest and Places.Regions[Dest].Name)
		if Scenery then Scenery:Destroy() Scenery = nil end
		task.delay(3, function() FadeTo(1, 0.5) end) -- Studio loopback: fade back in
	elseif Kind == "Message" then
		-- toasts already come through UIService; nothing else here
	end
end)

task.spawn(Boards)
```

- [ ] **Step 6: Start it and add a departure board.**
  - Splice `require(ServerScriptService.StationService).Start() -- World plan 1: tickets, boarding, the ride` into `ServerHandler`, after the `TravelService` line.
  - Add a `DepartureBoard` part (8 × 4 × 0.4, facing the platform) to `station_lindenmoor.lua` and `station_foundry.lua`.

- [ ] **Step 7: Run `Play_Station` and the earlier suites (Ye).**
  - Expected: Play_Station PASS 4, Play_Travel PASS 3, and the earlier suites unchanged.
  - **By hand:** walk up to the clerk, press E, buy 3rd class. Stand in the 3rd-class car; try to walk into the 2nd-class car (the conductor stops you). Wait for departure: the fade, the ride, then arrival at the platform (loopback).
  - Screenshot the ticket window and the ride with `screen_capture`.
  - Restore the profile, then Stop.

- [ ] **Step 8: Commit.** Commit the sources (`StationService.lua`, `TravelClient.lua`, `Play_Station.lua`) and the station scripts.

---

### Task 7: Ride events (inspection, rumour, pickpocket, holdup)

**Files:**
- Create: `ServerStorage.RenseiServer.RideEvents`
- Modify: `ServerHandler` (start RideEvents after StationService)
- Test: `ServerStorage.RenseiTests.Play_RideEvents`

**Interfaces:**
- **Consumes:** `StationService.Departing(RouteId, List, RideSeconds)`, `Travel.PickRideEvent`, `Travel.Fine`, `ProgressionService.SpendMoney`, `RumourService` (read-only: `Data.Morality.Rumours`), `EnemyService.Spawn`. Look up EnemyService's spawn function name with `script_grep` "function EnemyService" in `RenseiServer.EnemyService`, and use that exact name.
- **Produces:** `RideEvents.Run(EventId, RouteId, List)`, which the tests can call with a forced event.

- [ ] **Step 1: Write the failing test** (`Play_RideEvents`):

```lua
local SSS = game.ServerScriptService
return {
	InspectionFinesTheTicketless = function(T)
		local RE, PS = require(SSS.RideEvents), require(SSS.ProgressionService)
		local P = game.Players:GetPlayers()[1]
		local D = PS.GetData(P)
		local Money = D.Money
		D.Money = 100
		RE.Run("Inspection", "LindenmoorFoundry", {P}, {[P] = false}) -- false = boarded without a ticket (stowaway)
		T.Eq(PS.GetData(P).Money, 100 - 45, "fined 3x the base price")
		D.Money = Money
	end,
	RumourEventTellsSomething = function(T)
		local RE = require(SSS.RideEvents)
		local P = game.Players:GetPlayers()[1]
		local Said = RE.Run("Rumour", "LindenmoorFoundry", {P}, {[P] = true})
		T.True(type(Said) == "string" and #Said > 0, "a rumour line")
	end,
	HoldupSpawnsBandits = function(T)
		local RE = require(SSS.RideEvents)
		local P = game.Players:GetPlayers()[1]
		local Spawned = RE.Run("Holdup", "LindenmoorFoundry", {P}, {[P] = true})
		T.True(type(Spawned) == "number" and Spawned >= 1, "bandits in the aisle")
		RE.ClearHoldup()
	end,
}
```

- [ ] **Step 2: Run it to see it fail.**

- [ ] **Step 3: Write RideEvents:**

```lua
-- RideEvents (World plan 1, 2026-10-20; world spec §2): one event per ride, picked by weight (Travel.RideEvents).
--   Inspection: the conductor checks tickets; anyone aboard without one (a stowaway) pays a fine (3x base) or is
--               thrown off at the next fade (sent back to this station's platform).
--   Rumour:     a passenger mentions a real rumour about the rider waiting in the destination, else a lore line.
--   Pickpocket: $5-15 lifted from one rider unless they catch the thief (a PROPOSAL: a 6 s chase prompt).
--   Holdup:     2 bandits appear in the dining car aisle (EnemyService), gone at arrival.
--   Quiet:      nothing.
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Travel = require(ReplicatedStorage.Modules.Data.Rensei.Travel)
local Places = require(ReplicatedStorage.Modules.Data.Rensei.Places)
local ProgressionService = require(ServerScriptService.ProgressionService)
local UIService = require(ServerScriptService.UIService)

local RideEvents = {}
local Bandits = {}
local LORE = {
	"\"They say the Foundry smelters never go cold, not even at night.\"",
	"\"A State alchemist rode this line last week. Didn't say a word the whole way.\"",
	"\"Bandits have been hitting the roads north of Lindenmoor. Glad I took the train.\"",
}

local function Say(P, Text) UIService.Notify(P, "Toast", {Text = Text}) end

function RideEvents.Run(EventId, RouteId, List, HasTicket)
	if EventId == "Inspection" then
		for _, P in ipairs(List) do
			if HasTicket[P] == false then
				local Fine = Travel.Fine(RouteId)
				if ProgressionService.SpendMoney(P, Fine) then
					Say(P, ("Conductor: \"No ticket? That's a $%d fine.\""):format(Fine))
				else
					P:SetAttribute("ThrownOff", true)
					Say(P, "Conductor: \"No ticket and no money. Off at the next stop.\"")
				end
			else
				Say(P, "The conductor clips your ticket.")
			end
		end
		return true
	elseif EventId == "Rumour" then
		local Line
		local P = List[1]
		local D = P and ProgressionService.GetData(P)
		local Rumours = D and D.Morality and D.Morality.Rumours
		if type(Rumours) == "table" and #Rumours > 0 then
			local Deeds = require(ReplicatedStorage.Modules.Data.Rensei.Deeds)
			local R = Rumours[math.random(1, #Rumours)]
			local Def = Deeds[R.Deed]
			if type(Def) == "table" and Def.Text then Line = "A passenger whispers: \"Heard about someone who " .. Def.Text:lower() .. "\"" end
		end
		Line = Line or ("A passenger says: " .. LORE[math.random(1, #LORE)])
		for _, Q in ipairs(List) do Say(Q, Line) end
		return Line
	elseif EventId == "Pickpocket" then
		local P = List[math.random(1, #List)]
		local Amount = math.random(5, 15)
		if ProgressionService.SpendMoney(P, Amount) then Say(P, ("Someone brushes past you... $%d is gone."):format(Amount)) end
		return Amount
	elseif EventId == "Holdup" then
		local EnemyService = require(ServerScriptService.EnemyService)
		local Ride = workspace:FindFirstChild("RideTrain", true)
		local Car = Ride and Ride:FindFirstChild("DiningCar_Main")
		local N = 0
		if Car then
			local CF = Car:GetPivot()
			for I = 1, 2 do
				-- use EnemyService's own spawn function (name checked in Interfaces) with type "Grunt"
				local Rig = EnemyService.Spawn("Grunt", CF * CFrame.new((I - 1.5) * 6, 7, 0))
				if Rig then table.insert(Bandits, Rig) N += 1 end
			end
		end
		for _, P in ipairs(List) do Say(P, "\"Nobody move! Hand over your valuables!\"") end
		return N
	end
	return nil
end

function RideEvents.ClearHoldup()
	for _, B in ipairs(Bandits) do if B.Parent then B:Destroy() end end
	Bandits = {}
end

function RideEvents.Start()
	local StationService = require(ServerScriptService.StationService)
	local TravelService = require(ServerScriptService.TravelService)
	StationService.Departing.Event:Connect(function(RouteId, List, Seconds)
		local Has = {}
		for _, P in ipairs(List) do Has[P] = TravelService.HasTicket(P, RouteId) ~= nil end
		task.wait(math.min(8, Seconds * 0.3))
		RideEvents.Run(Travel.PickRideEvent(math.random()), RouteId, List, Has)
		task.delay(Seconds, RideEvents.ClearHoldup)
	end)
end

return RideEvents
```

If EnemyService's spawn function has a different name or signature, adapt the two Holdup lines to it, and record the actual call in the task report.

- [ ] **Step 4: Run it to see it pass.** Start it in `ServerHandler`, after StationService. Run `Play_RideEvents` (expected PASS 3), restore the profile, then Stop.

- [ ] **Step 5: Commit.**

---

### Task 8: Road exits and road journeys (with ambushes)

**Files:**
- Create: `ServerStorage.RenseiServer.RoadService`
- Modify: `TravelClient` (travel card, journey screen)
- Modify: `station_lindenmoor.lua` / `station_foundry.lua`: add `RenseiRoadExit` parts (attribute `Route`, `Arrive`), a gate arch, and a `RenseiAmbushArena` part
- Test: `ServerStorage.RenseiTests.Play_Road`

**Interfaces:**
- **Consumes:** `Travel.AmbushChance`, `Travel.Routes` (the Road kind), `TravelService.Depart`, `HeatService.Wanted(Player, "State")`, `PartyService.Get`, `EnemyService` spawn (as in Task 7).
- **Produces:**
  - `RoadService.Start()`;
  - `RoadService.Journey(Leader, RouteId, ForceAmbush?) -> "ambush" | "sent" | "loopback"`;
  - `RoadService.ArenaCleared` (a BindableEvent).
  - Lindenmoor's road exit is the north road at local (0, 6, 340), with `Route = "RoadLindenmoorFoundry"` and `Arrive = "SouthGate"`.
  - Foundry's road exit is the south gate at (150, 5, 190), with the same route and `Arrive = "NorthGate"`.

- [ ] **Step 1: Write the failing test** (`Play_Road`):

```lua
local SSS = game.ServerScriptService
return {
	NoAmbushJourneyArrives = function(T)
		local RS, TS = require(SSS.RoadService), require(SSS.TravelService)
		local P = game.Players:GetPlayers()[1]
		local Got
		local C = TS.Arrived.Event:Connect(function(Who) if Who == P then Got = true end end)
		T.Eq(RS.Journey(P, "RoadLindenmoorFoundry", false), "loopback")
		local t0 = os.clock()
		while not Got and os.clock() - t0 < 5 do task.wait(0.1) end
		C:Disconnect()
		T.True(Got, "arrived")
	end,
	AmbushStopsInTheArenaThenContinues = function(T)
		local RS = require(SSS.RoadService)
		local P = game.Players:GetPlayers()[1]
		T.Eq(RS.Journey(P, "RoadLindenmoorFoundry", true), "ambush")
		local Arena = workspace:FindFirstChild("AmbushArena", true)
		T.True((P.Character.HumanoidRootPart.Position - Arena.Position).Magnitude < 40, "in the arena")
		RS.ClearArena(P) -- test hook: count the fight as won
		task.wait(1)
		T.True(not RS.InAmbush(P), "journey continued")
	end,
}
```

- [ ] **Step 2: Run it to see it fail.**

- [ ] **Step 3: Write RoadService:**

```lua
-- RoadService (World plan 1, 2026-10-20; world spec §3): road exits (RenseiRoadExit parts: Route, Arrive) start a
-- road journey for the player's whole party: free, no papers. Before leaving, the trip may be ambushed
-- (Travel.AmbushChance: night, winter, Wanted): the party is moved into this place's RenseiAmbushArena with 2-3
-- enemies; when they're beaten (or the party walks out of the arena), the journey continues.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Lighting = game:GetService("Lighting")

local Travel = require(ReplicatedStorage.Modules.Data.Rensei.Travel)
local TravelService = require(ServerScriptService.TravelService)
local PartyService = require(ServerScriptService.PartyService)
local UIService = require(ServerScriptService.UIService)

local RoadService = {}
RoadService.Season = function() return "Summer" end -- the seasons plan replaces this
local Ambushes = {} -- [Player] = {Route, Arrive, Party, Enemies}

local function PartyOf(P)
	local Party = PartyService.Get(P)
	return Party and table.clone(Party.Members) or {P}
end

local function Wanted(P)
	local Ok, W = pcall(function() return require(ServerScriptService.HeatService).Wanted(P, "State") end)
	return Ok and W or 0
end

function RoadService.InAmbush(P) return Ambushes[P] ~= nil end

local function Continue(A)
	for _, M in ipairs(A.Party) do Ambushes[M] = nil end
	for _, E in ipairs(A.Enemies) do if E.Parent then E:Destroy() end end
	local Still = {}
	for _, M in ipairs(A.Party) do if M.Parent then table.insert(Still, M) end end
	if #Still > 0 then TravelService.Depart(Still, A.Route, A.Arrive) end
end

function RoadService.ClearArena(P)
	local A = Ambushes[P]
	if A then Continue(A) end
end

function RoadService.Journey(Leader, RouteId, ForceAmbush)
	local R = Travel.Routes[RouteId]
	assert(R and R.Kind == "Road", "not a road")
	local Party = PartyOf(Leader)
	local Exit
	for _, E in ipairs(CollectionService:GetTagged("RenseiRoadExit")) do if E:GetAttribute("Route") == RouteId then Exit = E end end
	local Arrive = Exit and Exit:GetAttribute("Arrive") or "Platform"
	local MaxWanted = 0
	for _, M in ipairs(Party) do MaxWanted = math.max(MaxWanted, Wanted(M)) end
	local Night = Lighting.ClockTime < 6 or Lighting.ClockTime > 19
	local Ambush = ForceAmbush
	if Ambush == nil then Ambush = math.random() < Travel.AmbushChance(Night, RoadService.Season() == "Winter", MaxWanted) end
	if not Ambush then return TravelService.Depart(Party, RouteId, Arrive) end
	local Arena = workspace:FindFirstChild("AmbushArena", true)
	if not Arena then return TravelService.Depart(Party, RouteId, Arrive) end
	local A = {Route = RouteId, Arrive = Arrive, Party = Party, Enemies = {}}
	for I, M in ipairs(Party) do
		Ambushes[M] = A
		if M.Character then M.Character:PivotTo(Arena.CFrame * CFrame.new((I - 1) * 4 - 6, 4, 0)) end
		UIService.Notify(M, "Toast", {Text = "Ambush on the road!"})
	end
	local EnemyService = require(ServerScriptService.EnemyService)
	local Kind = MaxWanted >= 1 and "Elite" or "Grunt"
	for I = 1, 2 + (#Party > 2 and 1 or 0) do
		local Rig = EnemyService.Spawn(Kind, Arena.CFrame * CFrame.new((I - 2) * 8, 4, -20)) -- same spawn call as Task 7
		if Rig then
			table.insert(A.Enemies, Rig)
			local H = Rig:FindFirstChildOfClass("Humanoid")
			if H then H.Died:Connect(function()
				for _, E in ipairs(A.Enemies) do local EH = E:FindFirstChildOfClass("Humanoid") if EH and EH.Health > 0 then return end end
				task.wait(2)
				Continue(A)
			end) end
		end
	end
	-- fleeing: leaving the arena's radius also continues the journey
	task.spawn(function()
		while Ambushes[Leader] == A do
			task.wait(1)
			local Root = Leader.Character and Leader.Character:FindFirstChild("HumanoidRootPart")
			if Root and (Root.Position - Arena.Position).Magnitude > Arena.Size.X / 2 + 10 then Continue(A) end
		end
	end)
	return "ambush"
end

function RoadService.Start()
	for _, Exit in ipairs(CollectionService:GetTagged("RenseiRoadExit")) do
		local Prompt = Instance.new("ProximityPrompt")
		local RouteId = Exit:GetAttribute("Route")
		local Dest = Travel.Other(RouteId, TravelService.Here())
		local Places = require(ReplicatedStorage.Modules.Data.Rensei.Places)
		Prompt.ActionText = "Travel the road"
		Prompt.ObjectText = "To " .. (Places.Regions[Dest] and Places.Regions[Dest].Name or tostring(Dest))
		Prompt.HoldDuration, Prompt.MaxActivationDistance = 1, 12
		Prompt.Parent = Exit
		Prompt.Triggered:Connect(function(P)
			if Ambushes[P] then return end
			local Party = PartyService.Get(P)
			if Party and Party.Leader ~= P then
				UIService.Notify(P, "Toast", {Text = "Your party leader decides when to set off."})
				return
			end
			local Ok, Why = Travel.CanTake((require(ServerScriptService.ProgressionService).GetData(P) or {}).Level or 1, RouteId)
			if not Ok then UIService.Notify(P, "Toast", {Text = Why}) return end
			RoadService.Journey(P, RouteId)
		end)
	end
	Players.PlayerRemoving:Connect(function(P) Ambushes[P] = nil end)
end

return RoadService
```

- [ ] **Step 4: Add the exits and arenas.** Extend `station_lindenmoor.lua`:
  - a `RenseiRoadExit` part (6 × 8 × 2, invisible) under a stone gate arch on the north road at local (0, 8, 340), with attributes `Route = "RoadLindenmoorFoundry"` and `Arrive = "SouthGate"`;
  - an `AmbushArena` (a 60 × 1 × 60 invisible marker part) at local (−80, 6, 300), a flat clearing by the north road.

  Extend `station_foundry.lua` the same way:
  - the exit is at the south gate, with `Arrive = "NorthGate"`;
  - an arena at (100, 5, 150);
  - a `RenseiArrival` with `Point = "NorthGate"` in Ye already exists (Task 5 Step 7).

  Start RoadService in `ServerHandler`, after RideEvents. Add a travel-card confirm to TravelClient: when the prompt triggers, show the destination and the trip time first, with a "Set off" button that sends `Travel:InvokeServer("Road", {Route})`. Add `Op == "Road"` to StationService's remote handler; it calls `RoadService.Journey(Player, Args.Route)` after the same leader and level checks.

- [ ] **Step 5: Run `Play_Road`** (expected PASS 2), then restore the profile and Stop.

- [ ] **Step 6: Commit.**

---

### Task 9: The papers check (Wanted) and the stowaway route

**Files:**
- Modify: `StationService` (a gate: the papers check before the platform; boarding without a ticket through the `StowZone`)
- Modify: `station_lindenmoor.lua` / `station_foundry.lua`: a `RenseiStationGate` turnstile part between the ticket hall and the platform, a guard NPC, and a freight-yard path to the baggage car's open side door
- Test: `ServerStorage.RenseiTests.Play_Gate`

**Interfaces:**
- **Consumes:**
  - `HeatService.Wanted(Player, "State") -> integer`;
  - `HeatService.Add(Player, "State", Amount, Region)`;
  - `Travel.Gate`, `Travel.Bribe`;
  - `ProgressionService.SpendMoney`;
  - `RideEvents` (an Inspection fines stowaways).
- **Produces:**
  - `StationService.Gate(Player) -> "Pass" | "Bribe" | "Refuse"`;
  - `StationService.PayBribe(Player, RouteId) -> boolean`;
  - stowaways count as aboard without a ticket (`Aboard` includes players inside the baggage car's `StowZone`; `Has[P] = false`).
  - **Ruling:** the spec's "the guard calls an arrest" has no arrest system to call yet (`HeatService` has fines and Heat only). For now, Wanted 3+ means refused, +10 State Heat ("resisting a checkpoint"), and the guard's line. A real arrest comes with the law-enforcement plan. Cost if wrong: one function to swap in later.

- [ ] **Step 1: Write the failing test** (`Play_Gate`):

```lua
local SSS = game.ServerScriptService
return {
	GateFollowsWanted = function(T)
		local SS, HS = require(SSS.StationService), require(SSS.HeatService)
		local P = game.Players:GetPlayers()[1]
		HS.Clear(P, "State")
		T.Eq(SS.Gate(P), "Pass")
		HS.Add(P, "State", 25, "Lindenmoor") -- Wanted 1 (threshold 20)
		T.Eq(SS.Gate(P), "Bribe")
		HS.Add(P, "State", 100, "Lindenmoor") -- 125: Wanted 3 (threshold 100)
		T.Eq(SS.Gate(P), "Refuse")
		HS.Clear(P, "State")
	end,
	StowawayIsAboardWithoutATicket = function(T)
		local SS = require(SSS.StationService)
		local P = game.Players:GetPlayers()[1]
		local Zone
		for _, d in ipairs(workspace:GetDescendants()) do
			if d.Name:find("StowZone") and d:FindFirstAncestor("PlatformTrain") then Zone = d break end
		end
		P.Character:PivotTo(Zone.CFrame)
		task.wait(0.5)
		local Aboard, Stow = SS.Aboard("LindenmoorFoundry")
		T.True(table.find(Aboard, P) ~= nil and Stow[P] == true, "aboard as a stowaway")
	end,
}
```

- [ ] **Step 2: Run it to see it fail.**

- [ ] **Step 3: Change StationService.**
  - **Add:**

```lua
local function StateWanted(P)
	local Ok, W = pcall(function() return require(ServerScriptService.HeatService).Wanted(P, "State") end)
	return Ok and W or 0
end

function StationService.Gate(Player)
	return Travel.Gate(StateWanted(Player))
end

function StationService.PayBribe(Player, RouteId)
	local Cost = Travel.Bribe(RouteId, "Third", StationService.Season())
	if not ProgressionService.SpendMoney(Player, Cost) then return false end
	Player:SetAttribute("GateCleared", os.time())
	return true
end

local function InStowZone(P)
	local Root = P.Character and P.Character:FindFirstChild("HumanoidRootPart")
	if not Root then return false end
	for _, Z in ipairs(workspace:GetDescendants()) do
		if Z:IsA("BasePart") and Z.Name:find("StowZone") and Z:FindFirstAncestor("PlatformTrain") then
			local L = Z.CFrame:PointToObjectSpace(Root.Position)
			if math.abs(L.X) <= Z.Size.X / 2 and math.abs(L.Y) <= Z.Size.Y / 2 + 2 and math.abs(L.Z) <= Z.Size.Z / 2 then return true end
		end
	end
	return false
end
```

  - **Replace `Aboard`** so it returns the list plus a stowaway set:

```lua
function StationService.Aboard(RouteId)
	local Train = TrainOf("RenseiPlatformTrain", RouteId)
	local Out, Stow = {}, {}
	if not Train then return Out, Stow end
	for _, P in ipairs(Players:GetPlayers()) do
		local Root = P.Character and P.Character:FindFirstChild("HumanoidRootPart")
		if Root and not Riding[P] then
			if InStowZone(P) and not TravelService.HasTicket(P, RouteId) then
				table.insert(Out, P) Stow[P] = true
			elseif TravelService.HasTicket(P, RouteId) and Inside(Train, Root.Position) then
				table.insert(Out, P)
			end
		end
	end
	return Out, Stow
end
```

  - **Turnstile:** in `Start()`, wire the `RenseiStationGate` part. Its `Touched` handler checks `Gate(P)`:
    - `"Pass"`: nothing.
    - `"Bribe"`, when the `GateCleared` attribute is older than 10 minutes: push the player back and fire `TravelEvent "GateBribe" {Route, Cost}`. TravelClient shows two buttons:
      - "Pay $X" calls `Travel:InvokeServer("Bribe", {Route})`;
      - "Get searched" calls `Travel:InvokeServer("Search")`, which removes contraband (there's no contraband yet, so it only sets `GateCleared`) and lets them through.
    - `"Refuse"`: push them back, call `HeatService.Add(P, "State", 10, TravelService.Here())`, and toast `Guard: "Your face is on a poster. Not on my platform."`

    Add `Op == "Bribe"` and `Op == "Search"` to the remote handler.
  - **Departures:** in `Depart`, change `local List = StationService.Aboard(RouteId)` to `local List, Stow = StationService.Aboard(RouteId)`. Pass `Stow` along with `Departing:Fire(RouteId, List, RideSeconds, Stow)`. RideEvents then sets `Has[P] = not Stow[P]` instead of reading tickets.
  - **Stowaway arrival:** `TravelService.Arrive` already only uses a ticket when there is one, so a stowaway arrives with nothing to use up.

- [ ] **Step 4: Build the turnstile and freight path.** Extend the station scripts:
  - a `StationGate` (tag `RenseiStationGate`): an 8 × 8 × 1 invisible part across the hall-to-platform opening, beside a guard NPC (an R6 rig in State blue, anchored, playing the idle from `NpcIdles`);
  - the freight yard: crates and a fence along the far side of the tracks, with one gap leading to the baggage car's open door.

  Re-run them in both places.

- [ ] **Step 5: Run `Play_Gate`** (expected PASS 2) plus all the earlier Play suites, then restore the profile and Stop.

- [ ] **Step 6: Commit.**

---

### Task 10: Rumours, regions, quests and parties across places

**Files:**
- Modify: `ReplicatedStorage.Modules.Data.Rensei.Regions` (new regions, links, a `Rail` carrier, the default region per place)
- Modify: `ServerStorage.RenseiTests.Test_Regions` (its expectations change)
- Modify: `ServerStorage.RenseiServer.QuestService` (an `Arrive` signal)
- Modify: `TravelService.Arrive` (signal the quest)
- Test: `Test_Regions`, `Test_Travel` (unchanged), and a new `Play_Arrive`

**Interfaces:**
- **Consumes:** `TravelService.Arrived`, `QuestService.Signal(Player, Kind, Target, Amount)`.
- **Produces:**
  - `Regions.Regions.{Aerugo, Ishval, North, Corrupted}`;
  - `Regions.Carriers.Rail` (reaches every faction);
  - `Regions.Default = Places.RegionOf(game.PlaceId) or "City"`;
  - quest objectives `{Kind = "Arrive", Target = RegionId}`.

- [ ] **Step 1: Update `Test_Regions` first.**
  - `AreasMapToRegions`: `OfArea(nil)` now returns the place's own region. In Ye that's `"Lindenmoor"`, so change `T.Eq(Regions.OfArea(nil), "City")` to `T.Eq(Regions.OfArea(nil), require(game.ReplicatedStorage.Modules.Data.Rensei.Places).RegionOf(game.PlaceId) or "City")`, and do the same for `"Somewhere New"`.
  - **Add:**

```lua
	NewRegionsAndRail = function(T)
		for _, Id in ipairs({"Aerugo", "Ishval", "North", "Corrupted"}) do T.True(Regions.Regions[Id] ~= nil, Id) end
		T.True(Regions.Carriers.Rail ~= nil and Regions.Carriers.Rail.Reaches == nil, "rail reaches everyone")
		local Rail = false
		for _, L in ipairs(Regions.Regions.Lindenmoor.Links) do if L.To == "Foundry" and L.Carrier == "Rail" then Rail = true end end
		T.True(Rail, "Lindenmoor -> Foundry by rail")
	end,
```

  - `PresenceAndCounts`: the community count becomes 9 (5 regions plus 4 new). Change `T.Eq(Regions.Count("IshvalanCommunity"), 5)` to `9`.

- [ ] **Step 2: Run them to see them fail.**

- [ ] **Step 3: Update `Regions`** (rewrite the module; keep every function the same). Add to `Regions.Carriers`:

```lua
	Rail = {Name = "the railway"}, -- World plan 1: word rides the timetable; reaches everyone present
```

Add to the `Lindenmoor`, `Foundry` and `City` link lists, and add the new regions:

```lua
-- Lindenmoor.Links (add)
	{To = "Foundry", Carrier = "Rail", Minutes = 3},
-- Foundry.Links (add)
	{To = "Lindenmoor", Carrier = "Rail", Minutes = 3}, {To = "City", Carrier = "Rail", Minutes = 3},
-- City.Links (add)
	{To = "Foundry", Carrier = "Rail", Minutes = 3}, {To = "Ishval", Carrier = "Rail", Minutes = 4},
	{To = "Aerugo", Carrier = "Gossip", Minutes = 25}, {To = "Aerugo", Carrier = "Dispatch", Minutes = 6},
	{To = "Ishval", Carrier = "Gossip", Minutes = 40}, {To = "Ishval", Carrier = "Whisper", Minutes = 8},
	{To = "North", Carrier = "Gossip", Minutes = 30}, {To = "North", Carrier = "Dispatch", Minutes = 6},
	{To = "Corrupted", Carrier = "Whisper", Minutes = 5},
-- new regions (PROPOSAL factions / jurisdictions)
	Aerugo = {Name = "the Aerugo Borderlands", Factions = {"Authority", "Townsfolk"}, Jurisdiction = "State", Safe = false,
		Links = {{To = "City", Carrier = "Gossip", Minutes = 25}, {To = "City", Carrier = "Dispatch", Minutes = 6}, {To = "Corrupted", Carrier = "Gossip", Minutes = 45}}},
	Ishval = {Name = "Ishval", Factions = {"Townsfolk"}, Jurisdiction = "None", Safe = false,
		Links = {{To = "City", Carrier = "Gossip", Minutes = 40}, {To = "City", Carrier = "Rail", Minutes = 4}}},
	North = {Name = "the Northern Wall", Factions = {"Authority"}, Jurisdiction = "State", Safe = false,
		Links = {{To = "City", Carrier = "Gossip", Minutes = 30}, {To = "City", Carrier = "Dispatch", Minutes = 6}, {To = "Corrupted", Carrier = "Gossip", Minutes = 45}}},
	Corrupted = {Name = "the Corrupted Lands", Factions = {"Circle"}, Hidden = {Circle = true}, Jurisdiction = "None", Safe = false,
		Links = {{To = "City", Carrier = "Whisper", Minutes = 5}, {To = "North", Carrier = "Gossip", Minutes = 45}, {To = "Aerugo", Carrier = "Gossip", Minutes = 45}}},
```

Then change the default:

```lua
Regions.Default = require(script.Parent.Places).RegionOf(game.PlaceId) or "City" -- outside every area volume = this place's region
```

The other `Test_Regions` assertions must still hold:
- `Count("Circle")` now includes Corrupted, so it's 3. **Check this** and update the expected value to match, noting the reason in the test.
- `Reach("Foundry", "Dispatch")` is still `{}`.

- [ ] **Step 4: Run `Test_Regions`, `Test_Heat` and `Test_RumourCore`** (Edit mode). All must pass. Where an existing Heat or rumour test counted regions, update its expected numbers, and write each changed number with its reason in the task report.

- [ ] **Step 5: Quest arrival signal.** In `TravelService.Arrive`, after `T.Region = Here`, add:

```lua
	pcall(function() require(ServerScriptService.QuestService).Signal(Player, "Arrive", Here, 1) end)
```

Check that `QuestService.Signal` matches objectives generically (Kind and Target). Read its body with `script_read`. If it only handles listed kinds, add `"Arrive"` to that list. Then write `Play_Arrive`:

```lua
return {
	ArriveSignalsQuests = function(T)
		local QS = require(game.ServerScriptService.QuestService)
		local Seen
		local Old = QS.Signal
		QS.Signal = function(P, Kind, Target, N) if Kind == "Arrive" then Seen = Target end return Old(P, Kind, Target, N) end
		require(game.ServerScriptService.TravelService).Arrive(game.Players:GetPlayers()[1], {Route = "RoadLindenmoorFoundry", Arrive = "Platform"})
		QS.Signal = Old
		T.Eq(Seen, require(game.ServerScriptService.TravelService).Here())
	end,
}
```

- [ ] **Step 6: Parties.** Party ticket purchase is already in `StationService.Buy` (`For`). Add a "Buy for" row to the ticket window: one button per party member, using the party roster TravelClient already gets from `UIService` ("Party"). Roads already take the whole party. The train keeps a party together because a whole party at the platform departs on the same call.

- [ ] **Step 7: Run every suite.**
  - **Edit mode:** `Test_Travel`, `Test_Regions`, `Test_Heat`, `Test_RumourCore`, `Test_Reputation`, `Test_Perception`, `Test_Witness`, `Test_Sound`, `Test_Schema5`, `Test_TestKit`.
  - **Play:** `Play_Boot`, `Play_Travel`, `Play_Station`, `Play_RideEvents`, `Play_Road`, `Play_Gate`, `Play_Arrive`, plus the existing `Play_*` suites.
  - Everything must pass. Restore the profile and Stop.

- [ ] **Step 8: Commit.**

---

### Task 11: Foundry end-to-end in Studio, docs, changelog, status page

**Files:**
- Modify: `Documents/Changelog.md`, `Documents/Lindenmoor Kit.md` (tooling note); create `Documents/World Travel.md`
- The status page artifact

- [ ] **Step 1: Foundry check.**
  - Open the Foundry place. Make sure its packages are up to date (Studio prompts for an update; accept it, or run `Packages > Update All` if offered).
  - Re-run `station_foundry.lua` (train, clerk, gate, exits, arena).
  - Then in Play there: run `Play_Boot`, `Play_Travel`, `Play_Station` and `Play_Road` (copy the test suites into its ServerStorage first). All pass.
  - Restore the profile and Stop.

- [ ] **Step 2: Screenshots.** Use `screen_capture` for:
  - the Lindenmoor platform with the train;
  - the 3rd-class interior;
  - the dining car;
  - the ticket window;
  - the Foundry platform.

  Save them to `Documents/images/World Travel/`.

- [ ] **Step 3: Write `Documents/World Travel.md`.** What a player sees, how stations work, ticket prices (PROPOSAL), the papers check and the stowaway route, roads and ambushes, how the group teleport and the save handover work, the Studio loopback, where everything lives (the `RenseiServer` package, the services), and the owner's next steps:
  1. **Publish**, so the real cross-place train can be tested on a live server. We don't publish.
  2. **Ride Lindenmoor to the Foundry** with 2+ players and check that everyone lands on one server.
  3. **Check a rejoin:** it should return you to the Foundry.

- [ ] **Step 4: Changelog entry** (newest first): the owner's words, what was built, the tests, and the rulings. That covers the arrest stand-in, any EnemyService spawn-name adaptation, and any count changes in the region tests.

- [ ] **Step 5: Commit** (by path; never `Art/Blender.rar`), then `git pull --rebase` and `git push`.

- [ ] **Step 6: Republish the status page.** Add a row for "World travel: train, stations, roads" in the World section, and next steps for the owner: publish to test live, then ride with 2+ players.

---

## Self-review notes (filled in while writing)

- **Spec coverage:**
  - §1 world structure: Tasks 1, 3, 4 and 10. Lindenmoor's growth and moving the trial rooms are later plans, spec build steps 4–5.
  - §2 train: Tasks 2, 5, 6 and 7. The model is "The train model".
  - §3 roads: Task 8.
  - §4 tie-ins: Tasks 6, 7, 9 and 10 (money, Heat and Wanted, the stowaway, rumours, quests, parties).
  - §5 seasons: a separate plan. `StationService.Season` and `RoadService.Season` are stubs that return "Summer", replaced by the seasons plan.
  - §6 Packages: Tasks 3 and 4.
- **Deviation from the spec:** the arrest at the gate becomes a refusal plus State Heat until an arrest system exists (Task 9 ruling).
- **Type consistency:**
  - Route ids (`LindenmoorFoundry`, `RoadLindenmoorFoundry`), class ids (`Third`, `Second`, `Cabin`) and car kinds (`ThirdClass`, `DiningCar`, `SecondClass`, `CabinCar`, `BaggageCar`) are used the same way in every task.
  - The region id for Central is `City` everywhere.
  - `Aboard` returns `(List, Stow)` from Task 9 on; Task 6's single-value callers (`Depart`) are updated in Task 9 Step 3.

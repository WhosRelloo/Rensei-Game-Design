# Region builds: design

**Status:** design approved section by section by the owner on 2026-10-23. This file is waiting for the owner's read-through before planning.

**Owner's request:** "Here's a PDF of all of the region layouts, I want all of them built in blender once all tasks are complete." The brief is `Documents/Rensei-Regional-Map-Design-Brief.pdf`.

**Owner's choices (2026-10-23):**
- **First region:** Foundry Yard.
- **Scope:** "Map + living world". That means the playable map, townsfolk with routines, a quest for each clue, and the region's trainer and trial rooms moved in.
- **Approach:** "a region layout file plus a shared Blender builder".
- **Surfaces:** Roblox built-in materials tinted to each region's palette, as Lindenmoor does today.
  - **Update (owner, 2026-10-23):** "I threw a texture pack into the foundry yard, use the assets as applicable". The pack is `Workspace."Texture pack (realistic)"` in Foundry Yard: 241 sample blocks (ceilings, floors, glass, roofs, terrain, walls and 168 numbered textures). Each block shows one image on six `Texture` faces. The catalog is in `Art/Regions/texture_pack.json`.
  - **How it's used:** wherever a pack image fits a region palette key, it becomes a **MaterialVariant** (`ColorMap` = the pack image, with its studs-per-tile) on the mapped built-in material, and parts reference it by name. That adds no objects per part. Keys with no fitting image stay tinted built-ins.
  - **Tested on 2026-10-23:** a MaterialVariant made from Ceiling C's image matched the original block.
  - Blender renders can't load the Roblox images, so they show the palette colours. The Studio screenshots after import show the textures.
- **Townsfolk:** "Routines + reactions". They have jobs and day schedules, hide from fights, act as witnesses, pass on rumours and greet you by your standing. About 20–40 per region.
- **Day cycle:** "Add a day cycle". A world clock drives lighting, schedules, lamps and the night ambush odds.

Every number in this file is a **PROPOSAL** unless it is quoted from the brief or the owner.

## 1. How this fits the world spec

`2026-10-20-world-travel-seasons-design.md` stays the binding world spec. The brief changes four things in it:

| World spec said | Now (the brief) |
|---|---|
| Each region about 3,000 × 3,000 studs | The brief's footprints: Lindenmoor 2,048², Central City 2,560², Foundry Yard 1,536², Ishval 2,048², Aerugo 2,560 × 2,048, Northern Wall 1,536 × 2,048, Corrupted Lands 3,072 × 2,560. |
| "Lindenmoor grows to about 3,000 studs" | Lindenmoor fills its 2,048 × 2,048 × 16-stud baseplate. The finished village keeps its current coordinates. |
| The Region Layouts plates (concept) | The brief's layout schematics. Both are "not final Studio coordinates". |
| 60–90k parts per region | A budget per region, scaled to its footprint and density (§3.6). |

Unchanged from the world spec:
- one experience with one save;
- natural edges, never invisible walls; edge cliffs and walls carry `RenseiNoGrip`, so the climb and the wall-run can't grab them (owner, 2026-10-24: "Ungrippable edges");
- `StreamingEnabled` in every place;
- the Lindenmoor pipeline reused for every region;
- trial rooms move to their regions, and their trainer questlines are re-pointed.

## 2. The work, split into pieces

Each piece below gets its own plan, built and reviewed task by task (the same process as World Plan 1). This file designs the foundation and Foundry Yard in full. Each later region gets a short spec of its own, built on the same foundation.

1. **Foundation**
   - **F1:** the shared region builder (Blender), the place import and the place setup.
   - **F2:** the world clock.
   - **F3:** the townsfolk service.
   - **F4:** the clue-quest template, plus a fix for the trainer exams ("Pass [Trainer]'s examination"; Backlog).
2. **Region 1: Foundry Yard.** The map, about 25 townsfolk, the shift-ledger quest, and Brannoc with his Silent Forge and Forge Floor moved in from Ye.
3. **Later regions, one at a time:** Lindenmoor's expansion, Central City, Ishval, Aerugo Borderlands, Northern Wall, Corrupted Lands. This order is a PROPOSAL; the owner can change it before each one starts.

## 3. F1: the shared region builder

### 3.1 The region file
There is one file per region, `Art/Regions/<Region>/layout.json`. It is written from the brief's schematic and translated into studs.

**Orientation (ruling):** the brief's drawings put north at the bottom. Central City's South Gate is at the top and its North Gate at the bottom, while west stays on the left. So the drawing's right is east (+X) and the drawing's top is south (+Z). This matches today's Foundry place, whose road to Lindenmoor leaves south at +Z.

The file holds:

| Key | What it is |
|---|---|
| `Region`, `PlaceId`, `Footprint` | Ids and size in studs. The place's origin is the footprint's centre. |
| `Palette` | Named colours from the brief, mapped to Roblox built-in materials. |
| `Heights` | Broad height shapes: raised districts, cuts, ridges, basins and water. These become the stepped part ground. |
| `Districts` | Polygon, building `Style`, `Density` and `Height` range. |
| `Routes` | Polylines, each with `Kind`: public, quiet, rail, under, ledge or road, and a width. |
| `Landmarks` | Named set pieces with a kind and a position. |
| `Markers` | Point and box markers, each with a `Tag` and attributes (see §3.4). |
| `Budget` | The part ceiling for the region (§3.6). |

### 3.2 The builder
The builder lives in `Art/Blender/region_builder/` (not `regions/`: on Windows that would be the same folder as the `Art/Blender/Regions/` output folder, and Python could not import it). It is generalized from `Art/Blender/lindenmoor/` (`core.py`, `world.py`, `build.py`), and the Lindenmoor scripts stay working. Run it as `region_builder.build.run("<Region>", stages)`. Its stages:

- **ground:** builds a heightfield from `Heights`, then stepped slabs in the approved style. Slabs are 4-stud cells near routes and towns, and 8–16-stud cells elsewhere. Climbing routes get dirt ramps, and the slabs merge into large parts. Water stays as Roblox terrain water, because SwimService reads it.
- **routes:** paving, alleys, rail walks, under-routes and their tunnels, ramps and stairs. Every public and quiet route must be continuous and walkable.
- **buildings:** placed from the style kits (§3.3) inside each district, facing its routes, with gaps for alleys and service doors.
- **landmarks:** each landmark kind is a function, for example `crane_bay`, `foundry_hall` or `practice_court`.
- **cover and traversal:** crates, walls, roofs, ledges, wall-run faces and climbable frames. Each is tagged as the movement systems already expect.
- **edges:** ridges, cliffs, slag banks or walls, depending on the region. Gaps are left only where a road passage or the station leads out.
- **markers:** marker parts, invisible and non-colliding, with their tag and attributes.
- **renders:** an aerial view, plus a street-level shot per district and landmark, saved to `Documents/images/Regions/<Region>/`.

The result is saved as `Art/Blender/Regions/<Region>.blend`.

### 3.3 Style kits
Each kit is a set of building and prop generators with parameters: storeys, roof type, window rhythm and trim. They use the region's palette.

- **Rail town (Foundry):** furnace brick, soot, iron trim, smokestacks, warm windows.
- Later regions add civic stone, sandstone and clay, white hill stone, cold stone and timber, and ruin and ash kits.

The Lindenmoor farmhouse kit stays as it is.

### 3.4 Markers and tags
Markers carry the World Plan 1 tags already in use, plus new ones:

- **World Plan 1:** `RenseiArrival`, `RenseiPlatformTrain`, `RenseiTicketClerk`, `RenseiDepartureBoard`, `RenseiStationGate`, `RenseiFreightYard`, `RenseiWatcher` (spawn spot), `RenseiRoadPassage`, `RenseiRoadThreshold`, `RenseiRoadEncounter`.
- **Places:** `RenseiArea` (areas with `AreaName`).
- **Movement:** `RenseiLedge` and the other movement tags.
- **Enemies:** `RenseiEnemySpawn`.
- **New:**
  - `RenseiPost`: a townsfolk post, with attributes `PostId`, `Kind` (Work / Seat / Counter / Home / Shelter) and `Facing`.
  - `RenseiClue`: a clue point, with `ClueId`.
  - `RenseiTrial`: a trial room entrance, with `TrialId` (the tag TrialService reads).

### 3.5 Export, import and setup in Studio
- **Export:** reused. `export.py` writes `layout.json`, and `studio_kit.py` writes the chunked Lua and the expected counts. It is generalized to take a region name.
- **Import:**
  - `Art/Studio/Regions/import.lua` builds `ServerStorage.RegionStaging`.
  - `finish.lua` then checks the counts, backs up the place's current `World.Map` into `RenseiBackups["Pre-Region_<date>"]`, swaps the map in, and refuses to run twice.
  - The tool is `rbxc.py`, with the region's place id.
- **Setup:** `Art/Studio/Regions/setup.lua` replaces the hand-placed station and road scripts for a rebuilt region. It reads the markers and builds the working pieces with the same tags, attributes and services World Plan 1 uses:
  - the platform, train spawn, clerk booth and departure board;
  - the gate, guard and railing;
  - the freight yard, its watchman and the stowaway path;
  - the road passage, threshold and encounters;
  - the arrivals.

  `station_foundry.lua` stays in the repo for history but is no longer run.
- **No change to server code for the map:** the services find everything by tag, as they do today.

### 3.6 Part budget
- **Foundry Yard:** a ceiling of about **45,000 parts**. It is a dense town on 56 % of Lindenmoor's area. For comparison, Lindenmoor's village plus its ground is about 24,600 parts.
- **Each later region:** its spec sets its own ceiling, never above the world spec's 90,000.
- **Enforcement:** the builder refuses to export over budget, and the import checks the count again.

## 4. F2: the world clock

- **Service:** `WorldClock` in `RenseiServer`.
- **The time of day comes from the real time,** so every place and server shows the same hour: `ClockTime = ((os.time() / 60) % 24)`. That gives a **24-minute day** (PROPOSAL), one game hour per real minute. The service sets `Lighting.ClockTime` once a second.
- **Who reads it:**
  - LightService, Perception's daylight check and stealth already read `Lighting.ClockTime`, so night now makes stealth easier with no change to them;
  - street lamps (`RenseiLight`) light from 18:00 to 06:00;
  - RoadService's night ambush bonus already reads `Lighting.ClockTime` (night is before 06:00 or after 19:00), so it starts working with no change;
  - townsfolk schedules (§5).
- **Admin and tests:**
  - `WorldClock.Hold(Hour)` freezes the clock at an hour, and `WorldClock.Release()` lets it run again;
  - the admin panel's time setting calls `Hold`;
  - tests that set `ClockTime` (for example Play_Stealth) call `Hold` and `Release`.
- **Seasons:** the seasons plan can build on this clock later. Seasons are out of scope here.

## 5. F3: the townsfolk service

- **Service:** `TownsfolkService` in `RenseiServer`.
- **Data:** `Rensei.Townsfolk` in the `Modules` package, keyed by region. Each townsperson has:
  - `Id`, `Name` and `Job`;
  - `Look`: a nation outfit, gender and hair, through `AppearanceService`;
  - `Faction`, which the greeting uses;
  - `Schedule`: a list of `{From, To, Post}` in game hours, for example `{6, 14, "crane_bay_2"}, {14, 15, "canteen_seat_4"}, {15, 22, "workers_row_3"}, {22, 6, "workers_row_3"}`.
- **Spawning:** each townsperson spawns at their current post when the place starts. They live in `workspace.World.Live.Townsfolk` and are tagged `RenseiWatcher` (with `Combat = false`) and `RenseiTownsfolk`.
- **Movement:**
  - When a townsperson's schedule moves them to a new post, the service computes one path with `PathfindingService` and walks it at WalkSpeed 8.
  - At the post they turn to its `Facing` and play the job's idle from the existing idle set.
  - A townsperson with no player within 300 studs doesn't move. When a player comes near, they are placed where their schedule says.
  - One update loop runs at 1 Hz for everyone.
- **Reactions:**
  - **Fights:** `PerceptionService.Hear` gives combat noise. On it, a townsperson walks or runs to the nearest `Shelter` post and cowers there, then returns 20 s after the last noise.
  - **Crimes:** they are watchers, so the existing witness, Heat and rumour paths handle what they see.
  - **Townsfolk can be hurt** (owner, 2026-10-23: "The townsfolk should be hittable and integrate the heat, rep system, morality, etc."; answer: "Knocked, can be finished"). This settles the open Plan 2 question.
    - **Taking hits:** they take hits like enemies do, through the same combat code. Each hit is assault: the existing `assault_townsfolk` deed, at most once per townsperson every 30 s, witnessed, with Heat and Townsfolk standing.
    - **Reactions:** a townsperson who is hit shouts and flees away from the attacker, and townsfolk nearby flee too.
    - **Knocked:** at 0 health they go down, knocked as enemies are. Left alone, they get up after about 30 s and flee. Gripped and executed, they die.
    - **Death is murder:** a new deed, `murder_townsfolk`. It is a big Heat and standing loss, witnessed and spread by rumour, like any deed. Killing townsfolk gives no EXP, money or drops.
    - **Replacement:** the dead townsperson's job is taken by a newcomer (a new name from their nation, the same posts) at the next 06:00 game time.
- **Talking: speech above their heads** (owner, 2026-10-23: "Make the townsfolk chat appear above their head with a custom font"; answers: font **Special Elite**, **bubbles only, no reply choices**).
  - **No dialogue box.** A "Talk" prompt makes the townsperson say one line in a speech bubble above their head. Talking again gives the next line. The rotation:
    - a **greeting**, by the player's standing tier with the townsperson's faction in this region (`MoralityService`);
    - a **rumour**, one of the latest that reached this region (a new read-only call, `RumourService.HeardIn(Region, N)`), skipped when there is none;
    - the townsperson's **job line**.
  - **Clues:** when the player is on a clue quest at the stage that townsperson matters to, the clue line comes first and advances the quest (§6).
  - **Ambient chatter:** short lines overhead when a player first passes close by (at most once per player every 5 minutes, PROPOSAL), at shift change, when fleeing a fight and when coming back.
  - **The bubble:**
    - a BillboardGui over the head, with its background from the game's existing dialogue art (owner UI rule) and the text in the **Special Elite** font;
    - it fades in and out (UIMotion) and stays for about 3 s plus 0.05 s per character (PROPOSAL);
    - everyone nearby can see it.
- **Cost check:** with 25 townsfolk, the update loop must stay under 1 ms average server time (§9).

## 6. F4: clue quests and trainer exams

- **Clue quests:**
  - A `RenseiClue` marker becomes an inspect point on the existing `InvestigationService`.
  - Inspecting it starts the region's clue quest in `Rensei.Quests`. The quest uses the existing stage, objective, Evidence, Deduce and Signal kinds, and can involve townsfolk through their dialogue.
  - The clue's data lives with the region's townsfolk data.
- **Trainer exams:** the Backlog says the alchemy trainers' exams don't work. F4 finds the cause, fixes it for every trainer that shares it, and adds a Play test for each exam.

## 7. Region 1: Foundry Yard

### 7.1 The map (1,536 × 1,536)
From the brief's schematic, with the orientation from §3.1:

| Area | Contents |
|---|---|
| South-west | **The station:** platform and rails, the ticket hall with the clerk booth outside the gate, the departure board, and the gate with its guard and railing. Two lines leave east: the Lindenmoor line and the Central line. |
| Along the tracks | **The raised service walk:** stacked rail walks above the tracks. They are loud metal (noise) and give a high route with vertical reads. |
| South-east | **The freight yard and sidings:** crates and machinery, the freight-side path to the baggage car's stowaway door, and the yard watchman. |
| Along the south edge | **The quiet under-route and the underworks:** a tunnel loop from near the station to the practice court. It is dark, for stealth and flanking. |
| Middle | **The practice court:** Brannoc's trainer yard. The **shift ledger** clue stands just east of it. |
| North-west | **Workers' row and the boarding house:** townsfolk homes, alleys and back yards. |
| North | **The public square, market and canteen.** |
| North-east | **The foundry hall and crane bay:** the landmark. A huge brick hall with smokestacks, furnace glow, crane frames and gantries to climb, and the **Silent Forge** and **Forge Floor** trial rooms inside. |
| Edges | Slag ridges and brick walls. The south gap holds the existing **south road passage** to Lindenmoor (World Plan 1, Task 8b), rebuilt into the new layout. A **north viaduct road mouth** toward Central City is built but stays closed until Central exists. |

- **Palette:** soot, iron, furnace brick and ember accents, from the brief.
- **Ground:** mostly flat, made of yard slabs and cinder. Raised walks, a sunken underworks and the slag ridges give the height.

### 7.2 Moving Brannoc and the forge rooms
- **Out of Ye:** Brannoc (the Metal trainer), the `SilentForge` and `ForgeFloor` models with their trial markers, their alchemist spawn, and Ye's small `FoundryYard` model. All of them go to `RenseiBackups["Pre-FoundryMove_<date>"]` in Ye.
- **Into Foundry:** rebuilt in the Foundry style, with the same evidence ids, minigame targets and trial flags. Brannoc stands in the practice court.
- **Quest change:** "The Unyielding Principle" (`acq_metal`) gets a first stage, "Travel to the Foundry Yard", which uses an `Arrive` objective. Its location text changes to match.
- **Area data:** `Regions` maps `Silent Forge` to the Foundry region, not Wilds.
- **Owner-visible effect:** the Metal path now needs a trip to the Foundry, by train or on foot. This was approved in the world spec, and the owner was told on 2026-10-23.

### 7.3 Living world
- **About 25 townsfolk** (PROPOSAL): crane and furnace crews on two shifts, canteen cooks, market traders, station porters, a ledger clerk, boarding-house keepers, children who run errands between posts, and two off-duty guards.
- **Shifts** change at 06:00, 14:00 and 22:00 game time. The canteen fills at shift change, and the market is open 08:00–20:00.
- **The shift-ledger quest** (PROPOSAL story): someone has been altering the Foundry's shift ledger. The steps:
  - read the ledger (the clue);
  - talk to two crew members and the clerk;
  - find an altered docket in the underworks;
  - deduce who did it on the Case Board.

  The reward is EXP and money, plus a standing change with the Foundry's people.

### 7.4 Travel after the rebuild
- Every World Plan 1 piece in Foundry is rebuilt from markers: the platform, train, clerk, board, gate, guard, railing, freight yard, watchman, road passage, threshold, encounters and arrivals.
- Every travel suite must pass in the new town: Boot, Travel, Station, Road, Gate, RideEvents and Arrive.

## 8. What's out of scope

- The other six regions' content (each gets its own spec).
- Seasons.
- Hittable townsfolk.
- Real textures (MaterialVariants).
- Townsfolk needs, relationships and trade.
- An arrest system.
- A working Foundry ↔ Central road passage (only the mouth is built).
- Publishing.

## 9. Testing and review

**In Blender, before Studio:**
- the owner approves the renders for each region;
- the builder checks that every route is continuous, every marker sits on walkable ground, and the part count is within budget.

**In Studio**, automated, with the owner's save snapshotted and restored as before:

| Area | What is checked |
|---|---|
| Walkability | Every public and quiet route is walked end to end with no stuck points. Pathfinding with jumps turned off reaches every townsfolk post. |
| Movement and stealth | Ledges, wall-runs and climbs are tagged and grabbable. The underworks and roofed areas give shade. |
| Travel | Every World Plan 1 suite passes in the rebuilt Foundry. |
| Clock | Time moves with real time, and Hold and Release work. At night, stealth exposure drops and lamps light. |
| Townsfolk | They reach every post on schedule. They hide when a fight starts and come back. A crime they witness reaches Heat and rumours. Talking gives the right greeting tier, rumours and job line. |
| Quests | The shift-ledger quest end to end. `acq_metal` from the Foundry start through Brannoc's exam. Every trainer's exam. |
| Performance | The part count, and the townsfolk loop's average server time with 25 townsfolk (under 1 ms). |

**Safety:**
- every import backs up the old map first and refuses to run twice;
- Ye loses only Brannoc, the forge rooms and the small Foundry model, all backed up;
- the owner publishes packages, and Claude checks that Foundry's copies match the repo;
- nothing is published.

**Process:**
- every task gets a review, a changelog entry and a push;
- the status page is updated after each piece.

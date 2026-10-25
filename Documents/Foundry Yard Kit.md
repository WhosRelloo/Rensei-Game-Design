# Foundry Yard Kit (Blender → Studio)

Foundry Yard's new map, built in Blender with the region builder (`Documents/Region Builder.md`) from the owner-approved layout (2026-10-24). The design is `Documents/specs/2026-10-23-region-builds-design.md` §7, and the brief's page is region 03 of `Documents/Rensei-Regional-Map-Design-Brief.pdf`. The new map replaced the hand-built Foundry map (World Plan 1) through the region import on 2026-10-24 (see "The import" below). It isn't live: the place has to be saved by the owner, and nothing is published.

Every number here is a **PROPOSAL** unless it is quoted from the brief or the owner.

## Owner decisions (2026-10-24)

- **Layout:** "Yes, build it". The layout proposal (districts, routes, landmarks, travel pieces, edges) was shown with a top-down sketch first.
- **North mouth toward Central City:** "Shut gatehouse, solid wall". The viaduct ends at a shut gatehouse. The edge wall behind it has no gap until Central City exists.
- **Forge rooms:** "Foundry-style shells". The great hall has two empty forge rooms. At import, the Silent Forge's and the Forge Floor's trial markers, minigame targets and alchemist spawn move in from Ye with the same ids.
- **Enemies:** "A few in the underworks". There are four Grunt spawns in the underworks tunnel and none in the town above.
- **The east (after the first renders):** "Fill the empty east first, and remember to place things for the movement and combat we currently have in game". See "Movement and combat" below.
- **Renders:** approved ("Approved", 2026-10-24) for a later Studio import.
- **The import:** "Keep the Foundry import as it is; I'll save the place in Studio." (owner, 2026-10-24, after the real swap). The owner saves the place.

## Frame

- Region coordinates are Roblox studs, and the origin is the footprint's centre. The footprint is 1,536 × 1,536 (from the brief).
- **In Foundry, +Z is south and +X is east.** This follows the region-builds spec's reading of the brief, whose drawings put north at the bottom. It also matches today's Foundry place, whose road to Lindenmoor leaves toward +Z. (Ye is the other way round: there, +Z is north.)
- The ground top is y 4, as today's Foundry ground is.
- The export origin is (0, 0, 0), so region coordinates are world coordinates.
- The renders are flipped left to right, so they show the place as Studio will.

## What's where

| Area | Where (x, z) | What |
|---|---|---|
| **Foundry Station** | south-west, x −768..−560 | The terminus: the track is at x −660, and the train's nose is at z +620 by the buffer stops. The platform (built by setup), its iron canopy (posts are skipped at the gate and the board), the booking hall with the ticket booth inside, the papers gate and the railing on the platform's back edge. The stowaway freight yard is on the far (−X) side of the track by the baggage car. |
| **The rail corridor** | z +42 (Lindenmoor line), z +66 (Central line) | Both lines leave east through a tunnel portal in the east wall: a dead end a few studs in. Six raised rail walks run between the tracks, with two signal gantries over them (24 up) as the high tier. A crane spur and two freight sidings branch off. |
| **Cinder Lane** | x −628..40, z +112..+395 | Terraced houses either side of Cinder Lane, between the freight path and Station Street. |
| **Lower Town, Practice Court** | z +444..+620 | Houses south of Station Street. In the middle are Brannoc's practice court at (−200, 480) and the shift office just east of it, with the shift-ledger clue at its lectern. |
| **The Underworks** | z +640..+712 | A brick tunnel loop (x −548..−160, z 676) runs through a slag embankment along the south edge. Its west mouth is near the station and its east mouth is by the court. It is dark, holds the altered docket and the four Grunt spawns, and has lanes up to Station Street at both ends. |
| **Freight Yard** | x 80..716, z +100..+410 | Two sidings full of box wagons, a raised goods platform along the second siding, a water tower, and warehouses on Freight Road. |
| **South Road** | from the road gate at (150, 446) | The passage to Lindenmoor: today's road shape moved 200 studs south (south, west, south), between slag heaps that hide the bends. It leaves through a tunnel portal in the south wall at x 5. The threshold covers the portal's mouth. A slag tip (three tiers and a lane up, a water tower, and a wall-run pair of yard walls) fills the south-east. |
| **Rail Yards** | z −250..+80 | Engine sheds and coal sheds (west). In the east: yard sheds, a water tower, two crane bays straddling the crane spur, a yard wall, four raised walks, the cooling pond with a wall-run pair of yard walls beside it, and warehouses. |
| **Workers' Row** | north-west, x −716..−320 | Five blocks of terraces between Row Street, Mill Street and two back lanes, with a cross lane. The boarding houses are on Mill Street. |
| **Foundry Square** | north, x −320..140 | The square has eight market stalls. The canteen is on its north side, with the market row and the boarding houses behind. The yard road (x 60) runs north onto the **viaduct** over a sunken slag cut, to the shut **gatehouse** at z −708. |
| **The Foundry** | north-east, x 140..716 | The **great hall** at (400, −340) is 200 × 110 and faces Foundry Road. It holds a casting floor with three furnaces, gantries and a stair, and a forge wing with the two forge-room shells. Two big stacks stand behind it. Around it are a stack yard, warehouses, sheds and a casting shed. |
| **Edges** | | Sheer slag walls tagged `RenseiNoGrip` (as the builder makes them). There are only two gaps, each closed by a tunnel portal: the rails east (z 26..82) and the south road (x −14..24). |

### Movement and combat (owner, 2026-10-24: "remember to place things for the movement and combat we currently have in game")

The map is laid out for the moves the game has today. The tuning is in `TuningConfig.Parkour`, `LedgeWalk` and `Swim`, and the shade and noise rules are in `LightService` and `NoiseService`.

| Move or system | Where in Foundry Yard |
|---|---|
| **Climb and mantle** (any upright face; a top to pull onto) | Every house, warehouse and wall. The wagons' sides and roofs, the crane-bay legs, the water-tower legs (plus a ladder), the signal-gantry towers (rungs), the yard walls' copings, the goods platform's edge, and the slag tiers' 8-stud steps. |
| **Climb leap** (Space + W up a wall) | The great hall (30 tall), the stacks' bases, and the 26-tall gatehouse towers. The edge walls are `RenseiNoGrip`, so no climb leaves the map. |
| **Wall run and kicks** (a side wall; kicks chain to another wall) | The yard-wall pairs set 12 apart: between the crane yard's pond and Foundry Road, and in front of the slag tip. Also the long terrace fronts on every street, the wagons' 28-long sides, the rail walks' plate fascias, and the great hall's 200-long front. |
| **Ledge walk** (`RenseiLedge`) | A strip at 6 along every yard wall, along both sides of every rail walk (six on the rail corridor, four over the crane yard), and at the first floor on the free gable ends of the houses. |
| **High routes and noise** | The iron rail walks (14 up) and the signal gantries (24 up) give loud metal footsteps. The crane girders (about 30 up), the water-tower decks (20) and the wagon roofs (about 12) are lookouts. |
| **Stealth and shade** (a roof within 80 overhead counts as indoors) | The underworks tunnel, the booking hall, the station and platform canopies, the great hall and its forge wing, the market stalls, and under the rail walks. Quiet cinder lanes run behind every terrace, and the freight path runs to the stowaway door. |
| **Cover** | Crate, boiler and barrel clusters along the quiet lanes and in the back yards. The wagons (gaps between them to slip through), the yard walls, and the furnaces and anvils inside the hall. |
| **Swimming** (terrain water, `SwimService`) | The cooling pond in the crane yard: 140 × 96, surface y 3 (1 below the ground) and 9 deep, so you can dive. |
| **Fights** | Four Grunt spawns in the underworks tunnel only (owner). The practice court is Brannoc's yard. |

The markers in the file:
- the travel pieces, which `setup.lua` builds (see the import notes);
- Brannoc's `TrainerSpot`;
- 12 `RenseiArea` boxes (11 names), which cover the footprint with no overlaps;
- 2 `RenseiClue`s (`foundry_shift_ledger`, `foundry_altered_docket`);
- 4 `RenseiEnemySpawn` Grunts;
- 76 `RenseiPost`s (Work, Seat, Counter, Home, Shelter) for about 25 townsfolk;
- 2 `EdgeGap`s.

The renders show water as see-through preview slabs; the Studio import fills `water.json`'s box with terrain water.

## Files

| File | What |
|---|---|
| `Art/Regions/Foundry/layout.json` | The region file. |
| `Art/Regions/Foundry/materials.json`, `water.json` | Written by the build. `water.json` holds the cooling pond. |
| `Art/Blender/region_builder/kits/foundry.py` | Foundry's own set pieces in the rail-town style: `great_hall`, `ticket_hall`, `platform_canopy`, `road_gate`, `gatehouse`, `shift_office`, `signal_gantry`, and the yard pieces for movement and combat, `wagon`, `water_tower` and `yard_wall`. Their footprints are in `kitspec.py` under `"foundry"`. The kit has no building styles, so the districts use `railtown`'s. |
| `Art/Blender/region_builder/extras.py` | Extra stages: tunnel portals in `EdgeGap`s that carry `Attr.Portal` (rail or road; `RenseiNoGrip`, Edges group); the viaduct (it isn't a kit landmark, because the landmark stage would fill the cut under it with a footing); a render-only preview of the travel pieces setup builds (platform, train, booth, board, gate, railing, the stowaway yard's crates). The preview is not exported or counted. |
| `Art/Blender/region_builder/tools/build_foundry.py` | The build: `build.run`, the extras, the count, Foundry's extra street shots, and a save. Progress goes to a log file, because a full build outlasts the bridge's 300-second wait. |
| `Art/Blender/region_builder/tests/foundry_check.py` | Pure checks on the layout. |
| `Art/Blender/region_builder/tests/foundry_blender_check.py` | Checks on the built scene. |
| `Art/Blender/Regions/Foundry.blend` | The build. Never committed. |
| `Documents/images/Regions/Foundry/` | The renders. |

Build it:
```
python -I Art/Tools/blender_mcpc.py code @Art/Blender/region_builder/tools/build_foundry.py
```
Set `FOUNDRY_RENDER` (see the file's header) to include renders. Then run the checks:
```
python -I Art/Blender/region_builder/tests/foundry_check.py
python -I Art/Tools/blender_mcpc.py code @Art/Blender/region_builder/tests/foundry_blender_check.py
```

## Numbers

| Group | Parts |
|---|---|
| Ground (stepped slabs, the embankment, the slag tiers and cut, the pond's bed) | 3,979 |
| Routes (kerbs, rails, stairs) | 1,948 |
| Buildings (terrace houses, boarding houses, warehouses, sheds, stacks) | 31,323 |
| Landmarks (the kit pieces, the underworks tunnel, the viaduct) | 2,165 |
| Cover (crate, boiler and barrel clusters; street lamps) | 3,777 |
| Edges (walls and the two portals, all `RenseiNoGrip`) | 391 |
| Markers | 102 |
| **Total** | **43,685** of the 45,000 ceiling (spec §3.6) |

- A full build takes about 15 minutes in Blender; with all 34 renders, about 45.
- `foundry_blender_check.py` takes about 25 minutes. Its result goes to `<temp>/foundry_check.json`, because the bridge stops waiting after 300 seconds.

## The import (2026-10-24, owner: "Import Foundry Yard into the Foundry Yard place")

Done in Studio, in the Foundry Yard place (109591196441030), Edit mode, with the region tools. Ye wasn't touched.

1. **Export:** from `Foundry.blend` with origin (0, 0, 0) to `Art/Studio/Regions/Foundry/layout.json`. 2,061 models and 43,685 parts, 189 lights.
2. **`kit.py Foundry`** wrote 39 chunks to `Art/Studio/Regions/Foundry/import/`.
3. **First dry run: FAILED, and nothing changed.**
   - 231 of the 535 buildings were missing from the staging. A district's building ids restarted at 0 on each of its frontages, so a later chunk replaced an earlier building with the same name.
   - **Fixed in the builder:** `placement.plan_buildings` now numbers ids through the whole district. A check was added to `tests/run.py` and one to `foundry_check.py`.
   - Rebuilt, exported again (no duplicate ids) and regenerated.
4. **Dry run ok:** 2,061 models and 43,685 parts, with every tag count as expected. It reported: keep list [], move `Foundry` into the backup.
5. **Real run** (`Confirm = "Foundry"`):
   - `World.Map.Foundry` is the new map.
   - The hand-built map is in `ServerStorage.RenseiBackups["Pre-Region_Foundry_2026-10-24"]`, with its tags set aside.
   - The three texture-pack MaterialVariants are in MaterialService.
   - The pond is terrain water (2,026 cells).
   - `restore.lua` undoes all of it.
6. **`setup.lua`** (`--region Foundry --map-child Foundry --origin 0,0,0`) built `Map.Foundry.Travel` from the 7 travel markers: the station with both trains, the booth, the board, the papers gate, the railing, the freight yard with its watchman, and the 447-stud South Road with 3 encounters. Brannoc's TrainerSpot was skipped.
   - **Fixed along the way:** the passage's own trees and slabs stood in the void past the south wall, and an oak reached through the portal.
   - The RoadPassage `Skip` is now `[[-2000,-2000,2000,2000]]`, in the region file, the export and the placed marker.
   - `travel_pieces.lua`'s end-of-road cluster now honours `Skip`. With no `Skip`, as on Lindenmoor's road, nothing changes.
   - The road now builds only its markers and the 30 bank stones at the encounter spots, which are the ambush cover.
7. **Contract test:** PASS 101 / FAIL 0.
8. **Spawn:** the old `Spawn` went to the backup with the old map. A new invisible, walk-through `SpawnLocation` named `Spawn` stands on the platform at (−648, 6.9, 360), as a child of `Map.Foundry`.
   - It isn't part of the export, so **re-add it after any re-import**.

9. **Play (hooked, the owner's save restored before Stop).** One Play session ran at a time across both places: Ye was in Edit and carried a PlayLock `Foundry:travel suites` while Foundry ran.
   - **Passing:** Boot 2/2, Station 20/20, Road 11/11, Gate 13/13, Arrive 5/5.
   - **Known failures:** Travel 5/7 and RideEvents 8/9 fail only on the known Cabin/Second ticket in the owner's real save, as in Ye.
   - **Two suites assumed the old map,** and both now read the built station and road (`Art/Studio/Travel/src`). Both changes are installed in Foundry's `RenseiTests`; Ye's behaviour is unchanged.
     - `Play_Station` now finds a setup-built platform beside the train.
     - `Play_Road` now steps back to a spot only leg 1 holds (Foundry's first leg is shorter than Lindenmoor's).
     - Foundry's copy of `Play_Road` was also brought up to the repo's version, which reads its spots from the built road.
   - Station once failed 4/20 when it ran first in a fresh session; with Boot first, it passed 20/20.

**Not done in this import (next):**
- **Brannoc's move out of Ye.** This touches Ye, where the other session is working. See note 10 below.
- **The game data:** areas, roster, clues and the shift-ledger quest.
- **The owner's save of the place.**

## Foundry import notes (for the Studio import, a later session)

Follow `Documents/Region Builder.md` §§3–9. What is particular to Foundry:

1. **Place:** Foundry Yard, 109591196441030. Edit mode, through the region tools only (`kit.py` → chunks → **dry run** → chunks → `Confirm = "Foundry"`).
2. **MapChild: `Foundry`.** This is the same name as today's hand-built `World.Map.Foundry` (from `station_foundry.lua`). The real run moves every non-kept `World.Map` child into `RenseiBackups["Pre-Region_Foundry_<date>"]` before it builds the new one, so the old map goes to the backup with its tags set aside.
3. **Keep list: empty (`KeepMapChildren` absent).** Measure `World.Map`'s children first. Anything there other than today's `Foundry` model (for example a leftover from the Testbed smoke test) needs a decision, not a silent move. The `Texture pack (realistic)` model is in `Workspace`, not `World.Map`, so the import leaves it alone.
4. **What the import retires** (all of it moves to the dated backup, with tags set aside):
   - today's ground;
   - the platform, rails and buffer stops;
   - the `Platform` and `SouthGate` `RenseiArrival` points, and the town gate arch at z 190;
   - the `Spawn` SpawnLocation;
   - the 400-stud `Foundry Yard` area;
   - the hand-built `Station` model (both trains, booth, board, `StationGate`, `PlatformRailing`, `FreightYard`);
   - the `PassageGround`, `Road` and `RoadGate`;
   - the `SouthRoad` passage with its passage, encounter and threshold markers and its `RoadStart` arrival.

   `station_foundry.lua` stays in the repo for history and is never run again.
5. **SpawnLocation:** the new map has none. Decide whether the place needs one; players normally arrive at `Platform` or `RoadStart`. The old one was on the platform.
6. **The `SouthGate` arrival goes.** World Plan 1 Task 8 used it as Lindenmoor's road arrival, and Task 8b moved road arrivals to `RoadStart`. Before the import, grep the live scripts for `"SouthGate"` and confirm nothing still asks for it.
7. **Travel setup:** `setup.lua` with `REGION = "Foundry"`, `MAP_CHILD = nil` (that is, "Foundry") and **`ORIGIN = (0, 0, 0)`**. It needs `ServerStorage.TrainKit`, which Foundry already has. It builds:
   - the station: Route `LindenmoorFoundry`, TrackX −660, RailTop 4.6, NoseZ 620;
   - the booth (`Station = "Foundry"`), the board on the platform's back edge, the gate (Yaw 90, facing the track) and the railing runs;
   - the freight yard by the baggage car;
   - the South Road passage: Route `RoadLindenmoorFoundry` to Lindenmoor, RoadY 4, Half 22, Threshold 432, RoadStart 290, and a `Skip` reaching well past the footprint ([[-2000,-2000,2000,2000]]). The region paves the road, so the passage builds only its markers and the bank stones at its encounter spots, with no Lindenmoor trees or ground.

   It skips Brannoc's `TrainerSpot`. Then run the contract test and the travel suites (Boot, Travel, Station, Road, Gate, RideEvents, Arrive). **Check by eye** that the threshold box covers the south portal's mouth and that the road's RoadPoints sit on the paving.
8. **Ride train clearance:** the ride train sits at +(0, 400, −1600) from the platform train, so at about (−660, 405, −980). That is outside the footprint and high above everything (the stacks top out near y 120). The contract test checks it.
9. **Materials:** `materials.json` has the texture-pack roles. The ground is `Terrain K` (dark cinder), the paving `Floor H` (grey slabs) and the quiet lanes `Terrain D`. They were picked by eye from the pack's thumbnails and are PROPOSALs: check them in Studio after the import. The Blender renders show flat palette colours.
10. **Brannoc's move (spec §7.2), in Ye then Foundry:**
    - Back up Brannoc, the `SilentForge` and `ForgeFloor` models with their trial markers, their alchemist spawn and Ye's small `FoundryYard` model in `RenseiBackups["Pre-FoundryMove_<date>"]` in Ye.
    - In Foundry, Brannoc stands at the `TrainerSpot` (−200, 490), inside the practice court, facing its gate (Yaw 0, toward −Z).
    - The two forge rooms are shells inside the great hall. Each room's floor part carries `Room = "SilentForge"` / `"ForgeFloor"` and a Note.
      - In region coordinates, with the hall at (400, −340) and Yaw 180, the room floors are centred at about (373, −364) (Silent Forge) and (325, −364) (Forge Floor). Each is about 39 × 50, with a doorway onto the forge wing's corridor toward +Z (the hall's front).
      - Measure each Ye room's gameplay pieces first and check they fit.
      - Move in the trial markers (`RenseiTrial`), minigame targets and alchemist spawn with the same ids.
    - Quest change: `acq_metal` gets a first stage, "Travel to the Foundry Yard" (an `Arrive` objective), with its location text. `Regions` maps `Silent Forge` to Foundry.
11. **Game data:**
    - **Areas:** add the 11 Foundry `AreaName`s to `Rensei.Regions` (Foundry Station, The Underworks, Practice Court, Cinder Lane, Lower Town, Freight Yard, South Road, Rail Yards, Workers' Row, Foundry Square, The Foundry).
    - **Roster:** write the Foundry roster in `Rensei.Townsfolk.Regions.Foundry` against the 76 posts. Each post's `PostId` is in `layout.json`. Every hour must be covered, with no two people at one post.
      - There are 7 shelters: station, yard, hall, foundry, square, workers, lower.
      - Two posts aren't on the ground: `station_porter_platform` is on the platform top (y 6.4), and `hall_gantry` is on the great hall's west gantry (y 20).
    - **Clues:** `foundry_shift_ledger` and `foundry_altered_docket` in `Rensei.Investigation`, plus the shift-ledger quest (spec §7.3).
    - **Enemies:** confirm the 4 Grunt spawns in the underworks are wanted live.
12. **Terrain water:** the import fills the pond from `water.json` (Task 11). Check in Play that SwimService swims you in it.
13. **Tags that need the export's row field 16:** `RenseiNoGrip` on every edge wall and portal part, `RenseiLedge` on the rail walks and the houses' ledges, the markers, and `NightOnly` lamps (an attribute). The Task 9 export already writes them.

## Test notes (Foundry Yard game-data plan, Task 9; Task 10 owns the Kit)
- **`Play_FoundryWalks` quick mode** (owner, 2026-10-25: "one full walk of every route, then repeats only for routes that needed repairs or failed before", made stricter: "only recheck routes that failed or needed a replan, not routine corner repairs"). Set `game.ServerStorage:SetAttribute("WalksQuick", true)` before running the suite (clear it after); without it the suite walks the whole day. Quick mode walks only the hours of the routes in `Scripts/ServerStorage/RenseiTests/RiskyWalks.lua` (`{Id, From, To}`), checks every listed route was walked and fails with "no risky list" on an empty list. Each run prints the routes that failed or needed a replan (a corner repair alone doesn't count) (`[FoundryWalks] risky: ...`, also ServerStorage's `FoundryWalksRisky`): after a full run, copy those lines into `RiskyWalks.lua` (keep the seeds) and sync it.

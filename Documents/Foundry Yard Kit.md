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
- [x] **Brannoc's move out of Ye.** Done by the Foundry Yard game-data plan (Tasks 7 and 8): see "The game data" below.
- [x] **The game data:** areas, roster, clues and the shift-ledger quest. Done by the same plan (Tasks 1–9).
- [ ] **The owner's save of the place.** Only the owner saves. It is the first step of the joint publish checkpoint (`Documents/Lindenmoor Kit.md`).

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
10. **Brannoc's move (spec §7.2), in Ye then Foundry.** *(Done by the game-data plan, Tasks 7 and 8; Ye's `FoundryYard` model stayed in Ye, owner decision A. See "The game data" below.)*
    - Back up Brannoc, the `SilentForge` and `ForgeFloor` models with their trial markers, their alchemist spawn and Ye's small `FoundryYard` model in `RenseiBackups["Pre-FoundryMove_<date>"]` in Ye.
    - In Foundry, Brannoc stands at the `TrainerSpot` (−200, 490), inside the practice court, facing its gate (Yaw 0, toward −Z).
    - The two forge rooms are shells inside the great hall. Each room's floor part carries `Room = "SilentForge"` / `"ForgeFloor"` and a Note.
      - In region coordinates, with the hall at (400, −340) and Yaw 180, the room floors are centred at about (373, −364) (Silent Forge) and (325, −364) (Forge Floor). Each is about 39 × 50, with a doorway onto the forge wing's corridor toward +Z (the hall's front).
      - Measure each Ye room's gameplay pieces first and check they fit.
      - Move in the trial markers (`RenseiTrial`), minigame targets and alchemist spawn with the same ids.
    - Quest change: `acq_metal` gets a first stage, "Travel to the Foundry Yard" (an `Arrive` objective), with its location text. `Regions` maps `Silent Forge` to Foundry.
11. **Game data.** *(Done by the game-data plan, Tasks 3–6: 88 posts with 19 shelters, 26 townsfolk, the shift-ledger quest. See "The game data" below.)*
    - **Areas:** add the 11 Foundry `AreaName`s to `Rensei.Regions` (Foundry Station, The Underworks, Practice Court, Cinder Lane, Lower Town, Freight Yard, South Road, Rail Yards, Workers' Row, Foundry Square, The Foundry).
    - **Roster:** write the Foundry roster in `Rensei.Townsfolk.Regions.Foundry` against the 76 posts. Each post's `PostId` is in `layout.json`. Every hour must be covered, with no two people at one post.
      - There are 7 shelters: station, yard, hall, foundry, square, workers, lower.
      - Two posts aren't on the ground: `station_porter_platform` is on the platform top (y 6.4), and `hall_gantry` is on the great hall's east gantry (y 20). It stands at x 495.5, east of the hall's centre (x 400), and Foundry's east is +X. (Corrected by the game-data plan, Task 10: this note first said "west".)
    - **Clues:** `foundry_shift_ledger` and `foundry_altered_docket` in `Rensei.Investigation`, plus the shift-ledger quest (spec §7.3).
    - **Enemies:** confirm the 4 Grunt spawns in the underworks are wanted live.
12. **Terrain water:** the import fills the pond from `water.json` (Task 11). Check in Play that SwimService swims you in it.
13. **Tags that need the export's row field 16:** `RenseiNoGrip` on every edge wall and portal part, `RenseiLedge` on the rail walks and the houses' ledges, the markers, and `NightOnly` lamps (an attribute). The Task 9 export already writes them.

## The game data (2026-10-24, Foundry Yard plan)

The Foundry Yard game-data plan (`Documents/plans/2026-10-24-foundry-yard-game-data.md`, Tasks 1–10, 2026-10-24 to 2026-10-25) gave the new map its game: areas, townsfolk, the shift-ledger quest, the forge rooms and Brannoc. All of it is in the Edit sessions of **Foundry Yard** (109591196441030) and **Ye** (106992859583940). **Neither place is saved or published.** The owner's "Hold both" stands: Ye and Foundry Yard go live together, through the joint publish checkpoint in `Documents/Lindenmoor Kit.md`.

Every number below is a **PROPOSAL** unless it is measured or the owner chose it. Directions use **Foundry's compass**: north is −Z, east is +X (`Regions.NorthOf` gives "-Z").

### What's live in Studio
- **The areas.** The 11 area names (Foundry Station, The Underworks, Practice Court, Cinder Lane, Lower Town, Freight Yard, South Road, Rail Yards, Workers' Row, Foundry Square, The Foundry) and `Silent Forge` all map to region Foundry in `Rensei.Regions`. Foundry has State law, and the Foundry and Townsfolk factions.
- **The posts.** 88 `RenseiPost`s: the kit's 76 plus 12 new Shelter posts (`foundry_posts.lua`). Every post has a Shelter within 145 studs (the worst is `yard_hand_4` at 140.0), under `TownsfolkService.ShelterRadius` 150.
- **26 townsfolk and their day** (`Rensei.Townsfolk.Regions.Foundry`, ids `fy_*`; all names original, checked by `Test_FoundryRoster`):
  - **Day crew** (crane, furnace and gantry hands) works 06–14 and eats at 14. **Late crew** eats at 13, works 14–22 and has supper at 22. The **furnace keeper** holds the banked fires 22–06.
  - At each shift change the crews eat at the canteen on the square's north side (4 people at 13:00, 14:00 and 22:00). The canteen is served 05–23 by two cooks.
  - The four **traders** keep their market stalls 08–20. The **errand runners** run between the square, Workers' Row and the court 08–19. Two **off-duty guards** sit on the square and at the station.
  - The **station porter**, the **shift clerk** (shift office 06–18), the **yard hands** and the **boarding-house keeper** fill out the day. All 24 Home posts are used.
  - **They walk every schedule change** through the real Mover (Task 4b's corner repair, body rule and 3D sight ray). A failed walk holds and retries (5, 10, 20, 40, 40 s). A townsperson is placed at a post only when no player is within 300 studs of both the rig and the post, so **nobody teleports in sight**.
  - In trouble they run to a Shelter within 150 studs.
  - The server refuses a Talk from beyond `TalkRange` + 4.
- **The shift-ledger quest** (`foundry_ledger`). It starts by inspecting the ledger at the shift office's lectern (−145, 465), just east of the practice court.
  - Stage 1: ask Edmund Rusk, Sella Marsh and Aldous Merriweather (each clue line gives its evidence).
  - Stage 2: the altered docket in the underworks (−330, 676), locked until then.
  - Stage 3: the deduction `foundry_ledger_who`.
  - Rewards: 300 EXP, 100 money and the deed `foundry_ledger_cleared` (Candor 5, Order 5, Foundry standing 10).
- **The forge rooms and Brannoc** (`build_forge.lua`, Task 7). They are built from the pieces Ye had, with the same ids.
  - `Map.Foundry.ForgeRooms`: the Silent Forge (20 pieces, the `Silent Forge` area box at (373, 13.7, −364.5)) and the Forge Floor, whose trial marker stands at (325, 5.2, −364.5) facing −Z. Both are inside the great hall's forge wing.
  - **Brannoc** (the Metal Alchemist) stands in the practice court at (−200, 7.4, 490), facing north (−Z) toward its gate.
  - The trial fits its shell with Radius 24 and FoeDistance 14 (owner decision E).
  - The Forge Floor's shell anvil (`ForgeFloorAnvil`) sat inside the arena. `hide_anvil.lua` hides it (Task 9, reversible).
- **The Ward Alchemist spawn** stands inside the Silent Forge room at (386, 5.2, −348) (owner decision B).
- **The four Grunts in the underworks** are the only enemies in Foundry (owner: they stay live). None spawns in the town above.
- **`acq_metal`** (the Metal path) now opens with a travel stage, "Travel to the Foundry Yard" (an `Arrive` objective). Then come the invite, fieldwork, the experiment, the trial, the exam and recognition.
  - A save from before the change moves forward one stage on join (decision C). In Studio, that upgrade waits for the test hook's snapshot.
  - In Ye, a notice at the Metal TrainerSpot starts the quest for a student with no path (decision D). It says "...OR WALK THE NORTH ROAD OUT NORTH-WEST" (Ye's compass).
- **Two place scripts Foundry lacked** (Task 1): `StarterPlayerScripts.TownsfolkClient` (without it no speech bubbles show) and `StarterCharacterScripts.Health`. Health is the owner's rule that health comes back only out of combat.
- **Ye keeps `FoundryYard`.** Brask's yard and `chalk_foundry` stay in Ye (owner decision A).
- **Part counts** (Task 9, measured):
  - Foundry's workspace: 46,984. `Map.Foundry` by the plan's definition: 43,719 of the 45,000 ceiling.
  - Ye's workspace: 76,326 of 80,000. That is 47 fewer than the Lindenmoor Kit's 76,373, since Brannoc and the forge left (and the notice came).

### Foundry differs from the kit
Foundry's map is **not** what the kit files build (`Art/Regions/Foundry/layout.json`, `Art/Studio/Regions/Foundry/import/chunk_*.lua` and `Foundry.blend`). These were made in Studio after the import, and none is in the kit:
- the **`Spawn` SpawnLocation** at (−648, 6.9, 360), a child of `Map.Foundry` (the import's step 8): re-add it by hand;
- **`foundry_posts.lua`** (flag `FoundryPosts`): the 12 Shelter posts, the 4 canopy PathfindingModifiers, `yard_hand_2` and `yard_hand_3` moved off the goods platform, and the 4 walk-through stall shelves;
- **`walk_fixes.lua`** (`FoundryWalks`): the crates 2 studs south of House 11, and the 4 stall counters 0.6 forward;
- **`build_forge.lua`** (`FoundryForge`): the forge rooms, the Ward spawn and Brannoc;
- **`hide_anvil.lua`** (`FoundryAnvil`): the Forge Floor's shell anvil hidden.

**A re-import from the kit, or a Blender rebuild and fresh export, silently drops all of these.** Nothing warns you: the import's own checks pass, because they compare against the kit. (`restore.lua` does refuse while any of their flags is set, so the import can't be swapped out from under them.)

After any re-import, re-apply them in the order they first ran: the Spawn (by hand), `foundry_posts.lua`, `walk_fixes.lua`, `build_forge.lua`, then `hide_anvil.lua`. Each script runs in Edit from a scratch copy with only its `MODE` line edited, and its check must pass.
- `build_forge.lua` is generated from `forge/forge_kit.json`, which was exported from Ye before Task 8 retired Ye's forge. **Never regenerate it**: the export it needs is gone from Ye's workspace. Run the committed file.
- Then run `Play_FoundrySmoke`, `Play_FoundryForge` and `Play_FoundryWalks`.

### Rolling back the game data (both places)
Do this in Edit, never in Play. Before each step, check that `ServerStorage`'s `PlayLock` is nil **in both places**. Each reversible script: copy the committed file to the scratch folder and edit only its `local MODE = ...` line there. **Undo** is the mode for every map step below.

**Foundry** (109591196441030):
1. **`Art/Studio/Regions/Foundry/forge/hide_anvil.lua` undo.** It puts `ForgeFloorAnvil`'s five values back and clears `FoundryAnvil`.
2. **`Art/Studio/Regions/Foundry/walk_fixes.lua` undo.** It puts the crates and the stall counters back and clears `FoundryWalks`. After this, `Play_FoundryWalks` and `Test_FoundryPaths` fail. That is expected.
3. **`Art/Studio/Regions/Foundry/forge/build_forge.lua` undo.** It destroys every **top-level** `FoundryForgeAdd` instance and clears `FoundryForge`: ForgeRooms with both rooms, the area box, the trial marker, the Ward spawn and Brannoc.
   - **Brannoc's rig descendants aren't marked one by one** (Ruling 35 (1)). Only his model and props carry `FoundryForgeAdd`, and undo removes the rig's own parts with the model. An unmarked part under Brannoc is expected, not a leftover.
4. **`Art/Studio/Regions/Foundry/foundry_posts.lua` undo.** It destroys the 12 shelters and 4 canopy modifiers, puts the two yard posts back and makes the 4 shelves solid again, then clears `FoundryPosts`.
   - No `fix_ledges.lua` exists: Task 9 found all 377 ledges facing their walls. `FoundryLedges` is reserved and was never set.

**Ye** (106992859583940):

5. **`Art/Studio/Regions/Foundry/forge/retire_ye.lua` undo.** It brings Brannoc, the Silent Forge, the Forge Floor and the Ward spawn back from `Pre-FoundryMove_2026-10-24`, with their tags. It also removes `BrannocNotice` and clears `FoundryMove` on `World.Map`.
6. **`Art/Studio/Regions/Lindenmoor/post_fixes.lua` undo.** It puts the five posts back (`lm_lookout_seat`, `lm_haybarn_shelter`, `lm_farm4_field`, `lm_farm1_home`, `lm_signal_box`) and clears `LindenmoorPostFixes`. After this, `Test_YePaths` fails. That is expected.

**Both places:**

7. **Revert the scripts this plan changed** from `ServerStorage.RenseiBackups["Pre-FoundryData_2026-10-24"]` **in that place**. Back up each current copy, then set its Source from the backup.
   - Revert **only labels whose live script has no `FoundryDataAdd` attribute**. The backups of created scripts (14 in Foundry, 6 in Ye) are mid-plan copies; those scripts are deleted in step 8 instead.
   - **Foundry (17):**
     - `Rensei.` Deeds, Dialogues, Evidence, Investigation, Minigames, Quests, Regions, StoryLogic, Townsfolk and Trials;
     - `RenseiServer.` MinigameService, QuestService, ServerHandler and TownsfolkService;
     - `TownsfolkService.Mover`;
     - `RenseiTests.` TestKit and Test_Regions.
   - **Ye (22):** the same 15 package scripts, plus `RenseiTests.` TestKit, Test_Regions, Play_Exams, Play_Townsfolk, Play_TownsfolkHurt, Play_LindenmoorData and Play_LindenmoorSmoke.
   - **Never take `Rensei.Puzzles` or `UI.CompassUI` from git.** This plan changed neither, so it has no backup of them. Their Studio text is ahead of git at the Lindenmoor plan's base (see `Documents/Lindenmoor Kit.md`, "Rolling everything back", step 11).
   - **If the packages were already published,** revert the package scripts in Ye, publish Modules and RenseiServer again, and update Foundry's packages by hand (World Travel.md §10). Revert the place scripts (`RenseiTests`) in each place.
8. **Delete the scripts this plan created.** They have no pre-plan backup. Each carries `FoundryDataAdd = true`: delete every script outside `RenseiBackups` with that attribute, after checking the count.
   - **Foundry (22):**
     - `StarterPlayerScripts.TownsfolkClient` and `StarterCharacterScripts.Health`;
     - `RenseiTests.` Test_TownsfolkLogic, Play_TownsfolkCrowd, Play_Clue, Play_Clock, Play_Exams, Play_NoGrip, Test_QuestRevision, Play_QuestEngine, Test_AcqMetal, Test_FoundryRoster, Play_FoundryLedger, PathKit, Test_MoverRepair, Test_FoundryPaths, Play_FoundryWalks, RiskyWalks, Play_FoundryForge, SmokeKit, Play_FoundrySmoke and Play_FoundryData.
   - **Ye (7):** `RenseiTests.` Test_QuestRevision, Play_QuestEngine, Test_AcqMetal, SmokeKit, PathKit, Test_MoverRepair and Test_YePaths. Ye's Play_LindenmoorSmoke goes back to its backup in step 7 instead.
   - Read live in Edit (2026-10-25): Foundry has 22 marked scripts outside the backups and Ye has 7.
9. **Foundry's `Art/Studio/Regions/Foundry/import/restore.lua`,** only to undo the region import itself as well (back to the hand-built World Plan 1 map). It refuses, changing nothing, while `Map.Foundry` carries `FoundryPosts`, `FoundryForge`, `FoundryLedges`, `FoundryWalks` or `FoundryAnvil` (the region file's `RestoreRefuseFlags`), so steps 1–4 come first. The new `Spawn` leaves with the new map, and the old one comes back with the old map.

**Then:**
- Run the travel suites in both places: Play_Boot first, then Station, Road, Gate, Arrive, Travel and RideEvents.
- `sync.py --check` then reports differences. That is expected: the repo still holds the plan's text. To roll the repo back too, revert the plan's commits.
- To roll back further, into the Lindenmoor import, continue with `Documents/Lindenmoor Kit.md`, "Rolling everything back". Its step 0 is step 5 here.

### The smoke test (`ServerStorage.RenseiTests.Play_FoundrySmoke`)
The repo copy is `Scripts/ServerStorage/RenseiTests/Play_FoundrySmoke.lua`. Run it in hooked Play through `LMRunSuite`. It passed **15/0** after Task 9's fix round. Every check has a RED control: some run inside the check every time, and the others were run once (Task 9's report).

| Check | What it proves |
|---|---|
| EveryPostIsReachable | Each of the 88 posts has a path from the square at the Mover's own radii, ending within 2.5 of the post's foot. A rig-sized box at the post overlaps no colliding part. Controls: a post at floor level inside the great hall's back wall fails the box; one at the wall's centre fails the reach. |
| EveryPostHasAShelter | Each post's nearest Shelter is at most 145 studs off. Control: a synthetic far post is reported. |
| EdgesCantBeGrabbed | On each map edge, at a spot chosen without reading the tag, the edge wall isn't grippable and the server refuses a climb and a wall run. Control: with the `RenseiNoGrip` tags near the west spot taken off, the climb is accepted (the tags go back). |
| LedgesFaceTheirWalls | All 377 `RenseiLedge`s face a wall within 1.5 studs. Control: a ledge turned 180° fails. |
| LampsFollowTheClock | The 154 `NightOnly` lamps are in WorldClock's set: lit at 23:00, dark with the day material at 12:00. Control: a lamp without `NightOnly` fails the count. |
| PondSwims | The cooling pond is terrain water. A player placed in it is in deep water and in the server's swim state within 3 s, and out of it on the platform. Control: dry ground isn't deep water. |
| TravelIsSingle | Exactly one RoadStart, one Platform and one LindenmoorFoundry platform train, and TravelService finds them. Control: a duplicated Platform arrival fails. |
| TrialsAreInTheWorld | One `RenseiTrial` (metal_experiment) in workspace with its prompt, and none outside. Control: a tagged clone in ServerStorage fails. |
| BrannocCanBeTalkedTo | Play_FoundryForge's BrannocTalks: his dialogue, prompt and spot. Control: Brannoc 10 studs off his spot fails. |
| EnemiesStandInTheWorld | The spawns in workspace are 4 Grunts in The Underworks and 1 Ward Alchemist in the Silent Forge room, with none in the town above. Each has a live enemy within 30 s, and ground under it. Control: a Grunt spawn cloned onto Foundry Square fails. |
| CompassMarksPointTrue | North is −Z. The compass has the spawn, Brannoc, trial, clue and area points. Bearings from live positions: the Grunts lie south of Brannoc's spot, and the hall and the Ward spawn north-east. Control: on a +Z compass the hall isn't north-east. |
| TownsfolkAtTheirPosts | Held at 10:00, all 26 are spawned, each within 1.5 studs of its post. Control: the 17 whose 16:00 post differs are away from it. |
| CommuteWalks | Near a player, `fy_runner_1` walks from `errand_square` to `errand_row` (passing through Walking) within 90 s. Control: with no player within 300, it is placed instead, and "passes through Walking" fails. |
| TownsfolkLoopIsCheap | `TownsfolkService.Step` averages under 1 ms over 60 s on the square. Control: a 2 ms busy-wait fails. |
| UnderworksIsShaded | At noon the underworks tunnel reads darker than the open square (0.350 against 1.000). Control: with the tunnel's roof left out of the rays, it doesn't. |

**Also Foundry's own suites:**
- **Play_FoundryData 2/0:** `acq_metal` end to end through the real services, from Brannoc to recognition, and a Ye save moving forward a stage.
- **Play_FoundryForge 8/0.**
- **Play_FoundryLedger 8/0.**
- **Test_FoundryRoster 7/0.**
- **Test_FoundryPaths 7/0.**
- **Play_FoundryWalks 6/0** in three separate sessions, each with 73 of 73 walks arrived and no failures. StepMs was about 0.25 ms.

The travel suites pass in both places, except the two known ticket failures (Play_Travel 5/2 and Play_RideEvents 8/1, the Cabin / Second ticket in the owner's real save).

### Test notes
- **Run Play_Boot first** in every travel run: Play_Station fails 4/20 when it is the first suite of a fresh session.
- **In Ye, run Play_Exams before Play_TownsfolkHurt:** right after it, InCombat lingers and Exams fails 0/5.
- **Edit's require cache.** An Edit run sees a module as it was before a script edit. Run suites that need a changed module in the Play VM (`LMRunSuite`).
- **`Play_FoundryWalks` quick mode** (owner, 2026-10-25).
  - **The rule:** "one full walk of every route, then repeats only for routes that needed repairs or failed before", made stricter: "only recheck routes that failed or needed a replan, not routine corner repairs".
  - **The list:** `Scripts/ServerStorage/RenseiTests/RiskyWalks.lua` (`{Id, From, To}`) holds **14 routes**. 5 are seeds from Task 4b's failures; the other 9 re-planned in at least one of Task 9's three full runs.
  - **Timing:** a quick run takes about 909 s, against about 1,485 s for the full day.
  - **Turning it on:** `game.ServerStorage:SetAttribute("WalksQuick", true)` before running the suite. The suite clears the attribute as soon as it reads it, so it is good for one run, and the header prints `QUICK` or `FULL`. Without it the suite walks the whole day.
  - **What it checks:** quick mode walks only the hours of the listed routes, and checks that every listed route was walked. It fails with "no risky list" on an empty list.
  - **Refreshing the list:** every run, full or quick, prints the routes that failed or needed a replan (`[FoundryWalks] risky: ...`, also ServerStorage's `FoundryWalksRisky`). A corner repair alone doesn't count. After a **full** run, copy those lines into `RiskyWalks.lua` (keep the seeds), then sync it with `sync.py --place foundry --only RenseiTests.RiskyWalks --run`.
  - **Acceptance runs stay full.** Quick mode is for re-checks only.
- **`Test_FoundryPaths` flake.** It failed 1/6 in three sessions on navmesh variation (Task 4b), then passed 7/0 in every later session. If it fails once, re-run it in a fresh session before suspecting the Mover. `Play_FoundryWalks` is the acceptance.
- **Smoke check 1's tolerance:** a post 1 stud inside a 2-stud wall still passes the reach part. The standing box (Ruling 39) catches a post inside a wall at floor level.
- **Save safety:** every Play session in this plan ran the hook protocol. The `Data.Quests` dump was identical before and after the restore in every session. **Studio Play outside that protocol writes the owner's real save, as it always has.**

### Known issues (accepted or parked, 2026-10-25)
None blocks the publish.
- **The errand runners are adult rigs.** There is no child rig, so the two runners are grown-up errand runners.
- **The traders' shelves are walk-through.** The four stalls' Shelf parts have CanCollide off, so the traders can reach their counters. The canopies stay solid (their PathfindingModifiers are PassThrough).
- **An `Arrive` objective has no compass mark.** `acq_metal`'s travel stage ("Travel to the Foundry Yard") shows no point on the compass; its text gives the way.
- **Ye's "Foundry Yard" area** (Brask's yard, owner decision A) shares the town's name.
- **`pads.json` is stale.** Task 4b's and Task 8's post moves changed `Art/Regions/Lindenmoor/layout.json` after `make_pads.py` ran.
  - So `bundle_prep.py prep <out> apply` refuses until `make_pads.py` is re-run and its pads diff reviewed. Re-checked 2026-10-25.
  - An **undo** bundle doesn't need fresh pads, because prep_ye's undo reads no pad data (Ruling 38; the Lindenmoor Kit's rollback step 10). Re-checked 2026-10-25: the undo bundle builds, and the apply bundle refuses with "pads.json is stale".
- **Planning cost.** The worst single planning frame measured was 2.3–3.5 ms against the Mover's 2 ms budget: one chunk over, not a stall.
- **Brannoc is the StarterCharacter R6 rig.** DialogueService gives him his look at runtime, as it does Ye's trainers.

### For the owner to look at
- **`SilentForgeAnvil`** duplicates the kit's Silent Forge anvil. The great hall's shell has its own anvil at (373, 6, −360.5), in the Silent Forge room beside the Anvil brought from Ye. It was left as it is for your eye. Hide it the way `hide_anvil.lua` hid the Forge Floor's if you want.
- **`RepairedGear` may float** in the Silent Forge, as it did in Ye. Look at it on your walk.
- **Brask's `chalk_foundry` stays in Ye** (decision A). Moving it into the Foundry is a Backlog follow-up.
- **Your save.** One Task 4b test session (G12) stopped by itself during Play, apparently another tool in that Studio. The `Data.Quests` check afterwards was identical, but its travel and area writes may remain in your save. Check `Travel` and `Region` before you test live (World Travel.md §10 step 2).
- **PROPOSAL numbers to review** (every one can be changed):
  - **The day:**
    - shifts 06–14, 14–22 and the keeper's 22–06;
    - the canteen served 05–23;
    - the market 08–20;
    - the runners 08–19;
    - the guards 08–20;
    - the clerk 06–18.
  - **Shelters:** the 145-stud design margin under ShelterRadius 150, the 12 Shelter spots, and `cinder_east_shelter` moved to (−90, 268) out of a house.
  - **Map nudges:**
    - `yard_hand_2` and `yard_hand_3` at z 164;
    - the crates 2 studs south;
    - the stall counters 0.6 forward;
    - the canopy PassThrough modifiers;
    - the Ward spawn at (386, 5.2, −348).
  - **Ye's post moves:**
    - `lm_lookout_seat` (715, 33, −447.7);
    - `lm_haybarn_shelter` (641.2, 5, 110.5);
    - `lm_farm4_field` (−631.2, 23, −468);
    - `lm_farm1_home` (−880, 23, −875.5);
    - `lm_signal_box` (660, 5, 822.5);
    - Brannoc's notice at (−130, 6.5, −137.5).
  - **The shift ledger:** 300 EXP and 100 money. The deed gives Candor 5, Order 5 and Foundry standing 10 (Local). All the clue-line and notice wording.
  - **The trial:** Radius 24 and FoeDistance 14 (decision E).
  - **The walking (Mover and TownsfolkService):**
    - repair clearances 2, 1.5 and then 1.25 (the floor), at most 12 new vertices, ground within 1.5;
    - the repair's ground cost floor 1.5 and the varied re-ask spacings;
    - the 3D sight ray of 12 studs;
    - a re-plan with under 10 studs of progress counts as stuck;
    - the failed-walk backoff 5/10/20/40/40 s;
    - placing only with no player within 300;
    - the Talk margin of 4.
  - **Quest saves:** Boot's snapshot wait (0.25 s polls; it gives up with a warning after 120 s) and its data poll (every 0.5 s, a one-time notice after 240 tries).

### Status page
After the final review, the controller pushes the plan's commits and updates the status page artifact. The implementer does neither.

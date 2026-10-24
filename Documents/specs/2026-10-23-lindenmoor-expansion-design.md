# Lindenmoor expansion: design

**Status:** layout approved by the owner on 2026-10-23 ("Yes, build it"), and the renders too ("The expansion renders look good. Approved for a later Studio import."). Built in Blender only. Studio import comes later and is coordinated by the main session.

**Owner's request:** grow Lindenmoor (Ye, placeId 106992859583940) to its full 2,048 × 2,048 footprint around the finished village, following page 3 of the Regional Map Design Brief. This runs in parallel with the region foundation plan.

**Owner's choices (2026-10-23):**
- **Hub graybox:** "Plan as if it's gone". The layout uses the hub's ground. After the build the owner refined this: the hub's pieces **move into the new map** (§5).
- **Exits:** "Together, NE corner". The north road and the station line leave side by side through one gap in the north-east rim.

Every number here is a **PROPOSAL** unless it is marked measured or quoted.

## 1. Orientation and placement (findings)

- **The brief reads correctly with drawing-down = +Z.** Ye's own convention is +Z = north: the village's north road runs +Z, and the station's train noses +Z. The brief draws north at the bottom with east on the right, which is exactly Studio's top-down view.
  - The region-builds spec rule "drawing top = south = +Z" is **mirrored for Ye**. With it, the creek, the north road, the fields and Bramble Hollow would all be on the wrong side.
  - Against the real village, four things in the schematic don't match. The new areas are placed against the real village, not the drawing:
    - Workshop Hill is drawn past the creek; it is really on the square's side of it.
    - The gorge is drawn near Bramble Hollow; it is really by the creek.
    - The station is drawn east; it is really west.
    - Cypress Ridge is drawn north-west; it is really the south edge.
- **The village is not central.** It sits against the south edge of the 2,048² baseplate: world z −990..−298, with about 30 studs to spare. The baseplate is assumed to be Roblox's template (centre (0, −8, 0), top y 0); this is not measured. Nearly all the new land is west, east and north of the village.

## 2. Layout

The source of truth is `Art/Regions/Lindenmoor/layout.json`, in world studs (x east, z north), in the region-foundation Task 8 format plus the extensions listed in its `Notes`.

| Area | What's there |
|---|---|
| **South-west: outlying farmsteads** | Four farms on a raised farm plateau (y 22), each with a kit farmhouse, a barn, fenced wheat and hay fields, a well, a cart and a woodpile. A roadside market at their crossroads. Mill Creek runs on west to a spring, with a watermill and a stone viaduct carrying the market road. A patchwork of hedged and walled fields surrounds them. |
| **Market road** | From the farms over the creek, north up the west side, then east across the rails (a level crossing) to the training field. |
| **East: mine approach** | On the plateau above Halvard's Adit: a headframe over a boarded shaft, a winding house, spoil heaps, and an ore-cart track with carts. Nothing inside the Adit changes. |
| **East: Mill Creek gorge** | The creek continues east from the village's Gorge Pool through a deep, meandering gorge (bed y 1, rims y 30–36), ending at a waterfall that pours off the east wall. It has a **second ledge walk** (a `RenseiLedge` strip along the south wall, with shelves and steps at both ends), a timber footbridge from the mine to the lookout, and the **lookout**: a raised stone platform on the north rim. |
| **South-east: Bramble woods** | Bramble Hollow's forest grows on into the corner. |
| **Middle (where the hub was)** | The **training field**: a fenced practice ground with dummies, targets and a vault wall, beside the north road just past the village. The **ridge marker**: a standing stone and cairn on a knoll, a clue spot where the forest path to the rim starts. Around them, **north meadows**: patchwork crop fields (wheat and hay in field gold, cabbages, ploughed strips, fallow), two orchards, two hay barns and lone oaks. |
| **North-west: Cypress Ridge rim** | A cypress-forested ridge up to y 46, with three stone overlooks facing back over the valley. Forest paths with dirt ramps climb between them. |
| **North-east: the gap** | The road and the rails run side by side into a cutting through the north rim. A signal box stands by the line, and the road passage's gate arch sits where the passage starts. The road passage (a `RenseiMarker`, Piece `RoadPassage`) runs about 370 studs from the arch to the threshold, just before the road and rail **tunnel portals** in the north wall. |
| **Edges** | Forested ridges rise on every side (y 46–60). The outer 20–24 studs are a **sheer rock wall to y 170**, about 115 studs above the ridge tops. That is more than a full stamina bar can climb (ClimbSpeed 9, ClimbMove 12/s). There are no invisible walls. The only openings are the tunnel portals behind the threshold. |

- **Movement:** the village's learning sequence is untouched. The new land adds more of each step:
  - field walls and dry-stone field boundaries to vault;
  - terrace steps on the ridges and the overlook paths;
  - a second ledge walk in the gorge;
  - swimming in the creek and gorge;
  - quiet forest paths for stealth (the forest canopy counts as a roof, as in the village).
- **Routes:**
  - north road (12 wide), market road (10), and the rails (gauge 5.2, as Ye's);
  - trails (6 wide): the creek walk, mine trail, gorge crossing, lookout link, rim paths, Bramble path and hay lane.
  - Every route is continuous. Grades are capped (roads 0.3, trails 0.42, rails 0.025 rise per stud), and they climb on tilted dirt ramps, as the village's paths do.
- **Markers in the file:**
  - 10 `RenseiArea`s (no overlaps);
  - 2 `RenseiClue`s (`lm_ridge_marker`, `lm_mine_shaft`);
  - 18 `RenseiPost`s (Work, Home, Counter, Seat, Shelter) for the townsfolk service;
  - 6 `RenseiEnemySpawn` Grunts (Bramble woods, the rim, the mine approach);
  - the `RoadPassage` marker;
  - an `EdgeGap` box.

## 3. Ground

- **Style:** the approved stepped part ground, in 1-stud steps:
  - flat mossy slabs over dark stone sides;
  - 4-stud cells on and beside routes and set pieces;
  - 8-stud cells on gentle ground, where wild slopes round to 3-stud terraces;
  - 16-stud cells on flat ground far from features;
  - patchwork fields levelled into single slabs.
- **Merging:** cells merge into rectangles up to 128 studs a side. Stone sides are only built where a neighbour is lower.
- **The village:** nothing is built on its existing ground (the Keep mask, from `terrain_studio.json` and the Adit hill box). New ground blends to the village's edge heights over 64 studs.
- **Water** stays Roblox terrain water (SwimService reads it): the boxes are in `Art/Regions/Lindenmoor/water.json`, one rotated box per channel segment. Surface y 5.2, the same as the creek.

## 4. Part budget

| | Parts |
|---|---|
| Kept in Ye | about 30.5k: village 8.3k, ground 16.3k, Adit dressing 1.5k, trains and station about 4.5k. Needs a Studio count. |
| **Expansion ceiling** | **42,000** (layout `Budget`) |
| Expansion as built | see `Documents/Lindenmoor Kit.md`, "Expansion (Blender)" |
| **Place ceiling** | **80,000**, inside the world spec's 60–90k |

## 5. Hub pieces and import timing (owner, 2026-10-23)

- **Timing:** "Start importing after the townspeople tasks are done." The owner chose to import with the region-foundation tools: Tasks 9 (export with tags), 11 (the staged import) and 12 (travel pieces from markers). Not a one-off import.
- **Hub pieces:** "Move them into the new map", so every trainer questline keeps working until each region is built.

| Piece (from the hub) | New spot (world x, z) | Pad radius |
|---|---|---|
| The five alchemy trainers (Calda, Veyra, Holt, Ansel, Brannoc) | `TrainerSpot` markers along the training field's north edge, (−230..−130, −135), facing into the field | none |
| Burned Laboratory and the Ash Pit (Flame) | Bramble woods, (864, −905) (moved 59.5 studs from (820, −945), Task 2) | 75.4 |
| Frozen Research Station and the Frozen Chamber (Ice) | the north-west rim, (−760, 760) | 77.0 |
| Cracked Footbridge and the Unstable Quarry (Earth) | the mine plateau, (860, −700) | 85.0 |
| Silent Observatory and the Gale Floor (Wind) | the Cypress rim crest, (−700, 520) | 76.0 |
| Silent Forge and the Forge Floor (Metal) | the north meadows by the gap, (560, 900), until they move to Foundry Yard | 76.7 |
| Ye's small Foundry Yard graybox, if it is still in Ye | (300, 880) | 74.6 |
| The LedgeCourse (with the FoundationRun world challenge) | a practice yard, (−20, 60) | 50 |
| The test arena (Wall x2, Curve, Hill, Step, TrainingGround, kept as one block; owner 2026-10-24: "Keep it in the map") | North Meadows, north-east of the practice yard, (104, 184) | 108.3 |

- **The pads:** each spot is a `lindenmoor.reserve` landmark: a flat pad with no routes, fields or trees. Radii (import plan Task 2, 2026-10-24) are the pieces' measured footprint, laid side by side by `pad_layout.arrange()`, + 6 studs (PROPOSAL). Blender shows it with survey stakes, which are never exported.
- **At import:** each piece's footprint is measured in Ye and checked against its pad. Each piece is then moved with its `RenseiArea`, spawns and trial markers.
- **The hub's bandit spawns** are replaced by the expansion's Grunt spawns.

## 6. Files

- `Art/Regions/Lindenmoor/layout.json`: the region file.
- `Art/Regions/Lindenmoor/water.json`: terrain water boxes, written by the build.
- `Art/Blender/lindenmoor/expansion_plan.py`: the pure planner (no bpy): heights, the cell grid, merging, route profiles, fields, tree scatter and the budget estimate.
- `Art/Blender/lindenmoor/expansion_tests.py`: checks on the plan. Run `python -I Art/Blender/lindenmoor/expansion_tests.py`.
- `Art/Blender/lindenmoor/expansion.py`: the Blender stages, renders, part count, export wrapper and save.
- `Art/Blender/Regions/Lindenmoor_Expansion.blend`: the build. Never committed.
- `Documents/images/Regions/Lindenmoor/`: the renders.

`world.py`, `core.py` and `export.py` are unchanged; the expansion only calls them.

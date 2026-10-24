# Lindenmoor Kit (Blender → Studio)

The whole starter village rebuilt in the reference style: blocky, textured, fogged. It is split into a kit of
models that go into Studio with no hand work. It was built on 2026-10-20 and is live in **Ye** (Studio, not published).
Every size, colour and count here is a **PROPOSAL**.

![Square](images/Map%20Concept/Lindenmoor%20in%20Studio%20-%20square.jpg)
![Aerial](images/Map%20Concept/Lindenmoor%20in%20Studio%20-%20aerial.jpg)

Blender renders are in `images/Map Concept/Lindenmoor kit - *.png`, and Studio screenshots are in `Lindenmoor in Studio - *.jpg`.

## What changed in Ye

The village is under `Workspace.World.Map.Lindenmoor`. It now has 8,299 parts; before the swap it had 3,457.

### Rebuilt
- **Houses:** 9 farmhouses (`Farmhouse_House_01..09`), each a different variant:
  - roof tile or slate;
  - plaster colour;
  - shutters, porch, chimney side, door position, shed and laundry line.
  - Each sits on the old house's pivot, with the front facing the lane or road as before. A house has a stone ground floor, a timber-framed upper floor, a tiled roof with rafters and gables, windows with sills and shutters, flower boxes, a door lantern, and a yard (front wall with a gate gap, garden bed, woodpile, rain barrel, crates, bench).
- **Trees:** 63 oaks and 95 cypresses on the old trunk positions.
  - Oaks have square trunks, root slabs, box branches, stacked canopy slabs and vines. They are about 17–22 studs tall, close to the old ones.
- **Lamps:** 17 lamp posts on the old post positions, each with an iron lantern, Neon glow and a PointLight.
- **Barn:** a plank barn on the old barn body, with a slate roof, open door and hay stack.
- **Camp:** the 4 tent halves on the old tent wedges, plus a stone ring and logs round the fire pit and a banner, crates and weapon rack.

### New
These are under `Scenery`:
- **Forest:** 69 big oaks on the valley rim, plus a dense ring round the camp, Bramble Hollow. It stays clear of the workshop hill, the station, the hub road and Halvard's Adit.
- **Ridge:** 28 stacked mossy rock terraces along the south edge (Cypress Ridge).
- **CreekBanks:** 118 clusters of stacked stones on the creek and pond edges. The bridge span is left open.
- **Edging:** 77 small sunk stones along the lane and road verges. Players walk through them.
- **Square:** a kerb ring (open where the road and lane cross), flagstones, 3 market stalls with awnings and goods, and well stones.

### Re-skinned
Material and colour only; the geometry is untouched:
- station, bridge, fences, wheat, cabbages and hay, square benches, well and notice board, gorge rocks, camp seats and crates.
- The old values are stored on each part as the attributes `PreKitMaterial` and `PreKitColor`.

### Kept exactly
- terrain and water, `LindenmoorSpawn`;
- the bandit spawns (`RenseiEnemySpawn`) and `GorgeLedge` (`RenseiLedge`, same CFrame and size);
- the Workshop (owner's model), the StyleTrainers, `LindenmoorRun` and `HubRoad`;
- the Areas, and the camp fire (FirePit, Embers, Fire, PointLight).

### Lighting
- Atmosphere is now a teal haze: Density 0.42, Offset 0.12, Haze 1.8, Glare 0.35, Color #A9C2BF, Decay #5E7A78.
- `OutdoorAmbient` is #5C6A68.
- The old values are stored as attributes on the backup folder.

### Backup
- Everything replaced is in `ServerStorage.RenseiBackups["Pre-LindenmoorKit_2026-10-20"]`: Houses, Trees, Lamps, `Farm_Barn`, `Camp_Tents`.

### Kit
- `ServerStorage.LindenmoorKit` holds one copy of each piece with its pivot at the origin, ready to drag out and place:
  - 9 farmhouses;
  - 4 oaks, 3 big oaks, 3 cypresses;
  - a lamp post, the barn, a tent half, the fire ring, the camp props;
  - 3 ridge terraces, 3 bank-stone clusters, 3 edge stones;
  - the square set.
- The same 34 pieces are also files, `Art/Studio/Lindenmoor/kit/<Group>/<Piece>.rbxmx`. Drag one into any Studio window (Rensei, Tutorial, a test place).

## Gameplay checks (Play test in Ye, 2026-10-20)

| Check | Result |
|---|---|
| Spawn | At the square (local −0.5, 7, −20) |
| Walk the lane east to X 200 and west to X −220 (Humanoid MoveTo, WalkSpeed 16) | Every leg reached |
| Walk the road north over the bridge to Z 170 | Reached; deck height 10.1 |
| Walk into the Bramble Hollow camp, and from the square to the farm | Reached |
| Raycast every 2 studs along the lane, the road and the square | No new part sticks up more than 1.2 studs where players walk. The only hits are overhead roofs and awnings, plus the original well, notice board and bridge |
| LightService lamps (`RenseiLight`) in Lindenmoor | 27: 17 lamps, 9 house lanterns, the camp fire |
| Stealth exposure under a forest canopy vs the open square (ClockTime 14.5) | 0.35 vs 1.00. The canopy counts as a roof, so the woods give shade |
| Swim in the Mill Pond | State Swimming |
| GorgeLedge | Same CFrame and size, still tagged |

The owner's profile was snapshotted when it loaded and restored before Stop. The temporary hook was then deleted.

## How the pipeline works

1. **Studio → Blender:** `Art/Blender/lindenmoor/terrain_studio.json` (8-stud height and material grid, plus water cells) and `layout_studio.json` (every Lindenmoor element), both exported from Ye.
2. **Build:** `Art/Blender/lindenmoor/world.py` (with `core.py` for materials and primitives) builds the scene `Lindenmoor_Full` on the real terrain. Run it in Blender with `lindenmoor.world.run("all")`, or run single stages: `terrain, houses, trees, forests, ridge, creek, edging, square, lamps, barn, camp, reskin, kept, lighting`. The saved result is `Art/Blender/Lindenmoor_Full.blend`.
3. **Export:** `Art/Blender/lindenmoor/export.py` (`export()`) writes `Art/Studio/Lindenmoor/layout.json`, 484 models and 7,517 parts.
   - Every prefab root (an Empty with `rs_prefab`) becomes a Model.
   - Each part keeps its kind (Block, Cylinder or Wedge), its size, its material key and a CFrame relative to the model pivot.
   - Axes: Blender (x, y, z) = Roblox local (X, Z, Y), and rotation R_roblox = P·R_blender·P.
   - Blender cylinders run along local Z; Roblox cylinders run along local X.
   - Checked by round-tripping the 486 re-skinned Studio parts: zero position and rotation error.
4. **Kit files:** run `python -I Art/Studio/Lindenmoor/studio_kit.py`. It writes:
   - `import/chunk_01..07.lua` (about 1,100 parts each);
   - `import/expected.json`;
   - the 34 `.rbxmx` kit files.
   - Materials are Roblox built-ins with a colour each (Plaster, ClayRoofTiles, RoofShingles, WoodPlanks, Wood, Cobblestone, Rock, LeafyGrass, Grass, Fabric, Metal, Neon, Glass). The material table is at the top of `studio_kit.py`.
5. **Import:**
   - Run the chunks in order. They build `ServerStorage.LindenmoorStaging`.
   - Then run `import/finish.lua`. It checks the counts, backs up, swaps, re-skins, fills the kit and sets the haze.
   - `finish.lua` refuses to run twice, because the backup folder is its marker.
   - To send files to Studio, use `Art/Tools/rbxc.py luau "placeId: 106992859583940" Edit @file.lua`. It starts its own StudioMCP client, so large files never pass through chat.

## Open items
- **Real textures in Studio (MaterialVariants):** Studio's MCP image upload only takes images from a web address, and serving them from this PC needs a local web server, which was declined earlier. Two ways to finish this step:
  - allow a localhost server for one upload run;
  - or upload the Poly Haven 1k maps yourself (Creator Hub → Development Items → Decals).
  - In both cases each part's colour stays the same. Variants named after the Blender materials (`LM_Plaster`, `LM_RoofTiles`, …) can be added in `MaterialService` and set on the parts.
- **Collaborator check:** jenkins2bee-prog edits Ye too. The swap happened in Ye's Edit session, so save the place only after both of you have looked at it.

## Update 2026-10-20: no Roblox terrain, fixes, and the Adit restyle

**Owner:**
- "Fix areas in the map that are out of place, also make the dungeon look like the reference picture & layout picture";
- "I don't want to use roblox's terrain. Make it like the references I sent you" (approved deleting the terrain);
- after a tilted-slope try: "Go back to the style we just had ... I just wanted the walk-ways to connect".

![Square](images/Map%20Concept/Part%20ground%20-%20square.jpg)
![Workshop path](images/Map%20Concept/Part%20ground%20-%20workshop%20path.jpg)
![Adit tunnel](images/Map%20Concept/Halvards%20Adit%20-%20tunnel.jpg)
![Adit lab](images/Map%20Concept/Halvards%20Adit%20-%20lab.jpg)

### Part ground (`Art/Studio/Lindenmoor/ground.lua`)
- All solid terrain under Lindenmoor and Halvard's Adit is now parts, in `Workspace.World.Map.Ground` (about 16,300 parts):
  - **Tops:** flat mossy slabs, stacked in 1-stud steps, on the terrain's own 4-stud grid and merged into large slabs.
  - **Sides:** dark stone under every slab, so each step shows a stone face.
  - **Cave:** stone blocks on every voxel that bounded the Adit cave.
- **Walkways connect:**
  - a cell counts as path if any of 5 samples in it hit path paint, and gaps of up to 2 cells along a path are closed;
  - where a path climbs, each cell is a dirt **ramp** tilted to the real slope;
  - so every lane, road and hill path is continuous and walkable; the rest stays stepped.
  - Pathfinding with jumping turned off reaches the workshop door from the lane.
- **Water stays Roblox terrain water**, because `SwimService` reads it. Its bed is now part slabs. Swimming in the Mill Pond was tested and works.
- **Backup:** the original terrain is in `ServerStorage.RenseiBackups["Pre-PartGround_2026-10-20"]` as a TerrainRegion (the Note attribute says how to paste it back). The script re-reads that backup each run, so it can be re-run.

### Out-of-place fixes (`Art/Studio/Lindenmoor/settle.lua`)
- **Workshop walls:** the three workshop `Prop_LowStoneWalls` were single 30-47 stud beams lying on the slope. They are now dry-stone walls (`Workshop.YardWalls`, 34 stones with mossy capstones) along the same lines, stepping with the ground.
- **Seating:** every tree, stone, terrace, lamp, tent, prop and the barn sits on the part ground. Tree trunks and roots reach down to it, and fence posts too.
- **Removed:**
  - creek-bank stones inside the station trestle, the gorge rocks or the bridge;
  - lamp bases inside the road fence (slimmed first);
  - fence pieces inside the barn;
  - big forest trunks inside other trunks.
- **Moved:** ridge terraces cutting through cypress trunks were nudged clear, and the camp props were moved off the tents.
- **Backup:** everything removed is in `RenseiBackups["Pre-Settle_2026-10-20"]`.

### Halvard's Adit (`Art/Studio/HalvardsAdit/`)
- **Look:** the owner's teal mine reference.
  - Every cave wall and ceiling face is lined with angular slate blocks (about 1,500), with bigger tilted slabs on the ceiling.
  - Stepped stone ledges run along both sides of the entrance tunnel, keeping the rails clear.
  - There is loose rubble along the edges, and crossing chains under the ceiling of the lift hall, the sump and the lab.
  - Every hanging lantern has a chain above it.
- **Clearances:** puzzle pieces, doors and lights all keep 3.5 studs of clearance. No mechanism moved.
- **Lighting:**
  - a teal fill and warm orange pools at the lanterns (`adit_warm.lua`);
  - both sit inside Attachments, so LightService (stealth) doesn't count them;
  - the floors are teal-grey, and `Lighting.Ambient` is teal.
- **Re-running:** `adit_dress.lua` read the cave from terrain voxels before the terrain went, so it must **not** be re-run. `adit_warm.lua` can be.

### Tested (Play in Ye)
- Spawn on the square.
- Both lanes, the road over the bridge to the hub road, square to farm, and into the camp.
- The workshop hill path, on foot with no jumping.
- The Adit tunnel to the lift hall, and around the lab.
- Swimming in the Mill Pond.
- Canopy shade (exposure 0.35 under it against 1.00 in the open), and the gorge ledge unchanged.
- The owner also walked the routes ("All of the walks are clear").
- The owner's profile was snapshotted and restored, and the temporary hook was deleted.

## Studio tooling note (2026-10-20, World Plan 1 Task 3)
- Server code now lives in `ServerStorage.RenseiServer`. In Edit mode, edit server scripts there, not in ServerScriptService.
  - `ServerScriptService.RenseiBoot` clones every `RenseiServer` child into ServerScriptService at server start (ModuleScripts and Folders first), so `ServerScriptService.<Name>` paths still work at runtime.
  - Source: `Art/Studio/Travel/src/RenseiBoot.lua`; the one-time move: `Art/Studio/Travel/boot_move.lua`; backup: `RenseiBackups["Pre-WorldPlan1_2026-10-20"].SSS`.
  - The Play test profile hook (`Art/Studio/Travel/test_hook.lua`) now installs `LMTestHook_TEMP` into `ServerStorage.RenseiServer`; delete it there after the tests.
  - Edit-mode `Test_` suites must require server modules from `ServerStorage.RenseiServer` (or resolve from either place, e.g. `game.ServerScriptService:FindFirstChild("X") or game.ServerStorage.RenseiServer.X`), because ServerScriptService only holds RenseiBoot in Edit mode.

## Studio tooling note (2026-10-23, World Plan 1 Task 11)
- **The Play test hook** (`Art/Studio/Travel/test_hook.lua`, now the version every World Plan 1 test used) installs `LMTestHook_TEMP` into **ServerScriptService** (RenseiServer is a Package now), not RenseiServer. It adds `ServerStorage.LMRunSuite`, which runs a `Play_` suite in the game's own VM: call `game.ServerStorage.LMRunSuite:Invoke("Play_Station")` from the Server datamodel once `ServerStorage:GetAttribute("LMSnapTaken")` is set. Then `LMTestHook:Invoke("restore")`, Stop, and delete `LMTestHook_TEMP` in Edit mode.
  - The hook's `diff` compares tables as JSON, so it still lists keys after a restore when their contents only iterate in a different order. It can't confirm a restore.
- **The travel suites run in both Ye and Foundry Yard.** `ServerStorage.RenseiTests` in Foundry holds TestKit and the seven travel Play suites, copied from `Art/Studio/Travel/src/`. Play_Road maps its fixed spots from Lindenmoor's North Road onto whichever road the place has; the two roads are the same shape, turned a quarter.
- **Screenshots:** the Studio MCP's `screen_capture` returns the image as JPEG data. `rbxc.py call screen_capture` only prints `[ image ]`, so save it by decoding the tool result's image content (base64) to a `.jpg`. With `camera_position` and `look_at_position` it works in Edit mode; without them, in Play, it captures the player's view and the UI.

## Expansion (Blender, 2026-10-23): Lindenmoor fills its 2,048 × 2,048 footprint

**Owner:** asked for the Lindenmoor expansion to be built in Blender alongside the region foundation. They approved the layout ("Yes, build it"), chose "Plan as if it's gone" for the hub graybox, and chose "Together, NE corner" for the exits. The design is `Documents/specs/2026-10-23-lindenmoor-expansion-design.md`. The owner approved the renders on 2026-10-23: "The expansion renders look good. Approved for a later Studio import." Then: "Start importing after the townspeople tasks are done", using the foundation import tools, with the hub's pieces moved into the new map. It is **Blender only**: nothing has gone into Ye yet. Every number is a **PROPOSAL**.

![Map](images/Regions/Lindenmoor/Lindenmoor%20expansion%20-%20map.png)
![Aerial](images/Regions/Lindenmoor/Lindenmoor%20expansion%20-%20aerial.png)

The map is drawn as the brief draws it: north at the bottom, east on the right, which is Studio's top-down view. The street-level renders are in `images/Regions/Lindenmoor/Lindenmoor expansion - *.png`:
- farmsteads, mill creek, mine approach, gorge ledge, lookout and Bramble woods;
- training field, ridge marker, cypress overlook, north meadows and northeast gap.

### What was built
- **Around the fixed village:**
  - four farmsteads and a roadside market in the south-west, with a watermill, a stone viaduct and the creek running on west to a spring;
  - the mine approach above Halvard's Adit;
  - Mill Creek's gorge east to a waterfall, with a second `RenseiLedge` walk, a footbridge and the lookout;
  - Bramble woods in the south-east;
  - the training field and the ridge marker where the hub was, with patchwork crop fields, orchards and hay barns in the north meadows;
  - the Cypress Ridge rim with three overlooks in the north-west;
  - the north road and the rails side by side to tunnel portals in the north-east gap.
- **Reserved spots** for the hub's pieces: five trainer spots in the training field, and flat, clear pads for each trial site, the Foundry graybox and the ledge course (design note §5).
- **Edges:** forested ridges rise to a sheer crag (crest y 150–195), more than a stamina bar can climb. There are no invisible walls.
- **Ground:** the approved stepped part ground, with merged mossy slabs over stone sides and dirt ramps where routes climb. New ground blends to the village's edge heights; nothing is built on the village's own ground.
- **Part count:** **40,414** exported parts, against the expansion ceiling of 42,000:

  | Group | Parts |
  |---|---|
  | Ground | 25,038 |
  | Forest | 11,023 (1,363 trees) |
  | Farmsteads | 1,423 |
  | Fields | 1,323 (43 fields) |
  | Routes | 777 |
  | Edging | 274 |
  | Gorge | 115 |
  | Training | 90 |
  | Mine | 81 |
  | Landmarks | 68 (plus 56 preview-only survey stakes, not exported) |
  | Meadows | 68 |
  | Markers | 42 |
  | Lamps | 40 |
  | Gap | 40 |
  | Bridges | 12 |

  With Ye's existing ~30.5k (village, ground, Adit dressing, trains; needs a Studio count), the place comes to about 71k against an 80k ceiling. The hub pieces moved onto the reserved spots are already part of that ~30.5k.

### Files
- `Art/Regions/Lindenmoor/layout.json`: the region file, in world studs (x east, z north), in the region-foundation Task 8 format. Its `Notes` list the extensions: `Materials`, `Keep`, `Infill`, channel cuts and water, `Crag`, and patchwork fields.
- `Art/Regions/Lindenmoor/water_segments.json`: the channel water as the plan carves it, one `{Id, From, To, Width, Top, Bed}` segment per channel leg, in world studs (surface y 5.2). `expansion.water()` writes it.
- `Art/Regions/Lindenmoor/water.json`: the same water in `kit.py`'s format: axis-aligned `Rect` boxes in the village's local frame (world − (0, 4, −650); `finish.lua` adds the origin back). `Art/Blender/lindenmoor/water_convert.py` makes it from `water_segments.json`: each segment is a capsule, filled with 2-stud cells and merged into rects (spill ≤ 15% of the capsule's area). Re-run the converter after every `water` stage.
- `Art/Blender/lindenmoor/expansion_plan.py`: the pure planner, with no bpy.
- `Art/Blender/lindenmoor/expansion_tests.py`: 114 checks on the plan, including:
  - no ground on the village, nor on any cell holding a village `Ground` part (the Keep mask is one cell wider than the village terrain; `expansion_plan.keep_mask()`, shared with `check_survey.py`);
  - the edge crag's tops and sides flagged `crag` (tagged `RenseiNoGrip`), on every edge;
  - no holes;
  - a continuous crag at least 80 studs above the ground beside it;
  - route grades and continuity;
  - the rails meeting Ye's rail top;
  - the ledge's wall;
  - water beds, and `water.json` covering each channel (`water_convert.py`);
  - markers;
  - non-overlapping areas;
  - level, clear fields;
  - trees clear of routes;
  - the road passage length;
  - flat, clear reserved spots;
  - the budget.

  Run `python -I Art/Blender/lindenmoor/expansion_tests.py`.
- `Art/Blender/lindenmoor/expansion.py`: the Blender stages. Run them through `Art/Tools/blender_mcpc.py code @file.py`:
  - `run("village")` once (`world.py`'s village plus a stepped preview of its ground, linked in for renders);
  - then `run("all")` or single stages: `ground, water, routes, fields, landmarks, trees, markers, lighting`;
  - then `render_all()`, `count()` and `save()`.
- `Art/Blender/Regions/Lindenmoor_Expansion.blend` (not committed): scenes `Lindenmoor_Expansion` (the build) and `Lindenmoor_Full` (the village preview, never exported).
- `world.py`, `core.py` and `export.py` are unchanged.

### Notes on the pipeline
- **Mirrored renders:** the Blender frame is a mirror image of Roblox's (export maps Roblox (X, Y, Z) to Blender (x, z, y)). The expansion's renders are therefore flipped to show the place as Studio will: perspective shots left-right, the map top-bottom. The older village renders were not flipped.
- **Slow deletes:** removing tens of thousands of objects one at a time takes Blender most of an hour. `expansion.clear()` uses `bpy.data.batch_remove`.
- **Slow stages:** stages over five minutes outlive `blender_mcpc.py`'s 300 s wait, but Blender finishes them anyway. Watch for the output file or the saved `.blend` instead.

### Importing later (main session)
**When (owner, 2026-10-23, 2026-10-24):** first after the region foundation, with its import tools, not a one-off import. The hub's pieces are **moved into the new map**, not removed; the design note §5 lists each piece's reserved spot.

The tools and the order are now in two places:
- **How the tools work:** `Documents/Region Builder.md` (§4 the import: `kit.py`, the dry run, `finish.lua`, `restore.lua`, `unstrip.lua`; §5 `setup.lua`; §5b the Foundry smoke test).
- **What to check and do for Ye:** the checklist "Before the import into Ye" below, then "Rolling back".

In short:
1. **Measure Ye first:** the Baseplate's position (assumed the template's (0, −8, 0)); the part count; that `World.Map.Ground` has no parts in the layout's `Infill` cells; the seam heights where new ground meets the village (blended from `terrain_studio.json`'s 8-stud grid; the Adit hill's are estimates); that the new areas don't overlap the village's own.
2. **Back up, then retire** the old `NorthRoad` passage and its `RoadStart` arrival, the `HubRoad` strip and its sign, and the north buffer stop at world (−270, −369) (see "Rolling back" for how to back them up).
3. **Export** with `expansion.export_expansion(path)` to `Art/Studio/Regions/Lindenmoor/layout.json`. It carries the tags (row field 16, from the region-foundation tooling). The scene is built in the village frame, so `export.py`'s origin (0, 4, −650) is right as it is.
4. **Materials:** the expansion's materials (`LM_GrassGround`, `LM_GroundMeadow`, `LM_GroundSide`, `LM_Ballast`, `LM_Falls`, `LM_Foam`, `LM_Shadow`) go in `Art/Regions/Lindenmoor/materials.json` (`kit.py` reads it; their values are in the layout's `Materials`).
5. **Import:** `kit.py Lindenmoor --keep <village children> --map-child LindenmoorExpansion`, the chunks, a dry run in Ye (read its "would move / keep" line), then the real run. The real run refuses to run twice on one date. Water: see the checklist.
6. **Travel:** `setup.lua` with `--origin 0,0,0` for the `RoadPassage` marker (its five `TrainerSpot` markers are skipped), then the contract test and the travel suites, especially Play_Road, which maps fixed spots from today's North Road.
7. **Game data:** the 10 new `AreaName`s in `Rensei.Regions.Areas` → Lindenmoor; quests for the clues `lm_ridge_marker` and `lm_mine_shaft` (F4); a Lindenmoor townsfolk roster for the 18 posts (F3); check the 6 Grunt spawns are wanted. **HubLaw is an open owner question** (see the checklist): don't change it without asking.
8. **Play-test:** walk every route; try to climb the crag (it should fail); swim the creek and the gorge; walk the gorge ledge; check that the lamps' `NightOnly` heads follow the clock; check streaming with the full map.

## Region Foundation tooling note (2026-10-24)
The Region Foundation reused this pipeline for every region. Lindenmoor's own commands are unchanged, and its export is byte-for-byte the same. Its stored kit outputs were regenerated once with today's `studio_kit.py` (commit ee24b09). The full region how-to is `Documents/Region Builder.md`.

- **`export.py`** now takes optional arguments: `export(scene_name="Lindenmoor_Full", out_path=..., origin=(0, 4, -650))`. With no arguments it exports Lindenmoor exactly as before. A region passes its scene, its output path and origin `(0, 0, 0)`.
  - Part rows can carry **field 16**: comma-separated CollectionService tags, from a Blender object's `rs_tags`.
  - When a part has any of `rs_invisible`, `rs_attr` or `rs_tags`, it gets all three fields (14 = 0/1, 15 = `""` with no attributes, 16 = `""` with no tags). Rows without them stay at 13 fields, so Lindenmoor's export is byte-for-byte the same.
- **`studio_kit.py`** gained region arguments: `main(folder, region={...})`, called by `Art/Studio/Regions/kit.py`. The command line is unchanged. In a region run:
  - the chunks build into `ServerStorage.RegionStaging`;
  - field 16 tags are added;
  - materials come from the region's `materials.json`, and texture-pack entries become MaterialVariants;
  - the region's own walk-through name list is used.
- **The `""` guard:** `studio_kit.py` (both the Python and the generated Lua) treats an empty field 15 as "no attributes", so a marker with tags but no settings imports instead of failing.

### Before the import into Ye
The order after the foundation is: this import first, then the Foundry Yard plan, then the gun and swimming reworks (owner, 2026-10-24: "I want the lindenmoor expansion to go first after foundation"). The village stays at its coordinates, and the expansion goes in around it. Check each item before the import plan is written:

- [ ] **water.json format and frame.** `Art/Regions/Lindenmoor/water.json` uses the expansion's segment format (`{Id, From, To, Width, Top, Bed}`, world studs). `kit.py` needs `{"Boxes": [{"Rect": [x0, z0, x1, z1], "Top", "Bed"}]}`, and `finish.lua` adds the export's origin `(0, 4, -650)` to every box. So the converter must write **village-local** coordinates: world − (0, 4, −650), that is x, z + 650, and Top and Bed − 4. (9 of the 13 segments are diagonal: split them into thin strips, or a rotated box; an axis-aligned bounding box adds about 28% more water. Import-plan work.)
- [ ] **Keep and MapChild.** Lindenmoor's `layout.json` is not a region-builder file (it has 31 schema errors, and its `Keep` is a list of area objects). Generate the import with `python -I Art/Studio/Regions/kit.py Lindenmoor --keep <village children> --map-child LindenmoorExpansion`, or add `KeepMapChildren` and `MapChild` to the file. Export the expansion scene to `Art/Studio/Regions/Lindenmoor/layout.json`.
- [ ] **Walk-through decoration.** `kit.py Lindenmoor` uses the village's own walk-through lists by default (`studio_kit.NO_COLLIDE`: `Tuft`, `Crop`, `Vine`, `Lantern`, … and the `EdgeStone` kind), so the 274 verge stones, the crop rows, tufts, vines and lanterns stay walk-through. Check the dry run's "walk-through names [...] kinds [EdgeStone]" line.
- [ ] **Separate top-level map children.** Check in Studio that the village, its ground, Halvard's Adit dressing and the trains are separate top-level `World.Map` children from the hub graybox. Everything kept must be in `--keep`. **Do a dry run in Ye first and read its keep line:** it lists exactly which `World.Map` children the real run would move into the backup and which it would keep, and fails on a keep name that isn't there (or names `LindenmoorExpansion`). Only the hub graybox children may be on the "move" side.
- [ ] **The hub pieces and the keep list.** The hub graybox children are **not** kept: the real run moves them into its backup, `RenseiBackups["Pre-Region_Lindenmoor_<date>"]`, tags stripped. Afterwards, place the trainers onto the five `TrainerSpot` markers and each trial site (with its arena, `RenseiArea`, spawns and markers) onto its `lindenmoor.reserve` pad: drag each piece out of the backup into `World.Map`, then run `unstrip.lua` on it (its `PATH`, or the attribute `RegionKitUnstrip = true`) to give its tags back. Measure each footprint against its pad first. **Never publish while a trial site is still in the backup** (out of `workspace`, its trial can't start).
- [ ] **Retire the old north road.** The expansion moves the road exit to the north-east corner. Before the expansion's `RoadPassage` is built (it carries the RoadStart arrival), retire `Map.Lindenmoor`'s old `NorthRoad` passage and its `RoadStart` arrival, with a backup. `setup.lua` refuses a second RoadStart in the place. Also retire the `HubRoad` strip and the north buffer stop (step 2 above).
- [ ] **`setup.lua`'s `ORIGIN` is `(0, 0, 0)`** (`bundle_setup.py setup ... --origin 0,0,0`, the default). Lindenmoor's marker attributes are in world studs: the RoadPassage `Legs` start at `[686, 661]`, its marker's own `At`. ORIGIN is non-zero only when marker attributes are in region coordinates. (With `(0, 4, -650)` the road would be built 650 studs off, at z 11..350, 4 studs high, in North Meadows.) Water is the opposite case: see "water.json format and frame".
- [ ] **TrainerSpot markers.** `setup.lua` skips the five `TrainerSpot` markers and lists them in its summary ("skipped (not travel pieces): TrainerSpot 5"). Any other unknown `Piece` is still refused.
- [ ] **Watch the first real runs.** `finish.lua`'s real swap and `setup.lua`'s real mode have run for real only in Foundry (the smoke test, 2026-10-24: a Testbed import, played, restored, Foundry left exactly as before). Do the Ye dry run first. `finish.lua` and `restore.lua` record their swap with ChangeHistoryService when Studio allows it; through the Studio bridge, each run is already one Undo step. Check the place-wide one-arrival scan doesn't trip on unrelated duplicates already in Ye.
- [ ] **No Station marker.** The station stays in the village. The expansion must not carry a `Station` marker, or `setup.lua` refuses a second Platform arrival and platform train.
- [ ] **`RenseiNoGrip` on the crag.** The crag must carry the tag (on its parts or its model). The import's dry run should show the tag on the crag. Tell the owner first: a boundary vault, or a leap with no hold, can't chain over an all-tagged wall.
- [ ] **Part budget.** Count Ye's parts in Studio. The estimate is ~30.5k today plus ~40.4k for the expansion, against the place's 80k ceiling. `kit.py` refuses an export over the file's `Budget` (42,000).
- [ ] **Open: HubLaw.** This doc's step 7 says to set `Regions.HubLaw` for Ye to Lindenmoor once the hub is gone. But the owner chose "Keep State law" for Ye's unnamed ground (2026-10-23). **Ask the owner before changing it.**
- [ ] **New areas against the village's.** `WorldService.AreaAt` returns the first tagged match. Check in Studio that the 10 new `RenseiArea` boxes don't overlap the kept village's own areas.

### Rolling back the import in Ye
`restore.lua` undoes **`finish.lua` only**:
- it moves `World.Map.LindenmoorExpansion` (with `Travel`, the road `setup.lua` built, and any edits) into `RenseiBackups["Post-Region_Lindenmoor_<date>"]`, tags stripped;
- it puts back every `World.Map` child the real run moved (the hub graybox), with its tags;
- it puts back any MaterialVariant the import replaced, and pastes back the terrain under the water boxes.

It does **not** bring back what was retired **by hand** before the import: the old `NorthRoad` passage and its `RoadStart` arrival, the `HubRoad` strip and its sign, and the north buffer stop. After `restore.lua` alone, Ye has **no RoadStart arrival**, so the road journey from Foundry fails (`TravelService.ArrivalPoint` returns nil). Nor does it undo hub pieces you already dragged onto their pads, or data edits.

**Before retiring anything**, back each piece up: put a clone in `ServerStorage.RenseiBackups["Pre-LindenmoorExpansion_<date>"]`, keeping its path (e.g. `Lindenmoor/Travel/NorthRoad`), and only then remove the original.

**To roll back**, in this order:
1. Run `restore.lua` (Edit, Ye).
2. Put the hand-retired pieces back from `Pre-LindenmoorExpansion_<date>`: drag each clone back to its old parent (`NorthRoad` with its `RoadStart` arrival, encounters and threshold; the `HubRoad` strip and sign; the buffer stop). A clone keeps its tags, so nothing needs `unstrip.lua`. Check there is exactly one `RenseiArrival` with `Point = "RoadStart"` in the place.
3. Hub pieces you already dragged out of the backup onto their pads are no longer in the backup, so `restore.lua` leaves them where they are: move each back to its hub spot by hand (`unstrip.lua` already gave its tags back). Pieces still in the backup come back with `restore.lua`.
4. Revert any data edits (`Rensei.Regions.Areas`, `HubLaw`, the roster, clue quests).
5. Re-run the travel suites (Play_Road, Play_Travel) before the owner publishes.

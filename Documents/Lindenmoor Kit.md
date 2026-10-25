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
- **The travel suites run in both Ye and Foundry Yard.** `ServerStorage.RenseiTests` in Foundry holds TestKit and the seven travel Play suites, copied from `Art/Studio/Travel/src/`. Play_Road maps its fixed spots from Lindenmoor's North Road onto whichever road the place has; the two roads are the same shape, turned a quarter. *(2026-10-24, import plan Task 7: Ye's road is now the expansion's north-east road, a different shape, so Play_Road reads every spot from the built road itself; see "Travel setup" below.)*
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
- `Art/Blender/lindenmoor/expansion_tests.py`: 116 checks on the plan, including:
  - no ground on the village, nor on any cell a village `Ground` part covers (the Keep mask is the village terrain plus the footprint of Ye's `Ground` and `HalvardsAdit` parts, measured by the Ye survey; the Adit's Keep Rect is kept only where those parts are; `expansion_plan.keep_mask()`, shared with `check_survey.py`);
  - a closed seam: every cell along the village boundary has village ground or new ground;
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

- [x] **water.json format and frame.** *(Done: import plan Task 3, `water_convert.py`; 218 boxes filled by the real run, 2026-10-24.)* `Art/Regions/Lindenmoor/water.json` uses the expansion's segment format (`{Id, From, To, Width, Top, Bed}`, world studs). `kit.py` needs `{"Boxes": [{"Rect": [x0, z0, x1, z1], "Top", "Bed"}]}`, and `finish.lua` adds the export's origin `(0, 4, -650)` to every box. So the converter must write **village-local** coordinates: world − (0, 4, −650), that is x, z + 650, and Top and Bed − 4. (9 of the 13 segments are diagonal: split them into thin strips, or a rotated box; an axis-aligned bounding box adds about 28% more water. Import-plan work.)
- [x] **Keep and MapChild.** *(Done: import plan Task 4, the region file's `KeepMapChildren` and `MapChild`.)* Lindenmoor's `layout.json` is not a region-builder file (it has 31 schema errors, and its `Keep` is a list of area objects). Generate the import with `python -I Art/Studio/Regions/kit.py Lindenmoor --keep <village children> --map-child LindenmoorExpansion`, or add `KeepMapChildren` and `MapChild` to the file. Export the expansion scene to `Art/Studio/Regions/Lindenmoor/layout.json`.
- [x] **Walk-through decoration.** *(Checked: the Ye dry run, 2026-10-24.)* `kit.py Lindenmoor` uses the village's own walk-through lists by default (`studio_kit.NO_COLLIDE`: `Tuft`, `Crop`, `Vine`, `Lantern`, … and the `EdgeStone` kind), so the 274 verge stones, the crop rows, tufts, vines and lanterns stay walk-through. Check the dry run's "walk-through names [...] kinds [EdgeStone]" line.
- [x] **Separate top-level map children.** *(Checked: the Ye dry run's keep line, 2026-10-24: move nothing, keep all 23.)* Check in Studio that the village, its ground, Halvard's Adit dressing and the trains are separate top-level `World.Map` children from the hub graybox. Everything kept must be in `--keep`. **Do a dry run in Ye first and read its keep line:** it lists exactly which `World.Map` children the real run would move into the backup and which it would keep, and fails on a keep name that isn't there (or names `LindenmoorExpansion`). Only the hub graybox children may be on the "move" side.
- [x] **The hub pieces and the keep list.** *(Superseded, 2026-10-24: every hub piece is kept; `prep_ye.lua` moved them onto their pads before the import, so nothing went into the backup. See "The import into Ye" below.)* The hub graybox children are **not** kept: the real run moves them into its backup, `RenseiBackups["Pre-Region_Lindenmoor_<date>"]`, tags stripped. Afterwards, place the trainers onto the five `TrainerSpot` markers and each trial site (with its arena, `RenseiArea`, spawns and markers) onto its `lindenmoor.reserve` pad: drag each piece out of the backup into `World.Map`, then run `unstrip.lua` on it (its `PATH`, or the attribute `RegionKitUnstrip = true`) to give its tags back. Measure each footprint against its pad first. **Never publish while a trial site is still in the backup** (out of `workspace`, its trial can't start).
- [x] **Retire the old north road.** *(Done by `prep_ye.lua` apply, 2026-10-24, into `Pre-LindenmoorExpansion_2026-10-24`.)* The expansion moves the road exit to the north-east corner. Before the expansion's `RoadPassage` is built (it carries the RoadStart arrival), retire `Map.Lindenmoor`'s old `NorthRoad` passage and its `RoadStart` arrival, with a backup. `setup.lua` refuses a second RoadStart in the place. Also retire the `HubRoad` strip and the north buffer stop (step 2 above).
- [x] **`setup.lua`'s `ORIGIN` is `(0, 0, 0)`** *(Run with `--origin 0,0,0`, 2026-10-24: the road starts at (686, 661), see "Travel setup" below.)* (`bundle_setup.py setup ... --origin 0,0,0`, the default). Lindenmoor's marker attributes are in world studs: the RoadPassage `Legs` start at `[686, 661]`, its marker's own `At`. ORIGIN is non-zero only when marker attributes are in region coordinates. (With `(0, 4, -650)` the road would be built 650 studs off, at z 11..350, 4 studs high, in North Meadows.) Water is the opposite case: see "water.json format and frame".
- [x] **TrainerSpot markers.** *(The summary said "skipped (not travel pieces): TrainerSpot 5", 2026-10-24.)* `setup.lua` skips the five `TrainerSpot` markers and lists them in its summary ("skipped (not travel pieces): TrainerSpot 5"). Any other unknown `Piece` is still refused.
- [x] **Watch the first real runs.** *(`finish.lua`'s real swap ran in Ye on 2026-10-24, and `setup.lua`'s real mode the same day (import plan Task 7); see below. The place-wide one-arrival scan found no clash.)* `finish.lua`'s real swap and `setup.lua`'s real mode have run for real only in Foundry (the smoke test, 2026-10-24: a Testbed import, played, restored, Foundry left exactly as before). Do the Ye dry run first. `finish.lua` and `restore.lua` record their swap with ChangeHistoryService when Studio allows it; through the Studio bridge, each run is already one Undo step. Check the place-wide one-arrival scan doesn't trip on unrelated duplicates already in Ye.
- [x] **No Station marker.** *(Checked: the import carries 6 `RenseiMarker`s, RoadPassage 1 + TrainerSpot 5.)* The station stays in the village. The expansion must not carry a `Station` marker, or `setup.lua` refuses a second Platform arrival and platform train.
- [x] **`RenseiNoGrip` on the crag.** *(Done: 2,141 tagged crag parts, checked by the dry run and in Ye; the owner chose ungrippable edges.)* The crag must carry the tag (on its parts or its model). The import's dry run should show the tag on the crag. Tell the owner first: a boundary vault, or a leap with no hold, can't chain over an all-tagged wall.
- [x] **Part budget.** *(Counted 2026-10-24: 71,593 workspace BaseParts after the import, under 80k.)* Count Ye's parts in Studio. The estimate is ~30.5k today plus ~40.4k for the expansion, against the place's 80k ceiling. `kit.py` refuses an export over the file's `Budget` (42,000).
- [x] **HubLaw.** *(Done: import plan Task 8. The owner chose "Lindenmoor's (Recommended)" for Ye's unnamed ground, 2026-10-24, so `Regions.HubLaw = {[Ye] = "Lindenmoor"}`.)* This doc's step 7 says to set `Regions.HubLaw` for Ye to Lindenmoor once the hub is gone. But the owner chose "Keep State law" for Ye's unnamed ground (2026-10-23). **Ask the owner before changing it.**
- [x] **New areas against the village's.** *(Done: import plan Task 8. `WorldService.AreaAt` now returns the smallest containing box, with a name tie-break, and only boxes in `workspace` count; Play_LindenmoorData's AreaLookup checks it.)* `WorldService.AreaAt` returned the first tagged match. Check in Studio that the 10 new `RenseiArea` boxes don't overlap the kept village's own areas.

### Rolling back the import in Ye
`restore.lua` undoes **`finish.lua` only**:
- it moves `World.Map.LindenmoorExpansion` (with `Travel`, the road `setup.lua` built, and any edits) into `RenseiBackups["Post-Region_Lindenmoor_<date>"]`, tags stripped;
- it puts back every `World.Map` child the real run moved (the hub graybox), with its tags;
- it puts back any MaterialVariant the import replaced, and pastes back the terrain under the water boxes.

It does **not** bring back what was retired **by hand** before the import: the old `NorthRoad` passage and its `RoadStart` arrival, the `HubRoad` strip and its sign, and the north buffer stop. After `restore.lua` alone, Ye has **no RoadStart arrival**, so the road journey from Foundry fails (`TravelService.ArrivalPoint` returns nil). Nor does it undo hub pieces you already dragged onto their pads, or data edits.

**Before retiring anything**, back each piece up: put a clone in `ServerStorage.RenseiBackups["Pre-LindenmoorExpansion_<date>"]`, keeping its path (e.g. `Lindenmoor/Travel/NorthRoad`), and only then remove the original.

**Superseded for the 2026-10-24 import:** the retired pieces went into the backup through `prep_ye.lua`, so its `undo` replaces step 2 below. Use the order in "The import into Ye" → "Rollback".

**To roll back**, in this order:
1. Run `restore.lua` (Edit, Ye).
2. Put the hand-retired pieces back from `Pre-LindenmoorExpansion_<date>`: drag each clone back to its old parent (`NorthRoad` with its `RoadStart` arrival, encounters and threshold; the `HubRoad` strip and sign; the buffer stop). A clone keeps its tags, so nothing needs `unstrip.lua`. Check there is exactly one `RenseiArrival` with `Point = "RoadStart"` in the place.
3. Hub pieces you already dragged out of the backup onto their pads are no longer in the backup, so `restore.lua` leaves them where they are: move each back to its hub spot by hand (`unstrip.lua` already gave its tags back). Pieces still in the backup come back with `restore.lua`.
4. Revert any data edits (`Rensei.Regions.Areas`, `HubLaw`, the roster, clue quests).
5. Re-run the travel suites (Play_Road, Play_Travel) before the owner publishes.

## The import into Ye (2026-10-24, import plan Task 6)
The expansion is in Ye (placeId 106992859583940) as `World.Map.LindenmoorExpansion`. The owner confirmed the real run in chat: "Yes, import it (Recommended)". Everything ran in Edit through the Studio bridge, and Play was never started. **Don't publish the Ye place until the import plan's Task 9 checkpoint.**

### What ran, in order
1. **Pre-check:** Ye was in Edit, with no `PlayLock`, no `LindenmoorPrep`, no prep backup and no `RegionStaging`. `World.Map` had 23 children, and the workspace had 31,998 BaseParts.
2. **`prep_ye.lua` apply.** The bundle was built fresh with `bundle_prep.py prep <out> apply`. Its `PADS_HASH` `ca265648` matches `pads.json`'s sha256.
   ```
   LindenmoorPrep apply OK: moved 43, retired 5, trainers 5 (blocks 13, spawns 5, elite 1, lifted 4; pads.json ca265648)
   ```
   - **Lifted:** `SpawnLocation`, `StarterCharacterMeca` `arm` and `arm2`, and `Carry & Grip Stuff`, each from y 0.00 to 4.05.
   - **Retired** into the backup: `NorthRoad`, `HubRoad`, `BufferStop` and two `GruntSpawn`s, 1,050 parts in all.
3. **Staging:** `import/chunk_01..31.lua`, giving 1,734 models and 40,645 parts. The bridge dropped once, on chunk 13. The chunk had already run, and it was re-run safely.
4. **Dry run** (`DryRun = true`):
   ```
   dry run ok: Lindenmoor: 1734 models, 40645 parts, 15 groups; tags RenseiArea=10 RenseiClue=2 RenseiEnemySpawn=6 RenseiLedge=1 RenseiMarker=6 RenseiNoGrip=2141 RenseiPost=18; markers 42 (0 queryable, 0 touchable); … a real run would move nothing into the backup, keep [all 23, both Walls], and build Map.LindenmoorExpansion | variants 0/0 present …; staging removed
   ```
5. **Re-staged:** all 31 chunks ran again.
6. **Real run** (`Confirm = "Lindenmoor"`):
   ```
   finish: Lindenmoor built into workspace.World.Map.LindenmoorExpansion (1734 models, 40645 parts; tags RenseiArea=10 RenseiClue=2 RenseiEnemySpawn=6 RenseiLedge=1 RenseiMarker=6 RenseiNoGrip=2141 RenseiPost=18); moved to RenseiBackups.Pre-Region_Lindenmoor_2026-10-24: nothing; kept: [all 23]; 0 tagged instances stripped; MaterialVariants added none; 218 water boxes filled (terrain snapshots in the backup); undo: the caller's recording (a recording is already open); undo with import/restore.lua
   ```
7. **Verified:**
   - The workspace has **71,593 BaseParts**: 30,948 after the prep plus 40,645.
   - The expansion's tags equal `expected.json`, with 14 lights.
   - Terrain reads **Water** at the centrelines of `creek_west_water_1`, `creek_west_water_4`, `gorge_water_3` and `gorge_water_5`.
   - There are **0** `RoadStart` arrivals in `workspace` (import plan Task 7 builds the new one), and exactly 1 `Platform` arrival.
   - `RegionStaging` is gone, and `LindenmoorPrep = "applied"`.

### Backups
- **`ServerStorage.RenseiBackups["Pre-LindenmoorExpansion_2026-10-24"]`** (from `prep_ye.lua`) holds the 5 retired pieces: `NorthRoad`, `HubRoad`, `BufferStop`, and `GruntSpawn` ×2. Each one records its old parent. Every moved instance records its old CFrame in `LindenmoorPrepFrom` (43 instances).
- **`ServerStorage.RenseiBackups["Pre-Region_Lindenmoor_2026-10-24"]`** (from `finish.lua`) holds no map children, because everything was kept. It does hold the terrain snapshots under the 218 water boxes, and `restore.lua` reads it.

### Seam fillers (Ruling 20)
Three openings in the **village's** ground faced the new ground. Village side parts stop above the floor, leaving a hollow under the village ground; the new ground doesn't build on village footprint cells, so it can't close them. They are closed by anchored, collidable Slate parts in **`World.Map.LindenmoorExpansion.SeamFillers`**. They sit inside the expansion so that `restore.lua` carries them into the `Post-Region` backup with it. Each part has the attribute `SeamFiller = "Ruling 20"`. Sizes and heights are measured from the live parts.

| Part | Position | Size | Closes |
|---|---|---|---|
| `Filler_West` | (−334, 7, −518) | 4 × 12 × 4 | The window in the village's west face at x −336, z −520..−516, y 1..13, under the Side that starts at y 13. Colour `3c3832`. |
| `Filler_Slit` | (−336.5, 29.05, −507.5) | 1 × 2.3 × 9 | The slit at x −336, z −512..−503, y 28..30, between the village top (28) and the new side's bottom (30). Colour `423c34`. |
| `Filler_East_A` | (330, 1.5, −554) | 4 × 3 × 4 | The y 0..3 slit under the 18-stud creek bank at x 332, z −556..−552. Colour `484238`. |
| `Filler_East_B01..B09` | x 331.5, z −551.875 … −549.875 (0.25 steps); y from 0.9 up to 7.67 … 3.42 | 1 × (6.77 … 2.52) × 0.25 each | The face x 332, z −552..−549.75, from the floor up to just under the steep creek-bank ramp. Each slice's top is 0.05 below the ramp's underside, as measured. Colour `484238`. |

**Checked:**
- Horizontal rays through each opening now stop at the face: 0 of 494 get more than 0.5 stud past it.
- Downward rays over every filler find the same top surface as without the fillers, and never a filler (300 rays).
- No road or path part intersects a filler. `Filler_Slit` runs through a village oak's `Trunk` and `Root3` (`OakBig_Rim45`).
- **Left as it is:** a ~1-stud crack under the ramp edge at z −549.75..−548, y 0.9..2. It sits under the creek water, and a plate there would stand on the open creek-mouth floor.

### Travel setup: the north-west road (2026-10-24, import plan Task 7; "north-east" in the builder's x = east frame)
Run in Ye (Edit), after the Studio fixes (seam regrade, gorge, seam pits, bed):
```
python -I Art/Studio/Regions/bundle_setup.py setup <scratch>/setup.lua --region Lindenmoor --map-child LindenmoorExpansion --origin 0,0,0
python -I Art/Tools/rbxc.py luau "placeId: 106992859583940" Edit @<scratch>/setup.lua
```
```
setup ok (Map.LindenmoorExpansion): Workspace.World.Map.LindenmoorExpansion.Travel from 1 markers (RoadPassage 1), 1592 parts; stations none; roads: RoadLindenmoorFoundry 368 studs, 533 slabs, 48 trees, 8 rocks, 3 encounters; tags: RenseiArrival 1, RenseiRoadEncounter 3, RenseiRoadPassage 2, RenseiRoadThreshold 1; replaced old Travel: no; backup: none; skipped (not travel pieces): TrainerSpot 5
```
- **Contract test** (`workspace.World.Map.LindenmoorExpansion`, place-wide): before, PASS 15 / FAIL 5 (no RoadStart, no passage); after, **PASS 43 / FAIL 0**. The workspace has exactly one `RoadStart` arrival (`Travel.Road_RoadLindenmoorFoundry.Arrival_RoadStart`, at (806.9, 7.5, 938.7)) and one `Platform` arrival (the village's). The retired RoadStart in `Pre-LindenmoorExpansion_2026-10-24` is still tagged, but every lookup filters to `workspace`.
- **The road:** two straight legs, (686, 661) → (790, 860) → (820, 1000); RoadY 7, Half 22; threshold at s 359, RoadStart at s 305, encounters at s 85, 195 and 265. Leg boxes: leg 1 x 662..814, z 637..884; leg 2 x 766..844, z 836..1024.
- **On the ground?** Along s 0..216 the road (y 7) stands **3 studs above** the expansion's ground and route ribbons (y 4; 1.5..2.6 from s 200 to 216). From s 224 to 344 it is 0.7..1 above (ground 6). At s 352 it is 0.4 below, and at s 360, just past the threshold, 2.8 below (the ground rises to ~9.8). The road's slabs stop at FloorY 6, so 272 of its 533 columns leave a **2-stud hollow** over the y 4 ground along leg 1. This is the plan's RoadY, not the seam regrade (the passage is hundreds of studs from both seams). Not changed here: setting the marker's `FloorY` to 3 (or its `RoadY` to 4) and re-running `setup.lua` would close it.
- **Play_Road** reads every spot from the built road now (RoadPoints by `S`, the leg boxes, the encounters and the threshold), not from a Lindenmoor frame. Ye: before the remap PASS 7 / FAIL 4; after, **PASS 11 / FAIL 0**. Play_Gate 13/0, Play_Station 20/0, Play_Arrive 5/0, Play_Boot 2/0; Play_Travel 5/2 (the known Cabin-ticket failures).
- **Foundry's copy** of Play_Road in its `RenseiTests` is still the old frame-mapped one; it works there (Foundry's road is still the old shape). The new one should also work there, but it hasn't been run in Foundry.
- **Rollback:** `restore.lua` carries `Travel` out with the expansion. To drop only the road, delete `LindenmoorExpansion.Travel` (setup made no backup: there was no old `Travel`).

### Rollback
**Superseded (import plan Task 9):** the Studio fixes, the road cut, the shelters and the names came after this. Use the full order in "The import is done" → "Rolling everything back" below. These two steps are its steps 9 and 10.

In Edit, never in Play:
1. **`import/restore.lua`.** It moves `LindenmoorExpansion` into `Post-Region_Lindenmoor_<date>`, along with its `SeamFillers` and any `Travel` built by `setup.lua`. It also pastes the terrain back under the water boxes.
2. **`prep_ye.lua` undo, from a fresh bundle:**
   ```
   python -I Art/Studio/Regions/Lindenmoor/bundle_prep.py prep <out.lua> undo
   python -I Art/Tools/rbxc.py luau "placeId: 106992859583940" Edit @<out.lua>
   ```
   It puts the 43 moved instances back where they were, returns the 5 retired pieces to their old parents, deletes `Pre-LindenmoorExpansion_2026-10-24` and clears `LindenmoorPrep`. Afterwards, check that there is exactly one `RenseiArrival` with `Point = "RoadStart"`.
3. **Re-run the travel suites** (`Play_Road`, `Play_Travel`) before the owner publishes. Also revert any data edits made after the import: `Rensei.Regions.Areas`, `HubLaw`, the roster, and the clue quests.

## The import is done (2026-10-24, import plan Task 9)
The Lindenmoor expansion is in Ye's Studio Edit session, tested, and **not live**. The counts below are measured; every design number elsewhere in this doc is a **PROPOSAL**.

**Compass (Ruling 38b).** Ye's north is **+Z**, so east is **−X**. This doc's builder sections and the layout files use the builder's frame (x = east), in which the road leaves to the "north-east". On Ye's compass, the one players see, the road and the rails leave Lindenmoor to the **north-west**. Ye's area names are **West Lookout** and **Northwest Gap**.

### Final part count
- **Workspace:** 76,373 BaseParts, against the place's 80,000 ceiling (76,372 at the final fix pass). It read 76,369 an hour earlier the same day; the 4 extra parts are inside the expansion (see "The unexplained parts" below).
- **`World.Map.LindenmoorExpansion`:** 45,425, including the north-west road's `Travel` (1,592).
  - The import itself brought 40,645.
  - The seam regrade, the seam pits, the gorge fix, the road cut and the shelter posts added the rest.
  - That is over the expansion's own 42,000 ceiling. Ruling 25 accepts it, because the binding limit is the place's 80,000.
- **The unexplained parts (final fix pass, read-only, 2026-10-24).** Every part is accounted for: the export's 40,645, minus 1,888 export parts now in the fix backups (Ground 1,848, Gorge 37, Routes 3), plus 4,940 parts the fixes built (each carries `LindenmoorSeamNew`, `LindenmoorSeamPitsNew`, `LindenmoorRoadCutNew`, `GorgeFixNew` or `LindenmoorShelterAdd`), plus `Travel` 1,592, `SeamFillers` 12, `SeamPitsFill` 95 and `SeamRegradeFill` 19, plus **10 parts with no provenance marker and no row in the export**. Those 10 are the drift. None is an exact copy (same CFrame and Size) of another part, and none carries a tag or an attribute. They look like Studio duplicates (Ctrl+D keeps the source's name), moved or resized by hand. No repo script makes unmarked parts with these names. **The owner added them by hand (2026-10-24); they stay.**

  | Group | Part | Copies (export had) | Where | Looks like |
  |---|---|---|---|---|
  | Gorge | `GorgeLedge_gorge_ledge` → `Gorge part` | 4 (0) | x 757..773, z −568.4, y 12..27, beside the footbridge's south end | Ground-material wall blocks (#4b392f), two of them tilted −22°: a hand patch of the south gorge wall |
  | Routes | `Route_creek_walk_west` → `Ribbon143` | 5 (1) | around (−611, 14, −488) | resized, re-tilted ribbon pieces |
  | Routes | `Route_market_road` → `Ribbon91` | 2 (1) | (−601.7, 12.2, −472.1), 13.8 × 16.3 × 18.1 | a resized ribbon block by the west creek |
  | Farmsteads | `Farmyard_farm_3` → `CartShaft` | 2 (1) | (−884.6, 25.0, −607.7), 5.3 studs from the original | a moved copy of the cart's shaft |

  The 71 exact-geometry pairs elsewhere in the expansion are the export's own corner fence posts (Farmsteads 24, Fields 45, Routes 2), each pair with two different names. Every `RenseiBackups.Pre-*` folder the plan made still holds what its script reported: Pre-SeamRegrade 1,631, Pre-SeamPits 3,093, Pre-RoadCut 207, Pre-LindenmoorExpansion 5 pieces, Pre-GorgeFix 44 pieces (the bridge's 37, Ribbon184 and 6 pit cells) with 2 terrain snapshots.
- **Attributes:**
  - the expansion carries `LindenmoorSeamRegrade`, `LindenmoorSeamPits`, `LindenmoorGorgeFix`, `LindenmoorGorgeBed`, `LindenmoorRoadCut`, `LindenmoorShelters` and `LindenmoorEastWest`;
  - `World.Map` has `LindenmoorPrep = "applied"`.

### Checklist
- [x] Orientation and keeping the village (Tasks 4–6).
- [x] Hub pieces moved onto their pads (Task 5).
- [x] Exits together in one corner (Task 7). That corner is north-west on Ye's compass.
- [x] Crag `RenseiNoGrip` (Task 2).
- [x] Water (Task 3, then the gorge fix).
- [x] Budget (above).
- [x] Areas: the smallest box wins (Task 8).
- [x] TrainerSpots (Tasks 5 and 7).
- [x] Old road retired (Task 5).
- [x] `ORIGIN (0, 0, 0)` (Task 7).
- [x] First real run watched (Task 6).
- [x] No Station marker (Task 4).
- [x] HubLaw (Task 8, the owner's answer).
- [x] Game data: areas, clues, the roster, shelters and spawns (Task 8).
- [x] Play tests (Tasks 7–9).

### Smoke test (`ServerStorage.RenseiTests.Play_LindenmoorSmoke`)
The repo copy is `Scripts/ServerStorage/RenseiTests/Play_LindenmoorSmoke.lua`. Run it in hooked Play through `LMRunSuite`. Before review it passed 7/0 in two of three sessions (the first was 6/1 on a test spot), under an older crag check that could not fail. After review fix round 1, with the stricter check, it passed 7/0 (with Play_NoGrip 6/0). With the crag tags taken off around one spot, it **failed**, as it must. At the final fix pass, with EnemiesStandInTheWorld added, it was 7/1 before the EnemyService fix and **8/0** after.

| Check | What it proves |
|---|---|
| CragCantBeGrabbed | On each of the four edges, the player stands at the crag's foot facing it. The wall in front is expansion Ground, within the server's reach, and `MovementState.Grippable` says no. The server refuses a climb and a wall run (`Refused:NoWall`). **Control:** with the crag's tags off for a moment, the same climb is accepted, and afterwards the tagged count is the same as before. |
| WaterIsReal | Terrain Water voxels, and a water surface at about 5.2, at three west-creek and three gorge centreline points. |
| LampsFollowTheClock | The expansion's 10 `NightOnly` lamps are all in WorldClock's set. Held at 23:00 they are lit, with their own material; held at 12:00 they are dark, with `DayMaterial`. The clock is held through `WorldClock.Hold` and put back afterwards. |
| TravelIsSingle | There is exactly one RoadStart arrival (on RoadLindenmoorFoundry, in the expansion's `Travel`), one Platform arrival, and one platform train for LindenmoorFoundry. `TravelService.ArrivalPoint` finds them. |
| LedgeWorks | The gorge's one `RenseiLedge` strip faces its wall: there is a wall 0.7 studs in front at both ends and in the middle, and nothing behind. |
| EveryTrialStarts | All five `RenseiTrial` markers are in workspace, one per trial, each with a known `TrialId` and its Begin Trial prompt. |
| TrainersCanBeTalkedTo | The five trainers (Calda, Veyra, Holt, Ansel and Brannoc) each have their `trainer_<element>` dialogue and a talk prompt, and stand within 6 studs of their TrainerSpot. |
| EnemiesStandInTheWorld | (Final fix pass.) Every enemy EnemyService has live has its Home spawn in `workspace`; no tagged spawn outside `workspace` has an enemy; every live enemy model is one of EnemyService's; a ray down from each spawn in use meets ground within 6 studs (PROPOSAL). Before the fix it **failed**: the two retired old-hub GruntSpawns in `Pre-LindenmoorExpansion_2026-10-24` kept their tag and spawned two Grunts at (−17, _, −70) and (26.5, _, −70). |

**Where the crag check stands.** Choosing the spot never reads the `RenseiNoGrip` tag:
- **The crag's foot** is the last expansion Ground cell before the ground rises more than 40 studs in one 2-stud step.
- **The wall in front** must be an expansion Ground part facing the player.
- **Skipped spots:** the test moves along the edge from s −400 only when the server's wall rays meet something grippable that *isn't* expansion Ground, such as a tree, a lamp or a rock. A tree is a fair climb.
- **What this means for the crag:** an untagged crag part, or a grippable Ground wall, is never skipped, so it fails the test. It failed with the tags off.
- **The +Z edge** uses s −360, because an oak trunk stands 3.5 studs off at s −400.

The four spots:
- (990, 48, −400);
- (−990, 54, −400);
- (−360, 54, 986);
- (−400, 38, −994).

**Travel suites in Ye, the same day:**
- **Passing:**
  - Boot 2/0, Gate 13/0 and Arrive 5/0;
  - Station 20/0 and Road 11/0. These are the d3606a5 versions, now installed in Ye too.
- **Failing only on the real save:** Travel 5/2 and RideEvents 8/1. The owner's real save holds a Cabin / Second ticket, so this is not a regression.
- **Also run:** NoGrip 6/0, Clock 5/0 and LindenmoorData 3/0.

### Rolling everything back
Do this in Edit, never in Play, in this order. Each Studio-fix script takes its mode on its `local MODE = ...` line:
- **`post_fixes.lua`, `east_west_names.lua`, `shelters.lua` and `bed_fix.lua`:** copy the file to a scratch folder and edit its MODE line there.
- **The generated scripts (`road_cut.lua`, `seam_pits.lua` and `regrade_seam.lua`):** do the same. Copy the committed file to a scratch folder and edit only its `local MODE = "apply"` line. **Never regenerate them with their `.py`**: the generator recomputes from the current survey and the current ground, so the new file would no longer match what was applied.
- **`gorge_fix.lua`:** use its bundler (step 7).
1. **`Art/Studio/Regions/Lindenmoor/post_fixes.lua`**, `MODE = "undo"` (Foundry Yard plan Task 4b). It puts `lm_lookout_seat`, `lm_haybarn_shelter`, `lm_farm4_field` and `lm_farm1_home` back where they were (inside the lookout's base, the hay barn, the farmhouse's stone floor and on the well's rim) and clears `LindenmoorPostFixes`. Nothing else depends on it.
   - After this step, Test_YePaths fails again (the four posts can't be stood at; farm4's walks fail). That is expected.
2. **`Art/Studio/Regions/Lindenmoor/east_west_names.lua`**, `MODE = "undo"`.
   - West Lookout and Northwest Gap go back to East Lookout and Northeast Gap.
   - The two area descriptions go back too.
   - `Rensei.Regions.Areas` and the tests still use the new names until step 11.
3. **`shelters.lua`**, `MODE = "undo"`. **At the same time, revert `Rensei.Townsfolk`** to its ce128ca text (`git show ce128ca:Scripts/ReplicatedStorage/Modules/Data/Rensei/Townsfolk.lua`): back up the current Studio copy, then set the old text as its Source.
   - **Why:** without that revert, the groundskeeper's night post `lm_field_shelter` no longer exists. `TownsfolkLogic.Validate` then refuses the roster, and **no Lindenmoor townsfolk spawn**.
   - After this step, Play_LindenmoorData's "a shelter within 150" check fails. That is expected.
4. **`road_cut.lua`**, `MODE = "undo"`. This also removes the mouth ramp.
5. **`bed_fix.lua`**, `MODE = "bedundo"`.
6. **`seam_pits.lua`**, `MODE = "undo"`. It refuses while the road cut is applied.
7. **`gorge_fix.lua`** `undo`: `python -I Art/Studio/Regions/Lindenmoor/bundle_gorge_fix.py fix <out.lua> undo`. It refuses while the road cut, the bed or the seam pits are applied.
8. **`regrade_seam.lua`**, `MODE = "undo"`. It refuses while the road cut, the seam pits or the gorge fix are applied.
9. **`import/restore.lua`.** It refuses, changing nothing, while the expansion still carries any of the seven fix flags (`LindenmoorSeamRegrade`, `LindenmoorSeamPits`, `LindenmoorGorgeFix`, `LindenmoorGorgeBed`, `LindenmoorRoadCut`, `LindenmoorShelters`, `LindenmoorEastWest`; the region file's `RestoreRefuseFlags`), so steps 2–8 come first. It does not check `LindenmoorPostFixes` (step 1 has no restore guard), so step 1 must already be done.
   - It moves `LindenmoorExpansion` into `Post-Region_Lindenmoor_<date>`, together with its `Travel`, its `SeamFillers` and the shelter posts.
   - It pastes the terrain back under the water boxes.
10. **`prep_ye.lua` undo, from a fresh bundle:** `python -I Art/Studio/Regions/Lindenmoor/bundle_prep.py prep <out.lua> undo`. Then check there is exactly one `RenseiArrival` with `Point = "RoadStart"`: the old North Road's.
11. **Revert the data and script files.** Take every Studio copy from `ServerStorage.RenseiBackups["Pre-LindenmoorImport_2026-10-24"]`. Backups are named `Rensei.<Module>`, `RenseiServer.<Service>`, `TownsfolkService.Mover`, `UI.<Module>` and `RenseiTests.<Suite>`. Back up each current copy, then set its Source from the backup.
    - **Never take `Rensei.Puzzles` or `UI.CompassUI` from git.** The repo copies at the plan's base, `2378b54`, were behind Studio:
      - Puzzles lacks `adit_boards` and the Breakable kind;
      - CompassUI lacks the `InTruth` line (no directions at the Gate).
      - Their Studio backups are the right text.
    - **Every other file below:** the Studio backup equals git at `2378b54` (checked by normalised hash, 2026-10-24). Either source works; the Studio backup is still preferred.
    - **Data modules:** Regions, Townsfolk, TownsfolkLogic, Quests, Dialogues, Investigation, Evidence and Puzzles.
    - **UI:** CompassUI and MasteryUI.
    - **Services:** WorldService (from `RenseiServer.WorldService`, the pre-import copy; the plain `WorldService` backup is Task 8's), TownsfolkService (from `RenseiServer.TownsfolkService`; `RenseiServer.TownsfolkService_Task8` is the copy from just before the final fix pass), TownsfolkService.Mover and MoralityService.
    - **EnemyService and CompassService** (`RenseiServer.EnemyService`, `RenseiServer.CompassService`): optional. Their backups are from before the final fix pass and equal git at `2378b54`. The workspace filter they lack is what keeps the retired GruntSpawns from spawning, so keep the fixed copies unless you need the exact pre-import text.
    - **Test suites:**
      - from their `RenseiTests.*` backups: Test_Regions, Test_TownsfolkLogic, Play_TownsfolkCrowd and Play_TownsfolkHurt;
      - Play_Road from `RenseiTests.Play_Road` (the pre-import copy, for the old North Road; `RenseiTests.Play_Road_Task7` is Task 7's);
      - Play_Station from `RenseiTests.Play_Station` (the copy from before d3606a5). That revert is optional: d3606a5's Play_Station behaves the same in Ye.
    - **Delete:** Play_LindenmoorData and Play_LindenmoorSmoke. They are new; the `RenseiTests.Play_LindenmoorData` backup is a Task 8 copy and `RenseiTests.Play_LindenmoorSmoke_Task9` a Task 9 copy, not pre-import ones.
12. **Run the travel suites:** Play_Boot, Gate, Arrive, Station, Road, Travel and RideEvents.

**A re-import brings the old names back.** The kit files (`Art/Studio/Regions/Lindenmoor/layout.json` and `import/chunk_*.lua`) still say East Lookout and Northeast Gap. After any re-import from them, re-apply `east_west_names.lua` with `MODE = "apply"`, then `post_fixes.lua` with `MODE = "apply"` (the kit's chunks still put `lm_lookout_seat`, `lm_haybarn_shelter`, `lm_farm4_field` and `lm_farm1_home` inside the parts they stood in).

### Ye differs from the kit
Ye's expansion is **not** what the kit files build. The kit is `Art/Studio/Regions/Lindenmoor/layout.json`, `import/chunk_*.lua` and the Blender scene `Lindenmoor_Expansion.blend`. After the import, these Studio fixes changed Ye in place, and none of them is in the kit:
- the **seam regrade** (`regrade_seam.lua`) and its `SeamRegradeFill` slabs;
- the **seam pits** (`seam_pits.lua`) and their `SeamPitsFill` blocks;
- the **gorge fix** (`gorge_fix.lua`): the straight, centred footbridge, its landings and the gorge and west-creek water;
- the **gorge bed** (`bed_fix.lua`): the slate channel bed;
- the **road cut** (`road_cut.lua`) and its mouth ramp;
- the **seam fillers** (`SeamFillers`, Ruling 20, placed by hand);
- the **7 Shelter posts** (`shelters.lua`);
- the **east/west names** (`east_west_names.lua`): West Lookout, Northwest Gap and the two village descriptions;
- the **four moved posts** (`post_fixes.lua`, Foundry Yard plan Task 4b): `lm_lookout_seat`, `lm_haybarn_shelter`, `lm_farm4_field` and `lm_farm1_home`, out of the parts they stood in. The region file (`Art/Regions/Lindenmoor/layout.json`) has the new spots; the kit's chunks don't.

The north-west road's `Travel` is built by `setup.lua` from the kit's marker, so a re-run of `setup.lua` brings it back.

**A re-import from the kit, or a Blender rebuild and fresh export, silently drops all of the list above.** Nothing warns you: the import's own checks pass, because they compare against the kit. After any re-import:
1. Re-apply the fixes in the order they first ran: the seam fillers (by hand), the seam regrade, the gorge fix, the seam pits, the bed, `setup.lua`, the road cut, the shelters, the east/west names, then the four posts (`post_fixes.lua`). Regenerate the generated ones (`regrade_seam.lua`, `seam_pits.lua`, `road_cut.lua`) from a fresh survey with their `.py` first, each right before it runs: their committed plans are for the ground as it was. Every fix checks the ground or targets it expects, and refuses instead of half-applying when they don't match.
2. Re-run the smoke and travel suites.

`test_ye_fixes.py` (beside the kit scripts) fails if the kit gains an east/west name that `east_west_names.lua` doesn't swap.

### Known issues (accepted or parked, 2026-10-24)
Each is recorded in the import plan's ledger. None blocks the publish.
- **19 corner steps at the village seam, up to 8 studs** (Ruling 30). Where Ye's two edge cells differ by 3–17 studs, no single height meets both. The steps are jumpable. The owner can point at one, and it gets fixed by hand.
- **Dry pocket cells by Halvard's Adit.** 191 low cells south of the gorge mouth (x 328..560, z −608..−576, tops 1–5) lie behind the south bank and don't connect to the channel, so the gorge fix left them dry.
- **About 1.2 studs of water over the village creek mouth.** The gorge's upstream water caps reach over the village's creek bed (top 4) at x 316..332 and fill the hollow under the village there. Cosmetic: it may read as the creek flowing out, or as a flooded bed.
- **A village oak's trunk runs through `Filler_Slit`** (`OakBig_Rim45`, its `Trunk` and `Root3`).
- **Test-order flakes, not game bugs:**
  - Play_Rumours R2 fails when it repeats in one session;
  - Play_Gate has an ordering flake;
  - Play_TownsfolkHurt goes 10/1 when it runs 13th in a session: Gossip hears an earlier rumour.
  Each passes on a fresh session.
- **The miller and the groundskeeper sleep curled up in the open.** Their night posts are Shelter posts, whose idle is `NPC_CurledUp`, so they spend every night curled up at the mill's and the training field's shelters.
- **Trains reach Foundry Yard from its east, and the road from its south.** The lines can curve in between, so it isn't a contradiction, but a player may notice.
- **The expansion is over its own 42,000 ceiling.** It is at 45,425 (Ruling 25 accepts it; the binding limit is the place's 80,000). Ye has **about 3.6k parts of headroom** left (76,372 of 80,000), and the next region work must fit in it.

### Publish checkpoint (for the owner)
**On hold (owner, 2026-10-24: "Hold both").** Ye (the Lindenmoor expansion) and Foundry Yard stay unpublished until the Foundry Yard plan has finished Foundry's game data. Then both are published together, in the order below. **Publishing Foundry Yard ships its new map**, the one the Foundry Yard plan imported, so it must be ready too. The steps stay as written, for when that happens.

**First:** Ye's Edit session holds every change below, unsaved.
1. **Save the place in Studio. Don't publish anything yet.**
2. Walk the new land in Play once: the farms, the gorge and its ledge, the mine, the woods, the meadows, the training field, and the north-west road to the gap.

**Then publish in this order.** It is the package routine in `Documents/World Travel.md` §10.
1. **Publish the packages from Ye:**
   - Modules;
   - RenseiServer;
   - ClientHandler (it holds `ClientHandler.Run`).

   Their contents are listed below.
2. **Update the packages in Foundry Yard by hand.** Foundry never updates a package on its own.
   - Update Modules, RenseiServer and ClientHandler there.
   - Check that they match Ye.
3. **Publish the places:**
   - Ye;
   - Foundry Yard, so it carries the updated packages;
   - the Main Menu and the Tutorial, only if they changed (nothing in this plan touched them).
4. **Migrate to Latest Update** (or shut down all servers) for Ye and Foundry Yard, so that no old server runs the old code against the new saves.

Migrate comes after the place publishes, because it moves running servers onto the latest *published* version. Run before Ye is published, it would restart them on the old place.

**1. The Modules package** (`ReplicatedStorage.Modules`):
- `Data.Rensei`: Regions, Townsfolk, TownsfolkLogic, Quests, Dialogues, Investigation, Evidence and Puzzles;
- `UI`: CompassUI and MasteryUI.

Foundry Yard gets these through step 2 of the order. Its compass stays −Z north.

**2. The RenseiServer package** (`ServerStorage.RenseiServer`):
- WorldService;
- TownsfolkService (since the final fix pass its posts count only in `workspace`) and TownsfolkService.Mover;
- MoralityService (a comment change only);
- **EnemyService and CompassService** (final fix pass): only spawns and compass points in `workspace` count, so the retired GruntSpawns in the backups no longer spawn Grunts by the old hub.

**3. The ClientHandler package** (`StarterPlayer.StarterPlayerScripts.ClientHandler`): `ClientHandler.Run` (slide into sprint). The sweep found the repo behind Studio here. It predates this plan, and may already be live.

**4. The Ye place itself:**
- **The map:**
  - `World.Map.LindenmoorExpansion`, with its `Travel` (the north-west road), `SeamFillers`, `SeamRegradeFill` and `SeamPitsFill`;
  - the hub pieces that `prep_ye.lua` moved onto their pads: trainers, trial sites, LedgeCourse, spawns and the lifted items;
  - the retired NorthRoad, HubRoad and BufferStop, now in the backups.
- **The Studio fixes:**
  - the seam regrade and the seam pits;
  - the gorge (bridge and water) and its bed;
  - the road cut and its mouth ramp.
- **The 7 Shelter posts.**
- **The names:** the West Lookout and Northwest Gap AreaNames, and the Bramble Hollow and Halvard's Adit descriptions.
- **Place-owned scripts** in `ServerStorage.RenseiTests` (not a package):
  - new: Play_LindenmoorData and Play_LindenmoorSmoke (with EnemiesStandInTheWorld since the final fix pass);
  - changed: Test_Regions, Test_TownsfolkLogic, Play_TownsfolkCrowd and Play_TownsfolkHurt;
  - Play_Road and Play_Station, the d3606a5 versions.
- **`ServerStorage.RenseiBackups`.**

**Older Studio changes that go out in the same package publishes, if they aren't live already.** The Studio == repo sweep found these Studio copies ahead of the repo, from before this plan, and brought the repo up to date:
- **Modules:**
  - StealthUI (the restyle);
  - PuzzleClient (Breakable boards);
  - `Managers.HitboxManager`;
  - ProfileData (the `Travel` default);
  - JumpManager (a trailing newline only).

  HitboxManager is Studio's copy, and it equals `Art/Studio/HalvardsAdit/boards/HitboxManager.lua`. Its `Sweep` → `PuzzleService.Strike` hook is what lets a melee strike break the Adit's boards. It has no `Scripts/` copy by design.
- **RenseiServer:** PuzzleService (Breakable boards: `Strike`) and FlowService (`ToMenu`).
- **ClientHandler:** `Run` (above).
- **RenseiTests (the place):** Test_Schema5 and Test_Witness.

**Two travel tests fail in your save.** Play_Travel and Play_RideEvents fail because your real save holds a Cabin / Second ticket. That isn't a regression.

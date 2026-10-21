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

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

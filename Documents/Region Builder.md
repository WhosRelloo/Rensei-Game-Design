# Region Builder: how to build a region and put it in a place

This is the how-to for the region pipeline built by the Region Foundation (2026-10-23 to 2026-10-24). It covers the whole route:

1. the region file;
2. the Blender builder and its renders;
3. the export;
4. the safe import into a Studio place;
5. the travel setup;
6. the game data that brings a region to life: townsfolk, clues and the clock.

The design is `Documents/specs/2026-10-23-region-builds-design.md`, and the plan is `Documents/plans/2026-10-23-region-foundation.md`. Where this page and the plan differ, this page follows the code as built.

Every size, height, colour and timing in the tools is a **PROPOSAL** unless the owner has chosen it. This page marks the ones that matter.

## The pieces at a glance

| Step | Where | What it does |
|---|---|---|
| Region file | `Art/Regions/<Region>/layout.json` | Describes the region: size, heights, districts, roads, landmarks, markers. |
| Builder | `Art/Blender/region_builder/` (`build.run`) | Builds the region in Blender, saves `Art/Blender/Regions/<Region>.blend`, writes renders, `materials.json` and `water.json`. |
| Export | `Art/Blender/lindenmoor/export.py` (`export(scene, out, origin)`) | Writes the parts to `Art/Studio/Regions/<Region>/layout.json`. |
| Import kit | `Art/Studio/Regions/kit.py` | Writes chunk scripts plus `finish.lua`, `restore.lua` and `unstrip.lua`. |
| Travel setup | `Art/Studio/Regions/setup.lua` (bundled by `bundle_setup.py`) | Builds the station and road pieces from `RenseiMarker` markers. |
| Game data | `Rensei.Townsfolk`, `Rensei.Investigation`, `WorldClock` | Townsfolk rosters, clue texts and quests, the time of day. |

The builder package is `region_builder/`, not `regions/`. On Windows, `regions/` would be the same folder as the `Art/Blender/Regions/` output folder, and Python can't import it.

## 1. The region file

The region file is `Art/Regions/<Region>/layout.json`. `region_builder/schema.py` checks it, listing every problem at once with where it is. An unknown top-level key is an error, which catches typos.

**Coordinates** are studs in Roblox's own axes (the export puts every point back exactly where the file says), with the origin at the footprint's centre:
- `+X`, `+Z` and `y` up. Compass words depend on the place: **in Ye, `+Z` is north** (Lindenmoor's file and its expansion: x east, z north). The region-builds spec read Foundry's drawings with `+Z` as south. In notes and attributes, say `+Z` / `−Z` rather than north or south;
- a point is `[x, z]`;
- a marker's `At` is `[x, y, z]`, where `y = 0` means "on the ground" (the builder snaps it) and any other y is an absolute height;
- a Rect is `[x0, z0, x1, z1]` with `x0 < x1` and `z0 < z1`.

### Top-level keys

| Key | Required | Value |
|---|---|---|
| `Region` | yes | The region id, e.g. `"Foundry"`. |
| `PlaceId` | yes | The Studio place the region goes into (whole number; 0 for a test region). |
| `Footprint` | yes | `[width, depth]` in studs. |
| `Palette` | yes | Role → material key (see "Palette and materials"). |
| `Heights` | yes | List of height shapes. |
| `Districts` | yes | List of built-up areas. |
| `Routes` | yes | List of roads, lanes and rails. |
| `Landmarks` | yes | List of landmark pieces. |
| `Markers` | yes | List of markers (tags with attributes). |
| `Budget` | yes | The part ceiling, 1 to 90,000. |
| `KeepMapChildren` | no | Names of `workspace.World.Map` children the import must leave in place. Absent means keep nothing. |
| `MapChild` | no | The `World.Map` child the import builds. Absent means the Region name. Letters, digits and `_`, starting with a letter. |
| `NoCollide` | no | Part-name substrings that are walk-through in the import (see "Collision"). Absent means the region's default. |
| `NoCollideKinds` | no | Prefab kinds that are walk-through in the import. Absent means the region's default. |
| `RestoreRefuseFlags` | no | The Studio fix flags (attribute names on `World.Map.<MapChild>`) that make the import's `restore.lua` refuse while any is set. A list of non-empty strings (the schema checks it). |
| `Notes` | no | Free-text strings for later readers, e.g. a change made in Studio that the builder doesn't make. The builder never reads them. A list of non-empty strings (the schema checks it). |

`KeepMapChildren` may not name the `MapChild`. Lindenmoor's file has its own top-level `Keep` (a list of area objects). That is a different thing, and the import ignores it.

### Heights

Each entry has a `Kind`. The ground is worked out on a 4-stud grid in 1-stud steps, as Lindenmoor's was.

| Kind | Keys | Meaning |
|---|---|---|
| `plane` | `Y` | The base ground height everywhere. |
| `box` | `Rect`, `Y`, optional `Edge` (default 0) | A raised block that blends down over `Edge` studs. |
| `ridge` | `Line` (2+ points), `Width`, `Y` | A ridge along a line that falls away to the sides. |
| `cut` | `Rect`, `Y` | A sunken area. |
| `water` | `Rect`, `Top`, `Bed` (`Bed < Top`) | Water with its surface and bed. Kept only where it stands above the ground. |

Later shapes override earlier ones. A shape can raise ground out of water, and no water is filled under raised ground.

### Districts

Each has `Id`, `Poly` (3+ points), `Style`, `Density` (0–1) and `Storeys` `[min, max]` (1 ≤ min ≤ max ≤ 4; the cap of 4 is a PROPOSAL).

`Style` names a building style as `"<kit>.<piece>"`. The rail-town kit has:
- `railtown.house`;
- `railtown.boarding`;
- `railtown.shed`;
- `railtown.warehouse`;
- `railtown.stack`.

### Routes

Each has `Id`, `Kind`, `Width` and `Line` (2+ points). The kinds are:
- `public`: paved, with kerbs;
- `road`: paved like `public`;
- `quiet`: a cinder lane;
- `rail`: rails;
- `under`: an underground route, dressed with the underworks tunnel piece. Its use still needs a design.
- `ledge`: left to a later traversal stage; it builds nothing yet.

Where a public, road or quiet route climbs more than 4 studs over 8, it gets stairs of 1 stud per step.

### Landmarks

Each has `Id`, `Kind`, `At` (`[x, z]`) and optional `Yaw` (degrees). The rail-town landmarks are:
- `practice_court`;
- `foundry_hall`;
- `crane_bay`;
- `rail_walk`;
- `underworks`;
- `canteen`;
- `market_stall`.

Write each with its kit name, e.g. `railtown.crane_bay`. The kit's footprints are in `region_builder/kitspec.py`.

### Markers

Each marker has:
- `Tag`;
- exactly one of `At` (`[x, y, z]`) or `Box` (`[[x0, y0, z0], [x1, y1, z1]]`);
- optional `Yaw` (degrees; 0 faces −Z, 90 faces −X, −90 faces +X; in Ye, Yaw 0 faces south);
- optional `Attr`, the attributes the part carries in Studio.

The builder makes each one an invisible part with the tag and attributes:
- a point marker is a 2 × 2 × 2 part standing on its spot;
- a box marker is its box.

**Marker parts never collide, and can't be queried or touched** (final review I3, 2026-10-24). The import sets `CanCollide`, `CanQuery` and `CanTouch` off on every marker part. A queryable marker is an invisible wall for every ray that crosses a face, and Lindenmoor's area boxes are huge (North Meadows is 740 × 100 × 1080):
- climbs and wall runs raycast all of `World.Map` (`JumpManager`, and the server's `MovementState` wall check);
- NPC sight rays exclude only the rigs (`PerceptionService`);
- projectiles and ground-placed casts stop on it (`AlchemyService`).

A tag gets a query or a touch back only where its service needs one (`studio_kit.MARKER_ACCESS`). Each service that reads a marker tag was read for this:

| Tag | Needs | Why (file:line) |
|---|---|---|
| `RenseiLedge` | `CanQuery` | `LedgeWalk.Under` raycasts with an Include list of the tagged parts (`Scripts/ReplicatedStorage/Modules/Managers/JumpManager/LedgeWalk.lua:75-77`); a query-off part is never hit. (The builder's ledges are visible kit parts, which keep their defaults; this is for a ledge marker.) |
| `RenseiStationGate` | `CanTouch` | `StationService`'s `GuardGate` wires `Gate.Touched` (`Art/Studio/Travel/src/StationService.lua:427`). |
| `RenseiArea` | nothing | Point-in-box: `WorldService.AreaAt` (`Scripts/ServerScriptService/WorldService.lua:36-40`), `FieldNotesUI.lua:180`, `AdminService.lua:302`, `CompassService.lua:50`. |
| `RenseiPost` | nothing | Position and LookVector: `TownsfolkService.lua:135` (`AddPost`), `:156` (`StandAt`). The Mover's queries respect `CanCollide`. |
| `RenseiClue`, `RenseiInspect` | nothing | `InvestigationService.lua:85-107` parents a ProximityPrompt with `RequiresLineOfSight = false` to the part. Checked in Play: the prompt shows on a `CanQuery = false` part. |
| `RenseiTrial`, `RenseiTicketClerk` | nothing | A ProximityPrompt (`TrialService.lua:499-508`; `StationService.lua:982`). |
| `RenseiEnemySpawn` | nothing | Its CFrame (`EnemyService.lua:526`). |
| `RenseiArrival` | nothing | Its CFrame (`TravelService.lua:38-43`). |
| `RenseiFreightYard` | nothing | Point-in-part (`StationService.lua:478-500`). |
| `RenseiRoadPassage`, `RenseiRoadThreshold`, `RenseiRoadEncounter` | nothing | Point-in-part (`RoadService.lua:131`). |
| `RenseiMarker` | nothing | `setup.lua` reads its attributes. |

The dry run checks the marker parts' settings against `expected.json`. Lindenmoor's and the train's own kits (the command-line `studio_kit.py`) are unchanged: their invisible helpers (`BoardZone`, `StowZone`, `CarDoor`) are not region markers and keep query and touch on, because the train services touch them.

**The tag names are the ones the game's services read.** The spec's four older names are refused, so a wrong tag can't import and silently do nothing.

| Tag | Required `Attr` | What it is |
|---|---|---|
| `RenseiPost` | `PostId` (unique), `Kind` (`Work` / `Seat` / `Counter` / `Home` / `Shelter`) | A townsfolk post. The marker's Yaw is the way they face. |
| `RenseiClue` | `ClueId` | A clue point (see "Clues"). |
| `RenseiArea` | `AreaName` | A named area. Use a Box. |
| `RenseiTrial` | `TrialId` | A trial room entrance. |
| `RenseiMarker` | `Piece` (+ that piece's keys) | A travel piece that `setup.lua` builds (see "Travel setup"), or a known non-travel piece it skips (`TrainerSpot`). Must use `At`. |
| `RenseiArrival`, `RenseiPlatformTrain`, `RenseiTicketClerk`, `RenseiDepartureBoard`, `RenseiStationGate`, `RenseiFreightYard`, `RenseiWatcher`, `RenseiRoadPassage`, `RenseiRoadThreshold`, `RenseiRoadEncounter` | as the travel services expect | World Plan 1 travel tags. For a new region, prefer `RenseiMarker` pieces and let `setup.lua` lay these. |
| `RenseiLedge`, `RenseiEnemySpawn`, `RenseiInspect`, `RenseiMechanism`, `RenseiPuzzleDoor`, `RenseiLight` | as their services expect | Other map-placed gameplay pieces. |
| `EdgeGap` | none; needs a `Box` | Builder only: the edges stage leaves this box open (a road mouth, the station). Never exported. |

The old names `RenseiClerk`, `RenseiThreshold`, `RenseiEncounter` and `RenseiTrialDoor` are refused. Use `RenseiTicketClerk`, `RenseiRoadThreshold`, `RenseiRoadEncounter` and `RenseiTrial` instead. To allow a new tag, add it to `MARKER_TAGS` in `schema.py`.

### `RenseiMarker` pieces

`Attr.Piece` names the piece. Any other attribute not listed is refused, because a misspelt name would be silently ignored in Studio.
- Types are: str (non-empty), num (number), int (whole number), bool, json.
- A json value is a **string** holding JSON, because Roblox attributes can't hold lists.
- Coordinates in attributes are region coordinates.

| Piece | Required | Optional |
|---|---|---|
| `Station` | `Route`, `TrackX`, `RailTop`, `NoseZ`, `PlatformSide` (must be 1) | `Arrival` (false: no Platform arrival) |
| `Clerk` | `Station` | |
| `Board` | none | |
| `Gate` | `Route` | `Sign` (default "STATE CHECKPOINT") |
| `Railing` | `Runs` (json `[[x1, z1, x2, z2], ...]`), `WallTop` | |
| `FreightYard` | none | |
| `RoadPassage` | `Route`, `To`, `RoadName`, `Legs` (json: `["line", x1, z1, x2, z2]` / `["arc", cx, cz, r, a1, a2]`), `Threshold`, `RoadStart`, `Encounters` (json `[s, ...]`), `Half`, `RoadY`, `Seed` (int) | `Arrival`, `Name`, `FloorY`, `Cut`, `High`, `Gate`, `Fence` (json `[s1, s2]`), `Skip` (json list of Rects), `Clip` (json `{MinX, MaxX, MinZ, MaxZ}`) |
| `TrainerSpot` (not a travel piece) | `Trainer` | `Element`, `Note` |

**Non-travel pieces.** `TrainerSpot` marks where a hub trainer is moved to by hand (Lindenmoor's training field). `setup.lua` leaves it alone and lists it in its summary ("skipped (not travel pieces): TrainerSpot 5"); the schema still checks its attributes. Any other unknown `Piece` is refused. The list is `NON_TRAVEL_PIECES` in `schema.py` and `SKIP` in `setup.lua`; keep the two equal (`tests/run.py` checks it).

A `RoadPassage` needs `0 ≤ RoadStart < Threshold ≤` the road's length. What each piece builds, and every derived size, is in the header of `Art/Studio/Regions/setup.lua`. Those sizes come from Foundry's hand-built station and are PROPOSALs.

### Palette and materials

`Palette` maps a role to a material key from `region_builder/materials.py` (`BASE`). The roles are `ground_top`, `ground_side`, `path`, `quiet`, and any role a stage uses.

A value is either:
- a key, e.g. `"cinder"`;
- or `{"Key": "paving", "Pack": "<texture-pack item>"}`, which names a block in `Art/Regions/texture_pack.json`. In Studio, that material becomes a MaterialVariant with the pack image, while Blender shows the flat colour.

The builder writes `Art/Regions/<Region>/materials.json`: `RG_<Region>_<key>` → `{Material, Color, Transparency}`, plus `PackImage` and `StudsPerTile` for a pack role. `StudsPerTile` is a PROPOSAL.

### Example

The Testbed, `Art/Regions/Testbed/layout.json`, is a 256 × 256 test map with one of everything. Copy it to start a new region.

## 2. Running the builder

Run it in Blender, through the bridge, with a small Python file:

```python
import sys; sys.path.insert(0, r"C:/Users/Owner/Rensei-Game-Design/Art/Blender")
from region_builder import build
result = build.run("Testbed")                      # every stage, renders included
# result = build.run("Testbed", "ground,routes,markers")
```

```
python -I Art/Tools/blender_mcpc.py code @my_build.py
```

The stages, in order:
1. `ground`: stepped slabs in 64 × 64 tiles, side blocks and ramps;
2. `routes`: kerbs, stairs and rails;
3. `buildings`: districts filled from the style kit, facing the street, with alleys;
4. `landmarks`;
5. `cover`: crate stacks and machinery, plus street lamps that light only at night;
6. `edges`;
7. `markers`;
8. `lighting`;
9. `render`.

**Safety.** `build.run`:
- refuses to run if Blender has unsaved changes, because it opens an empty file;
- saves only `Art/Blender/Regions/<Region>.blend`, which is never committed;
- never saves over `Lindenmoor_Full.blend` or `Lindenmoor_Expansion.blend`.

**Budget.** `build.run` returns `{objects, parts, budget, over, renders, blend, stages}`. When `over` is true, the scene carries `rs_over_budget`. **Don't export an over-budget scene.** The import kit refuses it as well.

**Renders** go to `Documents/images/Regions/<Region>/`: an aerial view, plus a street view per district and landmark. They are flipped left-right so they show the place as Studio will. **The owner approves the renders before any import.**

**Tests.**
- Pure Python: `python -I Art/Blender/region_builder/tests/run.py`.
- In Blender: `python -I Art/Tools/blender_mcpc.py code @Art/Blender/region_builder/tests/blender_check.py`.
- The kit gallery renders come from `region_builder/tools/render_kit_gallery.py`.

### Edges and `RenseiNoGrip`

The owner's rule is natural edges and no invisible walls. The climb leap can take a player about 123 studs up (a fully upgraded one about 207), so no sensible wall height keeps people in. Instead, edge walls carry the tag **`RenseiNoGrip`** (owner, 2026-10-24: "Ungrippable edges").

A part with `RenseiNoGrip`, or inside a model that has it, can't be grabbed by:
- a climb;
- a mid-air grab;
- a climb leap;
- moving along a climb;
- a wall run;
- the air wall-kick (S).

It still shows, and you can stand on it and bump into it. The server refuses a climb or wall run against it too. The tag name lives in `TuningConfig.Parkour.NoGripTag`.

- **The builder** tags every edge wall block (export row field 16).
- **By hand in Studio:** add the tag with the Tag editor or `CollectionService:AddTag(part, "RenseiNoGrip")`. Tagging a model covers every part in it.
- **Edge numbers** (`region_builder/placement.py`, PROPOSALs):
  - `EDGE_HEIGHT = 80`: each wall's sheer inner face stands at least 80 studs over the ground beside it. A running jump reaches about +16 to +19.
  - `WALL_CLEAR = 26`: no building, landmark, cover cluster or lamp stands within 26 studs of an edge wall's inner face, so no roof can launch anyone over.
  - `EDGE_BAND = 12`: the walls' depth in from the footprint's edge.
- **Gaps:** `EdgeGap` box markers leave the wall open where a road or the station leads out.

Today, no tagged part is in any live map. The first ones arrive with the region imports.

## 3. Export

The export is `Art/Blender/lindenmoor/export.py`: `export(scene_name="Lindenmoor_Full", out_path=..., origin=(0, 4, -650))`. For a region, give all three:

```python
from lindenmoor import export as EX
EX.export("Region_<Region>", r"C:/Users/Owner/Rensei-Game-Design/Art/Studio/Regions/<Region>/layout.json", origin=(0, 0, 0))
```

With origin (0, 0, 0), region coordinates are world coordinates. Each part row is:
- `[name, shape, mat, sx, sy, sz, X, Y, Z, qx, qy, qz, qw]`;
- then three more fields for marker and tagged parts: field 14 invisible (0/1), field 15 an attributes JSON string, field 16 comma-separated tags.

Field 16 is how `RenseiPost`, `RenseiClue`, `RenseiNoGrip` and the other tags reach Studio. When any of the three extra fields is present, all three are written, with `""` meaning none. Rows without them stay at 13 fields, so Lindenmoor's and the train's exports are byte-for-byte unchanged.

## 4. The import: dry run first, then Confirm

### Generate the scripts

```
python -I Art/Studio/Regions/kit.py <Region> [--keep Name1,Name2] [--map-child Name] [--place <id>] [--date YYYY-MM-DD]
                                    [--no-collide A,B] [--no-collide-kinds K1,K2] [--out <dir>] [--offset x,y,z]
```

It reads:
- the export, `Art/Studio/Regions/<Region>/layout.json`;
- `Art/Regions/<Region>/materials.json` and `water.json` (both optional);
- the region file, for `PlaceId`, `Budget`, `KeepMapChildren`, `MapChild`, `NoCollide` and `NoCollideKinds`.

It writes these into `Art/Studio/Regions/<Region>/import/`:
- `chunk_NN.lua`;
- `expected.json`;
- `finish.lua`;
- `restore.lua`;
- `unstrip.lua`.

It refuses an export over the region's `Budget`.

| Option | Meaning |
|---|---|
| `--keep` | More `World.Map` children to leave in place, added to the file's `KeepMapChildren`. |
| `--map-child` | The `World.Map` child to build (default: the file's `MapChild`, else the Region name). |
| `--place` | Another place id, for a test run. |
| `--date` | The date written into the headers. The backup is named by the **run** date. |
| `--no-collide`, `--no-collide-kinds` | The walk-through lists (comma-separated; `-` = none), replacing the file's `NoCollide` / `NoCollideKinds`. |
| `--out` | Test runs: write the scripts to `<dir>/import` instead of the committed `import/` folder. |
| `--offset` | Test runs only (needs `--out`): move the whole import, parts and water, by `x,y,z` studs (the Foundry smoke test). |

`water.json` must be `{"Boxes": [{"Rect": [x0, z0, x1, z1], "Top": t, "Bed": b}, ...]}` in the **export's** frame: `finish.lua` adds the export's origin to every box (`Lo = ORIGIN + (x0, Bed, z0)`). For a region_builder region (origin (0, 0, 0)) that is the region file's own coordinates, and the builder writes it this way from the cells that are actually under water. For Lindenmoor (origin (0, 4, −650)) the boxes must be village-local: world − (0, 4, −650), so y − 4 and z + 650.

### Run it in Studio (Edit mode, the region's place)

Run each chunk in order:

```
python -I Art/Tools/rbxc.py luau "placeId: <id>" Edit @Art/Studio/Regions/<Region>/import/chunk_01.lua
```

The chunks build everything into `ServerStorage.RegionStaging`. Nothing is in the live map yet.

**1. The dry run, always first.** Set the attribute `DryRun = true` on `ServerStorage.RegionStaging`, then run `finish.lua`. It checks the staging against `expected.json`:
- models and parts per group;
- every tag per group: posts, clues, areas, ledges, `RenseiNoGrip`;
- lights;
- the texture-pack MaterialVariants and the parts that carry them.

- the marker parts: no collision, and query or touch only where `MARKER_ACCESS` says;
- **the keep list, exactly as the real run checks it.** A keep name that isn't a `World.Map` child, or that names the `MapChild`, fails the dry run. So does a non-empty keep list checked in a place other than the kit's `PlaceId` (a Foundry dry run can't pass for Ye).

It also reports the walk-through lists and **which `World.Map` children a real run would move and which it would keep**, e.g. `keep list [Foundry]: a real run would move nothing into the backup, keep Foundry, and build Map.TestbedSmoke`. Read that line before every real run.

Then it removes the staging folder and every MaterialVariant the chunks made, so the place is left exactly as it was. It returns `dry run ok: ...` or `dry run FAILED: ...`.

**2. The real run, only with `Confirm`.** Run the chunks again, set `Confirm = "<Region>"` (the region's name, as a string) on `RegionStaging`, and run `finish.lua`. With neither attribute set, it refuses and changes nothing.

The real run refuses, before changing anything, if:
- the checks fail;
- this is another place;
- today's backup `RenseiBackups["Pre-Region_<Region>_<date>"]` already exists;
- `World.Map` is missing;
- a keep name isn't a `World.Map` child, or is the `MapChild`.

When it goes ahead, it:
- builds `World.Map.<MapChild>` from the staged groups;
- moves every `World.Map` child **not** in the keep list into the dated backup, with its CollectionService tags set aside in the attribute `RegionKitTags`, so the services stop seeing the old markers;
- backs up and swaps any MaterialVariant it replaces;
- snapshots the terrain under each water box and fills it with water.

**The keep list.** Children named in `KeepMapChildren` or `--keep` stay exactly where they are, with all their tags. That is how Lindenmoor's village stays when its expansion goes into Ye beside it, as `World.Map.LindenmoorExpansion`.

**Rollback.** The whole swap runs inside a pcall. If anything fails partway, everything is moved back as it was.

**Studio's Undo.** `finish.lua` and `restore.lua` wrap their swap in `ChangeHistoryService:TryBeginRecording` / `FinishRecording`, so Studio's Undo can take it back as one step. Through the Studio bridge (`rbxc.py luau`) a recording is already open (each run is the bridge's own "Assistant" Undo step), so `TryBeginRecording` returns nil and the summary says `undo: the caller's recording`. Either way, Undo covers the whole run. `restore.lua` stays the way to undo an import later.

**Restore.** `restore.lua` undoes a real run:
- it puts the old map back, with its tags, water and texture settings;
- it never deletes the imported map: that moves to `RenseiBackups["Post-Region_<Region>_<date>"]`, tags stripped, so anything built in it after the import is kept;
- it refuses if a backed-up child's name is already taken in `World.Map`;
- it refuses, changing nothing, while `World.Map.<MapChild>` carries any flag named in the region file's `RestoreRefuseFlags` (a Studio fix made after the import that has its own undo). Undo those fixes first; the refusal names the flag. A region file without the key gets no such guard. Today Lindenmoor lists its eight fix flags (`LindenmoorPostFixes` since the Foundry Yard plan's final fix) and Foundry lists `FoundryPosts`, `FoundryForge`, `FoundryLedges`, `FoundryWalks` and `FoundryAnvil` (`Documents/Lindenmoor Kit.md` and `Documents/Foundry Yard Kit.md` have the undo orders);
- set `DATE` at its top to restore an older backup than the newest.

**Unstrip.** A piece dragged out of a backup has no tags. To get them back, either:
- set `PATH` in `unstrip.lua` to its path (e.g. `"ServerStorage/RenseiBackups/Post-Region_<Region>_<date>/<MapChild>/<Group>/<Model>"`);
- or put the attribute `RegionKitUnstrip = true` on each piece.

Then run `unstrip.lua`, which re-adds every tag from `RegionKitTags`. A re-tagged piece left in ServerStorage becomes visible to the services again, so move it out.

**Collision.** The walk-through lists are per region (final review I4). `kit.py` takes them from `--no-collide` / `--no-collide-kinds`, else the region file's `NoCollide` / `NoCollideKinds`, else the region's default:
- a region_builder region (the rail-town kit): parts named `*Glass` or `*Glow` are walk-through. Kerbs, crates and walls stay solid;
- Lindenmoor: the village's own lists from `studio_kit.py` (`Tuft`, `Crop`, `Vine`, `Lantern`, `Banner`, … and the `EdgeStone` kind), because the expansion reuses the village's pieces. Its verge stones, crops, tufts, vines and lanterns stay walk-through, as in the village.

The dry run prints the lists it used.

## 5. Travel setup

After the import, `setup.lua` builds the station and road pieces from the `RenseiMarker` parts under `World.Map.<MapChild>`, into its `Travel` folder.

```
python -I Art/Studio/Regions/bundle_setup.py setup <scratch>/setup_bundle.lua
python -I Art/Tools/rbxc.py luau "placeId: <id>" Edit @<scratch>/setup_bundle.lua
```

Set `REGION`, `MAP_CHILD` and `ORIGIN` with `bundle_setup.py`'s options, which change only the bundle (the committed `setup.lua` keeps its defaults):

```
python -I Art/Studio/Regions/bundle_setup.py setup <scratch>/setup_bundle.lua --region Lindenmoor --map-child LindenmoorExpansion --origin 0,0,0
```

**`ORIGIN`** is added only to coordinates held in marker **attributes** (RoadPassage `Legs`, `RoadY`, `FloorY`, `Skip`, `Clip`; Railing `Runs`, `WallTop`; Station `TrackX`, `RailTop`, `NoseZ`). The marker parts themselves are already in world space, so the spot and facing never need it.
- **`(0, 0, 0)` whenever the attributes are in world studs.** That is every region_builder region (exported with origin (0, 0, 0)) **and Lindenmoor's expansion**: its region file is in world studs, and its RoadPassage `Legs` start at `[686, 661]`, the marker's own `At` (`tests/run.py` checks this).
- **Non-zero only when the attributes are in region coordinates that the export moved**, e.g. the smoke test's import moved by `kit.py --offset 4000,0,4000` (then `--origin 4000,0,4000`).
- It is **not** `finish.lua`'s `ORIGIN`. That one is the export's origin and is added to the water boxes, which is why Lindenmoor's water must be village-local (see "Generate the scripts").

A wrong `ORIGIN` builds the road in the wrong place, and nothing else flags it: the length check passes and the contract test checks shape, not position. A Station marker also needs `ServerStorage.TrainKit` (copy it from Ye).

- It checks every marker before building anything, and builds everything or nothing.
- Running it again rebuilds `Travel`. A hand-made `Travel` is backed up the first time, in `RenseiBackups["Pre-RegionSetup_<MapChild>"]`.
- It returns a one-line summary with any warnings.

**One of each per place.** The game takes the **first** arrival point and the **first** train it finds for a route (`TravelService.ArrivalPoint`, `StationService.TrainOf`). So setup refuses to add a Platform arrival, a RoadStart arrival, or a platform or ride train for a route the place already has anywhere outside the old `Travel`. It also refuses more than one of either arrival.
- A second station needs `Arrival = false`.
- A second road needs `Arrival = false`.
- The schema checks the same within one region file.
- Setup checks the whole place, including kept map children.

**Ride trains** use identity rotation and must stand clear: at least 300 studs above every map part, and away from other ride trains (PROPOSAL). Setup places the ride train at a fixed offset from the platform, +(0, 400, -1600); it does **not** check the clearance itself. The contract test does, so run it after every build with a Station.

**Test runs** use `ServerStorage.RegionSetupRoot`, and only when it carries the attribute `TEST = true` (an optional `ServerStorage.RegionSetupPlace` stands in for the rest of the place). A root without `TEST` makes setup refuse. A leftover root that still has `TEST = true` turns a real run into a test build in ServerStorage; that's harmless, and the summary says "test root", but remove test roots afterwards. Their tagged parts are also live tags while they exist.

**Check the result** with the contract test. First write it:

```
python -I Art/Studio/Regions/bundle_setup.py contract <scratch>/check.lua workspace.World.Map.<MapChild>
```

Then run it in the place:

```
python -I Art/Tools/rbxc.py luau "placeId: <id>" Edit @<scratch>/check.lua
```

It returns `PASS n / FAIL n`. Then rerun the travel Play suites in the place.

## 5b. The smoke test: a real import, played (Foundry only)

`Art/Studio/Regions/smoke.py` imports the Testbed into **Foundry Yard** for real, plays it, and undoes it. Never run it in Ye.

```
python -I Art/Studio/Regions/smoke.py --work <scratch>/smoke
```

The steps (`--steps snap,kit,dry,real,play,setup,restore,snap2`, all by default):
1. **snap:** Foundry's state before: `World.Map` children, every tag's count, MaterialService, ServerStorage and its backups, terrain;
2. **kit:** `kit.py Testbed --place 109591196441030 --map-child TestbedSmoke --keep Foundry --offset 4000,0,4000 --out <work>/kit`, clear of Foundry's own map;
3. **dry**, then **real:** the chunk and `finish.lua` (the dry run must report "move nothing, keep Foundry");
4. **play:** a hooked Play session (PlayLock, the save hook, `LMSnapTaken`, the suite, the save restored, Stop, unhook) running `Art/Studio/Regions/Play_RegionSmoke.lua` in the game VM. It checks:
   - every marker part has collision, query and touch off, and `WorldService.AreaAt` finds the Testbed area;
   - rays across the area box's faces aren't blocked;
   - the server's climb check accepts a plain wall, refuses a `RenseiNoGrip` edge, and refuses the bare area face;
   - the `test_work` post (Yaw 90) faces −X;
   - a `NightOnly` lamp follows `WorldClock.Hold`;
   - the clue gets its `InspectPrompt` (a test def is injected for the run);
5. **setup:** adds a `TrainerSpot` marker (skipped) and a `RoadPassage` marker (`Arrival = false`), runs `setup.lua` with `--origin 4000,0,4000`, then the contract test;
6. **restore:** `restore.lua`, then removes the smoke's own `Post-Region_Testbed_<date>` backup;
7. **snap2:** compares with the snapshot from step 1. Foundry must be exactly as before.

The suite is installed in `ServerStorage.RenseiTests` only for the Play session.

## 6. Townsfolk

### Posts

Posts are map markers: parts tagged `RenseiPost` with `PostId` (string) and `Kind`. The post's front (LookVector) is the way the townsperson faces. Each kind has an idle (PROPOSALs):

| Kind | Idle |
|---|---|
| `Work` | the townsperson's own `Idle` |
| `Seat` | `NPC_Chill` |
| `Counter` | `NPC_CrossArms` |
| `Home` | `NPC_Chill` |
| `Shelter` | `NPC_CurledUp` |

**Shelter** posts are where townsfolk run to from a fight.

### The roster

Rosters live in `ReplicatedStorage.Modules.Data.Rensei.Townsfolk`, as `Townsfolk.Regions[RegionId] = { ... }`. The region id is `TravelService.Here()` for the place, e.g. `"Foundry"`. Ye has no roster yet, so nobody appears there.

```lua
{
	Id = "foundry_crane_1",            -- unique within the region
	Name = "Edda Varn",
	Job = "Crane hand",
	JobLine = "Third shift on the bay crane. Watch your head under the hooks.",
	Faction = "Foundry",               -- a Factions id; the greeting reads your standing with it here
	Look = {Nation = "Amestrian", Gender = "Female", Seed = 11}, -- Nation required (Customization.NationLooks); Gender optional
	Idle = "NPC_Blacksmith",           -- optional: the idle at Work posts
	Schedule = { {6, 14, "crane_bay_2"}, {14, 15, "canteen_seat_4"}, {15, 6, "workers_row_3"} },
	Greetings = nil,                   -- optional per-tier overrides {Hostile = ..., Neutral = ...}
	Clue = nil,                        -- optional {Quest = "<QuestId>", Stage = <stage>, Text = "...", Signal = "<target>", Evidence = "<evidence id>"}
	                                   --   (Evidence optional: the evidence the line gives, before it signals)
}
```

**Schedule** slots are `{From, To, PostId}` in clock hours (0–24):
- a slot covers `From ≤ hour < To`;
- it wraps past midnight when `From > To`;
- the first matching slot wins.

**Checks.** `TownsfolkLogic.Validate` checks the roster when the town loads, and refuses the **whole** roster with a clear message for any of:
- a non-table entry;
- a missing or duplicate `Id`;
- an unknown `Faction`;
- a missing or unknown `Look.Nation`, or an unknown `Look.Gender`;
- no schedule;
- a slot whose hours are outside 0–24, or that is empty (`From == To`; use `{0, 24, ...}` for all day);
- a post that doesn't exist on the map;
- any uncovered hour;
- two townsfolk at the same post at the same hour.

**Talk.** Each Talk says one line, in a bubble over their head. In order:
1. the clue line, if you're on `Clue.Quest` at `Clue.Stage` (no `Stage` means any stage). It then gives `Clue.Evidence` (if set), and then signals `Clue.Signal`.
2. Otherwise, the next step of your rotation with them:
   - a greeting by your standing tier (Hostile, Distrusted, Neutral, Trusted, Honoured);
   - a rumour you haven't heard from them;
   - their `JobLine`;
   - then the greeting again.

Rumour and clue lines are said to you alone. A Talk also counts for "talk to" quest steps.

**Dress.** They wear their own nation's clothes, from `Customization.NationLooks`, with `Look.Seed` picking the outfit.

**Hurt.** Townsfolk can be hurt, knocked and killed, which counts as assault or murder. A newcomer takes a dead townsperson's job at the next 06:00. See the Task 6b changelog entry.

## 7. Clues

A clue is a part tagged `RenseiClue` with the attribute `ClueId`. `InvestigationService` turns it into an Inspect point for `Investigation.Inspects[ClueId]`. It works both for parts on the map at server start (how imported regions arrive) and for parts added later. `ClueId` wins over any `InspectId` the part already carries.

Clue texts live in `ReplicatedStorage.Modules.Data.Rensei.Investigation`, under `Inspects`:

```lua
foundry_cart_tracks = {
	Title = "Cart Tracks",
	Text = "Fresh ruts run from the gate to the slag heap, too deep for an empty cart.",
	AfterText = "Deep ruts to the slag heap.",       -- shown once you already hold the evidence
	Evidence = "deep_ruts",                          -- optional: the evidence it gives
	Requires = {Quest = {Id = "...", StageAtLeast = 2}}, -- optional StoryLogic conditions
	Locked = "Ruts in the cinder.",                  -- optional: shown when Requires fails
	StartsQuest = "foundry_cart_quest",              -- optional: the quest this clue starts
},
```

(The entry above shows the shape only; it isn't real content.)

**Starting a quest.** With `StartsQuest`, an inspect starts the quest when all of these hold:
- `Requires` passes: you got the evidence now, or you held it already and saw `AfterText`;
- `QuestService.CanStart` allows it: not active, not done, not on cooldown.

A failed `Requires` never starts the quest. On a clue with no `Evidence`, `Requires` gates only the quest. Put any other gate on the quest's own `Requires`. An active or finished quest is never restarted, but a `Repeatable` quest starts again after its cooldown.

A townsperson can also hold a clue line (the roster's `Clue`, above).

## 8. The clock

`WorldClock` lives in `RenseiServer`. The time of day comes from real time, so every place and every server shows the same hour.

- **Day length:** one real minute is one game hour, so a full day takes 24 real minutes (`WorldClock.DayMinutes = 24`, PROPOSAL).
- **Night** is 18:00 to 06:00 (`IsNight`, PROPOSAL).
- **The API:**
  - `Hour()`: the real-time hour;
  - `Now()`: the hour the world shows, which is the held hour while held;
  - `Hold(h)` and `Release()`;
  - `IsHeld()`;
  - `IsNight(h)`;
  - `Changed`: fires with each new whole hour.
- **Townsfolk schedules** read `Now()`.
- **Lamps:** give the lamp's part the attribute `NightOnly = true`. Its lights are on only at night. By day, the part's material becomes `SmoothPlastic` (`WorldClock.DayMaterial`, PROPOSAL), so a Neon head doesn't glow at noon, and its own material comes back at night. The builder's street lamps already carry `NightOnly`.
- **Admin:** the admin panel's Time box holds the clock at the hour you type; type `run` to let it follow real time again.
- **Different meanings of "night".** They don't all agree yet:
  - lamps light at 18:00;
  - the road's ambush bonus starts after 19:00;
  - stealth is darkest from 20:00 (daylight fades from 17:00 and returns 06:00 to 09:00).

## 9. Checklist for a new region

1. Write `Art/Regions/<Region>/layout.json`, starting from the Testbed. Run `tests/run.py`.
2. Run `build.run("<Region>")` in Blender. Check `over` is false. Show the owner the renders, and wait for approval.
3. Export `Region_<Region>` with origin (0, 0, 0) to `Art/Studio/Regions/<Region>/layout.json`.
4. Run `kit.py <Region>` with the right `--keep` and `--map-child` (and the walk-through lists if the default isn't right).
5. In Studio:
   - run the chunks, then a **dry run**;
   - read the result, especially the "would move / keep" line;
   - run the chunks again, set `Confirm`, and do the real run.
6. Run `setup.lua` for the travel pieces (`bundle_setup.py setup ... --origin 0,0,0` for world-stud attributes), then the contract test and the travel Play suites.
7. Add the game data:
   - the roster in `Rensei.Townsfolk`;
   - the clue texts in `Rensei.Investigation`;
   - area names in `Rensei.Regions`.
8. Play-test: walk every route, try to climb the edges, check lamps at night, talk to the townsfolk.
9. Commit the region file, `materials.json`, `water.json`, the export and the `import/` scripts. Never commit `.blend` files.

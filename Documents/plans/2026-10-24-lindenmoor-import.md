# Lindenmoor Expansion Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put the owner-approved Lindenmoor expansion (40,414 parts, built in Blender) into Ye around the village, which stays exactly where it is. The hub's pieces move onto their reserved pads, travel moves to the new north-east road, and the new land comes alive: areas, law, clues, townsfolk and water.

**Architecture:** Five stages:
1. **Survey Ye** (read-only) and fix the two Blender-side gaps: the crag's `RenseiNoGrip` tag, and the water converted to the import format.
2. **Export** the expansion and generate the import with the Region Foundation tools (`kit.py`).
3. **Prepare Ye** with a reversible script. It retires the old north road and moves the hub pieces and trainers onto their pads.
4. **Import** with a dry run first, then the owner's confirm. Then build the new road with `setup.lua`.
5. **Game data and checks:** the game data, a Ye smoke suite, and the docs.

Nothing here publishes. The owner publishes at the checkpoint named at the end.

**Tech Stack:**
- Python 3.14 (stdlib only): `expansion_plan.py`, the converter and the checkers.
- Blender, through `Art/Tools/blender_mcpc.py`.
- Roblox Studio Luau, through `Art/Tools/rbxc.py`.
- The region tools: `Art/Studio/Regions/kit.py`, `finish/restore/unstrip`, `setup.lua`, `bundle_setup.py`.

**Spec:**
- `Documents/specs/2026-10-23-lindenmoor-expansion-design.md` (approved);
- the checklist "Before the import into Ye" and "Rolling back the import in Ye" in `Documents/Lindenmoor Kit.md`;
- the tool guide `Documents/Region Builder.md`.

## Global Constraints

**Owner rules:**
- "Do not publish the Roblox game or modify live player data."
- "Do not expose API keys, credentials, private player data, or other secrets."
- "Do not blindly copy another game's code or assets."

**Labels and records:**
- Label every invented number **PROPOSAL** in code comments and docs.
- Every change gets a `Documents/Changelog.md` entry ending with a `### Discord announcement` section. "Hold: not live yet" applies until the owner publishes.

**Studio:**
- Ye is placeId 106992859583940 ("[CLOSED TESTING] Rensei"); Foundry Yard is 109591196441030. Never touch the Studio window "bloodydeadpool53's Place".
- Bridge: `python -I C:/Users/Owner/Rensei-Game-Design/Art/Tools/rbxc.py luau "placeId: <id>" <Edit|Server|Client> @file.lua`. Only the first return value prints, and output is cut at 30k chars.
- Play writes the owner's REAL save. Every Play session:
  1. sets `ServerStorage:SetAttribute("PlayLock", "<task>")`;
  2. installs `C:/Users/Owner/.claude/jobs/0c39df78/tmp/blender/hook.lua` in Edit;
  3. waits for `LMSnapTaken`;
  4. calls `game.ServerStorage.LMTestHook:Invoke("restore")` in Server;
  5. stops Play;
  6. runs `unhook.lua`;
  7. clears PlayLock.

  Script edits are refused while Play runs.
- **Backups:** before changing any script or instance, clone it into `ServerStorage.RenseiBackups["Pre-LindenmoorImport_2026-10-24"]`. Change a script by setting its Source in place (`string.find` + `string.sub`, never `gsub`). Keep each repo copy under `Scripts/` byte-equal to Studio, after normalising CRLF.

**Blender is shared with the "Foundry Yard in Blender" session:**
- Before any Blender step, the controller confirms with that session that it is not mid-build. It also checks `bpy.data.is_dirty` is false. Opening `Art/Blender/Regions/Lindenmoor_Expansion.blend` replaces Foundry's open file, which must already be saved.
- Never open, save or export `Art/Blender/Lindenmoor_Full.blend`. Never call `lindenmoor.core.reset_scene()`.
- Save only `Lindenmoor_Expansion.blend`, and only through `expansion.save()`.

**Git:**
- Commit by path only; never `git add -A`. Never stage `.blend`/`.blend1` files or `Art/Blender.rar`.
- End commit messages with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Implementers don't push.

**The owner's decisions for this import:**
- The expansion goes in Ye ("The Lindenmoor expansion is gonna go in Ye").
- It goes first after the foundation.
- The hub's pieces "move into the new map".
- Exits: "Together, NE corner".
- Edges are ungrippable (`RenseiNoGrip`), with no invisible walls.
- Ye's unnamed ground follows **Lindenmoor's law** once the hub is gone (2026-10-24: "Lindenmoor's (Recommended)").

**Ye place publishing:** the owner should not publish the Ye *place* between Task 5's prep and Task 9's checkpoint. Packages are unaffected unless a task says so.

---

## File map

| File | Responsibility |
|---|---|
| `Art/Studio/Regions/Lindenmoor/survey_ye.lua` (new) | Read-only Ye survey → JSON |
| `Art/Studio/Regions/Lindenmoor/check_survey.py` (new) | Checks the survey against the plan (keep list, budget, areas, pads) |
| `Art/Studio/Regions/Lindenmoor/ye_survey.json` (new, committed) | Survey result |
| `Art/Blender/lindenmoor/expansion_plan.py` (modify) | Marks crag cells |
| `Art/Blender/lindenmoor/expansion.py` (modify) | Tags crag tops/sides `RenseiNoGrip`; writes water segments to `water_segments.json` |
| `Art/Blender/lindenmoor/expansion_tests.py` (modify) | Crag-tag and water-converter checks |
| `Art/Blender/lindenmoor/water_convert.py` (new, pure) | Converts segments to `water.json` in kit format (village-local Rects) |
| `Art/Regions/Lindenmoor/layout.json` (modify) | Adds `KeepMapChildren`, `MapChild`, `PlaceId` |
| `Art/Regions/Lindenmoor/materials.json` (new) | The seven `LM_` expansion materials |
| `Art/Regions/Lindenmoor/water_segments.json` (renamed from `water.json`) | Water in segment form |
| `Art/Regions/Lindenmoor/water.json` (regenerated) | Water in kit form |
| `Art/Studio/Regions/Lindenmoor/layout.json` and `import/*` (generated, committed) | Export and import scripts |
| `Art/Studio/Regions/Lindenmoor/prep_ye.lua` (new) | Reversible Ye prep (`MODE = "apply"` or `"undo"`) |
| `Art/Studio/Regions/Lindenmoor/pads.json` (generated by Task 5) | Pad and trainer-spot world positions and heights |
| `Scripts/ServerScriptService/WorldService.lua` (modify) | `AreaAt`: the smallest containing box wins |
| `Scripts/ReplicatedStorage/Modules/Data/Rensei/Regions.lua` (modify) | The 10 new areas, and `HubLaw[Ye] = "Lindenmoor"` |
| `Scripts/ReplicatedStorage/Modules/Data/Rensei/Townsfolk.lua` (modify) | Lindenmoor roster (18 posts) |
| `Scripts/ReplicatedStorage/Modules/Data/Rensei/Investigation.lua`, `Quests.lua` (modify) | The two clue defs and their quests |
| `Scripts/ServerStorage/RenseiTests/Test_Regions.lua` (modify) | Expects `HubLaw` = Lindenmoor |
| `Art/Studio/Travel/src/Play_Road.lua` (modify) | Fixed spots mapped onto the new north-east road |
| `Scripts/ServerStorage/RenseiTests/Play_LindenmoorSmoke.lua` (new) | Ye smoke suite |
| `Documents/Lindenmoor Kit.md`, `Documents/Changelog.md` (modify) | Docs |

---

### Task 1: Survey Ye (read-only) and check it against the plan

**Files:**
- Create: `Art/Studio/Regions/Lindenmoor/survey_ye.lua`, `check_survey.py`, `ye_survey.json`

**Interfaces:**
- **Produces** `ye_survey.json`, used by Tasks 4, 5 and 8:

```json
{
  "Parts": 31998,
  "Baseplate": {"Pos": [0, -8, 0], "Size": [2048, 16, 2048]},
  "MapChildren": [{"Name": "Lindenmoor", "Class": "Model", "Parts": 12398, "Pivot": [x, y, z], "Box": [[x0,y0,z0],[x1,y1,z1]]}, ...],
  "Areas": [{"AreaName": "Lindenmoor", "Top": "Lindenmoor", "Box": [[...],[...]]}, ...],
  "Arrivals": [{"Point": "RoadStart", "Path": "World.Map.Lindenmoor.NorthRoad..."}, ...],
  "Trainers": [{"DialogueId": "trainer_flame", "Path": "Workspace.World.NPCs.Alchemy Trainers.Flame Alchemist", "Pivot": [44, 3, -24]}, ...],
  "Retire": [{"Path": "World.Map.Lindenmoor.NorthRoad"}, {"Path": "World.Map.Lindenmoor.HubRoad"}, {"Path": "World.Map.Lindenmoor.Station.BufferStop", "Pivot": [-270, 10, -369]}],
  "Spawns": [{"Name": "BanditSpawn_1", "Path": "...", "Pos": [x, y, z], "EnemyType": "..."}, ...],
  "GroundInInfill": 0
}
```

- **Classification:** `check_survey.py` maps each top-level `World.Map` child to one of:
  - **Keep, unchanged:** `Lindenmoor`, `Ground`, `HalvardsAdit`, `Baseplate`.
  - **Relocate to a pad:** `BurnedLaboratory`, `AshPit`, `FrozenStation`, `FrozenChamber`, `CrackedFootbridge`, `UnstableQuarry`, `SilentObservatory`, `GaleFloor`, `SilentForge`, `ForgeFloor`, `FoundryYard`, `LedgeCourse`, and the test arena `Wall` (both instances), `Curve`, `Hill`, `Step`, `TrainingGround`. `AlchemistSpawns` moves child by child with its site.
  - **Unknown:** any other name fails the check.

  Measured on 2026-10-24: 22 children, with two named `Wall`.

- [ ] **Step 1: Write the failing checker.** `check_survey.py <survey.json>` exits 1 and prints `PASS n / FAIL n` when any check fails. The checks:
  1. **Every Map child is classified.** No unknowns.
  2. **Budget.** `Parts` + the export's part count (from `Art/Studio/Regions/Lindenmoor/layout.json` once it exists; otherwise 40,414) ≤ 80,000.
  3. **Baseplate** at (0, −8, 0).
  4. **`GroundInInfill` == 0.**
  5. **Area overlaps.** No village `RenseiArea` box overlaps one of the 10 new boxes in `Art/Regions/Lindenmoor/layout.json`. A relocated trial site's own area may sit inside a new area: Task 8 makes the smallest box win.
  6. **Pad fit.** Each relocated piece's horizontal footprint radius (half the diagonal of its XZ box) is ≤ its pad radius. The pad table is in the design §5: burned lab 38, frozen 50, footbridge 50, observatory 45, forge 45, foundry graybox 50, practice yard 50. A site and its exam floor (e.g. `BurnedLaboratory` + `AshPit`) share one pad, so they're measured together.
  7. **Arrivals.** Exactly one `RoadStart` and one `Platform` arrival, and the `RoadStart` is under `World.Map.Lindenmoor.NorthRoad`.
  8. **Trainers.** All five trainers are found, in `World.NPCs`.

```python
import json, sys, math, os
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
KEEP = {"Lindenmoor", "Ground", "HalvardsAdit", "Baseplate"}
SITES = {  # pad id: map children placed on it together
    "res_burned_laboratory": ["BurnedLaboratory", "AshPit"],
    "res_frozen_station": ["FrozenStation", "FrozenChamber"],
    "res_cracked_footbridge": ["CrackedFootbridge", "UnstableQuarry"],
    "res_silent_observatory": ["SilentObservatory", "GaleFloor"],
    "res_silent_forge": ["SilentForge", "ForgeFloor"],
    "res_foundry_graybox": ["FoundryYard"],
    "res_practice_yard": ["LedgeCourse", "Wall", "Curve", "Hill", "Step", "TrainingGround"],
}
RELOCATE = {n for v in SITES.values() for n in v} | {"AlchemistSpawns"}
PASS = FAIL = 0
def check(ok, msg):
    global PASS, FAIL
    PASS, FAIL = PASS + bool(ok), FAIL + (not ok)
    if not ok: print("FAIL:", msg)
def overlap(a, b):
    return all(a[0][i] < b[1][i] and b[0][i] < a[1][i] for i in (0, 2))
def main(path):
    S = json.load(open(path, encoding="utf-8"))
    L = json.load(open(os.path.join(REPO, "Art", "Regions", "Lindenmoor", "layout.json"), encoding="utf-8"))
    for c in S["MapChildren"]:
        check(c["Name"] in KEEP | RELOCATE, f"unclassified map child {c['Name']}")
    exp = os.path.join(REPO, "Art", "Studio", "Regions", "Lindenmoor", "import", "expected.json")
    add = json.load(open(exp))["parts"] if os.path.exists(exp) else 40414
    check(S["Parts"] + add <= 80000, f"budget {S['Parts']} + {add} > 80000")
    check(S["Baseplate"]["Pos"] == [0, -8, 0], f"baseplate at {S['Baseplate']['Pos']}")
    check(S["GroundInInfill"] == 0, f"{S['GroundInInfill']} Ground parts in Infill cells")
    new = [m["Box"] for m in L["Markers"] if m["Tag"] == "RenseiArea"]
    for a in S["Areas"]:
        if a["Top"] in ("Lindenmoor", "Ground", "HalvardsAdit"):
            for b in new:
                check(not overlap(a["Box"], b), f"village area {a['AreaName']} overlaps a new area")
    pads = {l["Id"]: l for l in L["Landmarks"] if "reserve" in l["Kind"]}
    radius = {"res_burned_laboratory": 38, "res_frozen_station": 50, "res_cracked_footbridge": 50,
              "res_silent_observatory": 45, "res_silent_forge": 45, "res_foundry_graybox": 50, "res_practice_yard": 50}  # design §5
    by = {}
    for c in S["MapChildren"]:
        by.setdefault(c["Name"], []).append(c)
    for pad, names in SITES.items():
        boxes = [c["Box"] for n in names for c in by.get(n, [])]
        check(boxes, f"{pad}: none of {names} found")
        if boxes:
            x0 = min(b[0][0] for b in boxes); x1 = max(b[1][0] for b in boxes)
            z0 = min(b[0][2] for b in boxes); z1 = max(b[1][2] for b in boxes)
            check(math.hypot(x1 - x0, z1 - z0) / 2 <= radius[pad], f"{pad}: footprint {math.hypot(x1-x0, z1-z0)/2:.0f} > {radius[pad]}")
            check(pad in pads, f"{pad} not in the layout's landmarks")
    rs = [a for a in S["Arrivals"] if a["Point"] == "RoadStart"]
    check(len(rs) == 1 and "NorthRoad" in rs[0]["Path"], f"RoadStart arrivals {rs}")
    check(sum(a["Point"] == "Platform" for a in S["Arrivals"]) == 1, "Platform arrivals != 1")
    check(len(S["Trainers"]) == 5, f"trainers found: {len(S['Trainers'])}")
    print(f"PASS {PASS} / FAIL {FAIL}")
    sys.exit(1 if FAIL else 0)
if __name__ == "__main__":
    main(sys.argv[1])
```

- [ ] **Step 2: Run it on a hand-made bad survey.** For example, an unknown child `Foo` and `Parts` 50000. Expected: FAIL on both. Keep this as `test_check_survey.py`, which builds its fixtures in a temporary directory.

- [ ] **Step 3: Write `survey_ye.lua`.** It is read-only and returns `HttpService:JSONEncode(result)`.
  - **MapChildren:** for each `World.Map` child, record the part count, pivot and a world AABB. Use `GetBoundingBox()` for a Model, CFrame/Size for a Part, and the union of child parts for a Folder.
  - **Areas:** every `RenseiArea` in workspace, with `AreaName`, the top-level Map child it sits under, and its world AABB.
  - **Arrivals:** every `RenseiArrival`, with `Point` and full path.
  - **Trainers:** every Instance whose `DialogueId` starts with `trainer_` and that sits under `workspace`, with its pivot.
  - **Spawns:** every `RenseiEnemySpawn`, with its `EnemyType` attribute.
  - **Retire:** `World.Map.Lindenmoor.NorthRoad`, `World.Map.Lindenmoor.HubRoad`, and the `BufferStop` whose pivot is within 5 studs of (−270, 10, −369).
  - **GroundInInfill:** the count of `World.Map.Ground` BaseParts whose XZ centre lies in any `Infill` cell of the layout. Pass the cell list into the script as a JSON literal generated by a small Python step. **The layout is in world studs.**

  Because the bridge prints only the first return value, cut at 30k characters, write the JSON to a `StringValue` in `ServerStorage.LMSurvey` and read it back in chunks of 25k characters.

- [ ] **Step 4: Run the survey in Ye (Edit) and save `ye_survey.json`.** Run `python -I check_survey.py ye_survey.json`, then `test_check_survey.py`. Expected: the checker passes, or a fail names a real problem. Report every fail: an area overlap, a pad too small, or an unknown child means **stop and report; the controller rules**. Remove `ServerStorage.LMSurvey` afterwards.
- [ ] **Step 5: Commit** `survey_ye.lua`, `check_survey.py`, `test_check_survey.py` and `ye_survey.json`.

---

### Task 2: The crag carries `RenseiNoGrip` (plus two fixes from Task 1's survey)

> **Amendment from Task 1's survey (controller Rulings 3 and 4, 2026-10-24).** This task makes three changes to the expansion and then one Blender rebuild.
>
> **(a) The crag tag**, as below.
>
> **(b) A wider Keep mask.** The survey found 417 village `Ground` parts in the expansion's `Infill` cells, all within one 4-stud cell of Keep. Widen the expansion's Keep mask by one 4-stud cell, so no new ground is built there.
> - Add an `expansion_tests` check that the planned new ground never touches a cell holding a village Ground part. Use `Art/Studio/Regions/Lindenmoor/ye_survey.json` (export the Ground part XZ centres into the survey first if they aren't there).
> - After the rebuild, re-run `survey_ye.lua` and `check_survey.py`. Expected: `GroundInInfill` 0.
>
> **(c) Bigger pads.** For each `lindenmoor.reserve` pad:
> - Set its `Radius` to `pad_layout.arrange(...)["radius"] + 6` (PROPOSAL), using `Art/Studio/Regions/Lindenmoor/pad_layout.py`. `check_survey.py` prints these numbers.
> - Keep each pad flat and clear: no routes, fields or trees. Move a pad's centre up to 60 studs inside its own area only if it can't grow in place, and report every move.
> - Keep `expansion_tests`' flat-and-clear reserved-spot checks passing.
> - After the rebuild, `check_survey.py` must PASS its pad checks.
>
> **(e) Share the keep mask** (Task 1 review, Minor 1). Factor the Keep mask into `expansion_plan.keep_mask(...)` and use it from both `plan()` and `check_survey.py`'s `infill_runs()`. Then re-stamp the survey's Infill runs and update the hard-coded 10,863 cell count in `test_check_survey.py`.
>
> **(d) A new pad for the test arena** (owner: "Keep it in the map"; Ruling 5). Add a `lindenmoor.reserve` landmark `res_test_arena` in North Meadows near the practice yard, clear of routes, the training field and the ridge marker, with radius about 122 (PROPOSAL: `arrange()` radius + 6). The practice yard pad keeps `LedgeCourse` only.
>
> **The rebuild.** Re-run every stage the pad change affects: ground, fields, trees, landmarks and markers. Re-render the aerial view and the views that show a changed pad. The owner sees that seven clearings grew slightly; send them the aerial. Keep the part count at or under 42,000.

**Files:**
- Modify: `Art/Blender/lindenmoor/expansion_plan.py` (the height function at ~:180-200 and the plan's `tops`/`sides`), `Art/Blender/lindenmoor/expansion.py` (`ground()` ~:198-226), `Art/Blender/lindenmoor/expansion_tests.py`

**Interfaces:**
- **Produces:**
  - `plan().tops` gains a 7th field, `crag: bool`: `(i, j, w, d, y, m, crag)`.
  - `plan().sides` gains a 7th field: `(i, j, w, d, lo, hi, crag)`.
  - A merged rect never mixes crag and non-crag cells: the merge key includes the crag flag.
  - In `expansion.ground()`, a top or side with `crag=True` gets `rs_tags = "RenseiNoGrip"`. Export then writes the tag as row field 16, since export.py already supports it.

**Why the side, too:** the climbable inner face of the crag is the side block of a crag column. It reaches down to its lowest neighbour − 1, so that is the part a climber grabs.

- [ ] **Step 1: Write the failing checks** in `expansion_tests.py`:
  - every cell whose height came from an `edge_wall_*` Crag box is reported `crag=True` in `tops`;
  - every side whose `hi` equals a crag column's top is `crag=True`;
  - no top with `crag=False` lies within a Crag box's reach;
  - **at least one crag side per edge** (west, east, north, south) has `hi − lo ≥ 80`, which proves the face is tagged, not just the crest.
- [ ] **Step 2: Run** `python -I Art/Blender/lindenmoor/expansion_tests.py`. Expected: the new checks FAIL. The 60 existing checks still pass.
- [ ] **Step 3: Implement.**
  - In the height sampler, return `(h, flat, crag)`, where `crag = True` when the `Crag` branch set the height.
  - Carry the flag into the cell grid, include it in the merge key, and add it to `tops` and `sides`. A side belongs to the column whose `hi` it reaches.
  - In `ground()`, unpack the extra field and set `o["rs_tags"] = "RenseiNoGrip"` on the part returned by `pb(...)` when `crag` is true.
- [ ] **Step 4: Run the tests.** Expected: all pass, including the 60 old ones.
- [ ] **Step 5: Rebuild in Blender.** This needs the Blender coordination in the Global Constraints.
  - Open `Lindenmoor_Expansion.blend`.
  - Run `expansion.run("ground")`. It may outlive the bridge's 300 s wait; watch for completion with `count()`.
  - Then run `expansion.count()` and `expansion.save()`.
  - Check in Blender that the parts with `rs_tags == "RenseiNoGrip"` exist on all four edges.
  - Check that `count()["parts"]` stays ≤ 42,000. The crag flag may split a few merges.
- [ ] **Step 6: Commit** the three `.py` files.

---

### Task 3: Water in the import format

**Files:**
- Create: `Art/Blender/lindenmoor/water_convert.py` (pure)
- Modify: `Art/Blender/lindenmoor/expansion.py` (`water()` ~:228-246 writes `water_segments.json`), `expansion_tests.py`
- Rename: `Art/Regions/Lindenmoor/water.json` → `water_segments.json` (`git mv`)
- Generate: `Art/Regions/Lindenmoor/water.json` in kit format

**Interfaces:**
- **Consumes:** segments `{Id, From:[x,z], To:[x,z], Width, Top, Bed}` in world studs (x east, z north).
- **Produces:** `convert(segments, cell=2) -> {"Note": str, "Boxes": [{"Id": str, "Rect": [x0, z0, x1, z1], "Top": float, "Bed": float}]}`.
  - Rects are **village-local**: world − export origin (0, 4, −650). That means `x`, `z + 650`, `Top − 4` and `Bed − 4`, because `finish.lua` adds the origin back.
  - Rects are axis-aligned. Each covers merged `cell`-stud cells whose centre lies within `Width/2` of the segment.
  - Cells are merged with the region builder's `merge.rects`. Import it as `region_builder.merge` from `Art/Blender` on `sys.path`.
  - `python -I water_convert.py` reads `water_segments.json` and writes `water.json`.

- [ ] **Step 1: Write the failing checks** in `expansion_tests.py` (`import water_convert as WC`):
  - **Frame:** a segment From (0, −650) To (10, −650), Width 4, Top 5.2, Bed 1 gives boxes with every z near 0 and Top 1.2, Bed −3.
  - **Coverage:** for every real segment, 50 sample points along its centreline each lie in some box after adding the origin back.
  - **Spill:** the total box area per segment is ≤ 1.15 × the segment's exact area (length × width). PROPOSAL tolerance at cell = 2.
  - **Kit's own rule:** every box satisfies `x0 < x1`, `z0 < z1` and `Bed < Top`.
- [ ] **Step 2: Run.** Expected: FAIL (no module).
- [ ] **Step 3: Implement** `water_convert.py`:

```python
"""Lindenmoor water: channel segments (world studs) -> kit.py's water.json (village-local axis-aligned Rects).
finish.lua adds the export origin back, so this subtracts it. PROPOSAL: 2-stud cells (spill <= ~15% on diagonals)."""
import json, math, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))  # Art/Blender
from region_builder import merge
ORIGIN = (0.0, 4.0, -650.0)  # export.py's Lindenmoor origin
REGION = os.path.normpath(os.path.join(HERE, "..", "..", "Regions", "Lindenmoor"))

def seg_dist(px, pz, ax, az, bx, bz):
    dx, dz = bx - ax, bz - az
    L2 = dx * dx + dz * dz
    t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / L2))
    return math.hypot(px - (ax + t * dx), pz - (az + t * dz))

def convert(segments, cell=2):
    boxes = []
    for s in segments:
        (ax, az), (bx, bz), r = s["From"], s["To"], s["Width"] / 2
        x0, x1 = math.floor((min(ax, bx) - r) / cell), math.ceil((max(ax, bx) + r) / cell)
        z0, z1 = math.floor((min(az, bz) - r) / cell), math.ceil((max(az, bz) + r) / cell)
        cells = {(i, k): 1 for i in range(x0, x1) for k in range(z0, z1)
                 if seg_dist((i + 0.5) * cell, (k + 0.5) * cell, ax, az, bx, bz) <= r}
        for n, (i, k, w, d, _) in enumerate(merge.rects(cells, max_span=64)):
            X0, Z0 = i * cell - ORIGIN[0], k * cell - ORIGIN[2]
            boxes.append({"Id": f"{s['Id']}_{n}", "Rect": [X0, Z0, X0 + w * cell, Z0 + d * cell],
                          "Top": round(s["Top"] - ORIGIN[1], 3), "Bed": round(s["Bed"] - ORIGIN[1], 3)})
    return {"Note": "Village-local water boxes (world - export origin (0, 4, -650)); finish.lua adds the origin back. PROPOSAL.",
            "Boxes": boxes}

if __name__ == "__main__":
    segs = json.load(open(os.path.join(REGION, "water_segments.json"), encoding="utf-8"))["Boxes"]
    out = convert(segs)
    with open(os.path.join(REGION, "water.json"), "w", encoding="utf-8") as f:
        json.dump(out, f, indent=1)
    print(f"{len(segs)} segments -> {len(out['Boxes'])} boxes")
```

- [ ] **Step 4: Point the export at the new file.**
  - `git mv` the old file to `water_segments.json`.
  - Change `expansion.water()` to write `water_segments.json`, the same content as before.
  - Run `water_convert.py`, then the tests. Expected: all pass.
  - Check the output: `water.json` has a few hundred boxes or fewer (more is fine if `finish.lua` stays under the Luau chunk limit).
- [ ] **Step 5: Commit** the `.py` files, `water_segments.json` (the rename) and the new `water.json`.

---

### Task 4: Export and generate the import

**Files:**
- Modify: `Art/Regions/Lindenmoor/layout.json` (top-level `KeepMapChildren`, `MapChild`, `PlaceId`)
- Create: `Art/Regions/Lindenmoor/materials.json`
- Generate (commit): `Art/Studio/Regions/Lindenmoor/layout.json`, `Art/Studio/Regions/Lindenmoor/import/*`

**Interfaces:**
- **Consumes:**
  - Task 1's classification;
  - Task 2's tagged ground;
  - Task 3's `water.json`;
  - `kit.py` (reads the region file's `KeepMapChildren`, `MapChild` and `NoCollide`; see `Documents/Region Builder.md` §4).
- **Produces:**
  - **The import scripts** in `Art/Studio/Regions/Lindenmoor/import/`: `chunk_NN.lua`, `expected.json`, `finish.lua`, `restore.lua` and `unstrip.lua`.
  - **`KeepMapChildren`** = every current `World.Map` child name. There are 23 children, with `Wall` appearing twice; use the survey's names. Hub pieces are already relocated by Task 5, and stay Map children, so nothing is moved into the import's backup. The list is: `["Lindenmoor","Ground","HalvardsAdit","Baseplate","AlchemistSpawns","BurnedLaboratory","AshPit","FrozenStation","FrozenChamber","CrackedFootbridge","UnstableQuarry","SilentObservatory","GaleFloor","SilentForge","ForgeFloor","FoundryYard","LedgeCourse","Wall","Curve","Hill","Step","TrainingGround"]`. Use Task 1's survey for the exact names.
  - **`MapChild`** = `"LindenmoorExpansion"`.
  - **`PlaceId`** = 106992859583940.

**Ruling: relocate first, keep everything.**
- **What it means:** the hub pieces are moved onto their pads by Task 5's reversible script *before* the import, and kept. They are not swept into the import's backup and dragged back out.
- **Why:**
  - Their tags are never stripped, so `unstrip.lua` isn't needed.
  - The two same-named `Wall` children cause no trouble.
  - Rollback becomes `restore.lua` plus `prep_ye.lua` with `MODE = "undo"`.
- **Cost if wrong:** none. The hub pieces end up on the same pads either way.

- [ ] **Step 1: Write the failing check.** Run `python -I Art/Studio/Regions/kit.py Lindenmoor`. Expected: it exits with "no export at Art/Studio/Regions/Lindenmoor/layout.json".
- [ ] **Step 2: Add the keys and materials.**
  - Add the three keys to `Art/Regions/Lindenmoor/layout.json`. Leave its own `Keep` (area objects) untouched; kit.py ignores it.
  - Write `materials.json` for `LM_GrassGround`, `LM_GroundMeadow`, `LM_GroundSide`, `LM_Ballast`, `LM_Falls`, `LM_Foam` and `LM_Shadow`. Take each one's Roblox material and colour from the layout's `Materials`, in the format `{"<name>": {"Material": "<Enum.Material>", "Color": "<hex>", "Transparency": 0}}`.
- [ ] **Step 3: Export** (Blender coordination). Run `expansion.export_expansion("C:/Users/Owner/Rensei-Game-Design/Art/Studio/Regions/Lindenmoor/layout.json")`. Check that the export's rows include field 16 tags: `RenseiNoGrip` on Ground parts, plus `RenseiArea`, `RenseiClue`, `RenseiPost`, `RenseiMarker`, `RenseiEnemySpawn` and `RenseiLedge`.
- [ ] **Step 4: Generate.** Run `python -I Art/Studio/Regions/kit.py Lindenmoor`. Expected: it generates without error. Then check that `import/expected.json` shows:
  - parts ≤ 42,000;
  - tags: `RenseiArea` 10, `RenseiClue` 2, `RenseiPost` 18, `RenseiEnemySpawn` 6, `RenseiMarker` 6, `RenseiLedge` ≥ 1, and `RenseiNoGrip` > 0;
  - the keep list as above;
  - `MapChild` `LindenmoorExpansion`;
  - the walk-through names from `studio_kit.NO_COLLIDE` and the kinds `[EdgeStone]`.

  `EdgeGap` is builder-only and must not appear.
- [ ] **Step 5: Re-run** `check_survey.py ye_survey.json`, which now uses the real part count. Expected: PASS.
- [ ] **Step 6: Commit** the region file, `materials.json`, the export and `import/*`.

---

### Task 5: Reversible Ye prep: retire the old road, move the hub pieces and trainers onto their pads

> **Amendment from Task 1's survey (controller Ruling 4, 2026-10-24).** Pieces are placed **by slot**, not by keeping today's relative layout. `pads.json` comes from `Art/Studio/Regions/Lindenmoor/pad_layout.arrange(...)`: each piece's slot offset from its pad centre, plus each pad's ground height. Each Map child goes to its pad centre plus its slot offset; its lowest point goes to the pad's height.
> - **Practice yard and test arena (owner, 2026-10-24: keep the test arena in the map; Ruling 5):** `res_practice_yard` holds `LedgeCourse` only. A new pad, `res_test_arena` (added by Task 2), holds the test arena (both `Wall`s, `Curve`, `Hill`, `Step`, `TrainingGround`) as one block that keeps its internal layout.
> - **`AlchemistSpawns` children** move by their own site's offset. A spawn that would land outside its pad is pulled in along its direction to the pad radius − 8 (PROPOSAL; Ruling 7).
> - **`World.EnemySpawns` on the old hub** (Ruling 8): back up and retire the two `GruntSpawn`s, since the expansion's six Grunt spawns replace them. Move the `EliteSpawn` to a clear spot in Bramble Woods near the expansion's Grunt spawns (PROPOSAL). Both are reversible through `PrepFrom` and the backup.
> - **This supersedes** "the group's XZ centre goes to the pad's (x, z)" below.

**Files:**
- Create: `Art/Studio/Regions/Lindenmoor/prep_ye.lua`, `Art/Studio/Regions/Lindenmoor/pads.json`

**Interfaces:**
- **Consumes:**
  - `ye_survey.json`;
  - the pads in `Art/Regions/Lindenmoor/layout.json` (landmarks whose `Kind` contains `reserve`);
  - the `TrainerSpot` markers;
  - pad and spot ground heights from `expansion_plan.plan()`. The `pads.json` generator is `python -I -c` over `expansion_plan` and writes `{pad_id: {"At": [x, y, z]}, "trainer_<element>": {"At": [x, y, z], "Yaw": 0}}`, with `y` = the plan's top height at that point.
- **Produces:** `prep_ye.lua` with `local MODE = "apply"` or `"undo"` at the top.
  - **`apply`:**
    1. Refuses if `ServerStorage.RenseiBackups["Pre-LindenmoorExpansion_2026-10-24"]` exists.
    2. Clones `World.Map.Lindenmoor.NorthRoad`, `World.Map.Lindenmoor.HubRoad` and the `BufferStop` at (−270, 10, −369) into that backup, keeping each path in an attribute `FromPath`. Then it destroys the originals.
    3. For each pad, moves its Map children together. They keep their relative layout: the group's XZ centre goes to the pad's (x, z), and the group's lowest point goes to the pad's y. Each child records its old pivot as the attribute `PrepFrom` (a CFrame string).
    4. Moves each `AlchemistSpawns` child with its site, by the same offset as the site.
    5. Moves each trainer in `World.NPCs.Alchemy Trainers` to its `TrainerSpot` (by element), facing into the field (+Z), and records `PrepFrom`.
    6. Sets the attribute `LindenmoorPrep = "applied"` on `World.Map`.
  - **`undo`:**
    1. Moves every instance with `PrepFrom` back to it and clears the attribute.
    2. Puts the cloned pieces back to their `FromPath` parents.
    3. Deletes the backup folder.
    4. Clears `LindenmoorPrep`.
  - **Both modes:**
    - wrap their work in a pcall with a journal, so an error mid-way is undone;
    - return a summary: moved N, retired M, trainers 5;
    - record a ChangeHistoryService waypoint when available.

- [ ] **Step 1: Write the failing test.** Add `test_prep.lua` (Edit), which:
  1. snapshots Ye: every `World.Map` and `World.NPCs` descendant's full name and pivot, rounded to 0.01, plus per-tag counts in workspace;
  2. runs `prep_ye.lua` apply;
  3. asserts: no `RenseiRoadPassage` under `Map.Lindenmoor`; exactly zero `RoadStart` arrivals; each pad group within its pad radius; trainers at their spots;
  4. runs `prep_ye.lua` undo;
  5. asserts that the snapshot equals the start.

  Run it before `prep_ye.lua` exists. Expected: FAIL.
- [ ] **Step 2: Generate `pads.json`, then implement `prep_ye.lua`** as specified above.
- [ ] **Step 3: Run `test_prep.lua` in Ye (Edit).** Expected: PASS, and Ye is unchanged afterwards (the test's own final assert). Leave Ye **un-prepped**: Task 6 applies it for real.
- [ ] **Step 4: Commit** `prep_ye.lua`, `pads.json`, `test_prep.lua` and the `pads.json` generator script.

---

### Task 6: The import into Ye (dry run, then the owner's confirm)

**Files:**
- No new code: runs Task 4's import and Task 5's prep.
- Modify: `Documents/Lindenmoor Kit.md` (record what was done, with the backup names).

**Interfaces:**
- **Consumes:** `prep_ye.lua`, and `import/chunk_NN.lua`, `finish.lua`, `restore.lua`.
- **Produces:**
  - `World.Map.LindenmoorExpansion` in Ye, with its water, `RG_` variants (if any) and tags;
  - the prep applied;
  - the backups `Pre-LindenmoorExpansion_2026-10-24` and the import's `Pre-Region_Lindenmoor_<date>`, which holds no moved children because all are kept.

- [ ] **Step 1: Prep.** Run `prep_ye.lua` with `MODE = "apply"` in Ye (Edit). Expected: the summary reports 5 trainers moved and the pad groups placed.
- [ ] **Step 2: Build the staging.** Run every `chunk_NN.lua` in order (Edit). Expected: `ServerStorage.RegionStaging` holds the build.
- [ ] **Step 3: Dry run.**
  - Set `ServerStorage.RegionStaging:SetAttribute("DryRun", true)` and run `finish.lua`.
  - Expected: `"dry run ok: …"`, counts equal to `expected.json`, and the keep line "would move: (none)" with every Map child on "would keep".
  - Anything on "would move" means **stop**: the controller rules.
- [ ] **Step 4: STOP and ask the owner to confirm the real import.** This is an irreversible-feeling change to the live main place. The controller asks in chat, with the dry-run summary and the rollback steps. Don't continue without a clear yes.
- [ ] **Step 5: Real run** (after the owner's yes).
  - Rerun the chunks if the dry run destroyed the staging.
  - Set `RegionStaging:SetAttribute("Confirm", "Lindenmoor")` and run `finish.lua`.
  - Expected: a summary showing kept 22, moved 0, the water filled and the parts parented.
- [ ] **Step 6: Verify.**
  - Ye's part count equals the survey plus the expansion, within ±50.
  - Every tag count in `World.Map.LindenmoorExpansion` matches `expected.json`.
  - `Terrain:ReadVoxels` at 3 creek sample points (centrelines from `water_segments.json`) reads Water.
  - Exactly zero `RoadStart` arrivals: the old one is retired, and Task 7 builds the new one.
- [ ] **Step 7: Document and commit.** Record in `Documents/Lindenmoor Kit.md` what ran, the backup names and the exact rollback (restore.lua, then `prep_ye.lua` undo, then re-run the travel suites). Commit.

---

### Task 7: The north-east road (`setup.lua`) and the travel suites

**Files:**
- Modify: `Art/Studio/Travel/src/Play_Road.lua`, and its copy in Ye's `ServerStorage.RenseiTests`
- Run: `Art/Studio/Regions/bundle_setup.py`, `setup.lua`, `Test_SetupContract.lua`

**Interfaces:**
- **Consumes:**
  - the `RoadPassage` marker in `World.Map.LindenmoorExpansion`, with Legs in world studs from (686, 661), Threshold 359, RoadStart 305 and Encounters [85, 195, 265];
  - `setup.lua` with `REGION = "Lindenmoor"`, `MAP_CHILD = "LindenmoorExpansion"`, `ORIGIN = Vector3.zero`.
- **Produces:**
  - `World.Map.LindenmoorExpansion.Travel` with the road passage, its threshold, encounters and the one `RoadStart` arrival;
  - `Play_Road` checking the new road.

- [ ] **Step 1: Run the place-wide contract test** with ROOT = `workspace.World.Map.LindenmoorExpansion`. Expected: FAIL. There is no RoadStart and no passage yet; the five TrainerSpots don't count.
- [ ] **Step 2: Build the road.**
  - Bundle: `python -I Art/Studio/Regions/bundle_setup.py setup <scratch>/setup.lua --origin 0,0,0` (with REGION and MAP_CHILD set).
  - Run it in Ye (Edit).
  - Expected summary: the road built, "skipped (not travel pieces): TrainerSpot 5", and no clash with the village's Platform arrival and trains.
- [ ] **Step 3: Re-run the contract test.** Expected: all pass, place-wide: one RoadStart and one Platform.
- [ ] **Step 4: Remap `Play_Road`.**
  - Its fixed spots map from the old North Road. Remap them onto the new passage, reading the built `RoadPoint` attachments by `S` rather than hard-coded coordinates, so it can't drift again.
  - Run Play_Road in Ye: expected to fail before the remap and pass after.
  - Then run the hooked Play suites: Play_Travel, Play_Station, Play_Gate, Play_Arrive and Play_Boot. Expected: pass. The known Cabin-ticket failures in Travel and RideEvents stay as known.
- [ ] **Step 5: Commit.** Commit `Play_Road.lua`, and record the setup summary in the Kit doc.

---

### Task 8: Game data: areas, law, clues, townsfolk, and the smallest area wins

**Files:**
- Modify:
  - `Scripts/ServerScriptService/WorldService.lua` (`AreaAt`, about :37-40);
  - `Scripts/ReplicatedStorage/Modules/Data/Rensei/Regions.lua` (`Areas`, `HubLaw`);
  - `Scripts/ReplicatedStorage/Modules/Data/Rensei/Townsfolk.lua`;
  - `Scripts/ReplicatedStorage/Modules/Data/Rensei/Investigation.lua`;
  - `Scripts/ReplicatedStorage/Modules/Data/Rensei/Quests.lua`;
  - `Scripts/ServerStorage/RenseiTests/Test_Regions.lua`.
- Test: `Scripts/ServerStorage/RenseiTests/Play_LindenmoorData.lua` (new)

**Interfaces:**
- **`AreaAt(Position)`:** returns the `AreaName` of the **smallest-volume** `RenseiArea` box containing the point. It used to return the first match. Relocated trial sites keep their own boxes, which lie inside the new areas (e.g. the Burned Laboratory inside Bramble Woods), so the smaller box must win.
- **`Regions.Areas`:** gains the ten new area names, each mapped to `"Lindenmoor"`: Outlying Farmsteads, Mine Approach, Mill Creek Gorge, East Lookout, Bramble Woods, Training Field, Ridge Marker, North Meadows, Cypress Ridge Rim and Northeast Gap.
- **`Regions.HubLaw`:** becomes `{[Places.Regions.Lindenmoor.PlaceId] = "Lindenmoor"}` (owner, 2026-10-24).
- **`Townsfolk.Regions.Lindenmoor`:** 18 entries, one per `RenseiPost` PostId in the layout, in the TownsfolkLogic format:

```lua
{Id = "lm_farm1", Name = "Aldric Venn", Job = "Farmer", JobLine = "Wheat won't cut itself.", Faction = "Townsfolk", Look = "Amestris",
 Schedule = {{From = 6, To = 18, Post = "lm_farm1_field"}, {From = 18, To = 6, Post = "lm_farm1_home"}}},
```

  Read `TownsfolkLogic.Validate` for the exact required fields, nation names and the rule that the hours must cover 0–24. Pair each Work/Counter post with a Home post, and give Shelter posts to the townsfolk whose day is nearest them. All names and lines are original and labelled PROPOSAL.
- **Investigation:**
  - `lm_ridge_marker = {Title = "Ridge Marker", Text = ..., Evidence = "lm_ridge_survey", StartsQuest = "lm_ridge"}`;
  - `lm_mine_shaft = {Title = "Boarded Shaft", Text = ..., Evidence = "lm_shaft_ore", StartsQuest = "lm_mine"}`.

  Plus their evidence defs, and two one-stage quests, `lm_ridge` and `lm_mine`, in `Quests.lua` with an `Evidence` objective. The content is PROPOSAL, and must not give away Halvard's Adit's own quest.

- [ ] **Step 1: Write the failing tests.**
  - **`Test_Regions` (Edit):** `HubLaw[Ye] == "Lindenmoor"`, and each of the 10 names maps to Lindenmoor.
  - **`Play_LindenmoorData` (Play, hooked):**
    - **Area lookup:** `WorldService.AreaAt` at the centre of each of the 10 new boxes returns its name. At the relocated Burned Laboratory site centre it returns "Burned Laboratory", not "Bramble Woods".
    - **Clue quests:** inspecting each clue starts its quest. Use the InvestigationService handler, as `Play_Clue` does.
    - **Townsfolk:** `TownsfolkService` loads the Lindenmoor roster without a validation refusal, and every townsperson stands at its post for the current hour (hold the clock at 10:00).
- [ ] **Step 2: Run them.** Expected: FAIL.
- [ ] **Step 3: Implement.**
  - **Backups first:** back up `WorldService`, `Regions`, `Townsfolk`, `Investigation` and `Quests` in Studio before editing.
  - **`AreaAt`:** among the containing boxes, choose the one with the smallest `Size.X * Size.Y * Size.Z`. Keep the point-in-part test.
  - **Repo copies:** keep them equal to Studio.
- [ ] **Step 4: Run them, plus the regression suites.** Run `Test_Regions`, `Play_LindenmoorData`, Play_Townsfolk, Play_TownsfolkCrowd, Play_Clue, Play_Heat, Play_Morality and Play_Rumours (Rumours first). Expected: all pass, apart from the known flakes in the Region Foundation ledger.
- [ ] **Step 5: Spawn sanity.** List the 6 new Grunt spawns and the old `BanditSpawn_1/2` (under `Map.Lindenmoor`). Per the design ("The hub's bandit spawns are replaced by the expansion's Grunt spawns"), if a BanditSpawn sits on the old hub ground, now North Meadows, back it up and remove it. Record which, with positions, in the report.
- [ ] **Step 6: Commit** all the repo copies and the new test.

---

### Task 9: Ye smoke suite, docs, and the publish checkpoint

**Files:**
- Create: `Scripts/ServerStorage/RenseiTests/Play_LindenmoorSmoke.lua`
- Modify: `Documents/Lindenmoor Kit.md`, `Documents/Changelog.md`, `Documents/Backlog.md` (tick the import)

**Interfaces:**
- **Consumes:** everything above.

- [ ] **Step 1: Write `Play_LindenmoorSmoke`** (Play, hooked). It checks that:
  - **The crag can't be grabbed:** a climb is refused on the crag. Use `MovementState.Grippable` = false on a crag part, and the server wall-in-reach check refusing it, at one point per edge.
  - **The water is real:** water voxels at 3 creek and gorge points.
  - **The lamps follow the clock:** the expansion's `NightOnly` lamps are on at a held 23:00 and off at a held 12:00.
  - **Travel is single:** exactly one RoadStart, one Platform and one platform train for `LindenmoorFoundry`.
  - **The ledge works:** the gorge `RenseiLedge` strip exists, with its front face toward its wall.
  - **Every trial still starts:** each `RenseiTrial` is under workspace, with its `TrialId`.
  - **The trainers can be talked to:** each of the 5 trainers has its `DialogueId` and stands within 6 studs of its spot.
- [ ] **Step 2: Run it in Ye.** Expected: PASS. If a check fails, fix the cause in the task that owns it (the controller rules), never by loosening the check.
- [ ] **Step 3: Write the docs.**
  - **`Lindenmoor Kit.md`:** tick the checklist and record the final part count. Put the rollback steps in one place: `restore.lua`, then `prep_ye.lua` undo, then revert the data files from their backups, then the travel suites.
  - **`Changelog.md`:** one entry for the import. Its `### Discord announcement` is a real, player-facing post, held until the owner publishes, covering:
    - the land around Lindenmoor;
    - the north-east road;
    - the farms, gorge, mine, woods and meadows;
    - the trainers' new training field;
    - the trial sites' new homes.
- [ ] **Step 4: Name the publish checkpoint** to the owner (the controller does this):
  - **Ye place:** the new map, and the hub pieces moved.
  - **The Modules package:** `Regions`, `Townsfolk`, `Investigation` and `Quests`.
  - **RenseiServer:** `WorldService`.

  Ask the owner to walk the new land in Play once before publishing. Point out that their real save's Cabin ticket makes two travel tests fail; that isn't a regression.
- [ ] **Step 5: Commit.**

---

## Self-review notes

- **Spec and checklist coverage:**
  - Orientation, keeping the village: Tasks 4–6 (KeepMapChildren, MapChild).
  - Hub pieces moved: Task 5.
  - Exits in the NE corner: Task 7.
  - Crag: Task 2.
  - Water: Task 3.
  - Budget: Tasks 1 and 4.
  - Area overlaps: Tasks 1 and 8.
  - TrainerSpots: Tasks 5 and 7.
  - Retiring the old road: Task 5.
  - ORIGIN (0,0,0): Task 7.
  - Watching the first real run: Task 6 (stop for the owner).
  - No Station marker: Task 4's expected tags (there is no Station `RenseiMarker`).
  - HubLaw: Task 8 (owner's answer).
  - Game data (areas, clues, roster, spawns): Task 8.
  - Play-testing: Tasks 7 and 9.
- **Deferred, not in this plan:**
  - the Mover's map-scan cost at Ye's size (the Foundry plan's performance check) — this plan watches the Play suites' timing only;
  - the travel test ticket wrapper (a Region Foundation follow-up).
- **Names used across tasks:**
  - `KeepMapChildren` and `MapChild` `LindenmoorExpansion`;
  - `prep_ye.lua` with `MODE` apply/undo, the attribute `PrepFrom`, and the backup `Pre-LindenmoorExpansion_2026-10-24`;
  - `water_segments.json` → `water.json`;
  - `plan().tops` and `sides` with a 7th field `crag`;
  - `AreaAt`: smallest box wins.

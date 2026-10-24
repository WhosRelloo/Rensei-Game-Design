"""Blender-side checks on the region builder's Blender stages (Tasks 9 and 10). Run through the Blender bridge:
    python -I Art/Tools/blender_mcpc.py code @Art/Blender/region_builder/tests/blender_check.py

It builds Testbed with build.run("Testbed", "ground,routes,markers") (which refuses a file with unsaved changes, opens
an empty file and saves only Art/Blender/Regions/Testbed.blend), then checks the scene, water.json, the material table
and export.py's row field 16 (exported to a temp folder). Task 10 (kit_main) then builds every stage with
build.run("Testbed", "all"), renders included, and checks the buildings, the practice court, ledges, lamps, cover,
the edge ridges and EdgeGaps, the export, and the whole rail-town kit (built in a gallery, then the file is reverted).
Sets `result` to a dict: {"pass": bool, "fails": [...], ...}."""
import importlib, json, math, os, sys, tempfile, traceback

BLENDER = r"C:/Users/Owner/Rensei-Game-Design/Art/Blender"
REPO = os.path.normpath(os.path.join(BLENDER, "..", ".."))
if BLENDER not in sys.path:
    sys.path.insert(0, BLENDER)
# Blender keeps modules between runs: drop ours so every run checks the code on disk
for _m in [m for m in list(sys.modules) if m == "region_builder" or m.startswith("region_builder.")
           or m == "lindenmoor.export"]:
    del sys.modules[_m]

FAILS, PASSES = [], []
INFO = {}


def check(name, ok, detail=""):
    (PASSES if ok else FAILS).append(name if ok else f"{name}: {detail}")


def tags_of(o):
    return [t for t in str(o.get("rs_tags", "")).split(",") if t]


def main():
    import bpy
    from mathutils import Vector
    from region_builder import build, materials

    from region_builder import heightfield as HF, schema, stages as ST
    import dataclasses

    # the over-budget path: a 1-part budget (markers only, so the run is quick)
    over = build.run("Testbed", "markers", budget=1)
    check("over budget: over is True", over["over"] is True and over["budget"] == 1 and over["parts"] == 4, over)
    check("over budget: the scene carries rs_over_budget",
          bpy.context.scene.get("rs_over_budget") is True or bpy.context.scene.get("rs_over_budget") == 1,
          dict(bpy.context.scene.items()) if hasattr(bpy.context.scene, "items") else None)

    out = build.run("Testbed", "ground,routes,markers")
    layout = schema.load(os.path.join(REPO, "Art", "Regions", "Testbed", "layout.json"))
    grid = HF.sample(layout, cell=build.CELL)
    INFO["run"] = {k: out[k] for k in ("objects", "parts", "budget", "over")}
    s = bpy.context.scene
    bpy.context.view_layer.update()
    check("scene is Region_Testbed", s.name == "Region_Testbed", s.name)
    check("saved as Art/Blender/Regions/Testbed.blend",
          os.path.normcase(bpy.data.filepath) == os.path.normcase(os.path.join(BLENDER, "Regions", "Testbed.blend")),
          bpy.data.filepath)
    check("no Lindenmoor scene in the file", not any(x.name.startswith("Lindenmoor") for x in bpy.data.scenes),
          [x.name for x in bpy.data.scenes])

    # parts per group (a part = a mesh with rs_kind under a prefab root, as export.py counts them)
    groups = {}
    for o in s.objects:
        if o.type == "MESH" and o.get("rs_kind") and o.parent and o.parent.get("rs_prefab"):
            g = o.parent.users_collection[0].name.split(".")[0]
            groups.setdefault(g, []).append(o)
    INFO["parts_by_group"] = {g: len(v) for g, v in groups.items()}
    ground = groups.get("Ground", [])
    INFO["ground_parts"] = len(ground)
    check("Ground has parts", len(ground) > 0)
    check("run's part count = parts under prefabs", out["parts"] == sum(len(v) for v in groups.values()),
          (out["parts"], INFO["parts_by_group"]))
    roots = [o for o in s.objects if o.get("rs_prefab") == "Ground"]
    check("Ground is one prefab per 64x64 tile (16 for 256x256)", len(roots) == 16, len(roots))

    # Top slabs: 1 stud thick, top face on a whole stud
    tops = [o for o in ground if o.name.split("_")[-1].startswith("Top")]
    bad = []
    for o in tops:
        z_top = o.matrix_world.translation.z + o["rs_size"][2] / 2
        if abs(z_top - round(z_top)) > 1e-4 or abs(o["rs_size"][2] - 1) > 1e-6:
            bad.append((o.name, round(z_top, 4), o["rs_size"][2]))
    INFO["top_slabs"] = len(tops)
    check("every Top slab's top face is at a whole-stud height", tops and not bad, bad[:5])
    ramps = [o for o in ground if o.name.split("_")[-1].startswith(("Ramp", "Under"))]
    INFO["ramps"] = len([o for o in ramps if "Ramp" in o.name])
    check("ramps are 1.2 thick", all(abs(o["rs_size"][2] - 1.2) < 1e-6 for o in ramps if "Ramp" in o.name))
    under = ST.stair_cells(layout, grid)
    INFO["stair_cells"] = len(under)
    check("the climb's stairs cover some cells", len(under) > 0)

    def cell_at(o):
        t = o.matrix_world.translation
        return ST._cell_of(grid, t.x, t.y)
    on = [o.name for o in ramps if cell_at(o) in under]
    check("no Ramp or Under part under a stair run", not on, on)

    # Side blocks span exactly top - 1 down to the column's bottom (the stair-adjusted columns, as ground builds them)
    tops = [col[:] for col in grid.top]
    for (i, k), t in under.items():
        tops[i][k] = t
    bottom = {(i, k): b for i, k, t, b, kd in HF.columns(dataclasses.replace(grid, top=tops))}
    bad = []
    nsides = 0
    for o in ground:
        nm = o.name.split("_")[-1]
        if not nm.startswith("Side"):
            continue
        nsides += 1
        top = bpy.data.objects.get(o.name[:-len(nm)] + "Top" + nm[4:])
        sz, t = o["rs_size"][2], o.matrix_world.translation
        s_top, s_bot = t.z + sz / 2, t.z - sz / 2
        t_bottom = top.matrix_world.translation.z - 0.5 if top else None
        # a merged rect's cells share one bottom: read it at the rect's north-west cell
        x0, z0 = t.x - o["rs_size"][0] / 2 + 0.01, t.y - o["rs_size"][1] / 2 + 0.01
        b = bottom[ST._cell_of(grid, x0, z0)]
        if top is None or abs(s_top - t_bottom) > 1e-4 or abs(s_bot - b) > 1e-4:
            bad.append((o.name, round(s_top, 3), t_bottom, round(s_bot, 3), b))
    INFO["sides"] = nsides
    check("every Side block spans top - 1 down to its column's bottom", nsides > 0 and not bad, bad[:5])

    # routes: the climb (10 -> 4 over 8 studs of box edge) is steeper than 4 over 8, so it gets stairs
    routes = groups.get("Routes", [])
    stairs = [o for o in routes if "Step" in o.name.split("_")[-1]]
    kerbs = [o for o in routes if "Kerb" in o.name.split("_")[-1]]
    INFO["stairs"], INFO["kerbs"] = len(stairs), len(kerbs)
    check("the climb gets stairs", len(stairs) > 0)
    # the stair rise: whole-stud tops, 1 stud per riser, the bottom step 1 above the ground it leaves and the top step
    # flush with the plateau slab it reaches
    runs = ST.stair_runs(layout)
    tops_built = sorted(round(o.matrix_world.translation.z + o["rs_size"][2] / 2, 4) for o in stairs)
    plan = sorted(float(t) for r in runs for _, _, t in r["steps"])
    INFO["stair_tops"] = tops_built
    check("stair tops are whole studs, as planned", tops_built == plan and all(t == int(t) for t in tops_built),
          (tops_built, plan))
    rise_ok = True
    for r in runs:
        ts = [t for _, _, t in r["steps"]]
        (ax, az), (ux, uz) = r["a"], r["u"]
        g0 = ST.ground_y(grid, ax + ux * (r["s0"] - 1), az + uz * (r["s0"] - 1))  # just before the run
        g1 = ST.ground_y(grid, ax + ux * (r["s1"] + 1), az + uz * (r["s1"] + 1))  # just after it
        lo, hi = min(g0, g1), max(g0, g1)
        rise_ok &= all(abs(b - a) == 1 for a, b in zip(ts, ts[1:])) and min(ts) == lo + 1 and max(ts) == hi
        INFO.setdefault("stair_ends", []).append({"route": r["route"], "ground": [g0, g1], "tops": [ts[0], ts[-1]]})
    check("each riser is 1 stud; the steps meet the slabs at both ends", runs and rise_ok, INFO.get("stair_ends"))
    check("steps stand on the run's base", all(abs(o.matrix_world.translation.z - o["rs_size"][2] / 2
                                                   - runs[0]["base"]) < 1e-4 for o in stairs), runs[0]["base"])
    # Task 9 re-review: no Top slab stands above the tread over ANY point of a stair run's footprint (cell corners and
    # edges included: sampling only cell interiors left 1-stud slivers at the corners)
    slabs = []
    for o in ground:
        if o.name.split("_")[-1].startswith("Top"):
            t, sz = o.matrix_world.translation, o["rs_size"]
            slabs.append((t.x - sz[0] / 2, t.x + sz[0] / 2, t.y - sz[1] / 2, t.y + sz[1] / 2, t.z + sz[2] / 2))
    above, npts = [], 0
    for r in runs:
        (ax, az), (ux, uz) = r["a"], r["u"]
        hw, step = r["width"] / 2, 0.25
        ns, nd = int(math.ceil((r["s1"] - r["s0"]) / step)), int(math.ceil(2 * hw / step))
        for a in range(ns + 1):
            sv = min(r["s1"], r["s0"] + a * step)
            tread = min(t for sa, sb, t in r["steps"] if sa - 1e-9 <= sv <= sb + 1e-9)
            for b in range(nd + 1):
                dv = min(hw, -hw + b * step)
                x, z = ax + ux * sv - uz * dv, az + uz * sv + ux * dv
                npts += 1
                for x0, x1, z0, z1, top in slabs:
                    if x0 - 1e-6 <= x <= x1 + 1e-6 and z0 - 1e-6 <= z <= z1 + 1e-6 and top > tread + 1e-6:
                        above.append((round(x, 2), round(z, 2), top, tread))
    INFO["stair_sliver_points"] = npts
    check("no ground slab stands above the tread anywhere over a stair run", npts > 0 and not above,
          (len(above), above[:6]))
    check("the public main road gets kerbs", len(kerbs) > 0)

    # markers
    marks = [o for o in s.objects if o.get("rs_tags")]
    counts = {t: sum(1 for o in marks if t in tags_of(o)) for t in ("RenseiPost", "RenseiClue", "RenseiArea")}
    INFO["tag_counts"] = counts
    check("2 RenseiPost", counts["RenseiPost"] == 2, counts)
    check("1 RenseiClue", counts["RenseiClue"] == 1, counts)
    check("1 RenseiArea", counts["RenseiArea"] == 1, counts)
    check("markers are invisible", all(o.get("rs_invisible") for o in marks))
    post = next(o for o in marks if "RenseiPost" in tags_of(o) and json.loads(o["rs_attr"])["PostId"] == "test_work")
    check("Post Attr travels as JSON", json.loads(post["rs_attr"]) == {"PostId": "test_work", "Kind": "Work"},
          post.get("rs_attr"))
    check("Post At (10, 0, 20) is a 2x2x2 part on the ground",
          list(post["rs_size"]) == [2.0, 2.0, 2.0] and abs(post.matrix_world.translation.x - 10) < 1e-4
          and abs(post.matrix_world.translation.y - 20) < 1e-4
          and abs(post.matrix_world.translation.z - 5) < 1e-4,  # the plane is at Y 4: centre 4 + 1
          (tuple(post.matrix_world.translation), list(post["rs_size"])))
    # Yaw 90 (Roblox, about +Y) is a Blender rotation of -90 degrees about z
    yaw = post.matrix_world.to_euler().z
    check("Post Yaw 90 is applied", abs(math.degrees(yaw) + 90) < 1e-3, math.degrees(yaw))
    area = next(o for o in marks if "RenseiArea" in tags_of(o))
    check("Area box size 256 x 90 x 256", [round(v, 3) for v in area["rs_size"]] == [256.0, 256.0, 90.0],
          list(area["rs_size"]))

    check("within budget (over is false)", out["over"] is False, out)
    check("budget is the layout's 12000", out["budget"] == 12000, out["budget"])

    # water.json: from the cells still water, merged
    wpath = os.path.join(REPO, "Art", "Regions", "Testbed", "water.json")
    w = json.load(open(wpath, encoding="utf-8")) if os.path.exists(wpath) else None
    INFO["water"] = w
    check("water.json has the one lake box", w is not None and len(w["Boxes"]) == 1
          and w["Boxes"][0]["Rect"] == [60, 40, 100, 80] and w["Boxes"][0]["Top"] == 3
          and w["Boxes"][0]["Bed"] == -6, w)

    # materials.json
    mpath = os.path.join(REPO, "Art", "Regions", "Testbed", "materials.json")
    mt = json.load(open(mpath, encoding="utf-8")) if os.path.exists(mpath) else {}
    check("materials.json maps RG_Testbed_cinder to Ground 4a4642",
          mt.get("RG_Testbed_cinder") == {"Material": "Ground", "Color": "4a4642", "Transparency": 0},
          mt.get("RG_Testbed_cinder"))
    check("glass_warm is Glass at 0.3", mt.get("RG_Testbed_glass_warm", {}).get("Transparency") == 0.3,
          mt.get("RG_Testbed_glass_warm"))
    used = {o.get("rs_mat") for v in groups.values() for o in v}
    check("every part's material is in materials.json", used <= set(mt), sorted(used - set(mt)))
    # a texture-pack Palette entry adds PackImage and StudsPerTile (the first catalog item that has an image)
    pack = json.load(open(os.path.join(REPO, "Art", "Regions", "texture_pack.json"), encoding="utf-8"))
    item = next(p for p in pack if p.get("I") and p.get("U"))
    lay = {"Region": "PackCheck", "Palette": {"wall": {"Key": "brick", "Pack": item["N"]}, "ground_top": "cinder"}}
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "materials.json")
        materials.write_table(lay, p)
        t = json.load(open(p, encoding="utf-8"))
    e = t.get("RG_PackCheck_wall", {})
    check("a Pack palette entry gets PackImage and StudsPerTile",
          e.get("PackImage") == "rbxassetid://" + item["I"] and e.get("StudsPerTile") == item["U"]
          and e.get("Material") == "Brick" and e.get("Color") == "7a3e2e", e)
    check("a plain palette entry has no PackImage", "PackImage" not in t.get("RG_PackCheck_cinder", {}), t)

    # export.py: origin is a parameter; marker rows carry field 16 = the tags
    sys.modules.pop("lindenmoor.export", None)
    X = importlib.import_module("lindenmoor.export")
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "layout.json")
        ex = X.export(s.name, p, origin=(0, 0, 0))
        data = json.load(open(p, encoding="utf-8"))
    INFO["export"] = {k: ex[k] for k in ("prefabs", "parts", "lights")}
    check("export writes the origin given", data["origin"] == [0, 0, 0], data["origin"])
    rows = [r for pf in data["prefabs"] if pf["g"] == "Markers" for r in pf["p"]]
    check("4 marker rows exported", len(rows) == 4, len(rows))
    check("marker rows have 16 fields, field 14 = 1, field 16 = the tag",
          rows and all(len(r) == 16 and r[13] == 1 and r[15] in ("RenseiPost", "RenseiClue", "RenseiArea")
                       for r in rows), [r[13:] for r in rows])
    check("marker rows' field 15 is the Attr JSON", all(json.loads(r[14]) for r in rows), [r[14] for r in rows])
    plain = [r for pf in data["prefabs"] if pf["g"] == "Ground" for r in pf["p"]]
    check("ground rows stay 13 fields", plain and all(len(r) == 13 for r in plain))
    check("export parts = run parts", ex["parts"] == out["parts"], (ex["parts"], out["parts"]))

    # ramps: the Testbed climb is all stairs, so build the ground once more with a gentler plateau edge (Edge 24:
    # 6 studs over 24, under the stairs' 4 over 8) and check the ramps; then revert, so the saved file stays as built
    import copy
    gentle = copy.deepcopy(layout)
    gentle["Heights"][1]["Edge"] = 24
    gg = HF.sample(gentle, cell=build.CELL)
    ST.ground(gentle, gg)
    bpy.context.view_layer.update()
    rp = [o for o in s.objects if o.type == "MESH" and o.name.split("_")[-1].startswith("Ramp")]
    INFO["gentle_ramps"] = len(rp)
    check("a gentle climb gets ramps and no stairs", len(rp) > 0 and not ST.stair_runs(gentle),
          (len(rp), len(ST.stair_runs(gentle))))
    check("ramps are 1.2 thick, tilted",
          rp and all(abs(o["rs_size"][2] - 1.2) < 1e-6 and abs(o.matrix_world.to_euler().x)
                     + abs(o.matrix_world.to_euler().y) > 1e-3 for o in rp))
    # a ramp's top face passes through its cell's corner heights (ground.lua): check the centre height
    worst = 0.0
    for o in rp:
        t = o.matrix_world.translation
        i, k = ST._cell_of(gg, t.x, t.y)
        mid = sum(HF.corners(gg, gentle, i, k)) / 4
        top_c = t + o.matrix_world.to_3x3() @ Vector((0, 0, 0.6))
        worst = max(worst, abs(top_c.z - mid))
    check("ramp tops pass through the corner heights' mean", rp and worst < 1e-3, worst)
    bpy.ops.wm.revert_mainfile()
    check("the saved Testbed file is back as built", not bpy.data.is_dirty and len(build.parts_of(bpy.context.scene))
          == out["parts"], len(build.parts_of(bpy.context.scene)))


def _seg_dist(px, pz, a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    L2 = dx * dx + dz * dz
    t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((px - a[0]) * dx + (pz - a[1]) * dz) / L2))
    return math.hypot(px - (a[0] + t * dx), pz - (a[1] + t * dz))


def _route_dist(r, x, z):
    return min(_seg_dist(x, z, a, b) for a, b in zip(r["Line"], r["Line"][1:]))


def _inside(poly, x, z):
    c = False
    for (x0, z0), (x1, z1) in zip(poly, poly[1:] + poly[:1]):
        if (z0 > z) != (z1 > z) and x < x0 + (z - z0) * (x1 - x0) / (z1 - z0):
            c = not c
    return c


def _part_samples(o, step=0.5):
    """(x, z) region points over a part's footprint: a grid over its local x / y extents at its bottom and top faces."""
    from mathutils import Vector
    sx, sy, sz = o["rs_size"]
    nx, ny = max(1, int(math.ceil(sx / step))), max(1, int(math.ceil(sy / step)))
    M = o.matrix_world
    out = []
    for i in range(nx + 1):
        for j in range(ny + 1):
            for h in (-sz / 2, sz / 2):
                p = M @ Vector((-sx / 2 + sx * i / nx, -sy / 2 + sy * j / ny, h))
                out.append((p.x, p.y))
    return out


def _foot(root):
    """A prefab root's footprint (rs_foot, local [x0, y0, x1, y1]) as 4 region (x, z) corners."""
    from mathutils import Vector
    x0, y0, x1, y1 = root["rs_foot"]
    M = root.matrix_world
    return [tuple((M @ Vector((x, y, 0)))[:2]) for x, y in ((x0, y0), (x1, y0), (x1, y1), (x0, y1))]


def _foot_points(root, step=1.0, inset=0.01):
    from mathutils import Vector
    x0, y0, x1, y1 = root["rs_foot"]
    x0, y0, x1, y1 = x0 + inset, y0 + inset, x1 - inset, y1 - inset
    nx, ny = max(1, int(math.ceil((x1 - x0) / step))), max(1, int(math.ceil((y1 - y0) / step)))
    M = root.matrix_world
    return [tuple((M @ Vector((x0 + (x1 - x0) * i / nx, y0 + (y1 - y0) * j / ny, 0)))[:2])
            for i in range(nx + 1) for j in range(ny + 1)]


def _rect_point_dist(corners, x, z):
    """Distance from (x, z) to a convex quad (0 inside)."""
    if _inside([list(c) for c in corners], x, z):
        return 0.0
    return min(_seg_dist(x, z, a, b) for a, b in zip(corners, corners[1:] + corners[:1]))


def kit_main():
    """Task 10: the full Testbed build (every stage): buildings, landmarks, cover, edges, lamps, traversal tags."""
    import bpy
    from mathutils import Vector
    from region_builder import build, schema, heightfield as HF, stages as ST
    from region_builder import kits

    layout = schema.load(os.path.join(REPO, "Art", "Regions", "Testbed", "layout.json"))
    grid = HF.sample(layout, cell=build.CELL)
    out = build.run("Testbed", "all")
    s = bpy.context.scene
    bpy.context.view_layer.update()
    INFO["full"] = {k: out[k] for k in ("objects", "parts", "budget", "over", "stages")}
    INFO["renders"] = out["renders"]

    groups = {}
    for o in s.objects:
        if o.type == "MESH" and o.get("rs_kind") and o.parent and o.parent.get("rs_prefab"):
            groups.setdefault(o.parent.users_collection[0].name.split(".")[0], []).append(o)
    INFO["full_parts_by_group"] = {g: len(v) for g, v in groups.items()}
    check("full build: parts within the 12000 budget", out["over"] is False and out["parts"] <= 12000, out["parts"])
    check("full build: the renders were written", len(out["renders"]) >= 3
          and all(os.path.exists(p) for p in out["renders"]), out["renders"])

    def roots_in(g):
        return [o for o in s.objects if o.get("rs_prefab") and not o.parent and o.users_collection
                and o.users_collection[0].name.split(".")[0] == g]

    # ---- buildings
    bld = roots_in("Buildings")
    row = next(d for d in layout["Districts"] if d["Id"] == "row")
    in_row = [r for r in bld if _inside(row["Poly"], r.location.x, r.location.y)]
    INFO["buildings"] = {r.name: len(r.children) for r in bld}
    check("the row district holds 3 or more buildings", len(in_row) >= 3, len(in_row))
    check("every row building is a railtown.house", all(r.get("rs_style") == "railtown.house" for r in in_row),
          [r.get("rs_style") for r in in_row])
    big = {r.name: len([c for c in r.children if c.type == "MESH"]) for r in bld}
    check("every building is under 150 parts (PROPOSAL)", big and max(big.values()) < 150, big)
    corr = [r for r in layout["Routes"]]
    bad = []
    for r in bld:
        for o in r.children:
            if o.type != "MESH" or not o.get("rs_kind"):
                continue
            for x, z in _part_samples(o):
                for rt in corr:
                    d = _route_dist(rt, x, z)
                    if d < rt["Width"] / 2 + 2 - 1e-3:
                        bad.append((o.name, rt["Id"], round(x, 1), round(z, 1), round(d, 2)))
                        break
                if len(bad) > 8:
                    break
    check("no building part within 2 studs of a route's corridor", bld and not bad, bad[:8])
    # markers: point markers (2x2x2 parts) keep 2 studs clear of every building footprint
    pts = [m for m in layout["Markers"] if "At" in m]
    bad = [(r.name, m["Tag"]) for r in bld for m in pts
           if _rect_point_dist(_foot(r), m["At"][0], m["At"][2]) < 1 + 2 - 1e-6]
    check("no building within 2 studs of a marker", not bad, bad)
    # each building sits on the ground: floor at or above the highest ground under it, plinth down to the lowest
    bad = []
    for g in ("Buildings", "Landmarks", "Cover"):
        for r in roots_in(g):
            if "rs_foot" not in r:
                bad.append((r.name, "no rs_foot"))
                continue
            gys = [ST.ground_y(grid, x, z) for x, z in _foot_points(r)]
            low = min((o.matrix_world @ Vector(c)).z for o in r.children if o.type == "MESH" and o.get("rs_kind")
                      for c in o.bound_box)
            if r.location.z < max(gys) - 1e-4 or low > min(gys) + 1e-4:
                bad.append((r.name, round(r.location.z, 2), max(gys), round(low, 2), min(gys)))
    check("buildings, landmarks and cover sit on the ground (floor >= highest ground, base <= lowest)", not bad, bad[:8])
    # buildings face a route: a ray from the front face, straight out, meets a route corridor within FRONT_REACH
    bad = []
    for r in bld:
        x0, y0, x1, y1 = r["rs_body"]
        M = r.matrix_world
        f = M.to_3x3() @ Vector((0, -1, 0))
        p0 = M @ Vector(((x0 + x1) / 2, y0, 0))
        hit = False
        for k in range(int(ST.FRONT_REACH * 2) + 1):
            x, z = p0.x + f.x * k * 0.5, p0.y + f.y * k * 0.5
            if any(_route_dist(rt, x, z) <= rt["Width"] / 2 for rt in corr if rt["Kind"] in ("public", "quiet", "road")):
                hit = True
                break
        if not hit:
            bad.append(r.name)
    check("every building's front looks onto a route", bld and not bad, bad)
    # alleys: along a frontage, neighbours share a party wall or stand 4+ studs apart; no more than 3 in a row
    lines = {}
    for r in bld:
        lines.setdefault(r["rs_frontage"], []).append(r)  # "<district>:<edge>": the buildings along one frontage
    gaps, run_bad, alley = [], [], 0
    for key, rs in lines.items():
        a = rs[0].rotation_euler.z
        ax = (math.cos(a), math.sin(a))  # local +x in the world
        rs.sort(key=lambda r: r.location.x * ax[0] + r.location.y * ax[1])
        run = 1
        for p, q in zip(rs, rs[1:]):
            pe = p.location.x * ax[0] + p.location.y * ax[1] + p["rs_body"][2]
            qs = q.location.x * ax[0] + q.location.y * ax[1] + q["rs_body"][0]
            gap = qs - pe
            if abs(gap) <= 0.01:
                run += 1
            elif gap >= 4 - 1e-6:
                alley += 1
                run = 1
            else:
                gaps.append((p.name, q.name, round(gap, 2)))
            if run > 3:
                run_bad.append(q.name)
    INFO["alleys"] = alley
    check("neighbours share a wall or leave a 4+ stud alley", not gaps, gaps)
    check("no more than 3 buildings without an alley", not run_bad, run_bad)
    check("the row leaves at least one alley", alley >= 1, alley)

    # ---- landmarks
    lms = roots_in("Landmarks")
    court = [r for r in lms if r.get("rs_id") == "court"]
    check("the practice court exists", len(court) == 1 and court[0].get("rs_prefab") == "PracticeCourt"
          and court[0].get("rs_style") == "railtown.practice_court", [(r.name, r.get("rs_prefab")) for r in lms])
    if court:
        c = court[0]
        xs = [p[0] for o in c.children if o.type == "MESH" for p in _part_samples(o, 2.0)]
        span = max(xs) - min(xs) if xs else 0
        INFO["court_span"] = round(span, 2)
        check("the court is about 40 studs across", 34 <= span <= 46, span)
        check("the court has benches", any("Bench" in o.name for o in c.children), [o.name for o in c.children][:10])
        bad = [rt["Id"] for o in c.children if o.type == "MESH" for x, z in _part_samples(o, 1.0) for rt in corr
               if _route_dist(rt, x, z) < rt["Width"] / 2]
        check("the court stays off the routes", not bad, bad[:5])

    # ---- traversal: ledges
    ledges = [o for o in s.objects if o.type == "MESH" and "RenseiLedge" in tags_of(o)]
    INFO["ledges"] = len(ledges)
    check("at least one object carries the RenseiLedge tag", len(ledges) >= 1, len(ledges))
    dg = bpy.context.evaluated_depsgraph_get()
    bad = []
    for o in ledges:
        e = o.matrix_world.to_euler()
        sz = list(o["rs_size"])
        M3 = o.matrix_world.to_3x3()
        wall = M3 @ Vector((0, -1, 0))  # Roblox LookVector (front face) = Blender local -y
        top = o.matrix_world.translation + Vector((0, 0, sz[2] / 2))
        origin = top + wall * (sz[1] / 2 + 0.05) + Vector((0, 0, 1.0))
        hit, _, _, _, obj, _ = s.ray_cast(dg, origin - wall * 0.1, wall, distance=1.0)
        if abs(e.x) > 1e-4 or abs(e.y) > 1e-4 or abs(sz[1] - 1.4) > 1e-6 or abs(sz[2] - 1.0) > 1e-6 or not hit \
                or (obj and "RenseiLedge" in tags_of(obj)):
            bad.append((o.name, round(e.x, 3), round(e.y, 3), sz, hit, obj.name if obj else None))
    check("ledges are level 1 x 1.4 strips whose front face meets a wall", ledges and not bad, bad[:5])

    # ---- lamps
    glows = [o for o in s.objects if o.type == "MESH" and o.get("rs_attr") and json.loads(o["rs_attr"]).get("NightOnly")]
    named = [o for o in s.objects if o.get("rs_prefab") == "LampPost"]
    INFO["lamps"] = {"posts": len(named), "glows": len(glows)}
    check("there are street lamps", len(named) >= 2, INFO["lamps"])
    lights = [o for o in s.objects if o.type == "LIGHT" and o.get("rs_light")]
    bad = []
    for g in glows:
        sibs = [l for l in lights if l.parent == g.parent and (l.matrix_world.translation
                                                               - g.matrix_world.translation).length < 3]
        if not sibs or g.get("rs_kind") != "Block" or bpy.data.materials[g["rs_mat"]].get("rs_roblox") != "Neon":
            bad.append(g.name)
    check("every lamp's glow carries NightOnly, is Neon and has a light beside it", glows and not bad, bad)
    check("every LampPost has a NightOnly glow",
          all(any(c in glows for c in r.children) for r in named), [r.name for r in named])

    # ---- cover
    cov = [r for r in roots_in("Cover") if r.get("rs_prefab") == "Cover"]
    alley = next(r for r in layout["Routes"] if r["Id"] == "alley")
    near = [r for r in cov if _route_dist(alley, r.location.x, r.location.y) < alley["Width"] / 2 + 10]
    INFO["cover"] = {"clusters": len(cov), "by_alley": len(near)}
    check("cover clusters line the quiet alley (1 per 20 studs: 2 for 40)", len(near) >= 2, INFO["cover"])
    bad = []
    for r in roots_in("Cover"):
        for o in r.children:
            if o.type == "MESH" and o.get("rs_kind"):
                for x, z in _part_samples(o, 0.5):
                    hit = [rt["Id"] for rt in corr if _route_dist(rt, x, z) < rt["Width"] / 2 + 0.5 - 1e-6]
                    if hit:
                        bad.append((o.name, hit[0]))
                        break
    check("cover and lamps stay off the route corridors", not bad, bad[:6])
    bad = [(c.name, b.name) for c in roots_in("Cover") for b in bld + lms
           if any(_rect_point_dist(_foot(b), x, z) == 0 for x, z in _foot_points(c, 1.0))]
    check("cover and lamps keep out of buildings and landmarks", not bad, bad[:6])

    # ---- edges
    gaps_ = [m for m in layout["Markers"] if m["Tag"] == "EdgeGap"]
    check("the Testbed has 2 EdgeGap markers", len(gaps_) == 2, len(gaps_))
    eparts = groups.get("Edges", [])
    boxes = []
    for o in eparts:
        t, sz = o.matrix_world.translation, o["rs_size"]
        boxes.append((t.x - sz[0] / 2, t.x + sz[0] / 2, t.y - sz[1] / 2, t.y + sz[1] / 2, t.z + sz[2] / 2,
                      t.z - sz[2] / 2))
    check("edge parts are unrotated blocks", eparts and all(
        o["rs_kind"] == "Block" and all(abs(a) < 1e-6 for a in o.matrix_world.to_euler()) for o in eparts))

    def in_gap(x, z):
        return any(g["Box"][0][0] <= x <= g["Box"][1][0] and g["Box"][0][2] <= z <= g["Box"][1][2] for g in gaps_)
    hw, hd = layout["Footprint"][0] / 2, layout["Footprint"][1] / 2
    perim = []
    for k in range(int(2 * hw / 2) + 1):
        x = -hw + 3 + (2 * hw - 6) * k / int(2 * hw / 2)
        perim += [(x, -hd + 3), (x, hd - 3)]
    for k in range(int(2 * hd / 2) + 1):
        z = -hd + 3 + (2 * hd - 6) * k / int(2 * hd / 2)
        perim += [(-hw + 3, z), (hw - 3, z)]
    open_, short, blocked = [], [], []
    for x, z in perim:
        cov_ = [b for b in boxes if b[0] - 1e-6 <= x <= b[1] + 1e-6 and b[2] - 1e-6 <= z <= b[3] + 1e-6]
        if in_gap(x, z):
            if cov_:
                blocked.append((round(x, 1), round(z, 1)))
        elif not cov_:
            open_.append((round(x, 1), round(z, 1)))
        elif max(b[4] for b in cov_) < ST.ground_y(grid, x, z) + 24 - 1e-6:
            short.append((round(x, 1), round(z, 1), max(b[4] for b in cov_), ST.ground_y(grid, x, z)))
    INFO["edge_samples"] = len(perim)
    check("the edge ridges close the footprint's edge except at EdgeGaps", eparts and not open_, open_[:8])
    check("the edge ridges stand 24+ studs over the ground (PROPOSAL)", not short, short[:6])
    check("nothing of the edges stands in an EdgeGap", not blocked, blocked[:6])
    bad = []
    for o, b in zip(eparts, boxes):  # each ridge's bottom tier reaches the lowest ground under it (nothing floats)
        if "Base" not in o.name.split("_")[-1]:
            continue
        n = 8
        lo = min(ST.ground_y(grid, b[0] + 0.01 + (b[1] - b[0] - 0.02) * i / n, b[2] + 0.01 + (b[3] - b[2] - 0.02) * j / n)
                 for i in range(n + 1) for j in range(n + 1))
        if b[5] > lo + 1e-6:
            bad.append((o.name, round(b[5], 2), lo))
    check("each edge ridge's base reaches the lowest ground under it", eparts and not bad, bad[:4])

    # ---- EdgeGap is consumed: no part, no export row
    check("no part carries an EdgeGap tag", not any("EdgeGap" in tags_of(o) for o in s.objects))
    sys.modules.pop("lindenmoor.export", None)
    X = importlib.import_module("lindenmoor.export")
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "layout.json")
        ex = X.export(s.name, p, origin=(0, 0, 0))
        data = json.load(open(p, encoding="utf-8"))
    rows = [r for pf in data["prefabs"] for r in pf["p"]]
    check("full export: 4 marker rows (EdgeGaps are not exported)",
          len([r for pf in data["prefabs"] if pf["g"] == "Markers" for r in pf["p"]]) == 4)
    check("full export: ledge rows carry field 16 = RenseiLedge",
          any(len(r) == 16 and "RenseiLedge" in r[15].split(",") for r in rows))
    check("full export: lamp glow rows carry NightOnly",
          any(len(r) == 16 and r[14] and json.loads(r[14]).get("NightOnly") is True for r in rows))
    check("full export: lamp lights are exported", sum(len(pf["l"]) for pf in data["prefabs"]) >= len(glows),
          (sum(len(pf["l"]) for pf in data["prefabs"]), len(glows)))
    check("full export parts = run parts", ex["parts"] == out["parts"], (ex["parts"], out["parts"]))
    mt = json.load(open(os.path.join(REPO, "Art", "Regions", "Testbed", "materials.json"), encoding="utf-8"))
    used = {o.get("rs_mat") for v in groups.values() for o in v}
    check("full build: every part's material is in materials.json", used <= set(mt), sorted(used - set(mt)))

    # ---- the whole kit: every style and landmark builds, each style under 150 parts (gallery, then revert)
    gal = ST.kit_gallery(layout)
    INFO["kit_parts"] = gal
    styles = [k for k in gal if k.split(".")[1] in kits.railtown.STYLES]
    check("the kit has the 5 styles and 7 landmarks",
          sorted(kits.railtown.STYLES) == ["boarding", "house", "shed", "stack", "warehouse"]
          and sorted(kits.railtown.LANDMARKS) == ["canteen", "crane_bay", "foundry_hall", "market_stall",
                                                  "practice_court", "rail_walk", "underworks"],
          (sorted(kits.railtown.STYLES), sorted(kits.railtown.LANDMARKS)))
    check("every kit piece builds parts", gal and all(n > 0 for n in gal.values()), gal)
    check("every style is under 150 parts at its largest (PROPOSAL)", styles and all(gal[k] < 150 for k in styles),
          {k: gal[k] for k in styles})
    gs = [o for o in s.objects if o.type == "MESH" and o.get("rs_gallery")]
    kinds = {o.get("rs_kind") for o in gs}
    check("kit parts are Blocks, Cylinders and Wedges", kinds <= {"Block", "Cylinder", "Wedge"}, kinds)
    check("every kit material is in materials.json", {o.get("rs_mat") for o in gs} <= set(mt),
          sorted({o.get("rs_mat") for o in gs} - set(mt)))
    rw = [o for o in gs if o.get("rs_gallery") == "railtown.rail_walk" and "RenseiLedge" in tags_of(o)]
    check("the rail walk has ledge strips along both sides", len(rw) >= 2, len(rw))
    legs = [o for o in gs if o.get("rs_gallery") == "railtown.crane_bay" and "Leg" in o.name.split("_")[-1]]
    check("the crane bay has 4 climbable legs (a Note says so; climbing needs no tag)",
          len(legs) == 4 and all("climb" in json.loads(o.get("rs_attr", "{}")).get("Note", "").lower() for o in legs),
          [(o.name, o.get("rs_attr")) for o in legs])
    gird = [o for o in gs if o.get("rs_gallery") == "railtown.crane_bay" and "Girder" in o.name]
    check("the crane bay's girder is walkable (4+ studs wide, level)",
          gird and any(o["rs_size"][1] >= 4 and abs(o.matrix_world.to_euler().x) < 1e-6 for o in gird))
    bpy.ops.wm.revert_mainfile()
    check("the saved Testbed file is the full build", not bpy.data.is_dirty
          and len(build.parts_of(bpy.context.scene)) == out["parts"], len(build.parts_of(bpy.context.scene)))


try:
    main()
except Exception:
    FAILS.append("error: " + traceback.format_exc()[-2500:])
try:
    kit_main()
except Exception:
    FAILS.append("kit error: " + traceback.format_exc()[-2500:])
result = {"pass": not FAILS, "passed": len(PASSES), "failed": len(FAILS), "fails": FAILS, "info": INFO}

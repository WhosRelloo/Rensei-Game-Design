"""Blender-side checks on the region builder's Blender stages (Task 9). Run through the Blender bridge:
    python -I Art/Tools/blender_mcpc.py code @Art/Blender/region_builder/tests/blender_check.py

It builds Testbed with build.run("Testbed", "ground,routes,markers") (which refuses a file with unsaved changes, opens
an empty file and saves only Art/Blender/Regions/Testbed.blend), then checks the scene, water.json, the material table
and export.py's row field 16 (exported to a temp folder). Sets `result` to a dict: {"pass": bool, "fails": [...], ...}."""
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
    from region_builder import build, materials

    out = build.run("Testbed", "ground,routes,markers")
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
    ramps = [o for o in ground if o.name.split("_")[-1].startswith("Ramp")]
    INFO["ramps"] = len(ramps)
    check("the climb gets ramps", len(ramps) > 0)
    check("ramps are 1.2 thick", all(abs(o["rs_size"][2] - 1.2) < 1e-6 for o in ramps))

    # routes: the climb (10 -> 4 over 8 studs of box edge) is steeper than 4 over 8, so it gets stairs
    routes = groups.get("Routes", [])
    stairs = [o for o in routes if "Step" in o.name.split("_")[-1]]
    kerbs = [o for o in routes if "Kerb" in o.name.split("_")[-1]]
    INFO["stairs"], INFO["kerbs"] = len(stairs), len(kerbs)
    check("the climb gets stairs", len(stairs) > 0)
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


try:
    main()
except Exception:
    FAILS.append("error: " + traceback.format_exc()[-2500:])
result = {"pass": not FAILS, "passed": len(PASSES), "failed": len(FAILS), "fails": FAILS, "info": INFO}

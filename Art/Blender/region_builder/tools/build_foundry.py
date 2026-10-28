"""Builds Foundry Yard: build.run("Foundry", stages), then the extras (extras.py: the tunnel portals in the edge gaps,
the north viaduct, the render-only travel preview), the part count again, the renders, and a save of
Art/Blender/Regions/Foundry.blend only. Run through the Blender bridge:
    python -I Art/Tools/blender_mcpc.py code @Art/Blender/region_builder/tools/build_foundry.py

A long build can outlast the bridge's 300 s wait; Blender carries on regardless. Progress and the result are written to
LOG (a JSON file; default <temp>/foundry_build.json), so poll that. Set these globals in a wrapper before exec'ing
this file to change what runs:
    FOUNDRY_STAGES   build.run stages (default: every stage but render), or "none" to render the open, saved
                     Foundry.blend as it is;
    FOUNDRY_RENDER   None (no renders), "all", or a list of shot names (stages.shots: "aerial", "district <Id>",
                     "landmark <Id>"; add "+extras" for every EXTRA_SHOTS view);
    FOUNDRY_LOG      the log path.
Sets `result` to a dict. Every number in VIADUCT is a PROPOSAL (owner-approved layout, 2026-10-24)."""
import json, os, sys, tempfile, time, traceback

BLENDER = r"E:/Rensei/Rensei-Game-Design/Art/Blender"
REPO = os.path.normpath(os.path.join(BLENDER, "..", ".."))
if BLENDER not in sys.path:
    sys.path.insert(0, BLENDER)
for _m in [m for m in list(sys.modules) if m == "region_builder" or m.startswith("region_builder.")]:
    del sys.modules[_m]  # Blender keeps modules between runs: build with the code on disk

STAGES = globals().get("FOUNDRY_STAGES", "ground,routes,buildings,landmarks,cover,edges,markers,lighting")
RENDER = globals().get("FOUNDRY_RENDER", None)
LOG = globals().get("FOUNDRY_LOG", os.path.join(tempfile.gettempdir(), "foundry_build.json"))
# the north viaduct over the slag cut, from the yard road's end to the shut gatehouse (layout: north_gatehouse)
VIADUCT = {"x": 60.0, "z0": -590.0, "z1": -702.0, "width": 16.0}
# Foundry's own street views beside stages.shots (name: (eye (x, y, z), target (x, y, z), lens)), all PROPOSALs
EXTRA_SHOTS = {
    "aerial from the south-east": ((640, 900, 1200), (-40, 0, -60), 28),
    "underworks tunnel": ((-540, 9, 676), (-420, 8, 676), 18),
    "viaduct from the cut": ((150, 6, -650), (60, -2, -650), 22),
    "north gatehouse": ((60, 10, -560), (60, 14, -708), 30),
    "rail portal": ((640, 12, 54), (768, 14, 54), 26),
    "south road bend": ((150, 10, 470), (110, 6, 640), 24),
    "south road portal": ((5, 9, 690), (5, 12, 768), 26),
    "station platform": ((-636, 12, 140), (-650, 9, 400), 22),
    "station concourse": ((-560, 10, 470), (-636, 8, 420), 22),
    "great hall casting floor": ((488, 14, -296), (400, 8, -380), 18),
    "great hall forge rooms": ((373, 7, -300), (373, 4, -372), 22),
    "great hall front": ((320, 12, -256), (470, 14, -300), 20),
    "boarding houses": ((-310, 9, -545), (-40, 10, -560), 26),
    "foundry works lane": ((150, 9, -600), (700, 9, -600), 26),
    "slag tip": ((200, 12, 440), (490, 22, 560), 24),
    "freight sidings": ((240, 10, 124), (700, 8, 124), 24),
    "crane yard pond": ((380, 16, -130), (560, 2, -160), 24),
    "wall run corridor": ((396, 10, -228), (520, 9, -228), 24),
    "rail corridor": ((-420, 26, 54), (120, 10, 54), 24),
    "workers row street": ((-560, 10, -280), (-560, 9, -560), 26),
    "cinder lane": ((-610, 10, 260), (-100, 8, 260), 26),
    "market square": ((-40, 12, -290), (-230, 6, -345), 24),
}
T0 = time.time()


def log(**kv):
    kv["t"] = round(time.time() - T0, 1)
    with open(LOG, "w", encoding="utf-8") as f:
        json.dump(kv, f, indent=1)


try:
    import bpy
    from region_builder import build, extras, heightfield as HF, schema, stages as ST
    layout = schema.load(os.path.join(build.REGIONS, "Foundry", "layout.json"))
    extra = {}
    if STAGES == "none":  # render only: the open, saved Foundry.blend as it is
        if bpy.data.is_dirty or not bpy.data.filepath.replace("\\", "/").lower().endswith("/regions/foundry.blend"):
            raise RuntimeError("render only needs Foundry.blend open and saved")
        out = {"stages": {}}
        grid = HF.sample(layout, cell=build.CELL)
    else:
        log(state="building", stages=STAGES)
        out = build.run("Foundry", STAGES)
        log(state="extras", build=out)
        grid = HF.sample(layout, cell=build.CELL)
        want = [x.strip() for x in STAGES.split(",")]
        if "edges" in want:
            extra["portals"] = extras.portals(layout, grid)
        if "landmarks" in want:
            extra["viaduct"] = extras.viaduct(layout, grid, **VIADUCT)
        extra["preview"] = extras.travel_preview(layout, grid)
    bpy.context.view_layer.update()
    s = bpy.context.scene
    parts = len(build.parts_of(s))
    s["rs_parts"], s["rs_over_budget"] = parts, parts > layout["Budget"]
    groups = {}
    for o in build.parts_of(s):
        g = o.users_collection[0].name.split(".")[0]
        groups[g] = groups.get(g, 0) + 1
    renders = []
    if RENDER is not None:
        log(state="rendering", parts=parts, groups=groups)
        out_dir = os.path.join(build.RENDERS, "Foundry")
        names = None if RENDER == "all" else list(RENDER)
        if names and "+extras" in names:  # every EXTRA_SHOTS view as well
            names = [n for n in names if n != "+extras"] + list(EXTRA_SHOTS)
        std = set(ST.shots(layout, grid))
        if names is None or any(n in std for n in names):
            renders = ST.render(layout, out_dir, grid, names=None if names is None else [n for n in names if n in std])
        for name, (eye, tgt, lens) in EXTRA_SHOTS.items():
            if names is not None and name not in names:
                continue
            ST._camera(layout, name.replace(" ", "_"), eye, tgt, lens)
            path = os.path.join(out_dir, f"Foundry - {name}.png")
            s.render.filepath = path
            bpy.ops.render.render(write_still=True, scene=s.name)
            ST._flip_x(path)
            renders.append(path)
            log(state="rendering", parts=parts, done=len(renders))
    if not bpy.data.filepath.replace("\\", "/").lower().endswith("/art/blender/regions/foundry.blend"):
        raise RuntimeError(f"refusing to save: the open file is {bpy.data.filepath!r}, not Foundry.blend")
    bpy.ops.wm.save_mainfile()
    result = {"parts": parts, "budget": layout["Budget"], "over": parts > layout["Budget"], "groups": groups,
              "extras": extra, "stages": out["stages"], "renders": renders, "blend": bpy.data.filepath,
              "dirty": bpy.data.is_dirty}
    log(state="done", **result)
except Exception:
    result = {"error": traceback.format_exc()[-3000:]}
    try:
        log(state="error", **result)
    except Exception:
        pass

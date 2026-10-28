"""Builds a region in Blender from Art/Regions/<Region>/layout.json (spec 2026-10-23 §3.2).

Run in Blender (Art/Tools/blender_mcpc.py code @file.py):
    import sys; sys.path.insert(0, r"E:/Rensei/Rensei-Game-Design/Art/Blender")
    from region_builder import build
    result = build.run("Testbed")                         # every stage, renders included
    result = build.run("Testbed", "ground,routes,markers")
Stages, in build order: ground, routes, buildings, landmarks, cover (cover clusters and street lamps), edges, markers,
lighting, render. cover plans around the buildings itself, so it may run without them.

run() refuses a Blender file with unsaved changes (it opens an empty file, which would throw them away). It then builds
the scene Region_<Region>, writes Art/Regions/<Region>/materials.json and water.json, and saves only
Art/Blender/Regions/<Region>.blend; never Lindenmoor_Full.blend or Lindenmoor_Expansion.blend, and it never touches
the Lindenmoor scenes (lindenmoor.core.reset_scene is not used). Over budget, it returns over=True and the scene
carries rs_over_budget = True: do not export it."""
import os

import bpy

from . import heightfield as HF, materials, schema, stages as ST

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
REGIONS = os.path.join(REPO, "Art", "Regions")
BLENDS = os.path.join(REPO, "Art", "Blender", "Regions")
RENDERS = os.path.join(REPO, "Documents", "images", "Regions")
PROTECTED = {"lindenmoor_full.blend", "lindenmoor_expansion.blend"}  # other sessions' files: never saved over
STAGES = ("ground", "routes", "buildings", "landmarks", "cover", "edges", "markers", "lighting", "render")
CELL = 4  # studs; the ground's cell (4 near routes and towns, spec §3.2; the Testbed is all town)


def parts_of(scene):
    """The parts export.py would write: meshes with rs_kind under a prefab root."""
    return [o for o in scene.objects
            if o.type == "MESH" and o.get("rs_kind") and o.parent is not None and o.parent.get("rs_prefab")]


def run(region, stages="all", budget=None):
    """Builds the region's stages ("all", or a comma-separated subset of STAGES) and saves the .blend.
    budget overrides the layout's Budget (for checks of the over-budget path).
    Returns {"objects", "parts", "budget", "over", "renders": [paths], "blend", "stages"}."""
    want = list(STAGES) if stages == "all" else [x.strip() for x in stages.split(",") if x.strip()]
    bad = [x for x in want if x not in STAGES]
    if bad:
        raise ValueError(f"unknown stage(s) {', '.join(bad)}; stages are {', '.join(STAGES)} or 'all'")
    blend = os.path.join(BLENDS, f"{region}.blend")
    if os.path.basename(blend).lower() in PROTECTED:
        raise ValueError(f"{blend} belongs to the Lindenmoor builds; a region may not save over it")
    if bpy.data.is_dirty:
        raise RuntimeError(f"Blender has unsaved changes ({bpy.data.filepath or 'an unsaved file'}). build.run opens "
                           "an empty file, which would lose them: save or discard them first.")
    layout = schema.load(os.path.join(REGIONS, region, "layout.json"))
    grid = HF.sample(layout, cell=CELL)

    bpy.ops.wm.read_homefile(use_empty=True)
    s = bpy.context.scene
    s.name = f"Region_{region}"
    s["rs_region"] = region
    materials.write_table(layout, os.path.join(REGIONS, region, "materials.json"))
    ST.write_water(grid, os.path.join(REGIONS, region, "water.json"))

    counts = {}
    if "ground" in want:
        counts["ground"] = ST.ground(layout, grid)
    if "routes" in want:
        counts["routes"] = ST.routes(layout, grid)
    for name in ("buildings", "landmarks", "cover", "edges"):  # the style kits (Task 10)
        if name in want:
            counts[name] = getattr(ST, name)(layout, grid)
    if "markers" in want:
        counts["markers"] = ST.markers(layout, grid)
    if "lighting" in want or "render" in want:
        ST.lighting(layout)
    bpy.context.view_layer.update()

    parts = len(parts_of(s))
    budget = layout["Budget"] if budget is None else budget
    over = parts > budget
    s["rs_parts"], s["rs_budget"], s["rs_over_budget"] = parts, budget, over
    renders = ST.render(layout, os.path.join(RENDERS, region), grid) if "render" in want else []

    os.makedirs(BLENDS, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=blend)
    return {"objects": len(s.objects), "parts": parts, "budget": budget, "over": over, "renders": renders,
            "blend": blend, "stages": counts}

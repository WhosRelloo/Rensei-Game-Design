"""Renders the style-kit sheets (stages.render_gallery) to Documents/images/Regions/Kits/. Run through the Blender bridge:
    python -I Art/Tools/blender_mcpc.py code @Art/Blender/region_builder/tools/render_kit_gallery.py

It uses the open file (normally Art/Blender/Regions/Testbed.blend, as build.run left it), which must have no unsaved
changes: it hides the region, builds every kit piece in a row (stages.kit_gallery), renders the sheets and reverts the
file, so nothing is saved. Set SHOTS to a list of shot names (stages.GALLERY_SHOTS, "underworks end",
"foundry gantries") to render only those. Sets `result` to a dict."""
import os, sys, traceback

BLENDER = r"E:/Rensei/Rensei-Game-Design/Art/Blender"
REPO = os.path.normpath(os.path.join(BLENDER, "..", ".."))
if BLENDER not in sys.path:
    sys.path.insert(0, BLENDER)
for _m in [m for m in list(sys.modules) if m == "region_builder" or m.startswith("region_builder.")]:
    del sys.modules[_m]  # Blender keeps modules between runs: render with the code on disk
SHOTS = None  # e.g. ["buildings", "foundry gantries"]
try:
    import bpy
    from region_builder import schema, stages
    layout = schema.load(os.path.join(REPO, "Art", "Regions", "Testbed", "layout.json"))
    paths = stages.render_gallery(layout, os.path.join(REPO, "Documents", "images", "Regions", "Kits"), names=SHOTS)
    result = {"paths": paths, "dirty_after": bpy.data.is_dirty}
except Exception:
    result = {"error": traceback.format_exc()[-3000:]}

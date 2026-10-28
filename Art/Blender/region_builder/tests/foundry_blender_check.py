"""Blender-side checks on the built Foundry Yard (run after tools/build_foundry.py, with Foundry.blend open and saved).
Run through the Blender bridge:
    python -I Art/Tools/blender_mcpc.py code @Art/Blender/region_builder/tests/foundry_blender_check.py

It checks the scene as built: the part count against the Budget, every edge wall and portal part ungrippable
(RenseiNoGrip), the two tunnel portals closed at the footprint's edge, the viaduct's piers on the ground and its deck
level with the ground at both ends, the forge-room shells, the canopy's posts clear of the gate and the board, one
marker part per exported marker, and every townsfolk post, clue and spawn standing on walkable ground with head room
(rays down and sideways against everything but markers and previews; this can outlast the bridge's 300 s wait, so
the result is also written to <temp>/foundry_check.json). It changes nothing it keeps: collections hidden
for the rays are shown again and the file is reverted when it was clean before. Sets `result` to a dict."""
import json, math, os, sys, traceback

BLENDER = r"E:/Rensei/Rensei-Game-Design/Art/Blender"
if BLENDER not in sys.path:
    sys.path.insert(0, BLENDER)
for _m in [m for m in list(sys.modules) if m == "region_builder" or m.startswith("region_builder.")]:
    del sys.modules[_m]

FAILS, PASSES, INFO = [], [], {}


def check(name, ok, detail=""):
    (PASSES if ok else FAILS).append(name if ok else f"{name}: {detail}")


def tags_of(o):
    return [t for t in str(o.get("rs_tags", "")).split(",") if t]


def main():
    import bpy
    from mathutils import Vector
    from region_builder import build, placement as PL, schema
    s = bpy.context.scene
    check("the open file is Foundry.blend, saved", bpy.data.filepath.replace("\\", "/").lower().endswith(
        "/art/blender/regions/foundry.blend") and not bpy.data.is_dirty, (bpy.data.filepath, bpy.data.is_dirty))
    L = schema.load(os.path.join(build.REGIONS, "Foundry", "layout.json"))
    parts = build.parts_of(s)
    INFO["parts"] = len(parts)
    check("the part count is within the Budget", len(parts) <= L["Budget"], (len(parts), L["Budget"]))

    def group_of(o):
        return o.users_collection[0].name.split(".")[0]

    edges = [o for o in parts if group_of(o) == "Edges"]
    check("every edge wall and portal part is ungrippable (RenseiNoGrip)",
          edges and all(PL.EDGE_TAG in tags_of(o) for o in edges),
          [o.name for o in edges if PL.EDGE_TAG not in tags_of(o)][:5])
    portals = [o for o in s.objects if o.get("rs_prefab") == "Portal"]
    check("two tunnel portals (rail, road)", sorted(o.get("rs_portal") for o in portals) == ["rail", "road"],
          [o.get("rs_portal") for o in portals])
    fw, fd = L["Footprint"]
    for p in portals:
        back = [o for o in p.children if o.name.endswith("_Back")]
        ok = False
        if back:
            pts = [back[0].matrix_world @ Vector(c) for c in back[0].bound_box]
            if p.get("rs_portal") == "rail":
                ok = abs(max(q.x for q in pts) - fw / 2) < 0.6
            else:
                ok = abs(max(q.y for q in pts) - fd / 2) < 0.6
        check(f"the {p.get('rs_portal')} portal is closed at the footprint's edge", ok)
    # the viaduct
    via = next((o for o in s.objects if o.get("rs_prefab") == "Viaduct"), None)
    check("the viaduct is built", via is not None)
    if via:
        vp = [o for o in via.children if o.type == "MESH"]
        deck = next(o for o in vp if o.name.endswith("_Deck"))
        dpts = [deck.matrix_world @ Vector(c) for c in deck.bound_box]
        top = max(q.z for q in dpts)
        ends = (min(q.y for q in dpts), max(q.y for q in dpts))
        g = PL.ground_y(_grid(L), 60, ends[1] + 0.5)  # the south end (region +Z: Blender +y) meets the yard road
        gh = next((o for o in s.objects if o.get("rs_prefab") == "Gatehouse"), None)
        gf = gh.get("rs_floor") if gh else None  # the north end runs into the gatehouse, settled with a footing
        check("the viaduct's deck is level with the ground at its south end and the gatehouse's floor at its north end",
              abs(top - g) < 0.3 and gf is not None and abs(top - gf) < 0.3, (round(top, 2), g, gf))
        piers = [o for o in vp if "_Pier" in o.name]
        bad = []
        for o in piers:
            pts = [o.matrix_world @ Vector(c) for c in o.bound_box]
            cx, cz = sum(q.x for q in pts) / 8, sum(q.y for q in pts) / 8
            if min(q.z for q in pts) > PL.ground_y(_grid(L), cx, cz) + 0.01:
                bad.append(o.name)
        check("every viaduct pier reaches the ground", piers and not bad, (len(piers), bad[:4]))
    # the forge rooms
    rooms = [o for o in parts if json.loads(o.get("rs_attr", "{}")).get("Room") in ("SilentForge", "ForgeFloor")]
    check("the great hall holds the two forge-room shells (a Room floor each, with a Note)",
          sorted(json.loads(o["rs_attr"])["Room"] for o in rooms) == ["ForgeFloor", "SilentForge"]
          and all("Reserved" in json.loads(o["rs_attr"]).get("Note", "") for o in rooms), [o.name for o in rooms])
    # markers: one part per exported marker
    mk = [o for o in parts if group_of(o) == "Markers"]
    want = [m for m in L["Markers"] if m["Tag"] not in schema.BUILDER_TAGS]
    check("one marker part per exported marker", len(mk) == len(want), (len(mk), len(want)))
    # canopy posts clear of the gate and the board
    can = next(o for o in s.objects if o.get("rs_prefab") == "PlatformCanopy")
    posts = [o.matrix_world.translation for o in can.children if o.type == "MESH" and "_Post" in o.name
             and "Foot" not in o.name]
    gb = [m["At"] for m in L["Markers"] if m["Tag"] == "RenseiMarker" and m["Attr"]["Piece"] in ("Gate", "Board")]
    near = [(round(p.x, 1), round(p.y, 1)) for p in posts for a in gb if abs(p.y - a[2]) < 6]
    check("no canopy post within 6 of the papers gate or the departure board", posts and not near, near)
    # walkable ground and head room at every post, clue and spawn: rays against a small BVH tree of the parts near
    # each one (scene.ray_cast tests all ~46k objects per ray, far too slow here)
    from mathutils.bvhtree import BVHTree
    solid = [o for o in parts if group_of(o) != "Markers"]
    cells = {}
    for o in solid:
        pts = [o.matrix_world @ Vector(c) for c in o.bound_box]
        x0, x1 = min(q.x for q in pts), max(q.x for q in pts)
        y0, y1 = min(q.y for q in pts), max(q.y for q in pts)
        for i in range(int(x0 // 32), int(x1 // 32) + 1):
            for k in range(int(y0 // 32), int(y1 // 32) + 1):
                cells.setdefault((i, k), []).append(o)

    def tree_near(x, z):
        objs = {o.name: o for i in (-1, 0, 1) for k in (-1, 0, 1)
                for o in cells.get((int(x // 32) + i, int(z // 32) + k), [])}
        verts, polys = [], []
        for o in objs.values():
            me = o.data
            mw = o.matrix_world
            n0 = len(verts)
            verts += [mw @ v.co for v in me.vertices]
            polys += [[n0 + i for i in p.vertices] for p in me.polygons]
        return BVHTree.FromPolygons(verts, polys) if polys else None

    bad, skipped = [], []
    for m in L["Markers"]:
        if m["Tag"] not in ("RenseiPost", "RenseiClue", "RenseiEnemySpawn") or "At" not in m:
            continue
        x, y, z = m["At"]
        name = m["Attr"].get("PostId") or m["Attr"].get("ClueId") or f"spawn {x},{z}"
        if y != 0 and abs(y - 6.4) < 0.01:
            skipped.append(name)  # on the platform: setup.lua builds it in Studio
            continue
        base = PL.ground_y(_grid(L), x, z) if y == 0 else y
        T = tree_near(x, z)
        hit = T.ray_cast(Vector((x, z, base + 5.0)), Vector((0, 0, -1)), 7.0) if T else (None,)
        if hit[0] is None or abs(hit[0].z - base) > 0.7:
            bad.append((name, "no floor", round(hit[0].z, 2) if hit[0] is not None else None, base))
            continue
        fz = hit[0].z
        for h in (1.0, 3.0):
            for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if T.ray_cast(Vector((x, z, fz + h)), Vector((d[0], d[1], 0)), 0.9)[0] is not None:
                    bad.append((name, "blocked", h, d))
                    break
        up = T.ray_cast(Vector((x, z, fz + 0.3)), Vector((0, 0, 1)), 5.0)
        if up[0] is not None:
            bad.append((name, "no head room", round(up[0].z - fz, 2)))
    INFO["skipped_posts"] = skipped
    check("every post, clue and spawn stands on walkable ground with room around and above it", not bad, bad[:12])


_G = {}


def _grid(L):
    if "g" not in _G:
        from region_builder import build, heightfield as HF
        _G["g"] = HF.sample(L, cell=build.CELL)
    return _G["g"]


import bpy  # noqa: E402
_clean = not bpy.data.is_dirty
try:
    main()
except Exception:
    FAILS.append("error: " + traceback.format_exc()[-2500:])
if _clean and bpy.data.is_dirty and bpy.data.filepath.lower().endswith("foundry.blend"):
    bpy.ops.wm.revert_mainfile()
result = {"pass": not FAILS, "passed": len(PASSES), "failed": len(FAILS), "fails": FAILS, "info": INFO,
          "dirty_after": bpy.data.is_dirty}
# the rays can outlast the bridge's 300 s wait: the result is also written to LOG (default <temp>/foundry_check.json)
import tempfile  # noqa: E402
with open(globals().get("FOUNDRY_CHECK_LOG", os.path.join(tempfile.gettempdir(), "foundry_check.json")), "w",
          encoding="utf-8") as _f:
    json.dump(result, _f, indent=1)

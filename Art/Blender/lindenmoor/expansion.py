"""Lindenmoor expansion in Blender (owner-approved layout, 2026-10-23): grows Lindenmoor to its 2,048 x 2,048 footprint
around the finished village, from Art/Regions/Lindenmoor/layout.json (planned by expansion_plan.py, no bpy).

Run in Blender (Art/Tools/blender_mcpc.py code @file.py):
    import sys; sys.path.insert(0, r"E:/Rensei/Rensei-Game-Design/Art/Blender")
    import importlib, lindenmoor.expansion as X; importlib.reload(X)
    result = X.run("village")            # the finished village as a preview (world.py), then
    result = X.run("ground,water,routes") ...  # see STAGES; X.render_all(); X.save()
Scenes in the file:
  * Lindenmoor_Full: the village, rebuilt by world.py as a PREVIEW (Studio already has it; never exported from here);
  * Lindenmoor_Expansion: the new ground, routes, set pieces, trees and markers, plus the village collection linked in
    for renders. Only the expansion's own prefabs are exported (export_expansion() unlinks the village first).
Frames: built in the village's Blender frame (bx = X, by = Z + 650, bz = Y - 4) so export.py works unchanged.
That frame is a mirror image of Roblox's (export maps Roblox (X, Y, Z) to Blender (x, z, y)), so the renders are flipped
to show the place as Studio will: perspective shots left-right, the top-down map top-bottom (north down, east right,
as the brief draws it).
Never saves over Art/Blender/Lindenmoor_Full.blend. Every size here is a PROPOSAL."""
import bpy, json, math, os, random, importlib, time
from mathutils import Vector, Euler, Matrix
from . import core, world, expansion_plan as EP

importlib.reload(core)
importlib.reload(world)
importlib.reload(EP)
from .core import box, cyl, srgb

SCENE = "Lindenmoor_Expansion"
VILLAGE = "Lindenmoor_Full"
REPO = EP.REPO
BLEND = os.path.join(REPO, "Art", "Blender", "Regions", "Lindenmoor_Expansion.blend")
RENDERS = os.path.join(REPO, "Documents", "images", "Regions", "Lindenmoor")
STAGES = ["ground", "water", "routes", "fields", "landmarks", "trees", "markers", "lighting"]
RNG = random.Random(4417)
M = {}


def R(a, b):
    return RNG.uniform(a, b)


def rad(d):
    return math.radians(d)


# ------------------------------------------------------------------ scene plumbing
def plan(force=False):
    ns = bpy.app.driver_namespace
    if force or "lm_exp_plan" not in ns:
        ns["lm_exp_plan"] = EP.plan()
    return ns["lm_exp_plan"]


def use_expansion():
    """Point core/world at the expansion scene (its own root collection)."""
    core.SCENE = core.ROOT = SCENE
    world.COLL.clear()
    if SCENE not in bpy.data.scenes:
        s = bpy.data.scenes.new(SCENE)
        root = bpy.data.collections.new(SCENE)
        s.collection.children.link(root)
    s = bpy.data.scenes[SCENE]
    bpy.context.window.scene = s
    if world.TER is None:
        world.load()
    mats()
    return s


def mats():
    global M
    if not world.M or "grass_ground" not in world.M or world.M["grass_ground"].name not in bpy.data.materials:
        world.mats()
    M = world.M
    if "helper" in M:
        return M
    M["meadow"] = core.pbr("LM_GroundMeadow", "leafy_grass", tile=10, tint=srgb("#c2b66a"), value=0.9, bump=0.3)
    M["side"] = core.pbr("LM_GroundSide", "mossy_rock", tile=18, tint=srgb("#8a8278"), value=0.6, bump=0.8)
    M["ballast"] = core.pbr("LM_Ballast", "stony_dirt_path", tile=6, tint=srgb("#a29e96"), value=0.8, bump=0.7)
    M["falls"] = core.flat("LM_Falls", srgb("#d6ece8"), rough=0.15, emit=(srgb("#cfe6e2"), 0.6))
    M["foam"] = core.flat("LM_Foam", srgb("#eef4f2"), rough=0.7)
    M["shadow"] = core.flat("LM_Shadow", srgb("#040505"), rough=1.0)
    M["helper"] = core.flat("LM_Helper", srgb("#ff00ff"), rough=1.0)
    world.M = M
    return M


MATKEY = {"lm_moss": "grass_ground", "lm_meadow": "meadow", "lm_side": "side", "lm_dirt": "path", "lm_ballast": "ballast",
          "lm_rock": "rock", "lm_cliff": "cliff", "lm_cobble": "cobble", "lm_stone": "stonebase"}


def C(name):
    return world.C(name)


def clear(name):
    """core.clear_coll, but one batch_remove: removing tens of thousands of objects one by one takes Blender minutes."""
    c = core.coll(name)
    objs = list(c.objects)
    if objs:
        bpy.data.batch_remove(objs)
    return c


def pf(kind, ident, X, Z, Y, ang=0.0, coll="Expansion"):
    """A prefab root (Empty) at WORLD (X, Y, Z), turned by ang radians about Blender z. Children: front = +y."""
    e = bpy.data.objects.new(f"PF_{kind}_{ident}", None)
    e.empty_display_size = 2
    e.location = EP.to_blender(X, Y, Z)
    e.rotation_euler = (0, 0, ang)
    e["rs_prefab"] = kind
    e["rs_id"] = str(ident)
    C(coll).objects.link(e)
    return e


def face(X, Z, TX, TZ):
    """Blender z-rotation that turns a prefab's front (+y) toward world (TX, TZ)."""
    return math.atan2(-(TX - X), (TZ - Z))


def yaw(deg):
    return rad(-deg)  # a Roblox yaw (degrees about +Y) is a Blender rotation of -yaw about z (world.prefab)


pb = world.pbox
pc = world.pcyl


def gy(x, z):
    return EP.ground_y(plan(), x, z)


# ------------------------------------------------------------------ village preview
def village():
    """The finished village (world.py) in its own scene, a stepped-ground preview under it, linked into ours."""
    r = world.run("all")
    mats()
    for n in ("TerrainRef",):
        o = bpy.data.objects.get(n)
        if o:
            o.hide_render = True
            o.hide_viewport = True
    pre = village_preview()
    s = use_expansion()
    vroot = bpy.data.collections[VILLAGE]
    if vroot.name not in [ch.name for ch in s.collection.children]:
        s.collection.children.link(vroot)
    # the village's own lighting stays in its scene; ours is built by the lighting stage
    for lc in _walk_lc(bpy.context.view_layer.layer_collection):
        if lc.name == VILLAGE:
            for ch in lc.children:
                if ch.collection.name.split(".")[0] == "Lighting":
                    ch.exclude = True
    return {"village": r, "preview": pre}


def village_preview():
    """A stepped (ground.lua style) preview of the village's part ground. Never exported. A Keep cell is drawn only where
    Ye really has ground, the survey's footprint: inside a Keep Rect (the Adit hill) from the field, elsewhere from
    terrain_studio.json (or its nearest sample just outside it). A Keep cell off the footprint stays empty, so a render
    shows any hole at the seam instead of hiding it (Rulings 14, 15)."""
    mats()
    P = plan()
    V = P.village
    foot = EP.ground_footprint()
    rects = [k["Rect"] for k in P.layout.get("Keep", []) if "Rect" in k]
    core.SCENE = core.ROOT = VILLAGE
    c = clear("VillageGroundPreview")
    top = [[None] * EP.N for _ in range(EP.N)]
    mt = [[None] * EP.N for _ in range(EP.N)]
    chars = {"g": "lm_moss", "l": "lm_moss", "m": "lm_dirt", "d": "lm_dirt", "c": "lm_cobble", "r": "lm_rock", "s": "lm_rock", "w": "lm_rock", "a": "lm_dirt"}
    for i in range(EP.N):
        for j in range(EP.N):
            if not P.keep[i][j]:
                continue
            x, z = EP.cell_center(i, j)
            if any(EP.in_rect(r, x, z) for r in rects):
                if (i, j) in foot:  # the Adit rect (kept only where its parts are): village terrain where the village
                    # has a sample (the rect overlaps the village at x 270..346), else the field (the hill itself)
                    top[i][j] = max(1, round(V.height(x, z) if V.has(x, z) else P.h0[i][j]))
                    mt[i][j] = "lm_moss"
            elif (i, j) in foot:
                top[i][j] = max(1, round(V.height(x, z)))  # V.height falls back to the nearest village sample
                mt[i][j] = chars.get(world.mat_at(x, z - EP.VILLAGE_O[2]), "lm_moss") if V.has(x, z) else "lm_moss"
    tops, sides = EP.merge_ground(top, mt)
    for (i, j, w, d, y, m, _) in tops:
        X0, Z0 = -EP.HALF + EP.CELL * i, -EP.HALF + EP.CELL * j
        o = box(f"VG_T{i}_{j}", (w * 4, d * 4, 1), EP.to_blender(X0 + w * 2, y - 0.5, Z0 + d * 2), M[MATKEY[m]], c, bevel=0)
        o["rs_skip"] = True
    for (i, j, w, d, lo, hi, _) in sides:
        X0, Z0 = -EP.HALF + EP.CELL * i, -EP.HALF + EP.CELL * j
        o = box(f"VG_S{i}_{j}", (w * 4, d * 4, hi - lo), EP.to_blender(X0 + w * 2, (hi + lo) / 2, Z0 + d * 2), M["side"], c, bevel=0)
        o["rs_skip"] = True
    use_expansion()
    return {"preview_tops": len(tops), "preview_sides": len(sides)}


def _walk_lc(lc):
    yield lc
    for ch in lc.children:
        yield from _walk_lc(ch)


# ------------------------------------------------------------------ ground
def ground():
    P = plan()
    for n in ("Ground",):
        clear(n)
        world.COLL.pop(n, None)
    tiles = {}

    def tile(i, j):
        key = (i // 64, j // 64)
        if key not in tiles:
            X = -EP.HALF + key[0] * 256 + 128
            Z = -EP.HALF + key[1] * 256 + 128
            tiles[key] = pf("Ground", f"{key[0]}_{key[1]}", X, Z, 0.0, coll="Ground")
        return tiles[key]

    n = 0
    for (i, j, w, d, y, m, crag) in P.tops:
        rt = tile(i, j)
        X0, Z0 = -EP.HALF + EP.CELL * i, -EP.HALF + EP.CELL * j
        b = Vector(EP.to_blender(X0 + w * 2, y - 0.5, Z0 + d * 2)) - rt.location
        o = pb(rt, f"T{i}_{j}", (w * 4, d * 4, 1), tuple(b), M[MATKEY[m]], bevel=0)
        if crag:
            o["rs_tags"] = "RenseiNoGrip"  # the edge crag is ungrippable (export field 16; owner: no invisible walls)
        n += 1
    for (i, j, w, d, lo, hi, crag) in P.sides:
        rt = tile(i, j)
        X0, Z0 = -EP.HALF + EP.CELL * i, -EP.HALF + EP.CELL * j
        b = Vector(EP.to_blender(X0 + w * 2, (hi + lo) / 2, Z0 + d * 2)) - rt.location
        o = pb(rt, f"S{i}_{j}", (w * 4, d * 4, hi - lo), tuple(b), M["side"], bevel=0)
        if crag:
            o["rs_tags"] = "RenseiNoGrip"  # the crag's climbable inner face
        n += 1
    return n


def water():
    """Preview water planes (Studio fills these boxes with terrain water; SwimService reads it)."""
    P = plan()
    c = clear("WaterPreview")
    world.COLL.pop("WaterPreview", None)
    for w in P.water:
        if "Rect" in w:
            x0, z0, x1, z1 = w["Rect"]
            o = box(f"Water_{w['Id']}", (x1 - x0, z1 - z0, 0.2), EP.to_blender((x0 + x1) / 2, w["Top"] - 0.1, (z0 + z1) / 2), M["water"], c, bevel=0)
        else:
            (ax, az), (bx, bz) = w["From"], w["To"]
            L = math.hypot(bx - ax, bz - az) + w["Width"] * 0.5
            o = box(f"Water_{w['Id']}", (w["Width"], L, 0.2), EP.to_blender((ax + bx) / 2, w["Top"] - 0.1, (az + bz) / 2), M["water"], c,
                    rot=(0, 0, face(ax, az, bx, bz)), bevel=0)
        o["rs_skip"] = True
    with open(os.path.join(REPO, "Art", "Regions", "Lindenmoor", "water_segments.json"), "w", encoding="utf-8") as f:
        json.dump({"Note": "Terrain water boxes for Ye (world studs; fill from Bed to Top with Enum.Material.Water). PROPOSAL.",
                   "Boxes": P.water}, f, indent=1)
    return len(P.water)


# ------------------------------------------------------------------ routes, rails, edging
def _slab(rt, name, a, b, width, base, mat, thick_min=1.2, extra=0.6):
    """A tilted slab whose top runs along a->b (world (x, z, y)), reaching down to the ground at `base`."""
    ax, az, ay = a
    bx, bz, by = b
    L = math.hypot(bx - ax, bz - az)
    pitch = math.atan2(by - ay, L)
    ang = face(ax, az, bx, bz)
    mid = ((ax + bx) / 2, (az + bz) / 2, (ay + by) / 2)
    t = max(thick_min, mid[2] - base + 1.0)
    c = Vector(EP.to_blender(mid[0], mid[2] - t / 2, mid[1])) - rt.location
    return pb(rt, name, (width, L / math.cos(pitch) + extra, t), tuple(c), mat, rot=(pitch, 0, ang), bevel=0)


def routes():
    P = plan()
    for n in ("Routes", "Edging"):
        clear(n)
        world.COLL.pop(n, None)
    roots = {}
    n = 0
    for k, rb in enumerate(P.ribbons):
        rid = rb["route"]
        if rid not in roots:
            x, z, y = rb["p0"]
            roots[rid] = pf("Route", rid, x, z, y, coll="Routes")
        rt = roots[rid]
        mat = M["ballast"] if rb["kind"] == "rail" else M["path"]
        _slab(rt, f"Ribbon{k}", rb["p0"], rb["p1"], rb["width"], rb["base"], mat)
        n += 1
        if rb["kind"] == "rail":
            n += _track(rt, k, rb)
    n += _edging(P)
    return n


def _track(rt, k, rb):
    """Sleepers every 4 studs and two rails (gauge 5.2, as Ye's: rails at x -272.6 / -267.4) on the ballast."""
    a, b = rb["p0"], rb["p1"]
    L = math.hypot(b[0] - a[0], b[1] - a[1])
    ux, uz = (b[0] - a[0]) / L, (b[1] - a[1]) / L
    px, pz = -uz, ux
    pitch = math.atan2(b[2] - a[2], L)
    ang = face(a[0], a[1], b[0], b[1])
    n = 0
    m = int(L // 4)
    for s in range(m):
        t = (s + 0.5) / m
        x, z, y = EP.lerp(a[0], b[0], t), EP.lerp(a[1], b[1], t), EP.lerp(a[2], b[2], t)
        c = Vector(EP.to_blender(x, y + 0.25, z)) - rt.location
        pb(rt, f"Sleeper{k}_{s}", (8, 1.2, 0.5), tuple(c), M["timber"], rot=(pitch, 0, ang), bevel=0.04)
        n += 1
    for side in (-1, 1):
        o = 2.6 * side
        a2 = (a[0] + px * o, a[1] + pz * o, a[2] + 0.8)
        b2 = (b[0] + px * o, b[1] + pz * o, b[2] + 0.8)
        mid = ((a2[0] + b2[0]) / 2, (a2[1] + b2[1]) / 2, (a2[2] + b2[2]) / 2)
        c = Vector(EP.to_blender(mid[0], mid[2], mid[1])) - rt.location
        pb(rt, f"Rail{k}_{side}", (0.5, L / math.cos(pitch) + 0.2, 0.6), tuple(c), M["iron"], rot=(pitch, 0, ang), bevel=0)
        n += 1
    return n


def _edging(P):
    """Rough stones along both verges of the roads (walk-through EdgeStone kit pieces), as the village's lanes have."""
    n = 0
    for rb in P.ribbons:
        if rb["kind"] != "road":
            continue
        a, b = rb["p0"], rb["p1"]
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        ux, uz = (b[0] - a[0]) / L, (b[1] - a[1]) / L
        t = R(2, 8)
        while t < L:
            x, z = a[0] + ux * t, a[1] + uz * t
            for side in (-1, 1):
                if RNG.random() < 0.4:
                    continue
                ex, ez = x - uz * side * (rb["width"] / 2 + 1.4), z + ux * side * (rb["width"] / 2 + 1.4)
                rt = pf("EdgeStone", f"X{n}", ex, ez, gy(ex, ez), R(0, 6.28), coll="Edging")
                s = R(1.2, 2.4)
                pb(rt, "S", (s * R(1, 1.5), s, s * 0.5), (0, 0, -0.05), M["rock"], rot=(R(-0.2, 0.2), R(-0.2, 0.2), 0), bevel=0.1, chip=0.15)
                n += 1
            t += R(10, 16)
    return n


# ------------------------------------------------------------------ patchwork fields
def fields():
    """Hedged, walled and fenced crop fields (field gold, cabbage green, ploughed dirt), one prefab each."""
    P = plan()
    clear("Fields")
    world.COLL.pop("Fields", None)
    n = 0
    for k, f in enumerate(P.fields):
        x0, z0, x1, z1 = f["Rect"]
        W, D = x1 - x0, z1 - z0
        rt = pf("Field", f"{f['District']}_{k}", (x0 + x1) / 2, (z0 + z1) / 2, f["Y"], 0.0, coll="Fields")
        along = f["Rows"] == 0  # rows run along local x (the longer side)
        span, depth = (W, D) if along else (D, W)
        crop = f["Crop"]
        spec = {"wheat": (6, 2.4, (1.6, 2.2), "wheatfield"), "hay": (10, 1.8, (0.9, 1.2), "hay"),
                "cabbage": (5, 1.6, (0.9, 1.2), "foliage"), "plough": (5, 1.4, (0.5, 0.7), "path")}.get(crop)
        if spec:
            gap, wdt, hr, mk = spec
            rows = int((depth - 6) // gap)
            for r_ in range(rows):
                off = -depth / 2 + 3 + gap / 2 + r_ * gap
                hh = R(*hr)
                size = (span - 6, wdt, hh) if along else (wdt, span - 6, hh)
                loc = (0, off, hh / 2) if along else (off, 0, hh / 2)
                pb(rt, f"Row{r_}", size, loc, M[mk], bevel=0.25 if crop != "plough" else 0.1, chip=0.15)
                n += 1
            if crop == "hay":
                for b in range(4):
                    pb(rt, f"Bale{b}", (3.2, 3.2, 2.6), (R(-W / 2 + 6, W / 2 - 6), R(-D / 2 + 6, D / 2 - 6), 1.3), M["hay"], rot=(0, 0, R(0, 3)), bevel=0.5, chip=0.2)
                    n += 1
        else:
            for t in range(3):
                s_ = R(1.2, 2.4)
                pb(rt, f"Tuft{t}", (s_, s_, s_ * 0.8), (R(-W / 2 + 4, W / 2 - 4), R(-D / 2 + 4, D / 2 - 4), s_ * 0.3), M["foliage"], bevel=0.2, chip=0.15)
                n += 1
        # boundary: hedge, dry-stone wall (vaultable) or fence; a 6-stud gate gap in the south side
        sides = (("S", -W / 2, -D / 2, W / 2, -D / 2), ("N", -W / 2, D / 2, W / 2, D / 2), ("W", -W / 2, -D / 2, -W / 2, D / 2), ("E", W / 2, -D / 2, W / 2, D / 2))
        for nm, ax, ay, bx, by in sides:
            L = math.hypot(bx - ax, by - ay)
            horiz = ay == by
            pieces = [(-L / 2, -3), (3, L / 2)] if nm == "S" else [(-L / 2, L / 2)]
            for q, (u0, u1) in enumerate(pieces):
                Lp = u1 - u0
                cu = (u0 + u1) / 2
                cx, cy = ((ax + bx) / 2 + cu, ay) if horiz else (ax, (ay + by) / 2 + cu)
                if f["Bound"] == "hedge":
                    pb(rt, f"Hedge{nm}{q}", (Lp, 2.4, 2.6) if horiz else (2.4, Lp, 2.6), (cx, cy, 1.3), M["foliage"], bevel=0.4, chip=0.35)
                    n += 1
                elif f["Bound"] == "wall":
                    m = max(1, int(Lp // 8))
                    for t in range(m):
                        uu = u0 + (t + 0.5) * Lp / m
                        sx, sy = ((ax + bx) / 2 + uu, ay) if horiz else (ax, (ay + by) / 2 + uu)
                        hh = R(2.4, 2.9)
                        pb(rt, f"Wall{nm}{q}_{t}", (Lp / m + 0.2, 2.2, hh) if horiz else (2.2, Lp / m + 0.2, hh), (sx, sy, hh / 2), M["fieldwall"], bevel=0.3, chip=0.3)
                        n += 1
                else:
                    m = max(1, int(Lp // 12))
                    for t in range(m + 1):
                        uu = u0 + t * Lp / m
                        sx, sy = ((ax + bx) / 2 + uu, ay) if horiz else (ax, (ay + by) / 2 + uu)
                        pb(rt, f"Post{nm}{q}_{t}", (0.6, 0.6, 4), (sx, sy, 1.6), M["timber"], bevel=0.05)
                        n += 1
                    for hh in (1.6, 3.0):
                        pb(rt, f"Rail{nm}{q}_{hh}", (Lp, 0.3, 0.35) if horiz else (0.3, Lp, 0.35), (cx, cy, hh), M["timber"], bevel=0.03)
                        n += 1
    return n


# ------------------------------------------------------------------ set pieces
def _lm(P, Id):
    return next(l for l in P.landmarks if l["Id"] == Id)


def _ang(lm):
    if "Face" in lm:
        return face(lm["At"][0], lm["At"][1], lm["Face"][0], lm["Face"][1])
    return yaw(lm.get("Yaw", 0))


VARIANTS = []


def _variants():
    if VARIANTS:
        return VARIANTS
    r = random.Random(77)
    for i in range(6):
        VARIANTS.append({"W": r.choice((24, 26, 28)), "D": r.choice((16, 17, 18)), "rise": r.uniform(7, 9), "slate": i % 3 == 1,
                         "plaster": ("cream", "ochre", "white")[(i + 1) % 3], "shutter": ("green", "red", "brown")[i % 3],
                         "chimney": r.choice((-1, 1)), "door": r.choice((-6, -4, 4, 6)), "porch": i % 2 == 1,
                         "crates": r.randint(1, 3), "laundry": i % 2 == 0, "shed": i % 3 == 0})
    return VARIANTS


def barn(ident, X, Z, Y, ang, W=26, Hh=12, D=16, coll="Farmsteads"):
    """The village barn's look (world.barn), sized by arguments."""
    rt = pf("Barn", ident, X, Z, Y, ang, coll=coll)
    pb(rt, "Plinth", (W + 1, D + 1, 1.2), (0, 0, 0.6), M["stonebase"], bevel=0.2, chip=0.15)
    pb(rt, "Body", (W, D, Hh), (0, 0, Hh / 2), M["planks_red"], bevel=0.1)
    for i in range(int(W // 6) + 1):
        for side in (-1, 1):
            pb(rt, f"Batten_{side}_{i}", (0.5, 0.4, Hh), (-W / 2 + i * 6, side * (D / 2 + 0.1), Hh / 2), M["timber"], bevel=0.03)
    half, rise = D / 2 + 1.5, Hh * 0.55
    a = math.atan2(rise, half)
    for s in (-1, 1):
        pb(rt, f"Roof_{s}", (W + 2.4, math.hypot(half, rise), 0.9), (0, s * half / 2, Hh + rise / 2), M["roof_slate"], rot=(-s * a, 0, 0), bevel=0.1)
    pb(rt, "Ridge", (W + 3, 1.4, 1.2), (0, 0, Hh + rise + 0.4), M["timber"], bevel=0.12)
    for s in (-1, 1):
        for k in range(4):
            pb(rt, f"Gable_{s}_{k}", (0.5, D - k * D / 4.4, rise / 4 + 0.1), (s * (W / 2), 0, Hh + 0.2 + k * rise / 4), M["planks_red"], bevel=0.04)
    pb(rt, "DoorL", (5, 0.6, Hh * 0.8), (-2.6, D / 2 + 0.3, Hh * 0.4), M["planks"], bevel=0.05)
    pb(rt, "DoorR", (5, 0.6, Hh * 0.8), (2.6, D / 2 + 1.6, Hh * 0.4), M["planks"], rot=(0, 0, rad(-40)), bevel=0.05)
    pb(rt, "LoftDoor", (4, 0.5, 4), (0, D / 2 + 0.2, Hh + 1.5), M["planks"], bevel=0.04)
    for k in range(4):
        pb(rt, f"HayStack{k}", (3.4, 2.6, 2.6), (W / 2 + 3 + (k % 2) * 3.6, -D / 4 + (k // 2) * 3, 1.3), M["hay"], rot=(0, 0, R(-0.2, 0.2)), bevel=0.4, chip=0.25)
    return rt


def _local(rt, x, y):
    """Prefab-local (x, y) -> world (X, Z)."""
    a = rt.rotation_euler[2]
    bx = rt.location.x + x * math.cos(a) - y * math.sin(a)
    by = rt.location.y + x * math.sin(a) + y * math.cos(a)
    return bx + EP.VILLAGE_O[0], by + EP.VILLAGE_O[2]


def field(rt, name, x0, y0, w, d, crop="wheat"):
    """A fenced field in a prefab's local frame: crop rows (wheat or hay bales), posts and rails, one dry-stone side."""
    cx, cy = x0 + w / 2, y0 + d / 2
    if crop == "wheat":
        rows = int(w // 4)
        for k in range(rows):
            pb(rt, f"{name}_Crop{k}", (2.2, d - 3, R(1.4, 2.0)), (x0 + 2 + k * 4, cy, 0.7), M["wheatfield"], bevel=0.3, chip=0.2)
    else:
        for k in range(8):
            pb(rt, f"{name}_Bale{k}", (3.2, 3.2, 2.6), (x0 + 4 + (k % 4) * (w - 8) / 3, y0 + 5 + (k // 4) * (d - 10), 1.3), M["hay"], rot=(0, 0, R(0, 3)), bevel=0.5, chip=0.2)
    # fence on three sides (posts every 8, two rails per side), dry-stone wall on the fourth (vaultable)
    for side, (ax, ay, bx2, by2) in enumerate(((x0, y0, x0 + w, y0), (x0 + w, y0, x0 + w, y0 + d), (x0, y0 + d, x0 + w, y0 + d))):
        L = math.hypot(bx2 - ax, by2 - ay)
        for k in range(int(L // 8) + 1):
            t = k * 8 / L
            pb(rt, f"{name}_Post{side}_{k}", (0.6, 0.6, 4), (EP.lerp(ax, bx2, t), EP.lerp(ay, by2, t), 1.6), M["timber"], bevel=0.05)
        for hgt in (1.6, 3.0):
            pb(rt, f"{name}_Rail{side}_{hgt}", (L if ay == by2 else 0.3, 0.3 if ay == by2 else L, 0.35), ((ax + bx2) / 2, (ay + by2) / 2, hgt), M["timber"], bevel=0.03)
    for k in range(int(d // 6)):
        pb(rt, f"{name}_Wall{k}", (2.4, 6.2, R(2.6, 3.2)), (x0, y0 + 3 + k * 6, 1.3), M["fieldwall"], rot=(0, 0, R(-0.05, 0.05)), bevel=0.3, chip=0.3)


def farmstead(lm):
    X, Z = lm["At"]
    Y = lm["GY"]
    ang = yaw(lm.get("Yaw", 0))
    v = _variants()[lm.get("Variant", 0) % 6]
    yard = pf("Farmyard", lm["Id"], X, Z, Y, ang, coll="Farmsteads")
    # the farmhouse (world.house: the village's kit house), front facing the yard
    h = world.house(lm["Id"], 0, 0, 0, v)
    world.core.link(h, C("Farmsteads"))
    for ch in h.children:
        world.core.link(ch, C("Farmsteads"))
    hx, hz = _local(yard, 0, 14)
    h.location = EP.to_blender(hx, Y, hz)
    h.rotation_euler = (0, 0, ang + math.pi)
    bx, bz = _local(yard, -34, -8)
    barn(lm["Id"], bx, bz, Y, ang + rad(90))
    field(yard, "Wheat", 8, -50, 40, 32, "wheat")
    field(yard, "Hay", -56, -58, 30, 24, "hay")
    # well, cart, woodpile, trough
    for k in range(8):
        a = k / 8 * math.tau
        pb(yard, f"Well{k}", (2.6, 1.4, 1.0), (14 + math.cos(a) * 3.2, -6 + math.sin(a) * 3.2, 0.5), M["stonebase"], rot=(0, 0, a + math.pi / 2), bevel=0.2, chip=0.12)
    pb(yard, "CartBed", (5, 8, 0.6), (-10, -18, 2.4), M["planks"], rot=(0, 0, rad(20)), bevel=0.05)
    for s in (-1, 1):
        pc(yard, f"Wheel{s}", 1.8, 0.5, (-10 + s * 2.9 * math.cos(rad(20)), -18 + s * 2.9 * math.sin(rad(20)), 1.8), M["timber"], rot=(0, rad(90), rad(20)))
    pb(yard, "CartShaft", (0.4, 7, 0.4), (-11.4, -24.5, 1.6), M["timber"], rot=(rad(-8), 0, rad(20)), bevel=0)
    for k in range(5):
        pb(yard, f"Log{k}", (0.9, 5, 0.9), (22 + (k % 3) * 1.0, 6, 0.5 + (k // 3) * 0.9), M["bark"], bevel=0.1)
    pb(yard, "Trough", (6, 2, 1.4), (-20, 4, 0.7), M["planks"], bevel=0.05)
    return yard


def market(lm):
    X, Z = lm["At"]
    rt = pf("Market", lm["Id"], X, Z, lm["GY"], _ang(lm), coll="Farmsteads")
    for i, (x, y, a, cm) in enumerate(((-9, 6, -10, "cloth"), (9, 6, 10, "cloth_b"), (0, -9, 180, "cloth_w"))):
        pb(rt, f"Stall{i}_Counter", (8, 3, 3), (x, y, 1.5), M["planks"], rot=(0, 0, rad(a)), bevel=0.06)
        ca, sa = math.cos(rad(a)), math.sin(rad(a))
        for sx in (-1, 1):
            for sy in (-1, 1):
                pb(rt, f"Stall{i}_Post{sx}{sy}", (0.5, 0.5, 8), (x + ca * sx * 3.6 - sa * sy * 2.2, y + sa * sx * 3.6 + ca * sy * 2.2, 4), M["timber"], bevel=0.04)
        pb(rt, f"Stall{i}_Awning", (9, 6.4, 0.3), (x, y, 8.2), M[cm], rot=(rad(-8), 0, rad(a)), bevel=0.02)
        for k in range(3):
            pb(rt, f"Stall{i}_Goods{k}", (1.6, 1.4, 1.0), (x + ca * (k - 1) * 2.4, y + sa * (k - 1) * 2.4, 3.5), (M["flower_y"], M["hay"], M["foliage"])[k], bevel=0.2, chip=0.1)
    for k in range(6):
        pb(rt, f"Crate{k}", (2.4, 2.4, 2.4), (14 + (k % 2) * 2.6, -4 + (k // 2) * 2.6, 1.2), M["planks"], rot=(0, 0, R(-0.3, 0.3)), bevel=0.08)
    pb(rt, "SignPost", (0.7, 0.7, 9), (-15, -4, 4.5), M["timber"], bevel=0.05)
    pb(rt, "SignBoard", (5, 0.4, 1.6), (-15, -4, 7.6), M["planks"], bevel=0.05)
    return rt


def watermill(lm):
    X, Z = lm["At"]
    Y = lm["GY"]
    rt = pf("Watermill", lm["Id"], X, Z, Y, _ang(lm), coll="Farmsteads")
    pb(rt, "Plinth", (18, 14, 1.4), (0, 0, 0.7), M["stonebase"], bevel=0.2, chip=0.15)
    pb(rt, "Walls", (16, 12, 10), (0, 0, 6), M["stonebase"], bevel=0.15)
    pb(rt, "Upper", (15.4, 11.4, 6), (0, 0, 14), M["plaster_white"], bevel=0.1)
    for k in range(4):
        pb(rt, f"Beam{k}", (0.6, 11.8, 6.2), (-6 + k * 4, 0, 14), M["timber"], bevel=0.05)
    half, rise = 7.5, 5.5
    a = math.atan2(rise, half)
    for s in (-1, 1):
        pb(rt, f"Roof_{s}", (18, math.hypot(half, rise), 0.9), (0, s * half / 2, 17 + rise / 2), M["roof"], rot=(-s * a, 0, 0), bevel=0.1)
    pb(rt, "Door", (3.6, 0.5, 6), (0, 6.2, 3.6), M["planks"], bevel=0.05)
    # the wheel stands in the creek's run, south of the house (local -y)
    wy = -(lm["At"][1] - (-512)) - 1.5  # the creek's north edge is at z -512
    wz = 5.2 - Y + 3.5
    pc(rt, "Wheel", 7.5, 2.4, (0, wy, wz + 4.5), M["timber"], rot=(0, rad(90), 0), verts=16)
    pc(rt, "Axle", 0.8, 6, (0, wy, wz + 4.5), M["iron"], rot=(0, rad(90), 0))
    for k in range(8):
        a = k / 8 * math.tau
        pb(rt, f"Paddle{k}", (2.8, 1.2, 0.3), (0, wy + math.cos(a) * 7.8, wz + 4.5 + math.sin(a) * 7.8), M["planks"], rot=(a, 0, 0), bevel=0.03)
    pb(rt, "Race", (3.6, abs(wy) + 2, 1.2), (6, wy / 2, wz + 12), M["planks"], bevel=0.05)
    return rt


def stone_bridge(lm, route_id):
    """A stone viaduct carrying a route across the creek valley (deck at the route's height at both ends)."""
    P = plan()
    r = next(x for x in P.routes if x["Id"] == route_id)
    (a, b) = r["Bridges"][0]
    ya, yb = _prof_y(r, a), _prof_y(r, b)
    X, Z = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
    Y = (ya + yb) / 2
    L = math.hypot(b[0] - a[0], b[1] - a[1]) + 6
    rt = pf("StoneBridge", lm["Id"], X, Z, Y, face(a[0], a[1], b[0], b[1]), coll="Bridges")
    W = r["Width"] + 2
    pb(rt, "Deck", (W, L, 1.6), (0, 0, -0.8), M["cobble"], bevel=0.1)
    for s in (-1, 1):
        pb(rt, f"Parapet{s}", (1.2, L, 2.4), (s * (W / 2 - 0.6), 0, 1.2), M["stonebase"], bevel=0.15, chip=0.08)
    for k, yy in enumerate((-L / 4, L / 4)):
        hgt = Y - 1.0 + 0.5
        pb(rt, f"Pier{k}", (W - 2, 5, hgt), (0, yy, -1.6 - hgt / 2), M["stonebase"], bevel=0.2, chip=0.15)
        pb(rt, f"Cutwater{k}", (W - 3, 7, 4), (0, yy, -Y + 3), M["stonebase"], bevel=0.3, chip=0.2)
    for k in range(5):
        a2 = (k - 2) * 0.25
        pb(rt, f"Arch{k}", (W - 2, 4, 1.6), (0, math.sin(a2) * 9, -2.4 - math.cos(a2) * 2), M["stonebase"], rot=(a2, 0, 0), bevel=0.15)
    return rt


def _prof_y(r, p):
    prof = r["Profile"]
    best = min(prof, key=lambda q: (q[0] - p[0]) ** 2 + (q[1] - p[1]) ** 2)
    return best[3]


def level_crossing(lm):
    X, Z = lm["At"]
    Y = gy(X, Z - 10)
    rt = pf("LevelCrossing", lm["Id"], X, Z, Y, 0.0, coll="Routes")
    for k in range(4):
        pb(rt, f"Plank{k}", (8.6, 2.4, 0.5), (0, -4.5 + k * 3, 0.85), M["planks"], bevel=0.04)
    for s in (-1, 1):
        pb(rt, f"SignPost{s}", (0.6, 0.6, 9), (s * 7, s * 9, 4.5), M["timber"], bevel=0.05)
        for d in (-1, 1):
            pb(rt, f"Cross{s}{d}", (5, 0.3, 0.8), (s * 7, s * 9 + 0.4, 7.6), M["plaster_white"], rot=(0, d * rad(35), 0), bevel=0.02)
        pb(rt, f"GateArm{s}", (0.5, 10, 0.5), (s * 7, s * 9 - s * 5, 3.4), M["planks_red"], bevel=0.04)
    return rt


def training_field(lm):
    X, Z = lm["At"]
    W, D = lm["Size"]
    Y = lm["GY"]
    rt = pf("TrainingField", lm["Id"], X, Z, Y, 0.0, coll="Training")
    # fence posts every 16 with two rails per side; gaps east (to the lane) and west (to the market road)
    for side, (ax, ay, bx, by) in enumerate(((-W / 2, -D / 2, W / 2, -D / 2), (W / 2, -D / 2, W / 2, D / 2), (W / 2, D / 2, -W / 2, D / 2), (-W / 2, D / 2, -W / 2, -D / 2))):
        L = math.hypot(bx - ax, by - ay)
        for k in range(int(L // 16) + 1):
            t = k * 16 / L
            px, py = EP.lerp(ax, bx, t), EP.lerp(ay, by, t)
            if side in (1, 3) and abs(py) < 9:
                continue
            pb(rt, f"Post{side}_{k}", (0.7, 0.7, 4.2), (px, py, 1.6), M["timber"], bevel=0.05)
        for hgt in (1.6, 3.1):
            if side in (1, 3):
                for half in (-1, 1):
                    seg = D / 2 - 9
                    pb(rt, f"Rail{side}_{hgt}_{half}", (0.3, seg, 0.35), (ax, half * (9 + seg / 2), hgt), M["timber"], bevel=0.03)
            else:
                pb(rt, f"Rail{side}_{hgt}", (L, 0.3, 0.35), ((ax + bx) / 2, ay, hgt), M["timber"], bevel=0.03)
    for k in range(6):  # training dummies
        x, y = -60 + (k % 3) * 22, -30 + (k // 3) * 24
        pb(rt, f"Dummy{k}_Post", (0.8, 0.8, 6), (x, y, 3), M["timber"], bevel=0.05)
        pb(rt, f"Dummy{k}_Arm", (4.4, 0.6, 0.6), (x, y, 4.6), M["timber"], bevel=0.05)
        pb(rt, f"Dummy{k}_Sack", (2.2, 1.6, 2.8), (x, y, 6.4), M["hay"], bevel=0.4, chip=0.15)
    for k in range(3):  # target boards
        x = 40 + k * 14
        pb(rt, f"Target{k}", (6, 0.6, 6), (x, 50, 4.2), M["planks"], bevel=0.05)
        pb(rt, f"TargetRing{k}", (3, 0.7, 3), (x, 50, 4.2), M["planks_red"], bevel=0.05)
        pb(rt, f"TargetLeg{k}", (0.6, 0.6, 4), (x, 50.6, 1.6), M["timber"], bevel=0.03)
    for k in range(5):  # low vault wall (the field-wall vault, again)
        pb(rt, f"VaultWall{k}", (6.2, 2.4, R(2.6, 3.0)), (-20 + k * 6, 40, 1.3), M["fieldwall"], bevel=0.3, chip=0.3)
    pb(rt, "Stand", (12, 8, 2), (60, -40, 1), M["planks"], bevel=0.08)
    for k in range(4):
        pb(rt, f"Rack{k}", (0.25, 0.25, 4.4), (56 + k * 1.2, -34, 4.2), M["iron"], rot=(rad(12), 0, 0), bevel=0)
    pb(rt, "RackBar", (5, 0.6, 0.4), (57.8, -34, 5.2), M["timber"], bevel=0.03)
    return rt


def ridge_marker(lm):
    X, Z = lm["At"]
    rt = pf("RidgeMarker", lm["Id"], X, Z, lm["GY"], _ang(lm), coll="Landmarks")
    pb(rt, "Stone", (3.6, 2.2, 10), (0, 0, 4.6), M["stonebase"], rot=(rad(4), rad(-3), 0), bevel=0.3, chip=0.4)
    pb(rt, "Cap", (4.2, 2.6, 1.2), (0.1, 0, 9.9), M["rock"], rot=(rad(4), rad(-3), 0), bevel=0.3, chip=0.3)
    pb(rt, "Plaque", (2.0, 0.3, 1.4), (0, 1.2, 5.5), M["iron"], bevel=0.05)
    for k in range(8):
        a = k / 8 * math.tau
        s = R(1.2, 2.2)
        pb(rt, f"Cairn{k}", (s * 1.3, s, s * 0.7), (math.cos(a) * 3.4, math.sin(a) * 3.4, s * 0.3), M["rock"], rot=(0, 0, a), bevel=0.15, chip=0.25)
    return rt


def overlook(lm):
    X, Z = lm["At"]
    Y = lm["GY"]
    rt = pf("Overlook", lm["Id"], X, Z, Y, _ang(lm), coll="Landmarks")
    for k in range(3):
        pb(rt, f"Terrace{k}", (18 - k * 2, 12 - k * 1.5, 2.4), (0, 2 + k * 1.2, -1.2 - k * 2.2), M["terrace"], bevel=0.3, chip=0.35)
    pb(rt, "Floor", (16, 11, 1.2), (0, 2, 0.6), M["cobble"], bevel=0.1)
    for k in range(7):
        x = -7 + k * 14 / 6
        pb(rt, f"Post{k}", (0.9, 0.9, 3.4), (x, 7.4, 1.7), M["stonebase"], bevel=0.12)
    pb(rt, "RailFront", (15, 0.7, 0.5), (0, 7.4, 3.4), M["timber"], bevel=0.05)
    for s in (-1, 1):
        pb(rt, f"RailSide{s}", (0.7, 9, 0.5), (s * 7.6, 3, 3.4), M["timber"], bevel=0.05)
    pb(rt, "Bench", (6, 1.6, 0.5), (0, -1, 1.9), M["planks"], bevel=0.05)
    for s in (-1, 1):
        pb(rt, f"BenchLeg{s}", (0.5, 1.4, 1.3), (s * 2.4, -1, 1.2), M["stonebase"], bevel=0.05)
    pc(rt, "Scope", 0.35, 2.2, (4, 6.2, 4.0), M["iron"], rot=(rad(80), 0, 0))
    pb(rt, "ScopeLeg", (0.4, 0.4, 2.8), (4, 6.0, 2.6), M["iron"], bevel=0)
    return rt


def mine_head(lm):
    X, Z = lm["At"]
    Y = lm["GY"]
    rt = pf("MineHead", lm["Id"], X, Z, Y, _ang(lm), coll="Mine")
    # headframe over the old shaft
    for sx in (-1, 1):
        for sy in (-1, 1):
            pb(rt, f"Leg{sx}{sy}", (1.2, 1.2, 22), (sx * 5, sy * 5, 10.5), M["timber"], rot=(sy * rad(-6), sx * rad(6), 0), bevel=0.08)
    for k, z in enumerate((6, 13, 19)):
        for s in (-1, 1):
            pb(rt, f"Brace{k}{s}", (10.5 - k * 1.2, 0.8, 0.8), (0, s * (5 - k * 0.6), z), M["timber"], bevel=0.05)
            pb(rt, f"BraceX{k}{s}", (0.8, 10.5 - k * 1.2, 0.8), (s * (5 - k * 0.6), 0, z), M["timber"], bevel=0.05)
    pc(rt, "Sheave", 3.2, 0.8, (0, 0, 22.5), M["iron"], rot=(0, rad(90), 0), verts=20)
    pb(rt, "Cable", (0.25, 0.25, 20), (0, 3.2, 12.5), M["iron"], bevel=0)
    # the boarded shaft collar
    for k in range(10):
        a = k / 10 * math.tau
        pb(rt, f"Collar{k}", (3.0, 1.6, 1.4), (math.cos(a) * 4.0, math.sin(a) * 4.0, 0.7), M["stonebase"], rot=(0, 0, a + math.pi / 2), bevel=0.2, chip=0.15)
    for k in range(5):
        pb(rt, f"Board{k}", (8, 1.3, 0.3), (0, -3 + k * 1.5, 1.5), M["planks"], rot=(0, 0, R(-0.15, 0.15)), bevel=0.03)
    # winding house
    pb(rt, "WinderBody", (12, 10, 8), (-18, 2, 4), M["planks"], bevel=0.08)
    pb(rt, "WinderRoof", (13.6, 11.6, 0.8), (-18, 2, 8.6), M["roof_slate"], rot=(rad(8), 0, 0), bevel=0.06)
    pb(rt, "WinderDoor", (3.4, 0.5, 6), (-12, 2, 3), M["planks_red"], rot=(0, 0, rad(90)), bevel=0.04)
    pb(rt, "Chimney", (1.6, 1.6, 6), (-21, 5, 11), M["iron"], bevel=0.05)
    # spoil heaps
    for h in range(3):
        hx, hy = (16, -14, 22)[h], (14, 18, -12)[h]
        for k in range(4):
            s = 11 - k * 2.4
            pb(rt, f"Spoil{h}_{k}", (s, s * R(0.8, 1.0), 2.4), (hx + R(-1, 1), hy + R(-1, 1), 1.0 + k * 2.0), M["rock"], rot=(0, 0, R(0, 3)), bevel=0.3, chip=0.45)
    # ore-cart track toward the Adit side, with two carts
    for s in (-1, 1):
        pb(rt, f"CartRail{s}", (0.4, 30, 0.4), (s * 1.6, -22, 0.6), M["iron"], bevel=0)
    for k in range(8):
        pb(rt, f"CartSleeper{k}", (4.6, 0.8, 0.4), (0, -36 + k * 4, 0.2), M["timber"], bevel=0.03)
    for c, yy in enumerate((-16, -30)):
        pb(rt, f"Cart{c}_Body", (3.4, 4.6, 2.4), (0, yy, 2.2), M["iron"], bevel=0.12)
        pb(rt, f"Cart{c}_Ore", (2.8, 4.0, 0.8), (0, yy, 3.6), M["rock"], bevel=0.3, chip=0.3)
        for s in (-1, 1):
            pc(rt, f"Cart{c}_Wheel{s}", 0.8, 0.4, (s * 1.8, yy, 0.9), M["iron"], rot=(0, rad(90), 0), verts=10)
    for k in range(4):
        pb(rt, f"Barrel{k}", (2, 2, 2.6), (8 + k * 2.3, -6, 1.3), M["planks"], bevel=0.4)
    for s in (-1, 1):  # two kit lamp posts (NightOnly)
        lp = pf("LampPost", f"{lm['Id']}_{s}", *_local(rt, s * 12, -10), Y, 0.0, coll="Mine")
        _lamp(lp)
    return rt


def _lamp(rt, h=9.0):
    pb(rt, "Base", (1.6, 1.6, 1.2), (0, 0, 0.6), M["stonebase"], bevel=0.12)
    pb(rt, "Post", (0.8, 0.8, h + 1), (0, 0, (h + 1) / 2), M["timber"], bevel=0.06)
    pb(rt, "Arm", (0.4, 2.7, 0.4), (0, 1.15, h + 0.6), M["iron"])
    pb(rt, "Cap", (1.5, 1.5, 0.3), (0, 2.3, h + 0.3), M["iron"], bevel=0.03)
    g = pb(rt, "Glow", (0.9, 0.9, 1.2), (0, 2.3, h - 0.6), M["glow"], bevel=0.08)
    g["rs_attr"] = json.dumps({"NightOnly": True})  # the world clock's lamp rule (Changelog 2026-10-23, Task 2)
    world.plight(rt, "Light", (0, 2.3, h - 1.0), 3600, rng=22)


def lookout(lm):
    X, Z = lm["At"]
    Y = lm["GY"]
    rt = pf("Lookout", lm["Id"], X, Z, Y, _ang(lm), coll="Gorge")
    pb(rt, "Base", (14, 14, 7), (0, 0, 3.5), M["stonebase"], bevel=0.2, chip=0.15)
    pb(rt, "Floor", (15, 15, 1), (0, 0, 7.5), M["cobble"], bevel=0.1)
    for k in range(7):  # steps up the back
        pb(rt, f"Step{k}", (4, 2, 1), (-4, -8 - k * 2 + 14, 0.5 + k), M["stonebase"], bevel=0.1)
    for sx in (-1, 1):
        for k in range(4):
            pb(rt, f"PostS{sx}_{k}", (0.8, 0.8, 3.4), (sx * 7, -6 + k * 4, 9.7), M["stonebase"], bevel=0.12)
        pb(rt, f"RailS{sx}", (0.6, 15, 0.5), (sx * 7, 0, 11.3), M["timber"], bevel=0.04)
    for k in range(4):
        pb(rt, f"PostF{k}", (0.8, 0.8, 3.4), (-6 + k * 4, 7, 9.7), M["stonebase"], bevel=0.12)
    pb(rt, "RailF", (15, 0.6, 0.5), (0, 7, 11.3), M["timber"], bevel=0.04)
    pb(rt, "FlagPole", (0.5, 0.5, 14), (5.5, -5.5, 15), M["timber"], bevel=0.03)
    pb(rt, "Flag", (3.6, 0.2, 2.4), (7.4, -5.5, 20.6), M["cloth_b"], bevel=0.02)
    pb(rt, "Bench", (5, 1.4, 0.5), (0, 3, 8.9), M["planks"], bevel=0.05)
    return rt


def footbridge(lm, route_id="gorge_crossing"):
    P = plan()
    r = next(x for x in P.routes if x["Id"] == route_id)
    (a, b) = r["Bridges"][0]
    ya, yb = _prof_y(r, a), _prof_y(r, b)
    X, Z = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
    L = math.hypot(b[0] - a[0], b[1] - a[1]) + 4
    Y = (ya + yb) / 2
    rt = pf("Footbridge", lm["Id"], X, Z, Y, face(a[0], a[1], b[0], b[1]), coll="Gorge")
    sag = 2.0
    n = 13
    for k in range(n):  # deck planks with a slight sag
        t = (k + 0.5) / n
        yy = -L / 2 + t * L
        zz = (yb - ya) * (t - 0.5) - sag * math.sin(math.pi * t)
        pb(rt, f"Deck{k}", (5, L / n + 0.2, 0.5), (0, yy, zz - 0.25), M["planks"], rot=(math.atan2(yb - ya, L), 0, 0), bevel=0.04)
        for s in (-1, 1):
            if k % 2 == 0:
                pb(rt, f"Post{k}_{s}", (0.5, 0.5, 4), (s * 2.6, yy, zz + 1.8), M["timber"], bevel=0.03)
    for s in (-1, 1):
        for hh in (2.2, 3.6):
            pb(rt, f"Rope{s}_{hh}", (0.25, L, 0.25), (s * 2.6, 0, (yb - ya) * 0 + hh - sag * 0.6), M["rope"], rot=(math.atan2(yb - ya, L), 0, 0), bevel=0)
    for e, yy in ((0, -L / 2 - 1), (1, L / 2 + 1)):
        for s in (-1, 1):
            pb(rt, f"Tower{e}_{s}", (1.2, 1.2, 9), (s * 3.2, yy, (ya - Y if e == 0 else yb - Y) + 3.5), M["timber"], bevel=0.06)
        pb(rt, f"Lintel{e}", (8, 1, 1), (0, yy, (ya - Y if e == 0 else yb - Y) + 8.2), M["timber"], bevel=0.05)
    return rt


def gorge_ledge(lm):
    """The second ledge walk: a RenseiLedge strip along the gorge's south wall (front face toward the wall), shelves
    at both ends, steps down to the water at the west end and up the wall to the footbridge at the east end."""
    X, Z = lm["At"]
    Lg, Y = lm["Length"], lm["Y"]  # the strip's own height (layout)
    rt = pf("GorgeLedge", lm["Id"], X, Z, Y, 0.0, coll="Gorge")
    s = pb(rt, "LedgeStrip", (Lg, 1.4, 1.0), (0, 0, -0.5), M["rock"], bevel=0.05)
    s["rs_tags"] = "RenseiLedge"
    for e in (-1, 1):
        pb(rt, f"Shelf{e}", (8, 5, 1.2), (e * (Lg / 2 + 4), 1.8, -0.6), M["terrace"], bevel=0.2, chip=0.2)
    for k in range(10):  # west: steps from the water (top 5.2) up to the shelf
        pb(rt, f"StepW{k}", (3, 4, 1.0), (-Lg / 2 - 9 - k * 2.6, 2.2, -0.5 - (k + 1) * 0.62), M["terrace"], bevel=0.15, chip=0.15)
    top = gy(X + Lg / 2 + 8, Z - 4) - Y
    k = 0
    while k * 1.0 < top:  # east: steps cut up the wall, two runs
        x = Lg / 2 + 9 + (k % 12) * 2.4 if (k // 12) % 2 == 0 else Lg / 2 + 9 + (11 - k % 12) * 2.4
        pb(rt, f"StepE{k}", (2.6, 3.2, 1.0), (x, 2.0 + (k // 12) * 3.2, 0.5 + k * 1.0), M["terrace"], bevel=0.15, chip=0.15)
        k += 1
    return rt


def waterfall(lm):
    """The creek falls into the gorge's east end from a notch at rim height (the crag rises behind it)."""
    X, Z = lm["At"]
    top = max(gy(X - 40, Z + 34), gy(X - 40, Z - 38)) + 8
    rt = pf("Waterfall", lm["Id"], X, Z, 5.2, yaw(90), coll="Gorge")
    hgt = max(8.0, top - 5.2)
    pb(rt, "Rock", (44, 10, hgt + 4), (0, 6, (hgt + 4) / 2), M["rock"], bevel=0.4, chip=0.5)  # the cliff behind the falls
    for k, (w, x, bright) in enumerate(((12, -12, 1), (9, -1, 0), (14, 11, 1))):
        pb(rt, f"Strip{k}", (w, 0.8, hgt), (x, 0.4, hgt / 2), M["falls"] if bright else M["foam"], bevel=0.1)
    for k in range(8):
        pb(rt, f"Foam{k}", (R(4, 7), R(3, 5), R(1.2, 2.4)), (-16 + k * 4.6, R(-4, -1), 0.6), M["foam"], rot=(0, 0, R(0, 3)), bevel=0.4, chip=0.3)
    for k in range(3):
        pb(rt, f"Lip{k}", (14, 4, 1.6), (-13 + k * 13, 1.0, hgt + 0.4), M["rock"], bevel=0.3, chip=0.3)
    return rt


def hay_barn(lm):
    X, Z = lm["At"]
    rt = barn(lm["Id"], X, Z, lm["GY"], _ang(lm), W=22, Hh=11, D=14, coll="Meadows")
    for k in range(6):
        pb(rt, f"Bale{k}", (3.2, 3.2, 2.6), (-8 + k * 3.4, 12, 1.3), M["hay"], rot=(0, 0, R(0, 3)), bevel=0.5, chip=0.2)
    return rt


def signal_box(lm):
    X, Z = lm["At"]
    rt = pf("SignalBox", lm["Id"], X, Z, lm["GY"], _ang(lm), coll="Gap")
    pb(rt, "Base", (8, 6, 5), (0, 0, 2.5), M["stonebase"], bevel=0.15)
    pb(rt, "Cabin", (8.4, 6.4, 5), (0, 0, 7.5), M["planks_green"], bevel=0.08)
    for k in range(3):
        pb(rt, f"Window{k}", (2.2, 0.3, 2.2), (-2.6 + k * 2.6, 3.25, 8), M["glass"], bevel=0.02)
    half, rise = 3.8, 2.2
    a = math.atan2(rise, half)
    for s in (-1, 1):
        pb(rt, f"Roof_{s}", (9.6, math.hypot(half, rise), 0.5), (0, s * half / 2, 10 + rise / 2), M["roof_slate"], rot=(-s * a, 0, 0), bevel=0.05)
    for k in range(5):
        pb(rt, f"Stair{k}", (2.4, 1.6, 1), (5.4, -2 + k * 1.2, 0.5 + k), M["planks"], bevel=0.04)
    pb(rt, "SignalPost", (0.6, 0.6, 14), (8, 10, 7), M["iron"], bevel=0)
    pb(rt, "SignalArm", (3.4, 0.3, 0.7), (9.6, 10, 12.5), M["planks_red"], rot=(0, rad(-20), 0), bevel=0.02)
    return rt


def road_gate(lm):
    X, Z = lm["At"]
    rt = pf("RoadGate", lm["Id"], X, Z, gy(X, Z), _ang(lm), coll="Gap")
    for s in (-1, 1):
        pb(rt, f"Pillar{s}", (3, 3, 12), (s * 9, 0, 6), M["stonebase"], bevel=0.2, chip=0.15)
    pb(rt, "Lintel", (21, 3.5, 2.5), (0, 0, 12.6), M["timber"], bevel=0.12)
    pb(rt, "Sign", (9, 0.4, 2.2), (0, -1.9, 12.6), M["planks"], bevel=0.05)
    return rt


def tunnel_portals(lm):
    """Road and rail tunnel mouths in the north edge wall, behind the threshold (the road's way out)."""
    out = []
    for name, x, w, y in (("Road", 820, 16, gy(820, 990)), ("Rail", 750, 13, gy(750, 990) + 1.1)):
        rt = pf("TunnelPortal", f"{lm['Id']}_{name}", x, 999.5, y, 0.0, coll="Gap")
        hgt = w * 0.95
        pb(rt, "Dark", (w, 4, hgt), (0, 2.2, hgt / 2), M["shadow"], bevel=0)
        for s in (-1, 1):
            pb(rt, f"Jamb{s}", (2.6, 3, hgt + 1), (s * (w / 2 + 1.3), -0.6, (hgt + 1) / 2), M["stonebase"], bevel=0.2, chip=0.12)
        for k in range(7):
            a = math.pi * k / 6
            pb(rt, f"Voussoir{k}", (2.6, 3, 2.2), (-math.cos(a) * (w / 2 + 0.6), -0.6, hgt + math.sin(a) * 3.0), M["stonebase"], rot=(0, a - math.pi / 2, 0), bevel=0.15, chip=0.1)
        pb(rt, "Keystone", (3, 3.4, 2.8), (0, -0.8, hgt + 3.4), M["stonebase"], bevel=0.2)
        out.append(rt)
    return out


def reserve(lm):
    """A reserved spot for a piece moving in from the hub: four survey stakes with red rags. Preview only (rs_skip):
    the real piece is moved in Studio at import."""
    X, Z = lm["At"]
    rt = pf("Reserve", lm["Id"], X, Z, lm["GY"], 0.0, coll="Landmarks")
    R = lm["Radius"] * 0.7
    for k, (sx, sy) in enumerate(((-1, -1), (1, -1), (1, 1), (-1, 1))):
        a = pb(rt, f"Stake{k}", (0.6, 0.6, 5), (sx * R, sy * R, 2.0), M["timber"], bevel=0.04)
        b = pb(rt, f"Rag{k}", (1.6, 0.15, 1.0), (sx * R + 0.9, sy * R, 4.0), M["cloth"], bevel=0.02)
        a["rs_skip"] = b["rs_skip"] = True
    rt["rs_reserve"] = lm.get("Holds", "")
    return rt


def landmarks():
    P = plan()
    for n in ("Farmsteads", "Bridges", "Training", "Landmarks", "Mine", "Gorge", "Meadows", "Gap", "Houses", "Lamps"):
        clear(n)
        world.COLL.pop(n, None)
    fns = {
        "lindenmoor.farmstead": farmstead, "lindenmoor.roadside_market": market, "lindenmoor.watermill": watermill,
        "lindenmoor.level_crossing": level_crossing, "lindenmoor.training_field": training_field,
        "lindenmoor.ridge_marker": ridge_marker, "lindenmoor.overlook": overlook, "lindenmoor.mine_head": mine_head,
        "lindenmoor.lookout": lookout, "lindenmoor.gorge_ledge": gorge_ledge, "lindenmoor.waterfall": waterfall,
        "lindenmoor.hay_barn": hay_barn, "lindenmoor.signal_box": signal_box, "lindenmoor.road_gate": road_gate,
        "lindenmoor.tunnel_portals": tunnel_portals, "lindenmoor.reserve": reserve,
    }
    done = []
    for lm in P.landmarks:
        k = lm["Kind"]
        if k == "lindenmoor.stone_bridge":
            stone_bridge(lm, "market_road")
        elif k == "lindenmoor.footbridge":
            footbridge(lm)
        elif k in fns:
            fns[k](lm)
        else:
            continue
        done.append(lm["Id"])
    # lamps at the junctions (kit lamp post look; NightOnly with the world clock)
    for i, (x, z) in enumerate(((10, -150), (-262, -170), (-700, -684), (-596, -444), (540, -470), (580, -680), (676, 676), (12, -60))):
        lp = pf("LampPost", f"X{i}", x, z, gy(x, z), 0.0, coll="Lamps")
        _lamp(lp)
    return done


# ------------------------------------------------------------------ trees (templates cloned, sharing meshes)
TPL = "LM_ExpTemplates"


def _templates():
    if TPL in bpy.data.collections and len(bpy.data.collections[TPL].objects):
        return {k: [o for o in bpy.data.collections[TPL].objects if o.get("tpl") == k] for k in EP.TREE_PARTS}
    c = bpy.data.collections.get(TPL) or bpy.data.collections.new(TPL)
    c.use_fake_user = True
    out = {k: [] for k in EP.TREE_PARTS}
    hold = C("TemplatesBuild")
    for v in range(4):
        out["cypress"].append(world.cypress(f"TPL{v}", 0, 0, h=0.95 + v * 0.12, coll="TemplatesBuild"))
    for v in range(4):
        out["oak"].append(world.oak(f"TPL{v}", 0, 0, scale=0.9 + v * 0.08, coll="TemplatesBuild"))
    for v in range(3):
        out["oak_big"].append(world.oak(f"TPLB{v}", 0, 0, scale=0.85 + v * 0.1, coll="TemplatesBuild", big=True))
    for v in range(4):
        out["oak_far"].append(_oak_far(f"TPL{v}", 0.9 + v * 0.12))
    for v in range(3):
        out["fruit"].append(_fruit(f"TPL{v}", v))
    for k, lst in out.items():
        for rt in lst:
            rt["tpl"] = k
            rt.location = (0, 0, 0)
            for o in [rt] + list(rt.children):
                for x in list(o.users_collection):
                    x.objects.unlink(o)
                c.objects.link(o)
    return out


def _oak_far(ident, s):
    """A cheap forest oak in the kit's style: square trunk, three stacked canopy slabs, two bits (6 parts)."""
    rt = world.prefab("OakFar", ident, 0, 0, 0, coll="TemplatesBuild")
    h = 15 * s
    pb(rt, "Trunk", (2.6 * s, 2.6 * s, h), (0, 0, h / 2 - 0.5), M["bark"], bevel=0.2, chip=0.15)
    for k, (w, z) in enumerate(((20, 0), (15, 3.6), (9, 6.8))):
        pb(rt, f"Canopy{k}", (w * s * R(0.9, 1.1), w * s * R(0.75, 0.9), 4.4 * s), (R(-1, 1), R(-1, 1), h + z * s - 1), M["foliage"], rot=(0, 0, R(0, 3)), bevel=0.4, chip=0.5)
    for k in range(2):
        a = R(0, math.tau)
        pb(rt, f"Bit{k}", (6 * s, 5 * s, 3.4 * s), (math.cos(a) * 8 * s, math.sin(a) * 8 * s, h - 2.5 * s), M["foliage"], rot=(0, 0, R(0, 3)), bevel=0.3, chip=0.4)
    return rt


def _fruit(ident, v):
    rt = world.prefab("FruitTree", ident, 0, 0, 0, coll="TemplatesBuild")
    pb(rt, "Trunk", (1.3, 1.3, 5), (0, 0, 2.0), M["bark"], bevel=0.12, chip=0.1)
    pb(rt, "Canopy0", (8.5, 8, 3.2), (0, 0, 5.6), M["foliage"], rot=(0, 0, R(0, 3)), bevel=0.4, chip=0.4)
    pb(rt, "Canopy1", (6, 6, 2.6), (0.4, -0.3, 7.8), M["foliage"], rot=(0, 0, R(0, 3)), bevel=0.4, chip=0.35)
    pb(rt, "Fruit", (5.2, 5.2, 0.8), (0, 0, 7.0), (M["flower_w"], M["flower_y"], M["cloth"])[v % 3], rot=(0, 0, R(0, 3)), bevel=0.3, chip=0.3)
    return rt


def _clone(tpl, ident, coll, loc, ang):
    r = bpy.data.objects.new(f"PF_{tpl['rs_prefab']}_{ident}", None)
    r.empty_display_size = 2
    r["rs_prefab"] = tpl["rs_prefab"]
    r["rs_id"] = ident
    coll.objects.link(r)
    r.location = loc
    r.rotation_euler = (0, 0, ang)
    pre = tpl.name + "_"
    for ch in tpl.children:
        o = ch.copy()
        o.name = r.name + "_" + (ch.name[len(pre):] if ch.name.startswith(pre) else ch.name)
        coll.objects.link(o)
        o.parent = r
        o.matrix_parent_inverse = ch.matrix_parent_inverse.copy()
    return r


def trees():
    P = plan()
    clear("Forest")
    world.COLL.pop("Forest", None)
    tp = _templates()
    c = C("Forest")
    n = 0
    for k, (kind, x, z, y, a, s, did) in enumerate(P.trees):
        lst = tp[kind]
        tpl = lst[k % len(lst)]
        _clone(tpl, f"{did}_{k}", c, EP.to_blender(x, y, z), rad(a))
        n += 1
    tb = bpy.data.collections.get("TemplatesBuild")
    if tb:
        for o in list(tb.objects):
            bpy.data.objects.remove(o, do_unlink=True)
    return n


# ------------------------------------------------------------------ markers
def markers():
    P = plan()
    clear("Markers")
    world.COLL.pop("Markers", None)
    rt = pf("Markers", "Expansion", 0, -650, 4, 0.0, coll="Markers")
    n = 0
    for k, m in enumerate(P.markers):
        if m["Tag"] == "EdgeGap":
            continue
        if "Box" in m:
            (x0, y0, z0), (x1, y1, z1) = m["Box"]
            size, at = (x1 - x0, z1 - z0, y1 - y0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
        else:
            x, y, z = m["At"]
            y = m.get("Y", y)
            size, at = (2, 2, 2), (x, y + 1, z)
        b = Vector(EP.to_blender(at[0], at[1], at[2])) - rt.location
        o = pb(rt, f"{m['Tag']}{k}", size, tuple(b), M["helper"], rot=(0, 0, yaw(m.get("Yaw", 0))), bevel=0)
        o["rs_invisible"] = True
        o["rs_tags"] = m["Tag"]
        attr = dict(m.get("Attr", {}))
        if attr:
            o["rs_attr"] = json.dumps(attr)
        o.hide_render = True
        o.display_type = "WIRE"
        n += 1
    return n


# ------------------------------------------------------------------ lighting, cameras, renders
def lighting():
    s = use_expansion()
    world.lighting()
    fog = bpy.data.objects.get("FogVolume")
    for o in C("Lighting").objects:
        if o.name.startswith("FogVolume"):
            o.location = (0, 650, 110)
            o.scale = (2.6, 2.6, 1.6)
    for o in C("Lighting").objects:
        if o.name.startswith("Sun_Low"):
            o.rotation_euler = Euler((rad(42), 0, rad(150)))  # a higher sun than the village's (PROPOSAL)
            o.data.energy = 3.2
    fm = bpy.data.materials.get("LM_Fog")
    if fm:
        for nd in fm.node_tree.nodes:
            if nd.type == "PRINCIPLED_VOLUME":
                nd.inputs["Density"].default_value = 0.001  # lighter than Studio's haze, so the renders read
    for attr, val in (("volumetric_end", 3200), ("volumetric_tile_size", "8"), ("volumetric_samples", 64)):
        try:
            setattr(s.eevee, attr, val)
        except Exception:
            pass
    return True


SHOTS = {  # name: (camera x, z, height above ground, target x, z, height above ground, lens) in WORLD studs
    "aerial": (-720, -1340, 760, 40, 60, 0, 22),
    "farmsteads": (-690, -650, 9, -880, -860, 4, 24),
    "mill_creek": (-688, -502, 6, -775, -518, 5, 24),
    "mine_approach": (610, -690, 7, 720, -770, 9, 24),
    "gorge_ledge": (585, -540, 9, 820, -560, 14, 22),
    "lookout": (660, -410, 10, 940, -540, 4, 24),
    "bramble_woods": (548, -888, 7, 760, -930, 8, 22),
    "training_field": (-30, -110, 9, -170, -205, 2, 24),
    "ridge_marker": (-160, -78, 6, -230, 10, 10, 24),
    "cypress_overlook": (-724, 84, 15, -540, -100, 0, 22),
    "north_meadows": (250, 480, 10, 90, 720, 0, 22),
    "northeast_gap": (712, 760, 8, 792, 968, 10, 26),
}
CHECK_SHOTS = {  # Task 2 part B check views (PROPOSAL framing): the grown pads, the seam and the creek joints
    "pad_burned_laboratory": (790, -790, 150, 864, -905, 0, 22),
    "pad_frozen_station": (-620, 630, 80, -760, 760, 0, 22),
    "pad_cracked_footbridge": (720, -580, 90, 860, -700, 0, 22),
    "pad_silent_observatory": (-560, 400, 80, -700, 520, 0, 22),
    "pad_silent_forge": (560, 790, 110, 560, 900, 0, 22),
    "pad_foundry_graybox": (300, 770, 110, 300, 880, 0, 22),
    "pads_test_arena_and_practice_yard": (260, -20, 140, 50, 140, 0, 20),
    "seam_south": (-40, -950, 45, -260, -984, 0, 24),
    "seam_north": (120, -240, 50, -120, -300, 0, 22),
    "seam_adit": (600, -800, 90, 430, -680, 0, 22),
    "east_creek_mouth": (420, -490, 40, 334, -552, 0, 24),
    "west_channel": (-430, -460, 40, -340, -520, 0, 24),
}


def camera(name):
    s = bpy.data.scenes[SCENE]
    c = C("Lighting")
    cx, cz, ch, tx, tz, th, lens = SHOTS[name] if name in SHOTS else CHECK_SHOTS[name]
    cam = bpy.data.objects.get(f"Cam_X_{name}")
    if not cam:
        cd = bpy.data.cameras.new(f"Cam_X_{name}")
        cam = bpy.data.objects.new(f"Cam_X_{name}", cd)
        c.objects.link(cam)
    cam.data.lens = lens
    cam.data.clip_start = 0.5
    cam.data.clip_end = 6000
    cy = ch if name == "aerial" else gy(cx, cz) + ch
    ty = th if name == "aerial" else gy(tx, tz) + th
    p = Vector(EP.to_blender(cx, cy, cz))
    t = Vector(EP.to_blender(tx, ty, tz))
    cam.location = p
    cam.rotation_euler = (t - p).to_track_quat("-Z", "Y").to_euler()
    s.camera = cam
    return cam


def map_camera():
    s = bpy.data.scenes[SCENE]
    cam = bpy.data.objects.get("Cam_X_map")
    if not cam:
        cd = bpy.data.cameras.new("Cam_X_map")
        cam = bpy.data.objects.new("Cam_X_map", cd)
        C("Lighting").objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 2080
    cam.data.clip_end = 6000
    cam.location = EP.to_blender(0, 2400, 0)
    cam.rotation_euler = (0, 0, 0)
    s.camera = cam
    return cam


def _flip(path, axis):
    """Mirror a saved PNG (axis 'x' left-right, 'y' top-bottom) so it shows the place as Studio will."""
    import numpy as np
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    px = px[:, ::-1, :] if axis == "x" else px[::-1, :, :]
    img.pixels.foreach_set(px.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def render(name, samples=40, res=(1920, 1080), tag=""):
    """Render one shot (SHOTS, CHECK_SHOTS or "map") to RENDERS. tag (e.g. "v2") goes into the file name, so a re-render
    never overwrites the approved originals."""
    s = bpy.data.scenes[SCENE]
    os.makedirs(RENDERS, exist_ok=True)
    s.render.resolution_x, s.render.resolution_y = res
    s.eevee.taa_render_samples = samples
    fog_on = name != "map"
    for o in C("Lighting").objects:
        if o.name.startswith("FogVolume"):
            o.hide_render = not fog_on
    if name == "map":
        map_camera()
        s.render.resolution_x = s.render.resolution_y = 2048
    else:
        camera(name)
    path = os.path.join(RENDERS, f"Lindenmoor expansion{' ' + tag if tag else ''} - {name.replace('_', ' ')}.png")
    s.render.filepath = path
    s.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True, scene=s.name)
    _flip(path, "y" if name == "map" else "x")
    return path


def render_all(names=None, samples=40, tag=""):
    out = []
    for n in names or (["map"] + list(SHOTS)):
        t = time.time()
        out.append((render(n, samples, tag=tag), round(time.time() - t, 1)))
    return out


# ------------------------------------------------------------------ budget, export, save
EXP_COLLS = ("Ground", "Routes", "Edging", "Fields", "Farmsteads", "Houses", "Bridges", "Training", "Landmarks", "Mine", "Gorge",
             "Meadows", "Gap", "Lamps", "Forest", "Markers")


def count():
    s = bpy.data.scenes[SCENE]
    root = bpy.data.collections[SCENE]
    by = {}
    tot = 0
    for c in root.children:
        g = c.name.split(".")[0]
        if g not in EXP_COLLS:
            continue
        n = sum(1 for o in c.objects if o.type == "MESH" and o.get("rs_kind") and o.parent and o.parent.get("rs_prefab"))
        by[g] = by.get(g, 0) + n
        tot += n
    return {"parts": tot, "by_group": by, "budget": EP.load()["Budget"], "over": tot > EP.load()["Budget"]}


def export_expansion(out_path):
    """export.py on the expansion scene only (the village preview is unlinked for the run). Tags (rs_tags) need the
    region-foundation Task 9 export change (row field 16); until then markers export with attributes but no tags."""
    from . import export as X
    importlib.reload(X)
    s = bpy.data.scenes[SCENE]
    v = bpy.data.collections.get(VILLAGE)
    linked = v is not None and v.name in [c.name for c in s.collection.children]
    if linked:
        s.collection.children.unlink(v)
    try:
        return X.export(SCENE, out_path)
    finally:
        if linked:
            s.collection.children.link(v)


def save():
    path = os.path.normpath(BLEND)
    assert not path.lower().endswith("lindenmoor_full.blend")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=path, compress=True)
    return path


def run(stage="all"):
    t0 = time.time()
    if stage == "village":
        return village()
    use_expansion()
    todo = STAGES if stage == "all" else stage.split(",")
    fns = {"ground": ground, "water": water, "routes": routes, "fields": fields, "landmarks": landmarks, "trees": trees, "markers": markers, "lighting": lighting}
    done = {}
    for st in todo:
        t = time.time()
        use_expansion()
        r = fns[st]()
        done[st] = {"result": r if isinstance(r, (int, bool)) else (len(r) if hasattr(r, "__len__") else True), "s": round(time.time() - t, 1)}
    return {"done": done, "s": round(time.time() - t0, 1)}

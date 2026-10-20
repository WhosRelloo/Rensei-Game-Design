"""Lindenmoor (full village) in the owner's reference style: blocky, textured, fogged.

Coordinates: everything here is in the village's Roblox-local frame (origin = world (0, 4, -650) in Ye):
  Blender (x, y, z) = Roblox local (X, Z, Y).  A Roblox yaw of θ (about Y) is a Blender rotation of -θ about Z.
Inputs (exported from Studio, Art/Blender/lindenmoor):
  terrain_studio.json  8-stud height/material grid + water cells (the terrain stays in Studio; it's drawn here for reference)
  layout_studio.json   every existing Lindenmoor element (kept, re-skinned or rebuilt in place)
Output: prefab roots (Empty, ["rs_prefab"]) whose children carry rs_kind / rs_size / rs_mat for the Studio exporter.
Every size is a PROPOSAL; gameplay pieces (spawns, ledge, areas, bandit spawns, workshop, trainers, run, hub road) are not touched."""
import bpy, json, math, os, random
from mathutils import Vector, Matrix, Euler
import importlib
from . import core
importlib.reload(core)
from .core import box, cyl, srgb

HERE = os.path.dirname(os.path.abspath(__file__))
RNG = random.Random(2026)
M = {}
TER = None
LAY = None


def R(a, b):
    return RNG.uniform(a, b)


def rad(d):
    return math.radians(d)


# ------------------------------------------------------------------ data
def load():
    global TER, LAY
    TER = json.load(open(os.path.join(HERE, "terrain_studio.json")))
    LAY = {e["name"]: e for e in json.load(open(os.path.join(HERE, "layout_studio.json")))}


def ground(X, Z):
    """Terrain surface height (Roblox local Y) at X, Z, bilinear on the 8-stud grid."""
    st, o, H = TER["step"], TER["origin"], TER["H"]
    fx, fz = (X - o) / st, (Z - o) / st
    i0, j0 = int(math.floor(fz)), int(math.floor(fx))
    vals = []
    for di in (0, 1):
        row = []
        for dj in (0, 1):
            i, j = min(max(i0 + di, 0), len(H) - 1), min(max(j0 + dj, 0), len(H[0]) - 1)
            v = H[i][j]
            row.append(v if v is not None else 0.0)
        vals.append(row)
    tz, tx = fz - i0, fx - j0
    a = vals[0][0] * (1 - tx) + vals[0][1] * tx
    b = vals[1][0] * (1 - tx) + vals[1][1] * tx
    return a * (1 - tz) + b * tz


def mat_at(X, Z):
    st, o, MT = TER["step"], TER["origin"], TER["M"]
    i, j = round((Z - o) / st), round((X - o) / st)
    if 0 <= i < len(MT) and 0 <= j < len(MT[0]):
        return MT[i][j]
    return "x"


def is_water(X, Z, pad=0):
    for w in TER["water"]:
        if abs(w[0] - X) <= 4 + pad and abs(w[1] - Z) <= 4 + pad:
            return True
    return False


# ------------------------------------------------------------------ prefab roots
COLL = {}


def C(name):
    if name not in COLL:
        COLL[name] = core.coll(name)
    return COLL[name]


def prefab(kind, ident, X, Z, yaw_deg=0.0, Y=None, coll="Village"):
    """An Empty at Roblox-local (X, Y, Z) with Roblox yaw; children are built in its local frame (front = +y)."""
    e = bpy.data.objects.new(f"PF_{kind}_{ident}", None)
    e.empty_display_size = 2
    e.location = (X, Z, ground(X, Z) if Y is None else Y)
    e.rotation_euler = (0, 0, rad(-yaw_deg))
    e["rs_prefab"] = kind
    e["rs_id"] = str(ident)
    C(coll).objects.link(e)
    return e


def P(root, o):
    o.parent = root
    return o


def pbox(root, name, size, loc, mat, rot=(0, 0, 0), bevel=0.15, chip=0.0):
    return P(root, box(f"{root.name}_{name}", size, loc, mat, root.users_collection[0], rot=rot, bevel=bevel, chip=chip))


def pcyl(root, name, r, h, loc, mat, rot=(0, 0, 0), verts=12):
    return P(root, cyl(f"{root.name}_{name}", r, h, loc, mat, root.users_collection[0], verts=verts, rot=rot))


def plight(root, name, loc, energy, color="#ffae55", kind="POINT", rng=18):
    L = bpy.data.lights.new(f"{root.name}_{name}", kind)
    L.energy = energy
    L.color = srgb(color)
    L.shadow_soft_size = 0.5
    o = bpy.data.objects.new(f"{root.name}_{name}", L)
    o.location = loc
    o["rs_light"] = kind
    o["rs_range"] = rng
    root.users_collection[0].objects.link(o)
    o.parent = root
    return o


# ------------------------------------------------------------------ reference terrain (drawn only; Studio keeps its terrain)
def terrain_mesh():
    c = core.clear_coll("Terrain_Reference")
    st, o, H, MAT = TER["step"], TER["origin"], TER["H"], TER["M"]
    n = len(H)
    me = bpy.data.meshes.new("TerrainRef")
    verts, faces, fmat = [], [], []
    for i in range(n):
        for j in range(n):
            h = H[i][j]
            verts.append((o + j * st, o + i * st, h if h is not None else -2.0))
    keys = {"g": 0, "l": 0, "x": 0, "r": 1, "s": 1, "m": 2, "d": 2, "c": 3, "w": 2, "a": 2}
    for i in range(n - 1):
        for j in range(n - 1):
            a = i * n + j
            faces.append((a, a + 1, a + n + 1, a + n))
            fmat.append(keys.get(MAT[i][j], 0))
    me.from_pydata(verts, [], faces)
    for m in (M["grass_ground"], M["rock"], M["path"], M["cobble"]):
        me.materials.append(m)
    for p, k in zip(me.polygons, fmat):
        p.material_index = k
        p.use_smooth = True
    ob = bpy.data.objects.new("TerrainRef", me)
    ob["rs_skip"] = True
    c.objects.link(ob)
    # water: one plane per 8-stud water cell at its surface height
    wm = bpy.data.meshes.new("WaterRef")
    wv, wf = [], []
    for k, (x, z, top, bed) in enumerate(TER["water"]):
        b = len(wv)
        wv += [(x - 4, z - 4, top), (x + 4, z - 4, top), (x + 4, z + 4, top), (x - 4, z + 4, top)]
        wf.append((b, b + 1, b + 2, b + 3))
    wm.from_pydata(wv, [], wf)
    wm.materials.append(M["water"])
    wo = bpy.data.objects.new("WaterRef", wm)
    wo["rs_skip"] = True
    c.objects.link(wo)


# ------------------------------------------------------------------ helpers for existing parts (keep geometry, new look)
PMAT = None


def roblox_to_blender_matrix(p):
    """Layout part -> Blender world matrix (unit scale): Roblox CFrame.fromEulerAnglesYXZ(rx, ry, rz) at (X, Y, Z)."""
    rx, ry, rz = (math.radians(a) for a in p["r"])
    Rr = Matrix.Rotation(ry, 3, "Y") @ Matrix.Rotation(rx, 3, "X") @ Matrix.Rotation(rz, 3, "Z")
    Pm = Matrix(((1, 0, 0), (0, 0, 1), (0, 1, 0)))
    Rb = Pm @ Rr @ Pm
    X, Y, Z = p["p"][0], p["p"][1], p["p"][2]
    return Matrix.Translation((X, Z, Y)) @ Rb.to_4x4()


def wedge(name, size, mat, c):
    """Roblox WedgePart in Blender local axes: full height at +y (Roblox back, +Z), sloping down to -y."""
    o = box(name, size, (0, 0, 0), mat, c, bevel=0)
    for v in o.data.vertices:
        if v.co.y < 0 and v.co.z > 0:
            v.co.z = -size[2] / 2
    o["rs_kind"] = "Wedge"
    return o


def reskin(groupname, matmap, coll, skip=(), extra=None):
    """Rebuild a Studio group's parts as Blender blocks with the new materials, same CFrames and sizes."""
    root = bpy.data.objects.new(f"PF_Reskin_{groupname}", None)
    root["rs_prefab"] = f"Reskin_{groupname}"
    root["rs_id"] = groupname
    C(coll).objects.link(root)
    n = 0
    for k in LAY[groupname]["children"]:
        p = k.get("part")
        if not p or p["n"] in skip:
            continue
        mat = matmap.get(p["n"]) or matmap.get(p.get("m", "")) or matmap.get("*")
        if mat is None:
            continue
        sx, sy, sz = p["s"]
        if p.get("c") == "WedgePart":
            o = wedge(f"RS_{groupname}_{p['n']}_{n}", (sx, sz, sy), mat, C(coll))
            o.matrix_world = roblox_to_blender_matrix(p)
        elif p.get("sh") == "Cylinder":
            # Roblox cylinder axis = local X; build along Blender local Z then turn it onto local X
            o = cyl(f"RS_{groupname}_{p['n']}_{n}", sy / 2, sx, (0, 0, 0), mat, C(coll), verts=12)
            o.matrix_world = roblox_to_blender_matrix(p) @ Matrix.Rotation(math.radians(90), 4, "Y")
        else:
            o = box(f"RS_{groupname}_{p['n']}_{n}", (sx, sz, sy), (0, 0, 0), mat, C(coll), bevel=0.08)
            o.matrix_world = roblox_to_blender_matrix(p)
        o.parent = root
        o.matrix_parent_inverse = root.matrix_world.inverted()
        o["rs_source"] = p["n"]
        n += 1
        if extra:
            extra(p, root)
    return root


# ------------------------------------------------------------------ farmhouse (front = +y, lot ~48 x 45)
def house(ident, X, Z, yaw, variant):
    rt = prefab("Farmhouse", ident, X, Z, yaw, Y=4.0, coll="Houses")
    v = variant
    W, D = v["W"], v["D"]
    cy = -3  # body sits back on the lot, porch + yard in front (+y)
    roofm = M["roof_slate"] if v["slate"] else M["roof"]
    pbox(rt, "Plinth", (W + 2, D + 2, 1.4), (0, cy, 0.7), M["stonebase"], bevel=0.2, chip=0.15)
    pbox(rt, "StoneFloor", (W, D, 9), (0, cy, 5.9), M["stonebase"], bevel=0.12)
    for sx in (-1, 1):
        for sy in (-1, 1):
            for k in range(5):
                lg = k % 2 == 0
                pbox(rt, f"Quoin_{sx}_{sy}_{k}", (2.6 if lg else 1.8, 1.8 if lg else 2.6, 1.7),
                     (sx * (W / 2 - (0.9 if lg else 0.5)), cy + sy * (D / 2 - (0.5 if lg else 0.9)), 2.2 + k * 1.75), M["stonebase"], bevel=0.2, chip=0.12)
    pbox(rt, "SillBeam", (W + 1.2, D + 1.2, 1.0), (0, cy, 10.9), M["timber"], bevel=0.1)
    pbox(rt, "UpperPlaster", (W - 0.4, D - 0.4, 7.4), (0, cy, 15.1), M["plaster_" + v["plaster"]], bevel=0.1)
    pbox(rt, "HeadBeam", (W + 0.8, D + 0.8, 0.9), (0, cy, 19.1), M["timber"], bevel=0.1)
    for side, yy in (("F", cy + D / 2), ("B", cy - D / 2)):
        nb = int(W // 5)
        for i in range(nb + 1):
            x = -W / 2 + i * W / nb
            pbox(rt, f"Post_{side}_{i}", (0.9, 0.9, 7.6), (x, yy, 15.1), M["timber"], bevel=0.08)
            if i < nb:
                pbox(rt, f"Brace_{side}_{i}", (0.6, 0.7, 7.0), (x + W / nb / 2, yy, 15.1), M["timber"], rot=(0, rad(30 if i % 2 else -30), 0), bevel=0.06)
    for side, xx in (("L", -W / 2), ("R", W / 2)):
        for i in range(4):
            pbox(rt, f"Post_{side}_{i}", (0.9, 0.9, 7.6), (xx, cy - D / 2 + i * D / 3, 15.1), M["timber"], bevel=0.08)
    # roof (ridge along x), tile rows, rafters, ridge, gables
    half, rise, over = D / 2 + 2.2, v["rise"], 1.8
    ang = math.atan2(rise, half)
    slope = math.hypot(half, rise)
    for s in (-1, 1):
        pbox(rt, f"Roof_{s}", (W + over * 2, slope, 1.0), (0, cy + s * half / 2, 19.6 + rise / 2), roofm, rot=(-s * ang, 0, 0), bevel=0.1)
        rows = 6
        for r in range(rows):
            t = (r + 0.5) / rows
            pbox(rt, f"TileRow_{s}_{r}", (W + over * 2 - 0.2, slope / rows + 0.15, 0.45),
                 (0, cy + s * half * t, 19.6 + rise * (1 - t) + 0.75), roofm, rot=(-s * ang, 0, 0), bevel=0.12, chip=0.08)
        for i in range(int(W // 3) + 1):
            pbox(rt, f"Rafter_{s}_{i}", (0.6, 2.6, 0.7), (-W / 2 + i * 3, cy + s * (D / 2 + 1.3), 19.2), M["timber"], rot=(-s * ang, 0, 0), bevel=0.05)
    pbox(rt, "Ridge", (W + over * 2 + 0.6, 1.6, 1.4), (0, cy, 19.6 + rise + 0.6), M["timber"], bevel=0.15)
    for s in (-1, 1):
        for k in range(5):
            pbox(rt, f"Gable_{s}_{k}", (0.6, D - k * D / 5.3, rise / 5 + 0.1), (s * (W / 2 - 0.3), cy, 19.8 + k * rise / 5), M["plaster_" + v["plaster"]], bevel=0.05)
        for f in (-1, 1):
            pbox(rt, f"Barge_{s}_{f}", (0.5, slope + 0.6, 0.8), (s * (W / 2 + over), cy + f * half / 2, 19.8 + rise / 2), M["timber"], rot=(-f * ang, 0, 0))
    chx = (W / 2 - 4) * (1 if v["chimney"] > 0 else -1)
    pbox(rt, "Chimney", (3.4, 3.4, rise + 7), (chx, cy - D / 4, 19.6 + (rise + 7) / 2 - 1), M["stonebase"], bevel=0.15, chip=0.1)
    pbox(rt, "ChimneyCap", (4.4, 4.4, 0.8), (chx, cy - D / 4, 19.6 + rise + 6.2), M["stonebase"], bevel=0.15)
    # front door + steps + lantern
    dx, fy = v["door"], cy + D / 2
    pbox(rt, "DoorFrameL", (1.0, 1.4, 9.6), (dx - 3.5, fy + 0.2, 5.6), M["timber"])
    pbox(rt, "DoorFrameR", (1.0, 1.4, 9.6), (dx + 3.5, fy + 0.2, 5.6), M["timber"])
    pbox(rt, "DoorLintel", (8.6, 1.6, 1.4), (dx, fy + 0.25, 10.6), M["stonebase"], bevel=0.15)
    pbox(rt, "Door", (6, 0.6, 9), (dx, fy + 0.15, 5.9), M["planks"], bevel=0.05)
    for z in (3.0, 8.6):
        pbox(rt, f"Hinge_{z}", (4.2, 0.2, 0.35), (dx - 0.6, fy + 0.5, z), M["iron"], bevel=0.02)
    for k in range(2):
        pbox(rt, f"Step_{k}", (8 - k, 2.4, 0.7), (dx, fy + 2.4 - k * 1.1, 0.35 + k * 0.7), M["stonebase"], bevel=0.15, chip=0.12)
    pbox(rt, "Lantern_Arm", (0.3, 2.0, 0.3), (dx - 5, fy + 1.0, 9.2), M["iron"])
    pbox(rt, "Lantern", (1.0, 1.0, 1.4), (dx - 5, fy + 2.0, 8.4), M["glow"], bevel=0.1)
    plight(rt, "LanternLight", (dx - 5, fy + 2.6, 8.2), 3200, rng=20)

    def window(name, x, y, z, face=1, shutters=True, flowers=False, w=3.6, h=4.2):
        pbox(rt, f"{name}_Glass", (w, 0.3, h), (x, y, z), M["glass"], bevel=0)
        pbox(rt, f"{name}_Top", (w + 0.9, 0.7, 0.6), (x, y + face * 0.3, z + h / 2), M["timber"], bevel=0.05)
        pbox(rt, f"{name}_Sill", (w + 1.6, 1.4, 0.6), (x, y + face * 0.6, z - h / 2 - 0.2), M["stonebase"], bevel=0.08)
        pbox(rt, f"{name}_Mullion", (0.35, 0.5, h), (x, y + face * 0.25, z), M["timber"], bevel=0)
        if shutters:
            pbox(rt, f"{name}_ShL", (w / 2, 0.4, h + 0.4), (x - w * 0.85, y + face * 0.4, z), M["planks_" + v["shutter"]], bevel=0.04)
            pbox(rt, f"{name}_ShR", (w / 2, 0.4, h + 0.4), (x + w * 0.85, y + face * 0.4, z), M["planks_" + v["shutter"]], bevel=0.04)
        if flowers:
            pbox(rt, f"{name}_Box", (w + 1, 1.2, 1.0), (x, y + face * 1.1, z - h / 2 - 0.9), M["planks"], bevel=0.05)
            for k in range(6):
                fm = (M["flower_y"], M["flower_w"], M["flower_p"], M["foliage"])[(k + len(name)) % 4]
                pbox(rt, f"{name}_Bloom{k}", (0.6, 0.6, 0.6), (x - w / 2 + 0.6 + k * w / 5.5, y + face * 1.1, z - h / 2 - 0.1), fm, bevel=0.15)
    xs_g = [x for x in (-W / 2 + 4, -W / 2 + 9, W / 2 - 9, W / 2 - 4) if abs(x - dx) > 5.5][:3]
    for i, x in enumerate(xs_g):
        window(f"WinG{i}", x, fy, 5.8)
    for i, x in enumerate((-W / 2 + 5, 0, W / 2 - 5)):
        window(f"WinU{i}", x, fy, 15.0, shutters=False, flowers=(i != 1))
    for i, x in enumerate((-W / 4, W / 4)):
        window(f"WinB{i}", x, cy - D / 2, 15.0, face=-1, shutters=False)
    # porch
    if v["porch"]:
        pw = W * 0.55
        px = dx
        pbox(rt, "PorchDeck", (pw, 5.5, 0.6), (px, fy + 3.2, 1.6), M["planks"], bevel=0.05)
        for sx in (-1, 1):
            pbox(rt, f"PorchPost_{sx}", (0.8, 0.8, 8.2), (px + sx * (pw / 2 - 0.5), fy + 5.5, 5.6), M["timber"], bevel=0.06)
        pbox(rt, "PorchBeam", (pw + 0.6, 0.8, 0.8), (px, fy + 5.5, 9.8), M["timber"])
        pbox(rt, "PorchRoof", (pw + 2, 7, 0.6), (px, fy + 3.4, 10.6), roofm, rot=(rad(-14), 0, 0), bevel=0.05)
        for sx in (-1, 1):
            pbox(rt, f"PorchRail_{sx}", (0.4, 5.2, 0.4), (px + sx * (pw / 2 - 0.5), fy + 3.0, 4.2), M["timber"], bevel=0.03)
    # yard: front wall with a gate gap, garden bed, woodpile, barrel, crates, bench, laundry line, shed
    ly = 19.5
    for side in (-1, 1):
        x0, x1 = (-22, dx - 3.5) if side < 0 else (dx + 3.5, 22)
        t = x0
        while t < x1 - 1:
            w = min(R(2.4, 4.2), x1 - t)
            pbox(rt, f"YardWall_{side}_{t:.0f}", (w, 1.6, R(2.4, 3.0)), (t + w / 2, ly, 1.2), M["fieldwall"], rot=(0, 0, R(-0.05, 0.05)), bevel=0.3, chip=0.2)
            t += w + 0.2
    gx = -W / 2 - 2 if dx > 0 else W / 2 + 2
    gx = max(min(gx, 17), -17)
    pbox(rt, "GardenSoil", (8, 10, 0.6), (gx * 0.9, 12, 0.3), M["path"], bevel=0.1)
    for r in range(3):
        for k in range(4):
            pbox(rt, f"Crop_{r}_{k}", (1.4, 1.4, 1.2), (gx * 0.9 - 2.8 + k * 1.9, 8.5 + r * 3.2, 1.0), M["foliage"], bevel=0.3, chip=0.15)
    for r in range(3):
        for k in range(5 - r):
            pcyl(rt, f"Log_{r}_{k}", 0.55, 4.5, (-W / 2 + 2 + k * 1.15 + r * 0.55, cy - D / 2 - 1.6, 0.55 + r * 1.0), M["bark"], rot=(rad(90), 0, 0), verts=8)
    bxx = W / 2 + 1.6
    pcyl(rt, "RainBarrel", 1.6, 3.4, (bxx, fy - 1.5, 1.7), M["planks"], verts=12)
    for k in range(2):
        pcyl(rt, f"BarrelHoop{k}", 1.66, 0.25, (bxx, fy - 1.5, 0.8 + k * 1.6), M["iron"], verts=12)
    for k in range(v["crates"]):
        pbox(rt, f"Crate{k}", (2.8, 2.8, 2.8), (bxx + 1.5 + (k % 2) * 3, fy + 3 + (k // 2) * 3, 1.4), M["planks"], rot=(0, 0, R(-0.3, 0.3)), bevel=0.08)
    pbox(rt, "Bench", (5, 1.6, 0.4), (dx + (7 if dx < 0 else -7), fy + 1.8, 2.0), M["planks"], bevel=0.04)
    for sx in (-2, 2):
        pbox(rt, f"BenchLeg{sx}", (0.4, 1.4, 2), (dx + (7 if dx < 0 else -7) + sx, fy + 1.8, 1.0), M["timber"], bevel=0.03)
    if v["laundry"]:
        lx0, lx1 = -18, -6
        for xx in (lx0, lx1):
            pbox(rt, f"LinePost_{xx}", (0.6, 0.6, 8), (xx, cy - D / 2 - 7, 4), M["timber"], bevel=0.05)
        pbox(rt, "Line", (lx1 - lx0, 0.12, 0.12), ((lx0 + lx1) / 2, cy - D / 2 - 7, 7.6), M["rope"], bevel=0)
        for k in range(4):
            pbox(rt, f"Cloth{k}", (2.2, 0.2, R(2.4, 3.6)), (lx0 + 2 + k * 2.8, cy - D / 2 - 7, 6.0), (M["cloth"], M["cloth_w"], M["cloth_b"])[k % 3], bevel=0.02)
    if v["shed"]:
        sx0 = W / 2 + 5 if v["chimney"] > 0 else -W / 2 - 5
        sx0 = max(min(sx0, 19), -19)
        pbox(rt, "Shed", (6, 7, 6), (sx0, cy - D / 2 + 4, 3), M["planks"], bevel=0.08)
        pbox(rt, "ShedRoof", (7.4, 8.4, 0.6), (sx0, cy - D / 2 + 4, 6.4), roofm, rot=(rad(12), 0, 0), bevel=0.05)
    # tufts around the lot edges
    for k in range(14):
        a = R(0, math.tau)
        rr = R(14, 22)
        x, y = math.cos(a) * rr, math.sin(a) * rr * 0.9
        s = R(0.9, 2.2)
        pbox(rt, f"Tuft{k}", (s, s * R(0.7, 1.1), s * R(0.6, 1.0)), (x, y, s * 0.3 - 0.1), M["foliage"], rot=(0, 0, R(0, 3)), bevel=0.2, chip=0.15)
    return rt


def houses():
    core.clear_coll("Houses")
    COLL.pop("Houses", None)
    variants = []
    for i in range(9):
        variants.append({"W": RNG.choice((24, 26, 28)), "D": RNG.choice((16, 17, 18)), "rise": R(7, 9), "slate": i % 3 == 1,
                         "plaster": ("cream", "ochre", "white")[i % 3], "shutter": ("green", "red", "brown")[(i + 1) % 3],
                         "chimney": RNG.choice((-1, 1)), "door": RNG.choice((-6, -4, 4, 6)), "porch": i % 2 == 0,
                         "crates": RNG.randint(1, 3), "laundry": i % 3 == 2, "shed": i % 4 == 1})
    for k, h in enumerate(LAY["Houses"]["children"]):
        X, Y, Z, yaw = h["pivot"]
        house(h["n"], X, Z, yaw, variants[k % 9])


# ------------------------------------------------------------------ trees
def oak(ident, X, Z, scale=1.0, coll="Trees", big=False):
    rt = prefab("Oak" + ("Big" if big else ""), ident, X, Z, R(0, 360), coll=coll)
    hgt = (R(52, 64) if big else R(17, 22)) * scale
    tr = (R(7, 9) if big else R(3.0, 3.8)) * scale
    cw = (R(54, 66) if big else R(19, 24)) * scale
    for k in range(3 if not big else 4):
        a = k * math.tau / (3 if not big else 4) + R(-0.3, 0.3)
        pbox(rt, f"Root{k}", (tr * 0.9, tr * 0.55, 2.0 * scale), (math.cos(a) * tr * 0.55, math.sin(a) * tr * 0.55, 0.8), M["bark"], rot=(R(-0.12, 0.12), R(-0.2, 0.2), a), bevel=0.2, chip=0.25)
    pbox(rt, "Trunk", (tr, tr, hgt), (0, 0, hgt / 2 - 0.5), M["bark"], rot=(0, 0, R(0, 0.6)), bevel=0.25, chip=0.2)
    nb = 5 if big else 4
    for k in range(nb):
        a = k / nb * math.tau + R(-0.3, 0.3)
        L = R(0.3, 0.42) * cw
        z = hgt * R(0.62, 0.84)
        pbox(rt, f"Branch{k}", (tr * 0.4, tr * 0.4, L), (math.cos(a) * L * 0.45, math.sin(a) * L * 0.45, z + L * 0.25), M["bark"], rot=(0, rad(R(55, 70)), a), bevel=0.12, chip=0.12)
    layers = 4 if big else 3
    for k in range(layers):
        w = cw * (1 - k * 0.15) * R(0.9, 1.1)
        d = w * R(0.75, 0.9)
        pbox(rt, f"Canopy{k}", (w, d, R(4, 6) * (1.2 if big else 1)), (R(-2, 2) * scale, R(-2, 2) * scale, hgt + k * 4 * scale - 1.5), M["foliage"], rot=(0, 0, R(0, math.pi)), bevel=0.4, chip=0.6)
        for j in range(4 if big else 3):
            a = R(0, math.tau)
            r = R(0.35, 0.5) * w
            pbox(rt, f"Bit{k}_{j}", (R(0.18, 0.3) * cw, R(0.15, 0.25) * cw, R(3, 5)), (math.cos(a) * r, math.sin(a) * r, hgt + k * 4 * scale - R(2.5, 4.5)), M["foliage"], rot=(0, 0, R(0, math.pi)), bevel=0.3, chip=0.4)
    for k in range(6 if big else 4):
        a = R(0, math.tau)
        r = R(0.15, 0.42) * cw
        L = R(5, 16) * scale
        pbox(rt, f"Vine{k}", (R(0.4, 0.7), R(0.4, 0.7), L), (math.cos(a) * r, math.sin(a) * r, hgt - 3 - L / 2), M["vine"], bevel=0.05)
    return rt


def cypress(ident, X, Z, h=1.0, coll="Trees"):
    rt = prefab("Cypress", ident, X, Z, R(0, 360), coll=coll)
    pbox(rt, "Trunk", (1.6, 1.6, 8 * h), (0, 0, 4 * h - 0.5), M["bark"], bevel=0.1)
    tiers = 6
    for k in range(tiers):
        s = 7.5 * (1 - k * 0.13) * R(0.9, 1.1)
        pbox(rt, f"Tier{k}", (s, s * 0.9, 5.2 * h), (0, 0, 7 * h + k * 4.6 * h), M["cypress"], rot=(0, 0, R(0, 1)), bevel=0.3, chip=0.35)
    return rt


def trees():
    core.clear_coll("Trees")
    COLL.pop("Trees", None)
    parts = [k["part"] for k in LAY["Trees"]["children"]]
    oaks = [p for p in parts if p["n"] == "OakTrunk"]
    cyps = [p for p in parts if p["n"] == "CypressTrunk"]
    for i, p in enumerate(oaks):
        oak(i, p["p"][0], p["p"][2], scale=R(0.9, 1.15))
    for i, p in enumerate(cyps):
        cypress(i, p["p"][0], p["p"][2], h=R(0.9, 1.25))


# ------------------------------------------------------------------ forests, ridge, creek banks, edging (new)
BLOCK = []  # (X, Z, radius): keep-clear zones


def clear(X, Z, r=0):
    if X > 270 - r and -95 - r < Z < 75 + r:
        return False  # Halvard's Adit (east ridge, world model HalvardsAdit)
    if abs(X) < 20 + r and Z > 300:
        return False  # hub road
    for bx, bz, br in BLOCK:
        if (X - bx) ** 2 + (Z - bz) ** 2 < (br + r) ** 2:
            return False
    return not is_water(X, Z, pad=6)


def keepout():
    BLOCK.clear()
    # village core, square, roads, lane, houses, workshop hill, station, camp clearing, gorge, adit approach, hub road
    BLOCK.extend([(0, 0, 60), (195, -95, 75), (-262, 0, 40), (223, -232, 20), (231, 115, 40), (330, -10, 40), (0, 200, 18), (0, 300, 18)])
    for x in range(-240, 241, 20):
        BLOCK.append((x, 0, 14))
    for z in range(-240, 281, 20):
        BLOCK.append((-270, z, 14))  # railway
    for z in range(-210, 360, 20):
        BLOCK.append((0, z, 14))
    for h in LAY["Houses"]["children"]:
        BLOCK.append((h["pivot"][0], h["pivot"][2], 30))
    for k in LAY["Farm"]["children"]:
        p = k["part"]
        BLOCK.append((p["p"][0], p["p"][2], max(p["s"][0], p["s"][2]) / 2 + 4))
    for k in LAY["Station"]["children"]:
        p = k["part"]
        if p["n"] in ("Rail", "StationHouse", "Canopy", "PlatformEdge"):
            BLOCK.append((p["p"][0], p["p"][2], 10))


def forests():
    core.clear_coll("Forest")
    COLL.pop("Forest", None)
    keepout()
    n = 0
    # rim belts: big oaks around the valley edge, staggered rows, fading into the fog
    for X in range(-330, 331, 42):
        for Z in (-322, 326):
            x, z = X + R(-9, 9), Z + R(-8, 8)
            if clear(x, z, 10):
                oak(f"Rim{n}", x, z, scale=R(0.85, 1.1), coll="Forest", big=True)
                n += 1
    for Z in range(-290, 300, 44):
        for X in (-328, 330):
            x, z = X + R(-8, 8), Z + R(-9, 9)
            if clear(x, z, 10):
                oak(f"Rim{n}", x, z, scale=R(0.85, 1.1), coll="Forest", big=True)
                n += 1
    # Bramble Hollow: dense woods around the camp clearing (canopy shade = the stealth intro)
    for k in range(16):
        a = k / 16 * math.tau + R(-0.15, 0.15)
        r = R(30, 52)
        x, z = 223 + math.cos(a) * r, -232 + math.sin(a) * r
        oak(f"Hollow{k}", x, z, scale=R(0.7, 0.9), coll="Forest", big=True)
    return n


def ridge():
    """Cypress Ridge: stacked mossy rock terraces along the south edge (Z ~ -260..-340) with cypress rows."""
    core.clear_coll("Ridge")
    COLL.pop("Ridge", None)
    n = 0
    for X in range(-320, 321, 22):
        x = X + R(-4, 4)
        z = -268 + R(-6, 6)
        if not clear(x, z, 4) or abs(x) < 16:
            continue
        rt = prefab("RidgeTerrace", n, x, z, R(-8, 8), coll="Ridge")
        hz = 0
        for k in range(RNG.randint(2, 4)):
            h = R(2.4, 3.6)
            pbox(rt, f"Slab{k}", (R(18, 26) - k * 3, R(12, 16) - k * 2, h), (R(-1, 1), -k * R(3, 5), hz + h / 2), M["terrace"], rot=(0, 0, R(-0.08, 0.08)), bevel=0.3, chip=0.35)
            hz += h * 0.95
        n += 1
    return n


def creek_banks():
    """Stacked stone along the creek and pond edges (water cells next to land)."""
    core.clear_coll("CreekBanks")
    COLL.pop("CreekBanks", None)
    water = {(w[0], w[1]) for w in TER["water"]}
    st = TER["step"]
    n = 0
    for (x, z) in sorted(water):
        for dx, dz in ((st, 0), (-st, 0), (0, st), (0, -st)):
            if (x + dx, z + dz) in water or RNG.random() < 0.35:
                continue
            bx, bz = x + dx * 0.55, z + dz * 0.55
            if abs(bx) < 10 and 95 < bz < 125:
                continue  # under the bridge
            rt = prefab("BankStones", n, bx, bz, R(0, 360), coll="CreekBanks")
            g = ground(bx, bz)
            for k in range(RNG.randint(2, 3)):
                s = R(2.4, 4.4)
                pbox(rt, f"Stone{k}", (s * R(1, 1.6), s * R(0.8, 1.2), s * R(0.5, 0.8)), (R(-1.5, 1.5), R(-1.5, 1.5), -0.8 + k * 1.2), M["rock"], rot=(R(-0.2, 0.2), R(-0.2, 0.2), R(0, 3)), bevel=0.12, chip=0.3)
            n += 1
    return n


def edging():
    """Rough stones along both sides of the lane and the north road; tuft clusters along the verges."""
    core.clear_coll("Edging")
    COLL.pop("Edging", None)
    n = 0
    lines = [((-235, 0), (235, 0), 7.5), ((0, -195), (0, 340), 8.0)]
    for (x0, z0), (x1, z1), off in lines:
        L = math.hypot(x1 - x0, z1 - z0)
        t = 0
        while t < L:
            x, z = x0 + (x1 - x0) * t / L, z0 + (z1 - z0) * t / L
            for side in (-1, 1):
                ex, ez = (x, z + side * off) if z0 == z1 else (x + side * off, z)
                if (ex ** 2 + ez ** 2) < 38 ** 2 or is_water(ex, ez, 2) or mat_at(ex, ez) not in "gl" or RNG.random() < 0.35:
                    continue
                rt = prefab("EdgeStone", n, ex, ez, R(0, 360), coll="Edging")
                s = R(1.2, 2.4)
                pbox(rt, "S", (s * R(1, 1.5), s, s * 0.5), (0, 0, -0.05), M["rock"], rot=(R(-0.2, 0.2), R(-0.2, 0.2), 0), bevel=0.1, chip=0.15)
                if RNG.random() < 0.5:
                    t2 = R(0.9, 1.8)
                    pbox(rt, "Tuft", (t2, t2, t2 * 0.8), (R(-2, 2), R(-2, 2), t2 * 0.3), M["foliage"], rot=(0, 0, R(0, 3)), bevel=0.2, chip=0.15)
                n += 1
            t += R(9, 15)
    return n


# ------------------------------------------------------------------ square, lamps, camp, barn, existing groups re-skinned
def square():
    core.clear_coll("Square")
    COLL.pop("Square", None)
    rt = prefab("Square", "Main", 0, 0, 0, Y=4.0, coll="Square")
    # cobble border ring + inner patterned slabs
    for k in range(28):
        a = k / 28 * math.tau
        if min(abs(math.sin(a)), abs(math.cos(a))) < 0.2:
            continue  # leave the road and lane crossings open
        pbox(rt, f"Kerb{k}", (8.2, 1.6, 0.5), (math.cos(a) * 34, math.sin(a) * 34, 0.05), M["stonebase"], rot=(0, 0, a + math.pi / 2), bevel=0.15, chip=0.08)
    for k in range(16):
        a = k / 16 * math.tau + 0.2
        r = R(14, 28)
        pbox(rt, f"Flag{k}", (R(4, 7), R(3, 5), 0.3), (math.cos(a) * r, math.sin(a) * r, 0.05), M["cobble"], rot=(0, 0, R(0, 3)), bevel=0.1)
    # market stalls
    for i, (x, y, ang, cm) in enumerate(((-20, 18, -30, "cloth"), (22, 16, 35, "cloth_b"), (-24, -12, 200, "cloth_w"))):
        st = pbox(rt, f"Stall{i}_Counter", (8, 3, 3), (x, y, 1.5), M["planks"], rot=(0, 0, rad(ang)), bevel=0.06)
        ca, sa = math.cos(rad(ang)), math.sin(rad(ang))
        for sx in (-1, 1):
            for sy in (-1, 1):
                px, py = x + ca * sx * 3.6 - sa * sy * 2.2, y + sa * sx * 3.6 + ca * sy * 2.2
                pbox(rt, f"Stall{i}_Post{sx}{sy}", (0.5, 0.5, 8), (px, py, 4), M["timber"], bevel=0.04)
        pbox(rt, f"Stall{i}_Awning", (9, 6.4, 0.3), (x, y, 8.2), M[cm], rot=(rad(-8), 0, rad(ang)), bevel=0.02)
        for k in range(3):
            pbox(rt, f"Stall{i}_Goods{k}", (1.6, 1.4, 1.0), (x + ca * (k - 1) * 2.4, y + sa * (k - 1) * 2.4, 3.5), (M["flower_y"], M["hay"], M["foliage"])[k], bevel=0.2, chip=0.1)
    # well (the existing one stays as the walkable base; this frames it)
    for k in range(10):
        a = k / 10 * math.tau
        pbox(rt, f"WellStone{k}", (3.2, 1.6, 1.0), (math.cos(a) * 5.4, math.sin(a) * 5.4, 0.5), M["stonebase"], rot=(0, 0, a + math.pi / 2), bevel=0.2, chip=0.15)
    return rt


def lamps():
    core.clear_coll("Lamps")
    COLL.pop("Lamps", None)
    parts = [k["part"] for k in LAY["Lamps"]["children"]]
    posts = [p for p in parts if p["n"] == "LampPost"]
    lanterns = [p for p in parts if p["n"] == "Lantern"]
    for i, p in enumerate(posts):
        X, Y, Z = p["p"][0], p["p"][1], p["p"][2]
        h = p["s"][1]
        # nearest lantern gives the arm direction
        ln = min(lanterns, key=lambda q: (q["p"][0] - X) ** 2 + (q["p"][2] - Z) ** 2)
        ax, az = ln["p"][0] - X, ln["p"][2] - Z
        L = max(math.hypot(ax, az), 0.1)
        rt = prefab("LampPost", i, X, Z, 0, Y=Y - h / 2, coll="Lamps")
        dx, dy = ax / L * 2.3, az / L * 2.3
        pbox(rt, "Base", (1.6, 1.6, 1.2), (0, 0, 0.6), M["stonebase"], bevel=0.12)
        pbox(rt, "Post", (0.8, 0.8, h + 1), (0, 0, (h + 1) / 2), M["timber"], bevel=0.06)
        pbox(rt, "Arm", (abs(dx) + 0.4 if abs(dx) > abs(dy) else 0.4, abs(dy) + 0.4 if abs(dy) >= abs(dx) else 0.4, 0.4), (dx / 2, dy / 2, h + 0.6), M["iron"])
        for k, (bx, by) in enumerate(((-0.6, -0.6), (0.6, -0.6), (-0.6, 0.6), (0.6, 0.6))):
            pbox(rt, f"Bar{k}", (0.15, 0.15, 1.6), (dx + bx, dy + by, h - 0.6), M["iron"], bevel=0)
        pbox(rt, "Cap", (1.5, 1.5, 0.3), (dx, dy, h + 0.3), M["iron"], bevel=0.03)
        pbox(rt, "Glow", (0.9, 0.9, 1.2), (dx, dy, h - 0.6), M["glow"], bevel=0.08)
        plight(rt, "Light", (dx, dy, h - 1.0), 3600, rng=22)


def barn():
    core.clear_coll("Farm")
    COLL.pop("Farm", None)
    parts = {k["part"]["n"]: k["part"] for k in LAY["Farm"]["children"] if k["part"]["n"] == "BarnBody"}
    b = parts["BarnBody"]
    X, Y, Z, yaw = b["p"]
    W, Hh, D = b["s"]
    rt = prefab("Barn", "Main", X, Z, yaw, Y=Y - Hh / 2, coll="Farm")
    pbox(rt, "Plinth", (W + 1, D + 1, 1.2), (0, 0, 0.6), M["stonebase"], bevel=0.2, chip=0.15)
    pbox(rt, "Body", (W, D, Hh), (0, 0, Hh / 2), M["planks_red"], bevel=0.1)
    for i in range(int(W // 4) + 1):
        for side in (-1, 1):
            pbox(rt, f"Batten_{side}_{i}", (0.5, 0.4, Hh), (-W / 2 + i * 4, side * (D / 2 + 0.1), Hh / 2), M["timber"], bevel=0.03)
    half, rise = D / 2 + 1.5, Hh * 0.55
    ang = math.atan2(rise, half)
    for s in (-1, 1):
        pbox(rt, f"Roof_{s}", (W + 2.4, math.hypot(half, rise), 0.9), (0, s * half / 2, Hh + rise / 2), M["roof_slate"], rot=(-s * ang, 0, 0), bevel=0.1)
    pbox(rt, "Ridge", (W + 3, 1.4, 1.2), (0, 0, Hh + rise + 0.4), M["timber"], bevel=0.12)
    for s in (-1, 1):
        for k in range(5):
            pbox(rt, f"Gable_{s}_{k}", (0.5, D - k * D / 5.3, rise / 5 + 0.1), (s * (W / 2), 0, Hh + 0.2 + k * rise / 5), M["planks_red"], bevel=0.04)
    pbox(rt, "DoorL", (5, 0.6, Hh * 0.8), (-2.6, D / 2 + 0.3, Hh * 0.4), M["planks"], bevel=0.05)
    pbox(rt, "DoorR", (5, 0.6, Hh * 0.8), (2.6, D / 2 + 1.6, Hh * 0.4), M["planks"], rot=(0, 0, rad(-40)), bevel=0.05)
    for s in (-1, 1):
        pbox(rt, f"DoorX{s}", (0.4, 0.3, Hh * 0.85), (-2.6, D / 2 + 0.7, Hh * 0.4), M["timber"], rot=(0, rad(s * 28), 0), bevel=0.02)
    pbox(rt, "LoftDoor", (4, 0.5, 4), (0, D / 2 + 0.2, Hh + 1.5), M["planks"], bevel=0.04)
    for k in range(6):
        pbox(rt, f"HayStack{k}", (3.4, 2.6, 2.6), (W / 2 + 3 + (k % 2) * 3.6, -D / 4 + (k // 2) * 3, 1.3 + (k // 4) * 2.6), M["hay"], rot=(0, 0, R(-0.2, 0.2)), bevel=0.4, chip=0.25)


def camp():
    core.clear_coll("Camp")
    COLL.pop("Camp", None)
    tents = [k["part"] for k in LAY["Camp"]["children"] if k["part"]["n"] == "Tent"]
    for i, t in enumerate(tents):
        X, Y, Z, yaw = t["p"]
        w, h, d = t["s"]
        rt = prefab("TentHalf", i, X, Z, yaw, Y=Y - h / 2, coll="Camp")
        ang = math.atan2(h, d)
        pbox(rt, "Sheet", (w, math.hypot(d, h), 0.25), (0, 0, h / 2), M["cloth_tent"], rot=(ang, 0, 0), bevel=0.02)
        pbox(rt, "RidgePole", (w + 0.8, 0.35, 0.35), (0, d / 2, h + 0.1), M["timber"], bevel=0)
        for s_ in (-1, 1):
            pbox(rt, f"Pole_{s_}", (0.35, 0.35, h + 0.4), (s_ * (w / 2 + 0.2), d / 2, (h + 0.4) / 2), M["timber"], bevel=0)
            pbox(rt, f"Peg_{s_}", (0.3, 0.3, 0.8), (s_ * (w / 2 - 0.5), -d / 2 - 0.4, 0.2), M["timber"], bevel=0)
        pbox(rt, "Bedroll", (2, 3.4, 0.5), (R(-2.5, 2.5), d / 2 - 1.6, 0.25), M["cloth"], bevel=0.1)
    fp = [k["part"] for k in LAY["Camp"]["children"] if k["part"]["n"] == "FirePit"][0]
    X, Y, Z, _ = fp["p"]
    rt = prefab("FirePit", "Main", X, Z, 0, Y=Y, coll="Camp")
    for k in range(9):
        a = k / 9 * math.tau
        pbox(rt, f"Ring{k}", (1.6, 1.0, 0.9), (math.cos(a) * 2.6, math.sin(a) * 2.6, 0.2), M["rock"], rot=(0, 0, a), bevel=0.12, chip=0.12)
    for k in range(4):
        pbox(rt, f"Log{k}", (0.6, 3.2, 0.6), (math.cos(k * 1.6) * 0.6, math.sin(k * 1.6) * 0.6, 0.6), M["bark"], rot=(rad(25), 0, k * 1.6), bevel=0.05)
    plight(rt, "Fire", (0, 0, 2.0), 6000, color="#ff8a3a", rng=26)
    # bandit banner + crates + weapon rack near the spawns (spawn pads themselves untouched)
    rt2 = prefab("CampProps", "Main", X + 8, Z + 6, 30, coll="Camp")
    pbox(rt2, "BannerPole", (0.5, 0.5, 12), (0, 0, 6), M["timber"], bevel=0.03)
    pbox(rt2, "Banner", (3.5, 0.2, 5), (1.9, 0, 9), M["cloth"], bevel=0.02)
    for k in range(4):
        pbox(rt2, f"Crate{k}", (2.6, 2.6, 2.6), (-3 + (k % 2) * 2.8, 3 + (k // 2) * 2.8, 1.3 + (k // 3) * 2.6), M["planks"], rot=(0, 0, R(-0.3, 0.3)), bevel=0.08)
    pbox(rt2, "Rack", (5, 0.6, 0.4), (4, -3, 3.6), M["timber"], bevel=0.03)
    for k in range(4):
        pbox(rt2, f"RackPole{k}", (0.25, 0.25, 4.4), (2.2 + k * 1.2, -3, 2.0), M["iron"], rot=(rad(12), 0, 0), bevel=0)


def reskinned():
    core.clear_coll("Reskin")
    COLL.pop("Reskin", None)
    st = {"Sleeper": M["timber"], "Rail": M["iron"], "BufferStop": M["iron"], "TrestlePier": M["stonebase"], "TrestleBeam": M["timber"],
          "StationHouse": M["stonebase"], "StationRoof": M["roof_slate"], "Canopy": M["planks"], "CanopyPost": M["timber"],
          "StationWindow": M["glass"], "StationTrim": M["timber"], "StationSign": M["planks"], "StationDoor": M["planks"], "PlatformEdge": M["stonebase"], "*": M["stonebase"]}
    reskin("Station", st, "Reskin")
    reskin("Bridge", {"ArchStone": M["stonebase"], "Parapet": M["stonebase"], "Ramp": M["cobble"], "Pier": M["stonebase"], "Deck": M["cobble"]}, "Reskin")
    reskin("Fences", {"FenceRail": M["timber"], "FencePost": M["timber"], "*": M["timber"]}, "Reskin")
    reskin("Farm", {"Wheat": M["wheatfield"], "Cabbages": M["foliage"], "HayBale": M["hay"]}, "Reskin",
           skip=("BarnBody", "BarnRoof", "BarnGable", "BarnDoor", "BarnLoft", "BarnDoorX1", "BarnDoorX2"))
    reskin("Square", {"BenchLeg": M["timber"], "BenchBack": M["planks"], "BenchSeat": M["planks"], "Notice": M["paper"], "NoticePost": M["timber"],
                      "NoticeBoard": M["planks"], "WellPost": M["timber"], "WellBeam": M["timber"], "WellRoof": M["roof"], "WellRing": M["stonebase"],
                      "WellBucket": M["planks"], "WellWater": M["water"]}, "Reskin", skip=("LindenmoorSpawn",))
    reskin("Gorge", {"Cliff": M["cliff"], "WestShelf": M["rock"], "EastShelf": M["rock"], "WestRamp": M["rock"], "GorgeLedge": M["rock"],
                     "BenchSeat": M["planks"], "BenchBack": M["planks"]}, "Reskin")
    reskin("Camp", {"LogSeat": M["bark"], "Crate": M["planks"]}, "Reskin", skip=("Tent", "FirePit", "Embers", "BanditSpawn_1", "BanditSpawn_2"))


def kept_reference():
    """Grey stand-ins for what stays exactly as it is in Studio (not exported)."""
    c = core.clear_coll("Kept_Reference")
    for name in ("Workshop", "StyleTrainers", "LindenmoorRun", "HubRoad"):
        for k in LAY[name]["children"]:
            if "box" in k:
                (bx, by, bz, yaw), (sx, sy, sz) = k["box"]
                o = box(f"KEEP_{name}_{k['n']}", (sx, sz, sy), (bx, bz, by), M["keep"], c, rot=(0, 0, rad(-yaw)), bevel=0)
                o["rs_skip"] = True
                o.hide_render = True
            elif "part" in k:
                p = k["part"]
                o = box(f"KEEP_{name}_{p['n']}", (p["s"][0], p["s"][2], p["s"][1]), (0, 0, 0), M["keep"], c, bevel=0)
                o.matrix_world = roblox_to_blender_matrix(p)
                o["rs_skip"] = True
                o.hide_render = True


# ------------------------------------------------------------------ materials, lighting, cameras
def mats():
    global M
    M = core.materials()
    M["terrace"] = core.pbr("LM_Terrace", "mossy_rock", tile=10, bump=0.7, moss="leafy_grass", moss_amount=0.95)
    M["vine"] = core.flat("LM_Vine", srgb("#1f3a1c"), rough=0.8)
    M["roof_slate"] = core.pbr("LM_RoofSlate", "clay_roof_tiles_02", tile=6, tint=srgb("#6f7c86"), bump=0.9, moss="leafy_grass", moss_amount=0.15)
    M["plaster_cream"] = M["plaster"]
    M["plaster_ochre"] = core.pbr("LM_PlasterOchre", "plastered_wall_04", tile=9, tint=srgb("#e8c98f"), bump=0.35)
    M["plaster_white"] = core.pbr("LM_PlasterWhite", "plastered_wall_04", tile=9, tint=srgb("#f6f1e6"), bump=0.35)
    M["planks_green"] = core.pbr("LM_PlanksGreen", "brown_planks_05", tile=5, tint=srgb("#7f9a72"), bump=0.5)
    M["planks_red"] = core.pbr("LM_PlanksRed", "brown_planks_05", tile=5, tint=srgb("#b8695a"), bump=0.5)
    M["planks_brown"] = M["planks"]
    M["cloth_w"] = core.flat("LM_ClothLinen", srgb("#d9d2bf"), rough=0.95)
    M["cloth_b"] = core.flat("LM_ClothBlue", srgb("#3c5a78"), rough=0.95)
    M["cloth_tent"] = core.flat("LM_ClothTent", srgb("#6e6248"), rough=0.95)
    M["paper"] = core.flat("LM_Paper", srgb("#e6dcc2"), rough=0.9)
    M["ember"] = core.flat("LM_Embers", srgb("#ff6a1a"), rough=0.6, emit=(srgb("#ff6a1a"), 25))
    M["wheatfield"] = core.pbr("LM_WheatField", "thatch_roof_angled", tile=6, tint=srgb("#f0cf73"), bump=0.6)
    M["keep"] = core.flat("LM_KeptAsIs", srgb("#8a8f94"), rough=0.8)
    M["fog"] = fog_mat()
    return M


def fog_mat():
    m = bpy.data.materials.get("LM_Fog") or bpy.data.materials.new("LM_Fog")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    v = nt.nodes.new("ShaderNodeVolumePrincipled")
    v.inputs["Density"].default_value = 0.0045
    v.inputs["Color"].default_value = (*srgb("#86a9a6"), 1)
    v.inputs["Anisotropy"].default_value = 0.5
    nt.links.new(v.outputs["Volume"], out.inputs["Volume"])
    return m


def lighting():
    s = core.scene()
    c = core.clear_coll("Lighting")
    w = bpy.data.worlds.get("LM_World") or bpy.data.worlds.new("LM_World")
    s.world = w
    w.use_nodes = True
    nt = w.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg = nt.nodes.new("ShaderNodeBackground")
    env = nt.nodes.new("ShaderNodeTexEnvironment")
    env.image = bpy.data.images.load(os.path.join(core.TEX, "kloofendal_misty_morning_puresky.hdr"), check_existing=True)
    tint = nt.nodes.new("ShaderNodeMix")
    tint.data_type = "RGBA"
    tint.blend_type = "MULTIPLY"
    tint.inputs["Factor"].default_value = 0.85
    tint.inputs[7].default_value = (*srgb("#4f7f86"), 1)
    nt.links.new(env.outputs["Color"], tint.inputs[6])
    nt.links.new(tint.outputs[2], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 0.7
    nt.links.new(bg.outputs["Background"], out.inputs["Surface"])
    fog = box("FogVolume", (900, 900, 160), (0, 0, 70), M["fog"], c, bevel=0)
    fog.display_type = "WIRE"
    fog.hide_select = True
    fog["rs_skip"] = True
    sun = bpy.data.lights.new("Sun_Low", "SUN")
    sun.energy = 2.4
    sun.color = srgb("#ffd2a0")
    sun.angle = rad(1.5)
    so = bpy.data.objects.new("Sun_Low", sun)
    so.rotation_euler = Euler((rad(68), 0, rad(150)))
    c.objects.link(so)
    r = s.render
    r.engine = "BLENDER_EEVEE"
    r.resolution_x, r.resolution_y = 1920, 1080
    s.view_settings.view_transform = "AgX"
    try:
        s.view_settings.look = "AgX - Medium High Contrast"
    except Exception:
        pass
    e = s.eevee
    for attr, val in (("taa_render_samples", 48), ("volumetric_tile_size", "4"), ("volumetric_end", 900), ("volumetric_samples", 96),
                      ("use_shadows", True), ("use_volumetric_shadows", True), ("use_raytracing", True)):
        try:
            setattr(e, attr, val)
        except Exception:
            pass


CAMS = {
    "square": ((0, -70, 12), (86, 0, 0), 22),
    "lane": ((-200, -10, 10), (86, 0, -84), 20),
    "bridge": ((10, 60, 10), (85, 0, 8), 22),
    "gorge": ((200, 70, 16), (82, 0, 35), 20),
    "hollow": ((197, -209, 7), (86, 0, -132), 20),
    "aerial": ((-250, -330, 190), (58, 0, -38), 24),
    "station": ((-220, -40, 10), (86, 0, 50), 22),
}


def camera(name):
    s = core.scene()
    c = core.coll("Lighting")
    loc, rot, lens = CAMS[name]
    cam = bpy.data.objects.get(f"Cam_{name}")
    if not cam:
        cd = bpy.data.cameras.new(f"Cam_{name}")
        cam = bpy.data.objects.new(f"Cam_{name}", cd)
        c.objects.link(cam)
    cam.data.lens = lens
    cam.data.clip_end = 2000
    X, Z, Y = loc
    cam.location = (X, Z, ground(X, Z) + Y if name != "aerial" else Y)
    cam.rotation_euler = Euler((rad(rot[0]), rad(rot[1]), rad(rot[2])))
    s.camera = cam
    return cam


STAGES = ["terrain", "houses", "trees", "forests", "ridge", "creek", "edging", "square", "lamps", "barn", "camp", "reskin", "kept", "lighting"]


def run(stage="all"):
    core.SCENE = core.ROOT = "Lindenmoor_Full"
    if stage in ("all", "reset") or core.SCENE not in bpy.data.scenes:
        core.reset_scene()
    bpy.context.window.scene = core.scene()
    load()
    mats()
    COLL.clear()
    todo = STAGES if stage in ("all", "reset") else stage.split(",")
    fns = {"terrain": terrain_mesh, "houses": houses, "trees": trees, "forests": forests, "ridge": ridge, "creek": creek_banks,
           "edging": edging, "square": square, "lamps": lamps, "barn": barn, "camp": camp, "reskin": reskinned, "kept": kept_reference, "lighting": lighting}
    done = {}
    for st in todo:
        r = fns[st]()
        done[st] = r if isinstance(r, int) else True
    return {"objects": len(core.scene().objects), "done": done}


def render(cam, path, samples=48):
    core.SCENE = core.ROOT = "Lindenmoor_Full"
    s = core.scene()
    camera(cam)
    s.eevee.taa_render_samples = samples
    s.render.filepath = path
    bpy.ops.render.render(write_still=True, scene=s.name)
    return path

"""Lindenmoor v2: a Deepwoken-style corner of the starter valley (owner refs: blocky, angular, textured, fogged).
Run each stage through Blender: build.run("all") or build.run("terrain") etc. 1 unit = 1 stud.
Look rules (from the refs): square trunks, angled box branches, stacked flat canopy slabs, hanging box vines,
stacked mossy terrace slabs, angular rock wedges; detail comes from PBR texture + many layered blocks + fog + one warm light."""
import bpy, math, random
from mathutils import Vector, Euler
import importlib
from . import core
importlib.reload(core)
from .core import box, cyl, link, coll, clear_coll, srgb

RNG = random.Random(11)
M = {}


def R(a, b):
    return RNG.uniform(a, b)


def rad(d):
    return math.radians(d)


# ------------------------------------------------------------------ ground: stacked mossy terraces + path
def terrain():
    c = clear_coll("Terrain")
    box("Ground_Base", (360, 360, 2), (0, 0, -1), M["grass_ground"], c, bevel=0)
    # the path: a worn dirt band from the camera to the house door, sunk 0.2
    pts = [(0, -95), (2, -70), (-1, -45), (3, -22), (6, -6)]
    for i in range(len(pts) - 1):
        a, b = Vector((*pts[i], 0)), Vector((*pts[i + 1], 0))
        mid = (a + b) / 2
        d = b - a
        box(f"Path_{i}", (11 + R(-1, 1), d.length + 3, 0.4), (mid.x, mid.y, 0.05), M["path"], c,
            rot=(0, 0, math.atan2(-d.x, d.y)), bevel=0.15, chip=0.3)
    # stacked terrace slabs, left and right of the path (ref 1's layered mossy steps)
    def terrace(name, x0, y0, w, d, steps, rise, yaw, recede=(0, 7)):
        for i in range(steps):
            box(f"{name}_{i}", (w - i * R(3, 6), d - i * R(2, 4), rise), (x0 + recede[0] * i + R(-1, 1), y0 + recede[1] * i, rise / 2 + i * rise),
                M["rock"] if i == 0 and RNG.random() < 0.3 else M["terrace"], c, rot=(0, 0, rad(yaw + R(-4, 4))), bevel=0.25, chip=0.35)
    terrace("TerraceL", -46, -40, 48, 26, 5, 2.6, 6, recede=(-3, 8))
    terrace("TerraceR", 46, -48, 44, 24, 4, 2.2, -8, recede=(4, 7))
    terrace("TerraceBackL", -40, 30, 60, 30, 6, 3.4, 3, recede=(-2, 9))
    terrace("TerraceBackR", 52, 34, 56, 34, 6, 3.8, -5, recede=(3, 8))
    # wheat fields on two terrace tops (lighter strips, like the lit floor plates in ref 1)
    for i, (x, y, z, w, d) in enumerate(((-52, -32, 13.2, 30, 10), (-44, 58, 20.6, 40, 12))):
        box(f"WheatBed_{i}", (w, d, 0.6), (x, y, z), M["hay"], c, rot=(0, 0, rad(6)), bevel=0.2, chip=0.2)


# ------------------------------------------------------------------ farmhouse: the warm-lit centre piece
def house():
    c = clear_coll("Farmhouse")
    hx, hy, yaw = 8, 8, rad(-12)
    g = bpy.data.objects.new("Farmhouse_Root", None)
    g.location = (hx, hy, 0)
    g.rotation_euler = (0, 0, yaw)
    c.objects.link(g)

    def P(o):
        o.parent = g
        return o

    W, D = 24, 17
    # plinth + stone ground floor with chunky quoins
    P(box("Plinth", (W + 1.6, D + 1.6, 1.2), (0, 0, 0.6), M["stonebase"], c, bevel=0.2, chip=0.15))
    P(box("StoneFloor", (W, D, 9), (0, 0, 5.7), M["stonebase"], c, bevel=0.15))
    for sx in (-1, 1):
        for sy in (-1, 1):
            for k in range(5):
                long = k % 2 == 0
                P(box(f"Quoin_{sx}_{sy}_{k}", (2.6 if long else 1.8, 1.8 if long else 2.6, 1.7),
                      (sx * (W / 2 - (0.9 if long else 0.5)), sy * (D / 2 - (0.5 if long else 0.9)), 2 + k * 1.75),
                      M["stonebase"], c, bevel=0.2, chip=0.12))
    # timber + plaster upper floor
    P(box("SillBeam", (W + 1.2, D + 1.2, 1.0), (0, 0, 10.7), M["timber"], c, bevel=0.1))
    P(box("UpperPlaster", (W - 0.4, D - 0.4, 7.4), (0, 0, 14.9), M["plaster"], c, bevel=0.1))
    P(box("HeadBeam", (W + 0.8, D + 0.8, 0.9), (0, 0, 18.9), M["timber"], c, bevel=0.1))
    for side, yy in (("S", -D / 2), ("N", D / 2)):
        for i in range(6):
            x = -W / 2 + i * W / 5
            P(box(f"Post_{side}_{i}", (0.9, 0.9, 7.6), (x, yy, 14.9), M["timber"], c, bevel=0.08))
        for i in range(5):
            x0 = -W / 2 + i * W / 5 + W / 10
            P(box(f"Brace_{side}_{i}", (0.6, 0.7, 7.2), (x0, yy, 14.9), M["timber"], c, rot=(0, rad(32 if i % 2 else -32), 0), bevel=0.06))
    for side, xx in (("W", -W / 2), ("E", W / 2)):
        for i in range(4):
            y = -D / 2 + i * D / 3
            P(box(f"Post_{side}_{i}", (0.9, 0.9, 7.6), (xx, y, 14.9), M["timber"], c, bevel=0.08))
    # roof: tile slabs with stepped tile rows on top, rafters under the eaves, ridge, gables
    half, rise, over = D / 2 + 2.2, 8.0, 1.8
    ang = math.atan2(rise, half)
    slope = math.hypot(half, rise)
    for s in (-1, 1):
        P(box(f"Roof_{s}", (W + over * 2, slope, 1.0), (0, s * half / 2, 19.4 + rise / 2), M["roof"], c, rot=(-s * ang, 0, 0), bevel=0.1))
        for r in range(7):
            t = (r + 0.5) / 7
            yy = s * half * t
            zz = 19.4 + rise * (1 - t) + 0.75
            P(box(f"TileRow_{s}_{r}", (W + over * 2 - 0.2, slope / 7 + 0.15, 0.45), (0, yy, zz), M["roof"], c,
                  rot=(-s * ang, 0, 0), bevel=0.12, chip=0.08))
        for i in range(9):
            x = -W / 2 + i * W / 8
            P(box(f"Rafter_{s}_{i}", (0.6, 2.6, 0.7), (x, s * (D / 2 + 1.3), 19.0), M["timber"], c, rot=(-s * ang, 0, 0), bevel=0.05))
    P(box("Ridge", (W + over * 2 + 0.6, 1.6, 1.4), (0, 0, 19.4 + rise + 0.6), M["timber"], c, bevel=0.15))
    for s in (-1, 1):
        for k in range(5):
            h = rise * (1 - k / 5)
            P(box(f"Gable_{s}_{k}", (0.6, (D - k * D / 5.3), 1.6), (s * (W / 2 - 0.3), 0, 19.6 + k * 1.6), M["plaster"], c, bevel=0.05))
        P(box(f"BargeBoard_{s}_L", (0.5, slope + 0.6, 0.8), (s * (W / 2 + over), -half / 2, 19.6 + rise / 2), M["timber"], c, rot=(ang, 0, 0)))
        P(box(f"BargeBoard_{s}_R", (0.5, slope + 0.6, 0.8), (s * (W / 2 + over), half / 2, 19.6 + rise / 2), M["timber"], c, rot=(-ang, 0, 0)))
    # chimney
    P(box("Chimney", (3.4, 3.4, 14), (W / 2 - 4, D / 4, 22), M["stonebase"], c, bevel=0.15, chip=0.1))
    P(box("ChimneyCap", (4.4, 4.4, 0.8), (W / 2 - 4, D / 4, 29.4), M["stonebase"], c, bevel=0.15))
    # door (6 x 9) with frame, lintel, step, iron hinges
    dx, dy = -5, -D / 2
    P(box("DoorFrameL", (1.0, 1.4, 9.6), (dx - 3.5, dy - 0.2, 5.4), M["timber"], c))
    P(box("DoorFrameR", (1.0, 1.4, 9.6), (dx + 3.5, dy - 0.2, 5.4), M["timber"], c))
    P(box("DoorLintel", (8.6, 1.6, 1.4), (dx, dy - 0.25, 10.4), M["stonebase"], c, bevel=0.15))
    P(box("Door", (6, 0.6, 9), (dx, dy - 0.15, 5.7), M["planks"], c, bevel=0.05))
    for z in (2.8, 8.4):
        P(box(f"Hinge_{z}", (4.2, 0.2, 0.35), (dx - 0.6, dy - 0.5, z), M["iron"], c, bevel=0.02))
    P(box("DoorStep", (8, 3, 1.2), (dx, dy - 2.0, 0.6), M["stonebase"], c, bevel=0.2, chip=0.15))
    # windows: frame, sill, glass, shutters (one open), flower box upstairs
    def window(name, x, y, z, w=3.6, h=4.2, shutters=True, flowers=False, face=-1):
        P(box(f"{name}_Glass", (w, 0.3, h), (x, y + face * 0.05, z), M["glass"], c, bevel=0))
        P(box(f"{name}_Frame", (w + 0.9, 0.7, 0.6), (x, y + face * 0.3, z + h / 2), M["timber"], c, bevel=0.05))
        P(box(f"{name}_Sill", (w + 1.6, 1.4, 0.6), (x, y + face * 0.6, z - h / 2 - 0.2), M["stonebase"], c, bevel=0.08))
        P(box(f"{name}_Mullion", (0.35, 0.5, h), (x, y + face * 0.25, z), M["timber"], c, bevel=0))
        if shutters:
            P(box(f"{name}_ShutterL", (w / 2, 0.4, h + 0.4), (x - w * 0.85, y + face * 0.4, z), M["planks"], c, bevel=0.04))
            P(box(f"{name}_ShutterR", (w / 2, 0.4, h + 0.4), (x + w * 0.95, y + face * 1.1, z), M["planks"], c, rot=(0, 0, rad(-35)), bevel=0.04))
        if flowers:
            P(box(f"{name}_FlowerBox", (w + 1, 1.2, 1.0), (x, y + face * 1.1, z - h / 2 - 0.9), M["planks"], c, bevel=0.05))
            for k in range(7):
                col = (M["flower_y"], M["flower_w"], M["flower_p"], M["foliage"])[k % 4]
                P(box(f"{name}_Bloom_{k}", (0.6, 0.6, 0.6), (x - w / 2 + 0.4 + k * w / 6.5, y + face * 1.1, z - h / 2 - 0.1), col, c, bevel=0.15))
    window("WinG1", 3.5, -D / 2, 5.6)
    window("WinG2", 8.5, -D / 2, 5.6)
    window("WinU1", -7, -D / 2, 14.8, flowers=True, shutters=False)
    window("WinU2", 2, -D / 2, 14.8, flowers=True, shutters=False)
    window("WinU3", 8.5, -D / 2, 14.8, shutters=False)
    # gutter + downpipe + rain barrel, firewood stack, bench
    P(box("Gutter", (W + 3, 0.7, 0.6), (0, -(D / 2 + 3.9), 18.0), M["iron"], c, bevel=0.03))
    P(box("DownPipe", (0.5, 0.5, 17), (W / 2 + 1.2, -(D / 2 + 3.6), 9.5), M["iron"], c, bevel=0.02))
    P(cyl("RainBarrel", 1.6, 3.4, (W / 2 + 1.2, -(D / 2 + 2.6), 1.7), M["planks"], c, verts=14))
    for k in range(3):
        P(cyl(f"RainBarrel_Hoop{k}", 1.66, 0.25, (W / 2 + 1.2, -(D / 2 + 2.6), 0.6 + k * 1.2), M["iron"], c, verts=14, bevel=0))
    for r in range(4):
        for k in range(6 - r):
            P(cyl(f"Log_{r}_{k}", 0.55, 4.5, (-W / 2 + 1.5 + k * 1.15 + r * 0.55, -(D / 2 + 1.4), 0.55 + r * 1.0), M["bark"], c,
                  verts=8, rot=(rad(90), 0, 0), bevel=0.05))
    P(box("Bench_Seat", (5, 1.6, 0.4), (4.5, -(D / 2 + 1.8), 2.0), M["planks"], c, bevel=0.04))
    for sx in (-2, 2):
        P(box(f"Bench_Leg_{sx}", (0.4, 1.4, 2), (4.5 + sx, -(D / 2 + 1.8), 1.0), M["timber"], c, bevel=0.03))
    # lantern by the door (the scene's key warm light, like the lit hut in ref 1)
    P(box("DoorLantern_Arm", (0.3, 2.0, 0.3), (dx - 5, dy - 1.0, 9.0), M["iron"], c))
    P(box("DoorLantern", (1.0, 1.0, 1.4), (dx - 5, dy - 2.0, 8.2), M["glow"], c, bevel=0.1))
    L = bpy.data.lights.new("DoorLantern_Light", "POINT")
    L.energy = 7000
    L.color = srgb("#ffae55")
    L.shadow_soft_size = 0.5
    lo = bpy.data.objects.new("DoorLantern_Light", L)
    lo.location = (dx - 5, dy - 3.2, 8.0)
    c.objects.link(lo)
    lo.parent = g
    # warm interior glow through the ground-floor windows
    L2 = bpy.data.lights.new("Interior_Glow", "AREA")
    L2.energy = 1500
    L2.color = srgb("#ff9a3d")
    L2.size = 8
    lo2 = bpy.data.objects.new("Interior_Glow", L2)
    lo2.location = (6, -D / 2 + 2, 6)
    lo2.rotation_euler = (rad(-90), 0, 0)
    c.objects.link(lo2)
    lo2.parent = g


# ------------------------------------------------------------------ trees: square trunks, angled box branches, slab canopies, box vines
def tree(name, at, c, height=46, trunk=6.0, canopy=(48, 38), layers=4, branches=5, vines=10, lean=0):
    x, y = at
    # root flare: chunky slabs at the base
    for k in range(4):
        a = k * math.pi / 2 + R(-0.3, 0.3)
        box(f"{name}_Root{k}", (trunk * 0.9, trunk * 0.55, 2.4), (x + math.cos(a) * trunk * 0.55, y + math.sin(a) * trunk * 0.55, 1.0), M["bark"], c,
            rot=(R(-0.15, 0.15), R(-0.25, 0.25), a), bevel=0.2, chip=0.3)
    box(f"{name}_Trunk", (trunk, trunk, height), (x, y, height / 2), M["bark"], c, rot=(lean, 0, R(0, 0.6)), bevel=0.3, chip=0.25)
    # angled branches reaching out to the canopy
    for k in range(branches):
        a = k / branches * math.tau + R(-0.3, 0.3)
        L = R(14, 22)
        z = height * R(0.62, 0.86)
        tilt = rad(R(55, 70))
        cx, cy = x + math.cos(a) * L * 0.45, y + math.sin(a) * L * 0.45
        box(f"{name}_Branch{k}", (trunk * 0.38, trunk * 0.38, L), (cx, cy, z + L * 0.25), M["bark"], c,
            rot=(0, tilt, a), bevel=0.15, chip=0.15)
    # stacked flat canopy slabs (big, overlapping, slightly rotated)
    for k in range(layers):
        w = canopy[0] * (1 - k * 0.14) * R(0.9, 1.1)
        d = canopy[1] * (1 - k * 0.12) * R(0.9, 1.1)
        box(f"{name}_Canopy{k}", (w, d, R(4.5, 6.5)), (x + R(-5, 5), y + R(-5, 5), height + k * 4.2 - 2), M["foliage"], c,
            rot=(R(-0.05, 0.05), R(-0.05, 0.05), R(0, math.pi)), bevel=0.4, chip=0.8)
        # small blocks breaking up the slab edges
        for j in range(6):
            a = R(0, math.tau)
            r = R(0.35, 0.5) * w
            box(f"{name}_CanopyBit{k}_{j}", (R(6, 12), R(5, 10), R(3, 5)), (x + math.cos(a) * r, y + math.sin(a) * r, height + k * 4.2 - R(3, 5)),
                M["foliage"], c, rot=(0, 0, R(0, math.pi)), bevel=0.3, chip=0.5)
    # hanging box vines
    for k in range(vines):
        a = R(0, math.tau)
        r = R(6, canopy[0] * 0.42)
        L = R(6, 20)
        box(f"{name}_Vine{k}", (R(0.4, 0.8), R(0.4, 0.8), L), (x + math.cos(a) * r, y + math.sin(a) * r, height - 3 - L / 2), M["vine"], c, bevel=0.05)


def trees():
    c = clear_coll("Trees")
    # big framing trunks in the foreground (dark silhouettes, ref 1)
    tree("Oak_FG_L", (-28, -62), c, height=44, trunk=9, canopy=(70, 56), layers=4, branches=6, vines=26)
    tree("Oak_FG_R", (34, -74), c, height=46, trunk=10, canopy=(66, 52), layers=4, branches=5, vines=24)
    # mid-ground oak behind the house
    tree("Oak_Mid", (-22, 46), c, height=44, trunk=6.5, canopy=(46, 36), layers=4, branches=5, vines=8)
    # background silhouettes fading into fog
    for i, (x, y) in enumerate(((-90, 120), (-40, 150), (20, 140), (80, 125), (130, 90), (-140, 70), (110, 170), (-100, 190))):
        tree(f"Oak_BG{i}", (x, y), c, height=R(48, 64), trunk=R(6, 8), canopy=(R(46, 60), R(36, 46)), layers=3, branches=4, vines=4)
    # cypress on the right ridge: stacked tapering blocks
    for i, (x, y) in enumerate(((84, 40), (96, 58), (74, 72))):
        box(f"Cypress{i}_Trunk", (1.8, 1.8, 10), (x, y, 5), M["bark"], c, bevel=0.1)
        for k in range(7):
            s = 9 * (1 - k * 0.12)
            box(f"Cypress{i}_Tier{k}", (s, s * 0.9, 6), (x, y, 9 + k * 5.2), M["cypress"], c, rot=(0, 0, R(0, 1)), bevel=0.3, chip=0.4)


# ------------------------------------------------------------------ rocks: angular wedges and slabs (refs 1 + 2)
def rocks():
    c = clear_coll("Rocks")
    # outcrop with the authored ledge-walk strip (7 up, 1.2 deep)
    ox, oy = 40, -6
    z = 0
    for k in range(5):
        w, d, h = R(18, 24) - k * 2, R(12, 15) - k, R(3.2, 4.2)
        box(f"Outcrop_{k}", (w, d, h), (ox + R(-1.5, 1.5), oy + R(-1, 1), z + h / 2), M["cliff"], c,
            rot=(R(-0.04, 0.04), R(-0.04, 0.04), R(-0.25, 0.25)), bevel=0.2, chip=0.45)
        z += h * 0.95
    led = box("LEDGE_RenseiLedge_Outcrop", (14, 1.4, 0.9), (ox - 1, oy - 7.2, 7.2), M["rock"], c, bevel=0.1, chip=0.1)
    led["RenseiLedge"] = True
    # angular wedge rocks scattered along the path and terraces (tilted slabs read as wedges)
    spots = [(-12, -60), (13, -52), (-16, -30), (17, -24), (-24, -8), (26, -36), (-6, 22), (30, 16), (-58, -10), (60, -20), (-30, 70), (50, 70)]
    for i, (x, y) in enumerate(spots):
        for k in range(RNG.randint(1, 3)):
            s = R(2, 5.5)
            box(f"Wedge_{i}_{k}", (s * R(1, 1.8), s * R(0.8, 1.3), s * R(0.5, 1.0)), (x + R(-2.5, 2.5), y + R(-2.5, 2.5), s * 0.25),
                M["rock"], c, rot=(R(-0.35, 0.35), R(-0.35, 0.35), R(0, math.pi)), bevel=0.12, chip=s * 0.12)
    # field wall: two courses of chunky stones, 4 studs tall (vault height)
    def wall(name, x0, y0, length, yaw):
        ca, sa = math.cos(yaw), math.sin(yaw)
        for course, (h, z0) in enumerate(((2.2, 1.1), (1.9, 3.1))):
            t = -length / 2 + R(0, 1)
            while t < length / 2:
                w = R(2.2, 4.4)
                cx, cy = x0 + ca * (t + w / 2), y0 + sa * (t + w / 2)
                box(f"{name}_{course}_{t:.0f}", (w, 1.9, h), (cx, cy, z0), M["fieldwall"], c,
                    rot=(R(-0.04, 0.04), R(-0.04, 0.04), yaw + R(-0.06, 0.06)), bevel=0.3, chip=0.25)
                t += w + 0.15
    wall("FieldWall_A", -26, -18, 26, rad(8))
    wall("FieldWall_B", 30, -32, 22, rad(-14))


# ------------------------------------------------------------------ props: well, cart, barrels, crates, fences, lantern posts, hay, clutter
def props():
    c = clear_coll("Props")
    # well
    wx, wy = -18, -36
    for k in range(10):
        a = k / 10 * math.tau
        box(f"Well_Stone{k}", (2.6, 1.6, 3.2), (wx + math.cos(a) * 3.2, wy + math.sin(a) * 3.2, 1.6), M["stonebase"], c,
            rot=(0, 0, a + math.pi / 2), bevel=0.2, chip=0.15)
    box("Well_Water", (5, 5, 0.2), (wx, wy, 2.4), M["water"], c, bevel=0)
    for sx in (-1, 1):
        box(f"Well_Post{sx}", (0.8, 0.8, 8), (wx + sx * 3.4, wy, 4.5), M["timber"], c, bevel=0.06)
    box("Well_Beam", (8.2, 0.8, 0.8), (wx, wy, 8.2), M["timber"], c)
    for s in (-1, 1):
        box(f"Well_Roof{s}", (9, 3.6, 0.5), (wx, wy + s * 1.5, 9.2), M["roof"], c, rot=(-s * rad(35), 0, 0), bevel=0.05)
    cyl("Well_Bucket", 0.7, 1.2, (wx + 1.5, wy - 2.6, 3.8), M["planks"], c, verts=10)
    box("Well_Rope", (0.15, 0.15, 4), (wx, wy, 6.2), M["rope"], c, bevel=0)
    # cart by the path
    cx, cy = 18, -40
    box("Cart_Bed", (9, 5, 0.6), (cx, cy, 3.0), M["planks"], c, rot=(0, 0, rad(25)), bevel=0.05)
    for s in (-1, 1):
        box(f"Cart_Side{s}", (9, 0.4, 1.6), (cx - s * math.sin(rad(25)) * 2.4, cy + s * math.cos(rad(25)) * 2.4, 4.0), M["planks"], c, rot=(0, 0, rad(25)), bevel=0.04)
        cyl(f"Cart_Wheel{s}", 2.2, 0.5, (cx - s * math.sin(rad(25)) * 2.9 + 1, cy + s * math.cos(rad(25)) * 2.9 + 0.4, 2.2), M["timber"], c, verts=12,
            rot=(rad(90), 0, rad(25)))
    box("Cart_Shaft", (7, 0.4, 0.4), (cx - 6.5, cy - 3.1, 1.6), M["timber"], c, rot=(0, rad(10), rad(25)))
    for k in range(3):
        box(f"Cart_Hay{k}", (3, 2.4, 2.2), (cx + R(-2, 2), cy + R(-1, 1), 4.6 + k * 0.4), M["hay"], c, rot=(0, 0, R(0, 1)), bevel=0.4, chip=0.3)
    # barrels + crates near the house corner
    for k in range(4):
        x, y = 26 + (k % 2) * 3.4, -12 + (k // 2) * 3.4
        cyl(f"Barrel{k}", 1.5, 3.6, (x, y, 1.8), M["planks"], c, verts=14)
        for h in range(3):
            cyl(f"Barrel{k}_Hoop{h}", 1.56, 0.25, (x, y, 0.5 + h * 1.3), M["iron"], c, verts=14, bevel=0)
    for k in range(3):
        box(f"Crate{k}", (3, 3, 3), (30 + k * 0.6, -4 + (k % 2) * 3.2, 1.5 + (k // 2) * 3.0), M["planks"], c, rot=(0, 0, R(-0.2, 0.2)), bevel=0.08)
    # fence along the path (post + two rails, slightly crooked)
    for side in (-1, 1):
        for i in range(9):
            y = -92 + i * 9
            x = side * (8.5 + R(-0.4, 0.4))
            box(f"Fence_{side}_{i}_Post", (0.8, 0.8, 5), (x, y, 2.5), M["timber"], c, rot=(R(-0.05, 0.05), R(-0.05, 0.05), 0), bevel=0.06)
            if i < 8:
                for z in (2.0, 3.8):
                    box(f"Fence_{side}_{i}_Rail{z}", (0.4, 9.2, 0.5), (x, y + 4.5, z + R(-0.15, 0.15)), M["timber"], c,
                        rot=(R(-0.03, 0.03), 0, R(-0.04, 0.04)), bevel=0.04)
    # lantern posts along the path: warm pools in the fog
    for i, (x, y) in enumerate(((-9.5, -72), (9.5, -40), (-9.5, -12))):
        box(f"LampPost{i}", (0.8, 0.8, 11), (x, y, 5.5), M["timber"], c, bevel=0.06)
        box(f"LampPost{i}_Arm", (2.6, 0.4, 0.4), (x + (1.2 if x < 0 else -1.2), y, 10.6), M["iron"], c)
        lx = x + (2.3 if x < 0 else -2.3)
        for k, (dx, dy) in enumerate(((-0.6, -0.6), (0.6, -0.6), (-0.6, 0.6), (0.6, 0.6))):
            box(f"LampPost{i}_Bar{k}", (0.15, 0.15, 1.6), (lx + dx, y + dy, 9.6), M["iron"], c, bevel=0)
        box(f"LampPost{i}_Cap", (1.5, 1.5, 0.3), (lx, y, 10.5), M["iron"], c, bevel=0.03)
        box(f"LampPost{i}_Base", (1.4, 1.4, 0.25), (lx, y, 8.7), M["iron"], c, bevel=0.03)
        box(f"LampPost{i}_Glow", (0.9, 0.9, 1.2), (x + (2.3 if x < 0 else -2.3), y, 9.6), M["glow"], c, bevel=0.08)
        L = bpy.data.lights.new(f"LampPost{i}_Light", "POINT")
        L.energy = 5200
        L.color = srgb("#ffb15e")
        L.shadow_soft_size = 0.4
        lo = bpy.data.objects.new(f"LampPost{i}_Light", L)
        lo.location = (x + (2.3 if x < 0 else -2.3), y, 9.0)
        c.objects.link(lo)
    # hay bales (stealth cover) and small clutter: sticks, stones, planks
    for i, (x, y) in enumerate(((-14, -48), (-11, -50), (14, -14), (-30, -26), (34, -56))):
        box(f"HayBale{i}", (4, 3, 3), (x, y, 1.5), M["hay"], c, rot=(0, 0, R(0, 1.5)), bevel=0.5, chip=0.25)
    for i in range(40):
        x, y = R(-60, 60), R(-90, 30)
        if abs(x) < 6:
            continue
        kind = RNG.random()
        if kind < 0.45:
            box(f"Stick{i}", (R(0.2, 0.35), R(0.2, 0.35), R(1.2, 2.6)), (x, y, 0.7), M["timber"], c, rot=(R(-0.3, 0.3), R(-0.3, 0.3), R(0, 3)), bevel=0)
        elif kind < 0.8:
            s = R(0.6, 1.4)
            box(f"Pebble{i}", (s, s * 0.8, s * 0.6), (x, y, s * 0.2), M["rock"], c, rot=(R(-0.3, 0.3), R(-0.3, 0.3), R(0, 3)), bevel=0.08, chip=0.1)
        else:
            box(f"PlankScrap{i}", (R(2, 4), 0.8, 0.25), (x, y, 0.2), M["planks"], c, rot=(0, R(-0.1, 0.1), R(0, 3)), bevel=0.02)
    # grass clumps: chunky blocky tufts, clustered (no hair particles: matches the refs' block language)
    def clear_of_path(x, y):
        return not (abs(x - 2) < 7.5 or (-8 < x < 26 and -8 < y < 24))
    n = 0
    for k in range(120):
        cx, cy = R(-85, 85), R(-100, 45)
        for j in range(RNG.randint(3, 9)):
            x, y = cx + R(-4, 4), cy + R(-4, 4)
            if not clear_of_path(x, y):
                continue
            s = R(1.0, 2.6)
            box(f"Tuft{n}", (s * R(0.6, 1.2), s * R(0.6, 1.2), s * R(0.5, 1.2)), (x, y, s * 0.3), M["foliage"], c,
                rot=(R(-0.2, 0.2), R(-0.2, 0.2), R(0, 3)), bevel=0.2, chip=0.2)
            n += 1
    # moss patches: thin irregular slabs on the ground
    for i in range(60):
        x, y = R(-90, 90), R(-100, 40)
        if not clear_of_path(x, y):
            continue
        box(f"MossPatch{i}", (R(4, 12), R(3, 9), 0.25), (x, y, 0.08), M["foliage"], c, rot=(0, 0, R(0, 3)), bevel=0.1, chip=0.5)
    # bushes: clusters of foliage blocks along the fences, terrace edges and the house
    spots = [(-14, -84), (14, -78), (-15, -60), (15, -64), (-13, -20), (14, -6), (-6, -12), (24, 4), (-34, -50), (32, -50), (-44, -6), (58, -8), (-10, 40)]
    for i, (x, y) in enumerate(spots):
        for j in range(RNG.randint(4, 7)):
            s = R(2, 4.5)
            box(f"Bush{i}_{j}", (s * R(0.9, 1.4), s * R(0.8, 1.2), s * R(0.7, 1.0)), (x + R(-3, 3), y + R(-3, 3), s * 0.45 + R(0, 1.5)),
                M["foliage"], c, rot=(R(-0.15, 0.15), R(-0.15, 0.15), R(0, 3)), bevel=0.3, chip=0.35)


# ------------------------------------------------------------------ scale reference
def scale_refs():
    c = clear_coll("Scale_R6")
    core.r6((3, -48, 0.4), c, M["dummy"], yaw=rad(10))
    core.r6((36, -12.5, 0), c, M["dummy"], yaw=rad(180))


# ------------------------------------------------------------------ light, fog, camera
def lighting():
    s = core.scene()
    c = clear_coll("Lighting")
    w = bpy.data.worlds.get("LM_World") or bpy.data.worlds.new("LM_World")
    s.world = w
    w.use_nodes = True
    nt = w.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg = nt.nodes.new("ShaderNodeBackground")
    env = nt.nodes.new("ShaderNodeTexEnvironment")
    env.image = bpy.data.images.load(core.os.path.join(core.TEX, "kloofendal_misty_morning_puresky.hdr"), check_existing=True)
    tint = nt.nodes.new("ShaderNodeMix")
    tint.data_type = "RGBA"
    tint.blend_type = "MULTIPLY"
    tint.inputs["Factor"].default_value = 0.85
    tint.inputs[7].default_value = (*srgb("#4f7f86"), 1)
    nt.links.new(env.outputs["Color"], tint.inputs[6])
    nt.links.new(tint.outputs[2], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 0.65
    nt.links.new(bg.outputs["Background"], out.inputs["Surface"])
    # bounded teal fog (depth layers)
    fog = box("FogVolume", (420, 420, 120), (0, 20, 50), M["fog"], c, bevel=0)
    fog.display_type = "WIRE"
    fog.hide_select = True
    sun = bpy.data.lights.new("Sun_Low", "SUN")
    sun.energy = 2.2
    sun.color = srgb("#ffd2a0")
    sun.angle = rad(1.5)
    so = bpy.data.objects.new("Sun_Low", sun)
    so.rotation_euler = Euler((rad(70), 0, rad(150)))
    c.objects.link(so)
    # camera: a third-person view down the path, like the refs' framing
    cd = bpy.data.cameras.new("Cam_Main")
    cd.lens = 18
    cd.dof.use_dof = True
    cd.dof.aperture_fstop = 8
    cam = bpy.data.objects.new("Cam_Main", cd)
    cam.location = (3, -104, 9.5)
    cam.rotation_euler = Euler((rad(91), 0, rad(1)))
    c.objects.link(cam)
    cd.dof.focus_distance = 70
    s.camera = cam
    r = s.render
    r.engine = "BLENDER_EEVEE"
    r.resolution_x, r.resolution_y = 1920, 1080
    s.view_settings.view_transform = "AgX"
    try:
        s.view_settings.look = "AgX - Medium High Contrast"
    except Exception:
        pass
    e = s.eevee
    for attr, val in (("taa_render_samples", 64), ("volumetric_tile_size", "4"), ("volumetric_end", 600), ("volumetric_samples", 96),
                      ("use_shadows", True), ("use_volumetric_shadows", True), ("use_raytracing", True), ("shadow_ray_count", 2),
                      ("fast_gi_method", "GLOBAL_ILLUMINATION")):
        try:
            setattr(e, attr, val)
        except Exception:
            pass


def fog_mat():
    m = bpy.data.materials.get("LM_Fog") or bpy.data.materials.new("LM_Fog")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    v = nt.nodes.new("ShaderNodeVolumePrincipled")
    v.inputs["Density"].default_value = 0.0105
    v.inputs["Color"].default_value = (*srgb("#86a9a6"), 1)
    v.inputs["Anisotropy"].default_value = 0.5
    nt.links.new(v.outputs["Volume"], out.inputs["Volume"])
    return m


def mats():
    global M
    M = core.materials()
    M["terrace"] = core.pbr("LM_Terrace", "mossy_rock", tile=10, bump=0.7, moss="leafy_grass", moss_amount=0.95)
    M["vine"] = core.flat("LM_Vine", srgb("#1f3a1c"), rough=0.8)
    M["fog"] = fog_mat()
    return M


STAGES = ["materials", "terrain", "house", "trees", "rocks", "props", "scale", "lighting"]


def run(stage="all"):
    if stage in ("all", "reset"):
        core.reset_scene()
    mats()
    todo = STAGES if stage in ("all", "reset") else [stage]
    for st in todo:
        {"materials": lambda: None, "terrain": terrain, "house": house, "trees": trees, "rocks": rocks, "props": props,
         "scale": scale_refs, "lighting": lighting}[st]()
    return {"objects": len(core.scene().objects), "stage": stage}


def render(path, samples=64):
    s = core.scene()
    s.eevee.taa_render_samples = samples
    s.render.filepath = path
    bpy.ops.render.render(write_still=True, scene=s.name)
    return path

"""FMA-style train kit (2026-10-20, world spec "The train model"). Locomotive + tender + baggage, 3rd class, dining,
2nd class, private cabin. 1 Blender unit = 1 stud. Each car: an Empty root ["rs_prefab"] = kind at x along the train,
local +x = forward, rail top at z = 0, floor top at z = 4.2. Helper parts (BoardZone, StowZone, CarDoor) are invisible.
Every size and colour is a PROPOSAL (owner refs: the FMA locomotive, the maroon coach, the 3rd-class benches).

Run in Blender:
    import sys; sys.path.insert(0, r"C:/Users/Owner/Rensei-Game-Design/Art/Blender")
    import train.train as T; result = T.run()            # builds scene "Train"
    T.render_setup(); T.render("loco", path)              # optional preview renders (views in CAMS)
Export with lindenmoor.export.export("Train", <Art/Studio/Train/layout.json>), then studio_kit.py Art/Studio/Train.

Notes on the Roblox side:
- Seat parts are turned so their LookVector (Roblox -Z = Blender -y) points the way the sitter faces.
- Window glass is "LM_TrainGlass" in Blender (see-through for renders) but exports as LM_WindowGlass (Glass, 0.3).
- Wheels sit on rails 5.2 apart (y = +-2.6), matching the Lindenmoor station track in Ye."""
import bpy, math, json, importlib, random
from mathutils import Euler
from lindenmoor import core
importlib.reload(core)
from lindenmoor.core import box, cyl, srgb

SCENE = "Train"
M = {}
L, W, FLOOR = 64.0, 12.0, 4.2   # PROPOSAL: coach length, width, floor top
WALL = FLOOR + 10.6              # PROPOSAL: side-wall top / roof eaves (10.5 headroom under the ceiling)
ROOF = WALL + 1.8                # PROPOSAL: roof crown (arched roof, sagitta 1.8)
VEST = 5.0                       # PROPOSAL: end vestibule length (boarding area)
GAUGE = 2.6                      # wheel centre-line |y| (Ye's station rails are 5.2 apart)
WIN_Z0, WIN_Z1 = FLOOR + 3.4, FLOOR + 7.2   # PROPOSAL: window band (frame outer edges)
DEG = math.radians


def mats():
    M["navy"] = core.flat("LM_TrainNavy", srgb("#23262d"), rough=0.45, metal=0.6)
    M["maroon"] = core.pbr("LM_TrainMaroon", "brown_planks_05", tile=4, tint=srgb("#7a2228"), bump=0.3)
    M["black"] = core.flat("LM_TrainBlack", srgb("#1b1c1e"), rough=0.5, metal=0.7)
    M["roof"] = core.flat("LM_TrainRoof", srgb("#4a4d50"), rough=0.6, metal=0.4)
    M["brass"] = core.flat("LM_Brass", srgb("#b08a3c"), rough=0.3, metal=0.9)
    M["cream"] = core.pbr("LM_Cream", "plastered_wall_04", tile=8, tint=srgb("#e6dcc2"), bump=0.2)
    M["bench"] = core.flat("LM_BenchGreen", srgb("#2f4a3a"), rough=0.9)
    M["wood"] = core.pbr("LM_TrainWood", "medieval_wood", tile=5, tint=srgb("#5a3a26"), bump=0.3)
    M["glass"] = glass_mat()
    # same definition as core.materials(), so the shared village material is never changed
    M["glow"] = core.flat("LM_LanternGlow", srgb("#ffb35c"), rough=0.4, emit=(srgb("#ffad4d"), 18))
    M["helper"] = core.flat("LM_Helper", srgb("#ffffff"), rough=1)


def glass_mat():
    """See-through window glass for the renders; exported as LM_WindowGlass (Studio: Glass, transparency 0.3)."""
    m = core.flat("LM_TrainGlass", srgb("#9fb4bf"), rough=0.05)
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Alpha"].default_value = 0.3
    for attr, val in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND")):
        try:
            setattr(m, attr, val)
        except Exception:
            pass
    return m


def root(kind, x):
    e = bpy.data.objects.new(f"PF_{kind}_Main", None)
    e.location = (x, 0, 0)
    e["rs_prefab"], e["rs_id"] = kind, "Main"
    core.coll("Cars").objects.link(e)
    return e


def P(rt, name, size, loc, m, rot=(0, 0, 0), bevel=0.06, kind=None, invisible=False, attr=None):
    o = box(f"{rt.name}_{name}", size, loc, M[m], rt.users_collection[0], rot=rot, bevel=bevel)
    assert o.name == f"{rt.name}_{name}", f"duplicate part name {o.name}"
    o.parent = rt
    if kind:
        o["rs_kind"] = kind
    if m == "glass":
        o["rs_mat"] = "LM_WindowGlass"
    if invisible:
        o["rs_invisible"] = True
        o.hide_render = True
    if attr:
        o["rs_attr"] = json.dumps(attr)
    return o


def C(rt, name, r, h, loc, m, rot=(0, 0, 0), verts=16):
    o = cyl(f"{rt.name}_{name}", r, h, loc, M[m], rt.users_collection[0], verts=verts, rot=rot)
    assert o.name == f"{rt.name}_{name}", f"duplicate part name {o.name}"
    o.parent = rt
    if m == "glass":
        o["rs_mat"] = "LM_WindowGlass"
    return o


def light(rt, name, loc, energy, rng=16, color="#ffae55"):
    """A PointLight for Roblox (export.py: rs_light; studio_kit.py parents it to the nearest Neon part)."""
    ld = bpy.data.lights.new(f"{rt.name}_{name}", "POINT")
    ld.energy = energy
    ld.color = srgb(color)
    ld.shadow_soft_size = 0.4
    o = bpy.data.objects.new(f"{rt.name}_{name}", ld)
    o.location = loc
    o["rs_light"], o["rs_range"] = "POINT", rng
    rt.users_collection[0].objects.link(o)
    o.parent = rt
    return o


def seat(rt, name, size, loc, m, facing):
    """A Seat part. size = (depth along x, width along y, height). facing = (fx, fy): the way the sitter looks.
    Blender -y (Roblox -Z, the Seat's LookVector) is turned onto that direction."""
    yaw = math.atan2(facing[0], -facing[1])  # Rz(yaw) * (0, -1, 0) = facing
    dx, dy, h = size
    local = (dy, dx, h) if abs(facing[0]) > 0.5 else (dx, dy, h)
    return P(rt, name, local, loc, m, rot=(0, 0, yaw), bevel=0.08, kind="Seat")


# ------------------------------------------------------------------ running gear
def bogie(rt, x, tag):
    P(rt, f"Bogie{tag}", (9, 2 * GAUGE - 1.2, 1.2), (x, 0, 2.2), "black")
    for i, dx in enumerate((-2.6, 2.6)):
        for s in (-1, 1):
            C(rt, f"Wheel{tag}_{i}{'L' if s > 0 else 'R'}", 1.6, 0.6, (x + dx, s * GAUGE, 1.6), "black", rot=(DEG(90), 0, 0))
    for s in (-1, 1):
        P(rt, f"Spring{tag}{'L' if s > 0 else 'R'}", (7, 0.6, 0.6), (x, s * (GAUGE + 0.6), 2.4), "brass", bevel=0.02)


# ------------------------------------------------------------------ coach body
DEFAULT_WINDOWS = [(-24 + 6 * i, 4.2) for i in range(9)]   # (centre x, glass width): about 4 x 3.2, every 6 studs


def side_band(rt, s, items, xa, xb):
    """Fill the window band (WIN_Z0..WIN_Z1) of side s from xa to xb. items: (x, glass_w) windows or (x, w, 'gap')."""
    y = s * (W / 2 - 0.3)
    sd = "L" if s > 0 else "R"
    occ = []
    for k, it in enumerate(items):
        x, gw = it[0], it[1]
        if len(it) > 2:  # an open doorway: nothing in the band
            occ.append((x - gw / 2, x + gw / 2))
            continue
        fw = gw + 0.8
        occ.append((x - fw / 2, x + fw / 2))
        zc = (WIN_Z0 + WIN_Z1) / 2
        P(rt, f"Window{sd}{k}", (gw + 0.1, 0.2, WIN_Z1 - WIN_Z0 - 0.5), (x, y, zc), "glass", bevel=0)
        P(rt, f"Sill{sd}{k}", (fw, 1.4, 0.3), (x, y - s * 0.1, WIN_Z0 + 0.15), "wood", bevel=0.03)
        P(rt, f"WinHead{sd}{k}", (fw, 0.9, 0.3), (x, y, WIN_Z1 - 0.15), "wood", bevel=0.03)
        for j, sx in enumerate((-1, 1)):
            P(rt, f"Jamb{sd}{k}{j}", (0.4, 0.9, WIN_Z1 - WIN_Z0 - 0.6), (x + sx * (fw / 2 - 0.2), y, zc), "wood", bevel=0.02)
    occ.sort()
    cur, k = xa, 0
    for a, b in occ + [(xb, xb)]:
        if a - cur > 0.05:
            P(rt, f"Pier{sd}{k}", (a - cur, 0.6, WIN_Z1 - WIN_Z0), ((a + cur) / 2, y, (WIN_Z0 + WIN_Z1) / 2), "maroon", bevel=0.03)
            k += 1
        cur = max(cur, b)


def coach_shell(rt, kind, windows=True, win=None, door_gap=None, lamp_energy=1500):
    """Underframe, floor, maroon sides with wood-framed windows, end vestibules (open side doors + two steps),
    arched roof of tilted slabs, cream lining and ceiling, covered gangways, two BoardZones and two CarDoors.
    win: {side: [(x, glass_w), ...]} to override the window layout per side. door_gap: (side, x0, x1) open doorway."""
    P(rt, "Underframe", (L - 2, W - 1, 1.2), (0, 0, 3.0), "black")
    for i, x in enumerate((-L / 2 + 9, L / 2 - 9)):
        bogie(rt, x, "AB"[i])
    for s in (-1, 1):  # truss rods under the frame
        P(rt, f"Truss{'L' if s > 0 else 'R'}", (L - 24, 0.3, 0.3), (0, s * (W / 2 - 1.2), 2.2), "black", bevel=0)
    P(rt, "Floor", (L, W, 0.6), (0, 0, FLOOR - 0.3), "wood")
    xa, xb = -L / 2 + VEST, L / 2 - VEST
    for s in (-1, 1):
        y = s * (W / 2 - 0.3)
        sd = "L" if s > 0 else "R"
        gap = door_gap if door_gap and door_gap[0] == s else None
        # lower panel (split around an open side door) and upper panel
        spans = [(xa, gap[1]), (gap[2], xb)] if gap else [(xa, xb)]
        for j, (a, b) in enumerate(spans):
            P(rt, f"Lower{sd}{j}", (b - a, 0.6, WIN_Z0 + 0.1 - FLOOR), ((a + b) / 2, y, (FLOOR + WIN_Z0 + 0.1) / 2), "maroon")
            P(rt, f"LiningLow{sd}{j}", (b - a, 0.2, WIN_Z0 - FLOOR), ((a + b) / 2, s * (W / 2 - 0.75), (FLOOR + WIN_Z0) / 2), "cream", bevel=0)
        P(rt, f"Upper{sd}", (xb - xa, 0.6, WALL - WIN_Z1 + 0.1), (0, y, (WIN_Z1 - 0.1 + WALL) / 2), "maroon")
        P(rt, f"LiningHigh{sd}", (xb - xa, 0.2, WALL - 0.1 - WIN_Z1), (0, s * (W / 2 - 0.75), (WIN_Z1 + WALL - 0.1) / 2), "cream", bevel=0)
        for j, (a, b) in enumerate(spans):  # brass lining strip (broken by an open side door)
            P(rt, f"Waist{sd}{j}", (b - a, 0.3, 0.25), ((a + b) / 2, s * (W / 2 + 0.05), WIN_Z0 - 0.6), "brass", bevel=0)
        items = []
        if windows:
            items = list((win or {}).get(s, DEFAULT_WINDOWS))
        if gap:
            items = [it for it in items if it[0] + it[1] / 2 < gap[1] or it[0] - it[1] / 2 > gap[2]]
            items.append(((gap[1] + gap[2]) / 2, gap[2] - gap[1], "gap"))
        side_band(rt, s, items, xa, xb)
        # end vestibules: an open side door (VEST wide x 8.5 high), framed, with two steps down and grab handles
        for e in (-1, 1):
            ed = "F" if e > 0 else "B"
            xe = e * (L / 2 - VEST / 2)
            P(rt, f"DoorHead{sd}{ed}", (VEST, 0.6, WALL - FLOOR - 8.5), (xe, y, (FLOOR + 8.5 + WALL) / 2), "maroon")
            P(rt, f"StepA{sd}{ed}", (4.4, 0.8, 0.4), (xe, s * (W / 2), FLOOR - 1.1), "black", bevel=0.03)
            P(rt, f"StepB{sd}{ed}", (4.4, 0.8, 0.4), (xe, s * (W / 2 + 0.6), FLOOR - 2.0), "black", bevel=0.03)
            for j, hx in enumerate((-1, 1)):
                P(rt, f"StepHanger{sd}{ed}{j}", (0.2, 1.4, 1.9), (xe + hx * 2.3, s * (W / 2 + 0.2), FLOOR - 1.45), "black", bevel=0)
            for j, gx in enumerate((e * (L / 2 - VEST + 0.3), e * (L / 2 - 0.9))):
                P(rt, f"Grab{sd}{ed}{j}", (0.25, 0.25, 6), (gx, s * (W / 2 + 0.15), FLOOR + 4), "brass", bevel=0)
    # ends: end wall with a gangway opening (4 wide x 8.5), the covered gangway, the vestibule partition and doorway
    for e in (-1, 1):
        ed = "F" if e > 0 else "B"
        x = e * (L / 2 - 0.3)
        for s in (-1, 1):
            P(rt, f"EndWall{ed}{'L' if s > 0 else 'R'}", (0.6, (W - 4) / 2, WALL - FLOOR), (x, s * ((W - 4) / 4 + 2), (FLOOR + WALL) / 2), "maroon")
        P(rt, f"EndTop{ed}", (0.6, 4, WALL - FLOOR - 8.5), (x, 0, (FLOOR + 8.5 + WALL) / 2), "maroon")
        # covered gangway: hollow, walkable, 1.5 long so two cars' gangways meet across the 3-stud gap
        gx = e * (L / 2 + 0.75)
        for s in (-1, 1):
            P(rt, f"Bellows{ed}{'L' if s > 0 else 'R'}", (1.5, 0.4, 9.1), (gx, s * 2.4, FLOOR + 4.55), "black", bevel=0.1)
        P(rt, f"BellowsTop{ed}", (1.5, 5.2, 0.6), (gx, 0, FLOOR + 8.8), "black", bevel=0.1)
        P(rt, f"GangPlate{ed}", (1.5, 4.4, 0.3), (gx, 0, FLOOR - 0.15), "black", bevel=0)
        xp = e * (L / 2 - VEST)
        for s in (-1, 1):
            P(rt, f"Partition{ed}{'L' if s > 0 else 'R'}", (0.4, (W - 4) / 2 - 0.5, WALL - FLOOR - 0.1),
              (xp, s * ((W - 4) / 4 + 1.75), (FLOOR + WALL - 0.1) / 2), "wood")
        P(rt, f"PartitionTop{ed}", (0.4, 4, WALL - FLOOR - 8.6), (xp, 0, (FLOOR + 8.5 + WALL - 0.1) / 2), "wood")
        P(rt, f"CarDoor{ed}", (0.6, 4, 8.5), (xp, 0, FLOOR + 4.25), "helper", invisible=True, attr={"CarKind": kind})
        P(rt, f"BoardZone{ed}", (VEST - 0.6, W - 1.4, 8), (e * (L / 2 - VEST / 2), 0, FLOOR + 4), "helper", invisible=True,
          attr={"CarKind": kind})
    roof(rt)
    P(rt, "Ceiling", (L - 1.2, W - 1.2, 0.2), (0, 0, WALL - 0.1), "cream", bevel=0)
    for i, x in enumerate(range(-24, 25, 12)):
        P(rt, f"Lamp{i}", (0.9, 0.9, 0.5), (x, 0, WALL - 0.45), "glow", bevel=0.1)
        P(rt, f"LampRose{i}", (1.4, 1.4, 0.15), (x, 0, WALL - 0.25), "brass", bevel=0.03)
    for i, x in enumerate((-24, 0, 24)):
        light(rt, f"Light{i}", (x, 0, WALL - 1.2), lamp_energy)


def roof(rt):
    """Arched roof: 7 tilted slabs on a circle through the eaves (y = +-6.1, z = WALL) and the crown (ROOF);
    gable fillers close the ends under the arch; gutters along the eaves; a row of roof vents."""
    half = W / 2 + 0.1
    sag = ROOF - WALL
    R = (half * half + sag * sag) / (2 * sag)
    zc = ROOF - R
    amax = math.asin(half / R)
    n = 7
    step = 2 * amax / n
    sw = 2 * R * math.sin(step / 2) + 0.12
    for i in range(-(n // 2), n // 2 + 1):
        a = i * step
        y, z = R * math.sin(a), zc + R * math.cos(a)
        P(rt, f"Roof{i + 3}", (L + 0.4, sw, 0.5), (0, y, z), "roof", rot=(-a, 0, 0), bevel=0.04)
        # gable filler under this slab at each end, from the wall top up to the slab's lower edge
        zlow = zc + R * math.cos(abs(a) + step / 2) - 0.3
        if zlow - WALL > 0.15:
            for e in (-1, 1):
                P(rt, f"Gable{'F' if e > 0 else 'B'}{i + 3}", (0.6, sw * math.cos(a), zlow - WALL + 0.05),
                  (e * (L / 2 - 0.3), y, (WALL + zlow) / 2 - 0.025), "maroon", bevel=0)
    for s in (-1, 1):
        P(rt, f"Gutter{'L' if s > 0 else 'R'}", (L + 0.4, 0.35, 0.35), (0, s * (half + 0.05), WALL - 0.05), "black", bevel=0.05)
    for i, x in enumerate((-21, -7, 7, 21)):
        C(rt, f"Vent{i}", 0.4, 0.7, (x, 0, ROOF + 0.4), "black", verts=10)


# ------------------------------------------------------------------ fittings
def bench(rt, x, y, facing, tag, width=3.15):
    """A bench facing +x (facing=1) or -x: base, Seat (cushion), back and its wooden cap."""
    P(rt, f"BenchBase{tag}", (2.0, width, 1.6), (x, y, FLOOR + 0.8), "wood")
    seat(rt, f"Seat{tag}", (2.2, width, 0.6), (x, y, FLOOR + 1.9), "bench", (facing, 0))
    P(rt, f"Back{tag}", (0.5, width, 3.4), (x - facing * 1.2, y, FLOOR + 3.8), "bench", bevel=0.12)
    P(rt, f"BackTop{tag}", (0.7, width + 0.1, 0.4), (x - facing * 1.2, y, FLOOR + 5.6), "wood")


def third_class(rt):
    """Open saloon: 7 bays of facing benches either side of a 4-stud centre aisle (28 Seats), brass luggage racks."""
    coach_shell(rt, "ThirdClass")
    for i in range(7):
        x = -22.8 + 7.6 * i            # PROPOSAL: bay pitch 7.6
        for side in (-1, 1):
            sd = "L" if side > 0 else "R"
            y = side * 3.575           # benches 3.15 wide: |y| 2.0 .. 5.15
            bench(rt, x - 2.0, y, 1, f"{i}{sd}a")
            bench(rt, x + 2.0, y, -1, f"{i}{sd}b")
            P(rt, f"Rack{i}{sd}", (6.0, 1.4, 0.15), (x, side * 4.45, FLOOR + 8.0), "brass", bevel=0)
            P(rt, f"RackRail{i}{sd}", (6.0, 0.15, 0.15), (x, side * 3.8, FLOOR + 8.15), "brass", bevel=0)


def dining(rt):
    """Six tables for four (spec): three each side of a 4.2-wide centre aisle. Each table has a two-place bench at
    each end, so 4 Seats a table (1.5 wide each), 24 in all. A bar counter with a bottle shelf beyond the tables."""
    coach_shell(rt, "DiningCar")
    for i, x in enumerate((-18, -6, 6)):
        for side in (-1, 1):
            sd = "L" if side > 0 else "R"
            y = side * 3.6                # PROPOSAL: tables + benches span |y| 2.1 .. 5.1 (aisle |y| < 2.1)
            P(rt, f"Table{i}{sd}", (3.0, 3.0, 0.3), (x, y, FLOOR + 2.9), "wood")
            P(rt, f"TableCloth{i}{sd}", (2.6, 2.6, 0.06), (x, y, FLOOR + 3.08), "cream", bevel=0)
            P(rt, f"Leg{i}{sd}", (0.4, 0.4, 2.75), (x, y, FLOOR + 1.375), "brass", bevel=0)
            P(rt, f"TableLamp{i}{sd}", (0.5, 0.5, 0.7), (x, y + side * 1.0, FLOOR + 3.45), "glow", bevel=0.1)
            for j, dx in enumerate((-2.4, 2.4)):
                f = 1 if dx < 0 else -1  # the benches face the table
                P(rt, f"ChairBase{i}{sd}{j}", (1.4, 3.0, 1.55), (x + dx, y, FLOOR + 0.775), "wood")
                for k, dy in enumerate((-0.75, 0.75)):  # two places per bench
                    seat(rt, f"Chair{i}{sd}{j}{k}", (1.6, 1.45, 0.5), (x + dx, y + dy, FLOOR + 1.8), "bench", (f, 0))
                P(rt, f"ChairBack{i}{sd}{j}", (0.4, 3.0, 2.6), (x + dx - f * 0.8, y, FLOOR + 3.2), "wood")
    P(rt, "Bar", (12, 2.4, 3.6), (17, -2.8, FLOOR + 1.8), "wood")
    P(rt, "BarTop", (12.4, 2.8, 0.3), (17, -2.8, FLOOR + 3.75), "brass")
    P(rt, "Shelf", (12, 0.8, 0.3), (17, -4.75, FLOOR + 3.9), "wood")
    for k in range(6):
        P(rt, f"Bottle{k}", (0.4, 0.4, 1.0), (12.5 + k * 1.8, -4.75, FLOOR + 4.55), "glass", bevel=0)


def corridor_wall(rt, tag, x0, x1, door_x, y=0.9, windows=False):
    """A wooden corridor wall along x at y, floor to ceiling, with a 3-wide x 8-high doorway centred on door_x."""
    h = WALL - FLOOR - 0.1
    spans = [(x0, door_x - 1.5), (door_x + 1.5, x1)]
    for j, (a, b) in enumerate(spans):
        if b - a < 0.05:
            continue
        if windows:
            P(rt, f"CorrLow{tag}{j}", (b - a, 0.4, 3.4), ((a + b) / 2, y, FLOOR + 1.7), "wood")
            P(rt, f"CompWindow{tag}{j}", (b - a, 0.2, 3.8), ((a + b) / 2, y, FLOOR + 5.3), "glass", bevel=0)
            P(rt, f"CorrHigh{tag}{j}", (b - a, 0.4, h - 7.2), ((a + b) / 2, y, FLOOR + (7.2 + h) / 2), "wood")
        else:
            P(rt, f"CorrWall{tag}{j}", (b - a, 0.4, h), ((a + b) / 2, y, FLOOR + h / 2), "wood")
    P(rt, f"Lintel{tag}", (3.0, 0.4, h - 8), (door_x, y, FLOOR + (8 + h) / 2), "wood")


def second_class(rt):
    """Side corridor (4 wide, +y) and four compartments (-y), each with two facing benches (8 Seats), a glazed corridor
    wall and a sliding door standing open."""
    coach_shell(rt, "SecondClass", win={-1: [(-23.5, 4.2), (-15, 5.0), (-5, 5.0), (5, 5.0), (15, 5.0), (23.5, 4.2)]})
    yc = (-(W / 2 - 0.85) + 0.7) / 2      # compartment centre line (between the lining and the corridor wall)
    for i, x in enumerate((-20, -10, 0, 10, 20)):
        P(rt, f"CompWall{i}", (0.4, 6.0, WALL - FLOOR - 0.1), (x, -2.15, (FLOOR + WALL - 0.1) / 2), "wood")
    for i, x in enumerate((-15, -5, 5, 15)):
        corridor_wall(rt, f"C{i}", x - 5, x + 5, x, windows=True)
        bench(rt, x - 3.6, yc, 1, f"C{i}a", width=5.6)
        bench(rt, x + 3.6, yc, -1, f"C{i}b", width=5.6)
        P(rt, f"DoorLeafLow{i}", (3.0, 0.2, 3.4), (x + 3.0, 1.25, FLOOR + 1.7), "wood", bevel=0.03)
        P(rt, f"DoorPane{i}", (3.0, 0.2, 4.6), (x + 3.0, 1.25, FLOOR + 5.7), "glass", bevel=0)
        P(rt, f"DoorLeafTop{i}", (3.0, 0.25, 0.3), (x + 3.0, 1.25, FLOOR + 8.1), "wood", bevel=0.02)
        P(rt, f"CompLamp{i}", (0.6, 0.6, 0.5), (x, yc, WALL - 0.45), "glow", bevel=0.1)


def cabin_car(rt):
    """Two private cabins (a bed bench, a table and a lamp) off a side corridor, and a small sitting nook (4 Seats)."""
    coach_shell(rt, "CabinCar", win={-1: [(-23.5, 4.2), (-15, 4.2), (-9, 4.2), (1, 4.2), (7, 4.2), (17, 4.2), (23, 4.2)]})
    for i, x in enumerate((-20, -4, 12)):
        P(rt, f"CabinWall{i}", (0.4, 6.0, WALL - FLOOR - 0.1), (x, -2.15, (FLOOR + WALL - 0.1) / 2), "wood")
    for i, (x0, x1) in enumerate(((-20, -4), (-4, 12))):
        corridor_wall(rt, f"K{i}", x0, x1, x1 - 2.2)
        P(rt, f"BedBase{i}", (7, 3.6, 1.2), (x0 + 4.2, -3.3, FLOOR + 0.6), "wood")
        seat(rt, f"Bed{i}", (7, 3.6, 0.6), (x0 + 4.2, -3.3, FLOOR + 1.5), "bench", (0, 1))
        P(rt, f"Pillow{i}", (1.4, 2.6, 0.5), (x0 + 1.6, -3.3, FLOOR + 2.0), "cream", bevel=0.2)
        P(rt, f"BedHead{i}", (0.6, 3.6, 3.4), (x0 + 0.6, -3.3, FLOOR + 1.7), "wood")
        P(rt, f"CabinTable{i}", (2.4, 2.4, 0.3), (x0 + 10.5, -3.6, FLOOR + 2.8), "wood")
        P(rt, f"CabinTableLeg{i}", (0.4, 0.4, 2.65), (x0 + 10.5, -3.6, FLOOR + 1.325), "brass", bevel=0)
        P(rt, f"CabinLamp{i}", (0.5, 0.5, 0.8), (x0 + 10.5, -3.6, FLOOR + 3.35), "glow", bevel=0.1)
        P(rt, f"CabinCeilLamp{i}", (0.6, 0.6, 0.5), (x0 + 8, -2.2, WALL - 0.45), "glow", bevel=0.1)
    # sitting nook: two armchairs facing across a small table
    for k, (x, f) in enumerate(((15.5, 1), (22.5, -1))):
        P(rt, f"ArmchairBase{k}", (2.4, 2.4, 1.2), (x, -3.2, FLOOR + 0.6), "wood")
        seat(rt, f"Armchair{k}", (2.4, 2.4, 0.6), (x, -3.2, FLOOR + 1.5), "bench", (f, 0))
        P(rt, f"ArmchairBack{k}", (0.6, 2.4, 3.0), (x - f * 1.2, -3.2, FLOOR + 3.0), "bench", bevel=0.15)
        for j, s in enumerate((-1, 1)):
            P(rt, f"ArmchairArm{k}{j}", (2.4, 0.4, 1.0), (x, -3.2 + s * 1.2, FLOOR + 2.3), "bench", bevel=0.12)
    P(rt, "NookTable", (1.8, 1.8, 0.3), (19, -3.2, FLOOR + 2.4), "wood")
    P(rt, "NookTableLeg", (0.4, 0.4, 2.25), (19, -3.2, FLOOR + 1.125), "brass", bevel=0)


def baggage_car(rt):
    """Crates, mail sacks and a dim lamp; an open sliding door on +y = Roblox local +Z (the freight-yard side: the
    stowaway route). World Plan 1 Task 6 turns each car by CFrame.Angles(0, -90deg, 0), which sends local +Z to world
    -X in Ye: away from the platform (the platform is on the track's +X side)."""
    D = 1  # the door side (Blender y sign)
    coach_shell(rt, "BaggageCar", windows=False, door_gap=(D, -2.5, 2.5), lamp_energy=700)
    P(rt, "DoorLeaf", (5.4, 0.3, 7.0), (5.6, D * (W / 2 + 0.15), FLOOR + 3.5), "maroon")
    P(rt, "DoorRail", (11.8, 0.3, 0.3), (2.8, D * (W / 2 + 0.15), FLOOR + 7.25), "black", bevel=0)
    P(rt, "DoorFrameL", (0.4, 0.8, 7.1), (-2.7, D * (W / 2 - 0.3), FLOOR + 3.55), "wood", bevel=0.02)
    P(rt, "DoorFrameR", (0.4, 0.8, 7.1), (2.7, D * (W / 2 - 0.3), FLOOR + 3.55), "wood", bevel=0.02)
    P(rt, "StowZone", (5, 3, 7), (0, D * 3.6, FLOOR + 3.5), "helper", invisible=True, attr={"CarKind": "BaggageCar"})
    rnd = random.Random(7)
    placed = [(-3.5, 3.5, 1.5, 5.2) if D > 0 else (-3.5, 3.5, -5.2, -1.5)]  # keep the doorway and the StowZone clear
    inner = W / 2 - 0.85

    def free(x0, x1, y0, y1):
        return all(x1 < a or x0 > b or y1 < c or y0 > d for a, b, c, d in placed)
    k = tries = 0
    while k < 10 and tries < 400:
        tries += 1
        s = rnd.uniform(2.2, 3.4)
        x, side = rnd.uniform(-24, 24), rnd.choice((-1, 1))
        y = side * (inner - s / 2 - 0.25)
        if free(x - s / 2 - 0.3, x + s / 2 + 0.3, y - s / 2 - 0.3, y + s / 2 + 0.3):
            placed.append((x - s / 2 - 0.3, x + s / 2 + 0.3, y - s / 2 - 0.3, y + s / 2 + 0.3))
            P(rt, f"Crate{k}", (s, s, s), (x, y, FLOOR + s / 2), "wood", rot=(0, 0, rnd.uniform(-0.12, 0.12)))
            k += 1
    k = tries = 0
    while k < 6 and tries < 400:
        tries += 1
        x, side = rnd.uniform(-22, 22), rnd.choice((-1, 1))
        y = side * (inner - 0.85)
        if free(x - 1.1, x + 1.1, y - 0.8, y + 0.8):
            placed.append((x - 1.1, x + 1.1, y - 0.8, y + 0.8))
            P(rt, f"Sack{k}", (1.8, 1.2, 1.2), (x, y, FLOOR + 0.6), "cream", rot=(0, 0, rnd.uniform(-0.4, 0.4)), bevel=0.4)
            k += 1


# ------------------------------------------------------------------ locomotive and tender
def locomotive(rt):
    """Navy-black engine: boiler with brass bands, a big round smokebox door ringed with bolts, twin headlamps,
    chimney and dome, three coupled driving wheels with side rods, a leading bogie and a cab. Front = +x."""
    P(rt, "Frame", (70, 2 * GAUGE - 1.6, 1.6), (0, 0, 3.4), "black")
    P(rt, "Running", (66, 12, 0.4), (1.0, 0, 5.4), "black", bevel=0.02)
    for s in (-1, 1):
        P(rt, f"Valance{'L' if s > 0 else 'R'}", (60, 0.3, 0.7), (-1.0, s * 5.9, 4.9), "black", bevel=0)
    P(rt, "BufferBeam", (0.8, 10, 1.8), (34.6, 0, 3.6), "black")
    for s in (-1, 1):
        C(rt, f"Buffer{'L' if s > 0 else 'R'}", 0.6, 1.0, (35.4, s * 3.2, 3.6), "brass", rot=(0, DEG(90), 0), verts=10)
    P(rt, "Pilot", (3.0, 8, 0.35), (34.95, 0, 1.55), "black", rot=(0, DEG(50), 0))
    # boiler, smokebox, smokebox door with its ring of bolts
    C(rt, "Boiler", 4.4, 43, (3.5, 0, 10.6), "navy", rot=(0, DEG(90), 0), verts=24)
    for i, x in enumerate((-10, 0, 10, 20)):
        C(rt, f"Band{i}", 4.5, 0.4, (x, 0, 10.6), "brass", rot=(0, DEG(90), 0), verts=24)
    C(rt, "Smokebox", 4.9, 8, (28, 0, 10.6), "navy", rot=(0, DEG(90), 0), verts=24)
    C(rt, "SmokeboxRing", 5.0, 0.4, (31.9, 0, 10.6), "black", rot=(0, DEG(90), 0), verts=24)
    C(rt, "SmokeboxDoor", 4.6, 0.8, (32.4, 0, 10.6), "navy", rot=(0, DEG(90), 0), verts=24)
    C(rt, "DoorDome", 3.4, 0.4, (32.9, 0, 10.6), "navy", rot=(0, DEG(90), 0), verts=24)
    for k in range(12):
        a = k / 12 * math.tau
        C(rt, f"Bolt{k}", 0.35, 0.5, (32.9, math.cos(a) * 3.95, 10.6 + math.sin(a) * 3.95), "brass", rot=(0, DEG(90), 0), verts=8)
    P(rt, "DoorBar", (0.5, 0.6, 5.6), (33.2, 0, 10.6), "brass", bevel=0.02)
    C(rt, "DoorHub", 0.7, 0.6, (33.3, 0, 10.6), "brass", rot=(0, DEG(90), 0), verts=12)
    # twin headlamps on the front footplate
    for s in (-1, 1):
        sd = "L" if s > 0 else "R"
        P(rt, f"LampHousing{sd}", (1.6, 2.2, 2.2), (32.2, s * 3.4, 6.7), "navy")
        C(rt, f"LampRim{sd}", 1.0, 0.3, (33.05, s * 3.4, 6.7), "brass", rot=(0, DEG(90), 0), verts=14)
        C(rt, f"Headlamp{sd}", 0.8, 0.3, (33.2, s * 3.4, 6.7), "glow", rot=(0, DEG(90), 0), verts=14)
        light(rt, f"HeadLight{sd}", (34.2, s * 3.4, 6.7), 4500, rng=30, color="#ffd9a0")
    # chimney, dome, safety valve
    C(rt, "Chimney", 1.4, 4.2, (28, 0, 16.6), "black", verts=14)
    C(rt, "ChimneyLip", 1.75, 0.5, (28, 0, 18.75), "black", verts=14)
    P(rt, "SteamOut", (1, 1, 1), (28, 0, 19.6), "helper", invisible=True, attr={"Emit": "Steam"})
    C(rt, "Dome", 1.8, 2.4, (12, 0, 15.6), "brass", verts=14)
    C(rt, "DomeCap", 1.2, 0.5, (12, 0, 17.0), "brass", verts=14)
    C(rt, "SafetyValve", 0.5, 1.4, (-8, 0, 15.4), "brass", verts=10)
    for s in (-1, 1):
        P(rt, f"Handrail{'L' if s > 0 else 'R'}", (41, 0.3, 0.3), (3.5, s * 3.7, 13.2), "brass", bevel=0)
    # running gear: leading bogie, three coupled drivers with brass hubs, coupling and main rods, steam cylinders
    bogie(rt, 27, "Lead")
    for i, x in enumerate((-8, 2, 12)):
        for s in (-1, 1):
            sd = "L" if s > 0 else "R"
            C(rt, f"Driver{i}{sd}", 2.6, 0.8, (x, s * GAUGE, 2.6), "black", rot=(DEG(90), 0, 0), verts=20)
            C(rt, f"DriverBoss{i}{sd}", 1.3, 0.3, (x, s * (GAUGE + 0.4), 2.6), "navy", rot=(DEG(90), 0, 0), verts=14)
            C(rt, f"Hub{i}{sd}", 0.7, 0.5, (x, s * (GAUGE + 0.65), 2.6), "brass", rot=(DEG(90), 0, 0), verts=10)
    for s in (-1, 1):
        sd = "L" if s > 0 else "R"
        P(rt, f"CouplingRod{sd}", (22, 0.4, 0.6), (2, s * (GAUGE + 1.15), 2.6), "brass", bevel=0.02)
        P(rt, f"MainRod{sd}", (7.9, 0.3, 0.45), (15.75, s * (GAUGE + 1.5), 3.25), "brass", rot=(0, DEG(-9.3), 0), bevel=0.02)
        C(rt, f"SteamCyl{sd}", 1.5, 5, (22, s * 4.4, 3.9), "navy", rot=(0, DEG(90), 0), verts=16)
        for j, cx in enumerate((19.6, 24.4)):
            C(rt, f"CylCover{sd}{j}", 1.6, 0.25, (cx, s * 4.4, 3.9), "brass", rot=(0, DEG(90), 0), verts=16)
        C(rt, f"Trailing{sd}", 1.6, 0.6, (-24, s * GAUGE, 1.6), "black", rot=(DEG(90), 0, 0))
    # cab
    P(rt, "CabFloor", (12, 11, 0.6), (-24, 0, 6.0), "wood")
    for s in (-1, 1):
        sd = "L" if s > 0 else "R"
        y = s * 5.3
        P(rt, f"CabSideLow{sd}", (12, 0.6, 4.5), (-24, y, 8.55), "navy")
        P(rt, f"CabSideTop{sd}", (12, 0.6, 1.5), (-24, y, 14.55), "navy")
        P(rt, f"CabSideFront{sd}", (2, 0.6, 3.0), (-19, y, 12.3), "navy")
        P(rt, f"CabSideBack{sd}", (4, 0.6, 3.0), (-28, y, 12.3), "navy")
        P(rt, f"CabWinSill{sd}", (6.4, 0.8, 0.25), (-23, y, 10.8), "brass", bevel=0.02)
        C(rt, f"CabWindow{sd}", 0.8, 0.2, (-17.85, s * 3.6, 14.0), "glass", rot=(0, DEG(90), 0), verts=14)
        C(rt, f"CabWinRim{sd}", 0.95, 0.15, (-17.8, s * 3.6, 14.0), "brass", rot=(0, DEG(90), 0), verts=14)
    P(rt, "CabFront", (0.6, 11, 9), (-18.2, 0, 10.8), "navy")
    P(rt, "CabRoof", (14, 12.4, 0.6), (-24, 0, 15.6), "roof")
    P(rt, "Backhead", (0.4, 7, 7), (-18.7, 0, 10.0), "black")
    for k in range(3):
        C(rt, f"Gauge{k}", 0.45, 0.2, (-19.0, -1.5 + k * 1.5, 12.4), "brass", rot=(0, DEG(90), 0), verts=10)


def tender(rt):
    P(rt, "Frame", (28, 9, 1.4), (0, 0, 3.2), "black")
    P(rt, "Tank", (26, 11, 7.4), (0, 0, 7.6), "navy")
    P(rt, "TankBand", (26.2, 11.2, 0.3), (0, 0, 11.15), "brass", bevel=0.03)
    P(rt, "TankFoot", (26.2, 11.2, 0.3), (0, 0, 4.1), "brass", bevel=0.03)
    P(rt, "Coal", (12, 9, 1.6), (6, 0, 12.0), "black", bevel=0.4)
    C(rt, "Hatch", 0.8, 0.4, (-8, 0, 11.5), "black", verts=12)
    for i, x in enumerate((-8, 8)):
        bogie(rt, x, "AB"[i])


CARS = [("Locomotive", 72, locomotive), ("Tender", 30, tender), ("BaggageCar", L, baggage_car),
        ("ThirdClass", L, third_class), ("DiningCar", L, dining), ("SecondClass", L, second_class), ("CabinCar", L, cabin_car)]
GAP = 3.0


def run():
    global M
    old = (core.SCENE, core.ROOT)
    core.SCENE = core.ROOT = SCENE
    try:
        core.reset_scene()
        mats()
        x = 0.0
        for kind, length, fn in CARS:
            rt = root(kind, x - length / 2)
            fn(rt)
            x -= length + GAP
        n = len(core.scene().objects)
    finally:
        core.SCENE, core.ROOT = old
    return {"objects": n, "length": -x - GAP}


# ------------------------------------------------------------------ preview renders (not exported)
CAMS = {  # name: (location, look-at, lens mm)
    "loco": ((24, -26, 8.5), (-14, 0, 8.5), 28),
    "coach": ((-178, -34, 6.5), (-212, 0, 8.5), 30),
    "interior": ((-184.2, 0.0, 9.6), (-230, 0.0, 7.6), 14),
    "dining": ((-262, 0.8, 11.6), (-284, -3.6, 5.0), 16),
    "baggage": ((-118, 30, 6.5), (-140, 0, 6.5), 30),
}


def render_setup():
    s = bpy.data.scenes[SCENE]
    rc = bpy.data.collections.get("TrainRender")
    if rc:
        for o in list(rc.objects):
            bpy.data.objects.remove(o, do_unlink=True)
    else:
        rc = bpy.data.collections.new("TrainRender")
        s.collection.children.link(rc)
    ground = core.pbr("LM_DirtPath", "stony_dirt_path", tile=8, bump=0.6, variation=0.05)
    iron = core.flat("LM_Iron", srgb("#2b2a28"), rough=0.45, metal=0.9)
    timber = core.pbr("LM_Timber", "medieval_wood", tile=6, tint=srgb("#8a6a52"), bump=0.5, variation=0.15)
    stone = core.pbr("LM_StoneBase", "stacked_stone_wall", tile=7, bump=0.8, variation=0.1)
    props = [box("R_Ground", (900, 300, 1), (-200, 0, -1.3), ground, rc, bevel=0),
             box("R_RailL", (900, 0.5, 0.6), (-200, GAUGE, -0.3), iron, rc, bevel=0),
             box("R_RailR", (900, 0.5, 0.6), (-200, -GAUGE, -0.3), iron, rc, bevel=0),
             box("R_Platform", (300, 10, 2.4), (-230, -11, -0.4), stone, rc, bevel=0.05)]  # -y = Ye's platform side
    for i in range(160):
        props.append(box(f"R_Sleeper{i}", (1.2, 8, 0.5), (60 - i * 5.0, 0, -0.85), timber, rc, bevel=0))
    for o in props:
        o["rs_skip"] = True
    w = bpy.data.worlds.get("TR_World") or bpy.data.worlds.new("TR_World")
    s.world = w
    w.use_nodes = True
    nt = w.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg = nt.nodes.new("ShaderNodeBackground")
    env = nt.nodes.new("ShaderNodeTexEnvironment")
    env.image = bpy.data.images.load(core.os.path.join(core.TEX, "kloofendal_misty_morning_puresky.hdr"), check_existing=True)
    nt.links.new(env.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 0.8
    nt.links.new(bg.outputs["Background"], out.inputs["Surface"])
    sun = bpy.data.lights.new("TR_Sun", "SUN")
    sun.energy = 3.0
    sun.color = srgb("#ffe2bd")
    sun.angle = DEG(1.5)
    so = bpy.data.objects.new("TR_Sun", sun)
    so.rotation_euler = Euler((DEG(55), 0, DEG(-35)))
    rc.objects.link(so)
    r = s.render
    r.engine = "BLENDER_EEVEE"
    r.resolution_x, r.resolution_y = 1600, 900
    s.view_settings.view_transform = "AgX"
    try:
        s.view_settings.look = "AgX - Medium High Contrast"
    except Exception:
        pass
    e = s.eevee
    for attr, val in (("taa_render_samples", 32), ("use_shadows", True), ("use_raytracing", True),
                      ("fast_gi_method", "GLOBAL_ILLUMINATION")):
        try:
            setattr(e, attr, val)
        except Exception:
            pass
    return len(props)


def render(view, path, samples=32):
    s = bpy.data.scenes[SCENE]
    loc, at, lens = CAMS[view]
    name = f"TR_Cam_{view}"
    cam = bpy.data.objects.get(name)
    if not cam:
        cam = bpy.data.objects.new(name, bpy.data.cameras.new(name))
        bpy.data.collections["TrainRender"].objects.link(cam)
    cam.data.lens = lens
    cam.data.clip_start = 0.1
    cam.location = loc
    d = (at[0] - loc[0], at[1] - loc[1], at[2] - loc[2])
    from mathutils import Vector
    cam.rotation_euler = Vector(d).to_track_quat("-Z", "Y").to_euler()
    s.camera = cam
    s.eevee.taa_render_samples = samples
    s.render.filepath = path
    bpy.ops.render.render(write_still=True, scene=s.name)
    return path

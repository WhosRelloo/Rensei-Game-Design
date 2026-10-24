"""The rail-town style kit (Foundry Yard; spec 2026-10-23 §3.3 and §7, plan Task 10): furnace brick, soot, iron trim,
smokestacks and warm windows, in the blocky Lindenmoor style (chunky beveled boxes, no terrain).

Styles, (root, rng, w, d, storeys) -> [parts]: house, boarding, shed, warehouse, stack.
Landmarks, (root, rng) -> [parts]: practice_court, foundry_hall, crane_bay, rail_walk, underworks, canteen,
market_stall.

Each piece builds into a prefab root (an Empty the caller has placed) in the root's LOCAL frame: the origin is the
middle of the footprint at floor level, +z is up, and the FRONT (street side, front door, gate) faces local -y. Local
-y is the Roblox LookVector (export.py maps Blender local y to Roblox Z), so a prefab turned to a Roblox yaw faces
that way, as a marker's Yaw does; at yaw 0 the front faces north. 1 unit = 1 stud. Parts are lindenmoor.core's box
and cyl, plus wedges in world.wedge's pattern, in the region palette (bind() first). Every size here is a PROPOSAL.

The caller may set root["rs_party"] = "L", "R" or "LR" before a house or boarding house is built: the sides (local -x,
+x) where a neighbour shares the wall. Those sides get no overhangs (so roofs butt cleanly) and no ledge; the free
sides of a two-storey or taller building get a ledge strip at the first floor.

Traversal, as the movement code reads it (Task 10 report has the line references):
  * RenseiLedge (TuningConfig.LedgeWalk.Tag, read by JumpManager/LedgeWalk.lua and MovementState.lua): the tag only;
    no attribute is read. The part's top face is the foothold, Size.X is the path, its FRONT face (LookVector,
    Blender local -y) points AT the wall, and it is level. Ye's ledges are 1 tall x 1.4 deep; so are these (ledge()).
    A "Note" attribute describes it, as Ye's ledges carry one.
  * Climbing and wall-running need no tag or attribute: JumpManager raycasts against everything under
    workspace.World.Map (the grab ray ahead, the wall-run ray WallRunReach to the side) and the server's check
    (MovementState WallInReach) wants a face with |Normal.Y| < 0.7. So any solid upright face of the map works.
    Crane legs and rail-walk fascias stay plain parts; their Note says they are meant for climbing / wall-running."""
import json, math, zlib

import bpy

from lindenmoor.core import box, cyl, srgb

M = {}  # the region palette: {key: material}; set by bind()
SH = 10  # studs per storey (PROPOSAL: R6 is 5 tall; Lindenmoor's ground floor is about 10)
LEDGE = (1.4, 1.0)  # ledge strip depth and height, as Ye's RenseiLedge parts
LEDGE_NOTE = "Authored ledge (RenseiLedge): front face toward the wall, Size.X = the path"
CLIMB_NOTE = "Climbable and wall-runnable: the climb and wall-run rays hit any World.Map face; no tag needed"


def bind(palette):
    M.clear()
    M.update(palette)


# ------------------------------------------------------------------ primitives in a prefab's local frame
def _col(root):
    return root.users_collection[0]


def pb(root, name, size, loc, mat, rot=(0, 0, 0), bevel=0.1):
    """A Block part of root at local loc."""
    o = box(f"{root.name}_{name}", size, loc, M[mat], _col(root), rot=rot, bevel=bevel, segs=1)
    o.parent = root
    return o


def pc(root, name, r, h, loc, mat, rot=(0, 0, 0), verts=12):
    """A Cylinder part (axis = Blender local z before rot)."""
    o = cyl(f"{root.name}_{name}", r, h, loc, M[mat], _col(root), verts=verts, rot=rot)
    o.parent = root
    return o


def pw(root, name, size, loc, mat, rot=(0, 0, 0)):
    """A WedgePart (world.wedge's pattern): full height at local +y (Roblox back, +Z), sloping down toward -y."""
    o = box(f"{root.name}_{name}", size, loc, M[mat], _col(root), rot=rot, bevel=0)
    for v in o.data.vertices:
        if v.co.y < 0 and v.co.z > 0:
            v.co.z = -size[2] / 2
    o["rs_kind"] = "Wedge"
    o.parent = root
    return o


def light(root, name, loc, energy, colour, rng):
    """A point light (export.py writes it; studio_kit puts it in the nearest Neon part)."""
    L = bpy.data.lights.new(f"{root.name}_{name}", "POINT")
    L.energy = energy
    L.color = srgb(colour)
    L.shadow_soft_size = 0.5
    o = bpy.data.objects.new(f"{root.name}_{name}", L)
    o.location = loc
    o["rs_light"] = "POINT"
    o["rs_range"] = rng
    _col(root).objects.link(o)
    o.parent = root
    return o


def tag(o, *tags):
    have = [t for t in str(o.get("rs_tags", "")).split(",") if t]
    o["rs_tags"] = ",".join(have + [t for t in tags if t not in have])
    return o


def attr(o, **kv):
    d = json.loads(o.get("rs_attr") or "{}")
    d.update(kv)
    o["rs_attr"] = json.dumps(d)
    return o


def _yaw_to(dx, dy):
    """The z rotation that turns local -y (a part's Roblox front) toward the local direction (dx, dy)."""
    return math.atan2(dx, -dy)


def ledge(root, name, face, length, wall, mat="stone"):
    """A RenseiLedge strip whose back face lies on a wall: face = (x, y, top) a point on the wall face at the strip's
    middle and the height of its top; wall = the unit direction (dx, dy) from the strip into the wall."""
    x, y, top = face
    dep, hgt = LEDGE
    o = pb(root, name, (length, dep, hgt), (x - wall[0] * dep / 2, y - wall[1] * dep / 2, top - hgt / 2), mat,
           rot=(0, 0, _yaw_to(*wall)), bevel=0.05)
    tag(o, "RenseiLedge")
    attr(o, Note=LEDGE_NOTE)
    return o


def lamp(root, name, x, y, z=0.0, h=10.0, energy=3600, rng=22):
    """A street lamp (PROPOSAL look: a lantern on an iron post). Its Neon glow carries NightOnly = true, the
    WorldClock lamp rule, and a light sits in it. 5 parts + 1 light, all within 1.6 x 1.6."""
    P = [pb(root, f"{name}Base", (1.6, 1.6, 1.0), (x, y, z + 0.5), "stone", bevel=0.12),
         pb(root, f"{name}Post", (0.6, 0.6, h), (x, y, z + 1.0 + h / 2 - 0.5), "iron", bevel=0.05),
         pb(root, f"{name}Collar", (1.2, 1.2, 0.4), (x, y, z + h + 0.7), "iron", bevel=0.05)]
    g = pb(root, f"{name}Glow", (1.0, 1.0, 1.4), (x, y, z + h + 1.6), "lamp", bevel=0.08)
    attr(g, NightOnly=True)
    P += [g, pb(root, f"{name}Cap", (1.6, 1.6, 0.4), (x, y, z + h + 2.5), "soot", bevel=0.06)]
    light(root, f"{name}Light", (x, y, z + h + 1.6), energy, "ffb35c", rng)
    return P


# ------------------------------------------------------------------ walls, windows, doors
# a wall side: (along-axis unit, outward normal) in local (x, y); the front is -y
SIDES = {"F": ((1, 0), (0, -1)), "B": ((1, 0), (0, 1)), "L": ((0, 1), (-1, 0)), "R": ((0, 1), (1, 0))}


def _on(side, half, a, off, o=(0, 0)):
    """Local (x, y) of the point `a` along a side's wall, `off` out from its face (the face is `half` from o)."""
    (ux, uy), (nx, ny) = SIDES[side]
    return o[0] + ux * a + nx * (half + off), o[1] + uy * a + ny * (half + off)


def _sz(side, along, thick, h):
    return (along, thick, h) if side in "FB" else (thick, along, h)


def window(root, name, side, half, a, z, w=2.6, h=4.4, o=(0, 0), sill=True):
    """A warm window on a wall face: glass, a stone lintel and (optionally) a sill. 2-3 parts."""
    P = [pb(root, f"{name}Glass", _sz(side, w, 0.3, h), (*_on(side, half, a, 0.05, o), z), "window", bevel=0.02),
         pb(root, f"{name}Lintel", _sz(side, w + 1.0, 0.5, 0.7), (*_on(side, half, a, 0.15, o), z + h / 2 + 0.35),
            "stone", bevel=0.06)]
    if sill:
        P.append(pb(root, f"{name}Sill", _sz(side, w + 0.8, 0.6, 0.35), (*_on(side, half, a, 0.2, o), z - h / 2 - 0.18),
                    "stone", bevel=0.05))
    return P


def door(root, name, side, half, a, z0=0.8, w=3.6, h=7.2, o=(0, 0), mat="timber"):
    """A door on a wall face: the leaf and a stone lintel, and a step in front of it. 3 parts."""
    return [pb(root, f"{name}Leaf", _sz(side, w, 0.4, h), (*_on(side, half, a, 0.1, o), z0 + h / 2), mat, bevel=0.05),
            pb(root, f"{name}Lintel", _sz(side, w + 1.4, 0.6, 0.8), (*_on(side, half, a, 0.2, o), z0 + h + 0.4),
               "stone", bevel=0.06),
            pb(root, f"{name}Step", _sz(side, w + 1.0, 1.2, z0), (*_on(side, half, a, 0.6, o), z0 / 2), "stone",
               bevel=0.06)]


def _bays(w, bay):
    n = max(1, int(round(w / bay)))
    return [-w / 2 + (i + 0.5) * w / n for i in range(n)]


def _block(root, rng, w, d, storeys, sh=SH, o=(0, 0), wall="brick", roof="slate", door_x=None, back_door=True,
           chimneys=1, bay=5.0, back_every=1, ledges=True):
    """A brick block with a pitched roof, the ridge along x (the street): the house, boarding house and canteen body.
    Returns (parts, front door x). Party sides (root["rs_party"]) get no overhang and no ledge."""
    party = str(root.get("rs_party", ""))
    el, er = (0 if "L" in party else 1), (0 if "R" in party else 1)  # 1 where a side is free

    def span(ext):
        """(width, x centre) of a piece reaching `ext` past each FREE side wall."""
        return w + ext * (el + er), o[0] + ext * (er - el) / 2

    ox, oy = o
    H = storeys * sh
    P = []
    ww, cx = span(0.3)
    P.append(pb(root, "PlinthCourse", (ww, d + 0.6, 0.8), (cx, oy, 0.4), "stone", bevel=0.08))
    P.append(pb(root, "Body", (w, d, H), (ox, oy, H / 2), wall, bevel=0.06))
    ww, cx = span(0.2)
    for k in range(1, storeys):
        for side in "FB":
            P.append(pb(root, f"Band{side}{k}", (ww, 0.4, 0.6), (cx, _on(side, d / 2, 0, 0.2, o)[1], k * sh),
                        "brick_dark", bevel=0.04))
    ww, cx = span(0.4)
    P.append(pb(root, "Cornice", (ww, d + 0.8, 0.8), (cx, oy, H + 0.4), "brick_dark", bevel=0.06))
    # roof
    over = 0.8
    half = d / 2 + over
    rise = round(d * 0.33, 1)  # PROPOSAL: about a 34-degree pitch
    ang, slope = math.atan2(rise, half), math.hypot(half, rise)
    base = H + 0.8
    rmat = "slate_roof" if roof == "slate" else "iron_roof"
    rw, rcx = span(0.6)

    def on_slab(s, t, off):
        """Local (y, z) at fraction t from the ridge (0) to the eave (1) on slab side s, `off` above its middle."""
        return oy + s * half * t + s * math.sin(ang) * off, base + rise * (1 - t) + math.cos(ang) * off

    for s in (-1, 1):
        y, z = on_slab(s, 0.5, 0)
        P.append(pb(root, f"Roof{'FB'[s > 0]}", (rw, slope, 0.8), (rcx, y, z), rmat, rot=(-s * ang, 0, 0), bevel=0.06))
        if roof == "slate":
            for r in range(3):
                y, z = on_slab(s, (r + 0.5) / 3, 0.5)
                P.append(pb(root, f"Course{'FB'[s > 0]}{r}", (rw - 0.2, slope / 3 + 0.1, 0.3), (rcx, y, z),
                            "slate_roof", rot=(-s * ang, 0, 0), bevel=0.08))
        else:
            y, z = on_slab(s, 0.5, 0.5)
            for i, x in enumerate(_bays(w, 2.4)):
                P.append(pb(root, f"Rib{'FB'[s > 0]}{i}", (0.3, slope, 0.25), (ox + x, y, z), "iron_roof",
                            rot=(-s * ang, 0, 0), bevel=0))
        ra = rise * (d / 2) / half  # the attic's height under the slab
        P.append(pw(root, f"Gable{'FB'[s > 0]}", (w, d / 2, ra), (ox, oy + s * d / 4, base + ra / 2), wall,
                    rot=(0, 0, 0 if s < 0 else math.pi)))
    P.append(pb(root, "Ridge", (rw + 0.2, 1.0, 0.6), (rcx, oy, base + rise + 0.25), "soot", bevel=0.06))
    # chimneys on the gable ends (on the party wall when there is one, as terraces have)
    ends = [-1, 1] if chimneys > 1 else [rng.choice((-1, 1))]
    for e in ends:
        x = ox + e * (w / 2 - 1.3)
        ch = rise + 4.5
        P.append(pb(root, f"Chimney{e:+d}", (2.6, 2.6, ch), (x, oy, base + ch / 2), "brick_dark", bevel=0.08))
        P.append(pb(root, f"ChimneyCap{e:+d}", (3.2, 3.2, 0.6), (x, oy, base + ch + 0.3), "soot", bevel=0.06))
        for p in (-1, 1):
            P.append(pc(root, f"Pot{e:+d}{p:+d}", 0.45, 1.6, (x + p * 0.65, oy, base + ch + 1.4), "soot", verts=8))
    # doors and windows
    xs = _bays(w, bay)
    if door_x is None:
        door_x = rng.choice(xs)
    P += door(root, "Door", "F", d / 2, door_x, o=o)
    for k in range(storeys):
        for i, x in enumerate(xs):
            if k == 0 and abs(x - door_x) < 3.2:
                continue
            P += window(root, f"WinF{k}{i}", "F", d / 2, x, k * sh + 5.0, o=o)
    bx = None
    if back_door:
        bx = min(xs, key=lambda x: (abs(x + door_x), x))  # across from the front door
        P += door(root, "BackDoor", "B", d / 2, bx, o=o, w=3.2, h=7.0)
    for k in range(storeys):
        for i, x in enumerate(xs):
            if i % back_every or (k == 0 and bx is not None and abs(x - bx) < 3.2):
                continue
            P += window(root, f"WinB{k}{i}", "B", d / 2, x, k * sh + 5.0, o=o, sill=False)
    # ledges on the free gable walls, at the first floor (two storeys or more)
    if ledges and storeys >= 2:
        for side, free in (("L", el), ("R", er)):
            if free:
                fx, fy = _on(side, w / 2, 0, 0, o)
                P.append(ledge(root, f"Ledge{side}", (fx, fy, sh), d - 2, (-SIDES[side][1][0], -SIDES[side][1][1])))
    return P, door_x


# ------------------------------------------------------------------ styles: (root, rng, w, d, storeys) -> parts
def house(root, rng, w, d, storeys):
    """A brick terrace house: slate or iron roof, a chimney on a gable end, warm windows, a front and a back door."""
    roof = "slate" if rng.random() < 0.65 else "iron"
    wall = "brick" if rng.random() < 0.7 else "brick_dark"
    P, dx = _block(root, rng, w, d, storeys, wall=wall, roof=roof)
    root["rs_door_x"] = dx
    party = str(root.get("rs_party", ""))
    side = 1 if dx < 0 else -1  # a downpipe at a front corner: away from the door, but never at a party wall
    if ("R" if side > 0 else "L") in party and ("L" if side > 0 else "R") not in party:
        side = -side
    x = (w / 2 - 0.5) * side
    P.append(pb(root, "Downpipe", (0.5, 0.5, storeys * SH), (x, -d / 2 - 0.3, storeys * SH / 2), "iron", bevel=0))
    return P


def boarding(root, rng, w, d, storeys):
    """A long three-storey boarding house (always 3 storeys): a central door under an iron canopy, a name board,
    chimneys at both ends, windows on every bay at the front and every other bay at the back."""
    P, dx = _block(root, rng, w, d, 3, roof="slate", door_x=min(_bays(w, 5.0), key=lambda x: (abs(x), x)), chimneys=2,
                   back_every=2)
    root["rs_door_x"] = dx
    y = -d / 2
    P.append(pb(root, "Canopy", (7.0, 2.8, 0.4), (dx, y - 1.4, 9.4), "iron", rot=(math.radians(8), 0, 0), bevel=0.05))
    for s in (-1, 1):
        P.append(pb(root, f"Bracket{s:+d}", (0.3, 2.4, 0.3), (dx + s * 3.0, y - 1.2, 8.9), "iron", bevel=0))
    P.append(pb(root, "NameBoard", (10.0, 0.4, 1.4), (dx, y - 0.25, SH + 1.2), "timber", bevel=0.05))
    return P


def shed(root, rng, w, d, storeys):
    """A corrugated iron shed: ribbed walls, a shallow ribbed roof, a sliding door. One storey (storeys ignored)."""
    h = 8.0
    P = [pb(root, "Plinth", (w + 0.4, d + 0.4, 0.6), (0, 0, 0.3), "stone", bevel=0.06),
         pb(root, "Body", (w, d, h), (0, 0, h / 2), "iron_roof", bevel=0.04)]
    for side, half, length, every in (("F", d / 2, w, 2.0), ("B", d / 2, w, 2.0), ("L", w / 2, d, 3.0),
                                      ("R", w / 2, d, 3.0)):
        for i, a in enumerate(_bays(length - 1, every)):
            P.append(pb(root, f"Rib{side}{i}", _sz(side, 0.3, 0.3, h - 0.6), (*_on(side, half, a, 0.1), h / 2 + 0.3),
                        "rust", bevel=0))
    rise, over = round(d * 0.15, 1), 0.8
    half = d / 2 + over
    ang, slope = math.atan2(rise, half), math.hypot(half, rise)
    for s in (-1, 1):
        sy, sz_ = s * half / 2, h + 0.4 + rise / 2
        P.append(pb(root, f"Roof{'FB'[s > 0]}", (w + 1.2, slope, 0.5), (0, sy, sz_), "iron_roof", rot=(-s * ang, 0, 0),
                    bevel=0.04))
        for i, x in enumerate(_bays(w, 2.5)):
            P.append(pb(root, f"RoofRib{'FB'[s > 0]}{i}", (0.3, slope, 0.2),
                        (x, sy + s * math.sin(ang) * 0.35, sz_ + math.cos(ang) * 0.35), "iron_roof",
                        rot=(-s * ang, 0, 0), bevel=0))
        ra = rise * (d / 2) / half
        P.append(pw(root, f"Gable{'FB'[s > 0]}", (w, d / 2, ra), (0, s * d / 4, h + ra / 2), "iron_roof",
                    rot=(0, 0, 0 if s < 0 else math.pi)))
    dw = min(8.0, w * 0.45)
    P.append(pb(root, "Opening", (dw - 1, 0.2, 6.6), (0, -d / 2 - 0.05, 3.9), "soot", bevel=0))
    P.append(pb(root, "SlideDoor", (dw, 0.4, 6.8), (-dw * 0.55, -d / 2 - 0.45, 4.0), "rust", bevel=0.04))
    P.append(pb(root, "DoorRail", (dw * 2.1, 0.4, 0.4), (-dw * 0.3, -d / 2 - 0.45, 7.7), "iron", bevel=0))
    root["rs_door_x"] = 0.0
    return P


def warehouse(root, rng, w, d, storeys):
    """A brick warehouse: pilasters, a parapet round a flat roof, loading doors stacked up the middle bay under a
    hoist beam, and a loading dock. 12-stud storeys."""
    sh = 12.0
    H = storeys * sh
    P = [pb(root, "PlinthCourse", (w + 0.6, d + 0.6, 0.8), (0, 0, 0.4), "stone", bevel=0.08),
         pb(root, "Body", (w, d, H), (0, 0, H / 2), "brick", bevel=0.06),
         pb(root, "Roof", (w - 0.4, d - 0.4, 0.6), (0, 0, H + 0.3), "soot", bevel=0)]
    for side, half, length in (("F", d / 2, w), ("B", d / 2, w), ("L", w / 2, d), ("R", w / 2, d)):
        P.append(pb(root, f"Parapet{side}", _sz(side, length + (1.0 if side in "FB" else 0), 1.0, 1.8),
                    (*_on(side, half, 0, -0.5), H + 0.9), "brick_dark", bevel=0.06))
    xs = _bays(w, 6.0)
    mid = min(range(len(xs)), key=lambda i: abs(xs[i]))
    for side in "FB":
        for i in range(len(xs) + 1):
            a = -w / 2 + i * w / len(xs)
            P.append(pb(root, f"Pilaster{side}{i}", _sz(side, 1.2, 0.5, H), (*_on(side, d / 2, a, 0.25), H / 2),
                        "brick_dark", bevel=0.05))
    for k in range(storeys):
        for i, x in enumerate(xs):
            if i == mid:
                continue
            P += window(root, f"WinF{k}{i}", "F", d / 2, x, k * sh + 6.5, w=2.4, h=3.6)
            if i % 2 == 0:
                P += window(root, f"WinB{k}{i}", "B", d / 2, x, k * sh + 6.5, w=2.4, h=3.6, sill=False)
    x = xs[mid]
    P.append(pb(root, "BigDoor", (7.0, 0.4, 9.0), (x, -d / 2 - 0.1, 1.4 + 4.5), "timber", bevel=0.05))
    for k in range(1, storeys):
        P.append(pb(root, f"LoadDoor{k}", (4.6, 0.4, 7.0), (x, -d / 2 - 0.1, k * sh + 4.0), "timber", bevel=0.05))
        P.append(pb(root, f"LoadLintel{k}", (6.0, 0.6, 0.8), (x, -d / 2 - 0.2, k * sh + 7.9), "stone", bevel=0.06))
    P.append(pb(root, "HoistBeam", (0.8, 3.6, 0.8), (x, -d / 2 - 1.6, H - 1.2), "iron", bevel=0.04))
    P.append(pc(root, "HoistChain", 0.15, 5.0, (x, -d / 2 - 3.0, H - 4.1), "iron", verts=6))
    P.append(pb(root, "HoistHook", (0.8, 0.8, 1.0), (x, -d / 2 - 3.0, H - 7.0), "iron", bevel=0.05))
    P.append(pb(root, "Dock", (12.0, 3.6, 1.4), (x, -d / 2 - 1.8, 0.7), "stone", bevel=0.1))
    root["rs_door_x"] = x
    return P


def stack(root, rng, w, d, storeys):
    """A brick smokestack on a square base: iron bands, a soot-black crown. Taller with more storeys."""
    b = min(w, d)
    r = round(b * 0.33, 2)
    H = 30.0 + 8.0 * storeys  # PROPOSAL
    P = [pb(root, "Base", (b, b, 6.0), (0, 0, 3.0), "brick_dark", bevel=0.1),
         pb(root, "BaseCap", (b + 0.6, b + 0.6, 0.8), (0, 0, 6.4), "stone", bevel=0.08),
         pc(root, "Shaft", r, H, (0, 0, 6.8 + H / 2), "brick", verts=16)]
    for k, f in enumerate((0.3, 0.6, 0.85)):
        P.append(pc(root, f"Band{k}", r + 0.15, 0.6, (0, 0, 6.8 + H * f), "iron", verts=16))
    P.append(pc(root, "Crown", r + 0.4, 2.0, (0, 0, 6.8 + H + 0.6), "soot", verts=16))
    return P


# ------------------------------------------------------------------ landmarks: (root, rng) -> parts
def practice_court(root, rng):
    """Brannoc's practice court: a brick ring wall about 38 studs across, its gate to the front (-y) between two
    piers carrying NightOnly lamps, a cinder floor, four benches against the wall, two practice posts and a weapon
    rack."""
    R, T, Hw, nseg = 18.0, 1.6, 5.0, 20  # PROPOSAL
    P = [pc(root, "Floor", R - T / 2, 0.4, (0, 0, 0.2), "cinder_dark", verts=24)]
    seg = 2 * R * math.tan(math.pi / nseg) + 0.3
    gate = []
    for k in range(nseg):
        phi = math.radians(-90 + (k + 0.5) * 360 / nseg)
        if abs((math.degrees(phi) + 90 + 180) % 360 - 180) < 360 / nseg:  # the 2 segments either side of the front
            gate.append(phi)
            continue
        x, y, rot = R * math.cos(phi), R * math.sin(phi), (0, 0, phi + math.pi / 2)
        P.append(pb(root, f"Wall{k}", (seg, T, Hw), (x, y, Hw / 2), "brick", rot=rot, bevel=0.08))
        P.append(pb(root, f"Coping{k}", (seg + 0.1, T + 0.6, 0.5), (x, y, Hw + 0.25), "stone", rot=rot, bevel=0.06))
    for s, phi in zip((-1, 1), (math.radians(-90 - 360 / nseg), math.radians(-90 + 360 / nseg))):
        x, y = R * math.cos(phi), R * math.sin(phi)
        P.append(pb(root, f"Pier{s:+d}", (2.6, 2.6, Hw + 2), (x, y, (Hw + 2) / 2), "brick_dark", bevel=0.1))
        P.append(pb(root, f"PierCap{s:+d}", (3.2, 3.2, 0.6), (x, y, Hw + 2.3), "stone", bevel=0.06))
        P += lamp(root, f"Lamp{s:+d}", x, y, z=Hw + 2.6, h=2.5, energy=3000, rng=20)
    for k, deg in enumerate((20, 70, 110, 160)):  # benches round the back half, facing the middle
        phi = math.radians(deg)
        rr = R - T / 2 - 1.2
        x, y, rot = rr * math.cos(phi), rr * math.sin(phi), (0, 0, phi + math.pi / 2)
        P.append(pb(root, f"Bench{k}Seat", (5.0, 1.4, 0.35), (x, y, 1.9), "timber", rot=rot, bevel=0.05))
        for s in (-1, 1):
            lx, ly = x + s * 1.9 * -math.sin(phi), y + s * 1.9 * math.cos(phi)
            P.append(pb(root, f"Bench{k}Leg{s:+d}", (0.4, 1.2, 1.75), (lx, ly, 0.875), "timber", rot=rot, bevel=0.03))
    for s in (-1, 1):  # practice posts
        P.append(pb(root, f"Pell{s:+d}", (1.2, 1.2, 6.0), (s * 6.0, 4.0, 3.0), "timber", bevel=0.08))
        P.append(pb(root, f"PellBand{s:+d}", (1.5, 1.5, 0.4), (s * 6.0, 4.0, 4.6), "iron", bevel=0.04))
    phi = math.radians(-20)  # a weapon rack against the wall, front right
    rr = R - T / 2 - 0.6
    x, y, rot = rr * math.cos(phi), rr * math.sin(phi), (0, 0, phi + math.pi / 2)
    tx, ty = -math.sin(phi), math.cos(phi)
    for s in (-1, 1):
        P.append(pb(root, f"Rack{s:+d}", (0.5, 0.5, 4.0), (x + s * 1.8 * tx, y + s * 1.8 * ty, 2.0), "timber", rot=rot,
                    bevel=0.03))
    P.append(pb(root, "RackRail", (4.2, 0.4, 0.4), (x, y, 3.4), "timber", rot=rot, bevel=0.03))
    for i in (-1, 0, 1):
        P.append(pb(root, f"Staff{i:+d}", (0.25, 0.25, 4.4), (x + i * 0.9 * tx, y + i * 0.9 * ty, 2.3), "timber",
                    rot=(0, math.radians(8), phi + math.pi / 2), bevel=0))
    return P


def foundry_hall(root, rng):
    """The foundry hall: a 96 x 64 brick hall, 28 tall, with a sawtooth roof glazed to the north (front), a great
    doorway, pilasters, three furnaces with ember-lit mouths and flues against the back wall, gantries along both
    side walls joined by a bridge, a stair up to them, and an open stone floor."""
    W, D, Hw, T = 96.0, 64.0, 28.0, 2.0  # PROPOSAL
    P = [pb(root, "Floor", (W - 2 * T, D - 2 * T, 0.4), (0, 0, 0.2), "stone", bevel=0)]
    dw, dh = 18.0, 20.0  # the doorway
    side_w = (W - dw) / 2
    for s in (-1, 1):
        P.append(pb(root, f"Front{s:+d}", (side_w, T, Hw), (s * (dw / 2 + side_w / 2), -D / 2 + T / 2, Hw / 2), "brick",
                    bevel=0.08))
    P.append(pb(root, "FrontLintel", (dw, T, Hw - dh), (0, -D / 2 + T / 2, dh + (Hw - dh) / 2), "brick", bevel=0.08))
    P.append(pb(root, "Back", (W, T, Hw), (0, D / 2 - T / 2, Hw / 2), "brick", bevel=0.08))
    for s in (-1, 1):
        x = s * (W / 2 - T / 2)
        P.append(pb(root, f"Side{s:+d}", (T, D - 2 * T, 17.0), (x, 0, 8.5), "brick", bevel=0.08))
        # (not "...Glass": studio_kit makes parts named *Glass* non-colliding, and this band is beside the gantries)
        P.append(pb(root, f"SideLights{s:+d}", (0.6, D - 2 * T - 1, 6.0), (x, 0, 20.0), "window", bevel=0))
        P.append(pb(root, f"SideTop{s:+d}", (T, D - 2 * T, 5.0), (x, 0, 25.5), "brick", bevel=0.08))
        for i in range(4):
            P.append(pb(root, f"Mullion{s:+d}{i}", (T + 0.2, 0.8, 6.0), (x, -D / 2 + T + (i + 1) * (D - 2 * T) / 5, 20.0),
                        "brick_dark", bevel=0.03))
    for side in "FB":  # pilasters
        for i in range(9):
            a = -W / 2 + i * W / 8
            if side == "F" and abs(a) < dw / 2 + 1:
                continue
            P.append(pb(root, f"Pilaster{side}{i}", _sz(side, 1.6, 0.8, Hw + 1.0), (*_on(side, D / 2, a, 0.4), (Hw + 1) / 2),
                        "brick_dark", bevel=0.06))
    teeth, rise = 8, 5.0  # sawtooth: each tooth glazed on its north (front) face
    p = D / teeth
    ang = math.atan2(rise, p)
    for j in range(teeth):
        y0 = -D / 2 + j * p
        P.append(pb(root, f"Tooth{j}", (W + 1.0, math.hypot(p, rise), 0.6), (0, y0 + p / 2, Hw + rise / 2), "iron_roof",
                    rot=(-ang, 0, 0), bevel=0.04))
        P.append(pb(root, f"Glazing{j}", (W - 2 * T, 0.4, rise), (0, y0, Hw + rise / 2), "glass_warm", bevel=0))
        for s in (-1, 1):
            P.append(pw(root, f"ToothEnd{j}{s:+d}", (T, p, rise), (s * (W / 2 - T / 2), y0 + p / 2, Hw + rise / 2),
                        "brick", rot=(0, 0, math.pi)))
    for k, x in enumerate((-30.0, 0.0, 30.0)):  # furnaces against the back wall
        fy = D / 2 - T - 4.0
        P.append(pb(root, f"Furnace{k}", (12.0, 8.0, 14.0), (x, fy, 7.0), "brick_dark", bevel=0.12))
        P.append(pb(root, f"Mouth{k}", (5.0, 0.5, 4.5), (x, fy - 4.1, 3.0), "ember", bevel=0.05))
        P.append(pb(root, f"MouthLintel{k}", (7.0, 0.8, 1.0), (x, fy - 4.3, 5.8), "iron", bevel=0.04))
        P.append(pc(root, f"Flue{k}", 1.8, Hw - 2.0, (x, fy, 14.0 + (Hw - 2.0) / 2), "brick_dark", verts=12))
        P.append(pc(root, f"FlueCap{k}", 2.2, 1.0, (x, fy, Hw + 12.5), "soot", verts=12))
        light(root, f"Ember{k}", (x, fy - 6.0, 3.5), 4500, "e0782a", 26)
    gz = 14.0  # gantries along both side walls
    gl = D - 2 * T - 4
    for s in (-1, 1):
        x = s * (W / 2 - T - 2.5)
        P.append(pb(root, f"Gantry{s:+d}", (4.0, gl, 0.6), (x, 0, gz - 0.3), "iron", bevel=0.03))
        for i, y in enumerate((-24.0, -10.0, 4.0, 18.0)):
            P.append(pb(root, f"GantryPost{s:+d}{i}", (0.8, 0.8, gz - 0.6), (x - s * 1.6, y, (gz - 0.6) / 2), "iron",
                        bevel=0.03))
        P.append(pb(root, f"GantryToe{s:+d}", (0.2, gl, 0.8), (x - s * 1.9, 0, gz + 0.4), "iron", bevel=0))
        P.append(pb(root, f"GantryRail{s:+d}", (0.3, gl, 0.3), (x - s * 1.9, 0, gz + 3.3), "iron", bevel=0))
    bl = W - 2 * T - 10
    P.append(pb(root, "Bridge", (bl, 4.0, 0.6), (0, -6.0, gz - 0.3), "iron", bevel=0.03))
    for s in (-1, 1):
        P.append(pb(root, f"BridgeRail{s:+d}", (bl, 0.3, 0.3), (0, -6.0 + s * 1.9, gz + 3.3), "iron", bevel=0))
    for k in range(1, int(gz) + 1):  # a stair up to the west gantry along the inside of the front wall: 1-stud risers
        top = float(k)
        P.append(pb(root, f"Stair{k}", (1.85, 4.0, top), (-16.0 - 1.8 * (k - 0.5), -D / 2 + T + 2.5, top / 2), "iron",
                    bevel=0.03))
    for s in (-1, 1):
        P += lamp(root, f"Lamp{s:+d}", s * (dw / 2 + 3.0), -D / 2 - 2.0)
    return P


def crane_bay(root, rng):
    """A gantry crane: two portal frames on ground rails (legs climbable: plain faces, with a Note), a walkable
    4.4-wide girder with handrails, a trolley, hook and load, an operator's cab and ladder rungs up one leg."""
    lx, ly, lh = 20.0, 10.0, 23.3  # PROPOSAL
    P = []
    for s in (-1, 1):
        P.append(pb(root, f"CraneRail{s:+d}", (0.6, 30.0, 0.5), (s * lx, 0, 0.25), "iron", bevel=0))
        for t in (-1, 1):
            P.append(pb(root, f"Bogie{s:+d}{t:+d}", (3.0, 4.0, 1.2), (s * lx, t * ly, 1.1), "iron", bevel=0.06))
            leg = pb(root, f"Leg{s:+d}{t:+d}", (2.4, 2.4, lh), (s * lx, t * ly, 1.7 + lh / 2), "iron", bevel=0.05)
            attr(leg, Note=CLIMB_NOTE)
            P.append(leg)
        P.append(pb(root, f"Portal{s:+d}", (3.0, 2 * ly + 3.4, 2.4), (s * lx, 0, 1.7 + lh + 1.2), "iron", bevel=0.05))
        L = math.hypot(ly, 12.0)
        for t in (-1, 1):
            P.append(pb(root, f"Brace{s:+d}{t:+d}", (0.8, L, 0.8), (s * lx, t * ly / 2, 1.7 + lh - 6.0), "iron",
                        rot=(-t * math.atan2(12.0, ly), 0, 0), bevel=0.03))
    gt = 1.7 + lh + 2.4  # girder bottom
    P.append(pb(root, "Girder", (2 * lx + 6.0, 4.4, 2.4), (0, 0, gt + 1.2), "rust", bevel=0.05))
    for s in (-1, 1):
        P.append(pb(root, f"Handrail{s:+d}", (2 * lx + 6.0, 0.25, 0.25), (0, s * 2.0, gt + 2.4 + 3.0), "iron", bevel=0))
        for i, x in enumerate((-lx - 2.0, -lx / 2, lx / 2, lx + 2.0)):
            P.append(pb(root, f"Stanchion{s:+d}{i}", (0.25, 0.25, 3.0), (x, s * 2.0, gt + 2.4 + 1.5), "iron", bevel=0))
    tx = 6.0
    P.append(pb(root, "Trolley", (5.0, 5.4, 2.4), (tx, 0, gt + 2.4 + 1.2), "iron", bevel=0.06))
    P.append(pc(root, "Drum", 1.0, 4.0, (tx, 0, gt + 2.4 + 3.4), "iron", rot=(0, math.radians(90), 0), verts=12))
    P.append(pc(root, "Cable", 0.15, 12.0, (tx, 0, gt - 6.0), "iron", verts=6))
    P.append(pb(root, "HookBlock", (1.4, 1.4, 1.8), (tx, 0, gt - 12.9), "rust", bevel=0.06))
    for i in range(2):
        P.append(pb(root, f"Load{i}", (3.0, 3.0, 3.0), (tx + (i - 0.5) * 3.1, 0, 1.5), "crate", bevel=0.08))
    P.append(pb(root, "Cab", (3.6, 3.6, 3.4), (-lx + 5.0, -3.6, gt - 1.7), "iron", bevel=0.06))
    P.append(pb(root, "CabGlass", (3.0, 0.3, 1.6), (-lx + 5.0, -5.45, gt - 1.4), "window", bevel=0))
    for i in range(10):  # rungs up the front face of one leg
        P.append(pb(root, f"Rung{i}", (1.6, 0.3, 0.3), (lx, -ly - 1.35, 3.5 + i * 2.2), "iron", bevel=0))
    return P


def rail_walk(root, rng):
    """A raised iron walkway on trestles (deck top 14): plate-girder fascias down both sides (wall-runnable faces),
    a RenseiLedge strip along the foot of each fascia (shimmy along the side, out of sight of the deck), railings,
    and a stair down at the +x end."""
    L, Wd, top = 44.0, 6.0, 14.0  # PROPOSAL
    fh = 5.0
    P = [pb(root, "Deck", (L, Wd, 0.6), (0, 0, top - 0.3), "iron", bevel=0.03)]
    for s in (-1, 1):
        f = pb(root, f"Fascia{s:+d}", (L, 0.6, fh), (0, s * (Wd / 2 + 0.3), top - fh / 2), "iron", bevel=0.04)
        attr(f, Note=CLIMB_NOTE)
        P.append(f)
        P.append(ledge(root, f"Ledge{s:+d}", (0, s * (Wd / 2 + 0.6), top - fh), L - 2.0, (0, -s), mat="iron"))
        for i in range(6):
            P.append(pb(root, f"RailPost{s:+d}{i}", (0.35, 0.35, 3.2), (-L / 2 + 2.0 + i * 8.0, s * (Wd / 2 - 0.2),
                                                                         top + 1.6), "iron", bevel=0))
        P.append(pb(root, f"Rail{s:+d}", (L, 0.3, 0.3), (0, s * (Wd / 2 - 0.2), top + 3.3), "iron", bevel=0))
    lh = top - fh
    for k, x in enumerate((-16.0, 0.0, 16.0)):
        for s in (-1, 1):
            P.append(pb(root, f"Trestle{k}{s:+d}", (0.9, 0.9, lh), (x, s * 2.4, lh / 2), "iron", bevel=0.03))
        P.append(pb(root, f"Tie{k}", (0.6, 5.4, 0.7), (x, 0, 4.0), "iron", bevel=0))
        P.append(pb(root, f"Brace{k}", (0.5, math.hypot(4.8, lh - 1), 0.5), (x, 0, lh / 2), "iron",
                    rot=(math.atan2(lh - 1, 4.8), 0, 0), bevel=0))
        P.append(pb(root, f"Footing{k}", (2.4, 6.4, 0.6), (x, 0, 0.3), "stone", bevel=0.06))
    for j in range(13):  # down from the deck at +x: 1-stud risers
        t = top - 1.0 - j
        P.append(pb(root, f"Stair{j}", (1.55, 4.0, t), (L / 2 + 1.5 * (j + 0.5), 0, t / 2), "iron", bevel=0.03))
    return P


def underworks(root, rng):
    """A tunnel section of the underworks along local x (root["rs_len"] studs, default 16): brick side walls, an
    arched brick roof filled flat on top, a cinder floor and one dim caged lamp (always on: it is underground)."""
    Ls = float(root.get("rs_len", 16.0))
    span, T, Hs = 10.0, 2.0, 6.0  # PROPOSAL
    r = span / 2 + T / 2
    P = [pb(root, "Floor", (Ls, span, 0.4), (0, 0, 0.2), "cinder_dark", bevel=0)]
    for s in (-1, 1):
        P.append(pb(root, f"Wall{s:+d}", (Ls, T, Hs), (0, s * r, Hs / 2), "brick", bevel=0.06))
        hh = r + T / 2  # up to the fill, behind the arch
        P.append(pb(root, f"Haunch{s:+d}", (Ls, 2.6, hh), (0, s * (r + 0.3), Hs + hh / 2), "brick", bevel=0.04))
    for k in range(6):  # the arch: six voussoir courses, 30 degrees each
        phi = math.radians(15 + 30 * k)
        P.append(pb(root, f"Arch{k}", (Ls, 2 * r * math.tan(math.radians(15)) + 0.3, T),
                    (0, r * math.cos(phi), Hs + r * math.sin(phi)), "brick_dark", rot=(phi + math.pi / 2, 0, 0),
                    bevel=0.04))
    P.append(pb(root, "Fill", (Ls, span + 2 * T + 2.0, 1.2), (0, 0, Hs + r + T / 2 + 0.6), "brick", bevel=0.06))
    P.append(pb(root, "Cage", (0.9, 0.9, 1.1), (0, 0, Hs + r - T / 2 - 0.55), "iron", bevel=0.04))
    P.append(pb(root, "DimGlow", (0.6, 0.6, 0.6), (0, 0, Hs + r - T / 2 - 1.4), "lamp", bevel=0.05))
    light(root, "DimLight", (0, 0, Hs + r - T / 2 - 1.6), 1500, "ffb35c", 14)
    return P


def canteen(root, rng):
    """The canteen: a one-storey brick hall with an iron roof, big warm windows, a canvas awning and a name board,
    two tables with benches out front and a NightOnly lamp."""
    P, dx = _block(root, rng, 24.0, 14.0, 1, sh=9.0, o=(0, 4.0), roof="iron", door_x=0.0, bay=6.0, ledges=False)
    fy = 4.0 - 7.0
    P.append(pb(root, "Awning", (20.0, 4.0, 0.3), (0, fy - 2.0, 9.0), "canvas", rot=(math.radians(14), 0, 0), bevel=0))
    for k, x in enumerate((-6.0, 6.0)):
        P.append(pb(root, f"Table{k}", (5.0, 2.4, 0.4), (x, -8.0, 2.9), "timber", bevel=0.05))
        for s in (-1, 1):
            P.append(pb(root, f"Table{k}Leg{s:+d}", (0.5, 2.0, 2.7), (x + s * 2.0, -8.0, 1.35), "timber", bevel=0.03))
            P.append(pb(root, f"Table{k}Bench{s:+d}", (5.0, 1.0, 1.6), (x, -8.0 + s * 2.3, 0.8), "timber", bevel=0.05))
    P += lamp(root, "Lamp", 11.0, -10.0)
    root["rs_door_x"] = dx
    return P


def market_stall(root, rng):
    """A market stall: four posts, a counter to the front, a back shelf, a canvas canopy, goods and a sign."""
    P = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            P.append(pb(root, f"Post{sx:+d}{sy:+d}", (0.6, 0.6, 7.0), (sx * 3.6, sy * 2.2, 3.5), "timber", bevel=0.04))
    P.append(pb(root, "Counter", (8.0, 1.6, 3.0), (0, -1.6, 1.5), "timber", bevel=0.06))
    P.append(pb(root, "Shelf", (7.0, 1.0, 2.2), (0, 2.0, 1.1), "crate", bevel=0.05))
    P.append(pb(root, "Canopy", (9.0, 6.2, 0.3), (0, -0.4, 7.4), "canvas", rot=(math.radians(10), 0, 0), bevel=0))
    for i, m in enumerate(("crate", "rust", "canvas")):
        P.append(pb(root, f"Goods{i}", (1.2, 1.2, 1.0), (-2.4 + i * 2.4, -1.6, 3.5), m, bevel=0.08))
    P.append(pb(root, "Sign", (5.0, 0.3, 1.0), (0, -2.7, 6.3), "timber", bevel=0.03))
    return P


# ------------------------------------------------------------------ cover: (root, rng) -> parts in a 6 x 6 footprint
def cover(root, rng):
    """A cover cluster within local [-3, 3] x [-3, 3]: a crate stack, a boiler on cradles, or barrels. 3-6 studs tall
    (R6 is 5): enough to crouch behind."""
    kind = rng.choice(("crates", "crates", "boiler", "barrels"))
    P = []
    if kind == "crates":
        spots = [(-1.5, -1.5), (1.5, -1.5), (-1.5, 1.5), (1.5, 1.5)]
        rng.shuffle(spots)
        n = rng.choice((2, 3, 4))
        for i, (x, y) in enumerate(spots[:n]):
            P.append(pb(root, f"Crate{i}", (2.9, 2.9, 2.9), (x, y, 1.45), "crate", rot=(0, 0, rng.uniform(-0.12, 0.12)),
                        bevel=0.08))
        x, y = spots[0]
        P.append(pb(root, "CrateTop", (2.6, 2.6, 2.6), (x, y, 2.9 + 1.3), "crate", rot=(0, 0, rng.uniform(-0.3, 0.3)),
                    bevel=0.08))
    elif kind == "boiler":
        P.append(pb(root, "Skid", (5.6, 3.4, 0.6), (0, 0, 0.3), "iron", bevel=0.04))
        for s in (-1, 1):
            P.append(pb(root, f"Cradle{s:+d}", (0.8, 3.0, 1.4), (s * 1.6, 0, 1.3), "iron", bevel=0.04))
        P.append(pc(root, "Boiler", 1.5, 5.4, (0, 0, 3.2), "rust", rot=(0, math.radians(90), 0), verts=14))
        P.append(pc(root, "Flywheel", 1.6, 0.5, (0, 2.0, 2.0), "iron", rot=(math.radians(90), 0, 0), verts=14))
    else:
        for i, (x, y) in enumerate(((-1.4, -1.2), (1.3, -1.4), (-1.2, 1.4), (1.4, 1.2))):
            P.append(pc(root, f"Barrel{i}", 1.1, 3.0, (x, y, 1.5), "timber", verts=12))
            P.append(pc(root, f"Hoop{i}", 1.16, 0.25, (x, y, 2.2), "iron", verts=12))
    return P


# ------------------------------------------------------------------ the kit's tables
# style -> (Roblox prefab kind, function, (w min, w max, d min, d max), terrace: neighbours share walls). PROPOSAL sizes.
STYLES = {
    "house": ("House", house, (12, 16, 16, 20), True),
    "boarding": ("BoardingHouse", boarding, (32, 40, 16, 18), False),
    "shed": ("Shed", shed, (14, 22, 12, 18), False),
    "warehouse": ("Warehouse", warehouse, (24, 36, 18, 24), False),
    "stack": ("Smokestack", stack, (6, 8, 6, 8), False),
}
# landmark -> (Roblox prefab kind, function, local footprint [x0, y0, x1, y1] the planners keep clear). PROPOSAL.
LANDMARKS = {
    "practice_court": ("PracticeCourt", practice_court, (-20, -20, 20, 20)),
    "foundry_hall": ("FoundryHall", foundry_hall, (-49, -35, 49, 33)),
    "crane_bay": ("CraneBay", crane_bay, (-24, -16, 24, 16)),
    "rail_walk": ("RailWalk", rail_walk, (-23, -5, 43, 5)),
    "underworks": ("Underworks", underworks, (-8, -8, 8, 8)),
    "canteen": ("Canteen", canteen, (-13, -12, 13, 12)),
    "market_stall": ("MarketStall", market_stall, (-5, -4, 5, 3)),
}
COVER = ("Cover", cover, (-3, -3, 3, 3))
LAMP_FOOT = (-0.8, -0.8, 0.8, 0.8)

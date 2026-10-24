"""The region builder's Blender stages (spec 2026-10-23 §3.2): ground, routes, buildings, landmarks, cover (cover
clusters and street lamps), edges, markers, lighting and renders. The style-kit stages place pieces from kits/
(railtown) with pure-geometry planners (plan_buildings, plan_props, plan_edges) and settle each prefab on the stepped
ground (a footing down to the lowest ground under it, stoop steps to the street).

Frame: 1 Blender unit = 1 stud. A region point (x east, y up, z south) is Blender (x, z, y), so export.py's mapping
(Blender (x, y, z) -> Roblox (X = x, Y = z, Z = y)) puts it back where the region file says. That frame is a mirror
image of Roblox's, so perspective renders are flipped left-right to show the place as Studio will (as
lindenmoor/expansion.py does). A Roblox yaw (degrees about +Y) is a Blender rotation of -yaw about z.

Each stage clears and rebuilds its own collection under Region_<Region> (the Roblox group: Ground, Routes, Buildings,
Landmarks, Cover, Edges, Markers).
Every exported piece is a prefab: an Empty with rs_prefab / rs_id, its parts parented, each part carrying rs_kind,
rs_size, rs_mat (and rs_invisible / rs_attr / rs_tags on markers). Water previews and the lights live outside the
groups and have no prefab, so export.py skips them. Every size here is a PROPOSAL."""
import dataclasses, json, math, os, random

import bpy
from mathutils import Matrix, Vector

from lindenmoor.core import box, flat, srgb
from . import heightfield as HF, kits, materials, merge, schema

TILE = 64  # studs: one Ground prefab per 64 x 64 tile (brief)
TOP_BEVEL = 0.1  # studs; a slab's lit edge in the renders (the bevel is Blender-only, Roblox parts stay boxes)
RAMP_THICK = 1.2  # as ground.lua's dirt ramps
KERB = (0.6, 0.5)  # kerb width, height above the paving (PROPOSAL)
STEEP = (4, 8)  # stairs where a route climbs more than 4 studs over 8 (brief)
GAUGE = 4.7  # rail centres (PROPOSAL)
SLEEPER_GAP = 4  # studs between sleepers (PROPOSAL)
RAIL_PIECE = 16  # longest straight rail piece; longer runs follow the ground in pieces (PROPOSAL)
EYE = 6  # street-view camera height above the ground (a standing character's eye is about 5)
P3 = Matrix(((1, 0, 0), (0, 0, 1), (0, 1, 0)))  # Roblox <-> Blender axis swap (export.py's P3)


# ------------------------------------------------------------------ scene plumbing
def _root(layout):
    """The region's root collection, Region_<Region>, linked into the current scene."""
    name = f"Region_{layout['Region']}"
    s = bpy.context.scene
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
    if c.name not in s.collection.children:
        s.collection.children.link(c)
    return c


def group(layout, name):
    """The child collection `name` of Region_<Region> (export.py reads the group from the collection's name)."""
    root = _root(layout)
    for c in root.children:
        if c.name.split(".")[0] == name:
            return c
    c = bpy.data.collections.new(name)
    root.children.link(c)
    return c


def clear_group(layout, name):
    c = group(layout, name)
    objs = list(c.objects)
    if objs:
        bpy.data.batch_remove(objs)
    return c


def prefab(c, kind, ident, loc):
    """A prefab root: an Empty at Blender `loc` (no rotation), in collection c."""
    e = bpy.data.objects.new(f"PF_{kind}_{ident}", None)
    e.empty_display_size = 2
    e.location = loc
    e["rs_prefab"] = kind
    e["rs_id"] = str(ident)
    c.objects.link(e)
    return e


def part(root, name, size, loc, mat, rot=(0, 0, 0), bevel=0.0):
    """A Block part of `root` at Blender world `loc` (roots here are never rotated, so local = loc - root)."""
    rl = root.location
    o = box(f"{root.name}_{name}", size, (loc[0] - rl.x, loc[1] - rl.y, loc[2] - rl.z), mat, root.users_collection[0],
            rot=rot, bevel=bevel, segs=1)
    o.parent = root
    return o


def bl(x, y, z):
    """Region (x, y, z) -> Blender location."""
    return (x, z, y)


def _cell_of(grid, x, z):
    i = int(math.floor((x - grid.origin[0]) / grid.cell))
    k = int(math.floor((z - grid.origin[1]) / grid.cell))
    return min(max(i, 0), grid.nx - 1), min(max(k, 0), grid.nz - 1)


def ground_y(grid, x, z):
    """The stepped ground's top at (x, z): its cell's whole-stud top."""
    i, k = _cell_of(grid, x, z)
    return grid.top[i][k]


def _num(v):
    return int(v) if float(v).is_integer() else v


def water_boxes(grid):
    """The water that is left: cells still water (Grid.water_of), merged per water shape. [{Rect, Top, Bed}]."""
    cells = {(i, k): grid.water_of[i][k] for i in range(grid.nx) for k in range(grid.nz)
             if grid.water_of and grid.water_of[i][k] is not None}
    ox, oz, c = grid.origin[0], grid.origin[1], grid.cell
    out = []
    for i0, k0, w, d, n in merge.rects(cells):
        top, bed = grid.water[n][4], grid.water[n][5]
        out.append({"Rect": [_num(ox + i0 * c), _num(oz + k0 * c), _num(ox + (i0 + w) * c), _num(oz + (k0 + d) * c)],
                    "Top": _num(top), "Bed": _num(bed)})
    return out


def write_water(grid, path):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    boxes = water_boxes(grid)
    with open(path, "w", encoding="utf-8") as f:
        json.dump({"Boxes": boxes}, f, indent=1)
        f.write("\n")
    return boxes


# ------------------------------------------------------------------ ground
def _ramp(root, n, grid, layout, i, k, bottom, mat, side):
    """A route cell on a slope: a tilted 1.2-thick slab through its 4 corner heights over a side block (ground.lua)."""
    a, b, c, d = HF.corners(grid, layout, i, k)
    cell = grid.cell
    cx, cz = grid.centre(i, k)
    gx = ((b + d) - (a + c)) / (2 * cell)
    gz = ((c + d) - (a + b)) / (2 * cell)
    mid = (a + b + c + d) / 4
    right = Vector((1, gx, 0)).normalized()  # Roblox axes (X east, Y up, Z south)
    up = Vector((0, gz, 1)).cross(Vector((1, gx, 0))).normalized()
    if up.y < 0:
        up = -up
    back = right.cross(up).normalized()
    R = P3 @ Matrix((right, up, back)).transposed() @ P3  # CFrame.fromMatrix's columns, in Blender axes
    at = Vector((cx, mid, cz)) - up * (RAMP_THICK / 2)
    size = (cell * math.sqrt(1 + gx * gx) + 0.25, cell * math.sqrt(1 + gz * gz) + 0.25, RAMP_THICK)
    part(root, f"Ramp{n}", size, bl(at.x, at.y, at.z), mat, rot=R.to_euler())
    hi, lo = min(a, b, c, d) - RAMP_THICK / 2, bottom
    if hi - lo > 0.3:
        part(root, f"Under{n}", (cell, cell, hi - lo), bl(cx, (hi + lo) / 2, cz), side)


def ground(layout, grid):
    """One prefab per 64 x 64-stud tile (group Ground): merged Top slabs 1 stud thick, Side blocks from top - 1 down
    to the column's bottom, and ramps on sloping route cells. Route cells' tops are the routes' surfaces (paving on
    public and road routes, cinder lanes on quiet ones); a water cell's top is its bed. Cells under a stair run (see
    stair_cells) get no ramp: they are flat columns whose tops stay at or below the steps over them, so the stairs
    stand alone. Returns the part count."""
    M = materials.palette(layout)
    c = clear_group(layout, "Ground")
    top_mat = {"top": M["ground_top"], "path": M["path"], "quiet": M["quiet"], "water": M["ground_side"]}
    side = M["ground_side"]
    under = stair_cells(layout, grid)  # cells under a stair run: flat columns kept below the steps, never ramps
    ramps = HF.ramps(grid, layout) - set(under)
    ox, oz, cell = grid.origin[0], grid.origin[1], grid.cell
    tops = [col[:] for col in grid.top]
    for (i, k), t in under.items():
        tops[i][k] = t
    tiles = {}
    for i, k, t, b, kd in HF.columns(dataclasses.replace(grid, top=tops)):
        tiles.setdefault((i * cell // TILE, k * cell // TILE), {})[(i, k)] = (t, b, kd)
    n = 0
    for (ti, tk), cols in sorted(tiles.items()):
        root = prefab(c, "Ground", f"{ti}_{tk}", (ox + (ti + 0.5) * TILE, oz + (tk + 0.5) * TILE, 0))
        flat_cells = {ik: v for ik, v in cols.items() if ik not in ramps}
        for j, (i0, k0, w, d, (t, b, kd)) in enumerate(merge.rects(flat_cells)):
            x, z = ox + (i0 + w / 2) * cell, oz + (k0 + d / 2) * cell
            part(root, f"Top{j}", (w * cell, d * cell, 1), bl(x, t - 0.5, z), top_mat[kd], bevel=TOP_BEVEL)
            n += 1
            if t - 1 > b:
                part(root, f"Side{j}", (w * cell, d * cell, t - 1 - b), bl(x, (t - 1 + b) / 2, z), side)
                n += 1
        for j, (i, k) in enumerate(sorted(ik for ik in cols if ik in ramps)):
            kd = cols[(i, k)][2]
            before = len(root.children)
            _ramp(root, j, grid, layout, i, k, cols[(i, k)][1], top_mat[kd], side)
            n += len(root.children) - before
    water_preview(layout, grid)
    return n


def water_preview(layout, grid):
    """See-through water slabs for the renders only (no prefab: Studio fills water.json's boxes with terrain water)."""
    c = clear_group(layout, "Preview")
    m = flat(f"RG_{layout['Region']}_water_preview", srgb("2b3a3f"), rough=0.08)
    try:
        b = m.node_tree.nodes.get("Principled BSDF")
        b.inputs["Alpha"].default_value = 0.72
        m.blend_method = "BLEND"
    except Exception:  # older/newer material settings: an opaque preview is fine
        pass
    for n, w in enumerate(water_boxes(grid)):
        x0, z0, x1, z1 = w["Rect"]
        h = w["Top"] - w["Bed"]
        o = box(f"WaterPreview{n}", (x1 - x0, z1 - z0, h), bl((x0 + x1) / 2, w["Bed"] + h / 2, (z0 + z1) / 2), m, c,
                bevel=0)
        for k in ("rs_kind", "rs_size", "rs_mat"):
            del o[k]
        o["rs_skip"] = True
    return c


# ------------------------------------------------------------------ routes
def _runs(cells, along):
    """Groups edge cells into straight runs. cells: {(i, k): top}; along "i" or "k". Yields (i0, k0, length, top)."""
    seen = set()
    for i, k in sorted(cells, key=lambda ik: (ik[1], ik[0]) if along == "i" else ik):
        if (i, k) in seen:
            continue
        t, n = cells[(i, k)], 1
        while True:
            nxt = (i + n, k) if along == "i" else (i, k + n)
            if nxt in cells and cells[nxt] == t and nxt not in seen:
                n += 1
            else:
                break
        for m in range(n):
            seen.add((i + m, k) if along == "i" else (i, k + m))
        yield i, k, n, t


def _kerbs(layout, grid, c, mat):
    """Kerbs along every path cell edge that meets plain ground or water (not on ramps or under stairs), one prefab per
    tile."""
    ramps = HF.ramps(grid, layout) | set(stair_cells(layout, grid))
    tc = max(1, TILE // grid.cell)  # cells per tile
    edges = {d: {} for d in ("N", "S", "W", "E")}
    for i in range(grid.nx):
        for k in range(grid.nz):
            if grid.kind[i][k] != "path" or (i, k) in ramps:
                continue
            for d, (di, dk) in (("N", (0, -1)), ("S", (0, 1)), ("W", (-1, 0)), ("E", (1, 0))):
                ii, kk = i + di, k + dk
                if 0 <= ii < grid.nx and 0 <= kk < grid.nz and grid.kind[ii][kk] in ("top", "water"):
                    # key the top with the tile so runs break at tile edges
                    edges[d][(i, k)] = (grid.top[i][k], i // tc, k // tc)
    roots, n = {}, 0
    ox, oz, cell = grid.origin[0], grid.origin[1], grid.cell
    kw, kh = KERB
    for d, cells in edges.items():
        along = "i" if d in ("N", "S") else "k"
        for i0, k0, L, (t, ti, tk) in _runs(cells, along):
            root = roots.get((ti, tk))
            if root is None:
                root = roots[(ti, tk)] = prefab(c, "Kerbs", f"{ti}_{tk}",
                                                (ox + (ti + 0.5) * TILE, oz + (tk + 0.5) * TILE, 0))
            x0, z0 = ox + i0 * cell, oz + k0 * cell
            if along == "i":
                z = z0 + kw / 2 if d == "N" else z0 + cell - kw / 2
                size, x = (L * cell, kw, kh), x0 + L * cell / 2
            else:
                x = x0 + kw / 2 if d == "W" else x0 + cell - kw / 2
                size, z = (kw, L * cell, kh), z0 + L * cell / 2
            part(root, f"Kerb{n}", size, bl(x, t + kh / 2, z), mat)
            n += 1
    return n


def _steep_spans(layout, a, b):
    """([(s0, s1)], h(s), (ux, uz)): the stretches of segment a-b, as distances along it, that climb more than STEEP[0]
    studs over STEEP[1]; h is the ground's (unrounded) height at a distance along the segment."""
    L = math.hypot(b[0] - a[0], b[1] - a[1])
    if L == 0:
        return [], None, None
    ux, uz = (b[0] - a[0]) / L, (b[1] - a[1]) / L

    def h(s):
        return HF.height_at(layout, a[0] + ux * s, a[1] + uz * s)

    rise, run = STEEP
    spans = []
    s = 0.0
    while s <= L + 1e-9:
        lo = max(0.0, s - run / 2)
        hi = min(L, lo + run)
        lo = max(0.0, hi - run)
        if abs(h(hi) - h(lo)) > rise:
            if spans and lo <= spans[-1][1]:
                spans[-1][1] = max(spans[-1][1], hi)
            else:
                spans.append([lo, hi])
        s += 1.0
    out = []
    for s0, s1 in spans:  # trim the flat ends, so the stairs start and stop where the ground does
        while s1 - s0 > 1 and abs(h(s0 + 0.5) - h(s0)) < 0.02:
            s0 += 0.5
        while s1 - s0 > 1 and abs(h(s1 - 0.5) - h(s1)) < 0.02:
            s1 -= 0.5
        out.append((s0, s1))
    return out, h, (ux, uz)


def stair_runs(layout, route=None):
    """The stair runs of the public, road and quiet routes (or of one route): every stretch steeper than STEEP becomes
    1-stud risers between whole-stud ends, the ground's rounded heights where the stretch starts and stops, so the
    bottom step rises 1 from the slab below and the top step is flush with the slab above. Each run is a dict:
    route Id, a (segment start [x, z]), u (unit direction), s0 / s1 (distances along the segment), width, base (the
    lower end - 1: every step is solid down to it) and steps [(sa, sb, top)] in order along the segment."""
    out = []
    for r in layout["Routes"] if route is None else [route]:
        if r["Kind"] not in ("public", "road", "quiet"):
            continue
        for a, b in zip(r["Line"], r["Line"][1:]):
            spans, h, u = _steep_spans(layout, a, b)
            for s0, s1 in spans:
                H0, H1 = HF._round(h(s0)), HF._round(h(s1))
                if H0 == H1:
                    continue
                n, rise = abs(H1 - H0), (1 if H1 > H0 else -1)
                tread = (s1 - s0) / n
                steps = [(s0 + j * tread, s0 + (j + 1) * tread, max(H0 + j * rise, H0 + (j + 1) * rise))
                         for j in range(n)]
                out.append({"route": r["Id"], "a": a, "u": u, "s0": s0, "s1": s1, "width": r["Width"],
                            "base": min(H0, H1) - 1, "steps": steps})
    return out


def stair_top_at(run, x, z):
    """The top of the step over (x, z), or None outside the run's footprint."""
    (ax, az), (ux, uz) = run["a"], run["u"]
    s = (x - ax) * ux + (z - az) * uz
    d = -(x - ax) * uz + (z - az) * ux
    if abs(d) > run["width"] / 2 or s < run["s0"] or s > run["s1"]:
        return None
    for sa, sb, top in run["steps"]:
        if s <= sb:
            return top
    return run["steps"][-1][2]


def _step_meets_cell(run, sa, sb, x0, z0, c):
    """Whether the step [sa, sb] x [-width/2, width/2] (in the run's frame) meets the closed cell square [x0, x0 + c]
    x [z0, z0 + c]: separating axes (the world axes and the run's two), so touching counts."""
    (ax, az), (ux, uz) = run["a"], run["u"]
    hw = run["width"] / 2
    step = [(ax + ux * s - uz * d, az + uz * s + ux * d) for s in (sa, sb) for d in (-hw, hw)]
    cell = [(x0, z0), (x0 + c, z0), (x0, z0 + c), (x0 + c, z0 + c)]
    for nx, nz in ((1, 0), (0, 1), (ux, uz), (-uz, ux)):
        p = [x * nx + z * nz for x, z in step]
        q = [x * nx + z * nz for x, z in cell]
        if max(p) < min(q) - 1e-9 or max(q) < min(p) - 1e-9:
            return False
    return True


def stair_cells(layout, grid):
    """{(i, k): top} for every cell a stair run's footprint touches: the cell's top lowered, where needed, to the
    lowest step that meets the cell anywhere (an exact overlap test, so cell corners and edges count: sampling only
    the cell's interior left 1-stud slivers of slab above the treads), so no part of a slab stands above a tread."""
    out = {}
    runs = stair_runs(layout)
    if not runs:
        return out
    c = grid.cell
    for run in runs:
        (ax, az), (ux, uz) = run["a"], run["u"]
        reach = run["width"] / 2 + c
        xs = [ax + ux * run["s0"], ax + ux * run["s1"]]
        zs = [az + uz * run["s0"], az + uz * run["s1"]]
        i0, k0 = _cell_of(grid, min(xs) - reach, min(zs) - reach)
        i1, k1 = _cell_of(grid, max(xs) + reach, max(zs) + reach)
        for i in range(i0, i1 + 1):
            for k in range(k0, k1 + 1):
                x0, z0 = grid.origin[0] + i * c, grid.origin[1] + k * c
                tops = [t for sa, sb, t in run["steps"] if _step_meets_cell(run, sa, sb, x0, z0, c)]
                if tops:
                    out[(i, k)] = min(out.get((i, k), grid.top[i][k]), grid.top[i][k], min(tops))
    return out
    c = grid.cell
    offs = [(m + 0.5) * c / samples for m in range(samples)]
    for run in runs:
        (ax, az), (ux, uz) = run["a"], run["u"]
        reach = run["width"] / 2 + c
        xs = [ax + ux * run["s0"], ax + ux * run["s1"]]
        zs = [az + uz * run["s0"], az + uz * run["s1"]]
        i0, k0 = _cell_of(grid, min(xs) - reach, min(zs) - reach)
        i1, k1 = _cell_of(grid, max(xs) + reach, max(zs) + reach)
        for i in range(i0, i1 + 1):
            for k in range(k0, k1 + 1):
                x0, z0 = grid.origin[0] + i * c, grid.origin[1] + k * c
                tops = [t for dx in offs for dz in offs if (t := stair_top_at(run, x0 + dx, z0 + dz)) is not None]
                if tops:
                    out[(i, k)] = min(out.get((i, k), grid.top[i][k]), grid.top[i][k], min(tops))
    return out


def _stairs(layout, route, root, mat):
    """Builds the route's stair runs (stair_runs): one solid Step block per riser, from the run's base up to the
    step's whole-stud top."""
    n = 0
    for run in stair_runs(layout, route):
        (ax, az), (ux, uz) = run["a"], run["u"]
        yaw_b = math.atan2(uz, ux) - math.pi / 2  # Blender: the step's local +y runs along the segment
        base = run["base"]
        for sa, sb, top in run["steps"]:
            sm = (sa + sb) / 2
            x, z = ax + ux * sm, az + uz * sm
            part(root, f"Step{n}", (run["width"], sb - sa + 0.05, top - base), bl(x, (top + base) / 2, z), mat,
                 rot=(0, 0, yaw_b))
            n += 1
    return n


def _rails(layout, grid, route, root, M):
    """Two iron rails on timber sleepers along a rail route, in straight pieces that follow the ground."""
    n = 0
    for a, b in zip(route["Line"], route["Line"][1:]):
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        if L == 0:
            continue
        ux, uz = (b[0] - a[0]) / L, (b[1] - a[1]) / L
        px, pz = -uz, ux  # across the track
        yaw_b = math.atan2(uz, ux) - math.pi / 2
        pieces = max(1, int(math.ceil(L / RAIL_PIECE)))
        for p in range(pieces):
            s0, s1 = L * p / pieces, L * (p + 1) / pieces
            y0 = ground_y(grid, a[0] + ux * s0, a[1] + uz * s0)
            y1 = ground_y(grid, a[0] + ux * s1, a[1] + uz * s1)
            pl = s1 - s0
            pitch = math.atan2(y1 - y0, pl)
            sm, ym = (s0 + s1) / 2, (y0 + y1) / 2
            for side in (-1, 1):
                x = a[0] + ux * sm + px * side * GAUGE / 2
                z = a[1] + uz * sm + pz * side * GAUGE / 2
                part(root, f"Rail{n}", (0.4, math.hypot(pl, y1 - y0) + 0.05, 0.5), bl(x, ym + 0.65, z), M["rail"],
                     rot=(pitch, 0, yaw_b))
                n += 1
        s = SLEEPER_GAP / 2
        while s < L:
            x, z = a[0] + ux * s, a[1] + uz * s
            part(root, f"Sleeper{n}", (GAUGE + 2.3, 1, 0.4), bl(x, ground_y(grid, x, z) + 0.2, z), M["sleeper"],
                 rot=(0, 0, yaw_b))
            n += 1
            s += SLEEPER_GAP
    return n


def routes(layout, grid):
    """Group Routes: kerb strips along public and road paving, stairs where a public, road or quiet route climbs more
    than 4 studs over 8, rails on rail routes. The paving and the cinder lanes themselves are the route cells' Top
    slabs and ramps, built by the ground stage from the heightfield's path / quiet cells (one surface, so no second
    layer of parts on the same cells). under and ledge routes are left to the later traversal stages. Returns the
    part count."""
    M = materials.palette(layout)
    c = clear_group(layout, "Routes")
    n = _kerbs(layout, grid, c, M["kerb"])
    for r in layout["Routes"]:
        kind = r["Kind"]
        if kind in ("public", "road", "quiet"):
            root = prefab(c, "Route", r["Id"], (0, 0, 0))
            n += _stairs(layout, r, root, M["quiet"] if kind == "quiet" else M["path"])
        elif kind == "rail":
            root = prefab(c, "Route", r["Id"], (0, 0, 0))
            n += _rails(layout, grid, r, root, M)
        else:
            continue
        if not root.children:
            bpy.data.objects.remove(root, do_unlink=True)
    return n


# ------------------------------------------------------------------ the style kits: placement (pure geometry)
FRONT_REACH = 48  # PROPOSAL: a district edge is a frontage when rays straight out from it meet a route this close
FRONT_SETBACK = 2  # PROPOSAL: a pavement strip between a frontage edge and the building fronts
CLEAR = 2  # studs: every building keeps this clear of each route's corridor and of every marker (brief)
ALLEY = 4  # studs: the narrowest alley between buildings (brief)
OVERHANG = 1.5  # studs: how far eaves, cornices, plinths and ledges reach past a building's side and back walls
FOOTING = 0.4  # studs: a footing reaches this far past a building's walls
STEP_TREAD = 1.2  # studs: a stoop step's tread (risers are 1 stud or less)
COVER_EVERY = 20  # PROPOSAL (brief): studs of quiet route, or of built frontage (back yards), per cover cluster
LAMP_EVERY = 40  # PROPOSAL: studs of public or road route per street lamp, sides alternating
EDGE_BAND = 12  # PROPOSAL: the edge ridges' depth in from the footprint's edge
EDGE_HEIGHT = 24  # PROPOSAL (brief: at least 24): the edge ridges' least height over the ground
EDGE_SEG = 16  # PROPOSAL: the longest ridge block along an edge
STREET_KINDS = ("public", "quiet", "road")  # the routes a building may front
# how far each style's front fittings (steps, canopy, dock, hoist) reach past its front wall (PROPOSAL, from the kit)
FRONT_REACH_OF = {"house": 1.5, "boarding": 3.4, "shed": 1.5, "warehouse": 4.2, "stack": 1.0}


def _quad(x, z, theta, rect):
    """Region (x, z) corners of a local rect [x0, y0, x1, y1] on a prefab at (x, z) turned theta (Blender z)."""
    c, s = math.cos(theta), math.sin(theta)
    x0, y0, x1, y1 = rect
    return [(x + px * c - py * s, z + px * s + py * c) for px, py in ((x0, y0), (x1, y0), (x1, y1), (x0, y1))]


def _seg_dist(px, pz, a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    L2 = dx * dx + dz * dz
    t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((px - a[0]) * dx + (pz - a[1]) * dz) / L2))
    return math.hypot(px - (a[0] + t * dx), pz - (a[1] + t * dz))


def _orient(a, b, c):
    return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])


def _seg_seg(a, b, c, d):
    """Distance between segments a-b and c-d (0 when they cross or touch)."""
    o1, o2, o3, o4 = _orient(a, b, c), _orient(a, b, d), _orient(c, d, a), _orient(c, d, b)
    if o1 * o2 <= 0 and o3 * o4 <= 0 and (o1, o2) != (0, 0):
        return 0.0
    return min(_seg_dist(c[0], c[1], a, b), _seg_dist(d[0], d[1], a, b), _seg_dist(a[0], a[1], c, d),
               _seg_dist(b[0], b[1], c, d))


def _inside(poly, x, z):
    c = False
    for (x0, z0), (x1, z1) in zip(poly, poly[1:] + poly[:1]):
        if (z0 > z) != (z1 > z) and x < x0 + (z - z0) * (x1 - x0) / (z1 - z0):
            c = not c
    return c


def _quad_point_dist(q, x, z):
    if _inside(q, x, z):
        return 0.0
    return min(_seg_dist(x, z, a, b) for a, b in zip(q, q[1:] + q[:1]))


def _quad_line_dist(q, line):
    if any(_inside(q, p[0], p[1]) for p in line):
        return 0.0
    return min(_seg_seg(a, b, c, d) for a, b in zip(q, q[1:] + q[:1]) for c, d in zip(line, line[1:]))


def _quads_overlap(p, q, eps=1e-6):
    """Whether two convex quads overlap with some area (touching is not overlapping)."""
    for poly in (p, q):
        for a, b in zip(poly, poly[1:] + poly[:1]):
            nx, nz = b[1] - a[1], a[0] - b[0]
            L = math.hypot(nx, nz) or 1.0
            pp = [(x * nx + z * nz) / L for x, z in p]
            qq = [(x * nx + z * nz) / L for x, z in q]
            if max(pp) <= min(qq) + eps or max(qq) <= min(pp) + eps:
                return False
    return True


def _grow(rect, by):
    return (rect[0] - by, rect[1] - by, rect[2] + by, rect[3] + by)


def _ground_stats(grid, x, z, theta, rect, step=1.0):
    """(lowest, highest, any water) of the stepped ground over a local rect of a prefab at (x, z) turned theta."""
    x0, y0, x1, y1 = rect[0] + 0.01, rect[1] + 0.01, rect[2] - 0.01, rect[3] - 0.01
    nx, ny = max(1, int(math.ceil((x1 - x0) / step))), max(1, int(math.ceil((y1 - y0) / step)))
    c, s = math.cos(theta), math.sin(theta)
    lo, hi, wet = math.inf, -math.inf, False
    for i in range(nx + 1):
        for j in range(ny + 1):
            px, py = x0 + (x1 - x0) * i / nx, y0 + (y1 - y0) * j / ny
            ci, ck = _cell_of(grid, x + px * c - py * s, z + px * s + py * c)
            t = grid.top[ci][ck]
            lo, hi = min(lo, t), max(hi, t)
            wet = wet or grid.kind[ci][ck] == "water"
    return lo, hi, wet


class _Site:
    """What a placement must keep clear of: routes, markers, landmarks, the edge band, and what is already placed."""

    def __init__(self, layout, grid):
        self.layout, self.grid = layout, grid
        self.routes = list(layout["Routes"])
        self.points = [m for m in layout["Markers"] if "At" in m and m["Tag"] not in schema.BUILDER_TAGS]
        # Box markers that stand for a place (a gate, a yard zone) keep buildings out; RenseiArea boxes are areas that
        # hold whole districts, and builder tags (EdgeGap) only shape the edges
        self.boxes = [m for m in layout["Markers"] if "Box" in m and m["Tag"] not in schema.BUILDER_TAGS
                      and m["Tag"] != "RenseiArea"]
        fw, fd = layout["Footprint"]
        self.inner = (-fw / 2 + EDGE_BAND, -fd / 2 + EDGE_BAND, fw / 2 - EDGE_BAND, fd / 2 - EDGE_BAND)
        self.landmarks = []
        for lm in layout["Landmarks"]:
            mod, entry, what = kits.piece(lm["Kind"])
            if what == "landmark":
                self.landmarks.append(_quad(lm["At"][0], lm["At"][1], -math.radians(lm.get("Yaw", 0)), entry[2]))
        self.taken = []  # [(quad, group)]: placed footprints

    def routes_clear(self, q, clear):
        return all(_quad_line_dist(q, r["Line"]) >= r["Width"] / 2 + clear - 1e-9 for r in self.routes)

    def markers_clear(self, q, clear):
        for m in self.points:
            if _quad_point_dist(q, m["At"][0], m["At"][2]) < math.sqrt(2) + clear - 1e-9:  # a marker part is 2 x 2
                return False
        for m in self.boxes:
            (x0, _, z0), (x1, _, z1) = m["Box"]
            if _quads_overlap(q, [(x0 - clear, z0 - clear), (x1 + clear, z0 - clear), (x1 + clear, z1 + clear),
                                  (x0 - clear, z1 + clear)]):
                return False
        return True

    def in_bounds(self, q):
        x0, z0, x1, z1 = self.inner
        return all(x0 <= x <= x1 and z0 <= z <= z1 for x, z in q)

    def free(self, q, skip=()):
        return not any(_quads_overlap(q, lq) for lq in self.landmarks) and \
            not any(_quads_overlap(q, tq) for tq, g in self.taken if g not in skip)


def frontages(layout, district):
    """The district's edges that front a route: [{edge, a, u, n (outward), L}]. An edge fronts a route when, from at
    least half its points (every 4 studs), a ray straight out meets a public, quiet or road corridor within
    FRONT_REACH."""
    poly = district["Poly"]
    streets = [r for r in layout["Routes"] if r["Kind"] in STREET_KINDS]
    out = []
    for e, (a, b) in enumerate(zip(poly, poly[1:] + poly[:1])):
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        if L < 1:
            continue
        u = ((b[0] - a[0]) / L, (b[1] - a[1]) / L)
        n = (u[1], -u[0])
        if _inside(poly, (a[0] + b[0]) / 2 + n[0] * 0.5, (a[1] + b[1]) / 2 + n[1] * 0.5):
            n = (-n[0], -n[1])
        ts = [2 + 4 * k for k in range(int((L - 4) // 4) + 1)] if L > 4 else [L / 2]
        hits = 0
        for t in ts:
            px, pz = a[0] + u[0] * t, a[1] + u[1] * t
            for k in range(1, FRONT_REACH + 1):
                qx, qz = px + n[0] * k, pz + n[1] * k
                if any(HF.line_dist(qx, qz, r["Line"]) <= r["Width"] / 2 for r in streets):
                    hits += 1
                    break
        if hits * 2 >= len(ts):
            out.append({"edge": e, "a": a, "u": u, "n": n, "L": L})
    return out


def plan_buildings(layout, grid, site=None):
    """Where the buildings go: each district's frontages filled with its Style's buildings, fronts to the route.

    Along a frontage the buildings stand FRONT_SETBACK in from the district edge. Free stretches are those where a
    building of the style's largest depth keeps CLEAR studs off every route corridor and marker, stays out of
    landmarks, water and the edge band, and has its footing inside the district. Each stretch fills with terraces of 2
    or 3 (houses: neighbours share a party wall; other styles stand alone), then an alley of max(ALLEY, terrace length
    x (1 - Density) / Density) studs, so about Density of the frontage is built (PROPOSAL). A building stands at the
    highest ground under its footing (the stage adds a footing down to the lowest and stoop steps to the street).
    Returns [{id, district, frontage, style, kind, fn, x, z, theta, w, d, storeys, seed, party, body, clear}]."""
    site = site or _Site(layout, grid)
    out = []
    for dist in layout["Districts"]:
        mod, entry, what = kits.piece(dist["Style"])
        if what != "style":
            raise ValueError(f"district {dist['Id']}: {dist['Style']} is a landmark, not a building style")
        if dist["Density"] <= 0:
            continue
        rng = random.Random(f"{layout['Region']}:{dist['Id']}")
        for f in frontages(layout, dist):
            out += _fill_frontage(site, grid, dist, f, dist["Style"].partition(".")[2], entry, rng)
    return out


def _fill_frontage(site, grid, dist, f, style, entry, rng):
    kind, fn, (wmin, wmax, dmin, dmax), terrace = entry
    reach = FRONT_REACH_OF.get(style, OVERHANG)
    (ax, az), (ux, uz), (nx, nz), L = f["a"], f["u"], f["n"], f["L"]
    theta = math.atan2(nx, -nz)  # local -y (the front) faces out of the district
    sgn = 1 if math.cos(theta) * ux + math.sin(theta) * uz > 0 else -1  # local +x runs with the edge (+1) or against
    poly = dist["Poly"]
    key = f"{dist['Id']}:{f['edge']}"

    def frame(s, t):  # s along the edge, t in from it
        return ax + ux * s - nx * t, az + uz * s - nz * t

    def edge_quad(s0, s1, t0, t1):
        return [frame(s0, t0), frame(s1, t0), frame(s1, t1), frame(s0, t1)]

    def slice_ok(s):
        q = edge_quad(s, s + 1, FRONT_SETBACK - reach, FRONT_SETBACK + dmax + OVERHANG)
        foot = edge_quad(s, s + 1, FRONT_SETBACK - FOOTING, FRONT_SETBACK + dmax + FOOTING)
        if not all(_inside(poly, x, z) or _quad_point_dist(poly, x, z) < 1e-9 for x, z in foot):
            return False
        cx, cz = frame(s + 0.5, FRONT_SETBACK + dmax / 2)
        if _ground_stats(grid, cx, cz, theta, (-0.5, -dmax / 2 - FOOTING, 0.5, dmax / 2 + FOOTING))[2]:
            return False
        return site.routes_clear(q, CLEAR) and site.markers_clear(q, CLEAR) and site.in_bounds(q) and site.free(q)

    ok = [slice_ok(s) for s in range(int(L))]
    spans, s = [], 0
    while s < len(ok):
        if ok[s]:
            e = s
            while e < len(ok) and ok[e]:
                e += 1
            lo, hi = math.ceil(s + OVERHANG), math.floor(e - OVERHANG)  # bodies; the slices covered the overhangs
            if hi - lo >= wmin:
                spans.append((lo, hi))
            s = e
        else:
            s += 1
    out = []
    D = dist["Density"]
    for lo, hi in spans:
        pos = lo
        while hi - pos >= wmin:
            k = rng.choice((2, 3)) if terrace else 1
            depth = rng.randint(dmin, dmax)
            start, row = pos, []
            for _ in range(k):
                rem = hi - pos
                if rem < wmin:
                    break
                w = rng.randint(wmin, wmax)
                if rem - w < wmin:  # leave nothing, or room for one more
                    w = rem - wmin if rem - wmin >= wmin else min(rem, wmax)
                b = _place(site, grid, kind, fn, dist, key, len(out) + len(row), frame, theta, pos, w, depth, reach,
                           rng)
                if b is None:
                    break
                row.append(b)
                pos += w
            for p, q in zip(row, row[1:]):  # neighbours in a terrace share a party wall
                p["party"] += "R" if sgn > 0 else "L"
                q["party"] += "L" if sgn > 0 else "R"
            out += row
            built = pos - start
            if built == 0:
                pos += 1
                continue
            for b in row:
                site.taken.append((b["body"], key))
            pos += max(ALLEY, math.ceil(built * (1 - D) / D))
    return out


def _place(site, grid, kind, fn, dist, key, n, frame, theta, pos, w, depth, reach, rng):
    """One building of the fill, checked exactly (its own depth, its stoop): a dict, or None when it can't stand."""
    x, z = frame(pos + w / 2, FRONT_SETBACK + depth / 2)
    body = (-w / 2, -depth / 2, w / 2, depth / 2)
    lo, hi, wet = _ground_stats(grid, x, z, theta, _grow(body, FOOTING))
    flo, _, fwet = _ground_stats(grid, x, z, theta, (-w / 2, -depth / 2 - 2.4, w / 2, -depth / 2 - 1.2))
    if wet or fwet:
        return None
    rise = hi - min(flo, lo)
    nsteps = int(math.ceil(rise - 1e-9)) - 1 if rise > 1 + 1e-9 else 0
    q = _quad(x, z, theta, (-w / 2 - OVERHANG, -depth / 2 - reach - nsteps * STEP_TREAD, w / 2 + OVERHANG,
                            depth / 2 + OVERHANG))
    if not (site.routes_clear(q, CLEAR) and site.markers_clear(q, CLEAR) and site.in_bounds(q)):
        return None
    alley = _quad(x, z, theta, _grow(body, ALLEY / 2 - 1e-3))  # other frontages' buildings stay an alley away
    if not site.free(q, skip=(key,)) or any(_quads_overlap(alley, tq) for tq, g in site.taken if g != key):
        return None
    if not all(_inside(dist["Poly"], px, pz) or _quad_point_dist(dist["Poly"], px, pz) < 1e-9
               for px, pz in _quad(x, z, theta, _grow(body, FOOTING))):
        return None
    lo_s, hi_s = dist["Storeys"]
    return {"id": f"{dist['Id']}_{n}", "district": dist["Id"], "frontage": key, "style": dist["Style"],
            "kind": kind, "fn": fn, "x": x, "z": z, "theta": theta, "w": w, "d": depth,
            "storeys": rng.randint(lo_s, hi_s), "seed": rng.randrange(1 << 30), "party": "",
            "body": _quad(x, z, theta, body), "clear": q}


def _along(line, every):
    """Points every `every` studs along a polyline, at (j + 0.5) * every: [(x, z, ux, uz, j)]."""
    segs, total = [], 0.0
    for a, b in zip(line, line[1:]):
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        if L > 0:
            segs.append((a, b, L, total))
            total += L
    out = []
    for j in range(int(total // every)):
        s = (j + 0.5) * every
        for a, b, L, s0 in segs:
            if s <= s0 + L + 1e-9:
                t = (s - s0) / L
                out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, (b[0] - a[0]) / L, (b[1] - a[1]) / L,
                            j))
                break
    return out


def _spot_ok(site, grid, x, z, theta, rect, route_clear, grow):
    """The quad of a prop spot that is clear and stands on flat dry ground, or None."""
    q = _quad(x, z, theta, rect)
    lo, hi, wet = _ground_stats(grid, x, z, theta, rect)
    if wet or hi != lo:  # props stand on flat ground only, so nothing floats
        return None
    if not (site.routes_clear(q, route_clear) and site.markers_clear(q, CLEAR) and site.in_bounds(q)):
        return None
    if not site.free(_quad(x, z, theta, _grow(rect, grow))):
        return None
    return q


def plan_props(layout, grid, plan, site=None):
    """Cover clusters and street lamps: [{kind: "cover" | "lamp", id, x, z, theta}].

    Cover (brief, PROPOSAL 1 cluster per COVER_EVERY studs of quiet route): beside each quiet route, sides alternating
    (the other side when one is blocked), 1 stud off its corridor; and in the back yards, 1 per COVER_EVERY studs of
    built frontage, behind the row. Lamps (PROPOSAL 1 per LAMP_EVERY studs of public or road route, sides alternating)
    1.5 studs off the corridor's middle line past its edge. All keep off every corridor, marker, building, landmark
    and each other, on flat dry ground inside the edge band. The alleys between buildings stay open."""
    site = site or _Site(layout, grid)
    for b in plan:
        site.taken.append((b["clear"], "building"))
    kit = kits.kit_of(layout)
    out = []
    cr = kit.COVER[2]
    half = max(abs(v) for v in cr)
    for r in layout["Routes"]:
        if r["Kind"] != "quiet":
            continue
        for x, z, ux, uz, j in _along(r["Line"], COVER_EVERY):
            off = r["Width"] / 2 + 1 + half
            for sd in ((1, -1) if j % 2 == 0 else (-1, 1)):
                px, pz = x - uz * sd * off, z + ux * sd * off
                th = math.atan2(uz, ux)
                q = _spot_ok(site, grid, px, pz, th, cr, 1.0, 1.0)
                if q:
                    site.taken.append((q, "cover"))
                    out.append({"kind": "cover", "id": f"{r['Id']}_{j}", "x": px, "z": pz, "theta": th})
                    break
    rows = {}
    for b in plan:
        rows.setdefault(b["frontage"], []).append(b)
    for key, bs in rows.items():
        k = max(1, int(round(sum(b["w"] for b in bs) / COVER_EVERY)))
        for j in range(k):
            b = bs[min(len(bs) - 1, int((j + 0.5) * len(bs) / k))]
            back = b["d"] / 2 + OVERHANG + 1 + half  # behind the back wall, in the yard
            c, s = math.cos(b["theta"]), math.sin(b["theta"])
            px, pz = b["x"] - s * back, b["z"] + c * back
            q = _spot_ok(site, grid, px, pz, b["theta"], cr, 1.0, 1.0)
            if q:
                site.taken.append((q, "cover"))
                out.append({"kind": "cover", "id": f"yard_{key.replace(':', '_')}_{j}", "x": px, "z": pz,
                            "theta": b["theta"]})
    lr = kit.LAMP_FOOT
    for r in layout["Routes"]:
        if r["Kind"] not in ("public", "road"):
            continue
        for x, z, ux, uz, j in _along(r["Line"], LAMP_EVERY):
            off = r["Width"] / 2 + 1.5
            for sd in ((1, -1) if j % 2 == 0 else (-1, 1)):
                px, pz = x - uz * sd * off, z + ux * sd * off
                q = _spot_ok(site, grid, px, pz, 0.0, lr, 0.6, 0.5)
                if q:
                    site.taken.append((q, "lamp"))
                    out.append({"kind": "lamp", "id": f"{r['Id']}_{j}", "x": px, "z": pz, "theta": 0.0})
                    break
    return out


def plan_edges(layout):
    """The edge ridge blocks: [(side, x0, z0, x1, z1)] in the EDGE_BAND round the footprint, at most EDGE_SEG long,
    broken wherever an EdgeGap marker's Box meets the band. N and S run the full width (split at the corner squares,
    which edges() builds as full-height bastions, so the ridge never dips where two sides meet); W and E run between
    them."""
    fw, fd = layout["Footprint"]
    hw, hd, B = fw / 2, fd / 2, EDGE_BAND
    gaps = [m["Box"] for m in layout["Markers"] if m["Tag"] == "EdgeGap"]
    sides = {"N": ("x", -hw, hw, -hd, -hd + B), "S": ("x", -hw, hw, hd - B, hd),
             "W": ("z", -hd + B, hd - B, -hw, -hw + B), "E": ("z", -hd + B, hd - B, hw - B, hw)}
    out = []
    for side, (axis, lo, hi, c0, c1) in sides.items():
        cuts = []
        for (gx0, _, gz0), (gx1, _, gz1) in gaps:
            a0, a1, b0, b1 = (gx0, gx1, gz0, gz1) if axis == "x" else (gz0, gz1, gx0, gx1)
            if b1 > c0 and b0 < c1 and a1 > lo and a0 < hi:
                cuts.append((max(lo, a0), min(hi, a1)))
        if axis == "x":  # the corner squares are blocks of their own
            cuts += [(lo + B, lo + B), (hi - B, hi - B)]
        spans, p = [], lo
        for a0, a1 in sorted(cuts):
            if a0 > p + 1e-9:
                spans.append((p, a0))
            p = max(p, a1)
        if p < hi:
            spans.append((p, hi))
        for p, q in spans:
            n = max(1, int(math.ceil((q - p) / EDGE_SEG - 1e-9)))
            for i in range(n):
                a0, a1 = p + (q - p) * i / n, p + (q - p) * (i + 1) / n
                out.append((side, a0, c0, a1, c1) if axis == "x" else (side, c0, a0, c1, a1))
    return out


# ------------------------------------------------------------------ the style kits: stages
def _settle(root, grid, rect=None):
    """Sets a prefab on the ground: its floor (root z) at the highest ground under its footing (rect, a local
    [x0, y0, x1, y1], grown by FOOTING; by default the box round the parts that stand on the floor), and a footing
    block down to the lowest ground when the ground under it isn't flat. Sets root["rs_foot"] (the footing rect, local)
    and root["rs_floor"]. Returns the parts it added."""
    if rect is None:
        pts = [o.matrix_basis @ Vector(c) for o in root.children if o.type == "MESH" and o.get("rs_kind")
               for c in o.bound_box]
        pts = [p for p in pts if p.z <= 0.05] or pts
        rect = (min(p.x for p in pts), min(p.y for p in pts), max(p.x for p in pts), max(p.y for p in pts))
    foot = _grow(rect, FOOTING)
    lo, hi, _ = _ground_stats(grid, root.location.x, root.location.y, root.rotation_euler.z, foot)
    root.location.z = hi
    root["rs_foot"] = list(foot)
    root["rs_floor"] = hi
    if hi - lo > 0.05:
        h = hi - lo + 0.5
        kits.railtown.pb(root, "Footing", (foot[2] - foot[0], foot[3] - foot[1], h),
                         ((foot[0] + foot[2]) / 2, (foot[1] + foot[3]) / 2, -h / 2), "stone", bevel=0.08)
        return 1
    return 0


def _stoop(root, grid, w, d):
    """Steps from a building's front door down to the street when its floor stands above it: risers of 1 stud or
    less, and a block under the kit's door step. Returns the parts it added."""
    dx = float(root.get("rs_door_x", 0.0))
    floor = root.location.z
    lo, _, _ = _ground_stats(grid, root.location.x, root.location.y, root.rotation_euler.z,
                             (-w / 2, -d / 2 - 2.4, w / 2, -d / 2 - 1.2))
    rise = floor - lo
    if rise <= 0.05:
        return 0
    base = lo - 0.5 - floor
    n = int(math.ceil(rise - 1e-9)) - 1 if rise > 1 + 1e-9 else 0
    kits.railtown.pb(root, "StepFooting", (4.6, 1.2, -base), (dx, -d / 2 - 0.6, base / 2), "stone", bevel=0.06)
    for j in range(1, n + 1):
        top = -j * rise / (n + 1)
        kits.railtown.pb(root, f"Stoop{j}", (4.6, STEP_TREAD + 0.05, top - base),
                         (dx, -d / 2 - 1.2 - (j - 0.5) * STEP_TREAD, (top + base) / 2), "stone", bevel=0.06)
    return n + 1


def buildings(layout, grid):
    """Group Buildings: the planned buildings (plan_buildings), one prefab each: kind = the style's Roblox kind,
    id = <district>_<n>. Root props (Blender only, not exported): rs_style, rs_district, rs_frontage, rs_party,
    rs_body (the walls, local), rs_foot (the footing, local), rs_floor. Returns the part count."""
    kits.bind(materials.palette(layout))
    c = clear_group(layout, "Buildings")
    n = 0
    for b in plan_buildings(layout, grid):
        root = prefab(c, b["kind"], b["id"], bl(b["x"], 0, b["z"]))
        root.rotation_euler = (0, 0, b["theta"])
        root["rs_style"], root["rs_district"], root["rs_frontage"] = b["style"], b["district"], b["frontage"]
        root["rs_party"] = b["party"]
        root["rs_body"] = [-b["w"] / 2, -b["d"] / 2, b["w"] / 2, b["d"] / 2]
        n += len(b["fn"](root, random.Random(b["seed"]), b["w"], b["d"], b["storeys"]))
        n += _settle(root, grid, rect=tuple(root["rs_body"]))
        n += _stoop(root, grid, b["w"], b["d"])
    return n


def landmarks(layout, grid):
    """Group Landmarks: each landmark's kit function, its prefab at At turned to its Yaw (front = local -y = the
    Roblox LookVector), settled on the ground; then the region kit's underworks tunnel sections along every under
    route, about 16 studs each. Returns the part count."""
    kits.bind(materials.palette(layout))
    c = clear_group(layout, "Landmarks")
    n = 0
    for lm in layout["Landmarks"]:
        mod, entry, what = kits.piece(lm["Kind"])
        if what != "landmark":
            raise ValueError(f"landmark {lm['Id']}: {lm['Kind']} is a building style, not a landmark")
        root = prefab(c, entry[0], lm["Id"], bl(lm["At"][0], 0, lm["At"][1]))
        root.rotation_euler = (0, 0, -math.radians(lm.get("Yaw", 0)))
        root["rs_style"] = lm["Kind"]
        n += len(entry[1](root, random.Random(f"{layout['Region']}:{lm['Id']}")))
        n += _settle(root, grid)
    kit = kits.kit_of(layout)
    if "underworks" in kit.LANDMARKS:
        kind, fn, _ = kit.LANDMARKS["underworks"]
        for r in layout["Routes"]:
            if r["Kind"] != "under":
                continue
            for si, (a, b) in enumerate(zip(r["Line"], r["Line"][1:])):
                L = math.hypot(b[0] - a[0], b[1] - a[1])
                if L == 0:
                    continue
                m = max(1, int(round(L / 16)))
                for j in range(m):
                    t = (j + 0.5) / m
                    root = prefab(c, kind, f"{r['Id']}_{si}_{j}",
                                  bl(a[0] + (b[0] - a[0]) * t, 0, a[1] + (b[1] - a[1]) * t))
                    root.rotation_euler = (0, 0, math.atan2(b[1] - a[1], b[0] - a[0]))
                    root["rs_style"] = f"{kit.__name__.rpartition('.')[2]}.underworks"
                    root["rs_len"] = L / m
                    n += len(fn(root, random.Random(f"{layout['Region']}:{r['Id']}:{si}:{j}")))
                    n += _settle(root, grid)
    return n


def cover(layout, grid):
    """Group Cover: cover clusters (kind Cover) and street lamps (kind LampPost: a NightOnly glow and a light) from
    plan_props. Returns the part count."""
    kits.bind(materials.palette(layout))
    c = clear_group(layout, "Cover")
    kit = kits.kit_of(layout)
    n = 0
    for p in plan_props(layout, grid, plan_buildings(layout, grid)):
        if p["kind"] == "cover":
            root = prefab(c, kit.COVER[0], p["id"], bl(p["x"], 0, p["z"]))
            root.rotation_euler = (0, 0, p["theta"])
            n += len(kit.COVER[1](root, random.Random(f"{layout['Region']}:cover:{p['id']}")))
            n += _settle(root, grid, rect=kit.COVER[2])
        else:
            root = prefab(c, "LampPost", p["id"], bl(p["x"], 0, p["z"]))
            n += len(kit.lamp(root, "Lamp", 0.0, 0.0))
            n += _settle(root, grid, rect=kit.LAMP_FOOT)
    return n


def edges(layout, grid):
    """Group Edges: slag ridges in the EDGE_BAND round the footprint (plan_edges), one prefab per side. Each block is
    three stepped tiers rising outward (base: the whole band; middle: the outer two thirds; top: the outer third),
    the base from 1 stud below the lowest ground under it, the top at least EDGE_HEIGHT over the highest. EdgeGap
    boxes stay open. Returns the part count."""
    M = materials.palette(layout)
    c = clear_group(layout, "Edges")
    roots, n = {}, 0
    rng = random.Random(f"{layout['Region']}:edges")
    for j, (side, x0, z0, x1, z1) in enumerate(plan_edges(layout)):
        root = roots.get(side) or roots.setdefault(side, prefab(c, "Edge", side, (0, 0, 0)))
        lo, hi, _ = _ground_stats(grid, (x0 + x1) / 2, (z0 + z1) / 2, 0.0,
                                  (-(x1 - x0) / 2, -(z1 - z0) / 2, (x1 - x0) / 2, (z1 - z0) / 2))
        bottom = lo - 1
        t1 = hi + round(rng.uniform(8, 11), 1)  # PROPOSAL tier heights
        t2 = t1 + round(rng.uniform(6, 9), 1)
        t3 = max(hi + EDGE_HEIGHT + round(rng.uniform(0, 6), 1), t2 + 3)
        out = {"N": (0, -1), "S": (0, 1), "W": (-1, 0), "E": (1, 0)}[side]
        hw = layout["Footprint"][0] / 2
        corner = side in "NS" and (x1 <= -hw + EDGE_BAND + 1e-9 or x0 >= hw - EDGE_BAND - 1e-9)
        for name, frac, zb, zt, mat in (("Base", 1.0, bottom, t1, "slag"),
                                         ("Mid", 1.0 if corner else 0.66, t1 - 0.5, t2, "cinder_dark"),
                                         ("Top", 1.0 if corner else 0.33, t2 - 0.5, t3, "slag")):
            if out[0]:  # W / E: the tier keeps the outer frac of the band's depth
                dd = (x1 - x0) * frac
                bx0, bx1 = (x0, x0 + dd) if out[0] < 0 else (x1 - dd, x1)
                bz0, bz1 = z0, z1
            else:
                dd = (z1 - z0) * frac
                bz0, bz1 = (z0, z0 + dd) if out[1] < 0 else (z1 - dd, z1)
                bx0, bx1 = x0, x1
            part(root, f"{name}{j}", (bx1 - bx0, bz1 - bz0, zt - zb), bl((bx0 + bx1) / 2, (zb + zt) / 2, (bz0 + bz1) / 2),
                 M[mat], bevel=0.3)
            n += 1
    return n


def kit_gallery(layout, collection="KitGallery"):
    """Builds every style (at its largest size, 3 storeys) and every landmark of every kit in a row along +x, in the
    collection `collection` (linked to the scene, outside Region_<Region>), for checks and a kit render. Every root
    and part carries rs_gallery = "<kit>.<piece>". Returns {"<kit>.<piece>": parts}. Revert the file afterwards."""
    kits.bind(materials.palette(layout))
    c = bpy.data.collections.get(collection) or bpy.data.collections.new(collection)
    if c.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(c)
    out, cursor = {}, 0.0
    for kname, mod in kits.KITS.items():
        items = [(f"{kname}.{k}", e[0], (lambda r, g, e=e: e[1](r, g, e[2][1], e[2][3], 3)))
                 for k, e in mod.STYLES.items()]
        items += [(f"{kname}.{k}", e[0], e[1]) for k, e in mod.LANDMARKS.items()]
        for name, kind, fn in items:
            root = prefab(c, kind, f"gallery_{name.partition('.')[2]}", (0, 0, 0))
            root["rs_gallery"] = name
            parts = fn(root, random.Random(name))
            for o in root.children:
                o["rs_gallery"] = name
            out[name] = len(parts)
            xs = [(o.matrix_basis @ Vector(cn)).x for o in root.children if o.type == "MESH" for cn in o.bound_box]
            root.location.x = cursor - min(xs)
            cursor += max(xs) - min(xs) + 12
    return out


# ------------------------------------------------------------------ markers
def markers(layout, grid):
    """Group Markers: one prefab holding an invisible, non-colliding part per marker (Studio hides helpers: export
    field 14 = 1). A point marker is a 2 x 2 x 2 part standing on its spot (At y = 0 snaps to the ground; any other y
    is an absolute height); a Box marker is its box. rs_tags = the Tag, rs_attr = the Attr JSON (when it has any),
    and the Yaw turns the part (a Post's facing is the part's front). Returns the part count."""
    M = materials.palette(layout)
    c = clear_group(layout, "Markers")
    root = prefab(c, "Markers", layout["Region"], (0, 0, 0))
    n = 0
    for j, m in enumerate(layout["Markers"]):
        if m["Tag"] in schema.BUILDER_TAGS:  # read by the builder (EdgeGap: the edges stage), never exported
            continue
        if "Box" in m:
            (x0, y0, z0), (x1, y1, z1) = m["Box"]
            size, at = (x1 - x0, z1 - z0, y1 - y0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
        else:
            x, y, z = m["At"]
            if y == 0:
                y = ground_y(grid, x, z)
            size, at = (2, 2, 2), (x, y + 1, z)
        o = part(root, f"{m['Tag']}{j}", size, bl(*at), M["helper"], rot=(0, 0, math.radians(-m.get("Yaw", 0))))
        o["rs_invisible"] = True
        o["rs_tags"] = m["Tag"]
        if m.get("Attr"):
            o["rs_attr"] = json.dumps(m["Attr"])
        o.hide_render = True
        o.display_type = "WIRE"
        n += 1
    return n


# ------------------------------------------------------------------ lighting and renders
def _engine(s):
    for e in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            s.render.engine = e
            return e
        except TypeError:
            continue
    return s.render.engine


def lighting(layout):
    """A sooty overcast sky and a near-white sun (so the palette's hex colours read true; PROPOSAL), EEVEE at
    1920 x 1080."""
    s = bpy.context.scene
    c = clear_group(layout, "Lighting")
    w = bpy.data.worlds.get(f"RG_{layout['Region']}_World") or bpy.data.worlds.new(f"RG_{layout['Region']}_World")
    s.world = w
    try:
        w.use_nodes = True
    except Exception:
        pass
    bg = w.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (*srgb("8c8a86"), 1)
    bg.inputs["Strength"].default_value = 1.5
    sun = bpy.data.lights.new(f"RG_{layout['Region']}_Sun", "SUN")
    sun.energy = 3.0
    sun.color = srgb("ffeedd")
    sun.angle = math.radians(3)
    o = bpy.data.objects.new(sun.name, sun)
    # shining toward the south-south-east, so the north and west faces the cameras look at are lit
    o.rotation_euler = (math.radians(50), 0, math.radians(-30))
    c.objects.link(o)
    _engine(s)
    s.render.resolution_x, s.render.resolution_y, s.render.resolution_percentage = 1920, 1080, 100
    s.render.image_settings.file_format = "PNG"
    try:  # Standard keeps the palette's hex colours close to how Roblox shows them
        s.view_settings.view_transform = "Standard"
        s.view_settings.look = "None"
    except TypeError:
        pass
    return o


def _camera(layout, name, eye, target, lens):
    c = group(layout, "Lighting")
    cd = bpy.data.cameras.get(f"Cam_{name}") or bpy.data.cameras.new(f"Cam_{name}")
    cam = bpy.data.objects.get(f"Cam_{name}") or bpy.data.objects.new(f"Cam_{name}", cd)
    if cam.name not in c.objects:
        c.objects.link(cam)
    cd.lens, cd.clip_start, cd.clip_end = lens, 0.5, 8000
    p, t = Vector(bl(*eye)), Vector(bl(*target))
    cam.location = p
    cam.rotation_euler = (t - p).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    return cam


def _nearest_route_point(layout, x, z):
    best = None
    for r in layout["Routes"]:
        if r["Kind"] not in ("public", "road", "quiet"):
            continue
        for a, b in zip(r["Line"], r["Line"][1:]):
            dx, dz = b[0] - a[0], b[1] - a[1]
            L2 = dx * dx + dz * dz
            t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((x - a[0]) * dx + (z - a[1]) * dz) / L2))
            p = (a[0] + t * dx, a[1] + t * dz)
            d = math.hypot(p[0] - x, p[1] - z)
            if best is None or d < best[0]:
                best = (d, p)
    return best


def shots(layout, grid):
    """{name: (eye (x, y, z), target (x, y, z), lens)}: the aerial, then a street view per district and landmark.
    A district with a frontage (frontages()) is shot from out in front of its longest one, looking back at the building
    fronts. Otherwise (and for landmarks) the shot is taken from the nearest public, road or quiet route (or 40 studs
    south when none is within 120 studs)."""
    fw, fd = layout["Footprint"]
    span = max(fw, fd)
    hw, hd = fw / 2 - 1, fd / 2 - 1
    out = {"aerial": ((-0.42 * fw, 0.62 * span, -0.78 * fd), (0, 0, 0.05 * fd), 28)}
    targets = []
    for d in layout["Districts"]:
        poly = d["Poly"]
        fr = sorted(frontages(layout, d), key=lambda f: -f["L"])
        if fr:
            f = fr[0]
            (ax, az), (ux, uz), (nx, nz), L = f["a"], f["u"], f["n"], f["L"]
            mx, mz = ax + ux * L / 2, az + uz * L / 2
            ex, ez = mx + nx * 30 + ux * L * 0.2, mz + nz * 30 + uz * L * 0.2  # PROPOSAL: 30 out, a little along
            ex, ez = max(-hw, min(hw, ex)), max(-hd, min(hd, ez))
            tx, tz = mx - nx * 8, mz - nz * 8
            out[f"district {d['Id']}"] = ((ex, ground_y(grid, ex, ez) + EYE, ez), (tx, ground_y(grid, tx, tz) + 5, tz), 24)
            continue
        targets.append((f"district {d['Id']}", sum(p[0] for p in poly) / len(poly), sum(p[1] for p in poly) / len(poly)))
    for m in layout["Landmarks"]:
        targets.append((f"landmark {m['Id']}", m["At"][0], m["At"][1]))
    for name, tx, tz in targets:
        near = _nearest_route_point(layout, tx, tz)
        if near and 8 < near[0] < 120:
            d, (ex, ez) = near
            ex, ez = ex - (tx - ex) / d * 10, ez - (tz - ez) / d * 10  # step back 10 studs along the line of sight
        else:
            ex, ez = tx, tz + 40
        ex, ez = max(-hw, min(hw, ex)), max(-hd, min(hd, ez))
        eye = (ex, ground_y(grid, ex, ez) + EYE, ez)
        out[name] = (eye, (tx, ground_y(grid, tx, tz) + 3, tz), 24)
    return out


def _flip_x(path):
    """Mirror a saved PNG left-right so it shows the place as Studio will (see the module doc)."""
    import numpy as np
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    img.pixels.foreach_set(px.reshape(h, w, 4)[:, ::-1, :].ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def render(layout, out_dir, grid=None, samples=32, names=None):
    """Renders the shots (all, or `names`) to out_dir as '<Region> - <shot>.png'. Returns the paths."""
    s = bpy.context.scene
    grid = grid or HF.sample(layout)
    os.makedirs(out_dir, exist_ok=True)
    if not s.world or not any(o.type == "LIGHT" for o in s.objects):
        lighting(layout)
    try:
        s.eevee.taa_render_samples = samples
    except AttributeError:
        pass
    paths = []
    for name, (eye, target, lens) in shots(layout, grid).items():
        if names and name not in names:
            continue
        _camera(layout, name.replace(" ", "_"), eye, target, lens)
        path = os.path.join(out_dir, f"{layout['Region']} - {name}.png")
        s.render.filepath = path
        bpy.ops.render.render(write_still=True, scene=s.name)
        _flip_x(path)
        paths.append(path)
    return paths

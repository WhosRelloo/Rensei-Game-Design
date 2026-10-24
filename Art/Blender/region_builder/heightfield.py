"""Heights from a region file's Heights shapes, sampled on a cell grid (spec 2026-10-23 §3.2, the ground stage).

Cell (i, k) covers x in [origin x + i*cell, + cell) and z in [origin z + k*cell, + cell); i runs east, k south.
Its top is the shapes' height at the cell centre, rounded to a whole stud (the 1-stud steps of ground.lua v4).

Shapes apply in file order, each on the height the earlier ones left (later wins):
  plane  sets Y everywhere;
  box    sets Y inside Rect, and blends linearly from Y at the box's edge to the height beneath at Edge studs out;
  ridge  raises to Y on its Line, falling linearly to the height beneath at Width studs from it (never lowers);
  cut    lowers to Y inside Rect (never raises);
  water  sets the ground to Bed inside Rect and records the water box (Top is terrain water in Studio).
No bpy; standard library only."""
import math
from dataclasses import dataclass, field

RAMP_SLOPE = 0.6  # corner-height spread (studs) above which a route cell is a ramp, as ground.lua
EDGE_DROP = 12  # a column at the grid's edge reaches this far below its top, as ground.lua's missing neighbour

# Route Kind -> ground kind. rail, under and ledge leave the ground as it is: the routes stage builds them
# (rail walks, tunnels, ledges) on top. PROPOSAL: road is paved like a public route.
ROUTE_GROUND = {"public": "path", "road": "path", "quiet": "quiet"}
# where routes overlap, the higher rank wins; water beats every route (PROPOSAL)
RANK = {"top": 0, "quiet": 1, "path": 2, "water": 3}


@dataclass
class Grid:
    origin: tuple  # (x, z) of cell (0, 0)'s north-west corner, in studs
    cell: int
    top: list  # top[i][k]: int, ground height in studs
    kind: list  # kind[i][k]: "top" | "path" | "quiet" | "water"
    water: list = field(default_factory=list)  # (x0, z0, x1, z1, top, bed) per water shape

    @property
    def nx(self):
        return len(self.top)

    @property
    def nz(self):
        return len(self.top[0]) if self.top else 0

    def centre(self, i, k):
        return self.origin[0] + (i + 0.5) * self.cell, self.origin[1] + (k + 0.5) * self.cell


# ------------------------------------------------------------------ geometry
def _rect(r):
    return min(r[0], r[2]), min(r[1], r[3]), max(r[0], r[2]), max(r[1], r[3])


def rect_dist(x, z, r):
    """Distance from (x, z) to the rectangle [x0, z0, x1, z1]; 0 inside or on its edge."""
    x0, z0, x1, z1 = _rect(r)
    return math.hypot(max(x0 - x, 0.0, x - x1), max(z0 - z, 0.0, z - z1))


def line_dist(x, z, line):
    """Distance from (x, z) to the polyline [[x, z], ...]."""
    best = math.inf
    for (ax, az), (bx, bz) in zip(line, line[1:]):
        dx, dz = bx - ax, bz - az
        L2 = dx * dx + dz * dz
        t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((x - ax) * dx + (z - az) * dz) / L2))
        best = min(best, math.hypot(x - (ax + t * dx), z - (az + t * dz)))
    return best


# ------------------------------------------------------------------ heights
def height_at(layout, x, z):
    """The shapes' height at (x, z), before rounding. 0 where no shape reaches."""
    h = 0.0
    for s in layout["Heights"]:
        kind = s["Kind"]
        if kind == "plane":
            h = s["Y"]
        elif kind == "box":
            d = rect_dist(x, z, s["Rect"])
            edge = s.get("Edge", 0)
            if d == 0:
                h = s["Y"]
            elif d < edge:
                h = s["Y"] + (h - s["Y"]) * (d / edge)
        elif kind == "ridge":
            d = line_dist(x, z, s["Line"])
            if d < s["Width"] and s["Y"] > h:
                h = h + (s["Y"] - h) * (1 - d / s["Width"])
        elif kind == "cut":
            if rect_dist(x, z, s["Rect"]) == 0:
                h = min(h, s["Y"])
        elif kind == "water":
            if rect_dist(x, z, s["Rect"]) == 0:
                h = s["Bed"]
    return h


def _round(h):
    return int(math.floor(h + 0.5))


def sample(layout, cell=4):
    """Samples the layout's Heights and Routes on a grid of cell-stud cells covering the footprint."""
    fw, fd = layout["Footprint"]
    if fw % cell or fd % cell:
        raise ValueError(f"Footprint {fw}x{fd} is not a whole number of {cell}-stud cells")
    nx, nz = int(fw // cell), int(fd // cell)
    origin = (-fw / 2, -fd / 2)
    if origin[0] == int(origin[0]) and origin[1] == int(origin[1]):
        origin = (int(origin[0]), int(origin[1]))
    G = Grid(origin=origin, cell=cell, top=[[0] * nz for _ in range(nx)], kind=[["top"] * nz for _ in range(nx)])
    waters = [s for s in layout["Heights"] if s["Kind"] == "water"]
    for s in waters:
        x0, z0, x1, z1 = _rect(s["Rect"])
        G.water.append((x0, z0, x1, z1, s["Top"], s["Bed"]))
    routes = [(ROUTE_GROUND[r["Kind"]], r) for r in layout["Routes"] if r["Kind"] in ROUTE_GROUND]
    for i in range(nx):
        for k in range(nz):
            x, z = G.centre(i, k)
            G.top[i][k] = _round(height_at(layout, x, z))
            kd = "top"
            for gk, r in routes:
                if RANK[gk] > RANK[kd] and line_dist(x, z, r["Line"]) <= r["Width"] / 2:
                    kd = gk
            if any(rect_dist(x, z, s["Rect"]) == 0 for s in waters):
                kd = "water"
            G.kind[i][k] = kd
    return G


def columns(grid):
    """One column per cell: (i, k, top, bottom, kind). The bottom is closed down to 1 below the lowest
    neighbour's top so every step shows a side face, and at least 2 below its own top, as ground.lua."""
    out = []
    T = grid.top
    nx, nz = grid.nx, grid.nz
    for i in range(nx):
        for k in range(nz):
            t = T[i][k]
            lo = t - 2
            for di, dk in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ii, kk = i + di, k + dk
                n = T[ii][kk] if 0 <= ii < nx and 0 <= kk < nz else t - EDGE_DROP
                lo = min(lo, n - 1)
            out.append((i, k, t, lo, grid.kind[i][k]))
    return out


def corners(grid, layout, i, k):
    """The unrounded heights at a cell's 4 corners: (x0 z0, x1 z0, x0 z1, x1 z1), as ground.lua's a, b, c, d."""
    x0, z0 = grid.origin[0] + i * grid.cell, grid.origin[1] + k * grid.cell
    x1, z1 = x0 + grid.cell, z0 + grid.cell
    return (height_at(layout, x0, z0), height_at(layout, x1, z0),
            height_at(layout, x0, z1), height_at(layout, x1, z1))


def ramps(grid, layout):
    """Route cells (path or quiet) on a slope: corner heights spread by more than RAMP_SLOPE studs."""
    out = set()
    for i in range(grid.nx):
        for k in range(grid.nz):
            if grid.kind[i][k] in ("path", "quiet"):
                c = corners(grid, layout, i, k)
                if max(c) - min(c) > RAMP_SLOPE:
                    out.add((i, k))
    return out

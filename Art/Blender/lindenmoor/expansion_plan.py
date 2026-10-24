"""Lindenmoor expansion, the pure half (no bpy): reads Art/Regions/Lindenmoor/layout.json and plans everything the
Blender stages build. Run the checks with: python -I Art/Blender/lindenmoor/expansion_tests.py

Frames:
  * world (the region file): x = east, z = NORTH (Ye's convention), y = height of the ground top; the footprint centre is
    world (0, 0) (assumed: the template Baseplate's centre; its top is y 0).
  * village local (world.py, export.py, terrain_studio.json): world - (0, 4, -650).
  * Blender (expansion.py builds in the village's Blender frame so export.py works unchanged):
      bx = X, by = Z + 650, bz = Y - 4.
Semantics of the Heights kinds follow the region-foundation plan, Task 8 (plane / box / ridge / cut / water, later wins).
Every number invented here is a PROPOSAL."""
import json, math, os, random
from collections import deque

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
LAYOUT = os.path.join(REPO, "Art", "Regions", "Lindenmoor", "layout.json")
TERRAIN = os.path.join(HERE, "terrain_studio.json")
VILLAGE_O = (0.0, 4.0, -650.0)  # measured: the Lindenmoor kit origin in Ye

CELL = 4
HALF = 1024
N = 2 * HALF // CELL  # 512 cells per side
SEAM = 64  # studs over which new ground blends into the village's edge (PROPOSAL)
WALL_Y = 150  # tops at or above this are the edge wall (no noise, no trees)
MAX_SPAN = 32  # merge rectangles up to 32 cells (128 studs) a side (PROPOSAL; ground.lua merged similarly)
TERRACE = 3  # wild slopes round to 3-stud terraces (PROPOSAL; the reference's stacked terraces)
ROUTE_SLOPE = {"road": 0.3, "quiet": 0.42, "rail": 0.025, "ledge": 0.0, "public": 0.3}  # rise per stud (PROPOSAL)
PAD = {  # flat pad radius (studs) under each landmark kind (PROPOSAL)
    "lindenmoor.farmstead": 54, "lindenmoor.roadside_market": 22, "lindenmoor.watermill": 18, "lindenmoor.stone_bridge": 0,
    "lindenmoor.level_crossing": 0, "lindenmoor.training_field": 0, "lindenmoor.ridge_marker": 9, "lindenmoor.overlook": 12,
    "lindenmoor.mine_head": 42, "lindenmoor.lookout": 14, "lindenmoor.footbridge": 0, "lindenmoor.gorge_ledge": 0,
    "lindenmoor.waterfall": 0, "lindenmoor.hay_barn": 22, "lindenmoor.signal_box": 9, "lindenmoor.road_gate": 0,
    "lindenmoor.tunnel_portals": 0, "lindenmoor.reserve": 0,
}


def pad_r(lm):
    """A landmark's flat pad radius: its own Radius (reserved spots) or its kind's."""
    return lm.get("Radius", PAD.get(lm["Kind"], 0))


# ------------------------------------------------------------------ small geometry
def lerp(a, b, t):
    return a + (b - a) * t


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def seg_dist(px, pz, ax, az, bx, bz):
    dx, dz = bx - ax, bz - az
    L2 = dx * dx + dz * dz
    t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / L2))
    qx, qz = ax + dx * t, az + dz * t
    return math.hypot(px - qx, pz - qz), t


def poly_dist(pts, x, z):
    best = (1e18, 0, 0.0)
    for k in range(len(pts) - 1):
        d, t = seg_dist(x, z, pts[k][0], pts[k][1], pts[k + 1][0], pts[k + 1][1])
        if d < best[0]:
            best = (d, k, t)
    return best


def in_rect(r, x, z):
    return r[0] <= x <= r[2] and r[1] <= z <= r[3]


def rect_dist(r, x, z):
    dx = max(r[0] - x, 0.0, x - r[2])
    dz = max(r[1] - z, 0.0, z - r[3])
    return math.hypot(dx, dz)


def in_poly(poly, x, z):
    inside = False
    n = len(poly)
    j = n - 1
    for i in range(n):
        xi, zi = poly[i]
        xj, zj = poly[j]
        if (zi > z) != (zj > z) and x < (xj - xi) * (z - zi) / (zj - zi) + xi:
            inside = not inside
        j = i
    return inside


def _hash(ix, iz, seed):
    h = (ix * 374761393 + iz * 668265263 + seed * 2147483647) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 32767.5 - 1.0


def vnoise(x, z, wl, seed=1):
    fx, fz = x / wl, z / wl
    ix, iz = math.floor(fx), math.floor(fz)
    tx, tz = smooth(fx - ix), smooth(fz - iz)
    a = lerp(_hash(ix, iz, seed), _hash(ix + 1, iz, seed), tx)
    b = lerp(_hash(ix, iz + 1, seed), _hash(ix + 1, iz + 1, seed), tx)
    return lerp(a, b, tz)


def cell_center(i, j):
    return -HALF + CELL * i + CELL / 2, -HALF + CELL * j + CELL / 2


def cell_of(x, z):
    return int(math.floor((x + HALF) / CELL)), int(math.floor((z + HALF) / CELL))


def to_blender(x, y, z):
    return (x - VILLAGE_O[0], z - VILLAGE_O[2], y - VILLAGE_O[1])


# ------------------------------------------------------------------ inputs
def load(path=LAYOUT):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


class Village:
    """terrain_studio.json in world terms: heights (world y) where the village's terrain exists."""

    def __init__(self, path=TERRAIN):
        with open(path, encoding="utf-8") as f:
            t = json.load(f)
        self.st, self.o, self.H = t["step"], t["origin"], t["H"]
        self.n = len(self.H)
        self.water = [(w[0] + VILLAGE_O[0], w[1] + VILLAGE_O[2], w[2] + VILLAGE_O[1], w[3] + VILLAGE_O[1]) for w in t["water"]]

    def _grid(self, X, Z):
        lx, lz = X - VILLAGE_O[0], Z - VILLAGE_O[2]
        return (lz - self.o) / self.st, (lx - self.o) / self.st  # (row, col)

    def has(self, X, Z):
        """Is there village terrain within half a grid step of (X, Z)?"""
        r, c = self._grid(X, Z)
        ri, ci = round(r), round(c)
        if 0 <= ri < self.n and 0 <= ci < self.n and abs(r - ri) <= 0.5 + 1e-9 and abs(c - ci) <= 0.5 + 1e-9:
            return self.H[ri][ci] is not None
        return False

    def height(self, X, Z):
        """World height of the nearest non-empty village cell (bilinear where all four corners exist)."""
        r, c = self._grid(X, Z)
        r = max(0.0, min(self.n - 1.0, r))
        c = max(0.0, min(self.n - 1.0, c))
        r0, c0 = int(math.floor(r)), int(math.floor(c))
        vals = []
        for dr in (0, 1):
            for dc in (0, 1):
                ri, ci = min(r0 + dr, self.n - 1), min(c0 + dc, self.n - 1)
                vals.append(self.H[ri][ci])
        if None not in vals:
            tr, tc = r - r0, c - c0
            a = lerp(vals[0], vals[1], tc)
            b = lerp(vals[2], vals[3], tc)
            return lerp(a, b, tr) + VILLAGE_O[1]
        best = None
        for rad in range(1, 6):
            for ri in range(r0 - rad, r0 + rad + 2):
                for ci in range(c0 - rad, c0 + rad + 2):
                    if 0 <= ri < self.n and 0 <= ci < self.n and self.H[ri][ci] is not None:
                        d = (ri - r) ** 2 + (ci - c) ** 2
                        if best is None or d < best[0]:
                            best = (d, self.H[ri][ci])
            if best:
                return best[1] + VILLAGE_O[1]
        return 4.0


# ------------------------------------------------------------------ the height field (shapes only)
def shape_height(layout, x, z, skip=()):
    """Heights shapes in order (Task 8 semantics). Returns (y, flat, crag): flat = no noise belongs here; crag = a box's
    Crag branch set the height (the edge crag, tagged RenseiNoGrip; a later shape that sets the height clears it)."""
    h, flat, crag = 0.0, False, False
    for s in layout["Heights"]:
        k = s["Kind"]
        if s.get("Id") in skip:
            continue
        if k == "plane":
            h, crag = s["Y"], False
        elif k == "box" and "Crag" in s:
            # an edge crag: the inner face juts in and out by up to Depth, the crest varies over Y, in Cell blocks
            cg = s["Crag"]
            c = cg.get("Cell", 16)
            bx, bz = (math.floor(x / c) + 0.5) * c, (math.floor(z / c) + 0.5) * c
            n1 = 0.5 + 0.5 * (0.7 * vnoise(bx, bz, 64, 11) + 0.3 * _hash(int(bx // c), int(bz // c), 12))
            n2 = 0.5 + 0.5 * (0.6 * vnoise(bx, bz, 96, 13) + 0.4 * _hash(int(bx // c), int(bz // c), 14))
            if rect_dist(s["Rect"], x, z) <= cg.get("Depth", 0) * max(0.0, min(1.0, n1)):
                h, flat, crag = round(cg["Y"][0] + (cg["Y"][1] - cg["Y"][0]) * max(0.0, min(1.0, n2))), True, True
        elif k == "box":
            d = rect_dist(s["Rect"], x, z)
            E = s.get("Edge", 0)
            if d == 0:
                h, crag = s["Y"], False
                if E == 0:
                    flat = True
            elif E > 0 and d < E:
                h, crag = lerp(s["Y"], h, d / E), False
        elif k == "ridge":
            d, _, _ = poly_dist(s["Line"], x, z)
            if d < s["Width"]:
                y = max(h, lerp(s["Y"], h, d / s["Width"]))
                h, crag = y, crag and y == h
        elif k == "cut":
            if "Line" in s:
                d, _, _ = poly_dist(s["Line"], x, z)
                hw, B = s["Width"] / 2, s.get("Bank", 0)
                if d <= hw:
                    h, flat, crag = s["Y"], True, False
                elif B and d < hw + B:
                    h, crag = lerp(s["Y"], h, smooth((d - hw) / B)), False
            elif in_rect(s["Rect"], x, z):
                h, flat, crag = s["Y"], True, False
        elif k == "water":
            if ("Line" in s and poly_dist(s["Line"], x, z)[0] <= s["Width"] / 2) or ("Rect" in s and in_rect(s["Rect"], x, z)):
                h, flat, crag = s["Bed"], True, False
    return h, flat, crag


def noise(x, z):
    return 2.4 * vnoise(x, z, 96, 3) + 1.1 * vnoise(x, z, 38, 7)  # PROPOSAL: gentle roll, about +-3.5


# ------------------------------------------------------------------ plan
class Plan:
    pass


def _route_profile(route, field_h, start_y=None):
    """Sample a route every 4 studs; heights follow the ground, smoothed and slope-clamped (ramps stay walkable)."""
    pts = route["Line"]
    samples = []  # (x, z, s)
    s = 0.0
    for k in range(len(pts) - 1):
        ax, az = pts[k]
        bx, bz = pts[k + 1]
        L = math.hypot(bx - ax, bz - az)
        n = max(1, int(math.ceil(L / 4)))
        for m in range(n):
            t = m / n
            samples.append((lerp(ax, bx, t), lerp(az, bz, t), s + L * t))
        s += L
    samples.append((pts[-1][0], pts[-1][1], s))
    hs = [field_h(x, z) for x, z, _ in samples]
    # moving average (window 9 = 32 studs)
    sm = []
    for i in range(len(hs)):
        lo, hi = max(0, i - 4), min(len(hs), i + 5)
        sm.append(sum(hs[lo:hi]) / (hi - lo))
    if start_y is not None:
        sm[0] = start_y
    slope = ROUTE_SLOPE.get(route["Kind"], 0.35)
    for _ in range(2):  # clamp the grade both ways
        for i in range(1, len(sm)):
            ds = samples[i][2] - samples[i - 1][2]
            sm[i] = max(min(sm[i], sm[i - 1] + slope * ds), sm[i - 1] - slope * ds)
        if start_y is not None:
            sm[0] = start_y
        for i in range(len(sm) - 2, -1, -1):
            ds = samples[i + 1][2] - samples[i][2]
            sm[i] = max(min(sm[i], sm[i + 1] + slope * ds), sm[i + 1] - slope * ds)
        if start_y is not None:
            sm[0] = start_y
    return [(x, z, s_, y) for (x, z, s_), y in zip(samples, sm)]


def _on_bridge(route, x, z):
    for (a, b) in route.get("Bridges", []):
        d, _ = seg_dist(x, z, a[0], a[1], b[0], b[1])
        if d <= 0.5:
            return True
    return False


def _bridge_t(route, x, z, pad=0.0):
    for (a, b) in route.get("Bridges", []):
        d, _ = seg_dist(x, z, a[0], a[1], b[0], b[1])
        if d <= pad:
            return True
    return False


SURVEY = os.path.join(REPO, "Art", "Studio", "Regions", "Lindenmoor", "ye_survey.json")  # survey_ye.lua's output


def ground_footprint(path=SURVEY):
    """The village Ground parts' footprint in Ye, measured by survey_ye.lua (GroundFootprint): the set of (i, j) 4-stud
    world cells whose centre lies inside any World.Map.Ground BasePart's XZ box (world AABB). Raises if it is missing."""
    with open(path, encoding="utf-8") as f:
        runs = json.load(f).get("GroundFootprint")
    if not runs:
        raise ValueError(f"{path} has no GroundFootprint: re-run Art/Studio/Regions/Lindenmoor/run_survey.py")
    return {cell_of(x0 + CELL / 2, z + CELL / 2) for x0, z0, z1 in runs for z in range(z0, z1, CELL)}


def terrain_mask(layout, village):
    """The Keep mask before Task 2: an N x N bool grid of village terrain cells (terrain_studio.json, within half an
    8-stud step of the cell centre) and Keep Rect cells (the Adit hill)."""
    rects = [k["Rect"] for k in layout.get("Keep", []) if "Rect" in k]
    m = [[False] * N for _ in range(N)]
    for i in range(N):
        x = -HALF + CELL * i + CELL / 2
        for j in range(N):
            z = -HALF + CELL * j + CELL / 2
            m[i][j] = village.has(x, z) or any(in_rect(r, x, z) for r in rects)
    return m


def keep_mask(layout, village, footprint=None):
    """The Keep mask, an N x N bool grid of 4-stud world cells where nothing new is built (controller Rulings 14, 15):
    village terrain cells (terrain_studio.json) outside the Keep Rects, plus every cell Ye's own parts cover
    (`footprint`, default ground_footprint(): World.Map.Ground and World.Map.HalvardsAdit). A Keep Rect (the Adit hill)
    is kept only where it is footprint; new ground fills the rest of it. So new ground never lands on old ground, and
    no kept cell is bare.
    One exception keeps the seam closed: a village terrain cell that no part covers and that touches an unkept cell is
    not kept either, so new ground fills it at the village's height (on the village's south edge row, z -982, where
    Ye's own ground has gaps). Shared by plan() and check_survey.py's infill_runs()."""
    if footprint is None:
        footprint = ground_footprint()
    foot = set(footprint)
    rects = [k["Rect"] for k in layout.get("Keep", []) if "Rect" in k]
    keep = [[False] * N for _ in range(N)]
    for i in range(N):
        x = -HALF + CELL * i + CELL / 2
        for j in range(N):
            z = -HALF + CELL * j + CELL / 2
            keep[i][j] = (i, j) in foot or (village.has(x, z) and not any(in_rect(r, x, z) for r in rects))
    out = [row[:] for row in keep]
    for i in range(N):
        for j in range(N):
            if keep[i][j] and (i, j) not in foot and any(
                    not keep[a][b] for a in range(max(0, i - 1), min(N, i + 2)) for b in range(max(0, j - 1), min(N, j + 2))):
                out[i][j] = False  # bare village edge cell: new ground fills it
    return out


def plan(layout=None, village=None, trees=True):
    L = layout or load()
    V = village or Village()
    P = Plan()
    P.layout, P.village = L, V

    # 1. keep mask (existing village ground and the Ground parts' footprint) and the seam source heights
    keep = keep_mask(L, V)
    vsrc = [[None] * N for _ in range(N)]
    for i in range(N):
        x = -HALF + CELL * i + CELL / 2
        for j in range(N):
            z = -HALF + CELL * j + CELL / 2
            if V.has(x, z):
                vsrc[i][j] = V.height(x, z)
    # seam: multi-source BFS from the village cells (not the Adit hill), up to SEAM studs
    seamd = [[None] * N for _ in range(N)]
    seamh = [[None] * N for _ in range(N)]
    dq = deque()
    for i in range(N):
        for j in range(N):
            if vsrc[i][j] is not None:
                seamd[i][j], seamh[i][j] = 0, vsrc[i][j]
                dq.append((i, j))
    lim = SEAM // CELL
    while dq:
        i, j = dq.popleft()
        d = seamd[i][j]
        if d >= lim:
            continue
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            a, b = i + di, j + dj
            if 0 <= a < N and 0 <= b < N and seamd[a][b] is None:
                seamd[a][b], seamh[a][b] = d + 1, seamh[i][j]
                dq.append((a, b))

    # route corridors and pads calm the noise (smooth ground beside paths and under set pieces)
    feats = [(r["Line"], r["Width"] / 2) for r in L["Routes"]]
    pads = [(lm["At"][0], lm["At"][1], pad_r(lm)) for lm in L["Landmarks"]]

    def calm(x, z):
        d = 1e9
        for line, hw in feats:
            d = min(d, poly_dist(line, x, z)[0] - hw)
        for px, pz, R in pads:
            d = min(d, math.hypot(px - x, pz - z) - R)
        return smooth((d - 6) / 30)

    # 2. base heights: shapes + noise + seam blend (edge walls, cuts and water untouched)
    h = [[0.0] * N for _ in range(N)]
    flat = [[False] * N for _ in range(N)]
    crag = [[False] * N for _ in range(N)]  # the edge crag (Task 2: RenseiNoGrip); flat, so later stages leave it be
    for i in range(N):
        x = -HALF + CELL * i + CELL / 2
        for j in range(N):
            z = -HALF + CELL * j + CELL / 2
            y, fl, crag[i][j] = shape_height(L, x, z)
            if not fl and y < WALL_Y:
                y += noise(x, z) * calm(x, z)
            if not fl and y < WALL_Y and seamd[i][j] is not None and (seamd[i][j] > 0 or not keep[i][j]):
                # seamd 0 and not kept: a bare village edge cell (keep_mask), built at the village's height
                y = lerp(seamh[i][j], y, smooth(seamd[i][j] * CELL / SEAM))
            h[i][j], flat[i][j] = y, fl
    P.h0 = [row[:] for row in h]

    def field(x, z):
        i, j = cell_of(x, z)
        i, j = max(0, min(N - 1, i)), max(0, min(N - 1, j))
        return h[i][j]

    # 3. landmark pads (flat ground under set pieces)
    P.landmarks = []
    for lm in L["Landmarks"]:
        R = pad_r(lm)
        x0, z0 = lm["At"]
        hc = round(field(x0, z0))
        if R > 0:
            ci, cj = cell_of(x0, z0)
            rr = int((R + 16) / CELL) + 1
            for i in range(max(0, ci - rr), min(N, ci + rr + 1)):
                for j in range(max(0, cj - rr), min(N, cj + rr + 1)):
                    if keep[i][j] or flat[i][j]:
                        continue
                    x, z = cell_center(i, j)
                    d = math.hypot(x - x0, z - z0)
                    if d <= R:
                        h[i][j] = hc
                    elif d < R + 16:
                        h[i][j] = lerp(hc, h[i][j], smooth((d - R) / 16))
        P.landmarks.append(dict(lm, GY=float(hc)))  # GY: the pad's ground height (a landmark's own Y stays)

    # 4. routes: profiles, corridor cells
    kind = [[None] * N for _ in range(N)]  # route kind under the cell
    near = [[99] * N for _ in range(N)]  # cells to the nearest route / pad (for the cell size)
    P.routes = []
    for r in L["Routes"]:
        if r["Kind"] == "ledge":
            P.routes.append(dict(r, Profile=[]))
            continue
        a = r["Line"][0]
        ia, ja = cell_of(a[0], a[1])
        start = None
        if r["Id"] == "rail_north":
            start = 8.1  # measured: Ye's rail top is local 5.2 = world 9.2; ballast top = rail top - 1.1
        elif r["Id"] == "north_road":
            start = 2.7  # measured: the north road's surface at the village edge (arrivals_lindenmoor.lua, local -1.3)
        elif 0 <= ia < N and 0 <= ja < N and seamh[ia][ja] is not None:
            start = seamh[ia][ja] if seamd[ia][ja] <= 2 else None
        prof = _route_profile(r, field, start)
        P.routes.append(dict(r, Profile=prof))
        half = r["Width"] / 2
        rr = int((half + 2) / CELL) + 1
        for (x, z, s, y) in prof:
            if _bridge_t(r, x, z, pad=1.0):
                continue
            ci, cj = cell_of(x, z)
            for i in range(max(0, ci - rr), min(N, ci + rr + 1)):
                for j in range(max(0, cj - rr), min(N, cj + rr + 1)):
                    cx, cz = cell_center(i, j)
                    d = math.hypot(cx - x, cz - z)
                    if d <= half + 1.5 and not keep[i][j] and h[i][j] < WALL_Y:
                        if kind[i][j] is None or kind[i][j] == "quiet":
                            kind[i][j] = r["Kind"]
                        # the ribbon sits on top; the cell under it stays at or below the ribbon's base
                        h[i][j] = min(h[i][j], math.floor(y) - (0 if r["Kind"] != "rail" else 1))
    # landmark pad cells count as "near" too
    srcs = deque()
    for i in range(N):
        for j in range(N):
            if kind[i][j] is not None:
                near[i][j] = 0
                srcs.append((i, j))
    for lm in P.landmarks:
        R = max(pad_r(lm), 8)
        ci, cj = cell_of(*lm["At"])
        rr = int(R / CELL)
        for i in range(max(0, ci - rr), min(N, ci + rr + 1)):
            for j in range(max(0, cj - rr), min(N, cj + rr + 1)):
                if near[i][j] > 0:
                    near[i][j] = 0
                    srcs.append((i, j))
    while srcs:
        i, j = srcs.popleft()
        d = near[i][j]
        if d >= 12:
            continue
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            a, b = i + di, j + dj
            if 0 <= a < N and 0 <= b < N and near[a][b] > d + 1:
                near[a][b] = d + 1
                srcs.append((a, b))

    # 4b. patchwork fields: level each field (it merges into big slabs) and keep it off routes and pads
    P.fields = make_fields(L, P, h, keep, kind, flat)
    for f in P.fields:
        i0, j0 = cell_of(f["Rect"][0] + 0.1, f["Rect"][1] + 0.1)
        i1, j1 = cell_of(f["Rect"][2] - 0.1, f["Rect"][3] - 0.1)
        for i in range(i0, i1 + 1):
            for j in range(j0, j1 + 1):
                h[i][j] = f["Y"]
                flat[i][j] = True
                near[i][j] = min(near[i][j], 8)

    # 5. quantize: 16-stud blocks where flat and far from features, 8 where gentle, 4 near routes/pads and on steep ground
    top = [[None] * N for _ in range(N)]
    res = [[4] * N for _ in range(N)]

    def slope_at(i, j):
        a, b = max(0, i - 1), min(N - 1, i + 1)
        c, d = max(0, j - 1), min(N - 1, j + 1)
        return max(abs(h[b][j] - h[a][j]) / ((b - a) * CELL or 1), abs(h[i][d] - h[i][c]) / ((d - c) * CELL or 1))

    for bi in range(0, N, 4):
        for bj in range(0, N, 4):
            cells = [(i, j) for i in range(bi, bi + 4) for j in range(bj, bj + 4)]
            live = [(i, j) for (i, j) in cells if not keep[i][j]]
            if not live:
                continue
            wall = all(h[i][j] >= WALL_Y for i, j in live)
            mixed_keep = len(live) != len(cells)
            nearmin = min(near[i][j] for i, j in live)
            anykind = any(kind[i][j] is not None for i, j in live)
            anyflat = any(flat[i][j] for i, j in live) and not all(flat[i][j] for i, j in live)
            hs_ = [h[i][j] for i, j in live]
            if any(v >= WALL_Y for v in hs_) and not wall:
                anyflat = True  # wall beside other ground: never average them together
            if all(flat[i][j] for i, j in live) and max(hs_) - min(hs_) > 1:
                anyflat = True  # different flat features (a cut beside a crag): keep each cell's height
            sl = max(slope_at(i, j) for i, j in live)
            if wall:
                r16 = 16
            elif anykind or nearmin <= 1 or mixed_keep or anyflat:
                r16 = 4
            elif nearmin <= 6:
                r16 = 8 if sl * 8 <= 3.5 else 4
            elif sl * 16 <= 1.6:
                r16 = 16
            elif sl * 8 <= 3.5:
                r16 = 8
            else:
                r16 = 4
            if r16 == 16:
                y = round(sum(h[i][j] for i, j in live) / len(live))
                for i, j in live:
                    top[i][j], res[i][j] = y, 16
            elif r16 == 8 or (r16 == 4 and not anykind and not mixed_keep and not anyflat):
                for si in (bi, bi + 2):
                    for sj in (bj, bj + 2):
                        sub = [(i, j) for i in (si, si + 1) for j in (sj, sj + 1) if not keep[i][j]]
                        if not sub:
                            continue
                        if any(kind[i][j] is not None or near[i][j] <= 1 for i, j in sub):
                            for i, j in sub:
                                top[i][j] = round(h[i][j]) if kind[i][j] is None else math.floor(h[i][j])
                            continue
                        y = sum(h[i][j] for i, j in sub) / len(sub)
                        far = min(near[i][j] for i, j in sub) > 6
                        y = TERRACE * round(y / TERRACE) if far and sl * 8 > 1.0 else round(y)
                        for i, j in sub:
                            top[i][j], res[i][j] = y, 8
            else:
                for i, j in live:
                    top[i][j] = round(h[i][j])
                    if kind[i][j] is not None:
                        top[i][j] = math.floor(h[i][j])
    for f in P.fields:  # fields stay level whatever block they fell in
        i0, j0 = cell_of(f['Rect'][0] + 0.1, f['Rect'][1] + 0.1)
        i1, j1 = cell_of(f['Rect'][2] - 0.1, f['Rect'][3] - 0.1)
        for i in range(i0, i1 + 1):
            for j in range(j0, j1 + 1):
                top[i][j] = f['Y']
    for i in range(N):
        for j in range(N):
            if top[i][j] is not None and top[i][j] < 1:
                top[i][j] = 1  # the baseplate's top is y 0; every slab is at least 1 thick
    crag = [[crag[i][j] and top[i][j] is not None for j in range(N)] for i in range(N)]
    P.top, P.kind, P.keep, P.res, P.flat, P.crag = top, kind, keep, res, flat, crag

    # 6. materials per cell
    hay = [d["Poly"] for d in L["Districts"] if d["Style"] == "lindenmoor.hayfield"]
    mat = [[None] * N for _ in range(N)]
    for i in range(N):
        for j in range(N):
            t = top[i][j]
            if t is None:
                continue
            if kind[i][j] is not None:
                mat[i][j] = "lm_ballast" if kind[i][j] == "rail" else "lm_dirt"
                continue
            if t >= WALL_Y:
                mat[i][j] = "lm_cliff"
                continue
            drop = 0
            for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                a, b = i + di, j + dj
                if 0 <= a < N and 0 <= b < N and top[a][b] is not None:
                    drop = max(drop, t - top[a][b])
            if drop >= 5:
                mat[i][j] = "lm_rock"
            else:
                x, z = cell_center(i, j)
                mat[i][j] = "lm_meadow" if any(in_poly(p, x, z) for p in hay) else "lm_moss"
    for f in P.fields:
        m = CROP_GROUND[f["Crop"]]
        i0, j0 = cell_of(f["Rect"][0] + 0.1, f["Rect"][1] + 0.1)
        i1, j1 = cell_of(f["Rect"][2] - 0.1, f["Rect"][3] - 0.1)
        for i in range(i0 + 1, i1):
            for j in range(j0 + 1, j1):
                if top[i][j] is not None and kind[i][j] is None:
                    mat[i][j] = m
    P.mat = mat

    # 7. merge into top rectangles; sides under each
    P.tops, P.sides = merge_ground(top, mat, crag)

    # 8. water boxes (terrain water in Studio; preview planes in Blender)
    P.water = []
    for s_ in L["Heights"]:
        if s_["Kind"] != "water":
            continue
        if "Rect" in s_:
            P.water.append(dict(Id=s_.get("Id"), Rect=s_["Rect"], Top=s_["Top"], Bed=s_["Bed"]))
            continue
        pts = s_["Line"]
        for k in range(len(pts) - 1):  # one rotated box per segment, overlapping at the joints
            P.water.append(dict(Id="%s_%d" % (s_.get("Id"), k), From=pts[k], To=pts[k + 1], Width=s_["Width"], Top=s_["Top"], Bed=s_["Bed"]))

    # 9. ribbons (road, trail and ballast surfaces)
    P.ribbons = ribbons(P)

    # 10. markers on the ground
    P.markers = []
    for m in L["Markers"]:
        mm = dict(m)
        if "At" in m and m["At"][1] == 0:
            mm["Y"] = ground_y(P, m["At"][0], m["At"][2])
        P.markers.append(mm)

    # 11. trees
    P.trees = scatter(P) if trees else []
    return P


def ground_y(P, x, z):
    """Walkable top at (x, z): a ribbon's surface on a route, else the cell top."""
    for r in P.routes:
        prof = r.get("Profile") or []
        if not prof:
            continue
        d, k, t = poly_dist(r["Line"], x, z)
        if d <= r["Width"] / 2 + 0.5:
            best = min(prof, key=lambda p: (p[0] - x) ** 2 + (p[1] - z) ** 2)
            return best[3]
    i, j = cell_of(x, z)
    if 0 <= i < N and 0 <= j < N and P.top[i][j] is not None:
        return float(P.top[i][j])
    if 0 <= i < N and 0 <= j < N and P.keep[i][j]:
        return P.village.height(x, z) if P.village.has(x, z) else float(round(P.h0[i][j]))
    return 4.0


def merge_ground(top, mat, crag=None):
    """Greedy rectangle merge of equal (top, material, crag) cells (ground.lua's approach), up to MAX_SPAN cells a side.
    Returns tops [(i0, j0, w, d, y, mat, crag)] and sides [(i0, j0, w, d, bottom, y-1, crag)]: a side belongs to the
    column (top) whose height it reaches and carries its crag flag. crag: an N x N bool grid (None: no crag)."""
    cg = crag or [[False] * N for _ in range(N)]
    used = [[False] * N for _ in range(N)]
    tops = []
    for j in range(N):
        for i in range(N):
            if used[i][j] or top[i][j] is None:
                continue
            key = (top[i][j], mat[i][j], cg[i][j])
            w = 1
            while i + w < N and w < MAX_SPAN and not used[i + w][j] and (top[i + w][j], mat[i + w][j], cg[i + w][j]) == key:
                w += 1
            d = 1
            while j + d < N and d < MAX_SPAN:
                ok = all(not used[i + a][j + d] and (top[i + a][j + d], mat[i + a][j + d], cg[i + a][j + d]) == key
                         for a in range(w))
                if not ok:
                    break
                d += 1
            for a in range(w):
                for b in range(d):
                    used[i + a][j + b] = True
            tops.append((i, j, w, d, top[i][j], mat[i][j], cg[i][j]))
    sides = []
    for (i, j, w, d, y, m, c) in tops:
        lo = y - 2
        for a in range(-1, w + 1):
            for b in (-1, d):
                lo = min(lo, _nb(top, i + a, j + b, y) - 1)
        for b in range(0, d):
            for a in (-1, w):
                lo = min(lo, _nb(top, i + a, j + b, y) - 1)
        lo = max(0, lo)
        if lo >= y - 2 and _min_nb(top, i, j, w, d, y) >= y:
            continue  # no neighbour is lower: nothing shows this side
        if y - 1 - lo > 0.01:
            sides.append((i, j, w, d, lo, y - 1, c))
    return tops, sides


def _min_nb(top, i, j, w, d, y):
    lo = y
    for a in range(-1, w + 1):
        for b in (-1, d):
            lo = min(lo, _nb(top, i + a, j + b, y))
    for b in range(0, d):
        for a in (-1, w):
            lo = min(lo, _nb(top, i + a, j + b, y))
    return lo


def _nb(top, i, j, y):
    if 0 <= i < N and 0 <= j < N:
        t = top[i][j]
        return y if t is None else t  # next to the village (kept) ground: assume level (the seam blends to it)
    return 0  # outside the footprint: the void under the edge wall


def ribbons(P):
    """Route surfaces: tilted slabs every 8 studs along each route, merged where the grade and heading repeat.
    Each: dict(route, kind, p0=(x,z,y), p1=(x,z,y), width, base) with base = the lowest ground under it."""
    out = []
    for r in P.routes:
        prof = r.get("Profile") or []
        if len(prof) < 2:
            continue
        segs = []
        for k in range(0, len(prof) - 1, 2):
            a = prof[k]
            b = prof[min(k + 2, len(prof) - 1)]
            if a[:2] == b[:2]:
                continue
            mx, mz = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
            if _bridge_t(r, mx, mz, pad=1.0) or _bridge_t(r, a[0], a[1], pad=1.0) or _bridge_t(r, b[0], b[1], pad=1.0):
                continue
            segs.append([a, b])
        merged = []
        for s in segs:
            if merged:
                p = merged[-1]
                a0, b0 = p[0], p[1]
                a1, b1 = s
                L0 = math.hypot(b0[0] - a0[0], b0[1] - a0[1])
                L1 = math.hypot(b1[0] - a1[0], b1[1] - a1[1])
                h0 = math.atan2(b0[1] - a0[1], b0[0] - a0[0])
                h1 = math.atan2(b1[1] - a1[1], b1[0] - a1[0])
                g0 = (b0[3] - a0[3]) / max(L0, 1e-6)
                g1 = (b1[3] - a1[3]) / max(L1, 1e-6)
                if (b0[:2] == a1[:2] and abs(h0 - h1) < 0.02 and abs(g0 - g1) < 0.01 and L0 + L1 <= 64):
                    merged[-1] = [a0, b1]
                    continue
            merged.append(s)
        for a, b in merged:
            base = min(a[3], b[3])
            L_ = math.hypot(b[0] - a[0], b[1] - a[1])
            n = max(2, int(L_ / 4))
            for m in range(n + 1):
                t = m / n
                x, z = lerp(a[0], b[0], t), lerp(a[1], b[1], t)
                i, j = cell_of(x, z)
                if 0 <= i < N and 0 <= j < N:
                    if P.top[i][j] is not None:
                        base = min(base, P.top[i][j])
                    elif P.keep[i][j]:
                        base = min(base, P.village.height(x, z) if P.village.has(x, z) else base)
            out.append(dict(route=r["Id"], kind=r["Kind"], p0=(a[0], a[1], a[3]), p1=(b[0], b[1], b[3]), width=r["Width"], base=base))
    return out


# ------------------------------------------------------------------ patchwork fields
CROPS = [("wheat", 0.34), ("hay", 0.2), ("cabbage", 0.18), ("plough", 0.16), ("fallow", 0.12)]  # PROPOSAL
CROP_GROUND = {"wheat": "lm_meadow", "hay": "lm_meadow", "cabbage": "lm_moss", "plough": "lm_dirt", "fallow": "lm_moss"}
BOUNDS = [("hedge", 0.5), ("wall", 0.3), ("fence", 0.2)]  # field boundaries (walls are vaultable)
FIELD_PARTS = 30  # average, for the estimate


def make_fields(L, P, h, keep, kind, flat):
    rng = random.Random(907)
    pads = [(lm["At"][0], lm["At"][1], pad_r(lm) + 10) for lm in L["Landmarks"]]
    pads += [(m["At"][0], m["At"][2], 10) for m in L["Markers"] if "At" in m and m["Tag"] in ("RenseiPost", "RenseiClue", "RenseiMarker", "RenseiEnemySpawn")]
    out = []
    for d in L["Districts"]:
        if d["Style"] != "lindenmoor.patchwork":
            continue
        xs = [p[0] for p in d["Poly"]]
        zs = [p[1] for p in d["Poly"]]
        z = min(zs) + 4
        while z < max(zs) - 40:
            dz = rng.uniform(56, 90)
            x = min(xs) + 4
            while x < max(xs) - 40:
                dx = rng.uniform(60, 100)
                r = [x, z, min(x + dx, max(xs) - 4), min(z + dz, max(zs) - 4)]
                x += dx + 4
                if r[2] - r[0] < 40 or r[3] - r[1] < 40 or rng.random() > d["Density"]:
                    continue
                if not all(in_poly(d["Poly"], cx, cz) for cx in (r[0], r[2]) for cz in (r[1], r[3])):
                    continue
                if any(rect_dist(r, px, pz) < pr for px, pz, pr in pads):
                    continue
                i0, j0 = cell_of(r[0] - 6, r[1] - 6)
                i1, j1 = cell_of(r[2] + 6, r[3] + 6)
                ok, hs = True, []
                for i in range(max(0, i0), min(N, i1 + 1)):
                    for j in range(max(0, j0), min(N, j1 + 1)):
                        if keep[i][j] or kind[i][j] is not None or flat[i][j] or h[i][j] >= WALL_Y:
                            ok = False
                            break
                        cx, cz = cell_center(i, j)
                        if in_rect(r, cx, cz):
                            hs.append(h[i][j])
                    if not ok:
                        break
                if not ok or not hs or max(hs) - min(hs) > 6:
                    continue
                crop = _pick(rng, CROPS)
                out.append(dict(Rect=[round(v) for v in r], Y=round(sum(hs) / len(hs)), Crop=crop, Bound=_pick(rng, BOUNDS),
                                Rows=0 if (r[2] - r[0]) >= (r[3] - r[1]) else 1, District=d["Id"]))
            z += dz + 4
    # snap rects to the cell grid so the levelled cells match the field exactly
    for f in out:
        f["Rect"] = [CELL * math.floor(f["Rect"][0] / CELL), CELL * math.floor(f["Rect"][1] / CELL),
                     CELL * math.ceil(f["Rect"][2] / CELL), CELL * math.ceil(f["Rect"][3] / CELL)]
    return out


# ------------------------------------------------------------------ trees
STYLE = {  # spacing (studs) at Density 1, and the mix of tree kinds: (kind, weight) (PROPOSAL)
    "lindenmoor.forest_mixed": (24, [("cypress", 0.55), ("oak_far", 0.35), ("oak_big", 0.10)]),
    "lindenmoor.forest_cypress": (22, [("cypress", 0.85), ("oak_far", 0.15)]),
    "lindenmoor.forest_oak": (24, [("oak_big", 0.35), ("oak", 0.25), ("oak_far", 0.40)]),
    "lindenmoor.forest_sparse": (26, [("oak_far", 0.6), ("cypress", 0.4)]),
    "lindenmoor.orchard": (18, [("fruit", 1.0)]),
    "lindenmoor.hayfield": (0, []),
    "lindenmoor.patchwork": (0, []),
    "lindenmoor.meadow_trees": (40, [("oak", 0.6), ("oak_far", 0.4)]),
}
TREE_PARTS = {"cypress": 7, "oak_far": 6, "oak": 24, "oak_big": 36, "fruit": 4}  # parts per tree (kit counts)
CLEAR = {"cypress": 3, "oak_far": 6, "oak": 6, "oak_big": 10, "fruit": 3}


def scatter(P):
    L = P.layout
    rng = random.Random(2310)
    taken = {}  # grid of placed trees for spacing

    def free(x, z, r):
        gi, gj = int(x // 32), int(z // 32)
        for a in range(gi - 1, gi + 2):
            for b in range(gj - 1, gj + 2):
                for (tx, tz, tr) in taken.get((a, b), ()):
                    if (tx - x) ** 2 + (tz - z) ** 2 < (tr + r) ** 2:
                        return False
        return True

    def put(x, z, r):
        taken.setdefault((int(x // 32), int(z // 32)), []).append((x, z, r))

    blocked = []  # (x, z, r): landmarks and markers
    for lm in P.landmarks:
        R = pad_r(lm) + 6
        if lm["Kind"] in ("lindenmoor.overlook", "lindenmoor.lookout"):
            R = 40  # a clear view from every viewpoint
        if lm["Kind"] in ("lindenmoor.training_field",):
            R = 110
        if lm["Kind"] in ("lindenmoor.footbridge", "lindenmoor.stone_bridge"):
            R = 60
        blocked.append((lm["At"][0], lm["At"][1], max(R, 14)))
    for m in L["Markers"]:
        if "At" in m and m["Tag"] in ("RenseiPost", "RenseiClue", "RenseiMarker"):
            blocked.append((m["At"][0], m["At"][2], 8))
    gap = [m["Box"] for m in L["Markers"] if m["Tag"] == "EdgeGap"]
    others = [d for d in L["Districts"] if d["Style"] != "lindenmoor.meadow_trees"]
    trees = []
    order = sorted(L["Districts"], key=lambda d: d["Style"] == "lindenmoor.meadow_trees")
    for d in order:
        sp0, mix = STYLE.get(d["Style"], (0, []))
        if not mix or d["Density"] <= 0:
            continue
        sp = sp0 / math.sqrt(d["Density"])
        xs = [p[0] for p in d["Poly"]]
        zs = [p[1] for p in d["Poly"]]
        orchard = d["Style"] == "lindenmoor.orchard"
        z = min(zs) + sp / 2
        row = 0
        while z < max(zs):
            x = min(xs) + sp / 2 + (sp / 2 if row % 2 and not orchard else 0)
            while x < max(xs):
                jx = 0 if orchard else rng.uniform(-0.42, 0.42) * sp
                jz = 0 if orchard else rng.uniform(-0.42, 0.42) * sp
                tx, tz = x + jx, z + jz
                x += sp
                if not in_poly(d["Poly"], tx, tz):
                    continue
                if d["Style"] == "lindenmoor.meadow_trees" and any(in_poly(o["Poly"], tx, tz) for o in others):
                    continue
                kindt = _pick(rng, mix)
                r = CLEAR[kindt]
                i, j = cell_of(tx, tz)
                if not (0 <= i < N and 0 <= j < N) or P.top[i][j] is None or P.keep[i][j]:
                    continue
                if P.top[i][j] >= WALL_Y or P.flat[i][j] or P.kind[i][j] is not None:
                    continue
                if _near_route(P, tx, tz, r + 4) or any((bx - tx) ** 2 + (bz - tz) ** 2 < (br + r) ** 2 for bx, bz, br in blocked):
                    continue
                if any(b[0][0] <= tx <= b[1][0] and b[0][2] <= tz <= b[1][2] for b in gap):
                    continue
                if any(rect_dist(f["Rect"], tx, tz) < r + 2 for f in P.fields):
                    continue
                if not free(tx, tz, r):
                    continue
                put(tx, tz, r)
                trees.append((kindt, tx, tz, float(P.top[i][j]), rng.uniform(0, 360), rng.uniform(0.85, 1.2), d["Id"]))
            z += sp * (0.9 if not orchard else 1.0)
            row += 1
    # hedgerow trees: one oak at some field corners
    for f in P.fields:
        if rng.random() < 0.45:
            cx = f["Rect"][0] - 4 if rng.random() < 0.5 else f["Rect"][2] + 4
            cz = f["Rect"][1] - 4 if rng.random() < 0.5 else f["Rect"][3] + 4
            i, j = cell_of(cx, cz)
            if 0 <= i < N and 0 <= j < N and P.top[i][j] is not None and P.kind[i][j] is None and not _near_route(P, cx, cz, 9) and free(cx, cz, 6):
                put(cx, cz, 6)
                trees.append(("oak_far", cx, cz, float(P.top[i][j]), rng.uniform(0, 360), 1.0, f["District"]))
    return trees


def _pick(rng, mix):
    t = rng.random() * sum(w for _, w in mix)
    for k, w in mix:
        t -= w
        if t <= 0:
            return k
    return mix[-1][0]


def _near_route(P, x, z, pad):
    i, j = cell_of(x, z)
    rr = int(pad / CELL) + 1
    for a in range(max(0, i - rr), min(N, i + rr + 1)):
        for b in range(max(0, j - rr), min(N, j + rr + 1)):
            if P.kind[a][b] is not None:
                cx, cz = cell_center(a, b)
                if (cx - x) ** 2 + (cz - z) ** 2 <= pad * pad:
                    return True
    return False


# ------------------------------------------------------------------ budget
LANDMARK_PARTS = {  # per set piece, calibrated to the Blender build's counts (2026-10-23); the build counts exactly
    "lindenmoor.farmstead": 300, "lindenmoor.roadside_market": 60, "lindenmoor.watermill": 40, "lindenmoor.stone_bridge": 12,
    "lindenmoor.level_crossing": 14, "lindenmoor.training_field": 95, "lindenmoor.ridge_marker": 12, "lindenmoor.overlook": 25,
    "lindenmoor.mine_head": 90, "lindenmoor.lookout": 30, "lindenmoor.footbridge": 40, "lindenmoor.gorge_ledge": 50,
    "lindenmoor.waterfall": 15, "lindenmoor.hay_barn": 35, "lindenmoor.signal_box": 20, "lindenmoor.road_gate": 5,
    "lindenmoor.tunnel_portals": 40, "lindenmoor.reserve": 0,
}


def budget(P):
    rails = [r for r in P.ribbons if r["kind"] == "rail"]
    rail_len = sum(math.dist(r["p0"][:2], r["p1"][:2]) for r in rails)
    est = {
        "ground_tops": len(P.tops),
        "ground_sides": len(P.sides),
        "ribbons": len(P.ribbons),
        "rail_track": int(rail_len / 4) + 2 * len(rails),
        "trees": sum(TREE_PARTS[t[0]] for t in P.trees),
        "landmarks": sum(LANDMARK_PARTS.get(l["Kind"], 50) for l in P.landmarks),
        "markers": sum(1 for m in P.markers if m["Tag"] not in ("EdgeGap",)),
        "fields": FIELD_PARTS * len(P.fields),
        "edging": int(sum(math.dist(r["p0"][:2], r["p1"][:2]) for r in P.ribbons if r["kind"] in ("road",)) / 12),
    }
    est["total"] = sum(est.values())
    est["budget"] = P.layout["Budget"]
    est["tree_count"] = len(P.trees)
    est["field_count"] = len(P.fields)
    return est


if __name__ == "__main__":
    import time
    t0 = time.time()
    P = plan()
    print(json.dumps(budget(P), indent=1), "%.1fs" % (time.time() - t0))

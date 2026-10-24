"""Where the style kits' pieces go, as pure geometry (spec 2026-10-23 §3.2; plan Task 10): the buildings along district
frontages, cover clusters and street lamps, the edge ridge blocks, and stoop steps. No bpy; standard library only, so
run.py tests it. stages.py builds what these plan.

Facing (a deliberate reading of the brief's "buildings face the nearest route"): a building faces its FRONTAGE EDGE's
outward normal, not the nearest route point, so every building along one frontage shares one facing and a terrace
lines up. A frontage is a district edge that rays straight out from meet a street within FRONT_REACH, so district
edges that should hold buildings must run alongside streets (Testbed: the row's south edge faces the main road).

Frame: region (x, z) studs; a prefab turned theta (a Blender z rotation) maps its local (x, y) to
(x cos theta - y sin theta, x sin theta + y cos theta); its front is local -y (the Roblox LookVector)."""
import math, random

from . import heightfield as HF, kitspec, schema


def cell_of(grid, x, z):
    """The grid cell (i, k) holding region (x, z), clamped to the grid."""
    i = int(math.floor((x - grid.origin[0]) / grid.cell))
    k = int(math.floor((z - grid.origin[1]) / grid.cell))
    return min(max(i, 0), grid.nx - 1), min(max(k, 0), grid.nz - 1)


def ground_y(grid, x, z):
    """The stepped ground's top at (x, z): its cell's whole-stud top."""
    i, k = cell_of(grid, x, z)
    return grid.top[i][k]


# ------------------------------------------------------------------ constants
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
# Ungrippable edges (Task 10b, owner 2026-10-24: "Ungrippable edges"; natural edges, never invisible walls). No wall
# height holds a climber: the climb leap (Space+W, Parkour.ClimbStep 8 x the ParkourCost multiplier, +12 studs, 0.5 s
# cooldown) takes a base player about 123 studs up from a running jump and a fully upgraded one about 207. So every edge
# wall block carries EDGE_TAG (the CollectionService tag RenseiNoGrip, TuningConfig.Parkour.NoGripTag, through rs_tags):
# the climb, the climb leap and the wall run can't grab it (JumpManager.Grippable; the server's wall check refuses it
# too), while it still shows and collides. The height only has to beat what needs no grip at all.
EDGE_TAG = "RenseiNoGrip"
# PROPOSAL (the owner's earlier Lindenmoor figure): every edge wall shows a SHEER inner face at least EDGE_HEIGHT studs
# over the ground beside it, with no tread on that face. A running jump rises about +16 to +19 studs, so 80 is well
# over anything reached without a grip. (Supersedes fix round 2's 120, which was sized against a full climb.)
EDGE_HEIGHT = 80
# PROPOSAL: every structure (building, landmark, cover cluster, lamp: anything a player could stand on) keeps this far
# from any edge wall's inner face. A running jump's apex lands 18-23 studs out, so at 26 no roof or crate stack can
# launch a player over the crest. The wall's inner face is at most EDGE_BAND in from the footprint's edge, so
# structures stay EDGE_BAND + WALL_CLEAR in (_Site.inner, wall_clear_rect).
WALL_CLEAR = 26
EDGE_SEG = 16  # PROPOSAL: the longest ridge block along an edge
STREET_KINDS = ("public", "quiet", "road")  # the routes a building may front


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
            ci, ck = cell_of(grid, x + px * c - py * s, z + px * s + py * c)
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
        self.inner = wall_clear_rect(layout)
        self.landmarks = []
        for lm in layout["Landmarks"]:
            _, _, what, spec = kitspec.piece(lm["Kind"])
            if what == "landmark":
                self.landmarks.append(_quad(lm["At"][0], lm["At"][1], -math.radians(lm.get("Yaw", 0)), spec["foot"]))
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


def wall_clear_rect(layout):
    """[x0, z0, x1, z1]: where structures may stand, WALL_CLEAR studs clear of every edge wall's inner face."""
    fw, fd = layout["Footprint"]
    m = EDGE_BAND + WALL_CLEAR
    return (-fw / 2 + m, -fd / 2 + m, fw / 2 - m, fd / 2 - m)


def landmarks_too_near_walls(layout):
    """The Ids of landmarks whose footprint (kitspec foot, at At turned to -Yaw) comes within WALL_CLEAR of an edge
    wall's inner face. The landmarks stage refuses to build a layout with any."""
    x0, z0, x1, z1 = wall_clear_rect(layout)
    out = []
    for lm in layout["Landmarks"]:
        _, _, what, spec = kitspec.piece(lm["Kind"])
        if what != "landmark":
            continue
        q = _quad(lm["At"][0], lm["At"][1], -math.radians(lm.get("Yaw", 0)), spec["foot"])
        if not all(x0 - 1e-9 <= x <= x1 + 1e-9 and z0 - 1e-9 <= z <= z1 + 1e-9 for x, z in q):
            out.append(lm["Id"])
    return out


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
    Returns [{id, district, frontage, style, kind, x, z, theta, w, d, storeys, seed, party, body, clear}]: body and
    clear are region quads (the walls; the walls with overhangs, front fittings and stoop)."""
    site = site or _Site(layout, grid)
    out = []
    for dist in layout["Districts"]:
        _, _, what, spec = kitspec.piece(dist["Style"])
        if what != "style":
            raise ValueError(f"district {dist['Id']}: {dist['Style']} is a landmark, not a building style")
        if dist["Density"] <= 0:
            continue
        rng = random.Random(f"{layout['Region']}:{dist['Id']}")
        for f in frontages(layout, dist):
            out += _fill_frontage(site, grid, dist, f, spec, rng)
    return out


def _fill_frontage(site, grid, dist, f, spec, rng):
    kind, (wmin, wmax, dmin, dmax), terrace = spec["kind"], spec["size"], spec["terrace"]
    reach = spec.get("front", OVERHANG)
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
                b = _place(site, grid, spec, dist, key, len(out) + len(row), frame, theta, pos, w, depth, reach, rng)
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


def _place(site, grid, spec, dist, key, n, frame, theta, pos, w, depth, reach, rng):
    """One building of the fill, checked exactly (its own depth, its stoop): a dict, or None when it can't stand."""
    x, z = frame(pos + w / 2, FRONT_SETBACK + depth / 2)
    body = (-w / 2, -depth / 2, w / 2, depth / 2)
    lo, hi, wet = _ground_stats(grid, x, z, theta, _grow(body, FOOTING))
    flo, _, fwet = _ground_stats(grid, x, z, theta, front_strip(spec, w, depth))
    if wet or fwet:
        return None
    nsteps = len(stoop_tops(spec.get("step"), hi, flo))  # exactly the steps stages._stoop builds
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
            "kind": spec["kind"], "x": x, "z": z, "theta": theta, "w": w, "d": depth,
            "storeys": rng.randint(lo_s, hi_s), "seed": rng.randrange(1 << 30), "party": "",
            "body": _quad(x, z, theta, body), "clear": q}


def front_strip(spec, w, d):
    """The local rect of ground just in front of a building's door step (or dock): the stoop runs down onto it."""
    sd = (spec.get("step") or (0, 0))[1]
    return (-w / 2, -d / 2 - sd - 1.2, w / 2, -d / 2 - sd)


def stoop_tops(step, floor, ground):
    """The tops (absolute heights) of the stoop steps from a door step down to the street, nearest the door first.
    step = the style's (height above the floor, depth) or None (no door: no stoop). Every riser, the top one from the
    door step and the last one onto the ground included, is 1 stud or less: n steps split the drop evenly."""
    if not step:
        return []
    top = floor + step[0]
    drop = top - ground
    if drop <= 1 + 1e-9:
        return []
    n = int(math.ceil(drop - 1e-9)) - 1
    return [top - j * drop / (n + 1) for j in range(1, n + 1)]


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
    kit = kitspec.KITS[kitspec.kit_name(layout)]
    out = []
    cr = kit["cover"]["foot"]
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
    lr = kit["lamp"]["foot"]
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

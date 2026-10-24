"""Checks on the pure region builder modules (no Blender): python -I Art/Blender/region_builder/tests/run.py
Prints PASS n / FAIL n and exits 1 on any failure."""
import copy, json, math, os, sys, tempfile, traceback

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..", "..")))  # Art/Blender, so `region_builder` imports
REPO = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
TESTBED = os.path.join(REPO, "Art", "Regions", "Testbed", "layout.json")

FAILS, PASSES = [], []


def check(name, ok, detail=""):
    (PASSES if ok else FAILS).append(name)
    if not ok:
        print("FAIL", name, detail)


# ------------------------------------------------------------------ helpers
def seg_dist(px, pz, a, b):
    ax, az = a
    bx, bz = b
    dx, dz = bx - ax, bz - az
    L2 = dx * dx + dz * dz
    t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / L2))
    return math.hypot(px - (ax + t * dx), pz - (az + t * dz))


def line_dist(px, pz, line):
    return min(seg_dist(px, pz, line[i], line[i + 1]) for i in range(len(line) - 1))


def rect_dist(px, pz, r):
    x0, z0, x1, z1 = min(r[0], r[2]), min(r[1], r[3]), max(r[0], r[2]), max(r[1], r[3])
    return math.hypot(max(x0 - px, 0, px - x1), max(z0 - pz, 0, pz - z1))


def centre(G, i, k):
    return G.origin[0] + (i + 0.5) * G.cell, G.origin[1] + (k + 0.5) * G.cell


def cell_of(G, x, z):
    return int(math.floor((x - G.origin[0]) / G.cell)), int(math.floor((z - G.origin[1]) / G.cell))


def route_cells(G, route):
    out = set()
    for i in range(len(G.top)):
        for k in range(len(G.top[0])):
            x, z = centre(G, i, k)
            if line_dist(x, z, route["Line"]) <= route["Width"] / 2:
                out.add((i, k))
    return out


def raises_schema(schema, data, needle):
    """Writes data to a temp file, loads it, returns (raised SchemaError, a message mentions needle)."""
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "layout.json")
        with open(p, "w", encoding="utf-8") as f:
            json.dump(data, f)
        try:
            schema.load(p)
        except schema.SchemaError as e:
            msgs = e.messages
            return True, any(needle in m for m in msgs), msgs
        return False, False, []


# ------------------------------------------------------------------ schema
def test_schema():
    from region_builder import schema
    L = schema.load(TESTBED)
    check("testbed loads", L["Region"] == "Testbed" and L["Footprint"] == [256, 256])
    with open(TESTBED, encoding="utf-8") as f:
        raw = json.load(f)

    bad = copy.deepcopy(raw)
    del bad["Footprint"]
    r, m, msgs = raises_schema(schema, bad, "Footprint")
    check("missing Footprint raises", r and m, msgs)

    bad = copy.deepcopy(raw)
    bad["Markers"][0]["Tag"] = "RenseiNoSuchTag"
    r, m, msgs = raises_schema(schema, bad, "RenseiNoSuchTag")
    check("unknown marker Tag raises", r and m, msgs)

    bad = copy.deepcopy(raw)
    bad["Routes"][1]["Line"] = [[-75, -40]]
    r, m, msgs = raises_schema(schema, bad, "alley")
    check("route with 1 point raises", r and m, msgs)

    bad = copy.deepcopy(raw)
    bad["Districts"][0]["Poly"][0] = [-200, -110]
    r, m, msgs = raises_schema(schema, bad, "row")
    check("district outside footprint raises", r and m, msgs)

    # every problem is reported, not just the first
    bad = copy.deepcopy(raw)
    del bad["Footprint"]
    bad["Markers"][0]["Tag"] = "RenseiNoSuchTag"
    r, m, msgs = raises_schema(schema, bad, "RenseiNoSuchTag")
    check("all problems collected", r and m and len(msgs) >= 2, msgs)

    # a post needs its PostId and a known Kind
    bad = copy.deepcopy(raw)
    bad["Markers"][0]["Attr"]["Kind"] = "Nap"
    r, m, msgs = raises_schema(schema, bad, "Kind")
    check("post with unknown Kind raises", r and m, msgs)

    # a file that is not JSON is a SchemaError too
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "layout.json")
        with open(p, "w", encoding="utf-8") as f:
            f.write("{ not json")
        try:
            schema.load(p)
            ok = False
        except schema.SchemaError:
            ok = True
    check("invalid JSON raises SchemaError", ok)
    return L


# ------------------------------------------------------------------ heightfield
def test_heightfield(L):
    from region_builder import heightfield as hf
    G = hf.sample(L, cell=4)
    NX, NZ = len(G.top), len(G.top[0])
    check("grid size", (NX, NZ) == (64, 64) and G.cell == 4 and tuple(G.origin) == (-128, -128),
          (NX, NZ, G.cell, G.origin))
    H = {h["Kind"]: h for h in L["Heights"]}
    box, ridge, cut, water = H["box"], H["ridge"], H["cut"], H["water"]

    # every top is a whole stud
    check("top is int everywhere", all(type(G.top[i][k]) is int for i in range(NX) for k in range(NZ)))

    # plane: 4 wherever no other shape reaches
    off = []
    for i in range(NX):
        for k in range(NZ):
            x, z = centre(G, i, k)
            if rect_dist(x, z, box["Rect"]) < box["Edge"] or line_dist(x, z, ridge["Line"]) < ridge["Width"]:
                continue
            if rect_dist(x, z, cut["Rect"]) == 0 or rect_dist(x, z, water["Rect"]) == 0:
                continue
            if G.top[i][k] != 4:
                off.append((x, z, G.top[i][k]))
    check("plane is 4 outside the shapes", not off, off[:5])

    # box: 10 inside, a smooth step down over Edge outside it
    inside = [G.top[i][k] for i in range(NX) for k in range(NZ) if rect_dist(*centre(G, i, k), box["Rect"]) == 0]
    check("box is 10 inside", inside and all(t == 10 for t in inside), set(inside))
    i0, k = cell_of(G, -22, -42)
    row = [G.top[i][k] for i in range(i0, i0 + 5)]  # centres x -22 (in), -18, -14, -10, -6 (8+ studs out)
    mono = all(row[j] >= row[j + 1] for j in range(len(row) - 1))
    mid = any(4 < t < 10 for t in row)
    small = all(row[j] - row[j + 1] <= 3 for j in range(len(row) - 1))
    check("box steps down smoothly over Edge", row[0] == 10 and row[-1] == 4 and mono and mid and small, row)

    # ridge: 30 on its line, falling linearly to the base at Width
    check("ridge is 30 on its line", hf.height_at(L, 0, 100) == 30, hf.height_at(L, 0, 100))
    check("ridge half-way is between", abs(hf.height_at(L, 0, 112) - 17) < 1e-6, hf.height_at(L, 0, 112))
    check("ridge meets base at Width", abs(hf.height_at(L, 0, 124) - 4) < 1e-6, hf.height_at(L, 0, 124))
    i, k_on = cell_of(G, 2, 102)
    _, k_far = cell_of(G, 2, 74)
    col = [G.top[i][kk] for kk in range(k_on, k_far - 1, -1)]  # z 102 down to 74
    mono = all(col[j] >= col[j + 1] for j in range(len(col) - 1))
    check("ridge falls off over Width", col[0] >= 27 and col[-1] == 4 and mono, col)

    # cut: -4 inside
    inside = [G.top[i][k] for i in range(NX) for k in range(NZ) if rect_dist(*centre(G, i, k), cut["Rect"]) == 0]
    check("cut is -4 inside", inside and all(t == -4 for t in inside), set(inside))

    # water: kind water, the bed as the top, and the water box recorded
    inw = [(i, k) for i in range(NX) for k in range(NZ) if rect_dist(*centre(G, i, k), water["Rect"]) == 0]
    check("water cells are water", inw and all(G.kind[i][k] == "water" for i, k in inw))
    check("water bed is the top", all(G.top[i][k] == -6 for i, k in inw), {G.top[i][k] for i, k in inw})
    check("water box recorded", list(G.water) == [(60, 40, 100, 80, 3, -6)], G.water)
    nw = sum(1 for i in range(NX) for k in range(NZ) if G.kind[i][k] == "water")
    check("no water outside the box", nw == len(inw), (nw, len(inw)))

    # routes: public is path, quiet is quiet
    R = {r["Id"]: r for r in L["Routes"]}
    i, k = cell_of(G, -100, 2)
    check("main is path", G.kind[i][k] == "path", G.kind[i][k])
    i, k = cell_of(G, -74, -20)
    check("alley is quiet", G.kind[i][k] == "quiet", G.kind[i][k])
    i, k = cell_of(G, -30, -30)
    check("climb is path", G.kind[i][k] == "path", G.kind[i][k])
    i, k = cell_of(G, -100, 60)
    check("off-route is top", G.kind[i][k] == "top", G.kind[i][k])
    on = set().union(*(route_cells(G, r) for r in L["Routes"]))
    stray = [(i, k) for i in range(NX) for k in range(NZ)
             if G.kind[i][k] in ("path", "quiet") and (i, k) not in on]
    check("only route cells are path/quiet", not stray, stray[:5])
    main = route_cells(G, R["main"])
    check("every main cell is path", all(G.kind[i][k] == "path" for i, k in main))
    return G


# ------------------------------------------------------------------ columns
def test_columns(G):
    from region_builder import heightfield as hf
    cols = hf.columns(G)
    NX, NZ = len(G.top), len(G.top[0])
    check("one column per cell", len(cols) == NX * NZ, len(cols))
    bad = []
    for i, k, top, bottom, kind in cols:
        if top != G.top[i][k] or kind != G.kind[i][k] or bottom > top - 2:
            bad.append((i, k, top, bottom))
        for di, dk in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ii, kk = i + di, k + dk
            if 0 <= ii < NX and 0 <= kk < NZ and bottom > G.top[ii][kk] - 1:
                bad.append((i, k, bottom, "vs", ii, kk, G.top[ii][kk]))
    check("column bottoms are 1 below every neighbour's top", not bad, bad[:5])


# ------------------------------------------------------------------ ramps
def test_ramps(L, G):
    from region_builder import heightfield as hf
    R = {r["Id"]: r for r in L["Routes"]}
    ramps = hf.ramps(G, L)
    check("ramps are route cells", all(G.kind[i][k] in ("path", "quiet") for i, k in ramps))
    climb = route_cells(G, R["climb"])
    check("climb has a ramp", len(ramps & climb) >= 1, len(ramps & climb))
    # main is flat at 4 except where the Testbed's cut [40,-40,80,0] sinks its south half (see the Task 8 report):
    # the cells whose x-span touches the cut are left out of this check.
    cut = next(h for h in L["Heights"] if h["Kind"] == "cut")["Rect"]
    main = {(i, k) for i, k in route_cells(G, R["main"])
            if not (cut[0] <= G.origin[0] + (i + 1) * G.cell and G.origin[0] + i * G.cell <= cut[2])}
    check("flat main has no ramps", not (ramps & main), sorted(ramps & main)[:5])


# ------------------------------------------------------------------ merge
def test_merge():
    from region_builder import merge
    cells = {(i, k): "a" for i in range(10) for k in range(10)}
    rs = merge.rects(cells)
    check("10x10 block is 1 rect", rs == [(0, 0, 10, 10, "a")], rs)

    cells = {(i, k): ("a" if (i + k) % 2 else "b") for i in range(10) for k in range(10)}
    check("checkerboard is 100 rects", len(merge.rects(cells)) == 100)

    cells = {(i, 0): "a" for i in range(10)}
    rs = merge.rects(cells, max_span=4)
    check("max_span 4 on 10x1 is 3 rects", sorted(r[2] for r in rs) == [2, 4, 4] and len(rs) == 3, rs)

    # an irregular map: the rects cover exactly the cells, once each, with each rect's key
    cells = {}
    for i in range(23):
        for k in range(17):
            if (i * 7 + k * 3) % 11 != 0:
                cells[(i, k)] = (i // 5 + k // 4) % 3
    seen = {}
    ok = True
    for i0, k0, w, d, key in merge.rects(cells, max_span=6):
        ok = ok and 1 <= w <= 6 and 1 <= d <= 6
        for i in range(i0, i0 + w):
            for k in range(k0, k0 + d):
                ok = ok and (i, k) not in seen and cells.get((i, k)) == key
                seen[(i, k)] = key
    check("rects tile the cells exactly", ok and seen == cells)


def main():
    L = G = None
    try:
        L = test_schema()
    except Exception:
        check("schema module", False, traceback.format_exc())
    if L is not None:
        try:
            G = test_heightfield(L)
        except Exception:
            check("heightfield module", False, traceback.format_exc())
    if G is not None:
        for name, fn, args in (("columns", test_columns, (G,)), ("ramps", test_ramps, (L, G))):
            try:
                fn(*args)
            except Exception:
                check(name, False, traceback.format_exc())
    try:
        test_merge()
    except Exception:
        check("merge module", False, traceback.format_exc())
    print(f"PASS {len(PASSES)} / FAIL {len(FAILS)}")
    sys.exit(1 if FAILS else 0)


if __name__ == "__main__":
    main()

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


def seg_t(px, pz, a, b):
    """Where (px, pz) projects onto segment a-b, unclamped: 0 at a, 1 at b."""
    dx, dz = b[0] - a[0], b[1] - a[1]
    return ((px - a[0]) * dx + (pz - a[1]) * dz) / (dx * dx + dz * dz)


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
        except Exception as e:  # anything but SchemaError is a failure (e.g. TypeError on an unhashable value)
            return False, False, [repr(e)]
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

    # the spec's old tag names are rejected: no service reads them
    for oldname in ("RenseiClerk", "RenseiThreshold", "RenseiEncounter", "RenseiTrialDoor"):
        bad = copy.deepcopy(raw)
        bad["Markers"][2]["Tag"] = oldname
        r, m, msgs = raises_schema(schema, bad, oldname)
        check(f"old tag {oldname} raises", r and m, msgs)

    # a post needs its PostId and a known Kind
    bad = copy.deepcopy(raw)
    bad["Markers"][0]["Attr"]["Kind"] = "Nap"
    r, m, msgs = raises_schema(schema, bad, "Kind")
    check("post with unknown Kind raises", r and m, msgs)

    # unhashable values are SchemaErrors, not TypeErrors
    bad = copy.deepcopy(raw)
    bad["Markers"][0]["Tag"] = ["RenseiPost"]
    r, m, msgs = raises_schema(schema, bad, "Tag must be a string")
    check("list Tag raises SchemaError", r and m, msgs)
    bad = copy.deepcopy(raw)
    bad["Routes"][0]["Id"] = ["main"]
    r, m, msgs = raises_schema(schema, bad, "Id must be")
    check("list Id raises SchemaError", r and m, msgs)
    bad = copy.deepcopy(raw)
    bad["Markers"][0]["Attr"]["PostId"] = ["test_work"]
    r, m, msgs = raises_schema(schema, bad, "PostId must be")
    check("list PostId raises SchemaError", r and m, msgs)

    # two posts without a PostId: each is missing, neither is a duplicate
    bad = copy.deepcopy(raw)
    del bad["Markers"][0]["Attr"]["PostId"]
    del bad["Markers"][1]["Attr"]["PostId"]
    r, m, msgs = raises_schema(schema, bad, "missing Attr.PostId")
    nmiss = sum("missing Attr.PostId" in x for x in msgs)
    check("posts without PostId are missing, not duplicate",
          r and nmiss == 2 and not any("duplicate" in x for x in msgs), msgs)

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

    # Palette values: a key string, or {"Key": key, "Pack": texture-pack item} (Pack optional; owner, 2026-10-23)
    check("_pal accepts a key string", schema._pal("cinder"))
    check("_pal accepts {Key, Pack}", schema._pal({"Key": "brick", "Pack": "Floor A"}))
    check("_pal accepts {Key}", schema._pal({"Key": "brick"}))
    check("_pal rejects {Pack} alone", not schema._pal({"Pack": "Floor A"}))
    check("_pal rejects an unknown field", not schema._pal({"Key": "brick", "Tint": "ff0000"}))
    check("_pal rejects an empty Pack", not schema._pal({"Key": "brick", "Pack": ""}))
    good = copy.deepcopy(raw)
    good["Palette"]["wall"] = {"Key": "brick", "Pack": "Floor A"}
    r, m, msgs = raises_schema(schema, good, "Palette")
    check("a layout with a {Key, Pack} Palette value loads", not r, msgs)
    bad = copy.deepcopy(raw)
    bad["Palette"]["wall"] = {"Pack": "Floor A"}
    r, m, msgs = raises_schema(schema, bad, "Palette")
    check("a layout with a Pack-only Palette value raises", r and m, msgs)

    # EdgeGap (Task 10): a builder-only tag. The edges stage reads it to leave a gap in the edge ridges; the markers
    # stage makes no part for it, so nothing exports it. It needs a Box.
    check("EdgeGap is a builder-only tag",
          "EdgeGap" in getattr(schema, "BUILDER_TAGS", ()) and "EdgeGap" not in schema.MARKER_TAGS)
    good = copy.deepcopy(raw)
    good["Markers"].append({"Tag": "EdgeGap", "Box": [[-20, 0, -128], [20, 60, -112]]})
    r, m, msgs = raises_schema(schema, good, "EdgeGap")
    check("an EdgeGap with a Box loads", not r, msgs)
    bad = copy.deepcopy(raw)
    bad["Markers"].append({"Tag": "EdgeGap", "At": [-120, 0, 0]})
    r, m, msgs = raises_schema(schema, bad, "EdgeGap needs a Box")
    check("an EdgeGap without a Box raises", r and m, msgs)
    bad = copy.deepcopy(raw)
    bad["Markers"].append({"Tag": "EdgeGap", "Box": [[-20, 60, -128], [20, 0, -112]]})
    r, m, msgs = raises_schema(schema, bad, "Box")
    check("an EdgeGap with an inside-out Box raises", r and m, msgs)
    check("the Testbed has an EdgeGap at each end of the main road",
          sum(1 for mk in L["Markers"] if mk["Tag"] == "EdgeGap") == 2, [mk["Tag"] for mk in L["Markers"]])
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
    # the exact bottom: min(top - 2, each neighbour's top - 1), an off-grid neighbour counting as top - 12
    wrong = []
    for i, k, top, bottom, kind in cols:
        want = top - 2
        for di, dk in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ii, kk = i + di, k + dk
            n = G.top[ii][kk] if 0 <= ii < NX and 0 <= kk < NZ else top - 12
            want = min(want, n - 1)
        if bottom != want:
            wrong.append((i, k, top, bottom, want))
    check("column bottom is exact", not wrong, wrong[:5])
    at = {(i, k): (top, bottom) for i, k, top, bottom, kind in cols}
    check("border column reaches EDGE_DROP below", hf.EDGE_DROP == 12 and at[(0, 0)] == (4, -9)
          and at[(NX - 1, 20)] == (4, -9), (at[(0, 0)], at[(NX - 1, 20)]))


# ------------------------------------------------------------------ ramps
def test_ramps(L, G):
    from region_builder import heightfield as hf
    R = {r["Id"]: r for r in L["Routes"]}
    ramps = hf.ramps(G, L)
    check("ramps are route cells", all(G.kind[i][k] in ("path", "quiet") for i, k in ramps))
    climb = route_cells(G, R["climb"])
    tops = {G.top[i][k] for i, k in climb}
    check("climb runs from 4 to 10", 4 in tops and 10 in tops, sorted(tops))
    a, b = R["climb"]["Line"]
    slope = {(i, k) for i, k in climb if 0 < seg_t(*centre(G, i, k), a, b) < 1}  # not the round end caps
    check("climb has ramps on its slope", len(ramps & slope) >= 1, (len(ramps & climb), len(ramps & slope)))
    main = route_cells(G, R["main"])
    check("flat main has no ramps", not (ramps & main), sorted(ramps & main)[:5])


# ------------------------------------------------------------------ variants of the Testbed
def test_variants(L):
    from region_builder import schema, heightfield as hf
    base = hf.sample(L)

    def variant(heights=(), routes=()):
        V = copy.deepcopy(L)
        V["Heights"] += list(heights)
        V["Routes"] += list(routes)
        errs = schema.validate(V)
        check("variant is valid", not errs, errs)
        return V, hf.sample(V)

    water = next(h for h in L["Heights"] if h["Kind"] == "water")
    inw = [(i, k) for i in range(base.nx) for k in range(base.nz) if rect_dist(*centre(base, i, k), water["Rect"]) == 0]

    # a later box raising part of the water out of it takes those cells back
    V, G = variant(heights=[{"Kind": "box", "Rect": [60, 40, 80, 60], "Y": 12, "Edge": 0}])
    up = [(i, k) for i, k in inw if rect_dist(*centre(G, i, k), [60, 40, 80, 60]) == 0]
    still = [c for c in inw if c not in up]
    check("raised water cells are dry", up and all(G.top[i][k] == 12 and G.kind[i][k] != "water"
                                                   and G.water_of[i][k] is None for i, k in up))
    check("the rest stays water", still and all(G.kind[i][k] == "water" and G.water_of[i][k] == 0
                                                for i, k in still))
    check("the water box is still recorded", G.water == [(60, 40, 100, 80, 3, -6)], G.water)
    nwet = sum(1 for i in range(G.nx) for k in range(G.nz) if G.kind[i][k] == "water")
    check("water count drops by the raised cells", nwet == len(inw) - len(up), (nwet, len(inw), len(up)))

    # raised entirely: no water cells and no water box
    V, G = variant(heights=[{"Kind": "box", "Rect": [56, 36, 104, 84], "Y": 12, "Edge": 0}])
    nwet = sum(1 for i in range(G.nx) for k in range(G.nz) if G.kind[i][k] == "water")
    check("fully raised water is gone", nwet == 0 and G.water == [], (nwet, G.water))

    # water beats path
    wet = {"Id": "wet", "Kind": "public", "Width": 8, "Line": [[80, 24], [80, 96]]}
    V, G = variant(routes=[wet])
    cells = route_cells(G, wet)
    inside = [c for c in cells if c in set(inw)]
    outside = [c for c in cells if c not in set(inw)]
    check("water beats path", inside and all(G.kind[i][k] == "water" for i, k in inside), len(inside))
    check("the route is path off the water", outside and all(G.kind[i][k] == "path" for i, k in outside))

    # rail, under and ledge leave the ground as it is
    odd = [{"Id": "r", "Kind": "rail", "Width": 10, "Line": [[0, -100], [100, -100]]},
           {"Id": "u", "Kind": "under", "Width": 8, "Line": [[110, -120], [110, -60]]},
           {"Id": "l", "Kind": "ledge", "Width": 4, "Line": [[-120, 60], [-60, 60]]}]
    V, G = variant(routes=odd)
    for r in odd:
        cells = route_cells(G, r)
        same = all(G.kind[i][k] == "top" == base.kind[i][k] and G.top[i][k] == base.top[i][k] for i, k in cells)
        check(f"{r['Kind']} route leaves the ground as top", cells and same, len(cells))


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
        for name, fn, args in (("columns", test_columns, (G,)), ("ramps", test_ramps, (L, G)),
                               ("variants", test_variants, (L,))):
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

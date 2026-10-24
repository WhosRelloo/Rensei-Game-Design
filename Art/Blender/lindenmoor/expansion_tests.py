"""Checks on the Lindenmoor expansion plan (no Blender): python -I Art/Blender/lindenmoor/expansion_tests.py
Prints PASS n / FAIL n and exits 1 on any failure."""
import math, os, sys

sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")))
from lindenmoor import expansion_plan as E  # noqa: E402

FAILS, PASSES = [], []


def check(name, ok, detail=""):
    (PASSES if ok else FAILS).append(name)
    if not ok:
        print("FAIL", name, detail)


def main():
    L = E.load()
    P = E.plan()
    N, HALF = E.N, E.HALF

    # nothing is built on the village's existing ground
    bad = sum(1 for i in range(N) for j in range(N) if P.keep[i][j] and P.top[i][j] is not None)
    check("keep cells untouched", bad == 0, f"{bad} kept cells got new ground")

    # every non-kept cell has ground
    holes = sum(1 for i in range(N) for j in range(N) if not P.keep[i][j] and P.top[i][j] is None)
    check("no holes", holes == 0, f"{holes} cells without ground")

    # sealed edges: the outer 20 studs are the edge wall everywhere (the NE gap ends at the wall, z 1000)
    low = []
    for i in range(N):
        for j in range(N):
            x, z = E.cell_center(i, j)
            if (abs(x) > HALF - 20 or abs(z) > HALF - 20) and not P.keep[i][j] and P.top[i][j] < E.WALL_Y:
                low.append((x, z, P.top[i][j]))
    check("edge wall continuous", not low, f"{len(low)} low edge cells, e.g. {low[:3]}")

    # the wall is too tall to climb out of: wall top minus the highest ground within 40 studs inside it
    worst = 999
    for i in range(N):
        for j in range(N):
            if P.top[i][j] is None or P.top[i][j] >= E.WALL_Y:
                continue
            x, z = E.cell_center(i, j)
            if abs(x) > HALF - 64 or abs(z) > HALF - 64:
                worst = min(worst, 150 - P.top[i][j])  # the crag's lowest crest is 150
    check("edge wall > 80 studs above the ground beside it", worst > 80, f"min face {worst}")

    # routes: walkable grades and continuous ribbons (gaps only where a bridge carries the route)
    for r in P.routes:
        prof = r.get("Profile") or []
        if not prof:
            continue
        lim = E.ROUTE_SLOPE[r["Kind"]] + 0.01
        steep = [(a[0], a[1]) for a, b in zip(prof, prof[1:]) if b[2] > a[2] and abs(b[3] - a[3]) / (b[2] - a[2]) > lim]
        check(f"route {r['Id']} grade <= {lim - 0.01}", not steep, f"{len(steep)} steep samples, e.g. {steep[:2]}")
        rib = [x for x in P.ribbons if x["route"] == r["Id"]]
        gaps = []
        for a, b in zip(rib, rib[1:]):
            d = math.dist(a["p1"][:2], b["p0"][:2])
            if d > 0.5:
                mid = ((a["p1"][0] + b["p0"][0]) / 2, (a["p1"][1] + b["p0"][1]) / 2)
                if not E._bridge_t(r, mid[0], mid[1], pad=2.0):
                    gaps.append((round(mid[0]), round(mid[1]), round(d, 1)))
        check(f"route {r['Id']} continuous", not gaps, f"gaps {gaps[:3]}")

    # the rails start level with Ye's rail top (local 5.2 = world 9.2) at the buffer stop
    rail = next(r for r in P.routes if r["Id"] == "rail_north")
    check("rails meet the village track", abs(rail["Profile"][0][3] + 1.1 - 9.2) < 0.01, rail["Profile"][0])

    # the gorge ledge has a wall behind it (south) at least 12 studs above the strip
    lg = next(l for l in L["Landmarks"] if l["Id"] == "gorge_ledge")
    walls = []
    for x in range(int(lg["At"][0] - lg["Length"] / 2), int(lg["At"][0] + lg["Length"] / 2), 8):
        i, j = E.cell_of(x, lg["At"][1] - 3)
        walls.append(P.top[i][j])
    check("gorge ledge has its wall", min(walls) >= lg["Y"] + 12, f"wall tops {walls}")

    # water cells sit at their bed
    for w in P.water:
        if "Rect" in w:
            x0, z0, x1, z1 = w["Rect"]
        else:
            (x0, z0), (x1, z1) = w["From"], w["To"]
        i, j = E.cell_of((x0 + x1) / 2, (z0 + z1) / 2)
        check(f"water {w['Id']} bed", P.top[i][j] == w["Bed"] or P.keep[i][j], P.top[i][j])

    # markers inside the footprint, on ground below the wall; areas don't overlap
    out = [m for m in L["Markers"] if "At" in m and (abs(m["At"][0]) > HALF or abs(m["At"][2]) > HALF)]
    check("markers inside the footprint", not out, out[:2])
    high = [m["Attr"] for m in P.markers if "Y" in m and m["Y"] >= E.WALL_Y]
    check("no marker on the edge wall", not high, high[:2])
    areas = [m for m in L["Markers"] if m["Tag"] == "RenseiArea"]
    ov = []
    for a in range(len(areas)):
        for b in range(a + 1, len(areas)):
            (ax0, _, az0), (ax1, _, az1) = areas[a]["Box"]
            (bx0, _, bz0), (bx1, _, bz1) = areas[b]["Box"]
            if ax0 < bx1 and bx0 < ax1 and az0 < bz1 and bz0 < az1:
                ov.append((areas[a]["Attr"]["AreaName"], areas[b]["Attr"]["AreaName"]))
    check("areas don't overlap", not ov, ov)

    # trees stay off routes, the village and the wall
    badt = []
    for (k, x, z, y, a, s, d) in P.trees:
        i, j = E.cell_of(x, z)
        if P.keep[i][j] or P.kind[i][j] is not None or y >= E.WALL_Y:
            badt.append((k, round(x), round(z)))
    check("trees placed clear", not badt, badt[:3])

    # the road passage reaches its threshold before the wall
    rp = next(m for m in L["Markers"] if m.get("Attr", {}).get("Piece") == "RoadPassage")
    import json
    legs = json.loads(rp["Attr"]["Legs"])
    length = sum(math.hypot(l[3] - l[1], l[4] - l[2]) for l in legs)
    check("road passage longer than its threshold", length > rp["Attr"]["Threshold"] + 4, length)

    # fields: level, off routes, not overlapping each other
    badf = []
    for a, f in enumerate(P.fields):
        i0, j0 = E.cell_of(f["Rect"][0] + 0.1, f["Rect"][1] + 0.1)
        i1, j1 = E.cell_of(f["Rect"][2] - 0.1, f["Rect"][3] - 0.1)
        tops = {P.top[i][j] for i in range(i0, i1 + 1) for j in range(j0, j1 + 1)}
        kinds = {P.kind[i][j] for i in range(i0, i1 + 1) for j in range(j0, j1 + 1)}
        if len(tops) != 1 or kinds != {None}:
            badf.append((f["District"], f["Rect"], len(tops), kinds))
        for g in P.fields[a + 1:]:
            r, q = f["Rect"], g["Rect"]
            if r[0] < q[2] and q[0] < r[2] and r[1] < q[3] and q[1] < r[3]:
                badf.append(("overlap", r, q))
    check("fields level, clear and apart", not badf, badf[:3])
    check("some fields", len(P.fields) >= 20, len(P.fields))

    # reserved spots for the hub's pieces: flat, and clear of routes, fields and trees
    badr = []
    for lm in P.landmarks:
        if lm["Kind"] != "lindenmoor.reserve":
            continue
        R, (x0, z0) = lm["Radius"], lm["At"]
        tops, kinds = set(), set()
        for i in range(E.N):
            for j in range(E.N):
                x, z = E.cell_center(i, j)
                if (x - x0) ** 2 + (z - z0) ** 2 <= R * R:
                    tops.add(P.top[i][j])
                    kinds.add(P.kind[i][j])
        trees_in = sum(1 for t in P.trees if (t[1] - x0) ** 2 + (t[2] - z0) ** 2 <= R * R)
        fields_in = sum(1 for f in P.fields if E.rect_dist(f["Rect"], x0, z0) <= R)
        if len(tops) != 1 or kinds != {None} or trees_in or fields_in or None in tops or max(tops) >= E.WALL_Y:
            badr.append((lm["Id"], sorted(t for t in tops if t is not None)[:4], kinds, trees_in, fields_in))
    check("reserved spots flat and clear", not badr, badr)

    water_checks(P)

    b = E.budget(P)
    check("estimated parts within budget", b["total"] <= b["budget"], b)
    print("budget estimate", b)
    print(f"PASS {len(PASSES)} / FAIL {len(FAILS)}")
    return 1 if FAILS else 0


def water_checks(P):
    """water_convert: channel segments (world) -> kit.py's village-local axis-aligned boxes."""
    import json
    from lindenmoor import water_convert as WC
    ox, oy, oz = 0.0, 4.0, -650.0  # export origin; finish.lua adds it back

    # frame: a world segment along z = -650 lands on village-local z ~ 0, Top/Bed lose the origin's 4
    fb = WC.convert([dict(Id="t", From=[0, -650], To=[10, -650], Width=4, Top=5.2, Bed=1)])["Boxes"]
    check("water frame: z near 0", bool(fb) and all(abs(b["Rect"][1]) <= 2.5 and abs(b["Rect"][3]) <= 2.5 for b in fb), fb)
    check("water frame: Top 1.2, Bed -3", bool(fb) and all(b["Top"] == 1.2 and b["Bed"] == -3 for b in fb), fb)

    segs = [w for w in P.water if "From" in w]
    allb = WC.convert(segs)["Boxes"]

    def inside(x, z):
        return any(b["Rect"][0] + ox <= x <= b["Rect"][2] + ox and b["Rect"][1] + oz <= z <= b["Rect"][3] + oz for b in allb)

    for s in segs:
        (ax, az), (bx, bz) = s["From"], s["To"]
        miss = [(round(ax + (bx - ax) * t / 49, 1), round(az + (bz - az) * t / 49, 1)) for t in range(50)
                if not inside(ax + (bx - ax) * t / 49, az + (bz - az) * t / 49)]
        check(f"water {s['Id']} centreline covered", not miss, miss[:3])
        # spill: box area vs the segment's exact area. The channel is a capsule (round ends), as the plan carves its bed
        # (poly_dist <= Width/2) and as the converter fills it, so exact = length x width + pi (width/2)^2; against
        # length x width alone the caps are 19-87% "spill" on every segment, straight ones too. PROPOSAL tolerance 15%.
        L = math.hypot(bx - ax, bz - az)
        exact = L * s["Width"] + math.pi * (s["Width"] / 2) ** 2
        area = sum((b["Rect"][2] - b["Rect"][0]) * (b["Rect"][3] - b["Rect"][1]) for b in WC.convert([s])["Boxes"])
        check(f"water {s['Id']} spill <= 15%", area <= 1.15 * exact, f"{area} vs {exact:.0f} ({area / exact:.3f}x)")

    # kit.py's own rule (Art/Studio/Regions/kit.py: x0 < x1, z0 < z1, Bed < Top)
    bad = [b for b in allb if not (b["Rect"][0] < b["Rect"][2] and b["Rect"][1] < b["Rect"][3] and b["Bed"] < b["Top"])]
    check("water boxes pass kit.py's rule", bool(allb) and not bad, bad[:2])

    # the committed water.json is the converter's output of the committed water_segments.json
    reg = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "Regions", "Lindenmoor")
    try:
        with open(os.path.join(reg, "water_segments.json"), encoding="utf-8") as f:
            seg_file = json.load(f)["Boxes"]
        with open(os.path.join(reg, "water.json"), encoding="utf-8") as f:
            kit_file = json.load(f)
        current = kit_file == json.loads(json.dumps(WC.convert(seg_file)))
    except (OSError, KeyError, ValueError) as e:
        current = e
    check("water.json is water_convert's output of water_segments.json", current is True, current)


if __name__ == "__main__":
    sys.exit(main())

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

    b = E.budget(P)
    check("estimated parts within budget", b["total"] <= b["budget"], b)
    print("budget estimate", b)
    print(f"PASS {len(PASSES)} / FAIL {len(FAILS)}")
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())

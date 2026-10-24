"""Check a Ye survey (survey_ye.lua's ye_survey.json) against the Lindenmoor expansion plan.

python -I check_survey.py <survey.json> [--layout layout.json]
    prints FAIL/INFO lines and "PASS n / FAIL n / INFO n"; exits 1 on any FAIL.
python -I check_survey.py --stamp survey_ye.lua
    writes the layout's Infill cells into survey_ye.lua.

Checks (plan Task 1, with controller Rulings 1, 4, 5, 7, 9):
  1. every World.Map child classified, and every Keep child, arena member (Wall x2) and AlchemistSpawns present;
  2. part budget; 3. Baseplate at (0, -8, 0); 4. no Ground parts in the layout's Infill cells;
  5. village-vs-new RenseiArea overlaps: INFO when the boxes differ in volume (Task 8's smallest box wins), FAIL on an
     equal-volume tie (within 1 cubic stud); an area outside World.Map (Top "") is INFO;
  6. each pad's blocks, side by side (pad_layout.arrange), fit the layout's reserve Radius; every alchemist spawn maps
     to a site and its final slot (pulled in if needed) lies on its pad;
  7. exactly one RoadStart (under NorthRoad) and one Platform arrival; 8. five trainers in World.NPCs;
  9. Retire holds NorthRoad, HubRoad and exactly one BufferStop within 5 studs of (-270, 10, -369).
"""
import math
import json, sys, os

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import pad_layout  # noqa: E402

REPO = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
LAYOUT = os.path.join(REPO, "Art", "Regions", "Lindenmoor", "layout.json")
EXPECTED = os.path.join(REPO, "Art", "Studio", "Regions", "Lindenmoor", "import", "expected.json")
BUDGET = 80000
EXPORT_PARTS = 40414  # the export's part count until import/expected.json exists (plan Task 1)
KEEP = {"Lindenmoor", "Ground", "HalvardsAdit", "Baseplate"}
RELOCATE = {m for blocks in pad_layout.PADS.values() for _, ms in blocks for m in ms} | {"AlchemistSpawns"}
PAD_MARGIN = 6  # Task 2 enlarges each pad to the needed radius + this (Ruling 4; PROPOSAL)
VILLAGE_TOPS = ("Lindenmoor", "Ground", "HalvardsAdit")

PASS = FAIL = INFO = 0


def check(ok, msg):
    global PASS, FAIL
    PASS, FAIL = PASS + bool(ok), FAIL + (not ok)
    if not ok:
        print("FAIL:", msg)


def info(msg):
    global INFO
    INFO += 1
    print("INFO:", msg)


def overlap(a, b):
    """XZ overlap of two [[x0,y0,z0],[x1,y1,z1]] boxes (touching edges don't count)."""
    return all(a[0][i] < b[1][i] and b[0][i] < a[1][i] for i in (0, 2))


def volume(b):
    return abs((b[1][0] - b[0][0]) * (b[1][1] - b[0][1]) * (b[1][2] - b[0][2]))


def main(path, layout=LAYOUT):
    global PASS, FAIL, INFO
    PASS = FAIL = INFO = 0
    S = json.load(open(path, encoding="utf-8"))
    L = json.load(open(layout, encoding="utf-8"))

    # 1. classification and presence
    names = [c["Name"] for c in S["MapChildren"]]
    for n in names:
        check(n in KEEP | RELOCATE, f"unclassified map child {n}")
    for n in sorted(KEEP | set(pad_layout.ARENA_MEMBERS) | {"AlchemistSpawns"}):
        want = pad_layout.MEMBER_COUNTS.get(n, 1)
        check(names.count(n) == want, f"map child {n}: found {names.count(n)}, expected {want}")

    # 2. budget
    add = json.load(open(EXPECTED, encoding="utf-8"))["parts"] if os.path.exists(EXPECTED) else EXPORT_PARTS
    check(S["Parts"] + add <= BUDGET, f"budget {S['Parts']} + {add} = {S['Parts'] + add} > {BUDGET}")

    # 3. baseplate
    bp = S.get("Baseplate")
    check(bp is not None and bp["Pos"] == [0, -8, 0], f"baseplate at {bp and bp['Pos']}")

    # 4. ground in infill
    check(S["GroundInInfill"] == 0, f"{S['GroundInInfill']} Ground parts in Infill cells")

    # 5. area overlaps (Ruling 1)
    new = [(m["Attr"]["AreaName"], m["Box"]) for m in L["Markers"] if m["Tag"] == "RenseiArea"]
    for a in S["Areas"]:
        check(a.get("Box"), f"area {a['AreaName']} has no box")
        if a["Top"] == "":
            info(f"area {a['AreaName']} is not under World.Map ({a.get('Path')}): neither village nor site")
        if a.get("Box") and a["Top"] in VILLAGE_TOPS:
            for nname, b in new:
                if overlap(a["Box"], b):
                    va, vb = volume(a["Box"]), volume(b)
                    if abs(va - vb) <= 1:
                        check(False, f"village area {a['AreaName']} overlaps new area {nname} with equal volume "
                                     f"({va:.0f} vs {vb:.0f}): smallest-wins can't break the tie")
                    else:
                        info(f"village area {a['AreaName']} (vol {va:.0f}) overlaps new area {nname} (vol {vb:.0f}); "
                             f"smallest wins: {a['AreaName'] if va < vb else nname}")

    # 6. pad fit (Ruling 4): each pad's blocks side by side; the pad radius comes from the layout
    pads = {l["Id"]: l for l in L["Landmarks"] if "reserve" in l["Kind"]}
    pieces = pad_layout.pad_pieces(S["MapChildren"])
    for pad, blocks in pad_layout.PADS.items():
        got = pieces[pad]
        missing = [n for n, _ in blocks if n not in {p["Name"] for p in got}]
        check(not missing, f"{pad}: blocks not found: {missing}")
        r = pad_layout.arrange(got)["radius"]
        sizes = ", ".join(f"{p['Name']} {p['Size'][0]:.1f} x {p['Size'][1]:.1f}" for p in got)
        need = f"needed radius {r:.1f}; needed + {PAD_MARGIN} = {r + PAD_MARGIN:.1f} ({sizes})"
        if pad not in pads or "Radius" not in pads[pad]:
            check(False, f"{pad} not in the layout's landmarks (or has no Radius); {need}")
        elif got:
            check(r <= pads[pad]["Radius"], f"{pad}: pad {pads[pad]['Radius']} too small: {need}")

    # 6b. alchemist spawns follow their site's slot (Ruling 7)
    radii = {p: pads[p]["Radius"] for p in pads if "Radius" in pads[p]}
    spawns = S.get("AlchemistSpawns")
    check(spawns, "survey has no AlchemistSpawns children")
    for name, e in pad_layout.spawn_slots(spawns or [], pieces, radii).items():
        if e["Site"] is None:
            check(False, f"alchemist spawn {name}: no site for its name (pad_layout.SPAWN_SITES)")
        elif e["Pad"] is None:
            check(False, f"alchemist spawn {name}: its site {e['Site']} isn't on any pad")
        elif e["Offset"] is None:
            check(False, f"alchemist spawn {name}: pad {e['Pad']} has no Radius in the layout")
        else:
            d = math.hypot(*e["Offset"])
            check(d <= radii[e["Pad"]], f"alchemist spawn {name} at {d:.1f} off pad {e['Pad']} ({radii[e['Pad']]})")
            if e["Pulled"]:
                info(f"alchemist spawn {name} pulled in to {d:.1f} on {e['Pad']} (pad {radii[e['Pad']]})")

    # 7. arrivals
    rs = [a for a in S["Arrivals"] if a["Point"] == "RoadStart"]
    under = lambda p: p.split("Workspace.", 1)[-1].startswith("World.Map.Lindenmoor.NorthRoad.")
    check(len(rs) == 1 and under(rs[0]["Path"]), f"RoadStart arrivals {rs}")
    pf = [a for a in S["Arrivals"] if a["Point"] == "Platform"]
    check(len(pf) == 1, f"Platform arrivals {len(pf)} != 1: {pf}")

    # 8. trainers
    tr = S["Trainers"]
    check(len(tr) == 5, f"trainers found: {len(tr)}")
    for t in tr:
        check("World.NPCs." in t["Path"], f"trainer {t['DialogueId']} not in World.NPCs: {t['Path']}")

    # 9. retire targets (Task 5)
    ret = S.get("Retire", [])
    paths = [r["Path"] for r in ret]
    for want in ("World.Map.Lindenmoor.NorthRoad", "World.Map.Lindenmoor.HubRoad"):
        check(paths.count(want) == 1, f"Retire: {want} found {paths.count(want)} times")
    stops = [r for r in ret if r["Path"].endswith(".BufferStop") and r.get("Pivot")
             and math.dist(r["Pivot"], (-270, 10, -369)) <= 5]
    check(len(stops) == 1 and len(ret) == 3, f"Retire: {len(stops)} BufferStops near (-270, 10, -369), "
                                            f"{len(ret)} entries: {paths}")

    print(f"PASS {PASS} / FAIL {FAIL} / INFO {INFO}")
    return 1 if FAIL else 0


def infill_runs():
    """The layout's Infill cells (4-stud world cells in Infill.Rect that are not Keep), as column runs
    [x0, z0, z1]: cells x0..x0+4 by z0..z1 (z1 exclusive). Keep = expansion_plan.keep_mask(), the plan's own mask:
    village terrain outside the Keep Rects, plus the footprint of Ye's Ground and HalvardsAdit parts from
    ye_survey.json's GroundFootprint (Rulings 14, 15). Stamping therefore needs a survey with GroundFootprint; re-run the survey after it."""
    sys.path.insert(0, os.path.join(REPO, "Art", "Blender", "lindenmoor"))
    import expansion_plan as E  # pure Python, no bpy
    L = E.load(LAYOUT)
    keep = E.keep_mask(L, E.Village())
    R = L["Infill"]["Rect"]
    runs = []
    for x0 in range(R[0], R[2], E.CELL):
        start = None
        for z0 in range(R[1], R[3] + E.CELL, E.CELL):
            i, j = E.cell_of(x0 + E.CELL / 2, z0 + E.CELL / 2)
            free = z0 < R[3] and not keep[i][j]
            if free and start is None:
                start = z0
            elif not free and start is not None:
                runs.append([x0, start, z0])
                start = None
    return runs


def stamp(lua_path):
    """Write the Infill runs into survey_ye.lua between its INFILL BEGIN / END lines."""
    runs = infill_runs()
    src = open(lua_path, encoding="utf-8").read()
    a = src.find("-- INFILL BEGIN\n")
    b = src.find("-- INFILL END")
    assert a >= 0 and b > a, "INFILL markers not found"
    a += len("-- INFILL BEGIN\n")
    lit = json.dumps(runs, separators=(",", ":"))
    src = src[:a] + f'local INFILL = "{lit}" -- {len(runs)} runs, {sum((r[2] - r[1]) // 4 for r in runs)} cells\n' + src[b:]
    with open(lua_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(src)
    print(f"stamped {len(runs)} runs into {lua_path}")


if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
        print(__doc__)
        sys.exit(2)
    if sys.argv[1] == "--stamp":
        stamp(sys.argv[2])
    elif len(sys.argv) > 3 and sys.argv[2] == "--layout":
        sys.exit(main(sys.argv[1], sys.argv[3]))
    else:
        sys.exit(main(sys.argv[1]))

"""Pure-Python checks on Foundry Yard's region file and the Foundry kit's tables (no bpy). Run:
    python -I Art/Blender/region_builder/tests/foundry_check.py

It checks the owner-approved layout (2026-10-24) against the rules the builder and setup.lua rely on: the schema, one
Platform and one RoadStart arrival, the station pieces' spacing (canopy posts clear of the gate and the board, the
booth inside the booking hall, the railing on the platform's back edge), the two edge gaps (a portal each, the road's
threshold covering its mouth), landmarks clear of the walls, the south road route following the passage's legs, the
areas not overlapping, the posts and clues. Exits 1 on any failure."""
import json, math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
BLENDER = os.path.normpath(os.path.join(HERE, "..", ".."))
REPO = os.path.normpath(os.path.join(BLENDER, "..", ".."))
sys.path.insert(0, BLENDER)

from region_builder import kitspec, placement as PL, schema  # noqa: E402

FAILS, PASSES = [], []


def check(name, ok, detail=""):
    (PASSES if ok else FAILS).append(name if ok else f"{name}: {detail}")


def _leg_points(legs, step=2.0):
    pts = []
    for g in legs:
        if g[0] == "line":
            n = max(1, math.ceil(math.hypot(g[3] - g[1], g[4] - g[2]) / step))
            pts += [(g[1] + (g[3] - g[1]) * i / n, g[2] + (g[4] - g[2]) * i / n) for i in range(n + 1)]
        else:
            a1, a2 = math.radians(g[4]), math.radians(g[5])
            n = max(1, math.ceil(abs(a2 - a1) * g[3] / step))
            pts += [(g[1] + g[3] * math.cos(a1 + (a2 - a1) * i / n), g[2] + g[3] * math.sin(a1 + (a2 - a1) * i / n))
                    for i in range(n + 1)]
    return pts


def _at_s(legs, s):
    """(x, z, ux, uz) at distance s along the legs (sampled as the passage samples them)."""
    pts = _leg_points(legs)
    acc = 0.0
    for a, b in zip(pts, pts[1:]):
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        if L and acc + L >= s:
            t = (s - acc) / L
            return a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, (b[0] - a[0]) / L, (b[1] - a[1]) / L
        acc += L
    raise ValueError("s past the end")


def _line_dist(x, z, line):
    return min(PL._seg_dist(x, z, a, b) for a, b in zip(line, line[1:]))


def main():
    path = os.path.join(REPO, "Art", "Regions", "Foundry", "layout.json")
    try:
        L = schema.load(path)
    except schema.SchemaError as e:
        check("Foundry's layout.json loads", False, e.messages[:8])
        return
    check("Foundry's layout.json loads", True)
    check("Region Foundry, place 109591196441030, 1,536 x 1,536 (brief), budget 45,000 (spec 3.6)",
          (L["Region"], L["PlaceId"], L["Footprint"], L["Budget"]) == ("Foundry", 109591196441030, [1536, 1536], 45000),
          (L["Region"], L["PlaceId"], L["Footprint"], L["Budget"]))
    mk = L["Markers"]
    pieces = {}
    for m in mk:
        if m["Tag"] == "RenseiMarker":
            pieces.setdefault(m["Attr"]["Piece"], []).append(m)
    check("one each of Station, Clerk, Board, Gate, Railing, FreightYard, RoadPassage, TrainerSpot",
          {k: len(v) for k, v in pieces.items()} == {k: 1 for k in ("Station", "Clerk", "Board", "Gate", "Railing",
                                                                   "FreightYard", "RoadPassage", "TrainerSpot")},
          {k: len(v) for k, v in pieces.items()})
    st, rd = pieces["Station"][0]["Attr"], pieces["RoadPassage"][0]["Attr"]
    check("exactly one Platform arrival and one RoadStart arrival",
          st.get("Arrival", True) is True and rd.get("Arrival", True) is True)
    check("the train route and the road route are World Plan 1's",
          (st["Route"], rd["Route"], rd["To"]) == ("LindenmoorFoundry", "RoadLindenmoorFoundry", "Lindenmoor"),
          (st["Route"], rd["Route"], rd["To"]))
    TX, RT, NZ = st["TrackX"], st["RailTop"], st["NoseZ"]
    lms = {lm["Id"]: lm for lm in L["Landmarks"]}
    # --- the station ---
    can = lms["platform_canopy"]
    check("the canopy stands over the platform (centre x TrackX + 12, z the platform's middle, yaw 0)",
          can["At"] == [TX + 12, NZ - 275] and can["Yaw"] == 0, can)
    gate, board = pieces["Gate"][0], pieces["Board"][0]
    check("the gate and the board are on the platform's back edge, facing the track (yaw 90)",
          abs(gate["At"][0] - (TX + 17.5)) < 0.01 and abs(board["At"][0] - (TX + 17.6)) < 0.01
          and gate["Yaw"] == 90 and board["Yaw"] == 90 and abs(board["At"][1] - (RT + 1.8)) < 0.01,
          (gate["At"], board["At"]))
    return_gate = gate["At"][2] - can["At"][1]
    return_board = board["At"][2] - can["At"][1]
    import re  # kits/foundry.py needs bpy: read its constants from the source
    src = open(os.path.join(BLENDER, "region_builder", "kits", "foundry.py"), encoding="utf-8").read()
    ga, ba = map(float, re.search(r"GATE_AT, BOARD_AT = ([\d.]+), ([\d.]+)", src).groups())
    check("the canopy's skipped posts are where the gate and the board stand (kits/foundry GATE_AT, BOARD_AT)",
          abs(return_gate - ga) < 0.01 and abs(return_board - ba) < 0.01, (return_gate, return_board, ga, ba))
    th = lms["ticket_hall"]
    hx, hz = th["At"]
    check("the booking hall faces the platform (yaw 90) with its canopy's edge 12+ studs east of the railing",
          th["Yaw"] == 90 and (hx - 12 - 13) - (TX + 18.6) >= 12 - 1e-6, (th, TX + 18.6))
    clerk = pieces["Clerk"][0]
    cx, _, cz = clerk["At"]
    check("the ticket booth (6 x 4) stands inside the booking hall, before the gate",
          hx - 12 + 1.6 + 2 <= cx <= hx + 12 - 1.6 - 2 and hz - 30 + 1.6 + 3.2 <= cz <= hz + 30 - 1.6 - 3.2
          and clerk["Attr"]["Station"] == "Foundry", (clerk["At"], th["At"]))
    runs = json.loads(pieces["Railing"][0]["Attr"]["Runs"])
    gz = gate["At"][2]
    check("the railing runs the platform's back edge with a gap at the gate",
          len(runs) == 4 and runs[0][2] < gz - 4 and runs[1][1] > gz + 4 and abs(runs[0][1] - (NZ - 444.7)) < 0.2
          and abs(runs[1][3] - (NZ - 105.3)) < 0.2 and all(abs(r[0] - (TX + 18.6)) < 0.11 for r in runs), runs)
    fy = pieces["FreightYard"][0]
    check("the freight yard marker is on the far (-X) side of the track", fy["At"][0] < TX - 6, fy["At"])
    # --- the road ---
    legs = json.loads(rd["Legs"])
    length = schema.road_length(legs)
    check("RoadStart < Threshold <= the road's length", 0 <= rd["RoadStart"] < rd["Threshold"] <= length,
          (rd["RoadStart"], rd["Threshold"], length))
    road = next(r for r in L["Routes"] if r["Id"] == "south_road")
    off = max(_line_dist(x, z, road["Line"]) for x, z in _leg_points(legs))
    check("the south_road route follows the passage's legs (within 1.5 studs)", off <= 1.5, round(off, 2))
    check("the passage builds no ground, trees or rocks of its own (Skip covers the footprint: the region paves it)",
          json.loads(rd["Skip"]) == [[-768, -768, 768, 768]], rd.get("Skip"))
    gaps = [m for m in mk if m["Tag"] == "EdgeGap"]
    check("two edge gaps, each with a portal: the rails east and the road south",
          sorted(m["Attr"].get("Portal") for m in gaps) == ["rail", "road"], [m["Attr"] for m in gaps])
    rgap = next(m for m in gaps if m["Attr"]["Portal"] == "road")
    (gx0, _, gz0), (gx1, _, gz1) = rgap["Box"]
    tx, tz, ux, uz = _at_s(legs, rd["Threshold"])
    half_w = rd["Half"] + 5  # the threshold part is Half * 2 + 10 across, 10 deep
    inner = L["Footprint"][1] / 2 - PL.EDGE_BAND
    check("the threshold spans the road gap's mouth (across) and reaches the edge wall's inner face",
          abs(ux) < 1e-6 and uz > 0 and tx - half_w <= gx0 and gx1 <= tx + half_w and tz + 5 >= inner + 2
          and tz - 5 <= inner, (round(tx, 1), round(tz, 1), rgap["Box"]))
    check("the road gap is on the south edge, the rail gap on the east edge",
          gz1 == L["Footprint"][1] / 2 and next(m for m in gaps if m["Attr"]["Portal"] == "rail")["Box"][1][0]
          == L["Footprint"][0] / 2)
    rails = [r for r in L["Routes"] if r["Kind"] == "rail" and r["Line"][-1][0] == L["Footprint"][0] / 2]
    rg = next(m for m in gaps if m["Attr"]["Portal"] == "rail")["Box"]
    check("both main lines leave through the rail gap", len(rails) == 2
          and all(rg[0][2] + 6 <= r["Line"][-1][1] <= rg[1][2] - 6 for r in rails), [r["Line"][-1] for r in rails])
    check("the main line starts where setup.lua's station rails end (NoseZ - 490)",
          next(r for r in L["Routes"] if r["Id"] == "main_line")["Line"][0] == [TX, NZ - 490])
    # --- landmarks, kit ---
    check("no landmark within WALL_CLEAR of an edge wall", not PL.landmarks_too_near_walls(L),
          PL.landmarks_too_near_walls(L))
    fk = kitspec.KITS["foundry"]
    check("the foundry kit has no building styles and its 10 landmarks",
          fk["styles"] == {} and sorted(fk["landmarks"]) == ["gatehouse", "great_hall", "platform_canopy", "road_gate",
                                                             "shift_office", "signal_gantry", "ticket_hall", "wagon",
                                                             "water_tower", "yard_wall"],
          sorted(fk["landmarks"]))
    kinds = {}
    for lm in L["Landmarks"]:
        kinds[lm["Kind"]] = kinds.get(lm["Kind"], 0) + 1
    rails = {r["Id"]: r for r in L["Routes"]}
    wag = [lm for lm in L["Landmarks"] if lm["Kind"] == "foundry.wagon"]
    off = [lm["Id"] for lm in wag if min(_line_dist(lm["At"][0], lm["At"][1], rails[i]["Line"]) for i in ("siding_1", "siding_2")) > 0.01]
    check("every wagon stands on a siding's centre line", wag and not off, off)
    walls = [lm for lm in L["Landmarks"] if lm["Kind"] == "foundry.yard_wall"]
    pairs = sum(1 for i, a in enumerate(walls) for b in walls[i + 1:]
                if a["Yaw"] == b["Yaw"] and a["At"][0] == b["At"][0] and abs(a["At"][1] - b["At"][1]) == 12)
    check("the east has movement pieces: 10+ wagons, 2+ water towers, 2 wall-run pairs of yard walls, 4+ crane-yard walks",
          kinds.get("foundry.wagon", 0) >= 10 and kinds.get("foundry.water_tower", 0) >= 2 and pairs >= 2
          and sum(1 for lm in L["Landmarks"] if lm["Id"].startswith("crane_walk")) >= 4, (kinds, pairs))
    # the wall-run corridors stay open at both ends: no planned building within 24 studs past either end (the first
    # build put warehouses across both ends of the pond pair); plans the buildings, so this check takes about a minute
    from region_builder import heightfield as HF
    plan = PL.plan_buildings(L, HF.sample(L, cell=4))
    blocked = []
    for i, a in enumerate(walls):
        for b in walls[i + 1:]:
            if not (a["Yaw"] == b["Yaw"] == 0 and a["At"][0] == b["At"][0] and abs(a["At"][1] - b["At"][1]) == 12):
                continue
            z0, z1 = sorted((a["At"][1], b["At"][1]))
            x = a["At"][0]
            for ex0, ex1 in ((x - 30 - 24, x - 30), (x + 30, x + 30 + 24)):
                end = [(ex0, z0), (ex1, z0), (ex1, z1), (ex0, z1)]
                hit = [bd["id"] for bd in plan if PL._quads_overlap(end, bd["body"])]
                if hit:
                    blocked.append((a["Id"], b["Id"], hit))
    check("the wall-run corridors are open at both ends (no building within 24 studs past either end)", not blocked,
          blocked)
    pond = [h for h in L["Heights"] if h["Kind"] == "water"]
    check("a pond to swim in (terrain water, deeper than a body)", pond and all(h["Top"] - h["Bed"] >= 6 for h in pond), pond)
    check("the region's kit (cover, lamps) is railtown", kitspec.kit_name(L) == "railtown", kitspec.kit_name(L))
    # --- areas, posts, clues, spawns ---
    areas = [m for m in mk if m["Tag"] == "RenseiArea"]
    bad = []
    for i, a in enumerate(areas):
        for b in areas[i + 1:]:
            (a0, _, a1), (a2, _, a3) = a["Box"][0], a["Box"][1]
            (b0, _, b1), (b2, _, b3) = b["Box"][0], b["Box"][1]
            if a0 < b2 and b0 < a2 and a1 < b3 and b1 < a3:
                bad.append((a["Attr"]["AreaName"], b["Attr"]["AreaName"]))
    check("no two areas overlap", not bad, bad)
    fw = L["Footprint"][0] / 2
    cov = sum((m["Box"][1][0] - m["Box"][0][0]) * (m["Box"][1][2] - m["Box"][0][2]) for m in areas)
    check("the areas cover the whole footprint", abs(cov - (2 * fw) ** 2) < 1e-6, cov)
    posts = [m for m in mk if m["Tag"] == "RenseiPost"]
    kinds = {}
    for p in posts:
        kinds[p["Attr"]["Kind"]] = kinds.get(p["Attr"]["Kind"], 0) + 1
    check("70+ townsfolk posts (about 25 townsfolk), every kind, 5+ shelters",
          len(posts) >= 70 and set(kinds) == set(schema.POST_KINDS) and kinds["Shelter"] >= 5, kinds)
    ix0, iz0, ix1, iz1 = PL.wall_clear_rect(L)
    out = [p["Attr"]["PostId"] for p in posts if not (ix0 <= p["At"][0] <= ix1 and iz0 <= p["At"][2] <= iz1)]
    check("every post is inside the walls' clear band", not out, out)
    clues = sorted(m["Attr"]["ClueId"] for m in mk if m["Tag"] == "RenseiClue")
    check("the shift-ledger clue and the altered docket (spec 7.3)",
          clues == ["foundry_altered_docket", "foundry_shift_ledger"], clues)
    under = next(r for r in L["Routes"] if r["Kind"] == "under")
    doc = next(m for m in mk if m["Tag"] == "RenseiClue" and m["Attr"]["ClueId"] == "foundry_altered_docket")
    spawns = [m for m in mk if m["Tag"] == "RenseiEnemySpawn"]
    check("the docket and the enemy spawns are in the underworks tunnel (owner: Grunts there only)",
          _line_dist(doc["At"][0], doc["At"][2], under["Line"]) < 1 and 1 <= len(spawns) <= 6
          and all(_line_dist(m["At"][0], m["At"][2], under["Line"]) < 1 for m in spawns), [m["At"] for m in spawns])
    led = next(m for m in mk if m["Tag"] == "RenseiClue" and m["Attr"]["ClueId"] == "foundry_shift_ledger")
    cr = lms["practice_court"]["At"]
    check("the shift ledger is just east of the practice court (spec 7.1)",
          0 < led["At"][0] - cr[0] <= 80 and abs(led["At"][2] - cr[1]) <= 30, (led["At"], cr))
    br = pieces["TrainerSpot"][0]
    check("Brannoc's spot is inside the practice court", math.hypot(br["At"][0] - cr[0], br["At"][2] - cr[1]) < 15,
          br["At"])


if __name__ == "__main__":
    try:
        main()
    except Exception:
        import traceback
        FAILS.append("error: " + traceback.format_exc()[-2000:])
    for f in FAILS:
        print("FAIL", f)
    print(f"PASS {len(PASSES)} / FAIL {len(FAILS)}")
    sys.exit(1 if FAILS else 0)

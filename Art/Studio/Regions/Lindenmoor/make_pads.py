"""Lindenmoor import Task 5: writes pads.json, the data prep_ye.lua places Ye's hub pieces with.

python -I Art/Studio/Regions/Lindenmoor/make_pads.py [--check]
    Reads ye_survey.json (Task 1), layout.json's reserve pads and TrainerSpot markers, pad_layout.py (slots and
    spawn offsets, Rulings 4, 5, 7) and expansion_plan.plan() (ground heights; world studs, x east, z north = Ye +Z).
    Writes pads.json next to this file. --check rebuilds it in memory and fails if the file on disk differs.

pads.json (all world studs):
    "<pad id>": {"At": [x, y, z], "Radius", "Flat": [lo, hi], "Blocks": [{"Name", "Members", "Counts", "Center",
                 "Size", "MinY", "Slot", "Riders"}]}
        y = the plan's ground top at the pad centre. A block's XZ centre (its members' tight part box, survey
        "PartBox") goes to At + Slot; it rises by y - GROUND (every hub block stands on the Baseplate's top today,
        GROUND = 0; a few parts sink below it: Hill to -12.7, FrozenStation -0.7, AshPit -0.1, so "lowest point to
        the pad's height" is taken as "the ground it stands on to the pad's height"). Flat = the lowest and highest
        plan ground top under the pad's placed blocks. Riders: World.NPCs / World.Live models standing on the block
        today (measured 2026-10-24), moved with it by the same offset.
    "trainer_<element>": {"At": [x, y, z], "Yaw": 0, "Trainer", "Element"}   (y = the plan's ground top there)
    "Spawns": {AlchemistSpawns child: {"Pad", "Site", "XZ": [x, z], "DY", "Pulled", "Nudged"}}
    "EliteSpawn": {"XZ": [x, z], "DY", "Near": [x, z], "From": surveyed [x, y, z]}     (Ruling 8; PROPOSAL)
    "Inputs": {repo path: sha256 (CRLF -> LF)} of every input (Ruling 18); bundle_prep.py refuses on any mismatch.
    Every pad is asserted flat under its blocks at its centre height (Flat[0] == Flat[1] == At[1]).
    "Retire": [{"Path", "Near"?: [x, y, z], "Within"?, "Count"}]
    "Lift": [{"Path", "Class", "Pivot", "Top", "Why"}]   (Ruling 17: items outside World.Map on new ground; Top null =
            stays put. Inputs: lift_items.json from lift_survey.lua; re-run both if Ye's items change.)
"""
import hashlib, json, math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(REPO, "Art", "Blender", "lindenmoor"))
import pad_layout  # noqa: E402
import expansion_plan as E  # noqa: E402  (pure Python, no bpy)

SURVEY = os.path.join(HERE, "ye_survey.json")
LAYOUT = os.path.join(REPO, "Art", "Regions", "Lindenmoor", "layout.json")
OUT = os.path.join(HERE, "pads.json")

GROUND = 0.0  # measured: the Baseplate's top, which every hub block, spawn and trainer stands on today
SPAWN_HALF = 1.0  # measured: AlchemistSpawns parts are 2 x 1 x 2
SPAWN_CLEAR = 4.0  # a spawn's edge keeps this far from any block's part box on its pad (PROPOSAL)
NUDGE_MAX = 60.0  # how far sideways a spawn may be nudged to find free pad ground (PROPOSAL)
ELITE_RING = (6, 8, 10, 12, 14, 16)  # studs off a Bramble Woods Grunt spawn to look for the elite's spot (PROPOSAL)
ELITE_ROUTE_CLEAR = 12.0  # elite spot: this far beyond a route's half width (PROPOSAL)
ELITE_TREE_CLEAR = 4.0  # elite spot: this far beyond a tree's clear radius (PROPOSAL)
ELITE_WATER_CLEAR = 8.0  # elite spot: this far beyond water (PROPOSAL)
ELITE_GRUNT_MIN = 6.0  # elite spot: at least this far from any Grunt spawn marker (PROPOSAL)
# models standing on a block today that move with it (measured in Ye 2026-10-24; prep_ye.lua checks each is still
# on its block before moving it). The layout's res_foundry_graybox "Holds" the graybox "and its NPCs".
RIDERS = {
    "FoundryYard": ["NPCs/Mirra", "NPCs/Foreman Brask", "NPCs/Lise", "NPCs/Tobin"],
    pad_layout.ARENA: ["NPCs/Drillmaster Vask", "NPCs/Placeholder NPC",
                       "Live/Dummy", "Live/Perfect Parry", "Live/Blocking", "Live/Parry"],
}
RETIRE_BUFFER = [-270, 10, -369]  # the BufferStop to retire (the one at z -891 stays)
LIFT_ITEMS = os.path.join(HERE, "lift_items.json")  # lift_survey.lua's output (Ruling 17)
LIFT_CLEAR = 0.05  # a lifted item's lowest point ends this far above the planned ground top (Ruling 17)
# pads.json "Inputs" (Ruling 18): bundle_prep.py refuses to bundle if any of these changed since make_pads.py ran
INPUTS = ["Art/Studio/Regions/Lindenmoor/ye_survey.json", "Art/Studio/Regions/Lindenmoor/lift_items.json",
          "Art/Regions/Lindenmoor/layout.json", "Art/Blender/lindenmoor/expansion_plan.py",
          "Art/Studio/Regions/Lindenmoor/pad_layout.py", "Art/Studio/Regions/Lindenmoor/make_pads.py"]


def file_hash(rel):
    """sha256 of a repo file with CRLF normalised to LF (git may rewrite line endings on checkout)."""
    with open(os.path.join(REPO, rel), "rb") as f:
        return hashlib.sha256(f.read().replace(b"\r\n", b"\n")).hexdigest()


def input_hashes():
    return {rel: file_hash(rel) for rel in INPUTS}


def _r(v, n=2):
    return round(float(v), n)


def _overlap(a, b):
    """XZ boxes [x0, z0, x1, z1]."""
    return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]


def build():
    with open(SURVEY, encoding="utf-8") as f:
        S = json.load(f)
    L = E.load(LAYOUT)
    P = E.plan(L)
    reserve = {lm["Id"]: lm for lm in L["Landmarks"] if "reserve" in lm["Kind"]}
    pieces = pad_layout.pad_pieces(S["MapChildren"])
    radii = {k: lm["Radius"] for k, lm in reserve.items()}
    boxes = {}
    for c in S["MapChildren"]:
        b = c.get("PartBox") or c.get("Box")
        boxes.setdefault(c["Name"], []).append(b)

    out = {"Inputs": input_hashes(), "Note": "Generated by make_pads.py (Lindenmoor import Task 5); world studs. GROUND = %s (Baseplate top). "
                   "Slots, spawn pull-in, nudges and the EliteSpawn spot are PROPOSALs (Rulings 4, 5, 7, 8)." % GROUND,
           "Ground": GROUND}
    placed = {}  # pad -> [XZ boxes of its placed blocks]
    for pad, got in pieces.items():
        lm = reserve[pad]
        cx, cz = lm["At"]
        y = E.ground_y(P, cx, cz)
        slots = pad_layout.arrange(got)["slots"]
        blocks, lo, hi = [], 1e9, -1e9
        placed[pad] = []
        for p in got:
            sx, sz = slots[p["Name"]]
            nx, nz = cx + sx, cz + sz
            hx, hz = p["Size"][0] / 2, p["Size"][1] / 2
            placed[pad].append([nx - hx, nz - hz, nx + hx, nz + hz])
            for i in range(E.cell_of(nx - hx, 0)[0], E.cell_of(nx + hx, 0)[0] + 1):
                for j in range(E.cell_of(0, nz - hz)[1], E.cell_of(0, nz + hz)[1] + 1):
                    t = P.top[i][j]
                    if t is not None:
                        lo, hi = min(lo, t), max(hi, t)
            members = p["Members"]
            counts = {m: len(boxes[m]) for m in members}
            miny = min(b[0][1] for m in members for b in boxes[m])
            blocks.append({"Name": p["Name"], "Members": members, "Counts": counts, "Center": [_r(v) for v in p["Center"]],
                           "Size": [_r(v) for v in p["Size"]], "MinY": _r(miny), "Slot": [_r(sx), _r(sz)],
                           "Riders": RIDERS.get(p["Name"], [])})
        assert lo == hi == y, "%s is not flat under its blocks: Flat [%s, %s], centre %s" % (pad, lo, hi, y)
        out[pad] = {"At": [cx, y, cz], "Radius": lm["Radius"], "Flat": [lo, hi], "Blocks": blocks}

    # alchemist spawns: their site's slot, pulled in (pad_layout), then nudged sideways off any block (Carry to Task 5)
    spawn_in = [{"Name": s["Name"], "Pos": s["Pos"]} for s in S["AlchemistSpawns"]]
    sl = pad_layout.spawn_slots(spawn_in, pieces, radii)
    spawns = {}
    for s in S["AlchemistSpawns"]:
        e = sl[s["Name"]]
        assert e["Offset"] is not None, "spawn %s has no pad" % s["Name"]
        pad = e["Pad"]
        cx, cz = reserve[pad]["At"]
        dx, dz = e["Offset"]
        lim = radii[pad] - pad_layout.SPAWN_INSET
        h = SPAWN_HALF + SPAWN_CLEAR

        def clear(x, z):
            return not any(_overlap([x - h, z - h, x + h, z + h], b) for b in placed[pad])

        nudged = 0.0
        if not clear(cx + dx, cz + dz):
            d = math.hypot(dx, dz) or 1.0
            tx, tz = -dz / d, dx / d  # sideways: perpendicular to the spawn's direction from the pad centre
            best = None
            k = 0.5
            while k <= NUDGE_MAX and best is None:
                for sgn in (1, -1):
                    x, z = dx + sgn * k * tx, dz + sgn * k * tz
                    if math.hypot(x, z) <= lim + 1e-6 and clear(cx + x, cz + z):
                        best = (x, z, sgn * k)
                        break
                k += 0.5
            assert best, "no free pad ground for %s" % s["Name"]
            dx, dz, nudged = best
        y = E.ground_y(P, cx + dx, cz + dz)
        spawns[s["Name"]] = {"Pad": pad, "Site": e["Site"], "XZ": [_r(cx + dx), _r(cz + dz)], "DY": _r(y - GROUND),
                             "Pulled": e["Pulled"], "Nudged": nudged, "From": s["Pos"]}
    out["Spawns"] = spawns

    # trainers onto their TrainerSpot markers, by element
    for m in L["Markers"]:
        a = m.get("Attr", {})
        if a.get("Piece") == "TrainerSpot":
            x, _, z = m["At"]
            out["trainer_" + a["Element"].lower()] = {"At": [x, E.ground_y(P, x, z), z], "Yaw": m.get("Yaw", 0),
                                                      "Trainer": a["Trainer"], "Element": a["Element"]}

    # EliteSpawn: a clear spot a few studs off a Bramble Woods Grunt spawn (Ruling 8; PROPOSAL)
    bw = next(d for d in L["Districts"] if d["Id"] == "bramble_woods")
    grunts = [m["At"] for m in L["Markers"] if m["Tag"] == "RenseiEnemySpawn" and m["Attr"].get("EnemyType") == "Grunt"]
    near = [g for g in grunts if E.in_poly(bw["Poly"], g[0], g[2])]
    assert near, "no Grunt spawn in Bramble Woods"
    water = [s_ for s_ in L["Heights"] if s_["Kind"] == "water"]

    def elite_ok(x, z):
        if not E.in_poly(bw["Poly"], x, z):
            return False
        for r in L["Routes"]:
            if E.poly_dist(r["Line"], x, z)[0] < r["Width"] / 2 + ELITE_ROUTE_CLEAR:
                return False
        for w in water:
            d = E.rect_dist(w["Rect"], x, z) if "Rect" in w else E.poly_dist(w["Line"], x, z)[0] - w["Width"] / 2
            if d < ELITE_WATER_CLEAR:
                return False
        for t in P.trees:
            if math.hypot(t[1] - x, t[2] - z) < E.CLEAR[t[0]] * t[5] + ELITE_TREE_CLEAR:
                return False
        for g in grunts:
            if math.hypot(g[0] - x, g[2] - z) < ELITE_GRUNT_MIN:
                return False
        for lm in reserve.values():
            if math.hypot(lm["At"][0] - x, lm["At"][1] - z) < lm["Radius"] + 6:
                return False
        i, j = E.cell_of(x, z)
        tops = [P.top[a][b] for a in (i - 1, i, i + 1) for b in (j - 1, j, j + 1)]
        if any(t is None or t >= E.WALL_Y for t in tops) or max(tops) - min(tops) > 1:
            return False
        if P.crag[i][j] or P.kind[i][j] is not None:
            return False
        return True

    elite = None
    for rr in ELITE_RING:
        for g in near:
            for k in range(24):
                a = 2 * math.pi * k / 24
                x, z = g[0] + rr * math.cos(a), g[2] + rr * math.sin(a)
                if elite_ok(x, z):
                    elite = (round(x, 1), round(z, 1), g)
                    break
            if elite:
                break
        if elite:
            break
    assert elite, "no clear EliteSpawn spot in Bramble Woods"
    ey = E.ground_y(P, elite[0], elite[1])
    surveyed = [s_ for s_ in S["EnemySpawns"] if s_["Name"] == "EliteSpawn"]
    assert len(surveyed) == 1, "the survey has %d EliteSpawns" % len(surveyed)
    out["EliteSpawn"] = {"XZ": [elite[0], elite[1]], "DY": _r(ey - GROUND), "Near": [elite[2][0], elite[2][2]],
                         "From": surveyed[0]["Pos"],
                         "Note": "PROPOSAL (Ruling 8): %s studs off the Bramble Woods Grunt spawn" %
                                 _r(math.hypot(elite[0] - elite[2][0], elite[1] - elite[2][2]), 1)}

    out["Retire"] = [{"Path": r["Path"], **({"Near": RETIRE_BUFFER, "Within": 5} if r["Path"].endswith("BufferStop") else {}),
                      "Count": 1} for r in S["Retire"]]
    out["Retire"].append({"Path": "World.EnemySpawns.GruntSpawn", "Count": 2})  # Ruling 8: replaced by the expansion's
    out["Lift"] = lift_entries(P, out)
    return out


def lift_entries(P, out):
    """Ruling 17: every item outside World.Map (lift_items.json, from lift_survey.lua) whose XZ box lies on cells the
    plan fills with new ground gets "Top": the highest planned top there (a cell's top, or a route ribbon's surface
    via ground_y at the cell centre). prep_ye.lua lifts its lowest point to Top + LIFT_CLEAR if it is below that.
    Items the prep already moves ("Moved") and items on no new-ground cell (kept village / Adit ground, or nothing
    planned) get Top null and stay put."""
    with open(LIFT_ITEMS, encoding="utf-8") as f:
        items = json.load(f)
    moved = {"Workspace.World.EnemySpawns.EliteSpawn", "Workspace.World.EnemySpawns.GruntSpawn"}
    for blocks in (v["Blocks"] for k, v in out.items() if k.startswith("res_")):
        for b in blocks:
            for r in b["Riders"]:
                moved.add("Workspace.World." + r.replace("/", "."))
    rows = []
    for it in items:
        e = {"Path": it["Path"], "Class": it["Class"], "Pivot": it["Pivot"], "Top": None, "Why": ""}
        rows.append(e)
        if it["Path"] in moved or it["Path"].startswith("Workspace.World.NPCs.Alchemy Trainers."):
            e["Why"] = "moved by the prep"
            continue
        b = it["Box"]
        if not b:
            e["Why"] = "no parts"
            continue
        i0, j0 = E.cell_of(b[0] + 0.01, b[2] + 0.01)
        i1, j1 = E.cell_of(b[3] - 0.01, b[5] - 0.01)
        top = None
        for i in range(max(0, i0), min(E.N - 1, i1) + 1):
            for j in range(max(0, j0), min(E.N - 1, j1) + 1):
                if P.top[i][j] is None:  # kept village / Adit ground, or no ground planned
                    continue
                t = max(float(P.top[i][j]), E.ground_y(P, *E.cell_center(i, j)))
                top = t if top is None else max(top, t)
        if top is None:
            e["Why"] = "on no new-ground cell"
            continue
        e["Top"] = top
        e["Base"] = b[1]
        e["Why"] = "lift %.2f" % (top + LIFT_CLEAR - b[1]) if b[1] < top + LIFT_CLEAR else "already above"
    return rows


def main(argv):
    out = build()
    text = json.dumps(out, indent=1) + "\n"
    if "--check" in argv:
        with open(OUT, encoding="utf-8") as f:
            same = f.read() == text
        print("pads.json is current" if same else "pads.json differs: re-run make_pads.py")
        return 0 if same else 1
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("wrote", OUT)
    for k, v in out.items():
        if k.startswith("res_"):
            print(k, "At", v["At"], "R", v["Radius"], "Flat", v["Flat"],
                  [(b["Name"], b["Slot"], b["Size"]) for b in v["Blocks"]])
        elif k.startswith("trainer_"):
            print(k, v["At"])
    for k, v in out["Spawns"].items():
        print("spawn", k, v)
    print("elite", out["EliteSpawn"])
    for e in out["Lift"]:
        print("lift", e["Path"], e["Pivot"], e["Top"], e["Why"])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

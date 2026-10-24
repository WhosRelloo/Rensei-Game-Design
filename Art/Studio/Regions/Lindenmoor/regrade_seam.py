"""Lindenmoor seam regrade in Studio (Ye), owner 2026-10-24: "Could you rebuild the ground height along the seam in
studio with all of the assets you currently have?" (Ruling 21 done in place, no Blender rebuild, no re-import).

python -I Art/Studio/Regions/Lindenmoor/regrade_seam.py stats
    prints the plan: band, changed cells, exceptions, parts to replace and build.
python -I Art/Studio/Regions/Lindenmoor/regrade_seam.py lua <out.lua> <apply|undo|test|check>
    writes regrade_seam.lua (template regrade_seam.lua.tmpl + this plan as data) with that MODE; run it in Ye (Edit):
        python -I Art/Tools/rbxc.py luau "placeId: 106992859583940" Edit @<out.lua>
    The committed Art/Studio/Regions/Lindenmoor/regrade_seam.lua is the MODE = "apply" build.

Inputs (all read-only): the expansion plan (expansion_plan.plan(), which the imported World.Map.LindenmoorExpansion
was built from: seam_survey.json's SeamNewTops match it on every measured cell), seam_survey.json (Ye's real top at
the footprint's edge, measured by survey_ye.lua) and layout.json.

The regrade (PROPOSAL numbers):
  * boundary cells F: footprint (Ye) cells with a measured top that touch an expansion cell (4-neighbour). Ye's
    height there He = the measured top; where that is below the Baseplate's top (y < 0, the Adit skirt's outer rows,
    where the bare Baseplate shows) the cell gets a 1-stud fill slab (top 1) and He = 1. New ground stays >= 1.
    F needs the regrade only when some expansion cell beside it differs from He by more than 1 stud.
  * every expansion cell within BAND studs of an F (centre to centre, minus one cell) gets
        new = round(cur + (He(F) - cur) * (1 - smoothstep(d / BAND)))   (F = the nearest boundary cell)
    so the cell beside F sits at He(F) and the blend reaches the current top BAND studs out.
  * left untouched (exceptions): crag cells (RenseiNoGrip), channel beds (inside a cut or water shape's Width; a
    bank, its Bank margin or BANK_CELLS beside the bed, is regraded but never below BANK_FLOOR, so the water stays
    in), flat design ground (fields, plateaus such as the training field), route corridors (so
    every ribbon still sits on its ground; only mine_trail's edge in the band, 1 stud), pads (every landmark's flat
    pad radius) and the cells within MARK_R of a point marker (TrainerSpot, RoadPassage, posts, clues, spawns).
  * replaced: every Top slab and Side block covering a changed cell, or touching one (its side's bottom depends on
    its neighbours); rebuilt as greedy-merged rects of equal (top, material, crag) up to MAX_SPAN cells, Top slabs
    1 thick, Sides down to min(neighbour tops) - 1 (a Ye neighbour counts at its measured top), each cloned from
    the part it replaces so Material, Color, MaterialVariant and tags match.
  * objects standing on a changed cell move by its height change (regrade_seam.lua does it from DELTA).
"""
import json, math, os, sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, "Art", "Blender", "lindenmoor"))
import expansion_plan as E  # noqa: E402  (pure Python, no bpy)

SEAM = os.path.join(HERE, "seam_survey.json")
TEMPLATE = os.path.join(HERE, "regrade_seam.lua.tmpl")
BAND = 64  # studs over which the new ground blends from Ye's edge to its planned height (Ruling 21; PROPOSAL)
JUMP_OK = 1  # a boundary jump up to this many studs is left as it is (PROPOSAL)
MARK_R = 6  # studs around a point marker left untouched (PROPOSAL)
BANK_CELLS = 2  # cells beside a channel's bed that count as its bank (PROPOSAL)
BANK_FLOOR = 6  # a regraded bank cell stays at least this high: the channels' water surface is y 5.2 (PROPOSAL)
SRC_R = 8.5  # studs: the boundary cells whose median Ye height a seam cell starts from (PROPOSAL)
UNEVEN = 1  # a boundary cell more than this off its neighbours' median is a Ye edge step (reported, PROPOSAL)
# 'ye_step' boundary pairs keep a jump: Ye's own edge steps there (a cell off its neighbours' median, or Ye cells on two
# sides of one new cell more than 2 studs apart), so no single new height can meet it within JUMP_OK
MAX_SPAN = E.MAX_SPAN
N, CELL, HALF = E.N, E.CELL, E.HALF
NB4 = ((1, 0), (-1, 0), (0, 1), (0, -1))


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def cell_xz(i, j):
    """min corner of a cell in world studs (the survey's cell key)"""
    return -HALF + CELL * i, -HALF + CELL * j


def channel_mask(L):
    """(beds, banks): beds = cells inside a cut or water shape's bed (Line: within Width/2; Rect: inside); banks =
    the cut's Bank margin plus every cell within BANK_CELLS of a bed, beds excluded"""
    beds, banks = set(), set()
    shapes = [s for s in L["Heights"] if s["Kind"] in ("cut", "water")]
    for i in range(N):
        for j in range(N):
            x, z = E.cell_center(i, j)
            for s in shapes:
                if "Line" in s:
                    d = E.poly_dist(s["Line"], x, z)[0]
                    if d <= s["Width"] / 2:
                        beds.add((i, j))
                    elif d <= s["Width"] / 2 + s.get("Bank", 0):
                        banks.add((i, j))
                elif E.in_rect(s["Rect"], x, z):
                    beds.add((i, j))
    for i, j in beds:
        for a in range(-BANK_CELLS, BANK_CELLS + 1):
            for b in range(-BANK_CELLS, BANK_CELLS + 1):
                banks.add((i + a, j + b))
    return beds, banks - beds


def compute():
    L = E.load()
    P = E.plan(L)
    S = json.load(open(SEAM, encoding="utf-8"))
    ye = {}  # (i, j) -> measured Ye top, for footprint cells within 2 cells of the edge
    for x, z, y, n, ring in S["SeamHeights"]:
        if y != -999:
            ye[E.cell_of(x + 2, z + 2)] = y
    top, keep = P.top, P.keep
    new = lambda i, j: 0 <= i < N and 0 <= j < N and top[i][j] is not None and not keep[i][j]

    # exceptions
    exc = {}
    for i in range(N):
        for j in range(N):
            if not new(i, j):
                continue
            if P.crag[i][j]:
                exc[(i, j)] = "crag"
            elif P.flat[i][j]:
                exc[(i, j)] = "flat"
            elif P.kind[i][j] is not None:
                exc[(i, j)] = "route"  # a route's corridor keeps its ground, so its ribbon still sits on it
    beds, banks = channel_mask(L)
    for c in beds:
        if new(*c) and exc.get(c) != "crag":
            exc[c] = "channel"
    banks = {c for c in banks if new(*c) and exc.get(c) not in ("crag", "channel")}
    for lm in L["Landmarks"]:
        R = E.pad_r(lm)
        if R <= 0:
            continue
        ci, cj = E.cell_of(*lm["At"])
        rr = int(R / CELL) + 2
        for i in range(ci - rr, ci + rr + 1):
            for j in range(cj - rr, cj + rr + 1):
                if new(i, j) and math.dist(E.cell_center(i, j), lm["At"]) <= R:
                    exc.setdefault((i, j), "pad")
    for m in L["Markers"]:
        if "At" not in m:
            continue
        ci, cj = E.cell_of(m["At"][0], m["At"][2])
        for i in range(ci - 3, ci + 4):
            for j in range(cj - 3, cj + 4):
                if new(i, j) and math.dist(E.cell_center(i, j), (m["At"][0], m["At"][2])) <= MARK_R:
                    exc.setdefault((i, j), "marker")

    # boundary cells and their jumps
    F = {}
    for (i, j), y in ye.items():
        nb = [(i + a, j + b) for a, b in NB4 if new(i + a, j + b)]
        if nb:
            he = y if y >= -0.05 else 1  # a sunken Ye cell (below the Baseplate's top) gets a fill slab with top 1
            F[(i, j)] = (he, max(abs(top[a][b] - he) for a, b in nb), nb)
    grid = defaultdict(list)
    for f in F:
        grid[(f[0] // 16, f[1] // 16)].append(f)

    # Ye's edge is jagged (its rim steps up and down cell by cell), so the blend starts from a robust local edge
    # height: the median He of the boundary cells within SRC_R studs, not one cell's He (which would cut 4-stud
    # trenches or spikes out into the new ground at every notch)
    def src(c, d0=None):
        hs = [F[g][0] for g in F if abs(g[0] - c[0]) <= 2 and abs(g[1] - c[1]) <= 2
              and CELL * math.hypot(g[0] - c[0], g[1] - c[1]) <= SRC_R]
        hs.sort()
        return hs[len(hs) // 2] if len(hs) % 2 else (hs[len(hs) // 2 - 1] + hs[len(hs) // 2]) / 2
    Fsrc = {f: src(f) for f in F}  # the smoothed edge height at each boundary cell

    # the blend
    newtop = [row[:] for row in top]
    near = {}
    for i in range(N):
        for j in range(N):
            if not new(i, j):
                continue
            best = None
            for a in range(i // 16 - 2, i // 16 + 3):
                for b in range(j // 16 - 2, j // 16 + 3):
                    for f in grid.get((a, b), ()):
                        d = CELL * math.hypot(f[0] - i, f[1] - j)
                        if best is None or d < best[0] - 1e-6:
                            best = (d, f)
            if best is None or best[0] - CELL >= BAND:
                continue
            near[(i, j)] = best
            d, f = best
            if (i, j) in exc:
                continue
            # the edge height: the median of the boundary cells around this cell (if it touches any), else the
            # smoothed edge height at its nearest boundary cell; skipped where that edge already meets within 1
            adj = [g for g in ((i + a, j + b) for a, b in NB4) if g in F]
            if adj:  # beside the edge: meet its cells (their own heights, or the median where a cell is a Ye step)
                cand = [F[g][0] for g in adj if abs(F[g][0] - Fsrc[g]) <= UNEVEN] or [Fsrc[g] for g in adj]
                he = (min(cand) + max(cand)) / 2
            else:
                close = [g for g in F if abs(g[0] - i) <= 2 and abs(g[1] - j) <= 2
                         and CELL * math.hypot(g[0] - i, g[1] - j) <= SRC_R]
                he = src((i, j)) if close else Fsrc[f]
            cur = top[i][j]
            if max(F[f][1], abs(cur - he) if d <= CELL else 0) <= JUMP_OK:
                continue
            y = max(1, round(cur + (he - cur) * (1 - smooth((d - CELL) / BAND))))
            if (i, j) in banks:
                y = max(y, min(cur, BANK_FLOOR))  # a bank keeps the channel's water in: never below BANK_FLOOR
            newtop[i][j] = y
    changed = {(i, j) for (i, j) in near if newtop[i][j] != top[i][j]}

    # parts to replace: every old rect covering a changed cell or 8-touching one
    touch = set()
    for i, j in changed:
        for a in (-1, 0, 1):
            for b in (-1, 0, 1):
                touch.add((i + a, j + b))
    owner = {}
    for (i, j, w, d, y, m, c) in P.tops:
        for a in range(w):
            for b in range(d):
                owner[(i + a, j + b)] = (i, j, w, d, y, m, c)
    sides = {(s[0], s[1]): s for s in P.sides}
    rebuild_rects = {owner[c] for c in touch if c in owner}
    cells = set()
    for (i, j, w, d, y, m, c) in rebuild_rects:
        for a in range(w):
            for b in range(d):
                cells.add((i + a, j + b))
    # parts as [kind "T"/"S", i, j, w, d, a, b]: a Top slab's top is a (b unused), a Side block runs from a up to b.
    # Studio name kind..i.."_"..j in model Ground_<i // 64>_<j // 64>, at x -1024 + 4i .. + 4w, z likewise.
    old_parts = []
    for (i, j, w, d, y, m, c) in sorted(rebuild_rects):
        old_parts.append(["T", i, j, w, d, y, 0])
        s = sides.get((i, j))
        if s:
            old_parts.append(["S", i, j, w, d, s[4], s[5]])

    # rebuild: greedy merge over the replaced cells with the new tops (Ye neighbours at their measured top)
    def nb_top(i, j, y):
        if not (0 <= i < N and 0 <= j < N):
            return 0
        if newtop[i][j] is not None and not keep[i][j]:
            return newtop[i][j]
        return ye.get((i, j), y)  # a Ye cell: its measured top, else level (as the plan assumes)

    key = lambda c: (newtop[c[0]][c[1]], P.mat[c[0]][c[1]], P.crag[c[0]][c[1]])
    used = set()
    new_parts = []
    side_tpl = {}
    for p in old_parts:
        if p[0] == "S":
            side_tpl.setdefault(P.crag[p[1]][p[2]], (p[1], p[2]))
    for j in range(N):
        for i in range(N):
            if (i, j) not in cells or (i, j) in used:
                continue
            k = key((i, j))
            w = 1
            while w < MAX_SPAN and (i + w, j) in cells and (i + w, j) not in used and key((i + w, j)) == k:
                w += 1
            d = 1
            while d < MAX_SPAN and all((i + a, j + d) in cells and (i + a, j + d) not in used and key((i + a, j + d)) == k
                                       for a in range(w)):
                d += 1
            for a in range(w):
                for b in range(d):
                    used.add((i + a, j + b))
            y = k[0]
            o = owner[(i, j)]
            # [kind, i, j, w, d, a, b, crag, template kind, template i, template j]: cloned from an old part it replaces
            new_parts.append(["T", i, j, w, d, y, 0, bool(k[2]), "T", o[0], o[1]])
            lo = y - 2
            ring = [(i + a, j + b) for a in range(-1, w + 1) for b in (-1, d)] + \
                   [(i + a, j + b) for b in range(d) for a in (-1, w)]
            nbs = [nb_top(a, b, y) for a, b in ring]
            lo = max(0, min([lo] + [t - 1 for t in nbs]))
            if lo >= y - 2 and min(nbs) >= y:
                continue  # nothing beside it is lower: no side shows
            if y - 1 - lo > 0.01:
                os_ = sides.get((o[0], o[1]))
                t = (o[0], o[1]) if os_ and os_[6] == k[2] else (side_tpl.get(k[2]) or side_tpl.get(not k[2]))
                new_parts.append(["S", i, j, w, d, lo, y - 1, bool(k[2]), "S", t[0], t[1]])

    delta = {c: newtop[c[0]][c[1]] - top[c[0]][c[1]] for c in changed}
    return dict(L=L, P=P, ye=ye, F=F, Fsrc=Fsrc, exc=exc, banks=banks, near=near, newtop=newtop, changed=changed, delta=delta,
                old_parts=old_parts, new_parts=new_parts)


def pair_class(R, f, c):
    """why a boundary pair may keep a jump over JUMP_OK: the expansion cell is an exception ('crag', 'channel',
    'flat', 'pad', 'marker'), or the Ye cell is a step in Ye's own jagged edge ('ye_step': its height is more than
    UNEVEN off the median of the boundary cells around it); '' = no excuse, the jump must be <= JUMP_OK"""
    if c in R["exc"]:
        return R["exc"][c]
    if c in R["banks"] and R["newtop"][c[0]][c[1]] == min(R["P"].top[c[0]][c[1]], BANK_FLOOR):
        return "channel_bank"  # held at BANK_FLOOR (or its old top, if lower) to keep the channel's water in
    if abs(R["F"][f][0] - R["Fsrc"][f]) > UNEVEN:
        return "ye_step"
    hs = [R["F"][g][0] for g in ((c[0] + a, c[1] + b) for a, b in NB4) if g in R["F"]]
    if max(hs) - min(hs) > 2 * JUMP_OK:
        return "ye_step"  # Ye cells on two sides of this cell differ by more than one height can meet
    return ""


def boundary_pairs(R):
    """every (F cell, expansion neighbour) pair: [Ye x0, z0, He, new x0, z0, class]"""
    out = []
    for f, (he, jump, nb) in sorted(R["F"].items()):
        for c in nb:
            out.append([*cell_xz(*f), he, *cell_xz(*c), pair_class(R, f, c)])
    return out


def stats(R):
    P = R["P"]
    from collections import Counter
    exc_band = Counter(v for c, v in R["exc"].items() if c in R["near"])
    print(f"boundary cells {len(R['F'])}, needing the regrade {sum(1 for v in R['F'].values() if v[1] > JUMP_OK)}")
    print(f"band cells {len(R['near'])}, changed {len(R['changed'])}, exceptions in the band {dict(exc_band)}")
    ds = sorted(R["delta"].values())
    if ds:
        print(f"height change: min {ds[0]}, max {ds[-1]}, median {ds[len(ds) // 2]}")
    fr = fill_rects(R)
    print(f"parts replaced {len(R['old_parts'])}, built {len(R['new_parts'])} (net {len(R['new_parts']) - len(R['old_parts'])}); "
          f"baseplate fill slabs {len(fr)} over {sum(r[2] for r in fr)} Ye cells")
    # predicted boundary jumps after the regrade
    big = Counter()
    worst = 0
    for f, (he, jump, nb) in R["F"].items():
        for a, b in nb:
            j = R["newtop"][a][b] - he
            cls = pair_class(R, f, (a, b))
            if abs(j) > JUMP_OK:
                big[cls or "UNEXPLAINED"] += 1
            if not cls:
                worst = max(worst, abs(j))
    print(f"predicted boundary jumps > {JUMP_OK}: {dict(big)}; worst non-exception {worst}")
    walls = Counter()
    for (i, j), v in R["exc"].items():
        if (i, j) not in R["near"]:
            continue
        for a, b in NB4:
            c = (i + a, j + b)
            if c in R["changed"] and abs(R["newtop"][c[0]][c[1]] - P.top[i][j]) > 4:
                walls[v] += 1
                break
    print(f"exception cells now beside a > 4-stud step: {dict(walls)}")
    routes = Counter(P.kind[i][j] for (i, j) in R["changed"] if P.kind[i][j])
    print(f"changed route cells by kind: {dict(routes)}")


def fill_rects(R):
    """Ye edge cells whose own top lies below the Baseplate's top (y < 0: the Adit skirt's outer rows, where the bare
    Baseplate shows), merged along x into [i, j, w, 1]: regrade_seam.lua covers each with a 1-stud slab (top y 1)
    cloned from the Ye part there, inside the expansion (Ye's parts stay untouched)"""
    cells = sorted(c for c, y in R["ye"].items() if y < -0.05)
    out, done = [], set()
    for i, j in sorted(cells, key=lambda c: (c[1], c[0])):
        if (i, j) in done:
            continue
        w = 1
        while (i + w, j) in R["ye"] and R["ye"][(i + w, j)] < -0.05 and (i + w, j) not in done and w < MAX_SPAN:
            w += 1
        for a in range(w):
            done.add((i + a, j))
        out.append([i, j, w, 1])
    return out


def lua_data(R):
    """the plan as compact JSON strings for regrade_seam.lua"""
    dl = sorted([i, j, d] for (i, j), d in R["delta"].items())
    return {
        "OLD": json.dumps(R["old_parts"], separators=(",", ":")),
        "NEW": json.dumps(R["new_parts"], separators=(",", ":")),
        "DELTA": json.dumps(dl, separators=(",", ":")),
        "PAIRS": json.dumps(boundary_pairs(R), separators=(",", ":")),
        "FILL": json.dumps(fill_rects(R), separators=(",", ":")),
        "ROUTES": json.dumps({r["Id"]: r["Line"] for r in R["L"]["Routes"] if r["Kind"] != "ledge"}, separators=(",", ":")),
    }


def write_lua(R, out, mode):
    assert mode in ("apply", "undo", "test", "check"), mode
    src = open(TEMPLATE, encoding="utf-8").read()
    d = lua_data(R)
    src = src.replace("--@@MODE@@", f'local MODE = "{mode}"')
    for k, v in d.items():
        assert "]==]" not in v
        src = src.replace(f"--@@{k}@@", f"local {k}_JSON = [==[{v}]==]")
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write(src)
    print(f"wrote {out} ({len(src)} chars, MODE {mode})")


if __name__ == "__main__":
    R = compute()
    if sys.argv[1:2] == ["stats"]:
        stats(R)
    elif sys.argv[1:2] == ["lua"] and len(sys.argv) == 4:
        write_lua(R, sys.argv[2], sys.argv[3])
    else:
        print(__doc__)
        sys.exit(2)

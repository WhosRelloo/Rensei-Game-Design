"""Lindenmoor seam pits and trenches (Ruling 27), a separate reversible step on top of the seam regrade.

python -I Art/Studio/Regions/Lindenmoor/seam_pits.py stats
python -I Art/Studio/Regions/Lindenmoor/seam_pits.py lua <out.lua> <apply|undo|test|check>
    writes seam_pits.lua (template seam_pits.lua.tmpl + this plan) with that MODE; run it in Ye (Edit) AFTER
    regrade_seam.lua is applied. The committed Art/Studio/Regions/Lindenmoor/seam_pits.lua is the MODE = "apply" build.
    Undo order: seam_pits undo, then regrade_seam undo, then import/restore.lua.

After the regrade, 185 boundary pairs kept a step over 1 stud. Most are pits: Ye's outermost rim cells sit far below
both the Ye cell inward of them and the expansion beside them (Ye's own skirt; open to the outside before the import,
4-stud shafts up to 34 deep now). The rest are trenches: the blend started from the edge's median height, which the
pits dragged down. This step:
  * pits: a Ye boundary cell whose top is more than 1 below both min(adjacent expansion top) and its highest Ye
    neighbour (inward or along the edge: a shaft or a notch in Ye's rim) gets a fill block
    cloned from the Ye part in that cell, from its Ye top up to min(inner Ye, adjacent expansion), inside the
    expansion (LindenmoorExpansion.SeamPitsFill). Ye's own parts are not moved or edited.
  * trenches: the regrade blend is recomputed (regrade_seam.compute) with the filled heights, the pit cells left
    out of the edge medians, and every cell beside the edge starting at its Ye neighbours' own heights. Cells that
    come out different from the regrade's are rebuilt (their Top/Side parts cloned, originals to the backup), except
    channel banks and cells beside a channel bed (the gorge fix's water ring lives there: those keep the regrade's
    height and are reported).
"""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import regrade_seam as G  # noqa: E402

E, N, NB4, JUMP_OK = G.E, G.N, G.NB4, G.JUMP_OK
TEMPLATE = os.path.join(HERE, "seam_pits.lua.tmpl")


def compute():
    R1 = G.compute()  # the regrade as applied in Ye
    P, ye, top1 = R1["P"], R1["ye"], R1["newtop"]
    pits = {}
    for f, (he, jump, nb) in R1["F"].items():
        cand = [ye[g] for g in ((f[0] + a, f[1] + b) for a, b in NB4) if g in ye and g not in nb]
        if not cand:
            continue
        t = min(max(cand), min(top1[n[0]][n[1]] for n in nb))
        if t > he + JUMP_OK:
            pits[f] = (ye[f], round(t, 1))  # fill from Ye's own top up to t
    # a pit beside a channel bed or bank stays as it is (the creek mouths' water and the gorge fix's water ring)
    beds = {c for c, v in R1["exc"].items() if v == "channel"}
    wet = beds | R1["banks"]
    X_wet = sorted(f for f in pits if any((f[0] + a, f[1] + b) in wet for a in (-1, 0, 1) for b in (-1, 0, 1)))
    for f in X_wet:
        del pits[f]
    fix = {f: v[1] for f, v in pits.items()}
    R2 = G.compute(he_fix=fix, skip_src=frozenset(pits), own_height=True)
    top2 = R2["newtop"]
    # channel banks and cells beside a channel bed keep the regrade's height (the gorge fix's water ring is there)
    beds = {c for c, v in R2["exc"].items() if v == "channel"}
    near_bed = set()
    for i, j in beds:
        for a in (-1, 0, 1):
            for b in (-1, 0, 1):
                near_bed.add((i + a, j + b))
    frozen = []
    for i in range(N):
        for j in range(N):
            if top2[i][j] != top1[i][j] and ((i, j) in R2["banks"] or (i, j) in near_bed):
                frozen.append((i, j))
                top2[i][j] = top1[i][j]
    changed = {(i, j) for i in range(N) for j in range(N) if top2[i][j] != top1[i][j]}
    # the ground as it stands after the regrade: plan rects it did not replace + the rects it built
    replaced = {(p[1], p[2]) for p in R1["old_parts"] if p[0] == "T"}
    rects = [r for r in P.tops if (r[0], r[1]) not in replaced]
    sides = {(s[0], s[1]): s for s in P.sides if (s[0], s[1]) not in replaced}
    for p in R1["new_parts"]:
        k, i, j, w, d, a, b, crag = p[:8]
        if k == "T":
            rects.append((i, j, w, d, a, P.mat[i][j], crag))
        else:
            sides[(i, j)] = (i, j, w, d, a, b, crag)
    old_parts, new_parts = G.rebuild(P, ye, top2, changed, rects, sides)
    delta = {c: top2[c[0]][c[1]] - top1[c[0]][c[1]] for c in changed}
    R2.update(newtop=top2, changed=changed, delta=delta, old_parts=old_parts, new_parts=new_parts)
    return dict(R1=R1, R2=R2, pits=pits, frozen=frozen, wet_pits=X_wet)


def fill_rects(X):
    """pit cells merged along x where bottom and top match: [i, j, w, 1, bottom, top]"""
    out, done = [], set()
    pits = X["pits"]
    for (i, j) in sorted(pits, key=lambda c: (c[1], c[0])):
        if (i, j) in done:
            continue
        w = 1
        while (i + w, j) in pits and (i + w, j) not in done and pits[(i + w, j)] == pits[(i, j)] and w < G.MAX_SPAN:
            w += 1
        for a in range(w):
            done.add((i + a, j))
        out.append([i, j, w, 1, pits[(i, j)][0], pits[(i, j)][1]])
    return out


def pairs(X):
    """every Ye<->expansion boundary pair after this step: [Ye x0, z0, He (filled), new x0, z0, class]"""
    R2 = X["R2"]
    out = []
    for f, (he, jump, nb) in sorted(R2["F"].items()):
        for c in nb:
            out.append([*G.cell_xz(*f), he, *G.cell_xz(*c), G.pair_class(R2, f, c)])
    return out


def stats(X):
    from collections import Counter
    R1, R2 = X["R1"], X["R2"]
    print(f"pits left alone beside channel water: {[G.cell_xz(*c) for c in X['wet_pits']]}")
    print(f"pits {len(X['pits'])} cells, fill blocks {len(fill_rects(X))}; depth filled: max "
          f"{max(t - b for b, t in X['pits'].values()):.1f}")
    print(f"re-blend: {len(X['R2']['changed'])} cells change ({len(X['frozen'])} channel-bank cells held at the regrade's "
          f"height), parts replaced {len(R2['old_parts'])}, built {len(R2['new_parts'])}")
    def tally(R):
        c, worst, walls = Counter(), {}, 0
        for f, (he, jump, nb) in R["F"].items():
            for n in nb:
                j = R["newtop"][n[0]][n[1]] - he
                if abs(j) > JUMP_OK:
                    k = G.pair_class(R, f, n) or "UNEXCUSED"
                    c[k] += 1
                    worst[k] = max(worst.get(k, 0), abs(j))
                    if j > JUMP_OK and k not in ("crag", "channel"):
                        walls += 1
        return dict(c), worst, walls
    print("after the regrade:", tally(R1))
    print("after this step:  ", tally(R2))
    rest = [(G.cell_xz(*f), he, G.cell_xz(*n), R2["newtop"][n[0]][n[1]]) for f, (he, jump, nb) in R2["F"].items()
            for n in nb if abs(R2["newtop"][n[0]][n[1]] - he) > JUMP_OK and G.pair_class(R2, f, n) == "ye_step"]
    print("ye_step left:", len(rest), rest[:12])
    new_walls = []
    for f, (he, jump, nb) in R2["F"].items():
        for n in nb:
            j2 = R2["newtop"][n[0]][n[1]] - he
            j1 = R1["newtop"][n[0]][n[1]] - R1["F"][f][0]
            if j2 > JUMP_OK and j1 <= JUMP_OK and G.pair_class(R2, f, n) not in ("crag", "channel"):
                new_walls.append((G.cell_xz(*f), he, G.cell_xz(*n), R2["newtop"][n[0]][n[1]]))
    print("new walls over 1 stud:", len(new_walls), new_walls[:8])


def write_lua(X, out, mode):
    assert mode in ("apply", "undo", "test", "check"), mode
    src = open(TEMPLATE, encoding="utf-8").read()
    R2 = X["R2"]
    d = {
        "OLD": json.dumps(R2["old_parts"], separators=(",", ":")),
        "NEW": json.dumps(R2["new_parts"], separators=(",", ":")),
        "DELTA": json.dumps(sorted([i, j, v] for (i, j), v in R2["delta"].items()), separators=(",", ":")),
        "PAIRS": json.dumps(pairs(X), separators=(",", ":")),
        "FILL": json.dumps(fill_rects(X), separators=(",", ":")),
        "ROUTES": json.dumps({r["Id"]: r["Line"] for r in R2["L"]["Routes"] if r["Kind"] != "ledge"}, separators=(",", ":")),
    }
    src = src.replace("--@@MODE@@", f'local MODE = "{mode}"')
    for k, v in d.items():
        assert "]==]" not in v
        src = src.replace(f"--@@{k}@@", f"local {k}_JSON = [==[{v}]==]")
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write(src)
    print(f"wrote {out} ({len(src)} chars, MODE {mode})")


if __name__ == "__main__":
    X = compute()
    if sys.argv[1:2] == ["stats"]:
        stats(X)
    elif sys.argv[1:2] == ["lua"] and len(sys.argv) == 4:
        write_lua(X, sys.argv[2], sys.argv[3])
    else:
        print(__doc__)
        sys.exit(2)

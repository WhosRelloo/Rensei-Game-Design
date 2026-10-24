"""Lindenmoor road cutting (Ruling 31): the expansion ground under the north-east road (Travel, built by setup.lua at
RoadY 7) is regraded so its top sits exactly at the road's underside; around it, it blends back to the existing ground.

python -I Art/Studio/Regions/Lindenmoor/road_cut.py measure
    read-only: runs a measuring snippet in Ye (Edit) and writes road_survey.json next to this file: every road column
    (the Top slab and the Side block under it, by XZ footprint), the RoadPoints, and the road's dressing models.
python -I Art/Studio/Regions/Lindenmoor/road_cut.py stats
python -I Art/Studio/Regions/Lindenmoor/road_cut.py lua <out.lua> <apply|undo|check|test>
    writes road_cut.lua (template road_cut.lua.tmpl + this plan) with that MODE; run in Ye (Edit):
        python -I Art/Tools/rbxc.py luau "placeId: 106992859583940" Edit @<out.lua>
    The committed Art/Studio/Regions/Lindenmoor/road_cut.lua is the MODE = "apply" build.

The plan (PROPOSAL numbers), on the ground as it stands after the seam regrade and seam_pits (which this reads from
their own planners, so the parts it replaces are known by name and position; road_cut.lua refuses if any differs):
  * corridor: every 4-stud cell whose centre lies within MARGIN studs of a road column's footprint; its new top = the
    underside of the nearest column (the lowest bottom of its Top/Side parts: y 6 everywhere), so no hollow is left
    under the road and its built banks stand on the ground;
  * blend: cells within L studs outside the corridor go new = round(cur + (edge - cur)(1 - smoothstep(d/L))),
    edge = the nearest corridor cell's new top, d = the distance to it, L = BLEND, or STEEP x |edge - cur| where that
    is longer (up to BLEND_MAX), so the blend's steps stay about 1 stud;
  * ramp: any neighbour outside the corridor still more than 1 stud off a regraded cell is clamped to within 1 of it
    (and so on outward), so the regrade never leaves a new wall or trench over 1 stud;
  * left alone: crag cells (RenseiNoGrip), the expansion's own route corridors outside the road's footprint (the
    rails beside it), the water channels' beds and banks (the gorge, the west creek), Ye's own
    cells, and the road and its travel pieces themselves (reported if the corridor crosses crag or a channel). The
    NE gap is a dry cut the road runs through: it is regraded like any ground;
  * the Top/Side parts covering a changed cell (or touching one) are rebuilt as merged clones; objects standing on a
    changed cell outside the road's footprint move by its height change (road_cut.lua).
"""
import json, math, os, re, subprocess, sys, tempfile
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
sys.path.insert(0, HERE)
import regrade_seam as G  # noqa: E402
import seam_pits as SP  # noqa: E402

E, N, CELL = G.E, G.N, G.CELL
RBXC = os.path.join(REPO, "Art", "Tools", "rbxc.py")
STUDIO = "placeId: 106992859583940"
SURVEY = os.path.join(HERE, "road_survey.json")
TEMPLATE = os.path.join(HERE, "road_cut.lua.tmpl")
MARGIN = 4  # studs beyond the road's columns that sit at the road's underside (Ruling 31)
BLEND = 16  # studs over which the cut blends back to the existing ground (Ruling 31; PROPOSAL)
STEEP = 6  # ... or STEEP x the height change, if longer, so a blend step stays <= ~1 stud per cell (PROPOSAL)
BLEND_MAX = 48  # but never further than this (PROPOSAL)

MEASURE = r'''
local HS = game:GetService("HttpService")
local CS = game:GetService("CollectionService")
local EX = workspace.World.Map.LindenmoorExpansion
local T = EX:FindFirstChild("Travel")
assert(T, "no Travel")
local road = T:FindFirstChildWhichIsA("Model")
local out = { road = road:GetFullName(), cols = {}, points = {}, dress = {}, other = {} }
local function r2(v) return math.floor(v * 100 + 0.5) / 100 end
local cols = {}
for _, p in ipairs(road.Ground:GetChildren()) do
	if p:IsA("BasePart") then
		local key = ("%.2f,%.2f"):format(p.Position.X, p.Position.Z)
		local c = cols[key] or { x = r2(p.Position.X), z = r2(p.Position.Z), sx = r2(p.Size.X), sz = r2(p.Size.Z),
			ry = r2(p.Orientation.Y), lo = 1e9, hi = -1e9, n = 0 }
		cols[key] = c
		c.lo = math.min(c.lo, r2(p.Position.Y - p.Size.Y / 2))
		c.hi = math.max(c.hi, r2(p.Position.Y + p.Size.Y / 2))
		c.n += 1
		c.sx = math.max(c.sx, r2(p.Size.X))
		c.sz = math.max(c.sz, r2(p.Size.Z))
	end
end
for _, c in pairs(cols) do table.insert(out.cols, { c.x, c.z, c.sx, c.sz, c.ry, c.lo, c.hi, c.n }) end
for _, d in ipairs(road:GetDescendants()) do
	if d:IsA("Attachment") and d.Name == "RoadPoint" then
		local w = d.WorldPosition
		table.insert(out.points, { d:GetAttribute("S"), r2(w.X), r2(w.Y), r2(w.Z) })
	end
end
for _, c in ipairs(road:GetChildren()) do
	if c:IsA("Model") and c.Name ~= "Ground" then
		local cf, size = c:GetBoundingBox()
		local pv = c:GetPivot().Position
		table.insert(out.dress, { c.Name, r2(pv.X), r2(pv.Z), r2(cf.Position.Y - size.Y / 2), r2(size.X), r2(size.Z) })
	elseif c:IsA("BasePart") then
		table.insert(out.other, { c.Name, r2(c.Position.X), r2(c.Position.Y), r2(c.Position.Z), r2(c.Size.X), r2(c.Size.Y), r2(c.Size.Z) })
	end
end
local s = HS:JSONEncode(out)
local sv = game:GetService("ServerStorage"):FindFirstChild("LMRoadSurvey") or Instance.new("StringValue")
sv.Name = "LMRoadSurvey"
sv.Value = s
sv.Parent = game:GetService("ServerStorage")
return "LMRoadSurvey written: " .. #s
'''
READ = '''local v = game:GetService("ServerStorage"):FindFirstChild("LMRoadSurvey")
if not v then return "@@ERR@@" end
local s, a = v.Value, %d
local b = math.min(a + %d - 1, #s)
return "@@" .. #s .. "@@" .. (b + 1) .. "@@" .. string.sub(s, a, b) .. "@@END@@"
'''
CLEAN = '''local v = game:GetService("ServerStorage"):FindFirstChild("LMRoadSurvey")
if v then v:Destroy() end
return "@@clean=" .. tostring(game:GetService("ServerStorage"):FindFirstChild("LMRoadSurvey")) .. "@@"
'''


def _luau(code, tmp):
    path = os.path.join(tmp, "snippet.lua")
    with open(path, "w", encoding="utf-8") as f:
        f.write(code)
    r = subprocess.run([sys.executable, "-I", RBXC, "luau", STUDIO, "Edit", "@" + path], capture_output=True, text=True,
                       encoding="utf-8", env=dict(os.environ, PYTHONIOENCODING="utf-8"), timeout=900)
    if r.returncode != 0 or "(isError)" in r.stdout:
        raise SystemExit("bridge error:\n" + r.stdout + r.stderr)
    return r.stdout


def measure():
    with tempfile.TemporaryDirectory() as tmp:
        try:
            first = _luau(MEASURE, tmp)
            if "LMRoadSurvey written" not in first:
                raise SystemExit("measure did not run: " + first[:400])
            parts, a, total = [], 1, None
            while total is None or a <= total:
                m = re.search(r"@@(\d+)@@(\d+)@@(.*)@@END@@", _luau(READ % (a, 20000), tmp), re.S)
                total, a = int(m.group(1)), int(m.group(2))
                parts.append(m.group(3))
            data = json.loads("".join(parts))
        finally:
            gone = _luau(CLEAN, tmp)
    assert "@@clean=nil@@" in gone, gone
    with open(SURVEY, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, separators=(",", ":"))
        f.write("\n")
    print(f"road_survey.json: {len(data['cols'])} columns, {len(data['points'])} RoadPoints, {len(data['dress'])} dressing models")


def col_dist(c, x, z):
    """distance from (x, z) to a column's footprint (an oriented rectangle)"""
    cx, cz, sx, sz, ry = c[0], c[1], c[2], c[3], c[4]
    a = math.radians(ry)
    dx, dz = x - cx, z - cz
    # Roblox yaw: local X = (cos, -sin), local Z = (sin, cos) in world (x, z)
    lx = dx * math.cos(a) - dz * math.sin(a)
    lz = dx * math.sin(a) + dz * math.cos(a)
    ex, ez = max(abs(lx) - sx / 2, 0), max(abs(lz) - sz / 2, 0)
    return math.hypot(ex, ez)


def current_state():
    """the expansion ground as it stands in Ye: plan, then the seam regrade, then seam_pits"""
    X = SP.compute()
    R1, R2 = X["R1"], X["R2"]
    P = R1["P"]
    top = R2["newtop"]
    rects = {(r[0], r[1]): r for r in P.tops}
    sides = {(s[0], s[1]): s for s in P.sides}
    for R in (R1, R2):
        for p in R["old_parts"]:
            (rects if p[0] == "T" else sides).pop((p[1], p[2]), None)
        for p in R["new_parts"]:
            k, i, j, w, d, a, b, crag = p[:8]
            if k == "T":
                rects[(i, j)] = (i, j, w, d, a, P.mat[i][j], crag)
            else:
                sides[(i, j)] = (i, j, w, d, a, b, crag)
    return dict(X=X, P=P, top=top, rects=list(rects.values()), sides=sides, ye=R1["ye"], banks=R1["banks"],
                exc=R1["exc"])


def compute():
    S = json.load(open(SURVEY, encoding="utf-8"))
    C = current_state()
    P, top = C["P"], C["top"]
    cols = S["cols"]
    xs = [c[0] for c in cols]; zs = [c[1] for c in cols]
    i0, j0 = E.cell_of(min(xs) - 60, min(zs) - 60)
    i1, j1 = E.cell_of(max(xs) + 60, max(zs) + 60)
    grid = defaultdict(list)
    for k, c in enumerate(cols):
        grid[(int(c[0] // 32), int(c[1] // 32))].append(k)

    def nearest_col(x, z, lim):
        best = None
        for a in range(int(x // 32) - 2, int(x // 32) + 3):
            for b in range(int(z // 32) - 2, int(z // 32) + 3):
                for k in grid.get((a, b), ()):
                    d = col_dist(cols[k], x, z)
                    if d <= lim and (best is None or d < best[0]):
                        best = (d, k)
        return best

    new = lambda i, j: 0 <= i < N and 0 <= j < N and top[i][j] is not None and not P.keep[i][j]
    # channels = the water courses (cut and water Lines: the gorge and the west creek) with their banks; the NE gap is a
    # dry cut Rect the road runs through, regraded like any ground
    L = G.E.load()
    beds, banks = G.channel_mask(dict(L, Heights=[h for h in L["Heights"] if "Line" in h]))
    C["banks"] = banks
    corridor, under, skipped = {}, set(), defaultdict(list)
    for i in range(max(0, i0), min(N, i1 + 1)):
        for j in range(max(0, j0), min(N, j1 + 1)):
            if not new(i, j):
                continue
            x, z = E.cell_center(i, j)
            b = nearest_col(x, z, MARGIN + 2 * math.sqrt(2) + 0.01)  # centre within MARGIN of the footprint, cell-wise
            if not b or b[0] > MARGIN + 1e-6:
                continue
            if b[0] < 1e-6:
                under.add((i, j))
            if P.crag[i][j]:
                skipped["crag"].append((i, j))
                continue
            if P.kind[i][j] is not None and b[0] > 1e-6:
                skipped["route"].append((i, j))  # an expansion route beside the road (the rails) keeps its ground
                continue
            if (i, j) in beds or (i, j) in C["banks"]:
                skipped["channel"].append((i, j))
                continue
            corridor[(i, j)] = cols[b[1]][5]  # the nearest column's underside (y 6 throughout)
    newtop = [row[:] for row in top]
    for (i, j), y in corridor.items():
        newtop[i][j] = y
    # blend
    cgrid = defaultdict(list)
    for c in corridor:
        cgrid[(c[0] // 8, c[1] // 8)].append(c)
    blend = {}
    for i in range(max(0, i0), min(N, i1 + 1)):
        for j in range(max(0, j0), min(N, j1 + 1)):
            if not new(i, j) or (i, j) in corridor or P.crag[i][j] or (i, j) in beds or (i, j) in C["banks"]                     or P.kind[i][j] is not None:
                continue
            best = None
            for a in range(i // 8 - 2, i // 8 + 3):
                for b in range(j // 8 - 2, j // 8 + 3):
                    for c in cgrid.get((a, b), ()):
                        d = CELL * math.hypot(c[0] - i, c[1] - j)
                        if d <= BLEND_MAX and (best is None or d < best[0]):
                            best = (d, c)
            if best:
                d, c = best
                cur = top[i][j]
                L = min(BLEND_MAX, max(BLEND, STEEP * abs(corridor[c] - cur)))  # a bigger change blends further
                if d > L:
                    continue
                y = round(cur + (corridor[c] - cur) * (1 - G.smooth(d / L)))
                blend[(i, j)] = y
                newtop[i][j] = y
    # ramp: no step over 1 stud between a regraded cell and its neighbours outside the corridor (except crag, channel
    # and Ye cells, which stay as they are): clamp each neighbour into [y - 1, y + 1], nearest its current top, and go on
    from collections import deque
    free = lambda c: new(*c) and c not in corridor and not P.crag[c[0]][c[1]] and c not in beds and c not in C["banks"]         and P.kind[c[0]][c[1]] is None
    q = deque(c for c in list(corridor) + list(blend))
    ramped = set()
    while q:
        c = q.popleft()
        y = newtop[c[0]][c[1]]
        for a, b in G.NB4:
            o = (c[0] + a, c[1] + b)
            if not free(o):
                continue
            v = newtop[o[0]][o[1]]
            w = min(max(v, y - 1), y + 1)
            if w != v:
                newtop[o[0]][o[1]] = w
                ramped.add(o)
                q.append(o)
    for c in ramped:
        blend.setdefault(c, newtop[c[0]][c[1]])
    # beside an expansion route that keeps its ground (the north road's ribbon at the road's mouth), a cell not under
    # a road column stays within 1 stud of it
    for c in list(corridor) + list(blend):
        if c in under:
            continue
        for a, b in G.NB4:
            o = (c[0] + a, c[1] + b)
            if new(*o) and P.kind[o[0]][o[1]] is not None and o not in corridor and o not in blend:
                y, r = newtop[c[0]][c[1]], top[o[0]][o[1]]
                newtop[c[0]][c[1]] = min(max(y, r - 1), r + 1)
    changed = {(i, j) for (i, j) in list(corridor) + list(blend) if newtop[i][j] != top[i][j]}
    old_parts, new_parts = G.rebuild(P, C["ye"], newtop, changed, C["rects"], C["sides"])
    delta = {c: newtop[c[0]][c[1]] - top[c[0]][c[1]] for c in changed}
    # walls at the blend's outer edge: a step over 1 stud between a changed cell and an unchanged neighbour that
    # was not there before
    walls = []
    for (i, j) in changed:
        for a, b in G.NB4:
            o = (i + a, j + b)
            if o in changed or o in corridor or not new(*o):
                continue
            if abs(newtop[i][j] - top[o[0]][o[1]]) > 1 and abs(top[i][j] - top[o[0]][o[1]]) <= 1:
                why = "crag" if P.crag[o[0]][o[1]] else ("channel" if o in beds or o in C["banks"] else
                                                         ("route" if P.kind[o[0]][o[1]] else ""))
                walls.append((E.cell_center(i, j), newtop[i][j], E.cell_center(*o), top[o[0]][o[1]], why))
    return dict(S=S, C=C, P=P, top=top, newtop=newtop, corridor=corridor, under=under, blend=blend, changed=changed,
                delta=delta, old_parts=old_parts, new_parts=new_parts, skipped=skipped, walls=walls)


def stats(R):
    from collections import Counter
    ds = Counter(R["delta"].values())
    print(f"columns {len(R['S']['cols'])}; corridor cells {len(R['corridor'])} ({len(R['under'])} under a column), "
          f"blend cells {len(R['blend'])}; changed {len(R['changed'])}; height changes {sorted(ds.items())}")
    print(f"skipped in the corridor: { {k: len(v) for k, v in R['skipped'].items()} } "
          f"{ {k: sorted({(round(E.cell_center(*c)[0], -1), round(E.cell_center(*c)[1], -1)) for c in v})[:6] for k, v in R['skipped'].items()} }")
    print(f"parts replaced {len(R['old_parts'])}, built {len(R['new_parts'])} (net {len(R['new_parts']) - len(R['old_parts'])})")
    print(f"new walls over 1 stud at the blend's edge: {len(R['walls'])} {R['walls'][:6]}")
    unders = Counter(c[5] for c in R["S"]["cols"])
    print(f"column undersides: {sorted(unders.items())}")


def write_lua(R, out, mode):
    assert mode in ("apply", "undo", "check", "test"), mode
    src = open(TEMPLATE, encoding="utf-8").read()
    d = {
        "OLD": json.dumps(R["old_parts"], separators=(",", ":")),
        "NEW": json.dumps(R["new_parts"], separators=(",", ":")),
        "DELTA": json.dumps(sorted([i, j, v] for (i, j), v in R["delta"].items()), separators=(",", ":")),
        "COLS": json.dumps([[c[0], c[1], c[2], c[3], c[4], c[5]] for c in R["S"]["cols"]], separators=(",", ":")),
        "EXPECT": json.dumps(sorted([i, j, R["newtop"][i][j]] for (i, j) in R["changed"]), separators=(",", ":")),
        "ROUTES": json.dumps({r["Id"]: r["Line"] for r in G.E.load()["Routes"] if r["Kind"] != "ledge"}, separators=(",", ":")),
    }
    src = src.replace("--@@MODE@@", f'local MODE = "{mode}"')
    for k, v in d.items():
        assert "]==]" not in v
        src = src.replace(f"--@@{k}@@", f"local {k}_JSON = [==[{v}]==]")
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write(src)
    print(f"wrote {out} ({len(src)} chars, MODE {mode})")


if __name__ == "__main__":
    cmd = sys.argv[1:2]
    if cmd == ["measure"]:
        measure()
    elif cmd == ["stats"]:
        stats(compute())
    elif cmd == ["lua"] and len(sys.argv) == 4:
        write_lua(compute(), sys.argv[2], sys.argv[3])
    else:
        print(__doc__)
        sys.exit(2)

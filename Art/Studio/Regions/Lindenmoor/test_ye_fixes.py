"""Pure-Python checks of the Studio fixes Ye carries on top of the Lindenmoor kit (final review of the import, 2026-10-24).

python -I Art/Studio/Regions/Lindenmoor/test_ye_fixes.py

1. The name swap is pinned (review M5). Ye's compass has north at +Z, so the kit's east/west words read mirrored there.
   east_west_names.lua swaps them in Ye after the import. Every player-facing attribute value in the kit
   (layout.json and import/chunk_*.lua) that carries an east/west word must be one east_west_names.lua swaps.
   Otherwise a re-import brings back a name like "East Lookout" or "Northeast Gap" that the script doesn't know.
2. The generated fix scripts match their templates (review I2). regrade_seam.lua, seam_pits.lua and road_cut.lua are
   the template with the MODE line and the plan's data lines filled in. They must not drift apart, because the
   committed outputs can't be regenerated (the generators re-survey the current ground).
3. The rollback guards are in place (review I2): restore.lua refuses on every fix flag, gorge_fix undo refuses on the
   seam pits, bed and road cut, regrade_seam undo refuses on the gorge fix, seam_pits undo on the road cut.
4. prep_ye.lua's undo refuses while the Foundry move is applied (Foundry Yard plan Task 8, Ruling 12): the FoundryMove
   guard is planUndo()'s first statement, before any journal step or change.
5. retire_ye.lua (Foundry Yard plan Task 9, Ruling 38): apply journals the RenseiBackups and backup folders it makes
   before it parents them; undo destroys BrannocNotice only when it carries FoundryMoveAdd; test mode runs undo in a
   pcall; check has the NoticePost, board-faces-minus-Z and no-metal_*-inspect conditions.
"""
import glob, json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
FAILS = []


def check(name, ok, detail=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else f": {detail}"))
    if not ok:
        FAILS.append(name)


def read(*parts):
    with open(os.path.join(HERE, *parts), encoding="utf-8") as f:
        return f.read().replace("\r\n", "\n")


# ---------------------------------------------------------------- 1. east/west names
EW = re.compile(r"(east|west)", re.I)  # also inside "Northeast", "south-east", "western"


def ew_targets(src):
    """east_west_names.lua's TARGETS: [(Attr, Old, New)]."""
    body = src[src.index("local TARGETS = {"):]
    body = body[:body.index("\n}\n")]
    return re.findall(r'Attr = "(\w+)", Old = "([^"]+)", New = "([^"]+)"', body)


def attr_dicts(value):
    """Every attribute dict (a JSON object in a string, as the export's field 15) found anywhere in value."""
    if isinstance(value, str):
        s = value.strip()
        if s.startswith("{"):
            try:
                d = json.loads(s)
            except ValueError:
                return
            if isinstance(d, dict):
                yield d
    elif isinstance(value, list):
        for v in value:
            yield from attr_dicts(v)
    elif isinstance(value, dict):
        for v in value.values():
            yield from attr_dicts(v)


def kit_attrs():
    """(file, attribute, value) for every string attribute in the kit's layout.json and import chunks."""
    sources = [("layout.json", json.loads(read("layout.json")))]
    for path in sorted(glob.glob(os.path.join(HERE, "import", "chunk_*.lua"))):
        text = read("import", os.path.basename(path))
        for blob in re.findall(r"\[(=+)\[(.*?)\]\1\]", text, re.S):
            try:
                sources.append((os.path.basename(path), json.loads(blob[1])))
            except ValueError:
                pass
    for name, data in sources:
        for d in attr_dicts(data):
            for k, v in d.items():
                if isinstance(v, str):
                    yield name, k, v


def uncovered(targets, found):
    """The kit's east/west attribute values that no target swaps."""
    return [(f, k, v) for f, k, v in found if not any(a == k and old in v for a, old, _new in targets)]


def test_names():
    targets = ew_targets(read("east_west_names.lua"))
    check("east_west_names.lua has its targets", len(targets) >= 2, targets)
    found = [(f, k, v) for f, k, v in kit_attrs() if EW.search(v)]
    check("the kit has east/west names to swap (the scan sees the attributes)", len(found) >= 2, found)
    for f, k, v in found:
        check(f"{f}: {k} {v!r} is swapped by east_west_names.lua", not uncovered(targets, [(f, k, v)]),
              "add it to east_west_names.lua's TARGETS (and Rensei.Regions / the tests) or rename it in the kit")
    kit_values = {(k, v) for _f, k, v in found}
    for a, old, new in targets:
        if a != "AreaName":
            continue  # (the village descriptions aren't in the kit; they are reworded, not mirrored word for word)
        check(f"the kit still names {old!r} (so east_west_names.lua finds it after a re-import)",
              any(k == a and old in v for k, v in kit_values))
        check(f"{old!r} -> {new!r} swaps one east/west word for the other",
              old.replace("east", "@").replace("East", "@") == new.replace("west", "@").replace("West", "@"))
    # self-tests: the check fails when the script drops a name, or the kit gains one
    for a, old, _n in targets:
        if a == "AreaName":
            fewer = [t for t in targets if t[1] != old]
            check(f"self-test: without {old!r} in TARGETS the kit's name is caught", bool(uncovered(fewer, found)))
    check("self-test: a new east/west name in the kit is caught",
          bool(uncovered(targets, [("layout.json", "AreaName", "Southeast Fold")])))


# ---------------------------------------------------------------- 2. generated scripts == template + data
def render(tmpl, generated):
    """The template with the generated file's MODE line and data lines put back into the slots."""
    mode = re.search(r'^local MODE = .*$', generated, re.M)
    out = tmpl.replace("--@@MODE@@", mode.group(0) if mode else "--@@MODE@@")
    for k in re.findall(r"^--@@(\w+)@@$", tmpl, re.M):
        if k == "MODE":
            continue
        line = re.search(rf"^local {k}_JSON = \[==\[.*?\]==\]$", generated, re.M | re.S)
        if line:
            out = out.replace(f"--@@{k}@@", line.group(0))
    return out


def test_generated():
    for name in ("regrade_seam", "seam_pits", "road_cut"):
        tmpl, gen = read(name + ".lua.tmpl"), read(name + ".lua")
        check(f"{name}.lua = {name}.lua.tmpl + its MODE and data", render(tmpl, gen) == gen,
              "the committed output and the template differ outside the data lines")


# ---------------------------------------------------------------- 3. the guards
FLAGS = ["LindenmoorSeamRegrade", "LindenmoorSeamPits", "LindenmoorGorgeFix", "LindenmoorGorgeBed",
         "LindenmoorRoadCut", "LindenmoorShelters", "LindenmoorEastWest"]


def guard_list(src, start):
    """The attribute names in the {"..."} list right after the text start."""
    i = src.index(start)
    j = src.index("}", i)
    return re.findall(r'"(\w+)"', src[i:j])


def test_guards():
    region = json.loads(read(os.path.join("..", "..", "..", "Regions", "Lindenmoor", "layout.json")))
    check("the region file lists every fix flag in RestoreRefuseFlags", region.get("RestoreRefuseFlags") == FLAGS,
          region.get("RestoreRefuseFlags"))
    res = read("import", "restore.lua")
    m = re.search(r"local REFUSE_FLAGS = HS:JSONDecode\(\[==\[(.*?)\]==\]\)", res)
    check("restore.lua refuses on every fix flag", bool(m) and json.loads(m.group(1)) == FLAGS, m and m.group(1))
    check("restore.lua's guard comes before its first change",
          bool(m) and res.index("if #StillSet > 0 then") < res.index("TryBeginRecording"))
    gorge = read("gorge_fix.lua")
    undo = gorge[gorge.index('elseif MODE == "undo" then'):]
    check("gorge_fix undo refuses on the road cut, the bed and the seam pits",
          sorted(guard_list(undo, "for _, a in ipairs({")) == sorted(["LindenmoorRoadCut", "LindenmoorGorgeBed", "LindenmoorSeamPits"])
          and undo.index("#later > 0") < undo.index("beginRecording()"))
    for name in ("regrade_seam.lua.tmpl", "regrade_seam.lua"):
        src = read(name)
        body = src[src.index("local function undo(strict)"):]
        check(f"{name}: undo refuses on the road cut, the seam pits and the gorge fix",
              sorted(guard_list(body, "for _, a in ipairs({")) == sorted(["LindenmoorRoadCut", "LindenmoorSeamPits", "LindenmoorGorgeFix"]))
    for name in ("seam_pits.lua.tmpl", "seam_pits.lua"):
        src = read(name)
        body = src[src.index("local function undo(strict)"):]
        check(f"{name}: undo refuses on the road cut", 'EX:GetAttribute("LindenmoorRoadCut") then error' in body.split("local n =")[0])
    for name in ("road_cut.lua.tmpl", "road_cut.lua"):
        head = read(name).split("--   \"check\"")[0]
        check(f"{name}: the header no longer says every other undo refuses", "the other steps' undos refuse" not in head
              and "seam_pits.lua, gorge_fix.lua and" in head)


# ---------------------------------------------------------------- 4. prep_ye.lua's Foundry-move guard
# (Foundry Yard plan Task 8, Ruling 12.) prep_ye.lua's undo puts Ye's trainers and spawns back by LindenmoorPrepFrom and
# returns every backup child; with Brannoc, the forge rooms and the Ward spawn moved into the Foundry move's backup by
# Art/Studio/Regions/Foundry/forge/retire_ye.lua, an undo then would act on a half-moved world. So planUndo() refuses
# while World.Map has FoundryMove, before it plans anything, and so before doUndo's first journal step or move.
# (bundle_prep.py builds the undo bundle from prep_ye.lua itself: there is no template.)
GUARD = re.compile(r'^\s*if Map:GetAttribute\("FoundryMove"\) ~= nil then return nil, [^\n]*retire_ye\.lua[^\n]* end\s*$', re.M)
# a line that writes the journal or changes the place: did(...), a Parent / attribute / pivot write, a Destroy
CHANGE = re.compile(r'\bdid\(|table\.insert\(journal|\.Parent\s*=|:SetAttribute\(|setPivot\(|:PivotTo\(|\.CFrame\s*=|:Destroy\(')


def function_body(src, header):
    """The lines of the top-level Lua function opened by header, up to its closing top-level "end"."""
    lines = src.split("\n")
    start = next((i for i, l in enumerate(lines) if l.strip() == header), None)
    if start is None:
        return None, None
    end = next((i for i in range(start + 1, len(lines)) if lines[i] == "end"), None)
    return start, lines[start + 1:end] if end else None


def guard_problems(src):
    """Why src's planUndo() lacks a working FoundryMove guard (empty when it has one)."""
    start, body = function_body(src, "local function planUndo()")
    if body is None:
        return ["no top-level local function planUndo()"]
    g = next((i for i, l in enumerate(body) if GUARD.match(l)), None)
    if g is None:
        return ["no FoundryMove guard (if Map:GetAttribute(\"FoundryMove\") ~= nil then return nil, ... retire_ye.lua ... end) in planUndo()"]
    out = []
    first_change = next((i for i, l in enumerate(body) if CHANGE.search(l.split("--")[0])), None)
    if first_change is not None and first_change < g:
        out.append(f"planUndo() line {first_change + 1} ({body[first_change].strip()}) changes something before the guard")
    first_stmt = next((i for i, l in enumerate(body) if l.strip() and not l.strip().startswith("--")), None)
    if first_stmt != g:
        out.append(f"the guard is not planUndo()'s first statement (line {g + 1}; first is {first_stmt + 1 if first_stmt is not None else '-'})")
    run = src[src.index("-- ================================================================ run"):] if "-- ================================================================ run" in src else ""
    if not re.search(r"W, why = planUndo\(\)", run) or run.index("planUndo()") > run.index("doUndo, W"):
        out.append("the run section does not call planUndo() (and refuse on nil) before doUndo")
    return out


def test_prep_guard():
    src = read("prep_ye.lua")
    problems = guard_problems(src)
    check("prep_ye.lua: planUndo() refuses while World.Map has FoundryMove, before any journal step", not problems, problems)
    # self-tests: the check fails without the guard, and with a change put in front of it
    start, body = function_body(src, "local function planUndo()")
    if body and any(GUARD.match(l) for l in body):
        no_guard = "\n".join(l for l in src.split("\n") if not GUARD.match(l))
        check("self-test: prep_ye.lua without the guard is caught", bool(guard_problems(no_guard)))
        moved = src.replace("local function planUndo()\n", "local function planUndo()\n\tdid(function() end)\n", 1)
        check("self-test: a journal step before the guard is caught", bool(guard_problems(moved)))


# ---------------------------------------------------------------- 5. retire_ye.lua (Ruling 38)
RETIRE = os.path.join(HERE, "..", "Foundry", "forge", "retire_ye.lua")


def retire_problems(src):
    """Why src (retire_ye.lua) misses a Ruling 38 rule (empty when it has them all)."""
    out = []
    lines = src.split("\n")
    for var, parent in (("RB", "SS"), ("BK", "RB")):
        j = next((i for i, l in enumerate(lines) if re.match(r"^\s*did\(function\(\) %s:Destroy\(\) end\)" % var, l)), None)
        p = next((i for i, l in enumerate(lines) if re.match(r"^\s*%s\.Parent = %s\s*$" % (var, parent), l)), None)
        if j is None or p is None:
            out.append(f"apply: no journal entry / Parent line for {var}")
        elif j > p:
            out.append(f"apply: {var}.Parent = {parent} (line {p + 1}) comes before its journal entry (line {j + 1})")
    _, body = function_body(src, "local function undo()")
    text = "\n".join(body or [])
    if not re.search(r'local Notice = Map:FindFirstChild\("BrannocNotice"\)\s*\n(?:\s*--[^\n]*\n)?\s*if Notice and Notice:GetAttribute\(ADD\) == true then', text):
        out.append("undo: BrannocNotice is not destroyed only when it carries FoundryMoveAdd (ADD)")
    test_part = src[src.index('elseif MODE == "test" then'):] if 'elseif MODE == "test" then' in src else ""
    if not re.search(r"=\s*pcall\(undo\)", test_part):
        out.append("test mode: undo() is not run in a pcall")
    _, cbody = function_body(src, "local function checks()")
    ctext = "\n".join(cbody or [])
    for what, rx in (("NoticePost", r'FindFirstChild\("NoticePost"\)'),
                     ("the board faces -Z", r"Dot\(Vector3\.new\(0, 0, -1\)\) <= 0\.99"),
                     ("no metal_* inspect", r'string\.sub\(Id, 1, 6\) == "metal_"')):
        if not re.search(rx, ctext):
            out.append("check: no condition for " + what)
    return out


def test_retire():
    with open(RETIRE, encoding="utf-8") as f:
        src = f.read().replace("\r\n", "\n")
    problems = retire_problems(src)
    check("retire_ye.lua: Ruling 38's journal order, notice guard, test pcall and check conditions", not problems, problems)
    # self-tests: each rule is caught when broken
    good = "\t\t\tdid(function() RB:Destroy() end) -- (Ruling 38: the journal entry before the Parent)\n\t\t\tRB.Parent = SS"
    swapped = src.replace(good, "\t\t\tRB.Parent = SS\n\t\t\tdid(function() RB:Destroy() end)", 1)
    check("self-test: RenseiBackups parented before its journal entry is caught", swapped != src and bool(retire_problems(swapped)))
    unguarded = src.replace("if Notice and Notice:GetAttribute(ADD) == true then", "if Notice then", 1)
    check("self-test: an unguarded notice destroy is caught", unguarded != src and bool(retire_problems(unguarded)))
    bare = src.replace("pcall(undo)", "undo()", 1)
    check("self-test: a bare undo() in test mode is caught", bare != src and bool(retire_problems(bare)))
    nopost = src.replace('FindFirstChild("NoticePost")', 'FindFirstChild("Post")', 1)
    check("self-test: a check without the NoticePost condition is caught", nopost != src and bool(retire_problems(nopost)))


if __name__ == "__main__":
    test_names()
    test_generated()
    test_guards()
    test_prep_guard()
    test_retire()
    print(f"{'FAIL' if FAILS else 'PASS'}: {len(FAILS)} failed")
    sys.exit(1 if FAILS else 0)

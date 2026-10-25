"""Keeps a place's Studio scripts equal to the repo (Foundry data plan, Task 1).

python -I Art/Studio/Regions/Foundry/data/sync.py --place ye|foundry --check
    One line per pair of that place: "<Label> SAME", "<Label> DIFFER <studio hash> vs <repo hash>" or
    "<Label> MISSING" ("<Label> MISSING (no repo file)" when the Repo file is absent; Studio is still asked), then
    "SAME n / DIFFER n / MISSING n". Exits 1 when DIFFER or MISSING > 0. Read-only.
python -I Art/Studio/Regions/Foundry/data/sync.py --place ye|foundry --only <label>[,<label>...] --run
python -I Art/Studio/Regions/Foundry/data/sync.py --place ye|foundry --all --run
    Generates and runs one bundle per pair (Studio, Edit), then re-runs --check for those labels.
python -I Art/Studio/Regions/Foundry/data/sync.py --place ye|foundry --only ...|--all --out <dir>
    Generates the bundles into <dir> only (run one by hand: rbxc.py luau "placeId: <id>" Edit @<bundle>).
--backup Pre-<Name>_YYYY-MM-DD (gun rework Task 1) names the backup folder a --run/--out bundle clones into; it must
    match BACKUP_NAME (Pre-, letters/digits, _, a YYYY-MM-DD date) or the tool exits 2 ("bad --backup name").
    Without it, BACKUP (every existing call produces the same bytes).

Every mode considers only the pairs whose Places include --place (Ruling 7); --only refuses a label that isn't one.
Pairs live in sync_manifest.json: {"Pairs": [{"Label", "Studio", "Class", "Repo", "Places", "Create"}, ...]}.
"Studio" is a "/"-separated path from a service name, the last element the script. "Create": true lets a bundle
create a missing script of Class in its (existing) parent; a created script carries the attribute FoundryDataAdd = true
(Task 2, Ruling 20c). A repo file with a lone CR left after CRLF normalisation is refused at generation (20b); --check
echoes Studio's raw answer when no line of it parses (20d); an empty --only is refused (20e).

What a bundle does: refuses while Play runs or while this place's ServerStorage PlayLock attribute is set (a Foundry
--run also first asks Ye's PlayLock and runs nothing unless it is nil: 20a); resolves PATH (creates the script when missing and CREATE, else
refuses); returns "same <LABEL>" when the normalised hash already equals WANT; otherwise clones the current script
once into ServerStorage.RenseiBackups[BACKUP][LABEL] (tags stripped into RegionKitTags; a created script gets no
backup), sets Source and returns "synced <LABEL>" or "MISMATCH <LABEL> <hash>". Re-running one is safe, so a
"Target is not reachable" answer is retried.
"""
import argparse, datetime, json, os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", ".."))
MANIFEST = os.path.join(HERE, "sync_manifest.json")
RBXC = os.path.join(REPO, "Art", "Tools", "rbxc.py")
TOOL = "Art/Studio/Regions/Foundry/data/sync.py"
PLACES = {"ye": 106992859583940, "foundry": 109591196441030}
BACKUP = "Pre-FoundryData_2026-10-24"
BACKUP_NAME = re.compile(r"^Pre-[A-Za-z0-9]+_[0-9]{4}-[0-9]{2}-[0-9]{2}$")  # --backup NAME (the swim plan's check)
# [0-9], not \d: in a str pattern \d also takes non-ASCII digits such as a fullwidth "２" (gun rework Task 3)
CLASSES = ("ModuleScript", "Script", "LocalScript")
RETRIES = 3

NORMHASH_LUA = """local function NormHash(S)
	S = S:gsub("\\r\\n", "\\n")
	local H1, H2 = 0, 0
	for I = 1, #S do
		local B = string.byte(S, I)
		H1 = (H1 * 31 + B) % 1000000007
		H2 = (H2 * 131 + B) % 998244353
	end
	return #S .. ":" .. H1 .. ":" .. H2
end
"""

# Resolves PATH from its service; sets Node (the parent) and Hits (children named like the script). Shared by the
# sync bundle and the check bundle so both read a path the same way.
RESOLVE_LUA = """local function Resolve(Path)
	local Bits = string.split(Path, "/")
	local Ok, Node = pcall(function() return game:GetService(Bits[1]) end)
	if not Ok or not Node then return nil, "no service " .. Bits[1] end
	for I = 2, #Bits - 1 do
		local Kids = {}
		for _, C in Node:GetChildren() do
			if C.Name == Bits[I] then table.insert(Kids, C) end
		end
		if #Kids ~= 1 then return nil, #Kids .. " children named " .. Bits[I] .. " under " .. Node:GetFullName() end
		Node = Kids[1]
	end
	local Hits = {}
	for _, C in Node:GetChildren() do
		if C.Name == Bits[#Bits] then table.insert(Hits, C) end
	end
	return Node, Hits, Bits[#Bits]
end
"""

SYNC_BODY_LUA = """
if game:GetService("RunService"):IsRunning() then return "REFUSED " .. LABEL .. ": Play is running" end
local Lock = game:GetService("ServerStorage"):GetAttribute("PlayLock")
if Lock ~= nil then return "REFUSED " .. LABEL .. ": PlayLock is " .. tostring(Lock) end
local Node, Hits, Name = Resolve(PATH)
if not Node then return "REFUSED " .. LABEL .. ": " .. Hits end
if #Hits > 1 then return "REFUSED " .. LABEL .. ": " .. #Hits .. " scripts named " .. Name end
local S = Hits[1]
if S and S.ClassName ~= CLASS then return "REFUSED " .. LABEL .. ": is a " .. S.ClassName .. ", want " .. CLASS end
if not S then
	if not CREATE then return "REFUSED " .. LABEL .. ": missing and Create is false" end
	S = Instance.new(CLASS)
	S.Name = Name
	S.Source = SRC
	S:SetAttribute("FoundryDataAdd", true)
	S.Parent = Node
	local H = NormHash(S.Source)
	return H == WANT and ("synced " .. LABEL) or ("MISMATCH " .. LABEL .. " " .. H)
end
if NormHash(S.Source) == WANT then return "same " .. LABEL end
local SS = game:GetService("ServerStorage")
local Root = SS:FindFirstChild("RenseiBackups")
if not Root then
	Root = Instance.new("Folder")
	Root.Name = "RenseiBackups"
	Root.Parent = SS
end
local Dir = Root:FindFirstChild(BACKUP)
if not Dir then
	Dir = Instance.new("Folder")
	Dir.Name = BACKUP
	Dir.Parent = Root
end
if not Dir:FindFirstChild(LABEL) then
	local Copy = S:Clone()
	if not Copy then return "REFUSED " .. LABEL .. ": the script can't be cloned (Archivable false)" end
	local CS = game:GetService("CollectionService")
	local HS = game:GetService("HttpService")
	local All = Copy:GetDescendants()
	table.insert(All, Copy)
	for _, D in All do
		local Tags = CS:GetTags(D)
		if #Tags > 0 then
			D:SetAttribute("RegionKitTags", HS:JSONEncode(Tags))
			for _, T in Tags do CS:RemoveTag(D, T) end
		end
	end
	Copy.Name = LABEL
	Copy.Parent = Dir
end
S.Source = SRC
local H = NormHash(S.Source)
return H == WANT and ("synced " .. LABEL) or ("MISMATCH " .. LABEL .. " " .. H)
"""


def norm_hash(data: bytes) -> str:
    data = data.replace(b"\r\n", b"\n")
    h1 = h2 = 0
    for b in data:
        h1 = (h1 * 31 + b) % 1000000007
        h2 = (h2 * 131 + b) % 998244353
    return f"{len(data)}:{h1}:{h2}"


def bracket_level(text: str) -> int:
    """The smallest n such that the long string [=n[ text ]=n] first closes at its own end."""
    n = 0
    while True:
        close = "]" + "=" * n + "]"
        if (text + close).find(close) == len(text):
            return n
        n += 1


def lua_str(s: str) -> str:
    return json.dumps(s)  # a JSON string of plain path/label text is a valid Luau string


def load_manifest(path=MANIFEST):
    with open(path, encoding="utf-8") as f:
        m = json.load(f)
    labels = [p["Label"] for p in m["Pairs"]]
    dup = sorted({l for l in labels if labels.count(l) > 1})
    if dup:
        raise SystemExit("manifest: duplicate labels " + ", ".join(dup))
    for p in m["Pairs"]:
        if p["Class"] not in CLASSES:
            raise SystemExit(f"manifest: {p['Label']} has Class {p['Class']}")
        if not set(p["Places"]) <= set(PLACES):
            raise SystemExit(f"manifest: {p['Label']} has Places {p['Places']}")
    return m


def pairs_for(manifest, place):
    return [p for p in manifest["Pairs"] if place in p["Places"]]


def repo_bytes(pair):
    with open(os.path.join(REPO, pair["Repo"]), "rb") as f:
        return f.read()


def repo_text(pair):
    text = repo_bytes(pair).decode("utf-8").replace("\r\n", "\n")
    if "\r" in text:
        # Luau reads a lone CR as a line break, so Studio's Source would not hash like the repo file (Ruling 20b)
        raise ValueError(f"{pair['Repo']}: a lone CR (not part of a CRLF) at character {text.index(chr(13))}; "
                         "fix the file's line endings")
    return text


def bundle_text(pair, date=None, backup=BACKUP):
    date = date or datetime.date.today().isoformat()
    src = repo_text(pair)
    want = norm_hash(src.encode("utf-8"))
    eq = "=" * bracket_level(src)
    return (f"-- generated by {TOOL} from {pair['Repo']} ({date}): do not edit by hand.\n"
            + NORMHASH_LUA + RESOLVE_LUA
            + f"local PATH, CLASS, LABEL, CREATE, BACKUP, WANT = {lua_str(pair['Studio'])}, {lua_str(pair['Class'])}, "
              f"{lua_str(pair['Label'])}, {'true' if pair['Create'] else 'false'}, {lua_str(backup)}, {lua_str(want)}\n"
            + f"local SRC = [{eq}[\n" + src + f"]{eq}]\n"
            + SYNC_BODY_LUA)


def write_bundle(pair, out_dir, date=None, backup=BACKUP):
    path = os.path.join(out_dir, "sync_" + pair["Label"].replace(".", "_") + ".lua")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(bundle_text(pair, date, backup=backup))
    return path


def check_bundle_text(pairs, date=None):
    date = date or datetime.date.today().isoformat()
    rows = "\n".join(f"\t{{{lua_str(p['Label'])}, {lua_str(p['Studio'])}, {lua_str(p['Class'])}}}," for p in pairs)
    return (f"-- generated by {TOOL} from sync_manifest.json ({date}): do not edit by hand. Read-only.\n"
            + NORMHASH_LUA + RESOLVE_LUA
            + "local PAIRS = {\n" + rows + "\n}\n"
            + """local Out = {}
for _, P in PAIRS do
	local Node, Hits = Resolve(P[2])
	local R
	if not Node or #Hits == 0 then
		R = "MISSING"
	elseif #Hits > 1 then
		R = "DUP" .. #Hits
	elseif Hits[1].ClassName ~= P[3] then
		R = "CLASS:" .. Hits[1].ClassName
	else
		R = NormHash(Hits[1].Source)
	end
	table.insert(Out, P[1] .. "\\t" .. R)
end
return table.concat(Out, "\\n")
""")


def rbxc_runner(place_id, bundle_path):
    r = subprocess.run([sys.executable, "-I", RBXC, "luau", f"placeId: {place_id}", "Edit", "@" + bundle_path],
                       capture_output=True, text=True, encoding="utf-8")
    return (r.stdout or "") + (r.stderr or "")


def run(runner, place_id, bundle_path):
    """Runs a bundle; every bundle is idempotent, so an unreachable answer is retried."""
    out = ""
    for _ in range(RETRIES):
        out = runner(place_id, bundle_path).replace("\r\n", "\n").strip()
        if "not reachable" not in out:
            return out
    return out


YE_LOCK_LUA = (f"-- generated by {TOOL} (Ruling 20a): reads Ye's PlayLock before a Foundry sync. Read-only.\n"
               'return "PlayLock=" .. tostring(game:GetService("ServerStorage"):GetAttribute("PlayLock"))\n')


def ye_lock_free(out_dir, runner):
    """A Foundry sync runs only while Ye's PlayLock is nil (a Play session locks both places). Returns (ok, answer)."""
    path = os.path.join(out_dir, "lock_ye.lua")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(YE_LOCK_LUA)
    ans = run(runner, PLACES["ye"], path)
    return ans == "PlayLock=nil", ans


def do_check(pairs, place, out_dir, runner):
    path = os.path.join(out_dir, f"check_{place}.lua")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(check_bundle_text(pairs))
    got = {}
    raw = run(runner, PLACES[place], path)
    for line in raw.split("\n"):
        if "\t" in line:
            k, v = line.split("\t", 1)
            got[k.strip()] = v.strip()
    if not got:  # (Ruling 20d) say what Studio did answer
        print("no line of Studio's answer parsed; raw rbxc output:\n" + (raw or "(empty)"))
    n = {"SAME": 0, "DIFFER": 0, "MISSING": 0}
    for p in pairs:
        have = got.get(p["Label"])
        if not os.path.isfile(os.path.join(REPO, p["Repo"])):  # (gun rework Task 1) report it, don't crash
            print(f"{p['Label']} MISSING (no repo file)")
            n["MISSING"] += 1
            continue
        want = norm_hash(repo_bytes(p))
        if have is None:
            print(f"{p['Label']} MISSING (no answer from Studio)")
            n["MISSING"] += 1
        elif have == "MISSING":
            print(f"{p['Label']} MISSING")
            n["MISSING"] += 1
        elif have == want:
            print(f"{p['Label']} SAME")
            n["SAME"] += 1
        else:
            print(f"{p['Label']} DIFFER {have} vs {want}")
            n["DIFFER"] += 1
    print(f"SAME {n['SAME']} / DIFFER {n['DIFFER']} / MISSING {n['MISSING']}")
    return 1 if n["DIFFER"] or n["MISSING"] else 0


def main(argv=None, runner=None):
    ap = argparse.ArgumentParser(description="Sync a place's Studio scripts with the repo.")
    ap.add_argument("--place", required=True, choices=sorted(PLACES))
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--check", action="store_true")
    g.add_argument("--only")
    g.add_argument("--all", action="store_true")
    ap.add_argument("--run", action="store_true")
    ap.add_argument("--out")
    ap.add_argument("--manifest", default=MANIFEST)
    ap.add_argument("--backup", default=BACKUP)
    a = ap.parse_args(argv)
    if not BACKUP_NAME.fullmatch(a.backup):
        print(f"bad --backup name: {a.backup!r} (want Pre-<Name>_YYYY-MM-DD)")
        return 2
    runner = runner or rbxc_runner
    pairs = pairs_for(load_manifest(a.manifest), a.place)
    out_dir = a.out or tempfile.mkdtemp(prefix="rensei_sync_")
    os.makedirs(out_dir, exist_ok=True)

    if a.check:
        if a.run:
            print("--check takes no --run")
            return 2
        return do_check(pairs, a.place, out_dir, runner)

    if a.only is not None:
        want = [l.strip() for l in a.only.split(",") if l.strip()]
        if not want:  # (Ruling 20e)
            print("--only names no label")
            return 2
        known = {p["Label"]: p for p in pairs}
        bad = [l for l in want if l not in known]
        if bad:
            print(f"not a {a.place} pair: " + ", ".join(bad))
            return 2
        pairs = [known[l] for l in want]
    if not a.run and not a.out:
        print("give --run, or --out <dir> to generate only")
        return 2

    try:
        paths = [(p, write_bundle(p, out_dir, backup=a.backup)) for p in pairs]
    except ValueError as e:
        print(f"REFUSED: {e}")
        return 2
    if a.run and a.place == "foundry":  # (Ruling 20a) Foundry's own lock is read by each bundle; Ye's is read here
        ok, ans = ye_lock_free(out_dir, runner)
        if not ok:
            print(f"REFUSED: Ye's PlayLock must be nil before a Foundry sync (Ye answered: {ans or '(no answer)'})")
            return 2
    if not a.run:
        for p, path in paths:
            print(f"{p['Label']}: {path}")
        return 0
    bad = 0
    for p, path in paths:
        res = run(runner, PLACES[a.place], path)
        first = res.split("\n")[0] if res else "(no answer)"
        ok = first in (f"synced {p['Label']}", f"same {p['Label']}")
        bad += 0 if ok else 1
        print(f"{p['Label']}: {first if ok else res}")
    print("-- check --")
    code = do_check(pairs, a.place, out_dir, runner)
    return 1 if bad or code else 0


if __name__ == "__main__":
    sys.exit(main())

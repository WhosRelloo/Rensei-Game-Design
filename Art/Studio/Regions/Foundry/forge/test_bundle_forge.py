"""Tests for bundle_forge.py (Foundry data plan, Task 7).

python -I Art/Studio/Regions/Foundry/forge/test_bundle_forge.py
    1. the kit round-trips into the bundle: the KIT literal in a generated bundle parses back (a small parser for the
       Lua subset the bundler writes) to forge_kit.json; a changed kit does not;
    2. the bundle's MODE line is the one asked for, for each of the five modes, and nothing else differs;
    3. the committed build_forge.lua equals a fresh bundle with MODE "plan" (and a bundle of a changed kit doesn't);
    4. the header is the generated-file header; no placeholder is left; an unknown MODE is refused; the CLI writes the
       asked MODE to <out> and leaves build_forge.lua a plan bundle; the CLI refuses another MODE onto build_forge.lua;
    5. the kit has what the brief lists: 20 SilentForge pieces, 3 SilentForge Models (Interactables a Folder,
       WorkshopRecord's Model and Iron Alchemy Models), every container on a piece's path a Models entry, the
       TrialMarker, Brannoc's 9 attributes (no LindenmoorPrepFrom), the Ward; attributes string/number/boolean only.
Prints PASS n / FAIL n; exits 1 on any failure.
"""
import copy, json, os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bundle_forge as B  # noqa: E402

PASSES, FAILS = [0], []


def check(name, ok, detail=""):
    if ok:
        PASSES[0] += 1
    else:
        FAILS.append(name)
        print("FAIL %s: %s" % (name, detail))


# ------------------------------------------------------------------ a parser for the bundler's Lua subset
class P:
    def __init__(self, s, i=0):
        self.s, self.i = s, i

    def ws(self):
        while self.i < len(self.s) and self.s[self.i] in " \t\r\n":
            self.i += 1

    def peek(self):
        self.ws()
        return self.s[self.i] if self.i < len(self.s) else ""

    def eat(self, ch):
        self.ws()
        if self.s[self.i] != ch:
            raise ValueError("expected %r at %d, got %r" % (ch, self.i, self.s[self.i:self.i + 20]))
        self.i += 1

    def string(self):
        self.eat('"')
        out = []
        while True:
            ch = self.s[self.i]
            if ch == '"':
                self.i += 1
                return "".join(out)
            if ch == "\\":
                nx = self.s[self.i + 1]
                if nx.isdigit():
                    m = re.match(r"\d{1,3}", self.s[self.i + 1:])
                    out.append(chr(int(m.group(0))))
                    self.i += 1 + len(m.group(0))
                    continue
                out.append({"n": "\n", "r": "\r", "t": "\t", "\\": "\\", '"': '"'}[nx])
                self.i += 2
                continue
            out.append(ch)
            self.i += 1

    def value(self):
        ch = self.peek()
        if ch == "{":
            return self.table()
        if ch == '"':
            return self.string()
        m = re.match(r"(true|false|nil)\b", self.s[self.i:])
        if m:
            self.i += len(m.group(0))
            return {"true": True, "false": False, "nil": None}[m.group(1)]
        m = re.match(r"-?(\d+\.?\d*(e[-+]?\d+)?|inf|nan)", self.s[self.i:])
        if m:
            t = m.group(0)
            self.i += len(t)
            return float(t) if any(c in t for c in ".e") else int(t)
        raise ValueError("no value at %d: %r" % (self.i, self.s[self.i:self.i + 20]))

    def table(self):
        self.eat("{")
        items, keyed = [], None
        while self.peek() != "}":
            key = None
            if self.peek() == "[":
                self.eat("[")
                key = self.string()
                self.eat("]")
                self.eat("=")
            else:
                m = re.match(r"([A-Za-z_][A-Za-z0-9_]*)\s*=(?!=)", self.s[self.i:])
                if m and m.group(1) not in ("true", "false", "nil"):
                    key = m.group(1)
                    self.i += len(m.group(0))
            v = self.value()
            if keyed is None:
                keyed = key is not None
            if keyed != (key is not None):
                raise ValueError("a mixed table at %d" % self.i)
            items.append((key, v))
            if self.peek() == ",":
                self.eat(",")
        self.eat("}")
        if not items:
            return EMPTY
        return dict(items) if keyed else [v for _, v in items]


EMPTY = ("EMPTY",)


def canon(v):
    """{} and [] both read back as an empty table"""
    if isinstance(v, dict):
        return EMPTY if not v else {k: canon(x) for k, x in v.items()}
    if isinstance(v, list):
        return EMPTY if not v else [canon(x) for x in v]
    return v


def kit_in(bundle):
    """the KIT literal in a bundle, parsed"""
    at = bundle.index("local KIT = ") + len("local KIT = ")
    p = P(bundle, at)
    v = p.value()
    return v, bundle[p.i:p.i + 1]


def read(path):
    if not os.path.exists(path):
        return ""
    with open(path, encoding="utf-8", newline="") as f:
        return f.read().replace("\r\n", "\n")  # (a Windows checkout may turn LF into CRLF: compare normalised)


def mode_lines(text):
    return re.findall(r'^local MODE = "([a-z]+)"', text, re.M)


def main():
    kit = B.load_kit()
    plan = B.generate("plan")

    # 1. round trip
    got, _ = kit_in(plan)
    check("kit round-trips into the bundle", canon(got) == canon(kit), "the parsed KIT differs from forge_kit.json")
    bad = copy.deepcopy(kit)
    bad["Pieces"][0]["CFrame"][0] += 0.001
    check("control: a changed kit does not round-trip", canon(kit_in(B.generate("plan", kit=bad))[0]) != canon(kit))
    odd = copy.deepcopy(kit)
    odd["Pieces"][0]["Attributes"]["Odd \"key\"\\"] = "line\nbreak\t\"q\"\x01"
    check("strings and odd keys round-trip", canon(kit_in(B.generate("plan", kit=odd))[0]) == canon(odd))
    check("numbers keep every digit", all(
        isinstance(x, (int, float)) and x == y
        for p, q in zip(got["Pieces"], kit["Pieces"]) for x, y in zip(p["CFrame"], q["CFrame"])))

    # 2. the MODE line
    strip = lambda t: re.sub(r'^local MODE = "[a-z]+"', "local MODE = ?", t, flags=re.M)
    for mode in B.MODES:
        body = B.generate(mode)
        check("MODE line is %s" % mode, mode_lines(body) == [mode], mode_lines(body))
        check("only the MODE line differs (%s)" % mode, strip(body) == strip(plan))
    try:
        B.generate("delete")
        check("an unknown MODE is refused", False, "generated")
    except ValueError:
        check("an unknown MODE is refused", True)

    # 3. the committed file
    committed = read(B.OUT_PATH)
    check("build_forge.lua equals a fresh plan bundle", committed == plan, "regenerate with bundle_forge.py")
    check("control: a bundle of a changed kit differs from build_forge.lua", B.generate("plan", kit=bad) != committed)
    check("build_forge.lua is MODE plan", mode_lines(committed) == ["plan"], mode_lines(committed))

    # 4. header, placeholders, the CLI
    first = plan.split("\n")[1]
    check("the generated header", first.startswith("-- generated by Art/Studio/Regions/Foundry/forge/bundle_forge.py from forge_kit.json and build_forge.lua.tmpl (")
          and first.endswith("): do not edit by hand."), first)
    check("no placeholder left", B.HEADER_MARK not in plan and B.KIT_MARK not in plan)
    check("no CR in the bundle", "\r" not in plan)
    with tempfile.TemporaryDirectory() as d:
        out = os.path.join(d, "bf_check.lua")
        r = subprocess.run([sys.executable, "-I", os.path.join(HERE, "bundle_forge.py"), out, "check"], capture_output=True, text=True)
        check("CLI exits 0", r.returncode == 0, r.stdout + r.stderr)
        body = read(out)
        check("CLI wrote MODE check", mode_lines(body) == ["check"], mode_lines(body))
        check("CLI left build_forge.lua a plan bundle", read(B.OUT_PATH) == plan)
        r = subprocess.run([sys.executable, "-I", os.path.join(HERE, "bundle_forge.py"), out, "nope"], capture_output=True, text=True)
        check("CLI refuses an unknown MODE", r.returncode != 0 and "REFUSED" in r.stdout, r.stdout)
    r = subprocess.run([sys.executable, "-I", os.path.join(HERE, "bundle_forge.py"), B.OUT_PATH, "apply"], capture_output=True, text=True)
    check("CLI refuses another MODE onto build_forge.lua", r.returncode != 0 and "REFUSED" in r.stdout, r.stdout)
    check("build_forge.lua still a plan bundle after the refusal", read(B.OUT_PATH) == plan)

    # 5. the kit's contents
    sf = [p for p in kit["Pieces"] if p["Group"] == "SilentForge"]
    check("20 SilentForge pieces", len(sf) == 20, len(sf))
    sfm = {m["Path"]: m["Class"] for m in kit["Models"] if m["Group"] == "SilentForge"}
    check("3 SilentForge Models", sfm == {"Interactables": "Folder", "Interactables/WorkshopRecord/Model": "Model", "Iron Alchemy": "Model"}, sfm)
    check("every Models entry has a Folder / Model Class", all(m.get("Class") in ("Folder", "Model") for m in kit["Models"]))
    paths = {(p["Group"], p["Path"]) for p in kit["Pieces"]}
    cont = {(m["Group"], m["Path"]) for m in kit["Models"]}
    missing = []
    for p in kit["Pieces"]:
        bits = p["Path"].split("/")
        for n in range(1, len(bits)):
            pre = (p["Group"], "/".join(bits[:n]))
            if pre not in paths and pre not in cont:
                missing.append(pre)
    check("every container on a piece's path is a Models entry", not missing, missing)
    names = sorted(p["Path"].split("/")[-1] for p in sf)
    want = sorted(["WorkshopRecord", "MeshPart", "MeshPart", "MeshPart", "MaterialBench", "RepairedGear", "SampleRack",
                   "DriveShaft", "Sample1", "Sample2", "Sample3", "Sample4", "Sample5", "Paper", "BookProp", "BookProp",
                   "Machine", "Desk", "Anvil", "Silent ForgeArea"])
    check("the 20 pieces are the brief's", names == want, names)
    shell = {"WestA", "WestB", "EastA", "SouthA", "SouthB", "North", "Floor", "Furnace", "FurnaceMouth"}
    check("no shell part exported", not any(p["Path"] in shell for p in sf))
    tm = [p for p in kit["Pieces"] if p["Group"] == "ForgeFloor"]
    check("the TrialMarker only from ForgeFloor", [p["Path"] for p in tm] == ["TrialMarker"] and tm[0]["Attributes"] == {"TrialId": "metal_experiment"}, tm)
    ba = kit["Brannoc"]["Attributes"]
    check("Brannoc's 9 attributes", len(ba) == 9 and "LindenmoorPrepFrom" not in ba and ba.get("DialogueId") == "trainer_metal", sorted(ba))
    check("Brannoc's Humanoid fields", set(kit["Brannoc"]["Humanoid"]) == {"DisplayName", "DisplayDistanceType", "NameDisplayDistance", "HealthDisplayDistance"})
    check("Brannoc's props", sorted(p["Path"] for p in kit["Pieces"] if p["Group"] == "Brannoc") == ["Metal Alchemy/Paper", "ScrollStand"])
    check("the Ward", kit["Ward"]["Attributes"].get("EnemyType") == "WardAlchemist" and kit["Ward"]["Size"] == [2, 1, 2], kit["Ward"])
    allattrs = [a for p in kit["Pieces"] + [kit["Ward"]] for a in p["Attributes"].items()] + list(ba.items())
    check("attributes are string / number / boolean, no LindenmoorPrepFrom",
          all(isinstance(v, (str, int, float, bool)) and k != "LindenmoorPrepFrom" for k, v in allattrs))
    check("every piece has 12 CFrame numbers", all(len(p["CFrame"]) == 12 for p in kit["Pieces"] + [kit["Ward"]]))

    print("PASS %d / FAIL %d" % (PASSES[0], len(FAILS)))
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())

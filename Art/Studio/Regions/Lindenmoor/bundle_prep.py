"""Bundles Task 5's Ye prep for Studio's execute_luau (one file; pads.json inlined as a literal).

python -I Art/Studio/Regions/Lindenmoor/bundle_prep.py prep <out.lua> apply|undo
    prep_ye.lua with pads.json inlined and MODE set (the mode is required). Run it in Ye, Edit:
    python -I Art/Tools/rbxc.py luau "placeId: 106992859583940" Edit @<out.lua>
python -I Art/Studio/Regions/Lindenmoor/bundle_prep.py test <out.lua>
    test_prep.lua, with pads.json inlined and prep_ye.lua wrapped as `local function Prep(MODE_ARG)`. With no
    prep_ye.lua yet, Prep is nil (the test fails: Task 5 step 1).
Both refuse if pads.json is stale: every file in its "Inputs" must still hash as recorded (Ruling 18; CRLF counts
as LF). The bundle also sets PADS_HASH, the first 8 hex of pads.json's sha256, which apply echoes in its summary.
"""
import hashlib, json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))
MODE_LINE = re.compile(r'^local MODE = .*$', re.M)
PADS_LINE = re.compile(r'^local PADS_JSON = .*$', re.M)


def read(name):
    with open(os.path.join(HERE, name), encoding="utf-8") as f:
        return f.read()


def sha(data):
    return hashlib.sha256(data.replace(b"\r\n", b"\n")).hexdigest()


def check_fresh(text):
    """Refuse (SystemExit) unless every pads.json input still hashes as recorded."""
    inputs = json.loads(text).get("Inputs")
    if not inputs:
        raise SystemExit("pads.json has no Inputs: re-run python -I Art/Studio/Regions/Lindenmoor/make_pads.py")
    stale = []
    for rel, want in sorted(inputs.items()):
        path = os.path.join(REPO, rel)
        if not os.path.exists(path):
            stale.append(f"{rel} (missing)")
            continue
        with open(path, "rb") as f:
            if sha(f.read()) != want:
                stale.append(rel)
    if stale:
        raise SystemExit("pads.json is stale; changed since make_pads.py ran: " + ", ".join(stale) +
                         "\nRe-run: python -I Art/Studio/Regions/Lindenmoor/make_pads.py (and lift_survey.lua first if Ye's items changed)")


def pads_literal():
    text = read("pads.json")
    check_fresh(text)
    if "]==]" in text:
        raise SystemExit("pads.json contains ]==]; pick a longer bracket level")
    short = sha(text.encode("utf-8"))[:8]
    return ("local PADS_JSON = [==[\n" + text + "]==] -- pads.json, inlined by bundle_prep.py\n"
            f'local PADS_HASH = "{short}" -- first 8 hex of pads.json\'s sha256')


def sub_once(rx, repl, src, what):
    out, n = rx.subn(lambda _m: repl, src)
    if n != 1:
        raise SystemExit(f"prep_ye.lua: expected one {what} line, found {n}")
    return out


def main(argv):
    if len(argv) < 2 or argv[0] not in ("prep", "test") or (argv[0] == "prep" and (len(argv) != 3 or argv[2] not in ("apply", "undo"))):
        raise SystemExit(__doc__)
    kind, out = argv[0], argv[1]
    have_prep = os.path.exists(os.path.join(HERE, "prep_ye.lua"))
    if kind == "prep":
        src = sub_once(PADS_LINE, pads_literal(), read("prep_ye.lua"), "PADS_JSON")
        lua = sub_once(MODE_LINE, f'local MODE = "{argv[2]}" -- set by bundle_prep.py', src, "MODE")
    else:
        lua = pads_literal() + "\n"
        if have_prep:
            body = sub_once(PADS_LINE, "-- PADS_JSON, PADS_HASH: the bundle's upvalues", read("prep_ye.lua"), "PADS_JSON")
            body = sub_once(MODE_LINE, "local MODE = MODE_ARG -- set by the test", body, "MODE")
            lua += "local function Prep(MODE_ARG)\n" + body + "\nend\n"
        else:
            lua += "local Prep = nil -- prep_ye.lua does not exist yet\n"
        lua += read("test_prep.lua")
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write(lua)
    print(f"wrote {out} ({len(lua)} chars)")


if __name__ == "__main__":
    main(sys.argv[1:])

"""Bundles the gorge fix (Ruling 23) for Studio's execute_luau.

python -I Art/Studio/Regions/Lindenmoor/bundle_gorge_fix.py fix <out.lua> plan|apply|undo|check
    gorge_fix.lua with MODE set. Run it in Ye, Edit:
    python -I Art/Tools/rbxc.py luau "placeId: 106992859583940" Edit @<out.lua>
python -I Art/Studio/Regions/Lindenmoor/bundle_gorge_fix.py test <out.lua>
    test_gorge_fix.lua with gorge_fix.lua wrapped as `local function GorgeFix(MODE_ARG)`: snapshot, apply, check,
    undo, compare. Leaves Ye as it found it (or says what differs).
"""
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
MODE_LINE = re.compile(r'^local MODE = .*$', re.M)
SLOT = "--[[GORGE_FIX]]"


def read(name):
    with open(os.path.join(HERE, name), encoding="utf-8") as f:
        return f.read()


def with_mode(src, line):
    out, n = MODE_LINE.subn(lambda _m: line, src)
    if n != 1:
        raise SystemExit(f"gorge_fix.lua: expected one MODE line, found {n}")
    return out


def main(argv):
    if len(argv) < 3 or argv[1] not in ("fix", "test"):
        raise SystemExit(__doc__)
    kind, out = argv[1], argv[2]
    src = read("gorge_fix.lua")
    if kind == "fix":
        if len(argv) != 4 or argv[3] not in ("plan", "apply", "undo", "check"):
            raise SystemExit("fix needs a mode: plan, apply, undo or check")
        text = with_mode(src, f'local MODE = "{argv[3]}" -- set by bundle_gorge_fix.py')
    else:
        test = read("test_gorge_fix.lua")
        if test.count(SLOT) != 1:
            raise SystemExit(f"test_gorge_fix.lua: expected one {SLOT}")
        body = with_mode(src, "local MODE = MODE_ARG")
        text = test.replace(SLOT, "local function GorgeFix(MODE_ARG)\n" + body + "\nend")
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print(f"wrote {out} ({len(text)} chars)")


if __name__ == "__main__":
    main(sys.argv)

"""Bundles the Task 12 region setup for Studio's execute_luau (one file, no ModuleScripts installed in the place).

python -I Art/Studio/Regions/bundle_setup.py setup <out.lua> [--region R] [--map-child C] [--origin x,y,z]
    travel_pieces.lua wrapped as `local TravelPieces = (function() ... end)()`, then setup.lua. Run the result in the
    region's place, Edit: python -I Art/Tools/rbxc.py luau "placeId: <id>" Edit @<out.lua>
    --region / --map-child / --origin set setup.lua's REGION, MAP_CHILD and ORIGIN in the bundle only (the committed
    setup.lua keeps its defaults, so a Lindenmoor run never leaves Lindenmoor values committed). ORIGIN is (0, 0, 0)
    for every region whose marker attributes are in world studs, Lindenmoor's expansion included (see setup.lua).
python -I Art/Studio/Regions/bundle_setup.py contract <out.lua> <root> [<place>]
    Test_SetupContract.lua wrapped as `local Check = ...`, then `return Check(<root>, <place>)`. <root> and <place> are
    Luau expressions, e.g. workspace.World.Map.LindenmoorExpansion, or game.ServerStorage.RegionSetupRoot
    game.ServerStorage.RegionSetupPlace for a test run. With no <place>, a root under workspace is checked place-wide."""
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
NAME = re.compile(r"[A-Za-z][A-Za-z0-9_]*")
# the lines of setup.lua the options replace (each must appear exactly once)
LINES = {"--region": re.compile(r'^local REGION = .*$', re.M), "--map-child": re.compile(r'^local MAP_CHILD = .*$', re.M),
         "--origin": re.compile(r'^local ORIGIN = .*$', re.M)}


def read(name):
    with open(os.path.join(HERE, name), encoding="utf-8") as f:
        return f.read()


def wrap(local, name):
    return f"local {local} = (function()\n{read(name)}\nend)()\n"


def options(argv):
    """{flag: value} for --region / --map-child / --origin (each checked)."""
    out = {}
    i = 0
    while i < len(argv):
        flag = argv[i]
        if flag not in LINES or i + 1 >= len(argv):
            raise SystemExit(f"unknown option or missing value: {flag}\n\n{__doc__}")
        v = argv[i + 1]
        if flag in ("--region", "--map-child") and not NAME.fullmatch(v):
            raise SystemExit(f"{flag} {v!r}: letters, digits and _ only, starting with a letter")
        if flag == "--origin":
            try:
                n = [float(t) for t in v.split(",")]
            except ValueError:
                n = []
            if len(n) != 3:
                raise SystemExit(f"--origin {v!r}: three numbers x,y,z")
            v = n
        out[flag] = v
        i += 2
    return out


def setup_source(opts):
    src = read("setup.lua")
    for flag, v in opts.items():
        if flag == "--region":
            line = f'local REGION = "{v}" -- set by bundle_setup.py --region'
        elif flag == "--map-child":
            line = f'local MAP_CHILD = "{v}" -- set by bundle_setup.py --map-child'
        else:
            line = "local ORIGIN = Vector3.new(%s) -- set by bundle_setup.py --origin" % ", ".join(repr(c) for c in v)
        src, n = LINES[flag].subn(line, src)
        if n != 1:
            raise SystemExit(f"setup.lua: expected one line for {flag}, found {n}")
    return src


def main(argv):
    if len(argv) < 2 or argv[0] not in ("setup", "contract") or (argv[0] == "contract" and len(argv) < 3):
        raise SystemExit(__doc__)
    mode, out = argv[0], argv[1]
    if mode == "setup":
        opts = options(argv[2:])
        lua = wrap("TravelPieces", "travel_pieces.lua") + setup_source(opts)
    else:
        place = argv[3] if len(argv) > 3 else "nil"
        lua = wrap("Check", "Test_SetupContract.lua") + f"return Check({argv[2]}, {place})\n"
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write(lua)
    print(f"{mode} bundle: {out} ({len(lua.splitlines())} lines)")


if __name__ == "__main__":
    main(sys.argv[1:])

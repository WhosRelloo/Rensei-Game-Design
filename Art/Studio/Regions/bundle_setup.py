"""Bundles the Task 12 region setup for Studio's execute_luau (one file, no ModuleScripts installed in the place).

python -I Art/Studio/Regions/bundle_setup.py setup <out.lua>
    travel_pieces.lua wrapped as `local TravelPieces = (function() ... end)()`, then setup.lua. Run the result in the
    region's place, Edit: python -I Art/Tools/rbxc.py luau "placeId: <id>" Edit @<out.lua>
python -I Art/Studio/Regions/bundle_setup.py contract <out.lua> <root> [<place>]
    Test_SetupContract.lua wrapped as `local Check = ...`, then `return Check(<root>, <place>)`. <root> and <place> are
    Luau expressions, e.g. workspace.World.Map.LindenmoorExpansion, or game.ServerStorage.RegionSetupRoot
    game.ServerStorage.RegionSetupPlace for a test run. With no <place>, a root under workspace is checked place-wide."""
import os, sys

HERE = os.path.dirname(os.path.abspath(__file__))


def read(name):
    with open(os.path.join(HERE, name), encoding="utf-8") as f:
        return f.read()


def wrap(local, name):
    return f"local {local} = (function()\n{read(name)}\nend)()\n"


def main(argv):
    if len(argv) < 2 or argv[0] not in ("setup", "contract") or (argv[0] == "contract" and len(argv) < 3):
        raise SystemExit(__doc__)
    mode, out = argv[0], argv[1]
    if mode == "setup":
        lua = wrap("TravelPieces", "travel_pieces.lua") + read("setup.lua")
    else:
        place = argv[3] if len(argv) > 3 else "nil"
        lua = wrap("Check", "Test_SetupContract.lua") + f"return Check({argv[2]}, {place})\n"
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write(lua)
    print(f"{mode} bundle: {out} ({len(lua.splitlines())} lines)")


if __name__ == "__main__":
    main(sys.argv[1:])

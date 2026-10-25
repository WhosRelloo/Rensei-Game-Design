"""Region kit for Roblox Studio: a thin wrapper around Art/Studio/Lindenmoor/studio_kit.py (Region Foundation Task 11).

python -I Art/Studio/Regions/kit.py <Region> [--date YYYY-MM-DD] [--keep Name1,Name2] [--map-child Name] [--place <id>]
                                    [--no-collide A,B] [--no-collide-kinds K1,K2] [--offset x,y,z --out <dir>]
  reads  Art/Studio/Regions/<Region>/layout.json   (export.py's output: Region_<Region> exported with origin (0,0,0))
         Art/Regions/<Region>/materials.json        (optional: else studio_kit's built-in table)
         Art/Regions/<Region>/water.json            (optional: terrain water boxes)
         Art/Regions/<Region>/layout.json           (the region file: PlaceId, Budget and the optional
                                                     KeepMapChildren, MapChild, NoCollide, NoCollideKinds and
                                                     RestoreRefuseFlags)
  writes Art/Studio/Regions/<Region>/import/chunk_NN.lua, expected.json, finish.lua, restore.lua and unstrip.lua
         (from finish_region.lua.tmpl, restore_region.lua.tmpl and unstrip_region.lua.tmpl).
  --date  the generation date written into the headers (default today; the backup is named by the RUN date).
  --keep  World.Map children the real run leaves in place, added to the region file's KeepMapChildren. (A region
          file's top-level "Keep", as in Lindenmoor's, is something else and is ignored here.)
  --map-child  the World.Map child the import builds (default: the region file's MapChild, else the Region name);
          Task 12's setup.lua must read the same MapChild.
  --place overrides the region file's PlaceId (a test run of a region in another place).
  --no-collide / --no-collide-kinds  the walk-through lists (part-name substrings / prefab kinds), replacing the
          region file's NoCollide / NoCollideKinds. Default: the region file's, else Lindenmoor's own lists
          (studio_kit.NO_COLLIDE / NO_COLLIDE_KINDS) for Lindenmoor, else ("Glass", "Glow") and no kinds. "-" = none.
  --out   TEST RUNS: the folder the scripts go to (its import/), so the committed Art/Studio/Regions/<Region>/import
          stays as it is.
  --offset  TEST RUNS ONLY (needs --out): added to the export's origin, moving the whole import (parts and water)
          by x, y, z studs; the Foundry smoke test (smoke.py) uses it to put the Testbed clear of Foundry's own map.

In Studio (Edit, the region's place): run the chunks in order (they build ServerStorage.RegionStaging), then set ONE
attribute on RegionStaging and run finish.lua:
  DryRun = true          checks the staging against expected.json, then removes it again (and any MaterialVariant
                         the chunks made): the place is left as it was.
  Confirm = "<Region>"   the real run (only in the region's place): backs up and swaps World.Map (see the template).
With neither, finish.lua refuses and changes nothing. restore.lua undoes a real run from its backup.

RestoreRefuseFlags (optional, final review I2 of the Lindenmoor import): attribute names that later Studio fixes set on
World.Map.<MapChild> when they change the import in place, each with its own undo. restore.lua then refuses while any of
them is set. Without the key, restore.lua is generated exactly as before."""
import datetime, json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, "Art", "Studio", "Lindenmoor"))
import studio_kit  # noqa: E402
from studio_kit import lua_str, long_json  # noqa: E402

TEMPLATES = {"finish.lua": os.path.join(HERE, "finish_region.lua.tmpl"),
             "restore.lua": os.path.join(HERE, "restore_region.lua.tmpl"),
             "unstrip.lua": os.path.join(HERE, "unstrip_region.lua.tmpl")}
# The walk-through lists are per region (final review I4, 2026-10-24): part-name substrings (NoCollide) and prefab
# kinds (NoCollideKinds) that lose collision. no_collide() picks them: --no-collide / --no-collide-kinds, else the
# region file's NoCollide / NoCollideKinds, else by region:
#   * a region_builder region (the rail-town kit): only see-through or lit fittings that sit flush on something solid,
#     window panes (*Glass: house/warehouse windows on the wall face, the crane's CabGlass) and lamp heads (*Glow:
#     street-lamp and court lamp glows, the underworks DimGlow in its cage). Kerbs, steps, crates, goods, walls and
#     roofs keep their collision.
#   * Lindenmoor (its expansion reuses the village's pieces): the village's own lists, studio_kit.NO_COLLIDE and
#     NO_COLLIDE_KINDS (Tuft, Crop, Vine, Lantern, ... and the EdgeStone kind: walk-through verge stones and plants).
NO_COLLIDE = ("Glass", "Glow")
NO_COLLIDE_KINDS = ()
REGION_NO_COLLIDE = {"Lindenmoor": (studio_kit.NO_COLLIDE, studio_kit.NO_COLLIDE_KINDS)}
NAME = re.compile(r"[A-Za-z][A-Za-z0-9_]*")


def load(path, default=None):
    if not os.path.exists(path):
        return default
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def arg(argv, flag):
    if flag not in argv:
        return None
    i = argv.index(flag)
    if i + 1 >= len(argv):
        raise SystemExit(f"{flag} needs a value")
    return argv[i + 1]


def keep_list(spec, extra):
    """The region file's KeepMapChildren plus --keep (comma-separated, trimmed, empty ones skipped), in order, no
    repeats. The top-level "Keep" (Lindenmoor's area objects) is not read."""
    keep = spec.get("KeepMapChildren") or []
    if not (isinstance(keep, list) and all(isinstance(k, str) and k.strip() for k in keep)):
        raise SystemExit(f"KeepMapChildren must be a list of non-empty names, got {keep!r}")
    keep = [k.strip() for k in keep] + studio_kit.split_tags(extra or "")
    return list(dict.fromkeys(keep))


def map_child(spec, region, override, keep):
    """The World.Map child the import builds: --map-child, else the region file's MapChild, else the Region name.
    It must be a plain name and may not be kept."""
    child = override or spec.get("MapChild") or region
    if not (isinstance(child, str) and NAME.fullmatch(child)):
        raise SystemExit(f"MapChild {child!r}: letters, digits and _ only, starting with a letter")
    if child in keep:
        raise SystemExit(f"KeepMapChildren may not name the MapChild ({child}): the import builds World.Map.{child}")
    return child


def _names(value, what):
    if not (isinstance(value, (list, tuple)) and value and all(isinstance(v, str) and v.strip() for v in value)):
        raise SystemExit(f"{what} must be a list of non-empty names, got {value!r}")
    return tuple(dict.fromkeys(v.strip() for v in value))


def no_collide(spec, region, names=None, kinds=None):
    """The walk-through lists (name substrings, prefab kinds) of a region run: --no-collide / --no-collide-kinds
    (comma-separated; "-" = none), else the region file's NoCollide / NoCollideKinds, else REGION_NO_COLLIDE's
    entry for the region (Lindenmoor's own lists), else (NO_COLLIDE, NO_COLLIDE_KINDS)."""
    base_names, base_kinds = REGION_NO_COLLIDE.get(region, (NO_COLLIDE, NO_COLLIDE_KINDS))
    out = []
    for flag, key, base in ((names, "NoCollide", base_names), (kinds, "NoCollideKinds", base_kinds)):
        if flag is not None:
            out.append(() if flag.strip() == "-" else _names(studio_kit.split_tags(flag), f"--{key}"))
        elif key in spec:
            out.append(_names(spec[key], key) if spec[key] != [] else ())
        else:
            out.append(tuple(base))
    return out[0], out[1]


# restore.lua's guard for a region file with RestoreRefuseFlags (filled into the template's {{REFUSE_FLAGS}} slot, at the
# start of a line, so a region without the key gets the template's text unchanged)
REFUSE_GUARD = """-- Later fixes made in place on World.Map.<MapChild> (the region file's RestoreRefuseFlags): each one marks it with
-- an attribute and has its own undo. restore.lua would carry them off half-undone, so it refuses while any is set.
local REFUSE_FLAGS = HS:JSONDecode([==[{flags}]==])
local StillSet = {{}}
for _, F in ipairs(REFUSE_FLAGS) do
	if Dest:GetAttribute(F) then table.insert(StillSet, F) end
end
if #StillSet > 0 then
	return "restore refused: World.Map." .. Dest.Name .. " still carries " .. table.concat(StillSet, ", ")
		.. " (undo those fixes first, in the Kit's rollback order); nothing changed"
end
"""


def refuse_guard(spec):
    """The restore.lua guard text for the region file's RestoreRefuseFlags ("" without the key)."""
    flags = spec.get("RestoreRefuseFlags")
    if flags is None:
        return ""
    names = _names(flags, "RestoreRefuseFlags")
    bad = [n for n in names if not NAME.fullmatch(n)]
    if bad:
        raise SystemExit(f"RestoreRefuseFlags: {bad!r} are not attribute names (letters, digits and _)")
    return REFUSE_GUARD.format(flags=long_json(list(names)))


def offset(text):
    """--offset x,y,z -> three numbers (None without the option)."""
    if text is None:
        return None
    try:
        v = [float(t) for t in text.split(",")]
    except ValueError:
        v = []
    if len(v) != 3:
        raise SystemExit(f"--offset {text!r}: three numbers x,y,z")
    return [int(c) if c == int(c) else c for c in v]


def fill_template(path, fill):
    with open(path, encoding="utf-8") as f:
        lua = f.read()
    for k, v in fill.items():
        lua = lua.replace(k, v)
    left = re.findall(r"\{\{[A-Z_]+\}\}", lua)
    assert not left, f"template slots left in {path}: {left}"
    return lua


def main(argv):
    if not argv or argv[0].startswith("-"):
        raise SystemExit(__doc__)
    region = argv[0]
    if not NAME.fullmatch(region):
        raise SystemExit(f"region {region!r}: letters, digits and _ only, starting with a letter")
    date = arg(argv, "--date") or datetime.date.today().isoformat()
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", date):
        raise SystemExit(f"--date {date!r}: YYYY-MM-DD")
    src = os.path.join(REPO, "Art", "Regions", region)
    folder = os.path.join(HERE, region)
    spec = load(os.path.join(src, "layout.json"))
    if spec is None:
        raise SystemExit(f"no region file {os.path.join(src, 'layout.json')}")
    if not os.path.exists(os.path.join(folder, "layout.json")):
        raise SystemExit(f"no export at {os.path.join(folder, 'layout.json')}: run export.py on Region_{region} first")
    place = arg(argv, "--place")
    place = int(place) if place is not None else int(spec.get("PlaceId") or 0)
    keep = keep_list(spec, arg(argv, "--keep"))
    child = map_child(spec, region, arg(argv, "--map-child"), keep)
    mats = load(os.path.join(src, "materials.json"))
    water = load(os.path.join(src, "water.json"), {"Boxes": []})
    for w in water.get("Boxes", []):
        nums = list(w["Rect"]) + [w["Top"], w["Bed"]]
        if not (all(isinstance(v, (int, float)) and not isinstance(v, bool) for v in nums) and len(w["Rect"]) == 4
                and w["Rect"][0] < w["Rect"][2] and w["Rect"][1] < w["Rect"][3] and w["Bed"] < w["Top"]):
            raise SystemExit(f"water.json: bad box {w!r}")
    names, kinds = no_collide(spec, region, arg(argv, "--no-collide"), arg(argv, "--no-collide-kinds"))
    shift = offset(arg(argv, "--offset"))
    out_dir = arg(argv, "--out")
    if shift is not None and out_dir is None:
        raise SystemExit("--offset needs --out (a test run must not overwrite the committed import scripts)")
    if out_dir is not None:  # a test run: a copy of the export (moved by --offset), and the scripts beside it
        lay = load(os.path.join(folder, "layout.json"))
        if shift is not None:
            lay["origin"] = [a + b for a, b in zip(lay["origin"], shift)]
        folder = os.path.abspath(out_dir)
        os.makedirs(folder, exist_ok=True)
        with open(os.path.join(folder, "layout.json"), "w", encoding="utf-8") as f:
            json.dump(lay, f, separators=(",", ":"))
    out = studio_kit.main(folder, region={"name": region, "materials": mats, "no_collide": names,
                                          "no_collide_kinds": kinds})
    exp = out["expected"]
    if spec.get("Budget") and exp["parts"] > spec["Budget"]:
        raise SystemExit(f"{exp['parts']} parts is over the region's Budget {spec['Budget']}: not importable")
    origin = out["origin"]
    if not all(isinstance(v, (int, float)) and not isinstance(v, bool) for v in origin):
        raise SystemExit(f"export origin {origin!r} is not three numbers")
    fill = {"{{REGION}}": lua_str(region), "{{REGION_TEXT}}": region, "{{PLACE_ID}}": str(place),
            "{{GENERATED}}": lua_str(date), "{{GENERATED_TEXT}}": date,
            "{{EXPECTED}}": long_json(exp, sort_keys=True), "{{WATER}}": long_json(water.get("Boxes", []), sort_keys=True),
            "{{KEEP}}": long_json(keep), "{{MAPCHILD}}": lua_str(child), "{{MAPCHILD_TEXT}}": child, "{{REFUSE_FLAGS}}": refuse_guard(spec), "{{ORIGIN}}": ", ".join(repr(float(v)) if isinstance(v, float) else str(v) for v in origin)}
    for name, tmpl in TEMPLATES.items():
        with open(os.path.join(folder, "import", name), "w", encoding="utf-8") as f:
            f.write(fill_template(tmpl, fill))
    print(f"finish/restore/unstrip.lua: region {region}, place {place}, generated {date}, Map.{child}, keep {keep}; tags {exp['tags']}; "
          f"variants {exp['variantParts']}; water boxes {len(water.get('Boxes', []))}; walk-through names {list(names)}, "
          f"kinds {list(kinds)}; markers {exp['helpers']}; origin {origin}" + (f" (moved by --offset {shift})" if shift else "")
          + (f"; written to {os.path.join(folder, 'import')}" if out_dir else ""))
    return out


if __name__ == "__main__":
    main(sys.argv[1:])

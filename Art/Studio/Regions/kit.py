"""Region kit for Roblox Studio: a thin wrapper around Art/Studio/Lindenmoor/studio_kit.py (Region Foundation Task 11).

python -I Art/Studio/Regions/kit.py <Region> [--date YYYY-MM-DD] [--keep Name1,Name2] [--place <placeId>]
  reads  Art/Studio/Regions/<Region>/layout.json   (export.py's output: Region_<Region> exported with origin (0,0,0))
         Art/Regions/<Region>/materials.json        (optional: else studio_kit's built-in table)
         Art/Regions/<Region>/water.json            (optional: terrain water boxes)
         Art/Regions/<Region>/layout.json           (the region file: PlaceId, Budget and the optional Keep)
  writes Art/Studio/Regions/<Region>/import/chunk_NN.lua, expected.json, finish.lua and restore.lua (from
         finish_region.lua.tmpl and restore_region.lua.tmpl).
  --date  the generation date written into the headers (default today; the backup is named by the RUN date).
  --keep  World.Map children the real run leaves in place, added to the region file's Keep.
  --place overrides the region file's PlaceId (a test run of a region in another place).

In Studio (Edit, the region's place): run the chunks in order (they build ServerStorage.RegionStaging), then set ONE
attribute on RegionStaging and run finish.lua:
  DryRun = true          checks the staging against expected.json, then removes it again (and any MaterialVariant
                         the chunks made): the place is left as it was.
  Confirm = "<Region>"   the real run (only in the region's place): backs up and swaps World.Map (see the template).
With neither, finish.lua refuses and changes nothing. restore.lua undoes a real run from its backup."""
import datetime, json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, "Art", "Studio", "Lindenmoor"))
import studio_kit  # noqa: E402
from studio_kit import lua_str, long_json  # noqa: E402

TEMPLATES = {"finish.lua": os.path.join(HERE, "finish_region.lua.tmpl"),
             "restore.lua": os.path.join(HERE, "restore_region.lua.tmpl")}
# Parts whose name contains one of these lose collision in a region run. Only see-through or lit fittings that sit
# flush on something solid: window panes (*Glass: house/warehouse windows on the wall face, the crane's CabGlass)
# and lamp heads (*Glow: street-lamp and court lamp glows, the underworks DimGlow in its cage). Kerbs, steps, crates,
# goods, walls and roofs keep their collision. (Lindenmoor's list, studio_kit.NO_COLLIDE, is for its own flush
# decoration and is not used here: it would make the rail-town Kerbs and market Goods walk-through.)
NO_COLLIDE = ("Glass", "Glow")
NO_COLLIDE_KINDS = ()
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
    """The region file's Keep plus --keep (comma-separated, trimmed, empty ones skipped), in order, no repeats."""
    keep = list(spec.get("Keep") or [])
    if not all(isinstance(k, str) and k.strip() for k in keep):
        raise SystemExit(f"Keep must be a list of non-empty names, got {keep!r}")
    keep = [k.strip() for k in keep] + studio_kit.split_tags(extra or "")
    return list(dict.fromkeys(keep))


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
    if region in keep:
        raise SystemExit(f"Keep may not name the region itself ({region}): the import builds World.Map.{region}")
    mats = load(os.path.join(src, "materials.json"))
    water = load(os.path.join(src, "water.json"), {"Boxes": []})
    for w in water.get("Boxes", []):
        nums = list(w["Rect"]) + [w["Top"], w["Bed"]]
        if not (all(isinstance(v, (int, float)) and not isinstance(v, bool) for v in nums) and len(w["Rect"]) == 4
                and w["Rect"][0] < w["Rect"][2] and w["Rect"][1] < w["Rect"][3] and w["Bed"] < w["Top"]):
            raise SystemExit(f"water.json: bad box {w!r}")
    out = studio_kit.main(folder, region={"name": region, "materials": mats, "no_collide": NO_COLLIDE,
                                          "no_collide_kinds": NO_COLLIDE_KINDS})
    exp = out["expected"]
    if spec.get("Budget") and exp["parts"] > spec["Budget"]:
        raise SystemExit(f"{exp['parts']} parts is over the region's Budget {spec['Budget']}: not importable")
    origin = out["origin"]
    if not all(isinstance(v, (int, float)) and not isinstance(v, bool) for v in origin):
        raise SystemExit(f"export origin {origin!r} is not three numbers")
    fill = {"{{REGION}}": lua_str(region), "{{REGION_TEXT}}": region, "{{PLACE_ID}}": str(place),
            "{{GENERATED}}": lua_str(date), "{{GENERATED_TEXT}}": date,
            "{{EXPECTED}}": long_json(exp, sort_keys=True), "{{WATER}}": long_json(water.get("Boxes", []), sort_keys=True),
            "{{KEEP}}": long_json(keep), "{{ORIGIN}}": ", ".join(repr(float(v)) if isinstance(v, float) else str(v) for v in origin)}
    for name, tmpl in TEMPLATES.items():
        with open(os.path.join(folder, "import", name), "w", encoding="utf-8") as f:
            f.write(fill_template(tmpl, fill))
    print(f"finish.lua + restore.lua: region {region}, place {place}, generated {date}, keep {keep}; tags {exp['tags']}; "
          f"variants {exp['variantParts']}; water boxes {len(water.get('Boxes', []))}")
    return out


if __name__ == "__main__":
    main(sys.argv[1:])

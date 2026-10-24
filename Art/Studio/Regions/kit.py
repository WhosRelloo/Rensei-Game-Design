"""Region kit for Roblox Studio: a thin wrapper around Art/Studio/Lindenmoor/studio_kit.py (Region Foundation Task 11).

python -I Art/Studio/Regions/kit.py <Region> [--date YYYY-MM-DD]
  reads  Art/Studio/Regions/<Region>/layout.json   (export.py's output: Region_<Region> exported with origin (0,0,0))
         Art/Regions/<Region>/materials.json        (optional: else studio_kit's built-in table)
         Art/Regions/<Region>/water.json            (optional: terrain water boxes)
         Art/Regions/<Region>/layout.json           (the region file: PlaceId and Budget)
  writes Art/Studio/Regions/<Region>/import/chunk_NN.lua, expected.json and finish.lua (from finish_region.lua.tmpl).

In Studio (Edit, the region's place): run the chunks in order (they build ServerStorage.RegionStaging), then
finish.lua. With RegionStaging:SetAttribute("DryRun", true) first, finish.lua only checks the staging against
expected.json and removes it again (and any MaterialVariant the chunks made); without it, it swaps the map (see the
template). The real run refuses any place but the region's PlaceId; a region with PlaceId 0 (the Testbed) is dry
run only."""
import datetime, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, "Art", "Studio", "Lindenmoor"))
import studio_kit  # noqa: E402

TEMPLATE = os.path.join(HERE, "finish_region.lua.tmpl")
# Parts whose name contains one of these lose collision in a region run. Only see-through or lit fittings that sit
# flush on something solid: window panes (*Glass: house/warehouse windows on the wall face, the crane's CabGlass)
# and lamp heads (*Glow: street-lamp and court lamp glows, the underworks DimGlow in its cage). Kerbs, steps, crates,
# goods, walls and roofs keep their collision. (Lindenmoor's list, studio_kit.NO_COLLIDE, is for its own flush
# decoration and is not used here: it would make the rail-town Kerbs and market Goods walk-through.)
NO_COLLIDE = ("Glass", "Glow")
NO_COLLIDE_KINDS = ()


def load(path, default=None):
    if not os.path.exists(path):
        return default
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def lua_json(v):
    s = json.dumps(v, sort_keys=True)
    assert "]==]" not in s
    return s


def main(argv):
    if not argv or argv[0].startswith("-"):
        raise SystemExit(__doc__)
    region = argv[0]
    date = argv[argv.index("--date") + 1] if "--date" in argv else datetime.date.today().isoformat()
    src = os.path.join(REPO, "Art", "Regions", region)
    folder = os.path.join(HERE, region)
    spec = load(os.path.join(src, "layout.json"))
    if spec is None:
        raise SystemExit(f"no region file {os.path.join(src, 'layout.json')}")
    if not os.path.exists(os.path.join(folder, "layout.json")):
        raise SystemExit(f"no export at {os.path.join(folder, 'layout.json')}: run export.py on Region_{region} first")
    mats = load(os.path.join(src, "materials.json"))
    water = load(os.path.join(src, "water.json"), {"Boxes": []})
    out = studio_kit.main(folder, region={"name": region, "materials": mats, "no_collide": NO_COLLIDE,
                                          "no_collide_kinds": NO_COLLIDE_KINDS})
    exp = out["expected"]
    if spec.get("Budget") and exp["parts"] > spec["Budget"]:
        raise SystemExit(f"{exp['parts']} parts is over the region's Budget {spec['Budget']}: not importable")
    fill = {"{{REGION}}": region, "{{PLACE_ID}}": str(int(spec.get("PlaceId") or 0)), "{{DATE}}": date,
            "{{EXPECTED}}": lua_json(exp), "{{WATER}}": lua_json(water.get("Boxes", [])),
            "{{ORIGIN}}": ", ".join(str(v) for v in out["origin"])}
    with open(TEMPLATE, encoding="utf-8") as f:
        lua = f.read()
    for k, v in fill.items():
        lua = lua.replace(k, v)
    left = [k for k in fill if k in lua]
    assert not left and "{{" not in lua, f"template slots left: {left}"
    with open(os.path.join(folder, "import", "finish.lua"), "w", encoding="utf-8") as f:
        f.write(lua)
    print(f"finish.lua: region {region}, place {fill['{{PLACE_ID}}']}, date {date}; tags {exp['tags']}; "
          f"variants {exp['variants']}; water boxes {len(water.get('Boxes', []))}")
    return out


if __name__ == "__main__":
    main(sys.argv[1:])

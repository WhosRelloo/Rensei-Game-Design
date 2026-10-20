"""Downloads the CC0 Poly Haven texture sets (and one HDRI) the Lindenmoor build uses.
Run: python fetch_textures.py   ->  Art/Blender/textures/<id>/<map>.jpg  (git-ignored; re-run to restore)
All assets are CC0 (https://polyhaven.com/license): free to use in the game, no attribution required."""
import json, os, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "textures")
RES = "2k"
SETS = {
    "leafy_grass": "ground grass",
    "sparse_grass": "ground grass, worn",
    "stony_dirt_path": "paths",
    "mossy_cobblestone": "village square",
    "mossy_rock": "boulders, outcrops",
    "cliff_side": "cliff faces",
    "stacked_stone_wall": "farmhouse stone base",
    "mossy_stone_wall": "field walls",
    "plastered_wall_04": "farmhouse upper floor",
    "medieval_wood": "timber framing",
    "brown_planks_05": "doors, shutters, crates",
    "clay_roof_tiles_02": "terracotta roofs",
    "bark_brown_02": "tree bark",
    "thatch_roof_angled": "hay, straw",
}
MAPS = {"Diffuse": "diff", "nor_gl": "nor", "Rough": "rough", "Displacement": "disp"}
HDRI = "kloofendal_misty_morning_puresky"

def get(url, tries=5):
    for i in range(tries):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Rensei-build"}), timeout=90) as r:
                return r.read()
        except Exception as e:
            if i == tries - 1:
                raise
            print("retry", url.rsplit("/", 1)[-1], e)

def main():
    os.makedirs(OUT, exist_ok=True)
    for tid in SETS:
        files = json.loads(get(f"https://api.polyhaven.com/files/{tid}"))
        d = os.path.join(OUT, tid)
        os.makedirs(d, exist_ok=True)
        for key, short in MAPS.items():
            entry = files.get(key, {}).get(RES, {})
            fmt = entry.get("jpg") or entry.get("png")
            if not fmt:
                continue
            ext = "jpg" if "jpg" in entry else "png"
            path = os.path.join(d, f"{short}.{ext}")
            if not os.path.exists(path):
                open(path, "wb").write(get(fmt["url"]))
        print("ok", tid, sorted(os.listdir(d)))
    files = json.loads(get(f"https://api.polyhaven.com/files/{HDRI}"))
    hd = files["hdri"]["2k"]["hdr"]["url"]
    p = os.path.join(OUT, f"{HDRI}.hdr")
    if not os.path.exists(p):
        open(p, "wb").write(get(hd))
    print("ok hdri", HDRI)

if __name__ == "__main__":
    main()

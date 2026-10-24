"""Region materials: the layout's Palette as Blender materials and as the Studio material table (spec 2026-10-23 §3.1,
Surfaces). Roblox built-in materials tinted to the region's palette, as Lindenmoor does.

The layout's Palette maps a role (ground_top, ground_side, path, quiet, or any name a later stage uses) to a base key
below, either as a string ("cinder") or, for a texture-pack image (owner, 2026-10-23), as an object
{"Key": "brick", "Pack": "<item name>"} naming a block in Art/Regions/texture_pack.json.

  palette(layout)        -> {key or role: bpy material}; Blender material names are RG_<Region>_<key>. A role that
                            names a Pack gets its own material, RG_<Region>_<role>, with the base key's flat colour
                            (Blender can't load Roblox images).
  write_table(layout, p) -> writes materials.json: {"<blender material name>": {"Material": "<Enum.Material name>",
                            "Color": "<hex>", "Transparency": t}}, plus "PackImage": "rbxassetid://<I>" and
                            "StudsPerTile": <U> for a Pack role. It also lists RG_<Region>_helper, the material of
                            the invisible marker parts.
write_table and table need no bpy; palette does."""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
PACK = os.path.normpath(os.path.join(HERE, "..", "..", "Regions", "texture_pack.json"))

# base key -> (Roblox material, colour hex, transparency). Rail-town palette from the brief: soot, iron, furnace
# brick, ember. Every colour is a PROPOSAL.
BASE = {
    "cinder": ("Ground", "4a4642", 0),  # PROPOSAL
    "cinder_dark": ("Ground", "3a3633", 0),  # PROPOSAL
    "slag": ("Slate", "2f2b29", 0),  # PROPOSAL
    "paving": ("Cobblestone", "5c5853", 0),  # PROPOSAL
    "brick": ("Brick", "7a3e2e", 0),  # PROPOSAL
    "brick_dark": ("Brick", "5e2f24", 0),  # PROPOSAL
    "iron": ("Metal", "3d4247", 0),  # PROPOSAL
    "timber": ("WoodPlanks", "5a4636", 0),  # PROPOSAL
    "glass_warm": ("Glass", "3a2a1c", 0.3),  # PROPOSAL
    "ember": ("Neon", "e0782a", 0),  # PROPOSAL
    "lamp": ("Neon", "ffb35c", 0),  # PROPOSAL
}
# the material of invisible marker parts (Studio hides them: export field 14 = 1); not a palette colour
HELPER = ("SmoothPlastic", "ff4fd8", 1)
# the roles the ground and routes stages read, and the base key each falls back to when the Palette leaves it out
ROLE_DEFAULTS = {"ground_top": "cinder", "ground_side": "slag", "path": "paving", "quiet": "cinder_dark",
                 "kerb": "slag", "rail": "iron", "sleeper": "timber"}
# how each Roblox material looks in the Blender renders: (roughness, metallic, emission strength)
LOOK = {"Ground": (0.95, 0.0, 0), "Slate": (0.85, 0.0, 0), "Cobblestone": (0.9, 0.0, 0), "Brick": (0.85, 0.0, 0),
        "Metal": (0.45, 0.8, 0), "WoodPlanks": (0.8, 0.0, 0), "Glass": (0.1, 0.0, 0), "Neon": (0.5, 0.0, 6)}


def mat_name(layout, key):
    return f"RG_{layout['Region']}_{key}"


def _pack():
    with open(PACK, encoding="utf-8") as f:
        return {p["N"]: p for p in json.load(f)}


def roles(layout):
    """{role: (base key, pack item name or None)} for the Palette's roles plus the defaults it leaves out."""
    out = {r: (k, None) for r, k in ROLE_DEFAULTS.items()}
    for role, v in (layout.get("Palette") or {}).items():
        if isinstance(v, dict):
            key, pack = v.get("Key"), v.get("Pack")
        else:
            key, pack = v, None
        if key not in BASE:
            raise ValueError(f"Palette {role}: unknown key {key!r} (one of {', '.join(BASE)})")
        if role == "helper" or (pack and role in BASE):
            raise ValueError(f"Palette {role}: that role name is taken by a base material; rename the role")
        out[role] = (key, pack or None)
    return out


def table(layout):
    """The material table as a dict (what write_table writes)."""
    t = {}
    for key, (mat, col, tr) in BASE.items():
        t[mat_name(layout, key)] = {"Material": mat, "Color": col, "Transparency": tr}
    t[mat_name(layout, "helper")] = {"Material": HELPER[0], "Color": HELPER[1], "Transparency": HELPER[2]}
    items = None
    for role, (key, pack) in roles(layout).items():
        if not pack:
            continue
        items = items if items is not None else _pack()
        it = items.get(pack)
        if it is None or not it.get("I"):
            raise ValueError(f"Palette {role}: {pack!r} is not a texture-pack item with an image")
        mat, col, tr = BASE[key]
        t[mat_name(layout, role)] = {"Material": mat, "Color": col, "Transparency": tr,
                                     "PackImage": "rbxassetid://" + str(it["I"]), "StudsPerTile": it.get("U", 4)}
    return t


def write_table(layout, path):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    t = table(layout)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(t, f, indent=1, sort_keys=True)
        f.write("\n")
    return t


def palette(layout):
    """{base key: material} for every base key, plus {role: material} for every role (see the module doc)."""
    from lindenmoor.core import flat, srgb

    def make(name, key):
        mat, col, tr = BASE[key]
        rough, metal, glow = LOOK.get(mat, (0.8, 0.0, 0))
        c = srgb(col)
        m = flat(name, c, rough=rough, metal=metal, emit=(c, glow) if glow else None, alpha=1 - tr)
        m["rs_roblox"] = mat
        return m

    out = {key: make(mat_name(layout, key), key) for key in BASE}
    for role, (key, pack) in roles(layout).items():
        out[role] = make(mat_name(layout, role), key) if pack else out[key]
    h = flat(mat_name(layout, "helper"), srgb(HELPER[1]), rough=0.5)
    h["rs_roblox"] = HELPER[0]
    out["helper"] = h
    return out

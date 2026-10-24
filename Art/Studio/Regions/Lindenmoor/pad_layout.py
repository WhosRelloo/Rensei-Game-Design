"""Lindenmoor import: how the hub pieces sit on their reserve pads (controller Rulings 4, 5, 7). Pure, stdlib only.

Each pad holds a few blocks placed side by side along +X, centred on the pad, with GAP studs between them.
A block is one World.Map child, or the test arena: Wall x2, Curve, Hill, Step and TrainingGround, kept together
as one block with its own internal layout, on its own pad (Ruling 5: the owner keeps the test arena in the map).
AlchemistSpawns is not a block: each of its children follows its site's slot, keeping its offset from the site
block's centre, and is pulled in to (pad radius - SPAWN_INSET) if that would land it off the pad (Ruling 7).
Block sizes use each Map child's tight part union (survey "PartBox") when present, else its "Box".
Used by check_survey.py (pad fit, spawn fit) and by Task 5's pads.json generator (slot and spawn offsets).
"""
import math

GAP = 4  # studs between blocks on a pad (PROPOSAL)
SPAWN_INSET = 8  # a spawn pulled back onto its pad stops this far inside the edge (Ruling 7; PROPOSAL)
ARENA = "TestArena"
ARENA_MEMBERS = ["Wall", "Curve", "Hill", "Step", "TrainingGround"]  # "Wall" matches both Walls (a Model and a Part)
MEMBER_COUNTS = {"Wall": 2}  # Map children expected more than once (measured 2026-10-24)

# pad id -> its blocks in slot order (-X to +X). Each block: (block name, World.Map child names in it)
PADS = {
    "res_burned_laboratory": [("BurnedLaboratory", ["BurnedLaboratory"]), ("AshPit", ["AshPit"])],
    "res_frozen_station": [("FrozenStation", ["FrozenStation"]), ("FrozenChamber", ["FrozenChamber"])],
    "res_cracked_footbridge": [("CrackedFootbridge", ["CrackedFootbridge"]), ("UnstableQuarry", ["UnstableQuarry"])],
    "res_silent_observatory": [("SilentObservatory", ["SilentObservatory"]), ("GaleFloor", ["GaleFloor"])],
    "res_silent_forge": [("SilentForge", ["SilentForge"]), ("ForgeFloor", ["ForgeFloor"])],
    "res_foundry_graybox": [("FoundryYard", ["FoundryYard"])],
    "res_practice_yard": [("LedgeCourse", ["LedgeCourse"])],
    "res_test_arena": [(ARENA, ARENA_MEMBERS)],  # Task 2 adds this reserve landmark to the layout
}

# AlchemistSpawns child name suffix (after the last "_") -> its site block (names measured in Ye, 2026-10-24)
SPAWN_SITES = {
    "BurnedLab": "BurnedLaboratory",
    "FrozenStation": "FrozenStation",
    "CrackedFootbridge": "CrackedFootbridge",
    "SilentObservatory": "SilentObservatory",
    "SilentForge": "SilentForge",
}


def arrange(pieces, gap=GAP):
    """pieces: [{"Name", "Size": [sx, sz]}] in slot order. Returns {"slots": {name: [dx, dz]}, "radius": r}:
    each piece's centre offset from the pad centre, and half the diagonal of the combined XZ AABB."""
    if not pieces:
        return {"slots": {}, "radius": 0.0}
    width = sum(p["Size"][0] for p in pieces) + gap * (len(pieces) - 1)
    depth = max(p["Size"][1] for p in pieces)
    slots, x = {}, -width / 2
    for p in pieces:
        slots[p["Name"]] = [x + p["Size"][0] / 2, 0.0]
        x += p["Size"][0] + gap
    return {"slots": slots, "radius": math.hypot(width, depth) / 2}


def _box(c):
    return c.get("PartBox") or c.get("Box")


def pad_pieces(map_children):
    """Survey MapChildren -> {pad id: [{"Name", "Size": [sx, sz], "Center": [cx, cz], "Members": [...]}]}.
    A block's Size/Center are the XZ union of its members' boxes; a block with no member found is left out."""
    by = {}
    for c in map_children:
        if _box(c):
            by.setdefault(c["Name"], []).append(_box(c))
    out = {}
    for pad, blocks in PADS.items():
        out[pad] = []
        for name, members in blocks:
            boxes = [b for m in members for b in by.get(m, [])]
            if not boxes:
                continue
            x0 = min(b[0][0] for b in boxes); x1 = max(b[1][0] for b in boxes)
            z0 = min(b[0][2] for b in boxes); z1 = max(b[1][2] for b in boxes)
            out[pad].append({"Name": name, "Size": [x1 - x0, z1 - z0], "Center": [(x0 + x1) / 2, (z0 + z1) / 2],
                             "Members": [m for m in members if m in by]})
    return out


def spawn_site(name):
    """An AlchemistSpawns child's site block, from its name suffix; None if unknown."""
    return SPAWN_SITES.get(name.rsplit("_", 1)[-1]) if "_" in name else None


def spawn_slots(spawns, pieces, radii, inset=SPAWN_INSET):
    """spawns: [{"Name", "Pos": [x, y, z]}] (AlchemistSpawns children); pieces: pad_pieces(...);
    radii: {pad id: pad radius}. Returns {spawn name: {"Site", "Pad", "Offset": [dx, dz], "Pulled": bool}}:
    the spawn's final offset from its pad centre. Site/Pad/Offset are None when its site or pad isn't known."""
    where = {}
    for pad, got in pieces.items():
        slots = arrange(got)["slots"]
        for p in got:
            where[p["Name"]] = (pad, p["Center"], slots[p["Name"]])
    out = {}
    for s in spawns:
        site = spawn_site(s["Name"])
        e = {"Site": site, "Pad": None, "Offset": None, "Pulled": False}
        out[s["Name"]] = e
        if site not in where:
            continue
        pad, centre, slot = where[site]
        e["Pad"] = pad
        dx, dz = slot[0] + s["Pos"][0] - centre[0], slot[1] + s["Pos"][2] - centre[1]
        r = radii.get(pad)
        if r is None:
            continue
        d = math.hypot(dx, dz)
        if d > r:
            k = max(r - inset, 0) / d
            dx, dz, e["Pulled"] = dx * k, dz * k, True
        e["Offset"] = [round(dx, 2), round(dz, 2)]
    return out

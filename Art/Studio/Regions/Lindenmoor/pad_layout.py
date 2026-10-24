"""Lindenmoor import: how the hub pieces sit on their reserve pads (controller Ruling 4). Pure, stdlib only.

Each pad holds a few blocks placed side by side along +X, centred on the pad, with GAP studs between them.
A block is one World.Map child, or the test arena: Wall x2, Curve, Hill, Step and TrainingGround, kept together
as one block with its own internal layout. AlchemistSpawns is not a block; its children follow their site's slot.
Used by check_survey.py (pad fit) and by Task 5's pads.json generator (slot offsets).
"""
import math

GAP = 4  # studs between blocks on a pad (PROPOSAL)
ARENA = "TestArena"
ARENA_MEMBERS = ["Wall", "Curve", "Hill", "Step", "TrainingGround"]  # "Wall" matches both Walls (a Model and a Part)

# pad id -> its blocks in slot order (-X to +X). Each block: (block name, World.Map child names in it)
PADS = {
    "res_burned_laboratory": [("BurnedLaboratory", ["BurnedLaboratory"]), ("AshPit", ["AshPit"])],
    "res_frozen_station": [("FrozenStation", ["FrozenStation"]), ("FrozenChamber", ["FrozenChamber"])],
    "res_cracked_footbridge": [("CrackedFootbridge", ["CrackedFootbridge"]), ("UnstableQuarry", ["UnstableQuarry"])],
    "res_silent_observatory": [("SilentObservatory", ["SilentObservatory"]), ("GaleFloor", ["GaleFloor"])],
    "res_silent_forge": [("SilentForge", ["SilentForge"]), ("ForgeFloor", ["ForgeFloor"])],
    "res_foundry_graybox": [("FoundryYard", ["FoundryYard"])],
    "res_practice_yard": [("LedgeCourse", ["LedgeCourse"]), (ARENA, ARENA_MEMBERS)],
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


def pad_pieces(map_children):
    """Survey MapChildren -> {pad id: [{"Name", "Size": [sx, sz], "Center": [cx, cz], "Members": [...]}]}.
    A block's Size/Center are the XZ union of its members' boxes; a block with no member found is left out."""
    by = {}
    for c in map_children:
        if c.get("Box"):
            by.setdefault(c["Name"], []).append(c["Box"])
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

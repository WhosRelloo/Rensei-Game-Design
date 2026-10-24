"""The style kits' data, without bpy (spec 2026-10-23 §3.3): what the planners (placement.py) need to know about each
kit piece. kits/<kit>.py builds the pieces and takes its tables from here, so there is one source for each number.

A layout names a piece "<kit>.<piece>": a district's Style ("railtown.house") or a landmark's Kind
("railtown.practice_court").

Styles (buildings), per piece:
  kind     the Roblox prefab kind (Model name prefix);
  size     (w min, w max, d min, d max) studs;
  terrace  neighbours share a party wall (else every building stands alone);
  front    how far the front fittings (door step, canopy, dock, hoist) reach past the front wall;
  step     (height above the floor, depth out from the front wall) of the door step or dock the stoop starts from,
           or None (no door: no stoop).
Landmarks: kind, and foot (a local [x0, y0, x1, y1] the planners keep clear; front = local -y).
Every number is a PROPOSAL. No bpy; standard library only."""

KITS = {
    "railtown": {
        "styles": {
            "house": {"kind": "House", "size": (12, 16, 16, 20), "terrace": True, "front": 1.5, "step": (0.8, 1.2)},
            "boarding": {"kind": "BoardingHouse", "size": (32, 40, 16, 18), "terrace": False, "front": 3.4,
                         "step": (0.8, 1.2)},
            "shed": {"kind": "Shed", "size": (14, 22, 12, 18), "terrace": False, "front": 1.5, "step": (0.6, 0.2)},
            "warehouse": {"kind": "Warehouse", "size": (24, 36, 18, 24), "terrace": False, "front": 4.2,
                          "step": (1.4, 3.6)},
            "stack": {"kind": "Smokestack", "size": (6, 8, 6, 8), "terrace": False, "front": 1.0, "step": None},
        },
        "landmarks": {
            "practice_court": {"kind": "PracticeCourt", "foot": (-20, -20, 20, 20)},
            "foundry_hall": {"kind": "FoundryHall", "foot": (-49, -35, 49, 33)},
            "crane_bay": {"kind": "CraneBay", "foot": (-24, -16, 24, 16)},
            "rail_walk": {"kind": "RailWalk", "foot": (-23, -5, 43, 5)},
            "underworks": {"kind": "Underworks", "foot": (-8, -8, 8, 8)},
            "canteen": {"kind": "Canteen", "foot": (-13, -12, 13, 12)},
            "market_stall": {"kind": "MarketStall", "foot": (-5, -4, 5, 3)},
        },
        "cover": {"kind": "Cover", "foot": (-3, -3, 3, 3)},
        "lamp": {"kind": "LampPost", "foot": (-0.8, -0.8, 0.8, 0.8)},
    },
    # Foundry Yard's own set pieces (kits/foundry.py; owner-approved layout 2026-10-24). No building styles: its
    # districts use railtown's. The viaduct is built by extras.py, not here.
    "foundry": {
        "styles": {},
        "landmarks": {
            "great_hall": {"kind": "GreatHall", "foot": (-101, -58, 101, 65)},
            "ticket_hall": {"kind": "TicketHall", "foot": (-31, -25, 31, 13)},
            "platform_canopy": {"kind": "PlatformCanopy", "foot": (-6, -160, 7, 160)},
            "road_gate": {"kind": "RoadGate", "foot": (-11, -2, 11, 2)},
            "gatehouse": {"kind": "Gatehouse", "foot": (-19, -7, 19, 6)},
            "shift_office": {"kind": "ShiftOffice", "foot": (-8, -9, 8, 6)},
            "signal_gantry": {"kind": "SignalGantry", "foot": (-3, -36, 3, 36)},
            "wagon": {"kind": "Wagon", "foot": (-15, -5, 15, 5)},
            "water_tower": {"kind": "WaterTower", "foot": (-7, -10, 7, 7)},
            "yard_wall": {"kind": "YardWall", "foot": (-31, -2, 31, 3)},
        },
        "cover": {"kind": "Cover", "foot": (-3, -3, 3, 3)},
        "lamp": {"kind": "LampPost", "foot": (-0.8, -0.8, 0.8, 0.8)},
    },
}


def piece(name):
    """(kit name, piece name, "style" | "landmark", spec) for "<kit>.<piece>"; ValueError for an unknown name."""
    kit, _, p = str(name).partition(".")
    k = KITS.get(kit)
    if k is None:
        raise ValueError(f"unknown kit {kit!r} in {name!r} (kits: {', '.join(KITS)})")
    if p in k["styles"]:
        return kit, p, "style", k["styles"][p]
    if p in k["landmarks"]:
        return kit, p, "landmark", k["landmarks"][p]
    raise ValueError(f"{name!r}: {kit} has no piece {p!r} (styles: {', '.join(k['styles'])}; "
                     f"landmarks: {', '.join(k['landmarks'])})")


def kit_name(layout):
    """The region's kit: its first district's or landmark's kit, else railtown."""
    for item in list(layout.get("Districts") or []) + list(layout.get("Landmarks") or []):
        name = item.get("Style") or item.get("Kind") or ""
        if name.partition(".")[0] in KITS:
            return name.partition(".")[0]
    return "railtown"

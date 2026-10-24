"""The region file, Art/Regions/<Region>/layout.json (spec 2026-10-23 §3.1).

Coordinates are studs with the origin at the footprint's centre: x = east, z = south. A point is [x, z]; a marker's
At is [x, y, z], where y = 0 means "on the ground" (the builder snaps it). A Rect is [x0, z0, x1, z1].

load(path) returns the parsed dict, with optional fields filled in (box Edge 0, Yaw 0, Attr {}), or raises
SchemaError(messages) listing every problem found. No bpy; standard library only."""
import json, re

HEIGHT_KINDS = ("plane", "box", "ridge", "cut", "water")
ROUTE_KINDS = ("public", "quiet", "rail", "under", "ledge", "road")
POST_KINDS = ("Work", "Seat", "Counter", "Home", "Shelter")

# Tags a marker may carry: the names the game's services read (spec §3.4), plus the map-placed gameplay tags
# (RenseiInspect, RenseiMechanism, RenseiPuzzleDoor, RenseiLight). Add a tag here when a region needs one.
MARKER_TAGS = frozenset((
    # World Plan 1 (travel)
    "RenseiArrival", "RenseiPlatformTrain", "RenseiTicketClerk", "RenseiDepartureBoard", "RenseiStationGate",
    "RenseiFreightYard", "RenseiWatcher", "RenseiRoadPassage", "RenseiRoadThreshold", "RenseiRoadEncounter",
    # places, movement, enemies
    "RenseiArea", "RenseiLedge", "RenseiEnemySpawn",
    # new for regions
    "RenseiPost", "RenseiClue", "RenseiTrial",
    # other map-placed gameplay pieces
    "RenseiInspect", "RenseiMechanism", "RenseiPuzzleDoor", "RenseiLight",
    # Task 12: a travel piece Art/Studio/Regions/setup.lua builds in Studio (Attr.Piece; see TRAVEL_PIECES)
    "RenseiMarker",
))
# Builder-only tags: the builder reads these markers and never exports them (the markers stage makes no part for
# them). EdgeGap: a Box where the edges stage leaves the edge ridges open (a road mouth, the station); it needs a Box.
BUILDER_TAGS = frozenset(("EdgeGap",))
# the spec's old names: no service reads them, so a marker carrying one would import and silently do nothing
OLD_TAGS = {
    "RenseiClerk": "RenseiTicketClerk",
    "RenseiThreshold": "RenseiRoadThreshold",
    "RenseiEncounter": "RenseiRoadEncounter",
    "RenseiTrialDoor": "RenseiTrial",
}
# attributes a tag must carry (spec §3.4; Post Facing comes from the marker's Yaw)
MARKER_ATTRS = {
    "RenseiPost": ("PostId", "Kind"),
    "RenseiClue": ("ClueId",),
    "RenseiArea": ("AreaName",),
    "RenseiTrial": ("TrialId",),
    "RenseiMarker": ("Piece",),
}
# RenseiMarker (Task 12): Art/Studio/Regions/setup.lua builds one travel piece per marker, at its spot (the marker's At;
# y = 0 is the ground) facing its Yaw (0 = -Z, 90 = -X, -90 = +X). Attr.Piece names the piece; these are each piece's
# Attr ("str" a non-empty string, "num" a number, "int" a whole number, "bool", "json" a STRING holding JSON, since
# Roblox attributes can't hold lists). Coordinates in Attr are region coordinates. setup.lua's header has the details.
TRAVEL_PIECES = {
    "Station": {"Route": "str", "TrackX": "num", "RailTop": "num", "NoseZ": "num", "PlatformSide": "num"},
    "Clerk": {"Station": "str"},
    "Board": {},
    "Gate": {"Route": "str"},
    "Railing": {"Runs": "json", "WallTop": "num"},
    "FreightYard": {},
    "RoadPassage": {"Route": "str", "To": "str", "RoadName": "str", "Legs": "json", "Threshold": "num",
                    "RoadStart": "num", "Encounters": "json", "Half": "num", "RoadY": "num", "Seed": "int"},
}
TRAVEL_OPTIONAL = {
    "Station": {"Arrival": "bool"},  # false: no Platform arrival (a second station; one Platform arrival per place)
    "Gate": {"Sign": "str"},
    "RoadPassage": {"Name": "str", "FloorY": "num", "Cut": "num", "High": "num", "Gate": "num", "Fence": "json",
                    "Skip": "json", "Clip": "json"},
}
CLIP_KEYS = ("MinX", "MaxX", "MinZ", "MaxZ")
MAX_BUDGET = 90000  # the world spec's ceiling for any region (spec §3.6)
# the tallest a district's buildings may be: the kit's part counts are checked at this cap (<= about 150 parts per
# building; blender_check builds every style at it). PROPOSAL
MAX_STOREYS = 4

# Every top-level key a region file may have; any other key is an error (it catches typos). A later task that adds a
# top-level key to the region file must add it here, or every file carrying it will fail to load.
TOP_KEYS = ("Region", "PlaceId", "Footprint", "Palette", "Heights", "Districts", "Routes", "Landmarks", "Markers",
            "Budget")
# optional top-level keys, read by the Studio import (Art/Studio/Regions/kit.py; Task 11 fix round 2):
#   KeepMapChildren: names of workspace.World.Map children the real run leaves in place (absent = keep nothing);
#   MapChild: the World.Map child the import builds (absent = the Region name), e.g. "LindenmoorExpansion" beside
#   the kept village Map.Lindenmoor. (Lindenmoor's own "Keep", a list of area objects, is a different thing.)
OPTIONAL_KEYS = ("KeepMapChildren", "MapChild")


class SchemaError(Exception):
    def __init__(self, messages):
        self.messages = list(messages)
        super().__init__("region file has %d problem(s):\n  " % len(self.messages) + "\n  ".join(self.messages))


# ------------------------------------------------------------------ value checks
def _num(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool)


def _int(v):
    return isinstance(v, int) and not isinstance(v, bool)


def _str(v):
    return isinstance(v, str) and v != ""


def _point(v, n=2):
    return isinstance(v, list) and len(v) == n and all(_num(c) for c in v)


def _line(v):
    return isinstance(v, list) and len(v) >= 2 and all(_point(p) for p in v)


def _pal(v):
    """A Palette value: a material key, or {"Key": key, "Pack": texture-pack item name} (Pack optional)."""
    if isinstance(v, dict):
        return _str(v.get("Key")) and set(v) <= {"Key", "Pack"} and ("Pack" not in v or _str(v["Pack"]))
    return _str(v)


def _rect(v):
    return isinstance(v, list) and len(v) == 4 and all(_num(c) for c in v) and v[0] < v[2] and v[1] < v[3]


class _Checker:
    def __init__(self):
        self.errs = []
        self.half = None  # (half width, half depth) once Footprint is known

    def err(self, where, msg):
        self.errs.append(f"{where}: {msg}")

    def need(self, obj, key, ok, where, what):
        """Checks obj[key] exists and passes ok; returns whether it does."""
        if key not in obj:
            self.err(where, f"missing {key}")
            return False
        if not ok(obj[key]):
            self.err(where, f"{key} must be {what}, got {obj[key]!r}")
            return False
        return True

    def inside(self, where, pts):
        if self.half is None:
            return
        hw, hd = self.half
        for p in pts:
            if abs(p[0]) > hw or abs(p[-1]) > hd:
                self.err(where, f"point {p} is outside the footprint (|x| <= {hw}, |z| <= {hd})")

    def items(self, data, key):
        v = data.get(key)
        if not isinstance(v, list):
            return []
        out = []
        for n, it in enumerate(v):
            if isinstance(it, dict):
                out.append((n, it))
            else:
                self.err(f"{key}[{n}]", "must be an object")
        return out

    def ids(self, key, items):
        seen = set()
        for n, it in items:
            i = it.get("Id")
            if not isinstance(i, str):
                continue  # a missing or non-string Id is reported by its own check
            if i in seen:
                self.err(f"{key}[{n}] {i}", "duplicate Id")
            seen.add(i)


_KIND = {"str": (_str, "a non-empty string"), "num": (_num, "a number"), "int": (_int, "a whole number"),
         "bool": (lambda v: isinstance(v, bool), "true or false")}


def _json_shape(key, v):
    """A RenseiMarker JSON attribute's parsed value: '' when its shape is right, else what it must be."""
    if key == "Runs":
        ok = isinstance(v, list) and len(v) >= 1 and all(_point(r, 4) for r in v)
        return "" if ok else "a JSON list of one or more [x1, z1, x2, z2]"
    if key == "Legs":
        ok = isinstance(v, list) and len(v) >= 1 and all(
            isinstance(g, list) and ((len(g) == 5 and g[0] == "line") or (len(g) == 6 and g[0] == "arc"))
            and all(_num(x) for x in g[1:]) for g in v)
        return "" if ok else 'a JSON list of ["line", x1, z1, x2, z2] / ["arc", cx, cz, r, a1, a2] legs'
    if key == "Encounters":
        return "" if isinstance(v, list) and all(_num(s) for s in v) else "a JSON list of distances [s, ...]"
    if key == "Fence":
        return "" if _point(v, 2) else "a JSON [s1, s2]"
    if key == "Skip":
        return "" if isinstance(v, list) and all(_rect(r) for r in v) else "a JSON list of [x0, z0, x1, z1] (x0 < x1, z0 < z1)"
    if key == "Clip":
        ok = isinstance(v, dict) and v and all(k in CLIP_KEYS and _num(x) for k, x in v.items())
        return "" if ok else "a JSON object of " + ", ".join(CLIP_KEYS) + " (numbers)"
    return ""


def _travel_marker(c, w, m, attr):
    """A RenseiMarker: a point marker (At), Attr.Piece one of TRAVEL_PIECES, that piece's Attr present and well formed,
    no other Attr (a misspelt name would be silently ignored in Studio)."""
    if "At" not in m:
        c.err(w, "a RenseiMarker needs At (its spot), not a Box")
    piece = attr.get("Piece")
    if piece is None:
        return  # reported as missing Attr.Piece
    if not (isinstance(piece, str) and piece in TRAVEL_PIECES):
        c.err(w, f"Attr.Piece must be one of {', '.join(TRAVEL_PIECES)}, got {piece!r}")
        return
    w = f"{w} {piece}"
    need, opt = TRAVEL_PIECES[piece], TRAVEL_OPTIONAL.get(piece, {})
    for key, kind in list(need.items()) + list(opt.items()):
        if key not in attr:
            if key in need:
                c.err(w, f"missing Attr.{key}")
            continue
        v = attr[key]
        if kind == "json":
            if not isinstance(v, str):
                c.err(w, f"Attr.{key} must be a string holding JSON (Roblox attributes can't hold lists), got {v!r}")
                continue
            try:
                parsed = json.loads(v)
            except ValueError as e:
                c.err(w, f"Attr.{key} is not valid JSON ({e}): {v!r}")
                continue
            what = _json_shape(key, parsed)
            if what:
                c.err(w, f"Attr.{key} must be {what}, got {v!r}")
        else:
            ok, what = _KIND[kind]
            if not ok(v):
                c.err(w, f"Attr.{key} must be {what}, got {v!r}")
    if piece == "Station" and _num(attr.get("PlatformSide")) and attr["PlatformSide"] != 1:
        c.err(w, f"Attr.PlatformSide must be 1 (the platform on the track's +X side: the trains' baggage door faces -X), "
                 f"got {attr['PlatformSide']!r}")
    for key in attr:
        if key != "Piece" and key not in need and key not in opt:
            c.err(w, f"unknown Attr.{key} (a {piece} takes {', '.join(list(need) + list(opt)) or 'none'})")


def validate(data):
    """Returns a list of problems (empty when the region file is valid). Fills in optional defaults."""
    c = _Checker()
    if not isinstance(data, dict):
        return ["the region file must be a JSON object"]
    for k in TOP_KEYS:
        if k not in data:
            c.err("region", f"missing {k}")
    for k in data:
        if k not in TOP_KEYS and k not in OPTIONAL_KEYS:
            c.err("region", f"unknown key {k}")

    if "Region" in data and not _str(data["Region"]):
        c.err("region", f"Region must be a non-empty string, got {data['Region']!r}")
    if "PlaceId" in data and not (_int(data["PlaceId"]) and data["PlaceId"] >= 0):
        c.err("region", f"PlaceId must be an integer >= 0, got {data['PlaceId']!r}")
    fp = data.get("Footprint")
    if "Footprint" in data:
        if _point(fp) and fp[0] > 0 and fp[1] > 0:
            c.half = (fp[0] / 2, fp[1] / 2)
        else:
            c.err("region", f"Footprint must be [width, depth] in studs, both > 0, got {fp!r}")
    child = data.get("MapChild", data.get("Region"))
    if "MapChild" in data and not (_str(child) and re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", child)):
        c.err("region", f"MapChild must be a name of letters, digits and _ (starting with a letter), got {child!r}")
    keep = data.get("KeepMapChildren")
    if "KeepMapChildren" in data and not (isinstance(keep, list) and all(_str(k) for k in keep)
                                          and len(set(keep)) == len(keep)):
        c.err("region", f"KeepMapChildren must be a list of distinct non-empty names (World.Map children), got {keep!r}")
    if isinstance(keep, list) and child in keep:
        c.err("region", f"KeepMapChildren may not name the MapChild ({child!r}): the import builds World.Map.{child}")
    if "Budget" in data and not (_int(data["Budget"]) and 0 < data["Budget"] <= MAX_BUDGET):
        c.err("region", f"Budget must be an integer in 1..{MAX_BUDGET}, got {data['Budget']!r}")
    pal = data.get("Palette")
    if "Palette" in data and not (isinstance(pal, dict) and all(_str(k) and _pal(v) for k, v in pal.items())):
        c.err("region", 'Palette must map names to material names (strings) or to {"Key": name, "Pack": item}')
    for k in ("Heights", "Districts", "Routes", "Landmarks", "Markers"):
        if k in data and not isinstance(data[k], list):
            c.err("region", f"{k} must be a list")

    # Heights
    for n, h in c.items(data, "Heights"):
        w = f"Heights[{n}]"
        kind = h.get("Kind")
        if kind not in HEIGHT_KINDS:
            c.err(w, f"Kind must be one of {', '.join(HEIGHT_KINDS)}, got {kind!r}")
            continue
        w = f"Heights[{n}] {kind}"
        if kind in ("plane", "box", "ridge", "cut"):
            c.need(h, "Y", _num, w, "a number")
        if kind in ("box", "cut", "water"):
            c.need(h, "Rect", _rect, w, "[x0, z0, x1, z1] with x0 < x1 and z0 < z1")
        if kind == "box":
            h.setdefault("Edge", 0)
            c.need(h, "Edge", lambda v: _num(v) and v >= 0, w, "a number >= 0")
        if kind == "ridge":
            c.need(h, "Line", _line, w, "a list of 2 or more [x, z] points")
            c.need(h, "Width", lambda v: _num(v) and v > 0, w, "a number > 0")
        if kind == "water":
            if c.need(h, "Top", _num, w, "a number") and c.need(h, "Bed", _num, w, "a number"):
                if not h["Bed"] < h["Top"]:
                    c.err(w, f"Bed ({h['Bed']}) must be below Top ({h['Top']})")

    # Districts
    ds = c.items(data, "Districts")
    c.ids("Districts", ds)
    for n, d in ds:
        w = f"Districts[{n}] {d.get('Id', '?')}"
        c.need(d, "Id", _str, w, "a non-empty string")
        if c.need(d, "Poly", lambda v: isinstance(v, list) and len(v) >= 3 and all(_point(p) for p in v), w,
                  "a list of 3 or more [x, z] points"):
            c.inside(w, d["Poly"])
        c.need(d, "Style", _str, w, "a style name")
        c.need(d, "Density", lambda v: _num(v) and 0 <= v <= 1, w, "a number in 0..1")
        c.need(d, "Storeys", lambda v: isinstance(v, list) and len(v) == 2 and all(_int(s) for s in v)
               and 1 <= v[0] <= v[1] <= MAX_STOREYS, w, f"[min, max] whole storeys, 1 <= min <= max <= {MAX_STOREYS}")

    # Routes
    rs = c.items(data, "Routes")
    c.ids("Routes", rs)
    for n, r in rs:
        w = f"Routes[{n}] {r.get('Id', '?')}"
        c.need(r, "Id", _str, w, "a non-empty string")
        c.need(r, "Kind", lambda v: v in ROUTE_KINDS, w, "one of " + ", ".join(ROUTE_KINDS))
        c.need(r, "Width", lambda v: _num(v) and v > 0, w, "a number > 0")
        if c.need(r, "Line", _line, w, "a list of 2 or more [x, z] points"):
            c.inside(w, r["Line"])

    # Landmarks
    ls = c.items(data, "Landmarks")
    c.ids("Landmarks", ls)
    for n, m in ls:
        w = f"Landmarks[{n}] {m.get('Id', '?')}"
        c.need(m, "Id", _str, w, "a non-empty string")
        c.need(m, "Kind", _str, w, "a landmark kind")
        if c.need(m, "At", _point, w, "[x, z]"):
            c.inside(w, [m["At"]])
        m.setdefault("Yaw", 0)
        c.need(m, "Yaw", _num, w, "a number (degrees)")

    # Markers
    posts = set()
    for n, m in c.items(data, "Markers"):
        tag = m.get("Tag")
        w = f"Markers[{n}] {tag}"
        if not isinstance(tag, str):
            c.err(w, f"Tag must be a string, got {tag!r}")
            tag = None
        elif tag in OLD_TAGS:
            c.err(w, f"unknown Tag {tag!r} (an old spec name: the game reads {OLD_TAGS[tag]})")
        elif tag not in MARKER_TAGS and tag not in BUILDER_TAGS:
            c.err(w, f"unknown Tag {tag!r}")
        has_at, has_box = "At" in m, "Box" in m
        if tag in BUILDER_TAGS and not has_box:
            c.err(w, f"{tag} needs a Box ([[x0, y0, z0], [x1, y1, z1]])")
            continue
        if has_at == has_box:
            c.err(w, "needs exactly one of At ([x, y, z]) or Box ([[x, y, z], [x, y, z]])")
        elif has_at:
            if c.need(m, "At", lambda v: _point(v, 3), w, "[x, y, z]"):
                c.inside(w, [m["At"]])
        elif c.need(m, "Box", lambda v: isinstance(v, list) and len(v) == 2 and all(_point(p, 3) for p in v)
                    and all(v[0][a] < v[1][a] for a in range(3)), w, "[[x0, y0, z0], [x1, y1, z1]], min < max"):
            c.inside(w, m["Box"])
        m.setdefault("Yaw", 0)
        c.need(m, "Yaw", _num, w, "a number (degrees)")
        m.setdefault("Attr", {})
        if not c.need(m, "Attr", lambda v: isinstance(v, dict), w, "an object"):
            continue
        attr = m["Attr"]
        for a in MARKER_ATTRS.get(tag, ()):
            if a not in attr:
                c.err(w, f"missing Attr.{a}")
        if tag == "RenseiMarker":
            _travel_marker(c, w, m, attr)
        if tag == "RenseiPost":
            if "Kind" in attr and attr["Kind"] not in POST_KINDS:
                c.err(w, f"Attr.Kind must be one of {', '.join(POST_KINDS)}, got {attr['Kind']!r}")
            pid = attr.get("PostId")
            if pid is None:
                pass  # reported as missing above
            elif not _str(pid):
                c.err(w, f"Attr.PostId must be a non-empty string, got {pid!r}")
            elif pid in posts:
                c.err(w, f"duplicate PostId {pid!r}")
            else:
                posts.add(pid)
    return c.errs


def load(path):
    """Reads and checks a region file. Returns the dict, or raises SchemaError listing every problem."""
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError) as e:
        raise SchemaError([f"{path}: {e}"]) from e
    errs = validate(data)
    if errs:
        raise SchemaError(errs)
    return data

"""Extra Blender stages for a region, run after build.run's stages (first used by Foundry Yard, 2026-10-24):

  portals(layout, grid)        a tunnel portal in every EdgeGap whose Attr has "Portal" ("rail" or "road"): the gap in
                               the edge wall becomes a dark tunnel mouth through the wall band, closed at the
                               footprint's edge, so a road or a line visibly leaves the map with no way out. Group
                               Edges, kind Portal; every part carries RenseiNoGrip (placement.EDGE_TAG), like the walls.
  viaduct(layout, grid, ...)   a brick viaduct along +Z / -Z over sunken ground: piers down to the ground, arch rings,
                               spandrels, a paved deck level with the ground at its ends, parapets and NightOnly lamps.
                               Group Landmarks, kind Viaduct. It isn't a kit landmark because the landmarks stage settles
                               a landmark on the highest ground under it and fills a footing down to the lowest, which
                               would fill the cut it spans.
  travel_preview(layout, grid) render-only stand-ins for the travel pieces setup.lua builds in Studio from the
                               RenseiMarker markers (platform, platform train, buffer stops, the ticket booth, departure
                               board, papers gate and railing, the stowaway yard's crates): group Preview, rs_skip, no
                               rs_kind, so the export and the part count leave them out.

Frame: region (x, y, z) -> Blender (x, z, y) (stages.bl). Every size here is a PROPOSAL."""
import json, math

from lindenmoor.core import box, cyl, flat, srgb
from . import kits, materials, placement as PL, stages as ST

NOGRIP = PL.EDGE_TAG
PORTAL_H = {"rail": 22.0, "road": 20.0}  # the tunnel mouth's clear height over the ground (PROPOSAL)


def _bpy():
    import bpy
    return bpy


# ------------------------------------------------------------------ portals
def _gap_side(layout, box_):
    """The footprint side ("N", "S", "W" or "E") an EdgeGap box opens, from which band it reaches into."""
    fw, fd = layout["Footprint"]
    (x0, _, z0), (x1, _, z1) = box_
    B = PL.EDGE_BAND
    if z1 >= fd / 2 - B and x0 > -fw / 2 + B and x1 < fw / 2 - B:
        return "S"
    if z0 <= -fd / 2 + B and x0 > -fw / 2 + B and x1 < fw / 2 - B:
        return "N"
    if x1 >= fw / 2 - B:
        return "E"
    if x0 <= -fw / 2 + B:
        return "W"
    raise ValueError(f"EdgeGap {box_} meets no edge band")


def portals(layout, grid):
    """Builds a portal in each EdgeGap with Attr.Portal. Returns the part count."""
    M = materials.palette(layout)
    c = ST.group(layout, "Edges")
    fw, fd = layout["Footprint"]
    B = PL.EDGE_BAND
    n = 0
    for j, m in enumerate(layout["Markers"]):
        kind = (m.get("Attr") or {}).get("Portal")
        if m["Tag"] != "EdgeGap" or not kind:
            continue
        if kind not in PORTAL_H:
            raise ValueError(f"EdgeGap {j}: Portal must be one of {', '.join(PORTAL_H)}, got {kind!r}")
        side = _gap_side(layout, m["Box"])
        (x0, _, z0), (x1, _, z1) = m["Box"]
        # the opening across the gap, in the band: a = across (x for N/S, z for E/W), b = into the band
        if side in "NS":
            a0, a1 = max(x0, -fw / 2 + B), min(x1, fw / 2 - B)
            b_in, b_out = (fd / 2 - B, fd / 2) if side == "S" else (-fd / 2 + B, -fd / 2)
        else:
            a0, a1 = max(z0, -fd / 2 + B), min(z1, fd / 2 - B)
            b_in, b_out = (fw / 2 - B, fw / 2) if side == "E" else (-fw / 2 + B, -fw / 2)
        sgn = 1 if b_out > b_in else -1

        def at(a, b):  # region (x, z) of (across, into-band)
            return (a, b) if side in "NS" else (b, a)

        mid_a = (a0 + a1) / 2
        gx, gz = at(mid_a, b_in - sgn * 4)
        g = PL.ground_y(grid, gx, gz)
        H = PORTAL_H[kind]
        top = g + PL.EDGE_HEIGHT + 6.0
        root = ST.prefab(c, "Portal", f"{kind}_{j}", (0, 0, 0))
        root["rs_portal"] = kind

        def blk(name, a_lo, a_hi, b_lo, b_hi, y_lo, y_hi, mat, bevel=0.2):
            (xa, za), (xb, zb) = at(a_lo, b_lo), at(a_hi, b_hi)
            sx, sz = abs(xb - xa), abs(zb - za)
            o = ST.part(root, name, (sx, sz, y_hi - y_lo), ST.bl((xa + xb) / 2, (y_lo + y_hi) / 2, (za + zb) / 2),
                        M[mat], bevel=bevel)
            o["rs_tags"] = NOGRIP
            return o

        depth = abs(b_out - b_in)
        lo, hi = min(b_in, b_out), max(b_in, b_out)
        parts = [
            # the lintel over the mouth, as tall as the walls beside it
            blk("Lintel", a0, a1, lo, hi, g + H, top, "slag", bevel=0.3),
            # the back of the tunnel at the footprint's edge: a soot-black wall
            blk("Back", a0, a1, (hi - 1.0) if sgn > 0 else lo, hi if sgn > 0 else (lo + 1.0), g - 1.0, g + H, "soot", 0.05),
            # a brick ring round the mouth on the wall's inner face
            blk("JambA", a0, a0 + 2.4, (b_in - 1.2) if sgn > 0 else b_in, b_in if sgn > 0 else (b_in + 1.2), g - 0.5,
                g + H + 2.4, "brick_dark", 0.1),
            blk("JambB", a1 - 2.4, a1, (b_in - 1.2) if sgn > 0 else b_in, b_in if sgn > 0 else (b_in + 1.2), g - 0.5,
                g + H + 2.4, "brick_dark", 0.1),
            blk("Header", a0, a1, (b_in - 1.2) if sgn > 0 else b_in, b_in if sgn > 0 else (b_in + 1.2), g + H,
                g + H + 2.4, "brick_dark", 0.1),
            blk("Keystone", mid_a - 1.6, mid_a + 1.6, (b_in - 1.6) if sgn > 0 else b_in, b_in if sgn > 0 else (b_in + 1.6),
                g + H - 0.6, g + H + 3.0, "stone", 0.08),
        ]
        n += len(parts)
        root["rs_depth"] = depth
    return n


# ------------------------------------------------------------------ the viaduct
def viaduct(layout, grid, x, z0, z1, width=16.0, deck_top=None, pier_every=24.0, name="Viaduct"):
    """A viaduct along z from z0 to z1 (either order) at x: the deck's top at deck_top (default: the ground at the
    ends' higher one), piers every pier_every from the first sunken point, an arch ring and spandrels in each bay,
    parapets and lamps. Returns the part count."""
    kits.bind(materials.palette(layout))
    R = kits.railtown
    c = ST.group(layout, "Landmarks")
    za, zb = min(z0, z1), max(z0, z1)
    if deck_top is None:
        deck_top = max(PL.ground_y(grid, x, za), PL.ground_y(grid, x, zb))
    root = ST.prefab(c, "Viaduct", name, ST.bl(x, deck_top, (za + zb) / 2))
    root["rs_style"] = "extras.viaduct"
    L = zb - za
    hw = width / 2
    dz = 1.6  # deck thickness
    P = []

    def loc(lx, ly, lz):  # local (x across, y along +z, z up) from the root (no rotation): Blender (x, y, z)
        return (lx, ly, lz)

    P.append(R.pb(root, "Deck", (width, L, dz), loc(0, 0, -dz / 2), "paving", bevel=0.05))
    for s in (-1, 1):
        P.append(R.pb(root, f"Parapet{s:+d}", (1.0, L, 3.4), loc(s * (hw + 0.5), 0, 1.7), "brick", bevel=0.06))
        P.append(R.pb(root, f"Coping{s:+d}", (1.4, L + 0.2, 0.4), loc(s * (hw + 0.5), 0, 3.6), "stone", bevel=0.05))
        P.append(R.pb(root, f"StringCourse{s:+d}", (0.6, L, 0.8), loc(s * (hw + 0.3), 0, -dz - 0.4), "stone", bevel=0.04))
    # piers wherever the ground under the deck is 2+ below it
    under = deck_top - dz
    zs, z = [], za + pier_every / 2
    while z < zb - 2:
        if PL.ground_y(grid, x, z) < under - 2:
            zs.append(z)
        z += pier_every
    r, T = (pier_every - 3.0) / 2, 1.6
    for i, zp in enumerate(zs):
        g = PL.ground_y(grid, x, zp)
        h = under - (g - 1.0)
        P.append(R.pb(root, f"Pier{i}", (width, 3.0, h), loc(0, zp - (za + zb) / 2, -dz - h / 2), "brick_dark", bevel=0.08))
    # an arch ring and two spandrels in each bay between piers (and between the end of the deck and the first/last)
    edges_ = [za] + zs + [zb]
    for i, (pa, pb_) in enumerate(zip(edges_, edges_[1:])):
        mid = (pa + pb_) / 2
        g = PL.ground_y(grid, x, mid)
        if g > under - 4:
            continue  # no room under this bay for an arch
        rr = min(r, (pb_ - pa) / 2 - 1.0)
        yc = under - rr - T / 2  # the arch's centre height: its crown's top meets the deck's underside
        for k in range(6):
            phi = math.radians(15 + 30 * k)
            ly = mid - (za + zb) / 2 + rr * math.cos(phi)
            lz = yc + rr * math.sin(phi) - deck_top
            P.append(R.pb(root, f"Arch{i}_{k}", (width - 0.4, 2 * rr * math.tan(math.radians(15)) + 0.3, T),
                          loc(0, ly, lz), "brick", rot=(phi + math.pi / 2, 0, 0), bevel=0.04))
        for s in (-1, 1):
            sl = rr * 0.55
            P.append(R.pb(root, f"Spandrel{i}{s:+d}", (width - 0.6, sl, under - (yc + rr * 0.55)),
                          loc(0, mid - (za + zb) / 2 + s * (rr - sl / 2 + 0.6), (under + yc + rr * 0.55) / 2 - deck_top),
                          "brick", bevel=0.04))
    # lamps on the parapets
    k = 0
    lz = za + 12.0
    while lz < zb - 6:
        side = 1 if k % 2 == 0 else -1
        P += R.lamp(root, f"Lamp{k}", side * (hw + 0.5), lz - (za + zb) / 2, z=3.8, h=7.0)
        lz += 30.0
        k += 1
    return len(P)


# ------------------------------------------------------------------ the travel preview (render only)
def _pmat(name, hexc, rough=0.7, metal=0.0, emit=0.0):
    c = srgb(hexc)
    return flat(f"Preview_{name}", c, rough=rough, metal=metal, emit=(c, emit) if emit else None)


def _pbox(c, name, size, at, mat, yaw=0.0):
    """A render-only box: region centre `at` (x, y, z), size (along x, along z, up), turned yaw (Roblox degrees)."""
    o = box(f"Preview_{name}", size, ST.bl(*at), mat, c, rot=(0, 0, math.radians(-yaw)), bevel=0.05, segs=1)
    for k in ("rs_kind", "rs_size", "rs_mat"):
        if k in o:
            del o[k]
    o["rs_skip"] = True
    return o


def travel_preview(layout, grid):
    """Stand-ins for what setup.lua builds from the RenseiMarker markers (render only). Returns the object count."""
    c = ST.clear_group(layout, "Preview")
    ST.water_preview(layout, grid)  # water_preview cleared Preview too: rebuild its slabs first
    c = ST.group(layout, "Preview")
    mk = [m for m in layout["Markers"] if m["Tag"] == "RenseiMarker"]
    by = {}
    for m in mk:
        by.setdefault(m["Attr"]["Piece"], []).append(m)
    cob = _pmat("Cobble", "7a766c")
    iron = _pmat("Iron", "3d4247", 0.45, 0.6)
    loco = _pmat("Loco", "1f2a24", 0.5, 0.4)
    coach = _pmat("Coach", "4a2a24", 0.6)
    roofm = _pmat("CoachRoof", "2d2b29", 0.7)
    wood = _pmat("Wood", "7a5a3e")
    red = _pmat("Buffer", "6e2820")
    sign = _pmat("Sign", "282220")
    crate = _pmat("Crate", "7a5c3c")
    win = _pmat("Window", "d9934a", 0.2, 0, 2.0)
    n = 0
    st = None
    for m in by.get("Station", []):
        a = m["Attr"]
        TX, RT, NZ = a["TrackX"], a["RailTop"], a["NoseZ"]
        st = (TX, RT, NZ)
        _pbox(c, "Platform", (12, 340, 2.4), (TX + 12, RT + 0.6, NZ - 275), cob)
        for s in (-1, 1):
            _pbox(c, f"Rail{s:+d}", (0.5, 500, 0.6), (TX + s * 2.6, RT - 0.3, NZ - 240), iron)
        for dzb in (-251, 251):
            _pbox(c, f"Buffer{dzb}", (7, 1.6, 2.6), (TX, RT + 1, NZ - 240 + dzb), red)
        z = 0.0
        for i, (L, mat, h) in enumerate(((72, loco, 14.0), (30, loco, 10.0)) + tuple((64, coach, 13.0) for _ in range(5))):
            cz = NZ - z - L / 2
            _pbox(c, f"Car{i}", (9.4, L - 0.5, h - 2.0), (TX, RT + 1.0 + (h - 2.0) / 2, cz), mat)
            _pbox(c, f"CarRoof{i}", (10.0, L - 0.5, 0.8), (TX, RT + h - 0.6, cz), roofm)
            if mat is coach:
                for w in range(6):
                    _pbox(c, f"CarWin{i}_{w}", (9.6, 4.0, 2.4), (TX, RT + 7.5, cz - L / 2 + 6 + w * 10.4), win)
            z += L + 3
        n += 1
    for m in by.get("Clerk", []):
        x, y, z = m["At"]
        g = PL.ground_y(grid, x, z) if y == 0 else y
        _pbox(c, "Booth", (6.4, 4.4, 7.8), (x, g + 3.9, z), wood, yaw=m.get("Yaw", 0))
        n += 1
    for m in by.get("Board", []):
        x, y, z = m["At"]
        g = PL.ground_y(grid, x, z) if y == 0 else y
        _pbox(c, "Board", (8, 0.4, 4), (x, g + 8, z), sign, yaw=m.get("Yaw", 0))
        n += 1
    for m in by.get("Gate", []):
        x, y, z = m["At"]
        g = PL.ground_y(grid, x, z) if y == 0 else y
        top = (st[1] + 1.8) if st else g + 2.4
        yaw = math.radians(m.get("Yaw", 0))
        fx, fz = -math.sin(yaw), -math.cos(yaw)  # the facing (onto the platform)
        rx, rz = -fz, fx  # its right
        for s in (-1, 1):
            _pbox(c, f"GatePost{s:+d}", (0.8, 0.8, top + 6.6 - g), (x + rx * s * 4.6, (g + top + 6.6) / 2, z + rz * s * 4.6),
                  iron)
        _pbox(c, "GateSign", (10.0, 0.4, 1.6), (x, top + 7.4, z), sign, yaw=m.get("Yaw", 0) + 0)
        _pbox(c, "GateRamp", (8.0, 6.0, top - g), (x - fx * 3.5, (g + top) / 2, z - fz * 3.5), cob, yaw=m.get("Yaw", 0))
        n += 1
    for m in by.get("Railing", []):
        runs = json.loads(m["Attr"]["Runs"])
        for i, (x1, z1, x2, z2) in enumerate(runs):
            L = math.hypot(x2 - x1, z2 - z1)
            yaw = -math.degrees(math.atan2(x2 - x1, -(z2 - z1)))  # face along the run
            top = (st[1] + 1.8) if st and abs(x1 - (st[0] + 12)) < 7 and abs(x2 - (st[0] + 12)) < 7.5 else 4.0
            base = (st[1] + 1.8) if st else 4.0
            _pbox(c, f"Rail{i}", (0.3, L, 0.3), ((x1 + x2) / 2, base + 3.0, (z1 + z2) / 2), wood, yaw=yaw)
            k = 0
            while k * 8 <= L:
                t = k * 8 / max(L, 1e-6)
                _pbox(c, f"Post{i}_{k}", (0.5, 0.5, 3.4), (x1 + (x2 - x1) * t, base + 1.7, z1 + (z2 - z1) * t), wood)
                k += 1
        n += 1
    for m in by.get("FreightYard", []):
        if st:
            TX, RT, NZ = st
            bz = NZ - 72 - 3 - 30 - 3 - 32  # the baggage car's middle
            g = PL.ground_y(grid, TX - 13, bz)
            for i, dz_ in enumerate((-30, -18, -6, 8, 22, 34)):
                h = 3.0 if i % 2 else 6.0
                _pbox(c, f"YardCrate{i}", (3.0, 3.0, h), (TX - 14 - (i % 3) * 3.2, g + h / 2, bz + dz_), crate)
            for i in range(12):
                _pbox(c, f"YardFence{i}", (0.4, 7.6, 3.0), (TX - 22, g + 1.5, bz - 44 + i * 8.0), wood)
        n += 1
    return n

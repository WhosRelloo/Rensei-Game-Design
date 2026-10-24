"""Foundry Yard's own set pieces (owner-approved layout, 2026-10-24): the landmarks only Foundry Yard has, built in the
rail-town style with the rail-town kit's primitives and palette (railtown.pb / pc / pw / lamp / light / window / door).
Its districts still use railtown's buildings; this kit has no building styles.

Landmarks, (root, rng) -> [parts]:
  great_hall      the foundry works' great hall (200 x 110): a casting floor with furnaces, gantries and a stair, and a
                  forge wing holding the two forge-room shells for the Silent Forge and the Forge Floor (owner,
                  2026-10-24: "Foundry-style shells"; the trial markers, minigame targets and the alchemist spawn move
                  in from Ye at import);
  ticket_hall     the station's booking hall: a through hall with open arcades front and back and an iron canopy over
                  the concourse where the ticket booth and the papers gate stand (setup.lua builds those);
  platform_canopy an iron canopy on posts along the platform's back half; no post where the gate or the departure
                  board stand (GATE_AT, BOARD_AT, offsets along the canopy);
  road_gate       the south road's gate: brick piers, an iron arch and a name board;
  gatehouse       the shut gatehouse at the north end of the viaduct (owner, 2026-10-24: "Shut gatehouse, solid wall");
  shift_office    the yard's shift office beside the practice court, with the ledger lectern outside (the clue);
  signal_gantry   an iron signal bridge over both tracks on two towers, 24 up, with a ladder: the high tier above the
                  rail walks;
  wagon           a box wagon on a siding: cover, climbable sides, a roof to run along;
  water_tower     a yard water tower: climbable legs, a ladder and a lookout deck at 20;
  yard_wall       a 60-long, 12-tall brick yard wall: a wall-run line with a ledge strip and a coping (in pairs, a
                  wall-run corridor).

The viaduct is not a landmark (a landmark is settled on the highest ground under it with a footing filled down to the
lowest, which would fill the cut it spans); extras.py builds it from the layout's Viaduct marker.

Frames and conventions are railtown's: the root's LOCAL frame, origin at the footprint's middle at floor level, +z up,
the FRONT faces local -y (the Roblox LookVector). 1 unit = 1 stud. Every size here is a PROPOSAL."""
import math

from .. import kitspec
from . import railtown as R
from .railtown import pb, pc, pw, lamp, light, window, door, attr, ledge, _on, _sz

M = R.M  # the shared palette (railtown.bind fills it)
CLIMB_NOTE = R.CLIMB_NOTE


def bind(palette):
    R.bind(palette)


# ------------------------------------------------------------------ the great hall
GH_W, GH_D, GH_H, GH_T = 200.0, 110.0, 30.0, 2.0  # PROPOSAL
FORGE_ROOMS = {  # local rects [x0, y0, x1, y1] inside the forge wing, and what each is kept for
    "SilentForge": ((6.0, -2.0, 48.0, 51.0), "Silent Forge"),
    "ForgeFloor": ((54.0, -2.0, 96.0, 51.0), "Forge Floor"),
}
ROOM_WALL = (1.6, 12.0)  # thickness, height (PROPOSAL)
ROOM_DOOR = (8.0, 9.0)  # width, height of each room's doorway onto the wing's corridor (PROPOSAL)


def great_hall(root, rng):
    """The great hall: a 200 x 110 brick hall, 30 tall, sawtooth roof glazed to the front, two big stacks behind.

    West half (local x < 0): the casting floor: a 22-wide main doorway, three furnaces with ember mouths and flues on
    the back wall, a gantry along the west wall and a bridge gantry across, a stair up along the front wall.
    East half: the forge wing, behind a 14-tall brick partition with a 12-wide opening, entered by its own 14-wide
    doorway: a corridor along the front and two forge-room shells behind it (FORGE_ROOMS), each with a doorway, a
    hearth with an ember mouth, and a floor part whose Note says what it is kept for."""
    W, D, H, T = GH_W, GH_D, GH_H, GH_T
    P = [pb(root, "Floor", (W - 2 * T, D - 2 * T, 0.4), (0, 0, 0.2), "stone", bevel=0)]
    # front wall with two doorways: (centre x, width, height)
    doors = [(-50.0, 22.0, 22.0), (50.0, 14.0, 16.0)]
    x0 = -W / 2
    for i, (cx, dw, dh) in enumerate(doors):
        a, b = cx - dw / 2, cx + dw / 2
        P.append(pb(root, f"Front{i}", (a - x0, T, H), ((x0 + a) / 2, -D / 2 + T / 2, H / 2), "brick", bevel=0.08))
        P.append(pb(root, f"FrontLintel{i}", (dw, T, H - dh), (cx, -D / 2 + T / 2, dh + (H - dh) / 2), "brick",
                    bevel=0.08))
        P.append(pb(root, f"DoorArch{i}", (dw + 2.4, 1.0, 1.4), (cx, -D / 2 - 0.4, dh + 0.7), "stone", bevel=0.06))
        x0 = b
    P.append(pb(root, f"Front{len(doors)}", (W / 2 - x0, T, H), ((x0 + W / 2) / 2, -D / 2 + T / 2, H / 2), "brick",
                bevel=0.08))
    P.append(pb(root, "Back", (W, T, H), (0, D / 2 - T / 2, H / 2), "brick", bevel=0.08))
    for s in (-1, 1):
        x = s * (W / 2 - T / 2)
        P.append(pb(root, f"Side{s:+d}", (T, D - 2 * T, 19.0), (x, 0, 9.5), "brick", bevel=0.08))
        P.append(pb(root, f"SideLights{s:+d}", (0.6, D - 2 * T - 1, 6.0), (x, 0, 22.0), "window", bevel=0))
        P.append(pb(root, f"SideTop{s:+d}", (T, D - 2 * T, 5.0), (x, 0, 27.5), "brick", bevel=0.08))
        for i in range(5):
            P.append(pb(root, f"Mullion{s:+d}{i}", (T + 0.2, 0.8, 6.0), (x, -D / 2 + T + (i + 1) * (D - 2 * T) / 6, 22.0),
                        "brick_dark", bevel=0.03))
    for side in "FB":  # pilasters every 25, none across a doorway
        for i in range(9):
            a = -W / 2 + i * W / 8
            if side == "F" and any(abs(a - cx) < dw / 2 + 1.5 for cx, dw, _ in doors):
                continue
            P.append(pb(root, f"Pilaster{side}{i}", _sz(side, 2.0, 0.9, H + 1.0), (*_on(side, D / 2, a, 0.45), (H + 1) / 2),
                        "brick_dark", bevel=0.06))
    P.append(pb(root, "Cornice", (W + 1.2, 1.2, 1.0), (0, -D / 2 - 0.3, H + 0.5), "brick_dark", bevel=0.06))
    # the sawtooth roof: each tooth glazed on its front face
    teeth, rise = 10, 6.0
    p = D / teeth
    ang = math.atan2(rise, p)
    for j in range(teeth):
        y0 = -D / 2 + j * p
        P.append(pb(root, f"Tooth{j}", (W + 1.0, math.hypot(p, rise), 0.6), (0, y0 + p / 2, H + rise / 2), "iron_roof",
                    rot=(-ang, 0, 0), bevel=0.04))
        P.append(pb(root, f"Glazing{j}", (W - 2 * T, 0.4, rise), (0, y0, H + rise / 2), "glass_warm", bevel=0))
        for s in (-1, 1):
            P.append(pw(root, f"ToothEnd{j}{s:+d}", (T, p, rise), (s * (W / 2 - T / 2), y0 + p / 2, H + rise / 2),
                        "brick", rot=(0, 0, math.pi)))
    # casting floor: furnaces on the back wall
    for k, x in enumerate((-82.0, -52.0, -22.0)):
        fy = D / 2 - T - 5.0
        P.append(pb(root, f"Furnace{k}", (14.0, 10.0, 16.0), (x, fy, 8.0), "brick_dark", bevel=0.12))
        P.append(pb(root, f"Mouth{k}", (6.0, 0.5, 5.0), (x, fy - 5.1, 3.3), "ember", bevel=0.05))
        P.append(pb(root, f"MouthLintel{k}", (8.0, 0.8, 1.0), (x, fy - 5.3, 6.4), "iron", bevel=0.04))
        P.append(pc(root, f"Flue{k}", 2.2, H + 2.0, (x, fy, 16.0 + (H + 2.0) / 2), "brick_dark", verts=12))
        P.append(pc(root, f"FlueCap{k}", 2.6, 1.0, (x, fy, H + 18.5), "soot", verts=12))
        light(root, f"Ember{k}", (x, fy - 7.0, 3.5), 5000, "e0782a", 30)
    # casting floor: a gantry along the west wall, a bridge gantry across to the partition, a stair up the front wall
    gz, gx = 16.0, -W / 2 + T + 2.5
    gl = D - 2 * T
    P.append(pb(root, "GantryW", (4.0, gl, 0.6), (gx, 0, gz - 0.3), "iron", bevel=0.03))
    for i, y in enumerate((-40.0, -16.0, 8.0, 32.0)):
        P.append(pb(root, f"GantryPost{i}", (0.8, 0.8, gz - 0.6), (gx + 1.6, y, (gz - 0.6) / 2), "iron", bevel=0.03))
    by, bw = -14.0, 6.0  # the bridge: its middle (y) and width
    bx0, bx1 = gx + 2.0, -T / 2 - 1.0
    P.append(pb(root, "Bridge", (bx1 - bx0, bw, 0.6), ((bx0 + bx1) / 2, by, gz - 0.3), "iron", bevel=0.03))
    for s in (-1, 1):
        P.append(pb(root, f"BridgeRail{s:+d}", (bx1 - bx0, 0.3, 0.3), ((bx0 + bx1) / 2, by + s * (bw / 2 - 0.15), gz + 3.3),
                    "iron", bevel=0))
    for i, x in enumerate((-70.0, -40.0, -12.0)):
        P.append(pb(root, f"BridgePost{i}", (0.8, 0.8, gz - 0.6), (x, by, (gz - 0.6) / 2), "iron", bevel=0.03))
    sy, sw = -D / 2 + T + 2.5, 4.0  # the stair: up along the inside of the front wall to the west gantry
    for k in range(1, int(gz) + 1):
        P.append(pb(root, f"Stair{k}", (1.85, sw, float(k)), (gx + 2.0 + 1.8 * (int(gz) - k + 0.5), sy, k / 2), "iron",
                    bevel=0.03))
    # the partition between the casting floor and the forge wing, with a 12-wide opening at y = 0
    ph, po = 14.0, 12.0
    for s in (-1, 1):
        L = (D - 2 * T - po) / 2
        P.append(pb(root, f"Partition{s:+d}", (1.6, L, ph), (0, s * (po / 2 + L / 2), ph / 2), "brick_dark", bevel=0.06))
    P.append(pb(root, "PartitionLintel", (1.6, po, 2.0), (0, 0, ph - 1.0), "brick_dark", bevel=0.06))
    # the forge rooms: shells for the trial rooms moved in at import
    t, h = ROOM_WALL
    dw, dh = ROOM_DOOR
    for name, ((rx0, ry0, rx1, ry1), label) in FORGE_ROOMS.items():
        cx, cy = (rx0 + rx1) / 2, (ry0 + ry1) / 2
        fl = pb(root, f"{name}Floor", (rx1 - rx0 - 2 * t, ry1 - ry0 - 2 * t, 0.3), (cx, cy, 0.55),
                "cinder_dark" if name == "ForgeFloor" else "slate_roof", bevel=0)
        attr(fl, Note=f"Reserved: the {label} trial room (Brannoc's Metal path). The import moves its trial markers, "
                      "minigame targets and alchemist spawn in from Ye with the same ids.", Room=name)
        P.append(fl)
        for s in (-1, 1):  # side walls
            P.append(pb(root, f"{name}Side{s:+d}", (t, ry1 - ry0, h), (cx + s * ((rx1 - rx0) / 2 - t / 2), cy, h / 2),
                        "brick", bevel=0.06))
        P.append(pb(root, f"{name}Back", (rx1 - rx0 - 2 * t, t, h), (cx, ry1 - t / 2, h / 2), "brick", bevel=0.06))
        side_w = (rx1 - rx0 - 2 * t - dw) / 2
        for s in (-1, 1):  # front wall either side of the doorway
            P.append(pb(root, f"{name}Front{s:+d}", (side_w, t, h), (cx + s * (dw / 2 + side_w / 2), ry0 + t / 2, h / 2),
                        "brick", bevel=0.06))
        P.append(pb(root, f"{name}Lintel", (dw, t, h - dh), (cx, ry0 + t / 2, dh + (h - dh) / 2), "brick", bevel=0.06))
        hy = ry1 - t - 3.0  # the hearth against the back wall
        P.append(pb(root, f"{name}Hearth", (10.0, 5.0, 6.0), (cx, hy, 3.0), "brick_dark", bevel=0.1))
        P.append(pb(root, f"{name}HearthMouth", (5.0, 0.4, 2.6), (cx, hy - 2.6, 2.2), "ember", bevel=0.04))
        P.append(pb(root, f"{name}Anvil", (3.0, 1.6, 2.6), (cx, cy - 4.0, 1.3 + 0.7), "iron", bevel=0.06))
        light(root, f"{name}Glow", (cx, hy - 4.0, 3.0), 2500, "e0782a", 20)
    # hanging lamps along the forge wing's corridor (the rooms' hearths light only the rooms)
    for i, x in enumerate((24.0, 50.0, 76.0)):
        P.append(pb(root, f"WingChain{i}", (0.25, 0.25, 6.0), (x, -28.0, H - 3.0), "iron", bevel=0))
        P.append(pb(root, f"WingGlow{i}", (1.2, 1.2, 1.4), (x, -28.0, H - 6.7), "lamp", bevel=0.06))
        light(root, f"WingLight{i}", (x, -28.0, H - 7.6), 4000, "ffb35c", 30)
    # two big stacks behind the back wall
    for s in (-1, 1):
        x, y = s * 70.0, D / 2 + 5.0
        P.append(pb(root, f"StackBase{s:+d}", (9.0, 9.0, 8.0), (x, y, 4.0), "brick_dark", bevel=0.1))
        P.append(pc(root, f"Stack{s:+d}", 3.4, 74.0, (x, y, 8.0 + 37.0), "brick", verts=16))
        for k, f in enumerate((0.35, 0.7)):
            P.append(pc(root, f"StackBand{s:+d}{k}", 3.6, 0.8, (x, y, 8.0 + 74.0 * f), "iron", verts=16))
        P.append(pc(root, f"StackCrown{s:+d}", 3.9, 2.2, (x, y, 8.0 + 74.0 + 1.1), "soot", verts=16))
    for s in (-1, 1):
        P += lamp(root, f"Lamp{s:+d}", -50.0 + s * 15.0, -D / 2 - 2.0)
    return P


# ------------------------------------------------------------------ the station
TH_W, TH_D, TH_H = 60.0, 24.0, 14.0  # PROPOSAL
TH_CANOPY = 13.0  # how far the canopy reaches out over the concourse (PROPOSAL)


def ticket_hall(root, rng):
    """The booking hall: 60 x 24 brick, 14 tall, a slate roof; three open arches front and back, so the street walks
    through it to the concourse; a stone floor, benches, a clock and a name board; an iron canopy 13 out over the
    concourse at 11.5 (above the booth's roof and below the gate's sign)."""
    W, D, H, T = TH_W, TH_D, TH_H, 1.6
    P = [pb(root, "Floor", (W - 2 * T, D - 2 * T, 0.4), (0, 0, 0.2), "stone", bevel=0)]
    arches = (-18.0, 0.0, 18.0)
    aw, ah = 10.0, 9.0
    for side in "FB":
        y = (-1 if side == "F" else 1) * (D / 2 - T / 2)
        x0 = -W / 2
        for i, cx in enumerate(arches):
            P.append(pb(root, f"Pier{side}{i}", (cx - aw / 2 - x0, T, H), ((x0 + cx - aw / 2) / 2, y, H / 2), "brick",
                        bevel=0.06))
            P.append(pb(root, f"ArchHead{side}{i}", (aw, T, H - ah), (cx, y, ah + (H - ah) / 2), "brick", bevel=0.06))
            P.append(pb(root, f"Keystone{side}{i}", (1.6, T + 0.4, 1.6), (cx, y, ah + 0.8), "stone", bevel=0.05))
            x0 = cx + aw / 2
        P.append(pb(root, f"Pier{side}{len(arches)}", (W / 2 - x0, T, H), ((x0 + W / 2) / 2, y, H / 2), "brick",
                    bevel=0.06))
    for s in (-1, 1):
        P.append(pb(root, f"End{s:+d}", (T, D - 2 * T, H), (s * (W / 2 - T / 2), 0, H / 2), "brick", bevel=0.06))
        for i, y in enumerate((-5.0, 5.0)):
            P += window(root, f"EndWin{s:+d}{i}", "L" if s < 0 else "R", W / 2, y, 7.0)
    P.append(pb(root, "Cornice", (W + 0.8, D + 0.8, 0.8), (0, 0, H + 0.4), "brick_dark", bevel=0.06))
    rise, over = 6.0, 0.8
    half = D / 2 + over
    ang, slope = math.atan2(rise, half), math.hypot(half, rise)
    for s in (-1, 1):
        P.append(pb(root, f"Roof{'FB'[s > 0]}", (W + 1.2, slope, 0.8), (0, s * half / 2, H + 0.8 + rise / 2),
                    "slate_roof", rot=(-s * ang, 0, 0), bevel=0.06))
        ra = rise * (D / 2) / half
        for e in (-1, 1):
            P.append(pw(root, f"Gable{'FB'[s > 0]}{e:+d}", (T, D / 2, ra), (e * (W / 2 - T / 2), s * D / 4, H + 0.8 + ra / 2),
                        "brick", rot=(0, 0, 0 if s < 0 else math.pi)))
    P.append(pb(root, "Ridge", (W + 1.4, 1.0, 0.6), (0, 0, H + 0.8 + rise + 0.25), "soot", bevel=0.06))
    # the canopy over the concourse, on brackets from the front wall
    cz = 11.5
    P.append(pb(root, "Canopy", (W - 4.0, TH_CANOPY, 0.5), (0, -D / 2 - TH_CANOPY / 2, cz), "iron_roof",
                rot=(math.radians(-4), 0, 0), bevel=0.04))
    P.append(pb(root, "CanopyValance", (W - 4.0, 0.3, 1.2), (0, -D / 2 - TH_CANOPY + 0.15, cz - 0.9), "iron", bevel=0))
    for i, x in enumerate((-27.0, -9.0, 9.0, 27.0)):
        L = math.hypot(TH_CANOPY - 1.0, 4.0)
        P.append(pb(root, f"Bracket{i}", (0.4, L, 0.4), (x, -D / 2 - (TH_CANOPY - 1.0) / 2, cz - 2.2), "iron",
                    rot=(math.atan2(4.0, TH_CANOPY - 1.0), 0, 0), bevel=0))
    for i, x in enumerate((-18.0, 18.0)):
        P.append(pb(root, f"CanopyGlow{i}", (1.0, 1.0, 1.2), (x, -D / 2 - 6.0, cz - 1.2), "lamp", bevel=0.06))
        attr(P[-1], NightOnly=True)
        light(root, f"CanopyLight{i}", (x, -D / 2 - 6.0, cz - 1.6), 3000, "ffb35c", 22)
    P.append(pc(root, "Clock", 2.0, 0.5, (0, -D / 2 - 0.3, H - 1.6), "stone", rot=(math.radians(90), 0, 0), verts=16))
    P.append(pb(root, "ClockHands", (0.3, 0.2, 1.6), (0, -D / 2 - 0.6, H - 1.3), "soot", bevel=0))
    P.append(pb(root, "NameBoard", (16.0, 0.4, 1.6), (0, D / 2 + 0.25, ah + 2.4), "timber", bevel=0.05))
    for i, x in enumerate((-22.0, 22.0)):
        P.append(pb(root, f"Bench{i}", (8.0, 1.6, 1.8), (x, 4.0, 0.9 + 0.4), "timber", bevel=0.05))
    return P


GATE_AT, BOARD_AT = 87.0, 105.0  # PROPOSAL: along the canopy (local +y), where the papers gate and the board stand
CANOPY_LEN = 320.0


def platform_canopy(root, rng):
    """A canopy over the platform's back half: posts 30 apart on the platform (local x +3, which is the track's x +15:
    clear of a coach's side and its steps), a gently sloped iron roof from local x -5.5 to +6.5, a valance and NightOnly
    lamps under it. The posts stand on the platform top (local z 2.4: the platform is 1.8 above the rail top, which is
    0.6 above the ground). No post within 10 of the gate (GATE_AT) or 8 of the board (BOARD_AT)."""
    top = 2.4  # the platform top over the ground (setup.lua: RailTop + 1.8, RailTop = ground + 0.6)
    ph = 13.0
    L = CANOPY_LEN
    P = []
    ys = [-150.0 + 30.0 * i for i in range(11)]
    ys = [y for y in ys if abs(y - GATE_AT) >= 10.0 and abs(y - BOARD_AT) >= 8.0]
    for i, y in enumerate(ys):
        P.append(pb(root, f"Post{i}", (0.8, 0.8, ph), (3.0, y, top + ph / 2), "iron", bevel=0.04))
        P.append(pb(root, f"PostFoot{i}", (1.4, 1.4, 0.6), (3.0, y, top + 0.3), "stone", bevel=0.05))
        arm = math.hypot(7.0, 3.0)
        P.append(pb(root, f"Arm{i}", (arm, 0.4, 0.4), (3.0 - 3.5, y, top + ph - 1.5), "iron",
                    rot=(0, math.atan2(3.0, 7.0), 0), bevel=0))
        g = pb(root, f"Glow{i}", (0.8, 0.8, 1.0), (0.0, y, top + ph - 2.6), "lamp", bevel=0.05)
        attr(g, NightOnly=True)
        P.append(g)
        light(root, f"Light{i}", (0.0, y, top + ph - 3.0), 2200, "ffb35c", 18)
    tilt = math.radians(4)
    P.append(pb(root, "Roof", (12.0, L, 0.5), (0.5, 0, top + ph + 0.4), "iron_roof", rot=(0, tilt, 0), bevel=0.04))
    P.append(pb(root, "Beam", (0.8, L, 1.0), (3.0, 0, top + ph - 0.3), "iron", bevel=0.03))
    P.append(pb(root, "Valance", (0.3, L, 1.4), (-5.4, 0, top + ph - 0.2), "iron", bevel=0))
    return P


# ------------------------------------------------------------------ the roads
def road_gate(root, rng):
    """The south road's gate: two brick piers 18 apart (a 15-wide way through), an iron arch beam with a name board,
    NightOnly lamps on the piers."""
    P = []
    for s in (-1, 1):
        x = s * 9.0
        P.append(pb(root, f"Pier{s:+d}", (3.0, 3.0, 14.0), (x, 0, 7.0), "brick", bevel=0.08))
        P.append(pb(root, f"PierCap{s:+d}", (3.6, 3.6, 0.6), (x, 0, 14.3), "stone", bevel=0.06))
        P += lamp(root, f"Lamp{s:+d}", x, 0, z=14.6, h=2.0, energy=3000, rng=20)
    P.append(pb(root, "Beam", (21.0, 1.0, 1.2), (0, 0, 13.0), "iron", bevel=0.04))
    P.append(pb(root, "Board", (11.0, 0.4, 2.0), (0, -0.7, 11.2), "timber", bevel=0.05))
    for s in (-1, 1):
        P.append(pb(root, f"Hanger{s:+d}", (0.25, 0.25, 0.8), (s * 4.5, -0.7, 12.4), "iron", bevel=0))
    return P


def gatehouse(root, rng):
    """The shut north gatehouse at the viaduct's end: two brick towers either side of the 16-wide road, an arch over
    it with a name board, and a shut iron gate of bars and rails (the road toward Central City is closed until that
    region exists). Front (local -y) faces the town."""
    P = []
    for s in (-1, 1):
        x = s * 13.0
        P.append(pb(root, f"Tower{s:+d}", (10.0, 10.0, 26.0), (x, 0, 13.0), "brick", bevel=0.1))
        P.append(pb(root, f"TowerCap{s:+d}", (11.0, 11.0, 1.0), (x, 0, 26.5), "stone", bevel=0.08))
        for k in range(3):
            P.append(pb(root, f"Merlon{s:+d}{k}", (2.4, 11.0, 2.2), (x + (k - 1) * 3.8, 0, 28.1), "brick_dark", bevel=0.06))
        P += window(root, f"Slit{s:+d}", "F", 5.0, x, 18.0, w=1.2, h=4.0, o=(0, 0))
    P.append(pb(root, "Arch", (16.0, 8.0, 6.0), (0, 0, 21.0), "brick", bevel=0.08))
    P.append(pb(root, "ArchStone", (17.0, 8.6, 1.0), (0, 0, 17.6), "stone", bevel=0.06))
    P.append(pb(root, "Board", (12.0, 0.4, 2.2), (0, -4.3, 21.0), "timber", bevel=0.05))
    for i in range(9):  # the shut gate: bars
        P.append(pb(root, f"Bar{i}", (0.5, 0.5, 17.0), (-7.2 + i * 1.8, 1.0, 8.5), "iron", bevel=0))
    for k, z in enumerate((2.0, 9.0, 16.0)):
        P.append(pb(root, f"GateRail{k}", (16.0, 0.7, 0.8), (0, 1.0, z), "iron", bevel=0.03))
    P.append(pb(root, "Lock", (1.2, 0.8, 1.6), (0, 0.4, 8.0), "rust", bevel=0.05))
    for s in (-1, 1):
        P += lamp(root, f"Lamp{s:+d}", s * 7.2, -6.0, h=8.0)
    return P


def shift_office(root, rng):
    """The shift office: a one-storey brick office (14 x 10, iron roof) with a door, a window and, outside to the front
    right, the ledger lectern where the shift-ledger clue stands (the RenseiClue marker sits in front of it)."""
    w, d = 14.0, 10.0
    P, dx = R._block(root, rng, w, d, 1, sh=9.0, roof="iron", door_x=-3.5, bay=7.0, back_door=False, chimneys=1,
                     ledges=False)
    root["rs_door_x"] = dx
    P.append(pb(root, "Lectern", (1.6, 1.2, 3.6), (5.0, -d / 2 - 2.6, 1.8), "timber", bevel=0.05))
    P.append(pb(root, "LecternTop", (2.4, 1.8, 0.3), (5.0, -d / 2 - 2.6, 3.75), "timber", rot=(math.radians(-15), 0, 0),
                bevel=0.03))
    P.append(pb(root, "Ledger", (1.6, 1.1, 0.3), (5.0, -d / 2 - 2.65, 4.0), "brick_dark", rot=(math.radians(-15), 0, 0),
                bevel=0.03))
    P.append(pb(root, "Board", (6.0, 0.3, 1.2), (dx, -d / 2 - 0.2, 8.0), "timber", bevel=0.03))
    return P


# ------------------------------------------------------------------ the rail corridor
def signal_gantry(root, rng):
    """A signal bridge over both tracks: two iron towers 68 apart (local y), a walkable 3.4-wide deck at 24 with
    handrails, signal heads hanging over each track, ladder rungs up the -y tower's front face."""
    span, top = 68.0, 24.0
    P = []
    for s in (-1, 1):
        y = s * span / 2
        for t in (-1, 1):
            leg = pb(root, f"Leg{s:+d}{t:+d}", (1.0, 1.0, top), (t * 1.4, y, top / 2), "iron", bevel=0.03)
            attr(leg, Note=CLIMB_NOTE)
            P.append(leg)
        for k, z in enumerate((6.0, 12.0, 18.0)):
            P.append(pb(root, f"Tie{s:+d}{k}", (3.8, 0.6, 0.6), (0, y, z), "iron", bevel=0))
        P.append(pb(root, f"Foot{s:+d}", (4.4, 2.6, 0.6), (0, y, 0.3), "stone", bevel=0.05))
    P.append(pb(root, "Deck", (3.4, span + 3.0, 0.6), (0, 0, top + 0.3), "iron", bevel=0.03))
    for s in (-1, 1):
        P.append(pb(root, f"Girder{s:+d}", (0.4, span + 3.0, 2.0), (s * 1.9, 0, top - 0.6), "iron", bevel=0.03))
        P.append(pb(root, f"Handrail{s:+d}", (0.25, span + 3.0, 0.25), (s * 1.6, 0, top + 3.6), "iron", bevel=0))
        for i in range(5):
            P.append(pb(root, f"Stanchion{s:+d}{i}", (0.25, 0.25, 3.0), (s * 1.6, -span / 2 + i * span / 4, top + 2.1),
                        "iron", bevel=0))
    for j, y in enumerate((-12.0, 12.0)):  # the signal heads over the tracks (the layout puts the tracks 12 off centre)
        P.append(pb(root, f"Head{j}", (1.4, 1.2, 4.0), (0, y, top - 3.6), "soot", bevel=0.05))
        g = pb(root, f"Lens{j}", (0.8, 0.3, 0.8), (0, y - 0.7, top - 2.6), "lamp", bevel=0.04)
        P.append(g)
    for i in range(10):
        P.append(pb(root, f"Rung{i}", (1.8, 0.3, 0.3), (0, -span / 2 - 0.65, 2.5 + i * 2.2), "iron", bevel=0))
    return P


# ------------------------------------------------------------------ yard pieces for movement and combat (owner, 2026-10-24:
# "Fill the empty east first, and remember to place things for the movement and combat we currently have in game")
def wagon(root, rng):
    """A box wagon standing on a siding (local x along the track): two bogies on the rails (their bottoms at the rail
    top, 0.9 over the ground), a plank body with sliding doors on both sides, a flat roof to run along, buffers and
    an end ladder. Cover to crouch behind, sides to climb and wall-run, a roof to mantle onto, and gaps between
    wagons to slip through."""
    L, W, base = 28.0, 9.0, 2.5
    body = rng.choice(("timber", "rust", "brick_dark"))
    P = []
    for s in (-1, 1):
        P.append(pb(root, f"Bogie{s:+d}", (6.0, 6.4, 1.6), (s * 9.0, 0, 1.7), "iron", bevel=0.06))
        P.append(pb(root, f"Buffer{s:+d}", (0.8, W - 1.0, 1.0), (s * (L / 2 + 0.4), 0, base + 1.2), "iron", bevel=0.04))
    P.append(pb(root, "Frame", (L, W - 1.2, 0.8), (0, 0, base + 0.4), "iron", bevel=0.04))
    b = pb(root, "Body", (L - 0.4, W, 8.0), (0, 0, base + 0.8 + 4.0), body, bevel=0.08)
    attr(b, Note=CLIMB_NOTE)
    P.append(b)
    P.append(pb(root, "Roof", (L + 0.4, W + 0.6, 0.6), (0, 0, base + 9.1), "iron_roof", bevel=0.05))
    for s in (-1, 1):
        P.append(pb(root, f"Door{s:+d}", (7.0, 0.3, 6.6), (rng.uniform(-4, 4), s * (W / 2 + 0.15), base + 4.3), "soot",
                    bevel=0.03))
        P.append(pb(root, f"DoorRail{s:+d}", (L - 4.0, 0.3, 0.3), (0, s * (W / 2 + 0.2), base + 7.9), "iron", bevel=0))
    P.append(pb(root, "Ladder", (0.4, 2.4, 8.2), (L / 2 + 0.2, 0, base + 4.9), "iron", bevel=0))
    return P


def water_tower(root, rng):
    """A yard water tower: four iron legs (climbable) and ties, a ladder up one leg, a walkable deck at 20 with a
    rail, the tank, its cap and a swinging spout. A lookout over the yards."""
    P = []
    top = 20.0
    for i, (x, y) in enumerate(((-4, -4), (4, -4), (-4, 4), (4, 4))):
        leg = pb(root, f"Leg{i}", (1.0, 1.0, top), (x, y, top / 2), "iron", bevel=0.03)
        attr(leg, Note=CLIMB_NOTE)
        P.append(leg)
        P.append(pb(root, f"Foot{i}", (2.0, 2.0, 0.6), (x, y, 0.3), "stone", bevel=0.05))
    for k, z in enumerate((7.0, 14.0)):
        P.append(pb(root, f"TieX{k}", (9.0, 0.5, 0.5), (0, -4, z), "iron", bevel=0))
        P.append(pb(root, f"TieY{k}", (0.5, 9.0, 0.5), (4, 0, z), "iron", bevel=0))
    for i in range(8):
        P.append(pb(root, f"Rung{i}", (1.6, 0.3, 0.3), (-4, -4.65, 2.0 + i * 2.3), "iron", bevel=0))
    P.append(pb(root, "Deck", (13.0, 13.0, 0.5), (0, 0, top + 0.25), "timber", bevel=0.04))
    for s in (-1, 1):
        P.append(pb(root, f"RailX{s:+d}", (13.0, 0.25, 0.25), (0, s * 6.4, top + 3.4), "iron", bevel=0))
        P.append(pb(root, f"RailY{s:+d}", (0.25, 13.0, 0.25), (s * 6.4, 0, top + 3.4), "iron", bevel=0))
    P.append(pc(root, "Tank", 5.0, 9.0, (0, 0, top + 0.5 + 4.5), rng.choice(("timber", "rust")), verts=14))
    P.append(pc(root, "Band", 5.15, 0.5, (0, 0, top + 3.0), "iron", verts=14))
    P.append(pc(root, "Cap", 5.4, 1.0, (0, 0, top + 10.0), "soot", verts=14))
    P.append(pb(root, "Spout", (0.9, 6.0, 0.9), (0, -7.5, top + 3.5), "iron", rot=(math.radians(-25), 0, 0), bevel=0))
    return P


def yard_wall(root, rng):
    """A tall brick yard wall, 60 long and 12 high (local x), with a stone coping to mantle onto, buttresses on its
    back (+y) and a RenseiLedge strip along its front face at 6: a wall-run line, a climb, a ledge walk and hard
    cover. Two set 12 apart make a wall-run corridor to chain kicks along."""
    Lw, T, H = 60.0, 1.6, 12.0
    P = []
    w = pb(root, "Wall", (Lw, T, H), (0, 0, H / 2), rng.choice(("brick", "brick_dark")), bevel=0.06)
    attr(w, Note=CLIMB_NOTE)
    P.append(w)
    P.append(pb(root, "Coping", (Lw + 0.4, T + 0.6, 0.6), (0, 0, H + 0.3), "stone", bevel=0.05))
    P.append(pb(root, "Plinth", (Lw + 0.4, T + 0.8, 0.8), (0, 0, 0.4), "stone", bevel=0.05))
    for i, x in enumerate((-22.0, 0.0, 22.0)):
        P.append(pb(root, f"Buttress{i}", (2.0, 2.4, 8.0), (x, T / 2 + 1.2, 4.0), "brick_dark", bevel=0.06))
    P.append(ledge(root, "Ledge", (0, -T / 2, 6.0), Lw - 4.0, (0, 1)))
    return P


# ------------------------------------------------------------------ the kit's tables (data from kitspec.py)
_SPEC = kitspec.KITS["foundry"]
_FN = {"great_hall": great_hall, "ticket_hall": ticket_hall, "platform_canopy": platform_canopy,
       "road_gate": road_gate, "gatehouse": gatehouse, "shift_office": shift_office, "signal_gantry": signal_gantry,
       "wagon": wagon, "water_tower": water_tower, "yard_wall": yard_wall}
STYLES = {}
LANDMARKS = {k: (v["kind"], _FN[k], v["foot"]) for k, v in _SPEC["landmarks"].items()}
COVER = R.COVER
LAMP_FOOT = R.LAMP_FOOT
cover = R.cover

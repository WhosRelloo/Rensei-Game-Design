"""The animated menu preview (owner 2026-10-28: "make the menu animated, with animated background, ambiance").

Run through menu_scene.py, which builds the scene and then runs this file in its own namespace:
    blender -b --factory-startup -P Art/MainMenu/menu_scene.py -- --anim --out E:/Rensei/Renders/MainMenu/anim --samples 16 [--frames 0-275]

Timeline (24 fps):
- frames 0-191, the menu idling (an 8 s loop): embers rising, the reaction crackling over the platform circle, smoke
  drifting over the town and rising from the stacks, the lantern swaying and flickering, the Mezarath circle pulsing,
  a train crossing the viaduct, the characters breathing, the camera's slow sway;
- frames 192-251, the click on the empty slot: the reaction surges and the camera pans into its alcove
  (the creator's BODY view, character right of centre where the panel leaves room);
- frames 252-275, holding there.
Writes OUT/frames/f_NNNN.png (painted) and OUT/timeline.json (for compose_anim.py: where the pan starts and ends).
In game the same motions are Roblox ParticleEmitters, Beams, TweenService and the camera script (the spec, §2 and §4).
"""
import json

FPS = 24
LOOP, PAN, HOLD = 192, 84, 24  # the pan: 3.5 s (owner: "smoother and a little slower")
TOTAL = LOOP + PAN + HOLD
os.makedirs(os.path.join(OUT, "frames"), exist_ok=True)
scene.render.resolution_x, scene.render.resolution_y = 1280, 720
scene.render.resolution_percentage = 100
scene.render.fps = FPS
for n in scene.compositing_node_group.nodes:  # the paint-over's brush size follows the resolution
	if n.bl_idname == "CompositorNodeKuwahara":
		n.inputs["Size"].default_value = 4
	if n.bl_idname == "CompositorNodeOutputFile":
		n.mute = True


def wave(t, period, phase=0.0):
	return math.sin(2 * math.pi * t / period + phase)


def flicker(t, seed):
	"""A lamp's unsteady flame: a few incommensurate sines, roughly -1..1."""
	return 0.5 * math.sin(t * 7.3 + seed) + 0.3 * math.sin(t * 13.1 + seed * 2.1) + 0.2 * math.sin(t * 29.7 + seed * 3.7)


def ease(p):
	p = min(max(p, 0.0), 1.0)
	return p * p * (3 - 2 * p)


def ease5(p):
	"""Smootherstep: no jolt at either end (zero speed and zero acceleration)."""
	p = min(max(p, 0.0), 1.0)
	return p * p * p * (p * (p * 6 - 15) + 10)


def sway(t):
	return Vector((0.035 * wave(t, 8), 0.02 * wave(t, 8, 1.3), 0.015 * wave(t, 4)))


def pivot(name, loc, prefixes):
	"""An empty at loc, parented over every object whose name starts with one of prefixes (keeping transforms)."""
	e = bpy.data.objects.new(name, None)
	e.location = loc
	col.objects.link(e)
	bpy.context.view_layer.update()
	for o in list(col.objects):
		if o is not e and o.parent is None and any(o.name.startswith(p) for p in prefixes):
			mw = o.matrix_world.copy()
			o.parent = e
			o.matrix_parent_inverse = e.matrix_world.inverted()
			o.matrix_world = mw
	return e


# ---------- what moves ----------
lan = pivot("LanternPivot", (lx, ly, 6.0), ("Lantern",))
train = pivot("TrainRig", (0, 0, 0), ("Carriage", "TrainWindow", "Engine", "Headlamp"))
lamp = bpy.data.objects["Lantern"]
niche_lamps = [o for o in col.objects if o.name.startswith("NicheLamp")]
glow = bpy.data.objects["ReactionGlow"]
niche_glow = bpy.data.objects.get("NicheArcGlow")
slots = [bpy.data.objects[n] for n in ("Slot1", "Slot2", "Slot3") if n in bpy.data.objects]
BASE = {}  # each slot's posed rotations, which the breathing adds to
for arm in slots:
	for b in ("Upper", "Head"):
		pb = arm.pose.bones[b]
		e = pb.rotation_quaternion.to_euler() if pb.rotation_mode == "QUATERNION" else pb.rotation_euler.copy()
		pb.rotation_mode = "XYZ"
		pb.rotation_euler = e
		BASE[arm.name, b] = e.copy()

# smoke that drifts: a Mapping node in front of each volume's noise, its offset moved per frame. The noise works in
# metres (object coordinates), so each gets a feature size to match its box: haze ~3 m, smog banks ~25 m, plumes ~5 m.
drift = []
for m in bpy.data.materials:
	kind = next((k for k in ("Haze", "Smog", "Plume") if m.name.startswith(k)), None)
	if not kind or not m.node_tree:
		continue
	nt = m.node_tree
	nz = next(n for n in nt.nodes if n.bl_idname == "ShaderNodeTexNoise")
	nz.inputs["Scale"].default_value = {"Haze": 0.33, "Smog": 0.045, "Plume": 0.2}[kind]
	link = next(l for l in nt.links if l.to_socket == nz.inputs["Vector"])
	src = link.from_socket
	nt.links.remove(link)
	mp = nt.nodes.new("ShaderNodeMapping")
	nt.links.new(src, mp.inputs["Vector"])
	nt.links.new(mp.outputs["Vector"], nz.inputs["Vector"])
	# metres per second the pattern moves (+z offset = the smoke sinks, so rising smoke uses -z)
	drift.append((mp, {"Haze": (0.12, 0.0, -0.05), "Smog": (-1.6, 0.0, -0.2), "Plume": (-0.9, 0.0, -2.2)}[kind]))


def emission(name):
	m = bpy.data.materials.get(name)
	return m.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"] if m else None


ancient_em = emission("AncientCircle")
chalk_em = emission("ChalkCircle")
ANCIENT0 = ancient_em.default_value if ancient_em else 0
CHALK0 = chalk_em.default_value if chalk_em else 0
GLOW0, LAMP0 = glow.data.energy, lamp.data.energy
NICHE0 = [o.data.energy for o in niche_lamps]

# the reaction: rebuilt every two frames (new jags each time), more of it once the slot is picked
EMPTY_X = NICHE_X[STATES.index("Empty")]


def reaction(seed, surge):
	for o in [o for o in col.objects if o.name.startswith(("Arc", "NicheArc")) and o.type == "CURVE"]:
		bpy.data.objects.remove(o, do_unlink=True)
	r = random.Random(seed)
	for k in range(9 + int(surge * 10)):
		a0 = r.uniform(0, 2 * math.pi)
		r0, r1 = r.choice([(1.38, 1.38), (1.1, 1.38), (0.6, 1.1)])
		a1 = a0 + r.uniform(0.4, 1.1)
		bolt(f"Arc{k}", (CX + math.cos(a0) * r0, CY + math.sin(a0) * r0, 0.02), (CX + math.cos(a1) * r1, CY + math.sin(a1) * r1, 0.02),
			M["arc"], 0.35, 6, 0.006, seed=r.randrange(1 << 30))
	for k in range(r.randint(1, 3) + int(surge * 2)):
		a0 = r.uniform(0, 2 * math.pi)
		p0 = (CX + math.cos(a0) * 1.3, CY + math.sin(a0) * 1.3, 0.02)
		bolt(f"ArcUp{k}", p0, (p0[0] + r.uniform(-0.3, 0.3), p0[1], r.uniform(0.3, 0.7 + 0.3 * surge)), M["arc"], 0.3, 5, 0.005, seed=r.randrange(1 << 30))
	fy = WALL_Y + 0.3
	for n in range(4 + int(surge * 8)):
		a0 = r.uniform(0, 2 * math.pi)
		a1 = a0 + r.uniform(0.6, 1.4)
		hz = 0.28 + (r.uniform(0, 0.9) * surge if n % 3 == 0 else 0)
		bolt(f"NicheArc{n}", (EMPTY_X + math.cos(a0) * 0.46, fy + math.sin(a0) * 0.46, 0.28),
			(EMPTY_X + math.cos(a1) * 0.46, fy + math.sin(a1) * 0.46, hz), M["arc"], 0.3, 5, 0.004, seed=r.randrange(1 << 30))
	return r.uniform(0.55, 1.4)


# ---------- the camera: the menu view, and the slot's BODY view to pan to ----------
cam.rotation_mode = "QUATERNION"
S_LOC = Vector((0.8, 0.0, 1.7))
S_ROT = (cam.matrix_world.to_quaternion())
look = Vector((EMPTY_X - 0.6, WALL_Y + 0.3, 1.12))
E_LOC = Vector((EMPTY_X - 0.75, WALL_Y - 5.2, 1.3))  # a full-body shot, the creator panel's room on the left
E_ROT = (look - E_LOC).to_track_quat("-Z", "Y")
# a cubic curve: it eases forward out of the menu view, rises a little, and settles into the alcove from slightly above
C1 = S_LOC + Vector((0.15, 1.6, 0.3))
C2 = E_LOC + Vector((-0.1, -1.4, 0.32))
S_LENS, E_LENS = cd.lens, 33.0
S_SHIFT, S_FOCUS, S_STOP = cd.shift_y, cd.dof.focus_distance, cd.dof.aperture_fstop
E_FOCUS = (Vector((EMPTY_X, WALL_Y + 0.3, 1.1)) - E_LOC).length


def place_camera(f):
	t = f / FPS
	if f < LOOP:
		cam.location = S_LOC + sway(t)
		cam.rotation_quaternion = S_ROT
		cd.lens, cd.shift_y, cd.dof.focus_distance, cd.dof.aperture_fstop = S_LENS, S_SHIFT, S_FOCUS, S_STOP
		return 0.0
	p = ease5((f - LOOP) / PAN)
	u = 1 - p
	# the idle sway carries on and fades out through the pan, so there's no kink where the pan starts
	cam.location = S_LOC * u ** 3 + C1 * 3 * u * u * p + C2 * 3 * u * p * p + E_LOC * p ** 3 + sway(t) * (1 - ease((f - LOOP) / (PAN * 0.6)))
	cam.rotation_quaternion = S_ROT.slerp(E_ROT, p)
	cd.lens = S_LENS + (E_LENS - S_LENS) * p
	cd.shift_y = S_SHIFT * u
	cd.dof.focus_distance = S_FOCUS + (E_FOCUS - S_FOCUS) * p
	cd.dof.aperture_fstop = S_STOP + (2.0 - S_STOP) * p
	return min(max((f - LOOP) / PAN, 0.0), 1.0)


def animate(f):
	t = f / FPS
	surge_raw = place_camera(f)
	surge = ease(surge_raw) if f >= LOOP else 0.0
	lan.rotation_euler = (0.05 * wave(t, 4), 0.03 * wave(t, 8, 1.0), 0)
	lamp.data.energy = LAMP0 * (1 + 0.12 * flicker(t, 1.0))
	for o, e0, k in zip(niche_lamps, NICHE0, range(99)):
		o.data.energy = e0 * (1 + 0.05 * flicker(t, 3.0 + k))
	train.location.x = -95 + 150 * (t / (LOOP / FPS))
	for mp, v in drift:
		mp.inputs["Location"].default_value = (v[0] * t, v[1] * t, v[2] * t)
	if ancient_em:
		ancient_em.default_value = ANCIENT0 * (0.7 + 0.3 * wave(t, 4))
	if chalk_em:
		chalk_em.default_value = CHALK0 * (1 + 3.5 * surge)
	if f % 2 == 0:
		k = reaction(f // 2 + 7, surge)
		glow.data.energy = GLOW0 * k * (1 + 2.5 * surge)
		if niche_glow:
			niche_glow.data.energy = 8 * k * (1 + 6 * surge)
	for i, arm in enumerate(slots):
		u, h = BASE[arm.name, "Upper"], BASE[arm.name, "Head"]
		arm.pose.bones["Upper"].rotation_euler = (u.x + 0.018 * wave(t, 4, i * 1.7), u.y, u.z)
		arm.pose.bones["Head"].rotation_euler = (h.x, h.y, h.z + 0.05 * wave(t, 8, i * 2.3))
	return surge


def wanted():
	if not FRAMES:
		return list(range(TOTAL))
	out = []
	for part in FRAMES.split(","):
		a, _, b = part.partition("-")
		out += list(range(int(a), int(b) + 1)) if b else [int(a)]
	return out


frames = wanted()
for f in range(-200, frames[0], 4):  # the embers' simulation, run up to the first frame
	scene.frame_set(f)
for f in frames:
	scene.frame_set(f)
	animate(f)
	scene.render.filepath = os.path.join(OUT, "frames", f"f_{f:04d}.png")
	bpy.ops.render.render(write_still=True, scene=scene.name)
	print("RENSEI_FRAME", f, flush=True)
with open(os.path.join(OUT, "timeline.json"), "w") as fh:
	json.dump({"fps": FPS, "loop": LOOP, "pan": PAN, "hold": HOLD, "total": TOTAL}, fh)

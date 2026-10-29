"""Export the menu diorama for Roblox (run through menu_scene.py, in its namespace):
    blender -b --factory-startup -P Art/MainMenu/menu_scene.py -- --export [--out E:/Rensei/Renders/MainMenu/upload]

Writes:
- Art/Studio/MainMenu/painted_stage.json: what Art/Studio/MainMenu/build_stage.py turns into Workspace.PaintedStage:
  parts, lights, decals, and the markers the client uses (each slot's alcove, the cameras, the pan, the lantern,
  the reaction circles, the ember and smoke sources, the train's run).
- OUT/backdrop_full.png: the far view (sky, smoke, the Mezarath circle, the town, the viaduct) painted, 3072 x 1024,
  rendered from a camera that matches Roblox's (no lens shift: pitched up instead). build_stage.py cuts it into three
  1024 x 1024 tiles (Roblox's image limit). The 3D parts stand in front of it in game.

Axes: Roblox = ORIGIN + S * (x, z, -y) (a rotation, not a mirror: Blender +Y away from the camera = Roblox -Z,
where a Roblox camera looks). S = 2.7 studs a metre (an R6, 5 studs, is the scene's 1.85 m figure).
Rows: parts [name, shape (0 Block, 1 Cylinder, 2 Ball), material, colour hex, sx, sy, sz, X, Y, Z, qx, qy, qz, qw,
group]; Roblox cylinders run along local X (Blender's along local Z: R @ Ry(-90)).
"""
import json

from mathutils import Matrix

S = 2.7
ORIGIN = Vector((0.0, 50.0, -600.0))  # where PaintedStage sits in the place (clear of the old stage and the forest)
FAR_Y = 45.0  # Blender y beyond this is the painted backdrop (the train apart)
M3 = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))  # Blender -> Roblox basis
CYL_FIX = Matrix.Rotation(math.radians(-90), 4, "Y")
STUDIO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Studio", "MainMenu"))
os.makedirs(STUDIO, exist_ok=True)


def rpos(v):
	v = Vector(v)
	return ORIGIN + S * Vector((v.x, v.z, -v.y))


def rdir(v):
	v = Vector(v)
	return Vector((v.x, v.z, -v.y)).normalized()


def r3(v, n=3):
	return [round(float(c), n) for c in v]


def srgb(c):
	return [max(0, min(255, round(255 * (12.92 * x if x <= 0.0031308 else 1.055 * x ** (1 / 2.4) - 0.055)))) for x in c[:3]]


def hexc(rgb):
	return "%02x%02x%02x" % tuple(rgb)


# Blender material -> Roblox material (the colour comes from the Blender base colour unless given)
MATS = {
	# (the baked materials: "Base:Variant", the variant being Roblox's copy of the Blender material, menu_bake.py; its
	# colour map carries the colour, so these parts are white under it)
	"WallStone": ("Brick:RenseiWallStone", (255, 255, 255)), "Flagstones": ("Slate:RenseiFlagstones", (255, 255, 255)),
	"StatueStone": ("Slate:RenseiStatueStone", (255, 255, 255)),
	"Iron": ("Metal:RenseiIron", (255, 255, 255)), "RustIron": ("CorrodedMetal:RenseiRustIron", (255, 255, 255)), "Brass": ("Metal", (150, 112, 56)),
	"GoldBraid": ("Metal", (186, 148, 70)), "Steel": ("Metal", (170, 174, 182)), "Leather": ("Leather", None),
	"Bulb": ("Neon", (255, 196, 130)), "LanternGlass": ("Neon", (255, 170, 96)), "Window": ("Neon", (255, 150, 70)),
	"Train": ("Metal", (40, 32, 28)), "PhilosophersStone": ("Basalt", (92, 22, 18)), "DustSheet": ("Fabric", None),
}
IMAGE_MATS = {"Banner": "banner", "ClockFace": "clock", "StationSign": "sign", "ChalkCircle": "chalk_circle"}
SKIP_PREFIX = ("HallHaze", "SmokeBanks", "Plume", "EmberSource", "Ember", "CutBox", "CutArch", "AncientCircleSky")


def base_colour(m):
	if not m or not m.node_tree:
		return (128, 128, 128)
	b = m.node_tree.nodes.get("Principled BSDF")
	if not b:
		return (128, 128, 128)
	s = b.inputs["Base Color"]
	if s.is_linked:  # a textured material: its first brick colour if it has one
		n = next((n for n in m.node_tree.nodes if n.bl_idname == "ShaderNodeTexBrick"), None)
		return tuple(srgb(n.inputs["Color1"].default_value)) if n else (110, 100, 92)
	return tuple(srgb(s.default_value))


def under_armature(o):
	p = o.parent
	while p:
		if p.type == "ARMATURE":
			return True
		p = p.parent
	return False


def group_of(name):
	for g, pre in (("Lantern", ("Lantern",)), ("Train", ("Carriage", "TrainWindow", "Engine", "Headlamp"))):
		if name.startswith(pre):
			return g
	return ""


bpy.context.view_layer.update()
dg = bpy.context.evaluated_depsgraph_get()
parts, lights, decals = [], [], []


def solid_row(o, shape):
	"""[shape, sx, sy, sz, X, Y, Z, qx, qy, qz, qw] for a box (0) or Blender cylinder (1) from its own mesh."""
	vs = o.data.vertices
	lo = Vector((min(v.co.x for v in vs), min(v.co.y for v in vs), min(v.co.z for v in vs)))
	hi = Vector((max(v.co.x for v in vs), max(v.co.y for v in vs), max(v.co.z for v in vs)))
	sc = o.matrix_world.to_scale()
	d = Vector(((hi - lo).x * sc.x, (hi - lo).y * sc.y, (hi - lo).z * sc.z))
	mw = o.matrix_world.normalized()
	R = (mw @ CYL_FIX).to_3x3() if shape == 1 else mw.to_3x3()
	size = (d.z, d.x, d.y) if shape == 1 else (d.x, d.z, d.y)
	q = (M3 @ R.normalized() @ M3.transposed()).to_quaternion()
	return [shape] + r3(Vector(size) * S) + r3(rpos(o.matrix_world @ ((lo + hi) / 2))) + [round(q.x, 5), round(q.y, 5), round(q.z, 5), round(q.w, 5)]


cutter_rows = [solid_row(c, 1 if c.name.startswith("CutArch") else 0) for c in bpy.data.collections["NicheCutters"].objects]
for o in scene.objects:
	if o.name.startswith(SKIP_PREFIX) or under_armature(o):
		continue
	wpos = o.matrix_world.to_translation()
	grp = group_of(o.name)
	if wpos.y > FAR_Y and grp != "Train":
		continue
	if o.type == "LIGHT":
		ld = o.data
		d = (o.matrix_world.to_3x3() @ Vector((0, 0, -1))).normalized()
		lights.append({"name": o.name, "kind": ld.type, "pos": r3(rpos(wpos)), "dir": r3(rdir(d), 4),
			"watts": round(ld.energy, 2), "colour": hexc(srgb(ld.color)), "angle": round(math.degrees(getattr(ld, "spot_size", 0)), 1),
			"shadows": bool(ld.use_shadow), "group": grp})
		continue
	if o.type != "MESH":
		continue
	m = o.data.materials[0] if o.data.materials else None
	mname = m.name.split(".")[0] if m else ""
	ev = o.evaluated_get(dg)
	me = ev.to_mesh()
	lo = Vector((min(v.co.x for v in me.vertices), min(v.co.y for v in me.vertices), min(v.co.z for v in me.vertices)))
	hi = Vector((max(v.co.x for v in me.vertices), max(v.co.y for v in me.vertices), max(v.co.z for v in me.vertices)))
	ev.to_mesh_clear()
	sc = o.matrix_world.to_scale()
	dims = Vector(((hi - lo).x * sc.x, (hi - lo).y * sc.y, (hi - lo).z * sc.z))
	centre_local = (lo + hi) / 2
	mw = o.matrix_world.normalized()
	centre = o.matrix_world @ centre_local
	if mname in IMAGE_MATS or mname.startswith("TowerClockFace"):
		if mname not in IMAGE_MATS:
			continue  # (the tower clock is in the backdrop)
		n = (mw.to_3x3() @ Vector((0, 0, 1))).normalized()
		up = (mw.to_3x3() @ Vector((0, 1, 0))).normalized()
		decals.append({"name": o.name, "image": IMAGE_MATS[mname], "pos": r3(rpos(centre)), "normal": r3(rdir(n), 4), "up": r3(rdir(up), 4),
			"w": round(dims.x * S, 3), "h": round(dims.y * S, 3)})
		continue
	shape = 0
	R = mw.to_3x3()
	mesh_name = o.data.name
	is_cyl = o.name.startswith(("Cyl", "Stack", "Leg", "Coat", "Chest", "Arm", "Neck", "Sash", "Belt", "CartWheel", "Gate", "LanternCap",
		"HallDrum", "HallLantern", "ClockCase", "TowerSpire", "EngineStack", "Watch"))
	is_ball = o.name.startswith(("Bulb", "Spike", "Stone", "Headlamp"))
	if is_cyl:
		shape = 1
		R = (mw @ CYL_FIX).to_3x3()
		size = (dims.z, dims.x, dims.y)
	elif is_ball:
		shape = 2
		dm = sum(dims) / 3  # (Roblox balls are round: the stones' squash is lost)
		size = (dm, dm, dm)
	else:
		size = (dims.x, dims.z, dims.y)  # Roblox local Y is the Blender object's local Z, local Z its -Y
	Rr = M3 @ R.normalized() @ M3.transposed()
	q = Rr.to_quaternion()
	mat, mcol = MATS.get(mname, ("SmoothPlastic", None))
	colour = hexc(mcol or base_colour(m))
	row = [o.name, shape, mat, colour] + r3(Vector(size) * S) + r3(rpos(centre)) + [round(q.x, 5), round(q.y, 5), round(q.z, 5), round(q.w, 5), grp]
	if any(md.type == "BOOLEAN" for md in o.modifiers):
		# the alcove wall: exported whole, with its cutters; Studio subtracts them (SubtractAsync)
		row.append([c for c in cutter_rows])
	parts.append(row)

# ---------- markers the client needs ----------
k = 1.85 / 5.1


def cam_view(pos, look, lens):
	p, l = rpos(pos), rpos(look)
	return {"pos": r3(p), "look": r3(l), "fov": round(math.degrees(2 * math.atan(10.125 / lens)), 2)}


shift_pitch = math.degrees(math.atan(cd.shift_y * 36 / cd.lens))  # the Blender lens shift, as a pitch up
menu_pos = Vector((0.8, 0.0, 1.7))
menu_look = menu_pos + Vector((0, math.cos(math.radians(shift_pitch)), math.sin(math.radians(shift_pitch)))) * 10
markers = {
	"scale": S, "origin": r3(ORIGIN),
	"menu_camera": cam_view(menu_pos, menu_look, cd.lens),
	"alcoves": [], "platform_circle": {"centre": r3(rpos((CX, CY, 0.02))), "radius": round(1.38 * S, 3)},
	"lantern_pivot": r3(rpos((lx, ly, 6.0))),
	"ember_box": {"centre": r3(rpos((2, 8, 0.3))), "size": r3(Vector((18, 0.1, 10)) * S)},
	"haze_box": {"centre": r3(rpos((2, 7, 3.5))), "size": r3(Vector((30, 7.2, 14)) * S)},
	"stack_tops": [r3(rpos((x, y, top))) for x, y, top in stacks],
	"train": {"from_x": round(-95 * S, 2), "to_x": round(55 * S, 2), "seconds": 8.0},
	"statue": {"foot": r3(rpos((SX, SY, 1.21))), "height_studs": round(2.3 * S, 2)},
	"backdrop": {},
}
for i, x in enumerate(NICHE_X):
	fy = WALL_Y + 0.3
	markers["alcoves"].append({
		"slot": i + 1, "foot": r3(rpos((x, fy, 0.25))), "face": r3(rdir((0, -1, 0)), 3),
		"body": cam_view((x - 0.75, WALL_Y - 5.2, 1.3), (x - 0.6, WALL_Y + 0.3, 1.12), 33.0),
		"face_view": cam_view((x - 0.45, WALL_Y - 2.6, 1.9), (x - 0.3, WALL_Y + 0.3, 1.72), 32.0),  # head and shoulders, the panel's room on the left
		"circle": {"centre": r3(rpos((x, fy, 0.28))), "radius": round(0.46 * S, 3)},
		"lamp": r3(rpos((x, WALL_Y - 0.25, 2.9))),
	})

# ---------- the backdrop: the far view only, from the Roblox-equivalent camera ----------
BD_W, BD_H = 3072, 1024
far_dist = 80.0  # metres: the plane sits just behind the viaduct
for o in scene.objects:
	if o.type in ("MESH", "CURVE", "LIGHT") and not o.name.startswith(("SmokeBanks", "Plume", "AncientCircle", "DuskSun", "Furnace", "TowerClock")):
		wy = o.matrix_world.to_translation().y
		if wy < FAR_Y or group_of(o.name) == "Train" or under_armature(o):
			o.hide_render = True
bcam = bpy.data.objects.new("BackdropCam", bpy.data.cameras.new("BackdropCam"))
col.objects.link(bcam)
bcd = bcam.data
bcd.sensor_fit = "VERTICAL"
bcd.sensor_height = 20.25
bcd.lens = cd.lens  # the same vertical field of view as the menu camera...
bcd.dof.use_dof = False
bcd.clip_end = 2000
bcam.location = menu_pos
bcam.rotation_euler = (math.radians(90 + shift_pitch), 0, 0)
scene.camera = bcam
scene.render.resolution_x, scene.render.resolution_y = BD_W, BD_H  # ...but 3:1 wide, for ultrawide screens
scene.render.resolution_percentage = 100
vfov = 2 * math.atan(10.125 / bcd.lens)
hfov = 2 * math.atan(math.tan(vfov / 2) * BD_W / BD_H)
fwd = Vector((0, math.cos(math.radians(shift_pitch)), math.sin(math.radians(shift_pitch))))
centre = menu_pos + fwd * far_dist
markers["backdrop"] = {"centre": r3(rpos(centre)), "normal": r3(rdir(-fwd), 4), "up": r3(rdir(Vector((0, -math.sin(math.radians(shift_pitch)), math.cos(math.radians(shift_pitch))))), 4),
	"w": round(2 * far_dist * math.tan(hfov / 2) * S, 2), "h": round(2 * far_dist * math.tan(vfov / 2) * S, 2), "tiles": 3}
for n in scene.compositing_node_group.nodes:
	if n.bl_idname == "CompositorNodeKuwahara":
		n.inputs["Size"].default_value = 6
	if n.bl_idname == "CompositorNodeOutputFile":
		n.mute = True
full = os.path.join(OUT, "backdrop_full.png")
scene.render.filepath = full
bpy.ops.render.render(write_still=True, scene=scene.name)
with open(os.path.join(STUDIO, "painted_stage.json"), "w") as fh:
	json.dump({"parts": parts, "lights": lights, "decals": decals, "markers": markers}, fh, indent=None, separators=(",", ":"))
print("RENSEI_EXPORT", len(parts), "parts", len(lights), "lights", len(decals), "decals ->", STUDIO)

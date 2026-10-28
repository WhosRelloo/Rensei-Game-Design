"""Rensei main menu: the painted diorama as a lit 3D scene (owner 2026-10-28: "Make it higher quality").

Builds a rail-platform foundry hall at dusk in a fresh Blender scene, renders it with Eevee (volumetric smoke
and light shafts, glowing furnaces, depth of field) and paints it over with the compositor's anisotropic
Kuwahara filter. Design: Documents/specs/2026-10-28-main-menu-painted-design.md.

Run headless (never saves a .blend unless --save is given; .blend files are never committed):
    blender -b --factory-startup -P Art/MainMenu/menu_scene.py -- --out E:/Rensei/Renders/MainMenu/concept

Writes scene_raw.png (the render) and scene_painted.png (after the paint-over).
Coordinates: metres, +Y away from the camera, +Z up. The alcove wall's face is at y = WALL_Y.
"""
import math
import os
import random
import sys

import bpy
import bmesh
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[argv.index("--out") + 1] if "--out" in argv else "E:/Rensei/Renders/MainMenu/concept"
TEX = argv[argv.index("--tex") + 1] if "--tex" in argv else "E:/Rensei/Work/main-menu/tex"  # menu_textures.py's output
SAMPLES = int(argv[argv.index("--samples") + 1]) if "--samples" in argv else 96
SAVE = argv[argv.index("--save") + 1] if "--save" in argv else None
PCT = int(argv[argv.index("--pct") + 1]) if "--pct" in argv else 100  # resolution percentage (50 for a quick test)
BAKE = "--bake" in argv  # bake the materials for Roblox (menu_bake.py)
EXPORT = "--export" in argv  # write the Roblox stage (menu_export.py) instead of rendering the still
ANIM = "--anim" in argv  # render the animated preview frames (menu_anim.py) instead of the still
FRAMES = argv[argv.index("--frames") + 1] if "--frames" in argv else None  # e.g. "0-275" or "0,100,200" (default: all)
os.makedirs(OUT, exist_ok=True)
rng = random.Random(28)

WALL_Y = 12.0
WALL_TOP = 3.0
NICHE_X = [-1.4, 0.75, 2.9, 5.05, 7.2]  # slots 1-5
NICHE_W, SPRING = 1.7, 1.95  # niche width (an R6 is 4 units wide at the arms) and where its arch springs
STATES = ["Created", "Created", "Empty", "Locked", "Locked"]

# headless with --factory-startup: the default scene is ours to clear
scene = bpy.context.scene
scene.name = "RenseiMenu"
for o in list(scene.objects):
	bpy.data.objects.remove(o, do_unlink=True)
col = scene.collection


# ---------- helpers ----------
def mat(name, color, rough=0.6, metal=0.0, emit=None, strength=0.0):
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	b = m.node_tree.nodes["Principled BSDF"]
	b.inputs["Base Color"].default_value = (*color, 1)
	b.inputs["Roughness"].default_value = rough
	b.inputs["Metallic"].default_value = metal
	if emit:
		b.inputs["Emission Color"].default_value = (*emit, 1)
		b.inputs["Emission Strength"].default_value = strength
	return m


def _node(nt, kind, **inputs):
	n = nt.nodes.new(kind)
	for k, v in inputs.items():
		if k.startswith("_"):
			setattr(n, k[1:], v)
		else:
			n.inputs[k].default_value = v
	return n


def _sock(socks, ident):
	"""A socket by identifier (ShaderNodeMix has several sockets named "A", "B" and "Result", one per data type)."""
	return next(x for x in socks if x.identifier == ident)


def _mix(nt, blend, a, b, fac):
	"""Colour mix node; a, b and fac are sockets or values. Returns its colour output."""
	n = nt.nodes.new("ShaderNodeMix")
	n.data_type = "RGBA"
	n.blend_type = blend
	for ident, v in (("A_Color", a), ("B_Color", b), ("Factor_Float", fac)):
		sock = _sock(n.inputs, ident)
		if isinstance(v, bpy.types.NodeSocket):
			nt.links.new(v, sock)
		else:
			sock.default_value = v if ident == "Factor_Float" or isinstance(v, tuple) else (v, v, v, 1)
	return _sock(n.outputs, "Result_Color")


def _math(nt, op, a, b=0.0, clamp=True):
	n = nt.nodes.new("ShaderNodeMath")
	n.operation = op
	n.use_clamp = clamp
	for i, v in enumerate((a, b)):
		if isinstance(v, bpy.types.NodeSocket):
			nt.links.new(v, n.inputs[i])
		else:
			n.inputs[i].default_value = v
	return n.outputs["Value"]


def textured_stone(name, c1, c2, mortar, scale, brick_w, row_h, rough=0.8, bump=0.3, wet=0.0, upright=False):
	"""Coursed stone: per-block colour, fine noise, pitted faces (voronoi), dirt packed into recessed mortar, soot
	streaks running down, and (wet > 0) puddles where the roughness drops and the stone darkens."""
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	nt = m.node_tree
	b = nt.nodes["Principled BSDF"]
	co0 = nt.nodes.new("ShaderNodeTexCoord").outputs["Object"]
	co = co0
	if upright:  # the Brick texture reads X and Y only: turn a wall's X-Z face into X-Y
		rot = _node(nt, "ShaderNodeMapping", Rotation=(math.pi / 2, 0, 0))
		nt.links.new(co0, rot.inputs["Vector"])
		co = rot.outputs["Vector"]
	br = _node(nt, "ShaderNodeTexBrick", Scale=scale, Color1=(*c1, 1), Color2=(*c2, 1), Mortar=(*mortar, 1),
		**{"Mortar Size": 0.02, "Mortar Smooth": 0.3, "Brick Width": brick_w, "Row Height": row_h, "Bias": 0.0}, _offset=0.5)
	nt.links.new(co, br.inputs["Vector"])
	nz = _node(nt, "ShaderNodeTexNoise", Scale=9.0, Detail=12.0, Roughness=0.62)
	nt.links.new(co, nz.inputs["Vector"])
	vo = _node(nt, "ShaderNodeTexVoronoi", Scale=22.0)
	nt.links.new(co, vo.inputs["Vector"])
	mp = _node(nt, "ShaderNodeMapping", Scale=(1.5, 1.5, 0.12))
	nt.links.new(co0, mp.inputs["Vector"])  # soot runs down (world Z)
	streak = _node(nt, "ShaderNodeTexNoise", Scale=3.0, Detail=6.0)
	nt.links.new(mp.outputs["Vector"], streak.inputs["Vector"])
	colr = _mix(nt, "MULTIPLY", br.outputs["Color"], nz.outputs["Color"], 0.6)
	pits = _math(nt, "SUBTRACT", 1.0, _math(nt, "MULTIPLY", vo.outputs["Distance"], 2.2))  # 1 at a pit's centre
	colr = _mix(nt, "MIX", colr, (0.012, 0.01, 0.01, 1), _math(nt, "MULTIPLY", _math(nt, "POWER", pits, 6.0), 0.5))
	soot = _math(nt, "MULTIPLY", _math(nt, "SUBTRACT", streak.outputs["Fac"], 0.45), 1.6)
	colr = _mix(nt, "MIX", colr, (0.01, 0.009, 0.009, 1), _math(nt, "MULTIPLY", soot, 0.55))
	colr = _mix(nt, "MIX", colr, (0.008, 0.007, 0.006, 1), _math(nt, "MULTIPLY", br.outputs["Fac"], 0.7))
	rough_s = _math(nt, "ADD", rough, _math(nt, "MULTIPLY", br.outputs["Fac"], 0.2))
	if wet > 0:
		pud = _node(nt, "ShaderNodeTexNoise", Scale=0.6, Detail=4.0)
		nt.links.new(co, pud.inputs["Vector"])
		wmask = _node(nt, "ShaderNodeMapRange", **{"From Min": 0.52, "From Max": 0.58})
		nt.links.new(pud.outputs["Fac"], wmask.inputs["Value"])
		wm = _math(nt, "MULTIPLY", wmask.outputs["Result"], wet)
		colr = _mix(nt, "MULTIPLY", colr, (0.55, 0.55, 0.58, 1), wm)
		rough_s = _mix(nt, "MIX", rough_s, 0.06, wm)
	nt.links.new(colr, b.inputs["Base Color"])
	if isinstance(rough_s, bpy.types.NodeSocket) and rough_s.type == "RGBA":
		sep = nt.nodes.new("ShaderNodeSeparateColor")
		nt.links.new(rough_s, sep.inputs["Color"])
		nt.links.new(sep.outputs["Red"], b.inputs["Roughness"])
	else:
		nt.links.new(rough_s, b.inputs["Roughness"])
	# height: blocks proud of the mortar, pitted, a little noise
	h = _math(nt, "SUBTRACT", 1.0, br.outputs["Fac"])
	h = _math(nt, "SUBTRACT", h, _math(nt, "MULTIPLY", _math(nt, "POWER", pits, 4.0), 0.35))
	h = _math(nt, "ADD", h, _math(nt, "MULTIPLY", nz.outputs["Fac"], 0.25), clamp=False)
	bp = _node(nt, "ShaderNodeBump", Strength=bump, Distance=0.02)
	nt.links.new(h, bp.inputs["Height"])
	nt.links.new(bp.outputs["Normal"], b.inputs["Normal"])
	return m


def rusty_iron(name, base=(0.03, 0.028, 0.03), rust=(0.13, 0.045, 0.018), amount=0.5):
	"""Dark wrought iron, patched with rust (rougher, not metallic) and a fine hammered bump."""
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	nt = m.node_tree
	b = nt.nodes["Principled BSDF"]
	co = nt.nodes.new("ShaderNodeTexCoord").outputs["Object"]
	nz = _node(nt, "ShaderNodeTexNoise", Scale=3.5, Detail=10.0, Roughness=0.65)
	nt.links.new(co, nz.inputs["Vector"])
	fine = _node(nt, "ShaderNodeTexNoise", Scale=60.0, Detail=4.0)
	nt.links.new(co, fine.inputs["Vector"])
	mr = _node(nt, "ShaderNodeMapRange", **{"From Min": 0.62 - amount * 0.2, "From Max": 0.7 - amount * 0.2})
	nt.links.new(nz.outputs["Fac"], mr.inputs["Value"])
	r = mr.outputs["Result"]
	nt.links.new(_mix(nt, "MIX", (*base, 1), (*rust, 1), r), b.inputs["Base Color"])
	nt.links.new(_math(nt, "SUBTRACT", 0.85, _math(nt, "MULTIPLY", r, 0.7)), b.inputs["Metallic"])
	nt.links.new(_math(nt, "ADD", 0.42, _math(nt, "MULTIPLY", r, 0.5)), b.inputs["Roughness"])
	bp = _node(nt, "ShaderNodeBump", Strength=0.25, Distance=0.01)
	nt.links.new(_math(nt, "ADD", fine.outputs["Fac"], r, clamp=False), bp.inputs["Height"])
	nt.links.new(bp.outputs["Normal"], b.inputs["Normal"])
	return m


def box(name, loc, size, material, rot=(0, 0, 0)):
	me = bpy.data.meshes.new(name)
	bm = bmesh.new()
	bmesh.ops.create_cube(bm, size=1.0)
	bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
	bm.to_mesh(me)
	bm.free()
	o = bpy.data.objects.new(name, me)
	o.location = loc
	o.rotation_euler = rot
	me.materials.append(material)
	col.objects.link(o)
	return o


def cyl(name, loc, r1, r2, depth, material, rot=(0, 0, 0), verts=24):
	me = bpy.data.meshes.new(name)
	bm = bmesh.new()
	bmesh.ops.create_cone(bm, cap_ends=True, segments=verts, radius1=r1, radius2=r2, depth=depth)
	bm.to_mesh(me)
	bm.free()
	for p in me.polygons:
		p.use_smooth = True
	o = bpy.data.objects.new(name, me)
	o.location = loc
	o.rotation_euler = rot
	me.materials.append(material)
	col.objects.link(o)
	return o


def sphere(name, loc, r, material, scale=(1, 1, 1)):
	me = bpy.data.meshes.new(name)
	bm = bmesh.new()
	bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=16, radius=r)
	bm.to_mesh(me)
	bm.free()
	for p in me.polygons:
		p.use_smooth = True
	o = bpy.data.objects.new(name, me)
	o.location = loc
	o.scale = scale
	me.materials.append(material)
	col.objects.link(o)
	return o


def light(name, kind, loc, energy, color, size=0.1, rot=(0, 0, 0), spot=None, shadow=True):
	ld = bpy.data.lights.new(name, kind)
	ld.energy = energy
	ld.color = color
	ld.use_shadow = shadow
	if kind in ("POINT", "SPOT"):
		ld.shadow_soft_size = size
	if kind == "AREA":
		ld.size = size
	if kind == "SUN":
		ld.angle = size
	if spot:
		ld.spot_size = math.radians(spot)
		ld.spot_blend = 0.6
	o = bpy.data.objects.new(name, ld)
	o.location = loc
	o.rotation_euler = rot
	col.objects.link(o)
	return o


def beam(name, a, b, t, material):
	"""A square bar from a to b (t thick)."""
	a, b = Vector(a), Vector(b)
	d = b - a
	o = box(name, (a + b) / 2, (t, t, d.length), material)
	o.rotation_mode = "QUATERNION"
	o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
	return o


def image_mat(name, path, emit=None, strength=0.0, tint=None, rough=0.7):
	"""An image on a plane: base colour and alpha from the image; emit = glow colour (multiplied by the image)."""
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	nt = m.node_tree
	b = nt.nodes["Principled BSDF"]
	it = nt.nodes.new("ShaderNodeTexImage")
	it.image = bpy.data.images.load(path, check_existing=True)
	if tint:
		col_out = _mix(nt, "MULTIPLY", it.outputs["Color"], (*tint, 1), 1.0)
	else:
		col_out = it.outputs["Color"]
	nt.links.new(col_out, b.inputs["Base Color"])
	nt.links.new(it.outputs["Alpha"], b.inputs["Alpha"])
	if emit:
		nt.links.new(col_out, b.inputs["Emission Color"])
		b.inputs["Emission Strength"].default_value = strength
	b.inputs["Roughness"].default_value = rough
	return m


def plane(name, loc, w, h, material, rot=(math.pi / 2, 0, 0)):
	"""A w x h plane, facing -Y by default (towards the camera)."""
	me = bpy.data.meshes.new(name)
	bm = bmesh.new()
	uv = bm.loops.layers.uv.new()
	vs = [bm.verts.new((x * w / 2, y * h / 2, 0)) for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
	f = bm.faces.new(vs)
	for loop, (u, v) in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
		loop[uv].uv = (u, v)
	bm.to_mesh(me)
	bm.free()
	o = bpy.data.objects.new(name, me)
	o.location = loc
	o.rotation_euler = rot
	me.materials.append(material)
	col.objects.link(o)
	return o


def bolt(name, a, b, material, jag=0.18, depth=5, thick=0.007, seed=0):
	"""A jagged alchemy-reaction arc from a to b (midpoint displacement)."""
	r = random.Random(seed)
	pts = [Vector(a), Vector(b)]
	amp = (Vector(b) - Vector(a)).length * jag
	for _ in range(depth):
		new = [pts[0]]
		for p, q in zip(pts, pts[1:]):
			m = (p + q) / 2 + Vector((r.uniform(-1, 1), r.uniform(-1, 1) * 0.4, r.uniform(-1, 1))) * amp
			new += [m, q]
		pts = new
		amp *= 0.5
	cu = bpy.data.curves.new(name, "CURVE")
	cu.dimensions = "3D"
	cu.bevel_depth = thick
	sp = cu.splines.new("POLY")
	sp.points.add(len(pts) - 1)
	for p, v in zip(sp.points, pts):
		p.co = (v.x, v.y, v.z, 1)
	o = bpy.data.objects.new(name, cu)
	cu.materials.append(material)
	col.objects.link(o)
	return o


def join(objs, name):
	bpy.ops.object.select_all(action="DESELECT")
	for o in objs:
		o.select_set(True)
	bpy.context.view_layer.objects.active = objs[0]
	bpy.ops.object.join()
	objs[0].name = name
	return objs[0]


# ---------- materials ----------
M = {
	"iron": rusty_iron("Iron", amount=0.35),
	"rust": rusty_iron("RustIron", amount=0.9),
	"brass": mat("Brass", (0.55, 0.38, 0.14), 0.35, 1.0),
	"gold": mat("GoldBraid", (0.6, 0.45, 0.16), 0.4, 1.0),
	"stone_red": mat("PhilosophersStone", (0.11, 0.02, 0.016), 0.7, 0, (0.4, 0.04, 0.02), 0.12),
	"town": mat("TownStone", (0.035, 0.03, 0.03), 0.9),
	"soot": mat("Soot", (0.02, 0.018, 0.018), 0.95),
	"window": mat("Window", (0.1, 0.05, 0.02), 0.5, 0, (1.0, 0.45, 0.12), 6.0),
	"furnace": mat("Furnace", (0.1, 0.03, 0.0), 0.5, 0, (1.0, 0.32, 0.05), 40.0),
	"bulb": mat("Bulb", (1, 0.7, 0.4), 0.3, 0, (1.0, 0.62, 0.3), 25.0),
	"glass": mat("LanternGlass", (1, 0.6, 0.3), 0.2, 0, (1.0, 0.55, 0.22), 4.0),
	"chalk": mat("Chalk", (0.9, 0.88, 0.84), 0.9, 0, (0.9, 0.88, 0.84), 1.2),
	"cloth": mat("DustSheet", (0.55, 0.52, 0.48), 0.95),
	"coat1": mat("CoatAlchemistRed", (0.3, 0.03, 0.025), 0.72),
	"coat2": mat("CoatStateBlue", (0.025, 0.04, 0.12), 0.7),
	"leather": mat("Leather", (0.05, 0.03, 0.02), 0.6),
	"skin1": mat("Skin1", (0.55, 0.36, 0.26), 0.55),
	"skin2": mat("Skin2", (0.7, 0.52, 0.4), 0.55),
	"hair1": mat("Hair1", (0.05, 0.03, 0.02), 0.5),
	"hair2": mat("Hair2", (0.015, 0.012, 0.015), 0.5),
	"red": mat("Sash", (0.35, 0.02, 0.02), 0.6),
	"steel": mat("Steel", (0.5, 0.52, 0.56), 0.3, 1.0),
	"train": mat("Train", (0.04, 0.03, 0.025), 0.6, 0.4),
}
M["wall"] = textured_stone("WallStone", (0.11, 0.095, 0.09), (0.075, 0.065, 0.06), (0.03, 0.026, 0.024), 2.2, 0.55, 0.24, upright=True)
M["floor"] = textured_stone("Flagstones", (0.07, 0.06, 0.055), (0.05, 0.045, 0.042), (0.02, 0.018, 0.016), 0.7, 0.6, 0.5, rough=0.45, bump=0.4, wet=1.0)
M["viaduct"] = textured_stone("Viaduct", (0.07, 0.05, 0.042), (0.05, 0.038, 0.032), (0.02, 0.016, 0.014), 0.3, 0.5, 0.25, upright=True)
T = lambda f: os.path.join(TEX, f)
M["chalk_circle"] = image_mat("ChalkCircle", T("circle_chalk.png"), emit=True, strength=0.6, rough=0.95)
M["banner"] = image_mat("Banner", T("banner.png"), rough=0.85)
M["clock"] = image_mat("ClockFace", T("clock.png"), emit=True, strength=0.25, rough=0.25)
M["sign"] = image_mat("StationSign", T("sign.png"), rough=0.3)
M["blank"] = mat("BlankGrey", (0.32, 0.32, 0.33), 0.6)
M["statue"] = textured_stone("StatueStone", (0.2, 0.19, 0.17), (0.18, 0.17, 0.155), (0.17, 0.16, 0.15), 6.0, 0.9, 0.9, rough=0.85, bump=0.15)
M["arc"] = mat("AlchemyArc", (0.5, 0.75, 1.0), 0.3, 0, (0.45, 0.72, 1.0), 60.0)

# ---------- the R6 rig (owner 2026-10-28: "use a roblox rigged r6 model ... fully rigged for poses") ----------
# The owner's PaintRigV3: armature "RoBone" (Base, Lower, Upper, Head, R A / R E and L A / L E = upper arm / forearm,
# L L / L K and R L / R K = thigh / shin with IK on the knees), a bendy R6 body in six parts. In the file it faces +Y,
# stands 5.1 units tall, origin at the hips (feet 2 units below it).
R6_PATH = argv[argv.index("--r6") + 1] if "--r6" in argv else "E:/Blender Shit/CHARACTER SHIT/PaintRigV3.blend"
R6_PARTS = {"Idarkgames9": "Head", "Torso": "Torso", "Mendula6": "RightArm", "Mendula8": "LeftArm", "Left Leg": "LeftLeg", "Mendula5": "RightLeg"}


def load_r6(name, loc, height, face=math.pi):
	"""Append a fresh copy of the R6 rig with its feet at loc, `height` metres tall, turned by `face` (pi = facing
	the camera). Returns (armature, {part: mesh})."""
	with bpy.data.libraries.load(R6_PATH, link=False) as (src, dst):
		dst.objects = [n for n in src.objects if n == "RoBone" or n in R6_PARTS]
	names = list(R6_PARTS)
	arm, parts = None, {}
	for o in dst.objects:
		if o is None:
			continue
		col.objects.link(o)
		if o.type == "ARMATURE":
			arm = o
	for o in dst.objects:
		if o is not None and o.type == "MESH":
			base = next(n for n in names if o.name == n or o.name.startswith(n + "."))
			parts[R6_PARTS[base]] = o
	k = height / 5.1
	arm.name = name
	arm.scale = (k, k, k)
	arm.rotation_euler = (0, 0, face)
	arm.location = Vector(loc) + Vector((0, 0, 2.0 * k))
	for pb in arm.pose.bones:
		for con in pb.constraints:
			if con.type == "LIMIT_ROTATION":
				con.mute = True  # (the poses below set directions outright)
	return arm, parts


def aim(arm, bone, direction):
	"""Point a bone along `direction` (armature space; +Y is the rig's front), keeping its rest roll."""
	bpy.context.view_layer.update()
	pb = arm.pose.bones[bone]
	rest = pb.bone.matrix_local
	head = pb.matrix.translation.copy()
	q = Vector(rest.col[1][:3]).normalized().rotation_difference(Vector(direction).normalized())
	m = q.to_matrix().to_4x4() @ rest.to_3x3().to_4x4()
	m.translation = head
	pb.matrix = m
	bpy.context.view_layer.update()


def pose_r6(arm, kind):
	if kind == "idle":  # arms eased off the body, elbows a touch bent
		aim(arm, "R A", (0.12, 0.04, -1))
		aim(arm, "R E", (0.06, 0.22, -1))
		aim(arm, "L A", (-0.12, 0.0, -1))
		aim(arm, "L E", (-0.05, 0.15, -1))
	elif kind == "clap":  # Rensei's alchemy clap: arms forward, palms meeting in front of the chest
		aim(arm, "R A", (-0.45, 1, 0.05))
		aim(arm, "R E", (-1, 0.3, 0.25))
		aim(arm, "L A", (0.45, 1, 0.05))
		aim(arm, "L E", (1, 0.3, 0.25))
	elif kind == "arms_crossed":  # the alchemist: arms folded across the chest, weight on one leg, head cocked
		aim(arm, "Lower", (0.03, 0, 1))  # hips tilt over the standing leg
		arm.pose.bones["L K.001"].location = (-0.08, 0.1, 0.0)  # the free foot eased out (an IK target)
		aim(arm, "R A", (0.0, 0.42, -1))
		aim(arm, "R E", (-1, 0.34, 0.02))  # right forearm across, under
		aim(arm, "L A", (0.0, 0.5, -1))
		aim(arm, "L E", (1, 0.42, 0.12))  # left forearm across, over
		aim(arm, "Head", (-0.07, 0.04, 1))
	elif kind == "parade_rest":  # the State Alchemist: feet apart, hands clasped behind the back, chin up
		arm.pose.bones["L K.001"].location = (-0.12, 0.0, 0.0)
		arm.pose.bones["R K.001"].location = (0.12, 0.0, 0.0)
		aim(arm, "R A", (0.0, -0.36, -1))
		aim(arm, "R E", (-0.72, -0.62, -0.38))
		aim(arm, "L A", (0.0, -0.36, -1))
		aim(arm, "L E", (0.72, -0.62, -0.38))
		aim(arm, "Head", (0, -0.07, 1))
	elif kind == "attention":  # arms straight at the sides (Roblox's plain stand)
		for b, d in (("R A", (0.03, 0, -1)), ("R E", (0.03, 0, -1)), ("L A", (-0.03, 0, -1)), ("L E", (-0.03, 0, -1))):
			aim(arm, b, d)


def dress(parts, mats):
	"""mats: {part: material}; "*" covers every part without its own."""
	for part, o in parts.items():
		o.data = o.data.copy()
		o.data.materials.clear()
		o.data.materials.append(mats.get(part, mats.get("*")))


def accessory(arm, bone, obj):
	"""Parent a prop to a bone, keeping where it was put."""
	bpy.context.view_layer.update()
	mw = obj.matrix_world.copy()
	obj.parent = arm
	obj.parent_type = "BONE"
	obj.parent_bone = bone
	bpy.context.view_layer.update()
	obj.matrix_world = mw
	return obj


# ---------- the platform and the alcove wall ----------
floor = box("Floor", (2, 5, -0.1), (30, 16, 0.2), M["floor"])
wall = box("AlcoveWall", (0, WALL_Y + 0.5, WALL_TOP / 2), (26, 1.0, WALL_TOP), M["wall"])
box("Coping", (0, WALL_Y + 0.45, WALL_TOP + 0.08), (26.2, 1.2, 0.16), M["wall"])
cutters = bpy.data.collections.new("NicheCutters")
for x in NICHE_X:
	c1 = box("CutBox", (x, WALL_Y + 0.35, (0.25 + SPRING) / 2), (NICHE_W, 0.9, SPRING - 0.25 + 0.02), M["wall"])
	c2 = cyl("CutArch", (x, WALL_Y + 0.35, SPRING), NICHE_W / 2, NICHE_W / 2, 0.9, M["wall"], rot=(math.pi / 2, 0, 0), verts=64)
	for c in (c1, c2):
		col.objects.unlink(c)
		cutters.objects.link(c)
bo = wall.modifiers.new("Niches", "BOOLEAN")
bo.operation = "DIFFERENCE"
bo.operand_type = "COLLECTION"
bo.collection = cutters
bo.solver = "EXACT"

for i, x in enumerate(NICHE_X):
	state = STATES[i]
	box(f"Ledge{i + 1}", (x, WALL_Y - 0.08, 0.2), (NICHE_W + 0.3, 0.35, 0.12), M["wall"])
	# arch trim and a keystone
	for k in range(17):
		a = math.pi * k / 16
		rr = NICHE_W / 2 + 0.08
		box(f"Voussoir{i + 1}_{k}", (x + math.cos(a) * rr, WALL_Y - 0.02, SPRING + math.sin(a) * rr), (0.2, 0.08, 0.2), M["wall"], rot=(0, -a + math.pi / 2, 0))
	box(f"Keystone{i + 1}", (x, WALL_Y - 0.05, SPRING + NICHE_W / 2 + 0.1), (0.22, 0.12, 0.24), M["wall"])
	# every niche has its lamp, chalk circles and gate; the still and the preview show the ones its slot state wants,
	# and in game the client does the same from the player's own slots (owned: lamp lit, circles, no gate)
	lit = state != "Locked"
	box(f"Bracket{i + 1}", (x, WALL_Y - 0.15, 3.05), (0.05, 0.3, 0.05), M["iron"])
	sphere(f"Bulb{i + 1}", (x, WALL_Y - 0.3, 2.98), 0.06, M["bulb"]).hide_render = not lit
	light(f"NicheLamp{i + 1}", "POINT", (x, WALL_Y - 0.25, 2.9), 45, (1.0, 0.62, 0.32), 0.08).hide_render = not lit
	light(f"NicheFill{i + 1}", "POINT", (x, WALL_Y + 0.25, 2.3), 12, (1.0, 0.55, 0.3), 0.2).hide_render = not lit
	# a chalk circle on the niche's back wall (a halo behind the character) and one under its feet
	plane(f"NicheCircle{i + 1}", (x, WALL_Y + 0.78, 1.6), 1.3, 1.3, M["chalk_circle"]).hide_render = not lit
	plane(f"FootCircle{i + 1}", (x, WALL_Y + 0.3, 0.262), 0.95, 0.95, M["chalk_circle"], rot=(0, 0, 0)).hide_render = not lit
	gate = []
	for k in range(11):
		gx = x - 0.75 + k * 0.15
		gate.append(cyl(f"Gate{i + 1}_{k}", (gx, WALL_Y - 0.05, 1.4), 0.022, 0.022, 2.4, M["rust"]))
		gate.append(sphere(f"Spike{i + 1}_{k}", (gx, WALL_Y - 0.05, 2.62), 0.03, M["rust"]))
	gate.append(box(f"GateBar{i + 1}", (x, WALL_Y - 0.05, 1.7), (NICHE_W, 0.04, 0.05), M["rust"]))
	for g in gate:
		g.hide_render = lit
	if state == "Created":
		# R6 characters in Rensei's dress: slot 1 an alchemist in red (coat tails, gloves), slot 2 a State Alchemist
		# in the Authority's blue (gold epaulettes and buttons, the silver watch). In game: the slot's real character.
		red = i % 2 == 0
		fy = WALL_Y + 0.3
		H = 1.85
		k = H / 5.1
		arm, parts = load_r6(f"Slot{i + 1}", (x, fy, 0.25), H)
		coat = M["coat1"] if red else M["coat2"]
		dress(parts, {"Head": M["skin1"] if red else M["skin2"], "Torso": coat, "LeftArm": coat, "RightArm": coat,
			"LeftLeg": M["leather"], "RightLeg": M["leather"]})
		top = 0.25 + H  # the top of the head
		# hair: a blocky cap like a Roblox hair accessory; a face: two eyes and a mouth on the head's front
		hm = M["hair1"] if red else M["hair2"]
		accessory(arm, "Head", box(f"Hair{i + 1}", (x, fy + 0.02 * k, top - 0.08 * k), (1.36 * k, 1.36 * k, 0.4 * k), hm))
		accessory(arm, "Head", box(f"HairBack{i + 1}", (x, fy + 0.5 * k, top - 0.55 * k), (1.36 * k, 0.4 * k, 0.9 * k), hm))
		accessory(arm, "Head", box(f"Fringe{i + 1}", (x - 0.15 * k, fy - 0.6 * k, top - 0.26 * k), (0.9 * k, 0.16 * k, 0.22 * k), hm, rot=(0, 0.12, 0)))
		for sx in (-1, 1):
			accessory(arm, "Head", box(f"Eye{i + 1}{sx}", (x + sx * 0.2 * k, fy - 0.645 * k, top - 0.58 * k), (0.12 * k, 0.03, 0.2 * k), M["hair2"]))
		for n, (dx, dz) in enumerate(((-0.17, 0.0), (-0.06, -0.035), (0.06, -0.035), (0.17, 0.0))):  # a small smile
			accessory(arm, "Head", box(f"Mouth{i + 1}_{n}", (x + dx * k, fy - 0.645 * k, top - (0.86 - dz) * k), (0.12 * k, 0.03, 0.05 * k), M["hair2"]))
		if red:
			accessory(arm, "Lower", box(f"CoatTails{i + 1}", (x, fy, 0.25 + 1.3 * k), (2.15 * k, 1.1 * k, 1.5 * k), coat))
			accessory(arm, "Lower", box(f"Belt{i + 1}", (x, fy, 0.25 + 2.1 * k), (2.08 * k, 1.06 * k, 0.18 * k), M["leather"]))
			accessory(arm, "Lower", box(f"CoatSplit{i + 1}", (x, fy - 0.56 * k, 0.25 + 1.2 * k), (0.08 * k, 0.04, 1.3 * k), M["leather"]))
			accessory(arm, "Lower", box(f"CoatHem{i + 1}", (x, fy, 0.25 + 0.6 * k), (2.18 * k, 1.13 * k, 0.12 * k), M["leather"]))
			for bn, sx in (("R E", 1), ("L E", -1)):
				tip = arm.matrix_world @ arm.pose.bones[bn].tail
				accessory(arm, bn, box(f"Glove{i + 1}{sx}", tip + Vector((0, 0, 0.12 * k)), (1.04 * k, 1.04 * k, 0.5 * k), M["leather"]))
		else:
			for sx in (-1, 1):
				accessory(arm, "Upper", box(f"Epaulette{i + 1}{sx}", (x + sx * 1.45 * k, fy, 0.25 + 4.0 * k), (1.05 * k, 1.05 * k, 0.12 * k), M["gold"]))
			for n in range(4):
				accessory(arm, "Upper", sphere(f"Button{i + 1}_{n}", (x, fy - 0.52 * k, 0.25 + (3.6 - n * 0.4) * k), 0.075 * k, M["gold"]))
			accessory(arm, "Lower", beam(f"WatchChain{i + 1}", (x + 0.1 * k, fy - 0.52 * k, 0.25 + 2.2 * k), (x + 0.6 * k, fy - 0.52 * k, 0.25 + 1.8 * k), 0.008, M["steel"]))
			accessory(arm, "Lower", cyl(f"Watch{i + 1}", (x + 0.65 * k, fy - 0.54 * k, 0.25 + 1.65 * k), 0.14 * k, 0.14 * k, 0.04 * k, M["steel"], rot=(math.pi / 2, 0, 0)))
		pose_r6(arm, "arms_crossed" if red else "parade_rest")  # (after the props, so they follow the pose)
	elif state == "Empty":
		fy = WALL_Y + 0.3
		# the circle is waiting: a reaction crackling round it (animated in game)
		for n in range(5):
			a0 = rng.uniform(0, 2 * math.pi)
			a1 = a0 + rng.uniform(0.6, 1.4)
			p0 = (x + math.cos(a0) * 0.46, fy + math.sin(a0) * 0.46, 0.28)
			p1 = (x + math.cos(a1) * 0.46, fy + math.sin(a1) * 0.46, 0.28)
			bolt(f"NicheArc{n}", p0, p1, M["arc"], 0.3, 5, 0.004, seed=n)
		light("NicheArcGlow", "POINT", (x, fy - 0.15, 0.5), 8, (0.45, 0.7, 1.0), 0.2)
		# a blank R6: Roblox's plain grey character, not yet made into anyone
		arm, parts = load_r6(f"Slot{i + 1}", (x, fy, 0.25), 1.85)
		dress(parts, {"*": M["blank"]})
		pose_r6(arm, "attention")

# ---------- the hall: columns, roof trusses, a crane boom ----------
for x, y in ((-3.6, 3.2), (-5.9, 9.5), (8.8, 5.5)):
	box("Column", (x, y, 3.5), (0.45, 0.45, 7.0), M["iron"])
	for z in (0.4, 6.6):
		box("ColumnCap", (x, y, z), (0.7, 0.7, 0.25), M["iron"])
for y in (2.5, 5.5, 8.5, 11.5):
	box("Truss", (2, y, 6.4), (26, 0.18, 0.35), M["iron"])
	box("TrussLow", (2, y, 5.6), (26, 0.12, 0.14), M["iron"])
	for k in range(18):
		x0 = -11 + k * 1.5
		beam("Brace", (x0, y, 5.6), (x0 + 0.75, y, 6.4), 0.07, M["iron"])
		beam("Brace", (x0 + 1.5, y, 5.6), (x0 + 0.75, y, 6.4), 0.07, M["iron"])
for x in (-6, -1, 4, 9):
	box("Purlin", (x, 7, 6.6), (0.15, 12, 0.15), M["iron"])
# the crane boom, behind the wall on the right
a, b = Vector((11.5, 22, -6)), Vector((5.5, 30, 15))
side = Vector((0.6, 0, 0))
for k in range(12):
	t0, t1 = k / 12, (k + 1) / 12
	p0, p1 = a.lerp(b, t0), a.lerp(b, t1)
	for s in (-1, 1):
		beam("Boom", p0 + side * s, p1 + side * s, 0.12, M["iron"])
	beam("BoomX", p0 - side, p1 + side, 0.06, M["iron"])
	beam("BoomX", p0 + side, p1 - side, 0.06, M["iron"])
beam("CraneCable", b, b + Vector((0, 0, -11)), 0.03, M["iron"])
box("CraneHook", b + Vector((0, 0, -11.4)), (0.5, 0.5, 0.7), M["iron"])

# ---------- Rensei's alchemy, in the series' mood (owner: "more FMA like Rensei's theme") ----------
# a transmutation circle chalked on the platform in front of the alcoves, a blue reaction crackling over it
CX, CY = 2.0, 10.6
plane("PlatformCircle", (CX, CY, 0.006), 3.0, 3.0, M["chalk_circle"], rot=(0, 0, 0.3))
for k in range(9):
	a0 = rng.uniform(0, 2 * math.pi)
	r0, r1 = rng.choice([(1.38, 1.38), (1.1, 1.38), (0.6, 1.1)])
	a1 = a0 + rng.uniform(0.4, 1.1)
	p0 = (CX + math.cos(a0) * r0, CY + math.sin(a0) * r0, 0.02)
	p1 = (CX + math.cos(a1) * r1, CY + math.sin(a1) * r1, 0.02)
	bolt(f"Arc{k}", p0, p1, M["arc"], 0.35, 6, 0.006, seed=100 + k)
for k in range(3):  # a few leap upward
	a0 = rng.uniform(0, 2 * math.pi)
	p0 = (CX + math.cos(a0) * 1.3, CY + math.sin(a0) * 1.3, 0.02)
	bolt(f"ArcUp{k}", p0, (p0[0] + rng.uniform(-0.3, 0.3), p0[1], rng.uniform(0.5, 0.9)), M["arc"], 0.3, 5, 0.005, seed=200 + k)
light("ReactionGlow", "POINT", (CX, CY - 0.3, 0.35), 160, (0.42, 0.68, 1.0), 0.6)
# State Authority banners from the trusses, a station clock, the station's enamel sign
plane("BannerL", (-1.5, 8.4, 4.2), 0.9, 2.25, M["banner"])
plane("BannerR", (8.0, 9.6, 3.55), 0.9, 2.25, M["banner"])
for bx, by, bz in ((-1.5, 8.4, 5.35), (8.0, 9.6, 4.7)):
	beam("BannerPole", (bx - 0.55, by - 0.02, bz), (bx + 0.55, by - 0.02, bz), 0.05, M["brass"])
	for s in (-1, 1):
		beam("BannerCord", (bx + s * 0.5, by - 0.02, bz), (bx, by - 0.02, 5.6), 0.012, M["iron"])
ckx, cky, ckz = 0.05, 6.8, 4.2
beam("ClockRod", (ckx, cky, ckz + 0.5), (ckx, cky, 5.6), 0.05, M["iron"])
cyl("ClockCase", (ckx, cky, ckz), 0.5, 0.5, 0.18, M["brass"], rot=(math.pi / 2, 0, 0), verts=48)
plane("ClockFace", (ckx, cky - 0.095, ckz), 0.94, 0.94, M["clock"])
box("SignBoard", (-3.15, WALL_Y - 0.04, 2.45), (1.6, 0.05, 0.35), M["iron"])
plane("Sign", (-3.15, WALL_Y - 0.07, 2.45), 1.52, 0.3, M["sign"])
for s in (-1, 1):
	beam("SignBracket", (-3.15 + s * 0.65, WALL_Y - 0.02, 2.7), (-3.15 + s * 0.65, WALL_Y - 0.02, 2.2), 0.04, M["iron"])
# Philosopher's Stones on a cart by the wall: cast iron or cut rock with a circle in it, dull red, warm
# (Lore Bible §4: the Foundry Yard makes them in secret)
box("Cart", (-2.85, WALL_Y - 0.9, 0.45), (1.2, 0.8, 0.5), M["rust"])
for s in (-1, 1):
	cyl("CartWheel", (-2.85 + s * 0.45, WALL_Y - 1.32, 0.22), 0.22, 0.22, 0.06, M["iron"], rot=(math.pi / 2, 0, 0))
for k in range(6):
	stn = sphere("Stone", (-3.2 + (k % 3) * 0.33, WALL_Y - 0.95 + (k // 3) * 0.28, 0.76 + (k // 3) * 0.05), 0.13, M["stone_red"], (1, 0.85, 0.6))
	stn.rotation_euler = (rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), rng.uniform(0, 3))
	rk = stn.modifiers.new("Rough", "DISPLACE")
	rk.texture = bpy.data.textures.get("Chips") or bpy.data.textures.new("Chips", "VORONOI")
	rk.strength = 0.05
light("StoneWarmth", "POINT", (-2.85, WALL_Y - 1.1, 1.05), 6, (1.0, 0.18, 0.08), 0.4)
# a stone statue of an R6 alchemist mid-clap, on a plinth against the town (left, under the menu buttons)
SX, SY = -4.75, 10.5
box("Plinth", (SX, SY, 0.55), (1.3, 1.3, 1.1), M["wall"])
box("PlinthCap", (SX, SY, 1.15), (1.45, 1.45, 0.12), M["wall"])
box("PlinthFoot", (SX, SY, 0.06), (1.5, 1.5, 0.12), M["wall"])
plane("PlinthCircle", (SX, SY - 0.656, 0.6), 0.8, 0.8, M["chalk_circle"])
st, sparts = load_r6("Statue", (SX, SY, 1.21), 2.3)
dress(sparts, {"*": M["statue"]})
pose_r6(st, "clap")
light("StatueKey", "POINT", (SX + 1.1, SY - 1.6, 3.4), 70, (1.0, 0.66, 0.4), 0.3)
light("StatueRim", "POINT", (SX - 0.6, SY + 1.0, 4.2), 90, (1.0, 0.5, 0.25), 0.3)

# ---------- chains and a hanging lantern (near the camera, out of focus) ----------
def chain(a, b, sag, n):
	a, b = Vector(a), Vector(b)
	links = []
	for k in range(n):
		t = (k + 0.5) / n
		p = a.lerp(b, t) + Vector((0, 0, -math.sin(t * math.pi) * sag))
		t2 = (k + 1.5) / n
		q = a.lerp(b, t2) + Vector((0, 0, -math.sin(t2 * math.pi) * sag))
		d = (q - p).normalized()
		me = bpy.data.meshes.new("Link")
		bm = bmesh.new()
		bmesh.ops.create_cone(bm, cap_ends=False, segments=12, radius1=0.05, radius2=0.05, depth=0.001)
		bm.to_mesh(me)
		bm.free()
		o = bpy.data.objects.new("Link", me)
		o.location = p
		o.rotation_mode = "QUATERNION"
		o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d)
		o.scale = (1, 1.9, 1)
		sk = o.modifiers.new("Wire", "WIREFRAME")
		sk.thickness = 0.022
		me.materials.append(M["iron"])
		col.objects.link(o)
		links.append(o)
	return links


chain((-4.2, 4.0, 4.6), (-1.0, 4.2, 4.5), 0.8, 40)
chain((6.0, 4.5, 4.9), (10.5, 5.0, 4.6), 0.7, 40)
lx, ly, lz = 3.35, 4.6, 2.75
beam("LanternRod", (lx, ly, lz + 0.35), (lx, ly, 6.0), 0.03, M["iron"])
box("LanternTop", (lx, ly, lz + 0.3), (0.32, 0.32, 0.08), M["iron"])
box("LanternBase", (lx, ly, lz - 0.28), (0.3, 0.3, 0.07), M["iron"])
box("LanternGlass", (lx, ly, lz), (0.22, 0.22, 0.5), M["glass"])
for sx in (-1, 1):
	for sy in (-1, 1):
		box("LanternFrame", (lx + sx * 0.13, ly + sy * 0.13, lz), (0.035, 0.035, 0.58), M["iron"])
cyl("LanternCap", (lx, ly, lz + 0.42), 0.2, 0.02, 0.18, M["iron"], verts=4, rot=(0, 0, math.pi / 4))
light("Lantern", "POINT", (lx, ly - 0.05, lz), 55, (1.0, 0.6, 0.3), 0.12)

# ---------- beyond the wall: the viaduct, the train, the foundry town ----------
def viaduct(y, deck, x0, x1, span, pier):
	me = bpy.data.meshes.new("Viaduct")
	bm = bmesh.new()
	base = -14.0
	x = x0
	while x < x1:
		# a pier, then the arch over to the next pier
		for (a, b) in ((x, x + pier),):
			v = [bm.verts.new((a, 0, base)), bm.verts.new((b, 0, base)), bm.verts.new((b, 0, deck)), bm.verts.new((a, 0, deck))]
			bm.faces.new(v)
		ax0, ax1 = x + pier, x + span
		r = (ax1 - ax0) / 2
		cx = (ax0 + ax1) / 2
		spring = deck - r - 2.2
		n = 16
		prev_in = prev_top = None
		for k in range(n + 1):
			a = math.pi * (1 - k / n)
			pin = bm.verts.new((cx + math.cos(a) * r, 0, spring + math.sin(a) * r))
			ptop = bm.verts.new((cx + math.cos(a) * r, 0, deck))
			if prev_in:
				bm.faces.new((prev_in, pin, ptop, prev_top))
			prev_in, prev_top = pin, ptop
		for (a, b) in ((ax0, ax0 + 0.001),):
			pass
		x += span
	# the deck parapet
	v = [bm.verts.new((x0, 0, deck)), bm.verts.new((x1, 0, deck)), bm.verts.new((x1, 0, deck + 1.6)), bm.verts.new((x0, 0, deck + 1.6))]
	bm.faces.new(v)
	bm.to_mesh(me)
	bm.free()
	o = bpy.data.objects.new("Viaduct", me)
	o.location = (0, y, 0)
	so = o.modifiers.new("Thick", "SOLIDIFY")
	so.thickness = 5.0
	me.materials.append(M["viaduct"])
	col.objects.link(o)
	return o


VY, VDECK = 78.0, 15.0
viaduct(VY, VDECK, -90, 130, 16, 3.5)
# the train crossing (left of centre): carriages with lit windows, a headlamp
for k in range(5):
	cx = -34 + k * 7.6
	box("Carriage", (cx, VY - 1.5, VDECK + 3.3), (7.0, 3.0, 3.0), M["train"])
	box("CarriageRoof", (cx, VY - 1.5, VDECK + 4.9), (7.2, 3.2, 0.25), M["train"])
	for wv in range(5):
		box("TrainWindow", (cx - 2.6 + wv * 1.3, VY - 3.02, VDECK + 3.6), (0.7, 0.05, 0.8), M["window"])
box("Engine", (4.5, VY - 1.5, VDECK + 3.0), (8.0, 3.0, 2.6), M["train"])
cyl("EngineStack", (6.5, VY - 1.5, VDECK + 5.0), 0.5, 0.4, 1.6, M["train"])
sphere("Headlamp", (8.6, VY - 1.5, VDECK + 3.2), 0.4, M["bulb"])
light("HeadlampLight", "SPOT", (8.8, VY - 1.5, VDECK + 3.2), 9000, (1.0, 0.8, 0.55), 0.3, rot=(0, math.pi / 2, 0), spot=30)

town = []
windows = []
for _ in range(170):
	x = rng.uniform(-110, 150)
	y = rng.uniform(95, 230)
	w, d, h = rng.uniform(6, 15), rng.uniform(6, 12), rng.uniform(6, 22)
	town.append(box("House", (x, y, -14 + h / 2 + 10), (w, d, h), M["town"]))
	top = -4 + h
	if rng.random() < 0.6:
		town.append(box("Roof", (x, y, top), (w * 1.02, d * 0.72, d * 0.72), M["soot"], rot=(math.pi / 4, 0, 0)))
	for _ in range(rng.randint(0, 5)):
		windows.append(box("Win", (x + rng.uniform(-w / 2 + 1, w / 2 - 1), y - d / 2 - 0.05, top - rng.uniform(1.5, h * 0.7)), (0.8, 0.1, 1.2), M["window"]))
join(town, "Town")
if windows:
	join(windows, "TownWindows")
stacks = []
for x, y, h in ((-60, 150, 62), (-48, 160, 54), (-8, 120, 70), (4, 128, 64), (16, 118, 74), (72, 140, 66), (86, 150, 58)):
	cyl("Stack", (x, y, -14 + h / 2), 3.2, 2.2, h, M["soot"])
	cyl("StackLip", (x, y, -14 + h), 2.6, 2.6, 1.2, M["iron"])
	stacks.append((x, y, -14 + h))
# the great foundry: a long shed with a sawtooth roof and open furnace doors
fx, fy = 8, 104
box("FoundryShed", (fx, fy, 2), (70, 22, 32), M["soot"])
for k in range(12):
	box("Sawtooth", (fx - 33 + k * 6, fy, 19.5), (6, 21, 6), M["soot"], rot=(0, math.pi / 4, 0))
for k in range(4):
	box("FurnaceDoor", (fx - 24 + k * 16, fy - 11.1, 8), (5, 0.3, 9), M["furnace"])
	light("FurnaceGlow", "POINT", (fx - 24 + k * 16, fy - 16, 10), 45000, (1.0, 0.36, 0.08), 3.0)
# the State's buildings over the roofs: a clock tower and a domed Authority hall
tx, ty = -26, 112
box("ClockTower", (tx, ty, 14), (7, 7, 56), M["town"])
box("TowerBelfry", (tx, ty, 44), (8, 8, 6), M["soot"])
cyl("TowerSpire", (tx, ty, 53), 5.5, 0.2, 12, M["soot"], verts=4, rot=(0, 0, math.pi / 4))
plane("TowerClock", (tx, ty - 4.05, 38), 5.0, 5.0, image_mat("TowerClockFace", os.path.join(TEX, "clock.png"), emit=True, strength=3.0))
light("TowerClockLight", "POINT", (tx, ty - 7, 38), 3000, (1.0, 0.8, 0.55), 1.0)
hx, hy = 52, 136
box("AuthorityHall", (hx, hy, 4), (40, 24, 36), M["town"])
for k in range(8):
	box("HallColumn", (hx - 17 + k * 4.9, hy - 12.6, 8), (1.4, 1.4, 22), M["town"])
cyl("HallDrum", (hx, hy, 25), 9, 9, 6, M["town"], verts=48)
sphere("HallDome", (hx, hy, 28), 9.2, M["soot"], (1, 1, 0.75))
cyl("HallLantern", (hx, hy, 36.5), 1.2, 1.0, 3.0, M["soot"])

# ---------- sky, smoke, sigil, haze ----------
world = bpy.data.worlds.new("Dusk")
scene.world = world
world.use_nodes = True
wn = world.node_tree
bg = wn.nodes["Background"]
tc = wn.nodes.new("ShaderNodeTexCoord")
sep = wn.nodes.new("ShaderNodeSeparateXYZ")
ramp = wn.nodes.new("ShaderNodeValToRGB")
cr = ramp.color_ramp
cr.elements[0].position = 0.0
cr.elements[0].color = (0.6, 0.2, 0.045, 1)
cr.elements[1].position = 0.42
cr.elements[1].color = (0.006, 0.005, 0.007, 1)
e = cr.elements.new(0.06)
e.color = (0.42, 0.13, 0.04, 1)
e = cr.elements.new(0.13)
e.color = (0.045, 0.02, 0.018, 1)
mr = wn.nodes.new("ShaderNodeMapRange")
mr.inputs["From Min"].default_value = -0.02
mr.inputs["From Max"].default_value = 1.0
wn.links.new(tc.outputs["Generated"], sep.inputs["Vector"])
wn.links.new(sep.outputs["Z"], mr.inputs["Value"])
wn.links.new(mr.outputs["Result"], ramp.inputs["Fac"])
wn.links.new(ramp.outputs["Color"], bg.inputs["Color"])
bg.inputs["Strength"].default_value = 0.4
light("DuskSun", "SUN", (0, 0, 0), 0.3, (1.0, 0.5, 0.25), 0.05, rot=(math.radians(-84), 0, math.radians(180)))


def volume_mat(name, density, color, noise_scale, threshold, emit=None, emit_strength=0.0, aniso=0.25):
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	nt = m.node_tree
	nt.nodes.remove(nt.nodes["Principled BSDF"])
	out = nt.nodes["Material Output"]
	pv = nt.nodes.new("ShaderNodeVolumePrincipled")
	pv.inputs["Color"].default_value = (*color, 1)
	pv.inputs["Anisotropy"].default_value = aniso
	if emit:
		pv.inputs["Emission Color"].default_value = (*emit, 1)
		pv.inputs["Emission Strength"].default_value = emit_strength
	tcn = nt.nodes.new("ShaderNodeTexCoord")
	nz = nt.nodes.new("ShaderNodeTexNoise")
	nz.inputs["Scale"].default_value = noise_scale
	nz.inputs["Detail"].default_value = 6
	nz.inputs["Roughness"].default_value = 0.6
	mr2 = nt.nodes.new("ShaderNodeMapRange")
	mr2.inputs["From Min"].default_value = threshold
	mr2.inputs["From Max"].default_value = 0.85
	mr2.inputs["To Min"].default_value = 0.0
	mr2.inputs["To Max"].default_value = density
	nt.links.new(tcn.outputs["Object"], nz.inputs["Vector"])
	nt.links.new(nz.outputs["Fac"], mr2.inputs["Value"])
	nt.links.new(mr2.outputs["Result"], pv.inputs["Density"])
	nt.links.new(pv.outputs["Volume"], out.inputs["Volume"])
	return m


# near haze (light shafts in the hall), far smoke banks over the town, a plume over each stack
hz = box("HallHaze", (2, 7, 3.5), (30, 14, 7.2), volume_mat("Haze", 0.014, (0.8, 0.75, 0.7), 0.25, 0.25, aniso=0.55))
smog = box("SmokeBanks", (10, 160, 52), (420, 190, 70), volume_mat("Smog", 0.005, (0.3, 0.27, 0.27), 1.9, 0.52, (0.5, 0.18, 0.06), 0.002, 0.0))
for x, y, top in stacks:
	pl = box("Plume", (x + 10, y + 6, top + 22), (24, 18, 46), volume_mat("Plume", 0.06, (0.2, 0.18, 0.18), 1.4, 0.38, (0.6, 0.2, 0.05), 0.01, 0.1), rot=(0, math.radians(-22), 0))
# an ancient Mezarath circle in the smoke, the dull red of buried debt (Lore Bible: their circles still lie under the land)
ancient = image_mat("AncientCircle", os.path.join(TEX, "circle_ancient.png"), emit=True, strength=2.2, tint=(1.0, 0.12, 0.07))
ancient.surface_render_method = "BLENDED" if hasattr(ancient, "surface_render_method") else ancient.blend_method
plane("AncientCircleSky", (6, 150, 60), 62, 62, ancient)

# light shafts falling through the roof (a spot high up-left, shadowed by the trusses)
light("RoofShaft", "SPOT", (-3.5, 4.0, 14), 9000, (1.0, 0.72, 0.48), 0.25, rot=(math.radians(22), math.radians(-24), 0), spot=15)
light("CameraFill", "AREA", (1, -1.5, 2.2), 14, (0.65, 0.7, 0.85), 4.0, rot=(math.radians(90), 0, 0), shadow=False)

# ---------- embers ----------
ember_m = mat("Ember", (1, 0.3, 0.05), 0.5, 0, (1.0, 0.35, 0.06), 60.0)
ico = bpy.data.meshes.new("EmberMesh")
bm = bmesh.new()
bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.012)
bm.to_mesh(ico)
bm.free()
ico.materials.append(ember_m)
ember = bpy.data.objects.new("Ember", ico)
ember.location = (0, -50, -50)
col.objects.link(ember)
emitter = box("EmberSource", (2, 8, 0.3), (18, 10, 0.1), M["iron"])
emitter.hide_render = True
ps = emitter.modifiers.new("Embers", "PARTICLE_SYSTEM").particle_system.settings
ps.count = 900
ps.frame_start, ps.frame_end = -200, 200
ps.lifetime = 160
ps.lifetime_random = 0.6
ps.normal_factor = 0.6
ps.factor_random = 0.5
ps.brownian_factor = 0.4
ps.effector_weights.gravity = -0.03
ps.render_type = "OBJECT"
ps.instance_object = ember
ps.particle_size = 1.0
ps.size_random = 0.8
emitter.show_instancer_for_render = False

# ---------- camera ----------
cd = bpy.data.cameras.new("MenuCam")
cd.lens = 28
cd.sensor_width = 36
cd.shift_y = 0.141
cd.dof.use_dof = True
cd.dof.focus_distance = WALL_Y - 0.2
cd.dof.aperture_fstop = 2.4
cd.clip_end = 1500
cam = bpy.data.objects.new("MenuCam", cd)
cam.location = (0.8, 0.0, 1.7)
cam.rotation_euler = (math.radians(90), 0, 0)
col.objects.link(cam)
scene.camera = cam

# ---------- render settings (Blender 5.2) ----------
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 1920, 1080
scene.render.resolution_percentage = PCT
scene.render.film_transparent = False
ee = scene.eevee
ee.taa_render_samples = SAMPLES
ee.volumetric_start = 0.5
ee.volumetric_end = 400
ee.volumetric_tile_size = "4"
ee.volumetric_samples = 96
for attr, val in (("use_volumetric_shadows", True), ("volumetric_shadow_samples", 32), ("use_shadows", True), ("use_raytracing", True),
		("volumetric_ray_depth", 8), ("shadow_resolution_scale", 1.0), ("shadow_pool_size", "1024")):
	if hasattr(ee, attr):
		setattr(ee, attr, val)
scene.view_settings.view_transform = "AgX"
for look in ("AgX - Punchy", "Punchy", "AgX - Medium High Contrast"):
	try:
		scene.view_settings.look = look
		break
	except TypeError:
		pass
scene.view_settings.exposure = -0.2
scene.render.image_settings.file_format = "PNG"
scene.render.use_compositing = True


def set_menu(sock, options):
	"""Set a menu socket to the first option this Blender accepts."""
	for o in options:
		try:
			sock.default_value = o
			return o
		except (TypeError, ValueError):
			pass
	print("menu socket: none of", options, "accepted by", sock.name)


# ---------- compositor: the paint-over (a node group in 5.x) ----------
ng = bpy.data.node_groups.new("RenseiPaintOver", "CompositorNodeTree")
ng.interface.new_socket(name="Image", in_out="OUTPUT", socket_type="NodeSocketColor")
rl = ng.nodes.new("CompositorNodeRLayers")
rl.scene = scene
ku = ng.nodes.new("CompositorNodeKuwahara")
set_menu(ku.inputs["Type"], ("Anisotropic", "ANISOTROPIC"))
ku.inputs["Size"].default_value = 5
ku.inputs["Uniformity"].default_value = 4
ku.inputs["Sharpness"].default_value = 0.6
ku.inputs["Eccentricity"].default_value = 1.2
ku.inputs["High Precision"].default_value = True
gl = ng.nodes.new("CompositorNodeGlare")
set_menu(gl.inputs["Type"], ("Fog Glow", "FOG_GLOW", "Bloom", "BLOOM"))
set_menu(gl.inputs["Quality"], ("High", "HIGH"))
gl.inputs["Threshold"].default_value = 0.9
gl.inputs["Strength"].default_value = 0.9
go = ng.nodes.new("NodeGroupOutput")
ng.links.new(rl.outputs["Image"], ku.inputs["Image"])
ng.links.new(ku.outputs["Image"], gl.inputs["Image"])
ng.links.new(gl.outputs["Image"], go.inputs["Image"])
try:  # the unpainted render too, for comparison
	fo = ng.nodes.new("CompositorNodeOutputFile")
	fo.directory = OUT
	fo.file_name = "scene_raw"
	if hasattr(fo.format, "media_type"):
		fo.format.media_type = "IMAGE"
	fo.format.file_format = "PNG"
	fo.file_output_items.new("RGBA", "Image")
	ng.links.new(rl.outputs["Image"], fo.inputs[0])
except Exception as e:
	print("raw output skipped:", e)
scene.compositing_node_group = ng

if BAKE:
	# tileable PBR maps of the scene's materials, for Roblox MaterialVariants (menu_bake.py)
	import runpy
	runpy.run_path(os.path.join(os.path.dirname(os.path.abspath(__file__)), "menu_bake.py"), init_globals=globals())
elif EXPORT:
	# the Roblox export: the parts, lights, decals and markers, and the painted backdrop (menu_export.py)
	import runpy
	runpy.run_path(os.path.join(os.path.dirname(os.path.abspath(__file__)), "menu_export.py"), init_globals=globals())
elif ANIM:
	# the animated preview: menu_anim.py drives the scene frame by frame (it runs in this script's namespace)
	import runpy
	runpy.run_path(os.path.join(os.path.dirname(os.path.abspath(__file__)), "menu_anim.py"), init_globals=globals())
else:
	# step the embers' simulation to mid-flight
	for f in range(-200, 61, 4):
		scene.frame_set(f)
	scene.frame_set(60)
	scene.render.filepath = os.path.join(OUT, "scene_painted.png")
	bpy.ops.render.render(write_still=True, scene=scene.name)
if SAVE:
	bpy.ops.wm.save_as_mainfile(filepath=SAVE, copy=True)
print("RENSEI_MENU_DONE", OUT)

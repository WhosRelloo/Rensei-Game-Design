"""Bake the diorama's Blender materials into tileable PBR maps for Roblox MaterialVariants (owner 2026-10-28: "Make sure
the blender textures are the same in roblox as well. I don't want a quality downgrade on it").

Run through menu_scene.py, in its namespace (the materials in M are the scene's own):
    blender -b --factory-startup -P Art/MainMenu/menu_scene.py -- --bake [--out E:/Rensei/Renders/MainMenu/upload]
then make them seamless and painted with:  python Art/MainMenu/finish_maps.py

Each material is baked (Cycles) on a plane of one tile, laid the way the material is used (walls upright in X-Z, the
floor flat in X-Y), so its object coordinates match the scene's. Tiles are whole numbers of bricks so the coursing
repeats; the noise is made seamless afterwards. Writes OUT/raw_<key>_{color,normal,roughness,metalness}.png (1024 px,
Roblox's limit) and OUT/materials.json (the tile size in studs for each MaterialVariant's StudsPerTile).
"""
import json

RES = 1024
# key: (material, tile width m, tile height m, upright, Roblox base material)
BAKES = {
	"WallStone": (M["wall"], 2.0, 18 * 0.24 / 2.2, True, "Brick"),  # 8 bricks x 18 rows
	"Flagstones": (M["floor"], 5 * 0.6 / 0.7, 6 * 0.5 / 0.7, False, "Slate"),  # 5 x 6 flags (square)
	"StatueStone": (M["statue"], 8 * 0.9 / 6.0, 8 * 0.9 / 6.0, True, "Slate"),
	"Iron": (M["iron"], 2.0, 2.0, True, "Metal"),
	"RustIron": (M["rust"], 2.0, 2.0, True, "CorrodedMetal"),
}

scene.render.engine = "CYCLES"
cy = scene.cycles
cy.samples = 24
cy.use_denoising = False
try:
	prefs = bpy.context.preferences.addons["cycles"].preferences
	prefs.refresh_devices()
	for kind in ("OPTIX", "CUDA", "HIP", "ONEAPI"):
		try:
			prefs.compute_device_type = kind
			if any(d.type == kind for d in prefs.devices):
				for d in prefs.devices:
					d.use = True
				cy.device = "GPU"
				break
		except TypeError:
			pass
except Exception as e:
	print("bake: CPU (", e, ")")
bk = scene.render.bake
bk.margin = 0
bk.use_clear = True
bk.normal_space = "TANGENT"


def bake_plane(name, w, h, upright):
	me = bpy.data.meshes.new(name)
	bm = bmesh.new()
	uv = bm.loops.layers.uv.new()
	pts = [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]
	vs = [bm.verts.new((x, 0, y) if upright else (x, y, 0)) for x, y in pts]
	f = bm.faces.new(vs if not upright else list(reversed(vs)))
	for loop in f.loops:
		co = loop.vert.co
		u = co.x / w + 0.5
		v = (co.z if upright else co.y) / h + 0.5
		loop[uv].uv = (u, v)
	bm.to_mesh(me)
	bm.free()
	o = bpy.data.objects.new(name, me)
	col.objects.link(o)
	return o


def bake_one(o, mat, kind, path):
	nt = mat.node_tree
	img = bpy.data.images.new(os.path.basename(path), RES, RES, alpha=False, float_buffer=(kind == "normal"))
	if kind != "color":
		img.colorspace_settings.name = "Non-Color"
	node = nt.nodes.new("ShaderNodeTexImage")
	node.image = img
	for n in nt.nodes:
		n.select = False
	node.select = True
	nt.nodes.active = node
	out = nt.nodes["Material Output"]
	b = nt.nodes["Principled BSDF"]
	restore = None
	if kind == "metalness":  # bake it as emission: the Metallic input's source into an Emission shader
		em = nt.nodes.new("ShaderNodeEmission")
		src = b.inputs["Metallic"].links[0].from_socket if b.inputs["Metallic"].is_linked else None
		if src:
			nt.links.new(src, em.inputs["Color"])
		else:
			v = b.inputs["Metallic"].default_value
			em.inputs["Color"].default_value = (v, v, v, 1)
		old = out.inputs["Surface"].links[0].from_socket
		nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
		restore = (old, em)
	bpy.ops.object.select_all(action="DESELECT")
	o.select_set(True)
	bpy.context.view_layer.objects.active = o
	if kind == "color":
		bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"})
	elif kind == "roughness":
		bpy.ops.object.bake(type="ROUGHNESS")
	elif kind == "normal":
		bpy.ops.object.bake(type="NORMAL")
	else:
		bpy.ops.object.bake(type="EMIT")
	img.filepath_raw = path
	img.file_format = "PNG"
	img.save()
	if restore:
		nt.links.new(restore[0], out.inputs["Surface"])
		nt.nodes.remove(restore[1])
	nt.nodes.remove(node)


info = {}
for key, (mat, w, h, upright, base) in BAKES.items():
	o = bake_plane("Bake_" + key, w, h, upright)
	o.data.materials.append(mat)
	for kind in ("color", "normal", "roughness", "metalness"):
		bake_one(o, mat, kind, os.path.join(OUT, f"raw_{key}_{kind}.png"))
		print("baked", key, kind, flush=True)
	info[key] = {"base": base, "studs_per_tile": round(w * 2.7, 3), "tile_m": [round(w, 4), round(h, 4)]}
	bpy.data.objects.remove(o, do_unlink=True)
with open(os.path.join(OUT, "materials.json"), "w") as fh:
	json.dump(info, fh, indent=1)
print("RENSEI_BAKE", list(info))

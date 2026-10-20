"""Lindenmoor build: shared helpers (materials, primitives, scene).
1 Blender unit = 1 Roblox stud. Every size is a PROPOSAL from the world map concept.
Textures: CC0 Poly Haven sets in ../textures (fetch_textures.py)."""
import bpy, bmesh, math, os, random
from mathutils import Vector, Euler, noise

HERE = os.path.dirname(os.path.abspath(__file__))
TEX = os.path.normpath(os.path.join(HERE, "..", "textures"))
SCENE = "Lindenmoor_v2"
ROOT = "Lindenmoor_v2"


def scene():
    return bpy.data.scenes[SCENE]


def reset_scene():
    if SCENE in bpy.data.scenes:
        old = bpy.data.scenes[SCENE]
        for o in list(old.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.scenes.remove(old)
    for c in list(bpy.data.collections):
        if c.users == 0:
            bpy.data.collections.remove(c)
    for m in list(bpy.data.meshes):
        if m.users == 0:
            bpy.data.meshes.remove(m)
    s = bpy.data.scenes.new(SCENE)
    bpy.context.window.scene = s
    root = bpy.data.collections.new(ROOT)
    s.collection.children.link(root)
    return s


def coll(name):
    s = scene()
    root = bpy.data.collections[ROOT]
    for c in root.children:
        if c.name.split(".")[0] == name:
            return c
    c = bpy.data.collections.new(name)
    root.children.link(c)
    return c


def link(o, c):
    for x in list(o.users_collection):
        x.objects.unlink(o)
    c.objects.link(o)
    return o


def clear_coll(name):
    c = coll(name)
    for o in list(c.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    return c


# ---------------- materials ----------------
def _img(path, non_color):
    img = bpy.data.images.load(path, check_existing=True)
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    return img


def pbr(name, tex_id, tile=8.0, tint=None, value=1.0, rough_mul=1.0, bump=0.35, moss=None, moss_amount=0.55,
        variation=0.18, emission=None):
    """Box-projected PBR material in object space (tile = studs per texture repeat).
    moss = another texture id blended onto up-facing surfaces (the mossy-top look of the refs)."""
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    L = nt.links.new
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    coord = nt.nodes.new("ShaderNodeTexCoord")
    mapn = nt.nodes.new("ShaderNodeMapping")
    mapn.inputs["Scale"].default_value = (1 / tile, 1 / tile, 1 / tile)
    L(coord.outputs["Object"], mapn.inputs["Vector"])

    def tex(tid, kind, non_color):
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = _img(os.path.join(TEX, tid, f"{kind}.jpg"), non_color)
        n.projection = "BOX"
        n.projection_blend = 0.25
        L(mapn.outputs["Vector"], n.inputs["Vector"])
        return n

    diff = tex(tex_id, "diff", False)
    rough = tex(tex_id, "rough", True)
    disp = tex(tex_id, "disp", True)
    nor = tex(tex_id, "nor", True)
    color = diff.outputs["Color"]
    # per-object hue/value variation so repeated pieces never look cloned
    info = nt.nodes.new("ShaderNodeObjectInfo")
    hsv = nt.nodes.new("ShaderNodeHueSaturation")
    rnd = nt.nodes.new("ShaderNodeMapRange")
    rnd.inputs["To Min"].default_value = value * (1 - variation)
    rnd.inputs["To Max"].default_value = value * (1 + variation * 0.5)
    L(info.outputs["Random"], rnd.inputs["Value"])
    L(rnd.outputs["Result"], hsv.inputs["Value"])
    L(color, hsv.inputs["Color"])
    color = hsv.outputs["Color"]
    if tint:
        mixt = nt.nodes.new("ShaderNodeMix")
        mixt.data_type = "RGBA"
        mixt.blend_type = "MULTIPLY"
        mixt.inputs["Factor"].default_value = 1.0
        mixt.inputs[7].default_value = (*tint, 1)
        L(color, mixt.inputs[6])
        color = mixt.outputs[2]
    rmul = nt.nodes.new("ShaderNodeMath")
    rmul.operation = "MULTIPLY"
    rmul.inputs[1].default_value = rough_mul
    rmul.use_clamp = True
    L(rough.outputs["Color"], rmul.inputs[0])
    roughness = rmul.outputs[0]
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nmap.inputs["Strength"].default_value = 1.0
    L(nor.outputs["Color"], nmap.inputs["Color"])
    bmp = nt.nodes.new("ShaderNodeBump")
    bmp.inputs["Strength"].default_value = bump
    bmp.inputs["Distance"].default_value = 0.4
    L(disp.outputs["Color"], bmp.inputs["Height"])
    L(nmap.outputs["Normal"], bmp.inputs["Normal"])
    normal = bmp.outputs["Normal"]
    if moss:
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        L(geo.outputs["Normal"], sep.inputs["Vector"])
        noi = nt.nodes.new("ShaderNodeTexNoise")
        noi.inputs["Scale"].default_value = 0.35
        noi.inputs["Detail"].default_value = 4
        L(coord.outputs["Object"], noi.inputs["Vector"])
        add = nt.nodes.new("ShaderNodeMath")
        add.operation = "ADD"
        L(sep.outputs["Z"], add.inputs[0])
        sub = nt.nodes.new("ShaderNodeMath")
        sub.operation = "MULTIPLY"
        sub.inputs[1].default_value = 0.6
        L(noi.outputs["Fac"], sub.inputs[0])
        L(sub.outputs[0], add.inputs[1])
        mr = nt.nodes.new("ShaderNodeMapRange")
        mr.inputs["From Min"].default_value = 1.0 - moss_amount * 0.45
        mr.inputs["From Max"].default_value = 1.2 - moss_amount * 0.3
        L(add.outputs[0], mr.inputs["Value"])
        mdiff = tex(moss, "diff", False)
        mrough = tex(moss, "rough", True)
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        L(mr.outputs["Result"], mix.inputs["Factor"])
        L(color, mix.inputs[6])
        L(mdiff.outputs["Color"], mix.inputs[7])
        color = mix.outputs[2]
        mixr = nt.nodes.new("ShaderNodeMix")
        mixr.data_type = "FLOAT"
        L(mr.outputs["Result"], mixr.inputs["Factor"])
        L(roughness, mixr.inputs[2])
        L(mrough.outputs["Color"], mixr.inputs[3])
        roughness = mixr.outputs[0]
    L(color, bsdf.inputs["Base Color"])
    L(roughness, bsdf.inputs["Roughness"])
    L(normal, bsdf.inputs["Normal"])
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission[0], 1)
        bsdf.inputs["Emission Strength"].default_value = emission[1]
    L(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return m


def flat(name, color, rough=0.6, metal=0.0, emit=None, transmission=0.0, alpha=1.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if transmission:
        b.inputs["Transmission Weight"].default_value = transmission
    if emit:
        b.inputs["Emission Color"].default_value = (*emit[0], 1)
        b.inputs["Emission Strength"].default_value = emit[1]
    return m


def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def materials():
    M = {}
    M["grass_ground"] = pbr("LM_GrassGround", "leafy_grass", tile=10, tint=srgb("#8fb062"), value=0.85, bump=0.3, variation=0.05)
    M["path"] = pbr("LM_DirtPath", "stony_dirt_path", tile=8, bump=0.6, variation=0.05)
    M["cobble"] = pbr("LM_Cobble", "mossy_cobblestone", tile=7, bump=0.7, variation=0.05)
    M["rock"] = pbr("LM_MossyRock", "mossy_rock", tile=9, bump=0.8, moss="leafy_grass", moss_amount=0.55)
    M["cliff"] = pbr("LM_Cliff", "cliff_side", tile=16, bump=0.9, moss="leafy_grass", moss_amount=0.6)
    M["stonebase"] = pbr("LM_StoneBase", "stacked_stone_wall", tile=7, bump=0.8, moss="sparse_grass", moss_amount=0.3, variation=0.1)
    M["fieldwall"] = pbr("LM_FieldWallStone", "mossy_stone_wall", tile=5, bump=0.8, moss="leafy_grass", moss_amount=0.5)
    M["plaster"] = pbr("LM_Plaster", "plastered_wall_04", tile=9, tint=srgb("#efe4cc"), bump=0.35, variation=0.08)
    M["timber"] = pbr("LM_Timber", "medieval_wood", tile=6, tint=srgb("#8a6a52"), bump=0.5, variation=0.15)
    M["planks"] = pbr("LM_Planks", "brown_planks_05", tile=5, bump=0.5)
    M["roof"] = pbr("LM_RoofTiles", "clay_roof_tiles_02", tile=6, bump=0.9, moss="leafy_grass", moss_amount=0.15, variation=0.12)
    M["bark"] = pbr("LM_Bark", "bark_brown_02", tile=4, bump=1.0, moss="leafy_grass", moss_amount=0.25)
    M["hay"] = pbr("LM_Hay", "thatch_roof_angled", tile=4, tint=srgb("#f2d488"), bump=0.6, variation=0.12)
    M["iron"] = flat("LM_Iron", srgb("#2b2a28"), rough=0.45, metal=0.9)
    M["glass"] = flat("LM_WindowGlass", srgb("#1d2a2c"), rough=0.08, metal=0.0)
    M["glow"] = flat("LM_LanternGlow", srgb("#ffb35c"), rough=0.4, emit=(srgb("#ffad4d"), 18))
    M["water"] = flat("LM_Water", srgb("#18302f"), rough=0.04)
    M["dummy"] = flat("LM_R6Dummy", srgb("#c8c8c8"), rough=0.5)
    M["rope"] = flat("LM_Rope", srgb("#8a7650"), rough=0.9)
    M["cloth"] = flat("LM_Cloth", srgb("#6c2f25"), rough=0.95)
    M["foliage"] = foliage_mat("LM_OakFoliage", srgb("#2f4f22"), srgb("#6c8f3b"))
    M["cypress"] = foliage_mat("LM_CypressFoliage", srgb("#1a3020"), srgb("#36553a"))
    M["blade"] = blade_mat("LM_GrassBlade", srgb("#2c4a1e"), srgb("#8fae55"))
    M["wheat"] = blade_mat("LM_WheatStalk", srgb("#7a6a35"), srgb("#e2c47a"))
    M["flower_w"] = flat("LM_FlowerWhite", srgb("#e9e4d6"), rough=0.7)
    M["flower_y"] = flat("LM_FlowerYellow", srgb("#e0b83a"), rough=0.7)
    M["flower_p"] = flat("LM_FlowerViolet", srgb("#8a6cb0"), rough=0.7)
    return M


def foliage_mat(name, dark, light):
    """Clustered foliage: leafy breakup from noise, darker inside, translucent edges (stylised, not flat)."""
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    L = nt.links.new
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    b = nt.nodes.new("ShaderNodeBsdfPrincipled")
    coord = nt.nodes.new("ShaderNodeTexCoord")
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value = 1.6
    L(coord.outputs["Object"], vor.inputs["Vector"])
    noi = nt.nodes.new("ShaderNodeTexNoise")
    noi.inputs["Scale"].default_value = 0.4
    noi.inputs["Detail"].default_value = 5
    L(coord.outputs["Object"], noi.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*dark, 1)
    ramp.color_ramp.elements[1].color = (*light, 1)
    ramp.color_ramp.elements[0].position = 0.25
    ramp.color_ramp.elements[1].position = 0.85
    mixv = nt.nodes.new("ShaderNodeMath")
    mixv.operation = "MULTIPLY"
    L(vor.outputs["Distance"], mixv.inputs[0])
    L(noi.outputs["Fac"], mixv.inputs[1])
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    L(geo.outputs["Normal"], sep.inputs["Vector"])
    up = nt.nodes.new("ShaderNodeMapRange")
    up.inputs["From Min"].default_value = -1
    up.inputs["From Max"].default_value = 1
    up.inputs["To Min"].default_value = 0.55
    up.inputs["To Max"].default_value = 1.4
    L(sep.outputs["Z"], up.inputs["Value"])
    fac = nt.nodes.new("ShaderNodeMath")
    fac.operation = "MULTIPLY"
    L(mixv.outputs[0], fac.inputs[0])
    L(up.outputs["Result"], fac.inputs[1])
    L(fac.outputs[0], ramp.inputs["Fac"])
    L(ramp.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.75
    b.inputs["Subsurface Weight"].default_value = 0.15
    bmp = nt.nodes.new("ShaderNodeBump")
    bmp.inputs["Strength"].default_value = 0.8
    L(vor.outputs["Distance"], bmp.inputs["Height"])
    L(bmp.outputs["Normal"], b.inputs["Normal"])
    L(b.outputs["BSDF"], out.inputs["Surface"])
    return m


def blade_mat(name, root, tip):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    L = nt.links.new
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    b = nt.nodes.new("ShaderNodeBsdfPrincipled")
    coord = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    L(coord.outputs["Generated"], sep.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*root, 1)
    ramp.color_ramp.elements[1].color = (*tip, 1)
    L(sep.outputs["Z"], ramp.inputs["Fac"])
    info = nt.nodes.new("ShaderNodeObjectInfo")
    hsv = nt.nodes.new("ShaderNodeHueSaturation")
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["To Min"].default_value = 0.75
    mr.inputs["To Max"].default_value = 1.15
    L(info.outputs["Random"], mr.inputs["Value"])
    L(mr.outputs["Result"], hsv.inputs["Value"])
    L(ramp.outputs["Color"], hsv.inputs["Color"])
    L(hsv.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.7
    b.inputs["Subsurface Weight"].default_value = 0.2
    L(b.outputs["BSDF"], out.inputs["Surface"])
    return m


# ---------------- primitives ----------------
def box(name, size, loc, mat, c, rot=(0, 0, 0), bevel=0.15, segs=2, chip=0.0, seed=None):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    if chip > 0:
        rnd = random.Random(seed if seed is not None else hash(name))
        for v in bm.verts:
            v.co += Vector((rnd.uniform(-chip, chip), rnd.uniform(-chip, chip), rnd.uniform(-chip * 0.5, chip * 0.5)))
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    o.location = loc
    o.rotation_euler = rot
    if bevel > 0:
        b = o.modifiers.new("Bevel", "BEVEL")
        b.width = bevel
        b.segments = segs
        b.limit_method = "ANGLE"
        b.harden_normals = False
    me.materials.append(mat)
    c.objects.link(o)
    for p in me.polygons:
        p.use_smooth = False
    return o


def cyl(name, r, h, loc, mat, c, verts=16, rot=(0, 0, 0), r_top=None, bevel=0.05):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=verts, radius1=r, radius2=r if r_top is None else r_top, depth=h)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    o.location = loc
    o.rotation_euler = rot
    if bevel > 0:
        b = o.modifiers.new("Bevel", "BEVEL")
        b.width = bevel
        b.segments = 2
        b.limit_method = "ANGLE"
    me.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = True
    c.objects.link(o)
    return o


def displaced_rock(name, size, loc, mat, c, seed=1, strength=0.45, subd=3, flatten=1.0, rot=(0, 0, 0)):
    """A chunky, sculpted-looking boulder: subdivided cube, large-scale noise push + sharp strata, beveled."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=subd, use_grid_fill=True)
    rnd = random.Random(seed)
    off = Vector((rnd.uniform(0, 100), rnd.uniform(0, 100), rnd.uniform(0, 100)))
    for v in bm.verts:
        p = v.co.copy()
        n = p.normalized()
        # round the cube toward a slab-rock shape
        p = p.lerp(n * 0.62, 0.35)
        big = noise.noise(p * 1.6 + off)
        strata = math.floor((p.z + 0.5) * 4) / 4 - (p.z + 0.5) + 0.125
        p += n * (big * strength) + Vector((0, 0, strata * 0.25 * strength))
        v.co = Vector((p.x * size[0], p.y * size[1], p.z * size[2] * flatten))
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    o.location = loc
    o.rotation_euler = rot
    b = o.modifiers.new("Bevel", "BEVEL")
    b.width = 0.12
    b.segments = 1
    b.limit_method = "ANGLE"
    me.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = False
    c.objects.link(o)
    return o


def r6(at, c, mat, yaw=0):
    """R6 stand-in: 4 wide x 5 tall x 1 deep."""
    parts = [("Torso", (2, 1, 2), (0, 0, 3)), ("Head", (1.2, 1.2, 1), (0, 0, 4.5)), ("LArm", (1, 1, 2), (-1.5, 0, 3)),
             ("RArm", (1, 1, 2), (1.5, 0, 3)), ("LLeg", (1, 1, 2), (-0.5, 0, 1)), ("RLeg", (1, 1, 2), (0.5, 0, 1))]
    ca, sa = math.cos(yaw), math.sin(yaw)
    for n, s, p in parts:
        x, y = p[0] * ca - p[1] * sa, p[0] * sa + p[1] * ca
        box(f"R6_{n}_{at[0]:.0f}_{at[1]:.0f}", s, (at[0] + x, at[1] + y, at[2] + p[2]), mat, c, rot=(0, 0, yaw), bevel=0.04)

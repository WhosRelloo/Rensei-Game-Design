import bpy, bmesh, math, random
from mathutils import Vector, Euler

# Rensei style test: a Lindenmoor corner at R6 scale (1 Blender unit = 1 stud).
# Built in its own scene so the user's scene is untouched. Every size is a PROPOSAL from the map concept.
random.seed(7)
SCN = "Rensei_StyleTest"
if SCN in bpy.data.scenes:
    old = bpy.data.scenes[SCN]
    for o in list(old.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.scenes.remove(old)
for c in list(bpy.data.collections):
    if c.name.split(".")[0] in ("Lindenmoor_StyleTest", "Ground", "Rocks", "Trees", "Farmhouse", "Props", "Scale_R6") and c.users == 0:
        bpy.data.collections.remove(c)
scene = bpy.data.scenes.new(SCN)
bpy.context.window.scene = scene
root = bpy.data.collections.new("Lindenmoor_StyleTest")
scene.collection.children.link(root)

def col(name):
    c = bpy.data.collections.new(name)
    root.children.link(c)
    return c

C_GROUND, C_ROCK, C_TREE, C_HOUSE, C_PROPS, C_SCALE = (col(n) for n in
    ("Ground", "Rocks", "Trees", "Farmhouse", "Props", "Scale_R6"))

# ---------- materials (procedural PBR, stylised: big soft value variation, no flat colours) ----------
def mat(name, base, base2, rough=0.85, scale=0.15, bump=0.25, detail=3.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    tex = nt.nodes.new("ShaderNodeTexNoise")
    tex.inputs["Scale"].default_value = scale
    tex.inputs["Detail"].default_value = detail
    coord = nt.nodes.new("ShaderNodeTexCoord")
    nt.links.new(coord.outputs["Object"], tex.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*base, 1)
    ramp.color_ramp.elements[1].color = (*base2, 1)
    ramp.color_ramp.elements[0].position = 0.42
    ramp.color_ramp.elements[1].position = 0.78
    info = nt.nodes.new("ShaderNodeObjectInfo")
    mix = nt.nodes.new("ShaderNodeMath"); mix.operation = "ADD"
    jit = nt.nodes.new("ShaderNodeMath"); jit.operation = "MULTIPLY"; jit.inputs[1].default_value = 0.25
    nt.links.new(info.outputs["Random"], jit.inputs[0])
    nt.links.new(tex.outputs["Fac"], mix.inputs[0]); nt.links.new(jit.outputs[0], mix.inputs[1])
    nt.links.new(mix.outputs[0], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    bmp = nt.nodes.new("ShaderNodeBump")
    bmp.inputs["Strength"].default_value = bump
    fine = nt.nodes.new("ShaderNodeTexNoise")
    fine.inputs["Scale"].default_value = scale * 12
    fine.inputs["Detail"].default_value = 6
    nt.links.new(coord.outputs["Object"], fine.inputs["Vector"])
    nt.links.new(fine.outputs["Fac"], bmp.inputs["Height"])
    nt.links.new(bmp.outputs["Normal"], bsdf.inputs["Normal"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return m

def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)

M = {
    "grass": mat("RS_Grass", srgb("#2f4a27"), srgb("#6a8c45"), 0.95, 0.025, 0.2),
    "dirt": mat("RS_PackedDirt", srgb("#6b5338"), srgb("#8a6e4b"), 0.95, 0.12, 0.3),
    "stone": mat("RS_MossyStone", srgb("#5d5c55"), srgb("#3e4a32"), 0.9, 0.12, 0.7),
    "limestone": mat("RS_Limestone", srgb("#8f887a"), srgb("#5f5c52"), 0.85, 0.22, 0.6),
    "timber": mat("RS_Timber", srgb("#4a3424"), srgb("#6b4b31"), 0.8, 0.6, 0.35),
    "plaster": mat("RS_Plaster", srgb("#d8cdb5"), srgb("#b9ab8f"), 0.9, 0.35, 0.2),
    "roof": mat("RS_TerracottaTile", srgb("#7d3526"), srgb("#a04a32"), 0.8, 0.5, 0.5),
    "bark": mat("RS_Bark", srgb("#3b2c22"), srgb("#5a4535"), 0.9, 0.9, 0.6),
    "leaf": mat("RS_Foliage", srgb("#2f4a2a"), srgb("#4f7238"), 0.9, 0.3, 0.3),
    "cypress": mat("RS_CypressFoliage", srgb("#1f3324"), srgb("#30503a"), 0.9, 0.4, 0.3),
    "wheat": mat("RS_Wheat", srgb("#a8873e"), srgb("#c9a86a"), 0.9, 0.4, 0.2),
    "iron": mat("RS_Iron", srgb("#2b2b2b"), srgb("#4a3a30"), 0.6, 0.8, 0.3),
    "dummy": mat("RS_R6Dummy", srgb("#c9c9c9"), srgb("#b0b0b0"), 0.6, 0.2, 0.0),
    "ledge": mat("RS_LedgeStone", srgb("#8a8577"), srgb("#6e6a5e"), 0.85, 0.3, 0.4),
}
glow = bpy.data.materials.get("RS_LanternGlow") or bpy.data.materials.new("RS_LanternGlow")
glow.use_nodes = True
em = glow.node_tree.nodes.get("Principled BSDF")
em.inputs["Emission Color"].default_value = (1.0, 0.55, 0.18, 1)
em.inputs["Emission Strength"].default_value = 12

# ---------- helpers ----------
def box(name, size, loc, material, collection, rot=(0, 0, 0), bevel=0.25, segs=1):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        b = o.modifiers.new("Bevel", "BEVEL")
        b.width = bevel
        b.segments = segs
        b.limit_method = "ANGLE"
    o.data.materials.append(material)
    for c in o.users_collection:
        c.objects.unlink(o)
    collection.objects.link(o)
    return o

def chip(o, amount=0.35):
    # nudge vertices for a hand-sculpted, slightly irregular block (chunky, not faceted noise)
    me = o.data
    bm = bmesh.new()
    bm.from_mesh(me)
    for v in bm.verts:
        v.co += Vector((random.uniform(-amount, amount), random.uniform(-amount, amount), random.uniform(-amount * 0.5, amount * 0.5)))
    bm.to_mesh(me)
    bm.free()

def slab_stack(name, base, levels, collection, material, width=(8, 14), depth=(6, 10), height=(2.5, 4.5)):
    parts = []
    z = base.z
    for i in range(levels):
        w = random.uniform(*width) * (1 - i * 0.12)
        d = random.uniform(*depth) * (1 - i * 0.1)
        h = random.uniform(*height)
        off = Vector((random.uniform(-1.5, 1.5), random.uniform(-1.2, 1.2), 0))
        o = box(f"{name}_Slab{i + 1}", (w, d, h), base + off + Vector((0, 0, z - base.z + h / 2)), material, collection,
                rot=(random.uniform(-0.05, 0.05), random.uniform(-0.05, 0.05), random.uniform(-0.25, 0.25)), bevel=0.45, segs=2)
        chip(o, 0.3)
        z += h * 0.92
        parts.append(o)
    return parts, z

# ---------- ground ----------
bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0, 0))
g = bpy.context.active_object
g.name = "Ground_Grass"
g.scale = (220, 220, 1)
bpy.ops.object.transform_apply(scale=True)
sub = g.modifiers.new("Sub", "SUBSURF"); sub.levels = 0; sub.render_levels = 0
g.data.materials.append(M["grass"])
for c in g.users_collection: c.objects.unlink(g)
C_GROUND.objects.link(g)
# dirt path 10 wide (concept: lanes 10-12)
path = box("Path_Dirt", (10, 160, 0.3), (0, -10, 0.12), M["dirt"], C_GROUND, bevel=0.1)
# terrace steps (3-stud rises) on the left
for i in range(3):
    t = box(f"Terrace_{i + 1}", (40, 22 - i * 4, 3), (-38, 30 + i * 6, 1.5 + i * 3), M["grass"], C_GROUND, bevel=0.6, segs=2)
    w = box(f"Terrace_{i + 1}_Wheat", (36, 14 - i * 3, 1.2), (-38, 30 + i * 6, 3.6 + i * 3), M["wheat"], C_PROPS, bevel=0.3)

# ---------- field wall: 4 studs = the vault height ----------
x = -16
while x < 22:
    w1 = random.uniform(2.6, 4.6)
    s = box(f"FieldWall_Low_{x:.0f}", (w1, 1.9, 2.2), (x + w1 / 2, -18, 1.1), M["limestone"], C_PROPS,
            rot=(0, 0, random.uniform(-0.06, 0.06)), bevel=0.4, segs=2); chip(s, 0.22)
    x += w1 + 0.15
x = -15
while x < 21:
    w2 = random.uniform(2.2, 4.0)
    s = box(f"FieldWall_Top_{x:.0f}", (w2, 1.7, 1.8), (x + w2 / 2, -18 + random.uniform(-0.15, 0.15), 3.1), M["limestone"], C_PROPS,
            rot=(random.uniform(-0.05, 0.05), 0, random.uniform(-0.08, 0.08)), bevel=0.4, segs=2); chip(s, 0.22)
    x += w2 + 0.2

# ---------- rock outcrop with a ledge-walk strip (RenseiLedge: 1.2 deep, 7 above ground) ----------
rocks, top = slab_stack("Outcrop", Vector((50, 18, 0)), 5, C_ROCK, M["stone"], width=(14, 20), depth=(9, 12), height=(2.8, 3.6))
ledge = box("LEDGE_RenseiLedge_Outcrop", (12, 1.2, 0.8), (50, 11.6, 7), M["ledge"], C_ROCK, bevel=0.15)
ledge["RenseiLedge"] = True
ledge["Note"] = "authored ledge strip: tag RenseiLedge in Studio; wall gap 1; 7 studs up"

# ---------- oak: trunk 5 thick, layered slab canopy (ref 1) ----------
def oak(name, at, height=20, trunk=5):
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=trunk / 2, depth=height, location=(at.x, at.y, height / 2))
    t = bpy.context.active_object
    t.name = f"{name}_Trunk"
    bm = bmesh.new(); bm.from_mesh(t.data)
    for v in bm.verts:
        if v.co.z > 0:
            v.co.x *= 0.65; v.co.y *= 0.65
    bm.to_mesh(t.data); bm.free()
    t.modifiers.new("Bevel", "BEVEL").width = 0.3
    t.data.materials.append(M["bark"])
    for c in t.users_collection: c.objects.unlink(t)
    C_TREE.objects.link(t)
    for i, (w, z) in enumerate(((34, height - 3), (28, height + 1.5), (20, height + 6), (12, height + 10))):
        layer = box(f"{name}_Canopy{i + 1}", (w, w * random.uniform(0.75, 0.95), 4.2), (at.x + random.uniform(-2, 2), at.y + random.uniform(-2, 2), z),
                    M["leaf"], C_TREE, rot=(0, 0, random.uniform(0, 0.8)), bevel=0.9, segs=2)
        chip(layer, 0.6)
    for k in range(4):
        a = random.uniform(0, math.tau)
        r = random.uniform(5, 10)
        box(f"{name}_HangingRoot{k + 1}", (0.35, 0.35, random.uniform(4, 8)), (at.x + math.cos(a) * r, at.y + math.sin(a) * r, height - 6), M["bark"], C_TREE, bevel=0.05)

oak("Oak_A", Vector((-14, 40, 0)), height=26, trunk=6.5)

def cypress(name, at, h=26):
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.8, depth=6, location=(at.x, at.y, 3))
    t = bpy.context.active_object; t.name = f"{name}_Trunk"; t.data.materials.append(M["bark"])
    for c in t.users_collection: c.objects.unlink(t)
    C_TREE.objects.link(t)
    for i in range(6):
        w = 6.5 * (1 - i * 0.14)
        s = box(f"{name}_Tier{i + 1}", (w, w, h / 6 + 1), (at.x, at.y, 5 + i * (h / 6) + 1), M["cypress"], C_TREE,
                rot=(0, 0, random.uniform(0, 1)), bevel=0.7, segs=2)
        chip(s, 0.35)

for i, x in enumerate((-60, -48, 58, 70)):
    cypress(f"Cypress_{i + 1}", Vector((x, 70 + random.uniform(-6, 6), 0)))

# ---------- farmhouse: stone ground floor, timber/plaster upper, terracotta roof; door 6 x 9 ----------
hx, hy = 16, -2
box("House_StoneBase", (22, 16, 10), (hx, hy, 5), M["limestone"], C_HOUSE, bevel=0.4, segs=2)
box("House_Upper", (23, 17, 8), (hx, hy, 14), M["plaster"], C_HOUSE, bevel=0.3)
for i in range(5):
    box(f"House_Beam_V{i + 1}", (0.8, 17.4, 8.2), (hx - 11 + i * 5.5, hy, 14), M["timber"], C_HOUSE, bevel=0.1)
box("House_Beam_Floor", (23.6, 17.6, 1), (hx, hy, 10.2), M["timber"], C_HOUSE, bevel=0.15)
half, rise = 9.6, 6.0  # eave overhang 1.1 past the 17-deep upper floor; ridge 6 above the eaves
ang = math.atan2(rise, half)
slope = math.hypot(half, rise) + 0.6
for side in (-1, 1):
    box(f"House_Roof_{'L' if side < 0 else 'R'}", (27, slope, 1.3), (hx, hy + side * half / 2, 18 + rise / 2 + 0.4), M["roof"], C_HOUSE,
        rot=(-side * ang, 0, 0), bevel=0.3)
box("House_Ridge", (27.4, 1.2, 1.2), (hx, hy, 18 + rise + 0.7), M["timber"], C_HOUSE, bevel=0.15)
for side in (-1, 1):
    me = bpy.data.meshes.new(f"House_Gable_{side}")
    bm = bmesh.new()
    xs = (hx + side * 11.0, hx + side * 11.8)
    vs = []
    for x in xs:
        vs.append([bm.verts.new((x, hy - 8.5, 18)), bm.verts.new((x, hy + 8.5, 18)), bm.verts.new((x, hy, 18 + rise))])
    bm.faces.new(vs[0]); bm.faces.new(list(reversed(vs[1])))
    for i in range(3):
        a, b = vs[0][i], vs[0][(i + 1) % 3]; c2, d = vs[1][(i + 1) % 3], vs[1][i]
        bm.faces.new((a, b, c2, d))
    bm.normal_update(); bm.to_mesh(me); bm.free()
    go = bpy.data.objects.new(f"House_Gable_{'W' if side < 0 else 'E'}", me)
    go.data.materials.append(M["plaster"]); C_HOUSE.objects.link(go)
box("House_Chimney", (3, 3, 9), (hx + 7, hy + 3, 23), M["limestone"], C_HOUSE, bevel=0.3)
box("House_Door", (6, 0.6, 9), (hx - 4, hy - 8.2, 4.5), M["timber"], C_HOUSE, bevel=0.1)
for wx in (hx + 3, hx + 8):
    box(f"House_Window_{wx}", (3, 0.5, 3.5), (wx, hy - 8.3, 6), M["timber"], C_HOUSE, bevel=0.08)
box("House_Eave_Support", (26, 1, 0.8), (hx, hy - 8.8, 18), M["timber"], C_HOUSE, bevel=0.1)

# lantern by the door (the one warm practical)
box("Lantern_Bracket", (0.4, 1.6, 0.4), (hx - 8, hy - 9, 8.5), M["iron"], C_PROPS, bevel=0.05)
lan = box("Lantern_Glass", (0.9, 0.9, 1.3), (hx - 8, hy - 9.8, 7.8), glow, C_PROPS, bevel=0.1)
ld = bpy.data.lights.new("Lantern_Light", "POINT"); ld.energy = 2500; ld.color = (1.0, 0.62, 0.3); ld.shadow_soft_size = 0.6
lo = bpy.data.objects.new("Lantern_Light", ld); lo.location = (hx - 8, hy - 11, 7.8); C_PROPS.objects.link(lo)

# hay bales + barrel: cover for stealth (concept: cover every 20-25 studs)
for i, p in enumerate(((-4, -30), (-1, -33), (24, -26))):
    hb = box(f"HayBale_{i + 1}", (4, 3, 3), (p[0], p[1], 1.5), M["wheat"], C_PROPS, rot=(0, 0, random.uniform(0, 1)), bevel=0.5, segs=2)


# ---------- layering: stepped ground, path edging, grass clumps, foreground silhouettes ----------
for i, (cx, cy, w, d, h) in enumerate(((-70, -10, 50, 40, 2.5), (-62, 14, 34, 26, 4.5), (80, -20, 60, 50, 3), (72, 5, 40, 30, 5.5),
                                      (-30, 90, 120, 40, 6), (40, 95, 120, 40, 8))):
    st = box(f"GroundStep_{i + 1}", (w, d, h), (cx, cy, h / 2), M["grass"], C_GROUND, rot=(0, 0, random.uniform(-0.2, 0.2)), bevel=0.8, segs=2)
    chip(st, 0.5)
for side in (-1, 1):
    y = -60
    while y < 40:
        s = random.uniform(1.4, 2.6)
        e = box(f"PathEdge_{side}_{y:.0f}", (s, s * 0.9, s * 0.55), (side * random.uniform(5.6, 6.6), y, s * 0.2), M["stone"], C_GROUND,
                rot=(0, 0, random.uniform(0, 1)), bevel=0.35, segs=2); chip(e, 0.2)
        y += random.uniform(3.5, 7)
for i in range(70):
    x, y = random.uniform(-90, 90), random.uniform(-70, 60)
    if abs(x) < 7 or (0 < x < 30 and -12 < y < 8):
        continue
    s = random.uniform(0.8, 1.8)
    tuft = box(f"GrassClump_{i}", (s, s, s * 0.9), (x, y, s * 0.35), M["leaf"], C_GROUND, rot=(0, 0, random.uniform(0, 1)), bevel=0.3, segs=2)
    chip(tuft, 0.25)
# foreground frame: a big dark oak trunk on the left, a rock shoulder on the right
bpy.ops.mesh.primitive_cylinder_add(vertices=14, radius=4.2, depth=40, location=(-22, -52, 20))
ft = bpy.context.active_object; ft.name = "FG_OakTrunk"; ft.data.materials.append(M["bark"])
ft.modifiers.new("Bevel", "BEVEL").width = 0.4
for c in ft.users_collection: c.objects.unlink(ft)
C_TREE.objects.link(ft)
for i in range(3):
    fl = box(f"FG_Canopy{i + 1}", (34 - i * 6, 26 - i * 4, 5), (-18 + i * 2, -46, 30 + i * 4.5), M["leaf"], C_TREE, rot=(0, 0, 0.3 + i * 0.2), bevel=1.0, segs=2)
    chip(fl, 0.8)
for k in range(6):
    box(f"FG_Vine{k + 1}", (0.3, 0.3, random.uniform(6, 14)), (-24 + k * 3.2, -44 + random.uniform(-3, 3), 22), M["bark"], C_TREE, bevel=0.05)
fr, _ = slab_stack("FG_RockShoulder", Vector((24, -50, 0)), 3, C_ROCK, M["stone"], width=(12, 16), depth=(8, 10), height=(3, 4.5))

# ---------- R6 stand-in: 4 wide x 5 tall x 1 deep ----------
def r6(at):
    parts = [("Torso", (2, 1, 2), (0, 0, 3)), ("Head", (1.2, 1.2, 1), (0, 0, 4.5)), ("LeftArm", (1, 1, 2), (-1.5, 0, 3)),
             ("RightArm", (1, 1, 2), (1.5, 0, 3)), ("LeftLeg", (1, 1, 2), (-0.5, 0, 1)), ("RightLeg", (1, 1, 2), (0.5, 0, 1))]
    for n, s, p in parts:
        box(f"R6_{n}", s, (at[0] + p[0], at[1] + p[1], p[2]), M["dummy"], C_SCALE, bevel=0.05)
r6((2, -24))
r6((46, 9.5))  # under the ledge strip

# ---------- world: cool ambient, low warm sun, bounded layered fog ----------
w = bpy.data.worlds.new("RS_World_Lindenmoor")
scene.world = w
w.use_nodes = True
bg = w.node_tree.nodes.get("Background")
bg.inputs["Color"].default_value = (*srgb("#5f7c80"), 1)
bg.inputs["Strength"].default_value = 0.55
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 10, 22))
fog = bpy.context.active_object; fog.name = "FogVolume"; fog.scale = (360, 360, 50)
for c in fog.users_collection: c.objects.unlink(fog)
root.objects.link(fog); fog.display_type = "WIRE"
fm = bpy.data.materials.get("RS_FogVolume") or bpy.data.materials.new("RS_FogVolume")
fm.use_nodes = True; fnt = fm.node_tree; fnt.nodes.clear()
fo = fnt.nodes.new("ShaderNodeOutputMaterial"); fv = fnt.nodes.new("ShaderNodeVolumePrincipled")
fv.inputs["Density"].default_value = 0.009
fv.inputs["Color"].default_value = (*srgb("#9fb6b0"), 1)
fv.inputs["Anisotropy"].default_value = 0.45
fnt.links.new(fv.outputs["Volume"], fo.inputs["Volume"])
fog.data.materials.append(fm)
sd = bpy.data.lights.new("Sun_Morning", "SUN"); sd.energy = 3.2; sd.color = (1.0, 0.72, 0.45); sd.angle = math.radians(2)
so = bpy.data.objects.new("Sun_Morning", sd); so.rotation_euler = Euler((math.radians(72), 0, math.radians(-40))); root.objects.link(so)
# second warm practical: lantern post at the path
box("LanternPost", (0.6, 0.6, 9), (-7, -20, 4.5), M["timber"], C_PROPS, bevel=0.08)
box("LanternPost_Glass", (1, 1, 1.4), (-7, -20, 9.6), glow, C_PROPS, bevel=0.1)
ld2 = bpy.data.lights.new("LanternPost_Light", "POINT"); ld2.energy = 1800; ld2.color = (1.0, 0.6, 0.28); ld2.shadow_soft_size = 0.5
lo2 = bpy.data.objects.new("LanternPost_Light", ld2); lo2.location = (-7, -21.2, 9.4); C_PROPS.objects.link(lo2)

# ---------- camera: a player's eye line along the path; house left, outcrop with its ledge right ----------
cd = bpy.data.cameras.new("Cam_PlayerView"); cd.lens = 20
cam = bpy.data.objects.new("Cam_PlayerView", cd)
cam.location = (2, -66, 9)
cam.rotation_euler = Euler((math.radians(84), 0, math.radians(4)))
root.objects.link(cam)
scene.camera = cam

r = scene.render
r.engine = "BLENDER_EEVEE"
r.resolution_x, r.resolution_y = 1600, 900
try:
    scene.eevee.volumetric_tile_size = "4"
    scene.eevee.volumetric_end = 400
    scene.eevee.use_shadows = True
except Exception:
    pass
scene.view_settings.view_transform = "AgX"
try:
    scene.view_settings.look = "AgX - High Contrast"
except Exception:
    pass

n_objs = len(scene.objects)
result = {"scene": scene.name, "objects": n_objs, "collections": [c.name for c in root.children]}

"""Export the Lindenmoor build to Roblox: Art/Studio/Lindenmoor/layout.json.

Every prefab root (Empty with ["rs_prefab"]) becomes one Roblox Model; its parts carry Roblox CFrames relative to the
model pivot. Axis mapping (Blender -> Roblox local): (x, y, z) -> (X = x, Y = z, Z = y), rotation R_r = P R_b P.
Blender cylinders run along local Z, Roblox cylinders along local X, so they get R_b @ Ry(-90) and size (h, 2r, 2r).
Skipped: rs_skip objects (terrain/water/kept references) and Reskin_* roots (Studio keeps those parts and only
changes their material, see Art/Studio/Lindenmoor/import_finish.lua)."""
import bpy, json, math, os
from mathutils import Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "Studio", "Lindenmoor", "layout.json"))
P3 = Matrix(((1, 0, 0), (0, 0, 1), (0, 1, 0)))
CYL_FIX = Matrix.Rotation(math.radians(-90), 4, "Y")


def r(v, n=3):
    return round(float(v), n)


def to_roblox(m4):
    """Blender 4x4 (unit scale) -> [X, Y, Z, qx, qy, qz, qw] in Roblox axes."""
    t = m4.to_translation()
    R = P3 @ m4.to_3x3().normalized() @ P3
    q = R.to_quaternion()
    return [r(t.x), r(t.z), r(t.y), r(q.x, 5), r(q.y, 5), r(q.z, 5), r(q.w, 5)]


def short(root, name):
    pre = root.name + "_"
    return name[len(pre):] if name.startswith(pre) else name


def walk(o):
    for c in o.children:
        yield c
        yield from walk(c)


def export(scene_name="Lindenmoor_Full"):
    s = bpy.data.scenes[scene_name]
    mats, mi = [], {}
    prefabs = []
    for root in s.objects:
        kind = root.get("rs_prefab")
        if not kind or str(kind).startswith("Reskin_"):
            continue
        inv = root.matrix_world.inverted()
        parts, lights = [], []
        for o in walk(root):
            if o.get("rs_skip"):
                continue
            if o.type == "LIGHT" and o.get("rs_light"):
                rel = inv @ o.matrix_world
                t = rel.to_translation()
                c = o.data.color
                lights.append([r(t.x), r(t.z), r(t.y), float(o.get("rs_range", 18)), r(o.data.energy, 0), r(c[0]), r(c[1]), r(c[2])])
                continue
            k = o.get("rs_kind")
            if o.type != "MESH" or not k:
                continue
            mname = o.get("rs_mat") or o.active_material.name
            if mname not in mi:
                mi[mname] = len(mats)
                mats.append(mname)
            sz = list(o["rs_size"])
            rel = inv @ o.matrix_world
            if k == "Cylinder":
                rel = rel @ CYL_FIX
                size = [sz[2], sz[0], sz[1]]
                shape = 1
            else:
                size = [sz[0], sz[2], sz[1]]
                shape = 2 if k == "Wedge" else 0
            parts.append([short(root, o.name), shape, mi[mname], r(size[0]), r(size[1]), r(size[2])] + to_roblox(rel))
        if not parts:
            continue
        g = root.users_collection[0].name.split(".")[0]
        prefabs.append({"k": kind, "id": str(root.get("rs_id")), "g": g, "cf": to_roblox(root.matrix_world), "p": parts, "l": lights})
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    data = {"origin": [0, 4, -650], "mats": mats, "prefabs": prefabs}
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(data, f, separators=(",", ":"))
    return {"file": OUT, "prefabs": len(prefabs), "parts": sum(len(p["p"]) for p in prefabs), "lights": sum(len(p["l"]) for p in prefabs), "mats": mats}

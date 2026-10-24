"""Lindenmoor kit for Roblox Studio, generated from layout.json (Art/Blender/lindenmoor/export.py).

python -I studio_kit.py [folder]      (folder holds layout.json; default: this script's folder)
  -> import/chunk_NN.lua   build every Blender prefab as a Model under ServerStorage.LindenmoorStaging (run in order)
  -> kit/<Group>/<Model>.rbxmx   one drag-in model per kit piece (pivot at the origin), for hand placement
Then run import/finish.lua (hand-written): backup, swap into Workspace.World.Map.Lindenmoor, re-skin, kit folder.

Materials are Roblox built-ins (Plaster, ClayRoofTiles, RoofShingles, WoodPlanks, Cobblestone, LeafyGrass, ...) with
a colour each; the names stay the Blender material names so MaterialVariants can be layered on later.
Part rows may carry field 14 (1 = invisible helper: Transparency 1, CanCollide off, CanQuery/CanTouch on), field 15
(a JSON string of attributes; "" = none) and field 16 (comma-separated CollectionService tags, each trimmed, empty
ones skipped: split_tags; "" = none; applied only in a region run). Shape 3 is a Seat (box-sized). Art/Studio/Train uses this with the train kit.
Every colour is a PROPOSAL.

Region runs (Art/Studio/Regions/kit.py calls main(folder, region={...}); the command line above is unchanged): the
chunks build into ServerStorage.RegionStaging/<group>/<kind>_<id>, every model gets RegionKit = <Region>, field 16
tags are added with CollectionService:AddTag, materials come from the region's materials.json (the built-in table
fills any gap), an entry with PackImage becomes a MaterialVariant of the same name (RG_<Region>_<key>, made by
chunk 1 and set on that material's parts), the no-collide name list is the region's own, no kit/*.rbxmx files are
written, and expected.json also carries per-group part counts, tag counts and the variants."""
import base64, json, math, os, re, struct, sys, xml.sax.saxutils as sx

HERE = os.path.dirname(os.path.abspath(__file__))

# Blender material -> (Roblox material, hex colour, transparency)
MATS = {
    "LM_Timber": ("Wood", "5a4030", 0), "LM_Iron": ("Metal", "2e2c29", 0), "LM_Planks": ("WoodPlanks", "8a6a48", 0),
    "LM_PlanksRed": ("WoodPlanks", "9c5444", 0), "LM_PlanksGreen": ("WoodPlanks", "6f8a63", 0),
    "LM_StoneBase": ("Cobblestone", "8d8577", 0), "LM_FieldWallStone": ("Cobblestone", "7c7f70", 0),
    "LM_Cobble": ("Cobblestone", "8a8a7e", 0), "LM_MossyRock": ("Rock", "6f7566", 0), "LM_Terrace": ("Rock", "6b7262", 0),
    "LM_Cliff": ("Rock", "6a6c62", 0), "LM_DirtPath": ("Ground", "6b5a45", 0),
    "LM_Plaster": ("Plaster", "efe4cc", 0), "LM_PlasterOchre": ("Plaster", "e1c48d", 0), "LM_PlasterWhite": ("Plaster", "f4efe4", 0),
    "LM_RoofTiles": ("ClayRoofTiles", "a2553c", 0), "LM_RoofSlate": ("RoofShingles", "5d6870", 0),
    "LM_Bark": ("Wood", "4a3a2c", 0), "LM_Hay": ("Grass", "cfae5c", 0), "LM_WheatField": ("Grass", "d9b95e", 0),
    "LM_OakFoliage": ("LeafyGrass", "4a6b30", 0), "LM_CypressFoliage": ("LeafyGrass", "2d4a30", 0), "LM_Vine": ("LeafyGrass", "2a4424", 0),
    "LM_WindowGlass": ("Glass", "2a3a3c", 0.3), "LM_Water": ("Glass", "2b5552", 0.3),
    "LM_LanternGlow": ("Neon", "ffb35c", 0), "LM_Embers": ("Neon", "ff6a1a", 0),
    "LM_Rope": ("Fabric", "8a7650", 0), "LM_Cloth": ("Fabric", "6c2f25", 0), "LM_ClothLinen": ("Fabric", "d9d2bf", 0),
    "LM_ClothBlue": ("Fabric", "3c5a78", 0), "LM_ClothTent": ("Fabric", "6e6248", 0), "LM_Paper": ("SmoothPlastic", "e6dcc2", 0),
    "LM_FlowerWhite": ("SmoothPlastic", "e9e4d6", 0), "LM_FlowerYellow": ("SmoothPlastic", "e0b83a", 0),
    "LM_FlowerViolet": ("SmoothPlastic", "8a6cb0", 0),
    # the FMA train kit (Art/Blender/train/train.py, 2026-10-20): PROPOSAL colours from the world spec
    "LM_TrainNavy": ("Metal", "23262d", 0), "LM_TrainMaroon": ("WoodPlanks", "6a1f24", 0), "LM_TrainBlack": ("Metal", "1b1c1e", 0),
    "LM_TrainRoof": ("Metal", "4a4d50", 0), "LM_Brass": ("Metal", "b08a3c", 0), "LM_Cream": ("Plaster", "e6dcc2", 0),
    "LM_BenchGreen": ("Fabric", "2f4a3a", 0), "LM_TrainWood": ("Wood", "5a3a26", 0), "LM_Helper": ("SmoothPlastic", "ffffff", 0),
}
MAT_ENUM = {"Plastic": 256, "SmoothPlastic": 272, "Neon": 288, "Wood": 512, "WoodPlanks": 528, "Slate": 800, "Brick": 848,
            "Cobblestone": 880, "Rock": 896, "Grass": 1280, "LeafyGrass": 1284, "Fabric": 1312, "Metal": 1088, "Glass": 1568,
            "Plaster": 2310, "ClayRoofTiles": 2307, "RoofShingles": 2308, "Ground": 1360}
# decoration players should walk through (flush stones, plants, cloth, small fittings)
NO_COLLIDE = ("Tuft", "Crop", "Vine", "Bloom", "Cloth", "Line", "Hinge", "Bar0", "Bar1", "Bar2", "Bar3", "Goods", "Flag", "Kerb", "Bedroll", "Peg", "Banner",
              "Glass", "Box", "Glow", "Lantern")
NO_COLLIDE_KINDS = ("EdgeStone",)
# kit pieces: (kind, how many variants)
KIT = {"Farmhouse": 9, "Oak": 4, "OakBig": 3, "Cypress": 3, "LampPost": 1, "Barn": 1, "TentHalf": 1, "FirePit": 1, "CampProps": 1,
       "RidgeTerrace": 3, "BankStones": 3, "EdgeStone": 3, "Square": 1,
       "Locomotive": 1, "Tender": 1, "BaggageCar": 1, "ThirdClass": 1, "DiningCar": 1, "SecondClass": 1, "CabinCar": 1}
CHUNK_PARTS = 1100
# every Enum.Material name (read from Studio, 2026-10-24): a region's materials are checked against it before any Lua
ROBLOX_MATERIALS = frozenset((
    "Plastic", "SmoothPlastic", "Neon", "Wood", "WoodPlanks", "Marble", "Basalt", "Slate", "CrackedLava", "Concrete",
    "Limestone", "Granite", "Pavement", "Brick", "Pebble", "Cobblestone", "Rock", "Sandstone", "CorrodedMetal",
    "DiamondPlate", "Foil", "Metal", "Grass", "LeafyGrass", "Sand", "Fabric", "Snow", "Mud", "Ground", "Asphalt", "Salt",
    "Ice", "Glacier", "Glass", "ForceField", "Air", "Water", "Cardboard", "Carpet", "CeramicTiles", "ClayRoofTiles",
    "RoofShingles", "Leather", "Plaster", "Rubber"))


def split_tags(s):
    """Field 16 -> tags: split on commas, trim each, skip empty ones. The region chunks' Lua (@TAGS@) uses the
    same rule."""
    if not isinstance(s, str):
        return []
    return [t.strip() for t in s.split(",") if t.strip()]


def lua_str(s):
    """A Lua string literal for s (quotes, backslashes and anything outside printable ASCII escaped)."""
    out = []
    for ch in str(s):
        o = ord(ch)
        if ch in '\\"':
            out.append("\\" + ch)
        elif 32 <= o < 127:
            out.append(ch)
        else:
            out.append("\\u{%x}" % o)  # Luau's \u{XXXX} escape
    return '"' + "".join(out) + '"'


def long_json(v, **kw):
    """json.dumps for a Lua long string [==[ ... ]==]: refuses text that would close it early."""
    s = json.dumps(v, **kw)
    if "]==]" in s:
        raise ValueError("JSON contains ']==]', which would end the Lua long string early")
    return s


def light_props(l):
    x, y, z, rng, energy, r, g, b = l
    return {"pos": (x, y, z), "range": rng, "brightness": round(min(2.0, energy / 3000), 2), "shadows": energy >= 5000,
            "color": (r, g, b)}


def region_mats(region):
    """The material table of a region run: the built-in MATS, overridden by materials.json entries.
    {name: (material, hex, transparency, variant name or None)}; variant entries also list (name, base, image, studs)."""
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", str(region.get("name", ""))):
        raise ValueError(f"region name {region.get('name')!r}: letters, digits and _ only, starting with a letter")
    out = {k: (*v, None) for k, v in MATS.items()}
    variants = []
    for k, e in sorted((region.get("materials") or {}).items()):
        var = None
        if e.get("PackImage"):
            var = k if k.startswith(f"RG_{region['name']}_") else f"RG_{region['name']}_{k}"
            studs = e.get("StudsPerTile", 4)  # 4 = materials.PACK_TILE_DEFAULT (PROPOSAL)
            if not (isinstance(studs, (int, float)) and studs > 0):
                raise ValueError(f"materials.json {k}: StudsPerTile must be a number > 0, got {studs!r}")
            variants.append({"Name": var, "Base": e["Material"], "ColorMap": str(e["PackImage"]), "Studs": studs})
        out[k] = (e["Material"], e["Color"], e.get("Transparency", 0), var)
    for k, (mat, col, tr, var) in out.items():
        if mat not in ROBLOX_MATERIALS:
            raise ValueError(f"material {k}: {mat!r} is not an Enum.Material name")
        if not re.fullmatch(r"[0-9a-fA-F]{6}", str(col)):
            raise ValueError(f"material {k}: colour {col!r} is not a 6-digit hex")
        if isinstance(tr, bool) or not (isinstance(tr, (int, float)) and 0 <= tr <= 1):
            raise ValueError(f"material {k}: Transparency {tr!r} is not a number in 0..1")
    return out, variants


def lua_header(data, region=None):
    if region:
        table, _ = region_mats(region)
        mats = ",\n".join(f'\t[{lua_str(k)}] = {{Enum.Material.{v[0]}, Color3.fromHex("{v[1]}"), {v[2]}'
                          + (f", {lua_str(v[3])}" if v[3] else "") + "}" for k, v in sorted(table.items()))
        no_collide, kinds = region["no_collide"], region.get("no_collide_kinds", ())
    else:
        mats = ",\n".join(f'\t["{k}"] = {{Enum.Material.{v[0]}, Color3.fromHex("{v[1]}"), {v[2]}}}' for k, v in sorted(MATS.items()))
        no_collide, kinds = NO_COLLIDE, NO_COLLIDE_KINDS
    head = f"""-- generated by Art/Studio/Lindenmoor/studio_kit.py from layout.json: do not edit by hand
local HS = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local MATS = {{
{mats}
}}
local MATN = HS:JSONDecode([==[{long_json(data["mats"])}]==])
local O = Vector3.new({data["origin"][0]}, {data["origin"][1]}, {data["origin"][2]})
local NOCOLLIDE = HS:JSONDecode([==[{long_json(list(no_collide))}]==])
local NOCOLLIDE_KINDS = HS:JSONDecode([==[{long_json(list(kinds))}]==])
""" + steam_lua()
    if region:
        head += (f'-- region {region["name"]} (Art/Studio/Regions/kit.py)\n'
                 'local CS = game:GetService("CollectionService")\n'
                 f'local REGION = {lua_str(region["name"])}\n')
    return head


# field 16 -> tags in a region chunk: the rule of split_tags (split on commas, trim each, skip empty ones)
TAGS_LUA = ('\t\tif type(P[16]) == "string" then -- "" = no tags\n'
            '\t\t\tfor T in string.gmatch(P[16], "[^,]+") do\n'
            '\t\t\t\tT = T:match("^%s*(.-)%s*$")\n'
            '\t\t\t\tif T ~= "" then CS:AddTag(Part, T) end\n'
            "\t\t\tend\n"
            "\t\tend\n")


def body_lua(region=None, prelude=""):
    """LUA_BODY with its slots filled: Lindenmoor's own text by default, the region pieces for a region run.
    prelude: Lua run once the staging folder exists (a region's chunk 1 makes its MaterialVariants there)."""
    if region:
        fill = {"@STAGE@": "RegionStaging", "@KITATTR@": '"RegionKit", REGION',
                "@VARIANT@": "\t\tif M[4] then Part.MaterialVariant = M[4] end -- a texture-pack MaterialVariant\n",
                "@TAGS@": TAGS_LUA}
    else:
        fill = {"@STAGE@": "LindenmoorStaging", "@KITATTR@": '"LindenmoorKit", PF.k', "@VARIANT@": "", "@TAGS@": ""}
    fill["@PRELUDE@"] = prelude
    s = LUA_BODY
    for k, v in fill.items():
        s = s.replace(k, v)
    return s


# chunk 1 of a region run: each texture-pack MaterialVariant. A missing one is made in MaterialService and marked
# RegionKitStaged = REGION (finish.lua's dry run removes those again; the real run keeps them). One already there
# with the same base, image and tiling is left alone. A different one of that name is not touched: the new one waits
# in RegionStaging._Variants and finish.lua backs the old one up when it swaps them.
VARIANT_LUA = """local MS = game:GetService("MaterialService")
for _, V in ipairs(VARIANTS) do
	local Have = MS:FindFirstChild(V.Name)
	local Same = Have and Have:IsA("MaterialVariant") and Have.BaseMaterial == Enum.Material[V.Base]
		and Have.ColorMap == V.ColorMap and Have.StudsPerTile == V.Studs
	if not Same then
		local MV = Instance.new("MaterialVariant")
		MV.Name = V.Name
		MV.BaseMaterial = Enum.Material[V.Base]
		MV.ColorMap = V.ColorMap
		MV.StudsPerTile = V.Studs
		MV:SetAttribute("RegionKitStaged", REGION)
		if Have and Have:GetAttribute("RegionKitStaged") ~= REGION then
			local Wait = Stage:FindFirstChild("_Variants")
			if not Wait then
				Wait = Instance.new("Folder")
				Wait.Name = "_Variants"
				Wait.Parent = Stage
			end
			local Old = Wait:FindFirstChild(V.Name)
			if Old then Old:Destroy() end
			MV.Parent = Wait
		else
			if Have then Have:Destroy() end -- this kit's own earlier variant
			MV.Parent = MS
		end
	end
end
"""


LUA_BODY = """
local Stage = SS:FindFirstChild("@STAGE@")
if not Stage then
	Stage = Instance.new("Folder")
	Stage.Name = "@STAGE@"
	Stage.Parent = SS
end
@PRELUDE@local function CF(t, i)
	return CFrame.new(t[i], t[i + 1], t[i + 2], t[i + 3], t[i + 4], t[i + 5], t[i + 6])
end
local function Collides(Kind, Name)
	for _, K in ipairs(NOCOLLIDE_KINDS) do if Kind == K then return false end end
	for _, P in ipairs(NOCOLLIDE) do if Name:find(P, 1, true) then return false end end
	return true
end
local Made, Parts = 0, 0
for I, PF in ipairs(DATA) do
	local Group = Stage:FindFirstChild(PF.g)
	if not Group then
		Group = Instance.new("Folder")
		Group.Name = PF.g
		Group.Parent = Stage
	end
	local Name = PF.k .. "_" .. PF.id
	local Old = Group:FindFirstChild(Name)
	if Old then Old:Destroy() end -- re-running a chunk replaces its models
	local Model = Instance.new("Model")
	Model.Name = Name
	Model:SetAttribute(@KITATTR@)
	local Base = CFrame.new(O) * CF(PF.cf, 1)
	local List = {}
	for _, P in ipairs(PF.p) do
		local Part
		if P[2] == 2 then
			Part = Instance.new("WedgePart")
		elseif P[2] == 3 then
			Part = Instance.new("Seat")
		else
			Part = Instance.new("Part")
		end
		if P[2] == 1 then Part.Shape = Enum.PartType.Cylinder end
		Part.Name = P[1]
		Part.Size = Vector3.new(P[4], P[5], P[6])
		Part.CFrame = Base * CF(P, 7)
		local M = MATS[MATN[P[3] + 1]] or {Enum.Material.Plastic, Color3.new(1, 0, 1), 0}
		Part.Material, Part.Color, Part.Transparency = M[1], M[2], M[3]
@VARIANT@		Part.Anchored = true
		Part.TopSurface, Part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		Part.CanCollide = Collides(PF.k, P[1])
		Part.CastShadow = Part.Size.X * Part.Size.Y * Part.Size.Z > 1.5
		if P[14] == 1 then -- invisible helper (BoardZone, StowZone, CarDoor, ...)
			Part.Transparency, Part.CanCollide, Part.CanQuery, Part.CanTouch, Part.CastShadow = 1, false, true, true, false
		end
		if type(P[15]) == "string" and P[15] ~= "" then -- "" = no attributes (export rows keep fields 14-16 together)
			for K, V in pairs(HS:JSONDecode(P[15])) do
				Part:SetAttribute(K, V)
			end
		end
@TAGS@		if Part:GetAttribute("Emit") == "Steam" then Steam(Part) end -- the locomotive's chimney
		Part.Parent = Model
		table.insert(List, Part)
		Parts += 1
	end
	-- lights live directly in the nearest part (LightService tags parts holding a PointLight as lamps)
	for _, L in ipairs(PF.l) do
		local At = Base * Vector3.new(L[1], L[2], L[3])
		local Best, D = nil, math.huge
		for _, Part in ipairs(List) do
			local d = (Part.Position - At).Magnitude
			if Part.Material == Enum.Material.Neon then d -= 1000 end
			if d < D then Best, D = Part, d end
		end
		local PL = Instance.new("PointLight")
		PL.Range, PL.Brightness, PL.Shadows = L[4], L[5], L[6]
		PL.Color = Color3.new(L[7], L[8], L[9])
		PL.Parent = Best
	end
	Model.WorldPivot = Base
	Model.Parent = Group
	Made += 1
	if I % 25 == 0 then task.wait() end
end
return string.format("chunk %s: %d models, %d parts", CHUNK, Made, Parts)
"""


def rgb_uint(h):
    return str(0xFF000000 | int(h, 16))


def cf_xml(tag, name, x, y, z, R):
    k = "".join(f"<R{i}{j}>{R[i][j]:.6f}</R{i}{j}>" for i in range(3) for j in range(3))
    return f'<{tag} name="{name}"><X>{x:.4f}</X><Y>{y:.4f}</Y><Z>{z:.4f}</Z>{k}</{tag}>'


def quat_mat(qx, qy, qz, qw):
    return [[1 - 2 * (qy * qy + qz * qz), 2 * (qx * qy - qz * qw), 2 * (qx * qz + qy * qw)],
            [2 * (qx * qy + qz * qw), 1 - 2 * (qx * qx + qz * qz), 2 * (qy * qz - qx * qw)],
            [2 * (qx * qz - qy * qw), 2 * (qy * qz + qx * qw), 1 - 2 * (qx * qx + qy * qy)]]


def attrs_xml(js):
    """Roblox AttributesSerialize blob (string / bool / number values) for an rbxmx part."""
    d = json.loads(js)

    def st(t):
        b = t.encode("utf-8")
        return struct.pack("<I", len(b)) + b
    out = struct.pack("<I", len(d))
    for k, v in d.items():
        out += st(str(k))
        if isinstance(v, bool):
            out += b"\x03" + (b"\x01" if v else b"\x00")
        elif isinstance(v, (int, float)):
            out += b"\x06" + struct.pack("<d", float(v))
        else:
            out += b"\x02" + st(str(v))
    return f'<BinaryString name="AttributesSerialize">{base64.b64encode(out).decode()}</BinaryString>'


# Steam from a part with the attribute Emit = "Steam" (the train's chimney helper). ALL values PROPOSAL:
# soft white-grey puffs rising and spreading (Rate 8, Lifetime 3-5 s, size 1 -> 6, speed 4-5).
STEAM = {"Texture": "rbxasset://textures/particles/smoke_main.dds", "Rate": 8, "Lifetime": (3, 5), "Speed": (4, 5),
         "Spread": 10, "Size": ((0, 1), (0.5, 3.5), (1, 6)), "Transparency": ((0, 0.3), (0.6, 0.6), (1, 1)),
         "Color": ((0, "ebebeb"), (1, "b4b4b4")), "Accel": (0, 1.5, 0), "Drag": 0.6, "RotSpeed": (-20, 20)}


def _hex3(h):
    return [round(int(h[i:i + 2], 16) / 255, 4) for i in (0, 2, 4)]


def steam_lua():
    s = STEAM
    num = ", ".join(f"NumberSequenceKeypoint.new({t}, {v})" for t, v in s["Size"])
    tra = ", ".join(f"NumberSequenceKeypoint.new({t}, {v})" for t, v in s["Transparency"])
    col = ", ".join(f'ColorSequenceKeypoint.new({t}, Color3.fromHex("{c}"))' for t, c in s["Color"])
    return ("local function Steam(Part)\n"
            "\tlocal E = Instance.new(\"ParticleEmitter\")\n"
            "\tE.Name = \"Steam\"\n"
            f"\tE.Texture = \"{s['Texture']}\"\n"
            f"\tE.Rate = {s['Rate']}\n"
            f"\tE.Lifetime = NumberRange.new({s['Lifetime'][0]}, {s['Lifetime'][1]})\n"
            f"\tE.Speed = NumberRange.new({s['Speed'][0]}, {s['Speed'][1]})\n"
            f"\tE.SpreadAngle = Vector2.new({s['Spread']}, {s['Spread']})\n"
            f"\tE.Size = NumberSequence.new({{{num}}})\n"
            f"\tE.Transparency = NumberSequence.new({{{tra}}})\n"
            f"\tE.Color = ColorSequence.new({{{col}}})\n"
            f"\tE.Acceleration = Vector3.new({s['Accel'][0]}, {s['Accel'][1]}, {s['Accel'][2]})\n"
            f"\tE.Drag = {s['Drag']}\n"
            f"\tE.RotSpeed = NumberRange.new({s['RotSpeed'][0]}, {s['RotSpeed'][1]})\n"
            "\tE.Rotation = NumberRange.new(0, 360)\n"
            "\tE.EmissionDirection = Enum.NormalId.Top\n"
            "\tE.Parent = Part\n"
            "end\n")


def steam_xml(ref):
    s = STEAM
    seq = lambda pts: "".join(f"{t} {v} 0 " for t, v in pts)
    col = "".join(f"{t} {' '.join(str(c) for c in _hex3(h))} 0 " for t, h in s["Color"])
    return (f'<Item class="ParticleEmitter" referent="{ref}"><Properties><string name="Name">Steam</string>'
            f'<Content name="Texture"><url>{s["Texture"]}</url></Content><float name="Rate">{s["Rate"]}</float>'
            f'<NumberRange name="Lifetime">{s["Lifetime"][0]} {s["Lifetime"][1]} </NumberRange>'
            f'<NumberRange name="Speed">{s["Speed"][0]} {s["Speed"][1]} </NumberRange>'
            f'<Vector2 name="SpreadAngle"><X>{s["Spread"]}</X><Y>{s["Spread"]}</Y></Vector2>'
            f'<NumberSequence name="Size">{seq(s["Size"])}</NumberSequence>'
            f'<NumberSequence name="Transparency">{seq(s["Transparency"])}</NumberSequence>'
            f'<ColorSequence name="Color">{col}</ColorSequence>'
            f'<Vector3 name="Acceleration"><X>{s["Accel"][0]}</X><Y>{s["Accel"][1]}</Y><Z>{s["Accel"][2]}</Z></Vector3>'
            f'<float name="Drag">{s["Drag"]}</float><NumberRange name="RotSpeed">{s["RotSpeed"][0]} {s["RotSpeed"][1]} </NumberRange>'
            '<NumberRange name="Rotation">0 360 </NumberRange><token name="EmissionDirection">1</token>'
            '</Properties></Item>')


def rbxmx(pf, mats):
    """One Model, pivot at the origin (parts keep their CFrames relative to the prefab pivot)."""
    ref = [0]

    def nref():
        ref[0] += 1
        return f"RBX{ref[0]}"
    parts_xml = []
    plist = []
    for p in pf["p"]:
        name, shape, mi, sx_, sy_, sz_ = p[:6]
        x, y, z, qx, qy, qz, qw = p[6:13]
        R = quat_mat(qx, qy, qz, qw)
        mat, col, tr = MATS.get(mats[mi], ("Plastic", "ff00ff", 0))
        cls = {2: "WedgePart", 3: "Seat"}.get(shape, "Part")
        collide = "true"
        if pf["k"] in NO_COLLIDE_KINDS or any(s in name for s in NO_COLLIDE):
            collide = "false"
        helper = len(p) > 13 and p[13] == 1
        extra = ""
        if helper:
            collide, tr = "false", 1
        if len(p) > 14 and isinstance(p[14], str) and p[14]:  # "" = no attributes
            extra = attrs_xml(p[14])
        shape_xml = '<token name="shape">2</token>' if shape == 1 else ('<token name="shape">1</token>' if cls != "WedgePart" else "")
        plist.append((x, y, z, mat))
        parts_xml.append([f'<Item class="{cls}" referent="{nref()}"><Properties>'
                          f'<string name="Name">{sx.escape(name)}</string><bool name="Anchored">true</bool>'
                          f'<bool name="CanCollide">{collide}</bool>'
                          f'<bool name="CastShadow">{"true" if sx_ * sy_ * sz_ > 1.5 and not helper else "false"}</bool>'
                          + cf_xml("CoordinateFrame", "CFrame", x, y, z, R)
                          + f'<Vector3 name="size"><X>{sx_}</X><Y>{sy_}</Y><Z>{sz_}</Z></Vector3>'
                          f'<token name="Material">{MAT_ENUM[mat]}</token><Color3uint8 name="Color3uint8">{rgb_uint(col)}</Color3uint8>'
                          f'<float name="Transparency">{tr}</float><token name="TopSurface">0</token><token name="BottomSurface">0</token>'
                          + shape_xml + extra + "</Properties>", ""])
        if len(p) > 14 and isinstance(p[14], str) and p[14] and json.loads(p[14]).get("Emit") == "Steam":
            parts_xml[-1][1] += steam_xml(nref())
    for l in pf["l"]:  # [x, y, z, range, brightness, shadows, r, g, b]
        best, bd = 0, 1e9
        for i, (x, y, z, mat) in enumerate(plist):
            d = math.dist((x, y, z), l[:3]) - (1000 if mat == "Neon" else 0)
            if d < bd:
                best, bd = i, d
        r, g, b = l[6:9]
        parts_xml[best][1] += (f'<Item class="PointLight" referent="{nref()}"><Properties><float name="Range">{l[3]}</float>'
                               f'<float name="Brightness">{l[4]}</float><bool name="Shadows">{"true" if l[5] else "false"}</bool>'
                               f'<Color3 name="Color"><R>{r}</R><G>{g}</G><B>{b}</B></Color3></Properties></Item>')
    body = "".join(a + b + "</Item>" for a, b in parts_xml)
    ident = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
    return ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" version="4">'
            f'<Item class="Model" referent="RBX0"><Properties><string name="Name">{sx.escape(pf["k"] + "_" + pf["id"])}</string>'
            + "<OptionalCoordinateFrame name=\"WorldPivotData\">" + cf_xml("CFrame", "", 0, 0, 0, ident).replace(' name=""', "")
            + "</OptionalCoordinateFrame></Properties>" + body + "</Item></roblox>")


def main(folder=HERE, region=None):
    """Writes import/chunk_NN.lua and import/expected.json for folder/layout.json (and kit/*.rbxmx unless region).
    region (optional; Art/Studio/Regions/kit.py): {"name": <Region>, "materials": materials.json as a dict or None,
    "no_collide": name substrings that lose collision, "no_collide_kinds": prefab kinds that do}. Returns the
    expected dict and the chunk count."""
    folder = os.path.abspath(folder)
    data = json.load(open(os.path.join(folder, "layout.json"), encoding="utf-8"))
    pre = data["prefabs"]
    variants = []
    if region:
        table, variants = region_mats(region)
        missing = sorted(set(data["mats"]) - set(table))
        if missing:
            raise ValueError(f"materials missing from materials.json and the built-in table: {', '.join(missing)}")
    for pf in pre:
        pf["l"] = [[*l[:3], l[3], light_props(l)["brightness"], light_props(l)["shadows"], *l[5:8]] for l in pf["l"]]
    imp = os.path.join(folder, "import")
    os.makedirs(imp, exist_ok=True)
    for f in os.listdir(imp):
        if f.startswith("chunk_"):
            os.remove(os.path.join(imp, f))
    head = lua_header(data, region)
    chunks, cur, n = [], [], 0
    for pf in pre:
        cur.append(pf)
        n += len(pf["p"])
        if n >= CHUNK_PARTS:
            chunks.append(cur)
            cur, n = [], 0
    if cur:
        chunks.append(cur)
    for i, ch in enumerate(chunks, 1):
        prelude = ""
        if region and i == 1 and variants:
            prelude = f"local VARIANTS = HS:JSONDecode([==[{long_json(variants)}]==])\n" + VARIANT_LUA
        src = (head + f"local CHUNK = \"{i}/{len(chunks)}\"\nlocal DATA = HS:JSONDecode([==[{long_json(ch, separators=(',', ':'))}]==])\n"
               + body_lua(region, prelude))
        open(os.path.join(imp, f"chunk_{i:02d}.lua"), "w", encoding="utf-8").write(src)
    # expected totals for finish.lua's check
    groups = {}
    for pf in pre:
        groups[pf["g"]] = groups.get(pf["g"], 0) + 1
    expected = {"models": len(pre), "parts": sum(len(p["p"]) for p in pre), "groups": groups}
    if region:
        gparts, tags, tag_groups = {}, {}, {}
        vparts = {v["Name"]: 0 for v in variants}
        for pf in pre:
            gparts[pf["g"]] = gparts.get(pf["g"], 0) + len(pf["p"])
            for p in pf["p"]:
                var = table[data["mats"][p[2]]][3]
                if var:
                    vparts[var] += 1
                for t in dict.fromkeys(split_tags(p[15] if len(p) > 15 else "")):  # a tag once per part, as AddTag
                    tags[t] = tags.get(t, 0) + 1
                    tg = tag_groups.setdefault(t, {})
                    tg[pf["g"]] = tg.get(pf["g"], 0) + 1
        expected.update({"region": region["name"], "groupParts": gparts, "tags": tags, "tagsByGroup": tag_groups,
                         "lights": sum(len(p["l"]) for p in pre), "variants": [v["Name"] for v in variants], "variantParts": vparts})
    json.dump(expected, open(os.path.join(imp, "expected.json"), "w"), indent=1)
    # kit (Lindenmoor and the train only: a region's pieces live in its Blender scene)
    files = 0
    if not region:
        kit = os.path.join(folder, "kit")
        taken = {}
        for pf in sorted(pre, key=lambda p: (p["k"], p["id"])):
            want = KIT.get(pf["k"], 0)
            if taken.get(pf["k"], 0) >= want:
                continue
            taken[pf["k"]] = taken.get(pf["k"], 0) + 1
            d = os.path.join(kit, pf["g"])
            os.makedirs(d, exist_ok=True)
            open(os.path.join(d, f'{pf["k"]}_{pf["id"]}.rbxmx'), "w", encoding="utf-8").write(rbxmx(pf, data["mats"]))
            files += 1
    print(f"{len(chunks)} chunks, {len(pre)} models, {sum(len(p['p']) for p in pre)} parts, {files} kit files; groups {groups}")
    return {"expected": expected, "chunks": len(chunks), "origin": data["origin"]}


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else HERE)

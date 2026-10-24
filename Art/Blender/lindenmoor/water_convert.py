"""Lindenmoor water: channel segments (world studs) -> kit.py's water.json (village-local axis-aligned Rects).
finish.lua adds the export origin back, so this subtracts it. PROPOSAL: 2-stud cells (spill <= ~15% on diagonals)."""
import json, math, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))  # Art/Blender
from region_builder import merge
ORIGIN = (0.0, 4.0, -650.0)  # export.py's Lindenmoor origin
REGION = os.path.normpath(os.path.join(HERE, "..", "..", "Regions", "Lindenmoor"))

def seg_dist(px, pz, ax, az, bx, bz):
    dx, dz = bx - ax, bz - az
    L2 = dx * dx + dz * dz
    t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / L2))
    return math.hypot(px - (ax + t * dx), pz - (az + t * dz))

def convert(segments, cell=2):
    boxes = []
    for s in segments:
        (ax, az), (bx, bz), r = s["From"], s["To"], s["Width"] / 2
        x0, x1 = math.floor((min(ax, bx) - r) / cell), math.ceil((max(ax, bx) + r) / cell)
        z0, z1 = math.floor((min(az, bz) - r) / cell), math.ceil((max(az, bz) + r) / cell)
        cells = {(i, k): 1 for i in range(x0, x1) for k in range(z0, z1)
                 if seg_dist((i + 0.5) * cell, (k + 0.5) * cell, ax, az, bx, bz) <= r}
        for n, (i, k, w, d, _) in enumerate(merge.rects(cells, max_span=64)):
            X0, Z0 = i * cell - ORIGIN[0], k * cell - ORIGIN[2]
            boxes.append({"Id": f"{s['Id']}_{n}", "Rect": [X0, Z0, X0 + w * cell, Z0 + d * cell],
                          "Top": round(s["Top"] - ORIGIN[1], 3), "Bed": round(s["Bed"] - ORIGIN[1], 3)})
    return {"Note": "Village-local water boxes (world - export origin (0, 4, -650)); finish.lua adds the origin back. PROPOSAL.",
            "Boxes": boxes}

if __name__ == "__main__":
    with open(os.path.join(REGION, "water_segments.json"), encoding="utf-8") as f:
        segs = json.load(f)["Boxes"]
    out = convert(segs)
    with open(os.path.join(REGION, "water.json"), "w", encoding="utf-8") as f:
        json.dump(out, f, indent=1)
    print(f"{len(segs)} segments -> {len(out['Boxes'])} boxes")

"""Region builder: turns Art/Regions/<Region>/layout.json into a stepped part-built ground (spec 2026-10-23 §3).

Pure modules (no bpy, standard library only): schema (the region file), heightfield (heights, columns, ramps),
merge (greedy rectangle merge). The Blender stages import these; nothing here imports bpy."""

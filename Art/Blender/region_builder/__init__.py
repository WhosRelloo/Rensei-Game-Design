"""Region builder: turns Art/Regions/<Region>/layout.json into a stepped part-built ground (spec 2026-10-23 §3).

Pure modules (no bpy, standard library only): schema (the region file), heightfield (heights, columns, ramps),
merge (greedy rectangle merge). They never import bpy.

Blender modules (run inside Blender): materials (the palette as Blender materials, plus materials.json; its table
needs no bpy), stages (ground, routes, markers, lighting, renders) and build (build.run("<Region>", stages))."""

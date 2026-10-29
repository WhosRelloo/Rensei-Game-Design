"""Encode the composed preview frames and the ambience into an MP4 with Blender's own FFmpeg (no other tools needed).

    blender -b --factory-startup -P Art/MainMenu/encode_video.py -- --anim E:/Rensei/Renders/MainMenu/anim --out E:/Rensei/Renders/MainMenu/menu_preview.mp4
"""
import json
import os
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ANIM = argv[argv.index("--anim") + 1] if "--anim" in argv else "E:/Rensei/Renders/MainMenu/anim"
OUT = argv[argv.index("--out") + 1] if "--out" in argv else "E:/Rensei/Renders/MainMenu/menu_preview.mp4"
tl = json.load(open(os.path.join(ANIM, "timeline.json")))
comp = os.path.join(ANIM, "comp")
files = sorted(f for f in os.listdir(comp) if f.endswith(".png"))

scene = bpy.context.scene
scene.render.fps = tl["fps"]
scene.render.resolution_x, scene.render.resolution_y = 1920, 1080
scene.render.resolution_percentage = 100
scene.frame_start, scene.frame_end = 1, len(files)
se = scene.sequence_editor_create()
strips = se.strips if hasattr(se, "strips") else se.sequences
img = strips.new_image("Frames", os.path.join(comp, files[0]), 1, 1)
for f in files[1:]:
	img.elements.append(f)
audio = os.path.join(ANIM, "ambience.wav")
if os.path.exists(audio):
	strips.new_sound("Ambience", audio, 2, 1)
rs = scene.render
if hasattr(rs.image_settings, "media_type"):
	rs.image_settings.media_type = "VIDEO"
rs.image_settings.file_format = "FFMPEG"
rs.ffmpeg.format = "MPEG4"
rs.ffmpeg.codec = "H264"
rs.ffmpeg.constant_rate_factor = "HIGH"
rs.ffmpeg.ffmpeg_preset = "GOOD"
rs.ffmpeg.audio_codec = "AAC"
rs.ffmpeg.audio_bitrate = 192
rs.ffmpeg.audio_mixrate = 44100
rs.ffmpeg.audio_channels = "STEREO"
rs.use_sequencer = True
rs.filepath = OUT
bpy.ops.render.render(animation=True, scene=scene.name)
print("RENSEI_VIDEO", OUT, len(files), "frames")

"""Lay the UI mockup over the animated preview's frames (menu_anim.py), then they are encoded by encode_video.py.

    python Art/MainMenu/compose_anim.py [--anim E:/Rensei/Renders/MainMenu/anim]

Per frame: upscaled to 1080p, the vignette (and the darker left third behind the logo and buttons), a living film
grain, then the UI. Over the 8 s loop the tip line crossfades to the next tip halfway, and just before the click the
gold hover moves to the CREATE CHARACTER card; over the pan the UI and the left darkening fade away.
Writes ANIM/comp/f_NNNN.png.
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paint_menu as P  # noqa: E402

W, H = P.W, P.H


def ease(p):
	p = min(max(p, 0.0), 1.0)
	return p * p * (3 - 2 * p)


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("--anim", default="E:/Rensei/Renders/MainMenu/anim")
	ap.add_argument("--logo", default="E:/Rensei/Work/main-menu/dl_logo/rensei_logo_420.png")
	ap.add_argument("--seed", type=int, default=28)
	a = ap.parse_args()
	tl = json.load(open(os.path.join(a.anim, "timeline.json")))
	loop, pan, total = tl["loop"], tl["pan"], tl["total"]
	out = os.path.join(a.anim, "comp")
	os.makedirs(out, exist_ok=True)
	logo = a.logo if os.path.exists(a.logo) else None
	blank = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	# the UI layers: tip 0 then tip 1 (hover on slot 1), and the moment before the click (hover on CREATE CHARACTER)
	ui_a = np.asarray(P.compose_ui(blank, logo, a.seed, hover=0, tip=0), np.float32) / 255
	ui_b = np.asarray(P.compose_ui(blank, logo, a.seed, hover=0, tip=1), np.float32) / 255
	ui_c = np.asarray(P.compose_ui(blank, logo, a.seed, hover=2, tip=1), np.float32) / 255
	yy, xx = np.mgrid[0:H, 0:W]
	dx, dy = (xx - W * 0.55) / (W * 0.62), (yy - H * 0.48) / (H * 0.62)
	vig = (np.clip(1 - (dx ** 2 + dy ** 2) * 0.55, 0.25, 1) ** 1.4).astype(np.float32)
	left = (0.55 + 0.45 * P.smooth(0, 0.42, xx / W)).astype(np.float32)
	grains = [(0.95 + 0.1 * P.fbm(W, H, a.seed + 50 + k, base=260, octaves=2)).astype(np.float32) for k in range(6)]
	half = loop // 2
	TIP_ROWS = slice(1010, 1060)  # the tip line's rows (it sits at y 1046)
	for f in range(total):
		src = os.path.join(a.anim, "frames", f"f_{f:04d}.png")
		if not os.path.exists(src):
			print("missing", src)
			continue
		img = np.asarray(Image.open(src).convert("RGB").resize((W, H), Image.LANCZOS), np.float32) / 255
		if f < loop:
			ui_alpha = 1.0
			# the tip line fades out and the next fades in around the loop's middle (the rest of the UI stays)
			ui = ui_a if f < half else ui_b
			tip_k = min(abs(f - half) / 6.0, 1.0)
			if f >= loop - 18:
				ui = ui_c  # the pointer has moved to CREATE CHARACTER
		else:
			p = (f - loop) / pan
			ui_alpha = 1 - ease(p / 0.35)
			ui = ui_c
			tip_k = 1.0
		dark = vig * (left * ui_alpha + (1 - ui_alpha)) * grains[f % len(grains)]
		img = img * dark[..., None]
		ua = ui[..., 3:4] * ui_alpha
		if tip_k < 1.0:
			ua = ua.copy()
			ua[TIP_ROWS] *= ease(tip_k)
		img = img * (1 - ua) + ui[..., :3] * ua
		Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save(os.path.join(out, f"f_{f:04d}.png"))
		if f % 24 == 0:
			print("composed", f, flush=True)
	print("done", out)


if __name__ == "__main__":
	main()

"""Finish the baked material maps (menu_bake.py) for Roblox MaterialVariants: seamless, and the colour maps painted.

    python Art/MainMenu/finish_maps.py [--dir E:/Rensei/Renders/MainMenu/upload]

Seamless: two passes, one axis each. The map is crossfaded with a copy of itself rolled along that axis, the copy
taking over near the edges (where it is continuous across the wrap) and the original in the middle (where the copy's
own seam sits). The roll is a whole number of brick periods, so the coursing stays aligned and only the noise is
blended. Painted: the colour map gets a Kuwahara filter (the paint-over the Blender render had), computed on a wrapped
copy so it stays seamless. Writes DIR/mat_<key>_{color,normal,roughness,metalness}.png and DIR/materials_sheet.png.
"""
import argparse
import json
import os

import numpy as np
from PIL import Image

# key: (horizontal brick period, vertical brick period), in fractions of the tile (None = no pattern)
PERIODS = {
	"WallStone": (1 / 8, 2 / 18),
	"Flagstones": (1 / 5, 2 / 6),
	"StatueStone": (1 / 8, 2 / 8),
	"Iron": (None, None),
	"RustIron": (None, None),
}


def roll_for(n, period):
	if not period:
		return n // 2
	p = period * n
	k = max(1, round((n / 2) / p))
	return int(round(k * p)) % n


def seamless(a, rx, ry, band=0.25):
	h, w = a.shape[:2]
	x = np.arange(w)
	wx = np.clip(np.minimum(x, w - 1 - x) / (band * w), 0, 1)
	wx = (wx * wx * (3 - 2 * wx))[None, :, None]
	a = a * wx + np.roll(a, rx, axis=1) * (1 - wx)
	y = np.arange(h)
	wy = np.clip(np.minimum(y, h - 1 - y) / (band * h), 0, 1)
	wy = (wy * wy * (3 - 2 * wy))[:, None, None]
	return a * wy + np.roll(a, ry, axis=0) * (1 - wy)


def box(a, r):
	"""Mean over a (2r+1)^2 window, wrapping at the edges (cumulative sums)."""
	k = 2 * r + 1
	p = np.pad(a, ((r + 1, r), (r + 1, r), (0, 0)), mode="wrap")
	c = p.cumsum(0).cumsum(1)
	return (c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]) / (k * k)


def kuwahara(img, r=3):
	"""Classic Kuwahara: each pixel takes the mean of whichever of its four (r+1)^2 quadrants varies least."""
	lum = (img @ np.array([0.3, 0.59, 0.11]))[..., None]
	q = r // 2 + 1
	means, vars_ = [], []
	for dy, dx in ((-q, -q), (-q, q), (q, -q), (q, q)):
		m = np.roll(box(img, q), (dy, dx), axis=(0, 1))
		lm = np.roll(box(lum, q), (dy, dx), axis=(0, 1))
		l2 = np.roll(box(lum * lum, q), (dy, dx), axis=(0, 1))
		means.append(m)
		vars_.append((l2 - lm * lm)[..., 0])
	idx = np.argmin(np.stack(vars_), axis=0)
	out = np.zeros_like(img)
	for k in range(4):
		out[idx == k] = means[k][idx == k]
	return out


def load(path, gray=False):
	im = Image.open(path).convert("L" if gray else "RGB")
	a = np.asarray(im, np.float32) / 255
	return a[..., None] if gray else a


def save(a, path, gray=False):
	a = np.clip(a, 0, 1)
	a = a[..., 0] if gray else a
	Image.fromarray((a * 255 + 0.5).astype(np.uint8), "L" if gray else "RGB").save(path)


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("--dir", default="E:/Rensei/Renders/MainMenu/upload")
	a = ap.parse_args()
	info = json.load(open(os.path.join(a.dir, "materials.json")))
	thumbs = []
	for key in info:
		px, py = PERIODS[key]
		maps = {}
		for kind in ("color", "normal", "roughness", "metalness"):
			gray = kind in ("roughness", "metalness")
			m = load(os.path.join(a.dir, f"raw_{key}_{kind}.png"), gray)
			n = m.shape[1]
			m = seamless(m, roll_for(n, px), roll_for(m.shape[0], py))
			if kind == "color":
				m = kuwahara(m, 3)
			if kind == "normal":
				v = m * 2 - 1
				v /= np.linalg.norm(v, axis=2, keepdims=True) + 1e-6
				m = v * 0.5 + 0.5
			save(m, os.path.join(a.dir, f"mat_{key}_{kind}.png"), gray)
			maps[kind] = m
		# a 2 x 2 tiling of the colour map, to check the seams by eye
		c = maps["color"]
		thumbs.append(np.concatenate([np.concatenate([c, c], 1), np.concatenate([c, c], 1)], 0))
		print("finished", key)
	sheet = np.concatenate([np.asarray(Image.fromarray((t * 255).astype(np.uint8)).resize((512, 512), Image.LANCZOS), np.float32) / 255 for t in thumbs], 1)
	Image.fromarray((sheet * 255).astype(np.uint8)).save(os.path.join(a.dir, "materials_sheet.png"))
	print("sheet", os.path.join(a.dir, "materials_sheet.png"))


if __name__ == "__main__":
	main()

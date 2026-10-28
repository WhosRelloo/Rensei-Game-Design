"""Rensei main menu: painted concept art (owner request 2026-10-28; design: Documents/specs/2026-10-28-main-menu-painted-design.md).

Everything is painted procedurally: each layer is first laid in as flat shapes (a "reference"), then repainted
with brush strokes sampled from it, big brushes first and smaller ones only where detail is missing (the
Hertzmann painterly method). Nothing from any other game is used.

    python Art/MainMenu/paint_menu.py [--out E:/Rensei/Renders/MainMenu/concept] [--logo path/to/logo.png]

Writes: layer_far.png, layer_mid.png, layer_wall.png, layer_near.png, effects.png, scene.png (all layers),
card_frame.png, card_frame_hover.png, button_frame.png, and concept_menu.png (scene + a UI mockup).
"""
import argparse
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1920, 1080
FONTS = "C:/Windows/Fonts/"


# ---------- helpers ----------
def fbm(w, h, seed, base=4, octaves=5, aspect=1.0):
	"""Fractal value noise in 0..1 (upsampled random grids)."""
	rng = np.random.default_rng(seed)
	out = np.zeros((h, w), np.float32)
	amp, total = 1.0, 0.0
	for o in range(octaves):
		gx = max(2, int(base * aspect * 2 ** o))
		gy = max(2, int(base * 2 ** o))
		g = Image.fromarray((rng.random((gy, gx)) * 255).astype(np.uint8))
		out += np.asarray(g.resize((w, h), Image.BICUBIC), np.float32) / 255 * amp
		total += amp
		amp *= 0.5
	out /= total
	return (out - out.min()) / (out.max() - out.min() + 1e-6)


def smooth(e0, e1, x):
	t = np.clip((x - e0) / (e1 - e0), 0, 1)
	return t * t * (3 - 2 * t)


def gradient_rows(h, stops):
	ys = np.linspace(0, 1, h)
	cols = np.stack([np.interp(ys, [s[0] for s in stops], [s[1][c] for s in stops]) for c in range(3)], -1)
	return cols  # (h, 3)


def to_img(arr_rgb, alpha=None):
	a = np.clip(arr_rgb, 0, 255).astype(np.uint8)
	if alpha is None:
		alpha = np.full(a.shape[:2], 255, np.uint8)
	else:
		alpha = np.clip(alpha, 0, 255).astype(np.uint8)
	return Image.fromarray(np.dstack([a, alpha]), "RGBA")


def add(base, glow):
	"""Additive blend of an RGBA glow layer onto an RGBA image."""
	b = np.asarray(base, np.float32)
	g = np.asarray(glow, np.float32)
	k = g[..., 3:4] / 255
	b[..., :3] = np.clip(b[..., :3] + g[..., :3] * k, 0, 255)
	return Image.fromarray(b.astype(np.uint8), "RGBA")


def radial(w, h, cx, cy, r, color, power=2.0, strength=1.0):
	yy, xx = np.mgrid[0:h, 0:w]
	d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / r
	a = np.clip(1 - d, 0, 1) ** power * 255 * strength
	return to_img(np.broadcast_to(np.array(color, np.float32), (h, w, 3)), a)


# ---------- the painterly pass ----------
def paint(ref, seed, brushes=(30, 16, 8, 4), thresholds=(0, 14, 12, 10), flow=0.0, base=None):
	"""Repaint ref (RGBA) with oriented strokes. flow = the default stroke angle (radians) where the image is flat."""
	rng = random.Random(seed)
	w, h = ref.size
	canvas = base.copy() if base is not None else Image.new("RGBA", (w, h), (0, 0, 0, 0))
	noise_angle = fbm(w, h, seed + 7, base=3, octaves=3) * 1.4 - 0.7
	for bi, r in enumerate(brushes):
		blur = np.asarray(ref.filter(ImageFilter.GaussianBlur(r * 0.45)), np.float32)
		lum = blur[..., :3] @ np.array([0.3, 0.59, 0.11], np.float32)
		gy, gx = np.gradient(lum)
		cur = np.asarray(canvas, np.float32)
		layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
		d = ImageDraw.Draw(layer)
		step = max(2, int(r * 0.8))
		pts = [(x + rng.randint(0, step - 1), y + rng.randint(0, step - 1)) for y in range(0, h, step) for x in range(0, w, step)]
		rng.shuffle(pts)
		th = thresholds[min(bi, len(thresholds) - 1)]
		for x, y in pts:
			if x >= w or y >= h:
				continue
			c = blur[y, x]
			if c[3] < 24:
				continue
			if th > 0:
				diff = np.abs(cur[y, x, :3] - c[:3]).sum() / 3 + abs(cur[y, x, 3] - c[3]) * 0.5
				if diff < th:
					continue
			g = math.hypot(gx[y, x], gy[y, x])
			if g > 0.6:
				ang = math.atan2(gy[y, x], gx[y, x]) + math.pi / 2
			else:
				ang = flow + noise_angle[y, x]
			ang += rng.uniform(-0.18, 0.18)
			length = r * rng.uniform(1.0, 2.4)
			width = max(1, int(r * rng.uniform(0.55, 0.95)))
			dx, dy = math.cos(ang) * length / 2, math.sin(ang) * length / 2
			j = rng.uniform(-7, 7)
			col = (int(min(255, max(0, c[0] + j + rng.uniform(-3, 3)))), int(min(255, max(0, c[1] + j))),
				int(min(255, max(0, c[2] + j + rng.uniform(-3, 3)))), int(c[3]))
			d.line([(x - dx, y - dy), (x + dx, y + dy)], fill=col, width=width)
			rr = width / 2
			for ex, ey in ((x - dx, y - dy), (x + dx, y + dy)):
				d.ellipse([ex - rr, ey - rr, ex + rr, ey + rr], fill=col)
		canvas = Image.alpha_composite(canvas, layer)
	return canvas


# ---------- the far layer: sky, smoke, sigil, viaduct, foundry town ----------
SKY_HORIZON = 0.64


def far_ref(seed):
	rng = random.Random(seed)
	rows = gradient_rows(H, [(0, (13, 12, 15)), (0.3, (26, 23, 25)), (0.5, (58, 40, 33)), (0.6, (128, 74, 40)),
		(SKY_HORIZON, (168, 98, 44)), (0.7, (60, 38, 28)), (1, (18, 15, 14))])
	img = np.broadcast_to(rows[:, None, :], (H, W, 3)).copy()
	# smoke banks: thick above the town, lit from below by the furnaces
	n = fbm(W, H, seed, base=3, octaves=6, aspect=1.8)
	ys = np.linspace(0, 1, H)[:, None]
	dens = smooth(0.42, 0.75, n) * (0.35 + 0.65 * smooth(0.05, 0.55, ys)) * (1 - smooth(0.62, 0.7, ys))
	lit = smooth(0.25, SKY_HORIZON, ys)
	smoke_col = np.array([46, 40, 40], np.float32) * (1 - lit[..., None]) + np.array([120, 70, 42], np.float32) * lit[..., None]
	img = img * (1 - dens[..., None] * 0.85) + smoke_col * dens[..., None] * 0.85
	base = to_img(img)
	d = ImageDraw.Draw(base)
	# viaduct (hazed: lighter than the town in front of it)
	deck_y = int(H * 0.5)
	haze = (40, 28, 25)
	d.rectangle([0, deck_y, W, deck_y + 16], fill=haze)
	d.rectangle([0, deck_y - 5, W, deck_y], fill=(44, 31, 27))
	span = 132
	for i in range(-1, W // span + 2):
		x0 = i * span
		d.rectangle([x0, deck_y + 16, x0 + span, int(H * 0.69)], fill=haze)
		d.ellipse([x0 + 16, deck_y + 34, x0 + span - 16, deck_y + 34 + (span - 32)], fill=(0, 0, 0, 0))
	# punch the arches through to the sky behind
	arches = Image.new("L", (W, H), 0)
	ad = ImageDraw.Draw(arches)
	for i in range(-1, W // span + 2):
		x0 = i * span
		ad.ellipse([x0 + 16, deck_y + 34, x0 + span - 16, deck_y + 34 + (span - 32)], fill=255)
		ad.rectangle([x0 + 16, deck_y + 34 + (span - 32) // 2, x0 + span - 16, int(H * 0.69)], fill=255)
	sky_only = to_img(img)
	base.paste(sky_only, (0, 0), arches)
	# a train on the viaduct (lit windows, lamp): its own glow is added in effects
	tx = int(W * 0.16)
	for k in range(4):
		x = tx + k * 104
		d.rounded_rectangle([x, deck_y - 30, x + 96, deck_y - 4], radius=6, fill=(30, 22, 20))
		for wv in range(5):
			d.rectangle([x + 10 + wv * 17, deck_y - 24, x + 19 + wv * 17, deck_y - 15], fill=(214, 140, 60))
	d.polygon([(tx - 28, deck_y - 4), (tx - 4, deck_y - 34), (tx, deck_y - 4)], fill=(30, 22, 20))
	# foundry town: roofs, gables, stacks
	town = (17, 14, 14)
	x = -20
	sky_y = int(H * SKY_HORIZON)
	while x < W + 40:
		bw = rng.randint(40, 120)
		top = sky_y - rng.randint(8, 70)
		d.rectangle([x, top, x + bw, H], fill=town)
		if rng.random() < 0.45:
			d.polygon([(x, top), (x + bw // 2, top - rng.randint(16, 40)), (x + bw, top)], fill=town)
		for _ in range(rng.randint(0, 3)):
			wx, wy = x + rng.randint(6, max(7, bw - 10)), top + rng.randint(10, 60)
			d.rectangle([wx, wy, wx + 4, wy + 6], fill=(190, 104, 46))
		x += bw - rng.randint(0, 10)
	stacks = []
	for sx in (0.07, 0.13, 0.46, 0.52, 0.58, 0.83, 0.9):
		cx = int(W * sx) + rng.randint(-20, 20)
		top = int(H * rng.uniform(0.3, 0.44))
		wdt = rng.randint(16, 30)
		d.polygon([(cx - wdt, sky_y), (cx - wdt * 0.7, top), (cx + wdt * 0.7, top), (cx + wdt, sky_y)], fill=town)
		d.rectangle([cx - wdt * 0.85, top - 6, cx + wdt * 0.85, top], fill=town)
		stacks.append((cx, top))
	# the great foundry: a long shed with a sawtooth roof, glowing doors
	fx0, fx1 = int(W * 0.40), int(W * 0.66)
	fy = sky_y - 46
	d.rectangle([fx0, fy, fx1, H], fill=(15, 12, 12))
	for i in range((fx1 - fx0) // 40):
		x0 = fx0 + i * 40
		d.polygon([(x0, fy), (x0 + 40, fy - 26), (x0 + 40, fy)], fill=(15, 12, 12))
	for i in range(3):
		dx = fx0 + 60 + i * 150
		d.rectangle([dx, sky_y - 22, dx + 46, sky_y + 10], fill=(232, 120, 40))
	# smoke plumes from the stacks: soft blobs drifting up and right
	plume = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	pd = ImageDraw.Draw(plume)
	for cx, top in stacks:
		px, py, rad = cx, top - 6, 14
		for s in range(26):
			a = int(150 * (1 - s / 26))
			pd.ellipse([px - rad, py - rad, px + rad, py + rad], fill=(58, 46, 44, a))
			px += rng.uniform(4, 12)
			py -= rng.uniform(6, 12)
			rad += rng.uniform(1.5, 3.5)
	plume = plume.filter(ImageFilter.GaussianBlur(6))
	base = Image.alpha_composite(base, plume)
	return base, stacks


def sigil(cx, cy, r, color=(196, 70, 52), alpha=70):
	"""A transmutation circle (Rensei's own: outer rings, a seven-point star, a crescent and tick marks)."""
	img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	c = color + (alpha,)
	for k, wdt in ((1.0, 3), (0.93, 2), (0.62, 2), (0.2, 2)):
		rr = r * k
		d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], outline=c, width=wdt)
	pts = [(cx + math.cos(-math.pi / 2 + i * 2 * math.pi / 7) * r * 0.93, cy + math.sin(-math.pi / 2 + i * 2 * math.pi / 7) * r * 0.93) for i in range(7)]
	for i in range(7):
		d.line([pts[i], pts[(i + 3) % 7]], fill=c, width=2)
	for i in range(56):
		a = i * 2 * math.pi / 56
		r0, r1 = r * 0.93, r * (0.97 if i % 4 else 1.0)
		d.line([(cx + math.cos(a) * r0, cy + math.sin(a) * r0), (cx + math.cos(a) * r1, cy + math.sin(a) * r1)], fill=c, width=2)
	d.arc([cx - r * 0.45, cy - r * 0.45, cx + r * 0.45, cy + r * 0.45], 120, 420, fill=c, width=3)
	return img.filter(ImageFilter.GaussianBlur(1.2))


# ---------- the mid layer: the hall's iron arches, trusses, a crane boom ----------
IRON = (11, 10, 11)


def lattice(d, a, b, wdt, bays, color, rim=None):
	"""A riveted lattice girder from a to b."""
	ax, ay = a
	bx, by = b
	L = math.hypot(bx - ax, by - ay)
	nx, ny = -(by - ay) / L * wdt / 2, (bx - ax) / L * wdt / 2
	p = [(ax + nx, ay + ny), (bx + nx, by + ny), (bx - nx, by - ny), (ax - nx, ay - ny)]
	d.line([p[0], p[1]], fill=color, width=6)
	d.line([p[3], p[2]], fill=color, width=6)
	for i in range(bays):
		t0, t1 = i / bays, (i + 1) / bays
		q0 = (ax + (bx - ax) * t0, ay + (by - ay) * t0)
		q1 = (ax + (bx - ax) * t1, ay + (by - ay) * t1)
		d.line([(q0[0] + nx, q0[1] + ny), (q1[0] - nx, q1[1] - ny)], fill=color, width=3)
		d.line([(q0[0] - nx, q0[1] - ny), (q1[0] + nx, q1[1] + ny)], fill=color, width=3)
	if rim:
		d.line([p[3], p[2]], fill=rim, width=2)


def mid_ref():
	img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	rim = (96, 52, 34, 255)
	# left column and the great arch rib over the top
	d.rectangle([0, 0, 64, H], fill=IRON)
	d.rectangle([64, 0, 74, H], fill=(28, 20, 18))
	pts = []
	for i in range(41):
		t = i / 40
		x = 60 + t * (W - 120)
		y = 150 - math.sin(t * math.pi) * 130
		pts.append((x, y))
	d.line(pts, fill=IRON, width=30, joint="curve")
	d.line([(p[0], p[1] + 15) for p in pts], fill=rim, width=2, joint="curve")
	d.rectangle([W - 70, 0, W, H], fill=IRON)
	# roof trusses across the top
	d.rectangle([0, 0, W, 24], fill=IRON)
	for i in range(14):
		x = i * W / 13
		d.line([(x, 24), (x + 70, 120 - abs(i - 6.5) * 9)], fill=IRON, width=5)
		d.line([(x + 140, 24), (x + 70, 120 - abs(i - 6.5) * 9)], fill=IRON, width=5)
	# a crane boom reaching in from the right, behind the slot cards
	lattice(d, (W - 40, int(H * 0.62)), (int(W * 0.7), int(H * 0.2)), 34, 9, IRON, rim)
	d.line([(int(W * 0.7), int(H * 0.2)), (int(W * 0.7), int(H * 0.47))], fill=IRON, width=3)
	d.rectangle([int(W * 0.7) - 14, int(H * 0.47), int(W * 0.7) + 14, int(H * 0.47) + 20], fill=IRON)
	# rivets on the columns
	for y in range(40, H, 46):
		for x in (18, 46, W - 50, W - 22):
			d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=(36, 30, 28))
	return img


# ---------- the alcove wall (concept only: in game these are 3D parts) ----------
WALL_TOP = 0.66
NICHES = [0.39, 0.505, 0.62, 0.735, 0.85]  # niche centres (x, fraction of W), slots 1-5


def figure(d, cx, foot, hgt, coat, rim, skin=(160, 122, 100), hair=(30, 22, 20)):
	"""A character standing in a niche: head, shoulders, coat (a stand-in for the slot's real character), lit from the lamp above."""
	head = hgt * 0.12
	hy = foot - hgt
	sh = hy + head * 2.1
	# coat: shoulders, body, a split at the hem, arms
	body = [(cx - hgt * 0.17, sh + 6), (cx + hgt * 0.17, sh + 6), (cx + hgt * 0.19, foot - hgt * 0.45), (cx + hgt * 0.25, foot),
		(cx - hgt * 0.25, foot), (cx - hgt * 0.19, foot - hgt * 0.45)]
	d.polygon(body, fill=coat)
	d.rounded_rectangle([cx - hgt * 0.2, sh, cx + hgt * 0.2, sh + 22], radius=10, fill=coat)
	lit = tuple(min(255, int(c * 1.9 + 20)) for c in coat)
	d.rounded_rectangle([cx - hgt * 0.18, sh, cx + hgt * 0.18, sh + 8], radius=4, fill=lit)  # lamp-light on the shoulders
	d.line([(cx, foot - hgt * 0.3), (cx, foot)], fill=tuple(int(c * 0.5) for c in coat), width=3)
	d.line([(cx - hgt * 0.06, sh + 10), (cx, sh + 40), (cx + hgt * 0.06, sh + 10)], fill=(120, 30, 26), width=3)  # collar, the logo's red
	d.ellipse([cx - head * 0.75, hy, cx + head * 0.75, hy + head * 2], fill=skin)
	d.chord([cx - head * 0.85, hy - 4, cx + head * 0.85, hy + head * 1.3], 180, 360, fill=hair)
	for side in (-1, 1):
		d.line([(cx + side * hgt * 0.19, sh + 10), (cx + side * hgt * 0.22, foot - hgt * 0.38)], fill=coat, width=int(hgt * 0.07))
	d.line([(cx + hgt * 0.19, sh + 8), (cx + hgt * 0.25, foot - 4)], fill=rim, width=3)
	d.arc([cx - head * 0.75, hy, cx + head * 0.75, hy + head * 2], -80, 40, fill=rim, width=3)


def wall_ref(seed, states=("Created", "Created", "Empty", "Locked", "Locked")):
	rng = random.Random(seed)
	top = int(H * WALL_TOP)
	n = fbm(W, H - top, seed + 3, base=6, octaves=5, aspect=2)
	stone = np.array([36, 31, 30], np.float32)
	arr = np.broadcast_to(stone, (H - top, W, 3)) * (0.75 + 0.5 * n[..., None])
	ys = np.linspace(0, 1, H - top)[:, None, None]
	arr = arr * (1.1 - 0.5 * ys)
	wall = to_img(arr)
	d = ImageDraw.Draw(wall)
	# stone courses
	for y in range(0, H - top, 34):
		d.line([(0, y), (W, y)], fill=(22, 19, 19), width=2)
		off = 0 if (y // 34) % 2 else 38
		for x in range(-off, W, 76):
			d.line([(x, y), (x, y + 34)], fill=(24, 21, 20), width=2)
	# a coping strip along the top edge, lit by the sky
	d.rectangle([0, 0, W, 14], fill=(48, 40, 37))
	d.line([(0, 1), (W, 1)], fill=(120, 76, 46), width=2)
	# the floor of the platform
	d.rectangle([0, H - top - 70, W, H - top], fill=(20, 17, 16))
	d.line([(0, H - top - 70), (W, H - top - 70)], fill=(70, 50, 38), width=2)
	glows = []
	for i, fx in enumerate(NICHES):
		cx = int(W * fx)
		nw, nh = 150, 250
		x0, y0 = cx - nw // 2, 40
		y1 = y0 + nh
		state = states[i] if i < len(states) else "Locked"
		inner = (10, 9, 9) if state == "Locked" else (24, 17, 14)
		d.rectangle([x0 - 8, y0 + nw // 2 - 8, x0 + nw + 8, y1 + 8], fill=(46, 40, 38))
		d.ellipse([x0 - 8, y0 - 8, x0 + nw + 8, y0 + nw + 8], fill=(46, 40, 38))
		d.rectangle([x0, y0 + nw // 2, x0 + nw, y1], fill=inner)
		d.ellipse([x0, y0, x0 + nw, y0 + nw], fill=inner)
		if state != "Locked":
			# lamp-light falling down the niche
			for k in range(24):
				a = 1 - k / 24
				col = tuple(int(inner[c] + (np.array([150, 86, 40])[c] - inner[c]) * a * 0.55) for c in range(3))
				d.ellipse([cx - 60 + k, y0 + 6 + k * 4, cx + 60 - k, y0 + 70 + k * 6], fill=col)
		d.rectangle([x0 - 14, y1, x0 + nw + 14, y1 + 14], fill=(54, 46, 42))  # the ledge
		d.line([(x0 - 14, y1), (x0 + nw + 14, y1)], fill=(110, 74, 48), width=2)
		# keystone lamp
		d.rectangle([cx - 7, y0 - 20, cx + 7, y0 - 2], fill=(20, 17, 16))
		if state != "Locked":
			d.ellipse([cx - 6, y0 - 4, cx + 6, y0 + 10], fill=(255, 190, 110))
			glows.append((cx, y0 + 4 + top))
		foot = y1 - 2
		if state == "Created":
			coat, skin, hair = [((62, 44, 46), (168, 128, 104), (40, 28, 24)), ((44, 48, 62), (196, 160, 130), (18, 16, 18))][i % 2]
			figure(d, cx, foot, 205, coat, (230, 150, 80), skin, hair)
		elif state == "Empty":
			# a chalk circle and a dust-sheeted mannequin
			d.ellipse([cx - 62, foot - 16, cx + 62, foot + 8], outline=(200, 196, 186), width=3)
			d.ellipse([cx - 50, foot - 12, cx + 50, foot + 4], outline=(160, 156, 148), width=1)
			d.polygon([(cx - 30, foot - 2), (cx - 22, foot - 120), (cx - 12, foot - 160), (cx + 12, foot - 160), (cx + 22, foot - 120),
				(cx + 34, foot - 2)], fill=(122, 116, 108))
			d.ellipse([cx - 20, foot - 190, cx + 20, foot - 150], fill=(122, 116, 108))
			for k in range(4):
				d.line([(cx - 18 + k * 12, foot - 150), (cx - 24 + k * 16, foot - 4)], fill=(96, 90, 84), width=2)
		else:
			# an iron gate across the dark niche
			for gx in range(x0 + 14, x0 + nw, 22):
				d.line([(gx, y0 + nw // 2 - 30), (gx, y1)], fill=(30, 26, 25), width=4)
			d.line([(x0, y0 + nw // 2 + 30), (x0 + nw, y0 + nw // 2 + 30)], fill=(30, 26, 25), width=5)
	full = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	full.paste(wall, (0, top))
	return full, glows


# ---------- the near layer: chains, a hanging lantern ----------
def chain(d, a, b, sag, links, color, hi):
	ax, ay = a
	bx, by = b
	prev = None
	for i in range(links + 1):
		t = i / links
		x = ax + (bx - ax) * t
		y = ay + (by - ay) * t + math.sin(t * math.pi) * sag
		if prev:
			mx, my = (prev[0] + x) / 2, (prev[1] + y) / 2
			ang = math.atan2(y - prev[1], x - prev[0])
			L = math.hypot(x - prev[0], y - prev[1]) * 0.75
			wdt = 7 if i % 2 else 3.5
			# a link: an ellipse along the curve (open on alternate links)
			pts = [(mx + math.cos(ang) * L * math.cos(s) - math.sin(ang) * wdt * math.sin(s),
				my + math.sin(ang) * L * math.cos(s) + math.cos(ang) * wdt * math.sin(s)) for s in np.linspace(0, 2 * math.pi, 18)]
			d.line(pts, fill=color, width=4)
			d.line(pts[2:6], fill=hi, width=1)
		prev = (x, y)


def near_ref():
	img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	chain(d, (-20, 30), (420, -10), 150, 34, (14, 12, 12, 255), (110, 70, 50, 255))
	chain(d, (1500, -10), (W + 30, 60), 110, 30, (14, 12, 12, 255), (110, 70, 50, 255))
	# hanging lantern (left of centre, above the buttons' right edge)
	lx, ly = int(W * 0.29), 250
	d.line([(lx, 0), (lx, ly - 40)], fill=(14, 12, 12, 255), width=4)
	d.polygon([(lx - 26, ly - 40), (lx + 26, ly - 40), (lx + 18, ly - 54), (lx - 18, ly - 54)], fill=(16, 13, 12, 255))
	d.rectangle([lx - 22, ly - 40, lx + 22, ly + 22], fill=(16, 13, 12, 255))
	d.rectangle([lx - 15, ly - 32, lx + 15, ly + 14], fill=(255, 176, 92, 255))
	for gx in (lx - 6, lx + 6):
		d.line([(gx, ly - 32), (gx, ly + 14)], fill=(16, 13, 12, 255), width=3)
	d.polygon([(lx - 26, ly + 22), (lx + 26, ly + 22), (lx, ly + 40)], fill=(16, 13, 12, 255))
	return img, (lx, ly - 9)


# ---------- effects (painted on top, animated in game) ----------
def effects(seed, lamps, stacks):
	rng = random.Random(seed)
	fx = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	# light shafts falling from a gap in the roof
	shafts = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	sd = ImageDraw.Draw(shafts)
	for x0, wdt, a in ((620, 70, 26), (760, 40, 20), (880, 90, 18)):
		sd.polygon([(x0, 0), (x0 + wdt, 0), (x0 + wdt + 560, H), (x0 + 380, H)], fill=(255, 196, 140, a))
	shafts = shafts.filter(ImageFilter.GaussianBlur(26))
	# fog bands low over the platform
	n = fbm(W, H, seed + 11, base=3, octaves=5, aspect=3)
	ys = np.linspace(0, 1, H)[:, None]
	band = smooth(0.8, 0.9, ys) * (1 - smooth(0.97, 1.0, ys)) * smooth(0.4, 0.85, n) + 0.35 * smooth(0.6, 0.66, ys) * (1 - smooth(0.66, 0.7, ys)) * n
	fog = to_img(np.broadcast_to(np.array([118, 108, 106], np.float32), (H, W, 3)), band * 80)
	fx = Image.alpha_composite(fx, fog)
	glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	for cx, cy in lamps:
		glow = Image.alpha_composite(glow, radial(W, H, cx, cy, 170, (255, 150, 70), 2.2, 0.55))
	# the train's lamp and windows
	glow = Image.alpha_composite(glow, radial(W, H, int(W * 0.16) - 20, int(H * 0.5) - 20, 90, (255, 200, 120), 2.0, 0.8))
	# embers and ash rising (red-orange, the logo's red in the hottest ones)
	emb = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	ed = ImageDraw.Draw(emb)
	for _ in range(220):
		x = rng.uniform(0, W)
		y = H * (1 - rng.random() ** 1.6)
		r = rng.choice([1, 1, 1.5, 2, 2.5])
		c = rng.choice([(255, 150, 60), (255, 110, 50), (230, 60, 40), (255, 190, 100)])
		ed.ellipse([x - r, y - r, x + r, y + r], fill=c + (rng.randint(150, 255),))
	for _ in range(90):  # ash flecks (grey, larger, dim)
		x, y = rng.uniform(0, W), rng.uniform(0, H)
		ed.ellipse([x - 1.5, y - 1, x + 1.5, y + 1], fill=(150, 140, 136, 90))
	ember_glow = emb.filter(ImageFilter.GaussianBlur(4))
	return fx, shafts, glow, emb, ember_glow


def grain_and_vignette(img, seed):
	a = np.asarray(img, np.float32)
	n = fbm(W, H, seed + 21, base=180, octaves=2)
	a[..., :3] *= (0.94 + 0.12 * n[..., None])
	yy, xx = np.mgrid[0:H, 0:W]
	dx, dy = (xx - W * 0.55) / (W * 0.62), (yy - H * 0.48) / (H * 0.62)
	v = np.clip(1 - (dx ** 2 + dy ** 2) * 0.55, 0.25, 1) ** 1.4
	a[..., :3] *= v[..., None]
	# and a darker left third, where the logo and buttons sit (as in the layout reference)
	left = smooth(0, 0.42, xx / W)
	a[..., :3] *= (0.55 + 0.45 * left)[..., None]
	return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


# ---------- UI art: the slot card frame and the button frame ----------
STEEL_HI, STEEL_MID, STEEL_LO = (214, 218, 226), (132, 136, 146), (52, 54, 62)
GOLD = (230, 205, 120)
BLOOD = (150, 26, 22)


def steel(d, pts, width, s):
	"""A steel rail: dark under-stroke, mid body, a thin highlight on top."""
	d.line([(x, y + s) for x, y in pts], fill=STEEL_LO + (255,), width=width + 2 * s)
	d.line(pts, fill=STEEL_MID + (255,), width=width)
	d.line([(x, y - width * 0.25) for x, y in pts], fill=STEEL_HI + (255,), width=max(1, width // 3))


def stud(d, cx, cy, r, s):
	d.polygon([(cx, cy - r - s), (cx + r + s, cy), (cx, cy + r + s), (cx - r - s, cy)], fill=STEEL_LO + (255,))
	d.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], fill=STEEL_MID + (255,))
	d.polygon([(cx, cy - r), (cx + r, cy), (cx, cy)], fill=STEEL_HI + (255,))


def crescent(d, cx, cy, r, facing, s, accent=BLOOD):
	"""A crescent end-cap (horns pointing inward), as on the Health / Posture frames."""
	box = [cx - r, cy - r, cx + r, cy + r]
	d.ellipse([b + (-s if i < 2 else s) for i, b in enumerate(box)], fill=STEEL_LO + (255,))
	d.ellipse(box, fill=STEEL_MID + (255,))
	off = r * 0.55 * facing
	d.ellipse([cx - r * 0.8 + off, cy - r * 0.8, cx + r * 0.8 + off, cy + r * 0.8], fill=(0, 0, 0, 0))
	d.arc(box, 200 if facing > 0 else -20, 250 if facing > 0 else 30, fill=STEEL_HI + (255,), width=max(1, s))
	d.ellipse([cx - r * 0.22 - off * 0.3, cy - r * 0.22, cx + r * 0.22 - off * 0.3, cy + r * 0.22], fill=accent + (255,))


def scroll(d, cx, cy, r, sx, sy, s, color=STEEL_MID):
	"""A spiral curl at a corner (sx, sy = which way it opens)."""
	pts = []
	for i in range(60):
		t = i / 59 * 3.4 * math.pi
		rr = r * (1 - i / 70)
		pts.append((cx + sx * math.cos(t) * rr, cy + sy * math.sin(t) * rr))
	d.line([(x, y + s) for x, y in pts], fill=STEEL_LO + (255,), width=3 * s)
	d.line(pts, fill=color + (255,), width=2 * s)


def brushed_fill(w, h, seed, alpha=225):
	n = fbm(w, h, seed, base=3, octaves=4, aspect=6)
	streak = fbm(w, h, seed + 1, base=60, octaves=2, aspect=0.05)
	v = 12 + n * 12 + streak * 8
	return to_img(np.dstack([v, v * 0.97, v * 1.02]), np.full((h, w), alpha))


def card_frame(seed, w=860, h=150, hover=False):
	"""The slot card (drawn at 2x: 860 x 150 for a 430 x 75 card). 9-slice margins: 60 px each side at this size."""
	S = 2
	img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	fill = brushed_fill(w - 40, h - 36, seed)
	m = Image.new("L", fill.size, 0)
	ImageDraw.Draw(m).rounded_rectangle([0, 0, fill.size[0] - 1, fill.size[1] - 1], radius=10, fill=255)
	img.paste(fill, (20, 18), m)
	d = ImageDraw.Draw(img)
	top, bot = 16, h - 16
	for y, off in ((top, 0), (top + 7, 1), (bot, 0), (bot - 7, 1)):
		steel(d, [(46, y), (w - 46, y)], 4 if off == 0 else 2, S)
	for x in range(110, w - 100, 92):
		stud(d, x, top, 6, S)
		stud(d, x, bot, 6, S)
	# side rails
	for x in (22, w - 22):
		steel(d, [(x, top + 16), (x, bot - 16)], 3, S)
	crescent(d, 24, h // 2, 22, 1, S)
	crescent(d, w - 24, h // 2, 22, -1, S)
	for cx, cy, sx, sy in ((40, top + 2, 1, 1), (w - 40, top + 2, -1, 1), (40, bot - 2, 1, -1), (w - 40, bot - 2, -1, -1)):
		scroll(d, cx + sx * 16, cy + sy * 2, 14, sx, -sy, S)
	if hover:
		# the kit's gold line-art: sun-ray corners and a crescent row at the top centre
		g = GOLD + (255,)
		for cx, cy, sx, sy in ((58, 30, 1, 1), (w - 58, 30, -1, 1), (58, h - 30, 1, -1), (w - 58, h - 30, -1, -1)):
			for k in range(5):
				a = math.radians(k * 22.5)
				d.line([(cx, cy), (cx + sx * math.cos(a) * 22, cy + sy * math.sin(a) * 22)], fill=g, width=2)
			d.arc([cx - 10, cy - 10, cx + 10, cy + 10], 0, 360, fill=g, width=2)
		mid = w // 2
		for k in range(-2, 3):
			x = mid + k * 22
			d.arc([x - 7, top + 1, x + 7, top + 15], 200 if k < 0 else -20, 340 if k < 0 else 160, fill=g, width=2)
		d.line([(70, h - 30), (w - 70, h - 30)], fill=GOLD + (120,), width=1)
	return img


def button_frame(seed, w=700, h=76):
	"""A thin ornate plate for PLAY / CLAN INDEX (2x: 700 x 76 for 350 x 38). The right end fades into a flourish."""
	S = 2
	img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
	fill = brushed_fill(w - 60, h - 24, seed, 200)
	fade = np.linspace(1, 0, fill.size[0]) ** 1.5
	fa = np.asarray(fill).copy()
	fa[..., 3] = (fa[..., 3] * fade[None, :]).astype(np.uint8)
	img.paste(Image.fromarray(fa, "RGBA"), (34, 12))
	d = ImageDraw.Draw(img)
	steel(d, [(30, h - 10), (w - 120, h - 10)], 3, S)
	steel(d, [(54, 10), (w * 0.55, 10)], 2, S)
	crescent(d, 26, h // 2, 20, 1, S)
	# flourish: a few thinning curls off the right end
	for k, (r, yy) in enumerate(((22, h - 22), (14, h - 30), (9, h - 16))):
		scroll(d, w - 120 + k * 34, yy, r, 1 if k % 2 == 0 else -1, -1, 1)
	stud(d, w * 0.55 + 10, 10, 5, S)
	return img


# ---------- the UI mockup over the scene ----------
def font(name, size):
	try:
		return ImageFont.truetype(FONTS + name, size)
	except OSError:
		return ImageFont.load_default()


def text(d, xy, s, f, fill, shadow=True, anchor="la"):
	if shadow:
		d.text((xy[0] + 2, xy[1] + 2), s, font=f, fill=(0, 0, 0, 200), anchor=anchor)
	d.text(xy, s, font=f, fill=fill, anchor=anchor)


def bust(size, coat, seed):
	"""A painted head-and-shoulders portrait for a card (in game: a ViewportFrame of the slot's rig)."""
	img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	d.ellipse([size * 0.3, size * 0.12, size * 0.7, size * 0.58], fill=(150, 116, 96, 255))
	d.chord([size * 0.26, size * 0.06, size * 0.74, size * 0.46], 180, 360, fill=(36, 26, 24, 255))
	d.polygon([(size * 0.05, size), (size * 0.18, size * 0.66), (size * 0.82, size * 0.66), (size * 0.95, size)], fill=coat + (255,))
	d.line([(size * 0.5, size * 0.66), (size * 0.5, size)], fill=(120, 30, 26, 255), width=3)
	return paint(img, seed, brushes=(6, 3, 2), thresholds=(0, 8, 6))


# Roblox's top bar (its menu, chat and more buttons) covers about the top 60 px on the left at 1080p, so the logo and
# buttons sit well below it (owner 2026-10-28: "lower to compensate for roblox's UI overlap").
LOGO_Y = 168
BUTTONS_Y = 420


# tips for the line at the bottom: each one true of the game (Lore Bible; HeatService: Heat decays -5 per hour, offline too;
# the unlicensed_cast deed)
TIPS = [
	("[EQUIVALENT EXCHANGE]", "Nothing is made from nothing. Every transmutation is paid for, now or later."),
	("[WORD ON THE RAILS]", "Heat cools on its own, even while you're away. Lie low and the State forgets."),
	("[STATE NOTICE]", "Casting without a licence in front of the Authority is a crime."),
]


def compose_ui(scene, logo, seed, hover=0, tip=0):
	"""The UI mockup over scene. hover = the card drawn in its gold hover frame; tip = which TIPS line.
	Given a transparent scene it returns the UI alone, as a layer."""
	ui = scene.copy()
	d = ImageDraw.Draw(ui)
	# the logo (the owner's own, from Roblox) or a stand-in
	if logo:
		lg = Image.open(logo).convert("RGBA")
		lg = lg.resize((int(lg.width * 1.0), int(lg.height * 1.0)), Image.LANCZOS)
		shadow = Image.new("RGBA", lg.size, (0, 0, 0, 0))
		shadow.putalpha(lg.getchannel("A").point(lambda v: v * 0.7))
		ui.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(8)), (112, LOGO_Y + 8))
		ui.alpha_composite(lg, (106, LOGO_Y))
	else:
		text(d, (130, LOGO_Y + 30), "RENSEI", font("palab.ttf", 110), GOLD + (255,))
	f_btn = font("palab.ttf", 26)
	bf = button_frame(seed).resize((350, 38), Image.LANCZOS)
	for i, label in enumerate(("PLAY", "CLAN INDEX")):
		y = BUTTONS_Y + i * 52
		ui.alpha_composite(bf, (110 + (0 if i == 0 else -12), y))
		text(d, (152 + (0 if i == 0 else -12), y + 19), label, f_btn if i == 0 else font("palab.ttf", 21),
			(GOLD if i == 0 else (225, 220, 210)) + (255,), anchor="lm")
	# slot cards: 2 columns, sample data
	card = card_frame(seed).resize((430, 75), Image.LANCZOS)
	card_h = card_frame(seed, hover=True).resize((430, 75), Image.LANCZOS)
	cards = [
		("Created", "Edward Hale", "Lv 14 · Rare", "Amestrian · the Foundry Yard", (96, 20, 18)),
		("Created", "Mei Sorrow", "Lv 3 · Common", "Xingnese · Lindenmoor", (26, 38, 82)),
		("Empty", "CREATE CHARACTER", "", "Slot 3 · empty", None),
		("New", "NEW SLOT", "", "", None),
	]
	f_name, f_sub, f_small = font("pala.ttf", 24), font("pala.ttf", 15), font("palai.ttf", 14)
	for i, (kind, name, sub, info, coat) in enumerate(cards):
		x = 975 + (i % 2) * 448
		y = 86 + (i // 2) * 86
		ui.alpha_composite(card_h if i == hover else card, (x, y))
		if kind == "Created":
			b = bust(56, coat, seed + i)
			m = Image.new("L", (56, 56), 0)
			ImageDraw.Draw(m).ellipse([0, 0, 55, 55], fill=255)
			b.putalpha(Image.fromarray(np.minimum(np.asarray(b.getchannel("A")), np.asarray(m))))
			ui.alpha_composite(b, (x + 34, y + 10))
			text(d, (x + 102, y + 30), name, f_name, (232, 226, 214, 255), anchor="ls")
			rare = (110, 150, 230) if "Rare" in sub else (190, 186, 176)
			text(d, (x + 102, y + 52), sub, f_sub, rare + (255,), anchor="ls")
			text(d, (x + 404, y + 30), info.split(" · ")[1], f_sub, (225, 220, 210, 255), anchor="rs")
			text(d, (x + 404, y + 50), info.split(" · ")[0], f_small, (150, 142, 130, 255), anchor="rs")
			# star / trash / edit glyphs
			for k, (g, c) in enumerate((("★" if i == 0 else "☆", GOLD), ("✎", (200, 196, 186)), ("✕", (200, 100, 90)))):
				text(d, (x + 410 - (2 - k) * 22, y + 66), g, font("seguisym.ttf", 14), c + (255,), anchor="rs")
		elif kind == "Empty":
			text(d, (x + 40, y + 45), name, font("palab.ttf", 22), (225, 220, 210, 255), anchor="ls")
			text(d, (x + 404, y + 45), "free", f_small, (150, 142, 130, 255), anchor="rs")
		else:
			text(d, (x + 40, y + 45), name, font("palab.ttf", 22), (150, 142, 130, 255), anchor="ls")
			text(d, (x + 404, y + 36), "R$ 200", font("palab.ttf", 18), GOLD + (255,), anchor="rs")
			text(d, (x + 404, y + 56), "live price", f_small, (150, 142, 130, 255), anchor="rs")
	# the tip line
	label, line = TIPS[tip % len(TIPS)]
	lf = font("palab.ttf", 16)
	text(d, (48, 1046), label, lf, (196, 70, 52, 255), anchor="ls")
	text(d, (48 + d.textlength(label, font=lf) + 16, 1046), line, font("pala.ttf", 16), (200, 194, 184, 255), anchor="ls")
	return ui


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("--out", default="E:/Rensei/Renders/MainMenu/concept")
	ap.add_argument("--logo", default="E:/Rensei/Work/main-menu/dl_logo/rensei_logo_420.png")
	ap.add_argument("--seed", type=int, default=28)
	ap.add_argument("--scene", help="a finished scene image (e.g. menu_scene.py's scene_painted.png): only grade it and lay the UI over it")
	a = ap.parse_args()
	os.makedirs(a.out, exist_ok=True)
	s = a.seed
	logo = a.logo if a.logo and os.path.exists(a.logo) else None

	if a.scene:
		scene = grain_and_vignette(Image.open(a.scene).convert("RGBA").resize((W, H), Image.LANCZOS), s)
		scene.convert("RGB").save(os.path.join(a.out, "scene_graded.png"))
		card_frame(s).save(os.path.join(a.out, "card_frame.png"))
		card_frame(s, hover=True).save(os.path.join(a.out, "card_frame_hover.png"))
		button_frame(s).save(os.path.join(a.out, "button_frame.png"))
		compose_ui(scene, logo, s).convert("RGB").save(os.path.join(a.out, "concept_menu.png"))
		print("written to", a.out)
		return

	far, stacks = far_ref(s)
	far = Image.alpha_composite(far, sigil(int(W * 0.47), int(H * 0.25), 165, alpha=120))
	far_p = paint(far, s, brushes=(34, 18, 9, 4), flow=0.08)
	far_p.save(os.path.join(a.out, "layer_far.png"))
	mid_p = paint(mid_ref(), s + 1, brushes=(16, 8, 4, 2), thresholds=(0, 12, 10, 8), flow=1.3)
	mid_p.save(os.path.join(a.out, "layer_mid.png"))
	wall, lamps = wall_ref(s + 2)
	wall_p = paint(wall, s + 2, brushes=(20, 10, 5, 2), thresholds=(0, 12, 10, 8), flow=0.0)
	wall_p.save(os.path.join(a.out, "layer_wall.png"))
	near, lantern = near_ref()
	near_p = paint(near, s + 3, brushes=(10, 5, 2), thresholds=(0, 10, 8), flow=1.5)
	near_p.save(os.path.join(a.out, "layer_near.png"))

	fog, shafts, glow, emb, ember_glow = effects(s + 4, lamps + [lantern], stacks)
	fog_p = paint(fog, s + 5, brushes=(40, 20), thresholds=(0, 8), flow=0.0)
	scene = far_p
	scene = add(scene, shafts)
	scene = Image.alpha_composite(scene, mid_p)
	scene = Image.alpha_composite(scene, wall_p)
	scene = Image.alpha_composite(scene, fog_p)
	scene = add(scene, glow)
	scene = add(scene, radial(W, H, lantern[0], lantern[1], 260, (255, 160, 80), 2.0, 0.6))
	scene = Image.alpha_composite(scene, near_p)
	scene = add(scene, ember_glow)
	scene = add(scene, emb)
	scene = grain_and_vignette(scene, s)
	fx = Image.alpha_composite(Image.alpha_composite(fog_p, shafts), emb)
	fx.save(os.path.join(a.out, "effects.png"))
	scene.convert("RGB").save(os.path.join(a.out, "scene.png"))

	card_frame(s).save(os.path.join(a.out, "card_frame.png"))
	card_frame(s, hover=True).save(os.path.join(a.out, "card_frame_hover.png"))
	button_frame(s).save(os.path.join(a.out, "button_frame.png"))
	compose_ui(scene, a.logo if a.logo and os.path.exists(a.logo) else None, s).convert("RGB").save(os.path.join(a.out, "concept_menu.png"))
	print("written to", a.out)


if __name__ == "__main__":
	main()

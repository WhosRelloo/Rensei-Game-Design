"""Textures for the menu diorama (menu_scene.py): Rensei's own designs, in the series' mood (owner 2026-10-28:
"make it more FMA like Rensei's theme", then "Make the textures higher quality"; Lore Bible §1: series words
welcome, the series' symbols and plot not).

    python Art/MainMenu/menu_textures.py [--out E:/Rensei/Work/main-menu/tex]

Every texture is painted in layers (base, material detail, wear, grime) at full size:
- circle_chalk.png   4096², a hand-drawn transmutation circle in chalk (white + alpha): wobbling lines, grain, dust
- circle_ancient.png 4096², an old Mezarath-style circle (the buried-debt red is added in Blender)
- banner.png         1024 x 2560, a State Authority banner: woven navy cloth, silver embroidery, braided trim,
                     a tassel fringe, soot and stains (+ banner_height.png for bump)
- clock.png          2048², a station clock: aged crazed enamel, brass bezel, worn numerals, a glass glint
- sign.png           2048 x 410, a vitreous-enamel station sign, "FOUNDRY YARD": chips, rusted bolts, streaks
"""
import argparse
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from paint_menu import fbm, smooth  # noqa: E402  (the same noise as the painted concept)

FONTS = "C:/Windows/Fonts/"


def arr(img):
	return np.asarray(img, np.float32)


def img_of(a, mode="RGBA"):
	return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), mode)


def grime(rgb, seed, amount=0.35, scale=4, dark=(30, 24, 20)):
	"""Multiply in soot and dirt: broad patches plus fine speckle."""
	h, w = rgb.shape[:2]
	broad = fbm(w, h, seed, base=scale, octaves=6, aspect=w / h)
	fine = fbm(w, h, seed + 1, base=scale * 40, octaves=2, aspect=w / h)
	k = smooth(0.45, 0.9, broad) * amount + (fine - 0.5) * 0.08
	return rgb * (1 - k[..., None]) + np.array(dark, np.float32) * k[..., None]


# ---------- alchemical marks (Rensei's own set) ----------
def glyph(draw_line, cx, cy, s, kind):
	"""Calls draw_line(points) for each stroke of a mark."""
	def poly(pts):
		draw_line(pts + [pts[0]])

	def ring(r, a0=0, a1=360, ox=0, oy=0):
		draw_line([(cx + ox + math.cos(math.radians(a)) * r, cy + oy + math.sin(math.radians(a)) * r) for a in np.linspace(a0, a1, 48)])
	up = [(cx, cy - s), (cx + s * 0.87, cy + s * 0.5), (cx - s * 0.87, cy + s * 0.5)]
	dn = [(cx, cy + s), (cx + s * 0.87, cy - s * 0.5), (cx - s * 0.87, cy - s * 0.5)]
	if kind == "fire":
		poly(up)
	elif kind == "water":
		poly(dn)
	elif kind == "air":
		poly(up)
		draw_line([(cx - s * 0.6, cy), (cx + s * 0.6, cy)])
	elif kind == "earth":
		poly(dn)
		draw_line([(cx - s * 0.6, cy), (cx + s * 0.6, cy)])
	elif kind == "salt":
		ring(s)
		draw_line([(cx - s, cy), (cx + s, cy)])
	elif kind == "moon":
		ring(s, 60, 300)
		ring(s * 0.8, 110, 250, ox=s * 0.4)
	elif kind == "sun":
		ring(s)
		ring(s * 0.16)


# ---------- the transmutation circles: hand-drawn chalk ----------
def chalk_circle(size, seed, ancient=False):
	rng = random.Random(seed)
	S = size
	mask = Image.new("L", (S, S), 0)
	d = ImageDraw.Draw(mask)
	wob = fbm(512, 512, seed + 3, base=6, octaves=4)
	base_w = S / 520

	def stroke(pts, w=1.0):
		"""A chalk stroke: wobbled off the true line, pressure varying along it, sometimes overdrawn."""
		dense = []
		for p, q in zip(pts, pts[1:]):
			n = max(2, int(math.hypot(q[0] - p[0], q[1] - p[1]) / (S / 600)))
			for k in range(n):
				t = k / n
				dense.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
		dense.append(pts[-1])
		passes = 2 if rng.random() < 0.5 else 1
		for ps in range(passes):
			off = rng.uniform(-1, 1) * S / 900
			out = []
			for x, y in dense:
				wx = wob[int(y / S * 511) % 512, int(x / S * 511) % 512] - 0.5
				out.append((x + wx * S / 260 + off, y + wx * S / 300 - off))
			for (x0, y0), (x1, y1) in zip(out, out[1:]):
				press = 0.55 + 0.45 * wob[int(x0 / S * 511) % 512, int(y0 / S * 511) % 512]
				d.line([(x0, y0), (x1, y1)], fill=int(255 * press * (1.0 if ps == 0 else 0.6)), width=max(2, int(base_w * w * rng.uniform(0.85, 1.15))))

	def ring(r, w=1.0, gap=None):
		a0 = rng.uniform(0, 360)
		span = 360 + rng.uniform(4, 14)  # chalk circles overlap where they close
		pts = []
		for a in np.linspace(a0, a0 + span, 360):
			if gap and gap[0] < (a % 360) < gap[1]:
				if pts:
					stroke(pts, w)
					pts = []
				continue
			pts.append((S / 2 + math.cos(math.radians(a)) * r, S / 2 + math.sin(math.radians(a)) * r))
		if pts:
			stroke(pts, w)

	R = S * 0.46
	rings = ((1.0, 1.6), (0.95, 1.0), (0.78, 1.3), (0.74, 0.9), (0.36, 1.1)) if not ancient else \
		((1.0, 1.8), (0.97, 1.0), (0.88, 1.2), (0.7, 1.4), (0.66, 0.9), (0.5, 1.0), (0.3, 1.2), (0.27, 0.8))
	for k, w in rings:
		ring(R * k, w)
	n = 7
	pts = [(S / 2 + math.cos(-math.pi / 2 + i * 2 * math.pi / n) * R * 0.74, S / 2 + math.sin(-math.pi / 2 + i * 2 * math.pi / n) * R * 0.74) for i in range(n)]
	for i in range(n):
		stroke([pts[i], pts[(i + 3) % n]], 1.2)
	if ancient:
		for i in range(24):
			a = i * 2 * math.pi / 24
			stroke([(S / 2 + math.cos(a) * R * 0.88, S / 2 + math.sin(a) * R * 0.88), (S / 2 + math.cos(a) * R * 0.97, S / 2 + math.sin(a) * R * 0.97)], 0.9)
		q = R * 0.3
		stroke([(S / 2, S / 2 - q), (S / 2 + q, S / 2), (S / 2, S / 2 + q), (S / 2 - q, S / 2), (S / 2, S / 2 - q)], 1.1)
		q2 = q / math.sqrt(2)
		stroke([(S / 2 - q2, S / 2 - q2), (S / 2 + q2, S / 2 - q2), (S / 2 + q2, S / 2 + q2), (S / 2 - q2, S / 2 + q2), (S / 2 - q2, S / 2 - q2)], 1.1)
	marks = ["fire", "water", "air", "earth", "salt", "moon", "sun"]
	for i in range(n):
		a = -math.pi / 2 + (i + 0.5) * 2 * math.pi / n
		glyph(lambda p: stroke(p, 0.8), S / 2 + math.cos(a) * R * 0.865, S / 2 + math.sin(a) * R * 0.865, R * 0.055, marks[i])
	glyph(lambda p: stroke(p, 1.0), S / 2, S / 2, R * 0.15, "salt" if ancient else "sun")
	# chalk grain: the stone's tooth breaks the line up
	m = arr(mask) / 255
	tooth = fbm(S, S, seed + 7, base=S // 6, octaves=2)
	tooth2 = fbm(S, S, seed + 8, base=S // 24, octaves=3)
	m = m * smooth(0.25, 0.7, tooth * 0.7 + tooth2 * 0.3)
	# dust: a faint smear around every line, and a few hand smudges
	dust = arr(mask.filter(ImageFilter.GaussianBlur(S / 300))) / 255 * 0.22
	smudge = Image.new("L", (S, S), 0)
	sd = ImageDraw.Draw(smudge)
	for _ in range(6):
		a, r = rng.uniform(0, 2 * math.pi), R * rng.uniform(0.4, 1.0)
		x, y = S / 2 + math.cos(a) * r, S / 2 + math.sin(a) * r
		sd.ellipse([x - S / 30, y - S / 60, x + S / 30, y + S / 60], fill=40)
	dust += arr(smudge.filter(ImageFilter.GaussianBlur(S / 80))) / 255
	alpha = np.clip(m + dust * (0.6 + 0.4 * tooth2), 0, 1)
	rgb = np.broadcast_to(np.array([236, 233, 226], np.float32), (S, S, 3))
	return img_of(np.dstack([rgb, alpha * 255]))


# ---------- the State Authority banner ----------
def weave(w, h, seed, thread=6):
	"""A plain-weave cloth height field in 0..1."""
	yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
	warp = 0.5 + 0.5 * np.sin(xx * 2 * math.pi / thread)
	weft = 0.5 + 0.5 * np.sin(yy * 2 * math.pi / thread)
	over = (np.floor(xx / thread) + np.floor(yy / thread)) % 2
	hgt = np.where(over > 0, warp * 0.7 + weft * 0.3, weft * 0.7 + warp * 0.3)
	slub = fbm(w, h, seed, base=w // 10, octaves=2, aspect=0.15)
	return np.clip(hgt * 0.8 + slub * 0.2, 0, 1)


def embroider(size, draw_fn, color, seed):
	"""Raised thread work: a shape drawn by draw_fn(draw, width), shaded as a ridge (light above, shadow below),
	with satin-stitch striping. Returns (rgba, height)."""
	w, h = size
	m = Image.new("L", size, 0)
	draw_fn(ImageDraw.Draw(m), 1.0)
	ridge = arr(m.filter(ImageFilter.GaussianBlur(3))) / 255
	gy, gx = np.gradient(ridge)
	light = np.clip(0.75 - gy * 9 - gx * 3, 0.25, 1.25)
	yy, xx = np.mgrid[0:h, 0:w]
	stitch = 0.85 + 0.15 * np.sin((xx + yy) * 2 * math.pi / 5)
	a = arr(m) / 255
	rgb = np.array(color, np.float32) * (light * stitch)[..., None]
	shadow = arr(m.filter(ImageFilter.GaussianBlur(4))) / 255
	return rgb, a, ridge, shadow


def banner(seed, w=1024, h=2560):
	navy = np.array([24, 32, 64], np.float32)
	wv = weave(w, h, seed)
	tone = fbm(w, h, seed + 1, base=3, octaves=5, aspect=w / h)
	rgb = navy * (0.78 + 0.32 * wv[..., None]) * (0.85 + 0.3 * tone[..., None])
	# folds: soft vertical light and shade where the cloth hangs
	xs = np.linspace(0, 1, w)
	fold = 0.88 + 0.12 * np.sin(xs * math.pi * 5 + 0.7) + 0.05 * np.sin(xs * math.pi * 13)
	rgb *= fold[None, :, None]
	height = wv * 0.3
	shape = Image.new("L", (w, h), 0)
	ImageDraw.Draw(shape).polygon([(0, 0), (w, 0), (w, h * 0.9), (w / 2, h), (0, h * 0.9)], fill=255)
	alpha = arr(shape)
	# the braided gold trim along the edges
	trim = Image.new("L", (w, h), 0)
	td = ImageDraw.Draw(trim)
	edge = [(18, 0), (18, h * 0.9 - 10), (w / 2, h - 26), (w - 18, h * 0.9 - 10), (w - 18, 0)]
	td.line(edge, fill=255, width=30)
	tm = arr(trim) / 255
	yy, xx = np.mgrid[0:h, 0:w]
	braid = 0.6 + 0.4 * np.abs(np.sin((xx * 0.7 + yy) * 2 * math.pi / 18))
	gold = np.array([176, 140, 70], np.float32) * braid[..., None] * (0.8 + 0.4 * tone[..., None])
	rgb = rgb * (1 - tm[..., None]) + gold * tm[..., None]
	height = np.maximum(height, tm * braid * 0.8)
	# the emblem: circle, seven-point star, the red stone at its heart; and the lettering
	cx, cy, R = w / 2, h * 0.4, w * 0.33
	silver = (206, 210, 220)

	def emblem(d, k):
		for rr, wd in ((1.0, 22), (0.86, 12)):
			d.ellipse([cx - R * rr, cy - R * rr, cx + R * rr, cy + R * rr], outline=255, width=wd)
		pts = [(cx + math.cos(-math.pi / 2 + i * 2 * math.pi / 7) * R * 0.86, cy + math.sin(-math.pi / 2 + i * 2 * math.pi / 7) * R * 0.86) for i in range(7)]
		for i in range(7):
			d.line([pts[i], pts[(i + 3) % 7]], fill=255, width=13)
		f = ImageFont.truetype(FONTS + "palab.ttf", 104)
		d.text((cx, h * 0.69), "STATE", font=f, fill=255, anchor="mm")
		d.text((cx, h * 0.745), "AUTHORITY", font=f, fill=255, anchor="mm")
	er, ea, eh, es = embroider((w, h), emblem, silver, seed)
	rgb = rgb * (1 - es[..., None] * 0.45)  # the thread's shadow on the cloth
	rgb = rgb * (1 - ea[..., None]) + er * ea[..., None]
	height = np.maximum(height, eh)
	stone = Image.new("L", (w, h), 0)
	ImageDraw.Draw(stone).ellipse([cx - R * 0.2, cy - R * 0.2, cx + R * 0.2, cy + R * 0.2], fill=255)
	sm = arr(stone.filter(ImageFilter.GaussianBlur(2))) / 255
	sy = (yy - (cy - R * 0.08)) / (R * 0.2)
	sx = (xx - (cx - R * 0.06)) / (R * 0.2)
	gleam = np.clip(1 - (sx ** 2 + sy ** 2), 0, 1) ** 3
	red = (np.array([96, 22, 18], np.float32) + gleam[..., None] * np.array([46, 22, 16], np.float32)) * (0.85 + 0.3 * tone[..., None])  # dull red, warm (Lore Bible: a Philosopher's Stone)
	rgb = rgb * (1 - sm[..., None]) + red * sm[..., None]
	# the fringe: tassel threads below the point
	fr = Image.new("L", (w, h), 0)
	fd = ImageDraw.Draw(fr)
	rng = random.Random(seed)
	for x in range(30, w - 30, 7):
		top = h * 0.9 + (x - w / 2 if x > w / 2 else w / 2 - x) * -0.2 + (h * 0.1 - 26) * (1 - abs(x - w / 2) / (w / 2)) - 14
		fd.line([(x, top), (x + rng.uniform(-6, 6), top + rng.uniform(70, 110))], fill=255, width=4)
	fm = arr(fr) / 255
	alpha = np.maximum(alpha, fm * 255)
	rgb = rgb * (1 - fm[..., None]) + gold * 0.85 * fm[..., None]
	# soot rising from the bottom, sun-fade at the top, a few stains
	ys = np.linspace(0, 1, h)[:, None, None]
	rgb = rgb * (1 - smooth(0.6, 1.0, ys) * 0.35) + np.array([40, 40, 46], np.float32) * smooth(0.0, 0.15, 1 - ys) * 0.15
	rgb = grime(rgb, seed + 5, 0.3, 3)
	# the hem: a darker sleeve for the hanging pole
	rgb[:70] *= 0.6
	return img_of(np.dstack([rgb, alpha])), img_of(np.clip(height, 0, 1) * 255, "L")


# ---------- the station clock ----------
def clock(seed, size=2048):
	S = size
	c = S / 2
	yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
	r = np.sqrt((xx - c) ** 2 + (yy - c) ** 2) / c
	ang = np.arctan2(yy - c, xx - c)
	# enamel face: cream, yellowed toward the rim
	tone = fbm(S, S, seed, base=4, octaves=6)
	face = np.array([234, 224, 198], np.float32) * (0.92 + 0.1 * tone[..., None])
	face = face * (1 - smooth(0.4, 0.92, r)[..., None] * 0.18) + np.array([60, 40, 0], np.float32) * smooth(0.5, 0.92, r)[..., None] * 0.1
	img = img_of(np.dstack([face, np.full((S, S), 255)]))
	d = ImageDraw.Draw(img)
	ink = (26, 22, 20, 255)
	f = ImageFont.truetype(FONTS + "palab.ttf", int(S * 0.085))
	for i, rn in enumerate(["XII", "I", "II", "III", "IIII", "V", "VI", "VII", "VIII", "IX", "X", "XI"]):
		a = -math.pi / 2 + i * math.pi / 6
		d.text((c + math.cos(a) * S * 0.345, c + math.sin(a) * S * 0.345), rn, font=f, fill=ink, anchor="mm")
	d.ellipse([c - S * 0.44, c - S * 0.44, c + S * 0.44, c + S * 0.44], outline=ink, width=6)
	d.ellipse([c - S * 0.415, c - S * 0.415, c + S * 0.415, c + S * 0.415], outline=ink, width=3)
	for i in range(60):
		a = i * math.pi / 30
		r0 = S * (0.415 if i % 5 else 0.4)
		d.line([(c + math.cos(a) * r0, c + math.sin(a) * r0), (c + math.cos(a) * S * 0.44, c + math.sin(a) * S * 0.44)], fill=ink, width=6 if i % 5 else 14)
	d.text((c, c + S * 0.17), "STATE RAILWAY", font=ImageFont.truetype(FONTS + "pala.ttf", int(S * 0.03)), fill=ink, anchor="mm")
	# hands at ten to seven (dusk): spade hour hand, long minute hand
	def hand(a, L, wd, tip):
		ca, sa = math.cos(a), math.sin(a)
		px, py = -sa, ca
		pts = [(c - ca * S * 0.06 + px * wd, c - sa * S * 0.06 + py * wd), (c + ca * L * S + px * wd * 0.6, c + sa * L * S + py * wd * 0.6),
			(c + ca * (L + tip) * S, c + sa * (L + tip) * S), (c + ca * L * S - px * wd * 0.6, c + sa * L * S - py * wd * 0.6),
			(c - ca * S * 0.06 - px * wd, c - sa * S * 0.06 - py * wd)]
		d.polygon([(x + 10, y + 12) for x, y in pts], fill=(0, 0, 0, 70))  # its shadow on the face
		d.polygon(pts, fill=(18, 14, 12, 255))
	hand(math.radians(-90 + 6.83 * 30), 0.2, 22, 0.06)
	hand(math.radians(-90 + 50 * 6), 0.33, 12, 0.04)
	d.ellipse([c - 30, c - 30, c + 30, c + 30], fill=(18, 14, 12, 255))
	a = arr(img)
	# worn ink: the numerals and ticks rub away in places
	wear = smooth(0.62, 0.8, fbm(S, S, seed + 2, base=24, octaves=3))
	dark = (a[..., :3].sum(-1) < 200)[..., None]
	a[..., :3] = np.where(dark, a[..., :3] * (1 - wear[..., None]) + face * wear[..., None] * 0.9, a[..., :3])
	# crazing: a web of fine cracks in the enamel
	cr = Image.new("L", (S, S), 0)
	cd = ImageDraw.Draw(cr)
	rng = random.Random(seed)
	for _ in range(160):
		x, y = rng.uniform(0, S), rng.uniform(0, S)
		th = rng.uniform(0, 2 * math.pi)
		pts = [(x, y)]
		for _ in range(rng.randint(3, 9)):
			th += rng.uniform(-0.9, 0.9)
			x, y = x + math.cos(th) * S / 60, y + math.sin(th) * S / 60
			pts.append((x, y))
		cd.line(pts, fill=rng.randint(40, 110), width=2)
	k = arr(cr)[..., None] / 255
	a[..., :3] = a[..., :3] * (1 - k * 0.55)
	a[..., :3] = grime(a[..., :3], seed + 4, 0.25, 5, (70, 54, 30))
	# the brass bezel: a ring with an angular metallic sheen and tarnish
	bez = (r > 0.9) & (r <= 1.0)
	sheen = 0.55 + 0.45 * np.cos(ang * 2 - 0.8) ** 2
	prof = np.cos((r - 0.95) / 0.05 * math.pi / 2)
	brass = np.array([168, 128, 62], np.float32) * (sheen * (0.5 + 0.6 * prof))[..., None]
	tarn = fbm(S, S, seed + 6, base=10, octaves=4)
	brass = brass * (1 - smooth(0.55, 0.8, tarn)[..., None] * 0.5) + np.array([40, 60, 44], np.float32) * smooth(0.6, 0.85, tarn)[..., None] * 0.4
	a[..., :3] = np.where(bez[..., None], brass, a[..., :3])
	inner = (r > 0.885) & (r <= 0.9)
	a[..., :3] = np.where(inner[..., None], a[..., :3] * 0.4, a[..., :3])
	# the glass: a soft glint across the upper left
	glint = np.clip(1 - np.abs((xx - c) * 0.6 + (yy - c) + S * 0.18) / (S * 0.05), 0, 1) * (r < 0.88) * smooth(0.0, 0.5, (c - yy) / c + 0.3)
	a[..., :3] = a[..., :3] + glint[..., None] * 60
	a[..., 3] = np.where(r <= 1.0, 255, 0)
	return img_of(a)


# ---------- the enamel station sign ----------
def sign(seed, w=2048, h=410):
	yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
	tone = fbm(w, h, seed, base=4, octaves=5, aspect=w / h)
	navy = np.array([22, 36, 72], np.float32) * (0.85 + 0.3 * tone[..., None])
	# glossy enamel: a long soft highlight band and slight waviness
	gloss = np.exp(-((yy - h * 0.3 - np.sin(xx / w * 9) * 10) / (h * 0.12)) ** 2) * 0.35
	base = navy * (1 + gloss[..., None])
	img = img_of(np.dstack([base, np.full((h, w), 255)]))
	d = ImageDraw.Draw(img)
	cream = (232, 224, 202, 255)
	m = Image.new("L", (w, h), 0)
	ImageDraw.Draw(m).rounded_rectangle([0, 0, w - 1, h - 1], radius=48, fill=255)
	d.rounded_rectangle([10, 10, w - 11, h - 11], radius=44, outline=cream, width=18)
	d.rounded_rectangle([44, 44, w - 45, h - 45], radius=30, outline=cream, width=6)
	f = ImageFont.truetype(FONTS + "palab.ttf", 196)
	d.text((w / 2, h / 2 + 8), "FOUNDRY YARD", font=f, fill=cream, anchor="mm")
	a = arr(img)
	a[..., :3] = a[..., :3] * (1 + gloss[..., None] * 0.4)
	# chips: the enamel broken off down to dark iron, each with a rust halo
	rng = random.Random(seed)
	chips = Image.new("L", (w, h), 0)
	cd = ImageDraw.Draw(chips)
	for _ in range(28):
		x, y = rng.choice([rng.uniform(0, w), rng.uniform(0, 120), rng.uniform(w - 120, w)]), rng.uniform(0, h)
		if rng.random() < 0.5:
			y = rng.choice([rng.uniform(0, 40), rng.uniform(h - 40, h)])
		r = rng.uniform(6, 26)
		pts = [(x + math.cos(t) * r * rng.uniform(0.5, 1.2), y + math.sin(t) * r * rng.uniform(0.5, 1.2)) for t in np.linspace(0, 2 * math.pi, 9)]
		cd.polygon(pts, fill=255)
	cm = arr(chips) / 255
	halo = arr(chips.filter(ImageFilter.GaussianBlur(10))) / 255
	rust = np.array([118, 58, 26], np.float32) * (0.7 + 0.5 * tone[..., None])
	iron = np.array([30, 26, 24], np.float32)
	a[..., :3] = a[..., :3] * (1 - halo[..., None] * 0.6) + rust * halo[..., None] * 0.6
	a[..., :3] = a[..., :3] * (1 - cm[..., None]) + iron * cm[..., None]
	# bolts at each end, with rust running down from them
	for bx in (100, w - 100):
		streak = np.exp(-((xx - bx) / 14) ** 2) * smooth(h / 2, h / 2 + 20, yy) * np.exp(-(yy - h / 2) / (h * 0.5)) * (0.5 + 0.5 * fbm(w, h, seed + bx, base=40, octaves=2, aspect=0.05))
		a[..., :3] = a[..., :3] * (1 - streak[..., None] * 0.7) + rust * streak[..., None] * 0.7
		bd = ImageDraw.Draw(img2 := img_of(a))
		bd.ellipse([bx - 26, h / 2 - 26, bx + 26, h / 2 + 26], fill=(46, 40, 36, 255))
		bd.ellipse([bx - 18, h / 2 - 18, bx + 18, h / 2 + 18], fill=(84, 74, 66, 255))
		bd.line([(bx - 14, h / 2), (bx + 14, h / 2)], fill=(30, 26, 24, 255), width=6)
		a = arr(img2)
	a[..., :3] = grime(a[..., :3], seed + 9, 0.3, 4)
	a[..., 3] = arr(m)
	return img_of(a)


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("--out", default="E:/Rensei/Work/main-menu/tex")
	a = ap.parse_args()
	os.makedirs(a.out, exist_ok=True)
	chalk_circle(4096, 5).save(os.path.join(a.out, "circle_chalk.png"))
	chalk_circle(4096, 9, ancient=True).save(os.path.join(a.out, "circle_ancient.png"))
	b, bh = banner(3)
	b.save(os.path.join(a.out, "banner.png"))
	bh.save(os.path.join(a.out, "banner_height.png"))
	clock(4).save(os.path.join(a.out, "clock.png"))
	sign(6).save(os.path.join(a.out, "sign.png"))
	print("written to", a.out)


if __name__ == "__main__":
	main()

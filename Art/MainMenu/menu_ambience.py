"""The menu's ambience, synthesised from scratch (owner 2026-10-28: "animated background, ambiance, etc.").
Nothing sampled: every sound is filtered noise, sines and envelopes made here.

    python Art/MainMenu/menu_ambience.py --out E:/Rensei/Renders/MainMenu/anim/ambience.wav [--seconds 11.5] [--pan-at 8.0] [--pan-len 2.5]
    python Art/MainMenu/menu_ambience.py --loop --seconds 60 --out .../ambience_loop.wav   (a seamless bed for the game, no pan)

Layers: the foundry's rumble and furnace roar, the hall's air, a train crossing (chug, rail clacks, a distant steam
whistle), the station clock's tick, and the alchemy reaction's crackle; at the pan the crackle surges, a shimmer rises
and the circle settles with a low thump.
"""
import argparse
import math
import wave

import numpy as np

SR = 44100


def band(x, lo, hi, soft=0.15):
	"""Band-pass by FFT mask (smooth edges)."""
	X = np.fft.rfft(x)
	f = np.fft.rfftfreq(len(x), 1 / SR)
	m = np.ones_like(f)
	if lo > 0:
		m *= 1 / (1 + np.exp(np.clip(-(f - lo) / (lo * soft), -60, 60)))
	if hi:
		m *= 1 / (1 + np.exp(np.clip((f - hi) / (hi * soft), -60, 60)))
	return np.fft.irfft(X * m, len(x))


def norm(x):
	return x / (np.abs(x).max() + 1e-9)


def env_exp(n, decay):
	return np.exp(-np.arange(n) / (decay * SR))


def place(out, sig, t, pan=0.0, gain=1.0):
	"""Add a mono signal into the stereo buffer at time t (s), equal-power pan -1..1."""
	i = int(t * SR)
	if i >= out.shape[0]:
		return
	if i < 0:
		sig, i = sig[-i:], 0
	sig = sig[: out.shape[0] - i]
	a = (pan + 1) * math.pi / 4
	out[i:i + len(sig), 0] += sig * math.cos(a) * gain
	out[i:i + len(sig), 1] += sig * math.sin(a) * gain


def slow(n, seed, rate=0.2, depth=0.3):
	"""A slow wandering gain around 1."""
	r = np.random.default_rng(seed)
	t = np.arange(n) / SR
	g = np.zeros(n)
	for k in range(4):
		g += np.sin(2 * math.pi * rate * (k + 1) * 0.73 * t + r.uniform(0, 6.3)) / (k + 1)
	return 1 + depth * g / 2


def build(seconds, pan_at=None, pan_len=2.5, loop=False, seed=28):
	rng = np.random.default_rng(seed)
	n = int(seconds * SR)
	out = np.zeros((n, 2))
	t = np.arange(n) / SR
	# the foundry: a deep rumble that breathes, and the furnaces' roar
	brown = np.cumsum(rng.standard_normal(n))
	brown -= np.convolve(brown, np.ones(4096) / 4096, "same")
	rumble = norm(band(brown, 18, 110)) * slow(n, 1, 0.12, 0.35)
	roar = norm(band(rng.standard_normal(n), 70, 380)) * slow(n, 2, 0.25, 0.6)
	air = norm(band(rng.standard_normal(n), 500, 2600)) * slow(n, 3, 0.08, 0.5)
	for sig, g, w in ((rumble, 0.5, 0.0), (roar, 0.16, 0.12), (air, 0.05, 0.25)):
		out[:, 0] += sig * g * (1 - w)
		out[:, 1] += sig * g * (1 + w)
	# the station clock: tick and tock, left of centre
	for k in range(int(seconds)):
		click = band(rng.standard_normal(int(0.02 * SR)), 2500 if k % 2 == 0 else 1700, 7000) * env_exp(int(0.02 * SR), 0.003)
		place(out, norm(click), k + 0.35, -0.3, 0.035)
	# a train crossing the viaduct (left to right over the first 8 s): chug, rail clacks, a steam whistle
	cross = 8.0 if not loop else seconds
	chug_rate = 3.1
	for k in range(int(cross * chug_rate)):
		tt = k / chug_rate + rng.uniform(-0.01, 0.01)
		pos = tt / cross
		dist = math.exp(-((pos - 0.55) / 0.35) ** 2)  # loudest as it passes the middle
		puff = band(rng.standard_normal(int(0.25 * SR)), 120, 900) * env_exp(int(0.25 * SR), 0.06)
		place(out, norm(puff), tt, pos * 1.6 - 0.8, 0.07 * (0.35 + 0.65 * dist) * (1.0 if k % 2 == 0 else 0.7))
	for k in range(int(cross / 0.92)):
		tt = k * 0.92
		pos = tt / cross
		for d in (0.0, 0.11):
			cl = band(rng.standard_normal(int(0.03 * SR)), 900, 4500) * env_exp(int(0.03 * SR), 0.006)
			place(out, norm(cl), tt + d, pos * 1.6 - 0.8, 0.035 * math.exp(-((pos - 0.55) / 0.4) ** 2))
	wt, wl = 1.2, 1.5
	wn = int(wl * SR)
	tw = np.arange(wn) / SR
	vib = 1 + 0.004 * np.sin(2 * math.pi * 5.2 * tw)
	whistle = sum(np.sin(2 * math.pi * f * tw * vib) * a for f, a in ((523, 1.0), (659, 0.7), (784, 0.35), (1046, 0.15)))
	whistle += band(rng.standard_normal(wn), 400, 3000) * 0.25  # steam breath
	whistle *= np.minimum(tw / 0.12, 1) * np.minimum((wl - tw) / 0.5, 1)
	whistle = band(whistle, 300, 2500)  # distant: the highs are gone
	for d, g in ((0.0, 1.0), (0.28, 0.35), (0.56, 0.15)):  # its echo off the town
		place(out, norm(whistle), wt + d, -0.55 + d, 0.06 * g)
	# the reaction's crackle over the platform circle (centre right); it surges at the pan
	tt = 0.0
	while tt < seconds:
		p = 0.0 if pan_at is None else min(max((tt - pan_at) / pan_len, 0.0), 1.0)
		rate = 3.0 + 26.0 * p
		tt += rng.exponential(1 / rate)
		cluster = rng.integers(3, 9)
		g = 0.05 * (1 + 2.5 * p) * rng.uniform(0.5, 1.0)
		for c in range(cluster):
			ln = int(rng.uniform(0.002, 0.008) * SR)
			snap = band(rng.standard_normal(ln + 64), 1800, 9000)[:ln] * env_exp(ln, 0.0025)
			place(out, norm(snap), tt + c * rng.uniform(0.004, 0.02), 0.25 + rng.uniform(-0.2, 0.2), g)
	if pan_at is not None:
		# the transmutation rising as the camera arrives, then the circle settling
		rn = int(pan_len * SR)
		tr = np.arange(rn) / SR
		pr = tr / pan_len
		freq = 220 + 900 * pr ** 1.6
		phase = 2 * math.pi * np.cumsum(freq) / SR
		shimmer = (np.sin(phase) + 0.5 * np.sin(phase * 1.5) + 0.3 * np.sin(phase * 2.01)) * (0.6 + 0.4 * np.sin(2 * math.pi * 11 * tr))
		shimmer += band(rng.standard_normal(rn), 2000, 9000) * 1.2 * pr
		shimmer *= pr ** 1.5 * np.minimum((pan_len - tr) / 0.08, 1)
		place(out, norm(shimmer), pan_at, 0.15, 0.09)
		thump_n = int(1.2 * SR)
		tt2 = np.arange(thump_n) / SR
		thump = np.sin(2 * math.pi * (58 - 18 * tt2) * tt2) * env_exp(thump_n, 0.35) + band(rng.standard_normal(thump_n), 30, 300) * env_exp(thump_n, 0.15) * 0.6
		place(out, norm(thump), pan_at + pan_len - 0.05, 0.0, 0.22)
	if loop:
		# a seamless loop: crossfade the last second into the first
		k = SR
		fade = np.linspace(0, 1, k)[:, None]
		out[:k] = out[:k] * fade + out[-k:] * (1 - fade)
		out = out[:-k]
	else:
		fi = int(0.6 * SR)
		out[:fi] *= np.linspace(0, 1, fi)[:, None]
		fo = int(0.4 * SR)
		out[-fo:] *= np.linspace(1, 0, fo)[:, None]
	return out / (np.abs(out).max() + 1e-9) * 0.89  # -1 dBFS


def write(path, x):
	pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
	with wave.open(path, "wb") as w:
		w.setnchannels(2)
		w.setsampwidth(2)
		w.setframerate(SR)
		w.writeframes(pcm.tobytes())


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("--out", default="E:/Rensei/Renders/MainMenu/anim/ambience.wav")
	ap.add_argument("--seconds", type=float, default=11.5)
	ap.add_argument("--pan-at", type=float, default=8.0)
	ap.add_argument("--pan-len", type=float, default=2.5)
	ap.add_argument("--loop", action="store_true")
	a = ap.parse_args()
	x = build(a.seconds + (1 if a.loop else 0), None if a.loop else a.pan_at, a.pan_len, a.loop)
	write(a.out, x)
	print("written", a.out, round(len(x) / SR, 2), "s")


if __name__ == "__main__":
	main()

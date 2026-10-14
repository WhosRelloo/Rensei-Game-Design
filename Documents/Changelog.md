# Rensei Changelog

What each phase built and how it was tested. Newest first. All work is in the Studio place **Ye**. Backups of every touched script are in `ServerStorage.RenseiBackups`.

## 2026-10-14 — Flame kit complete

**Built:**
- **Scorching Wave (X):** cone.
- **Inferno Lance (C):** burning dash with i-frames.
- **Phoenix Drive (V):** flying phoenix, crash + burn, delayed explosion.
  - Unblockable, so its landing spot gets a red danger ring for everyone.
  - The alchemy circle opens under the caster.
- **Visuals:** all built on the owner's FireElement VFX (cone fire, ground impact, dash burst, phoenix model, explosion).
- **Release rule (owner):** projectile moves use Clap → **Arm Extend** → animation; Ignite switched to it. Ground and body moves keep the Ground Slam.
- **New shared effects:**
  - `Burst`: plays any authored VFX part with its own EmitCount/EmitDelay;
  - `Phoenix`, `Warning`, `Sigil`.

**Tested (Studio Play, real key presses, against passive Bandits):**
- **Scorching Wave:** hit the grunt inside the cone for 90 at 1.72s. The grunt outside the cone took nothing. Meter 100 → 65.
- **Inferno Lance:** 85 the moment the dash starts; 12.8-stud dash in open space; stops on contact.
- **Phoenix Drive:**
  - Danger ring at 0.55s; crash 70 on both grunts in range, explosion 170 0.8s later, burn 4×5. That's 260 total, matching the sheet.
  - A steeply downward aim still lands 12 studs out.
- **Ignite:** confirmed Clap → Arm Extend → throw.
- **Cleanup:** every effect cleaned up; no console errors.

## 2026-10-14 — Alchemy cast flow, Fire VFX, slot bar, combat fluidity

**Built:**
- **Alchemy cast flow:** clap (holdable) → ground slam → the move.
  - Uses the owner's group animations: Clap, Clap loop, Ground Slam, Arm Extend, Fire 1–5.
  - The prelude is part of the attack's startup, so stuns cancel it.
- **Custom transmutation circle:** a new texture, uploaded as `rbxassetid://132299053523633`.
  - Unfolds and spins in front of the hands on the clap; bursts on the slam.
- **Ignite rebuilt on the owner's FireElement VFX** (copied from the Assets place): hand fire, fireball, impact burst, burn.
- **Alchemy slot bar** (Z/X/C/V) like Devil Hunter's, shown once a player has an alchemy path.
- **Combat fluidity matched to Devil Hunter's code:**
  - light hitstun 0.45 → 0.6s; combo reset 1 → 2s;
  - walk speed swinging 6 → 14, heavy 4 → 11, blocking 5 → 12, stunned 0 → 4;
  - holding F re-raises the guard.
- **Shift-lock dash fix:** dashing sideways while sprinting in shift lock used to forward-roll. Dashes are now camera-relative and keep facing the camera.

**Tested:**
- Tap cast and held-clap cast (timelines logged).
- A stun during the held clap cancels cleanly.
- All 8 dash directions while walking and sprinting.
- Guard break with F held: the guard returns 0.2s after the stun ends.
- Slot bar visible, with cooldown and dimming.
- No console errors.

## 2026-10-14 — Alchemy vertical slice (master plan Phase 2)

**Built:**
- `AlchemyService`, Requests.Alchemy, Z/X/C input, V Ultimate fallback after Carry.
- Flame Z Ignite: server-swept projectile, burn, telegraph, banner feedback.

**Tested:**
- Normal cast; no meter; cooldown; Combat Mode off; malformed input; 5 casts in one frame (one charge).
- Interrupted cast; block from the front and the back; wall impact; range fizzle; no leftover effects.

## 2026-10-14 — Weapon position audit

**Built:**
- Grip re-solves; hold poses; greatsword shoulder carry and heavy feel.
- Hand-built holsters; HolsterWeld plus a client-side swap blend (no more snapping).

**Fixed:**
- Weak-table Instance keys lost tool joints (and could freeze hitstop or lose carry welds). Replaced across 6 modules.

**Also:**
- Group animations wired: Uppercut, Greatsword Run, Gun Idle.

## 2026-10-14 — Bug/feel pass

- Devil Hunter parry, M1 click buffer, hitstop overlap fix, holdable-skill state fix.
- Crit telegraph, wall-run chaining, directional climb, live stats polychart, UI readability pass.

## 2026-10-13 — Combat commission phases A1–A6

- Combat core, Devil Hunter feel pass, six weapons, PvE (Dummy/Grunt/Elite), downed actions, parkour, and the full UI rebuild from the PSDs.
- Master plan Phase 1: data contracts, ProfileData schema v1, ProgressionService, exploit fixes.

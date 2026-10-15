# Rensei Changelog

What each phase built and how it was tested. Newest first. All work is in the Studio place **Ye**. Backups of every touched script are in `ServerStorage.RenseiBackups`.

## 2026-10-14 — Weapons + inventory pass (A14)

**Changed (owner requests):**
- **Weapons come off the hotbar.** Click a weapon in the inventory to equip it, click again to unequip.
  - The choice is saved (`EquippedWeapon`) and given back on every spawn.
  - A save with a weapon on the hotbar is migrated: it's taken off and becomes the equipped weapon.
  - The equipped weapon shows a gold "E" and highlight; the tooltip says what a click will do.
- **Heavies inside the M1 string.** R during a swing queues the heavy; it comes out as soon as that swing ends, with no cancel. It also works while LMB is held. R no longer feints (RMB does).
- **Full M1 string on whiffs.** Holding or clicking into the air plays Light 1–4 instead of repeating Light 1.

**Fixed:**
- **"Character moves weird after unsheathing":**
  - The Katana/Rapier draw animation keyed both legs at Action2, so the legs froze and slid for about a second on every draw or sheathe. The leg keys were removed; the walk cycle keeps playing under the draw.
  - After a respawn, no animations loaded at all (the client read `Humanoid` before it existed), so everything moved wrongly until rejoining. It now waits for the Humanoid and Animator.
  - The climb error from the report (`ClimbAction` concatenating nil when Space was pressed during a ledge pull-up) no longer happens.
- **Weapons not lined up:** the sheathed Katana/Rapier hung straight through the right arm, and the Daggers were loose (one outside the left arm, one sticking out sideways). Holsters are now left hip (katana / rapier), crossed on the lower back (daggers), back (greatsword, unchanged) and right thigh (pistols, unchanged). The drawn grips were already in the fist.
- Inventory tooltip went stale after a click; the hotbar highlight and gun tracers could pick the weapon Tool instead of the held item.
- The old unused `HotbarUI` module was removed (copy in backups).

**Tested (Studio Play):**
- Equip, swap and unequip across Katana, Greatsword and Revolver; Apple onto the hotbar.
- A weapon forced onto the hotbar can't be held.
- The Apple is held beside the holstered weapon and put away when Combat Mode turns on.
- The weapon comes back after a respawn, and the migration moved the Katana off hotbar slot 1.
- Real clicks: inventory equip, the Potions tab, search ("app" / no match / cleared).
- Held M1 played the whole string into the air: Sword and Greatsword Light 1–4, then looped.
- M1 + R played Light 1, Light 2, then the Heavy straight away, then Light 3, Light 4. This worked both while holding LMB and while clicking, armed and unarmed.
- Walking while drawing kept the walk cycle on the legs.
- Respawn: animations loaded and the console stayed clean.
- Screenshots of every holster and of the drawn grips.

**Not done:** consumables have no use effect (the Apple can be held but not eaten; no design yet).

## 2026-10-14 — Mobile controls (A12)

**Built:**
- A touch control cluster in Rensei's slot-plate art.
- `ClientActions`: the keyboard and the touch buttons now run the same functions. ClientHandler was refactored onto it with no behaviour change.
- Touch-aware climbing and wall running in JumpManager: the thumbstick acts as WASD, and holding Jump acts as holding Space.

**Tested (Studio Play, ForceMobileControls):**
- Geometry: 16 buttons, no overlaps, none under the leaderboard, none off-screen, the thumbstick half kept clear.
- Fight turned on Combat Mode.
- Attack → Light1; Heavy → heavy; Block → parry window.
- Dash reached 98 studs/s; Jump peaked 7 studs up.
- Holding Z held the clap (2.35s cast vs 1.0s for a tap) and cost 25 meter.
- Turning it off restored the desktop alchemy bar and the Server panel.
- **Keyboard regression after the refactor:** E, F, R, M1 and Z all still work.
- Console clean.

## 2026-10-14 — Wind and Metal kits (all four designed kits complete)

**Built:**
- **Wind:** Air Slash, Gale Burst, Rising Wind, Tempest Break.
- **Metal:** Steel Guard, Crushing Anvil, Metal Bind, Alloy Divider.
- New `ShieldManager` and true damage.
- `WindElement` / `MetalElement` VFX, plus three uploaded wind textures.
- Placeholder animations.

**Tested (Studio Play):**
- **Air Slash:** 50, windup 0.92s.
- **Gale Burst:** 25 / 25 / 35 with stuns, push 24 studs; a blocking dummy took chip only.
- **Rising Wind:** 70; target and caster launched 11 studs.
- **Tempest Break:** 60 / 60 / 115 (= 235) to every dummy, through block and parry; lifted, then thrown up to 18–26 studs.
- **Steel Guard:** 4 frontal hits absorbed, the 5th broke it and ended the stance; a hit from behind landed; Coldsteel Smash shattered it and landed 110.
- **Crushing Anvil:** homed onto an off-axis target: 100.
- **Metal Bind:** 75, pinned 0.98s (walk speed 0, stunned), then released.
- **Alloy Divider:** 300 through a 20% resist buff; windup 2.42s (clap + slam + 1.2 cast + 0.4 delay).

**Fixed while testing:**
- Tempest Break's last hit missed lifted targets (sphere check); it now uses a column.
- Crushing Anvil turned too slowly to reach close targets (220°/s → 540°/s, plus a passed-by check).

## 2026-10-14 — Ice kit; climbing and combat bug pass; full audit

**Ice kit (A9):**
- Cryo Shift (counter), Coldsteel Smash (ice greataxe), Ice Shards (trap), Absolute Zero (area freeze).
- New `CounterManager`, damage-resist window, `IceElement` VFX, six Ice effects.
- Placeholder animations.

**Tested (Studio Play):**
- **Cryo Shift:** countered a light hit (no damage taken); the attacker took 40 and was frozen 1.55s; the next hit did 13.6 instead of 17 (20% resist).
- **Coldsteel Smash:** 110, then frozen 0.66s; windup 1.54s; full 0.5s recovery.
- **Ice Shards:** the trap sprang when the Dummy stepped in: 30 and frozen 1.57s.
- **Absolute Zero:** 200 to all four training dummies, straight through block, parry and perfect-parry; frozen 3.03s.

**Fixes found while testing:**
- Scorching Wave and Inferno Lance never applied their burn (it was configured but unused). Both now burn (2×5 verified).
- Inferno Lance missed targets more than ~8 studs away because the server sees the client's dash late. The hitbox now sweeps the whole dash; verified from 11 studs: 85 + burn.

**Climbing (owner report: "super bugged"):**
- Grab reach 3 → 5.
- Mantle onto the top instead of a launch; verified: you stand on top at the right height.
- New ledge pull-up; verified on an 11.5-stud block.
- Cleaned climb poses (they used to twist the body away from the wall).
- No fall animation under the hang; no stuck hang pose.
- Black arm cloud and duplicate attachments removed.

**Combat:**
- Enemies no longer hurt each other.
- Enemies spread out instead of stacking; first version froze them in place, fixed and re-tested: all three attack.
- Elite parries restored (verified).
- Feint queue for network ordering.
- Verified: 4-hit M1 combo, held M1 chain, heavy, feint, block chip (2.7–4.0), dash in all four directions.

**Audit:** see `Audit 2026-10-14.md`. 248 scripts syntax-checked (no errors); 13 debug prints removed; an unused PlayerModule copy moved out of StarterCharacterScripts. The console is clean in Play.

## 2026-10-14 — Status effects; parry while getting hit

**Built:**
- **Status effects** (`StatusManager` + `Effects.Status.StatusVFX`), using the owner's Status Effects VFX (Fire, Freeze, Bleed, Shock), copied from the Assets place.
  - Burn: damage ticks. Freeze: stunned, rooted, pose locked, ice glaze. Bleed: damage ticks. Shock: damage ticks plus jolt stuns.
  - Refresh instead of stacking; ended by death or knock.
  - Alchemy burns and the daggers' bleed now go through it. The old Burning effect is retired.
- **Parry while getting hit (owner request):** a fresh F press in hitstun opens the parry window for 10 posture (PROPOSAL) and always starts the 1.3s cooldown (PROPOSAL). Holding F raises the guard when the stun ends.
  - Only a real key press parries now; the hold-to-re-guard retry never opens a window.

**Tested (Studio Play):**
- **Burn:** 5 damage every 1.0s, 4 ticks.
- **Freeze:** walk speed 0, stunned, restored afterwards (Grunt 14, player 12). A hit while frozen didn't free the player.
- **Shock:** 3 jolt stuns plus ticks in 1.5s.
- **Bleed:** daggers hit → 3 ticks of 2 at 0.5s intervals.
- **Visuals:** welded on every client, then cleaned up (screenshot checked).
- **Hit-parry (real F presses during a hit stun):**
  - Window opened mid-stun; posture 100 → 90; the next hit was **PerfectParried** and the attacker stunned.
  - The cooldown stayed after the landed parry.
  - A second press on cooldown did nothing and cost nothing.
  - With F held, the guard came up 0.12s after the stun ended.
  - Guard-broken: no window.
- No console errors.

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

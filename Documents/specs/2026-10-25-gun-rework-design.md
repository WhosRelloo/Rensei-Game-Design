# Gun Class Rework: Audit and Design (PROPOSAL)

> **Owner update (2026-10-25):** the gun reload animation id is **97563934064498**, supplied by the owner.
> - The `Guns_Reload` slot is created with this id.
> - The plan's Task 1 checks it read-only (it loads, its length, and that it plays in this experience). Task 3 sets `AnimLength` to the measured length.
> - Only if Task 1 finds it unloadable is the slot left with an empty id (no animation, no warning).

> **Pre-flight amendment (2026-10-25, controller Rulings 1–2):** gun code that reaches the shared packages waits for the owner (plan header, "When to start"). The fire-request limits, the water rule, the AimFresh margin and the hold-to-fire cap below were changed by the pre-flight scan.

**Date:** 2026-10-25. **Status:** draft for the owner. Every number and rule here is a **PROPOSAL** unless it quotes an owner decision. Written overnight under the owner's go-ahead (Backlog, 2026-10-25); nothing is built or published.

**The owner's request** (Backlog, "After the Foundry Yard plan"): "Fix gun shoot mode aiming mechanics. (balance out the gun class completely, add a reload animation as well)".

**Owner decisions this keeps (not reopened):**
- "Guns: no reload button, automatic only" (`Decisions.md`).
- "M1 with a gun is a melee pistol whip and never fires a bullet; shooting is its own mode (Aim, Y)" (owner, 2026-10-17, non-negotiable).
- Y toggles shooting mode (rebindable "Aim (Guns)"); RMB fires while it's on.
- UI uses only the game's existing UI assets.
- Nothing is published by this work.

**The plan that builds this:** `Documents/plans/2026-10-25-gun-rework.md`.

---

## 1. How guns work today

The audit read the repo copies on 2026-10-25. `Scripts/README.md` says Studio is the source of truth, so the plan's Task 1 first confirms that every copy equals Studio.

**The flow of one shot:**
1. **Y** sends `Shoot("Mode", true)`. The server sets the character attribute `ShootingMode` (`Requests/Shoot.lua:63-67`). HUDUI shows a "+" label at the HUD's centre and a hint (`HUDUI.lua:199-231`).
2. **RMB** runs `FireInput` (`ClientHandler.client.lua:233-242`). It turns the root flat toward the camera's look, then sends `Shoot("Fire", Camera.CFrame.LookVector)`.
3. The server checks the mode, the gun, Combat Mode, that you're free to act, and that a round is loaded (`Shoot.lua:69-77`). It stores the direction with `WeaponManager.SetAim` and runs the shot through `AttackRunner` (Startup 0.12, Active 0.02, Recovery = the gun's).
4. At the strike, `WeaponManager.Fire` (`WeaponManager.lua:368-410`) spends a round. It casts a ray from `Root.Position + (0, 1.5, 0)` (head height) along the stored direction, up to `Def.Range` (90), against the **current** server positions. The first `Humanoid` in `World.Live` that the ray hits goes to `DamageManager`. An empty magazine starts the automatic reload (`WeaponManager.lua:312-327`).
5. **Fan the Hammer** (T) is three of the same shots, aimed by `SendAim()` (`ClientHandler.client.lua:84-88`). That sends the camera's look as an `"Aim"` request. The handler for that request isn't in the repo (see §9).

## 2. What's wrong with the aiming

Each finding names the code that shows it.

**A1. The shot doesn't go where the crosshair is (parallax).**
- The client sends only a direction: the camera's look (`ClientHandler.client.lua:237, 240`).
- The server fires that direction from the character's head (`WeaponManager.lua:379`), not from the camera.
- Two parallel lines that start in different places never meet. The shot lands off the crosshair by exactly the camera's offset from the head:
  - **Shift lock (Alt):** `Humanoid.CameraOffset = (0, 1.5, 0.5)` (`SettingsUI.lua:109`), so every shot lands **1.5 studs below** the crosshair at every range. Aim at a head and you hit the torso; aim at the torso and you hit the legs; aim at the legs and you hit the ground.
  - **Lock-on (G):** the lock camera sits over the right shoulder and above the player. The alchemy hotfix says so (`ClientHandler.client.lua:179-181`) and fixed it for alchemy only (`AlchemyAim`, lines 183-193). `FireInput` never reads `LockOn.Target`, so shots run **beside and below** the locked target. This is the bug alchemy had before 2026-10-23.

**A2. With shift lock off (the default), you aim with one thing and shoot with another.**
- `Settings.Defaults.ShiftLock = false` (`Settings.lua:7`), so by default the mouse is free and the system cursor shows.
- Players point the cursor at an enemy and click RMB. The shot ignores the cursor and goes to the screen's centre (the camera's look).
- In Roblox's default camera, holding RMB also turns the camera, so the press that fires can swing the view. A Studio check confirms whether the ContextActionService sink stops this (§9).
- Shooting mode changes nothing about the camera or the mouse.

**A3. The crosshair isn't tied to the shot.**
- The "+" is a TextLabel placed at (0.5, 0.5) of the HUD ScreenGui (`HUDUI.lua:210-221`). The shot uses the viewport's centre.
- If the HUD's ScreenGui doesn't ignore the top-bar inset, the "+" sits about 18 px below the true centre. Studio confirms which.
- The game already has its own marker, `Gui.Crosshair`, used by shift lock (`SettingsUI.lua:91, 108`). Shooting mode draws a second, different crosshair instead.

**A4. Turning to shoot behind you fires straight ahead.**
- The server accepts an aim only within 100° of the root's **server-side** facing, and only if it's less than 2 s old. Otherwise it fires along the root's look (`WeaponManager.lua:293-305`).
- The client turns the root and fires in the same frame (`ClientHandler.client.lua:238-240`). The new facing replicates on a different channel from the remote, so the server often still sees the old facing.
- **Result:** a quick turn-and-shoot goes out the old way and still spends the round.

**A5. Moving targets are missed that looked hit.**
- The server ray tests where targets are **now** (`WeaponManager.lua:384`).
- The shooter saw them about one ping plus Roblox's interpolation delay ago, so a strafing target (16 studs/s) has moved 2–4 studs, wider than a torso.
- There's no lag compensation and no aim snap. Alchemy has a 4-stud snap (`AlchemyService.lua:114-133`).

**A6. Clicks get eaten.**
- RMB fires once per press (`ClientHandler.client.lua:264, 287`).
- A press while the previous shot is still running is refused (`Shoot.lua:73`, `AttackRunner.IsRunning`), with no buffer and no hold-to-fire. Clicking a little early does nothing.

**A7. Enemy gunners shoot flat.**
- NPC shots never call `SetAim` (`EnemyService.lua:263-264`). They fire along the root's flat look from head height.
- So they miss targets above or below them, and hit with a perfect, 0.12 s hitscan otherwise.

**A8. Touch screens.**
- AIM and FIRE exist (`MobileControls.lua:56-57`), and FIRE fires once per tap along the camera's centre.
- There's no lock-on button on touch (none in `MobileControls.Layout`), so touch players can't use lock-on to aim.
- `Controls.md`'s touch table doesn't list AIM or FIRE.

## 3. Other bugs found

**B1. Fan the Hammer scales against the pistol whip.**
- `Resolve` scales a skill's damage by `Stats.Damage / Light.Hits[1].Damage` (`WeaponManager.lua:66-70`).
- Since 2026-10-17, `Light` is the pistol whip (11), so each Fan shot deals the gun's full shot damage:
  - Forge Tac: 3 × 24 = **72**, or 86 at Point Blank;
  - Revolver: 60.
- Other weapon skills deal 30–44 at melee range (TuningConfig lines 420, 440, 460, 488, 506). Fan reaches 70 studs.
- The base was the old shot damage (15) before the whip took `Light`'s place.

**B2. Weapon Mastery makes long shots weaker.**
- `DamageMult` returns `1 + (M − 1) × Mastery` (`WeaponManager.lua:420-423`). For guns, M is the falloff, below 1.
- At max Weapon Mastery (×1.75), a 90-stud shot deals 12.5% instead of 50%. The skill tree's "passives 25% stronger" punishes gunners.

**B3. A missed shot costs extra recovery.**
- Shots don't set `NoWhiffPenalty`, so a miss adds `Light.WhiffRecovery` 0.15 s (`AttackRunner.lua:292`). A missed bullet already costs the round.

**B4. Shots build alchemy meter as fast as melee, from safety.** Every shot hit gives `Meter.OnLightHit` 4 (`SkillData.lua:58-60`). A Renetti fires 2.9 hits/s, so it earns 11.8 meter/s at 60 studs, against 8.6/s for a fist string up close.

**B5. Every shot interrupts, at any range.**
- Shots stun 0.12 s (`TuningConfig.lua:535-538`), and a stun cancels an attack in its windup (`AttackRunner.lua` header).
- A Renetti fires every 0.34 s, so from 90 studs it can keep cancelling a target's windups.

**B6. Forge Tac beats the Revolver at everything.**
- Forge Tac: 24 damage, 7 rounds.
- Revolver: 20 damage, 6 rounds.
- Both have the same reload and range, and Forge Tac has higher burst and sustained damage (§4). There's no reason to pick the Revolver.

**B7. Shooting mode survives water** (pre-flight scan). `Shoot.lua:43` ends the mode on Combat Mode, weapon, knock, grip and carry changes, but not on `Traversal`, so a swimmer keeps shooting mode.

## 4. The balance audit

Numbers come from `TuningConfig` (2026-10-25).
- **Fire interval** = Startup 0.12 + Active 0.02 + the gun's Recovery.
- **Burst** = damage ÷ interval.
- **Sustained** = a full magazine plus its reload.
- Before falloff and Point Blank.

**Melee string damage per second** (four lights, back to back):

| Class | DPS | Range |
|---|---|---|
| Fists | 40.1 | 3.5 |
| Sword (Katana) | 42.2 | 4 |
| Rapier | 33.0 | 5 |
| Gauntlets (Caestus) | 42.0 | 3.5 |
| Greatsword | 44.6 | 5 |
| Daggers | 31.3 (+ bleed ≈ 4) | 3.5 |
| **Average** | **38.9** | |
| Gun pistol whip | 24.6 | 3 |

**Guns today:**

| Gun | Damage | Mag | Reload | Recovery | Interval | Burst | Sustained | Range |
|---|---|---|---|---|---|---|---|---|
| Revolver | 20 | 6 | 2.0 | 0.36 | 0.50 | 40.0 | 24.0 | 90 |
| Renetti | 10 | 12 | 1.6 | 0.20 | 0.34 | 29.4 | 21.1 | 90 |
| Forge Tac | 24 | 7 | 2.0 | 0.45 | 0.59 | 40.7 | 27.4 | 90 |
| Sykov | 13 | 10 | 1.7 | 0.24 | 0.38 | 34.2 | 23.6 | 90 |

**Alchemy for scale:** Ignite (Flame Z) is a 60-damage fireball plus 20 burn, every 8 s, for 25 meter. Alchemy is the "utility, not the main damage source" (`ALCHEMY_SYSTEM.md`).

**Where guns are over-tuned:**
- the Revolver's and Forge Tac's burst (40+) equals melee strings, from range;
- Fan the Hammer (B1);
- meter gain (B4);
- flinch at any range (B5);
- perfect accuracy (no spread on any shot).

Once the aiming is fixed, guns hit far more often, so all of these grow.

**Where guns are under-tuned:**
- the aiming bugs (§2);
- eaten clicks (A6);
- the whiff penalty (B3);
- Mastery's falloff penalty (B2);
- no gun has a range identity.

**Stamina and posture are left as they are:**
- shots cost no stamina, like melee lights;
- a blocked shot costs the blocker 3 posture and 20% chip. A gunner can't guard-break from range; the whip's heavy (30 posture) is how a gunner breaks a guard. That's the counterplay, and it's kept.

## 5. The design

### 5.1 The aiming fix

**One rule:** the shot goes to whatever is under the crosshair, and the crosshair is the game's own marker.

**1. Aim camera (PROPOSAL).** While shooting mode is on and you aren't locked on:
- the mouse locks to the centre and the cursor hides;
- the camera moves over the right shoulder (`Humanoid.CameraOffset` = (1.75, 0.5, 0));
- the character turns with the camera (`RotationType = CameraRelative`).

When you leave shooting mode, everything goes back to your shift-lock setting. Shift lock's own loop pauses while shooting mode owns the camera, so the two never fight.

**2. The crosshair is `Gui.Crosshair`,** the existing Rensei marker. It replaces the generated "+". The hint text stays.

**3. The aim point.**
- The client casts the camera's ray through the crosshair's **actual** screen centre (its `AbsolutePosition`, with the top-bar inset counted the way its ScreenGui does). The first thing past the shooter that the ray meets is the aim point.
- The shot's direction is then **from the muzzle to that point**, where the muzzle is the head: root + (0, 1.5, 0), the same point the server fires from.
- So the bullet meets the crosshair at the aim distance, whatever the camera's offset.
- A wall closer than 2 studs falls back to the camera's direction.

**4. Lock-on.** While locked on, the shot aims from the muzzle at the target's centre, as alchemy does. The crosshair moves onto the target, so it still shows where the bullet goes.

**5. Line of fire.** If the line from your head to the aim point is blocked (shooting past a corner your eye can't see round), the crosshair dims.

**6. The server checks every direction** (`GunAim.Validate`):
- it's a finite vector of about unit length;
- at most 70° up or down;
- at most 100° from your facing.

An aim that fails is **refused**: no shot, no round, no animation. The old fallback that fired straight ahead is removed. The direction comes with the Fire request; the stored aim used by Fan the Hammer is good for 0.75 s (was 2 s): Fan's last shot lands 0.42 s after the request, so 0.75 leaves a third of a second to spare.

**7. Lag compensation** (PROPOSAL, shooter-favoured, bounded):
- The server keeps half a second of every live character's root position.
- A player's shot is tested against characters' boxes **where they stood (one-way ping + 0.1 s) ago, capped at 0.25 s**.
- The box is 4 × 5.2 × 2 studs around the root, lowered 0.4. Task 1 measures an R6 rig to confirm.
- Walls are tested where they are now: the shot stops at the first wall.
- NPC shooters aren't rewound.

**8. Hold to fire.**
- Holding RMB (or FIRE on touch) keeps firing at the gun's own rate.
- A press up to 0.2 s before the gun is ready still fires (an input buffer).
- The server still sets the rate.
- **The hold loop sends at most one Fire request every 0.25 s (4 a second, PROPOSAL),** even while the server refuses shots. Every request shares ServerHandler's limit of 8 a second (burst 16), so a faster loop could starve the Y mode request.

### 5.2 Balance targets

**Targets:**
- **Burst ≤ 37 DPS:** under every melee string except Rapier and Daggers (whose reach is the shortest). Range is the gun's advantage.
- **Sustained 20–26 DPS:** 55–65% of the melee average.

Each gun gets a range identity, so none is strictly better than another.

| What | Old | New | Why |
|---|---|---|---|
| **Revolver** Recovery / Reload / Range (falloff) | 0.36 / 2.0 / 90 (25→90) | **0.42 / 1.8 / 70 (20→70)** | The hand cannon: hits hard up close and reloads quickly. Burst 40.0 → **35.7**, sustained 24.0 → **23.3**. |
| **Renetti** Range (falloff) | 90 (25→90) | **60 (15→60)** | The close-range spray. Its damage numbers are already in the band (burst 29.4, sustained 21.1). |
| **Forge Tac** Damage / Mag / Reload / Recovery / Range (falloff) | 24 / 7 / 2.0 / 0.45 / 90 (25→90) | **26 / 5 / 1.8 / 0.62 / 110 (40→110)** | The marksman: the hardest single shot, the slowest rate and the longest range. Burst 40.7 → **34.2**, sustained 27.4 → **23.2**. The Revolver now has the higher burst up close. |
| **Sykov** | 13 / 10 / 1.7 / 0.24 / 90 | **unchanged** | The all-rounder. Burst 34.2, sustained 23.6 are in the band. |
| Falloff floor (Min) | 0.5 | 0.5 | Kept: range buys safety, not damage. |
| **Point Blank** | +20% within 12 | kept | It's the class passive. |
| **Weapon Mastery on falloff** | made falloff worse (B2) | **bonuses only** | Mastery strengthens a passive's bonus and never deepens a penalty. |
| **Flinch** (shot stun 0.12 s) | at any range | **within 25 studs only** | A shot past 25 studs deals damage but can't cancel a windup (B5). Up close, the flinch stays. |
| **Meter per shot hit** | 4 | **2** (`Meter.OnShotHit`) | Shooting from safety shouldn't fill the meter faster than melee (B4). |
| **Whiff recovery on a missed shot** | +0.15 s | **none** (`NoWhiffPenalty`) | A miss already costs the round (B3). |
| **Fan the Hammer** damage per shot / range / spread | the gun's damage (10–24), 70, 1.5° | **12 for every gun, 40, 3°** | 36 total, in line with the other weapon skills (30–44), at close range where fanning belongs (B1). Stamina 15 and cooldown 6 are kept. |
| **Enemy gunner shot** windup / spread / aim | 0.12 s / 0° / flat | **0.35 s with the crit telegraph / 2.5° / at your centre** | PvE fairness (§5.5). |
| **Recoil kick** (camera, degrees) | none | Revolver 1.5, Renetti 0.5, Forge Tac 2.0, Sykov 0.8 | Feel. It recovers in 0.18 s, so it never moves your aim for good. |

The sustained figures are approximate: the reload starts at the last shot's strike, a moment before its recovery ends.

### 5.3 Ammo and reload

**Magazines and reloads (PROPOSAL):**

| Gun | Magazine | Reload |
|---|---|---|
| Revolver | 6 | 1.8 s |
| Renetti | 12 | 1.6 s |
| Forge Tac | 5 | 1.8 s |
| Sykov | 10 | 1.7 s |

Marksman still cuts reloads by 10% per rank. Magazines are still remembered while holstered, and there's still no reserve ammo.

**When a reload happens.** It stays automatic, with no reload button (owner decision):
- **an empty magazine** reloads by itself, as today;
- **a top-up (PROPOSAL):** leaving shooting mode with a part-empty magazine (by Y, by leaving Combat Mode, or when the mode ends by itself) starts the same automatic reload. Nobody gets stuck on 1 of 6.

**The reload animation slot:**
- **The owner supplied the reload animation:** id **97563934064498** (2026-10-25). No reload animation was in the game before.
- **The slot:** an `Animation` named **`Guns_Reload`** goes in `ReplicatedStorage.Assets.Animations.Weapons`, in both places, with `AnimationId = "rbxassetid://97563934064498"`. `TuningConfig.Weapons.Guns.Reload` names it, and `Reload.AnimLength` is the length the plan's Task 1 measures.
- **The safe fallback:** only if Task 1 finds the id unloadable is the slot made with an empty id. Then the server plays nothing, logs no warning, and the reload works exactly as now, with the reload bar in CooldownUI.
- **With the id set:**
  - it plays at Action priority;
  - its speed fits the reload (`AnimLength / ReloadTime`);
  - it's preloaded with the other weapon animations.
- **No asset id is invented anywhere.**

**The interrupt rule (PROPOSAL):**
- **Things done to you** cancel a reload: being stunned (any hit that stuns, a guard break, a parry stagger), knocked, gripped, carried, or entering water.
- The reload bar and the animation stop. As soon as you're free again, the reload **starts over** by itself.
- **Your own actions don't cancel it.** The pistol whip, the heavy, a dash or blocking play over it while the timer keeps running.
- **Why:** a gunner caught reloading can be punished by being hit, and weaving the whip while you reload stays the class's skill.
- Swapping or unequipping the gun cancels the reload, as today.
- **Water:** shooting mode ends when you start swimming (the server watches `Traversal`), so you can't shoot from water.
- Fan the Hammer with fewer than 3 rounds fires what's left, then reloads.

### 5.4 Feedback (existing UI assets only)

- **Crosshair:** the existing `Gui.Crosshair` marker. In shooting mode it sits where the shot goes: the screen's centre, or on the lock-on target. It dims when the line of fire is blocked.
- **Hit marker:**
  - the server sets `LastShotResult` ("Hit", "Blocked" or "Miss") and `LastShotAt` on the shooter after every shot. These are character attributes, so no new remote is needed;
  - **Hit:** the crosshair flashes warm red and pulses 1.35× → 1 over 0.15 s;
  - **Blocked** (blocked, shielded or countered): it flashes grey;
  - **Miss:** nothing.
- **Recoil:**
  - a camera kick by the gun's `Kick`, recovering over 0.18 s;
  - a crosshair bloom of 1.25× for 0.1 s;
  - the kick is predicted on the client when the client fires;
  - with Settings > Camera Shake off, only the bloom shows.
- **Already there and kept:** the tracer, the muzzle flash (`Assets.VFX.Guns.Muzzle`), the gunshot noise (NoiseService), the ammo count and the reload bar (CooldownUI).

No new images, fonts or sounds are added.

### 5.5 PvE against PvP, and anti-exploit

**PvE (enemy gunners):**
- **Windup:** 0.35 s, with the existing crit telegraph flash, so a player can see the shot coming and block or dash. It was 0.12 s with no tell.
- **Spread:** 2.5°, about 0.8 studs at their 18-stud stand-off, so they sometimes miss.
- **Aim:** at your centre, so height no longer breaks them.
- **Fire rate and damage:** they keep their per-gun numbers.
- **No rewind:** they're on the server, so they see the truth.

**PvP:**
- The same numbers for everyone.
- The lag compensation is shooter-favoured but capped at 0.25 s. A target can be hit up to a quarter-second after ducking behind cover. That's the usual trade, and the cap keeps it small.
- There are no headshot multipliers (PROPOSAL), so precise aim pays in hits, not spikes, and an aim-bot gains less.
- Shots stay BLOCKABLE: a block chips 20%, a parry window counts as a block, and dodge i-frames avoid them.
- **Townsfolk:** shots hit them as any attack does (the existing assault and murder deeds). Aim assist never bends onto them.

**Anti-exploit.** The server owns every number that matters:
- **State:** the mode, the gun, ammo, the reload and the fire rate.
- **Never trusted from the client:** a hit, a position or a time. The client sends only a direction.
- **Checks on each shot:**
  - the direction is validated (§5.1);
  - the range comes from the server's tuning;
  - the line of fire is cast from the server's own muzzle;
  - the rewind uses the server's own ping reading, capped.
- **Request rate:** at most 5 Fire requests per second per player (a pure `GunAim.Limiter`, checked first); the rest are dropped. That's above the fastest gun (Renetti, 2.9 a second) and the client's hold cap (4), and under ServerHandler's shared 8 a second.
- **Snap log (PROPOSAL):** two shots within 0.1 s whose directions differ by more than 120° are counted in a server attribute `GunSnapCount`, for admins to see. Nothing is punished automatically.

### 5.6 Touch screens

- **AIM (Slide's spot) toggles shooting mode** as today. FIRE shows while shooting, and **holding FIRE keeps firing** (MobileControls already sends the release).
- **Aiming:** drag the screen to turn the camera. The crosshair is the screen's centre; the camera stays over the shoulder and the character turns with it.
- **Aim assist (PROPOSAL, touch only):**
  - a shot whose crosshair ray passes within **2.5°** of a visible enemy's or player's centre, in range, goes to that centre;
  - townsfolk are never assisted;
  - setting `Aim.TouchAssist = 0` turns it off.
- The hint reads "SHOOTING MODE · hold FIRE to shoot · STOP to leave".
- `Controls.md` gains the AIM and FIRE rows.
- **A touch lock-on button** is out of scope; it's listed as a follow-up.

## 6. What changes, by file

| File | Change |
|---|---|
| `Modules/Data/Rensei/GunAim.lua` (new) | The pure maths: muzzle, aim point, direction, validate, ray-box, rewind, range multiplier, Mastery rule, flinch range, assist, spread, fire interval, DPS |
| `Modules/Data/Rensei/TuningConfig.lua` | `Guns.Items` (per-gun Range, Falloff, Kick), `Guns.Aim`, `Guns.Reload`, `Guns.NpcShot`, Fan the Hammer, `Shots.NoWhiffPenalty`, `Meter.OnShotHit` |
| `Modules/Managers/WeaponManager.lua` | `Resolve` (no skill scaling), `SetAim` / `AimDirection` (validate, refuse), `Fire` (per-gun range, the hit through boxes and rewind, flinch range, meter, `LastShotResult`), `DamageMult` (the Mastery rule), reload (the slot, the interrupt, the restart) |
| `ServerScriptService/PositionHistory.lua` (new) | Half a second of root positions for every live character |
| `ServerScriptService/ServerHandler.server.lua` | Starts PositionHistory |
| `ServerHandler/Requests/Shoot.lua` | The Fire limiter first, then the aim validated before anything runs; the snap log; shooting mode also ends in water (`Traversal`). The top-up lives in WeaponManager, so it reaches NPCs too |
| `ServerScriptService/EnemyService.lua` | NPC shots: aim at the centre, spread, windup, telegraph |
| `Modules/UI/GunAimUI.lua` (new) | The aim camera, the crosshair (existing marker), `AimDirection()`, recoil, bloom, the hit marker, touch assist |
| `StarterPlayerScripts/ClientHandler.client.lua` | `FireInput` (hold, buffer, the new direction), `SendAim`, the Fire release |
| `Modules/UI/SettingsUI.lua` | The shift-lock loop pauses during shooting mode |
| `Modules/UI/HUDUI.lua` | The generated "+" goes; the hint text stays (touch wording) |
| `Assets.Animations.Weapons.Guns_Reload` (Studio) | The reload slot with the owner's id (empty only if unloadable), in both places, via a reversible script |
| Tests | `Test_GunAim`, `Test_GunBalance`, `Play_Guns`, `Play_GunReload`, `Play_GunNpc` (RenseiTests) |

All `Modules/` paths are under `Scripts/ReplicatedStorage/`.

## 7. Tests

Every check is run once where it **must fail** (RED), then passes (GREEN). None reads the value it checks to choose its own input.

**`Test_GunAim`** (pure; run in the Play VM via `LMRunSuite`):
- **The Fire limiter:** 5 at once, then one per 0.2 s; keys are separate. RED: a stub that allows everything.
- **The parallax shot meets the crosshair.** A shoulder camera (offset (1.75, 1.5, 0), 12 studs back) aims at a 2-stud box (a head) 40 studs out: the new direction from the muzzle hits it. RED control: today's rule (the camera direction from the muzzle) misses it by about 1.35 studs sideways.
- **Lock-on aims at the centre.**
- **Validate:**
  - accepts a forward aim;
  - refuses NaN, zero, length 3, 80° up, and 150° behind.
- **The ray-box hit:**
  - a hit, a miss, and from inside the box;
  - rotated boxes;
  - the hit distance is correct to 1e-6.
- **Rewind:** interpolates between samples and clamps at both ends. `RewindTime` is capped at 0.25.
- **The range multiplier** at 5, 20, 45 and 80 studs against hand-worked numbers. Mastery never lowers a value below 1 further.
- **Flinch range:** 24.9 flinches, 25.1 doesn't.
- **Assist:** picks the nearest-angle centre under 2.5° and ignores one at 3°.
- **Spread:** with a seeded `Random`, 200 samples stay within the cone, and some exceed half of it.

**`Test_GunBalance`** (pure):
- every gun's burst ≤ 37 and sustained within 20–26;
- each identity holds:
  - Forge Tac has the longest range;
  - Renetti has the shortest interval;
  - the Revolver has the highest burst;
  - no gun is strictly better than another on damage, magazine, reload and range;
- Fan the Hammer's damage is the same for every gun (through `Resolve`, with a fake character);
- `Meter.OnShotHit` is 2.

RED: today's numbers fail the bands (Revolver and Forge Tac burst, Forge Tac sustained) and the Fan rule.

**`Play_Guns`** (Play, NPC shooter and dummy targets in `World.Live`):
- a shot at a dummy hits;
- an aim behind is refused with no round spent (RED: today it fires forward and spends one);
- per-gun range (a Renetti can't reach 65 studs; a Forge Tac can);
- falloff damage against hand-worked numbers;
- Mastery doesn't deepen falloff (RED today);
- flinch at 10 studs, none at 40 (RED today);
- a wall stops the shot;
- `LastShotResult`;
- **the rewind:** a dummy moved by the test at 16 studs/s is hit where it stood 0.2 s ago only with the rewind time. The same ray at the present time misses (that's the control).

**`Play_GunReload`:**
- an empty magazine reloads in the gun's time;
- a stun mid-reload cancels it, clears the bar, and restarts from zero once free;
- a whip or a dash mid-reload doesn't cancel it;
- leaving shooting mode tops up;
- with the id blanked in the Play copy, the server never asks to play `Guns_Reload`; with the owner's id, it does, and an NPC's Animator plays it. The two cases are each other's control.

**`Play_GunNpc`:**
- the NPC shot's windup is 0.35 s with the telegraph;
- it hits a target standing 4 studs higher (RED: today's flat aim misses);
- its spread stays within 2.5°.

**Client checks (Play, client data model):**
- the crosshair-ray centre equals the marker's centre within 1 px;
- `AimDirection()` hits a 1-stud marker placed under the crosshair with the shoulder camera (RED: the camera-look rule misses it);
- leaving the mode restores the mouse and camera to the shift-lock setting;
- holding fire for 10 s while the server refuses every shot sends at most 41 requests, and a Y press afterwards still gets through (RED: a 0.1 s loop starves the shared request limit).

**Regression:** Play_Stealth (`GunshotPullsTheCamp`), Play_Assault, Play_TownsfolkHurt, and the Foundry smoke and travel suites, in both places.

**Owner checks (by hand):**
- on a phone: AIM, hold FIRE, and the assist;
- two players: one shoots, the other strafes;
- the feel of each gun.

## 8. Decisions taken without the owner

Each is a PROPOSAL the owner can reverse. The plan builds them so they're easy to change (one number or one switch each).

1. **The aim camera:** shooting mode locks the mouse to the centre, moves the camera over the right shoulder, and turns the character with the camera. The alternative is to leave the camera alone and only fix the aim maths; free-mouse players would then still aim with the screen's centre, not the cursor.
2. **The crosshair is the existing `Gui.Crosshair` marker,** not the generated "+".
3. **Lag compensation:** shooter-favoured, capped at 0.25 s (one-way ping + 0.1 s).
4. **Hold to fire, and a 0.2 s input buffer.** The 2026-10-17 build fired once per press.
5. **Per-gun ranges:** Revolver 70, Renetti 60, Forge Tac 110, Sykov 90, each with its own falloff.
6. **The per-gun numbers** in §5.2, with the bands burst ≤ 37 and sustained 20–26.
7. **Shots flinch only within 25 studs.**
8. **Meter per shot hit is 2** (melee hits stay 4).
9. **No whiff penalty on shots.**
10. **Fan the Hammer:** 12 per shot for every gun, range 40, spread 3°.
11. **Weapon Mastery strengthens bonuses only.** This is a bug fix, but it changes numbers.
12. **The reload top-up:** leaving shooting mode with a part-empty magazine reloads automatically. There's still no reload button.
13. **The reload interrupt rule:** things done to you cancel it and it restarts once you're free; your own actions don't.
14. **The magazine and reload numbers** in §5.3.
15. **The reload slot holds the owner's id (97563934064498).** If it proves unloadable, the fallback is no animation and no stand-in pose.
22. **The hold-to-fire loop is capped at 4 requests a second,** and the server's Fire limiter at 5 a second.
23. **Fan the Hammer's stored aim lasts 0.75 s** (the scan found 0.5 left only 0.08 s spare).
16. **Enemy gunners:** a 0.35 s windup with the crit telegraph, 2.5° spread, aim at your centre.
17. **No headshot multiplier.**
18. **Touch aim assist** of 2.5°, touch only, never onto townsfolk.
19. **Recoil:** the per-gun kicks, and turning it off with Camera Shake.
20. **The snap log** counts suspicious turns and punishes nothing.
21. **The server refuses an invalid aim** instead of firing straight ahead.

## 9. Checks for the implementer (Studio, read-only; plan Task 1)

These need Studio. This audit didn't open it.
1. Do the repo copies equal Studio, by normalised hash? Check ClientHandler, WeaponManager, `Requests.Shoot`, HUDUI, SettingsUI, MobileControls, TuningConfig, EnemyService, ServerHandler, AttackRunner, DamageManager and AnimationManager.
2. **Studio-only scripts to export** (read-only) into the repo:
   - `Modules.UI.LockOn`;
   - CooldownUI (find its path);
   - `Managers.SkillMods`;
   - **the `"Aim"` request handler.** If none exists, `SendAim` is dropped and Fan the Hammer always fires straight ahead;
   - **`Requests.WeaponSkill`.** Does it call `WeaponManager.Resolve` for Fan? Does Fan need shooting mode?
3. **The lock-on camera:** where it puts the camera, and whether it sets `AutoRotate` false.
4. **`Gui.Crosshair`:** its class (ImageLabel or Frame), its ScreenGui's `IgnoreGuiInset`, and its anchor and position. Also the HUD ScreenGui's `IgnoreGuiInset`.
5. In Play with shift lock off and a gun in shooting mode, does holding RMB turn the camera?
6. **`World.Live`'s layout in Play:** which folders hold enemies, players and townsfolk.
7. Do the RenseiServer modules sit in `ServerScriptService` at run time? NoiseService is found there in `Shoot.lua:86`.
8. The extents of an R6 character around its root, for the hit box.
9. Where existing effects read Settings > Camera Shake on the client.
10. **`Assets.Animations.Weapons`:** its tree (is there a Guns folder?), and whether `Assets` is a package.
11. Does the Tutorial place carry the `Modules` package (or a copy)? If so, gun code reaches it when its package updates. Without `PositionHistory`, `WeaponManager.Fire` must fall back to current positions.
12. Does LockOn work on touch at all?
13. **The owner's reload id 97563934064498:** that it loads (KeyframeSequenceProvider, and an Animator load in Play), its length, and that the Rensei group (206818864) or the experience's owner owns it, so it can play live.
14. An open, flat 200 × 200 test spot in each place, for the gun suites.

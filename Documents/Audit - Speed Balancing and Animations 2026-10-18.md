# Audit: speed balancing and how it affects animations (2026-10-18)

**Owner (2026-10-18):** "audit speed balancing and how they affect animations".

> **Audit only: nothing was changed.**
> - Method: every walk-speed writer and animation-speed setting was read in the code.
> - Measured in Studio Play: the 86 attack animations were loaded on the real character to get their true lengths, and the live walk speed and `Animate` script were read on the client.
> - Proposed fixes are marked PROPOSAL and wait for the owner.

## 1. How movement speed works now

- **Base walk speed** is the custom StarterCharacter's `Humanoid.WalkSpeed`, which is **12**.
  - Every system that puts walking back reads it: Run, Crouch, Block, MoverManager, Swim, DownedManager, Auto Sprint, shift lock.
  - Each sets `12 × SpeedMultiplier`.
- **`SpeedMultiplier` is a character attribute**, equal to the Speed stat × the drawn weapon's weight:
  - **Speed stat:** +0.6 % per point above 1, capped at **+25 %** (Speed 43). It's applied to walking, running, sprinting and casting, never to attacks.
  - **Weapon weight:** only the Greatsword has one (`MoveSpeedMult = 0.85` while drawn).
  - **When it changes,** `ProgressionService` and `WeaponManager` rescale the *current* walk speed by the ratio, so a change mid-run keeps working.
- **Fixed speeds** (they don't use the multiplier):

  | State | Walk speed |
  |---|---|
  | Light attack | 14 (Greatsword 10) |
  | Heavy | 11 |
  | Blocking | 12 |
  | Casting | 6 (12 × mult with Steady Array) |
  | Carrying | 11 |
  | Hitstun | 4 |
  | Crouch | 6 |
  | Class skills | 3–12 each |
  | Enemies | 10–19 by type |

- **Run and sprint:** run is **24 × mult**, becoming a sprint at **30 × mult** after 2 s (× the Sprint Speed skill node). The swim sprint is base × 1.6.

## 2. Findings

### A. The base walk speed is 16 at spawn but 12 after your first action (bug)

- **Measured on the client:** a fresh character walks at **16**. After one run (Shift) it walks at **12**, and stays there.
- **Cause:**
  - The WCS framework's default props give the client humanoid **16** (`WCS.source.character`, `WalkSpeed = 16`).
  - Every Rensei system restores **12** (the StarterCharacter value).
  - The server copy stays at 12; the player's own client is what moves them.
- **The attack and block speeds were tuned against a ~15–16 base.** The comments in `TuningConfig` compare them with Devil Hunter's numbers:

  | Speed | Devil Hunter (of 15) | Rensei | % of a 16 base | % of a 12 base |
  |---|---|---|---|---|
  | Attack walk | 13 | 14 | 87 % | **117 %** |
  | Heavy walk | 10 | 11 | 69 % | 92 % |
  | Block walk | 12 | 12 | 75 % | **100 %** |

  So at the 12 base, **swinging makes you walk faster than walking**, and blocking doesn't slow you at all. At 16 the ratios match Devil Hunter.
- **PROPOSAL:** set `StarterCharacter.Humanoid.WalkSpeed = 16`. That one value fixes the spawn / after-action mismatch, because every writer reads it, and it restores the intended attack and block slow-downs. **It's a balance change** (walking becomes 16 everywhere), so it needs the owner's OK.
  - The alternative is to keep 12 and lower AttackWalkSpeed / Block / Heavy to about 10 / 9 / 8, and make WCS default to 12.

### B. The walk animation's speed follows walk speed: very slow at low speeds

- **The character is R6** and uses Roblox's default `Animate` (inserted at runtime, with the game's own walk animation). It plays the walk at **WalkSpeed ÷ 14.5**:

  | State | Walk speed | Walk playback |
  |---|---|---|
  | base (now) | 12 | 0.83× |
  | base (proposed) / spawn | 16 | 1.10× |
  | light attack | 14 | 0.97× |
  | heavy / carry | 11 | 0.76× |
  | Greatsword drawn | 10.2 | 0.70× |
  | casting / crouch | 6 | **0.41×** (slow-motion legs) |
  | hitstun | 4 | **0.28×** |
  | Speed stat maxed | 15 | 1.03× |

- **Under ~8 studs/s the legs visibly move in slow motion.** Casting is the most common case. Hitstun mostly hides it under the hit reaction.
- **PROPOSAL:** for states slower than ~8, either play a dedicated shuffle / cast-walk animation, or clamp the walk track to ≥ 0.6× and let the feet slide a little. A shuffle needs a new animation from the owner; none exists.

### C. Run and sprint animations don't follow the speed multiplier

- **Fixed rate:** the run plays at 1× at 24, and SpeedyRun at 1× at 30. With a drawn weapon there's no sprint animation, so the run is sped up to a fixed 1.2×.
- **They don't scale** with the Speed stat (up to 37.5 sprint, so feet slide forward) or the Greatsword weight (20.4 / 25.5, so the legs move faster than the body).
- **PROPOSAL:** in `ClientHandler.Run`, set the run / sprint track speed to `× SpeedMultiplier` (and re-apply it when the attribute changes). Small and safe.

### D. Enemy walk animations ignore enemy speed

- **No speed scaling:** `EnemyService` plays each enemy's walk at 1× whether it moves at 10 (Bandit) or 19 (Siv, the Gale Dancer). Enemies also have no run animation.
- **Result:** the fast enemies (Gale Alchemist 16, Corin Vale 16, Siv 19) visibly slide.
- **PROPOSAL:** `WalkTrack:AdjustSpeed(Def.WalkSpeed / 14.5)`, the same rule as the player's walk, or a run track above ~18.

### E. Attack animations: playback vs the attack's real timing

- **How timing works:** `AttackRunner` times every phase and hit in real seconds (`Startup` / `Active` / `Recovery` / `HitTimes`). The animation's speed (`AnimSpeed`, or `AnimPeak` lined up with the active window) only changes how it *looks*.
- **The ratio below** is the animation's length at its playback speed ÷ the attack's length:
  - **under ~0.75:** the animation ends while you're still locked in the attack, so the character pops to idle and stands for the rest;
  - **over ~1.3:** the animation keeps playing (at Action3 priority) after the attack has ended and you can move, so the attack pose lingers over walking.

**Dead time** (the animation is too short for the attack):

| Attack | Animation | Plays | Attack | Ratio | Idle time |
|---|---|---|---|---|---|
| **Fist Heavy (R)** | FistHeavy | 0.47 s | 1.17 s | **0.40** | **0.70 s** |
| Daggers Light 4 | Daggers_Light4 | 0.30 | 0.70 | 0.42 | 0.40 |
| Guns skill (Fan the Hammer) | Guns_Light2 | 0.41 | 0.78 | 0.52 | 0.37 |
| Sword dash attack | Sword_Light4 | 0.41 | 0.72 | 0.57 | 0.31 |
| Gauntlets Heavy | Gauntlets_Heavy | 0.57 | 0.93 | 0.61 | 0.36 |
| Fist dash attack | FistCombo1 | 0.47 | 0.75 | 0.62 | 0.28 |
| Boxing Light 4 | Boxing_Light4 | 0.48 | 0.77 | 0.63 | 0.29 |
| Rapier / Sword / Greatsword / Fist Light 4 (finishers) | each Light4 | — | — | 0.66–0.72 | 0.26–0.36 |
| Most weapon dash attacks | — | — | — | ~0.68 | ~0.2–0.35 |

- **The pattern:** the 4th light hit (the finisher) and the dash attacks have long recoveries, but their animations were sped up to fit the *hit* moment, so they finish early.
- **Fist Heavy is the worst case:** a 0.47 s animation for a 1.17 s attack.

**Overrun** (the animation keeps playing after the attack ends):

| Attack | Plays | Attack | Ratio | Extra |
|---|---|---|---|---|
| **WHERE YOU GOING?! (Fists class skill)** | 4.20 s | 2.60 s | **1.62** | **1.6 s** |
| **Iaido Barrage (Sword class skill)** | 2.83 | 1.79 | **1.58** | **1.0 s** |
| Ren (Rapier class skill) | 2.55 | 1.84 | 1.39 | 0.7 s |
| Rapier Heavy | 1.16 | 0.84 | 1.39 | 0.3 s |
| Whirlwind Cleave (Greatsword class skill) | 2.83 | 2.31 | 1.23 | 0.5 s |
| Greatsword skill / Heavy | 1.54 / 1.49 | 1.30 / 1.29 | 1.18 / 1.16 | 0.2 s |
| Daggers Light 1–3 | ~0.46 | 0.34 | 1.30–1.43 | 0.1 s (minor) |
| Gauntlets / Guns pistol-whip Light 3 (FistCombo3) | 0.55 | 0.40–0.42 | 1.31–1.38 | 0.15 s (minor) |

**Fine** (0.85–1.15): the remaining 50 or so, including most class skills, all gun shots, the Greatsword / Sword / Rapier lights 1–3, the fist lights and Uppercut.

**PROPOSALS:**
1. **Overrun:** stop the attack animation (short fade) when the run ends after *Recovery*, as `AttackRunner` already does on Interrupted / Feinted. Or trim the class skills' recovery to the animation, but that's balance, so the owner decides. The one-line, low-risk version is to fade it out in `Finish` for every outcome.
2. **Dead time:** for finishers and dash attacks, slow the animation so it fills the attack. Set `AnimSpeed ≈ length ÷ (Startup + Active + Recovery)`, keeping the hit moment by moving `HitTimes`. Or leave the timing alone and give the last 0.2–0.4 s a hold pose.
   - **Fist Heavy specifically:** its sheet animation is short. Either a longer heavy animation is needed (owner), or slow it to about 0.45× (it would look sluggish).

### F. Smaller notes

- **`StarterPlayer.CharacterWalkSpeed = 20`** is unused (the custom StarterCharacter's own value wins). It's harmless but misleading; set it to the chosen base so nobody tunes the wrong number.
- **Twelve or so scripts each restore** `DefaultWS × SpeedMultiplier` themselves, and they can overwrite each other (e.g. a block ending mid-run). Run guards it by checking the speed hasn't changed, so it works today.
  - **Optional refactor (PROPOSAL):** one `Movement.Restore(Character)` helper.
- **The Speed stat only affects movement.** No stat changes attack or animation speed (by design in `Formulas`). Intelligence still does nothing (marked UNRESOLVED there).
- **The swim sprint** restores to 12 (the StarterCharacter value). It agrees with everything else, so it inherits finding A.

## Applied 2026-10-18 (owner: "set the base walk speed to 16, fade attack animations out when the attack ends, and scale the run/sprint and enemy walk animations by speed. Leave the per-attack dead-time tuning for later.")

| Fix | What changed | Tested (Rensei Play) |
|---|---|---|
| **A. Base walk speed 16** | `StarterCharacter.Humanoid.WalkSpeed` 12 → **16** (every walk-speed writer reads it). `StarterPlayer.CharacterWalkSpeed` 20 → 16, so the unused value matches. Steady Array's full-speed casting now uses the base instead of a hard-coded 12 (`AlchemyService`) | client **16 at spawn, still 16 after a run** (was 16 → 12); server 16 |
| **E1. Attack animations end with the attack** | `AttackRunner.Finish` stops the attack's animation (Roblox's short default fade) on every outcome, not only Interrupted / Feinted. It skips this if a newer attack already took over the character, so strings and chains keep their own animation | a 4.2 s animation (WHERE YOU GOING?!) run as a 0.7 s attack **stopped at 0.65 s** (it used to play to 4.2 s); a 3-hit fist string played and stopped normally |
| **C / D. Run, sprint and enemy walk follow speed** | **Already in place, done by another change made in Studio during this session** (not by this one): `Managers.LocomotionSync` (player walk and run tracks follow real ground speed against `TuningConfig.Locomotion.Design`), and `EnemyService`'s `WalkRate` (enemy walk = walk speed / 12, clamped 0.5–1.6). Nothing was duplicated | walking at 16: walk track **1.33×**; running at 24: Run **~1.0×**; sprinting at 30: SpeedyRun **1.0×** |

- **Errors / profile:** 0 client or server errors; the profile was snapshotted and restored.
- **Backup:** `RenseiBackups["Pre-SpeedFix_2026-10-18"]` holds AttackRunner and AlchemyService. Its README has the undo steps, including putting the two StarterPlayer values back.
- **Note for the owner:** `Locomotion.Design.Walk / WalkAnim = 12` says the walk animation looks right at 12. At the new 16 base it plays at 1.33×. If the walk looks hurried, raise those two values toward 14.5–16 (one line in `TuningConfig`).
- **Still open:** the per-attack dead time (E2; deferred by the owner) and a cast / crouch walk (B).

## 3. Recommended order (each needs the owner's OK; A, C, D and E1 applied 2026-10-18)

1. **Decide the base walk speed** (A): 16 is recommended. Everything else's ratios depend on it.
2. **Fade attack animations out when the attack ends** (E1): it fixes the 1–1.6 s overruns on three class skills.
3. **Scale run / sprint and enemy walk tracks by speed** (C, D): small and safe.
4. **Fill the dead time** on finishers, dash attacks and Fist Heavy (E2): per-attack tuning, or new animations from the owner.
5. **Cast / crouch walk** (B): it needs an animation, or a clamp.

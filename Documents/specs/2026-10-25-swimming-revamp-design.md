# Swimming revamp: audit and design

> **Owner update (2026-10-25), overrides the slot text below:**
> - **Climbing out:** use the game's existing **ledge-climb** animation, the one played when you pull up onto a ledge. In the repo's JumpManager that pull-up plays `Vault1`/`Vault2`. Task 1's Studio survey confirms which `Assets.Animations` entry is the ledge climb (and whether a dedicated ledge-climb id exists) and uses that one.
> - **Underwater idle:** use the surface idle, `Swim_Idle`.
> - So **`Swim_ClimbOut` and `Swim_UnderIdle` are not new slots any more**. The owner only needs to upload **two** animations: `Swim_Dive` and `Swim_Surface`.
> - **The Ye plunge hole is APPROVED** (owner, 2026-10-25: "The deep diving hole in Ye's gorge is a good idea (you can work on that in studio I don't want to open blender yet)"). The optional Task 8 is in scope. It is **Studio-only, with no Blender**: a reversible Studio script carves the terrain hole and resizes the Baseplate around it, with a restore guard, as planned.
> - **Placeholders (owner, 2026-10-25: "Use placeholders for the other 2 animations"):** `Swim_Dive` and `Swim_Surface` are created **filled**, not empty.
>   - `Swim_Dive` copies `Swim_Forward`'s AnimationId, played with the body pitched down.
>   - `Swim_Surface` copies `Swim_Idle`'s AnimationId, played once, briefly.
>   - Each slot carries the attribute `Placeholder = true` and the name of the animation it copies.
>   - To swap in a real animation later, paste its id into the slot and clear `Placeholder`. No code changes.
>   - The undo refusal for owner-filled slots does not apply while `Placeholder` is true.

**Status:** written overnight on 2026-10-25 under the owner's overnight go-ahead. **Not approved by the owner yet. Nothing here is built.** The plan is `Documents/plans/2026-10-25-swimming-revamp.md`.

**The owner's request** (Backlog, "After the Foundry Yard plan"): "Completely audit and revamp the swimming system. (I want it to be directional, with a dive system)".

**When it's built:** after all the Foundry Yard tasks and their joint publish checkpoint, alongside the gun class rework (Backlog item 3).

**Every number and every new name in this file is a PROPOSAL** unless it is marked as the owner's. The owner's own rules that still stand:
- **Owner decision 6 (2026-10-18):** no combat or alchemy while swimming, for players and enemies.
- **Swimming extras (owner, 2026-10-18):** swim sprint (stamina), diving, breath and drowning, and touch buttons that only show while swimming. The numbers were proposals: sprint ×1.6 for 14 stamina/s, 15 s of air, and drowning at 6% of max HP per second (`Owner Hand-off 2026-10-18.md`). This design keeps all three.
- **UI:** use only the game's existing UI assets.

---

## 1. Audit: how swimming works today

Read from the repo exports on 2026-10-25. Studio was not opened. Items marked **(Studio check)** can only be confirmed there, and the plan's Task 1 measures them.

### 1.1 How it is built

- **The movement is Roblox's own terrain-water swimming.** The game doesn't move the swimmer at all (`SwimService.lua:3`, `SwimClient.client.lua:8`).
- **The server owns the game state.** Every 0.15 s, `SwimService` puts a character in deep water into `Traversal = "Swim"` (`SwimService.lua:72-90`, `MovementState.lua:208-222`). That state carries the Climbing status, which blocks every attack, block, cast, skill, shot, run, roll and crouch. It also turns Combat Mode off (`SwimService.lua:77-83`, `Requests/CombatMode.lua:9`).
- **"Deep water"** is either the Humanoid's Swimming state, or a terrain-water cell at least 60% full at the root or 2 studs under it (`SwimService.lua:38-45`, `62-69`).
- **The client** (`SwimClient`) plays `Swim_Idle`, `Swim_Forward` or `Swim_Sprint`. It also runs the sprint (Shift asks the server; the client raises its own WalkSpeed), the rise (Space sets `Humanoid.Jump`), and a breath bar it builds itself (`SwimClient.client.lua:35-137`).
- **The server** drains sprint stamina, and counts breath and drowning (`SwimService.lua:94-121`).
- **Tuning** is `TuningConfig.Swim` (`TuningConfig.lua:243-266`).

### 1.2 What is wrong or missing

| # | Finding | Evidence |
|---|---|---|
| A1 | **The swimming isn't directional by design.** The only "direction" is Roblox's default: the humanoid swims along the camera. Nothing in the game reads the camera's pitch, turns the body, or controls vertical speed. The animation is picked only by "moving or not". | `SwimClient.client.lua:8`, `102`, `123-124` |
| A2 | **The body never pitches.** `Swim_Forward` is a prone stroke with the torso fixed at 76° (Phase A audit, table row "Swim Forward"). Swimming down plays the same level stroke as swimming across. | `Rensei Phase A Audit 2026-10-17.md:45`; `SwimClient.client.lua:123-124` |
| A3 | **There is no dive system.** "Diving" means looking down and holding W. There is no dive input, no descend key, no underwater state, and no dive or surface animation. Space only rises. The changelog contradicts itself: the extras table says you can dive (head reached y 1.77), and its "Not tested" list says "there's no diving". Both are true: you can just get your head under, but buoyancy wins. | `SwimClient.client.lua:8`, `117-121`; `Changelog.md:2992`, `3008`, `3086` |
| A4 | **Accidental dives.** Because the swim follows the camera, looking down at the water while swimming pulls you under. | same as A1 |
| A5 | **Buoyancy fights any dive.** Roblox's buoyancy alone brought a character from the bottom to the surface in 0.75 s. | `Changelog.md` (touch-buttons notes, "Rising is mostly automatic") |
| A6 | **The water is too shallow to dive in Ye.** Ye's pools are capped at about 5.2 deep by the Baseplate (2048 × 16 × 2048 at (0, −8, 0), so its top is y 0). The expansion's creek and gorge channels are 4.2 deep (Bed 1, Top 5.2). **Foundry's cooling pond is 9 deep** (top 3, bed −6) and was built for diving, but nothing in the game uses that depth yet. | `Changelog.md:3093`; `Art/Studio/Regions/Lindenmoor/ye_survey.json` (Baseplate); `Art/Regions/Lindenmoor/water_segments.json`; `Art/Regions/Foundry/water.json`; `Foundry Yard Kit.md:55` |
| A7 | **The breath bar breaks the owner's UI rule.** It is a plain Frame and TextLabel made in code, in the Garamond font. The game's own art and font (Guru) aren't used. | `SwimClient.client.lua:35-68` (the game's font: `MobileControls.lua:28`) |
| A8 | **Breath only counts inside the Swim state.** A character that can't enter the state never runs out of air. **Carrying** a body blocks the state, so a carrier can walk along a pond's bed forever. | `SwimService.lua:103`; `MovementState.lua:30`, `215` |
| A9 | **No way out of the water at a wall.** A client can't climb from the water (the server refuses, and JumpManager returns early on the Climbing status). Getting out works only where the bank is a slope or a lip low enough for Roblox's swim hop. There's no climb-out move. | `MovementState.lua:246`, `255`; `JumpManager.lua:609` |
| A10 | **Entering and leaving have no feedback for the player.** Entering makes only an AI noise (Splash, radius 12). There's no entry, surfacing or exit animation, effect or sound. The state ends after 2 dry checks (0.3 s), which is fine. | `NoiseService.lua:73-74`; `TuningConfig.lua:247` |
| A11 | **Stealth underwater is accidental and total.** PerceptionService's sight rays use a default `RaycastParams`, where `IgnoreWater` is false. So the water's surface probably blocks every ray to a submerged body: a diver is likely invisible from any angle and distance, even to an NPC beside them. **(Studio check)** | `PerceptionService.lua:34-35`, `76-98` |
| A12 | **Swimming is silent to the AI after the splash.** Sprint-swimming makes no sound, and neither does surfacing. Footsteps are skipped for every traversal state. | `NoiseService.lua:83` |
| A13 | **Shift lock would undo any swim facing.** In shift lock, SettingsUI sets `Humanoid.AutoRotate = true` every frame unless JumpManager is climbing, wall-running or ledge-walking. An underwater controller that turns AutoRotate off would be overridden. | `SettingsUI.lua:111-113` |
| A14 | **A knockback clears any movers on the root's `VelocityAttachment`.** A swim controller placed there would be destroyed by the first hit. | `MoverManager.lua:333-338` |
| A15 | **Touch players can't dive or descend at all**, except by camera pitch (A4). The swim buttons are SPRINT and RISE only. | `MobileControls.lua:63-65`, `274-275` |
| A16 | **The sprint speed is set by the client.** The server owns only the `SwimSprint` flag and the stamina. Nothing checks how fast a swimmer really moves. That matches the rest of the game's movement today, but a 3D controller makes it worth a sanity check. | `SwimClient.client.lua:108-116`; `Requests/Swim.lua:9-16` |
| A17 | **The docs disagree about Swim Idle.** `Animations.md` says "Swim Idle: no id". The 2026-10-18 sheet import registered Swim Idle and Swim Sprint, and SwimClient plays them. The ids aren't written in the repo. **(Studio check:** read the ids in `Assets.Animations.Shared.Movement.Swim`.) | `Animations.md:80`; `Changelog.md:2912`, `3463` |
| A18 | **There are no swim tests.** No RenseiTests suite covers swimming. The only water checks are Lindenmoor's `WaterIsReal` (the water exists) and a crowd test's puddle. | `Scripts/ServerStorage/RenseiTests/` (`Play_LindenmoorSmoke.lua:215`) |

### 1.3 What works and stays

- **No combat or alchemy in water, for players and enemies** (owner decision 6). `AlchemyService.lua:200` refuses a cast with the Climbing status; `EnemyService.lua:87` and its brain refuse attacks, casts, blocks and parries; `CombatDirector.lua:233`, `291` drop swimmers from the squad tokens. Unchanged.
- **The server owns the Swim state.** A client can't start, end or replace it (`MovementState.lua:205-222`, `246`).
- **Breath and drowning numbers** (15 s of air, 5/s refill, 6% of max HP per second through `DownedManager.Damage`; at 0 HP you're knocked out, not killed) work and were tuned against health regen.
- **The sprint flow** (the server's `SwimSprint` attribute and stamina) works.
- **Both maps' water is terrain water**, which `SwimService` reads.
- **Enemies in water** keep their Swim state and chase on the surface.
- **The animation fallback is safe.** `AnimationManager.Has` is false for an `Animation` with an empty id and no saved sequence (`AnimationManager.lua:22-34`, `123-127`, `154-156`), so an empty upload slot just falls back.

---

## 2. Directional swimming

One **client swim controller** moves the swimmer while the server says `Traversal = "Swim"`. It replaces Roblox's own swim steering, which causes A1, A3, A4 and A5. It is a new client module, `Modules.Managers.SwimController`. `SwimClient` stays the script that starts it and keeps its job (sprint, rise, touch actions); the old version is backed up.

**How it moves you:**
- A `LinearVelocity` and an `AlignOrientation` on the root, on their own attachment, `SwimAttachment`, so a knockback's `MoverManager.ClearMovers` can't delete them (A14).
- Their force is finite, so walls, the bed and knockbacks still push you.
- **They pause** (force 0) while you're stunned, dashing, or while any `MoverManager` mover is on `VelocityAttachment`. A hit in the water still throws you.
- The input is the Roblox control module's move vector (`PlayerModule:GetControls():GetMoveVector()`), so keyboard, thumbstick and gamepad all work the same way. **(Studio check:** the place uses Roblox's standard PlayerModule. If it doesn't, the fallback is `Humanoid.MoveDirection` plus the camera's pitch.)
- The maths lives in a **pure module**, `Rensei.SwimLogic`, so it is tested without a character.

**Two states, kept on the client** (only the swimmer's own client needs them):

| | **Surface** | **Underwater** |
|---|---|---|
| When | Your head is within `SurfaceBand` (0.6) of the water's surface | After a dive, until your head breaks the surface |
| W A S D | Level, relative to the camera's **yaw only**. Looking down never pulls you under (fixes A4) | **Full 3D, relative to the camera**. W swims where the camera looks, pitch included. A and D strafe level. S swims back |
| Vertical | Held at the surface by the controller | Space rises at `AscendSpeed` (10). Ctrl sinks at `DescendSpeed` (10). With no input you drift up slowly (`Drift`, 1.5 studs/s): a gentle buoyancy that never fights you |
| Speed | Walk speed × `SpeedMultiplier`, as today | × `UnderSpeedMult` (0.85) |
| Sprint (Shift) | × 1.6, 14 stamina/s, as today | the same, and breath drains × `UnderSprintBreathMult` (1.5) |
| Body | Upright facing as now (AutoRotate) | The controller turns the body to the swim direction and **pitches it** up to `MaxPitch` (80°), so a dive reads as a dive (fixes A2). The prone stroke animation plus the root's pitch gives the pose |
| Animations | `Swim_Idle`, `Swim_Forward`, `Swim_Sprint` | `Swim_UnderIdle` (fallback `Swim_Idle`), `Swim_Forward`, `Swim_Sprint` |

**Shift lock:** while you're underwater, the controller owns the facing. SettingsUI's shift-lock loop skips its `AutoRotate = true` then, just as it does for JumpManager's climb (fixes A13).

**Others see it:** your client owns your character's physics, so the pitch and the animations replicate to other players as they do today.

**(Studio check)** Does an `AlignOrientation` pitch a humanoid that is in the Swimming state? The plan measures this first. **If it can't,** the body stays level and the movement is still fully 3D. The `Swim_Dive` animation then carries the look of the dive.

---

## 3. The dive system

**How to dive:**
- **Keyboard:** at the surface, **tap Ctrl** (the crouch key; crouching is already refused in water). Underwater, **hold Ctrl** to sink and **hold Space** to rise.
- **Touch:** a new **DIVE** button (tap at the surface = dive; hold underwater = sink), in Slide's spot, using the same slot-plate art. It shows only while swimming, beside SPRINT and RISE (fixes A15).
- **Pitch alone never dives** (see A4). PROPOSAL; listed under decisions.

**The dive:**
1. **The client checks the depth.** A ray down from the root (ignoring water) finds the bed, and a ray from above finds the water's surface. If the water under you is shallower than `DiveMinDepth` (4.5), nothing happens.
   - Ye's pools (5.2) allow a shallow dive.
   - The creek channels (4.2) don't.
   - Foundry's pond (9) and Ye's proposed plunge hole (§4) give a real one.
2. **The dive itself:** `Swim_Dive` plays once (head first). The controller pushes you down at `DiveSpeed` (16) for `DiveTime` (0.35 s), pitched down, and you are now Underwater.
3. **Underwater:** steer with the camera; Space and Ctrl go up and down; Shift sprints.
4. **Surfacing:** when your head breaks the surface, `Swim_Surface` plays once, you're back in the Surface state, and the AI hears a small splash (Surface noise, 6).

**The air meter (server-owned, as today):**
- `Breath` drains 1/s while your **head is under water**, × 1.5 while sprinting. It refills at 5/s above water. The maximum is 15 s.
- **New:** it counts whenever your head is under, **in the Swim state or not** (fixes A8). Knocked characters are left out, as now.
- At 0 you drown: 6% of max HP per second, through `DownedManager.Damage`. At 0 HP you're knocked out, not killed, and the body floats up. Unchanged.
- **New server attribute `Submerged`:** set while the head is under water, cleared after 2 dry checks. Other systems (stealth) read it.

**Climbing out (fixes A9):**
- At the surface, facing a ledge whose top is at most `ClimbOutHeight` (4.5) above the water and within `ClimbOutReach` (3) studs, **Space climbs out**.
- `Swim_ClimbOut` plays (fallback: the existing `Vault1`/`Vault2`), with an up-and-forward push like the climb's vault. Then `SwimService` ends the Swim state on dry land as usual.
- Higher walls still can't be climbed from the water (the 2026-10-18 rule). Without a ledge in reach, Space rises or hops as today.

---

## 4. Water depth: where you can dive

| Place | Water | Depth | Dive? |
|---|---|---|---|
| **Foundry Yard** | The cooling pond, x 420..560, z −196..−100 | 9 (top 3, bed −6) | **Yes: the main dive site. No map edit needed.** |
| Ye | Mill Pond (−110, −553); Gorge Pool (226, −551.5) | 5.2 (bed = the Baseplate's top, y 0) | A shallow dive only |
| Ye | The expansion's creek and gorge channels | 4.2 (bed 1) | No |

**Ye: one small plunge hole (PROPOSAL, optional).**
- **Where:** in the **Gorge Pool**, under the ledge walk, where a fall from the ledge already lands in the water. It is outside the gorge fix's and the bed fix's regions (x ≥ 336), so it doesn't touch the Lindenmoor fixes.
- **How:** a rectangle of the pool's flat floor, at most 24 × 12 and at least 12 × 8, on the 4-stud voxel grid, is cut through the Baseplate and lined. The water goes down to y −8, so it is **13.2 deep** there.
- **Done by one reversible Studio script,** `Art/Studio/Regions/Lindenmoor/plunge_hole.lua`, with the project's plan / apply / undo / check / test modes:
  - **The Baseplate keeps its instance and its name.** It is resized to the largest of four strips around the hole, and three cloned strips cover the rest. Any Texture keeps its world alignment.
  - A bed slab, and four thin liners in the pool floor's own material.
  - Terrain water from −8 to 0 in the hole.
  - **About 8 parts in all.** Ye has room: 76,373 of 80,000.
  - Every change is marked. Undo restores the Baseplate exactly, and removes the parts and the water.
- **Why it isn't an art change:** it is entirely under existing water, in the pool's own materials. Seen from the bank, the pool just looks darker in the middle.
- **It is optional.** If the owner would rather not touch Ye, skip it: Foundry's pond carries the dive, and Ye's pools still allow shallow dives.
- Because the Baseplate is resized, Lindenmoor's survey check ("Baseplate at (0, −8, 0)") and the seam regrade's bare-Baseplate scan would see the change. So `plunge_hole.lua undo` goes first in Lindenmoor's rollback order, and "Ye differs from the kit" lists it.

**Not proposed:** any new pool, any change above the waterline, or any change to Foundry's map.

---

## 5. Animations

All of these live in `Assets.Animations.Shared.Movement.Swim`, so every character preloads them and other players see them. That adds four tracks per character, well under Roblox's 256 (about 140 today).

| Slot | Today | Used for | If the slot is empty |
|---|---|---|---|
| `Swim_Idle` | **exists** (id read in Studio, A17) | treading at the surface | — |
| `Swim_Forward` | **exists**, 114885907475368 | the stroke, at the surface and underwater | — |
| `Swim_Sprint` | **exists** (id read in Studio) | sprinting, at the surface and underwater | `Swim_Forward` (as today) |
| **`Swim_Dive`** | **new slot, empty** | one-shot, about 0.6 s: a head-first duck-dive from the surface | nothing extra: `Swim_Forward` plays while the controller pitches you down |
| **`Swim_UnderIdle`** | **new slot, empty** | loop: hovering underwater, slow sculling | `Swim_Idle` |
| **`Swim_Surface`** | **new slot, empty** | one-shot, about 0.5 s: breaking the surface, a breath, a head shake | nothing: straight to `Swim_Idle` |
| **`Swim_ClimbOut`** | **new slot, empty** | one-shot: hauling yourself out onto a ledge | `Vault1` / `Vault2` (exist; JumpManager's vault) |

- **The owner uploads four animations:** Swim_Dive, Swim_UnderIdle, Swim_Surface and Swim_ClimbOut, made for the game's R6 rig, and pastes each id into its slot's `AnimationId`.
- **No asset id is invented.** The new slots are `Animation` instances with an empty `AnimationId`, created by a reversible Studio script in both places, each with the attribute `Fallback` naming what plays instead. `AnimationManager.Has` is false for an empty slot, so the fallback plays and nothing errors.
- **`Animations.md` is corrected:** Swim Idle and Swim Sprint have ids (with the ids read in Studio), and there's a row for each new slot.
- `Animate`'s own `onSwimming` (it sets the run pose) stays. The swim animations play above it at Movement priority, as now.

---

## 6. Stamina and air

- **Treading water and normal swimming cost no stamina.** Stamina regenerates as usual.
- **The sprint** costs 14 stamina/s and needs 10 to start (the owner's proposal, unchanged). It works at the surface and underwater.
- **Air:** see §3. The numbers are unchanged; the only rule change is that breath counts whenever your head is under (A8).

## 7. Combat, stealth and alchemy

**Combat and alchemy:** unchanged. **No attacks, blocks, skills, shots or casts while swimming, at the surface or underwater** (owner decision 6). Being hit in the water still damages you and throws you: the controller pauses for knockbacks (§2). Enemies stay surface swimmers. They don't dive, and they still can't attack in water.

**Stealth.** This replaces A11's accidental total cloak with a deliberate rule:
- **PerceptionService's sight rays ignore water** (`IgnoreWater = true`), so the surface no longer blocks sight.
- **A `Submerged` target is seen at × 0.3** (`Perception.SubmergedMult`, PROPOSAL), in the same place crouching's × 0.5 goes. Diving is a strong stealth tool, not invisibility: an NPC close by can still spot you.
- **Surface swimmers** are seen as anyone moving at that speed.

**Noise:**

| Sound | Radius | When | Status |
|---|---|---|---|
| Splash | 12 | entering the water | unchanged |
| Surface | 6 | your head breaks the surface after a dive | new |
| Stroke | 8 | every 0.8 s while sprint-swimming at the surface | new |
| — | — | swimming underwater | silent |

Light exposure is unchanged.

**The stealth missions design** (`specs/2026-10-25-stealth-missions-design.md`) can use water as a route: dive past a guard, and surface out of sight.

## 8. Touch controls

While swimming, these show:

| Button | Spot | Action |
|---|---|---|
| **SPRINT** | Dash's spot | hold to sprint |
| **RISE** | Jump's spot | hold to rise; tap at a ledge to climb out |
| **DIVE** (new) | Slide's spot (`{0.20, 0.88, 0.16}`) | tap at the surface to dive; hold underwater to sink |

- All three use the slot-plate art and run `ClientActions` (`SwimSprint`, `SwimRise`, `SwimDive`), like the keys.
- Underwater, the thumbstick plus the camera steer in 3D.
- The on-foot buttons stay hidden while swimming.

## 9. UI (owner rule: existing assets only)

- **The code-built breath bar is removed.** The **air meter** is a runtime clone of the HUD's own Meter bar (`Uis.HUD.Stats.BlueBar`; cyan reads as water), named `AirBar`.
  - It sits directly under the vitals, and is filled through the existing `Fill.Set`.
  - It shows only while you're Submerged or short of air.
  - Its label uses the game's Guru font, as the HUD's hover values do: "AIR", or "DROWNING" (the bar blinks) at 0.
- No new images, fonts or ScreenGuis. The touch DIVE button uses MobileControls' existing slot plate.
- **(Studio check)** `HUD.Stats`'s layout, and where the clone fits, are read in Task 1. Nothing in `StarterGui` is edited: the clone is made at run time.

## 10. Server validation

- **The server owns every rule:** the Swim state, `Submerged`, `Breath`, `Drowning`, `SwimSprint` and its stamina. The client sends only the sprint on/off (`Requests.Swim`, unchanged: a boolean). The dive, the underwater state and the climb-out are local movement, and need no new remote.
- **New: a speed sanity check.** Each check, SwimService compares how far a swimmer moved with the most they could: walk speed × multiplier × (1.6 if `SwimSprint`) × 1.5, plus 8 studs of slack.
  - Three misses in a row clear `SwimSprint` and log a warning with the numbers.
  - It's skipped while the character is stunned or dashing, and for 1 s after a hit (knockback movers are made on the client, where the server can't see them).
  - **It never teleports anyone back.** That keeps the game's current trust level and avoids rubber-banding on lag.
  - The count lives in the attribute `SwimSpeedStrikes`, so tests can read it.
- **New server helper `SwimService.WaterDepthAt(Position)`:** the water column from the surface to the bed, read from the terrain voxels, with the bed found by a downward ray that ignores water. The tests use it, and it can validate a dive later if the owner wants one.
- **Unchanged:** a client that fakes the Swimming state only locks itself out of fighting (`SwimService.lua:66-67`).

## 11. Tests

- **`RenseiTests.Test_SwimLogic`** (pure). Each check fails before `SwimLogic` exists or with a broken input:
  - the surface velocity ignores the camera's pitch;
  - underwater, W follows the pitch, and strafing stays level;
  - ascend and descend, and the idle drift;
  - the sprint multiplier;
  - the pitch clamp;
  - `CanDive` on either side of 4.5;
  - the surface/underwater switch, with its band;
  - the breath step (drain, sprint drain, refill, clamps);
  - the climb-out test (a ledge's height and reach);
  - the speed-strike counter.
- **`RenseiTests.Play_Swim`** (Play, server). An anchored test rig is placed at measured depths in Foundry's pond and in Ye's pools:
  - `WaterDepthAt`;
  - `Submerged` follows the head;
  - breath drains for a carrier under water (RED today, A8);
  - drowning knocks out and doesn't kill (the rig, never the real player);
  - the sprint request is refused on land;
  - a speed strike for a faked jump.
- **Stealth checks in `Play_Swim`:** a test NPC (Play_Stealth's fixture pattern) sees a submerged rig at about × 0.3 of a dry one. RED before the change: it sees nothing at all, which confirms A11.
- **Real input, in Play** (the Studio MCP's keyboard input), once in Foundry and once in Ye:
  - swim at the surface while looking down (you don't sink);
  - Ctrl dives; W steers down; Space surfaces;
  - the air meter shows;
  - a climb-out at a low ledge;
  - DIVE on touch, through `ForceMobileControls`.
- **Regression:** Play_Stealth, Play_Perception, Test_Sound, Test_Perception, and the Lindenmoor and Foundry smoke suites (water), all still green.

---

## 12. Decisions taken without the owner

Each is a PROPOSAL the owner can change.

1. **A client swim controller replaces Roblox's swim steering** (a `LinearVelocity` plus `AlignOrientation` on the client-owned character). The server keeps every rule.
2. **Surface swimming is level. Only a dive takes you under.** Looking down at the surface no longer dives. This removes accidental dives, and changes today's "look down and swim".
3. **Dive = tap Ctrl at the surface; hold Ctrl to sink; Space to rise.** On touch: a DIVE button in Slide's spot. The key isn't rebindable, like crouch.
4. **Underwater movement is fully camera-relative in 3D,** with level strafing, and a slow upward drift of 1.5 studs/s.
5. **The numbers:** UnderSpeedMult 0.85; AscendSpeed and DescendSpeed 10; DiveSpeed 16 for 0.35 s; DiveMinDepth 4.5; SurfaceBand 0.6; MaxPitch 80°; ClimbOutHeight 4.5 and reach 3; sprint breath × 1.5 underwater. The owner's sprint ×1.6 / 14 stamina/s, 15 s of air and 6% drowning are kept.
6. **Breath counts whenever your head is under water,** not only in the Swim state. This closes the carrier exploit.
7. **A low-ledge climb-out (Space)** is added. Higher walls still can't be climbed from the water.
8. **Stealth:** water no longer blocks NPC sight. A diver is seen at × 0.3. Two new noises: Surface 6, and sprint Stroke 8 every 0.8 s.
9. **Enemies don't dive.** No combat or alchemy in water, as before.
10. **The speed check only logs and stops the sprint.** It never teleports anyone.
11. **Foundry's pond is the main dive site.** Ye gets one optional, reversible plunge hole in the Gorge Pool (13.2 deep), made by resizing the Baseplate around a hole. Skip it if the owner prefers.
12. **Four new animation slots** (Swim_Dive, Swim_UnderIdle, Swim_Surface, Swim_ClimbOut), empty until the owner uploads, each with a fallback.
13. **The air meter** is a clone of the HUD's Meter bar. The code-built breath bar goes.
14. **`SwimClient` keeps its name and job.** The movement goes into a new `SwimController` module. The old SwimClient is backed up.

## 13. Open questions (for later)

- Should enemies (or some of them, such as the Gale Alchemist) be able to dive after a player?
- Underwater items or secrets (a sunken cache in Foundry's pond) for quests?
- A swim skill node (longer breath, faster strokes) in the skill tree?
- A gamepad layout: the move vector already works; the dive and rise buttons need mapping if gamepads are supported.

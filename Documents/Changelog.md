# Rensei Changelog

What each phase built and how it was tested. Newest first. Work is in the Studio place **Ye** unless an entry says otherwise. In the entries from 2026-10-17 on, a place called **Rensei** is Ye (106992859583940, the Studio window's title) and **Main Menu** is Character Customization (123967384111466). Backups of every touched script are in `ServerStorage.RenseiBackups`.

## 2026-10-19 — Plan 1: Foundation (in progress)

- Task 1: TestKit (ServerStorage.RenseiTests) — Studio test runner; self-test PASS 4 / FAIL 0
- Task 2: Schema 5, in all three places (Rensei, Tutorial, Main Menu):
  - `ProfileMigrations`: new step `[4]` (4 → 5, additive) adds `Morality.Places / Rumours / Heat / News` and `Licence = {Path = "", Since = 0, Orders = {}, Refused = {}, Revoked = 0}`; an existing `Licence` and the deed ledger are left alone;
  - `ProfileData`: `SchemaVersion = 5`, the four new `Morality` tracks + `Seeded = false`, and the new `Licence` block;
  - byte-identical in all three places: `ProfileMigrations` 7aac8c12 → 08185f97 (2811 bytes), `ProfileData` 7d86af52 → a494cec4 (7554 bytes); backups in `ServerStorage.RenseiBackups["Pre-Foundation_2026-10-19"]` in each place;
  - test `ServerStorage.RenseiTests.Test_Schema5` (Rensei, Edit mode): PASS 4 / FAIL 0.
- Task 3: Regions, communities, birth deeds (Rensei):
  - new `Rensei.Regions`: the graph that word of a deed travels. Five regions (City, Foundry, Lindenmoor, Adit, Wilds), each with the factions present, jurisdiction, safe flag and links. Three carriers: Gossip reaches everyone present; Dispatch reaches only the Authority; Whisper reaches only the Circle. Also an `AreaName` → region map (the default is City) and the helpers `OfArea / Present / FactionsAt / Count / Reach / Links`. Every region, link and minute is a PROPOSAL;
  - `Rensei.Factions`: six origin communities (`Diaspora = true`, so they are present in every region), `Factions.Order` 4 → 10 entries, and the new `Factions.Communities` (origin → community);
  - `Rensei.Deeds`: six `born_<Origin>` deeds (`Scope = "Public"`, `Birth = true`), plus a `Birth` field in the header comment. They are only defined here; nothing records them yet;
  - **for you to review (placeholders, all (new)):**
    - the six community names (Amestrian Citizenry, Ishvalan Community, Xingnese Merchant Houses, Drachman Frontier, Aerugonian Guild, Xerxian Remnant);
    - the birth offsets (each within ±20, each origin's sum ≥ 0);
    - the region **Wilds** (the Forgotten Sites);
  - `Factions.Order` uses (`script_grep`):
    - `Regions.FactionsAt` (new): this is how communities show up in every region;
    - `MoralityService` line 63, `Tiers()`: it now computes 10 tiers instead of 4. This is harmless; the tiers of the communities with no standing read Neutral;
    - `MoralityService` line 95, the tier-change banner loop: a deed that moves a community's standing across a tier now shows a banner, e.g. "Ishvalan Community - Trusted" (`born_Ishvalan` gives +20) once birth deeds are recorded;
    - no client UI iterates `Factions.Order` today, so no faction list grows to 10 rows yet (the Journal tab is Plan 10);
  - backups of Factions and Deeds are in `Pre-Foundation_2026-10-19`;
  - tests (Edit mode):
    - `Test_Regions`: RED was "Regions is not a valid member", then PASS 5 / FAIL 0;
    - `Test_Schema5`: PASS 4 / FAIL 0;
    - `Test_TestKit`: PASS 4 / FAIL 0.
- Note: commit e6f9408 (Task 1) carries a "Claude Sonnet 5.5" co-author line by mistake; it should read Claude Opus 5.5 (not rewritten: the branch is shared).

## 2026-10-19 — Plans: Morality × Reputation roadmap + Plan 1 (Foundation)

**Owner:** "Continue" (the spec is approved; next step, the implementation plans).

> **Status: plans written, nothing built yet.** Nothing in Studio changed for this entry.

- **`plans/2026-10-19-morality-roadmap.md`:**
  - the spec split into 10 plans that each ship working, tested code: Foundation → Heat / Wanted + sound / light → Consequences + Exchange → Licence → stealth kit → identification + hunters → PvP bounties → allies + stealth rewards → Taboo (blocked on canon) → Journal / HUD;
  - the Mecha Arm track: M1 variant model, M2 grapple (needs `graple` uploaded), M3 arm cannon (PROPOSAL, from your Aim / Charge / Shoot animations).
- **`plans/2026-10-19-plan1-foundation.md`:** 10 test-first tasks with full code:
  - test kit;
  - schema 5 (all three places);
  - regions graph;
  - communities and birth deeds;
  - place-by-place standing;
  - MoralityService on places;
  - perception maths;
  - PerceptionService + enemies (S1);
  - WitnessService + tagging the world's watchers;
  - rumour spread (pure, with a test clock);
  - RumourService tick, offline catch-up and witness reports (R2).
- **What players will notice when it's built:**
  - a deed changes standing only where it's heard, and word travels (dispatch to the City in 2 min, gossip in 10);
  - enemies notice you by sight (cones, line of sight, movement), investigate, search, then stay wary;
  - every character gets a birth deed from their origin.
- **For you to review when it's built (all PROPOSAL):**
  - the six community names;
  - the birth offsets;
  - which NPCs count as State agents;
  - the new region "Wilds" (the Forgotten Sites);
  - all timings and ranges.

## 2026-10-19 — Legs on the dagger idle, blocks and parries; no more stock Roblox idle

**Owner:**
- "for the dagger idle, make the legs use the base idle animations since they aren't animated in the dagger idle";
- "Fix the legs for blocking as well & parries";
- "fix characters sometimes being the default roblox idle" (screenshot: arms and legs hanging straight).

> **Status: built and tested in Studio Play** (Rensei), with a probe reading the live animation tracks and hip joints. Mirrored to the Tutorial (same code; not run there).
>
> **Animation sheet re-checked first:** no new or changed ids. The Dagger **Idle** cell is still empty, so the game uses the Studio-authored `Daggers_Idle` (unpublished; plays in Studio only until it's uploaded).
>
> **Backups:** `ServerStorage.RenseiBackups["Pre-BaseIdle_2026-10-19"]` (both places) and `["Pre-DaggerIdleLegs_2026-10-19"]` (Rensei).

### What was wrong (found live)
1. **Everything was stopped, the base idle included.** Block (every F press, so parries too), Heavy and the hit reaction stopped *every* playing track. That included the Animate script's base idle and walk, which carry the legs. The block and style-guard poses don't key the legs at all, so the legs dropped to the rest pose.
2. **The base idle never came back.** Roblox's stock Animate (injected because `StarterCharacterScripts` was empty) only restarts its idle when the idle *changes*. Once its track was stopped from outside, it still believed the idle was playing. A character standing still stayed frozen (arms and legs straight) until it moved. **Measured:** a fresh spawn had **no tracks playing at all**.
3. **Roblox's own idle, sometimes.** The injected Animate came with two Roblox idles; AnimationManager replaced only the first, so the second (Roblox's "look around") played about 1 loop in 10. It also started Roblox's idle on spawn before the ids were swapped.
4. **The dagger idle's legs.** The legs are keyed at weight 0, so they hung off the swaying torso instead of animating.
5. **Found while testing:** after a block, the weapon idle (dagger, style stances) never resumed. WeaponManager also thought its track was still playing.

### Fixes
- **`StarterCharacterScripts.Animate` (new).**
  - Roblox's stock R6 Animate, now installed in the game so Roblox doesn't inject its own copy.
  - It carries Rensei's idle and walk only (`Shared.Movement.Default`).
  - It re-plays the base idle or walk whenever something has stopped it.
- **Block, Heavy (both paths), DamageManager hit reaction:** they stop every track **except the base layer** (Core priority: the Animate idle and walk, and the weapon hold). Guard, heavy and hit poses still replace everything they key.
- **WeaponManager:**
  - the weapon idle, weapon walk and weapon hold re-play if something stopped them;
  - the walk part is Rensei only, since the Tutorial has no weapon walk.
- **`Daggers_Idle`:** the leg poses were removed (594 poses). The base idle now drives the legs; the torso, arms, head and dagger keep the dagger idle.

### Tests (Studio Play, real input actions)
| Check | Result |
|---|---|
| Spawn, standing still | Rensei idle playing (`99650759123617`); no Roblox idle |
| Every track force-stopped (what a ragdoll does) | base idle, weapon hold and dagger idle all back within 0.6 s |
| Dagger idle | `Daggers_Idle` + base idle; the hips move exactly as in the plain idle |
| Hold block (bare-handed Boxing guard, and with daggers) | the guard on the arms; the legs keep the base idle (not the rest pose) |
| Tap F (parry), release block | the base idle never drops; the dagger idle comes back after the block |

**Not changed:** the parry animations themselves (Parry1 / Parry2 / ParryFlinch) already animate the legs; their frozen legs came from the block path above.

### Also logged (no change yet)
- **New Automail animations from the owner** (load-tested, all OK):
  - Mecha Arm Aim `125033765857278` (1.12 s);
  - Cannon Charge `70940393329813` (0.80 s);
  - Cannon Shoot `117668751587041` (0.43 s).
  - They drive the arm's own joints (`fake arm`, `1`–`4`).
- **The owner's new model** `Workspace."StarterCharacterMeca arm2"` (MecArm: `fake arm` + segments 1–4, 5 FX) matches those joints and is the one the Mecha Arm plan will use. It sits in Workspace, so it should move to ReplicatedStorage / ServerStorage before any publish.

### Files
Rensei and Tutorial:
- `StarterPlayer.StarterCharacterScripts.Animate` (new);
- `Skills.Combat.Block`;
- `Skills.Combat.Heavy`;
- `Managers.DamageManager`;
- `Managers.WeaponManager`;
- `Assets.Animations.Weapons.Daggers.Daggers_Idle` (Save).

Exported to `Scripts/` and hash-checked against Studio. The `DamageManager` export also picks up the 2026-10-19 `ArmorResist` change, which hadn't been mirrored yet.

## 2026-10-19 — Design: Morality × Reputation, consequences and rewards (spec, not built)

**Owner:** "make a plan where the morality system intertwines with a reputation system... with real consequences and rewards... ON THEME".

> **Status: design approved section by section; the written spec awaits review. Nothing built.** Spec: `specs/2026-10-19-morality-reputation-consequences-design.md`.

**The owner's choices:**
- the three layers (Licence, Equivalent Exchange, nations);
- every kind of payoff;
- players can act on reputation (opt-in bounties and arrests);
- Taboo as secret power that is hunted once discovered;
- lore-true but bounded nation tensions;
- a consequence layer plus a rumour network.

**The design, in brief:**
- deeds spread as **rumours** between places over real time, and can be suppressed;
- **Heat → Wanted 0–5** with NPC and player hunters;
- the **State Licence vs the Circle** decides power and price;
- every reward shows its **Price**;
- 10 build slices (R1–R10), each with an acceptance test.

**Added the same day: §17 Detection and stealth** (owner: "like Thief, Metal Gear Solid or The Last of Us"):
- **Perception:** awareness for every NPC, alert phases (Unaware / Suspicious / Alert / Cautious), view cones, light Exposure, sound by surface and wall muffling, bodies and alarms.
- **The player's kit:** takedowns (choke, lethal, drop), distractions (throwables, alchemic lures), light control, Alchemic Sense.
- **Identity:** masks, and **anonymous rumours** that only become yours when evidence links them.
- **Animations:** listed against the re-read Animation ID's sheet.
- **Build:** slices S1-S7.

## 2026-10-18 — Data storage audit (all phases)

**Owner:** "Completely audit and fix all datastorage after all phases".

> **Status: fixed in all three places, tested in Studio** (Rensei; your profile was snapshotted and restored, then verified equal to the saved copy). The full write-up is `Data Storage.md`.
>
> **Backups:** `ServerStorage.RenseiBackups["Pre-DataAudit_2026-10-18"]` in each place.

**Fixes:**
- **`ProfileGuard`** (new, identical in every place):
  - repairs NaN or infinite numbers and removes unstorable values, any one of which makes every later save fail silently;
  - checks on load, every 30 s and before every release;
  - wired into Ye's `DataManager`, the menu's `MenuData` and the tutorial's `FlowData`.
- **`ProgressionService`:** `GrantExp`, `GrantMoney`, `SpendMoney` and `AddTraining` refuse NaN or infinite amounts (`GrantExp` let NaN through).
- **Reroll pack purchases** (`MenuServer`): the purchase id is kept in the profile's MetaTags (survives Gate permadeath), and the purchase is reported granted only after a confirmed save. It used to be reported at once, so a crash before the auto-save lost paid rolls.
- **Inventory caps** (`ItemService`, PROPOSALS): 60 entries, 999 per stack, 25 per give. Gives are all or nothing, with a "bag is full" toast.
- **`ProfileData`:** the same template in all three places (the menu and tutorial had an older copy), marked "keep the same".

**Checked and sound:**
- the shared files (migrations, slot account, teleport) are identical across places;
- session locking and teleport hand-off;
- account writes (`UpdateAsync`, idempotent receipts);
- the Gate permadeath reset.
- **Read-only scan of your two saves:** clean; 5.8 KB and 4.2 KB.

**Tests:**
- the guard repairs;
- your profile is clean;
- NaN and infinite amounts refused;
- the inventory caps, including all-or-nothing.

**Still open:**
- **Reroll receipt (tested 2026-10-19):** MenuServer's reroll code was run unchanged on your profile in Ye (the Main Menu's Play start hung). It granted after a confirmed save (11.4 s), and the same receipt again gave no second grant. Restored afterwards, and the stored copy checked: clean. The Main Menu path itself (`MenuServer.StudioReceiptTest`) is still to run.
- **`AddUserId`:** missing from this ProfileService version, which matters for data-deletion requests.

## 2026-10-18 — Fluidity pass: combat, M1s, movement, climb → ledge walk; Boxing knockback; no infinite combos

**Owner:**
- "completely audit combat fluidity, m1 fluidity, movement fluidity, and make it smoother to go from a climb into a ledge walk. Always publish the changes to the changelog";
- "make it so the 4th in boxing does a knock back, I don't want any infinite combos";
- "For the fluidity tests try the most complex things you can".

> **Status: built and tested in Studio Play** (Rensei), with chained real-input runs (keyboard / mouse) and server and client probes. The same changes are mirrored into the Tutorial place where its code has them (no ledges or styles there).
>
> **Backups:** `ServerStorage.RenseiBackups["Pre-Fluidity_2026-10-18"]` in both places (every touched script, as it was).
>
> **Numbers:** all new numbers are PROPOSALS in `TuningConfig`. No attack timing (startup, active, recovery) was changed: the owner deferred per-attack timing earlier today.

### Climb → ledge walk (the owner's request)

**Before (measured):**
- climbing down onto a ledge let go of the wall, fell, landed, and then needed 0.3–0.5 s standing still before the ledge walk started;
- the S key still held from climbing down walked you **backwards off the ledge**, and you fell to the ground 7.5 studs below.

**Now:**
- **Direct hand-over.** Climbing down onto an authored ledge on the same wall (feet within 1.5 studs), or sideways with your feet already at it, hands straight over to the ledge walk:
  - the server replaces the climb session with the ledge session, so there's no let-go, fall, landing or wait;
  - the body eases onto the strip over 0.3 s;
  - the climb pose blends into the ledge pose over 0.25 s;
  - the S you climbed down with is ignored until you release it.
  - **Measured:** the ledge walk is live 0.08 s after the feet reach the ledge, the body comes down at 9.4 studs/s (no fall), and it stands exactly on the strip; holding S 3 more seconds no longer steps you off.
- **Server height check.** The server allowed the root at most 6 studs over the strip and refused the hand-over at 6.51, because it sees a descending climber slightly late. Now `LedgeWalk.ServerAbove = 7`.

### Climbing (found by the chained tests)

**Sprint-jump grabs were refused mid-air.**
- **Cause:** the server sees a moving player about 0.3 s late in Studio (more live). A sprint-jump grab arrived while the server still had the player 10.4 studs from the wall, outside its 9-stud reach, so the climb was refused and you dropped.
- **Fix:** a start request that fails *only* the wall / ledge check is now re-checked for up to `Traversal.ValidateGrace = 0.5` s before it's refused. Stun / knock / grip refusals stay immediate, and a stop request cancels the re-check.
- **Measured:** the grab was accepted 0.35 s after the request.

**Grab buffer.**
- **Problem:** a sprint jump is only about 0.3 s airborne, and Space pressed a moment before the wall was in reach did nothing (you hit the wall and fell).
- **Fix:** that press is now remembered for `Parkour.GrabBuffer = 0.25` s and grabs as soon as the wall is in reach.

**False "top of the wall" vault.**
- **Problem:** climbing past anything that juts out (the LedgeCourse ledge strip juts 1.4 studs) left the climber hanging off *its* face. Above it, the 4-stud wall probe fell 0.05 studs short of the real wall, so the climb vaulted you off mid-wall as if it were the top.
- **Fix:** the probe is now 4 + `Parkour.ClimbProbeExtra = 2` studs.

**Legs dragging over a jutting strip.**
- **Problem:** the hang point only checked head height, so the legs dragged over the strip. The humanoid kept trying to stand on it: state flicker and +99 / −58 studs/s jolts.
- **Fix:** chest, shin and foot probes push the hang point out as needed (worst jolt 99 → 48 studs/s on the first fix).

### Combat / M1

**Boxing:**
- **The 4th hit knocks back** (stun 0.8, like the Rapier and Daggers finishers).
- **Measured:** it pushes the target 39.9 studs; the other finishers push 40–43 on the same enemy.

**No infinite combos.** Every M1 string was audited from the live numbers (stun vs recovery + the next windup):

| String | Finisher | Loop check |
|---|---|---|
| Fists, Katana, Rapier, Caestus, Greatsword, Daggers, Guns, Lethwei | knockback | knocked 40+ studs; dash can't cancel recovery, so the next hit arrives after the stun ends |
| Boxing (before) | pull, stun 0.35 | free 0.40 s |
| Boxing (now) | knockback | as above |

- **Loophole found: a feint reset the combo.** 1-2-3, feint 4, then 1 landed inside hit 3's stun, so the string restarted without ever reaching the finisher (limited only by the feint's 2 s cooldown). **A feint now keeps the combo's place:** the feinted hit comes next.
- **Universal safety net (`DamageManager`).** A target held in unbroken hitstun for `HitStun.MaxChain = 3.0` s gets no more stun from further hits (damage still lands) for `HitStun.ChainBreak = 0.6` s.
  - **Measured on a dummy hit every 0.42 s for 8 s:** stunned 0–3.00, free 3.00–3.90, stunned again, free 6.90–7.80.
  - A normal 4-hit string (about 1.8 s) never reaches it.
  - It protects players from enemy chains too.

**M1 animations: follow-through re-timed.** Audit of all 36 M1 hits:
- every finisher's animation ended 0.23–0.40 s before its recovery, so you stood in idle while still locked;
- pistol whips 2–4 were slowed to 0.6× and cut off halfway;
- dagger hits 1–3 ran 0.10–0.15 s past the swing and were cut off.

**Fix:** after the impact frame, the rest of a light's or heavy's animation is re-speeded to end exactly with the attack. Hit timing and every number are unchanged, and class skills keep their own timing (grab pairs stay in sync).
- **Measured:** the Lethwei finisher now plays through to the end of its recovery (2.77 s) instead of freezing for 0.25 s, and held-M1 strings chain with no dead frames.

### Movement
- **Landing on the move.** The landing animation (authored at Action priority) replaced the run's legs for 0.5 s while sliding at sprint speed. Moving, it now blends in at Movement priority and plays at 1.8×; standing still, it plays as before.
- **Checked and fine:**
  - walk → run → speedy run after 2 s;
  - sprint jumps keep sprint speed;
  - the dash eases 107 → 16 studs/s and the roll fades out;
  - sprint is hold-Shift, by design.

### Complex chained tests (real inputs, recorded every frame)
1. **The full traversal chain:**
   - sprint → jump → buffered air grab → climb up past the L1 strip → sideways → climb down → **ledge walk hand-over** → walk the ledge → W+Space hop back into the climb → climb to the top → vault.
   - The first runs exposed the three climbing bugs above. After the fixes the whole chain runs end to end with no errors.
2. **A held M1 string:** a 4-hit Lethwei string held through, plus the next string. Chains cleanly; finisher retime confirmed.
3. **An 8-second chain on an enemy** (the cap test above), the **Boxing finisher**, and **every class's finisher** on the same enemy.
4. **Climb-down with the old code vs the new**, side by side (the numbers above).

### Follow-up (same day, after Studio's Play start recovered)

**Climbing past a jutting ledge, now smooth.** The hang point used to jump a strip's depth (1.4 studs) out from the wall in one frame. It now glides at up to `Parkour.ClimbOutRate = 10` studs/s, and a probe just below the feet sees a protrusion early when climbing down.
- **Measured over the whole chain:** the worst velocity while climbing went 99 → 48 → **15 studs/s**.
- The climb-down hand-over to the ledge walk still works.

**Jump attacks that fizzled.**
- **Problem:** an M1 just before landing came out as a jump attack. The server, which sees the player about 0.3 s late, started the dive after the landing, and it ended at once (a 0.16 s scrap, no hit, wasted input).
- **Client fix:** the client now estimates the time until the feet touch down (height and fall speed under gravity). Under `Light.JumpAttackLandLead = 0.25` s, the click is a normal light, so the combo continues.
- **Server fix:** the server's own airborne check (meant for falls) only fires with no ground within 14 studs. A normal jump's apex no longer turns a light into a dive.

| Click after the jump | State | Result |
|---|---|---|
| 0.08 s | rising | aerial |
| 0.18 s | rising | aerial |
| 0.28 s | falling | normal light |
| 0.36 s | falling | normal light |

**Complex combat chain.** Real inputs went through `ClientActions`, the same path as the keyboard and touch buttons, against a passive Bandit with huge health:
- dash → M1 dash-cancel → M1 + R (queued heavy) → M1 + feint → M1 → M1 → M1 (finisher) → uppercut → 3 air M1s → jump → aerial.

Results:
- **Feint:** the feinted Light2 came out next (the feint keeps the combo's place).
- **Boxing string:** Light2, 3 and 4 all landed; the finisher stunned 0.8 s and knocked back.
- **Uppercut:** launched the target about 10.7 studs; all 3 air M1s landed; the target was free after 2.35 s, under the 3 s cap.
- **No errors** and no stuck combat states.
- **Two whiffs, both from positioning:** the dash-cancel M1 and the queued heavy (the 9-stud dash carried the attacker into or past the target).

### Not yet tested
- Two players.
- A real phone.
- Live latency: the grace, buffer and landing lead were sized for it, but only Studio was measured.

### Files
Rensei and Tutorial:
- `Managers.AnimationManager` (Fade, Retime);
- `Managers.AttackRunner`;
- `Managers.DamageManager`;
- `Managers.JumpManager`;
- `Skills.Combat.Fist.FistSwing`;
- `Skills.Combat.Air` (legacy copy: landing only);
- `StarterPlayerScripts.ClientHandler` (jump attack near landing);
- `Data.Rensei.TuningConfig`.

Rensei only: `Managers.JumpManager.LedgeWalk` and `Managers.MovementState`.

Exported to `Scripts/` (hash-checked against Studio), except the legacy `Skills/Combat/Air.lua`, which isn't mirrored.

## 2026-10-18 — Daggers: one dagger, in the right hand

**Owner:** "for the dagger model for the dagger class, I only want 1 dagger in the player's right hand".

> **Status: changed in Rensei and the Tutorial, checked in Studio Play** (Rensei). Nothing saved to the profile (`WeaponManager.Give` doesn't touch data; the equipped weapon stayed empty). Backup in both places: `ServerStorage.RenseiBackups["Pre-OneDagger_2026-10-18"]` (the whole Daggers tool).

- **What changed:** the Daggers tool (`ReplicatedStorage.Assets.Items.Weapon.Daggers`) held two daggers: `Dagger` + `DaggerMain` on the right arm, and `DaggerL` + `DaggerOff` on the left. The left pair is removed. No script named them, because `WeaponManager` attaches whatever grip parts the tool has (by their `Arm` attribute).
- **Result:**
  - one dagger, holstered at the right hip and drawn into the right hand;
  - the left hand is empty;
  - enemies that roll daggers hold one dagger too (they use the same tool).
- **Checked in Play:** given to the character, holstered, then drawn with Combat Mode (E). The right-arm Motor6D was enabled, the holster weld disabled, and there was no second blade (screenshots front and side).
- **Unchanged:**
  - The class keeps the name "Daggers" (display name, item name, animation names).
  - Animations made for twin daggers still move the left hand as if it held a blade; there's simply nothing in it now. Rename or re-animate only if you want.
- **Not a dagger part:** the plain brown block on the back in the owner's screenshot is the character's bare right arm. That outfit's shirt leaves the right sleeve uncovered, so the arm shows in skin colour.

## 2026-10-18 — Player Identities, Forgotten Sites (Halvard's Adit), directional climbing, boss bar, speed audit, tutorial update

**Owner:**
- the "RENSEI — PLAYER IDENTITIES + FORGOTTEN SITES EXPLORATION SYSTEM" brief;
- "Also fix the K menu UI positioning";
- "bring back directional climbing ... fit in with the game's vibe and the movement";
- "Make sure the UI layout for the identities tab looks visually appealing and is easy to understand";
- "audit and update the tutorial as well for all of the new features";
- "when there's a boss I need to fight, put their health bar at the top of the screen";
- "audit speed balancing and how they affect animations";
- "Make it so the dungeon NPC's have a longer respawn rate".

> **Status: built and tested in Studio Play** (Rensei and Tutorial). Every test snapshotted the owner's profile and restored it exactly. Nothing published. The full design, rules and test list are in `Identities and Forgotten Sites.md`.
>
> **Backups** (`ServerStorage.RenseiBackups`):
> - Rensei: `Pre-IdentitiesSites_2026-10-18`, `Pre-HalvardsAdit_2026-10-18` (with the terrain), `Pre-DirClimb_2026-10-18`;
> - Tutorial: `Pre-TutorialUpdate_2026-10-18`.

### K menu
`MasteryUI` line 124: a mid-line comment had swallowed `Position = Source.Position`, so the panel opened in the wrong place. Fixed.

### Player Identities
- **New:** `Rensei.Identities` (rules), `IdentityService` (the only writer), and a Journal **Identities** tab. MenuKit now takes more than 4 tabs.
- **How records are made:**
  - encounters (hits between two players);
  - witnessed casts (60 studs, line of sight);
  - introductions (a prompt, out of Combat Mode only);
  - naming a Suspected subject (a wrong name locks the record for 10 min);
  - evidence links, shown as leads, not proof.
- **Storage:** records are keyed by a random `CharacterId`, with no account data. Limits: 40 records, 4 encounters and 3 links per record.
- **The combat log** shows the journal label ("Subject 03") instead of the other player's Roblox name.
- **Tab redesign:**
  - the list is grouped by stage (Suspected first);
  - each record has a 4-step stage track and a gold "Next:" line saying what moves it on;
  - sections: Confirmed, Seen, Leads (not proof), Encounters, and Name them (with the lock warning).

### Forgotten Sites + Halvard's Adit (Tier I)
- **Framework:**
  - `RenseiArea` + `ForgottenSite`;
  - quest `StartOnVisit`;
  - `QuestService.Grant`;
  - `PuzzleService` prompt kinds `Toggle` (sluices) and `Reward` (a one-time, server-checked cache);
  - `PuzzleClient` drawings `Valve` and `Water` (the water freezes when Frozen).
- **The site:** `Workspace.World.Map.HalvardsAdit`, behind Lindenmoor's east ridge. The route:
  1. boarded mouth;
  2. winch (Pressure Board) and lift;
  3. sump: drain it with the sluices (N shut, M open, S shut, per the shift chart) or freeze it with Ice;
  4. two Adit Scavengers;
  5. desk and tool rack;
  6. assay ring (Array Restoration);
  7. vault and ledger;
  8. optional: cracked wall and hidden strongbox.
- **Tested end to end:** +$180 and +775 EXP; the cache pays once.
- **Dungeon respawn:** `TuningConfig.DungeonRespawn = {Time = 900, ClearRadius = 80}` (PROPOSAL). Dungeon enemies come back after 15 min, and only once nobody is within 80 studs.
- **Fixes found in testing:**
  - the mouth's inspect prompt was out of reach (it now uses an `InspectAnchor`);
  - the boards blocked the mouth and the terrain floor sat too high (re-carved; the loose planks are non-collidable);
  - the splash VFX was oversized;
  - prompts fired from attack clicks (`PromptUI` now ignores clicks in Combat Mode).

### Directional climbing
- **Animations:** the sheet's Climb Right (130050644596516), Climb Left (106220254643862) and Climb Down (107192077286134) are in `Assets.Animations.Climb` and loop at a stride matched to the climb speed.
- **Climb speeds** (`TuningConfig.Parkour`): down 7 and sideways 6 (PROPOSAL). Diagonals run sideways at ×0.7.
- **Wall checks:** wall probes stop you climbing off an edge sideways. Climbing is still server-validated, so it needs a wall the server can see.
- Same code in the Tutorial place.

### Boss health bar
- **Who gets it:** enemies with `Boss = true` (every trial foe; `BossName` and `Title` are split from "Name, Title").
- **What it shows:** a large bar at the top of the screen with the name, the title and the health (the HP label is now on top).
- **Combat log:** moves below the bar (the `BossBarBottom` attribute).

### Speed vs animation audit (see also the separate speed entry below)
- **Bug: walk speed flipped between the base and 16.** WCS's built-in default walk speed (16) replaced Rensei's base whenever a status effect ended.
  - **Fix:** `CharacterHandler` sets the WCS default props to the StarterCharacter's walk speed × `SpeedMultiplier`, so it follows the base the owner set (now **16**, see the speed entry below).
  - `EnemyService` does the same with each enemy's own walk speed.
- **Bug: sprint never played the run.** WalkSpeed is a 32-bit float, so the exact `==` check in `Run` failed for anyone with Speed points.
  - **Fix:** `Run` compares with a tolerance (`Same`).
- **New `LocomotionSync`:** scales the walk and run animations to the character's real speed against the speed each was designed for (`TuningConfig.Locomotion`, clamped 0.5–1.6). Enemy walks scale the same way.
  - Measured at the old base of 12: walk 1.01, run 1.02, speedy run 1.01. At the new base of 16 the walk plays at 1.33× (see the note in the speed entry below).
- **Superseded:** my recommendation to slow attack, block and heavy movement (they were faster than a 12 walk) no longer applies at the 16 base.

### Owner assets, guns, tutorial
- **Gun assets and animations:**
  - gun muzzle VFX from "ASSETS TO EXPORT";
  - the guns' walk, whip M1 1–4 and grip / gripped animations from the sheet;
  - Greatsword Idle got its sheet id.
- **Field Notes:** 7 one-time hint cards (`Rensei.FieldNotes`, `FieldNotesUI`, `Requests.Hint`, saved in `Flow.Hints`). They cover inspect, the journal, mechanisms, identities, sites, bosses and Mastery.
- **Tutorial:** the Wall beat teaches climbing up, down and sideways.
- **Unused assets:** Windup, WindStep, Icechainfx, IceEruption and Pale Assassin Cloak (no system yet).

### Exported
34 scripts are mirrored to `Scripts/`, checked chunk by chunk against Studio (FNV-1a hashes). The Tutorial's script edits are described above but not mirrored.

## 2026-10-18 — Speed balancing and animations: audit and fixes

**Owner:** "audit speed balancing and how they affect animations", then "set the base walk speed to 16, fade attack animations out when the attack ends, and scale the run/sprint and enemy walk animations by speed. Leave the per-attack dead-time tuning for later."

The full audit (every walk-speed writer, the walk / run / enemy playback rules, and all 86 attack animations measured against their attack's real timing) is `Documents/Audit - Speed Balancing and Animations 2026-10-18.md`.

### Applied

| Fix | What changed | Tested (Rensei Play) |
|---|---|---|
| **A. Base walk speed 16** | `StarterCharacter.Humanoid.WalkSpeed` 12 → **16** (every walk-speed writer reads it). `StarterPlayer.CharacterWalkSpeed` 20 → 16, so the unused value matches. Steady Array's full-speed casting now uses the base instead of a hard-coded 12 (`AlchemyService`) | client **16 at spawn, still 16 after a run** (was 16 → 12); server 16 |
| **E1. Attack animations end with the attack** | `AttackRunner.Finish` stops the attack's animation (Roblox's short default fade) on every outcome, not only Interrupted / Feinted. It skips this if a newer attack already took over the character, so strings and chains keep their own animation | a 4.2 s animation (WHERE YOU GOING?!) run as a 0.7 s attack **stopped at 0.65 s** (it used to play to 4.2 s); a 3-hit fist string played and stopped normally |
| **C / D. Run, sprint and enemy walk follow speed** | **Already in place, done by another change made in Studio during this session** (not by this one): `Managers.LocomotionSync` (player walk and run tracks follow real ground speed against `TuningConfig.Locomotion.Design`), and `EnemyService`'s `WalkRate` (enemy walk = walk speed / 12, clamped 0.5–1.6). Nothing was duplicated | walking at 16: walk track **1.33×**; running at 24: Run **~1.0×**; sprinting at 30: SpeedyRun **1.0×** |

- **Errors / profile:** 0 client or server errors; the profile was snapshotted and restored.
- **Backup:** `RenseiBackups["Pre-SpeedFix_2026-10-18"]` holds AttackRunner and AlchemyService. Its README has the undo steps, including putting the two StarterPlayer values back.
- **Note for the owner:** `Locomotion.Design.Walk / WalkAnim = 12` says the walk animation looks right at 12. At the new 16 base it plays at 1.33×. If the walk looks hurried, raise those two values toward 14.5–16 (one line in `TuningConfig`).
- **Still open:** the per-attack dead time (E2; deferred by the owner) and a cast / crouch walk (B).

## 2026-10-18 — Journal Evidence / Case Board and Class Skill UI revamp

**Owner (2026-10-18):** the pasted "RENSEI — JOURNAL INVESTIGATION UI + CLASS SKILL UI REVAMP" prompt.
- Audit first and reuse existing assets.
- Evidence becomes a list plus a detail panel.
- The Case Board gets clue cards, real connections and a server-validated deduction panel.
- The Class Skill section gets a real revamp.
- Both must work on mobile and desktop.

> **Status: built and tested in Studio Play** (Rensei, one client, desktop, plus the Journal's narrow / phone layout forced on).
> - The profile was snapshotted first and restored after every session.
> - **No server script, remote or data format was changed.** This is UI only.

### 1. Audit findings (before)

**Journal** (`ReplicatedStorage.Modules.UI.JournalUI`, J)
- **Built with `MenuKit`**, which clones the Settings panel: its frame, header plate, tab art, row plates, the Enable / Disable buttons and the key-bind box.
- **Opening and tabs:** it opens through `UIState.RegisterMenu`, and rows pop in through UIMotion.
- **Evidence tab:**
  - one long column, grouped by case;
  - each clue took a title row plus a paragraph row;
  - no selection, no source, no count, no "new" marker.
- **Case Board:**
  - a column per case;
  - each line had a `<` `>` cycler through *every* clue held;
  - answers were checked by the server (`InvestigationService.Deduce` through `Requests.Investigation`).
- **Identities tab** (2026-10-18) already had a two-column list / record layout, with a phone fallback (list, then record with Back).

**Data**
- **Evidence** (`Rensei.Evidence`) has a title, text, quest, an optional Research flag and an optional Technique.
- **When a clue was found:** `Story.Evidence[id]` holds that time.
- **Where a clue came from** isn't stored, but every source is in shared content:
  - inspect points (`Investigation.Inspects`);
  - minigames;
  - puzzles;
  - dialogue `GiveEvidence` actions.
- **Case Board cases** (`Investigation.Deductions`) have a title, question, lines (Label plus answer evidence), a conclusion and a wrong-answer line.

**Class skills** (`MasteryUI`, K → CLASS)
- **Layout:** six narrow columns of small "I" squares.
- **Text:** 10–11 px labels, and every skill read just "LOCKED" with no reason.
- **The card** on the right already had what matters: the details, requirements, Learn and Equip 1–4.
- **Data and rules:** `Rensei.ClassSkills` and `Rensei.SkillTree` (16 skills across 6 families).
- **Server:** `SkillTreeService` decides buy, equip and unequip.

### 2. Asset reuse

| Use | Existing asset |
|---|---|
| Journal frame, header, tabs, row plates, buttons, value boxes | the Settings panel art via `MenuKit` (unchanged) |
| Two-column layout and phone fallback | the Identities tab's split layout, now shared by Evidence and the Case Board |
| Clue cards | the Stats panel's ornate header plate (`Uis.Stats.MainFrame.Left.Head`) |
| Pinned-line badge on a card, "NEW", "SOLVED", the clue count | the key-bind box (`MenuKit` BoxProto) |
| Threads between cards and lines | rotated 1–2 px lines, the same technique `MasteryUI` uses for its tree links |
| Class family tabs | the Inventory's category tab art, the same art the Mastery menu's own tabs use |
| Class loadout slots | the hotbar's slot plate (`Uis.HUD.Bottom` slots) |
| Skill rows, tier marks, state colours | the Mastery menu's own Guide-row style and its node style (rounded square, gold stroke, tier numeral) |
| Learn / Refund / Equip | unchanged (the card) |

**No new images, textures or icons were added.** Evidence and class skills have no icons in the project, so none are shown rather than invented.

### 3. Files changed

- **`ReplicatedStorage.Modules.UI.JournalUI`:**
  - new Evidence ledger and Case Board (the section above `Draw.Identities`);
  - the split layout is now shared;
  - "new clue" tracking and the tab badge.
- **`ReplicatedStorage.Modules.UI.MasteryUI`:**
  - the new `DrawClass`;
  - a `ClassSkills` list container;
  - row highlight in `Refresh`;
  - `ShowTree` handles the Class list;
  - a new line under the tabs ("Fighting as …").
- **Backup:** `ServerStorage.RenseiBackups["Pre-JournalClassUI_2026-10-18"]` holds JournalUI, MasteryUI and MenuKit as they were. To undo, put them back. (MenuKit wasn't changed in the end.)

### 4. Evidence (an investigator's ledger)

- **Layout:** the clue list on the left, the selected clue's record on the right (desktop, 1000 px wide or more).
- **The list:**
  - the count ("6 clues collected");
  - clues grouped under their case;
  - the selected clue gets a gold title, a warmer plate and a gold edge bar.
- **NEW marker:** a clue picked up during this session shows **NEW** until you look at it, and the tab reads **Evidence (n)**. Clues you already held when you joined count as seen.
- **The record:**
  - name;
  - Clue or Research note;
  - "Found N min ago";
  - the clue's own text;
  - **Source**, read from the content that actually gives it, for example "Examined: Reagent Shelf, Burned Laboratory". The area is added only when the compass list places the inspect point inside one;
  - **Case**, plus each Case Board case of that investigation, with a **Case Board** button that opens it;
  - once solved, "[confirmed] It helped prove: …" if this clue was one of the answers;
  - any **Player Identities** link, labelled as a lead, not proof.
- **Nothing is invented:** a missing source or link is simply left out. Evidence tracking / marking doesn't exist in the game, so there is no button for it.
- **Phone layout:** the list, then the record with a **< Back** row.

### 5. Case Board (a structured deduction workspace)

- **Layout:** the case list on the left (solved cases sink to the bottom, marked "(solved)"). The board on the right shows:
  - the case title and clue count;
  - the question;
  - **clue cards**: every clue you hold from that investigation, so the board never hints which ones matter;
  - the case's **lines** (from its data);
  - **threads** from each pinned card down to its line.
- **Interaction:**
  - pick a line, then the card that answers it, or a card, then a line;
  - the next empty line activates by itself;
  - **X** unpins;
  - tapping a card without an active line shows its text under the board ("inspect without pinning").
- **Submit:**
  - it's dimmed and explains itself ("Pin a clue to every line first.") until every line has a clue;
  - it sends the pins through the existing `Requests.Investigation "Deduce"`;
  - **the server decides**, with no client-side success state.
- **Results:**
  - a wrong answer shows the case's own wrong line in red;
  - a right answer arrives with the profile sync, and the board turns solved: solid gold threads, the proved answers and the conclusion.
- **Connections are only what the system supports:**
  - before solving, threads show *your* pins (thin);
  - after solving, they show the proved answers (solid).
  - Nothing links two clues just because they're near each other.
- **Any case works**, from `Investigation.Deductions`; nothing is hard-coded to the Foundry Yard. Tested on two cases: *The Laboratory Fire* and *Who Drew the Circles*.
- **Phone layout:** the case list, then the board with a **< Cases** row. The cards use 3 columns when there's room, else 2.

### 6. Class Skill

- **Family tabs:** on the Inventory tab art, with a small gold mark under the class you fight as. The tab opens on that class.
- **Loadout strip:** the family's 4 keys on the hotbar slot art. A filled slot shows the skill and selects it.
- **One row per skill**, in tier order:
  - its tier mark (filled gold once learned);
  - name;
  - "Tier · MP · cooldown · stamina · after <prerequisite>" (all from `ClassSkills.Def` / `SkillTree`);
  - a **state line** with the real reason: "Needs 2 MP (you have 0).", "Needs Level 5", "Needs Bullet Slash or Blood Dash", "Ready to learn for 3 MP.", "On key 1.";
  - a status word (SLOT n / LEARNED / LEARNABLE / LOCKED, from the same `Refresh` verdicts as before);
  - a short gold thread to the row above when that row is its prerequisite.
- **The selected row is lit.** The card on the right is unchanged: details, requirement checklist, cooldown / stamina / hits, and the Learn, Refund and Equip 1–4 buttons, all decided by `SkillTreeService`.

### 7. Compatibility (preserved)

- Quests, Codex and Identities tabs, and Journal open / close.
- Track and Abandon, Identify, and the deduction remote.
- `Story.Evidence` / `Story.Deductions` formats.
- Rewards and quest progression through QuestService.
- Skill data, `SkillTree` / `ClassSkills` rules, the Buy / Refund / Equip / Unequip requests, loadout saves, the style picker, the circle tabs and the Guide.

### 8. Testing

**Performed (Rensei Play, desktop 1644 × 852):**

| Test | Result |
|---|---|
| Evidence, 6 clues in 2 cases | list grouped by case, count, NEW on all 6, tab "Evidence (5)" after one was opened; record shows type, found time, text, source "Examined: Reagent Shelf, Burned Laboratory", case and Case Board link |
| Case Board, *The Laboratory Fire* | 3 cards; pinning a card fills the active line, moves to the next, tints the card, adds a "1" badge and draws the thread |
| Wrong answer submitted | **server refused** (case not solved); the case's wrong line shown in red |
| Right answer submitted | **server solved it** (`Story.Deductions.lab_fire_cause` set); the quest **advanced to stage 3** ("Run the reaction chamber" on the HUD); board turned solved with solid threads and the conclusion |
| Evidence → "Case Board" button | opened that case's board |
| Forced phone layout (Journal `ForceNarrow`) | Evidence list → record with < Back; Case Board → board with < Cases, 3 card columns |
| Identities and Quests tabs after the change | Identities split works; Quests back to the single column |
| Class tab | family tabs, loadout strip, 5 Fists rows with correct reasons |
| Learn (5 test MP) | Spin Kick learned (MP 5 → 3); Bear Hug turned LEARNABLE; 540 Kick "Needs Level 5" |
| Equip to key 1 | loadout slot 1 "Spin Kick"; row "SLOT 1 · On key 1." |
| Family tab switch (Daggers) | 4 skills, threads between prerequisite rows, tier II mark, "Needs Bullet Slash or Blood Dash" |
| Errors | 0 client and 0 server game errors or warnings |
| Profile | restored after each session (test quests, evidence, deduction, MP, learned skill and loadout removed) |

**Fixed during testing:**
- the case lines inherited the journal rows' centred anchor and sat half off the board;
- the case list was too cramped for a status label (the count moved onto the board);
- long line labels overlapped their box, then shrank too small (they now wrap to two lines);
- the MP-only lock reason showed just "Locked.".

**Not tested (needs a device or more players):**
- **A real phone or tablet.** The Journal's phone layout was forced on a desktop. The Mastery menu's Class list wasn't seen at phone size: its rows are 62 px and it scrolls, but its panel follows the Inventory's size.
- **Two players.**
- **The Dialogue / Minigame / Puzzle evidence sources:** the mapping is code-checked, but only inspect-point sources were seen.
- **A Player Identities link line:** no test record had one.

### 9. Remaining issues / notes

- **No evidence or class-skill icons exist** in the project, so none are shown. If the owner adds icons (an `Icon` field on evidence or skills), the cards and rows have room for them.
- **"NEW" lasts one session.** It isn't saved, because adding a profile field would change the save format, which the brief said to avoid.
- **The Case Board's free dragging** wasn't built: the brief allowed a structured layout instead, and it avoids scaling and input problems on touch.

## 2026-10-18 — Minimal top-of-screen compass

**Owner (2026-10-18):** "a minimal directional compass on the top of the screen (the combat log would be slightly under it, but not overlapping or clipping) that subtly shows players where their areas of interests are… don't make it clutter".

> **Status: built and tested in Studio Play** (Rensei, one client, desktop). The profile was snapshotted and restored. Ranges and sizes are PROPOSAL.

### What you see

- **A thin strip at the top centre** (34 % of the screen width, 220–360 px).
  - **Markings:** tick marks every 15° and the letters N / E / S / W, with N in gold.
  - **Backing:** a soft dark band behind the strip keeps it readable against a bright sky.
  - **Edges:** both ends fade out, so it never reads as a box.
  - **Centre:** a small gold notch marks your heading. North is world −Z.
- **At most three marks:**

  | Mark | Means | Notes |
  |---|---|---|
  | **Gold diamond** | the nearest unfinished objective of your **tracked quest** (the Journal's tracked quest, or else the oldest active one) | When it's behind you, it stays **pinned to the strip's edge**, smaller, so you always know which way to turn |
  | **Faint ring** (up to 2) | the nearest **areas you haven't discovered**, within 320 studs of their edge | Their names stay hidden ("Unexplored") until the discovery popup reveals them |

- **Label:** a name and distance (e.g. "Reagent Shelf · 655") fade in under the strip, but only for the mark nearest the centre of your view, within 9°.
- **Combat log:** the badge now drops in just under the compass (top 42 instead of 12). If the compass is off, it goes back to the very top.
- **Hidden** during full-screen menus, dialogue, cutscenes and death.
- **Settings:** new **Gameplay → Compass** toggle (on by default; saved and validated like the others).

### How objectives are found

- **Each kind of objective points at the place that completes it:**

  | Objective | Points at |
  |---|---|
  | Visit | the area |
  | Talk | the NPC with that dialogue |
  | Evidence | the inspect point that gives that evidence (`Investigation.Inspects[..].Evidence`) |
  | Mechanism / Puzzle | the puzzle's mechanisms |
  | Trial flag | the trial marker |
  | Minigame | the station |
  | Defeat | the enemy spawn whose enemy has that name |

- **Journal-only steps** (Deduce, Signal): the mark points to the quest's home area (its first Visit), unless you're already in it.

### How it works

- **New `ServerScriptService.CompassService`** publishes the place list to `ReplicatedStorage.CompassPoints`. It rebuilds every 30 s and updates in place.
  - **Why the server builds it:** the place streams, so a client can't see far-off parts itself.
  - **What's in it:** 84 points today (14 areas, 13 NPCs, 27 inspect points, 13 mechanisms, 5 trials, 2 stations, 10 enemy spawns).
  - **Nothing secret:** every point is a visible place in the world. Which points matter to *you* is decided on your client from your own profile copy.
- **New `ReplicatedStorage.Modules.UI.CompassUI`**, started by `UIHandler`:
  - picks its targets twice a second;
  - draws every frame;
  - each step is wrapped in pcall, so an error hides the compass instead of breaking the HUD.

### Tested (Rensei Play)

| Test | Result |
|---|---|
| Points published | 84, all seven kinds |
| Facing north in Lindenmoor (no quest) | rings for the two undiscovered areas in range, at the right bearings: **Cypress Ridge** −20° (due north), **Bramble Hollow** +27° (true bearing 47°, camera heading 19°) |
| Ring near the centre | label **"Unexplored · 276"** |
| Quest started for the test (*The Unburned Lesson*, stage 2: find evidence) | **gold diamond pinned at the right edge** while facing away; facing the lab, it was **centred with "Reagent Shelf · 655"**, the nearest evidence inspect point |
| In combat | the badge dropped in **under** the compass (top 42): no overlap or clipping (screenshot checked) |
| Settings open | the compass faded out |
| Settings → Compass → Disable | compass hidden; combat log back at top 12; the setting **saved through the server's validation** |
| Readability | first version too faint on the overcast sky; fixed with the dark band and stronger outlines (screenshot checked) |
| Errors | 0 game errors |
| Profile | restored (test quests and the setting removed) |

### Also fixed (found while testing)

- **Settings rows had uneven heights.** The **Combat Log** row (added 2026-10-15) and the **Aim (Guns)** row (added 2026-10-17) were drawn smaller than the authored rows, about 65 % and 60 % height. Weapon Skill was slightly short too.
  - All are now the standard row height, along with the new Compass row.

### Files and backup

- **New:** `ServerScriptService.CompassService`, `ReplicatedStorage.Modules.UI.CompassUI`, the Settings row `StarterGui.Uis.Settings.MainFrame.Container.Compass`.
- **Changed:**
  - `CombatLogUI` (`TopY`: under the compass, or at the top without it);
  - `Rensei.Settings` (`Compass` default and toggle);
  - `SettingsUI` (sets the `ShowCompass` attribute);
  - `UIHandler` (starts CompassUI);
  - `ServerHandler` (starts CompassService);
  - the Combat Log / Aim / Weapon Skill row sizes.
- **Backup:** `ServerStorage.RenseiBackups["Pre-Compass_2026-10-18"]` holds the five scripts as they were, plus a README with the undo steps.

### Not tested

- **A real phone or tablet.** The width clamps to 220 px on narrow screens, and Roblox's top bar on mobile has buttons at the corners, so the centre should stay free. Not seen on a device.
- **The Talk, Defeat, Mechanism / Puzzle, Trial and Minigame mappings.** They are code-checked against the data, but only the Evidence and Visit kinds were run.
- **Two players.**

### Open (owner)

- Whether discovered areas should ever show (e.g. a faint mark for the area you're heading back to).
- The 320-stud range for unexplored areas, and the 150° span.
- An optional custom icon set (a quest sigil, an area glyph) in place of the plain diamond and ring.

## 2026-10-18 — Coordinated enemy squads ("Advanced Swarm NPC Combat AI")

**Owner (2026-10-18):** the pasted "RENSEI — ADVANCED SWARM NPC COMBAT AI" prompt: Archived / VV Ultimatum-style squads. One enemy attacks a player at a time; the rest surround and wait their turn, with clean handoffs.

> **Status: built and tested in Studio Play** (Rensei, one client). The profile was snapshotted first and restored after every session. Every number is PROPOSAL (`TuningConfig.Squad`).

### Audit (before the change)

- **How enemies worked:** each enemy ran its own brain in `EnemyService` (every 0.1 s: pick the nearest player, chase, attack or cast). Nothing coordinated them.
- **The result:**
  - a crowd all swung at once;
  - they stacked on the same spot;
  - a target could flicker between two players at nearly the same distance.
- **What was already in place:**
  - enemies couldn't hurt each other (a `DamageManager` check);
  - `AttackRunner` already knew whether a rig was mid-attack.
- **The single hit path:** every melee, weapon and alchemy hit reaches a victim through one function, `DamageManager(Character, Victim, SkillInfo)`. That made it the right place for a hard "only one attacker" rule.

### How it works

**New `ServerScriptService.CombatDirector`** (ModuleScript, about 520 lines; started from `ServerHandler`).

- **Encounters:** one per targeted player. An enemy belongs to the encounter of its current target, which the brain reports every tick.
  - An encounter dissolves when the player dies, is knocked, leaves, or walks out of every member's leash.
- **The attack token:** each encounter has at most **one holder**. Only the holder starts attacks or casts.
  - **It's enforced at the hit as well:** `DamageManager` drops any enemy hit on a player whose token that enemy doesn't hold (returns "IFramed"). Late hitboxes, projectiles, traps and explosions are covered too, so there's never a hidden second attacker.
  - **Exceptions:**
    - a 0.25 s **Grace** after a normal end of turn (so the last swing isn't cut off);
    - **reactive counters** the player triggered (a Cryo Shift riposte);
    - a cast's projectile may land up to **1.4 s** after the cast (`CastLinger`).
- **Atomic changes:** a grant or release never yields, so two enemies can never both hold the token.
- **Handoffs:**

  | Cause | Kind |
  |---|---|
  | Death or despawn | forced |
  | Knocked, gripped or carried | forced |
  | Knockback of 45 or more | forced |
  | Stunned for 0.8 s or longer (parry, guard break, long hitstun) | forced |
  | Separated (beyond reach + 9 studs for 2.5 s: stuck or knocked away) | forced |
  | Swimming or passive | forced |
  | Turn over: 9 s × personality, only between attacks and only if someone else is ready | normal |

  - **After a forced release** the old holder gets no grace and sits out 1.2 s (`Recover`).
  - **The next holder** is chosen 0.2 s later, once the old holder's `AttackRunner` has stopped, so attacks never overlap. It then waits 0.35 s (`CommitDelay`) before striking. That beat is the player's read.
- **Who goes next (score; lowest wins):**
  - distance beyond its own waiting ring;
  - plus its personality's bias;
  - plus 5 if it's behind the player (no free back-stabs);
  - plus 6 if it had a turn in the last 4 s;
  - minus 0.6 per second since its last turn, up to 20 s.

  The last term, fairness, was added during testing (see below) so brawlers and casters alternate.
- **Personalities** (by enemy type):

  | Personality | Enemy types | Behaviour |
  |---|---|---|
  | Aggressor | Bandit, Adit Scavenger | eager |
  | Duelist | Bandit Duelist | |
  | Alchemist | Field, Frost, Gale and Stone Alchemists | ranged, wider ring |
  | Defender | Ward Alchemist | patient |
  | Gunner | gun bandits | ranged |

- **Waiting members' positions:**
  - **Ring slots:** every 0.45 s each waiting member gets a slot on a ring around the player: 8.5 studs for melee, 16+ for ranged. Slots sit at angles relative to the holder (70°, −70°, 125°, …), never in its lane, and drift slowly so the ring circles.
  - **Prepare:** the most likely next attacker gets the closer **Prepare** spot (6.5 studs, ±45°).
  - **Reachable:** slots are pulled in front of walls (raycast) and must have ground under them.
  - **No jitter:** a member keeps its slot unless another is 25° better.
  - **Reserve:** more than 8 members wait on an outer Reserve ring.
  - Waiting members walk to their slot, then stand and face the player.
- **Targets don't flicker:** `PickTarget` keeps the current player unless another is at least 8 studs closer (`TargetSwitchMargin`).
- **Several players:** each player has their own encounter and token. So two players near the same group each face one attacker at a time, and an enemy can't be in two encounters.
- **Debug (Studio only):** set the workspace attribute `SquadDebug = true` (or `TuningConfig.Squad.Debug`).
  - Neon markers show the slots.
  - A label over each member shows its slot number, its role, and why it last gained or lost the token.
  - Every member always carries the attributes `SquadEncounter`, `SquadRole`, `SquadReason` and `SquadPersonality`.

### Tested (Rensei Play, one client)

**Setup:** the player was anchored at a test spot with 50,000 HP, and every world enemy was set passive. Squads were spawned from a persistent test script.

| Test | Result |
|---|---|
| 4 Bandits (fists), 15 s | **at most 1 attacking at any moment** (0 samples with 2+); 16 hits on the player, all by the token holder at the time; 0 blocked, 0 conflicts. Roles Attacker / Prepare / Flank; one Turn-over handoff at 8.6 s, with the new attacker in 0.2 s. Waiting members walked 18–32 studs to their slots |
| Gate | a non-holder's hit → **"IFramed"**, no damage; the holder's hit → "Hit", 1 damage |
| Knockback 75 on the holder | released at once; the next attacker took the token after **0.23 s**; the knocked-back bandit's hits are refused |
| Knockback 20 (below 45) | holder **kept** the token |
| 1.5 s stun on the holder | released after **1.03 s** (0.8 s threshold + tick); the next took it at 1.23 s |
| Holder killed | released at once; next attacker after **0.30 s**; the dead one left the encounter |
| Holder destroyed (despawn) | released at once; next after **0.30 s**; 2 members left |
| Player teleported 220 studs away | token released in 0.1 s, **encounter dissolved**; back in range → a new attacker in 0.2 s |
| Mixed squad: 3 alchemists + 2 Bandits, first version | **found a problem:** in 20 s only the two Bandits took turns. Alchemists waiting at 15 studs always lost to Bandits at 6. |
| After the first fix (distance counted beyond each member's own ring) | the opposite: only alchemists took turns. Fixed with the fairness credit and by measuring melee members from their ring too |
| Mixed squad, final version, 40 s | **turns rotate: Bandit → Field Alchemist → Bandit → Bandit → Field Alchemist.** Each hit was by the holder; max 1 attacking; 0 conflicts. Alchemists wait at about 15 studs, Bandits at 7–8 |
| Debug view | slot markers and role labels appear |
| Errors / profile | 0 errors from the new code; profile restored to the snapshot |

Release reasons logged across the sessions: Turn over 27, Knockback 2, Stunned 2, Died 2 (+1 "Dead", the same thing seen from the tick), Removed 3, Lost target 3, Separated 1.

### Files and backup

- **New:** `ServerScriptService.CombatDirector`.
- **Changed:**
  - `EnemyService`:
    - registers each rig and reports its target;
    - only attacks or casts while holding the token, and stops a string if the token moves on;
    - waiting members walk to their slot;
    - `PickTarget` hysteresis.
  - `DamageManager`: the token gate; knockback and downslam tell the director; reactive counters are allowed.
  - `TuningConfig.Squad` (new block).
  - `ServerHandler` (starts the director).
- **Backup:** `ServerStorage.RenseiBackups["Pre-SwarmAI_2026-10-18"]` (EnemyService, DamageManager, TuningConfig, ServerHandler as they were). **To undo:**
  - restore those four;
  - delete `CombatDirector`.
- **Switch-off without undoing:** `TuningConfig.Squad.Enabled = false`.

### Not tested / limitations

- **Two real players** (one client only). The per-player encounters are code-checked, and the target-loss test covers the switch.
- **A real fight with a moving player:** the player was anchored. The handoffs were triggered directly (a `DamageManager` knockback, a Stun status, Health = 0, Destroy, teleport), not by real key presses.
- **Gun bandits and the Bandit Duelist's block / parry** in a squad: these run through the same gates but weren't run.
- **Spacing:** two bandits came within 1.9 studs of each other once, while one walked past another to its slot. Slots are spaced, but the walk paths aren't.
- **No new animations:** waiting members use the existing walk and idle. Taunts, a "readying" stance or circling strafe animations would make the waiting read better; none exist yet, and no IDs were invented.
- **Performance** wasn't profiled. The director ticks every 0.2 s with work proportional to the members, and slots every 0.45 s with one wall and one ground raycast per member.

### Open (owner)

- Feel: the turn length (9 s), the 0.35 s beat before a new attacker strikes, and the ring sizes, all in `TuningConfig.Squad`.
- Whether bosses or elites should ignore the token (e.g. a boss plus adds).
- Optional waiting-stance animations (see above).
## 2026-10-18 — Weapon hand-placement audit; katana swings fixed

**Owner:** "completely audit and go through all hand placements for all weapons for everything, idles, runs, m1s, crits, etc."

> **Status: audited in Studio Play** (all 9 weapon tools: every draw, hold, idle, walk, run, carry, M1, shot, crit, skill and dash animation). **The katana is fixed and checked on the real character.** The other weapons are documented with measurements and wait on the animator's rigs. Backup: `ServerStorage.RenseiBackups["Pre-WeaponGrips_2026-10-18"]` (the Katana tool and the four Sword animations).

### Method
Test rigs (copies of the player character) with each tool attached exactly as `WeaponManager` does. Each animation was sampled at 11–13 points, measuring three things:
- whether the hand stays on the grip;
- whether the visible weapon passes through the torso, head or legs;
- where the blade tip is at the hit frame.

The bone names each animation moves were read from its keyframes. Screenshots compared current vs converted versions.

### Findings
- **The weapon never leaves the hand.** In every animation, the hand-to-grip offset is constant: 0.46 studs for the swords, 0.31 for the greatsword, 0.21 for the daggers, 0 for the guns. The one exception is the dagger draw, which pulls the blade from the back.
- **But most sheet animations' weapon motion was ignored.** They were made on the animator's rig, whose weapon bone is `Hilt` / `Hilt2`. Ours are `Ninjato` / `Greatsword` / `Dagger` / `Right Hand`, so the weapon stayed frozen in its hold pose while the arm swung. The katana's M1 2 cut back across its own face.
- Full table: `Animations.md`, "Weapon bones and hand placement".

### Fixed: katana
- The Katana's grip part is renamed `Hilt` with the animator's joint (`MotorC0` (0, −0.65, 0); `MotorC1` chosen so the rest pose is exactly the same). The published M1 1–4 now move the sword as authored, **in a live server too** once the place is published.
- The four Studio saves that animate the old bone (`Sword_Hold`, `Sword_Heavy`, `Sword_Idle`, `Sword_Run`) got matching `Hilt` poses. The Rapier still uses `Ninjato` and the same Hold, so it's unchanged.
- **Measured:** the swings no longer pass through the body (M1 2: 1 frame → 0; M1 4: 2 → 0), and M1 3's blade points 5.3 studs forward at the hit (2.5 before).
- **Checked:** M1 1 frozen at its hit frame on the real character (given the katana with `WeaponManager.Give`, nothing saved), with the hilt in the fist and the blade along the cut.

### Not changed (needs the animator's rigs)
- **Rapier:** its M1s use a separate root bone (`Handle`), and its idle / walk were made on a pistol rig. M1 2 clips the head.
- **Greatsword:** converting the tracks made it worse.
- **Daggers:** the animator's mount is flipped about 175° from ours.
- **Pistols:** shots move `PistolHandleR`.

### Other measurements
- **Caestus:** the gauntlet collision boxes touch the head / torso in the guard poses (the gloves are on the fists near the face; nothing visibly wrong).
- **Pistols:** the whip's 4th hit (FistCombo5) brushes the left leg.
## 2026-10-18 — NPC idles: every NPC posed, and why none were moving before

**Owner:** "Go through the spreadsheet and use the NPC Idle anims to add idles to all NPC's, trainers, etc." and "Check if the animations actually work in game".

> **Status: fixed and checked in Studio Play** (Rensei): all 13 NPCs are posed and moving on the client, with screenshots of the trainers and the Foundry Yard. The Tutorial's Drillmaster got the same fix. Backups: `ServerStorage.RenseiBackups["Pre-NpcIdles_2026-10-18"]` in both places (the script, every touched NPC, and their previous `IdleAnim` values as an attribute).

### What was wrong (found by testing in game)
The 10-16 idles were "playing" on the server, but no NPC visibly moved. Three separate causes:
1. **Every NPC part was anchored.** Roblox doesn't animate anchored parts.
2. **The joints had a pose baked into them.** All the NPCs except Drillmaster Vask and Placeholder NPC had non-standard Motor6D offsets (the same baked pose, copied between them). The Tutorial's Drillmaster had them too. Animations are made for the standard R6 joints, so once freed these NPCs crumpled to the floor.
3. **The seven trainers' joints belonged to Lise.** All five alchemy trainers and both style trainers had Motor6Ds whose limbs pointed at **Lise's** arms, legs and head (they were copied from her rig). Their own limbs were attached to nothing, and Lise's limbs were tied to seven other bodies.

Also: the style trainers stand in `World.Map.Lindenmoor`, which the old script didn't watch.

### Fixed
- **`ServerScriptService.NpcIdles` (rewritten; same file in Rensei and the Tutorial):** watches every non-player character in Workspace, not only `World.NPCs`, including NPCs added later. When an NPC has an idle, it keeps only the HumanoidRootPart anchored, so the NPC still can't fall or be pushed, and frees the parts jointed to it. Props inside a model that aren't jointed to the body (the trainers' scroll stands) stay anchored.
- **The joints:** the 7 trainers' 42 Motor6Ds now point at their own parts, and every posed NPC's six joints use the standard R6 offsets (copied from `StarterPlayer.StarterCharacter`). Each body was rebuilt around its root, so the edit view matches the game. Feet were checked against the ground, and Coach Harlan and Master Thura were raised 0.5 / 0.41 studs out of the terrain.
- **Registered** the sheet's missing NPC idles: `NPC_Blacksmith` and `NPC_WallCoverLeft` (`Registry.NPCIdles`). The Tutorial got `NPC_CrossArms`.

### The cast (PROPOSAL)
Vask: Cross Arms · Brask: Hand in Pocket · Mirra: Blacksmith · Tobin: Curled Up · Lise: Kneel · Placeholder NPC: Chill · Calda: Chill · Veyra: Transcend · Holt: Low Hand On Ground · Ansel: Tai Chi · Brannoc: Blacksmith · Coach Harlan: Cross Arms · Master Thura: Tai Chi. (Before: Chill / Admire on 11 of them. Admire is a lying-down pose, so Mirra, Lise, Veyra and Ansel would have been lying on the floor.) Details in `Animations.md`.

### Tested (Studio Play, Rensei)
- **Every idle on the sheet, loaded on a rig, server and client:** 14 work. **8 are broken uploads** (length 0): Beg, Prisoner, Sit 3, Sit 4, Sit 5, Sleep 2, Wall Cover Left / Right. All 8 are owned by the group and are Animation assets, so they need re-uploading.
- **All 13 NPCs on the client:** every one is posed (limbs 70–128° from the default pose) and moving.
- **Screenshots:** the five trainers (standing, meditating, hand on the ground, Tai Chi, hammering) and the Foundry Yard (Mirra at the crucible, Brask, Tobin crouched, Lise kneeling).

### Side effects to know
- The emote wheel's **Sit** and **Rest** use Sit 3 and Sleep 2, so they don't play until those are re-uploaded.
- An NPC with no `IdleAnim` keeps its old setup (all parts anchored).

## 2026-10-18 — Store live: Developer Product IDs, Creator Plus as a product, live prices, product art

**Owner (2026-10-18):** created five Developer Products in the Creator Dashboard, all with Managed Pricing on:

| Product | ID | List price |
|---|---|---|
| New Save Slot | 3719583607 | 200 R$ |
| Creator Plus | 3719583889 | 100 R$ |
| Clan Reroll x1 | 3719584065 | 50 R$ |
| Clan Reroll x5 | 3719584366 | 200 R$ |
| Clan Reroll x15 | 3719584544 | 550 R$ |

> **Status: wired and tested in Studio Play** (Main Menu, one client). No purchase was completed and no real account was changed. Backups: `ServerStorage.RenseiBackups["Pre-Products_2026-10-18"]` in all three places.

### IDs
- `Rensei.Slots.ProductId` = 3719583607 in **all three places** (the file must stay identical).
- `Rensei.Clans.RerollPacks` IDs and prices (50 / 200 / 550) in the Main Menu and Rensei. The Tutorial's `Clans` is an older copy with no packs and no store, so it was left alone.
- `Rensei.CreatorPlus.ProductId` = 3719583889 (Main Menu).

### Creator Plus is now a Developer Product
The code expected a Game Pass, and Roblox's Game Pass ownership check can never see a Developer Product, so it's now sold as a one-time product:
- **`SlotAccount.GrantPlus(UserId, PurchaseId)`** (new): sets `Plus = true` on the player's `RenseiAccounts` record with `UpdateAsync`, skipping a receipt it has already seen. It answers "Granted" / "Already", or nil if the store failed.
- **`MenuServer.ProcessReceipt`:** grants Creator Plus **only after the account record is saved**, otherwise it returns `NotProcessedYet` so Roblox retries. Ownership is read from the account (cached by `MenuData`), so it covers every save slot.
- **`SlotAccount` keeps the `Plus` flag** in all three places. Before this, any account write in another place (slot select, favourite, code redeem) would have dropped an unknown field.
- **`MenuClient`:** "GET CREATOR PLUS" prompts the product, refuses if already owned, and after a purchase asks the server until ownership shows (up to 8 s).
- **Game Pass still supported:** setting `CreatorPlus.PassId` makes the pass work too (either one unlocks it). `StudioOwns` now applies only while both IDs are 0, so Studio shows the real locked state.

### Live prices
Managed Pricing means a player can be shown a different price than the list price. In Studio, Roblox reported 160 / 80 / 40 / 160 / 440 R$ for the five products. The reroll buttons and the New Slot card now show the price Roblox reports (`GetProductInfo`), falling back to the config until it answers. The Creator Plus button already did this.

### Tested (Studio Play, Main Menu)
- **The grant logic, against a throwaway account key (`A-9001`, removed afterwards):** the first grant answered "Granted"; the same receipt again answered "Already"; a slot `Select` afterwards kept `Plus = true`. The owner's real account was never written.
- **`GetProductInfo`:** all five IDs resolve to the right names and are for sale.
- **The menu:** the "Plus" call returns `ProductId` 3719583889 and Owned = false; the reroll shop reads 40 / 160 / 440 R$; the New Slot card reads "160 R$"; clicking New Slot opens Roblox's "Buy item: New Save Slot" prompt (closed without buying).
- **Persistence:** all edits were still in place after a Play / Stop cycle. No new console errors.

### Product art
Icons for all five products: `Art/Market Icons/*.png` (512×512). Preview page: https://claude.ai/artifact/4bAXdJMuf2uwLMigW7xSjJ. They aren't uploaded to the products yet (the dashboard shows the default icon).

### Not done / for the owner
- Upload the icons to each product.
- A completed purchase can only be tested by buying in Studio (a test purchase charges nothing but writes to the real account) or live.
- **Reroll packs (pre-existing):** rerolls are added to the open save slot's ProfileService profile and granted at once, before that profile next saves. If the server crashed in between, the rolls could be lost. The ProfileService purchase-id pattern would close that gap; not changed here.
- Only the Main Menu handles receipts. If a purchase isn't granted before the player leaves, Roblox retries the next time they're in the Main Menu.

## 2026-10-18 — Basic swimming (owner decision 6)

**Owner (2026-10-18):** "Add basic swimming: allow deep water with a swim state (no combat or alchemy while swimming)."

> **Status: built and tested in Studio Play** (Rensei, one client, real keyboard and mouse). The profile was snapshotted first and restored exactly afterwards. Numbers, the pond's name, spot and size are PROPOSAL.

### How it works

- **Movement:** Roblox's own terrain-water swimming. You float, swim with WASD, and the speed is your walk speed. There's no drowning or stamina drain ("basic").
- **The game state is server-owned.**
  - **New `ServerScriptService.SwimService`** checks each player every 0.15 s.
  - **What counts as deep water:** the Humanoid is in Roblox's Swimming state, or a terrain-water cell at least 60 % full is at the root or 2 studs below it.
  - **In deep water**, the server puts you in the **Traversal = "Swim"** state. This is the slot `MovementState` already reserved for it, set through the new server-only `MovementState.SetSwim`.
  - **The state ends** after two dry checks in a row, so it doesn't flicker at the surface.
- **No combat or alchemy while swimming.**
  - The Swim state carries the existing `Climbing` status, the same "traversing" gate the ledge walk and wall run use. Every attack, block, alchemy cast, class or weapon skill, shot, sprint, roll and crouch already refuses while it's on.
  - **Entering the water turns Combat Mode off**, so the weapon goes away. `Requests.CombatMode` refuses to turn it back on while swimming.
  - **No climbing or wall running from the water:** a client can't replace or end the server's swim state. You leave by swimming to a bank or into the shallow creek.
  - **A stun doesn't end swimming,** since you're still in the water. Being knocked, gripped or carried, or dying, does.
- **The shallow creek stays wadeable** (about 1.2 deep). It never counts as swimming.
- **Animations** are the owner's own `Swim_Idle` (treading water) and `Swim_Forward` (moving). They were already in `Assets.Animations.Registry.Movement` and were moved to `Shared.Movement.Swim`, so every character preloads them and other players see them. `Swim_Sprint` moved too but isn't used yet.
  - **New `StarterPlayerScripts.SwimClient`** plays them on your own character, above the walk cycle.
- **Tuning:** `TuningConfig.Swim`.

### Deep water in the map: the Mill Pond (PROPOSAL)

- **Where:** a pond on Mill Creek, **west of the stone bridge**, at world (−110, −553). That's on the creek line, clear of houses, roads and the nearest oak.
- **Size:** the flat floor is 11 studs across from the centre, and the banks rise back to the meadow by 19.
- **Depth:**
  - **5.2 studs deep in the middle.** The floor is the baseplate top (y 0), and the water surface is the creek's (y 5.2), so the pond joins the creek.
  - The banks shelve through 4.2, 2.6 and 1.8 to the creek's 1.2.
- **Built by a new map tool, `RenseiMapTools.PondWriter`.** It changes only the voxels within 19 studs.
  - The place uses terrain **shorelines** (one cell holds ground and water), so the tool writes the voxel channels. Plain `WriteVoxels` left the old mud floor in place.
- **`TerrainWriter` now notes** that a full terrain rebuild clears the pond, so `PondWriter.Write()` has to be run again after one.

### Tested (Studio Play, real input)

| Step | Result |
|---|---|
| Combat Mode on (E), then walk (W) off the south bank into the pond | Roblox Swimming state at 0.95 s; at 1.00 s the server set **Traversal = Swim**, the **Climbing status went on** and **Combat Mode went off** (banner "Combat Mode Off") |
| Treading water | **Swim_Idle** plays (Movement priority, above the walk cycle) |
| Swimming forward (W) | **Swim_Forward** plays (the horizontal stroke) |
| E in the water | Combat Mode stayed off |
| M1 clicks in the water | no attack started |
| Alchemy Z and C in the water, **meter filled to 100** | no cast: the meter stayed 100 and no cooldown started |
| Swim east out of the pond into the shallow creek | the swim state ended (Traversal nil, Climbing off, Running) |
| **Control on dry footing (the creek):** E, then Z | Combat Mode on; **Ignite cast** (meter 100 → 75). So the same keys work out of the water |
| Errors | 0 client or server errors |
| Profile | restored; equal to the snapshot (no changed keys) |

### Files and backup

- **New:** `ServerScriptService.SwimService`, `StarterPlayerScripts.SwimClient`, `RenseiMapTools.PondWriter`, the folder `Assets.Animations.Shared.Movement.Swim`.
- **Changed:**
  - `MovementState` (`SetSwim`; Swim survives a stun; a client can't end or replace it);
  - `Requests.CombatMode` (refused while swimming);
  - `TuningConfig` (`Swim`);
  - `ServerHandler` (starts SwimService);
  - `TerrainWriter` (header note);
  - the terrain at the pond.
- **Backup:** `ServerStorage.RenseiBackups["Pre-Swimming_2026-10-18"]`.
  - It holds the five changed scripts as they were, and **`PondSiteTerrain`** (the original terrain there).
  - Its README has the undo steps: paste the terrain back, move the swim animations back to `Registry.Movement`, and delete the new scripts.

### Enemies in deep water (added the same day)

**Owner (2026-10-18):** "enemies in deep water should also be unable to attack or cast, same as players."

- **`SwimService` also checks every live enemy rig** (`EnemyService.Active`), using the same deep-water test. In deep water an enemy gets the same **Traversal = Swim** state and **Climbing** status.
  - `MovementState.SetSwim` now tracks an NPC on its first swim, for the same cleanup on death or removal.
  - `AlchemyService.CastAs` already refuses casts under the Climbing status.
- **`EnemyService`'s brain** doesn't start an attack while its rig is swimming. That covers:
  - melee strings and heavies;
  - gun shots and alchemy casts;
  - the Ward Alchemist's Guard cast;
  - blocks and parries.
  
  A string that's already running stops if the enemy ends up in deep water partway through.
- **Enemies still chase**, swimming after you, and keep their weapon drawn (the brain reads `CombatMode` as "armed"), but they can't use it. On land they fight as before.

**Tested (Studio Play):**
- **Setup:** the player in the pond. For the test only, the enemy's leash home was moved to the pond (it otherwise swims back to its hub spawn); this was undone afterwards.

| Case | Water | Land (control, same enemy, same distance) |
|---|---|---|
| Bandit (Rapier), not passive | in the Swim state, **targeted the player and closed to 3.8 studs, no attack** in 10 s, no damage | **attacked:** Rapier_Light1–4, damage dealt |
| Field Alchemist, not passive, meter 100 | in the Swim state, **no cast, no melee** in 9 s, meter stayed 100 | **cast Scorching Wave (X)**, plus a Light1–3 string |

- 0 client or server errors.
- The profile was restored and is equal to the snapshot.

**Backup:** `RenseiBackups["Pre-EnemySwim_2026-10-18"]` (EnemyService, SwimService and MovementState before this step).

### Swimming extras (added the same day)

**Owner (2026-10-18):** "add swimming extras". The numbers are PROPOSAL (`TuningConfig.Swim`).

| Extra | How it works |
|---|---|
| **Swim sprint** | Hold **Shift** while swimming and moving. The client asks the server (**new `Requests.Swim`**), and the server sets `SwimSprint` only in the Swim state with at least 10 stamina. While it's on, swim speed is **× 1.6** with the owner's **Swim_Sprint** stroke, and the server drains **14 stamina/s**. It turns off when stamina runs out or the swim ends; let go of Shift to try again |
| **Diving** | Roblox swims along the camera, so **look down and swim** to dive. **Hold Space to rise**: the game's own Space action doesn't jump in water, so `SwimClient` sets the Humanoid's swim-up input |
| **Breath and drowning** | **15 s of air** (`Breath` attribute) drains while your head is under the water's surface and refills at 5/s above it or on land. At 0 you're **drowning**: **8 damage per second** through `DownedManager.Damage`, the normal damage path. At 0 HP you're knocked out, not killed, matching "only a grip finishes", and a knocked body floats back up |
| **Breath bar** | A thin gold "BREATH" bar under the centre of the screen, shown only while you're short of air. It turns red as "DROWNING" (new `SwimHUD`) |
| **More deep water: the Gorge Pool** | A long pool in the gorge **under the ledge walk** (world 226, −551.5; about 46 × 20 studs, **5.2 deep**). A fall from the ledge now lands in deep water |

**`PondWriter`** now takes a list of pools (Mill Pond, Gorge Pool), each optionally stretched along the creek.
- **It only ever removes ground.** The first gorge carve rebuilt columns from the generator's heights, and the gorge had been shaped by hand, so it **raised the bank under the ledge by about 4.6 studs**.
- That was caught by comparing against the backup. The gorge was restored and re-carved with the fixed tool: **no column on the site is higher than before** (the bank under the ledge went 3.7 → 3.6).
- The Mill Pond was checked the same way: 0 of 169 sampled columns were raised.

**Tested (Rensei Play, real keys):**

| Step | Result |
|---|---|
| Shift+W in the Mill Pond for 2.5 s | `SwimSprint` on; speed **12 → 19.2**; **Swim_Sprint** played; stamina **100 → 66.4** (about 14/s) |
| Let go of Shift (W still held) | **back to 12** at once; `SwimSprint` cleared. (Bug found and fixed here: WalkSpeed is stored as a 32-bit float, so 19.2 read back as 19.2000008 and the speed stayed raised. The comparison now has a tolerance) |
| Dive: camera looking down, hold W | the head went under (lowest y 1.77); the breath bar drained **15 → 0 in 15.9 s** |
| Stay down | **drowning at 16.4 s**; **8 damage every ~1.1 s** (14 ticks logged); the bar turned red "DROWNING"; no knock-out (health was high) |
| Hold Space | rose to the surface (head y 5.38); breath refilled to full; drowning cleared |
| Drop from ledge height on the water side into the Gorge Pool | landed in the water and **entered the Swim state** |
| Errors | 0 game errors or warnings (the one client line is the Studio tool noting the test camera) |
| Profile | restored; equal to the snapshot |

**Files:**
- **New:** `ServerHandler.Requests.Swim`.
- **Changed:** `SwimService` (sprint drain, breath, drowning), `SwimClient` (sprint, rise, breath bar), `TuningConfig.Swim`, `PondWriter` (pool list; never raises ground), the terrain at the gorge.

**Backup:** `RenseiBackups["Pre-SwimExtras_2026-10-18"]`.
- It holds the four scripts as they were, plus **`GorgeSiteTerrain`** (the gorge before the pool).
- Its README has the undo steps.

### Touch buttons for swimming (added the same day)

**Owner (2026-10-18):** "add touch buttons for swim sprint and rise that only show while swimming."

- **Two hold buttons** in the existing touch cluster (`MobileControls`), using the same slot-plate art:
  - **SPRINT**, in Dash's spot: held = holding Shift;
  - **RISE**, in Jump's spot: held = holding Space.
- **Shown only in the Swim state.** Meanwhile, the on-foot buttons that do nothing in water (Jump, Dash, Fight, Run, Slide) hide, so nothing overlaps. A toggled RUN stops when you enter the water.
- **Same code path as the keys:** `SwimClient` registers the actions "SwimSprint" and "SwimRise" through `ClientActions`. The server rules (stamina, the Swim state) are unchanged.

**Tested (Rensei Play, with the game's `ForceMobileControls` test switch; buttons pressed and held with the mouse):**

| Step | Result |
|---|---|
| On land | Fight, Dash, Jump, Slide and Run shown; no swim buttons |
| In the Mill Pond | **only SPRINT and RISE shown** (82 px each in a 682 × 715 window) |
| Hold SPRINT while swimming forward | `SwimSprint` on, speed **19.2**; released → **12** |
| Dive, then hold RISE | the swim-up input was set **28 times** while held, and the character surfaced |
| Back on the bank | the on-foot buttons returned and the swim buttons hid |
| Errors / profile | 0 game errors; profile restored, equal to the snapshot; the test switch was turned off |

**Notes:**
- **Rising is mostly automatic.** Roblox's buoyancy alone brought the character from the bottom to the surface in 0.75 s, so RISE (and Space) mainly matter for staying near the surface or climbing out.
- **The game's base walk speed is inconsistent.** It's 12 by the game's own convention (`DefaultWS × SpeedMultiplier`, which the run, crouch and block skills restore to), but WCS characters can start at 16. The swim sprint restores to 12, like the others.

**Backup:** `RenseiBackups["Pre-SwimTouch_2026-10-18"]` (MobileControls, SwimClient).

### Follow-up checks and fixes (same day)

**1. Drowning was too weak (balance fix).**
- A flat 8 damage per second was out-healed by Roblox's own health regeneration (about 1 % of max health per second, roughly 6/s at 580 HP).
- In Play, health actually *rose* while drowning (10 → 25 HP), so it could never knock anyone out.
- **Now:** `TuningConfig.Swim.DrownFraction = 0.06` (PROPOSAL), so each tick deals 6 % of max health, at least the old 8. That's 35/s at 580 HP.
- **Retested from full health:** 20 s of drowning took 580 → 36 HP (about 17–22 s to a knock-out with regen running).
- **Retested with health set to 60 at the start of drowning:**
  - **knocked out at 19.5 s** with 1 HP (not killed);
  - the swim state and drowning ended at once;
  - the body floated back up (head y 0.6 → 5.3).

**2. Every enemy type in deep water.**
- **Run:** the Gale, Ward, Stone and Frost Alchemists, the Bandit Duelist, and bandits with the Sykov (gun) and the Katana, on top of the Bandit (Rapier) and Field Alchemist tested earlier.
- **Result:** each enemy was moved into the pond with the player, then switched from passive to hostile. **None started an attack or a cast in 7–8 s**, and none left the Swim state.
- **A test mistake, not a bug:** the first pass switched enemies to hostile *before* moving them, so three alchemists started casts on land and finished them in the pond.
- **Real edge case (left as is):** an attack or cast that's already running finishes even if its owner (player or enemy) ends up in water partway through. New ones can't start.

**3. Bug fix: Earth spike / rock visuals over water.**
- **Bug:** `Effects.Alchemy.EarthShapes.Ground` raycast for the ground under a spike. Over water it hit the water surface, and `Terrain:GetMaterialColor(Water)` errors ("Unsupported terrain material"). That stopped the client-side spike visuals for that cast; the damage, run on the server, was unaffected.
- **Fix:** the ground ray now ignores water, so rock rises from the bed. `GetMaterialColor` is also wrapped, falling back to the default rock look for any other unsupported material.
- **Verified on the client:**
  - over both pools, `Ground` returns the floor (y 0);
  - dry land is unchanged;
  - the old path still reproduces the error.

**Backup:** `RenseiBackups["Pre-DrownTuning_2026-10-18"]` (SwimService, TuningConfig, EarthShapes). The profile was restored after every session; 0 game errors.

### Not tested

- Two players watching each other's swim animation.
- A real touch device (the buttons were pressed with the mouse through the game's test switch).
- An Earth spike cast by a player across water (the fixed function was checked directly).
- Being knocked out by drowning (needs low health; the damage path is the normal one).
- Enemies of every type in water (a Bandit and the Field Alchemist were run).
- Being stunned, knocked or gripped while swimming (code-checked only).
- Swimming up and down with Space or crouch. Roblox's buoyancy keeps you at the surface; there's no diving.

### Open (owner)

- ~~More deep water elsewhere~~ (the Gorge Pool is added). Whether to rename or move either pool.
- ~~Drowning or stamina while swimming, a swim sprint, and diving~~: done (see "Swimming extras").
- ~~Mobile buttons for the swim sprint and rise~~: done (see "Touch buttons for swimming").
- Deeper water: the baseplate top (y 0) limits pools to about 5.2 deep where the creek's surface is 5.2. Deeper water would need a raised basin or a hole in the baseplate.
- ~~Whether enemies should also be unable to fight in water.~~ Yes; done (see above).

## 2026-10-18 — Iron Rush and Phoenix Drive fixes; Greatsword / Rapier / Daggers regression

These two misses were noted earlier but not fixed:
- Iron Rush whiffed at point blank (Sheet Import changelog);
- Phoenix Drive didn't connect at 10 studs (Phase 8 changelog).

The Phase 9 audit also didn't cover the Greatsword, Rapier and Daggers M1 strings, so they're tested here. No combat numbers were changed.

> **Status: fixed and tested in Studio Play** (Rensei, one client, real keyboard and mouse). The profile was snapshotted first and restored exactly afterwards.

### 1. Iron Rush ran past a close target

**Cause:** the rush is a 0.6 s lunge at speed 70 (about 27 studs) that only stopped at walls. The grab check comes later, at 1.97 s. From point blank, the gunner ran straight past the target and grabbed air.

**Fix:**
- `MoverManager.Lunge` takes an optional `StopAt` (studs). The lunge also ends once a character is that close in front.
- `Requests.ClassSkill` passes the skill's `LungeStopAt`.
- `TuningConfig.ClassSkills.IronRush.LungeStopAt = 3.5`.
- **Only Iron Rush uses it.** Every other lunge behaves exactly as before.

**Tested (passive bandit, key 1 in Combat Mode):**

| Start distance | Rush | Grab | Final hit | Result |
|---|---|---|---|---|
| 2.6 studs (point blank) | stopped after 1.1 studs | 10, latched | 30, knocked 17.9 studs away | full move |
| 15 studs | carried 12.1 studs, stopped at the target | 10, latched | 30, knocked 40.6 studs away | full move |

### 2. Phoenix Drive landed behind a close target

**Cause:** the crash point came from a 45-stud aim ray that ignored every character. With a level aim (an NPC's, or a player looking straight ahead), the phoenix always crashed about 45 studs out, or at the first wall, past anyone close. Rising Thorn's aim already stops at the first character it crosses.

**Fix (`AlchemyService`, Phoenix kind):**
- The aim ray now stops at the first character it crosses (excluding the caster), like Rising Thorn.
- The ground check under that point still ignores characters, so the crash lands on the ground at their feet.
- `MinRange` (12) still applies.

**Tested:**
- **Setup:** the Field Alchemist (passive) cast Flame V through `AlchemyService.CastAs` at the player from 10 studs, aiming level.
- **Before the fix**, the Phase 8 test of the same case did no damage.
- **Now:**
  - the crash hit for **70**, and the explosion for **170** (240 total, matching the sheet);
  - the 5-damage burn ticks followed;
  - the meter went from 100 to 30, the right V cost.

### 3. Weapon M1 strings (Phase 9 gap)

**Setup:** each weapon equipped through `LoadoutService.Toggle`, four real mouse clicks at a passive bandit 3.5 studs away. Every hit was confirmed by the hitbox (all four came back "Hit"), and the damage was read from the target's health.

| Weapon | Configured (`TuningConfig.Weapons`) | Measured |
|---|---|---|
| Greatsword | 30 / 30 / 30 / 38 | **30 / 30 / 30 / 38** |
| Rapier | 14 / 14 / 14 / 20 | **14 / 14 / 14 / 20** |
| Daggers | 12 / 12 / 12 / 16 | **12 / 12 / 12 / 16**, plus 2-damage bleed ticks (the Lacerate passive) |

### Test notes

**A second bandit interfered.** One 15-stud Iron Rush run lost its final hit. The cause was another bandit hitting the gunner, which stunned the attack 0.13 s before the final hit; it wasn't the fix. With every enemy made passive, the move completed. This is the same outside interference as the earlier "grip ending early" case.

**Profile:**
- The test changed `SkillTree`, `SkillLoadout`, `Inventory` (test weapons), `EquippedWeapon` and `Mastery` (training from the hits). All of it was restored, and the profile equals the snapshot.
- 0 client or server errors.
- Studio-only test helpers (temporary scripts, a hitbox logger, the raised test health) were removed or ended with Play.

### Files and backup

- **Changed:** `MoverManager`, `ServerHandler.Requests.ClassSkill`, `TuningConfig` (one field), `AlchemyService`.
- **Backup:** `ServerStorage.RenseiBackups["Pre-SkillAimFix_2026-10-18"]`, holding all four as they were.

### Follow-up: a player-cast Phoenix Drive (tested the same day)

**Setup:**
- V was unlocked on the test profile (the Mastery node `AL_V`), the meter was filled, and Combat Mode was turned on.
- The camera was level behind the player, aiming at a bandit 10 studs ahead. Then a real **V** key press.

**Results:**
- **First cast:** the danger ring was marked about 10 studs ahead, under the target, not 45 studs out. But the passive bandit walked during the 1.5 s cast and took no damage. That's the intended design: the crash point is fixed when the cast starts, and the move "can't be blocked, so it must be dodged".
- **Second cast, with the bandit held still at 10 studs:**
  - crash **70**;
  - explosion **170**;
  - burn **5 × 4**;
  - **260 total**, exactly the sheet's number. The meter went 100 → 30.

The profile was restored afterwards, and there were no errors.

### Not tested
- **Ice Shards** (Ice C) has the same "ignore characters" aim. That's left as is, because a trap is placed, not thrown at someone.
- Two players.

## 2026-10-18 — UI pass: menus, leaderboard, popups, character creator camera

**These are the owner's queued UI items.** Sizes and timings are PROPOSAL.

> **Status: built and tested in Studio Play** (one client, real mouse). See "Tested" under each item.

### 1. Smaller Stats and Inventory menus (Rensei)

- **Change:** `StarterGui.Uis.Stats.MainFrame` and `Inventory.MainFrame` are scaled to **0.85×**:
  - Stats: {0.586, 0.605} → {0.498, 0.514};
  - Inventory: {0.638, 0.747} → {0.542, 0.635}.
- **The original size** is kept on each frame as a `FullSize` attribute. To undo, set Size back to it.
- **Why the sizes were edited directly:** UIMotion skips frames that already have a UIScale, so a UIScale couldn't be used.
- **MasteryUI** sizes its panel from `FullSize` when present, so the Mastery menu keeps its old size.
- **Tested:** both menus open at the new size, with no clipped text.

### 2. Leaderboard on the original art, with character names (Rensei)

- **Uses the existing UI:** `HUDUI` now fills the original `HUD.LeaderBoard` (its Scroll and Container) with `Templates.LeaderEntry` rows. The dark panel, banner and column header were removed.
- **Each row shows:**
  - **the character name** (from the save's `Identity.Name`). It falls back to the Roblox display name until the profile has loaded, or if a character has no name;
  - **the title and level**, in the rank colour (for example "Initiate · Lv 3").
- **Hover or tap a row:** opens the existing info card, now titled with the character name.
- **Server:** `RankService.Publish` sets a `CharacterName` player attribute alongside the existing rank attributes.
- **Tested:** the row showed a test name ("Alden Varro") on the original art with no dark panel. The test name was set and then removed. The profile was restored afterwards.

### 3. Minimal level-up and codex/area popups (Rensei)

- **`PopupUI` was rewritten.** The old `HUD2.LevelUp` and `NewAreaDiscovered` art is left in place, unused.
- **Level up** (`HUD2.LevelUpMinimal`): a thin gold line draws out, and a small sigil (two outlined squares turning in opposite directions) settles. Then "LEVEL n" with the rewards underneath ("+3 Stat Points · +20 HP").
- **New area and codex entry** (`HUD2.EntryMinimal`): a small "NEW AREA" or "CODEX ENTRY" label, the name, an underline that draws in, and the description.
- **Queue:** all three popups share one centre lane, so they play one after another instead of overlapping.
- **Reduced Motion:** a fade only.
- **Fixed:** the label helper passed `Max` to a TextLabel as if it were a property. That error stopped the UI from starting, which also hid the alchemy slots.
- **Tested:**
  - a level-up and an area discovery fired together. Level-up showed 0.1–3.8 s, then the area 3.8–8.8 s, with no overlap;
  - 0 client errors.

### 4. Character creator (Main Menu place)

- **Crisp UI:** the menu's UIScale was allowed to grow to 1.6× on large windows, which made the panel art blurry. It's now **capped at 1.0×**:
  - `math.clamp(math.min(V.Y/720, V.X/1100), 0.5, 1)`;
  - it can still shrink to 0.5× on small screens.
- **Face cam and full body:** **FACE** and **BODY** buttons were added to the rotate bar (`<  FACE  BODY  >`), and the active one is highlighted.
  - **FACE:** a close-up of the head and shoulders, offset so the panel doesn't cover the face.
  - **BODY:** the full character on the pedestal.
  - **Default per step:** the Face step opens on FACE; the other steps open on BODY. Once the player picks a view, it stays until they leave the creator.
- **Depth of field:** while in the creator, the blur follows the camera, so the character stays sharp and the background is softly blurred. Leaving the creator restores the menu's normal blur.
- **Tested** (Play, real mouse):
  - the empty slot opened the creator on the FACE close-up;
  - BODY switched to the full-body shot, with the character in focus;
  - SLOTS returned to the save-slot screen;
  - **no character was created.** Slot 1 stayed EMPTY and slot 2 (the owner's real character, Level 3) was untouched;
  - 0 game errors (only Roblox CoreGui UIBlox warnings).

### 5. Creator QOL and Creator Plus (Main Menu place, plus one rendering change in Rensei)

**Request:** "add more QOL features for character customization, with some behind a paywall for more accessibility (NO ACCESSORIES)". The free/paid split and the slot count are **PROPOSAL**. Everything is cosmetic: no stats, no accessories.

**Free for everyone.** A tool bar above the turn buttons: `UNDO  REDO  RANDOM  RESET  LOOKS`.
- **Undo / redo:**
  - covers every look change: face, hair, colours, nation, gender, random and reset;
  - the keyboard works too (Ctrl+Z, Ctrl+Y or Ctrl+Shift+Z), but not while typing in a text box;
  - one colour-wheel drag counts as one step, and the history holds 60 steps;
  - the buttons dim when there's nothing to undo or redo.
- **Random:** a random look true to your nation and gender: skin, hair colour, preset hair, eyes, brows and mouth. Your typed hair IDs stay.
- **Reset:** back to the nation's default look. Nation, gender and name stay.

**Creator Plus** (one Game Pass, config in `ReplicatedStorage.Modules.Data.Rensei.CreatorPlus`):
- **Custom skin colour:**
  - a colour wheel under the 8 skin swatches (the same wheel as hair colour);
  - picking a swatch goes back to a preset;
  - without the pass, an "UNLOCK WITH CREATOR PLUS" button shows instead.
- **Saved looks:**
  - **3 looks** kept on the account and loadable into any new character, in any slot;
  - each slot has LOAD, SAVE HERE / OVERWRITE and CLEAR;
  - loading sets the nation, gender and look; the name and clan stay.
- **Without the pass**, LOOKS (shown as "LOOKS +") opens a Creator Plus panel listing the two features and a GET CREATOR PLUS button. That panel shows the pass's price once it exists.
- **Panel position:** on the right, so the character stays visible.

**Server rules (MenuServer):**
- Ownership is checked with `UserOwnsGamePassAsync` and cached. A purchase in the same server unlocks at once.
- **Create** refuses a custom skin from a non-owner: "Custom skin colours are part of Creator Plus. Pick a skin swatch instead."
- **New calls:** `Plus` (returns ownership and the saved looks), `SaveLook`, `ClearLook`. Saving and clearing need the pass, and every look is cleaned by `Customization.Clean` before it's stored.
- **New `ServerScriptService.LookPresets`:** stores the looks in DataStore `RenseiLooks`, key `"L" .. UserId`, written only by the menu server. **In Studio the looks are kept in memory only**, so testing never writes the live store.

**Skin colour in saves:** `Appearance.Skin` is now a preset id (as before) **or** 6 hex digits.
- **New in `Customization`:** `SkinColorOf` and `IsCustomSkin`. `Clean` keeps a hex skin.
- **Both places are updated**, so a custom skin also renders in game:
  - `Customization` in both places (the file stays the same in every place);
  - `AppearanceService` in both places (Main Menu `ReplicatedStorage.Modules`, Rensei `ServerScriptService`).
- Old saves are unchanged (preset ids load as before).

**Before going live (owner):**
1. Create the Game Pass in the Creator Dashboard and put its ID in `CreatorPlus.PassId`. While it's 0, the paid options are locked and buying says "Creator Plus isn't on sale yet."
2. `CreatorPlus.StudioOwns = true` makes Studio testers count as owners while `PassId` is 0. It never applies on a live server, and you can set it to false to see the locked view in Studio.

**Tested (Studio Play, real mouse and keyboard):**
- **Tool bar:**
  - RANDOM changed the look (skin FFCC99 → EAB892, new eyes);
  - UNDO restored it exactly, and REDO brought the random look back;
  - RESET returned to the Amestrian default, and Ctrl+Z undid the reset;
  - UNDO/REDO dimmed and lit up correctly.
- **Custom skin (Studio counted as an owner):**
  - the wheel first showed the current preset without changing it, and the swatch stayed selected;
  - a click set skin #706AEA on the character, and the swatches deselected.
- **Saved looks:**
  - SAVE HERE stored look 1, which then read "Amestrian · Male · custom skin";
  - after RESET, LOAD brought back skin 706AEA;
  - CLEAR emptied the slot again.
- **Forged requests**, all refused: slot 9 ("No such look slot."), an unknown nation ("That look isn't complete."), a non-table argument.
- **Locked view (test switch off):**
  - the tool bar showed "LOOKS +";
  - the skin wheel was hidden behind the unlock button, which opened the Creator Plus panel;
  - GET CREATOR PLUS said "Creator Plus isn't on sale yet.";
  - a forged SaveLook from the non-owner was refused ("Saved looks are part of Creator Plus.").
- **Errors:** 0 game errors or warnings on the client and the server.
- **No character was created.** Slot 1 stayed EMPTY, and the owner's real character (slot 2) is unchanged.
- **Rensei:** both changed scripts compile. `Clean` keeps a hex skin and maps it to the right colour; old preset ids are unchanged.

**Not tested:**
- **The Create refusal for a non-owner's custom skin.** Reaching that check needs a rolled clan, which would spend the slot's free roll on your live save, so it was only code-checked.
- A real Game Pass purchase (no pass exists yet).
- The live `RenseiLooks` DataStore. Studio uses memory by design.
- A character *spawning* with a saved custom skin in Rensei. **Tested instead (Rensei Play):** applying a look with skin `706aea` to the player's character coloured the head, torso, arms and legs 706AEA. Re-applying the saved identity then restored FFCC99. Nothing was saved.
- Touch.

### 6. Starting weapons: six (Main Menu, plus Rensei's enemy pool)

**Owner (2026-10-18):** "Fists, Katana, Rapier, Caestus, Greatsword, Daggers".

- **`Customization.StartWeapons`** (both places, so the file stays the same everywhere) is now those six. Renetti and Sykov (the guns) are off the creator.
- **New `Customization.CommonWeapons`:** all eight Common weapons, guns included.
- **Rensei `EnemyService`** used `StartWeapons` as the random enemy weapon pool. It now uses `CommonWeapons`, so bandits still carry guns. Only the creator changed.
- **Existing characters keep their weapon.** The list is only checked when a character is created.

**Tested (Studio Play, real mouse):**
- the Weapon step shows the six in a 2×3 grid;
- Daggers selects and shows its stats card;
- a forged Create with Renetti or Sykov was refused ("Pick a starting weapon."). Daggers passed the weapon check and stopped at "Roll your clan first.", so nothing was created;
- slot 1 stayed EMPTY and the owner's real character is unchanged;
- 0 client errors;
- both places' scripts compile.

**Backup:** Rensei `EnemyService` (as it was before) is in `RenseiBackups["Pre-CreatorPlus_2026-10-18"]`. The `Customization` copies from before today are already backed up there and in `Pre-CreatorQOL_2026-10-18`.

**Tested in Rensei Play:** 5 bandits spawned with Rapier, **Sykov** (a gun), Caestus, Daggers and Rapier. The guns are still in the enemy pool.

### 7. Menus no longer open over a conversation (Rensei; Phase 9 finding 1)

**Before:** pressing K during an NPC dialogue opened the Mastery menu on top, with the dialogue's choices still showing underneath.

**Fix:** `UIState.ToggleMenu` refuses to open a menu while `Uis.Dialogue` is visible, just as it already did in combat. Closing a menu is never blocked, and this covers every registered menu (Mastery, Stats, Inventory and the rest).

**Backup:** `RenseiBackups["Pre-DialogueMenuFix_2026-10-18"].UIState`.

**Tested (Rensei Play, real keys, at Drillmaster Vask):**
- E opened the dialogue;
- **K did nothing**: only the dialogue was showing;
- key 5 ("That's enough for now") closed it;
- **K then opened the Mastery menu** as normal, and K closed it;
- 0 client or server errors.

**Profile:** snapshotted before the session and restored afterwards: no changed keys, equal field for field.

**Finding: Esc doesn't close a dialogue.** `DialogueUI` listens for Esc, but Roblox takes Esc for its own menu, so the game sees it as already handled and ignores it. In Studio, Esc opened Roblox's menu, which then swallowed every key until Esc was pressed again. **Fixed with an X button (section 8).**

### 8. A close (X) button on the dialogue box (Rensei)

**Owner (2026-10-18):** "Add a small X close button on the dialogue box (works on mobile too)."

- **Look:** the kit's own round X (the same art as the inventory search's clear button), on the box's top-right corner, clear of the text. It turns gold on hover.
- **What it does:** sends the normal close request. The server ends the conversation and the HUD bars come back, the same as leaving through a choice. It works mid-line too.
- **Touch:** the icon is small (20 px), but its invisible tap area is larger: **44×44 px** in a 682×715 window, about 45 px on a landscape phone, which meets Roblox's recommended minimum. The tap area overlaps the text box by only a 4 px corner.
- **Built in code** by `DialogueUI.Start`, under `Uis.Dialogue.MainFrame.Close`.
- **Backup:** `RenseiBackups["Pre-DialogueMenuFix_2026-10-18"].DialogueUI`.

**Tested (Rensei Play, real mouse and keys, at Drillmaster Vask):**
- the X shows on the corner;
- clicking it closed the dialogue mid-line, and the HUD bars came back;
- talking again reopened it normally;
- key 5 still closes through "That's enough for now" (the first press finishes the typing line, as designed);
- 0 client or server errors.

**Profile:**
- Snapshotted and restored exactly: no changed keys.
- The first test session was stopped before its restore. The next session's full profile matched the earlier full snapshot (taken in an earlier session) field for field, apart from the empty `Styles` / `StyleUnlocks` keys the style system added on purpose earlier. So nothing leaked into the save.

**Not tested:** a real touch device (Studio can't emulate one through these tools).

### 9. Owner decision 8: the base moveset stays a selectable style (Rensei)

**Owner (2026-10-18):** "it should stay as selectable".

- **Nothing in the game changed.** It already worked this way: every class's existing moveset is the "Base" style. For bare fists it's shown as **Brawler**, a name that's still PROPOSAL.
- **Base is always learned:** no trainer and no requirements. It's listed in the style picker, can be picked at any time out of combat, and is the fallback when no other style is saved.
- **The comment in `Rensei.Styles`** now records the decision (it used to say "decision 8 still open").

**Checked (Edit, fresh module copy):**
- Fists lists Base, Boxing and Lethwei.
- A brand-new save has Base learned (Boxing not) and uses Base.
- A Boxing player who saved Boxing gets Boxing; switching back saves and uses Base.
- Weapon classes list Base only.
- **Same rule everywhere:** the server's switch (`StyleService.Select`) and the picker (`MasteryUI`) both use `Styles.Unlocked`, which always allows Base.
- **Earlier Play tests already covered** switching back to Base (Fist Styles changelog: "Base after styles").

**Backup:** `RenseiBackups["Pre-Decision8_2026-10-18"].Styles`.

### 10. The CODEX ENTRY card now shows for real unlocks (Rensei, bug fix)

**The bug:** the minimal CODEX ENTRY card (section 3) listens for a "Codex" event. Both places that unlock codex entries still sent the old generic "Banner" text, so the card never appeared:
- `QuestService` (quest rewards);
- `WorldService` (an enemy with a `CodexEntry` attribute defeated).

**The fix:**
- Both now send **"Codex" {Name = the entry, Description = "Added to your Journal (J)."}**.
- Codex entries have no description text in the data, so the card points to the Journal (J) instead of inventing lore.

**Backup:** `RenseiBackups["Pre-CodexPopup_2026-10-18"]` (QuestService, WorldService).

**Tested (Rensei Play, real input):**
- **Setup:** a bandit was given a test-only `CodexEntry` ("Studio Test Entry") and 5 HP, then defeated with two real M1 clicks.
- **Result:**
  - the client received **Codex: Studio Test Entry**;
  - the card showed **CODEX ENTRY / Studio Test Entry / Added to your Journal (J).**;
  - 0 errors.
- **Profile:** the codex entry, EXP and training from the kill were removed (restored to the snapshot).

### Files

| Place | Changed |
|---|---|
| Rensei | `HUDUI`, `MasteryUI`, `RankService`, `PopupUI`, `Stats.MainFrame`, `Inventory.MainFrame`, `Customization` (skin helpers, weapon lists), `ServerScriptService.AppearanceService` (skin colour), `EnemyService` (weapon pool), `UIState` (no menus over dialogue), `DialogueUI` (X button), `Rensei.Styles` (comment only) |
| Main Menu | `StarterPlayerScripts.MenuClient`, `MenuServer`, `Customization`, `Modules.AppearanceService`, **new** `CreatorPlus`, **new** `ServerScriptService.LookPresets` |

### Backups

- **Rensei:** `ServerStorage.RenseiBackups["Pre-UIPass_2026-10-18"]` (the four scripts, plus a README on the `FullSize` attribute).
- **Main Menu:** `ServerStorage.RenseiBackups["Pre-CreatorQOL_2026-10-18"]`:
  - `MenuClient` (the original), `MenuClient_AfterCamera` (with the camera work, before Creator Plus);
  - `Customization`, `AppearanceService`, `MenuServer`.
- **Rensei:** `ServerStorage.RenseiBackups["Pre-CreatorPlus_2026-10-18"]` (`Customization`, `AppearanceService`).

### Not tested

- Touch and phone screen sizes for any of these.
- The leaderboard with two or more players.
- Turning the character in FACE view.

### Still open (owner)

- **Starting weapons:** done (section 6).
- **Creator Plus:** built (section 5). It needs the Game Pass ID, and the owner should confirm or change the free/paid split.

## 2026-10-18 — Animation sheet import, sticky skills, style trainers, Boxing fix, gun balance

All tested in Studio Play (one client) unless marked otherwise. Every combat number is PROPOSAL.

**Backup:** `ServerStorage.RenseiBackups["Pre-SheetImport_2026-10-18"]` (TuningConfig, DownedManager, LedgeWalk, Requests.ClassSkill, WeaponManager, Styles, StoryLogic, StyleService, ProfileData, Dialogues, DialogueService, MasteryUI). Every changed animation keeps its old published id in the attribute `PreviousId`.

### 1. Animation sheet import

- **Transcription:** all 95 IDs from the sheet screenshots were transcribed and checked. 61 were already registered.
- **The 34 new ones:** each was verified with Roblox as an animation owned by Rensei whose name matches the sheet label (for example "greatsword m4", "Pistol 1", "WALL WALK RIGHT").
- **Loading:** checked in Play by loading every one on a live character.

**Working and wired (load in game):**

| What | Before | Now |
|---|---|---|
| Gun shots `Guns_Light1–4` | Studio-only "blatt" saves (nothing live) | sheet **Pistol Aim 1–4**, timed on their HitFrame (0.35 s) |
| Gun heavy | the fist heavy | sheet **Pistol Crit** (HitFrame 0.70 s) |
| Gun run | Studio-only | sheet **Dual Gun Run** |
| Rapier M1 1–4 | borrowed 3 katana swings | sheet **Rapier 1–4** (Hit markers 0.37 s) |
| Rapier crit | old id | sheet crit (fastest motion 0.43 s) |
| Greatsword M1 4 | old id | sheet "greatsword m4" (Hit 0.78 s; windup 0.46 → 0.55 s) |
| Katana / Dagger run | Studio-only | sheet Run ("Dagger Run") |
| Grips | registered but never used | **per-weapon grip finishers** (see 3) |
| Ledge walk right | Walk Left played backwards | sheet **Wall Ledge Walk Right** |
| Swim Idle / Swim Sprint / Walk Right / Ground Interaction | — | registered for future systems (swimming, strafing, ground interactions) |

The emote "No!" (80946728550958) was already registered as `Emote_No`.

**Broken in the sheet — owner action needed.** The engine rejects these: "AnimationClip loaded is not valid", or the download fails. Each was put back to its previous behaviour, with the sheet id kept in the attribute `SheetId`. Re-export and re-upload them, then put the new id in `AnimationId`.

| Animation | Sheet id |
|---|---|
| Greatsword Idle | 125386811877833 |
| Greatsword Walk | 76985284126069 |
| Greatsword Unsheathe | 122309498454912 |
| Greatsword Sheathe | 78181583295596 |
| Katana Walk | 110642878390298 |
| Katana Unsheathe | 138826683613033 |
| Katana Sheathe | 135958788270981 |
| Dagger Unsheathe | 82218741773055 |
| Dagger Sheathe | 120069108676683 |
| Greatsword Grip Victim (KO) | 136479651286488 (the previous working id is back) |
| Wall Ledge Idle Left / Right | 134041804221664 / 111740908967094 |

The last ID is also the existing NPC "Wall Cover Right" idle, which therefore doesn't play either.

### 2. Fist skills

- **Spin Kick:** now **one hit**, the big kick at 1.12 s of the animation, played at 1.25× so it lands at 0.9 s. Tested: **28** damage.
- **540 Kick:** now **three hits**, its kicks at 0.13 / 0.40 / 0.82 s. Tested: **12 / 12 / 22**.
- The skill tree descriptions are updated.

### 3. Grabs, the latch, and grip finishers

- **Victim-animation moves are grabs:** Bear Hug, Slam Dunk and Iron Rush, the only skills with victim animations. They were already grabs; they now also hold the victim for the whole move (the latch).
- **Latch (Devil Hunter / VV Ultimatum skill logic):** once a skill hit **lands** (not blocked, not parried):
  - the victim is welded **in front of the attacker** for the rest of the move;
  - it follows the attacker's lunges and stays stunned between hits, so the remaining hits connect;
  - it's released just before the final hit, so the finisher's knockback works, or when the move ends, is interrupted, or either dies.
  - A blocked or parried hit never latches. It never puts the victim inside a wall (raycast).
  - **Tested:** the 540 Kick and Bear Hug held the victim at exactly 2.8 studs during the move and released it at the end.
- **Grip finishers (B on a knocked target):** the sheet's GRIP / GRIP VICTIM pairs per weapon (`TuningConfig.Downed.Grips`), played to fill the 2 s grip:
  - **bare hands** use the Caestus (Fists) pair, replacing the Studio-only pair;
  - **Katana, Greatsword, Daggers and Caestus** use their own pair;
  - **Guns** play the execution shot over the slumped body;
  - **Rapier** keeps the Execution finisher (no grip animation on the sheet).
  - **Tested:** a Katana grip on a knocked Elite played `Sword_Grip`, finished in 2.02 s and killed it.
  - **Not re-verified:** the B key itself in this session (the request path is unchanged).

### 4. Fighting styles: trainer-only unlocks, Boxing infinite fixed

- **Styles are learned only from their trainer, once the requirements are met:**
  - **Boxing:** Coach Harlan, Lindenmoor square. Level 4, Speed 4.
  - **Lethwei:** Master Thura, by the Lindenmoor barn. Level 6, Strength 5.
- **Pieces:**
  - New profile key `StyleUnlocks` (additive).
  - `Rensei.Styles` gains `Unlock`, `Unlocked`, `Missing` and `Ready`.
  - StoryLogic conditions `StyleReady` / `StyleUnlocked` / `NotStyleUnlocked`.
  - Dialogue choices can use `ShowIf`.
  - New dialogue action `UnlockStyle`; StyleService re-checks the requirements.
  - The two trainer NPCs, with their dialogues.
- **Picker:** unlearned styles show **LOCKED**, with the trainer, where to find them, and what's still needed.
- **Tested:**
  - at level 1 the lesson shows greyed out as **[Needs Level 4, Speed 4]**, and clicking it does nothing;
  - with the requirements met (test values, restored afterwards), "Teach me Boxing" taught it;
  - Boxing could then be selected;
  - Lethwei was refused: "You haven't learned Lethwei. Master Thura teaches it, at the Lindenmoor farm, by the barn."
- **Boxing infinite:**
  - **Cause:** the finisher stunned for 0.75 s, past its recovery plus the next jab's startup, so the string looped forever.
  - **Fix:** finisher stun 0.35 s, recovery 0.45 s, still no knockback.
  - **Tested** with continuous M1 spam: after each full string the target got about **0.42 s free** before the next jab landed.

### 5. Gun combat audit and balance

**Audit (before):**

| | Melee classes | Guns (shooting) |
|---|---|---|
| Damage per second | 30–37 at 3.5–5 studs | burst 40–54, sustained 30–37, at **90 studs** |
| Stun per hit | — | 0.3 s per shot, so the Renetti (0.30 s between shots) could **stunlock from 90 studs** |
| Posture | 15–20 /s | 11.5–20 /s, from range |
| M1 | each class's own string | the pistol whip matched a full melee string (31 DPS) |
| Range penalty | — | **none** |

**Changes:**
- **Shots:** stun 0.3 → **0.12 s** (a flinch, shorter than any gun's fire interval); posture 6 → **3**.
- **Falloff:** full damage to 25 studs, down to **50% at 90**. Point Blank (+20% within 12) is kept.
- **Per gun** (damage / magazine / reload / recovery):
  - **Revolver:** 20 / 6 / 2.0 / 0.36
  - **Renetti:** 10 / 12 / 1.6 / 0.20
  - **Forge Tac:** 24 / 7 / 2.0 / 0.45
  - **Sykov:** 13 / 10 / 1.7 / 0.24
  - **Result:** sustained 21–27 DPS (melee 30–37), burst 29–41 before falloff.
- **Pistol whip:** 11 / 11 / 11 / 16, about 24 DPS.
- Enemy gunners use the same numbers.
- **Tested** (Revolver, real shoot request): **24** damage at 8 studs (Point Blank), **17** at 40, **10** at 85. The shots carry 0.12 s stun and 3 posture.

### Not tested

- Rapier, Greatsword M1 4, gun heavy and Pistol shot animations swung with real input. They load in game and are timed from their markers; the swings weren't checked visually.
- Slam Dunk and Iron Rush with the latch (only the 540 Kick and Bear Hug were run).
- The latch against a real player victim (network ownership hand-off) and two players.
- Mobile.
- Balance and feel.

## 2026-10-18 — Weapon styles: Boxing and Lethwei on bare fists

**Owner decision 1 (2026-10-17): Boxing and Lethwei go on bare fists** (not Gauntlets/Caestus). This implements the original prompt's Phase 4 (the three-style system) for its first target. Every combat number is PROPOSAL.

> **Status: built and tested in Studio Play** (one client, real keyboard and mouse). See "Tested" below.

### What a style is

A style is a combat moveset for one class. It replaces that class's **light combo and heavy** and its **idle, walk and block poses**. Everything else stays shared:
- uppercut, aerial, dash attack;
- block/parry rules, posture, hitstop, stun, downed;
- class skills.

Damage still goes through AttackRunner → HitboxManager → DamageManager; there's no new damage path.

| | Base ("Brawler") | Boxing | Lethwei |
|---|---|---|---|
| Identity | The existing fist moveset | Pressure: even jab chains that keep the target close, walking forward while punching | Close and brutal: snappy elbows, knees and headbutts that crush guards, but risky on a whiff |
| Lights | 17×3 + 24, posture 8×3 + 14, knockback finisher | 15×3 + 20, posture 6×3 + 10, **no knockback finisher** (Pull), walk speed 16 while attacking | 16×3 + 26, **posture 12×3 + 20**, recovery 0.2 (0.6 on the finisher), knockback finisher, walk speed 12 |
| Heavy | 32 dmg / 38 posture | **Peek-a-boo**: 28 / 30, **hyper armour** | 34 / **55 posture** (guard crusher), cooldown 1.5 |
| Hit timing | — | each animation's authored "Punch" marker (0.32 s; heavy 0.58 s) | its "Punch" marker (0.12–0.18 s; heavy 0.42 s) |

### Pieces

- **New `Rensei.Styles`** (registry):
  - Classes → styles: name, description, available, idle/walk/block pose names.
  - `Fists` = bare hands: Base, Boxing, Lethwei, and **Third: NOT YET DESIGNED** (not selectable).
  - Sword, Rapier, Greatsword, Daggers, Guns and Gauntlets: Base, plus three NOT YET DESIGNED slots.
  - Helpers: `ClassOf`, `Valid`, `Selectable`, `Saved`, `Active`, `Tuning`.
- **`TuningConfig.Styles`:** the combat numbers per class and style, with the fist fallback animations if a style animation can't load.
- **`SkillData`:** generates `Style_<Id>_Light1–4` and `Style_<Id>_Heavy`.
- **Combat hooks:**
  - `FistSwing` and `Heavy` use the active style's light combo and heavy, falling back to the weapon's or the fists'.
  - `Block` plays the style's guard pose.
  - `WeaponManager` (client) plays the style's idle and walk while bare-handed in Combat Mode.
- **Animations:** Boxing and Lethwei were moved from `Assets.Animations.Registry` to `Assets.Animations.Shared.Styles`, so every character preloads them (other players see them too).
- **Save:**
  - Profile `Styles = {}`, `[Class] = id`. It's additive: Reconcile fills old saves, with no schema bump and no reset.
  - **New `StyleService`:**
    - every spawn (from `LoadoutService.Restore`), it sets the character attribute `Style` from the save;
    - on every weapon change, it re-resolves the style for the new class, so a fist style can never apply to a sword.
- **Switching (new `Requests.Style`):**
  - The client sends only a style id.
  - The server checks: it belongs to the class you're fighting as, it's available, you're alive, **out of combat** (the 12 s combat tag), and free to act (not attacking, stunned, blocking, traversing, knocked, gripped or carried).
  - Then it saves the choice. It's covered by the request rate limiter.
  - The server alone sets the attribute that combat reads.
- **UI:**
  - **Mastery menu (K), Class tab:** a **STYLE: … ▾** button beside the loadout line opens a picker panel. It shows the class's available styles with descriptions and ACTIVE/SELECT, and works by tap on mobile. Unfinished styles are hidden.
  - **HUD:** the Combat Mode tag reads **"COMBAT MODE · BOXING"**, and the entry banner matches.

### Files

- **New:** `Rensei.Styles`, `ServerScriptService.StyleService`, `Requests.Style`, the `Assets.Animations.Shared.Styles` folder.
- **Changed:** `TuningConfig`, `SkillData`, `FistSwing`, `Heavy`, `Block`, `WeaponManager`, `ProfileData`, `LoadoutService`, `MasteryUI`, `CombatModeUI`.
- **Backup:** `RenseiBackups["Pre-FistStyles_2026-10-17"]`, with a README for the moved animations and the new modules.

### Tested (Studio Play, real input unless noted)

- **Old save:** Reconcile added `Styles = {}` with no reset. The spawn set the character's style to Base.
- **Picker:** K → Class → STYLE ▾ → Boxing selected through the UI, and the profile saved `Styles = {Fists: "Boxing"}`.
- **HUD:** the tag reads **"COMBAT MODE · BOXING"**.
- **Boxing on a camp bandit:**
  - `Style_Boxing_Light1–4` hit for **15 / 15 / 15 / 20**;
  - the Peek-a-boo heavy hit the **same** target for **28** (no knockback finisher, as designed).
  - **Animations seen:** Boxing_Light1/2, Boxing_Heavy, **Boxing_Block** (guard), **Boxing_Idle**, **Boxing_Walk**.
- **Lethwei on a camp bandit:**
  - lights hit for **16 / 16 / 16 / 26**; the finisher knocked the target away;
  - the heavy hit for **34**, landing on the second bandit, which had walked into range.
- **Base after styles:** Light1/Light2 hit for 17 each.
- **Switching rules:**
  - **refused in combat** ("Catch your breath first: no switching styles mid-fight.");
  - Lethwei can't be forced while a sword is drawn.
- **Forged requests**, all refused: Third (not designed), Style1 (a weapon placeholder), an unknown id, a number, a 5,000-character string, a table.
- **Weapon switching:** drawing the Katana switched to the Sword's Base; putting it away returned to the saved fist style.
- **Persistence:**
  - **respawn** kept Lethwei;
  - **rejoin** (a full stop/start, so a real save and load) came back with Lethwei.
- **Errors:** 0 game errors or warnings on the server and the client.
- **Profile:** restored afterwards. The only difference from the original save is the new empty `Styles` key.

### Fixed during testing

- **Style attacks had no hitbox, so they couldn't hit.** The base attacks get theirs from a `LightHitbox` default inside TuningConfig. Style attacks now inherit the class's light and heavy hitboxes unless a style sets its own.
- **Picker layout at small window sizes:** the panel now scrolls, and the rows are taller so descriptions fit. The STYLE button moved, so it no longer covers the loadout line.
- **Test confusion (not a game bug):** the camp's second, non-passive bandit kept interrupting and taking hits. Later tests made both passive and tracked both.

### Not tested

- Parry timing against each style.
- Another player watching the style animations; two players.
- Touch (the picker uses tappable buttons; not run on a device).
- The STYLE button text wraps onto two lines at very small window sizes.
- Balance and feel.

### Owner decisions still open

- ~~**Decision 8:** should the existing moveset be a selectable "Base" style?~~ **Resolved 2026-10-18.** The owner said: "it should stay as selectable". See the Styles entry in the UI Pass changelog (section 9). The name "Brawler" is still PROPOSAL.
- **Unlocks:** styles are all available. No unlock rule exists in the progression design (trainers or skill tree could gate them later).

## 2026-10-17 — Phase 8: expansion on tested systems (alchemist roster, Lindenmoor Run)

**Unified prompt, Phase 8 ("avoid expanding content faster than the underlying systems can support").** I scoped this to expansions on systems already tested today. Every number is PROPOSAL.

### NPC casting: all 20 abilities verified

**Setup:** one NPC (the Gale Alchemist rig, brain set to passive) cast every ability of all five paths through `AlchemyService.CastAs` at the player, 10 studs away.

**Result:** **all 20 ran with no error**, charged the right meter cost (Z 25, X/C 35, V 70) and started their cooldown. 17 of 20 damaged the player. The three that didn't:

| Ability | Why no damage |
|---|---|
| Cryo Shift | A counter; expected |
| Steel Guard | A shield; expected |
| Phoenix Drive (Flame V) | Didn't connect at 10 studs. Not used by any NPC (ultimates are excluded); worth a look when tuning |

`CastAs` returns "Whiff" for projectiles, traps and pillars, because their damage lands after the cast returns. Judge them by the damage, not the return value.

### Three new hostile alchemists (`TuningConfig.Enemies`)

Each is built like the Field and Ward Alchemists: real abilities, meter earned by fighting, the line-of-sight check, and the free-to-act check.

| Enemy | Path | Casts | Reflex | HP / Lv | Spawn (`Map.AlchemistSpawns`) |
|---|---|---|---|---|---|
| Frost Alchemist | Ice | X Coldsteel Smash at 0–9, C Ice Shards (trap) at 6–22 | **Z Cryo Shift** (counter) | 700 / 6 | outside the Frozen Research Station's west entrance (−160, 1, −60). The interior is sealed by its ice-door puzzle, and the brain has no pathfinding |
| Gale Alchemist | Wind | X Gale Burst at 0–9, Z Air Slash at 10–45 | — | 600 / 6 | south of the Silent Observatory (118, 1, 84) |
| Stone Alchemist | Earth | X Tectonic Shift at 0–9, Z Rising Thorn at 6–18 | **C Earth Wall** | 850 / 7 | east of the Cracked Footbridge (−88, 1, 98) |

**Nations:** Drachman, Xingnese and Aerugonian, matching the path's trainer.

**Tested:**
- All three spawned with the configured HP, level and nation.
- Each cast the right slot at the right range under its own brain:
  - Frost: X at 7 studs, C at 14;
  - Gale: X at 6, Z at 19;
  - Stone: X at 6, Z at 13.
- **Stone:** raised Earth Wall against a windup.
- **Frost:** raised Cryo Shift against a windup once its earlier Ice Shards trap had expired. While a trap is still live, the Frost Alchemist counts as busy and falls back to normal defence.
- 0 errors.

### Lindenmoor Run (new movement gauntlet)

**Course:** the existing Movement Gauntlet framework; the course is `Map.Lindenmoor.LindenmoorRun`, defined as `Rensei.Minigames.lindenmoor_run`.

**Route:**
1. Start pad north of the bridge.
2. Up the rock ramp onto the West Shelf.
3. **Along the cliff ledge.** The marker requires `LedgeWalk`, so you can't just walk past it.
4. Up to the lookout.
5. Expert and above: wade down Mill Creek.
6. Finish on the bridge.

**Numbers:**
- Time limits 90 / 80 / 70 / 80 / 70 s.
- MaxDistance 300.
- Reward: Exam × 0.4, twice a day (the same as the Foundation Run).

**Tested (Initiate):**
- **Passed in 62.6 s.** The route to the ramp and the long way back round the bluff were walked by the character (server MoveTo); the ledge leg used real keys.
- **Reward:** +24 Mastery training through the normal Exam allowance; a daily count of 1; the record shows Passed with best tier 1.
- **Walk-through:** a full on-foot run of the route took 66 s at walking pace.

**Not tested:** the higher bands (including the creek marker); a fully hand-played run; the touch controls.

### Files

- **Changed:** `TuningConfig` (3 enemies), `Rensei.Minigames` (`lindenmoor_run`).
- **Map:** `AlchemistSpawns` (+3 spawns), `Lindenmoor.LindenmoorRun` (5 markers and a start pad).
- **Backup:** `RenseiBackups["Pre-Phase8_2026-10-17"]`.

### Not done in Phase 8

These are deliberately left for later, as PROPOSALs:
- a trainer demonstration NPC;
- new puzzles;
- the Equivalent Exchange minigame;
- more progression nodes.

They need content or owner direction rather than more systems.

## 2026-10-17 — Phase 9: regression and playable-state audit

**Setup:** Studio Play, one client, real keyboard and mouse unless noted. The profile was snapshotted before testing and restored exactly afterwards (verified field by field).

| Area | Result |
|---|---|
| Spawn | The player spawns in the Lindenmoor square (earlier session) |
| Walk, jump, dash | Pass. Dash burst 107 studs/s; jump +7.5; the states run Jumping → Freefall → Landed → Running |
| Wall climb | Pass. Airborne Space at a tall wall → server `Climb` session; W climbed y 6.5 → 19.1; Space let go cleanly |
| Ledge walk | Pass (gorge ledge, real keys; see Phase 7/8) |
| Combat Mode and fists | Pass. E on; 4 × M1 ran Light1 → Light4; F blocked |
| Alchemy | Pass. Z cast Ignite (meter 100 → 75, cooldown started) |
| Class-skill hotbar | Pressing 1 in Combat Mode with an empty loadout did nothing, with no error. The full equip-and-use test is in the Class Skills changelog |
| Dialogue | Pass. E at the Drillmaster opened the dialogue with its choices, including the Combat Read drill; a choice closed it |
| Mastery menu | Pass. K opens on the Guide tab |
| Combat → reward | Pass. An M1 kill on a camp bandit credited +50 EXP (25 × level 2) and Mastery Defeat training |
| Errors | 0 game errors or warnings on the server and the client. The only errors were my own test-command mistakes |
| Save round-trip | Pass. After the restore, Play stopped and ProfileService saved. A read-only `GetAsync` of the stored profile (`PlayerData` / `Data<UserId>`, slot 1) **matches the pre-test snapshot field for field**, with the session lock released, so no test data leaked into the save. Reloading it in Play wasn't redone (the Studio connector got stuck starting Play). Loading the profile in Play worked in every session today |

### Findings

1. **K opens the Mastery menu on top of an open dialogue.** The dialogue's choices stay visible under the menu. It's cosmetic, and both still work. The fix would be to have UIState block the menu while a dialogue is open. Not changed.
2. **The prompt and Combat Mode share E.** In Combat Mode, E toggles Combat Mode instead of talking. Out of it, E talks. This looks intentional (prompts hide in combat); noted for the controls doc.
3. **Test artifacts (not game bugs), worth knowing when testing:**
   - a leftover `CombatState` attribute blocks the ledge walk;
   - movement is camera-relative, so teleporting a character without turning the camera reverses W/A/S/D;
   - scripted `Humanoid:MoveTo` can't drive the ledge walk, which reads the player's own input.

### Not covered

- Mobile/touch controls (no device emulation through the tools).
- Two players.
- Weapon classes other than fists in this pass. Guns and Sword were run earlier today; Greatsword, Rapier and Daggers M1 strings were not.
- The character creator and the queued UI list.
- A live server.

## 2026-10-17 — Starter map: Lindenmoor, a Countryside farm village (Phase 7)

**Added (owner: "Build the starter map as the Resembool-style Countryside farm village" and "use the model that's open in blender as well").** Layout doc: `Starter Map - Countryside Village Layout.md`. The name, layout, sizes and area texts are all PROPOSAL.

### Where

- **Location:** a new terrain region **south of the graybox hub**, centred on world (0, 8, −650). It spans about x ±330 and z −980..−296.
- **Hub link:** the north road ramps down to the baseplate and continues as a dirt strip to the hub at z −110.
- **Spawn:** players now spawn **in the village square** (`Lindenmoor.Square.LindenmoorSpawn`, a copy of the old spawn's settings).
- **Old spawn:** `Workspace.SpawnLocation` is **disabled, not deleted**. Set its `Enabled` back to true and disable `LindenmoorSpawn` to restore the old start.

### The Blender model

- The **RockbellHouse** scene open in Blender (unsaved) was **read, not changed**, through the Blender MCP add-on's local socket. The session's Blender tools weren't connected.
- Every piece of the model was measured: 249 box pieces with their exact position, rotation and size, plus colours averaged from each material's texture.
- **Rebuilt in Studio as Parts** (`ServerStorage.RenseiMapTools.HouseBuilder` + `RockbellHouseData`):
  - **Scale:** 1 m = 3.5 studs, so the 2.15 m door is 7.5 studs.
  - **Conversion:** Blender Z-up → Roblox Y-up.
  - **Rebuilt specially:** the gable becomes two wedges, the octagonal pole a cylinder, and the "AUTO MAIL" lettering a SurfaceGui text on the sign board.
  - **Skipped:** the ground and path planes (the terrain replaces them).
- **Why Parts and not a mesh import:** there's no file-import tool from here, and an EditableMesh MeshPart doesn't persist without publishing an asset to your account.
- **To use the real mesh and textures later:** export from Blender and import with Studio's 3D Importer. The house model's pivot (its ground origin) is where to drop it.
- **Uses:**
  - **Workshop Hill:** the model exactly as authored, with the sign, banner, utility pole, wires, low stone yard walls and mailbox. This is `Lindenmoor.Workshop.AutomailWorkshop`.
  - **Village:** the 9 houses are the same model recoloured. There are 5 palettes (the original cream/green, white/blue, peach/brown, pale blue/white, cream/red), without the sign, banner or yard props.
- **Material choices:** clapboard → WoodPlanks; shingles → Slate; stone → Cobblestone (Brick read pinkish); whitewash → Plaster; glass → Glass.

### What's there

| Feature | Notes |
|---|---|
| Village square | Cobblestone, a covered well, 4 benches, a notice board, the spawn |
| Roads | Dirt: the main N–S road to the hub, the E–W lane, the hill path, the farm track, the camp trail |
| 9 houses | Around the square and along both roads |
| Automail workshop | On Workshop Hill (+16), reached by the hill path |
| Mill Creek | Meandering, **about 1.2 deep and wadeable**. Deeper water (2.4) put characters into Roblox's default Swimming state, and swimming isn't designed yet (owner decision 6) |
| Stone arch bridge | Where the main road crosses the creek: ramps, parapets, arch ring, piers |
| Station | Platform with a ramp, a brick station house, a canopy, a "LINDENMOOR" sign, rails on sleepers (scenery) with buffer stops and a timber trestle over the creek |
| Farm | Red barn, hay bales, a fenced wheat field and a fenced cabbage field |
| Fences | Post and rail along the north road, the farm track and the fields |
| Lamps | 16 lamp posts with warm PointLights |
| Trees | 158: rows of cypress on Cypress Ridge, along the north road and around the hill; oaks behind houses and in the meadows; a thicket at the camp |
| Gorge ledge | A rock cliff on the creek's north bank with an **authored `RenseiLedge`** strip (46 long, 1.4 deep, Front face toward the cliff). There's a shelf at each end: the West Shelf (reached by a ramp) and the East Shelf, which joins the Gorge Lookout plateau (with a bench). The bluff above has steep sides |
| Bramble Hollow | Bandit camp: two tents, a fire pit (Fire + light), log seats, crates, and **2 `Grunt` spawns** (`RenseiEnemySpawn`, copied from the existing GruntSpawn) |
| Discovery areas | 8 `RenseiArea` volumes (no overlaps): Lindenmoor (×2 boxes), Workshop Hill, Mill Creek Bridge, Lindenmoor Station, Cypress Ridge, Bramble Hollow, Gorge Lookout. Each has PROPOSAL descriptions |
| Entrance sign | "LINDENMOOR" signpost on the north road, readable both ways |

- **Parts:** about 3,430 in `Workspace.World.Map.Lindenmoor`. Small props don't cast shadows. Area volumes have no collision, query or touch.
- **Terrain:** about 79k cells; it was empty before.

### Map tools (`ServerStorage.RenseiMapTools`, used only in Edit; nothing requires them at runtime)

| Tool | What it does |
|---|---|
| `LindenmoorGen` | The layout (roads, plots, features) and the heightmap/material functions |
| `TerrainWriter` | Writes the terrain from `LindenmoorGen` |
| `RockbellHouseData` | The Blender model's pieces |
| `HouseBuilder` | Builds a house from the data, with optional palette, props, sign and banner |
| `Templates.AutomailHouse` | The built house |

**Terrain detail:** Roblox draws a voxel's surface half a voxel (2 studs) above `y0 + occupancy × 4`. The writer compensates, so the terrain lands on the designed heights. Measured: mean error 0.06 studs over 650 samples; every house sits exactly on its pad.

**Backup:** `ServerStorage.RenseiBackups["Pre-StarterMap_2026-10-17"]` holds the old SpawnLocation and a README with the revert steps (delete the `Lindenmoor` model, clear the terrain, re-enable the old spawn, delete the map tools).

### Tested (Studio Play, one client)

- **Spawn:** the player spawned in the square (root at y 11 on ground 8). Discovery fired for "Lindenmoor".
- **Bandit camp:** 2 bandits spawned at Bramble Hollow.
- **Gorge ledge (real keys):**
  - stepping onto the strip started `LedgeWalk` within 0.6 s;
  - walking west → stepped off onto the West Shelf at the strip's end;
  - walking east → one session along the full 41 studs → stepped off onto the East Shelf and onto the lookout. The server never ended it.
- **Hill path:** the character walked from the lane up to the workshop (Humanoid MoveTo reached every waypoint).
- **Creek:** wading along the bed stayed in the Running state (no Swimming) at 1.2 deep. At 2.4 deep it swam, so the depth was lowered.
- **Errors:** 0 game warnings or errors on the server and the client (only Roblox CoreGui UIBlox warnings).
- **Profile:** area discovery writes `Areas` to the profile. The new areas (Lindenmoor, Mill Creek Bridge, Workshop Hill, Gorge Lookout) were removed after each session. The profile was verified unchanged otherwise (Mastery all zero, level 1, 0 EXP, empty flags/minigames/skill tree/loadout) before Play stopped.

### Not tested

- Walking every road, fence line and house pad by hand (spot checks only).
- The station platform ramp and the bridge with real input (geometry checked visually).
- Fighting the camp bandits.
- Performance on a low-end device or mobile (about 3.4k parts plus 16 lights).
- Two players.
- The map edges: the terrain ends in a steep edge at the region's south, east and west borders. Barriers or more terrain are a later decision.

### Screenshots

In `images/Starter Map/`. 2–5 were taken before the terrain-offset fix (the ground sat 2 studs high, so foundations look slightly buried there); 1 is after it.

### Missing / owner decisions

- Villager NPCs and their dialogue. No content was invented; the existing hub NPCs weren't moved.
- House interiors (the houses are closed shells).
- A train.
- Real Blender meshes and textures (see above).
- Swimming and real water depth (decision 6).
- The name "Lindenmoor".

## 2026-10-17 — Mastery menu GUIDE tab (unified progression presentation)

**Added (unified prompt, Phase 4).** The new tab sits on top of the existing progression. No progression rules changed: Truth/Gate, 20 Mastery Points per stage and the hourly allowances are untouched.

### Mastery menu (K)

- **Tabs:** `Guide | [Path] Alchemy | Arms | Body | Class`. **GUIDE opens by default.**
- **Guide tab sections:**
  - **Standing:** level, stage, Mastery Points, stats.
  - **Ready now:** nodes you can learn this moment, in any category.
  - **One step away:** nodes missing exactly one thing, with the hint for it (deduplicated), e.g. "Needs level 5", "Learn Spin Kick first", "2 more Mastery Points".
  - **Where to progress:**
    - trainers (by `TrainerPath`, with compass direction and distance);
    - lessons and exercises, with today's count against the daily limit.
  - **Choices with consequences:** forks, and what each one closes off.
- **Clicking a row** jumps to that node in its own tab.
- A short explainer card at the top says how Mastery is earned.

### Data

`Rensei.SkillTree` gains:
- `SkillTree.Category(Node)` (Alchemy / Arms / Body / Class);
- `SkillTree.Missing(Data, Id)`, which returns what's missing with a kind (`Stage`, `Prereq`, `Stat`, `Level`, `Fork`, `MP`, `Maxed`) and a player-facing hint;
- `CategoryOrder`.

### Files and tests

- **Changed:** `Rensei.SkillTree`, `MasteryUI`.
- **Backup:** `RenseiBackups["Pre-ProgressionGuide_2026-10-17"]`.
- **Tested (Studio Play):** K opens on the Guide; every section rendered on a fresh profile; clicking rows jumped to the right node and tab. 0 errors.
- **Not tested:** a profile far into the tree (only a fresh profile and the test states); a touch device.

## 2026-10-17 — Challenge framework: difficulty bands, Combat Read, Movement Gauntlet

**Added (unified prompt, Phase 5).** This extends the existing `MinigameService`; it isn't a second framework.

### Difficulty bands (5)

The band comes from the stat that matches the challenge's track:

| Track | Stats |
|---|---|
| Combat | Strength / Speed |
| Movement | Speed |
| Alchemy | Alchemy |
| Knowledge | Intelligence |

| Band | Stat range |
|---|---|
| Initiate | 1–4 |
| Apprentice | 5–8 |
| Adept | 9–12 |
| Expert | 13–16 |
| Master | 17+ |

- **Reward multiplier by band:** 0.6 / 0.8 / 1.0 / 1.2 / 1.5 (PROPOSAL).
- **Rewards** go through `ProgressionService.AddTraining`, so the hourly allowance and the 20-per-stage rule still apply.
- **Daily caps:** a per-challenge daily limit kept in `Story.Flags` ("day:count").

### World challenges (new kind)

- In-world, with Begin / Tick / End hooks and a server watcher. A challenge ends on:
  - death;
  - entering combat (unless the challenge allows it);
  - walking too far away;
  - **GIVE UP** on the HUD tracker.
- **Combat Read** (`combat_read`):
  - Started from the Drillmaster's dialogue ("StartMinigame").
  - A sparring foe (15% damage, can't die) performs a band-sized plan of attacks. You must answer each correctly: block, parry or dodge, judged by the server from real hit results.
  - Rewards ×0.5, twice a day.
- **Movement Gauntlet** (`foundation_run`):
  - A timed checkpoint course (`RenseiGauntlet` tag, markers `CP1–CP6`).
  - Checkpoints can require a traversal kind (e.g. reach CP by ledge walk) or a minimum band.
  - Time limit per band: 70 / 70 / 85 / 85 / 70 s (PROPOSAL; higher bands add checkpoints).
  - Started from the pad tagged `RenseiChallenge` in `LedgeCourse.FoundationRun`.
- **HUD:** a ChallengeTracker panel shows the step, timer and result.

### Files and tests

- **Changed:** `MinigameService` (+ `MinigameService.WorldChallenges`), `Rensei.Minigames`, `MinigameUI`, `TuningConfig` (Enemies.Sparring), `SkillData`, `Rensei.Dialogues`; map `LedgeCourse.FoundationRun`.
- **Backup:** `RenseiBackups["Pre-ChallengeFramework_2026-10-17"]`.
- **Tested (Studio Play):**
  - Combat Read failed on wrong answers, and passed with a real block. The reward was +30 training, and the daily count was recorded.
  - The Gauntlet passed, including the checkpoint that requires a ledge walk.
  - A UI minigame closed when the player entered combat.
  - The profile was snapshotted and restored, and verified all zero before Play stopped.
- **Not tested:** bands above Initiate in play (the band math was checked, not played); two players running challenges at once; touch.
- **Not built (PROPOSAL from the brief):** the Equivalent Exchange minigame; a trainer demonstration NPC.

## 2026-10-17 — Alchemist NPCs cast the real abilities

**Added (unified prompt, Phase 6).** NPCs now run the same alchemy pipeline as players: meter, cooldowns, AttackRunner, hitboxes, block / parry / dodge. Before this, trial "alchemy" was only arena hazards.

### AlchemyService

- The cast body is factored into `RunCast(...)`. `AlchemyService.Cast(Player, Slot, Aim)` keeps every player check (affinity, built ability, clan rule, skill-tree unlock), then calls it.
- **New `AlchemyService.CastAs(Character, Affinity, Slot, Aim, Opts)`** for NPCs only:
  - refuses any player character;
  - needs Combat Mode, no cast in progress, and the character free to act;
  - `Opts.HoldFor` auto-releases charged moves.
- **New `AlchemyService.CanCastAs(Character, Affinity, Slot)`:** built ability, not casting, **free to act**, off cooldown, enough meter.
- **Player-only parts are skipped for NPCs:** the puzzle cost waiver, meter tells, puzzle reactions.
- **NPC meter** is earned the same way as a player's (Regen 0; filled by hits, blocks and parries).

### EnemyService (brain)

- `Def.Alchemy = {Affinity, Slots = {{Slot, Min, Max}}, Gap, Guard}`.
- When ready to attack, the NPC casts the first slot that is in range, in line of sight (no casting through map walls) and affordable. It stops, faces the target and casts. The gap between casts is a random `Gap` (PROPOSAL 1.5–3 s).
- **Guard reflex:** when its target winds up within 12 studs, an NPC with `Guard` raises it (Steel Guard), if it can act.

### Enemies (`TuningConfig.Enemies`, all numbers PROPOSAL)

| Enemy | Path | Casts | Health | Spawn |
|---|---|---|---|---|
| Field Alchemist | Flame | X (Scorching Wave) at 0–14 studs, Z (Ignite) at 7–40 | 650 | Burned Laboratory |
| Ward Alchemist | Metal | C at 0–12, X at 8–30, **Guard Z (Steel Guard)** | 800 | Silent Forge |

Both use the normal leash (60).

### Fixed during testing

`CanCastAs` didn't check "free to act", so the Ward's guard reflex passed its check while the Ward was mid-swing, and `CastAs` then refused it. `CanCastAs` now checks the same free-to-act rule. A busy Ward makes no cast attempt and falls back to its normal block/parry roll.

### Files and tests

- **Changed:** `AlchemyService`, `EnemyService`, `TuningConfig`; map `AlchemistSpawns`.
- **Backup:** `RenseiBackups["Pre-NPCAlchemy_2026-10-17"]`.
- **Tested (Studio Play, one client):**
  - `CastAs` on a player character is refused.
  - **Line of sight:** no cast through the Burned Laboratory wall.
  - **Field Alchemist brain:** cast X (Scorching Wave) up close, and Z (Ignite) at 20 studs.
  - **Ward Alchemist brain:** cast C at 9 studs and hit the player.
  - **Guard reflex:** an idle windup made the Ward raise Steel Guard; a windup during its own swing made no cast attempt.
  - **Player regression:** a real **Z** key press cast Ignite; cooldown and meter (100 → 75) behaved as before.
  - 0 game errors on the server and the client.
  - The profile was verified all zero before Play stopped. Combat training earned during the test (+2 progress) was reverted first.
- **Not tested:**
  - All 20 abilities through `CastAs` (only Ignite, Scorching Wave, the Metal C and Steel Guard ran).
  - The Ward's reflex from a natural player swing; the test fired the windup signal from the server, because the Ward's melee kept the player stunned.
  - Two players.
  - Balance and feel.
- **Limits:** the brain has no pathfinding (as before); alchemists walk straight at the target. There is no friendly trainer alchemist that demonstrates moves yet.

## 2026-10-17 — Class Skills: a dedicated column in the Mastery menu, equipped to the hotbar

**Added (owner prompt "Skill Tree & Class Skill Hotbar").** Design and audit: `Skill Tree Class Skills - Audit and Design.md`.

### Mastery menu (K): new CLASS tab

- **Tabs:** `[Path] Alchemy | Arms | Body | Class`. The first three are unchanged: alchemy moves, general combat techniques and passives.
- **Class tab layout:**
  - One column per class family: Fists · Sword · Rapier · Greatsword · Daggers · Guns.
  - The column for the class you're fighting as is lit and marked **EQUIPPED CLASS**.
  - Each column lists its skills in tier order (marks I / II / III) with links to their prerequisites.
- **Node states:** LOCKED / LEARNABLE / LEARNED / SLOT n.
- **Header line:** the current class's loadout.
- **Card:**
  - description, class, tier;
  - cooldown, stamina, number of hits, hyper armour;
  - whether it fits your current class;
  - an animation-missing warning if its animation can't load;
  - cost and requirements (hidden once learned);
  - **Learn** / **Refund** (the existing Mastery Point rules: refundable until the Truth/Gate trial seals the stage);
  - for a learned skill: **equip to key 1–4** and **Remove**.

### Skills (the skill sheet's names and animations; every number PROPOSAL)

| Class | Skills |
|---|---|
| Fists | Spin Kick, Bear Hug (grab), 540 Kick, Slam Dunk (grab), WHERE YOU GOING?! |
| Sword | Quick Draw, Iaido Barrage |
| Rapier | Speed Lunge, Ren |
| Greatsword | Heavy Drop, Whirlwind Cleave |
| Daggers | Slip Slash, Bullet Slash, Blood Dash (bleed), COME HERE!! |
| Guns | Iron Rush (grab) |

- **Requirements:** a prerequisite in the same column, a character level (tier I = 1, II = 5, III = 10), and 2–5 Mastery Points. All skills are in ring 1, so none waits on the unbuilt trial.
- **Hit times:** taken from each animation's own markers (HitFrame, Stab, Slash1/2, FirstHit/FinalHit). Where there are none, from its measured fastest-motion peaks.
- **Grabs:**
  - They're `UNBLOCKABLE`: they beat block and parry, and a dodge or i-frames avoid them.
  - On a hit, the victim is held: stunned, placed in front (never through a wall) and playing its victim animation.
  - On a miss, *Grab Whiff* plays and the move ends early.

### Families (`Rensei.ClassSkills.Families`)

- `Fists` = unarmed **and** Gauntlets (Caestus). The other five map one to one.
- Pending owner decision 1 on the Fist styles; changing this is a one-line edit.

### Hotbar

- **4 slots per family** (PROPOSAL), saved as profile `SkillLoadout[Family]`.
- **In Combat Mode:** keys **1–4**, and tapping hotbar slots 1–4 on mobile, use the equipped class skills. Slots 1–4 show the skill's name and a cooldown sweep with seconds; slots 5–0 dim.
- **Out of Combat Mode:** unchanged. Items are held as before (the server already refused items in Combat Mode, so nothing is lost).
- **Switching weapons** switches to that family's own loadout; nothing is deleted.
- **T** stays the weapon's built-in skill.

### Server (all decisions)

- **Learning:** `SkillTree.CanBuy` / `SkillTreeService.Buy`, plus a new **Level** requirement.
- **Equipping:** `SkillTreeService.Equip(Id, Slot)` / `Unequip(Family, Slot)` through `Requests.SkillTree`. It needs the skill learned and a valid slot, and is refused in combat. A skill is never in two slots. A refunded skill comes off its loadout.
- **Using:** `Requests.ClassSkill(Slot)`, where the client sends only the slot. The server checks:
  - Combat Mode on, alive;
  - not stunned, attacking, blocking, traversing, knocked, gripped or carried;
  - the skill fits the current family;
  - cooldown (kept server-side per player and skill, so a death doesn't reset it), stamina.

  Then it runs `AttackRunner.Run`: the existing hitbox, damage, block / parry, hitstop, interrupts and recovery. It's covered by the ServerHandler request rate limiter.
- **Data:**
  - `TuningConfig.ClassSkills` holds the combat numbers.
  - SkillData gains `Class_<Id>`, `Class_<Id>Final` and `Class_<Id>Grab`.
  - `AttackRunner` gains an optional `Opts.AfterStrike` hook, which skips the remaining hits after a missed grab.
- **Save:** `ProfileData.SkillLoadout = {}` is additive; Reconcile fills it on old saves (verified on a real Studio profile). No schema bump. Ownership uses the existing `SkillTree` table.
- **Animations:** the 20 skill-sheet animations moved from `Animations.Registry.Skills` to `Animations.Shared.ClassSkills`, so attackers and grab victims have them loaded.

### Files

- **New:** `Rensei.ClassSkills`, `Requests.ClassSkill`.
- **Changed:** `Rensei.SkillTree` (Class nodes, Level requirement), `TuningConfig` (ClassSkills), `SkillData`, `ProfileData`, `SkillTreeService`, `Requests.SkillTree`, `AttackRunner`, `MasteryUI`, `HUDUI`.
- **Backup:** `ServerStorage.RenseiBackups["Pre-ClassSkills_2026-10-17"]`.

### Tested (Studio Play, one client)

**Server rules** (real SkillTreeService, on a Studio profile; restored afterwards):
- learn works, and a second purchase is refused ("Already maxed");
- the level gate works (540 Kick: "Needs level 5");
- equipping something unlearned is refused;
- an equipped skill moves between slots rather than duplicating;
- Fists and Sword keep separate loadouts;
- a bad slot and a bad family are refused.

**Use** (real `Requests.ClassSkill`):
- Bear Hug grabbed the training dummy: it was snapped in front, and no whiff penalty was applied.
- Bear Hug with nobody near: whiff, the move ended at 0.30 s, and stamina 100 → 80.
- Spin Kick on the Blocking dummy and Quick Draw with a Sword each ran their full Startup / Active / Recovery.
- Refused: on cooldown, an empty slot, out of Combat Mode, no stamina, and bad slot values (no errors).

**Real input:**
- K opened the menu; the Class tab showed 6 columns and 16 nodes with the right states and the loadout line.
- Clicking the card's slot 3 moved Spin Kick to slot 3 (server-confirmed).
- E entered Combat Mode: slots 2 / 3 showed Bear Hug / Spin Kick and 5–0 dimmed.
- Pressing **3** ran Spin Kick: its animation played, with an 8 s cooldown sweep.
- E again restored the normal bar.

**Persistence:**
- Learned skills and the loadout survived a full Play stop and restart (save → load).
- The pre-existing profile gained `SkillLoadout` with no reset.

0 game warnings or errors on the server and the client.

**Found and fixed:** on a learned skill, the equip buttons sat just below the card's visible area. The card now hides cost and requirements once a skill is learned.

### Not tested

- A touch device (the hotbar slots are the existing tappable buttons, so tapping uses the same path).
- A grab on another **player** (only on an NPC dummy).
- Two players at once.
- Refunding an equipped skill (the code removes it from the loadout; not run).
- The Rapier, Greatsword, Daggers and Guns skills beyond their definitions compiling. Only Spin Kick, Bear Hug and Quick Draw were actually run.
- Hit feel and balance.
- A live server.

**Test-data note:** one Studio session stopped before the profile restore ran, so the test's +20 MP, three learned skills and loadout saved to the Studio profile. They were reversed exactly in the next session and verified after a further restart: 0 MP, nothing learned, empty loadout.

## 2026-10-17 — Guns: M1 is a pistol whip; shooting is its own mode

**Changed (owner, non-negotiable: "M1 with a gun is a melee pistol whip and never fires a bullet"):**

**What was wrong:** `FistSwing` sent a gun's M1 down a `Ranged` branch that fired a hitscan shot (`WeaponManager.Fire`), and the gun's "light" hits *were* shots.

**M1 now:**
- **4-hit pistol-whip string** through the normal light-attack pipeline (AttackRunner, server hitbox sweep, block / parry / posture / stun, the combo chaining rules).
- The gunshot branch is removed from `FistSwing`, so **M1 cannot reach `WeaponManager.Fire`**: no round spent, no tracer, no raycast.
- No pistol-whip animation exists on any sheet, so it uses the published fist combo (FistCombo1/2/3/5), which the guns' heavy already used.

**Shooting mode:**
- **Y** (rebindable "Aim (Guns)" in Settings) toggles it, with a gun drawn in Combat Mode.
- While it's on, **RMB fires**. RMB is Feint the rest of the time. **M1 stays the pistol whip even in shooting mode.**
- The server owns the mode (character attribute `ShootingMode`) and ends it when Combat Mode ends, the gun is put away or changed, or the character is knocked, gripped, carried or dies.
- Each shot is `Requests.Shoot("Fire", AimDir)`. The server checks:
  - the mode, the gun, Combat Mode;
  - free to act (not stunned, attacking, blocking, traversing or downed);
  - a round in the magazine and not reloading.

  Then it runs through AttackRunner + `WeaponManager.Fire` (aim validated, range, raycast, DamageManager rules). Fire rate is the gun's Recovery (one attack at a time).
- The shots moved to `TuningConfig.Weapons.Guns.Shots` (SkillData `Guns_Shot1–4`).
- **Visuals:** a crosshair and a mode hint on the HUD while shooting mode is on.
- **Mobile:** an **AIM / STOP** button (Slide's spot, which is hidden in Combat Mode) and a **FIRE** button that only shows while shooting.

**Ammo / reload:**
- Unchanged by design. Per-gun magazines (Revolver 6, Renetti 15, Forge Tac 7, Sykov 10) are kept while holstered.
- **Automatic reload when empty** (`Decisions.md`: "Guns: no reload button, automatic only").
- There is no reserve-ammo system; magazines refill.
- No shot can go out during a reload. CooldownUI already shows rounds and the reload bar.

**Also updated:**
- `EnemyService` gunners fire with the new `Shots`.
- Fan the Hammer (T) is unchanged; it's its own input.

**Files:**
- **Changed:** `TuningConfig` (Guns.Light = pistol whip, Guns.Shots), `SkillData`, `FistSwing`, `WeaponManager` (clears `ShootingMode` on unequip), `EnemyService`, `Requests.CombatMode`, `Keybinds`, `Rensei.Settings` (Aim bindable), `ClientHandler`, `HUDUI`, `MobileControls`, the Settings panel (new "Aim (Guns)" row).
- **New:** `Requests.Shoot`.
- **Backup:** `RenseiBackups["Pre-GunRepair_2026-10-17"]`.

**Tested (Studio Play, real keyboard and mouse, Revolver given to the character, no profile change):**
- 4 × M1 → `Guns_Light1–4` (pistol whip), ammo stayed **6/6**.
- Y → shooting mode on, crosshair shown.
- M1 in shooting mode → pistol whip, ammo unchanged.
- RMB → `Guns_Shot1`, `Guns_Shot2`, ammo 6 → 5 → 4.
- Emptied the magazine → automatic reload; an RMB during the reload fired nothing; refilled to 6.
- Y → mode off; RMB then fired nothing.
- Y then E (leave Combat Mode) → shooting mode ended by itself.
- An enemy Renetti gunner fired `Guns_Shot1–4` and hit the player (580 → 489).
- 0 warnings or errors on the server and the client.

**Not tested:** mobile buttons on a touch device; the Settings rebind of Aim; two players.

**Missing assets:** a pistol-whip animation; published gun shot animations (`Guns_Light1–4` are Studio-only saves); gunshot, muzzle-flash and reload sounds and VFX.

## 2026-10-17 — Ledge walk reworked: authored ledges, facing the wall

**Changed (owner reference: the Tomb Raider narrow cliff-ledge walk).** The earlier version auto-detected ledges from geometry and put your back to the wall. It's replaced.

### Authoring convention (for map builders)

- Make a thin part along the wall: about 1.4 deep and 1 high, its top face is the foothold.
- **Tag it `RenseiLedge`** (CollectionService; Tag Editor in Studio).
- Turn it so its **Front face points at the wall**. Its length (Size.X) is the whole walkable path; its two ends are the endpoints. Keep it level.
- **Joining:** two ledges whose ends are within **1.5 studs** (and within 0.75 studs in height) join. A straight joint continues; an angled joint is a supported corner.
- **Exits:** past an end with walkable ground just beyond it (a platform), the player steps off onto it.
- **Every other end stops the player:** a gap, a dead end, or an unsupported corner. There are no automatic jumps.
- Untagged parts and ordinary walls are never traversable.

### Behaviour

- **Enter:** stand on a ledge for 2 checks (0.3 s), by walking onto it or dropping onto it. You turn to **face the wall**, held about 1 stud off it.
- **Move:** the move input (camera-relative, like walking) projected along the ledge, at 5 studs/s.
  - Obstacles stop you.
  - At a joined corner the body turns smoothly and the travel direction sticks while the input is held.
- **Leave:**
  - step off at a platform end;
  - hold away from the wall for 0.3 s (step down);
  - **Space** = hop back off the wall;
  - **Space while pushing toward the wall** = hop up into the existing **climb**;
  - the server ends it (stun, knock, grip, carry, death, or the body leaving the authored strip).
- Combat, dash, sprint and crouch are off on the ledge (the `Climbing` status). No stamina cost.
- **Server:** `MovementState` accepts `LedgeWalk` only over an authored strip, inside its endpoints plus a 1.5-stud lag tolerance. It re-checks every 0.5 s and ends it with reason `OffLedge`.

### Graybox test course

`Workspace.World.Map.LedgeCourse` (delete it when real map ledges exist):
- **L1:** platform → gap.
- **L2:** gap → supported inner corner → **L3** → platform.
- **L5:** platform → unsupported outer corner.
- An **untagged look-alike strip** against an ordinary wall.
- Two ramps.

### Fixed during testing

- The head and hair touched the wall at a 0.75 gap and tipped the body back about 12°. The gap is now 1.0 and the body is level.
- Character-relative input made the player ping-pong at platform exits when the camera faced the other way. Input is now camera-relative, with a sticky direction at corners.
- The ledge → climb hand-off fired before the body was airborne. It now waits for the airborne state.

### Tested (Studio Play, real keys, the test course)

- Entry on L1 (server-confirmed, facing the wall, level).
- Left and right; stops at L1's gap end.
- Steps off at L1's start platform and stays off (no re-grab loop).
- L2 → inner corner → L3 → end platform in **one session**: the body turned to face WallB, kept moving with the input held, and stepped off onto the platform.
- Stops at L5's **unsupported outer corner**.
- **No** ledge walk on the untagged look-alike strip.
- Space = hop off.
- **W + Space = climb** (server `Climb` session, climbing up).
- Stun → ended (`Stun`), Climbing status removed, one re-entry after.
- Death → ended (`Dead`); the respawned character starts clean.
- Forged ledge requests in the open and beside an ordinary wall → `Refused:NoLedge`.
- A ledge walk whose body is moved off the strip → ended about 1.4 s later.
- 0 warnings or errors on the server and the client.

### Not tested

- Touch controls (they use the same `MoveDirection` and Jump action).
- Two players watching each other.
- Long repeated-traversal soak.
- Real map ledges (none exist yet).

### Limits

- The server's 1.5-stud lag tolerance means a gap narrower than about 3 studs doesn't trip the server check. The client still always stops at gaps.
- **Animation:** the only ledge animation ("Wall Ledge Walk Left") is posed **back to the wall**. It plays as a stand-in, but a face-the-wall sidestep (left, right, idle), plus entry, corner and pull-up animations, are needed. Put the new name in `TuningConfig.LedgeWalk.Anim`.

## 2026-10-17 — Standing ledge walk

**Added (owner: "build the standing ledge-walk that the existing animation supports"):** `JumpManager.LedgeWalk`, a client module that is part of JumpManager, not a separate controller.

**What it does:**
- **Entering:** walk onto a narrow ledge and you step into it automatically. The ledge needs:
  - a tall wall within 2.5 studs;
  - ground at most 3 studs wide out from the wall;
  - a drop of at least 6 studs past the edge.

  The conditions must hold for 2 checks in a row (0.3 s), so brushing past a ledge never snaps you onto it.
- **On the ledge:**
  - Your back is to the wall, held 0.9 studs off it by the climb's AlignPosition / AlignOrientation movers.
  - You sidestep at 6 studs/s with the move input (WASD or the thumbstick), projected onto the wall.
  - Gentle curves are followed. Sharp corners stop you.
- **Stops (you stay on the ledge):** the ledge's end, an obstacle, or a corner.
- **Ends:**
  - the wall ending: you walk on normally;
  - the ledge widening into a platform;
  - holding away from the wall for 0.3 s: you step off (a tap doesn't);
  - Space / the jump button: you hop up and away;
  - the server ending it: stun, knock, grip, carry or death.
- **Locked out on the ledge:** combat, dash, sprint and crouch, via the `Climbing` status the server sets for every traversal kind.
- **Stamina:** none.

**Animation:**
- `LedgeWalk_Left` (sheet 129382412379032) moved from `Animations.Registry` to `Shared.Movement.Default`, so clients preload it.
- Moving right plays it backwards until a Wall Ledge Walk Right exists.
- Standing still holds its first frame, because there's no ledge idle yet.

**Server:**
- `MovementState` gains the kind `LedgeWalk`. A start needs a wall in reach **and** ground under the feet, and both are re-checked every 0.5 s.
- New JumpRemote call `TraversalState(State, Kind, Seq)` covers any kind. `ClimbState` stays for compatibility.

**Client backoff:**
- The client doesn't ask while it can see `Stun` / `Climbing` on itself (crouch included).
- After the server ends or refuses a ledge walk, it waits `RefusedCooldown` (2 s) before asking again.

**Config:** `TuningConfig.LedgeWalk` (all values PROPOSAL). `FaceWall = true` flips the pose to face the wall, if the animation turns out to be meant that way.

**Other:** SettingsUI's shift lock leaves AutoRotate alone during the ledge walk too.

**Backup:** `ServerStorage.RenseiBackups["Pre-LedgeWalk_2026-10-17"]` (JumpManager, MovementState, ServerHandler, TuningConfig, SettingsUI). To restore, also delete `JumpManager.LedgeWalk` and move `LedgeWalk_Left` back to the Registry.

**Tested (Studio Play, one client, on a temporary graybox ledge built only inside the Play session):**
- Auto-entry: the server confirmed it, the character has its back to the wall at 0.9 studs, and the animation is paused.
- **D:** sidestepped right at 6 studs/s with the animation reversed. Walking into the wide platform ended the walk and normal walking resumed.
- **A:** sidestepped left and stopped before a crate. With the crate removed, it stopped at the ledge's end (x = −215) instead of walking off.
- **W:** a short tap kept you on the ledge. Holding it stepped you off; you fell, with movers cleared and AutoRotate restored.
- **Space:** hopped off, up and away from the wall.
- **Server stun:** ended it (`Stun`), removed the `Climbing` status and the client let go. There were no requests during the stun and one re-entry after it.
- 0 game warnings or errors.

**Not tested:**
- Mobile thumbstick and jump button (they use the same `MoveDirection` / Jump action, but haven't been tried on a touch device).
- Curved walls.
- Real map ledges (there are no narrow ledges in the graybox map yet).
- Two players at once.
- A live server.
- Whether the pose reads right with the back to the wall: the animation's arms sit behind the body, which suggests back to the wall, but it's the owner's call.

**Found and fixed during testing:** while the server kept refusing (for example a lingering stun), the client retried every 0.8 s. It now pre-checks its statuses and backs off.

**Still missing (assets):** Wall Ledge Walk Right, a ledge idle, and hang / shimmy / mantle animations for the hanging version.

## 2026-10-17 — Movement state foundation: a server-owned traversal state, and the JumpRemote fixes

**Added: `ReplicatedStorage.Modules.Managers.MovementState`.** It holds the one traversal state of each character, and only the server writes it.

**Character attributes:**
- `Traversal` = `Climb` or `WallRun`. `Ledge` and `Swim` are reserved for their phases. nil means on foot or airborne.
- `TraversalSession` = `"<seq>:<kind>:<reason>"`. It is a single string, so it changes atomically.

**Start (JumpRemote `ClimbState` → `MovementState.Request`):** the server refuses unless all of these hold:
- the character is alive;
- it is not knocked, gripped, gripping, carried or carrying;
- it is not stunned;
- a map wall is in reach: 16 raycasts at body and head height, `Traversal.ValidateReach` = 9 studs.

**End:** the server ends the state on:
- stun (the WCS `StatusEffectAdded` / `Started` signals);
- the downed attributes being set;
- death;
- the wall leaving reach (2 checks in a row, checked every 0.5 s, and only while a traversal is active);
- a wall run outliving `WallRunDuration` × Acrobat + 1 s.

It also starts and stops the `Climbing` status. That fixes stacked `Climbing` statuses that could linger, since the old stop removed only one.

**Client (`JumpManager`):**
- Every climb or wall run is a numbered session.
- When the server ends or refuses the client's *current* session, the client lets go (`LetGoClimb` / `EndWallRun`). Client and server can no longer disagree about being on a wall.
- **New behaviour:** being stunned, knocked or gripped now drops you off a wall. Before, a stun never broke a climb.
- A late "ended" for an older session is ignored.

**Fixed: JumpRemote `ClimbState`.** It used to start or stop the `Climbing` status on any request, with no checks. It is now validated as described above.

**Fixed: JumpRemote `PlayFX`.** It used to broadcast any effect module, with any arguments the client sent, to every player. Now:
- **Allowed types:** only `Climb` (side, and only while the server has you climbing), `WallJump` (optional side), `Roll` (a finite, non-zero direction, normalised server-side) and `DoubleJump` (only if enabled).
- **Rejected:** dead or downed characters.
- **Throttle:** at most one per type per `Traversal.FXMinInterval` (0.12 s).

**Config:** `TuningConfig.Traversal` (ValidateReach, CheckEvery, MissesToEnd, WallRunGrace, FXMinInterval). All values are PROPOSALs.

**Wiring:** `CharacterHandler` calls `MovementState.Track(Character, CharacterState)` for every player character. All state lives in plain tables and is dropped when the character is removed.

**Not changed:** climb and wall-run feel, speeds, stamina costs and controls. The dormant `Skills.Combat.Air` (an older WCS copy of climbing, never given to any character) is untouched.

**Backup:** `ServerStorage.RenseiBackups["Pre-MovementState_2026-10-17"]` (JumpManager, CharacterHandler, TuningConfig). To restore, also delete `Managers.MovementState`.

**Tested (Studio Play, one client):**
- **Server logic**, through the real modules, 16 checks, all passing:
  - refused with no wall in reach;
  - accepted at a wall;
  - bad kind and NaN session number handled;
  - stun ends it;
  - a stale stop for an older session is ignored and the current stop works;
  - knocked ends it and refuses a new one;
  - moving away from the wall ends it (`NoWall`);
  - a wall run hits the time cap at about 4 s;
  - death ends it.
- **PlayFX:** an unknown type, a NaN direction, a bad side, a non-string type and throttled repeats are all refused without errors.
- **Real keyboard input:**
  - Space on a wall grabbed it and the server confirmed it. A server-side stun then made the client let go: anchors removed, AutoRotate back, climb pose stopped.
  - A second climb (W held to the top) was confirmed and then ended by the vault, with no false drop.
  - Holding Space beside a wall started a wall run, the server confirmed it, and releasing Space ended it.
- No script errors.

**Not tested:**
- Two players at once.
- Mobile touch input.
- High ping (the 9-stud reach includes latency slack, but it hasn't been tested at 200 ms+).
- A live server.
- The tests used lowered gravity (only in the Play session) to have time to press keys.

**Known limit:** climb stamina is still charged by the client's requests. A modified client could skip the charges and hang on a wall indefinitely. The server now ensures there is a real wall, but it doesn't drain climb stamina itself.

## 2026-10-17 — Animation sheet pass 3: weapon M1 / crit swaps and the Registry

**Changed (owner: "use the new Katana M1, Greatsword M1 + crit and Dagger M1 + crit IDs from the sheet"):**

**Swapped to the sheet's IDs.** All of these are published under the Rensei group, and each old ID is kept as the `PreviousId` attribute:
- **Katana M1 1–4** → `Sword_Light1–4`. The Rapier borrows lights 1, 3 and 4, so it picks these up too.
- **Greatsword M1 1–4 and CRIT** → `Greatsword_Light1–4` and `Greatsword_Heavy`. The Greatsword dash attack also gets the new light 1.
- **Dagger M1 1–4 and CRIT** → `Daggers_Light1–4` and `Daggers_Heavy`.
- **Live effect:** the Daggers and Greatsword M1s were Studio-only saves before, so they now play in a live server for the first time.

**Timing (`TuningConfig`):**
- `AnimPeak` is now each animation's `Hit` keyframe:
  - Sword: 0.35 / 0.32 / 0.32 / 0.30
  - Greatsword: 0.53 / 0.52 / 0.53 / 0.60, crit 0.83
  - Daggers: 0.37 / 0.40 / 0.45 / 0.42
- The Dagger CRIT has no marker, so it uses its measured fastest motion, 0.54.
- The dash attacks that borrow these swings (Rising Cut, Cleaving Charge, Shadow Step) were updated to match.
- Startup, Active, Recovery, damage and hitboxes are unchanged.
- Dagger M1 3 reaches AttackRunner's 2.2× speed cap. Its hit frame still lands inside the active window.

**Alchemy kept as it was:**
- The previous Greatsword heavy is now `Shared.Alchemy.Alchemy_GreatswordOverhead`.
- Coldsteel Smash (Ice X) and Alloy Divider (Metal V) point at it, so their placeholder swing doesn't change.

**New folder `Assets.Animations.Registry`:**
- It holds 59 sheet animations that load but aren't used by any system yet:
  - movement: swim, ledge walk, walk left, fall / glide
  - class grips: Caestus, Daggers, Greatsword victim
  - misc: berserk, lock pick, assassinate, "No!"
  - 9 NPC idles
  - the **Boxing** and **Lethwei** style sets
  - all 20 skill-sheet animations
- AnimationManager finds them by name (server and NPC playback). Clients **don't** preload this folder, which keeps each character at about 140 loaded tracks, under Roblox's 256 limit.
- Move an animation into `Shared` / `Weapons` when a system starts playing it on players.

**Backup:** `ServerStorage.RenseiBackups["Pre-AnimSheet3_2026-10-17"]` (TuningConfig and the whole Animations folder, including the removed Studio saves).

**Tested (Studio Play, one client):**
- 21 of the swapped, preserved and registered animations load on the client Animator. Each reports its real length, so the ID is valid at runtime.
- AttackRunner was run with the real TuningConfig definitions for Sword, Greatsword and Daggers (M1 1–4 and heavy each). The client played every new animation at the expected speed: Sword 1.25 / 1.14 / 1.14 / 0.86, Greatsword 1.15 / 1.13 / 1.15 / 1.13 with crit 1.34, Daggers 2.00 / 2.16 / 2.20 / 1.75 with crit 1.54.
- An NPC played `NPC_TaiChi` from the Registry by name.
- No script errors.

**Not tested:**
- Hits on a target (the swings were whiffs).
- The keyboard / mouse input path: the simulated clicks didn't reach the game, so the swings were started through AttackRunner directly.
- A live server.
- How the new swings look next to the Greatsword's shoulder-carry pose.

**Still broken (bad uploads, need re-upload):** Greatsword Idle / Sheathe / Unsheathe / Walk / Grip / KO, Katana Sheathe / Unsheathe / Walk, Dagger Sheathe / Unsheathe.

## 2026-10-17 — Leaderboard: level column removed

**Changed (owner: "remove level from the leaderboard"):** the board now has three columns: Name, Title, Nation (`HUDUI`).
- **Level:** still shown on the hover / tap player card.
- **Sorting:** rows still sort by level, highest first.

**Tested (Studio Play):** the header reads NAME, TITLE, NATION and the row fills the three columns, with no script errors.

## 2026-10-17 — Leaderboard: Tab to show / hide

**Changed (owner: "make it so were you can close and open the leaderboard with tab"):** **Tab** toggles the leaderboard (`HUDUI`, ContextActionService action `RenseiLeaderboard`).
- **Starts:** shown.
- **While typing:** nothing happens (ContextActionService skips focused text boxes).
- **On hiding:** an open player card closes too.
- **Other keys:** nothing else in the game uses Tab; Roblox's own player list is already disabled.

**Tested (Studio Play):** two real Tab presses took the board from shown to hidden to shown, with no script errors.

## 2026-10-17 — Leaderboard: Nation instead of Clan

**Changed (owner: "change clan with your nation you choose when creating your character"):**
- **Leaderboard column:** the fourth column is now **Nation**, the nation picked in character creation (`Identity.Origin`, shown by its `Rensei.Customization.Nations` name). It shows "None" before a character exists.
- **Player card:** shows "Nation: …" in place of "Clan: …".
- **`RankService.Publish`:** publishes a `Nation` attribute and no longer publishes `Clan`.
- **Unchanged:** clans themselves (surname, rolls, the Marcoh rule) work as before; they're just not on the leaderboard.

**Tested (Studio Play):**
- The board header reads NATION, and the card line works.
- The save slot loaded in Studio (slot 1) has no character, so it shows "None".
- The character in slot 2 (Xingnese) wasn't loaded, so a real nation name was not seen on screen.

## 2026-10-17 — Leaderboard: Name, Level, Title, Clan + player card

**Built (owner prompt: "Secure Roblox RPG Leaderboard Upgrade"; then "make the leaderboard ui off the ui asset we have in game"):**
Backup: `ServerStorage.RenseiBackups["Pre-Leaderboard_2026-10-17"]` (HUDUI, ProgressionService, AdminService, AdminUI, ServerHandler).
- **Columns:** Name (Roblox display name), Lv, Title (earned alchemist rank), Clan ("Unclanned" when none).
- **Sorting:** level, then rank, then display name, then UserId.
- **Updates:** event-driven from attribute changes; the old 1 s polling loop no longer drives the board.
- **Scrolling:** after 10 rows.
- **Your own row:** tinted gold.
- **Art:** the game's own HUD pieces:
  - the Server Info header banner ("PLAYERS"),
  - the Server Info panel,
  - the `LeaderEntry` row bar behind each row.
- **Player card:**
  - Hover a name (or tap it on mobile) for the card: @username, display name, level, title, clan, rank 1–4 with its description, license status, and the next-rank / eligibility line.
  - A click or tap pins the card; a click or tap elsewhere closes it.
  - A short grace period stops it flickering between the name and the card.
  - The card closes if that player leaves.
- **Ranks** (`Rensei.Ranks`, `RankService`, server-authoritative):
  - Apprentice 1–5.
  - State Alchemist 6–10: needs the `StateLicense` flag. Reaching level 6 alone only makes you eligible.
  - Master Alchemist 11–15: needs `Promotion_Master` and rank 2.
  - Philosopher's Tier 16–20: WIP, never granted.
  - Promotions are Story flags that only the server sets, checked for level and order.
  - `RankService.Publish` runs from `ProgressionService.Sync` and on join, and writes the read-only Player attributes `Rank`, `Title`, `RankStatus`, `StateLicense`, `Clan` and `ProfileReady`.
  - No new remotes.
- **Clan:** the existing system (`Identity.Clan`, `Rensei.Clans`).
- **Admin panel:** a new `SetRank` command (1–3, server-checked) with a Rank row under Alchemy, for testing.
- PROPOSAL: the flag names. No quest grants the License or the Master promotion yet.

**Tested (Studio Play, one client):**
- Level 1 can't be promoted; level 6 without the license stays Apprentice and shows "Eligible…".
- License → State Alchemist. A repeat grant is refused, and skipping straight to rank 3 is refused.
- Level 11 + promotion → Master Alchemist.
- Level 16 shows "not open yet (WIP)", and rank 4 can't be granted.
- Clan shows "Unclanned", then the character's clan.
- A level change updates the row live.
- Hover, hover onto the card, leave, click-pin, and click-away all behave as described.
- Loading state shows "Loading".
- A client rewriting its own attributes changes only its own screen; the server's values are unchanged.
- The save was snapshotted and restored.

**Not tested:**
- Multiple real clients: duplicate display names, equal levels, a player leaving with their card open, other clients' views.
- Touch on a real phone.

## 2026-10-17 — Alchemy acquisition & mastery questlines

**Built (owner prompt: "RENSEI — ALCHEMY ACQUISITION & MASTERY QUESTLINES"):** a questline per alchemy path that grants the path, plus practice with the trainer afterwards. Design, decisions and test table: `Documents/Alchemy Acquisition and Mastery.md`. Backup: `ServerStorage.RenseiBackups["Pre-AlchemyQuests_2026-10-16"]`.
- **Five questlines** (`acq_flame` "The Unburned Lesson", `acq_ice` "The Stillness Beneath", `acq_earth` "The Weight of Foundations", `acq_wind` "The Invisible Equation", `acq_metal` "The Unyielding Principle"), each started from its trainer (Calda, Veyra, Holt, Ansel, Brannoc):
  1. Invitation: go to the site.
  2. Fieldwork: three clues, an optional research note, then a Case Board deduction.
  3. Experimentation: a station puzzle.
  4. Trial: a fight in an arena next to the site.
  5. Exam: a harder puzzle, opened from the trainer's dialogue.
  6. Recognition: the trainer grants the path.
- **One path per character.** Starting a questline needs no saved path, and only one questline can run at a time. Other trainers still talk and share lore, but won't teach. The reward sets `Identity.Affinity` only if it's empty, adds the `Acquired_<Path>` flag, 600 EXP and Quest training. X/C/V stay in the Mastery tree.
- **Puzzles** (new kinds; the server keeps the answer and explains what went wrong):
  - Flame: ReactionControl.
  - Ice: PhaseSequence.
  - Earth: LoadPaths.
  - Wind: PressureRouting.
  - Metal: MaterialMatch.
- **Trials** (`TrialService`, `Rensei.Trials`): the foe is an Elite clone, and the server runs telegraphed hazards:
  - Flame: fire rings and burn.
  - Ice: frost rings and Freeze.
  - Earth: rockfall and a tremor band.
  - Wind: gust lanes that push.
  - Metal: cleave lines.
  
  After each hazard the foe opens up, taking more damage with its guard down. You lose if you're knocked, time runs out, or you stay out of the arena for 6 s. A hint shows after two losses.
- **Mentor practice** (`TrainingService`, `Rensei.Training`):
  - A daily lesson puzzle.
  - An exercise drill, 6 a day.
  - Both pay through `AddTraining`, so the stage's 20 MP cap and the Truth/Gate still hold.
- **Research notes:** evidence marked `Research = true`. The Journal tags them "(research note)".
- **Engine changes:**
  - `StoryLogic`: new `NoAffinity` and `SavedAffinity` conditions; `Quest.Is = "NotActive"`.
  - `QuestService`: new `Affinity` and `Training` rewards.
  - `DialogueService`: new `Lesson` and `Exercise` actions.
  - `ProgressionService.AddTraining`: takes an `Active` flag.
  - `MinigameService`: refuses to open during combat, with a message.
  - `DownedManager`: applies `DamageTakenMult`.
  - `EnemyService`: no block or parry while `GuardDown`.
- **World:** five graybox sites and five arenas in `World.Map` (moveable folders).
- All numbers are PROPOSALS.

**Tested (Studio Play, all five paths end to end):**
- dialogue → visit → clues (prompt shown at each) → wrong and right deduction → puzzle fail and pass → trial (hazards, guarded vs opening damage, win) → exam → recognition (path saved, EXP, MP);
- the lesson and exercise payouts, plus the "another path" and "another questline running" refusals;
- 15 puzzle definitions × 20 seeds solved.

The test player's save was snapshotted and restored around every run.

**Fixed during testing:**
- A puzzle opened during combat was dropped silently.
- Earth's soft-ground columns showed as rock: a sparse table lost its keys over the remote.
- Wind panel overlap.
- Metal pickers too small for touch.
- Doubled "(optional)" labels.

**Not built:**
- Practical exams (real casts at mechanisms).
- Placement on the real map.
- Respec.

**Scripts exported (byte-identical to Studio):**
- New: TrialService, TrainingService, Trials, Training, AlchemyMinigames, AlchemyMinigameUI.
- Updated: StoryLogic, QuestService, Progression, ProgressionService, DialogueService, MinigameService, MinigameUI, ServerHandler, DownedManager, EnemyService, TuningConfig, Quests, Evidence, Investigation, Minigames, Puzzles, Dialogues, JournalUI, WorldService.

## 2026-10-16 — Smaller HUD, sheet animations pass 2, evidence props

**Asked (owner):** "Some of the UI is too big: Party UI, Level Up UI, Quest UI, etc. make them readable but not too big"; "look through the spreadsheet again and add in the animations wherever you can"; "for the investigative quests … look for suitable small items like notebooks, trinkets"; "look through the assets for any suitable armor, runes". Backups (per place): `RenseiBackups["Pre-UISize_2026-10-16"]` (the whole `StarterGui.Uis`), `["Pre-Anims2_2026-10-16"]`, `["Pre-EvidenceProps_2026-10-16"]`.

**UI (Ye and Tutorial, same sizes):**
- The HUD is sized as fractions of the screen, so it grew with big displays. These frames now use a share of their original size (PROPOSAL):
  - quest tracker 78% (its title line 85% of that);
  - party list, party invite and the "Enter name" party box 80%;
  - Level Up popup 90% (its reward lines stay legible);
  - Server Info 80%;
  - dialogue box and choices 85%.
- Each frame keeps its original size in the attribute `SizeBeforeShrink`. Re-running the change always starts from that.
- Sizes are changed directly rather than with a `UIScale`, so UIMotion's pop-in on Level Up still works.
- "Report to ????" in the Tutorial is unchanged: the hidden name is the owner's 2026-10-15 decision.

**Animations (Animation ID's sheet, read again 2026-10-16):**
- **New and live:**

  | Sheet entry | Game animation | ID |
  |---|---|---|
  | Greatsword CRIT | `Greatsword_Heavy` | 87785261665755 |
  | Greatsword WEAPON SKILL | `Greatsword_Skill` | 85933834004793 |
  | Caestus CRIT | `Gauntlets_Heavy` (replaces 89096699319522, kept as `PreviousId`) | 75715098693180 |
  | Plank | `NPC_Plank` | 110416565777124 |
  | Evil Cinematic | `Misc_EvilCinematic` | 125888674015361 |
  | Cloak/Armor Equip | `Misc_ArmorEquip` | 85191463400707 |

- **Hit timing:** `AnimPeak` was re-measured from the new clips. Greatsword Heavy 0.85 (its sfx/vfx/comboStep markers sit at 0.88), Greatsword Skill 1.31 (first big swing; PROPOSAL), Caestus Heavy 0.88 (its `Hit` marker). This also applies to the two alchemy moves that borrow `Greatsword_Heavy` and to Shoulder Charge.
- **Still broken:** the 15 ⏳ IDs from this morning still return "AnimationClip loaded is not valid": Greatsword M1 1–4 / Idle / Equip / Unequip / Walk / Grip / KO, Katana Sheathe / Unsheathe / Walk, Dagger Sheathe / Unsheathe. The previous animations stay until those are re-published.
- **Wired in:**
  - **Build** plays while a minigame is open (`MinigameService`), and stops on a pass, a close, or walking away.
  - **NPC idles:** the new `NpcIdles` script loops each NPC's `IdleAnim` attribute. Picks (PROPOSAL):
    - Chill: Brask, Tobin, Drillmaster Vask, and the Flame, Earth and Metal trainers;
    - Admire: Lise, Mirra, and the Ice and Wind trainers.
    - Lean Idle wasn't used: no NPC stands against anything to lean on.
  - `AnimationManager` now loops NPC tracks when asked (`Looped`). Its "Animation not found" warning names the missing animation.
- **Tutorial place:** its Animations folder was behind Ye. 39 animations were added (emotes, NPC idles, misc, Drag, Fire 2, Rapier / Caestus idles…) and 11 IDs updated (live katana M1s and idle, Rapier / Caestus / Greatsword CRITs, Greatsword skill, new Uppercut). The wrong gun idle was cleared. With Combat Mode on, the katana idle now plays and nothing warns.
- **Not wired:** there is nothing to attach these to yet:
  - Bandage Use: the only consumable is the Apple.
  - Mask Equip, Arm Blast: no masks or prosthetics.
  - Armor Equip: no armor system.
  - Evil Cinematic: no villain cutscene.
  - Plank, Drag.

**Evidence props (Foundry Yard investigation):** the clue blocks now use the imported Alchemist Assets. The original part stays as the Inspect target.
- the apprentice's notebook → the cream notebook with an orange ribbon (the block is hidden; the prompt is unchanged);
- the State Authority crate → the grey clasped tome lying on top (the voided ledger);
- the yard notice board → three pinned sheets.

**Asset survey (for later):**
- **Books:** nine closed alchemy books (Flame, Ice, Earth, Iron, Plant, Silver, Crimson, Chimera, Combat).
- **Alchemist Assets research notes:** Human Transmutation, Blood Seals, Philosopher Stones, Teleportation, Sacrifice, Mannequin Soldiers. These suit forbidden-alchemy clues or rune/seal pages.
- **Armor:** a full-plate `ArmourSet (FULL METAL ALCHEMIST)`.
- **Missing:** no small trinkets (rings, keys, watches, lockets) exist in any place.

**Tested (Studio Play):**
- Tutorial screenshots before and after: tracker, party, Level Up, Server Info and dialogue all smaller and readable.
- The six new IDs load (lengths 1.2–8 s).
- All ten NPCs loop their idles.
- Build plays while Pressure Board is open and stops on close.
- The katana idle plays in the Tutorial.
- The evidence prompts are intact.
- Consoles clean.

**Not verified:**
- The Ye HUD on screen (its viewport only captures in Edit mode this session; the sizes match the Tutorial's).
- Triggering the evidence inspects (skipped so the save's evidence isn't changed).
- The new Greatsword / Caestus CRITs in an actual fight.

## 2026-10-16 — Alchemy trainer placeholders

**Built (owner: "add alchemist trainer npc place holders with the in game asset we have"):** five placeholder trainers, one per alchemy path, in a row east of spawn with their backs to the east wall. Backup: `ServerStorage.RenseiBackups["Pre-Trainers_2026-10-16"]` (Dialogues; the NPCs are new).
- **Where:** `Workspace.World.NPCs["Alchemy Trainers"]`, at x = 44 and z = −24 / −12 / 0 / 12 / 24 (Flame, Ice, Earth, Wind, Metal), facing spawn.
- **Each trainer:**
  - The same R6 rig as the Foundry NPCs, dressed by the nation-look system (`LookNation` / `LookGender` / `LookSeed`).
  - A Talk prompt.
  - Attributes `TrainerPath = <path>` and `Placeholder = true`.
- **Scroll stands:** each trainer has a wooden stand at their front-right holding their path's scroll from `Assets["RELLO IMPORTED ASSETS"]["Alchemist Assets"]`:
  - Flame Alchemy, Ice Alchemy and Earth Alchemy for those paths.
  - Iron Alchemy for Metal.
  - There's no Wind scroll in the assets, so Wind uses the plain scroll ("1").
- **Dialogue** (`trainer_flame` … `trainer_metal`), generated in `Rensei.Dialogues` from `Rensei.Alchemy`, so the move lists stay current:
  - a placeholder greeting;
  - "What can <path> alchemy do?" lists the path's four moves;
  - "Will you train me?" says training isn't built yet;
  - Leave.
- **PROPOSAL placeholders for the owner to replace:**
  - Names ("Flame Alchemist", …).
  - Nations: Flame Amestrian (M), Ice Drachman (F), Earth Aerugonian (M), Wind Xingnese (F), Metal Xerxian (M).
  - All lines.
- Trainers don't grant a path yet. Paths are still set from the admin panel (F2).

**Tested (Studio Play):**
- All five spawned dressed, with Talk prompts.
- Each path's dialogue lists its real moves (Flame: Ignite, Scorching Wave, Inferno Lance, Phoenix Drive).
- The Flame conversation ran start → moves → back → training → leave, through the prompt and the dialogue UI's own choice requests.
- Console clean.

**Not verified:**
- How they look on screen: the Studio viewport captured blank this session.
- Opening the prompt with a real E key press: injected keys didn't reach Studio, even on Lise.

## 2026-10-16 — Teleport + save audit

**Asked:** "completely audit and fix the TP & data storage system". Covers all three places: Ye, Main Menu ("Character Customization") and Tutorial. Backups: `ServerStorage.RenseiBackups["Pre-TPData_2026-10-16"]` in each place.

**Found and fixed:**
- **Tutorial loaded the wrong save.** It always loaded slot 1 (`Data<UserId>`), whichever slot was picked in the menu. It now loads the selected slot through `SlotAccount`, like Ye. The Tutorial place gained copies of `Rensei.Slots` and `SlotAccount`.
- **Ye wiped one account's save on every join.** The template's leftover line reset the profile of a hard-coded username (`husaynawesome`) to defaults. Removed.
- **Async teleport failures left the player with no save.** Every place releases the profile, then teleports. If the teleport failed later (`TeleportInitFailed`: server full, flooded, ...), nothing reloaded the profile, so the player kept playing and nothing saved.
  - New `ServerScriptService.FlowTeleport` (same file in every place) handles all flow teleports. It retries up to 3 times, covering immediate errors and `TeleportInitFailed`, then runs a fallback:
    - **Menu:** loads the slot again and says "Teleport failed. Try again."
    - **Tutorial / Ye:** kick with "please rejoin". The profile is already saved, so the menu sends them to the right step.
- **A save taken by another server went unnoticed in Ye.** Ye didn't kick when another server's ForceLoad took the profile, so the player kept playing with progress that couldn't save. It now kicks ("Your data was opened somewhere else"), as the menu and tutorial already did. Releasing for a teleport doesn't kick.
- **A store outage could load the wrong slot.** If the `RenseiAccounts` record couldn't be read, Ye and the Tutorial loaded slot 1 without saying so.
  - `SlotAccount.ProfileKey` now returns nil in that case, and the place kicks with "Couldn't load your save slot. Please rejoin."
  - Account reads skip the 4 s GetAsync cache (`UseCache = false`), so a slot picked moments ago on another server is never stale.
  - The menu no longer caches an account it failed to read. Before, a store hiccup showed 2 slots instead of the ones owned.
- **Ye: leaving during load kept the profile locked.** A player who left while their profile was loading kept it locked until the server closed. It's now released.
- **Ye: CharacterHandler could wait forever.** It now waits at most 60 s (`DataManager:WaitProfile`).
- **Ye: `SendData` crashed without a profile.** It now returns quietly.
- **Ye: blocking start-up load.** Players already in the server at start-up no longer load one after another, blocking `Initiate`.
- **Release waits for the save to finish.** Before a teleport, release now waits for ProfileService's "hop ready" signal (up to 6 s), so the next place's ForceLoad gets the profile at once instead of stealing a lock that's still being saved.
- **Save templates and migrations were out of date in two places.**
  - Menu and Tutorial `ProfileData` were still at schema v2, and their migrations stopped at step 1. All three places now use one `ServerScriptService.ProfileMigrations` (steps 0 to 3) and Ye's v4 `ProfileData`, byte-identical.
  - No save changes shape: the steps are the same ones Ye already ran.

**Shared files (keep identical in every place):** `ProfileData`, `Rensei.Places`, `Rensei.Slots`, `SlotAccount`, `ProfileMigrations`, `FlowTeleport`, ProfileService. Hashes matched across all three places after the change.

**Tested (Studio Play, the owner's real save on slot 2):**
- **Ye:**
  - Loaded `Data<UserId>_S2` (the owner's character) at schema 4.
  - `SendData` with no profile: no error.
  - A forced teleport failure: 2 tries, then the fallback ran and the teleport cleared.
  - `DataManager:Release`: no kick.
  - Releasing the profile from outside (as another server would): the player was kicked with "Your data was opened somewhere else".
- **Menu:**
  - Account read (2 owned, slot 2 selected); opened slot 2.
  - Release, then a failed teleport: slot 2 came back and the player stayed in.
  - Release took 0.67 s on a settled profile. On a profile opened a moment before, it took the full 6 s, because Roblox throttles writes to one key for about 6 s.
  - Play over the real remote still answers the Studio message (next: Tutorial).
- **Tutorial:** loaded slot 2 (the owner's character, step Footwork). Before the fix it would have loaded slot 1.
- **Consoles:** clean apart from Roblox's own UIBlox warnings and the expected `[FlowTeleport]` test warnings. Test hooks were removed.

**Found while testing:** this project's ProfileService is an older standalone version without `AddUserId`, so profiles carry no GDPR user ids. The keys contain the UserId, so an erasure request is still a key lookup. Upgrading ProfileService (or moving to ProfileStore) would add it.

**Not verified:** a real teleport between live servers (Studio can't teleport). The changes only take effect live after all three places are saved and published.

## 2026-10-16 — Emote wheel

**Built (owner's "Rensei — Alchemical Emote Wheel System" prompt):** a radial emote wheel that is the game's own transmutation circle. All labels and page names are placeholders. Backup: `ServerStorage.RenseiBackups["Pre-Emotes_2026-10-16"]` (UIHandler; everything else is new).
- **Use:**
  - **Hold H**, point, release to perform.
  - **Tap H** to leave it open and click a name; H again or right click closes it.
  - The **mouse wheel** turns to the next ring.
  - On touch, an **Emote** button opens it; tap a name, or tap the centre to close.
- **Look:** a dark disc with the transmutation circle turning slowly behind gold Guru-font names. A chalk-line pointer runs from the centre to the chosen emote, with a diamond node per slot. The centre plate shows the ring's name, the chosen emote, or why you can't emote right now. Opens with a short pop.
- **Rings (8 each):**
  - *Composure:* Bow, Meditate, Lean, Kneel, Sit, Rest, Pushups, Laugh.
  - *Revelry:* Aero Step, Anthony, Clean Groove, Dance, Floss, Kazotsky Kick, Peter Parker, Thriller.

  All are from the Animation ID's sheet; Kneel, Sit and Rest reuse its NPC idles.
- **Rules:**
  - The server checks every emote (`Requests.Emote` + `Rensei.Emotes.Blocked`): not in Combat Mode or in combat, not knocked / carried / gripped, hands free, on the ground.
  - 0.75s between emotes (PROPOSAL).
  - While one runs, the character attribute is `Emote = id`.
  - Moving, jumping, attacking or entering Combat Mode ends it; one-shot emotes (Bow, Laugh) clear themselves when done.
  - The animation plays on the player's own client, so it replicates to everyone.
- **Files:** `Rensei.Emotes` (list, rings, key, cooldown, shared check), `ServerHandler.Requests.Emote`, `Modules.UI.EmoteWheelUI` (started by UIHandler).

**Tested (Studio Play, real keys and clicks):**
- Tap H → the wheel stayed open → pointed at Meditate → click → seated meditation, `Emote = meditate` → W ended it and cleared it.
- Mouse wheel → Revelry → Floss played.
- A forged Bow cleared itself when it ended; forged unknown ids and a table were ignored.
- In Combat Mode the wheel won't open and a forged Play was refused.
- Console clean.

**Fixed while testing:** a quick tap of H used to "pick" whatever the resting mouse pointed at. A release within 0.3s now never performs; it leaves the wheel open for clicking.

**Not verified:** the touch button on a phone; a second player seeing the emote (it replicates the way every player animation does); rebinding H (the Settings key rows are authored GUI, so H is fixed for now).

## 2026-10-16 — Animation ID's sheet applied

**Done (owner: "We added new & more animations to the spreadsheet, replace and add them as needed"):** every id in the **Animation ID's** sheet was loaded in Studio Play. Backup: `ServerStorage.RenseiBackups["Pre-AnimSheet_2026-10-16"]` (TuningConfig, WeaponManager, DownedManager and the whole `Assets.Animations` folder). Full map: `Documents/Animations.md`.
- **Live now (published ids replace the Studio-only saves):** Katana M1 1–4 and idle; Rapier idle, walk and crit; Caestus idle and crit; the new Uppercut; Greatsword run.
- **Registered for later:**
  - Drag, and the Misc animations: Mask, Bandage, Arm Blast, Build, Meditate, Pushups, Bow;
  - 10 emotes (`Shared.Emotes`) and 9 NPC idles (`Shared.NPCIdles`), not wired to anything yet.
- **Wiring:**
  - `IdleAnim` for Sword, Rapier (its own idle now) and Gauntlets.
  - New `WalkAnim` support in `WeaponManager`: a drawn weapon's walk replaces the default walk (not while sprinting, attacking or carrying). The Rapier uses it.
  - `AnimPeak` re-measured from the new keyframes, so hits still land on the swing: Katana M1 1 0.38 / M1 2 0.31 / M1 4 0.38 (also the Rising Cut dash), Rapier crit 0.44 (first of three thrusts), Caestus crit 0.45, Uppercut 0.27 (its Hit marker).
- **Not usable yet:** 15 ids return "AnimationClip loaded is not valid" in this place. They are the Greatsword M1 1–4, idle, sheathe, unsheathe, walk and GRIP; Katana sheathe, unsheathe and walk; Dagger sheathe and unsheathe; and KO. Applying them would have replaced working Studio saves, so each keeps its previous animation, with the sheet id stored as `SheetId`. The id probably needs re-publishing to the group or re-copying.
- **Gun idle:** `Guns_Idle` carried 86848934973845, which the sheet now lists as the Rapier idle. It was cleared (its Studio save still plays in Studio).

**Tested (Studio Play, real clicks and keys):**
- Katana: drawn idle, then M1 1→2→3→4 in order.
- Rapier: idle, then walking (Rapier_Walk at full weight), then the crit on R.
- Caestus: idle, then the crit on R.
- Uppercut: Ctrl+LMB.
- Console clean. The owner's save (inventory, equipped weapon) was snapshotted and restored; the test hook was removed.

**Not done:** sheathe / unsheathe still play the old draw backwards (the new ids don't load). Emotes have no menu or command yet. NPC idles aren't on the story NPCs yet.

## 2026-10-16 — Morality, first slice (M1–M3 + M5)

**Built (owner approved the defaults in `Morality and Reputation Proposal.md` §8: five tracks, the placeholder factions, Mercy / Candor / Order, words only, no deeds in arena / duels / self-defence, flavour titles; Taboo canon left for later):** all names, lines and numbers are placeholders / PROPOSALS. Backups: `ServerStorage.RenseiBackups["Pre-Morality_2026-10-16"]`.
- **M1 — data + save schema 4.** New `Rensei.Factions`:
  - the factions State Authority, Foundry Hands, Unlicensed Circle and Townsfolk;
  - tiers Hostile / Distrusted / Neutral / Trusted / Honoured;
  - the conduct words (Merciful–Ruthless, Honest–Deceitful, Lawful–Defiant) and the renown ranks.

  New `Rensei.Deeds`: 9 deeds, plus `Finishers` for knocked enemies. `ProfileData` is now `SchemaVersion = 4` with `Morality = {Deeds, Conduct, Standing, Trust, Renown, Taboo}`. The `DataManager` 3→4 migration is additive.
- **M2 — `MoralityService`, the only writer.**
  - `Record` puts a deed on the ledger once. Repeatable deeds count at most `Cap` times a day, so morality can't be farmed.
  - It applies the deed's effects:
    - Conduct and Trust always change.
    - Standing changes only for Local / Public deeds. A Private deed waits for discovery, which comes in a later slice.
    - Renown changes for Public deeds.
  - It shows a toast with the deed's reason, and a banner when a faction's tier changes.
  - On join, all tracks are **rebuilt from the ledger**, and any quest ending already chosen is turned into its deeds once (so older saves catch up).
- **M3 — hooks.** New StoryLogic conditions: `Deed`, `NotDeed`, `Standing` / `StandingBelow` (a tier name or a number), `Trait`, `Trust` / `TrustBelow` and `Renown`, with lock labels such as "[State Authority: Trusted]". Other hooks:
  - a dialogue action `{Kind = "Deed"}`;
  - quest `Outcomes[x].Deeds`;
  - `DownedManager.Listeners` (fired after a grip finishes someone);
  - `WorldService.Credit(Victim, Player)` (credits a victim once only).
- **M5 — content.**
  - **Lise:** Report, Secret and Teach each record their deed. After Secret, telling Brask "It was Lise" is a separate betrayal: Candor −10, Lise remembers it, and new lines for her and Brask.
  - **Tobin:** "Your secret's safe" is now a promise (with a "not promising" option). Telling Brask later records a *broken promise* (Candor −10) or a plain *told on*, and Tobin's lines change.
  - **Brask:** after the quest, "Any word from the Authority's inspectors?" is greyed until the State Authority is **Trusted**. Mirra reacts to Report / Teach.
  - **Bandits:** gripping a knocked bandit is *Finished off a beaten bandit* (Mercy −1). Carrying one alive to Brask (`TakesPrisoners`) is *Carried a beaten bandit in alive*: Mercy +1, Order +1, Authority +1, Townsfolk +1, +10 money, and the defeat counts once.

**Fixed while testing:** `DownedManager` found the carried body by **name**. With two "Bandit Duelist"s alive, it returned the healthy one, so Drop (and the hand-over) acted on the wrong rig. The new `DownedManager.Carried(Carrier)` follows the `CarriedBy` link, and Drop uses it. This was an existing bug.

**Tested (Studio Play, real key presses):**
- Server checks: a once-only deed recorded 20× counted once; a repeatable recorded 15× counted 10 (the cap); an unknown id was ignored; a rebuild from the ledger gave identical numbers; the join-time catch-up of an old Report ending applied once and was idempotent.
- Tobin: broke his lie, promised (toast and Trust +15), then got his "you kept your word" line. Brask showed exactly one "Tobin slept" choice. Picking it recorded the broken promise (Candor −10, Foundry −5, Tobin −35), and the choice was gone afterwards.
- Lise: backing out at the confirmation recorded nothing. Secret recorded *Kept Lise's secret* (Private: Lise +30, Mercy +5, no faction change).
- Brask after the quest: "It was Lise" and the greyed "[State Authority: Trusted]" choice were shown. The locked one did nothing. Betraying Lise gave Candor −20 (Deceitful), and Lise's new line followed.
- Grip on a knocked Bandit Duelist: deed recorded, kill credited once. Carry to Brask: deed, standing, +10 money, +125 EXP credited once; the other live duelist was untouched.
- At Authority 20, Brask's inspectors line unlocked with no label.
- Console clean. The owner's save was snapshotted and restored. Its only lasting change is the schema 4 migration (an empty ledger). Hooks and test spawns removed.

**Not built (next slices):** Discovery (M6), the Journal Standing tab (M4), standing drift, PvP grip deeds (PvP rules still undecided), titles / renown sources, Taboo (canon pending). Grunt bandits aren't Knockable, so only Bandit Duelists can be gripped or carried.

**Notes:**
- When this session started, the Studio save showed EXP 0 with no quests, unlike the earlier test save (quest at stage 5). It may be a different save slot. It was restored exactly as found.
- New scripts are mirrored in `Scripts/`.

## 2026-10-16 — Morality & reputation proposal; full Foundry Yard playtest

**Proposed (not built): `Morality and Reputation Proposal.md`.** Audit: there is no morality or faction system in the game. The only consequences today are the recorded story choice `Outcome_chalk_foundry` and Grip / Carry on knocked targets. The proposal expands Implementation Plan §14–16 into:
- a **Deeds Ledger**: every consequential act is recorded once, with its reason;
- five tracks built from it: **Conduct** (Mercy / Candor / Order, shown as words), **Standing** with each faction, **Renown** (the road to "Legendary Alchemist"), **Trust** with single NPCs, and **Taboo** (forbidden alchemy).
- **Witness scopes** (Private / Local / Public) and **Discovery**: a secret deed can surface later through evidence.
- It maps the Lise / Tobin / bandit-bounty moments onto deeds and has build slices M1–M7.
- Every number is a PROPOSAL. The extra factions (Foundry Hands, Unlicensed Circle, Townsfolk) and the titles are **(new)** placeholders. §8 lists 8 owner decisions.

**Playtested (Studio Play, real key presses and clicks, from a fresh quest state):** the whole "Chalk on the Foundry Wall".
- Accepted from Brask. Inspected the wall chalk and the soot prints.
- The **Valve Board** was solved by reading the needle: valve 1 bleeds. The vent saved as Sealed, then the corridor led to the half-drawn array.
- Mirra, then Tobin's lie broken with the boot prints.
- The furnace store opened by the **no-alchemy route**: coal carried from the bins to the furnace, then standing on the lock stone. The notebook was inside.
- **Case Board:** one wrong answer refused at no cost, then the right one.
- Lise → **Secret** (confirmed): +150 money +50 outcome bonus, +400 EXP (level 2), both codex entries, `Outcome_chalk_foundry = Secret`. Talking to her again paid nothing more.
- **Assay Bench** (Flame / Magnet / Water → Slag Chalk) and **Ledger Cipher** (crate key → shift 5 → "Slag Heap") were played along the way. Both gave their evidence without touching the quest path.
- The dialogue box now closes when you walk away mid-conversation (the stuck-dialogue fix from another session this day).
- Console clean. The owner's save, which had its own progress (chalk quest at stage 5, bounty active), was snapshotted, reset for the run and restored exactly. The temporary hook was removed.

**Found (not fixed):**
- Pressing E as you arrive at an object, before its prompt shows, toggles **Combat Mode** instead. In Combat Mode an inspect still gives its evidence, but its text is suppressed, so it looks like nothing happened.
- The HUD quest-tracker title overlaps the chat box (top left).

## 2026-10-16 — Fix: dialogue box stuck open

**Fixed (the pre-existing bug found during the Assay Bench / Ledger Cipher pass):** the NPC dialogue box could stay open with no way to close it. Number keys and clicking a choice did nothing; only a server `DialogueEnd` cleared it. Backups: `ServerStorage.RenseiBackups["Pre-DialogueStuck_2026-10-16"]` (DialogueService, DialogueUI, Requests.Dialogue).
- **Cause (confirmed in Play):** the client box was showing while `DialogueService` had no session for the player. In that state, `Choose` returned at once and `Close` only sent `DialogueEnd` when a session existed, so nothing ever told the client to close. Walking away and back alone did *not* reproduce it (the server kept the session and choices still worked). The stuck state came back reliably whenever a conversation was opened through a different copy of the module, as a server-side test command does. That is the most likely trigger in the original playtest, which also used forged remotes.
- **`DialogueService`:** `Close` now always sends `DialogueEnd`, session or not. `Choose` with no session closes the box. A new range watch (every 0.5 s) ends a conversation once the player is more than 16 studs (the existing `MAX_DISTANCE`) from the NPC or inspect point, or if either one is gone. `Choose` uses the same range check (`InRange`).
- **`DialogueUI`:** a `DialogueEnd` while the box is already shut does nothing. The extra close messages (e.g. turning on Combat Mode) can no longer re-show the HUD bars.

**Tested (Studio Play, real key presses and a click):**
- Mirra (talk with E, choices 1 / 1, then E again and 2 "Thanks."): conversations advance and close normally.
- Walking ~38 studs away mid-conversation closes the box by itself and brings the HUD back. Walking back and pressing E starts a fresh conversation.
- Stuck state recreated (box open, no server session): before the fix 1 and Escape did nothing. After the fix, pressing 1 closed it, and so did clicking the choice.
- Authority Crate inspect line (`Say`): it stays open while you stand at the crate, and Leave closes it.
- Console clean (no game-script warnings). The owner's save was snapshotted before testing and restored afterwards; a deep compare showed no difference. The temporary test hook was removed.

**Not changed / found:**
- **Escape never closes the dialogue.** Roblox's own menu takes Escape before the game sees it (`InputBegan` never fires for it), so the Escape branch in `DialogueUI` is dead code. This is pre-existing and needs a different key or the menu's open event.
- `DialogueService` keeps `Prompted` as a weak-keyed table with Instance keys, which the design rules forbid. It is pre-existing and was left as is.
- Not verified: touch input, two players at once.

## 2026-10-16 — Assay Bench and Ledger Cipher minigames

**Built (the two deferred minigames from `Quests, Puzzles and Minigames Proposal.md` §3.7, same pattern as Pressure Board / Array Restoration):** all names, lines and numbers are placeholders / PROPOSALS. Backups: `ServerStorage.RenseiBackups["Pre-AssayCipher_2026-10-16"]`.
- **Assay Bench** (`Kind = "AssayBench"`, `assay_chalk`): identify the wall chalk by testing it (Flame, Acid, Magnet, Water) and picking the matching row of a six-row reference table (Clerk's Chalk, Slag Chalk, Iron Ore, Copper Ore, Bone Ash, Sulphur). **The sample never reaches the client**: each test is a new `Act` message and the server answers with that one reaction. 3 chips per sample (PROPOSAL); every two rows differ in at least two tests, so any three tests always name it. Cells turn green or red against what you've seen. A wrong guess refills the chips. The bench's sample is always slag chalk (the story needs that); a bench without `Sample` picks a random row.
- **Ledger Cipher** (`Kind = "LedgerCipher"`, `ledger_cipher`): the server writes a four-line State Authority shipping page ("SIX CRATES CHALK TO ORE ROAD"…) from word pools, enciphers it with a shift of 5 (PROPOSAL), and strikes one chalk line out in red wax. **The key is never sent**: the player finds it on an Authority crate seal ("F over A"). A cipher ring (WRITTEN / READS, `< Shift >`) helps decode, and the answer box is the Settings key-bind box. The client sends the place; the server compares letters only (case and spaces don't matter, 40 characters max).
- **`MinigameService`** (additive): a `Requires` + `Locked` gate on opening (StoryLogic conditions), an optional `Kind.Act` step (`Act` → `Reply`, rate-limited) and `Kind.Failed` reset hook, and `Def.Evidence` given **on the first pass only**. Pressure Board and Array Restoration are unchanged.
- **`MinigameUI`**: draws both with kit buttons and the Guru font. Cipher text is letter-spaced, so Guru never joins "II".
- **Foundry Yard (optional side content; the quest's required path is unchanged):** an **Assay Bench** on the far side of Mirra's crucible (mechanism `assay_bench`, needs *Chalk Sample*) gives new evidence **Slag Chalk**. A **Shipping Ledger** beside the notice board (mechanism `yard_ledger`) gives new evidence **Voided Ledger Line** (new lore hook: the Authority is missing licensed chalk too). An **Authority Crate** by the gate (inspect `authority_crate`) holds the key. Both mechanisms save as `Mech_<Id>` and answer "It's already done." afterwards.

**Tested (Studio Play, real key presses and clicks):**
- The bench without *Chalk Sample* refused with the Locked line. With it, the Flame and Magnet tests answered Orange / Pulls and showed 1 chip left. Iron Ore → failed with refilled chips. Slag Chalk → passed, giving *Slag Chalk* once. E again → "It's already done."
- **Forged client messages:** an unknown test was ignored; a 4th test with 0 chips returned "no sample left"; `{Passed = true}`, `"true"` and a wrong row were all rejected. On the ledger, a table, a 70-character string, the raw ciphertext and an assay `Act` were all rejected or ignored. A correct answer re-sent after the pass did nothing (no session).
- Ledger: E on the crate showed the key; `>` ×5 set Shift 5; "old mill" failed; typing "Ore Road" passed and gave *Voided Ledger Line*. A second run dealt a different page.
- Console clean (client and server). The owner's save (Story / Quests / Money / Exp / Codex / Level) was snapshotted before testing and restored afterwards. A second Play session confirmed it was empty again. The temporary test hook was removed.

**Fixed while testing:** the bench first stood right beside Mirra, so her Talk prompt won over it. It was moved to the far side of the crucible.

**Re-checked afterwards:** the Journal's Evidence tab lists *Slag Chalk* and *Voided Ledger Line* under the quest. The tweaked Assay Bench layout (named table rows, cell spacing) reads cleanly, and a row can be picked. The save was snapshotted and restored again.

**Not verified:** touch input, two players at once.

**Found (pre-existing; fixed the same day, see "Fix: dialogue box stuck open" above):** if you walk away from an NPC mid-conversation, the dialogue box can stay open with no way to close it. Number keys and Escape do nothing, and only a server `DialogueEnd` clears it. The likely cause: `DialogueService.Choose` returns without notifying the client when the server has no session.

## 2026-10-16 — Quests, investigation, environmental puzzles, UI minigames (Phases 6–7 vertical slice)

**Built (owner approved `Quests, Puzzles and Minigames Proposal.md` with the recommended defaults):** the full framework plus one complete quest on a graybox site. All names, lines and numbers are placeholders / PROPOSALS.
- **Save schema 3** (additive migration): `Story = {Flags, Evidence, Deductions, Puzzles, Minigames}`, quest `Stage`, `Quests.Tracked`.
- **Quests** (`QuestService` + shared `Rensei.StoryLogic`): ordered stages, prerequisites, catch-up (evidence found before a stage still counts), optional / hidden objectives, outcomes per ending, item / codex rewards, repeatables with cooldowns. Still pays exactly once (the quest leaves Active before paying). New objective kinds: Inspect, Evidence, Deduce, Puzzle, Minigame, Mechanism, Flag.
- **Dialogue** (`DialogueService`): conditional openers (`Starts`), alternate node text (`Alt`), choices hidden or shown greyed with a reason (`Show = "Locked"`, e.g. "[Evidence: Small Boot Prints]"), new actions (SetFlag, GiveEvidence, GiveItem, StartMinigame, Signal). The server keeps the list of choices it showed, so a forged index can't reach a hidden or locked one. Story NPCs can wear a seeded nation look (`LookNation` / `LookGender` / `LookSeed`).
- **Investigation** (`InvestigationService`, `StoryService`): `RenseiInspect` points give evidence; the **Case Board** checks deductions on the server (wrong answers cost nothing).
- **Journal (J)** (`JournalUI`, built with the new `MenuKit` from the Settings art): Quests (stage text, Track / Abandon), Evidence, Case Board, Codex. The HUD tracker shows the current stage, tracked quest first.
- **Environmental puzzles** (`PuzzleService` + `PuzzleClient`): **per-player** mechanism states (steam vent, furnace mouth, lock stone, cracked seal, valve board, coal bins), doors that open per player, timed states that revert, permanent states saved. **Every alchemy path reacts:** any cast of that element near a mechanism (AlchemyService hook). **Every puzzle also has a non-alchemy route** (valves, carried coal, standing on the stone, the seal minigame).
- **Puzzle casts are free (PROPOSAL):** out of combat, a cast next to a mechanism that reacts to your element costs no meter (the meter only fills in fights).
- **UI minigames** (`MinigameService` + `MinigameUI`): **Pressure Board** (balance three valves, one bleeds pressure) and **Array Restoration** (turn geared rings until the marks meet the notch). Server-seeded, server-validated (it recomputes the gauge / replays the moves), retryable, no penalty for failing.
- **Graybox Foundry Yard** (`World.Map.FoundryYard`, south of the arena): walls, gate, vent corridor, furnace store, notice board, area discovery. NPCs Foreman Brask, Mirra, Tobin, Lise.
- **Quest "Chalk on the Foundry Wall"**: examine three chalk marks (one behind the steam vent) → question the night shift (Tobin lies until shown either of two clues) → open the furnace store ("fire in the mouth, weight on the stone", or mend the seal) → search it → Case Board → confront Lise: **report / keep the secret / teach** (confirmed, recorded once as `Outcome_chalk_foundry`). Plus the repeatable **Bounty: Ore Road Bandits** (5 bandits, 10 min cooldown).

**Tested (Studio Play, real key presses and clicks):**
- The whole quest end to end: E to talk to Brask and accept; E on each mark; the vent blocked the corridor (stopped at z 51.4); the Valve Board failed with the needle outside the green, then passed (vent saved as Sealed, steam and the invisible wall gone for that player); walked through; Tobin's lie broken with the boot prints; Mirra.
- **Alchemy route:** a real Ignite cast with 0 meter lit the furnace from 22 studs; standing on the lock stone opened the store; walked in through the door.
- **Array Restoration** solved by clicking the rings in (saved as Restored); forged minigame submits with no open session were ignored.
- **Case Board:** a wrong answer refused with a hint; the right one solved it. Lise: backing out at the confirmation recorded nothing; "Teach" completed the quest: +150 money, +550 EXP, both codex entries; 15 repeated signals paid nothing more; changing the ending afterwards was refused.
- Server checks (earlier pass): catch-up, stage gating, deduction gating, the bounty's cooldown. Console clean (client and server). The owner's save was snapshotted and restored after testing.

**Fixed while testing:** the NPC clones copied Vask's anchored crouch pose (they looked like they were lying down) — given a standing pose; the font drew "II" as a ligature (valves are numbered 1–3); bigger minigame buttons; inspect / mechanism prompts can sit on plain parts (dialogue distance check).

**Not verified:** two players at once (per-player states were designed for it but only one test client was available); restoring saved puzzle state after a real rejoin (Studio's DataStore calls were failing with HTTP 500 this session, so saves from Studio didn't persist).

## 2026-10-15 — Admin panel: switch alchemy

**Built (owner: "add switching alchemy to this panel"):**
- An **Alchemy** row on the Self tab and on the Players tab (for the selected player): `<  Flame  >  Set`, cycling None / Flame / Ice / Earth / Wind / Metal. It starts on the player's current path and shows "(now: …)".
- Server: `AdminService` command `SetAlchemy` writes the save's `Identity.Affinity` ("None" clears it), then `AlchemyService.PublishAffinity` and a profile sync, so the alchemy bar, mobile buttons and the Mastery tree switch straight away. Unknown paths are refused; every switch is in the admin log.

**Tested (Studio Play, real clicks):** Flame → Ice: the row read "now: Ice" and the slot bar showed Cryo Shift, Coldsteel Smash, Ice Shards, Absolute Zero. "Lightning" was refused. The owner's save was restored to its empty path (Studio's `StudioTestAffinity` fallback shows Flame). Console clean.

## 2026-10-15 — Admin panel; settings update

**Built (owner: "make a on theme admin panel using the ui assets that we have in game, also update the settings"):**
- **Admin panel (F2).** Built from the Settings panel's own art: frame, header plate (ADMIN), tab art, row plates, Enable/Disable buttons, the key-bind box as text inputs. Four tabs:
  - **Players:** pick a player, then Go To, Bring, Freeze/Unfreeze, Heal, Respawn, Kill, Spectate, Give Money, Give EXP, Give Item (cycler over `ItemData`), Kick with a reason.
  - **World:** spawn an enemy in front of you (cycler over `TuningConfig.Enemies`; admin spawns never respawn), Clear Spawns, Kill All, set the time of day, Announce (top-of-screen banner for everyone).
  - **Self:** God mode (DamageManager returns IFramed for `AdminGod`), Speed x0.5–4 (`SpeedMultiplier`), Heal Me.
  - **Logs:** the server's last 60 admin actions.
- **Permissions:** `ServerScriptService.AdminConfig` (server-only): Rensei group (206818864) rank ≥ 254, listed UserIds, and anyone in Studio. `AdminService` re-checks every call; non-admins never get the panel built.
- **Safety:** announcements and kick reasons go through `TextService` filtering; you can't kick yourself, and only a listed UserId can kick another admin; 0.2s between commands.
- **Allowed in combat:** `UIState.RegisterMenu` takes an `AllowInCombat` flag; the admin panel uses it. Other menus still lock in combat.
- **Settings update:** Combat Log (Gameplay); Post Effects, UI Animations, Field Of View 60–100° (Graphics); UI Sounds (Audio). Saved with the profile like the existing settings (`Rensei.Settings` defaults + validation).

**Tested (Studio Play):**
- The panel opened on F2 for the admin and matched the other menus (screenshots).
- Every command through the real remote: money, EXP, Apple (an unknown item refused), Freeze/Unfreeze, God on/off, Speed x2 and reset, time 18:00, enemy spawn and clear, announcement, an unknown command refused. The log listed all 13.
- Settings: Post Effects off disabled Bloom; back on restored it. FOV shows in degrees. Console clean on client and server.

**Fixed while testing:**
- Long admin lists ran past the frame; the list now clips and scrolls.
- **Rows re-animated every 2s** (owner report): the live refresh rebuilt every row and the motion layer popped each one again. Unchanged refreshes now do nothing, and rebuilt rows update in place; rows pop only on open or a tab change (verified: 7s idle, 0 rebuilds; Select rebuilt 10 rows, 0 pops).

**Note:** the command test wrote to the owner's live slot-1 save (+250 money, +50 EXP, +1 Apple), because Studio saves to the real DataStores.

## 2026-10-15 — Animated UI; combat-log badge

**Built (owner: "make all UI in the game animated", "a custom Combat log icon that pops up at the top of the screen when players are in combat ... who hit them and how long they have until they are out of combat"):**
- **`Modules.UI.UIMotion`**, started by UIHandler after every UI module:
  - Menus pop in (scale + slide) and settle out instead of snapping; the backdrop fades. `UIState.ToggleMenu` / `CloseMenus` use it.
  - Every button gets hover grow / press squish (touch gets a press punch). Buttons that already have their own UIScale (Fusion springs) are left alone.
  - List rows pop in, staggered, as menus build them (not in the HUD, whose lists refresh constantly).
  - HUD2 popups punch in, the banner drops from the top, the dialogue box rises, the HUD slides into place.
  - Settings: UI Animations off makes everything instant; UI Sounds off silences the menu sounds.
- **`Modules.UI.CombatLogUI`:** a badge that drops in at the top centre while you're in combat. It shows "IN COMBAT", who last hit you (or who you're fighting), a countdown and a draining bar; the icon jolts on every new hit and the timer pulses in the last 3s. It flashes "SAFE" and slides away when combat ends.
  - **Icon:** a white seated Truth figure with a big toothy grin and black arms, drawn from UI shapes on a transparent background. An uploaded image can replace it (`ICON_IMAGE`).
  - Server: `WorldService.MarkCombat` now also sets `CombatUntil` (server time), `CombatBy`, `CombatVs`, `CombatHitAt` on the player's character.

**Tested (Studio Play):** a Bandit hit the player: the badge read "IN COMBAT / Hit by Bandit" with the countdown; after combat it showed SAFE and hid. Stats menu open/close animated and restored cleanly; 56 buttons got hover motion. Console clean.

**Fixed while documenting:** UIMotion used weak-keyed tables with Instance keys (against the rule in ARCHITECTURE.md); they're plain tables now, cleared on `Destroying`.

## 2026-10-15 — Grip audit, grip styles, weapon dash attacks

**Grip audit (owner: "completely audit player behavior after gripping enemies, add different grips"):**
- After a grip, the gripper's parts kept the wrong `Massless` value and the HumanoidRootPart was left massless; both are saved and restored now. Walk speed and jump height are saved and restored too.
- **Grip styles** (`DownedManager.GripStyle`): **Classic** (paired, then the gripper steps clear), **Stomp**, and **Execution** (armed: the weapon's heavy, twice). Unarmed grips pick Classic or Stomp at random; the `GripStyle` attribute forces one.
- Tested: Stomp and Classic kept mass, speed and position correct afterwards.

**Weapon dash attacks (owner: "dash attacks for weapons to make them feel more custom"):** running + LMB with a weapon drawn uses that class's own dash attack (`TuningConfig.WeaponDashAttacks`, all numbers PROPOSAL):
- Sword **Rising Cut** · Rapier **Lunging Thrust** · Greatsword **Cleaving Charge** (hyper armour) · Daggers **Shadow Step** (2 hits) · Gauntlets **Shoulder Charge** · Guns **Pistol Whip**.
- `SkillData` generates `<Class>_DashAttack`; the Momentum Strike skill-tree bonus applies to all of them.
- Tested: Katana run attack → `Sword_DashAttack`, 26 damage on a Bandit. (Two earlier "misses" were the test setup: the camera faced away, and the passive Bandit wandered.)

**New animations (the "NEW RENSEI ANIMS" folder):** they're owned by another group ("gangsta bugs bunny"), so they don't load in Rensei's game. They need re-uploading under the Rensei group before they can replace placeholders. The carry IDs were tried and reverted.

## 2026-10-15 — NPC looks and weapons

**Built (owner: "randomize the fits of the npc ... respective to their nation", "spawn with the weapons that are in the character customization screen"):**
- Every enemy spawn rolls a nation, gender and outfit from the creator's assets (`Customization.RandomLook`).
- Each enemy gets one of the creator's starting weapons (`PickWeapon`; a spawn part's `Weapon` attribute overrides). Gunners keep 18 studs away and fire through the players' gun code.

**Tested:** looks varied per spawn; a gunner hit 12 × 12; a melee Bandit dealt 170 in 7s.

## 2026-10-15 — Mastery skill tree finished (Rello's plan, Tasks 6–8)

- **Movement effects:** parkour cost and wall-run time (JumpManager) and sprint speed (ClientHandler.Run) read their `SkillMods`.
- **Mastery menu (K):** `Modules.UI.MasteryUI`, built from the Inventory art: the tree on a circle canvas, a node card, and a ViewportFrame preview of the move. Buy and refund go through `Requests.SkillTree`.
- The temporary `TestHookScript` was removed (copy in backups).
- Tested: buying and refunding nodes, and the movement effects.

## 2026-10-15 — Character creator rebuild (Character Customization place)

**Built (owner: rebuild like the reference video on slide 12, keep hair IDs, add purchasable save slots, surname = clan):**
- **Save slots:** 2 free, up to 5 (Developer Product, 200 Robux PROPOSAL). Each slot is its own profile (`Data<UserId>` for slot 1, `Data<UserId>_S<n>`); the account store `RenseiAccounts` keeps owned / selected / favourite slots. Small star (favourite, listed first) and trash icons per slot.
- **Clans = surnames,** rolled with the deck's odds: Common 50 / Uncommon 28 / Rare 15 / Mythic 1 (Legendary is empty, so its share is spread), with pity. A Clan Index lists every clan's rarity and buffs. Rerolls come from packs (Developer Products) or codes (`ClanCodes`).
- **Look:** up to 3 hair IDs from the Roblox catalog (recoloured by the hair colour) plus preset hairs; a colour wheel with brightness and a "keep own colours" toggle; eyes / brows / mouth thumbnails; skin swatches.
- **Gender** changes the body (the owner's ROBLOX Girl torso for Female). **Nation** decides the starter outfit.
- **Weapon** step shows the weapon's stats card. The Alchemy step was removed.
- **Presentation:** rebuilt from the game's UI kit (panels, plates, rarity frames); an idle with an occasional clap; hold left-click on the character to turn it; the camera sits on `MenuStage.CameraMark` with the background streamed in.
- Ye's `DataManager` loads the selected slot (`SlotAccount.ProfileKey`).

**Tested:** slot buy/select/favourite/delete, the clan roll and index, creation, the colour wheel, ID hair tint, the female body, the reroll panel (bad codes refused), hold-to-rotate.

**Owner items:** the Developer Product IDs for slots and reroll packs are still 0; the Tutorial place still loads `Data<UserId>` instead of the selected slot.

## 2026-10-15 — Earth kit (20 of 20 alchemy slots); Rensei logo

**Built (the approved proposal, from the owner's own prototypes):**
- **Z Rising Thorn:** a spike at the aimed spot, under the first character the aim crosses: 55 + Bleed, knock-up.
- **X Tectonic Shift:** a ring of spikes, 85, stun 1.2s.
- **C Earth Wall:** solid, climbable cover for 6s that blocks projectiles; it lifts whoever stands there (30).
- **V Earth Pillars:** an unblockable line, 3 waves, 60 + 60 + 120.
- **VFX:** `Assets.VFX.EarthElement` from the prototypes' rock and spike meshes, sounds and crack decal. Rock takes the ground's colour and material.
- **Logo:** the owner's Rensei logo is on the main menu and in the intro cutscene. The decal 108616489098661 resolves to the image 130654945285755.

**Tested (Studio Play, dummies given 10,000 HP):**
- **Rising Thorn:** 55, then bleed 2 per 0.5s; the dummy was lifted to y 8.8.
- **Tectonic Shift:** 85 on the plain dummy, 17 chip on the blocking dummy.
- **Earth Wall:** the collider is in the right place, solid, and stops a projectile sweep; the lift hit deals 30.
- **Earth Pillars:** all four dummies (including the blocking and parrying ones) took 60 / 60 / 120 in order along the line, popped up 3 → 7 → 11.6.
- Screenshots of the ring, the wall and the pillars. Console clean.

**Fixed while testing:**
- Rising Thorn's aim passed through characters to the full range; it now stops at the first character.
- Earth Wall's lift dealt nothing (the wall is DEFENSIVE); the lift is now its own BLOCKABLE hit.

**Not verified by hand:** climbing the Earth Wall. The climb raycasts use `World.Map`, where the wall is, but the input tools couldn't steer a real climb.

## 2026-10-14 — Character creation and the start flow (three places)

**Built (owner: "Main Menu > Customize Character > Finish creating > Teleport to Tutorial world > Finish Tutorial > Cutscene > Main Game"; "Let players set their first name, gender, etc."):**
- **Character Customization place:**
  - A main menu in Rensei's style (Guru font, gold on black) and a 6-step creation screen with a live preview on a lit dais.
  - Steps: nation, first name (typed or random from the nation's list) / surname / gender, look (skin, 7 hairs, hair colour, 22 eyes, 8 brows, 25 mouths, 27 outfits, randomize), alchemy path (shows the 4 moves), starting weapon, confirm.
  - Server-validated and saved once; then PLAY goes to the Tutorial.
- **Tutorial place:** it loads the shared save, dresses the player, and sends players without a character to the menu. `ServerStorage.FinishTutorial:Fire(Player)` marks it done and goes to the main game.
- **Ye:**
  - `AppearanceService` dresses every spawn.
  - `FlowService` sends anyone who didn't come through the flow to the menu (live), and plays the intro cutscene once (placeholder).
  - The in-Ye `CreateCharacter` request was removed (copy in backups).
- **Registry** `Customization`: the owner's nations, palettes, face parts, outfits, hair meshes and name lists, all from the Assets place.

**Tested:** the full chain on one save. The character was made in the menu, finished the Tutorial, and arrived in Ye with the cutscene, the look, the Greatsword and the Earth path. Bad inputs were refused, every hair was checked on the head, and the console stayed clean.

**Fixed while testing:**
- Hair didn't attach on the client preview; it's now welded to the head.
- Coloured hair textures ignored the chosen colour; they're now left off.
- The stage didn't stream to the client; it's now Persistent.
- Step tabs were sorted alphabetically.
- Roblox's chat window covered the menu; it's hidden in the menu.

**Owner items:** see `Start Flow and Character Creation.md`: tutorial content, the real cutscene, publishing for the first live teleport test, and the template's data-wipe line for one player in Ye's DataManager.

## 2026-10-14 — Consumables heal; Earth + character creation proposal

**Built (owner request: "consumables should heal a little bit of health at a time"):**
- Hold an item from the hotbar (outside Combat Mode) and click to use it.
- The Apple heals **8% of max HP over 6s**, in ticks every 0.5s. There is 1s between bites, and it isn't eaten at full health (all PROPOSAL).
- Eating more adds to the heal still to come.
- Healing pauses while knocked.
- Each bite takes one off the stack. The last one leaves the inventory, and hotbar / equipped-weapon references shift to match.

**Tested (Studio Play):**
- At 940 max HP, one click healed +6.4 HP every 0.5s, 75 HP total.
- A second click within 1s was ignored.
- The stack went from 3 to 2.
- The last Apple was removed, the tool disappeared, and the equipped-weapon index followed the Katana.
- Console clean.

**Noticed:** Roblox's default health regen (the auto-inserted `Health` script, +1% of max HP per second) is active in Ye. Whether Rensei wants passive regen is an owner decision. It's untouched.

**Proposal written:** `Earth and Character Creation Proposal.md`.
- The Earth kit is mapped from the owner's prototypes: Rising Thorn, Tectonic Shift, Earth Wall, Earth Pillars, with sheet-style numbers as PROPOSAL.
- The character creation flow and data model build on the old build's nation system and the Assets-place customization parts.
- It ends with 10 decisions for the owner.

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

**Follow-up (same day):** consumables heal. See the entry above.

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

# Rensei — Phase A Audit: Movement, Animation & Weapon Styles

**Date:** 2026-10-17. **Scope:** read-only audit. **Nothing in Ye was changed.**

## How this was verified

| Source | How it was read |
|---|---|
| GitHub `WhosRelloo/Rensei-Game-Design@main` | Downloaded as a zip. Read ARCHITECTURE, Project Status, Animations and the exported scripts. |
| The 3 animation sheets | Exported as xlsx and CSV. All three were publicly readable. Every row was read, and IDs were checked against the CSV text so no digits were lost. |
| Ye (106992859583940) | Read live through Studio MCP in **Edit mode**: the script sources, all 145 `Animation` objects and the map. |
| Animation load test | `AnimationClipProvider:GetAnimationClipAsync` in Studio Edit. This is the same check that produced the earlier "AnimationClip loaded is not valid" results. |
| Ownership | `MarketplaceService:GetProductInfo` → `Creator`. The game is owned by **Group 206818864 (Rensei)**. |

**Limits:** no Play test, no live server, no second client. A clean load in Studio Edit is strong evidence but does not prove live playback. A live check is still needed before any of these is called "verified live".

---

## 1. Animation sheets: what they contain

### 1.1 Ownership and load results (96 unique IDs)

- **Every one of the 96 IDs is owned by the Rensei group**, the same group that owns the game. The old "uploaded under another group" problem no longer applies to anything on these sheets.
- **85 load and 11 fail** (corrected 2026-10-17; first published as 84 / 12). The 11 failures are the same assets that were already flagged on 2026-10-16. They are owned by the group but fail with `AnimationClip loaded is not valid`, which means the upload itself is bad and must be re-uploaded:
  - Greatsword: KO / "GRIP VICTIM" (136479651286488), Grip (97655349905356), Idle (125386811877833), Sheathe (78181583295596), Unsheathe (122309498454912), Walk (76985284126069)
  - Katana: Sheathe (135958788270981), Unsheathe (138826683613033), Walk (110642878390298)
  - Dagger: Sheathe (120069108676683), Unsheathe (82218741773055)
  - (The 2026-10-16 list of 15 also had Greatsword M1 1–4. **Those rows now hold new IDs, and the new IDs load.**)

### 1.2 General sheet: changed since the 2026-10-16 pass

| Row / column | Sheet ID now | Asset name | Load | In Ye now |
|---|---|---|---|---|
| Katana M1 1–4 | 92912515507435, 104427266748350, 113494460122019, 74531248779637 | Katana1–4 | ✅ | **No.** `Sword_Light1–4` use 85877842085151 / 75984364191563 / 87445491406328 / 96737659250581. The sheet has replaced them. |
| Greatsword M1 1–4 | 135443790313474, 119757160915763, 88358005749268, 125110120812047 | Kanabo 1–4 | ✅ | **No.** Ye uses Studio-only saves. The stored `SheetId`s are the old, broken IDs. |
| Greatsword CRIT | 134098741446163 | odachiaircrit | ✅ | **No.** `Greatsword_Heavy` = 87785261665755. |
| Greatsword GRIP VICTIM (R17, "Greatssword") | 132402287752151 | Greatsword gripped | ✅ | No |
| Dagger M1 1–4 | 135888213988144, 127180979844138, 80421062677398, 85482783176882 | Hell Dagger 1–3, dagger 4 | ✅ | **No.** Daggers lights are Studio-only saves, so they are broken live. |
| Dagger GRIP / GRIP VICTIM | 128181861798117 / 127333192588264 | grip dagger grip / gripped | ✅ | No |
| Dagger CRIT | 103317286406552 | **"Sword Crit"** ⚠ | ✅ | No (`Daggers_Heavy` is a Studio save) |
| Caestus GRIP / GRIP VICTIM | 114886619154794 / 104445631686192 | Head Smasher / _Victim | ✅ | No |
| Forward Glide/Fall, Gliding Neutral | 113503003046182, 114537534383994 | Fall, Gliding Neutral | ✅ | No (a Fall animation was listed as missing) |
| Walk Left | 91362206594750 | LEFT WALK | ✅ | No. **Walk Right has no ID.** |
| Wall Ledge Walk Left | 129382412379032 | Ledge Walk Left | ✅ | No. **Right has no ID.** See §3.2: this is a *standing* ledge walk. |
| Swim Forward | 114885907475368 | Swim Forward | ✅ | No. **Swim Idle has no ID.** Prone stroke, torso pitched 76°, looped 1.5 s. |
| Berserk Transformation, Lock Pick, Assassination (+Victim: no ID) | 83696585980884, 136478153650620, 83505608395055 | | ✅ | No |
| Emote "No!" | 80946728550958 | NO | ✅ | No |
| NPC idles: Low Hand On Ground, Hand in Pocket, Praise, Transcend, Prisoner, Greatsword Entrance Idle, Cross Arms, Wall Cover Right, Tai Chi Dance | 100885036033762, 134259918702783, 130482465126083, 81595704172803, 89704594975684, 115271747714860, 83476611333944, 111740908967094, 137321428622135 | | ✅ | No |
| Jump, Take The L, Trainings (Pushup Idle, Situps…) | (blank) | | ➖ | No ID |

Rows that are still in sync with Ye: Alchemy (Clap / Loop / Slam / Arm Extend / Fire 1–5), NEW UPPERCUT, Drag, Misc rows, emotes, the original 10 NPC idles, Katana Idle, Greatsword Run, Greatsword WEAPON SKILL (85933834004793), Rapier Idle / Walk / CRIT, Caestus Idle / CRIT.

### 1.3 Weapon-style sheet: only Fist styles exist

| Style | M1 1–4 | Idle | Walk | Crit | Block | Sheathe / Unsheathe / Run |
|---|---|---|---|---|---|---|
| **Boxing** | 82202712812003, 118707795709694, 85596385691117, 77445690844594 ✅ | 128144874685921 ✅ | 136199920360463 ✅ | 85458853360992 ("Peakaboo M2") ✅ | 132233175475993 ✅ | blank |
| **Lethwei** | 73114452271742, 106540270306289, 77122297784777, 92791475470813 ✅ | 92729063077948 ✅ | 108623097986801 ✅ | 89942936599788 ("M2") ✅ | 132233175475993 (**same ID as Boxing**) ✅ | blank |

Both styles have a complete set and every asset loads. The shared Block ID is probably intentional (one shared guard pose). The sheet has no column for a style skill, uppercut, aerial or dash attack, so those will fall back to the shared versions.

### 1.4 Skill sheet: 20 animations, none of them used in Ye

| Class | Skills (ID) — all ✅ and owned by the group |
|---|---|
| Fist | Bear Hug 140607038476506 (+Victim 76737043223431), WHERE YOU GOING?! 112750159390677, 540 Kick 103740230258261, Slam Dunk 73012783228902 (+Victim 78594988220475), Spin Kick 124203451617546, shared Grab Whiff 74141778302667 |
| Sword / Katana | Quick Draw 73340942048018, Iaido Barrage 82444061045726 |
| Dagger | Slip Slash 71144555873390, Blood Dash 72806175551332, Bullet Slash 84040495870926, COME HERE!! 109499493690369 |
| Greatsword | Heavy Drop 91816061778866, Whirlwind Cleave 94150677409224 |
| Rapier | Ren 138152002961886, Speed Lunge 118892893693638 |
| Gun | Iron Rush 135502951675204 (+Victim 93017980685233) |

**Ye's current weapon skills are one per class**, on `Weapons.<Class>.Skill` and the `WeaponSkill` key (default **T**):

- Dragonflash, Flurry, Barrage, Scissor Rush and Fan the Hammer all run on Studio-only saves or a reused gun shot, so **they are broken or placeholder live**.
- Greatsword Whirlwind uses the *general* sheet's WEAPON SKILL (85933834004793). The skill sheet has a different "Whirlwind Cleave" (94150677409224).
- Unarmed fists have **no** weapon skill.
- The skill sheet implies **several skills per class**. The current one-slot design cannot hold that (see the decisions in §6).

### 1.5 Mapping mismatches to confirm (the IDs load; the question is whether they are in the right place)

1. **Rapier Idle / Walk** (86848934973845 / 105780900199532) are named **"Gun Idle Animation" / "Gun Walk"** on Roblox. Ye uses them for the Rapier. They may belong on the empty Gun row.
2. **Dagger CRIT** (103317286406552) is named **"Sword Crit"**.
3. **`Shared.Combat.Downed.Knocked`** stores `SheetId=136479651286488`. That ID is the Greatsword **GRIP VICTIM** column (asset "Greatsword KO"), not a generic knocked pose, so the earlier mapping is questionable. The working Greatsword grip-victim animation is the R17 entry, 132402287752151.
4. `Alchemy_Fire2` and `Alchemy_Ignite` share 139705972233564. This is intentional and already documented.

---

## 2. What already exists (code, live in Ye)

The GitHub `Scripts/` export covers about 70 files. **It does not include** JumpManager, MoverManager, WeaponManager, AttackRunner, HitboxManager, DamageManager, ClientHandler (+Roll/Run/Crouch), MobileControls, ClientActions, Keybinds, FistSwing, Heavy, Block, LoadoutService, ItemData or SkillData. Ye is the only copy of these files. All findings below come from Ye.

### Movement (`Managers.JumpManager`, client-driven)

- Climbing: tap Space on a wall, then W/S climbs vertically (sideways is disabled in code, `X = 0`). It uses an `AlignPosition` + `AlignOrientation` anchor and arm IK that puts the hands on the wall.
- Wall run: hold Space next to a side wall. Walls chain, each run drains stamina, and releasing Space kicks off.
- Top of a climb: a **velocity-pop "vault"** (`Vault1/2`). `Tuning.Parkour.MantleTime = 0.32` is **defined but unused**: the earlier tweened mantle survives only in `RenseiBackups.Pre-Mobile_2026-10-14`.
- **No swimming system.** The Roblox default `Swimming` humanoid state is still active.
- **No ledge hang or ledge walk system.**
- **No central movement state machine.** State is spread across:
  - WCS statuses: `Climbing` (also covers wall runs), `Stun`, `Attacking`, `Blocking`, `Dodge`, `AirCombo`, `IFrame`
  - character attributes: `Knocked`, `CombatState`, `CombatMode`, `Weapon`
  - client-local fields in JumpManager: `ClimbConn`, `WallRunConn`, `AlignPosition`

### Security gaps in the existing movement remote

- `JumpRemote "ClimbState"` lets any client start or stop its own `Climbing` status with **no server check**. The cost is small: it mostly blocks your own attacks.
- `JumpRemote "PlayFX"` indexes `EffectModules[Type]` with a client-supplied `Type` and client args, and broadcasts the result to all players. It has no whitelist. A bad `Type` errors on the server, and a valid one can be spammed.
- Stamina for parkour is charged server-side (`ParkourStamina` validates `Kind`), which is good. Eligibility (am I really on a wall?) is never validated.

New traversal must not copy this pattern. The audit recommends fixing both gaps in Phase C.

### Combat and weapons

- **Canonical classes in code** (`TuningConfig.Weapons`, `ItemData.Weapon`): `Sword` (item Katana), `Rapier`, `Gauntlets` (item **Caestus**), `Greatsword`, `Daggers`, `Guns` (Revolver / Renetti / Forge Tac / Sykov).
- **Unarmed fists** are not a class. They are what you fight with when `EquippedWeapon = ""`, using `TuningConfig.Light.Hits` (FistCombo1–4) and `Heavy`.
- **"Gauntlets" = the sheet's "Caestus (Fists)".** It is the same class under two names, not a duplicate. Gauntlets lights currently reuse the unarmed fist combo.
- Attack flow: `FistSwing` → `WeaponManager.Def(Character)` (reads the `Weapon` attribute) → `AttackRunner.Run(def, SkillName)`. SkillData is generated from TuningConfig. **This is a natural hook for styles**: resolve `Def` through the active style before it reaches AttackRunner. No new damage path is needed.
- Persistence: `ProfileData` is at SchemaVersion 4. `EquippedWeapon` is saved, `LoadoutService.Restore` runs on every spawn, and `ProfileMigrations` exists. A style choice fits as an additive `Styles = {[Class] = StyleId}` key (Reconcile fills it, so no reset is needed).
- Input: the `ClientActions` registry is shared by keys and touch. `Keybinds` holds Dash Q, Block F, LockTarget G, WeaponSkill T. `MobileControls` has a contextual cluster.
- Rig: **R6** (StarterCharacter). Every sheet animation that was inspected is R6.

### Map

- **There is no swimmable water.** The only water-like object is `World.Map.CrackedFootbridge.Riverbed`, a 44×0.6×22 part. Terrain water was not detected, so swimming needs test water before it can be tested at all.

---

## 3. Design findings that change the brief

### 3.1 Style target

Boxing and Lethwei are **Fist** styles, but Ye has two fist-like modes: unarmed, and Caestus/Gauntlets. The brief says "Fists", and the sheet says "Caestus (Fists)" (Caestus Idle's asset is literally named "boxing"). **Owner decision needed:** styles on Gauntlets only, on unarmed only, or on both (shared style list, saved per mode).

### 3.2 "Wall Ledge Walk" is a standing animation, not a hang

I inspected the keyframes of 129382412379032:

- The torso is upright.
- The arms are low, swung 66° to the side.
- The head is turned 43°.
- It is a 0.82 s side-step loop.

This is a **narrow-ledge walk with the back or side to the wall** (Uncharted-style), **not** a hanging shimmy.

There are **no hang, hang-idle, shimmy or mantle animations on any sheet.** Options:

- **(a)** Build the standing ledge-walk the asset supports: step onto a narrow ledge along a wall, sidestep left/right, with clean entry and exit. A hang can be added when assets exist.
- **(b)** Build the hang / shimmy / mantle from the brief using the existing climb-idle poses as placeholders, which will look wrong.
- **(c)** Both, with (b) behind a flag until hang animations are uploaded.

Walk *Right* is also missing. Playing Left in reverse is a usable stopgap (the feet move the right way), but it should be flagged.

### 3.3 Swimming assets

- Swim Forward exists and loads.
- Swim Idle, dive, surface and water entry/exit are missing.
- The surface idle can reuse Swim Forward at a slow speed as a labelled gap.

### 3.4 Skills

The skill sheet gives 2–5 skills per class, but the game has one weapon-skill slot. These need a design rule (see §6) before Phase G.

---

## 4. Style completion matrix (real findings)

| Class (code name) | Style 1 | Style 2 | Style 3 |
|---|---|---|---|
| Fists (unarmed and/or `Gauntlets`/Caestus, see §3.1) | **Boxing**: animation set complete, all load; not implemented | **Lethwei**: animation set complete, all load; not implemented | NOT YET DESIGNED |
| `Sword` (Katana) | NOT YET DESIGNED | NOT YET DESIGNED | NOT YET DESIGNED |
| `Rapier` | NOT YET DESIGNED | NOT YET DESIGNED | NOT YET DESIGNED |
| `Greatsword` | NOT YET DESIGNED | NOT YET DESIGNED | NOT YET DESIGNED |
| `Daggers` | NOT YET DESIGNED | NOT YET DESIGNED | NOT YET DESIGNED |
| `Guns` | NOT YET DESIGNED | NOT YET DESIGNED | NOT YET DESIGNED |

Proposal: each class's current moveset (general sheet) is registered as its implicit **"Base"** style. Every class then always has one valid, selectable style, and designed styles add to it. Base would not count toward the three; this is the owner's call.

---

## 5. Proposed implementation order

Each phase snapshots the scripts it touches into `ServerStorage.RenseiBackups["Pre-<Name>_2026-10-17"]`. Nothing is published, and the profile is snapshotted and restored around Studio tests.

| Phase | Work | Touches | Blocked on |
|---|---|---|---|
| **B. Animation integration** (data-only, lowest risk) | Register the 85 loading IDs as named `Animation`s (new: Swim, LedgeWalk, WalkLeft, Fall/Glide, grips ×3, styles ×2, skills ×20, NPC idles, misc). Swap Katana M1, Greatsword M1 + CRIT, and Dagger M1 + CRIT to the sheet IDs, re-measure `AnimPeak` from the new keyframes, and keep the old ID or save as `PreviousId`. Keep fallbacks for the 11 broken IDs. | `Assets.Animations`, `TuningConfig.Weapons` (Anim / AnimPeak only) | Decisions 2–4 |
| **C. Movement-state foundation** | One server-owned `Traversal` attribute (`None / Climb / WallRun / Ledge / Swim`) set only through a validated request. The server checks that a wall or water is really there (one cheap raycast per *transition*, not per frame) and clears the attribute on Stun, Knocked, death and respawn. Existing climb and wall run are routed through it. Fix the `ClimbState` / `PlayFX` gaps. | JumpManager, a new `Requests.Traversal`, CharacterHandler cleanup | — |
| **D. Ledge traversal** | Per decision §3.2 | JumpManager (or a `TraversalManager` sub-module it owns), ClientActions, MobileControls, `Tuning.Parkour.Ledge` (PROPOSAL) | Decision 5 |
| **E. Swimming** | Detection by terrain water + parts tagged `RenseiWater` (validated server-side). Surface / dive / vertical movement with an AlignPosition + LinearVelocity controller replacing the default Swimming state. Stamina via ResourceManager, no drowning (config flag off). Mobile: contextual dive / surface buttons. | same, + `Tuning.Swim` (PROPOSAL) | Decision 6 (test water) |
| **F. Style foundation** | `Rensei.Styles` registry: Class → {StyleId → overrides of Light / Heavy / Idle / Walk / Block / DashAttack...}. The style resolves inside `WeaponManager.Def`, and SkillData is generated per style. Profile `Styles` key (additive), plus `Requests.Style`: valid for the class, out of attack / stun / traversal, rate-limited. A MenuKit picker that works with touch. Boxing + Lethwei first. | TuningConfig / SkillData generation, WeaponManager.Def, LoadoutService, ProfileData, new UI | Decision 1 |
| **G. Skill animations** | Wire the sheet skills according to the rule chosen in decision 7. Retime from keyframes. Grab skills with victim animations go through the existing Grip / Downed paired pattern. | `Weapons.<Class>.Skill`, Requests.WeaponSkill | Decision 7 |
| **H. Regression + docs** | Studio Play test matrix (Server + 2 Clients for multiplayer), plus Animations.md, ARCHITECTURE, Status, Phase Plan and Changelog | — | — |

## 6. Decisions needed from the owner

1. **Fist styles go on:** Gauntlets/Caestus, unarmed, or both?
2. **Use the sheet's new Katana M1 and Greatsword M1 + CRIT IDs** in place of what Ye plays now? (Recommended: yes. The sheet is newer and the IDs load.)
3. **Rapier Idle / Walk** ("Gun Idle Animation" / "Gun Walk"): keep them on the Rapier, or move them to Guns?
4. **Dagger CRIT** (asset "Sword Crit"): correct for the daggers?
5. **Ledge traversal:** (a) standing ledge-walk, (b) hang / shimmy / mantle with placeholders, or (c) both? Can Walk Right, a ledge-hang idle, shimmy and mantle be uploaded?
6. **Water:** is there a planned lake or river? If not, may a tagged test pool be added to the graybox?
7. **Skill sheet:** are the 2–5 skills per class style-specific skills, a loadout the player picks into the one slot, extra keys, or skill-tree unlocks?
8. **Base style:** should the current movesets count as a selectable "Base" style?

## 7. Manual work for the owner (no code can fix these)

- **Re-upload the 11 broken group animations** listed in §1.1 and paste the new IDs into the sheet.
- Upload the missing assets: Swim Idle, Wall Ledge Walk Right, Walk Right, Jump, Assassination Victim, and any hang / shimmy / mantle / dive animations.
- Publish the remaining Studio-only `Save` animations (climb ×4, Daggers / Sword / Rapier / Guns sets, the downed set) so that they play live.

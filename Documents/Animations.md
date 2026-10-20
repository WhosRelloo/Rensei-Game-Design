# Animations — sheet to game map

Sources: the three animation sheets: **general** ("Animation ID's"), **weapon styles** and **skills**. Last pass **2026-10-19** (Rapier set, Dagger idle and light 3, Katana unsheathe, Rapier grip).

In Studio every animation is an `Animation` object under `ReplicatedStorage.Assets.Animations`, found by **name** (`AnimationManager`).
- **Empty ID:** an `Animation` with an empty id plays its local `KeyframeSequence` save in Studio only, and nothing in a live server.
- **Ownership:** every ID on all three sheets is owned by the Rensei group (206818864), the group that owns the game (checked 2026-10-17).
- **Status:** from loading each id in Studio. The swapped weapon IDs were also loaded and played through AttackRunner in Studio Play.

**Legend:**
- ✅ live: the published id loads.
- ⏳ broken: the id doesn't load ("AnimationClip loaded is not valid"). The upload is bad and needs re-uploading. The game keeps the previous animation or Studio save, and the sheet id is stored as the attribute `SheetId`.
- 📦 registered: loads, sits in `Animations.Registry`, and isn't played by anything yet.
- ➖ not in the sheet yet.

## Folders

- **`Shared`, `Weapons`:** preloaded on every character by the client (about 140 tracks; Roblox's limit is 256 per Animator).
- **`Registry`:** resolvable by name (server and NPC playback) but **not** preloaded. Move an entry into `Shared` or `Weapons` when a system starts playing it on players.

## Weapons (general sheet)

| Sheet | Game name | Status | Used by |
|---|---|---|---|
| Katana M1 1–4 | `Sword_Light1`–`4` | ✅ (pass 3: new ids, old ones kept as `PreviousId`) | Sword lights, Sword dash attack (light 4) |
| Katana Idle | `Sword_Idle` | ✅ | Sword `IdleAnim` |
| Katana Unsheathe | `Sword_Equip` (114589995116351) | ✅ 2026-10-19 (0.43 s) | Sword and Rapier draw, and their sheathe (played backwards). The old Studio save stays as `Save` |
| Katana Sheathe / Walk | `Sword_Unequip` / `Sword_Walk` | ⏳ | Studio saves kept |
| Greatsword M1 1–4 ("Kanabo") | `Greatsword_Light1`–`4` | ✅ (pass 3; were Studio-only) | Greatsword lights, dash attack (light 1) |
| Greatsword CRIT ("odachiaircrit") | `Greatsword_Heavy` | ✅ (pass 3) | Greatsword heavy (R), `AnimPeak` 0.83 (Hit) |
| (old Greatsword heavy, 87785261665755) | `Alchemy_GreatswordOverhead` | ✅ | Coldsteel Smash, Alloy Divider (placeholder) |
| Greatsword WEAPON SKILL | `Greatsword_Skill` | ✅ | Whirlwind (T) |
| Greatsword Run | `Greatsword_Run` | ✅ | Greatsword `RunAnim` |
| Greatsword Idle, Sheathe, Unsheathe, Walk, GRIP | `Greatsword_Idle`, `_Unequip`, `_Equip`, `_Walk`, `_Grip` | ⏳ | Studio saves kept / empty. Idle got a new sheet id 2026-10-18 (the sheet recheck) |
| Greatsword GRIP VICTIM ("Greatsword KO", 136479651286488) | stored as `SheetId` on `Knocked` | ⏳ | **Questionable mapping:** this is the greatsword grip-victim column, not a generic knocked pose |
| Greatsword grip victim, row 17 | `Greatsword_Gripped` | 📦 | |
| Dagger M1 1–4 ("Hell Dagger") | `Daggers_Light1`–`4` | ✅ (pass 3; were Studio-only). M1 3 got a new id 2026-10-19: 130478011394399 (0.42 s; was 80421062677398) | Daggers lights, dash attack (light 2) |
| Dagger CRIT (Roblox asset name "Sword Crit"; owner confirmed) | `Daggers_Heavy` | ✅ (pass 3) | Daggers heavy, `AnimPeak` 0.54 (measured, no marker) |
| Daggers tool (2026-10-18) | one dagger, right hand only (the left `DaggerL` / `DaggerOff` removed) | ✅ | owner request |
| Dagger Idle | `Daggers_Idle` (96820335600899) | ✅ 2026-10-19 (4.93 s loop, Idle priority) | Daggers `IdleAnim`. The legs are keyed at full weight and animated, so the hips move (8–11° on each hip in Play). The Studio save without legs stays as `Save` |
| Mecha Arm Aim / Cannon Charge / Cannon Shoot (2026-10-19, owner) | `125033765857278` / `70940393329813` / `117668751587041` | 📦 all load | the Automail Mecha Arm (`fake arm`, joints `1`–`4`); not wired yet |
| Dagger GRIP / GRIP VICTIM | `Daggers_Grip` / `Daggers_Gripped` | 📦 | |
| Dagger Sheathe / Unsheathe | `Daggers_Unequip` / `Daggers_Equip` | ⏳ | Studio save kept |
| Rapier M1 1–4 | `Rapier_Light1`–`4` (88629079862060, 106111566774072, 94932519812153, 140341502749537) | ✅ 2026-10-19 (0.75 / 0.72 / 0.75 / 0.72 s) | Rapier lights. `AnimPeak` measured 0.38 / 0.33 / 0.38 / 0.40 (were 0.37) |
| Rapier Idle | `Rapier_Idle` (122141349611647) | ✅ 2026-10-19 (2.23 s loop; was 86848934973845, a gun idle) | Rapier `IdleAnim` (played at Idle priority; no leg keys) |
| Rapier Walk (Roblox name "Gun Walk"; owner: keep on the Rapier) | `Rapier_Walk` | ✅ | Rapier `WalkAnim` |
| Rapier CRIT | `Rapier_Heavy` (136861400985819) | ✅ 2026-10-19 (1.35 s; was 83129950699636) | Rapier heavy, `AnimPeak` 0.72 measured (was 0.43) |
| Rapier Flurry (T) | `Rapier_Skill` (79473015992584) | ✅ 2026-10-19 (2.0 s; markers Barrage 0.43, BarrageEnd 1.05, FinalStab 1.35) | Flurry. Its timing (`AnimSpeed` 0.9, 5 hits) wasn't re-tuned to the markers yet. The old Studio save stays as `Save` |
| Rapier GRIP / GRIP VICTIM | `Grips.Rapier_Grip` / `Grips.Rapier_Gripped` (85813024737924 / 75188810841150) | ✅ 2026-10-19 (1.23 / 1.80 s) | `Downed.Grips.Rapier` (Length 1.23). The grip keys `Hilt` under a "SheatheNightshade Rapier" pose our rig lacks, so the blade stays in its hand pose during the grip |
| Caestus Idle / CRIT | `Gauntlets_Idle` / `Gauntlets_Heavy` | ✅ | Gauntlets |
| Caestus GRIP / GRIP VICTIM ("Head Smasher") | `Gauntlets_Grip` / `Gauntlets_Gripped` | 📦 | |
| Guns Walk | `Guns_Walk` | ✅ 2026-10-18 | Guns `WalkAnim` |
| Guns M1 1–4 (whip) | `Guns_Whip1`–`4` (104678448678860, 111673179001500, 132014168951584, 84893375216590) | ✅ 2026-10-18 | gun light string, `AnimPeak` per hit with the old fist animations as fallback |
| Guns GRIP / GRIP VICTIM | `Guns_Grip` / `Grips.Guns_Gripped` | ✅ 2026-10-18 | `Downed.Grips.Guns` (3.0 s) |

## Weapon styles (style sheet): Fist styles only

| Style | Game names | Status |
|---|---|---|
| **Boxing** | `Boxing_Light1`–`4`, `_Idle`, `_Walk`, `_Heavy` (Crit), `_Block` | 📦 all load |
| **Lethwei** | `Lethwei_Light1`–`4`, `_Idle`, `_Walk`, `_Heavy` (Crit), `_Block` | 📦 all load; Block is the same id as Boxing's |

## Skills (skill sheet): all 📦, nothing wired yet

| Class | Game names |
|---|---|
| Fist | `Fist_BearHug` (+`Victim`), `Fist_WhereYouGoing`, `Fist_540Kick`, `Fist_SlamDunk` (+`Victim`), `Fist_SpinKick`, shared `Skill_GrabWhiff` |
| Sword | `Sword_QuickDraw`, `Sword_IaidoBarrage` |
| Daggers | `Daggers_SlipSlash`, `Daggers_BloodDash`, `Daggers_BulletSlash`, `Daggers_ComeHere` |
| Greatsword | `Greatsword_HeavyDrop`, `Greatsword_WhirlwindCleave` |
| Rapier | `Rapier_Ren`, `Rapier_SpeedLunge` |
| Guns | `Guns_IronRush` (+`Victim`) |

The current weapon skills (Dragonflash, Flurry, Barrage, Scissor Rush, Fan the Hammer) still use Studio-only saves or a gun shot. How the skill sheet maps onto them is an open owner decision.

## Movement and misc (general sheet)

| Sheet | Game name | Status | Notes |
|---|---|---|---|
| Swim Forward | `Swim_Forward` | 📦 | prone stroke, loops 1.5 s. **Swim Idle: no id** |
| Wall Ledge Walk Left | `LedgeWalk_Left` | 📦 | **standing** side-step along a narrow ledge (not a hang). **Right: no id** |
| Walk Left | `Walk_Left` | 📦 | **Walk Right: no id** |
| Forward Glide/Fall, Gliding Neutral | `Fall_Forward`, `Glide_Neutral` | 📦 | |
| Berserk Transformation, Lock Pick, Assassination | `Misc_BerserkTransform`, `Misc_LockPick`, `Misc_Assassinate` | 📦 | Assassination victim: no id |
| No! (emote) | `Emote_No` | 📦 | |
| Clap / Loop / Ground Slam / Arm Extend, Fire 1–5 | `Alchemy_*` | ✅ | alchemy casts |
| NEW UPPERCUT | `Uppercut` | ✅ | Ctrl+LMB |
| Build, Meditate, Pushups, Bow, Drag, Mask, Bandage, Arm Blast, Evil Cinematic, Cloak/Armor | `Misc_*`, `Drag` | ✅ | as before |
| Jump, Take The L, Trainings | — | ➖ | no id |
| Climb Right / Left / Down | `Climb.ClimbSideRight` (130050644596516), `ClimbSideLeft` (106220254643862), `ClimbDown` (107192077286134) | ✅ 2026-10-18 | directional climbing (`JumpManager`), looped at a stride matched to the climb speed. Rensei and Tutorial |

## Emotes and NPC idles

| Folder | Names | Used by |
|---|---|---|
| `Shared.Emotes` | `Emote_LeanIdle`, `Emote_AeroStep`, `Emote_Anthony`, `Emote_CleanGroove`, `Emote_DefaultDance`, `Emote_Floss`, `Emote_KazotskyKick`, `Emote_LoudLaugh`, `Emote_PeterParker`, `Emote_Thriller` | emote wheel |
| `Shared.NPCIdles` | `NPC_Chill`, `NPC_Admire`, `NPC_Sit5`, `NPC_Sit3`, `NPC_Kneel`, `NPC_CurledUp`, `NPC_Sit4`, `NPC_Beg`, `NPC_Sleep2`, `NPC_Plank` | emote wheel + NPC idles |
| `Registry.NPCIdles` | `NPC_LowHandOnGround`, `NPC_HandInPocket`, `NPC_Praise`, `NPC_Transcend`, `NPC_Prisoner`, `NPC_GreatswordEntrance`, `NPC_CrossArms`, `NPC_WallCoverRight`, `NPC_TaiChi`, `NPC_Blacksmith` (2026-10-18), `NPC_WallCoverLeft` (2026-10-18) | available to NPCs via the `IdleAnim` attribute |

### NPC idles: what loads (tested in Play, 2026-10-18)

- **Working (14):** Chill, Admire, Cross Arms, Hand in Pocket, Praise, Transcend, Tai Chi, Blacksmith Idle, Low Hand On Ground, Kneel, Curled Up, Plank, Greatsword Entrance, and the emote Lean Idle.
  - **Standing:** Chill, Cross Arms, Hand in Pocket, Praise, Lean Idle, Blacksmith, Tai Chi, Greatsword Entrance, Transcend.
  - **On the ground:** Admire (lying), Kneel, Curled Up, Low Hand On Ground, Plank.
- **Broken uploads (8):** Beg, Prisoner, Sit 3, Sit 4, Sit 5, Sleep 2, Wall Cover Left, Wall Cover Right. They're owned by the Rensei group and are Animation assets, but load with length 0 on the server and the client (nothing plays). Re-upload them. The emote wheel's **Sit** (Sit 3) and **Rest** (Sleep 2) use two of them, so those emotes don't play either.

### NPC idle cast (PROPOSAL picks, 2026-10-18)

| NPC | Place | Idle |
|---|---|---|
| Drillmaster Vask | Rensei and Tutorial | Cross Arms |
| Foreman Brask | Rensei (Foundry Yard) | Hand in Pocket |
| Mirra (night smelter) | Rensei (Foundry Yard) | Blacksmith Idle |
| Tobin (stoker) | Rensei (Foundry Yard) | Curled Up |
| Lise (apprentice) | Rensei (Foundry Yard) | Kneel |
| Placeholder NPC | Rensei | Chill |
| Calda (Flame trainer) | Rensei | Chill |
| Veyra (Ice trainer) | Rensei | Transcend |
| Holt (Earth trainer) | Rensei | Low Hand On Ground |
| Ansel (Wind trainer) | Rensei | Tai Chi |
| Brannoc (Metal trainer) | Rensei | Blacksmith Idle |
| Coach Harlan (Boxing) | Rensei (Lindenmoor) | Cross Arms |
| Master Thura (Lethwei) | Rensei (Lindenmoor) | Tai Chi |

To change one, set the NPC model's `IdleAnim` attribute to another name from the folders above. `ServerScriptService.NpcIdles` (same file in Rensei and the Tutorial) plays it for any NPC anywhere in Workspace.

## Weapon bones and hand placement (audit 2026-10-18)

**How a weapon sits in the hand:** each weapon Tool has an invisible grip part (the "bone"). `WeaponManager` joins it to the arm with a Motor6D built from the part's `MotorC0` / `MotorC1` attributes, and the visible weapon is welded to it. An animation moves the weapon only through a Pose **with the same name as that bone** (and parented to the arm's pose). The hold pose (`<Class>_Hold`, lowest priority) sets the weapon's angle whenever nothing else moves it.

**What the audit found:** most sheet animations were made on the animator's rig, whose weapon bones are called **`Hilt`** (right hand) and **`Hilt2`** (left), joined at (0, −0.65, 0) with no rotation (`Assets["RELLO IMPORTED ASSETS"]["Uppercut stuff"].Movement`). Our tools used other names, so those animations' weapon motion was silently dropped and the weapon stayed frozen in its hold pose while the arm swung.

| Weapon | Our bone | Animations whose weapon track was ignored | Status |
|---|---|---|---|
| Katana | **Hilt** (was Ninjato) | M1 1–4 (`Hilt`) | ✅ **Fixed:** the bone now uses the animator's name and joint, with the rest pose unchanged. The four Studio saves that move `Ninjato` (Hold, Heavy, Idle, Run) got matching `Hilt` poses. Measured: M1 2 / M1 4 no longer pass through the body (1 and 2 frames before → 0), and M1 3's blade points 5.3 studs forward at the hit (2.5 before). Checked on the real character in Play. |
| Rapier | Ninjato | 2026-10-19 set: M1 1–4, crit, idle, Flurry and grip all key `Hilt` (Right Arm → Hilt). The walk is still the gun-rig one | ⚠️ Not changed. `WeaponManager` names the motor after the tool's grip part (`Ninjato`), so the rename would be a tool change (part name + the animator's (0, −0.65, 0) joint, as done for the katana), not a one-line code change. Until then the blade keeps its hand pose and follows the arm only. |
| Greatsword | Greatsword | M1 1–4, crit, run (`Hilt`, `Hilt2`, `Iron Kanabo`) | ⚠️ Not changed. Our grip has a big rotation (tuned for its own draw / hold / carry), and converting the tracks made the crit and M1 2 clip (9 and 3 frames). The current swings already reach 9–10 studs forward. |
| Daggers | Dagger / DaggerL | M1 1–4 (`Hilt` / `Hilt2`) | ⚠️ Not changed. The animator's dagger mount is flipped about 175° from ours (reverse grip vs forward), and the converted tracks weren't clearly better. |
| Pistols | Right Hand | shots 1–4 and crit (`PistolHandleR` / `PistolHandleL`) | ⚠️ Not changed. The gun stays in its plain grip while aiming; the animator's pistol rig (`1911Rig`) mounts the gun differently. |
| Caestus | (welded, can't move) | crit (`BladeBase`) | ➖ Gauntlets are welded to the fists, so nothing to move. |

**What fixes the rest properly:** either the animator re-exports with our bone names, or shares the rig file for each weapon (how the sword / greatsword / daggers / pistols sit on `Hilt`). With that, each tool's grip can match the animator's exactly, as the katana now does.

**Studio-only weapon animations:** Sword Hold / Heavy / Skill, Greatsword Equip / Hold / Idle / Carry, Daggers Equip / Hold / Skill, Gauntlets Skill and Guns Idle play only in Studio until their `Save` is published.

## Fixing the ⏳ ids

These ids are owned by the group but still return "KeyframeSequence loaded is not valid" (re-checked 2026-10-19). Each stays on its Studio save until it is re-uploaded:
- Dagger: Sheathe 120069108676683 (`Daggers_Unequip`), Unsheathe 82218741773055 (`Daggers_Equip`, the Daggers draw)
- Greatsword: Unsheathe 122309498454912, Sheathe 78181583295596, Walk 76985284126069, KO / GRIP VICTIM 136479651286488
- Katana: Sheathe 135958788270981, Walk 110642878390298
- Greatsword Idle and GRIP weren't part of the 2026-10-19 re-check (broken on 2026-10-17).

Katana Unsheathe was fixed by its new upload (2026-10-19).

Because ownership is correct, the upload itself is bad. Re-export the animation, upload it to the group again, and put the new id on the sheet.

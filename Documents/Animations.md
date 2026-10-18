# Animations — sheet to game map

Sources: the three animation sheets: **general** ("Animation ID's"), **weapon styles** and **skills**. Last pass **2026-10-17 (pass 3)**.

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
| Katana M1 1–4 | `Sword_Light1`–`4` | ✅ (pass 3: new ids, old ones kept as `PreviousId`) | Sword lights, Rapier lights 1/3/4, Sword dash attack (light 4) |
| Katana Idle | `Sword_Idle` | ✅ | Sword `IdleAnim` |
| Katana Sheathe / Unsheathe / Walk | `Sword_Unequip` / `Sword_Equip` / `Sword_Walk` | ⏳ | Studio saves kept |
| Greatsword M1 1–4 ("Kanabo") | `Greatsword_Light1`–`4` | ✅ (pass 3; were Studio-only) | Greatsword lights, dash attack (light 1) |
| Greatsword CRIT ("odachiaircrit") | `Greatsword_Heavy` | ✅ (pass 3) | Greatsword heavy (R), `AnimPeak` 0.83 (Hit) |
| (old Greatsword heavy, 87785261665755) | `Alchemy_GreatswordOverhead` | ✅ | Coldsteel Smash, Alloy Divider (placeholder) |
| Greatsword WEAPON SKILL | `Greatsword_Skill` | ✅ | Whirlwind (T) |
| Greatsword Run | `Greatsword_Run` | ✅ | Greatsword `RunAnim` |
| Greatsword Idle, Sheathe, Unsheathe, Walk, GRIP | `Greatsword_Idle`, `_Unequip`, `_Equip`, `_Walk`, `_Grip` | ⏳ | Studio saves kept / empty |
| Greatsword GRIP VICTIM ("Greatsword KO", 136479651286488) | stored as `SheetId` on `Knocked` | ⏳ | **Questionable mapping:** this is the greatsword grip-victim column, not a generic knocked pose |
| Greatsword grip victim, row 17 | `Greatsword_Gripped` | 📦 | |
| Dagger M1 1–4 ("Hell Dagger") | `Daggers_Light1`–`4` | ✅ (pass 3; were Studio-only) | Daggers lights, dash attack (light 2) |
| Dagger CRIT (Roblox asset name "Sword Crit"; owner confirmed) | `Daggers_Heavy` | ✅ (pass 3) | Daggers heavy, `AnimPeak` 0.54 (measured, no marker) |
| Dagger GRIP / GRIP VICTIM | `Daggers_Grip` / `Daggers_Gripped` | 📦 | |
| Dagger Sheathe / Unsheathe | `Daggers_Unequip` / `Daggers_Equip` | ⏳ | Studio save kept |
| Rapier Idle / Walk (Roblox names "Gun Idle Animation" / "Gun Walk"; owner: keep on the Rapier) | `Rapier_Idle` / `Rapier_Walk` | ✅ | Rapier |
| Rapier CRIT | `Rapier_Heavy` | ✅ | Rapier heavy |
| Caestus Idle / CRIT | `Gauntlets_Idle` / `Gauntlets_Heavy` | ✅ | Gauntlets |
| Caestus GRIP / GRIP VICTIM ("Head Smasher") | `Gauntlets_Grip` / `Gauntlets_Gripped` | 📦 | |
| Gun (any) | — | ➖ | |

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

## Fixing the ⏳ ids

These 11 ids are owned by the group but still return "AnimationClip loaded is not valid" (re-checked 2026-10-17):
- Greatsword: Idle, Unsheathe, Sheathe, Walk, GRIP, KO / GRIP VICTIM
- Katana: Sheathe, Unsheathe, Walk
- Dagger: Sheathe, Unsheathe

Because ownership is correct, the upload itself is bad. Re-export the animation, upload it to the group again, and put the new id on the sheet.

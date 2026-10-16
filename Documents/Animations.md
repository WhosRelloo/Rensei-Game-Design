# Animations — sheet to game map

Source: the **Animation ID's** Google Sheet (last pass 2026-10-16, second read). In Studio every animation is an `Animation` object under `ReplicatedStorage.Assets.Animations`, found by **name** (`AnimationManager`). An `Animation` with an empty id plays its local `KeyframeSequence` save in Studio only, and nothing in a live server. Status is from loading each id in Studio Play on 2026-10-16. The Tutorial place's Animations folder was brought in line with Ye's on the same day.

**Legend:**
- ✅ live: the published id loads.
- ⏳ broken: the id on the sheet doesn't load ("AnimationClip loaded is not valid"). The game keeps the previous animation or Studio save, and the sheet id is stored as the attribute `SheetId`.
- ➖ not in the sheet yet.

## Weapons

| Sheet | Game name | Status | Used by |
|---|---|---|---|
| Katana M1 1–4 | `Sword_Light1`–`4` | ✅ | Sword (and Rapier lights 1/3/4) |
| Katana Idle | `Sword_Idle` | ✅ | Sword `IdleAnim` |
| Katana Sheathe / Unsheathe | `Sword_Unequip` / `Sword_Equip` | ⏳ | Studio save kept |
| Katana Walk | `Sword_Walk` | ⏳ | — |
| Greatsword M1 1–4, Idle, Unsheathe | `Greatsword_Light1`–`4`, `_Idle`, `_Equip` | ⏳ | Studio saves kept |
| Greatsword Sheathe, Walk, GRIP | `Greatsword_Unequip`, `_Walk`, `_Grip` | ⏳ | — (empty until fixed) |
| Greatsword Run | `Greatsword_Run` | ✅ | Greatsword `RunAnim` |
| Greatsword CRIT | `Greatsword_Heavy` | ✅ (new) | Greatsword heavy (R), `AnimPeak` 0.85; also two alchemy moves that borrow it |
| Greatsword WEAPON SKILL | `Greatsword_Skill` | ✅ (new) | Whirlwind (G), `AnimPeak` 1.31 (PROPOSAL) |
| Greatsword KO | `Knocked` (downed pose) | ⏳ | Studio save kept |
| Dagger Sheathe / Unsheathe | `Daggers_Unequip` / `Daggers_Equip` | ⏳ | Studio save kept |
| Rapier Idle / Walk | `Rapier_Idle` / `Rapier_Walk` | ✅ | Rapier `IdleAnim` / `WalkAnim` |
| Rapier CRIT | `Rapier_Heavy` | ✅ | Rapier heavy (R) |
| Caestus Idle | `Gauntlets_Idle` | ✅ | Gauntlets `IdleAnim` |
| Caestus CRIT | `Gauntlets_Heavy` | ✅ (new id 75715098693180; the old one is kept as `PreviousId`) | Gauntlets heavy (R) and Shoulder Charge, `AnimPeak` 0.88 (its `Hit` marker) |
| Gun (any) | — | ➖ | `Guns_Idle` was cleared: its id is the sheet's Rapier idle (Studio save kept) |

## Alchemy, combat, misc

| Sheet | Game name | Status | Used by |
|---|---|---|---|
| Clap / Loop / Ground Slam / Arm Extend | `Alchemy_Clap` / `_ClapLoop` / `_GroundSlam` / `_ArmExtend` | ✅ | alchemy casts |
| Fire 1–5 | `Alchemy_Fire1`, `Alchemy_Ignite` (= Fire 2, also `Alchemy_Fire2`), `_Fire3`–`_Fire5` | ✅ | alchemy casts |
| NEW UPPERCUT | `Uppercut` | ✅ | Ctrl+LMB |
| Build Anim | `Misc_Build` | ✅ | **wired:** loops while a minigame is open (`MinigameService`) |
| Meditate, Pushups, Bow | `Misc_Meditate`, `Misc_Pushups`, `Misc_Bow` | ✅ | emote wheel |
| Drag | `Drag` (Shared.Combat.Downed) | ✅ | registered, not wired |
| Mask Equip, Bandage Use, Arm Blast | `Misc_MaskEquip`, `Misc_BandageUse`, `Misc_ArmBlast` | ✅ | registered, not wired: no masks, bandage item or prosthetics yet |
| Evil Cinematic | `Misc_EvilCinematic` | ✅ (new) | registered, for a villain cutscene |
| Cloak/Armor Equip | `Misc_ArmorEquip` | ✅ (new) | registered, for when armor exists |
| Jump, Fall | — | ➖ | no id yet |

## Emotes and NPC idles

| Folder | Names | Used by |
|---|---|---|
| `Shared.Emotes` | `Emote_LeanIdle`, `Emote_AeroStep`, `Emote_Anthony`, `Emote_CleanGroove`, `Emote_DefaultDance`, `Emote_Floss`, `Emote_KazotskyKick`, `Emote_LoudLaugh`, `Emote_PeterParker`, `Emote_Thriller` (Take The L: no id yet) | the emote wheel |
| `Shared.NPCIdles` | `NPC_Chill`, `NPC_Admire`, `NPC_Sit5`, `NPC_Sit3`, `NPC_Kneel`, `NPC_CurledUp`, `NPC_Sit4`, `NPC_Beg`, `NPC_Sleep2`, `NPC_Plank` (new) | the emote wheel (Kneel / Sit / Rest) and **NPC idles** |

All of these load (✅).

**NPC idles:** `ServerScriptService.NpcIdles` loops an NPC's `IdleAnim` attribute. Picks (PROPOSAL):
- `NPC_Chill`: Foreman Brask, Tobin, Drillmaster Vask, and the Flame, Earth and Metal trainers.
- `NPC_Admire`: Lise, Mirra, and the Ice and Wind trainers.

The sheet suggests Lean Idle for some NPCs, but none of them stands against a wall or post yet.

## Fixing the ⏳ ids

These 15 ids still return "AnimationClip loaded is not valid" in this place (re-checked 2026-10-16, second pass):
- Greatsword M1 1–4, Idle, Unsheathe, Sheathe, Walk, GRIP, KO
- Katana Sheathe, Unsheathe, Walk
- Dagger Sheathe, Unsheathe

That usually means the wrong asset id was copied, or the animation isn't published where this game can use it (it must belong to the group that owns the game, or to the place owner). To fix one: re-publish or re-copy the id, put it in the sheet, and set it as that `Animation`'s `AnimationId`. The stored `SheetId` attribute shows which one each is.

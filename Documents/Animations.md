# Animations — sheet to game map

Source: the **Animation ID's** Google Sheet (last pass 2026-10-16). In Studio every animation is an `Animation` object under `ReplicatedStorage.Assets.Animations`, found by **name** (`AnimationManager`). An `Animation` with an empty id plays its local `KeyframeSequence` save in Studio only, and nothing in a live server. Status is from loading each id in Studio Play on 2026-10-16.

**Legend:** ✅ live (published id loads) · ⏳ id on the sheet doesn't load ("AnimationClip loaded is not valid"); the game keeps the previous animation or Studio save, and the sheet id is stored as the attribute `SheetId` · ➖ not in the sheet yet.

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
| Greatsword KO | `Knocked` (downed pose) | ⏳ | Studio save kept |
| Dagger Sheathe / Unsheathe | `Daggers_Unequip` / `Daggers_Equip` | ⏳ | Studio save kept |
| Rapier Idle / Walk | `Rapier_Idle` / `Rapier_Walk` | ✅ | Rapier `IdleAnim` / `WalkAnim` |
| Rapier CRIT | `Rapier_Heavy` | ✅ | Rapier heavy (R) |
| Caestus Idle | `Gauntlets_Idle` | ✅ | Gauntlets `IdleAnim` |
| Caestus CRIT | `Gauntlets_Heavy` | ✅ | Gauntlets heavy (R) |
| Gun (any) | — | ➖ | `Guns_Idle` had the id the sheet now lists as the Rapier idle; cleared (Studio save kept) |

## Alchemy, combat, misc

| Sheet | Game name | Status |
|---|---|---|
| Clap / Loop / Ground Slam / Arm Extend | `Alchemy_Clap` / `_ClapLoop` / `_GroundSlam` / `_ArmExtend` | ✅ (unchanged) |
| Fire 1–5 | `Alchemy_Fire1`, `Alchemy_Ignite` (= Fire 2, also `Alchemy_Fire2`), `_Fire3`–`_Fire5` | ✅ |
| NEW UPPERCUT | `Uppercut` | ✅ (Ctrl+LMB) |
| Drag | `Drag` (Shared.Combat.Downed) | ✅ registered, not wired |
| Mask Equip, Bandage Use, Arm Blast, Build, Meditate, Pushups, Bow | `Misc_MaskEquip`, `Misc_BandageUse`, `Misc_ArmBlast`, `Misc_Build`, `Misc_Meditate`, `Misc_Pushups`, `Misc_Bow` | ✅ registered, not wired |
| Jump, Fall | — | ➖ (no id yet) |

## Emotes and NPC idles (registered, not wired yet)

| Folder | Names |
|---|---|
| `Shared.Emotes` | `Emote_LeanIdle`, `Emote_AeroStep`, `Emote_Anthony`, `Emote_CleanGroove`, `Emote_DefaultDance`, `Emote_Floss`, `Emote_KazotskyKick`, `Emote_LoudLaugh`, `Emote_PeterParker`, `Emote_Thriller` (Take The L: no id yet) |
| `Shared.NPCIdles` | `NPC_Chill`, `NPC_Admire`, `NPC_Sit5`, `NPC_Sit3`, `NPC_Kneel`, `NPC_CurledUp`, `NPC_Sit4`, `NPC_Beg`, `NPC_Sleep2` |

All of these load (✅).

## Fixing the ⏳ ids

These 15 ids return "AnimationClip loaded is not valid" in this place. That usually means the wrong asset id was copied, or the animation isn't published where this game can use it (it must belong to the group that owns the game, or to the place owner). Re-publish or re-copy the id, put it in the sheet, and set it as that `Animation`'s `AnimationId`; the stored `SheetId` attribute shows which one each is.

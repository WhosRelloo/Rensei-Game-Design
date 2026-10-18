# Rensei: owner hand-off (2026-10-18)

This is what's waiting on you, followed by where each piece of today's work is written up. **Nothing was published.** Every change was made in Studio, with backups in `ServerStorage.RenseiBackups`. Every Play test snapshotted your profile and restored it exactly afterwards. In the Main Menu, the owner's real character (slot 2) was never touched and no character was created.

## Needs you (only you can do these)

| # | What | Why it waits | Where it plugs in |
|---|---|---|---|
| 1 | ~~Create the Creator Plus Game Pass~~ **Done 2026-10-18** as a Developer Product (3719583889), wired | | Main Menu: `Rensei.CreatorPlus.ProductId` |
| 2 | **Confirm or change the Creator Plus split.** Free: undo / redo, random, reset. Paid: custom skin colour and 3 saved looks | My proposal | same module |
| 3 | **Re-upload 12 broken sheet animations:** Greatsword Idle / Walk / Sheathe / Unsheathe / KO; Katana Walk / Sheathe / Unsheathe; Daggers Sheathe / Unsheathe; Ledge Idle Left / Right | Roblox reports their assets as "AnimationClip loaded is not valid". Their sheet ids are kept in each animation's `SheetId` attribute | Rensei: `Assets.Animations` (see `Animations.md`) |
| 4 | ~~Save-slot Developer Product~~ **Done 2026-10-18** (3719583607), wired with the three reroll packs | | `Rensei.Slots.ProductId`, `Rensei.Clans.RerollPacks` |
| 5 | **Upload the product icons** to the five products | They show the default icon now | `Art/Market Icons/*.png` |
| 7 | **Weapon animations: send the animator's weapon rigs** (or have them export with our bone names) | The sheet's greatsword, dagger, rapier and pistol attacks move a bone called `Hilt` / `PistolHandleR`, which our tools don't have, so the weapon stays in its hold pose during those attacks. The katana is fixed already | `Animations.md`, "Weapon bones and hand placement" |
| 6 | **Re-upload 8 NPC idle animations:** Beg, Prisoner, Sit 3, Sit 4, Sit 5, Sleep 2, Wall Cover Left, Wall Cover Right | They load with length 0 (nothing plays). The emote wheel's Sit and Rest use two of them | Rensei: `Assets.Animations` (`Shared.NPCIdles`, `Registry.NPCIdles`); see `Animations.md` |

## Your call (proposals are in place and can be changed)

- **Names:** "Brawler" (the base fist style), "Mill Pond", "Gorge Pool", "Lindenmoor".
- **Swimming numbers:**
  - sprint × 1.6 for 14 stamina/s;
  - 15 s of air;
  - drowning at 6 % of max health per second;
  - where the deep water is. Pools are limited to about 5.2 deep by the baseplate.
- **Weapon skills and the skill sheet:** how the sheet maps onto Dragonflash, Flurry, Barrage, Scissor Rush and Fan the Hammer (`Animations.md`).
- **Esc can't close dialogue** (Roblox reserves Esc). It's covered by the new X button; say if you'd like a key as well.
- **The base walk speed is inconsistent** in the code (12 by the game's convention, but WCS characters can start at 16). Not changed.

## Decided today

| Decision | Result |
|---|---|
| Starting weapons | Fists, Katana, Rapier, Caestus, Greatsword, Daggers. Enemies still use all eight, including the guns |
| Decision 8: base moveset | Stays a selectable style (always learned, no trainer) |
| Decision 6: swimming | Basic swimming + extras + touch buttons; enemies can't fight in water either |
| Dialogue close | Small X button on the dialogue box (works with touch) |

## Where everything is (all in `Changelog.md`)

| Changelog | Covers |
|---|---|
| `Changelog entry - UI Pass.md` | Smaller menus; leaderboard on the original art with character names; level-up and codex popups (plus the codex-unlock fix); creator camera (FACE / BODY) and sharpness; creator QOL and Creator Plus; starting weapons; no menus over dialogue; dialogue X button; decision 8 |
| `Changelog entry - Basic Swimming.md` | Swim state; no combat or alchemy in water (players and enemies); Mill Pond; sprint, diving, breath and drowning; Gorge Pool; touch buttons; drowning balance; Earth-spike visual fix |
| `Changelog entry - Skill Fixes and Weapon Regression.md` | Iron Rush overshoot fix; Phoenix Drive aim fix (NPC and player casts); Greatsword / Rapier / Daggers M1 strings verified |
| `Changelog entry - Sheet Import, Skills, Styles, Guns.md` | Sheet animations, style trainers, the Boxing infinite combo, gun balance, grabs, skill latch, the "No!" emote |
| `Changelog entry - Fist Styles.md`, `- Phase 8 and 9.md`, `- Starter Map Lindenmoor.md`, `- Guide, Challenges, Alchemist NPCs.md` | Earlier work |

## Not tested anywhere (needs real conditions)

- **Two or more players:** the leaderboard, other players seeing swim and style animations, PvP in water.
- **A real phone or tablet:** touch was tested on a PC through the game's `ForceMobileControls` test switch.
- **A live server and real purchases** (no Game Pass or Product exists yet).

# Rensei Changelog

What each phase built and how it was tested. Newest first. Work is in the Studio place **Ye** unless an entry says otherwise. In the entries from 2026-10-17 on, a place called **Rensei** is Ye (106992859583940, the Studio window's title) and **Main Menu** is Character Customization (123967384111466). Backups of every touched script are in `ServerStorage.RenseiBackups`.

**Discord announcements (owner, 2026-10-23).** From now on, every entry ends with a `### Discord announcement` section: a ready-to-paste post for players. It is written in plain words about what players will notice in the game, with no file names, script names, test results or PROPOSAL tags, and stays under Discord's 2,000-character limit. An entry whose work isn't in the live game yet says so in the section (for example "Hold: not live yet") instead of announcing it, and its post is written when it ships.

## 2026-10-28 — The takedown key is rebindable (not live)

**Owner** (asked whether the takedown key should be rebindable): "Yes it should rebindable".

**What changed** (Ye and Foundry Yard, the same files in both; the Tutorial is not a package consumer and has no takedowns, so it is left alone):
- **`Rensei.Settings`:** `Defaults.Keys.Takedown = "N"` and `Bindable.Takedown`; N is out of `Reserved`. B and V (grip, carry) stay reserved. The server's save path (`Requests.Settings` → `Settings.Resolve`) is unchanged: a saved Takedown key is kept when `IsBindableKey` accepts it, anything else falls back to N, and the one-key-per-action rule covers it like the other actions. Nothing changed in ProfileService or the data layer: the key lives in the profile's existing `Settings.Keys`.
- **`Keybinds`:** `Keys.Takedown = "N"` (without it `Keybinds.Set` ignored the action).
- **The Settings panel:** a **Takedown** row on the Keybinds tab, after Aim (Guns): a copy of the Aim row (`StarterGui.Uis.Settings.MainFrame.Container.Takedown`, LayoutOrder 150, attribute `KeyNAdd`), the same template and art, made by `Art/Studio/UI/takedown_row.lua` (MODE "remove" takes it out). `SettingsUI` needed no change: it wires every row by its `Tab` and `Kind` attributes.
  - The first copy came out short (Size Y 0.049 against Aim's 0.0913, the same thing the 2026-10-18 entry fixed for Combat Log and Aim). The script now sets the size after parenting, and a re-run fixed both places: every row is 0.0913.
  - **For the publish list:** `StarterGui.Uis` is a **package** in Ye (PackageLink v1), and it now has this extra row in both places.
- **`TakedownUI`:** the prompt is made on `TakedownUI.Key()`, the player's binding (N by default). A rebind (`Keybinds.Changed` "Takedown") drops the prompt, and the next pick (0.1 s) makes a fresh one on the new key, so PromptUI draws the new key's label with no respawn. Left unbound ("Unknown"), no prompt is offered on keyboard and mouse; on touch or a gamepad it is offered as before. Tap, hold, `TapGrace` and the gamepad and touch paths are unchanged.
  - For hostages Task 12: read the key with `TakedownUI.Key()` (an `Enum.KeyCode`; `Enum.KeyCode.Unknown` when unbound) and offer the prompt only when `TakedownUI.Offered()` is true.
- Comments that said N is reserved: `Rensei.Settings`, `Rensei.Takedown`, `CombatModeUI`, `TakedownUI`. `Documents/Controls.md`: Takedowns now say "N (rebindable)".
- **Tooling:** two new sync pairs, `Managers.Keybinds` and `RenseiTests.Test_Settings` (both places).

**Tests:**
- `Test_Settings` (new, pure): RED 0/6 against the old `Rensei.Settings`, GREEN 6/0 (Ye, Edit, from the repo sources).
- `Art/Studio/Takedown/client_checks.lua`: `NReserved` is gone (its rule is now in `Test_Settings`); new `TakedownKeyFollowsBinding`, `UnboundHidesKeyboardPrompt` and `ServerSavesTakedownKey`.
- After the sync (both places, backup `Pre-KeyN_2026-10-28`; `sync.py --check` showed only these six labels differing before it, and SAME after): `Test_Settings` 6/0 and `Test_Takedown` 13/0 in Edit, in Ye and in Foundry.
- **Play, Ye, lock `Ye:keyN`, two sessions.** Each one: `TestNoSave` set in Edit, then `DataManager.IsNoSave()` true and the mock profile confirmed from the game VM before anything changed; hooked and dumped; restored; dump 2 equal to dump 1 (15,309 chars); Stop; unhook read back as gone; helper out; the switch and lock cleared.
  - **RED** (the old Studio code): the three new checks 0/3. There was no Takedown key in Keybinds, and the server dropped a saved H.
  - **GREEN** (after the sync and the row): 11/0. That is every client check except `EStillDraws`, which needs a real E press; CombatModeUI only had a comment change. The prompt moved to H with the label "H" on a fresh prompt and came back to N, with hold time and action text unchanged. Unbound on keyboard and mouse, no prompt. The server kept H and sent LeftShift and "NotAKey" back to N, and the player's own binding and Settings table were put back. On the client, the Settings Takedown row showed "N" on the Keybinds tab.
- Not tested: a real phone or gamepad (the unbound case on touch or gamepad is code-read only), and a rebind made by a real key press in the Settings panel. The checks rebind through `Keybinds.Set`, as the panel's Apply does.

### Discord announcement

Hold: not live yet. Post this when the owner publishes the update.

```md
**Small update: Takedown key**
- You can now change the takedown key (N by default) in the Menu (P), under Keybinds. The prompt shows your new key right away.
```

## 2026-10-27 — TestNoSave: test Play sessions can't write the real save (Studio only, not live)

**Owner:** "Yes, add a Studio-only no-save switch for test runs, before hostages starts."

**Why:** the Play test suites change the tester's profile in memory (EXP, money, deeds, Heat, DayCount), and until now only the test hook's snapshot and restore kept that out of the save. On 2026-10-27 Play was stopped from outside the test runner, the restore never ran, and test state was written to the owner's real slot 2.

**What changed** (`DataManager`, in `ServerStorage.RenseiServer.CharacterHandler` in Ye and Foundry Yard, the same file in both; repo `Scripts/ServerScriptService/CharacterHandler/DataManager.lua`):
- **The switch:** `ServerStorage:GetAttribute("TestNoSave") == true`, set in **Edit** before Play (the Play copy inherits it). It is off by default, so the owner's own Studio play-testing saves exactly as before.
- **Studio only:** `RunService:IsStudio()` is checked first, so a live server never reads the attribute, even in a place published with it set by mistake. It is decided once when DataManager loads.
- **With it on**, a joining player's real save is read with a plain `GetAsync` on the `PlayerData` store (the store and key ProfileService uses): no session lock and no write. It is deep-copied into a **mock** profile (`ProfileStore.Mock`, memory only), and Migrate, Reconcile, ProfileGuard and the release listener run on that as usual. Auto-saves and the release on leave or Stop go to the mock store, never to the DataStore.
  - `ViewProfileAsync` is **not** used: in this ProfileService version it reads through `UpdateAsync`, which is a write.
  - An empty slot (no record, a deleted slot's `"PROFILE_WIPED"`, or a stub holding only GlobalUpdates) starts from the template, as ProfileService would. A save that can't be read, or is in any other shape, kicks the player with a "TestNoSave: ..." message; the session never falls back to the real store.
  - The server sets `ReplicatedStorage`'s `TestNoSave` attribute to true and warns once: `[DataManager] TestNoSave: this Studio session will not save`.
- **`DataManager.IsNoSave()`** returns true only in such a session, for the test kits to check.
- **With it off (and on every live server)** the code runs the same calls in the same order as before.
- **Other DataStore writes a test session could reach:** none. `SlotAccount`'s writes are only called from the Main Menu place, `AdminService`'s (snapshots, bans, the staff log) only from the admin panel, and `RoadService`'s MemoryStore write already skips Studio. ProfileService's own Studio access probe (`____PS`) is not player data and is left alone.
- **Not changed:** the Tutorial (`FlowData`) and Main Menu (`MenuData`), where no tests run.
- **Tooling:** DataManager is now a sync pair (`CharacterHandler.DataManager`, both places) in `Art/Studio/Regions/Foundry/data/sync_manifest.json`. The Play protocol note is in `Lindenmoor Kit.md` ("Studio tooling note (2026-10-27, TestNoSave)").

**Tests:** the new source compiles in Studio (Foundry, Edit); both places' DataManager matched the repo before the change (normalised hash); `test_sync.py` PASS 1338 / FAIL 0. Synced to both places (backup `Pre-TestNoSave_2026-10-27`; `sync.py --check` SAME 115 in Ye, 114 in Foundry).
- **Play, Ye, lock `Ye:nosave`, hooked and dumped as usual.** Every real-save read was a `GetAsync` from the Play server, comparing the whole record and its DataStore version.
  - **Session A:** the switch was proven on before anything changed: the warning, both attributes, and the profile in ProfileService's mock set and not its real one. The real save's Exp was 576. The test added 12,345 Exp to the session (12,921), waited 40 s, then stopped Play from outside the runner with no restore.
  - **Session B:** the real save was byte-identical, with the same version (`…0000001465…`, last written before session A) and Exp 576. Play_Downed with the switch on gave 10/2: the known KnockGraceSnapsBack and DeepWaterStill flakes, which have nothing to do with saving. The restore dump equalled the first dump, and the real save was still unchanged.
  - **Session C** (a clean rerun): Play_Downed 12/0, both dumps equal, and the real save unchanged.
  - After each session the hook was read back as gone. The switch and the lock were cleared in Edit.

### Discord announcement

No player-facing change; nothing to post.

## 2026-10-27 — Assassinations: stealth takedowns, PvE only (not live)

The assassinations plan (`Documents/plans/2026-10-25-assassinations.md`, Tasks 1–12 plus Task 6b, run 2026-10-27; spec `Documents/specs/2026-10-25-assassinations-design.md`, **approved by the owner 2026-10-27**, "Approve as written", with the three §18 answers) answers the owner's Backlog item: "Assassinations that work with the detection system (sight, light, sound)", "I threw anims in the spreadsheet for it", and the older "Add assassinations to the game, like we talked about before (ONLY PVE)". All of it is in the Studio Edit sessions of **Ye** (106992859583940) and **Foundry Yard** (109591196441030), the same in both; the Tutorial got only DownedManager and Ragdoll (below). **Nothing is saved or published.** This is the plan's only Changelog entry. The downed crawl side task that ran first has its own entry below ("Downed crawl, Downed Idle, Carry and Carried animations").

Every number is a **PROPOSAL** unless the owner chose it or it was measured. The numbers live in `Rensei.Takedown`; the rules are in `Documents/COMBAT_SYSTEM.md`, "Takedowns (PvE only)".

**What existed and what was missing** (the spec's audit, §2):
- **A1** No takedown of any kind; `Misc_Assassinate` was registered but never played, and sat in `Registry`, which the client doesn't preload.
- **A2** A killed enemy's body was deleted 4 s after death, so a kill left nothing to find.
- **A3** No NPC ever noticed a body: perception only looked at players.
- **A4** The Grip finisher was loud (a 20-stud "Hit" sound that alarmed the victim).
- **A5** NPCs could only be called to a search about a player, never to a spot.
- **A6** Crouch only works out of Combat Mode (in Combat Mode Ctrl is the Uppercut).
- **A7** Tapping a prompt does nothing in Combat Mode.
- **A8** Any visible prompt stopped E from drawing your weapon.
- **A9** The view cone counts someone straight above as "ahead", so it can't judge a drop from above.
- **A10** Townsfolk are hittable, knockable and grippable; killing one is `murder_townsfolk`.
- **A11** Enemies heal to full at home, so an unaware enemy is always at full health.
- **A12** Bosses are the five trial foes, which perception doesn't track.
- **A13** No current enemy has a faction, so their witnesses add no rumour and no enemy killing is a crime.
- **A14** The stealth design lives in the 2026-10-19 morality spec's §17, not the proposal document.
- **A15** Crouching runs a real Stun, so Grip and Carry are refused while crouched (confirmed in Task 1).

**What changed:**
- **Two takedowns on one key, from Calm:** behind an enemy that hasn't caught you, a prompt (the game's own PromptUI art) shows **N**, the enemy's name and its state ("Bandit (unaware)", "suspicious" or "cautious") and "Knock out · hold to kill". **Tap N: knock out** (2.0 s choke). **Hold N 0.6 s: assassinate** (1.0 s, the kill at the animation's "Snap").
- **The gates** (server-checked, `TakedownService`): the target is an `EnemyService` enemy, alive and free; not Alert and not fully aware of you; you are in its 140° rear arc (+10° server slack), within 4 studs (+1.5) and 3 up or down, with a clear line torso to torso; you are alive, free, on the ground, not swimming and **out of Combat Mode**. Crouching isn't required (its own Stun is ignored, A15). **The first check refuses a player's character, whatever else is true.**
- **Witnesses:** at the start, every tracked NPC but the victim takes one quick look (`PerceptionService.Glimpse`). An enemy that sees it goes Alert on you; a townsperson that sees it **runs** (`TownsfolkService.Startle`, owner §18.2) and **reports** it: the deed is recorded with witnesses, so rumours spread (and Heat, when the deed is a crime).
- **Sounds:** the knockout makes a "Choke" (6 studs), the assassination a "Takedown" (4 studs) as the body drops. The kill skips the 20-stud Hit (A4); EXP, money and quest credit go through `WorldService.Credit` once.
- **The knockout:** the enemy is knocked for 300 s (the existing knocked state, so V carries it, B grips it, a `TakesPrisoners` NPC takes it). It is a findable "Out" body while it lies there. **Waking up raises the alarm:** it searches where it woke and calls NPCs within 40 studs (`PerceptionService.Raise`). No credit and no deed.
- **The assassination:** the enemy dies, the kill is credited once and the deed is `assassinated_bandit` (Mercy −1, cap 10 a day), or **`assassinated_guard`** (Mercy −5, Crime 60, owner §18.3) for a law-faction victim. No law-faction enemy spawns yet, so the guard deed is built and tested on a test rig, ready for guards.
- **Bodies:** an assassinated body **ragdolls** (owner request, below) and stays **120 s** (was 4). Enemies that aren't Alert find bodies by sight, at their normal sight rate, with the **light on the body** counting (deep shadow about 6× slower than a lamp) and a body under water seen at ×0.3. A found body turns the finder Alert, searching there and calling others in; each body is found once. Townsfolk don't look for bodies.
- **Carrying bodies** (owner §18.1, "Yes, carry bodies"): V picks up a dead takedown body like a knocked one; its 120 s timer keeps running and a carried body is still a body. B never grips a corpse.
- **Gripped bodies ragdoll** (owner: "When people are dead, make them ragdoll so it's easier to spot a body, looks smoother, etc." / "And by dead I mean after they get gripped"): a finished Grip (B) ragdolls the body (enemies, townsfolk, and players gripped by players); assassinated bodies ragdoll too; other deaths are unchanged. New `Managers.Ragdoll`: joints become limited ball sockets, the body settles, then is anchored where it lies; carrying unfreezes it.
- **Gripped bodies stay and are clues** (owner: "Yes, gripped bandit bodies should stay 120 seconds like takedown bodies, so they're easy to spot." and "Gripped bodies can be used as clues too."): a gripped enemy's body stays 120 s (was 4 s), and every gripped NPC's body (townsfolk too, which keep their 60 s) is registered so enemies can find it like an assassinated one.
- **Elites and bosses:** an Elite or a Hunter (perception class Chunk; the "Bandit Duelist" is an Elite) only takes a **backstab** (hold N): 45% of its max health through the normal hit path (the Hit sound, Alert on you), then a 1.2 s stun; no knockout. Bosses, trial foes, the sparring partner and anything perception doesn't track are **immune** (no prompt; refused). A rig's `TakedownClass` attribute overrides (the hook for Nemesis rivals). Townsfolk are refused.
- **Cooldown:** 4 s after any takedown (finished or interrupted), 0.5 s after a refused request, per player, on the server; the prompt waits for it.
- **Interrupts:** you're stunned or knocked, either of you dies or vanishes, the victim is knocked or gripped by something else, you end up 6 studs apart, or you're moved more than 1 stud off where the hold put you (final fix round): both are released, the enemy turns Alert on you, and the cooldown applies. The victim takes no damage from anyone during a takedown; you can be hit.
- **The prompt** (`UI.TakedownUI`, client only): rebuilt for each new target, hidden in Combat Mode, while swimming, on cooldown, in dialogue, in a cutscene and while a menu is open. A tap that ends without the hold sends a knockout 0.1 s later (Roblox fires the hold's end before its trigger).
- **Touch:** the prompt is the control: tap it to knock out, hold it to assassinate. No new button.
- **Two fixes the feature needed:** only a prompt on **E** stops E from drawing your weapon (A8); **N is reserved** in Settings, like B and V, so no rebind takes it.
- **Anti-exploit:** the client decides nothing; the player is held (root anchored) for the whole takedown (final fix round). Malformed requests are refused quietly; the victim is marked in the same step as the last check (one takedown per target); every heartbeat re-checks the interrupts; a player who leaves is released and forgotten; `LastTakedownResult` records each outcome.
- **PvE only:** no NPC has a takedown and no path accepts a player as the victim. PvP is unchanged (Grip on a knocked player works as before, now with the ragdoll).
- **Hooks for later:** `TakedownService.Done` / `.Failed`, `PerceptionService.BodyFound`, `Takedown.IsHidden` (false until hiding spots), `TakedownClass`, `Deeds.Finishers[Type].Assassinate`.
- **Animations** (`Assets.Animations.Shared.Takedown`, `Art/Studio/Takedown/anim_slots.lua`, reversible): `Misc_Assassinate` 83505608395055 (moved from `Registry`), `Misc_AssassinateVictim` 132728216355683, `Takedown_Choke` 72960497872371 ("Knock out"), `Takedown_ChokeVictim` 131914091661838 ("Hold"). All four load (Task 1); the Bear Hug pair is a fallback only. See `Animations.md`, "Takedowns".

**The owner's rules kept:** PvE only (the server's first check, a test, and the client never offers it on a player); only existing UI assets (PromptUI draws the prompt; no new image, font, sound or ScreenGui); no invented asset id (every id is the owner's, from the sheet or chat).

**Decisions taken without the owner** (each a PROPOSAL):
- **From the spec (§16):**
  1. two kinds on one key: tap N knocks out, hold N (0.6 s) assassinates;
  2. key N, reserved like B and V (not rebindable yet);
  3. the gates: rear 140° arc, 4 studs (3 up or down), clear line, not Alert and not fully aware of you, from Calm only, crouch not required;
  4. Suspicious and Cautious enemies can be taken down; Alert ones can't;
  5. timings: knock out 2.0 s, assassinate 1.0 s, knocked out 300 s, cooldown 4 s;
  6. sounds: Choke 6, Takedown 4; the kill skips the 20-stud Hit;
  7. witnesses: one quick look at the start; enemies who see it go Alert; townsfolk remember (and now flee, §18.2);
  8. bodies stay 120 s; enemies find them by sight, faster in light; a found body starts a search there; townsfolk don't look for bodies (dead bodies became carryable, §18.1);
  9. waking up raises the alarm as a search at that spot; hiding spots come with stealth missions;
  10. assassinating a bandit is `assassinated_bandit` (Mercy −1, cap 10 a day); knocking out a hostile mob is no deed;
  11. Elites: a 45% backstab and a 1.2 s stun, no knockout; bosses and trial foes immune;
  12. townsfolk can't be taken down;
  13. the victim can't be damaged during a takedown; the player can;
  14. the Bear Hug pair is now only the fallback (the owner's Knock out / Hold ids are in);
  15. the prompt shows the enemy's state word;
  16. no drop takedowns (no animation; the cone can't judge "above", A9);
  17. only E prompts stop E from drawing.
- **The controller's rulings during the plan:**
  - the victim is placed 2.0 studs in front of the player (the animations carry no root offset, and 1.6 overlapped);
  - the kill is timed on the server clock (LethalTime × the Snap's share, about 0.6 s), since the player's animation plays on the client;
  - the victim's animation ("HammerChoking", 4.717 s) is cut at the Snap, then the body ragdolls;
  - a body's "found" meter never drains: glances add up over the body's life;
  - a body under water is seen at ×0.3, like a diver;
  - `assassinated_guard`: Crime 60 (as `murder_townsfolk`), cap 10;
  - Heat when a guard's body is found (overrides spec §7.5's "no new Heat code", per §18.3): **a found gripped or backstab-killed law-faction (guard) body raises law Heat like an assassinated guard**, once, unless the kill's own deed already heated through a witness; an assassinated guard past the daily cap heats when found;
  - **townsfolk bodies are excluded there** (TownsfolkService owns murder Heat, so it would count twice);
  - **townsfolk corpses keep 60 s** (`TownsfolkService.BodySeconds`);
  - **a killing backstab leaves a 120 s, findable body** like a grip; today every enemy except the sparring dummy is knockable, so a backstab that would kill knocks instead;
  - **TapGrace 0.1 s** (a tap's knockout waits for the hold's trigger that never comes);
  - **the prompt hides while a menu is open** (Inventory, Stats, Settings, Mastery, Journal, Minigame, Admin);
  - the ragdoll's numbers (joint limits, settle after 4 s, still below 0.6 studs/s and 1.5 rad/s, friction 1.5); weapon and accessory joints stay rigid;
  - the knock grace pins a knocked player to the knock point, with a 110 studs/s momentum allowance (the dash's peak);
  - a carried corpse can't be delivered as a prisoner (only a living knocked target);
  - `Play_Stealth` and the other Ye-only suites stay Ye-only.

**Owner questions:**
- ~~Is "HammerChoking" (132728216355683, 4.717 s, the victim animation cut at the Snap) the intended Assassination Victim?~~ Answered 2026-10-28, owner: "Yes I like that animation". It stays.
- Spec §16, open question 2: should the takedown key be rebindable?

**Tests** (hooked Play, one session at a time; the owner's save dump and deed probe were equal before and after every session except the incident below). RED first in every task; final GREEN counts:
- **Task 1** (parity and survey): `sync.py --check` Ye 100 / Foundry 99 SAME; `test_sync.py` 1188/0; all six ids load (Assassinate 1.133 s with the "Snap" keyframe at 0.683 s; Knock out 1.25 s; Hold a one-keyframe loop; Victim 4.717 s); N is free; A15 confirmed.
- **Task 2** (`Rensei.Takedown`): `Test_Takedown` 0/11 → 11/0 (Ye Play, Foundry Edit); Test_Perception 5/0, Test_Heat 6/0; test_sync 1208/0.
- **Task 3** (the slots): `anim_slots.lua` check 10/9 → 32/0 in Ye and Foundry; `test` mode round trip equal; `AnimationManager.Has` true for all six on the client.
- **Task 4** (perception skip, Glimpse, Raise, sounds): `Play_Takedown` 0/8 (0/9 split) → 9/0 ×2; Test_Sound 9/1 → 10/0; Test_Perception 5/0, Play_Perception 6/0, Play_Stealth 9/0 ×3, Play_Guns 25/0, Play_LindenmoorSmoke 10/0; test_sync 1268/0.
- **Task 5** (bodies): `Play_Takedown` 9/7 → 16/0 ×2; Play_Stealth 9/0 ×3, Play_Perception 6/0, Test_Perception 5/0, LindenmoorSmoke 10/0 ×2. Measured: a body at 10 studs is found in 1.4 s at noon; at midnight the meter is 0.63 after three times that.
- **Task 6** (knock length, deeds, dead-body carry): Test_Takedown 11/1 → 12/0; Play_Takedown 16/5 → 21/0 (Ye ×2, Foundry); `Play_Downed` 11/1 → 12/0 (Ye ×2, Foundry, Tutorial); Play_Morality 3/0, Play_TownsfolkHurt 11/0, Play_NoGrip 6/0.
- **Task 6b** (gripped bodies ragdoll): Play_Takedown 20/5 → 25/0 (Ye ×2, Foundry); ragdoll client check 0/2 → 2/0 (Ye, Foundry); Play_Downed 12/0 (Ye, Foundry, Tutorial); Tutorial grip-ragdoll 1/0; Stealth 9/0, LindenmoorSmoke 10/0, TownsfolkHurt 11/0, Morality 3/0, NoGrip 6/0; test_sync 1278/0.
- **Task 7** (the server takedown, assassinate): Test_Takedown 12/1 → 13/0; Play_Takedown 26/27 → 53/0 (Ye ×5; Foundry 53/0 in 5 of 8 runs, the misses being a doubled run and two ragdoll-height flakes); Play_Downed 12/0 (Ye, Foundry, Tutorial); Stealth 9/0, Morality 3/0, Heat 8/0, TownsfolkHurt 11/0, LindenmoorSmoke 10/0, NoGrip 6/0; test_sync 1298/0.
- **Task 8** (knock out, waking up, gripped-guard Heat): Play_Takedown 54/11 → 66/0; fix round: `Play_TakedownHard` 6/2 → 8/0 ×2 and Play_Takedown 60/0 ×2 in Ye and Foundry; Test_Takedown 13/0, Downed 12/0, Stealth 9/0, Morality 3/0, LindenmoorSmoke 10/0, Heat 8/0, TownsfolkHurt 11/0; test_sync 1308/0.
- **Task 9** (Elites, bosses, townsfolk, hooks): Play_Takedown 64/3 → 67/0 (Ye ×2, Foundry); fix round: `Play_TakedownClasses` 8/1 → 9/0 ×2 in Ye and Foundry, Play_Takedown 60/0 ×2 and Hard 8/0 in both; Play_Townsfolk 18/0, TownsfolkHurt 11/0 (fresh session), Heat 8/0; test_sync 1328/0.
- **Task 10** (the prompt, the E fix, N reserved): takedown client checks 0/8 → 8/0 (Ye; Foundry ×2), including a real E press with the prompt showing; Foundry gun client checks 21/0 and swim 9/0; test_sync 1318/0 on the staged index.
- **Task 11** (the full sweep, plus the prompt-per-target and menu fixes): client checks 1/2 → **10/0** in Ye and Foundry; `sync.py --check` Ye 114 / Foundry 113 SAME; `anim_slots.lua` check 32/0 in both; test_sync 1328/0.
  - **Ye:** Test_Takedown 13/0, Test_Sound 10/0, Test_Perception 5/0, Play_Takedown 60/0, Hard 8/0, Classes 9/0, Stealth 9/0, Perception 6/0, Morality 3/0, Rumours 3/0, LindenmoorSmoke 10/0, Downed 12/0, TownsfolkHurt 11/0, Heat 8/0 (the first Play_Takedown run, 55/5, was the runner overlapping two suites; rerun alone, clean); gun suites Guns 25/0, GunAim 21/0, GunBalance 8/0, GunKit 3/0, GunNpc 4/0, GunReload 11/0, Assault 1/0; swim Test_SwimLogic 13/0, Play_Swim 9/0; swim client 9/0.
  - **Foundry:** Boot 2/0, Test_Takedown 13/0, Play_Takedown 59/1 twice (a different single case each run), then **60/0 three times** in a clean session (Foundry:assn11r), Hard 8/0, Classes 9/0, FoundrySmoke 15/0 (third run), Downed 12/0, Test_Sound 10/0, Test_Perception 5/0.
  - **Real input (Ye):** walked from spawn to the bandit camp, crept up behind an unaware Grunt and held N: "Assassinate:ok", the body ragdolled, "Assassinated a bandit", the bounty counted it, and its partner 15 studs away stayed unaware.
- **Known flakes and machine-load failures, not regressions** (this plan changed no gun or swim code; up to five Studio windows were open, Ye's client at 15 fps, Foundry's at 8 fps with a 28 Hz server): gun client `KickRespectsCameraShake` (fails below about 20 fps; passes at 54) and `LockOnMarkerOnTarget` (frame-bound, passed on rerun); Foundry swim `SteersDown` at 8 fps (passed 9/0 at 54 fps in Task 10); the ragdoll-height flake (GripRagdolls, RagdollSettles, RagdollBodyIsFound, AssassinatedBodyIsFound under server hitches); Foundry `Play_Takedown` failing a single, different case per run (once `AssassinateSuspicious` "ended", a new signature); `Play_Downed.KnockGraceSnapsBack` and `Play_GunReload.StunCancelsAndRestarts` once each; `Play_TownsfolkCrowd.Performance` over 1.5 ms with the old code too; and the known order effects (TownsfolkHurt.Gossip after Heat, Play_Perception after Stealth, Play_Rumours R2 after Morality).

- **Final fix round** (after the final whole-branch review, "With fixes", no Critical; RED first; `final-fix-brief.md`):
  - **F1, the player is held for real:** the player's root is anchored for the takedown (its anchoring given back on every end), and a takedown ends interrupted when the player's root is more than 1 stud (PROPOSAL) from where the hold put it. Before, the walk lock was only advisory: the client owns its character, so a sprint, or letting go of crouch, dragged the welded victim mid-choke (and an exploiter could move the pair anywhere). The choke animation still plays with the root anchored (checked on the client in Play), so the anchor was kept rather than re-welding with the victim as holder.
  - **F2:** Grip (B) and Carry (V) refuse a player who is taking someone down (`DownedManager`), and the client doesn't send them.
  - **F3:** the start and the whole run loop are in pcalls; any error releases everything as `"<Kind>:error"` (no alarm). An error at the start used to be released as an interrupt, with the alarm. A takedown slower than 1.5 s (the knockout: 2.5 s, PROPOSAL) warns its phase timings on the server.
  - **F4:** a victim killed by something else mid-takedown loses `TakenDownBy`, so it is no carryable takedown body.
  - **F5:** a player still crouching when a takedown ends keeps crouch speed (6) and no jump until they stand up.
  - **F6:** a rig that is itself gripping or carrying someone is refused ("target_busy").
  - **F7:** a character gone mid-takedown, or a gripper removed mid-grip, leaves no walk-lock entry behind.
  - **F8 (tests only):** `TakedownKit.Guard` refuses to run a case unless the test hook's save snapshot is armed. The Studio-only no-save switch has its own entry above.
  - **Counts:** `Play_TakedownHard` 8/10 → **18/0** (Ye ×2, Foundry); `Play_Takedown` 58/2 → **60/0** (Ye, Foundry; `AssassinateFromBehind` now expects the crouch speed; the other RED miss was `WitnessAlerts` "ended", the known load flake); Ye Classes 9/0, Stealth 9/0, Heat 8/0 (last); Play_Downed 12/0 twice in a fresh Ye session (11/1, then 10/2, after Stealth and Heat in the first session: `KnockGraceSnapsBack`, a known flake, and `DeepWaterStill`), Foundry 12/0. Every pair this round touched is SAME in both places; test_sync 1338/0. The Tutorial got the new DownedManager (its copy matched Ye's). The save dumps were equal in every session.

**Incident (Task 8, owner informed):** during one Ye Play session the Studio window was stopped and closed from outside, so the test hook's restore never ran and the owner's slot 2 save kept that session's test state (test EXP, money, deeds, Heat and rumours). Nothing was written to fix it. The owner chose "Leave my save as it is for now"; the pre-session dump is kept in the session's scratch folder. Every later session restored and compared the save as before.

**Not tested:**
- a real phone (touch tap and hold on the prompt);
- **the final fix round's hold with real keys:** crouch behind an enemy, tap N, then let go of Ctrl or press Shift mid-choke (you should stay put); covered on the server only;
- **the tap-N knockout and V carry with real keys** (the Task 11 walk-through reached only the assassinate: the partner went Alert in run 1, and the input tool's crouch slid on the slope in run 2); both are covered by the Play and client checks;
- the gamepad: the prompt uses ProximityPrompt's default ButtonX, which talk prompts share;
- **no touch carry button out of Combat Mode** (on touch V is the alchemy button, so carrying a body there needs Combat Mode);
- a player gripped by a player still dying and respawning normally (never done to the owner's character);
- two real players taking down the same enemy (simulated in `OneTakedownPerTarget`);
- a live server.

**Backups and rollback:**
- **Backups:** `ServerStorage.RenseiBackups["Pre-Assassinations_2026-10-25"]` in Ye and Foundry Yard (and the Tutorial, for DownedManager). Each script is cloned once, before this plan's first change. Created scripts have no backup.
- **The rollback order** (Edit, both places):
  1. Revert from that backup, for this plan's labels: Rensei.Perception, Rensei.Deeds, Rensei.Settings, Managers.DownedManager, UI.CombatModeUI, SPScripts.UIHandler, SPScripts.ClientHandler, PerceptionService, EnemyService, ServerHandler, MoralityService, TownsfolkService, Test_Sound, SmokeKit, Play_Downed, and in Ye Play_Stealth and Play_TownsfolkHurt. In the Tutorial, DownedManager.
  2. Delete the scripts this plan created: `Rensei.Takedown`, `Managers.Ragdoll` (Tutorial too), `UI.TakedownUI`, `TakedownService`, `Requests.Takedown`, and the tests `TakedownKit`, `Test_Takedown`, `Play_Takedown`, `Play_TakedownHard`, `Play_TakedownClasses`.
  3. Run `Art/Studio/Takedown/anim_slots.lua` with MODE "undo" (it moves `Misc_Assassinate` back to `Registry.Misc` and refuses if a slot's id was changed).
- To undo only the final fix round: `RenseiBackups["Pre-AssassinationsFinal_2026-10-27"]` (TakedownService, DownedManager, ClientHandler, TakedownKit, Play_Takedown, Play_TakedownHard; the Tutorial: DownedManager).
- Never use the downed side task's or older backup folders for these scripts: they predate later work.

**For the owner: the publish checkpoint.** This plan publishes nothing. It follows `Documents/World Travel.md` §10, and may be published only together with whatever hold is then in force. The downed crawl side task's own entry below lists what it adds to the same packages.
1. **Save** Ye and Foundry Yard in Studio.
2. **Publish the packages from Ye:**
   - **Modules:** `Rensei.Takedown` (new), `Rensei.Perception`, `Rensei.Deeds`, `Rensei.Settings` (N reserved), `Rensei.TuningConfig` (the side task's Downed keys), `Managers.DownedManager`, `Managers.Ragdoll` (new), `UI.TakedownUI` (new), `UI.CombatModeUI`;
   - **RenseiServer:** `TakedownService` (new), `ServerHandler`, `ServerHandler.Requests.Takedown` (new), `PerceptionService`, `EnemyService`, `MoralityService`, `TownsfolkService` (plus the side task's StationService, RoadService, TravelService and AdminService);
   - **Assets:** `Animations.Shared.Takedown`. Note: Task 1 found Ye's Assets at package version 5 and Foundry's at 4 (the same contents).
3. **Update Foundry Yard's packages by hand** (Modules, RenseiServer, Assets), then check with `sync.py --check` (expect Ye 114 / 0 / 0, Foundry 113 / 0 / 0) and `anim_slots.lua` MODE "check" (32/0).
4. **Publish the places** Ye and Foundry Yard. `StarterPlayerScripts.UIHandler` (starts TakedownUI) and `ClientHandler` (the ragdoll watch) are place scripts in both, and go out with them, like the new test suites.
5. **Last: Migrate to Latest Update** for both places.
- **The Tutorial:** its Modules is **not** a package, so no package publish reaches it, and it needs nothing else from this plan. Its DownedManager and Ragdoll were set directly (Tasks 6, 6b, 7 and the final fix round) and go out with the Tutorial's own place save.

### Discord announcement

Hold: not live yet. Post this when the owner publishes the assassinations update.

```md
**Update: Assassinations**

**Sneak up, take them down**
- Creep up behind an enemy who hasn't spotted you, out of Combat Mode, and a prompt appears over them.
- **Tap N** to choke them out. **Hold N** to take them out for good. On touch, tap or hold the prompt.
- It only works from behind, before they're on to you. The prompt shows whether they're unaware, suspicious or cautious.
- Crouching isn't required, but it keeps you quiet and harder to see on the way in.
- A stun or a knockdown breaks it, and your target turns on you.

**Bodies**
- Knocked-out enemies wake up after a few minutes and raise the alarm.
- Bodies now go limp and stay where they fall for a while, so they're easier to spot. That goes for anyone finished with a grip too.
- Enemies who spot a body or a knocked-out friend search the area and call others over. Bodies in the dark take much longer to notice.
- Press V to pick up a knocked-out enemy or a body and carry it out of sight. Stand up first: you can't carry while crouched.

**Witnesses**
- Enemies who see you do it come straight for you.
- Townsfolk who see it run, and word gets around.
- Assassinating a bandit weighs on your Mercy, like finishing one off.

**Tougher targets**
- Duelists only take a heavy backstab, and then it's a fight.
- Bosses can't be taken down.
- Only enemies can be taken down. Never other players, and never townsfolk.
```

## 2026-10-27 — Downed crawl, Downed Idle, Carry and Carried animations (not live)

**Owner:** "Here's the downed idle and downed crawl anim IDs: 140397797689506, 140556271258345", "Yes, slow crawl", and the Carry (70888533900445) / Carried (124248460861263) ids; then "Throw those anims in all places we've worked on so far and make sure everything is synced up". Side task before the assassinations' DownedManager tasks (brief: `.superpowers/sdd/2026-10-25-assassinations/downed-crawl-brief.md`; report: `downed-crawl-report.md` there). Studio Edit sessions of **Ye**, **Foundry Yard** and the **Tutorial**; nothing saved or published. Every number is a **PROPOSAL**.

**Animations** (all four load in Play in the three places: Downed Idle 4.17 s, Downed Crawl 0.93 s, Carry 0.5 s, Carried 0.5 s):
- `Knocked` now plays **Downed Idle**; the questionable Greatsword grip-victim stand-in is kept as `PreviousSheetId`.
- New slot `DownedCrawl` (**Downed Crawl**); `Carrying` = **Carry**, `Carried` = **Carried** (were unpublished Studio saves).
- Tool: `Art/Studio/Downed/downed_slots.lua`. The Main Menu has no `Assets.Animations`, so it needed nothing.

**The crawl** (players only):
- `DownedManager`: a knocked player's WalkSpeed is `Downed.CrawlSpeed` (3) instead of 0 (`KnockedSpeed`, `CanCrawl`, `SetKnockedSpeed`; a watch keeps it while the knock lasts). Enemies, townsfolk, a gripped or carried body and a body in deep water stay at 0. JumpHeight stays 0 and everything else a knock blocks stays blocked.
- `MoverManager`: a movement change that ends mid-knock hands back the knocked speed (it set 0 before).
- `AnimationManager` (client): Downed Idle when still, Downed Crawl when moving, crossfaded by weight (no flicker on a tap); gripped or carried, the crawl stops at once.
- **Fixed (an old hole the crawl made visible):** letting go of crouch while knocked set the client back to full walk speed and jump, so a knocked player could walk off at 16. `ClientHandler.Crouch` now leaves a knocked player at the knocked speed with no jump.
- Road thresholds and the train refuse a knocked player (checked: RoadService's `Unfit`, StationService's `Held` at boarding and departure).
- **Carry pose:** the owner's Carried animation buried the carrier's head in the body on the old root-to-root weld, so a carry's weld now puts the body over the left shoulder (`Downed.CarryOffset`). Grips are unchanged.

**Tests:** new `Play_Downed` (7: crawl speed, enemy still, carried, gripped, recover, deep water, travel refused): 7/0 in Ye, Foundry Yard and the Tutorial (temporary test folder there, removed after). Real input (hold W, sampled every frame): 3 studs/s, crossfades with no flicker, grip stops the crawl at once, recover restores 16.29 on both server and client. Regressions in Ye: Play_Boot 2/0, Play_Road 11/0, Play_Stealth 9/0, Play_Perception 6/0, Play_Swim 9/0, Play_Guns 25/0, Play_TownsfolkHurt 11/0 (10/1 once: a grip timing flake, 11/0 on rerun), Play_Station 19/1 (DeathAboardDropsYouFromTheRide's respawn timing check; it fails the same way in Foundry Yard with the old code, and passed 20/0 in Foundry Yard after the sync). Foundry Yard: Play_Downed 7/0, Boot 2/0, Station 20/0, Road 11/0, Swim 9/0, FoundrySmoke 15/0. Save dumps equal in every session.

**Sync:** `sync.py` covers the new pairs (DownedManager, MoverManager, ClientHandler.Crouch, Play_Downed): Ye 92/0/0, Foundry Yard 95/0/0. The Tutorial (no Modules package) got the same DownedManager, MoverManager and AnimationManager, the Downed section of TuningConfig, the crouch guard and the slots. FlowTeleport, Places, DownedManager, AnimationManager, MoverManager, the Downed tuning and the downed / grip slots hash equal across every place that has them (the Menu has only FlowTeleport and Places, both equal).

**Fix round 1 (review minors, same day):** the server clamps a knocked player's crawl distance (a 10-stud jump in one tick is put back; a real crawl isn't touched); attribute `KnockedStill` makes the client's `KnockedSpeed` read 0 in deep water, gripped or carried; repo copies of the Tutorial's TuningConfig and Crouch (`Scripts/Tutorial/...`) and the live Crouch in `Art/Studio/Movement`. Play_Downed 8/0 in Ye, Foundry Yard and the Tutorial; Ye Play_Boot 2/0, Play_Road 11/0; real input: no clamp on a 3 s crawl.

**Fix round 2 (re-review, same day):** the clamp puts a body back at its full last position (no more old x / z with a new height), its slack is per second (7 studs/s in all, over at most 1 s), and it leaves alone a grounded or welded assembly, a seat, PlatformStand and the 0.5 s after a rebase. Every deliberate server move of a player calls `RebaseCrawl`: StationService (gate and car-door pushes, platform, ride watchdog, departure), RoadService (arrival spread), TravelService (arrival), AdminService (bring, goto, teleport); these four services are now sync pairs. Play_Downed 10/0 in Ye (x2), Foundry Yard and the Tutorial; Ye Play_Station 20/0, Play_Road 11/0, Play_Boot 2/0. **RenseiServer** (StationService, RoadService, TravelService, AdminService) now also needs publishing.

**Fix round 3 (re-review):** a rebase now pins the clamp to the server's own spot right after the move (it followed the client for 0.5 s, so a rebase could be ridden anywhere); a snap inside that grace (the client's stale echo) isn't counted. Rebases are kept for knocked players only, and a re-knock's old watch no longer clears the new knock's state. Play_Downed 11/0 in Ye, Foundry Yard and the Tutorial; Ye Play_Station 20/0, Play_Road 11/0.

**Packages to publish:** Modules (93881868321364: DownedManager, MoverManager, AnimationManager, TuningConfig) and Assets (91921092226558: the four slots); RenseiServer needs publishing too since fix round 2 (StationService, RoadService, TravelService, AdminService: the `Rebased` calls; the `RenseiTests` suite is not in a package). StarterPlayerScripts (Crouch) is saved with each place. The Tutorial is saved with its place.

### Discord announcement

Hold: not live yet. Post this when the owner publishes the update.

```md
**Update: Knocked Down, Not Out**

- When you're knocked down you can now **crawl slowly** to safer ground. You still can't fight, jump, sprint or use alchemy until you get up.
- New animations for lying knocked down and for crawling.
- **Carrying** someone now has proper animations: they're slung over your left shoulder.
- Being gripped or picked up stops your crawl, and you can't crawl through deep water.
- Fixed: letting go of crouch while knocked down no longer lets you walk away at full speed.
```

## 2026-10-27 — Backlog order: the main game quest system after stealth missions

**Owner:** "I published them. After assassinations and hostages, and stealth missions, let's start the main game quest system w/ the lore, etc."
- The swimming revamp is **live**.
- **New Backlog order:**
  1. assassinations;
  2. hostages;
  3. stealth missions;
  3b. **bring the Tutorial completely up to date** (owner, 2026-10-27, after stealth missions);
  4. **the main game quest system with the lore** (starting from the main story concept draft, which the owner approves first);
     - **Owner direction for it (2026-10-27):** a clear first step on spawning in; keep the roguelike feel; use the cinematics; and gate later chapters behind level, Gate stage and other milestones, so players explore, do side quests and stealth missions, solve investigations and learn alchemy. It's in the main story concept.
  5. consequences for wrong guesses;
  6. the Nemesis system;
  7. reputation in investigations.

## 2026-10-27 — Swimming revamp: directional swimming and diving (live: owner published 2026-10-27)

The swimming revamp plan (`Documents/plans/2026-10-25-swimming-revamp.md`, run 2026-10-26 / 27; spec `Documents/specs/2026-10-25-swimming-revamp-design.md`) answers the owner's request: "Completely audit and revamp the swimming system. (I want it to be directional, with a dive system)". All of it is in the Studio Edit sessions of **Ye** (106992859583940) and **Foundry Yard** (109591196441030), the same in both. **Nothing is saved or published by this plan.** This is the plan's only Changelog entry.

Every number is a **PROPOSAL** unless the owner chose it or it was measured. The owner's answers of 2026-10-25 are built in: climbing out uses the ledge climb (Vault1 / Vault2), the underwater idle is Swim_Idle, Swim_Dive and Swim_Surface start as placeholders.

**What was wrong** (the spec's audit, findings A1–A18):
- **Not directional:** Roblox's own swimming moved you along the camera; nothing turned or pitched the body, and looking down at the water dragged you under (A1, A2, A4).
- **No dive system:** no dive key, no underwater state, buoyancy fought any dive, and Ye's pools are only 5.2 deep (A3, A5, A6).
- **The breath bar** was a code-built bar in the wrong font (A7), and breath only counted in the swim state, so a carrier could walk a pond's bed forever (A8).
- **No way out at a wall** (A9), no entry or surfacing feedback (A10).
- **Stealth:** the water's surface blocked every sight ray, so a diver was invisible even next to an NPC (A11, confirmed by the RED: awareness under water 0, dry 0.12); swimming made no sound after the splash (A12).
- Shift lock and knockbacks would undo any swim facing or mover (A13, A14); touch players couldn't dive (A15); the server never checked swim speed (A16); the docs disagreed on the swim ids (A17); there were no swim tests (A18).

**What changed:**
- **Directional swimming** (`Modules.Managers.SwimController`, maths in `Rensei.SwimLogic`): at the surface you swim level, relative to the camera's yaw, with your head held at the surface and the body upright; underwater (after a dive) W follows the camera's full look (pitch clamped to 80°), A / D strafe level, the body turns and pitches into the swim, and with no input you drift up at 1.5 studs/s. The controller's `LinearVelocity` and `AlignOrientation`s sit on the root's own attachments, let go while you're stunned, dashing or knocked back, and keep the humanoid's own jump off while it swims.
- **Diving:** Ctrl at the surface dives where the water is at least 4.5 deep (Foundry's pond and Ye's pools, not the 4.2-deep creeks); hold Ctrl to sink, Space to rise; Shift sprints underwater (air x1.5). Surfacing plays Swim_Surface; diving plays Swim_Dive.
- **Climbing out:** Space at the surface, facing a ledge up to 4.5 above the water within 3, climbs out with the ledge climb; otherwise it's the old hop.
- **The air meter:** a run-time clone of the HUD's own Meter bar (`AirBar`, labelled AIR, DROWNING and blinking at 0), under the vitals while you're under water or short of air. The code-built `SwimHUD` is gone.
- **The server** (`SwimService`): `Submerged` follows the head; breath counts whenever your head is under water (the carrier exploit closed); `WaterDepthAt`; a speed check that stops a too-fast sprint and warns, never moving anyone. Drowning, the sprint's stamina and owner decision 6 (no combat or alchemy in water) are unchanged.
- **Stealth and noise:** sight rays ignore water; a diver is seen at x0.3; surfacing (6) and sprint strokes at the surface (8, every 0.8 s) make noise; swimming underwater is silent.
- **Touch:** a DIVE button in Slide's spot (tap at the surface to dive, hold underwater to sink), beside SPRINT and RISE.
- **Animations:** `Swim_Dive` and `Swim_Surface` placeholder slots in `Shared.Movement.Swim` (`Art/Studio/Swim/anim_slots.lua`, reversible).

**Decisions taken without the owner** (each is in `Decisions.md`, "Swimming revamp"):
1. A client swim controller replaces Roblox's swim steering; the server keeps every rule.
2. Surface swimming is level; only a dive takes you under.
3. Ctrl dives on the press (the plan said a short tap), holds to sink; Space rises; touch DIVE.
4. Underwater: camera-relative 3D, level strafing, a slow drift up.
5. The new numbers (UnderSpeedMult 0.85, Ascend / Descend 10, Dive 16 for 0.35 s, DiveMinDepth 4.5, SurfaceBand 0.6, MaxPitch 80°, ClimbOut 4.5 / 3, sprint breath x1.5; RootBelowSurface 1.4 and HeadOffset 1.5 measured).
6. Breath counts whenever the head is under water.
7. The low-ledge climb-out.
8. Water no longer blocks sight; a diver is seen at x0.3; the Surface and Stroke noises.
9. Enemies don't dive.
10. The speed check only logs and stops the sprint.
11. **The Ye plunge hole is skipped** (the controller's ruling, 2026-10-27; the owner can reverse it): the Gorge Pool's floor is `Map.Ground.Tops` parts at y 0, not the Baseplate, with a flat area of only about 12 x 4. Foundry's 9-deep pond is the deep dive. **Options for the owner:** (a) a small 12 x 4 hole in the Gorge Pool; (b) a bigger change that also cuts the `Ground.Tops` parts; (c) a hole in the Mill Pond, whose flat floor is larger.
12. Two placeholder animation slots.
13. The air meter is a clone of the HUD's Meter bar.
14. SwimClient keeps its name; the movement is the new SwimController.

**Faults the real-input runs found and fixed** (Task 9, keyboard input in Play):
- Walking into Ye's Mill Pond looking down still dived: Roblox's Swimming state pitched the body, the head sank, and that counted as "sunk". Now the body is kept upright at the surface.
- The forward stroke lowered the head under the surface, so surface swimming drained air. The surface hold now keeps the head up.
- In Foundry's 9-deep pond, `Submerged` switched off near the bed (a cell part slab, part water above it). The head check now also reads the cell above.
- Holding Space at the surface let Roblox's swim-jump lift you out of the water. The humanoid's jump is off while the controller swims.
- The climb-out's wall ray at the waterline passed under Foundry's slab banks. It now tries several heights.

**Tests** (both places; every Play session hooked, restored and unhooked, save dumps equal):
- `Test_SwimLogic` (13 pure cases): RED (the module missing) → 13/0 in Ye and Foundry.
- `Play_Swim` (9 server cases: depth at the dive sites, Submerged follows the head, Submerged near the bed, a carrier's breath drains, drowning hurts a test rig, no sprint on land, speed strikes, a diver is hard to see, surfacing makes noise): RED → 9/0 in Ye and Foundry.
- `Art/Studio/Swim/client_checks.lua` (9 client checks: the placeholder slots load, level at the surface, the dive goes under, steering down (Foundry: the root fell 5.46), rising to the surface, no dive in the 4.2-deep creek (Ye), shift lock yields underwater, the air meter is the HUD's bar, the DIVE button): RED 0/7 and 0/2 → 9/0 in Ye and Foundry.
- `Test_Sound` 9/0 and `Test_Perception` 5/0 (new: SwimSounds, SubmergedSight).
- **Real input, Ye (Mill Pond):** walked in looking down and stayed at the surface (head 5.26–5.31 over a 5.19 surface), Ctrl dived, Shift sprinted underwater, Space surfaced. **Foundry (cooling pond):** walked in, dived to the head 8.5 studs under, sprinted, surfaced, stayed level with Space held, and climbed out onto the west bank; under for about 3.6 s, air 15 → 11.2.
- **Regression:** Ye `Play_LindenmoorSmoke` 10/0, `Play_Stealth` 9/0, `Play_Perception` 6/0 (once 4/2 straight after the smoke and stealth suites, then 6/0 three times in a fresh session), `Play_Station` 20/0; Foundry `Play_FoundrySmoke` 15/0, `Play_Boot` 2/0, `Play_Station` 20/0. `sync.py --check`: Ye 88/0/0, Foundry 91/0/0. `test_sync.py` 1068/0.

**Not tested:** two real players watching each other dive; a real phone (DIVE was tested with `ForceMobileControls`); a live server.

**Backups and rollback:**
- **Backups:** `ServerStorage.RenseiBackups["Pre-SwimRevamp_2026-10-25"]` in both places (12 scripts in Ye, 8 in Foundry Yard). Foundry has no backups of SwimService, PerceptionService and NoiseService because the RenseiServer package (v17) already held this plan's versions when Foundry was synced. The SwimController, SwimKit and Play_Swim backups are in-plan copies (those scripts are new).
- **The rollback order** (Edit, both places):
  1. Revert TuningConfig, Perception, MobileControls, SwimClient, SwimService, PerceptionService, NoiseService, Test_Perception and Test_Sound (Ye) from that backup.
  2. Delete the scripts this plan created: `Rensei.SwimLogic`, `Managers.SwimController`, `RenseiTests.Test_SwimLogic`, `SwimKit`, `Play_Swim` (and Foundry's new `Test_Perception` / `Test_Sound`).
  3. Run `Art/Studio/Swim/anim_slots.lua` with MODE "undo" (it refuses to delete a slot the owner has filled with a real animation).

**For the owner: the publish checkpoint.** This plan publishes nothing. It follows `Documents/World Travel.md` §10:
1. **Save** Ye and Foundry Yard in Studio.
2. **Publish the packages from Ye:**
   - **Modules:** TuningConfig, SwimLogic (new), SwimController (new), MobileControls, Perception;
   - **RenseiServer:** SwimService, PerceptionService, NoiseService. **Note:** the RenseiServer v17 you published already holds an earlier, unfinished copy of these three (the Task 7 state, without the near-the-bed fix). Without the client half, a place running v17 has the new breath, stealth and noise rules but the old swimming. Publish this round of RenseiServer with the rest.
   - **Assets:** the two animation slots.
3. **Update Foundry Yard's packages by hand** (Modules, RenseiServer, Assets), then check with `sync.py --check` (Ye 88/0/0, Foundry 91/0/0) and `anim_slots.lua` MODE "check" (9/0).
4. **Publish the places:** Ye and Foundry Yard. `SwimClient` is a place script (StarterPlayerScripts), already in both, and goes out with them, like the new test suites.
5. **Last: Migrate to Latest Update** for both places.
- **Then:** upload Swim_Dive and Swim_Surface and paste their ids into the slots (`Animations.md`, "Swim (revamp)").

**Open questions** (spec §13): should some enemies dive after a player; underwater items or secrets for quests; a swim skill node (longer breath, faster strokes); gamepad buttons for dive and rise.

### Discord announcement

Hold: not live yet. Post this when the owner publishes the swimming update.

```md
**Update: Swimming Reworked**

**Swim where you look**
- At the surface you now swim level, so looking down at the water no longer drags you under.
- Underwater, you swim wherever the camera points, and your character dives and turns with you.

**Diving**
- Press Ctrl at the surface to dive (DIVE on touch). The water has to be deep enough.
- Hold Ctrl to sink and Space to rise. Shift still sprints, underwater too.
- Foundry Yard's cooling pond is deep enough for a proper dive.

**Air**
- A new air meter shows under your health while you're under water.
- Come up before it runs out, or you'll start to drown.

**Getting out**
- Press Space at the surface to climb straight out onto a low ledge or bank.

**Stealth**
- Diving is a good way to slip past people, but they can still spot you up close.
- Splashing in, surfacing and sprint-swimming can be heard.

**Still the same**
- No fighting or alchemy in the water.
```

## 2026-10-25 — Guns rework: aiming fixed, the class rebalanced, the reload animation (not live)

The gun rework plan (`Documents/plans/2026-10-25-gun-rework.md`, Tasks 1–13, run 2026-10-25; spec `Documents/specs/2026-10-25-gun-rework-design.md`) answers the owner's request: "Fix gun shoot mode aiming mechanics. (balance out the gun class completely, add a reload animation as well)". All of it is in the Studio Edit sessions of **Ye** (106992859583940) and **Foundry Yard** (109591196441030), the same in both. **Nothing is saved or published.** The owner had already published Ye, Foundry Yard and the packages (2026-10-25) before the gun code reached the packages, so this is its own publish (the checkpoint below). This is the plan's only Changelog entry.

Every number is a **PROPOSAL** unless the owner chose it or it was measured. The rules and the per-gun table are in `Documents/COMBAT_SYSTEM.md`, "Guns".

**What was wrong** (the spec's audit, §2–3):
- **A1 Parallax:** the shot left the head along the camera's look, so it landed off the crosshair: 1.5 studs low in shift lock, beside and below a lock-on target.
- **A2 The free mouse:** with shift lock off (the default) players aimed with the cursor, but the shot went to the screen's centre.
- **A3 The crosshair** was a generated "+" on the HUD, not tied to the shot (29 px off, half the top-bar inset), and not the game's own marker.
- **A4 Turn-and-shoot:** a shot aimed behind fired straight ahead, because the server hadn't seen the turn yet, and it still spent the round.
- **A5 Moving targets:** the server tested where targets are now, not where the shooter saw them.
- **A6 Eaten clicks:** one shot per press, and a press while the last shot ran was dropped.
- **A7 Enemy gunners** fired flat from head height with a perfect 0.12 s hitscan.
- **A8 Touch:** FIRE fired once per tap, and `Controls.md` didn't list AIM or FIRE.
- **B1 Fan the Hammer** scaled against the pistol whip, so each shot dealt the gun's full damage (Forge Tac 72 in all).
- **B2 Weapon Mastery** made long shots weaker (12.5% instead of 50% at max).
- **B3 A missed shot** cost an extra 0.15 s of recovery.
- **B4 Shots built alchemy meter** as fast as melee, from safety.
- **B5 Every shot flinched,** at any range, so a fast gun could keep cancelling windups from 90 studs.
- **B6 Forge Tac** beat the Revolver at everything.
- **B7 Shooting mode survived water.**

**What changed:**
- **Aiming:**
  - **The aim camera:** in shooting mode (not locked on) the mouse locks to the centre, the camera moves over the right shoulder and the character turns with it. Leaving the mode restores your shift-lock setting.
  - **The crosshair is the game's own marker** (`Uis.Crosshair`), and the shot goes from the muzzle to what's under it. Locked on, the shot aims at the target's centre and the crosshair sits on the target. A blocked line of fire dims it.
  - **Hold to fire** (RMB or FIRE), with a 0.2 s input buffer; the hold sends at most 4 requests a second.
  - **The server** checks every aim (70° up or down, 100° from your facing) and **refuses** a bad one: no shot, no round. A quick turn-and-shoot is held up to 0.4 s until the server sees the turn.
  - **Lag compensation:** shots are tested where targets stood (one-way ping + 0.1 s, capped at 0.25 s), timed from the click. A 20 Hz position history (`PositionHistory`, new) feeds it.
  - **Fire limits:** 5 Fire requests a second per player on the server. A snap log (`GunSnapCount`) counts suspicious turns and punishes nothing.
- **Balance** (per-gun numbers in `COMBAT_SYSTEM.md`):
  - **Revolver** (the hand cannon): Recovery 0.36 → 0.42, Reload 2.0 → 1.8, Range 90 → 70.
  - **Renetti** (quick and close): Range 90 → 60.
  - **Forge Tac** (the marksman): Damage 24 → 26, Magazine 7 → 5, Reload 2.0 → 1.8, Recovery 0.45 → 0.62, Range 90 → 110.
  - **Sykov** (the all-rounder): unchanged.
  - Each gun has its own falloff; burst ≤ 37 and sustained 20–26 for every gun.
  - **Fan the Hammer:** 12 per shot for every gun, range 40, spread 3°. A Fan the server refuses costs nothing.
  - **Mastery** strengthens bonuses only; **flinch** only within 25 studs; **2 meter** per shot hit; **no whiff penalty** on shots.
- **The reload:** the owner's animation plays at Action priority, fitted to the reload time. Reloading is still automatic; leaving shooting mode with a part-empty magazine tops it up; a stun, knock, grip, carry or water cancels it and it restarts once you're free; your own actions don't.
- **Feedback** (existing UI only): the hit marker (red hit, grey blocked), the crosshair bloom and a per-gun camera kick (off with Camera Shake, bloom only).
- **Water:** shooting mode ends when you start swimming, and can't start in water.
- **Enemy gunners:** a 0.35 s windup with the crit telegraph, 2.5° spread, aimed at your centre.
- **Touch:** holding FIRE keeps firing; a 2.5° aim assist (touch only, never townsfolk); the touch hint reads "SHOOTING MODE · hold FIRE to shoot · STOP to leave".
- **Smaller fixes found on the way:** `WeaponManager.Give` detaches an old gun before destroying it; `EnemyService.MakeCombatant` (Spawn's combat setup, unchanged) is shared with the test kit; `Requests.Aim`'s header comment.
- **Tests and kits:** `GunKit` and `Play_GunKit` (test dummies on a Play-only floor at y 2000), `SmokeKit.TempPart` / `Guarded`, the five gun suites, and `Art/Studio/Guns/client_checks.lua` for the client. Play_Stealth's Grunt cases now spawn their own Grunt instead of taking the first live one (the cause of its old flaky failures); after Task 12 moved the last of them, it passed 9/0 in all four runs.

**The owner's decisions kept:**
- No reload button: reloading stays automatic.
- M1 with a gun is the pistol whip and never fires; shooting is its own mode (Y, rebindable); RMB fires while it's on.
- Only the game's existing UI assets.
- **The reload animation is the owner's: 97563934064498** ("Reloaded", Rensei group). It loads in both places (Task 1: 4.07 s), in the slot `Assets.Animations.Weapons.Guns.Guns_Reload`.

**Decisions taken without the owner** (each a PROPOSAL; one number or switch each):
- **From the spec (§8):**
  1. the aim camera (mouse locked, over the shoulder, character turns with the camera);
  2. the crosshair is the existing `Uis.Crosshair` marker;
  3. lag compensation, shooter-favoured, capped at 0.25 s;
  4. hold to fire and a 0.2 s input buffer;
  5. per-gun ranges: Revolver 70, Renetti 60, Forge Tac 110, Sykov 90;
  6. the per-gun numbers, with burst ≤ 37 and sustained 20–26;
  7. shots flinch only within 25 studs;
  8. 2 meter per shot hit;
  9. no whiff penalty on shots;
  10. Fan the Hammer: 12 per shot for every gun, range 40, spread 3°;
  11. Weapon Mastery strengthens bonuses only;
  12. the reload top-up on leaving shooting mode;
  13. the reload interrupt rule;
  14. the magazine and reload numbers;
  15. the slot holds the owner's id;
  16. enemy gunners: 0.35 s windup with the telegraph, 2.5° spread, centre aim;
  17. no headshot multiplier;
  18. touch aim assist 2.5°, touch only, never townsfolk;
  19. recoil kicks, off with Camera Shake;
  20. the snap log punishes nothing;
  21. the server refuses an invalid aim instead of firing straight ahead;
  22. the hold loop at 4 requests a second and the server limiter at 5;
  23. a stored aim lasts 0.75 s.
- **The controller's rulings after the spec:**
  - **Flick grace 0.4 s** (PROPOSAL): the server holds a quick-turn shot until the turn arrives (measured lag 0.20–0.27 s in Studio), then fires or drops it.
  - **The shot ticket:** lag compensation counts from the click, not the strike (cap 0.25 s, PROPOSAL).
  - **Far shots** (past 25 studs) don't flinch, cancel animations or cause hitstop.
  - **Shots pass through knocked bodies.**
  - **Position history sampled at 20 Hz** (PROPOSAL), for the server's frame budget (0.07 ms a frame measured).
  - **Fan the Hammer aimed behind** turns you and fires 0.4 s later (PROPOSAL); a refused Fan costs nothing.
  - **A guard-breaking shot shows as a hit** on the marker.
  - **Touch assist ignores townsfolk** (by their folder and their `TownsfolkId`).
  - **The hit box** is 4 × 5 × 2 around the root, 0.5 low (PROPOSAL; the measured R6 height, depth 2 for side-on shots).

**Tests** (hooked Play in each place, one Play session at a time; the owner's whole-profile save dump was identical before and after in every session):
- **The final sweep (Task 12), both places:**

  | Suite | Ye | Foundry Yard |
  |---|---|---|
  | Test_GunAim | 21/0 | 21/0 |
  | Test_GunBalance | 8/0 | 8/0 |
  | Play_GunKit | 3/0 | 3/0 |
  | Play_Guns | 25/0 | 25/0 |
  | Play_GunReload | 11/0 | 10/1, then 11/0 four times |
  | Play_GunNpc | 4/0 | 4/0 |
  | Client checks | 20/1 | 21/0 |
  | Play_Stealth | 9/0 (and 9/0 three times before) | not in Foundry |
  | Play_Assault, Play_TownsfolkHurt, Play_LindenmoorSmoke | 1/0, 11/0, 10/0 | — |
  | Play_FoundrySmoke, Play_FoundryData | — | 15/0, 2/0 |
  | Play_Boot, Road, Arrive | 2/0, 11/0, 5/0 | 2/0, 11/0, 5/0 |
  | Play_Station | 19/1, rerun 20/0 | 19/1, rerun 20/0 |
  | Play_Gate | 13/0 | 12/1, rerun 13/0 |
  | Play_Travel, RideEvents | 5/2, 8/1 (known) | 5/2, 8/1 (known) |

  - **No regressions.** Travel 5/2 and RideEvents 8/1 fail only on the Cabin / Second ticket in the owner's real save, as before. Station's DeathAboard is a first-respawn flake from before the rework. Gate failed once in Foundry during a server hitch (not gun code).
  - **Play_GunReload in Foundry:** EmptyReloadsInTime failed once in five runs during a server hitch; its 0.1 s slack was kept (a flaky timing test is better than a loose one).
  - **Client checks in Ye:** KickRespectsCameraShake failed because Studio was behind another window (client at 15 fps); it passed in Foundry at 42 fps.
- **RED → GREEN, task by task** (each check seen to fail first):
  - Task 1: test_sync 12 failures → 829/0 (`sync.py --backup` and the missing-repo check); the reload id loads (4.07 s).
  - Task 2: Test_GunAim 1/15 → 16/0.
  - Task 3: Test_GunBalance 0/8 → 8/0.
  - Task 4: Play_GunKit 2/1 → 3/0.
  - Task 5: Play_Guns 2/7 → 9/0; fix round 13/0.
  - Task 6: Play_Guns 9/3 → 12/0; fix rounds 14/0.
  - Task 7: reload_slot check 0/2 → 7/0 in both places; Play_GunReload 3/3 → 6/0; fix round 6/2 → 8/0.
  - Task 8: client checks 0/7 → 6/1, then 7/0 with the flick grace (its seam fails at FlickGrace 0); a 10 s hold sent 38 requests (90 at a 0.1 s gap).
  - Task 9: the five feedback checks 0/5 → 5/0; all client checks 12/0.
  - Task 10: the touch checks 0/4 and the kick-undo check 0/1 → client checks 17/0.
  - Task 11: Play_GunNpc 0/3 → 3/0. A 60 s watch: 54 shots, none refused; 26 of 26 on a still target, 11 of 28 on a strafing one.
  - Final fix A: Play_Guns 15/9 → 24/0; the Give fix 24/1 → 25/0.
  - Final fix B: the three new client checks 0/3 → client checks 20/0.
  - Task 12: the delayed Fan guard 0/1 → passes.
- **Studio == repo** (`sync.py --check`): Ye SAME 76 / DIFFER 0 / MISSING 0, Foundry SAME 79 / 0 / 0. test_sync 930/0. `reload_slot.lua` check 7/0 in both places.

**Not tested:**
- **A real phone:** Studio's device emulator couldn't be driven; the harness covered the touch logic (hint, held FIRE, STOP, the assist).
- **Two real players and live ping:** the shot ticket, the lag compensation and the flick grace were tested in Studio, at about zero ping.
- **A real-mouse RMB hold** (the harness held fire through the same input path) and **the Alt shift-lock toggle.** An Alt press that reaches Studio's Play window turns shift lock on and writes your save; the test hook restored it.

**Owner playtest list:**
- Your own strafing offsets your shot (the direction comes from your client's muzzle and is fired from the server's).
- The muzzle sits at root + 1.5 even when crouched.
- Shots pass through knocked bodies.
- Knocked targets are valid touch-assist picks.
- Big flicks on a live server (the 0.4 s flick grace against real ping), and whether far shots feel fair with lag (the 0.25 s cap bounds it).
- A Fan the Hammer started while a quick-turn shot is held is refused.
- On a phone or the emulator: AIM shows, holding FIRE repeats, STOP leaves; how the 2.5° assist feels.
- The kick and the hit tint: how they feel.
- A real-mouse RMB hold.
- The Alt shift-lock toggle, in and out of shooting mode.
- A Fan aimed behind while running is still refused (it costs nothing).
- Fan's turn toward your aim happens even when the Fan can't fire (cooldown or ammo).
- Keep Studio focused (in front) during camera checks: in the background its client drops to 15 fps.

**Backups and rollback:**
- **Backups:** `ServerStorage.RenseiBackups["Pre-GunRework_2026-10-25"]` in both places (24 in Ye, 23 in Foundry Yard, which has no Play_Stealth). It also holds the RED copies of created scripts; those are never restored.
- **The rollback order** (Edit, both places):
  1. Revert the scripts from that backup for this plan's labels: TuningConfig, WeaponManager, DamageManager, SettingsUI, HUDUI, MobileControls, ServerHandler, Requests.Shoot, Requests.WeaponSkill, Requests.Aim, EnemyService, ClientHandler, SmokeKit and Play_Stealth (Ye). SmokeKit and Play_Stealth go back from the backup like any other script.
  2. Delete the scripts this plan created: GunAim, GunAimUI, PositionHistory, GunKit, Play_GunKit and the five gun suites (Test_GunAim, Test_GunBalance, Play_Guns, Play_GunReload, Play_GunNpc).
  3. Run `Art/Studio/Guns/reload_slot.lua` with MODE "undo" (removes only the `Guns_Reload` slot it made, and its flag).
- Reverting TuningConfig alone undoes the balance numbers.

**For the owner: the publish checkpoint.** This plan publishes nothing. It follows `Documents/World Travel.md` §10, after the joint Ye + Foundry Yard publish the owner has already done:
1. **Save** Ye and Foundry Yard in Studio (the changes are in their Edit sessions).
2. **Publish the packages from Ye:**
   - **Modules:** TuningConfig, GunAim (new), WeaponManager, DamageManager, GunAimUI (new), SettingsUI, HUDUI, MobileControls;
   - **RenseiServer:** ServerHandler, Requests.Shoot, Requests.WeaponSkill, Requests.Aim (a comment only), EnemyService, PositionHistory (new);
   - **ClientHandler.**
   - **The reload slot** sits in `ReplicatedStorage.Assets`, which Task 1's survey found is a package. It was written into both places' copies, so publish `Assets` from Ye too.
3. **Update Foundry Yard's packages by hand** (Modules, RenseiServer, ClientHandler, Assets), then check they equal Ye with `sync.py --check` (expect Ye 76 / 0 / 0, Foundry 79 / 0 / 0) and `reload_slot.lua` MODE "check" (7/0).
4. **Publish the places:** Ye and Foundry Yard. The new test suites in `ServerStorage.RenseiTests` go out with them, like the earlier plans' suites.
5. **Last: Migrate to Latest Update** for Ye and Foundry Yard (or shut down all their servers), so no old server keeps the old gun code beside the new.
- **The Tutorial:** if the Tutorial place uses the Modules package, the gun code reaches it when the package updates. It's safe there, because WeaponManager falls back to current positions without PositionHistory. Confirm which places use the Modules package before publishing.

### Discord announcement

Hold: not live yet. Post this when the owner publishes the gun update.

```md
**Update: Guns Reworked**

**Aiming that works**
- Shooting mode now aims where your crosshair is. The camera moves over your shoulder, and your shots land on the crosshair.
- Locked on? Your shots go to your target.
- Hold right mouse (or FIRE) to keep shooting.
- Quick turn-and-shoot works now.

**Every gun feels different**
- Revolver: a hard-hitting hand cannon.
- Renetti: quick and close.
- Forge Tac: a long-range marksman pistol.
- Sykov: the all-rounder.
- Hits flash your crosshair, and guns kick when they fire.

**Reloading**
- A new reload animation.
- Reloading is still automatic, and now it also tops up your gun when you leave shooting mode.
- Getting hit interrupts a reload. It starts again once you're free.

**Also**
- Fan the Hammer is a close-range move now.
- You can't shoot while swimming.
- Bandit gunners give you a moment to react, and they don't hit every shot.
- Touch players get a little aim help.
```

## 2026-10-24 — Foundry Yard comes alive: game data, Brannoc's move, the shift ledger (not live)

The Foundry Yard game-data plan (`Documents/plans/2026-10-24-foundry-yard-game-data.md`, Tasks 1–10, run 2026-10-24 to 2026-10-25) gave the new Foundry map its game. All of it is in the Studio Edit sessions of **Foundry Yard** (109591196441030) and **Ye** (106992859583940). **Nothing is saved or published.** The owner's "Hold both" stands: Ye and Foundry Yard go out together, through the joint publish checkpoint in `Documents/Lindenmoor Kit.md`. This is the plan's only Changelog entry.

Every number is a **PROPOSAL** unless it is measured or the owner chose it. The full list for review, the rollback and the smoke table are in `Documents/Foundry Yard Kit.md`, "The game data".

**The decisions:**
- **Grunts in the underworks** stay live (owner).
- **A:** Ye's `FoundryYard` model (Brask's yard and `chalk_foundry`) stays in Ye for now (owner).
- **B:** the Ward Alchemist spawns inside the Silent Forge room (owner).
- **C:** saved `acq_metal` stages move forward one on join, because the quest gained a first stage (controller).
- **D:** a notice at Ye's Metal TrainerSpot starts `acq_metal` (owner).
- **E:** the forge trial uses Radius 24 and FoeDistance 14, so it fits the Forge Floor's shell (owner; PROPOSAL numbers).
- **Quick mode:** `Play_FoundryWalks` can re-walk only the routes that failed or needed a replan (owner, 2026-10-25).

**What changed in Foundry Yard:**
- **Areas:** the 11 area names and `Silent Forge` map to region Foundry.
- **Posts:** 12 new Shelter posts, so every one of the 88 posts has a shelter within 145 studs. The two yard posts came off the goods platform. The four market stalls are reachable (walk-through shelves, PassThrough canopy modifiers). Applied by `foundry_posts.lua`.
- **Townsfolk:** 26 townsfolk on two shifts (06–14 and 14–22, with a furnace keeper 22–06). The crews eat at the canteen at shift change, and the market runs 08–20. All names are original.
- **The shift-ledger quest** (`foundry_ledger`): the ledger at the shift office, three townsfolk with clue lines, the altered docket in the underworks, and a deduction. It gives 300 EXP, 100 money and the deed `foundry_ledger_cleared`.
- **Forge rooms:** the Silent Forge and the Forge Floor are inside the great hall's forge wing, and Brannoc is in the practice court (`build_forge.lua`). The Ward spawn is inside the Silent Forge. The Forge Floor's shell anvil, which stood in the arena, is hidden (`hide_anvil.lua`).
- **Walking:** the crates by House 11 and the stall counters moved a little, so every walk fits (`walk_fixes.lua`).
- **Place scripts:** `TownsfolkClient` (speech bubbles) and the owner's `Health` script (no health back in combat), which Foundry lacked.
- **Sync:** Foundry's package copies were already level with Ye's when the plan began. Its test suites were caught up (`sync.py`, Task 1), and every later script change went into both places.

**What changed in Ye:**
- **Brannoc moved out:** Brannoc, the Silent Forge, the Forge Floor and the Ward spawn are retired into `Pre-FoundryMove_2026-10-24` (`retire_ye.lua`, reversible). Their tags are set aside, so nothing in the backup spawns or prompts.
- **The notice:** a notice at the Metal TrainerSpot points students to the Foundry ("...OR WALK THE NORTH ROAD OUT NORTH-WEST", Ye's compass).
- **Posts:** five Lindenmoor posts moved out of the solid parts they stood in (`post_fixes.lua`).
- **Part count:** Ye's workspace is 76,326 parts.

**The game scripts** (both places, through `sync.py`; a backup of each first in `Pre-FoundryData_2026-10-24`):
- **Quest revisions:** `StoryLogic.UpgradeQuest` and `StageIndex`; `QuestService` with revisions, `Boot` (the save upgrade on join, which in Studio waits for the test hook's snapshot) and deeds as rewards. A stale save takes no signal until upgraded. Since the final fix, `UpgradeQuest` never moves a save below stage 1. **The upgrade is one-way once published:** a rollback keeps acq_metal's 7 stages, `UpgradeQuest` / `Stale` and `Boot` (the Kits' rollback sections).
- **`acq_metal`:** a travel stage first ("Travel to the Foundry Yard"). Brannoc's new lines, the notice, the trial numbers, and the Foundry areas.
- **The Mover:** corner repair, a body rule, a 3D sight ray and honest stuck counting.
- **TownsfolkService:** a failed walk holds and retries; a townsperson is placed only when no player is within 300 studs; the server checks the Talk range.
- **Smaller changes:** `MinigameService.Submit` (for tests) and `ServerHandler` (calls `Boot`).
- **The region schema** now type-checks `RestoreRefuseFlags` and `Notes`. Foundry's `restore.lua` refuses while `FoundryPosts`, `FoundryForge`, `FoundryLedges`, `FoundryWalks` or `FoundryAnvil` is set. Lindenmoor's `restore.lua` (regenerated, only its flag list changed) now also refuses while `LindenmoorPostFixes` is set.

**Tests** (every Play session ran the hook protocol; the owner's `Data.Quests` dump was identical before and after in every session):
- **Pure checks:**
  - test_sync 654/0;
  - test_kit 75/0;
  - foundry_check 37/0;
  - run.py 230/0 (218 plus Task 10's 12 schema cases; RED 220/10 before the schema change);
  - test_bundle_forge 41/0, test_ye_fixes PASS and test_bundle_prep 6/0.
- **Foundry (final sweep, Task 9 and its fix round):**
  - Play_FoundrySmoke 15/0 and Play_FoundryData 2/0 (`acq_metal` end to end through the real services);
  - Ledger 8/0, Forge 8/0, Roster 7/0, AcqMetal 13/0, Regions 9/0, QuestRevision 15/0, QuestEngine 8/0;
  - Exams 5/0, Clue 1/0, Clock 5/0, NoGrip 6/0;
  - Crowd 14/0 (1.016 ms), MoverRepair 12/0 and FoundryPaths 7/0;
  - **Play_FoundryWalks 6/0 in three separate sessions,** each with 73 of 73 walks arrived and none failed.
- **Ye:**
  - LindenmoorSmoke 10/0, LindenmoorData 3/0;
  - Exams 5/0, Clue 1/0, Regions 9/0, AcqMetal 13/0, QuestEngine 8/0, QuestRevision 15/0;
  - Townsfolk 18/0, Crowd 14/0 (1.058 ms), Hurt 11/0, YePaths 7/0 and MoverRepair 12/0.
- **Travel suites, both places:**
  - Boot 2/0, Station 20/0, Road 11/0, Gate 13/0 and Arrive 5/0;
  - Travel 5/2 and RideEvents 8/1 fail only on the Cabin / Second ticket in the owner's real save.
- **Studio == repo** (`sync.py --check`): Ye 50 / 0 / 0, Foundry 54 / 0 / 0.
- **RED first:** every new check was first seen to fail, before its change or against a deliberate break (each task's report).

**For the owner:**
- **The joint publish checkpoint** is in `Documents/Lindenmoor Kit.md`:
  1. save both places;
  2. walk each once in Play;
  3. check both places for test leftovers (the checkpoint's command-bar line);
  4. publish the packages from Ye;
  5. update Foundry's packages by hand and check them equal;
  6. publish Ye and shut down all Ye servers straight away;
  7. publish Foundry Yard immediately after and shut down all its servers straight away. Don't use a gradual Migrate: old servers would misread upgraded saves.
- **Look at:** the Silent Forge's second anvil, `RepairedGear` (it may float), and the PROPOSAL numbers. All are listed in the Foundry Yard Kit's "For the owner to look at".

### Discord announcement

**Live (owner published Ye, Foundry Yard and the packages, 2026-10-25).** Ready to post.

```md
**Update: Foundry Yard Comes Alive**

**A real town at the end of the line**
- Foundry Yard is a whole town now: the station, Cinder Lane's terraces, the rail yards, Workers' Row, the square with its market and canteen, and the great hall where the furnaces roar day and night.
- Take the train from Lindenmoor, or walk the road north.

**A town at work**
- 26 townsfolk live and work here on two shifts: crane and furnace hands, yard hands, a porter, cooks, traders, errand runners and more.
- When the shift changes, the crews head to the canteen to eat. The market is open from morning till evening, and at night a keeper watches the banked fires.
- They walk the town properly now, around corners and between the stalls, and nobody pops from place to place while you're watching.
- When trouble starts, they run for shelter.

**A mystery in the shift ledger**
- Someone has been faking hours in the Foundry's shift ledger. Start at the shift office by the practice court, ask the right people at the right time of day, and work out who did it.

**Brannoc has moved**
- Brannoc and his forge have left Lindenmoor for the Foundry: he teaches in the practice court, and the forge rooms are in the great hall. A notice where he used to stand points the way.
- The Metal path now starts with a trip to Foundry Yard: take the train, or walk the road. Already partway through? Your progress carries over.

**Danger below, water above**
- Bandits lurk in the tunnels under the town. The streets above are safe.
- An alchemist guards the Silent Forge in the great hall.
- The cooling pond in the crane yard is deep enough to swim and dive in.

**Also**
- Your compass matches each place: north points the right way in Lindenmoor and in Foundry Yard.
- In Foundry Yard too, health only comes back once you're out of combat.
```

## 2026-10-24 — Lindenmoor import: final fix pass (retired spawns, rollback guards, docs; not live)

The final review of the Lindenmoor import asked for these fixes (Ruling 43). All of it is in Ye's Studio Edit session (106992859583940). **Nothing is published.** The publish is on hold until the Foundry Yard plan finishes Foundry's game data. Then Ye and Foundry Yard go out together (the owner's "Hold both", 2026-10-24).

**Retired enemy spawns no longer spawn (C1).**
- `prep_ye.lua` moved the old hub's two `GruntSpawn`s into `RenseiBackups["Pre-LindenmoorExpansion_2026-10-24"]`, and they kept their `RenseiEnemySpawn` tag. `EnemyService` found them through `GetTagged`, so two Grunts stood by the old hub at (−17, _, −70) and (26.5, _, −70) and kept respawning.
- **EnemyService** now spawns only from tagged spawns in `workspace`, at Start, when a tag is added, and on respawn. `Spawn()` refuses a part that sits in the DataModel outside `workspace`. It still takes an unparented mark, because the road ambushes and the ride holdups spawn from those on purpose.
- **CompassService** publishes only points in `workspace`.
- **TownsfolkService** counts only posts in `workspace` (review M1).
- **The audit:** every tagged instance in `ServerStorage.RenseiBackups` was checked against every server consumer of its tag. Only `RenseiEnemySpawn` reached a consumer without a filter. The road and travel tags were already filtered, and the other backed-up tags have no consumer.
- **New smoke check, `EnemiesStandInTheWorld`:** every live enemy's Home is in `workspace` (or is a runtime mark), no backed-up spawn has an enemy, and the ground is under every spawn in use. Before the fix it failed on exactly this bug (7/1).

**Rollback guards (I2).**
- `import/restore.lua` refuses while the expansion carries any of the seven fix flags. They come from the region file's new `RestoreRefuseFlags`, through `kit.py` and the restore template. A region without the key gets byte-for-byte the same `restore.lua` as before (Foundry and Testbed regenerate unchanged).
- `gorge_fix.lua` undo refuses while the seam pits, the bed or the road cut is applied.
- `regrade_seam` undo refuses while the gorge fix is applied, as well as the road cut or the seam pits.
- `road_cut`'s header now says which undos refuse.
- **Tested in Ye (Edit):** the template and committed copies were changed alike. Each guard refused on today's applied state, with the state unchanged. A control copy with a dummy flag got past each guard, and stopped there.

**Docs.**
- **`Documents/Lindenmoor Kit.md`** has two new sections:
  - "Ye differs from the kit": a re-import or Blender rebuild drops every Studio fix;
  - "Known issues".
- The Kit's publish checkpoint now opens with the hold, and its package list has EnemyService and CompassService.
- **The unexplained parts** are identified (read-only): 10 hand-made Studio duplicates in the expansion, listed in the Kit's part count. None was deleted.
- **The Lindenmoor Discord post** now says the compass matches the land, says the open land falls under Lindenmoor's law, and puts the mine beside the Adit hill.

**Tests:**
- **New `test_ye_fixes.py`:** 26 checks pass, 0 fail. It pins the east/west name swap against the kit's layout.json and chunks (review M5), keeps the generated scripts equal to their templates, and checks every guard.
- **`test_kit.py`:** 75/0.
- **Hooked Play in Ye** (the owner's save restored before every Stop):
  - **The RED run, before the EnemyService fix:** Smoke 7/1, failing on EnemiesStandInTheWorld. Two Grunts stood within 60 studs of (5, _, −70).
  - **The first fixed session** caught a regression in the first version of the guard: Play_Road 8/3, with no ambush bandits. The guard had also refused the road's unparented spawn marks, so `Spawn()` now refuses only parts in the DataModel outside `workspace`.
  - **The final session:**
    - Smoke 8/0, LindenmoorData 3/0, Townsfolk 16/0 and TownsfolkHurt 11/0;
    - Road 11/0, Stealth 9/0, Perception 6/0, Assault 1/0 and Heat 8/0;
    - RideEvents 8/1: the known Cabin ticket in the owner's save.

    No live enemy within 60 studs of (5, _, −70), and 16 live enemies, one per spawn in `workspace`.
  - **In the earlier session:** TownsfolkHurt 10/1 on its first run (NewcomerAtSix read Asleep for AtPost, a timing race with the sleep step), then 11/0. Stealth 8/1 on GunshotPullsTheCamp: it picks any live Grunt, and that one didn't hear the shot. Both passed in the final session.

### Discord announcement

Live (2026-10-25). Nothing here is new to players on its own: it shipped inside the Lindenmoor update (see that entry's post).

## 2026-10-24 — The Lindenmoor expansion is in Ye (import plan Tasks 1–9; not live)

The approved Blender expansion now fills Lindenmoor's 2,048 × 2,048 footprint around the village in Ye (106992859583940). All of it is in Ye's Studio Edit session, and **nothing is published**. The owner's decisions:
- "The Lindenmoor expansion is gonna go in Ye";
- the hub's pieces "move into the new map";
- exits "Together, NE corner" (north-west on Ye's compass, below);
- ungrippable edges with no invisible walls;
- "Lindenmoor's (Recommended)" law for Ye's unnamed ground.

Every number is a **PROPOSAL** unless the owner chose it. The details, the rollback order and the publish checkpoint are in `Documents/Lindenmoor Kit.md`, "The import is done".

**What went in:**
- **The land (Tasks 1–6):**
  - a read-only survey of Ye, then a reversible prep (`prep_ye.lua`) that moved the trainers, the five trial sites, the LedgeCourse, spawns and four lifted items onto their pads, and retired the old NorthRoad, HubRoad and buffer stop into a backup;
  - the import itself: 1,734 models, 40,645 parts and 218 water boxes, with the crag tagged `RenseiNoGrip` (2,141 parts);
  - seam fillers.
- **The owner's Studio fixes:**
  - the seam regrade and the seam pits, so the new ground meets the village without walls, trenches or holes;
  - the gorge: a straight, centred footbridge and water wall to wall;
  - a slate creek bed under the water.
- **Travel (Task 7):** the road to Foundry Yard is built from its marker by `setup.lua`, with a road cutting so it sits on the ground and a ramp at its mouth. There is one RoadStart, one Platform and one platform train in the place.
- **Game data (Task 8):**
  - the 10 new areas, all under Lindenmoor's law; `AreaAt` now picks the smallest box;
  - two clue quests (the Ridge Marker and the Boarded Shaft);
  - a roster of 8 townsfolk for the expansion's posts, plus 7 more Shelter posts so everyone has a shelter within 150 studs;
  - the acquisition quests' directions to the trial sites' new homes;
  - townsfolk give way to someone in a hurry in time, and only run to a shelter within 150 studs;
  - the compass reads north per place: Ye's north is +Z, so its east is −X. Lindenmoor's East/West words are swapped to match: West Lookout, Northwest Gap.
- **Task 9:**
  - a new smoke suite, `Play_LindenmoorSmoke`;
  - the d3606a5 Play_Station and Play_Road installed in Ye;
  - a Studio == repo sweep of every `Scripts/` copy and the Adit boards kit;
  - these docs.

**Tests (hooked Play in Ye; the owner's save restored before every Stop; one Play session at a time across Ye and Foundry):**
- **Play_LindenmoorSmoke 7/0** after review fix round 1 (with Play_NoGrip 6/0), under the stricter crag check. With the crag tags removed around one spot it fails, as it should. It checks that:
  - the crag refuses a climb and a wall run on all four edges, and a control proves it is the tag;
  - there is water in the creek and the gorge;
  - the expansion's 10 lamps are lit at 23:00 and dark at 12:00;
  - there is one RoadStart, one Platform and one LindenmoorFoundry platform train;
  - the gorge ledge faces its wall;
  - all five trials start;
  - the five trainers stand at their spots and can be talked to.
- **Travel suites:**
  - Boot 2/0, Gate 13/0, Arrive 5/0, Station 20/0 and Road 11/0;
  - Travel 5/2 and RideEvents 8/1 fail only on the Cabin / Second ticket in the owner's real save.
- **Also:** NoGrip 6/0, Clock 5/0 and LindenmoorData 3/0. Task 8's suites passed in its own rounds.

**Part budget:**
- **Workspace:** 76,373 of the place's 80,000.
- **The expansion:** 45,425. That is over its own 42,000 ceiling, which Ruling 25 accepts.

**Repo brought up to Studio (the sweep):** these files were stale copies of what is already in Studio, and the game is unchanged:
- `Scripts/`: ProfileData, JumpManager, StealthUI, PuzzleClient, FlowService, PuzzleService, Test_Schema5, Test_Witness and `ClientHandler/Run`;
- the boards kit: `Art/Studio/HalvardsAdit/boards/Investigation.lua`.

Two whitespace-only differences in `Art/Studio/Travel/src` (Play_Boot, RenseiBoot) were left alone.

**For the owner:** the publish is **on hold** until the Foundry Yard plan finishes Foundry's game data (the owner's "Hold both", 2026-10-24). Then Ye and Foundry Yard go out together, and publishing Foundry ships its new map. The steps, for then:
1. Save Ye in Studio. Don't publish yet.
2. Walk the new land in Play once.
3. Publish the packages from Ye:
   - Modules: Regions, Townsfolk, TownsfolkLogic, Quests, Dialogues, Investigation, Evidence, Puzzles, CompassUI and MasteryUI;
   - RenseiServer: WorldService, TownsfolkService, TownsfolkService.Mover and MoralityService, plus EnemyService and CompassService (the final fix pass, below);
   - ClientHandler (`Run`).
4. Update those three packages in Foundry Yard by hand, and check they match Ye.
5. Publish Ye and Foundry Yard.
6. Migrate to Latest Update.

This follows `Documents/World Travel.md` §10. The Kit doc has the full list, including older Studio changes that go out with these packages (HitboxManager's Strike hook among them).

### Discord announcement

**Live (owner published Ye, Foundry Yard and the packages, 2026-10-25).** Ready to post, together with Foundry Yard's post.

```md
**Update: Lindenmoor Grows**

**A whole valley around the village**
- Lindenmoor is no longer a lone village. The land around it is open to explore, ringed by forested ridges and tall cliffs that can't be climbed.
- Four farmsteads and a roadside market, with a watermill on the creek.
- Mill Creek's gorge, with a footbridge, a waterfall and a narrow ledge walk along the cliff.
- The old mine, up on its plateau beside the hill of Halvard's Adit, the Bramble woods, and wide meadows of fields, orchards and hay barns to the north.
- The road to Foundry Yard now leaves Lindenmoor to the north-west, beside the railway, through a gap in the ridge.

**Training and trials**
- The alchemy trainers have a new training field just north of the village.
- Four of the alchemy trial sites have new homes out in the valley. Brannoc and the forge have moved to Foundry Yard. Ask your trainer where to go.

**Getting around**
- Your compass now matches the land: north, south, east and west point where you'd expect.
- All the open land around the village now falls under Lindenmoor's law.

**Townsfolk**
- New townsfolk live and work around the valley: farmers, a miller, a mine hand, a groundskeeper and a signalman.
- They give way better when someone is in a hurry, and in trouble they run to a shelter close by.
- Some of them know a thing or two. Look around and ask.
```

## 2026-10-24 — Foundry Yard's new map imported into the Foundry Yard place (not live)

On the owner's request ("Import Foundry Yard into the Foundry Yard place"), the approved Blender build replaced the hand-built World Plan 1 map in the Foundry Yard place (109591196441030). It was done in Edit mode with the region tools. Ye wasn't touched, and nothing is published: **the place needs the owner's save**.

**The import:**
- **Export and scripts:** exported from Blender at origin (0, 0, 0): 2,061 models, 43,685 parts and 189 lights. `kit.py` wrote 39 chunks.
- **Dry run:** ok. Every model, part and tag count matched.
- **Real run:**
  - `World.Map.Foundry` is the new map.
  - The old map is backed up in `RenseiBackups["Pre-Region_Foundry_2026-10-24"]`, with its tags set aside. `restore.lua` undoes the import.
  - The three texture-pack MaterialVariants are in.
  - The cooling pond is terrain water.
- **Travel setup:** `setup.lua` built the station (platform train and ride train), the ticket booth, the departure board, the papers gate and its railing, the stowaway freight yard with its watchman, and the 447-stud South Road to Lindenmoor with its 3 encounters, threshold and RoadStart arrival. The contract test passes 101/101.
- **Spawn:** a SpawnLocation stands on the new platform. The old one went to the backup with the old map.

**Fixed on the way:**
- **Missing buildings.** The first dry run caught 231 missing buildings, and nothing changed. The region builder numbered building ids per street frontage, so a district facing two streets repeated names, and the import replaced one building with another. Ids now run through the whole district (`placement.plan_buildings`). There are new checks in `tests/run.py` (218/218) and `foundry_check.py` (36/36).
- **Trees past the wall.** The South Road's passage put trees and ground past the south wall, and an oak reached through the portal. Its `Skip` now reaches past the footprint, and the passage's end-of-road trees honour `Skip` (`travel_pieces.lua`; with no `Skip`, as on Lindenmoor's road, nothing changes). `test_kit.py` passes 72/72.

**Play (hooked; the owner's save restored before Stop; one Play session at a time across Ye and Foundry):**
- **Passing:** Boot 2/2, Station 20/20, Road 11/11, Gate 13/13, Arrive 5/5.
- **Known failures:** Travel 5/7 and RideEvents 8/9, only the known Cabin/Second ticket in the owner's save.
- **Test fixes:** `Play_Station` and `Play_Road` (`Art/Studio/Travel/src`) now read a setup-built station and a shorter first road leg. Nothing changes in Ye.

**Owner:** "Keep the Foundry import as it is; I'll save the place in Studio."

**Next:**
- the owner saves the place;
- Brannoc and the forge rooms move from Ye (that touches Ye);
- the game data: areas, the townsfolk roster, clues and the shift-ledger quest.

See `Documents/Foundry Yard Kit.md`, "The import".

### Discord announcement

Hold: not live yet.

## 2026-10-24 — Foundry Yard built in Blender (owner-approved layout and renders; not imported)

Foundry Yard's new map is built in Blender with the region builder, from the layout the owner approved: 1,536 × 1,536 studs in soot, iron, furnace brick and ember, following the brief's page and spec §7. Nothing changed in Studio, and no game script changed. Every number is a **PROPOSAL** unless the owner chose it.

**Owner decisions (2026-10-24):**
- **Layout:** "Yes, build it".
- **The north road toward Central City:** a shut gatehouse at the end of a viaduct, with a solid wall behind it.
- **Brannoc's forge rooms:** Foundry-style shells in the great hall, ready for the Silent Forge and Forge Floor pieces from Ye.
- **Enemies:** a few Grunts in the underworks only.
- **After the first renders:** "Fill the empty east first, and remember to place things for the movement and combat we currently have in game".
- **Renders:** "Approved" for a later Studio import.

**What's there:**
- **The station (south-west):** the terminus, a platform canopy, the booking hall with the ticket booth, the papers gate and the railing, and the stowaway yard by the baggage car. Setup builds the travel pieces from markers at import.
- **The rail corridor:** two lines leaving east through a dead-end tunnel portal, raised iron rail walks and signal gantries.
- **Housing:**
  - Cinder Lane and the lower town;
  - Brannoc's practice court, with the shift office and its ledger clue beside it;
  - workers' row and the boarding houses;
  - the market square with 16 stalls and the canteen.
- **The underworks:** a dark brick tunnel along the south edge.
- **The freight yard:** box wagons on the sidings, a goods platform and warehouses.
- **The rail yards:** engine and coal sheds, crane bays on a spur, a cooling pond and raised walks.
- **The foundry works:** a 200 × 110 great hall with furnaces, gantries and the two forge rooms, plus stacks, sheds and a casting shed.
- **The south road to Lindenmoor:** it winds between slag heaps to a tunnel portal.
- **The north viaduct:** it crosses a slag cut to the shut gatehouse.
- **Edges:** ungrippable slag walls. The only gaps are the two portals, each a dead end.

**Movement and combat:**
- climbable faces everywhere, with copings, wagon roofs and tower decks to pull up onto;
- wall-run walls, including two pairs set 12 apart for chained kicks;
- ledge-walk strips on the yard walls, rail walks and houses;
- loud iron high routes;
- roofed shade for stealth (tunnel, halls, canopies, stalls);
- crate, wagon and wall cover;
- a pond to swim and dive in.

**Numbers:** 43,685 parts against the 45,000 ceiling. There are 76 townsfolk posts, 2 clues, 11 area names, 4 Grunt spawns, and Brannoc's trainer spot.

**Files:**
- `Art/Regions/Foundry/` (the region file, materials, water);
- `region_builder/kits/foundry.py` (10 set pieces), `extras.py` (portals, the viaduct, a render-only travel preview) and `tools/build_foundry.py`;
- the tests `tests/foundry_check.py` and `tests/foundry_blender_check.py`;
- the renders in `Documents/images/Regions/Foundry/`;
- **`Documents/Foundry Yard Kit.md`**, with the layout, the movement table and the **Foundry import notes**: the MapChild, keep list, ORIGIN, what the import retires, Brannoc's move, the roster, areas and clues.

**Tests:** `foundry_check.py` 35/35; `run.py` 216/216; `foundry_blender_check.py` 13/13 (parts within budget, ungrippable edges and portals, the viaduct, the forge rooms, every post, clue and spawn on walkable ground).

**Next:** the Studio import into Foundry Yard, in a later session, following the import notes.

### Discord announcement

Hold: not live yet.

## 2026-10-24 — Region Foundation final fix pass: ready for the Lindenmoor import into Ye

The final whole-branch review found five things that would have gone wrong in the Ye import. They are fixed in the tools and the docs; no game script and nothing in Ye changed.
- **The road's position (docs).** `setup.lua`'s `ORIGIN` for Lindenmoor is `(0, 0, 0)`, not `(0, 4, -650)`: Lindenmoor's marker attributes are in world studs. Water is the opposite case: its boxes must be village-local. Both docs now say when `ORIGIN` is non-zero, and `bundle_setup.py` sets it without editing `setup.lua`.
- **Trainer spots.** `setup.lua` and the schema skip the five `TrainerSpot` markers (listed in the summary); other unknown pieces are still refused.
- **Invisible walls.** Region marker parts (the huge area boxes, posts, clues) no longer collide, and can't be queried or touched, so they no longer block climbs, NPC sight or projectiles. Only `RenseiLedge` (query) and `RenseiStationGate` (touch) keep one, because their services need it.
- **Walk-through decoration.** The walk-through lists are per region; Lindenmoor's import keeps the village's own (verge stones, crops, tufts, vines, lanterns).
- **The dry run** now checks the keep list like the real run and lists exactly which map children would be moved and kept.
- **Also:** `finish.lua` and `restore.lua` record their swap for Studio's Undo; a "Rolling back" section and the hub-pieces rule in the Lindenmoor checklist; the stale "Importing later" steps rewritten; direction words made consistent (+Z is north in Ye); the two old station scripts marked historical.
- **New smoke test (Foundry only):** `Art/Studio/Regions/smoke.py` imports the Testbed into Foundry Yard for real, plays it (`Play_RegionSmoke` 6/6: areas, rays across area faces, climbs refused on edges and area faces, a lamp on the clock, the clue prompt), builds a road with `setup.lua`, restores, and checks Foundry is exactly as before (it was).
- **Tests:** `region_builder/tests/run.py` 216/216; `test_kit.py` 72/72; Lindenmoor's and the train's kit outputs unchanged; the contract test on live Foundry 93/93.

### Discord announcement

Hold: not live yet.

## 2026-10-24 — Region Foundation complete (Task 13): what it built, and the final test run

The Region Foundation is done: the shared pieces every new region map needs, built and reviewed task by task from 2026-10-23 to 2026-10-24 (Tasks 1–12; each has its own entry below). Next, in the order you set: the **Lindenmoor expansion import into Ye**, then the **Foundry Yard plan**, then the **gun and swimming reworks**. Every number in the work is a **PROPOSAL** unless you chose it.

**What's in the live game now** (you published RenseiServer and Modules with Tasks 1–10b):
- **A day and night (Task 2).** One real minute is one game hour, so a day takes 24 minutes. It's the same hour in every place and on every server. Lindenmoor's street lamps light at night, and night makes you harder to see.
- **Trainers' exams open again (Task 1).** "I'm ready for the examination." now opens the exam with all five alchemy trainers.
- **Assault needs a landed hit (Task 6b).** A blocked, dodged or missed swing at a witness no longer counts.

**Built and live in the code, but not visible until a region ships:**
- **Townsfolk (Tasks 3–6b).** They have jobs, day schedules, crowd-quality walking, speech bubbles, rumours and clue lines. They run from fights, and can be hurt, knocked and killed, with the full Heat, morality and reputation cost. Ye has no roster yet, so nobody appears; Foundry Yard's townsfolk come with the Foundry plan.
- **Clues that start quests (Task 7).** These are map points tagged `RenseiClue`.
- **Ungrippable edges (Task 10b).** The tag `RenseiNoGrip` can't be climbed, leapt or wall-run; no live map part carries it yet.

**The region tools (Tasks 8–12; nothing changed in Ye's map):**
- a region file;
- a Blender builder: stepped ground, roads, the rail-town kit, edges and markers, with renders for your approval;
- an export that carries tags;
- a safe import: a dry run first, a real run only with `Confirm`, a keep list, rollback, restore and unstrip;
- a travel setup that builds stations and roads from markers, one of each per place.

**New docs:**
- `Documents/Region Builder.md`, the how-to for all of it: the region file's keys, running the builder, export, import, setup, the marker table, the townsfolk roster and clue formats, and the clock.
- `Documents/Lindenmoor Kit.md` now notes the `export.py` and `studio_kit.py` changes, and has a "Before the import into Ye" checklist.

**Still open for you:**
- **HubLaw:** the old Lindenmoor plan says to set Ye's HubLaw to Lindenmoor, but you chose "Keep State law". Ask before the import changes it.
- **Townsfolk:** should hurt townsfolk heal at 06:00? Should murder also raise Circle Heat?
- **Edges:** a boundary vault, or a leap with no hold, can't chain over an all-tagged wall. Decide whether that's fine before Lindenmoor's crag is tagged.

**Final test run (Ye, 2026-10-24; the owner's save restored after each of 4 Play sessions, the test hook removed and PlayLock cleared):**
- **Play, passing:**
  - Rumours 3/3 (run first), Boot 2/2, Station 20/20 (first run), Road 11/11, Gate 13/13 (run before Crowd);
  - Arrive 5/5, Clock 5/5, AditBoards 10/10, Clue 1/1, NoGrip 6/6;
  - Heat 8/8, Morality 3/3, Assault 1/1, Townsfolk 16/16, TownsfolkCrowd 13/13.
- **Play, known flakes that passed on a rerun or in a fresh session:**
  - Perception 6/6 when first in a fresh session. In another session it failed 1 of 6 when run first, then 3 of 6 on a rerun after other suites.
  - Stealth 8/9 (`GunshotPullsTheCamp`), then 9/9.
- **Play, new flakes (not fixed in this task):**
  - Exams 4/5 (`EarthExamOpens`: the exam wasn't running 1.5 s later), then 5/5 on a rerun.
  - TownsfolkHurt 9/10 (`Gossip`: the townsperson told the "struck" rumour, not the killing) twice when run after Townsfolk and Assault in the same session; 10/10 first in a fresh session. It looks order-dependent: deeds from earlier suites stay in the session, and the test's four talks hold only one rumour.
- **Play, failing because of a test issue (pre-existing):** the owner's save holds a Cabin ticket, and these suites have no wrapper that clears tickets:
  - RideEvents 8/9 (known);
  - Travel 5/7 (`TicketsAddUseAndKeepCount`, `LoopbackArrivesAtThePlatform`). It has the same known cause, but is first recorded for Travel: adding a ticket keeps the better Cabin class.
- **Edit:** all 12 `Test_` modules pass:
  - TownsfolkLogic 9/9, RumourCore 10/10, Reputation 10/10, Travel 8/8, Sound 8/8;
  - Heat 6/6, Regions 6/6, Schema5 6/6, Perception 4/4, TestKit 4/4, Witness 3/3, AditRoute 1/1.
- **Python:** `region_builder/tests/run.py` 202/202; `Art/Studio/Regions/test_kit.py` 47/47.
- No game script was changed in this task.

### Discord announcement

```md
**Update: Day and Night**

**A living clock**
- Time now moves! A full day and night takes 24 minutes, and it's the same time everywhere. If it's evening in Lindenmoor, it's evening in Foundry Yard too.
- Lindenmoor's street lamps light up at dusk and go out at dawn.
- Night is darker, which makes you harder to spot. Sneaking is easier after dark.

**Fixes**
- The alchemy trainers' examinations work again. Choosing "I'm ready for the examination." now opens the exam with every trainer.
- An attack only counts as assault if it actually lands. Blocked, dodged or missed swings no longer count against you.
```

## 2026-10-24 — Region Foundation Task 12: stations and roads built from map markers

A region's map can now carry markers for its station, ticket booth, departure board, papers gate, railing, freight yard and road passage. One script builds the real pieces from them, the same pieces World Plan 1 built by hand in Foundry Yard. Tested in Foundry Yard, which was left exactly as it started; **Ye was not touched.** Code:
- `Art/Studio/Regions/travel_pieces.lua`, the builders taken from `station_foundry.lua`, which stays unchanged;
- `setup.lua`, with `bundle_setup.py` to bundle it;
- `Test_SetupContract.lua`;
- the marker rules in `Art/Blender/region_builder/schema.py`.

- **How it works.** `setup.lua` reads every `RenseiMarker` under `World.Map.<MapChild>`, the same map folder the region import uses, and builds the pieces into its `Travel` folder.
  - It checks every marker before building anything, and builds everything or nothing.
  - Running it again rebuilds `Travel`. A hand-made `Travel` is backed up the first time.
- **One of each per place.** The game uses the first arrival point and the first train it finds for a route, so setup refuses to build a second platform arrival, road start or train for a route that the place already has anywhere.
  - For Lindenmoor's expansion this means no station marker, since the village keeps its station.
  - The village's old north road and its road start must be retired, with a backup, before the expansion's new north-east road is built.
- **Same as the hand-built station.** In a test build from markers, every piece matched Foundry's live station to the stud, except that the ride train now sits relative to its platform (the game only uses that offset).
- **Checks.** The contract test checks every rule the travel system relies on: trains, booths, boards, gates, the freight yard, arrivals, road passages and areas. Live Foundry passes 93/93. The test only runs on a folder explicitly marked `TEST`.
- **Tests:**
  - the region tests pass 202/202;
  - the synthetic station passes 90/90;
  - two roads, the second without a road start, pass 113/113;
  - an expansion-style folder beside a copy of Foundry's map passes 12/12;
  - every refusal left `Travel` unchanged.

### Discord announcement

Hold: not live yet. This is behind-the-scenes map tooling; there's nothing for players to see until the first new region ships.

## 2026-10-24 — Region Foundation Task 11: importing a region into any place, safely

A region built in Blender can now be imported into any Studio place. The tool builds it in a staging folder, checks it, and swaps it in only when you confirm, with an undo and a restore. It was tested in Foundry Yard, which ended exactly as it started each time. **Ye was not touched.** Tools:
- `Art/Studio/Regions/kit.py`;
- the templates `finish_region.lua.tmpl`, `restore_region.lua.tmpl` and `unstrip_region.lua.tmpl`;
- the shared `Art/Studio/Lindenmoor/studio_kit.py`.

- **How an import works.**
  1. `python -I Art/Studio/Regions/kit.py <Region>` writes chunk scripts and the files `expected.json`, `finish.lua`, `restore.lua` and `unstrip.lua`.
  2. Running the chunks builds the region into `ServerStorage.RegionStaging`. Nothing is in the live map yet.
  3. **A dry run** (`DryRun` set on the staging folder) compares the build against what's expected: part counts, every tag (townsfolk posts, clues, areas, ledges, `RenseiNoGrip` on the edges), materials and texture images. Then it removes everything it made and reports.
  4. **A real run** happens only when the staging folder carries `Confirm = "<Region>"`. It refuses, before changing anything, if:
     - the checks fail;
     - it's the wrong place;
     - something listed to keep isn't there;
     - today's backup already exists.
- **What a real run does.** It moves the map's other pieces into a dated backup and puts the new region under `World.Map.<MapChild>`. Then it fills the water and applies the texture-pack images.
  - Pieces listed in `KeepMapChildren` stay exactly where they are, with all their tags. That's how Lindenmoor's village stays when its expansion goes into Ye beside it, as `World.Map.LindenmoorExpansion`.
  - Backed-up pieces have their tags set aside, so the game no longer treats the old markers as live (old area names, for example).
  - If anything goes wrong partway, everything is put back as it was.
- **Restore.**
  - `restore.lua` puts the old map back, with its tags, water and texture settings.
  - It never deletes the imported map. That moves to its own backup, so anything you built in it after the import is kept.
  - `unstrip.lua` re-tags any piece you drag out of a backup.
- **Texture-pack images.** A material that names a pack image becomes a Roblox MaterialVariant. Your own variants with the same name are backed up and are never deleted.
- **Collision.** Region parts named Glass or Glow are walk-through. Kerbs, crates and walls stay solid; Lindenmoor and the train keep their own rules.
- **Lights:** furnace and tunnel lights stay on by day. Only street lamps follow the day and night.
- **Unchanged:** Lindenmoor's and the train's existing imports are byte-for-byte the same, and their stored outputs were regenerated once with today's tool.
- **Tests:**
  - the kit's own tests pass 47/47, and the region tests 156/156;
  - in Foundry: the dry run, five refusals that change nothing, a real import and restore, a forced error that rolls back, and a Ye-like layout with a kept "village". All left Foundry as it started.
- **Before the Lindenmoor import:**
  - Lindenmoor's water file needs converting to the new format;
  - the village, trains and hub pieces must be separate top-level map pieces in Ye.

### Discord announcement

Hold: not live yet. This is behind-the-scenes map tooling; there's nothing for players to see until the first new region ships.

## 2026-10-24 — Region Foundation Task 10b: ungrippable map edges

Your choice: "Ungrippable edges". The climb leap (Space+W) gains 12 studs for little stamina, so a base player can climb about 123 studs from a running jump, and a fully upgraded one about 207. No sensible wall height keeps them in. Instead, edge cliffs and walls keep their look, but carry a new tag, `RenseiNoGrip`, that nothing can grab. There are still no invisible walls. Built in Ye; backups are in `ServerStorage.RenseiBackups["Pre-RegionFoundation_2026-10-23"]` (`*_task10b`). Every number is a **PROPOSAL**.

- **Movement.** A part tagged `RenseiNoGrip`, or inside a model with the tag, can't be grabbed by any of these:
  - a climb;
  - a mid-air grab;
  - a climb leap;
  - moving along a climb (the wall ends where the tagged part starts);
  - a wall run;
  - the air wall-kick (S).

  You can still stand on it and bump into it. Climbing an ordinary wall up to a tagged part stops there; you vault onto the top if there is one, or drop. **Nothing changes on any untagged surface.** The server refuses a climb or wall run against a tagged wall too, so a modified client can't climb one.
- **No tagged parts exist in the live game yet.** The first ones come with the region imports. Lindenmoor's expansion cliff gets the tag when it's imported.
- **Region edges.**
  - Edge walls carry the tag. They stand 80 studs over the ground beside them, well over a running jump (about +16 to +19).
  - No building, landmark or tall prop stands within 26 studs of an edge wall. That's beyond a running jump's reach, so no roof can launch anyone over the top.
  - The Testbed's row district moved slightly to keep its 3 houses.
- **Also:** the repo copy of TuningConfig now matches Studio, picking up an earlier `Knockable = false` line for the sparring dummy.
- **Tests:**
  - A new Play_NoGrip test covers the tag check and the server's refusal (6/6).
  - On a real client, a mid-air grab caught a tagged wall before the change and never after; ordinary walls still grabbed.
  - Play_Boot passes, and so do the region builder checks (144/144 and 101/101).
  - The owner's save was restored and the test hook removed.
- **To publish:** the `Modules` package (JumpManager, MovementState, TuningConfig).

### Discord announcement

Hold: not live yet. No map edges use this until the first new region ships.

## 2026-10-24 — Region Foundation Task 10: the rail-town building kit

The region builder can now dress a region in the rail-town style (Foundry Yard's look: soot, iron, furnace brick, ember). It uses the same chunky, blocky parts as Lindenmoor. **Nothing changed in Studio.** Code: `Art/Blender/region_builder/kits/railtown.py`, `placement.py`, `stages.py`. Renders: `Documents/images/Regions/Kits/` and `Documents/images/Regions/Testbed/`. Every number, size and colour is a **PROPOSAL**.

- **Buildings:** brick terrace houses with slate roofs, chimneys and warm windows, a long boarding house, a corrugated shed, a brick warehouse with a loading dock, and a smokestack. Each stays under 150 parts, up to 4 storeys.
- **Landmarks:**
  - a walled practice court with benches;
  - the foundry hall: a sawtooth roof, glowing furnace mouths, and upper walkways reached by a stair and a bridge;
  - a crane bay with climbable legs and a walkable girder;
  - a raised iron rail walk on trestles;
  - an arched brick tunnel section (its use along underground routes still needs a design);
  - a canteen and a market stall.
- **Placing buildings:**
  - Districts fill their street frontage with buildings, more densely as the region file asks.
  - Buildings face the street, leave alleys at least 4 studs wide every 2–3 buildings, and keep 2 studs off roads and markers.
  - Each sits on its own plinth, with steps no higher than 1 stud.
  - Placement is exact and repeatable: the same file always builds the same town.
- **Cover:** crate stacks and machinery along quiet lanes and yards, and street lamps that light only at night.
- **Movement:** building ledges carry the ledge-walk tag the game already reads. Climbing and wall-running work on any surface, so nothing else needed tagging.
- **Edges:** sheer slag walls round the map, broken only where a road leaves (see Task 10b).
- **Fixes found in review:**
  - the foundry walkway rails blocked the stair and bridge;
  - the rail walk's deck floated;
  - a lintel flickered;
  - the crane's trolley blocked the girder;
  - the warehouse dock had no step.
- **Tests:** the Blender check passes 101/101 and the core tests 144/144. The Testbed is 809 of its 12,000-part budget.

### Discord announcement

Hold: not live yet. This is behind-the-scenes map tooling; there's nothing for players to see until the first new region ships.

## 2026-10-23 — Region Foundation Task 9: the builder makes ground, roads and markers in Blender

The region builder now builds a region's ground in Blender from its region file, ready for the later export to Studio. **Nothing changed in Studio.** The test region (Testbed) builds to 455 parts against a 12,000-part budget. Code: `Art/Blender/region_builder/` (`materials.py`, `stages.py`, `build.py`). Renders: `Documents/images/Regions/Testbed/`. Every number and colour below is a **PROPOSAL**.

- **Ground:** stepped ground in 1-stud steps, in 64 × 64-stud tiles, the same blocky style as Lindenmoor. Each tile has flat top slabs, side blocks down to the lowest neighbour (no gaps), and ramps where a road climbs gently.
- **Roads:** main roads are paved with kerbs, and quiet lanes are cinder. Where a road climbs more than 4 studs in 8, it gets stairs: one stud per step, sitting exactly on the ground steps. Rail routes get rails.
- **Markers:** townsfolk posts, clues, area names and the station and road pieces are invisible, non-colliding parts carrying the game's tags and settings. They travel to Studio in a new export column. Existing exports (Lindenmoor, the train) are byte-for-byte unchanged, and the Studio import kit now accepts a marker with no settings instead of failing.
- **Colours and textures:**
  - Each region gets its own materials from a rail-town palette (soot, iron, furnace brick, ember).
  - A material can name a texture from the owner's texture pack; Studio uses that image, and Blender shows the flat colour.
- **Water:** the builder records exactly the cells that are still under water, for Studio to fill with real water.
- **Safety:**
  - The builder starts from an empty Blender file and refuses to run over unsaved work.
  - It saves only its own region file and never touches the Lindenmoor files.
  - Saved region `.blend` files are now ignored by git.
- **Budget:** a region over its part budget is flagged, and must not be exported.
- **Renders:** an aerial and a street view per district and landmark.
- **Tests:** the Blender check passes 44/44 and the core tests 70/70.

### Discord announcement

Hold: not live yet. This is behind-the-scenes map tooling; there's nothing for players to see until the first new region ships.

## 2026-10-23 — Region Foundation Task 8: the region file and the map-builder core

The first piece of the tool that builds every region in Blender. Each region is now described by one file, `Art/Regions/<Region>/layout.json`, which gives:
- the region's size and colours;
- its heights: flat ground, raised blocks, ridges, cuts and water;
- its districts, roads, landmarks and markers (townsfolk posts, clues, area names, and the station and road pieces).

A plain-Python core reads that file and works out the stepped ground the game's maps use. **Nothing changed in Studio or Blender.** Code: `Art/Blender/region_builder/` (`schema.py`, `heightfield.py`, `merge.py`). Every number below is a **PROPOSAL**.

- **Checking the file.** The loader lists every problem in a region file at once, each with where it is: a missing size, a road with one point, a district outside the map, an unknown marker. Markers must use the names the game actually reads; the design spec's four older names are refused, so a wrong one can't import and silently do nothing. The spec now uses the game's names.
- **The ground.** Heights are worked out on a 4-stud grid in 1-stud steps, the same way Lindenmoor's ground was:
  - raised blocks blend down over their edge;
  - ridges fall away to the sides;
  - cuts sink;
  - water records its surface and bed.

  Each column reaches down past its lowest neighbour, so no gaps show. Roads and alleys mark their cells, and a road that climbs gets ramps.
- **Fewer parts.** Equal neighbouring cells merge into rectangles of up to 40 cells a side, as in Lindenmoor.
- **Water** is kept only where it stands above the ground. Later shapes can raise ground out of it, and no water is filled under it.
- **A Testbed region**: a small 256 × 256 test map with one of everything.
- **Speed:** a Foundry-size map (1,536 × 1,536 studs, 147,456 cells) takes about 5.4 seconds.
- **Plan fixes found on the way:**
  - The builder's folder is `region_builder/`, because a `regions/` folder would clash with the saved maps' `Regions/` folder on Windows.
  - The Testbed's dip no longer cuts the main road.
  - Its climbing road now runs down the slope.
- **Tests:** `python -I Art/Blender/region_builder/tests/run.py` passes 62/62. The Lindenmoor builder's own checks still pass 60/60.

### Discord announcement

Hold: not live yet. This is behind-the-scenes map tooling; there's nothing for players to see until the first new region ships.

## 2026-10-23 — Region Foundation Task 7: clues on the map can start quests

Region maps built in Blender can now carry clues: a spot on the map that you inspect, like the existing "Inspect" points. Inspecting one can also start a quest. Built in Ye. No map has clues yet; the first ones come with the region imports.

- **Clues.** Any part on the map marked as a clue gets the usual Inspect prompt. That works for parts already on the map when the server starts (how imported regions arrive) and for parts added later. One clue always has exactly one prompt.
- **Clues that start quests.** A clue can name a quest. Inspecting it starts that quest when all of these hold:
  - you found what the clue gives, or you'd found it before;
  - you meet the clue's requirements;
  - the quest itself can start: not already active, not done, and not on cooldown.

  If you already found what the clue gives, the new quest counts it at once. Inspecting a clue again doesn't restart a quest you're already on, and doesn't show a message. A locked clue, one whose requirements you don't meet, never starts its quest.
- **Fix:** the repo copy of the Halvard's Adit entrance's inspect wording was out of date and now matches the game (no change in Ye).
- **Tests:** a new Play_Clue test covers clues present at start and added later, the quest start, the locked and unmet-requirement cases, and the repeat inspect. Play_AditBoards and Play_Boot still pass.
- **To publish:** `RenseiServer` (InvestigationService) and `Modules` (Investigation).

### Discord announcement

Hold: not live yet. No map has clues yet; this post is written when the first region with clues ships.

## 2026-10-23 — Region Foundation Task 6b: townsfolk can be hurt

Your ask: "The townsfolk should be hittable and integrate the heat, rep system, morality, etc.", and when their health runs out, "Knocked, can be finished". Built in Ye. Ye still has no townsfolk roster, so **nobody new appears in Ye**: this shows once Foundry Yard's townsfolk arrive. Until then it runs in the tests. Every number and line below is a **PROPOSAL**.

- **Hitting a townsperson.** Townsfolk have 100 health and don't heal by themselves. Only players can hurt them; an enemy's swing or blast passes through a bystander, as enemies' attacks pass through each other. A melee hit, a fireball or any other attack that reaches one lands like a hit on an enemy. Before this, fireballs stopped on townsfolk without hitting them.
  - The one you hit cries out ("Leave me be!"), stops where it stands, and once the hit's stagger is over runs to a shelter. It picks the shelter farthest from you among the 3 nearest, so it runs away from you rather than past you.
  - Everyone else within 30 studs runs too, and about half of them shout for help ("Somebody stop them!").
  - They hide until 20 s after the last hit or fight sound nearby, then go back to their day.
- **What it costs you.**
  - **Assault** ("Struck a townsperson"; unchanged from before): Mercy -2, Order -2, Townsfolk standing -2, and 15 Heat where the law hears of it. It counts at most once per townsperson every 30 s. It now counts only for a hit that actually lands: a swing that was blocked, dodged or passed through is not assault.
  - **Murder** ("Killed a townsperson", new): Mercy -5 (the harshest so far), Order -5, Townsfolk standing -15, Authority standing -5, and 60 Heat (Wanted 2 at once) wherever there is law, State or Militia. It counts for the last player who hit, gripped or executed them in the 10 s before they died. Witnesses and word of mouth work as for every other deed: other townsfolk soon say "They say you killed a townsperson."
- **Knocked, and finished.** At 0 health a townsperson is knocked down like an enemy: you can grip them (B) or carry them (V), and the mobile Grip button shows for them too. Left alone for 30 s they get up with 30% health and run for shelter. Gripped and executed, they die; the body lies for 60 s, then is gone.
- **No rewards.** Hurting or killing townsfolk gives no EXP, money, combat training, codex entries, quest "defeat" progress or drops.
- **A newcomer takes the job.** At the next 06:00 game time, every townsperson who died is replaced by someone new: same job, place, hours and nation, a new face and a new name (8 names per nation, never one already walking about in the town). Nobody sees them appear: while a player is within 60 studs of the spot, the newcomer arrives a moment after everyone has gone. They greet you like anyone else would; your deed stands.
- **Walking and fighting.** A townsperson who is hit, knocked, gripped or carried while walking no longer keeps steering or turning: the walk stops or waits, so knockbacks and knockdowns play out properly. A townsperson who dies while walking now lies where they fell instead of being moved to their post, and a townsperson whose walk broke is no longer placed at their post while a player is within 60 studs; they walk on instead.
- **Tests:** a new test suite covers each of the above (hits, assault, fleeing and calling for help, knock and recovery, execution and murder with a witness and Heat, no rewards, the newcomer at 06:00, gossip, and one swing hitting a townsperson and a bandit together). The townsfolk, crowd, Heat, morality, rumour, stealth, assault and station suites still pass.
- **To publish (at a checkpoint the controller names):** the `RenseiServer` package (TownsfolkService and its Mover, HeatService, ProgressionService, WorldService, AlchemyService) and the `Modules` package (DamageManager, DownedManager, MobileControls, Deeds, TownsfolkLogic).

### Discord announcement

Hold: not live yet. Townsfolk aren't in the live game yet; this post is written when they ship.

## 2026-10-23 — Closed-test fixes (afternoon and evening)

Fixes made during the weekend closed test, each tested in Ye and published by the owner.

- **Alchemy:** every move with a range reaches 50% further (PROPOSAL), including enemy alchemists. While locked on, casts aim at the target's body. Fireball, Air Slash and Metal Bind track a target that moves during the windup.
- **Weapons:**
  - The air heavy after an uppercut now hits in mid-air and slams the target down.
  - The rapier skill's hits land on its animation.
  - The katana skill and crit use published animations (Iaido Barrage, Quick Draw).
  - Multi-hit timing no longer drifts late.
- **Grips:** unarmed grips always use the grip animation. B right after the knockdown no longer gets ignored. Climbing hand effects no longer stick to the arm.
- **Leaderboard:** the scroll bar moves and drags, long names end in "…", and the player card hides off-screen.
- **Players stuck unable to attack:** a long combo ending in a wall knockback or a downslam left an endless stun. A 0-second stun is no longer started.
- **Health regen:** none while in combat. It resumes at 1% of max health per second, 2 s after combat ends (PROPOSAL).
- **Travel:**
  - A failed journey's kick message now shows Roblox's reason. That's how the "not published" cause was found: Foundry Yard had to be published once.
  - A live countdown to your train's departure shows once you hold a ticket.
- **Greatsword:** it sits centred on the back, on a steeper diagonal, with the handle over the right shoulder. Screenshots: `images/Fixes/Greatsword back - *.jpg`.

### Discord announcement

```md
**Closed Test Patch Notes: Oct 23**

**Combat**
- Alchemy reaches 50% further, and when you're locked on your casts now aim at your target. Fireball, Air Slash and Metal Bind follow a target that moves.
- The air heavy after an uppercut now hits in mid-air and slams your opponent down.
- Rapier skill hits now line up with its animation.
- The katana skill and crit now play their proper animations.
- Multi-hit attacks no longer land late.
- Fixed players getting stuck unable to attack after being knocked into a wall or slammed down.

**Health**
- No more healing mid-fight. Your health starts coming back 2 seconds after combat ends.

**Grips**
- Unarmed grips always play the grip animation, and pressing B right after a knockdown now works.
- Climbing hand effects no longer stick to your arm.

**Travel**
- Once you hold a train ticket, a live countdown shows how long until your train leaves.
- If a journey fails, the message now tells you why.

**Other**
- The leaderboard scrolls properly, and long names are shortened.
- The greatsword now sits centred on your back.
```

## 2026-10-23 — Region Foundation Tasks 3-6: townsfolk who keep to their day, walk through crowds, run from fights and talk

Towns get ordinary people: each one has a job, a place to be at each hour, and something to say. Built in Ye. Ye has no townsfolk roster yet, so **nobody new appears in Ye**: the first real townsfolk come with Foundry Yard's roster (the Foundry plan). Until then everything below runs in the tests. Backups are in `ServerStorage.RenseiBackups["Pre-RegionFoundation_2026-10-23"]`. Every number and every line of speech is a **PROPOSAL**.

- **Townsfolk talk (Task 6).** Your choice: their words appear in a speech bubble over their head, in the Special Elite typewriter font, with no reply choices. The bubble is the dialogue's own choice plate, stretched to fit the text. It fades in and out and is replaced when they say something new. Walk up and press **Talk**. Each time you talk to the same person they say the next thing:
  - a greeting that depends on your standing with their faction in this region (Hostile to Honoured);
  - a rumour from around town that you haven't heard from them yet (skipped when there isn't one);
  - what they do for a living;
  - then the greeting again.

  If you're at the right step of a quest they know something about, they give you that clue first. Rumours and clues are said to you alone: other players nearby see greetings, job lines and remarks, but not those. Talking to them also counts for "talk to" quest steps. They also speak up on their own:
  - a passing remark when you first come near (at most once every 5 minutes each);
  - sometimes a word when they set off for their next place;
  - a shout when they run from a fight;
  - a remark when they come back.
- **Rumours (Tasks 3 and 6).** What a town is talking about is what has happened there, plus word of your deeds that has travelled in from elsewhere: "They say someone struck a townsperson." The newest comes first, and each story is told once. Your rule: "Name if known, else 'someone'": they use the person's name once you've identified them, otherwise "someone" (never a journal number like "Subject 03"). If it was you: "They say you ...". Where you were born is never gossip.
- **Fights (Task 6).** A fight nearby (a hit, an alchemy cast or a gunshot within earshot plus 20 studs) sends townsfolk running to the nearest shelter that nobody else has taken. They run at a player's walking speed, don't give way to anyone, and curl up there. With no shelter nearby they curl up where they stand. 20 seconds after the last sound of fighting they walk back to wherever their day has them. You can't talk to them while they're running or hiding. They can't be hurt yet: that's the next task, 6b.
- **Their day (Tasks 4 and 5).** Each townsperson has a schedule of places by the hour (work, a seat, a counter, home), checked when the town loads: a gap in the day, a missing place, two people sharing one spot, an empty or broken time slot, or an unknown nation or faction refuses the whole roster with a clear message. They wear their own nation's clothes (owner: "Townsfolk should have their nation's clothing on"). When nobody is near they're held still at their place, which costs nothing. They're witnesses for the stealth and crime systems.
- **Walking through crowds (Task 5b).** Owner: "I don't want them to walk through each other." They follow smoothed paths that prefer streets, step around each other and around players (passing on the right), queue at doors and give way there, back out of narrow alleys, wait for a taken spot, re-plan round new obstacles, and turn smoothly with a walk that matches their speed. Someone running from a fight has right of way: anyone in their path steps aside at once. In the doorway test the runner goes through first without ever stopping (38 studs in about 3.4 s).
- **Tests (Ye; one Play session, after every fix):**
  - Play_Boot 2/2, Play_Rumours 3/3, Play_Townsfolk 12/12 (twice), Play_TownsfolkCrowd 13/13, Play_Stealth 9/9, Play_Heat 8/8, Play_Morality 3/3;
  - Test_TownsfolkLogic 7/7 (Edit);
  - the new talk, fleeing and rumour tests failed before the change;
  - checked in a Play client: the bubble appears over the head in Special Elite with the right text, grows to four lines for a long rumour, and is gone after its time.
  - The owner's save was restored after every Play session and the test hook removed.
- **For the owner:**
  - **look at a bubble in Play once** (the test tool's screenshots can't show bubbles);
  - publish `RenseiServer`, `Modules` and `Remotes` from Ye (Remotes has a new `TownsfolkSay`);
  - the new `TownsfolkClient` script in `StarterPlayer.StarterPlayerScripts` is plain (not a package): Foundry Yard gets its copy with the Foundry plan.

## 2026-10-23 — Lindenmoor expansion in Blender (owner-approved layout; not in Studio yet)

Lindenmoor is planned and built in Blender at its full 2,048 × 2,048 footprint, around the finished village. It follows page 3 of the Regional Map Design Brief. **Nothing changed in Ye**: the import waits until the hub graybox has moved out (the owner's choice: "Plan as if it's gone") and is coordinated by the main session. Design: `Documents/specs/2026-10-23-lindenmoor-expansion-design.md`. What was built, the renders and the import steps are in `Documents/Lindenmoor Kit.md`, "Expansion (Blender)". Every number is a **PROPOSAL**.

- **The new land:**
  - farmsteads, a market and a watermill in the south-west;
  - the mine approach above Halvard's Adit;
  - Mill Creek's gorge with a second ledge walk, a footbridge, the lookout and a waterfall;
  - Bramble woods;
  - the training field and the ridge marker;
  - patchwork fields, orchards and hay barns;
  - the Cypress Ridge rim with three overlooks;
  - the north road and the rails side by side to tunnel portals in a north-east gap (the owner's choice: "Together, NE corner").
- **Edges:** natural edges with no invisible walls. The forested ridges end in a sheer crag that's too tall to climb out of.
- **Size:** 40,414 parts (expansion ceiling 42,000; place ceiling 80,000).
- **Owner, after the build:** "Start importing after the townspeople tasks are done", with the region-foundation import tools (Tasks 9, 11 and 12). The hub's trainers and trial sites move into the new map onto reserved spots, so their questlines keep working.
- **Orientation finding:** the brief reads correctly with drawing-down = +Z (Ye's north). The region-builds spec's "drawing top = +Z" rule is mirrored for Ye.
- **Files:**
  - `Art/Regions/Lindenmoor/layout.json` and `water.json`;
  - `Art/Blender/lindenmoor/expansion_plan.py` (pure), `expansion_tests.py` and `expansion.py`;
  - the renders in `Documents/images/Regions/Lindenmoor/`.
- **Tests:** `python -I Art/Blender/lindenmoor/expansion_tests.py` passes 60/60.

## 2026-10-23 — Region Foundation Task 2: a day and night: 24 minutes, the same time in every place

The time of day now moves. One real minute is one game hour, so a full day takes 24 real minutes (**PROPOSAL**). The hour comes from the real clock, so every place and every server shows the same time: if it is evening in Lindenmoor it is evening in Foundry Yard too. Built in Ye. Backups are in `ServerStorage.RenseiBackups["Pre-RegionFoundation_2026-10-23"]`.

- **Night is from 18:00 to 06:00** (**PROPOSAL**). Lindenmoor's 17 street lamps now light only at night; the house door lanterns and the camp fire stay lit all the time. By day each lamp head also loses its glow (it turns to plain SmoothPlastic, **PROPOSAL**: you may pick another material) and gets its own glowing material back at night.
- **What else notices the time.** Nothing else was changed, but three things already read the hour and now see it move:
  - how lit you are, so at night enemies **and the crime-watching agents** (the ones who report casting and assault for Heat) see you much less;
  - the road's night ambushes.

  "Night" is not one hour for all of them yet: the lamps come on at 18:00, the road's ambush bonus starts after 19:00, and stealth is darkest from 20:00 (daylight fades from 17:00 and is gone by 20:00, back from 06:00 to 09:00).
- **The admin panel's Time box** (its hint now reads "0 - 24 or run") holds the clock at the hour you type until released. Type `run` in the same box to let it follow real time again.
- **For later tasks:** `WorldClock.Now()` gives the hour the world shows, and `WorldClock.Changed` fires each new hour. The townsfolk schedules will use them. The night lamps are kept in a list, so switching them never searches the whole map (0.2-0.3 ms in Ye).
- **Tests (Ye):**
  - new `Play_Clock`: the hour follows real time, holding and releasing, NightOnly lamps off by day and on at night (and not glowing by day), what counts as night, and `Now()` while held and running. It failed before `WorldClock` existed and passes 5/5 now;
  - `Play_Perception` and `Play_Heat` assumed it was always daytime. With the old version held at 23:00, Play_Perception failed 2 of 6 (the Grunt barely noticed the tester). Each of their tests now runs in full light, as Play_Stealth already did. In a fresh Play session they pass 6/6 and 8/8 at 23:00, at 13:00 and at 23:00 again;
  - Play_Stealth 9/9 and Play_Road 11/11 pass;
  - by hand: held at 23:00, the sky is dark and the square's lamps are lit (`Documents/images/World Clock/Lindenmoor at 23h.jpg`); held at 13:00, all 17 lamps are off and none of their heads glow (`Lindenmoor at 13h.jpg`).
  - The owner's save was restored after each Play session, and the test hook was removed.
- **For the owner:**
  - publish `RenseiServer` and the `Modules` package from Ye, then update them in Foundry by hand;
  - the other places only get the clock once their copy of `RenseiServer` is updated;
  - to go dark by day, their street lamps need `NightOnly` set on the lamp part.

## 2026-10-23 — Region Foundation Task 1: the trainers' exams open

Choosing "I'm ready for the examination." with any of the five alchemy trainers (Calda, Veyra, Holt, Ansel, Brannoc) did nothing: the exam panel never appeared, so nobody could finish an acquisition questline at Act V. Fixed in Ye. Backups are in `ServerStorage.RenseiBackups["Pre-RegionFoundation_2026-10-23"]`.

- **Why it broke.** The exam opened while the conversation was still on screen. The game never opens a menu over a conversation (a rule from 2026-10-18), so the exam panel shut at once and the server quietly cancelled the exam. Checked in a real Play client before the fix: the client got the exam while the dialogue box was showing, sent "Close" straight back, and the exam ended.
- **The fix.** The exam choice now closes the conversation first and then opens the exam, as the trainers' Lesson and Exercise choices already did. The two Combat Read drill choices go the same way, which changes nothing you can see.
- **For tests:** two small read-only helpers, `DialogueService.IsOpen(Player)` and `MinigameService.Current(Player)`.
- **Tests (Ye):**
  - new `Play_Exams`: for each of the five exams it puts the quest at stage 5, opens the trainer's conversation, takes the exam choice the way the game does, and checks that the conversation was closed before the exam opened and that the exam is still running 1.5 seconds later. It passed none of the five before the fix and all five after it, twice;
  - Play_Boot 2/2, Play_Arrive 5/5 and Play_Morality 3/3 still pass;
  - by hand: talked to Calda at the exam stage and pressed 1. The exam panel ("The Unburned Lesson") opens (screenshot: `Documents/images/Fixes/Trainer exam opens.jpg`).
  - The owner's save was restored after each Play session, and the test hook was removed.
- **For the owner:** publish `RenseiServer` from Ye, then update it in Foundry by hand.

## 2026-10-23 — World Plan 1 final fix wave: the whole-branch review's fixes

The final review of World Plan 1 found problems where two tasks meet. This pass fixes them in Ye (and, for the teleport copies, in the Main Menu and the Tutorial). Every number is a **PROPOSAL**. Backups are in `ServerStorage.RenseiBackups["Pre-FinalFix_2026-10-23"]` in each place touched.

- **A ticket holder who stows away keeps the ticket** (ledger ruling, now built). A Wanted player without papers who hides in the baggage car still rides as a stowaway, but the inspector catches them for the papers, not the fare:
  - +5 State Heat and the line "A ticket, but hiding with the baggage? Your papers will be reported.";
  - no fine, and never thrown off;
  - the ticket is **not** used on arrival (`TravelService.Depart` has a new `NoTicket` option, so their trip records no class).

  Before this, they paid the $45 fine, could be thrown off, and lost the ticket on arrival too.
- **Nobody boards held.** The train now works like the road:
  - anyone knocked down, gripped, carried, gripping or carrying isn't taken aboard. The conductor says why;
  - the server checks again after the "doors closing" fade, so going down in the fade leaves you on the platform with your ticket;
  - when a ride ends, anyone in the moving train who isn't riding it (such as a carried non-rider) is put back on the platform.

  Before this, the train was a way to escape a grip, and a carried player could be stranded in the moving train.
- **A stalled train teleport has a watchdog** (tested by calling it directly; the live trigger is untested until published), as the road has. 25 seconds after the send, a rider still here goes back to the platform if their save is still loaded, or is kicked if it was released. Nobody plays on a released save.
- **Ye's hub keeps State law** (owner: "Keep State law"). Outside every named area, Ye counts as the City again, as before Task 10, so unlicensed casting in the hub is a State crime again. This is a one-entry table in `Rensei.Regions` (`HubLaw`: Ye's place id → City). Ye is still Lindenmoor everywhere else: its named areas, the station, rumours by rail and your saved region. Other region places still use their own region.
- **Players who arrive before the server is ready get their skills.** `CharacterHandler` now also sets up players (and characters) already in the server when it starts. A group teleport opens a fresh server, so this can happen. (Untested: Studio never starts a player before the handler, so this branch has not run yet.)
- **Smaller fixes from the review:**
  - the conductor's "Papers first" line comes once per boarding, not every 3 seconds. A Wanted 3+ player hears "Your papers won't pass here." instead of being sent to a guard who would refuse them;
  - a rider who dies just before the train arrives isn't sent on, and a body that died during the fade isn't moved into the train;
  - each travel service starts on its own, so one that fails can't stop the others;
  - an arrival no longer waits forever for a player who left before spawning.
- **Menu and Tutorial checked after the Studio crash.** The Menu's "resume where you were" edit, and both places' `Places` and the Tutorial's hair fix, were intact and match Ye and the repo. Both places' own `FlowTeleport` copies were old, so they were updated to the current one; they only use `Send`, which is unchanged.
- **Docs:** `World Travel.md` corrected: the stowaway ruling, "one server" marked as designed but untested until published, Menu and Tutorial's own teleport copies, the signed gateway, Ye's hub law, and the owner's publish steps.
- **Tests (Ye):**
  - Play: Boot 2/2, Travel 7/7, Station 20/20, Road 11/11, Gate 13/13, RideEvents 9/9, Arrive 5/5, Heat 8/8, Morality 3/3, Stealth 9/9, all on the first run;
  - Test_Regions 6/6, Test_Reputation 10/10, Test_Heat 6/6 and Test_RumourCore 10/10 in a fresh game VM. Test_Regions also passes 6/6 in Edit against fresh modules.
  - New tests: in `Play_Gate`, a ticket holder's inspection and a full ticket-holder stowaway ride; in `Play_Station`, held players don't board, knocked in the fade stays behind, the ride-end sweep, and the stalled-teleport watchdog. `Play_Station` now puts aside any ticket the tester's save holds for each test, as `Play_Gate` does.
  - The owner's save was restored after the Play session, and the test hook was removed.
- **For the owner:** publish `RenseiServer` and `Modules` from Ye, then update both packages (and `ClientHandler`) in Foundry by hand. Then publish Ye, Foundry Yard, the Main Menu and the Tutorial, and use **Migrate to Latest Update** for Ye. Before testing live, check your own save for leftover test state. `World Travel.md` §10 has the steps.
- **Not done here:** two small client-side timing fixes (the rail fade lifting early, and the crossing failsafe being shorter than the server's deadline) are left for the next `TravelClient` change. Foundry now has the newer test suites, but they have only been run in Ye.
- **Rulings left for later** (the review's last minor notes, accepted for now):
  - the train's 25-second watchdog can cut off a slow third teleport try. The ticket is kept, and the road makes the same trade-off;
  - inside `StationService.Depart`, a local table shares the name of a helper function. It's harmless today; rename it in the next station change;
  - a failed group teleport's kick message says "Your ticket is still valid" even to a stowaway with no ticket. This was already there before; fix it with the next `TravelService` change;
  - the "Papers first" and "Your papers won't pass here" lines share one 35-second gap, so the second can be late. Cosmetic.

## 2026-10-23 — World Plan 1 complete (Task 11: Foundry end to end, the World Travel guide)

**Owner:** "I want the full map to be so big you have to use the train, etc. to TP to the place. I want it to really feel like a real RPG experience where all the systems connect together with the map to make something super immersive and breathtaking."

### Task 11
- **Foundry's ticket booth moved outside the gate.** Task 9's railing had left it on the platform, behind the checkpoint, where a Wanted player couldn't reach the clerk. It now stands in the open ground below the platform (x 16, z 36, PROPOSAL), with its window facing the way in.
  - `station_foundry.lua` was re-run in Foundry. Every other part was checked against a backup and is unmoved (4,264 parts), with the same tags.
  - Checked in Play:
    - the clerk prompt is in reach and in sight from in front of the booth (3.4 studs), but not from the platform (13.6 studs, behind the booth's back wall);
    - a player walks from the booth up the ramp and through the gate onto the platform.
  - Backup: `RenseiBackups["Pre-Task11_2026-10-23"]` in Foundry. Its tags were removed so nothing in the game sees the copy.
- **The whole travel system passes in Foundry Yard.** Foundry's `ServerStorage.RenseiTests` now holds TestKit and the seven travel suites. Results, in both Foundry and Ye: Boot 2/2, Travel 7/7, Station 16/16, Road 11/11, Gate 11/11, RideEvents 9/9, Arrive 5/5.
- **The suites now run in any place.** Three needed changes, made once in the repo and copied into both places:
  - `Play_Road`: Foundry's South Road is Lindenmoor's North Road turned a quarter, so the test's fixed spots are mapped onto whichever road the place has, and the place names come from the place itself;
  - `Play_Station`: the "sitting through the wall" test stands on Foundry's platform edge (Foundry has no edge strip);
  - `Play_Arrive`: the "quest taken elsewhere" test pretends to be in a third region (in Foundry it was pretending to be in the Foundry).
- **The World Travel guide:** `Documents/World Travel.md`. It covers what players see, prices, the papers check, roads, the save handover, the Studio loopback, where everything lives, and your next steps. Screenshots are in `Documents/images/World Travel/`.
- **Tooling:** `Art/Studio/Travel/test_hook.lua` now matches the hook every test used. There is a new tooling note in `Lindenmoor Kit.md`.
- The owner's save was snapshotted and restored in both places, and both hooks were removed.

### World Plan 1: what was built (Tasks 1–11, 2026-10-20 to 2026-10-23)
- **The train:** built in Blender (locomotive, tender and five cars) and imported into Studio.
- **Shared code:** the server code is in the `RenseiServer` package and the data in `Modules`, so every region place runs the same code.
- **Stations:**
  - tickets by class;
  - a departure clock every server agrees on;
  - seats you choose;
  - a 50-second ride with one event;
  - one group teleport with the save handed over safely.
- **Roads you walk,** with a seamless crossing and ambushes.
- **The papers check and the stowaway route.**
- **Rumours by rail,** four new regions, arrival quests and party tickets.
- **Two places:** Lindenmoor (Ye) and a placeholder Foundry Yard, both with a station and a road.

**Stand-ins and adaptations:**
- **No arrest yet:** a Wanted 3+ player is refused at the gate, with +10 State Heat, instead of the spec's arrest.
- **EnemyService:** `EnemyService.Spawn` takes a spawn part, not a type and a position. Train and road bandits are spawned from an unparented marker part (`EnemyType = "Grunt"`, shown as "Bandit"), so a killed bandit never respawns.
- **Region test numbers** changed with the four new regions, because global standing averages over more regions:
  - Authority, for a one-place deed: 24 → 8;
  - Circle: −8 → −16/3;
  - the rumour tests now expect the train.

**Rulings made during the plan** (the controller's, from the plan log; the ones marked † are on the owner's list to confirm):
- Work went straight onto the docs repo's main branch and into Ye, with no worktree, and the changelog was kept up to date.
- The plan's agents ran on Opus, as the owner asked.
- Server scripts keep their old ServerScriptService paths at runtime, because RenseiBoot copies them in from RenseiServer. So hooks that use those paths needed no change.
- The trains sit on the measured rail top (local Y 5.2 in Ye), not the brief's 4.9.
- When moving server code into RenseiServer broke three test suites' paths, the suites were fixed and the move was kept.
- The profile test hook only runs in Studio, so it can never touch live player data. (Corrected 2026-10-23: it no longer ships in a Package. It is put into ServerScriptService for a Studio test session and removed afterwards.)
- Play suites run in the game's own VM (through `LMRunSuite`), never from the tool's sandbox, which sees no loaded saves.
- The controller, not a subagent, updated the Menu and Tutorial copies of FlowTeleport.
- Arrival trusts only a trip record the server writes into the save before the teleport, never the teleport data. A join to the wrong place is sent where the save says (live only).
- The first TravelService fix round also:
  - releases only the players actually sent;
  - burns exactly the class ridden;
  - labels every PROPOSAL.

  A stalled-teleport watchdog and the north gate's height were left for later.
- Everything in Foundry is built by `station_foundry.lua`. Nothing is added there by hand.
- Someone in a car their ticket doesn't allow when the train leaves is moved to the nearest allowed car. The departure also re-checks who is aboard at the moment of the move, skips a hitch, sends gifts by UserId, and kicks (live) if the teleport fails after the save was handed over.
- A second fix round closed the class barrier for good.
- † Dying aboard drops you from the ride. You come to back in town with your ticket still good, and you're never pulled back into the train.
- Task 8's road trips:
  - held the party safely for the trip time;
  - rolled the ambush partway along;
  - turned a second party away from a busy arena;
  - had their arena moved outside the gate.

  Task 8b later replaced all of this with roads you walk.
- A party that flees an ambush may split (consistent with the spec), and the teleport-screen failsafe was left for later.
- The ticket window was rebuilt in the game's own dialogue box: the clerk says the line, and the classes and "Ticket for" are the choices.
- † The full-screen black ride fade stays a plain black frame. It is a transition, not a UI panel.
- The server only seats you in the car you're standing in. A seat is freed on death or leaving, anyone in the wrong class is stood up, and nobody sits down during the fade.
- The ticket window has no number-key picking. It closes on death, when you walk away from the clerk, or when a real dialogue opens, and it fits any screen.
- † A 0.8 s slide cooldown (PROPOSAL) stops slide-chaining. A single slide feels the same.
- A road crossing counts only if you walked the road's stretches in order. There is one ambush roll per crossing; on a hit, the bandits wait at a random spot ahead.
- The road's trees and rocks still block enemy sight (only their touch events are off), so stealth works there.
- A rider thrown off by the inspector ends the ride back on the platform they left from.
- Stowaways caught by the inspector gain State Heat (+5, PROPOSAL). The freight yard has a watchman whose sighting adds +5 State Heat, once per visit.
- The gate tests set aside any ticket the tester holds for the test route and give it back afterwards.
- A road walk can't start where the stretches overlap at a bend. A bandit chased off its stretch gives up and walks home.
- Joining the road from the fields beside its first stretch still counts as walking it.
- Papers are checked again at boarding, and a railing closes the platform's back edge.
- Footsteps count: the yard watchman turns toward a noise, and any of his senses can notice you.
- The yard watchman and the gate guard are lawmen (Authority witnesses), and the yard's zone stops at the fence.
- Smaller Task 9 fixes:
  - being let off clears the thrown-off mark;
  - the stowaway lines were reworded;
  - the stowaway-spot cache no longer holds on to removed trains.
- A ticket holder without papers who rides hidden with the baggage gains Heat instead of the fine, and keeps the ticket.
- Foundry's ticket booth had to move outside the gate (done in Task 11).
- Old saves keep their reputation with the new regions: a one-time step on join spreads old deeds into them.
- That step works faction by faction, so a faction that heard a deed everywhere it lived keeps its full standing.
- The controller pushes Task 11's commit and republishes the status page after the final review.

**For the owner:**
1. Publish, then ride Lindenmoor → Foundry with 2+ players and check that everyone lands on one server.
2. Rejoin and check that you come back in the Foundry.
3. Confirm the † rulings above.

## 2026-10-23 — World Plan 1, Task 10: the regions join the world's word-of-mouth

- **New regions:** Aerugo Borderlands, Ishval, the Northern Wall and the Corrupted Lands are now on the rumour map, with their factions and law (PROPOSAL).
- **Word rides the rails:** news travels by train between Lindenmoor, the Foundry, the City and Ishval in 3–4 minutes (PROPOSAL). A big rumour can now reach about 11 places.
- **Each place knows where it is:** a deed done outside every named area counts in the place's own region. In Ye that was now Lindenmoor (Militia law), not the City (State law). So, for example, unlicensed casting in Ye's hub was no longer a State crime. **Undone for Ye's hub in the final fix wave** (owner, 2026-10-23: "Keep State law"): Ye's hub is the City under State law again; the other region places keep their own region.
- **Arrival quests:** a quest goal can be "arrive in X". It completes when you arrive, or at once if you're already there when the quest or its stage begins.
- **Party tickets:** the ticket window's "Ticket for" choice cycles through your party (it used to cycle every player, and the server refused non-members). If a party member's save isn't loaded, the clerk refuses before charging; a ticket that still fails is refunded.
- **Old saves keep their standing:** global standing averages over the regions a faction lives in, and some factions now live in more of them. A one-time step on join spreads old deeds into the new regions wherever a faction had already heard them everywhere it lived, so no player's standing moves. Tested on old-shaped saves (an Ishvalan birth stays Trusted; a City-only Authority deed keeps its full weight).
- **Changed test numbers** (each follows from the new regions): Authority global standing 24 → 8 and Circle −8 → −16/3 for a one-place deed; rumour tests now expect the train.
- **Tests:** Edit — Regions, Reputation, Schema5, RumourCore, Heat, Travel, Perception, Witness, Sound, TestKit all pass. Play — Arrive 5/5, Travel, Station, Gate, Road, RideEvents, Rumours, Morality, Heat, Stealth, Boot all pass. `Play_Rumours` fails if run straight after `Play_Morality` (an old test-order issue).
- **For the owner:** publish the `ReplicatedStorage.Modules` package (Regions, Reputation, Quests) and `RenseiServer` (TravelService, StationService, QuestService, MoralityService), then update both packages in Foundry. TravelClient is already copied into Foundry.

## 2026-10-23 — World Plan 1, Task 9: the papers check and the stowaway route

- **The gate:** a turnstile and a guard stand between the ticket hall and the platform.
  - Not Wanted: walk through.
  - Wanted 1–2: the guard stops you in the game's dialogue box with "Pay $X" or "Get searched". Either clears you for 10 minutes.
  - Wanted 3+: refused, with +10 State Heat (resisting a checkpoint) and the guard's line "Your face is on a poster. Not on my platform." There is no arrest system yet, so refusal stands in for one.
- **Papers are checked at boarding too:** the server won't board a ticket holder whose papers aren't in order, however they reached the platform. The conductor says "Papers first — see the gate guard." A kit-fence railing now runs along the back and ends of the platform.
- **Stowaways:** a freight-yard path with crates and a fence leads to the baggage car's open side door. Hiding there gets you aboard without a ticket.
  - A yard watchman uses the game's sight, light and sound rules: crouch in the shadows and stay quiet. If he sees you in the yard: +5 State Heat (PROPOSAL), once per visit. Noise makes him turn to look.
  - The ticket inspector fines stowaways and adds +5 State Heat (PROPOSAL).
- **Thrown off:** a rider who can't pay the inspector's fine ends the ride back on the departure platform.
- **The guards are lawmen:** both report crimes they see. Hitting one counts as assaulting a townsperson.
- **Fixed along the way:** the list of stowaways was being lost between the station and the ride events (Roblox drops player keys from event tables), so the inspector never saw them.
- **Tests:** Gate 11/11, Road 11/11, Travel 7/7, Station 16/16, RideEvents 9/9, Boot 2/2. Stealth's `GunshotPullsTheCamp` is flaky: it sometimes picks a bandit behind a tent.
- **Screenshots:** `Documents/images/Map Concept/Station Gate - *.png`.
- **Foundry:** the station is rebuilt there and TravelClient re-synced. Its ticket booth currently sits behind the gate; Task 11 moves it.
- **For the owner:** publish the `RenseiServer` package (StationService, RideEvents).

## 2026-10-23 — World Plan 1, Task 8b: roads you walk, with a seamless crossing

**Owner:** "the 'On the road' option should be a free roam type of RPG thing, where the passageway (or road) they are on TP's them to the outside area of the next place ... Sort of like a seemless cutscene". The train is the fast travel; roads are walked.

- **The roads:** Lindenmoor's North Road branches east off the hub road, and Foundry's South Road runs 382 studs out of the gate. Both are built in the part-ground style, about 1,050 parts each. Task 8's road card, journey screen, ambush arena and road prompt are gone (backed up in `RenseiBackups["Pre-RoadsOnFoot_2026-10-21"]`).
- **The crossing:** walk to the far end and the game takes over for a moment. You keep walking (still sprinting if you were), the screen dims, and you arrive walking in at the next place's outside area. Party members within about 40 studs who also walked the road come along.
- **No shortcuts:** the server tracks that you walked the road's stretches in order. Teleporting in, starting partway along, or a lag spike can't trigger a crossing. You can still join the road from the fields beside its first stretch.
- **Ambushes:** one roll per crossing. On a hit, bandits wait at a random spot ahead of you. Bandits that chase too far off the road give up and walk home.
- **Tests:** Road 11/11, Stealth 9/9, Travel 7/7, Station 16/16, RideEvents 9/9, Boot 2/2.
- **Code:** `Art/Studio/Travel/src/` (RoadService, TravelClient, TravelService, FlowTeleport, Play_Road) and the two station scripts.
- **For the owner:** publish the `RenseiServer` package so Foundry gets the new RoadService. Foundry's road and TravelClient are already in place.

## 2026-10-22 — The slide flows into a sprint

**Owner:** "if a player is running and slides, they continue running if they are holding the sprint key or has auto run on". The owner tried it: "I like the slide into the sprint".

- **Sprint carries through:** with sprint held, Auto Sprint on, the mobile run toggle on, or sprint pressed during the slide, you come out of a slide already sprinting. There's no walking frame in between; the sampled speed stays at sprint speed the whole way. Otherwise you stand up into a walk, as before.
- **Slide cooldown:** a new 0.8 s cooldown (PROPOSAL) between slides stops slide-chaining, which had reached about 51 studs/s against a 30.7 sprint. It's now about 36. A single slide feels exactly the same.
- **Respawn fix:** a sprint or slide no longer survives death, so sprint and Auto Sprint work straight after respawning.
- **Owner decisions:**
  - With a weapon owned but holstered, every sprint skips the 24-speed run phase and goes straight to 30. This bug existed before; the fix is one line but changes the feel.
  - Should a press during the slide cooldown be buffered?
- **Code:** `Art/Studio/Movement/`. Backups are in `RenseiBackups["Pre-SlideSprint_2026-10-21"]`.
- **For the owner:** publish the ClientHandler package.

## 2026-10-21 — Train seats you choose, and UI from the game's own art

**Owner:** "for the train seats, I want the players to have the OPTION to sit on them with a prompt on each seat"; "whenever you make any UI, ONLY use existing UI assets to create them. Fix the detection UI, conductor prompt ui, and ticket UI."

- **Seats (Task 6b):**
  - Brushing past a seat no longer sits you down. Each of the 128 seats (64 per train) has a "Sit" prompt in the game's prompt style.
  - Only the nearest seat shows its prompt. You have to be inside that car, and your ticket must reach it.
  - Jump to stand up.
  - Dying while seated frees the seat.
  - Seats carry over into the ride train as before.
  - Tests: Station 16/16.
- **Ticket window:** rebuilt as the game's dialogue box. The clerk asks "Tickets to the Foundry Yard. Which class?", and the choices are who the ticket is for, each class with its price, and "Never mind". It's animated, has phone-sized buttons, and closes with Esc, when another menu or a real conversation opens, when you walk away from the clerk, or when you die.
- **Prompts:** the clerk and road prompts now use the game's own prompt art (PromptUI).
- **Detection indicator:** now the hotbar slot plate with the transmutation circle, in place of the drawn eye. Light, crouch and sound still show.
- **Train messages:** now the game's toasts.
- **Departure board and train teleport screen:** use existing art.
- **Screenshots:** `Documents/images/UI/`.
- **Ruling to confirm:** the full-screen black fade during the train ride stays a plain fade (the intro cutscene does the same). It's a transition, not a panel.
- **For the owner:** publish `RenseiServer` and `ReplicatedStorage.Modules` (StealthUI). TravelClient is copied into Foundry.

## 2026-10-21 — World Plan 1, Task 8: road journeys and ambushes

- **Road exits:**
  - **Lindenmoor:** the north road, under a stone gate arch, 30 studs past the NorthGate arrival point (which now sits on the road surface).
  - **Foundry Yard:** a new south road strip with its own arch.
  - **Setting off:** hold the prompt, then press "Set off" on the travel card. Only the party leader can start. Party members within 60 studs come along, and anyone knocked, held or fighting stays behind and is told why.
  - **Who may travel:** no ticket and no papers check, so Wanted players travel this way.
- **`RoadService` (new, in `RenseiServer`):**
  - **The trip:** it takes its full time (40 s on this route).
    - The party waits safely out of the world, each trip in its own spot, and nobody can fight on the road.
    - The journey screen counts down from the server's clock.
  - **Ambush:**
    - The chance is from the spec: 15% base, plus night, winter and Wanted, capped at 60%.
    - It stops the trip partway, and the party fights bandits (an Elite if Wanted) in a road arena in the origin place.
    - **Win or flee:** win, or flee by leaving the arena's marked edge (fence posts and stones). Either way the journey continues for the time left. A far teleport out is put back. Knocked enemies count as beaten after an 8 s grace (PROPOSAL), and grips in progress get time to finish.
    - **One party at a time:** a second party is told "The road ahead is blocked. Try again shortly."
  - **Leaving:** death or leaving the server takes you out of the journey, and enemies are always cleaned up.
- **UI (existing assets only):**
  - The travel card and journey screen are built from the existing party panel, banner, background and boss bar art.
  - Messages use the game's toasts.
- **Tests (Ye, Play):** Road 11/11, Travel 7/7, Station 8/8, RideEvents 9/9, Boot 2/2. Multi-player paths and the live teleport are untested until there's a publish and a second player.
- **Backups:** `RenseiBackups["Pre-Roads_2026-10-21"]`.
- **For the owner:** publish `RenseiServer`. TravelClient is copied into Foundry.

## 2026-10-21 — World Plan 1, Task 7: things happen on the train

- **`RideEvents` (new, in `RenseiServer`):** each ride may roll one event (the weights are in `Travel`, PROPOSAL):
  - **Inspection:** the conductor checks tickets. A rider with no ticket is fined 3× the base fare. Someone who can't pay is marked to be put off, which Task 9 acts on. Money never goes below 0.
  - **Rumour:** a passenger repeats something "someone" did, taken from rumours already going around, preferring ones heard at the destination. No player is named. Deeds written as "you…" are skipped because they read oddly.
  - **Pickpocket:** a little money goes missing, never more than you carry.
  - **Holdup:** two bandits burst into the dining car.
    - They are real enemies that fight and give the normal rewards.
    - They can't leave the train, and they are removed when the ride ends or everyone is gone.
    - They never respawn.
- **Death aboard (a ruling to confirm):** if you die on the ride, you come to back in town and your ticket is still good; you're no longer pulled back into the train.
- **Tests (Ye, Play):** RideEvents 9/9, Station 8/8, Travel 7/7, Boot 2/2. The death test uses a real death.
- **Backups:** `RenseiBackups["Pre-RideEvents_2026-10-21"]`.
- **For the owner:** publish `RenseiServer`.

## 2026-10-21 — World Plan 1, Task 6: the station and the train ride

- **Lindenmoor station (Ye):**
  - the FMA train waiting at the platform;
  - a ticket booth with a clerk ("press E");
  - a departure board on posts that counts down to the next train.
  
  A second copy of the train ("RideTrain") runs high above the map for the journey itself.
- **Foundry Yard:** the same station on its placeholder platform (`station_foundry.lua`, safe to re-run). The train kit was copied from the committed import, and its geometry matches Ye's exactly. Foundry's older copy, which predated the review fixes, is in backups.
- **`StationService` (new, in `RenseiServer`):**
  - **Buying tickets:** you buy at the clerk (the server checks you're near one). You can also buy for a party member, matched by UserId.
  - **The conductor:**
    - Doors check your class: 3rd class can use the dining car but not 2nd class. You need a ticket to board at all.
    - The server checks the class again at departure and during the ride, so a cheating client can't teleport into a class it didn't pay for.
    - Seats carry over into the ride train.
  - **Departures:**
    - Trains leave every 150 s (PROPOSAL), and the clock survives a short server hitch.
    - The screen fades, everyone aboard rides together, and they arrive as a group (Task 5's `Depart`).
    - Anyone who steps off during the fade stays behind and keeps their ticket.
- **`TravelClient` (new):** the ticket window, the departure boards, the ride screen with scenery out the windows, and the teleport screen.
- **Tests (Ye, Play):** Station 7/7, Travel 7/7, Boot 2/2, Heat 8/8. The tests cover buying, the conductor, a seated ride, stepping off during the fade, and wrong-class seats and cars. The real journey between places needs a publish.
- **For the owner:**
  - Publish the `RenseiServer` package, which carries StationService.
  - Turn `StarterPlayerScripts.TravelClient` into a Package. Foundry has a plain copy for now.
- **Backups:** `RenseiBackups["Pre-Stations_2026-10-21"]`.

## 2026-10-21 — World Plan 1, Task 5: TravelService and group teleports

- **Save:** a new `Travel` field holds the region you were last in, your unused tickets, and the trip under way. It is added to old saves automatically.
- **`FlowTeleport.SendGroup`:** everyone in the list goes in one teleport and lands in the same server. A failure retries, and after the last try every member is kicked back. `Send` is unchanged.
- **`TravelService`** (new, in `RenseiServer`):
  - tickets: add, check, and use one of a chosen class;
  - `Depart`, which sends a group along a route;
  - arrival at a named point (`RenseiArrival` parts);
  - an `Arrived` event, which Task 6's stations use.
- **Safety: the arrival trusts the save, not the player.** Before the teleport, the server writes the trip (route, destination, arrival point, class) into each traveller's save.
  - On arrival, only a trip to *this* region counts: that exact ticket is used up and the region is saved.
  - Anyone who turns up somewhere they didn't travel to is sent back to their last region.
  - This closes a hole where a player could jump to any region, skip its level gate and keep their ticket.
  - Saves are released all at once, so a full train doesn't wait one player at a time.
- **Lindenmoor:** two arrival points, `Platform` and `NorthGate`.
- **Menu:** a returning player now goes back to the region they were last in (`Places.ResumePlace`); new and old saves still go to Lindenmoor. The `Places` module is synced to the Menu and Tutorial, and the new `FlowTeleport` to the Tutorial. The Menu copy follows when that place is open in Studio.
- **Tests (Ye, Play):** Travel 7/7, Boot 2/2, Heat 8/8, Rumours 2/2.
  - Covered: tickets, the Studio arrival, a forged arrival refused, a trip that arrives and uses the right class, and a stale trip cleared with the ticket kept.
  - The real hop between places can only be tested after the owner publishes.
- **Backups:** `RenseiBackups["Pre-TravelService_2026-10-21"]`, in Ye, Menu and Tutorial.

## 2026-10-21 — World Plan 1, Task 4: Foundry Yard boots the full game

- **Packages:** the owner turned the 13 shared roots into Roblox Packages, with auto-update on. Their ids are in `Art/Studio/Travel/packages.json`.
- **Foundry Yard (109591196441030), a placeholder for now:**
  - the `workspace.World` skeleton;
  - a 400×400 ground;
  - a cobbled platform with rails;
  - two arrival points (`Platform` and `SouthGate`, with a gate arch);
  - a spawn and the "Foundry Yard" area.
  
  The template Baseplate and SpawnLocation are backed up in `RenseiBackups["Pre-WorldPlan1_2026-10-20"]`. Every size is a PROPOSAL; the real region is a later plan. Ye's lighting and place settings are copied with `place_setup.lua`; Lighting.Technology must be set by hand.
- **Bug fixed: the server wouldn't start after packaging.** `RenseiBoot` tried to copy the package's own `PackageLink`, which Roblox won't clone. That broke Ye as well as Foundry.
  - Now it skips the link, and one bad child can't stop the rest from copying.
  - The old version is in `RenseiBackups["Pre-WorldPlan1_2026-10-20"].RenseiBoot_v1`.
  - **Tests (Ye, Play):** Boot 2/2, Heat 8/8, AditBoards 10/10. The owner's save was snapshotted and restored, and the temporary hook was removed.
- **More packages:** the owner published the `RenseiBoot` fix (now v2) and packaged `StarterPlayer.StarterCharacter`, `SoundService.SFX` and `SoundService.Music`. All four are now in Foundry, which makes 16 packages.
- **Boot test (Foundry, Play):** Boot passes 2/2. The character spawns on the platform in the "Foundry Yard" area, and the console has no game errors. The owner's save was snapshotted and restored, and the hook was removed.
- **Review fixes:**
  - The settings that `place_setup.lua` generates now refuse to run in Ye.
  - The leftover tool tags are removed from the Foundry package roots.
  - The v1 RenseiBoot backup no longer links to the package, so auto-update can't overwrite it.
- **Tooling:** `Art/Tools/rbxc.py` retries when Studio briefly reports a window with no name.
- **For the owner:** in Foundry, set Lighting.Technology by hand to match Ye. Keep or delete the template SunRays and DepthOfField (Ye has neither). Save the place.

## 2026-10-20 — World Plan 1, Task 3: server code now lives in ServerStorage.RenseiServer

- **Editing has moved.** In Ye, every server script and module now lives in `ServerStorage.RenseiServer`; this is where you edit server code from now on. **jenkins2bee-prog: please edit there too.**
  - `ServerScriptService` holds only `RenseiBoot`. At server start it copies `RenseiServer` into ServerScriptService, modules first, so every `ServerScriptService.<name>` path in the code still works and nothing in the game changed.
  - This is what lets every region place run the same code as one Roblox Package (Task 4).
- **Backup:** `RenseiBackups["Pre-WorldPlan1_2026-10-20"].SSS`.
- **Tests:**
  - Every Play suite gives the same results before and after the move: Heat, Morality, Perception, Rumours, Stealth, Assault and AditBoards, plus the new `Play_Boot`.
  - Three Edit-mode suites now look for server modules in either place: Schema5, Witness and RumourCore.
  - The rule for new tests is in `Documents/Lindenmoor Kit.md`.
  - The temporary save-snapshot hook now refuses to run outside Studio.
- **Already failing, not caused by this:** `Test_Sound` (0/8; it expects Perception functions that changed), plus one test each in Witness and RumourCore.
- **Backlog:** the owner's request for civilian NPCs that react to players and the world is added to `Documents/Backlog.md`, for after this plan.

## 2026-10-20 — World Plan 1, Task 2: the FMA train kit

**Owner:** "I want the train model to be made in blender and have it have a FMA style... a nice interior too"; chose 5 cars plus the engine.

- **Blender (`Art/Blender/train/train.py`, `Art/Blender/Train.blend`):** a part kit 440 studs long, about 1,480 objects:
  - **Locomotive (72 long):** navy-black with brass, a round smokebox door ringed with 12 bolts, twin lit headlamps, three coupled drivers with rods, steam from the chimney.
  - **Tender**.
  - **Baggage car:** crates, mail sacks, and the stowaway door on the freight-yard side.
  - **3rd class:** an open saloon with 28 seats on facing benches.
  - **Dining car:** six tables for four (24 seats) and a bar.
  - **2nd class:** a side corridor and 4 compartments, 8 seats.
  - **Private cabin car:** two cabins and a sitting nook, 4 seats.
  - **Every coach:** maroon with wood-framed windows, cream inside, an arched roof, gangways between cars, vestibule doors with steps, plus invisible BoardZones, CarDoors (for the conductor's class check) and a StowZone.
- **Pipeline:**
  - `export.py` takes a scene and output path, and exports Seat parts and invisible helper parts with attributes.
  - `studio_kit.py` takes a folder, builds Seats, helper attributes and the steam ParticleEmitter, and adds the train materials.
  - The Lindenmoor export stays byte-identical.
- **Studio:** `ServerStorage.TrainKit` in Ye, 7 models; counts checked. The trains are placed at the stations in Task 6.
- **Renders:** `Documents/images/Map Concept/Train - *.png` (locomotive, coach side, 3rd-class interior, dining car, baggage door).
- **Reviewed:** the review found three gaps (12 dining seats, no steam, the baggage door on the platform side). All three are fixed and re-reviewed.

## 2026-10-20 — Fixes: custom hair in the Tutorial, every enemy grippable, grip alignment audit

**Owner:** fix custom hair IDs not saving, make every enemy grippable, and check how the players line up during a grip.

- **Hair:**
  - **Cause:** saving was fine (the Menu saves `HairIds`; Ye applies them). The Tutorial place ran stale copies of `AppearanceService` and `Rensei.Customization` with no typed hair, hex hair colours, custom skin or female body. So typed hair vanished there.
  - **Fix:** the Tutorial now has Ye's exact modules (9,542 and 19,208 bytes). Backup: `RenseiBackups["Pre-HairSync_2026-10-20"]`. Generator: `Art/Studio/Fixes/tutorial_hair_sync_make_push.py`.
  - **Checked in Tutorial Play:** the owner's two typed hairs (14891305487, 18935646653) load and are worn. The owner's profile was snapshotted and restored.
  - The region places still need these modules once they're playable (packages, World Plan 1 Task 4).
- **Grippable enemies:**
  - `EnemyService` now makes every enemy knockable unless its definition says `Knockable = false`. The Sparring partner opts out, in `TuningConfig`.
  - A knocked alchemist no longer raises its guard, and a knocked Elite no longer parries.
  - Backup: `RenseiBackups["Pre-GripAll_2026-10-20"]`. Script: `Art/Studio/Fixes/grip_all_enemies.lua`.
  - **Checked in Ye Play:** every live enemy type is knockable (Grunt ×4, Adit Scavenger ×2, all five alchemists, Elite). A Grunt at 0 HP was knocked, gripped, and died.
  - **Design consequence:** an enemy at 0 HP now goes down and must be gripped (or carried) to finish; otherwise it recovers after 20 s.
- **Grip alignment (audit; nothing changed):**
  - A grip welds the gripper's root onto the victim's root, so how the bodies line up comes from the animation pair.
  - Each pair was posed on R6 stand-ins at 50% of the animation:

    | Pair | Torso gap | Height difference |
    |---|---|---|
    | Fists | 1.25 | gripper 1.07 above |
    | Sword | 1.30 | gripper 0.40 below |
    | Greatsword | **3.41** | 0.32 (the bodies don't meet) |
    | Rapier | 2.64 | gripper **2.61 above** |

  - The Daggers and Guns grip animations didn't load (length 0), so they're probably unpublished to the group.
  - Animation lengths differ: Rapier victim 1.80 vs grip 1.23, Greatsword 1.13 vs 1.33, Guns 3.25 vs 3.0.
  - `Knocked`, `Gripped`, `Gripping`, `Carried` and `Carrying` have empty AnimationIds. The owner publishes those.
  - **Suggested next step (owner's call):** per-pair offsets in `Tuning.Downed.Grips`, or re-authored Greatsword and Rapier pairs.

## 2026-10-20 — Halvard's Adit: the boards smash open

**Owner:** "I want the boards to physically smash when hit or hit with alchemy". Who sees them broken: "Each player, unless they are in a party".

- **New puzzle piece:** the boarded mouth is now a per-player breakable mechanism, `adit_boards`, built like the cracked wall. Players break it by:
  - three melee hits from fists or any weapon (a heavy counts as two; PROPOSAL);
  - any of the five alchemy elements, each with its own line.
- **The melee hook:** one guarded call in `HitboxManager.Sweep` (`PuzzleService.Strike`). Combat results are unchanged.
- **Saving and parties:** a break is saved for the player and for every party member in the server.
- **What players see:**
  - each hit cracks the boards with a splinter puff;
  - the break throws the planks off as physics debris, with a dust burst, cleared after 6 s;
  - a player who rejoins sees the opening, with no debris.
- **The blocker:** while the boards are whole, an invisible client-side blocker fills the frame, so smashing is the only way in. The review measured that no R6-sized box fits through.
- **Inspect text:** now "Two hang loose; a few good hits, or a little alchemy, would bring the lot down." (PROPOSAL wording).
- **Tests:** `Play_AditBoards` passes 10/10 and `Play_Assault` still passes. A MoveTo was blocked while the boards were whole and passed once they broke. The owner's profile was snapshotted and restored.
- **Backups:** `RenseiBackups["Pre-AditBoards_2026-10-20"]`.
- **Open:**
  - the game has no wood-break or crack sound yet (set the `BreakSound` / `CrackSound` attributes on the boards model to add one);
  - a multi-hit skill counts each of its hits;
  - party sharing still needs a live two-player check.

## 2026-10-20 — Fix: Halvard's Adit entrance blocked

**Owner:** "fix the dungeon entrance not being able to be destroyed open".

- **Cause:** when `ground.lua` turned the terrain into parts, it stopped each ground column above any cave it could detect. The Adit's boarded mouth sits under the hillside's overhang, which that test doesn't count as a cave. So two stone columns, 16–17 studs tall, filled the entrance right behind the boards. That is also why the earlier walk test stopped at the mouth. The boards were fine: the loose planks are passable, as designed.
- **Fix in `Art/Studio/Lindenmoor/ground.lua`:** before building any ground column, the script reads the Adit's real route (every floor, the ramp, and the mouth between its frame posts up to the lintel) and keeps it clear. A column taller than the route keeps only the part above it. One whose top is inside the route becomes a 1-stud surface slab. The ground was rebuilt and `settle.lua` re-run.
- **Test:** the new `ServerStorage.RenseiTests.Test_AditRoute` (a copy is in `Art/Studio/HalvardsAdit/`) failed before the fix and passes now.
- **Tried in Play:** a character walked from outside, through the boards, and down the tunnel to x 327. The owner's profile was snapshotted and restored.

## 2026-10-20 — Plan: World Plan 1, travel backbone and station tie-ins (with the FMA train)

**Owner:**
- approved the world spec;
- created the six region places (Foundry Yard 109591196441030, Central City 74075793529314, Aerugo Borderlands 72020960130134, Ishval 133625615147752, Northern Wall 132378034692557, Corrupted Lands 138436167547886);
- asked for the train to be "made in blender and have it have a FMA style... a nice interior too, with areas for players to board", and chose 5 cars plus the engine.

- **Spec:** updated with the place ids and a "train model" section: locomotive and tender, then baggage, 3rd class, dining, 2nd class and private cabin cars, with R6 sizes and FMA colours.
- **Plan:** `Documents/plans/2026-10-20-world-plan1-travel.md`, 11 tasks:
  1. the travel rules and region places (pure, tested);
  2. the Blender train kit;
  3. a server boot loader, so every place runs the same code;
  4. Packages, and the Foundry place running the full game;
  5. the group teleport and TravelService;
  6. stations (tickets, boarding by class, the playable ride);
  7. ride events;
  8. road journeys with ambushes;
  9. the papers check and the stowaway route;
  10. rumours, regions, quests and parties across places;
  11. the Foundry end-to-end check and docs.
- **Ruling:** Wanted 3+ at the gate is a refusal plus State Heat until an arrest system exists.
- **Not started yet.**

## 2026-10-20 — Backlog: the owner's to-do list for after the world plans

- **New file `Documents/Backlog.md`:** the owner's 16 items, in the owner's words, for after the world, travel and seasons plans:
  - combat and movement fixes (climbing, health balance, running attack, down slam, parry spam, greatsword sheathe, alchemy lock-on);
  - lag, memory and multiplayer response;
  - smarter NPCs and their swarm system;
  - "???" name tags until a player is identified;
  - PvE-only assassinations with the detection system;
  - broken trainer exams, the leaderboard scroll, and live party health bars.
- **Trading** is also listed there, as already queued.

## 2026-10-20 — Spec: world scale, travel and seasons

**Owner:** "I want the full map to be so big you have to use the train, etc. to TP to the place..."; "I want regions to be as big as VV Ultimatum's maps"; "also add seasons into the game that effect terrain".

Spec: `Documents/specs/2026-10-20-world-travel-seasons-design.md`. Approved in conversation; waiting on the owner's review of the written spec. Every number is a PROPOSAL.

- **World:** one place per region (Ye becomes Lindenmoor), each about 3,000 × 3,000 studs (about 2 minutes of running across). The trial rooms and the Foundry core move to their regions.
- **Train:** a playable 45–60 s ride with events; everyone aboard lands on the same server.
- **Roads:** road journeys can be ambushed, and they're the way out for Wanted players.
- **Stations tie in:** tickets by class, the papers check, refusal or arrest when Wanted, a stowaway route, and rumours carried by the timetable.
- **Seasons:** 2 hours each, worked out from the clock. They change the part ground (snow, autumn leaves, crops), freeze ponds into walkable ice, and affect tracking, stealth and prices.
- **Code:** shared through Roblox Packages.
- **Build order:** backbone, then station tie-ins, then seasons, then Lindenmoor grown to about 3,000 studs, then the Foundry Yard, then Central, then the borders.

## 2026-10-20 — Concept: region layouts and how they connect

**Owner:** "Draw me up some layouts of the other map areas and how they connect".

- **Artifact:** [Rensei Region Layouts](https://claude.ai/artifact/J7yecfYa1uRf5cdarNt8HM), a companion to the Rensei World Map. It is private, so share it from its Share menu.
- **Connection plan:**
  - the Act 1 spine (Lindenmoor, the Foundry Yard, Central) by road and rail;
  - Central's four gates, to Aerugo, Ishval (the East line), the Northern Wall, and the Corrupted Lands by the undercity;
  - two late links into the Corrupted Lands: the ice-cave pass from the Wall and the ash wastes from Aerugo.
  - Each route has its length, its level or Act gate, and its rumour link. The existing ones come from `Rensei.Regions`; the new ones are proposed.
- **"Built today" plate:** the training field, the Foundry Yard core and the Forgotten Site rooms north of Lindenmoor, at their measured positions in Ye.
- **A layout per region:** Foundry Yard, Central City, Aerugo Borderlands, Ishval, the Northern Wall, and the Corrupted Lands with the Eclipse Citadel. Each shows its districts, gates, arenas, Forgotten Sites and signature movement.
- **Joining rules:** choke points, visible landmarks, level gates in the world, one fast-travel post per region, and area names for rumours and Heat.
- Every number is a PROPOSAL. Concept only: nothing in Studio changed.

## 2026-10-20 — No Roblox terrain: part-built ground, out-of-place fixes, Halvard's Adit in the mine reference style

**Owner:**
- "Fix areas in the map that are out of place, also make the dungeon look like the reference picture & layout picture";
- "I don't want to use roblox's terrain. Make it like the references I sent you" (approved deleting the terrain);
- "Go back to the style we just had ... I just wanted the walk-ways to connect".

Details: `Documents/Lindenmoor Kit.md` (update section). Every number is a PROPOSAL.

- **Ground (`Art/Studio/Lindenmoor/ground.lua`):** all solid terrain under Lindenmoor and the Adit is now parts, about 16,300 of them:
  - mossy slabs stacked in 1-stud steps over dark stone;
  - connected walkways: path gaps closed, and climbing path cells are dirt ramps on the real slope;
  - a block-built cave.
  - Terrain water stays, because swimming reads it.
  - The original terrain is backed up in `RenseiBackups["Pre-PartGround_2026-10-20"]`.
  - A tilted-slope version was tried and dropped at the owner's request.
- **Fixes (`settle.lua`):**
  - the workshop's three lying stone beams became stepped dry-stone yard walls;
  - every tree, stone, lamp, tent and prop sits on the new ground, with trunks, roots and fence posts reaching down to it;
  - clipping removed: bank stones in the trestle and gorge, lamp bases in the fence, fence in the barn, terraces through trunks, props in tents, trunks in trunks.
  - Removed pieces are in `RenseiBackups["Pre-Settle_2026-10-20"]`.
- **Halvard's Adit (`Art/Studio/HalvardsAdit/`):**
  - stacked angular slate blocks on every wall and ceiling;
  - stepped ledges along the entrance tunnel;
  - crossing chains in the lift hall, sump and lab, and chains above the lanterns;
  - a teal fill with warm lantern pools. These lights sit inside Attachments, so stealth is unchanged.
  - No mechanism moved.
- **Tested (Play in Ye):**
  - spawn, lanes, bridge and road north, farm, camp;
  - the workshop path on foot with no jumping;
  - the Adit tunnel and lab;
  - swimming, canopy shade (0.35 against 1.00), the gorge ledge.
  - The owner walked the routes too.
  - The profile was snapshotted and restored.

## 2026-10-20 — Lindenmoor finished and split into a Studio kit (live in Ye)

**Owner:** "I want the whole lindenmoor finished, then split into a kit so I can export them into studio seemlessly".

Full write-up: `Documents/Lindenmoor Kit.md`. Every number is a PROPOSAL.

- **Blender:** the whole village is built on the real Studio terrain (`Art/Blender/lindenmoor/world.py`, saved as `Art/Blender/Lindenmoor_Full.blend`):
  - 9 farmhouse variants on the old house pivots;
  - 63 oaks and 95 cypresses on the old trunks;
  - 17 lamp posts, the barn and the camp tents;
  - new: a forest rim and Bramble Hollow (69 big oaks), Cypress Ridge terraces (28), creek-bank stones (118), verge stones (77), and a square with a kerb ring, 3 market stalls and well stones.
  - The station, bridge, fences, crops, square furniture and gorge keep their exact geometry.
- **Kit and export:**
  - `export.py` writes `Art/Studio/Lindenmoor/layout.json`: 484 models and 7,517 parts with Roblox CFrames. A round-trip against the 486 original Studio parts showed zero error.
  - `studio_kit.py` writes 7 import chunks and 34 drag-in `.rbxmx` kit models (`Art/Studio/Lindenmoor/kit/`).
  - The materials are Roblox built-ins: Plaster, ClayRoofTiles, RoofShingles, WoodPlanks, Cobblestone, LeafyGrass and others.
- **Ye:**
  - Imported through `import/chunk_01..07.lua` and `import/finish.lua`. Lindenmoor is now 8,299 parts (it was 3,457).
  - The replaced pieces are in `ServerStorage.RenseiBackups["Pre-LindenmoorKit_2026-10-20"]`.
  - The kit copies are in `ServerStorage.LindenmoorKit`.
  - Re-skinned parts keep their old values in the attributes `PreKitMaterial` and `PreKitColor`.
  - The Atmosphere is now a teal haze; the old values are stored on the backup folder.
  - Kept exactly: terrain and water, the spawn, the bandit spawns, GorgeLedge, the workshop, the trainers, the run course, the hub road, the areas and the camp fire.
- **Tested (Play in Ye):**
  - spawn on the square;
  - the lane walked both ways, the road walked over the bridge, and walks into the camp and the farm;
  - no new part blocks a walkway (raycast every 2 studs);
  - LightService tags all 27 new lights;
  - canopy shade gives exposure 0.35 against 1.00 in the open;
  - swimming in the Mill Pond works;
  - GorgeLedge is unchanged.
  - The owner's profile was snapshotted and restored, and the temporary hook was deleted.
- **Tools:** `Art/Tools/rbxc.py` (a file-driven Studio MCP client) and `Art/Tools/blender_mcpc.py` (the Blender MCP client).
- **Open:**
  - real texture MaterialVariants need either an upload route (a localhost server, which was declined earlier) or a manual upload;
  - Ye is not saved or published by this change.

## 2026-10-20 — Lindenmoor v2 in Blender: blocky like the refs, real textures, far more detail

**Owner:**
- "I want the build to be wayy more detailed with better textures";
- "1000x cooler";
- "Remember I want it like these pictures" (the 3 refs: a blocky fogged forest, a teal mine, a candlelit temple).

- **Look:** the refs' block language.
  - Trees: square trunks with root slabs, angled box branches, stacked flat canopy slabs with edge blocks, and hanging box vines. The canopy forms a ceiling over the camera.
  - Ground: stacked mossy terrace slabs.
  - Rock: angular wedges and slab outcrops.
  - Every surface is real PBR texture, box-projected at stud scale. Moss grows on the upward-facing faces of rock, terraces, walls and bark.
  - Lighting: teal fog in layers, background tree silhouettes, and warm practical lights (the door lantern, interior glow through the windows, three lamp posts).
- **Textures:** 14 CC0 Poly Haven sets plus a misty-morning sky.
  - Sets: grass, dirt path, cobble, mossy rock, cliff, stacked stone, field-wall stone, plaster, medieval timber, planks, clay roof tiles, bark, thatch.
  - `Art/Blender/fetch_textures.py` downloads them. The files are git-ignored, about 143 MB.
- **Farmhouse detail:**
  - plinth, stone ground floor with quoins;
  - timber frame with posts and braces;
  - framed windows with sills, mullions, shutters and flower boxes;
  - a 6 × 9 plank door with lintel, hinges and step;
  - a tiled roof with tile rows, rafters, ridge, barge boards and gables;
  - chimney and cap, gutter and downpipe, rain barrel, firewood stack, bench.
- **Props:**
  - a well (stone ring, roof, bucket, rope) and a hay cart;
  - barrels with iron hoops, and crates;
  - fences and lamp posts along the path, hay bales;
  - sticks, pebbles and plank scraps;
  - about 700 grass clumps, moss patches and bushes.
- **Gameplay pieces:**
  - an outcrop with an authored ledge strip (7 up, 1.2 deep; tag it `RenseiLedge` in Studio);
  - field walls 4 studs high (the vault height);
  - R6 stand-ins for scale.
- **Files:**
  - `Art/Blender/lindenmoor/{core,build}.py`, which rebuilds everything with `build.run("all")`;
  - `Art/Blender/Lindenmoor_v2.blend`;
  - the render: `Documents/images/Map Concept/Lindenmoor v2 (textured, blocky).png`.
- **Not yet:** export to Studio. The pieces have to become a modular kit, with FBX at stud scale and MaterialVariants from the same textures.

## 2026-10-20 — Blender style test: a Lindenmoor corner at R6 scale

**Owner:** "Continue" (after the world map concept), with Blender connected.

- **Blender connection:** the owner's Blender Lab MCP server (from the Claude desktop app) is now also registered in Claude Code (`claude mcp add blender`, user scope). Its tools load after a restart of Claude Code. Until then, this session drives the same server from a small script.
- **Style test:** built in its own scene (`Rensei_StyleTest`); the default scene was not touched. Scale is 1 unit = 1 stud. It contains:
  - a chunky stacked-slab rock outcrop with an authored ledge strip (1.2 deep, 7 up; tagged `RenseiLedge` in Studio);
  - an oak with a layered slab canopy and hanging roots, plus cypress;
  - a stone-base, timber-and-plaster farmhouse with a terracotta roof, a 6 × 9 door and a lantern;
  - a two-row field wall, 4 studs high (the vault height);
  - 3-stud terraces, a 10-wide dirt path with stone edging, grass clumps and hay-bale cover;
  - two R6 stand-ins (4 × 5 × 1) for scale;
  - procedural PBR materials, bounded fog, a low warm sun and two warm practical lights.
- **Files:**
  - `Art/Blender/Lindenmoor_StyleTest.blend`;
  - `Art/Blender/lindenmoor_styletest_build.py` (rebuilds the scene from scratch);
  - the render: `Documents/images/Map Concept/Lindenmoor style test v1.png`.
- **Next, once the look is approved:** split it into the modular kit (rocks / cliffs with ledge pieces, trees, farmhouse parts, walls), export FBX at stud scale, import into Studio with MaterialVariants.

## 2026-10-20 — Concept: world map layout and visual style (not built)

**Owner:** "give me a concept idea on how the map layout would work based on all the documents and slideshows... starter area grassy farmland... deepwoken/semi-stylized, NO LOW POLY... respective to R6 height and... all the movement, combat, and parkour mechanics".

- **Concept page:** https://claude.ai/artifact/Qbm5hCE23tSRyu9mjPxRWK
- **World layout:** drawn from the slideshow's regions and Acts 1–3:
  - Lindenmoor (start), the Foundry Yard and Central City (the hub) on the rail line;
  - Aerugo Borderlands to the south-west, Ishval to the east, the Northern Wall, and the Corrupted Lands with the Eclipse Citadel;
  - the existing Forgotten Sites are placed as the dungeons.
- **Lindenmoor:** re-shaped into a fogged valley bowl that teaches one movement verb per path. The current layout, area names and tags are kept.
- **Visual rules** from the 3 references: chunky textured masses, PBR material variants, layered fog, warm practical lights; no low-poly.
- **Build metrics** from the measured R6 / TuningConfig numbers: gaps, climb heights, wall-run faces, arena sizes, cover spacing against sight ranges, water depths.
- **Everything is PROPOSAL.** Open questions: seamless vs separate places, names, level bands, day/night.

## 2026-10-20 — Plan 2: Heat and Wanted + sound and light

Plan 2 of the Morality × Reputation roadmap: slices R3 (Heat) and S2 (sound and light). Approved in the session on 2026-10-20 (ImWaymonTTK: "Approved. Build Plan 2 as drafted, using the default answer for all 6 questions"). The plan is `plans/2026-10-20-plan2-heat-wanted.md`; what's left is in `plans/2026-10-20-plan2-followups.md`. Every number is a **PROPOSAL**. Built in **Rensei** (Ye) only.

**Default answers used (yours to change):**
1. The five Alchemy Trainers are **not** witnesses (unchanged).
2. Field / Frost / Gale / Stone / Ward Alchemists are **rogues**: they keep the Agent sight type but have no faction, so they never raise Heat.
3. The rumour hop rule stays (strength N → N−1 hops). This now decides Heat too: a crime seen by one townsperson in the Foundry never reaches the City, so it gives no State Heat.
4. Hostile NPCs (no faction) still notice you but **add no rumour strength**.
5. **No cell yet.** It comes with the arrests in Plans 6 / 7.
6. Betraying Lise gives **no** Circle Heat. Circle Heat is wired, but no deed uses it yet.

**What players notice**
- **Crimes and Heat.** Two crimes, both new deeds:
  - `unlicensed_cast`: from level 6, without a State licence, in a State place, while an Authority agent (today only Foreman Brask) saw you within 3 s. +10 State Heat per cast, at most +30 per place per hour. Order −1.
  - `assault_townsfolk`: hitting a watcher. +15 Heat, Mercy −2, Order −2, Townsfolk −2. Once per victim per 30 s. **See the finding below: melee can't reach watchers today.**
- **How Heat rises** (spec §6):
  - **At once**, when the law of that place is there to hear it. The Authority is present in the City, and Townsfolk are the law in Lindenmoor. An agent who saw it counts as present, e.g. Brask in the Foundry.
  - **Otherwise, when the word arrives.** For example, an assault in the Foundry with 2 witnesses' worth reaches the City's Authority by dispatch in 2 min: +15 State Heat.
  - Each rumour raises each jurisdiction **once**. Gossip arriving later adds nothing more.
- **Wanted 0–5** per jurisdiction (State / Militia / Circle) at Heat 20 / 50 / 100 / 180 / 300. A banner shows when the level changes ("State - Wanted 1", "State - no longer wanted").
- **Heat decays** −5 per hour of real time, offline included.
- **Fine.** Foreman Brask has a new line, **"I'll pay the fine." (Price: 100 per level)**. It shows only while you have State Heat and Wanted ≤ 2. Paying costs 100 × level, clears State Heat, and he answers with a new "fined" line. At Wanted 3+ his line is "About that fine…" → "Past that, friend." If you can't pay, the conversation closes and a toast says why.
- **Wanted badge** (`WantedUI`, new): small badges to the right of the compass, one per jurisdiction you're wanted in (State blue, Militia brown, Circle dark red), with five pips. Hidden at Wanted 0, and with the compass's own rules.
- **Sound** (`NoiseService`, new). Sounds are events with a radius. NPCs go to look at the **spot**; they learn where, not who.
  - **Footsteps** by floor: grass / dirt 4, wood 7, metal / gravel 9, anything else 5. Running or sprinting ×2. Crouched 0.
  - **Other sounds:** landing from a height (falling faster than 45 studs/s) 12, a dive into deep water 12, dash / roll 10, any hit 20, alchemy cast 30, gunshot 60.
  - **Walls:** each wall between the sound and an NPC takes 40% off the radius (counted up to 3).
  - **Modifiers:** Cautious NPCs hear ×1.3, and Agent-type NPCs hear alchemy ×2.
- **Light** (`LightService`, new). Every enabled light in the world outside rigs (35 parts: lanterns, the forge, the crucible, embers) is tagged `RenseiLight` with a radius and strength from its light.
  - **Exposure** (0–1) comes from the brightest lamp with a clear line to your torso, or from daylight: in full in the open, ×0.35 under a roof.
  - **Sight:** NPCs see you ×0.2 in deep shadow, up to ×1.2 in bright light.
  - **The game has no day cycle** (ClockTime 14.5), so the open is always bright.
- **Crouching** (real Ctrl) sets `Crouching` on the server: NPCs fill awareness at half rate, and your steps are silent.
- **Eye sigil** (`StealthUI`, new), bottom left above the party-name row. It's original art: a chalk-circle eye.
  - The iris goes from dark to gold with your Exposure.
  - The lid lowers while you crouch.
  - A ring flares out to the reach of your last sound, then fades.
  - It hides in menus, dialogue, cutscenes and at the Gate.

**Built**

| Piece | Kind | What |
|---|---|---|
| `Rensei.Heat` | new data | thresholds, decay, the per-hour cap, which law hears what (`Raised`), HUD colours |
| `HeatService` | new | Add / Value / Wanted / Fine / Clear; crime listeners (`Recorded`, rumour landings, `OnCast`, hits on watchers); `Wanted_<J>` / `Heat_<J>` Player attributes; `SetClock` for tests |
| `NoiseService` | new | `Emit`; steps, landings, splashes; hits via HitListeners; `Noise` / `NoiseAt` character attributes for the sigil |
| `LightService` | new | lamp tagging, `ExposureAt` / `ExposureOf`, `Exposure` character attribute every 0.5 s |
| `WantedUI`, `StealthUI` | new client UI | the badge and the eye sigil (UIHandler starts them) |
| `Rensei.Deeds` | edit | the two crimes; new fields `Crime`, `CircleHeat`, `HeatCap` |
| `Rensei.Perception` | edit | `CrouchMult`, `ExposureMult`, `Daylight`, `LampLight`, `Sounds`, `Steps`, `StepNoise`, `Muffled`; `MoveMult(Speed, SpeedMult)` |
| `PerceptionService` | edit | `Hear` (walls, Cautious, Agents and alchemy), `Walls`; crouch and Exposure in the sight rate; `Lose(Rig, Home, Range)`; Call guard |
| `MoralityService` | edit | `Info.Witnesses` (the full `Capture` result); hardened `Record`; warns if the join catch-up fails |
| `WitnessService` | edit | NPCs with no faction add no strength (answer 4) |
| `RumourService` / `.Core` | edit | `Core.Advance` also returns every landing (with `Reach`), which goes to HeatService; a "Word reached …: <reason>" toast for the newest arrival each tick |
| `StoryLogic` | edit | conditions `Heat`, `HeatBelow`, `Wanted`, `WantedBelow` (decayed to now) |
| `Dialogues` (Brask), `DialogueService` | edit | the fine lines and the `PayFine` action |
| `AlchemyService` | edit | after a successful player cast: a Cast sound + `HeatService.OnCast` (both optional, so the Tutorial can run this file without them) |
| `CharacterHandler` | edit | the `Crouching` attribute; a Roll sound on an accepted dash |
| `Shoot` request | edit | a Gunshot sound when a shot fires |
| `EnemyService` | edit | passes its home and leash to `Lose` |
| `ServerHandler`, `UIHandler` | edit | start the three services and the two UIs |

**Plan 1 follow-ups done:**
- the witness list is passed on;
- `Record` is hardened: Capture is pcalled, Evidence is coerced, an unknown region falls back;
- `Call(S, nil)` is guarded;
- an enemy that gave up at its leash no longer re-notices someone who stays beyond it (no Alert↔Cautious churn);
- a speed buff no longer reads as sprinting (gaits ÷ `SpeedMultiplier`);
- the crouch flag;
- the catch-up warning;
- the "Word reached" toast;
- Test_Schema5 extras.

**Tests.** All suites ran inside the game VM (Play), through an injected harness that snapshots the tester's save, runs `TestKit`, and restores it.
- **Edit-mode suites:**
  - `Test_TestKit` 4/0, `Test_Schema5` 6/0 (+2), `Test_Regions` 5/0, `Test_Reputation` 7/0, `Test_Perception` 4/0;
  - `Test_Witness` 3/0 (+1; RED "a bandit and a townsperson: expected 1, got 2" first);
  - `Test_RumourCore` 9/0 (+1);
  - **new:** `Test_Heat` 6/0, `Test_Sound` 8/0.
- **Play suites:**
  - **new** `Play_Heat` 8/0:
    - an agent-seen cast gives +10, and the cap holds at 30 → Wanted 1;
    - no crime behind Brask, at level 5, or with a licence;
    - an assault's Heat arrives with the dispatch and isn't repeated by gossip;
    - the law present raises Heat at once (Militia in Lindenmoor, State in the City);
    - a ghost crime raises nothing;
    - the fine works, and is refused past Wanted 2 or without the money;
    - decay.
  - **new** `Play_Stealth` 9/0:
    - one wall stops a 12-radius sound at 10 studs, and a 20-radius one gets through;
    - running on metal is heard at 14 studs where walking on grass isn't;
    - an Agent hears a cast at 45;
    - a gunshot pulls a Grunt from 50;
    - crouching halves the fill;
    - deep shadow vs bright light gives a ratio of 0.17;
    - a lamp lights a point at 0.75 and a wall puts it in shadow;
    - a lamp put out / afternoon / under a roof give the right values;
    - the leash stops the churn and a hit still alarms;
    - `Step` with the focus gone doesn't error.
  - **new** `Play_Assault` 1/0: the hit hook.
  - Plan 1's `Play_Perception` 6/0, `Play_Rumours` 2/0, `Play_Morality` 3/0.
- **Real input** (Studio Play as ImWaymonTTK; Level 6 and money set inside the snapshot):
  - three **Z** casts (Cryo Shift) in front of Brask → State Heat 10 → 20 → 29.9 (the cap less decay), Wanted 1, and the badge showed one pip (screenshot);
  - **E** to Brask, then **4** "I'll pay the fine." → money 1000 → 400, Heat 0, the badge hid, and the "fined" line showed;
  - **Ctrl** crouch-walk at 6 studs/s → `Crouching` true and no step sound for 30+ s;
  - walking on concrete → 5; sprinting on dirt → 8;
  - **Q** dash → Roll 10;
  - a 20-stud drop → Land 12.
- **Cost** (game VM, 18 NPCs registered, 4 within 80 studs of the tester, 35 lamps): perception step 0.016 ms, one cast sound 0.012 ms, one Exposure check 0.020 ms. **Not measured:** 20 NPCs near 2 players. The MCP only runs solo Play.
- **Save:** restored after the run with **0 differences**. A fresh Play then loaded it unchanged: Level 3, Money 120, Exp 70, only `born_Ishvalan`, no Heat or rumours.
- **Console:** no game errors or warnings from the new or changed scripts.

**Findings for you**
- **Townsfolk can't be hit yet.** `HitboxManager` only counts targets under `workspace.World.Live`, and the watchers live in `World.NPCs`. Two real M1s at Tobin did nothing. The assault crime is wired and tested through `ProgressionService.RecordHit`, but it can't happen in play until watchers are hittable. That's your call: they'd need health, knockouts and respawns.
- **Outdoors in daylight, enemies now notice you ×1.2 faster** than in Plan 1's timings, because the open sky is bright (Exposure 1 → ×1.2, spec §17.2). Shade, roofs and night now help. Tune with `Perception.ExposureMax` if the open feels too sharp.
- **The Tutorial wasn't touched.** AlchemyService, CharacterHandler, EnemyService, StoryLogic, Perception, PerceptionService and the Shoot request now differ from the Tutorial's copies, which were meant to match Ye. The new lookups are optional, so copying them over later is safe once HeatService / NoiseService / LightService and Rensei.Heat go too.
- During the real-input run, an Escape keypress (Roblox's own menu) left Tobin's dialogue box on screen with nothing answering it. One "Close" request from the client cleared it. Not caused by Plan 2 (DialogueUI only reacts while it thinks the box is open), and not investigated further.

**This export also carries earlier Studio changes that weren't in the repo yet** (made before Plan 2, from the 2026-10-19 Automail / Alchemic Binding work):
- `Dialogues`: the Lindenmoor mechanic Wren (`automail_mechanic`: fit / repair / remove automail, sell chalk);
- `DialogueService`: `Ask` (one question with server-side answers), and the `Automail` and `Buy` actions;
- `StoryLogic`: the `Automail` and `Money` conditions;
- `UIHandler`: its module list.

**Backups:** `ServerStorage.RenseiBackups["Pre-HeatWanted_2026-10-20"]`, 22 scripts:
- MoralityService, RumourService, RumourService.Core, PerceptionService, Perception, Deeds, AlchemyService, CharacterHandler, StoryLogic, Dialogues, DialogueService, ServerHandler, UIHandler, Shoot, SwimService (untouched in the end), WitnessService, EnemyService;
- tests: Play_Perception, Test_Schema5, Test_Perception, Test_Witness, Test_RumourCore.
- Test_Witness and Test_RumourCore were edited before they were backed up. Their backups were rebuilt by removing this plan's additions, and they match the repo's copies byte for byte.

**Exports** (Adler-32, the same in Studio and in the files):

| File | Bytes | Adler-32 |
|---|---|---|
| Heat | 3577 | `6f6e79be` |
| HeatService | 9483 | `d2f65a69` |
| NoiseService | 5267 | `18d9ee04` |
| LightService | 6057 | `284df244` |
| WantedUI | 4545 | `e31aa8be` |
| StealthUI | 5482 | `4a13ca34` |
| PerceptionService | 16821 | `013e74b1` |
| Perception | 6798 | `6d58b533` |
| MoralityService | 12560 | `c0a0522f` |
| RumourService | 3917 | `b3ef34ae` |
| Core | 5002 | `0b8d52e7` |
| WitnessService | 3263 | `7a924a04` |
| Deeds | 6125 | `ef165e2d` |
| StoryLogic | 10500 | `27266dd9` |
| Dialogues | 47210 | `6d36babc` |
| DialogueService | 13912 | `84d174cf` |
| AlchemyService | 62651 | `4c9044a4` |
| CharacterHandler | 8650 | `5dc5632b` |
| EnemyService | 25124 | `ba534e95` |
| ServerHandler | 5055 | `12f2efa7` |
| Shoot | 4790 | `092c4cec` |
| UIHandler | 2131 | `31e3c038` |

## 2026-10-20 — Tutorial synced with Ye's systems

Owner request: "sync up the Tutorial place to the same systems the main game has" (task E). Scope approved 2026-10-20 as tiers 1–3: the combat and movement core, UI parity, and the systems a new player can use. Ye's main-game content stays out: quests, investigation, morality / rumours, minigames, puzzles, trials, Truth, ritual, Automail, compass, journal / Mastery tree UI, admin. **Tutorial** = place 74257385894576.

**How:** every script and instance was copied byte for byte from Ye. Script sources and instances (SerializationService) went through a localhost relay between the two Studio windows, and each script was checked with an Adler-32 checksum before and after it was written. Everything replaced is in the Tutorial's `ServerStorage.RenseiBackups["Pre-YeSync_2026-10-20"]`: scripts as source copies, replaced models under `ReplacedInstances`, the old animation ids and walk speeds as StringValues.

**Before:** 407 scripts were identical, 51 had diverged (the Tutorial had older copies), and 96 existed only in Ye.

**Copied from Ye (58 scripts)**
- Combat and movement core:
  - data: TuningConfig, SkillData, Styles, Settings;
  - managers: AttackRunner, DamageManager, DownedManager, JumpManager, JumpManager.LedgeWalk, MovementState, SkillMods, LocomotionSync, MoverManager, ResourceManager, WeaponManager, Keybinds;
  - combat skills: Block, FistSwing, Heavy;
  - client: ClientHandler with Roll and Run;
  - server: CharacterHandler, StyleService, ItemService, LoadoutService;
  - requests: CombatMode, WeaponSkill, Style.

  This brings the 2026-10-19 animation wiring, the M1 speed pass with its AttackRunner fix, and the VV parry into the Tutorial.
- UI: UIState, UIMotion, MenuKit, HUDUI (with StoryLogic, Factions, ClassSkills, SkillTree, Ranks), CombatModeUI, MobileControls, SettingsUI, PromptUI, PopupUI, DialogueUI, CombatLogUI (the "IN COMBAT" badge), ItemData.Consumable.
- Systems:
  - swimming: SwimService, SwimClient and the Swim request;
  - guns: the Shoot request;
  - the ClassSkill request;
  - AlchemyService and Effects.Alchemy.EarthShapes;
  - enemies: EnemyService, PerceptionService with Perception data, CombatDirector;
  - Mastery: SkillTreeService, so the Mastery unlocks bought in Ye apply here too.
- Instances:
  - animations: the Registry, class-skill, style, swim and ledge folders, weapon Grips, the gun whips and heavy, Rapier lights 1/3/4, the sheathes;
  - 23 weapon animation ids updated to Ye's;
  - the Katana and Rapier models with the `Hilt` part (step A's fix);
  - gun VFX;
  - the seven Settings rows Ye added (Aim, CombatLog, Compass, FieldOfView, PostEffects, UIAnimations, UISounds);
  - one HUD stroke.

**Kept as the Tutorial's own, with small edits:**
- `CharacterHandler.DataManager` (the FlowData shim): added `WaitProfile`, which Ye's CharacterHandler uses.
- `ServerHandler`:
  - the client may now call `TraversalState` (Ye's JumpManager climbs, wall-runs and ledge-walks through it; without it, climbing never started on the server);
  - it now starts PerceptionService, SwimService and CombatDirector.
- `UIHandler`: starts CombatLogUI and UIMotion.
- `ProgressionService.ApplyCharacter`: applies the Mastery max-health bonus and publishes the skill tree (`SkillTreeService.Publish`), as Ye does.
- `TutorialController`: the Alchemy beat asks for X only from a player who has unlocked it. Ye's rule: Z comes with every path; X, C and V are bought in the Mastery tree. Before this, the beat asked everyone for X, which AlchemyService refuses until it's bought, so the beat couldn't be finished.
- Place settings: `StarterCharacter.Humanoid.WalkSpeed` 12 → 16 and `StarterPlayer.CharacterWalkSpeed` 20 → 16, matching Ye.

**Changed in Ye too (the same file in both places):**
- `AlchemyService`: the PuzzleService lookup on every cast is now optional (`FindFirstChild`). The Tutorial has no PuzzleService, so every cast failed there. Ye behaves the same. The repo copy was 128 bytes behind Ye before this, so this export also carries that earlier change.
- `ItemService`: using transmutation chalk looks up RitualService optionally, so a player carrying chalk into the Tutorial doesn't hit an error.
- Backups: Ye's `ServerStorage.RenseiBackups["Pre-TutorialSync_2026-10-20"]`.

**Tests** (Tutorial Play as ImWaymonTTK, one run from beat 1 to the finish with real keyboard / mouse input; the parry press went through the client's own `ClientActions.Run("Block")`, the same function the F key runs, timed off the Dummy's swing):
1. **Footwork:** a sprint (24 → 30 speed), a jump and two dashes passed.
2. **Report In:** passed.
3. **The Wall:** the first run found `TraversalState` missing (fixed above). After the fix, the server set `Traversal = Climb`, the climb moved 6 studs sideways (A / D), and W climbed over the top.
4. **Strikes:** Combat Mode, 4 Katana lights at the new timing, and a heavy.
5. **Break a Guard:** broken with light strings.
6. **Defend:**
   - three held blocks counted;
   - a test script inside the game showed each tap's parry window open for 0.25 s;
   - fixed-interval taps never lined up with a hit, so the press was timed off the Dummy's swing: the window opened at 83.31 and the hit at 83.40 came back `PerfectParried`.
7. **Alchemy:** casting failed on PuzzleService (fixed above), then Cryo Shift (Z) cast. X is asked for only once it's unlocked.
8. **The Bout:** the Dummy went from 300 HP to knocked in four light strings, and the grip (B) finished it.
9. **The Gate:** walking in ran the finale and fired `FinishTutorial` ("Studio can't teleport").

No game errors in the output after the fixes. The test scripts existed only during Play.

**Side effects:** the run went through the real save. Its `Flow` is TutorialDone = true and IntroSeen = true, the same as before for this account (Studio ignores TutorialDone and replays from beat 1).

**For the owner:**
- For a player without X, the Alchemy line reads "{X} for nothing yet". It's harmless, but the wording could change.
- Not covered by the run:
  - the swimming, gun, style and class-skill requests (copied, not exercised here);
  - EnemyService squads (the Tutorial only has the Dummy);
  - the Sword animation keyframe saves that carry a `Hilt` pose, which are Studio-only saves and weren't copied.

## 2026-10-20 — Admin panel: lock, audit, new tools, staff log

Owner request: "add more features to the admin panel and lock it behind me and ImWaymonTTK as the admins for the panel. Completely audit the admin panel for any extra features it could use for better debugging, gameplay, trading, etc." Decisions: only those two accounts, everywhere, Studio included; trading is a separate project, scheduled last (no Trades tab). Task D of the 2026-10-19 queue. The tool list below was approved in the session on 2026-10-20.

**Lock** (`ServerScriptService.AdminConfig`, now in the repo): `Users` = WhosRello (37484441) and ImWaymonTTK (4161273705), and nothing else. Removed: Rensei group rank 254+, and "anyone playtesting in Studio". AdminService re-checks the list on every call; before, it checked once at join and trusted that.

**Audit fixes** (`ServerScriptService.AdminService`)
- Every call re-checks the admin list (see above). A non-admin calling the remote gets a warning in the output, and a Discord line once per player per server.
- Give Item goes through `ItemService.Give`, so the bag limits hold (60 entries, 999 a stack). It used to add past both.
- The staff log was 60 entries in memory, lost when the server closed. It's now saved: see the staff log below.
- Kick refuses any admin on the list (it was "unless you're in Users").

**New tools** (`ReplicatedStorage.Modules.UI.AdminUI`; tabs are now Players, World, Self, Mod, Server, Logs)
- Players tab, for the selected player:
  - Give Mastery (1–100 points).
  - Refill posture, stamina and meter.
  - Clear Cooldowns: every `...ReadyAt` attribute plus the parry whiff. The dash's client timer isn't touched.
  - Snapshot / Restore: one saved copy of the player's current slot, in DataStore `RenseiAdminSnapshots`. Restore takes two clicks, refuses a snapshot from another slot, swaps the save in place, and sends the player back to rejoin so every system reloads from it.
  - Warn: a filtered on-screen banner to that player.
  - Save Details (Inspect): character, origin, slot, schema, level / EXP / money / stat points, alchemy, rank, Mastery, bag, quests, areas, codex, renown, Automail, last snapshot.
- Self tab:
  - Fly: WASD, Space up, Ctrl down, Shift for 150 instead of 60. A LinearVelocity + AlignOrientation on your own client.
  - Noclip: puts collision back exactly as it was.
  - Teleport To any `RenseiArea` area (14 now), dropped onto the ground.
  - Refill and Clear Cooldowns for yourself.
- Mod tab: Ban by the selected player or a typed UserId (offline too). Hours, blank for permanent, and a reason they see (filtered). Ban takes two clicks and refuses admins. Unban by UserId. Bans use Roblox's ban API (every server of the experience, alt accounts too); our own list of them is in DataStore `RenseiAdminBans`, because Roblox has no call that lists bans.
- Server tab: server tag, place version, uptime, physics FPS, heartbeat, memory, players, live enemies, Discord status, staff log save status, and every player's ping.
- Logs tab: the last 200 staff actions across all servers, each with its server tag (Studio sessions show `[Studio]`).
- Dangerous buttons (Ban, Restore) take two clicks: the first turns the button into "Confirm?" for 4 s.

**Staff log**
- Every action that ran is saved to DataStore `RenseiStaffLog` ("Recent", newest first, 200 kept). It's written every 15 s and when the server closes.
- **Discord:** every action, and any non-admin remote call, posts to Discord when the experience has a secret named `STAFF_WEBHOOK` (Creator Dashboard → the Rensei experience → Secrets, allowed domain `discord.com`). Posts are batched (one every 2.5 s, up to 15 lines), use `allowed_mentions` none, and back off when Discord rate-limits. The Server tab shows ON / OFF. Studio always shows OFF, because it can't read the live secrets.

**Tests** (Rensei Play as ImWaymonTTK, the remote called from the client, and the panel driven with real F2 / mouse clicks):
- The panel was built for ImWaymonTTK. State returned the server stats, the 14 areas, bans and the log.
- Inspect matched the save (Level 3, Money 120, Mastery 4, Ice, Rank 1, slot 1, schema 5).
- Snapshot saved. Give Mastery took it 4 → 5 → 105 (500 was clamped to the 100 cap, as Give Money clamps). Refill and Warn ran. Give Item Apple stacked.
- Clear Cooldowns cleared a live parry cooldown and whiff (2 attributes).
- Refused, as intended:
  - banning WhosRello or ImWaymonTTK;
  - a ban with no UserId;
  - an unban with no UserId;
  - kicking yourself;
  - an unknown area.
- Fly: Space for 1 s climbed 60 studs, it hovered with no drift, the server saw the same height, and Fly off dropped back to the ground. Noclip: 0 colliding parts while on, 2 restored when off. Teleport to Foundry Yard and Lindenmoor landed on the ground.
- UI: the six tabs fit, and Server, Mod, Logs and Players (Select, Inspect) rendered. Ban's first click showed "Confirm?" and disarmed after 4 s.
- Restore, by the real two clicks, ran and sent the player to rejoin. After rejoining, the save was back to Mastery 4, so the test changes were undone. The Logs tab showed every test action, including the Restore saved on close, across server sessions.
- A bug caught in testing and fixed: the new server numbers changed on every 2 s poll, so every tab rebuilt and swallowed clicks. Now they only count while the Server tab is open, and ping is only shown there.
- **Not tested:**
  - a real ban or unban (it would ban a real account; `BanAsync` may also refuse in Studio);
  - Discord posting (needs the live secret);
  - a non-admin account (needs a second account);
  - two admins in one server.
- No game errors in the output.

**Side effects of testing:** about 15 `[Studio]` entries in the live staff log, and one snapshot of ImWaymonTTK's slot 1 in `RenseiAdminSnapshots`.

**For the owner:** add the `STAFF_WEBHOOK` secret (a new Discord webhook for the staff channel) to turn on the Discord log. Rensei had no Discord hook before this.

Backups: `ServerStorage.RenseiBackups["Pre-AdminD_2026-10-20"]` (AdminConfig 520 bytes, AdminService 14269, AdminUI 15004).

## 2026-10-20 — Parry like VV: Ultimatum

Owner request: "make the parrying more like VV ultimatum's" (design approved 2026-10-19). Rensei only; all new numbers are PROPOSALS, marked `-- PROPOSAL (VV parry 2026-10-20)` in TuningConfig. Picked up after the 2026-10-19 cloud session hit its limit (task C of A–E).

**What changed**

| Rule | Before | Now |
|---|---|---|
| Parry window (tap F) | 0.22 s, wider at high ping | 0.25 s, ping allowance kept |
| Cost of a landed parry | 5 posture | nothing |
| What it does to the attacker | 10 posture, 0.7 s stun | 30 posture, 1.0 s stagger (ParryFlinch); 4 parries from full break them |
| A parry that empties the attacker's posture | — | full guard break: Posture.BreakStun (1.4 s), dazed, `GuardBrokenUntil` set so they can't parry out |
| Missed tap | parry locked 1.3 s from the press | a 0.35 s whiff with no guard and no parry, and the parry stays locked 0.9 s after the window (1.15 s from the press). Holding F through the window isn't a whiff: the guard is already up |
| Landed parries | chain, no cooldown | unchanged |
| Holding F (block) | chip damage, posture drain, guard break at 0 | unchanged |
| Red (UNBLOCKABLE) attacks | no block, no parry | unchanged: dodge only |
| Enemies | Elite duelists parry with the Block skill | same skill, so the same rules: their parries cost them nothing and punish you the same way, and their missed taps whiff |

Left out, as agreed: VV's yellow / orange attack colours (the guides disagree on what they mean).

**Code**
- `Data.Rensei.TuningConfig` — `Parry`: Window 0.25, Cooldown 0.9 (from the window's end), new `WhiffTime` 0.35, AttackerPostureDamage 30, AttackerStun 1.0, DefenderPostureCost 0. `FailLockout` (read by CooldownUI) is now Window + Cooldown.
- `Skills.Combat.Block` — `ParryReadyAt` = press + window + cooldown. When a window closes without landing and F is already released, `ParryWhiffUntil` is set. A press during a whiff waits it out (server and client), then guards with no parry window.
- `Managers.DamageManager` — the PerfectParried branch skips the defender's posture cost when it's 0, and a parry that empties the attacker's posture runs the guard-break path (BlockBreak FX, Dazed, no movement) instead of the flinch. The result stays `PerfectParried`, so ProgressionService's Parry training and the parry drill still count it.
- HitParry (pressing F during hitstun) is unchanged: it still costs 10 posture up front and always starts the cooldown, so it can't escape every combo.

**Tests** (Rensei Play, real F presses through the client's input path; a server test script hit the player the moment the parry window opened):
- T1 parry: `PerfectParried`, player posture 100 → 100 and HP unchanged, Dummy posture 100 → 70, stagger 0.98 s, cooldown cleared, chain bonus set.
- T2 chain: three taps 0.5 s apart all landed: Dummy 100 → 70 → 40 → 10, player posture 100 throughout.
- T3 break: a fourth chained parry took the Dummy 10 → 0, which became a guard break with a 1.38 s stagger.
- T4 whiff: a tap with nothing incoming closed at 0.27 s and whiffed until 0.62 s. Pressing and holding F again at 0.35 s opened no parry window (cooldown), and the guard came up at 0.72 s. A later held press opened a window, then guarded, with no whiff.
- T5 enemy: the Elite's Block skill pressed like its AI (`Start(true)`) parried the player's light: player posture 100 → 70, stagger ~1.0 s, Elite posture unchanged. Its missed tap whiffed with the parry locked about 0.8 s more.
- Not tested: the Elite's own AI choosing to parry during a real fight (it didn't target me in the test), and how the whiff feels with real network latency.
- No game errors. The test scripts existed only in Play and are gone. The profile wasn't touched: the tests called DamageManager directly, not `RecordHit`, so no Parry training was paid.

**Not done:** the Tutorial was not mirrored (task E).

Backups: `ServerStorage.RenseiBackups["Pre-VVParry_2026-10-20"]` (Block 7215 bytes, DamageManager 20810, TuningConfig 87969, CooldownUI 5920).

## 2026-10-19 — M1 speed pass

Owner request: "fix some m1 strings being too slow (I want them to be within reasonable timing for their respective class type)". Design and target ranges approved. Rensei only; all new numbers are PROPOSALS, marked `-- PROPOSAL (2026-10-19 M1 pass)` in TuningConfig.

**Measured string times** (Rensei Play, real input path: a LocalScript calling `ClientActions.Run("Attack", ...)`, held M1 and 0.12 s clicks, on `World.Live.Dummy`; press to the end of the finisher's recovery, server clock):

| Class | Target | Config before → after | Measured before (held / clicks) | Measured after (held / clicks) |
|---|---|---|---|---|
| Daggers | 1.6–1.8 | 1.72 → 1.66 | 1.83 / 1.84 | 1.72 / 1.75 |
| Fists (Brawler) | 1.8–2.0 | 2.31 → 1.87 | 2.45 / 2.45 | 1.93 / 1.97 |
| Gauntlets | 1.8–2.0 | 2.12 → 1.88 | 2.20 / 2.25 | 1.93 / 1.95 |
| Boxing | 1.8–2.0 | 2.15 → 1.88 | 2.29 / 2.28 | 1.94 / 1.97 |
| Lethwei | 1.8–2.0 | 2.06 → 1.88 | 2.20 / 2.18 | 1.93 / 1.98 |
| Rapier | 1.8–2.0 | 1.94 → 1.88 | 2.09 / 2.09 | 1.94 / 1.97 |
| Guns (whip) | 1.9–2.1 | 1.99 (unchanged) | 2.17 / 2.10 | 2.03 / 2.07 |
| Sword (Katana) | 2.0–2.2 | 2.40 → 2.06 | 2.53 / 2.57 | 2.12 / 2.15 |
| Greatsword | 2.8–3.0 | 3.81 → 2.87 | 3.99 / 4.00 | 2.94 / 2.98 |

**Hidden delay found and fixed** (`Managers.AttackRunner`): real strings ran 0.11–0.18 s over their config.
- `AttackRunner.Run` waited for the attack by polling Heartbeat; that poll ran before the attack's last Heartbeat, so every swing returned a frame late. It now waits on a BindableEvent.
- Each phase's wait ends on the first frame past its time and the overshoots added up. The recovery now ends on the attack's own clock (capped at 0.05 s; HitTimes attacks keep their timing).
- Left: about one frame between swings inside WCS (skill end → restart) and the press → server frame; real strings are now config + ~0.05 s held, + ~0.08 s clicking.

**What changed** (hits 1–3 mostly; Damage / Posture / Reach / Hitbox untouched; the finishers keep their knockback and stun):
- Fists: 1–3 Startup 0.22 → 0.19, Recovery 0.16 → 0.10; finisher Startup 0.28 → 0.26, Recovery 0.55 → 0.40.
- Gauntlets: 1–3 Startup 0.2 → 0.18, Recovery 0.14 → 0.10; finisher Recovery 0.5 → 0.44.
- Boxing: 1–3 Startup 0.22 → 0.19, Recovery 0.16 → 0.10. Lethwei: 1–3 Recovery 0.2 → 0.14.
- Sword: 1–3 Startup 0.24 → 0.22, Recovery 0.18 → 0.10; finisher Recovery 0.50 → 0.46.
- Rapier: hits 1 / 3 Startup 0.18 → 0.21 (see speed-ups), 1–3 Recovery 0.14 → 0.10. Heavy Startup 0.34 → 0.47.
- Greatsword: 1–3 Startup 0.40 → 0.32, Recovery 0.32 → 0.13, Stun 0.55 → 0.75 (hit 3: 0.85); finisher Startup 0.55 → 0.50, Recovery 0.6 → 0.52.
- Daggers: 1–3 Recovery 0.12 → 0.10; hit 3 AnimPeak 0.45 → 0.19 (see below).
- Lunging Thrust (Rapier dash attack): AnimPeak 0.29 → 0.33, the new Rapier_Light2 peak.
- Comments: Rapier header (its idle is its own), `Downed.Grips.Rapier` (the grip moves the blade).
- Enemies use the same tables, so enemy strings are faster too (a Greatsword bandit most of all).

**Stun-gap check** (no infinite combos): for hits 1–3, Stun (MinStun 0.6 floor) ≥ Recovery + next Startup + Active on every class. Gaps now 0.32–0.50 s, Greatsword 0.57 / 0.57 / 0.77 against 0.75 / 0.75 / 0.85. Before this pass the Greatsword string was not a true combo (the target left stun between every hit); now it holds. Measured in Play: the target's Stun never dropped between hit 1 and hit 4 on any class. MaxChain 3.0 stays; the Greatsword chain is ~2.9 s.

**Animation speed-ups** (AttackRunner plays an animation at AnimPeak / (Startup + Active / 2)):
- Windups after the pass: Sword 1.23–1.35×, Greatsword 1.37–1.39×, Boxing 1.39×, Rapier 1.43–1.55× (was 1.77× on hits 1 / 3), Rapier heavy 1.38× (was 1.85×). Fists and Gauntlets have no AnimPeak (1×).
- Over 1.6×, not changed: Daggers 1 / 2 / 4 at 2.0 / 2.16 / 1.75× (already in range; fixing it needs longer startups), and Lunging Thrust at 1.74× after the new peak.
- Daggers M1 3: the new sheet id (wired 2026-10-19) is 0.417 s long but kept the old 0.45 peak, so it played clamped at 2.2×. Re-measured from the keyframes (fastest arm / torso turn between 0.133 and 0.250): 0.19, so 1.03×.
- The follow-through after the impact plays faster with the shorter recoveries (AnimationManager Retime, capped 3×): up to 2.3–2.9× on Fists / Gauntlets hit 3, Greatsword 1–3 and Rapier 1–3.
- Verified in Play: Rapier_Light1–4 played at 1.55 / 1.53 / 1.55 / 1.43, Rapier_Heavy at 1.38.

**Tests:** Dummy, every class plus Boxing and Lethwei, held and clicked, before, after the AttackRunner fix alone, and after the retune; all 4 hits landed, no stun gaps. Held strings on an `AIPassive` Grunt (health raised) land the same times (Rapier 1.92–1.93, Daggers 1.72–1.73, Fists 1.92, Greatsword 2.93; misses there were the Grunt walking out of reach). Rapier heavy lands 0.47 s after the press. No game errors. The player's weapon, style and Combat Mode were restored and the profile matched its snapshot (Mastery had moved and was restored).

**Not done:** the Tutorial was not mirrored (out of time); its TuningConfig has an older weapon block. The parry drill (`WorldChallenges`) attacks with fist Light1, now 0.19 s startup.

Backups: `ServerStorage.RenseiBackups["Pre-M1Timing_2026-10-19"]` (TuningConfig 85093 bytes, AttackRunner 14575 bytes). AttackRunner's export also brings the Automail Piston Strike block that was in Studio but not yet in the repo.

## 2026-10-19 — Animation sheet: Rapier set, Dagger idle, grips wired

Owner request: "fix all animations with the ones from the spreadsheet" (design approved). Rensei, mirrored to the Tutorial where the same objects exist.

- **What players notice:**
  - the Rapier has its own sheet set: new M1 1–4, CRIT, idle and Flurry (T), and a Rapier grip finisher (GRIP + GRIP VICTIM) instead of the execution;
  - the Dagger idle is the published one, with the legs animated (the hips sway);
  - Dagger M1 3 is the new upload;
  - the Katana / Rapier draw uses the new Katana Unsheathe (and plays it backwards to sheathe).
- **Wired** (`AnimationId` = the sheet id, attribute `SheetId`; the old id kept as `PreviousId`, any Studio `Save` kept as the fallback; the published id wins in Studio and live, `AnimationManager.Playable`):
  - `Rapier_Light1`–`4`: 88629079862060, 106111566774072, 94932519812153, 140341502749537 (0.75 / 0.72 / 0.75 / 0.72 s);
  - `Rapier_Idle` 122141349611647 (2.23 s loop), `Rapier_Heavy` 136861400985819 (1.35 s), `Rapier_Skill` 79473015992584 (2.0 s; markers Barrage 0.43, BarrageEnd 1.05, FinalStab 1.35);
  - new `Grips.Rapier_Grip` 85813024737924 (1.23 s) and `Grips.Rapier_Gripped` 75188810841150 (1.80 s);
  - `Daggers_Idle` 96820335600899 (4.93 s loop), `Daggers_Light3` 130478011394399 (0.42 s; was 80421062677398);
  - `Sword_Equip` 114589995116351 (0.43 s; was a Studio save).
- **TuningConfig:**
  - `Downed.Grips.Rapier = {Grip = "Rapier_Grip", Victim = "Rapier_Gripped", Length = 1.23}`. The brief said 1.13; the animation loads at 1.23 s on the Animator, and `Length` is the gripper animation's length, so the pair now fills the 2 s grip exactly (played at 0.62×);
  - Rapier `AnimPeak`, **measured**: Light1 0.37 → **0.38**, Light2 0.37 → **0.33**, Light3 0.37 → **0.38**, Light4 0.37 → **0.40**, Heavy 0.43 → **0.72**. Startup / Active / Recovery unchanged;
  - **method:** from each KeyframeSequence, the blade tip's position through the R6 chain Torso → Right Arm → Hilt (the animator's Hilt joint at (0, −0.65, 0); the tip 4.25 studs down the blade, from our Rapier's blade mesh). A keyframe's speed is the mean of its two neighbouring keyframe intervals; the peak is taken in the forward thrust. A 240 Hz resample agrees (peak forward speed at 0.377 / 0.385 s for M1 1 / 3, 0.735 s for the CRIT);
  - effect: with `AnimSpeed = AnimPeak / (Startup + Active / 2)` the M1s play at 1.77 / 1.53 / 1.77 / 1.43× and the CRIT at **1.85×** (was 1.10×). Part B re-times the windows.
- **The Rapier's blade bone (follow-up, controller ruling): the grip is now `Hilt`, so the sheet's animations move the blade.**
  - **Finding:** the Animator matches a pose to a joint by the **part** names it joins (Part0 / Part1), not by the Motor6D's name. Tested on fresh rigs in Play: motor `Hilt` + part `Ninjato` → the grip joint turned 0° in M1 1 and the crit; part `Hilt` (motor either name) → 90° and 178°. So the preferred "name only the motor" field would not have moved the blade.
  - **Change (Rapier tool only, no combat code):** `Assets.Items.Weapon.Rapier.Ninjato` renamed `Hilt`, and its `MotorC0` / `MotorC1` moved to the animator's joint, (0, −0.65, 0) / (0, 0.091, 0), the katana's values (was (0, −1.059, 0) / (0, −0.318, 0)). The rest pose is the same (the part sits (0, −0.741, 0) from the arm either way), so the holster, the hold and the swap blend are unchanged. `WeaponManager` already names the motor after the part, so the motor is `Hilt` too. Only its header comment changed. Attribute `GripNote` on the part.
  - **Checked first:** no script looks up `Ninjato` or the weapon motor by name (holster weld, swap blend, DownedManager, ragdoll, StatsUI, IceAxe all go by object / Part0 / attributes).
  - **Also checked:** the holster weld places the part itself by `HolsterC0` (no change); the client swap blend uses each joint's own `C1`; enemies arm through the same tool (`WeaponManager.Give`; the Elite "Bandit Duelist" carries a Rapier). The repo doesn't mirror item models (`Scripts/` only), so this entry is the record of the tool change.
  - **The Rapier's animations and their weapon tracks** (each KeyframeSequence loaded, weapon poses listed):
    - `Right Arm > Hilt`: M1 1–4, crit, idle, Flurry, the grip, and `Rapier_Ren` (class skill; also keys `Left Arm > Hilt2`).
    - M1 3, M1 4 and the grip also carry a second, unused `Hilt` (or mesh) pose under a "SheatheNightshade Rapier" pose our rig lacks. Their `Right Arm > Hilt` track still drives the blade (measured below).
    - `Rapier_Walk` (gun rig): `Right Arm > Hilt` at identity, plus pistol parts and `Left Arm > Hilt2`. While walking, the blade sits in its rest grip (before: `Sword_Hold`'s 29° pose). Not re-checked for leg clipping.
    - `Sword_Hold`'s Save (the Rapier's hold) keys both `Ninjato` and `Hilt` (the katana fix), both at the same 29.4°, so the hold is unchanged.
    - No weapon track: `Sword_Equip` (the new unsheathe), `Sword_Run`, `Rapier_SpeedLunge` (class skill), `Rapier_Gripped`.
    - **Nothing the Rapier uses keys only `Ninjato` or `Handle`, so nothing needs re-exporting for the rename.**
  - **Tests (Rensei Play):**
    - **First run** (previous pass): M1 1–4 and the crit all hit the Dummy. The blade turned 107.6° / 117.8° / 109.8° / 118.9° / 178.5° relative to the Right Arm.
    - **Verification run** (client, every frame):
      - Rapier given → holstered (weld on, 0.000 studs from `HolsterC0`) → drawn (motor `Hilt`, Right Arm → `Hilt`, on).
      - Idle (`Rapier_Idle`, 3 s): the blade is held at the idle's own 24.8° pose, out to the right and forward. The tip is 4.1 studs right and 2.7 forward of the torso, and no blade point is inside the torso or legs.
      - Within each attack, relative to the Right Arm, the blade turned 101.9° / 117.8° / 109.8° / 121.0° in M1 1–4 and 176.6° in the crit, with the tip moving 6.5–7.3 studs. Nothing passed through the body.
      - Rapier grip finisher on the knocked Dummy: `Rapier_Grip` played, and the blade turned 105.8°.
      - Bandit Duelist (enemy): motor `Hilt`; with `Rapier_Light1` + `Rapier_Heavy` played on it, its blade turned 178.9° as seen by the client.
      - **Before the fix** (the backup tool with part `Ninjato`, swapped in at runtime): M1 1 and the crit played, and the blade turned 0.0–0.1° (it stayed in `Sword_Hold`'s pose).
      - Sheathe → holster (0.000 studs) → re-draw → sheathe, all OK. Katana: holstered → drawn → sheathed, motor `Hilt`, 0.000 studs, unchanged.
      - No errors outside CorePackages.
    - **Player restored:** the Renetti is back, Combat Mode is off, and the position is restored.
    - **Profile:** snapshotted and compared. The first run was unchanged. In the second run the profile differed, and it was restored in place to an exact match (cause not isolated; the Dummy has no `EnemyType`, so a finisher on it records no deed).
  - **Tutorial not changed:** its Rapier and Katana tools are both still `Ninjato` with the old joint (the katana fix was never mirrored there), and its WeaponManager is a different file (25385 bytes).
  - **Backups:** `Assets.Items.Weapon.Rapier` and `WeaponManager` added to `RenseiBackups["Pre-SheetWire_2026-10-19"]` (Rensei).
- **Tutorial:** mirrored `Rapier_Light2`, `Rapier_Idle`, `Rapier_Heavy`, `Rapier_Skill`, `Daggers_Idle`, `Daggers_Light3`, `Sword_Equip` (all seven ids load there). The Tutorial has no `Rapier_Light1`/`3`/`4` or grip animations, and its TuningConfig has an older Rapier block (lights 1/3/4 borrow the sword set, Light2 `AnimPeak` 0.29, Heavy 0.34) and no `Downed.Grips`, so its TuningConfig wasn't changed.
- **Tests (Rensei Play, real profile snapshotted and restored, 0 differences):**
  - all 12 animations load on the player's Animator (lengths above);
  - Rapier given + drawn: the draw played `Sword_Equip` 114589995116351, then `Rapier_Idle` 122141349611647 plays at Idle priority while standing;
  - M1 string on the Dummy: the four sheet ids played in order and all four hits landed; the CRIT played and hit. Hits register at the start of the active window, 0.17 s after the press for M1 1–3 (animation time 0.30 / 0.26 / 0.30), 0.24 s for M1 4 (0.34) and 0.33 s for the CRIT (0.61); the measured peaks sit mid-window;
  - knocked Dummy + grip with the Rapier drawn: style `Weapon`, `Rapier_Grip` on the player and `Rapier_Gripped` on the Dummy, both at 0.62×; the grip finished at 2.0 s (track at 1.23 s);
  - Daggers: `Daggers_Idle` 96820335600899 plays; the left hip swings 0.7°–9.0° and the right −16.7°–−5.9° over 3 s;
  - no errors in the console;
  - the player was restored: the Rapier / Daggers removed, the original Renetti back, Combat Mode and position restored.
- **Still broken uploads (re-upload, then put the new id in `AnimationId`):** Daggers_Equip 82218741773055, Daggers_Unequip 120069108676683, Greatsword_Equip 122309498454912, Greatsword_Unequip 78181583295596, Greatsword_Walk 76985284126069, Greatsword_Gripped 136479651286488, Sword_Unequip 135958788270981, Sword_Walk 110642878390298 ("KeyframeSequence loaded is not valid"). They stay on their Studio saves.
- **Not changed, for the owner:** the Rapier dash attack Lunging Thrust (`WeaponDashAttacks.Rapier`) uses `Rapier_Light2` with `AnimPeak` 0.29 (the old animation; the new one peaks at 0.33). Flurry's timing hasn't been fitted to the new markers yet.
- **Backups:** `ServerStorage.RenseiBackups["Pre-SheetWire_2026-10-19"]`: in Rensei, the 10 changed Animation objects + TuningConfig; in the Tutorial, the 7 changed Animation objects.

## 2026-10-19 — Plan 1: Foundation

**Summary (Plan 1 complete: slices R1, S1, R2 of the Morality × Reputation spec).**
- **What players notice:**
  - faction standing now depends on *where* a deed has been heard. A deed counts at once in the region where it happened, if anyone saw it. Word then travels: dispatch reaches the City's Authority in 2 min, and gossip reaches everyone there in 10 min. Being offline doesn't stop it: on rejoin, the word that travelled meanwhile arrives at once, with a tier banner for any change;
  - **Lise's Circle hit** (`reported_lise`, Circle −15) no longer counts everywhere at once. It lands where you stand when you choose, with the default 2 witnesses' worth. In the Foundry Yard the Circle isn't present, so it isn't heard there. Gossip carries it to the City in 10 min, the Circle hears it there, and it counts half, because the City is one of the Circle's two regions (City, Lindenmoor). At strength 2, word goes only one hop, so it never reaches Lindenmoor. The Authority's +15 reaches the City by dispatch in 2 min (full);
  - **enemies notice you by sight** (view cones, line of sight, movement), investigate, search, then stay wary. A hit still alerts them at once. Arena and trial foes are unchanged;
  - every character gets a **birth deed** from their origin, heard everywhere;
  - a player who saw another's deed can report it at a desk (`RumourService.Report`), which lands it there at once. Nothing in the world calls it yet: the desks come with a later plan (the roadmap's Plan 7 has the bounty desks).
- **Placeholders for you to review (all PROPOSAL / (new)):**
  - the six community names;
  - the birth offsets;
  - the watchers list (which NPCs witness, and for which faction; the five Alchemy Trainers aren't watchers);
  - the region **Wilds** (the Forgotten Sites);
  - all timings and ranges: rumour minutes per link, perception cones / rates / timers, the witness weights, the 30-min report window, the 60 s rumour tick.
- **Tests (final run, after Task 10):**
  - Edit:
    - `Test_TestKit` PASS 4 / FAIL 0;
    - `Test_Schema5` PASS 4 / FAIL 0;
    - `Test_Regions` PASS 5 / FAIL 0;
    - `Test_Reputation` PASS 7 / FAIL 0;
    - `Test_Perception` PASS 4 / FAIL 0;
    - `Test_Witness` PASS 2 / FAIL 0;
    - `Test_RumourCore` PASS 8 / FAIL 0;
  - Play (real profile snapshotted and restored, 0 differences after each):
    - `Play_Morality` PASS 3 / FAIL 0;
    - `Play_Perception` PASS 6 / FAIL 0;
    - `Play_Rumours` PASS 2 / FAIL 0;
  - the rejoin catch-up check passed (see Task 10).
- **Backups:** every script that existed before was cloned into `ServerStorage.RenseiBackups["Pre-Foundation_2026-10-19"]` before it was edited, in each place it was edited:
  - ProfileMigrations, ProfileData, Factions, Deeds, MoralityService, EnemyService, ServerHandler and PerceptionService;
  - the `_preT8fix` and `_preT10` copies.

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
- Task 4: Reputation, place by place (Rensei):
  - new `Rensei.Reputation` (pure functions over a profile's `Morality`): a deed's Standing counts in a region only for the factions there that have heard of it, recorded once per faction per place in `Morality.Places[Region].Known[DeedId][Faction]` (the time it was heard);
  - `Land / LandEverywhere / Landed / PlaceStanding / GlobalStanding / Renown / Seed`. The global standing stays a cache: each faction's place standing summed over regions and divided by `Regions.Count(F)` (equal weights, a PROPOSAL), so a deed heard everywhere counts in full and one heard in half a faction's regions counts half;
  - Renown counts Public deeds (or deeds discovered as Public) once they've been heard somewhere;
  - `Seed` (schema 5, once per profile, sets `Morality.Seeded`): deeds that already counted before places existed (Local / Public / discovered) are heard everywhere, stamped with the deed's own time, so no old save loses standing. Private deeds stay unheard;
  - repeatable deeds (review finding, kept by ruling and now documented in the header): a place that has heard of a deed counts every repeat (the ledger's Count), so later repeats count there at once. This is accepted for small capped deeds; the owner can switch to per-place counts later;
  - nothing calls it yet (MoralityService and RumourService will); no existing script changed;
  - test `Test_Reputation` (Edit mode): RED was "Reputation is not a valid member", then PASS 7 / FAIL 0.
- Task 5: MoralityService on places (Rensei):
  - **what players notice:** faction standing now comes from where a deed has been heard. A Local / Public deed is heard at once by the factions in the region where it happened (if anyone perceived it; dialogue and quest deeds count as 2 witnesses for Local, 4 for Public, PROPOSAL), and Rensei.Reputation sums it into the global standing; a Private deed is heard nowhere until discovered. Conduct and Trust stay personal and move at once. Old saves are seeded once on join (`Reputation.Seed`), so nothing they had is lost;
  - birth deeds: on first join in Ye the origin's `born_<Origin>` deed is recorded once, quietly, and heard everywhere (`RecordBirth`);
  - new API: `Record(Player, DeedId, Quiet, Ctx)` (`Ctx.Region / Strength / Witness / Evidence`), the `Recorded` listener list (`Info = {Region, Strength, Scope}`), `Refresh(Player)`, `RecordBirth(Player)` and `RegionOf(Character)`. A grip finisher now records with `{Witness = true}`; until WitnessService exists (Task 8) it falls back to strength 2;
  - backup `ServerScriptService_MoralityService` in `Pre-Foundation_2026-10-19`; MoralityService 8072 → 11853 bytes (FNV b0a56c81);
  - test `Play_Morality` (Play mode, real profile snapshotted and restored): RED was "FAIL JoinSeededAndBorn: seeded on join" (PASS 1 / FAIL 2), then PASS 3 / FAIL 0; no MoralityService errors in the console;
  - existing content (Step 5): `Record(Player, "told_on_tobin", true, {Region = "Foundry"})` moved `Standing.Foundry` 0 → -3 (full, since the Foundry faction is only in the Foundry); the profile was restored afterwards (deep compare: 0 differences).
- Task 6: Perception maths (Rensei):
  - new `Rensei.Perception`, the pure numbers and maths of what NPCs notice. PerceptionService (Task 7) will run it, and the eye-sigil HUD (Plan 2) will read it:
    - timing and budget: `Tick` 0.2 s, `ActiveRange` 80, `RaysPerNpc` 3, `RaysPerTick` 120;
    - cones: `Primary` 110° (full rate) and `Peripheral` 160° (half rate); behind that, nothing;
    - thresholds and timers: `Suspicious` 0.35, `Drain` 0.25/s, `Memory` 3 s, `InvestigateTime` 8 s, `SearchTime` 25 s, `CautiousTime` 180 s;
    - multipliers: `CautiousMult` 1.3, `CallRadius` 40, `Falloff` 0.75 (a range's edge fills at 25%);
    - movement multiplier: x1 / x1.5 / x2 at speed ≤20 / ≤27 / above;
    - five perception types (Grunt, Elite, Agent, Hunter, Witness), each with a Range and a Fill rate;
    - `EnemyTypes` maps TuningConfig enemies to perception types (unlisted enemies are Grunt);
    - `AlwaysAware`: Sparring and the five Trial foes keep the old distance aggro;
  - functions: `ConeMult(Look, To)` (horizontal angle only, so someone straight above counts as seen), `MoveMult(Speed)` and `Rate(Type, Dist, Cone, Visible, Move, Exposure, Cautious)`, which gives awareness per second. Light (Exposure) and crouching arrive in Plan 2;
  - **every perception number is a PROPOSAL (spec §18.7)**, for the owner to tune;
  - nothing calls it yet; no existing script changed;
  - test `Test_Perception` (Edit mode): RED was "Perception is not a valid member", then PASS 4 / FAIL 0.
  - review fix: the movement breakpoints moved from 17 / 24 to 20 / 27. These are the midpoints between the game's gaits (walk 16, run 24, sprint 30 in Run.lua), so physics jitter and speed bonuses don't flip a runner into a sprinter. The test now covers 24 (run) and 24.4 (run with jitter): RED was "run with jitter: expected 1.5, got 2", then PASS 4 / FAIL 0.
- Task 7: PerceptionService and enemies, slice S1 (Rensei):
  - **what players notice:**
    - open-world enemies no longer aggro by distance alone. They notice you through a view cone with sight lines to your head, torso and feet. Distance, movement and Cautious all speed it up: sprinting is noticed about twice as fast as standing or walking;
    - an enemy that half-notices you (Suspicious, 0.35) walks to where it saw you and gives up after 8 s;
    - at full awareness it fights (Alert) through the same squad combat as before, and NPCs within 40 studs come to look;
    - if it loses sight of you for 3 s, it sweeps a widening circle around where it lost you for 25 s, then walks home and stays Cautious for 3 min (sight x1.3);
    - **a hit alerts it at once**, even from behind;
    - **arena / trial foes are unchanged:** Sparring and the Trial foes (`Perception.AlwaysAware`) keep the old nearest-player aggro;
    - the rig attribute `Awareness` shows the phase;
  - new `ServerScriptService.PerceptionService`:
    - `Register / Unregister / Tracks / Awareness / PhaseOf / Target / Goal / Lose / Reset / Alarm / Noise / Perceived`;
    - `ExposureOf`, which returns 1 until Plan 2;
    - `SetAuto / Step`, for tests;
    - world watchers tagged `RenseiWatcher` (none placed yet);
    - started in ServerHandler after MoralityService. It listens to `ProgressionService.HitListeners` for hits;
  - EnemyService:
    - `Spawn` registers every enemy that isn't AlwaysAware;
    - `Brain`'s old `PickTarget` is now `NearestTarget`, used for arena foes only. The new `PickTarget` asks `PerceptionService.Target` and calls `Lose` past the leash;
    - with no target, the enemy walks to `PerceptionService.Goal` (investigate / search) while that's inside the leash, else home as before;
    - backups of EnemyService and ServerHandler are in `Pre-Foundation_2026-10-19`;
  - test `Play_Perception` (Play mode, the passive test Grunt): RED was "PerceptionService is not a valid member", then PASS 3 / FAIL 0. No `PerceptionService:` warnings in the console;
  - cost (game VM, 50 × `Step(0.2)`, 12 enemies tracked):
    - far from all of them: 0.012 ms/step;
    - beside a camp (3 in range): 0.138 ms/step;
    - all 12 forced to update: 0.100 ms/step;
  - scripted feel checks (Play, the Grunt camp at (230, -889), both Grunts passive):
    - walking up from 30 studs behind to 5 studs: awareness stayed at 0;
    - time to Alert at 15 studs in front:
      - standing: 1.77–1.90 s;
      - walking: 2.13 s;
      - running: 1.42 s;
      - sprinting: 1.10–1.18 s;
    - the second Grunt went Suspicious each time (called in);
    - wall plus 45 studs away: target dropped at 3.15 s and it searched up to 23 studs out. It turned Cautious at 28.1 s, back at its spawn. Re-sighted while Cautious, it alerted in 1.04 s instead of 1.50 s;
    - a hit from behind (fed through `ProgressionService.RecordHit` → HitListeners): Unaware → Alert at once, targeting the hitter;
  - **for you to feel-test (needs real keyboard and mouse):**
    - sneaking up behind a Grunt camp, and whether the cone feels fair;
    - whether sprinting past in front feels about twice as noticeable;
    - breaking line of sight around real cover, and how the 25 s search sweep looks;
    - a real M1 from behind starting the fight instantly;
    - **surprises to watch for:**
      - nothing alerts an Elite before its first hit, so its parry AI only engages once it's Alert;
      - walking alone doesn't add to noticing (x1 up to speed 20), so walking in the open is noticed at the standing rate.
  - review fix: groups no longer hide each other: an NPC out of sight rays for a player holds that player's awareness and catches up next tick. New test `HoldsWhenNotChecked`; `Play_Perception` PASS 4 / FAIL 0.
- Task 8: WitnessService and the world's watchers (Rensei):
  - **what players notice:**
    - a grip finisher's witnesses are now real. Only NPCs that actually saw you within the last 3 s (`Perception.Memory`) count as witnesses. This is after the review fix below; the first version also counted any NPC still Suspicious of you;
    - an NPC behind you, out of its cone, doesn't see the deed. Once 3 s pass without it seeing you, it no longer counts. With no NPC witness, no player witness and no evidence, strength is 0 and there's no rumour;
  - new `ServerScriptService.WitnessService`:
    - `Weights` (PROPOSAL): `Npc` 1, `Agent` 2 (Carrier: State / Circle agents), `Evidence` 3;
    - `Strength(Npcs, Evidence)` is pure;
    - `Capture(Player, DeedId, Evidence)` returns `{Npcs, Players, Strength}`. NPC witnesses come from `PerceptionService.Perceived`. Player witnesses are other players within `Identities.WitnessRange` (60) with a clear line of sight. A missing character means no player witnesses, not an error;
    - `Note / CanReport / Forget` keep player witnesses in server memory, so they can report at a desk later (RumourService). `ReportWindow` is 1800 s (30 min, PROPOSAL). The memory is cleared when the witness leaves;
    - MoralityService already calls `Capture` for deeds recorded with `Ctx.Witness`, so its strength-2 fallback is no longer used. No existing script changed;
  - **Watchers (PROPOSAL, owner to review).** Every NPC model in `Workspace.World.NPCs` with a Humanoid and no `EnemyType` is now tagged `RenseiWatcher`, with attributes `Faction` / `Carrier` / `WatcherType`. Factions were assigned by these rules: `TakesPrisoners` → Authority agent, inside the FoundryYard volume → Foundry, otherwise Townsfolk.
    - Mirra -> Foundry
    - Tobin -> Foundry
    - Drillmaster Vask -> Townsfolk
    - Placeholder NPC -> Townsfolk
    - Foreman Brask -> Authority (agent)
    - Lise -> Foundry
    - not tagged: the five trainers in the `Alchemy Trainers` folder (Veyra, Holt, Ansel, Calda, Brannoc). The tagging pass only looks at direct children of `World.NPCs`. Tag them too if they should witness;
  - test `Test_Witness` (Edit mode): RED was "WitnessService is not a valid member", then PASS 2 / FAIL 0;
  - Play check (Lise, Foundry, 25 studs in front, then 5 studs behind):
    - before: strength 0;
    - 2 s in front: strength 1 (Lise only), awareness 0.83, Suspicious;
    - 0.5 s behind: strength 1 (awareness 0.72, still above Suspicious);
    - 6 s behind: strength 0, awareness 0.00;
    - the player's position was restored; no WitnessService errors in the console.
    - (this check ran before the review fix; with the 3 s rule, "behind" drops to 0 once 3 s pass without sight)
  - review fix (`PerceptionService`), three rules:
    - `Perceived` counts only NPCs that saw the player within `Memory` (3 s); awareness alone isn't sight (spec §4);
    - watchers (`Combat = false`) cap at awareness 0.99. They notice and stare (Suspicious) but never go Alert from sight; a hit still alarms them (`Alarm`). This also stops a watcher from holding witness status through a 25 s search;
    - `Call` reaches only NPCs of the same kind: enemies call enemies, watchers call watchers (spec §17.1);
    - backups `ServerScriptService_PerceptionService_preT8fix` and `ServerStorage_RenseiTests_Play_Perception_preT8fix` are in `Pre-Foundation_2026-10-19`;
    - new Play tests `WatcherNeverAlertsFromSight` and `PerceivedNeedsRecentSight`: `Play_Perception` PASS 6 / FAIL 0, no `PerceptionService:` warnings. `Test_Witness` still PASS 2 / FAIL 0;
    - PerceptionService is now 13903 bytes (FNV 152410ad).
- Task 9: RumourService.Core, the pure rumour spread (Rensei):
  - new `ServerScriptService.RumourService.Core` (pure functions over a profile's `Morality` and a time you pass in): word of a deed travels the region graph from where it happened. Each link sends a front with its carrier (Gossip / Dispatch / Whisper); on arrival it lands the deed for the factions that carrier reaches there (`Reputation.Land`, once per faction per place), then goes on by the same carrier. Each hop costs 1 Strength (a front lands only while Strength - Hops > 0), and each `To/Carrier` is sent at most once per rumour;
  - `Spawn / Advance / Silence / LandReport`, `MaxLive = 20`, `MaxNews = 10` (PROPOSAL). Fronts are processed in arrival-time order, so an offline catch-up gives exactly what being online would have. `Spawn` reuses a live rumour of the same deed from the same origin; `Silence` takes a witness's weight off and kills the rumour at 0; `LandReport` lands a desk report at once for that desk's faction. The newest 10 arrivals are kept in `Morality.News` (newest first, `Report = true` for desk reports);
  - the communities are diaspora (present everywhere), so gossip lands for them in every region it reaches. This is intended;
  - `ServerScriptService.RumourService` itself is a placeholder (`return {}`) until Task 10; nothing calls Core yet and no existing script changed;
  - Core is 4537 bytes (FNV f4d8a9cd);
  - test `Test_RumourCore` (Edit mode): RED was "Core is not a valid member", then PASS 8 / FAIL 0.
- Task 10: RumourService, slice R2 (Rensei):
  - `ServerScriptService.RumourService` replaces the placeholder (its `Core` child is unchanged):
    - a Local / Public deed that someone perceived (`MoralityService.Recorded`, Strength > 0, not a birth deed) starts a rumour at its origin (`Core.Spawn`);
    - every 60 s (`TickSeconds`, PROPOSAL) each player's rumours advance to the current time (`Tick`). Any arrival rebuilds standing through `MoralityService.Refresh`, with a banner for any tier change;
    - `Report(Reporter, Subject, DeedId, Region, Faction)`: a player the server recorded as a witness (`WitnessService.CanReport`) reports the deed and it lands there at once. That memory is then forgotten. Otherwise it's refused with "You didn't witness that.";
    - `SetClock(Fn)` / `Now()` swap the clock for tests;
  - `MoralityService` `Joined`: after the old-outcome catch-up, `RumourService.Tick` runs once (pcall) as the **offline catch-up**. Word that travelled while you were away arrives on join (MoralityService 11853 → 12002 bytes, FNV 998ee50c);
  - `ServerHandler`: `RumourService.Start()` after PerceptionService;
  - backups `ServerScriptService_MoralityService_preT10` and `ServerScriptService_ServerHandler_preT10` are in `Pre-Foundation_2026-10-19` (the first backups of both already existed);
  - test `Play_Rumours` (Play mode, real profile snapshotted and restored, using a test-only deed injected into `Deeds`): RED was "attempt to call a nil value" (`SetClock`, PASS 0 / FAIL 2), then PASS 2 / FAIL 0:
    - dispatch reaches the City at +2 min: Authority +12, in full;
    - gossip reaches it at +10 min;
    - a second tick is idempotent;
    - a report with no recorded witness is refused;
  - rejoin catch-up (manual): the test deed was recorded in the Foundry (strength 2), then Play was stopped for just over 3 real minutes and started again:
    - on join, `Places.City.Known.__test_rumour.Authority` was set (dispatch, stamped at +120 s);
    - Townsfolk hadn't heard yet (the gossip front, due at +600 s, was still on the road);
    - `News[1]` = City / Authority;
    - the profile was then restored from the snapshot saved before the first stop. A later fresh Play loaded it with 0 differences;
  - console: no `RumourService` / `PerceptionService` / `MoralityService` / `WitnessService` errors or warnings;
  - Exports, matching Studio by FNV:
    - RumourService: 2885 bytes, `5c0c7dc0`;
    - ServerHandler: 4737 bytes, `ea79e495`;
    - Play_Rumours: 1910 bytes, `aba570c3`.
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

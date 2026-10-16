# Rensei Project Status

Updated **2026-10-16**. See `Phase Plan.md` for the roadmap, `Changelog.md` for per-phase detail, and `ARCHITECTURE.md` for where everything lives in the place.

## Current state

- **Main place:** **Ye** (placeId 106992859583940, owned by the Rensei group). Every system below is built there and was tested in Studio Play sessions.
- **Reference places:** not merge targets.
  - **Devil Hunter** (126902673811186): combat and movement feel reference.
  - **Assets** (124475187257502): the owner's asset dump. Its `Workspace.FireElement` holds the Flame VFX.
  - **Character Customization** (123967384111466): the main menu, save slots and character creation (part of the start flow, not a reference).
- **Nothing is published to live yet.** Ye's ProfileService saves from Studio, so test sessions use the real profile. Tests snapshot and restore it.

## What works now (playtested)

- **Combat:**
  - 4-hit light combo with held-LMB chaining and a click buffer; the full string plays even when it whiffs.
  - Heavy (R) with a crit telegraph, usable mid-string (queued behind the current swing); feint (RMB during a light's windup).
  - Uppercut (Ctrl+LMB) with an air juggle, aerial dive, dash attack (each weapon class has its own).
  - Grips come in three styles: Classic, Stomp, and Execution (armed).
  - Block (hold F, re-raises by itself while held) and parry (tap F, Devil Hunter rules), including parrying while getting hit (posture cost, cooldown).
  - Status effects: Burn, Freeze, Bleed, Shock, on the owner's VFX.
- **Alchemy:** all five kits complete (20 of 20 slots): Flame, Ice, Wind, Metal, Earth.
  - Posture and guard break, hitstop, knockbacks.
- **Movement:**
  - Devil Hunter dash in 8 directions, including shift lock and sprint.
  - Run, slide (outside Combat Mode), shift lock (Alt).
  - Directional climb, wall run, wall-to-wall chaining.
- **Weapons:** Sword (Katana), Rapier, Gauntlets, Greatsword, Daggers, Guns.
  - Each has a combo, heavy, skill (T) and passive.
  - Equipped from the inventory (not the hotbar); the choice is saved and comes back on respawn.
- **Start flow:** main menu + character creation (separate place) → Tutorial place → intro cutscene → Ye. See `Start Flow and Character Creation.md`.
  - Save slots (2 free, up to 5 purchasable), clan surnames rolled with the deck's odds (Clan Index, rerolls by pack or code), catalog hair IDs, colour wheel, female body, nation starter outfits.
- **Mastery skill tree (K):** buy / refund nodes; combat, alchemy, body and movement effects.
- **Quests, investigation, puzzles (vertical slice):** staged quests with endings, conditional dialogue, evidence and a Case Board in the Journal (J), per-player environmental puzzles that every alchemy path can solve (each with a non-alchemy route too), and two UI minigames (Pressure Board, Array Restoration). One full placeholder quest, "Chalk on the Foundry Wall", in a graybox Foundry Yard south of the arena, plus a repeatable bandit bounty.
- **PvE looks:** enemies roll a nation outfit and one of the creator's starting weapons.
- **Combat log badge:** in combat, shows who hit you and the time until you're out of combat.
- **Admin panel (F2):** admins only (`AdminConfig`); players, world, self and log tabs, including switching a player's alchemy path.
- **Items:** consumables on the hotbar; clicking while holding uses one. The Apple heals a little at a time.
  - Draw/sheathe through Combat Mode (E) with holster↔hand blending; greatsword shoulder carry. Holsters on the hip / back / thigh.
- **Resources:** Health, Stamina, Posture, Transmutation Meter (earned by fighting only).
- **Downed:** knocked state, Grip (B), Carry (V).
- **PvE:** Dummy, Grunt, Elite (blocks and parries).
- **Alchemy:** the full Flame kit (Ignite, Scorching Wave, Inferno Lance, Phoenix Drive).
  - Clap (holdable) → arm extend (projectiles) or ground slam → move, on the owner's FireElement VFX, with the transmutation-circle effects.
  - Server-validated meter cost and cooldown; Z/X/C/V slot bar.
- **Mobile:** touch control cluster (every action, alchemy with cooldowns, climbing with the thumbstick).
- **UI:** HUD bars, cooldown list, alchemy slots, Stats (live polychart), Inventory, Hotbar, Settings (keybinds, shift lock, auto sprint, combat log, post effects, UI animations, field of view, UI sounds), Party, Quest log, Server info, popups.
  - Animated throughout (`UIMotion`): menus pop in and settle out, buttons react to hover and press, rows and popups animate in.
- **Progression:** levels, stat points (5 stats), Mastery Points (training), Truth/Gate checks (the trial itself isn't built).

## Known gaps

- **Animations:** many weapon animations are unpublished copies that play only in Studio. 16 IDs from the owner's animation sheet are broken group uploads, so the old animations are used for those.
  - The "NEW RENSEI ANIMS" folder (new uppercut, emotes, etc.) is owned by another group and won't load in Rensei's game; it needs re-uploading under the Rensei group. The animation spreadsheet's new rows haven't been audited yet (link needed).
- **Affinity:** the Alchemy step was removed from the creator at the owner's request, so players can't choose a path yet; admins can set anyone's path from the admin panel (F2). Studio uses the test setting `ServerScriptService.AlchemyService` attribute `StudioTestAffinity` (never saved, ignored live).
- **Purchases:** the Developer Product IDs for save slots and reroll packs are placeholders (0).
- **Tutorial place:** still loads `Data<UserId>`, not the selected save slot.
- **Alchemy:** Ice, Wind, Metal and Earth run on placeholder animations (Earth's VFX use the owner's prototype meshes).
- **Climb animations:** the cleaned versions play only in Studio until published (live keeps the originals).
- **Quest content:** only the placeholder Foundry Yard quest and bounty exist; real quests, the map and canon lore are the owner's. Not yet verified: two players in one puzzle at once, and puzzle state after a real rejoin (Studio saves were failing with HTTP 500 during testing).
- **Not built:** main story, Assay Bench / Ledger Cipher minigames, escort objectives, factions / reputation.

## Development rules (unchanged)

- Preserve working systems; audit before editing.
- Don't assume planned features exist.
- Label invented numbers PROPOSAL.
- Don't publish the game or touch live player data.
- The Nemesis system is shelved.
- Keep backups: every change round snapshots the scripts it touches into `ServerStorage.RenseiBackups["Pre-<Name>_<date>"]`.

# Rensei Project Status

Updated **2026-10-14**. See `Phase Plan.md` for the roadmap, `Changelog.md` for per-phase detail, and `ARCHITECTURE.md` for where everything lives in the place.

## Current state

- **Main place:** **Ye** (placeId 106992859583940, owned by the Rensei group). Every system below is built there and was tested in Studio Play sessions.
- **Reference places:** not merge targets.
  - **Devil Hunter** (126902673811186): combat and movement feel reference.
  - **Assets** (124475187257502): the owner's asset dump. Its `Workspace.FireElement` holds the Flame VFX.
  - **Character Customization** (123967384111466): for later.
- **Nothing is published to live yet.** Ye's ProfileService saves from Studio, so test sessions use the real profile. Tests snapshot and restore it.

## What works now (playtested)

- **Combat:**
  - 4-hit light combo with hit confirm, held-LMB chaining and a click buffer.
  - Heavy (R) with a crit telegraph; feint (RMB during a light's windup).
  - Uppercut (Ctrl+LMB) with an air juggle, aerial dive, dash attack.
  - Block (hold F, re-raises by itself while held) and parry (tap F, Devil Hunter rules).
  - Posture and guard break, hitstop, knockbacks.
- **Movement:**
  - Devil Hunter dash in 8 directions, including shift lock and sprint.
  - Run, slide (outside Combat Mode), shift lock (Alt).
  - Directional climb, wall run, wall-to-wall chaining.
- **Weapons:** Sword (Katana), Rapier, Gauntlets, Greatsword, Daggers, Guns.
  - Each has a combo, heavy, skill (T) and passive.
  - Draw/sheathe through Combat Mode (E) with holster↔hand blending; greatsword shoulder carry.
- **Resources:** Health, Stamina, Posture, Transmutation Meter (earned by fighting only).
- **Downed:** knocked state, Grip (B), Carry (V).
- **PvE:** Dummy, Grunt, Elite (blocks and parries).
- **Alchemy:** the full Flame kit (Ignite, Scorching Wave, Inferno Lance, Phoenix Drive).
  - Clap (holdable) → arm extend (projectiles) or ground slam → move, on the owner's FireElement VFX, with the transmutation-circle effects.
  - Server-validated meter cost and cooldown; Z/X/C/V slot bar.
- **UI:** HUD bars, cooldown list, alchemy slots, Stats (live polychart), Inventory, Hotbar, Settings (keybinds, shift lock, auto sprint), Party, Quest log, Server info, popups.
- **Progression:** levels, stat points (5 stats), Mastery Points (training), Truth/Gate checks (the trial itself isn't built).

## Known gaps

- **Animations:** many weapon animations are unpublished copies that play only in Studio. 16 IDs from the owner's animation sheet are broken group uploads, so the old animations are used for those.
- **Affinity:** no way to choose one yet, because character creation isn't built. Studio uses the test setting `ServerScriptService.AlchemyService` attribute `StudioTestAffinity` (never saved, ignored live).
- **Alchemy:** Ice, Wind and Metal aren't built yet (no VFX folders or move animations). Earth has no design.
- **Not built:** skill tree, quests/dialogue content, puzzles, story.

## Development rules (unchanged)

- Preserve working systems; audit before editing.
- Don't assume planned features exist.
- Label invented numbers PROPOSAL.
- Don't publish the game or touch live player data.
- The Nemesis system is shelved.
- Keep backups: every change round snapshots the scripts it touches into `ServerStorage.RenseiBackups["Pre-<Name>_<date>"]`.

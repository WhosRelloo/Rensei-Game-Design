# Rensei Development Decisions

This document records established project decisions to keep development consistent. "Owner" = Rello. Newest decisions are at the bottom of each section.

## Confirmed direction
- Rensei is an open-world dark industrial-fantasy action RPG on Roblox.
- Alchemy, combat, exploration, character progression and consequential storytelling are the core pillars.
- Inspect existing systems before changing them. Preserve what works. Work in small, testable phases.
- **Ye** is the main place. Devil Hunter is the combat reference (inspiration, not a merge target). Assets is an asset source.

## Alchemy
- Five paths: **Flame, Ice, Earth, Wind, Metal.**
- **Ability rows come from the alchemy design sheet:** damage, cooldown, cast and extras. They are recorded in `Modules.Data.Rensei.Alchemy`. The sheet has no Earth rows.
- **Controls:** Z primary, X secondary, C utility, V ultimate.
  - Meter based, cooldowns, telegraphed.
  - Utility/control focused, not the main damage source.
- **V priority:** Carry if a knocked target is in range, otherwise the Ultimate.
- **Cast flow (owner, 2026-10-14):**
  1. Clap; the clap is **holdable**.
  2. Hands slam the ground (or the arm extends).
  3. The move's own animation.
- **Cast VFX (owner, 2026-10-14):**
  - The owner's FireElement folder (Assets place) is used for Flame.
  - A custom in-theme transmutation circle appears in front of the hands on the clap.
- **Slot bar (owner, 2026-10-14):** a Z/X/C(/V) bar like Devil Hunter's, shown once a player has an alchemy path.
- **Marcoh lineage** cannot use Stone Abilities, enforced centrally in `Clans.CanUseAbility`.

## Combat
- **Attack classes:** BLOCKABLE, PARRYABLE, UNBLOCKABLE.
- **Controls doc is LOCKED.** Owner changes since:
  - RMB = Feint only; R = Heavy.
  - Ctrl+LMB = Uppercut.
  - Air LMB = Aerial.
  - Ctrl crouch/slide only outside Combat Mode.
  - Combat Mode on E (draw/sheathe).
  - Weapon skill on T; Lock Target on G.
- **Parry:** Devil Hunter's rules. 0.22s window, ping-scaled; 1.3s cooldown unless the parry lands.
- **Combat fluidity matched to Devil Hunter (owner, 2026-10-14):**
  - Light hitstun 0.6s; combo resets after 2s.
  - Walk speed while swinging, blocking or stunned close to Devil Hunter's.
  - Holding F re-raises the guard.
- **Hit confirm stays** (controls doc): a whiff adds recovery and resets the combo.
- **Weapons:** six (Sword, Rapier, Gauntlets, Greatsword, Daggers, Guns). Passives were proposed and accepted as PROPOSALS.
- **Greatsword (owner):** must feel heavy. Shoulder carry with the blade just behind the head when idle, walking or running; slower movement; a step into each swing; longer hit-pause.
- **Guns:** no reload button, automatic only.
- **Weapon animations (owner):** use the group animations that work; keep the old ones for any that don't.

## Progression
- Stat Points (levels) and Mastery Points (training) stay **separate**.
- The spreadsheet HP scale is approved "until we tweak it later": 580 HP at level 1, +120 per level, +60 per Vitality.
- **Truth/Gate (Deepwoken-style stages):** spend all 20 Mastery Points of a stage, then pass the trial to unlock the next 20.
- Paid rerolls (clan) must use secure purchase processing. Rolling is disabled until a clan roster exists.

## Shelved features
- The Nemesis system is shelved. Don't implement it unless the owner brings it back.

## Implementation rules
- Audit before changing scripts.
- Don't assume planned systems exist.
- Explain major rewrites first.
- Test in Roblox Studio before calling anything done.
- Label invented numbers PROPOSAL in `TuningConfig`.
- Protect backups. Never publish or touch live player data without explicit approval.
- After every phase:
  - update this repo (`Project Status.md`, `Phase Plan.md`, `Changelog.md`, this file);
  - update the visual status page.

## Open questions (not decided; don't invent answers)
- **Affinity:** how a player gets an affinity (character creation flow, rolls?).
- **Earth:** abilities (no sheet rows).
- **Alchemy numbers:** meter costs (PROPOSAL: Z25 / X35 / C35 / V70); whether interrupted casts refund anything (currently no refund).
- **Skill tree:** nodes, costs, prerequisites, and whether alchemy slots unlock through it.
- **Grip:** PvP / permadeath / anti-gank consequences of a grip finisher.
- **Clans:** roster, rarities, roll weights, bonuses; which abilities count as "Stone Abilities".
- **Ranked arena:** timing (the doc says "later").

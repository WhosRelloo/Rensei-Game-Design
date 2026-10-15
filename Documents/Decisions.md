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
- **Parry while getting hit (owner, 2026-10-14, "like VV and Devil Hunter"):** allowed on a fresh F press during hitstun, with a slight cooldown and a posture cost.
  - Built as: 10 posture per attempt (PROPOSAL); always the 1.3s cooldown, even when it lands (PROPOSAL).
  - Never out of a guard break, parry stun, freeze or knock.
- **Status effects (owner, 2026-10-14):** alchemy hits apply the owner's status effects (Fire / Freeze / Bleed / Shock VFX) with real effects. See COMBAT_SYSTEM.md.
- **Combat fluidity matched to Devil Hunter (owner, 2026-10-14):**
  - Light hitstun 0.6s; combo resets after 2s.
  - Walk speed while swinging, blocking or stunned close to Devil Hunter's.
  - Holding F re-raises the guard.
- **Hit confirm (owner, 2026-10-14, replaces the controls-doc rule):** a whiff still adds recovery, but no longer resets the combo. Holding LMB plays the full string into the air.
- **Heavies mid-combo (owner, 2026-10-14):** R during an M1 swing doesn't cancel it; the heavy comes out right after that swing.
- **Weapons are equipped from the inventory (owner, 2026-10-14):** never on the hotbar. The hotbar is for items. Items are held outside Combat Mode only (PROPOSAL).
- **Holster spots (PROPOSAL):** Katana/Rapier left hip, Greatsword back, Daggers crossed on the lower back, pistols right thigh.
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
- **Start flow (owner, 2026-10-14):** Main Menu → Customize → Tutorial → Cutscene → Main game. Creation is in its own place (Character Customization). It lets players set a first name, an optional surname and a gender (owner: "first name, gender, etc.").
- **Proposal approved (owner, 2026-10-14, "I like it")**, so §3 took the recommended or safest options:
  - "Stone Abilities" means Philosopher's Stone abilities; Earth isn't restricted for Marcoh.
  - Six nations, cosmetic only. Names typed or from the nation lists.
  - The alchemy path is picked, not rolled. Starting weapon: fists or a Common weapon.
  - Automail, blindness and Homunculi are left for later.
  - The Earth kit as proposed, with Earth Wall at 6s.
- **(Superseded) open decisions:** see `Earth and Character Creation Proposal.md` §3 (10 decisions: Stone Abilities meaning, nations, name, affinity pick vs roll, starting weapon, old-build extras, where creation happens, the Earth mapping, the Earth Wall duration).
- **Consumables (PROPOSAL):** the Apple heals 8% of max HP over 6s (0.5s ticks), 1s between uses.
- **Passive health regen:** Roblox's default regen (+1% max HP/s) is active. Keep it or remove it?
- **Shock:** which element / moves apply it (built, unused). Bleed beyond daggers (Metal?).
- **Flame X/C burn:** Scorching Wave and Inferno Lance burn for 2 ticks (PROPOSAL; the sheet lists burn only on Ignite and Phoenix Drive).
- **Hit-parry numbers:** posture cost 10 and "always cooldown" are PROPOSALS; "VV" wasn't available to check, so they follow Devil Hunter's code.
- **Ice kit PROPOSALS:** Cryo Shift window 1.0s; Coldsteel Smash freezes 0.6s; Ice Shards as a placed trap (4–22 studs, radius 6, arms 0.3s, lasts 8s, one per caster); Absolute Zero radius 20 and recovery 1.0s.
- **Wind PROPOSALS:** Air Slash 160 studs/s, 75 range; Gale Burst radius 12, 3 blasts 0.2s apart, push 55; Rising Wind uses the Uppercut launch; Tempest Break 10–35 studs, radius 9 / pull 18, pull 18, lift 9, 1.0s recovery.
- **Metal PROPOSALS:** Steel Guard arc ~78°; Crushing Anvil 42 studs/s, 36 range, homing 540°/s after 0.25s, slam radius 5; Metal Bind 15 studs; Alloy Divider line 30×6, 1.2s recovery.
- **Wind, Metal and Ice animations / VFX** are placeholders until the owner provides them.
- **Ice animations / VFX:** placeholders until the owner makes Ice animations and an Ice VFX folder.
- **Alchemy numbers:** meter costs (PROPOSAL: Z25 / X35 / C35 / V70); whether interrupted casts refund anything (currently no refund).
- **Skill tree:** nodes, costs, prerequisites, and whether alchemy slots unlock through it.
- **Grip:** PvP / permadeath / anti-gank consequences of a grip finisher.
- **Clans:** roster, rarities, roll weights, bonuses; which abilities count as "Stone Abilities".
- **Ranked arena:** timing (the doc says "later").

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
- **Gun M1 (owner, 2026-10-17, non-negotiable):** M1 with a gun is a melee pistol whip and never fires a bullet; shooting is its own mode (Aim, Y).
- **Ledge walk (owner, 2026-10-17):** the Tomb Raider narrow cliff-ledge walk, on authored ledges (tagged `RenseiLedge`), facing the wall.
- **Weapon styles (owner decision 1, 2026-10-17):** Boxing and Lethwei go on **bare fists**, not Gauntlets / Caestus.
- **Style unlocks (owner, 2026-10-18):** a style is learned **only** from its style trainer once its requirements are met.
- **Base moveset (owner decision 8, 2026-10-18, "it should stay as selectable"):** every class's existing moveset stays a selectable style, always learned (no trainer). For bare fists it's shown as "Brawler" (the name is PROPOSAL).
- **Fist skills (owner, 2026-10-18):** Spin Kick is a 1-hit move, 540 Kick a 3-hit move.
- **Grabs and sticky skills (owner, 2026-10-18):** moves with victim animations work as grabs; a skill that lands sticks to the opponent until they parry or block (Devil Hunter / VV Ultimatum skill logic).
- **Starting weapons (owner, 2026-10-18):** the creator offers six: Fists, Katana, Rapier, Caestus, Greatsword, Daggers. Enemies still use all eight Common weapons (guns included).

## Progression
- Stat Points (levels) and Mastery Points (training) stay **separate**.
- The spreadsheet HP scale is approved "until we tweak it later": 580 HP at level 1, +120 per level, +60 per Vitality.
- **Truth/Gate (Deepwoken-style stages):** spend all 20 Mastery Points of a stage, then pass the trial to unlock the next 20.
- Paid rerolls (clan) must use secure purchase processing. Rolling is disabled until a clan roster exists.

## Quests, puzzles and minigames (owner approved the proposal's defaults, 2026-10-15)
- **Placeholder lore allowed:** the foundry district, the State Authority's alchemy licence, and the new characters Foreman Brask, Mirra, Tobin and Lise are placeholders until the owner's canon replaces them.
- **Graybox first:** content is built on a graybox Foundry Yard in Ye until the real map exists.
- **Puzzle ownership:** per-player by default (nobody blocks anyone else).
- **Minigames first:** Pressure Board and Array Restoration (Assay Bench and Ledger Cipher later).
- **Rewards:** the proposal's numbers as a starting point (PROPOSAL).
- **Consequences:** story choices only record a flag for now (`Outcome_<QuestId>`); later faction work reads it.
- **Rules kept:** no puzzle requires a specific alchemy path; failures are recoverable; rewards pay once.
- **PROPOSAL (built):** out of combat, an alchemy cast next to a mechanism that reacts to its element costs no meter. The Journal is on J (J and K are now reserved from rebinding).

## Morality and reputation (owner approved the proposal's defaults, 2026-10-16)
- **Five tracks, no karma meter:** Conduct (Mercy / Candor / Order), Standing per faction, Renown, Trust per NPC, Taboo, all built from a Deeds Ledger (`Morality and Reputation Proposal.md`).
- **Placeholder factions allowed:** Foundry Hands, Unlicensed Circle and Townsfolk next to the State Authority.
- **Words only:** players see tiers, conduct words and ranks, never numbers.
- **PvP:** no deeds in arena, duels or self-defence. An unprovoked grip on a player is a capped Local deed (not built until the PvP rules exist).
- **Titles:** the Renown x Conduct flavour titles (placeholders).
- **First slice:** M1-M3 + M5 (built 2026-10-16). Taboo canon is left for later.

## World and movement (2026-10-17 / 18)
- **Starter map (owner, 2026-10-17):** "the Resembool-style Countryside farm village", using the owner's Blender model (RockbellHouse). Built as **Lindenmoor** (the name, layout and sizes are PROPOSAL).
- **Swimming (owner decision 6, 2026-10-18):** basic swimming in deep water with a swim state: **no combat or alchemy while swimming**. The same rule applies to enemies (owner: "enemies in deep water should also be unable to attack or cast, same as players").
- **Swimming extras (owner, 2026-10-18):** swim sprint (stamina), diving, breath and drowning, more deep water, and touch buttons for sprint and rise that only show while swimming. The numbers are PROPOSAL.
- **Swimming revamp (2026-10-27, PROPOSAL, awaiting the owner).** The owner's request: "Completely audit and revamp the swimming system. (I want it to be directional, with a dive system)". Taken without the owner (spec `Documents/specs/2026-10-25-swimming-revamp-design.md` §12), each changeable by a `TuningConfig.Swim` number or a ruling:
  1. A client swim controller replaces Roblox's swim steering; the server keeps every rule.
  2. Surface swimming is level; only a dive takes you under (looking down no longer dives).
  3. Ctrl at the surface dives (on the press); hold Ctrl underwater to sink, Space to rise. Touch: a DIVE button in Slide's spot.
  4. Underwater: camera-relative in 3D, level strafing, a 1.5 studs/s drift up.
  5. The numbers: UnderSpeedMult 0.85, Ascend / Descend 10, Dive 16 for 0.35 s, DiveMinDepth 4.5, SurfaceBand 0.6, MaxPitch 80°, ClimbOut 4.5 / 3, sprint breath x1.5 underwater, RootBelowSurface 1.4 and HeadOffset 1.5 (measured). The owner's sprint x1.6 / 14 stamina/s, 15 s of air and 6% drowning are kept.
  6. Breath counts whenever your head is under water, not only in the Swim state.
  7. A low-ledge climb-out with Space (the owner: it uses the ledge climb, Vault1 / Vault2).
  8. Stealth: water no longer blocks NPC sight; a diver is seen at x0.3; two new noises, Surface 6 and sprint Stroke 8 every 0.8 s.
  9. Enemies don't dive (no combat or alchemy in water, as before).
  10. The speed check only logs and stops the sprint; it never teleports.
  11. **Foundry Yard's 9-deep cooling pond is the deep dive.** The Ye plunge hole (approved by the owner on 2026-10-25) is **skipped** by the controller's ruling of 2026-10-27, which the owner can reverse: Task 1's survey found the Gorge Pool's floor is `Map.Ground.Tops` parts at y 0, not the Baseplate the plan assumed, with a flat area of only about 12 x 4 studs. The other options, for the owner: (a) a small 12 x 4 hole in the Gorge Pool; (b) a bigger change that also cuts the `Ground.Tops` parts under the pool; (c) the hole in the Mill Pond, whose flat floor is larger.
  12. Two animation slots, filled with placeholders (owner, 2026-10-25): Swim_Dive and Swim_Surface.
  13. The air meter is a clone of the HUD's Meter bar.
  14. SwimClient keeps its name and job; the movement is in the new SwimController.
- **Dialogue close (owner, 2026-10-18):** a small X button on the dialogue box (works with touch). No menu opens over a conversation.

## Character creation (2026-10-18)
- **Creator QOL with a paywall, no accessories (owner).** Built as PROPOSAL: free undo / redo, random look and reset; **Creator Plus** for a custom skin colour and 3 saved looks. Cosmetic only.
- **Store (owner, 2026-10-18):** five Developer Products with Managed Pricing: New Save Slot 200 R$, Creator Plus 100 R$, Clan Reroll x1 / x5 / x15 at 50 / 200 / 550 R$. Creator Plus is a **Developer Product bought once** (recorded on the account), not a Game Pass.

## Shelved features
- The Nemesis system is shelved. Don't implement it unless the owner brings it back.
  - **2026-10-25:** the owner brought it back into the backlog, after the swimming revamp: "Nemesis System (Gotta make the concept first)". The first step is a concept for the owner to approve. Nothing is built until the owner approves it.

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
- **Earth PROPOSALS (built 2026-10-15):**
  - Rising Thorn: range 4–18, radius 4, Bleed 3s (2 per 0.5s), knock-up 32.
  - Tectonic Shift: 12 spikes, push 22.
  - Earth Wall: 6×7×1.6, 5 studs out, 6s; the lift hit is BLOCKABLE.
  - Earth Pillars: waves 0.3s apart, 0.35s to cross the line; 1.1s recovery.
  - Earth's status is Bleed (the prototype's Rising Thorn bled).
- **Consumables (PROPOSAL):** the Apple heals 8% of max HP over 6s (0.5s ticks), 1s between uses.
- **Passive health regen:** Roblox's default regen (+1% max HP/s) is active. Keep it or remove it? (Drowning is tuned against it: 6% of max HP per second, PROPOSAL.)
- **Creator Plus (2026-10-18):** whether the free / paid split is right (it's on sale as a Developer Product now).
- **Broken sheet animations (2026-10-18):** 12 sheet assets don't load ("AnimationClip loaded is not valid"): Greatsword Idle / Walk / Sheathe / Unsheathe / KO, Katana Walk / Sheathe / Unsheathe, Daggers Sheathe / Unsheathe, Ledge Idle Left / Right. They need re-uploading; the old animations stay meanwhile.
- **Weapon skills vs the skill sheet:** how the sheet maps onto Dragonflash, Flurry, Barrage, Scissor Rush and Fan the Hammer (`Animations.md`).
- **Names (PROPOSAL):** "Brawler", "Lindenmoor", "Mill Pond", "Gorge Pool". Deeper water than ~5.2 studs needs a raised basin or a hole in the baseplate.
- **Shock:** which element / moves apply it (built, unused). Bleed beyond daggers (Metal?).
- **Flame X/C burn:** Scorching Wave and Inferno Lance burn for 2 ticks (PROPOSAL; the sheet lists burn only on Ignite and Phoenix Drive).
- **Hit-parry numbers:** posture cost 10 and "always cooldown" are PROPOSALS; "VV" wasn't available to check, so they follow Devil Hunter's code.
- **Ice kit PROPOSALS:** Cryo Shift window 1.0s; Coldsteel Smash freezes 0.6s; Ice Shards as a placed trap (4–22 studs, radius 6, arms 0.3s, lasts 8s, one per caster); Absolute Zero radius 20 and recovery 1.0s.
- **Wind PROPOSALS:** Air Slash 160 studs/s, 75 range; Gale Burst radius 12, 3 blasts 0.2s apart, push 55; Rising Wind uses the Uppercut launch; Tempest Break 10–35 studs, radius 9 / pull 18, pull 18, lift 9, 1.0s recovery.
- **Metal PROPOSALS:** Steel Guard arc ~78°; Crushing Anvil 42 studs/s, 36 range, homing 540°/s after 0.25s, slam radius 5; Metal Bind 15 studs; Alloy Divider line 30×6, 1.2s recovery.
- **Wind, Metal and Ice animations / VFX** are placeholders until the owner provides them.
- **Ice animations / VFX:** placeholders until the owner makes Ice animations and an Ice VFX folder.
- **Alchemy numbers:** meter costs (PROPOSAL: Z25 / X35 / C35 / V70); whether interrupted casts refund anything (currently no refund).
- **Player Identities (2026-10-18, PROPOSALS):** 40 records per investigator, 120 s between encounters, witness range 60 studs, a 10-minute lock after a wrong name, and naming allowed from the Suspected stage (2 kinds of observation and 2 encounters).
- **Forgotten Sites (2026-10-18, PROPOSALS):** dungeon respawn 15 min with an 80-stud clear radius; Halvard's Adit rewards ($180, 775 EXP, the strongbox cache); the site's name and story.
- **Unused owner assets:** Windup, WindStep, Icechainfx, IceEruption, Pale Assassin Cloak (from "ASSETS TO EXPORT"). Where should they go?
- **Fluidity numbers (2026-10-18, PROPOSALS):** hitstun chain cap 3.0 s + 0.6 s break; grab buffer 0.25 s; server climb grace 0.5 s; climb → ledge reach 1.5 studs, settle 0.3 s; landing on the move at 1.8×.
- **Data storage (2026-10-18):**
  - inventory caps (60 entries / 999 per stack / 25 per give, PROPOSALS);
  - whether Studio should use ProfileService's mock store instead of your real saves;
  - upgrading ProfileService for `AddUserId` (data-deletion requests).
- **Skill tree:** nodes, costs, prerequisites, and whether alchemy slots unlock through it.
- **Grip:** PvP / permadeath / anti-gank consequences of a grip finisher.
- **Clans:** roster, rarities, roll weights, bonuses; which abilities count as "Stone Abilities".
- **Ranked arena:** timing (the doc says "later").
- **Morality Taboo canon:** which forbidden acts exist (human transmutation, Stone use, chimeras) and whether the Authority hunts or recruits a Taboo user. PvP / permadeath rules (Grip) also gate PvP deeds.

## Reputation in investigations (owner, 2026-10-25)
- Persuade, bribe and intimidate use the existing dialogue box, on a second talk with a witness who evaded or refused: "Yes, use the dialogue box for persuade/bribe/intimidate on a second talk with a witness." This is the one exception to the 2026-10-23 rule that townsfolk give no reply choices. Spec: `Documents/specs/2026-10-25-reputation-investigations-design.md`, D1.

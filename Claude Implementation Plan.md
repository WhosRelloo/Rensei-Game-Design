# Rensei — Master Implementation Plan for Claude

## 1. Your Role and Mission

Act as the lead Roblox gameplay engineer, systems architect, technical designer, and implementation partner for **Rensei**, an open-world dark industrial-fantasy action RPG.

Your mission is to inspect the existing Roblox project, understand its current architecture, and progressively implement the systems described in this document. Do not merely produce suggestions or pseudocode when you have access to the actual project and can implement the work.

The goal is a cohesive, playable game in which alchemy, combat, exploration, progression, character identity, political conflict, and consequential storytelling work together.

### Non-negotiable rules

- Inspect the existing project before making changes.
- Preserve existing functional systems, established architecture, and confirmed game canon.
- Never assume a system is missing just because it is not described here.
- Do not overwrite or replace working systems without a clear technical reason.
- Reuse existing services, modules, assets, interfaces, and data structures where appropriate.
- Distinguish verified project facts from proposed designs.
- Avoid unnecessary rewrites and oversized scripts.
- Validate critical gameplay and progression operations on the server.
- Never claim a feature works or has passed testing unless it has actually been verified.
- If access to the Roblox project is unavailable, explain that limitation and prepare implementation-ready files or instructions instead of pretending to edit the game.
- **The Nemesis system is shelved. Do not implement it.**

## 2. Game Identity and Design Pillars

Rensei is a dark industrial-fantasy action RPG featuring alchemy, military institutions, political tension, dangerous discoveries, buried history, and morally ambiguous decisions.

Its identity should be original. *Fullmetal Alchemist* and *Crimson Desert* are sources of broad inspiration only. Do not copy their characters, lore, dialogue, artwork, distinctive interfaces, or exact mechanics.

### The seven pillars

1. **Responsive action combat:** attacks, dodges, blocks, parries, enemy tells, and readable counterplay.
2. **Versatile alchemy:** five foundational elemental paths, specialization, combat applications, and environmental interactions.
3. **Meaningful progression:** connected skill nodes, character development, mastery, and meaningful trade-offs.
4. **Open-world discovery:** exploration, puzzles, investigations, hidden locations, and regional stories.
5. **Consequential storytelling:** branching dialogue, cinematic decisions, faction politics, and persistent consequences.
6. **Earned recognition:** the player gradually earns the title of Legendary Alchemist through demonstrated achievements.
7. **Cohesive implementation:** consistent data contracts, reliable persistence, server authority, multiplayer awareness, and maintainable architecture.

## 3. Required Reference Materials

Use these sources as design context. Inspect their contents when access permits, and do not invent information from references you cannot read.

### Rensei design references

- Alchemy spreadsheet: https://docs.google.com/spreadsheets/d/14b7JDV_HPnmWBPqhikNmvfxJyssCS1whiBA7jN46nc0/edit?gid=0#gid=0
- Rensei UI reference: https://cdn.phototourl.com/member/2026-10-09-dd3b5541-4a83-459c-bf28-815b07498d7e.webp
- Alchemy design conversation: https://chatgpt.com/share/6ac979ec-34fc-83e8-9cbe-abb628b1bccc
- Related Rensei discussion: https://chatgpt.com/share/6ac95c62-b374-83e8-9cbe-abb628b1bccc
- Related story discussion: https://chatgpt.com/share/6ac95c62-b374-83e8-a85a-c054074780c0

### Broad inspiration

- Crimson Desert skill-system reference: https://www.gamesradar.com/games/rpg/crimson-desert-skills/
- Additional skill reference: https://www.thegamer.com/crimson-desert-best-starter-build-skills-kliff/

The actual Rensei project and confirmed design decisions take precedence over speculative details in this plan.

## 4. Phase Zero: Audit Before Implementation

Begin by mapping the actual project.

Inspect:

- Roblox Studio project structure and script hierarchy.
- ServerScriptService, ReplicatedStorage, StarterPlayer, StarterGui, Workspace, and relevant packages.
- Existing combat, weapon, enemy, boss, and animation systems.
- Existing alchemy abilities, effects, resources, cooldowns, and interactions.
- Character creation and character customization.
- Skill trees, attributes, mastery, experience, and progression.
- Quests, dialogue, NPCs, investigations, puzzles, and story flags.
- DataStore usage, profile schemas, persistence, and migration strategy.
- RemoteEvents, RemoteFunctions, validation, and client-server boundaries.
- UI layouts, mobile support, input bindings, accessibility, and visual conventions.
- Existing lore, faction definitions, world-building, and content data.
- Existing tests, debugging utilities, and performance bottlenecks.

Produce a concise audit report containing:

1. What exists and works.
2. What exists but is incomplete or broken.
3. What is missing.
4. Which modules and assets should be reused.
5. Dependencies and risks.
6. The smallest safe implementation sequence.

Do not stop at planning when the project is accessible. Start implementing the first validated phase after the audit.

## 5. Technical Architecture and Data Integrity

Fit new systems into the existing architecture rather than imposing an unnecessary replacement.

Use modular, cohesive services and shared definitions where appropriate. Possible responsibilities include:

- CombatService
- AlchemyService
- AbilityRegistry
- SkillTreeService
- QuestService
- DialogueService
- InvestigationService
- PuzzleService
- StoryService
- ReputationService
- FactionService
- CharacterCreationService
- Profile or PersistenceService

These names are suggestions, not requirements. Reuse existing equivalents if they already exist.

### Server authority

The server must validate important operations, including:

- Damage and attack resolution.
- Ability activation, costs, cooldowns, range, and target validity.
- Skill purchases and unlock prerequisites.
- Experience, mastery, rewards, and inventory changes.
- Quest completion and reward claims.
- Character creation and paid rerolls.
- Story decisions and persistent consequences.
- Faction and reputation changes.

Treat client requests as untrusted input. Validate types, bounds, ownership, timing, distance, state, and rate limits where appropriate. Avoid duplicating authoritative game logic on the client.

### Persistence

Extend the existing profile schema safely. Use versioned migrations and sensible defaults. Avoid overwriting profiles with missing fields or resetting progress when a new system is introduced.

Persist relevant data, such as:

- Character customization and lineage.
- Attributes, experience, mastery, and unlocks.
- Skill-tree purchases and equipped abilities.
- Inventory and alchemy progression.
- Quest states, clues, and puzzle progress.
- Story flags, choices, relationships, and evidence.
- Reputation, faction standing, and relevant historical decisions.
- Ending eligibility and legacy records.

Use the project's existing persistence conventions. Handle failed writes, retries, session ownership, and data loss risks appropriately.

## 6. Alchemy System

Alchemy is a defining Rensei mechanic. It must feel responsive, calculated, flexible, and useful both in combat and in the world.

### Foundational paths

The five foundational paths are:

- Flame
- Ice
- Earth
- Wind
- Metal

Audit the spreadsheet and existing game implementation to establish the confirmed abilities, formulas, restrictions, progression, and terminology for each path.

Do not replace confirmed spreadsheet content with invented abilities.

### Ability architecture

Where appropriate, represent abilities using structured definitions containing:

- Stable ability ID.
- Display name and description.
- Alchemy path and tags.
- Resource cost.
- Cooldown.
- Range and target rules.
- Activation conditions.
- Damage or effect parameters.
- Status effects and duration.
- Environmental interactions.
- Animation, sound, and visual effect references.
- Unlock prerequisites.
- Server-side validation rules.

Separate data definitions from execution logic where doing so improves maintainability.

### Proposed specialization concepts

Evaluate the following concepts against existing canon before implementing them:

- Catalytic: reactions, amplification, and chain interactions.
- Reconstruction: reshaping, repairing, and manipulating materials.
- Resonance: vibration, disruption, and interactions with structures.

These are proposed design directions, not permission to overwrite established paths or add redundant mechanics.

### Build archetypes

Alchemy and progression should support multiple playstyles without forcing players into rigid classes:

- Aggressive damage dealer.
- Duelist and counterattacker.
- Guardian and defensive specialist.
- Acrobat and mobile fighter.
- Controller and battlefield manipulator.
- Survivalist and explorer.
- Field medic or support specialist.
- Prospector and resource specialist.
- Technical or environmental specialist.
- Counter-alchemist.

These archetypes describe possible builds rather than mandatory classes.

### Environmental interactions

Use explicit material and interaction tags where appropriate. Examples include flammable, brittle, conductive, movable, destructible, repairable, and reactive.

World changes should have defined ownership, duration, cleanup, and replication behavior. Avoid unbounded physics objects, uncontrolled chains, or permanent world mutations without a persistence design.

### Performance

Alchemy must not require long, repetitive interaction sequences for routine actions. Use clear feedback, reasonable effect lifetimes, bounded calculations, and server-side checks that are efficient enough for real-time combat.

## 7. Combat System

Build on the existing combat foundation. Do not replace it until its limitations are understood.

### Core actions

Support the existing intended combat actions, which may include:

- Light and heavy attacks.
- Combos and recovery windows.
- Blocking.
- Parrying.
- Dodging and evasion.
- Alchemy abilities.
- Weapon-specific moves.
- Enemy attacks and boss mechanics.

Maintain responsiveness while preserving meaningful timing, positioning, and risk.

### Attack classifications

Every relevant attack should be classified as one of:

- `BLOCKABLE`
- `PARRYABLE`
- `UNBLOCKABLE`

These classifications must have consistent, documented gameplay semantics. An attack can be blockable, parryable, both, or neither only if the underlying representation explicitly supports that combination. Do not let different systems interpret the same classification differently.

Unblockable attacks must bypass ordinary blocking and parrying. They should generally have longer cooldowns or recovery windows, visible telegraphs, and clear dodge or positioning counterplay.

### Telegraphs and fairness

Initial tuning targets for testing:

- Standard unblockable attacks: approximately 0.6–1.0 seconds of warning.
- Large, high-damage, or boss attacks: approximately 1.0–1.5 seconds of warning.

These are starting points, not universal final values. Tune them through playtesting, attack speed, animation readability, latency, and difficulty.

Ensure:

- The warning matches the actual attack area.
- The player has a realistic opportunity to react.
- Attack commitment is clear.
- Tracking does not abruptly change after commitment unless explicitly telegraphed.
- Hit detection and damage resolve consistently on the server.
- Effects do not obscure critical combat information.
- Different enemy types remain readable and distinct.

### Unified combat pipeline

Player, enemy, and boss attacks should use consistent shared resolution rules where feasible. Centralize damage, defense interactions, hit validation, status effects, and combat logging instead of creating contradictory implementations.

Test blocking, parrying, dodge timing, overlapping attacks, latency, death during combat, and invalid remote requests.

## 8. Connected Skill Tree

Create or extend a connected-node skill tree inspired by the general concept of interconnected progression, while preserving Rensei's own UI identity.

Audit the existing skill UI and progression system first.

Requirements:

- Connected nodes and readable prerequisites.
- Meaningful choices and specialization.
- Clear costs, requirements, and unlock feedback.
- Visible locked, available, purchased, and unavailable states.
- Genuine effects when a node is unlocked.
- Server-authoritative purchases.
- Safe handling of duplicate requests and insufficient points.
- Persistent purchases and backward-compatible data.
- Responsive PC and mobile layouts.
- Consistent visual language with the existing Rensei UI.

Avoid a decorative tree whose nodes do not affect gameplay. Avoid copying another game's exact layout or presentation.

## 9. Character Creation and Identity

Audit existing character creation before extending it.

Potential customization includes:

- Hair and face options.
- Skin tone and cosmetic markings.
- Clan or lineage identity.
- Initial weapon preference, including fists if supported by the existing design.
- Other already established character identity choices.

Character creation must have a clear data model, sensible defaults, server validation, persistence, and support for existing characters.

If clan rerolls or paid customization exist, inspect the current monetization rules before modifying them. Do not create paid mechanics without an established design and appropriate purchase validation.

## 10. Lore and Main Story

Rensei should feature a coherent, original world shaped by industrial development, alchemy, military authority, conflicting interests, and contested history.

### Central mystery proposal

A possible central mystery is **The Cost of Reconstruction**: historical large-scale alchemical experiments may have concealed consequences that powerful institutions still seek to control.

Treat this as a proposed framing device until verified against existing lore. Reconcile it with established characters, historical events, factions, and world rules before implementation.

### The player's rise

The player begins without legendary status. Their recognition develops through investigation, skill, discoveries, difficult decisions, and demonstrated achievement.

The title **Legendary Alchemist** should be earned and reflected in appropriate dialogue, reputation, story events, and ending outcomes.

Do not make every NPC instantly recognize the player. NPC knowledge and reactions should reflect local events, faction affiliation, personal history, and actual player achievements.

### Suggested narrative progression

Use the following as broad structural guidance:

1. Unknown — establish the player's identity and immediate goals.
2. Discovery — uncover contradictions and hidden evidence.
3. Proof — establish what happened and who benefited.
4. Controversy — face competing interests and public consequences.
5. Legacy — determine what the player will preserve, reveal, destroy, or control.

Preserve established story canon over this proposed outline.

## 11. Quest and Mission Framework

Support reusable quest types, including:

- Main story missions.
- Regional quests.
- Faction missions.
- Investigations.
- Puzzle and exploration quests.
- Repeatable contracts.
- Character-specific or relationship quests where appropriate.

A quest definition should clearly identify its ID, objectives, prerequisites, state transitions, rewards, dialogue conditions, and persistence requirements.

Use reusable objective handlers rather than writing an entirely separate system for every quest.

Potential objectives include:

- Talk to a character.
- Reach a location.
- Defeat a target.
- Collect or deliver an item.
- Find or interpret evidence.
- Activate an environmental mechanism.
- Complete an alchemy challenge.
- Make a consequential choice.
- Protect, rescue, or escort an NPC.

Provide clear journal feedback and track progress reliably. Reward claims must be idempotent so that repeated requests cannot duplicate rewards.

## 12. Dialogue, Investigations, and Evidence

Dialogue should be able to respond to meaningful player history.

Conditions may include:

- Quest and story flags.
- Faction standing.
- Public reputation.
- Relationship history.
- Clan or lineage.
- Evidence discovered.
- Relevant alchemy or skill capabilities.
- Prior decisions.

Use stable IDs for dialogue nodes, choices, clues, and evidence records.

Evidence should matter mechanically. Discoveries may unlock dialogue, reveal contradictions, open routes, establish prerequisites, or change the available interpretation of an event.

Allow characters to disagree, lie, misunderstand events, or possess incomplete information when appropriate. Do not automatically present every NPC's account as objective truth.

## 13. Puzzles and Environmental Exploration

Puzzles should reinforce alchemy, observation, world history, and environmental understanding.

Potential categories include:

- Alchemical reaction puzzles.
- Transmutation and material manipulation.
- Environmental mechanisms.
- Investigation and deduction.
- Exploration and hidden-route puzzles.
- Multi-stage challenges that combine several mechanics.

### Puzzle design rules

- Provide fair clues and consistent world logic.
- Make failures recoverable unless an irreversible consequence is intentional and communicated.
- Do not require one specific alchemy path for every major puzzle.
- Where practical, offer alternate approaches for different builds.
- Keep puzzle state and rewards consistent across reconnects.
- Define multiplayer ownership explicitly: individual, party-shared, or world-shared.
- Prevent repeated interactions from duplicating rewards or corrupting state.

## 14. Factions and Reputation

Audit existing factions before adding new ones.

Potential faction concepts to reconcile with established canon include:

- Military institutions.
- Rebels or resistance groups.
- Independent alchemists.
- Rogue alchemists.
- Remnants of historical research organizations.

Reputation should not be reduced to a single good-versus-evil meter.

Potential dimensions include:

- Public Reputation.
- Faction Standing.
- Moral Record.
- Forbidden Knowledge.
- Personal Relationships.
- Story Flags and historical decisions.

NPC reactions should be contextual. A decision might improve standing with one faction while damaging trust with another.

Reputation changes should have traceable causes and should not be silently overwritten by unrelated events.

## 15. Cinematic Choices and Consequences

Major story decisions should feel consequential without creating an unmanageable number of completely separate campaigns.

Use a branching structure with meaningful changes to dialogue, relationships, quests, access, survivors, faction outcomes, and ending eligibility. Branches may converge where doing so preserves the impact of prior choices.

### Proposed decision points

These are examples to reconcile with actual story canon.

**Decision 1 — The Reconstruction Incident**

Possible approaches:

- Prioritize civilian safety.
- Secure valuable research.
- Attempt a risky transmutation.

**Decision 2 — The Official Account**

Possible approaches:

- Publicly expose the evidence.
- Pursue an official investigation.
- Destroy evidence to protect someone.
- Use the information as leverage.

**Decision 3 — The Human Cost**

Possible approaches:

- Rescue affected people and destroy dangerous research.
- Preserve evidence while protecting survivors.
- Coerce a researcher into cooperation.
- Take control of the research.

**Decision 4 — A City Divided**

Possible approaches:

- Protect civilians.
- Support a faction.
- Manipulate competing factions.
- Seize control of a research facility.

**Decision 5 — The Final Exchange**

Possible approaches:

- Destroy the mechanism at the center of the conflict.
- Seek a difficult alternative.
- Take control of the mechanism.
- Complete a forbidden transmutation.

These options must be adapted to the actual narrative and should not be added as rigid choices if they contradict existing canon.

### Choice implementation requirements

For each consequential choice, define:

- Choice ID and presentation.
- Availability conditions.
- Immediate outcome.
- Persistent story flags.
- Relationship and faction changes.
- Quest consequences.
- World or NPC consequences.
- Irreversibility rules.
- Ending eligibility effects.
- Multiplayer ownership and replication behavior.

Choices must be saved reliably and applied only once. Important cinematic decisions should not be accidentally duplicated by reconnects, latency, or repeated remote calls.

In multiplayer, establish whether a decision belongs to the initiating player, a party, or the shared world. Never assume that a global choice should automatically overwrite every player's individual campaign.

## 16. Endings and Legacy

Develop multiple meaningful endings based on accumulated history rather than one morality score.

Relevant inputs may include:

- Major story decisions.
- Evidence discovered and preserved.
- Relationships.
- Faction standing.
- Public reputation.
- Forbidden knowledge.
- Quest outcomes.
- Survivors and unresolved conflicts.
- The final decision.

Converging branches are acceptable if previous decisions still influence outcomes and the player's ending feels earned.

A forbidden or ambitious path may provide compelling advantages, but its consequences must be meaningful. Avoid portraying every morally difficult choice as a simplistic good or evil decision.

Redemption should require sustained actions, not one last-minute dialogue choice. Some consequences may be irreversible when that is established clearly by the narrative.

## 17. Existing Progression and Special Mechanics

Before changing progression, verify whether the existing project uses:

- Vitality.
- Strength.
- Alchemy.
- Speed.
- Intelligence.
- Mastery points.
- Experience requirements.
- Truth or Gate mechanics.
- Permadeath or PvP-related progression rules.

Historical design discussions may have included a 20 Mastery Point concept and special requirements involving zero Mastery Points and sufficient experience. **Do not implement those rules blindly.** Confirm the current game implementation and the intended design before changing them.

Preserve existing mechanics that remain part of the game. Document any conflicts between legacy systems and the proposed new architecture.

## 18. User Interface and Player Feedback

Reuse the existing UI framework and styling wherever possible.

Every significant action should provide understandable feedback, including:

- Ability activation and cooldowns.
- Resource costs and insufficient resources.
- Block, parry, and dodge outcomes.
- Skill requirements and purchases.
- Quest updates and reward receipts.
- Evidence discoveries.
- Dialogue choices and their availability.
- Story decisions and relevant consequences.
- Reputation and faction changes when appropriate.

Avoid excessive screen clutter. Preserve readability during combat and support different resolutions and input devices.

Do not introduce an entirely new visual language when existing Rensei UI conventions can be extended.

## 19. Multiplayer, Performance, and Security

Design new features with Roblox multiplayer constraints in mind.

- Establish clear ownership of individual and shared quest progress.
- Keep authoritative gameplay decisions on the server.
- Avoid trusting client-provided damage, rewards, prerequisites, or story outcomes.
- Apply appropriate request rate limits.
- Prevent duplicate rewards and duplicate story transitions.
- Keep temporary environmental changes bounded and clean them up.
- Avoid unnecessary per-frame server work and excessive remote traffic.
- Handle player departure during combat, quests, puzzles, and cutscenes.
- Consider latency when tuning telegraphs and defensive timing.
- Test multiple clients for synchronization issues.

Use Roblox services and APIs according to their actual capabilities and current project conventions. Do not invent unavailable APIs.

## 20. Implementation Phases

Implement incrementally in this order, adjusting based on the audit.

### Phase 0 — Project audit
Map architecture, identify existing systems, document dependencies, and establish a safe implementation sequence.

**Acceptance:** A grounded audit with identified files, reuse opportunities, risks, and tests.

### Phase 1 — Core contracts and persistence
Establish or extend shared definitions, state transitions, validation, and safe data migrations.

**Acceptance:** Existing profiles remain compatible, new fields have safe defaults, and invalid client requests cannot directly modify authoritative progression.

### Phase 2 — Alchemy vertical slice
Implement or repair one complete representative alchemy ability, from input to server validation, effects, feedback, cleanup, and testing.

**Acceptance:** The ability works in real gameplay, respects costs and cooldowns, and handles invalid or repeated requests safely.

### Phase 3 — Combat classifications and telegraphs
Unify attack classification, defense interactions, telegraphs, and server-authoritative damage where appropriate.

**Acceptance:** Blockable, parryable, and unblockable attacks behave consistently and provide fair counterplay.

### Phase 4 — Connected skill tree
Implement genuine unlocks, prerequisites, purchases, persistence, and responsive UI.

**Acceptance:** Purchases are validated, duplicate purchases cannot exploit the system, and nodes change gameplay.

### Phase 5 — Complete alchemy progression
Expand the verified alchemy design into a coherent ability set and environmental interaction framework.

**Acceptance:** Abilities are documented, balanced, server-validated, and compatible with existing systems.

### Phase 6 — Quest, dialogue, and investigation framework
Build reusable objectives, dialogue conditions, evidence, journal tracking, and reliable rewards.

**Acceptance:** A representative quest can be completed, saved, resumed, and rewarded without duplication.

### Phase 7 — Puzzle and environmental framework
Implement reusable puzzle state, clue handling, interaction validation, and multiplayer ownership.

**Acceptance:** A representative multi-stage puzzle has fair clues, recoverable failures, and reliable persistence where required.

### Phase 8 — Main story integration
Integrate confirmed lore, quest chains, evidence, faction interactions, and the player's gradual rise in recognition.

**Acceptance:** The story works as a connected experience without contradicting established canon.

### Phase 9 — Cinematic choices
Implement persistent major decisions, dialogue consequences, and explicit multiplayer decision ownership.

**Acceptance:** Choices are saved, applied once, and reflected in downstream content.

### Phase 10 — Endings and legacy
Implement ending eligibility and outcome resolution from persistent history.

**Acceptance:** Multiple endings are reachable through meaningful combinations of decisions and accomplishments.

### Phase 11 — Polish and quality assurance
Refine responsiveness, accessibility, UI consistency, performance, error handling, balance, and regression testing.

**Acceptance:** Major gameplay loops have been tested, critical issues are resolved or documented, and known limitations are explicit.

## 21. Testing Requirements

For every phase, provide relevant tests and distinguish automated checks from manual playtesting.

Test at least:

- Normal gameplay paths.
- Invalid and malformed client requests.
- Insufficient resources and unmet prerequisites.
- Repeated interactions and duplicate rewards.
- Player death and respawn where relevant.
- Disconnects and reconnects.
- Data migration and missing profile fields.
- Multiplayer synchronization.
- Ability and environmental cleanup.
- Story-choice persistence.
- Quest and puzzle recovery.
- Performance under reasonable load.
- Regression of previously working systems.

Use automated tests when supported by the existing project. If a test requires Roblox Studio or live multiplayer execution that is unavailable, state that clearly and provide exact reproduction steps.

Never fabricate test results.

## 22. Documentation and Reporting

Maintain useful documentation as the project develops.

Create or update the following supporting files when appropriate:

- `GAME_OVERVIEW.md`
- `ALCHEMY_SYSTEM.md`
- `COMBAT_SYSTEM.md`
- `SKILL_TREE.md`
- `QUESTS_AND_MISSIONS.md`
- `LORE_AND_WORLD.md`
- `STORY_CHOICES_AND_ENDINGS.md`
- `PUZZLES_AND_EXPLORATION.md`

If the `docs/` directory cannot be created because of a repository naming conflict, keep the files in the repository root until the conflict is resolved. Do not waste time blocking implementation on folder organization.

For each implementation phase, report:

1. What was inspected.
2. What was changed.
3. Which files were created or modified.
4. How the change works.
5. Tests actually run and their results.
6. Known issues and unverified behavior.
7. Any decisions requiring clarification.
8. The next smallest useful step.

Keep the documentation synchronized with actual implementation rather than describing planned features as completed.

## 23. Definition of Done

Rensei should ultimately provide a cohesive playable experience in which:

- Alchemy is useful in combat and exploration.
- Combat is responsive, readable, and fair.
- Defensive mechanics behave consistently.
- Skill progression produces genuine gameplay changes.
- Character identity and progression persist reliably.
- Quests, investigations, evidence, and puzzles interact coherently.
- The world reflects meaningful player decisions.
- Factions and relationships respond to player actions.
- The player earns recognition through demonstrated achievements.
- Multiple endings reflect accumulated history and final decisions.
- Existing systems remain functional.
- Server authority, data integrity, and multiplayer behavior are tested.
- Documentation accurately reflects the state of the game.

## 24. First Action

**Begin with Phase 0: audit the actual Rensei project.**

Do not start by rewriting everything. Establish the current state, identify the smallest valuable vertical slice, and implement it using the existing architecture. Then validate the result before expanding to the next phase.

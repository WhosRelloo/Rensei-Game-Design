# Rensei — Game Design & Development Documentation

**Genre:** Open-world dark industrial-fantasy action RPG  
**Platform:** Roblox  
**Purpose:** Central design reference and implementation guide for Rensei.

## Project Vision

Rensei is an open-world action RPG built around alchemy, fast-paced combat, industrial-era military structures, political conflict, suppressed history, and morally complex decisions.

Players begin without legendary status and gradually earn recognition through their actions, discoveries, relationships, and consequences. The world should feel interconnected and reactive, with meaningful progression and multiple approaches to combat, exploration, and problem-solving.

## Core Design Pillars

1. **Alchemy:** Five foundational paths—Flame, Ice, Earth, Wind, and Metal—with responsive combat applications, environmental interactions, specialization, and meaningful progression.
2. **Action Combat:** Responsive attacks, blocking, parrying, dodging, readable enemy telegraphs, and fair boss encounters.
3. **Connected Skill Progression:** A skill tree that rewards exploration and investment while supporting distinct playstyles.
4. **Open-World Exploration:** Investigations, puzzles, environmental mechanisms, hidden history, and regional quests.
5. **Consequential Storytelling:** Branching dialogue, cinematic decisions, faction relationships, persistent consequences, and multiple endings.
6. **Earned Reputation:** The player gradually earns the title of Legendary Alchemist through demonstrated achievements rather than prophecy or predetermined destiny.
7. **Multiplayer-Aware Design:** Server-authoritative combat and progression, secure persistence, and clearly defined ownership of story decisions.

## Development Principles

- Inspect the existing Roblox project before modifying it.
- Preserve working systems and established project architecture.
- Treat existing game code, UI, data structures, and lore as the source of truth when they conflict with unverified assumptions.
- Implement functional systems rather than placeholder interfaces or simulated features.
- Validate important combat, progression, rewards, and persistence operations on the server.
- Use versioned, backward-compatible data migrations.
- Test changes and document limitations honestly.
- The Nemesis system is shelved and must not be implemented unless explicitly reinstated.

## Design References

- **Alchemy design spreadsheet:** https://docs.google.com/spreadsheets/d/14b7JDV_HPnmWBPqhikNmvfxJyssCS1whiBA7jN46nc0/edit?gid=0#gid=0
- **Rensei UI reference:** https://cdn.phototourl.com/member/2026-10-09-dd3b5541-4a83-459c-bf28-815b07498d7e.webp
- **Crimson Desert skill-system inspiration:** https://www.gamesradar.com/games/rpg/crimson-desert-skills/
- **Additional skill progression reference:** https://www.thegamer.com/crimson-desert-best-starter-build-skills-kliff/
- **Related alchemy design conversation: https://chatgpt.com/share/6ac979ec-34fc-83e8-9cbe-abb628b1bccc

Related Rensei design conversation: https://chatgpt.com/share/6ac95c62-b374-83e8-9cbe-abb628b1bccc

Related story design conversation: https://chatgpt.com/share/6ac95c62-b374-83e8-a85a-c054074780c0

External games are inspiration only. Rensei must retain its own world, mechanics, presentation, characters, and identity.

Documentation Index

The following documents should be created as the project specification develops:

docs/GAME_OVERVIEW.md — Overall vision, design pillars, systems, and priorities.

docs/ALCHEMY_SYSTEM.md — Alchemy paths, abilities, interactions, specializations, and balancing.

docs/COMBAT_SYSTEM.md — Attack classifications, blocking, parrying, dodging, telegraphs, and enemy behavior.

docs/SKILL_TREE.md — Connected nodes, unlock requirements, progression, and UI behavior.

docs/QUESTS_AND_MISSIONS.md — Quest types, objectives, journals, rewards, and persistence.

docs/LORE_AND_WORLD.md — World history, factions, characters, mysteries, and canonical lore.

docs/STORY_CHOICES_AND_ENDINGS.md — Major decisions, persistent consequences, branching routes, and endings.

docs/PUZZLES_AND_EXPLORATION.md — Environmental puzzles, investigations, clues, and alternate solutions.

docs/CLAUDE_IMPLEMENTATION_PLAN.md — Technical audit, implementation phases, acceptance criteria, and testing.

Implementation Order

Audit the existing project and establish what already works.

Map existing architecture, dependencies, data structures, and UI.

Define shared data contracts and secure core services.

Build and test a complete alchemy-and-combat vertical slice.

Integrate skill progression and character creation.

Implement quests, dialogue, investigations, and environmental puzzles.

Develop the main story, cinematic choices, faction consequences, and endings.

Polish performance, accessibility, multiplayer behavior, persistence, and quality assurance.

Instructions for AI Development Assistants

Read this document and all relevant linked design documents before implementing major features. Inspect the actual project whenever access is available. Distinguish confirmed existing functionality from proposed designs, and resolve contradictions in favor of verified project behavior or explicitly documented canon.

Work incrementally. For each phase, explain the intended changes, implement them in the existing architecture, test them, and report what was completed, what remains, and any unresolved questions. Do not claim that code was changed, tested, or committed unless that action actually occurred.

The goal: Build Rensei as one cohesive game in which alchemy, combat, exploration, progression, character identity, and consequential storytelling reinforce one another.

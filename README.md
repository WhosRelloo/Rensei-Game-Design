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
- **Related al

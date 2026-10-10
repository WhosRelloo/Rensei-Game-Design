# Rensei Development Decisions

This document records established project decisions to help maintain consistency during development.

## Confirmed Direction
- Rensei is an open-world dark industrial-fantasy action RPG on Roblox.
- Alchemy, combat, exploration, character progression, and consequential storytelling are core gameplay pillars.
- Existing game systems must be inspected before implementation changes are proposed.
- Preserve working systems wherever possible.
- Development should proceed in small, testable phases.

## Alchemy
The five planned alchemy paths are:
- Flame
- Ice
- Earth
- Wind
- Metal

Refer to the main implementation plan and alchemy design spreadsheet for further details.

## Combat
Combat attacks use these classifications:
- BLOCKABLE
- PARRYABLE
- UNBLOCKABLE

Refer to the main implementation plan for the intended combat behavior.

## Shelved Features
- The Nemesis system is shelved and should not be implemented unless explicitly brought back into scope.

## Implementation Rules
- Audit before changing scripts.
- Do not assume planned systems already exist in the current game.
- Explain proposed changes before major rewrites.
- Test changes in Roblox Studio before considering them complete.
- Protect backups and do not publish without explicit approval.

## Open Questions
Record unresolved design decisions here instead of inventing answers.

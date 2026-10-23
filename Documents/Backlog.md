# Rensei Backlog

Owner's to-do list, in the owner's words. The order is the owner's, and none of it is started.

## Next, right after World Plan 1 (owner, 2026-10-21 and 2026-10-23)
- [ ] **Build every region in Blender** (owner, 2026-10-23): "Here's a PDF of all of the region layouts, I want all of them built in blender once all tasks are complete." The brief is `Documents/Rensei-Regional-Map-Design-Brief.pdf` (9 pages: world connections, shared rules, then one page per region). Seven places:

  | Region | Footprint (studs) | Palette |
  |---|---|---|
  | Lindenmoor | 2,048 × 2,048 (keep the village at its current coordinates; expand around it) | cypress greens, creek teal, field gold |
  | Central City | 2,560 × 2,560 | civic stone, aged brick, slate, restrained green |
  | Foundry Yard | 1,536 × 1,536 | soot, iron, furnace brick, ember |
  | Ishval | 2,048 × 2,048 | sandy orange, ochre, clay, oasis teal |
  | Aerugo Borderlands | 2,560 × 2,048 | warm ochre, vineyard green, white hill stone, irrigation teal |
  | Northern Wall | 1,536 × 2,048 | snow, ice blue, cold stone, deep pine |
  | Corrupted Lands | 3,072 × 2,560 | ash, charred earth, dead olive, corruption crimson |

  - Notes for when this starts: the brief's footprints replace the world spec's earlier "about 3,000 × 3,000" target. Each region's station, gate, freight yard, road passages and arrival points (World Plan 1) must be rebuilt into the new layouts, not lost. Keep the approved main-map style (the stepped part-ground). The layout pictures are schematics, "not final Studio coordinates".
- [ ] **Hostages:** "make a cool option for other players to take others hostage, and have it intertwine with the game's mechanics already". The owner's choices are in the spec draft `Documents/specs/2026-10-21-hostage-design.md`, which is waiting for owner approval:
  - taking: from knocked, plus a stealth grab;
  - what the captor can do: shield, ransom, bounty, journeys;
  - getting free: struggle, rescue, time limit, captor's choice;
  - where: never in safe zones.

## After the Foundry Yard plan (owner, 2026-10-23)
- [ ] **Gun class rework:** "Fix gun shoot mode aiming mechanics. (balance out the gun class completely, add a reload animation as well)".
- [ ] **Swimming revamp:** "Completely audit and revamp the swimming system. (I want it to be directional, with a dive system)".

## After the world plans (owner, 2026-10-20)

These start after the world, travel and seasons plans are finished (`Documents/specs/2026-10-20-world-travel-seasons-design.md`).

### Combat and movement
- [ ] **Climbing:** fix climbing on certain parts (like the well, etc.).
- [ ] **Health:** balance it out, so fights don't last forever.
- [ ] **Running attack:** fix it; it shouldn't be a knockback.
- [ ] **Down slam:** fix it not doing anything on uptilt.
- [ ] **Parry:** "Fix parrying so players can constantly spam F (let me know if I need to add parry attempt anims)".
  - Ask the owner before starting: should spam be blocked by a miss window (a parry attempt with its own animation and cooldown)? If so, which animations are needed?
- [ ] **Greatsword:** fix its sheathe position on the back.
- [ ] **Alchemy aim:** alchemy doesn't lock on with the lock-on; it fires in random directions.

### Performance and multiplayer
- [ ] **Lag and memory:** fix server lag and in-game memory use, so players aren't laggy or delayed.
- [ ] **Multiplayer response:** fix the response time.

### NPCs
- [ ] **Smarter NPCs:** improve their IQ and combat patterns, and the swarm system they use (`CombatDirector`).

### Stealth and identity
- [ ] **"???" name tags:** players show "???" over their head until you figure out who they are (Player Identities).
- [ ] **Assassination system:** build it on top of the detection system (sight, light, sound). **PvE only.**
- [ ] **Add assassinations to the game,** "like we talked about before (ONLY PVE)".

### Quests and UI
- [ ] **Trainer quests:** the alchemy trainers' quests don't work ("Pass [Trainer]'s examination").
- [ ] **Leaderboard:** the scroll doesn't work.
- [ ] **Party health bars:** they don't update live.

### World life (owner, 2026-10-20, during World Plan 1)
- [ ] **Civilian NPCs** that walk around Lindenmoor and react to the players and the environment, building on the rumour, reputation and morality systems (`RumourService`, `MoralityService`, `WitnessService`, `PerceptionService`).

## Already queued
- [ ] **Trading:** design approved (`Documents/specs/2026-10-19-trading-design.md`). The owner's rule: only after all the plans.

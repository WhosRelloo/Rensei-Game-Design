# Rensei Backlog

Owner's to-do list, in the owner's words. The order is the owner's, and none of it is started.

## Order after the region foundation (owner, 2026-10-24)
"I want the lindenmoor expansion to go first after foundation."
1. [x] **Lindenmoor expansion import into Ye** (owner: "The Lindenmoor expansion is gonna go in Ye"). The village stays where it is; the hub's trainers and trial sites move onto their reserved spots; the cliff gets `RenseiNoGrip`. Steps: `Documents/Lindenmoor Kit.md`, "Expansion (Blender)". *(Done 2026-10-24, import plan Tasks 1–9: in Ye's Studio Edit session, smoke-tested; not live until the owner saves Ye, walks it once in Play and publishes the place, Modules and RenseiServer. See `Documents/Lindenmoor Kit.md`, "The import is done".)* **Publish on hold** (owner, 2026-10-24: "Hold both"): Ye and Foundry Yard stay unpublished until the Foundry Yard plan finishes Foundry's game data, then both are published together. Publishing Foundry ships its new map.
2. **The Foundry Yard plan** (the first full region). When it has finished Foundry's game data, Ye (with the Lindenmoor expansion) and Foundry Yard are published together (owner, 2026-10-24: "Hold both"); the checkpoint is in `Documents/Lindenmoor Kit.md`.
3. **The gun class rework and the swimming revamp** (below), still after all the Foundry tasks.
4. **Then, in order** (owner, 2026-10-25): assassinations, stealth missions, consequences for wrong guesses, the Nemesis system (design approved: `Documents/specs/2026-10-25-nemesis-design.md`), reputation in investigations, then the main story. See "After the swimming revamp" below.
5. **Overnight go-ahead** (owner, 2026-10-25): "you can do everything you listed while I'm sleep, just make sure to post on the changelogs." Nothing is published; every finished piece gets a Changelog entry with a held Discord post.

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

## After the swimming revamp (owner, 2026-10-25)
In the owner's order:
1. [ ] **Assassinations** that work with the detection system (sight, light, sound). "I threw anims in the spreadsheet for it": read the animation spreadsheet first. This is the same work as the two assassination items under "Stealth and identity" below. It stays **PvE only**, as the owner said there.
2. [ ] **Stealth missions.**
3. [ ] **Consequences for wrong guesses** in minigames and puzzles on quests.
4. [ ] **Nemesis system:** "Gotta make the concept first". The owner has brought it back into scope (see Decisions.md), so it starts as a concept and design for the owner to approve, not code.
5. [ ] **Reputation shapes investigations:** expand the reputation system so it changes how NPCs answer during investigations. "some will lie to you or just refuse to tell you the truth, or some evil NPC's will spill secrets easier, etc."
6. [ ] **The main story** (concept draft: `Documents/specs/2026-10-25-main-story-concept.md`). Placed here by the controller (the owner left the slot open on 2026-10-25): after the reputation item, before the remaining regions are built, so it can teach every system. The owner can move it.

## After the main story (owner, 2026-10-25: "The older backlog can go after the main story task")
The items below, from 2026-10-20, now come after the main story (item 6 in "After the swimming revamp").

## After the world plans (owner, 2026-10-20)

These start after the world, travel and seasons plans are finished (`Documents/specs/2026-10-20-world-travel-seasons-design.md`).

### Combat and movement
- [ ] **Climbing:** fix climbing on certain parts (like the well, etc.).
- [ ] **Health:** balance it out, so fights don't last forever.
- [ ] **Running attack:** fix it; it shouldn't be a knockback.
- [ ] **Down slam:** fix it not doing anything on uptilt.
- [x] **Parry:** "Fix parrying so players can constantly spam F (let me know if I need to add parry attempt anims)". *(Done: confirmed by the owner 2026-10-25.)*
  - Ask the owner before starting: should spam be blocked by a miss window (a parry attempt with its own animation and cooldown)? If so, which animations are needed?
- [x] **Greatsword:** fix its sheathe position on the back. *(Done 2026-10-23: centred on the spine, steeper diagonal; `HolsterC0` on the Greatsword grip part, Assets package.)*
- [x] **Alchemy aim:** alchemy doesn't lock on with the lock-on; it fires in random directions. *(Done: confirmed by the owner 2026-10-25.)*

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
- [x] **Trainer quests:** the alchemy trainers' quests don't work ("Pass [Trainer]'s examination"). *(Done: confirmed by the owner 2026-10-25.)*
- [x] **Leaderboard:** the scroll doesn't work. *(Done: confirmed by the owner 2026-10-25.)*
- [ ] **Party health bars:** they don't update live. *(Still broken: owner, 2026-10-25.)*

### World life (owner, 2026-10-20, during World Plan 1)
- [x] **Civilian NPCs** that walk around Lindenmoor and react to the players and the environment, building on the rumour, reputation and morality systems (`RumourService`, `MoralityService`, `WitnessService`, `PerceptionService`). *(Done: the townsfolk system; confirmed by the owner 2026-10-25.)*

## Already queued
- [ ] **Trading:** design approved (`Documents/specs/2026-10-19-trading-design.md`). The owner's rule: only after all the plans.

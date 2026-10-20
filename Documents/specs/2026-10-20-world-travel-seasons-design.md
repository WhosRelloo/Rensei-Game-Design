# World Scale, Travel and Seasons: design

**Date:** 2026-10-20
**Status:** approved by the owner (2026-10-20). The place ids were created by the owner and are in the table below.

**Owner's words:**
- "I want the full map to be so big you have to use the train, etc. to TP to the place. I want it to really feel like a real RPG experience where all the systems connect together with the map to make something super immersive and breathtaking."
- "I want regions to be as big as VV Ultimatum's maps."
- "also add seasons into the game that effect terrain."

**Builds on:**
- [Rensei World Map](https://claude.ai/artifact/Qbm5hCE23tSRyu9mjPxRWK)
- [Rensei Region Layouts](https://claude.ai/artifact/J7yecfYa1uRf5cdarNt8HM)
- `Documents/Lindenmoor Kit.md` (the part-ground style)
- the Morality spec (`2026-10-19-morality-reputation-consequences-design.md`): rumours, Heat and Wanted

Every number in this document is a **PROPOSAL**.

## Scope

This spec covers the **world backbone**:
- the region places;
- travel between them (the train, road journeys);
- how travel ties into the other systems;
- seasons;
- shared code across places.

**Not covered here:** building each region's content. Every region (Foundry Yard, Central, and the rest) gets its own spec, and its own plan, later. Trading still waits until after all the plans (the owner's rule).

## Decisions (owner, 2026-10-20)

| Question | Decision |
|---|---|
| The train trip | **A playable ride:** a real carriage, 45–60 s, with events, then one loading screen. |
| Other travel | **Train plus roads.** Road exits lead to road journeys, which can be ambushed, and they're the only way for Wanted players. |
| Multiplayer | **Everyone aboard together.** All players in the carriage land on the same server. |
| Station tie-ins | **Fully tied in:** tickets by distance and class, a papers check, Wanted refusal or arrest, a stowaway route, rumours travel by train. |
| Trial rooms in Ye | **Move to their regions.** The Foundry core goes to the Foundry place; the training field stays in Lindenmoor. |
| Shared code | **Roblox Packages** with auto-update. |
| Region size | **About 2 minutes of running across:** about 3,000 × 3,000 studs at Rensei's run speed of 24 st/s. |
| Season length | **2 real hours each,** so a full year every 8 hours. |

## 1. World structure

- **One experience, one shared save.** Menu and Tutorial stay as they are, and these are the region places:

| Region | Place | Level band | Station | Road exits |
|---|---|---|---|---|
| Lindenmoor | **Ye** (keeps id 106992859583940) | 1–6 | Lindenmoor Station | north road (to the Foundry), east ridge (Halvard's Adit stays inside the region) |
| Foundry Yard | 109591196441030 | 5–12 | Foundry Junction | south road (to Lindenmoor), viaduct road (to Central) |
| Central City | 74075793529314 | hub | Central Terminal | west, east and north gates, and the undercity (story) |
| Aerugo Borderlands | 72020960130134 | 12–22 | none (road only), or a branch halt later | Vintner's Pass (to Central), ash wastes (to the Corrupted Lands) |
| Ishval | 133625615147752 | 18–30 | Ishval Rail Halt (East line) | desert road (to Central) |
| Northern Wall | 132378034692557 | 25–35 | none (the road is the climb) | the switchbacks (to Central), the ice caves (to the Corrupted Lands) |
| Corrupted Lands | 138436167547886 | 30–45 | none | ice caves, undercity, ash wastes |

- **Size:** each region is about **3,000 × 3,000 studs**. The Region Layouts plates become each region's heart (700–1,500 studs), and wilds, roads, side villages, camps and Forgotten Sites fill the rest.
- **Lindenmoor grows about 4×:** today's valley is the village core. Around it:
  - farmland and orchards;
  - Bramble Hollow as a real forest;
  - the north road, with the training field on it;
  - the gorge country;
  - Halvard's Adit's ridge.
- **Edges** are natural walls (ridges, gorges, fog forest, cliffs) with only the station and the road exits leading out. There are no invisible walls.
- **Performance budget:**
  - `StreamingEnabled` in every region;
  - part ground at 4-stud cells near paths and towns, 8–16-stud cells in the wilds;
  - about **60–90k parts per region**;
  - the Lindenmoor pipeline (Blender kit, `ground.lua`, `settle.lua`) is reused for every region.
- **Moves out of Ye:** the Foundry Yard core goes to the Foundry place, and each Forgotten Site trial room goes to its region as on the layouts plates:

  | Region | Trial rooms |
  |---|---|
  | Foundry | Silent Forge, Forge Floor |
  | Aerugo | Burned Laboratory, Ash Pit |
  | Ishval | Cracked Footbridge, Unstable Quarry |
  | Northern Wall | Frozen Station, Frozen Chamber, Silent Observatory, Gale Floor |

  The trainer questlines that point at them are re-pointed to the new places.
- **`Rensei.Places`** gains a `Regions` table. For each region:
  - its place id and display name;
  - its station (if any);
  - its road exits (each with its destination region and arrival gate);
  - its climate type (see section 5).

  `Rensei.Regions` (the rumour graph) gets the new regions, with the link minutes from the Region Layouts page, Plate A.

## 2. The train

**Flow:**
1. **Ticket hall:**
   - The clerk's prompt sells a ticket by destination and class:
     - 3rd class: base price;
     - 2nd class: ×2;
     - private cabin: ×5.
   - The base price comes from the route length in a `Travel` data module.
   - The ticket is kept in the profile until it's used or refunded.
2. **Papers check** at the State gate (section 4).
3. **Platform:**
   - A departure board shows the next train on each line.
   - Trains leave every **2–3 minutes**, and departures are worked out from the real clock, so every server agrees.
   - Boarding opens 30 s before departure.
4. **The ride (45–60 s):**
   - A real carriage model in the origin place, parked out of the playable world.
   - When it departs, everyone with a valid ticket inside it is in the ride.
   - Scenery scrolls past the windows; NPC passengers are seated; players can walk the cars.
   - Ride events, one per ride, picked by weight:

     | Event | Weight |
     |---|---|
     | ticket inspection (no ticket means a fine, or being thrown off) | 40% |
     | overheard rumour (a real rumour from the destination) | 30% |
     | pickpocket (stealth or a chase in the aisle) | 15% |
     | quiet ride | 10% |
     | bandit holdup (a fight in the aisle) | 5% |
5. **Arrival:**
   - Everyone still aboard is sent together by **one** `TeleportService:TeleportAsync` call, with a list of the players, so they arrive on the same server.
   - If that server is full, Roblox picks a fresh server for the whole group.
   - The teleport data carries the route, the arrival station and the class.
   - A custom loading screen shows the train pulling in.
   - The destination place spawns the group on its arrival platform, doors opening.
6. **Saves:** each traveller's profile is released before the hop with `DataManager:Release(Player)`, the same handover `FlowTeleport` uses. The destination waits for the release with `WaitProfile`.
7. **Failure:**
   - Retry with backoff (three tries, the same as `FlowTeleport`).
   - If it still fails, the train "breaks down": everyone gets off at the origin platform and the ticket is refunded.
   - A player who leaves mid-ride keeps the ticket for the next train.

**Units:**
- `StationService` (server, per place): tickets, the departure clock, boarding, ride events, departure.
- `TravelService` (server, shared): the group teleport, the save handover, retries and refunds, arrival spawns.
- `TrainRideClient`: the scrolling scenery, seats and loading screen.
- `Travel` data module: routes, prices, times, ride events.

## 3. Road journeys

- **The exit:** walking through a road exit opens a travel card showing the destination, the trip time (30–60 s), the risk, and who's coming (your party).
- **The trip:** a travel screen with a map, a road, and your party's marker moving along it. Then a teleport to the destination's road gate, by the same `TravelService`.
- **Ambush:**
  - **Base chance 15%.** It goes up by:
    - +5% at night;
    - +5% in winter;
    - +10% per Wanted level.
  - The cap is 60%.
  - The trip stops, and the party fights in a road arena in the origin place (bandits, Eclipse hunters, or a State patrol if Wanted).
  - When you win, or flee by leaving the arena's edge, the journey continues.
- **Who gets in:** free, with no papers check, which is why Wanted players and smugglers use it. A party travels together.

## 4. How travel ties into the other systems

- **Money:**
  - Tickets are a steady money sink. Prices are by route (Lindenmoor to Foundry: 3rd class 15).
  - A fine for riding without a ticket: 3× the price.
  - Prices go up 20% in winter.
- **Heat and Wanted (Plan 2):** the State gate guard reads the player's Wanted level.

  | Wanted | At the gate |
  |---|---|
  | 0 | waved through |
  | 1–2 | a bribe (2× the price), or a search (illegal items taken) |
  | 3+ | refused, and the guard calls an arrest (the Heat system's arrest flow) |

- **Stowaway:** the freight yard next to each station is a stealth route onto the cargo car. It uses the existing sight cones, light and footsteps. Getting caught raises Heat.
- **Rumours (Plan 1):**
  - Word of a deed also travels on the timetable: the next train out carries the rumour, so it can arrive before the player does.
  - Overheard-rumour ride events read real rumours waiting at the destination.
- **Quests:**
  - Trainer questlines and Forgotten Sites now send players travelling.
  - Some quests start on the train (a passenger who needs help).
  - `QuestService` gains an objective type, "arrive at region X".
- **Parties:**
  - Party members can buy tickets for each other.
  - A party always shares a carriage and a server.
  - A road journey takes the whole party.

## 5. Seasons

- **Cycle:** 2 real hours per season (spring, summer, autumn, winter), so a full year every 8 hours.
  - Worked out from UTC: `season = floor(os.time() / 7200) % 4`, so every server and region agrees.
  - Each change blends in over about **5 minutes**.
  - `Lighting.ClockTime` is unchanged (Perception's daylight stays as it is).
- **Ownership:**
  - `SeasonService` (server) publishes `Season` and `SeasonBlend` as attributes on `ReplicatedStorage`.
  - It also makes the changes that affect collision and gameplay for everyone.
  - `SeasonClient` makes the purely visual changes locally (colours, leaves, snowfall, foliage), so a change never floods replication.
  - Every part that changes with the seasons carries a tag (`SeasonGround`, `SeasonFoliage`, `SeasonWater`, `SeasonCrop`) set by the build pipeline.
- **Temperate regions** (Lindenmoor, Foundry, Central, Aerugo):

  | Season | Ground and trees | Water | Gameplay |
  |---|---|---|---|
  | Spring | fresh green, blossom on orchards, rain | some fords flood (impassable) | crops sprout |
  | Summer | lush; wheat full and gold | some riverbeds dry, so fords open | long clear sight |
  | Autumn | orange and red canopies, fallen leaves | normal | harvest (fields bare); fog lowers sight 15% |
  | Winter | snow on grass slabs (Snow material), bare branches with snow caps, snowfall | ponds and slow rivers freeze: walkable ice slabs at the water surface, so no swimming there | footprints in snow (trackable), quieter footsteps on fresh snow, sight −20% in snowfall, ticket prices +20% |

- **Other climates:**
  - **Ishval:** wet, dry, hot and sandstorm. Sandstorms cut sight 40% and hide tracks.
  - **Northern Wall:** always frozen. Its winter is a whiteout (sight −50%; the ice caves are the safe route).
  - **Corrupted Lands:** follow the Eclipse cycle (a crimson phase spawns more enemies).
- **Water stays terrain water** (`SwimService` reads it). Freezing adds a walkable ice part at the water surface, and the thaw removes it. Players on the ice when it thaws drop into the water and swim.
- **Ties to other systems:**
  - season-only quests and creatures;
  - crop and food prices follow the harvest;
  - stealth: sight changes are applied through `Rensei.Perception`;
  - rumours spread slower in winter (×1.25 minutes).

## 6. Shared code: Packages

- **Packages:** the shared code becomes Roblox **Packages** with AutoUpdate:
  - **Core:** services and managers;
  - **Data:** `Rensei.*` data modules;
  - **UI:** UI modules and screens;
  - **Combat:** weapons, alchemy and movement.
- **What stays per place:** each region place holds its map, its local NPCs, its local quests' data, and its own `Rensei.Places` region entry, which is read from the shared table.
- **Ye is where packages are edited and published.** Publishing a package version is a cloud action on the group's account, so the owner approves the first package creation.
- **Moving over:** the existing scripts move into the packages one group at a time, and each step is checked with the existing test suites (`ServerStorage.RenseiTests`) in Ye and in a second place.

## Build order

1. **Backbone:**
   - Packages;
   - `Travel` data;
   - `TravelService`, `StationService`, `TrainRideClient`;
   - Lindenmoor Station and a Foundry placeholder place (just its station and a test area);
   - one road exit each way.
   - The owner created all six region places (ids in section 1). Nothing is published.
2. **Station tie-ins:** tickets, money, the papers check, Wanted, the stowaway route, rumours on the timetable.
3. **Seasons in Lindenmoor:** `SeasonService` and `SeasonClient`, pipeline tags, freezing water, crops.
4. **Lindenmoor grows to about 3,000 studs**, using the existing kit pipeline.
5. **The Foundry Yard region** (its own spec): the core moved out of Ye, Silent Forge and Forge Floor.
6. **Central City** (its own spec), **then the borders**, one region at a time.

## Testing

- **Each step is play-tested in Studio:**
  - a two-place teleport test, with a group of 2+ (Studio's multi-client test where possible);
  - a failed-teleport refund;
  - the save handover;
  - the papers check at each Wanted level;
  - a season change on a forced short cycle;
  - ice on and off with a player standing on it.
- **Profile safety:** the owner's profile is snapshotted before and restored after every Play test.
- **Unit tests:** pure modules (`Travel` prices and routes, the season maths, ambush chance) get tests in `ServerStorage.RenseiTests`.

## Open items (not blocking)

- **Region names:** Vintner's Pass, Monteblanc, the Crimson Seam, the Soul Forge wings.
- **Aerugo:** whether it gets a branch rail halt later.
- **Fast travel:** whether there should be any beyond trains and roads. Not planned; the owner chose trains plus roads.

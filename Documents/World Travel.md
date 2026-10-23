# World Travel: trains, stations and roads

**Built:** World Plan 1, 2026-10-20 to 2026-10-23. **Spec:** `Documents/specs/2026-10-20-world-travel-seasons-design.md`.

**Owner:** "I want the full map to be so big you have to use the train, etc. to TP to the place. I want it to really feel like a real RPG experience where all the systems connect together with the map to make something super immersive and breathtaking."

Rensei is now several Roblox places that share one save: one place per region. You get between them in two ways:
- **the train**, which is the fast way;
- **the road**, which you walk, and which has no papers check.

Two regions are connected so far: **Lindenmoor** (the place Ye) and **Foundry Yard** (a placeholder place with just a station and a road). The other regions have place ids and travel data but no stations or roads yet.

**Every number in this guide is a PROPOSAL** unless it says otherwise. They all live in one data module (`Rensei.Travel`) or at the top of a service, so each is a one-line change.

---

## 1. What a player sees

### At the station

![Lindenmoor platform with the train](images/World%20Travel/lindenmoor-platform.jpg)

Lindenmoor Station stands beside the village. A full train stands at the platform with its doors open:
- the locomotive and tender;
- a baggage car;
- a 3rd-class coach;
- a dining car;
- a 2nd-class coach;
- a private-cabin car.

You can walk through every car you have a ticket for.

![Lindenmoor ticket booth](images/World%20Travel/lindenmoor-ticket-booth.jpg)

**1. Buy a ticket.** The ticket clerk stands in a booth beside the station house. Press the prompt and the clerk talks to you in the game's own dialogue box.

![The ticket window](images/World%20Travel/ticket-window.jpg)

The window offers:
- **Ticket for:** you, or a member of your party (it cycles through your party);
- the three classes, with their prices;
- **Never mind.**

The ticket goes into your save and stays there until you ride. If you don't ride, you keep it.

**2. Show your papers.** A State checkpoint stands between the ticket hall and the platform: a gate guard at a signed gateway with a "STATE CHECKPOINT" sign. What happens there depends on your Wanted level (section 3).

**3. Wait for the train.** The departure board on the platform shows the next train on each line.
- A train leaves every **2½ minutes**.
- The doors open **30 seconds** before it leaves.
- The times come from the real clock, so every server agrees on them.

**4. Board.** Walk into a car your ticket allows and take a seat (each seat has a "Sit" prompt). A conductor stops you at the door of a car your class doesn't reach. Nobody boards while knocked down, gripped, carried, gripping or carrying someone (section 2).

![The 3rd-class saloon](images/World%20Travel/third-class-interior.jpg)

![The dining car](images/World%20Travel/dining-car.jpg)

**5. The ride.** When the train leaves, the screen fades for a moment and you are in the moving train. The ride lasts **50 seconds**, and one thing happens on the way (section 2). You keep your seat, and you can walk the cars your ticket allows.

**6. Arrival.** The screen fades and you step off at the other station's platform. Your ticket is used up at that moment, not before.

![The Foundry platform](images/World%20Travel/foundry-platform.jpg)

The Foundry's station works the same way. Its ticket booth stands in the open ground below the platform, before the checkpoint, and the gate's ramp leads up past the guard.

### On the road

Each region also has a road out:
- Lindenmoor's **North Road** branches east off the hub road;
- Foundry Yard's **South Road** runs out through the town gate.

Each is a real stretch of road, about 380 studs long, with trees, banks and fences. It ends round a bend you can't see past. Walk round that bend and the game takes over for a moment, like a film cutscene:
1. your character keeps walking down the road;
2. the camera eases into a low follow shot;
3. the road darkens under the trees;
4. you appear walking in at the start of the other place's road.

Then you get control back. You can turn back at any point before the bend, and nothing happens.

---

## 2. Stations in detail

### Ticket prices (PROPOSAL)

The price is the route's base price times the class.

| Class | Times the base | Lindenmoor ↔ Foundry | Cars you can enter |
|---|---|---|---|
| 3rd class | ×1 | $15 | 3rd class, dining car |
| 2nd class | ×2 | $30 | adds 2nd class |
| Private cabin | ×5 | $75 | every car |

- **Other lines** (data only; no station built yet): Foundry ↔ City, $15, from level 8; City ↔ Ishval, $40, from level 18.
- **Winter:** prices go up 20%. Seasons aren't built yet, so it's always summer for now.
- **The fine** for riding without a ticket is 3× the base price ($45 on Lindenmoor ↔ Foundry).
- **A bribe** at the gate is 2× the 3rd-class price ($30).

### Ride events (PROPOSAL weights)

One event per ride, about 8 seconds in:

| Event | Chance | What happens |
|---|---|---|
| Ticket inspection | 40% | The conductor checks everyone. A stowaway pays the fine and gains +5 State Heat. Someone who can't pay is thrown off, which means the ride ends back on the platform they left from. |
| Overheard rumour | 30% | A passenger mentions a real rumour about one of the riders (preferring one already heard at the destination), or a piece of lore. |
| Pickpocket | 15% | $5 to $15 is lifted from one rider. The chase to catch the thief isn't built yet. |
| Quiet ride | 10% | Nothing happens. |
| Bandit holdup | 5% | Two bandits appear in the dining-car aisle. They stay aboard and vanish at arrival. |

### Dying on the train

If you die aboard, you drop out of the ride. You come to back in town, and **your ticket is still good**. (Ruling: you aren't pulled back into the train next to live bandits.)

### Nobody boards held

As on the roads, nobody escapes a grip or a carry by train, and nobody drags someone else aboard:
- anyone knocked down, gripped, carried, gripping or carrying isn't taken. The conductor says: "Not like that. Nobody boards down, held or holding someone."
- the server checks again when the train leaves, after the "doors closing" fade. Anyone who went down in the fade stays on the platform with their ticket.
- when the ride ends, anyone in the moving train who isn't riding it is put back on the platform.

### Seats

You sit only through a seat's prompt. Brushing or dropping onto a seat doesn't sit you. The server also checks that you're:
- close enough;
- standing in that car;
- not knocked down;
- holding a ticket that reaches that car.

---

## 3. The papers check and the stowaway route

### At the gate

| Wanted | At the gate |
|---|---|
| 0 | Walk straight through. |
| 1–2 | The guard stops you and offers two choices: **pay $30**, or **be searched**. Either clears you for 10 minutes. (For now the search takes nothing; there are no illegal items to find yet.) |
| 3+ | Refused. You're pushed back, you gain +10 State Heat (resisting a checkpoint), and the guard says: "Your face is on a poster. Not on my platform." |

- **No arrest yet.** The spec says a Wanted 3 player is arrested at the gate. There's no arrest system yet, so refusal plus Heat stands in for it (ruling).
- **No way round.** A railing with an invisible wall runs along the platform's back and ends. The server also checks your papers again when the train leaves, so a ticket holder who got onto the platform some other way still isn't taken. The conductor says: "Papers first — see the gate guard." A Wanted 3+ player hears "Your papers won't pass here." instead. Either line comes once per boarding.

### The stowaway route

Across the tracks from each platform is a **freight yard**. It has stacks of crates and a fence with one gap, opposite the baggage car's open side door.

- **Hide in the baggage car** when the train leaves and you ride without a ticket or papers. You ride in the baggage car; the conductor sends you back there if you wander into the coaches.
- **The yard watchman** uses the game's stealth rules: his sight cone, the light, and your footsteps.
  - If he sees you in the yard, you gain +5 State Heat, once per visit.
  - If he hears you running behind him, he turns to look.
  - Crouch in the shadows and stay quiet, and you get past.
- **If the inspector catches you aboard,** you pay the fine and gain +5 State Heat.
- **A ticket holder without papers** who hides in the baggage car rides as a stowaway too, but is caught for the papers, not the fare. The inspector gives them +5 State Heat and says: "A ticket, but hiding with the baggage? Your papers will be reported." They pay no fine, are never thrown off, and **their ticket isn't used** on arrival (ruling; built in the final fix wave, 2026-10-23).

---

## 4. Roads and ambushes

- **Anyone may use a road.** There's no ticket and no papers check, which is why Wanted players and smugglers use them.
- **You have to walk it.** The server tracks that you walked the road's stretches in order. These don't count:
  - teleporting to the end, or into the middle (for example to escape a fight or an arrest);
  - a respawn;
  - a big lag jump.
- **Joining from the side is fine.** You can step onto the first stretch from the fields beside it.
- **Who can't cross:** anyone knocked down, gripped, carried, gripping or carrying. A player in combat can cross; fleeing over the threshold is allowed.
- **Parties:** when you cross, party members who also walked the road and are within **40 studs** come with you, in the same teleport and onto the same server. Members further back cross when they reach the end. In the live game they are sent to the server their party went to if it still has room (best effort, for 2 minutes).
- **Ambushes:** there is one roll per crossing.
  - The chance is **15%**, plus 5% at night, plus 5% in winter, plus 10% per Wanted level, up to 60%.
  - On a hit, two or three bandits wait at a random spot ahead of you on the road.
  - They are real enemies. You fight them, or run past them to the end.
  - A bandit that chases too far off its stretch gives up and walks back.
  - Bandits left alone for 30 seconds are removed, with no reward.

---

## 5. How the group teleport and the save handover work

This is the part that keeps saves safe when players move between places.

1. **The trip goes into the save first.** Before anyone leaves, the server writes the trip into each traveller's save: the route, the destination, the arrival point and the class.
2. **The saves are handed over.** Each traveller's save is released, all at once, the same way the menu hands a save to the game.
3. **One teleport for everyone.** Everyone aboard (or everyone crossing together) goes in a **single** teleport call with the whole list of players, so they all land on **one server** (designed; untested until published). If that server is full, Roblox picks a fresh server for the whole group. A failed teleport is tried up to three times.
4. **Arrival trusts only the save.** The destination ignores what the player's own computer says. It reads the trip from the save:
   - **The trip ends here:** you appear at the right point, the exact ticket class you rode is used up, your saved region becomes this place, and the trip is cleared.
   - **The trip was going somewhere else** (for example it failed and you rejoined the place you left): the trip is cleared and you **keep your ticket**.
   - **No trip:** you may stay only if your saved region is this place. A new save or an old save with no region counts as Lindenmoor. Anyone else is sent to the place their save says they're in.
5. **If the teleport still fails after the retries,** the player is kicked. Their save was already handed over, so this is the safe choice, and the ticket isn't lost because it's only used on arrival.
6. **If the teleport stalls without failing** (designed; untested until published: the Studio tests call the watchdog directly), a watchdog acts 25 seconds after the send, on the train as on the road. A player still here with their save loaded goes back to the platform (or the road) with the ticket kept; one whose save was released is kicked, so nobody plays on a released save.

So a rejoin from the menu should put you back where your save says you are.

---

## 6. The Studio loopback

Studio can't teleport between places. So in Studio, `TravelService.Depart` does everything up to the teleport (it writes the trip into the save and runs the arrival code), then arrives **in the same place**:
- a train ride ends at this place's own platform;
- a road crossing ends at this place's own road start.

This is how every travel test runs. **The real hop between places has never run.** It needs a published game (next steps).

---

## 7. Tie-ins with the other systems

- **Money:** tickets, fines, bribes and pickpockets.
- **Heat and Wanted:** the gate, the yard watchman and the inspector all add State Heat.
- **Rumours:** word of a deed now rides the trains too. Lindenmoor, the Foundry, the City and Ishval are linked by rail (about 3–4 minutes a hop), so a rumour can arrive before you do. The overheard-rumour ride event reads real rumours.
- **Regions:** Aerugo, Ishval, the Northern Wall and the Corrupted Lands are on the rumour map, with their factions and law. A deed done outside every named area counts in that place's own region, **except in Ye's hub**, which stays the City under State law, as before (owner ruling, 2026-10-23: "Keep State law"). So unlicensed casting in the hub is still a State crime. Ye's named Lindenmoor areas count as Lindenmoor (Militia law), and Ye is still Lindenmoor for the station, rumours by rail and your saved region.
- **Quests:** a quest goal can be "arrive in X". It completes when you arrive there, or at once if you're already there when the quest (or its stage) begins.
- **Parties:** you can buy a ticket for a party member at the clerk, as long as their save is loaded. A party that boards together lands on one server (designed; untested until published). A road takes the party members walking with you.

---

## 8. Where everything lives

**Code in Studio** (edited in Ye, shared through Packages, which the owner publishes):

| Piece | Where | What it does |
|---|---|---|
| `TravelService` | `ServerStorage.RenseiServer` package | The trip in the save, the handover, the group teleport, arrival and the loopback |
| `StationService` | `RenseiServer` | Tickets, the departure clock, boarding and seats, the gate, stowaways, the yard watch, the ride |
| `RideEvents` | `RenseiServer` | The one event per ride |
| `RoadService` | `RenseiServer` | Walking the road, the crossing, parties, ambushes |
| `FlowTeleport` | `RenseiServer` | The teleport with retries; `SendGroup` sends a group in one call. Menu and Tutorial have **their own copies** in `ServerScriptService` (not the package); keep all three the same (synced 2026-10-23) |
| `Rensei.Travel` | `ReplicatedStorage.Modules` package, `Data.Rensei.Travel` | Routes, prices, classes, timetable, ride events, ambush chance |
| `Rensei.Places` | `Modules`, `Data.Rensei.Places` | Every region's place id; where a save should go |
| `Rensei.Regions` | `Modules`, `Data.Rensei.Regions` | The rumour map, including the rail links |
| `TravelClient` | `StarterPlayerScripts.TravelClient` (in **each** place, not a package) | The ticket window, the gate guard's window, the departure board, fades and the road crossing |

**How a place finds its station and road:** CollectionService tags on the map, put there by the build scripts:
- `RenseiPlatformTrain` and `RenseiRideTrain`;
- `RenseiTicketClerk` and `RenseiDepartureBoard`;
- `RenseiStationGate`, `RenseiFreightYard` and `RenseiWatcher`;
- `RenseiArrival`;
- `RenseiRoadPassage`, `RenseiRoadEncounter` and `RenseiRoadThreshold`.

**Copies in this repo** (`Art/Studio/Travel/`):
- `src/`: every script above, plus the test suites.
- `station_lindenmoor.lua` and `station_foundry.lua`: the build scripts for each place's station, freight yard and road. They can be re-run.
- `test_hook.lua`: the temporary profile hook used for Play tests.
- The train model is built in Blender: `Art/Blender/train/`.

**Tests** (in `ServerStorage.RenseiTests` in both Ye and Foundry):
- `Test_Travel` (Edit mode, Ye);
- the Play suites: `Play_Boot`, `Play_Travel`, `Play_Station`, `Play_Gate`, `Play_RideEvents`, `Play_Road` and `Play_Arrive`.

The same suite files are copied into **both** places. All of them passed in both places on 2026-10-23 (Task 11). The final fix pass then added tests to `Play_Gate`, `Play_Station` and `Test_Regions`; those newer copies are in Foundry but have only been run in Ye so far. Play tests write the owner's real save, so they always run with the profile hook: snapshot, test, restore, Stop, remove the hook.

---

## 9. Not built yet, or stand-ins

- **The real cross-place teleport:** only tested through the loopback. It needs a published game.
- **Arrest at the gate:** refusal plus +10 State Heat stands in for it until an arrest system exists.
- **Seasons:** the stations and roads always think it's summer. The seasons plan replaces two one-line stand-ins (`StationService.Season`, `RoadService.Season`).
- **The pickpocket chase:** not built (the money is just taken).
- **The search at the gate:** it clears you but takes nothing, because no item is marked illegal yet.
- **Foundry Yard is a placeholder:** just a station, a freight yard and the South Road on flat ground. Its spawn point is on the platform, past the gate. The boarding check still stops a Wanted player from riding, but it isn't a real town entrance yet.
- **Only one line is built:** Lindenmoor ↔ Foundry. The Foundry ↔ City line and the other roads are in the travel data, but their stations and roads come with those regions.

---

## 10. Owner's next steps

1. **Publish.** We never publish; this is yours. In this order:
   1. **Packages:** publish `RenseiServer` and `Modules` from Ye (the final fix wave changed both), and make sure the `ClientHandler` package is the version with the slide fix.
   2. **Update the packages in Foundry by hand.** Foundry never updates a package on its own: update `RenseiServer`, `Modules` and `ClientHandler` there, then check they match Ye.
   3. **Places:** publish **Ye**, **Foundry Yard**, the **Main Menu** and the **Tutorial**. Menu and Tutorial carry their own copies of `FlowTeleport` and `Places`, which were synced on 2026-10-23.
   4. **Shut down old servers.** Use **Migrate to Latest Update** (or shut down all servers) for Ye, so no old server runs pre-travel code against the new saves.
2. **Check your own save first.** Studio Play tests write your real save, and two test sessions ended outside the test hook's control (one stopped by someone else, one in the Studio crash). Before you test live, check your save for leftover test state: a `Travel.Trip` (should be empty), `Travel.Region` (should be where you really are), any travel tickets you didn't buy yourself (a Private-cabin ticket was bought while testing), and `SeededRegions` (set by the one-time region migration; check it matches a migration your save really went through). A Claude session can read these from Studio for you without changing anything.
3. **Ride Lindenmoor to the Foundry with 2+ players.** Buy tickets, pass the gate, board together, and check that **everyone lands on one server** in Foundry Yard. Then try the North Road together (stay within 40 studs) and check the same.
4. **Check a rejoin.** After arriving in the Foundry, leave and join the game again from the menu. It should return you to the **Foundry**, not Lindenmoor.

If anything goes wrong in those checks, note who was in the group, which way they travelled, and what each player saw. The servers' output (F9) will show any teleport errors.

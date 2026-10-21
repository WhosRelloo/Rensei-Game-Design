# Hostages: design

**Status:** draft for owner approval, 2026-10-21. Build it after World Plan 1, whose Tasks 8–9 (roads, the papers check and stowaways) it depends on.

**Owner's request:** "make a cool option for other players to take others hostage, and have it intertwine with the game's mechanics already".

**Owner's choices:**
- **Taking:** from knocked, plus a stealth grab.
- **Captor:** human shield, ransom, turn in for bounty, take them on journeys.
- **Escape:** struggle minigame, rescue, time limit, captor's choice.
- **Limits:** anywhere but safe zones.

Every number below is a **PROPOSAL**.

## 1. What it is
One player binds another and leads them around restrained. The hostage keeps control of their camera and can struggle, but can't fight, cast, sprint, climb or use items. Everything else runs on the systems the game already has:

| System | How hostages use it |
|---|---|
| `DownedManager` (Knocked, Grip B, Carry V) | Hostage is a fourth downed action. It uses the same weld, Lock and attributes pattern. |
| Detection (`PerceptionService`, `StealthUI`) | A stealth grab only works on someone who hasn't noticed you. |
| Heat / Wanted (`HeatService`), witnesses, rumours | Taking a hostage is a crime. Witnesses report it, and word of it travels. |
| Morality (`MoralityService`, Deeds) | Taking, ransoming, releasing, finishing and turning someone in each record a deed. |
| Parties (`PartyService`) | The hostage's party is who can pay a ransom and who mounts a rescue. |
| Money (`ProgressionService.SpendMoney` and money add) | Ransom moves money between players. |
| Travel (Tasks 5–9) | Hostages come along on roads. On the train, the conductor and the papers check can catch them. |

## 2. Taking a hostage
Two ways in. Both are refused in safe zones (§6) and on a target far below your level (§6).

- **From knocked:** stand over a knocked player and press **N** (the key sits next to Grip B and Carry V; mobile gets a button in the existing touch cluster).
  - It takes 1.5 s to bind, as a channelled action like Grip: getting stunned cancels it.
  - Once bound, the target stops being knocked and becomes a **Hostage**, at their current HP (at least 15% of max).
- **Stealth grab:** come up behind a player who hasn't noticed you and press N.
  - The game checks with PerceptionService's sight rules, run for the target player: you must be outside their view cone or in darkness or cover, and within 4 studs behind them.
  - A **grab struggle** starts at once (§4), with the bar at 40% instead of 0. If the target fills it within 3 s, they shove you off and you are stunned for 1 s. Otherwise they are bound.
  - A failed grab still counts as an assault (Heat and witnesses).

The captor gets attributes `Holding = <name>` and the hostage `HeldBy = <name>`, using the same attribute pattern as Grip and Carry. A captor holds one hostage at a time and can't also carry or grip someone.

## 3. While holding a hostage
- **Leading:** the hostage is welded in front of the captor, the captor's arm across them (an existing animation from the sheet, or a held Carry pose until the owner adds one).
  - The captor walks at 12 (Carry is 11), can't sprint, dash, climb or swim, and can only fight with light attacks from the off hand: no heavies, no alchemy.
  - Pressing **N** again opens the **captor menu**, a radial built from the existing emote wheel art.
- **Captor menu:**
  1. **Release.** Lets them go unharmed. It records a Mercy deed (`released_hostage`), and its Heat is only half that of the original crime.
  2. **Finish.** Runs the normal Grip on them (the same styles, the same deed and listeners), plus the deed `killed_hostage`: a big Heat rise, and a rumour whose text names "a hostage".
  3. **Demand ransom.** See §5.
  4. **Turn in.** Only offered next to a State desk or guard, and only if the hostage is Wanted. See §5.
- **Human shield** (owner's choice):
  - NPC guards and enemies whose attacks would hit the hostage first hold their attack. They circle for an angle instead; CombatDirector gets a "blocked line" check.
  - Player hits from the front land on the hostage. Hits from behind land on the captor.
  - Alchemy aimed at the captor through the hostage hits the hostage. This is why the alchemy lock-on fix in the Backlog matters here.
  - Witnesses see the shield use: the deed `used_human_shield`.
- **Time limit** (owner's choice): you can hold someone for 180 s. After that they slip free (it shows as a bar on both players' HUDs, drawn with the existing BossHealth/Fill art). Each re-take of the same player within 10 min halves the time.

## 4. Getting free
- **Struggle** (owner's choice): the hostage mashes or times a key (F, or tap on mobile) to fill a struggle bar.
  - Each press costs stamina. The bar fills faster the higher the hostage's Body stat is compared with the captor's, and drains slowly over time.
  - When it's full, the hostage breaks free and the captor is stunned for 1.5 s.
  - It's drawn with existing art: the QTE or minigame bars already in `MinigameService` and Uis.
- **Rescue** (owner's choice): any hit on the captor from behind or the side, a parry of the captor's light attack, knocking the captor, or alchemy that hits the captor frees the hostage at once. Party members, other players and guards can all do it. A guard who frees a hostage records it as witnessed, so the captor's Heat rises.
- **Time limit:** see §3.
- **Captor's choice:** Release or Finish (§3).
- **Automatic release** when:
  - the captor is knocked, dies, leaves the server, enters a safe zone, or teleports without the hostage (§7);
  - the hostage's own party wipes the captor's party.

After any release, the hostage gets 5 s of grab immunity and keeps whatever HP they had.

## 5. Ransom and bounty
- **Ransom** (owner's choice):
  - The captor picks an amount, from $50 to 10× the hostage's level × 10 (PROPOSAL).
  - Every party member of the hostage gets a demand popup in the existing Dialogue art: "<Captor> holds <Hostage>. Pay $X?" (Pay / Refuse).
  - The first to pay (through `SpendMoney`, all or nothing) frees the hostage. The captor receives the money, minus 10% that "goes missing", as a money sink.
  - It records deeds on both sides: `paid_ransom` (Mercy) and `took_ransom` (crime: Heat if witnessed).
  - If nobody pays within 60 s, or everyone refuses, the captor is told and keeps holding.
  - A hostage with no party can't be ransomed; the option is greyed out.
- **Turn in for bounty** (owner's choice): lead a Wanted hostage to a State desk (Foreman Brask's desk in the Foundry, or later desks) or a guard NPC, and choose Turn in. Then:
  - the hostage pays HeatService's normal fine for that jurisdiction (100 × level for Wanted ≤ 2), or, if they can't pay or their Wanted is 3+, it goes to the "cell" once the cell exists (the Morality plan). Until then: the fine, plus their Heat is cleared in that jurisdiction, plus they're released at the desk;
  - the captor gets a bounty (50% of the fine) and Order standing with the State (`turned_in_fugitive`);
  - turning in someone who isn't Wanted isn't offered.

## 6. Where it's allowed
- **Never in safe zones:**
  - regions with `Safe = true` in `Regions` (all are false today, so set it per region);
  - parts tagged `RenseiSafeZone`: station platforms and ticket halls, the Tutorial place, the Menu;
  - near a quest NPC in dialogue.
- **Never on a target 15+ levels below you** (PROPOSAL), and never on a player under level 5.
- **It's a witnessed crime** (owner's choice: towns are risky, the wilds are where it happens):
  - taking a hostage records `took_hostage` through MoralityService;
  - WitnessService captures it if anyone saw;
  - HeatService raises Heat in that jurisdiction (it counts as an assault, ×2);
  - RumourService spreads "someone took a traveller hostage on the north road".
  - In lawless regions (`Jurisdiction = "None"`) there's no Heat, only rumours and Morality.

## 7. Travel
Owner's choice: "Take them on journeys". This builds on World Plan 1.
- **Roads:** a captor can set off by road with a hostage. The hostage counts as a party member of the captor for this journey only, and arrives restrained. If an ambush hits, the hostage stays held, and bandits treat them like anyone else (shield rules apply).
- **Train:**
  - A hostage can't buy a ticket, and the captor can't board through the conductor's doors with one (the conductor stops you: "You can't bring them aboard like that.").
  - The **stowaway route** (Task 9's baggage car StowZone) works: smuggle them aboard.
  - A **ride Inspection** (Task 7) that finds a hostage frees them, fines the captor 3× the fare, and raises State Heat.
  - The **papers check** (Task 9) refuses a captor holding a hostage.
- **Teleports:** `TravelService.Depart` carries the pair: the hold is written into both Trips and restored on arrival. If either player doesn't arrive, the hold ends.

## 8. Feedback and UI (owner rule: only existing UI assets)
- **Hostage HUD:** the struggle bar and the time-left bar, using the existing Fill and BossHealth art. Plus a small "Held by <name>" plate using the NPC name plate art (`Templates.NpcTemplate`).
- **Captor HUD:** the time-left bar, and the captor menu on the emote wheel art.
- **Prompts:** "Take hostage (N)" uses PromptUI's custom style.
- **Ransom popup:** the existing Dialogue panel.
- **Toasts:** the existing `UIService.Notify`.
- **Animations:** the hold and struggle poses come from the Animation ID sheet (recheck it before wiring). Any that are missing are listed for the owner to make; until then the Carry pose stands in.

## 9. Data and code
- **New `HostageService`** (in `RenseiServer`, so it rides the package). It owns the state machine Free → Binding → Held → Free, and the attributes `Holding` and `HeldBy`. It reuses DownedManager's Attach, Detach and Lock (exported for it), and DownedManager's listeners.
- **New data module `Rensei.Hostage`** for the numbers (PROPOSAL).
- **New Deeds:** `took_hostage`, `released_hostage`, `killed_hostage`, `used_human_shield`, `paid_ransom`, `took_ransom`, `turned_in_fugitive`.
- **Save:** nothing new beyond the deeds and the re-take timestamps (`Data.Hostage.LastTaken[UserId]`), plus the Trip carrying `HeldBy` (§7).
- **Remotes:** one `Hostage` RemoteEvent with Take, Menu, Struggle and Ransom-answer actions. The server checks every action: range, state, safe zone, levels, cooldowns. Struggle presses are rate-limited on the server.
- **Tests:** `Play_Hostage` covers:
  - take from knocked;
  - a stealth grab refused when seen;
  - safe zones and the level gap refused;
  - a struggle frees;
  - a hit from behind rescues;
  - the timeout;
  - Release and Finish deeds;
  - ransom paid by a party member, with money moved;
  - turn-in fine and bounty;
  - road travel carries the hold;
  - conductor refusal;
  - an inspection frees.

  The two-player parts are simulated with a server-side test dummy (a Knockable rig), like the earlier suites, and then a real 2-player check is done in Studio's local server.

## 10. Not in this design
- PvP permadeath (still undecided).
- The cell or jail (Morality plan).
- Rescue missions for NPC hostages (a Backlog idea).
- Hostages in PvE: NPCs taking players, or players taking NPCs. The owner's PvE-only assassination rule is separate, and this design is player on player only.

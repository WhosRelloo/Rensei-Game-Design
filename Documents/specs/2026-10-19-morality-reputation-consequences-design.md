# Morality × Reputation: Consequences and Rewards — Design Spec

**Date:** 2026-10-19. **Status:** design approved section by section in chat; this written spec awaits the owner's review. Nothing is built yet.
**Builds on:** `Morality and Reputation Proposal.md` (2026-10-16, slices M1–M3 + M5 built: the Deeds Ledger, Conduct, Standing, Renown, Trust, `MoralityService`, Lise / Tobin / bandit content), `Identities and Forgotten Sites.md` (witness detection), `Data Storage.md`.
**Rules:** every number is a **PROPOSAL**. Every faction, place, title or lore detail not already in the game is marked **(new)** and needs the owner's OK. No existing mechanic is removed.

## 1. Owner decisions taken in the review

| Question | Decision |
|---|---|
| Thematic spine | **All three, layered:** the **Licence** is the main path, **Equivalent Exchange** is the rule for every reward, **nations** add regional flavour. |
| Kinds of payoff | **All:** progression and power, hunters and bounties, access and economy, allies and NPC behaviour. |
| Players | **Players can act on reputation:** licensed players take State bounties on Wanted players and arrest them; Circle initiates take Circle contracts. Opt-in (only Wanted players are huntable), arena and duels are neutral, unprovoked attacks on innocents are crimes. |
| Taboo | **Secret power, hunted if found:** real power, Private marks, State Wanted 5 when discovered, the Circle cuts you off, and a hidden State faction may offer recruitment instead. Irreversible and always warned. |
| Nations | **Lore-true tensions:** origin sets starting standing both ways (bounded so no origin is a net handicap). |
| Architecture | **A + C:** a data-driven consequence layer on the existing ledger, **plus** a rumour network that spreads deeds between places over time. |

## 2. Core model

```
DEED (server, once) ──► WITNESSES (who saw it, evidence left)
   │                         │
   │ at once                 ▼
   ├─► Conduct, Trust     RUMOUR ──hops between PLACES over real time──► arrives at a place
   │   (you / those there)   │  (carriers: gossips, State dispatch, Circle whisper-net,     │
   │                         │   a player witness's report)                                  ▼
   │                         └─ can be suppressed (silence, destroy evidence, vouch)   Standing / Renown / HEAT
   ▼                                                                                   applied THERE, with a reason line
TABOO marks (Private until a rumour or evidence exposes them)
                                   ALL TRACKS ──► CONSEQUENCE RULES ──► prices, access, trainers, allies,
                                                                        hunters, licence, techniques
```

1. **Deeds Ledger (exists).** Recorded once, server only. **Conduct** (Mercy / Candor / Order) and **Trust** with the people present apply at once.
2. **Rumour Network (new).** Standing, Renown and Heat change only when a deed's rumour **reaches** a place (§5).
3. **Tracks:**
   - Conduct;
   - Standing, now **per faction and per place**;
   - Renown, global plus "known in" per place;
   - Trust;
   - Taboo marks;
   - **Heat (new)**, per jurisdiction, turned into **Wanted 0–5** (§6).
4. **Consequence Rules (new).** One data table of `condition → effect` rules over all tracks (§9).
5. **The Exchange rule (new).** Every reward and choice declares a **Price** in another track, shown before you accept (§10).

## 3. Places (new data: `Rensei.Places` → extended)

A small graph of places. Each place has:
- **Factions present:** they react when a rumour arrives.
- **Jurisdiction:** `State`, `Militia` or `None`. This decides whose Heat rises.
- **Carriers:** links to other places, with hop times.
- **Safe-zone flag:** hunters never spawn there.

Starting graph (PROPOSAL):

| Place | Factions | Jurisdiction | Links (carrier, real minutes) |
|---|---|---|---|
| The City (hub, Ye) | Authority, Townsfolk, Circle (hidden) | State | Foundry (gossip 10, dispatch 2), Lindenmoor (gossip 20, dispatch 5) |
| Foundry Yard | Foundry, Townsfolk | State | City (gossip 10, dispatch 2) |
| Lindenmoor | Townsfolk, Circle (hidden) | Militia | City (gossip 20, dispatch 5), Halvard's Adit (gossip 30) |
| Halvard's Adit | — | None | Lindenmoor (gossip 30) |
| Each nation's region **(new, later)** | that nation's community | varies | border links: gossip 120+ |

**Carrier speeds:**
- **Gossip:** reaches every faction, slowly.
- **State dispatch:** fast, but only reaches the Authority.
- **Circle whisper-net:** fast, but only reaches the Circle.
- **A player witness's report:** instant, at the desk where they report.

## 4. Witnesses (new: `WitnessService`)

Who counts as a witness is decided by the **perception model in §17**: an NPC only witnesses what it actually perceived. Being seen and being **identified** are different (§17.6).

When a deed is recorded, the server captures:
- **Witnesses:**
  - NPCs and faction agents in line of sight and range (reusing `IdentityService`'s witness test);
  - players in range, recorded by the server;
  - each witness is tagged with their faction and whether they're a carrier.
- **Evidence:** a deed may leave an evidence item in the world (the existing Evidence / Inspect system). A later inspect raises the rumour, or creates one if it had died out.
- **Strength** = witnesses + evidence (PROPOSAL: 1 per NPC witness, 2 per agent, 3 per evidence). A deed with no witnesses and no evidence creates **no rumour**: it stays Private for good, unless Taboo evidence turns up.

## 5. Rumours (new: `RumourService`)

```lua
-- one rumour (in the save, Morality.Rumours, max 20 live; oldest settled first)
{Id, Deed, Origin = PlaceId, Strength, Born = os.time(),
 Reached = {[PlaceId] = os.time()}, Fronts = {{Place, Carrier, ArrivesAt}}, Suppressed = false}
```

**How a rumour spreads:**
- **Spread:** each front advances on a **60 s server tick**. On arrival the deed's Standing, Renown and Heat apply **for that place's factions** with a reason line ("Word reached the Foundry: you reported Lise").
- **Weakening:** each hop takes away 1 Strength. At 0 the rumour stops spreading.
- **Offline catch-up:** progress is computed from timestamps on load, applying every arrival in order. Offline time counts.
- **Idempotent:** a deed lands **once per place**. A repeat arrival from another route changes nothing.

**Suppression** (each is itself a deed with a price):

| Action | How | Price |
|---|---|---|
| Silence a witness | bribe (money) or threaten | Candor −5 or Mercy −5, Trust −20 with the witness |
| Destroy evidence | inspect and destroy | a Private deed. If discovered, it's worse than the original |
| Vouch | an ally whose Trust is ≥ 40 sends a counter-rumour; where both land, the original's Standing hit is **halved** | that ally's Trust −10 (a favour spent) |

**Player witness reports:** a player the server recorded as a witness can report you at a State desk or Circle drop. The rumour lands **instantly** in that jurisdiction. Reports for deeds they didn't witness are refused.

## 6. Heat and Wanted (new: `HeatService`)

Heat is kept per jurisdiction: **State**, **Circle** (informers and State dogs who hurt the Circle) and **Militia** (Townsfolk law). It rises when a crime's rumour arrives, or at once if one of the jurisdiction's agents witnessed it.

Whose Heat rises depends on the crime:
- **State and Militia Heat:** follow the place's jurisdiction (§3).
- **Circle Heat:** comes from deeds against the Circle, landing in any place where the Circle is present.

*"Per day played"* below means each real day on which the character played at least 30 minutes.

**Wanted thresholds** (PROPOSAL: 20 / 50 / 100 / 180 / 300):

| Wanted | Effect |
|---|---|
| 1 | Guards watch you; prices +10% in that jurisdiction. |
| 2 | Guards in State places demand surrender (yield = fine or arrest; resist = +Heat, straight to 3). State vendors refuse you. **A player bounty is posted.** |
| 3 | Enforcer squads patrol the places where you're known (CombatDirector squads). |
| 4 | A **State Alchemist hunter** is dispatched (an alchemist-type enemy). |
| 5 | A named elite hunter (boss bar); every State place is hostile. Discovered Taboo and the worst crimes only. |

**Getting clear:**

| Way | Who / when | Effect | Price |
|---|---|---|---|
| Fine | State desk, Wanted ≤ 2 | Heat → 0 | money (PROPOSAL 100 × level) |
| Cell | Arrested or surrendered | Heat → 0 | 3 min in a cell (an escape minigame = a new crime) |
| Pardon | An ally's testimony or a quest | Heat −100 | a favour spent (Trust) |
| Bribe | A corrupt officer (Trust or contact) | Heat −50 | money + Candor −5 |
| Safehouse | Circle initiates | Heat burns off 3× faster while inside | dues |
| Decay | No new crime | −5 Heat per hour | time. Taboo-level Heat never decays |

Crimes (new deeds, PROPOSAL):
- **Unlicensed casting** in a State place in front of agents (§7);
- **Assault** of an innocent player or townsperson;
- **Murder** (a grip on an innocent);
- **Escape**;
- **Contraband**;
- **Obstruction:** destroying evidence or silencing witnesses, once discovered.

## 7. The Licence path (new: `LicenceService`)

The rank ladder already exists (`Rensei.Ranks`: Apprentice → State Alchemist → Master → Philosopher's Tier). Reputation decides the road.

- **Apprentice (levels 1–5):** studying is legal everywhere.
- **From level 6, unlicensed casting is a crime** in State places when an agent sees it. Heat +10 per cast seen (capped at 30 per place per hour).

### 7.1 The State Alchemist Exam (quest)
- **Eligible:** level ≥ 6, Authority ≥ Neutral, State Wanted 0.
- **The three parts:**
  1. **Written:** Investigation deductions.
  2. **Practical:** a trial fight (TrialService).
  3. **Interview:** dialogue that reads Conduct and **rumours already known in the City**; lying is a Candor deed, and the panel asks about known rumours.
- **Gains:**
  - the `StateLicense` flag (rank 2);
  - the **Silver Watch** **(new item):** alchemy meter costs −15% while carried;
  - a **stipend** (PROPOSAL: 50 money per day played);
  - access to **restricted labs and archives** (State techniques: skill-tree nodes gated by `Licence = State`);
  - **legal cover:** force against Wanted targets raises no Heat;
  - **State bounties** and **arrest** rights.
- **Prices:**
  - Circle −20 and the Ishvalan community −10, as a Public rumour;
  - **State Orders:** about one assignment per 2 hours played, refusable at a cost (Authority −10 each). Some are morally hard (arrest an unlicensed healer, evict a family).
  - **Revocation:** three refused Orders in 7 days, or State Heat ≥ 50, revokes the licence. That's a Public rumour, Authority −30, and the rank drops back to 1.

### 7.2 The Circle's Initiation (quest)
- **Eligible:** Circle ≥ Trusted, plus a **sponsor** (an NPC with Trust ≥ 40, e.g. Lise).
- **Gains:**
  - the `CircleInitiate` flag **(new)**;
  - **Circle techniques** (skill nodes gated by `Licence = Circle`);
  - the **black market**;
  - **safehouses**;
  - no Orders.
- **Prices:**
  - dues (PROPOSAL: 30 money per day played);
  - unlicensed-casting Heat applies in full;
  - State labs are closed;
  - State bounty hunters.

### 7.3 Independent
No licence and no initiation:
- no crime while you avoid casting in front of State agents;
- neither side's top rewards.

### 7.4 Double agent
A licensed alchemist who does Circle deeds in secret gets both sides' rewards. Every such deed is a rumour with **State dispatch** as a possible carrier. If one reaches the City, the licence is revoked and you're at **State Wanted 4**.

### 7.5 Master rank
Either road:
- **State:** a promotion quest (Authority Honoured, levels 11–15);
- **Circle:** the Master's rite (Circle Honoured, sponsor Trust 60).

Sets `Promotion_Master` (the existing flag).

### 7.6 Rank 4: two routes (owner canon pending)
- **Legendary Alchemist:** Renown Famed plus the main-story capstone (plan §10: earned recognition).
- **The forbidden route:** the Philosopher's Stone (§8). Fits the rank's existing name, "Philosopher's Tier".

## 8. The Taboo layer

Irreversible. Always preceded by a "This can't be undone" confirmation.

| Mark | Power | Ties to |
|---|---|---|
| Philosopher's Stone use | Casts cost no meter for 30 s, and moves are amplified (PROPOSAL); the forbidden route to rank 4 | the Stone abilities already referenced in Clans |
| Human transmutation attempt | Forbidden knowledge (a unique technique); a forced Gate visit where **the Truth takes a price** (a limb, leading to **Automail**) | TruthService (the Gate), AutomailService |
| Chimera-making | A bound chimera companion | (new) |

How a Taboo act is treated:
- **Scope:** Private.
- **Rumour and evidence:** it creates a rumour only if witnessed, but always leaves **evidence**: a circle, remains or residue.
- **When discovered:**
  - State Heat jumps to Wanted 5;
  - the Circle drops to Hostile and cuts you off;
  - the **Shadow Office** **(new hidden State faction)** may send an **offer**: serve it and your State Heat is wiped, but you take Shadow Orders (darker) and Circle standing locks at Hostile.

## 9. Consequences (new: `ConsequenceService` + `Rensei.Consequences`)

```lua
-- a rule: when Condition holds (StoryLogic shape), Effect applies (server-evaluated, cached per player)
{Id = "foundry_prices", When = {Standing = {Foundry = "Trusted"}, Place = "Foundry"}, Effect = {PriceMult = 0.9}}
```

**Economy:**

| Standing | Effect at that faction's vendors |
|---|---|
| Hostile | Refuse to trade |
| Distrusted | ×1.2 |
| Neutral | ×1.0 |
| Trusted | ×0.9 |
| Honoured | ×0.85, plus exclusive stock |

- **Wanted:** State vendors refuse at Wanted ≥ 2.
- **Black market** (Circle fences): needs Circle ≥ Neutral or a contact; contraband buys are Private deeds.

**Access:**
- **Labs and archives:** licence only.
- **Safehouses:** initiates only.
- **Checkpoints:** a papers check between places. If you're Wanted, it's an arrest attempt, unless you take another way round: a smuggler route (Circle contact) or a **climb / ledge route** (parkour).

**Trainers:**
- Each path and style trainer has preferred values (Conduct + Trust). Their advanced lessons need them to be met; basic lessons are always open.
- At least one trainer per path accepts any Conduct, so there's **never a dead end**.

**Allies (Trust ≥ 40):** an NPC can be called once per 30 min to:
- **fight beside you** (a friendly squad member);
- **testify** (pardon, or vouch against a rumour);
- **hide you**;
- **tip you off** that a hunter is coming.

**Betrayal (Trust ≤ −40):** that NPC becomes a **fast carrier** to the State, and may tell hunters where you are.

**Remarks:** greetings use the rumours known in that place.

**New dialogue and quest conditions** (`StoryLogic`): `Wanted`, `Heat`, `Licence`, `Nation`, `Origin`, `Rumour` (known in a place), `Place`.

## 10. The Exchange rule

**Every** reward and consequential choice carries a `Price`:
- the price is the deed it records, or a direct cost;
- it's shown on the prompt **before** accepting: "*Price: the Circle will hear you took the Watch*";
- quests, dialogue choices, licence gains, techniques and Taboo acts all use it;
- data convention: `Price = {Deed = id}` or `Price = {Money = n}` / `{Trust = {...}}`.

The rule is enforced by a check: a reward definition without a `Price` fails the data validation script.

## 11. Nations: lore-true, bounded

- **Communities (new):** each origin has a home community faction, named by the owner. Placeholders: Amestrian Citizenry, Ishvalan Community, Xingnese Merchant Houses, Drachman Frontier, Aerugonian Guild, Xerxian Remnant.
- **Birth deed:** recorded at character creation, `born_<origin>`. It applies starting offsets that cut both ways:
  - each offset is at most **±20**;
  - **each origin's offsets add up to ≥ 0**;
  - the cause shows in the Journal.
  - Example (PROPOSAL): Ishvalan: Authority −15, Ishvalan Community +20, Circle +10; Amestrian: Authority +10, Ishvalan Community −10.
- **Origin opportunities:** a home trainer, contacts and origin quests (content).
- **The Exam interview** acknowledges origin in dialogue only. It's never a gate.
- **Borders:** rumours cross between nations over 120+ minutes, and lose 2 Strength at the border.

## 12. Players acting on reputation (new: `BountyService`)

**Contracts:**
- taken at a State desk (licensed players) or a Circle drop (initiates);
- target: a player who is **Wanted ≥ 2** with that faction;
- at most **2 hunters** per target, a 20 min contract, and a 15 min cooldown on the target after an arrest;
- the target is told: "You're being hunted".

**Dead or alive:**
- **Arrest** (knock, then **Carry** to a desk or cell): full pay, Order +2.
- **Grip:** half pay, Mercy −3.

**Arrest never kills.** The arrested player pays a fine or serves time, and their Heat clears.

**Pay:**
- money is scaled by the target's Heat, plus standing with the contract's faction;
- renown if the arrest is public;
- **×0.25** if the hunter is more than 10 levels above the target.

**Crimes against players:**
- attacking an innocent (not Wanted, outside the arena or a duel, unprovoked) is **Assault**;
- a grip on an innocent is **Murder**;
- both come with witnesses and rumours.

**Neutral:** self-defence (the victim struck first, as recorded by the server), the arena and duels.

**Anti-collusion:**
- the same hunter–target pair earns 50% then 0% pay within 24 h;
- no contracts between players in the same party;
- pay comes only from Heat that real crimes created.

## 13. Data (save, additive)

Schema bump to **5** with a migration step that adds empty tables:

```lua
Morality.Places   = {[PlaceId] = {Standing = {[Faction] = n}, Known = {[DeedId] = os.time()}}}
Morality.Rumours  = { ...max 20 live... }
Morality.Heat     = {[Jurisdiction] = {Value = n, At = os.time()}}
Licence           = {Path = "" | "State" | "Circle", Since = 0, Orders = {}, Refused = {}, Revoked = 0}
```

- **Global Standing** = a weighted sum of place standing. It's kept as the cache the existing code reads, so existing conditions keep working.
- **Bounded:**
  - 20 rumours;
  - Known lists are bounded by the deed list;
  - Orders keep only the last 10.
- **Protected:** `ProfileGuard` covers it all.
- **PvP contracts:** server memory only (they don't persist across servers).

## 14. UI

- **Journal → Standing tab** (the M4 slice from the October proposal):
  - factions per place, in words;
  - your conduct words;
  - your renown rank;
  - a **"Rumours about you"** list: only rumours you've learned of (a tip-off, overheard, or reported to you), with where they've reached;
  - your Wanted status per jurisdiction, with how to clear it.
- **HUD:**
  - a small **Wanted indicator** near the compass (Rensei art), coloured by jurisdiction;
  - a hunter-warning Field Note.
- **Prompts:** a `Price:` line on reward and choice prompts.
- **Leaderboard:**
  - the rank title is already shown;
  - licence and **Wanted (≥ 2)** are visible to other players, since they can act on it.

## 15. Anti-exploit and multiplayer

- **Deeds:** server-only and idempotent. Repeatables are capped; rumours land once per place.
- **Who owns what:** each player's deeds and rumours are their own campaign. No deed touches another player's save, except through PvP crimes and arrests, which record a deed in **each** player's own ledger.
- **Suppression costs:** suppression is never free; each method costs money, Trust or a deed.
- **Reports and bounty pay:** player reports need a server-recorded witness, and bounty pay needs real Heat.
- **Hunter fairness:**
  - never in safe zones, dialogue or quests;
  - a warning before they arrive;
  - a cap of 2 hunter arrivals per hour.

## 16. Build slices and acceptance tests

Every slice:
- backs up the scripts it touches;
- snapshots and restores the tester's profile;
- gets a Changelog entry;
- updates the status page.

| Slice | Builds | Acceptance (Studio Play) |
|---|---|---|
| **R1** Data | Schema 5 migration, `Rensei.Places`, communities, birth deeds | Old saves migrate with empty tables; a birth deed records once with its cause. |
| **R2** Witnesses + rumours | `WitnessService`, `RumourService` (tick, catch-up, suppression, player reports) | With a controllable test clock: a deed with 2 witnesses reaches the Foundry in 10 min (gossip) and the City in 2 min (dispatch), applying once each; offline catch-up gives the same result; silencing stops it. |
| **R3** Heat | `HeatService`, Wanted HUD, fine, cell | Unlicensed casting seen by an agent raises Heat; the thresholds give the right Wanted level; a fine clears it; Heat decays over time. |
| **R4** Consequences | `ConsequenceService`, rules table, new conditions, price multipliers, trainer gates, checkpoints | Each tier gives the right price; a gated lesson shows its reason; a Wanted checkpoint offers the climb route. |
| **R5** Licence | Exam and initiation quests, the Silver Watch, Orders, revocation, licence-gated nodes | Pass the exam → rank 2 + Watch + stipend; 3 refused Orders → revoked, Public rumour; initiation works with a sponsor. |
| **R6** NPC hunters | `HunterDirector` | Wanted 3/4/5 spawn their tier within the caps, never in safe zones, always after a warning. |
| **R7** PvP bounties | `BountyService`, desks, arrest via Carry | Multi-client test: contract → arrest → target fined / jailed, Heat cleared; pay ×0.5 / 0 on repeats; assaulting an innocent is a crime. |
| **R8** Allies + betrayal | Call ally, testify, hide, tip-off; betrayal carriers | An ally's vouch halves a landed rumour once; a betrayer speeds dispatch. |
| **R9** Taboo + Shadow Office | Marks, evidence, discovery, recruitment offer | Needs the owner's Taboo canon first. |
| **R10** Journal tab + polish + docs | Standing tab, rumour list, the `Price` lint | No raw numbers shown; every reward has a Price. |

## 17. Detection and stealth (added 2026-10-19)

**Owner decisions:**
- **Model:** inspired by *Thief* (light, shadow, sound), *Metal Gear Solid* (vision cones, alert phases, investigating noises) and *The Last of Us* (gradual awareness, searching, takedowns, listen mode). The ideas are borrowed; **none of those games' interfaces or assets are copied**.
- **Scope:** **everyone**. All NPC enemies, guards, witnesses and hunters use it.
- **Kit:** **all four tools**: takedowns, distractions, light control, Alchemic Sense.

### 17.1 Awareness and alert phases (`PerceptionService`, new, server)

Each NPC keeps an **awareness value from 0 to 1 per player**, which fills and drains over time.

| Phase | Behaviour |
|---|---|
| **Unaware** | Patrols / idles. |
| **Suspicious** (awareness >= 0.35) | Walks to the last thing it noticed (a sighting or a noise) and investigates; gives up after ~8 s. |
| **Alert** (awareness = 1) | If it sees you: combat, handed to `CombatDirector` (the existing squad AI). If not: **search**. The squad sweeps outward from your last known position, and guards within 40 studs are called in. |
| **Cautious** | After a failed search (~25 s): back to patrol for 3 min with sight and hearing x1.3. |

Today's distance-only aggro is replaced. Enemies enter combat only through these phases. Once in combat, the existing squad AI runs unchanged.

### 17.2 Sight

- **The view cone:**
  - **Primary:** 110 degrees, full rate.
  - **Peripheral:** 160 degrees, half rate.
  - **Behind:** nothing.
- **Range:** depends on the NPC type (below), with the fill rate falling off over distance.
- **Line of sight:** checked to your **head, torso and feet** separately. Each visible point adds a third, so partial cover helps.
- **Multipliers:**
  - crouching x0.5;
  - walking x1, running x1.5, sprinting x2;
  - **Exposure** (§17.4) x0.2 in deep shadow up to x1.2 in bright light.
- **NPC types** (PROPOSAL):

  | Type | Range | Notes |
  |---|---|---|
  | Grunt / Scavenger | 30 | slow fill |
  | Elite | 45 | |
  | State Alchemist / enforcer | 40 | hears alchemy from 2x further |
  | Hunters | 50 | |
  | Trial foes | | always aware (arena) |

### 17.3 Sound

Sounds are **events with a radius**. Each wall between the sound and the NPC removes 40% of the radius. Hearing a sound sends the NPC to **investigate the spot**: it learns where, not who.

| Sound | Radius (PROPOSAL) |
|---|---|
| Footsteps: crouched | 0 |
| Footsteps: walking on grass / dirt | 4 |
| Footsteps: walking on wood | 7 |
| Footsteps: walking on metal / gravel | 9 |
| Footsteps: running | x2 |
| Landing from height | 12 |
| Vault / roll | 10 |
| Water splash | 12 |
| Melee hit | 20 |
| Alchemy cast | 30 (the clap alone: 8) |
| Gunshot | 60 |
| Breaking something | 25 |
| Lock-picking | 6 |

Surfaces are read from the floor's material.

### 17.4 Light: Exposure (0-1)

- **What it's computed from:**
  - lamps, torches and windows, which are **tagged light sources** (`RenseiLight`, with radius and strength);
  - outdoor daylight, from the time of day;
  - whether you're in shadow, using a raycast to the strongest nearby light.
- **Computed** on the server for perception, and on the client for the HUD.
- **The HUD:** a small **eye sigil** in the transmutation-circle style shows your Exposure plus your movement noise. It's original art, not a copy of a "light gem".

### 17.5 Bodies, alarms, evidence

- **Bodies:** a knocked-out or dead person found by a guard -> that area goes **Alert**, and an **evidence** item appears (the existing Evidence system).
- **Revival:** a knocked-out NPC who is revived becomes a **witness**, if they saw you before going down.
- **Alarm bells** in State places: a guard at Alert runs to the bell, and ringing it puts the whole place on **Alert** for 60 s. You can **sabotage** a bell (a mechanism: Metal jams it, Earth buries it, or a lock-pick-style minigame).

### 17.6 Identification, masks and anonymous rumours

- **What identifies you:** a witness identifies you only if **distance <= 25**, **Exposure >= 0.4**, and you're **unmasked**.
- **Masks:** equipping one (Mask Equip animation) hides your identity. The witness still saw the deed, but not who did it.
- **Identified** -> a normal rumour (§5).
- **Not identified** -> an **anonymous rumour** ("a masked alchemist", "a stranger"):
  - no Heat or Standing for you;
  - the place goes Cautious for 10 min and tightens patrols.
- **Linking an anonymous rumour back to you:**
  - your **technique** or **weapon** matched by evidence;
  - a witness who later sees your face;
  - Player Identities records.

  Once linked, it becomes yours and lands in full, once. This is the investigation theme working both ways.
- **No witness and no evidence** -> no rumour at all (a ghost).

### 17.7 The player's kit

| Tool | Rules (PROPOSAL) |
|---|---|
| **Choke** (non-lethal) | From behind or above, on an Unaware or Suspicious NPC. 2 s, interruptible, quiet (radius 6). KO lasts until found / revived, or 5 min. A Mercy-friendly deed for persons; nothing for hostile mobs. |
| **Lethal finish** | Same conditions. 0.8 s, silent. Uses the Assassination animation or the weapon's Grip. Killing a person is a deed, and the body is evidence. |
| **Drop takedown** | From a ledge, wall run or climb onto an NPC below. |
| **Bodies** | **Drag** (the Drag animation, slow) or **Carry** (existing) into shadow or a **hiding spot** (tagged `RenseiHide`: containers, haystacks, alcoves). A hidden body is never found. |
| **Throwables** | Pick up (Ground Interaction) a pebble or bottle (stack of 3); throw lands a sound event of radius 12 at the impact point. |
| **Alchemic lures** | A no-damage cast per path, meter 5, sound 15 at the target point: Earth stone clatter, Wind door / shutter rattle, Flame spark, Ice frost crack, Metal pipe clang. |
| **Light control** | On a `RenseiLight`: Ice / Wind snuff it, Flame relights or flares it (blinding 1.5 s at close range), Earth / Metal shutter a window. A guard who sees a light go out turns Suspicious and goes to relight it. |
| **Alchemic Sense** | Hold the key: clap and palm to the ground. Outlines people **through walls** within 40 studs for 3 s. Meter 15, 20 s cooldown, you move at 50% while holding it, and the clap makes a sound of radius 8. |
| **Lock picking** | Locked doors and chests (`RenseiLock`). 3-6 s, sound radius 6. The Lock Pick animation. |

Players keep all their existing movement: climbing, ledge walking and swimming are stealth routes.

### 17.8 Stealth rewards

- **Ghost / no-kill completion** of a site, Order or contract: bonus Renown, and stealth flavour titles (PROPOSAL: e.g. "the Shade of <place>").
- **Contract conditions:** some Circle contracts and State Orders require **no alarms**.
- **Later skill-tree nodes:** quieter steps, faster chokes, a longer Sense pulse, a lure that costs less meter.

### 17.9 Animations

The Animation ID's sheet was re-read on 2026-10-19.

| Need | From the sheet | Status |
|---|---|---|
| Lethal takedown | Assassination `83505608395055` | available. **Its victim column is empty** |
| Drag a body | Drag `85054207968303` | available |
| Lock pick | Lock Pick `136478153650620` | available |
| Pick up a throwable | Ground Interaction `138121475774733` | available |
| Mask on / off | Mask Equip/Unequip `121711546680316` | available |
| Sense pulse | Clap `115558611088872` + Ground Slam `85976777038591` | in the game |
| Lethal finish by weapon | each weapon's GRIP | in the game |
| Wall cover | Wall Cover Left `134041804221664` / Right `111740908967094` | **broken uploads** (on the re-upload list) |
| Crouch walk | in the game | - |

**Needed from the animator** (placeholders until then):
- an assassination victim reaction;
- a choke and its victim;
- a drop takedown, with its victim;
- a throw;
- a cover peek;
- guard search / look-around;
- stuffing a body into a hiding spot.

### 17.10 Performance

- **Who runs perception:** only NPCs within **80 studs** of a player, at **0.2 s** per NPC.
- **Raycast budget:** at most 3 sight rays per NPC per tick, and a global cap of 120 per tick.
- **Sound:** handled as events, never scanned.
- **Light:** tagged sources, cached per place, never engine lighting queries.
- **Measuring it:** the R2 / S1 tests profile the cost with 20 NPCs near 2 players.

### 17.11 Build slices (they interleave with R1-R10)

| Slice | Builds | Acceptance (Studio Play) |
|---|---|---|
| **S1** Perception + phases | `PerceptionService`; enemies enter combat through phases; Suspicious investigation; search sweeps | Approaching an Unaware Grunt from behind in shadow doesn't alert it; walking into its cone fills awareness at the expected rates; losing it leads to a search, then Cautious. (Built with R2: witnesses use it.) |
| **S2** Sound + light | Footstep surfaces, sound events, wall muffling, `RenseiLight`, Exposure, the eye sigil HUD | Running on metal is heard further than walking on grass; a lamp put out lowers Exposure; a gunshot pulls guards. |
| **S3** Takedowns + bodies | Choke, lethal, drop takedown, drag / carry, hiding spots, bodies -> Alert + evidence, alarm bells | A choke on an Unaware NPC works and is refused on an Alert one; a hidden body is never found, a visible one raises Alert. |
| **S4** Distractions + light control | Throwables, alchemic lures, snuffing / relighting / shuttering lights, guards relighting | A lure pulls a guard off its patrol; a guard relights a snuffed lamp. |
| **S5** Alchemic Sense | Pulse, outlines, costs, clap sound | Outlines last 3 s through walls within 40 studs; the cooldown and meter are enforced on the server. |
| **S6** Identification + masks | Identification rule, masks, anonymous rumours, linking | A masked deed creates an anonymous rumour with no Heat; matching evidence links it once. |
| **S7** Stealth rewards | Ghost / no-kill tracking, contract conditions | A no-alarm Order pays its bonus once. |

## 18. Open decisions for the owner

1. **Names:**
   - the six nation communities;
   - the Shadow Office;
   - the Silver Watch (keep the name, or one of your own?);
   - the starter places beyond those in §3.
2. **Origin offsets:** the full table (§11). **The example values are placeholders.**
3. **Taboo canon:** confirm the three marks, what the Truth takes, and the chimera companion (R9 waits on this).
4. **Numbers:**
   - Heat thresholds;
   - stipend and dues;
   - Order frequency and the revocation rule;
   - fines;
   - bounty pay;
   - hunter caps.
5. **PvP permadeath interplay:** arrest never kills (proposed). Confirm that a **grip** on a Wanted player is still a normal knockout, not permadeath.
6. **Rank 4:** both routes, or only one?
7. **Stealth numbers:**
   - sight ranges;
   - cone angles;
   - sound radii;
   - the identification rule (25 studs, Exposure 0.4);
   - takedown times;
   - Sense cost and range.
8. **Animations:** commission the missing stealth animations (§17.9) and re-upload Wall Cover L/R.
9. **Lethal stealth kills of guards:** how heavy a deed. They're always deeds; the proposal is Mercy -5 and the evidence goes into rumours.

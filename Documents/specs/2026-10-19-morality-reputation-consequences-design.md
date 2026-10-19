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

## 17. Open decisions for the owner

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

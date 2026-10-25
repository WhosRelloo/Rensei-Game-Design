# Stealth missions: design

**Status:** concept **approved by the owner on 2026-10-25**. This file writes that concept up. Nothing here is built.

**When it's built:** after the gun class rework, the swimming revamp and the assassination system, in the owner's order (`Backlog.md`, "After the swimming revamp", item 2).

**Builds on:** the detection and stealth design in `specs/2026-10-19-morality-reputation-consequences-design.md` §17. That spec already designed awareness, alert phases, sight, sound, light, takedowns, bodies, masks and stealth rewards. Part of it is built (§6 below says which). This file adds the **missions** on top: where they happen, who gives them, smarter guards, seeing what guards see, and what a mission pays.

**Every number and every new name in this file is a PROPOSAL** unless it is marked as the owner's.

---

## 1. The owner's decisions (2026-10-25)

| Topic | Decision |
|---|---|
| Where | Purpose-built guarded compounds in each region. Big infiltrations run in a **private copy for the player's party**, on its own server. Smaller jobs happen in places that already exist, in the shared world. |
| From whom | **Hand-made story missions** for each compound, **plus repeatable contracts** built from templates, handed out by a job board or a fixer. |
| Guards | They think, **in the style of Metal Gear Solid** (inspired by, never copied): alert phases, a suspicion meter, shared memory. |
| Seeing guard vision | Vision cones drawn on the ground, **only while the player is in stealth stance**, tinting as suspicion rises, plus a suspicion marker over each guard's head. **No HUD radar.** Only existing UI assets. |
| Tools | Sneak, assassinate (PvE only), a non-lethal chokehold, carrying and hiding bodies, distractions, disguises. |
| Outcomes | Ghost, Quiet or Loud, each paying differently. Kills and knockouts feed Morality. Loud runs spread rumours. Contracts are where Nemesis rivals appear. |

---

## 2. Where missions happen, and who gives them

### 2.1 Two sizes of mission

| | **Big infiltration** | **Small job** |
|---|---|---|
| Where | A purpose-built guarded compound | A place that already exists: the Foundry underworks, the rail yards, Halvard's Adit, Lindenmoor's mine approach |
| World | A **private copy** on its own server, for the party only | The **shared world**, with other players around |
| Guards | The compound's own guards | The place's own guards, watchmen and townsfolk |
| Length (PROPOSAL) | 10–25 minutes | 3–8 minutes |
| Examples | Steal a waybill from a State Military depot; free an informant from a Circle safehouse | Tail someone, plant evidence, retrieve an item |

### 2.2 The compounds (one or two per region)

Each region gets at least one compound, built with the region builder like any other landmark. **All names and contents below are PROPOSAL placeholders.**

| Region | Compound (PROPOSAL) | Owner of the compound | Feel |
|---|---|---|---|
| Lindenmoor | **Survey field camp** at the mine approach | State Authority | Small and forgiving: the first compound, a few guards, lots of cover |
| Foundry Yard | **State Military rail depot** in the sidings | State Authority | Floodlights, loud metal walkways, shift changes |
| Central City | **Bureau records hall**; a **Circle safehouse** in the undercity | State Authority; Unlicensed Circle | Offices and archives; a hidden warren |
| Aerugo Borderlands | **Border customs fort** | State Authority | Open ground, long sight lines, vineyard cover |
| Ishval | **Quarry company compound** | a mining company (new faction, PROPOSAL) | Cliffs and ledges, sandstorms cut sight |
| Northern Wall | **Gatehouse cold store** | State Authority | Snow muffles steps, whiteout cuts sight, cold water |
| Corrupted Lands | **Containment camp** | State Authority | The last and hardest compound |

### 2.3 The private copy (big infiltrations)

- **Getting in:** the party walks up to the compound's entrance (a marker in the open world) and starts the mission there. Everyone in the party within **40 studs** of the entrance goes in together (the road crossing's rule).
- **The teleport:** it reuses the travel system exactly as World Plan 1 built it:
  1. the trip is written into each player's save first;
  2. the saves are handed over;
  3. **one** group teleport sends the whole party to a **reserved server** (a private server only this party can join);
  4. the mission server trusts only the save when they arrive.
- **What's new:** a new trip kind, "mission", which remembers where to send the party back (the compound's entrance in the region they came from).
- **Coming back:** when the mission ends (success, failure or everyone leaving), the party goes back the same way, to the entrance's arrival point.
- **Who can't go in:** the same rule as the train and the road: nobody knocked, gripped, carried, gripping or carrying.
- **Leaving early:** a player who disconnects or leaves goes back to their region on rejoin. The rest of the party carries on. The mission counts as failed only for the one who left.

### 2.4 Small jobs (shared world)

Three job types run in the shared world from the start (more can come later):

| Job | What you do | What it uses |
|---|---|---|
| **Tail** | Follow a person along their daily route without them noticing you, and see where they go | The townsperson's schedule and walking (`TownsfolkService`); their awareness of **you** (`PerceptionService`) |
| **Plant evidence** | Put an item somewhere it will be found (a desk, a locker, a coat) | The Evidence system, turned around. Planting is a deed (Candor), because it's a lie told with an object |
| **Retrieve** | Get an item out of a guarded spot and back to the giver | Inspect points, per-player items |

- **Shared-world rules:** the guards and people are the world's own, so other players can see you, get in the way, or be witnesses. The item or spot is **per player** (like puzzles today), so two players on the same job never block each other.

### 2.5 Story missions and contracts

| | **Story mission** | **Contract** |
|---|---|---|
| Made | By hand, one or more per compound | From a template: **a type + a place + a twist** |
| Given by | The main story or a regional story (a quest stage) | A **job board** or a **fixer** NPC |
| Repeats | Once | Yes, with a cooldown (the quest engine's `Repeatable` and `Cooldown`, which exist) |
| Layout | Fixed, with scripted moments | The compound's normal patrols, with the twist applied |

**Contract templates (PROPOSAL):**

| Types | Places | Twists |
|---|---|---|
| Retrieve, Plant, Tail, Knock out a target (non-lethal), Assassinate a target (PvE only), Sabotage (an alarm bell, a machine), Copy a document (the Ledger Cipher minigame) | Any compound, or a small-job place | Night only · No alarms · No kills · A disguise is supplied · Shift change halfway · The target moves on their schedule · A rival is on the same job (Nemesis, §5.4) |

**Givers (PROPOSAL):**
- **A job board** in each region (Lindenmoor's square already has a notice board prop that could hold it).
- **A fixer** per region who sides with a faction. The fixer's faction decides the jobs: a Circle fixer offers jobs against the Authority, and an Authority clerk offers "Orders" against smugglers and the Circle. This matches the Orders and Circle contracts already designed in the morality spec (§7, §17.8).

---

## 3. Guards that think

### 3.1 The alert phases

The owner's four phases map onto the phases `PerceptionService` already runs. **What exists stays; what's new is added on top.**

| Owner's phase | Already in the game | New for missions |
|---|---|---|
| **Normal** | "Unaware": the guard idles. After a failed search it is "Cautious" for 3 minutes (sight and hearing ×1.3) | **Patrols** along set routes, **look-outs** on high posts, and **radio check-ins** on a timer |
| **Suspicion** | "Suspicious": at awareness 0.35 the guard walks to what it noticed and looks for about 8 s | **Only one guard** goes to look; the others hold their posts. The guard says a line in a speech bubble (the townsfolk bubble, which exists) |
| **Alert** | "Alert": at awareness 1 the guard fights (the squad AI in `CombatDirector`), and calls in guards within 40 studs | A **radio call** to the whole compound, guards **converge**, and **reinforcements** arrive from a barracks door |
| **Search** | An Alert guard who loses you searches for about 25 s, then turns Cautious | A **sweep** outward from your last known position by several guards, then the **calm-down** ladder: Search → Cautious → Normal |

**Radio** is the owner's word. In this industrial world it can look like a field telephone or a signal whistle (PROPOSAL).

**The radio call is a window:** a guard has to stop for about 2 seconds (PROPOSAL) to make the call. Knocking him out in that window stops the alarm.

**After an alarm (PROPOSAL):** the compound stays tighter for the rest of the run: patrols move in pairs and the calm-down ends at Cautious, never Normal.

### 3.2 The suspicion meter

The meter is the awareness value that already exists (0 to 1, per guard, per player). It already fills from:
- **sight:** the view cone (110° full rate, 160° half rate, nothing behind), range by guard type, partial cover (head, torso and feet checked separately), crouching ×0.5, running ×1.5, sprinting ×2;
- **light:** Exposure, ×0.2 in deep shadow up to ×1.2 in bright light, from tagged lamps and the time of day;
- **sound:** footsteps by floor, landings, hits, casts and gunshots, muffled by walls. A sound sends the guard to **the spot**: it learns where, not who.

Missions change none of these rules. They only add new guard types with their own numbers (PROPOSAL: a **Sentry** with long sight and slow fill, an **Officer** who sees through disguises faster).

### 3.3 Shared memory

Today each guard mostly keeps its own counsel (it only calls guards within 40 studs at Alert). Missions add a compound-wide memory (all new):

| What happens | What the compound does |
|---|---|
| A guard hears a noise | Guards on the same radio net learn the spot a few seconds later (PROPOSAL 3 s) and the nearest free one may go to look |
| A guard finds a body (knocked out or dead) | Alert at the body's spot, a radio call, and an **evidence** item appears (already designed, §17.5 of the morality spec) |
| A guard misses a check-in (because you knocked him out) | After a grace period (PROPOSAL 30 s), a **search starts from his post** |
| A guard sees you and loses you | Your **last known position** is shared, so the sweep starts there, not at each guard's own spot |
| A light goes out | The nearest guard turns Suspicious and goes to relight it (already designed, §17.7) |

### 3.4 How guards walk

- Guards use the **same Mover** as the townsfolk (`TownsfolkService.Mover`: one path per walk, give-way in crowds, narrow-gap radii).
- Its walkability fix is **in progress in the Foundry Yard plan, Task 4b**. Missions wait for it.
- **Every compound** is checked with the same reach test the Foundry plan uses: every patrol point and post must be reachable on foot.

---

## 4. Seeing guard vision, and the player's tools

### 4.1 Vision cones and suspicion markers

**Owner's rule:** only existing UI assets, and **no HUD radar**.

| Piece | How it looks | When it shows |
|---|---|---|
| **Vision cone** | A flat, see-through wedge **drawn on the ground in the world**, from the guard's feet out to the edge of its sight. Two bands: the full-rate cone and the fainter half-rate edge. Plain world geometry, no new image | **Only while the player is in stealth stance** (PROPOSAL: stealth stance = the crouch that already exists). Only for guards near you (PROPOSAL: the 8 closest within 60 studs) |
| **Tint** | Pale while the guard knows nothing, amber as suspicion builds, red at Alert (PROPOSAL colours) | Live, from that guard's awareness of **you** |
| **Suspicion marker** | A small marker over the guard's head, built from the game's **transmutation circle** art (the same image the stealth sigil uses). It fills as the meter rises; it gets a sharp outline at Suspicion and turns solid red at Alert, so colour is never the only signal | Whenever the guard's meter for you is above zero, stance or not |

- **Honest limit (PROPOSAL for the first version):** the cone shows where the guard *could* see. Walls still block real sight, but the drawn cone is not trimmed by walls.
- **What's new in code:** each guard's awareness of *you* is sent only to you, so the cone and marker can show it. Today only the guard's phase is shared (as a character attribute).
- **Kept:** the stealth sigil (bottom left), which already shows your light and noise.

### 4.2 The player's tools

| Tool | Status today | How it works in missions |
|---|---|---|
| **Sneak** | **Exists:** crouch, shadow, quiet floors, footsteps by floor | Unchanged. Climbing, ledge walks, wall runs and swimming are stealth routes. The swimming revamp's diving adds underwater routes |
| **Assassinate** | **Not built.** Needs the assassination system first. The owner's animations are in the spreadsheet | **PvE only.** From behind or above on a guard who hasn't noticed you. Silent. A kill is a deed, and the body is evidence |
| **Non-lethal knockout** | Designed (the "Choke", §17.7), not built | A **chokehold from behind** on a guard at Normal or Suspicion. About 2 s, can be interrupted, quiet. **The guard wakes later and raises the alarm, unless he's hidden** (owner) |
| **Carry and hide bodies** | **Carry (V) exists.** Drag and hiding spots are designed, not built | Carry or drag a body into shadow or a **hiding spot** (crates, haystacks, alcoves, lockers). A hidden body is never found |
| **Distractions** | Sounds exist (`NoiseService`); throwables and lures are designed, not built | **Thrown objects** (a pebble or bottle; the noise lands where it hits) and **noise lures** (a small no-damage cast per alchemy path) through the existing sound system. A guard goes to look at the spot |
| **Disguises** | **New.** Built on the existing **Identities** | See §4.3 |

**Light control** and **Alchemic Sense** (§17.7 of the morality spec) also work in missions once they are built. They are not part of this concept.

### 4.3 Disguises

- **Getting one:** take a uniform from a knocked-out guard, or get one from a fixer for a contract with the "disguise supplied" twist.
- **What it does:**
  - **At range** (PROPOSAL: further than 10 studs), guards see the uniform and their meter fills very slowly, or not at all, while you act normally.
  - **Up close, a suspicious guard sees through it.** A guard already at Suspicion who gets within about 4 studs (PROPOSAL) or looks at you for long enough recognises you, and goes straight to Alert. Officers see through it faster.
  - **Acting wrong breaks it:** running, crouching in the open, carrying a body, casting alchemy or being in a place your uniform shouldn't be.
- **How it uses Identities:**
  - Players' records already note what someone wore ("dress"). A disguise changes what witnesses record, so a disguised deed points at the uniform, not at you.
  - Recognition follows the identification rule already designed in §17.6 (close, lit and unmasked): a disguised player who is recognised has their **real name** spread.

---

## 5. Outcomes

### 5.1 Ghost, Quiet, Loud

| Rating | What it means | Pay (PROPOSAL) |
|---|---|---|
| **Ghost** | Never seen: no guard's meter for you ever reached Suspicion, and no body was found | Base pay ×1.5, plus a Renown bonus and stealth titles (already designed: "the Shade of <place>") |
| **Quiet** | Seen (a guard got suspicious or saw you), but no alarm: no radio call ever went out | Base pay ×1.2 |
| **Loud** | The alarm went out, and you still finished and escaped | Base pay ×1.0 |
| **Failed** | Knocked down, caught, timed out, or everyone left | Nothing. A loud failure still spreads a rumour |

- **Contract twists** can demand a rating ("No alarms" means Quiet or Ghost). Missing it fails the twist's bonus, not the whole contract (PROPOSAL).
- **The end screen** reuses the existing quest-complete popup and banner art, with the rating as words (no numbers, as Morality does).

### 5.2 Kills and knockouts feed Morality and standing

These run through the existing Deeds ledger (`MoralityService`, `Rensei.Deeds`):
- **Knockouts** lean Mercy. **Kills** lean Ruthless. Repeats have diminishing returns, so morality can't be farmed (the morality spec's rule).
- **Standing:** the compound's owner faction loses standing if it learns who you are; the giver's faction gains it. A State depot hit for a Circle fixer: Circle up, Authority down.
- **Hostile mobs** (bandits, scavengers) are not deeds, as today. **Guards are people,** so their deaths are deeds.

### 5.3 Loud runs spread rumours

A Loud run is witnessed, so the existing witness and rumour system carries it:
- **Not recognised** (masked, disguised, in the dark or far away): an **anonymous rumour with your description** ("a stranger with a greatsword and a Xerxian coat"), built from what the guards actually saw. No Heat lands on you, but the description can be linked back to you later through evidence or Identities (already designed, §17.6).
- **Recognised:** a normal rumour with your **real name**, with Heat in that place's law and the standing changes.

### 5.4 Nemesis rivals

- **Contracts are where Nemesis rivals appear** (owner).
- **The Nemesis design isn't written yet.** It is item 4 on the Backlog after this one, and starts as a concept for the owner.
- **The owner's one decision so far:** a rival first comes back with a **rumour warning**. If the player ignores it, the rival comes with an **ambush**.
- This file only leaves the hook: the contract twist "a rival is on the same job" and a place for the rival's warning rumour.

---

## 6. Build order and dependencies

### 6.1 The order

1. **The townsfolk walkability fix** (Foundry Yard plan, Task 4b; in progress). Guards walk with the same Mover.
2. *(The owner's order puts the gun class rework and the swimming revamp here.)*
3. **Assassinations** (Backlog, item 1): the assassination system on top of detection. **PvE only.** This also brings the takedown pieces missions need: the kill from behind, bodies as evidence, carrying and hiding bodies.
4. **Stealth missions** (this file), in slices (PROPOSAL):

| Slice | Builds | Check |
|---|---|---|
| **M1** Smarter guards | Patrol routes, look-outs, radio check-ins, the radio call, shared memory, reinforcements, the calm-down ladder | A missed check-in starts a search from the guard's post; a heard noise reaches the radio net |
| **M2** Seeing vision | Ground cones in stealth stance, tint, the over-head marker, each guard's meter sent to its player | Cones show only while crouched; the marker fills and turns red at Alert |
| **M3** Tools | The chokehold, waking up and raising the alarm, drag, hiding spots, throwables, noise lures | A hidden guard is never found; a guard left in the open wakes and raises the alarm |
| **M4** Disguises | Uniforms, the range and close-up rules, Identities records | A disguised player passes at range and is seen through up close by a suspicious guard |
| **M5** Small jobs and contracts | Tail, Plant, Retrieve; contract templates; the job board and fixers | A contract built from a template pays once per cooldown |
| **M6** Private compounds | The "mission" trip kind, reserved servers, the return trip; the first compound (Lindenmoor's survey camp) and its story mission | A party of 2+ lands on one private server and comes back to the entrance |
| **M7** Outcomes | Ghost / Quiet / Loud, pay, deeds, anonymous and named rumours | A Loud, unrecognised run makes an anonymous rumour with no Heat |
| **M8** Nemesis hook | The rival twist and warning rumour | Waits for the owner's Nemesis concept |

### 6.2 What exists today, and what is new

| Exists today | New for stealth missions |
|---|---|
| `PerceptionService`: awareness 0–1, the phases Unaware / Suspicious / Alert / Cautious, investigating, searching, calling guards within 40 studs | Patrols, look-outs, radio check-ins and calls, reinforcements, compound-wide memory |
| Sight rules, `LightService` (Exposure), `NoiseService` (sounds by floor, wall muffling) | New guard types (Sentry, Officer) as data |
| The stealth sigil (`StealthUI`), crouching | Ground vision cones, over-head markers, each guard's meter sent to its player |
| Carry (V); knocked state; Grip (B) | Chokehold, drag, hiding spots, throwables, noise lures (designed in §17.7, not built) |
| — | Assassination (its own system first, PvE only) |
| Player Identities (records, dress, naming) | Disguises |
| `TownsfolkService` and its Mover, schedules, speech bubbles | Guards using the Mover; the Tail job reading schedules |
| `TravelService`: trip in the save, save handover, one group teleport, arrival trusts the save | A "mission" trip kind, reserved servers, the return trip |
| Quest engine: stages, `Repeatable`, `Cooldown`, `Outcomes`, quest deeds | Contract templates, the job board, fixers |
| Evidence and inspect points | Planting evidence; bodies as evidence |
| `MoralityService` and Deeds; `WitnessService`; `RumourService`; `HeatService` | Mission deeds; descriptions in anonymous rumours |
| Parties (`PartyService`) | Party entry to a compound |
| The region builder and its markers | Compound markers: entrance, patrol points, look-out posts, radio posts, hiding spots, barracks door |

---

## 7. Open questions (for later)

1. **Stealth stance:** is it the crouch that already exists (recommended), or a separate toggle?
2. **Where compounds live:** one extra place holding every compound (recommended, simpler to publish), or one per region?
3. **Party size** for a private copy: 4 (recommended), or the full party?
4. **Heat after a mission:** does a recognised Loud run's Heat follow you back into the shared world (recommended: yes, it's real law)?
5. **Wanted players:** can they take contracts? Recommended: Circle and fixer contracts yes, Authority Orders no.
6. **Lethal on story missions:** always allowed in PvE (recommended), or some story missions forbid kills?

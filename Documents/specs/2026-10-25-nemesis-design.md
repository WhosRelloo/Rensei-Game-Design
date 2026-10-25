# Nemesis system: design

**Status:** concept **approved by the owner on 2026-10-25**. This file writes that concept up. **Nothing here is built.**

**Background:** the Nemesis system was shelved (`Decisions.md`, "Shelved features"). On 2026-10-25 the owner brought it back as "Gotta make the concept first" (`Backlog.md`, "After the swimming revamp", item 4). "Nemesis system" is the owner's working name.

**When it's built:** after assassinations and stealth missions, in the owner's order (`Backlog.md`: assassinations, stealth missions, consequences for wrong guesses, **the Nemesis system**, then reputation in investigations).

**Sibling design:** `specs/2026-10-25-stealth-missions-design.md`. Its §5.4 leaves the hook this file fills: the contract twist "a rival is on the same job" and the rival's warning rumour.

**Builds on:** `specs/2026-10-19-morality-reputation-consequences-design.md` (rumours, Heat, detection and stealth, masks), `Morality and Reputation Proposal.md` (deeds, standing), `Identities and Forgotten Sites.md` (Player Identities), `Data Storage.md` (saves).

**Every number and every new name in this file is a PROPOSAL** unless it is marked as the owner's. Each one is tagged where it appears.

---

## 1. The idea in one paragraph

An ordinary enemy who beats you, gets away from you, or lives through a fight you started can become a **named rival**. It has a name, a title and a personality. It remembers how your last fight went and comes back changed: proofed against what hurt it, scarred where you hit it, and higher in its faction's ranks if it won. Before it comes for you, townsfolk warn you that someone is asking for you by name, so you can strike first. If you don't, it ambushes you. It ends when you kill it, spare it, or turn it into your informant. It is **PvE only**: rivals only ever hunt players, and a player is never a rival.

---

## 2. What exists today and what this adds

The system is mostly new, but it sits on top of systems that already run in Ye.

| Exists today (built) | Planned elsewhere (designed, not built) | New in this file |
|---|---|---|
| Enemies, their spawns, nation looks and weapons (`EnemyService`) | The assassination system, PvE only (Backlog item 1) | Rivals: promotion, names, titles, personalities |
| Squad fighting with combat roles such as Aggressor and Duelist (`CombatDirector`) | Stealth missions: compounds, contracts, disguises (sibling spec) | Hand-made faction leaders |
| Awareness, alert phases, light and sound (`PerceptionService`, `LightService`, `NoiseService`) | Masks and anonymous rumours (morality spec §17.6, slice S6) | The warning rumour and the ambush |
| Witnesses (`WitnessService`) | NPC hunters at Wanted 3–5 (morality spec §6, slice R6) | Adaptations and visible marks |
| Rumours between places, and townsfolk who pass them on (`RumourService`, `TownsfolkService`) | Reputation shapes investigations (Backlog item 5) | False rumours spread by a schemer |
| Heat and Wanted (`HeatService`) | | Kill, spare and turn endings; informants |
| Deeds, Conduct, Standing per place (`MoralityService`) | | The rival record in the save |
| Player Identities (`IdentityService`) | | A Rivals page in the Journal |
| Inspect points and deductions (`InvestigationService`) | | |
| Road ambushes by bandits (`RoadService`) | | |
| Parties (`PartyService`, framework) | | |

---

## 3. How rivals are born

### 3.1 The three ways to be promoted (owner)

An ordinary enemy can be promoted to a rival when:

| Trigger | What it means in play |
|---|---|
| **It kills the player** | The player dies to it (knocked and finished, or killed outright). |
| **It escapes the player** | It breaks off the fight alive and gets clear, for example after a retreat at low health. |
| **It survives an attack the player started** | The player struck first (an open attack, or an assassination or takedown that failed) and the enemy is still alive when the fight ends, because the player ran, died elsewhere, or gave up. |

- **Promotion is a chance, not a certainty** (PROPOSAL: 35% on a kill, 25% on an escape, 15% on a survived attack). See open question 2.
- **Not every enemy can be promoted** (PROPOSAL): only human enemies with a faction or a bandit crew. Never trial foes, sparring dummies, townsfolk or bosses.
- **At most one new rival per 20 minutes of play** per player (PROPOSAL), so a bad run doesn't flood the list.
- **The moment of promotion is shown:** the enemy says a short line, and a quiet toast says "*Someone will remember this.*" (PROPOSAL wording). Its name is not shown yet; you learn it from the warning rumour.

### 3.2 What a rival is

| Part | What it is |
|---|---|
| **Name** | Generated: a first name and a surname from the rival's nation (it keeps the nation look `EnemyService` gave it). |
| **Title** | Generated from its history, for example "the Scalded" after you burned it, or "Who Walked Away" after it escaped (PROPOSAL examples). The title changes as its story grows. |
| **Personality** | One of four: coward, duellist, schemer, zealot (§5.3). Picked at promotion and never changed. |
| **Faction and rank** | The faction it came from, and its rank in that faction (§3.3). |

- **Names are original.** Rivals get **their own name lists** per nation (PROPOSAL, to be written), not the character creator's lists, which include names the rivals must not use. Every generated name passes the project's existing Names rule (no clash with townsfolk, dialogue speakers or enemy display names).

### 3.3 Factions, ranks and leaders

Rivals rise toward a few **hand-made leaders** at the top of each faction, or are sent by them (owner). Leaders are written by hand, have their own story, and are never generated.

Today's factions are in `Rensei.Factions`. The owner's brief names three that hunt the player:

| Hunting faction | In the game today | Rival ranks (PROPOSAL) | Hand-made leader (PROPOSAL placeholder) |
|---|---|---|---|
| **State Authority** (the owner's "State Military") | Exists: `Authority`, with State Heat | Enforcer → Sergeant-Hunter → Hunt Lieutenant | **Inspector-General Isolde Varrick**, "the Long Ledger" |
| **Unlicensed Circle** | Exists: `Circle`, with Circle Heat | Runner → Warden → Elder's Hand | **Orla Fenwright**, "the Chalk Elder" |
| **Bandit crews** | **New.** Bandits are enemies today, but they have no faction (`WitnessService` treats them as faction-less). The first crew would be the Ore Road bandits from Foreman Brask's bounty. | Cutthroat → Crew Boss → Road Boss | **Hesk Morrow**, "the Toll-Keeper", head of the Ore Road Crew |

- **The other factions** (Foundry Hands, Townsfolk and the six nation communities) don't field rivals (PROPOSAL). They are not hunters.
- **Where an enemy's faction comes from (new):** a faction or crew setting on its spawn, or the compound it guards (a State depot's guards are Authority). Today enemies don't carry one.
- **Each rank up** makes a rival tougher, sharper-eyed and better escorted (PROPOSAL):

  | Rival rank | Fights like | Escorts | Sight |
  |---|---|---|---|
  | 1 | its original type | none | its type's own |
  | 2 | an Elite (blocks and parries) | 1 | Hunter range |
  | 3 | an Elite with one alchemy slot | 2 | Hunter range, Cautious for longer |

- **Above rank 3** a rival doesn't replace the leader. It becomes the leader's **right hand**: the leader takes notice of the player (a story flag) and may send other rivals.
- **Sent by a leader:** when the player's Wanted level or a faction's grudge is high enough, a leader can send one of their rivals instead of waiting for one to be born (PROPOSAL). This is where the planned Wanted 4 State hunter could come from.

### 3.4 How many at a time

- **About 5 active rivals per player** (owner: "about 5"; the exact number is PROPOSAL, see open question 1).
- **When the list is full:** a new promotion doesn't happen. Instead the existing rival from that faction (if there is one) hears about the fight and gains a rank (PROPOSAL).

### 3.5 PvE only (owner)

- Rivals only ever hunt players. A player is never a rival, and rivals never come from PvP.
- **Bystanders:** other players in the server who aren't in the hunted party can't damage a rival, and it ignores them (PROPOSAL). Nobody can steal someone else's ending.

---

## 4. How they come back

### 4.1 First, a warning (owner)

Before a rival comes for you, word reaches you that someone is **asking for you by name**.

- **How:** through the existing rumour system. Townsfolk already pass on rumours in their talk rotation (`TownsfolkService`). The warning is a new kind of rumour line: not a deed you did, but **someone looking for you**.
  - *"A woman with a burned arm was in here asking for you. Knew your name and everything."* (PROPOSAL line)
  - A townsperson you walk past can call it out, so you hear it even if you don't stop to talk (PROPOSAL).
- **It describes the rival and where they are:** their marks, their faction, and where they were last seen ("staying by the rail yard").
- **It is your chance to strike first.** Go to that place and find the rival before it finds you. It's there, unaware, with its escorts. You can:
  - assassinate it (the planned PvE assassination system);
  - fight it on your terms;
  - lure it with noise, or set up an ambush of your own.
- **The Journal** keeps the warning on the rival's page (§9), so a warning heard once isn't lost.

### 4.2 Then, if ignored, an ambush (owner)

If the player doesn't act on the warning, the rival comes to them after a while (PROPOSAL: 30 minutes of play; see open question 3).

| Where (owner) | How it uses what exists |
|---|---|
| **On a road** | `RoadService` already rolls for a bandit ambush on each crossing. A rival's ambush takes that roll's place. |
| **In town** | The rival walks in with its escorts and finds you. Never in a safe zone. |
| **During a stealth contract** | The stealth spec's contract twist "a rival is on the same job", or the rival is guarding the compound. |

- **It opens with a line about the last fight**, built from the rival's history (PROPOSAL lines):
  - *"Last time you set me alight at the Foundry. I've had the coat treated since."*
  - *"You ran from me on the South Road. My tracker doesn't let people run."*
- **Fairness rules** (PROPOSAL; they follow the planned NPC hunter rules in the morality spec §15):
  - always after a warning;
  - never in a safe zone, in dialogue, in a cutscene or during a scripted quest moment;
  - never while the player is knocked, carried or swimming;
  - at most one rival ambush per 20 minutes of play, and none in the first 5 minutes after joining;
  - offline time doesn't count toward the ambush, so a player is never jumped the moment they log in.

---

## 5. How they change

### 5.1 They learn from the last fight (owner)

After each fight the rival gains one **adaptation** based on how it went:

| How the last fight went | It comes back with | How the player can answer |
|---|---|---|
| **Beaten with fire** (owner) | **Fire-proofing:** a treated coat. Burns don't stick and Flame hurts less (PROPOSAL: half damage, no Burn status). | Use another element, a weapon, or the terrain. |
| **Ambushed in the dark** (owner) | **A lantern and a lookout:** the lantern lights the area around it (it raises your Exposure through `LightService`), and one extra escort watches its back. | Put out the lantern (planned light control), take the lookout first, or come in loud. |
| **Escaped from** (owner) | **A tracker:** an escort who follows your trail. The rival searches longer and doesn't calm down as fast. | Break the trail through water or climbing, or deal with the tracker. |

- **More adaptations can follow the same rule** (PROPOSAL, later): frost-wrapped after Ice; a shield after guns; more feints after it was parried a lot.
- **At most 3 adaptations at once** (PROPOSAL). A fourth replaces the oldest.

### 5.2 They carry visible marks (owner)

- **Scars, burns and damaged armour** show where you hurt it and with what (owner). A burned rival looks burned.
- Marks come from how the last fight went (the element, the weapon, how close it came to dying).
- **Art:** marks need art from the owner (decals and armour variants). Until then they are placeholders, and only existing assets are used.

### 5.3 Each has a personality (owner)

A rival's personality drives what it does. This is a **new, story-level trait**. It is separate from `CombatDirector`'s squad personalities (Aggressor, Duelist, Defender and so on), which only decide how an enemy fights in a group. A duellist rival would also fight with the squad "Duelist" role.

| Personality | What it does (owner) | In play (PROPOSAL detail) |
|---|---|---|
| **Coward** | Flees, then returns with friends. | Breaks off at low health. Each return brings one more escort. |
| **Duellist** | Sends a one-on-one challenge. | The warning is a challenge: a time and a place. If you go alone, its escorts stay out. If you bring your party, it brands you a coward and fights dirty. |
| **Schemer** | Frames the player, raising Heat and spreading false rumours. | See below. |
| **Zealot** | Never stops. | Doesn't flee. Comes back sooner after each fight. |

**The schemer's false rumours** (owner: "frames the player"):
- The schemer starts a rumour of a deed the player **didn't** do (for example, an attack on a Foundry Hand). It travels through the rumour network like a real one, and where it lands it raises Heat and lowers standing.
- **This is new.** Today every rumour is about a deed the player really did.
- **Limits** (PROPOSAL):
  - framing alone can never push the player above **Wanted 2**;
  - at most one false rumour live per schemer;
  - it never adds Morality deeds to the player's own ledger, since the player didn't do it.
- **Clearing it:** killing or turning the schemer makes its false rumours collapse. Later, the planned reputation-in-investigations work can let the player prove the lie.
- The planned Journal list "Rumours about you" marks a false rumour once the player learns of it.

### 5.4 They rise in their faction by beating you (owner)

- **Each win over the player** (a kill, or making the player flee) moves the rival up one rank (§3.3).
- A rival that loses doesn't drop a rank, but it gains an adaptation and a mark.

### 5.5 They hear rumours (owner)

A rival knows what the rumour network says about you **in the places its faction hears**.

- **Before your real name reaches it,** it knows you only by description: your weapon, your alchemy, your dress, the way Player Identities records do.
- **Once a rumour carrying your real name lands where it is** (an identified deed, or a disguised player recognised, as the stealth spec §4.3 describes), the rival **knows your name**. After that, your **disguises and false identities no longer fool that rival** (owner). It sees through a mask, a stolen uniform or any alias.
- **What exists:** rumours that carry your name, and Identities records of what someone saw. **What is planned:** masks (morality spec §17.6) and disguises (stealth spec §4.3). Player Identities today record how players know *each other*. There is no false-name feature yet, so "false identities" here means the planned masks and disguises, and any alias added later.
- **On the rival's page** in the Journal, the player sees what it knows: "Knows your face" or "Knows your name" (PROPOSAL wording).

---

## 6. Whose rival it is (owner)

- **Rivals are saved with each player** and hunt that player.
- **In a party:** any member's rivals can come for the whole group, and **the whole party gets credit** when one is beaten.
  - **Credit** (PROPOSAL): every party member present gets the reward and the matching deed in their own ledger. The rival record changes only in its owner's save.
  - **One rival at a time** per party (PROPOSAL), even if several members have rivals due.
  - **If the owner isn't there** (they left the party or the server), their rival doesn't come.
- **Who chooses the ending** in a party is open question 6.

---

## 7. How it ends

| Ending | How | What happens |
|---|---|---|
| **Kill** (owner) | Grip (B) the knocked rival, the existing finisher. | Gone for good. It counts toward Morality, and **its faction remembers**. |
| **Spare** (owner) | Leave it knocked and walk away, or choose "Spare" when it yields (PROPOSAL prompt). | The result depends on its personality. |
| **Turn** (owner) | Spare it, then talk to it, if its personality allows and your standing is high enough. | It becomes your informant. |

### 7.1 Kill

- **Morality** (PROPOSAL deed `killed_rival`): Mercy −3, and Standing −10 with its faction (Local: heard where it happened, then carried by rumour as usual).
- **Its faction remembers** (owner) (PROPOSAL detail):
  - the next rival from that faction may start one rank higher, with a line about the one you killed;
  - the faction's leader notices you sooner.
- **Bandit crews have no standing** with the player, so for them only the grudge part applies.

### 7.2 Spare

- **Morality** (PROPOSAL deed `spared_rival`): Mercy +3.
- **By personality:**

  | Personality | When spared |
  |---|---|
  | **Duellist** | Backs off (owner). It leaves the active list and owes you a debt. |
  | **Schemer** | Comes back worse (owner): sooner, with a new false rumour. |
  | **Coward** | Runs. It can be turned (§7.3). If not turned, it comes back with friends. |
  | **Zealot** | Comes back, with a new adaptation (PROPOSAL). |

- **Carrying a rival to a guard** (the existing Carry and Deliver) counts as sparing it: the rival is jailed for a while, then comes back by its personality (PROPOSAL).

### 7.3 Turn: the informant (owner)

- **Who can be turned** (PROPOSAL): a spared **coward** or **duellist**. Schemers and zealots never turn.
- **Standing needed:** the player needs enough standing with the rival's faction (PROPOSAL: Neutral or better in that region). Someone who hates you won't risk it.
- **Turning is secret:** a Private deed (PROPOSAL `turned_rival`). Its faction doesn't know.
- **What an informant gives:**

  | Gives | How it ties in |
  |---|---|
  | **Rumours** | Tips you off about rumours spreading about you, and about other rivals' warnings, earlier. Uses the rumour network and the planned "Rumours about you" list. |
  | **Compound guard routes** | Shows the patrol routes of a compound in its faction's region before a stealth mission (stealth spec §2.2). |
  | **The truth in investigations** | Tells the truth when asked. This links to the planned "reputation shapes investigations" (Backlog item 5), where some NPCs lie or refuse to talk and evil NPCs spill secrets more easily. An informant is a witness who doesn't lie to you. |

- **The informant stays in the save** with the state "informant", and lives in the world as an NPC you can visit (PROPOSAL: at a fixed spot in its faction's region).
- Whether an informant can betray the player is open question 5.

---

## 8. What it ties into, and the build order

### 8.1 Ties

| System | How rivals use it |
|---|---|
| **Detection and stealth** | Rivals see and hear through `PerceptionService`. Lanterns and lookouts raise the stakes for a stealthy player. |
| **Stealth contracts** | The "a rival is on the same job" twist; rivals guarding compounds; informants giving guard routes. |
| **Assassinations** | The main way to strike first after a warning. A failed assassination can promote a rival. |
| **Heat** | The schemer's framing raises Heat, capped. A leader may send a rival when Wanted is high. |
| **Rumours** | The warning, the false rumours, and how a rival learns your name. |
| **Identities** | What a rival knows about you, by description or by name. |
| **Morality** | Kill, spare and turn are deeds. |
| **Factions and standing** | Rivals belong to factions; their faction remembers a kill; turning needs standing. |
| **Reputation in investigations** | An informant tells the truth. |

### 8.2 Each piece: exists or new, and the service it touches

| Piece | Exists today or new | Service it touches |
|---|---|---|
| Enemy spawns, looks, weapons | Exists | `EnemyService` |
| Promotion on a kill, an escape or a survived attack | New | `EnemyService`, new `RivalService` |
| A faction or crew on an enemy | New | `EnemyService`, `Rensei.Factions` |
| Rival data: name lists, titles, personalities, adaptations, ranks, leaders | New | new `Rensei.Rivals` data |
| Rival fighting in a squad | Exists (squad roles) | `CombatDirector` |
| Fleeing (cowards), escorts, trackers | New | `EnemyService`, `CombatDirector` |
| Sight, sound, light | Exists | `PerceptionService`, `LightService`, `NoiseService` |
| The lantern and lookout adaptation | New | `LightService`, `PerceptionService` |
| Fire-proofing and other resistances | New | combat damage and status effects |
| Visible marks | New (needs owner art) | `EnemyService` (dressing the rig) |
| The warning rumour | New kind, on the existing network | `RumourService`, `TownsfolkService` |
| False rumours (schemer) | New kind, on the existing network | `RumourService`, `HeatService` |
| Learning the player's name | New, from existing rumours | `RumourService`, `WitnessService`, `IdentityService` |
| Seeing through masks and disguises | New (masks and disguises are planned) | `IdentityService`, `PerceptionService` |
| Road ambush | Exists (bandit roll) | `RoadService` |
| Contract ambush | Planned (stealth missions) | stealth missions' contract code |
| Kill, spare and turn deeds | New deeds on the existing ledger | `MoralityService`, `Rensei.Deeds` |
| Faction memory | New | new `RivalService`, `MoralityService` |
| Informant: tips, guard routes | New | `RumourService`, stealth missions |
| Informant: the truth in investigations | New (waits for Backlog item 5) | `InvestigationService` |
| Party credit | New | `PartyService` |
| The rival record in the save | New | `ProfileData`, `ProfileMigrations`, `ProfileGuard` |
| The Rivals page | New | `JournalUI` |

### 8.3 Build order

1. **Assassinations** (Backlog item 1). PvE only.
2. **Stealth missions** (Backlog item 2, the sibling spec), including its slice M8, the Nemesis hook.
3. *(The owner's order puts "consequences for wrong guesses" here.)*
4. **The Nemesis system** (this file), in slices (PROPOSAL):

| Slice | Builds | Check (Studio Play) |
|---|---|---|
| **N1** Data and save | `Rensei.Rivals`, the save section, the migration | An old save loads with an empty rival list; the owner's save is snapshotted and restored. |
| **N2** Promotion | The three triggers, the odds, the cap, name and title generation | Dying to an eligible enemy can promote it once; a trial foe never is. |
| **N3** Warning and ambush | The warning rumour, the strike-first spot, the road and town ambush, the fairness rules | A warning is heard from a townsperson; ignoring it brings an ambush, never in a safe zone. |
| **N4** Adaptations and marks | The three owner adaptations, placeholder marks | A rival beaten with fire comes back fire-proofed and looks burned. |
| **N5** Personalities and ranks | Coward, duellist, schemer, zealot; rank ups; leaders' notice | A schemer's false rumour raises Heat but never past Wanted 2. |
| **N6** Endings | Kill, spare, turn; faction memory; party credit | Killing a rival records the deed once for each party member present. |
| **N7** Informants | Tips and guard routes; the investigation hook once Backlog item 5 exists | A turned coward shows a compound's patrol routes. |
| **N8** Journal | The Rivals page | It shows words, not numbers. |

---

## 9. The player's view: the Rivals page (PROPOSAL)

A new page in the Journal (J), built with the existing menu art.

- **Active rivals:** name, title, faction and rank, personality as a word, their marks, what they've adapted to, what they know about you, and the last warning heard.
- **Their history with you:** "Killed you on the South Road", "Burned at the Foundry" (PROPOSAL lines).
- **Ended rivals:** a short line each ("Killed at the rail yard", "Spared; now your informant").
- **Words, never numbers**, the same rule as Morality.

---

## 10. Data and saving (concept level)

### 10.1 The rival record

A rival record is saved **per player**, with that character's save:

| Field | What it holds |
|---|---|
| Id | a stable random id |
| Name, title | the generated name and current title |
| Faction | the faction or crew it belongs to |
| Personality | coward, duellist, schemer or zealot |
| Adaptations | up to 3 (PROPOSAL) |
| Marks | which scars, burns and armour damage it shows |
| Rank | its rank in its faction |
| History of encounters | the last few fights: when, where, how it went, what was used (PROPOSAL: last 5) |
| Knowledge | what it knows about you: a description, or your name |
| State | active, spared, informant or dead |

- **Leaders** are hand-made data, not records. The save only keeps a small note per leader (has this leader noticed the player? PROPOSAL).
- **Ended rivals** shrink to a short summary (name, title, faction, how it ended, when). At most 10 are kept (PROPOSAL); the oldest is dropped first.

### 10.2 Save-size budget

- Saves today are small: the owner's two slots were 5.8 KB and 4.2 KB in the 2026-10-18 audit, against the 4 MB limit.
- **Budget for rivals** (PROPOSAL): about 1 KB per active rival and 100 bytes per ended summary, so **under 8 KB in all** with 5 active and 10 ended.
- Every list is capped (active rivals, adaptations, history, ended summaries), so the section can never grow without bound. This follows the audit's rule for the inventory.

### 10.3 Migrations

- Saves use ProfileService (session-locked, auto-saved). Every load runs `ProfileMigrations.Migrate` before `Reconcile`.
- The rival section is **additive**: a schema bump (from today's 5 to the next number) with a migration step that adds an empty rival list. Old saves load unchanged.
- `ProfileMigrations` and the `ProfileData` template must stay **identical in all three places** (Ye, the Main Menu, the Tutorial), as `Data Storage.md` requires.
- `ProfileGuard` already protects the whole save from values a DataStore can't hold. It covers the new section with no extra work.
- A Gate permadeath reset clears the slot's rivals with everything else (PROPOSAL), since rivals belong to the character.

### 10.4 Studio test protection

- **Studio writes the real save store** (by design, `Data Storage.md`). Every Studio test of this system must **snapshot the owner's real save first, restore it afterwards, and check that the restored copy matches**, as every audit test does today.
- Rival tests should use a controllable clock (as `RumourService` tests already do), so warnings and ambushes can be tested without waiting 30 minutes.

---

## 11. Rules kept

- **PvE only:** rivals never hunt as players, never come from PvP, and never act for one player against another.
- **Never a dead end:** a rival can make life harder, never block the story. Framing is capped.
- **Fair warning:** a rival always warns before it ambushes.
- **Server only:** promotion, adaptations and endings are decided by the server, never the client.
- **Original content:** every name, title and line in this system is original. No character, plot or term is borrowed from any other work or game.

---

## 12. Open questions (with recommended answers)

1. **The exact rival cap.** *Recommended:* **5 active per player** (the owner's "about 5"), plus 10 ended summaries. Raise it later only if the Journal page and the save budget allow.
2. **The promotion odds.** *Recommended:* **35% on a kill, 25% on an escape, 15% on a survived attack**, with at most one new rival per 20 minutes of play. Tune them after playtests.
3. **How long a warning lasts before the ambush.** *Recommended:* **30 minutes of play** (offline time doesn't count), and never in the first 5 minutes after joining.
4. **Whether rivals can steal items or Identities.** *Recommended:* **no stealing items** (losing gear feels unfair in an online game). A rival can **learn and spread your name** (§5.5), which is already a real loss of cover. That's enough.
5. **Whether a turned informant can betray the player.** *Recommended:* **yes, but only for a reason the player can see coming**: if the player's standing with the informant's faction falls to Hostile, or the player kills another rival of that faction, the informant goes back with a warning sign first ("He's stopped meeting your eye"). Never at random.
6. **Who chooses the ending in a party.** *Recommended:* **the rival's owner chooses**, if they're there. If not, whoever finishes the rival does. Every member present still gets credit.

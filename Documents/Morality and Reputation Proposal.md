# Morality, Reputation & Consequence — Audit and Proposal

**Status:** owner approved the Â§8 defaults 2026-10-16 (Taboo canon left open). **Slices M1-M3 + M5 built and playtested 2026-10-16** (see `Changelog.md`). Not built yet: M4 (Journal Standing tab), M6 (Discovery), standing drift, PvP deeds, titles, Taboo. It expands `Claude Implementation Plan.md` §14 (Factions and Reputation), §15 (Choices) and §16 (Endings) into a concrete system. Every number is a PROPOSAL. Every faction, title or lore detail not already in canon is marked **(new)** and needs the owner's OK. The decisions the owner must make are in §8.

---

## 1. Audit — what exists today (Ye, verified in Studio and this repo)

| Area | State | Reuse |
|---|---|---|
| Story flags | `Story.Flags` in the save (schema 3). `StoryService.SetFlag` never overwrites a recorded choice. | The morality system **reads** flags; it never replaces them. |
| Consequential choices | One: Lise in "Chalk on the Foundry Wall" — Report / Secret / Teach, confirmed, recorded once as `Outcome_chalk_foundry`. It only changes the reward (Decisions: "later faction work reads it"). | First content to map (§5). |
| Quest outcomes | `Outcomes = {[value] = {Text, Rewards}}` per quest; paid once. | Outcomes gain a `Deeds` list. |
| Dialogue conditions | `StoryLogic.Meets` (Flag, FlagIs, Evidence, Quest, Affinity, Level, Item…); choices can be hidden or shown greyed with a reason. | Add `Standing`, `Trait`, `Renown`, `Trust`, `Deed` conditions. |
| Combat | A knocked target can be **Gripped (B)** — finished — or **Carried (V)**. PvP consequences of a Grip are an open question (Decisions). | Grip vs Carry is the core moral act in combat (§3.5). |
| Factions / reputation | **Not built.** Only the State Authority and its alchemy licence exist, as placeholder lore. `ReputationService` / `FactionService` are listed in the Implementation Plan but don't exist. | Built new, in small slices. |
| Forbidden alchemy | Truth / Gate stages exist in progression; "Stone Abilities" = Philosopher's Stone abilities (blocked for the Marcoh lineage). No taboo tracking. | The Taboo track (§3.4) hooks here. |
| Nemesis | Shelved. | Nothing here depends on it or revives it. |

**Conclusion:** there is no morality system to extend. There is a clean place to plug one in: flags, outcomes, StoryLogic conditions and the Grip/Carry choice.

---

## 2. Design goals

1. **No single good/evil meter.** (Plan §14.) What you did is judged differently by different people. Reporting Lise is lawful, cold and loyal to the Authority all at once.
2. **Every change has a traceable cause.** The player can always see *why* a faction feels the way it does ("Reported an unlicensed apprentice"). Nothing is silently overwritten.
3. **Reputation travels by witnesses.** A deed nobody saw changes your own record and the people involved, not the city. Secrets can surface later through evidence. This is Rensei's investigation theme turned back on the player.
4. **Grey choices, real trade-offs.** Each option opens something and closes something else. No option is the "good ending" button.
5. **Redemption takes sustained action.** (Plan §16.) A run of deeds over time, never one last dialogue line.
6. **Server-authoritative, idempotent, per-player.** Deeds are recorded once by id, only by the server. A choice never overwrites another player's campaign.
7. **Never a dead end.** Low standing changes *how* you get through the story (other routes, other allies, higher prices), never *whether* you can.
8. **No griefing incentives.** Self-defence, arena duels and consensual PvP are morally neutral. Repeatable acts have diminishing returns, so morality can't be farmed.

---

## 3. The model — five tracks and one ledger

```
            DEEDS LEDGER  (source of truth: what you did, who saw it, when)
                 │
     ┌───────────┼───────────────┬───────────────┬───────────────┐
  CONDUCT     STANDING         RENOWN           TRUST           TABOO
  (who you    (what each       (how widely      (what single    (the Truth's
  are: 3 axes) faction thinks) you are known)   NPCs think)     price; rare)
```

### 3.1 The Deeds Ledger (source of truth)

Every consequential act is a **deed** defined once in data (`Rensei.Deeds`) and recorded once per player:

```lua
-- Rensei.Deeds (PROPOSAL)
[DeedId] = {
  Text = "Reported an unlicensed apprentice to the Authority", -- the reason line players see
  Conduct  = {Mercy = -5, Candor = 0, Order = 10},            -- §3.2
  Standing = {Authority = 15, Foundry = -10},                  -- §3.3 (faction deltas)
  Renown   = 5,                                                -- §3.4
  Trust    = {Lise = -40},                                     -- §3.5
  Taboo    = nil,                                              -- §3.6
  Scope    = "Local",   -- "Private" | "Local" | "Public": who hears about it (§4)
  Repeat   = nil,       -- nil = once ever; {Cap = n, Decay = 0.5} for repeatable deeds
}
```

- **Save (schema 4, additive):** `Morality = {Deeds = {[DeedId] = {At, Count, Known}}, Standing = {}, Conduct = {}, Renown = 0, Trust = {}, Taboo = {}}`.
- The track values are **caches**: they can always be rebuilt from `Deeds` plus the data table, so a balance change never needs a hand-edited save, and every number has a cause.
- Only consequential acts are deeds (choices, finishers on named or story NPCs, crimes, rescues). Ordinary kills of hostile mobs are not deeds.

### 3.2 Conduct — who you are (3 axes, −100…100)

Shown only as **words**, never numbers ("Known for mercy", "Plays by the rules", "Says what's true"):

| Axis | − end | + end | Moves on |
|---|---|---|---|
| **Mercy** | Ruthless | Merciful | sparing vs finishing the beaten; rescues; cruelty |
| **Candor** | Deceitful | Honest | lying in dialogue, forged evidence, broken promises vs keeping your word |
| **Order** | Defiant | Lawful | obeying vs defying the State Authority's law (licences, curfews, reporting) |

**Order is not morality.** In an FMA-like world, the law can be the villain. Defiance is a path with its own allies (§3.3), not a punishment.

### 3.3 Standing — what each faction thinks (−100…100, five tiers)

Tiers (PROPOSAL): **Hostile** ≤ −60 · **Distrusted** ≤ −20 · **Neutral** · **Trusted** ≥ 20 · **Honoured** ≥ 60.

Starting factions (only the Authority is existing placeholder lore; the rest are **(new)** and need the owner's OK):

| Faction | Values | Dislikes |
|---|---|---|
| **State Authority** (placeholder) | licences, reporting, order, results | defiance, unlicensed alchemy, embarrassment |
| **Foundry Hands** **(new)** — the yard's workers and smelters | loyalty to your own, keeping quiet, honest pay | informers, the Authority's inspectors |
| **Unlicensed Circle** **(new)** — alchemists working without a licence | protecting students, sharing knowledge | informers, Taboo users (it brings the Authority down on everyone) |
| **Townsfolk** **(new)** — ordinary people of the district | mercy, protection, fair dealing | cruelty, bandit-like behaviour |

Rules:
- Factions are **linked**: some deeds move two factions in opposite directions (Report: Authority up, Foundry down). No deed raises everyone.
- Standing changes show a quiet toast with the reason ("The Foundry Hands won't forget this."). The Journal shows the last three causes per faction.
- **Drift back:** Distrusted and worse drift towards Neutral by 1 per real day of no new negative deeds (PROPOSAL), up to −20. Hostile needs real amends (a redemption quest). Honoured never decays.

### 3.4 Renown — how widely you are known (0…∞)

Renown isn't moral: it measures how much of the world has heard of you. It is the measure for the earned **Legendary Alchemist** title (Plan §10: the title is earned, never given).

- Grows from major quests, public deeds and feats (first clear of a boss, a famous rescue). It never goes down.
- **Renown × Conduct = your reputation's flavour.** At Renown tiers 1–4 (PROPOSAL: 50 / 200 / 600 / 1500), people start to recognise you, by your dominant Conduct:

| Dominant conduct at high Renown | Title flavour **(new, placeholder)** |
|---|---|
| Merciful + Lawful | "the State's Alchemist" |
| Merciful + Defiant | "the People's Alchemist" |
| Ruthless + Lawful | "the Authority's Hound" |
| Ruthless + Defiant | "the Red-Handed" |
| (Renown tier 4 + the main-story capstone) | **Legendary Alchemist** + flavour |

- NPCs only "know" you through Public deeds, or Local deeds done in their district (Plan §10: not every NPC recognises you).

### 3.5 Trust — what one person thinks (−100…100)

Per named NPC. Personal and remembered: Lise remembers who reported her, whatever the Authority thinks. Trust drives relationship lines, favours (an NPC covers for you, opens a back door, testifies), and whether an NPC can later be called as an ally or a witness.

### 3.6 Taboo — the Truth's price (rare, mostly irreversible)

Forbidden alchemy is the FMA heart of the setting, and it's tracked apart from everything else:

- Marks (not a meter): e.g. *Used a Philosopher's Stone ability*, *Attempted human transmutation*, *Made a chimera* **(all need canon)**.
- Each mark is **told before it happens** ("This can't be undone" confirmation, as with Lise). It is permanent, and may give power (the "forbidden or ambitious path", Plan §16).
- Taboo marks are **Private** until discovered: evidence can surface (an investigator finds the circle). Discovery is a story event, not a random roll.
- The Unlicensed Circle shuns Taboo users. Whether the Authority hunts them or recruits them is an owner decision (§8).
- Ties to Truth / Gate: what the Gate takes in return is canon the owner owns, so this proposal only provides the hook (`Taboo` condition + deed).

---

## 4. Witnesses — how deeds become reputation

A deed's **Scope** decides who learns of it:

| Scope | Who it affects at once | Example |
|---|---|---|
| **Private** | your Conduct, and Trust with the people involved | keeping Lise's secret; a Taboo act alone |
| **Local** | + Standing of factions present in that district | reporting Lise (the yard knows who talked) |
| **Public** | + Renown, everywhere | a public execution; a famous rescue |

**Discovery:** a Private deed can be raised to Local or Public later by a story event (an NPC who saw it, or evidence found). Discovery applies the deed's Standing deltas *then*, with a reason line ("The Authority learned you taught Lise."). It runs once (`Known` on the ledger entry). This is the investigation system aimed at the player: the same Evidence / Inspect / dialogue tools, with the player as the suspect.

---

## 5. Applied to what's already built

### 5.1 "Chalk on the Foundry Wall": the Lise choice

The flag `Outcome_chalk_foundry` stays exactly as it is. Each outcome adds a deed, so saves that already chose are converted once from the flag:

| Outcome | Conduct | Standing | Trust | Scope | Opens (PROPOSAL) | Closes |
|---|---|---|---|---|---|---|
| **Report** | Order +10, Mercy −5 | Authority +15, Foundry −10, Circle −15 | Lise −60, Brask +10 | Local | Authority contract board; licence-exam quest line **(new)** | Lise's later quests; the Circle's safehouse |
| **Secret** | Mercy +5, Candor −5 (you lie to Brask if asked) | Foundry +5 | Lise +30, Tobin +10 | Private | Foundry favours; Lise as an informant | Nothing yet. **Risk:** Brask can ask you later. Lying is Candor −10; telling him turns it into Report-lite |
| **Teach** | Mercy +5, Order −10 | Circle +15 (only once Lise talks: Local) | Lise +60 | Private → Local after 2 quests | Lise as an apprentice ally; the Circle's first contact **(new)** | **Risk:** a later Authority investigation can uncover it (Discovery: Authority −20) |

### 5.2 Smaller existing moments

| Moment | Deed (PROPOSAL) |
|---|---|
| Tobin: "Your secret's safe." | `promise_tobin`: Trust Tobin +15. If you later tell Brask he slept: `broke_promise_tobin`, Candor −10, Trust Tobin −50 |
| Voided Ledger Line (minigame evidence) | A future hand-in choice: give it to Brask (Foundry +5), give it to the Authority (Authority +10, Foundry −5), or keep it as leverage (Candor −5, unlocks blackmail lines) |
| Bounty: Ore Road Bandits | Each **Grip** on a knocked bandit counts toward `executed_bandits` (Mercy −1, capped −10 per day). **Carry** one to Brask: `arrested_bandit` (Mercy +1, Order +1, cap +10/day, bonus 10 money PROPOSAL) |

### 5.3 Grip and Carry (combat's moral act)

- **NPC enemies:** finishing a *hostile mob* is not a deed. Finishing a **named or story NPC**, or one who **surrendered** (a future knocked state with "yields"), is a deed. Carrying them to a guard, healer or quest-giver is the merciful option, and it is mechanically worth something (a bounty bonus, information, a later favour).
- **Players (open question in Decisions):** the proposal is **no deeds in arena, duels, party fights or self-defence**. A Grip on a player who did not attack you, outside an arena, is a Local deed: Mercy −3, Townsfolk −3 (PROPOSAL). It is capped per victim per day so it can't be used for griefing or farming. The owner decides PvP / permadeath first (§8).

---

## 6. Where morality shows up (what it changes)

| System | Effect |
|---|---|
| **Dialogue** | New conditions: `Standing = {Authority = "Trusted"}`, `Trait = {Mercy = "Merciful"}`, `Renown = 200`, `Trust = {Lise = 30}`, `Deed = "reported_lise"`, `Taboo = "…"`. Greetings and barks change by standing. Locked choices can show why ("[Foundry: Distrusted]"). |
| **Quests** | Faction quest lines unlock by standing. Some quests have a moral path and an expedient path. Outcomes gain `Deeds = {...}`. |
| **Access** | Authority checkpoints and licence offices vs the Circle's safehouses. Hostile standing means a different route, never a locked story. |
| **Economy** (later, when shops exist) | Prices scale with the vendor's faction tier (PROPOSAL ±15%). |
| **Titles** | The Renown × Conduct flavours in §3.4. "Legendary Alchemist" also needs the main-story capstone. |
| **Endings** | Ending eligibility reads the whole history (Plan §16): major deeds, standing, Trust with key NPCs, Taboo marks and preserved evidence. There is never one morality score. |

**UI:** the Journal (J) gains a **Standing** tab (MenuKit art): faction tiers as words with their last three causes, Conduct as three descriptors, Renown as a rank name, and known Trust for met NPCs. There are no raw numbers and no good/evil bar. Changes arrive as quiet toasts, not banners.

---

## 7. Implementation plan (small, testable slices — after owner approval)

| # | Slice | Scripts | Acceptance test (Studio Play) |
|---|---|---|---|
| M1 | Data + save schema 4 | `Rensei.Deeds`, `Rensei.Factions`, `ProfileData`, `DataManager` migrate | Old saves load unchanged with empty `Morality`; `Outcome_chalk_foundry` saves convert to their deed once. |
| M2 | `MoralityService` (the only writer) | new server module; `StoryService` / `QuestService` call `RecordDeed` | Recording a deed 20× applies once; repeatables respect caps; caches rebuild exactly from the ledger. |
| M3 | Conditions + dialogue/quest hooks | `StoryLogic`, `DialogueService` (`Deed` action), `QuestService` (`Outcomes.Deeds`) | A choice gated on Standing is hidden or greyed with its reason; a forged index can't bypass it (as today). |
| M4 | Journal Standing tab + toasts | `JournalUI`, `UIService` | Reasons listed per faction; no numbers shown. |
| M5 | Lise / Tobin / bandit content | `Rensei.Dialogues`, `Rensei.Quests` | All three Lise outcomes give their deeds once; Grip vs Carry on bandits records correctly with caps. |
| M6 | Discovery | `MoralityService.Discover`, one test investigation | A Private "Teach" deed becomes Local once, with the reason line; never twice. |
| M7 | Docs + QA | this repo | Changelog / Status / Decisions updated; multi-client test that one player's deeds never touch another's. |

Every slice backs up touched scripts to `ServerStorage.RenseiBackups["Pre-<Name>_<date>"]` first, and snapshots / restores the tester's save.

---

## 8. Decisions needed from the owner

1. **Model:** approve five tracks (Conduct, Standing, Renown, Trust, Taboo) over a single karma meter? (Recommended.)
2. **Factions:** may we add the placeholder factions *Foundry Hands*, *Unlicensed Circle* and *Townsfolk* next to the State Authority, or do you have canon factions to use instead?
3. **Conduct axes:** Mercy / Candor / Order: keep, rename or replace?
4. **Visibility:** words only (recommended) or show numbers?
5. **Taboo:** which forbidden acts exist in your canon (human transmutation, Stone use, chimeras), and how does the Authority treat a Taboo user: hunt or recruit?
6. **PvP:** confirm "no deeds in arena, duels or self-defence; capped Local deed for an unprovoked Grip", or decide the PvP / permadeath rules first.
7. **Titles:** use the Renown × Conduct flavour titles, or should "Legendary Alchemist" be the only title?
8. **First slice:** build M1–M3 + M5 (Lise / Tobin / bandits) as the vertical slice? (Recommended.)

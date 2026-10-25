# Reputation in investigations: audit and design

**Status:** design **PROPOSAL**, written overnight on 2026-10-25 with the owner's go-ahead (Backlog, 2026-10-25). **Nothing here is built.** The owner has not seen it yet. Every number, name and line of speech is a PROPOSAL unless it quotes the owner.

**The owner's item** (`Backlog.md:43`, "After the swimming revamp", item 5):
> "Expand reputation system to affect NPC's in investigations. (some will lie to you or just refuse to tell you the truth, or some evil NPC's will spill secrets easier, etc.)"

**When it's built:** after assassinations, stealth missions, consequences for wrong guesses and the Nemesis system, in the owner's order (`Backlog.md:10`). The plan is `Documents/plans/2026-10-25-reputation-investigations.md`.

**Builds on:**
- `Morality and Reputation Proposal.md` (deeds, conduct, standing, trust);
- `specs/2026-10-19-morality-reputation-consequences-design.md` (rumours, Heat, witnesses, masks §17.6, bribes and threats §5);
- `specs/2026-10-25-nemesis-design.md` §7.3 (turned rivals become informants who tell the truth);
- `specs/2026-10-25-main-story-concept.md:180` ("every main-quest witness has at least two ways to the truth");
- `specs/2026-10-25-stealth-missions-design.md` §4.3 (disguises);
- `specs/2026-10-25-wrong-guess-consequences-design.md` (**may not exist yet**; this file only references it).

---

## 1. The idea in one paragraph

Each townsperson who answers a clue now has an attitude toward **you**. It comes from what their faction thinks of you here, whether your conduct matches their own nature, how wanted you are, whether they can tell who you are, and what they saw you do. That attitude picks one of five answers: the **truth**, an **evasive** line, a **refusal**, a **lie** that hands you false evidence, or the truth with **something extra**. You can push with your standing, your money or your fists, call on an informant, or hide who you are. A lie can mislead your Case Board, but it can always be caught: other evidence contradicts it, or the Case Board rejects it, and then the liar gives up the truth. At neutral reputation every existing clue quest plays exactly as it does today.

---

## 2. Audit: how it works today

Line numbers are the repo at `0415f18`. `TownsfolkService.lua` has uncommitted edits by another agent (Foundry Task 4b fix round); they start at line 326, so every TownsfolkService line cited below 326 and in 396–458 is the same in both.

### 2.1 What do NPCs know about the player?

| # | Finding | Evidence |
|---|---|---|
| A1 | **A townsperson knows one thing about you: your standing with their faction in their region.** It only picks the greeting (Hostile to Honoured). | `TownsfolkService.lua:431-436`; `TownsfolkLogic.lua:34-46` |
| A2 | **Standing is per place and comes only from deeds heard there.** A deed counts in a region for the factions there that heard it. | `Reputation.lua:1-9, 51-63`; `MoralityService.lua:118-143` |
| A3 | **Rumours are about anyone in the server**, not about the listener's standing. A townsperson passes on deeds known in its region, worded by what the *listening player* knows of the subject ("someone" or a name). | `RumourService.lua:75-116`; `TownsfolkService.lua:396-402, 437-440`; `TownsfolkLogic.lua:172-196` |
| A4 | **No NPC remembers what it saw you do.** `WitnessService.Capture` lists the NPCs that perceived a deed, but only to size the rumour and raise Heat. Nothing keeps it per NPC. The only per-NPC memory is the talk rotation and the last player to hit them (for the murder deed), both in server memory. | `WitnessService.lua:47-71`; `MoralityService.lua:124-136, 156-157`; `TownsfolkService.lua:441-443, 595` |
| A5 | **No NPC has an identity record of you.** Player Identities are records players keep of *other players*. Masks and disguises are designed, not built. | `Identities.lua:1-8`; `IdentityService.lua:1-14`; morality spec §17.6; stealth spec §4.3 |
| A6 | **No NPC has a morality of its own.** A roster entry has a Faction and nothing else about its nature. Factions are names only. | `Townsfolk.lua:2`; `Factions.lua:9-22` |
| A7 | **Trust is per named person, but only from fixed deed data**, and it is rebuilt from the ledger on every join. It can't hold "Sella Marsh trusts you less since you threatened her". | `Deeds.lua:8`; `MoralityService.lua:47-60` |
| A8 | **Townsfolk ignore Heat and Wanted.** Only dialogue conditions read them (Brask's fine). | `StoryLogic.lua:31-33, 203-210`; `Dialogues.lua:161-165` |
| A9 | **Two different "standings".** Dialogue conditions read the global cache (each faction averaged over its regions); townsfolk read the place's own. | `StoryLogic.lua:191-196` vs `TownsfolkService.lua:434` |
| A10 | **The Authority isn't present in the Foundry region**, so its place standing there is always 0, and a crime in the Foundry raises State Heat only when an Authority agent sees it or the rumour reaches an Authority place. | `Regions.lua:42-43`; `Heat.lua:76-88`; `HeatService.lua:103-131` |

### 2.2 What changes a townsperson's answer today?

| # | Finding | Evidence |
|---|---|---|
| B1 | **Only whether you are on the clue's quest stage.** Then the clue line overrides the rotation. It is the same true line for everyone. | `TownsfolkService.lua:423-430`; `TownsfolkLogic.lua:143-146` |
| B2 | **Otherwise the rotation:** greeting by tier, a rumour you haven't heard from them, the job line. | `TownsfolkLogic.lua:134-165` |
| B3 | **The gates are physical:** calm state, the server's range check (TalkRange 10 + margin 4), a 0.5 s cooldown. | `TownsfolkService.lua:107-109, 410-417` |
| B4 | **A clue line always gives its evidence, then its signal** (Foundry Task 2), so the next stage's catch-up sees the evidence. | `TownsfolkService.lua:448-456` |
| B5 | **The client only gets text.** `Say` fires the bubble text and its duration; the line's Kind stays on the server. Clue and rumour lines are private to the talker. | `TownsfolkService.lua:63-67, 445-447` |
| B6 | **No reply choices, by the owner's choice** (2026-10-23): townsfolk speak in bubbles. | `Changelog.md:598` |

### 2.3 How clue lines and dialogue gates work

| # | Finding | Evidence |
|---|---|---|
| C1 | **Clue line format:** `Clue = {Quest, Stage, Signal, Evidence?, Text}` on a roster entry. A stale-revision quest state is on no stage until upgraded. | `Townsfolk.lua:2, 51-52, 57-58, 119-120, 125-126, 163-164`; `TownsfolkService.lua:427-429` |
| C2 | **The five clue lines today:** Ned Harrow (`lm_ridge`) and Bess Kettering (`lm_mine`) give no evidence, only a signal. Edmund Rusk, Sella Marsh and Aldous Merriweather (`foundry_ledger`) each give one piece of evidence and a signal. | as C1 |
| C3 | **`lm_ridge` and `lm_mine` are one stage**: examine the clue, ask the townsperson. No deduction. | `Quests.lua:60-87` |
| C4 | **`foundry_ledger_who` needs all five pieces of evidence before it can be answered**, including the three from clue lines. A witness who withholds would block the Case Board. | `Investigation.lua:309-320` (Requires at :312) |
| C5 | **Inspects:** `Requires` gates the evidence (else `Locked` text); `StartsQuest` starts a quest after a passing inspect. | `InvestigationService.lua:36-65`; `Investigation.lua:1-16` |
| C6 | **Deduce:** `Requires` first, then every slot must be the exact evidence id, held. **A wrong answer costs nothing.** | `InvestigationService.lua:10-11, 67-82` |
| C7 | **The Case Board** shows a case once you hold any slot's answer, and offers every held evidence of that quest as a card. | `JournalUI.lua:419-442` |
| C8 | **Dialogue trees:** `Starts` picks the opening node; `Alt` swaps a node's text (first match wins); a choice's `Requires` hides it, or greys it with a reason (`Show = "Locked"`); `ShowIf` hides it. The server keeps the shown list, so a forged index can't reach a hidden or locked choice. Presenting evidence is a choice gated on `Requires = {Evidence}`, labelled "[Evidence: X]". | `Dialogues.lua:1-22, 158-165, 311-315`; `DialogueService.lua:1-7, 49-76, 245-248`; `StoryLogic.lua:214-218` |
| C9 | **`DialogueService.Ask`** opens the normal dialogue box with server-handled answers. Unlike `Say`, it has **no combat check**, and it **can't grey a choice** (every inline choice is unlocked). | `DialogueService.lua:41-47, 106-129, 234-241` |
| C10 | **`StoryLogic.Meets`** already reads deeds, standing, trait, trust, renown, Heat and Wanted. | `StoryLogic.lua:5-33, 154-212` |
| C11 | **The Journal's evidence sources** list inspects, minigames, puzzles and dialogue actions, but not townsfolk clue lines. | `JournalUI.lua:250-273` |
| C12 | **Every answer is already visible to the client:** deduction slot answers live in `ReplicatedStorage`. Marking evidence as false in shared data leaks nothing new. | `Investigation.lua:314-316` |
| C13 | **A killed townsperson is replaced** at the next 06:00 by a newcomer with the same Id, job and roster entry (so the same `Clue`), and a new name. | `TownsfolkService.lua:27-34` |

### 2.4 What the audit means for the design

- There is **no NPC disposition** to extend. There is a clean place to plug one in: the clue branch of `TownsfolkService.Talk` (B1).
- Every input the owner named already exists somewhere **except** NPC morality (A6), NPC memory of what it saw (A4), and NPC knowledge of who you are (A5). The design adds the first two small and in server memory. The third is a hook that masks and disguises fill when they're built.
- The Case Board's `Requires` (C4) is the soft-lock risk. The design keeps it working (§6.3).
- Levers need a choice, and townsfolk have none (B6). The design uses the existing dialogue box for that one moment, and asks the owner (§7.1, decision D1).

---

## 3. The NPC's disposition toward you

A **score** from −100 to +100, computed on the server each time you ask. It is never shown as a number. These are its inputs; each term is PROPOSAL.

### 3.1 The NPC's own nature: `Temper`

A roster entry gains `Temper = {Mercy = -1|0|1, Candor = -1|0|1, Order = -1|0|1}`, the same three axes as the player's conduct (`Factions.lua:41-45`). Missing axes are 0. "Evil" in the owner's words means **Ruthless and Deceitful** (Mercy −1, Candor −1).

### 3.2 The terms

| Term | How it's computed | Range |
|---|---|---|
| **Standing** | For each faction in the clue's `Disposition.Weights` (default: the NPC's own faction, weight 1): weight × tier points (Hostile −40, Distrusted −20, Neutral 0, Trusted +20, Honoured +40). Factions present in the NPC's region use the **place** standing, as greetings do. A faction **not present** there uses the global standing at **half** weight, so "the Authority's Hound" still reaches Foundry hands (A10). | −80..+80 in practice |
| **Kinship** (the owner's "evil spill easier") | For each axis where both you and the NPC lean (your conduct word shows, `Factions.Word`; the NPC's Temper is ±1): the same side +10, opposite sides −10. **Doubled** if your Renown rank is Known or higher: they've heard what kind of person you are. | −60..+60 |
| **Heat** | Wanted level W in the NPC region's law (State or Militia). An NPC with Order 0 or +1: −10 × W. An Order −1 NPC: +5 × W (respect for an outlaw). A Circle NPC also takes −10 × your Circle Wanted. | −50..+25 |
| **Heard** | Crime deeds of yours known in the NPC's region (`Morality.Places[Region].Known`, deeds with `Crime`): −5 each for Order 0/+1 NPCs, +3 each for Order −1 NPCs. | capped ±15 |
| **Witnessed** | Deeds this NPC itself perceived this session (new, §3.3): a crime −15; any other deed: its standing change toward the NPC's faction. You hit this NPC: −25. | capped ±30 |
| **Identity** | What they can tell of who you are (§3.4). | changes the terms above |
| **Informant** | You have a turned informant (Nemesis §7.3) of the NPC's faction or region: +20. | 0 or +20 |

The total is clamped to −100..+100.

### 3.3 What an NPC saw (new, server memory only)

- `TestimonyService` listens to `MoralityService.Recorded`. For each NPC in `Info.Witnesses.Npcs` whose rig carries `TownsfolkId` (`TownsfolkService.lua:754`), it notes the deed against that townsperson and that player.
- A landed hit on a townsperson (`TownsfolkService.OnHit`, :587-597) notes "you hit me".
- **Memory only** (PROPOSAL), like the talk rotation: a server restart forgets it, and the deed's lasting effect is already in standing. No save change.
- The assassination plan's "townsfolk remember" (a takedown seen by a townsperson is a witnessed deed) feeds this for free.

### 3.4 What they know of who you are

| State | When | Effect |
|---|---|---|
| **Known** | Default: any non-birth deed of yours is known in their region, or your Renown is Noticed or higher | All terms apply. |
| **Stranger** | Nothing of yours is known there | All terms apply. (Standing is near 0 anyway: only birth deeds count.) |
| **Masked** | Character attribute `Masked = true` (the planned masks, morality spec §17.6) | Standing, Kinship, Heat, Heard and Witnessed are dropped; −10 for a hidden face. |
| **Guise** | Character attribute `Guise = "<FactionId>"` (the planned disguises, stealth spec §4.3) | Standing is replaced: +20 if the NPC is of that faction; weight × 20 for a faction the clue weighs (Marsh's Authority weight −0.5 gives −10); 0 otherwise. Heat, Heard and Witnessed are dropped. Kinship stays (it's how you behave, not your face). |

`Masked` and `Guise` are this design's **contract** for the stealth and mask work: they set the attribute on the character; this design reads it. Until then, only tests set them.

### 3.5 Patience: "come back later"

- Each refusal or evasion is remembered (server memory) per player and NPC.
- **Asking again at least 10 minutes later** (PROPOSAL; real time) moves the answer **one band friendlier**, up to two bands: Refuse → Evasive → Truth. Softening **skips the Lie band**.
- So every witness who isn't lying reaches the truth with no money, no standing and no violence. That is the floor that keeps every quest finishable.

---

## 4. The five answers

### 4.1 The bands (PROPOSAL)

| Score | Answer | Notes |
|---|---|---|
| ≥ 40 (≥ 20 for a Candor −1 NPC) | **Spill**: the truth and a bonus | Only if the clue has a `Spill`. Else Truth. |
| −15..39 | **Truth** | Neutral (0) is always here. |
| −35..−16 | **Evasive** | Only if the clue has `Evasive`. Else Truth. |
| −60..−36 | **Lie** | Only if the clue has `Lie` **and** the NPC's Candor is 0 or −1. Else Refuse. |
| < −60 | **Refuse** | Only if the clue has `Refuse`. Else Evasive, else Truth. |

**A missing variant always falls to a friendlier one**, never a harsher one. **An honest NPC (Candor +1) never lies.**

**Deterministic, not random** (PROPOSAL, decision D3): the same inputs give the same answer, so asking twice is not a re-roll, and tests can check each band.

### 4.2 What each answer does

| Answer | Line | Evidence | Signal (quest progress) |
|---|---|---|---|
| **Truth** | `Clue.Text` (today's line) | `Clue.Evidence` | yes |
| **Spill** | `Clue.Spill.Text` | `Clue.Evidence` **and** `Clue.Spill.Evidence` (bonus, never required) | yes |
| **Evasive** | `Clue.Evasive.Text`: a vague line that points elsewhere | none | **no** |
| **Refuse** | `Clue.Refuse.Text` | none | **no** |
| **Lie** | `Clue.Lie.Text` | `Clue.Lie.Evidence`: **false evidence** | **yes** (the witness "answered") |
| **Caught** (after a lie is exposed) | `Clue.Lie.Caught` | `Clue.Evidence` (the truth) | (already given) |

- Every answer is a bubble, private to the talker, as clue lines are today (B5). **The client can't tell a lie from the truth:** only text reaches it.
- `Talk` keeps returning Kind `"Clue"` for all of them, so existing callers and tests keep working, plus a third value naming the answer for tests.
- **Evasive and Refuse** add a quiet toast the first time: "*Talk to them again to press them.*" (PROPOSAL; the existing Toast). That is how the player finds the levers.
- **A line that gives nothing new** (an evasion, a refusal, or a clue line with no evidence and no signal) is said once per visit, then the normal rotation resumes, so a stubborn witness doesn't block their greetings and rumours.

### 4.3 Lies, and how they're caught

A lie hands over a **false evidence** def. It looks like any other evidence: same banner, same Journal entry, a card on the Case Board.

```lua
-- Rensei.Evidence (PROPOSAL)
foundry_marsh_full_pay = {Quest = "foundry_ledger", Title = "A Full Packet",
	Text = "Sella Marsh, late furnace hand: her pay packet for the 14th held a full eight hours.",
	False = {Truth = "foundry_short_pay",                                   -- what she's hiding
		Contradicts = {"foundry_scraped_docket", "foundry_banked_early"}}}, -- what gives her away
```

A lie is **exposed** when either:
1. **You hold evidence it contradicts.** At the moment that evidence is given (or at once, if you already hold it), a toast says "*Sella Marsh's account doesn't square with The Scraped Docket.*" and the Journal marks the lie.
2. **The Case Board rejects it.** A deduction answered with a lie in any slot fails as usual, and marks that lie as doubted (the flag `Doubt_<evidence id>` in `Story.Flags`, an existing save table). This catches a lie even if you never find the contradiction.

Once exposed:
- **Talking to the liar again** gives the `Caught` line and the true evidence, **at any stage while the quest is Active**, whatever their disposition is now.
- The lie stays in your Journal, marked "*Doesn't add up*", and leaves the Case Board's cards.

**The never-soft-lock rules** (checked by `Testimony.Validate` and its tests):
1. Every opted-in clue gives **Truth at a neutral score**.
2. A lie's `False.Truth` is the clue's own `Evidence`.
3. Every id in `Contradicts` can be got **without any lie**: from an inspect, or from a clue that has no `Lie`. At least one is required.
4. Exposure through a wrong Case Board answer always works, so even rule 3 is a second net, not the only one.
5. A Caught line ignores disposition, levers, clamming up and cooldowns.
6. Spill evidence is never in any deduction's `Requires` or slot answers.
7. A clue with no `Disposition` behaves exactly as today.

### 4.4 The Case Board with a lie in your pocket

`foundry_ledger_who` needs all five pieces of evidence (C4). If Marsh lied, you hold her lie, not `foundry_short_pay`.
- **An unexposed lie stands in for its truth in `Requires`** (only for the `Evidence` key), so the case opens and you can be misled. Slots still need the real evidence.
- **An exposed lie doesn't stand in**, so the board says "*You don't have enough to go on yet.*" until you go back to the liar. That nudges the player back.
- This is computed on the server (`InvestigationService.Deduce`) from a view of your evidence. Nothing is written to the save except the `Doubt_` flag.

---

## 5. The player's levers

### 5.1 How they're offered

After an **Evasive** or **Refuse** line, **talking to the same person again within 60 s** (PROPOSAL) opens the **existing dialogue box** (`DialogueService.Ask`) with the levers as its choices. The line itself was still a bubble. (Decision D1: this bends the owner's "no reply choices" rule for this one moment.)

| Choice (PROPOSAL wording) | Lever | Shown when | Greyed with |
|---|---|---|---|
| "*You know me. I'm on your side.*" | **Persuade** | always | the reason it can't work, e.g. "[Foundry Hands: Trusted]" |
| "*Here. For your trouble.*" [price] | **Bribe** | the NPC isn't Candor +1 | "[Won't take money]" for Candor +1; "[Needs 50]" when you can't pay |
| "*Tell me, or you'll be sorry.*" | **Intimidate** | the NPC isn't State Authority | (hidden for Authority NPCs: threatening an officer is a fight) |
| "*Never mind.*" | — | always | — |

Greying needs a small extension of `Ask` (C9): an optional `Locked` list, which the existing box already draws. The server refuses a locked index.

### 5.2 What each lever does

| Lever | Works when | Gives | Costs |
|---|---|---|---|
| **Persuade** (standing, a favour) | Your **global** standing with the NPC's faction is Trusted or better, or your Candor word is Honest, or the NPC's `Trust` (if any) is 15 or more | Truth (Spill if the score would be ≥ the spill line) | Nothing. |
| **Bribe** (Money) | You can pay | Truth; **Spill** from a Candor −1 NPC ("evil spills easier") | 50 Money (PROPOSAL); ×2 after a Refuse; ×0.5 for a Candor −1 NPC. Deed `bribed_witness`: Candor −2, Private, at most 10 a day. |
| **Intimidate** | Always (not on Authority) | Truth | Deed `intimidated_<Faction>`: Mercy −3, Order −2, Standing −3 with the NPC's faction, Local, **Crime 10** (Heat cap 30), at most 5 a day, recorded with the threatened witness as one witness (Strength 1), so Heat and rumours follow the existing path. The NPC remembers it (−25 in "Witnessed"). |
| **Informant** (Nemesis) | You have one of the NPC's faction or region | +20 score, and **no NPC of that faction lies to you** while they vouch. Talking to the informant during an investigation in their region **exposes** any unexposed lie you hold from there ("*Marsh is covering for someone.*"). | Nothing here; Nemesis decides what an informant costs. |
| **Disguise / identity** | You wear a mask or a guise (§3.4) | A different score | Whatever the mask or disguise costs (stealth spec) |

- **Intimidation in the Foundry** raises State Heat only when the rumour reaches the Authority or an agent saw it (A10). In Lindenmoor, the Militia hears it at once. That's the existing law, unchanged.
- **One lever result per NPC per player per 10 minutes** (PROPOSAL), so deeds can't be farmed.
- **A lie can't be bribed or threatened out of someone**: once they've lied, only exposure (§4.3) gets the truth. Persuasion, bribes and threats work on the evasive and the refusing.
- Per-faction intimidation deeds (`intimidated_Foundry`, `intimidated_Townsfolk`, …) are needed because a deed's standing change is fixed data (A7). They are generated in `Deeds.lua` from `Factions.Order` (PROPOSAL).

---

## 6. How the existing clue quests opt in

### 6.1 The rule

A clue opts in by having a `Disposition` key. Its roster entry gains a `Temper`. **Nothing else about the quest changes**: same stages, objectives, signals and rewards.

### 6.2 Data shape

```lua
-- Rensei.Townsfolk, a roster entry (PROPOSAL)
{Id = "fy_furnace_l1", Name = "Sella Marsh", Job = "Furnace hand", Faction = "Foundry", ...,
	Temper = {Mercy = 1, Order = -1},                   -- her own nature (Rensei.Factions axes, -1..1)
	Clue = {Quest = "foundry_ledger", Stage = 1, Signal = "foundry_ledger_marsh", Evidence = "foundry_short_pay",
		Text = "Four hours. ...",                       -- the Truth line: today's Text, unchanged
		Disposition = {Weights = {Foundry = 1, Authority = -0.5}}, -- opts in; whose opinion counts, and how
		Evasive = {Text = "..."},
		Refuse = {Text = "..."},
		Lie = {Text = "...", Evidence = "foundry_marsh_full_pay", Caught = "..."},
		Spill = {Text = "...", Evidence = "foundry_ashe_rounds"},
	}},
```

- **`Text` stays the Truth line** (PROPOSAL, decision D2), so every existing reader and test keeps working. There is no separate `Truth` key.
- `Disposition` may also hold `Bands` (overrides §4.1's numbers for this clue) and `Never = {"Lie"}`.
- `Stage = nil` means "any stage while the quest is Active" (already true today).

### 6.3 The three quests (PROPOSAL content)

**`lm_ridge`: Ned Harrow** (groundskeeper, Townsfolk; `Temper = {Order = 1}`). Chapter 1's first beat (`main-story-concept.md:84`), so it stays gentle.
- Neutral and Trusted: the truth (today's line). Honoured, or Trusted and Lawful with a known name (his Order +1 kinship, doubled): **Spill** `lm_ridge_visitors` ("*Men in State coats came up last spring. Didn't measure a thing. Looked at the arrow and wrote in a book.*").
- Distrusted: **Evasive** ("*Ask the surveyors. I just keep the grass down.*"). Hostile: **Refuse** ("*I've seen what you do to people. Off my field.*").
- **No Lie**: Chapter 1 teaches investigation, and the main story turns wrong-guess costs off in Chapter 1 (`main-story-concept.md:177`).

**`lm_mine`: Bess Kettering** (mine hand, Townsfolk; `Temper = {Mercy = 1}`). Same shape as Ned. **Spill** `lm_shaft_warm` ("*The water came up warm. The assayer wouldn't touch that ore bare-handed.*"). No Lie.

**`foundry_ledger`:**

| Teller | Temper | Weights | Answers |
|---|---|---|---|
| **Edmund Rusk** (day furnace hand) | Order −1, Candor +1 | Foundry 1 | Truth; Evasive; Refuse. **Never lies** (he swears to it). No Spill. |
| **Sella Marsh** (late furnace hand) | Mercy +1, Order −1 | Foundry 1, Authority −0.5 | Truth; Evasive; **Lie** `foundry_marsh_full_pay` (she takes you for an Authority snoop and protects her place on the late shift); Caught; **Spill** `foundry_ashe_rounds` ("*Two nights after, Ashe stood the whole late crew drinks. Ashe never stands anyone anything.*") |
| **Aldous Merriweather** (shift clerk) | Order +1, Candor +1 | Foundry 1, Authority 0.5 | Truth; Evasive; Refuse ("*I'll not open my books to the likes of you.*"); won't take money; **Spill** `foundry_ashe_hand` ("*Ashe always brings his dockets in himself. Every other charge hand sends a runner.*") |
| **Ivo Marchbank** (late yard hand) **(new teller)** | Mercy −1, Candor −1, Order −1 | Foundry 0.5 | The owner's "evil NPC". Not needed for the quest: his clue has no Signal and no required evidence. Truth: a shrug ("*Ashe? Charge hand. Keeps to himself.*"). **Spill** at ≥ 20 (a Ruthless, Deceitful or Defiant player, or a cheap bribe): `foundry_ashe_coin` ("*Paid for a crate off the evening freight in new State coin, and didn't sign for it.*"). |

- **Marsh's lie is contradicted by** the docket (`foundry_scraped_docket`, an inspect, stage 2) and by Rusk's account (`foundry_banked_early`). Ask Rusk first and you catch her at once; ask her first and the docket catches her later.
- **Marsh's lie, in numbers:** a player Distrusted by the Foundry hands (−20) who reads as the Authority's Hound (Ruthless and Lawful against her Merciful, Defiant nature: −20; Honoured by the Authority elsewhere: −10) scores −50: a lie. The same player merely Distrusted gets an evasion.
- **Spill evidence** is a bonus card, never a slot answer. The main story can use it later as a shortcut (as regional side quests do, `main-story-concept.md:174`).
- Every line is PROPOSAL and original.

---

## 7. Ties

### 7.1 Wrong-guess consequences (`specs/2026-10-25-wrong-guess-consequences-design.md`, not written yet)

That design decides what a wrong Case Board answer costs (the main story suggests "*makes a witness clam up for a while*", `main-story-concept.md:177`). This design asks it to keep four rules:
1. **A wrong answer that used a lie still exposes the lie** (§4.3), whatever else it costs.
2. **"Clam up" is a Refuse with a timer:** this design reads an optional `ClamUntil` per player and NPC from that system (a function it exposes, or none). While it runs, the NPC refuses.
3. **A Caught line ignores clamming up.** An exposed liar always gives the truth.
4. **Off in Chapter 1**, as the main story says, and `lm_ridge` / `lm_mine` have no lies anyway.

Whichever plan lands second edits `InvestigationService.Deduce`'s wrong branch to call both.

### 7.2 Nemesis (`specs/2026-10-25-nemesis-design.md`)

- **Informants** (§7.3 there): this design reads `RivalService.Informants(Player) -> {{Faction, Region}}` if `RivalService` exists, else none (§5.2).
- **Schemers' false rumours** (§5.3 there) lower standing, so they lower dispositions too. Proving a framing false is not in this design; it is a later piece.
- **The rival's warning rumour** joins the Talk rotation (Nemesis N3). It shares `TownsfolkService.Talk` with this design: the clue branch runs first, the rotation after.

### 7.3 Stealth missions and masks

`Masked` and `Guise` (§3.4) are the contract. Stealth M4 (disguises) and morality S6 (masks) set them. A recognised disguise (stealth spec §4.3) clears `Guise`.

### 7.4 Dialogue-tree NPCs

Brask, Tobin and the trainers already change their lines with `Alt`, `Requires` and `ShowIf` (C8), and players can already present evidence there. This design **doesn't change them**. A later step can add a `Candid` condition that reads the same score, so a tree NPC can lie too (not in the plan).

---

## 8. Server validation

- **Everything is decided on the server**: the score, the answer, the evidence, the levers. The client sends only the Talk prompt and a choice index.
- **Talk** keeps its range, calm and cooldown checks (B3).
- **A lever answer** (`Ask`'s `OnAnswer`) re-checks, at the moment of answering: the player is still within talk range and not fighting (`Ask` has no combat check of its own, C9, so `TestimonyService` checks the character's `InCombat` and `CombatMode` attributes first, as `DialogueService` does at :87-90); the NPC is calm; the offer is under 60 s old; the lever's condition (persuade's standing, the price, the NPC's Temper); and the 10-minute lever cooldown.
- **Money** is taken with `ProgressionService.SpendMoney`, which fails if the player can't pay. Nothing is given on a failed payment.
- **A locked index** is refused by `DialogueService.Choose` (the new `Locked` list), as tree choices already are (:248).
- **False evidence** is given only by the server's Talk path. No remote gives evidence.
- **The Case Board's stand-in view** and the `Doubt_` flag are computed and written on the server only.
- **`Testimony.Validate`** runs at `TestimonyService.Start` over every roster: a clue that breaks a §4.3 rule is warned about and **treated as not opted in** (today's behaviour), so a data mistake can never cause a soft-lock.
- **No save schema change.** Server memory: witnessed deeds, patience, lever offers and cooldowns. Save: only `Story.Flags.Doubt_<id>` and deeds through `MoralityService`.

---

## 9. UI (existing assets only, owner rule)

- **Bubbles:** every answer is a TownsfolkClient bubble, as today.
- **Levers:** the existing dialogue box (`DialogueUI`) through `DialogueService.Ask`, with its existing greyed-choice style.
- **Toasts:** the existing Toast ("*Talk to them again to press them.*", "*… doesn't square with …*").
- **Journal:** new text lines in the existing Evidence ledger and Case Board (MenuKit paragraphs): "Told by: <name>" for clue-line evidence; "*Doesn't add up: <title>*" in the existing red text for an exposed lie; exposed lies leave the Case Board's cards.
- No new images, fonts, sounds, ScreenGuis or `StarterGui` edits.

---

## 10. Tests (the plan's tasks name each one)

- **Pure (`Test_Testimony`):** every term and its cap; the bands and their fallbacks; honest NPCs never lie; the Candor −1 spill line; patience skips the Lie band; exposure by contradiction and by `Doubt_`; the stand-in view; `Validate` catches each broken rule; **every opted-in clue in the real rosters gives Truth at neutral**.
- **Server (`Play_Testimony`, a test townsperson with injected defs):** each answer's evidence and signal; Evasive and Refuse give neither; the lever box opens on the second talk, greys and refuses locked choices; bribe takes the exact money and records the deed; intimidate records its deed and raises Heat where the law hears it; a lie's evidence, its exposure toast, the Caught line; a Case Board answer with a lie marks it doubted; a mask and a guise change the answer; the informant stub; patience with a test clock; a clue without `Disposition` is unchanged.
- **Content:** `Play_FoundryLedger` gains the Marsh lie end to end (lie, docket, exposure, Caught, deduction); `Play_LindenmoorData` checks Ned and Bess at neutral and at Distrusted.
- **Regression:** the existing clue suites now set a neutral `Morality` around their clue checks (deep copy, put back), because the owner's real save could be anything.
- **RED then GREEN**, the real save snapshotted and restored, as every plan here does.

---

## 11. Decisions taken without the owner

The owner was asleep (overnight go-ahead, 2026-10-25). Each is a PROPOSAL.

| | Decision | Why |
|---|---|---|
| D1 | **Levers use the existing dialogue box** (`DialogueService.Ask`) after an evasion or refusal. Every line is still a bubble. This **bends the owner's 2026-10-23 "no reply choices" choice** (`Changelog.md:598`) for this one moment. | A bribe or a threat needs a price shown and consent. The alternative, extra hold-prompts on the townsperson, needs new key binds (the keybind system's conflicts) and hides the price. If the owner says no, levers become hold-prompts (PromptUI already draws them) and the rest stands. |
| D2 | **`Text` stays the Truth line**; no separate `Truth` key. | Five clue lines and their tests read `Text` today. |
| D3 | **Deterministic answers**, no dice. | Talking twice must not be a re-roll; tests can check every band. |
| D4 | **Five bands** at 40 / −15 / −35 / −60 (spill at 20 for Candor −1); tier points ±20/±40; kinship ±10 (doubled at Renown Known); Heat −10 or +5 per Wanted level; Heard ±5/+3 capped 15; Witnessed capped 30, −25 for a hit; Informant +20; Masked −10; Guise +20. | Neutral is always Truth; Distrusted evades; Hostile, or Distrusted with a clash of natures, lies or refuses. |
| D5 | **NPC nature is `Temper`** (Mercy, Candor, Order: −1/0/+1). "Evil" = Ruthless and Deceitful. | Same axes as the player's conduct; the owner's "evil spill easier" is kinship plus cheaper bribes plus a lower spill line. |
| D6 | **Absent factions count at half weight** from the global standing. | The Authority isn't in the Foundry region (A10), but the Foundry hands still care what the Authority thinks of you. |
| D7 | **What an NPC saw, patience, lever offers and cooldowns live in server memory.** No save schema change. | Same as the talk rotation; lasting effects are already in deeds and standing. |
| D8 | **Patience:** 10 minutes moves a refusal or evasion one band friendlier, up to two, skipping Lie. | The lever-free path to the truth (the main story's "two ways to the truth"). |
| D9 | **A lie signals the objective; an evasion or refusal doesn't.** | The liar "answered", so the player is misled; the evasive one didn't, so the quest tells them to keep asking. |
| D10 | **An unexposed lie stands in for its truth in deduction `Requires`; an exposed one doesn't.** Exposed lies leave the Case Board's cards. | The lie can mislead the board without soft-locking it, and exposure nudges the player back to the liar. |
| D11 | **A wrong deduction with a lie in it exposes the lie.** | The second net under the contradicting evidence. |
| D12 | **Lies can't be bought or bullied out**; only exposure gets the truth from a liar. | Otherwise money skips the investigation. |
| D13 | **Bribe** 50 Money (×2 after a refusal, ×0.5 for Candor −1; Candor +1 won't take it); deed `bribed_witness` Candor −2, Private, 10 a day. | Close to the morality spec's silencing price (§5) and Brask's fine scale. |
| D14 | **Intimidate**: per-faction deeds `intimidated_<Faction>`: Mercy −3, Order −2, Standing −3, Local, Crime 10, Heat cap 30, 5 a day; not offered against the Authority. | The owner asked that it affect Morality and Heat; deed standing is fixed data, so one deed per faction. |
| D15 | **Persuade** needs global standing Trusted with the NPC's faction, or the Honest conduct word, or Trust 15. | "Persuasion via standing" without dice. |
| D16 | **One lever result per NPC per player per 10 minutes.** | No deed farming. |
| D17 | **`Masked` and `Guise` character attributes** are the contract for masks and disguises. | Neither exists yet; this lets tests and the later work meet in one place. |
| D18 | **`lm_ridge` and `lm_mine` get Evasive, Refuse and Spill but no Lie.** | Chapter 1 teaches investigation; wrong-guess costs are off there. |
| D19 | **Marsh is the only liar in `foundry_ledger`; Rusk and the clerk are honest.** | One lie per quest is enough to teach the rule; Rusk and the docket catch it. |
| D20 | **A new optional teller, Ivo Marchbank**, shows "evil spills easier". | His JobLine already fits ("*Nobody signs for anything after dark.*"); he's not needed to finish the quest. |
| D21 | **Five spill pieces of evidence** (`lm_ridge_visitors`, `lm_shaft_warm`, `foundry_ashe_rounds`, `foundry_ashe_hand`, `foundry_ashe_coin`) and **one false one** (`foundry_marsh_full_pay`). | Bonus cards the main story can use; never required. |
| D22 | **The lever hint is a toast** the first time a witness evades or refuses. | Players won't find the second talk otherwise. |
| D23 | **A newcomer** who replaced a dead liar gives the Truth line, not the Caught line, when the lie is exposed. | They didn't lie; the clue must still finish. |
| D24 | **Dialogue-tree NPCs are unchanged** in this design. | They already have conditions and evidence choices; a `Candid` condition can come later. |

---

## 12. Open questions for the owner (with recommended answers)

1. **The dialogue box for levers (D1).** *Recommended:* yes, only after an evasion or refusal, only on a second talk.
2. **Should a lie be catchable by the Case Board alone (D11)?** *Recommended:* yes. Without it, a player who never finds the contradicting evidence could be stuck believing the lie.
3. **Should intimidation ever be a real crime (D14, Crime 10)?** *Recommended:* yes, small. The owner asked that it touch Heat.
4. **Who else lies?** *Recommended:* only Marsh for now; the main story's witnesses are written with this system from the start.

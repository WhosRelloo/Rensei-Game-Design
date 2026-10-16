# Quests, Environmental Puzzles & UI Minigames — Audit and Proposal

**Status:** approved by the owner 2026-10-15 with the recommended defaults (§6: yes to 1–3, Pressure Board + Array Restoration first, the proposed rewards, choices record a flag only). **Slices S1–S8 built and playtested 2026-10-16** — see `Changelog.md`. Not built yet: the Assay Bench and Ledger Cipher minigames, escort objectives, the Journal codex text. Master plan Phases 6 (quests, dialogue, investigation) and 7 (puzzles and environment). Every number is a PROPOSAL; every lore detail not already in canon is marked **(new)** and needs the owner's OK.

---

## 1. Audit — what exists today (Ye, verified in Studio)

| Area | State | Reuse |
|---|---|---|
| `QuestService` | Works. Quests live in the profile (`Quests.Active` / `Completed`). Progress only moves through server `Signal(Kind, Target)`. Completion leaves Active **before** paying, so rewards can't pay twice. Rewards: EXP, Money. | Keep as the core. Extend, don't replace. |
| Objective kinds | `Talk` (dialogue opened), `Visit` (area entered), `Defeat` (NPC killed, by `QuestTarget` / DisplayName), `Signal` (any id). | Add the kinds in §3.1. |
| `Rensei.Quests` | **Empty on purpose**: no approved content. | First content goes here. |
| `DialogueService` | Works. Server holds the node; the client only sends a choice index; distance and combat checks; actions `StartQuest`, `CompleteSignal`. | Add conditions and more actions (§3.3). |
| `Rensei.Dialogues` | Drillmaster Vask (tutorial, PROPOSAL text) + a placeholder NPC. Vask mentions **chalk circles on the foundry walls drawn without an Authority licence** — an unused story hook. | The vertical slice picks this hook up. |
| `WorldService` | Areas (parts tagged `RenseiArea`, discovery popup, saved in `Areas`), defeat credit, Codex unlock by `CodexEntry` attribute. | Visit objectives, codex. |
| Profile | `Quests`, `Codex` (exists, barely used), `Areas`. No flags, evidence or puzzle state. | Schema v3 adds them (§3.2). |
| UI | Quest log (HUD `Quests` + `QuestHeader` / `QuestTask` templates), dialogue box with choices, banners, PromptUI (custom ProximityPrompts), UIMotion, the menu kit (Settings / Inventory art). | Journal, prompts and minigames reuse this art. |
| Alchemy | Five paths, 20 moves, server-swept hitboxes, `ApplyOnHit` per move. **No hook for alchemy hitting objects** (only characters). | Needs a small "reaction" hook (§3.5). |
| World | **No real map.** `World.Map` is a test arena (baseplate, wall, curve, hill, step). The Tutorial place has the Gate of Truth set. | Content is built on a **graybox test site** until the owner's map exists. |
| Factions / reputation | Not built. Only the State Authority is named (in Vask's PROPOSAL lines). | Out of scope here; choices record flags that a later faction phase reads. |

**Risks found:** quest objectives match on display names (`Defeat` target = DisplayName), which breaks if an NPC is renamed — new content should use the `QuestTarget` attribute. `WorldService` / `DialogueService` keep Instance-keyed weak tables (against the ARCHITECTURE.md rule); new code won't, and fixing those is a separate small task.

---

## 2. Design goals

1. **Alchemy is the verb of the world.** Puzzles react to the five paths, but **no puzzle requires one path** (master plan rule): every alchemy solution has a mundane alternative (a lever, a carried crate, a route to climb, a clue that skips it).
2. **Investigation over waypoints.** Evidence is a real object with a stable id. It unlocks dialogue, contradicts testimony, opens routes, and can be wrong-footed by an NPC who lies.
3. **Failures are recoverable.** Puzzles reset themselves; minigames can be retried; nothing is lost on a mistake unless a choice says so up front.
4. **Server-authoritative and duplicate-proof.** Clients ask; the server checks distance, state and prerequisites; every reward is claimed once.
5. **Fits Rensei's identity:** dark industrial — foundries, steam, ore, licences, chalk and blood circles. UI uses the existing kit; minigames are diegetic (a circle on a workbench, a valve board, a ledger), not arcade popups.
6. **Multiplayer clarity:** every puzzle declares its ownership (§3.6).

---

## 3. Systems

### 3.1 Quest framework (extends `QuestService`)

**Definition** (in `Rensei.Quests`):
```lua
[QuestId] = {
  Title, Description, Category = "Main" | "Regional" | "Investigation" | "Puzzle" | "Contract",
  Requires = {Quests = {...}, Flags = {...}, Level = n},   -- prerequisites, checked on Start
  Stages = {                                              -- NEW: ordered stages; objectives inside a stage run in parallel
    {Id = "s1", Text = "Journal line for this stage", Objectives = {...}},
    ...
  },
  Outcomes = {[FlagId] = {Text = ..., Rewards = {...}}},  -- NEW: branch-specific endings (set by a Choice)
  Rewards = {Exp, Money, Items = {{Name, Amount}}, Training = n, Codex = {...}},
  Repeatable = false, Cooldown = seconds (contracts),
}
```
Old single-list `Objectives` quests keep working (treated as one stage).

**Objective kinds** (reusable handlers; the source system calls `QuestService.Signal`):

| Kind | Fired by | Target |
|---|---|---|
| `Talk` | DialogueService (exists) | dialogue id |
| `Visit` | WorldService (exists) | area name |
| `Defeat` | WorldService (exists) | `QuestTarget` |
| `Collect` / `Deliver` | ItemService / dialogue `TakeItem` | item name |
| `Inspect` | InvestigationService (new) | inspect-point id |
| `Evidence` | when evidence is gained | evidence id |
| `Deduce` | Case Board (new) | deduction id |
| `Mechanism` | PuzzleService (new) | mechanism id + state |
| `Puzzle` | PuzzleService | puzzle id solved |
| `Minigame` | MinigameService (new) | minigame id passed |
| `Choice` | dialogue `Choose` action | choice flag |
| `Escort` / `Protect` | later (needs NPC follow AI) | — |

**Rules:** objectives can be `Hidden` until a stage reveals them; `Optional` objectives add bonus rewards; stage advance is server-side; abandon keeps evidence (knowledge isn't lost). Rewards stay idempotent: the quest moves to `Completed` (with its outcome) before anything is paid, exactly as today.

**Journal:** the existing HUD quest log shows the tracked quest's current stage; the P menu gains a **Journal** tab (Settings art) listing active / completed quests, the stage text history and collected evidence.

### 3.2 Save data — `ProfileData` SchemaVersion 3 (migration adds defaults only)

```lua
Story = {
  Flags = {},      -- [FlagId] = value (choices, world states); never silently overwritten
  Evidence = {},   -- [EvidenceId] = os.time()
  Deductions = {}, -- [DeductionId] = os.time()
  Puzzles = {},    -- [PuzzleId] = {Solved = os.time(), Stage = n} (per-player puzzles only)
  Minigames = {},  -- [MinigameId] = {Best = score, Passed = os.time()}
}
```
`Quests.Completed[QuestId]` stays a timestamp; the outcome is a flag (`Outcome_<QuestId>`). Existing profiles get empty tables; nothing else changes.

### 3.3 Dialogue extensions (`DialogueService` / `Rensei.Dialogues`)

- **Conditions on choices and nodes:** `Requires = {Flag, NotFlag, Evidence, Quest = {Id, State}, Affinity, Clan, Item}`. Unmet choices are hidden by default, or shown greyed with a reason (`Show = "Locked"`), e.g. *[Evidence: Chalk Sample] "This chalk is foundry slag."*
- **Present Evidence** choices: picking one checks the evidence server-side; a lying NPC reacts to the contradiction (new branch).
- **New actions:** `SetFlag`, `GiveEvidence`, `GiveItem` / `TakeItem`, `StartMinigame`, `Choose` (records a consequential choice; asks for confirmation in the UI first), `AdvanceQuest`.
- Stable ids for nodes, choices and evidence (already true for nodes).

### 3.4 Investigation

- **Inspect points:** a part or model tagged `RenseiInspect` with `InspectId`. PromptUI shows "Inspect". The server checks distance and prerequisites, then plays a short look-at line in the dialogue box ("Chalk, mixed with something gritty…") and may grant evidence.
- **Evidence:** `Rensei.Evidence[Id] = {Title, Text, Icon, Tags}`; shown in the Journal's Evidence tab.
- **Case Board (deduction minigame):** a board in the Journal. A deduction asks a question ("Who drew the circle?") with 3–4 slots; the player drags evidence cards into the slots. The server checks the combination. Wrong answers just say "That doesn't hold together" (no penalty); correct ones grant the deduction and fire `Deduce`.

### 3.5 Environmental puzzles (`PuzzleService`, new)

**Mechanisms** are tagged parts or models with a `Mechanism` attribute; their state lives on the server:

| Mechanism | Mundane way | Alchemy reaction (any one works) |
|---|---|---|
| **Brazier / furnace mouth** | carry a lit coal from another fire | **Flame** lights it |
| **Steam vent** (blocks a path, scalds) | close the valve upstream (a valve puzzle) | **Ice** freezes it shut for N s · **Wind** disperses it for N s |
| **Broken catwalk / gap** | find the plank and carry it | **Metal** bridges it · **Earth** raises a step |
| **Rubble / collapsed door** | the long climb route | **Earth** clears it · **Wind** blasts loose debris |
| **Rotating fan / turbine** | crank (hold E) | **Wind** spins it |
| **Pressure plate** | stand on it / place a crate | **Earth** pillar or **Metal** anvil holds it down |
| **Transmutation array** (engraved floor circle) | — | any path: cast inside it to "charge" it (the array's element is a clue) |

**Alchemy hook:** `AlchemyService` gains one call after each cast resolves: `PuzzleService.React(Caster, Element, Position, Radius, MoveId)`. Mechanisms in range respond. Nothing changes in combat.

**Puzzle definitions** chain mechanisms into stages with **fair clues** placed in the world (an engraving, a ledger page, an NPC remark) and **auto-reset** (mechanisms time out back to their start state; the puzzle can be reset at a lever).

### 3.6 Multiplayer ownership

| Ownership | Used for | How |
|---|---|---|
| **Per-player** (default for quest puzzles) | quest investigations, quest puzzles | Server keeps the state per player; each client renders its own state (attributes / remote), so two players never block each other. |
| **Party-shared** | dungeon-style multi-step puzzles (later) | State keyed by party id; any member advances it; credit to all present. |
| **World-shared** | public events (a vent everyone sees frozen) | Server state replicated to all; resets on a timer. |

Players leaving mid-puzzle: per-player state is saved only when a stage completes (no half-states); world-shared objects reset.

### 3.7 UI minigames (`MinigameService`, new) — optional, in-world

All minigames: opened from an in-world object, built from the menu kit, **server-seeded and server-validated** (the client sends the answer, not "I won"), retryable, no loss on failure, and never required for the main path unless the quest says so (each has a skip/alternate). Keyboard, mouse and touch.

1. **Array Restoration** *(alchemy)* — a damaged transmutation circle on a workbench. Rotate its rings so the runes line up with the reference etching found nearby. 3 rings → 5 rings as difficulty. Fits the clap-circle visuals already in the game.
2. **Pressure Board** *(industrial)* — three linked valves feed one gauge; turning one shifts the others. Bring the needle into the green band and hold it. Used to safely close steam vents (the mundane route in §3.5).
3. **Assay Bench** *(deduction)* — identify an unknown ore or chalk sample by testing it (flame, acid, magnet, water) and matching the reactions to a reference table. Gives evidence in investigations.
4. **Ledger Cipher** *(investigation)* — State Authority shipping ledgers use a shift cipher; a clue elsewhere gives the key. Decode a line to learn a name or location.
5. *(later)* **Lockwork** — pin-and-tumbler lockpicking for side doors; contracts only.

---

## 4. Vertical slice — "Chalk on the Foundry Wall" (investigation + puzzle + choice)

Built on a **graybox Foundry Yard** test site in Ye (blocks and placeholder props) until the real map exists. Picks up Vask's existing line about unlicensed circles.

| Stage | What the player does | Systems exercised |
|---|---|---|
| 1. The rumour | Vask (or a foreman **(new)**) mentions fresh chalk marks in the foundry yard. Quest accepted. | dialogue action, quest start |
| 2. The marks | Inspect 3 chalk circles (one is behind a steam vent). Each gives evidence: *Chalk Sample*, *Half-Finished Array*, *Boot Prints (small)*. | inspect points, evidence, vent puzzle (freeze / disperse / valve board) |
| 3. Test the chalk | *(optional)* Assay Bench: the chalk is mixed with foundry slag → evidence *Slag Chalk* (someone who works here). | minigame → evidence |
| 4. Witnesses | Talk to two workers **(new)**. One lies about the night shift; presenting *Boot Prints* or *Slag Chalk* exposes it. | conditioned dialogue, present evidence |
| 5. The sealed store | The trail leads to a locked furnace store. Open it: light the furnace (Flame or carried coal) **and** hold the plate (Earth / Metal / a crate), or restore the broken array (Array Restoration). | multi-stage mechanism puzzle with alternates |
| 6. Case Board | Deduce who drew the circles: a young apprentice **(new)** practising without a licence. | deduction |
| 7. The choice | Report the apprentice to the Authority, keep their secret, or offer to teach them. Each sets a flag; rewards differ slightly; later faction work reads the flag. | consequential choice, outcomes |

Plus one **repeatable contract** (bandit bounty, `Defeat` ×5, cooldown) to prove repeatables.

**Rewards (PROPOSAL):** 400 EXP, 150 money, 2 Mastery training, codex entries *Unlicensed Alchemy* and *Foundry Yard*; outcome extras (a chalk kit item / Authority commendation flag / apprentice ally flag).

---

## 5. Implementation plan (small, testable slices)

| # | Slice | Scripts | Acceptance test (Studio Play) |
|---|---|---|---|
| S1 | Data contracts + Schema v3 migration | `ProfileData`, `DataManager` (Migrate), `Rensei.Quests` / `Evidence` / `Puzzles` / `Minigames` registries | An existing profile loads unchanged with empty `Story` tables; a new one too. |
| S2 | Quest stages, prerequisites, outcomes, item/training/codex rewards, journal tab | `QuestService`, `HUDUI` quest log, new `JournalUI` | A 3-stage test quest completes, survives a rejoin mid-stage, pays once (spam the final signal 20×). |
| S3 | Dialogue conditions + actions + present evidence | `DialogueService`, `DialogueUI` | Locked choices hide/grey; evidence choice works only with the evidence; a crafted client choice index can't bypass a condition. |
| S4 | Investigation: inspect points, evidence, Case Board | new `InvestigationService`, `JournalUI` | Inspect from 30 studs is refused; evidence persists; a wrong deduction costs nothing; the right one fires `Deduce`. |
| S5 | PuzzleService + alchemy reaction hook + mechanisms | new `PuzzleService`, one call in `AlchemyService` | Each mechanism solved by its alchemy path **and** its mundane way; auto-reset; two players' per-player states don't interfere (2-client test). |
| S6 | MinigameService + Pressure Board + Array Restoration (+ Assay, Cipher) | new `MinigameService`, `MinigameUI` | Server rejects a forged "solved" answer; retry works; touch works. |
| S7 | Graybox Foundry Yard + "Chalk on the Foundry Wall" + contract | `World.Map.FoundryYard`, content modules | Full run with each of the five paths and with no alchemy; all three outcomes; rewards once. |
| S8 | Docs + QA | this repo | Changelog / Status / Architecture updated; multi-client test. |

Every slice backs up touched scripts to `ServerStorage.RenseiBackups["Pre-<Name>_<date>"]` first.

---

## 6. Decisions needed from the owner

1. **Lore:** may the slice use the foundry district, the State Authority licence, and the new characters (foreman, two workers, the apprentice)? Names and lines are placeholders until you approve them.
2. **Location:** build a graybox Foundry Yard in Ye now (recommended), or wait for your map?
3. **Ownership default:** per-player puzzle state for quests (recommended)?
4. **Minigames:** which of the four to build first? (Recommended: Pressure Board + Array Restoration, then Assay + Cipher.)
5. **Rewards:** are the PROPOSAL numbers in §4 acceptable as a starting point?
6. **Consequences:** should the slice's choice change anything now (e.g. an NPC appears/leaves), or only record a flag for the faction phase?

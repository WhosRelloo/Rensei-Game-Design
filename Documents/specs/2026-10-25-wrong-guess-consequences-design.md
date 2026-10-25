# Wrong-guess consequences: audit and design (PROPOSAL)

**Status:** written overnight on 2026-10-25 under the owner's overnight go-ahead. **Not approved by the owner yet. Nothing here is built.** The plan is `Documents/plans/2026-10-25-wrong-guess-consequences.md`.

**The owner's request** (Backlog, "After the swimming revamp", item 3, 2026-10-25): "Consequences for wrong guesses in minigames and puzzles on quests."

**When it's built:** after the assassinations and the stealth missions (Backlog order). Reputation in investigations (Backlog item 5) comes after it and uses its hooks (§10).

**The hint we followed** (`Documents/specs/2026-10-25-main-story-concept.md:177` and `:233-234`, a draft): consequences are told up front, never a dead end, off in Chapter 1, on from Act II. We treated it as a strong hint, not a rule.

**Owner rules that bind this design:**
- **UI:** only the game's existing UI assets. This design adds no image, font, sound, frame or ScreenGui.
- Do not publish the game or change live player data.

**Every number and every new name in this file is a PROPOSAL** unless it is marked as the owner's.

---

## 1. Audit: what happens today

Read from the repo exports on 2026-10-25. Studio was not opened. The plan's Task 1 confirms the Studio copies match.

### 1.1 The short answer

| Question | Minigames (UI) | Environmental puzzles | Case Board deductions |
|---|---|---|---|
| What happens on a wrong answer? | A red line and a shake; the panel stays open on the same puzzle | Nothing: mechanisms just change state | A toast with the deduction's `Wrong` line |
| Are attempts unlimited? | Yes | Yes | Yes |
| Is there a cooldown? | 0.3 s between submits | No | No (only the global request limit, 8 a second) |
| What does the player lose? | Nothing | Nothing (timed states revert by themselves) | Nothing |
| Is anything recorded? | A try count, saved on the pass, read by nothing | No | No |

The only wrong-guess penalty in the game today is outside this request: naming a player wrongly in Identities locks that record for 10 minutes (§1.6).

### 1.2 Minigames (`MinigameService`, `Rensei.Minigames`)

- **The rule is written down.** "Server-seeded, server-validated, retryable; a failed attempt costs nothing" (`Minigames.lua:1-2`). The service says the same: "A fail: try again (Kind.Failed resets what it used up)" (`MinigameService.lua:7`).
- **A wrong submit** (`MinigameService.lua:313-337`):
  - is rate-limited to one per 0.3 s (`:317`);
  - counts `S.Tries` (`:327`) and calls the kind's `Failed` reset, if any (`:329`);
  - sends the kind's reason or `Def.Fail`, and from the third try adds `LateHint` (`:331-332`);
  - leaves the session open on **the same seed** (`:333-334`).
- **The client** shows the line in red and shakes the panel (`MinigameUI.lua:454-462`). Nothing closes, nothing is lost.
- **Closing and reopening** deals a new puzzle (`Random.new()` on every `Open`, `:239`). `Close` has no cost (`:347-348`).
- **Tries are saved but never read.** On a pass, `Story.Minigames[Id].Tries` adds the session's tries (`:296`); no script reads it.
- **Kinds that can be guessed rather than solved:**
  - **Assay Bench:** a wrong row refills the chips (`MinigameService.lua:147-150`, documented at `Minigames.lua:12-13`; Mirra's line at `:56`). With six rows, a player can name rows one by one without running a single test.
  - **Ledger Cipher:** the answer is one of seven places (`Minigames.lua:63`). A player who never found the key on the crate (`Investigation.lua:214-217`; "the key is never sent", `MinigameService.lua:181`) can try all seven.
  - **Pressure Board** and **Array Restoration** are solved by watching the gauge or the rings, so guessing gains nothing.
  - **The alchemy kinds** (ReactionControl, PhaseSequence, LoadPaths, PressureRouting, MaterialMatch): the client previews every move with the same rules the server checks (`AlchemyMinigames.lua:2-6`), and a failure already says what went wrong (`AlchemyMinigameUI.lua:107`, "Reset to try again."). A fail teaches; nothing is lost.
- **World challenges** (Combat Read, the runs) end on a fail and can be restarted at once (`WorldChallenges.lua:133-135`, `:205-207`; `MinigameService.lua:384-386`). They are skill tests, not guesses, and pay at most `PerDay` passes (`Minigames.lua:157-158`).

### 1.3 Environmental puzzles (`PuzzleService`, `Rensei.Puzzles`)

- **Failures are recoverable by design:** "Timed states revert by themselves (failures are recoverable)" (`PuzzleService.lua:13`).
- **Wrong alchemy** on a mechanism shows its `Refuse` line, a clue, not a penalty (`PuzzleService.lua:159-161`, e.g. `Puzzles.lua:64`).
- **Levers and sluices** flip freely on every use (`PuzzleService.lua:227-231`). The Adit's shift chart warns "Never all three open or the gallery floods" (`Investigation.lua:31`), but **no code reads an all-open state**. The puzzle only checks the right answer (`Puzzles.lua:182-184`).
- **Bench mechanisms** open a minigame (`PuzzleService.lua:224-226`) and take its pass state (`:255-259`), so they inherit §1.2.
- **Breakables** (the Adit boards) count hits, which is progress, not guessing (`PuzzleService.lua:188-210`).
- **The client** (`PuzzleClient.lua:1-2`) only draws states the server sent. It decides nothing.
- **Ownership is per player** (`Puzzles.lua:2-3`), so one player's mistakes never block another.
- **The Adit boards kit** (`Art/Studio/HalvardsAdit/boards/`, 2026-10-20) is a snapshot taken when the boards were added:
  - its `PuzzleService.lua`, `Puzzles.lua` and `PuzzleClient.lua` equal today's `Scripts/` copies once line endings are normalised;
  - its `Investigation.lua` is older (it lacks the Foundry ledger and the `Rensei.Quests` require);
  - `HitboxManager.lua` (the melee hook into `PuzzleService.Strike`) has no `Scripts/` copy;
  - `Play_AditBoards.lua` tests the boards: three hits break them, any element breaks them, the break is saved and shared with the party.
  - Breaking is progress, not guessing, so the boards get no consequence. The kit is a record: this design doesn't edit it, and runs `Play_AditBoards` as a regression where Ye has it.

### 1.4 Case Board deductions (`InvestigationService.Deduce`, `Rensei.Investigation`, `JournalUI`)

- **The rule is written down:** "a wrong answer costs nothing (fair, recoverable)" (`InvestigationService.lua:10-11`).
- **`Deduce`** (`InvestigationService.lua:68-82`) checks each slot, and on the first wrong one returns `Def.Wrong`. It records nothing and has no cooldown.
- **The request path:** `Requests/Investigation.lua:11-13` sends the result as the UI event `CaseResult`. Only the global request limiter applies: 8 a second, 16 burst (`ServerHandler.server.lua:52`, `:67`).
- **The client:** Submit sends the pins (`JournalUI.lua:656-664`); a wrong result toasts and shows the line in red (`:944-948`, `:667-668`).
- **The message never says which slot is wrong,** but a three-slot board over 3 to 5 clues is small: at most 60 orderings for `foundry_ledger_who` (5 clues, 3 slots, `Investigation.lua:309-320`). Nothing stops trying them all.
- **The original proposal chose this:** "Wrong answers just say 'That doesn't hold together' (no penalty)" (`Quests, Puzzles and Minigames Proposal.md:103`), under the goal "Failures are recoverable... nothing is lost on a mistake **unless a choice says so up front**" (`:31`). This design is that exception.

### 1.5 Trials (`TrialService`, `Rensei.Trials`)

- Fights, not guesses. A failure is recoverable, with a retry at the arena and the trial's `Hint` after two failures (`TrialService.lua:13-14`, `:343-349`; `Trials.lua:14`).
- **Out of scope:** combat already costs something (being knocked down).

### 1.6 The one existing penalty: Identities

- Naming a player wrongly locks that record for `WrongLock` = 600 s (`Identities.lua:18`; `IdentityService.lua:244-249`).
- **It is told up front:** "A wrong name locks this record for %d min." under the Name button (`JournalUI.lua:874`).
- It already follows every rule in §3 (told first, timed, recoverable). This design copies its pattern and leaves it as it is.

### 1.7 Which quests use which puzzles

Every objective kind is listed at `Quests.lua:21-23`.

| Quest (category) | Minigames | Puzzles | Deduction |
|---|---|---|---|
| `forgotten_halvard` (Exploration, **Tier 1**, Ye; `Quests.lua:32-33`) | `adit_winch` (Pressure Board) through the `Mechanism` objective `adit_winch:Running` (`:41`); `adit_assay_ring` (Array Restoration) inside `adit_vault` | `adit_drain` (`:44`), `adit_hidden` (optional, `:49`), `adit_vault` (`:52`) | `adit_truth` exists (`Investigation.lua:225`) but **no objective asks for it** |
| `chalk_foundry` (Investigation, Ye's FoundryYard; `:113-116`) | `pressure_board` seals the vent on the way to the second mark (`Puzzles.lua:67-70`); `array_restoration` in `furnace_store`; `assay_chalk` and `ledger_cipher` are optional extra evidence (`Puzzles.lua:97-105`) | `furnace_store` (`:129`) | `who_drew` (`:135`) |
| `foundry_ledger` (Investigation, **Foundry**; `:94`) | — | — | `foundry_ledger_who` (`:108`) |
| `acq_flame` (Main; `:165`) | `flame_reaction` (`:185`), `flame_exam` (`:191`) | — | `lab_fire_cause` (`:182`) |
| `acq_ice` (`:199`) | `ice_phase` (`:217`), `ice_exam` (`:223`) | — | `station_freeze` (`:214`) |
| `acq_earth` (`:231`) | `earth_loads` (`:249`), `earth_exam` (`:255`) | — | `bridge_failure` (`:246`) |
| `acq_wind` (`:263`) | `wind_routing` (`:281`), `wind_exam` (`:287`) | — | `observatory_stall` (`:278`) |
| `acq_metal` (`:295`) | `metal_match` (`:317`), `metal_exam` (`:323`) | — | `forge_failure` (`:314`) |
| not quests | `lesson_*` (TrainingService drills, `Minigames.lua:93`, `:110`, `:123`, `:136`, `:151`); `combat_read`, `lindenmoor_run`, `foundation_run` (world challenges, `:160-210`) | — | — |

`lm_ridge`, `lm_mine` and `bandit_bounty` use none.

### 1.8 Where today's content sits in the story

- **No quest has an act.** "Act" in `Minigames.lua:70`, `:82` and `Trials.lua:1` means a step of an alchemy questline, not a story act.
- `forgotten_halvard` is Exploration **Tier 1** (`Quests.lua:30-33`).
- In the story draft, Lindenmoor (Ye, the Adit, Ye's FoundryYard) is **Chapter 1 / Act I**, and **Foundry Yard is Act II** (`main-story-concept.md`, §3.2).
- So by the hint, **everything today is off**, except content in the Foundry Yard place: `foundry_ledger`.

### 1.9 Findings that shape this design

1. Nothing counts wrong guesses across sessions. A count kept in the open session would reset on Close (§1.2), so **strikes must be keyed by the puzzle and saved**, not kept in the session.
2. `Story.Flags` already stores small packed values ("day:count" for minigame rewards, `MinigameService.lua:270-281`), and the whole profile reaches the client (`ProgressionService.lua:30-38`, `DataManager:SendData`). **Strikes can live there with no schema change**, and the UI can read them.
3. Two kinds (Assay Bench, Ledger Cipher) and the Case Board can be brute-forced today (§1.2, §1.4).
4. The Identities lock (§1.6) is a working, told-first pattern to copy.
5. The fiction already promises consequences that the code doesn't keep: the flood at the sluices (`Investigation.lua:31`), "no second chances on stock" (`Minigames.lua:146`), "cross it and the lesson burns" (`:84`).
6. Noise (`NoiseService.Emit`, `NoiseService.lua:39-56`), crimes and Heat (Deeds `Crime`, `Deeds.lua:15-18`; `HeatService.lua:3-7`), rumours (`RumourService.lua:3`) and timed flags all exist. **A consequence can reuse each of them** instead of inventing a new channel.
7. `LateHint` arrives on the third try (`MinigameService.lua:332`). With two strikes, it would never show. It has to move.

---

## 2. Consequence types

A consequence fires when a player runs out of **strikes** (wrong tries) on one puzzle. Then the strikes reset. Each type matches a kind of fiction.

| Type | The fiction | What the server does | Fits |
|---|---|---|---|
| **Lockout** | The boiler loses its head of steam; the pieces blur and you need to step away; the clerk shoos you off | Locks that puzzle for N seconds. The minigame closes, the Case Board's Submit is refused, a puzzle's mechanisms reset and won't move | Every kind. **A wrong vault code adding a delay** is a Lockout with 1 strike and a short time |
| **Alarm** | A failed lock clanks, a vent shrieks, someone hears you at the ledger | A noise at the spot through `NoiseService.Emit` (guards come to look; they learn where, not who). With `Crime`, also the deed `tripped_alarm` | Locks, valves, papers in guarded places; stealth missions (§7) |
| **Backfire** | The reaction runs away and singes you | A small hit of damage and an optional short Burn or Freeze. It **never** knocks the player down | The alchemy kinds |
| **Waste** | You burn through reagents or ruin stock | Costs money (the reagents' price). If the player can't pay, it becomes a Lockout instead | Alchemy benches, assay chips |
| **ClamUp** | A witness you pressed wrongly won't talk for a while | A timed flag `Clam_<Npc>`; dialogue can show a "clammed" node while it holds | Deductions with a suspect; dialogue presses (later, §8) |
| **TipOff** | The culprit hears you're asking | Sets a flag that the quest's **Outcomes** read (a lesser ending, a smaller reward). Never blocks an objective | Accusation deductions |

**Every type may also lock.** For example, a failed lock can sound an Alarm **and** jam for 60 s.

**What strikes mean to the player:** a count of wrong tries left, shown before the first attempt and after every miss ("2 tries left before the boiler loses its head").

---

## 3. The rules

1. **Never a dead end, never a soft lock.**
   - Every lock is timed. The longest is 10 minutes (the validator refuses more).
   - Waste never blocks: a player who can't pay gets a short lock instead.
   - Backfire never knocks down: it stops at 25% health.
   - ClamUp is timed (15 minutes at most).
   - TipOff only changes an ending. The validator refuses a TipOff flag in any `Requires` that gates starting a quest or getting evidence.
   - An Alarm can start a fight. That is the game's normal, recoverable risk.
2. **Always told before the attempt.** The warning line and the strikes left appear on the minigame panel, under the Case Board's Submit, and as a toast the first time a player touches an armed puzzle. A consequence with no `Warn` line fails validation.
3. **Scaled by the quest's stakes** (§4): light in Act II, harsher by Act V.
4. **Off in the tutorial and early content.** Stakes 0 means no strikes, no consequence and no warning: today's behaviour exactly. Chapter 1 / Act I and Exploration Tier I are Stakes 0.
5. **Only on quests.** A puzzle is armed only while the quest that owns it is **Active**. Drills, world challenges, trials and optional side minigames outside a quest are never armed.
6. **The same rules for parties.** Strikes and locks are per player, like puzzle states. A party member's mistakes never use your strikes. An Alarm is heard in the world, so it can bring guards down on the whole party.
7. **Server-decided.** The client only shows what the server stored (§9).

---

## 4. Stakes: scaling by act or tier

**Stakes** is a number from 0 to 3 for each quest.
- A quest's explicit `Stakes` field wins.
- Otherwise it comes from a new quest field **`StoryAct`** (named so it can't be confused with an alchemy questline's "acts"):
  - Act I → 0, Act II → 1, Acts III and IV → 2, Act V → 3.
- Otherwise, for Exploration quests, from `Tier`:
  - Tier I → 0, Tier II → 1, Tier III → 2, Tier IV → 3.
- Otherwise 0.

**Defaults by stakes.** A puzzle's own numbers override these, within the validator's caps.

| | Stakes 1 | Stakes 2 | Stakes 3 | Cap |
|---|---|---|---|---|
| Strikes before it fires | 3 | 2 | 2 | 1–5 |
| Lockout | 60 s | 180 s | 300 s | 600 s |
| Alarm radius | 25 studs | 40 | 60 | 80 |
| Backfire | 5% of max health | 10% | 15% | 20%, never below 25% health |
| Waste | the puzzle's `Money` × 1 | × 1.5 | × 2 | 500 |
| ClamUp | 120 s | 300 s | 600 s | 900 s |

**Hints move earlier.** On an armed puzzle, `LateHint` shows after the **first** miss instead of the third.

---

## 5. Data shape

Each minigame, puzzle or deduction may carry a `Consequence` table and a `Strikes` count:

```lua
-- in Rensei.Minigames, Rensei.Puzzles.Puzzles or Rensei.Investigation.Deductions
foundry_ledger_who = {
	...,
	Strikes = 3, -- optional; default from the quest's stakes
	Consequence = {
		Kind = "Lockout",          -- Lockout | Alarm | Backfire | Waste | ClamUp | TipOff
		Warn = "Three wrong boards and the pieces start to blur together.", -- shown BEFORE the attempt (required)
		Text = "You've turned it over too many times. Step away and come back to it.", -- shown when it fires (required)
		Lock = 60,                 -- optional seconds; true = the stakes default; Lockout always locks
		Quest = "foundry_ledger",  -- optional; otherwise found from the objective that targets this id
		-- per kind:
		-- Alarm:    Radius = n (or the default), Crime = true (records tripped_alarm)
		-- Backfire: Share = 0.1 (or the default), Status = "Burn" | "Freeze" (2 s at most)
		-- Waste:    Money = n (the base cost)
		-- ClamUp:   Npc = "Tobin", For = seconds (or the default)
		-- TipOff:   Flag = "TipOff_<quest>" (or that default)
	},
},
```

- **Puzzles** (environmental) add one more field, `Wrong = function(States) -> bool`. Reaching a wrong state counts as one miss (for example, all three sluices open).
- **Keys** name one guess site: `M:<minigame>`, `P:<puzzle>`, `D:<deduction>`.
- **The save:** `Story.Flags["Guess_<M|P|D>_<id>"] = "<strikes used>:<locked until (os.time)>"`. It is cleared on a pass and reset to `0:<until>` when the consequence fires. No schema change.
- **Timed NPC state:** `Story.Flags["Clam_<Npc>"] = <until>`. New StoryLogic conditions `Clammed = "Npc"` and `NotClammed = "Npc"` read it.
- **A shared pure module, `Rensei.WrongGuess`,** holds the defaults, the stakes rule, the flag format, `Armed(...)`, the strike step and the validator. The server and the client both use it, so the warning the player reads is what the server will do.

---

## 6. Ties to Heat, rumours, Morality and reputation

- **Heat:** only through a crime, never by writing Heat directly. An Alarm with `Crime = true` records the new deed `tripped_alarm`:
  - "Was heard forcing a lock", `Crime = 5`, `HeatCap = 15`, `Scope = "Local"`, `Repeat = {Cap = 3}` (all PROPOSAL);
  - recorded with `Witness = true` (`MoralityService.Record`, `MoralityService.lua:91-94`). HeatService's rules decide the rest: Heat at once if a law agent saw it or the law's faction is present, otherwise when word reaches a place whose law hears it (`HeatService.lua:3-7`).
- **Rumours:** the same deed is Local and perceived, so RumourService carries it (`RumourService.lua:3`). Nothing new.
- **Morality:** `tripped_alarm` moves no Conduct axis. A wrong guess isn't a moral act. Later, an accusation deduction could record a Candor deed for accusing an innocent (§11), but not in this version.
- **Reputation shapes investigations** (Backlog item 5, after this one):
  - **ClamUp** is the hook. That plan can make a witness clam up at once if they distrust you, or give a trusted investigator an extra strike.
  - `Rensei.WrongGuess.StrikesFor(Def, Stakes, Mods)` takes an optional modifiers table for it. This version passes none.
  - Townsfolk clue lines (`TownsfolkService`) aren't touched here. That plan owns how NPCs answer.

---

## 7. Ties to stealth missions

The stealth missions design (`Documents/specs/2026-10-25-stealth-missions-design.md`) has locks, ciphers and alarms. Its plan isn't written yet; it runs **before** this one.
- **Alarm is the bridge.** A wrong guess on a compound lock makes a noise that the guards' existing hearing picks up (§3.2 there: "A sound sends the guard to the spot"). The mission plan can add a radio call or count the run as **Loud** (its §5.1).
- **`WrongGuessService.Listen(Fn)`** tells any listener when a consequence fires (player, key, kind, position), as `NoiseService.Listen` does. Missions can grade with it without this plan knowing about missions.
- **Contracts and mission quests set `Stakes` explicitly.** A Copy-a-document job (the Ledger Cipher, stealth spec §2.5) can then raise the alarm on a wrong decode.
- **The plan's Task 1 checks what the stealth missions plan built.** Task 8 arms whatever locks or ciphers it added, if any.

---

## 8. What is armed on day one

Only content outside Chapter 1 is armed. Today that is one deduction.

| Site | Quest and stakes | Consequence (PROPOSAL) |
|---|---|---|
| `foundry_ledger_who` | `foundry_ledger` gets `StoryAct = 2`, so Stakes 1 | **Lockout**, 3 strikes, 60 s. Warn: "Three wrong boards and the pieces start to blur together." Text: "You've turned it over too many times. Step away and come back to it." |

**Suggestions for when the story moves content into Act II or later.** Not written into the data in this version. The owner picks.

| Site | Fits |
|---|---|
| `adit_drain` (sluices) | Lockout and reset: "The gallery floods. You'll have to wait for it to drain." (`Wrong` = all three open, which the chart warns about) |
| `adit_assay_ring` (vault) | "Wrong vault code": Lockout, 1 strike, 20 s |
| `adit_winch`, `pressure_board` | Alarm without a crime: the line shrieks |
| `ledger_cipher` | Alarm with `Crime`: you're heard rifling Authority papers |
| `assay_chalk` | Lockout: Mirra stops handing you chips for a while |
| `who_drew` | TipOff: Lise hears someone is asking (a different ending line) |
| `flame_reaction`, `flame_exam` | Backfire with Burn |
| `metal_match`, `metal_exam` | Waste: ruined stock |
| `ice_phase`, `earth_loads`, `wind_routing` and their exams | Lockout |
| the five acquisition deductions | Lockout |

---

## 9. Server validation and anti-exploit

- **The server decides** right or wrong, as today. Strikes and locks are stored by the server in the save; the client only draws them.
- **Locks are checked by the server** on `MinigameService.Open`, on `Deduce`, and on every player-driven puzzle change (prompts and alchemy reactions). Never only in the UI.
- **Reopening doesn't reset strikes:** they are keyed by the puzzle, not the session.
- **Rejoining doesn't reset strikes or locks:** they are saved, with `os.time()` deadlines.
- **Abandoning and restarting the quest doesn't reset them** either (the flag stays).
- **Every server-rejected answer on an armed puzzle counts.** The client already blocks empty answers (`MinigameUI.lua:366-372`, `JournalUI.lua:656-661`), so only hand-made requests send malformed ones.
- **Throttles:** the minigame submit keeps its 0.3 s. The `"Deduce"` request gets 1 s per player, armed or not. It sits on the request path (`Requests/Investigation.lua`), not inside `InvestigationService.Deduce`, so server code and tests that call `Deduce` twice in a row (`Play_FoundryLedger.lua:174-179`) are unaffected.
- **Effects only come from a real, server-checked miss** on an armed puzzle. There is no new remote. The existing `MinigameRemote`, `Requests.Investigation` and `PuzzleRemote` carry everything; `CaseResult` gains three fields.
- **Caps** (§4), enforced by the validator in tests and clamped again in the service at run time.
- **Backfire** is applied through `DownedManager.Damage`, capped so the player's health stays above 25%. It is skipped if the player is knocked down or below that line.

---

## 10. UI (owner rule: existing assets only)

- **Minigame panel:** the warning and the tries left appear in the panel's existing result line (`ResultLabel`) in the dim colour whenever it would otherwise be empty. Misses add "(n tries left)" to the line the panel already shows. When a lock fires, the panel closes with the consequence's `Text`, as "You walked away from it." does today.
- **Case Board:** one dim paragraph under Submit, the same pattern as the Identities warning (`JournalUI.lua:874`): the warning and the tries left. While locked: "Come back to it in n min." in the existing red, with Submit dimmed as it already is when lines are missing (`JournalUI.lua:666`).
- **Puzzles:** a toast (`UIService.Notify "Toast"`) with the warning the first time in a session that a player touches an armed puzzle, and the consequence's `Text` when it fires.
- **Refusals while locked:** the existing toast.
- **No** new images, fonts, sounds, frames, ScreenGuis or StarterGui edits.

---

## 11. Hooks for later

- `WrongGuessService.Listen(Fn)`: stealth mission grading, the Nemesis "rival heard about it" idea.
- `StrikesFor(..., Mods)`: reputation in investigations.
- `Clammed` / `NotClammed`: dialogue presses (the reputation plan adds wrong-press choices).
- A Candor deed for a wrong accusation of an innocent NPC, once deductions can accuse a living suspect.

---

## 12. Tests

- **Pure** (`Test_WrongGuess`): the stakes rule from `Stakes`, `StoryAct` and `Tier`; defaults and caps; the flag format round-trip; the strike step (miss, fire, reset, lock, expiry); `Armed` true only with an Active owning quest and Stakes ≥ 1; the validator on hand-made bad defs (no `Warn`, a 20-minute lock, a TipOff flag in a `Requires`), and on the real data, which must pass.
- **Server** (`Play_WrongGuess`, in Play, inside the save hook): test-only definitions are injected at run time; nothing is added to the shipped data.
  - **Minigames:** misses count; the third fires; Open is refused while locked; reopening keeps the count; a pass clears it; `LateHint` comes after the first miss.
  - **Deductions:** the same, through `InvestigationService.Deduce`; the 1 s throttle through the request handler.
  - **Puzzles:** a `Wrong` state counts; a lock resets and freezes the mechanisms; a timed revert still works.
  - **Each effect:** Alarm (`NoiseService.Log` sees the radius; with `Crime`, the deed is on the ledger), Backfire (health falls but stays above 25%; never knocked), Waste (money taken; with too little money, a lock instead), ClamUp (the flag and the condition), TipOff (the flag).
  - **Controls,** so no check passes by construction: every "unarmed does nothing" check runs the **same** input against an armed control in the same test and sees a strike there. Every "locked" check first sees the action succeed with no lock.
- **Regressions:** `Play_FoundryLedger` (its one wrong board must still return exactly the `Wrong` line), `Play_Exams`, `Play_Clue`, `Play_Heat`, `Play_Morality`, `Play_Rumours`, `Play_Stealth`.
- **Client checks:** the panel line, the Case Board paragraph and the locked state, read in Play from the real UI.

---

## 13. Decisions taken without the owner

The owner was asleep (overnight go-ahead, 2026-10-25). Each is a PROPOSAL and can be changed by a number in `Rensei.WrongGuess` or one data line.

1. **Stakes 0–3 per quest,** from an explicit `Stakes`, a new `StoryAct` field, or the Exploration `Tier` (§4).
2. **Armed only while the owning quest is Active.** Drills, world challenges, trials and optional side minigames are never armed.
3. **Day one arms only `foundry_ledger_who`** (`foundry_ledger` gets `StoryAct = 2`). Everything else is Chapter 1 or Tier I, so it stays off. §8 lists suggestions.
4. **The default numbers** in §4.
5. **Strikes are saved** in `Story.Flags`, cleared on a pass, reset when the consequence fires, and never decay with time.
6. **Every server-rejected answer counts as a miss** on an armed puzzle.
7. **`LateHint` after the first miss** on armed puzzles.
8. **Waste costs money,** because no reagent items exist yet. It falls back to a lock if the player can't pay.
9. **Backfire** never goes below 25% health and never knocks down. Only Burn or Freeze, at most 2 s.
10. **Alarm is a plain noise radius** (not a new named sound), so townsfolk don't treat it as a fight. `Crime` records the new deed `tripped_alarm` (Crime 5, HeatCap 15, Local, at most 3 a day).
11. **ClamUp is a timed flag plus a StoryLogic condition.** Townsfolk clue lines are left to the reputation plan.
12. **TipOff is a flag only.** It may change an ending; the validator stops it from gating anything.
13. **Parties:** strikes and locks are per player; an Alarm is heard in the world.
14. **The `"Deduce"` request gets a 1 s throttle** for everyone, armed or not, on the request path only.
15. **Where the warning shows:** the panel's result line, a Case Board paragraph, and a first-touch toast for puzzles.
16. **Identities' wrong-name lock is left as it is.** It already follows these rules.
17. **Trials and world challenges are out of scope:** they are skill tests, not guesses.
18. **Puzzle `Wrong` states are built** but no shipped puzzle uses one yet (the Adit flood is a suggestion, because the Adit is Tier I).

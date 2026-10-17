# Alchemy Acquisition & Mastery Questlines

**Status:** built and playtested in Ye, 2026-10-17: all five questlines run end to end (see §5). Not pushed to GitHub yet. Owner prompt: "RENSEI — ALCHEMY ACQUISITION & MASTERY QUESTLINES". Every number is a **PROPOSAL**; every name and line of dialogue is placeholder-quality until the owner rewrites it.

## 1. Audit (what exists, verified in the Ye place)

| System | What's there | Reused as |
|---|---|---|
| **Affinity** | One path per character: `Identity.Affinity` ("" = none). Set today only by the admin panel (`AdminService.SetAlchemy` → `AlchemyService.PublishAffinity` → `ProgressionService.Sync`). `AlchemyService.AffinityOf` falls back to `StudioTestAffinity` in Studio only. Moves: Z comes with the path; X/C are bought in the Mastery tree; V needs the first Truth/Gate stage. | The acquisition reward sets `Identity.Affinity` through the same calls. Acquisition never touches the skill tree. |
| **Quests** | `QuestService` + `Rensei.Quests`: staged quests; objectives Talk, Visit, Defeat, Inspect, Evidence, Deduce, Puzzle, Minigame, Mechanism, Flag, Signal; Optional / Hidden objectives. Saved in `Quests.Active` / `Completed`. CatchUp fills objectives already true. Completion leaves Active **before** paying, so rewards pay once. | All five questlines are ordinary staged quests. New: reward `Affinity`, condition `NoAffinity`, `Quest.Is = "NotActive"`. |
| **Dialogue** | `DialogueService` + `Rensei.Dialogues` + `DialogueUI`: per-NPC trees, `Starts` (conditional opening node), `Alt` (conditional text), `Requires` / `Show = "Locked"` choices, server-held session (a forged index can't reach a hidden choice), distance and combat checks, Actions (StartQuest, Signal, SetFlag, GiveEvidence, GiveItem, StartMinigame, Deed). | The trainers' trees. New actions: `Lesson`, `Exercise` (trials start from the arena's own prompt; exams open with `StartMinigame`). |
| **Investigation** | `InvestigationService` + `Rensei.Investigation` (inspect points with `Requires`, Case Board deductions) + `Rensei.Evidence`; the Journal (J) shows evidence and the Case Board. | Fieldwork clues and deductions. **Research Notes** are evidence entries marked `Research = true`. |
| **Minigames** | `MinigameService` (server keeps the secret, checks the answer, drift limit, fail = retry) + `MinigameUI` (one builder per kind) + `Rensei.Minigames`. | Five new kinds (one per discipline); final exams are harder settings of the same kinds. |
| **Puzzles** | `PuzzleService`: per-player mechanisms that react to alchemy casts by element, prompts, plates. | Post-acquisition practical exams (real casts at mechanisms). |
| **Mastery** | `ProgressionService.AddTraining(Player, Source, Mult)`: 100 TP = 1 MP, per-source hourly allowance then 15–20%, idle check, **nothing past the stage's 20 MP** (Truth/Gate). The trial itself isn't built. | New sources `Lesson`, `Exercise`, `Exam` — capped by the same rules, so training can never pass the Gate. |
| **Enemies** | `EnemyService.Spawn(Part)` (tag-based; the admin panel spawns on demand); two types: Bandit (Grunt), Bandit Duelist (Elite: blocks, parries). No alchemy-using AI. `WorldService` credits the last hitter. | Trial foes are new Elite-style types; their "alchemy" is server-run telegraphed hazards (`TrialService`). Credit goes only to the trial's owner. |
| **World** | No real map yet: a graybox arena (Foundry Yard at z≈215, bandits south, the trainers east of spawn at x=44). | Five compact graybox sites, built from parts + the imported Alchemist Assets (books, research papers). |

## 2. Conflicts with the prompt, and the decisions taken

1. **One affinity per character** (existing design: "picked, not rolled"; one `Identity.Affinity`). A character earns **one** discipline: starting an acquisition questline needs no affinity, and only one can be active. After acquisition the other trainers still talk, share lore and Research Notes, but won't teach. Each completed questline is recorded (`Acquired_<Path>` flag) so a future owner decision (respec, second discipline) has the data.
2. **Truth/Gate is unchanged.** Training sources are capped by the stage limit, so no quest or lesson moves a player past 20 MP of a stage; the trial stays unbuilt.
3. **Acquisition ≠ mastery.** Acquisition grants the path only (Z). X/C/V stay in the Mastery tree.
4. **No real map:** graybox sites until the owner's map exists; each site is a self-contained folder that can be moved.
5. **No alchemy enemy AI:** trials pair an Elite-derived foe with telegraphed environmental hazards the server runs.

## 3. Architecture (new pieces only)

- `Rensei.Quests`: `acq_flame`, `acq_ice`, `acq_earth`, `acq_wind`, `acq_metal`. Six stages each: Invitation (Visit) → Fieldwork (3 evidence + optional research note + Case Board deduction) → Experimentation (station minigame) → Trial (flag `Trial_<id>`) → Exam (harder minigame, opened from the trainer's dialogue) → Recognition (talk; Signal `acq_<path>_recognized`).
- `QuestService`: reward `Affinity` (sets the path once, only if none; banner + `Acquired_<Path>` flag) and `Training = {[Source] = mult}`.
- `StoryLogic`: conditions `NoAffinity`, `SavedAffinity` (the saved path, ignoring Studio's test affinity), `Quest.Is = "NotActive"`.
- `TrialService` (new) + `Rensei.Trials`: arenas are parts tagged `RenseiTrial` with `TrialId`; one run per arena per player; foe via `EnemyService.Spawn`; hazard patterns Flame (rings + burn), Ice (frost rings + Freeze), Earth (rockfall + tremor band), Wind (gust lanes + push), Metal (cleave lines); an "opening" after each hazard (`GuardDown`, `DamageTakenMult`). Win = foe down (owner only); fail = owner knocked, timed out, or out of the arena for 6 s; a hint after two fails.
- `TrainingService` (new) + `Rensei.Training`: lessons (exam-grade minigame, once a day each) and exercises (timed drill with the discipline's animation, 6 a day) → `AddTraining(..., Active = true)`. A use only counts when it paid; at the stage cap the trainer says only the Gate opens the next stage.
- `AlchemyMinigames` (shared rules, server + client) + `AlchemyMinigameUI`: kinds `ReactionControl` (Flame), `PhaseSequence` (Ice), `LoadPaths` (Earth), `PressureRouting` (Wind), `MaterialMatch` (Metal). Each has `New` / `Check` (returns a reason the player sees) / `Solve` (tests only). `MinigameService` refuses to open in combat (the client can't show a menu then).
- Content: `Dialogues` (five trainers), `Investigation`, `Evidence` (+ Research Notes), `Minigames`, `TuningConfig.Enemies` (trial foes).

## 4. Phases

1. Audit and plan (this document).
2. Foundation: rewards, conditions, dialogue actions, TrialService, TrainingService, training sources.
3. Flame vertical slice: site, dialogue, quest, ReactionControl, trial, exam, acquisition, training; full playtest.
4. Ice, Earth, Wind, Metal on the same framework, each with its own minigame and trial pattern.
5. Research Notes, revisits, mastery activities.
6. End-to-end test, cleanup, documentation.

## 5. Verification (Studio Play, Ye, 2026-10-16/17)

Each run snapshotted the test player's save first and restored it after; the temporary test hook has been removed.

| | Act I | Act II | Act III | Trial | Exam | Recognition | Mentor |
|---|---|---|---|---|---|---|---|
| Flame | ✓ | ✓ 4 clues, wrong + right deduction | ✓ fail reason, pass | ✓ guarded ×1, opening ×1.35 | ✓ | ✓ path saved, +1 MP, EXP | lesson +40 TP once a day; exercise +12 TP |
| Ice | ✓ | ✓ | ✓ | ✓ shell ×0.3, cracked ×1.4, Freeze | ✓ | ✓ | lesson +40 TP |
| Earth | ✓ | ✓ | ✓ soft-ground fail | ✓ rockfall + tremor, opening ×1.3 | ✓ | ✓ | exercise +12 TP |
| Wind | ✓ | ✓ | ✓ | ✓ gust push, opening ×1.35 | ✓ | ✓ | research + Gate nodes |
| Metal | ✓ | ✓ | ✓ | ✓ armour ×0.25, joints ×1.5 | ✓ | ✓ | research + Gate nodes |

Also checked: another trainer refuses a student with a saved path ("other") or with another acquisition in progress ("busy"); all 15 minigame definitions solve and pass 20/20 random seeds; no public minigame data has sparse arrays; clean server boot with no script errors.

**Fixed during testing:** the minigame could open during combat and be dropped by the client without a word (now refused with a message); Earth's soft-ground columns showed as rock (a sparse table lost its keys over the remote); the Wind panel's rules line was covered by the valve tree; Metal's pickers were too small for touch; doubled "(optional)" labels; Flame/Ice `Solve` returned a bare move list.

## 6. Not built / for the owner

- Practical exams (real alchemy casts at mechanisms) — designed, not built.
- Real map placement: the five sites and arenas are graybox folders under `World.Map`, easy to move.
- Respec / second discipline: not allowed; `Acquired_<Path>` flags record history if that changes.
- All numbers (TP, EXP 600, foe stats, hazard damage, time limits) are PROPOSALS.
- The Tutorial place doesn't have these systems (Ye only, by design).

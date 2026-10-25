# Reputation in Investigations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Every implementer gets the **Global Constraints** and the **Facts** below together with its own task.

**Goal:** the owner's Backlog item (`Backlog.md:43`): "Expand reputation system to affect NPC's in investigations. (some will lie to you or just refuse to tell you the truth, or some evil NPC's will spill secrets easier, etc.)". When this plan is done:
- a townsperson asked for a clue answers by their **disposition** toward the player: faction standing, a match of natures (Temper against conduct), Heat and Wanted, what they can tell of who the player is, and what they saw the player do;
- they tell the **truth**, **evade**, **refuse**, **lie** (false evidence that can mislead the Case Board) or **spill** something extra;
- the player can **persuade**, **bribe** or **intimidate**, call on an **informant**, or hide behind a **mask or guise**, and can simply **come back later**;
- every lie is caught, by contradicting evidence or by the Case Board, and the liar then gives the truth: **no quest can soft-lock**;
- `lm_ridge`, `lm_mine` and `foundry_ledger` opt in, and play **exactly as today at neutral reputation**.

Both places get the same code. Nothing is published.

**Spec:** `Documents/specs/2026-10-25-reputation-investigations-design.md`. Its §2 is the audit (findings A1–A10, B1–B6, C1–C13, with file:line evidence) and §11 lists the decisions taken without the owner (D1–D24). Every number, name and line in it, and here, is **PROPOSAL** unless it quotes the owner.

**When to start:**
- **After** the gun rework, the swimming revamp, assassinations, stealth missions, consequences for wrong guesses and the Nemesis system, in the owner's order (`Backlog.md:10`). §"Shared files" says what each of them shares with this plan.
- `sync.py`'s `--backup` option comes from whichever of the gun and swim plans ran first. This plan only adds pairs.
- `Documents/CLAUDE.md` asks for approval before scripts are rewritten. The owner's overnight go-ahead (Backlog, 2026-10-25) covers planning only. **The controller confirms the owner has seen the spec, and answered decision D1 (the dialogue box for levers), before Task 3**, the first behaviour change. Tasks 1–2 change nothing a player can see.

**Architecture:** five stages.
1. **Parity** (Task 1): every script this plan touches is a manifest pair, equal to Studio in both places.
2. **Pure rules** (Task 2): `Rensei.Testimony`: the score, the bands, patience, exposure, the Case Board's stand-in view, the bribe price, the persuade check and `Validate`.
3. **The server** (Tasks 3–5): `TestimonyService` answers opted-in clue lines from `TownsfolkService.Talk`; the levers through `DialogueService.Ask`; the Case Board's stand-ins and doubts in `InvestigationService.Deduce`.
4. **The Journal and the content** (Tasks 6–7): the evidence ledger's new lines; the three quests opt in, with Ivo Marchbank as the new optional teller.
5. **The close** (Tasks 8–9): both places' sweep, then the docs and the one Changelog entry.

**Tech Stack:**
- Roblox Studio Luau, through `Art/Tools/rbxc.py`.
- Python 3.14 (stdlib only), only for `sync.py --check` and `test_sync.py` (unchanged by this plan).

---

## Facts (read from the repo at `0415f18`, 2026-10-25; Task 1 confirms them in Studio)

**Places and windows:**
- **Ye:** placeId 106992859583940, window "[CLOSED TESTING] Rensei".
- **Foundry:** placeId 109591196441030, window "Foundry Yard".
- Get each window's `studio_id` from `python -I Art/Tools/rbxc.py studios`.
- Never touch the window "bloodydeadpool53's Place".

**The talk path today** (`Scripts/ServerScriptService/TownsfolkService.lua`; these lines are the same at HEAD and in the working tree on 2026-10-25):
- `Talk(Player, Id)` is at :408-458. Its order: calm (:410), range TalkRange 10 + TalkMargin 4 (:414), cooldown 0.5 s (:416), the quest's "Talk" signal (:420), `OnClue` (:424-430), the greeting tier from **place** standing (:432-436), rumours (:438-440), `TownsfolkLogic.NextTalk` (:444), a private `Say` for Rumour and Clue (:446-447), the clue's evidence (:449-452), then its signal (:453-456). It returns `Text, Kind`.
- The client gets only text: `Remotes.TownsfolkSay:FireClient(Player, Rig, Text, Seconds)` (:63, :369; `Art/Studio/Regions/TownsfolkClient.lua:5`).
- Rigs carry `TownsfolkId` (:754). `OnHit` (:587-597) notes the last player to hit (`F.LastBy`). The talk rotation is in memory (`F.Talks`, :441-443).
- **Another agent had uncommitted edits in this file on 2026-10-25** (Foundry Task 4b fix round: `Retry`, the backoff reset, from :326). Task 1 checks they are committed and synced before anything here edits the file.

**The data:**
- Clue lines: `Townsfolk.lua` Ned Harrow :54-59 (`lm_ridge`), Bess Kettering :48-53 (`lm_mine`), Edmund Rusk :116-121, Sella Marsh :122-127, Aldous Merriweather :160-165 (`foundry_ledger`, each with `Evidence`). Ivo Marchbank (`fy_yard_l`) :152-155 has no clue.
- `foundry_ledger_who` needs all five ledger evidence (`Investigation.lua:309-320`, Requires :312). `lm_ridge` and `lm_mine` are one stage, no deduction (`Quests.lua:60-87`).
- `Deeds.lua` requires nothing today. `Evidence.lua` defs are `{Quest, Title, Text}`.
- Factions present: Foundry region `{Foundry, Townsfolk}`, State law; Lindenmoor `{Townsfolk, Circle}`, Militia law (`Regions.lua:42-43, 50-51`).

**The services this plan uses, unchanged:**
- `Reputation.PlaceStanding(M, Deeds, Region)` (`Reputation.lua:51-63`); the global cache `M.Standing` (`MoralityService.lua:62, 143`); `Factions.TierOf`, `Word`, `RankOf` (`Factions.lua:64-89`); `Heat.WantedOf(M.Heat, J, Now)` (`Heat.lua:46`); `Regions.Present`, `Regions.Regions[R].Jurisdiction`.
- `MoralityService.Record(Player, DeedId, Quiet, Ctx)` with `Ctx.Witness = true` and `Ctx.Region` (:94-159); its `Recorded` listeners get `Info.Witnesses.Npcs` (:73-76, :156-157).
- `ProgressionService.SpendMoney(Player, Amount)` returns false and takes nothing when the player can't pay (:129-136).
- `StoryService.GiveEvidence` (:45-57) and `SetFlag` (:28).
- `HeatService.Wanted(Player, J)` and `Value` (:46-47).

**The scripts this plan changes.** Repo path first, then the Studio path; Task 1 confirms each. "Pair" = already in `sync_manifest.json`.

| Label | Repo | Studio | Task |
|---|---|---|---|
| `Rensei.Testimony` | `Scripts/ReplicatedStorage/Modules/Data/Rensei/Testimony.lua` | `ReplicatedStorage/Modules/Data/Rensei/Testimony` | new (2) |
| `Rensei.Deeds` | `.../Data/Rensei/Deeds.lua` | `ReplicatedStorage/Modules/Data/Rensei/Deeds` | 4 (pair) |
| `Rensei.Evidence` | `.../Data/Rensei/Evidence.lua` | `ReplicatedStorage/Modules/Data/Rensei/Evidence` | 7 (pair) |
| `Rensei.Townsfolk` | `.../Data/Rensei/Townsfolk.lua` | `ReplicatedStorage/Modules/Data/Rensei/Townsfolk` | 7 (pair) |
| `Rensei.Investigation` | `.../Data/Rensei/Investigation.lua` | `ReplicatedStorage/Modules/Data/Rensei/Investigation` | 5, header comment only (pair) |
| `UI.JournalUI` | `Scripts/ReplicatedStorage/Modules/UI/JournalUI.lua` | `ReplicatedStorage/Modules/UI/JournalUI` | 6 (Task 1 adds) |
| `RenseiServer.TestimonyService` | `Scripts/ServerScriptService/TestimonyService.lua` | `ServerStorage/RenseiServer/TestimonyService` | new (3) |
| `RenseiServer.TownsfolkService` | `Scripts/ServerScriptService/TownsfolkService.lua` | `ServerStorage/RenseiServer/TownsfolkService` | 3 (pair) |
| `RenseiServer.StoryService` | `Scripts/ServerScriptService/StoryService.lua` | `ServerStorage/RenseiServer/StoryService` | 3 (Task 1 adds) |
| `RenseiServer.DialogueService` | `Scripts/ServerScriptService/DialogueService.lua` | `ServerStorage/RenseiServer/DialogueService` | 4 (Task 1 adds) |
| `RenseiServer.InvestigationService` | `Scripts/ServerScriptService/InvestigationService.lua` | `ServerStorage/RenseiServer/InvestigationService` | 5 (Task 1 adds) |
| `RenseiServer.ServerHandler` | `Scripts/ServerScriptService/ServerHandler.server.lua` | `ServerStorage/RenseiServer/ServerHandler` | 3 (pair) |
| `RenseiTests.Test_Testimony`, `TestimonyKit`, `Play_Testimony` | `Scripts/ServerStorage/RenseiTests/<X>.lua` | `ServerStorage/RenseiTests/<X>` | new (2, 3) |
| `RenseiTests.Play_FoundryLedger` (Foundry only), `Play_LindenmoorData` (Ye only), `Play_Townsfolk` (Ye only), `Play_Clue`, `Play_QuestEngine` | `Scripts/ServerStorage/RenseiTests/<X>.lua` | `ServerStorage/RenseiTests/<X>` | 7, regressions (pairs) |

**Read-only, not changed:** `MoralityService`, `RumourService`, `WitnessService`, `HeatService`, `IdentityService`, `ProgressionService`, `QuestService`, `PerceptionService`, `TownsfolkLogic`, `StoryLogic`, `Reputation`, `Factions`, `Heat`, `Regions`, `Quests`, `Dialogues`, `DialogueUI` (it already greys a locked choice, `DialogueUI.lua:145-147`), `PromptUI`, `TownsfolkClient`.

---

## Global Constraints

**Owner rules:**
- "Do not publish the Roblox game or modify live player data."
- "Do not expose API keys, credentials, private player data, or other secrets."
- "Do not blindly copy another game's code or assets."
- **UI:** use only the game's existing UI assets. Bubbles are TownsfolkClient's; levers use the existing dialogue box (`DialogueService.Ask` → `DialogueUI`); hints are the existing Toast; the Journal gains text lines in its existing MenuKit panels. No new images, fonts, sounds or ScreenGuis, and no `StarterGui` edits.
- **Names and lines:** every line of speech, evidence title and deed text is original and PROPOSAL. No new townsperson is added (Ivo Marchbank already exists).
- **Never a dead end** (morality proposal §2.7): reputation changes the route to the truth, never whether the quest can finish. Every task that touches answers keeps the spec's §4.3 rules.

**Labels and records:**
- Label every invented number and name **PROPOSAL** in code comments and docs.
- No task writes a Changelog entry except Task 9, which writes one entry for the whole plan.
- Implementers report to the controller in their final message.
- Implementers never dispatch subagents and never write under `.superpowers/`: the harness refuses it.

**Studio bridge:**
- Run Luau with `python -I C:/Users/Owner/Rensei-Game-Design/Art/Tools/rbxc.py luau "placeId: <id>" <Edit|Server|Client> @file.lua`.
  - Only the first return value prints, cut at 30,000 characters.
  - For a longer return, write it to a StringValue in ServerStorage, read it back in 25,000-character chunks, and delete it.
  - If `Client` isn't accepted by rbxc, client checks run as a TEMP LocalScript (the gun plan's Task 7 pattern).
- **Studio state:** `rbxc.py call get_studio_state '{"studio_id":"<id>"}'`.
- **Play:** `rbxc.py call start_stop_play '{"is_start":true|false,"studio_id":"<id>"}'`.
- **Foundry quirk:** rbxc sometimes returns "Target is not reachable (DMN_ID_EDIT)" even though the call ran. Before retrying anything that isn't idempotent, read the state the call would have changed.
- Never touch the Studio window "bloodydeadpool53's Place".
- Put scratch files in `C:/Users/Owner/AppData/Local/Temp/claude/C--Users-Owner/ecd4cd55-01de-4070-9638-cb228809b769/scratchpad/rep-investigations-plan/`.

**Play** is hooked and protected, because Play writes the owner's REAL save.

- **One Play session at a time across Ye and Foundry.** Before Play:
  - `get_studio_state` must show the **other** place in Edit;
  - Ye's `game.ServerStorage:GetAttribute("PlayLock")` must be nil.
- **The order, every session:**
  1. **Lock.** In Ye (Edit), `game.ServerStorage:SetAttribute("PlayLock", "<Ye|Foundry>:rep<task>")`. When playing Foundry, set the same attribute in Foundry too.
  2. **Hook.** In the playing place (Edit), run `C:/Users/Owner/.claude/jobs/0c39df78/tmp/blender/hook.lua`. Then install the dump helper: `rbxc.py luau "placeId: <id>" Edit @Art/Studio/Regions/Foundry/data/dumphelper.lua`. It returns "dump helper installed".
  3. **Start Play.** In the Server data model, wait until `game.ServerStorage:GetAttribute("LMSnapTaken")` is set. Then:
     - take the dump: `return game.ServerStorage:WaitForChild("LMQuestDump", 30):Invoke()`. Save it to the scratch folder as `quests_rep<task>_1.txt`;
     - **and the probe** (Server), written as one line to `probe_rep<task>_1.txt`: the player's `Data.Money`; every `Data.Morality.Deeds` entry whose id is `bribed_witness` or starts with `intimidated_`; `Data.Morality.Heat` (each jurisdiction's `Value` and `At`); every `Data.Story.Flags` key that starts with `Doubt_`; and `Data.Story.Evidence` for the six evidence ids Task 7 adds. These tests spend money, record deeds, raise Heat, set flags and give evidence in the real save.
  4. **Suites.** Run them with `game.ServerStorage.LMRunSuite:Invoke("<Suite>")` (Server).
  5. **Put the character back.** Every test that moves the real character restores its CFrame and its `Masked` and `Guise` attributes before it returns (`TestimonyKit.Clean`).
  6. **Restore.** Run `game.ServerStorage.LMTestHook:Invoke("restore")` (Server). It must return "restored".
     - Dump again (`quests_rep<task>_2.txt`). It must equal the first dump character for character.
     - Probe again (`probe_rep<task>_2.txt`). It must equal the first probe.
     - `LMTestHook:Invoke("diff")` may list only the known encode-quirk keys (Settings, Story, Morality). **Any other key**, or a dump or probe that differs, means stop: keep Play running and report both dumps, both probes and the diff to the controller.
  7. **Stop** Play.
  8. **Unhook.** In Edit, run `C:/Users/Owner/.claude/jobs/0c39df78/tmp/blender/unhook.lua`. Then remove the helper: copy `dumphelper.lua` to the scratch folder, set its MODE line to `"remove"` there (only that line), and run the copy in Edit. It returns "removed <n>".
  9. **Unlock.** Only then, clear PlayLock in both places.
- **Test townsfolk:** every server test talks to **townsfolk it spawned itself** with `TestimonyKit.Spawn` (a temporary RenseiPost on a floor at y 300, Play_Townsfolk's fixture pattern, `TownsfolkService.Despawn` after), except Task 7's content suites, which talk to the real tellers as `Play_FoundryLedger` and `Play_LindenmoorData` already do.
- **A neutral reputation is set, never assumed.** Any test that expects a particular answer sets `Data.Morality` to a crafted copy first (`TestimonyKit.WithMorality`) and puts the real one back after, because the owner's real standing could be anything.
- **Script edits are refused while Play runs.**
- **In Play, the world is a copy.** Instance changes made in Play vanish at Stop. Save data is real: the hook's restore puts it back.
- **Edit's require cache.** Edit keeps a module's result between `execute_luau` calls. Every suite here runs **in the Play VM** (`LMRunSuite`), because each requires a module this plan changes.

**Scripts live in both places.**
- Every script is edited in the repo first, then set into **both** places with the sync tool:
  ```
  python -I Art/Studio/Regions/Foundry/data/sync.py --place ye|foundry --backup Pre-RepInvestigations_2026-10-25 --only <label>[,<label>...] --run
  python -I Art/Studio/Regions/Foundry/data/sync.py --place ye|foundry --check
  ```
- **Start every task that touches a script with `--check` in both places.** If anything differs, stop and report: another plan's work may not be synced yet, and syncing over it would lose it.
- `--check` must print `DIFFER 0 / MISSING 0` for **both** places at the end of every task that touched a script.
- Each task adds its own pairs to `Art/Studio/Regions/Foundry/data/sync_manifest.json` (the Foundry plan's Task 1 format). Places are both, except the suites marked Ye-only or Foundry-only in the Facts.
- **Backups:** with `--backup Pre-RepInvestigations_2026-10-25`, the tool clones a script once, before its first change in this plan, into `ServerStorage.RenseiBackups["Pre-RepInvestigations_2026-10-25"]` in that place. **Never sync this plan's scripts without `--backup`:** the older folders already hold older copies of some of them.
- **The normalised hash** (Studio == repo means these strings are equal) is `sync.py`'s `norm_hash`, as in the Foundry plan's Global Constraints.
- **Packages:** `Modules` and `RenseiServer` are packages. Syncing changes both places' package copies. Publishing them is the owner's (Task 9's checkpoint).

**Tests:**
- **RED then GREEN.** Every new check is run once where it **must fail** (before the change, or against a control that keeps today's rule), and fails. Then it passes after.
- **A check that cannot fail is not a check.** Never pick an input by reading the property under test. **Expected answers, scores and prices are written by hand in the test**, never read from `Rensei.Testimony` at check time. (Example: "Distrusted with weight 1 and nothing else gives −20 and Evasive" is written as the numbers −20 and "Evasive".)
- **No duplicated test logic.** Shared helpers live in `RenseiTests.TestimonyKit` (Task 3), required, never copied. If an earlier plan already made a shared townsfolk fixture kit, `TestimonyKit` requires it instead of repeating it.
- When a check fails, fix the cause in the task that owns it (the controller rules), never by loosening the check.

**Publish order** (`Documents/World Travel.md` §10):
1. packages from Ye (Modules, RenseiServer);
2. Foundry's packages updated by hand and checked with `sync.py --check`;
3. the places;
4. Migrate to Latest Update last.

This plan never publishes.

**Git:**
- Commit by path only: `git commit -m "<msg>" -- <paths>`. New files need `git add -- <path>` first. Never `git add -A`.
- Never stage `.blend` or `.blend1` files or `Art/Blender.rar`.
- End every commit message with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Implementers don't push.

---

## Shared files with the plans before this one

This plan runs **after** all of them. The rule for each shared file: run `--check` first, edit the repo file (which already holds the earlier plans' changes), sync, `--check` again. Never sync an older copy.

| File | Gun rework | Swimming revamp | Assassinations | Stealth missions *(no plan yet)* | Wrong-guess consequences *(no spec or plan yet)* | Nemesis *(no plan yet)* | This plan |
|---|---|---|---|---|---|---|---|
| `sync.py`, `test_sync.py` | Task 1: `--backup` (or swim) | Task 1: `--backup` (or gun) | — | ? | ? | ? | uses `--backup` only |
| `sync_manifest.json` | pairs | pairs | pairs | pairs | pairs | pairs | pairs (append only) |
| `ServerHandler.server.lua` | Task 5: `PositionHistory` start | — | Task 7: `TakedownService` start | likely a contract service start | ? | likely `RivalService` start | Task 3: one `TestimonyService.Start()` line, at the end of the start list |
| `Rensei/Deeds.lua` | — | — | Task 6: `assassinated_bandit` | likely mission deeds | ? | `killed_rival`, `spared_rival`, `turned_rival` (spec §7) | Task 4: `bribed_witness`, `intimidated_<Faction>`, and `require(Factions)` at the top |
| `TownsfolkService.lua` | — | — | read-only (takedowns refuse townsfolk) | ? | ? | **Talk**: the rival's warning rumour joins the rotation (N3) | Task 3: the clue branch of **Talk**, and one line in `OnHit`. **Also the Foundry Task 4b fix round** (uncommitted on 2026-10-25). |
| `InvestigationService.lua` | — | — | — | ? | **Deduce**'s wrong branch (its consequences) | — | Task 5: Deduce's `Requires` view and its wrong branch. Whichever lands second calls both. |
| `StoryService.lua` | — | — | — | ? | possibly | — | Task 3: one pcall line in `GiveEvidence` |
| `DialogueService.lua` | — | — | — | ? | — | — | Task 4: `Ask`'s optional `Locked` list |
| `UI/JournalUI.lua` | — | — | — | ? | possibly (the Case Board's wrong answers) | the Rivals page (N8) | Task 6: evidence sources, the "doesn't add up" line, exposed lies off the cards |
| `Rensei/Evidence.lua`, `Townsfolk.lua` | — | — | — | possibly (contract evidence; fixers) | — | possibly (informant townsfolk) | Task 7: new defs; `Temper` and clue variants |
| Character attributes `Masked`, `Guise` | — | — | — | **sets `Guise`** (disguises, M4) | — | rivals see through them (spec §5.5) | Task 4: **reads** them (spec §3.4, decision D17) |
| `RivalService.Informants(Player)` | — | — | — | — | — | **provides it** (N7) | Task 4: reads it if it exists |
| `Changelog.md`, `Backlog.md`, `Region Builder.md` | Task 12 | Task 10 | Task 12 | ? | ? | ? | Task 9 (Region Builder.md §6 in Task 7) |

- **Stealth missions, wrong-guess consequences and Nemesis** had no implementation plans when this was written. Before Task 1, **the controller reads whatever plans they have by then** and updates this table; their changes to `Talk`, `Deduce` and `JournalUI` decide where this plan's lines go.
- If the stealth plan named its disguise attribute differently, Task 4 reads that name and the spec's §3.4 is updated to match. If wrong-guess consequences exposes a "clam up" timer (spec §7.1), Task 5 reads it.

---

## Decisions taken without the owner, by task

The owner was asleep (overnight go-ahead, 2026-10-25). Each is a PROPOSAL, listed in the spec's §11, and built so the owner can change it by a number in `Rensei.Testimony` or a line in the data.

| | Decision (PROPOSAL) | Task |
|---|---|---|
| D1 | **Answered: yes (owner, 2026-10-25).** Levers use the existing dialogue box (`DialogueService.Ask`) on a second talk after an evasion or refusal. This bends the owner's 2026-10-23 "no reply choices" choice (`Changelog.md:598`) for this one moment. **The controller gets the owner's answer before Task 3.** If no, Task 4 offers the levers as hold-prompts instead. | 4 |
| D2 | `Text` stays the Truth line; no separate `Truth` key | 2, 7 |
| D3 | Deterministic answers, no dice | 2 |
| D4 | The bands and every term's numbers | 2 |
| D5 | NPC nature is `Temper` (Mercy, Candor, Order, −1/0/+1); "evil" = Ruthless and Deceitful | 2, 7 |
| D6 | Factions absent from the NPC's region count at half weight from the global standing | 2 |
| D7 | What an NPC saw, patience, lever offers and cooldowns live in server memory; no save schema change | 3, 4 |
| D8 | Patience: 10 minutes moves a refusal or evasion one band friendlier, up to two, skipping Lie | 2, 4 |
| D9 | A lie signals the objective; an evasion or a refusal doesn't | 3 |
| D10 | An unexposed lie stands in for its truth in deduction `Requires`; an exposed one doesn't; exposed lies leave the cards | 2, 5, 6 |
| D11 | A wrong deduction with a lie in a slot exposes the lie | 5 |
| D12 | Lies can't be bought or bullied out; only exposure gets the truth | 4 |
| D13 | Bribe 50 Money (×2 after a refusal, ×0.5 for Candor −1; Candor +1 won't take it); `bribed_witness` | 2, 4 |
| D14 | Intimidate: `intimidated_<Faction>` deeds, Crime 10; not offered against the Authority | 4 |
| D15 | Persuade: global standing Trusted, or Honest, or Trust 15 | 2, 4 |
| D16 | One lever result per NPC per player per 10 minutes | 4 |
| D17 | `Masked` and `Guise` character attributes are the contract for masks and disguises | 4 |
| D18 | `lm_ridge` and `lm_mine`: Evasive, Refuse and Spill, no Lie | 7 |
| D19 | Marsh is `foundry_ledger`'s only liar | 7 |
| D20 | Ivo Marchbank becomes an optional teller (the "evil NPC") | 7 |
| D21 | Five spill evidence and one false evidence | 7 |
| D22 | The lever hint is a toast the first time a witness evades or refuses | 3 |
| D23 | A newcomer who replaced a dead liar gives the Truth line on exposure | 3 |
| D24 | Dialogue-tree NPCs are unchanged | — |

---

## File map

| File | Responsibility | Task |
|---|---|---|
| `Art/Studio/Regions/Foundry/data/sync_manifest.json` | This plan's pairs | 1 (pairs added in every task) |
| `Rensei/Testimony.lua` (new), `RenseiTests/Test_Testimony.lua` (new) | The pure rules and their tests | 2 |
| `ServerScriptService/TestimonyService.lua` (new), `TownsfolkService.lua` (Talk, OnHit), `StoryService.lua` (`GiveEvidence`), `ServerHandler.server.lua`; `RenseiTests/TestimonyKit.lua`, `Play_Testimony.lua` (new) | Answers on the server, exposure, memory | 3 |
| `DialogueService.lua` (`Ask`, `Choose`), `Rensei/Deeds.lua`, `TestimonyService.lua`, `Play_Testimony.lua` | The levers, patience, masks, guises, informants | 4 |
| `InvestigationService.lua` (`Deduce`), `Rensei/Investigation.lua` (header comment), `Play_Testimony.lua` | The Case Board | 5 |
| `UI/JournalUI.lua`, `Art/Studio/Testimony/client_checks.lua` (new) | The Journal's lines | 6 |
| `Rensei/Evidence.lua`, `Rensei/Townsfolk.lua`, `Documents/Region Builder.md` §6; `RenseiTests/Play_FoundryLedger.lua`, `Play_LindenmoorData.lua`, `Test_Testimony.lua` | The three quests opt in | 7 |
| (no new files) | Both places' sweep | 8 |
| `Documents/Changelog.md`, `Backlog.md`, `Decisions.md` | Docs | 9 |

All `Rensei/` paths are `Scripts/ReplicatedStorage/Modules/Data/Rensei/`. `UI/` is `Scripts/ReplicatedStorage/Modules/UI/`. `RenseiTests/` is `Scripts/ServerStorage/RenseiTests/`. Bare service names are under `Scripts/ServerScriptService/`.

---

### Task 1: Parity and the pairs

**Files:**
- Modify: `sync_manifest.json` (four pairs).
- Studio: nothing is changed.

**Interfaces:** the four pairs, `Places: ["ye", "foundry"]`, `Create: false`:
- `RenseiServer.StoryService`, `RenseiServer.DialogueService`, `RenseiServer.InvestigationService` (`ServerStorage/RenseiServer/<X>`, repo `Scripts/ServerScriptService/<X>.lua`);
- `UI.JournalUI` (`ReplicatedStorage/Modules/UI/JournalUI`, repo `Scripts/ReplicatedStorage/Modules/UI/JournalUI.lua`).

New files get their pairs in the task that creates them, so `test_sync.py`'s "every Repo file exists" check stays green.

- [ ] **Step 1: The other plans.** Read the plans that now exist for stealth missions, wrong-guess consequences and Nemesis, and update §"Shared files" and the Facts' line numbers where they moved. Report the changes to the controller.
- [ ] **Step 2:** `sync.py --check` in both places. Expected: `DIFFER 0 / MISSING 0`. **In particular `RenseiServer.TownsfolkService` must be SAME**: the Foundry Task 4b fix round (uncommitted on 2026-10-25) is committed and synced. If anything differs, stop and report.
- [ ] **Step 3:** Add the four pairs. Run `test_sync.py` (all pass), then `--check` in both places. Expected: the four new pairs SAME in both places (Studio already holds the repo's copies). A DIFFER here means Studio and the repo disagree on a script this plan will edit: stop and report.
- [ ] **Step 4: Read-only confirmation in Edit, both places** (one Luau each, returning a compact table):
  - `Remotes.TownsfolkSay` exists;
  - `DialogueUI` (the client module) contains the string `P.Locked` (it greys locked choices);
  - `ServerStorage.RenseiServer` holds `TestimonyService`? Expected **no** (it's new);
  - `ReplicatedStorage.Modules.Data.Rensei.Testimony`? Expected **no**.
- [ ] **Step 5: Commit** the manifest: `"Rep investigations Task 1: pairs for the services and the Journal this plan edits"`.

---

### Task 2: The pure rules (`Rensei.Testimony`)

**Files:**
- Create: `Rensei/Testimony.lua`, `RenseiTests/Test_Testimony.lua`.
- Modify: `sync_manifest.json` (`Rensei.Testimony`, `RenseiTests.Test_Testimony` with `Create: true`, Places both).

**Interfaces.** A pure module: no Instances, no services. It requires `Factions`, `Reputation`, `Heat`, `Regions` and `Deeds` (none requires it back). Every number is a PROPOSAL constant at the top, with a comment naming the spec section.

```lua
Testimony.TierPoints = {Hostile = -40, Distrusted = -20, Neutral = 0, Trusted = 20, Honoured = 40}
Testimony.AbsentWeight = 0.5          -- a faction not present in the NPC's region: global standing, half weight (D6)
Testimony.Kin = 10                    -- per shared / clashing lean; doubled at Renown "Known" or higher
Testimony.HeatLaw, Testimony.HeatOutlaw, Testimony.HeatCircle = -10, 5, -10   -- per Wanted level
Testimony.HeardLaw, Testimony.HeardOutlaw, Testimony.HeardCap = -5, 3, 15     -- per crime deed known in the region
Testimony.WitnessCrime, Testimony.WitnessCap, Testimony.HitMe = -15, 30, -25
Testimony.Informant, Testimony.Masked, Testimony.Guise = 20, -10, 20
Testimony.Bands = {Spill = 40, SpillCrook = 20, Truth = -15, Evasive = -35, Lie = -60}  -- the lowest score of each
Testimony.PatienceSeconds, Testimony.PatienceSteps = 600, 2
Testimony.VisitSeconds, Testimony.LeverWindow, Testimony.LeverCooldown = 300, 60, 600
Testimony.Bribe = {Base = 50, AfterRefuse = 2, Crook = 0.5}
Testimony.Persuade = {Standing = "Trusted", Trust = 15}
```

| Function | Contract |
|---|---|
| `OptedIn(Clue) -> bool` | `type(Clue) == "table" and type(Clue.Disposition) == "table"` |
| `Temper(NpcDef) -> {Mercy, Candor, Order}` | each −1, 0 or 1 (missing or out of range = 0) |
| `Inputs(Data, NpcDef, Region, Now, Extra) -> Inputs` | Reads only `Data.Morality` (`Places`, `Standing`, `Conduct`, `Trust`, `Renown`, `Heat`, `Deeds`). `Extra = {Witnessed = {[DeedId] = count}, HitMe = bool, Informant = bool, Masked = bool, Guise = FactionId or nil}`. |
| `Score(Inputs, NpcDef, Clue) -> Score, Terms` | `Terms = {Standing, Kinship, Heat, Heard, Witnessed, Informant, Identity}`, each a number; `Score` is their sum clamped to −100..100 (spec §3.2, §3.4). |
| `Outcome(Score, NpcDef, Clue, Softened) -> "Spill" \| "Truth" \| "Evasive" \| "Lie" \| "Refuse"` | Spec §4.1, with the fallbacks (a missing variant falls friendlier), Candor +1 never "Lie", `Clue.Disposition.Bands` overriding, `Never = {...}`. `Softened` (0–2) moves Refuse/Evasive that many bands friendlier, skipping Lie (§3.5). |
| `Exposed(Story, EvidenceDefs, LieId) -> bool, By` | true when `Story.Flags["Doubt_" .. LieId]` is set (`By = "Doubt"`), or the player holds any id in `EvidenceDefs[LieId].False.Contradicts` (`By` = that id) |
| `CaughtDue(Story, EvidenceDefs, Clue) -> bool` | the clue has a `Lie`; the player holds `Clue.Lie.Evidence`, it is exposed, and the player doesn't hold `Clue.Evidence` |
| `DeduceView(Data, EvidenceDefs) -> View` | a shallow copy of `Data` whose `Story.Evidence` also holds `False.Truth` for each held, **unexposed** lie. `Data` itself is never changed. |
| `LiesIn(Answers, EvidenceDefs) -> {LieId}` | the false evidence ids among a Deduce request's answers |
| `BribePrice(NpcDef, LastOutcome) -> number or nil` | nil for Candor +1; else `Base`, × `AfterRefuse` if `LastOutcome == "Refuse"`, × `Crook` for Candor −1; `math.floor` |
| `CanPersuade(Data, NpcDef) -> bool, Reason` | global standing tier with `NpcDef.Faction` ≥ Trusted, or `Factions.Word("Candor", …) == "Honest"`, or `M.Trust[NpcDef.Name] >= 15`; `Reason` is a label like `"[Foundry Hands: Trusted]"` |
| `Validate(Rosters, EvidenceDefs, Inspects, Deductions) -> ok, Errs, Bad` | spec §4.3's rules 1–6 for every opted-in clue; `Bad[NpcId] = true` for each clue that breaks one. Rule 1 is checked by computing `Outcome(Score(Inputs(neutral)))`. |

- [ ] **Step 1: Write `Test_Testimony` (RED).** Pure cases, each with hand-written expectations:
  - **Standing:** a Foundry NPC (weight 1) in Foundry with place standing −25 (Distrusted) gives Standing −20; with `Weights = {Foundry = 1, Authority = -0.5}` and a global Authority standing of 65 (Honoured), the Authority part is −0.5 × 40 × 0.5 = −10.
  - **Kinship:** a Ruthless, Lawful player (Conduct Mercy −20, Order 20) and Marsh's Temper (Mercy 1, Order −1) give −20; at Renown 250 (Known), −40; a Ruthless, Deceitful player and Ivo's Temper (−1, −1, −1) give +20.
  - **Heat:** Wanted 2 in State (Heat 60) for an Order 0 NPC in Foundry gives −20; for Ivo (Order −1) +10.
  - **Heard:** four crime deeds known in the region: −15 for an Order 0 NPC (capped), +12 for Ivo.
  - **Witnessed:** two crimes seen: −30; a hit: −25; both: −30 (capped).
  - **Masked** drops Standing, Kinship, Heat, Heard and Witnessed and gives −10; **Guise** `"Foundry"` for a Foundry NPC gives Standing +20 and drops Heat, Heard and Witnessed.
  - **Bands:** scores 40 → Spill, 39 → Truth, −15 → Truth, −16 → Evasive, −36 → Lie, −61 → Refuse (for a clue with every variant and a Candor 0 NPC); a Candor −1 NPC at 20 → Spill; a Candor +1 NPC at −40 → Refuse; a clue with only `Text` and `Disposition` → Truth at every score; a clue with no `Refuse` at −80 → Evasive; Softened 1 at −80 → Evasive; Softened 2 at −80 → Truth; Softened 1 at −40 for a liar → Evasive (Lie skipped).
  - **Neutral:** an empty `Data.Morality` gives Score 0 and Truth.
  - **Exposure:** a held lie with no contradiction held: not exposed; after holding a `Contradicts` id: exposed by it; with `Doubt_<id>`: exposed by "Doubt". `CaughtDue` false once `Clue.Evidence` is held.
  - **DeduceView:** an unexposed lie adds its `Truth` to the view's evidence and leaves `Data.Story.Evidence` untouched; an exposed one doesn't.
  - **BribePrice:** Candor 0: 50; after a Refuse: 100; Candor −1: 25; Candor +1: nil.
  - **CanPersuade:** global Foundry standing 25: true; 10: false with "[Foundry Hands: Trusted]"; Candor conduct 20 (Honest): true.
  - **Validate:** a fixture roster with one broken clue per rule (no neutral truth because of `Bands`; a `Lie` whose evidence has no `False`; `False.Truth` not the clue's evidence; `Contradicts` empty; a `Contradicts` id only given by another lie; a `Spill.Evidence` used in a deduction's `Requires`) reports each in `Bad`; a good clue passes.
  - Run it in the Play VM in **Ye** (PlayLock `Ye:rep2`). Expected: it errors (no `Rensei.Testimony`).
- [ ] **Step 2: Implement** `Testimony.lua`. Sync both pairs to both places.
- [ ] **Step 3: GREEN** in Play in Ye: `Test_Testimony` 0 FAIL. Regressions (unchanged code, sanity): `Test_TownsfolkLogic`, `Test_Reputation`, `Test_Heat`.
- [ ] **Step 4:** `--check` in both places.
- [ ] **Step 5: Commit** `Testimony.lua`, `Test_Testimony.lua` and the manifest: `"Rep investigations Task 2: the pure testimony rules (score, bands, patience, exposure, stand-ins, validate)"`.

---

### Task 3: Answers on the server

**Files:**
- Create: `TestimonyService.lua`, `RenseiTests/TestimonyKit.lua`, `RenseiTests/Play_Testimony.lua`.
- Modify: `TownsfolkService.lua` (`Talk`'s clue branch; one line in `OnHit`; the header comment's Talk paragraph); `StoryService.lua` (`GiveEvidence`); `ServerHandler.server.lua`; `sync_manifest.json` (`RenseiServer.TestimonyService`, `RenseiTests.TestimonyKit`, `RenseiTests.Play_Testimony`: `Create: true`, Places both).

**Interfaces.**

**`TestimonyService`** (server; the only place a disposition is computed):
- `Talk(Player, F, OnClue) -> Took, Text, Outcome`. `F` is the townsperson's record (`Id`, `Def`, `Region`, `Rig`). Called by `TownsfolkService.Talk` only when `Testimony.OptedIn(F.Def.Clue)` and the clue isn't in `Validate`'s `Bad` set.
  - `CaughtDue` (any stage, while the quest is Active): `Took`, the `Caught` line (the Truth line for a newcomer, D23: `F.Def.Name` differs from the name the roster gave), gives `Clue.Evidence`, Outcome `"Caught"`.
  - Else, when `OnClue`: computes `Testimony.Inputs/Score/Outcome` with this player's memory, then:
    - **Truth / Spill:** gives `Clue.Evidence` (and `Spill.Evidence`), then signals `Clue.Signal`, in that order (as Foundry Task 2's rule).
    - **Lie:** gives `Lie.Evidence`, then signals.
    - **Evasive / Refuse:** gives nothing, signals nothing; remembers the refusal time for patience; the first time for this player, a Toast "Talk to them again to press them." (D22).
  - A line that gives nothing new is said **once per visit** (`VisitSeconds`); later talks in the visit return `Took = false`, and `TownsfolkService` falls through to the rotation with `Clue = false`.
  - (Task 4 adds the lever box on the second talk.)
- `NoteHit(Player, NpcId)` (from `TownsfolkService.OnHit`) and a `MoralityService.Recorded` listener that notes each deed against every perceiving NPC whose rig carries `TownsfolkId` (spec §3.3).
- `OnEvidence(Player, EvidenceId)`: for each held lie that `EvidenceId` now contradicts, a Toast "*<Teller>'s account doesn't square with <Title>.*" (once per lie). Also checks at `Talk` time a lie given after its contradiction was already held (immediate exposure, same toast).
- `Handles(Def) -> bool`: `Testimony.OptedIn(Def.Clue)` and `Def.Id` not in the `Bad` set.
- `Memory(Player, NpcId)` (tests); `Forget(Player)`; `SetClock(Fn)` (tests; default `os.time`).
- `Start()`: runs `Testimony.Validate` over `Townsfolk.Regions`, keeps its `Bad` set and warns `TestimonyService: <id>'s clue is not opted in: <reason>` for each (that clue then behaves as today, spec §8); the Recorded listener; `Players.PlayerRemoving` → `Forget`.
- Memory is a plain table keyed by UserId (ARCHITECTURE.md rule), never the save.

**`TownsfolkService.Talk`** (the only change to its flow): after `OnClue` is computed (:424-430) and before the tier:
```lua
-- (Rep investigations Task 3) an opted-in clue line answers by the speaker's disposition (TestimonyService)
local Testimony = require(ServerScriptService.TestimonyService)
if Testimony.Handles(Def) then
	local Took, Line, Outcome = Testimony.Talk(Player, F, OnClue)
	if Took then
		if Line then TownsfolkService.Say(Id, Line, "Clue", {Only = Player}) end
		return Line, "Clue", Outcome
	end
	OnClue = false -- nothing new to say here this visit: the rotation
end
```
- The existing evidence and signal code (:448-456) still serves clues that aren't opted in. **Nothing changes for them.**
- `Talk` now returns a third value, `Outcome`, for tests; existing callers read two.
- `OnHit` gains `pcall(function() require(ServerScriptService.TestimonyService).NoteHit(Player, Id) end)` after `F.LastBy` is set.

**`StoryService.GiveEvidence`:** after the IdentityService line (:54), `pcall(function() require(ServerScriptService.TestimonyService).OnEvidence(Player, Id) end)`.

**`ServerHandler.server.lua`:** at the end of the start list, `require(ServerScriptService.TestimonyService).Start() -- reputation in investigations: witness memory, exposure`.

**`TestimonyKit`:**
- `Spawn(T, Def, Region)`: a temporary post at y 300 and `TownsfolkService.Spawn(Def, Region)`, Play_Townsfolk's fixture pattern; returns the Id and a cleanup.
- `Beside(Id)`: pivots the character within talk range and waits up to 5 s for a calm state.
- `Inject(T, Defs)`: injects evidence, quest, deduction, deed and townsfolk defs into the live tables and removes them after.
- `WithMorality(Player, Spec, Body)`: deep-copies the real `Data.Morality`, builds a crafted one, runs `Body`, and puts the real one back, even on error. Exact numbers come from **test deeds**, not real ones:
  - `Spec.Place = {[Region] = {[Faction] = n}}`: injects `__rep_plus_<F>` / `__rep_minus_<F>` (Standing ±1 for that faction, Local, `Repeat`) with `Count = |n|`, heard in that region by that faction, so `Reputation.PlaceStanding` gives exactly n;
  - `Spec.Global = {[Faction] = n}`: sets the `Standing` cache (any `MoralityService.Record` recomputes it, so only for checks made before a deed is recorded);
  - `Spec.Conduct`, `Spec.Renown`, `Spec.Trust`: set as given (Record only adds to them);
  - `Spec.Heat = {[J] = Value}`: `{Value = n, At = now}`;
  - `Spec.Crimes = {[Region] = n}`: n distinct injected crime deeds known there.
  - The crafted Morality has no live rumours, so no rumour tick rebuilds it mid-test.
- `Clean(Player)`: puts back the character's CFrame and its `Masked` / `Guise` attributes.

- [ ] **Step 1: Write `TestimonyKit` and `Play_Testimony` part 1 (RED).** Injected: a 2-stage quest `__rep_q` (stage 1: Signal `__rep_sig` and Evidence `__rep_true`), evidence `__rep_true`, `__rep_spill`, `__rep_contra`, and a lie `__rep_lie` with `False = {Truth = "__rep_true", Contradicts = {"__rep_contra"}}`. A test townsperson with `Temper = {}` and a clue with every variant. Cases:
  - **`NeutralIsTruth`:** empty Morality → Kind "Clue", Outcome "Truth", the player holds `__rep_true`, the stage is 2.
  - **`NotOptedInIsUnchanged`:** the same clue without `Disposition`, at Hostile → the truth line and evidence, as today (the control that keeps today's rule).
  - **`DistrustedEvades`:** place standing −25 (Distrusted: −20) → Outcome "Evasive", no evidence, stage still 1, a Toast fired once; a second talk after `VisitSeconds` says it again; a talk inside the visit falls to the rotation (Kind "Greeting").
  - **`HostileRefuses`:** place standing −70 (Hostile: −40) and State Heat 100 (Wanted 3: −30) → −70 → "Refuse", no evidence, no signal.
  - **`LieGivesFalseEvidence`:** place standing −70 alone (−40) → "Lie"; the player holds `__rep_lie`, not `__rep_true`; the stage is 2; the bubble's recipients are only the player (`LastRecipients`).
  - **`ExposureToastAndCaught`:** then `StoryService.GiveEvidence(Player, "__rep_contra")` fires the toast; the next talk (stage 2) → Outcome "Caught" and `__rep_true` held.
  - **`AlreadyContradictedLie`:** holding `__rep_contra` first, a lie fires the toast at once.
  - **`SpillWhenHonoured`:** place standing +65 (Honoured: +40) → "Spill", both `__rep_true` and `__rep_spill` held; +25 (Trusted: +20) → "Truth" only.
  - **`WitnessedAndHit`:** `NoteHit` then a talk at neutral: −25 → "Evasive". A recorded crime deed with the test rig in `Witnesses.Npcs` (call the Recorded listener with a built `Info`) → −15 → "Truth"; two → −30 → "Evasive".
  - Run in Play in **Ye** (PlayLock `Ye:rep3`). Expected: every case but `NotOptedInIsUnchanged` FAILs (no TestimonyService).
- [ ] **Step 2: Implement.** Sync `TestimonyService`, `TownsfolkService`, `StoryService`, `ServerHandler` and the tests to **both** places.
- [ ] **Step 3: GREEN in Play in Ye:** `Play_Testimony` 0 FAIL. Regressions: `Play_Townsfolk`, `Play_TownsfolkHurt`, `Play_TownsfolkCrowd`, `Play_Clue`, `Play_QuestEngine`, `Play_LindenmoorData`, `Play_Morality`, `Play_Rumours`, `Play_Heat`. No real clue is opted in yet, so the real clue lines are unchanged.
- [ ] **Step 4: Play in Foundry** (PlayLock `Foundry:rep3`): `Play_Testimony`, `Play_FoundryLedger`, `Play_Clue`, `Play_QuestEngine`: 0 FAIL.
- [ ] **Step 5:** `--check` in both places.
- [ ] **Step 6: Commit** the four scripts, the kit, the suite and the manifest: `"Rep investigations Task 3: opted-in clue lines answer by disposition (truth, evasive, refuse, lie, spill, caught)"`.

---

### Task 4: The levers

**Files:**
- Modify: `DialogueService.lua` (`Ask`, `Show`, `Choose`); `Rensei/Deeds.lua`; `TestimonyService.lua`; `Play_Testimony.lua`; `sync_manifest.json` (none new).

**Interfaces.**

**`DialogueService.Ask(Player, Model, Speaker, Text, Choices, OnAnswer, Locked)`:** `Locked` (optional) is `{[index] = true}`. `Show` sends it (`Session.Inline.Locked[I] == true`) instead of all false (:43-44). `Choose` returns false and keeps the box open for a locked inline index, as a locked tree choice does (:248). With no `Locked`, `Ask` behaves exactly as today.

**`Rensei/Deeds.lua`** (a new block; `local Factions = require(script.Parent.Factions)` at the top):
```lua
-- ===== Reputation in investigations (2026-10-25; PROPOSAL numbers): buying and forcing testimony =====
bribed_witness = {Text = "Paid a witness to talk", Conduct = {Candor = -2}, Scope = "Private", Repeat = {Cap = 10}},
```
and after the table, generated so each faction's standing moves (deed standing is fixed data, spec A7):
```lua
for _, F in ipairs(Factions.Order) do
	Deeds["intimidated_" .. F] = {Text = "Threatened a witness into talking", Conduct = {Mercy = -3, Order = -2},
		Standing = {[F] = -3}, Scope = "Local", Repeat = {Cap = 5}, Crime = 10, HeatCap = 30} -- PROPOSAL
end
```

**`TestimonyService`:**
- **The lever box:** a talk within `LeverWindow` of an Evasive or Refuse line (and no lever result from this NPC in the last `LeverCooldown`) calls `DialogueService.Ask(Player, F.Rig, F.Def.Name, <Text>, Choices, OnAnswer, Locked)` and returns `Took, <Text>, "Levers"`. Before it, if the character has `InCombat` or `CombatMode` (`Ask` has no combat check, spec C9), it says nothing and returns `Took = false`. The choices, in order (spec §5.1; PROPOSAL wording):
  1. Persuade: locked with `CanPersuade`'s reason when it can't work;
  2. Bribe `[<price>]`: shown locked "[Won't take money]" for a Candor +1 NPC; locked "[Needs <price>]" when `Data.Money` is short;
  3. Intimidate: **left out** for an NPC whose faction is `Authority`;
  4. "Never mind."
- **`OnAnswer(Index)`** re-checks everything at answer time (spec §8): talk range, not fighting, the NPC calm, the offer under `LeverWindow`, the lever's own condition, the cooldown. Then:
  - **Persuade:** Truth (Spill if the score would reach the spill line).
  - **Bribe:** `ProgressionService.SpendMoney(Player, Price)`; on false, a Toast "You need <price>." and nothing else. On true: `MoralityService.Record(Player, "bribed_witness")`; Truth, or **Spill** for a Candor −1 NPC.
  - **Intimidate:** `MoralityService.Record(Player, "intimidated_" .. F.Def.Faction, false, {Strength = 1, Region = F.Region})`: the threatened witness is one witness (`WitnessService.Weights.Npc`), so the deed is heard where it happened and Heat and the rumour follow the existing path, whether or not perception has registered the rig (PROPOSAL); a "you threatened me" note (−25, like a hit); Truth.
  - Each sets the lever cooldown. **A clue whose answer was Lie never reaches the box** (D12): the lie has already signalled the stage.
- **Patience:** the outcome's `Softened` is `math.min(PatienceSteps, floor((Now - LastNo) / PatienceSeconds))` from the remembered refusal (`SetClock` makes it testable).
- **Masks and guises:** `Extra.Masked = Character:GetAttribute("Masked") == true`, `Extra.Guise = Character:GetAttribute("Guise")` (a string faction id, or nil) (D17).
- **Informants:** `Informants(Player)` returns `RivalService.Informants(Player)` when `ServerScriptService:FindFirstChild("RivalService")` exists (pcall), else `{}`; `SetInformants(Fn)` replaces it for tests. `Extra.Informant` is true when one shares the NPC's faction or region; then the Lie band is skipped too (spec §5.2). Talking to an informant townsperson (`Def.Informant = true`, set by the Nemesis work) during an Active quest in its region marks every held, unexposed lie from that region `Doubt_` and toasts "*<Teller> is covering for someone.*"

- [ ] **Step 1: `Play_Testimony` part 2 (RED).** Cases:
  - **`SecondTalkOpensTheBox`:** after an evasion, a talk 1 s later → Outcome "Levers", `DialogueService.IsOpen(Player)`; the box has 4 choices for a Townsfolk NPC and 3 for an Authority one.
  - **`LockedChoiceRefused`:** with no standing, `DialogueService.Choose(Player, 1)` (Persuade) returns false, and the box stays open.
  - **`PersuadeWithStanding`:** global Townsfolk standing 25 → Choose 1 → Truth and the evidence.
  - **`BribeTakesExactMoney`:** `Data.Money` set to 120; after a Refuse, the price is 100; Choose 2 → Money 20, `bribed_witness` recorded, Truth. With Money 99: "You need 100." toast, Money 99, no deed, no evidence.
  - **`CrookSpillsForABribe`:** a Candor −1 NPC after an evasion: price 25; Spill.
  - **`HonestWontTakeMoney`:** a Candor +1 NPC: choice 2 locked.
  - **`IntimidateRecordsAndHeats`:** in Lindenmoor's region (Militia law, Townsfolk present): Choose 3 → `intimidated_Townsfolk` recorded, `HeatService.Value(Player, "Militia")` rose by 10 (from a known start), Truth; a later talk to the same NPC scores −25 lower.
  - **`LeverCooldown`:** a second lever within 600 s (test clock) is not offered.
  - **`PatienceSoftens`:** the −70 refusal of `HostileRefuses`, then the test clock +600 s → Evasive (the Lie band skipped); +1200 s → Truth.
  - **`MaskAndGuise`:** at Hostile (−40, a Lie unmasked), `Masked = true` → Score −10 and Truth, with `Terms.Standing` 0; `Guise = "Townsfolk"` on a Townsfolk NPC → Score +20 and Truth, with `Terms.Standing` +20. Both attributes put back.
  - **`InformantVouches`:** at Hostile (−40, a Lie without one), `SetInformants` returning one of the NPC's faction → −20 → Evasive, not Lie.
  - **`AskUnchangedWithoutLocked`:** `DialogueService.Ask` with no `Locked` still answers every index (the control for the Binding consent).
  - Run in Play in Ye (PlayLock `Ye:rep4`). Expected: every case FAILs except `AskUnchangedWithoutLocked`.
- [ ] **Step 2: Implement.** Sync `DialogueService`, `Deeds`, `TestimonyService` and `Play_Testimony` to both places.
- [ ] **Step 3: GREEN in Play in Ye:** `Play_Testimony` 0 FAIL. Regressions: `Play_Morality`, `Play_Heat`, `Play_Assault`, `Play_Rumours`, `Test_Heat`, and any suite of the Alchemic Binding's consent that calls `Ask` (search `RenseiTests` for `Ask(`; record if none).
- [ ] **Step 4: Play in Foundry** (`Foundry:rep4`): `Play_Testimony`, `Play_FoundryLedger`: 0 FAIL.
- [ ] **Step 5:** `--check` in both places.
- [ ] **Step 6: Commit** the scripts and the suite: `"Rep investigations Task 4: levers (persuade, bribe, intimidate), patience, masks, guises, informants"`.

---

### Task 5: The Case Board

**Files:**
- Modify: `InvestigationService.lua` (`Deduce`; the header comment); `Rensei/Investigation.lua` (the header comment's Deductions paragraph); `Play_Testimony.lua`.

**Interfaces.**
- **`InvestigationService.Deduce`:**
  - `Requires` is checked against `Testimony.DeduceView(Data, EvidenceDefs)` instead of `Data` (:73). The slot check (:74-79) still reads the real `Data.Story.Evidence`, so a lie in a slot is held but never the answer.
  - On a wrong answer, before returning `Wrong`: `pcall(TestimonyService.OnDeduceWrong, Player, Id, Answers)`, which sets `Doubt_<id>` (`StoryService.SetFlag`) for every lie in `Testimony.LiesIn(Answers)` and toasts the "*doesn't square*" line once per lie.
  - **If the wrong-guess consequences plan already changed this branch,** this call goes first and its consequence after; a wrong answer that used a lie still pays that plan's cost (spec §7.1, rule 1).
- **The header comments** say both rules (D10, D11).

- [ ] **Step 1: `Play_Testimony` part 3 (RED).** Injected deduction `__rep_who` with `Requires = {Evidence = {"__rep_true", "__rep_other"}}` and one slot answered by `__rep_true`. Cases:
  - **`LieStandsInForRequires`:** holding `__rep_lie` and `__rep_other` (not `__rep_true`): `Deduce(Player, "__rep_who", {"__rep_lie"})` returns false with the deduction's **Wrong** text (not "You don't have enough to go on yet.").
  - **`WrongAnswerDoubtsTheLie`:** after that, `Data.Story.Flags.Doubt___rep_lie` is set and the toast fired once.
  - **`ExposedLieNoLongerStandsIn`:** then the same request returns "You don't have enough to go on yet."
  - **`TruthSolves`:** after the Caught talk, `{"__rep_true"}` returns true with the Conclusion.
  - **`NoLieNoChange`:** a deduction answered wrong with only true evidence sets no `Doubt_` flag (the control).
  - Run in Play in Ye (`Ye:rep5`). Expected: the first three FAIL.
- [ ] **Step 2: Implement.** Sync `InvestigationService`, `Investigation` and `Play_Testimony` to both places.
- [ ] **Step 3: GREEN** in Play in Ye: `Play_Testimony` 0 FAIL; regressions `Play_Clue`, `Play_LindenmoorData`, and (if they exist by then) the wrong-guess consequences suites.
- [ ] **Step 4: Play in Foundry** (`Foundry:rep5`): `Play_FoundryLedger` 0 FAIL (its `DeductionNeedsTheRightPieces` still holds).
- [ ] **Step 5:** `--check` in both places.
- [ ] **Step 6: Commit**: `"Rep investigations Task 5: the Case Board (lies stand in for Requires; a wrong answer with a lie exposes it)"`.

---

### Task 6: The Journal

**Files:**
- Modify: `UI/JournalUI.lua`.
- Create: `Art/Studio/Testimony/client_checks.lua` (a read-only Client check, the gun plan's Task 7 pattern).

**Interfaces** (text lines in the existing panels only; spec §9):
- **Sources** (the `SourceCache` builder, :250-273): each roster clue across `Townsfolk.Regions` adds "Told by: <Name>" for `Clue.Evidence`, `Clue.Spill.Evidence` and `Clue.Lie.Evidence`. A lie reads exactly like a true account.
- **An exposed lie** (`Testimony.Exposed`, the shared pure function, over the client's own `D.Story`): the evidence record gains a line "Doesn't add up: <contradicting evidence title>" (or "The Case Board wouldn't take it." for a `Doubt_` exposure) in the existing `RED_TEXT`.
- **The Case Board's cards** (`CaseClues`, :435-442) leave out exposed lies.
- The client never learns a lie before exposure: nothing new is sent; exposure reads data the client already holds.

- [ ] **Step 1: Write `client_checks.lua` (RED).** In Play in Ye (`Ye:rep6`), as the Client: build a fake `D` (`Story.Evidence` holding a lie, then also its contradiction) and call JournalUI's exported helpers (export `JournalUI._Sources(Id)` and `JournalUI._CaseClues(D, Def)` for tests, PROPOSAL names). Expected before the change: no "Told by" source for a clue-line evidence; the exposed lie still among the cards.
- [ ] **Step 2: Implement.** Sync `UI.JournalUI` to both places.
- [ ] **Step 3: GREEN:** the client checks pass in Ye and in Foundry (`Foundry:rep6`). Then open the Journal once in each place in Play and screenshot the Evidence tab with an injected lie (server-side `GiveEvidence` of a test lie and its contradiction), for the owner's review; the screenshots go to the scratch folder.
- [ ] **Step 4:** `--check` in both places.
- [ ] **Step 5: Commit** `JournalUI.lua` and `client_checks.lua`: `"Rep investigations Task 6: the Journal names who told you, marks lies that don't add up, and drops them from the Case Board"`.

---

### Task 7: The three quests opt in

**Files:**
- Modify: `Rensei/Evidence.lua`, `Rensei/Townsfolk.lua`, `Documents/Region Builder.md` §6 (the `Clue` line); `RenseiTests/Test_Testimony.lua`, `Play_FoundryLedger.lua`, `Play_LindenmoorData.lua`.

**Interfaces** (all wording PROPOSAL and original; spec §6.3).

**Evidence** (new defs):

| Id | Quest | Title | Text | `False` |
|---|---|---|---|---|
| `foundry_marsh_full_pay` | foundry_ledger | A Full Packet | "Sella Marsh, late furnace hand: her pay packet for the 14th held a full eight hours." | `{Truth = "foundry_short_pay", Contradicts = {"foundry_scraped_docket", "foundry_banked_early"}}` |
| `foundry_ashe_rounds` | foundry_ledger | Drinks on Ashe | "Sella Marsh: two nights after the 14th, Ashe stood the whole late crew drinks. Ashe never stands anyone anything." | — |
| `foundry_ashe_hand` | foundry_ledger | Ashe's Own Hand | "Aldous Merriweather: Ashe always brings his dockets in himself. Every other charge hand sends a runner." | — |
| `foundry_ashe_coin` | foundry_ledger | New Coin | "Ivo Marchbank: Ashe paid for a crate off the evening freight in new State coin, and didn't sign for it." | — |
| `lm_ridge_visitors` | lm_ridge | State Coats on the Knoll | "Ned Harrow: men in State coats came up to the marker last spring. They didn't measure anything. They looked at the arrow and wrote in a book." | — |
| `lm_shaft_warm` | lm_mine | Warm Water | "Bess Kettering: the water that flooded the shaft came up warm, and the assayer wouldn't touch the ore bare-handed." | — |

**Townsfolk:** `Temper` on the six entries, and each clue gains `Disposition` and its variants (spec §6.3). `Text` (the Truth line) is **unchanged** on the five existing clues.

| Id | Temper | `Disposition.Weights` | Variants |
|---|---|---|---|
| `lm_groundskeeper` (Ned) | `{Order = 1}` | `{Townsfolk = 1}` | Evasive "Ask the surveyors. I just keep the grass down."; Refuse "I've seen what you do to people. Off my field."; Spill `lm_ridge_visitors` "The marker? I look after it. ... And I'll tell you something else. Men in State coats came up last spring. Didn't measure a thing. Looked at the arrow and wrote in a book." (the Truth line's content first, then the extra) |
| `lm_minehand` (Bess) | `{Mercy = 1}` | `{Townsfolk = 1}` | Evasive "Company business. Ask the company."; Refuse "Not to you. Not after what I've heard."; Spill `lm_shaft_warm` (Truth line, then "The water came up warm, mind. The assayer wouldn't touch that ore bare-handed.") |
| `fy_furnace_d1` (Rusk) | `{Order = -1, Candor = 1}` | `{Foundry = 1}` | Evasive "Ask the clerk. Hours are his business."; Refuse "I've nothing to say to you about the 14th." |
| `fy_furnace_l1` (Marsh) | `{Mercy = 1, Order = -1}` | `{Foundry = 1, Authority = -0.5}` | Evasive "Talk to the clerk. I just stoke."; Lie `foundry_marsh_full_pay` "Eight hours, same as always. Full packet. Whatever you're after, it isn't at Furnace One." with Caught "...All right. Four hours. Ashe said anyone who talked to an inspector would be off the late shift for good. Four hours, and I didn't argue."; Spill `foundry_ashe_rounds` (Truth line, then the drinks) |
| `fy_clerk` (Merriweather) | `{Order = 1, Candor = 1}` | `{Foundry = 1, Authority = 0.5}` | Evasive "The ledger's open to the paymaster, not to passers-by."; Refuse "I'll not open my books to the likes of you."; Spill `foundry_ashe_hand` (Truth line, then the runner) |
| `fy_yard_l` (Ivo) **new clue** | `{Mercy = -1, Candor = -1, Order = -1}` | `{Foundry = 0.5}` | `Clue = {Quest = "foundry_ledger", Disposition = {...}, Text = "Ashe? Charge hand on the late shift. Keeps to himself."}` (no `Stage`, `Signal` or `Evidence`); Spill `foundry_ashe_coin` "Ashe? Between us: he paid for a crate off the evening freight in new State coin, and didn't sign for it. Funny, on a charge hand's wage." |

**Region Builder.md §6:** the `Clue` line documents `Disposition`, `Evasive`, `Refuse`, `Lie` (`Evidence`, `Caught`), `Spill`, the roster's `Temper`, and the §4.3 rules, pointing at the spec.

**Suites:**
- **`Test_Testimony` gains `RealRostersValidate`:** `Testimony.Validate` over the real `Townsfolk.Regions`, `Evidence`, `Inspects` and `Deductions` returns ok, and every opted-in clue gives Truth at neutral (hand-listed: the six ids above, so a clue that silently stops opting in fails).
- **`Play_LindenmoorData`** (Ye): its clue-line checks run inside `TestimonyKit.WithMorality(neutral)` (they keep asserting today's `Text`). A new case **`NedAndBessByStanding`:** at Townsfolk place standing −25 (−20), Ned and Bess evade (no signal); at +65 (Honoured, +40), Ned spills `lm_ridge_visitors`; at −70 (Hostile, −40), Ned refuses (he has no Lie).
- **`Play_FoundryLedger`** (Foundry): `CrewAndClerkAnswer` runs inside a neutral Morality. A new case **`MarshLiesAndIsCaught`**, end to end on the real tellers and clues, with a crafted Morality (`TestimonyKit.WithMorality`: Foundry place standing −25 for the Foundry hands, Conduct Mercy −20 and Order 20; by hand: Standing −20 + Kinship −20 = −40, a Lie for Marsh; Rusk, Candor +1, can't lie and evades at −20, so step 3 runs Rusk and the clerk inside a neutral Morality):
  1. the ledger inspect starts the quest;
  2. Marsh → Outcome "Lie", `foundry_marsh_full_pay` held, `foundry_short_pay` not;
  3. the clerk and Rusk at neutral → their truths; holding `foundry_banked_early` fires Marsh's toast;
  4. the docket inspect at stage 2;
  5. the Case Board with the lie in slot 2 → Wrong and `Doubt_foundry_marsh_full_pay`;
  6. Marsh again → "Caught", `foundry_short_pay` held;
  7. the right answer → Completed.
  
  It puts back Quests, Story and Morality, as the suite already does.
- **The id sweep** in `Play_FoundryLedger` (:340-370) also walks `Clue.Lie.Evidence` and `Clue.Spill.Evidence`.

- [ ] **Step 1: RED.** Add the suite cases first. In Play in Ye (`Ye:rep7a`): `Test_Testimony` `RealRostersValidate` FAILs (no opted-in clues), `NedAndBessByStanding` FAILs. In Play in Foundry (`Foundry:rep7a`): `MarshLiesAndIsCaught` FAILs.
- [ ] **Step 2: Implement** the data and the doc. Sync `Evidence`, `Townsfolk` and the suites to both places (`Play_FoundryLedger` Foundry only, `Play_LindenmoorData` Ye only).
- [ ] **Step 3: GREEN in Play in Ye** (`Ye:rep7b`): `Test_Testimony`, `Play_LindenmoorData`, `Play_Testimony`, `Play_Clue`, `Play_Townsfolk`: 0 FAIL.
- [ ] **Step 4: GREEN in Play in Foundry** (`Foundry:rep7b`): `Play_FoundryLedger`, `Test_FoundryRoster`, `Play_Testimony`: 0 FAIL. The server output has no "TestimonyService: ... not opted in" warning (a `Validate` refusal).
- [ ] **Step 5:** `--check` in both places.
- [ ] **Step 6: Commit** the data, the doc and the suites: `"Rep investigations Task 7: lm_ridge, lm_mine and foundry_ledger opt in (Marsh can lie; Ivo spills)"`.

---

### Task 8: Both places' sweep

**Files:** none new.

- [ ] **Step 1:** `--check` in both places: `DIFFER 0 / MISSING 0`.
- [ ] **Step 2: Play in Ye** (`Ye:rep8`), every suite this plan touched or depends on, in this order: `Test_Testimony`, `Play_Testimony`, `Test_TownsfolkLogic`, `Play_Townsfolk`, `Play_TownsfolkHurt`, `Play_TownsfolkCrowd`, `Play_Clue`, `Play_QuestEngine`, `Play_LindenmoorData`, `Play_LindenmoorSmoke`, `Play_Morality`, `Play_Rumours`, `Play_Heat`, `Play_Assault`, `Test_Reputation`, `Test_Heat`, and the earlier plans' smoke suites if they exist (the assassination plan's `Play_Takedown`, the stealth and Nemesis suites). Record each result.
- [ ] **Step 3: Play in Foundry** (`Foundry:rep8`): `Play_Boot` first, then `Test_Testimony`, `Play_Testimony`, `Play_FoundryLedger`, `Test_FoundryRoster`, `Play_Clue`, `Play_QuestEngine`, the Foundry smoke suite if it exists, and the travel suites (`Play_Station`, `Play_Road`, `Play_Gate`, `Play_Arrive`, `Play_Travel`, `Play_RideEvents`; the known ticket failures in Travel and RideEvents are not regressions).
- [ ] **Step 4: A walk-through in each place** (the controller watches; screenshots to the scratch folder): in Ye, ask Ned with the owner's real standing (whatever it is) and record the answer; in Foundry, ask Marsh, Rusk, the clerk and Ivo. **Before** the walk-through, the dump and probe; **after**, the restore and both compared (Global Constraints). The answers are reported, not judged: the owner's real standing decides them.
- [ ] **Step 5:** Report the counts to the controller. No commit (nothing changed).

---

### Task 9: Docs and the checkpoint

**Files:**
- Modify: `Documents/Changelog.md`, `Documents/Backlog.md`, `Documents/Decisions.md`.

**Interfaces:**
- **`Changelog.md`:** one entry, `## 2026-10-25 — Reputation in investigations: witnesses who lie, refuse or spill (not live)`. It holds:
  - the decisions D1–D24, each marked PROPOSAL or with the owner's answer;
  - what changed in each place (the scripts, the data, the Journal);
  - the test counts from Tasks 2–8;
  - the rollback: revert the scripts from `RenseiBackups["Pre-RepInvestigations_2026-10-25"]` in both places; delete what this plan created, which has no backup (`Rensei.Testimony`, `RenseiServer.TestimonyService`, and the suites `Test_Testimony`, `TestimonyKit`, `Play_Testimony`). Removing every `Disposition` key from the rosters alone turns the feature off.

  Its `### Discord announcement` starts "Hold: not live yet. Post this when the owner publishes Ye, Foundry Yard and the packages together." Then a ```md block, under 2,000 characters, plain and player-facing, with no file names, test numbers or PROPOSAL tags. It covers:
  - people you question now react to who you are: your name with their people, how you behave, how wanted you are, and what they've seen you do;
  - some will tell you everything, some will dodge, some will shut the door, and some will lie to your face;
  - a lie can fool your Case Board, but it never holds up: other evidence gives it away, and the liar comes clean when you go back;
  - the shady sort talk more freely to the shady sort;
  - you can press a reluctant witness: lean on your good name, pay them, or threaten them, and threats have a price;
  - patience works too: come back later;
  - the shift-ledger mystery in the Foundry Yard, and the two Lindenmoor clue hunts, now play this way.
- **`Backlog.md`:** item 5 of "After the swimming revamp" is ticked, with a pointer to this entry. Add follow-ups: a `Candid` condition for dialogue-tree NPCs (spec §7.4); proving a schemer's false rumour (Nemesis §5.3); the main story's witnesses written with this system.
- **`Decisions.md`:** a short entry listing D1 (with the owner's answer from before Task 3) and pointing at the spec's §11 for the rest.

**Steps:**
- [ ] **Step 1:** Write the docs. Every number comes from a task report.
- [ ] **Step 2:** Check that the Discord block is under 2,000 characters (count it with `python -I -c`), and that it has no file names, test numbers or PROPOSAL.
- [ ] **Step 3: The controller names the checkpoint to the owner in chat:** the packages (Modules: Testimony, Deeds, Evidence, Townsfolk, Investigation, JournalUI; RenseiServer: TestimonyService, TownsfolkService, StoryService, DialogueService, InvestigationService, ServerHandler), the publish order, the hold. This plan publishes nothing.
- [ ] **Step 4:** This is the plan's only Changelog entry. No other task wrote one.
- [ ] **Step 5: Commit** the three docs: `"Rep investigations Task 9: docs, changelog (held Discord post) and the checkpoint"`. After the commit, **the controller pushes and updates the status page.** The implementer does neither.

---

## Self-review notes

**Coverage of the request:**
1. **Disposition from** standing (place, and absent factions at half), conduct matched against the NPC's Temper (the "evil" kinship), Heat and Wanted, what the NPC can tell of you (masks and guises), and deeds witnessed or heard: Task 2 (rules), Task 3 (witness memory), Task 4 (masks, guises, informants).
2. **The five answers** and the Caught line: Task 3. False evidence and its exposure: Tasks 2, 3, 5 and 6.
3. **Levers:** persuade, bribe, intimidate (Morality and Heat through the existing deed path), informant, disguise, and patience: Task 4.
4. **The three quests opt in and keep working at neutral:** Task 7, with neutral checked in `Test_Testimony` (`RealRostersValidate`), `Play_LindenmoorData` and `Play_FoundryLedger`.
5. **Data shape** per clue: Task 7 and `Region Builder.md` §6.
6. **Never a soft-lock:** `Validate` at Start (a broken clue falls back to today's behaviour), the stand-in view, the Case Board's doubt, the Caught line, patience.
7. **Wrong-guess consequences:** §"Shared files" and Task 5 (the wrong branch, in either order).
8. **Server validation:** Tasks 3–5 (every lever re-checked at answer time; the client only ever gets text).
9. **Existing UI only:** bubbles, the dialogue box, toasts, Journal text.

**Found while planning, not in the request:**
- `foundry_ledger_who` needs all three clue-line evidence before it can be answered, so any withholding witness would block the Case Board (spec C4): hence the stand-in view (D10).
- The Authority isn't present in the Foundry region, so its place standing is always 0 there and intimidation's State Heat arrives by rumour (spec A10, D6).
- `DialogueService.Ask` has no combat check and can't grey a choice (spec C9): Task 4 adds `Locked`; `TestimonyService` checks combat itself.
- Trust can't hold per-townsperson changes (spec A7): per-faction intimidation deeds and server-memory grudges instead.
- The Journal doesn't list townsfolk as evidence sources (spec C11): Task 6.
- Two "standings" (spec A9): dialogue conditions read the global cache, townsfolk the place's. This plan uses the place's (like greetings) and the global one only for absent factions and Persuade.

**Names used across tasks:**
- the module `Rensei.Testimony` and the service `TestimonyService` (`Talk`, `Handles`, `NoteHit`, `OnEvidence`, `OnDeduceWrong`, `Informants`, `SetInformants`, `SetClock`, `Memory`, `Forget`, `Start`);
- the roster key `Temper`, the clue keys `Disposition`, `Evasive`, `Refuse`, `Lie` (`Evidence`, `Caught`), `Spill`; the evidence key `False` (`Truth`, `Contradicts`);
- the flag `Doubt_<evidence id>`; the deeds `bribed_witness` and `intimidated_<FactionId>`;
- the character attributes `Masked` and `Guise`;
- the backup folder `Pre-RepInvestigations_2026-10-25`; PlayLock values `<Ye|Foundry>:rep<task>`;
- the kit `RenseiTests.TestimonyKit`; the suites `Test_Testimony` and `Play_Testimony`;
- the new evidence `foundry_marsh_full_pay`, `foundry_ashe_rounds`, `foundry_ashe_hand`, `foundry_ashe_coin`, `lm_ridge_visitors`, `lm_shaft_warm`.

**Order and dependencies:**
- 1 before everything.
- 2 before 3 (the rules).
- 3 before 4 (the lever box hangs off an evasion) and 5 (`OnDeduceWrong` lives in `TestimonyService`).
- 3, 4 and 5 before 6 (the Journal reads exposure) and 7 (the content needs every path).
- 8 after all; 9 last.
- **D1 is answered before Task 3.**
- Play sessions are serial across the places.

**Each task can be rejected on its own:**
- Without Task 4, there are no levers. Patience is built in Task 4 too, so if Task 4 is dropped, its patience step moves into Task 3 (it is the lever-free path to the truth and must ship with the answers).
- Without Task 6, the Journal doesn't mark lies, but the toasts and the Case Board still do.
- Without Task 7, nothing a player meets changes.

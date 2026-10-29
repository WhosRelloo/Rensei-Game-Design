# Stealth Missions 1: Guards That Think, and Seeing What They See — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Every implementer gets the **Global Constraints**, the **Facts** and the **Audit rulings** below together with its own task.

**Goal:** slices **M1** (smarter guards) and **M2** (seeing guard vision) of the stealth missions design. When this plan is done:
- **State guards exist as data.** There are three new enemy types: `StateGuard`, `StateSentry` (long sight, slow to notice) and `StateOfficer`. All three are Authority, so a takedown of one is the existing `assassinated_guard` deed.
- **Guards keep a routine.** A guard on a **radio net** walks a **patrol route** with the townsfolk's Mover, or stands a **post**. A **look-out** holds a high post and sweeps its gaze.
- **The radio runs on a timer.** Every guard on a net **checks in** on a timer. A guard who misses one (knocked out, dead or taken) starts a **search from his post** after a grace period.
- **A guard who goes Alert stops to make a radio call** (about 2 s). Knocking him out in that window stops the alarm. A call that gets through raises the **whole net**: guards converge on the spot, **reinforcements** come out of a barracks door, and the net stays **tight** (it calms to Cautious, never to Normal) for a while.
- **The net shares what it learns:**
  - only the **nearest** guard goes to look at a noise, and look-outs never leave their posts;
  - a noise only look-outs heard is radioed, and the nearest free guard goes 3 s later;
  - a guard who loses you **shares your last known position**, so the sweep starts there.
- **Guards talk.** They say short lines in the townsfolk speech bubble when they turn suspicious, search, call, or give up.
- **The player sees each guard's awareness:**
  - each guard's awareness of you is sent **only to you**;
  - while you **crouch** (the stealth stance), a flat **vision cone** shows on the ground under each of the 8 nearest enemies within 60 studs, tinted pale → amber → red;
  - a **suspicion marker** (the transmutation circle art) shows over a guard's head whenever it has noticed you at all;
  - there's no radar.
- **Nothing else changes for enemies without a net:** a bandit without a `Net` behaves exactly as today. The cones and markers show for them too (ruling A9). **No guard is placed in the live world by this plan.** Guards appear only where a later plan places them, or in Play through the demo script.

Both Ye and Foundry get the same code. Nothing is published.

**Architecture:** three new modules and a few small hooks into existing ones.
- **`Rensei.Guard`** (ReplicatedStorage, pure) holds the numbers, the lines, and the pure rules: the route stepping, the check-in clock, the cone geometry, the tint and the marker state. The client and the tests share it.
- **`GuardService`** (server) owns guards, nets, routines, the radio and the shared memory. It drives patrol walks with `TownsfolkService.Mover` and listens to new `PerceptionService` hooks.
- **`SightFeed`** (server) sends each player their own awareness rows on an `UnreliableRemoteEvent`.
- **`GuardSightUI`** (client) draws the cones and markers from those rows.

**Tech Stack:**
- Roblox Studio Luau, through `Art/Tools/rbxc.py`.
- Python 3.14 (stdlib only), only for `sync.py --check` and `test_sync.py`.

**Spec:** `Documents/specs/2026-10-25-stealth-missions-design.md` (binding; concept approved by the owner 2026-10-25). It builds on `Documents/specs/2026-10-19-morality-reputation-consequences-design.md` §17. Every number and new name in the spec and here is a **PROPOSAL** unless it quotes an owner decision.

---

## The stealth missions roadmap (this plan is Plan 1 of 4)

The spec has eight slices (§6.1), too many for one plan: each later group needs the one before it, and two need things only the owner can give. The plans:

| Plan | Slices | Builds | Needs |
|---|---|---|---|
| **1 (this plan)** | M1, M2 | Guards that think; cones and markers | Nothing new |
| **2: tools and disguises** | M3, M4 | **Hiding spots** (`Takedown.IsHidden` becomes real), **drag**, **throwables** and **noise lures** through `NoiseService`; uniforms taken from knocked-out guards, the range and close-up rules, Identities records | Plan 1's nets (a hidden body against a missed check-in); the Officer type |
| **3: jobs, contracts, outcomes** | M5, M7 | Tail, Plant, Retrieve in the shared world; contract templates; the job board and the fixers; Ghost / Quiet / Loud, pay, mission deeds, anonymous and named rumours | Plans 1–2 |
| **4: private compounds** | M6 | The "mission" trip kind, reserved servers, the return trip; Lindenmoor's survey field camp and its story mission | **The compound built in Blender with the owner's render approval**, and **a private live test server** (reserved servers can't run in Studio) |
| — | M8 | The Nemesis hook | **Nemesis is shelved** (`Documents/CLAUDE.md`). It waits for the owner |

**What already exists from the assassinations plan:**
- the chokehold knockout (tap N);
- waking up and raising the alarm (`TakedownService` WAKING UP);
- carrying bodies (V);
- bodies found by sight.

So Plan 2's M3 is only the four pieces named above.

---

## When to start

- **Now.** The owner said "Yes, start the stealth missions plan" (2026-10-29). Stealth missions is item 3 of the Backlog's "After the swimming revamp" list (`Documents/Backlog.md:62`). Hostages are done (`0ecda93`).
- The spec's one dependency is that the townsfolk walkability fix (Foundry Yard plan Task 4b) is in. It has been in since 2026-10-25 (`Mover.PlanPath` and the corner repair, `Mover.lua:26-60`).
- `Documents/CLAUDE.md` asks for approval before scripts are rewritten. Nothing here is rewritten: every existing script gets a small, named hook (see "Each task can be rejected on its own"). The owner approved the design on 2026-10-25.
- **Before Task 4** (the first behaviour change), the controller adds the "Decisions taken without the owner" list to the ledger. Unattended rules apply: rule, label PROPOSAL, keep going (`rensei-overnight-queue` memory).

---

## Facts (read from the repo, 2026-10-29; Task 1 confirms them in Studio)

**Places and windows:**
- **Ye:** placeId 106992859583940, window "[CLOSED TESTING] Rensei".
- **Foundry:** placeId 109591196441030, window "Foundry Yard".
- **Tutorial:** placeId 74257385894576. It doesn't consume the packages. This plan never edits it.
- Get each window's `studio_id` from `python -I Art/Tools/rbxc.py studios`.
- **Never touch** "Crownfall" (93979562442002), "bloodydeadpool53's Place", or the Main Menu window (123967384111466). Leave Ye's "Tool Grip Editor (LOCAL)" panel alone.

**Tools:**
- `Art/Tools/rbxc.py` is the Studio bridge.
  - `luau "placeId: <id>" <Edit|Server|Client> @file.lua` runs Luau. Only the first return value prints, cut at 30,000 characters.
  - `call get_studio_state '{"studio_id":"<id>"}'`; `call start_stop_play '{"is_start":true|false,"studio_id":"<id>"}'`.
  - **Foundry quirk:** "Target is not reachable (DMN_ID_EDIT)" can come back although the call ran. Read the state before retrying anything that isn't idempotent.
- `Art/Studio/Regions/Foundry/data/sync.py` keeps Ye and Foundry identical: manifest `sync_manifest.json`, pins in `test_sync.py:103-106`. Today the pins are **Ye 143 / Foundry 142**.
- **Work folder** (the owner's E: rule): `E:/Rensei/Work/stealth1/`. Dumps, probes, screenshots and survey output go here, never in the repo or the temp scratchpad.

**Play protocol** (every Play session, every task; the hostages' protocol, unchanged):
1. **Check the state.** `get_studio_state` shows the **other** place in Edit, and Ye's `game.ServerStorage:GetAttribute("PlayLock")` is nil (Foundry's too, when playing Foundry).
2. **Turn on TestNoSave.** In **Edit**: `game.ServerStorage:SetAttribute("TestNoSave", true)` in the place about to play.
3. **Lock.** In Ye (Edit), set `PlayLock` to `"<Ye|Foundry>:stealth<task>"`. When playing Foundry, set it in Foundry too.
4. **Hook.** In Edit, run `C:/Users/Owner/.claude/jobs/0c39df78/tmp/blender/hook.lua`, then **read it back** right away (`game.ServerStorage:FindFirstChild("LMTestHook")`).
5. **Helper.** `rbxc.py luau "placeId: <id>" Edit @Art/Studio/Regions/Foundry/data/dumphelper.lua` must return "dump helper installed".
6. **Start Play.** In the Server data model:
   - wait for `game.ServerStorage:GetAttribute("LMSnapTaken")`;
   - then check `require(game.ServerScriptService.CharacterHandler.DataManager).IsNoSave()` is `true`, **before anything mutates**. If it isn't, stop Play and report.
7. **Dump 1.** `return game.ServerStorage:WaitForChild("LMQuestDump", 30):Invoke()`, saved to `E:/Rensei/Work/stealth1/quests_stealth<task>_1.txt`. Plus a probe line `deeds_stealth<task>_1.txt`: `Data.Money`, `Data.LifetimeExp`, and the `Count` of `assassinated_guard` and `executed_bandit`.
8. **Suites:** `game.ServerStorage.LMRunSuite:Invoke("<Suite>")` (Server).
9. **Restore:** `game.ServerStorage.LMTestHook:Invoke("restore")` must return "restored".
10. **Dump 2 and probe 2** must equal dump 1 and probe 1, with session timestamps masked. If not, keep Play running and report both, plus `LMTestHook:Invoke("diff")`.
11. **Stop** Play.
12. **Unhook:** in Edit, run `.../unhook.lua`, then **read** that the hook is gone.
13. **Remove the helper:** a copy of `dumphelper.lua` in the work folder with only its `MODE` line set to `"remove"` must return "removed <n>".
14. **Clean up:** clear `TestNoSave`, then clear `PlayLock` in both places.

**Never run Play while the owner is in the live game on the same account.** If anything suggests they are, stop and report.

**Testing realities:**
- Studio Play has **one real test player**. Every guard in a test is an enemy rig spawned by `TakedownKit.Spawn` on the kit's Play-only floor high above the map. The kit's floor keeps real NPCs out of reach (`TakedownKit.lua:5-12`).
- `TakedownKit.Spawn` anchors the rig's root (`TakedownKit.lua:13-15`). A guard that must walk is freed with `Kit.Free(Rig)` (`:271`).
- `Kit.Guard` holds `PerceptionService.SetAuto(false)` (`:20-24`), so phases change only when the case calls `Kit.Run`. The enemy Brain still runs every 0.1 s. GuardService gets the same seam (`SetAuto` / `Step`) in Task 4.
- **Client checks** use the takedowns' and hostages' pattern: `Art/Studio/Hostage/client_checks.lua:1-25` (one file holds a CLIENT half and a SERVER half; TEMP objects are removed before it returns).

---

## Global Constraints

**Owner rules (verbatim):**
- "Do not publish the Roblox game or modify live player data."
- "Do not expose API keys, credentials, private player data, or other secrets."
- "Do not blindly copy another game's code or assets." Guards are "in the style of Metal Gear Solid (inspired by, never copied)" (spec §1). Every line and name here is original.
- "ONLY use existing UI assets."
  - The marker is built only from the transmutation circle `rbxassetid://132299053523633`, the same image as `StealthUI` (`StealthUI.lua:20`).
  - The cones are plain world geometry (`WedgePart`s), with no image.
  - Speech uses the existing `Remotes.TownsfolkSay` bubble (`TownsfolkService.lua:367-381`; the client draws it on any rig's Head, `TownsfolkClient.lua:85-129`).
  - No new images, fonts, sounds or ScreenGuis, no `StarterGui` edits, and **no HUD radar** (owner).
- "Leave my save as it is for now." Every Play session runs under TestNoSave, and dump 2 must equal dump 1.
- **Never invent an asset id.**

**Labels and records:**
- Every invented number, name or line is labelled **PROPOSAL** in code comments and docs.
- **One Changelog entry**, written by Task 10 for the whole plan. It ends with a held `### Discord announcement` under 2,000 characters: no file names, no test counts, no PROPOSAL tags.
- Implementers report to the controller in their final message. They never dispatch subagents and never write under `.superpowers/`.

**Scripts live in both places:**
- Edit the repo file first, then set it into **both** places:
  ```
  python -I Art/Studio/Regions/Foundry/data/sync.py --place ye|foundry --backup Pre-Stealth1_2026-10-29 --only <label>[,<label>...] --run
  python -I Art/Studio/Regions/Foundry/data/sync.py --place ye|foundry --check
  ```
- **Start every task that touches a script with `--check` in both places.** If anything differs, stop and report.
- `--check` must print `DIFFER 0 / MISSING 0` for both places at the end of every task that touched a script.
- Each task adds its own pairs to `sync_manifest.json` (`Places: ["ye", "foundry"]`, `Create: true` for a new script) and raises the counts in `test_sync.py:103-106` with a comment naming the task.
- **Never sync this plan's scripts without `--backup Pre-Stealth1_2026-10-29`.** A created script gets no backup.
- `Modules`, `RenseiServer` and `Assets` are packages. Publishing them is the owner's (Task 10's checkpoint).
- **Script edits are refused while Play runs.** Stop, unhook and unlock before syncing.

**Tests:**
- **RED then GREEN.** Every new check is run once where it **must fail** (before the change), and fails. Then it passes after.
- **A check that cannot fail is not a check.** Expected numbers are written by hand in the test, never read from `Rensei.Guard` at check time.
- **No duplicated test logic.** Shared helpers live in `RenseiTests.GuardKit` (Task 4), which **requires** `TakedownKit` (Spot, Spawn, Free, PutPlayer, PutInFront, PutBehind, Crouch, Run, Guard, WaitFor). Nothing is copied.
- **Every Play case runs inside `TakedownKit.Guard`**, which refuses to run unless the hook's snapshot is armed. `GuardKit.Guard` adds the `DataManager.IsNoSave()` check and `GuardService`'s own `SetAuto(false)` and clean-up.
- When a check fails, fix the cause, never by loosening the check.

**Enemies without a net are untouched** (the plan's safety rule):
- Every new behaviour is keyed on `GuardService.Guards[Rig]`, which exists only for a rig with a net (a `Net` attribute on its spawn part, or `GuardService.Track` in a test).
- Each behaviour task keeps one **control case**: a plain `Grunt` on the same floor does exactly what it did before. It walks home, isn't radioed, and every hearer of a noise still goes to look.
- The one change every perceiving enemy gets is the cones and the marker (Tasks 7–8).

**Git:**
- Commit by path only: `git commit -m "<msg>" -- <paths>`. New files need `git add -- <path>` first. Never `git add -A`.
- Never stage `.blend`, `.blend1`, `Art/Blender.rar`, `.animation-mcp/` or `poses/`.
- End every commit message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Implementers don't push.

**Publish order** (`Documents/World Travel.md` §10):
1. packages from Ye;
2. Foundry's packages by hand, checked with `sync.py --check`;
3. the places;
4. Migrate to Latest Update last.

This plan never publishes. The held hostages, assassinations and gun rework packages already wait on the owner. This plan's changes ride in the same Modules and RenseiServer packages, so **they ship together**. Task 10's Changelog says so.

---

## Audit: what exists now against what the spec assumes

Every line below was read from the repo on 2026-10-29.

| # | Spec assumes | What exists (file:line) | Ruling (PROPOSAL) |
|---|---|---|---|
| A1 | Alert phases Normal / Suspicion / Alert / Search (§3.1) | `PerceptionService`: Unaware, Suspicious (≥ 0.35), Alert (1), searching (`SearchUntil`), Cautious (`PerceptionService.lua:154-194`). `Call` brings in same-kind NPCs within 40 studs (`:133-146`) | Keep every rule. Owner's Normal = Unaware or Cautious; Search = Alert with `SearchUntil`. New behaviour lives in GuardService, fed by **listeners** added to PerceptionService (Task 3) |
| A2 | "Guards" | **No guard enemy type exists.** `TuningConfig.Enemies` has Sparring, the five alchemists, Grunt, Elite, AditScavenger and the trials, **none with a `Faction`** (`TuningConfig.lua:1027-1160`). The Yard watchmen are `RenseiWatcher` townsfolk with `Combat = false` (`travel_pieces.lua:759-760`; `PerceptionService.lua:551-559`), which never fight | Task 2 adds `StateGuard` (from Grunt), `StateSentry` (from Grunt, perception type Sentry) and `StateOfficer` (from Elite, perception type Officer), all `Faction = "Authority"` (= `Heat.Law.State`, `Heat.lua:18`). `TakedownService.DeedFor` already makes their takedown `assassinated_guard` (`TakedownService.lua:250-258`) |
| A3 | New guard types Sentry and Officer "as data" (§3.2) | `Perception.Types` holds Grunt, Elite, Agent, Hunter, Witness (`Perception.lua:30-36`). `Takedown.ClassByPerception` lists Grunt, Agent, Elite, Hunter; **an unlisted class fails closed as immune** (`Takedown.lua:56`, `:110-112`) | Task 2 adds `Sentry = {Range = 60, Fill = 0.6}` and `Officer = {Range = 40, Fill = 1.2}`, and `ClassByPerception.Sentry = "Full"`, `.Officer = "Full"`: officers are people, not bosses, so a knockout works on them. Disguise-reading for officers is Plan 2 |
| A4 | Guards use the Mover (§3.4) | Enemies walk with `Humanoid:MoveTo` in `Brain` (`EnemyService.lua:337-368`). The Mover's API is `WalkTo(Rig, CFrame, {Speed, OnDone})`, `Stop`, `Place`, `Handle` and `PlanPath` (`Mover.lua:1-35`, `:2044-2128`). `WalkTo` sets `Humanoid.WalkSpeed`, turns `AutoRotate` off and network ownership to the server (`:2104-2110`); `Stop` gives the body back (`:14-16`). `Place` **anchors** the root (`:12`) | **The Mover walks the routine only** (patrol legs and the walk back to a post). The moment Brain has a target or a perception goal, `GuardService.Interrupt` stops the walk and puts `WalkSpeed` back to the def's. **`Mover.Place` is never used on a guard** (an anchored guard couldn't fight). Task 1 proves in Play that a WCS enemy rig walks with the Mover and fights after `Stop`. **Fallback, if it doesn't:** patrol legs use `Mover.PlanPath` waypoints walked with `Humanoid:MoveTo` (ledger the ruling) |
| A5 | Look-outs on high posts (§3.1) | Nothing | A guard whose spawn has `Lookout = true` holds its post, walking back if it's more than 3 studs off. While idle it sweeps its facing ±45° over a 6 s period. A look-out never leaves the post to look at a noise; it radios it (A7) |
| A6 | Radio check-ins; a missed one starts a search from the guard's post after 30 s (§3.3) | Nothing | Task 5. Every 45 s each guard on a net checks in if it is alive, not `Knocked` and not `TakenDownBy`. 45 s with no check-in plus a 30 s grace makes a **missed** check-in. The nearest free guard on the net is then `Raise`d at the missing guard's post (or its last patrol point). The missing guard's record stays until that happens, even after the rig is destroyed, so a cleaned-up body still gets missed |
| A7 | A heard noise reaches the net 3 s later; only one guard goes to look (§3.1, §3.3) | `Hear` sends **every** NPC in muffled reach to investigate (`PerceptionService.lua:453-472`) | Task 3 adds `PerceptionService.PickLookers` (default: everyone, as today). GuardService replaces it in Task 6: per net, only the nearest non-look-out hearer goes, and the other net hearers keep their routine. Rigs with no net are kept as they are. A noise heard only by look-outs is radioed: 3 s later the nearest free non-look-out guard on the net goes to look (`PerceptionService.Look`) |
| A8 | The radio call: a guard stops about 2 s to call; knocking him out in that window stops the alarm; then the whole compound converges and reinforcements come (§3.1) | `Call` (40 studs) is the shout, and it stays | Task 5. When a net guard enters Alert and the net has no alarm out and no call in progress, it starts the call: attribute `Radioing` for 2 s (`EnemyService.Busy` includes it, so it stands still). **Cut:** dead, `Knocked`, `TakenDownBy` or gone before the end. **Through:** the net's alarm, where every other free net guard is `Raise`d at the spot and floored to Cautious for 600 s, and each barracks of the net sends 2 reinforcements after 6 s (at most 4 alive per net). A cut call can be retried by the next guard to go Alert |
| A9 | Cones and markers for "guards near you" (§4.1) | `StealthUI` draws the sigil from character attributes (`StealthUI.lua:1-100`). Each NPC's phase replicates as the rig attribute `Awareness` (`PerceptionService.lua:72-77`); **awareness per player is server-only** | **Every perceiving enemy** (`Combat = true` in PerceptionService) gets them, guards and bandits alike: a bandit watching you is as much a stealth threat. Townsfolk watchers don't (no cone, no marker), because they never fight and a town would be a sea of markers. Owner question 1 |
| A10 | Stealth stance (§7 question 1) | Crouching exists (`Crouching` attribute, `Perception.lua:74`; `TakedownKit.Crouch`) | **Stealth stance = the crouch** (the spec's recommendation). Cones show only while `Crouching` is true |
| A11 | After an alarm, the compound stays tighter for the rest of the run: patrols in pairs, calm-down ends at Cautious (§3.1) | No "run" exists in the shared world | `TightUntil = alarm + 600 s` (`Guard.TightSeconds`). `PerceptionService.Floor` keeps every net guard at Cautious or above until then. **Pairs:** after the search, reinforcements walk the routes of the net's patrolling guards, one each. Plan 4's compounds end the tight time with the run. Once `TightUntil` passes, reinforcements that aren't Alert are removed (so a net can't grow without limit) |
| A12 | A light goes out → the nearest guard relights it (§3.3) | Light control isn't built (morality spec §17.7) | **Out of this plan.** It goes with light control, which the spec says isn't part of this concept (§4.2). Ledger it |
| A13 | Speech lines in the townsfolk bubble (§3.1) | `TownsfolkService.Say` works only for townsfolk ids (`Folk[Id]`, `:367-370`), but the remote is `TownsfolkSay:FireClient(P, Rig, Text, Seconds)` and the client draws on any Head | GuardService fires `Remotes.TownsfolkSay` itself, to players within `TownsfolkService.SayRadius`, timed with `TownsfolkLogic.SpeechSeconds` (`:378`). There's one line per guard per 8 s at most. The lines are original (PROPOSAL, `Rensei.Guard.Lines`) |
| A14 | Each guard's meter sent only to its player (§4.1) | — | Task 7: `SightFeed` sends at 5 Hz on an `UnreliableRemoteEvent`, `Remotes.GuardSight`, created at Start if missing (the `PuzzleService.Start` pattern, `PuzzleService.lua:310-313`). Each row is `{Rig, Aware}` with `Aware` rounded to 0.05, for the 8 nearest perceiving enemies within 60 studs. It's sent only when the rows change, plus one keep-alive per second (unreliable events can drop) |
| A15 | The cone "is not trimmed by walls" (§4.1, honest limit) | — | As the spec says. The cone is drawn flat at the guard's floor height, found with one client ray down every 0.2 s, and isn't draped over slopes. Every cone part is `CanCollide`, `CanQuery`, `CanTouch` and `CastShadow` false, so no client raycast (camera, guns, prompts) ever hits one |
| A16 | Guard deaths are deeds (§5.2) | Takedowns and grips record deeds (`TakedownService.lua:250-258`, `:620`); **a guard killed in open combat records none** | Out of scope: M7 (Plan 3). Ledger it |
| A17 | Patrols wait for the walkability fix (§3.4) | In since the Foundry Yard plan (`Mover.lua:26-60`) | Done. Task 4's routes are on the kit's flat floor; real routes get the reach test in Plan 4 |

---

## Decisions taken without the owner

Each is a PROPOSAL, built so the owner can change it with a number in `Rensei.Guard` or by skipping a task.

| | Decision (PROPOSAL) | Task |
|---|---|---|
| D1 | Stealth stance = the crouch | 8 |
| D2 | Cones and markers for every perceiving enemy, not townsfolk | 7, 8 |
| D3 | The three guard type names, numbers and Authority faction | 2 |
| D4 | Officers can be knocked out (class Full) | 2 |
| D5 | Check-in every 45 s, grace 30 s; radio call 2 s; radio delay 3 s; tight time 600 s; 2 reinforcements per barracks, at most 4 alive per net, after 6 s | 2, 5 |
| D6 | Look-outs never leave the post for a noise; they radio it | 6 |
| D7 | Reinforcements pair up on the patrol routes, and leave when the net calms | 5 |
| D8 | Patrol walk speed 8; a pause of 3 s at each point; a look-out sweeps ±45° over 6 s | 2, 4 |
| D9 | The guards' lines (original text) | 2, 6 |
| D10 | Cone colours: pale (230, 226, 214) → amber (240, 176, 64) → red (214, 64, 52). Fill transparency 0.78 for the full cone, 0.9 for the half-rate band | 2, 8 |
| D11 | The marker sits 4.2 studs over the Head. It shows whenever your awareness > 0, in or out of stance. It gets a ring at Suspicion and turns solid red at Alert | 2, 8 |

**Owner questions** (asked in the Changelog; nothing waits on them):
1. Should cones and markers also show for townsfolk witnesses (D2)?
2. Is crouch the stealth stance, or does the owner want a separate toggle (D1)?
3. Should a guard killed in open combat record a deed, as takedowns do (A16, Plan 3)?

---

## File map

| File | Responsibility | Task |
|---|---|---|
| `Scripts/ReplicatedStorage/Modules/Data/Rensei/Guard.lua` (new) | numbers, lines, pure rules | 2 |
| `Scripts/ReplicatedStorage/Modules/Data/Rensei/Perception.lua` | Sentry, Officer; three enemy type rows | 2 |
| `Scripts/ReplicatedStorage/Modules/Data/Rensei/Takedown.lua` | two class rows | 2 |
| `Scripts/ReplicatedStorage/Modules/Data/Rensei/TuningConfig.lua` | the three guard defs | 2 |
| `Scripts/ServerStorage/RenseiTests/Test_Guard.lua` (new) | pure tests | 2 |
| `Scripts/ServerScriptService/PerceptionService.lua` | listeners, `Look`, `Floor`, `Now`, `PickLookers`, `PerceptionType` attribute | 3 |
| `Scripts/ServerStorage/RenseiTests/Play_GuardSense.lua` (new) | the hooks, in Play | 3 |
| `Scripts/ServerScriptService/GuardService.lua` (new) | guards, nets, routine, radio, memory | 4–6 |
| `Scripts/ServerScriptService/EnemyService.lua` | `Busy` + Radioing; the idle hook; Track at spawn | 4, 5 |
| `Scripts/ServerScriptService/ServerHandler.server.lua` | start GuardService and SightFeed | 4, 7 |
| `Scripts/ServerStorage/RenseiTests/GuardKit.lua` (new) | shared fixture | 4 |
| `Scripts/ServerStorage/RenseiTests/Play_Guard.lua` (new) | routine cases | 4 |
| `Scripts/ServerStorage/RenseiTests/Play_GuardRadio.lua` (new) | check-ins, call, alarm | 5 |
| `Scripts/ServerStorage/RenseiTests/Play_GuardMemory.lua` (new) | noises, last known, lines | 6 |
| `Scripts/ServerScriptService/SightFeed.lua` (new) | per-player awareness rows | 7 |
| `Scripts/ServerStorage/RenseiTests/Play_SightFeed.lua` (new) | feed cases | 7 |
| `Scripts/ReplicatedStorage/Modules/UI/GuardSightUI.lua` (new) | cones and markers | 8 |
| `Scripts/ReplicatedStorage/Modules/UI/StealthUI.lua` | export `Hidden` | 8 |
| `Scripts/StarterPlayer/StarterPlayerScripts/UIHandler.client.lua` | start GuardSightUI | 8 |
| `Art/Studio/Stealth/survey_stealth.lua`, `survey_ye.json`, `survey_foundry.json` (new) | Task 1 survey | 1 |
| `Art/Studio/Stealth/client_checks.lua` (new) | real-client cone and marker checks | 8 |
| `Art/Studio/Stealth/demo.lua` (new) | a Play-only demo net | 9 |
| `Documents/Changelog.md`, `Documents/Backlog.md`, `Documents/COMBAT_SYSTEM.md`, `README.md` | docs | 10 |
| `Art/Studio/Regions/Foundry/data/sync_manifest.json`, `test_sync.py` | pairs and pins | every script task |

---

## Each task can be rejected on its own

- **Tasks 1–3** change nothing a player can see. The survey is read-only plus one Play probe. Task 2 adds data that no spawn uses. Task 3's listeners have no subscriber, and `PickLookers` defaults to today's rule.
- **Task 4** changes only rigs that have a net (none in the live world).
- **Task 5** changes only rigs that have a net.
- **Task 6** changes only rigs that have a net.
- **Task 7** sends data nobody draws yet.
- **Task 8** is the one visible change for every player: cones while crouched, and markers.
- **Task 9** is Play-only.
- **Task 10** is docs only.

---

### Task 1: Parity and the read-only survey

**Files:**
- Create: `Art/Studio/Stealth/survey_stealth.lua`, `Art/Studio/Stealth/survey_ye.json`, `Art/Studio/Stealth/survey_foundry.json`

**Interfaces:**
- Produces: the survey JSONs (later tasks cite them), and a ruling on A4 (Mover or the fallback).

- [ ] **Step 1: Parity.** `sync.py --place ye --check` and `--place foundry --check` both print `DIFFER 0 / MISSING 0`, and `python -I Art/Studio/Regions/Foundry/data/test_sync.py` passes. If not, stop and report.
- [ ] **Step 2: The Edit survey.** Write `survey_stealth.lua` (read-only, Edit). It returns JSON with:
  - **`Remotes`:** whether `ReplicatedStorage.Remotes.TownsfolkSay` exists (and its class), whether `GuardSight` exists (it must not), and whether `Instance.new("UnreliableRemoteEvent")` succeeds (made and destroyed in a pcall, never parented).
  - **`Tags`:** counts of `RenseiEnemySpawn` in workspace by `EnemyType`. Also any part with a `Net`, `Route` or `Lookout` attribute (expect none), and any `RenseiPatrolRoute` or `RenseiBarracks` tag (expect none).
  - **`Mover`:** `TownsfolkService.Mover`'s path and `typeof(Mover.WalkTo)`.
  - **`StealthUI`:** the Studio path of `Modules.UI.StealthUI` and whether its source matches the repo file (`sync.norm_hash` in Python on the read source). It **isn't in the manifest** today. Task 8 adds the pair (`Create: false`).
  - **`Kit`:** `TakedownKit.Spot()`'s X/Z for this place (from the source; it reads the survey JSONs).
  - **`Speech`:** `TownsfolkService.SayRadius`.
- [ ] **Step 3: The Play probe** (Ye, `Ye:stealth1`, the full Play protocol). It answers A4 with one probe run through LMRunSuite as a temporary suite module `ServerStorage.RenseiTests.StealthProbe_TEMP` (removed after), inside `TakedownKit.Guard`:
  1. `Kit.Spawn("Grunt", Kit.Spot() * CFrame.new(0, 0, 0))`, then `Kit.Free(Rig)`.
  2. `Mover.WalkTo(Rig, CFrame.new(Spot + Vector3.new(16, 0, 0)), {Speed = 8, OnDone = record})`. Record the result within 6 s, the distance to the goal, and `Humanoid.WalkSpeed`.
  3. `Mover.Stop(Rig)`, `Humanoid.WalkSpeed = 14`, then `Humanoid:MoveTo(Spot)`. Record whether the rig moved more than 4 studs in 2 s and `Humanoid.AutoRotate` (want true).
  4. Leave `AIPassive`. Then `PerceptionService.Alarm(Rig, Player)` and `Kit.Run(0.4)`, and record `EnemyService.Active[Rig].Target == Character` within 2 s (Brain picks the target after Stop).
  - Results go to `survey_ye.json` under `Probe`. **If 2–4 don't all hold, the controller rules the A4 fallback** before Task 4 and records it in the ledger.
- [ ] **Step 4:** Run the Edit survey in Foundry too (`survey_foundry.json`, no probe: same code, same Mover).
- [ ] **Step 5: Commit** the three files: `"Stealth 1 Task 1: read-only survey (remotes, tags, Mover probe with an enemy rig, StealthUI parity)"`.

---

### Task 2: `Rensei.Guard`, the guard types and the pure rules

**Files:**
- Create: `Scripts/ReplicatedStorage/Modules/Data/Rensei/Guard.lua`, `Scripts/ServerStorage/RenseiTests/Test_Guard.lua`
- Modify: `Perception.lua:30-43` (types), `Takedown.lua:56` (classes), `TuningConfig.lua` (after the trial loop, before "Weapon dash attacks", about line 1158)
- Manifest: `Rensei.Guard` and `RenseiTests.Test_Guard` (`Create: true`); pins +2 in both places.

**Interfaces:**
- Produces (exact names later tasks use):
  - `Guard.CheckInEvery, Guard.CheckInGrace, Guard.RadioTime, Guard.RadioDelay, Guard.TightSeconds, Guard.Reinforcements, Guard.MaxReinforcements, Guard.ReinforceDelay, Guard.PatrolSpeed, Guard.PatrolPause, Guard.PostSlack, Guard.LookoutSweep, Guard.LookoutPeriod, Guard.MaxWalkFails, Guard.LineCooldown, Guard.FeedRange, Guard.FeedCount, Guard.FeedHz, Guard.FeedKeepAlive, Guard.MarkerHeight`;
  - `Guard.EnemyTypes` (set of the three type names);
  - `Guard.Lines[Kind]`, for Kind = `"Suspicious" | "Search" | "Radio" | "Calm" | "Missing"`;
  - `Guard.Line(Kind, Rng) -> string`;
  - `Guard.NextPoint(Count, Index, Dir, Loop) -> Index, Dir`;
  - `Guard.CheckInDue(LastCheckIn, Now) -> boolean`;
  - `Guard.Missed(LastCheckIn, Now) -> boolean`;
  - `Guard.Sweep(T) -> degrees`;
  - `Guard.Quantize(A) -> number`;
  - `Guard.Tint(Aware, Phase) -> Color3`;
  - `Guard.Marker(Aware, Phase) -> {Show, Fill, Ring, Solid}`;
  - `Guard.ConeFan(Range, Degrees, Segments) -> {{Vector3, Vector3, Vector3}}`;
  - `Guard.Colours = {Pale, Amber, Red}`, `Guard.ConeAlpha = {Full, Half}`;
  - `Guard.Nearest(Points, Where) -> index, distance`.

- [ ] **Step 1: Write `Test_Guard`** (pure, run through LMRunSuite like `Test_Takedown`). Every expected value is written by hand:

```lua
-- Test_Guard (stealth missions Plan 1 Task 2): the pure rules of Rensei.Guard. No Instance is read.
local G = require(game.ReplicatedStorage.Modules.Data.Rensei.Guard)
local P = require(game.ReplicatedStorage.Modules.Data.Rensei.Perception)
local Tk = require(game.ReplicatedStorage.Modules.Data.Rensei.Takedown)
local Tuning = require(game.ReplicatedStorage.Modules.Data.Rensei.TuningConfig)
return {
	Numbers = function(T)
		T.Eq(G.CheckInEvery, 45); T.Eq(G.CheckInGrace, 30); T.Eq(G.RadioTime, 2); T.Eq(G.RadioDelay, 3)
		T.Eq(G.TightSeconds, 600); T.Eq(G.Reinforcements, 2); T.Eq(G.MaxReinforcements, 4); T.Eq(G.ReinforceDelay, 6)
		T.Eq(G.PatrolSpeed, 8); T.Eq(G.PatrolPause, 3); T.Eq(G.FeedRange, 60); T.Eq(G.FeedCount, 8)
	end,
	Types = function(T)
		T.Eq(P.Types.Sentry.Range, 60); T.Eq(P.Types.Sentry.Fill, 0.6)
		T.Eq(P.Types.Officer.Range, 40); T.Eq(P.Types.Officer.Fill, 1.2)
		T.Eq(P.EnemyTypes.StateGuard, "Grunt"); T.Eq(P.EnemyTypes.StateSentry, "Sentry"); T.Eq(P.EnemyTypes.StateOfficer, "Officer")
		T.Eq(Tk.ClassByPerception.Sentry, "Full"); T.Eq(Tk.ClassByPerception.Officer, "Full")
		for _, Name in ipairs({"StateGuard", "StateSentry", "StateOfficer"}) do
			local D = Tuning.Enemies[Name]
			T.True(D ~= nil, Name .. " exists")
			T.Eq(D.Faction, "Authority", Name .. " is Authority")
			T.True(Tk.IsLawFaction(D.Faction), Name .. " is a law faction (assassinated_guard)")
			T.Eq(D.LeashRange, 120, Name .. " leash")
			T.True(G.EnemyTypes[Name] == true, Name .. " listed")
		end
		T.Eq(Tuning.Enemies.StateOfficer.ParryChance, 0.25, "the Officer defends like an Elite")
		T.Eq(Tuning.Enemies.Grunt.Faction, nil, "a bandit has no faction (unchanged)")
	end,
	NextPoint = function(T)
		-- ping-pong over 3 points: 1 2 3 2 1 2
		local I, D = 1, 1
		local Seen = {}
		for _ = 1, 5 do I, D = G.NextPoint(3, I, D, false); table.insert(Seen, I) end
		T.Eq(table.concat(Seen, ","), "2,3,2,1,2")
		-- loop over 3 points: 1 2 3 1 2
		I, D, Seen = 1, 1, {}
		for _ = 1, 4 do I, D = G.NextPoint(3, I, D, true); table.insert(Seen, I) end
		T.Eq(table.concat(Seen, ","), "2,3,1,2")
		-- one point: stays
		T.Eq((G.NextPoint(1, 1, 1, false)), 1)
	end,
	CheckIn = function(T)
		T.Eq(G.CheckInDue(0, 44.9), false); T.Eq(G.CheckInDue(0, 45), true)
		T.Eq(G.Missed(0, 74.9), false); T.Eq(G.Missed(0, 75), true)
	end,
	Sweep = function(T)
		T.Near(G.Sweep(0), 0, 0.01); T.Near(G.Sweep(1.5), 45, 0.01); T.Near(G.Sweep(4.5), -45, 0.01); T.Near(G.Sweep(6), 0, 0.01)
	end,
	Quantize = function(T)
		T.Eq(G.Quantize(0), 0); T.Eq(G.Quantize(0.024), 0); T.Eq(G.Quantize(0.026), 0.05); T.Eq(G.Quantize(1.2), 1); T.Eq(G.Quantize(-1), 0)
	end,
	Tint = function(T)
		local function Same(A, B) return math.abs(A.R - B.R) < 0.01 and math.abs(A.G - B.G) < 0.01 and math.abs(A.B - B.B) < 0.01 end
		T.True(Same(G.Tint(0, "Unaware"), Color3.fromRGB(230, 226, 214)), "pale at 0")
		T.True(Same(G.Tint(0.35, "Suspicious"), Color3.fromRGB(240, 176, 64)), "amber at Suspicion")
		T.True(Same(G.Tint(0.2, "Alert"), Color3.fromRGB(214, 64, 52)), "red at Alert, whatever the meter")
		local Mid = G.Tint(0.175, "Unaware")
		T.True(Mid.G < 226 / 255 and Mid.G > 176 / 255, "between pale and amber on the way up")
	end,
	Marker = function(T)
		local M = G.Marker(0, "Unaware"); T.Eq(M.Show, false)
		M = G.Marker(0.2, "Unaware"); T.Eq(M.Show, true); T.Near(M.Fill, 0.2, 0.001); T.Eq(M.Ring, false); T.Eq(M.Solid, false)
		M = G.Marker(0.5, "Suspicious"); T.Eq(M.Ring, true); T.Eq(M.Solid, false)
		M = G.Marker(0.4, "Alert"); T.Eq(M.Show, true); T.Eq(M.Fill, 1); T.Eq(M.Ring, true); T.Eq(M.Solid, true)
		M = G.Marker(0, "Alert"); T.Eq(M.Show, true, "an Alert guard shows even with no meter for you")
	end,
	ConeFan = function(T)
		local Tris = G.ConeFan(30, 110, 4)
		T.Eq(#Tris, 4)
		local A, B, C = Tris[1][1], Tris[1][2], Tris[4][3]
		T.Near(A.Magnitude, 0, 0.001, "every triangle starts at the feet")
		T.Near(B.Magnitude, 30, 0.01, "the rim is at range")
		-- the fan's edges are 55 degrees either side of straight ahead (-Z)
		T.Near(math.deg(math.atan2(-B.X, -B.Z)), 55, 0.1)
		T.Near(math.deg(math.atan2(-C.X, -C.Z)), -55, 0.1)
		T.Eq(B.Y, 0); T.Eq(C.Y, 0)
	end,
	Nearest = function(T)
		local I, D = G.Nearest({Vector3.new(10, 0, 0), Vector3.new(0, 0, 3), Vector3.new(-5, 0, 0)}, Vector3.zero)
		T.Eq(I, 2); T.Near(D, 3, 0.001)
		T.Eq((G.Nearest({}, Vector3.zero)), nil)
	end,
	Lines = function(T)
		for _, K in ipairs({"Suspicious", "Search", "Radio", "Calm", "Missing"}) do
			T.True(#G.Lines[K] >= 2, K .. " has lines")
			local L = G.Line(K, Random.new(1))
			T.True(type(L) == "string" and #L > 0 and #L <= 60, K .. " line is short")
		end
		T.Eq(G.Line("Nope", Random.new(1)), nil)
	end,
}
```

- [ ] **Step 2: RED.** Sync only `RenseiTests.Test_Guard` (with its pin) and run it in Ye Play (`Ye:stealth2`). Every test fails (the module is missing).
- [ ] **Step 3: Write `Guard.lua`:**

```lua
-- Guard (stealth missions Plan 1, 2026-10-29; spec Documents/specs/2026-10-25-stealth-missions-design.md §3-4): the
-- numbers, the lines and the pure rules of guards that think and of seeing what they see. GuardService (server) runs
-- the routine and the radio; SightFeed (server) sends each player their own awareness rows; GuardSightUI (client)
-- draws the cones and markers. No Instance is read here, so RenseiTests.Test_Guard checks it without a game.
-- Every number, name and line is a PROPOSAL (spec: inspired by stealth classics, never copied).
local Guard = {}

-- the radio (spec §3.1, §3.3)
Guard.CheckInEvery = 45 -- seconds between a guard's check-ins
Guard.CheckInGrace = 30 -- a check-in this late is missed: the net searches the guard's post
Guard.RadioTime = 2 -- seconds an Alert guard stands still to radio the net; knocked out meanwhile = no alarm
Guard.RadioDelay = 3 -- a noise only look-outs heard reaches the nearest free guard this much later
Guard.TightSeconds = 600 -- after an alarm the net calms to Cautious, never Normal, this long
Guard.Reinforcements = 2 -- per barracks, per alarm
Guard.MaxReinforcements = 4 -- alive per net at once
Guard.ReinforceDelay = 6 -- seconds from the alarm to the barracks door opening

-- the routine
Guard.PatrolSpeed = 8 -- a patrol stroll (enemies walk 14-15 when they fight)
Guard.PatrolPause = 3 -- seconds at each patrol point (a point's Pause attribute wins)
Guard.PostSlack = 3 -- a post guard further than this from its post walks back
Guard.LookoutSweep = 45 -- degrees either side of the post's facing
Guard.LookoutPeriod = 6 -- seconds for one full sweep (there and back)
Guard.MaxWalkFails = 3 -- failed legs in a row before a guard stands where it is
Guard.LineCooldown = 8 -- seconds between two lines from one guard

-- seeing what they see (spec §4.1)
Guard.FeedRange = 60 -- studs: the enemies whose awareness of you is sent to you
Guard.FeedCount = 8 -- at most this many, the nearest
Guard.FeedHz = 5
Guard.FeedKeepAlive = 1 -- seconds: the rows are sent again this often even when unchanged (unreliable events drop)
Guard.MarkerHeight = 4.2 -- studs above the Head (the speech bubble is at 2.6)
Guard.Colours = {
	Pale = Color3.fromRGB(230, 226, 214), -- knows nothing
	Amber = Color3.fromRGB(240, 176, 64), -- suspicion building
	Red = Color3.fromRGB(214, 64, 52), -- Alert
}
Guard.ConeAlpha = {Full = 0.78, Half = 0.9} -- transparency of the full-rate cone and the fainter half-rate band
Guard.ConeSegments = {Full = 6, Half = 2} -- triangles in the full cone; in each half-rate band

Guard.EnemyTypes = {StateGuard = true, StateSentry = true, StateOfficer = true}

Guard.Lines = {
	Suspicious = {"Hm? Who's there?", "Did something move?", "I heard that.", "Show yourself."},
	Search = {"Spread out. Find them.", "Check the corners.", "They can't have gone far."},
	Radio = {"Intruder! All posts, respond!", "Contact! Sending word to every post!"},
	Calm = {"Nothing. Just the wind.", "Must be the night playing tricks.", "Back to it."},
	Missing = {"No word from that post. Going to look.", "Someone's not answering. Checking."},
}

function Guard.Line(Kind, Rng)
	local L = Guard.Lines[Kind]
	if not L or #L == 0 then return nil end
	return L[(Rng or Random.new()):NextInteger(1, #L)]
end

-- the patrol point after Index on a route of Count points. Loop: 1..Count, then 1 again; else back and forth.
function Guard.NextPoint(Count, Index, Dir, Loop)
	if Count <= 1 then return 1, 1 end
	if Loop then return Index % Count + 1, 1 end
	local Next = Index + Dir
	if Next > Count or Next < 1 then Dir = -Dir; Next = Index + Dir end
	return Next, Dir
end

function Guard.CheckInDue(Last, Now) return Now - Last >= Guard.CheckInEvery end
function Guard.Missed(Last, Now) return Now - Last >= Guard.CheckInEvery + Guard.CheckInGrace end

-- a look-out's facing offset (degrees) T seconds into its sweep: a triangle wave 0 -> +Sweep -> -Sweep -> 0
function Guard.Sweep(T)
	local P = (T % Guard.LookoutPeriod) / Guard.LookoutPeriod
	local S = Guard.LookoutSweep
	if P < 0.25 then return S * P * 4 end
	if P < 0.75 then return S * (1 - (P - 0.25) * 4) end
	return -S * (1 - (P - 0.75) * 4)
end

function Guard.Quantize(A)
	return math.clamp(math.floor((tonumber(A) or 0) * 20 + 0.5) / 20, 0, 1)
end

-- the cone's colour: pale -> amber as the meter goes 0 -> Suspicious (0.35), amber above it, red at Alert
local SUSPICIOUS = 0.35 -- Perception.Suspicious (Test_Guard checks the tint at this value by hand)
function Guard.Tint(Aware, Phase)
	if Phase == "Alert" then return Guard.Colours.Red end
	return Guard.Colours.Pale:Lerp(Guard.Colours.Amber, math.clamp((Aware or 0) / SUSPICIOUS, 0, 1))
end

-- the marker over a guard's head: shown while its meter for you is above zero (or it is Alert); the fill follows the
-- meter; a ring from Suspicion on and a solid red fill at Alert, so colour is never the only signal (spec §4.1)
function Guard.Marker(Aware, Phase)
	local A = math.clamp(Aware or 0, 0, 1)
	if Phase == "Alert" then return {Show = true, Fill = 1, Ring = true, Solid = true} end
	return {Show = A > 0, Fill = A, Ring = Phase == "Suspicious" or A >= SUSPICIOUS, Solid = false}
end

-- a flat fan of Segments triangles from the feet (the origin) to Range, Degrees wide, centred on -Z (forward), in
-- the guard's local space at its feet. Each triangle is {feet, rim point (left), rim point (right)}.
function Guard.ConeFan(Range, Degrees, Segments)
	local Out = {}
	local Half = math.rad(Degrees / 2)
	local function Rim(A) return Vector3.new(-math.sin(A) * Range, 0, -math.cos(A) * Range) end
	for I = 0, Segments - 1 do
		local A0 = Half - (2 * Half) * I / Segments
		local A1 = Half - (2 * Half) * (I + 1) / Segments
		table.insert(Out, {Vector3.zero, Rim(A0), Rim(A1)})
	end
	return Out
end

-- the nearest of Points (Vector3s) to Where, on the ground plane: index, distance; nil for an empty list
function Guard.Nearest(Points, Where)
	local Best, BestD = nil, math.huge
	for I, Pt in ipairs(Points) do
		local D = Vector3.new(Pt.X - Where.X, 0, Pt.Z - Where.Z).Magnitude
		if D < BestD then Best, BestD = I, D end
	end
	return Best, Best and BestD or nil
end

return Guard
```

  - In `Perception.lua`, add `Sentry` and `Officer` to `Perception.Types` and the three rows to `Perception.EnemyTypes`, each with a `-- stealth missions Plan 1 Task 2 (PROPOSAL)` comment:
    ```lua
    	Sentry = {Range = 60, Fill = 0.6}, -- (stealth Plan 1, PROPOSAL) look-outs: long sight, slow to fill
    	Officer = {Range = 40, Fill = 1.2}, -- (stealth Plan 1, PROPOSAL) reads disguises faster (Plan 2)
    ```
    and in `EnemyTypes`: `StateGuard = "Grunt", StateSentry = "Sentry", StateOfficer = "Officer",`.
  - In `Takedown.lua:56`: `Takedown.ClassByPerception = {Grunt = "Full", Agent = "Full", Elite = "Chunk", Hunter = "Chunk", Sentry = "Full", Officer = "Full"}`, with a comment naming Plan 1 Task 2 and D4.
  - In `TuningConfig.lua`, after the trial loop's `end` and before the "Weapon dash attacks" comment:
    ```lua
    -- State guards (stealth missions Plan 1 Task 2, 2026-10-29; spec §3; all PROPOSALS): the Authority's own. Their
    -- faction makes a takedown of one the assassinated_guard deed (TakedownService.DeedFor). No spawn uses them yet:
    -- a later plan places them (compounds), Art/Studio/Stealth/demo.lua spawns them in Play.
    for Name, Over in pairs({
    	StateGuard = {Base = "Grunt", DisplayName = "State Guard", Level = 4, Health = 500},
    	StateSentry = {Base = "Grunt", DisplayName = "State Sentry", Level = 4, Health = 450},
    	StateOfficer = {Base = "Elite", DisplayName = "State Officer", Level = 6, Health = 950},
    }) do
    	local D = table.clone(TuningConfig.Enemies[Over.Base])
    	for K, V in pairs(Over) do if K ~= "Base" then D[K] = V end end
    	D.Faction = "Authority" -- Heat.Law.State
    	D.Nation = "Amestrian"
    	D.LeashRange = 120 -- room for a patrol route around the spawn
    	TuningConfig.Enemies[Name] = D
    end
    ```
- [ ] **Step 4: GREEN.** Sync `Rensei.Guard`, `Rensei.Perception`, `Rensei.Takedown`, `Rensei.TuningConfig` and `RenseiTests.Test_Guard` to both places. In a new Ye Play session: `Test_Guard` passes. `Test_Takedown`, `Test_Perception` and `Play_Perception` are unchanged.
- [ ] **Step 5:** `--check` both places: `DIFFER 0 / MISSING 0`. Then `test_sync.py` passes.
- [ ] **Step 6: Commit** `Guard.lua`, `Test_Guard.lua`, `Perception.lua`, `Takedown.lua`, `TuningConfig.lua`, `sync_manifest.json`, `test_sync.py`: `"Stealth 1 Task 2: Rensei.Guard (numbers, lines, route stepping, check-in clock, cone fan, tint, marker), Sentry/Officer perception types, three State guard types"`.

---

### Task 3: PerceptionService hooks

**Files:**
- Modify: `Scripts/ServerScriptService/PerceptionService.lua`
- Create: `Scripts/ServerStorage/RenseiTests/Play_GuardSense.lua`
- Manifest: `RenseiTests.Play_GuardSense` (`Create: true`); pins +1 in both places.

**Interfaces:**
- Produces:
  - `PerceptionService.PhaseChanged`: a list of listeners `(Rig, New, Old)`, each run in a pcall, deferred with `task.defer`. That way a listener never runs inside Decide's loop over the NPCs.
  - `PerceptionService.LostSight`: listeners `(Rig, Where)`, fired once when an Alert NPC starts searching for a focus it lost (Decide's `not S.SearchUntil` branch, when `S.Focus` was set).
  - `PerceptionService.Heard`: listeners `(Hearers, Position, Kind, Source)`, fired once per `Hear` that someone heard. `Hearers` is a list of rigs.
  - `PerceptionService.PickLookers(Hearers, Position, Kind) -> list of rigs`. By default it returns `Hearers` (today's rule). Only the returned rigs investigate.
  - `PerceptionService.Look(Rig, Where) -> boolean`: Suspicious at a spot. Refused (false) when untracked, Alert, dead, `Knocked` or `TakenDownBy`.
  - `PerceptionService.Floor(Rig, Until)`: until `Until` (perception time), the NPC never drops below Cautious. Every place that sets `CautiousUntil` takes `math.max(..., S.FloorUntil or 0)`, and an Unaware NPC is set to Cautious at once.
  - `PerceptionService.Now() -> number` (perception time).
  - `Register` sets the rig attribute `PerceptionType` (= `Info.Type`), for the client's cone range.
  - `Hear`'s return value stays **the count of all hearers** (unchanged).

- [ ] **Step 1: Write `Play_GuardSense`** (inside `TakedownKit.Guard`; `Kit.Spawn` gives Unaware, passive rigs on the floor; `Kit.Run` steps perception). Cases, each RED before the change:
  - `PhaseListenerFires`: subscribe a recorder, `PerceptionService.Raise(Rig, Spot)`, wait one `task.wait()`. The recorder saw `(Rig, "Alert", "Unaware")` exactly once. Unsubscribe in the case's clean-up (remove from the list).
  - `LostSightFiresOnce`: `Kit.PutInFront(Rig, 10)`, `Kit.Run(2.6)` (Alert on the player), `Kit.PutPlayer(Kit.AWAY)`, `Kit.Run(P.Memory + 0.6)`. LostSight fired once, with `Where` within 3 studs of where the player stood. `Kit.Run(1)` more: still once.
  - `HeardListenerAndDefaultPick`: two Grunts 6 studs from a spot, no walls. `PerceptionService.Hear(Spot, 12, "Land")` returns 2. The Heard listener got both rigs. Both are Suspicious (the default `PickLookers` keeps today's rule; this is the **control**).
  - `PickLookersFilters`: replace `PickLookers` with one that returns only the first rig (restored in clean-up). `Hear` still returns 2. One rig is Suspicious, the other Unaware.
  - `LookRefusals`: `Look` on an Unaware rig → true, and the rig is Suspicious with `Goal(Rig)` equal to the spot. On an Alert rig with a focus → false. On a rig with `Knocked = true` → false. On an untracked part → false.
  - `FloorHoldsCautious`: `Floor(Rig, Now() + 60)`. The phase is Cautious at once. `Raise`, then `Kit.Run(P.SearchTime + 1)`: the rig is Cautious. Then `Kit.Run(61)`: still Cautious (CautiousTime 180 > 61; the floor didn't shorten it). A second rig: note `F = Now() + 300`, `Floor(Rig2, F)`, `Raise(Rig2, Spot)`, `Kit.Run(P.SearchTime + 1)`. Its search has ended, and `Npcs[Rig2].CautiousUntil >= F` (the floor won over the 180 s CautiousTime).
  - `PerceptionTypeAttribute`: a spawned Grunt has `PerceptionType = "Grunt"`; a spawned `StateSentry` has `"Sentry"`.
- [ ] **Step 2: RED** in Ye Play (`Ye:stealth3`). Every case fails.
- [ ] **Step 3: Implement**, keeping every existing line's behaviour:

```lua
-- (stealth missions Plan 1 Task 3, 2026-10-29) hooks for GuardService: listeners, Look, Floor, Now, PickLookers
PerceptionService.PhaseChanged = {} -- (Rig, New, Old), deferred, each in a pcall
PerceptionService.LostSight = {} -- (Rig, Where): an Alert NPC began searching for the focus it lost
PerceptionService.Heard = {} -- (Hearers, Position, Kind, Source): a sound someone heard
local function Fire(List, ...)
	for _, Fn in ipairs(List) do
		local Ok, Err = pcall(Fn, ...)
		if not Ok then warn("PerceptionService listener:", Err) end
	end
end
-- the hearers of a sound that go to look; the default keeps the old rule (all of them). GuardService replaces it.
function PerceptionService.PickLookers(Hearers) return Hearers end
function PerceptionService.Now() return Clock end
```
  - `SetPhase`: after the attribute, `if #PerceptionService.PhaseChanged > 0 then task.defer(Fire, PerceptionService.PhaseChanged, S.Rig, Phase, Old) end`. `Old` is the phase before the change.
  - `Decide`, in the `not S.SearchUntil` branch: capture `local Lost = S.Focus ~= nil` **before** the existing lines. After them, `if Lost and S.LastKnown then task.defer(Fire, PerceptionService.LostSight, S.Rig, S.LastKnown) end`.
  - The **floor**, in each of these three places:
    - in `Decide`'s search end: `S.CautiousUntil = math.max(T + P.CautiousTime, S.FloorUntil or 0)`;
    - in `Lose`: `S.CautiousUntil = math.max(Now() + P.CautiousTime, S.FloorUntil or 0)`;
    - in `Reset`: `S.FloorUntil = nil` (a reset is a fresh NPC).
  - `Floor`:
    ```lua
    function PerceptionService.Floor(Rig, Until)
    	local S = Npcs[Rig]
    	if not S or type(Until) ~= "number" then return end
    	S.FloorUntil = math.max(S.FloorUntil or 0, Until)
    	S.CautiousUntil = math.max(S.CautiousUntil, S.FloorUntil)
    	if S.Phase == "Unaware" then SetPhase(S, "Cautious") end
    end
    ```
  - `Look`:
    ```lua
    function PerceptionService.Look(Rig, Where)
    	local S = Npcs[Rig]
    	if not S or typeof(Where) ~= "Vector3" or S.Phase == "Alert" or not Alive(Rig)
    		or Rig:GetAttribute("Knocked") or Rig:GetAttribute("TakenDownBy") then return false end
    	Investigate(S, Where, Now())
    	return true
    end
    ```
    Move the `local function Investigate` above `Look` if needed. It is unchanged.
  - `Hear`: collect the rigs that pass the muffled check into `Hearers` instead of calling `Investigate` inline. Then:
    ```lua
    if #Hearers == 0 then return 0 end
    local Pick = PerceptionService.PickLookers(Hearers, Position, Kind) or Hearers
    for _, Rig in ipairs(Pick) do local S = Npcs[Rig] if S then Investigate(S, Position, T) end end
    Fire(PerceptionService.Heard, Hearers, Position, Kind, Source)
    return #Hearers
    ```
    A `PickLookers` that errors falls back to `Hearers`: wrap the call in a pcall.
  - `Register`: `Rig:SetAttribute("PerceptionType", S.Type)`.
  - Add a header paragraph naming Plan 1 Task 3 and each hook, in the file's style.
- [ ] **Step 4: GREEN.** Sync `RenseiServer.PerceptionService` and `RenseiTests.Play_GuardSense` to both places. In Ye Play: `Play_GuardSense` all pass. The regressions are unchanged: `Play_Perception`, `Play_Stealth`, `Play_Takedown`, `Play_TakedownHard`, `Play_TownsfolkHurt`.
- [ ] **Step 5:** `--check` both; `test_sync.py`.
- [ ] **Step 6: Commit**: `"Stealth 1 Task 3: PerceptionService hooks (PhaseChanged, LostSight, Heard, PickLookers, Look, Floor, Now, PerceptionType)"`.

---

### Task 4: GuardService: guards, nets and the routine

**Files:**
- Create: `Scripts/ServerScriptService/GuardService.lua`, `Scripts/ServerStorage/RenseiTests/GuardKit.lua`, `Scripts/ServerStorage/RenseiTests/Play_Guard.lua`
- Modify: `EnemyService.lua` (Spawn: `Track`; Brain: the idle hook and `Interrupt`), `ServerHandler.server.lua` (start GuardService after TakedownService, in a pcall like HostageService)
- Manifest: `RenseiServer.GuardService`, `RenseiTests.GuardKit`, `RenseiTests.Play_Guard` (`Create: true`); pins +3 in both places.

**Interfaces:**
- Consumes: `Rensei.Guard` (Task 2); `PerceptionService.PhaseOf`, `Now` (Task 3); `TownsfolkService.Mover.WalkTo/Stop/Handle`.
- Produces:
  - `GuardService.Guards[Rig] = G`, where G has these fields:
    - `{Rig, Net, Route = {CFrame...} | nil, Loop, Lookout, Post (CFrame), Speed (the def's WalkSpeed)}`;
    - `Index, Dir, PauseUntil, Fails`;
    - `LastCheckIn, Missed, LastLineAt`;
    - `Reinforcement` (bool);
    - `Walk` (the Mover handle or nil).
  - `GuardService.Nets[Name] = {Name, Guards = {[Rig] = G}, Barracks = {Part...}, Alarm = false, AlarmAt, TightUntil = 0, Calling = nil, Lost = {}, Reinforced = {}}`.
  - `GuardService.Track(Rig, Info) -> G`. `Info = {Net = string (required), Route = {CFrame...}?, Loop = bool?, Lookout = bool?, Post = CFrame?, Speed = number?}`. Without `Post`, the post is the rig's root CFrame at Track. A rig without a `Net` is refused (nil).
  - `GuardService.Untrack(Rig)`.
  - `GuardService.Idle(Rig) -> nil | "walking" | "standing"`. The Brain's no-target, no-goal branch: nil means "not a guard, do the old thing".
  - `GuardService.Interrupt(Rig)`: stops a routine walk and puts back `Humanoid.WalkSpeed = G.Speed`.
  - `GuardService.SetAuto(On)`, `GuardService.Step(Dt)`, `GuardService.Now()`. GuardService's own clock, as PerceptionService's; the live loop steps it on Heartbeat every 0.2 s.
  - `GuardService.Start()`.
  - **World data**, read at spawn by `EnemyService.Spawn`:
    - a spawn part's `Net` (string), `Route` (string), `Lookout` (bool);
    - a route is any Model or Folder tagged `RenseiPatrolRoute` with attribute `Route` = the name and `Loop` (bool). Its BasePart children are named `"1"`, `"2"`, …, ordered by number, each CFrame a standing spot and facing. A point's attribute `Pause` (seconds) is optional.
    - a barracks is a BasePart tagged `RenseiBarracks`, with `Net` and an optional `ReinforceType` (default `"StateGuard"`).
  - `RenseiTests.GuardKit`:
    - `GuardKit.Guard(Body)`: refuses unless `DataManager.IsNoSave()`. Then it runs `TakedownKit.Guard`, with `GuardService.SetAuto(false)` inside and `GuardService.Reset()` plus `SetAuto(true)` in its clean-up.
    - `GuardKit.Net(Name)`: a fresh net name, unique per case.
    - `GuardKit.Guardsman(Type, At, Info)`: `Kit.Spawn` then `Kit.Free`, then `GuardService.Track(Rig, Info)`.
    - `GuardKit.Route(Offsets)`: CFrames on the kit floor from `Kit.Spot()`, each facing the next.
    - `GuardKit.Step(Seconds)`: `GuardService.Step(0.2)` and `Kit.Run(0.2)` alternately, with a `task.wait(0.2)` so the Brain and Mover run in real time.
  - `GuardService.Reset()` (tests): untracks every guard, clears nets and stops walks.

- [ ] **Step 1: Write `GuardKit` and `Play_Guard`.** Cases (RED before GuardService exists):
  - `TrackRefusesWithoutNet`: `Track(Rig, {})` → nil; `Guards[Rig]` is nil.
  - `PatrolWalksTheRoute`: a 3-point route 14 studs apart (a straight line), not looping. Within 20 s real time the guard has been within 2.5 studs of point 2 and of point 3, then point 2 again (ping-pong). It pauses about 3 s at a point: it stands still (root speed < 1) for at least 2.5 s after reaching point 3. Its `Humanoid.WalkSpeed` is 8 while walking.
  - `AlertInterruptsTheWalk`: mid-leg, `PerceptionService.Alarm(Rig, Player)`, then `Kit.Run(0.4)`, `task.wait(0.5)`. `Mover.Handle(Rig)` is nil, `Humanoid.WalkSpeed` is the def's 14, and `EnemyService.Active[Rig].Target` is the player's character.
  - `RoutineResumesAfterCalm`: after the alarm case, `PerceptionService.Lose(Rig)`. Within 10 s the guard walks again (the Mover handle is not nil, with status "walking").
  - `PostGuardReturns`: a post guard (no route). The kit moves it 8 studs off (`PivotTo`). Within 8 s it's within 3 studs of its post and faces the post's facing within 20°.
  - `LookoutSweeps`: a `StateSentry` look-out. Over 6 s of `GuardKit.Step`, its facing moves more than 60° in total and stays within ±50° of the post's. It stays within 3 studs of the post.
  - `FailedLegsStop`: a route whose point 2 is inside a sealed box (`Kit.Wall` on all sides). After 3 failed legs (`Fails` = 3), the guard stands. No error, and one warn at most.
  - `DeathUntracks`: `Humanoid.Health = 0`, then `task.wait(0.2)`. `Guards[Rig]` is nil, and the net no longer lists it (Task 5 keeps a `Lost` record; here only the routine's untracking is checked).
  - `SpawnWithNetIsTracked`: an unparented spawn part with `EnemyType = "StateGuard"` and `Net = <net>`, through `EnemyService.Spawn(Part)`. The rig is in `Guards` with that net and its `Post` at the part. Cleaned up by `Kit.Clean`'s enemy sweep.
  - **Control** `BanditUnchanged`: a plain Grunt (no Track) moved 8 studs from home walks home with `Humanoid:MoveTo` (it arrives within 8 s). `Mover.Handle(Rig)` stays nil throughout.
- [ ] **Step 2: RED** in Ye Play (`Ye:stealth4`).
- [ ] **Step 3: Implement `GuardService`.** The structure (the header names Plan 1 Task 4 and the rules A4, A5 and D8):

```lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local G = require(ReplicatedStorage.Modules.Data.Rensei.Guard)
local PerceptionService = require(ServerScriptService.PerceptionService)
local Mover = require(ServerScriptService.TownsfolkService.Mover)

local GuardService = {}
local Guards, Nets = {}, {}
GuardService.Guards, GuardService.Nets = Guards, Nets

local Clock = 0
function GuardService.Now() return Clock end

local function Alive(M) local H = M and M:FindFirstChildOfClass("Humanoid") return H ~= nil and H.Health > 0 end
local function Free(Rig) -- can act on its own: not down, held or being taken
	return Alive(Rig) and Rig:IsDescendantOf(workspace) and not Rig:GetAttribute("Knocked")
		and not Rig:GetAttribute("TakenDownBy") and not Rig:GetAttribute("GrippedBy") and not Rig:GetAttribute("CarriedBy")
end
GuardService.Free = Free

local function NetOf(Name)
	local N = Nets[Name]
	if not N then
		N = {Name = Name, Guards = {}, Barracks = {}, Alarm = false, AlarmAt = nil, TightUntil = 0, Calling = nil, Lost = {}, Reinforced = {}}
		Nets[Name] = N
	end
	return N
end
GuardService.NetOf = NetOf

function GuardService.Track(Rig, Info)
	if type(Info) ~= "table" or type(Info.Net) ~= "string" or Info.Net == "" then return nil end
	local Root = Rig:FindFirstChild("HumanoidRootPart")
	local Hum = Rig:FindFirstChildOfClass("Humanoid")
	if not (Root and Hum) then return nil end
	local Net = NetOf(Info.Net)
	local Gd = {
		Rig = Rig, Net = Net, Route = Info.Route, Loop = Info.Loop == true, Lookout = Info.Lookout == true,
		Post = Info.Post or Root.CFrame, Speed = Info.Speed or Hum.WalkSpeed,
		Index = 1, Dir = 1, PauseUntil = 0, Fails = 0, SweepT = 0,
		LastCheckIn = Clock, Missed = false, LastLineAt = -math.huge, Reinforcement = Info.Reinforcement == true,
	}
	Guards[Rig], Net.Guards[Rig] = Gd, Gd
	Hum.Died:Once(function() GuardService.Untrack(Rig, "died") end)
	Rig.Destroying:Once(function() GuardService.Untrack(Rig, "gone") end)
	return Gd
end
```
  - **`Untrack(Rig, Why)`:** removes the rig from `Guards` and `Net.Guards` and `Mover.Stop`s it if a routine walk is active. Task 5 extends it to leave a `Lost` record.
  - **`Interrupt(Rig)`:** if `G.Walk` is set, `Mover.Stop(Rig)`, `G.Walk = nil`, then `Humanoid.WalkSpeed = G.Speed`.
  - **`Idle(Rig)`:** returns nil when the rig isn't a guard. Otherwise, in order:
    1. **Look-out or post guard:**
       - more than `PostSlack` from its post: walk there (`Mover.WalkTo(Rig, G.Post, {Speed = G.Speed})`, so a post guard walks back at its own pace) → "walking";
       - otherwise, a look-out sets `Root.CFrame = CFrame.new(Root.Position) * G.Post.Rotation * CFrame.Angles(0, math.rad(G.Sweep(G.SweepT)), 0)`, with `G.SweepT` advanced by Idle's real Dt (`os.clock()` delta, capped at 0.5) → "standing";
       - otherwise, a post guard faces its post once on arrival (the Mover's arrival turn does it) → "standing".
    2. **Patrol (route):**
       - a walk in progress → "walking";
       - otherwise, while `PauseUntil > os.clock()` → "standing";
       - otherwise, walk to `Route[G.Index]` at `Guard.PatrolSpeed`. `OnDone`:
         - "arrived": `Fails = 0`, `PauseUntil = os.clock() + (point pause or Guard.PatrolPause)`, then the index steps with `Guard.NextPoint`;
         - "failed": `Fails += 1`, step the index the same way, and `PauseUntil = os.clock() + 2`;
         - "cancelled": nothing (Interrupt did it).
       - When `Fails >= Guard.MaxWalkFails` → "standing" for good, with one `warn` naming the rig and the point.
    - Routine timing uses `os.clock()`, because the routine is real movement. Only the radio and the memory (Tasks 5–6) use GuardService's stepped clock.
  - **Start():**
    - reads tagged `RenseiPatrolRoute` folders into `Routes[Name] = {Points = {CFrame...}, Pauses = {number?...}, Loop}` (and watches the tag);
    - reads `RenseiBarracks` parts into their nets (and watches);
    - runs the Heartbeat loop (`if Auto then Step(Acc) every 0.2 s`, in a pcall).
  - **`GuardService.RouteFor(Name)`** returns the route's points and loop flag, for `EnemyService.Spawn`.
  - **EnemyService:**
    - **Spawn:** after `PerceptionService.Register`, `local Net = Part:GetAttribute("Net")`. If it's a non-empty string, call `Guard().Track(Rig, {Net = Net, Route = <points of RouteFor(Part:GetAttribute("Route"))>, Loop = ..., Lookout = Part:GetAttribute("Lookout") == true, Speed = Def.WalkSpeed})`, with no `Post`: Track then takes the rig's root CFrame where BuildRig stood it, which is the post. `Guard()` is a lazy require of `ServerScriptService.GuardService` (GuardService requires EnemyService in Task 5; the lazy require breaks the cycle, as `PerceptionService.lua:271-281` does for SwimService).
    - **Brain:** in the `if not Target then` branch, `if Goal ... then Guard().Interrupt(Rig) ... end` at the top of the goal walk. Then, before "leash: walk home", add:
      ```lua
      local Routine = Guard().Idle(Rig) -- (stealth Plan 1 Task 4) a guard on a net keeps its routine; nil = not a guard
      if Routine then SetWalking(Routine == "walking") continue end
      ```
    - When a target is picked (the code after `if not Target then ... end`), call `Guard().Interrupt(Rig)` once, guarded by a cheap `Guard().Guards[Rig]` lookup.
    - Comment each edit with "stealth Plan 1 Task 4".
- [ ] **Step 4: GREEN.** Sync `RenseiServer.GuardService`, `RenseiServer.EnemyService`, `RenseiServer.ServerHandler`, `RenseiTests.GuardKit` and `RenseiTests.Play_Guard` to both places. In Ye Play: `Play_Guard` all pass. The regressions `Play_Perception`, `Play_GuardSense`, `Play_Takedown`, `Play_TakedownHard`, `Play_Swim` and `Play_Townsfolk` are unchanged (the Mover is shared).
- [ ] **Step 5:** `--check` both; `test_sync.py`.
- [ ] **Step 6: Commit**: `"Stealth 1 Task 4: GuardService (nets, patrol routes with the Mover, posts, look-out sweep), EnemyService idle hook, GuardKit, Play_Guard"`.

---

### Task 5: The radio: check-ins, the call, the alarm and reinforcements

**Files:**
- Modify: `GuardService.lua`, `EnemyService.lua` (`Busy()` + `Radioing`)
- Create: `Scripts/ServerStorage/RenseiTests/Play_GuardRadio.lua`
- Manifest: `RenseiTests.Play_GuardRadio`; pins +1.

**Interfaces:**
- Consumes: `PerceptionService.PhaseChanged`, `Raise`, `Floor`, `Npcs[Rig].LastKnown` (Task 3); `EnemyService.Spawn` (unparented part).
- Produces:
  - `GuardService.StartCall(Gd, Where) -> boolean`;
  - `GuardService.Alarm(Net, Where)`;
  - the rig attribute `Radioing` (true during the call);
  - `Net.Calling = {Rig, Until, Where}`, `Net.LastCut = {Rig, At}` (tests), `Net.Alarms` (a count, for tests);
  - `Net.Lost[Rig] = {Post, Since, Noticed}` for a guard that died or was destroyed;
  - `GuardService.Say(Rig, Kind)`: a line to players in earshot, rate-limited per rig, through `Remotes.TownsfolkSay`.

- [ ] **Step 1: Write `Play_GuardRadio`** (each case RED first):
  - `CheckInKeepsQuiet`: a net with two post guards. `GuardKit.Step(80)` with both free: no Raise, both Unaware or Cautious, and each one's `LastCheckIn` advanced within the last 45 s.
  - `MissedCheckInSearchesThePost` (the spec's M1 check): set guard A `Knocked = true` (by hand, on a passive rig). `GuardKit.Step(76)`. Guard B is Alert and searching, with `PerceptionService.Goal(B)` within 10 studs of A's post. B said a "Missing" line (`GuardService.LastLine(B)` is a "Missing" line). It happens once: `Step(30)` more, and there is no second Raise of B by the check-in.
  - `DestroyedGuardStillMissed`: guard A's rig `:Destroy()`ed. After `Step(76)`, B is Raised at A's post, and `Net.Lost[A].Noticed` is true.
  - `AlertStartsTheCall`: `PerceptionService.Raise(A, Spot)`, `task.wait()` (the deferred listener). `A:GetAttribute("Radioing") == true`, `Net.Calling.Rig == A`, and A stands still (root speed < 1 over 1 s of real time).
  - `KnockedInTheWindowStopsTheAlarm` (the spec's radio window): start the call; at 1 s, `A:SetAttribute("Knocked", true)`. `Step(3)`: `Net.Alarm == false`, `Net.LastCut.Rig == A`, `Radioing` is cleared, B is still Unaware, and no reinforcement was spawned.
  - `CallThroughRaisesTheNet`: start the call and `Step(2.2)`. `Net.Alarm` is true; B is Alert, searching within 10 studs of the spot; `PerceptionService.Npcs[B].FloorUntil >= Now() + 599`; A's `Radioing` is cleared. A said a "Radio" line.
  - `Reinforcements`: a barracks part (`Kit.Wall`-made, tagged `RenseiBarracks`, `Net`) on the floor. After the alarm, `Step(6.4)`: exactly 2 new rigs tracked on the net with `Reinforcement = true`, of type `StateGuard`, Raised at the spot. A second alarm on the same net (after their search ends): 2 more, so 4 alive. A third: none (`MaxReinforcements`).
  - `TightCalmsToCautious`: after the alarm, `Kit.Run(P.SearchTime + 2)`. B is Cautious, not Unaware, and stays Cautious after `Kit.Run(200)` (past CautiousTime 180, inside the tight 600).
  - `ReinforcementsLeaveWhenCalm`: set `Net.TightUntil = Now()` by hand and `Step(1)`. Reinforcements that aren't Alert are gone (destroyed and untracked), and `Net.Alarm` is false.
  - `PairsWalkTheRoutes`: the net has one patrol guard on a 3-point route and a barracks. After the alarm and the search, a reinforcement's `Route` is the patrol guard's route, starting one point behind.
  - **Controls:** `NoNetNoCall`: a plain Grunt Raised never gets `Radioing`, and no net exists. `SecondGuardDoesNotDoubleCall`: two guards go Alert during A's call; only A is `Radioing`.
- [ ] **Step 2: RED** in Ye Play (`Ye:stealth5`).
- [ ] **Step 3: Implement.**
  - **Check-ins** in `Step(Dt)`, for each net:
    - each free guard that is `CheckInDue` gets `LastCheckIn = Clock` and `Missed = false`;
    - each guard that isn't free and `Missed(LastCheckIn, Clock)` and not yet `Missed`: set `Missed = true` and `Notice(Net, Gd.Post.Position or its last point)`;
    - each `Lost` record that isn't yet `Noticed` and `Guard.Missed(Record.LastCheckIn, Clock)`: noticed the same way, at `Record.Post`, and `Noticed = true`. The record keeps the guard's last check-in time, so a guard lost right after checking in is missed exactly when a knocked one would be.
  - **`Notice(Net, Where)`:** the nearest free guard on the net (`Guard.Nearest` over their root positions) is `Raise`d at `Where`, and says a "Missing" line.
  - **`Untrack`**, on death or destruction, records `Net.Lost[Rig] = {Post = <post or last route point>, LastCheckIn = Gd.LastCheckIn, Noticed = false}`. A reinforcement leaves no `Lost` record.
  - **The call:** a `PhaseChanged` listener. `New == "Alert"` on a tracked guard, the net has no `Alarm` and no `Calling`, and the guard is free: `StartCall(Gd, Npcs[Rig].LastKnown or root position)`. That sets `Calling`, sets `Radioing`, says a "Radio" line and `Interrupt`s. In `Step`:
    - a `Calling` rig that isn't free (or is gone) → cut: `LastCut`, `Calling = nil`, attribute cleared;
    - `Clock >= Until` → clear the attribute, then `Alarm(Net, Where)`.
  - **`Alarm(Net, Where)`:**
    - `Alarm = true`, `Alarms += 1`, `AlarmAt = Clock`, `TightUntil = Clock + Guard.TightSeconds`;
    - every other free guard on the net: `PerceptionService.Raise(Rig, Where)`; every guard on the net: `PerceptionService.Floor(Rig, PerceptionService.Now() + Guard.TightSeconds)`;
    - schedule reinforcements at `Clock + Guard.ReinforceDelay`. When they come, each barracks spawns `min(Guard.Reinforcements, Guard.MaxReinforcements - alive reinforcements)`:
      - each is a clone of the barracks part, **unparented**, with `EnemyType = ReinforceType or "StateGuard"` and no `Net` attribute, through `EnemyService.Spawn`. Spawn refuses only a part in the DataModel outside workspace (`EnemyService.lua:5-7`), and an unparented mark never respawns;
      - then `Track` it with `Reinforcement = true`, `Raise` it at `Where` and `Floor` it.
  - **Pairs:** a reinforcement with no route that is Unaware or Cautious and not searching takes the route of a patrol guard on the net that no other reinforcement pairs with. Its `Index` is one before that guard's.
  - **Calm:** in `Step`, `Alarm` and `Clock >= TightUntil` → `Alarm = false`. Reinforcements that aren't Alert are destroyed.
  - **EnemyService `Busy()`:** add `or Rig:GetAttribute("Radioing")`, with a comment.
  - **`Say(Rig, Kind)`:** at most one line per `Guard.LineCooldown` per rig. It sends `Guard.Line(Kind)` through `ReplicatedStorage.Remotes.TownsfolkSay:FireClient(P, Rig, Text, TownsfolkLogic.SpeechSeconds(Text))`, to players within `TownsfolkService.SayRadius` of the Head, and records `LastLines[Rig] = {Text, Kind}`. `GuardService.LastLine(Rig) -> Text, Kind` is for tests. A missing remote warns once, like `TownsfolkService.Say`.
- [ ] **Step 4: GREEN.** Sync `RenseiServer.GuardService`, `RenseiServer.EnemyService` and `RenseiTests.Play_GuardRadio`. In Ye Play: `Play_GuardRadio`, `Play_Guard` and `Play_GuardSense` pass. The regressions are unchanged: `Play_Takedown` (a knockout's wake still raises), `Play_TakedownHard`, `Play_Perception`, `Play_Stealth`.
- [ ] **Step 5:** `--check` both; `test_sync.py`.
- [ ] **Step 6: Commit**: `"Stealth 1 Task 5: the radio (check-ins and missed check-ins, the 2 s call and its cut window, the net alarm, tight calm-down, reinforcements that pair on the routes)"`.

---

### Task 6: Shared memory: one guard looks, look-outs radio, last known is shared, lines

**Files:**
- Modify: `GuardService.lua`
- Create: `Scripts/ServerStorage/RenseiTests/Play_GuardMemory.lua`
- Manifest: `RenseiTests.Play_GuardMemory`; pins +1.

**Interfaces:**
- Consumes: `PerceptionService.PickLookers`, `Heard`, `LostSight`, `PhaseChanged`, `Look`, `Raise`, `BodyFound` (Task 3 and the assassinations).
- Produces: `GuardService.Pick(Hearers, Position, Kind)` (installed as `PerceptionService.PickLookers` at Start); `Net.Pending = {{At, Where}}` (radioed noises, for tests).

- [ ] **Step 1: Write `Play_GuardMemory`** (RED first):
  - `OnlyTheNearestLooks` (the spec's "only one guard goes"): three net guards at 5, 8 and 10 studs from a spot. `PerceptionService.Hear(Spot, 14, "Land")` returns 3, but only the guard at 5 studs is Suspicious. The others are unchanged.
  - `LookoutHoldsAndRadios`: a look-out at 4 studs and a patrol guard 30 studs away (out of earshot). `Hear(Spot, 12)` → the look-out stays Unaware or Cautious at its post (it didn't move off). After `GuardKit.Step(2.8)` the patrol guard isn't yet Suspicious; after `Step(0.4)` more it is, with `Goal` = the spot.
  - `NoRadioWhenSomeoneWent`: a look-out and a patrol guard both hear the noise. The patrol guard goes at once, and no `Pending` entry is made.
  - `LastKnownIsShared` (the spec's sweep from your last position): guard A Alert on the player, B Raised elsewhere (searching around a far spot). The player moves away and A loses sight, so LostSight fires at the last spot. B's `Goal` sweep is re-centred within 6 studs of that spot. A guard C that is Unaware is **not** pulled in (no alarm out).
  - `BodyFoundMakesTheCall`: an `Out` body (`Kit.AddBody`) in A's view, `Kit.Run` until found. A is `Radioing` (Raise → Alert → the call).
  - `LinesAtTheRightMoments`: one case per line kind:
    - a Suspicious turn → a "Suspicious" line;
    - a calm-down from Suspicious → a "Calm" line;
    - a lost-sight search → a "Search" line;
    - two Suspicious turns within 8 s → one line only.
  - **Control** `BanditsAllLook`: two plain Grunts both hear and both go Suspicious (GuardService's Pick keeps non-net rigs).
- [ ] **Step 2: RED** in Ye Play (`Ye:stealth6`).
- [ ] **Step 3: Implement.**
  - **`Pick`:** split `Hearers` into non-guards (kept) and, per net, its guards. For each net, keep the nearest non-look-out hearer (by distance to `Position`). If the net's hearers are all look-outs, keep none and add `{At = Clock + Guard.RadioDelay, Where = Position}` to `Net.Pending`. Return the kept list.
  - **In `Step`:** each `Pending` entry past `At` sends the nearest free non-look-out guard on the net that isn't Alert: `PerceptionService.Look(Rig, Where)`, then remove the entry.
  - **`LostSight` listener:** a tracked guard that loses sight shares the spot. Every other free guard on the net that is Alert with no focus (`Npcs[Rig].Focus == nil`, searching) is `Raise`d at it. Then say a "Search" line.
  - **`PhaseChanged` listener** (extend Task 5's): a "Suspicious" line on `→ Suspicious`; a "Calm" line on `Suspicious → Unaware | Cautious`.
  - **Start:** `PerceptionService.PickLookers = GuardService.Pick`. Keep the old function in `GuardService.OldPick` so tests can restore it.
- [ ] **Step 4: GREEN.** Sync and run `Play_GuardMemory`, `Play_GuardRadio`, `Play_Guard`, `Play_GuardSense`. The regressions are unchanged: `Play_Perception`, `Play_Stealth` (every noise case), `Play_Takedown`.
- [ ] **Step 5:** `--check` both; `test_sync.py`.
- [ ] **Step 6: Commit**: `"Stealth 1 Task 6: shared memory (the nearest guard looks, look-outs radio noises after 3 s, last known shared to searchers, bodies make the call, guard lines)"`.

---

### Task 7: SightFeed: each player's own awareness rows

**Files:**
- Create: `Scripts/ServerScriptService/SightFeed.lua`, `Scripts/ServerStorage/RenseiTests/Play_SightFeed.lua`
- Modify: `ServerHandler.server.lua` (start after PerceptionService, in a pcall)
- Manifest: `RenseiServer.SightFeed`, `RenseiTests.Play_SightFeed`; pins +2.

**Interfaces:**
- Produces:
  - `SightFeed.Rows(Player) -> {{Rig, Aware}}`: the 8 nearest `Combat` NPCs within 60 studs of the player's root, alive and in workspace. Nearest first. `Aware` is `Guard.Quantize(PerceptionService.Awareness(Rig, Player))`.
  - `SightFeed.Send(Player) -> boolean` (sent or not);
  - `SightFeed.LastSent[Player] = {Rows, At}`;
  - `SightFeed.SetAuto(On)`;
  - the remote `ReplicatedStorage.Remotes.GuardSight` (`UnreliableRemoteEvent`), fired as `:FireClient(Player, Rows)`.

- [ ] **Step 1: Write `Play_SightFeed`** (RED first):
  - `OnlyEnemiesNearby`: two Grunts at 10 and 50 studs and one at 70; a townsperson (`Kit.Folk`) at 5. `Rows` holds exactly the two Grunts, nearest first, and no townsperson.
  - `AtMostEight`: ten Grunts in a ring at 20 studs → 8 rows.
  - `AwareIsYours`: `Kit.PutInFront(Rig, 10)`, `Kit.Run(0.4)`. The row's `Aware` equals `Guard.Quantize(PerceptionService.Awareness(Rig, Player))`, and that is > 0.
  - `SendsOnChangeAndKeepAlive`: `Send` twice with nothing changed → true then false; after 1.1 s → true (keep-alive); after an awareness change → true.
  - `RemoteIsUnreliable`: `Remotes.GuardSight.ClassName == "UnreliableRemoteEvent"`.
  - `DeadAndKnockedLeave`: a Grunt with `Health = 0` leaves the rows.
- [ ] **Step 2: RED** in Ye Play (`Ye:stealth7`).
- [ ] **Step 3: Implement.**
  - `Start` makes the remote if it's missing.
  - The loop runs every `1 / Guard.FeedHz` s on Heartbeat (a pcall). Each player with a root gets `Send(Player)`.
  - `Send` compares the rows by rig and `Aware` against `LastSent` and fires on a change, or when `At` is `Guard.FeedKeepAlive` old.
  - `PlayerRemoving` clears `LastSent`.
  - The cost: one pass over `PerceptionService.Npcs` per player per tick, with no rays.
- [ ] **Step 4: GREEN.** Sync and run `Play_SightFeed`, `Play_Perception`, `Play_Guard`.
- [ ] **Step 5:** `--check` both; `test_sync.py`.
- [ ] **Step 6: Commit**: `"Stealth 1 Task 7: SightFeed (each player's own awareness of the nearest 8 enemies, unreliable remote, on change plus keep-alive)"`.

---

### Task 8: GuardSightUI: cones in the stance, markers over heads

**Files:**
- Create: `Scripts/ReplicatedStorage/Modules/UI/GuardSightUI.lua`, `Art/Studio/Stealth/client_checks.lua`
- Modify: `StealthUI.lua` (export `StealthUI.Hidden = Hidden`, one line), `UIHandler.client.lua:10` (add `"GuardSightUI"` after `"StealthUI"`, with a comment)
- Manifest:
  - `UI.GuardSightUI` (`Create: true`), at `ReplicatedStorage/Modules/UI/GuardSightUI`, `Class: ModuleScript`, as `UI.HostageUI`;
  - `UI.StealthUI` (`Create: false`), the pair Task 1 found missing.
  - Pins +2.

**Interfaces:**
- Consumes:
  - `Remotes.GuardSight` rows (Task 7);
  - the rig attributes `Awareness` (the phase) and `PerceptionType` (Task 3);
  - `Perception.Types[Type].Range`, `Perception.Primary`, `Perception.Peripheral`;
  - `Guard.ConeFan`, `Guard.Tint`, `Guard.Marker`, `Guard.Colours`, `Guard.ConeAlpha`, `Guard.ConeSegments`, `Guard.MarkerHeight`;
  - `StealthUI.Hidden()`;
  - the character attribute `Crouching`.
- Produces: `GuardSightUI.Start()`; `GuardSightUI.State() -> {[Rig] = {Cone = bool, Marker = {Show, Fill, Ring, Solid}}}` (for the client checks).

- [ ] **Step 1: Write `client_checks.lua`** on the hostages' pattern (`Art/Studio/Hostage/client_checks.lua`: TEMP remote, TEMP LocalScript in PlayerGui, TEMP suite module, everything removed before it returns). Cases, with the server half on `TakedownKit`'s floor inside `GuardKit.Guard`:
  - `NoConesStanding`: a Grunt at 15 studs, the player standing. After 0.6 s, `State()[Rig].Cone == false` and no cone part exists for it.
  - `ConesWhenCrouched`: `Kit.Crouch(true)`. After 0.6 s, `Cone == true`. The cone folder has `Full + 2 * Half` triangles' parts for it (2 wedges each = 2 × (6 + 4) = 20). Every part has `CanCollide`, `CanQuery`, `CanTouch` and `CastShadow` false. The cone's root sits within 0.5 studs of the floor height under the guard, and its rim is at the type's range (Grunt 30) ± 0.5.
  - `ConeFollowsTheGuard`: turn the rig 90°. After 0.4 s, the cone's forward has turned 90° ± 5°.
  - `TintFollowsTheMeter`: drive the meter (`Kit.PutInFront`, `Kit.Run`) to about 0.2: the cone colour is between pale and amber. To Alert: red (the `Guard.Tint` values ± 0.02).
  - `MarkerFillsAndTurns`:
    - meter 0 → no marker;
    - about 0.2 → shown with fill 0.2 ± 0.05 and no ring;
    - Suspicious → a ring;
    - Alert → solid.
    - While standing (out of stance), the marker still shows.
  - `SentryConeIsLonger`: a `StateSentry` gets a rim at 60 ± 0.5.
  - `TownspersonNothing`: a `Kit.Folk` townsperson gets no cone and no marker, even crouched.
  - `HiddenInDialogue`: with the Dialogue frame visible, nothing shows. Restore after.
  - `UncrouchClears`: `Kit.Crouch(false)`: cones are gone in 0.4 s, and markers stay.
  - Take screenshots of the crouched cone (pale, amber, red) and a marker at each stage with `screen_capture` into `E:/Rensei/Work/stealth1/`.
- [ ] **Step 2: RED** in Ye Play (`Ye:stealth8`): the module is missing, so every case fails.
- [ ] **Step 3: Implement `GuardSightUI`:**
  - **Rows:** `Remotes.GuardSight.OnClientEvent` stores `Rows[Rig] = Aware` and the receive time. A rig missing from the latest rows, or with rows older than 1.5 s, is dropped. If the remote isn't there yet, `WaitForChild` it (30 s) in a task.
  - **Cones:**
    - a `Folder` "GuardSight" under `workspace.CurrentCamera` (local, never replicated);
    - per rig, a `Model` of WedgeParts built once from `Guard.ConeFan`: the full cone at `Primary` degrees with `Full` segments, and the two half-rate bands at `(Peripheral - Primary) / 2` degrees each, offset to either side;
    - **each triangle** of the fan is drawn with two WedgeParts (the standard right-triangle split: the foot of the perpendicular from the apex to the far side splits it into two right triangles, each one WedgePart sized `(0.05, height, base)` and CFramed on the triangle's plane);
    - **materials:** Material `SmoothPlastic` (flat, not neon), `Transparency = Guard.ConeAlpha.Full` or `.Half`;
    - each RenderStepped, while `Crouching` and not `StealthUI.Hidden()`, each row's cone is `PivotTo`'d to `CFrame.new(FootPoint) * YawOf(Rig.HumanoidRootPart)`. FootPoint = the root position at the floor height found by one ray down from the root, refreshed every 0.2 s per rig. The ray filter excludes the character, the rig and the folder;
    - colour = `Guard.Tint(Aware, Rig:GetAttribute("Awareness"))`, on every part of that cone;
    - out of stance, or hidden, the folder's parts are parented to nil (kept for reuse). A rig gone from the rows is destroyed.
  - **Markers:**
    - per rig, a `BillboardGui` named "GuardMarker" adorned to the Head, in the player's `PlayerGui` (never on the server's rig);
    - settings: `StudsOffset (0, Guard.MarkerHeight, 0)`, `Size = UDim2.fromOffset(30, 30)`, `MaxDistance = Guard.FeedRange`, `AlwaysOnTop = false` (no seeing markers through walls: no radar);
    - **built only from `CIRCLE_IMAGE`:**
      - a back circle at 0.6 transparency in `Guard.Colours.Pale`;
      - a fill circle inside a clipping Frame anchored at its foot, whose height follows `Marker.Fill` (StealthUI's lid trick, `StealthUI.lua:55-59`), coloured amber (red when `Solid`);
      - a ring: a third circle at 1.35× size behind the others, `INK`, shown when `Marker.Ring`;
      - when `Solid`, the fill is full and red, at transparency 0.
    - `Marker.Show` false → `Enabled = false`.
  - `GuardSightUI.State()` reports what is drawn, for the checks.
  - The header names Plan 1 Task 8, the owner's rules ("only existing UI assets", "no HUD radar"), A9, A10 and A15, and the D10/D11 colours.
- [ ] **Step 4: GREEN.** Sync `UI.GuardSightUI`, `UI.StealthUI` and `SPScripts.UIHandler` to both places. In Ye Play, run the client checks: all pass. The sigil still draws (a look at the screenshot), and `Play_Stealth` is unchanged.
- [ ] **Step 5:** `--check` both; `test_sync.py`.
- [ ] **Step 6: Commit**: `"Stealth 1 Task 8: GuardSightUI (ground vision cones while crouched, tinted by your meter; suspicion markers from the transmutation circle art; no radar), StealthUI.Hidden export"`.

---

### Task 9: The demo, Foundry parity and the full sweep

**Files:**
- Create: `Art/Studio/Stealth/demo.lua`

**Interfaces:**
- Consumes: everything above.
- Produces: the demo screenshots and the sweep results in the ledger.

- [ ] **Step 1: Write `demo.lua`.** It is a Play-only Server script, run with `rbxc luau ... Server`. It refuses outside Play or without `IsNoSave()`. It builds on `TakedownKit`'s floor:
  - **net "Demo":**
    - a 4-point loop route with one `StateGuard`;
    - a ping-pong route with a second;
    - a `StateSentry` look-out on a 6-stud platform (`Kit.Wall`);
    - a `StateOfficer` on a post;
  - a barracks part;
  - three crate walls for cover;
  - lamps are skipped (the light is the floor's).
  - It returns the rigs' names. `MODE = "remove"` removes everything it made (marked `StealthDemo = true`).
- [ ] **Step 2: Demo session in Ye** (`Ye:stealth9`, the full protocol). Run the demo. Then, with the real client, crouch near the net, get seen, and get away (by moving the player with `Kit.PutPlayer` from the server). Take screenshots into `E:/Rensei/Work/stealth1/demo_*.png`:
  - the patrol walking;
  - cones while crouched;
  - an amber cone with a filling marker;
  - a guard radioing (its speech bubble);
  - the net converging;
  - reinforcements out of the barracks.
  - Run `MODE = "remove"`, then the protocol's restore and dump 2.
- [ ] **Step 3: Foundry parity.** `--check` both places, `DIFFER 0 / MISSING 0`, and `test_sync.py` passes.
- [ ] **Step 4: The full sweep, Ye** (one session, `Ye:stealth9b`):
  - `Test_Guard`, `Test_Takedown`, `Test_Perception`;
  - `Play_GuardSense`, `Play_Guard`, `Play_GuardRadio`, `Play_GuardMemory`, `Play_SightFeed`;
  - the client checks;
  - **the regressions:** `Play_Perception`, `Play_Stealth`, `Play_Takedown`, `Play_TakedownHard`, `Play_TakedownClasses`, `Play_Downed`, `Play_Morality`, `Play_Heat`, `Play_Rumours`, `Play_Townsfolk`, `Play_TownsfolkCrowd`, `Play_TownsfolkHurt`, `Play_Swim`, `Play_Hostage`, `Play_HostageHard`, `Play_Road`, `Play_Station`, `Play_Gate`.
  - The known flakes (the hostages ledger) are re-run once before any is counted as a failure. They are KnockGraceSnapsBack, RebaseGraceSnapsBack, DeepWaterStill, HeldClientCantMove, ClampFightSnapsBack, RetakeHalves, AStalledWatchAllowsNoBiggerJump, Gate WalkingIntoTheGateIsStopped, the Foundry Station seat cases and Foundry PromptGrabBehindOnly.
- [ ] **Step 5: The sweep, Foundry** (`Foundry:stealth9c`):
  - `Play_Boot` first;
  - then `Test_Guard`, `Play_GuardSense`, `Play_Guard`, `Play_GuardRadio`, `Play_GuardMemory`, `Play_SightFeed` (every new suite is in both places);
  - the client checks;
  - `Play_Takedown`, `Play_Hostage`, `Play_Station`, `Play_Gate`.
- [ ] **Step 6: Commit** `demo.lua`: `"Stealth 1 Task 9: Play-only demo net; Foundry parity and the full sweep"`. The results go in the ledger, not the repo.

---

### Task 10: Docs, the Changelog entry and the held Discord post

**Files:**
- Modify: `Documents/Changelog.md`, `Documents/Backlog.md`, `Documents/COMBAT_SYSTEM.md` (a "Guards and radio nets" section), `README.md` (one line under the systems list, if it has one for stealth)

- [ ] **Step 1: The Changelog entry** "## 2026-10-29 — Stealth missions 1: guards that think, and seeing what they see (not live)". Sections:
  - **what changed for players:**
    - cones while crouched and markers, for every enemy;
    - guards with radios, once a later plan places them;
    - **nothing else changes for bandits**;
  - **how it works:** the radio, the call window, the tight net, reinforcements, look-outs, shared memory;
  - **for builders:** the world data, listed exactly:
    - a spawn's `Net`, `Route` and `Lookout`;
    - `RenseiPatrolRoute` folders with numbered points, `Loop`, and a point's `Pause`;
    - `RenseiBarracks` with `Net` and `ReinforceType`;
  - **the decisions list** D1–D11 and the owner questions 1–3;
  - **the owner playtest** (8 items):
    1. run the demo;
    2. crouch: cones;
    3. stand: no cones, markers stay;
    4. be seen: amber then red;
    5. knock a guard out mid-call: no alarm;
    6. let a call through: everyone converges and reinforcements come;
    7. hide past the search: Cautious, not Normal;
    8. check the cones never block a shot or a prompt;
  - **the publish checkpoint:** these changes ride in Modules and RenseiServer with the held hostages, assassinations and gun rework; the World Travel order; Foundry by hand;
  - **the rollback:** the `Pre-Stealth1_2026-10-29` backups, and the created scripts deleted;
  - **what's next:** Plans 2–4 and M8, as in the roadmap above;
  - ends with `### Discord announcement`: "Hold: not live yet…", under 2,000 characters, with no file names, test counts or PROPOSAL tags.
- [ ] **Step 2: Backlog:**
  - item 3 gets "Stealth missions 1 (guards, cones): done 2026-10-29, not live";
  - sub-items for Plans 2, 3 and 4 and the parked notes: A12 (light relighting, with light control), A16 (open-combat guard deeds, Plan 3), and M8 (waits for the owner).
- [ ] **Step 3: COMBAT_SYSTEM.md:** the new section, in the file's style.
- [ ] **Step 4: Commit** the docs: `"Stealth 1 Task 10: Changelog (held Discord post), Backlog, COMBAT_SYSTEM guards and radio nets"`.

---

## Self-review notes

- **Spec coverage, M1:**

  | M1 item | Task |
  |---|---|
  | Patrols | 4 |
  | Look-outs | 4, 6 |
  | Radio check-ins | 5 |
  | The radio call and its window | 5 |
  | Shared memory | 6, plus body found (6) |
  | Reinforcements | 5 |
  | The calm-down ladder | existing, plus the tight floor (3, 5) |
  | After an alarm | 5 |
  | Speech lines | 5, 6 |
  | New guard types | 2 |

  - The **check** "a missed check-in starts a search from the guard's post; a heard noise reaches the radio net" is `MissedCheckInSearchesThePost` and `LookoutHoldsAndRadios`.
- **Spec coverage, M2:**

  | M2 item | Task |
  |---|---|
  | Ground cones in stance (two bands) | 8 |
  | Tint | 2, 8 |
  | The over-head marker (ring and solid, so colour isn't the only signal) | 2, 8 |
  | Each guard's meter sent only to its player | 7 |
  | No radar | 8: `AlwaysOnTop` false; no HUD element |

  - The **check** "cones show only while crouched; the marker fills and turns red at Alert" is `NoConesStanding`, `ConesWhenCrouched`, `MarkerFillsAndTurns` and `UncrouchClears`.
- **Out of this plan, by design:** light relighting (A12), open-combat guard deeds (A16), compounds and private copies (Plan 4), tools and disguises (Plan 2), contracts and outcomes (Plan 3), Nemesis (M8).
- **Names, used the same everywhere:**
  - GuardService: `Track`, `Untrack`, `Idle`, `Interrupt`, `Step`, `SetAuto`, `Now`, `Reset`, `StartCall`, `Alarm`, `Say`, `LastLine`, `Pick`, `NetOf`, `Free`, `RouteFor`;
  - PerceptionService: `PhaseChanged`, `LostSight`, `Heard`, `PickLookers`, `Look`, `Floor`, `Now`;
  - SightFeed: `Rows`, `Send`, `LastSent`;
  - GuardSightUI: `State`;
  - attributes: `Radioing`, `PerceptionType`, `Net`, `Route`, `Lookout`, `ReinforceType`;
  - tags: `RenseiPatrolRoute`, `RenseiBarracks`.

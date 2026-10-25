# Assassinations: audit and design (PROPOSAL)

> **Owner update (2026-10-25):** the owner added the takedown animations to the general sheet:
> - **Knock out:** 72960497872371
> - **Hold** (the knocked-out victim's side): 131914091661838
> - **Assassination:** 83505608395055
> - **Victim:** 132728216355683
>
> These replace the stand-ins below. The knockout uses the owner's Knock out / Hold pair, not the Bear Hug, and the assassination victim is no longer empty. The slots `Takedown_Choke` / `Takedown_ChokeVictim` take the Knock out / Hold ids, and `Misc_AssassinateVictim` takes 132728216355683. The implementer's Task 1 checks that each id loads in Studio, as the sheet process requires. Nothing is left for the owner to upload for this plan.

**Status:** written overnight on 2026-10-25 under the owner's overnight go-ahead. **Not approved by the owner yet. Nothing here is built.** The plan is `Documents/plans/2026-10-25-assassinations.md`.

**The owner's request** (Backlog, "After the swimming revamp", item 1): "Assassinations that work with the detection system (sight, light, sound)", and "I threw anims in the spreadsheet for it". The same work is the two older items under "Stealth and identity": "build it on top of the detection system" and "Add assassinations to the game, like we talked about before (ONLY PVE)".

**When it's built:** after the gun class rework and the swimming revamp (Backlog order). Stealth missions and the Nemesis system come after it and use its hooks (§13).

**Owner rules that bind this design:**
- **PvE only.** Players can never be assassinated or knocked out by a takedown.
- **UI:** only the game's existing UI assets.
- **Never invent an asset id.** Missing animations get empty, named slots with safe fallbacks.

**Every number and every new name in this file is a PROPOSAL** unless it is marked as the owner's.

---

## 1. The owner's animations (the sheets, read 2026-10-25)

The three Google Sheets were read **read-only** through Drive on 2026-10-25. Nothing was edited.

| Sheet | Row / column | Name | Id | In the game |
|---|---|---|---|---|
| "Animation ID's" (general), Misc. column | row 29 | **Assassination** | **83505608395055** | `Misc_Assassinate` in `Animations.Registry`: loads, nothing plays it (`Animations.md:84`) |
| same cell | row 29 | **Assassination Victim** | **empty** ("Victim:" with no id) | none |
| general, Misc. | row 19 | Drag ("Downed person is ragdolled while dragged") | 85054207968303 | `Drag`, live, not used by this design |
| general, Misc. | row 36 | Ground Interaction | 138121475774733 | not used here (throwables, later) |
| general, Misc. | row 24 | Lock Pick | 136478153650620 | not used here |
| "Skill ID's" (skills), Fist | row 4 | Bear Hug / Victim | 140607038476506 / 76737043223431 | `Fist_BearHug` (+`Victim`), registered, not played |
| skills, top row | row 2 | Grab Whiff | 74141778302667 | `Skill_GrabWhiff`, registered |
| "Fighting Styles ID's" | | (no stealth rows) | | |

- **Searched for:** assassination, takedown, stealth kill, victim, knockout, choke(hold). **The only assassination row is "Assassination: 83505608395055 / Victim:" with the victim id missing.** There is no choke, knockout or drop-takedown row on any sheet.
- The general sheet's Drive "modified" time is 2026-10-19. If the owner added rows after that in a copy we can't see, the owner should point us at it (§16, question 1).
- The 2026-10-19 morality spec already recorded the same thing (`specs/2026-10-19-morality-reputation-consequences-design.md` §17.9: "Assassination `83505608395055` … Its victim column is empty").

**What this design needs from the owner** (§5 has the slots):
1. **Assassination Victim**, paired with 83505608395055 → slot `Misc_AssassinateVictim`.
2. **Chokehold** (attacker) → slot `Takedown_Choke`.
3. **Chokehold Victim** → slot `Takedown_ChokeVictim`.

Until then each slot is empty and plays a fallback (§5).

---

## 2. Audit: what exists today

Read from the repo exports on 2026-10-25. Studio was not opened; items marked **(Studio check)** are measured in the plan's Task 1.

### 2.1 The detection system (built)

| Piece | What it does | Where |
|---|---|---|
| Phases | Each tracked NPC has one phase: **Unaware**, **Suspicious** (awareness ≥ 0.35: walks to what it noticed, gives up after 8 s), **Alert** (awareness 1: fights, or searches 25 s and calls NPCs within 40 studs), **Cautious** (3 min after a failed search, sight and hearing ×1.3) | `PerceptionService.lua:4-7`, `Perception.lua:14-21` |
| Awareness | A number 0..1 **per player**, on the server only | `PerceptionService.lua:59-60`, `:72` (`Awareness(Rig, Player)`) |
| Sight | View cone 110° full rate, 160° half rate, nothing behind; range by type (Grunt 30, Elite 45, Agent 40, Hunter 50, Witness 30); head, torso and feet checked separately; crouch ×0.5, run ×1.5, sprint ×2 | `Perception.lua:12-13`, `:29-36`, `:52-61`; `PerceptionService.lua:176-198` |
| Light | `Exposure` 0..1 on each player: ×0.2 in deep shadow to ×1.2 in bright light. `LightService.ExposureOf` also works on any rig, worked out on demand | `LightService.lua:73-111`, `Perception.lua:76-82` |
| Sound | Events with a radius; walls cut 40% each; the NPC learns where, not who | `NoiseService.lua:39-57`, `PerceptionService.lua:338-357`, `Perception.lua:103-128` |
| Witnesses | Only NPCs that **saw the player** in the last 3 s witness a deed; only NPCs with a Faction add strength | `PerceptionService.lua:361-371`, `WitnessService.lua:22-28`, `:47-71` |
| Who is tracked | Every EnemyService enemy except arena and trial foes (`AlwaysAware`), plus every `RenseiWatcher` (townsfolk, as non-combat witnesses) | `EnemyService.lua:506-508`, `Perception.lua:46-48`, `PerceptionService.lua:395-403` |

### 2.2 Knocked, Grip and Carry (built)

- Every enemy except the sparring dummy is **knocked** at 0 HP instead of dying (`EnemyService.lua:142`, `TuningConfig.lua:955`). Knocked = stunned, can't move, immune to damage; it gets up after `KnockedTime` (20 s), or a per-rig `KnockedTime` attribute (`DownedManager.lua:169-203`, `:173`).
- **Grip (B)** finishes a knocked target over 2 s with a paired animation (`DownedManager.lua:311-402`). **Carry (V)** picks up a knocked target (`:427-451`).
- Carrying a knocked bandit to an NPC with `TakesPrisoners` arrests it (`arrested_bandit`; `MoralityService.lua:226-255`).

### 2.3 What the player can read about an enemy's state today

- **The phase is public:** `SetPhase` writes it to the rig's `Awareness` attribute (`PerceptionService.lua:48-53`, `:65`), which every client can read.
- **The per-player awareness number is server-only.**
- **Nothing on screen shows either.** No client script reads `Awareness` (a repo-wide search finds only the server). The stealth sigil (`StealthUI.lua:1-11`, `:70-90`) shows only **your own** light, crouch and last noise. Players judge an enemy's state from what it does (stands, walks to a noise, attacks).
- Seeing guard vision (ground cones and over-head markers) is the stealth missions' slice M2, not this design (`specs/2026-10-25-stealth-missions-design.md` §4.1).

### 2.4 Findings that shape this design

| # | Finding | Evidence | What the design does |
|---|---|---|---|
| A1 | No takedown of any kind exists. `Misc_Assassinate` is registered but nothing plays it, and it sits in `Registry`, which the client doesn't preload, so playing it on a player would warn "Animation not found" | `Animations.md:13`, `:18-19`, `:84`; `AnimationManager.lua:158-195` | Move it into `Shared` (reversible) and give it a fallback (§5) |
| A2 | **A killed enemy's body is deleted 4 s after death**, so a kill leaves nothing to find | `EnemyService.lua:68`, `:481-487` | A body from a takedown stays 120 s (§7.3) |
| A3 | **No NPC ever notices a body.** Perception only looks at players | `PerceptionService.lua:157-213` | Bodies join perception (§7.3) |
| A4 | **The Grip finisher is loud:** it calls `RecordHit(…, "Hit")`, which NoiseService turns into a 20-stud "Hit" sound, and which alarms the victim | `DownedManager.lua:386-388`, `NoiseService.lua:121-125`, `PerceptionService.lua:384-387` | A takedown credits the kill directly (`WorldService.Credit`) and makes its own small sound (§7.2) |
| A5 | `Call` (bringing in NPCs within 40) needs a player; there is no way to raise a search **at a spot** with nobody seen | `PerceptionService.lua:101-114` | A new `Raise(Rig, Where)` (§7.3, §7.4) |
| A6 | Crouch works **only out of Combat Mode** (in Combat Mode, Ctrl is the Uppercut modifier) | `ClientHandler.client.lua:383-394`, `Controls.md` (Moving) | Takedowns are done from Calm, like sneaking (§3) |
| A7 | **Tapping a prompt does nothing in Combat Mode** (PromptUI ignores clicks and taps while `CombatMode` is on) | `PromptUI.lua:162-166` | Matches A6: takedowns from Calm |
| A8 | **Any visible prompt stops E from drawing your weapon.** CombatModeUI counts every shown prompt, not only E prompts | `CombatModeUI.lua:17`, `:66-73` | Count only prompts on E, so a takedown prompt never blocks E (§9) |
| A9 | The view cone treats someone straight above as "ahead", so "from above" can't reuse the cone | `Perception.lua:50-51` | Drop takedowns wait for their own animation (§16) |
| A10 | Townsfolk are hittable, knockable and grippable, and killing one is `murder_townsfolk` (Crime 60) | `TownsfolkService.lua:14-34`, `Deeds.lua:115-126` | Takedowns refuse townsfolk (§11) |
| A11 | Enemies heal to full at home, so an Unaware enemy is always at full health | `EnemyService.lua:307-315` | The Elite backstab can't kill from full (§8) |
| A12 | Bosses today are the five trial foes: `Boss = true`, `TrialFoe = true`, and `AlwaysAware`, so perception doesn't track them | `TuningConfig.lua:1056-1079`, `Perception.lua:46-48` | Immune (§8) |
| A13 | No current enemy has a `Faction`, so their witnesses add no rumour strength, and no enemy killing is a crime | `TuningConfig.lua:961-1048`, `WitnessService.lua:7-8` | Heat and rumours follow existing rules; future faction guards plug in through data (§7.5) |
| A14 | `Morality and Reputation Proposal.md` has no §17; the stealth design lives in the 2026-10-19 spec's §17 | `Morality and Reputation Proposal.md` headings | This file builds on that §17.7 |
| A15 | **Crouching runs a real WCS Stun status** (the client's "Stun" toggle). So any "not stunned" check, like DownedManager's `Free`, treats a crouching player as stunned (Grip and Carry are likely refused while crouched: **Studio check**) | `CharacterHandler.server.lua:119-126`, `:150-157`; `AttackRunner.CrouchStuns`; `DownedManager.lua:278-284` | The takedown's "stunned" test ignores the crouch's own Stun (§3) |

---

## 3. The takedown rules

A **takedown** is a stealth attack from behind on an enemy that hasn't caught you. It comes in two kinds: **Knock out** (non-lethal) and **Assassinate** (lethal).

**You can take an enemy down when all of these hold** (checked on the server; the client only shows the prompt):

| Gate | Rule (PROPOSAL) |
|---|---|
| Target | An enemy spawned by `EnemyService` (in `World.Live`), alive, not knocked, gripped, carried or already being taken down. **Never a player** (§11), never a townsperson |
| Its state | Its phase is **Unaware, Suspicious or Cautious**, never **Alert**, and its awareness of **you** is below 1 |
| From behind | You stand in its rear arc: within **70°** of straight behind it (a 140° arc, inside its 200° blind zone; the server allows 10° of slack) |
| Range | Your root within **4 studs** of its root on the ground plane (server slack +1.5), and within **3 studs** up or down |
| Clear | Nothing solid between your torso and its torso |
| You | Alive, not knocked, gripping or carrying, not attacking or stunned (the crouch's own Stun doesn't count, A15), on the ground, not swimming, and **out of Combat Mode** (Calm) |
| Its class | Not **Immune** (§8) |
| Cooldown | Ready (§9) |

**Crouching is not required** (PROPOSAL). It already does its job on the way in: sight ×0.5 and silent steps. A Suspicious enemy walking to a noise is a fair target: it's looking for something, not at you.

**Why Calm only:** crouching only works in Calm (A6), touch prompts can't be tapped in Combat Mode (A7), and it stops a takedown being used as a free kill mid-fight.

### 3.1 The input

- **Key: N** (PROPOSAL; free in every script and in `Controls.md`). **Tap N: knock out. Hold N (0.6 s): assassinate.** Holding is the deliberate choice, because killing can't be undone.
- **The prompt:** when a takedown is possible, a prompt in the game's own art (PromptUI) appears over the enemy:
  - the key: **N**;
  - the object line: the enemy's name and its state in lower case, for example "Bandit (unaware)" or "Bandit (suspicious)". **This is how the player reads the enemy's state** at the moment it matters;
  - the action line: "Knock out · hold to kill". For an Elite: "Backstab (hold)" (§8).
  - The prompt's own hold fill shows the hold.
- **N is reserved** in Settings (like B and V) so no rebind can take it. A save that bound N to something else falls back to that action's default (the existing rule in `Settings.Resolve`). Making the takedown key rebindable is a later change (§16).

---

## 4. Knock out or assassinate

| | **Knock out** (chokehold) | **Assassinate** |
|---|---|---|
| Input | Tap N | Hold N 0.6 s |
| Length | **2.0 s**, interruptible (morality spec §17.7) | **1.0 s** (the animation is retimed to fit) |
| Sound | **Choke, radius 6** at the start (morality spec §17.7) | **Takedown, radius 4** when the body drops ("silent" in §17.7; a body falling still makes a little noise) |
| Result | The enemy is **knocked out for 300 s** (§17.7's 5 minutes), using the existing knocked state, so it can be **carried (V)**, **gripped (B)** or **delivered** to a `TakesPrisoners` NPC as today | The enemy **dies**. You get the kill credit (EXP, money, quests) once. The body stays 120 s |
| Waking up | After 300 s it gets up **and raises the alarm**: it starts an Alert search where it woke and calls NPCs within 40 studs (owner: "the guard wakes later and raises the alarm, unless he's hidden"; hiding spots come later, §13) | — |
| Morality | Nothing for hostile mobs (morality spec §17.7) | The same deed as finishing a beaten bandit: **`assassinated_bandit`**, Mercy −1, Local, at most 10 a day |

**Gripping a knocked-out enemy is still the loud Grip** (A4: a 20-stud sound). The quiet kill is the assassination. This is intended: the knockout is the merciful choice, and finishing someone helpless afterwards is a separate act.

**If a takedown is interrupted** (you're stunned or knocked, either of you dies or vanishes, or you end up more than 6 studs apart): both are released, the enemy turns **Alert on you**, and the cooldown still applies.

During a takedown the victim takes **no damage from anyone** (its `DamageTakenMult` is 0), so nobody can steal or double the kill. **You are not protected:** anyone else can hit you, and that interrupts it.

---

## 5. Animations

### 5.1 The slots

All slots live in a new folder `Assets.Animations.Shared.Takedown`, so the client preloads them (A1). A reversible Studio script makes them (plan Task 3). Names must be unique across all of `Assets.Animations`, because AnimationManager finds animations by name.

| Slot | Plays on | Id | Fallback while empty |
|---|---|---|---|
| `Misc_Assassinate` | the player (assassinate) | **83505608395055** (the sheet's), moved from `Registry` | `Gripping` |
| `Misc_AssassinateVictim` | the victim (assassinate) | **132728216355683** (owner, 2026-10-25) | `Gripped`, then the body drops (only if the id fails to load) |
| `Takedown_Choke` | the player (knock out) | **72960497872371** (owner's "Knock out", 2026-10-25) | `Fist_BearHug` (skill sheet, 140607038476506), moved from `Registry` |
| `Takedown_ChokeVictim` | the victim (knock out) | **131914091661838** (owner's "Hold", 2026-10-25) | `Fist_BearHugVictim` (skill sheet, 76737043223431), moved from `Registry` |

- **The Bear Hug as the stand-in choke** is a PROPOSAL: it's the only paired restraining hold on the sheets. Task 1 plays it on a test rig in Play and the controller looks at the capture. If it reads wrong from behind, the fallback becomes the existing classic grip pair (`Gauntlets_Grip` / `Gauntlets_Gripped`), slowed.
- **Never an invented id.** An empty slot has `AnimationId = ""`, and AnimationManager plays the fallback.

### 5.2 Placement and timing

- **The player moves, not the victim:** at the start, your character is put behind the victim, facing the same way, at the offset the attacker animation was authored for. Task 1 reads that offset from the animation (its root motion and the Grip pairs' "shared root" convention, `DownedManager.lua:9-11`). Until it's measured the offset is 1.6 studs behind.
- The victim is welded to you for the takedown (as Grip and Carry do), then released.
- **The kill moment:** the animation's "Kill" or "Hit" marker if it has one (Task 1 reads its markers), otherwise 60% of the way through.
- **Speed:** like Grip, the pair plays at its length ÷ the takedown time, clamped to 0.6–1.6×.
- **The body:** a dead rig plays the existing `Knocked` pose so it lies down rather than standing stiff (Task 1 checks what a dead enemy rig does on its own).

---

## 6. Witnesses: who sees it

- **At the start of a takedown**, every tracked NPC (not the victim) gets one quick look at you, with the normal sight rules (range, cone, at least one of head, torso and feet in clear view, without the light and movement multipliers: it's a single glance at an attack, not a slow notice):
  - an **enemy** that sees it goes straight to **Alert on you** (as if you'd hit it);
  - a **watcher** (townsperson) that sees it **remembers seeing you**, so it witnesses the deed.
- The deed is recorded when the takedown finishes, with the witness capture that already exists (`MoralityService.Record(…, {Witness = true})`). It counts only NPCs that saw **you** in the last 3 s, so a takedown nobody saw is a ghost: no rumour.
- Watchers don't flee from a quiet takedown (their flee rule listens for Hit, Cast and Gunshot sounds). PROPOSAL: leave that for stealth missions.

---

## 7. Sound, bodies, Heat, rumours and morality

### 7.1 Summary

| | Knock out | Assassinate | Elite backstab |
|---|---|---|---|
| Sound | Choke 6 | Takedown 4 | Hit 20 (it's a fight now) |
| Who notices | Enemies within the sound radius go to look; anyone who sees you (§6) | same | everyone the hit alerts, as today |
| Body | Knocked-out enemy, findable until it wakes or is carried off | Dead body, findable for 120 s | none |
| Morality | none for hostile mobs | `assassinated_bandit` (Mercy −1, cap 10/day) | none |
| Heat | only if the deed is a crime (none today) | same | none |
| Rumour | only if a faction NPC witnessed you | same | none |

### 7.2 Sound

- Two new sounds in `Rensei.Perception.Sounds`: **`Choke = 6`** and **`Takedown = 4`**.
- The kill does **not** go through the generic hit path (A4), so it doesn't make the 20-stud "Hit" sound. EXP and quest credit go through `WorldService.Credit(Rig, Player)` directly.

### 7.3 Bodies

- **A body is either dead (assassinated) or out (knocked out).** Each one is registered with perception.
- **How an enemy finds one:** every perception tick, an enemy that isn't Alert, and is within its sight range of the body with the body in its cone and a clear line to it, fills a "found" meter at its normal sight rate. The body never moves, so the movement multiplier is 1. The **light on the body** counts (`ExposureOf` works on any rig), so a body in deep shadow is found 6× slower than one under a lamp. At 1 the body is **found**.
- **When a body is found:** the finder turns **Alert** with nobody to fight and **searches around the body**, and calls NPCs within 40 studs to look there (the new `Raise`). Each body is found once. Townsfolk don't look for bodies (PROPOSAL).
- **Dead bodies stay 120 s** (PROPOSAL; was 4 s for every death), then are removed as before. The enemy still respawns on its normal timer. A respawned bandit may find its predecessor: that is intended.
- **Moving bodies:** a knocked-out enemy can be **carried (V)** as today. Dead bodies can't be moved in this version (§16). The stealthy way to clear a path is: knock out, carry into shadow, then decide.
- **Hidden bodies:** hiding spots (`RenseiHide`) are stealth missions' slice M3. This design leaves a hook (`Takedown.IsHidden`, always false for now) so a hidden knocked-out guard won't raise the alarm when he wakes, as the owner described.

### 7.4 What waking up does

A knocked-out enemy that gets up on its own (not gripped, not delivered) is `Raise`d at the spot where it woke: an Alert search with nobody to fight, and a call to NPCs within 40 studs. It doesn't know who choked it (it never saw you). The search ends in Cautious as usual.

### 7.5 Heat, rumours and morality

All three run through the deeds system that exists. **No new Heat or rumour code.**
- **Morality:** the deed is chosen by the victim's `EnemyType` through `Deeds.Finishers` (the table Grip already uses): `Finishers.Grunt.Assassinate = "assassinated_bandit"`, and the same for Elite. Enemy types with no entry (the alchemists, Adit scavengers) record nothing, as their grips record nothing today.
- **Heat:** a deed raises Heat only if it has a `Crime` value. `assassinated_bandit` has none (bandits are outlaws). When stealth missions add guards who belong to a faction, their deeds carry `Crime`, and `HeatService` handles them without changes.
- **Rumours:** a deed starts a rumour only when someone with a faction witnessed it. Bandits have no faction (A13), so in the wild today, only townsfolk who saw you can spread it.
- **Knockouts of persons** (future faction guards) lean Mercy (stealth missions §5.2). The table has room for a `Knockout` deed per enemy type; none is set for bandits.

---

## 8. Elites and bosses

Each enemy gets a **takedown class** from its perception type (PROPOSAL):

| Class | Who | What a takedown does |
|---|---|---|
| **Full** | Grunts, scavengers, the five alchemists (perception types Grunt and Agent) | Knock out or assassinate, as above |
| **Chunk** | Elites ("Bandit Duelist") and, later, Hunters (perception types Elite and Hunter) | **Backstab only** (hold N): **45% of its max health** through the normal damage path, a **1.2 s stun**, and it turns **Alert on you**. No knockout. It can't kill from full health (A11), but if the 45% would take it to 0, it's knocked as usual |
| **Immune** | Bosses (`Boss` attribute), trial foes, the sparring partner, anything perception doesn't track (`AlwaysAware`) | No prompt; the server refuses |

- A rig's `TakedownClass` attribute (`"Full"`, `"Chunk"` or `"Immune"`) overrides the type. That is the hook for named Nemesis rivals and hand-made bosses later.
- The backstab plays `Misc_Assassinate`, cut off at its kill moment, and the victim plays nothing special.

---

## 9. Cooldown

- **4 s** after any takedown ends (finished or interrupted), per player, on the server.
- **0.5 s** after a refused request (spam guard, on top of the request limiter's 8 per second).
- The server writes the time you're ready again to your character (`TakedownReadyAt`, server time). The prompt doesn't show until then.

---

## 10. Touch screens

- The prompt is the touch control: **tap it to knock out, hold it to assassinate.** PromptUI already turns a tap or hold on its plate into the prompt's hold (`PromptUI.lua:162-175`), and shows "TAP" for the key on touch.
- No new touch button and no change to `MobileControls`. Takedowns are from Calm, so the combat buttons aren't showing anyway.
- `Controls.md`'s touch table gains a line: "Takedown: tap or hold the prompt over the enemy".

---

## 11. Server validation, anti-exploit and PvE only

**The client decides nothing.** It shows the prompt and sends `Takedown` with the kind and the target. The server re-checks every gate in §3 with its own positions, in this order:

1. **The target is not a player's character. Ever.** First check, before anything else. This is the PvE-only rule (owner).
2. The target is in `EnemyService.Active` (an enemy), not a townsperson (`TownsfolkId`), alive.
3. The kind is "Knockout" or "Assassinate", and the class allows it.
4. Then the rest of §3, the cooldown, and that neither side is already in a takedown.

**Also:**
- **Malformed requests** (wrong types, a non-Instance target, NaN) are refused quietly.
- **One takedown per target:** the server marks the victim `TakenDownBy` in the same step as the last check, with no yield between, so two players can't take down one enemy.
- **Every heartbeat during the takedown** the server re-checks the interrupt rules (§4).
- **Results for tests and logs:** the character gets `LastTakedownResult` (for example `"Assassinate:ok"` or `"Knockout:front"`).
- **No NPC has a takedown**, and no takedown path accepts a player as the victim, so players can never be assassinated or choked. PvP stays as it is (Grip on a knocked player is unchanged).

---

## 12. UI (owner rule: existing assets only)

- **The prompt** is a `ProximityPrompt` made on the client, with `Style = Custom`, so PromptUI draws it in the game's own art (the hotbar slot plate, the transmutation circle, the name-plate lettering). No new image, font, sound or ScreenGui.
- **The eye sigil** (StealthUI) is unchanged. A takedown's sound shows on it like any other.
- **The Combat Mode prompt rule** (A8) changes so only prompts on E stop E from drawing. Without this, standing behind an enemy would stop E from working.

---

## 13. Hooks for later systems

| Hook | Used by |
|---|---|
| `TakedownService.Done` listeners: `(Kind, Player, Rig)` after a finished takedown | Stealth missions (no-kill twists, Ghost / Quiet / Loud) |
| `TakedownService.Failed` listeners: `(Player, Rig, Reason)` when interrupted, or when an Elite survives a backstab | Nemesis: "survives an attack the player started" can promote a rival |
| `PerceptionService.BodyFound` listeners: `(Body, Finder, Info)` | Stealth missions: radio calls, evidence, missed check-ins |
| `Takedown.IsHidden(Body)`: false until hiding spots exist | Stealth missions M3 |
| `TakedownClass` attribute | Nemesis rivals, bosses |
| `Deeds.Finishers[Type].Knockout` / `.Assassinate` | Faction guards' deeds (with `Crime` for Heat) |

---

## 14. What changes, by file

| File | Change |
|---|---|
| `Rensei/Takedown.lua` (new) | Every number, the slot names, and the pure rules (`Behind`, `ClassOf`, `Check`) |
| `Rensei/Perception.lua` | Sounds `Choke` 6 and `Takedown` 4 |
| `PerceptionService.lua` | Skip rigs being taken down; `Glimpse` (the one quick look); `Raise` (a search at a spot); bodies and `BodyFound` |
| `EnemyService.lua` | A rig in a takedown is busy; a takedown body stays 120 s |
| `DownedManager.lua` | `Knock(Victim, Seconds)`: an optional knock length |
| `Rensei/Deeds.lua` | `assassinated_bandit`; `Finishers.Grunt/Elite.Assassinate` |
| `TakedownService.lua` (new, RenseiServer) | The takedown itself |
| `Requests/Takedown.lua` (new) | The request, typed |
| `ServerHandler.server.lua` | One line: `TakedownService.Start()` |
| `UI/TakedownUI.lua` (new) | The client prompt |
| `UIHandler.client.lua` | Starts TakedownUI |
| `UI/CombatModeUI.lua` | Count only E prompts (A8) |
| `Rensei/Settings.lua` | N reserved |
| Studio: `Assets.Animations.Shared.Takedown` | The slots (reversible script) |
| Tests | `Test_Takedown`, `Play_Takedown`, `TakedownKit`, a client check script |

`TuningConfig`, `MobileControls`, `ClientHandler` and `SettingsUI` are **not** changed, so this plan doesn't collide with the gun and swimming plans there. The shared files it does touch are listed in the plan's "Shared files" table.

---

## 15. Tests

Every check is run once where it must fail (RED), then passes (GREEN). Spots come from Task 1's survey, never from the thing under test.

**Pure (`Test_Takedown`):**
- `Behind`: straight behind passes; 70° passes; 71° fails; the side (90°) and the front fail; slack widens it by exactly 10°.
- `ClassOf`: Grunt and Agent → Full; Elite and Hunter → Chunk; `Boss`, `TrialFoe` or an unknown type with `AlwaysAware` → Immune; the attribute overrides.
- `Check`: each gate refuses with its own reason, and **a player target is refused first** whatever else is true.
- The numbers are the PROPOSAL values written in the test by hand.

**Server (`Play_Takedown`, in the Play VM, on test enemies spawned for the test):**
- From the front, at 6 studs, through a wall, on an Alert enemy, in Combat Mode, on cooldown: each refused with its reason.
- **PvE:** the player's own character as the target is refused "player"; a townsperson is refused "townsfolk".
- Assassinate: the enemy dies once, the kill is credited once, `assassinated_bandit` is recorded once, a 4-stud `Takedown` sound and **no** `Hit` sound.
- Knock out: knocked for 300 s; with a short test length it wakes and is Alert-searching where it woke.
- Interrupt: stunning the player mid-choke releases both, the enemy is Alert on the player, and `Failed` fires.
- Witness: a second enemy facing the player goes Alert on them; one facing away doesn't.
- Bodies: a dead body lasts past 4 s; an enemy facing it finds it and searches there; one facing away doesn't; found once.
- Elite: 45% damage, Alert, no knockout; boss: refused "immune".

**Client (`client_checks.lua`, a temporary LocalScript):** the prompt shows only behind an Unaware enemy and in Calm; hides when it turns Alert; a tap ends as `Knockout:ok`, a hold as `Assassinate:ok`; E still draws the weapon while the prompt shows.

**Regression:** `Play_Stealth`, `Play_Perception`, `Play_Morality`, `Play_Heat`, `Play_TownsfolkHurt`, `Test_Perception`, `Test_Sound` stay green.

---

## 16. Decisions taken without the owner

The owner was asleep (overnight go-ahead, 2026-10-25). Each is a PROPOSAL.

1. **Two kinds on one key:** tap N to knock out, hold N (0.6 s) to assassinate.
2. **Key N**, reserved like B and V (not rebindable in this version).
3. **Gates:** rear 140° arc, 4 studs (3 up or down), clear line, enemy not Alert and not fully aware of you, **from Calm only**, **crouch not required**.
4. **Suspicious and Cautious enemies can be taken down**; Alert ones can't.
5. **Timings:** knock out 2.0 s, assassinate 1.0 s, knocked out for 300 s, cooldown 4 s.
6. **Sounds:** Choke 6, Takedown 4; the kill skips the 20-stud hit sound.
7. **Witnesses:** one quick look at the start; enemies that see it go Alert; townsfolk remember.
8. **Bodies:** dead bodies stay 120 s; enemies find bodies by sight, faster in light; a found body starts a search there. Townsfolk don't look for bodies. Dead bodies can't be moved yet.
9. **Waking up raises the alarm** (owner's rule), as a search at that spot. Hiding spots come with stealth missions.
10. **Morality:** assassinating a bandit is `assassinated_bandit` (Mercy −1, cap 10 a day), the same weight as finishing a beaten one; knocking out a hostile mob is no deed.
11. **Elites:** backstab for 45% and a 1.2 s stun, no knockout. **Bosses and trial foes:** immune.
12. **Townsfolk can't be taken down** (killing one is already a crime through the existing Grip).
13. **The victim can't be damaged during a takedown; the player can.**
14. **The Bear Hug pair stands in for the choke** until the owner uploads one.
15. **The prompt shows the enemy's state word** ("unaware", "suspicious", "cautious"): the only on-screen read of enemy state until stealth missions' markers.
16. **Drop takedowns** (from a ledge onto an enemy) are left out: no animation exists, and the cone can't judge "above" (A9).
17. **The Combat Mode prompt rule** changes to count only E prompts (a bug fix this feature needs).

**Open questions (for later):**
1. Did the owner add assassination rows in a sheet we didn't see? Only one row was found (§1).
2. Should the takedown key be rebindable?
3. Should townsfolk flee from, or report, a takedown they saw?
4. Should dead bodies be carryable (needs the Carry code to accept a dead body)?
5. How heavy are lethal takedowns of **guards** (morality spec open decision 9 proposed Mercy −5)?

---

## 17. Studio checks for the implementer (plan Task 1, read-only)

1. Where `Misc_Assassinate`, `Fist_BearHug`, `Fist_BearHugVictim`, `Gripping`, `Gripped` and `Knocked` sit under `Assets.Animations`, and their ids. None of `Misc_AssassinateVictim`, `Takedown_Choke` or `Takedown_ChokeVictim` may exist yet.
2. The three sheet animations' KeyframeSequences (83505608395055, 140607038476506, 76737043223431), read with `KeyframeSequenceProvider`: length, marker names and times, which parts they key (a weapon bone such as `Hilt`?), and how far the root or torso travels, which gives the takedown offset.
3. Whether a `ProximityPrompt` made on the client with `Style = Custom` is drawn by PromptUI, and whether its hold events fire for a tap (Play).
4. What a dead enemy rig does on its own over 5 s (it has `BreakJointsOnDeath = false`).
5. Whether Grip and Carry are refused while crouched (A15).
6. That no script in either place binds **N**.
7. One open, flat test spot per place for the Play tests, chosen by a fixed search, never by the thing under test.

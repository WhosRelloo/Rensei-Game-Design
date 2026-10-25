# Main story: concept (DRAFT for the owner)

**Status:** **DRAFT**, 2026-10-25, revised the same day to the owner's answers. Written for the owner to read, change and approve. Nothing here is built, and nothing here is canon until the owner says so.

**Owner's request (their exact words):** "I want the game to Go like this: Character Creation > Tutorial > Main Game Cutscene of the character waking up in 1st person seeing a bird fly across the sky above him/her, then they get up and look left and right > Lore + Main Quest. I want the first main quests to introduce all the in-depth features in the game 1 by 1 and in a simple way for players to understand."

## Owner's answers (2026-10-25)

Recorded verbatim:

> "For the short quests make sure they explain the features well but don't overload with information."
>
> "1. The player is someone who was transported to another world (the alchemy world)."
>
> "2. Each trainer's starting quest should be in Lindenmoor for now, until we add the other maps later."
>
> "3. The first chapter doesn't require a finished alchemy path, but if players want to they can."
>
> "4. Nah let's create a full lore for the game that's original, immersive, and still follows the FMA theme."
>
> "5. Good."
>
> "6. Yes. (the identity quests should be able to do solo if you want)."

**What they change in this draft:**
- **Answer 1:** the player is a **stray**, someone who fell through the Gate from another world (`Documents/Lore Bible.md` §6). The waking cutscene is now an arrival.
- **Answer 2:** every trainer's questline starts in Lindenmoor. Metal is the one exception the map forces today (§2.4).
- **Answer 3:** beat 7 completes when the player **starts** a trainer's questline. Finishing it is optional.
- **Answer 4:** the placeholder "dross" spine is gone. The new lore is in `Documents/Lore Bible.md` (DRAFT), and §§1.4, 2 and 3 below use its spine: the **Tally**, **debtwork**, **sinks** and **strays**.
- **Answer 5** (wrong-guess consequences): **off in Chapter 1, on from Act II**, always told up front, never a dead end.
- **Answer 6:** the Identities beat (12) and the parties beat (13) are optional, and **beat 12 can be done solo**: the player meets an NPC stranger and fills in their first Identity record (§2.5).
- **The start flow stays:** Character Creation > Tutorial > the first-person waking cutscene > Lore + Main Quest.

**Rules this draft follows:**
- **Every new name, line, number and plot point is a PROPOSAL.** The lore's own rules (names, tone, words to avoid) are in the Lore Bible. The owner's story notes (the conversation linked in `README.md`, a web link I couldn't read) win wherever they disagree.
- **Original story.** The theme is Fullmetal Alchemist; the content is our own (Lore Bible §9.2).
- **Explain each feature well, briefly.** Every beat says **what the player is told**: at most two short sentences or one Field Note, shown at the moment of use.
- **What exists is named as existing; what's new is marked new.** Section 5 lists both.

---

## 1. The start flow

### 1.1 Step by step

| Step | Place | Status | What happens |
|---|---|---|---|
| 1. **Character creation** | Character Customization (the menu place) | **Exists** | Main menu, save slots, nation, name, look, clan roll, starting weapon. Saved once. In the lore, the nation and clan are the people and family line the Gate weighs the stray against (Lore Bible §6.3). |
| 2. **Tutorial** | Tutorial place | **Exists** | Drillmaster Vask's beats: Footwork, Report In, The Wall (climbing), Strikes, Break a Guard, Defend (block and parry), Alchemy, The Bout (knock and grip), then **the Gate** (Truth's lines). It ends with `FinishTutorial`, which saves `TutorialDone` and sends the player to Ye. In the lore, this is **the Weighing**: Truth testing a stray before letting them in (Lore Bible §6.2). |
| 3. **The waking cutscene** | Ye (Lindenmoor) | **New** (replaces the placeholder) | The stray's first breath in this world. It plays once, on the first arrival (`FlowService` already plays the intro once and saves `Flow.IntroSeen`). §1.3. |
| 4. **Lore** | Ye | **New** | Short and in-world. §1.4. |
| 5. **Main quest** | Ye, then the regions | **New** | Chapter 1, "The Arrow and the Seal" (PROPOSAL). §2. |

**The hand-off:** nothing in steps 1–2 changes. The menu routes a new player to the Tutorial, and the Tutorial routes them to Ye (`Start Flow and Character Creation.md`). In Ye, `FlowService` already calls `IntroCutscene.Play` once for a profile that hasn't seen it. The waking cutscene **takes that slot**. A returning player (`IntroSeen` already true) never sees it again.

**Why it reads well:** the Tutorial ends with the player walking into the Gate. In the lore, that *is* the crossing. The next thing they see is open sky in another world. It feels like waking from a dream, and it isn't one: the grey patch they're lying in proves it (§1.3, shot 4).

**Truth's finale lines:** they live in the Tutorial place in Studio, which isn't mirrored in this repo, so this draft couldn't read them. The Lore Bible (§6.2) proposes three lines that set up the outsider story ("You were not sent. You fell."...). If the owner's lines already say something else, the lore bends to fit (open question 1).

### 1.2 Where they wake

**On the slope of the Ridge Marker's knoll** (PROPOSAL), in Lindenmoor's North Meadows, just above the training field.

- **Why there:** it's real ground in Ye today. The Ridge Marker (a standing stone and cairn on a knoll, with a surveyor's arrow someone keeps scrubbed clean) is already a clue point with its own quest, `lm_ridge`. In the lore it marks the Bureau's buried debt under the ridge (sink **LM-7**), which began to be paid the night the player fell through (Lore Bible §4.1). The first mystery is literally next to the player's head.
- **What can be seen from there** (the Lindenmoor expansion layout): the village's red tile roofs and Mill Creek one way; the training field, its trainers and the north road running up to the gap the other way; the Cypress Ridge rim behind.
- **New:** a one-time **wake point** marker on the knoll. The first arrival spawns there; every later spawn uses the village square as today (`LindenmoorSpawn`).
- **New:** a permanent **grey patch** on the knoll: a ring of dead grey grass a few studs across, the "fall of grey" every stray lands in. Everyone sees it; every new player wakes in it. Townsfolk say it's been spreading since spring.
- **Time of day:** the clock is the same in every server (`WorldClock`), so the scene can't choose its hour. PROPOSAL: the cutscene sets its own sky light for its 15 seconds, then hands back to the real clock.

### 1.3 The waking cutscene, shot by shot

About 15 seconds (PROPOSAL). First person all the way; no HUD; the player can't move until the last shot.

| # | Shot | What we see and hear |
|---|---|---|
| 1 | **Black, then eyes open** | A ringing in the ears fades out: the Gate closing (the Tutorial's last sound, carried over). A slow fade in, with a blink or two (the screen dips dark at the top and bottom). Wind in grass; a far-off train whistle. |
| 2 | **Lying on their back: sky** | The camera looks straight up from the ground. Tall grass frames the edges. A few flakes of grey ash drift up and away on the wind. Clouds drift. The light is soft. |
| 3 | **A bird crosses overhead** | One dark bird, a swift, crosses the sky from one side of the frame to the other, and the camera's eyes follow it slightly. Its call fades as it goes. In the lore it came through with the player; nobody here has a name for it (Lore Bible §6.4). |
| 4 | **Sitting up** | The view rises and tips forward as the character sits up. The sky drops away. The grass in a ring around them is dead and grey, and the green meadow begins just past it. The standing stone comes into view. Their own hands (their chosen look) are in shot, brushing off grey dust. A breath, a rustle of clothes. |
| 5 | **Look left** | The head turns left and holds: Lindenmoor below, chimney smoke, the creek bridge, a train standing at the station. |
| 6 | **Look right** | The head turns right and holds: the training field, small figures at practice, the north road climbing to the gap. The title card shows here (§1.4). |
| 7 | **Back to centre, control returns** | The head comes back to centre on the standing stone and its arrow. The HUD fades in. A groundskeeper is already walking up the slope (§2, beat 1). |

- **Built with:** the existing intro slot (`Modules.UI.IntroCutscene`), a scripted camera, and the player's own character as the first-person body.
- **New assets:** the bird (a small animated model), the grey patch, a few ash particles, the shots' camera path, and a few sounds (the ringing, wind, whistle, the swift's call). The blink uses plain screen fades, no new UI art.

### 1.4 The lore, short and in-world

No lore dump and no long scroll. Three small touches, all in the world:

1. **A title card over shot 6** (PROPOSAL lines: three short lines, white text on the image, then gone):
   > *Nothing is made. Everything is moved.*
   > *What a working takes, the Tally remembers.*
   > *And what is owed, the ground pays.*
2. **Ned Harrow's first lines** (beat 1, PROPOSAL): "Easy. Don't stand up too fast. You came down with the grey, didn't you? Folk call you strays. You're the third this month." Then who he is, where you are, and that he keeps the stone's arrow clean "for the Survey".
3. **A notice on the village notice board** (an inspect point, beat 6). Two sheets:
   - *"BY ORDER OF THE BUREAU OF SURVEY AND ASSAY: the workings marked LM-7 on the ridge are sealed."*
   - *"Persons arriving without papers are requested to present themselves to the Bureau's registrar at Lindenmoor Station."*

   One names the State and its Bureau; the other admits strays exist.

Everything else is learned by playing. The Codex fills as areas are found (this exists), and townsfolk mention the world in their job lines and rumours. The four ideas Chapter 1 needs are **the Tally** (everything has a price), **strays** (you), **sinks** (debts buried in the ground) and **the Bureau** (who buries them). Nothing else is explained in Chapter 1 (Lore Bible §9.3).

---

## 2. The opening chapter: one feature at a time

**Chapter 1, "The Arrow and the Seal"** (PROPOSAL), Lindenmoor, levels 1–6 (the world spec's band).

**The story in one paragraph (PROPOSAL):** you wake in a ring of dead grey grass beside a standing stone, under a bird nobody in the valley can name. Ned Harrow calls you a stray: someone who comes down with the grey. The stone's figures turn out to be a Bureau sink number and a due date, and the date is this year. Thirty years ago the Bureau of Survey and Assay buried a State debt under Lindenmoor's ridge. Now the ground has started to pay it, and that's the door you fell through. Halvard's sealed adit holds the sink's heart. When you open it, a Bureau inspector arrives to push the debt deeper, out of sight and onto the future. You decide with Bess Kettering whether to let him, lock it again yourselves, or tell the whole village. Then you take the night train to the Foundry Yard, where the debt-stones are cast.

### 2.1 The beats

Each beat is one short main quest and teaches **one** feature. "What the player is told" is the only explanation the beat gives: at most two short sentences or one Field Note, shown at the moment of use.

| # | Quest beat (PROPOSAL names and story) | The one feature | What the player is told (PROPOSAL wording) | Reuses |
|---|---|---|---|---|
| 0 | **Waking.** The cutscene. | (the arrival) | The title card's three lines (§1.4). | The intro slot in `FlowService` |
| 1 | **Someone Keeps It Clean.** Ned Harrow finds you in the grey patch, tells you you're a stray, and shows you the stone. Examine the arrow; he tells you he keeps it clean for the Survey. | **Looking and talking:** the Inspect prompt, talking to people with jobs | Field Note **"A Closer Look"** (exists), at the marker. | `lm_ridge` (examine the marker, ask the groundskeeper); Ned Harrow (Lindenmoor roster); `TownsfolkService` bubbles |
| 2 | **The Quick Way Down.** Ned sends you to the village by the children's shortcut: over the practice yard's walls, along the gorge ledge, across the pool. | **Movement:** climb, ledges, wall-run, slide, swim | Ned: "The children's way down goes over the yard walls, along the gorge ledge and across the pool. Mind your breath in deep water." | The LedgeCourse and its world challenge; the `RenseiLedge` gorge walks; `SwimService` pools; the Lindenmoor Run challenge (optional repeat) |
| 3 | **Mine Hours.** Ned says Bess Kettering, the mine hand, knows the ridge better than he does. Examine the boarded shaft at the mine approach and ask her. She gives you the old story: the shaft flooded the year they sank it (her existing line). | **The day/night clock:** people keep hours; lamps light at dusk; night is darker | The quest line (exists in `lm_mine`): "She works at the mine head by day and sits up at the West Lookout after dark." | `lm_mine` (its text already teaches Bess's hours); `WorldClock` |
| 4 | **Cart Trouble.** Bess won't say more while bandits rob her ore carts. Clear their camp in the woods. | **Basic combat** in the open world (the Tutorial taught the moves; this is the first real fight) | New Field Note **"Open Ground"**: "Out here they come in twos and threes and don't take turns. Keep them in front of you and break one guard at a time." | The Grunt spawns there; `CombatDirector`; a `Defeat` objective |
| 5 | **Word Gets Around.** Back in the square, people are already telling your fight. One mentions lights in the old adit at night. | **Rumours:** what you do travels, and people pass on what they hear | New Field Note **"Word Travels"**: "What people see you do becomes a rumour, and rumours travel, even by train. Some of them come back to you." | `RumourService` (the townsfolk's rumour line); `WitnessService` |
| 6 | **What the Arrows Mark.** Read the Bureau's notice on the board, then put the stone, the shaft and the notice together. | **Investigation:** clues, evidence and the **Case Board** | Field Note **"Your Journal"** (exists; held back from beat 1 so it lands here, §2.3). | `InvestigationService`; the evidence from beats 1 and 3 (`lm_ridge_survey`, `lm_shaft_ore`); a new notice inspect and a new first deduction (§5.2) |
| 7 | **Five Teachers.** Bess says the adit is no place for someone with only their fists. Meet the teachers at the training field and say yes to one. | **Alchemy and choosing a medium** | New Field Note **"A Medium"**: "Your hands will only ever take to one medium. Saying yes to a teacher starts their teaching; finish it whenever you like." | Calda, Veyra, Holt and Ansel's dialogues; Brannoc's notice (`brannoc_moved`); `acq_flame`, `acq_ice`, `acq_earth`, `acq_wind`, `acq_metal` (§2.4) |
| 8 | **Number Four.** Go into Halvard's Adit and open his vault. | **Puzzles and minigames:** mechanisms, the winch board, the sluices, the assay ring | Field Note **"A Forgotten Site"** (exists), on entering. | `forgotten_halvard` (whole quest, unchanged); its Pressure Board and Array Restoration; the `adit_truth` deduction ("No. 4 is not ore") |
| 9 | **The Inspector.** By morning a Bureau inspector and State guards have a survey camp at the mine approach. Get close enough to read their work order without being seen. | **Stealth and detection:** crouch, shadow, quiet floors, the stealth sigil, guards who notice | New Field Note **"Unseen"**: "Crouch, keep to shadow and mind loud floors. The sigil shows how close a guard is to noticing you." | `PerceptionService`, `LightService`, `NoiseService`, `StealthUI`; night from the clock |
| 10 | **The Law in Lindenmoor.** The village constable wants a word with anyone seen near the camp. If you weren't seen, he only warns you. | **Heat, Wanted and the law:** crimes, the Wanted badge, decay, fines, the station's papers check | Constable Selden: "Break the law where someone sees it and you'll owe Heat to whoever's law it was. Too much and you're Wanted; until then, a fine clears it." | `HeatService`, `Rensei.Heat` (decay, fines), the station gate's Wanted rules |
| 11 | **Whose Debt.** Bess tells you what her father carted up the ridge in C.R. 184. Decide with her: let the inspector push the debt deeper, lock the vault again yourselves, or tell the square (§2.6). | **Morality, reputation and factions:** deeds, standing, conduct words | Bess: "There's no clean answer here, only who pays. Each side will remember what you chose." Then the existing confirmation: "[This can't be undone.]" | Quest `Outcomes` (like Lise's choice); `MoralityService`, `Rensei.Deeds`, `Rensei.Factions` |
| 12 | **Subject Unknown.** *(Optional; solo-able.)* At the station the Bureau's registrar is noting strays. Note what you can about him, then get his name. Any player you meet there counts too. | **Player Identities** | Field Note **"An Unknown Subject"** (exists), at the first record. | `IdentityService`; the "Introduce yourself" prompt; the Journal's Identities tab; **new: NPC records** (§2.5) |
| 13 | **Company for the Road.** *(Optional.)* Find someone to travel with, or choose to travel alone. | **Parties** | "A party boards together and lands together. Invite someone from the Party menu, or travel alone." | `PartyService` and the Party menu; a new "travel alone" choice |
| 14 | **The Night Train.** The work order says the debt-stones come from the Foundry Yard. Buy a ticket, pass the gate, ride there (or walk the North Road). | **Travel:** trains and roads | "Buy a ticket from the clerk, clear the gate guard, and board before the doors close. The North Road is free, but it's a long walk, and bandits use it too." | `StationService`, `RoadService`, `TravelService`; the `Arrive` objective |

**Chapter reward (PROPOSAL):** Codex entries "Strays" (beat 1), "The Tally" (beat 7) and "Sinks" (chapter end); a Renown bump; and a contact in the Foundry Yard that depends on the beat 11 choice (§2.6).

### 2.2 Why this order

- **Look and talk first (1).** It's the safest thing in the game. It gives the player a person and a question (what is a stray, and what is this stone?) before a single system is explained.
- **Movement next (2).** The Tutorial taught the basics. The world's advanced moves are best learned on a route with no enemies.
- **The clock before people get hard to find (3).** From here on, quest givers keep hours. Bess is the first person who isn't always where you left her.
- **Combat once the player can move and find people (4).** It's a short, real fight, not a lesson, and the player's first deed worth talking about.
- **Rumours right after that deed (5).** The player hears their own fight retold. Nothing explains the rumour system better.
- **Investigation once the player holds clues (6).** Beats 1 and 3 already gave two pieces of evidence, so the first deduction is easy.
- **Alchemy before the Adit (7).** Its mechanisms react to alchemy, so the player should have a teacher first. Every step still has a route without alchemy, so an unstarted or unfinished path never blocks it.
- **Puzzles and minigames in the chapter's set piece (8).** The Adit uses everything learned so far and adds mechanisms and minigames. Opening Halvard's vault is also what lets the Bureau in, which gives beat 9 its reason.
- **Stealth once there's something to hide (9).** The player has opened a State-sealed vault, and the State arrives. Being seen now matters.
- **Heat right after stealth (10).** If the player was seen, Heat is the consequence; if not, the constable explains what would have happened. The lesson lands either way.
- **Morality as the chapter's choice (11).** By now the player knows the sides (the Bureau, the village, Bess), so the choice has weight.
- **Identities, then parties, then travel (12–14).** Meet a stranger, team up, leave together. Parties buy each other tickets and land on the same server, so they come just before the train.

### 2.3 Rules for the opening chapter

- **One new thing per beat.** Each beat explains its feature with **one** Field Note or at most two short sentences, at the moment of use (owner: "explain the features well but don't overload with information").
- **One Field Note per beat (new rule).** If another existing note would fire during a beat (for example the Journal note on the first evidence in beat 1, or the Mechanism note at the Adit's winch in beat 8), it waits until a later beat or the end of this one. A player who already saw a note (in a side quest, say) doesn't see it twice (exists: `Flow.Hints`).
- **Done early counts.** If a player already finished `lm_ridge`, `lm_mine`, `forgotten_halvard` or an acquisition, the beat that reuses it ticks at once (exists: the quest engine's catch-up).
- **Choosing a path, not finishing it** (owner answer 3). Beat 7 completes when the player **starts** a trainer's questline. Finishing it is up to the player; the trainers encourage it but never require it.
- **Every trainer starts in Lindenmoor** (owner answer 2). Metal is the one case the map forces (§2.4).
- **Wrong-guess consequences are off in Chapter 1** (owner answer 5). Chapter 1 is Stakes 0 in the wrong-guess spec (`specs/2026-10-25-wrong-guess-consequences-design.md`): a wrong deduction or minigame answer only shows its line and lets the player try again. Consequences arm from Act II.
- **Solo players are never stuck** (owner answer 6). Beat 12 works with an NPC (§2.5). Beat 13 is optional, with a "travel alone" choice. Neither blocks beat 14.
- **Short.** PROPOSAL target: the whole chapter in 60–90 minutes, each beat 3–8 minutes, except the Adit.

### 2.4 Beat 7 and the Metal path

- **What's in Lindenmoor today:** Calda (Flame), Veyra (Ice), Holt (Earth) and Ansel (Wind) stand at the training field. Their questlines start there and their sites are in Lindenmoor too (the burned laboratory, the frozen research station, the cracked footbridge and the silent observatory).
- **Metal is in the Foundry Yard, as built today.** Brannoc and the forge rooms moved to the Foundry place on 2026-10-24 (region-builds spec §7.2). In Lindenmoor, only **his notice** remains at his old post (exists: the `brannoc_moved` inspect, "GONE TO THE FOUNDRY YARD...").
- **How beat 7 handles Metal:** reading Brannoc's notice **starts `acq_metal`** in Lindenmoor (it already does: `StartsQuest = "acq_metal"`). That counts as choosing a teacher, so beat 7 completes. The questline's first stage is "Travel to the Foundry Yard" (an `Arrive` objective, exists). For a Metal student, beat 14's train ride also completes it, so the two meet naturally. A player who wants Brannoc sooner can ride early, since travel is never locked.
- **So the owner's rule holds:** every questline *starts* in Lindenmoor. Only Metal's continues elsewhere, because that's where it's built. Open question 3 asks whether that's enough.

### 2.5 Beat 12 solo: an NPC in the Identities system

**The beat (PROPOSAL):** **Registrar Lucan Prewitt** sits at a small Bureau desk in Lindenmoor Station's ticket hall, noting strays in the Grey Book. He won't give his name at first. The player:
1. **sees** him (talking to him once makes the record: *Subject 01*, Unknown);
2. **observes** his dress (Amestrian) and, when he clears the steam off the platform with a small Wind cast, his technique (the record becomes Observed, then Suspected once there are two kinds of observation and two meetings);
3. **names** him: they get his introduction on a second talk, or name him from the Journal once Suspected.

He has a page on you too: "You introduced yourself. So did I. Now we each have a record of the other." Any **player** the stray meets at the station fills a record the normal way and also completes the beat.

**Can the Identities system hold an NPC record today? No.** What I checked (`IdentityService`, `Rensei.Identities`, `JournalUI`):
- Records are keyed by the subject's `Identity.CharacterId`, which `IdentityService.CharacterIdOf` reads from a **player's profile**. `Record()` returns nothing for anything that isn't a loaded player.
- Records are only written by player-to-player events: a hit (`OnHit`), a cast seen in range (`Witness`), and `Introduce` (which needs two players within 8 studs, each with a character).
- `Identify` looks for the subject among `Players:GetPlayers()`, and `Confirm` takes the name from the subject's profile.
- `LabelFor` and `KnownNameFor` take a player.
- **What does work as is:** the Journal's Identities tab lists whatever is in `Profile.Identities.Records`, keyed by any string, with the same fields (`N`, `Obs`, `Seen`, `Name`, `Log`, `Links`). The stage rules (`Identities.Stage`) don't care who the subject is. So an NPC record would *display* without a new UI, as long as it's written in the same shape.

**What's new (to build):**
1. **NPC subjects in data:** a small table, for example `Rensei.Identities.Npcs[NpcId] = {Name, Dress, Technique, Weapon}`, and a reserved key prefix (`npc:<NpcId>`) so NPC records can never collide with a `CharacterId`.
2. **Server writers for NPCs:** `IdentityService.MeetNpc / ObserveNpc / IntroduceNpc(Player, NpcId)`, called by the server when the player talks to the NPC, stands in range of its scripted cast, or reaches the introduction line. The rule stays the same: the server is the only witness.
3. **Naming an NPC:** `Identify` checks an `npc:` key against the data table instead of a live player. The Journal's name cycler needs the NPC's name among its choices (today it offers players' names). The 10-minute lock after a wrong name stays (it's not a wrong-guess consequence; it's the existing Identities rule).
4. **Eviction:** story NPC records shouldn't be dropped by the 40-record cap. Mark them `Keep = true`, or let the cap skip `npc:` keys.
5. **To verify while building:** that nothing in `JournalUI` or `WorldService` assumes a record's key is a live player's (the combat log only labels players, so it shouldn't).

### 2.6 Beat 11: the chapter's choice (PROPOSAL)

Bess tells the truth at last: her father, Tom Kettering, carted Bureau crates up the ridge in C.R. 184, and the "flooded" shaft was filled with them. The figures on the stone are the sink's number and the year it falls due. The inspector's work order (beat 9) says he'll **roll** the debt into the heart of Halvard's array, now that someone (you) has opened the vault: due again in C.R. 251, with replacement stones from the Foundry Yard.

| Outcome (flag `Outcome_<quest>`) | What happens | Deed (new) | Foundry contact |
|---|---|---|---|
| **Roll:** let the inspector do it | The valley is safe for now. The debt grows in the dark, and somebody's grandchildren pay. Bess won't look at you. | Order up, Authority up, Bess's trust down (Local: the Bureau knows) | Inspector Denby's letter to the Bureau's man at the Foundry |
| **Seal:** lock the vault again with Bess and tell no one | The Bureau can't roll it. The ridge keeps paying slowly, and the grey patch keeps spreading. Only you and Bess know. | Candor down, Bess's trust up (Private) | Bess's cousin on the Foundry crews (Foundry Hands) |
| **Tell:** raise the square | Constable Selden and half the village turn the inspector away. The truth is out locally, and the Bureau now knows your face. | Townsfolk up, Authority down, Renown up (Local, then Public by rumour) | Wenna Fane of the Circle finds you (she heard) |

Each is told before it's chosen ("[This can't be undone.]") and recorded once, as Lise's choice is today.

---

## 3. The main story arc across the seven regions (PROPOSAL)

### 3.1 The premise

The full version is in `Documents/Lore Bible.md`. In short:
- **The Tally:** every working is paid now, weight for weight. **Debtwork**, working now and paying later, is forbidden. A debt is anchored in a **tallystone** and collected from wherever that stone lies.
- **The State's secret:** in the Bright Years the **Bureau of Survey and Assay** revived debtwork using old Xerxian **sinks** (deep arrays in bedrock). The biggest debt was called in C.R. 183 (**the Eclipse**), and the province that paid is the **Corrupted Lands**. Since then the Bureau has kept the country running by moving debts around: into old mines (Lindenmoor), onto night freight (the Foundry), into frozen vaults (the Northern Wall), and over the border (Aerugo).
- **Strays:** when a debt is called, the Gate opens over the owed ground and things fall through from elsewhere. This year the post-Eclipse sinks are falling due, and strays come down by the dozen. **The player is one.** A stray owes this world nothing, so the Gate doesn't collect from them, which makes them the one courier who can walk into called ground.
- **The question the story asks:** "What does the State owe, who is it owed to, and who is paying?" Stopping the debt hurts ordinary people now; hiding it poisons their grandchildren's ground. There's no clean answer.
- **The antagonists:** **Assayer-General Odette Sallow** (the Bureau) wants to spread the Vell's debt thin over the whole State: the Even Measure. **Sorrel Kade**, the first stray the Bureau ever used, leads the Circle's **Reckoners**, who want the whole debt called at once, on the capital. Both need a clean stray.

### 3.2 The acts

Level bands are from the world spec. Act IV's three regions can be played in any order. Wrong-guess Stakes are from the wrong-guess spec.

| Act | Region | Levels | Its role in the story | Systems it puts in front |
|---|---|---|---|---|
| **Prologue: the Weighing** | Tutorial | — | Truth weighs the stray, wearing Vask's face, then the Gate opens. | Combat basics |
| **I. The Arrow and the Seal** | **Lindenmoor** | 1–6 | You fell through a debt being called. The Bureau would roll it deeper; you make the first choice. | Every feature, one at a time (§2). Wrong guesses off (Stakes 0). |
| **II. Night Freight** | **Foundry Yard** | 5–12 | The stones are cast on Furnace One on nights the ledger calls "banked" (the 14th, C. Ashe). You meet the real Vask, and Wenna Fane. The first big infiltration (the rail depot). The licence choice opens: the State's exam or the Circle's initiation. | Stealth missions; the licence path; Foundry standing; wrong guesses on (Stakes 1) |
| **III. The Deep Ledger** | **Central City** | hub | The Bureau's records: every sink, and the Grey Book, where your own entry was written the morning you arrived. Licence hearings; Peleas Amund; Sallow in person. The act ends with a big choice: make the Ledger public, or trade it. | Renown, Identities, Heat under State law |
| **IV-a. The Border Trade** | **Aerugo Borderlands** | 12–22 | Smugglers sink State stones on the Aerugonian side; the "grey rot" in the vineyards is collection. Shows **where it goes**. | Contracts, the road route, rumours across borders |
| **IV-b. The Old Ground** | **Ishval** | 18–30 | The oldest Paid Land and the Covenant of Ground. Elder Saffa Orun teaches **settling**, which mends called ground without alchemy. Shows **how to stop it**, slowly. | Investigation, Ishvalan standing, sandstorm stealth |
| **IV-c. The Cold Store** | **Northern Wall** | 25–35 | The State's worst stones are kept asleep in the cold, and the cooling is failing. Halvard's name in the records. The Drachman lie. Shows **how much there is**. | Survival in the cold, the hardest compounds |
| **V. What the Ground Keeps** | **Corrupted Lands** | 30–45 | The Eclipse Citadel in the crimson phase. Sallow's Even Measure against Kade's Reckoning. The endings. | Everything; Taboo choices |

### 3.3 Endings (a direction only)

The master plan's Phase 10 (endings) isn't designed yet. These PROPOSAL directions are shaped by the player's deeds, standing, licence path and Taboo marks, never by one last dialogue choice (Lore Bible §7.4):
- **Expose:** the Deep Ledger goes public. The Bureau falls, the foundries slow, and hard but honest years follow. What's owed is still owed, so settling becomes everyone's work.
- **Even Measure:** help Sallow. No more Paid Lands, and every field a little poorer forever. The secret is kept.
- **Settle:** a stray who is still clean (no Taboo marks) carries the Citadel's stone into the Gate and asks Truth the price.
- **Harness:** take the stone's power for yourself (the Taboo path). Strong, feared, and the debt is yours.
- **(Failure) the Reckoning:** if Kade isn't stopped, the capital pays.

The **Legendary Alchemist** title stays earned, as already proposed: top Renown plus the main story's capstone.

---

## 4. Side-quest integration

### 4.1 The rule: side content feeds the story, never blocks it

- **The main path only ever requires main quests.** A main beat's `Requires` names only the previous main beat.
- **Side content gives four things, never a key:** a **shortcut** (a dialogue line or route that skips a step), an **ally** (someone who helps later), an **alternate route** (another way through), and **rewards**.
- **Done early counts:** when a main beat reuses a side quest the player already finished, it ticks at once.
- **Level bands are soft.** A region's band is a warning, not a wall. Travel itself is the only hard gate (you have to get there).

### 4.2 How each kind connects

| Kind | Feeds the main story | Fed by the main story |
|---|---|---|
| **Regional side quests** (e.g. `foundry_ledger`, `chalk_foundry`) | Their evidence opens extra main-quest lines (`Show = "Locked"` choices that become available). Finishing `foundry_ledger` before Act II's depot mission is a shortcut: you already know the 14th's "banked" furnace was poured by C. Ashe. Lise's chalk and the Voided Ledger Line point at the stones' arrays. | Main acts send players into a region, where its side quests are found by clue markers and townsfolk. |
| **Trainer quests** (`acq_*`) | Choosing a teacher is a main beat (beat 7). Later acts give each trainer a role and a view of the debt (Lore Bible §8.1). Path-specific lines use the existing `SavedAffinity` condition. | The main story points the player at the trainers; mastery lessons and exercises keep paying training. |
| **Clue quests** (`lm_ridge`, `lm_mine`, and each region's) | They **are** Chapter 1's beats 1 and 3. Every region keeps the pattern: inspect a clue, ask a townsperson. The townsperson's first answer is the cover story (Ned's hedges, Bess's flood), and the main story reveals the rest. | Main-quest evidence can make a clue quest's answer quicker. |
| **Minigames and puzzles** | Story set pieces (the Adit, the depot's locks, the Ledger's ciphers). | **Consequences for wrong guesses** (owner answer 5): **off in Chapter 1, on from Act II**, told to the player up front and never a dead end. The detail is in `specs/2026-10-25-wrong-guess-consequences-design.md`: Stakes 0 in Act I, 1 in Act II, 2 in Acts III–IV, 3 in Act V. |
| **Stealth contracts** (the stealth missions spec) | Some contracts turn up evidence or contacts the main story can use (a stolen freight waybill shortens Act III). | Main acts unlock each region's job board and fixer, and the story missions run inside the same compounds (the survey camp, the rail depot, the records hall, the cold store, the containment camp). |
| **Nemesis rivals** (`specs/2026-10-25-nemesis-design.md`, concept approved) | A rival's grudge can follow the player into main-story places as an interruption, never as a required fight. | Rivals are born in contracts. The owner's rule stands: first a **rumour warning**, then an **ambush** if the player ignores it. |
| **Reputation in investigations** (`specs/2026-10-25-reputation-investigations-design.md`) | Witnesses answer by your standing, their trust in you and your conduct. Some **lie** (caught out by presenting evidence, which already works), some **refuse**, and some ruthless people **spill secrets more easily** to a ruthless player. Persuade, bribe and intimidate use the dialogue box on a second talk (owner decision, `Decisions.md`). **Every main-quest witness has at least two ways to the truth**, so reputation changes the route, never whether you can finish. | Main-quest choices move the standing that later witnesses react to. |
| **Forgotten Sites** | Each region's site holds a piece of the history: a Xerxian sink, a Bright Years record, a frozen stone. | Main acts point at them through rumours. |

### 4.3 Rewards (PROPOSAL)

| Content | Reward kind |
|---|---|
| Main beats | EXP and money, Renown at chapter ends, codex entries, story contacts |
| Regional side quests | EXP, money, standing with that region's people, sometimes a story shortcut |
| Trainer quests | The alchemy path, training, Mastery (as built) |
| Clue quests | Small EXP, evidence the story can use |
| Stealth contracts | Money by rating (Ghost / Quiet / Loud), faction standing, sometimes evidence |
| Forgotten Sites | Caches, EXP, codex lore about the sinks and the Xerxian kingdom |

All payouts stay once only, as the quest engine already guarantees (a quest leaves Active before anything is paid).

---

## 5. How it uses what exists

### 5.1 Reused as it is

| System | How the main story uses it |
|---|---|
| **Quest engine** (`QuestService`, `Rensei.Quests`) | Each beat is an ordinary quest with **stages** and **objectives** (Talk, Visit, Defeat, Inspect, Evidence, Deduce, Puzzle, Minigame, Mechanism, Flag, Signal, Arrive). **`Requires`** chains the beats. **`Outcomes`** carry the chapter's choices (as Lise's choice does). **`Rewards.Deeds`** record what the player did. Category is already `"Main"` for the acquisition quests. |
| **Quest revisions** (`Revision` / `Prepended`) | When a beat changes later (for example, beat 9 becomes a full stealth mission once those exist), older saves move forward safely, as `acq_metal`'s travel stage did. |
| **`StoryLogic` conditions** | Main dialogue reacts to evidence, deductions, flags, standing, conduct words, trust, Renown, Heat and Wanted, and the saved alchemy path. All of these conditions exist. |
| **Investigations and deductions** (`InvestigationService`, `Rensei.Investigation`, `Rensei.Evidence`) | Clue markers start quests (`StartsQuest`); the Case Board checks deductions; a wrong answer gets the deduction's `Wrong` line. |
| **Townsfolk** (`TownsfolkService`, `Rensei.Townsfolk`) | Clue lines advance quests; rumour lines teach rumours; schedules teach the clock. Ned's and Bess's existing clue lines stay as the cover story. |
| **Dialogue** (`DialogueService`, `Rensei.Dialogues`) | Named story characters use the dialogue box, with conditions and actions (`StartQuest`, `SetFlag`, `GiveEvidence`, `Deed`, `StartMinigame`). |
| **Brannoc's notice** (`brannoc_moved`) | Metal's Lindenmoor start for beat 7 (§2.4). |
| **Morality, Heat, rumours, witnesses, Identities, travel, parties, puzzles, minigames, Forgotten Sites, Field Notes** | Each is taught by its beat in §2 and used as built, except the Identities NPC records (§2.5). |

### 5.2 New for the main story

- **The waking cutscene** (replaces `IntroCutscene.Play`), the bird, the grey patch, the ash, and the one-time **wake point**.
- **About 14 new short quests** for Chapter 1 (the beats), with their dialogue and stage text.
- **New Field Notes:** "Open Ground" (beat 4), "Word Travels" (5), "A Medium" (7) and "Unseen" (9). Plus the **one-note-per-beat rule**: a note that would fire during a beat waits until the next one (a small queue on the existing `Flow.Hints`).
- **New story characters** (Lore Bible §8.2): Registrar Lucan Prewitt (beat 12), Inspector Aurel Denby (beats 9–11) and Constable Mabry Selden (beat 10); later Wenna Fane, Odette Sallow, Sorrel Kade, Elder Saffa Orun and Peleas Amund. Ned Harrow and Bess Kettering, who exist as townsfolk, get story lines. Townsfolk speak in bubbles only, so beat 11's choice needs a **dialogue tree for Bess**.
- **New data:**
  - the notice board inspect point and its evidence (the Bureau's two sheets, §1.4);
  - the first deduction (beat 6), "What the Marker Records": where it points (`lm_shaft_ore`), what the figures are (the notice's evidence) and when (`lm_ridge_survey`). Its conclusion: "Not a boundary stone: a Bureau mark for something sunk under the ridge, due this year.";
  - the work-order evidence at the survey camp (beat 9);
  - Codex entries "Strays", "The Tally", "Sinks" and "The Bird With No Name";
  - deeds for the three beat 11 outcomes and for trespassing on a sealed State site;
  - a Militia fine desk in Lindenmoor (fines are paid at Foreman Brask today, for State Heat only);
  - the "travel alone" choice (a flag) for beat 13.
- **Identities NPC records** (§2.5): NPC subjects in data, server writers, naming an NPC, and eviction safety.
- **A guaranteed rumour** about the player's beat 4 fight, so beat 5 always has something to hear.
- **The survey camp** at the mine approach (beat 9). It later becomes Lindenmoor's first stealth compound (stealth missions spec §2.2).
- **Text changes the lore suggests** (owner's call, open question 2): the birth deeds' text ("Born in Amestris" could read "Came through as an Amestrian") and the creator's nation blurbs (Lore Bible §4.2).

### 5.3 To check before building

- **The Tutorial's Alchemy beat for a new player:** a new player has no path until a teacher gives one (the creator's Alchemy step was removed). In the lore, Truth lets the stray's hands *try* a medium during the Weighing; the build must decide what the beat actually casts for a player with no path.
- **Truth's finale lines in the Tutorial place:** compare them with the Lore Bible's (§6.2) before writing anything that quotes them.

---

## 6. Open questions for the owner

### 6.1 Closed by the owner's answers (2026-10-25)

| # | The question | The answer | Where it's applied |
|---|---|---|---|
| 1 | Who is the player when they wake? | "someone who was transported to another world (the alchemy world)" | A stray (§1, §2; Lore Bible §6) |
| 2 | Where do the acquisition questlines start? | "Each trainer's starting quest should be in Lindenmoor for now, until we add the other maps later." | §2.3, §2.4 |
| 3 | Must Chapter 1 require a finished alchemy path? | "doesn't require a finished alchemy path, but if players want to they can" | Beat 7, §2.3 |
| 4 | Is "dross" the story's spine? | "Nah let's create a full lore for the game that's original, immersive, and still follows the FMA theme." | `Documents/Lore Bible.md`; §§1.4, 2, 3 |
| 5 | Wrong-guess consequences in Chapter 1? | "Good." (off in Chapter 1, on from Act II) | §2.3, §4.2 |
| 6 | Solo players and beats 12–13? | "Yes. (the identity quests should be able to do solo if you want)." | Beats 12–13, §2.5 |

### 6.2 New questions (PROPOSAL recommendations)

1. **Truth's lines at the end of the Tutorial.** They're in Studio, not in the repo, so this draft couldn't read them. Use the Lore Bible's three lines ("You were not sent. You fell." ...), or keep yours and fit the lore to them?
   **Recommended:** send me your current lines; keep yours where they fit, and add "You were not sent. You fell." if nothing yet says the player came from elsewhere.
2. **Text that already ships with the series' own events in it.** The creator's nation blurbs mention "the Promised Day", "Briggs" and the series' eastern art, and the birth deeds say "Born in Amestris" although the player is a stray. Reword them to the Lore Bible's versions?
   **Recommended:** yes, as one small text pass. They're display text only, and no save data changes.
3. **Metal's start (beat 7).** Is Brannoc's notice in Lindenmoor enough as Metal's "starting quest in Lindenmoor", or should Brannoc stand at the training field again until other maps exist?
   **Recommended:** the notice. Moving him back would undo the Foundry move, and the train ride in beat 14 carries a Metal student straight to him.
4. **Can a stray ever go home?** This shapes the "Settle" ending and what Truth asks for.
   **Recommended:** leave it unknown until Act V. Truth's answer is a price, and the player decides whether to pay it.
5. **The series' terms in older specs.** "Philosopher's Stone" (and the "Philosopher's Tier" rank), "Equivalent Exchange" and the Silver Watch appear in the morality specs. Adopt the Lore Bible's replacements: **tallystone**, **the Tally / the price**, the **Tallybook**?
   **Recommended:** yes for anything players read. "Stone Abilities" can stay as an internal label, and the Marcoh rule is unchanged.

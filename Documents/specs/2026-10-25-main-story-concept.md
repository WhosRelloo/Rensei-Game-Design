# Main story: concept (DRAFT for the owner)

**Status:** **DRAFT**, 2026-10-25, revised twice that day to the owner's answers and review. Written for the owner to read, change and approve. Nothing here is built, and nothing here is canon until the owner says so. The lore lives in `Documents/Lore Bible.md` (DRAFT).

**Owner's request (their exact words):** "I want the game to Go like this: Character Creation > Tutorial > Main Game Cutscene of the character waking up in 1st person seeing a bird fly across the sky above him/her, then they get up and look left and right > Lore + Main Quest. I want the first main quests to introduce all the in-depth features in the game 1 by 1 and in a simple way for players to understand."

## Owner's answers (2026-10-25)

**First round, recorded verbatim:**

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

**Second round (the owner's review of the lore and their answers to the new questions):**

> "change the word 'working' for the alchemy to something more FMA related. Make the ancient kingdom name something cooler. And I want the lore to be a little more understandable. You can use FMA words too I don't mind."
>
> 1. "Use the proposed ones." (Truth's finale lines)
> 2. "Keep the FMA terms." (the shipped creator text, the nation names and "Xerxian" stay)
> 3. "Brannoc's notice is pretty good."
> 4. "Give them a better term than strays." On whether they can go home, the owner chose **option C: it stays a mystery**.
> 5. "Keep the FMA terms like I said."
>
> "The tutorial should have a cool cutscene when you join it as well."
>
> "There should be a good amount (BUT NOT TOO MUCH) cutscenes throughout the story in REALLY IMPORTANT parts"
>
> "after the player's camera goes to the center, the camera should smoothly transition from first person to 3rd person."

**Third round (the last lore questions):**

> Human transmutation's price: "A limb, then automail."
> Truth's look: "He should look like the one we have in tutorial."
> The Gate set: "Keep the existing set."
> Mezarath and Farborn: "Keep both."

**What they change in this draft:**
- **The player is Farborn:** someone who fell through the Gate from another world (Lore Bible §6). "Stray" is retired.
- **The lore uses series words, in plain language:** transmutation, Equivalent Exchange (the law's name here), Philosopher's Stone (in this world, a stone that holds an unpaid debt and is never made of people), State Alchemist. The story, characters and events stay original.
- **The ancient empire is Mezarath.**
- **The start flow gains a Tutorial opening cutscene** (§1.2). The waking cutscene now ends with a smooth move from first person to third person (§1.4).
- **A small set of story cutscenes,** only at really important moments (§4).
- **Going home stays a mystery.** There are hints only, and no ending promises it or rules it out.
- **Every trainer starts in Lindenmoor.** For Metal, that start is Brannoc's notice (owner: "pretty good").
- **Beat 7** completes when a path is **started**. **Wrong-guess consequences** are off in Chapter 1. **Beats 12–13** are optional, and beat 12 can be done solo.

**Rules this draft follows:**
- **Every new name, line, number and plot point is a PROPOSAL.** The owner's story notes (the web link in `README.md`, which I couldn't read) win wherever they disagree.
- **Explain each feature well, briefly.** Every beat says **what the player is told**: at most two short sentences or one Field Note, at the moment of use.
- **What exists is named as existing; what's new is marked new** (§6).

---

## 1. The start flow

### 1.1 Step by step

| Step | Place | Status | What happens |
|---|---|---|---|
| 1. **Character creation** | Character Customization (the menu place) | **Exists** | Main menu, save slots, nation, name, look, clan roll, starting weapon. In the lore, the nation and clan are the people and family the Gate gives the Farborn (Lore Bible §6.3). |
| 2. **Tutorial opening cutscene** | Tutorial place | **New** | The pull through the Gate (§1.2). It plays once, before Vask's first beat. |
| 3. **Tutorial** | Tutorial place | **Exists** | Drillmaster Vask's beats: Footwork, Report In, The Wall (climbing), Strikes, Break a Guard, Defend (block and parry), Alchemy, The Bout (knock and grip), then **the Gate** and Truth's lines. It ends with `FinishTutorial`, which saves `TutorialDone` and sends the player to Ye. In the lore, this is Truth testing the newcomer. |
| 4. **The waking cutscene** | Ye (Lindenmoor) | **New** (replaces the placeholder) | The first breath in this world. It plays once, on the first arrival (`FlowService` already plays the intro once and saves `Flow.IntroSeen`) (§1.4). |
| 5. **Lore** | Ye | **New** | Short and in-world (§1.5). |
| 6. **Main quest** | Ye, then the regions | **New** | Chapter 1, "The Arrow and the Seal" (PROPOSAL) (§2). |

**The hand-off:** nothing else in steps 1 and 3 changes. The menu routes a new player to the Tutorial, and the Tutorial routes them to Ye (`Start Flow and Character Creation.md`). In Ye, `FlowService` already calls `IntroCutscene.Play` once for a profile that hasn't seen it, and the waking cutscene **takes that slot**.

**Why it reads well:** the Tutorial opens with the fall and ends with the player walking through the Gate. The next thing they see is open sky in another world. It feels like waking from a dream, and it isn't one: the grey patch they're lying in proves it.

**Truth's finale lines** (owner: "Use the proposed ones"): *"You were not sent. You fell." / "The ground here is paying, and every door swings both ways." / "You owe this world nothing. Keep it that way, if you can."* They go into the Tutorial's existing finale, which lasts about 9 seconds (`FINALE_TIME`). The finale's text lives in Studio (`TutorialSteps` and the Tutorial client, not mirrored in this repo).

### 1.2 The Tutorial opening cutscene (new)

**Story:** the player being pulled out of their own world and through the Gate. It ends as Truth's test begins. About 25 seconds (PROPOSAL). It is first person throughout, with no HUD, and letterbox bars from shot 3 to shot 6.

| # | Shot | What we see and hear |
|---|---|---|
| 1 | **Home, just a glimpse** (0–4 s) | Looking out of a rain-streaked window at dusk. Everything beyond the glass is soft and out of focus; home stays the player's own. A small dark bird, a **swift**, sits on a wire outside. Rain on glass, far-off everyday noise. |
| 2 | **The colour drains** (4–8 s) | The sound drops away to nothing. The colour runs out of the picture from the edges in, until it's grey. The swift takes off. |
| 3 | **The pull** (8–13 s) | The view tips forward and falls. The window is gone and there's only white rushing past. The player's own hands come up into frame. A low sound grows: beads clicking on wood, like someone counting. |
| 4 | **The Gate** (13–18 s) | The fall slows and stops. The player is standing before **the Gate as it stands in the Tutorial** (the owner's existing set). The counting stops. |
| 5 | **Truth** (18–23 s) | **Truth** is there in its own form, as built in the Tutorial place. It turns toward the player and says one line: *"Another one. Let's see what you're worth."* |
| 6 | **The yard appears** (23–27 s) | The white fills in around the player (posts, walls, ground) until it's the Tutorial's training yard, with Vask, Truth's copy of the drillmaster, standing in it. The letterbox lifts, the HUD fades in, and Vask's first beat (Footwork) starts. |

- **The one link to the waking cutscene:** the **swift**. Here it flies off as the colour drains (shot 2); in Lindenmoor it crosses the sky above the player (waking shot 3). It's the same bird, and it came through with them.
- **Where it hooks in** (checked in `Scripts/Tutorial/`):
  - `TutorialController.Begin` waits for the profile, then `OnCharacter` waits about a second and calls `StartStep(Player, S.Step)`.
  - The new cutscene plays just before that first `StartStep`, only when the player is starting from the first beat (no saved `Flow.TutorialStep`) and a new flag, `Flow.TutorialIntroSeen`, isn't set.
  - The server sends the client an "Intro" message (the controller already talks to the client this way: "Step", "Finale"), waits for the client's "done" or a timeout (PROPOSAL 35 s), saves the flag, then starts the beat.
  - The Tutorial's UIHandler already loads an `IntroCutscene` module, which is a natural home for the client side.
  - The Tutorial's step data (`TutorialSteps`) and its client script live in Studio and aren't mirrored here, so the build must check them there.
  - The Tutorial runs one player per server, so no other player is affected.
- **Once per profile; skippable after the first view** (PROPOSAL). A save slot sees it once. If the same account has already seen it on another slot, a "Hold to skip" prompt appears, using the existing prompt style (no new UI art).
- **Uses only existing UI:** plain screen fades and letterbox bars.
- **New assets:**
  - **Models:** the swift (shared with the waking cutscene), a small window-and-rain set, and white ground for the fall. They're built off the playable map in the Tutorial place. **The Gate and Truth reuse the Tutorial's existing set and figure as built** (owner: "Keep the existing set"); shots 4–5 are staged at that set, or at a copy of it.
  - **Animations (slots the owner would upload):** `Intro_SwiftPerch` and `Intro_SwiftTakeoff` (the swift), `Intro_FallHands` (first-person hands rising), and `Intro_TruthTurn` for Truth turning toward the player (only if the Tutorial's Truth figure is rigged; otherwise a camera move does the work).
  - **Sounds:** rain on glass, far-off everyday noise, the silence drop, the counting beads, and Truth's one line (voice, or a text line in the letterbox).

### 1.3 Where they wake

**On the slope of the Ridge Marker's knoll** (PROPOSAL), in Lindenmoor's North Meadows, just above the training field.

- **Why there:** it's real ground in Ye today, and the Ridge Marker is already a clue with its own quest, `lm_ridge`. In the lore, its figures mark the Bureau's buried debt under the ridge, which started being collected the night the player fell through.
- **What can be seen:** the village's red roofs and Mill Creek one way; the training field, its trainers and the north road the other way; the Cypress Ridge rim behind.
- **New:** a one-time **wake point** on the knoll. The first arrival spawns there; later spawns use the village square as today (`LindenmoorSpawn`).
- **New:** a permanent **grey patch** on the knoll: a ring of dead, colourless grass where every Farborn lands. Everyone sees it, and townsfolk say it's been spreading since spring.
- **Time of day:** the clock is shared by every server (`WorldClock`). PROPOSAL: the cutscene sets its own light for its length, then hands back to the real clock.

### 1.4 The waking cutscene, shot by shot

About 17 seconds (PROPOSAL). First person until the last shot; no HUD; the player can't move until the camera reaches its play position.

| # | Shot | What we see and hear |
|---|---|---|
| 1 | **Black, then eyes open** | A faint ringing fades: the Gate closing. A slow fade in with a blink or two (the screen dips dark at the top and bottom). Wind in grass; a far-off train whistle. |
| 2 | **Lying on their back: sky** | Looking straight up. Tall grass at the edges, a few flakes of grey drifting up and away, clouds moving. |
| 3 | **The swift crosses overhead** | The same small dark bird from the Tutorial's opening crosses from one side of the frame to the other, and the eyes follow it. Its call fades. |
| 4 | **Sitting up** | The view rises and tips forward. In a ring around the player the grass is dead and grey, and the green begins just past it. The standing stone comes into view. Their own hands (their chosen look) brush off grey dust. |
| 5 | **Look left** | The head turns and holds: Lindenmoor below, chimney smoke, the creek bridge, a train at the station. |
| 6 | **Look right** | The head turns and holds: the training field, figures at practice, the north road to the gap. The title card shows here (§1.5). |
| 7 | **Back to centre, then out to third person** | The head comes back to centre on the standing stone and its arrow. Then the camera pulls smoothly out of the player's eyes, back and up, into the normal third-person play camera behind the character. The move takes about 1.5–2 s (PROPOSAL), eased in and out, with no cut. The HUD fades in as the camera settles, control returns when it reaches its play position, and a groundskeeper is already walking up the slope (beat 1). |

- **Built with:** the existing intro slot (`Modules.UI.IntroCutscene`), a scripted camera, and the player's own character as the body.
- **The camera hand-off:** shot 7 ends by handing control to the game's own camera, so the end position must match the player's current camera settings: distance, field of view (a Settings row, exists), and **shift lock** if it's on. The cutscene should read those settings when it starts the pull-out, aim for exactly where the game camera will be, and only then give the camera back.
- **New assets:** the swift (shared), the grey patch, a few grey flakes, the camera path, and sounds (ringing, wind, whistle, the swift's call). The blink is plain screen fades.

### 1.5 The lore, short and in-world

There's no lore dump. Three small touches:

1. **A title card over shot 6** (PROPOSAL; three short lines, white text, then gone):
   > *Every transmutation has a price.*
   > *Some prices are paid at once.*
   > *Some are buried, and the ground pays them later.*
2. **Ned Harrow's first lines** (beat 1, PROPOSAL): "Easy. Don't get up too fast. You came down with the grey, didn't you? Folk call you Farborn. You're the third this month." Then who he is, and that he keeps the stone's arrow clean "for the Survey".
3. **A notice on the village notice board** (an inspect point, beat 6). Two sheets:
   - *"BY ORDER OF THE BUREAU OF SURVEY AND ASSAY: the old workings marked LM-7 on the ridge are sealed."*
   - *"Persons arriving without papers are asked to report to the Bureau's registrar at Lindenmoor Station."*

Chapter 1 needs only four ideas: **Equivalent Exchange** (everything has a price), **Farborn** (you), **buried debt** (stones in the ground) and **the Bureau** (who buries them). Everything else comes later or sits in the Codex (exists).

---

## 2. The opening chapter: one feature at a time

**Chapter 1, "The Arrow and the Seal"** (PROPOSAL). Lindenmoor, levels 1–6.

**The story in one paragraph (PROPOSAL):**
- You wake in a ring of dead grey grass beside a standing stone, under a bird nobody in the valley can name. Ned Harrow calls you Farborn: someone who came down with the grey.
- The figures on the stone turn out to be a Bureau number and a year: this year. Thirty years ago the Bureau buried a State debt under the ridge, locked in Philosopher's Stones. Now the ground has started to pay it, and that's the door you fell through.
- Halvard's sealed mine holds the heart of an old circle under the ridge. When you open his vault, a Bureau inspector arrives to bury the debt deeper, out of sight, for someone else to pay later.
- You decide with Bess Kettering whether to let him, seal it again yourselves, or tell the whole village.
- Then you take the night train to the Foundry Yard, where the stones are made.

### 2.1 The beats

Each beat is one short main quest and teaches **one** feature. "What the player is told" is the only explanation the beat gives.

| # | Quest beat (PROPOSAL names and story) | The one feature | What the player is told (PROPOSAL wording) | Reuses |
|---|---|---|---|---|
| 0 | **Waking.** The cutscene. | (the arrival) | The title card (§1.5). | The intro slot in `FlowService` |
| 1 | **Someone Keeps It Clean.** Ned Harrow finds you in the grey patch, tells you you're Farborn, and shows you the stone. Examine the arrow; he says he keeps it clean for the Survey. | **Looking and talking:** the Inspect prompt; people with jobs | Field Note **"A Closer Look"** (exists), at the stone. | `lm_ridge`; Ned Harrow (Lindenmoor roster); `TownsfolkService` |
| 2 | **The Quick Way Down.** Ned sends you to the village by the children's shortcut. | **Movement:** climb, ledges, wall-run, slide, swim | Ned: "The children go over the yard walls, along the gorge ledge and across the pool. Watch your breath in deep water." | The LedgeCourse; the `RenseiLedge` gorge walks; `SwimService` pools; the Lindenmoor Run challenge |
| 3 | **Mine Hours.** Ned says Bess Kettering knows the ridge. Look at the boarded shaft and ask her. She tells the old story: the shaft flooded (her existing line). | **The day/night clock:** people keep hours | The quest text (exists): "She works at the mine head by day and sits up at the West Lookout after dark." | `lm_mine`; `WorldClock` |
| 4 | **Cart Trouble.** Bess won't say more while bandits rob her ore carts. Clear their camp in the woods. | **Combat** in the open world | New Field Note **"Open Ground"**: "Out here enemies come in twos and threes. Keep them in front of you and break one guard at a time." | The Grunt spawns; `CombatDirector`; a `Defeat` objective |
| 5 | **Word Gets Around.** In the square, people are already telling your fight. One mentions lights in the old mine at night. | **Rumours** | New Field Note **"Word Travels"**: "What people see you do becomes a rumour. Rumours spread, even by train." | `RumourService`; `WitnessService` |
| 6 | **What the Arrows Mark.** Read the Bureau's notice, then put the stone, the shaft and the notice together. | **Investigation:** evidence and the **Case Board** | Field Note **"Your Journal"** (exists; held back from beat 1 so it lands here). | `InvestigationService`; `lm_ridge_survey`, `lm_shaft_ore`; a new notice and a new first deduction (§6.2) |
| 7 | **Five Teachers.** Bess says the mine is no place for someone with only their fists. Meet the teachers at the training field and say yes to one. | **Alchemy: choosing a path** | New Field Note **"Choosing a Path"**: "You can only ever learn one path of alchemy. Saying yes starts the lessons; finish them whenever you like." | Calda, Veyra, Holt and Ansel's dialogues; Brannoc's notice (`brannoc_moved`); `acq_flame` … `acq_metal` (§2.4) |
| 8 | **Number Four.** Go into Halvard's Adit and open his vault. | **Puzzles and minigames** | Field Note **"A Forgotten Site"** (exists), on entering. | `forgotten_halvard` (unchanged); Pressure Board and Array Restoration; the `adit_truth` deduction ("No. 4 is not ore") |
| 9 | **The Inspector.** By morning a Bureau inspector and State guards have a camp at the mine. Read their work order without being seen. | **Stealth** | New Field Note **"Unseen"**: "Crouch, stay in shadow and avoid loud floors. The sigil shows how close a guard is to spotting you." | `PerceptionService`, `LightService`, `NoiseService`, `StealthUI` |
| 10 | **The Law in Lindenmoor.** The constable wants a word with anyone seen near the camp. If you weren't seen, he only warns you. | **Heat, Wanted and the law** | Constable Selden: "Break the law in front of witnesses and you'll get Heat. Too much makes you Wanted; until then, a fine clears it." | `HeatService`, `Rensei.Heat`, the station gate's Wanted rules |
| 11 | **Whose Debt.** Bess tells you what her father carted up the ridge thirty years ago. Decide together (§2.6). | **Morality and reputation** | Bess: "There's no clean answer. Just who pays. Each side will remember what you chose." Then the existing "[This can't be undone.]". | Quest `Outcomes`; `MoralityService`, `Rensei.Deeds`, `Rensei.Factions` |
| 12 | **Subject Unknown.** *(Optional; solo-able.)* At the station, the Bureau's registrar is recording Farborn. Note what you can about him, then learn his name. Any player you meet there counts too. | **Player Identities** | Field Note **"An Unknown Subject"** (exists), at the first record. | `IdentityService`; the Journal's Identities tab; **new: NPC records** (§2.5) |
| 13 | **Company for the Road.** *(Optional.)* Find someone to travel with, or choose to travel alone. | **Parties** | "A party boards together and arrives together. Invite someone from the Party menu, or travel alone." | `PartyService` and the Party menu; a new "travel alone" choice |
| 14 | **The Night Train.** The work order says the stones come from the Foundry Yard. Buy a ticket and ride there, or walk the North Road. | **Travel** | "Buy a ticket from the clerk, pass the gate guard, and board before the doors close. The road is free, but it's long, and bandits use it too." | `StationService`, `RoadService`, `TravelService`; the `Arrive` objective |

**Chapter reward (PROPOSAL):** Codex entries "Farborn" (beat 1), "Equivalent Exchange" (beat 7) and "Buried Debts" (chapter end); a Renown bump; and a Foundry Yard contact that depends on the beat 11 choice.

### 2.2 Why this order

- **Look and talk first (1):** it's safe, and it gives the player a person and a question before any system is explained.
- **Movement (2):** advanced moves are best learned on a route with no enemies.
- **The clock (3):** from here on, people keep hours, and Bess is the first who isn't always in the same place.
- **Combat (4):** a short, real fight once the player can move and find people. It's also their first deed worth talking about.
- **Rumours (5):** the player hears their own fight retold.
- **Investigation (6):** the player already holds two clues, so the first deduction is easy.
- **Alchemy before the mine (7):** its mechanisms react to alchemy. Every step still works without alchemy.
- **Puzzles (8):** the chapter's set piece. Opening the vault is also what lets the Bureau in.
- **Stealth (9), then the law (10):** being seen now matters, and Heat is the consequence. If the player wasn't seen, the constable explains what would have happened.
- **The choice (11):** by now the player knows the sides.
- **Identities, parties, travel (12–14):** meet a stranger, team up, leave together.

### 2.3 Rules for the opening chapter

- **One new thing per beat,** explained with one Field Note or at most two short sentences, at the moment of use.
- **One Field Note per beat (new rule).** If another existing note would fire during a beat (for example the Journal note in beat 1, or the Mechanism note at the mine's winch in beat 8), it waits for a later beat. A note already seen is never shown twice (exists: `Flow.Hints`).
- **Done early counts:** a beat that reuses a side quest the player already finished ticks at once (exists: catch-up).
- **Starting a path is enough:** beat 7 completes when a trainer's questline starts. Finishing it is up to the player.
- **Every trainer starts in Lindenmoor:** for Metal, that start is Brannoc's notice (§2.4).
- **Wrong-guess consequences are off in Chapter 1** (Stakes 0 in `specs/2026-10-25-wrong-guess-consequences-design.md`). A wrong answer just shows its line and lets the player try again.
- **Solo players are never stuck:** beat 12 works with an NPC, and beat 13 has a "travel alone" choice. Neither blocks beat 14.
- **Short:** PROPOSAL 60–90 minutes for the chapter, 3–8 minutes per beat, except the mine.

### 2.4 Beat 7 and the Metal path

- **In Lindenmoor today:** Calda, Veyra, Holt and Ansel stand at the training field, and their questlines and sites are all in Lindenmoor.
- **Metal is in the Foundry Yard, as built:** Brannoc and the forge rooms moved there on 2026-10-24. In Lindenmoor only **his notice** remains at his old post (exists: `brannoc_moved`).
- **How beat 7 handles Metal:** reading the notice starts `acq_metal` in Lindenmoor (`StartsQuest`, exists), which completes beat 7. The questline's first stage is "Travel to the Foundry Yard" (`Arrive`, exists), and beat 14's train ride completes it. The owner approved this: "Brannoc's notice is pretty good."

### 2.5 Beat 12 solo: an NPC in the Identities system

**The beat (PROPOSAL):** **Registrar Lucan Prewitt** sits at a small Bureau desk in Lindenmoor Station's ticket hall, recording Farborn. He won't give his name at first.
1. Talking to him once creates the record: *Subject 01*, Unknown.
2. Noticing his clothes, then the small Wind cast he uses to clear steam off the platform, moves the record to Observed, then to Suspected after a second meeting.
3. On a third talk he introduces himself, or the player can name him from the Journal once he's Suspected.

His line: "You introduced yourself. So did I. Now we each have a record of the other." Any **player** met at the station also completes the beat.

**Can the Identities system hold an NPC record today? No.** What I checked (`IdentityService`, `Rensei.Identities`, `JournalUI`):
- Records are keyed by the subject's `Identity.CharacterId`, which is read from a **player's profile**. `Record()` returns nothing for anyone else.
- Only player-to-player events write records: hits, casts seen in range, and `Introduce` (two players within 8 studs).
- `Identify` searches only `Players:GetPlayers()`, and the confirmed name comes from the subject's profile.
- **What already works:** the Journal tab lists whatever is in `Profile.Identities.Records`, under any key, as long as the record has the same fields, and the stage rules don't care who the subject is. So an NPC record would display without new UI.

**What's new (to build):**
1. **NPC subjects in data:** for example `Rensei.Identities.Npcs[NpcId] = {Name, Dress, Technique, Weapon}`, with an `npc:` key prefix so NPC records never collide with players'.
2. **Server-side writers** to meet, observe and introduce an NPC. The server stays the only witness.
3. **Naming an NPC:** `Identify` checks an `npc:` key against the data. The Journal's name list must include the NPC's name. The existing 10-minute lock after a wrong name stays.
4. **The 40-record cap** must never drop a story NPC's record.
5. **To verify while building:** that nothing in `JournalUI` or `WorldService` assumes a record belongs to a live player.

### 2.6 Beat 11: the chapter's choice (PROPOSAL)

Bess finally tells the truth. Thirty years ago her father, Tom Kettering, carted Bureau crates up the ridge, and the "flooded" shaft was filled with Philosopher's Stones. The figures on the marker are the Bureau's number and the year the debt comes due. The inspector's work order (beat 9) says he'll move the debt into the heart of Halvard's circle, now that someone (you) has opened the vault. It will then be due again in forty years, with new stones from the Foundry Yard.

| Choice (flag value) | What happens | Deed (new) | Foundry contact |
|---|---|---|---|
| **Deeper:** let the inspector do it | The valley is safe for now. The debt grows in the dark, and somebody's grandchildren pay. Bess won't look at you. | Order and Authority up, Bess's trust down (Local) | Inspector Denby's letter to the Bureau's man at the Foundry |
| **Seal:** lock the vault again with Bess and tell no one | The Bureau can't move it. The ridge keeps paying slowly, and the grey patch keeps spreading. Only you and Bess know. | Candor down, Bess's trust up (Private) | Bess's cousin on the Foundry crews |
| **Tell:** raise the village | The constable and half the village turn the inspector away. The truth is out locally, and the Bureau knows your face. | Townsfolk and Renown up, Authority down (Local, then Public) | Wenna Fane of the Circle finds you |

Each choice is confirmed before it's taken and recorded once, as Lise's choice is today.

---

## 3. The main story across the seven regions (PROPOSAL)

### 3.1 The premise

The full version is in the Lore Bible; it opens with "The story in 60 seconds". In short:
- **Equivalent Exchange:** every transmutation is paid for at once. Transmuting now and paying later, by leaving the price in a **Philosopher's Stone**, is forbidden. The debt is collected later from the ground around the stone.
- **The State's secret:** in its boom years the **Bureau of Survey and Assay** started borrowing again, using the buried circles of the ancient empire of **Mezarath**. Thirty-one years ago the biggest debt came due. The sky stayed bright, but the colour drained from a whole province and the ground went silent; the papers called it **the Eclipse** when the province's "second sun" furnace went out. That province is the **Corrupted Lands**, and it's still paying. Since then the Bureau has hidden its debts in old mines, on night trains, in frozen vaults and over the border.
- **Farborn:** when a debt is collected, the Gate opens over that ground, and sometimes people fall through from other worlds. This year it happens every week. **The player is one of them.** A Farborn owes this world nothing, so the Gate doesn't collect from them, which makes them the only courier who can walk into paying ground.
- **The question:** "What does the State owe, and who is paying for it?" Stopping the borrowing hurts people now; hiding it poisons their grandchildren's land.
- **The antagonists:**
  - **Assayer-General Odette Sallow** of the Bureau wants to break the Corrupted Lands' debt into hundreds of small ones, buried across the country and due in a hundred years.
  - **Sorrel Kade,** the first Farborn the Bureau ever used, leads the Circle's **Reckoners**, who want every debt sent back to the foundries and the Bureau's halls.
  - Both need a Farborn.
- **Going home stays a mystery** (owner). The story hints and never confirms.

### 3.2 The acts

Level bands are from the world spec. Act IV's three regions can be played in any order. Wrong-guess Stakes are from the wrong-guess spec.

| Act | Region | Levels | Its role in the story | Systems it puts in front |
|---|---|---|---|---|
| **Prologue** | Tutorial | — | The pull through the Gate, Truth's test, and the Gate opening. | Combat basics |
| **I. The Arrow and the Seal** | **Lindenmoor** | 1–6 | You fell through a debt being collected. The Bureau would bury it deeper, and you make the first choice. | Every feature, one at a time (§2). Wrong guesses off. |
| **II. Night Freight** | **Foundry Yard** | 5–12 | The stones are made on Furnace One on nights the ledger calls "banked" (the 14th, C. Ashe). You meet the real Vask, and Wenna Fane. The first big infiltration (the rail depot). The licence choice opens: the State Alchemist exam or the Circle. | Stealth missions; the licence path; Foundry standing; wrong guesses on (Stakes 1) |
| **III. The Ledger** | **Central City** | hub | The Bureau's secret ledger of every buried stone and every Farborn, including your own entry. Licence hearings, Peleas Amund, Sallow in person. It ends with a choice: make the ledger public, or trade it. | Renown, Identities, Heat under State law |
| **IV-a. The Border Trade** | **Aerugo Borderlands** | 12–22 | Smugglers bury State stones on the Aerugonian side, and the grey rot in the vines is collection. You meet Kade. Shows **where the debt goes**. | Contracts, the road route, rumours across borders |
| **IV-b. The Old Ground** | **Ishval** | 18–30 | The oldest paid land. Elder Saffa Orun shows how to heal it by hand. Shows **how to undo it**, slowly. | Investigation, Ishvalan standing, sandstorm stealth |
| **IV-c. The Cold Store** | **Northern Wall** | 25–35 | The State's worst stones are kept asleep in the cold, and the cooling is failing. Halvard's name turns up. Shows **how much there is**. | Cold survival, the hardest compounds |
| **V. What the Ground Keeps** | **Corrupted Lands** | 30–45 | The Eclipse Citadel in the crimson phase: Sallow against Kade, and the endings. | Everything; Taboo choices |

### 3.3 Endings (a direction only)

Phase 10 (endings) isn't designed yet. These PROPOSAL directions are shaped by deeds, standing, licence path and Taboo marks, never by one last dialogue choice. **No ending promises or rules out going home.**
- **Expose:** the ledger goes public. The Bureau falls and the borrowing stops. Hard but honest years follow.
- **Sallow's way:** the debt is spread over a hundred valleys for a hundred years. The secret is kept.
- **Pay it yourself:** a Farborn with no Taboo marks carries the Citadel's oldest stone into the Gate and asks Truth the price, so no one else's land pays it. What Truth asks for, and what it gives back, is left open.
- **Take the power:** the Taboo route. Strong, feared, and the debt is yours.
- **(Failure) Kade wins:** the Foundry Yard and the Bureau's halls pay, along with everyone in them.

The **Legendary Alchemist** title stays earned: top Renown plus the main story's capstone.

---

## 4. Story cutscenes

**Owner:** "There should be a good amount (BUT NOT TOO MUCH) cutscenes throughout the story in REALLY IMPORTANT parts".

**The rule: if a moment could be played instead of watched, it gets no cutscene.** Conversations, choices, fights, stealth and travel are all played. Cutscenes are for the few moments the player should simply see. That's about 1–3 per act, each under 45 seconds except the endings. Every length is a PROPOSAL. A full shot list is written only when that act is built; the two in §1 are written already.

| Act | The moment | Why it earns a cutscene | Length (s) | View | Skippable after the first view | One-line shot summary |
|---|---|---|---|---|---|---|
| Prologue | **Pulled through** (joining the Tutorial) | The player's arrival in this world, and the first sight of the Gate | 25 | First person | Yes | A rainy window, the colour drains, the fall, the Gate as it stands in the Tutorial, and Truth's one line (§1.2). |
| Prologue | **The Gate opens** (the Tutorial's finale, exists) | Truth's three lines set up the whole story | 9 | First person | Yes | The door swings open on light while Truth speaks (exists; new lines only). |
| I | **Waking** | The first breath in a new world | 17 | First, then third person | Yes | Sky, the swift, the grey ring, look left, look right, out to the play camera (§1.4). |
| I | **The circle wakes** (beat 8, Halvard's vault opens) | The key reveal of Act I: a buried debt is real | 15 | Third person | Yes | As the vault opens, a vast old circle glows faintly through the rock floor and away under the ridge; grass on the slope outside goes grey. |
| II | **The night pour** (Furnace One, Act II midpoint) | The State makes Philosopher's Stones: the act's key reveal | 25 | Third person, from hiding | Yes | On a "banked" night, a crew in Bureau grey pours a dull red stone into a circle mould while C. Ashe ticks a ledger. |
| III | **Sallow at the hearing** (her first appearance) | The main antagonist arrives | 30 | Third person | Yes | The Licensing Office goes quiet as Sallow takes the stand, calm and exact, and looks straight at the player. |
| III | **The ledger's fate** (the act-ending choice) | Shows the consequence of a choice the player just made | 20 | Third person | Yes | Either the presses roll and newsboys shout the story through Central, or the ledger changes hands in a closed office. |
| IV-a | **Kade on the ash wastes** (his first appearance) | The second antagonist arrives | 25 | Third person | Yes | Out of the grey haze a lone figure walks unharmed through paying ground: another Farborn, older, who knows the player's name. |
| IV-b | **The healed field** | The story's one clear sign of hope | 20 | Third person | Yes | Elder Orun lifts a cloth from a patch of desert where green shoots grow, six hundred years after it paid. |
| IV-c | **The Cold Store fails** | The act's turn: the danger is real and close | 25 | Third person | Yes | Frost slides off a vault door, the stones inside warm to red, and grey spreads across the courtyard snow. |
| V | **The Citadel at crimson** (first arrival) | The last place, and the bird's last appearance | 30 | First, then third person | Yes | The Citadel under a red sky, the Gate's light over it, and the swift flying into the light without coming back. |
| Endings | **One per ending** (four, plus the failure) | The story's conclusion | 60–90 each | Third person | Yes | A short epilogue for each ending; none promises or rules out going home. |

**Shared rules (PROPOSAL):**
- **Once per profile.** Each cutscene plays once per save slot. If the same account has seen it on another slot, a "Hold to skip" prompt appears.
- **No new UI art:** plain screen fades and letterbox bars only.
- **Never mid-fight:** a cutscene waits until the player is out of combat.
- **Parties:** party members who are at the same point in the story and nearby watch it at the same time, each on their own screen. Members who aren't see the watcher's character stand still. The watcher can't be hurt or targeted while it plays, and the others get an existing toast: "*Name* is watching a scene." When it ends, everyone carries on together.
- **The play camera after:** any cutscene that ends in play hands back to the game's camera at the player's own settings, as the waking cutscene does (§1.4).

---

## 5. Side-quest integration

### 5.1 The rule: side content feeds the story, never blocks it

- **The main path only ever requires main quests.** A main beat's `Requires` names only the previous main beat.
- **Side content gives a shortcut, an ally, another route, or rewards, never a key.**
- **Done early counts.**
- **Level bands are soft.** Travel itself is the only hard gate.

### 5.2 How each kind connects

| Kind | Feeds the main story | Fed by the main story |
|---|---|---|
| **Regional side quests** (`foundry_ledger`, `chalk_foundry`) | Their evidence unlocks extra main-quest choices. Finishing `foundry_ledger` before Act II's depot mission is a shortcut: you already know the 14th's "banked" furnace was C. Ashe's. Lise's chalk and the Voided Ledger Line point at the stones' circles. | Main acts send players into a region, where its side quests are found by clue markers and townsfolk. |
| **Trainer quests** (`acq_*`) | Choosing a teacher is beat 7. Later acts give each trainer a role and a view of the debt (Lore Bible §8.1). | The trainers keep paying training. |
| **Clue quests** (`lm_ridge`, `lm_mine`, and each region's) | They **are** Chapter 1's beats 1 and 3. The townsperson's first answer is the cover story (Ned's field boundaries, Bess's flood), and the main story reveals the rest. | Main-quest evidence can speed up a clue quest. |
| **Minigames and puzzles** | Story set pieces (the mine, the depot's locks, the ledger's ciphers). | **Wrong-guess consequences: off in Chapter 1, on from Act II,** always told up front and never a dead end (Stakes 0 / 1 / 2 / 3 by act, wrong-guess spec). |
| **Stealth contracts** (stealth missions spec) | Some turn up evidence or contacts (a stolen freight waybill shortens Act III). | Main acts unlock each region's job board, and story missions use the same compounds (the mine camp, the rail depot, the records hall, the cold store, the containment camp). |
| **Nemesis rivals** (`specs/2026-10-25-nemesis-design.md`) | A rival can interrupt in main-story places, never as a required fight. | Rivals are born in contracts: first a rumour warning, then an ambush. |
| **Reputation in investigations** (`specs/2026-10-25-reputation-investigations-design.md`) | Witnesses answer by your standing and conduct; some lie, some refuse, and some ruthless people tell a ruthless player more. Every main-quest witness has at least two ways to the truth. | Main-quest choices move the standing later witnesses react to. |
| **Forgotten Sites** | Each holds a piece of history: one of Mezarath's circles, a boom-years record, a frozen stone. | Main acts point at them through rumours. |

### 5.3 Rewards (PROPOSAL)

| Content | Reward kind |
|---|---|
| Main beats | EXP and money, Renown at chapter ends, Codex entries, story contacts |
| Regional side quests | EXP, money, standing, sometimes a story shortcut |
| Trainer quests | The alchemy path, training, Mastery (as built) |
| Clue quests | Small EXP, evidence the story can use |
| Stealth contracts | Money by rating (Ghost / Quiet / Loud), standing, sometimes evidence |
| Forgotten Sites | Caches, EXP, Codex lore about Mezarath and the buried debts |

All payouts stay once only (exists: a quest leaves Active before anything is paid).

---

## 6. How it uses what exists

### 6.1 Reused as it is

| System | How the main story uses it |
|---|---|
| **Quest engine** (`QuestService`, `Rensei.Quests`) | Each beat is an ordinary staged quest. `Requires` chains the beats, `Outcomes` carry the choices, and `Rewards.Deeds` records them. |
| **Quest revisions** (`Revision` / `Prepended`) | Old saves move forward safely when a beat changes later. |
| **`StoryLogic` conditions** | Dialogue reacts to evidence, deductions, flags, standing, conduct, trust, Renown, Heat, Wanted and the saved path. |
| **Investigations** (`InvestigationService`, `Rensei.Investigation`, `Rensei.Evidence`) | Clue markers start quests; the Case Board checks deductions. |
| **Townsfolk** (`TownsfolkService`, `Rensei.Townsfolk`) | Clue lines advance quests, rumour lines teach rumours, schedules teach the clock. Ned's and Bess's existing lines stay as the cover story. |
| **Dialogue** (`DialogueService`, `Rensei.Dialogues`) | Named story characters use the dialogue box, with conditions and actions. |
| **The two intro slots** | Ye's `IntroCutscene` (the waking cutscene); the Tutorial's `IntroCutscene` module and `TutorialController` messages (the opening cutscene). |
| **Brannoc's notice** (`brannoc_moved`) | Metal's Lindenmoor start. |
| **Morality, Heat, rumours, witnesses, Identities, travel, parties, puzzles, minigames, Forgotten Sites, Field Notes** | Each is taught by its beat and used as built, except Identities' NPC records (§2.5). |

### 6.2 New for the main story

- **Cutscenes:** the Tutorial opening (§1.2), the waking cutscene with its third-person pull-out (§1.4), and the story cutscenes in §4. Shared assets: the swift and the grey patch. The Gate and Truth reuse the Tutorial's existing set and figure. Each section lists its new animation slots and sounds.
- **About 14 short quests** for Chapter 1, with their dialogue and stage text.
- **New Field Notes:** "Open Ground", "Word Travels", "Choosing a Path" and "Unseen", plus the one-note-per-beat rule (a small queue on `Flow.Hints`).
- **New flags:** `Flow.TutorialIntroSeen`; account-level "seen" markers for the skip prompt.
- **New story characters** (Lore Bible §8.2): Registrar Lucan Prewitt, Inspector Aurel Denby and Constable Mabry Selden for Chapter 1; later Wenna Fane, Odette Sallow, Sorrel Kade, Elder Saffa Orun and Peleas Amund. Ned and Bess get story lines, and Bess needs a **dialogue tree** for beat 11 (townsfolk speak in bubbles only).
- **New data:**
  - the notice inspect point and its evidence;
  - the first deduction, "What the Marker Records", with three slots: where it points (`lm_shaft_ore`), what the figures are (the notice) and when (`lm_ridge_survey`). Its conclusion: "Not a boundary stone. It marks something the Bureau buried under the ridge, and it's due this year.";
  - the work-order evidence (beat 9);
  - Codex entries ("Farborn", "Equivalent Exchange", "Buried Debts", "The Bird With No Name");
  - deeds for the three beat 11 choices and for trespassing on a sealed State site;
  - a Militia fine desk in Lindenmoor (fines are taken only by Foreman Brask today, for State Heat);
  - the "travel alone" flag.
- **Identities NPC records** (§2.5).
- **A guaranteed rumour** about the beat 4 fight, so beat 5 always has something to hear.
- **The survey camp** at the mine (beat 9). It later becomes Lindenmoor's first stealth compound.

### 6.3 To check before building

- **The Tutorial's Alchemy beat for a player with no path.** The creator no longer gives a path. In the lore, Truth lets the newcomer's hands try alchemy; the build must decide what the beat actually casts.
- **The Tutorial's step data and client** (`TutorialSteps` and the Tutorial client) are in Studio, not in this repo. Read them before wiring the opening cutscene and the new finale lines.

---

## 7. Open questions for the owner

### 7.1 Closed

| Question | Answer |
|---|---|
| Who is the player? | Transported from another world: a **Farborn**. |
| Where do trainer questlines start? | In Lindenmoor for now. Metal starts at Brannoc's notice ("pretty good"). |
| Must Chapter 1 need a finished path? | No; starting one is enough. |
| The story's spine | A full original lore, in the series' theme and words (Lore Bible). |
| Wrong-guess consequences in Chapter 1? | Off; on from Act II. |
| Solo players and beats 12–13 | Optional; beat 12 can be done solo. |
| Truth's finale lines | "Use the proposed ones." |
| Series terms and shipped text | "Keep the FMA terms." The nation names, "Xerxian" and the creator text stay. |
| A better word than "strays" | **Farborn**. |
| Can a Farborn go home? | It stays a mystery (option C): hints only, never confirmed, and no ending promises or denies it. |
| More cutscenes | A small set, at really important moments only (§4). |
| Human transmutation's price | "A limb, then automail." |
| Truth's look | "He should look like the one we have in tutorial." Truth always appears in its own form, as built in the Tutorial place. |
| The Tutorial's Gate set | "Keep the existing set." The lore and the cutscenes describe the Gate as it stands in the Tutorial. |
| The names Mezarath and Farborn | "Keep both." |

### 7.2 New

None. Every question so far is answered.

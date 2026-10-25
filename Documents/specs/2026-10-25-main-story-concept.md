# Main story: concept (DRAFT for the owner)

**Status:** **DRAFT**, 2026-10-25. Written for the owner to read, change and approve. Nothing here is built, and nothing here is canon until the owner says so.

**Owner's request (their exact words):** "I want the game to Go like this: Character Creation > Tutorial > Main Game Cutscene of the character waking up in 1st person seeing a bird fly across the sky above him/her, then they get up and look left and right > Lore + Main Quest. I want the first main quests to introduce all the in-depth features in the game 1 by 1 and in a simple way for players to understand."

**Rules this draft follows:**
- **Every new name, line, number and plot point is a PROPOSAL.** The owner's own story notes (the story conversation linked in `README.md`) win wherever they disagree.
- **Original story.** The world's nations are named in the style of Fullmetal Alchemist, but every new character, plot and name here is original. It doesn't borrow that series' plots (no homunculi, no stones made from people, no country-wide circle, no war story for Ishval), or any other work's.
- **What exists is named as existing; what's new is marked new.** Section 5 lists both.

---

## 1. The start flow

### 1.1 Step by step

| Step | Place | Status | What happens |
|---|---|---|---|
| 1. **Character creation** | Character Customization (the menu place) | **Exists** | Main menu, save slots, nation, name, look, clan roll, starting weapon. Saved once. |
| 2. **Tutorial** | Tutorial place | **Exists** | Drillmaster Vask's beats: Footwork, Report In, The Wall (climbing), Strikes, Break a Guard, Defend (block and parry), Alchemy, The Bout (knock and grip), then **the Gate** (Truth's lines). It ends with `FinishTutorial`, which saves `TutorialDone` and sends the player to Ye. |
| 3. **The waking cutscene** | Ye (Lindenmoor) | **New** (replaces the placeholder) | Plays once, on the first arrival (`FlowService` already plays the intro once and saves `Flow.IntroSeen`). §1.2. |
| 4. **Lore** | Ye | **New** | Short and in-world. §1.4. |
| 5. **Main quest** | Ye, then the regions | **New** | Chapter 1, "The Arrow and the Seal" (PROPOSAL). §2. |

**The hand-off:** nothing in steps 1–2 changes. The menu routes a new player to the Tutorial, and the Tutorial routes them to Ye (`Start Flow and Character Creation.md`). In Ye, `FlowService` already calls `IntroCutscene.Play` once for a profile that hasn't seen it. The waking cutscene **takes that slot**. A returning player (`IntroSeen` already true) never sees it again.

**Why it reads well:** the Tutorial ends on the Gate, a strange place with a strange voice. The next thing the player sees is open sky. The cut from the Gate to the sky feels like waking from a dream. Whether it *was* a dream is the owner's canon (the Gate and Truth are the owner's), so this draft leaves it open.

### 1.2 Where they wake

**On the slope of the Ridge Marker's knoll** (PROPOSAL), in Lindenmoor's North Meadows, just above the training field.

- **Why there:** it's real ground in Ye today. The Ridge Marker (a standing stone and cairn on a knoll, with a surveyor's arrow someone keeps scrubbed clean) is already a clue point with its own quest, `lm_ridge`. Waking beside it puts the first mystery literally next to the player's head.
- **What can be seen from there** (the Lindenmoor expansion layout): the village's red tile roofs and Mill Creek one way; the training field, its five trainers and the north road running up to the gap the other way; the Cypress Ridge rim behind.
- **New:** a one-time **wake point** marker on the knoll. The first arrival spawns there; every later spawn uses the village square as today (`LindenmoorSpawn`).
- **Time of day:** the clock is the same in every server (`WorldClock`), so the scene can't choose its hour. PROPOSAL: the cutscene sets its own sky light for its 15 seconds, then hands back to the real clock.

### 1.3 The waking cutscene, shot by shot

About 15 seconds (PROPOSAL). First person all the way; no HUD; the player can't move until the last shot.

| # | Shot | What we see and hear |
|---|---|---|
| 1 | **Black, then eyes open** | A slow fade in, with a blink or two (the screen dips dark at the top and bottom). Wind in grass; a far-off train whistle. |
| 2 | **Lying on their back: sky** | The camera looks straight up from the ground. Tall grass and hay stalks frame the edges. Clouds drift. The light is soft. |
| 3 | **A bird crosses overhead** | One dark bird (PROPOSAL: a swift) crosses the sky from one side of the frame to the other, the camera's eyes following it slightly. Its call fades as it goes. |
| 4 | **Sitting up** | The view rises and tips forward as the character sits up: the sky drops away and the meadow and the standing stone come into view. A breath, a rustle of clothes. |
| 5 | **Look left** | The head turns left and holds: Lindenmoor below, chimney smoke, the creek bridge, a train standing at the station. |
| 6 | **Look right** | The head turns right and holds: the training field, small figures at practice, the north road climbing to the gap. |
| 7 | **Back to centre, control returns** | The head comes back to centre on the standing stone and its arrow. The HUD fades in. A groundskeeper is already walking up the slope (§2, beat 1). |

- **Built with:** the existing intro slot (`Modules.UI.IntroCutscene`), a scripted camera, and the player's own character as the first-person body (their sleeves and hands in shot 4, so their chosen look shows).
- **New assets:** the bird (a small animated model), the shots' camera path, and a few sounds. The blink uses plain screen fades, no new UI art.

### 1.4 The lore, short and in-world

No lore dump and no long scroll. Three small touches, all in the world:

1. **A title card over shot 6** (PROPOSAL lines, three short lines, white text on the image, then gone):
   > *Every transmutation leaves something behind.*
   > *In the State's foundries, they make a great deal of it.*
   > *Where it goes is no one's business. That is the law.*
2. **The groundskeeper's first lines** (beat 1): who he is, where you are, and that the arrow on the stone is "an old Survey mark someone keeps clean".
3. **A notice on the village notice board** (an inspect point, beat 6): a State notice that the old workings on the ridge are sealed by order of the Bureau of Survey and Assay (PROPOSAL name). It names the State Authority and its licence in one paragraph.

Everything else is learned by playing: the Codex fills as areas are found (this exists), and townsfolk mention the world in their job lines and rumours.

---

## 2. The opening chapter: one feature at a time

**Chapter 1, "The Arrow and the Seal"** (PROPOSAL), Lindenmoor, levels 1–6 (the world spec's band).

**The story in one paragraph (PROPOSAL):** you wake beside a standing stone whose surveyor's arrow someone keeps clean. The arrow points at old mine workings the State sealed years ago. Following it, you learn that the State's alchemy leaves a waste behind, called **dross** by the people who handle it (PROPOSAL), and that the State has been burying it under Lindenmoor. When a Bureau inspector arrives to seal the valley's secret again, you must decide who gets the truth, then take the train to the Foundry Yard, where the dross comes from.

### 2.1 The beats

Each beat is one short main quest. Each teaches **one** feature. The table's last column says what already exists and is reused.

| # | Quest beat (PROPOSAL names) | The one feature it teaches | Where | Reuses |
|---|---|---|---|---|
| 0 | **Waking** | (the cutscene) | Ridge Marker knoll | The intro cutscene slot in `FlowService` |
| 1 | **Someone Keeps It Clean.** Ned Harrow, the groundskeeper, finds you by the stone. Examine the arrow; he tells you what he knows. | **Townsfolk and talking:** the Talk prompt, speech bubbles, people with jobs | Ridge Marker, training field | `lm_ridge` (examine the marker, ask the groundskeeper); Ned Harrow (Lindenmoor roster); `TownsfolkService` bubbles |
| 2 | **The Quick Way Down.** Ned points you at the shortcut the village children use: over the practice yard's walls, along the gorge ledge, across the pool. | **Movement:** climb, ledges, wall-run, slide, swim | Practice yard, Mill Creek gorge, Gorge Pool / Mill Pond, the village square | The LedgeCourse and its world challenge; the `RenseiLedge` gorge walks; `SwimService` pools; the Lindenmoor Run challenge (optional repeat) |
| 3 | **Mine Hours.** Ned says to ask Bess Kettering, the mine hand, about the old surveyors. She's at the mine head by day and the West Lookout after dark. | **The day/night clock:** people keep hours; lamps light at dusk; night is darker | Mine approach, West Lookout | `lm_mine` (its text already teaches Bess's hours); `WorldClock` |
| 4 | **Cart Trouble.** Bess won't talk until the ore carts stop getting robbed. Clear the camp in the woods. | **Basic combat** in the open world (the Tutorial taught the moves; this is the first real fight) | Bramble Hollow and Bramble Woods | The Grunt spawns there; `CombatDirector`; a `Defeat` objective |
| 5 | **Word Gets Around.** Back in the square, people are already telling your fight, and one mentions lights in the old adit at night. | **Rumours:** what you do travels, and people pass on what they hear | Village square | `RumourService` (the townsfolk's rumour line); `WitnessService` |
| 6 | **What the Arrows Mark.** Put the stone, the shaft and the State notice together. | **Investigation:** clues, evidence and the **Case Board** | Notice board in the square, then the Journal (J) | `InvestigationService`; the evidence from beats 1 and 3 (`lm_ridge_survey`, `lm_shaft_ore`); a new first deduction |
| 7 | **Five Teachers.** Bess says the adit isn't for someone with only their fists. Meet the five alchemists at the training field and choose one. | **Alchemy and choosing a path** | Training field (the five trainer spots) | Calda, Veyra, Holt, Ansel and Brannoc's dialogues; `acq_flame`, `acq_ice`, `acq_earth`, `acq_wind`, `acq_metal` |
| 8 | **Number Four.** Go into Halvard's Adit. | **Puzzles and minigames:** mechanisms, the winch board, the sluices, the assay ring | Halvard's Adit | `forgotten_halvard` (whole quest, unchanged); its Pressure Board and Array Restoration; the `adit_truth` deduction ("No. 4 is not ore") |
| 9 | **The Inspector.** A Bureau inspector and State guards set up camp at the mine approach to seal it again. Get close enough to see what they carry out, without being seen. | **Stealth and detection:** crouch, shadow, quiet floors, the stealth sigil, guards who notice | Mine approach (a survey camp) | `PerceptionService`, `LightService`, `NoiseService`, `StealthUI`; night from the clock |
| 10 | **The Law in Lindenmoor.** The village constable wants a word with anyone seen near the camp. | **Heat, Wanted and the law:** crimes, the Wanted badge, decay, fines, the station's papers check | Village square, the station gate | `HeatService`, `Rensei.Heat` (decay, fines), the station gate's Wanted rules |
| 11 | **Whose Truth.** Bess admits she keeps the arrows clean. Decide who gets what you found: the inspector, Bess, or the whole square. | **Morality, reputation and factions:** deeds, standing, conduct words | Square, mine approach | Quest `Outcomes` (like Lise's choice); `MoralityService`, `Rensei.Deeds`, `Rensei.Factions` |
| 12 | **Subject Unknown.** At the station, other travellers are strangers. Introduce yourself to one. | **Player Identities** | Lindenmoor Station | `IdentityService`; the "Introduce yourself" prompt; the Journal's Identities tab |
| 13 | **Company for the Road.** Find someone to travel with. | **Parties** | Station or square | `PartyService` and the Party menu |
| 14 | **The Night Train.** Buy a ticket, pass the gate, ride to the Foundry Yard (or walk the North Road). | **Travel:** trains and roads | Lindenmoor Station; the North Road | `StationService`, `RoadService`, `TravelService`; the `Arrive` objective |

**Chapter reward (PROPOSAL):** a codex entry ("Dross"), a Renown bump, and a contact in the Foundry Yard that depends on the beat 11 choice.

### 2.2 Why this order

- **Talk before anything (1).** It's the safest thing in the game, and it gives the player a person and a question before a single system is explained.
- **Movement next (2).** The Tutorial taught the basics. The world's advanced moves (ledges, wall-runs, the pools) are best learned on a route with no enemies, where the only danger is running out of breath.
- **The clock before people get hard to find (3).** From here on, quest givers keep hours. Bess is the first person who isn't always where you left her.
- **Combat once the player can move and find people (4).** The Tutorial already taught the moves, so this is a short, real fight, not a lesson. It also gives the player their first deed worth talking about.
- **Rumours right after that deed (5).** The player hears their own fight retold. Nothing explains the rumour system better.
- **Investigation once the player holds clues (6).** Beats 1 and 3 already gave two pieces of evidence. The Case Board only connects what the player has found, so the first deduction is easy.
- **Alchemy before the Adit (7).** The Adit's mechanisms react to alchemy, so the player should have a teacher first. Every acquisition questline also repeats investigation and minigames, so it reinforces beat 6.
- **Puzzles and minigames in the chapter's set piece (8).** The Adit uses everything learned so far, and adds mechanisms and minigames as the one new thing. Every step has a route without alchemy, so an unfinished path never blocks it.
- **Stealth once there's something to hide (9).** After the Adit the player knows a State secret, and the State arrives. Being seen now matters.
- **Heat right after stealth (10).** If the player was seen, Heat is the consequence; if not, the constable explains what would have happened. The lesson lands either way.
- **Morality as the chapter's choice (11).** By now the player knows the factions involved (the Authority, the Circle, the village), so the choice has weight.
- **Identities, then parties, then travel (12–14).** Meet a stranger, team up, leave together. Parties buy each other tickets and land on the same server, so they come just before the train.

### 2.3 Rules for the opening chapter

- **One new thing per beat.** Each beat shows a **Field Note** (the existing one-time hint cards) for its feature, and only that one. A player who already met a feature in a side quest has already seen its note, so it isn't shown twice.
- **Done early counts.** If a player already finished `lm_ridge`, `lm_mine`, `forgotten_halvard` or an acquisition, the beat that reuses it ticks at once (the quest engine's catch-up, which exists).
- **Solo players are never stuck.** Beats 12 and 13 need another player, so their objectives are **optional**, with a "travel alone" choice.
- **Choosing a path, not finishing it.** Beat 7 completes when the player **starts** a trainer's questline. Finishing it is strongly suggested but not required (see open question 3).
- **Short.** PROPOSAL target: the whole chapter in 60–90 minutes, each beat 3–8 minutes, except the Adit.

---

## 3. The main story arc across the seven regions (PROPOSAL)

### 3.1 The premise

- **Dross (PROPOSAL term):** every transmutation leaves a residue. In small work it's harmless ash. In the State's great foundries, where alchemy runs at industrial scale, it comes out by the ton, and it doesn't stay still. Buried, it creeps into rock and water, and near it alchemy misbehaves.
- **The cover-up:** for a generation the State Authority's **Bureau of Survey and Assay** (PROPOSAL) has hidden it: in sealed mines (Halvard's shaft No. 4), on night freight trains, in frozen vaults, and finally across the borderlands, in the place now called the Corrupted Lands.
- **The question the story asks:** the foundries feed the country. Stopping them hurts ordinary people; hiding the dross poisons them. There's no clean answer, which fits the game's grey-choice rule.
- **The antagonist (PROPOSAL):** **Assayer-General Edda Vorne**, head of the Bureau. Not a monster: she believes the dross can be contained and that the truth would cause a panic. The **Unlicensed Circle** is no simple ally either: some of its members want to *use* the dross (the Taboo layer).

### 3.2 The acts

Level bands are from the world spec. Act IV's three regions can be played in any order.

| Act | Region | Levels | Its role in the story | Systems it puts in front |
|---|---|---|---|---|
| **Prologue** | Tutorial | — | The Gate. A dream, or not (owner's canon). | Combat basics |
| **I. The Arrow and the Seal** | **Lindenmoor** | 1–6 | The starter village. The first buried dross; the first inspector; the first choice. | Every feature, one at a time (§2) |
| **II. Night Freight** | **Foundry Yard** | 5–12 | Where the dross is made. Altered shift ledgers hide the night shifts that load sealed wagons. The first big stealth infiltration (the rail depot). The licence choice opens: the State's exam or the Circle's initiation. | Stealth missions; the licence path; Foundry standing |
| **III. The Archive** | **Central City** | hub | The capital and the Bureau's records. Politics, hearings, people who know your name by now. A story infiltration of the records hall. The act ends with a big choice: make the proof public, or trade it. | Renown, Identities, Heat under State law |
| **IV-a. The Border Trade** | **Aerugo Borderlands** | 12–22 | Smugglers carry dross over the border for coin, and the vineyards are dying. Shows **where it goes**. | Contracts, the road route, rumours across borders |
| **IV-b. The Old Knowledge** | **Ishval** | 18–30 | The Ishvalan Community keep records of an older blight, and a way to settle dross into stone **without alchemy**. Shows **how to stop it** (it matters because alchemy misbehaves near dross). | Investigation, Ishvalan standing, sandstorm stealth |
| **IV-c. The Cold Store** | **Northern Wall** | 25–35 | The Bureau keeps its worst dross frozen in a fortress vault, and the vault is failing. Shows **how much there is**. | Survival in the cold, the hardest compounds |
| **V. What the Ground Keeps** | **Corrupted Lands** | 30–45 | The great dumping ground. The confrontation with Vorne and with the Circle's hard-liners. The endings. | Everything; Taboo choices |

### 3.3 Endings (a direction only)

The master plan's Phase 10 (endings) isn't designed yet. PROPOSAL directions, shaped by the player's deeds, standing and licence path, never by one last dialogue choice:
- **Expose:** the truth goes public. The Bureau falls; the foundries slow; hard times, but honest ones.
- **Contain:** the player helps the State seal it properly and keeps the secret. Order holds, at a price.
- **Harness:** the player takes the dross's power (a Taboo path). Strong, feared, and alone.

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
| **Regional side quests** (e.g. `foundry_ledger`, `chalk_foundry`) | Their evidence opens extra main-quest lines (`Show = "Locked"` choices that become available). Finishing `foundry_ledger` before Act II's depot mission gives a shortcut: you already know which night shift loads the wagons. | Main acts send players into a region, where its side quests are found by clue markers and townsfolk. |
| **Trainer quests** (`acq_*`) | Choosing a teacher is a main beat (beat 7). Later acts give each trainer a role: an ally with their own view of the dross (PROPOSAL). Path-specific lines use the existing `SavedAffinity` condition. | The main story points the player at the trainers; mastery lessons and exercises keep paying training. |
| **Clue quests** (`lm_ridge`, `lm_mine`, and each region's) | They **are** Chapter 1's beats 1 and 3. Every region keeps the pattern: inspect a clue, ask a townsperson. | Main-quest evidence can make a clue quest's answer quicker. |
| **Minigames and puzzles** | Story set pieces (the Adit, the depot's locks, the archive's ciphers). | **Consequences for wrong guesses** (owner's plan, Backlog item 3): PROPOSAL, told to the player up front: a wrong guess raises a guard's suspicion, floods a gallery (time lost), breaks a tool (a small cost), or makes a witness clam up for a while. **Never a dead end** (the existing rule that failures are recoverable). **Off in Chapter 1** while players learn, then **on from Act II**. |
| **Stealth contracts** (the stealth missions spec) | Some contracts turn up evidence or contacts the main story can use (a stolen waybill shortens Act III). | Main acts unlock each region's job board and fixer, and the story missions run inside the same compounds. |
| **Nemesis rivals** (concept not written yet) | A rival's grudge can follow the player into main-story places as an interruption, never as a required fight. | Rivals are born in contracts (owner). The owner's one decision so far stands: first a **rumour warning**, then an **ambush** if the player ignores it. |
| **Reputation in investigations** (owner's plan, Backlog item 5) | PROPOSAL: witnesses answer by your standing, their trust in you and your conduct. Some **lie** (and are caught out by presenting evidence, which already works), some **refuse**, and some ruthless people **spill secrets more easily** to a ruthless player. **Every main-quest witness has at least two ways to the truth** (evidence, standing, a bribe or a threat), so reputation changes the route, never whether you can finish. | Main-quest choices move the standing that later witnesses react to. |

### 4.3 Rewards (PROPOSAL)

| Content | Reward kind |
|---|---|
| Main beats | EXP and money, Renown at chapter ends, codex entries, story contacts |
| Regional side quests | EXP, money, standing with that region's people, sometimes a story shortcut |
| Trainer quests | The alchemy path, training, Mastery (as built) |
| Clue quests | Small EXP, evidence the story can use |
| Stealth contracts | Money by rating (Ghost / Quiet / Loud), faction standing, sometimes evidence |
| Forgotten Sites | Caches, EXP, codex lore about the dross's history |

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
| **Townsfolk** (`TownsfolkService`, `Rensei.Townsfolk`) | Clue lines advance quests; rumour lines teach rumours; schedules teach the clock. |
| **Dialogue** (`DialogueService`, `Rensei.Dialogues`) | Named story characters (the trainers today) use the dialogue box, with conditions and actions (`StartQuest`, `SetFlag`, `GiveEvidence`, `Deed`, `StartMinigame`). |
| **Morality, Heat, rumours, witnesses, Identities, travel, parties, puzzles, minigames, Forgotten Sites, Field Notes** | Each is taught by its beat in §2 and used as built. |

### 5.2 New for the main story

- **The waking cutscene** (replaces `IntroCutscene.Play`), the bird, and the one-time **wake point**.
- **About 14 new short quests** for Chapter 1 (the beats), plus their dialogue and Field Note text.
- **New story characters** (PROPOSAL): the Bureau inspector, the village constable, and later Assayer-General Edda Vorne. Bess Kettering and Ned Harrow, who exist as townsfolk, get a few story lines (townsfolk speak in bubbles only, so a choice scene such as beat 11 needs a dialogue tree for Bess).
- **New data:** the first deduction (beat 6), the State notice inspect point, a "dross" codex entry, deeds for the chapter's choice and for trespassing on a sealed State site, a fine desk in Lindenmoor (fines are paid at Foreman Brask today).
- **A guaranteed rumour** about the player's beat 4 fight, so beat 5 always has something to hear.
- **The survey camp** at the mine approach (beat 9). Later it becomes Lindenmoor's first stealth compound (stealth missions spec §2.2).
- **To check before building:** what the Tutorial's Alchemy beat does for a new player, who has no path until a trainer gives one (the creator's Alchemy step was removed).

---

## 6. Open questions for the owner

1. **Who is the player when they wake?** Options: a newcomer who arrived the night before (they slept in the meadow after the night train), or someone who has lost their memory.
   **Recommended:** a newcomer. Memory loss is a common trope, and the investigation theme works better if the player chooses what to dig into.
2. **The acquisition sites and the far regions.** The world spec moves each trainer's trial rooms to a far region (for example Ice and Wind to the Northern Wall, levels 25–35). A level-1 player who picks Ice in Chapter 1 couldn't finish it.
   **Recommended:** keep each acquisition in Lindenmoor (Metal in the Foundry Yard, as built), and use the far regions' trial rooms for later mastery trials.
3. **Must Chapter 1 require a finished alchemy path?**
   **Recommended:** no. Beat 7 asks the player to choose a teacher (start the questline). The Adit works without alchemy, and the trainers push the player to finish.
4. **Is "dross" the story's spine?** It's a placeholder built from clues already in the game (the sealed Adit, "No. 4 is not ore", the boarded shaft, the altered ledgers).
   **Recommended:** use it as the working spine until your own lore replaces it; it's easy to rename.
5. **Wrong-guess consequences in Chapter 1?**
   **Recommended:** off in Chapter 1 while players learn, on from Act II, always told up front and never a dead end.
6. **Solo players and beats 12–13 (Identities and parties).**
   **Recommended:** keep them optional, with a "travel alone" choice, so a player on an empty server can always finish the chapter.

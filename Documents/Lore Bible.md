# Rensei Lore Bible (DRAFT for the owner)

**Status:** **DRAFT**, 2026-10-25. Written for the owner to read, change and approve. Nothing here is canon until the owner says so.

**Owner's request (their words, 2026-10-25):** "Nah let's create a full lore for the game that's original, immersive, and still follows the FMA theme." Also: "The player is someone who was transported to another world (the alchemy world)."

**How to read this file:**
- **PROPOSAL** marks every invented name or fact. Where a whole table or list is new, its heading says so.
- **(exists)** marks names, places and facts already in the game's data, quests, dialogue or specs. This file builds around them and never renames them.
- **The owner's own story notes** are a web link in `README.md` (a chatgpt.com conversation). I couldn't read it. Wherever it disagrees with this file, the owner's notes win.
- **The Tutorial's Gate and Truth lines** live in the Tutorial place in Studio (`TutorialSteps` and the Tutorial client), which aren't mirrored in this repo. Only one Truth line could be read: the Bout's *"Again. And this time, take hold of it."* (exists, in `TutorialController`). §6.2 proposes the Gate's finale lines; if the owner has already written them, theirs win and §6.2 bends to fit.
- **The rule this lore follows:** the *theme* is Fullmetal Alchemist (alchemy with a cost and a law, a State that licenses alchemists, a Truth behind a Gate, nations at uneasy peace, industry, moral grey). The *content* is original. §9.2 lists the series' terms we don't use.

---

## 1. The world in one page

**Nothing is made. Everything is moved.** That is the first thing every alchemist learns. A working takes weight from one place and sets it down in another, and the price is paid there and then, out of the alchemist's own strain and the stuff at hand. The rule has a name: **the Tally** (PROPOSAL). Behind every circle stands **the Gate** (exists), where the Tally is kept, and behind the Gate sits **Truth** (exists), which keeps the count.

There is one way to cheat the Tally. A working can be done **on debt**: taken now, paid later, somewhere else. Six hundred years ago the old Xerxian kingdom (Xerxian: exists) invented the trick and built **sinks** (PROPOSAL), arrays cut deep into bedrock that hold a debt until it falls due. When those debts were called, the eastern plains paid. They are the desert of Ishval now (exists, own history).

**Amestris** (exists) is the State. Its **State Authority** (exists) licenses every alchemist. The Licence was written to stop debtwork for good. Then, in the **Bright Years** (PROPOSAL), the State's foundries ran hotter and cheaper than coal could explain, the railways reached every province, and nobody asked why. The **Bureau of Survey and Assay** (PROPOSAL), a quiet office of the Authority, had found the old Xerxian sinks and started borrowing again.

Thirty-one years ago the biggest debt was called. Noon went dark over a whole province (**the Eclipse**, PROPOSAL event; the Eclipse cycle and the Eclipse Citadel exist in the world spec). The ground paid: soil, water, timber, people. On the State's maps it's **the Corrupted Lands** (exists). The people who live near it call it **the Paid Lands** (PROPOSAL). The State calls it a blight and blames Drachman sabotage.

Since then the Bureau has kept the country running by moving its debts around: sinking them in old mines, carrying them on night freight, freezing them in fortress vaults, slipping them over the border. It works until a sink falls due. And this year, a lot of them are.

**Every door swings both ways** (PROPOSAL, Truth's rule). When a debt is called, the Gate opens over the owed ground, and things fall through from the other side: seeds, coins with strange faces, a bird nobody can name. Sometimes a person. The people here call them **strays** (PROPOSAL). Strays used to be rare. This year they come down by the dozen, and **the player is one of them**: someone from another world who fell through the night the ground under Lindenmoor (exists) began to pay.

A stray owes this world nothing. That is rare, useful, and it doesn't last if you're careless. The game asks what you will do with it, and who you will let pay.

---

## 2. Alchemy

### 2.1 The law: the Tally (PROPOSAL)

> *Nothing is made. Everything is moved. Weight for weight, kind for kind, and the Tally is kept.*

Every apprentice learns it as three clauses:

| Clause | What it means | How the game already shows it |
|---|---|---|
| **Weight** | A working can't make more than it takes. A stone wall needs stone. | Earth takes its material and colour from the ground under it (exists: Earth kit, `EarthElement`). |
| **Kind** | Stuff can only be moved into what its kind allows. Fire needs something to burn; steel needs metal. Each person's hands answer to one **medium** (§2.3). | One path per character (exists: `Identity.Affinity`). |
| **Keeping** | The price is paid **now**, at the working, out of the materials and the alchemist's own **strain**. Anything paid later is debt, and debt is forbidden (§2.5). | The meter (exists): it fills only while fighting and every circle drinks from it. In-world, strain is what you pay with, and a resting body has nothing to spend. Vask says it (exists): "Nobody charges up in a quiet corner." |

The game's **Price** rule (exists in the morality spec: every reward shows its price before you accept) is the Tally in miniature. Player-facing text calls it **the price**, never by the series' name for its law.

### 2.2 The three heats (PROPOSAL)

Alchemists talk about a working the way a foundry talks about a pour:

1. **Assay:** know the thing. What it is, how much of it there is, what holds it together.
2. **Melt:** unmake it. The clap and the circle open it. (Every working melts something, even ice.)
3. **Cast:** set it in its new shape.

This matches the cast as built (exists, `ALCHEMY_SYSTEM.md`): the clap and the circle (assay and melt), the hold, the release (cast). A cast interrupted between melt and cast is wasted strain, which is why a stunned cast is lost and never refunded (exists).

### 2.3 Media: the five paths

A person's hands **take to a medium** (exists: Vask's line, "if your hands have taken to a medium"). There are five: **Flame, Ice, Earth, Wind and Metal** (exists). The Tally writes a person's hands once (PROPOSAL lore for the existing one-path rule): you get one medium for life.

**How it's taught (PROPOSAL lore, built on the existing questlines).** The Licence's oldest teaching rule is **"read before you work"** (PROPOSAL). No licensed teacher lets a student touch a circle until the student can explain a failure. So every questline is the same shape (exists): investigate a failure, rebuild what failed, face whoever caused it, pass the teacher's examination, and be recognised. Recognition is the moment the medium sets.

| Medium | Teacher (exists) | What the teacher says it's really about (from their existing lines) | The failure you read (exists) |
|---|---|---|---|
| **Flame** | **Calda** | Control. "Fire is a decision, not a feeling." | The burned laboratory in Bramble Woods: Corin Vale's fire. |
| **Ice** | **Veyra** | Stillness. "Not the absence of motion. The absence of waste." | The frozen research station behind the Cypress ridge: Maren Ostrova's station. |
| **Earth** | **Holt** | Foundations. Understand it before you change it. | The cracked footbridge on the mine plateau: a pier rebuilt by alchemy for speed and never checked. |
| **Wind** | **Ansel** | Seeing the invisible by what it moved. | The silent observatory on the Cypress ridge rim: shutters wired shut for an experiment, over Siv's objection. |
| **Metal** | **Brannoc** | Precision. No waste. | The silent forge in the Foundry Yard's great hall: a brittle shaft and a hasty repair. |

**The Licence** (exists: the State Authority's alchemy licence). PROPOSAL detail: a licensed alchemist carries a **Tallybook**, a brass-bound book that records every working above a set weight, and the State audits it. Casting without a licence in front of the Authority is an offence (exists: the `unlicensed_cast` deed). Lindenmoor's training field is a **field school** (PROPOSAL): a place licensed teachers may take a student before the licence exam.

**Other peoples' ways** (PROPOSAL):
- **Xing:** **forepaying.** Xingnese alchemists pay *before* they work, with fasting, craft-offerings and long preparation. Slow, strong and clean, the opposite of debt. (This replaces the creator blurb's borrowed term; see §4.2.)
- **Ishval:** **settling.** Not alchemy at all: the slow hand-work of mending paid ground, with water-craft, planting and stone-laying rites, over a generation. Ishvalans distrust alchemy (exists, in the creator blurb) for their own reason: their land paid for someone else's.
- **Aerugo:** alchemy is a **guild trade**, licensed by the Aerugonian Guild (exists as a community), not the state.
- **Drachma:** few alchemists, and a hard practical faith in cold. Drachmans say that **cold keeps a debt asleep** (PROPOSAL), which turns out to be true (§4, the Northern Wall).

### 2.4 Mastery and the Gate (exists, given meaning)

- **Stages** (exists): each stage of Mastery holds 20 Mastery Points. To carry more, an alchemist must face the Gate (the Truth/Gate trial, exists in progression; the trial itself isn't built).
- **What the trial is** (PROPOSAL lore): Truth weighs whether the alchemist's hands can carry more of the Tally. Teachers can sharpen a student up to the Gate and no further (exists: every trainer's "gate" line).
- **Some don't come back** (exists: a death at the Gate is permanent since 2026-10-19). In-world: the Gate keeps those who asked to carry more than they could.

### 2.5 The forbidden arts (PROPOSAL names; the Taboo layer exists)

The Licence calls them **the Unpaid Arts**. Each maps onto a Taboo mark the morality spec already lists (exists). Each is told before it happens and can't be undone (exists rule).

| Art (PROPOSAL) | What it is | The existing Taboo mark it names | Truth's price |
|---|---|---|---|
| **Debtwork** | Working now and paying later, elsewhere. A debt is anchored in a **tallystone**: a cast block inscribed with the working's circle. When the debt is called, the Gate collects it from wherever the stone lies. Move the stone and you move who pays. | "Philosopher's Stone use" and the clans' **Stone Abilities** (exists: the Marcoh lineage can't use them). The spec's effect, casts cost no meter for 30 s, is exactly a working put on debt. | None at once. The debt is written in your name and called later, from the ground under your stone. A stray who does debtwork loses their clean account (§6.3). |
| **Kinmaking** | Making, remaking or returning a person. It has never worked. | "Human transmutation attempt" | Paid at once, in person: Truth takes part of the worker (exists in the spec: a limb, which leads to automail). |
| **Grafting** | Joining living kinds: beast to beast, beast to person, or metal to flesh so that it moves. | "Made a chimera" | The graft's own life, in time. Grafts don't last. |

- **Tallystones are not made of people** (rule). A tallystone is cast iron or dressed stone with an array in it. It's ugly, heavy and warm to the touch. The Foundry Yard casts them (§4).
- **Owner decision kept** (exists, 2026-10-19): Taboo is secret power, hunted once it's discovered.

### 2.6 The Gate and Truth in this world

- **The Gate** (exists) is the far side of every circle, where the Tally is kept. Every working passes through it the way a coin passes a counting table, and almost nobody ever sees it. People see it in three ways: when their mastery reaches a ceiling and they ask to carry more; when they attempt an Unpaid Art; and when they **fall through it from elsewhere** (§6).
- **Truth** (exists) keeps the count. It isn't a god and it isn't a devil. It doesn't punish; it collects. It never lies, and it answers only the question asked. It wears faces it has borrowed (it wore the drillmaster's in the Tutorial, §6.2). The owner's figure for it exists as an icon: white, seated, grinning, with black arms. People who have met it say the smile is the worst part.
- **Truth's rule** (PROPOSAL): **"Every door swings both ways."** When a debt is called, the Gate stands open over the owed ground, and things come through from the other side.
- **When a debt is called** (PROPOSAL): collection takes a thing's *kind* first and its *weight* after. Wood forgets it's wood. Iron goes to red ash. Water turns heavy and glassy. Grass goes grey in a ring. People say **"a fall of grey"** for a small collection and **"the dark"** for a big one.

---

## 3. History timeline (PROPOSAL)

Years are counted from the Charter: **C.R.** ("Charter reckoning"). **This year is C.R. 214.**

| Era | When | What happened |
|---|---|---|
| **1. Before the Writing** | time out of mind | Alchemy is a hedge-craft done by hand. Workings are small and paid on the spot. The ancestors of the Ishvalan people farm a green eastern plain. |
| **2. The Xerxian Writing** | about 900 to 600 years before the Charter | Xerxian scholars draw the first circles, write the Tally down, and invent **sinks**: deep arrays in bedrock that hold a working's price until it falls due. Their cities grow rich on borrowed work. Their surveyors cut sinks across the old rock of the continent, under other peoples' land. |
| **3. The Long Collection** | about 600 years before | The eastern sinks fall due over a century. The plain pays and becomes desert. The people who paid name the debt, and the Xerxian kingdom breaks apart in the wars that follow. Its scholars scatter (the **Xerxian Remnant**, exists). The Ishvalan people swear the **Covenant of Ground**: *the ground is not ours to borrow against.* |
| **4. The Charter** | C.R. 1 | The provinces unite as Amestris under the **State Authority**. The Licence is written to forbid debtwork forever. Borders settle with Aerugo to the south-west, Drachma to the north and Xing in the east across the desert. |
| **5. The Bright Years** | C.R. 151 to 183 | The Bureau of Survey and Assay maps old Xerxian sinks while surveying for mines, and quietly starts borrowing again. At **the Sunworks** in the province of **the Vell**, a furnace burns with no fuel (**the Unpaid Fire**). The foundries boom, the railways reach every region, and Lindenmoor's mines and field school open. |
| **6. The Eclipse** | C.R. 183 | The Sunworks' debt is called. Noon goes dark over the Vell, and the province pays. The Bureau walls the ruin in as the **Eclipse Citadel** (exists as a place). The official story is "the Blight", caused by Drachman sabotage. The Northern Wall (exists) is extended, and licences are tightened. ("Alchemy isn't for people like us": Lise, exists.) |
| **7. The Quiet Ledger** | C.R. 184 to now | The Bureau keeps the foundries running by **re-sinking**: moving debts into old mines, onto night freight, into frozen vaults and over the border. It records every sink in the **Deep Ledger** and every stray in the **Grey Book**. Lindenmoor's sink **LM-7** goes in (C.R. 184, due C.R. 214). Halvard, a licensed assayer, seals his vault over the ridge's deep array (C.R. 202). The Unlicensed Circle grows. |
| **8. This year** | C.R. 214 | Sinks sunk after the Eclipse fall due across the country. Strays come down by the dozen. Under Lindenmoor's ridge, LM-7 starts to pay, and the player falls through. |

---

## 4. Nations and regions

### 4.1 The seven regions

The regions (exists), their places and level bands come from the world spec. Each region's identity, tension and secret below are PROPOSAL, and each is checked against what the region is built as, or is specced to be built as.

| Region | Identity | Tension | Secret |
|---|---|---|---|
| **Lindenmoor** (levels 1–6; built) | A farm-and-mine valley in Amestris: red tile roofs, Mill Creek, the station and the signal box, the mine approach and headframe, Bramble Woods, and a training field where five licensed teachers keep a field school (four now: Brannoc has left a notice, exists). It keeps its own constable (Militia law, exists). | The mines are failing and the harvest is thin. State notices go up on the board. Strays keep turning up on the ridge knoll, and folk are split between charity and fear. | The ridge is an old **Xerxian sink**. In C.R. 184 the Bureau sank Lindenmoor's debt (**LM-7**) into its outer end through a mine shaft it then boarded (exists: the "flooded" shaft). The **Ridge Marker**'s figures (exists) are the sink number and the due year: **this year**. Halvard found the sink's heart under No. 4 and locked it so the Bureau couldn't use it (exists: "No. 4 is not ore. The array goes deeper than the mine. They will want it"). |
| **Foundry Yard** (5–12; built) | The State's great foundry: soot, iron, the crane bay, two shifts, the canteen, workers' row and the underworks tunnel (exists). It casts rail iron for the whole country. | Crews against foremen, pay fraud (exists: the shift ledger), apprentices with no hope of a licence (exists: Lise), and Authority inspectors. | Furnace One runs hotter than coal can make it. On nights the ledger calls "banked", Furnace One pours **tallystones** for the Bureau (exists hook: the 14th's false hours, signed C. Ashe, and the crate Ashe bought off the evening freight "in new State coin"). The licensed chalk going missing (exists: the Voided Ledger Line) is drawing stock for the stones' arrays. |
| **Central City** (hub; specced) | The capital: Central Terminal, the Licensing Office, hearings and newspapers, the Bureau's records hall (exists in the stealth spec), and the undercity. | Politics. Licence hearings, rival offices, and petitions to open the Licence to working people. Everyone important knows your name by now. | The city is built over the biggest Bright Years sinks. The undercity's tunnels (exists in the world spec as the story route to the Corrupted Lands) follow them, and the capital has a due date of its own. |
| **Ishval** (18–30; specced) | A desert of red stone, oases and a rail halt (exists). It was once a green plain: the oldest Paid Land. The Ishvalan Community (exists) farms the oases and keeps the Covenant of Ground. | The State railway runs across Ishvalan land. Licensers come and go. A quarry company works the cliffs (exists in the stealth spec). There's an old grievance with the Xerxian Remnant. | The Ishvalans keep the only record of a debt called to its end, and the only known cure: **settling**, slow and without alchemy. They have met strays before. They call them **the Gate-sent** (PROPOSAL). |
| **Aerugo Borderlands** (12–22; specced) | Vineyards, the border customs fort (exists in the stealth spec), Vintner's Pass, and the ash wastes running down to the Paid Lands (exists in the world spec). Guild alchemists, smugglers and vintners. | Rivalry with Amestris, border patrols and smuggling. | The Bureau pays smugglers to sink State tallystones on the Aerugonian side. The "grey rot" killing the vineyards is collection. Amestris is exporting its debt to a rival. |
| **Northern Wall** (25–35; specced) | The great fortress facing Drachma: switchbacks, snow, a garrison, Drachman traders, and the gatehouse cold store (exists in the stealth spec). | Old hatred of Drachma, kept warm by the Eclipse story. | **Cold keeps a debt asleep.** The Wall's vaults hold the State's worst tallystones frozen (**the Cold Store**), and the cooling is failing. The Wall faces south as much as north: it also guards the ice caves into the Paid Lands (exists as a route). |
| **Corrupted Lands** (30–45; specced) | The Paid Lands. Grey ash plains, glassy rivers, the walled Eclipse Citadel, the Bureau's containment camp (exists in the stealth spec), and the Eclipse cycle with its crimson phase (exists in the world spec). | The State, the Circle's hidden cells and things that used to be alive. | It's still paying. The crimson phase is the hours when the Gate stands open over the Citadel, so collection quickens, more strays fall, and more **Unkinded** walk: animals, timber and people whose kind has been taken and who keep moving out of habit. The Bureau keeps re-sinking into the Citadel, so the Vell's debt grows, and it has started to creep toward the undercity. |

### 4.2 The nations (own history; names exist)

| Nation | This game's history (PROPOSAL) | Proposed creator blurb (PROPOSAL; replaces today's) |
|---|---|---|
| **Amestris** | The Charter state, run by the State Authority. It is proud of its railways and frightened of Drachma. | "The Charter state at the heart of the map, rich on rail and iron, still living in the shadow of the Eclipse." |
| **Xing** | An empire of merchant houses (exists as a community) across the eastern desert. It practises forepaying and deals in contracts. | "From the eastern empire across the desert, where alchemists pay before they work." |
| **Ishval** | The people whose plain paid for the Xerxian kingdom's debt. They keep the Covenant of Ground. Disciplined, devout, and wary of alchemy for a reason they can name. | "A desert people of the east who keep the Covenant of Ground, and remember what borrowed alchemy costs." |
| **Xerxia** (the old Xerxian kingdom) | The inventors of circles and of sinks. The kingdom fell to the wars after the Long Collection. Its descendants (the Remnant, exists) split between those who atone and those who sell the old knowledge. | "Descendants of the lost eastern kingdom that first wrote the Tally down, and first learned to cheat it." |
| **Aerugo** | A southern rival where alchemy is a guild trade, not a state licence. It is ahead in theory and behind in iron. | "From the southern nation of guild alchemists and vineyards, Amestris's oldest rival." |
| **Drachma** | A cold northern empire, blamed for the Eclipse by Amestris. Its frontier settlers and traders (exists as a community) want the truth out. | "From the cold northern empire beyond the Wall, blamed for a disaster it didn't cause." |

**Why these:** today's blurbs (exists, `Customization.NationBlurb`) mention the series' own events and places ("the Promised Day", "Briggs", its eastern art's name). The proposed blurbs keep each nation's flavour and give it this game's history. They're a text change for later (owner's call, see the story concept's open questions).

---

## 5. Factions

The factions are the existing ones in `Rensei.Factions` and `Rensei.Regions` (exists). Their goals and views of the player are PROPOSAL.

| Faction | Goal | How it sees the player (a stray) |
|---|---|---|
| **State Authority** | Order, industry, the Licence, and peace on the borders. Most of the Authority believes the Eclipse story. | **Paperwork.** A stray is registered at the nearest station and watched. If they're useful, the Authority offers them a licence path (exists: the State's exam). |
| **↳ the Bureau of Survey and Assay** (PROPOSAL office inside the Authority) | Keep the country solvent by keeping its debts moving. It runs the sinks, the Deep Ledger and the Grey Book. Its inner office is the morality spec's hidden State faction (exists as the placeholder **Shadow Office**), the one that may recruit a Taboo user. | **An instrument and a warning.** Every stray marks a debt being called. Strays are also the only people who can walk into called ground and come back, so the Bureau uses them as couriers. |
| **Foundry Hands** | Fair pay, safe furnaces, and looking after their own. | **A stranger who might be an inspector.** Keep quiet and they'll keep you. |
| **Unlicensed Circle** | Open alchemy to anyone with the hands for it, and expose the Bureau. Hidden in Lindenmoor, the City and the Corrupted Lands (exists). | **A witness.** A stray proves a debt was called somewhere. Most cells want to protect and recruit you. |
| **↳ the Reckoners** (PROPOSAL splinter of the Circle) | Call the debt all at once, on the capital's own sinks, and break the State with it. | **A weapon.** An unweighed courier can carry a stone where nobody else can. |
| **Townsfolk** | Peace, a fair price and a decent harvest. | **Superstition, then judgement.** "A stray on the knoll means the ground is owed." Charity or fear first; after that, they judge you by your deeds (exists: rumours and witnesses). |
| **Amestrian Citizenry** | Ordinary Amestrians: patriotic and wary of Drachma. They believe the Blight story. | You're one of theirs if the Gate dressed you as one (§6.3). |
| **Ishvalan Community** | Keep the Covenant, mend the ground, and keep the railway's hands off the oases. | **The Gate-sent.** Hospitality first, then a test: will you borrow against ground that isn't yours? |
| **Xingnese Merchant Houses** | Trade, contracts and forepaid work. | **An unbought word.** A stray owes nobody, so a stray's testimony is worth money. |
| **Drachman Frontier** | Clear Drachma's name for the Eclipse. | **A natural ally** for anyone who wants the truth out. |
| **Aerugonian Guild** | Prove Amestris is sinking debt on Aerugonian ground. | **A useful outsider** who can cross the border without a guild's colours. |
| **Xerxian Remnant** | Split: the atoners want the sinks closed, the sellers want the knowledge paid for. | **Their ancestors' bill come due.** Some can't look at you. |

Lindenmoor's **Militia** law (exists as a jurisdiction) is the village constable's, not a faction. It counts with Townsfolk.

---

## 6. The outsider

### 6.1 How and why the player arrived (PROPOSAL)

- **You fell; you weren't sent.** On the night LM-7 began to be called, the Gate stood open over Lindenmoor's ridge. You were near the door on the other side, wherever you were, and you came through. Nobody chose you. No prophecy names you. (This keeps the README's pillar: the title of Legendary Alchemist is earned, never predestined.)
- **You're one of many.** This year the sinks sunk after the Eclipse fall due all over the country, and strays come down every week. In a server full of players, that's simply true: **every player is a stray.** The rise in strays *is* the story's alarm: the Bureau's Grey Book is filling faster than it ever has.
- **Why it matters to the plot:** a stray is proof that a debt was called. A stray is also the only kind of person the Gate doesn't collect from (§6.3). So the Bureau needs strays, the Circle wants them, and in the end both sides of the last act need one who's still clean.

### 6.2 The Weighing: the Tutorial, explained (PROPOSAL)

Nothing enters a world unweighed. Before the Gate lets a stray through, Truth weighs them. It builds a yard out of a borrowed memory, the yard of the man who has trained more newcomers than anyone in this world, **Drillmaster Vask** (exists), and it wears his face. It watches you move, strike, guard and take hold. It lets your hands try a medium that isn't yours yet (the Tutorial's Alchemy beat). The voice that speaks when you don't finish the Bout properly is Truth's own (exists: *"Again. And this time, take hold of it."*). Then the Gate opens and you walk through.

**Proposed Gate finale lines** (PROPOSAL; three lines inside the existing ~9-second finale, `FINALE_TIME`; check against the lines already in Studio):
> *You were not sent. You fell.*
> *The ground here is paying, and every door swings both ways.*
> *You owe this world nothing. Keep it that way, if you can.*

**The real Vask** (PROPOSAL) is alive and drilling new hands at the Foundry Yard (his existing dialogue, `tutorial_drillmaster`, is all furnaces and night shifts). When you meet him in Act II he doesn't know you. "Strays keep telling me they've met me," he says. "I've never liked it."

### 6.3 The rules of being from elsewhere (PROPOSAL)

1. **You arrive where a debt is being called.** Usually that's the Paid Lands. You landed in a green valley, because Lindenmoor's sink came due.
2. **The Gate dresses you.** It can't put a person into a world without weighing them in its terms, so it weighs you in the likeness of one of this world's peoples: their look, their tongue and a few of their songs (your **nation**, exists: chosen in character creation). It also weighs you against a family line, and you carry that line's gift (your **clan**, exists: the surname roll). That's why the communities treat you as kin, and why a family sometimes recognises its own gift in a stranger.
3. **You keep your own mind.** You remember home. The game never shows it, and you can mention it in a few dialogue choices. ("Where I'm from, nobody draws circles.")
4. **You're unweighed.** Everyone born here carries a **birth-share** of the debt owed by the ground they were born on. You carry none, so a collection doesn't take you. You can stand in called ground far longer than anyone native, and in the crimson phase you're the only one who can.
5. **Your medium is unset until a teacher sets it.** The first true working with a teacher writes your hands into the Tally, once, for life (exists: one path per character).
6. **Debtwork writes a debt in your name.** One tallystone working and you're no longer clean (this ties the Taboo layer to the story: it closes the "Settle" ending, §7.4).
7. **There's no known way home.** Truth answers questions with prices. (Whether a stray can ever go back is an owner decision; see the story concept's open questions.)

### 6.4 The bird (PROPOSAL)

The swift in the waking cutscene **came through with you**. It's from your world. Nobody in this one has a word for it. Ned calls it "the stray's bird", and the Codex entry is **The Bird With No Name**. It's seen again over every big collection: wherever the door stands open, it's on the wing. Its last appearance is over the Eclipse Citadel in Act V.

### 6.5 How people react

| Who | Reaction (PROPOSAL) |
|---|---|
| **Lindenmoor's folk** | "Came down with the grey, did you?" Wary charity. Some leave bread on the knoll; some won't sell to strays. Rumours and deeds (exists) settle it either way. |
| **The Bureau** | Courteous registration at the station, a number in the Grey Book, and after that, watching. |
| **Licensed teachers** | Unease and interest: "You've seen the Gate before your first circle?" |
| **The Circle** | A safe word and an offer. |
| **Ishvalans** | Water first, questions later. |
| **The real Vask** | He doesn't like it at all. |

---

## 7. The central mystery and the antagonists

### 7.1 The question

**"What does the State owe, who is it owed to, and who is paying?"** Each act answers one layer and opens the next:

| Act | The layer it reveals |
|---|---|
| I. Lindenmoor | There's a sink under the ridge, it falls due this year, and the Bureau means to push the debt deeper rather than pay it. |
| II. Foundry Yard | The stones are cast here, on nights the ledger calls "banked", and moved by night freight. The State's industry runs on debt. |
| III. Central City | The Deep Ledger (every sink) and the Grey Book (every stray). You find your own entry, **written the morning you arrived, before anyone had seen you**. (The Bureau has instruments that shiver when a door opens: **tally-glasses**.) |
| IV-a. Aerugo | Where the debt goes: over the border. |
| IV-b. Ishval | How it can be stopped: settling, slowly, with no alchemy. |
| IV-c. Northern Wall | How much there is: the Cold Store, and how close it is to waking. |
| V. Corrupted Lands | The Eclipse was no blight. The Vell is still paying, and the capital is next. |

### 7.2 Why the Corrupted Lands are corrupted

The Vell paid the Sunworks' debt (§3). Collection took the land's kind first: the soil stopped being soil, the timber stopped being wood, and people and animals kept walking after they had stopped being anything (the **Unkinded**, the region's enemies). The Bureau never stopped sinking new debt into the Citadel, so the collection never finished. The **crimson phase** of the Eclipse cycle (exists) is when the Gate stands open over the Citadel: more collection, more Unkinded, and more strays.

**The connection to the player:** it's the same door. The Lindenmoor sink is a small cousin of the Vell. Every stray fell through a collection, and the Grey Book's count shows the collections speeding up everywhere since the Bureau began re-sinking in earnest. The more the State borrows, the more doors open.

### 7.3 The antagonists (PROPOSAL)

- **Assayer-General Odette Sallow**, head of the Bureau of Survey and Assay. Exact, courteous and sincere. She believes the country would starve and go to war without its debts. Her plan, **the Even Measure**, is to spread the Vell's debt thin across every acre of the State, so no place is ever called hard again and every harvest is a little poorer forever. It needs the Citadel's founding stone carried into the open Gate at the crimson phase, by someone with a clean account: **a stray**. Her line: *"Nobody starves on a slightly poorer harvest. They starve in the Vell."*
- **Sorrel Kade**, leader of the Reckoners. He was the first stray the Bureau ever registered: he fell into the Vell during the Eclipse, and they used him as a courier in called ground for twenty years. He wants the whole debt called at once, on the capital, and the State broken by it. He's the player's dark mirror: what a stray becomes when every side uses them.
- **Neither is a monster.** Each is right about the other. This follows the game's grey-choice rule (exists, `Morality and Reputation Proposal.md` goal 4).

### 7.4 Ending directions (PROPOSAL; Phase 10 isn't designed)

These are shaped by the player's deeds, standing, licence path and Taboo marks, never by one last dialogue choice (exists rule).

- **Expose:** the Deep Ledger goes public. The Bureau falls and debtwork stops. The foundries slow, and hard but honest years follow. What's owed is still owed, so the Ishvalan settling becomes everyone's long work.
- **Even Measure:** you help Sallow. There will be no more Paid Lands, the price is spread over every field forever, and the secret is kept.
- **Settle:** a stray who is still clean carries the Citadel's stone into the Gate and asks Truth the price. It needs Ishvalan standing, the Remnant's knowledge, and **no Taboo marks**. What Truth asks for is the owner's call (§6.3, rule 7).
- **Harness:** you take the Citadel's stone for yourself, by the Taboo route. You become strong and feared, and the debt is now yours.
- **(Failure) the Reckoning:** if Kade isn't stopped, the capital pays.

### 7.5 Smaller mysteries to seed early (PROPOSAL)

1. **The figures on the Ridge Marker** (exists: "a row of figures"). They're a sink number and a due year: *LM·7 · DUE C.R. 214*. Ned thinks they're field measures.
2. **The bird with no name** (§6.4).
3. **Vask's face** (§6.2).
4. **Furnace One runs hotter than coal** (Foundry Yard).
5. **Where Halvard went.** His name turns up in the Deep Ledger: "retired, Northern Wall."
6. **Hooks already in the game that this lore can answer later:** Maren Ostrova's guardian that "holds the station's cold" (exists: was her station keeping a stone asleep?), and the Armored Experiment, "plated with cast iron. It moves" (exists: a graft, done in Brannoc's forge by someone else).

---

## 8. Key characters

### 8.1 Existing characters (kept; their roles in the lore are PROPOSAL)

| Character | Where | Role in the lore |
|---|---|---|
| **Truth** | The Gate | Keeper of the Tally. It weighed you. |
| **Drillmaster Vask** | Tutorial; real man at the Foundry Yard (PROPOSAL) | Truth borrowed his face for the Weighing. The real one drills new foundry hands. |
| **Calda** (Flame), **Veyra** (Ice), **Holt** (Earth), **Ansel** (Wind) | Lindenmoor's training field | Licensed teachers at the field school. Each has their own view of the debt: Calda thinks it's a fire someone let get away; Veyra suspects the cold vaults; Holt reads the ground and doesn't like it; Ansel already knows more than he says (PROPOSAL views). |
| **Brannoc** (Metal) | Foundry Yard (moved 2026-10-24); his notice stands in Lindenmoor | He knows Furnace One runs hot and won't say why. |
| **Ned Harrow** | Lindenmoor, the groundskeeper | The first person you meet. He scrubs the Ridge Marker for "a few coins a season from the Survey" (PROPOSAL) and thinks it's about hedges (exists: his clue line). |
| **Bess Kettering** | Lindenmoor, the mine hand | She knows what went down the "flooded" shaft in C.R. 184: her father, **Tom Kettering** (PROPOSAL), carted the crates. She tells the flood story (exists) until she trusts you. |
| **Halvard** | Absent | The licensed assayer who locked the sink's heart (exists). Fate unknown. |
| **Wren** (automail mechanic), **Coach Harlan**, **Master Thura** | Lindenmoor | Unchanged. Wren sells transmutation chalk (exists) and asks no questions. |
| **Abel Crane** (signalman), **Jory Fallow** (miller), and the farmers **Garrick Ashby**, **Marta Quill**, **Osric Penhale** and **Ilse Dunmore** | Lindenmoor | Townsfolk: rumour-carriers and witnesses. |
| **Foreman Brask**, **Mirra**, **Tobin**, **Lise** | Foundry Yard | Unchanged, including Lise's choice. Lise's chalk is the same stock the Bureau's stones need. |
| **Edmund Rusk**, **Sella Marsh**, **Aldous Merriweather**, **Ivo Marchbank** and the rest of the Foundry roster | Foundry Yard | The crews. They are the Act II witnesses. |
| **C. Ashe** | Foundry Yard (unseen) | The charge hand who faked the 14th's hours. PROPOSAL: **Cyprian Ashe**, the Bureau's man at Furnace One. |
| **Corin Vale**, **Maren Ostrova**, **Dask**, **Siv**, **the Crystallized Guardian**, **the Armored Experiment** | Trial sites | Unchanged; §7.5 has the hooks. |

### 8.2 New story characters (all PROPOSAL)

| Character | Where and when | Role |
|---|---|---|
| **Registrar Lucan Prewitt** | Lindenmoor Station's Bureau desk (Chapter 1, beat 12); later the Grey Book office in Central | A mild Bureau clerk who registers strays and keeps a page on you, as you keep one on him. He's a possible ally in Act III. |
| **Inspector Aurel Denby** | Lindenmoor's mine approach (Chapter 1, beats 9–11) | A tired, decent Bureau inspector who thinks moving the debt deeper is saving the valley. |
| **Constable Mabry Selden** | Lindenmoor's square (Chapter 1, beat 10) | The village's Militia constable. Fair, outnumbered, and unhappy about State inspectors. |
| **Wenna Fane** | First as a note and a rumour (Chapter 1); in person in Act II | A Circle sink-hunter, Flame. She wrote the Adit's "Visitor's Note" (exists: "Someone has been here before me"). An ally or a rival. |
| **Assayer-General Odette Sallow** | Central City (Act III onward) | The antagonist (§7.3). |
| **Sorrel Kade** | Rumours from Act II; Corrupted Lands (Act V) | The Reckoners' leader (§7.3). |
| **Elder Saffa Orun** | Ishval (Act IV-b) | Keeper of the Covenant. Teaches settling. |
| **Peleas Amund** | Central City's undercity (Act III) | A Xerxian Remnant archivist: an atoner who can read the old sink-arrays. |
| **Tom Kettering** | Dead; mentioned only | Bess's father, the Bureau carter. |

Each later region gets its own minor cast in its own spec.

---

## 9. Tone and writing rules for every future line

### 9.1 Voice

- **Working people, concrete words.** People talk about their jobs, their pay, the weather and the trains (exists: the townsfolk's job lines). Alchemy is described in trade words: weight, kind, heat, stock, strain, price.
- **Short lines.** One fact per sentence. The dialogue box holds about 240 characters (exists rule); aim for 180.
- **Nobody lectures.** People tell you what they need, not what they know. Lore comes out sideways: in a complaint, a notice, a joke, or a clue.
- **Each voice has a register.** The State is polite and bureaucratic ("Persons arriving without papers are requested to..."). The Circle is quick and wry. Ishvalans are plain and unhurried. Truth uses short, even sentences, with no exclamation marks and no comfort.
- **Grey, not grim.** Kindness is real and small: a bed, a meal, a warning. Villains have reasons. No choice is the "good ending" button (exists rule).

### 9.2 Words to avoid

| Avoid | Why | Use instead |
|---|---|---|
| "Equivalent Exchange" | The series' own law | **the Tally**, **the price** |
| "Philosopher's Stone", "Philosopher's Tier" | The series' own object (and ours isn't made of people) | **tallystone**; a rank name to be chosen. "Stone Abilities" can stay as the internal label. |
| homunculus / homunculi, Father, the Promised Day, Briggs, alkahestry, "dragon's pulse", a country-wide circle | The series' plot, characters and terms | This file's history |
| "chimera" | The series' word | **graft**, **grafting** |
| "human transmutation" in player-facing text | Too close to the series | **kinmaking** (the code and spec term can stay) |
| "State Alchemist", a silver watch | The series' titles and tokens | **licensed alchemist**, **Tallybook** |
| "toll" at the Gate | The series' word for the Gate's price | **price** |
| magic, mana, spell, wizard | Not this world | working, medium, circle, strain, alchemist |
| chosen one, destiny, prophecy | Breaks pillar 6 (earned, not predestined) | Nothing. The player earns it. |
| "corruption" in speech | It's only the State's map word | "the Paid Lands", "called ground", "a fall of grey" |
| "dross" | The draft's retired placeholder | "debt", "a sink", "a tallystone" |
| modern slang, "OK" | Breaks the period | "Right.", "Fair.", "Done." |

**Kept although they come from the series** (the owner's existing choices): the nation names (Amestris, Ishval, Xing, Drachma, Aerugo, the Xerxian people), the Gate, Truth, automail, the Marcoh clan, and the plain job labels "Flame Alchemist" and the like.

### 9.3 How much to explain

- **At the moment of use, never before.** A thing is explained when the player first needs it, in at most two short sentences or one Field Note (exists system).
- **Show it, then name it.** The player sees the grey ring before anyone says "a fall of grey".
- **One new idea per quest.** Chapter 1 needs only four ideas: **the Tally** (things have a price), **strays** (you), **sinks** (debts buried in the ground) and **the Bureau** (who buries them). Everything else waits.
- **Answer one question, open at most one.** Mysteries move forward; they don't pile up.
- **The Codex holds the rest** (exists): a player who wants more reads it, and a player who doesn't never has to.

---

## 10. Glossary (PROPOSAL unless marked)

| Term | Meaning |
|---|---|
| **Birth-share** | The share of a ground's debt everyone born on it carries. Strays have none. |
| **Bright Years** | C.R. 151–183: the boom the Bureau's borrowing paid for. |
| **Bureau of Survey and Assay** | The Authority's office for mines and surveys, and secretly for debts. |
| **Called** | Said of a debt being collected. "Called ground" is ground that's paying. |
| **C.R.** | Charter reckoning, the year count. This year is C.R. 214. |
| **Covenant of Ground** | The Ishvalan oath: *the ground is not ours to borrow against.* |
| **Debtwork** | The forbidden art of working now and paying later. |
| **Deep Ledger** | The Bureau's master record of every sink. |
| **The Eclipse** | C.R. 183: the Sunworks' debt is called and the Vell pays. (The Eclipse cycle and the Eclipse Citadel exist.) |
| **Even Measure** | Sallow's plan to spread the Vell's debt across the whole State. |
| **Fall of grey** | A small collection: grass, soil or ore gone grey and dead in a patch. |
| **Field school** | A training ground where licensed teachers may take students before the licence exam (Lindenmoor's training field). |
| **Forepaying** | The Xingnese way: pay before the working. |
| **Gate** (exists) | The far side of every circle, where the Tally is kept. |
| **Gate-sent** | The Ishvalan word for a stray. |
| **Grafting** | The forbidden art of joining living kinds. |
| **Grey Book** | The Bureau's register of strays. |
| **Kinmaking** | The forbidden art of making, remaking or returning a person. |
| **LM-7** | Lindenmoor's sink. Sunk C.R. 184, due C.R. 214. |
| **Medium** (exists, Vask's word) | The one path a person's hands take to: Flame, Ice, Earth, Wind or Metal. |
| **Paid Lands** | What the people who live near them call the Corrupted Lands. |
| **Reckoners** | The Circle's splinter that wants the whole debt called at once. |
| **Re-sinking** | Moving a debt by moving its tallystone, so somewhere else pays. |
| **Settling** | The Ishvalan craft of mending called ground, without alchemy. |
| **Sink** | A deep array in bedrock that holds a debt until it falls due. The Xerxian kingdom built the first ones. |
| **Strain** | What an alchemist pays small workings with: the body's own effort (the meter, exists). |
| **Stray** | A person who fell through the Gate from elsewhere. Every player is one. |
| **Sunworks** | The Bright Years works in the Vell, home of the Unpaid Fire. It's the Eclipse Citadel now. |
| **Tally** | The law of exchange: weight for weight, kind for kind, paid now. |
| **Tallybook** | A licensed alchemist's audited book of workings. |
| **Tally-glass** | A Bureau instrument that shivers when a door opens. |
| **Tallystone** | A cast block that anchors a debt. Using one is the game's "Stone Abilities". |
| **Three heats** | Assay, melt and cast: the three steps of every working. |
| **Truth** (exists) | The keeper of the count. |
| **Unkinded** | Things whose kind has been collected and that still move. |
| **Unpaid Arts** | The Licence's name for debtwork, kinmaking and grafting. |
| **Unpaid Fire** | The Sunworks' furnace, which burned with no fuel. |
| **The Vell** | The province that paid for the Eclipse. |
| **The Weighing** | What the Tutorial really is: Truth weighing a stray before letting them in. |

# Rensei Changelog

What each phase built and how it was tested. Newest first. Work is in the Studio place **Ye** unless an entry says otherwise. Backups of every touched script are in `ServerStorage.RenseiBackups`.

## 2026-10-16 — Morality, first slice (M1–M3 + M5)

**Built (owner approved the defaults in `Morality and Reputation Proposal.md` §8: five tracks, the placeholder factions, Mercy / Candor / Order, words only, no deeds in arena / duels / self-defence, flavour titles; Taboo canon left for later):** all names, lines and numbers are placeholders / PROPOSALS. Backups: `ServerStorage.RenseiBackups["Pre-Morality_2026-10-16"]`.
- **M1 — data + save schema 4.** New `Rensei.Factions`:
  - the factions State Authority, Foundry Hands, Unlicensed Circle and Townsfolk;
  - tiers Hostile / Distrusted / Neutral / Trusted / Honoured;
  - the conduct words (Merciful–Ruthless, Honest–Deceitful, Lawful–Defiant) and the renown ranks.

  New `Rensei.Deeds`: 9 deeds, plus `Finishers` for knocked enemies. `ProfileData` is now `SchemaVersion = 4` with `Morality = {Deeds, Conduct, Standing, Trust, Renown, Taboo}`. The `DataManager` 3→4 migration is additive.
- **M2 — `MoralityService`, the only writer.**
  - `Record` puts a deed on the ledger once. Repeatable deeds count at most `Cap` times a day, so morality can't be farmed.
  - It applies the deed's effects:
    - Conduct and Trust always change.
    - Standing changes only for Local / Public deeds. A Private deed waits for discovery, which comes in a later slice.
    - Renown changes for Public deeds.
  - It shows a toast with the deed's reason, and a banner when a faction's tier changes.
  - On join, all tracks are **rebuilt from the ledger**, and any quest ending already chosen is turned into its deeds once (so older saves catch up).
- **M3 — hooks.** New StoryLogic conditions: `Deed`, `NotDeed`, `Standing` / `StandingBelow` (a tier name or a number), `Trait`, `Trust` / `TrustBelow` and `Renown`, with lock labels such as "[State Authority: Trusted]". Other hooks:
  - a dialogue action `{Kind = "Deed"}`;
  - quest `Outcomes[x].Deeds`;
  - `DownedManager.Listeners` (fired after a grip finishes someone);
  - `WorldService.Credit(Victim, Player)` (credits a victim once only).
- **M5 — content.**
  - **Lise:** Report, Secret and Teach each record their deed. After Secret, telling Brask "It was Lise" is a separate betrayal: Candor −10, Lise remembers it, and new lines for her and Brask.
  - **Tobin:** "Your secret's safe" is now a promise (with a "not promising" option). Telling Brask later records a *broken promise* (Candor −10) or a plain *told on*, and Tobin's lines change.
  - **Brask:** after the quest, "Any word from the Authority's inspectors?" is greyed until the State Authority is **Trusted**. Mirra reacts to Report / Teach.
  - **Bandits:** gripping a knocked bandit is *Finished off a beaten bandit* (Mercy −1). Carrying one alive to Brask (`TakesPrisoners`) is *Carried a beaten bandit in alive*: Mercy +1, Order +1, Authority +1, Townsfolk +1, +10 money, and the defeat counts once.

**Fixed while testing:** `DownedManager` found the carried body by **name**. With two "Bandit Duelist"s alive, it returned the healthy one, so Drop (and the hand-over) acted on the wrong rig. The new `DownedManager.Carried(Carrier)` follows the `CarriedBy` link, and Drop uses it. This was an existing bug.

**Tested (Studio Play, real key presses):**
- Server checks: a once-only deed recorded 20× counted once; a repeatable recorded 15× counted 10 (the cap); an unknown id was ignored; a rebuild from the ledger gave identical numbers; the join-time catch-up of an old Report ending applied once and was idempotent.
- Tobin: broke his lie, promised (toast and Trust +15), then got his "you kept your word" line. Brask showed exactly one "Tobin slept" choice. Picking it recorded the broken promise (Candor −10, Foundry −5, Tobin −35), and the choice was gone afterwards.
- Lise: backing out at the confirmation recorded nothing. Secret recorded *Kept Lise's secret* (Private: Lise +30, Mercy +5, no faction change).
- Brask after the quest: "It was Lise" and the greyed "[State Authority: Trusted]" choice were shown. The locked one did nothing. Betraying Lise gave Candor −20 (Deceitful), and Lise's new line followed.
- Grip on a knocked Bandit Duelist: deed recorded, kill credited once. Carry to Brask: deed, standing, +10 money, +125 EXP credited once; the other live duelist was untouched.
- At Authority 20, Brask's inspectors line unlocked with no label.
- Console clean. The owner's save was snapshotted and restored. Its only lasting change is the schema 4 migration (an empty ledger). Hooks and test spawns removed.

**Not built (next slices):** Discovery (M6), the Journal Standing tab (M4), standing drift, PvP grip deeds (PvP rules still undecided), titles / renown sources, Taboo (canon pending). Grunt bandits aren't Knockable, so only Bandit Duelists can be gripped or carried.

**Notes:**
- When this session started, the Studio save showed EXP 0 with no quests, unlike the earlier test save (quest at stage 5). It may be a different save slot. It was restored exactly as found.
- New scripts are mirrored in `Scripts/`.

## 2026-10-16 — Morality & reputation proposal; full Foundry Yard playtest

**Proposed (not built): `Morality and Reputation Proposal.md`.** Audit: there is no morality or faction system in the game. The only consequences today are the recorded story choice `Outcome_chalk_foundry` and Grip / Carry on knocked targets. The proposal expands Implementation Plan §14–16 into:
- a **Deeds Ledger**: every consequential act is recorded once, with its reason;
- five tracks built from it: **Conduct** (Mercy / Candor / Order, shown as words), **Standing** with each faction, **Renown** (the road to "Legendary Alchemist"), **Trust** with single NPCs, and **Taboo** (forbidden alchemy).
- **Witness scopes** (Private / Local / Public) and **Discovery**: a secret deed can surface later through evidence.
- It maps the Lise / Tobin / bandit-bounty moments onto deeds and has build slices M1–M7.
- Every number is a PROPOSAL. The extra factions (Foundry Hands, Unlicensed Circle, Townsfolk) and the titles are **(new)** placeholders. §8 lists 8 owner decisions.

**Playtested (Studio Play, real key presses and clicks, from a fresh quest state):** the whole "Chalk on the Foundry Wall".
- Accepted from Brask. Inspected the wall chalk and the soot prints.
- The **Valve Board** was solved by reading the needle: valve 1 bleeds. The vent saved as Sealed, then the corridor led to the half-drawn array.
- Mirra, then Tobin's lie broken with the boot prints.
- The furnace store opened by the **no-alchemy route**: coal carried from the bins to the furnace, then standing on the lock stone. The notebook was inside.
- **Case Board:** one wrong answer refused at no cost, then the right one.
- Lise → **Secret** (confirmed): +150 money +50 outcome bonus, +400 EXP (level 2), both codex entries, `Outcome_chalk_foundry = Secret`. Talking to her again paid nothing more.
- **Assay Bench** (Flame / Magnet / Water → Slag Chalk) and **Ledger Cipher** (crate key → shift 5 → "Slag Heap") were played along the way. Both gave their evidence without touching the quest path.
- The dialogue box now closes when you walk away mid-conversation (the stuck-dialogue fix from another session this day).
- Console clean. The owner's save, which had its own progress (chalk quest at stage 5, bounty active), was snapshotted, reset for the run and restored exactly. The temporary hook was removed.

**Found (not fixed):**
- Pressing E as you arrive at an object, before its prompt shows, toggles **Combat Mode** instead. In Combat Mode an inspect still gives its evidence, but its text is suppressed, so it looks like nothing happened.
- The HUD quest-tracker title overlaps the chat box (top left).

## 2026-10-16 — Assay Bench and Ledger Cipher minigames

**Built (the two deferred minigames from `Quests, Puzzles and Minigames Proposal.md` §3.7, same pattern as Pressure Board / Array Restoration):** all names, lines and numbers are placeholders / PROPOSALS. Backups: `ServerStorage.RenseiBackups["Pre-AssayCipher_2026-10-16"]`.
- **Assay Bench** (`Kind = "AssayBench"`, `assay_chalk`): identify the wall chalk by testing it (Flame, Acid, Magnet, Water) and picking the matching row of a six-row reference table (Clerk's Chalk, Slag Chalk, Iron Ore, Copper Ore, Bone Ash, Sulphur). **The sample never reaches the client**: each test is a new `Act` message and the server answers with that one reaction. 3 chips per sample (PROPOSAL); every two rows differ in at least two tests, so any three tests always name it. Cells turn green or red against what you've seen. A wrong guess refills the chips. The bench's sample is always slag chalk (the story needs that); a bench without `Sample` picks a random row.
- **Ledger Cipher** (`Kind = "LedgerCipher"`, `ledger_cipher`): the server writes a four-line State Authority shipping page ("SIX CRATES CHALK TO ORE ROAD"…) from word pools, enciphers it with a shift of 5 (PROPOSAL), and strikes one chalk line out in red wax. **The key is never sent**: the player finds it on an Authority crate seal ("F over A"). A cipher ring (WRITTEN / READS, `< Shift >`) helps decode, and the answer box is the Settings key-bind box. The client sends the place; the server compares letters only (case and spaces don't matter, 40 characters max).
- **`MinigameService`** (additive): a `Requires` + `Locked` gate on opening (StoryLogic conditions), an optional `Kind.Act` step (`Act` → `Reply`, rate-limited) and `Kind.Failed` reset hook, and `Def.Evidence` given **on the first pass only**. Pressure Board and Array Restoration are unchanged.
- **`MinigameUI`**: draws both with kit buttons and the Guru font. Cipher text is letter-spaced, so Guru never joins "II".
- **Foundry Yard (optional side content; the quest's required path is unchanged):** an **Assay Bench** on the far side of Mirra's crucible (mechanism `assay_bench`, needs *Chalk Sample*) gives new evidence **Slag Chalk**. A **Shipping Ledger** beside the notice board (mechanism `yard_ledger`) gives new evidence **Voided Ledger Line** (new lore hook: the Authority is missing licensed chalk too). An **Authority Crate** by the gate (inspect `authority_crate`) holds the key. Both mechanisms save as `Mech_<Id>` and answer "It's already done." afterwards.

**Tested (Studio Play, real key presses and clicks):**
- The bench without *Chalk Sample* refused with the Locked line. With it, the Flame and Magnet tests answered Orange / Pulls and showed 1 chip left. Iron Ore → failed with refilled chips. Slag Chalk → passed, giving *Slag Chalk* once. E again → "It's already done."
- **Forged client messages:** an unknown test was ignored; a 4th test with 0 chips returned "no sample left"; `{Passed = true}`, `"true"` and a wrong row were all rejected. On the ledger, a table, a 70-character string, the raw ciphertext and an assay `Act` were all rejected or ignored. A correct answer re-sent after the pass did nothing (no session).
- Ledger: E on the crate showed the key; `>` ×5 set Shift 5; "old mill" failed; typing "Ore Road" passed and gave *Voided Ledger Line*. A second run dealt a different page.
- Console clean (client and server). The owner's save (Story / Quests / Money / Exp / Codex / Level) was snapshotted before testing and restored afterwards. A second Play session confirmed it was empty again. The temporary test hook was removed.

**Fixed while testing:** the bench first stood right beside Mirra, so her Talk prompt won over it. It was moved to the far side of the crucible.

**Re-checked afterwards:** the Journal's Evidence tab lists *Slag Chalk* and *Voided Ledger Line* under the quest. The tweaked Assay Bench layout (named table rows, cell spacing) reads cleanly, and a row can be picked. The save was snapshotted and restored again.

**Not verified:** touch input, two players at once.

**Found (pre-existing, not changed):** if you walk away from an NPC mid-conversation, the dialogue box can stay open with no way to close it. Number keys and Escape do nothing, and only a server `DialogueEnd` clears it. The likely cause: `DialogueService.Choose` returns without notifying the client when the server has no session.

## 2026-10-16 — Quests, investigation, environmental puzzles, UI minigames (Phases 6–7 vertical slice)

**Built (owner approved `Quests, Puzzles and Minigames Proposal.md` with the recommended defaults):** the full framework plus one complete quest on a graybox site. All names, lines and numbers are placeholders / PROPOSALS.
- **Save schema 3** (additive migration): `Story = {Flags, Evidence, Deductions, Puzzles, Minigames}`, quest `Stage`, `Quests.Tracked`.
- **Quests** (`QuestService` + shared `Rensei.StoryLogic`): ordered stages, prerequisites, catch-up (evidence found before a stage still counts), optional / hidden objectives, outcomes per ending, item / codex rewards, repeatables with cooldowns. Still pays exactly once (the quest leaves Active before paying). New objective kinds: Inspect, Evidence, Deduce, Puzzle, Minigame, Mechanism, Flag.
- **Dialogue** (`DialogueService`): conditional openers (`Starts`), alternate node text (`Alt`), choices hidden or shown greyed with a reason (`Show = "Locked"`, e.g. "[Evidence: Small Boot Prints]"), new actions (SetFlag, GiveEvidence, GiveItem, StartMinigame, Signal). The server keeps the list of choices it showed, so a forged index can't reach a hidden or locked one. Story NPCs can wear a seeded nation look (`LookNation` / `LookGender` / `LookSeed`).
- **Investigation** (`InvestigationService`, `StoryService`): `RenseiInspect` points give evidence; the **Case Board** checks deductions on the server (wrong answers cost nothing).
- **Journal (J)** (`JournalUI`, built with the new `MenuKit` from the Settings art): Quests (stage text, Track / Abandon), Evidence, Case Board, Codex. The HUD tracker shows the current stage, tracked quest first.
- **Environmental puzzles** (`PuzzleService` + `PuzzleClient`): **per-player** mechanism states (steam vent, furnace mouth, lock stone, cracked seal, valve board, coal bins), doors that open per player, timed states that revert, permanent states saved. **Every alchemy path reacts:** any cast of that element near a mechanism (AlchemyService hook). **Every puzzle also has a non-alchemy route** (valves, carried coal, standing on the stone, the seal minigame).
- **Puzzle casts are free (PROPOSAL):** out of combat, a cast next to a mechanism that reacts to your element costs no meter (the meter only fills in fights).
- **UI minigames** (`MinigameService` + `MinigameUI`): **Pressure Board** (balance three valves, one bleeds pressure) and **Array Restoration** (turn geared rings until the marks meet the notch). Server-seeded, server-validated (it recomputes the gauge / replays the moves), retryable, no penalty for failing.
- **Graybox Foundry Yard** (`World.Map.FoundryYard`, south of the arena): walls, gate, vent corridor, furnace store, notice board, area discovery. NPCs Foreman Brask, Mirra, Tobin, Lise.
- **Quest "Chalk on the Foundry Wall"**: examine three chalk marks (one behind the steam vent) → question the night shift (Tobin lies until shown either of two clues) → open the furnace store ("fire in the mouth, weight on the stone", or mend the seal) → search it → Case Board → confront Lise: **report / keep the secret / teach** (confirmed, recorded once as `Outcome_chalk_foundry`). Plus the repeatable **Bounty: Ore Road Bandits** (5 bandits, 10 min cooldown).

**Tested (Studio Play, real key presses and clicks):**
- The whole quest end to end: E to talk to Brask and accept; E on each mark; the vent blocked the corridor (stopped at z 51.4); the Valve Board failed with the needle outside the green, then passed (vent saved as Sealed, steam and the invisible wall gone for that player); walked through; Tobin's lie broken with the boot prints; Mirra.
- **Alchemy route:** a real Ignite cast with 0 meter lit the furnace from 22 studs; standing on the lock stone opened the store; walked in through the door.
- **Array Restoration** solved by clicking the rings in (saved as Restored); forged minigame submits with no open session were ignored.
- **Case Board:** a wrong answer refused with a hint; the right one solved it. Lise: backing out at the confirmation recorded nothing; "Teach" completed the quest: +150 money, +550 EXP, both codex entries; 15 repeated signals paid nothing more; changing the ending afterwards was refused.
- Server checks (earlier pass): catch-up, stage gating, deduction gating, the bounty's cooldown. Console clean (client and server). The owner's save was snapshotted and restored after testing.

**Fixed while testing:** the NPC clones copied Vask's anchored crouch pose (they looked like they were lying down) — given a standing pose; the font drew "II" as a ligature (valves are numbered 1–3); bigger minigame buttons; inspect / mechanism prompts can sit on plain parts (dialogue distance check).

**Not verified:** two players at once (per-player states were designed for it but only one test client was available); restoring saved puzzle state after a real rejoin (Studio's DataStore calls were failing with HTTP 500 this session, so saves from Studio didn't persist).

## 2026-10-15 — Admin panel: switch alchemy

**Built (owner: "add switching alchemy to this panel"):**
- An **Alchemy** row on the Self tab and on the Players tab (for the selected player): `<  Flame  >  Set`, cycling None / Flame / Ice / Earth / Wind / Metal. It starts on the player's current path and shows "(now: …)".
- Server: `AdminService` command `SetAlchemy` writes the save's `Identity.Affinity` ("None" clears it), then `AlchemyService.PublishAffinity` and a profile sync, so the alchemy bar, mobile buttons and the Mastery tree switch straight away. Unknown paths are refused; every switch is in the admin log.

**Tested (Studio Play, real clicks):** Flame → Ice: the row read "now: Ice" and the slot bar showed Cryo Shift, Coldsteel Smash, Ice Shards, Absolute Zero. "Lightning" was refused. The owner's save was restored to its empty path (Studio's `StudioTestAffinity` fallback shows Flame). Console clean.

## 2026-10-15 — Admin panel; settings update

**Built (owner: "make a on theme admin panel using the ui assets that we have in game, also update the settings"):**
- **Admin panel (F2).** Built from the Settings panel's own art: frame, header plate (ADMIN), tab art, row plates, Enable/Disable buttons, the key-bind box as text inputs. Four tabs:
  - **Players:** pick a player, then Go To, Bring, Freeze/Unfreeze, Heal, Respawn, Kill, Spectate, Give Money, Give EXP, Give Item (cycler over `ItemData`), Kick with a reason.
  - **World:** spawn an enemy in front of you (cycler over `TuningConfig.Enemies`; admin spawns never respawn), Clear Spawns, Kill All, set the time of day, Announce (top-of-screen banner for everyone).
  - **Self:** God mode (DamageManager returns IFramed for `AdminGod`), Speed x0.5–4 (`SpeedMultiplier`), Heal Me.
  - **Logs:** the server's last 60 admin actions.
- **Permissions:** `ServerScriptService.AdminConfig` (server-only): Rensei group (206818864) rank ≥ 254, listed UserIds, and anyone in Studio. `AdminService` re-checks every call; non-admins never get the panel built.
- **Safety:** announcements and kick reasons go through `TextService` filtering; you can't kick yourself, and only a listed UserId can kick another admin; 0.2s between commands.
- **Allowed in combat:** `UIState.RegisterMenu` takes an `AllowInCombat` flag; the admin panel uses it. Other menus still lock in combat.
- **Settings update:** Combat Log (Gameplay); Post Effects, UI Animations, Field Of View 60–100° (Graphics); UI Sounds (Audio). Saved with the profile like the existing settings (`Rensei.Settings` defaults + validation).

**Tested (Studio Play):**
- The panel opened on F2 for the admin and matched the other menus (screenshots).
- Every command through the real remote: money, EXP, Apple (an unknown item refused), Freeze/Unfreeze, God on/off, Speed x2 and reset, time 18:00, enemy spawn and clear, announcement, an unknown command refused. The log listed all 13.
- Settings: Post Effects off disabled Bloom; back on restored it. FOV shows in degrees. Console clean on client and server.

**Fixed while testing:**
- Long admin lists ran past the frame; the list now clips and scrolls.
- **Rows re-animated every 2s** (owner report): the live refresh rebuilt every row and the motion layer popped each one again. Unchanged refreshes now do nothing, and rebuilt rows update in place; rows pop only on open or a tab change (verified: 7s idle, 0 rebuilds; Select rebuilt 10 rows, 0 pops).

**Note:** the command test wrote to the owner's live slot-1 save (+250 money, +50 EXP, +1 Apple), because Studio saves to the real DataStores.

## 2026-10-15 — Animated UI; combat-log badge

**Built (owner: "make all UI in the game animated", "a custom Combat log icon that pops up at the top of the screen when players are in combat ... who hit them and how long they have until they are out of combat"):**
- **`Modules.UI.UIMotion`**, started by UIHandler after every UI module:
  - Menus pop in (scale + slide) and settle out instead of snapping; the backdrop fades. `UIState.ToggleMenu` / `CloseMenus` use it.
  - Every button gets hover grow / press squish (touch gets a press punch). Buttons that already have their own UIScale (Fusion springs) are left alone.
  - List rows pop in, staggered, as menus build them (not in the HUD, whose lists refresh constantly).
  - HUD2 popups punch in, the banner drops from the top, the dialogue box rises, the HUD slides into place.
  - Settings: UI Animations off makes everything instant; UI Sounds off silences the menu sounds.
- **`Modules.UI.CombatLogUI`:** a badge that drops in at the top centre while you're in combat. It shows "IN COMBAT", who last hit you (or who you're fighting), a countdown and a draining bar; the icon jolts on every new hit and the timer pulses in the last 3s. It flashes "SAFE" and slides away when combat ends.
  - **Icon:** a white seated Truth figure with a big toothy grin and black arms, drawn from UI shapes on a transparent background. An uploaded image can replace it (`ICON_IMAGE`).
  - Server: `WorldService.MarkCombat` now also sets `CombatUntil` (server time), `CombatBy`, `CombatVs`, `CombatHitAt` on the player's character.

**Tested (Studio Play):** a Bandit hit the player: the badge read "IN COMBAT / Hit by Bandit" with the countdown; after combat it showed SAFE and hid. Stats menu open/close animated and restored cleanly; 56 buttons got hover motion. Console clean.

**Fixed while documenting:** UIMotion used weak-keyed tables with Instance keys (against the rule in ARCHITECTURE.md); they're plain tables now, cleared on `Destroying`.

## 2026-10-15 — Grip audit, grip styles, weapon dash attacks

**Grip audit (owner: "completely audit player behavior after gripping enemies, add different grips"):**
- After a grip, the gripper's parts kept the wrong `Massless` value and the HumanoidRootPart was left massless; both are saved and restored now. Walk speed and jump height are saved and restored too.
- **Grip styles** (`DownedManager.GripStyle`): **Classic** (paired, then the gripper steps clear), **Stomp**, and **Execution** (armed: the weapon's heavy, twice). Unarmed grips pick Classic or Stomp at random; the `GripStyle` attribute forces one.
- Tested: Stomp and Classic kept mass, speed and position correct afterwards.

**Weapon dash attacks (owner: "dash attacks for weapons to make them feel more custom"):** running + LMB with a weapon drawn uses that class's own dash attack (`TuningConfig.WeaponDashAttacks`, all numbers PROPOSAL):
- Sword **Rising Cut** · Rapier **Lunging Thrust** · Greatsword **Cleaving Charge** (hyper armour) · Daggers **Shadow Step** (2 hits) · Gauntlets **Shoulder Charge** · Guns **Pistol Whip**.
- `SkillData` generates `<Class>_DashAttack`; the Momentum Strike skill-tree bonus applies to all of them.
- Tested: Katana run attack → `Sword_DashAttack`, 26 damage on a Bandit. (Two earlier "misses" were the test setup: the camera faced away, and the passive Bandit wandered.)

**New animations (the "NEW RENSEI ANIMS" folder):** they're owned by another group ("gangsta bugs bunny"), so they don't load in Rensei's game. They need re-uploading under the Rensei group before they can replace placeholders. The carry IDs were tried and reverted.

## 2026-10-15 — NPC looks and weapons

**Built (owner: "randomize the fits of the npc ... respective to their nation", "spawn with the weapons that are in the character customization screen"):**
- Every enemy spawn rolls a nation, gender and outfit from the creator's assets (`Customization.RandomLook`).
- Each enemy gets one of the creator's starting weapons (`PickWeapon`; a spawn part's `Weapon` attribute overrides). Gunners keep 18 studs away and fire through the players' gun code.

**Tested:** looks varied per spawn; a gunner hit 12 × 12; a melee Bandit dealt 170 in 7s.

## 2026-10-15 — Mastery skill tree finished (Rello's plan, Tasks 6–8)

- **Movement effects:** parkour cost and wall-run time (JumpManager) and sprint speed (ClientHandler.Run) read their `SkillMods`.
- **Mastery menu (K):** `Modules.UI.MasteryUI`, built from the Inventory art: the tree on a circle canvas, a node card, and a ViewportFrame preview of the move. Buy and refund go through `Requests.SkillTree`.
- The temporary `TestHookScript` was removed (copy in backups).
- Tested: buying and refunding nodes, and the movement effects.

## 2026-10-15 — Character creator rebuild (Character Customization place)

**Built (owner: rebuild like the reference video on slide 12, keep hair IDs, add purchasable save slots, surname = clan):**
- **Save slots:** 2 free, up to 5 (Developer Product, 200 Robux PROPOSAL). Each slot is its own profile (`Data<UserId>` for slot 1, `Data<UserId>_S<n>`); the account store `RenseiAccounts` keeps owned / selected / favourite slots. Small star (favourite, listed first) and trash icons per slot.
- **Clans = surnames,** rolled with the deck's odds: Common 50 / Uncommon 28 / Rare 15 / Mythic 1 (Legendary is empty, so its share is spread), with pity. A Clan Index lists every clan's rarity and buffs. Rerolls come from packs (Developer Products) or codes (`ClanCodes`).
- **Look:** up to 3 hair IDs from the Roblox catalog (recoloured by the hair colour) plus preset hairs; a colour wheel with brightness and a "keep own colours" toggle; eyes / brows / mouth thumbnails; skin swatches.
- **Gender** changes the body (the owner's ROBLOX Girl torso for Female). **Nation** decides the starter outfit.
- **Weapon** step shows the weapon's stats card. The Alchemy step was removed.
- **Presentation:** rebuilt from the game's UI kit (panels, plates, rarity frames); an idle with an occasional clap; hold left-click on the character to turn it; the camera sits on `MenuStage.CameraMark` with the background streamed in.
- Ye's `DataManager` loads the selected slot (`SlotAccount.ProfileKey`).

**Tested:** slot buy/select/favourite/delete, the clan roll and index, creation, the colour wheel, ID hair tint, the female body, the reroll panel (bad codes refused), hold-to-rotate.

**Owner items:** the Developer Product IDs for slots and reroll packs are still 0; the Tutorial place still loads `Data<UserId>` instead of the selected slot.

## 2026-10-15 — Earth kit (20 of 20 alchemy slots); Rensei logo

**Built (the approved proposal, from the owner's own prototypes):**
- **Z Rising Thorn:** a spike at the aimed spot, under the first character the aim crosses: 55 + Bleed, knock-up.
- **X Tectonic Shift:** a ring of spikes, 85, stun 1.2s.
- **C Earth Wall:** solid, climbable cover for 6s that blocks projectiles; it lifts whoever stands there (30).
- **V Earth Pillars:** an unblockable line, 3 waves, 60 + 60 + 120.
- **VFX:** `Assets.VFX.EarthElement` from the prototypes' rock and spike meshes, sounds and crack decal. Rock takes the ground's colour and material.
- **Logo:** the owner's Rensei logo is on the main menu and in the intro cutscene. The decal 108616489098661 resolves to the image 130654945285755.

**Tested (Studio Play, dummies given 10,000 HP):**
- **Rising Thorn:** 55, then bleed 2 per 0.5s; the dummy was lifted to y 8.8.
- **Tectonic Shift:** 85 on the plain dummy, 17 chip on the blocking dummy.
- **Earth Wall:** the collider is in the right place, solid, and stops a projectile sweep; the lift hit deals 30.
- **Earth Pillars:** all four dummies (including the blocking and parrying ones) took 60 / 60 / 120 in order along the line, popped up 3 → 7 → 11.6.
- Screenshots of the ring, the wall and the pillars. Console clean.

**Fixed while testing:**
- Rising Thorn's aim passed through characters to the full range; it now stops at the first character.
- Earth Wall's lift dealt nothing (the wall is DEFENSIVE); the lift is now its own BLOCKABLE hit.

**Not verified by hand:** climbing the Earth Wall. The climb raycasts use `World.Map`, where the wall is, but the input tools couldn't steer a real climb.

## 2026-10-14 — Character creation and the start flow (three places)

**Built (owner: "Main Menu > Customize Character > Finish creating > Teleport to Tutorial world > Finish Tutorial > Cutscene > Main Game"; "Let players set their first name, gender, etc."):**
- **Character Customization place:**
  - A main menu in Rensei's style (Guru font, gold on black) and a 6-step creation screen with a live preview on a lit dais.
  - Steps: nation, first name (typed or random from the nation's list) / surname / gender, look (skin, 7 hairs, hair colour, 22 eyes, 8 brows, 25 mouths, 27 outfits, randomize), alchemy path (shows the 4 moves), starting weapon, confirm.
  - Server-validated and saved once; then PLAY goes to the Tutorial.
- **Tutorial place:** it loads the shared save, dresses the player, and sends players without a character to the menu. `ServerStorage.FinishTutorial:Fire(Player)` marks it done and goes to the main game.
- **Ye:**
  - `AppearanceService` dresses every spawn.
  - `FlowService` sends anyone who didn't come through the flow to the menu (live), and plays the intro cutscene once (placeholder).
  - The in-Ye `CreateCharacter` request was removed (copy in backups).
- **Registry** `Customization`: the owner's nations, palettes, face parts, outfits, hair meshes and name lists, all from the Assets place.

**Tested:** the full chain on one save. The character was made in the menu, finished the Tutorial, and arrived in Ye with the cutscene, the look, the Greatsword and the Earth path. Bad inputs were refused, every hair was checked on the head, and the console stayed clean.

**Fixed while testing:**
- Hair didn't attach on the client preview; it's now welded to the head.
- Coloured hair textures ignored the chosen colour; they're now left off.
- The stage didn't stream to the client; it's now Persistent.
- Step tabs were sorted alphabetically.
- Roblox's chat window covered the menu; it's hidden in the menu.

**Owner items:** see `Start Flow and Character Creation.md`: tutorial content, the real cutscene, publishing for the first live teleport test, and the template's data-wipe line for one player in Ye's DataManager.

## 2026-10-14 — Consumables heal; Earth + character creation proposal

**Built (owner request: "consumables should heal a little bit of health at a time"):**
- Hold an item from the hotbar (outside Combat Mode) and click to use it.
- The Apple heals **8% of max HP over 6s**, in ticks every 0.5s. There is 1s between bites, and it isn't eaten at full health (all PROPOSAL).
- Eating more adds to the heal still to come.
- Healing pauses while knocked.
- Each bite takes one off the stack. The last one leaves the inventory, and hotbar / equipped-weapon references shift to match.

**Tested (Studio Play):**
- At 940 max HP, one click healed +6.4 HP every 0.5s, 75 HP total.
- A second click within 1s was ignored.
- The stack went from 3 to 2.
- The last Apple was removed, the tool disappeared, and the equipped-weapon index followed the Katana.
- Console clean.

**Noticed:** Roblox's default health regen (the auto-inserted `Health` script, +1% of max HP per second) is active in Ye. Whether Rensei wants passive regen is an owner decision. It's untouched.

**Proposal written:** `Earth and Character Creation Proposal.md`.
- The Earth kit is mapped from the owner's prototypes: Rising Thorn, Tectonic Shift, Earth Wall, Earth Pillars, with sheet-style numbers as PROPOSAL.
- The character creation flow and data model build on the old build's nation system and the Assets-place customization parts.
- It ends with 10 decisions for the owner.

## 2026-10-14 — Weapons + inventory pass (A14)

**Changed (owner requests):**
- **Weapons come off the hotbar.** Click a weapon in the inventory to equip it, click again to unequip.
  - The choice is saved (`EquippedWeapon`) and given back on every spawn.
  - A save with a weapon on the hotbar is migrated: it's taken off and becomes the equipped weapon.
  - The equipped weapon shows a gold "E" and highlight; the tooltip says what a click will do.
- **Heavies inside the M1 string.** R during a swing queues the heavy; it comes out as soon as that swing ends, with no cancel. It also works while LMB is held. R no longer feints (RMB does).
- **Full M1 string on whiffs.** Holding or clicking into the air plays Light 1–4 instead of repeating Light 1.

**Fixed:**
- **"Character moves weird after unsheathing":**
  - The Katana/Rapier draw animation keyed both legs at Action2, so the legs froze and slid for about a second on every draw or sheathe. The leg keys were removed; the walk cycle keeps playing under the draw.
  - After a respawn, no animations loaded at all (the client read `Humanoid` before it existed), so everything moved wrongly until rejoining. It now waits for the Humanoid and Animator.
  - The climb error from the report (`ClimbAction` concatenating nil when Space was pressed during a ledge pull-up) no longer happens.
- **Weapons not lined up:** the sheathed Katana/Rapier hung straight through the right arm, and the Daggers were loose (one outside the left arm, one sticking out sideways). Holsters are now left hip (katana / rapier), crossed on the lower back (daggers), back (greatsword, unchanged) and right thigh (pistols, unchanged). The drawn grips were already in the fist.
- Inventory tooltip went stale after a click; the hotbar highlight and gun tracers could pick the weapon Tool instead of the held item.
- The old unused `HotbarUI` module was removed (copy in backups).

**Tested (Studio Play):**
- Equip, swap and unequip across Katana, Greatsword and Revolver; Apple onto the hotbar.
- A weapon forced onto the hotbar can't be held.
- The Apple is held beside the holstered weapon and put away when Combat Mode turns on.
- The weapon comes back after a respawn, and the migration moved the Katana off hotbar slot 1.
- Real clicks: inventory equip, the Potions tab, search ("app" / no match / cleared).
- Held M1 played the whole string into the air: Sword and Greatsword Light 1–4, then looped.
- M1 + R played Light 1, Light 2, then the Heavy straight away, then Light 3, Light 4. This worked both while holding LMB and while clicking, armed and unarmed.
- Walking while drawing kept the walk cycle on the legs.
- Respawn: animations loaded and the console stayed clean.
- Screenshots of every holster and of the drawn grips.

**Follow-up (same day):** consumables heal. See the entry above.

## 2026-10-14 — Mobile controls (A12)

**Built:**
- A touch control cluster in Rensei's slot-plate art.
- `ClientActions`: the keyboard and the touch buttons now run the same functions. ClientHandler was refactored onto it with no behaviour change.
- Touch-aware climbing and wall running in JumpManager: the thumbstick acts as WASD, and holding Jump acts as holding Space.

**Tested (Studio Play, ForceMobileControls):**
- Geometry: 16 buttons, no overlaps, none under the leaderboard, none off-screen, the thumbstick half kept clear.
- Fight turned on Combat Mode.
- Attack → Light1; Heavy → heavy; Block → parry window.
- Dash reached 98 studs/s; Jump peaked 7 studs up.
- Holding Z held the clap (2.35s cast vs 1.0s for a tap) and cost 25 meter.
- Turning it off restored the desktop alchemy bar and the Server panel.
- **Keyboard regression after the refactor:** E, F, R, M1 and Z all still work.
- Console clean.

## 2026-10-14 — Wind and Metal kits (all four designed kits complete)

**Built:**
- **Wind:** Air Slash, Gale Burst, Rising Wind, Tempest Break.
- **Metal:** Steel Guard, Crushing Anvil, Metal Bind, Alloy Divider.
- New `ShieldManager` and true damage.
- `WindElement` / `MetalElement` VFX, plus three uploaded wind textures.
- Placeholder animations.

**Tested (Studio Play):**
- **Air Slash:** 50, windup 0.92s.
- **Gale Burst:** 25 / 25 / 35 with stuns, push 24 studs; a blocking dummy took chip only.
- **Rising Wind:** 70; target and caster launched 11 studs.
- **Tempest Break:** 60 / 60 / 115 (= 235) to every dummy, through block and parry; lifted, then thrown up to 18–26 studs.
- **Steel Guard:** 4 frontal hits absorbed, the 5th broke it and ended the stance; a hit from behind landed; Coldsteel Smash shattered it and landed 110.
- **Crushing Anvil:** homed onto an off-axis target: 100.
- **Metal Bind:** 75, pinned 0.98s (walk speed 0, stunned), then released.
- **Alloy Divider:** 300 through a 20% resist buff; windup 2.42s (clap + slam + 1.2 cast + 0.4 delay).

**Fixed while testing:**
- Tempest Break's last hit missed lifted targets (sphere check); it now uses a column.
- Crushing Anvil turned too slowly to reach close targets (220°/s → 540°/s, plus a passed-by check).

## 2026-10-14 — Ice kit; climbing and combat bug pass; full audit

**Ice kit (A9):**
- Cryo Shift (counter), Coldsteel Smash (ice greataxe), Ice Shards (trap), Absolute Zero (area freeze).
- New `CounterManager`, damage-resist window, `IceElement` VFX, six Ice effects.
- Placeholder animations.

**Tested (Studio Play):**
- **Cryo Shift:** countered a light hit (no damage taken); the attacker took 40 and was frozen 1.55s; the next hit did 13.6 instead of 17 (20% resist).
- **Coldsteel Smash:** 110, then frozen 0.66s; windup 1.54s; full 0.5s recovery.
- **Ice Shards:** the trap sprang when the Dummy stepped in: 30 and frozen 1.57s.
- **Absolute Zero:** 200 to all four training dummies, straight through block, parry and perfect-parry; frozen 3.03s.

**Fixes found while testing:**
- Scorching Wave and Inferno Lance never applied their burn (it was configured but unused). Both now burn (2×5 verified).
- Inferno Lance missed targets more than ~8 studs away because the server sees the client's dash late. The hitbox now sweeps the whole dash; verified from 11 studs: 85 + burn.

**Climbing (owner report: "super bugged"):**
- Grab reach 3 → 5.
- Mantle onto the top instead of a launch; verified: you stand on top at the right height.
- New ledge pull-up; verified on an 11.5-stud block.
- Cleaned climb poses (they used to twist the body away from the wall).
- No fall animation under the hang; no stuck hang pose.
- Black arm cloud and duplicate attachments removed.

**Combat:**
- Enemies no longer hurt each other.
- Enemies spread out instead of stacking; first version froze them in place, fixed and re-tested: all three attack.
- Elite parries restored (verified).
- Feint queue for network ordering.
- Verified: 4-hit M1 combo, held M1 chain, heavy, feint, block chip (2.7–4.0), dash in all four directions.

**Audit:** see `Audit 2026-10-14.md`. 248 scripts syntax-checked (no errors); 13 debug prints removed; an unused PlayerModule copy moved out of StarterCharacterScripts. The console is clean in Play.

## 2026-10-14 — Status effects; parry while getting hit

**Built:**
- **Status effects** (`StatusManager` + `Effects.Status.StatusVFX`), using the owner's Status Effects VFX (Fire, Freeze, Bleed, Shock), copied from the Assets place.
  - Burn: damage ticks. Freeze: stunned, rooted, pose locked, ice glaze. Bleed: damage ticks. Shock: damage ticks plus jolt stuns.
  - Refresh instead of stacking; ended by death or knock.
  - Alchemy burns and the daggers' bleed now go through it. The old Burning effect is retired.
- **Parry while getting hit (owner request):** a fresh F press in hitstun opens the parry window for 10 posture (PROPOSAL) and always starts the 1.3s cooldown (PROPOSAL). Holding F raises the guard when the stun ends.
  - Only a real key press parries now; the hold-to-re-guard retry never opens a window.

**Tested (Studio Play):**
- **Burn:** 5 damage every 1.0s, 4 ticks.
- **Freeze:** walk speed 0, stunned, restored afterwards (Grunt 14, player 12). A hit while frozen didn't free the player.
- **Shock:** 3 jolt stuns plus ticks in 1.5s.
- **Bleed:** daggers hit → 3 ticks of 2 at 0.5s intervals.
- **Visuals:** welded on every client, then cleaned up (screenshot checked).
- **Hit-parry (real F presses during a hit stun):**
  - Window opened mid-stun; posture 100 → 90; the next hit was **PerfectParried** and the attacker stunned.
  - The cooldown stayed after the landed parry.
  - A second press on cooldown did nothing and cost nothing.
  - With F held, the guard came up 0.12s after the stun ended.
  - Guard-broken: no window.
- No console errors.

## 2026-10-14 — Flame kit complete

**Built:**
- **Scorching Wave (X):** cone.
- **Inferno Lance (C):** burning dash with i-frames.
- **Phoenix Drive (V):** flying phoenix, crash + burn, delayed explosion.
  - Unblockable, so its landing spot gets a red danger ring for everyone.
  - The alchemy circle opens under the caster.
- **Visuals:** all built on the owner's FireElement VFX (cone fire, ground impact, dash burst, phoenix model, explosion).
- **Release rule (owner):** projectile moves use Clap → **Arm Extend** → animation; Ignite switched to it. Ground and body moves keep the Ground Slam.
- **New shared effects:**
  - `Burst`: plays any authored VFX part with its own EmitCount/EmitDelay;
  - `Phoenix`, `Warning`, `Sigil`.

**Tested (Studio Play, real key presses, against passive Bandits):**
- **Scorching Wave:** hit the grunt inside the cone for 90 at 1.72s. The grunt outside the cone took nothing. Meter 100 → 65.
- **Inferno Lance:** 85 the moment the dash starts; 12.8-stud dash in open space; stops on contact.
- **Phoenix Drive:**
  - Danger ring at 0.55s; crash 70 on both grunts in range, explosion 170 0.8s later, burn 4×5. That's 260 total, matching the sheet.
  - A steeply downward aim still lands 12 studs out.
- **Ignite:** confirmed Clap → Arm Extend → throw.
- **Cleanup:** every effect cleaned up; no console errors.

## 2026-10-14 — Alchemy cast flow, Fire VFX, slot bar, combat fluidity

**Built:**
- **Alchemy cast flow:** clap (holdable) → ground slam → the move.
  - Uses the owner's group animations: Clap, Clap loop, Ground Slam, Arm Extend, Fire 1–5.
  - The prelude is part of the attack's startup, so stuns cancel it.
- **Custom transmutation circle:** a new texture, uploaded as `rbxassetid://132299053523633`.
  - Unfolds and spins in front of the hands on the clap; bursts on the slam.
- **Ignite rebuilt on the owner's FireElement VFX** (copied from the Assets place): hand fire, fireball, impact burst, burn.
- **Alchemy slot bar** (Z/X/C/V) like Devil Hunter's, shown once a player has an alchemy path.
- **Combat fluidity matched to Devil Hunter's code:**
  - light hitstun 0.45 → 0.6s; combo reset 1 → 2s;
  - walk speed swinging 6 → 14, heavy 4 → 11, blocking 5 → 12, stunned 0 → 4;
  - holding F re-raises the guard.
- **Shift-lock dash fix:** dashing sideways while sprinting in shift lock used to forward-roll. Dashes are now camera-relative and keep facing the camera.

**Tested:**
- Tap cast and held-clap cast (timelines logged).
- A stun during the held clap cancels cleanly.
- All 8 dash directions while walking and sprinting.
- Guard break with F held: the guard returns 0.2s after the stun ends.
- Slot bar visible, with cooldown and dimming.
- No console errors.

## 2026-10-14 — Alchemy vertical slice (master plan Phase 2)

**Built:**
- `AlchemyService`, Requests.Alchemy, Z/X/C input, V Ultimate fallback after Carry.
- Flame Z Ignite: server-swept projectile, burn, telegraph, banner feedback.

**Tested:**
- Normal cast; no meter; cooldown; Combat Mode off; malformed input; 5 casts in one frame (one charge).
- Interrupted cast; block from the front and the back; wall impact; range fizzle; no leftover effects.

## 2026-10-14 — Weapon position audit

**Built:**
- Grip re-solves; hold poses; greatsword shoulder carry and heavy feel.
- Hand-built holsters; HolsterWeld plus a client-side swap blend (no more snapping).

**Fixed:**
- Weak-table Instance keys lost tool joints (and could freeze hitstop or lose carry welds). Replaced across 6 modules.

**Also:**
- Group animations wired: Uppercut, Greatsword Run, Gun Idle.

## 2026-10-14 — Bug/feel pass

- Devil Hunter parry, M1 click buffer, hitstop overlap fix, holdable-skill state fix.
- Crit telegraph, wall-run chaining, directional climb, live stats polychart, UI readability pass.

## 2026-10-13 — Combat commission phases A1–A6

- Combat core, Devil Hunter feel pass, six weapons, PvE (Dummy/Grunt/Elite), downed actions, parkour, and the full UI rebuild from the PSDs.
- Master plan Phase 1: data contracts, ProfileData schema v1, ProgressionService, exploit fixes.

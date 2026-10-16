# Start Flow and Character Creation

**Status:** built and playtested in Studio, 2026-10-14. Live teleports can't be tested in Studio (see "Not testable in Studio").

## The flow (owner, 2026-10-14)

**Main Menu → Customize Character → Finish creating → Tutorial world → Finish tutorial → Cutscene → Main game**

| Step | Place (experience 9509447316) | What happens |
|---|---|---|
| Main menu + creation | **Character Customization** (123967384111466) | Main menu (PLAY). A new player creates their character; a returning player continues to their next step. |
| Tutorial | **Tutorial** (74257385894576) | The player arrives in their created look. The tutorial's own content ends it with `ServerStorage.FinishTutorial:Fire(Player)`. |
| Cutscene + game | **RSEI / Ye** (106992859583940) | The intro cutscene plays once on first arrival (placeholder until the owner's cutscene exists), then the main game. |

All three places share the ProfileService store `PlayerData`. Since 2026-10-15 each **save slot** is its own profile: `Data<UserId>` (slot 1) or `Data<UserId>_S<n>`, chosen in the menu and recorded in the account store `RenseiAccounts` (`A<UserId>`: Owned, Selected, Favorite, Receipts, Codes). The session lock hands the profile from place to place; each place releases it just before teleporting. Every place loads the selected slot (`SlotAccount.ProfileKey`; the Tutorial since 2026-10-16) and kicks rather than guess slot 1 if the account store can't be read. Every flow teleport goes through `FlowTeleport` (retries, then reloads the profile or kicks; Changelog 2026-10-16 "Teleport + save audit").

**Routing** (live only; Studio never teleports):
- The menu sends PLAY to `Places.NextFor(profile)`: Customize if there's no character, the Tutorial if it isn't done, otherwise the main game.
- The Tutorial sends a player with no character to the menu.
- Ye sends anyone who didn't arrive through the flow (direct join, rejoin, old save) to the menu, which then routes them. So **players always start at the main menu**, whichever place is the experience's start place.

## Character creation (menu place) — rebuilt 2026-10-15

Rebuilt after the reference video on the design deck's slide 12, from the game's UI kit (panels, plates, rarity frames):
- **Save slots:** 2 free, up to 5 (`Rensei.Slots`: Free 2, Max 5, Price 200 PROPOSAL, Developer Product id still 0). Star = favourite (listed first), trash = delete (the profile is wiped).
- **Facial:** up to 3 Roblox catalog hair IDs (recoloured by the hair colour; their own texture is stripped), preset hairs, eye / brow / mouth thumbnails.
- **Traits:** nation (card with a blurb; decides the starter outfit, `Customization.OutfitFor`), gender (Female uses the owner's ROBLOX Girl torso), a hair colour wheel with brightness and "keep own colours", skin swatches.
- **Weapon:** the starting weapon with its stats card.
- **Finalize:** first name (suggestions from the nation's list); **surname = clan**, rolled with the deck's odds (`Rensei.Clans`: Common 50, Uncommon 28, Rare 15, Mythic 1; Legendary has no clans yet so its share is spread; pity 20 / 30). The Clan Index lists every clan with its rarity and buffs. Rerolls: packs (Developer Products, ids still 0) or codes (`ServerScriptService.ClanCodes`). A summary card framed by the clan's rarity.
- The **Alchemy** step was removed (owner request).
- The preview rig idles with an occasional clap; hold left-click on it to turn it. The camera sits on `Workspace.MenuStage.CameraMark`; the server sets `ReplicationFocus` so the background streams in.
- Server calls (`MenuServer`): Slots, Open, State, Hair, RollClan, Redeem, Favorite, Delete, Create, Play; `ProcessReceipt` for slots and reroll packs.

### The original six steps (2026-10-14, superseded)
1. **Origin:** one of the owner's six nations (Amestrian, Xingnese, Ishvalan, Xerxian, Aerugonian, Drachman). It sets the default skin, hair colour, eyes and outfit. Cosmetic only.
2. **Identity:**
   - **first name**: typed, or RANDOM from the nation's name list (the owner's old lists);
   - **surname**: optional, typed;
   - **gender**: Male / Female.
   - Typed names pass Roblox's text filter on the server.
3. **Look:**
   - skin (8);
   - hair (7: Bald, Short, Spiky, Anime, Pixie, Swept, Ponytail);
   - hair colour (8);
   - eyes (22), eyebrows (8), mouth (25);
   - outfit (27).
   - RANDOMIZE LOOK. Drag the character to turn it; the camera moves in for the face.
4. **Alchemy path:** Flame / Ice / Earth / Wind / Metal, with each path's Z/X/C/V moves shown.
5. **Starting weapon:** Fists, Katana, Rapier, Caestus, Greatsword, Daggers, Renetti, Sykov. It is added to the inventory and equipped.
6. **Confirm:** a summary, then BEGIN. A character can't be remade afterwards.

**Server validation** (`MenuServer`):
- Every choice is checked against `Modules.Data.Rensei.Customization`.
- Unknown appearance ids fall back to the nation default.
- Creation happens once per profile.
- No paid mechanics. The clan roll stays hidden until a roster exists.

**Saved:** `Identity` = `CharacterCreated`, `Origin`, `FirstName`, `LastName`, `Name`, `Gender`, `Affinity`, `Weapon`, `Appearance` {Skin, Hair, HairColor, Eyes, Brows, Mouth, Outfit}. Also `Flow` = {TutorialDone, IntroSeen}.

**The look in game:** `AppearanceService` builds it on every spawn in Ye and the Tutorial: face decals, the hair welded to the head's HairAttachment, skin, outfit, and the name over the head. The hair meshes' own textures are left off, so the chosen hair colour applies.

## Where things are

| Place | Scripts |
|---|---|
| Menu | `ServerScriptService.MenuServer` (MenuRemote: State / Create / Play), `MenuData` (+ ProfileService), `StarterPlayerScripts.MenuClient` (UI + preview), `Workspace.MenuStage` (Persistent), `ReplicatedStorage.PreviewRig` |
| Tutorial | `ServerScriptService.TutorialServer`, `FlowData` (+ ProfileService), `AppearanceService`; `StarterPlayer.StarterCharacter` = R6 like Ye |
| Ye | `ServerScriptService.FlowService` (routing + cutscene), `AppearanceService`, `Modules.UI.IntroCutscene` (placeholder) |
| All | `Modules.Data.Rensei.Customization`, `Places`, `Modules.Data.ProfileData` |

**Shared modules are copies**, kept in sync from Ye (the source of truth): `Customization`, `ProfileData`, `Places`, `Slots`, `AppearanceService`, ProfileService, and the server modules `SlotAccount`, `ProfileMigrations` and `FlowTeleport`.
- When one changes, copy it to the other places.
- Long term, turn these into Roblox **Packages** so they stay in sync automatically.

## Tested (Studio Play)

- **Menu:**
  - It loaded the profile and showed "Create your character".
  - A full real-click run: Xerxian → typed "Kael" + "Varrow" (passed the filter) → Female → Ponytail + Xerxian Garb 2 → Earth → Greatsword → BEGIN.
  - The character saved, and PLAY routed to the Tutorial.
- **Tutorial:** the same profile arrived dressed as "Kael Varrow" (outfit, hair, face). `FinishTutorial` saved `TutorialDone` and routed to the main game.
- **Ye:** the cutscene placeholder played with the name; the Greatsword was equipped and the Earth path set.
- **Validation:** a bad nation, a bad name, a bad path, a non-Common weapon and a second creation were all refused.
- All seven hair styles were screenshot-checked on the head.

## Not testable in Studio

- **Teleports:** Studio says where a teleport would go instead of making it. The first live test needs the places published (owner).
- **Start place:** the experience is private, so which place players join first couldn't be checked. The routing works either way. If RSEI is the start place, new players briefly load into it before going to the menu. Making the menu place the start place would remove that hop.

## Open items for the owner

- **The tutorial's content:** Drillmaster Vask and the Gate of Truth exist. The tutorial needs to call `FinishTutorial` when done.
  - Ye's combat and alchemy systems aren't in the Tutorial place. If the tutorial teaches combat, those systems need to be shared (Packages are recommended).
- **The real intro cutscene:** it replaces `IntroCutscene.Play`.
- **ProfileService** is an old standalone version without `AddUserId` (GDPR user ids). Upgrading it, or moving to ProfileStore, would add them.
- **The Tutorial's `Customization` copy is older than Ye's and the menu's.** Newer looks may not dress correctly there until it is synced.
- **Publishing** the three places (owner; never done by Claude).

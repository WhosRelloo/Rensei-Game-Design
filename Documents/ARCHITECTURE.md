# Rensei Architecture — where everything lives in Ye

Ye (placeId 106992859583940) started as a JJK-style WCS combat template with Rensei's UI on top. It has been extended system by system. The source of truth is the place itself; this is the map. Updated **2026-10-18**.

## Data and configuration — `ReplicatedStorage.Modules.Data`

- **`Rensei.TuningConfig`:** every combat number (controls doc: "TuningConfig.lua for all numbers"). Invented values are labelled PROPOSAL; values from Devil Hunter's code are labelled DH.
  - Light, Heavy, Uppercut, Aerial, DashAttack, Block, Parry, Dash, Hitstop, HitStun.
  - Parkour, Feint, Weapons, Alchemy, Downed, Enemies.
  - `WeaponDashAttacks`: per-class overrides of DashAttack, merged into `Weapons.<Class>.DashAttack` (→ SkillData `<Class>_DashAttack`).
  - **`Traversal`** (MovementState validation and re-check numbers), **`LedgeWalk`**, **`Styles`** (per-class style combat numbers), **`ClassSkills`** (class-skill moves; `LungeStopAt` ends a rush at its target), **`Swim`** (swim state, sprint, breath, drowning). All PROPOSAL.
- **`Rensei.Styles`:** weapon styles per class (`Fists` = bare hands: Base "Brawler", Boxing, Lethwei; every other class: Base). Base is always learned; other styles are taught by a style trainer (dialogue action `UnlockStyle`, profile `StyleUnlocks`). Helpers `ClassOf`, `Valid`, `Selectable`, `Unlocked`, `Saved`, `Active`, `Tuning`.
- **`Rensei.ClassSkills` / `Rensei.SkillTree`:** class-skill nodes (the Mastery tree's Class column), the 4-slot loadout per family (profile `SkillLoadout`).
- **`Rensei.Alchemy`:** the alchemy ability registry. Rows copied from the design sheet: damage, cooldown, cast, class, extras.
- **`Rensei.Stats` / `Progression` / `Formulas` / `Clans` / `Settings`:** stat definitions, level curve, damage/HP formulas (approved spreadsheet scale), clans (the Marcoh rule), settings defaults.
- **`SkillData`:** hit definitions, *generated* from TuningConfig. Names: `Light1-4`, `Heavy`, `<Weapon>_Light1..`, `<Weapon>_Heavy`, `<Weapon>_Skill`, `Alchemy_<Id>`.
- **`ProfileData`:** profile template (SchemaVersion 1). `DataManager` (ServerScriptService.CharacterHandler) runs Migrate before Reconcile.

## Other places (one experience, 9509447316)

- **Character Customization (123967384111466):** the main menu and character creation. **Tutorial (74257385894576):** the tutorial step. Both share Ye's save. See `Start Flow and Character Creation.md`.
  - Creator (2026-10-18): `StarterPlayerScripts.MenuClient` (FACE / BODY camera, undo / redo, random, reset), `Modules.Data.Rensei.CreatorPlus` (Game Pass config; `PassId` 0 = not on sale), `ServerScriptService.LookPresets` (saved looks, DataStore `RenseiLooks`; memory only in Studio). `MenuServer` checks the pass for custom skin colours and saved looks.
  - `Customization` is kept identical in every place: a skin may be a preset id or 6 hex digits (`SkinColorOf`, `IsCustomSkin`); `StartWeapons` is the creator's six, `CommonWeapons` all eight (enemy spawns).

## Server — `ServerScriptService`

- **`ServerHandler`:** routes `Remotes.RequestRemote(Module, ...)` to `ServerHandler.Requests.<Module>`, behind a token-bucket rate limiter. Starts the services.
  - Requests: Stat, Gate, Sync, Party, Quest, Dialogue, Settings, Equip, HoldItem, CombatMode, Uppercut, Feint, JumpAttack, WeaponSkill, Aim, Downed, **Alchemy**, **SkillTree**, **ClassSkill**, **Style**, **Shoot**, **Swim**.
  - **JumpRemote** (rate-limited, allowed list `PlayFX` / `ClimbState` / `TraversalState` / `ParkourStamina`): `ClimbState` → `MovementState.Request` (validated); `PlayFX` → only the allowed movement effects, with checked arguments and a per-type throttle (`TuningConfig.Traversal.FXMinInterval`).
  - `Requests.CombatMode` refuses to turn Combat Mode on while swimming.
- **`StyleService`:** sets the character attribute `Style` from the save on every spawn and weapon change; `Select` (Requests.Style) validates a switch (learned, right class, out of combat, free to act).
- **`SwimService`:** deep water → the server's `Traversal = "Swim"` state (players and EnemyService rigs). Swim sprint stamina (`SwimSprint`), breath (`Breath`) and drowning (`Drowning`, damage through `DownedManager.Damage`) for players. The enemy brain doesn't attack, cast, block or parry while swimming.
- **`AdminService` + `AdminConfig`:** the admin panel's server side. `Remotes.AdminRemote` (RemoteFunction): `"State"` and `"Run", Command, UserId, Arg`. Every call re-checks admin status; announcements and kick reasons are text-filtered; actions are logged (last 60) and printed. `AdminConfig` (group rank, UserIds, Studio) stays server-only. Admins get the `Player` attribute `RenseiAdmin`.
- **`SlotAccount`:** save slots. Account DataStore `RenseiAccounts`, key `A<UserId>` = {Owned, Selected, Favorite, Receipts, Codes}; `ProfileKey(UserId)` = `Data<UserId>` for slot 1, `Data<UserId>_S<n>` otherwise (DataManager loads it).
- **Quests / story (2026-10-16):**
  - **`QuestService`:** staged quests (`Rensei.Quests`, rules in `Rensei.StoryLogic`, shared with the client). Progress only via `Signal(Kind, Target)`; `CatchUp` fills objectives already true; completion leaves Active before paying; outcome rewards from flag `Outcome_<QuestId>`.
  - **`StoryService`:** the only writer of profile `Story.Flags` (never overwritten unless asked), `Story.Evidence`, `Story.Deductions`.
  - **`InvestigationService`:** parts / models tagged `RenseiInspect` (+ `InspectId`) get an Inspect prompt (text via `DialogueService.Say`); Case Board deductions (`Requests.Investigation` → UI event `CaseResult`). Content: `Rensei.Investigation`, `Rensei.Evidence`.
  - **`PuzzleService`:** PER-PLAYER mechanisms tagged `RenseiMechanism` (+ `MechanismId`), puzzles and doors tagged `RenseiPuzzleDoor` (+ `PuzzleId`). `Remotes.PuzzleRemote` sends a player only their own states. `AlchemyService` calls `React` when a move goes active (and waives the meter out of combat near a reacting mechanism). Permanent states saved as `Story.Flags["Mech_<Id>"]`. Content: `Rensei.Puzzles`.
  - **`MinigameService`:** server-seeded, server-validated minigames over `Remotes.MinigameRemote` (Pressure Board, Array Restoration). Content: `Rensei.Minigames`.
  - **`DialogueService`** extensions: `Starts` / `Alt` / choice `Requires` + `Show = "Locked"`; actions SetFlag, GiveEvidence, GiveItem, StartMinigame, Signal; NPC looks from `LookNation` / `LookGender` / `LookSeed`.
  - **`ItemService.Give(Player, Name, Amount)`** for rewards.
  - Graybox content: `Workspace.World.Map.FoundryYard`, NPCs in `World.NPCs`.
- **`SkillTreeService`:** Mastery node purchases and refunds (`Requests.SkillTree`); effects are read through `Managers.SkillMods` (`Mod_<Key>` attributes).
- **`ServerScriptService.AppearanceService`:** builds the created look on every spawn (`ApplyIdentity`, called by CharacterHandler).
- **`ServerScriptService.FlowService`:** start-flow routing (live: anyone not arriving through the flow goes to the menu) and the one-time intro cutscene (`IntroRemote` → `Modules.UI.IntroCutscene`).
- **`Modules.Data.Rensei.Customization` / `Places`:** the creation registry (nations, palettes, face, outfits, hair, names, genders) and the place ids + `NextFor`. Copies of these live in the other places.
- **`ServerScriptService.ItemService`:** using held items (`Tool.Activated`, hooked by Requests.HoldItem). Healing items heal over time (ItemData `Heal` = fraction of max HP, `HealTime`). Each use takes one off the stack; `RemoveIndex` removes an empty stack and shifts the hotbar / equipped-weapon indices.
- **`ServerScriptService.LoadoutService`:** the equipped weapon. Weapons are equipped from the inventory (`Requests.Equip` routes weapons here), never the hotbar. Saved as profile `EquippedWeapon` (inventory index, "" = fists) and given again on every spawn (`Restore`, called by CharacterHandler). Old saves with a weapon on the hotbar are migrated on spawn.
- **`ProgressionService`:** the only writer of stats, EXP, Mastery Points and Truth/Gate. Records hits (training), and writes the character multipliers PhysicalMultiplier, AlchemyMultiplier and SpeedMultiplier.
- **`AlchemyService`:** alchemy casting (kinds: Projectile [Visual Fireball/AirSlash], Cone, Lunge, Phoenix, Counter, Melee, Trap, Nova, Burst, Tornado, Shield, Tracker, Thrust, Cleave; on-hit statuses via `ApplyOnHit`; windup = sheet Cast + CastDelay) (validation, meter, cooldown, clan rule, clap → slam → move prelude, projectiles, cone / lunge / phoenix). Burns go through `StatusManager`. Publishes the `Player` attribute `Affinity`.
- **`EnemyService`:** PvE spawns (parts tagged `RenseiEnemySpawn`), Grunt/Elite AI using the players' combat rules.
  - Each spawn rolls a look (`Customization.RandomLook`: nation, gender, outfit) and a weapon (`PickWeapon` from `Customization.CommonWeapons`, guns included; the spawn part's `Weapon` attribute overrides). Gunners hold 18 studs.
  - Alchemist enemies cast through `AlchemyService.CastAs` (the same cast as a player's). Rig attribute `AIPassive` = chase and defend, never attack.
  - `EnemyService.Spawn(Part)` is public (the admin panel uses it with an untagged part).
- **`WorldService`:** areas, kill credit, and the combat lock: `InCombat`, plus for the combat-log badge `CombatUntil` (server time), `CombatBy`, `CombatVs`, `CombatHitAt` on player characters.
- **`UIService`:** server → client UI events (Toast, LevelUp, Area, Party, Dialogue…).
- **`PartyService`, `QuestService`, `DialogueService`:** frameworks wired; quest and dialogue content are empty on purpose.
- **`CharacterHandler`:** WCS server, dummies, DataManager.

## Shared managers — `ReplicatedStorage.Modules.Managers`

- **`AttackRunner`:** the attack state machine Startup → Active → Recovery.
  - Publishes `CombatState` / `CombatAttack`; stun cancels; feint; hyper armour.
  - Optional **Prelude** (variable-length lead-in, used by the alchemy clap).
  - Runs in its own thread so released holdable skills can't strand state.
- **`HitboxManager`:** server-side box sweeps every frame of the active window; validated client hitboxes.
- **`DamageManager`:** resolves a hit.
  - Classes BLOCKABLE/PARRYABLE/UNBLOCKABLE; block (facing the attack's source) and parry; posture.
  - Stun, knockback types, hitstop, meter gain, weapon passives.
- **`StatusManager`:** status effects (Burn / Freeze / Bleed / Shock). `Apply(Victim, Name, {Duration, Every, Damage, Mult})` refreshes, ticks damage, freezes and jolts; it shows `Effects.Status.StatusVFX` and sets the `Status<Name>` attribute.
- **`CounterManager`:** reactive counters (Cryo Shift). `Open(Character, Duration, Handler)`; DamageManager hands the first non-UNBLOCKABLE hit to the handler and returns "Countered".
- **`ShieldManager`:** damage-absorbing shields (Steel Guard): `Open(Character, {Duration, Absorb, Arc, OnAbsorb, OnBreak})`; DamageManager returns "Shielded".
- **`DownedManager`:** all combat damage goes through `DownedManager.Damage`. Knocked state, Grip, Carry.
  - Grip styles (`GripStyle`): Classic (paired), Stomp, Execution (armed); the gripper's `Massless`, WalkSpeed and JumpHeight are saved and restored.
  - `DamageManager` also returns IFramed for a victim with `AdminGod`.
- **`WeaponManager`:** weapon tools.
  - Server: grip Motor6Ds; HolsterWeld while holstered; draw/sheathe; guns; passives.
  - Client: hold, idle and carry poses; the holster↔hand blend.
- **`ResourceManager`:** Stamina, Posture, Meter. Attributes are computed so clients can read them for free.
- **`AnimationManager`:** server → client animation playback.
  - Unpublished KeyframeSequences (`Animation` with an empty id + a `Save` child) register in Studio only.
  - Hitstop freeze.
- **`MoverManager`:** velocity, look-at, lunge, hover, dive and knockback movers. `Movement()` handles walk-speed windows. `Lunge` stops at walls, and optionally (`StopAt`) at a character in front.
- **`JumpManager`:** jump, climb (directional), wall run; `JumpManager.LedgeWalk` is the authored-ledge walk (parts tagged `RenseiLedge`).
- **`MovementState`:** the server-owned traversal state.
  - **Attributes:** `Traversal` (`Climb` / `WallRun` / `LedgeWalk` / `Swim`) and `TraversalSession` (`"<seq>:<kind>:<reason>"`, atomic).
  - **Who changes it:** clients ask through JumpRemote `ClimbState` → `MovementState.Request` (validated: character state, a wall or ledge in reach). `Swim` is set only by the server (`SwimService` → `SetSwim`); a client can't start, end or replace it.
  - **Ending it:** stun, knock, grip, carry, death, losing the wall, the wall-run cap. A stun doesn't end a swim. `CharacterHandler` calls `Track` for every player character (enemies are tracked on their first swim).
  - **Climbing status:** started and stopped here, and nowhere else. It is the shared "traversing: no attacking" gate (attacks, block, alchemy, skills, shots, sprint, roll, crouch all refuse it).

## Skills (WCS) — `ReplicatedStorage.Modules.Skills`

- **`Combat.Fist`:** holdable M1. Click buffer and hold-to-chain → `Fist.FistSwing`, which picks Uppercut / Aerial / Dash Attack / gunshot / light combo.
- **`Combat.Heavy`:** R. Mid-swing presses are queued (`HeavyQueuedAt`) and `FistSwing` runs them through `Heavy.TakeQueued` when the swing ends. `CheckOthersActive = false`, so it works while LMB is held.
- **`Combat.Block`:** F tap = parry, hold = block. Starts with `Fresh = true` only on a real key press; in hitstun it opens a hit-parry, then raises the guard once the stun ends if F is still held.
- **States:** Stun, Attacking, Blocking, PerfectParry, IFrame, Dodge, AirCombo, Climbing…

## Client

- **`StarterPlayerScripts.ClientHandler`:** all input bindings.
  - LMB, RMB, R, F (hold-retry), Q dash (`ClientHandler.Roll`), Shift run, Ctrl.
  - V/B downed, **Z/X/C alchemy** (press + release).
- **`Managers.ClientActions`:** the action registry: ClientHandler and CombatModeUI register actions (Attack, Heavy, Block, Dash, Jump, AlchemyZ…), and keys and touch buttons both `Run(Name, Began)` them.
- **`StarterPlayerScripts.UIHandler`:** boots `Modules.UI.*` (now including **MobileControls**).
  - HUDUI, PopupUI, PartyUI, DialogueUI, InventoryUI, SettingsUI (shift lock lives here), CombatModeUI, CooldownUI, **AlchemyUI**, StatsUI, LockOn, Fill. (The old HotbarUI was removed; the live hotbar is in HUDUI.)
  - **MasteryUI** (K, the skill tree), **CombatLogUI** (in-combat badge), **AdminUI** (F2, admins only; built from the Settings panel's art).
  - **JournalUI** (J: quests, evidence, Case Board, codex), **PuzzleClient** (draws this player's puzzle states), **MinigameUI** — all panels built with **MenuKit** (an on-theme panel from the Settings art: rows, buttons, cyclers, paragraphs).
  - **UIMotion** is started last: menu open / close (`UIState` calls `Open` / `Close` / `Fade`), button hover and press, row pop-in (skipped for rows with the `NoPop` attribute), HUD2 popups, dialogue, HUD. Respects the player attributes `ReducedMotion` and `UISounds` (from Settings).
  - `UIState.RegisterMenu(Name, Frame, OnOpen, AllowInCombat)`: menus are locked in combat unless `AllowInCombat`, and never open over an NPC conversation (`Uis.Dialogue` visible).
  - **PopupUI** builds the minimal level-up card (`HUD2.LevelUpMinimal`) and the NEW AREA / CODEX ENTRY card (`HUD2.EntryMinimal`), queued in one lane. **DialogueUI** adds an X close button (Esc belongs to Roblox's menu).
- **`StarterPlayerScripts.SwimClient`:** swim animations (`Shared.Movement.Swim`), swim sprint (Shift / touch SPRINT), rise (Space / touch RISE), the breath bar (`SwimHUD`).
- **`StarterGui.Uis`:** the rebuilt UI (HUD, HUD2, Stats, Inventory, Settings, Dialogue, Templates).

## Effects (ReFX) — `ReplicatedStorage.Modules.Effects`

- **`Combat.*`:** hit, block, parry, roll, knockback, crit telegraph…
- **`Alchemy.Transmute`:** clap circle + hand fire + ground flash.
- **`Alchemy.Fireball`:** server-timed; `:Impact`.
- **`Alchemy.Burst`, `Phoenix`, `Warning`, `Sigil`:** Flame kit effects.
- **Ice kit:** `Alchemy.IceShapes` (part-built crystals + greataxe, `Emit`), `IceSpikes` (crystals erupting), `IceAxe`, `IceTrap` (`:Trigger`), `FrostNova`, `IceGuard` (`:Trigger`).
- **Wind kit:** `Alchemy.WindShapes` (textured plates, beams, `Emit`), `AirSlash` (projectile, Fireball contract), `GaleBurst` (`:Pulse`), `Updraft`, `Tornado`.
- **Metal kit:** `Alchemy.MetalShapes` (spike, wall, anvil, blade, `Emit`), `SteelGuard` (`:Absorb`/`:Break`/`:Lower`), `SteelSpikes` (Trail/Bind), `AnvilDrop`, `SteelLance`, `AlloyBlade` (`:Slam`), `LineWarning` (line telegraph).
- **`Status.StatusVFX`:** welds the owner's status VFX part (Assets.VFX.StatusEffects) to the victim for the status's duration; Freeze adds an ice Highlight. (The old `Alchemy.Burning` is retired to backups.)

## Assets — `ReplicatedStorage.Assets`

- **`Animations.Shared`:** movement, combat, downed, **Alchemy** (Clap, ClapLoop, GroundSlam, ArmExtend, Ignite/Fire 1–5).
- **`Animations.Weapons`:** per-weapon sets, many still unpublished.
- **`Animations.Shared.Styles`** (Boxing / Lethwei) and **`Animations.Shared.Movement.Swim`** (Swim_Idle / Swim_Forward / Swim_Sprint): preloaded for every character.
- **`Animations.Registry`:** sheet animations that load but aren't wired yet (movement, grips, the skill-sheet animations, extra NPC idles). AnimationManager resolves them by name for server / NPC playback; clients don't preload them (each character stays at about 140 tracks of Roblox's 256). Move an entry into `Shared` / `Weapons` when a system starts playing it on players.
- **`Items.Weapon`:** weapon Tools.
  - Grip parts carry attributes Arm, MotorC0/MotorC1, HolsterC0.
  - Holsters (PROPOSAL spots): Katana/Rapier left hip (handle forward, blade back), Greatsword diagonal on the back, Daggers crossed flat on the lower back, pistols on the right thigh.
- **`Items.Consumable`:** hotbar items (Apple). Held with keys 1–0 outside Combat Mode only; Combat Mode puts the item away. Click while holding to use (`ServerScriptService.ItemService`).
- **`VFX.FireElement`:** the owner's Flame VFX, copied from the Assets place.
  - ignite, infernolance, scorchingwave, phoenixdrive, Hands.
- **`VFX.EarthElement`:** the owner's prototype rock + spike meshes (MeshParts), sounds, crack decal, dust / chips, Hands.
- **`VFX.WindElement`, `VFX.MetalElement`:** built for the Wind and Metal kits (same layout).
- **`VFX.IceElement`:** built for the Ice kit from the owner's Freeze textures (Hands, shatter, mist); same layout as FireElement.
- **Animations with a `Save` child + attribute `StudioPrefersSave`:** published animation plus a corrected unpublished copy (the climb animations). Studio plays the copy; live plays the id.
- **`VFX.StatusEffects`:** the owner's status VFX parts (Fire, Freeze, Bleed, Shock), copied from the Assets place.
- **`RELLO IMPORTED ASSETS`:** the owner's imports (FireElement rig animations, books, armour…).
- **Transmutation circle texture:** `rbxassetid://132299053523633`, a custom white circle tinted per element.

## Conventions and gotchas (read before changing code)

- **Never use weak-keyed tables with Instance keys.** Roblox drops the key once Lua holds no other reference, even while the Instance lives. Use plain tables with explicit cleanup.
- **Walk speed:** every WalkSpeed writer multiplies by the character attribute `SpeedMultiplier`.
- **Testing in Studio:**
  - Ye's ProfileService **saves from Studio**: snapshot and restore the profile when tests grant EXP or training.
  - Studio's command sandbox `require`s modules into a separate VM. To test game logic, run a temporary Script in ServerScriptService (or a BindableFunction hook).
  - Shift lock (Alt) saves to the profile settings; toggle it back after tests.
- **HUD layout:**
  - Elements use `UIAspectRatioConstraint` with DominantAxis = Height, so the layout is identical on every screen.
  - A Folder inside a ScreenGui still renders its contents; templates live in a hidden Frame.
- **Backups:** each change round copies the scripts it touches into `ServerStorage.RenseiBackups["Pre-<Name>_<date>"]`.
- **Two climbing implementations exist.** `Managers.JumpManager` is the live one. `Skills.Combat.Air` is an older WCS-skill copy, registered but never given to a character. Don't extend `Air`; remove it in a cleanup pass once confirmed unused.
- **Terrain uses shorelines** (a cell holds solid and water). Edit terrain with `WriteVoxelChannels` (SolidMaterial / SolidOccupancy / LiquidOccupancy); plain `WriteVoxels` adds water but leaves the old solid. A ray that should reach the ground under water needs `IgnoreWater`; `Terrain:GetMaterialColor(Water)` errors. Map tools (Edit only) are in `ServerStorage.RenseiMapTools` (`LindenmoorGen`, `TerrainWriter`, `PondWriter`, `HouseBuilder`); a full `TerrainWriter` rebuild clears the pools, so run `PondWriter.Write()` after it.
- **WalkSpeed is stored as a 32-bit float:** compare with a tolerance (19.2 reads back as 19.2000008). The game's base walk speed is `DefaultWS * SpeedMultiplier` (12), though WCS characters can start at 16.
- **Studio testing:** pressing Esc opens Roblox's menu, which swallows every key and click until it's closed. Enemies leash back to their spawn, so move their `Home` for tests away from it.
- **The GitHub `Scripts/` export** now includes the combat, movement and swim modules (see `Scripts/README.md`). Not exported: HitboxManager, DamageManager, ClientActions, ItemData, `AdminConfig` and the menu's `ClanCodes` (secrets).

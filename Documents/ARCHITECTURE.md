# Rensei Architecture — where everything lives in Ye

Ye (placeId 106992859583940) started as a JJK-style WCS combat template with Rensei's UI on top. It has been extended system by system. The source of truth is the place itself; this is the map. Updated **2026-10-14**.

## Data and configuration — `ReplicatedStorage.Modules.Data`

- **`Rensei.TuningConfig`:** every combat number (controls doc: "TuningConfig.lua for all numbers"). Invented values are labelled PROPOSAL; values from Devil Hunter's code are labelled DH.
  - Light, Heavy, Uppercut, Aerial, DashAttack, Block, Parry, Dash, Hitstop, HitStun.
  - Parkour, Feint, Weapons, Alchemy, Downed, Enemies.
- **`Rensei.Alchemy`:** the alchemy ability registry. Rows copied from the design sheet: damage, cooldown, cast, class, extras.
- **`Rensei.Stats` / `Progression` / `Formulas` / `Clans` / `Settings`:** stat definitions, level curve, damage/HP formulas (approved spreadsheet scale), clans (the Marcoh rule), settings defaults.
- **`SkillData`:** hit definitions, *generated* from TuningConfig. Names: `Light1-4`, `Heavy`, `<Weapon>_Light1..`, `<Weapon>_Heavy`, `<Weapon>_Skill`, `Alchemy_<Id>`.
- **`ProfileData`:** profile template (SchemaVersion 1). `DataManager` (ServerScriptService.CharacterHandler) runs Migrate before Reconcile.

## Server — `ServerScriptService`

- **`ServerHandler`:** routes `Remotes.RequestRemote(Module, ...)` to `ServerHandler.Requests.<Module>`, behind a token-bucket rate limiter. Starts the services.
  - Requests: Stat, Gate, Sync, Party, Quest, Dialogue, Settings, Equip, HoldItem, CombatMode, Uppercut, Feint, JumpAttack, WeaponSkill, Aim, Downed, **Alchemy**.
- **`ProgressionService`:** the only writer of stats, EXP, Mastery Points and Truth/Gate. Records hits (training), and writes the character multipliers PhysicalMultiplier, AlchemyMultiplier and SpeedMultiplier.
- **`AlchemyService`:** alchemy casting (kinds: Projectile, Cone, Lunge, Phoenix, Counter, Melee, Trap, Nova; on-hit statuses via `ApplyOnHit`) (validation, meter, cooldown, clan rule, clap → slam → move prelude, projectiles, cone / lunge / phoenix). Burns go through `StatusManager`. Publishes the `Player` attribute `Affinity`.
- **`EnemyService`:** PvE spawns (parts tagged `RenseiEnemySpawn`), Grunt/Elite AI using the players' combat rules.
- **`UIService`:** server → client UI events (Toast, LevelUp, Area, Party, Dialogue…).
- **`PartyService`, `QuestService`, `WorldService`, `DialogueService`:** frameworks wired; quest and dialogue content are empty on purpose.
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
- **`DownedManager`:** all combat damage goes through `DownedManager.Damage`. Knocked state, Grip, Carry.
- **`WeaponManager`:** weapon tools.
  - Server: grip Motor6Ds; HolsterWeld while holstered; draw/sheathe; guns; passives.
  - Client: hold, idle and carry poses; the holster↔hand blend.
- **`ResourceManager`:** Stamina, Posture, Meter. Attributes are computed so clients can read them for free.
- **`AnimationManager`:** server → client animation playback.
  - Unpublished KeyframeSequences (`Animation` with an empty id + a `Save` child) register in Studio only.
  - Hitstop freeze.
- **`MoverManager`:** velocity, look-at, lunge, hover, dive and knockback movers. `Movement()` handles walk-speed windows.
- **`JumpManager`:** jump, climb (directional), wall run.

## Skills (WCS) — `ReplicatedStorage.Modules.Skills`

- **`Combat.Fist`:** holdable M1. Click buffer and hold-to-chain → `Fist.FistSwing`, which picks Uppercut / Aerial / Dash Attack / gunshot / light combo.
- **`Combat.Heavy`:** R; also the feint.
- **`Combat.Block`:** F tap = parry, hold = block. Starts with `Fresh = true` only on a real key press; in hitstun it opens a hit-parry, then raises the guard once the stun ends if F is still held.
- **States:** Stun, Attacking, Blocking, PerfectParry, IFrame, Dodge, AirCombo, Climbing…

## Client

- **`StarterPlayerScripts.ClientHandler`:** all input bindings.
  - LMB, RMB, R, F (hold-retry), Q dash (`ClientHandler.Roll`), Shift run, Ctrl.
  - V/B downed, **Z/X/C alchemy** (press + release).
- **`StarterPlayerScripts.UIHandler`:** boots `Modules.UI.*`.
  - HUDUI, PopupUI, PartyUI, DialogueUI, InventoryUI, SettingsUI (shift lock lives here), CombatModeUI, CooldownUI, **AlchemyUI**, StatsUI, LockOn, HotbarUI, Fill.
- **`StarterGui.Uis`:** the rebuilt UI (HUD, HUD2, Stats, Inventory, Settings, Dialogue, Templates).

## Effects (ReFX) — `ReplicatedStorage.Modules.Effects`

- **`Combat.*`:** hit, block, parry, roll, knockback, crit telegraph…
- **`Alchemy.Transmute`:** clap circle + hand fire + ground flash.
- **`Alchemy.Fireball`:** server-timed; `:Impact`.
- **`Alchemy.Burst`, `Phoenix`, `Warning`, `Sigil`:** Flame kit effects.
- **Ice kit:** `Alchemy.IceShapes` (part-built crystals + greataxe, `Emit`), `IceSpikes` (crystals erupting), `IceAxe`, `IceTrap` (`:Trigger`), `FrostNova`, `IceGuard` (`:Trigger`).
- **`Status.StatusVFX`:** welds the owner's status VFX part (Assets.VFX.StatusEffects) to the victim for the status's duration; Freeze adds an ice Highlight. (The old `Alchemy.Burning` is retired to backups.)

## Assets — `ReplicatedStorage.Assets`

- **`Animations.Shared`:** movement, combat, downed, **Alchemy** (Clap, ClapLoop, GroundSlam, ArmExtend, Ignite/Fire 1–5).
- **`Animations.Weapons`:** per-weapon sets, many still unpublished.
- **`Items.Weapon`:** weapon Tools.
  - Grip parts carry attributes Arm, MotorC0/MotorC1, HolsterC0.
- **`VFX.FireElement`:** the owner's Flame VFX, copied from the Assets place.
  - ignite, infernolance, scorchingwave, phoenixdrive, Hands.
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

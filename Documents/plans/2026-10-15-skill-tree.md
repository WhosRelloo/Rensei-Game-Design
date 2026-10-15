# Skill Tree Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Rensei's Mastery skill tree: three themed trees ([Path] Alchemy / Arms / Body) where Mastery Points buy nodes that unlock alchemy moves and change combat numbers, with live previews.

**Architecture:**
- One shared registry, `Modules.Data.Rensei.SkillTree`, holds the trees, nodes, layout and preview recipes, plus the pure `CanBuy` / `Modifiers` helpers.
- A server service, `SkillTreeService`, validates Buy / Refund through the existing `ProgressionService`, and publishes the summed modifiers as `Mod_<Key>` character attributes.
- Each game system reads only its own keys through a tiny shared helper, `Managers.SkillMods`.
- The client UI, `Modules.UI.MasteryUI`, draws each tree as a transmutation circle with a node card and a ViewportFrame preview.

**Tech stack:** Roblox Luau in Studio (place RSEI / Ye, 106992859583940), edited through the Studio MCP. ProfileService saves. Tests are Studio Edit-mode checks (pure registry functions) and Play-mode checks through a temporary `ServerStorage.TestHook` (deleted afterwards).

**Spec:** `Documents/specs/2026-10-15-skill-tree-design.md` (approved 2026-10-15).

## Global constraints

- Every number is a PROPOSAL from the spec §4; no other balance changes.
- Server-authoritative: the client never decides a purchase, refund or effect.
- Back up every script before editing it, to `ServerStorage.RenseiBackups.Pre-SkillTree_2026-10-15`.
- Don't publish the game, and don't touch live player data. The owner's test profile is restored after testing.
- Rensei UI style: Guru font, gold `rgb(230,205,120)` on near-black, the panel art. No copying of VV Ultimatum's art or layout; only its "separate trees per theme" structure.
- "Commit" = push the docs update to `WhosRelloo/Rensei-Game-Design`. The game code lives in the place and is backed up in RenseiBackups.

## File map

| File | Responsibility |
|---|---|
| `ReplicatedStorage.Modules.Data.Rensei.SkillTree` (new) | Trees, roots, nodes, layout, preview recipes; `CanBuy`, `CanRefund`, `Modifiers`, `Rank`, `SpentIn` |
| `ReplicatedStorage.Modules.Managers.SkillMods` (new) | `SkillMods.Get(Character, Key)`: reads `Mod_<Key>` (0 when absent); `Mult(Character, Key)` = 1 + Get |
| `ServerScriptService.SkillTreeService` (new) | Buy / Refund, combat lock, `Publish(Player)` of the modifiers |
| `ServerScriptService.ServerHandler.Requests.SkillTree` (new) | The remote entry: `(Player, Action, NodeId, ExpectedRank)` |
| `ReplicatedStorage.Modules.Data.ProfileData` | Save v2: `SkillTree = {}`, `Mastery.StageSpend = {}`, `SchemaVersion = 2` |
| `ServerScriptService.CharacterHandler.DataManager` (+ menu `MenuData`, tutorial `FlowData`) | Migration step 1 → 2 |
| `ReplicatedStorage.Modules.Data.Rensei.Progression` | `MaxStage = 5`; `GateExp[4]` stays from the growth rule |
| `ServerScriptService.ProgressionService` | `RefundMastery`; `CompleteTrial` seals `StageSpend`; `ApplyCharacter` applies MaxHealth / MaxStamina / MaxMeter mods and calls `SkillTreeService.Publish` |
| `AlchemyService` | Move gating, slot damage / cooldown, clap speed, windup, cast walk speed, held clap, overflow, refund, blood cast |
| `ResourceManager` | Regen × `Mod_<Name>Regen` |
| `DamageManager` | AttackMult / CastMult, DamageTaken, KnockbackTaken, Duel, Riposte, HeavyPosture, GuardBreakStun, MeterOnHit, MeterRefund |
| `AttackRunner` | Sets `AttackMult` / `PostureMult` per run (light, finisher, string ramp, dash attack, heavy posture); feint cost |
| `Heavy`, `FistSwing`, `Requests.WeaponSkill`, `WeaponManager` | Cooldown / draw / gun / passive mods |
| `DownedManager` | GripSpeed, SecondWind |
| `ClientHandler.Roll`, `CharacterHandler` (IFrame rule), `JumpManager`, `ClientHandler.Run` | Dash cooldown / i-frames, parkour cost, wall-run time, sprint speed |
| `ReplicatedStorage.Modules.UI.MasteryUI` (new) + `UIHandler` | The menu (K), tabs, circles, card, previews |

## Layout table (the registry's `Tree`, `R` = radius in ring units, `A` = angle in degrees clockwise from up)

Ring bands: ring 1 `R` 1.0–1.6, ring 2 `R` 2.3–2.7, ring 3 `R` 3.3. Roots sit at `R` 0.

| Tree | Node: R, A |
|---|---|
| Alchemy | AL_X 1.0,0 · AL_C 1.6,−15 · AL_XPot 1.6,20 · AL_CFocus 1.6,−40 · AL_ZPot 1.0,−70 · AL_ZFocus 1.6,−70 · AL_QuickClap 1.0,70 · AL_Attune 1.0,140 · AL_V 2.3,−15 · AL_VPot 2.7,−30 · AL_CPot 2.3,−45 · AL_Charged 2.3,70 · AL_Steady 2.7,55 · AL_Swift 2.7,85 · AL_Momentum 2.3,140 · AL_VFocus 3.3,−30 · AL_Overflow 3.3,70 · AL_Exchange 3.3,125 · AL_Blood 3.3,155 |
| Arms | AR_Finisher 1.0,0 · AR_Heavy 1.0,−60 · AR_Draw 1.0,90 · AR_Feint 1.0,200 · AR_Art 1.6,90 · AR_Upper 1.6,25 · AR_Riposte 2.3,−75 · AR_Breaker 2.3,−45 · AR_Blade 2.3,0 · AR_Rush 2.3,35 · AR_Marks 2.3,100 · AR_Exec 3.3,−60 · AR_Relentless 3.3,−15 · AR_Duelist 3.3,15 · AR_Mastery 3.3,60 |
| Body | BO_Endure 1.0,0 · BO_Tough 1.6,−20 · BO_Compose 1.6,25 · BO_Climb 1.0,120 · BO_Step 1.0,−120 · BO_Iron 2.3,−135 · BO_Light 2.3,−105 · BO_Vigor 2.3,−25 · BO_Recover 2.3,30 · BO_Runner 2.3,120 · BO_Heavy 2.7,105 · BO_Acro 2.7,135 · BO_Second 3.3,−40 · BO_Unbroken 3.3,−10 · BO_Fort 3.3,30 |

**Preview recipes:**
- `{Kind = "Alchemy", Slot = "Z"|"X"|"C"|"V"}`: all AL_ nodes tied to a slot.
- `{Kind = "Anim", Anim = <name>}`:
  - AR_Finisher / AR_Blade / AR_Relentless / AR_Duelist: `Light.Hits[#].Anim`.
  - AR_Heavy / AR_Breaker: `Heavy`.
  - AR_Upper: `Uppercut`.
  - AR_Rush: `DashAttack.Anim`.
  - AR_Riposte: `Parry1`.
  - AR_Art / AR_Marks / AR_Mastery: `Heavy`.
  - AR_Draw: `Sword_Equip`.
  - AR_Feint / AR_Exec: `FistCombo1`.
  - BO_Step / BO_Light: the dash forward animation.
  - BO_Climb: `RightClimb`. BO_Runner: `Run`. BO_Acro: `WallRunRight`.
- `{Kind = "Stat", Base = <number>, Unit = "", Label = <text>}`: every passive. If there's no Base, it shows percentages.

---

### Task 1: Registry + SkillMods (pure, testable in Edit mode)

**Files:**
- Create `Modules.Data.Rensei.SkillTree`.
- Create `Modules.Managers.SkillMods`.

**Interfaces (produces):**
- `SkillTree.Trees = {"Alchemy","Arms","Body"}`; `SkillTree.Roots = {Alchemy = "AL_Root", Arms = "AR_Root", Body = "BO_Root"}`.
- `SkillTree.Nodes[Id] = {Id, Name, Tree, Ring (0 for roots), R, A, Type, Ranks, Cost, Req = {ids}, Fork, Stat = {names...}, StatReq, Effects = {{Key, Add}}, Slot?, Preview}`.
- `SkillTree.RingStage = {[1] = 1, [2] = 2, [3] = 4}`; `SkillTree.StatReq = {[2] = 8, [3] = 14}`.
- `SkillTree.Rank(Data, Id) -> number` (roots always 1).
- `SkillTree.CanBuy(Data, Id, ExpectedRank?) -> ok:boolean, reason:string?`
- `SkillTree.CanRefund(Data, Id) -> ok, reason`
- `SkillTree.Modifiers(Data) -> {[Key] = number}`
- `SkillTree.SpentIn(Data, Tree) -> number`
- `SkillMods.Get(Character, Key) -> number`; `SkillMods.Mult(Character, Key) -> number`.

- [ ] **Step 1:** Write the registry: the §4 catalogue plus the layout table above. Each node has `Stat` set to its tree's stat list (`Alchemy` → {"Alchemy"}; Arms → {"Strength","Speed"}; Body → {"Vitality","Speed"}), and a node-level override where the spec names one (AL_V Alchemy; AR_Marks Speed; BO_Vigor Vitality; BO_Runner Speed). `StatReq` comes from its ring.
- [ ] **Step 2:** `CanBuy` checks, in order:
  - the node exists and isn't a root;
  - `Data.Mastery.Stage >= RingStage[Ring]`;
  - rank < Ranks;
  - `ExpectedRank == nil or ExpectedRank == rank`;
  - any Req owned (`Rank >= 1`; "Core" = the tree root);
  - no other node in the same Fork owned;
  - `StatReq`: max(Data.Stats[s] for s in Stat) >= StatReq;
  - `Data.Mastery.Unspent >= Cost`.

  Reasons, in order: "Unknown skill", "Opens at Stage N", "Already maxed", "Out of date", "Needs <prereq name>", "Locked by <fork rival name>", "Needs <Stat> N", "Not enough Mastery Points".
- [ ] **Step 3:** `CanRefund`:
  - `(Data.Mastery.StageSpend or {})[Id] >= 1`, else "Sealed by the Truth/Gate trial";
  - if rank would drop to 0, no owned node may list this one as its *only* owned prerequisite (else "Needed by <name>").
- [ ] **Step 4:** `Modifiers` sums `Effects[i].Add * rank` per key. Move nodes contribute `Unlock<Slot> = 1`.
- [ ] **Step 5 (test, Edit mode):** a fake Data with Stage 1, Unspent 5, Stats all 1. Expect:
  - `CanBuy(AL_X)` true; `CanBuy(AL_V)` "Opens at Stage 2";
  - with AL_Steady owned, `CanBuy(AL_Swift)` "Locked by Steady Array";
  - `Modifiers` with AL_ZPot rank 2 → `ZDamage == 0.12`;
  - `CanRefund` on a node not in StageSpend → sealed;
  - the catalogue total is 187 and the max-buyable is 160.
- [ ] **Step 6:** `SkillMods`: `Get` = `tonumber(Character and Character:GetAttribute("Mod_" .. Key)) or 0`.

### Task 2: Save v2 + Progression

**Files:**
- Modify: `ProfileData`, `DataManager`, `Progression`, `ProgressionService`.
- Modify: the menu place `MenuData` and the tutorial place `FlowData` (migration copy).

- [ ] **Step 1:** In ProfileData: `SchemaVersion = 2`; replace `AlchemyTree = {}` with `SkillTree = {}`; add `StageSpend = {}` inside `Mastery`.
- [ ] **Step 2:** Add migration `[1] = function(Data) Data.SkillTree = Data.SkillTree or Data.AlchemyTree or {}; Data.AlchemyTree = nil; Data.Mastery.StageSpend = Data.Mastery.StageSpend or {} end` to Ye's DataManager, the menu's `MenuData` and the tutorial's `FlowData`. Edit each place directly with multi_edit; the relay isn't running.
- [ ] **Step 3:** `Progression.MaxStage = 5`.
- [ ] **Step 4:** `ProgressionService.RefundMastery(Player, Cost)`: `Unspent += Cost`, `Spent -= Cost`, and a guard that `Spent >= Cost`.
- [ ] **Step 5:** In `CompleteTrial` (passed): `Data.Mastery.StageSpend = {}`.
- [ ] **Step 6 (test, Play):** an old profile without these keys loads with `SkillTree = {}` and `StageSpend = {}`; `GateCheck` reports "Final stage reached" when Stage = 5.

### Task 3: SkillTreeService + request + publishing

**Files:**
- Create: `ServerScriptService.SkillTreeService`, `Requests.SkillTree`.
- Modify: `ProgressionService.ApplyCharacter`.

- [ ] **Step 1:** `SkillTreeService.Buy(Player, Id, ExpectedRank)`:
  - Refuse if the Character has `CombatMode` true, or `(LastHitAt or 0) > now - 5` → "Not during combat". Record `LastHitAt`: DamageManager sets `Victim:SetAttribute("LastHitAt", now)` on Hit / Blocked.
  - Run `SkillTree.CanBuy`, then `ProgressionService.SpendMastery(Cost)`.
  - Rank +1, `StageSpend[Id]` +1, `Publish`, `Sync`.
  - Reply via `UIService.Notify(Player, "Toast", {Text = reason})` on refusal, and fire `RequestRemote` `"SkillTree", ok, reason` back.
- [ ] **Step 2:** `Refund`: mirror it with `CanRefund` and `RefundMastery(Cost)`.
- [ ] **Step 3:** `Publish(Player)`:
  - Clear every existing `Mod_*` attribute on the Character, then set each key from `SkillTree.Modifiers(Data)`.
  - Then: `MaxStamina` = `Tuning.Stamina.Max + Mod_MaxStamina`; `MaxMeter` = `Tuning.Meter.Max + Mod_MaxMeter`. MaxHealth is handled in ApplyCharacter.
- [ ] **Step 4:** In `ApplyCharacter`: `Humanoid.MaxHealth = Derived.MaxHealth * (1 + Modifiers.MaxHealth)`, and call `SkillTreeService.Publish(Player)` (lazy require).
- [ ] **Step 5 (test, Play + TestHook), each refused with the exact reason:**
  - no MP;
  - ring closed;
  - fork;
  - stat;
  - a stale ExpectedRank;
  - in Combat Mode;
  - a refund after `StageSpend` is cleared;
  - a refund of a needed prerequisite.

  Then a successful Buy: `Mod_ZDamage` appears on the character, Unspent drops, and it survives a respawn.

### Task 4: Alchemy effects + move gating

**Files:** modify `AlchemyService` and `DamageManager`.

- [ ] **Step 1, gating:** after the affinity check in `Cast`, `if Slot ~= "Z" and SkillMods.Get(Character, "Unlock" .. Slot) < 1 then Tell(Player, ("Unlock %s in the Mastery tree (K)."):format(Def.Name)) return end`.
- [ ] **Step 2, cooldown:** `Def.Cooldown * SkillMods.Mult(Character, Slot .. "Cooldown")` for both ReadyAt and the Cooldown attribute.
- [ ] **Step 3, clap / windup / walk:** `Speed = (T.Speed or 1) * SkillMods.Mult(Character, "ClapSpeed")`; `Windup *= SkillMods.Mult(Character, "Windup")`; WalkSpeed = `SkillMods.Get(Character,"CastWalkSpeed") > 0 and 12 * (Character:GetAttribute("SpeedMultiplier") or 1) or Cfg.CastWalkSpeed`.
- [ ] **Step 4, cast damage:** compute `CastMult = SkillMods.Mult(Character, Slot .. "Damage")`.
  - +HeldClapDamage if the clap was held ≥ 1s (measure in the Prelude).
  - +OverflowDamage if the meter before the spend was ≥ 80.
  - Set `Character:SetAttribute("CastMult", CastMult)` at the cast start, and clear it 4s after the cast ends (token check).
  - In DamageManager's Hit branch, when `SkillInfo.Alchemy`: `Damage *= Character:GetAttribute("CastMult") or 1`.
- [ ] **Step 5, Equivalent Exchange:** at the cast, `Character:SetAttribute("CastRefund", Cost * SkillMods.Get(Character,"MeterRefund"))`. In DamageManager, on an alchemy Hit: if the attribute is > 0, `ResourceManager.Add(Character,"Meter",value)` and set it to nil (once per cast).
- [ ] **Step 6, Blood Price:** if `ResourceManager.Spend` fails and `BloodCast > 0`: HP cost = (Cost − meter) × BloodCast. Allowed only if Humanoid.Health > cost + 1; then set the meter to 0 and `Humanoid.Health -= cost`.
- [ ] **Step 7 (test, Play):**
  - X is refused without AL_X, then works after buying;
  - Z damage on a dummy rises 6% per AL_ZPot rank;
  - the X cooldown attribute shrinks with CFocus;
  - Exchange refunds meter once.

### Task 5: Combat (Arms) effects

**Files:** modify `AttackRunner`, `DamageManager`, `Heavy`, `FistSwing`, `Requests.WeaponSkill`, `WeaponManager`, `DownedManager`, `Requests.Feint` (via `AttackRunner.Feint`).

- [ ] **Step 1, AttackRunner `RunBody`:** from the SkillName:
  - `Light%d+$` → `M = 1 + LightDamage`; if the index == `#Hits` of the weapon / fist list, `+FinisherDamage`; `+ min(index-1,3) * StringRamp`.
  - `DashAttack` → `+DashAttackDamage`.
  - Set `AttackMult = M`.
  - SkillName ending `_Heavy` or `Heavy` → `PostureMult = 1 + HeavyPosture`.
  - Clear both in `Finish`.
- [ ] **Step 2, DamageManager:**
  - On Hit, physical: `Damage *= AttackMult`.
  - Riposte: if `Character:GetAttribute("RiposteUntil") > now`, then ×1.5 and clear it.
  - Duel: if `SkillMods.Get(Character,"DuelDamage") > 0` and exactly one living other character in `World.Live` is within 20 studs, multiply.
  - Victim side: `Damage *= max(0.5, 1 + Mod_DamageTaken)`, also on chip.
  - Knockback velocity × (1 + Mod_KnockbackTaken).
  - GuardBreak stun × (1 + Mod_GuardBreakStun).
  - The block posture negate × `PostureMult`.
  - On a PerfectParry result: if `Mod_Riposte > 0` on the Victim, set `RiposteUntil = now + 2`.
  - Physical hit meter: `+ Mod_MeterOnHit`.
- [ ] **Step 3, cooldowns:**
  - Heavy `Def.Cooldown * Mult(HeavyCooldown)`;
  - FistSwing `Ready(..., Tuning.Uppercut)` with the Cooldown × Mult(UppercutCooldown);
  - WeaponSkill `Skill.Cooldown * Mult(SkillCooldown)`;
  - `AttackRunner.Feint` cost × Mult(FeintCost).
- [ ] **Step 4, WeaponManager:**
  - `Transition` Speed × Mult(DrawSpeed), SwapAt ÷ Mult(DrawSpeed);
  - Reload × Mult(GunReload); Fire Range × Mult(GunRange);
  - `DamageMult` bonus part × Mult(WeaponPassive); bleed damage × Mult(WeaponPassive).
- [ ] **Step 5, DownedManager:**
  - Grip time ÷ Mult(GripSpeed) (on the Gripper).
  - Knock: if Victim `Mod_SecondWind > 0` and not `SecondWindUsed`, use 12s / 30% and set `SecondWindUsed` (cleared on spawn).
- [ ] **Step 6 (test, Play):**
  - the light finisher deals +10% with AR_Finisher;
  - Iron Skin cuts damage taken by 6%;
  - the heavy cooldown attribute shrinks;
  - Riposte crits after a perfect parry;
  - Second Wind recovers at 30% after 12s.

### Task 6: Body + movement effects

**Files:** modify `ResourceManager`, `ClientHandler.Roll`, `CharacterHandler` (IFrame rule), `JumpManager`, `ClientHandler.Run`.

- [ ] **Step 1, ResourceManager.Get:** `Rule.Regen * (1 + (Character:GetAttribute("Mod_" .. Name .. "Regen") or 0))`.
- [ ] **Step 2, Roll (client):**
  - ReadyAt `+ Tuning.Dash.Cooldown * Mult(DashCooldown)`;
  - IFrame request `D.IFrames + Get(DashIFrames)`;
  - server `ClientStates.IFrame`: MaxDuration `+ Mod_DashIFrames`, MinInterval × Mult(DashCooldown), both read from the character.
- [ ] **Step 3, JumpManager:**
  - `ParkourStamina` cost × Mult(ParkourCost) on the server, and `HasStamina` on the client the same way;
  - the wall-run duration `P.WallRunDuration * Mult(WallRunTime)` at both uses.
- [ ] **Step 4, Run:** `CurrentWalkSpeed = 24 * (SpeedMultiplier) * Mult(SprintSpeed)`, and the same for 30.
- [ ] **Step 5 (test, Play):**
  - max stamina 110 with Endurance 1;
  - dash cooldown 10% shorter with QuickStep 1 (measure ReadyAt);
  - climb stamina drain 20% less;
  - Iron Skin tested in Task 5.

### Task 7: Mastery UI + previews

**Files:**
- Create: `Modules.UI.MasteryUI`.
- Modify: `UIHandler` (boot + K menu).

**Interfaces:**
- Consumes: `SkillTree` (Task 1); `UIState.RegisterMenu(Name, Frame, OnOpen)`, `UIState.Data`, `UIState.Changed`, `UIState.Request("SkillTree", Action, Id, ExpectedRank)`; `AppearanceService` copy path (the client builds the preview rig).
- Produces: `MasteryUI.Start()`; menu name `"Mastery"`.

- [ ] **Step 1, panel** (built in code under `PlayerGui.Uis`, Rensei style):
  - header: MP unspent, Stage n/5, progress n/20, and Gate status lines from `Progression.GateCheck`;
  - tabs: `<Affinity> Alchemy`, `Arms`, `Body`, each with its spent MP;
  - canvas: a Frame inside a clipping frame, drawn at `R * RingPx` polar coordinates; ring circles are `ImageLabel`s with a circle image (UICorner 0.5 + UIStroke); links are rotated Frames; nodes are `ImageButton`s sized by type, with keystones larger.
- [ ] **Step 2, node states** (recomputed on `UIState.Changed`):
  - owned: filled gold;
  - available (`CanBuy` true): gold outline with a pulse tween;
  - locked: grey;
  - fork-rival owned: a red strike;
  - ring closed: ring transparency 0.7 with an "Opens at Stage N" label.
- [ ] **Step 3, pan / zoom:**
  - drag on the canvas moves `Canvas.Position`;
  - the mouse wheel and `TouchPinch` scale a `UIScale` (0.6–1.8);
  - a recentre button.
- [ ] **Step 4, card:** the name (slot upgrades use the move's name via `Alchemy.ForAffinity`), the effect lines per rank, the cost, the requirements with ✓ / ✗ from `CanBuy`, and Buy / Refund buttons that send `UIState.Request("SkillTree", ...)`.
- [ ] **Step 5, preview:** `ViewportFrame` + `WorldModel` + `Camera`. The rig is a clone of `Players.LocalPlayer.Character` with scripts / tools stripped and parts anchored except the root (or `StarterCharacter` if missing). A dummy stands 6 studs in front.
  - **Alchemy recipe:** play `Alchemy_Clap` → the Release anim → `Tuning.Alchemy.Abilities[Def.Id].Anim`, and burst a Part in the element colour at the dummy.
  - **Anim recipe:** play the named animation.
  - **Stat recipe:** hide the viewport and show the bars.
  - Loop every 3s. Stop and destroy on card close or node switch.
  - Animations resolve by name from `Assets.Animations` (the Studio `Save` KeyframeSequence fallback, like `AnimationManager.Playable`).
- [ ] **Step 6, UIHandler:** add `"MasteryUI"` to the boot list, and `{Action = "RenseiMastery", Menu = "Mastery", Key = Enum.KeyCode.K, Title = "Mastery"}` to Menus (the touch button comes from `BindAction(..., true, ...)`).
- [ ] **Step 7 (test, Play):** screenshots of each tab; every state; buy and refund through clicks; a preview for each recipe kind; a phone-sized check (Device emulation or the viewport scale).

### Task 8: Docs + status page

- [ ] Update ALCHEMY_SYSTEM (move gating), COMBAT_SYSTEM (Mastery effects), ARCHITECTURE, Changelog, Phase Plan (Track B phase 4 → done), Decisions, and Project Status.
- [ ] Republish the status page.
- [ ] Restore the owner's test profile, and delete the TestHook.

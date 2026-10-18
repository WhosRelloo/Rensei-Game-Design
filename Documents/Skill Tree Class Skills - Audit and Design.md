# Skill Tree & Class Skill Hotbar: Audit and Design (Phase 1)

**Date:** 2026-10-17. **Source of truth:** Ye (106992859583940), read in Studio. Docs: `specs/2026-10-15-skill-tree-design.md` (owner-approved) and `ARCHITECTURE.md`.

## 1. What already exists (verified in Ye)

| System | Where | State |
|---|---|---|
| **Mastery skill tree** | `Rensei.SkillTree` (registry plus shared `CanBuy` / `CanRefund` / `Requirements` / `Modifiers`), `SkillTreeService` (Buy / Refund / Publish), `Requests.SkillTree`, `MasteryUI` (K) | **Built and owner-approved.** Three tabs, `[Path] Alchemy / Arms / Body`, each a transmutation circle with rings by stage. 49 passive / upgrade / keystone / move nodes, bought with **Mastery Points**, refundable until the Truth/Gate trial seals the stage, with live previews in the node card. |
| Currency | `ProgressionService.SpendMastery` / `RefundMastery`, `Mastery.{Unspent, Spent, StageSpend}` | MP come from training (20 per stage). Stat Points are a separate currency. |
| Alchemy | `AlchemyService`, `AlchemyUI` (Z / X / C / V slot bar, bottom-right), unlocks = SkillTree Move nodes | Unlocked in the Mastery tree's Alchemy tab. **No second unlock system.** |
| Weapon skill | `Weapons.<Class>.Skill`, `Requests.WeaponSkill`, key **T** (`Keybinds.WeaponSkill`) | One built-in skill per weapon (Dragonflash, Flurry, Barrage, Whirlwind, Scissor Rush, Fan the Hammer). Most run on Studio-only animations. |
| **Skill-sheet animations** | `Animations.Registry.Skills` (20, all load, Rensei group) | **Not used by anything.** No class-skill system exists. |
| **Hotbar** | `HUDUI` (`HUD.Bottom` Slot1..Slot0), `Requests.HoldItem` | Ten slots for **consumables**, held **outside Combat Mode only**. In Combat Mode the server refuses them, so **number keys do nothing in combat**. Slots are also tappable ImageButtons (mobile). |
| Input | `ClientHandler` + `Managers.ClientActions` registry; `Keybinds` (Dash Q, Block F, LockTarget G, WeaponSkill T) | Taken: LMB, RMB, R, F, Q, E, T, G, Z, X, C, V, B, H, J, K, M, P, `` ` ``, Shift, Ctrl, Space, Alt. |
| Mobile | `MobileControls` (cluster: actions, alchemy with cooldowns) | Contextual by Combat Mode. |
| Combat pipeline | `AttackRunner` (Startup → Active → Recovery; `HitTimes`, `MultiHit`, `HyperArmor`, `Strike` override, stun interrupts), `HitboxManager.Sweep` → `DamageManager`, `SkillData` generated from TuningConfig | Reused as-is for class skills. |
| Classes | `TuningConfig.Weapons`: Sword (Katana), Rapier, **Gauntlets (= Caestus)**, Greatsword, Daggers, Guns. Unarmed = no weapon (`EquippedWeapon = ""`). | The skill sheet's "Fist" column covers fist fighting. The sheet's "Caestus (Fists)" row is the Gauntlets class. |
| Styles | none built (the movement / style prompt's Phase F) | The skill data carries an optional `Styles` field. |
| Save | `ProfileData` SchemaVersion 4, `ProfileMigrations` (shared across 3 places), `SkillTree = {[NodeId] = rank}` | Ownership of class skills fits the existing `SkillTree` table. |

**Leftover found:** `Modules.UI.SkillTreeUI` and `Data.SkillTreeData` ("Cursed Technique" / "Yielding Art") are JJK-template remnants. UIHandler doesn't boot them. I'm leaving them untouched.

## 2. Gap analysis

| Required | Status |
|---|---|
| Class Skills as their own column / tab | **Missing.** Add a fourth tab, **Class**, to the Mastery menu, laid out as columns (one per class), not a circle. |
| Class-skill definitions | **Missing.** The 20 skill-sheet animations have no combat definitions. |
| Learn (unlock) | **Reuse:** `SkillTree.CanBuy` + `SkillTreeService.Buy` (MP, prerequisites, refund-until-seal). Add one requirement type, **Level**. |
| Equip to the hotbar / loadout | **Missing.** New `SkillLoadout` save key and Equip / Unequip actions. |
| Activate | **Missing.** New `Requests.ClassSkill(Slot)` running through `AttackRunner`. |
| Grab skills (victim animations) | **Missing.** A small `AttackRunner` extension (an `AfterStrike` hook to stop a whiffed grab) plus grab handling. |
| General combat techniques / passives | **Already exist** as the Arms and Body tabs (Upgrade / Passive / Keystone nodes). Not duplicated. |
| Alchemy | **Already exists** as the Alchemy tab (Move nodes unlock X / C / V). Not duplicated. |
| Progression / Mastery header (MP, stage, Truth/Gate) | **Already exists** in MasteryUI. Kept. |

## 3. Design (PROPOSAL where marked)

### Category layout (Mastery menu, K)

`[Path] Alchemy | Arms | Body | Class`

- **Alchemy:** alchemy moves and upgrades (existing).
- **Arms:** general combat techniques and weapon upgrades (existing).
- **Body:** passives (existing).
- **Class (new, dedicated):** columns **Fists · Sword · Rapier · Greatsword · Daggers · Guns**.
  - Each column lists that class's skills top to bottom in prerequisite order, with links between them.
  - The column for your currently equipped class is highlighted and labelled **Equipped class**.
  - Each node shows its state: **Locked / Learnable / Learned / Equipped (slot n)**.
  - Selecting one opens the detail card: description, cost, the requirement checklist (the server's own verdict), cooldown, stamina and animation status, plus **Learn**, **Refund**, **Equip to slot 1–4** and **Unequip**.
  - A **loadout preview strip** shows the 4 slots of the selected class.

### Compatibility (data: `ClassSkills.Families`)

| Family | Matches |
|---|---|
| `Fists` | unarmed **and** `Gauntlets` (Caestus) |
| `Sword` | `Sword` |
| `Rapier` | `Rapier` |
| `Greatsword` | `Greatsword` |
| `Daggers` | `Daggers` |
| `Guns` | `Guns` |

- A skill may also list `Styles` (none yet; the style system isn't built).
- Pending owner decision 1: if the Fist styles are meant for only one of unarmed / Gauntlets, it's a one-line change in `Families`.

### Unlock economy

- **Mastery Points:** the existing skill-tree currency, per the approved spec ("one connected tree… Arms (weapons / fighting)"). Truth/Gate isn't touched. Class skills join the same refund-until-the-trial rule.
- **Requirements:** prerequisite skill (chains per class), **character Level** (tier 1 = 1, tier 2 = 5, tier 3 = 10; PROPOSAL), and MP cost 2–5 (PROPOSAL).
- Every class skill sits in ring 1 (Stage 1), so all are reachable before the trial exists.

### Hotbar and loadout

- **4 class-skill slots per family** (PROPOSAL), saved as `SkillLoadout[Family] = {Id, Id, Id, Id}`.
- **Keys:** in **Combat Mode**, hotbar keys **1–4** (and tapping hotbar slots 1–4 on mobile) activate the equipped class skills. Out of Combat Mode they hold consumables exactly as now. Today the number keys do nothing in Combat Mode, so **no binding conflicts** and the consumable hotbar keeps working.
- **Display:** in Combat Mode, hotbar slots 1–4 show the equipped skill (name, key, cooldown sweep, stamina cost) and slots 5–0 dim. Out of Combat Mode the hotbar shows items as before.
- **Switching weapons** switches to that family's own saved loadout; nothing is deleted.
- **T stays** the weapon's built-in skill.

### Activation (server-authoritative)

- The client sends only the slot number: `Requests.ClassSkill(Slot)`.
- The server resolves the family from the equipped weapon, then the skill from the saved loadout. It checks:
  - owned, compatible;
  - Combat Mode on, alive;
  - not stunned, attacking, blocking, traversing or knocked;
  - cooldown (`ClassSkillReadyAt_<Id>`), stamina.
- Then it runs `AttackRunner.Run(Def, "Class_<Id>")`. The hitbox, damage, posture, block / parry, hitstop and interruption are all the existing ones.
- Rate-limited by `ServerHandler`'s request limiter. Respawn clears nothing that's saved.

### Combat definitions

- `TuningConfig.ClassSkills` (numbers PROPOSAL) → `SkillData["Class_<Id>"]` (+ `Final`).
- Hit times come from each animation's own markers where they exist (HitFrame, Stab, Slash1/2, FirstHit / FinalHit). Otherwise they come from measured peaks of limb motion.
- Grab skills (Bear Hug, Slam Dunk, Iron Rush):
  - The first hit is the grab. On a hit, the victim is held: stunned for the move, snapped in front, and playing its victim animation. Later hits land as timed.
  - On a whiff, *Grab Whiff* plays and the move ends.

## 4. Class-skill catalogue (from the skill sheet; numbers PROPOSAL)

| Family | Skill (sheet name) | Tier / Level | Cost | Req | Kind | Hit times (source) |
|---|---|---|---|---|---|---|
| Fists | Spin Kick | 1 / 1 | 2 | — | 3-hit spin | 0.19, 0.44, 1.11 (peaks) |
| Fists | 540 Kick | 2 / 5 | 3 | Spin Kick | 1 big hit, knockback | 0.82 (peak) |
| Fists | Bear Hug | 1 / 1 | 3 | — | grab → crush | 0.28 grab, 0.69 (peaks) |
| Fists | Slam Dunk | 2 / 5 | 4 | Bear Hug | grab → slam | 0.44 grab, 2.09 (peaks) |
| Fists | WHERE YOU GOING?! | 3 / 10 | 5 | 540 Kick or Slam Dunk | 4-hit chase combo, pulls in | 0.82, 1.10, 1.42, 1.94 (peaks) |
| Sword | Quick Draw | 1 / 1 | 2 | — | lunging draw cut | 0.88 (HitFrame marker) |
| Sword | Iaido Barrage | 2 / 5 | 4 | Quick Draw | 4 cuts | 0.47, 0.72, 0.99, 1.23 (peaks) |
| Daggers | Slip Slash | 1 / 1 | 2 | — | 2 cuts | 0.42, 0.89 (peaks) |
| Daggers | Bullet Slash | 2 / 5 | 3 | Slip Slash | dash cut, 2 hits | 0.42, 0.71 (peaks) |
| Daggers | Blood Dash | 2 / 5 | 3 | Slip Slash | dash-through cut + bleed | 0.79 (peak) |
| Daggers | COME HERE!! | 3 / 10 | 4 | Bullet Slash or Blood Dash | 4-hit pull-in flurry | 0.19, 0.38, 0.61, 0.86 (peaks) |
| Greatsword | Heavy Drop | 1 / 1 | 3 | — | 2 hits, hyper armour, lunge | 0.92, 1.67 (HitFrame markers) |
| Greatsword | Whirlwind Cleave | 2 / 5 | 4 | Heavy Drop | wide 2-hit spin | 0.92, 1.65 (FirstHit / FinalHit markers) |
| Rapier | Speed Lunge | 1 / 1 | 2 | — | long lunge thrust | 0.39 (peak) |
| Rapier | Ren | 2 / 5 | 4 | Speed Lunge | leap, 2 slashes, landing hit | 0.65, 0.93, 1.33 (Slash1 / Slash2 / Land markers) |
| Guns | Iron Rush | 1 / 1 | 3 | — | rush → grab stab → kick | 1.97 grab, 2.75 (Stab / Kick markers; Fail at 2.08) |

- **Gaps:** Sword, Greatsword and Rapier have 2 skills each and Guns has 1. That's all the sheet has; I'm not inventing more.
- **Missing assets:** no icons exist, so slots and nodes show the skill name in Rensei's font, not placeholder art. No sounds or VFX are specific to these skills; they use the existing hit / swing effects.

## 5. Risks

- **Mastery Points are scarce** (20 per stage, and the trial isn't built). Class skills compete with the Arms and Body nodes, by design. Costs are PROPOSAL.
- **Grab skills move another player** (a one-time snap in front). Exploit safety: only on a server-confirmed hit, only within reach, and never through walls (raycast).
- **Number keys change meaning in Combat Mode.** This is documented and shown in the UI (hotbar slots relabel).

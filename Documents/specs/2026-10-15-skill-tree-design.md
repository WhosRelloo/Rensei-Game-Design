# Skill Tree — Design Spec

**Status:** design approved section by section by the owner, 2026-10-15. Waiting on the owner's review of this written spec. Every number is a **PROPOSAL** for tuning.

**Sources:**
- The master plan §8 (Connected Skill Tree) and §17.
- `Decisions.md` (Progression).
- `Modules.Data.Rensei.Progression` and `ProgressionService` (Mastery Points, Truth/Gate).
- The owner's older build: the alchemy-knowledge ladder *Understanding → Deconstruction I/II → Reconstruction I/II/III → Advanced Understanding*, and per-move skill-XP costs.

## 1. Owner decisions (2026-10-15)

| Topic | Decision |
|---|---|
| Scope | **Alchemy + combat:** one connected tree with Alchemy, Arms (weapons / fighting) and Body (health, stamina, movement). |
| Alchemy moves | **Earned in the tree.** Z at the start; X and C bought; V behind the first Truth/Gate trial. |
| Respec | **Free until the trial.** Points bought in the current stage can be refunded; passing the trial seals them. |
| Specialization | **Forks + more than you can buy.** Exclusive pairs, and more nodes than any character earns. |
| Stages | **5 stages × 20 MP = 100 MP** lifetime, with 4 Truth/Gate trials. |
| Stats link | **Stat requirements on deeper nodes.** |
| Where to spend | **Anywhere, out of combat,** from a menu. |
| Shape | **A transmutation circle:** rings Comprehension → Deconstruction → Reconstruction; sectors Alchemy / Arms / Body. |

Already confirmed and unchanged:
- Mastery Points come from training (hits, parries, defeats), 20 per stage.
- Reaching the next stage needs all 20 spent, enough lifetime EXP, and a passed trial.
- Stat Points and Mastery Points stay separate currencies.

## 2. Structure

```
                 ALCHEMY
            ring3  ring2  ring1
                  \  |  /
                 (Understanding)        centre: owned by everyone, holds the Z move
                  /     \
             ARMS        BODY
```

- **Centre, *Understanding*:** free and owned by every character. It holds the **Z** move.
- **Rings,** opened by stage (the stage you're in, `Mastery.Stage`):

| Ring | Name | Opens at | Stat requirement (sector stat) |
|---|---|---|---|
| 1 | Comprehension | Stage 1 | none |
| 2 | Deconstruction | Stage 2 (after trial 1) | 8 |
| 3 | Reconstruction | Stage 4 (after trial 3) | 14 |

- **Sector stats:**
  - **Alchemy** nodes need **Alchemy**.
  - **Arms** nodes need **Strength or Speed** (either one).
  - **Body** nodes need **Vitality or Speed** (either one).
  - A node may override this (e.g. Marksman needs Speed).
- **Connections:** every node lists its prerequisites (an inward neighbour). You need **any one** of them to buy it.
- **Forks:** nodes sharing a fork group are exclusive; owning one locks the rest. Refunding (within the stage) unlocks them again.
- **Ranks:** a node may have 1–3 ranks, each bought separately. Prerequisites need rank 1.

**Budget:**
- The catalogue below holds **187 MP** counting both sides of every fork.
- A character can buy at most **160 MP** (one side of each fork).
- Lifetime earnings are **100 MP**, so every build leaves about 60 MP of the tree unbought.

## 3. Node types

| Type | What it does |
|---|---|
| **Move** | Unlocks an alchemy slot (X, C, V). `AlchemyService.Cast` refuses a slot whose Move node isn't owned. |
| **Upgrade** | Improves one specific thing, per rank. Slot upgrades follow the slot, not the path; the UI names them after your path's move ("Ignite Potency", "Rising Thorn Potency"). |
| **Passive** | A steady bonus (stamina, HP, posture...). |
| **Keystone** | A big, rule-changing node in ring 3, always one side of a fork. |

## 4. Catalogue (PROPOSAL)

Columns:
- **Ranks×Cost:** MP per rank.
- **Req:** a prerequisite; any one listed is enough. "Core" is the centre.
- **Fork:** the exclusive group.
- **Effect:** per rank, with the modifier key in `code`.

### Alchemy

| Id | Name | Ring | Type | Ranks×Cost | Req | Fork | Effect |
|---|---|---|---|---|---|---|---|
| AL_X | Second Transmutation | 1 | Move | 1×3 | Core | | Unlocks **X** (`UnlockX`) |
| AL_C | Third Transmutation | 1 | Move | 1×4 | AL_X | | Unlocks **C** (`UnlockC`) |
| AL_QuickClap | Quick Clap | 1 | Upgrade | 2×2 | Core | | Clap −8% time (`ClapSpeed` +0.08) |
| AL_Attune | Attunement | 1 | Passive | 2×2 | Core | | +10 max meter (`MaxMeter` +10) |
| AL_ZPot | Z Potency | 1 | Upgrade | 3×1 | Core | | Z damage +6% (`ZDamage` +0.06) |
| AL_ZFocus | Z Focus | 1 | Upgrade | 2×1 | AL_ZPot | | Z cooldown −8% (`ZCooldown` −0.08) |
| AL_XPot | X Potency | 1 | Upgrade | 2×2 | AL_X | | X damage +6% (`XDamage` +0.06) |
| AL_CFocus | C Focus | 1 | Upgrade | 2×2 | AL_C | | C cooldown −8% (`CCooldown` −0.08) |
| AL_V | Grand Transmutation | 2 | Move | 1×6 | AL_C | | Unlocks **V** (`UnlockV`). Alchemy 8 |
| AL_Charged | Charged Clap | 2 | Upgrade | 2×2 | AL_QuickClap | | Holding the clap ≥1s: the move +5% (`HeldClapDamage` +0.05) |
| AL_Momentum | Alchemic Momentum | 2 | Passive | 2×2 | AL_Attune | | +1 meter per light hit (`MeterOnHit` +1) |
| AL_Steady | Steady Array | 2 | Upgrade | 1×3 | AL_Charged | A1 | Cast at normal walk speed (`CastWalkSpeed` = walk) |
| AL_Swift | Swift Array | 2 | Upgrade | 1×3 | AL_Charged | A1 | Windup −10% (`Windup` −0.10) |
| AL_VPot | V Potency | 2 | Upgrade | 2×2 | AL_V | | V damage +6% (`VDamage` +0.06) |
| AL_CPot | C Potency | 2 | Upgrade | 2×2 | AL_C | | C damage +6% (`CDamage` +0.06) |
| AL_Exchange | Equivalent Exchange | 3 | Keystone | 1×5 | AL_Momentum | KA | A landed alchemy hit refunds 30% of its meter (`MeterRefund` 0.30) |
| AL_Blood | Blood Price | 3 | Keystone | 1×5 | AL_Momentum | KA | Out of meter: cast by paying 2 HP per missing meter (`BloodCast` 2) |
| AL_VFocus | V Focus | 3 | Upgrade | 2×3 | AL_VPot | | V cooldown −8% (`VCooldown` −0.08) |
| AL_Overflow | Overflow | 3 | Passive | 1×4 | AL_Charged | | Alchemy +10% while meter ≥ 80 (`OverflowDamage` 0.10) |

### Arms

| Id | Name | Ring | Type | Ranks×Cost | Req | Fork | Effect |
|---|---|---|---|---|---|---|---|
| AR_Heavy | Heavy Hand | 1 | Upgrade | 2×2 | Core | | Heavy cooldown −10% (`HeavyCooldown` −0.10) |
| AR_Feint | Feint Discipline | 1 | Upgrade | 1×2 | Core | | Feint stamina −25% (`FeintCost` −0.25) |
| AR_Finisher | Finisher | 1 | Upgrade | 2×2 | Core | | Last hit of the M1 string +10% (`FinisherDamage` +0.10) |
| AR_Draw | Drawn Steel | 1 | Upgrade | 1×1 | Core | | Draw / sheathe 30% faster (`DrawSpeed` +0.30) |
| AR_Art | Weapon Art | 1 | Upgrade | 2×2 | AR_Draw | | Weapon skill (T) cooldown −10% (`SkillCooldown` −0.10) |
| AR_Upper | Uppercutter | 1 | Upgrade | 1×2 | AR_Finisher | | Uppercut cooldown −20% (`UppercutCooldown` −0.20) |
| AR_Riposte | Riposte | 2 | Upgrade | 1×3 | AR_Heavy | R1 | After a perfect parry, the next hit within 2s is a crit (`Riposte` 1) |
| AR_Breaker | Guard Breaker | 2 | Upgrade | 1×3 | AR_Heavy | R1 | Heavies +25% posture damage (`HeavyPosture` +0.25) |
| AR_Blade | Bladework | 2 | Passive | 3×2 | AR_Finisher | | Light attacks +4% (`LightDamage` +0.04) |
| AR_Marks | Marksman | 2 | Upgrade | 2×2 | AR_Art | | Guns: reload −10%, range +10% (`GunReload` −0.10, `GunRange` +0.10). Speed 8 |
| AR_Rush | Momentum Strike | 2 | Upgrade | 2×2 | AR_Upper | | Dash attack +10% (`DashAttackDamage` +0.10) |
| AR_Relentless | Relentless | 3 | Keystone | 1×5 | AR_Blade | KR | Each hit in a string +3%, up to +9% (`StringRamp` 0.03) |
| AR_Duelist | Duelist | 3 | Keystone | 1×5 | AR_Blade | KR | +10% damage while only one enemy is within 20 studs (`DuelDamage` 0.10) |
| AR_Exec | Executioner | 3 | Upgrade | 1×4 | AR_Riposte, AR_Breaker | | Grip finisher 30% faster (`GripSpeed` +0.30) |
| AR_Mastery | Weapon Mastery | 3 | Passive | 2×3 | AR_Blade, AR_Marks | | Weapon passives +25% stronger (`WeaponPassive` +0.25) |

### Body

| Id | Name | Ring | Type | Ranks×Cost | Req | Fork | Effect |
|---|---|---|---|---|---|---|---|
| BO_Endure | Endurance | 1 | Passive | 3×1 | Core | | +10 max stamina (`MaxStamina` +10) |
| BO_Climb | Climber | 1 | Upgrade | 1×2 | Core | | Climb / wall-run stamina −20% (`ParkourCost` −0.20) |
| BO_Step | Quick Step | 1 | Upgrade | 2×2 | Core | | Dash cooldown −10% (`DashCooldown` −0.10) |
| BO_Tough | Toughness | 1 | Passive | 2×2 | BO_Endure | | Max HP +4% (`MaxHealth` +0.04) |
| BO_Compose | Composure | 1 | Passive | 1×2 | BO_Endure | | Posture recovers 20% faster (`PostureRegen` +0.20) |
| BO_Iron | Iron Skin | 2 | Passive | 1×3 | BO_Step | B1 | Damage taken −6% (`DamageTaken` −0.06) |
| BO_Light | Light Feet | 2 | Upgrade | 1×3 | BO_Step | B1 | Dash i-frames +0.05s (`DashIFrames` +0.05) |
| BO_Vigor | Vigor | 2 | Passive | 2×2 | BO_Tough | | Max HP +5% (`MaxHealth` +0.05). Vitality 8 |
| BO_Runner | Runner | 2 | Passive | 2×2 | BO_Climb | | Sprint speed +5% (`SprintSpeed` +0.05). Speed 8 |
| BO_Recover | Recovery | 2 | Passive | 1×3 | BO_Compose | | Stamina regen +20% (`StaminaRegen` +0.20) |
| BO_Heavy | Heavy Frame | 2 | Passive | 1×3 | BO_Runner | B2 | Knockback taken −30% (`KnockbackTaken` −0.30) |
| BO_Acro | Acrobat | 2 | Upgrade | 1×3 | BO_Runner | B2 | Wall runs 25% longer (`WallRunTime` +0.25) |
| BO_Second | Second Wind | 3 | Keystone | 1×5 | BO_Vigor | KB | Once per life, a knock recovers at 30% HP after 12s, instead of 15% after 20s (`SecondWind` 1) |
| BO_Unbroken | Unbroken | 3 | Keystone | 1×5 | BO_Vigor | KB | Posture recovers 50% faster; guard-break stun −25% (`PostureRegen` +0.5, `GuardBreakStun` −0.25) |
| BO_Fort | Fortitude | 3 | Passive | 2×3 | BO_Recover | | Damage taken −4% (`DamageTaken` −0.04) |

**Totals:**
- Ring 1: 60 MP. Ring 2: 71 MP (both fork sides). Ring 3: 56 MP (both sides). 49 nodes.
- **187 MP in the catalogue; 160 MP is the most one character can buy.**

## 5. Data and save

- **Registry:** `ReplicatedStorage.Modules.Data.Rensei.SkillTree`. It holds the catalogue (§4) plus each node's **position** (ring, angle) for the UI, and has helpers:
  - `SkillTree.CanBuy(Data, Id)`: one shared verdict, used by both server and UI (the same pattern as `Progression.GateCheck`). Returns ok and a reason.
  - `SkillTree.Modifiers(Data)`: the summed modifier table.
- **Save (SchemaVersion 1 → 2):**
  - `AlchemyTree` (empty everywhere) is renamed **`SkillTree`**: `[NodeId] = rank`.
  - Add **`Mastery.StageSpend`**: `[NodeId] = ranks bought this stage` (what a refund may undo).
  - The migration step must be added to Ye's `DataManager` **and** the Menu / Tutorial places' copies (`MenuData`, `FlowData`).
- **`Progression.MaxStage = 5`.**

## 6. Server

`ServerScriptService.SkillTreeService` serves one request, `Requests.SkillTree(Action, NodeId, ExpectedRank)`, where Action is `"Buy"` or `"Refund"`.

**Buy checks (in order):**
1. Profile loaded.
2. Out of combat: not in Combat Mode, and not hit in the last 5s.
3. The node exists, and its ring is open (`Mastery.Stage`).
4. A prerequisite is owned.
5. The fork is free.
6. The stat requirement is met.
7. The rank is below max, and the current rank equals `ExpectedRank`. A stale or double click is ignored, so nothing is ever bought twice.
8. `ProgressionService.SpendMastery(cost)`.

Then: rank += 1, `StageSpend[Id]` += 1, re-apply the modifiers, sync.

**Refund:**
- Only ranks in `StageSpend`.
- Never a node another owned node depends on (it must stay connected to the centre).
- The MP comes back through a new `ProgressionService.RefundMastery(cost)`, which reduces `Spent` and raises `Unspent`.

**On a trial pass** (`ProgressionService.CompleteTrial`): `StageSpend = {}`, which seals the stage.

All requests already go through `ServerHandler`'s per-player rate limiter.

## 7. Effects (how nodes change gameplay)

- `SkillTreeService` publishes `SkillTree.Modifiers` as **character attributes** `Mod_<Key>` on spawn and after every Buy / Refund. It does this through `ProgressionService.ApplyCharacter`, which already writes the derived stat caches.
- Each system reads only its own keys, with 0 / absent as the default:

| System | Keys |
|---|---|
| `AlchemyService` | Unlock X/C/V, <Slot>Damage, <Slot>Cooldown, ClapSpeed, HeldClapDamage, CastWalkSpeed, Windup, MeterRefund, BloodCast, OverflowDamage |
| `ResourceManager` / `ProgressionService` | MaxMeter, MaxStamina, StaminaRegen, PostureRegen, MaxHealth, MeterOnHit |
| `AttackRunner` / `FistSwing` / `Heavy` | FinisherDamage, LightDamage, StringRamp, HeavyCooldown, HeavyPosture, UppercutCooldown, FeintCost, DashAttackDamage |
| `DamageManager` | DamageTaken, KnockbackTaken, DuelDamage, Riposte, GuardBreakStun |
| `WeaponManager` | DrawSpeed, SkillCooldown, GunReload, GunRange, WeaponPassive |
| `Roll` / `JumpManager` | DashCooldown, DashIFrames, ParkourCost, SprintSpeed, WallRunTime |
| `DownedManager` | SecondWind, GripSpeed |

- **Move gating:** `AlchemyService.Cast` refuses a locked slot with a banner: "Unlock <move> in the Mastery tree."

## 8. UI

- **Mastery menu** on **K**, with a mobile button beside the other menu buttons.
- **The circle:**
  - Three rings and three sector dividers: Alchemy at the top, Arms lower-left, Body lower-right.
  - Nodes sit at their (ring, angle), with lines to their prerequisites.
  - Pan (drag), zoom (wheel / pinch), and recentre.
- **Header:**
  - Unspent MP, Stage n/5, stage progress (e.g. 12/20).
  - **Truth/Gate** status with the exact `GateCheck` reasons. "Begin trial" stays disabled until the trial exists.
- **Node states:**
  - owned: filled gold;
  - available: gold outline, pulsing;
  - locked: dim;
  - fork taken: struck through;
  - ring closed: the ring dimmed and labelled "Opens at Stage N".
- **Node card** (hover, or tap on mobile):
  - The name (the path's move name for slot upgrades), each rank's effect, and the cost.
  - Requirements ticked green or red.
  - **Buy / Refund** buttons, driven by the same `SkillTree.CanBuy` the server uses. A refusal shows the server's reason.
- **Feedback:** a purchase pulses gold along the link and plays a sound; the header updates at once.
- **Style:** Rensei UI (Guru font, gold on near-black, the existing panel art).

## 9. Testing

- **Server rules (Studio, test hook):** each of these must be refused with the right reason:
  - no MP; ring closed; prerequisite missing; fork taken; stat too low;
  - double click (`ExpectedRank`); buying in combat;
  - refunding a node something else depends on; refunding after a trial seal.
- **Effects:** measure in play before and after buying, for example:
  - Z damage (Z Potency); max stamina (Endurance); dash cooldown (Quick Step);
  - meter refund (Equivalent Exchange); move gating (X/C/V).
- **Save:** migration v1 → v2 on an old profile. Buy, rejoin, and check the purchases and the refund state.
- **UI:** PC and phone-sized screenshots; every node state; pan and zoom.

## 10. Dependencies and open items

- **The Truth/Gate trial isn't built.** Until it is, live players can't get past Stage 1, so rings 2–3 and the **V** move are out of reach. **The trial should be designed next, or alongside.** For testing, Studio can raise `Mastery.Stage` through the test hook.
- **Existing characters:** there are no live players (nothing is published), so there's no grandfathering. Test profiles start from Z only.
- **Balance:** every number is a proposal. Expect tuning after playtests.
- **Mobile:** the circle must fit a phone. If the radial view is too cramped, the same data can render as three columns (a fallback, not the plan).

# Earth Kit and Character Creation — Proposal

**Status:** APPROVED by the owner 2026-10-14 ("I like it"). Each decision in §3 took the recommended or safest option. Character creation is **built**, in a separate menu place as the owner asked: see `Start Flow and Character Creation.md`. The Earth kit is next. Numbers stay PROPOSAL until tuned.

**Sources:**
- The owner's older build in the Assets place:
  - `ServerStorage.AlchemyModules`: Earth Wall, Earth Rise, Earth Pillars, Shatter Point, Spike Lunge, Rising Thorn, Tectonic Shift.
  - `ServerScriptService.GameServices` (`Data`, `ServerEffects`).
  - `Workspace.Customization Stuff`.
- The master plan (§9 Character Creation).
- `ProfileData.Identity` and `Rensei.Clans` in Ye.

---

## 1. Earth kit

### 1.1 What the owner's prototypes do

These are from the older build. Damage there used a different health scale, so the numbers below are only a guide.

| Prototype | Cooldown | What it does | Old skill-XP cost |
|---|---|---|---|
| **Earth Wall** | 2s | A wall of the ground's own material rises 5 studs in front. It is solid cover; anyone caught in it takes a hit (10, 0.6s stun, knock-up). It lasts 60s; on sand it crumbles after 2s. | 50 |
| **Earth Rise** | 2s | A pillar rises under the caster and carries them high up (vertical mobility). | 500 |
| **Earth Pillars** | 6s | A line of pillars erupts ahead, every ~9 studs, out to 50 studs (×1.5 with the Philosopher's Stone). | 750 |
| **Shatter Point** | 3s | Cracks the ground and pulls up a throwable rock; also breaks alchemy walls. | 500 |
| **Spike Lunge** | 6s | Lifts a nearby rock (from Shatter Point), then punches it as a spiked projectile toward the cursor. On impact: 20 damage in a large radius, ragdoll 1s, knockback. | 600 |
| **Rising Thorn** | 5s | A slanted spike bursts out of the ground 5 studs ahead: damage, Bleed 10s, ragdoll, knockback. | 1000 |
| **Tectonic Shift** | 8s | A ring of 8 rock spikes erupts around the caster (radius ~8): damage and a 2s stun. A blocking target takes nothing. | 3500 |

Every prototype takes its colour and material from the ground it is cast on. Sand versions crumble or deal less damage. Every prototype also has a stronger version with the Philosopher's Stone (`Philo`).

### 1.2 Proposed Z / X / C / V

The kit follows the other kits' pattern: Z poke, X area or control, C utility, V ultimate. Earth's identity is **terrain control**: it changes the battlefield, gives cover and pins people in place.

| Slot | Ability (owner's name) | Form | Damage | CD | Cast | Class | Extras |
|---|---|---|---|---|---|---|---|
| **Z** | **Rising Thorn** | Ground spike at the aimed point (up to 18 studs) | 55 | 7 | 0.5 | BLOCKABLE | On hit: Bleed 3s (the existing Bleed status) and a short knock-up. The spike stays 2s as a small obstacle. |
| **X** | **Tectonic Shift** | Ring of spikes around the caster, radius 10 | 85 | 10 | 0.7 | BLOCKABLE | Stuns 1.2s (the prototype's "get off me" ring). The spikes stay 3s as a barrier around you. |
| **C** | **Earth Wall** | Wall rises in front (6 wide × 7 tall) | 30 on anyone it lifts | 12 | 0.4 | DEFENSIVE | Solid cover for 6s (prototype: 60s). It blocks movement and projectiles and can be **climbed** (the climb system already works on any wall). One wall at a time. |
| **V** | **Earth Pillars** | A line of pillars races forward 45 studs | 240 (3 hits: 60 + 60 + 120) | 26 | 1.3 | UNBLOCKABLE | Line telegraph (the existing `LineWarning`). Each pillar launches whoever it hits; the last hit throws them. |

**Sheet-style %HP columns** (580 HP at L1, 4000 at L20, as the sheet does):

| Ability | HpL1 | HpL20 |
|---|---|---|
| Rising Thorn | 0.0948 | 0.0138 |
| Tectonic Shift | 0.1466 | 0.0213 |
| Earth Wall (lift) | 0.0517 | 0.0075 |
| Earth Pillars | 0.4138 | 0.06 |

**How it compares with the built kits:** each slot sits in the same band as the other kits' matching slot. Z is 50–60, X is 85–110, the utility move deals little or no damage, and V is 235–300 on a 24–28s cooldown.

**Kept for later (skill-tree alternates, not in the base kit):**
- **Earth Rise:** mobility.
- **Shatter Point + Spike Lunge:** a two-step rock throw. It needs a "throwable rock" world object, which is a bigger system.
- The old skill-XP order is a starting point for the skill tree: Wall → Rise / Shatter → Spike Lunge → Pillars → Thorn → Tectonic.

### 1.3 Assets

The prototypes' own meshes can be reused, since they are the owner's assets: `Wall`, `Pillar`, `Rise`, `SpikePillar` and `Spike` MeshParts, the `EarthRise` sound, the `SandDismantle` particles and the `Cracked` decal. They would be copied from the Assets place, not rewritten.

- **VFX:** an `EarthElement` folder with the same layout as `FireElement`, built like the Ice, Wind and Metal ones.
- **Animations:** placeholders until the owner provides them, same as the other new kits.

### 1.4 "Stone Abilities" and the Marcoh restriction

`Clans` says Marcoh can't use **Stone Abilities**, but no ability is tagged "Stone" yet.

**Earth should not count as "Stone" by default.** In FMA, Marcoh is the Crystal Alchemist who researched **Philosopher's Stones**. The owner's prototypes all have a Philosopher's Stone (`Philo`) boost, and there is a `Sacrifice` module with a Philosopher's Stone UI. So "Stone Abilities" most likely means **Philosopher's Stone abilities** (boosted casts, Sacrifice), not rock alchemy. Tagging Earth "Stone" would make Marcoh unable to play one of the five paths.

→ Decision 1.

---

## 2. Character creation

### 2.1 What already exists

- **Ye, `ProfileData.Identity`:** `CharacterCreated`, `Clan`, `FreeClanRollUsed`, `PaidClanRolls`, `Affinity`, `Weapon`, `Appearance = {}`.
  - Nothing sets these yet.
  - Studio stands in for the affinity with `StudioTestAffinity`.
- **Ye, `Rensei.Clans`:** only Marcoh. Rolling is disabled until a roster exists. One free roll plus paid rerolls is CONFIRMED as a concept.
- **Assets place, `Customization Stuff`:**
  - **Eyes** 17, **Mouths** 25, **Eyebrows** 8 (decals on head parts).
  - **Fits** 19 outfits (shirt + pants): Alkahestry Tattoos, Alkahestry Apprentice, Aerugonian Prince ×2, Chemist Garbs, Ishvalan Fighter, Gods Fist Priest, Desert Vagabond, Alkahestry Master, Alchemical Council HR, Aerugonian General, Eastern Assassin, Southern Explorer, Aerugonian Pirate, Gods Fist Member, Eastern Traveller, Alchemical Council Hunter, Xerxian Merchant, Alchemical Countess.
  - **Hair:** six nation preset characters with hair meshes (Amestrian, Xingnese, Ishvalan, Aerugonian, Xerxian, Cretan), plus loose hair accessories.
- **Assets place, the owner's older build, `GameServices`:** a full identity system.
  - **Nations (races):** Ishvalan, Xingnese, Amestrian, Xerxian, Aerugonian, Drachman. Each sets:
    - **skin** (e.g. Ishvalan Nougat, Xerxian Buttermilk, Drachman Pastel yellow, the others Pastel brown);
    - **hair colour** (Ishvalan white, Amestrian Daisy orange, Aerugonian brown, Xerxian Cool yellow, Xingnese black, Drachman medium brown);
    - **eye style** (one per nation);
    - **clothing** (1–2 outfits per nation);
    - **family titles** (head family: Chieftain / Baron / Commander / Lord / Prince / Marshal; captain family: Archbishop / Viscount / Captain / Daimyo / Duke / Admiral).
  - The nation was **randomly assigned**, and a **character name** was generated from per-nation name lists.
  - Mouth and eyebrows were random, with an optional skin-colour override.
  - **Automail** arm / legs with wood and iron tiers (and limb health), **Blind** eyes, and a **Homunculi** race that keeps its past nation.

### 2.2 Proposed flow

This is shown once to any character with `CharacterCreated = false`. It is a full-screen menu in the Rensei UI style, and works on mobile.

1. **Origin (nation):** Ishvalan, Xingnese, Amestrian, Xerxian, Aerugonian, Drachman (the owner's list). It sets the default skin tone, hair colour, eye style and the suggested outfits. → Decisions 2–3.
2. **Appearance:**
   - skin tone, from a palette (the nation tones, plus more if approved);
   - hair style (the hair meshes) and hair colour (palette);
   - eyes, eyebrows and mouth (the 17 / 8 / 25 decals);
   - outfit (the 19 Fits);
   - markings (Alkahestry Tattoos is already a Fit; more could be added as overlays).
3. **Name:** typed with a filter, or generated from the nation's name list like the old build. → Decision 4.
4. **Alchemy path:** one of Flame / Ice / Earth / Wind / Metal. → Decision 5 (pick or roll).
5. **Lineage (clan):** the free roll happens here once a roster exists. Until then this step is hidden and the clan stays "".
6. **Starting weapon:** fists, or one Common weapon. It goes into the inventory and is equipped through `LoadoutService`. → Decision 6.
7. **Confirm:** sets `CharacterCreated = true`, saves and spawns.

### 2.3 Data model (all server-validated)

```lua
Identity = {
	CharacterCreated = false,
	Origin = "",              -- NEW: nation id ("" until creation)
	Name = "",                -- NEW: character name (filtered)
	Clan = "", FreeClanRollUsed = false, PaidClanRolls = 0,   -- existing
	Affinity = "",            -- existing: "Flame" | "Ice" | "Earth" | "Wind" | "Metal"
	Weapon = "",              -- existing: the starting-weapon choice ("" = fists)
	Appearance = {            -- existing table, now filled
		Version = 1,
		Skin = "", Hair = "", HairColor = "",
		Eyes = "", Brows = "", Mouth = "",
		Outfit = "", Markings = "",
	},
}
```

- **Allowed choices** live in one registry, `Modules.Data.Rensei.Customization`: the id → asset for each option, plus each nation's defaults. The server rejects any id that isn't in it.
- **Applying the look:** `AppearanceService` builds the character on every spawn from `Identity.Appearance` (face decals, hair, colours, clothing). The client only sends choices.
- **Existing characters** keep their stats, inventory and mastery. They see the creation screen once on their next join, because `CharacterCreated` is still false. No wipe and no migration loss.
- **Sensible defaults:** if a field is missing, the nation default fills it (or Amestrian if there's no nation).
- **No paid mechanics** are added. Paid clan rerolls stay unbuilt until the roster and purchase validation exist (the plan's rule).

### 2.4 Build order once approved

1. **C1:** `Customization` registry, Identity fields, server validation, copying the customization assets from the Assets place into Ye.
2. **C2:** `AppearanceService` (apply on spawn); tested with every option.
3. **C3:** the creation UI (PC + mobile); the existing-character path.
4. **E1:** the Earth kit (Z/X/C/V) on the AlchemyService pipeline, with the prototypes' meshes and an `EarthElement` VFX.

---

## 3. Decisions for the owner

1. **"Stone Abilities":** do they mean Philosopher's Stone abilities (recommended), or Earth / rock alchemy?
2. **Origin (nation):** keep the old build's six nations as a creation choice? Is Cretan (there is a Cretan preset) a seventh?
3. **Origin effects:** cosmetic only (defaults for skin, hair and eyes), or should nation also gate or suggest something else (family titles, story flags)?
4. **Name:** typed (filtered), generated from per-nation lists (the old build), or both?
5. **Alchemy path:** chosen freely, or rolled like the clan (free roll + rerolls)?
6. **Starting weapon:** fists only, or fists plus which Common weapons (Katana, Rapier, Caestus, Greatsword, Daggers, Renetti)?
7. **Old-build extras:** bring back automail, blindness or Homunculi as creation options, or leave them for story / later?
8. **Where creation happens:** in Ye on first join (recommended for now), or in the separate Character Customization place (123967384111466)?
9. **Earth kit:** approve the Z/X/C/V mapping and names (Rising Thorn, Tectonic Shift, Earth Wall, Earth Pillars), or swap any for Earth Rise / Spike Lunge?
10. **Earth Wall duration:** 6s (proposed, so it can't wall off an arena), or longer like the prototype (60s)?

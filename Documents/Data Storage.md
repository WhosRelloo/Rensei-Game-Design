# Rensei data storage (audit 2026-10-18)

How Rensei stores player data across its three places, what the audit after all phases found, and what was fixed. Owner request: "Completely audit and fix all datastorage after all phases".

## Stores

| Store | Kind | Key | Holds | Written by |
|---|---|---|---|---|
| `PlayerData` | ProfileService (session-locked, auto-save ~30 s) | `Data<UserId>` (slot 1), `Data<UserId>_S<n>` (slots 2–5) | one character: progression, inventory, story, morality, identities, etc. (`ProfileData` template) | Ye `DataManager`, Menu `MenuData`, Tutorial `FlowData` |
| `RenseiAccounts` | DataStore (`UpdateAsync`, cache bypassed on read) | `A<UserId>` | slots owned / selected / starred, purchase receipts (last 20), redeemed codes, Creator Plus | `SlotAccount` (identical in every place) |
| `RenseiLooks` | DataStore (`UpdateAsync`) | `L<UserId>` | Creator Plus saved looks (cleaned before storing) | Menu `LookPresets`; Studio keeps them in memory only |

There are no OrderedDataStores, MemoryStores or MessagingService.

## How a profile moves between places
1. **Main Menu.** It reads the slot summaries without a lock (`ViewProfileAsync`). When you pick a slot, it records the choice in `RenseiAccounts` and loads that slot with `ForceLoad`.
2. **Teleport.** Before teleporting, the place releases the profile and waits up to 6 s for the save to finish ("hop ready"). The next place loads the slot recorded in the account store, never one taken from teleport data. Teleport data only carries a flow tag.
3. **Loading.**
   - Migrations: every load runs `ProfileMigrations.Migrate` (identical in every place) before `Reconcile`.
   - Version: schema 4. Every section added since then is additive, and Reconcile fills it in on old saves.
4. **Opened elsewhere.** If a profile is opened on another server, this server kicks the player, so nothing gets played that can't be saved.

## Audit findings and fixes

| # | Finding | Risk | Fix |
|---|---|---|---|
| 1 | **No protection against unstorable values.** A DataStore can't hold NaN or infinite numbers, or Roblox values (Vector3, Instance, functions). One such value anywhere in a profile makes **every later save fail**, silently losing the session. | High (silent progress loss) | **`ProfileGuard`** (new, identical in every place). It repairs those values in place (a bad number becomes 0, an unstorable value is removed) and warns once per problem: when the profile loads, every 30 s, and right before every release. Tables mixing list and named keys are reported only. |
| 2 | **`GrantExp` let NaN through** (`NaN <= 0` is false). `GrantExp` / `GrantMoney` / `SpendMoney` accepted infinity, and `AddTraining` any multiplier. | High (feeds #1) | A finite-number check on all four. |
| 3 | **Reroll packs were reported "granted" before the profile saved.** A server that went down before the next auto-save lost the rolls, and Roblox would never retry. The receipt record (`Identity.RerollReceipts`) was also wiped by Gate permadeath. | Medium (paid items lost) | ProfileService's documented pattern: the purchase id goes in the profile's **MetaTags**, which survive a character wipe. The purchase is reported granted only once a save containing it is **confirmed** (otherwise "not processed yet", and Roblox retries). Old receipt ids are still honoured. Slot and Creator Plus purchases were already safe (saved to the account store before granting). |
| 4 | **The inventory had no size limit.** Each non-stacking reward adds an entry; a repeatable reward or an admin command could grow a save without bound. | Medium (save size / load time) | `ItemService` caps (PROPOSALS): 60 entries, 999 per stack, 25 per give. Gives are all or nothing (a reward is never half-paid), with a "Your bag is full" toast. |
| 5 | **The template differed between places.** Menu and Tutorial had an older `ProfileData` (no Identities, Styles, Automail, Binding, Fallen, Gate of Truth fields). Harmless while Reconcile only adds keys, but a slot created in the menu started without those sections until Ye filled them in. | Low | Rensei's template copied to the Menu and Tutorial (verified identical by hash), marked "KEEP THIS FILE THE SAME IN EVERY PLACE". |

## Checked and sound
- **Shared files:** `ProfileMigrations`, `SlotAccount`, `FlowTeleport`, `Places`, `Slots` and the ProfileService library are byte-identical in all three places.
- **Session handling:** the session lock, release before teleport, kick when opened elsewhere, a profile released if the player leaves mid-load, and the slot-account read failing safely (kick, never a guessed slot).
- **Account writes:** all through `UpdateAsync` with retries; receipts are idempotent.
- **Gate permadeath** resets the slot in place, keeping Settings, Flow, the clan-roll counters and the Fallen list.
- **Live saves (read-only scan of the owner's two slots):**
  - no NaN or infinite numbers, unstorable values, mixed or gappy tables;
  - 5.8 KB and 4.2 KB (the limit is 4 MB);
  - slot 1 released cleanly (no stale session lock).

## Tests (Studio Play, owner profile snapshotted and restored, verified equal to the saved copy)
- **`ProfileGuard`** on a broken table:
  - NaN, +inf and −inf → 0;
  - the Vector3 and the function removed;
  - the mixed table reported.
- **The real profile:** clean, no warnings.
- **Refused amounts:** `GrantExp(NaN)`, `GrantExp(inf)`, `GrantMoney(inf / NaN)` and `SpendMoney(NaN)` were all refused, and nothing changed.
- **Inventory caps:**
  - a give of 1,000 was clamped to 25 (11 → 36 entries);
  - the next give of 25 was refused (it would pass 60), and nothing was added;
  - a give of 5,000 to a stack was clamped to 25.
- **Reroll receipt:** **not yet run.** Studio's Play start hung in the Main Menu place. The code calls the receipt through a Studio-only hook (`MenuServer.StudioReceiptTest`) so it can be tested next session: it should wait for an auto-save, grant once, and grant nothing on a repeat.

## Limits / owner decisions
- **No user-id registration.** This ProfileService version has no `AddUserId`, the helper that lets a data-deletion request (GDPR) find a profile. Upgrading the library is a separate change; until then, an erasure request has to be handled by deleting the `Data<UserId>…` keys and `A<UserId>` / `L<UserId>` by hand.
- **Studio writes the real store** (by design: tests use your real profile, and every audit test snapshots and restores it). Switching Studio to ProfileService's mock store is a one-line option if you'd rather never touch real saves from Studio.
- **Cap numbers** (60 entries, 999 per stack, 25 per give) are PROPOSALS.

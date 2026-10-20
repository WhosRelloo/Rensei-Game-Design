# Player Trading: Design (approved, scheduled last)

**Date:** 2026-10-19.

**Status:** the design was approved by the owner ("Continue, but only put trading in after all of the plans"). **It will be built after every other planned project**: the animations, M1 timing, parry, admin panel and Tutorial sync passes, then the Morality × Reputation Plans 2–10. Nothing is built yet.

All numbers are **PROPOSAL**.

## Owner decisions
- **Tradable:** items (consumables, materials), weapons, money and cosmetics (when tradable cosmetics exist).
- **Some items are untradeable**, as in *VV: Ultimatum*.
- **Trades happen only at trading posts.**

## Where
- Trading Posts are tagged world spots (`RenseiTradePost`), one each in the City, the Foundry Yard and Lindenmoor to start. The owner places the exact spots.
- Both players must be at the same post (within about 15 studs), out of Combat Mode and not downed.
- Leaving the radius, entering combat, getting knocked or leaving the game cancels the trade.

## Flow
1. At a post, a player requests a trade with another player at the same post; the other accepts or declines.
2. A trade window opens.
   - Each side offers up to 8 entries: an item or a stack amount, a weapon, or money.
   - Each side sees the other's offer live.
3. Any change to either offer clears both sides' **Ready**.
4. When both are Ready, a final confirm screen lists both sides. **Confirm** unlocks after a 3 s countdown.
5. Then the server validates everything again and swaps both sides at once, or nothing happens. It checks:
   - every item still exists in its owner's inventory (by `ItemID`) and is tradeable;
   - an equipped weapon must be unequipped first;
   - the receiving inventory stays within the ItemService caps (60 entries, 999 per stack);
   - money is enough, with finite-number checks (ProgressionService rules).

## Untradeable items
- Add `Tradeable = false` to ItemData entries. Tooltips show "Untradeable".
- Proposed list (the owner adjusts it): quest items, evidence, keys, Automail parts, starter gear.

## Safety
- A 10 s cooldown between trades per player.
- Minimum level 5 to trade, against alt-account farming.
- Both profiles are saved right after a trade, so a crash between the two saves can't duplicate an item. Implementation note: write the trade id into both profiles' MetaTags, as with the reroll receipts. On load, a half-applied trade is detected and reconciled.

## Logging and admin
- Every completed trade goes to a trade log (DataStore `RenseiTrades`, keyed by trade id) with both sides' item ids and amounts.
- Each player's profile keeps their last 20 trades.
- The admin panel gets a **Trades** tab: search by player, view details, and **rollback** a trade while both players still hold the traded items.
- Trades post to the Discord staff log (the Secrets-based webhook from the admin-panel project).

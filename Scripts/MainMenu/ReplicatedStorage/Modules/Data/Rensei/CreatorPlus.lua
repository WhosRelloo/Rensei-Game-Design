-- Creator Plus (owner 2026-10-18: "more QOL features for character customization, with some behind a
-- paywall for more accessibility (NO ACCESSORIES)"). One Game Pass. Everything here is PROPOSAL.
--   Free for everyone: undo / redo, random look, reset look (MenuClient).
--   Creator Plus: a custom skin colour (a colour wheel instead of only the 8 swatches) and saved looks
--   (LookSlots looks kept on the account, loadable into any new character).
-- Cosmetic only: no stats, no accessories.
local CreatorPlus = {}

-- How it's sold. The owner made it a Developer Product (2026-10-18, "Creator Plus", 100 R$): bought once,
-- recorded on the player's account (SlotAccount.GrantPlus, receipt-checked) and kept in every slot.
-- A Game Pass ID also works (PassId); either one unlocks it. 0 = not used.
CreatorPlus.ProductId = 3719583889
CreatorPlus.PassId = 0

-- Studio test only: treat the tester as an owner while neither ID is set, so the paid options can be
-- tried. Never applies on a live server.
CreatorPlus.StudioOwns = true

CreatorPlus.LookSlots = 3 -- PROPOSAL

return CreatorPlus

-- Creator Plus (owner 2026-10-18: "more QOL features for character customization, with some behind a
-- paywall for more accessibility (NO ACCESSORIES)"). One Game Pass. Everything here is PROPOSAL.
--   Free for everyone: undo / redo, random look, reset look (MenuClient).
--   Creator Plus: a custom skin colour (a colour wheel instead of only the 8 swatches) and saved looks
--   (LookSlots looks kept on the account, loadable into any new character).
-- Cosmetic only: no stats, no accessories.
local CreatorPlus = {}

-- TODO(owner): create the Game Pass in the Creator Dashboard and put its ID here. 0 = not set up: the
-- paid options show as locked and buying says so.
CreatorPlus.PassId = 0

-- Studio test only: treat the tester as an owner while PassId is 0, so the paid options can be tried.
-- Never applies on a live server.
CreatorPlus.StudioOwns = true

CreatorPlus.LookSlots = 3 -- PROPOSAL

return CreatorPlus

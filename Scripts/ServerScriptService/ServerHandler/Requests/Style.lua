-- Pick a style for the class you're fighting as (Rensei.Styles; the Mastery menu's Class tab). The client
-- sends only a style id; StyleService validates it (belongs to the current class, available, out of combat,
-- free to act) and saves it. Rate-limited by the ServerHandler request limiter.
local ServerScriptService = game:GetService("ServerScriptService")
local StyleService = require(ServerScriptService.StyleService)
local UIService = require(ServerScriptService.UIService)

return function(Player, Id)
	local Ok, Message = StyleService.Select(Player, Id)
	if not Ok and Message then UIService.Notify(Player, "Toast", {Text = Message}) end
end

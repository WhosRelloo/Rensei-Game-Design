-- Hostage (hostages plan, 2026-10-27): the client asks to take a player hostage, choose from the captor menu, or
-- struggle. Typed here; every rule is HostageService's. PvP only: an NPC is refused there, first.
return function(Player, Action, A, B)
	if type(Action) ~= "string" then return end
	local HS = require(game:GetService("ServerScriptService").HostageService)
	if Action == "Take" then
		if typeof(A) ~= "Instance" or not A:IsA("Model") then return end
		HS.Take(Player, A)
	elseif Action == "Menu" then
		if type(A) ~= "string" then return end
		HS.Menu(Player, A, type(B) == "number" and B or nil)
	elseif Action == "Struggle" then
		if type(A) ~= "number" then return end
		HS.Struggle(Player, A)
	end
end

-- Takedown (assassinations, 2026-10-25): the client asks to knock out or assassinate an enemy. Typed here; every rule
-- is TakedownService's. PvE only: a player's character is refused there, first.
return function(Player, Kind, Target)
	if type(Kind) ~= "string" or typeof(Target) ~= "Instance" or not Target:IsA("Model") then return end
	require(game:GetService("ServerScriptService").TakedownService).Request(Player, Kind, Target)
end

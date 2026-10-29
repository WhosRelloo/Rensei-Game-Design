-- Hostage (hostages plan, 2026-10-27): the client asks to take a player hostage, choose from the captor menu, or
-- struggle. Typed here; every rule is HostageService's. PvP only: an NPC is refused there, first.
-- (Task 5 fix, ruling K1) switched off until the owner's go-live step (Changelog 2026-10-29): while
-- Rensei.Hostage.Enabled is false, every request is refused, except in a Studio TestNoSave session (the tests' bypass,
-- HostageService.Allowed). IsStudio is asked first, so a live server never gets past it.
local RunService = game:GetService("RunService")
local Hostage = require(game:GetService("ReplicatedStorage").Modules.Data.Rensei.Hostage)

return function(Player, Action, A, B)
	if type(Action) ~= "string" then return end
	if Hostage.Enabled ~= true and not RunService:IsStudio() then return end
	local HS = require(game:GetService("ServerScriptService").HostageService)
	if not HS.Allowed() then return end
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

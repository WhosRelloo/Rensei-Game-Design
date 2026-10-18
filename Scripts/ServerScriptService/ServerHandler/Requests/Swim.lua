-- Swim sprint toggle (owner 2026-10-18, swimming extras). The client sends only on / off. The server owns the
-- character attribute SwimSprint: on only while in the server's Swim state with enough stamina
-- (TuningConfig.Swim.SprintMinStamina); SwimService drains stamina while it's on and clears it when stamina
-- runs out or the swim ends. The client raises its own swim speed only while the attribute is set.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ResourceManager = require(ReplicatedStorage.Modules.Managers.ResourceManager)
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig).Swim

return function(Player, On)
	local Character = Player.Character
	if not Character or type(On) ~= "boolean" then return end
	if not On then Character:SetAttribute("SwimSprint", nil) return end
	if Character:GetAttribute("Traversal") ~= "Swim" then return end
	if ResourceManager.Get(Character, "Stamina") < Tuning.SprintMinStamina then return end
	Character:SetAttribute("SwimSprint", true)
end

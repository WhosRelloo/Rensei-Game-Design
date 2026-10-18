-- The Mastery skill tree (Modules.UI.MasteryUI): ("Buy", NodeId, ExpectedRank) / ("Refund", NodeId), and the
-- class-skill loadout: ("Equip", NodeId, Slot) / ("Unequip", Family, Slot).
-- SkillTreeService decides; the outcome goes back to the client as RequestRemote("SkillTree", Ok,
-- Reason, NodeId) and refusals also show as a toast.
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillTreeService = require(ServerScriptService.SkillTreeService)
local UIService = require(ServerScriptService.UIService)

return function(Player, Action, Id, ExpectedRank)
	local Ok, Why
	if Action == "Buy" then
		Ok, Why = SkillTreeService.Buy(Player, Id, ExpectedRank)
	elseif Action == "Refund" then
		Ok, Why = SkillTreeService.Refund(Player, Id)
	elseif Action == "Equip" then
		Ok, Why = SkillTreeService.Equip(Player, Id, ExpectedRank) -- (the third argument is the slot here)
	elseif Action == "Unequip" then
		Ok, Why = SkillTreeService.Unequip(Player, Id, ExpectedRank) -- Id = the family, then the slot
	else
		return
	end
	if not Ok and Why and Why ~= "Out of date" then UIService.Notify(Player, "Toast", {Text = Why}) end
	ReplicatedStorage.Remotes.RequestRemote:FireClient(Player, "SkillTree", Ok == true, Why, Id)
	return Ok, Why
end

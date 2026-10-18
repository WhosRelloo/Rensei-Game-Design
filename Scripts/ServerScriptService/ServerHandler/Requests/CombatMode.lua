-- Combat Mode toggle. The server owns the state (character attribute CombatMode); attacks from a
-- player who is not in Combat Mode deal no damage (HitboxManager).
return function(Player, Enabled)
	local Character = Player.Character
	if not Character or type(Enabled) ~= "boolean" then return end
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid or Humanoid.Health <= 0 then return end
	-- no fighting in deep water (owner decision 6, 2026-10-18): Combat Mode can't be turned on while swimming
	if Enabled and Character:GetAttribute("Traversal") == "Swim" then return end
	Character:SetAttribute("CombatMode", Enabled)
	if not Enabled then Character:SetAttribute("ShootingMode", nil) end -- guns' shooting mode ends with it
	if Enabled then
		-- a held hotbar item (not the weapon) is put away when fighting starts (Requests.HoldItem)
		local LoadoutService = require(game:GetService("ServerScriptService").LoadoutService)
		for _, Tool in ipairs(Character:GetChildren()) do
			if Tool:IsA("Tool") and not LoadoutService.IsWeapon(Tool.Name) then Tool:Destroy() end
		end
	end
end

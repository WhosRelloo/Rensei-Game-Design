-- Guns: the client sends its camera direction right before a shot. WeaponManager validates it
-- (unit vector, not behind the character) and only uses it for the next ~2 seconds.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponManager = require(ReplicatedStorage.Modules.Managers.WeaponManager)

return function(Player, Direction)
	local Character = Player.Character
	if not Character then return end
	local Weapon = WeaponManager.Def(Character)
	if not Weapon or not Weapon.Ranged then return end
	WeaponManager.SetAim(Character, Direction)
end

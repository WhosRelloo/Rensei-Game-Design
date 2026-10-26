-- Guns: the client sends its camera direction right before a shot. WeaponManager validates it
-- (GunAim.Validate: unit-ish, within MaxYaw / MaxPitch) and only uses it for the next TuningConfig
-- Weapons.Guns.Aim.AimFresh seconds; a refused aim fires nothing in that time (gun rework 2026-10-25).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponManager = require(ReplicatedStorage.Modules.Managers.WeaponManager)

return function(Player, Direction)
	local Character = Player.Character
	if not Character then return end
	local Weapon = WeaponManager.Def(Character)
	if not Weapon or not Weapon.Ranged then return end
	WeaponManager.SetAim(Character, Direction)
end

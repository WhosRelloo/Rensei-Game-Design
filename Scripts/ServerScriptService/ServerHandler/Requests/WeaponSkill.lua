-- G (rebindable) = the held weapon's skill (TuningConfig.Weapons.<Class>.Skill): stamina cost and a
-- short cooldown, run through AttackRunner like every other attack. Combat Mode only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Managers = ReplicatedStorage.Modules.Managers
local States = ReplicatedStorage.Modules.Skills.States

local WCS = require(ReplicatedStorage.Modules.Framework.WCS)
local AttackRunner = require(Managers.AttackRunner)
local ResourceManager = require(Managers.ResourceManager)
local MoverManager = require(Managers.MoverManager)
local WeaponManager = require(Managers.WeaponManager)
local Stun = require(States.Stun)
local Attacking = require(States.Attacking)
local Blocking = require(States.Blocking)
local Climbing = require(States.Climbing)

return function(Player)
	local Character = Player.Character
	if not Character or Character:GetAttribute("CombatMode") ~= true then return end
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid or Humanoid.Health <= 0 then return end
	local Weapon = WeaponManager.Def(Character)
	if not Weapon or not Weapon.Skill then return end
	local WCSCharacter = WCS.Character.GetCharacterFromInstance(Character)
	if not WCSCharacter or AttackRunner.IsRunning(Character)
		or WCSCharacter:HasStatusEffects({Stun, Attacking, Blocking, Climbing}) then
		return
	end
	if Weapon.Ranged and not WeaponManager.CanFire(Character) then return end
	-- a gun skill with a fresh refused aim would fire nothing: it spends nothing either -- no stamina, cooldown or
	-- animation (gun rework final fix A2, spec 5.1.6)
	if Weapon.Ranged and WeaponManager.AimRefused(Character) then return end

	local Skill = Weapon.Skill
	local Now = workspace:GetServerTimeNow()
	if (Character:GetAttribute("WeaponSkillReadyAt") or 0) > Now then return end
	if not ResourceManager.Spend(Character, "Stamina", Skill.Stamina or 0) then return end
	-- Weapon Art (skill tree): shorter weapon-skill cooldown
	local Cooldown = Skill.Cooldown * require(Managers.SkillMods).Mult(Character, "SkillCooldown")
	Character:SetAttribute("WeaponSkillReadyAt", Now + Cooldown)
	Character:SetAttribute("WeaponSkillCooldown", Cooldown)
	Character:SetAttribute("WeaponSkillName", Skill.Name)

	local Def = WeaponManager.Resolve(Character, Skill)
	AttackRunner.Run(WCSCharacter, Def, Weapon.Class .. "_Skill", {
		WalkSpeed = Skill.WalkSpeed,
		Strike = Weapon.Ranged and WeaponManager.Fire or nil,
		OnStartup = Skill.Lunge and function()
			MoverManager.CreateMover(Character, "Lunge", {Speed = Skill.Lunge, D = Skill.LungeTime})
		end or nil,
	})
end

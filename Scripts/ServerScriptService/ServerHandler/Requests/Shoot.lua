-- Guns' SHOOTING MODE (owner 2026-10-17). M1 with a gun is always the pistol whip (FistSwing); shooting is a
-- separate, deliberate mode:
--   ("Mode", On)      Y (rebindable "Aim") or the mobile AIM button: enter / leave shooting mode. Only with a
--                     gun drawn in Combat Mode. The server owns the state: character attribute ShootingMode.
--   ("Fire", AimDir)  RMB while in shooting mode (or the mobile FIRE button): one hitscan shot through
--                     AttackRunner + WeaponManager.Fire (range, raycast, block / parry rules, damage). The
--                     server checks the mode, the gun, Combat Mode, that you're free to act, a round in the
--                     magazine and not reloading. Fire rate = the gun's Recovery (one attack at a time).
-- Ammo: per-gun magazines (TuningConfig.Weapons.Guns.Items), automatic reload when empty (Decisions.md: no
-- reload button). The mode ends by itself when Combat Mode ends, the gun is put away or changed, or the
-- character is knocked, gripped, carried, swims or dies.
-- Gun rework 2026-10-25 (Task 5): Fire has its own per-player limiter (GunAim.Limiter, Aim.FireRate / FireBurst); its aim is
-- validated first (WeaponManager.SetAim) and an invalid aim returns before AttackRunner: no animation, no round. A Fire whose
-- aim turned more than Aim.SnapDeg from the previous Fire's within Aim.SnapWindow adds 1 to the character's GunSnapCount
-- attribute (a log only).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Managers = ReplicatedStorage.Modules.Managers
local States = ReplicatedStorage.Modules.Skills.States
local WCS = require(ReplicatedStorage.Modules.Framework.WCS)
local AttackRunner = require(Managers.AttackRunner)
local WeaponManager = require(Managers.WeaponManager)
local MovementState = require(Managers.MovementState)
local Stun = require(States.Stun)
local Attacking = require(States.Attacking)
local Blocking = require(States.Blocking)
local Climbing = require(States.Climbing)
local GunAim = require(ReplicatedStorage.Modules.Data.Rensei.GunAim)
local Cfg = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig).Weapons.Guns.Aim

local NextShot = {} -- [Character] = shot animation index
local LastFire = {} -- [Character] = {Dir, At}: the previous Fire's aim (the snap log)
local AllowFire, ForgetFire = GunAim.Limiter(Cfg.FireRate, Cfg.FireBurst)
Players.PlayerRemoving:Connect(ForgetFire)

local function GunReady(Character)
	local W = WeaponManager.Def(Character)
	return W ~= nil and W.Shots ~= nil and Character:GetAttribute("CombatMode") == true
		and Character:GetAttribute("WeaponDrawn") ~= false
end

-- the mode ends by itself: Combat Mode off, gun away / changed, knocked / gripped / carried, in the water, death
local function Watch(Character)
	local function Check()
		if not Character:GetAttribute("ShootingMode") then return end
		local Humanoid = Character:FindFirstChildOfClass("Humanoid")
		if not GunReady(Character) or MovementState.Blocked(Character) or not Humanoid or Humanoid.Health <= 0
			or Character:GetAttribute("Traversal") == "Swim" then -- spec B7: no shooting while swimming
			Character:SetAttribute("ShootingMode", nil)
		end
	end
	for _, A in ipairs({"CombatMode", "Weapon", "WeaponDrawn", "Knocked", "GrippedBy", "CarriedBy", "Carrying", "Gripping", "Traversal"}) do
		Character:GetAttributeChangedSignal(A):Connect(Check)
	end
	local Humanoid = Character:WaitForChild("Humanoid", 10)
	if Humanoid then Humanoid.Died:Connect(function() Character:SetAttribute("ShootingMode", nil) end) end
	Character.AncestryChanged:Connect(function(_, Parent) if not Parent then NextShot[Character], LastFire[Character] = nil, nil end end)
end
local function Hook(P)
	P.CharacterAdded:Connect(Watch)
	if P.Character then task.spawn(Watch, P.Character) end
end
for _, P in ipairs(Players:GetPlayers()) do Hook(P) end
Players.PlayerAdded:Connect(Hook)

return function(Player, Action, Arg)
	local Character = Player.Character
	if not Character then return end
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid or Humanoid.Health <= 0 then return end

	if Action == "Mode" then
		local On = Arg == true
		if On and (not GunReady(Character) or MovementState.Blocked(Character)) then return end
		Character:SetAttribute("ShootingMode", On or nil)
		return
	end
	if Action ~= "Fire" then return end
	if not AllowFire(Player, os.clock()) then return end
	if not Character:GetAttribute("ShootingMode") or not GunReady(Character) then return end
	if MovementState.Blocked(Character) or MovementState.Get(Character) then return end
	local WCSCharacter = WCS.Character.GetCharacterFromInstance(Character)
	if not WCSCharacter or AttackRunner.IsRunning(Character)
		or WCSCharacter:HasStatusEffects({Stun, Attacking, Blocking, Climbing}) then
		return
	end
	if not WeaponManager.CanFire(Character) then return end
	local Dir = WeaponManager.SetAim(Character, Arg) -- validated there (GunAim.Validate); refused: no shot, no round
	if not Dir then return end
	-- the snap log: a turn over SnapDeg within SnapWindow of the previous Fire
	local Now = os.clock()
	local Last = LastFire[Character]
	if Last and Now - Last.At < Cfg.SnapWindow
		and math.deg(math.acos(math.clamp(Last.Dir:Dot(Dir), -1, 1))) > Cfg.SnapDeg then
		Character:SetAttribute("GunSnapCount", (Character:GetAttribute("GunSnapCount") or 0) + 1)
	end
	LastFire[Character] = {Dir = Dir, At = Now}
	local Weapon = WeaponManager.Def(Character)
	local Index = (NextShot[Character] or 0) % #Weapon.Shots + 1
	NextShot[Character] = Index
	AttackRunner.Run(WCSCharacter, WeaponManager.Resolve(Character, Weapon.Shots[Index]), Weapon.Class .. "_Shot" .. Index, {
		WalkSpeed = 10,
		Strike = function(...)
			-- a gunshot is the loudest thing there is (Plan 2: NoiseService, optional for the Tutorial)
			local Noise = game:GetService("ServerScriptService"):FindFirstChild("NoiseService")
			local Root = Character:FindFirstChild("HumanoidRootPart")
			if Noise and Root then task.spawn(pcall, function() require(Noise).Emit(Root.Position, "Gunshot", Character) end) end
			return WeaponManager.Fire(...)
		end,
	})
end

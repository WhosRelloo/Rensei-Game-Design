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
-- validated first (WeaponManager.SetAim) and an invalid aim returns before AttackRunner: no animation, no round. An aimed
-- Fire request whose aim turned more than Aim.SnapDeg from the previous one's within Aim.SnapWindow adds 1 to the
-- character's GunSnapCount attribute (a log only; checked before the mode gates). Shooting mode can't be turned on in water.
-- The flick grace (Ruling 28, PROPOSAL): a Fire refused only because its yaw is past Aim.MaxYaw (GunAim.Validate's "behind")
-- is held -- one per character, a newer Fire request replaces it -- and its aim re-checked each Heartbeat for up to
-- Aim.FlickGrace s, because the server's copy of a client-owned root lags its turn by about 0.2-0.27 s. Accepted: it goes
-- on through the same gates as an immediately valid request; still refused: dropped. Nothing is spent while it waits.
-- The hold re-checks with the pure GunAim.Validate against the server's facing and calls SetAim once, when it passes, so
-- it never overwrites a newer valid aim (a Requests.Aim) with a refused one; a Mode request drops it (final fix A3,
-- Ruling 29).
-- The shot ticket (final fix A1): an accepted Fire request's validated aim and its rewind time (WeaponManager.RewindAt,
-- taken when the request is accepted -- for a held flick, when the hold accepts it) go to WeaponManager.Fire with the
-- strike, so the shot is tested where the shooter saw things when they fired, not a Startup later.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

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
local Pending = {} -- [Character] = token of the Fire request held by the flick grace
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
	-- (Holding / HeldBy: hostages Task 10, so the check runs when a hold starts; MovementState.Blocked refuses both)
	for _, A in ipairs({"CombatMode", "Weapon", "WeaponDrawn", "Knocked", "GrippedBy", "CarriedBy", "Carrying", "Gripping", "Traversal",
		"Holding", "HeldBy"}) do
		Character:GetAttributeChangedSignal(A):Connect(Check)
	end
	local Humanoid = Character:WaitForChild("Humanoid", 10)
	if Humanoid then Humanoid.Died:Connect(function() Character:SetAttribute("ShootingMode", nil) end) end
	Character.AncestryChanged:Connect(function(_, Parent)
		if not Parent then NextShot[Character], LastFire[Character], Pending[Character] = nil, nil, nil end
	end)
end
local function Hook(P)
	P.CharacterAdded:Connect(Watch)
	if P.Character then task.spawn(Watch, P.Character) end
end
for _, P in ipairs(Players:GetPlayers()) do Hook(P) end
Players.PlayerAdded:Connect(Hook)

-- a Fire request whose aim SetAim accepted (At: its rewind time): the snap log, then the gates and the shot
local function Fire(Character, Dir, At)
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid or Humanoid.Health <= 0 then return end
	-- the snap log (Ruling 13: before the mode / AttackRunner gates, so every aimed Fire request is compared with the
	-- previous one): a turn over SnapDeg within SnapWindow of the previous aimed Fire. A log only.
	local Now = os.clock()
	local Last = LastFire[Character]
	if Last and Now - Last.At < Cfg.SnapWindow
		and math.deg(math.acos(math.clamp(Last.Dir:Dot(Dir), -1, 1))) > Cfg.SnapDeg then
		Character:SetAttribute("GunSnapCount", (Character:GetAttribute("GunSnapCount") or 0) + 1)
	end
	LastFire[Character] = {Dir = Dir, At = Now}
	if not Character:GetAttribute("ShootingMode") or not GunReady(Character) then return end
	if MovementState.Blocked(Character) or MovementState.Get(Character) then return end
	local WCSCharacter = WCS.Character.GetCharacterFromInstance(Character)
	if not WCSCharacter or AttackRunner.IsRunning(Character)
		or WCSCharacter:HasStatusEffects({Stun, Attacking, Blocking, Climbing}) then
		return
	end
	if not WeaponManager.CanFire(Character) then return end
	local Weapon = WeaponManager.Def(Character)
	local Index = (NextShot[Character] or 0) % #Weapon.Shots + 1
	NextShot[Character] = Index
	local Ticket = {Dir = Dir, At = At}
	AttackRunner.Run(WCSCharacter, WeaponManager.Resolve(Character, Weapon.Shots[Index]), Weapon.Class .. "_Shot" .. Index, {
		WalkSpeed = 10,
		Strike = function(C, Name, Def)
			-- a gunshot is the loudest thing there is (Plan 2: NoiseService, optional for the Tutorial)
			local Noise = game:GetService("ServerScriptService"):FindFirstChild("NoiseService")
			local Root = Character:FindFirstChild("HumanoidRootPart")
			if Noise and Root then task.spawn(pcall, function() require(Noise).Emit(Root.Position, "Gunshot", Character) end) end
			return WeaponManager.Fire(C, Name, Def, Ticket)
		end,
	})
end

-- the flick grace: the same aim re-checked each Heartbeat (the pure GunAim.Validate against the root's facing) until it
-- passes -- then SetAim once and Fire, rewound from that moment -- or FlickGrace runs out
local function Hold(Character, Arg)
	local Token = {}
	Pending[Character] = Token
	task.spawn(function()
		local Until = os.clock() + Cfg.FlickGrace
		while os.clock() < Until do
			RunService.Heartbeat:Wait()
			if Pending[Character] ~= Token or not Character.Parent then return end
			local Root = Character:FindFirstChild("HumanoidRootPart")
			if Root and GunAim.Validate(Arg, Root.CFrame.LookVector, Cfg.MaxYaw, Cfg.MaxPitch) then
				Pending[Character] = nil
				local Dir = WeaponManager.SetAim(Character, Arg)
				if Dir then Fire(Character, Dir, WeaponManager.RewindAt(Character)) end
				return
			end
		end
		if Pending[Character] == Token then Pending[Character] = nil end
	end)
end

return function(Player, Action, Arg)
	local Character = Player.Character
	if not Character then return end
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid or Humanoid.Health <= 0 then return end

	if Action == "Mode" then
		Pending[Character] = nil -- a held Fire request goes with any Mode request (final fix A3)
		local On = Arg == true
		if On and (not GunReady(Character) or MovementState.Blocked(Character) or Character:GetAttribute("Traversal") == "Swim") then return end
		Character:SetAttribute("ShootingMode", On or nil)
		return
	end
	if Action ~= "Fire" then return end
	if not AllowFire(Player, os.clock()) then return end
	Pending[Character] = nil -- a newer Fire request replaces a held one
	local At = WeaponManager.RewindAt(Character) -- the ticket's rewind time: now, when the request arrives (final fix A1)
	local Dir = WeaponManager.SetAim(Character, Arg) -- validated there (GunAim.Validate); refused: no shot, no round
	if not Dir then
		-- refused only for its yaw (form, length and pitch passed): the flick grace
		local Root = Character:FindFirstChild("HumanoidRootPart")
		local _, Why = GunAim.Validate(Arg, Root and Root.CFrame.LookVector or Vector3.zero, Cfg.MaxYaw, Cfg.MaxPitch)
		if Root and Why == "behind" and (Cfg.FlickGrace or 0) > 0 then Hold(Character, Arg) end
		return
	end
	Fire(Character, Dir, At)
end

-- One light-attack input. Picks the variant, then runs it through AttackRunner:
--   Ctrl + LMB (queued by Requests.Uppercut) -> Uppercut (launch -> air juggle), ground or air
--   in an air juggle         -> next light hit, in the air
--   airborne                 -> Aerial    (hover, then forward dive slam)
--   running fast             -> Dash Attack (Hold Shift + LMB)
--   otherwise                -> next hit of the light combo: the held weapon's (TuningConfig.Weapons)
--                               or the fist combo when unarmed -- or the active STYLE's combo
--                               (Rensei.Styles: Boxing / Lethwei bare-handed). With a gun it's the PISTOL WHIP string:
--                               M1 never shoots (shooting is its own mode: Y, then RMB; Requests.Shoot).
-- The combo carries on through hits AND whiffs (holding / clicking into the air plays the whole
-- string; owner request 2026-10-14); an interrupt or a pause (Light.ComboReset) resets it. A FEINT keeps its
-- place (2026-10-18): the feinted hit comes next. Resetting on a feint let 1-2-3-feint-1-2-3 restart inside
-- hit 3's stun and never reach the finisher ("no infinite combos").
-- A whiff still costs the extra whiff recovery (AttackRunner).
-- All numbers: TuningConfig.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Managers = ReplicatedStorage.Modules.Managers
local States = ReplicatedStorage.Modules.Skills.States

local MoverManager = require(Managers.MoverManager)
local AnimationManger = require(Managers.AnimationManager)
local AttackRunner = require(Managers.AttackRunner)
local ResourceManager = require(Managers.ResourceManager)
local WeaponManager = require(Managers.WeaponManager)
local WCS = require(ReplicatedStorage.Modules.Framework.WCS)
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)
local Styles = require(ReplicatedStorage.Modules.Data.Rensei.Styles)
local SwingVFX = require(ReplicatedStorage.Modules.Effects.Combat.LightSwing)
local Attacking = require(States.Attacking)
local Stun = require(States.Stun)
local Blocking = require(States.Blocking)
local AirCombo = require(States.AirCombo)

local FistSwing = WCS.RegisterSkill("FistSwing")

local GroundParams = RaycastParams.new()
GroundParams.FilterType = Enum.RaycastFilterType.Exclude

local function Airborne(Character, Depth)
	local Root = Character:FindFirstChild("HumanoidRootPart")
	if not Root then return false end
	GroundParams.FilterDescendantsInstances = {Character, workspace.World.Visuals, workspace.World.Live}
	return workspace:Raycast(Root.Position, Vector3.new(0, -(Depth or 4.5), 0), GroundParams) == nil
end

local function HorizontalSpeed(Character)
	local Root = Character:FindFirstChild("HumanoidRootPart")
	if not Root then return 0 end
	local V = Root.AssemblyLinearVelocity
	return Vector3.new(V.X, 0, V.Z).Magnitude
end

-- cooldown + stamina gate shared by the special variants. ModKey: the skill tree's cooldown
-- modifier for this variant (e.g. Uppercutter).
local function Ready(Character, Key, Def, ModKey)
	local Now = workspace:GetServerTimeNow()
	if (Character:GetAttribute(Key) or 0) > Now then return false end
	if Def.Stamina and not ResourceManager.Spend(Character, "Stamina", Def.Stamina) then return false end
	local Cooldown = (Def.Cooldown or 0) * (ModKey and require(Managers.SkillMods).Mult(Character, ModKey) or 1)
	Character:SetAttribute(Key, Now + Cooldown)
	return true
end

function FistSwing:OnConstructServer()
	self:SetMetadata(0) -- current combo index
	self.MutualExclusives = {Stun, Attacking, Blocking}
	self.LastEnded = 0
	self.CheckOthersActive = false
	self.CheckedByOthers = false
end

function FistSwing:OnConstructClient()
	local Character = self.Character.Instance
	self.MetadataChanged:Connect(function()
		for _, Anim in pairs(AnimationManger.GetPlayingAnims(Character)) do
			if string.find(tostring(Anim), "Uptilt") then Anim:Stop() end
		end
	end)
end

function FistSwing:OnStartServer()
	local Character = self.Character.Instance
	local Root = Character:FindFirstChild("HumanoidRootPart")
	if not Root then return end

	-- Uppercut (Ctrl + LMB): the server queued it (Requests.Uppercut).
	if Character:GetAttribute("UppercutQueued") then
		Character:SetAttribute("UppercutQueued", nil)
		if not Ready(Character, "UppercutReadyAt", Tuning.Uppercut, "UppercutCooldown") then return end
		SwingVFX.new(Character):Start(Players:GetPlayers())
		AttackRunner.Run(self.Character, Tuning.Uppercut, "Uppercut", {
			OnActive = function()
				MoverManager.CreateMover(Character, "Velocity", {V = Vector3.new(0, Tuning.Uppercut.SelfLift, 0), D = 0.08})
			end,
		})
		self:SetMetadata(0)
		return
	end

	-- Jump attack. The client queues it the moment you attack while jumping (JumpAttackQueued,
	-- Requests.JumpAttack) because the server's own ground check lags a fresh jump; an airborne
	-- check here covers falls. Inside an air juggle, lights continue the combo instead.
	local Queued = Character:GetAttribute("JumpAttackQueued")
	Character:SetAttribute("JumpAttackQueued", nil)
	-- the server's own check only for a character clearly high up (a real fall, past a jump's apex): the server sees a player ~0.3 s
	-- late, so a light clicked just before landing used to come out as a dive that fizzled on landing. The client
	-- queues the jump attack whenever it's really airborne (fluidity pass 2026-10-18)
	if (Queued or Airborne(Character, 14)) and not self.Character:HasStatusEffects({AirCombo}) then
		if not Ready(Character, "AerialReadyAt", Tuning.Aerial) then return end
		SwingVFX.new(Character):Start(Players:GetPlayers())
		local A = Tuning.Aerial
		AttackRunner.Run(self.Character, A, "Aerial", {
			WalkSpeed = 16, -- don't brake the jump
			OnStartup = function()
				MoverManager.CreateMover(Character, "Hover", {D = A.Startup, Carry = A.HoverCarry})
			end,
			OnActive = function()
				MoverManager.CreateMover(Character, "Dive", {Forward = A.DiveForward, Down = A.DiveDown, D = A.Active, Ramp = A.DiveRamp})
			end,
		})
		self:SetMetadata(0)
		return
	end

	local InJuggle = self.Character:HasStatusEffects({AirCombo})

	-- Dash Attack (grounded only, like Devil Hunter's run attack; never inside a juggle). With a weapon
	-- drawn it's that weapon's own (TuningConfig.WeaponDashAttacks -> Weapons.<Class>.DashAttack).
	local Held = WeaponManager.Def(Character)
	local Dash = Held and Held.DashAttack or Tuning.DashAttack
	if not InJuggle and not Airborne(Character) and HorizontalSpeed(Character) >= Tuning.DashAttack.MinSpeed
		and Ready(Character, "DashAttackReadyAt", Dash) then
		SwingVFX.new(Character):Start(Players:GetPlayers())
		AttackRunner.Run(self.Character, Dash, Held and (Held.Class .. "_DashAttack") or "DashAttack", {
			OnStartup = function()
				MoverManager.CreateMover(Character, "Lunge", {Speed = Dash.Lunge, D = Dash.LungeTime})
			end,
		})
		self:SetMetadata(0)
		self.LastEnded = os.clock()
		return
	end

	-- Light combo (weapon or fists; with a gun: the pistol whip -- never a shot)
	local Weapon = WeaponManager.Def(Character)
	-- the active style's combo (Rensei.Styles; e.g. Boxing / Lethwei bare-handed), else the class's own
	local Style = Styles.Tuning(Character)
	local Hits = (Style and Style.Light.Hits) or (Weapon and Weapon.Light.Hits) or Tuning.Light.Hits
	local Prefix = (Style and ("Style_" .. Style.Id .. "_Light")) or (Weapon and (Weapon.Class .. "_Light")) or "Light"
	local Combo = self:GetMetadata()
	if os.clock() - self.LastEnded > Tuning.Light.ComboReset or Combo >= #Hits then
		Combo = 0
	end
	Combo += 1
	self:SetMetadata(Combo)
	SwingVFX.new(Character):Start(Players:GetPlayers())

	local Hit = Hits[Combo]
	local SwingStartedAt = workspace:GetServerTimeNow()
	local Outcome = AttackRunner.Run(self.Character, Hit, Prefix .. Combo, {
		Feintable = true,
		WalkSpeed = (Style and Style.AttackWalkSpeed) or (Weapon and Weapon.Light.AttackWalkSpeed),
		-- heavy weapons step the body into the swing late in the windup (weight transfer)
		OnStartup = Weapon and Weapon.SwingStep and function()
			task.wait(Hit.Startup * 0.6)
			if Character:GetAttribute("CombatState") == "Startup" then
				MoverManager.CreateMover(Character, "Velocity", {D = 0.14, V = Root.CFrame.LookVector * Weapon.SwingStep})
			end
		end or nil,
	})
	self.LastEnded = os.clock()
	if Outcome == "Feinted" then
		self:SetMetadata(Combo - 1) -- the feinted hit is next
	elseif (Outcome ~= "Hit" and Outcome ~= "Whiff") or Combo >= #Hits then
		self:SetMetadata(0)
	end
	-- R pressed during this swing: the heavy comes out now (Heavy.TakeQueued; not after a stun / feint)
	if Outcome == "Hit" or Outcome == "Whiff" then
		require(ReplicatedStorage.Modules.Skills.Combat.Heavy).TakeQueued(self.Character, SwingStartedAt)
	else
		Character:SetAttribute("HeavyQueuedAt", nil)
	end
end

function FistSwing:OnStartClient()
end

return FistSwing

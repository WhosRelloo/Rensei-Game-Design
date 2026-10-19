local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local States = ReplicatedStorage.Modules.Skills.States
local WCS = require(ReplicatedStorage.Modules.Framework.WCS)
local MoverManager = require(ReplicatedStorage.Modules.Managers.MoverManager)
local AnimationManager = require(ReplicatedStorage.Modules.Managers.AnimationManager)
local Stun = require(States.Stun)
local Climbing = require(States.Climbing)
local Attacking = require(States.Attacking)
local RunFX = require(ReplicatedStorage.Modules.Effects.Combat.RunFX)
local VaultFX = require(ReplicatedStorage.Modules.Effects.Combat.VaultFX)
local WCS = require(ReplicatedStorage.Modules.Framework.WCS)

local WCSCharacter = WCS.Character
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)
local SkillMods = require(ReplicatedStorage.Modules.Managers.SkillMods) -- the Mastery skill tree (Runner)

local DefaultWS = game.StarterPlayer.StarterCharacter.Humanoid.WalkSpeed
local DefaultJH = game.StarterPlayer.StarterCharacter.Humanoid.JumpHeight

local Player = RunService:IsClient() and game.Players.LocalPlayer

local Run = {}
local Running = true

-- WalkSpeed is stored as a 32-bit float: 24 x 1.018 never reads back equal. Comparing exactly ended every
-- sprint on its first frame for anyone with Speed points (no run animation, stuck at sprint speed).
local function Same(A, B) return math.abs(A - B) < 0.01 end

function Run:OnStartClient()
	local Character = Player.Character
	local CharacterState = WCSCharacter.GetCharacterFromInstance(Character)
	
	if CharacterState:HasStatusEffects({Stun,Climbing,Attacking}) then
		return
	end
	
	local Humanoid = Character.Humanoid
	local Camera = workspace.CurrentCamera
	local Root = Character.HumanoidRootPart
	
	local SpeedyRun = false
	local TimeToSpeedy = os.clock() + 2
	local LastVault = 0
	local VaultCooldown = 0.5
	
	local CurrentWalkSpeed = 24 * (Character:GetAttribute("SpeedMultiplier") or 1) * SkillMods.Mult(Character, "SprintSpeed")
	
	Humanoid.WalkSpeed = CurrentWalkSpeed
	
	-- A drawn weapon runs with its own run animation (TuningConfig.Weapons.<Class>.RunAnim).
	local Weapon = Character:GetAttribute("WeaponDrawn") and Tuning.Weapons[Character:GetAttribute("Weapon") or ""]
	local WeaponRun = Weapon and Weapon.RunAnim and AnimationManager.Has(Character, Weapon.RunAnim) and Weapon.RunAnim
	local RunName = WeaponRun or "Run"
	local RunAnimation = AnimationManager.Play(Character,RunName,{Looped = true,Priority = Enum.AnimationPriority.Movement})
	RunFX.locally(Player.Character)
	
	local function CheckVault(Character)
		local BottomPos = Root.Position + Vector3.new(0,-.5,0)
		local TopPos = Root.Position + Vector3.new(0,.1,0)
		local RayDirection = Root.CFrame.LookVector * 7

		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = {Character}
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude

		local BottomRay = workspace:Raycast(BottomPos, RayDirection, raycastParams)
		local TopRay = workspace:Raycast(TopPos,RayDirection,raycastParams)
		
		if (BottomRay and not TopRay) then
			if BottomRay.Normal.Y > 0 then return end
			local SurfaceRay = workspace:Raycast((Root.CFrame * CFrame.new(0,.1,-3)).Position,Vector3.new(0,-3,0),raycastParams)
			
			return true, SurfaceRay
		end

		return false
	end
	
	Running = true
	
	--TweenService:Create(Camera,TweenInfo.new(0.2),{FieldOfView = 80}):Play()
	
	local function WantedRun()
		local W = Character:GetAttribute("WeaponDrawn") and Tuning.Weapons[Character:GetAttribute("Weapon") or ""]
		return W and W.RunAnim and AnimationManager.Has(Character, W.RunAnim) and W.RunAnim or nil
	end

	local RunConnection; RunConnection = RunService.Heartbeat:Connect(function()
		-- drawing / sheathing mid-sprint swaps between the weapon run and the normal run
		if Running and WantedRun() ~= WeaponRun then
			RunAnimation:Stop()
			AnimationManager.Stop(Character, "SpeedyRun")
			WeaponRun = WantedRun()
			RunName = WeaponRun or "Run"
			RunAnimation = AnimationManager.Play(Character, RunName, {Looped = true, Priority = Enum.AnimationPriority.Movement})
			SpeedyRun = false
			TimeToSpeedy = os.clock()
		end
		if os.clock() - LastVault >= VaultCooldown then
			local CanVault,VaultSurface = CheckVault(Character)
			if CanVault and VaultSurface then
				local CurrentVelocity = Character.HumanoidRootPart.Velocity
				CurrentVelocity = Vector3.new(CurrentVelocity.X,0,CurrentVelocity.Z)
				local RootCFrame = Character.HumanoidRootPart.CFrame
				local Velocity = RootCFrame:PointToObjectSpace(CurrentVelocity + RootCFrame.Position) - RootCFrame:PointToObjectSpace(RootCFrame.Position)
				if -Velocity.Z >= 20 then
					local VaultIndex = math.random(1,3)
					LastVault = os.clock()
					Humanoid.JumpHeight = 0
					MoverManager.Velocity(Character,{D = 0.2,V = (CurrentVelocity * 2) + Vector3.new(0,15,0),Max = Vector3.new(4e4,4e4,4e4)})
					AnimationManager.Play(Character,"Vault"..VaultIndex,{Priority = Enum.AnimationPriority.Action})
					
					VaultFX.locally(Character,VaultIndex)
					
					task.wait(0.2)
					
					Humanoid.JumpHeight = DefaultJH
				end
			end
		end
		
		if Running == true and not SpeedyRun and os.clock() >= TimeToSpeedy then
			SpeedyRun = true
			local TimePos = RunAnimation.TimePosition
			if WeaponRun then
				RunAnimation:AdjustSpeed(1.2) -- weapon runs have no separate sprint animation (LocomotionSync then follows the real speed)
			else
				AnimationManager.Play(Character,"SpeedyRun",{Stop = "Run",Looped = true,TimePosition = TimePos,Priority = Enum.AnimationPriority.Movement})
			end
			
			CurrentWalkSpeed = 30 * (Character:GetAttribute("SpeedMultiplier") or 1) * SkillMods.Mult(Character, "SprintSpeed")
			Humanoid.WalkSpeed = CurrentWalkSpeed
			
			--TweenService:Create(Camera,TweenInfo.new(0.2),{FieldOfView = 90}):Play()
		elseif not Running then
			RunAnimation:Stop()
			AnimationManager.Stop(Character,"SpeedyRun")
			
			if Same(Humanoid.WalkSpeed, CurrentWalkSpeed) then
				Humanoid.WalkSpeed = DefaultWS * (Character:GetAttribute("SpeedMultiplier") or 1)
			end
			
			RunConnection:Disconnect()
		end
		if Humanoid.MoveDirection == Vector3.new() or CharacterState:HasStatusEffects({Stun}) or not Same(Humanoid.WalkSpeed, CurrentWalkSpeed) then
			Running = false
		end
	end)
end

function Run:OnEndClient()
	RunFX.locally(Player.Character,"Destroy")
	Running = false
end

return Run
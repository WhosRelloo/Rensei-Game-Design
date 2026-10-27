local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Animations = ReplicatedStorage.Assets.Animations
local States = ReplicatedStorage.Modules.Skills.States
local WCS = require(ReplicatedStorage.Modules.Framework.WCS)
local MoverManager = require(ReplicatedStorage.Modules.Managers.MoverManager)
local AnimationManager = require(ReplicatedStorage.Modules.Managers.AnimationManager)
local Stun = require(States.Stun)
local Climbing = require(States.Climbing)
local Attacking = require(States.Attacking)
local SlideFX = require(ReplicatedStorage.Modules.Effects.Combat.SlideFX)
local WCS = require(ReplicatedStorage.Modules.Framework.WCS)

local WCSCharacter = WCS.Character

local DefaultWS = game.StarterPlayer.StarterCharacter.Humanoid.WalkSpeed
local DefaultJH = game.StarterPlayer.StarterCharacter.Humanoid.JumpHeight

local SlideConn = nil
local Crouching = nil
local SlideDuration = 1.5
local MinSlideDuration = .5
local SlideStartTime = 0
local CrouchStarted = false
local WalkConn = nil

local Player = RunService:IsClient() and game.Players.LocalPlayer

local Crouch = {}

local function IsOnSlope(Character)
	local Root = Character.HumanoidRootPart
	local MinSlideAngle = 25
	
	local RayOrigin = Root.Position
	local RayDirection = Vector3.new(0, -5, 0) -- Cast ray downward
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {Character}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local raycastResult = workspace:Raycast(RayOrigin, RayDirection, raycastParams)
	local BottomRay = workspace:Raycast(((Root.CFrame * CFrame.new(0,0,-1))).Position,RayDirection,raycastParams)

	if raycastResult and BottomRay then
		local OnDownwardSlope = false
		local normal = raycastResult.Normal
		local angle = math.clamp((raycastResult.Position.Y - BottomRay.Position.Y) * 100,-100,50)
		
		if angle>= MinSlideAngle then
			OnDownwardSlope = true
		end
		return OnDownwardSlope, angle
	end

	return false,0
end

local function HitObject(Character)
	local Root = Character.HumanoidRootPart

	local RayOrigin = Root.Position + Vector3.new(0,-1,0)
	local RayDirection = Root.CFrame.LookVector * 5
	
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {Character}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local raycastResult = workspace:Raycast(RayOrigin, RayDirection, raycastParams)

	return raycastResult and true or false
end

function Crouch:ShouldStart()
	local Character = Player.Character
	local CharacterState = WCSCharacter.GetCharacterFromInstance(Character)
	local Humanoid = Character.Humanoid
	
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {Character}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	
	local BottomRay = workspace:Raycast(Character.HumanoidRootPart.Position,Vector3.new(0,-10,0),raycastParams)
	
	if BottomRay and not CharacterState:HasStatusEffects({Stun,Climbing,Attacking}) then
		return true
	end
end

function Crouch:OnStartClient()
	local Character = Player.Character
	local CharacterState = WCSCharacter.GetCharacterFromInstance(Character)
	local Humanoid = Character.Humanoid
	local Root = Character.HumanoidRootPart
	local Camera = workspace.CurrentCamera
	
	if not Crouch:ShouldStart() then return end
	
	CrouchStarted = true
	
	local SlideSpeedMultiplier = 1.5
	local SlideMinSpeed = 20
	
	local CurrentVelocity = Character.HumanoidRootPart.Velocity
	local RootCFrame = Character.HumanoidRootPart.CFrame
	local Velocity = RootCFrame:PointToObjectSpace(CurrentVelocity + RootCFrame.Position) - RootCFrame:PointToObjectSpace(RootCFrame.Position)
	local ForwardVelocity = math.abs(Velocity.Z)
	local FirstOnSlope,Angle = IsOnSlope(Character)
	
	if (ForwardVelocity >= 20 or FirstOnSlope) and Angle >= 0 and not HitObject(Character) then
		--Humanoid.WalkSpeed = 0
		Humanoid.JumpHeight = 0
		
		AnimationManager.Play(Character,"Slide",{Priority = Enum.AnimationPriority.Action2,Looped = true})
		
		local ForwardSpeed = math.clamp(ForwardVelocity + Angle,20,40)
		local StartingVelocity = Root.CFrame.LookVector * ForwardSpeed * 2
		
		local IsSliding = true
		SlideStartTime = os.clock()
		local BodyVelocity = MoverManager.Velocity(Character,{V = StartingVelocity,Max = Vector3.new(4e4,0,4e4)})
		
		local rayParams = RaycastParams.new()
		rayParams.FilterDescendantsInstances = {Character}
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		
		SlideFX.locally(Character)
		
		--TweenService:Create(Camera,TweenInfo.new(0.2),{FieldOfView = 85}):Play()
		
		SlideConn = RunService.RenderStepped:Connect(function()
			
			local Intersection = HitObject(Character)
			
			local OnSlope,SlopeAngle = IsOnSlope(Character)
			
			local TimePassed = os.clock() - SlideStartTime
			if (not OnSlope and TimePassed >= SlideDuration) or BodyVelocity.VectorVelocity.Magnitude < 3 or Intersection then
				SlideConn:Disconnect()
				MoverManager.ClearMovers(Character)
				Crouch:OnEndClient()
				
			else
				if OnSlope then
					SlideStartTime = os.clock()
					local VelCalc = Root.CFrame.LookVector * SlopeAngle * 1.5
					StartingVelocity = VelCalc.Magnitude > StartingVelocity.Magnitude and VelCalc or StartingVelocity
					BodyVelocity.VectorVelocity = StartingVelocity
				else
					local AngleFactor = SlopeAngle/-100
					local slideProgress = 1 - ((TimePassed / (SlideDuration)) + AngleFactor)
					BodyVelocity.VectorVelocity = StartingVelocity * slideProgress
				end
				
			end
		end)
	else
		Crouching = true
		
		ReplicatedStorage.Remotes.StateRemote:FireServer({{"Stun",true}})
		AnimationManager.Play(Character,"CrouchIdle",{Priority = Enum.AnimationPriority.Idle,Looped = true})
		
		local LastState = nil
		local CrouchWalking = false
		
		local Velocity = Root.Velocity
		Velocity = Vector3.new(Velocity.X,0,Velocity.Z).Magnitude
		if Velocity > 5 then
			CrouchWalking = true
			AnimationManager.Play(Character,"CrouchWalk",{Priority = Enum.AnimationPriority.Movement,Looped = true})
		end
		
		WalkConn = RunService.Heartbeat:Connect(function()
			local NewVelocity = Root.Velocity
			local CurrentVelocity = Vector3.new(NewVelocity.X,0,NewVelocity.Z)
			if not CrouchWalking and CurrentVelocity.Magnitude > 5 then
				CrouchWalking = true
				AnimationManager.Play(Character,"CrouchWalk",{Priority = Enum.AnimationPriority.Movement,Looped = true})
			elseif CrouchWalking and CurrentVelocity.Magnitude <= 5 then
				CrouchWalking = false
				AnimationManager.Stop(Character,"CrouchWalk")
			end
		end)

		Humanoid.WalkSpeed = 6
		Humanoid.JumpHeight = 0
	end
end

function Crouch:OnEndClient()
	local Character = Player.Character
	local Humanoid = Character.Humanoid
	
	if not CrouchStarted then return end
	CrouchStarted = false
	
	if SlideConn then
		local TimeUntilDone = MinSlideDuration - (os.clock() - SlideStartTime)
		if TimeUntilDone > 0 then
			task.wait(TimeUntilDone)
		end
		
		SlideFX.locally(Character,"Destroy")
		--TweenService:Create(Camera,TweenInfo.new(0.2),{FieldOfView = 70}):Play()
		SlideConn:Disconnect()
		MoverManager.ClearMovers(Character)
	end
	
	AnimationManager.Stop(Character,"Slide")
	
	if Crouching then
		ReplicatedStorage.Remotes.StateRemote:FireServer({{"Stun",false}})
		
		AnimationManager.Stop(Character,"CrouchIdle")
		AnimationManager.Stop(Character,"CrouchWalk")
		
		Crouching = false
		
		WalkConn:Disconnect()
	end
	
	-- (downed crawl, 2026-10-27) knocked: the server owns the speed and jump (DownedManager.KnockedSpeed: a slow crawl,
	-- no jump). A crouch that ended while knocked (Ctrl let go after the knock) stood the client back up at walk speed and
	-- full jump, and the server's value doesn't re-replicate unless it changes, so a knocked player walked off at 16.
	if Character:GetAttribute("Knocked") then
		Humanoid.JumpHeight = 0
		Humanoid.WalkSpeed = require(ReplicatedStorage.Modules.Managers.DownedManager).KnockedSpeed(Character)
		return
	end
	Humanoid.WalkSpeed = DefaultWS * (Character:GetAttribute("SpeedMultiplier") or 1)
	Humanoid.JumpHeight = DefaultJH
end

return Crouch
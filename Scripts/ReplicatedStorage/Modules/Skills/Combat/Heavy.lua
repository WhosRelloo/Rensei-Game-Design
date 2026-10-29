local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local States = ReplicatedStorage.Modules.Skills.States
local Managers = ReplicatedStorage.Modules.Managers

local MoverManager = require(Managers.MoverManager)
local AnimationManger = require(Managers.AnimationManager)
local HitboxManager = require(Managers.HitboxManager)
local WCS = require(ReplicatedStorage.Modules.Framework.WCS)
local Attacking = require(States.Attacking)
local Stun = require(States.Stun)
local Climbing = require(States.Climbing)
local Blocking = require(States.Blocking)
local AirCombo = require(States.AirCombo)
local Hit = require(ReplicatedStorage.Modules.Skills.Combat.Hit)
local AttackRunner = require(Managers.AttackRunner)
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)
local WeaponManager = require(Managers.WeaponManager)
local t = require(ReplicatedStorage.Modules.Framework.t)

local Heavy = WCS.RegisterHoldableSkill("Heavy")

function Heavy:OnConstructServer()
	self:SetMaxHoldTime(nil)
	-- R must work while LMB is held (the Fist skill stays active for the whole held combo); a heavy
	-- pressed mid-swing is queued in OnStartServer instead
	self.CheckOthersActive = false
	
	-- Attacking is NOT exclusive: RMB during a light attack's startup is a feint (handled below).
	self.MutualExclusives = {
		Stun,
		Blocking,
		Climbing
	}
	
	self.HitSkill = Hit.new(self.Character)
end

function Heavy:OnConstructClient()
	local Character = self.Character
	self.CheckOthersActive = false -- (see OnConstructServer)
end

local function GroundRaycast(Character,Distance)
	Distance = Distance or 12
	local Params = RaycastParams.new()
	Params.FilterDescendantsInstances = {Character,workspace.World.Visuals}
	Params.FilterType = Enum.RaycastFilterType.Exclude

	local Raycast = workspace:Raycast(Character.HumanoidRootPart.Position,Vector3.new(0,-Distance,0),Params)

	return Raycast
end

-- The ground heavy: the held weapon's (TuningConfig.Weapons.<Class>.Heavy) or the fist heavy.
local function GroundHeavy(Character)
	local Root = Character.Instance:FindFirstChild("HumanoidRootPart")
	local Humanoid = Character.Instance:FindFirstChildOfClass("Humanoid")
	if not Root or not Humanoid then return end
	local Weapon = WeaponManager.Def(Character.Instance)
	local Def = Weapon and Weapon.Heavy or Tuning.Heavy
	local Name = Weapon and (Weapon.Class .. "_Heavy") or "Heavy"
	-- the active style's heavy (Rensei.Styles; e.g. Boxing's Peek-a-boo, Lethwei's), else the class's own
	local Style = require(ReplicatedStorage.Modules.Data.Rensei.Styles).Tuning(Character.Instance)
	if Style then Def, Name = Style.Heavy, "Style_" .. Style.Id .. "_Heavy" end
	local Now = workspace:GetServerTimeNow()
	if (Character.Instance:GetAttribute("HeavyReadyAt") or 0) > Now then return end
	-- Heavy Hand (skill tree): shorter heavy cooldown
	local Cooldown = Def.Cooldown * require(Managers.SkillMods).Mult(Character.Instance, "HeavyCooldown")
	Character.Instance:SetAttribute("HeavyReadyAt", Now + Cooldown)
	Character.Instance:SetAttribute("HeavyCooldown", Cooldown) -- for the cooldown bar
	for _,Anim in pairs(Humanoid.Animator:GetPlayingAnimationTracks()) do
		if Anim.Priority ~= Enum.AnimationPriority.Core then Anim:Stop() end -- keep the base idle / walk (2026-10-19)
	end
	AttackRunner.Run(Character, Def, Name, {
		WalkSpeed = Def.WalkSpeed or Tuning.Heavy.WalkSpeed,
		OnStartup = function()
			task.wait(Def.Startup * 0.7)
			MoverManager.CreateMover(Character.Instance, "Velocity", {D = 0.15, V = Root.CFrame.LookVector * (Def.Step or 0)})
		end,
	})
end

-- The air heavy (R in the air): FistHeavyDown, then the slam. Hotfix 2026-10-23 ("downslam on uptilt does nothing"):
-- inside an air juggle (after the Uppercut / uptilt) the target is up here next to you, but the slam's hitbox was
-- only ever placed on the GROUND below (and an R pressed during an air light was dropped: TakeQueued needed the
-- ground). In a juggle the hit is now a box in front of you, mid-air, using the Downslam hit (SkillData.Downslam:
-- spikes the target down). Outside a juggle it's the old ground Smash.
local function AirSlam(Character, HitDelay)
	local Inst = Character.Instance
	local Humanoid = Character.Humanoid
	for _,Anim in pairs(Humanoid.Animator:GetPlayingAnimationTracks()) do
		if Anim.Priority ~= Enum.AnimationPriority.Core then Anim:Stop() end
	end
	AnimationManger.Play(Inst,"FistHeavyDown")
	Attacking.new(Character):Start(1)
	local InJuggle = Character:HasStatusEffects({AirCombo})
	local Result = GroundRaycast(Inst,100)
	task.delay(HitDelay,function()
		MoverManager.Movement(Inst,{JH = 0,WS = 5,D = 0.5})
		local Root = Inst:FindFirstChild("HumanoidRootPart")
		if InJuggle and Root then
			HitboxManager.Hitbox(Inst,"Downslam",Root.CFrame * CFrame.new(0,-1,-3),false,true)
			MoverManager.CreateMover(Inst,"Velocity",{V = Vector3.new(0,-60,0),D = 0.15}) -- PROPOSAL: follow the slam down
		elseif Result then
			HitboxManager.Hitbox(Inst,"Smash",CFrame.new(Result.Position),false)
		end
	end)
end

-- R pressed during an M1 swing: the heavy is queued and comes out the moment that swing ends (the
-- swing itself plays out in full), so a heavy can be mixed into the combo at any hit. FistSwing
-- calls this after each light; a press older than the swing that just ended doesn't count.
function Heavy.TakeQueued(Character, SwingStartedAt)
	local Inst = Character.Instance
	local Queued = Inst:GetAttribute("HeavyQueuedAt")
	Inst:SetAttribute("HeavyQueuedAt", nil)
	if not Queued or Queued < SwingStartedAt then return false end
	if Character:HasStatusEffects({Stun, Blocking, Climbing, Attacking}) then return false end
	if not Inst:GetAttribute("CombatMode") or Inst:GetAttribute("Knocked") then return false end
	-- airborne in an air juggle (after the uptilt): the downslam (hotfix 2026-10-23); otherwise only on the ground
	if not GroundRaycast(Inst) then
		if Character:HasStatusEffects({AirCombo}) then AirSlam(Character, 0.1) return true end
		return false
	end
	GroundHeavy(Character)
	return true
end

function Heavy:OnStartServer()
	local Character = self.Character
	-- (hostages Task 10) a captor's hands are full: no heavy, not even a queued one
	if Character.Instance:GetAttribute("Holding") then return end
	local Humanoid = Character.Humanoid
	local Root = Character.Instance.HumanoidRootPart

	-- mid-attack: queue it behind a light swing (Heavy.TakeQueued), otherwise nothing.
	-- (Feint is RMB -- Requests.Feint -- R no longer feints.)
	if Character:HasStatusEffects({Attacking}) then
		if tostring(Character.Instance:GetAttribute("CombatAttack") or ""):match("Light%d+$") then
			Character.Instance:SetAttribute("HeavyQueuedAt", workspace:GetServerTimeNow())
		end
		return
	end
	
	local Worked,SentInfo = self:Landing():await()
	local InAir,LastWallJump = SentInfo[1],SentInfo[2]
	
	if not InAir then
		GroundHeavy(Character)
	else
		for _,Anim in pairs(Humanoid.Animator:GetPlayingAnimationTracks()) do
			if Anim.Priority ~= Enum.AnimationPriority.Core then Anim:Stop() end -- keep the base idle / walk (2026-10-19)
		end
	end
	if InAir and workspace:GetServerTimeNow() - LastWallJump > 1 then
		AirSlam(Character, 0.45)
	end
end

function Heavy:Landing()
	local Character = self.Character
	
	return {not GroundRaycast(Character.Instance), Character.Instance:GetAttribute("LastWallJump") or 0}
end

WCS.DefineMessage(Heavy.Landing,{
	Type = "Request",
	Destination = "Client",
	ValueValidator = t.table
})

function Heavy:DownkickLand(Position)
	local Character = self.Character
	
	
	HitboxManager.Hitbox(Character.Instance,"Smash",CFrame.new(Position),false)
end

WCS.DefineMessage(Heavy.DownkickLand,{
	Type = "Event",
	Destination = "Server",
})

function Heavy:OnStartClient()
	local Player = Players.LocalPlayer
	local Character = self.Character
	-- (hostages Task 10 fix round 1, review m5) the server refuses a captor's heavy: no client movers or animation either
	if Character.Instance:GetAttribute("Holding") or Character.Instance:GetAttribute("HeldBy") then return end
	local Root = Character.Instance.HumanoidRootPart
	local Humanoid = Character.Humanoid
	
	local OnGround = GroundRaycast(Character.Instance)
	local SecondRay = GroundRaycast(Character.Instance,100)
	
	local LastWallJump = Character.Instance:GetAttribute("LastWallJump") or 0
	
	if workspace:GetServerTimeNow() - LastWallJump <= 1 then
		AnimationManger.Play(Character.Instance,"FistDownKick")
		
		MoverManager.AlignPosition(Character.Instance,{D = .66,P = Root.Position,Max = Vector3.new(math.huge,math.huge,math.huge),R = math.huge})
		
		
		coroutine.wrap(function()
			task.wait(.66)

			local Params = RaycastParams.new()
			Params.FilterDescendantsInstances = {Character.Instance,workspace.World.Visuals}
			Params.FilterType = Enum.RaycastFilterType.Exclude

			local MouseHit = Player:GetMouse().Hit
			local TargetPos = CFrame.new(Root.Position,Vector3.new(MouseHit.Position.X,math.min(MouseHit.Position.Y,Root.Position.Y),MouseHit.Position.Z))
			local V = TargetPos.LookVector * 50
			local Duration = 0.366

			local Velocity = MoverManager.Velocity(Character.Instance,{D = Duration,V = TargetPos.LookVector * 200,Max = Vector3.new(5e5,5e5,5e5)})
			local Direction = V.Unit
			local RayLength = 3

			local KBConn; KBConn = RunService.Stepped:Connect(function()
				local Raycast = workspace:Blockcast(Root.CFrame,Vector3.new(5,7,4),Direction * RayLength,Params)
				if Raycast then
					Velocity.VectorVelocity = Vector3.new(0,0,0)
					Velocity.MaxAxesForce = Vector3.new(100000, 100000, 100000)
					Velocity:Destroy()
					
					self:DownkickLand(Root.Position + Vector3.new(0,-3,0))

					KBConn:Disconnect()
				end
			end)

			task.wait(Duration)
			
			if KBConn then
				KBConn:Disconnect()
			end
		end)()
		
	elseif not OnGround and SecondRay then
		local Offset = Vector3.new(0,0,0)
		local Alignment = MoverManager.AlignPosition(Character.Instance,{P = Character.Instance.HumanoidRootPart.Position,Max = Vector3.new(0,10000,0),D = 1})

		coroutine.wrap(function()
			task.wait(.45)
			
			Alignment.Responsiveness = 75
			Alignment.Position = SecondRay.Position
		end)()
	elseif OnGround then
		
		
	end
end

function Heavy:OnEndServer()
end

function Heavy:OnEndClient()
end

return Heavy
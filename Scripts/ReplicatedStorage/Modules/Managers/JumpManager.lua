local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local States = ReplicatedStorage.Modules.Skills.States
local MoverManager = require(ReplicatedStorage.Modules.Managers.MoverManager)
local AnimationManager = require(ReplicatedStorage.Modules.Managers.AnimationManager)
local Stun = require(States.Stun)
local Climbing = require(States.Climbing)
local WCS = require(ReplicatedStorage.Modules.Framework.WCS)
local ResourceManager = require(ReplicatedStorage.Modules.Managers.ResourceManager)
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)
local SkillMods = require(ReplicatedStorage.Modules.Managers.SkillMods) -- the Mastery skill tree (Climber, Acrobat)
local MovementState = require(ReplicatedStorage.Modules.Managers.MovementState) -- server-owned traversal state
local LedgeWalk = require(script.LedgeWalk) -- the standing narrow-ledge walk (client)
local EffectModules = {}

for _,EffeectModule in pairs(ReplicatedStorage.Modules.Effects.Combat:GetChildren()) do
	if EffeectModule:IsA("ModuleScript") then
		local ModuleName = string.gsub(EffeectModule.Name,"FX","")
		EffectModules[ModuleName] = require(EffeectModule)
	end
end


local WCSCharacter = WCS.Character

local DefaultWS = game.StarterPlayer.StarterCharacter.Humanoid.WalkSpeed
local DefaultJH = game.StarterPlayer.StarterCharacter.Humanoid.JumpHeight

local Player = RunService:IsClient() and Players.LocalPlayer

local ClimbStamina = 10
local ClimbCooldown = 0

local Air = {}

-- Touch support (Modules.UI.MobileControls): the thumbstick stands in for W/A/S/D (camera-relative,
-- like the keys) and holding the touch jump button stands in for holding Space.
Air.TouchJumpHeld = false
local function Held(Key)
	if UserInputService:IsKeyDown(Key) then return true end
	if not UserInputService.TouchEnabled or not Player or not Player.Character then return false end
	local Humanoid = Player.Character:FindFirstChildOfClass("Humanoid")
	local Move = Humanoid and Humanoid.MoveDirection
	if not Move or Move.Magnitude < 0.3 then return false end
	local Look = workspace.CurrentCamera.CFrame.LookVector
	Look = Vector3.new(Look.X, 0, Look.Z).Unit
	local Right = Look:Cross(Vector3.yAxis)
	if Key == Enum.KeyCode.W then return Move:Dot(Look) > 0.5 end
	if Key == Enum.KeyCode.S then return Move:Dot(Look) < -0.5 end
	if Key == Enum.KeyCode.D then return Move:Dot(Right) > 0.5 end
	if Key == Enum.KeyCode.A then return Move:Dot(Right) < -0.5 end
	return false
end
local function HoldingJump()
	return UserInputService:IsKeyDown(Enum.KeyCode.Space) or Air.TouchJumpHeld == true
end

local raycastParams = RaycastParams.new()
raycastParams.FilterDescendantsInstances = {workspace.World.Map}
raycastParams.FilterType = Enum.RaycastFilterType.Include

-- How far the climber's root hangs off the wall face. 1.15 lets both hands reach the wall in the
-- climb poses (see the hands-on-wall pass in OnConstructClient) with the chest still clear of it;
-- at the old 1.5 the arms were too short for much of the climb step.
local WALL_GAP = 1.15

-- Every climb pose. Stop all of them on every exit: the hang idle is LOOPED, so missing the one
-- side that happens to be playing leaves the character stuck in the climb pose on the ground.
local ClimbAnims = {"RightClimbIdle", "LeftClimbIdle", "RightClimb", "LeftClimb", "ClimbSideRight", "ClimbSideLeft", "ClimbDown"}
local function StopClimbAnims(Character)
	for _, Name in ipairs(ClimbAnims) do AnimationManager.Stop(Character, Name) end
end

local function HitObject(Character)
	local Root = Character.HumanoidRootPart

	local RayOrigin = Root.Position + Vector3.new(0,3,0)
	local RayDirection = Root.CFrame.LookVector * 3

	local raycastResult = workspace:Raycast(RayOrigin, RayDirection, raycastParams)

	return raycastResult
end

local function SideObject(Character,Side)
	local Root = Character.HumanoidRootPart

	local RayOrigin = Root.Position
	local RayDirection = Root.CFrame.RightVector * Tuning.Parkour.WallRunReach

	local rightResult = (Side and Side == "Right" or not Side) and workspace:Raycast(RayOrigin, RayDirection, raycastParams)
	local leftResult = (Side and Side == "Left" or not Side) and  workspace:Raycast(RayOrigin, -RayDirection, raycastParams)
	
	return rightResult or leftResult, rightResult and "Right" or leftResult and "Left"
end

local function CheckVault(Character)
	local Root = Character.HumanoidRootPart
	local BottomPos = Root.Position + Vector3.new(0,3,0)
	local TopPos = Root.Position + Vector3.new(0,8,0)
	local RayDirection = Root.CFrame.LookVector * 7

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {Character}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local BottomRay = workspace:Raycast(BottomPos, RayDirection, raycastParams)
	local TopRay = workspace:Raycast(TopPos,RayDirection,raycastParams)

	if (BottomRay and not TopRay) then
		if BottomRay.Normal.Y > 0 then return end
		local SurfaceRay = workspace:Raycast((Root.CFrame * CFrame.new(0,8,-2)).Position,Vector3.new(0,-8,0),raycastParams)

		return true, SurfaceRay
	end

	return false
end

-- Parkour limits: one climb per airtime. Wall runs CHAIN (user request 2026-10-14): after kicking
-- off a wall you can attach to a DIFFERENT wall (not the one you just left) once
-- WallRunChainDelay has passed -- each new wall pays the wall-run stamina again. Landing resets.
Air.AirUses = {Climb = false, WallRun = false} -- WallRun = false or {Normal, Position, At} of the last wall

local function CanWallRun(Hit)
	local Last = Air.AirUses.WallRun
	if not Last then return true end
	if not Hit or os.clock() - Last.At < (Tuning.Parkour.WallRunChainDelay or 0.25) then return false end
	local SameFacing = Hit.Normal:Dot(Last.Normal) > 0.85
	local SamePlane = math.abs((Hit.Position - Last.Position):Dot(Last.Normal)) < 2
	return not (SameFacing and SamePlane) -- a different wall (angle or a separate parallel wall)
end

-- Parkour stamina costs, less with the Mastery tree's Climber (Mod_ParkourCost). The server charges
-- the same amount (ParkourStamina below).
local function ParkourCost(Character, Kind)
	return Tuning.Parkour[Kind] * SkillMods.Mult(Character, "ParkourCost")
end

local function HasStamina(Character, Kind)
	return ResourceManager.Get(Character, "Stamina") >= ParkourCost(Character, Kind)
end

-- Client asks the server to charge parkour stamina (the server re-checks; see ParkourStamina).
local function Charge(Kind)
	ReplicatedStorage.Remotes.JumpRemote:FireServer("ParkourStamina", Kind)
end

function Air.ParkourStamina(Player, Kind)
	if RunService:IsClient() then return end
	local Character = Player.Character
	if not Character or type(Kind) ~= "string" or type(Tuning.Parkour[Kind]) ~= "number" then return end
	ResourceManager.Spend(Character, "Stamina", ParkourCost(Character, Kind))
end

function Air:OnConstructClient()
	local function Watch(Character)
		local Humanoid = Character:WaitForChild("Humanoid")
		-- The server owns the traversal state (MovementState). When it ends or refuses THIS client's
		-- current climb / wall run (stun, knock, grip, carry, death, no wall in reach), let go here too,
		-- so client and server never disagree about being on a wall.
		Character:GetAttributeChangedSignal("TraversalSession"):Connect(function()
			local Pending = Air.PendingTraversal
			local Seq, Kind = MovementState.ParseSession(Character:GetAttribute("TraversalSession"))
			if not Pending or Seq ~= Pending.Seq or Kind == Pending.Kind then return end
			Air.PendingTraversal = nil
			if Air.WallRunConn and Air.EndWallRun then
				Air.EndWallRun(false)
			elseif Air.ClimbConn and Air.LetGoClimb then
				Air.LetGoClimb()
			elseif Air.LedgeConn and Air.EndLedge then
				Air.EndLedge("Server")
			end
		end)
		Humanoid.StateChanged:Connect(function(_, New)
			if New == Enum.HumanoidStateType.Landed or New == Enum.HumanoidStateType.Running then
				Air.AirUses.Climb = false
				Air.AirUses.WallRun = false
				-- safety net: standing on the ground and not on a wall = no climb pose
				if not self.ClimbConn and not (self.AlignPosition and self.AlignPosition.Parent) then
					StopClimbAnims(Character)
				end
			end
		end)
	end
	if Player.Character then task.spawn(Watch, Player.Character) end
	Player.CharacterAdded:Connect(Watch)

	-- Hands on the wall while climbing. The climb poses leave the hands short of the wall (the hang
	-- idle reaches 0.8 studs out; the climber hangs WALL_GAP off the wall) or push the reaching hand
	-- into it. After the Animator poses the arms each frame (Stepped is where Motor6D.Transform can be
	-- overridden), each arm is pitched at the shoulder so the hand rests on the wall face; its
	-- up/down motion from the animation is kept. Local only: Transform overrides do not replicate.
	local HAND_HALF = 0.5 -- the hand's centre to its front face
	local function Wrap(A) return (A + math.pi) % (2 * math.pi) - math.pi end
	RunService.Stepped:Connect(function()
		if not self.ClimbConn then return end
		local Character = Player.Character
		local Torso = Character and Character:FindFirstChild("Torso")
		local Root = Character and Character:FindFirstChild("HumanoidRootPart")
		if not Torso or not Root then return end
		local Wall = workspace:Raycast(Root.Position + Vector3.new(0, 1.5, 0), Root.CFrame.LookVector * 4, raycastParams)
		if not Wall then return end
		local N = -Wall.Normal -- into the wall
		local Axis = Torso.CFrame.RightVector -- the shoulders pitch about this
		local U = N:Cross(Axis) -- with N, the plane the arm swings in (rotating +angle turns U toward N)
		if U.Magnitude < 1e-3 then return end
		U = U.Unit
		for _, Name in ipairs({"Right Shoulder", "Left Shoulder"}) do
			local Joint = Torso:FindFirstChild(Name)
			local Arm = Joint and Joint.Part1
			if Arm then
				local JointCF = Torso.CFrame * Joint.C0
				local ArmCF = JointCF * Joint.Transform * Joint.C1:Inverse()
				local Pivot = JointCF.Position
				local V = ArmCF * Vector3.new(0, -Arm.Size.Y / 2, 0) - Pivot -- shoulder to hand
				local Vn, Vu = V:Dot(N), V:Dot(U)
				local L = math.sqrt(Vn * Vn + Vu * Vu)
				if L > 1e-3 then
					-- the swing angle that puts the hand at the wall, nearest to the animated one
					local Target = (Wall.Position - Pivot):Dot(N) - HAND_HALF
					local Beta = math.atan2(Vn, Vu)
					local B1 = math.asin(math.clamp(Target / L, -1, 1))
					local D1, D2 = Wrap(B1 - Beta), Wrap(math.pi - B1 - Beta)
					local Delta = math.abs(D1) < math.abs(D2) and D1 or D2
					local Rot = CFrame.new(Pivot) * CFrame.fromAxisAngle(Axis, Delta) * CFrame.new(-Pivot)
					Joint.Transform = JointCF:Inverse() * (Rot * ArmCF) * Joint.C1
				end
			end
		end
	end)

	-- Hold-to-wall-run: still holding Space from the jump when you reach a SIDE wall starts the
	-- wall run without a second press. Front walls never auto-trigger (climbing is a tap).
	local AirSince = nil
	RunService.Heartbeat:Connect(function()
		local Character = Player.Character
		local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
		local Root = Character and Character:FindFirstChild("HumanoidRootPart")
		if not Humanoid or not Root then return end
		local State = Humanoid:GetState()
		local InAir = State == Enum.HumanoidStateType.Freefall or State == Enum.HumanoidStateType.Jumping
		if not InAir then AirSince = nil Air.GrabBufferUntil = nil return end
		AirSince = AirSince or os.clock()
		-- a buffered grab (Space pressed just before the wall was in reach): take it now
		if Air.GrabBufferUntil and os.clock() <= Air.GrabBufferUntil and not self.ClimbConn and not self.WallRunConn and HitObject(Character) then
			Air.GrabBufferUntil = nil
			self:OnStartClient()
			return
		end
		if os.clock() - AirSince < 0.12 or self.WallRunConn then return end
		if not HoldingJump() then return end
		local CharacterState = WCSCharacter.GetCharacterFromInstance(Character)
		if not CharacterState or CharacterState:HasStatusEffects({Climbing, Stun}) then return end
		if Character:GetAttribute("Knocked") then return end
		local V = Root.AssemblyLinearVelocity
		if Vector3.new(V.X, 0, V.Z).Magnitude < 8 then return end
		if HitObject(Character) then return end
		local SideHit = SideObject(Character)
		if not SideHit or not CanWallRun(SideHit) then return end
		if not HasStamina(Character, "WallRun") then return end
		self:OnStartClient()
	end)
	self.LastJumped = os.clock()
	self.DoubleJump = true
	self.JumpCD = 1
	self.JumpDelay = 0.1 -- double jump delay
	self.LandingTime = 0.5
	self.DoubleJumpMultiplier = 2
	self.CheckClientState = false
	if Tuning.LedgeWalk and Tuning.LedgeWalk.Enabled then LedgeWalk.Start(Air) end
end

local function FindNextClimb(Character,Direction)
	local Root = Character.HumanoidRootPart
	local ClimbHeight = 15
	local StartPos = Root.Position

	for I = 1,11 do
		local Increment = ClimbHeight/20
		local Multiplier = ClimbHeight - ((I - 1) * Increment)
		local CurrentPos = StartPos + (Direction * Multiplier)

		local RayDirection = Root.CFrame.LookVector * 5

		local raycastResult = workspace:Raycast(CurrentPos, RayDirection, raycastParams)

		if raycastResult then
			return raycastResult,Multiplier/ClimbHeight
		end
	end
end

-- ===== Directional climb (controls doc) =====
-- While on the wall, WASD moves along it (W up, S down, A/D sideways), following angled walls.
-- Moving up past the top vaults onto the ledge; moving down onto the ground lets go. Stamina
-- drains while hanging and faster while moving; out of stamina = let go. Space: S = kick off
-- backwards, W = leap up (ClimbAction), nothing held = let go. No combat while climbing
-- (Climbing status). The loop ends by itself when the climb movers are removed (every exit
-- path clears them).
local WallProbe = RaycastParams.new()
WallProbe.FilterType = Enum.RaycastFilterType.Include
WallProbe.FilterDescendantsInstances = {workspace.World.Map}

-- Climb step timing (up). Each step plays one Right/LeftClimb animation sped up to last exactly
-- STEP_TIME (it is 0.8s long; it used to be cut off at 0.35s by the next step, mid-reach). The body
-- moves with the pull: still while the hands swap, fastest mid-step, averaging Parkour.ClimbSpeed.
-- Down and sideways (2026-10-18, the sheet's Climb Down / Climb Right / Climb Left) are looped
-- shuffles at a steady speed, the loop played at the rate that keeps the hands from sliding
-- (CLIMB_LOOP_STRIDE: studs one loop covers, measured from the animations).
local STEP_TIME = 0.35
local STEP_ANIM_LENGTH = 0.8 -- fallback if the track's Length has not loaded
local CLIMB_LOOPS = {Down = "ClimbDown", SideRight = "ClimbSideRight", SideLeft = "ClimbSideLeft"}
local CLIMB_LOOP_STRIDE = {Down = 7, SideRight = 6, SideLeft = 6}

function Air:ClimbLoop(Character, Normal)
	local Root = Character.HumanoidRootPart
	local Humanoid = Character.Humanoid
	local P = Tuning.Parkour
	local NextTick = os.clock() + P.ClimbTickEvery
	local StepStart, StepSide = nil, "Right"
	local Mode = nil -- "Up" (alternating pulls), "Down", "SideRight", "SideLeft"; nil = hanging still
	if self.ClimbConn then self.ClimbConn:Disconnect() end

	-- stopped (or blocked): straight back to the hang pose
	local function StopStepping()
		if not Mode then return end
		StepStart, Mode = nil, nil
		StopClimbAnims(Character)
		AnimationManager.Play(Character, self.CurrentSide .. "ClimbIdle", {Looped = true, Priority = Enum.AnimationPriority.Action})
	end

	local function StartStep()
		StepStart, Mode = os.clock(), "Up"
		StepSide = StepSide == "Right" and "Left" or "Right"
		self.CurrentSide = StepSide
		StopClimbAnims(Character)
		local Track = AnimationManager.Play(Character, StepSide .. "Climb", {Priority = Enum.AnimationPriority.Action2})
		if Track then
			local Length = Track.Length > 0 and Track.Length or STEP_ANIM_LENGTH
			Track:AdjustSpeed(Length / STEP_TIME)
		end
	end

	-- down / sideways: one looped shuffle, kept going while the direction holds
	local function StartLoop(Which, Speed)
		if Mode == Which then return end
		StepStart, Mode = nil, Which
		if Which == "SideRight" or Which == "SideLeft" then self.CurrentSide = Which == "SideRight" and "Right" or "Left" end
		StopClimbAnims(Character)
		local Track = AnimationManager.Play(Character, CLIMB_LOOPS[Which], {Looped = true, Priority = Enum.AnimationPriority.Action2})
		if Track then
			local Length = Track.Length > 0 and Track.Length or 1
			Track:AdjustSpeed(math.clamp(Speed * Length / CLIMB_LOOP_STRIDE[Which], 0.5, 2))
		end
	end

	-- climb -> ledge walk (2026-10-18): an authored ledge on THIS wall right under you takes over directly. The
	-- server's traversal session is replaced (MovementState: a new session replaces the old one), so there's no
	-- let-go, fall, landing or entry wait in between. Down: a ledge within ClimbDownReach of the feet; sideways:
	-- only one the feet are already at (ClimbSideReach), so climbing past a ledge doesn't grab it.
	local function LedgeHandoff(Y, X)
		local LW = Tuning.LedgeWalk
		if not (LW and LW.Enabled and LW.FromClimb) then return false end
		-- look under the body and a little toward the wall (the shin probe keeps the climber off the strip's front)
		local L, T, Height = LedgeWalk.Under(Root)
		if not L then L, T, Height = LedgeWalk.Under(Root, Root.Position - Normal * 1.6) end
		if not L or L.Wall:Dot(-Normal) < 0.7 then return false end
		local Stand = LedgeWalk.StandHeight(Character)
		if Height - Stand > (Y < 0 and LW.ClimbDownReach or LW.ClimbSideReach) then return false end
		if self.ClimbConn then self.ClimbConn:Disconnect() self.ClimbConn = nil end
		EffectModules["Hang"].locally(Character, self.CurrentSide, "Destroy")
		MoverManager.ClearMovers(Character)
		for _, Name in ipairs(ClimbAnims) do AnimationManager.Stop(Character, Name, LW.ClimbBlend) end
		LedgeWalk.Enter(self, Character, L, T, Stand, {FromClimb = true})
		return true
	end

	local function LetGo()
		if self.ClimbConn then self.ClimbConn:Disconnect() self.ClimbConn = nil end
		EffectModules["Hang"].locally(Character, self.CurrentSide, "Destroy")
		MoverManager.ClearMovers(Character)
		self.ClimbState(Player, false)
		Humanoid.AutoRotate = true
		StopClimbAnims(Character)
	end
	self.LetGoClimb = LetGo

	self.ClimbConn = RunService.RenderStepped:Connect(function(Dt)
		local Align = self.AlignPosition
		if not Align or not Align.Parent or Humanoid.Health <= 0 then
			if self.ClimbConn then self.ClimbConn:Disconnect() self.ClimbConn = nil end
			return
		end
		-- W up, S down, A / D along the wall (diagonals too)
		local X = (Held(Enum.KeyCode.D) and 1 or 0) - (Held(Enum.KeyCode.A) and 1 or 0)
		local Y = (Held(Enum.KeyCode.W) and 1 or 0) - (Held(Enum.KeyCode.S) and 1 or 0)
		local Moving = X ~= 0 or Y ~= 0

		-- stamina
		if os.clock() >= NextTick then
			NextTick = os.clock() + P.ClimbTickEvery
			local Kind = Moving and "ClimbMove" or "ClimbHang"
			if not HasStamina(Character, Kind) then LetGo() return end
			Charge(Kind)
		end
		if not Moving then
			StopStepping()
			return
		end

		-- the wall must continue that way (probe at head height, like the grab, a little ahead)
		local Right = (-Normal):Cross(Vector3.yAxis).Unit
		-- probe length: 4 + ClimbProbeExtra. With a flat 4, climbing past anything that juts out (a ledge strip,
		-- trim, a beam) left the climber hanging off ITS face; above it the real wall was just out of reach and the
		-- climb vaulted you off mid-wall as if it were the top (fluidity pass 2026-10-18, LedgeCourse L1)
		local Probe = 4 + (P.ClimbProbeExtra or 0)
		local function WallAt(Pos) return workspace:Raycast(Pos + Vector3.new(0, 3, 0) + Normal * 1.5, -Normal * Probe, WallProbe) end
		if Y ~= 0 and not WallAt(Align.Position + Vector3.yAxis * Y * 0.5) then
			if Y > 0 then
				-- top of the wall: vault onto the ledge
				LetGo()
				MoverManager.Velocity(Character, {D = 0.2, V = (Root.CFrame.LookVector * 30) + Vector3.new(0, 35, 0), Max = Vector3.new(4e4, 4e4, 4e4)})
				AnimationManager.Play(Character, "Vault" .. math.random(1, 2), {Priority = Enum.AnimationPriority.Action4})
				return
			end
			Y = 0 -- no wall below: only the sideways part, if any
		end
		if X ~= 0 and not WallAt(Align.Position + Right * X * 1.2) then X = 0 end -- the wall's edge
		if X == 0 and Y == 0 then
			StopStepping()
			return
		end
		if (Y < 0 or X ~= 0) and LedgeHandoff(Y, X) then return end

		-- up: pull by pull (a new step when the last one finished); down / sideways: a steady shuffle
		local Surge, Side = 1, (Y ~= 0) and 0.7 or 1
		if Y > 0 then
			if Mode ~= "Up" or os.clock() - StepStart >= STEP_TIME then StartStep() end
			local Phase = math.clamp((os.clock() - StepStart) / STEP_TIME, 0, 1)
			Surge = 1 - math.cos(Phase * 2 * math.pi) -- 0 at the hand swap, 2 mid-pull, averages 1
		elseif Y < 0 then
			StartLoop("Down", P.ClimbDownSpeed)
		else
			StartLoop(X > 0 and "SideRight" or "SideLeft", P.ClimbSideSpeed)
		end

		-- move along the wall plane
		local Vertical = Y > 0 and P.ClimbSpeed * Surge or P.ClimbDownSpeed
		local Delta = Right * X * P.ClimbSideSpeed * Side * Dt + Vector3.yAxis * Y * Vertical * Dt
		local Target = Align.Position + Delta
		local Hit = workspace:Raycast(Target + Vector3.new(0, 3, 0) + Normal * 1.5, -Normal * Probe, WallProbe)
		if not Hit then return end
		if Y < 0 and workspace:Raycast(Root.Position, Vector3.new(0, -3.3, 0), WallProbe) then
			LetGo() -- climbed down to the ground
			return
		end
		Normal = Hit.Normal
		-- keep the WHOLE body clear of anything jutting out of the wall (fluidity pass 2026-10-18): the head probe
		-- alone let the legs drag over a ledge strip while climbing past it (the humanoid kept trying to stand on it:
		-- state flicker and +99 / -58 studs/s jolts). Chest and shin probes push the hang point out as needed.
		local Out = 0
		for _, Dy in ipairs({0.5, -2, -2.9}) do -- chest, shins, feet
			local Low = workspace:Raycast(Target + Vector3.new(0, Dy, 0) + Normal * 1.5, -Normal * Probe, WallProbe)
			if Low then Out = math.max(Out, (Low.Position - Hit.Position):Dot(Normal)) end
		end
		Align.Position = Hit.Position + Normal * (WALL_GAP + Out) - Vector3.new(0, 3, 0)
		if self.AlignOrientation and self.AlignOrientation.Parent then
			self.AlignOrientation.CFrame = CFrame.new(Hit.Position, Hit.Position - Normal)
		end
	end)
end

function Air:ClimbAction(Character)
	local Root = Character.HumanoidRootPart
	local Humanoid = Character.Humanoid
	
	local Direction = Vector3.new(0,1,0)
	if not HasStamina(Character, "ClimbStep") then
		-- out of stamina: let go
		EffectModules["Hang"].locally(Character,self.CurrentSide,"Destroy")
		MoverManager.ClearMovers(Character)
		self.ClimbState(Player,false)
		Humanoid.AutoRotate = true
		if self.ClimbConn then self.ClimbConn:Disconnect() self.ClimbConn = nil end
		StopClimbAnims(Character)
		return
	end
	Charge("ClimbStep")
	-- straight up only (no diagonal leap with A/D)
	local Intersection,YModifier = FindNextClimb(Character,Direction)

	if Intersection then
		local MaxTime = 0.2
		local TweenTime = 0.2 * YModifier

		AnimationManager.Play(Character,self.CurrentSide.."Climb",{Stop = self.CurrentSide.."ClimbIdle",Priority = Enum.AnimationPriority.Action2})
		
		local LastSide = self.CurrentSide

		self.CurrentSide = self.CurrentSide == "Right" and "Left" or "Right"

		local Align, Orient = self.AlignPosition, self.AlignOrientation
		local function StillClimbing()
			return Align ~= nil and Align.Parent ~= nil and self.AlignPosition == Align
		end

		coroutine.wrap(function()
			task.wait(0.2)
			if not StillClimbing() then return end -- let go meanwhile

			self.PlayFX(Player,"Climb",LastSide)
			EffectModules["Hang"].locally(Character,LastSide,"Destroy")
			EffectModules["Hang"].locally(Character,self.CurrentSide)

			TweenService:Create(Align,TweenInfo.new(TweenTime),{Position = Intersection.Position - Vector3.new(0,3,0) + (Intersection.Normal * WALL_GAP)}):Play()
			if Orient and Orient.Parent then
				TweenService:Create(Orient,TweenInfo.new(TweenTime),{CFrame = CFrame.new(Intersection.Position, Intersection.Position - Intersection.Normal)}):Play()
			end

			task.wait(0.2)
			-- (this used to restart the LOOPED hang idle even after you had let go -- the stuck pose)
			if not StillClimbing() then return end

			AnimationManager.Play(Character,self.CurrentSide.."ClimbIdle",{Looped = true,Priority = Enum.AnimationPriority.Action})
		end)()

	else
		EffectModules["Hang"].locally(Character,self.CurrentSide,"Destroy")
		coroutine.wrap(function()
			local CanVault,VaultSurface = CheckVault(Character)

			if Direction == Vector3.new(0,1,0) and CanVault and VaultSurface then
				--vaulting up wall if upwards and close enough
				local RootCFrame = Character.HumanoidRootPart.CFrame
				if self.ClimbConn then self.ClimbConn:Disconnect() self.ClimbConn = nil end
				MoverManager.ClearMovers(Character)
				self.ClimbState(Player,false)

				Humanoid.AutoRotate = true

				StopClimbAnims(Character)
				MoverManager.Velocity(Character,{D = 0.2,V = (RootCFrame.LookVector * 30) + Vector3.new(0,30,0),Max = Vector3.new(4e4,4e4,4e4)})
				AnimationManager.Play(Character,"Vault"..math.random(1,2),{Priority = Enum.AnimationPriority.Action4})
			else
				-- wall jump in direction
				AnimationManager.Play(Character,self.CurrentSide.."Climb",{Stop = self.CurrentSide.."ClimbIdle"})
				task.wait(0.2)

				if self.ClimbConn then self.ClimbConn:Disconnect() self.ClimbConn = nil end
				MoverManager.ClearMovers(Character)
				self.ClimbState(Player,false)

				Humanoid.AutoRotate = true

				StopClimbAnims(Character)
				MoverManager.Velocity(Character,{D = 0.2,V = Direction * 60})
			end

		end)()

	end
end


function Air:OnStartClient()
	local Character = Player.Character
	local CharacterState = WCSCharacter.GetCharacterFromInstance(Character)
	local Humanoid = Character.Humanoid
	local Root = Character.HumanoidRootPart

	-- really hanging on a wall (the climb loop + its anchor) -- the Climbing status alone also covers a
	-- ledge pull-up and lingers a moment after letting go, and used to send Space here with no climb
	-- side set ("attempt to concatenate nil" in ClimbAction)
	-- on a narrow ledge (LedgeWalk): Space hops off it, away from the wall
	if Air.LedgeConn and Air.EndLedge then
		Air.EndLedge("Jump", true)
		return
	end
	local OnWall = self.ClimbConn ~= nil and self.AlignPosition ~= nil and self.AlignPosition.Parent ~= nil
	self.CurrentSide = self.CurrentSide or "Right"
	if CharacterState:HasStatusEffects({Climbing}) and self.WallRunConn then
		-- Space pressed again mid wall run: kick off now
		if self.EndWallRun then self.EndWallRun(true) end
	elseif CharacterState:HasStatusEffects({Climbing}) and not self.WallRunConn and not OnWall then
		return -- pulling up / just let go: nothing to do on the wall
	elseif OnWall and not self.WallRunConn then
		-- Action while climbing
		if os.clock() < ClimbCooldown then return end
		ClimbCooldown = os.clock() + 0.5
		
		if Held(Enum.KeyCode.S) then
			-- jump backwards while climbing
			EffectModules["Hang"].locally(Character,self.CurrentSide,"Destroy")

			self.PlayFX(Player,"WallJump")

			if self.ClimbConn then self.ClimbConn:Disconnect() self.ClimbConn = nil end
			MoverManager.ClearMovers(Character)

			self.ClimbState(Player,false)
			Character:SetAttribute("LastWallJump",workspace:GetServerTimeNow())
			StopClimbAnims(Character)
			AnimationManager.Play(Character,"WallKick",{Priority = Enum.AnimationPriority.Action2})

			Humanoid.AutoRotate = true

			MoverManager.Velocity(Character,{D = 0.2,V = (Character.HumanoidRootPart.CFrame.LookVector * -50) + Vector3.new(0,50,0)})
		elseif Held(Enum.KeyCode.W) then
			-- climb upwards/sidewards

			Air:ClimbAction(Character)
		else
			EffectModules["Hang"].locally(Character,self.CurrentSide,"Destroy")
			if self.ClimbConn then self.ClimbConn:Disconnect() self.ClimbConn = nil end
			MoverManager.ClearMovers(Character)
			self.ClimbState(Player,false)

			Humanoid.AutoRotate = true

			StopClimbAnims(Character)
		end
	else -- Not Climbing
		local Intersection = HitObject(Character)
		local SideIntersection,WhichSide = SideObject(Character)
		if Humanoid.JumpHeight == 0 then return end
		if (Humanoid:GetState() ~= Enum.HumanoidStateType.Jumping and Humanoid:GetState() ~= Enum.HumanoidStateType.Freefall) then
			
			if Humanoid.WalkSpeed > 28 and os.clock() - self.LastJumped >= 5 then
				self.PlayFX(Player,"Roll",(Root.CFrame.LookVector + Vector3.new(0,1,0)).Unit)
				AnimationManager.Play(Character,"SpeedyRunJump",{Priority = Enum.AnimationPriority.Action})
				MoverManager.Velocity(Character,{V = (Root.CFrame.LookVector * 50) + Vector3.new(0,50,0),D = 0.2})
				self.LastJumped = os.clock()
			else
				Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end

			
			local JumpConn; JumpConn = Humanoid.StateChanged:Connect(function()
				if Humanoid:GetState() ~= Enum.HumanoidStateType.Jumping and Humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
					Humanoid.JumpHeight = DefaultJH
					self.DoubleJump = true

					-- landing on the move (fluidity pass 2026-10-18): the landing (authored at Action priority) used to
					-- replace the run's legs for 0.5 s while sliding at sprint speed. Moving, it now blends in at Movement
					-- priority and plays quicker (a short dip); standing still it plays as before.
					local Moving = Humanoid.MoveDirection.Magnitude > 0.1
					AnimationManager.Play(Character,"DefaultLanding",{
						Priority = Moving and Enum.AnimationPriority.Movement or nil, Speed = Moving and 1.8 or 1,
					})

					JumpConn:Disconnect()
				end
			end)
		elseif (Humanoid:GetState() == Enum.HumanoidStateType.Jumping or Humanoid:GetState() == Enum.HumanoidStateType.Freefall) and Intersection and Held(Enum.KeyCode.S) then
			if os.clock() < ClimbCooldown then return end
			
			AnimationManager.Play(Character,"WallKick")
			
			MoverManager.LookAt(Character,{C = CFrame.new(Intersection.Position, Intersection.Position - Intersection.Normal),Max = math.huge,D = 0.2})
			
			self.PlayFX(Player,"WallJump")

			Humanoid.AutoRotate = true

			MoverManager.Velocity(Character,{D = 0.2,V = (Character.HumanoidRootPart.CFrame.LookVector * -50) + Vector3.new(0,50,0)})
		elseif (Humanoid:GetState() == Enum.HumanoidStateType.Jumping or Humanoid:GetState() == Enum.HumanoidStateType.Freefall) and Intersection
			and not Air.AirUses.Climb and HasStamina(Character, "ClimbStart") then
			-- tap Space facing a wall in the air: grab it (directional climb, controls doc)
			--Climbing start
			Air.AirUses.Climb = true
			Charge("ClimbStart")
			self.ClimbState(Player,true)

			AnimationManager.Play(Character,"RightClimbIdle",{Looped = true,Stop = "DoubleJump"})

			Humanoid.AutoRotate = false
			self.CurrentSide = "Right"
			self.AlignPosition = MoverManager.AlignPosition(Character,{P = Intersection.Position + (Intersection.Normal * WALL_GAP) - Vector3.new(0,3,0),Max = Vector3.one * math.huge,R = math.huge})
			self.AlignOrientation = MoverManager.LookAt(Character,{C = CFrame.new(Intersection.Position, Intersection.Position - Intersection.Normal),Max = math.huge})
			EffectModules["Hang"].locally(Character, self.CurrentSide)

			self:ClimbLoop(Character, Intersection.Normal)

			ClimbCooldown = os.clock() + 0.25
		elseif (Humanoid:GetState() == Enum.HumanoidStateType.Jumping or Humanoid:GetState() == Enum.HumanoidStateType.Freefall) and SideIntersection
			and not self.WallRunConn and CanWallRun(SideIntersection) and HasStamina(Character, "WallRun")
		then
			-- ===== Wall run (controls doc: airborne + HOLD Space near a wall; short burst; heavy
			-- stamina; no combat; one per airtime). Devil Hunter feel: run the way you were heading,
			-- a small rise-then-fall arc, and releasing Space kicks you off the wall.
			Air.AirUses.WallRun = {Normal = SideIntersection.Normal, Position = SideIntersection.Position, At = math.huge}
			Charge("WallRun")
			local P = Tuning.Parkour
			local Normal = SideIntersection.Normal
			local function AlongWall(Look, N)
				local A = Look - N * Look:Dot(N)
				A = Vector3.new(A.X, 0, A.Z)
				return A.Magnitude > 0.2 and A.Unit or nil
			end
			local Along = AlongWall(Root.CFrame.LookVector, Normal)
				or AlongWall(Humanoid.MoveDirection, Normal)
				or Normal:Cross(Vector3.yAxis).Unit
			local V0 = Root.AssemblyLinearVelocity
			local Speed = math.max(P.WallRunSpeed, Vector3.new(V0.X, 0, V0.Z):Dot(Along))
			-- which side the wall is on, relative to the run direction (picks the animation)
			local Side = (-Normal):Dot(Along:Cross(Vector3.yAxis)) > 0 and "Right" or "Left"

			Humanoid.AutoRotate = false
			self.ClimbState(Player, true, true) -- Climbing status: no attacking on the wall
			AnimationManager.Play(Character, "WallRun" .. Side, {Looped = true, Priority = Enum.AnimationPriority.Action2})
			local RunTime = P.WallRunDuration * SkillMods.Mult(Character, "WallRunTime") -- Acrobat: longer wall runs
			local Velocity = MoverManager.Velocity(Character, {V = Along * Speed, D = RunTime + 0.2, Max = Vector3.new(4e4, 4e4, 4e4)})
			local Orientation = MoverManager.LookAt(Character, {C = CFrame.lookAt(Vector3.zero, Along), Max = math.huge})

			local WallParams = RaycastParams.new()
			WallParams.FilterType = Enum.RaycastFilterType.Exclude
			WallParams.FilterDescendantsInstances = {Character, workspace.World.Live, workspace.World.Visuals}
			local Start = os.clock()
			local WallPos = SideIntersection.Position -- latest point on the wall being ridden
			local NextTick = Start + P.WallRunTickEvery
			local StuckSince = nil

			local function EndWallRun(Kick)
				if not self.WallRunConn then return end
				-- remember the wall we leave (its latest normal): the next wall run must be a different one
				if type(Air.AirUses.WallRun) == "table" then
					Air.AirUses.WallRun = {Normal = Normal, Position = WallPos, At = os.clock()}
				end
				self.WallRunConn:Disconnect()
				self.WallRunConn = nil
				self.EndWallRun = nil
				if Velocity.Parent then Velocity:Destroy() end
				if Orientation.Parent then Orientation:Destroy() end
				self.ClimbState(Player, false)
				Humanoid.AutoRotate = true
				AnimationManager.Stop(Character, "WallRun" .. Side)
				if Kick then
					AnimationManager.Play(Character, "WallJump" .. Side)
					self.PlayFX(Player, "WallJump", Side)
					Character:SetAttribute("LastWallJump", workspace:GetServerTimeNow())
					MoverManager.Velocity(Character, {V = Along * P.KickAlong + Normal * P.KickAway + Vector3.new(0, P.KickUp, 0), D = 0.18})
				elseif Kick == false then
					-- timed out mid-air: carry some momentum off the wall instead of stopping dead
					MoverManager.Velocity(Character, {V = Along * Speed * 0.55 + Normal * 8, D = 0.18, Max = Vector3.new(4e4, 0, 4e4)})
				end
			end
			self.EndWallRun = EndWallRun

			self.WallRunConn = RunService.RenderStepped:Connect(function()
				local T = os.clock() - Start
				local Holding = HoldingJump() or Humanoid.Jump
				if not Holding then EndWallRun(true) return end -- released: kick off
				if T >= RunTime or CharacterState:HasStatusEffects({Stun}) or Humanoid.Health <= 0 then
					EndWallRun(false) return
				end
				if T > 0.1 and workspace:Raycast(Root.Position, Vector3.new(0, -3.5, 0), WallParams) then
					EndWallRun(nil) return -- landed: no carry
				end
				-- blocked by something in the way (another player, a pillar): end instead of grinding
				local Moving = Root.AssemblyLinearVelocity:Dot(Along)
				if T > 0.2 and Moving < 5 then
					StuckSince = StuckSince or os.clock()
					if os.clock() - StuckSince > 0.3 then EndWallRun(true) return end
				else
					StuckSince = nil
				end
				-- steady stamina drain while riding; out of stamina = dismount with momentum
				if os.clock() >= NextTick then
					NextTick += P.WallRunTickEvery
					if not HasStamina(Character, "WallRunTick") then EndWallRun(false) return end
					Charge("WallRunTick")
				end
				local Hit = workspace:Raycast(Root.Position, -Normal * 4.5, WallParams)
				if not Hit then EndWallRun(true) return end -- ran out of wall: hop off it
				-- follow curved walls
				Normal = Hit.Normal
				WallPos = Hit.Position
				Along = AlongWall(Along, Normal) or Along
				Orientation.CFrame = CFrame.lookAt(Vector3.zero, Along)
				local Rise = math.max(-P.WallRunSink, P.WallRunRise * (1 - T / P.WallRunRiseTime))
				Velocity.VectorVelocity = Along * Speed + (-Normal) * 3 + Vector3.new(0, Rise, 0)
			end)
		elseif (Tuning.Movement.DoubleJump and (Humanoid:GetState() == Enum.HumanoidStateType.Jumping or Humanoid:GetState() == Enum.HumanoidStateType.Freefall) and os.clock() - self.LastJumped >= self.JumpDelay and self.DoubleJump) then
			self.DoubleJump = false
			self.PlayFX(Player,"DoubleJump")
			Humanoid.JumpHeight = DefaultJH * 2--self.DoubleJumpMultiplier
			AnimationManager.Play(Character,"DoubleJump")
			Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		elseif (Humanoid:GetState() == Enum.HumanoidStateType.Jumping or Humanoid:GetState() == Enum.HumanoidStateType.Freefall)
			and not Intersection and not Air.AirUses.Climb then
			-- grab buffer (fluidity pass 2026-10-18): Space in the air a moment BEFORE the wall is in reach still grabs
			-- it (the Heartbeat below takes it the moment the wall comes in reach). A sprint jump is only ~0.3 s
			-- airborne, and a press just early used to do nothing -- you hit the wall and dropped.
			Air.GrabBufferUntil = os.clock() + (Tuning.Parkour.GrabBuffer or 0)
		end
	end
end

-- Movement effects a client may broadcast, each with its arguments checked (the server used to play any
-- effect module with any arguments). Returns the checked arguments, or nil to refuse.
local FXLast = {} -- [Player] = {[Type] = os.clock() of the last one}
if RunService:IsServer() then
	Players.PlayerRemoving:Connect(function(P) FXLast[P] = nil end)
end
local function IsSide(S) return S == "Left" or S == "Right" end
local FXRules = {
	Climb = function(Character, Side)
		if IsSide(Side) and MovementState.Get(Character) == "Climb" then return {Side} end
	end,
	WallJump = function(Character, Side)
		if Side == nil or IsSide(Side) then return {Side} end
	end,
	Roll = function(Character, Direction)
		if typeof(Direction) ~= "Vector3" then return end
		local M = Direction.Magnitude
		if M ~= M or M < 0.1 or M == math.huge then return end -- NaN / zero / infinite
		return {Direction.Unit}
	end,
	DoubleJump = function()
		if Tuning.Movement.DoubleJump then return {} end
	end,
}

function Air.PlayFX(Player,Type,...)
	if RunService:IsClient() then
		ReplicatedStorage.Remotes.JumpRemote:FireServer("PlayFX",Type,...)
	else
		local Character = Player.Character
		local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
		local Rule = type(Type) == "string" and FXRules[Type]
		if not Rule or not EffectModules[Type] or not Humanoid or Humanoid.Health <= 0 or MovementState.Blocked(Character) then return end
		local Args = Rule(Character, ...)
		if not Args then return end
		local Last = FXLast[Player] or {}
		FXLast[Player] = Last
		local Now = os.clock()
		if Last[Type] and Now - Last[Type] < Tuning.Traversal.FXMinInterval then return end
		Last[Type] = Now
		EffectModules[Type].new(Character, table.unpack(Args, 1, 1)):Start(Players:GetPlayers())
	end


end

--WCS.DefineMessage(Air.PlayFX,{
--	Type = "Event",
--	Destination = "Server",
--})

-- Client: ask the server to start (State = true; NoBar = it's a wall run) or end the climb / wall run.
-- Each start is a new numbered session; the server's answer (TraversalSession) is matched against it
-- in Watch above. Server: MovementState validates it, owns the state and the Climbing status.
local TraversalSeq = 0
function Air.TraversalState(Player, State, Kind, Seq)
	if RunService:IsClient() then
		if State then
			TraversalSeq += 1
			Air.PendingTraversal = {Seq = TraversalSeq, Kind = Kind}
		else
			Air.PendingTraversal = nil
		end
		ReplicatedStorage.Remotes.JumpRemote:FireServer("TraversalState", State, Kind, TraversalSeq)
	else
		MovementState.Request(Player, State == true, Kind, Seq)
	end
end

-- Climb / wall run (NoBar = it's a wall run). Kept for its callers; the client sends TraversalState.
function Air.ClimbState(Player,State,NoBar,Seq)
	local Kind = NoBar and "WallRun" or "Climb"
	if RunService:IsClient() then
		Air.TraversalState(Player, State, Kind)
	else
		MovementState.Request(Player, State == true, Kind, Seq)
	end
end

--WCS.DefineMessage(Air.ClimbState,{
--	Type = "Event",
--	Destination = "Server",
--})

return Air
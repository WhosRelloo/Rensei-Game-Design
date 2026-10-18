-- LedgeWalk (client; part of JumpManager): narrow wall-ledge traversal (owner 2026-10-17; reference: the
-- Tomb Raider cliffside ledge walk -- face the wall, body close to it, sidestep along a narrow foothold).
--
-- AUTHORED LEDGES ONLY. A ledge is any BasePart tagged "RenseiLedge" (TuningConfig.LedgeWalk.Tag):
--   * its top face is the foothold; its length (Size.X, along the part's RightVector) is the whole path, and
--     its two ends are the endpoints -- you can never walk past them;
--   * its FRONT face (LookVector) points AT THE WALL; keep it level (the strip is flattened anyway);
--   * a ledge whose end is within JoinDistance of another ledge's end (and about level with it) CONTINUES into
--     it: a straight continuation, or a supported corner when the two run at an angle;
--   * past an end that has walkable map ground just beyond it (a platform), you step off onto it;
--   * any other end is a gap or a dead end: you stop there (no automatic jumps, no teleporting across).
-- Ordinary walls and untagged ledges are never traversable.
--
-- Entering: stand on a ledge (walk or drop onto it) for EnterChecks checks. You turn to face the wall.
-- Moving: the move input (WASD / thumbstick, camera-relative like normal walking) along the ledge. Round a joined
-- corner the travel direction sticks while the input is held, so the corner doesn't stall it.
-- Leaving: step off at a platform end; hold away from the wall StepOffHold s (step down); Space = hop back off
-- the wall; Space while pushing toward the wall = hop up into the existing climb (JumpManager) if the wall
-- above can be climbed; or the server ends it (MovementState: stun, knock, grip, carry, death, off the ledge).
-- Combat, dash, sprint and crouch are off meanwhile (the Climbing status the server sets). No stamina cost.
-- Animation: TuningConfig.LedgeWalk.Anim (see the note there). Numbers: TuningConfig.LedgeWalk (PROPOSAL).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local MoverManager = require(ReplicatedStorage.Modules.Managers.MoverManager)
local AnimationManager = require(ReplicatedStorage.Modules.Managers.AnimationManager)
local MovementState = require(ReplicatedStorage.Modules.Managers.MovementState)
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)
local WCS = require(ReplicatedStorage.Modules.Framework.WCS)
local Stun = require(ReplicatedStorage.Modules.Skills.States.Stun)
local Climbing = require(ReplicatedStorage.Modules.Skills.States.Climbing)

local LedgeWalk = {}

local function C() return Tuning.LedgeWalk end

local function Flat(V)
	V = Vector3.new(V.X, 0, V.Z)
	return V.Magnitude > 1e-3 and V.Unit or nil
end

-- The geometry of an authored ledge.
function LedgeWalk.Info(Part)
	local CF, S = Part.CFrame, Part.Size
	local Wall = Flat(CF.LookVector) -- toward the wall
	local Along = Flat(CF.RightVector)
	if not Wall or not Along then return nil end
	return {
		Part = Part, Wall = Wall, Along = Along, Half = S.X / 2, Depth = S.Z,
		Center = (CF * CFrame.new(0, S.Y / 2, 0)).Position, -- the middle of the top face
	}
end

local function EndPoint(L, Side) return L.Center + L.Along * Side * L.Half end

-- Root position for distance T along the ledge (from its centre).
local function RootAt(L, T, RootHeight)
	return L.Center + L.Along * T + L.Wall * (L.Depth / 2 - C().WallGap) + Vector3.new(0, RootHeight, 0)
end

local LedgeParams = RaycastParams.new()
LedgeParams.FilterType = Enum.RaycastFilterType.Include
local MapParams = RaycastParams.new()
MapParams.FilterType = Enum.RaycastFilterType.Include

-- The ledge the root stands on, and the distance along it, or nil.
function LedgeWalk.Under(Root)
	LedgeParams.FilterDescendantsInstances = CollectionService:GetTagged(C().Tag)
	local Hit = workspace:Raycast(Root.Position, Vector3.new(0, -5, 0), LedgeParams)
	if not Hit or Hit.Normal.Y < 0.7 then return nil end
	local L = LedgeWalk.Info(Hit.Instance)
	if not L then return nil end
	local T = (Hit.Position - L.Center):Dot(L.Along)
	if math.abs(T) > L.Half then return nil end
	return L, T, Root.Position.Y - L.Center.Y
end

-- Another ledge joined to this one's end (Side = +1 / -1): returns its info and the distance along it at the
-- joined end, and which way along it leads away from the join.
local function Joined(L, Side)
	local E = EndPoint(L, Side)
	for _, Part in ipairs(CollectionService:GetTagged(C().Tag)) do
		if Part ~= L.Part and Part:IsA("BasePart") then
			local Q = LedgeWalk.Info(Part)
			if Q then
				for _, QSide in ipairs({1, -1}) do
					local QE = EndPoint(Q, QSide)
					local D = Vector3.new(QE.X - E.X, 0, QE.Z - E.Z).Magnitude
					if D <= C().JoinDistance and math.abs(QE.Y - E.Y) <= C().JoinHeight then
						return Q, QSide * (Q.Half - C().EndMargin), -QSide
					end
				end
			end
		end
	end
	return nil
end

-- Walkable map ground just past an end (a platform to step off onto)?
local function PlatformBeyond(L, Side)
	MapParams.FilterDescendantsInstances = {workspace.World.Map}
	local Probe = EndPoint(L, Side) + L.Along * Side * C().PlatformStep - L.Wall * 0.2 + Vector3.new(0, 1.2, 0)
	local Hit = workspace:Raycast(Probe, Vector3.new(0, -3, 0), MapParams)
	return Hit ~= nil and Hit.Normal.Y > 0.7 and not CollectionService:HasTag(Hit.Instance, C().Tag)
		and math.abs(Hit.Position.Y - L.Center.Y) <= 1.5
end


function LedgeWalk.Enter(Air, Character, L, T, RootHeight)
	local Cfg = C()
	local Player = Players.LocalPlayer
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	local Root = Character:FindFirstChild("HumanoidRootPart")
	if not Humanoid or not Root then return end
	T = math.clamp(T, -(L.Half - Cfg.EndMargin), L.Half - Cfg.EndMargin)

	Air.TraversalState(Player, true, "LedgeWalk")
	Humanoid.AutoRotate = false
	local Align = MoverManager.AlignPosition(Character, {P = RootAt(L, T, RootHeight), Max = Vector3.one * math.huge, R = Cfg.Responsiveness})
	local Orient = MoverManager.LookAt(Character, {C = CFrame.lookAt(Vector3.zero, L.Wall), Max = math.huge})
	-- poses (sheet 2026-10-18): Walk Left / Walk Right while moving, the ledge idle of the side you last moved to
	-- while standing. With no AnimRight the left walk plays backwards (the old behaviour).
	local Current, CurrentTrack, LastLeft = nil, nil, true
	local function Pose(Name, Speed)
		if Name ~= Current then
			if CurrentTrack then CurrentTrack:Stop(0.15) end
			CurrentTrack = Name and AnimationManager.Play(Character, Name, {Looped = true, Priority = Enum.AnimationPriority.Action}) or nil
			Current = Name
		end
		if CurrentTrack and Speed then CurrentTrack:AdjustSpeed(Speed) end
	end
	Pose(Cfg.IdleLeft or Cfg.Anim, Cfg.IdleLeft and 1 or 0)
	local AwaySince = nil
	local Sticky = nil -- the travel direction kept round a joined corner while the input is held

	local function Exit(Reason, Hop)
		if not Air.LedgeConn then return end
		Air.LedgeConn:Disconnect()
		Air.LedgeConn = nil
		Air.EndLedge = nil
		if Root.Parent then MoverManager.ClearMovers(Character) end
		Humanoid.AutoRotate = true
		if CurrentTrack then CurrentTrack:Stop(0.15) end
		for _, N in ipairs({Cfg.Anim, Cfg.AnimRight, Cfg.IdleLeft, Cfg.IdleRight}) do AnimationManager.Stop(Character, N) end
		Air.TraversalState(Player, false, "LedgeWalk")
		if LedgeWalk.MarkExit then LedgeWalk.MarkExit(Reason == "Server" and Cfg.RefusedCooldown or Cfg.RegrabCooldown) end
		if not Root.Parent or Humanoid.Health <= 0 then return end
		if Reason == "Jump" then
			if Humanoid.MoveDirection:Dot(L.Wall) > 0.5 then
				-- pushing toward the wall: hop up and grab it (the existing climb), if it's climbable
				Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				MoverManager.Velocity(Character, {D = 0.12, V = Vector3.new(0, Cfg.ClimbHop, 0)})
				-- hand over to the climb as soon as the body is really airborne (JumpManager grabs the wall ahead)
				task.spawn(function()
					local Until = os.clock() + 0.5
					while os.clock() < Until and Root.Parent and Humanoid.Health > 0 do
						local St = Humanoid:GetState()
						if St == Enum.HumanoidStateType.Freefall or St == Enum.HumanoidStateType.Jumping then
							task.wait(0.05)
							Air:OnStartClient()
							return
						end
						task.wait()
					end
				end)
			else
				MoverManager.Velocity(Character, {D = 0.15, V = -L.Wall * Cfg.HopAway + Vector3.new(0, Cfg.HopUp, 0)})
			end
		elseif Reason == "StepOff" then
			MoverManager.Velocity(Character, {D = 0.12, V = -L.Wall * Cfg.StepOffSpeed})
		elseif Reason == "Platform" and Hop then
			MoverManager.Velocity(Character, {D = 0.15, V = Hop * Cfg.Speed * 1.5})
		end
	end
	Air.EndLedge = Exit

	Air.LedgeConn = RunService.RenderStepped:Connect(function(Dt)
		if not Align.Parent or not Root.Parent or Humanoid.Health <= 0 or not L.Part.Parent then Exit("Lost") return end
		-- camera-relative move input (the same as walking), along the ledge
		local Move = Humanoid.MoveDirection
		local Proj = Move:Dot(L.Along)
		local Dir = 0
		if Move.Magnitude < 0.3 then
			Sticky = nil
		elseif math.abs(Proj) >= Cfg.InputDeadzone then
			Dir = math.sign(Proj)
			Sticky = nil
		elseif Sticky then
			Dir = Sticky -- just round a corner: keep going while the input is held
		end

		-- holding away from the wall (and not along it): step down off the ledge
		if Dir == 0 and Move:Dot(-L.Wall) > 0.75 then
			AwaySince = AwaySince or os.clock()
			if os.clock() - AwaySince >= Cfg.StepOffHold then Exit("StepOff") return end
		else
			AwaySince = nil
		end

		local Moved = 0
		if Dir ~= 0 then
			local Step = Cfg.Speed * Dt
			MapParams.FilterDescendantsInstances = {workspace.World.Map}
			local Blocked = workspace:Raycast(Root.Position, L.Along * Dir * (Cfg.BodyHalfWidth + Step), MapParams)
			-- near an end that turns a supported corner, the corner's other wall is not an obstacle
			if Blocked and L.Half - math.abs(T) < Cfg.BodyHalfWidth + 1 and Joined(L, Dir) then Blocked = nil end
			if not (Blocked and Blocked.Normal:Dot(L.Along * Dir) < -0.5 and not CollectionService:HasTag(Blocked.Instance, Cfg.Tag)) then
				local NewT = T + Dir * Step
				local Limit = L.Half - Cfg.EndMargin
				if math.abs(NewT) <= Limit then
					T = NewT
					Moved = Dir
				else
					local Side = math.sign(NewT)
					local Q, QT, Away = Joined(L, Side)
					if Q then
						L, T = Q, QT -- continue onto the joined ledge (a corner turns the body smoothly)
						Sticky = Away
						Moved = Dir
					elseif PlatformBeyond(L, Side) then
						Exit("Platform", L.Along * Side) return
					else
						T = Side * Limit -- a gap or a dead end: stop at the edge
					end
				end
			end
		end

		Align.Position = RootAt(L, T, RootHeight)
		Orient.CFrame = CFrame.lookAt(Vector3.zero, L.Wall)
		-- facing the wall, left = Up x Wall
		local Toward = Moved * math.sign(Vector3.yAxis:Cross(L.Wall):Dot(L.Along)) -- > 0: moving to the left
		if Toward > 0 then
			LastLeft = true
			Pose(Cfg.Anim, Cfg.AnimSpeed)
		elseif Toward < 0 then
			LastLeft = false
			if Cfg.AnimRight then Pose(Cfg.AnimRight, Cfg.AnimSpeed) else Pose(Cfg.Anim, -Cfg.AnimSpeed) end
		else
			local Idle = LastLeft and Cfg.IdleLeft or Cfg.IdleRight
			if Idle then Pose(Idle, 1) elseif CurrentTrack then CurrentTrack:AdjustSpeed(0) end
		end
	end)
end

-- Started once by JumpManager:OnConstructClient. Cheap: one downward ray at the tagged ledges every
-- CheckEvery seconds, and only while the character is on its feet with nothing else going on.
function LedgeWalk.Start(Air)
	local Cfg = C()
	local Player = Players.LocalPlayer
	local Hits, NextCheck, ReadyAt = 0, 0, 0
	LedgeWalk.MarkExit = function(Cooldown) ReadyAt = os.clock() + (Cooldown or Cfg.RegrabCooldown) end
	RunService.Heartbeat:Connect(function()
		if os.clock() < NextCheck then return end
		NextCheck = os.clock() + Cfg.CheckEvery
		local Character = Player.Character
		local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
		local Root = Character and Character:FindFirstChild("HumanoidRootPart")
		local State = Humanoid and Humanoid:GetState()
		local Free = Humanoid and Root and Humanoid.Health > 0
			and not (Air.LedgeConn or Air.ClimbConn or Air.WallRunConn)
			and os.clock() >= ReadyAt
			and (State == Enum.HumanoidStateType.Running or State == Enum.HumanoidStateType.RunningNoPhysics)
			and not Character:GetAttribute("CombatState") and not MovementState.Blocked(Character)
			and not MovementState.Get(Character)
		if Free then
			local CS = WCS.Character.GetCharacterFromInstance(Character)
			Free = CS ~= nil and not CS:HasStatusEffects({Stun, Climbing})
		end
		local L, T, RootHeight
		if Free then L, T, RootHeight = LedgeWalk.Under(Root) end
		if not L then Hits = 0 return end
		Hits += 1
		if Hits >= Cfg.EnterChecks then
			Hits = 0
			LedgeWalk.Enter(Air, Character, L, T, RootHeight)
		end
	end)
end

return LedgeWalk

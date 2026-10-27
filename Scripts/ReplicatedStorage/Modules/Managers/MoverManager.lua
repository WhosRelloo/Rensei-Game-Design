local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local SkillData = require(ReplicatedStorage.Modules.Data.SkillData)

local IsClient = RunService:IsClient()
local MoverRemote = script.MoverRemote

local KBParams = RaycastParams.new()
KBParams.FilterType = Enum.RaycastFilterType.Include
KBParams.FilterDescendantsInstances = {workspace.World.Map}

local DefaultWS = game.StarterPlayer.StarterCharacter.Humanoid.WalkSpeed
local DefaultJH = game.StarterPlayer.StarterCharacter.Humanoid.JumpHeight

local MoverManager = {}

-- Frozen solid (StatusManager's Freeze): no other movement change may let the victim walk.
local function Frozen(Character)
	-- 0.1s slack: the freeze's own movement change ends right at the expiry and must hand speed back
	return (Character:GetAttribute("StatusFreeze") or 0) > workspace:GetServerTimeNow() + 0.1
end

function MoverManager.Movement(Character,Info)
	local WalkSpeed = Info.WS
	local JumpHeight = Info.JH
	local Duration = Info.D
	local CurrentMovement = Character:GetAttribute("Movement")
	
	if not CurrentMovement then
		Character:SetAttribute("Movement",0)
		CurrentMovement = 0
	end
	
	Character:SetAttribute("Movement",CurrentMovement + 1)
	if WalkSpeed then Character.Humanoid.WalkSpeed = WalkSpeed end
	if JumpHeight then Character.Humanoid.JumpHeight = JumpHeight end
	if Frozen(Character) then
		Character.Humanoid.WalkSpeed = 0
		Character.Humanoid.JumpHeight = 0
	end
	
	task.delay(Duration,function()
		-- the character may have died or been removed meanwhile
		local Humanoid = Character.Parent and Character:FindFirstChildOfClass("Humanoid")
		if not Humanoid then return end
		Character:SetAttribute("Movement",(Character:GetAttribute("Movement") or 1) - 1)
		if Character:GetAttribute("Movement") == 0 then
			-- knocked / gripping / carrying own the walk speed (DownedManager); don't hand it back
			if Character:GetAttribute("Gripping") or Frozen(Character) then
				Character.Humanoid.WalkSpeed = 0
				Character.Humanoid.JumpHeight = 0
			elseif Character:GetAttribute("Knocked") then
				-- a knocked player crawls (DownedManager.KnockedSpeed, owner 2026-10-27); anyone else stays still
				Character.Humanoid.WalkSpeed = require(ReplicatedStorage.Modules.Managers.DownedManager).KnockedSpeed(Character)
				Character.Humanoid.JumpHeight = 0
			elseif Character:GetAttribute("Carrying") then
				local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)
				Character.Humanoid.WalkSpeed = Tuning.Downed.CarryWalkSpeed
				Character.Humanoid.JumpHeight = 0
			else
				local Enemy = Character:GetAttribute("EnemyType")
				local Tuning = Enemy and require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)
				Character.Humanoid.WalkSpeed = Enemy and Tuning.Enemies[Enemy].WalkSpeed
					or DefaultWS * (Character:GetAttribute("SpeedMultiplier") or 1)
				Character.Humanoid.JumpHeight = DefaultJH
			end
		end
	end)
end

function MoverManager.Velocity(Character,Info:{V:'Velocity/Target (Vector3)',D:'Duration',Max:'Max Force'})
	if Info.Clear then MoverManager.ClearMovers(Character) end
	local Part = Character:FindFirstChild("HumanoidRootPart") or Character
	local Attachment = Part:FindFirstChild("VelocityAttachment")
	local LinearVelocity = script.LinearVelocity:Clone()
	LinearVelocity.VectorVelocity = Info.V
	LinearVelocity.MaxAxesForce = Info.Max or LinearVelocity.MaxAxesForce
	LinearVelocity.Attachment0 = Attachment
	LinearVelocity.Parent = Attachment

	Debris:AddItem(LinearVelocity,Info.D)
	
	return LinearVelocity
end

function MoverManager.DeadVelocity(Character,Info) -- .T = time until velocity is set to 0, .D is total velocity Duration
	if Info.Clear then MoverManager.ClearMovers(Character) end
	local Part = Character:FindFirstChild("HumanoidRootPart") or Character
	local Attachment = Part:FindFirstChild("VelocityAttachment")
	local LinearVelocity = script.LinearVelocity:Clone()
	LinearVelocity.VectorVelocity = Info.V
	LinearVelocity.Attachment0 = Attachment
	LinearVelocity.Parent = Attachment
	
	task.delay(Info.T,function()
		LinearVelocity.VectorVelocity = Vector3.new(0,0,0)
	end)

	Debris:AddItem(LinearVelocity,Info.D)

	return LinearVelocity
end

function MoverManager.LookAt(Character,Info)
	if Info.Clear then MoverManager.ClearMovers(Character) end
	local Part = Character:FindFirstChild("HumanoidRootPart") or Character
	local Attachment = Part:FindFirstChild("VelocityAttachment")
	local CFrameCalculation = Info.V and CFrame.new(Part.Position,Info.V) or Info.C -- v is target position and c would be the actual position
	local AlignOrientation = script.AlignOrientation:Clone()
	AlignOrientation.MaxTorque = Info.Max or AlignOrientation.MaxTorque
	AlignOrientation.CFrame = CFrameCalculation or Part.CFrame
	AlignOrientation.Attachment0 = Attachment
	AlignOrientation.Parent = Attachment
	if Info.D then
		Debris:AddItem(AlignOrientation,Info.D)
	end
	
	return AlignOrientation
end

function MoverManager.AlignPosition(Character,Info)
	if Info.Clear then MoverManager.ClearMovers(Character) end
	local Part = Character:FindFirstChild("HumanoidRootPart") or Character
	local Attachment = Part:FindFirstChild("VelocityAttachment")
	local Position = Info.P
	
	local AlignPosition = script.AlignPosition:Clone()
	AlignPosition.Position = Position  or Part.Position
	AlignPosition.Responsiveness = Info.R or AlignPosition.Responsiveness
	AlignPosition.MaxAxesForce = Info.Max or AlignPosition.MaxAxesForce
	AlignPosition.Attachment0 = Attachment
	AlignPosition.Parent = Attachment
	if Info.D then
		Debris:AddItem(AlignPosition,Info.D)
	end

	return AlignPosition
end

function MoverManager.Knockback(Character,Info) -- RL == RayLength, LD = Landing Duration (when you hit a wall or smth)
	if Info.Clear then MoverManager.ClearMovers(Character) end
	local Part = Character:FindFirstChild("HumanoidRootPart") or Character
	local Velocity = MoverManager.Velocity(Character,Info)
	-- Face back along the knock, YAW ONLY: a pitched facing (from a downward knock) used to tip
	-- characters over.
	local Flat = Vector3.new(-Info.V.X, 0, -Info.V.Z)
	if Flat.Magnitude < 0.01 then Flat = Part.CFrame.LookVector * Vector3.new(1, 0, 1) end
	local LookAt = MoverManager.LookAt(Character,{C = CFrame.lookAt(Vector3.zero, Flat.Unit, Vector3.yAxis),D = Info.D})
	LookAt.AlignType = Enum.AlignType.AllAxes
	local Direction = Info.V.Unit
	local RayLength = Info.RL or 3
	local LandDuration = Info.LD or 1
	
	local KBConn; KBConn = RunService.Stepped:Connect(function()
		local Raycast = workspace:Raycast(Part.Position,Direction * RayLength,KBParams)
		if Raycast then
			Velocity.VectorVelocity = Vector3.new(0,0,0)
			Velocity.MaxAxesForce = Vector3.new(100000, 100000, 100000)
			LookAt:Destroy()
			Velocity:Destroy()
			
			-- Walls get the wall-splat (upright, facing away from the wall). Floors just stop the
			-- character where it is, upright. (This used to face the character along the floor's
			-- normal -- straight up -- leaving it lying on its back.)
			local Normal = Raycast.Normal
			local FlatNormal = Vector3.new(Normal.X, 0, Normal.Z)
			if math.abs(Normal.Y) < 0.5 and FlatNormal.Magnitude > 0.01 then
				local At = Raycast.Position + FlatNormal.Unit * 1.5
				At = Vector3.new(At.X, Part.Position.Y, At.Z)
				Part.CFrame = CFrame.lookAt(At, At + FlatNormal.Unit)
				if LandDuration > 0 then
					MoverManager.LookAt(Character,{C = CFrame.lookAt(Vector3.zero, FlatNormal.Unit), D = LandDuration})
					MoverManager.AlignPosition(Character,{P = At, D = LandDuration, R = 100000})
				end
			else
				MoverManager.Upright(Character)
			end
			
			if Info.LandAction then
				Info.LandAction(Raycast.Position,Raycast.Normal)
			end
			
			KBConn:Disconnect()
		end
	end)
	
	task.delay(Info.D,function()
		if KBConn then
			KBConn:Disconnect()
		end
		MoverManager.Upright(Character)
	end)
end

-- Stand a tipped character back up (keeps position and facing yaw).
function MoverManager.Upright(Character)
	local Part = Character and Character.Parent and Character:FindFirstChild("HumanoidRootPart")
	if not Part or Part.CFrame.UpVector.Y > 0.95 then return end
	local Look = Part.CFrame.LookVector
	local Flat = Vector3.new(Look.X, 0, Look.Z)
	if Flat.Magnitude < 0.01 then Flat = Vector3.new(0, 0, -1) end
	Part.CFrame = CFrame.lookAt(Part.Position, Part.Position + Flat.Unit)
	Part.AssemblyAngularVelocity = Vector3.zero
end

-- ===== Smooth attack movers (run on the owning client for players, on the server for NPCs) =====
local function Grounded(Character, Part, Distance)
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = {Character, workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Visuals")}
	return workspace:Raycast(Part.Position, Vector3.new(0, -(Distance or 3.6), 0), Params)
end

-- Lunge: eased forward burst (cosine ease-out), horizontal only, stops at walls.
-- Info: {Speed, D, StopAt}. StopAt (optional, studs): also stop once a character is that close in front
-- (a rush that should end at its target instead of running past it, e.g. Iron Rush).
function MoverManager.Lunge(Character, Info)
	local Part = Character:FindFirstChild("HumanoidRootPart")
	if not Part then return end
	local Look = Part.CFrame.LookVector
	local Dir = Vector3.new(Look.X, 0, Look.Z).Unit
	local Velocity = MoverManager.Velocity(Character, {V = Dir * Info.Speed, D = Info.D + 0.05, Max = Vector3.new(4e4, 0, 4e4)})
	local Start = os.clock()
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = {Character, workspace.World.Live}
	local StopAt = type(Info.StopAt) == "number" and Info.StopAt > 0 and Info.StopAt or nil
	local Live = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Live")
	local LiveParams
	if StopAt and Live then
		LiveParams = RaycastParams.new()
		LiveParams.FilterType = Enum.RaycastFilterType.Include
		LiveParams.FilterDescendantsInstances = {Live}
	end
	local function AtTarget()
		if not LiveParams then return false end
		local Hit = workspace:Raycast(Part.Position, Dir * StopAt, LiveParams)
		return Hit ~= nil and not Hit.Instance:IsDescendantOf(Character)
	end
	local Conn
	Conn = RunService.Heartbeat:Connect(function()
		local T = os.clock() - Start
		if T >= Info.D or not Velocity.Parent or workspace:Raycast(Part.Position, Dir * 3, Params) or AtTarget() then
			Conn:Disconnect()
			if Velocity.Parent then Velocity:Destroy() end
			return
		end
		Velocity.VectorVelocity = Dir * Info.Speed * math.cos((T / Info.D) * math.pi / 2)
	end)
end

-- Hover: bleed off momentum smoothly through an aerial's windup instead of freezing mid-air.
-- Info: {D}
function MoverManager.Hover(Character, Info)
	local Part = Character:FindFirstChild("HumanoidRootPart")
	if not Part then return end
	local Initial = Part.AssemblyLinearVelocity
	local Velocity = MoverManager.Velocity(Character, {V = Initial, D = Info.D + 0.05, Max = Vector3.new(4e4, 4e4, 4e4), Clear = true})
	local Start = os.clock()
	local Conn
	Conn = RunService.Heartbeat:Connect(function()
		local T = os.clock() - Start
		if T >= Info.D or not Velocity.Parent then
			Conn:Disconnect()
			return
		end
		-- ease (smoothstep) from the current velocity to a near-still float: vertical fall eases to
		-- ~0, horizontal eases down to Info.Carry of what you had -- no frame-one snap
		local A = math.min(1, T / Info.D)
		local E = A * A * (3 - 2 * A)
		local Carry = Info.Carry or 0.75
		local H = 1 - (1 - Carry) * E
		Velocity.VectorVelocity = Vector3.new(Initial.X * H, Initial.Y * (1 - E) + 1.5 * E, Initial.Z * H)
	end)
end

-- Dive: forward-and-down slam that ramps in and ends the moment you land.
-- Info: {Forward, Down, D}
function MoverManager.Dive(Character, Info)
	local Part = Character:FindFirstChild("HumanoidRootPart")
	if not Part then return end
	-- Dive the way you are travelling (falls back to facing), at least Info.Forward fast.
	local V0 = Part.AssemblyLinearVelocity
	local Moving = Vector3.new(V0.X, 0, V0.Z)
	local Look = Part.CFrame.LookVector
	local Flat = Moving.Magnitude > 6 and Moving.Unit or Vector3.new(Look.X, 0, Look.Z)
	Flat = Flat.Magnitude > 0 and Flat.Unit or Vector3.zero
	local Forward = math.max(Info.Forward, Moving.Magnitude)
	local Velocity = MoverManager.Velocity(Character, {V = Flat * Forward, D = Info.D + 0.1, Max = Vector3.new(4e4, 4e4, 4e4), Clear = true})
	local Start = os.clock()
	local Conn
	Conn = RunService.Heartbeat:Connect(function()
		local T = os.clock() - Start
		if T >= Info.D or not Velocity.Parent or Grounded(Character, Part) then
			Conn:Disconnect()
			if Velocity.Parent then Velocity:Destroy() end
			-- land cleanly: keep a little forward carry, kill the downward slam
			local V = Part.AssemblyLinearVelocity
			Part.AssemblyLinearVelocity = Vector3.new(V.X * 0.25, math.max(V.Y, -10), V.Z * 0.25)
			return
		end
		local R = math.min(1, T / (Info.Ramp or 0.12))
		local Ramp = R * R * (3 - 2 * R) -- smoothstep into the slam
		Velocity.VectorVelocity = Flat * Forward * (1 - 0.4 * T / Info.D) + Vector3.new(0, -Info.Down * Ramp, 0)
	end)
end

-- AirStrike: rides the current jump arc during a jump attack. Keeps the vertical motion going
-- under softer gravity (no stall), pushes forward along your travel, ends when you land.
-- Info: {Forward, D, Gravity, MaxFall}
function MoverManager.AirStrike(Character, Info)
	local Part = Character:FindFirstChild("HumanoidRootPart")
	if not Part then return end
	local V0 = Part.AssemblyLinearVelocity
	local Horizontal = Vector3.new(V0.X, 0, V0.Z)
	local Look = Part.CFrame.LookVector
	local Dir = Horizontal.Magnitude > 6 and Horizontal.Unit or Vector3.new(Look.X, 0, Look.Z).Unit
	local Speed = math.max(Info.Forward, Horizontal.Magnitude)
	local Velocity = MoverManager.Velocity(Character, {V = V0, D = Info.D + 0.05, Max = Vector3.new(4e4, 4e4, 4e4), Clear = true})
	local Start = os.clock()
	local Conn
	Conn = RunService.Heartbeat:Connect(function()
		local T = os.clock() - Start
		if T >= Info.D or not Velocity.Parent or (T > 0.05 and Grounded(Character, Part)) then
			Conn:Disconnect()
			if Velocity.Parent then Velocity:Destroy() end
			return
		end
		local VY = math.max(-Info.MaxFall, V0.Y - Info.Gravity * T)
		Velocity.VectorVelocity = Dir * Speed * (1 - 0.35 * T / Info.D) + Vector3.new(0, VY, 0)
	end)
end

function MoverManager.ClearMovers(Character)
	for I,Mover in pairs(Character.HumanoidRootPart.VelocityAttachment:GetChildren()) do
		if Mover:IsA("AlignPosition") or Mover:IsA("AlignOrientation") or Mover:IsA("LinearVelocity") then
			Mover:Destroy()
		end
	end
end

function MoverManager.Initiate()
	local Player = Players.LocalPlayer
	
	local function MoverInvoke(Type,Info)
		MoverManager[Type](Player.Character,Info)
	end

	MoverRemote.OnClientEvent:Connect(MoverInvoke)
end

function MoverManager.CreateMover(Character,Type,Info:{V:'Velocity/Target (Vector3)',D:'DUration'})
	local Player = Players:GetPlayerFromCharacter(Character)
	if Player then
		MoverRemote:FireClient(Player,Type,Info)
	else
		MoverManager[Type](Character,Info)
	end
end

return MoverManager


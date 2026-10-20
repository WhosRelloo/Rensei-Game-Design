local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local SkillData = require(ReplicatedStorage.Modules.Data.SkillData)

local IsClient = RunService:IsClient()
local DamageManager = not IsClient and require(ReplicatedStorage.Modules.Managers.DamageManager) or nil
local HitboxRemote = script.HitboxRemote

local HitboxManager = {}

-- Training/progression hook. Resolved lazily and only on the server.
local ProgressionService = nil
local function RecordHit(Character, Victim, Result)
	if IsClient or not Result then return end
	if not ProgressionService then
		local Module = game:GetService("ServerScriptService"):FindFirstChild("ProgressionService")
		if not Module then return end
		ProgressionService = require(Module)
	end
	ProgressionService.RecordHit(Character, Victim, Result)
end

-- Players must be in Combat Mode (toggled with E) for their attacks to land. NPCs are unaffected.
local function CanAttack(Character)
	local Player = Players:GetPlayerFromCharacter(Character)
	return not Player or Character:GetAttribute("CombatMode") == true
end

local function HitboxCFrame(Character, SkillInfo, Pos)
	local Size = SkillInfo.HitboxSize
	local Root = Character.HumanoidRootPart
	local Offset = SkillInfo.Offset
	return Pos or Offset and Root.CFrame * CFrame.new(Offset.X,Offset.Y,Offset.Z)
		or SkillInfo.Reach and Root.CFrame * CFrame.new(0,0,-SkillInfo.Reach)
		or Root.CFrame * CFrame.new(0,0,(-Size.Z)/2)
end

-- The client runs the hitbox for responsiveness, but the server only accepts victims that
-- could plausibly be inside it. Previously the client's list was applied unchecked, so a
-- modified client could hit anyone in the server.
local HIT_TOLERANCE = 10 -- studs of latency allowance beyond the hitbox's own reach
local MAX_VICTIMS = 12

local function ValidVictims(Character, SkillInfo, Pos, Reported)
	local Accepted = {}
	if type(Reported) ~= "table" then return Accepted end
	local Root = Character:FindFirstChild("HumanoidRootPart")
	if not Root then return Accepted end
	local Center = HitboxCFrame(Character, SkillInfo, Pos).Position
	local Reach = SkillInfo.HitboxSize.Magnitude / 2 + HIT_TOLERANCE
	for Index, Victim in ipairs(Reported) do
		if Index > MAX_VICTIMS then break end
		if typeof(Victim) ~= "Instance" or not Victim:IsA("Model") or Victim == Character then continue end
		if not Victim:IsDescendantOf(workspace.World.Live) or table.find(Accepted, Victim) then continue end
		local Humanoid = Victim:FindFirstChildOfClass("Humanoid")
		local VictimRoot = Victim:FindFirstChild("HumanoidRootPart")
		if not Humanoid or Humanoid.Health <= 0 or not VictimRoot then continue end
		if (VictimRoot.Position - Center).Magnitude > Reach then continue end
		table.insert(Accepted, Victim)
	end
	return Accepted
end

-- A client that never answers would otherwise park the attacking skill's thread forever.
local INVOKE_TIMEOUT = 0.75
local function InvokeWithTimeout(Player, ...)
	local Args = table.pack(...)
	local Done, Result = false, nil
	task.spawn(function()
		local Ok, Value = pcall(HitboxRemote.InvokeClient, HitboxRemote, Player, table.unpack(Args, 1, Args.n))
		if Ok then Result = Value end
		Done = true
	end)
	local Start = os.clock()
	while not Done and os.clock() - Start < INVOKE_TIMEOUT do
		task.wait()
	end
	return Result
end

function HitboxManager.Initiate()
	local Player = Players.LocalPlayer
	
	local function HitboxInvoke(SkillName,Pos,Visualise)
		local SkillInfo = SkillData[SkillName]
		if not SkillInfo then return end
		local Victims = HitboxManager.CreateHitbox(Player.Character,SkillInfo,Pos,Visualise)
		return Victims
	end

	HitboxRemote.OnClientInvoke = HitboxInvoke
end

function HitboxManager.CreateHitbox(Character,SkillInfo,Pos,Visualise) 
	local Include = SkillInfo.Include 
	local Size = SkillInfo.HitboxSize
	local Root = Character.HumanoidRootPart
	local Offset = SkillInfo.Offset
	local cframe = Pos or Offset and Root.CFrame * CFrame.new(Offset.X,Offset.Y,Offset.Z)
		or SkillInfo.Reach and Root.CFrame * CFrame.new(0,0,-SkillInfo.Reach)
		or Root.CFrame * CFrame.new(0,0,(-Size.Z)/2)
	local Params = OverlapParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = Include or {workspace.World.Live}

	if Visualise then
		local Visualised = Instance.new("Part")
		Visualised.Anchored = true
		Visualised.CanCollide = false
		Visualised.CanQuery = false
		Visualised.CanTouch = false
		Visualised.Transparency = 0.5
		Visualised.Color = Color3.fromRGB(255,0,0)
		Visualised.Size = Size
		Visualised.CFrame = cframe
		Visualised.Parent = workspace.World.Visuals
		Debris:AddItem(Visualised,0.5)
	end
	
	local HitParts = workspace:GetPartBoundsInBox(cframe,Size,Params)
	local HitEnemies = {}
	for I,Part in ipairs(HitParts) do
		if Part:IsDescendantOf(workspace.World.Live) then
			local EHumanoid = Part.Parent:FindFirstChildOfClass("Humanoid") or Part.Parent.Parent:FindFirstChildOfClass("Humanoid")
			if Part:IsDescendantOf(Character) or not Part.Parent:IsA("Model") or table.find(HitEnemies,EHumanoid.Parent) then continue end
			if not EHumanoid or EHumanoid.Health <= 0 then 
				continue
			else
				table.insert(HitEnemies,EHumanoid.Parent)
			end
		else
			table.insert(HitEnemies,Part)
		end
	end

	return HitEnemies
end

function HitboxManager.Hitbox(Character,SkillName,Pos:CFrame,Visualise:boolean,ServerSide: boolean) -- make use skill info
	local SkillInfo = SkillData[SkillName]
	if not SkillInfo or not CanAttack(Character) then return end
	local Player = Players:GetPlayerFromCharacter(Character)
	local Victims
	if ServerSide or not Player then
		Victims = HitboxManager.CreateHitbox(Character,SkillInfo,Pos,Visualise)
	else
		Victims = ValidVictims(Character, SkillInfo, Pos, InvokeWithTimeout(Player, SkillName, Pos, Visualise))
	end

	local Landed = 0
	for _,Victim in pairs(Victims) do
		if typeof(Victim) == "Instance" and Victim:IsA("Model") and Victim:FindFirstChildOfClass("Humanoid") then
			Landed += 1
			RecordHit(Character, Victim, DamageManager(Character,Victim,SkillInfo))
		end
	end

	return Landed >= 1
end

-- Server-authoritative active-frame hitbox: the box is re-sampled every server frame for the
-- attack's whole active window (so fast movement cannot skip it), and each victim is hit once.
-- Returns the list of {Victim, Result} pairs.
function HitboxManager.Sweep(Character, SkillName, Duration)
	local SkillInfo = SkillData[SkillName]
	local Results = {}
	if IsClient or not SkillInfo or not CanAttack(Character) then return Results end
	-- breakable boards (PuzzleService.Strike, 2026-10-20): a player's strike counts as a hit on them. Optional (the
	-- Tutorial has no PuzzleService) and guarded: it never changes the attack.
	pcall(function()
		local P = Players:GetPlayerFromCharacter(Character)
		local M = P and game:GetService("ServerScriptService"):FindFirstChild("PuzzleService")
		if M then require(M).Strike(P, HitboxCFrame(Character, SkillInfo).Position, tostring(SkillName):match("Heavy$") ~= nil) end
	end)
	local Seen = {}
	local Start = os.clock()
	repeat
		local Root = Character:FindFirstChild("HumanoidRootPart")
		if not Root then break end
		for _, Victim in ipairs(HitboxManager.CreateHitbox(Character, SkillInfo)) do
			if not Seen[Victim] and typeof(Victim) == "Instance" and Victim:IsA("Model") and Victim:FindFirstChildOfClass("Humanoid") then
				Seen[Victim] = true
				local Result = DamageManager(Character, Victim, SkillInfo)
				RecordHit(Character, Victim, Result)
				table.insert(Results, {Victim = Victim, Result = Result})
			end
		end
		if os.clock() - Start >= (Duration or 0) then break end
		RunService.Heartbeat:Wait()
	until false
	return Results
end

function HitboxManager.Radius(Character,Radius,SkillInfo,Pos,Visualise) -- make use skill info
	if not IsClient and not CanAttack(Character) then return false end
	local Root = Character.HumanoidRootPart
	local cframe = Pos or Root.CFrame
	local Params = OverlapParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = {workspace.World.Live}

	local HitParts = workspace:GetPartBoundsInRadius(cframe.Position,Radius,Params)
	local HitEnemies = {}
	for I,Part in ipairs(HitParts) do
		if Part:IsDescendantOf(Character) or not Part.Parent:IsA("Model") or table.find(HitEnemies,Part.Parent) then continue end
		local EHumanoid = Part.Parent:FindFirstChildOfClass("Humanoid")
		if not EHumanoid or EHumanoid.Health <= 0 then 
			continue
		else
			table.insert(HitEnemies,Part.Parent)
			RecordHit(Character, Part.Parent, DamageManager(Character,Part.Parent,SkillInfo))
		end
	end
	
	return #HitEnemies >= 1
end

function HitboxManager.Closest(Character,Pos,Range)
	local Root = Character.HumanoidRootPart
	local Best = nil
	local Distance = 30
	for I,Target in ipairs(workspace.Logic.Live:GetChildren()) do
		if Target == Character or not Target:IsA("Model") or not Target:FindFirstChild("Humanoid") or Target.Humanoid.Health <= 0 then continue end
		local TRoot = Target.HumanoidRootPart
		local Magnitude = (Pos - TRoot.Position).Magnitude
		if Magnitude < Distance or not TRoot or not Target then Best = Target  Distance = Magnitude end
	end

	if Distance <= Range then
		return Best
	end
end

function HitboxManager.Projectile(Character, params)
	-- Default parameters
	local defaultParams = {
		Pos = Character.HumanoidRootPart.Position,
		TargetPos = nil, -- Required
		Distance = 50,
		Size = Vector3.new(4, 4, 4),
		LifeTime = 1,
		SkillInfo = nil,
		Penetrate = false,
		Visualise = false,
		Gravity = 0, -- 0 means no gravity
		Include = {workspace.World.Live, workspace.World.Map},
	}

	-- Merge provided params with defaults
	params = params or {}
	for key, value in pairs(defaultParams) do
		if params[key] == nil then
			params[key] = value
		end
	end

	-- Validate required parameters
	if not params.TargetPos then
		warn("Projectile: TargetPos is required")
		return
	end
	if not CanAttack(Character) then return end

	-- Calculate initial direction (flat, no upward angle)
	local Direction = (params.TargetPos - params.Pos).Unit
	local initialSpeed = params.Distance / params.LifeTime

	local SizeInterval = params.Size.Z
	local Iterations = math.ceil(params.Distance / SizeInterval)
	local Interval = params.LifeTime / Iterations

	local HitEnemies = {}
	local startTime = os.clock()

	for i = 1, Iterations do
		local elapsedTime = (i - 1) * Interval
		local currentPos

		-- Horizontal movement (constant velocity)
		local horizontalMovement = Direction * (initialSpeed * elapsedTime)

		-- Vertical movement (affected by gravity)
		local verticalDisplacement = 0
		if params.Gravity > 0 then
			verticalDisplacement = -0.5 * params.Gravity * (elapsedTime ^ 2)  -- Negative for downward pull
		end

		currentPos = params.Pos + horizontalMovement + Vector3.new(0, verticalDisplacement, 0)

		local projectileCFrame = CFrame.new(currentPos, currentPos + Direction)

		local Victims = HitboxManager.CreateHitbox(
			Character, 
			{HitboxSize = params.Size, Include = params.Include}, 
			projectileCFrame * CFrame.new(0, 0, -SizeInterval/2), 
			params.Visualise
		)

		for _, Victim in pairs(Victims) do
			if not table.find(HitEnemies, Victim) then
				table.insert(HitEnemies, Victim)

				if Victim:IsDescendantOf(workspace.World.Live) then
					RecordHit(Character, Victim, DamageManager(Character, Victim, params.SkillInfo))
				end

				if not params.Penetrate then 
					return Victim,currentPos
				end
			end
		end

		task.wait(Interval)
	end
end

if IsClient then
	function HitboxManager.CastProjectile(Character, params)
		-- Default parameters
		local defaultParams = {
			Pos = Character.HumanoidRootPart.Position,
			TargetPos = nil, -- Required
			Distance = 50,
			Size = Vector3.new(4, 4, 4),
			LifeTime = 1,
			Visualise = false,
			Gravity = 0, -- 0 means no gravity
			Include = {workspace.World.Live, workspace.World.Map},
			ProjectileModel = nil, -- The visual projectile to move
			OnHit = function(hit, position) end, -- Callback when hitting something
			OnUpdate = function(position, deltaTime) end, -- Callback each frame update
			OnFinished = function() end, -- Callback when projectile finishes
			Penetrate = false,
		}

		-- Merge provided params with defaults
		params = params or {}
		for key, value in pairs(defaultParams) do
			if params[key] == nil then
				params[key] = value
			end
		end

		-- Validate required parameters
		if not params.TargetPos then
			warn("ClientProjectile: TargetPos is required")
			return
		end

		-- Calculate initial direction (flat, no upward angle)
		local Direction = (params.TargetPos - params.Pos).Unit
		local initialSpeed = params.Distance / params.LifeTime

		local SizeInterval = params.Size.Z
		local Iterations = math.ceil(params.Distance / SizeInterval)
		local Interval = params.LifeTime / Iterations

		local HitEnemies = {}
		local hasHit = false

		-- If we have a projectile model, position it initially
		if params.ProjectileModel then
			params.ProjectileModel:PivotTo(CFrame.new(params.Pos, params.Pos + Direction))
		end

		-- Use a coroutine to match the server's discrete step approach
		local coroutineRef = coroutine.create(function()
			for i = 1, Iterations do
				local elapsedTime = (i - 1) * Interval

				-- Horizontal movement (constant velocity)
				local horizontalMovement = Direction * (initialSpeed * elapsedTime)

				-- Vertical movement (affected by gravity)
				local verticalDisplacement = 0
				if params.Gravity > 0 then
					verticalDisplacement = -0.5 * params.Gravity * (elapsedTime ^ 2)
				end

				local currentPos = params.Pos + horizontalMovement + Vector3.new(0, verticalDisplacement, 0)
				local projectileCFrame = CFrame.new(currentPos, currentPos + Direction)

				-- Update projectile model if it exists
				if params.ProjectileModel then
					params.ProjectileModel:PivotTo(projectileCFrame)
				end

				-- Call update callback
				params.OnUpdate(currentPos, Interval)

				-- Check for hits
				local Victims = HitboxManager.CreateHitbox(
					Character, 
					{HitboxSize = params.Size, Include = params.Include}, 
					projectileCFrame * CFrame.new(0, 0, -SizeInterval/2), 
					params.Visualise
				)

				-- Process hits
				for _, Victim in pairs(Victims) do
					if not table.find(HitEnemies, Victim) then
						table.insert(HitEnemies, Victim)
						hasHit = true
						-- Call hit callback
						params.OnHit(Victim, currentPos, Direction)

						if not params.Penetrate then 
							params.OnFinished()
							return
						end
					end
				end

				-- Wait for next interval
				task.wait(Interval)
			end

			-- Complete if we haven't hit anything
			if not hasHit then
				params.OnFinished()
			end
		end)

		-- Start the coroutine
		coroutine.resume(coroutineRef)

		-- Return a function to cancel the projectile early
		return function()
			if coroutineRef and coroutine.status(coroutineRef) ~= "dead" then
				coroutine.close(coroutineRef)
			end
			params.OnFinished()
		end
	end
end

return HitboxManager

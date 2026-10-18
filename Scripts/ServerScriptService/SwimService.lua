-- SwimService: basic swimming (owner decision 6, 2026-10-18: "allow deep water with a swim state (no combat or
-- alchemy while swimming)").
-- Roblox's own terrain-water swimming moves the character. This service owns the GAME state: every
-- TuningConfig.Swim.CheckEvery seconds it looks at each player character and, in deep water, puts it in the
-- server's Traversal = "Swim" state (MovementState.SetSwim). That state carries the Climbing status, which every
-- attack, block, alchemy cast, class / weapon skill, shot, sprint, roll and crouch already refuses. Entering the
-- water also turns Combat Mode off (the weapon goes away), and Requests.CombatMode refuses to turn it back on.
-- Deep water = the Humanoid is in Roblox's Swimming state, or a terrain-water cell at least WaterOccupancy full is
-- at the root or Below studs under it. The wadeable creek (about 1.2 deep) never counts. The state ends after
-- ExitChecks dry checks in a row. Animations: StarterPlayerScripts.SwimClient. Numbers: TuningConfig.Swim.
-- ENEMIES (owner 2026-10-18: "enemies in deep water should also be unable to attack or cast, same as players"):
-- every live EnemyService rig gets the same Swim state + Climbing status (CastAs refuses), and EnemyService's brain
-- doesn't attack, cast, guard-cast, block or parry while its rig is swimming. An enemy keeps its weapon drawn
-- (its CombatMode attribute means "armed" to the brain) but can't use it.
-- EXTRAS (owner 2026-10-18, "add swimming extras"; players only):
--   * swim sprint: attribute SwimSprint (Requests.Swim); stamina drains SprintStamina/s, cleared when it runs
--     out or the swim ends.
--   * breath: attribute Breath (seconds, max BreathMax). It drains while the head is under the water's surface
--     (diving: Roblox swims along the camera, so look down and swim) and refills above it. At 0, attribute
--     Drowning is set and DownedManager.Damage deals DrownFraction of max health (at least DrownDamage) every
--     DrownTick (the normal damage path: at
--     0 HP you're knocked out, not killed; a knocked body floats back up).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MovementState = require(ReplicatedStorage.Modules.Managers.MovementState)
local ResourceManager = require(ReplicatedStorage.Modules.Managers.ResourceManager)
local DownedManager = require(ReplicatedStorage.Modules.Managers.DownedManager)
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig).Swim

local SwimService = {}

local Dry = {} -- [Character] = consecutive checks out of deep water (plain table; cleaned when the character goes)
local DrownAt = {} -- [Character] = os.clock() of the next drowning tick

-- the 4-stud terrain cell holding Position: deep water?
local function DeepWaterAt(Position)
	local Corner = Vector3.new(math.floor(Position.X / 4) * 4, math.floor(Position.Y / 4) * 4, math.floor(Position.Z / 4) * 4)
	local Ok, Materials, Occupancy = pcall(function()
		return workspace.Terrain:ReadVoxels(Region3.new(Corner, Corner + Vector3.new(4, 4, 4)), 4)
	end)
	if not Ok then return false end
	return Materials[1][1][1] == Enum.Material.Water and Occupancy[1][1][1] >= Tuning.WaterOccupancy
end

-- the head under the water's surface? (shorelines: a cell's LiquidOccupancy fills it from the bottom, so the
-- surface in a part-filled cell is its bottom + occupancy * 4)
function SwimService.HeadUnderwater(Character)
	local Head = Character:FindFirstChild("Head")
	if not Head then return false end
	local P = Head.Position + Vector3.new(0, Tuning.HeadAbove, 0)
	local Corner = Vector3.new(math.floor(P.X / 4) * 4, math.floor(P.Y / 4) * 4, math.floor(P.Z / 4) * 4)
	local Ok, Ch = pcall(function()
		return workspace.Terrain:ReadVoxelChannels(Region3.new(Corner, Corner + Vector3.new(4, 4, 4)), 4, {"LiquidOccupancy"})
	end)
	if not Ok then return false end
	local Liquid = Ch.LiquidOccupancy[1][1][1]
	return Liquid > 0 and P.Y < Corner.Y + Liquid * 4
end

function SwimService.InDeepWater(Character)
	local Root = Character:FindFirstChild("HumanoidRootPart")
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Root or not Humanoid or Humanoid.Health <= 0 then return false end
	-- (a client faking the Swimming state only locks itself out of fighting)
	if Humanoid:GetState() == Enum.HumanoidStateType.Swimming then return true end
	return DeepWaterAt(Root.Position) or DeepWaterAt(Root.Position - Vector3.new(0, Tuning.Below, 0))
end

-- Player: the player (Combat Mode goes off on entering), or nil for an enemy rig
local function Step(Character, Player)
	if not Character or not Character.Parent then return end
	local Kind = MovementState.Get(Character)
	if SwimService.InDeepWater(Character) then
		Dry[Character] = 0
		if Kind == nil and MovementState.SetSwim(Character, true) then
			-- into the water: a player's weapon goes away
			if Player and Character:GetAttribute("CombatMode") then
				local CombatMode = require(ServerScriptService.ServerHandler.Requests.CombatMode)
				pcall(CombatMode, Player, false)
			end
		end
	elseif Kind == "Swim" then
		Dry[Character] = (Dry[Character] or 0) + 1
		if Dry[Character] >= Tuning.ExitChecks then
			Dry[Character] = nil
			MovementState.SetSwim(Character, false)
		end
	end
	if not Player then return end
	local Swimming = MovementState.Get(Character) == "Swim"

	-- swim sprint: stamina while it's on; off when it runs out or the swim ends
	if Character:GetAttribute("SwimSprint") then
		if not Swimming or not ResourceManager.Spend(Character, "Stamina", Tuning.SprintStamina * Tuning.CheckEvery) then
			Character:SetAttribute("SwimSprint", nil)
		end
	end

	-- breath
	local Breath = Character:GetAttribute("Breath") or Tuning.BreathMax
	local Under = Swimming and SwimService.HeadUnderwater(Character)
	if Under then
		Breath = math.max(0, Breath - Tuning.CheckEvery)
	else
		Breath = math.min(Tuning.BreathMax, Breath + Tuning.BreathRefill * Tuning.CheckEvery)
	end
	if Breath ~= Character:GetAttribute("Breath") then Character:SetAttribute("Breath", Breath < Tuning.BreathMax and Breath or nil) end
	local Drowning = Under and Breath <= 0
	if Drowning ~= (Character:GetAttribute("Drowning") == true) then Character:SetAttribute("Drowning", Drowning or nil) end
	if Drowning then
		if os.clock() >= (DrownAt[Character] or 0) then
			DrownAt[Character] = os.clock() + Tuning.DrownTick
			local Humanoid = Character:FindFirstChildOfClass("Humanoid")
			local Amount = math.max(Tuning.DrownDamage, (Humanoid and Humanoid.MaxHealth or 0) * (Tuning.DrownFraction or 0))
			DownedManager.Damage(Character, Amount)
		end
	else
		DrownAt[Character] = nil
	end
end

function SwimService.Start()
	local function Forget(Character) Dry[Character] = nil DrownAt[Character] = nil end
	Players.PlayerAdded:Connect(function(Player) Player.CharacterRemoving:Connect(Forget) end)
	for _, Player in ipairs(Players:GetPlayers()) do Player.CharacterRemoving:Connect(Forget) end
	task.spawn(function()
		while true do
			task.wait(Tuning.CheckEvery)
			for _, Player in ipairs(Players:GetPlayers()) do
				local Ok, Err = pcall(Step, Player.Character, Player)
				if not Ok then warn("SwimService:", Err) end
			end
			-- enemies (lazy: EnemyService starts after this)
			local EOk, EnemyService = pcall(require, ServerScriptService.EnemyService)
			if EOk and EnemyService.Active then
				for Rig in pairs(EnemyService.Active) do
					local Ok, Err = pcall(Step, Rig, nil)
					if not Ok then warn("SwimService (enemy):", Err) end
				end
			end
		end
	end)
end

return SwimService

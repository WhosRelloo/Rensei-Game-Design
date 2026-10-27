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
-- SWIMMING REVAMP (2026-10-26; Documents/specs/2026-10-25-swimming-revamp-design.md, all PROPOSAL): the movement is now
-- the client's swim controller (Modules.Managers.SwimController: level at the surface, camera-relative in 3D after a
-- dive, rise / sink with Space / Ctrl). The server still owns every rule, and adds:
--   * Submerged (attribute): set while the head is under the water; cleared after SubmergedExitChecks checks out.
--     Stealth reads it (PerceptionService).
--   * breath counts whenever the head is under water, IN THE SWIM STATE OR NOT (a carrier can't walk a pond's bed
--     forever any more); knocked characters are left out. Underwater sprinting uses air UnderSprintBreathMult faster.
--   * WaterDepthAt(Position): the water column from the surface to the bed (tests, and a later dive check).
--   * a swim speed check: a swimmer that moves further per check than SwimLogic.MaxSpeed allows (with slack) gets a
--     strike (attribute SwimSpeedStrikes); SpeedStrikes in a row clear SwimSprint and log a warning. It never moves
--     anyone. Skipped while stunned or dashing, for 1 s after a health drop (a hit's knockback is made on the
--     client, where the server can't see it) and when the last sample is over 1 s old.
--   Step(Character, Breather) is public (Play_Swim drives it): Breather = the Player (Combat Mode goes off on
--   entering the water), true (a test rig: every rule but Combat Mode), or nil (an enemy rig: the state only).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MovementState = require(ReplicatedStorage.Modules.Managers.MovementState)
local ResourceManager = require(ReplicatedStorage.Modules.Managers.ResourceManager)
local DownedManager = require(ReplicatedStorage.Modules.Managers.DownedManager)
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig).Swim
local SwimLogic = require(ReplicatedStorage.Modules.Data.Rensei.SwimLogic)
local StarterPlayer = game:GetService("StarterPlayer")
local BaseWalk = (function() -- the base walk speed the speed check scales (StarterCharacter's, 16 in both places)
	local SC = StarterPlayer:FindFirstChild("StarterCharacter")
	local H = SC and SC:FindFirstChildOfClass("Humanoid")
	return H and H.WalkSpeed or 16
end)()

local SwimService = {}

local Dry = {} -- [Character] = consecutive checks out of deep water (plain table; cleaned when the character goes)
local DrownAt = {} -- [Character] = os.clock() of the next drowning tick
local OutChecks = {} -- [Character] = checks in a row with the head out (Submerged clears at SubmergedExitChecks)
local Last = {} -- [Character] = {Pos, Time}: the speed check's previous sample
local HealthWas = {} -- [Character] = Humanoid.Health at the last check
local HurtAt = {} -- [Character] = os.clock() of the last health drop

local function Stunned(Character)
	local Ok, Yes = pcall(function()
		local WCS = require(ReplicatedStorage.Modules.Framework.WCS)
		local Stun = require(ReplicatedStorage.Modules.Skills.States.Stun)
		local CS = WCS.Character.GetCharacterFromInstance(Character)
		return CS ~= nil and CS:HasStatusEffects({Stun})
	end)
	return Ok and Yes == true
end

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
	-- (the cell above too: swimming revamp 2026-10-26. Near a pond's bed a cell can be part bed, part water ABOVE it;
	-- the bottom-fill rule then put the "surface" below a diver's head 8 studs down. Water filling the cell above
	-- means the head is under, whatever this cell holds.)
	local Ok, Ch = pcall(function()
		return workspace.Terrain:ReadVoxelChannels(Region3.new(Corner, Corner + Vector3.new(4, 8, 4)), 4, {"LiquidOccupancy"})
	end)
	if not Ok then return false end
	local Liquid = Ch.LiquidOccupancy[1][1][1]
	local Above = Ch.LiquidOccupancy[1][2] and Ch.LiquidOccupancy[1][2][1] or 0
	if Liquid > 0 and Above >= Tuning.WaterOccupancy then return true end
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

-- the water at Position: (depth, surface Y), or (0, nil) where there is none. The surface is the first terrain hit
-- of a ray down from 20 studs above, when it is Water; the bed is a ray from there down 40 studs that ignores water
-- (the map and the terrain only).
local SurfaceRay = RaycastParams.new()
SurfaceRay.FilterType = Enum.RaycastFilterType.Include
SurfaceRay.IgnoreWater = false
local BedRay = RaycastParams.new()
BedRay.FilterType = Enum.RaycastFilterType.Include
BedRay.IgnoreWater = true
function SwimService.WaterDepthAt(Position)
	SurfaceRay.FilterDescendantsInstances = {workspace.Terrain}
	local Top = workspace:Raycast(Position + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), SurfaceRay)
	if not Top or Top.Material ~= Enum.Material.Water then return 0, nil end
	local World = workspace:FindFirstChild("World")
	local Map = World and World:FindFirstChild("Map")
	BedRay.FilterDescendantsInstances = Map and {Map, workspace.Terrain} or {workspace.Terrain}
	local Bed = workspace:Raycast(Top.Position, Vector3.new(0, -40, 0), BedRay)
	if not Bed then return 40, Top.Position.Y end
	return Top.Position.Y - Bed.Position.Y, Top.Position.Y
end

-- the swim speed check (one sample per check while swimming)
local function SpeedCheck(Character, Swimming)
	local Root = Character:FindFirstChild("HumanoidRootPart")
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Root or not Humanoid then return end
	local Now = os.clock()
	if HealthWas[Character] and Humanoid.Health < HealthWas[Character] then HurtAt[Character] = Now end
	HealthWas[Character] = Humanoid.Health
	local Prev = Last[Character]
	Last[Character] = Swimming and {Pos = Root.Position, Time = Now} or nil
	local Skip = not Swimming or not Prev or Now - Prev.Time > 1 or Character:GetAttribute("Dashing")
		or (HurtAt[Character] and Now - HurtAt[Character] < 1) or Stunned(Character)
	if Skip then
		if Character:GetAttribute("SwimSpeedStrikes") then Character:SetAttribute("SwimSpeedStrikes", nil) end
		return
	end
	local Moved = (Root.Position - Prev.Pos).Magnitude
	local Dt = Now - Prev.Time
	local Max = SwimLogic.MaxSpeed(BaseWalk, Character:GetAttribute("SpeedMultiplier") or 1,
		Character:GetAttribute("SwimSprint") == true, Tuning)
	local Strikes = SwimLogic.SpeedStrike(Character:GetAttribute("SwimSpeedStrikes") or 0, Moved, Dt, Max, Tuning)
	if Strikes >= Tuning.SpeedStrikes then
		Character:SetAttribute("SwimSprint", nil)
		local P = Players:GetPlayerFromCharacter(Character)
		warn("SwimService: speed", P and P.Name or Character.Name, string.format("%.1f", Moved), string.format("%.2f", Dt),
			string.format("%.1f", Max))
		Strikes = 0
	end
	Character:SetAttribute("SwimSpeedStrikes", Strikes > 0 and Strikes or nil)
end

-- Breather: the Player (Combat Mode goes off on entering), true (a test rig), or nil for an enemy rig
function SwimService.Step(Character, Breather)
	if not Character or not Character.Parent then return end
	local Player = typeof(Breather) == "Instance" and Breather or nil
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
	if not Breather then return end
	local Swimming = MovementState.Get(Character) == "Swim"

	-- swim sprint: stamina while it's on; off when it runs out or the swim ends
	if Character:GetAttribute("SwimSprint") then
		if not Swimming or not ResourceManager.Spend(Character, "Stamina", Tuning.SprintStamina * Tuning.CheckEvery) then
			Character:SetAttribute("SwimSprint", nil)
		end
	end

	-- the head under water: Submerged, and breath (in the Swim state or not; knocked bodies are left out)
	local HeadUnder = SwimService.HeadUnderwater(Character)
	if HeadUnder then
		OutChecks[Character] = 0
		if not Character:GetAttribute("Submerged") then Character:SetAttribute("Submerged", true) end
	elseif Character:GetAttribute("Submerged") then
		OutChecks[Character] = (OutChecks[Character] or 0) + 1
		if OutChecks[Character] >= Tuning.SubmergedExitChecks then
			OutChecks[Character] = nil
			Character:SetAttribute("Submerged", nil)
		end
	end
	local Breath = Character:GetAttribute("Breath") or Tuning.BreathMax
	local Under = HeadUnder and not Character:GetAttribute("Knocked")
	Breath = SwimLogic.BreathStep(Breath, Under, Character:GetAttribute("SwimSprint") == true, Tuning.CheckEvery, Tuning)
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

	SpeedCheck(Character, Swimming)
end

-- drop every per-character table entry (a character leaving; Play_Swim's rigs)
function SwimService.Forget(Character)
	Dry[Character] = nil DrownAt[Character] = nil OutChecks[Character] = nil
	Last[Character] = nil HealthWas[Character] = nil HurtAt[Character] = nil
end

function SwimService.Start()
	local Forget = SwimService.Forget
	Players.PlayerAdded:Connect(function(Player) Player.CharacterRemoving:Connect(Forget) end)
	for _, Player in ipairs(Players:GetPlayers()) do Player.CharacterRemoving:Connect(Forget) end
	task.spawn(function()
		while true do
			task.wait(Tuning.CheckEvery)
			for _, Player in ipairs(Players:GetPlayers()) do
				local Ok, Err = pcall(SwimService.Step, Player.Character, Player)
				if not Ok then warn("SwimService:", Err) end
			end
			-- enemies (lazy: EnemyService starts after this)
			local EOk, EnemyService = pcall(require, ServerScriptService.EnemyService)
			if EOk and EnemyService.Active then
				for Rig in pairs(EnemyService.Active) do
					local Ok, Err = pcall(SwimService.Step, Rig, nil)
					if not Ok then warn("SwimService (enemy):", Err) end
				end
			end
		end
	end)
end

return SwimService

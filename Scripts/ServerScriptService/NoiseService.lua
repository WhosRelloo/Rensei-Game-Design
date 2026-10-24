-- NoiseService (2026-10-20, Morality × Reputation spec §17.3; Plan 2, slice S2): sounds as events with a radius.
-- Emit(Position, Kind | Radius, Source) hands a sound to PerceptionService.Hear: NPCs in range, through the
-- walls between (each takes 40% off), go to look at the spot. They learn where, not who. Sounds are events,
-- never scanned (spec §17.10).
-- Sources (radii in Rensei.Perception.Sounds / Steps, all PROPOSAL):
--   * footsteps, from the floor's material: grass / dirt 4, wood 7, metal / gravel 9, other 5; running x2;
--     crouched 0 (here, every StepEvery seconds while moving);
--   * landing from a height (a fall faster than LandSpeed) 12, here; diving into deep water 12, here;
--   * dash / roll 10 (CharacterHandler), melee hit 20 (HitListeners, here), alchemy cast 30 (AlchemyService;
--     Agents hear it x2), gunshot 60 (the Shoot request).
-- A player's own last sound is shown on their eye sigil: character attributes Noise (radius) and NoiseAt.
-- Listen(Fn) (Region Foundation Task 6): Fn(Position, Radius, Kind, Source) runs on every Emit, after the NPCs have
-- heard it, each in a pcall; it returns a function that stops listening. TownsfolkService uses it to flee fights.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local P = require(ReplicatedStorage.Modules.Data.Rensei.Perception)

local NoiseService = {}
NoiseService.StepEvery = 0.45 -- seconds between footstep sounds while moving
NoiseService.MinStepSpeed = 3 -- studs/s: slower than this isn't a step
NoiseService.LandSpeed = 45 -- studs/s downward: a landing loud enough to hear (about a 10+ stud drop)

NoiseService.Log = nil -- tests: set to a table to collect every {Kind, Radius, Position, Heard}

local Listeners = {}
function NoiseService.Listen(Fn)
	assert(type(Fn) == "function", "NoiseService.Listen: Fn must be a function")
	table.insert(Listeners, Fn)
	return function()
		local I = table.find(Listeners, Fn)
		if I then table.remove(Listeners, I) end
	end
end

function NoiseService.Emit(Position, KindOrRadius, Source)
	if typeof(Position) ~= "Vector3" then return 0 end
	local Kind = type(KindOrRadius) == "string" and KindOrRadius or nil
	local Radius = Kind and P.Sounds[Kind] or tonumber(KindOrRadius) or 0
	if Radius <= 0 then return 0 end
	if Source and Players:GetPlayerFromCharacter(Source) then
		Source:SetAttribute("Noise", Radius)
		Source:SetAttribute("NoiseAt", workspace:GetServerTimeNow())
	end
	local Heard = require(ServerScriptService.PerceptionService).Hear(Position, Radius, Kind, Source)
	if NoiseService.Log then table.insert(NoiseService.Log, {Kind = Kind, Radius = Radius, Position = Position, Heard = Heard}) end
	if #Listeners > 0 then
		for _, Fn in ipairs(table.clone(Listeners)) do -- (a copy: a listener may stop listening while it runs)
			local Ok, Err = pcall(Fn, Position, Radius, Kind, Source)
			if not Ok then warn("NoiseService: a listener failed:", Err) end
		end
	end
	return Heard
end

-- one player's movement sounds: steps, landings, splashes
local Track = {} -- [Character] = {Step = seconds since the last step, FallSpeed = fastest fall since grounded, Swim = bool}
local function StepPlayer(Character, Dt)
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	local Root = Character:FindFirstChild("HumanoidRootPart")
	if not Humanoid or not Root or Humanoid.Health <= 0 then return end
	local T = Track[Character] or {Step = 0, FallSpeed = 0, Swim = false}
	Track[Character] = T
	local Feet = Root.Position - Vector3.new(0, 3, 0)
	local V = Root.AssemblyLinearVelocity
	local Floor = Humanoid.FloorMaterial
	local Traversal = nil
	pcall(function() Traversal = require(ReplicatedStorage.Modules.Managers.MovementState).Get(Character) end)
	-- diving into deep water
	local Swim = Traversal == "Swim"
	if Swim and not T.Swim then NoiseService.Emit(Root.Position, "Splash", Character) end
	T.Swim = Swim
	if Floor == Enum.Material.Air then
		T.FallSpeed = math.max(T.FallSpeed, -V.Y)
		return
	end
	-- landing from a height
	if T.FallSpeed >= NoiseService.LandSpeed then NoiseService.Emit(Feet, "Land", Character) end
	T.FallSpeed = 0
	if Swim or Traversal then return end -- climbing, wall-running, swimming: no steps
	local Speed = Vector3.new(V.X, 0, V.Z).Magnitude
	if Speed < NoiseService.MinStepSpeed then T.Step = NoiseService.StepEvery return end -- the next step sounds at once
	T.Step += Dt
	if T.Step < NoiseService.StepEvery then return end
	T.Step = 0
	local Move = P.MoveMult(Speed, Character:GetAttribute("SpeedMultiplier"))
	local Radius = P.StepNoise(Floor.Name, Move, Character:GetAttribute("Crouching"))
	if Radius > 0 then NoiseService.Emit(Feet, Radius, Character) end
end

local Auto = true
function NoiseService.SetAuto(On) Auto = On end
NoiseService.StepPlayer = StepPlayer

function NoiseService.Start()
	local Acc = 0
	RunService.Heartbeat:Connect(function(Dt)
		if not Auto then return end
		Acc += Dt
		if Acc < 0.1 then return end
		local Step = math.min(Acc, 0.5)
		Acc = 0
		for _, Player in ipairs(Players:GetPlayers()) do
			local C = Player.Character
			if C then
				local Ok, Err = pcall(StepPlayer, C, Step)
				if not Ok then warn("NoiseService:", Err) end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(Player) if Player.Character then Track[Player.Character] = nil end end)
	Players.PlayerAdded:Connect(function(Player)
		Player.CharacterRemoving:Connect(function(C) Track[C] = nil end)
	end)
	for _, Player in ipairs(Players:GetPlayers()) do
		Player.CharacterRemoving:Connect(function(C) Track[C] = nil end)
	end
	-- melee (and every other) hit is heard where it lands
	table.insert(require(ServerScriptService.ProgressionService).HitListeners, function(Attacker, Victim)
		local R = Victim and Victim:FindFirstChild("HumanoidRootPart")
		if R then NoiseService.Emit(R.Position, "Hit", Attacker) end
	end)
end

return NoiseService

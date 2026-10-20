-- PuzzleClient: draws THIS player's puzzle states (PuzzleService is per-player). Nothing here
-- decides anything; it only shows what the server sent over Remotes.PuzzleRemote.
-- Conventions on a mechanism (tagged RenseiMechanism, attribute MechanismId):
--   SteamVent: ParticleEmitter "Steam"; Part "Blocker" (collides only while the vent is On)
--   Brazier:   Fire "Fire" and/or PointLight "Glow" (on while Lit)
--   Plate:     sinks and brightens while Held
--   Array:     Decal "Circle" (glows gold once Restored); descendants named Glow* (beams, particles,
--              lights) switch on once Restored
--   Valve:     a Model whose PrimaryPart is the wheel (turns a quarter when shut); Flow* particles and
--              "Stream" parts run while Open (Halvard's Adit sluices, 2026-10-18)
--   Water:     (instance attribute Draw = "Water") a water part that turns to ice while Frozen; Murk
--              particles stop. Draw on an instance overrides its mechanism's Kind.
--   Breakable: (Halvard's Adit boards, 2026-10-20) its parts named *Plank all collide while Whole, so the gap
--              is closed (locally, per player, like the cracked wall). Broken hides them; a LIVE break (a State
--              message) also throws loose plank pieces with physics, a dust burst and the model's BreakSound
--              attribute if it has one. A player who joins already Broken just sees the opening. Each hit before
--              the break ("Cracked") puffs splinters at the nearest plank (+ the CrackSound attribute, if set).
-- Doors: parts tagged RenseiPuzzleDoor with attribute PuzzleId open once that puzzle is solved.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local Content = require(ReplicatedStorage.Modules.Data.Rensei.Puzzles)

local PuzzleClient = {}

local States = {} -- [MechanismId] = state
local Solved = {} -- [PuzzleId] = true

local function Each(Id, Fn)
	for _, Inst in ipairs(CollectionService:GetTagged("RenseiMechanism")) do
		if Inst:GetAttribute("MechanismId") == Id then Fn(Inst) end
	end
end

local function Base(Part, Key, Value)
	if Part:GetAttribute(Key) == nil then Part:SetAttribute(Key, Value) end
	return Part:GetAttribute(Key)
end

local Draw = {}
function Draw.SteamVent(Inst, State)
	local On = State == "On"
	local Steam = Inst:FindFirstChild("Steam", true)
	if Steam then Steam.Enabled = On end
	local Blocker = Inst:FindFirstChild("Blocker", true)
	if Blocker then Blocker.CanCollide = On end
	if Inst:IsA("BasePart") then
		local Color = Base(Inst, "BaseColor", Inst.Color)
		Inst.Color = (State == "Frozen" and Color3.fromRGB(170, 215, 240))
			or (State == "Capped" and Color3.fromRGB(95, 90, 85))
			or (State == "Sealed" and Color3.fromRGB(70, 75, 80)) or Color
	end
end
function Draw.Brazier(Inst, State)
	local Lit = State == "Lit"
	for _, D in ipairs(Inst:GetDescendants()) do
		if D:IsA("Fire") or D:IsA("PointLight") or (D:IsA("ParticleEmitter") and D.Name == "Flames") then D.Enabled = Lit end
	end
end
function Draw.Plate(Inst, State)
	if not Inst:IsA("BasePart") then return end
	local Held = State == "Held"
	local Y = Base(Inst, "BaseY", Inst.Position.Y)
	local Color = Base(Inst, "BaseColor", Inst.Color)
	local Goal = Inst.CFrame - Vector3.new(0, Inst.Position.Y - (Held and Y - 0.35 or Y), 0)
	TweenService:Create(Inst, TweenInfo.new(0.2), {CFrame = Goal, Color = Held and Color:Lerp(Color3.fromRGB(230, 205, 120), 0.5) or Color}):Play()
end
function Draw.Array(Inst, State)
	local Circle = Inst:FindFirstChild("Circle", true)
	if Circle and Circle:IsA("Decal") then
		Circle.Color3 = State == "Restored" and Color3.fromRGB(255, 210, 110) or Color3.fromRGB(120, 110, 100)
		Circle.Transparency = State == "Restored" and 0 or 0.35
	end
	for _, D in ipairs(Inst:GetDescendants()) do
		if D.Name:find("^Glow") and (D:IsA("ParticleEmitter") or D:IsA("Beam") or D:IsA("Light")) then D.Enabled = State == "Restored" end
	end
end
function Draw.Valve(Inst, State)
	local Open = State == "Open"
	local Wheel = Inst:IsA("Model") and Inst.PrimaryPart or Inst
	if Wheel and Wheel:IsA("BasePart") then
		local Rest = Base(Wheel, "BaseCFrame", Wheel.CFrame)
		TweenService:Create(Wheel, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {CFrame = Rest * CFrame.Angles(Open and 0 or math.pi / 2, 0, 0)}):Play()
	end
	for _, D in ipairs(Inst:GetDescendants()) do
		if D:IsA("BasePart") and D.Name == "Stream" then D.Transparency = Open and 0.45 or 1 end
		if D:IsA("ParticleEmitter") and D.Name:find("^Flow") then D.Enabled = Open end -- the splash where it pours
	end
end
function Draw.Water(Inst, State)
	if not Inst:IsA("BasePart") then return end
	local Frozen = State == "Frozen"
	local Color = Base(Inst, "BaseColor", Inst.Color)
	local Mat = Base(Inst, "BaseMaterial", Inst.Material.Name)
	Inst.Material = Frozen and Enum.Material.Ice or Enum.Material[Mat]
	Inst.Color = Frozen and Color3.fromRGB(170, 215, 240) or Color
	for _, D in ipairs(Inst:GetDescendants()) do
		if D:IsA("ParticleEmitter") and D.Parent.Name:find("^Murk") then D.Enabled = not Frozen end
	end
end

-- ===== Breakable (boards) =====
local Rng = Random.new()
local DUST = Color3.fromRGB(150, 130, 105)
local WOOD = Color3.fromRGB(120, 85, 50)

local function Planks(Inst)
	local Out = {}
	for _, D in ipairs(Inst:GetDescendants()) do
		if D:IsA("BasePart") and D.Name:find("Plank$") then table.insert(Out, D) end
	end
	return Out
end

local function Visuals()
	local World = workspace:FindFirstChild("World")
	return World and World:FindFirstChild("Visuals") or workspace
end

local function Spin(Max)
	return Vector3.new(Rng:NextNumber(-Max, Max), Rng:NextNumber(-Max, Max), Rng:NextNumber(-Max, Max))
end

-- a one-shot particle burst at Position (an invisible anchored holder, gone after 3 s)
local function Burst(Position, Count, Color, Size, Speed)
	local Holder = Instance.new("Part")
	Holder.Name = "PuzzleBurst"
	Holder.Anchored, Holder.CanCollide, Holder.CanQuery, Holder.CanTouch = true, false, false, false
	Holder.Transparency = 1
	Holder.Size = Vector3.new(0.2, 0.2, 0.2)
	Holder.CFrame = CFrame.new(Position)
	local E = Instance.new("ParticleEmitter")
	E.Texture = "rbxasset://textures/particles/smoke_main.dds"
	E.Color = ColorSequence.new(Color)
	E.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, Size), NumberSequenceKeypoint.new(1, Size * 2.5)})
	E.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1)})
	E.Lifetime = NumberRange.new(0.8, 1.6)
	E.Speed = NumberRange.new(Speed * 0.4, Speed)
	E.SpreadAngle = Vector2.new(180, 180)
	E.Drag = 3
	E.Acceleration = Vector3.new(0, -2, 0)
	E.Rate = 0
	E.Parent = Holder
	Holder.Parent = Visuals()
	E:Emit(Count)
	Debris:AddItem(Holder, 3)
	return Holder
end

-- the mechanism's own sound attribute (BreakSound / CrackSound = an rbxassetid). The game has no wood-break sound
-- yet (2026-10-20), so none plays until one is set on the model.
local function Sound(Inst, Attribute, Parent)
	local Id = Inst:GetAttribute(Attribute)
	if type(Id) ~= "string" or Id == "" then return end
	local S = Instance.new("Sound")
	S.SoundId = Id
	S.Volume = 0.8
	S.RollOffMaxDistance = 120
	S.Parent = Parent
	S:Play()
	Debris:AddItem(S, 5)
end

-- the live break: every plank snaps into loose pieces that fly off (an outward impulse, away from this player, plus a
-- random spin; they collide and are removed after 6 s), with a dust burst
local function Smash(Inst, List)
	if #List == 0 then return end
	local Character = Players.LocalPlayer.Character
	local Root = Character and Character:FindFirstChild("HumanoidRootPart")
	local Folder = Visuals()
	local Center = Vector3.zero
	for _, P in ipairs(List) do
		Center += P.Position
		local Away = Root and (P.Position - Root.Position) or nil
		Away = Away and Away.Magnitude < 40 and Vector3.new(Away.X, 0, Away.Z) or nil
		if not Away or Away.Magnitude < 0.1 then Away = P.CFrame.RightVector end -- the plank's face
		Away = Away.Unit
		local Count = 3 -- pieces per plank
		local Length = P.Size.Z / Count
		for I = 1, Count do
			local Piece = Instance.new("Part")
			Piece.Name = "PlankDebris"
			Piece.Material, Piece.Color = P.Material, P.Color
			Piece.Transparency = P:GetAttribute("BaseTransparency") or P.Transparency
			Piece.Size = Vector3.new(P.Size.X, P.Size.Y, Length * 0.92)
			Piece.CFrame = P.CFrame * CFrame.new(0, 0, (I - (Count + 1) / 2) * Length) * CFrame.Angles(0, 0, Rng:NextNumber(-0.2, 0.2))
			Piece.Anchored, Piece.CanCollide, Piece.CanQuery, Piece.CanTouch = false, true, false, false
			Piece.Parent = Folder
			Piece:ApplyImpulse((Away * Rng:NextNumber(18, 30) + Vector3.new(0, Rng:NextNumber(6, 14), 0) + Spin(4)) * Piece.AssemblyMass)
			Piece.AssemblyAngularVelocity = Spin(12)
			Debris:AddItem(Piece, 6)
		end
	end
	local Holder = Burst(Center / #List, 60, DUST, 3, 10)
	Sound(Inst, "BreakSound", Holder)
end

-- a hit that didn't break it yet: splinters at the nearest plank
local function Crack(Id, Position)
	if typeof(Position) ~= "Vector3" then return end
	Each(Id, function(Inst)
		local Best, Point, Gap = nil, nil, math.huge
		for _, P in ipairs(Planks(Inst)) do
			if P.Transparency < 1 then
				local L = P.CFrame:PointToObjectSpace(Position)
				local H = P.Size / 2
				local Near = P.CFrame:PointToWorldSpace(Vector3.new(math.clamp(L.X, -H.X, H.X), math.clamp(L.Y, -H.Y, H.Y), math.clamp(L.Z, -H.Z, H.Z)))
				local D = (Near - Position).Magnitude
				if D < Gap then Best, Point, Gap = P, Near, D end
			end
		end
		if not Best then return end
		local Holder = Burst(Point, 14, WOOD, 0.6, 8)
		for _ = 1, 4 do
			local Chip = Instance.new("Part")
			Chip.Name = "Splinter"
			Chip.Material, Chip.Color = Best.Material, Best.Color
			Chip.Size = Vector3.new(0.15, 0.15, Rng:NextNumber(0.4, 0.9))
			Chip.CFrame = CFrame.new(Point) * CFrame.Angles(Rng:NextNumber(0, 6.28), Rng:NextNumber(0, 6.28), 0)
			Chip.Anchored, Chip.CanCollide, Chip.CanQuery, Chip.CanTouch = false, false, false, false
			Chip.Parent = Holder.Parent
			Chip.AssemblyLinearVelocity = Spin(10) + Vector3.new(0, 8, 0)
			Chip.AssemblyAngularVelocity = Spin(20)
			Debris:AddItem(Chip, 1.5)
		end
		Sound(Inst, "CrackSound", Holder)
	end)
end

function Draw.Breakable(Inst, State, Live)
	local Broken = State ~= "Whole"
	local List = Planks(Inst)
	if Broken and Live and Inst:GetAttribute("DrawnBroken") ~= true then pcall(Smash, Inst, List) end
	for _, P in ipairs(List) do
		local T = Base(P, "BaseTransparency", P.Transparency)
		local Q = Base(P, "BaseCanQuery", P.CanQuery)
		P.Transparency = Broken and 1 or T
		P.CanCollide = not Broken -- Whole: every plank blocks, the loose ones too
		P.CanQuery = (not Broken) and Q
	end
	Inst:SetAttribute("DrawnBroken", Broken)
end

-- Live = a state change that just happened (a State message), not a sync or a part streaming in
local function Apply(Id, Live)
	local Def = Content.Mechanisms[Id]
	if not Def then return end
	local State = States[Id] or Def.Default
	Each(Id, function(Inst)
		local Fn = Draw[Inst:GetAttribute("Draw") or Def.Kind]
		if Fn then pcall(Fn, Inst, State, Live) end
	end)
end

local function ApplyDoor(Door)
	local Open = Solved[Door:GetAttribute("PuzzleId")] == true
	local Parts = Door:IsA("BasePart") and {Door} or Door:GetDescendants()
	for _, P in ipairs(Parts) do
		if P:IsA("BasePart") then
			local T = Base(P, "BaseTransparency", P.Transparency)
			P.CanCollide = not Open
			TweenService:Create(P, TweenInfo.new(Open and 0.8 or 0), {Transparency = Open and 1 or T}):Play()
		end
	end
end

local function ApplyAll()
	for Id in pairs(Content.Mechanisms) do Apply(Id) end
	for _, Door in ipairs(CollectionService:GetTagged("RenseiPuzzleDoor")) do ApplyDoor(Door) end
end

function PuzzleClient.Start()
	task.spawn(PuzzleClient.Run) -- never hold up the other UI modules while the remote appears
end

function PuzzleClient.Run()
	local Remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PuzzleRemote", 30)
	if not Remote then return end
	Remote.OnClientEvent:Connect(function(Kind, A, B)
		if Kind == "Sync" then
			States = A or {}
			Solved = {}
			for _, Id in ipairs(B or {}) do Solved[Id] = true end
			ApplyAll()
		elseif Kind == "State" then
			States[A] = B
			Apply(A, true)
		elseif Kind == "Solved" then
			Solved[A] = true
			for _, Door in ipairs(CollectionService:GetTagged("RenseiPuzzleDoor")) do
				if Door:GetAttribute("PuzzleId") == A then ApplyDoor(Door) end
			end
		elseif Kind == "Cracked" then
			pcall(Crack, A, B)
		end
	end)
	-- streamed-in parts get drawn as they arrive
	CollectionService:GetInstanceAddedSignal("RenseiMechanism"):Connect(function(Inst)
		task.defer(Apply, Inst:GetAttribute("MechanismId"))
	end)
	CollectionService:GetInstanceAddedSignal("RenseiPuzzleDoor"):Connect(function(Door) task.defer(ApplyDoor, Door) end)
	Remote:FireServer("Sync")
end

return PuzzleClient

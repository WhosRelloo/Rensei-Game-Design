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
-- Doors: parts tagged RenseiPuzzleDoor with attribute PuzzleId open once that puzzle is solved.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

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

local function Apply(Id)
	local Def = Content.Mechanisms[Id]
	if not Def then return end
	local State = States[Id] or Def.Default
	Each(Id, function(Inst)
		local Fn = Draw[Inst:GetAttribute("Draw") or Def.Kind]
		if Fn then pcall(Fn, Inst, State) end
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
			Apply(A)
		elseif Kind == "Solved" then
			Solved[A] = true
			for _, Door in ipairs(CollectionService:GetTagged("RenseiPuzzleDoor")) do
				if Door:GetAttribute("PuzzleId") == A then ApplyDoor(Door) end
			end
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

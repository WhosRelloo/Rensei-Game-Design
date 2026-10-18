-- Earth kit VFX shapes, from the owner's prototype assets (Assets.VFX.EarthElement: the Rock and Spike
-- meshes, the EarthRise sound, the crack decal, dust / chip bursts). Rock takes the colour and material
-- of the ground it rises from, like the prototypes did.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local EarthShapes = {}

local function Folder() return ReplicatedStorage.Assets.VFX:FindFirstChild("EarthElement") end

local DEFAULT = {Color = Color3.fromRGB(105, 98, 90), Material = Enum.Material.Slate}
-- materials that don't read as rock: use the default rock look instead
local NOT_ROCK = {
	[Enum.Material.Fabric] = true, [Enum.Material.Wood] = true, [Enum.Material.WoodPlanks] = true,
	[Enum.Material.Glass] = true, [Enum.Material.Neon] = true, [Enum.Material.ForceField] = true,
	[Enum.Material.Plastic] = true, [Enum.Material.SmoothPlastic] = true, [Enum.Material.Metal] = true,
	[Enum.Material.DiamondPlate] = true, [Enum.Material.Foil] = true,
}

local Params = RaycastParams.new()
Params.FilterType = Enum.RaycastFilterType.Exclude
-- (2026-10-18) rock rises from the bed under water: hitting the water surface gave GetMaterialColor(Water),
-- which errors ("Unsupported terrain material") and stopped the spike / rock VFX over the swimmable pools
Params.IgnoreWater = true

-- The ground under Position: {Position, Color, Material}.
function EarthShapes.Ground(Position)
	Params.FilterDescendantsInstances = {workspace.World.Live, workspace.World.Visuals}
	local Hit = workspace:Raycast(Position + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), Params)
	if not Hit then return {Position = Position, Color = DEFAULT.Color, Material = DEFAULT.Material} end
	local Mat, Col = Hit.Material, Hit.Instance.Color
	if Hit.Instance:IsA("Terrain") then
		local Ok, C = pcall(function() return workspace.Terrain:GetMaterialColor(Mat) end)
		if Ok then Col = C else Mat, Col = DEFAULT.Material, DEFAULT.Color end
	elseif NOT_ROCK[Mat] then
		Mat, Col = DEFAULT.Material, DEFAULT.Color
	end
	if Mat == Enum.Material.Grass or Mat == Enum.Material.LeafyGrass then Mat, Col = Enum.Material.Ground, Color3.fromRGB(110, 90, 66) end
	return {Position = Hit.Position, Color = Col, Material = Mat}
end

local function Clone(Name, Size, CF, Style)
	local F = Folder()
	local Template = F and F:FindFirstChild(Name)
	local P
	if Template then
		P = Template:Clone()
	else
		P = Instance.new("Part")
		P.Anchored, P.CanCollide, P.CanQuery, P.CanTouch = true, false, false, false
	end
	P.Size = Size
	P.CFrame = CF
	if Style then
		P.Color = Style.Color
		P.Material = Style.Material
	end
	P.Parent = workspace.World.Visuals
	return P
end

-- A rough rock block (the prototypes' wall / pillar mesh), centred on CF.
function EarthShapes.Rock(CF, Size, Style) return Clone("Rock", Size, CF, Style) end

-- A rock spike standing on CF (its base), pointing along CF.UpVector.
function EarthShapes.Spike(CF, Height, Width, Style)
	return Clone("Spike", Vector3.new(Width, Height, Width), CF * CFrame.new(0, Height / 2, 0), Style)
end

-- One-shot burst ("dust" / "chips") at CF.
function EarthShapes.Emit(Name, CF, Scale, Color)
	local F = Folder()
	local Template = F and F:FindFirstChild(Name)
	if not Template then return end
	local P = Template:Clone()
	P.CFrame = CF
	P.Parent = workspace.World.Visuals
	local Longest = 0
	for _, E in ipairs(P:GetDescendants()) do
		if E:IsA("ParticleEmitter") then
			if Color and E.Name == "Chips" then E.Color = ColorSequence.new(Color) end
			E:Emit(math.max(1, math.floor((E:GetAttribute("EmitCount") or 10) * (Scale or 1))))
			Longest = math.max(Longest, E.Lifetime.Max)
		end
	end
	Debris:AddItem(P, Longest + 0.3)
end

-- The prototypes' rumble.
function EarthShapes.Sound(Name, Position, Volume)
	local F = Folder()
	local S = F and F:FindFirstChild(Name)
	if not S then return end
	local Holder = Instance.new("Attachment")
	Holder.WorldPosition = Position
	Holder.Parent = workspace.Terrain
	local Snd = S:Clone()
	if Volume then Snd.Volume = Volume end
	Snd.Parent = Holder
	Snd:Play()
	Debris:AddItem(Holder, 4)
end

-- A crack decal on the ground at Position (Size studs across), fading after Life seconds.
function EarthShapes.Crack(Position, Size, Life)
	local F = Folder()
	local D = F and F:FindFirstChild("Cracked")
	if not D then return end
	local P = Instance.new("Part")
	P.Anchored, P.CanCollide, P.CanQuery, P.CanTouch = true, false, false, false
	P.Transparency = 1
	P.Size = Vector3.new(Size, 0.05, Size)
	P.CFrame = CFrame.new(Position + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
	local Decal = D:Clone()
	Decal.Face = Enum.NormalId.Top
	Decal.Parent = P
	P.Parent = workspace.World.Visuals
	task.delay(Life or 3, function()
		TweenService:Create(Decal, TweenInfo.new(0.8), {Transparency = 1}):Play()
	end)
	Debris:AddItem(P, (Life or 3) + 1)
end

return EarthShapes

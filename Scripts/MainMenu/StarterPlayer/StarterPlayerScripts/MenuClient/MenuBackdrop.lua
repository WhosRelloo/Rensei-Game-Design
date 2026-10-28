-- The painted menu's living backdrop (owner 2026-10-28: "make the menu animated, with animated background, ambiance").
-- Client only, on Workspace.PaintedStage (built by Art/Studio/MainMenu/build_stage.py) and its markers
-- (Modules.Data.Rensei.MenuStage). Everything moves here, as it did in the Blender preview (Art/MainMenu/menu_anim.py):
-- the dusk lighting, embers and ash, haze over the platform, smoke from the far stacks, the lantern's sway and flicker,
-- the niche lamps, the train's run across the viaduct, and the alchemy reaction's arcs over the chalk circles (rebuilt
-- every few frames; Surge makes it flare when a slot is picked). Built-in particle textures only: nothing uploaded.
-- MenuBackdrop.Start(Stage, Markers, Art) -> the controller: :SetAlcoves(Owned, EmptySlots), :Surge(Circle, Amount), :Stop()

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local ARC = Color3.fromRGB(150, 200, 255)

local MenuBackdrop = {}

local function V(t) return Vector3.new(t[1], t[2], t[3]) end

local function New(Class, Props)
	local I = Instance.new(Class)
	for K, X in pairs(Props) do if K ~= "Parent" then I[K] = X end end
	I.Parent = Props.Parent
	return I
end

-- a flame's unsteadiness: a few incommensurate sines, about -1..1
local function Flicker(T, Seed)
	return 0.5 * math.sin(T * 7.3 + Seed) + 0.3 * math.sin(T * 13.1 + Seed * 2.1) + 0.2 * math.sin(T * 29.7 + Seed * 3.7)
end

-- the dusk look, set on this client only (the place's own Lighting stays as it is in Studio)
local function Dusk()
	Lighting.ClockTime = 18.35
	Lighting.Brightness = 0.7
	Lighting.Ambient = Color3.fromRGB(34, 28, 27)
	Lighting.OutdoorAmbient = Color3.fromRGB(70, 50, 38)
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.FogEnd = 100000
	Lighting.ExposureCompensation = 0
	local A = Lighting:FindFirstChildOfClass("Atmosphere") or New("Atmosphere", {Parent = Lighting})
	A.Density, A.Offset, A.Haze, A.Glare = 0.38, 0.15, 1.8, 0.35
	A.Color, A.Decay = Color3.fromRGB(196, 120, 66), Color3.fromRGB(84, 52, 40)
	local CC = Lighting:FindFirstChild("WorldColor")
	if CC and CC:IsA("ColorCorrectionEffect") then
		CC.Brightness, CC.Contrast, CC.Saturation, CC.TintColor = -0.02, 0.14, -0.06, Color3.fromRGB(255, 236, 214)
	end
	local B = Lighting:FindFirstChild("MenuBloom") or New("BloomEffect", {Name = "MenuBloom", Parent = Lighting})
	B.Intensity, B.Size, B.Threshold = 0.7, 28, 1.25
	local Rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if Rays then Rays.Intensity, Rays.Spread = 0.04, 0.6 end
end

local function Emitter(Parent, Props)
	local E = New("ParticleEmitter", {LightInfluence = 0, Parent = Parent})
	for K, X in pairs(Props) do E[K] = X end
	return E
end

-- an invisible box part to emit from
local function Source(Stage, Name, Centre, Size)
	return New("Part", {Name = Name, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1,
		Size = Size, CFrame = CFrame.new(Centre), Parent = Stage})
end

-- one arc of the reaction: a chain of beams through jagged points (midpoint displacement)
local function Jagged(A, B, Jag, Depth, Rng)
	local Pts = {A, B}
	local Amp = (B - A).Magnitude * Jag
	for _ = 1, Depth do
		local Out = {Pts[1]}
		for I = 1, #Pts - 1 do
			local M = (Pts[I] + Pts[I + 1]) / 2 + Vector3.new(Rng:NextNumber(-1, 1), Rng:NextNumber(-1, 1), Rng:NextNumber(-1, 1)) * Amp
			table.insert(Out, M)
			table.insert(Out, Pts[I + 1])
		end
		Pts = Out
		Amp /= 2
	end
	return Pts
end

local function Reaction(Stage, Name, Centre, Radius, Count)
	local Holder = New("Part", {Name = Name, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(Centre), Parent = Stage})
	local Glow = New("PointLight", {Color = ARC, Range = Radius * 3, Brightness = 1, Shadows = false, Parent = Holder})
	local Arcs = {}
	local PER = 9 -- points per arc (Depth 3 gives 9)
	for I = 1, Count do
		local Att, Beams = {}, {}
		for K = 1, PER do Att[K] = New("Attachment", {Parent = Holder}) end
		for K = 1, PER - 1 do
			Beams[K] = New("Beam", {Attachment0 = Att[K], Attachment1 = Att[K + 1], FaceCamera = true, LightEmission = 1, LightInfluence = 0,
				Width0 = 0.07, Width1 = 0.07, Color = ColorSequence.new(ARC), Transparency = NumberSequence.new(0), Segments = 1,
				Brightness = 4, Enabled = false, Parent = Holder})
		end
		Arcs[I] = {Att = Att, Beams = Beams}
	end
	return {Holder = Holder, Glow = Glow, Arcs = Arcs, Centre = Centre, Radius = Radius, Surge = 0, On = true}
end

local function Crackle(R, Rng)
	local Live = R.On and math.floor(#R.Arcs * (0.45 + 0.55 * math.min(1, 0.4 + R.Surge))) or 0
	for I, A in ipairs(R.Arcs) do
		local Show = I <= Live and Rng:NextNumber() < 0.85
		for _, B in ipairs(A.Beams) do B.Enabled = Show end
		if Show then
			local A0 = Rng:NextNumber(0, math.pi * 2)
			local A1 = A0 + Rng:NextNumber(0.4, 1.1)
			local R0 = R.Radius * Rng:NextNumber(0.55, 1)
			local P0 = Vector3.new(math.cos(A0) * R0, 0.05, math.sin(A0) * R0)
			local Up = Rng:NextNumber() < 0.15 + 0.3 * R.Surge
			local P1 = Up and P0 + Vector3.new(Rng:NextNumber(-0.6, 0.6), Rng:NextNumber(0.8, 1.8 + 2.5 * R.Surge), 0)
				or Vector3.new(math.cos(A1) * R.Radius, 0.05, math.sin(A1) * R.Radius)
			local Pts = Jagged(P0, P1, 0.3, 3, Rng)
			for K, Att in ipairs(A.Att) do Att.Position = Pts[K] end
			local W = 0.05 + 0.05 * Rng:NextNumber() + 0.05 * R.Surge
			for _, B in ipairs(A.Beams) do B.Width0, B.Width1 = W, W end
		end
	end
	R.Glow.Brightness = R.On and (0.6 + Rng:NextNumber() * 1.2) * (1 + 2.5 * R.Surge) or 0
end

function MenuBackdrop.Start(Stage, Markers, Art)
	Dusk()
	local Rng = Random.new()
	local Ctl = {Reactions = {}, Conns = {}}

	-- embers and ash over the platform, haze low over it, smoke rising from the far stacks
	local EB = Markers.ember_box
	local Embers = Source(Stage, "Embers", V(EB.centre), Vector3.new(EB.size[1], 0.2, EB.size[3]))
	Emitter(Embers, {Texture = SPARK, Rate = 22, Lifetime = NumberRange.new(5, 9), Speed = NumberRange.new(1.2, 3),
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(25, 25), Acceleration = Vector3.new(0.6, 0.5, 0),
		Drag = 0.35, LightEmission = 1, Brightness = 3, Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.16), NumberSequenceKeypoint.new(1, 0.04)}),
		Color = ColorSequence.new(Color3.fromRGB(255, 170, 80), Color3.fromRGB(220, 60, 40)),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0), NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 1)}),
		RotSpeed = NumberRange.new(-90, 90)})
	Emitter(Embers, {Texture = SPARK, Rate = 6, Lifetime = NumberRange.new(8, 12), Speed = NumberRange.new(0.4, 1),
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(40, 40), Acceleration = Vector3.new(0.4, 0.15, 0),
		LightEmission = 0, Brightness = 1, Size = NumberSequence.new(0.07), Color = ColorSequence.new(Color3.fromRGB(150, 140, 136)),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.4), NumberSequenceKeypoint.new(1, 1)})})
	local HB = Markers.haze_box
	local Haze = Source(Stage, "Haze", V(HB.centre) - Vector3.new(0, HB.size[2] * 0.35, 0), Vector3.new(HB.size[1], 1, HB.size[3]))
	Emitter(Haze, {Texture = SMOKE, Rate = 1.6, Lifetime = NumberRange.new(14, 20), Speed = NumberRange.new(0.2, 0.6),
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(70, 70), Acceleration = Vector3.new(0.35, 0.02, 0),
		Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 9), NumberSequenceKeypoint.new(1, 16)}),
		Color = ColorSequence.new(Color3.fromRGB(120, 104, 98)), LightInfluence = 0.6, Brightness = 1,
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.9), NumberSequenceKeypoint.new(0.7, 0.9), NumberSequenceKeypoint.new(1, 1)}),
		RotSpeed = NumberRange.new(-6, 6), Rotation = NumberRange.new(0, 360)})
	for I, P in ipairs(Markers.stack_tops) do
		local Top = Source(Stage, "Stack" .. I, V(P), Vector3.new(8, 1, 8))
		Emitter(Top, {Texture = SMOKE, Rate = 3, Lifetime = NumberRange.new(10, 14), Speed = NumberRange.new(8, 12),
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(12, 12), Acceleration = Vector3.new(6, 1, 0),
			Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 14), NumberSequenceKeypoint.new(1, 60)}),
			Color = ColorSequence.new(Color3.fromRGB(110, 70, 50), Color3.fromRGB(56, 48, 48)), LightInfluence = 0.3,
			Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1)}),
			RotSpeed = NumberRange.new(-10, 10), Rotation = NumberRange.new(0, 360)})
	end

	-- the reaction over the platform circle (and, per SetAlcoves, over each empty slot's circle)
	local PC = Markers.platform_circle
	Ctl.Reactions.Platform = Reaction(Stage, "Reaction", V(PC.centre), PC.radius, 12)

	-- the lantern sways about its hook; the lamps flicker
	local Lantern = Stage:FindFirstChild("Lantern")
	local LanternBase
	if Lantern and Lantern:IsA("Model") then
		Lantern.WorldPivot = CFrame.new(V(Markers.lantern_pivot))
		LanternBase = Lantern:GetPivot()
	end
	local Lamps = {}
	for _, D in ipairs(Stage:GetDescendants()) do
		if D:IsA("PointLight") and D.Parent and D.Parent.Name:match("^Light_") then
			table.insert(Lamps, {Light = D, Base = D.Brightness, Seed = #Lamps * 1.7})
		end
	end
	-- the train: across the viaduct every so often
	local Train = Stage:FindFirstChild("Train")
	local TrainBase = Train and Train:IsA("Model") and Train:GetPivot()

	-- the ambience (the 60 s loop, once uploaded)
	if Art and Art.Ambience and Art.Ambience ~= 0 then
		Ctl.Sound = New("Sound", {Name = "MenuAmbience", SoundId = "rbxassetid://" .. Art.Ambience, Looped = true, Volume = 0.55, Parent = SoundService})
		Ctl.Sound:Play()
	end

	local Clock, NextArc = 0, 0
	table.insert(Ctl.Conns, RunService.RenderStepped:Connect(function(Dt)
		Clock += Dt
		local T = Clock
		if Lantern and LanternBase then
			Lantern:PivotTo(LanternBase * CFrame.Angles(0.05 * math.sin(T * math.pi / 2), 0, 0.03 * math.sin(T * math.pi / 4 + 1)))
		end
		for _, L in ipairs(Lamps) do L.Light.Brightness = L.Base * (1 + 0.08 * Flicker(T, L.Seed)) end
		if Train and TrainBase then
			local Cycle = 14 -- 8 s across, then 6 s gone
			local P = (T % Cycle) / 8
			local X = Markers.train.from_x + (Markers.train.to_x - Markers.train.from_x) * math.min(P, 1) -- (studs from where it was built)
			Train:PivotTo(TrainBase + Vector3.new(X, 0, 0))
		end
		if T >= NextArc then
			NextArc = T + 1 / 12
			for _, R in pairs(Ctl.Reactions) do Crackle(R, Rng) end
		end
	end))

	function Ctl:SetAlcoves(Alcoves, EmptySlots)
		for Key, R in pairs(self.Reactions) do
			if Key ~= "Platform" then R.Holder:Destroy() self.Reactions[Key] = nil end
		end
		for _, Slot in ipairs(EmptySlots) do
			local A = Alcoves[Slot]
			if A then self.Reactions[Slot] = Reaction(Stage, "Reaction" .. Slot, V(A.circle.centre), A.circle.radius, 6) end
		end
	end

	-- Amount 0..1: the reaction flares (a slot picked, the camera on its way)
	function Ctl:Surge(Key, Amount)
		local R = self.Reactions[Key]
		if R then R.Surge = Amount end
		if Key ~= "Platform" and self.Reactions.Platform then self.Reactions.Platform.Surge = Amount * 0.6 end
	end

	function Ctl:Stop()
		for _, C in ipairs(self.Conns) do C:Disconnect() end
		if self.Sound then self.Sound:Destroy() end
	end
	return Ctl
end

return MenuBackdrop

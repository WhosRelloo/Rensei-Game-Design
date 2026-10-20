-- StealthUI (2026-10-20, Morality × Reputation spec §17.4; Plan 2, slice S2): the eye sigil, bottom left. Original
-- art in the transmutation-circle style (not a copy of any game's "light gem"):
--   * an outer circle with an inscribed square, like a chalk array;
--   * an eye in the middle whose iris glows with your Exposure: dark in deep shadow, gold in bright light;
--   * a ring that flares outward when you make a sound, sized by how far it carries, then fades.
-- Reads the character attributes Exposure (LightService), Noise / NoiseAt (NoiseService) and Crouching; it
-- never decides anything. Hidden with the HUD's rules (menus, dialogue, cutscenes, death).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UIState = require(script.Parent.UIState)

local Player = Players.LocalPlayer

local INK = Color3.fromRGB(236, 228, 206)
local GOLD = Color3.fromRGB(240, 196, 104)
local DARK = Color3.fromRGB(40, 44, 62)
local SIZE = 46
local LOUDEST = 30 -- a sound this far-reaching fills the ring (an alchemy cast)
local FADE = 1.2 -- seconds a sound's ring takes to fade

local StealthUI = {}

local function Make(Class, Props, Parent)
	local O = Instance.new(Class)
	for K, V in pairs(Props) do O[K] = V end
	O.Parent = Parent
	return O
end

local Gui, Root, Iris, Pupil, Ring, RingStroke, Lid

local function Build()
	Gui = Make("ScreenGui", {Name = "Stealth", ResetOnSpawn = false, DisplayOrder = 4, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, Player:WaitForChild("PlayerGui"))
	Root = Make("CanvasGroup", {Name = "Sigil", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 22, 1, -245), -- above the party-name row
		Size = UDim2.fromOffset(SIZE + 30, SIZE + 30), BackgroundTransparency = 1}, Gui)
	local Centre = UDim2.fromScale(0.5, 0.5)
	-- the sound ring (behind everything)
	Ring = Make("Frame", {Name = "Sound", AnchorPoint = Vector2.new(0.5, 0.5), Position = Centre, Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundTransparency = 1}, Root)
	Make("UICorner", {CornerRadius = UDim.new(1, 0)}, Ring)
	RingStroke = Make("UIStroke", {Color = INK, Thickness = 2, Transparency = 1}, Ring)
	-- the array: a circle and an inscribed square
	local Circle = Make("Frame", {Name = "Circle", AnchorPoint = Vector2.new(0.5, 0.5), Position = Centre, Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundColor3 = Color3.fromRGB(12, 12, 15), BackgroundTransparency = 0.35}, Root)
	Make("UICorner", {CornerRadius = UDim.new(1, 0)}, Circle)
	Make("UIStroke", {Color = INK, Thickness = 1.4, Transparency = 0.25}, Circle)
	local Square = Make("Frame", {Name = "Square", AnchorPoint = Vector2.new(0.5, 0.5), Position = Centre,
		Size = UDim2.fromOffset(SIZE * 0.7, SIZE * 0.7), Rotation = 45, BackgroundTransparency = 1}, Root)
	Make("UIStroke", {Color = INK, Thickness = 1, Transparency = 0.55}, Square)
	-- the eye: an almond (a squashed circle), an iris that glows with Exposure, a pupil
	local Eye = Make("Frame", {Name = "Eye", AnchorPoint = Vector2.new(0.5, 0.5), Position = Centre, Size = UDim2.fromOffset(30, 14),
		BackgroundColor3 = INK, BackgroundTransparency = 0.1, ClipsDescendants = true}, Root)
	Make("UICorner", {CornerRadius = UDim.new(1, 0)}, Eye)
	Iris = Make("Frame", {Name = "Iris", AnchorPoint = Vector2.new(0.5, 0.5), Position = Centre, Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = GOLD}, Eye)
	Make("UICorner", {CornerRadius = UDim.new(1, 0)}, Iris)
	Pupil = Make("Frame", {Name = "Pupil", AnchorPoint = Vector2.new(0.5, 0.5), Position = Centre, Size = UDim2.fromOffset(4, 4),
		BackgroundColor3 = Color3.fromRGB(10, 10, 12)}, Iris)
	Make("UICorner", {CornerRadius = UDim.new(1, 0)}, Pupil)
	-- crouching lowers the lid
	Lid = Make("Frame", {Name = "Lid", Position = UDim2.fromScale(0, 0), Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = Color3.fromRGB(12, 12, 15), BorderSizePixel = 0, ZIndex = 3}, Eye)
end

local function Hidden()
	local G = UIState.Gui
	if (G:FindFirstChild("bg") and G.bg.Visible) or (G:FindFirstChild("Dialogue") and G.Dialogue.Visible) then return true end
	if workspace.CurrentCamera.CameraType == Enum.CameraType.Scriptable or Player:GetAttribute("InTruth") then return true end
	local C = Player.Character
	local Hum = C and C:FindFirstChildOfClass("Humanoid")
	return not Hum or Hum.Health <= 0
end

function StealthUI.Draw()
	if Hidden() then Root.GroupTransparency = 1 return end
	Root.GroupTransparency = 0
	local C = Player.Character
	local E = math.clamp(tonumber(C:GetAttribute("Exposure")) or 1, 0, 1)
	Iris.BackgroundColor3 = DARK:Lerp(GOLD, E)
	Iris.BackgroundTransparency = 0.05
	Lid.Size = UDim2.new(1, 0, C:GetAttribute("Crouching") and 0.45 or 0, 0)
	-- the last sound: a ring out to its reach, fading
	local Noise = tonumber(C:GetAttribute("Noise")) or 0
	local Age = workspace:GetServerTimeNow() - (tonumber(C:GetAttribute("NoiseAt")) or -math.huge)
	if Noise > 0 and Age < FADE then
		local K = math.clamp(Noise / LOUDEST, 0.1, 1)
		local D = SIZE + 4 + 26 * K * math.clamp(Age / 0.25, 0, 1)
		Ring.Size = UDim2.fromOffset(D, D)
		RingStroke.Transparency = 0.15 + 0.85 * (Age / FADE)
		RingStroke.Thickness = 1 + 2 * K
	else
		RingStroke.Transparency = 1
	end
end

function StealthUI.Start()
	Build()
	RunService.RenderStepped:Connect(function()
		local Ok, Err = pcall(StealthUI.Draw)
		if not Ok and not StealthUI._Warned then StealthUI._Warned = true warn("[StealthUI] " .. tostring(Err)) end
	end)
end

return StealthUI

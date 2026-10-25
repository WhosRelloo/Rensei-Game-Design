-- StealthUI (2026-10-20, Morality & Reputation spec 17.4; Plan 2, slice S2): the stealth sigil, bottom left.
-- Restyled 2026-10-21 (owner rule: "ONLY use existing UI assets"): built only from the game's own art, the same
-- pieces as the alchemy slots (AlchemyUI) and the interact prompt (PromptUI):
--   * the hotbar slot plate (Uis.HUD.Bottom, 108980512067469) as the sigil's frame;
--   * the transmutation circle (132299053523633) inside it, tinted with your Exposure: dark in deep shadow, gold in
--     bright light (it was the eye's iris);
--   * crouching lowers a lid over the circle: its top 45% is hidden (a clipping layout frame, no drawn shape);
--   * a sound sends a second transmutation circle out from the plate, sized by how far it carries, then fading
--     (it was a drawn ring; louder sounds also show brighter, where the ring drew thicker).
-- Reads the character attributes Exposure (LightService), Noise / NoiseAt (NoiseService) and Crouching; it
-- never decides anything. Hidden with the HUD's rules (menus, dialogue, cutscenes, death).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UIState = require(script.Parent.UIState)

local Player = Players.LocalPlayer

local SLOT_IMAGE = "rbxassetid://108980512067469" -- Rensei hotbar slot plate (as AlchemyUI / PromptUI)
local CIRCLE_IMAGE = "rbxassetid://132299053523633" -- Rensei transmutation circle, white, tinted (as AlchemyUI)
local INK = Color3.fromRGB(236, 228, 206)
local GOLD = Color3.fromRGB(240, 196, 104)
local DARK = Color3.fromRGB(92, 104, 146) -- deep shadow: a dim cold blue (the old iris's (40, 44, 62) vanished on the dark plate)
local SIZE = 46
local CIRCLE = math.floor(SIZE * 0.78 + 0.5) -- the circle inside the plate (PromptUI's proportion)
local LID = 0.45 -- how much of the circle crouching covers (as the old eyelid)
local LOUDEST = 30 -- a sound this far-reaching fills the ring (an alchemy cast)
local FADE = 1.2 -- seconds a sound's ring takes to fade

local StealthUI = {}

local function Make(Class, Props, Parent)
	local O = Instance.new(Class)
	for K, V in pairs(Props) do O[K] = V end
	O.Parent = Parent
	return O
end

local Gui, Root, Iris, Ring, Lid

local function Build()
	Gui = Make("ScreenGui", {Name = "Stealth", ResetOnSpawn = false, DisplayOrder = 4, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, Player:WaitForChild("PlayerGui"))
	Root = Make("CanvasGroup", {Name = "Sigil", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 22, 1, -245), -- above the party-name row
		Size = UDim2.fromOffset(SIZE + 30, SIZE + 30), BackgroundTransparency = 1}, Gui)
	local Centre = UDim2.fromScale(0.5, 0.5)
	-- the sound ring (behind everything): a transmutation circle that grows out from the plate
	Ring = Make("ImageLabel", {Name = "Sound", AnchorPoint = Vector2.new(0.5, 0.5), Position = Centre, Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundTransparency = 1, Image = CIRCLE_IMAGE, ImageColor3 = INK, ImageTransparency = 1, ZIndex = 1}, Root)
	-- the frame: the hotbar slot plate
	local Plate = Make("ImageLabel", {Name = "Plate", AnchorPoint = Vector2.new(0.5, 0.5), Position = Centre,
		Size = UDim2.fromOffset(SIZE, SIZE), BackgroundTransparency = 1, Image = SLOT_IMAGE, ZIndex = 2}, Root)
	-- the lid: a transparent clipping frame over the circle, anchored at its foot; crouching shortens it from the top
	Lid = Make("Frame", {Name = "Lid", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.5, CIRCLE / 2),
		Size = UDim2.fromOffset(CIRCLE, CIRCLE), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 3}, Plate)
	-- the circle that glows with Exposure (kept at full size, pinned to the lid's foot, so the lid hides its top)
	Iris = Make("ImageLabel", {Name = "Iris", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(CIRCLE, CIRCLE), BackgroundTransparency = 1, Image = CIRCLE_IMAGE, ImageColor3 = GOLD, ZIndex = 3}, Lid)
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
	Iris.ImageColor3 = DARK:Lerp(GOLD, E)
	Iris.ImageTransparency = 0.05
	Lid.Size = UDim2.fromOffset(CIRCLE, math.floor(CIRCLE * (C:GetAttribute("Crouching") and 1 - LID or 1) + 0.5))
	-- the last sound: a circle out to its reach, fading
	local Noise = tonumber(C:GetAttribute("Noise")) or 0
	local Age = workspace:GetServerTimeNow() - (tonumber(C:GetAttribute("NoiseAt")) or -math.huge)
	if Noise > 0 and Age < FADE then
		local K = math.clamp(Noise / LOUDEST, 0.1, 1)
		local D = SIZE + 4 + 26 * K * math.clamp(Age / 0.25, 0, 1)
		Ring.Size = UDim2.fromOffset(D, D)
		local Fading = 0.15 + 0.85 * (Age / FADE) -- as the old ring's stroke
		Ring.ImageTransparency = 1 - (1 - Fading) * (0.45 + 0.55 * K) -- a louder sound shows brighter
	else
		Ring.ImageTransparency = 1
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

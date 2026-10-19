-- Interact prompts in Rensei's own art, replacing Roblox's default grey prompt for every
-- ProximityPrompt whose Style is Custom (the NPC Talk prompt -- DialogueService sets it).
-- The key sits on the hotbar slot plate with the transmutation circle behind it, like the alchemy
-- slots (AlchemyUI); beside it the object's name and the action in the Guru lettering of the enemy
-- name plates (Templates.NpcTemplate), over that plate's ornate bar. Pops in when shown, pulses
-- like a pressed slot when triggered, fills while a hold prompt is held, and can be clicked or
-- tapped. Display only: the prompt itself still fires Triggered as usual.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer

local SLOT_IMAGE = "rbxassetid://108980512067469" -- Rensei hotbar slot plate
local CIRCLE_IMAGE = "rbxassetid://132299053523633" -- Rensei transmutation circle
local PLATE_IMAGE = "rbxassetid://79200490823213" -- enemy name plate (Templates.NpcTemplate)
local FONT = Font.new("rbxasset://fonts/families/Guru.json", Enum.FontWeight.Bold)
local TEXT_COLOR = Color3.fromRGB(240, 230, 215)
local STROKE_COLOR = Color3.fromRGB(15, 10, 8)
-- the name plates' silver sheen
local SHEEN = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(182, 182, 182)),
	ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
})
local GAMEPAD_NAMES = {ButtonA = "A", ButtonB = "B", ButtonX = "X", ButtonY = "Y", ButtonL1 = "LB", ButtonR1 = "RB"}

local PromptUI = {}

local function Label(Name, Parent, Props)
	local L = Instance.new("TextLabel")
	L.Name = Name
	L.BackgroundTransparency = 1
	L.FontFace = FONT
	L.TextScaled = true
	L.TextColor3 = TEXT_COLOR
	local Stroke = Instance.new("UIStroke")
	Stroke.Thickness = 1.5
	Stroke.Color = STROKE_COLOR
	Stroke.Parent = L
	local Sheen = Instance.new("UIGradient")
	Sheen.Color = SHEEN
	Sheen.Rotation = 90
	Sheen.Parent = L
	for K, V in pairs(Props) do L[K] = V end
	L.Parent = Parent
	return L
end

local function KeyText(Prompt, InputType)
	if InputType == Enum.ProximityPromptInputType.Touch then return "TAP" end
	if InputType == Enum.ProximityPromptInputType.Gamepad then
		local Name = Prompt.GamepadKeyCode.Name
		return GAMEPAD_NAMES[Name] or Name:gsub("^Button", "")
	end
	local Ok, Text = pcall(UserInputService.GetStringForKeyCode, UserInputService, Prompt.KeyboardKeyCode)
	return (Ok and Text ~= "") and Text:upper() or Prompt.KeyboardKeyCode.Name
end

-- Builds the prompt's billboard; returns a function that removes it.
local function Build(Prompt, InputType)
	local Viewport = workspace.CurrentCamera.ViewportSize
	local H = math.clamp(math.floor(Viewport.Y * 0.06), 42, 76) -- height in pixels, scales with the screen
	local W = math.floor(H * 4.4)
	local Connections = {}

	local Gui = Instance.new("BillboardGui")
	Gui.Name = "RenseiPrompt"
	Gui.AlwaysOnTop = true
	Gui.LightInfluence = 0
	Gui.Active = true
	Gui.ResetOnSpawn = false
	Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	Gui.Size = UDim2.fromOffset(W, H)
	Gui.StudsOffset = Vector3.new(0, 3.4, 0) -- over the head of a character's root part
	Gui.Adornee = Prompt.Parent

	local Holder = Instance.new("CanvasGroup")
	Holder.Name = "Holder"
	Holder.BackgroundTransparency = 1
	Holder.Size = UDim2.fromScale(1, 1)
	Holder.GroupTransparency = 1
	Holder.Parent = Gui
	local Scale = Instance.new("UIScale")
	Scale.Scale = 0.8
	Scale.Parent = Holder

	-- the key: slot plate + transmutation circle, like the alchemy slots
	local Slot = Instance.new("ImageLabel")
	Slot.Name = "Key"
	Slot.BackgroundTransparency = 1
	Slot.Image = SLOT_IMAGE
	Slot.Size = UDim2.fromOffset(H, H)
	Slot.ZIndex = 2
	Slot.Parent = Holder
	local Circle = Instance.new("ImageLabel")
	Circle.Name = "Circle"
	Circle.BackgroundTransparency = 1
	Circle.Image = CIRCLE_IMAGE
	Circle.ImageTransparency = 0.55
	Circle.AnchorPoint = Vector2.new(0.5, 0.5)
	Circle.Position = UDim2.fromScale(0.5, 0.5)
	Circle.Size = UDim2.fromScale(0.78, 0.78)
	Circle.ZIndex = 2
	Circle.Parent = Slot
	local Spin = TweenService:Create(Circle, TweenInfo.new(14, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), {Rotation = 360})
	Spin:Play()
	-- hold prompts: a dark plate rises inside the slot while the key is held
	local Fill = Instance.new("Frame")
	Fill.Name = "Hold"
	Fill.BackgroundColor3 = Color3.fromRGB(10, 6, 6)
	Fill.BackgroundTransparency = 0.3
	Fill.BorderSizePixel = 0
	Fill.AnchorPoint = Vector2.new(0.5, 1)
	Fill.Position = UDim2.fromScale(0.5, 0.9)
	Fill.Size = UDim2.fromScale(0.8, 0)
	Fill.ZIndex = 3
	Fill.Parent = Slot
	local Key = KeyText(Prompt, InputType)
	Label("KeyText", Slot, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromScale(#Key > 1 and 0.62 or 0.45, 0.42), Text = Key, ZIndex = 4,
	})

	-- the name plate bar the text sits on
	local Left = math.floor(H * 0.92)
	local Plate = Instance.new("ImageLabel")
	Plate.Name = "Plate"
	Plate.BackgroundTransparency = 1
	Plate.Image = PLATE_IMAGE
	Plate.ScaleType = Enum.ScaleType.Fit
	Plate.AnchorPoint = Vector2.new(0, 0.5)
	Plate.Position = UDim2.new(0, Left - math.floor(H * 0.12), 0.8, 0)
	Plate.Size = UDim2.fromOffset(W - Left + math.floor(H * 0.12), math.floor(H * 0.26))
	Plate.Parent = Holder

	local HasObject = Prompt.ObjectText ~= ""
	local Object = Label("ObjectText", Holder, {
		Position = UDim2.fromOffset(Left, math.floor(H * 0.06)), Size = UDim2.fromOffset(W - Left, math.floor(H * 0.28)),
		TextXAlignment = Enum.TextXAlignment.Left, Text = Prompt.ObjectText, TextColor3 = Color3.fromRGB(200, 190, 175),
		Visible = HasObject, ZIndex = 2,
	})
	local Action = Label("ActionText", Holder, {
		Position = UDim2.fromOffset(Left, math.floor(H * (HasObject and 0.3 or 0.18))), Size = UDim2.fromOffset(W - Left, math.floor(H * 0.44)),
		TextXAlignment = Enum.TextXAlignment.Left, Text = Prompt.ActionText, ZIndex = 2,
	})
	table.insert(Connections, Prompt:GetPropertyChangedSignal("ActionText"):Connect(function() Action.Text = Prompt.ActionText end))
	table.insert(Connections, Prompt:GetPropertyChangedSignal("ObjectText"):Connect(function() Object.Text = Prompt.ObjectText end))

	-- click / tap the prompt to use it. Not in Combat Mode: there a click is an attack (like E, which toggles
	-- Combat Mode instead of interacting), so M1s in a fight never pull levers or open chests (2026-10-18).
	if Prompt.ClickablePrompt then
		local Button = Instance.new("TextButton")
		Button.Name = "Click"
		Button.Text = ""
		Button.BackgroundTransparency = 1
		Button.Size = UDim2.fromScale(1, 1)
		Button.ZIndex = 10
		Button.Parent = Gui
		local Holding = false
		table.insert(Connections, Button.InputBegan:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				if Player.Character and Player.Character:GetAttribute("CombatMode") == true then return end
				Holding = true
				Prompt:InputHoldBegin()
			end
		end))
		local function Release()
			if Holding then Holding = false Prompt:InputHoldEnd() end
		end
		table.insert(Connections, Button.InputEnded:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then Release() end
		end))
		table.insert(Connections, Button.MouseLeave:Connect(Release))
	end

	-- hold progress
	local HoldTween
	table.insert(Connections, Prompt.PromptButtonHoldBegan:Connect(function()
		if Prompt.HoldDuration <= 0 then return end
		Fill.Size = UDim2.fromScale(0.8, 0)
		HoldTween = TweenService:Create(Fill, TweenInfo.new(Prompt.HoldDuration, Enum.EasingStyle.Linear), {Size = UDim2.fromScale(0.8, 0.8)})
		HoldTween:Play()
	end))
	table.insert(Connections, Prompt.PromptButtonHoldEnded:Connect(function()
		if HoldTween then HoldTween:Cancel() HoldTween = nil end
		TweenService:Create(Fill, TweenInfo.new(0.15), {Size = UDim2.fromScale(0.8, 0)}):Play()
	end))

	-- used: the slot plate grows out and fades (AlchemyUI's pressed-slot pulse)
	table.insert(Connections, Prompt.Triggered:Connect(function()
		local Eff = Instance.new("ImageLabel")
		Eff.BackgroundTransparency = 1
		Eff.Image = SLOT_IMAGE
		Eff.ImageTransparency = 0.3
		Eff.AnchorPoint = Vector2.new(0.5, 0.5)
		Eff.Position = UDim2.fromScale(0.5, 0.5)
		Eff.Size = UDim2.fromScale(1, 1)
		Eff.ZIndex = 5
		Eff.Parent = Slot
		TweenService:Create(Eff, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = UDim2.fromScale(1.4, 1.4)}):Play()
		TweenService:Create(Eff, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {ImageTransparency = 1}):Play()
		task.delay(0.5, Eff.Destroy, Eff)
	end))

	Gui.Parent = Player:WaitForChild("PlayerGui")
	TweenService:Create(Holder, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {GroupTransparency = 0}):Play()
	TweenService:Create(Scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()

	return function()
		for _, C in ipairs(Connections) do C:Disconnect() end
		Spin:Cancel()
		TweenService:Create(Holder, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {GroupTransparency = 1}):Play()
		TweenService:Create(Scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.85}):Play()
		task.delay(0.13, Gui.Destroy, Gui)
	end
end

function PromptUI.Start()
	ProximityPromptService.PromptShown:Connect(function(Prompt, InputType)
		if Prompt.Style ~= Enum.ProximityPromptStyle.Custom then return end
		local Remove = Build(Prompt, InputType)
		Prompt.PromptHidden:Wait()
		Remove()
	end)
end

return PromptUI

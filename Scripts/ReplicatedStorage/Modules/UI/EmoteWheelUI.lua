-- EmoteWheelUI: the alchemical emote wheel. Hold H (Rensei.Emotes.Key), point at an emote and let
-- go to perform it; or tap H to leave the wheel open and click a name (H again or right click
-- closes it). The mouse wheel turns to the next ring of emotes. On touch, the Emote button opens
-- it and a tap on a name performs it (tap the centre to close). The wheel is the game's transmutation circle; the server checks
-- every emote (Requests.Emote). Moving, jumping, attacking or Combat Mode ends a running emote.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UIState = require(script.Parent.UIState)
local Emotes = require(ReplicatedStorage.Modules.Data.Rensei.Emotes)
local AnimationManager = require(ReplicatedStorage.Modules.Managers.AnimationManager)

local CIRCLE = "rbxassetid://132299053523633" -- the game's transmutation circle texture
local GOLD = Color3.fromRGB(230, 205, 120)
local PALE = Color3.fromRGB(215, 205, 185)
local RED = Color3.fromRGB(230, 120, 110)
local FONT = Font.new("rbxasset://fonts/families/Guru.json", Enum.FontWeight.Bold)
local SLOTS = 8
local RADIUS = 0.37 -- slot distance from the centre, as a share of the wheel
local DEAD_ZONE = 0.12 -- pointing closer to the centre than this selects nothing

local Player = Players.LocalPlayer
local EmoteWheelUI = {}

local Root, Scale, Ring, Pointer, Slots, Title, NameLabel, Hint, Dots
local IsOpen, Mode, Page, Hover = false, nil, 1, nil
local OpenedAt = 0
local TAP_TIME = 0.3 -- a shorter press of H leaves the wheel open for clicking
local SavedMouse, SavedIcon

local function Make(Class, Props, Parent)
	local O = Instance.new(Class)
	for K, V in pairs(Props) do O[K] = V end
	O.Parent = Parent
	return O
end

local function Text(Parent, T, Pos, Size, Color, Max)
	local L = Make("TextLabel", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = Pos, Size = Size,
		FontFace = FONT, Text = T, TextColor3 = Color or PALE, TextScaled = true, TextWrapped = true}, Parent)
	Make("UIStroke", {Thickness = 1.2, Transparency = 0.35}, L)
	Make("UITextSizeConstraint", {MaxTextSize = Max or 20}, L)
	return L
end

local function Blocked()
	return Emotes.Blocked(Player.Character)
end

local function Fill()
	local Def = Emotes.Pages[Page]
	Title.Text = string.upper(Def.Name)
	for I, S in ipairs(Slots) do
		local Id = Def.Emotes[I]
		S.Id = Id
		S.Button.Visible = Id ~= nil
		S.Label.Text = Id and Emotes.List[Id].Name or ""
	end
	for I, D in ipairs(Dots) do D.BackgroundColor3 = I == Page and GOLD or Color3.fromRGB(90, 80, 60) end
end

local function SetHover(Index)
	if Index == Hover then return end
	Hover = Index
	for I, S in ipairs(Slots) do
		local On = I == Index and S.Id ~= nil
		S.Label.TextColor3 = On and GOLD or PALE
		TweenService:Create(S.Scale, TweenInfo.new(0.12), {Scale = On and 1.18 or 1}):Play()
		S.Node.BackgroundColor3 = On and GOLD or Color3.fromRGB(120, 105, 75)
	end
	local Id = Index and Slots[Index].Id
	Pointer.Visible = Id ~= nil
	if Id then
		local Goal = (Index - 1) * (360 / SLOTS)
		local Now = Pointer.Rotation
		TweenService:Create(Pointer, TweenInfo.new(0.1), {Rotation = Now + ((Goal - Now + 180) % 360 - 180)}):Play()
	end
	local Why = Blocked()
	if Why then
		NameLabel.Text, NameLabel.TextColor3 = Why ~= "" and Why or "Not now", RED
	else
		NameLabel.Text, NameLabel.TextColor3 = Id and Emotes.List[Id].Name or "", GOLD
	end
end

local function Close()
	if not IsOpen then return end
	IsOpen, Mode = false, nil
	SetHover(nil)
	TweenService:Create(Scale, TweenInfo.new(0.12), {Scale = 0.85}):Play()
	TweenService:Create(Root, TweenInfo.new(0.12), {GroupTransparency = 1}):Play()
	task.delay(0.12, function() if not IsOpen then Root.Visible = false end end)
	if SavedMouse then UserInputService.MouseBehavior = SavedMouse end
	if SavedIcon ~= nil then UserInputService.MouseIconEnabled = SavedIcon end
	SavedMouse, SavedIcon = nil, nil
end

local function Perform(Id)
	if not Id or not Emotes.List[Id] then return end
	if Blocked() then return end
	UIState.Request("Emote", "Play", Id)
end

local function Open(NewMode)
	if IsOpen then return end
	-- not over a menu, the dialogue box or a minigame
	if UIState.Gui:FindFirstChild("bg") and UIState.Gui.bg.Visible then return end
	if UIState.Gui:FindFirstChild("Dialogue") and UIState.Gui.Dialogue.Visible then return end
	IsOpen, Mode, Hover = true, NewMode, nil
	Fill()
	SetHover(nil)
	OpenedAt = os.clock()
	Hint.Text = Mode == "Tap" and "Tap an emote. Tap here to close." or "Point and release H, or click. Scroll for more."
	Root.Visible = true
	Root.GroupTransparency = 1
	Scale.Scale = 0.85
	TweenService:Create(Scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), {Scale = 1}):Play()
	TweenService:Create(Root, TweenInfo.new(0.15), {GroupTransparency = 0}):Play()
	-- a free cursor while the wheel is up (shift lock / first person lock it to the centre)
	SavedMouse, SavedIcon = UserInputService.MouseBehavior, UserInputService.MouseIconEnabled
	UserInputService.MouseIconEnabled = true
end

local function Build()
	Root = Make("CanvasGroup", {Name = "EmoteWheel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Visible = false, ZIndex = 40}, UIState.Gui)
	Make("UIAspectRatioConstraint", {AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height}, Root)
	Scale = Make("UIScale", {}, Root)
	local Disc = Make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.98, 0.98),
		BackgroundColor3 = Color3.fromRGB(16, 13, 11), BackgroundTransparency = 0.18}, Root)
	Make("UICorner", {CornerRadius = UDim.new(1, 0)}, Disc)
	Make("UIStroke", {Color = Color3.fromRGB(150, 125, 75), Thickness = 2, Transparency = 0.2}, Disc)
	Ring = Make("ImageLabel", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.9),
		BackgroundTransparency = 1, Image = CIRCLE, ImageColor3 = Color3.fromRGB(170, 140, 80), ImageTransparency = 0.55}, Root)
	-- the pointer: a chalk line from the centre to the chosen emote
	Pointer = Make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, Visible = false}, Root)
	Make("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 3, RADIUS - 0.06, 0),
		BackgroundColor3 = GOLD, BackgroundTransparency = 0.15, BorderSizePixel = 0}, Pointer)
	Slots = {}
	for I = 1, SLOTS do
		local A = math.rad((I - 1) * 360 / SLOTS)
		local Pos = UDim2.fromScale(0.5 + math.sin(A) * RADIUS, 0.5 - math.cos(A) * RADIUS)
		-- a node on the circle where the chalk line meets it
		local Node = Make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5 + math.sin(A) * (RADIUS - 0.075), 0.5 - math.cos(A) * (RADIUS - 0.075)),
			Size = UDim2.fromScale(0.022, 0.022), Rotation = 45, BackgroundColor3 = Color3.fromRGB(120, 105, 75), BorderSizePixel = 0}, Root)
		local Button = Make("TextButton", {Name = "Slot" .. I, AnchorPoint = Vector2.new(0.5, 0.5), Position = Pos, Size = UDim2.fromScale(0.24, 0.1),
			BackgroundTransparency = 1, Text = "", AutoButtonColor = false}, Root)
		local Label = Text(Button, "", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), PALE, 22)
		local S = {Button = Button, Label = Label, Node = Node, Scale = Make("UIScale", {}, Button)}
		Slots[I] = S
		Button.MouseEnter:Connect(function() if IsOpen then SetHover(I) end end)
		Button.Activated:Connect(function()
			if not IsOpen or not S.Id or Mode == "Click" then return end -- desktop clicks: see InputBegan
			Perform(S.Id)
			Close()
		end)
	end
	-- the centre plate
	local Plate = Make("TextButton", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.36, 0.36),
		BackgroundColor3 = Color3.fromRGB(24, 20, 16), BackgroundTransparency = 0.1, Text = "", AutoButtonColor = false}, Root)
	Make("UICorner", {CornerRadius = UDim.new(1, 0)}, Plate)
	Make("UIStroke", {Color = GOLD, Thickness = 1.5, Transparency = 0.3}, Plate)
	Plate.Activated:Connect(function() if Mode == "Tap" then Close() end end)
	Title = Text(Plate, "", UDim2.fromScale(0.5, 0.25), UDim2.fromScale(0.8, 0.14), Color3.fromRGB(170, 150, 105), 16)
	NameLabel = Text(Plate, "", UDim2.fromScale(0.5, 0.48), UDim2.fromScale(0.85, 0.24), GOLD, 30)
	Hint = Text(Plate, "", UDim2.fromScale(0.5, 0.7), UDim2.fromScale(0.82, 0.14), Color3.fromRGB(150, 140, 120), 12)
	Dots = {}
	for I = 1, #Emotes.Pages do
		local X = 0.5 + (I - (#Emotes.Pages + 1) / 2) * 0.09
		local D = Make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(X, 0.86), Size = UDim2.fromScale(0.05, 0.05),
			BackgroundColor3 = GOLD, BorderSizePixel = 0}, Plate)
		Make("UICorner", {CornerRadius = UDim.new(1, 0)}, D)
		Dots[I] = D
	end
end

function EmoteWheelUI.Start()
	Build()

	-- H: hold to open (desktop); the touch button toggles it
	ContextActionService:BindAction("RenseiEmoteWheel", function(_, State, Input)
		local Touch = Input and Input.UserInputType == Enum.UserInputType.Touch
		if State == Enum.UserInputState.Begin then
			if IsOpen then
				Close() -- H (or the button) again closes an open wheel
			else
				Open(Touch and "Tap" or "Hold")
			end
		elseif State == Enum.UserInputState.End and Mode == "Hold" then
			local Id = Hover and Slots[Hover].Id
			if os.clock() - OpenedAt < TAP_TIME then
				Mode = "Click" -- a quick tap never performs: stay open, click a name
			elseif Id then
				Close()
				Perform(Id)
			else
				Close()
			end
		end
		return Enum.ContextActionResult.Sink
	end, true, Emotes.Key)
	ContextActionService:SetTitle("RenseiEmoteWheel", "Emote")
	ContextActionService:SetPosition("RenseiEmoteWheel", UDim2.new(1, -318, 0, 10))

	UserInputService.InputChanged:Connect(function(Input)
		if IsOpen and Input.UserInputType == Enum.UserInputType.MouseWheel then
			Page = (Page - 1 + (Input.Position.Z < 0 and 1 or -1)) % #Emotes.Pages + 1
			Fill()
			local H = Hover
			Hover = nil
			SetHover(H)
		end
	end)
	UserInputService.InputBegan:Connect(function(Input)
		if not IsOpen then return end
		if Input.UserInputType == Enum.UserInputType.MouseButton2 then
			Close()
		elseif Input.UserInputType == Enum.UserInputType.MouseButton1 and Mode ~= "Tap" then
			-- a click picks the emote the pointer is on (anywhere in its direction, not just its name)
			local Id = Hover and Slots[Hover].Id
			if Id then
				Close()
				Perform(Id)
			end
		end
	end)

	local Running, RunningSince, Asked = nil, 0, false
	RunService.RenderStepped:Connect(function(Dt)
		if IsOpen then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			Ring.Rotation = (Ring.Rotation + Dt * 6) % 360
			if Player.Character and Player.Character:GetAttribute("CombatMode") then Close() end
			if Mode == "Hold" or Mode == "Click" then
				-- point with the mouse: the direction from the wheel's centre picks the slot
				local Mouse = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
				local Centre = Root.AbsolutePosition + Root.AbsoluteSize / 2
				local D = Mouse - Centre
				if D.Magnitude < Root.AbsoluteSize.Y * DEAD_ZONE then
					SetHover(nil)
				else
					local Angle = math.deg(math.atan2(D.X, -D.Y)) % 360
					SetHover(math.floor((Angle + 180 / SLOTS) % 360 / (360 / SLOTS)) + 1)
				end
			end
		end
		-- a running emote ends when you move, jump, attack or enter Combat Mode (or a one-shot ends)
		local Character = Player.Character
		local Id = Character and Character:GetAttribute("Emote")
		if Id ~= Running then Running, RunningSince, Asked = Id, os.clock(), false end
		local Def = Id and Emotes.List[Id]
		if Def and not Asked then
			local Humanoid = Character:FindFirstChildOfClass("Humanoid")
			local Moving = Humanoid and (Humanoid.MoveDirection.Magnitude > 0.1 or Humanoid.Jump or Humanoid.FloorMaterial == Enum.Material.Air)
			local Busy = Character:GetAttribute("CombatMode") or Character:GetAttribute("CombatState") ~= nil or Character:GetAttribute("Knocked")
			local Done = false
			if not Def.Looped and os.clock() - RunningSince > 0.5 then
				Done = true
				for _, T in ipairs(AnimationManager.GetPlayingAnims(Character)) do
					if T.Name == Def.Anim then Done = false end
				end
			end
			if Moving or Busy or Done then
				Asked = true
				AnimationManager.Stop(Character, Def.Anim) -- at once here; the server clears the attribute
				UIState.Request("Emote", "Stop")
			end
		end
	end)
end

return EmoteWheelUI

-- EmoteWheelUI: the alchemical emote wheel. Hold H (Rensei.Emotes.Key), point at an emote and let
-- go to perform it; or tap H to leave the wheel open and click a name (H again or right click
-- closes it). The mouse wheel turns to the next ring of emotes. On touch, the Emote button opens
-- it and a tap on a name performs it (tap the centre to close). The wheel is the game's transmutation circle; the server checks
-- every emote (Requests.Emote). Moving, jumping, attacking or Combat Mode ends a running emote.
-- (hostages plan Task 12, 2026-10-28; spec section 3 "a radial built from the existing emote wheel art"; pre-flight P7)
-- MENU MODE: EmoteWheelUI.Menu(Title, Items, OnPick) opens the same wheel (its own drawing code, no new art) with Items
-- ({Id, Text, Locked, Why}, at most 8, spread evenly round the circle) in its slots, the Title on the centre plate.
--   * A locked item is greyed as DialogueUI greys a locked choice (its text at 0.55 transparency); hovering it shows its
--     Why in red, and picking it does nothing. An open item shows its Text in gold. Emotes.Blocked is never asked (after
--     hostages Task 10 it says "Your hands are full" for every captor), there is no Combat Mode auto-close (a captor
--     fighting with light attacks is in Combat Mode) and no mouse-wheel paging.
--   * Desktop: point and click (as the emote wheel's click mode); touch (the last input was a touch, or the touch
--     controls show): tap an item. A pick closes the wheel, then calls OnPick(Id).
--   * Esc, a right click, or the centre plate on touch close it with OnPick(nil); the caller's own key (HostageUI's)
--     closes it through EmoteWheelUI.CloseMenu(), also OnPick(nil). H toggles only the emote wheel: it does nothing while
--     a menu is open. A new Menu over an open one replaces it (the old one's OnPick(nil) first).
--   * EmoteWheelUI.MenuOpen() -> nil, or {Title, Items = {{Id, Text, Locked, Slot}}, Hover, HoverRed} (the client checks
--     read it).

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
local Menu = nil -- (hostages Task 12) the open menu: {Title, Items, OnPick}, or nil (the emote wheel)
local MENU_GREY = 0.55 -- a locked item's text transparency (DialogueUI's locked choice)

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

-- (Task 12) the slot each of N menu items sits in: spread evenly round the circle from the top
local function MenuSlots(N)
	local Out = {}
	local Step = math.max(1, math.floor(SLOTS / math.max(N, 1)))
	for I = 1, math.min(N, SLOTS) do Out[1 + (I - 1) * Step] = I end
	return Out
end

local function Fill()
	if Menu then
		Title.Text = string.upper(Menu.Title)
		local At = MenuSlots(#Menu.Items)
		for I, S in ipairs(Slots) do
			local Item = At[I] and Menu.Items[At[I]]
			S.Id, S.Item = Item and Item.Id, Item
			S.Button.Visible = Item ~= nil
			S.Label.Text = Item and tostring(Item.Text) or ""
			S.Label.TextTransparency = Item and Item.Locked and MENU_GREY or 0
		end
		for _, D in ipairs(Dots) do D.Visible = false end
		return
	end
	local Def = Emotes.Pages[Page]
	Title.Text = string.upper(Def.Name)
	for I, S in ipairs(Slots) do
		local Id = Def.Emotes[I]
		S.Id, S.Item = Id, nil
		S.Button.Visible = Id ~= nil
		S.Label.Text = Id and Emotes.List[Id].Name or ""
		S.Label.TextTransparency = 0
	end
	for I, D in ipairs(Dots) do
		D.Visible = true
		D.BackgroundColor3 = I == Page and GOLD or Color3.fromRGB(90, 80, 60)
	end
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
	if Menu then
		-- (Task 12, P7) the item's own text, or a locked item's reason; never Emotes.Blocked
		local Item = Index and Slots[Index].Item
		if Item and Item.Locked then
			NameLabel.Text, NameLabel.TextColor3 = tostring(Item.Why or "Not now"), RED
		else
			NameLabel.Text, NameLabel.TextColor3 = Item and tostring(Item.Text) or "", GOLD
		end
		return
	end
	local Why = Blocked()
	if Why then
		NameLabel.Text, NameLabel.TextColor3 = Why ~= "" and Why or "Not now", RED
	else
		NameLabel.Text, NameLabel.TextColor3 = Id and Emotes.List[Id].Name or "", GOLD
	end
end

-- (Task 12) Picked: a menu item's Id (or nil); the menu's OnPick is called with it once the wheel has closed
local function Close(Picked)
	if not IsOpen then return end
	local Was = Menu
	IsOpen, Mode = false, nil
	SetHover(nil)
	Menu = nil
	TweenService:Create(Scale, TweenInfo.new(0.12), {Scale = 0.85}):Play()
	TweenService:Create(Root, TweenInfo.new(0.12), {GroupTransparency = 1}):Play()
	task.delay(0.12, function() if not IsOpen then Root.Visible = false end end)
	if SavedMouse then UserInputService.MouseBehavior = SavedMouse end
	if SavedIcon ~= nil then UserInputService.MouseIconEnabled = SavedIcon end
	SavedMouse, SavedIcon = nil, nil
	if Was and Was.OnPick then task.spawn(Was.OnPick, Picked) end
end

local function Perform(Id)
	if not Id or not Emotes.List[Id] then return end
	if Blocked() then return end
	UIState.Request("Emote", "Play", Id)
end

-- (Task 12) the slot under the pointer (or tapped) was chosen: a menu item is picked (a locked one does nothing), an
-- emote performed
local function Choose(Index)
	local S = Index and Slots[Index]
	if not S or not S.Id then return end
	if Menu then
		if S.Item and not S.Item.Locked then Close(S.Item.Id) end
		return
	end
	local Id = S.Id
	Close()
	Perform(Id)
end

local function Open(NewMode, NewMenu)
	if IsOpen then return false end
	-- not over a menu, the dialogue box or a minigame
	if UIState.Gui:FindFirstChild("bg") and UIState.Gui.bg.Visible then return false end
	if UIState.Gui:FindFirstChild("Dialogue") and UIState.Gui.Dialogue.Visible then return false end
	IsOpen, Mode, Hover, Menu = true, NewMode, nil, NewMenu
	Fill()
	SetHover(nil)
	OpenedAt = os.clock()
	if Menu then
		Hint.Text = Mode == "Tap" and "Tap a choice. Tap here to close." or "Click a choice. Right click or Esc closes."
	else
		Hint.Text = Mode == "Tap" and "Tap an emote. Tap here to close." or "Point and release H, or click. Scroll for more."
	end
	Root.Visible = true
	Root.GroupTransparency = 1
	Scale.Scale = 0.85
	TweenService:Create(Scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), {Scale = 1}):Play()
	TweenService:Create(Root, TweenInfo.new(0.15), {GroupTransparency = 0}):Play()
	-- a free cursor while the wheel is up (shift lock / first person lock it to the centre)
	SavedMouse, SavedIcon = UserInputService.MouseBehavior, UserInputService.MouseIconEnabled
	UserInputService.MouseIconEnabled = true
	return true
end

-- (Task 12) the wheel as a menu (see MENU MODE in the header); false when it can't open now (a menu, the dialogue box)
function EmoteWheelUI.Menu(TitleText, Items, OnPick)
	if IsOpen then Close() end -- (an open menu's OnPick(nil); an open emote wheel just closes)
	local Touch = UserInputService:GetLastInputType() == Enum.UserInputType.Touch or Player:GetAttribute("MobileControls") == true
	local List = {}
	for _, It in ipairs(type(Items) == "table" and Items or {}) do
		if type(It) == "table" and It.Id ~= nil then
			table.insert(List, {Id = It.Id, Text = It.Text or tostring(It.Id), Locked = It.Locked == true, Why = It.Why})
		end
	end
	return Open(Touch and "Tap" or "Click", {Title = tostring(TitleText or ""), Items = List, OnPick = OnPick})
end

-- (Task 12) an open menu closed, its OnPick(nil); nothing when the wheel shows emotes or is shut
function EmoteWheelUI.CloseMenu()
	if IsOpen and Menu then Close() end
end

-- (Task 12) the open menu, for the client checks: nil, or {Title, Items = {{Id, Text, Locked, Slot}}, Hover (the centre
-- plate's text now), HoverRed (shown as a refusal)}
function EmoteWheelUI.MenuOpen()
	if not (IsOpen and Menu) then return nil end
	local Out = {Title = Menu.Title, Items = {}, Hover = NameLabel.Text, HoverRed = NameLabel.TextColor3 == RED}
	for I, S in ipairs(Slots) do
		if S.Item then table.insert(Out.Items, {Id = S.Item.Id, Text = S.Item.Text, Locked = S.Item.Locked, Slot = I}) end
	end
	return Out
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
			Choose(I)
		end)
	end
	-- the centre plate
	local Plate = Make("TextButton", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.36, 0.36),
		BackgroundColor3 = Color3.fromRGB(24, 20, 16), BackgroundTransparency = 0.1, Text = "", AutoButtonColor = false}, Root)
	Make("UICorner", {CornerRadius = UDim.new(1, 0)}, Plate)
	Make("UIStroke", {Color = GOLD, Thickness = 1.5, Transparency = 0.3}, Plate)
	Plate.Activated:Connect(function() if Mode == "Tap" then Close() end end) -- (a menu: OnPick(nil))
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
			if Menu then
				-- (Task 12, P7) H toggles only the emote wheel: an open menu stays
			elseif IsOpen then
				Close() -- H (or the button) again closes an open wheel
			else
				Open(Touch and "Tap" or "Hold")
			end
		elseif State == Enum.UserInputState.End and Mode == "Hold" and not Menu then
			local Id = Hover and Slots[Hover].Id
			if os.clock() - OpenedAt < TAP_TIME then
				Mode = "Click" -- a quick tap never performs: stay open, click a name
			elseif Id then
				Choose(Hover)
			else
				Close()
			end
		end
		return Enum.ContextActionResult.Sink
	end, true, Emotes.Key)
	ContextActionService:SetTitle("RenseiEmoteWheel", "Emote")
	ContextActionService:SetPosition("RenseiEmoteWheel", UDim2.new(1, -318, 0, 10))

	UserInputService.InputChanged:Connect(function(Input)
		if IsOpen and not Menu and Input.UserInputType == Enum.UserInputType.MouseWheel then
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
		elseif Input.KeyCode == Enum.KeyCode.Escape and Menu then
			Close() -- (Task 12) Esc closes a menu
		elseif Input.UserInputType == Enum.UserInputType.MouseButton1 and Mode ~= "Tap" then
			-- a click picks the emote (or menu item) the pointer is on (anywhere in its direction, not just its name)
			Choose(Hover)
		end
	end)

	local Running, RunningSince, Asked = nil, 0, false
	RunService.RenderStepped:Connect(function(Dt)
		if IsOpen then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			Ring.Rotation = (Ring.Rotation + Dt * 6) % 360
			if not Menu and Player.Character and Player.Character:GetAttribute("CombatMode") then Close() end -- (P7: not a menu)
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

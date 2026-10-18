-- CombatLogUI (owner 2026-10-15): a combat-log badge that drops in at the top of the screen while
-- you're in combat: who hit you, and a countdown until you're out of combat (combat-logging
-- before it runs out is what it warns about).
-- Server side: WorldService.MarkCombat sets the character attributes
--   CombatUntil (server time the lock ends), CombatBy (last attacker), CombatVs (last target),
--   CombatHitAt (server time of the last hit taken), InCombat.
-- The icon is the white Truth figure with black arms, drawn from UI shapes on a transparent
-- background. To use an uploaded image instead, set ICON_IMAGE to its rbxassetid.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer

local ICON_IMAGE = "rbxassetid://126283390796835" -- Truth painting, background cut out; e.g. "rbxassetid://123" (transparent PNG); empty = the drawn Truth icon
local COMBAT_SECONDS = 12 -- WorldService COMBAT_SECONDS (bar scale only; the deadline comes from the server)

local RED = Color3.fromRGB(214, 58, 52)
local SAFE = Color3.fromRGB(96, 200, 120)
local FONT = Font.new("rbxasset://fonts/families/Guru.json", Enum.FontWeight.Bold)

local CombatLogUI = {}

-- the badge drops in just under the compass strip (CompassUI: top 6, 32 tall), or to the very top without it
-- (a boss fight: under the boss bar instead, HUDUI's BossBarBottom; this ScreenGui ignores the inset)
local function TopY()
	local Y = Player:GetAttribute("ShowCompass") == false and 12 or 42
	local Boss = Player:GetAttribute("BossBarBottom")
	return Boss and math.max(Y, Boss + 6) or Y
end

local function Make(Class, Props, Parent)
	local O = Instance.new(Class)
	for K, V in pairs(Props) do O[K] = V end
	O.Parent = Parent
	return O
end
local function Round(O, R) Make("UICorner", {CornerRadius = R or UDim.new(1, 0)}, O) return O end
local function Tween(O, T, Goal, Style, Dir)
	local X = TweenService:Create(O, TweenInfo.new(T, Style or Enum.EasingStyle.Quad, Dir or Enum.EasingDirection.Out), Goal)
	X:Play()
	return X
end

-- ===== the Truth icon: white figure, huge grin, black arms; no background =====
local function Shape(Parent, Color, X, Y, W, H, Rot, Radius, Stroke, Z)
	local F = Make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(X, Y), Size = UDim2.fromScale(W, H),
		Rotation = Rot or 0, BackgroundColor3 = Color, BorderSizePixel = 0, ZIndex = Z or 1,
	}, Parent)
	Round(F, Radius)
	if Stroke then Make("UIStroke", {Color = Color3.new(0, 0, 0), Thickness = Stroke, Transparency = 0.15}, F) end
	return F
end

local function DrawTruth(Parent)
	local Holder = Make("Frame", {Name = "Truth", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1)}, Parent)
	local White = Color3.fromRGB(250, 250, 248)
	local Black = Color3.fromRGB(12, 12, 14)
	-- body: legs folded (seated) at the back, torso, head on top
	Shape(Holder, White, 0.5, 0.9, 0.6, 0.16, 0, UDim.new(0.5, 0), 1.5, 1)
	Shape(Holder, White, 0.5, 0.68, 0.36, 0.36, 0, UDim.new(0.35, 0), 1.5, 3)
	local Head = Shape(Holder, White, 0.5, 0.31, 0.46, 0.46, 0, nil, 1.5, 4)
	-- black arms over the legs, out from the shoulders and down to splayed hands
	local Arms = {}
	for _, Side in ipairs({-1, 1}) do
		local Upper = Shape(Holder, Black, 0.5 + Side * 0.26, 0.64, 0.11, 0.34, Side * -52, UDim.new(0.5, 0), nil, 2)
		local Fore = Shape(Holder, Black, 0.5 + Side * 0.41, 0.82, 0.1, 0.26, Side * 12, UDim.new(0.5, 0), nil, 2)
		local Hand = Shape(Holder, Black, 0.5 + Side * 0.43, 0.95, 0.17, 0.11, 0, nil, nil, 2)
		table.insert(Arms, {Upper, Fore, Hand})
	end
	-- the grin: a wide black mouth full of white teeth
	local Mouth = Shape(Head, Black, 0.5, 0.64, 0.76, 0.26, 0, UDim.new(0.45, 0), nil, 5)
	for I = 1, 6 do
		Shape(Mouth, White, (I - 0.5) / 6, 0.5, 0.09, 0.62, 0, UDim.new(0.2, 0), nil, 6)
	end
	return Holder, Arms
end

-- ===== build =====
local Gui, Root, Icon, Status, Who, Timer, Fill, Bar
local Arms

local function Build()
	Gui = Make("ScreenGui", {Name = "CombatLog", ResetOnSpawn = false, DisplayOrder = 6, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, Player:WaitForChild("PlayerGui"))
	Root = Make("Frame", {Name = "Badge", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -120),
		Size = UDim2.fromOffset(270, 72), BackgroundTransparency = 1, Visible = false}, Gui)
	Make("UIScale", {Name = "Motion"}, Root)

	-- the icon (transparent background)
	Icon = Make("Frame", {Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(36, 36),
		Size = UDim2.fromOffset(64, 64), BackgroundTransparency = 1}, Root)
	if ICON_IMAGE ~= "" then
		Make("ImageLabel", {Name = "Image", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = ICON_IMAGE,
			ScaleType = Enum.ScaleType.Fit}, Icon)
	else
		local _, A = DrawTruth(Icon)
		Arms = A
	end

	-- text plate: dark, fading out to the right so it never reads as a box
	local Plate = Make("Frame", {Name = "Plate", Position = UDim2.fromOffset(62, 10), Size = UDim2.fromOffset(204, 52),
		BackgroundColor3 = Color3.fromRGB(10, 10, 12), BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 0}, Root)
	Round(Plate, UDim.new(0, 6))
	Make("UIGradient", {Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.75, 0.15), NumberSequenceKeypoint.new(1, 1)})}, Plate)
	Make("Frame", {Name = "Edge", Size = UDim2.new(0, 2, 1, -8), Position = UDim2.fromOffset(0, 4),
		BackgroundColor3 = RED, BorderSizePixel = 0}, Plate)

	local function Text(Name, Y, H, Size, Color)
		local T = Make("TextLabel", {Name = Name, BackgroundTransparency = 1, Position = UDim2.fromOffset(78, Y),
			Size = UDim2.fromOffset(130, H), FontFace = FONT, TextSize = Size, TextColor3 = Color,
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = ""}, Root)
		Make("UIStroke", {Thickness = 1.2, Transparency = 0.3}, T)
		return T
	end
	Status = Text("Status", 13, 16, 15, RED)
	Who = Text("Who", 30, 14, 13, Color3.fromRGB(235, 232, 225))
	Timer = Make("TextLabel", {Name = "Timer", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(250, 12), Size = UDim2.fromOffset(44, 30), FontFace = FONT, TextSize = 22,
		TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Right, Text = ""}, Root)
	Make("UIStroke", {Thickness = 1.4, Transparency = 0.2}, Timer)

	Bar = Make("Frame", {Name = "Bar", Position = UDim2.fromOffset(78, 48), Size = UDim2.fromOffset(172, 4),
		BackgroundColor3 = Color3.fromRGB(40, 38, 40), BorderSizePixel = 0}, Root)
	Round(Bar)
	Fill = Make("Frame", {Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = RED, BorderSizePixel = 0}, Bar)
	Round(Fill)
end

-- ===== motion =====
local Showing = false
local HideToken

local function Show()
	HideToken = nil
	if Showing then return end
	if Player:GetAttribute("ShowCombatLog") == false then return end -- Settings: Combat Log off
	Showing = true
	Root.Visible = true
	Root.Position = UDim2.new(0.5, 0, 0, -120)
	Root.Motion.Scale = 0.85
	Icon.Rotation = -25
	Status.Text, Status.TextColor3 = "IN COMBAT", RED
	Fill.BackgroundColor3 = RED
	Tween(Root, 0.45, {Position = UDim2.new(0.5, 0, 0, TopY())}, Enum.EasingStyle.Back)
	Tween(Root.Motion, 0.45, {Scale = 1}, Enum.EasingStyle.Back)
	Tween(Icon, 0.6, {Rotation = 0}, Enum.EasingStyle.Elastic)
end

local function Hide()
	if not Showing then return end
	Showing = false
	local Token = {}
	HideToken = Token
	Status.Text, Status.TextColor3 = "SAFE", SAFE
	Who.Text = "Out of combat"
	Timer.Text = ""
	Fill.BackgroundColor3 = SAFE
	Fill.Size = UDim2.fromScale(1, 1)
	Tween(Icon, 0.25, {Rotation = 0})
	task.delay(0.9, function()
		if HideToken ~= Token then return end
		Tween(Root, 0.3, {Position = UDim2.new(0.5, 0, 0, -120)}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.delay(0.32, function() if HideToken == Token then Root.Visible = false end end)
	end)
end

-- a fresh hit: the icon jolts, the name flashes
local function Jolt()
	if not Showing then return end
	Icon.Rotation = math.random() < 0.5 and -14 or 14
	Tween(Icon, 0.45, {Rotation = 0}, Enum.EasingStyle.Elastic)
	local S = Icon:FindFirstChild("Punch") or Make("UIScale", {Name = "Punch"}, Icon)
	S.Scale = 1.3
	Tween(S, 0.3, {Scale = 1}, Enum.EasingStyle.Back)
	Who.TextColor3 = RED
	Tween(Who, 0.5, {TextColor3 = Color3.fromRGB(235, 232, 225)})
	local Image = Icon:FindFirstChild("Image")
	if Image then -- the image icon flashes red instead of the drawn arms
		Image.ImageColor3 = Color3.fromRGB(255, 120, 120)
		Tween(Image, 0.4, {ImageColor3 = Color3.new(1, 1, 1)})
	end
	if Arms then
		for _, Arm in ipairs(Arms) do
			for _, Part in ipairs(Arm) do
				Part.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
				Tween(Part, 0.4, {BackgroundColor3 = Color3.fromRGB(12, 12, 14)})
			end
		end
	end
end

-- ===== watch the character =====
local Conns = {}
local function Watch(Character)
	for _, C in ipairs(Conns) do C:Disconnect() end
	table.clear(Conns)
	Showing = false
	Root.Visible = false
	local function Refresh()
		if Character:GetAttribute("InCombat") then Show() else Hide() end
	end
	table.insert(Conns, Character:GetAttributeChangedSignal("InCombat"):Connect(Refresh))
	table.insert(Conns, Character:GetAttributeChangedSignal("CombatHitAt"):Connect(Jolt))
	for _, Attr in ipairs({"ShowCompass", "BossBarBottom"}) do
		table.insert(Conns, Player:GetAttributeChangedSignal(Attr):Connect(function()
			if Showing then Tween(Root, 0.3, {Position = UDim2.new(0.5, 0, 0, TopY())}) end
		end))
	end
	table.insert(Conns, Player:GetAttributeChangedSignal("ShowCombatLog"):Connect(function()
		if Player:GetAttribute("ShowCombatLog") == false then
			Showing, HideToken = false, nil
			Root.Visible = false
		else
			Refresh()
		end
	end))
	Refresh()

	table.insert(Conns, RunService.RenderStepped:Connect(function()
		if not Showing then return end
		local Left = math.max(0, (Character:GetAttribute("CombatUntil") or 0) - workspace:GetServerTimeNow())
		Timer.Text = ("%.1f"):format(Left)
		Fill.Size = UDim2.fromScale(math.clamp(Left / COMBAT_SECONDS, 0, 1), 1)
		local By, Vs = Character:GetAttribute("CombatBy"), Character:GetAttribute("CombatVs")
		Who.Text = By and ("Hit by " .. By) or Vs and ("Fighting " .. Vs) or "Don't leave yet"
		-- the grin breathes; the last 3 seconds tick faster
		local T = os.clock()
		Icon.Position = UDim2.fromOffset(36, 36 + math.sin(T * 3) * 1.5)
		Timer.TextColor3 = Left <= 3 and Color3.new(1, 1, 1):Lerp(RED, (math.sin(T * 12) + 1) / 2) or Color3.new(1, 1, 1)
	end))
end

function CombatLogUI.Start()
	Build()
	if Player.Character then Watch(Player.Character) end
	Player.CharacterAdded:Connect(Watch)
end

CombatLogUI.DrawTruth = DrawTruth
return CombatLogUI

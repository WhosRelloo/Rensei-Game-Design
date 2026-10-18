-- Timed popups: level up, new area, banner entries (codex / quests / toasts).
-- Owner 2026-10-18: "make the codex entry and level up UI a little more minimal but have a cool animation":
-- both are now built here (no panel art): level up = a gold line that draws out, a spinning alchemic sigil and
-- the level landing on it; new area / codex entry = a small label, the name with an underline that draws in,
-- the description fading in. The old art (HUD2.LevelUp / NewAreaDiscovered) stays in the place, unused.
-- Settings > UI Animations off (ReducedMotion): the same popups, faded only.
-- Each popup kind is a queue so two events never overwrite each other mid-display.

local TweenService = game:GetService("TweenService")

local UIState = require(script.Parent.UIState)

local HUD2 = UIState.Gui.HUD2

local PopupUI = {}

local function FadeTree(Root, Visible, Time)
	-- Fades every image and text under Root, remembering authored transparency.
	for _, D in ipairs(Root:GetDescendants()) do
		if D:IsA("ImageLabel") or D:IsA("ImageButton") then
			local Base = D:GetAttribute("BaseImageT")
			if Base == nil then Base = D.ImageTransparency D:SetAttribute("BaseImageT", Base) end
			TweenService:Create(D, TweenInfo.new(Time), {ImageTransparency = Visible and Base or 1}):Play()
		elseif D:IsA("TextLabel") then
			local Base = D:GetAttribute("BaseTextT")
			if Base == nil then Base = D.TextTransparency D:SetAttribute("BaseTextT", Base) end
			TweenService:Create(D, TweenInfo.new(Time), {TextTransparency = Visible and Base or 1}):Play()
		end
	end
	if Root:IsA("ImageLabel") then
		local Base = Root:GetAttribute("BaseImageT")
		if Base == nil then Base = Root.ImageTransparency Root:SetAttribute("BaseImageT", Base) end
		TweenService:Create(Root, TweenInfo.new(Time), {ImageTransparency = Visible and Base or 1}):Play()
	end
end

-- Popups that share screen space share a lane: they play one after another, never on top of
-- each other. Each queued item carries its own frame.
local Lanes = {}
local function Queue(Frame, Hold, LaneName)
	local Lane = Lanes[LaneName or Frame]
	if not Lane then
		Lane = {Items = {}, Running = false}
		Lanes[LaneName or Frame] = Lane
	end
	local Items = Lane.Items
	local function Run()
		Lane.Running = true
		while #Items > 0 do
			local Entry = table.remove(Items, 1)
			local Fill, Frame, Hold = Entry.Fill, Entry.Frame, Entry.Hold
			Fill(Frame)
			FadeTree(Frame, false, 0)
			Frame.Visible = true
			FadeTree(Frame, true, 0.3)
			task.wait(Hold)
			FadeTree(Frame, false, 0.4)
			task.wait(0.45)
			Frame.Visible = false
		end
		Lane.Running = false
	end
	return function(Fill)
		table.insert(Items, {Fill = Fill, Frame = Frame, Hold = Hold})
		if not Lane.Running then task.spawn(Run) end
	end
end

-- ===== the minimal popups (2026-10-18) =====
local GOLD = Color3.fromRGB(230, 205, 120)
local WHITE = Color3.fromRGB(240, 236, 226)
local DIM = Color3.fromRGB(190, 182, 166)
local FONT = Font.new("rbxasset://fonts/families/Guru.json")
local FONT_B = Font.new("rbxasset://fonts/families/Guru.json", Enum.FontWeight.Bold)
local Player = game:GetService("Players").LocalPlayer
local function Calm() return Player:GetAttribute("ReducedMotion") == true end
local function Tween(I, T, Props, Style, Dir)
	local Tw = TweenService:Create(I, TweenInfo.new(T, Style or Enum.EasingStyle.Quint, Dir or Enum.EasingDirection.Out), Props)
	Tw:Play()
	return Tw
end
local function New(Class, Props)
	local I = Instance.new(Class)
	for K, V in pairs(Props) do if K ~= "Parent" then I[K] = V end end
	I.Parent = Props.Parent
	return I
end
local function Text(Parent, Props)
	local Max = Props.Max or 40
	Props.Max = nil
	Props.Parent = Parent
	Props.BackgroundTransparency = 1
	Props.TextScaled = true
	Props.FontFace = Props.FontFace or FONT
	local L = New("TextLabel", Props)
	New("UITextSizeConstraint", {MaxTextSize = Max, Parent = L})
	New("UIStroke", {Thickness = 1, Transparency = 0.55, Color = Color3.new(0, 0, 0), Parent = L})
	return L
end
-- one popup at a time per lane; each Play yields for its whole animation
local Lanes = {}
local function Lane(Name)
	Lanes[Name] = Lanes[Name] or {Items = {}, Running = false}
	local L = Lanes[Name]
	return function(Play)
		table.insert(L.Items, Play)
		if L.Running then return end
		L.Running = true
		task.spawn(function()
			while #L.Items > 0 do
				local Ok, Err = pcall(table.remove(L.Items, 1))
				if not Ok then warn("PopupUI:", Err) end
			end
			L.Running = false
		end)
	end
end

-- Level up: a gold line draws out from the centre, a sigil (two counter-rotating squares) spins in behind
-- "LEVEL n", the rewards fade in under it; then it all folds back into the line and out.
local function BuildLevelUp()
	local Root = New("Frame", {Name = "LevelUpMinimal", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.24), Size = UDim2.fromScale(0.34, 0.15), Visible = false, Parent = HUD2})
	New("UIAspectRatioConstraint", {AspectRatio = 4, Parent = Root})
	local Sigil = New("Frame", {Name = "Sigil", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromScale(0.2, 0.8), Parent = Root})
	New("UIAspectRatioConstraint", {AspectRatio = 1, Parent = Sigil})
	local Squares = {}
	for I = 1, 2 do
		local Sq = New("Frame", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.72, 0.72), Rotation = I == 1 and 0 or 45, Parent = Sigil})
		Squares[I] = {Frame = Sq, Stroke = New("UIStroke", {Color = GOLD, Thickness = 1.5, Transparency = 1, Parent = Sq})}
	end
	local Line = New("Frame", {Name = "Line", BackgroundColor3 = GOLD, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.74), Size = UDim2.new(0, 0, 0, 2), BackgroundTransparency = 0.1, Parent = Root})
	New("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1)}), Parent = Line})
	local Title = Text(Root, {Name = "Title", Text = "LEVEL", FontFace = FONT_B, TextColor3 = WHITE, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromScale(0.9, 0.5), Max = 46})
	local Sub = Text(Root, {Name = "Rewards", Text = "", TextColor3 = GOLD, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.8), Size = UDim2.fromScale(0.9, 0.2), Max = 20})
	local Scale = New("UIScale", {Parent = Title})
	return {Root = Root, Squares = Squares, Line = Line, Title = Title, Sub = Sub, Scale = Scale, Sigil = Sigil}
end

-- New area / codex entry: a small gold label, the name with an underline that draws in, the description
local function BuildEntry()
	local Root = New("Frame", {Name = "EntryMinimal", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.16), Size = UDim2.fromScale(0.36, 0.13), Visible = false, Parent = HUD2})
	New("UIAspectRatioConstraint", {AspectRatio = 4.6, Parent = Root})
	local Kind = Text(Root, {Name = "Kind", Text = "NEW AREA", FontFace = FONT_B, TextColor3 = GOLD, Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 0.18), Max = 16})
	local Name = Text(Root, {Name = "Name", Text = "", FontFace = FONT_B, TextColor3 = WHITE, Position = UDim2.fromScale(0, 0.18),
		Size = UDim2.fromScale(1, 0.38), Max = 40})
	local Line = New("Frame", {Name = "Underline", BackgroundColor3 = GOLD, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.new(0, 0, 0, 1), BackgroundTransparency = 0.15, Parent = Root})
	local Desc = Text(Root, {Name = "Desc", Text = "", TextColor3 = DIM, TextWrapped = true, Position = UDim2.fromScale(0.05, 0.64),
		Size = UDim2.fromScale(0.9, 0.36), Max = 17})
	return {Root = Root, Kind = Kind, Name = Name, Line = Line, Desc = Desc}
end

function PopupUI.Start()
	local Banner = Queue(HUD2.Notification, 3)
	local Center = Lane("Center")
	local LU, EN = BuildLevelUp(), BuildEntry()

	local function PlayLevelUp(P)
		local Calmed = Calm()
		LU.Title.Text = ("LEVEL %s"):format(tostring(P.Level))
		local Parts = {}
		if P.StatPoints then table.insert(Parts, ("+%d Stat Points"):format(P.StatPoints)) end
		if P.Health then table.insert(Parts, ("+%s HP"):format(UIState.Format(P.Health))) end
		LU.Sub.Text = table.concat(Parts, "   ·   ")
		LU.Title.TextTransparency, LU.Sub.TextTransparency = 1, 1
		LU.Scale.Scale = Calmed and 1 or 1.35
		LU.Line.Size = UDim2.new(0, 0, 0, 2)
		for I, S in ipairs(LU.Squares) do S.Stroke.Transparency = 1 S.Frame.Rotation = I == 1 and -90 or 135 S.Frame.Size = UDim2.fromScale(0.2, 0.2) end
		LU.Root.Visible = true
		Tween(LU.Line, Calmed and 0.01 or 0.45, {Size = UDim2.new(0.86, 0, 0, 2)})
		for I, S in ipairs(LU.Squares) do
			Tween(S.Stroke, 0.35, {Transparency = 0.15})
			Tween(S.Frame, Calmed and 0.01 or 0.9, {Rotation = I == 1 and 0 or 45, Size = UDim2.fromScale(0.72, 0.72)}, Enum.EasingStyle.Back)
		end
		task.wait(Calmed and 0 or 0.2)
		Tween(LU.Title, 0.35, {TextTransparency = 0})
		Tween(LU.Scale, Calmed and 0.01 or 0.45, {Scale = 1}, Enum.EasingStyle.Back)
		task.wait(Calmed and 0 or 0.25)
		Tween(LU.Sub, 0.4, {TextTransparency = 0})
		-- the sigil keeps turning slowly while it holds
		local Spin = Calmed and nil or Tween(LU.Sigil, 3.2, {Rotation = 45}, Enum.EasingStyle.Linear)
		task.wait(2.8)
		Tween(LU.Title, 0.35, {TextTransparency = 1})
		Tween(LU.Sub, 0.3, {TextTransparency = 1})
		for _, S in ipairs(LU.Squares) do Tween(S.Stroke, 0.35, {Transparency = 1}) Tween(S.Frame, 0.4, {Size = UDim2.fromScale(0.2, 0.2)}) end
		Tween(LU.Line, Calmed and 0.01 or 0.4, {Size = UDim2.new(0, 0, 0, 2)}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.wait(0.45)
		if Spin then Spin:Cancel() end
		LU.Sigil.Rotation = 0
		LU.Root.Visible = false
	end

	local function PlayEntry(P, KindText)
		local Calmed = Calm()
		EN.Kind.Text = KindText
		EN.Name.Text = P.Name or ""
		EN.Desc.Text = P.Description or ""
		for _, L in ipairs({EN.Kind, EN.Name, EN.Desc}) do L.TextTransparency = 1 end
		EN.Line.Size = UDim2.new(0, 0, 0, 1)
		local Home = UDim2.fromScale(0.5, 0.16)
		EN.Root.Position = Calmed and Home or UDim2.fromScale(0.5, 0.12)
		EN.Root.Visible = true
		Tween(EN.Root, Calmed and 0.01 or 0.5, {Position = Home})
		Tween(EN.Kind, 0.3, {TextTransparency = 0})
		task.wait(Calmed and 0 or 0.12)
		Tween(EN.Name, 0.4, {TextTransparency = 0})
		Tween(EN.Line, Calmed and 0.01 or 0.6, {Size = UDim2.new(0.62, 0, 0, 1)})
		task.wait(Calmed and 0 or 0.35)
		Tween(EN.Desc, 0.5, {TextTransparency = 0})
		task.wait(4)
		for _, L in ipairs({EN.Kind, EN.Name, EN.Desc}) do Tween(L, 0.35, {TextTransparency = 1}) end
		Tween(EN.Line, 0.35, {Size = UDim2.new(0, 0, 0, 1)}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		Tween(EN.Root, Calmed and 0.01 or 0.4, {Position = Calmed and Home or UDim2.fromScale(0.5, 0.13)}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.wait(0.45)
		EN.Root.Visible = false
	end

	UIState.On("LevelUp", function(P) Center(function() PlayLevelUp(P) end) end)
	UIState.On("Area", function(P) Center(function() PlayEntry(P, "NEW AREA") end) end)
	-- a new codex entry (if the server sends one: {Name, Description}) uses the same minimal card
	UIState.On("Codex", function(P) Center(function() PlayEntry(P, "CODEX ENTRY") end) end)
	local function ShowBanner(P)
		Banner(function(F) F.Head.Text = P.Text end)
	end
	UIState.On("Banner", ShowBanner)
	UIState.On("Toast", ShowBanner)
end

PopupUI.FadeTree = FadeTree
return PopupUI

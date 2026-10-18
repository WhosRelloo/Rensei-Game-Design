-- MasteryUI: the Mastery skill tree menu (K). Plan: Documents/plans/2026-10-15-skill-tree.md, Task 7.
-- Three tabs ([Path] Alchemy / Arms / Body), each drawn as a transmutation circle: rings out from the
-- root, nodes placed by the registry's polar layout (R in ring units, A in degrees clockwise from up),
-- links to their prerequisites. Clicking a node opens its card: what it does, cost, the requirement
-- checklist (the same SkillTree.Requirements / CanBuy verdict the server uses), Buy / Refund, and a
-- live preview (your character in a ViewportFrame doing the move, or the stat it changes).
-- A fourth tab, CLASS (owner 2026-10-17), lists the class skills as one column per class family
-- (Rensei.ClassSkills): learn them here, then equip them to hotbar keys 1-4 (used in Combat Mode).
-- A GUIDE tab (first; 2026-10-17) ties the tracks together: your standing, what you can learn now, what's one
-- step away and where to get it (trainers, training, EXP, stats), and the choices with consequences.
-- Presentation only: SkillTreeService on the server decides every purchase and every equip.
-- Art: the Inventory panel, header and tabs (cloned from Uis.Inventory at start).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local UIState = require(script.Parent.UIState)
local SkillTree = require(ReplicatedStorage.Modules.Data.Rensei.SkillTree)
local Progression = require(ReplicatedStorage.Modules.Data.Rensei.Progression)
local Alchemy = require(ReplicatedStorage.Modules.Data.Rensei.Alchemy)
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)
local ClassSkills = require(ReplicatedStorage.Modules.Data.Rensei.ClassSkills)
local Styles = require(ReplicatedStorage.Modules.Data.Rensei.Styles)

local Player = Players.LocalPlayer

local MasteryUI = {}

-- ===== Style =====
local GURU = "rbxasset://fonts/families/Guru.json"
local FONT = Font.new(GURU, Enum.FontWeight.Regular)
local FONT_B = Font.new(GURU, Enum.FontWeight.Bold)
local GOLD = Color3.fromRGB(230, 205, 120)
local TEXT = Color3.fromRGB(225, 220, 210)
local DIM = Color3.fromRGB(140, 132, 120)
local DARK = Color3.fromRGB(20, 18, 16)
local LOCKED = Color3.fromRGB(70, 66, 60)
local RED = Color3.fromRGB(215, 80, 70)
local GREEN = Color3.fromRGB(140, 205, 120)
local TAB_OFF = "rbxassetid://126212104885490" -- Inventory category tab (inactive)
local TAB_ON = "rbxassetid://116949651608707" -- (active)
local BTN_GOLD = "rbxassetid://122322687865995" -- party Accept
local BTN_RED = "rbxassetid://96683854946403" -- party Decline
local ELEMENT = {
	Flame = Color3.fromRGB(255, 120, 40), Ice = Color3.fromRGB(140, 210, 255), Earth = Color3.fromRGB(190, 140, 90),
	Wind = Color3.fromRGB(170, 235, 190), Metal = Color3.fromRGB(190, 195, 205),
}
local NODE_SIZE = {Root = 54, Keystone = 44, Move = 38, Upgrade = 30, Passive = 30}
local RING_RADII = {1.0, 1.6, 2.3, 2.7, 3.3} -- the band edges drawn as circles
local OUTER = 3.75 -- the outer transmutation circle
local TREE_LABEL = {Arms = "ARMS", Body = "BODY", Class = "CLASS", Guide = "GUIDE"}
local TABS = {"Guide", "Alchemy", "Arms", "Body", SkillTree.ClassTree} -- the guide, the circles, then the Class columns
local GUIDE = "Guide"
local TIER = {[1] = "I", [5] = "II", [10] = "III"} -- class-skill tier mark, from its level requirement

local function New(Class, Props, Children)
	local I = Instance.new(Class)
	for K, V in pairs(Props or {}) do I[K] = V end
	for _, C in ipairs(Children or {}) do C.Parent = I end
	return I
end
local function Label(Text, Props)
	local L = New("TextLabel", {BackgroundTransparency = 1, Text = Text, FontFace = FONT, TextColor3 = TEXT, TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, RichText = true,
		Size = UDim2.new(1, 0, 0, 18)})
	for K, V in pairs(Props or {}) do L[K] = V end
	return L
end

-- ===== State =====
local Gui, Root, Main, Canvas, CanvasHolder, Zoom, CardBody, Info, Gate, GuideList, RecentreButton
local StyleButton, StylePanel -- the Class tab's style picker (Rensei.Styles)
local Tabs = {}
local Tree = "Guide" -- the menu opens on the GUIDE tab
local Selected = nil -- node id on the card
local NodeViews = {} -- [Id] = {Button, Stroke, Rank, Strike}
local Pending = false -- a Buy / Refund on its way to the server
local Preview = {} -- the viewport preview (built on open)

local function Data() return UIState.Data end
local function Affinity()
	local D = Data()
	local A = D and D.Identity and D.Identity.Affinity
	return (type(A) == "string" and A ~= "") and A or nil
end

-- the move a slot holds for the player's path (Alchemy.ForAffinity), or nil
local function MoveFor(Slot)
	local A = Affinity()
	if not A or not Slot then return nil end
	for _, Def in ipairs(Alchemy.ForAffinity(A)) do
		if Def.Key == Slot then return Def end
	end
	return nil
end

-- slot upgrades and move unlocks read with the move's own name
local function DisplayName(Node)
	local Move = MoveFor(Node.Slot)
	if Move and (Node.Type == "Upgrade") and Node.Name:sub(1, 2) == Node.Slot .. " " then
		return Move.Name .. " " .. Node.Name:sub(3)
	end
	return Node.Name
end
local function DisplayText(Node)
	local Move = MoveFor(Node.Slot)
	local T = Node.Text or ""
	if Move then
		T = T:gsub("[Yy]our " .. Node.Slot .. " move", Move.Name):gsub("[Yy]our " .. Node.Slot .. " cooldown", Move.Name .. "'s cooldown")
		if Node.Type == "Move" or Node.Type == "Root" then T = T .. ("  (%s, %s)"):format(Move.Name, Node.Slot) end
	end
	return T
end

-- ===== Panel =====
local function BuildPanel()
	local Inventory = Gui:WaitForChild("Inventory")
	local Source = Inventory:WaitForChild("MainFrame")
	Root = New("Frame", {Name = "Mastery", BackgroundTransparency = 1, Size = Inventory.Size, Position = Inventory.Position,
		AnchorPoint = Inventory.AnchorPoint, ZIndex = Inventory.ZIndex, Parent = Gui})
	Main = New("Frame", {Name = "MainFrame", BackgroundTransparency = 1, Size = Source:GetAttribute("FullSize") or Source.Size, -- the Bag shrank (2026-10-18); this menu keeps the full size Position = Source.Position,
		AnchorPoint = Source.AnchorPoint, Parent = Root}, {New("UIAspectRatioConstraint", {AspectRatio = 1.5179678})})
	Source.main:Clone().Parent = Main
	local Header = Source.Header:Clone()
	Header.Head.Text = "MASTERY"
	Header.Parent = Main

	-- tabs + the MP / stage line, where the Inventory has its categories and search bar
	local Top = New("Frame", {Name = "Top", BackgroundTransparency = 1, Size = Source.Top.Size, Position = Source.Top.Position,
		AnchorPoint = Source.Top.AnchorPoint, Parent = Main},
		{New("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0.012, 0), SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center})})
	for I, Name in ipairs(TABS) do
		local B = Source.Top.Armor:Clone()
		B.Name = Name
		B.LayoutOrder = I
		B.Size = UDim2.fromScale(0.13, 0.85)
		B.Parent = Top
		B.Active = true -- (the Inventory's tabs are inactive art; these are buttons)
		Tabs[Name] = B
		local Last = 0
		local function Pick() if os.clock() - Last > 0.2 then Last = os.clock() MasteryUI.ShowTree(Name) end end
		B.Activated:Connect(Pick)
		B.MouseButton1Click:Connect(Pick)
	end
	Info = Label("", {Name = "Info", LayoutOrder = 9, Size = UDim2.fromScale(0.3, 1), TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Center, TextScaled = true, Parent = Top})
	New("UITextSizeConstraint", {MaxTextSize = 17, Parent = Info})

	-- the circle (left) and the card (right), inside the panel's grid area
	CanvasHolder = New("Frame", {Name = "Circle", BackgroundTransparency = 1, ClipsDescendants = true, Active = true,
		Size = UDim2.fromScale(0.56, 0.83), Position = UDim2.fromScale(0.035, 0.125), Parent = Main})
	Canvas = New("Frame", {Name = "Canvas", BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 0), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Parent = CanvasHolder})
	Zoom = New("UIScale", {Parent = Canvas})
	Gate = Label("", {Name = "Gate", TextColor3 = DIM, TextSize = 13, Size = UDim2.new(0.75, 0, 0, 34), Position = UDim2.fromOffset(6, 4),
		ZIndex = 5, Parent = CanvasHolder})
	local Recentre
	Recentre = New("TextButton", {Name = "Recentre", Text = "◎", FontFace = FONT_B, TextSize = 20, TextColor3 = GOLD,
		BackgroundColor3 = DARK, BackgroundTransparency = 0.2, Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -36, 0, 6),
		ZIndex = 6, Parent = CanvasHolder}, {New("UICorner", {CornerRadius = UDim.new(1, 0)}), New("UIStroke", {Color = GOLD, Transparency = 0.4})})
	Recentre.Activated:Connect(function()
		Canvas.Position = UDim2.fromScale(0.5, 0.5)
		Zoom.Scale = 1
	end)
	RecentreButton = Recentre
	-- the Class tab's style picker (Rensei.Styles): a button beside the loadout line, a panel over the columns
	StyleButton = New("TextButton", {Name = "Style", Text = "", FontFace = FONT_B, TextScaled = true, TextColor3 = GOLD,
		BackgroundColor3 = DARK, BackgroundTransparency = 0.2, Size = UDim2.new(0.38, -42, 0, 28), Position = UDim2.new(0.6, 0, 0, 6),
		ZIndex = 6, Visible = false, Parent = CanvasHolder},
		{New("UICorner", {CornerRadius = UDim.new(0, 4)}), New("UIStroke", {Color = GOLD, Transparency = 0.4}),
		New("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5)}),
		New("UITextSizeConstraint", {MaxTextSize = 15})})
	StylePanel = New("ScrollingFrame", {Name = "StylePicker", BackgroundColor3 = DARK, BackgroundTransparency = 0.06, Active = true,
		BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = GOLD, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(0.92, 0, 0.82, 0), Position = UDim2.fromScale(0.04, 0.14), ZIndex = 10, Visible = false, Parent = CanvasHolder},
		{New("UICorner", {CornerRadius = UDim.new(0, 6)}), New("UIStroke", {Color = GOLD, Transparency = 0.3}),
		New("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}),
		New("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8)})})
	StyleButton.Activated:Connect(function() MasteryUI.StylePicker(not StylePanel.Visible) end)
	local function WatchStyle(Character)
		local function Changed()
			if StyleButton then StyleButton.Text = MasteryUI.StyleLabel() end
			if StylePanel and StylePanel.Visible then MasteryUI.StylePicker(true) end
		end
		Character:GetAttributeChangedSignal("Style"):Connect(Changed)
		Character:GetAttributeChangedSignal("Weapon"):Connect(Changed)
	end
	if Player.Character then WatchStyle(Player.Character) end
	Player.CharacterAdded:Connect(WatchStyle)
	-- the GUIDE tab's list (shown instead of the circle)
	GuideList = New("ScrollingFrame", {Name = "Guide", BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
		ScrollBarImageColor3 = GOLD, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 4,
		Size = UDim2.new(1, -12, 1, -8), Position = UDim2.fromOffset(6, 4), Parent = CanvasHolder},
		{New("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder})})

	local Card = New("Frame", {Name = "Card", BackgroundColor3 = DARK, BackgroundTransparency = 0.35, Size = UDim2.fromScale(0.345, 0.83),
		Position = UDim2.fromScale(0.61, 0.125), Parent = Main},
		{New("UICorner", {CornerRadius = UDim.new(0, 4)}), New("UIStroke", {Color = GOLD, Transparency = 0.6})})
	Preview.Frame = New("ViewportFrame", {Name = "Preview", BackgroundColor3 = Color3.fromRGB(10, 9, 8), BackgroundTransparency = 0.2,
		Size = UDim2.new(1, -16, 0.4, 0), Position = UDim2.fromOffset(8, 8), Ambient = Color3.fromRGB(170, 160, 150),
		LightColor = Color3.fromRGB(255, 240, 220), Parent = Card}, {New("UICorner", {CornerRadius = UDim.new(0, 4)})})
	Preview.Bars = New("Frame", {Name = "StatPreview", BackgroundTransparency = 1, Size = Preview.Frame.Size, Position = Preview.Frame.Position,
		Visible = false, Parent = Card}, {New("UIListLayout", {Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center})})
	CardBody = New("ScrollingFrame", {Name = "Body", BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
		ScrollBarImageColor3 = GOLD, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -16, 0.6, -60), Position = UDim2.new(0, 8, 0.4, 14), Parent = Card},
		{New("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder})})
	local Buttons = New("Frame", {Name = "Buttons", BackgroundTransparency = 1, Size = UDim2.new(1, -16, 0, 36), Position = UDim2.new(0, 8, 1, -44), Parent = Card})
	for _, B in ipairs({{"Buy", "BUY", BTN_GOLD, 0}, {"Refund", "REFUND", BTN_RED, 0.52}}) do
		local Btn = New("ImageButton", {Name = B[1], Image = B[3], BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Stretch,
			Size = UDim2.fromScale(0.48, 1), Position = UDim2.fromScale(B[4], 0), Parent = Buttons})
		Label(B[2], {Name = "Label", FontFace = FONT_B, TextSize = 16, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center, Parent = Btn})
		Btn.Activated:Connect(function() MasteryUI.Act(B[1]) end)
	end
	Preview.Buttons = Buttons

	-- pan (drag) and zoom (wheel / pinch) on the circle
	local Drag = nil
	CanvasHolder.InputBegan:Connect(function(I)
		if I.UserInputType == Enum.UserInputType.MouseButton1 or I.UserInputType == Enum.UserInputType.Touch then
			Drag = {Start = Vector2.new(I.Position.X, I.Position.Y), From = Canvas.Position}
		elseif I.UserInputType == Enum.UserInputType.MouseWheel then
			Zoom.Scale = math.clamp(Zoom.Scale + I.Position.Z * 0.1, 0.6, 1.8)
		end
	end)
	CanvasHolder.InputChanged:Connect(function(I)
		if I.UserInputType == Enum.UserInputType.MouseWheel then
			Zoom.Scale = math.clamp(Zoom.Scale + I.Position.Z * 0.1, 0.6, 1.8)
		end
	end)
	UserInputService.InputChanged:Connect(function(I)
		if Drag and (I.UserInputType == Enum.UserInputType.MouseMovement or I.UserInputType == Enum.UserInputType.Touch) then
			local D = Vector2.new(I.Position.X, I.Position.Y) - Drag.Start
			Canvas.Position = Drag.From + UDim2.fromOffset(D.X, D.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(I)
		if I.UserInputType == Enum.UserInputType.MouseButton1 or I.UserInputType == Enum.UserInputType.Touch then Drag = nil end
	end)
	UserInputService.TouchPinch:Connect(function(_, Scale, _, State)
		if not Root.Visible then return end
		if State == Enum.UserInputState.Begin then Preview.PinchFrom = Zoom.Scale end
		Zoom.Scale = math.clamp((Preview.PinchFrom or 1) * Scale, 0.6, 1.8)
	end)
	CanvasHolder:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() if Root.Visible then MasteryUI.Draw() end end)
end

-- ===== The circle =====
local function RingPx()
	local S = CanvasHolder.AbsoluteSize
	return math.max(20, math.min(S.X, S.Y) / 2 / (OUTER + 0.35))
end
local function PosOf(Node, Px)
	local A = math.rad(Node.A)
	return Vector2.new(math.sin(A), -math.cos(A)) * Node.R * Px
end

local function Circle(Radius, Thickness, Transparency, Parent)
	return New("Frame", {BackgroundTransparency = 1, Size = UDim2.fromOffset(Radius * 2, Radius * 2), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(0, 0), Parent = Parent},
		{New("UICorner", {CornerRadius = UDim.new(1, 0)}), New("UIStroke", {Color = GOLD, Thickness = Thickness, Transparency = Transparency})})
end

local function Line(A, B, Color, Transparency, Parent)
	local D = B - A
	local Mid = (A + B) / 2
	return New("Frame", {BorderSizePixel = 0, BackgroundColor3 = Color, BackgroundTransparency = Transparency,
		Size = UDim2.fromOffset(D.Magnitude, 2), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(Mid.X, Mid.Y),
		Rotation = math.deg(math.atan2(D.Y, D.X)), Parent = Parent})
end

function MasteryUI.Draw()
	for _, C in ipairs(Canvas:GetChildren()) do if not C:IsA("UIScale") then C:Destroy() end end
	NodeViews = {}
	if Tree == GUIDE then
		MasteryUI.DrawGuide()
		MasteryUI.Refresh()
		return
	end
	if Tree == SkillTree.ClassTree then
		MasteryUI.DrawClass()
		MasteryUI.Refresh()
		return
	end
	local Px = RingPx()
	local D = Data()
	local Stage = SkillTree.Stage(D)

	-- rings: the band edges, dimmed while closed, with their names
	local Rings = New("Folder", {Name = "Rings", Parent = Canvas})
	local Closed = {}
	for Ring, Need in pairs(SkillTree.RingStage) do Closed[Ring] = Stage < Need end
	for _, R in ipairs(RING_RADII) do
		local Ring = R <= 1.6 and 1 or (R <= 2.7 and 2 or 3)
		Circle(R * Px, 1, Closed[Ring] and 0.85 or 0.55, Rings)
	end
	Circle(OUTER * Px, 2.5, 0.3, Rings)
	Circle((OUTER - 0.12) * Px, 1, 0.55, Rings)
	for Ring, Name in pairs(SkillTree.RingNames) do
		local R = Ring == 1 and 1.3 or (Ring == 2 and 2.5 or 3.3)
		Label(Name:upper() .. (Closed[Ring] and ("\nOpens at Stage " .. SkillTree.RingStage[Ring]) or ""), {
			TextColor3 = Closed[Ring] and DIM or GOLD, TextTransparency = Closed[Ring] and 0.3 or 0.45, TextSize = 11, FontFace = FONT_B,
			TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(120, 30), AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(0, R * Px + 4), Parent = Rings})
	end

	-- links (prerequisite -> node), under the nodes
	local Links = New("Folder", {Name = "Links", Parent = Canvas})
	for Id, Node in pairs(SkillTree.Nodes) do
		if Node.Tree == Tree then
			for _, R in ipairs(Node.Req) do
				local From = SkillTree.Nodes[R]
				if From and From.Tree == Tree then
					local Lit = SkillTree.Rank(D, R) > 0 and SkillTree.Rank(D, Id) > 0
					Line(PosOf(From, Px), PosOf(Node, Px), Lit and GOLD or LOCKED, Lit and 0.1 or 0.35, Links)
				end
			end
		end
	end

	-- nodes
	for Id, Node in pairs(SkillTree.Nodes) do
		if Node.Tree == Tree then
			local P = PosOf(Node, Px)
			local S = NODE_SIZE[Node.Type] or 30
			local B = New("TextButton", {Name = Id, Text = "", AutoButtonColor = false, BackgroundColor3 = DARK, Size = UDim2.fromOffset(S, S),
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(P.X, P.Y), ZIndex = 3, Parent = Canvas},
				{New("UICorner", {CornerRadius = UDim.new(Node.Type == "Keystone" and 0.2 or 1, 0)})})
			if Node.Type == "Keystone" then B.Rotation = 45 end
			local Stroke = New("UIStroke", {Color = GOLD, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = B})
			local Glyph = Label(Node.Type == "Move" and (Node.Slot or "") or (Node.Type == "Root" and "✦" or ""), {
				FontFace = FONT_B, TextSize = S * 0.45, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center,
				Size = UDim2.fromScale(1, 1), Rotation = -B.Rotation, ZIndex = 4, Parent = B})
			local Rank = Label("", {TextSize = 11, FontFace = FONT_B, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(40, 14),
				AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 2), Rotation = -B.Rotation, ZIndex = 4, Parent = B})
			NodeViews[Id] = {Button = B, Stroke = Stroke, Rank = Rank, Glyph = Glyph}
			B.Activated:Connect(function() MasteryUI.Select(Id) end)
		end
	end
	MasteryUI.Refresh()
end

-- ===== The Class tab: one column per class family =====
-- Each column lists its skills top to bottom in tier order with links to their prerequisites. The column
-- of the class you're fighting as is lit and marked EQUIPPED CLASS.
function MasteryUI.DrawClass()
	local S = CanvasHolder.AbsoluteSize
	local Count = #ClassSkills.Order
	local ColW = math.max(74, S.X / Count)
	local RowH = math.clamp((S.Y - 110) / 5, 52, 86)
	local Top = -S.Y / 2 + 44 -- under the loadout line
	local D = Data()
	local Current = ClassSkills.CharacterFamily(Player.Character)
	local Pos = {}
	for C, Family in ipairs(ClassSkills.Order) do
		local X = (C - (Count + 1) / 2) * ColW
		local Here = Family == Current
		New("Frame", {Name = Family, BackgroundColor3 = Here and GOLD or DARK, BackgroundTransparency = Here and 0.9 or 0.65, BorderSizePixel = 0,
			Size = UDim2.fromOffset(ColW - 8, S.Y - 56), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(X, Top), ZIndex = 1, Parent = Canvas},
			{New("UICorner", {CornerRadius = UDim.new(0, 4)}), New("UIStroke", {Color = GOLD, Transparency = Here and 0.25 or 0.82})})
		Label(ClassSkills.Display[Family]:upper(), {FontFace = FONT_B, TextSize = 14, TextColor3 = Here and GOLD or TEXT, TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromOffset(ColW - 10, 18), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(X, Top + 6), ZIndex = 2, Parent = Canvas})
		Label(Here and "EQUIPPED CLASS" or "", {FontFace = FONT_B, TextSize = 10, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromOffset(ColW - 10, 14), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(X, Top + 24), ZIndex = 2, Parent = Canvas})
		for _, Node in ipairs(ClassSkills.Nodes(Family)) do
			Pos[Node.Id] = Vector2.new(X, Top + 50 + (Node.A - 0.5) * RowH)
		end
	end
	for Id, P in pairs(Pos) do
		for _, R in ipairs(SkillTree.Nodes[Id].Req) do
			if Pos[R] then
				local Lit = SkillTree.Rank(D, R) > 0 and SkillTree.Rank(D, Id) > 0
				Line(Pos[R], P, Lit and GOLD or LOCKED, Lit and 0.1 or 0.35, Canvas).ZIndex = 2
			end
		end
	end
	for Id, P in pairs(Pos) do
		local Node = SkillTree.Nodes[Id]
		local Size = math.clamp(RowH * 0.48, 30, 42)
		local B = New("TextButton", {Name = Id, Text = "", AutoButtonColor = false, BackgroundColor3 = DARK, Size = UDim2.fromOffset(Size, Size),
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(P.X, P.Y), ZIndex = 3, Parent = Canvas},
			{New("UICorner", {CornerRadius = UDim.new(0.18, 0)})})
		local Stroke = New("UIStroke", {Color = GOLD, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = B})
		local Glyph = Label(TIER[Node.Level or 1] or "I", {FontFace = FONT_B, TextSize = Size * 0.42, TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = B})
		Label(Node.Name, {FontFace = FONT_B, TextSize = 11, TextColor3 = TEXT, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(ColW - 12, 14),
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 2), ZIndex = 4, Parent = B})
		local Rank = Label("", {TextSize = 10, FontFace = FONT_B, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(ColW - 12, 12),
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 15), ZIndex = 4, Parent = B})
		NodeViews[Id] = {Button = B, Stroke = Stroke, Rank = Rank, Glyph = Glyph}
		B.Activated:Connect(function() MasteryUI.Select(Id) end)
	end
end

-- ===== Styles (Rensei.Styles): the style button's text and the picker panel =====
function MasteryUI.StyleLabel()
	local _, S = Styles.Active(Player.Character)
	return ("STYLE: %s  ▾"):format(((S and S.Name) or "Base"):upper())
end

-- the styles you can pick for the class you're fighting as; the server validates (Requests.Style)
function MasteryUI.StylePicker(Open)
	StylePanel.Visible = Open == true
	for _, C in ipairs(StylePanel:GetChildren()) do if C:IsA("GuiObject") then C:Destroy() end end
	if not Open then return end
	local Character = Player.Character
	local Class = Styles.ClassOf(Character)
	local Active = Styles.Active(Character)
	local Info = Class and Styles.Classes[Class]
	Label(("<b>%s STYLES</b>"):format(((Info and Info.Display) or "WEAPON"):upper()), {FontFace = FONT_B, TextColor3 = GOLD, TextSize = 16,
		LayoutOrder = 0, ZIndex = 11, Parent = StylePanel})
	local Ids = Class and Styles.Selectable(Class) or {}
	for I, Id in ipairs(Ids) do
		local S = Info.Styles[Id]
		local On = Id == Active
		local Learned = Styles.Unlocked(Data(), Id)
		local Row = New("TextButton", {Name = Id, Text = "", AutoButtonColor = not On, BackgroundColor3 = On and GOLD or Color3.fromRGB(34, 31, 27),
			BackgroundTransparency = On and 0.82 or 0.2, Size = UDim2.new(1, -6, 0, 76), LayoutOrder = I, ZIndex = 11, Parent = StylePanel},
			{New("UICorner", {CornerRadius = UDim.new(0, 4)}), New("UIStroke", {Color = GOLD, Transparency = On and 0.1 or 0.7})})
		Label(("<b>%s</b>"):format(S.Name:upper()), {FontFace = FONT_B, TextSize = 15, TextColor3 = On and GOLD or TEXT, Size = UDim2.new(0.7, 0, 0, 18),
			Position = UDim2.fromOffset(8, 5), ZIndex = 12, Parent = Row})
		Label(On and "ACTIVE" or (Learned and "SELECT" or "LOCKED"), {FontFace = FONT_B, TextSize = 12, TextColor3 = On and GOLD or (Learned and GREEN or RED), TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.new(0.3, -10, 0, 16), Position = UDim2.new(0.7, 0, 0, 6), ZIndex = 12, Parent = Row})
		local Desc = S.Desc
		if not Learned and S.Unlock then
			-- learned only from its trainer (Rensei.Styles.Unlock), once the requirements are met
			local Missing = Styles.Missing(Data(), Id)
			Desc = ("Learn it from %s, at %s. %s"):format(S.Unlock.Trainer, S.Unlock.Where,
				#Missing > 0 and ("Still needed: " .. table.concat(Missing, ", ") .. ".") or "You're ready: go and see them.")
			Row.AutoButtonColor = false
			Row.BackgroundTransparency = 0.45
		end
		Label(Desc, {TextSize = 12, TextColor3 = Learned and DIM or Color3.fromRGB(190, 150, 140), Size = UDim2.new(1, -16, 0, 48), Position = UDim2.fromOffset(8, 24), ZIndex = 12, Parent = Row})
		Row.Activated:Connect(function()
			if Learned and Id ~= Styles.Active(Player.Character) then UIState.Request("Style", Id) end
		end)
	end
	Label(#Ids <= 1 and "No styles have been designed for this weapon yet." or "Switch out of combat. Your choice is saved for this weapon.",
		{TextSize = 12, TextColor3 = DIM, LayoutOrder = 99, ZIndex = 11, Size = UDim2.new(1, 0, 0, 30), Parent = StylePanel})
end

-- "Fists loadout (Combat Mode): 1 Spin Kick  2 —  3 —  4 —" for the class you're fighting as
local function LoadoutLine(D)
	local Family = ClassSkills.CharacterFamily(Player.Character)
	if not Family or not D then return "" end
	local Parts = {}
	for I, Id in ipairs(ClassSkills.Loadout(D, Family)) do
		table.insert(Parts, ("<b>%d</b> %s"):format(I, Id ~= "" and SkillTree.Nodes[Id].Name or "—"))
	end
	return ("<font color='#E6CD78'>%s loadout</font>, Combat Mode keys:  %s"):format(ClassSkills.Display[Family], table.concat(Parts, "   "))
end

-- ===== The GUIDE tab =====
-- "What can I unlock next, what am I missing, where do I get it, what can I equip, who can teach me,
-- and what do my choices cost?" -- built from the same shared rules the server uses (SkillTree.Missing,
-- Progression.GateCheck, Rensei.Training), refreshed whenever the profile changes.
local Training = require(ReplicatedStorage.Modules.Data.Rensei.Training)
local COMPASS = {"north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"}
local function Direction(To)
	local Root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
	if not Root then return "" end
	local D = To - Root.Position
	local Dist = Vector3.new(D.X, 0, D.Z).Magnitude
	if Dist < 12 then return "right here" end
	local Heading = math.deg(math.atan2(D.X, -D.Z)) % 360 -- -Z is north
	return ("%d studs %s"):format(math.floor(Dist / 5 + 0.5) * 5, COMPASS[math.floor((Heading + 22.5) / 45) % 8 + 1])
end
local function Trainers()
	local List = {}
	local Folder = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("NPCs")
	if Folder then
		for _, M in ipairs(Folder:GetDescendants()) do
			if M:IsA("Model") and M:GetAttribute("TrainerPath") then table.insert(List, M) end
		end
	end
	table.sort(List, function(A, B) return A:GetAttribute("TrainerPath") < B:GetAttribute("TrainerPath") end)
	return List
end
local function DailyCount(D, Key)
	local V = D and D.Story and D.Story.Flags and D.Story.Flags[Key]
	local Day, Count = tostring(V or ""):match("^(%d+):(%d+)$")
	return (tonumber(Day) == math.floor(os.time() / 86400)) and tonumber(Count) or 0
end

function MasteryUI.DrawGuide()
	for _, C in ipairs(GuideList:GetChildren()) do if C:IsA("GuiObject") then C:Destroy() end end
	local D = Data()
	if not D or not D.Mastery then
		Label("Loading your progress...", {TextColor3 = DIM, Parent = GuideList})
		return
	end
	local O = 0
	local function Line(Text, Props)
		O += 1
		local L = Label(Text, Props)
		L.LayoutOrder = O
		L.AutomaticSize = Enum.AutomaticSize.Y
		L.ZIndex = 5
		L.Parent = GuideList
		return L
	end
	local function Head(Text) Line(Text, {FontFace = FONT_B, TextSize = 16, TextColor3 = GOLD}) end
	local function NodeRow(Node, Detail, Hint)
		O += 1
		local B = New("TextButton", {Name = Node.Id, Text = "", AutoButtonColor = true, BackgroundColor3 = DARK, BackgroundTransparency = 0.35,
			Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = O, ZIndex = 5, Parent = GuideList},
			{New("UICorner", {CornerRadius = UDim.new(0, 4)}), New("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3)}),
			 New("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder})})
		local Tab = TREE_LABEL[Node.Tree] or (Node.Tree == "Alchemy" and "ALCHEMY") or Node.Tree
		local Fam = Node.Family and (" · " .. ClassSkills.Display[Node.Family]) or ""
		Label(("<b>%s</b>  <font color='#8C8478'>%s%s · %s tab</font>"):format(DisplayName(Node), SkillTree.Category(Node), Fam, Tab:upper()),
			{TextSize = 14, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, ZIndex = 6, Parent = B})
		if Detail then Label(Detail, {TextSize = 13, TextColor3 = Hint ~= nil and RED or GREEN, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, ZIndex = 6, Parent = B}) end
		if Hint then Label(Hint, {TextSize = 12, TextColor3 = DIM, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, ZIndex = 6, Parent = B}) end
		B.Activated:Connect(function() MasteryUI.ShowTree(Node.Tree) MasteryUI.Select(Node.Id) end)
	end
	local M = D.Mastery

	-- 1. standing
	Head("YOUR STANDING")
	local Lvl = D.Level or 1
	Line(("Level <b>%d</b>  ·  EXP %s / %s  ·  <b>%d</b> Stat Points to spend (Stats, M)"):format(Lvl, UIState.Format(D.Exp or 0),
		UIState.Format(Progression.ExpToNext(Lvl)), D.StatPoints or 0), {TextSize = 14})
	Line(("Mastery Points: <b>%d</b> to spend  ·  Stage %d / %d  ·  earned this stage %d / %d"):format(M.Unspent or 0, M.Stage or 1,
		Progression.MaxStage, M.StageEarned or 0, Progression.MasteryPerStage), {TextSize = 14})
	local Ready, Reasons = Progression.GateCheck(D)
	if Ready then
		Line("<font color='#E6CD78'>Truth/Gate: you meet every requirement for the trial.</font> (The trial itself isn't in the game yet.)", {TextSize = 13})
	else
		Line("Truth/Gate trial needs: " .. table.concat(Reasons, "; ") .. ".", {TextSize = 13, TextColor3 = DIM})
	end

	-- 2. ready now / 3. one step away
	local ReadyBy, Near = {}, {}
	for Id, Node in pairs(SkillTree.Nodes) do
		if Node.Type ~= "Root" then
			local Miss = SkillTree.Missing(D, Id)
			if #Miss == 0 then
				local Cat = SkillTree.Category(Node)
				ReadyBy[Cat] = ReadyBy[Cat] or {}
				table.insert(ReadyBy[Cat], Node)
			elseif #Miss == 1 and Miss[1][1] ~= "Stage" and Miss[1][1] ~= "Maxed" and Miss[1][1] ~= "Fork" then
				table.insert(Near, {Node, Miss[1]})
			end
		end
	end
	Head("READY TO LEARN NOW")
	local Any = false
	for _, Cat in ipairs(SkillTree.CategoryOrder) do
		local List = ReadyBy[Cat]
		if List then
			table.sort(List, function(A, B) return A.Cost < B.Cost end)
			for _, Node in ipairs(List) do
				Any = true
				NodeRow(Node, ("Learnable now · %d MP"):format(Node.Cost))
			end
		end
	end
	if not Any then Line("Nothing yet: you need Mastery Points first (see WHERE TO PROGRESS).", {TextSize = 13, TextColor3 = DIM}) end

	Head("ONE STEP AWAY")
	local KindOrder = {MP = 1, Level = 2, Stat = 3, Prereq = 4}
	table.sort(Near, function(A, B)
		local KA, KB = KindOrder[A[2][1]] or 9, KindOrder[B[2][1]] or 9
		if KA ~= KB then return KA < KB end
		return A[1].Cost < B[1].Cost
	end)
	local HintShown = {} -- each kind's "where to get it" once, on its first row
	for I, E in ipairs(Near) do
		if I > 10 then Line(("...and %d more (open the tabs)."):format(#Near - 10), {TextSize = 12, TextColor3 = DIM}) break end
		local Kind = E[2][1]
		local Hint = (Kind == "MP" and HintShown.MP) and nil or E[2][3]
		HintShown[Kind] = true
		NodeRow(E[1], "Needs " .. E[2][2], Hint or false)
	end
	if #Near == 0 then Line("Nothing is a single step away right now.", {TextSize = 13, TextColor3 = DIM}) end

	-- 4. where to progress
	Head("WHERE TO PROGRESS")
	local Path = Affinity()
	local Found = Trainers()
	if Path then
		for _, T in ipairs(Found) do
			if T:GetAttribute("TrainerPath") == Path then
				Line(("<b>Your trainer:</b> %s (%s alchemy), %s."):format(T:GetAttribute("DisplayName") or T.Name, Path, Direction(T:GetPivot().Position)), {TextSize = 14})
			end
		end
		for Id, L in pairs(Training.Lessons) do
			if L.Path == Path then
				local Done = DailyCount(D, "Lesson_" .. Id)
				Line(("  Lesson \"%s\": %s"):format(L.Title, Done >= (L.PerDay or 1) and "done today" or "available today (pays Mastery training)"), {TextSize = 13, TextColor3 = Done >= (L.PerDay or 1) and DIM or GREEN})
			end
		end
		for Id, X in pairs(Training.Exercises) do
			if X.Path == Path then
				local Done = DailyCount(D, "Exercise_" .. Id)
				Line(("  Exercise \"%s\": %d of %d left today"):format(X.Title, math.max(0, (X.PerDay or 1) - Done), X.PerDay or 1), {TextSize = 13, TextColor3 = Done < (X.PerDay or 1) and GREEN or DIM})
			end
		end
	else
		Line("<b>No alchemy yet.</b> Alchemy is learned from the trainers, through their questlines:", {TextSize = 14})
		for _, T in ipairs(Found) do
			Line(("  %s: %s alchemy, %s"):format(T:GetAttribute("DisplayName") or T.Name, T:GetAttribute("TrainerPath"), Direction(T:GetPivot().Position)), {TextSize = 13})
		end
	end
	Line("Mastery Points come from training: fighting (hits, parries, defeats; full pay up to an hourly allowance per kind), trainer lessons (once a day), exercises, exams and quests. Every 100 training = 1 MP, up to the stage's 20.", {TextSize = 13, TextColor3 = DIM})
	local Active = 0
	for _ in pairs(D.Quests and D.Quests.Active or {}) do Active += 1 end
	Line(("EXP: defeat enemies, finish quests (%d active, Journal J) and solve investigations. Levels give Stat Points."):format(Active), {TextSize = 13, TextColor3 = DIM})

	-- 5. choices with consequences
	Head("CHOICES WITH CONSEQUENCES")
	local Forks, Seen = {}, {}
	for _, Node in pairs(SkillTree.Nodes) do
		if Node.Fork and not Seen[Node.Fork] and SkillTree.Stage(D) >= SkillTree.RingStage[Node.Ring] then
			local Pair, Taken = {}, nil
			for _, Other in pairs(SkillTree.Nodes) do
				if Other.Fork == Node.Fork then
					table.insert(Pair, Other.Name)
					if SkillTree.Rank(D, Other.Id) > 0 then Taken = Other.Name end
				end
			end
			Seen[Node.Fork] = true
			table.sort(Pair)
			table.insert(Forks, Taken and ("Fork (chosen): %s. The other side stays locked unless you refund it before the trial."):format(Taken)
				or ("Fork: %s. Owning one locks the other."):format(table.concat(Pair, " or ")))
		end
	end
	for _, F in ipairs(Forks) do Line(F, {TextSize = 13}) end
	local Refundable = 0
	for Id, Ranks in pairs(M.StageSpend or {}) do
		local Node = SkillTree.Nodes[Id]
		if Node then Refundable += Ranks * Node.Cost end
	end
	Line(("%d MP spent this stage can still be refunded. Passing the Truth/Gate trial seals it for good."):format(Refundable), {TextSize = 13, TextColor3 = DIM})
	Line(("The Deconstruction ring opens at Stage %d and Reconstruction (keystones) at Stage %d: each needs a Truth/Gate trial."):format(SkillTree.RingStage[2], SkillTree.RingStage[3]), {TextSize = 13, TextColor3 = DIM})
	Line("Class skills are equipped per weapon class: 4 hotbar keys in Combat Mode (CLASS tab).", {TextSize = 13, TextColor3 = DIM})
end

-- the card while the GUIDE tab is open: how the tracks fit together
function MasteryUI.GuideCard()
	for _, C in ipairs(CardBody:GetChildren()) do if C:IsA("GuiObject") then C:Destroy() end end
	Preview.Frame.Visible, Preview.Bars.Visible = false, false
	Preview.Buttons.Buy.Visible, Preview.Buttons.Refund.Visible = false, false
	local O = 0
	local function Add(Text, Props)
		O += 1
		local L = Label(Text, Props)
		L.LayoutOrder = O
		L.AutomaticSize = Enum.AutomaticSize.Y
		L.Parent = CardBody
	end
	Add("HOW IT FITS", {FontFace = FONT_B, TextSize = 20, TextColor3 = GOLD})
	Add("One character, several tracks. Each has its own way forward:", {TextSize = 14})
	Add("<b>Class Skills</b>: your weapon's techniques. Learn them in CLASS, equip up to 4 per weapon class on hotbar keys 1-4 (Combat Mode).", {TextSize = 13})
	Add("<b>Combat Techniques</b> and <b>Passive Skills & Traits</b>: the ARMS and BODY circles.", {TextSize = 13})
	Add("<b>Alchemy Skills</b>: your path's moves and upgrades (ALCHEMY). The path itself is taught by a trainer.", {TextSize = 13})
	Add("<b>Movement & Utility</b>: dash, climb, run and wall-run upgrades in BODY.", {TextSize = 13})
	Add("<b>Mastery & Advanced</b>: the outer rings and keystones, opened stage by stage through the Truth/Gate.", {TextSize = 13})
	Add("Mastery Points pay for all of it. Levels and Stat Points (Stats, M) are a separate track that deeper nodes ask for.", {TextSize = 13, TextColor3 = DIM})
	Add("Click any row on the left to jump to it.", {TextSize = 13, TextColor3 = DIM})
end

-- node colours from the shared verdict (owned / available / locked / fork-locked)
local Pulses = {}
function MasteryUI.Refresh()
	local D = Data()
	for _, T in pairs(Pulses) do T:Cancel() end
	Pulses = {}
	for Id, V in pairs(NodeViews) do
		local Node = SkillTree.Nodes[Id]
		local Rank = SkillTree.Rank(D, Id)
		local CanBuy = Node.Type ~= "Root" and SkillTree.CanBuy(D, Id)
		local Rival = SkillTree.ForkRival(D, Id)
		local Closed = Node.Type ~= "Root" and SkillTree.Stage(D) < SkillTree.RingStage[Node.Ring]
		V.Stroke.Transparency = 0
		if Rank > 0 then
			V.Button.BackgroundColor3 = GOLD
			V.Stroke.Color = GOLD
			V.Glyph.TextColor3 = DARK
		elseif CanBuy then
			V.Button.BackgroundColor3 = DARK
			V.Stroke.Color = GOLD
			V.Glyph.TextColor3 = GOLD
			local T = TweenService:Create(V.Stroke, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Transparency = 0.7})
			T:Play()
			table.insert(Pulses, T)
		else
			V.Button.BackgroundColor3 = Color3.fromRGB(28, 26, 24)
			V.Stroke.Color = Rival and RED or LOCKED
			V.Glyph.TextColor3 = LOCKED
		end
		V.Button.BackgroundTransparency = Closed and 0.5 or 0
		local Strike = V.Button:FindFirstChild("Strike")
		if Rival and Rank == 0 and not Strike then
			New("Frame", {Name = "Strike", BorderSizePixel = 0, BackgroundColor3 = RED, Size = UDim2.new(1.2, 0, 0, 2), AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5), Rotation = 45 - V.Button.Rotation, ZIndex = 5, Parent = V.Button})
		elseif not (Rival and Rank == 0) and Strike then
			Strike:Destroy()
		end
		V.Rank.Text = (Node.Type == "Root" or Node.Ranks <= 1) and "" or ("%d/%d"):format(Rank, Node.Ranks)
		V.Rank.TextColor3 = Rank > 0 and GOLD or DIM
		if Node.Tree == SkillTree.ClassTree then
			local Slot = Rank > 0 and ClassSkills.SlotOf(D, Node.Family, Id)
			V.Rank.Text = Slot and ("SLOT %d"):format(Slot) or (Rank > 0 and "LEARNED" or (CanBuy and "LEARNABLE" or "LOCKED"))
			V.Rank.TextColor3 = (Slot or Rank > 0) and GOLD or (CanBuy and GREEN or DIM)
		end
		if Id == Selected then V.Stroke.Color = Color3.new(1, 1, 1) V.Stroke.Thickness = 3 else V.Stroke.Thickness = 2 end
	end
	-- header: MP, stage, stage progress, and what the Truth/Gate trial still needs
	if D and D.Mastery then
		local M = D.Mastery
		Info.Text = ("<font color='#E6CD78'><b>%d MP</b></font>   Stage %d/%d   %d/%d"):format(M.Unspent or 0, M.Stage or 1,
			Progression.MaxStage, M.StageEarned or 0, Progression.MasteryPerStage)
		local Ready, Reasons = Progression.GateCheck(D)
		Gate.Text = Ready and "<font color='#E6CD78'>The Truth/Gate trial is ready.</font>" or ("Trial: " .. (Reasons[1] or ""))
		if Tree == SkillTree.ClassTree then Gate.Text = LoadoutLine(D) end
		if StyleButton then
			local OnClass = Tree == SkillTree.ClassTree
			StyleButton.Visible = OnClass
			StyleButton.Text = MasteryUI.StyleLabel()
			Gate.Size = UDim2.new(OnClass and 0.58 or 0.75, 0, 0, 34)
			if not OnClass then StylePanel.Visible = false end
		end
	end
	for Name, B in pairs(Tabs) do
		local On = Name == Tree
		B.Image = On and TAB_ON or TAB_OFF
		local Spent = SkillTree.SpentIn(D, Name)
		local Title = Name == "Alchemy" and ((Affinity() and (Affinity():upper() .. " ") or "") .. "ALCHEMY") or TREE_LABEL[Name]
		B.Head.Text = Title .. (Spent > 0 and ("  " .. Spent) or "")
		B.Head.TextColor3 = On and Color3.new(1, 1, 1) or Color3.fromRGB(190, 190, 190)
	end
	if Tree == GUIDE then MasteryUI.GuideCard() elseif Selected then MasteryUI.Card() end
end

function MasteryUI.ShowTree(Name)
	Tree = Name
	local IsGuide = Name == GUIDE
	GuideList.Visible = IsGuide
	Canvas.Visible = not IsGuide
	RecentreButton.Visible = not IsGuide
	Gate.Visible = not IsGuide
	if IsGuide then
		Selected = nil
	elseif Name == SkillTree.ClassTree then
		local First = ClassSkills.Nodes(ClassSkills.CharacterFamily(Player.Character) or ClassSkills.Order[1])[1]
		Selected = First and First.Id
	else
		Selected = SkillTree.Roots[Name]
	end
	Canvas.Position = UDim2.fromScale(0.5, 0.5)
	MasteryUI.Draw()
	MasteryUI.Select(Selected)
end

-- ===== The card =====
local function Fmt(N)
	if math.abs(N - math.floor(N)) < 1e-6 then return tostring(math.floor(N)) end
	return ("%.2f"):format(N):gsub("0+$", "")
end

-- what a node adds per rank, as text (percent keys shown as percentages)
local FLAT = {MaxStamina = true, MaxMeter = true, MeterOnHit = true, BloodCast = true, DashIFrames = true}
local function EffectText(Key, Value)
	if Key:sub(1, 6) == "Unlock" or Key == "Riposte" or Key == "SecondWind" or Key == "CastWalkSpeed" then return nil end
	if FLAT[Key] then return (Value > 0 and "+" or "") .. Fmt(Value) .. (Key == "DashIFrames" and "s" or "") end
	return (Value > 0 and "+" or "") .. Fmt(Value * 100) .. "%"
end

function MasteryUI.Card()
	for _, C in ipairs(CardBody:GetChildren()) do if C:IsA("GuiObject") then C:Destroy() end end
	local Node = Selected and SkillTree.Nodes[Selected]
	if not Node then return end
	local D = Data()
	local Rank = SkillTree.Rank(D, Selected)
	local O = 0
	local function Add(Text, Props)
		O += 1
		local L = Label(Text, Props)
		L.LayoutOrder = O
		L.AutomaticSize = Enum.AutomaticSize.Y
		L.Parent = CardBody
		return L
	end
	Add(DisplayName(Node), {FontFace = FONT_B, TextSize = 20, TextColor3 = GOLD})
	local Kind = Node.Type == "Root" and "Root  ·  owned by everyone" or (("%s  ·  %s  ·  Rank %d/%d"):format(Node.Type,
		SkillTree.RingNames[Node.Ring] or "", Rank, Node.Ranks))
	if Node.Tree == SkillTree.ClassTree then
		Kind = ("Class skill  ·  %s  ·  Tier %s  ·  %s"):format(ClassSkills.Display[Node.Family], TIER[Node.Level or 1] or "I", Rank > 0 and "Learned" or "Not learned")
	end
	Add(Kind, {TextColor3 = DIM, TextSize = 13})
	Add(DisplayText(Node), {TextSize = 15})
	-- per-rank effect, now and next
	local Parts = {}
	for _, E in ipairs(Node.Effects) do
		local T = EffectText(E[1], E[2])
		if T then table.insert(Parts, T) end
	end
	if #Parts > 0 and Node.Ranks > 1 then Add(("Per rank: %s"):format(table.concat(Parts, ", ")), {TextColor3 = GREEN, TextSize = 14}) end
	-- (a learned class skill skips its cost and requirements, so the equip row stays in view)
	if Node.Type ~= "Root" and not (Node.Tree == SkillTree.ClassTree and Rank > 0) then
		if Node.Fork then
			local Pair = {}
			for Id, Other in pairs(SkillTree.Nodes) do if Id ~= Selected and Other.Fork == Node.Fork then table.insert(Pair, DisplayName(Other)) end end
			Add("<i>Fork: you can own this or " .. table.concat(Pair, ", ") .. ", not both.</i>", {TextColor3 = DIM, TextSize = 13})
		end
		Add(("Cost: <b>%d MP</b>%s"):format(Node.Cost, Node.Ranks > 1 and " per rank" or ""), {TextSize = 14})
		for _, R in ipairs(SkillTree.Requirements(D, Selected)) do
			Add((R[2] and "✓ " or "✗ ") .. R[1], {TextSize = 14, TextColor3 = R[2] and GREEN or RED})
		end
	end
	if Node.Tree == SkillTree.ClassTree then
		local Def = ClassSkills.Def(Selected)
		if Def then
			local Hits = #(Def.HitTimes or {1})
			Add(("Cooldown %ss  ·  Stamina %d  ·  %d hit%s%s"):format(Fmt(Def.Cooldown), Def.Stamina or 0, Hits, Hits == 1 and "" or "s",
				Def.HyperArmor and "  ·  hyper armour" or ""), {TextSize = 13, TextColor3 = TEXT})
		end
		local Fits = Node.Family == ClassSkills.CharacterFamily(Player.Character)
		Add(Fits and "Fits the class you're fighting as." or ("Needs a %s class to use (equip one from the Bag)."):format(ClassSkills.Display[Node.Family]),
			{TextSize = 13, TextColor3 = Fits and GREEN or DIM})
		if not MasteryUI.FindAnim(Node.Preview and Node.Preview.Anim) then Add("Animation missing: this skill can't play yet.", {TextSize = 13, TextColor3 = RED}) end
		if Rank > 0 then
			local Loadout = ClassSkills.Loadout(D, Node.Family)
			local Slot = ClassSkills.SlotOf(D, Node.Family, Selected)
			Add(("Equip to a hotbar key (%s, used in Combat Mode):"):format(ClassSkills.Display[Node.Family]), {TextSize = 13, TextColor3 = DIM})
			O += 1
			local Row = New("Frame", {Name = "Equip", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = O, Parent = CardBody})
			for I = 1, ClassSkills.Slots do
				local On = Slot == I
				local Btn = New("TextButton", {Name = "Slot" .. I, Text = tostring(I), FontFace = FONT_B, TextSize = 15, TextColor3 = On and DARK or GOLD,
					BackgroundColor3 = On and GOLD or DARK, BackgroundTransparency = Pending and 0.5 or 0, Size = UDim2.new(0.16, -4, 1, 0),
					Position = UDim2.fromScale((I - 1) * 0.16, 0), Parent = Row},
					{New("UICorner", {CornerRadius = UDim.new(0, 4)}), New("UIStroke", {Color = GOLD, Transparency = 0.3})})
				Btn.Activated:Connect(function() if Slot ~= I then MasteryUI.Act("Equip", I) end end)
			end
			if Slot then
				local Off = New("TextButton", {Name = "Remove", Text = "REMOVE", FontFace = FONT_B, TextSize = 13, TextColor3 = TEXT, BackgroundColor3 = DARK,
					Size = UDim2.new(0.34, 0, 1, 0), Position = UDim2.fromScale(0.66, 0), Parent = Row},
					{New("UICorner", {CornerRadius = UDim.new(0, 4)}), New("UIStroke", {Color = RED, Transparency = 0.3})})
				Off.Activated:Connect(function() MasteryUI.Act("Unequip", Slot) end)
			end
			local Parts = {}
			for I, Id in ipairs(Loadout) do table.insert(Parts, ("%d %s"):format(I, Id ~= "" and SkillTree.Nodes[Id].Name or "—")) end
			Add(table.concat(Parts, "   "), {TextSize = 12, TextColor3 = DIM})
		end
	end
	-- Buy / Refund
	local CanBuy, Why = SkillTree.CanBuy(D, Selected)
	local CanRefund = SkillTree.CanRefund(D, Selected)
	local BuyB, RefB = Preview.Buttons.Buy, Preview.Buttons.Refund
	BuyB.Visible = Node.Type ~= "Root"
	RefB.Visible = Node.Type ~= "Root" and CanRefund
	BuyB.Size = RefB.Visible and UDim2.fromScale(0.48, 1) or UDim2.fromScale(1, 1)
	BuyB.ImageTransparency = (CanBuy and not Pending) and 0 or 0.55
	BuyB.Label.Text = Pending and "..." or (CanBuy and ((Node.Tree == SkillTree.ClassTree and "LEARN" or "BUY") .. ("  ·  %d MP"):format(Node.Cost)) or (Rank >= Node.Ranks and (Node.Tree == SkillTree.ClassTree and "LEARNED" or "MAXED") or (Why or "LOCKED"):upper()))
	BuyB.Label.TextSize = CanBuy and 16 or 12
end

function MasteryUI.Act(Action, Slot)
	local Node = Selected and SkillTree.Nodes[Selected]
	if not Node or Pending then return end
	local D = Data()
	if Action == "Buy" then
		if not SkillTree.CanBuy(D, Selected) then return end
		Pending = true
		UIState.Request("SkillTree", "Buy", Selected, SkillTree.Rank(D, Selected))
	elseif Action == "Equip" then
		if not ClassSkills.CanEquip(D, Selected, Slot) then return end
		Pending = true
		UIState.Request("SkillTree", "Equip", Selected, Slot)
	elseif Action == "Unequip" then
		Pending = true
		UIState.Request("SkillTree", "Unequip", Node.Family, Slot)
	else
		if not SkillTree.CanRefund(D, Selected) then return end
		Pending = true
		UIState.Request("SkillTree", "Refund", Selected)
	end
	MasteryUI.Card()
	task.delay(4, function() if Pending then Pending = false MasteryUI.Card() end end) -- (never stuck)
end

-- ===== Preview =====
local AnimIndex = nil
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Registered = {}
local ANIM_ALIAS = {Heavy = "FistHeavy"}
local function FindAnim(Name)
	if not AnimIndex then
		AnimIndex = {}
		for _, A in ipairs(ReplicatedStorage.Assets.Animations:GetDescendants()) do
			if A:IsA("Animation") then AnimIndex[A.Name] = A end
		end
	end
	local A = AnimIndex[Name] or AnimIndex[ANIM_ALIAS[Name] or ""]
	if not A then return nil end
	if A.AnimationId ~= "" and not (A:GetAttribute("StudioPrefersSave") and RunService:IsStudio()) then return A end
	-- an unpublished one (a KeyframeSequence named Save): playable in Studio only, like AnimationManager
	if Registered[A] then return Registered[A] end
	local Save = RunService:IsStudio() and A:FindFirstChildOfClass("KeyframeSequence")
	if not Save then return A.AnimationId ~= "" and A or nil end
	local Ok, Id = pcall(KeyframeSequenceProvider.RegisterKeyframeSequence, KeyframeSequenceProvider, Save)
	if not Ok then return nil end
	Registered[A] = New("Animation", {AnimationId = Id})
	return Registered[A]
end
MasteryUI.FindAnim = FindAnim -- (the card, defined above, checks a class skill's animation)

local function StripModel(Model)
	for _, D in ipairs(Model:GetDescendants()) do
		if D:IsA("BaseScript") or D:IsA("Tool") or D:IsA("ForceField") or D:IsA("BillboardGui") or D:IsA("Sound")
			or D:IsA("ParticleEmitter") or D:IsA("ProximityPrompt") then
			D:Destroy()
		elseif D:IsA("BasePart") then
			D.Anchored = D.Name == "HumanoidRootPart"
			D.CanCollide = false
		end
	end
end

local function BuildPreview()
	local VF = Preview.Frame
	for _, C in ipairs(VF:GetChildren()) do if not C:IsA("UICorner") then C:Destroy() end end
	local World = New("WorldModel", {Parent = VF})
	local Camera = New("Camera", {FieldOfView = 40, Parent = VF})
	VF.CurrentCamera = Camera
	local Source = Player.Character or game.StarterPlayer:FindFirstChild("StarterCharacter")
	if not Source then return end
	local Was = Source.Archivable
	Source.Archivable = true
	local Rig = Source:Clone()
	Source.Archivable = Was
	StripModel(Rig)
	-- the rig faces +X toward the dummy; the camera looks from the front-left so both read
	Rig:PivotTo(CFrame.lookAt(Vector3.new(0, 3, 0), Vector3.new(7, 3, 0)))
	Rig.Parent = World
	local Starter = game.StarterPlayer:FindFirstChild("StarterCharacter")
	if Starter then
		local Dummy = Starter:Clone()
		StripModel(Dummy)
		for _, P in ipairs(Dummy:GetDescendants()) do
			if P:IsA("BasePart") then P.Anchored = true P.Color = Color3.fromRGB(120, 112, 100) end
			if P:IsA("Decal") or P:IsA("Clothing") or P:IsA("Accessory") then P:Destroy() end
		end
		Dummy:PivotTo(CFrame.lookAt(Vector3.new(7, 3, 0), Vector3.new(0, 3, 0)))
		Dummy.Parent = World
		Preview.Dummy = Dummy
	end
	local Focus = Vector3.new(2.6, 2.7, 0)
	Camera.CFrame = CFrame.lookAt(Focus + Vector3.new(6.5, 1.8, -9.5), Focus) -- front three-quarter of the rig, dummy beside
	local Humanoid = Rig:FindFirstChildOfClass("Humanoid")
	Preview.Rig = Rig
	Preview.Animator = Humanoid and (Humanoid:FindFirstChildOfClass("Animator") or New("Animator", {Parent = Humanoid}))
	Preview.World = World
end

local function PlayAnim(Name, Speed)
	local A = Name and FindAnim(Name)
	if not A or not Preview.Animator then return nil end
	local Ok, Track = pcall(function() return Preview.Animator:LoadAnimation(A) end)
	if not Ok then return nil end
	Track.Priority = Enum.AnimationPriority.Action
	Track:Play(0.1, 1, Speed or 1)
	return Track
end

local function Burst(Color)
	if not Preview.Dummy or not Preview.World then return end
	local At = Preview.Dummy:GetPivot().Position
	local Ball = New("Part", {Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, Color = Color, Anchored = true, CanCollide = false,
		Size = Vector3.one * 1, CFrame = CFrame.new(At), Transparency = 0.1, Parent = Preview.World})
	TweenService:Create(Ball, TweenInfo.new(0.45, Enum.EasingStyle.Quad), {Size = Vector3.one * 6, Transparency = 1}):Play()
	task.delay(0.5, function() Ball:Destroy() end)
end

-- the stat a passive changes: now -> next rank
local function StatBars(Node)
	for _, C in ipairs(Preview.Bars:GetChildren()) do if C:IsA("GuiObject") then C:Destroy() end end
	local P = Node.Preview
	local D = Data()
	local Rank = SkillTree.Rank(D, Node.Id)
	local Per = 0
	for _, E in ipairs(Node.Effects) do Per += E[2] end
	local function Line(Title, Value, Max, Color)
		local Row = New("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, 34), Parent = Preview.Bars})
		Label(Title, {TextSize = 13, TextColor3 = DIM, Parent = Row})
		local Track = New("Frame", {BackgroundColor3 = Color3.fromRGB(35, 32, 28), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 8),
			Position = UDim2.fromOffset(0, 20), Parent = Row}, {New("UICorner", {CornerRadius = UDim.new(0, 4)})})
		New("Frame", {BackgroundColor3 = Color, BorderSizePixel = 0, Size = UDim2.fromScale(math.clamp(Value / Max, 0.03, 1), 1), Parent = Track},
			{New("UICorner", {CornerRadius = UDim.new(0, 4)})})
	end
	local Label1 = P.Label or Node.Name
	if P.Base then
		local Now = P.Base + Per * Rank
		local Next = P.Base + Per * math.min(Rank + 1, Node.Ranks)
		local Max = P.Base + Per * Node.Ranks
		if Per < 0 then Max = P.Base end
		Line(("%s now: %s%s"):format(Label1, Fmt(Now), P.Unit or ""), Now, Max, GOLD)
		if Rank < Node.Ranks then Line(("Next rank: %s%s"):format(Fmt(Next), P.Unit or ""), Next, Max, GREEN) end
	else
		local Now, Next, Max = Per * Rank * 100, Per * math.min(Rank + 1, Node.Ranks) * 100, math.abs(Per * Node.Ranks * 100)
		Line(("%s now: %s%%"):format(Label1, (Now > 0 and "+" or "") .. Fmt(Now)), math.abs(Now), Max, GOLD)
		if Rank < Node.Ranks then Line(("Next rank: %s%%"):format((Next > 0 and "+" or "") .. Fmt(Next)), math.abs(Next), Max, GREEN) end
	end
end

local PreviewToken = 0
local function RunPreview(Node)
	PreviewToken += 1
	local Token = PreviewToken
	local P = Node and Node.Preview
	if not P then Preview.Frame.Visible, Preview.Bars.Visible = false, false return end
	if P.Kind == "Stat" then
		Preview.Frame.Visible, Preview.Bars.Visible = false, true
		StatBars(Node)
		return
	end
	Preview.Frame.Visible, Preview.Bars.Visible = true, false
	task.spawn(function()
		while Token == PreviewToken and Root.Visible do
			if Preview.Animator then
				for _, T in ipairs(Preview.Animator:GetPlayingAnimationTracks()) do T:Stop(0.1) end
			end
			if P.Kind == "Alchemy" then
				local Move = MoveFor(P.Slot)
				local Def = Move and Tuning.Alchemy and Tuning.Alchemy.Abilities and Tuning.Alchemy.Abilities[Move.Id]
				local Clap = PlayAnim("Alchemy_Clap")
				task.wait(Clap and math.min(Clap.Length, 0.8) or 0.5)
				if Token ~= PreviewToken then break end
				PlayAnim(Def and Def.Anim or "Alchemy_Fire1")
				task.wait(0.35)
				Burst(ELEMENT[Affinity() or ""] or GOLD)
			else
				PlayAnim(P.Anim)
			end
			task.wait(3)
		end
	end)
end

function MasteryUI.Select(Id)
	Selected = Id
	MasteryUI.Refresh()
	RunPreview(SkillTree.Nodes[Id])
end

-- ===== Start =====
function MasteryUI.Start()
	Gui = UIState.Gui
	BuildPanel()
	UIState.RegisterMenu("Mastery", Root, function()
		Pending = false
		BuildPreview()
		MasteryUI.ShowTree(Tree)
	end)
	UIState.Changed:Connect(function()
		Pending = false
		if Root.Visible then MasteryUI.Draw() end
	end)
	ReplicatedStorage.Remotes.RequestRemote.OnClientEvent:Connect(function(Kind, Ok)
		if Kind ~= "SkillTree" then return end
		Pending = false
		if Root.Visible then MasteryUI.Card() end
	end)
	Root:GetPropertyChangedSignal("Visible"):Connect(function()
		if not Root.Visible then PreviewToken += 1 end -- stop the preview loop
	end)
end

return MasteryUI

-- MenuKit: builds an on-theme panel from the Settings panel's own art (frame, header plate, tab art,
-- row plates, Enable / Disable buttons, the key-bind box) -- the same approach as AdminUI -- for
-- the Journal and the minigames. Rows rebuilt by a live refresh can skip the UIMotion pop-in
-- (Kit.Quiet = true -> rows get NoPop).
--
--   local Kit = MenuKit.new("Journal", "JOURNAL", {"Quests", "Evidence", "Case Board", "Codex"}, OnTab)
--   Kit:Clear(); local Row, Controls = Kit:Row("Title", 0.44); Kit:Button(Controls, "Go", Fn)

local UIState = require(script.Parent.UIState)

local GOLD = Color3.fromRGB(230, 205, 120)
local DIM = Color3.fromRGB(150, 150, 150)

local MenuKit = {}
MenuKit.__index = MenuKit
MenuKit.Gold = GOLD

function MenuKit.new(Name, Title, Tabs, OnTab)
	local Gui = UIState.Gui
	local self = setmetatable({}, MenuKit)
	local Source = Gui.Settings
	self.Root = Source:Clone()
	self.Root.Name = Name
	self.Main = self.Root.MainFrame
	self.Rows = self.Main.Container
	self.Sections = self.Main.Sections
	self.Main.Header.Head.Text = Title
	self.Order = 0
	self.Quiet = false

	local Rows = self.Rows
	Rows.ClipsDescendants = true
	Rows.ScrollingEnabled = true
	Rows.ScrollBarThickness = 4
	Rows.ScrollBarImageColor3 = GOLD
	Rows.AutomaticCanvasSize = Enum.AutomaticSize.Y
	Rows.CanvasSize = UDim2.new()

	-- prototypes from the authored rows
	local Toggle = Rows:FindFirstChild("CameraShake")
	local Key = Rows:FindFirstChild("Dash")
	self.RowProto = Toggle:Clone()
	for _, C in ipairs(self.RowProto.Controls:GetChildren()) do
		if C:IsA("GuiObject") then C:Destroy() end
	end
	self.RowProto:SetAttribute("Tab", nil)
	self.RowProto:SetAttribute("Kind", nil)
	self.ButtonProto = Toggle.Controls.Enable:Clone()
	self.DangerProto = Toggle.Controls.Disable:Clone()
	self.BoxProto = Key.Controls.Bind:Clone()
	for _, R in ipairs(Rows:GetChildren()) do
		if R:IsA("GuiObject") then R:Destroy() end
	end

	-- tabs: the Settings tab art, relabelled (extra tab buttons removed)
	local Old = {}
	for _, T in ipairs(self.Sections:GetChildren()) do if T:IsA("ImageButton") then table.insert(Old, T) end end
	table.sort(Old, function(X, Y) return X.Position.X.Scale < Y.Position.X.Scale end)
	local Plain = Source.MainFrame.Sections.Graphics.Image -- the art without a baked-in word
	self.TabNames = Tabs or {}
	-- more tabs than the Settings art has (the Journal's Identities, 2026-10-18): clone the art's last tab
	-- and share the strip evenly (the authored four span about 1.045 of it). Four or fewer keep their size.
	while #Old < #self.TabNames and #Old > 0 do
		local Extra = Old[#Old]:Clone()
		Extra.Parent = self.Sections
		table.insert(Old, Extra)
	end
	if #self.TabNames > 4 then
		local Share = 1.045 / #self.TabNames
		for _, T in ipairs(Old) do T.Size = UDim2.new(Share, 0, T.Size.Y.Scale, T.Size.Y.Offset) end
	end
	self.Tab = self.TabNames[1]
	for I, T in ipairs(Old) do
		local TabName = self.TabNames[I]
		if TabName then
			T.Name = TabName
			T.Image = Plain
			T.LayoutOrder = I
			if T:FindFirstChild("Head") then T.Head.Text = TabName end
			T.Activated:Connect(function()
				self.Tab = TabName
				Rows.CanvasPosition = Vector2.zero
				self:PaintTabs()
				if OnTab then OnTab(TabName) end
			end)
		else
			T:Destroy()
		end
	end
	self.Sections.Visible = #self.TabNames > 0
	self.Root.Parent = Gui
	self.Root.Visible = false
	self:PaintTabs()
	return self
end

function MenuKit:PaintTabs()
	for _, T in ipairs(self.Sections:GetChildren()) do
		if T:IsA("ImageButton") then
			local Active = T.Name == self.Tab
			T.ImageColor3 = Active and Color3.new(1, 1, 1) or DIM
			if T:FindFirstChild("Head") then T.Head.TextColor3 = Active and GOLD or Color3.fromRGB(190, 190, 190) end
		end
	end
end

-- Animate: rows pop in (UIMotion); otherwise they are swapped in place (NoPop)
function MenuKit:Clear(Animate)
	self.Scroll = self.Rows.CanvasPosition
	for _, R in ipairs(self.Rows:GetChildren()) do
		if R:IsA("GuiObject") then R:Destroy() end
	end
	self.Order = 0
	self.Quiet = Animate ~= true
end

function MenuKit:KeepScroll()
	if self.Scroll then self.Rows.CanvasPosition = self.Scroll end
end

-- Width: the title's share of the row (authored 0.4). Lines: row height in authored rows.
function MenuKit:Row(Title, Width, Lines)
	self.Order += 1
	local R = self.RowProto:Clone()
	if self.Quiet then R:SetAttribute("NoPop", true) end
	R.Name = "Row" .. self.Order
	R.LayoutOrder = self.Order
	R.Title.Text = Title or ""
	if Width then R.Title.Size = UDim2.new(Width, 0, R.Title.Size.Y.Scale, 0) end
	if Lines and Lines > 1 then
		R.Size = UDim2.new(R.Size.X.Scale, R.Size.X.Offset, R.Size.Y.Scale * Lines, R.Size.Y.Offset)
		R.Title.Size = UDim2.new(R.Title.Size.X.Scale, 0, math.min(0.86, R.Title.Size.Y.Scale * 1.6), 0)
		R.Title.TextWrapped = true
		R.Title.TextScaled = true
		R.Title.TextYAlignment = Enum.TextYAlignment.Center
		local Cap = R.Title:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
		Cap.MaxTextSize = 15
		Cap.Parent = R.Title
	end
	R.Visible = true
	R.Parent = self.Rows
	return R, R.Controls
end

function MenuKit:Heading(Text)
	local R = self:Row(Text, 0.92)
	R.ImageTransparency = 0.6
	R.Title.TextColor3 = GOLD
	return R
end

-- a wrapped paragraph row (journal text, evidence descriptions)
function MenuKit:Paragraph(Text, Lines)
	local R = self:Row(Text, 0.92, Lines or 2)
	R.ImageTransparency = 0.35
	R.Title.TextColor3 = Color3.fromRGB(215, 210, 200)
	return R
end

function MenuKit:Fit(Controls)
	local N = 0
	for _, C in ipairs(Controls:GetChildren()) do if C:IsA("GuiObject") then N += 1 end end
	if N <= 3 then return end
	for _, C in ipairs(Controls:GetChildren()) do
		if C:IsA("GuiObject") then C.Size = UDim2.new(0.52 / N, 0, C.Size.Y.Scale, 0) end
	end
end

function MenuKit:Button(Controls, Text, OnClick, Danger, Width)
	local B = (Danger and self.DangerProto or self.ButtonProto):Clone()
	B.Name = Text
	B.Head.Text = Text
	B.LayoutOrder = #Controls:GetChildren()
	if Width then B.Size = UDim2.new(Width, 0, B.Size.Y.Scale, 0) end
	B.Parent = Controls
	if OnClick then B.Activated:Connect(OnClick) end
	return B
end

function MenuKit:Label(Controls, Text, Width)
	local L = self.BoxProto:Clone()
	L.Name = "Label"
	L.LayoutOrder = #Controls:GetChildren()
	L.Head.Text = Text
	L.Active = false
	L.AutoButtonColor = false
	if Width then L.Size = UDim2.new(Width, 0, L.Size.Y.Scale, 0) end
	L.Parent = Controls
	return L
end

-- a cycler: < Label > over Options (strings); Index is 1-based; OnChange(newIndex)
function MenuKit:Cycler(Controls, Options, Index, OnChange, LabelWidth)
	local N = #Options
	if N == 0 then return self:Label(Controls, "-", LabelWidth) end
	Index = (Index - 1) % N + 1
	self:Button(Controls, "<", function() OnChange((Index - 2) % N + 1) end, false, 0.07)
	local L = self:Label(Controls, Options[Index], LabelWidth)
	self:Button(Controls, ">", function() OnChange(Index % N + 1) end, false, 0.07)
	return L
end

return MenuKit

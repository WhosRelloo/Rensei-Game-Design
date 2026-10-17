-- Always-on HUD: vitals bars, cash, hotbar, nearby enemy bars, boss bar, leaderboard, server info
-- and the quest tracker. Reads replicated state only (humanoids, attributes, the synced profile).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local UIState = require(script.Parent.UIState)
local Fill = require(script.Parent.Fill)
local ResourceManager = require(ReplicatedStorage.Modules.Managers.ResourceManager)
local ItemData = require(ReplicatedStorage.Modules.Data.ItemData)
local QuestDefs = require(ReplicatedStorage.Modules.Data.Rensei.Quests)
local StoryLogic = require(ReplicatedStorage.Modules.Data.Rensei.StoryLogic)

local Player = Players.LocalPlayer
local Gui = UIState.Gui
local HUD = Gui.HUD
local Templates = Gui.Templates

local NPC_RANGE = 60
local BOSS_RANGE = 220
local MAX_NPC_BARS = 3
local MAX_QUESTS = 3

local HUDUI = {}

-- ===== Vitals =====
-- Gold segmented = Stamina, red = Health, orange = Posture, cyan = Transmutation Meter.
local function UpdateVitals()
	local Character = Player.Character
	local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
	local Bars = HUD.Stats
	if Humanoid and Humanoid.MaxHealth > 0 then
		Fill.Set(Bars.RedBar.Bar, Humanoid.Health / Humanoid.MaxHealth)
	end
	if Character then
		for BarName, Resource in pairs({YellowBar = "Stamina", PostureBar = "Posture", BlueBar = "Meter"}) do
			local Bar = Bars:FindFirstChild(BarName)
			if Bar then
				Fill.Set(Bar.Bar, ResourceManager.Get(Character, Resource) / ResourceManager.Max(Character, Resource))
			end
		end
	end
end

-- ===== Hover values on the vitals bars =====
local BarInfo = {
	{Bar = "RedBar", Label = "Health"},
	{Bar = "YellowBar", Label = "Stamina", Resource = "Stamina"},
	{Bar = "PostureBar", Label = "Posture", Resource = "Posture"},
	{Bar = "BlueBar", Label = "Meter", Resource = "Meter"},
}
local Hovered = nil

local function SetupHoverValues()
	local Bars = HUD.Stats
	for _, Info in ipairs(BarInfo) do
		local Bar = Bars:FindFirstChild(Info.Bar)
		if Bar then
			local L = HUD.CashFrame.Display:Clone()
			for _, K in ipairs(L:GetChildren()) do if not K:IsA("UIStroke") then K:Destroy() end end
			L.Name = "HoverValue"
			L.BackgroundTransparency = 1
			L.AnchorPoint = Vector2.new(0.5, 0.5)
			L.Position = UDim2.fromScale(0.5, 0.5)
			L.Size = UDim2.fromScale(0.6, Info.Bar == "RedBar" and 0.55 or 1.6)
			L.TextColor3 = Color3.new(1, 1, 1)
			L.ZIndex = Bar.ZIndex + 5
			L.Visible = false
			L.Parent = Bar
			Bar.MouseEnter:Connect(function() Hovered = Info L.Visible = true end)
			Bar.MouseLeave:Connect(function() if Hovered == Info then Hovered = nil end L.Visible = false end)
		end
	end
end

local function UpdateHoverValue()
	if not Hovered then return end
	local Character = Player.Character
	local Bar = HUD.Stats:FindFirstChild(Hovered.Bar)
	local L = Bar and Bar:FindFirstChild("HoverValue")
	if not Character or not L then return end
	local Value, Max
	if Hovered.Resource then
		Value, Max = ResourceManager.Get(Character, Hovered.Resource), ResourceManager.Max(Character, Hovered.Resource)
	else
		local Humanoid = Character:FindFirstChildOfClass("Humanoid")
		if not Humanoid then return end
		Value, Max = Humanoid.Health, Humanoid.MaxHealth
	end
	L.Text = ("%s  %s / %s"):format(Hovered.Label, UIState.Format(Value), UIState.Format(Max))
end

-- ===== Hotbar =====
local SlotOrder = {"1","2","3","4","5","6","7","8","9","0"}
local KeyToSlot = {
	[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5, [Enum.KeyCode.Six] = 6, [Enum.KeyCode.Seven] = 7, [Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9, [Enum.KeyCode.Zero] = 0,
}

function HUDUI.ItemIcon(Parent, ItemName, ItemInfo)
	local Old = Parent:FindFirstChild("Icon")
	if Old then Old:Destroy() end
	if not ItemName then return end
	local Folder = ItemInfo and ReplicatedStorage.Assets.Items:FindFirstChild(ItemInfo.Type)
	local Source = Folder and Folder:FindFirstChild(ItemName)
	local Icon
	if Source then
		Icon = Instance.new("ViewportFrame")
		Icon.BackgroundTransparency = 1
		Icon.Ambient = Color3.fromRGB(200, 200, 200)
		Icon.LightColor = Color3.fromRGB(255, 255, 255)
		local Model = Instance.new("Model")
		-- visible parts only (weapon grip helpers are invisible and would skew the framing)
		for _, D in ipairs(Source:GetDescendants()) do
			if D:IsA("BasePart") and D.Transparency < 1 then
				local P = D:Clone()
				for _, K in ipairs(P:GetChildren()) do if K:IsA("LuaSourceContainer") or K:IsA("JointInstance") or K:IsA("WeldConstraint") then K:Destroy() end end
				P.Anchored = true
				P.Parent = Model
			end
		end
		Model.Parent = Icon
		local Cam = Instance.new("Camera")
		Cam.FieldOfView = 30
		-- view from the side of the longest axis so long blades fill the icon, slightly from above
		local CF, Size = Model:GetBoundingBox()
		local Axes = {{CF.RightVector, Size.X}, {CF.UpVector, Size.Y}, {CF.LookVector, Size.Z}}
		table.sort(Axes, function(A, B) return A[2] > B[2] end)
		local Long, Second = Axes[1], Axes[2]
		local Side = Long[1]:Cross(Second[1]).Unit -- perpendicular to the two largest dimensions
		local Fit = math.max(Long[2], Second[2] * 1.2) / 2 / math.tan(math.rad(Cam.FieldOfView / 2)) * 1.08
		local Up = Second[1]
		Cam.CFrame = CFrame.lookAt(CF.Position + (Side + Up * 0.15).Unit * (Fit + Axes[3][2]), CF.Position, Up)
		Cam.Parent = Icon
		Icon.CurrentCamera = Cam
	else
		Icon = Instance.new("TextLabel")
		Icon.BackgroundTransparency = 1
		Icon.TextScaled = true
		Icon.TextColor3 = Color3.new(1, 1, 1)
		Icon.Text = ItemName
		Icon.FontFace = HUD.CashFrame.Display.FontFace
	end
	Icon.Name = "Icon"
	Icon.AnchorPoint = Vector2.new(0.5, 0.5)
	Icon.Position = UDim2.fromScale(0.5, 0.5)
	Icon.Size = UDim2.fromScale(0.62, 0.62)
	Icon.ZIndex = Parent.ZIndex + 1
	Icon.Parent = Parent
	return Icon
end

local HotbarShown = {}
local function UpdateHotbar()
	local Data = UIState.Data
	if not Data then return end
	local Held = nil
	local Character = Player.Character
	if Character then
		-- the held hotbar item (the weapon Tool sits beside it and is never on the hotbar)
		for _, Tool in ipairs(Character:GetChildren()) do
			local Info = Tool:IsA("Tool") and ItemData[Tool.Name]
			if Info and Info.Type ~= "Weapon" then Held = Tool.Name end
		end
	end
	for _, Key in ipairs(SlotOrder) do
		local Slot = HUD.Bottom:FindFirstChild("Slot" .. Key)
		if Slot then
			local Index = Data.Hotbar[Key]
			local Item = type(Index) == "number" and Data.Inventory[Index]
			local Name = Item and Item.ItemName
			if HotbarShown[Key] ~= Name then
				HotbarShown[Key] = Name
				HUDUI.ItemIcon(Slot, Name, Name and ItemData[Name])
			end
			Slot.ImageColor3 = (Name and Name == Held) and Color3.fromRGB(255, 225, 160) or Color3.new(1, 1, 1)
		end
	end
end

local function UseSlot(Number)
	if Gui.Dialogue.Visible then return end
	UIState.Request("HoldItem", Number)
end

-- ===== Enemy and boss bars =====
local NpcBars = {}
local function BarFor(Index)
	local Bar = NpcBars[Index]
	if not Bar then
		Bar = Templates.NpcTemplate:Clone()
		Bar.Name = "Npc" .. Index
		Bar.AnchorPoint = Vector2.new(0, 0)
		Bar.Position = UDim2.new()
		Bar.Size = UDim2.fromScale(1, 0.28)
		Bar.LayoutOrder = Index
		local AR = Bar:FindFirstChildOfClass("UIAspectRatioConstraint")
		if AR then AR:Destroy() end
		Bar.Parent = HUD.Npcs
		NpcBars[Index] = Bar
	end
	return Bar
end

local function UpdateTargets()
	local Root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
	local Live = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Live")
	local Near, Boss, BossDist = {}, nil, BOSS_RANGE
	if Root and Live then
		for _, Model in ipairs(Live:GetChildren()) do
			local Humanoid = Model:IsA("Model") and Model:FindFirstChildOfClass("Humanoid")
			local MRoot = Humanoid and Model:FindFirstChild("HumanoidRootPart")
			if MRoot and Humanoid.Health > 0 and Humanoid.MaxHealth < 1e9 and not Players:GetPlayerFromCharacter(Model) then
				local Dist = (MRoot.Position - Root.Position).Magnitude
				if Model:GetAttribute("Boss") then
					if Dist < BossDist then Boss, BossDist = Model, Dist end
				elseif Dist <= NPC_RANGE then
					table.insert(Near, {Model = Model, Humanoid = Humanoid, Dist = Dist})
				end
			end
		end
	end
	table.sort(Near, function(A, B) return A.Dist < B.Dist end)
	for I = 1, MAX_NPC_BARS do
		local Entry = Near[I]
		local Bar = NpcBars[I] or (Entry and BarFor(I))
		if Bar then
			Bar.Visible = Entry ~= nil
			if Entry then
				Bar.Head.Text = Entry.Model:GetAttribute("DisplayName") or Entry.Model.Name
				local Level = Entry.Model:GetAttribute("Level")
				Bar.Text.Text = Level and ("lvl " .. Level) or ""
				Fill.Set(Bar.Bar, Entry.Humanoid.Health / Entry.Humanoid.MaxHealth)
			end
		end
	end

	local BossBar = HUD.BossHealth
	BossBar.Visible = Boss ~= nil
	if Boss then
		local Humanoid = Boss:FindFirstChildOfClass("Humanoid")
		BossBar.Head.Text = Boss:GetAttribute("DisplayName") or Boss.Name
		BossBar.Text.Text = Boss:GetAttribute("Title") or ""
		BossBar.HP.Text = UIState.Format(Humanoid.Health) .. " / " .. UIState.Format(Humanoid.MaxHealth)
		Fill.Set(BossBar.Bar, Humanoid.Health / Humanoid.MaxHealth)
	end
end

-- ===== Leaderboard =====
-- Columns Name (the Roblox display name), Lv, Title (the earned alchemist rank), Clan. Hover a name,
-- or tap it on mobile, for a card: username, display name, level, title, clan, rank and promotion
-- status. Every value is an attribute the server sets on the Player (ProgressionService.Sync ->
-- RankService.Publish); rows are keyed by the Player instance, never by a name, so two players
-- with the same display name stay apart. Until a save has loaded (ProfileReady) the row says
-- "Loading" rather than guessing. Read-only: nothing here sends anything to the server.
-- Art: the game's own HUD pieces -- the Server Info panel and its header banner (HUD.Server), and
-- the leaderboard row bar (Templates.LeaderEntry) behind each row.
local Ranks = require(ReplicatedStorage.Modules.Data.Rensei.Ranks)
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local LB_FONT = Font.new("rbxasset://fonts/families/Guru.json")
local LB_BOLD = Font.new("rbxasset://fonts/families/Guru.json", Enum.FontWeight.Bold)
local LB_GOLD = Color3.fromRGB(230, 205, 120)
local LB_TEXT = Color3.fromRGB(225, 220, 210)
local LB_DIM = Color3.fromRGB(150, 145, 135)
local LB_EDGE = Color3.fromRGB(120, 100, 60)
local RANK_COLORS = {LB_TEXT, Color3.fromRGB(150, 180, 220), LB_GOLD, Color3.fromRGB(215, 95, 85)}
local ART_PANEL = "rbxassetid://119335349346175" -- HUD.Server.main
local ART_ROW = "rbxassetid://117415375236383" -- Templates.LeaderEntry
local ROW_H, HEAD_H, BANNER_H, MAX_ROWS = 24, 18, 28, 10
local INSET = 0.05 -- keeps text clear of the row bar's end caps
local COLUMNS = {{Key = "Name", Head = "Name", W = 0.34}, {Key = "Level", Head = "Lv", W = 0.1},
	{Key = "Title", Head = "Title", W = 0.32}, {Key = "Clan", Head = "Clan", W = 0.24}}

local Board -- {Root, List, Scale, CardScale}
local Rows = {} -- [Player] = {Frame, Art, Cells, Conn, NameConn}
local Dirty = true

local function LbText(Parent, Props)
	local L = Instance.new(Props.Button and "TextButton" or "TextLabel")
	Props.Button = nil
	L.BackgroundTransparency = 1
	L.FontFace = LB_FONT
	L.TextColor3 = LB_TEXT
	L.TextSize = 15
	L.TextXAlignment = Enum.TextXAlignment.Left
	L.TextTruncate = Enum.TextTruncate.AtEnd
	if L:IsA("TextButton") then L.AutoButtonColor = false end
	for K, V in pairs(Props) do L[K] = V end
	L.Parent = Parent
	return L
end

local function Art(Parent, Image, ZIndex)
	local A = Instance.new("ImageLabel")
	A.Name = "Art"
	A.BackgroundTransparency = 1
	A.Image = Image
	A.ScaleType = Enum.ScaleType.Stretch
	A.Size = UDim2.fromScale(1, 1)
	A.ZIndex = ZIndex or 0
	A.Parent = Parent
	return A
end

-- the Server Info header banner, retitled (nil if the HUD doesn't have it)
local function Banner(Parent, Text)
	local Proto = HUD:FindFirstChild("Server") and HUD.Server:FindFirstChild("Header")
	if not Proto then return nil end
	local B = Proto:Clone()
	B.Name = "Banner"
	B.AnchorPoint = Vector2.new(0.5, 0)
	B.Position = UDim2.fromScale(0.5, 0)
	B.Size = UDim2.new(0.62, 0, 0, BANNER_H)
	B.Head.Text = Text
	B.Parent = Parent
	return B
end

-- columns laid out between the insets: {Position, Size} for column I
local function ColumnBox(I)
	local X = INSET
	for J = 1, I - 1 do X += COLUMNS[J].W * (1 - 2 * INSET) end
	return UDim2.new(X, 2, 0, 0), UDim2.new(COLUMNS[I].W * (1 - 2 * INSET), -4, 1, 0)
end

-- what a row / the card shows for a player (only the server's attributes, or "Loading")
local function Info(P)
	local Ready = P:GetAttribute("ProfileReady") == true
	local Rank = Ready and tonumber(P:GetAttribute("Rank")) or nil
	local Clan = Ready and P:GetAttribute("Clan") or nil
	return {
		Ready = Ready,
		Name = P.DisplayName,
		Level = Ready and tostring(P:GetAttribute("Level") or "?") or "...",
		Rank = Rank,
		Title = Ready and (P:GetAttribute("Title") or "?") or "Loading",
		Clan = not Ready and "..." or ((Clan == nil or Clan == "") and "Unclanned" or Clan),
		Status = Ready and P:GetAttribute("RankStatus") or nil,
		License = Ready and P:GetAttribute("StateLicense") == true,
	}
end

local function SortKey(A, B)
	local LA, LB = tonumber(A:GetAttribute("Level")) or 0, tonumber(B:GetAttribute("Level")) or 0
	if LA ~= LB then return LA > LB end
	local RA, RB = tonumber(A:GetAttribute("Rank")) or 0, tonumber(B:GetAttribute("Rank")) or 0
	if RA ~= RB then return RA > RB end
	local NA, NB = A.DisplayName:lower(), B.DisplayName:lower()
	if NA ~= NB then return NA < NB end
	return A.UserId < B.UserId
end

-- ----- the card (hover / tap) -----
local Card = {Target = nil, Pinned = false, OverName = false, OverCard = false, Token = 0}

local function CardLine(Order, Text, Color, Wrap)
	return LbText(Card.Body, {Name = "Line" .. Order, LayoutOrder = Order, Text = Text, TextColor3 = Color or LB_TEXT,
		Size = UDim2.new(1, 0, 0, 18), AutomaticSize = Wrap and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
		TextWrapped = Wrap or false, TextTruncate = Wrap and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd})
end

local function FillCard()
	local P = Card.Target
	if not P or not P.Parent then return end
	for _, C in ipairs(Card.Body:GetChildren()) do if C:IsA("TextLabel") then C:Destroy() end end
	local I = Info(P)
	if Card.Banner then Card.Banner.Head.Text = P.DisplayName else CardLine(1, P.DisplayName, LB_GOLD).FontFace = LB_BOLD end
	CardLine(2, "@" .. P.Name, LB_DIM)
	CardLine(3, "Display name: " .. P.DisplayName)
	if not I.Ready then
		CardLine(4, "Loading this player's record...", LB_DIM)
		return
	end
	CardLine(4, "Level: " .. I.Level)
	CardLine(5, "Title: " .. I.Title, RANK_COLORS[I.Rank] or LB_TEXT)
	CardLine(6, "Clan: " .. I.Clan)
	local Def = I.Rank and Ranks.List[I.Rank]
	if Def then
		CardLine(7, ("Rank: %d - %s"):format(Def.Rank, Def.Title), RANK_COLORS[Def.Rank])
		CardLine(8, Def.Description, LB_DIM, true)
	end
	if I.License then
		CardLine(9, "State Alchemist License: verified", Color3.fromRGB(140, 200, 140))
	end
	if I.Status then CardLine(10, I.Status, LB_DIM, true) end
end

local function PlaceCard()
	local Row = Card.Target and Rows[Card.Target]
	if not Row then return end
	local Parent = Card.Frame.Parent
	local Origin = Parent.AbsolutePosition
	local Size = Card.Frame.AbsoluteSize
	local Y = math.clamp(Row.Frame.AbsolutePosition.Y - BANNER_H, 4, math.max(4, Parent.AbsoluteSize.Y - Size.Y - 4))
	Card.Frame.Position = UDim2.fromOffset(Board.Root.AbsolutePosition.X - Origin.X - 6, Y - Origin.Y)
end

local function HideCard()
	Card.Target, Card.Pinned = nil, false
	Card.Frame.Visible = false
end

local function ShowCard(P, Pinned)
	Card.Token += 1
	Card.Target = P
	Card.Pinned = Pinned or false
	FillCard()
	Card.Frame.Visible = true
	local S = Board.CardScale or 1
	Card.Scale.Scale = S * 0.94
	TweenService:Create(Card.Scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {Scale = S}):Play()
	task.defer(PlaceCard)
end

-- leaving the name for the card (or back) inside a short grace doesn't close it: no flicker
local function MaybeHide()
	Card.Token += 1
	local Token = Card.Token
	task.delay(0.18, function()
		if Card.Token == Token and not Card.Pinned and not Card.OverName and not Card.OverCard then HideCard() end
	end)
end

local function Inside(Gui, Pos)
	local A, S = Gui.AbsolutePosition, Gui.AbsoluteSize
	return Pos.X >= A.X and Pos.X <= A.X + S.X and Pos.Y >= A.Y and Pos.Y <= A.Y + S.Y
end

-- ----- rows -----
local function MarkDirty() Dirty = true end

local function AddRow(P)
	if Rows[P] then return end
	local Frame = Instance.new("Frame")
	Frame.Name = "Row_" .. P.UserId
	Frame.Size = UDim2.new(1, 0, 0, ROW_H)
	Frame.BackgroundTransparency = 1
	Frame.Parent = Board.List
	local Bar = Art(Frame, ART_ROW)
	-- your own row: the bar warmed toward gold
	Bar.ImageColor3 = P == Player and Color3.fromRGB(255, 225, 160) or Color3.new(1, 1, 1)
	local Cells = {}
	for I, Col in ipairs(COLUMNS) do
		local Pos, Size = ColumnBox(I)
		Cells[Col.Key] = LbText(Frame, {Name = Col.Key, Button = Col.Key == "Name", Position = Pos, Size = Size, ZIndex = 2})
	end
	local Name = Cells.Name
	Name.MouseEnter:Connect(function() Card.OverName = true if not Card.Pinned or Card.Target ~= P then ShowCard(P) end end)
	Name.MouseLeave:Connect(function() Card.OverName = false MaybeHide() end)
	Name.Activated:Connect(function()
		if Card.Target == P and Card.Pinned then HideCard() else ShowCard(P, true) end
	end)
	Rows[P] = {Frame = Frame, Art = Bar, Cells = Cells, Conn = P.AttributeChanged:Connect(MarkDirty),
		NameConn = P:GetPropertyChangedSignal("DisplayName"):Connect(MarkDirty)}
	Dirty = true
end

local function RemoveRow(P)
	local Row = Rows[P]
	if not Row then return end
	Row.Conn:Disconnect()
	Row.NameConn:Disconnect()
	Row.Frame:Destroy()
	Rows[P] = nil
	if Card.Target == P then HideCard() end
	Dirty = true
end

local function DrawLeaderboard()
	Dirty = false
	local List = Players:GetPlayers()
	table.sort(List, SortKey)
	for Order, P in ipairs(List) do
		local Row = Rows[P]
		if Row then
			local I = Info(P)
			Row.Frame.LayoutOrder = Order
			Row.Cells.Name.Text = I.Name
			Row.Cells.Level.Text = I.Level
			Row.Cells.Title.Text = I.Title
			Row.Cells.Title.TextColor3 = I.Ready and (RANK_COLORS[I.Rank] or LB_TEXT) or LB_DIM
			Row.Cells.Clan.Text = I.Clan
			Row.Cells.Clan.TextColor3 = (I.Ready and I.Clan ~= "Unclanned") and LB_TEXT or LB_DIM
		end
	end
	local Shown = math.min(#List, MAX_ROWS)
	Board.Root.Size = UDim2.new(0.2, 0, 0, BANNER_H + HEAD_H + Shown * ROW_H + 12)
	if Card.Target then
		if Card.Target.Parent then FillCard() task.defer(PlaceCard) else HideCard() end
	end
end

local function BuildLeaderboard()
	local Root = HUD.LeaderBoard
	-- the old one-column rows can't hold four columns: the frame is reused, its old children are
	-- hidden and left in place
	for _, C in ipairs(Root:GetChildren()) do
		if C:IsA("GuiObject") then C.Visible = false
		elseif C:IsA("UIAspectRatioConstraint") or C:IsA("UIListLayout") then C.Parent = nil end
	end
	Root.BackgroundTransparency = 1
	Root.ClipsDescendants = false
	local Size = Instance.new("UISizeConstraint")
	Size.MinSize = Vector2.new(280, 0)
	Size.MaxSize = Vector2.new(380, math.huge)
	Size.Parent = Root
	local Scale = Instance.new("UIScale")
	Scale.Parent = Root

	-- the panel: Server Info's art under everything below the banner
	local Panel = Instance.new("Frame")
	Panel.Name = "Panel"
	Panel.BackgroundTransparency = 1
	Panel.Position = UDim2.fromOffset(0, BANNER_H / 2)
	Panel.Size = UDim2.new(1, 0, 1, -BANNER_H / 2)
	Panel.Parent = Root
	Art(Panel, ART_PANEL)
	Banner(Root, "PLAYERS")

	local Head = Instance.new("Frame")
	Head.Name = "Header"
	Head.BackgroundTransparency = 1
	Head.Position = UDim2.fromOffset(0, BANNER_H + 2)
	Head.Size = UDim2.new(1, 0, 0, HEAD_H)
	Head.Parent = Root
	local Rule = Instance.new("Frame") -- a thin gold rule under the column names
	Rule.BackgroundColor3 = LB_EDGE
	Rule.BackgroundTransparency = 0.3
	Rule.BorderSizePixel = 0
	Rule.Position = UDim2.new(INSET, 0, 1, -1)
	Rule.Size = UDim2.new(1 - 2 * INSET, 0, 0, 1)
	Rule.Parent = Head
	for I, Col in ipairs(COLUMNS) do
		local Pos, Sz = ColumnBox(I)
		LbText(Head, {Name = Col.Key, Text = Col.Head:upper(), TextColor3 = LB_GOLD, FontFace = LB_BOLD, TextSize = 13,
			Position = Pos, Size = Sz})
	end

	local List = Instance.new("ScrollingFrame")
	List.Name = "Rows"
	List.BackgroundTransparency = 1
	List.BorderSizePixel = 0
	List.Position = UDim2.fromOffset(0, BANNER_H + HEAD_H + 4)
	List.Size = UDim2.new(1, 0, 1, -(BANNER_H + HEAD_H + 8))
	List.CanvasSize = UDim2.new()
	List.AutomaticCanvasSize = Enum.AutomaticSize.Y
	List.ScrollBarThickness = 3
	List.ScrollBarImageColor3 = LB_EDGE
	List.ScrollingDirection = Enum.ScrollingDirection.Y
	List.Parent = Root
	local Layout = Instance.new("UIListLayout")
	Layout.SortOrder = Enum.SortOrder.LayoutOrder
	Layout.Parent = List

	-- the card: the same panel art and banner, left of the board beside the row it describes
	local CardFrame = Instance.new("Frame")
	CardFrame.Name = "PlayerCard"
	CardFrame.AnchorPoint = Vector2.new(1, 0)
	CardFrame.BackgroundTransparency = 1
	CardFrame.Size = UDim2.fromOffset(250, 0)
	CardFrame.AutomaticSize = Enum.AutomaticSize.Y
	CardFrame.Visible = false
	CardFrame.ZIndex = 20
	CardFrame.Parent = Root.Parent
	local CLayout = Instance.new("UIListLayout")
	CLayout.SortOrder = Enum.SortOrder.LayoutOrder
	CLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	CLayout.Parent = CardFrame
	local BannerHolder = Instance.new("Frame")
	BannerHolder.Name = "Top"
	BannerHolder.BackgroundTransparency = 1
	BannerHolder.Size = UDim2.new(1, 0, 0, BANNER_H)
	BannerHolder.LayoutOrder = 0
	BannerHolder.Parent = CardFrame
	local CardBanner = Banner(BannerHolder, "")
	if CardBanner then CardBanner.Size = UDim2.new(0.86, 0, 1, 0) end
	local Holder = Instance.new("Frame") -- the panel art, behind the padded list of lines
	Holder.Name = "Holder"
	Holder.BackgroundTransparency = 1
	Holder.Size = UDim2.new(1, 0, 0, 0)
	Holder.AutomaticSize = Enum.AutomaticSize.Y
	Holder.LayoutOrder = 1
	Holder.Parent = CardFrame
	Art(Holder, ART_PANEL, 0)
	local Body = Instance.new("Frame")
	Body.Name = "Body"
	Body.BackgroundTransparency = 1
	Body.Size = UDim2.new(1, 0, 0, 0)
	Body.AutomaticSize = Enum.AutomaticSize.Y
	Body.ZIndex = 2
	Body.Parent = Holder
	local Pad = Instance.new("UIPadding")
	Pad.PaddingTop, Pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 10)
	Pad.PaddingLeft, Pad.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
	Pad.Parent = Body
	local BLayout = Instance.new("UIListLayout")
	BLayout.SortOrder = Enum.SortOrder.LayoutOrder
	BLayout.Padding = UDim.new(0, 1)
	BLayout.Parent = Body
	local CScale = Instance.new("UIScale")
	CScale.Parent = CardFrame
	CardFrame.MouseEnter:Connect(function() Card.OverCard = true Card.Token += 1 end)
	CardFrame.MouseLeave:Connect(function() Card.OverCard = false MaybeHide() end)
	Card.Frame, Card.Body, Card.Banner, Card.Scale = CardFrame, Body, CardBanner, CScale

	Board = {Root = Root, List = List, Scale = Scale}

	-- readable on a phone, not huge on a monitor
	local function Rescale()
		local H = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 900
		local S = math.clamp(H / 820, 0.85, 1.2)
		Scale.Scale = S
		Board.CardScale = S
		if Card.Frame.Visible then Card.Scale.Scale = S task.defer(PlaceCard) end
	end
	Rescale()
	if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(Rescale) end

	-- a tap or click anywhere else closes a pinned card
	UserInputService.InputBegan:Connect(function(Input)
		if not Card.Frame.Visible then return end
		if Input.UserInputType ~= Enum.UserInputType.Touch and Input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		-- input positions skip the top bar; GUI positions include it when the ScreenGui ignores the inset
		local Pos = Vector2.new(Input.Position.X, Input.Position.Y)
		local Screen = Root:FindFirstAncestorWhichIsA("ScreenGui")
		if Screen and Screen.IgnoreGuiInset then Pos += GuiService:GetGuiInset() end
		local Row = Card.Target and Rows[Card.Target]
		if Inside(Card.Frame, Pos) or (Row and Inside(Row.Cells.Name, Pos)) then return end
		HideCard()
	end)

	Players.PlayerAdded:Connect(AddRow)
	Players.PlayerRemoving:Connect(RemoveRow)
	for _, P in ipairs(Players:GetPlayers()) do AddRow(P) end
	RunService.Heartbeat:Connect(function()
		if Dirty then DrawLeaderboard() end
	end)
end

-- ===== Server info =====
local function UpdateServer()
	local Start = ReplicatedStorage:GetAttribute("ServerStart") or workspace:GetServerTimeNow()
	local T = math.max(0, math.floor(workspace:GetServerTimeNow() - Start))
	local Ping = math.floor(Player:GetNetworkPing() * 2000 + 0.5)
	HUD.Server.MainText.Text = table.concat({
		"Server: " .. (ReplicatedStorage:GetAttribute("ServerName") or "-"),
		("Players: %d/%d"):format(#Players:GetPlayers(), Players.MaxPlayers),
		("Time Elapsed: %02d:%02d:%02d"):format(T // 3600, T % 3600 // 60, T % 60),
		"Ping: " .. Ping .. " ms",
	}, "<br />")
end

-- ===== Quest tracker =====
local Collapsed = {}
local function UpdateQuests()
	local Data = UIState.Data
	local Q = HUD.Quests
	for _, C in ipairs(Q:GetChildren()) do
		if C:IsA("GuiObject") then C:Destroy() end
	end
	if not Data or not Data.Quests then Q.Visible = false return end
	local Ids = {}
	for Id in pairs(Data.Quests.Active) do if QuestDefs[Id] then table.insert(Ids, Id) end end
	-- the tracked quest (Journal) first, then oldest first
	local Tracked = Data.Quests.Tracked
	table.sort(Ids, function(A, B)
		if (A == Tracked) ~= (B == Tracked) then return A == Tracked end
		return Data.Quests.Active[A].Started < Data.Quests.Active[B].Started
	end)
	Q.Visible = #Ids > 0
	local Order = 0
	local function Add(Template)
		Order += 1
		local C = Templates[Template]:Clone()
		C.LayoutOrder = Order
		C.Parent = Q
		return C
	end
	for I = 1, math.min(MAX_QUESTS, #Ids) do
		local Id = Ids[I]
		local Def, State = QuestDefs[Id], Data.Quests.Active[Id]
		local Header = Add("QuestHeader")
		Header.main.Title.Text = Def.Title
		Header.Arrows.Down.Visible = not Collapsed[Id]
		Header.Arrows.Top.Visible = Collapsed[Id] == true
		local function Flip() Collapsed[Id] = not Collapsed[Id] UpdateQuests() end
		Header.Arrows.Down.Activated:Connect(Flip)
		Header.Arrows.Top.Activated:Connect(Flip)
		if not Collapsed[Id] then
			-- only the current stage's objectives (StoryLogic; quests can have several stages)
			for _, Obj in ipairs((StoryLogic.Visible(Def, State))) do
				local Need = Obj.Count or 1
				local Have = State.Progress[Obj.Id] or 0
				local Task = Add("QuestTask")
				local Text = Need > 1 and ("%s (%d/%d)"):format(Obj.Text, Have, Need) or Obj.Text
				Task.Text.Text = Obj.Optional and (Text .. " (optional)") or Text
				Task.Status.Checkmark.Visible = Have >= Need
			end
			local Abandon = Add("QuestAbandon")
			Abandon.Button.Activated:Connect(function()
				UIState.Request("Quest", "Abandon", Id)
			end)
		end
	end
end

function HUDUI.Start()
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end)
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) end)
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false) end)
	HUD.Visible = true
	Gui.HUD2.Visible = true
	BuildLeaderboard() -- event-driven (attribute changes), not on the 1 s loop

	UIState.Changed:Connect(function(Data)
		HUD.CashFrame.Display.Text = "$" .. UIState.Format(Data.Money or 0)
		UpdateHotbar()
		UpdateQuests()
	end)

	for I, Key in ipairs(SlotOrder) do
		local Slot = HUD.Bottom:FindFirstChild("Slot" .. Key)
		if Slot then
			Slot.Activated:Connect(function() UseSlot(tonumber(Key)) end)
		end
	end
	UserInputService.InputBegan:Connect(function(Input, Processed)
		if Processed then return end
		local Number = KeyToSlot[Input.KeyCode]
		if Number then UseSlot(Number) end
	end)
	local function WatchCharacter(Character)
		Character.ChildAdded:Connect(function() task.defer(UpdateHotbar) end)
		Character.ChildRemoved:Connect(function() task.defer(UpdateHotbar) end)
	end
	if Player.Character then WatchCharacter(Player.Character) end
	Player.CharacterAdded:Connect(WatchCharacter)

	SetupHoverValues()
	RunService.RenderStepped:Connect(UpdateVitals)
	RunService.RenderStepped:Connect(UpdateHoverValue)
	task.spawn(function()
		while true do
			UpdateTargets()
			task.wait(0.15)
		end
	end)
	task.spawn(function()
		while true do
			UpdateServer()
			task.wait(1)
		end
	end)
	UpdateQuests()
end

return HUDUI

-- AdminUI (owner 2026-10-15: "make a on theme admin panel using the ui assets that we have in game").
-- Built from the Settings panel's own art (frame, header plate, tab art, row plates, Enable / Disable
-- buttons, the key-bind box) so it matches the rest of the menus. Only built for players the server
-- marked RenseiAdmin; every button goes through Remotes.AdminRemote and AdminService re-checks it.
-- Open / close: F2. Tabs: Players, World, Self, Logs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local UIState = require(script.Parent.UIState)

local Player = Players.LocalPlayer

local GOLD = Color3.fromRGB(230, 205, 120)
local DIM = Color3.fromRGB(150, 150, 150)
local TABS = {"Players", "World", "Self", "Logs"}

local AdminUI = {}

local Remote
local Root, Main, Rows, Sections
local RowProto, ButtonProto, DangerProto, BoxProto
local Tab = "Players"
local State = nil
local Selected = nil -- UserId
local Spectating = nil
local ItemIndex, EnemyIndex = 1, 1
local Inputs = {} -- [key] = text typed into a box, kept across redraws

-- ===== talking to the server =====
local function Toast(Text)
	UIState.Emit("Toast", {Text = Text})
end

local Refresh -- forward
local function Run(Command, Arg, NeedsTarget)
	if NeedsTarget and not Selected then Toast("Pick a player first") return end
	task.spawn(function()
		local Ok, Done, Message = pcall(Remote.InvokeServer, Remote, "Run", Command, Selected, Arg)
		if not Ok then Toast("Admin: request failed") return end
		Toast((Done and "" or "Failed: ") .. tostring(Message or Command))
		Refresh(true)
	end)
end

-- ===== row builders (all clones of the Settings art) =====
local Order = 0
local Quiet = false -- live refresh: rebuilt rows don't pop in again (UIMotion NoPop)
-- Width: the title's share of the row (authored 0.4) for rows with long text and few buttons
local function Row(Title, Width)
	Order += 1
	local R = RowProto:Clone()
	if Quiet then R:SetAttribute("NoPop", true) end
	R.Name = "Row" .. Order
	R.LayoutOrder = Order
	R.Title.Text = Title
	if Width then R.Title.Size = UDim2.new(Width, 0, R.Title.Size.Y.Scale, 0) end
	R.Visible = true
	R.Parent = Rows
	return R, R.Controls
end

local function Fit(Controls)
	-- three buttons fit beside the title as authored; more get narrower
	local N = 0
	for _, C in ipairs(Controls:GetChildren()) do if C:IsA("GuiObject") then N += 1 end end
	if N <= 3 then return end
	for _, C in ipairs(Controls:GetChildren()) do
		if C:IsA("GuiObject") then C.Size = UDim2.new(0.52 / N, 0, C.Size.Y.Scale, 0) end
	end
end

local function Button(Controls, Text, OnClick, Danger, Width)
	local B = (Danger and DangerProto or ButtonProto):Clone()
	B.Name = Text
	B.Head.Text = Text
	B.LayoutOrder = #Controls:GetChildren()
	if Width then B.Size = UDim2.new(Width, 0, B.Size.Y.Scale, 0) end
	B.Parent = Controls
	B.Activated:Connect(OnClick)
	return B
end

local function Box(Controls, Key, Placeholder)
	local Frame = BoxProto:Clone()
	Frame.Name = "Box"
	Frame.LayoutOrder = #Controls:GetChildren()
	local Head = Frame.Head
	local T = Instance.new("TextBox")
	T.Name = "Input"
	for _, P in ipairs({"Size", "Position", "AnchorPoint", "FontFace", "TextColor3", "TextScaled", "BackgroundTransparency"}) do
		T[P] = Head[P]
	end
	T.ClearTextOnFocus = false
	T.PlaceholderText = Placeholder
	T.PlaceholderColor3 = Color3.fromRGB(140, 130, 100)
	T.Text = Inputs[Key] or ""
	for _, C in ipairs(Head:GetChildren()) do C.Parent = T end
	Head:Destroy()
	T.Parent = Frame
	T:GetPropertyChangedSignal("Text"):Connect(function() Inputs[Key] = T.Text end)
	Frame.Parent = Controls
	return T
end

local function Label(Controls, Text)
	local L = BoxProto:Clone()
	L.Name = "Label"
	L.LayoutOrder = #Controls:GetChildren()
	L.Head.Text = Text
	L.Active = false
	L.AutoButtonColor = false
	L.Parent = Controls
	return L
end

local function Heading(Text)
	local R = Row(Text, 0.92)
	R.ImageTransparency = 0.6
	R.Title.TextColor3 = GOLD
	return R
end

-- run a player command on someone other than the selected player (Self tab)
local function RunOn(UserId, Command, Arg)
	local Was = Selected
	Selected = UserId
	Run(Command, Arg, true)
	Selected = Was
end

-- Alchemy path cycler: < Flame > Set. Starts on the player's current path; the pick is kept per
-- player across redraws until it's applied.
local AlchemyPick = {} -- [UserId] = index into State.Affinities
local function AlchemyRow(P, Title)
	local Paths = State.Affinities or {}
	if #Paths == 0 then return end
	local I = AlchemyPick[P.UserId] or table.find(Paths, P.Affinity or "None") or 1
	I = (I - 1) % #Paths + 1
	AlchemyPick[P.UserId] = I
	local _, C = Row(Title .. "  (now: " .. (P.Affinity or "None") .. ")", 0.44)
	Button(C, "<", function() AlchemyPick[P.UserId] = I - 1 AdminUI.Redraw() end, false, 0.07)
	Label(C, Paths[I])
	Button(C, ">", function() AlchemyPick[P.UserId] = I + 1 AdminUI.Redraw() end, false, 0.07)
	Button(C, "Set", function()
		AlchemyPick[P.UserId] = nil -- after the switch, show the new current path
		RunOn(P.UserId, "SetAlchemy", Paths[I])
	end)
end

-- Alchemist rank: 1 / 2 / 3 buttons (the server checks level and order; 4 is WIP)
local function RankRow(P, Title)
	local _, C = Row(("%s  (now: %s %s)"):format(Title, tostring(P.Rank or "?"), P.Title or ""), 0.5)
	for N = 1, 3 do Button(C, tostring(N), function() RunOn(P.UserId, "SetRank", N) end, false, 0.07) end
end

-- ===== tabs =====
local Draw = {}

function Draw.Players()
	Heading("Players in this server")
	for _, P in ipairs(State.Players) do
		local Tags = (P.Admin and "  [Admin]" or "") .. (P.Frozen and "  [Frozen]" or "") .. (P.God and "  [God]" or "") .. (P.InCombat and "  [Combat]" or "")
		local R, C = Row(("%s  Lv %d  %d/%d HP%s"):format(P.DisplayName, P.Level, P.Health, P.MaxHealth, Tags), 0.7)
		local Picked = Selected == P.UserId
		if Picked then R.Title.TextColor3 = GOLD end
		Button(C, Picked and "Selected" or "Select", function()
			Selected = P.UserId
			AdminUI.Redraw()
		end)
	end

	local Target
	for _, P in ipairs(State.Players) do if P.UserId == Selected then Target = P end end
	if not Target then
		Selected = nil
		Heading("Select a player to manage them")
		return
	end
	Heading("Manage " .. Target.DisplayName)

	local _, Move = Row("Move")
	Button(Move, "Go To", function() Run("Goto", nil, true) end)
	Button(Move, "Bring", function() Run("Bring", nil, true) end)
	Button(Move, Target.Frozen and "Unfreeze" or "Freeze", function() Run("Freeze", nil, true) end)
	Fit(Move)

	local _, Life = Row("Health")
	Button(Life, "Heal", function() Run("Heal", nil, true) end)
	Button(Life, "Respawn", function() Run("Respawn", nil, true) end)
	Button(Life, "Kill", function() Run("Kill", nil, true) end, true)

	local _, View = Row("Spectate")
	Button(View, Spectating == Selected and "Stop" or "Watch", function()
		local Camera = workspace.CurrentCamera
		local Who = Players:GetPlayerByUserId(Selected)
		if Spectating == Selected or not (Who and Who.Character) then
			Spectating = nil
			local Mine = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
			if Mine then Camera.CameraSubject = Mine end
		else
			Spectating = Selected
			Camera.CameraSubject = Who.Character:FindFirstChildOfClass("Humanoid")
		end
		AdminUI.Redraw()
	end)

	AlchemyRow(Target, "Alchemy")
	RankRow(Target, "Rank")

	local _, Money = Row("Give Money")
	local MoneyBox = Box(Money, "Money", "Amount")
	Button(Money, "Give", function() Run("GiveMoney", MoneyBox.Text, true) end)

	local _, Exp = Row("Give EXP")
	local ExpBox = Box(Exp, "Exp", "Amount")
	Button(Exp, "Give", function() Run("GiveExp", ExpBox.Text, true) end)

	local Items = State.Items
	if #Items > 0 then
		ItemIndex = (ItemIndex - 1) % #Items + 1
		local _, Give = Row("Give Item")
		Button(Give, "<", function() ItemIndex -= 1 AdminUI.Redraw() end, false, 0.07)
		Label(Give, Items[ItemIndex].Name)
		Button(Give, ">", function() ItemIndex += 1 AdminUI.Redraw() end, false, 0.07)
		Button(Give, "Give", function() Run("GiveItem", Items[ItemIndex].Name, true) end)
	end

	local _, Kick = Row("Kick")
	local Reason = Box(Kick, "Kick", "Reason")
	Button(Kick, "Kick", function() Run("Kick", Reason.Text, true) end, true)
end

function Draw.World()
	Heading(("Live enemies: %d   Admin spawns: %d   Time: %.1f"):format(State.ActiveEnemies, State.AdminSpawns, State.ClockTime))
	local Enemies = State.Enemies
	if #Enemies > 0 then
		EnemyIndex = (EnemyIndex - 1) % #Enemies + 1
		local E = Enemies[EnemyIndex]
		local _, Spawn = Row("Spawn Enemy")
		Button(Spawn, "<", function() EnemyIndex -= 1 AdminUI.Redraw() end, false, 0.07)
		Label(Spawn, ("%s  Lv %d"):format(E.Name, E.Level or 0))
		Button(Spawn, ">", function() EnemyIndex += 1 AdminUI.Redraw() end, false, 0.07)
		Button(Spawn, "Spawn", function() Run("SpawnEnemy", E.Type) end)
	end
	local _, Clear = Row("Enemies")
	Button(Clear, "Clear Spawns", function() Run("ClearSpawns") end)
	Button(Clear, "Kill All", function() Run("KillEnemies") end, true)

	local _, Time = Row("Time Of Day")
	local Hour = Box(Time, "Time", "0 - 24")
	Button(Time, "Set", function() Run("Time", Hour.Text) end)

	local _, Say = Row("Announce")
	local Msg = Box(Say, "Announce", "Message to everyone")
	Msg.Parent.Size = UDim2.new(0.36, 0, Msg.Parent.Size.Y.Scale, 0)
	Button(Say, "Send", function()
		Run("Announce", Msg.Text)
		Inputs.Announce = ""
	end)
end

function Draw.Self()
	local Me
	for _, P in ipairs(State.Players) do if P.UserId == Player.UserId then Me = P end end
	Heading("Your character")
	local _, God = Row("God Mode")
	Button(God, (Me and Me.God) and "Turn Off" or "Turn On", function() Run("God") end, Me and Me.God)
	local _, Speed = Row("Speed")
	local Mult = Box(Speed, "Speed", "x0.5 - x4")
	Button(Speed, "Set", function() Run("Speed", Mult.Text) end)
	Button(Speed, "Reset", function() Run("Speed", 1) end)
	if Me then AlchemyRow(Me, "Alchemy") end
	if Me then RankRow(Me, "Rank") end
	local _, Heal = Row("Heal Me")
	Button(Heal, "Heal", function() RunOn(Player.UserId, "Heal") end)
end

function Draw.Logs()
	Heading(("Last %d admin actions (this server)"):format(#State.Log))
	if #State.Log == 0 then Row("Nothing yet.", 0.92) end
	for _, L in ipairs(State.Log) do
		Row(("%s  %s: %s"):format(os.date("%H:%M:%S", L.At), L.Admin, L.Message or L.Command), 0.92)
	end
end

-- ===== render =====
-- Animate: rows pop in only when the panel opens or the tab changes; every other redraw (live
-- refresh, Select, the < > cyclers, after a command) swaps the rows in place
function AdminUI.Redraw(Animate)
	if not State then return end
	Quiet = Animate ~= true
	for _, T in ipairs(Sections:GetChildren()) do
		if T:IsA("ImageButton") then
			local Active = T.Name == Tab
			T.ImageColor3 = Active and Color3.new(1, 1, 1) or DIM
			if T:FindFirstChild("Head") then T.Head.TextColor3 = Active and GOLD or Color3.fromRGB(190, 190, 190) end
		end
	end
	local Scroll = Rows.CanvasPosition
	for _, R in ipairs(Rows:GetChildren()) do
		if R:IsA("GuiObject") then R:Destroy() end
	end
	Order = 0
	Draw[Tab]()
	Quiet = false
	Rows.CanvasPosition = Scroll -- live refreshes keep your place in the list
end

local Busy = false
local LastSeen = nil -- the last state drawn, so an unchanged refresh doesn't rebuild at all
local function Signature(S)
	local Http = game:GetService("HttpService")
	local Ok, Json = pcall(Http.JSONEncode, Http, S)
	return Ok and Json or tostring(os.clock())
end
function Refresh(Live)
	if Busy or not Root.Visible then return end
	Busy = true
	local Ok, Result = pcall(Remote.InvokeServer, Remote, "State")
	Busy = false
	if Ok and type(Result) == "table" then
		local Sig = Signature(Result)
		if Live and Sig == LastSeen then return end
		LastSeen = Sig
		State = Result
		-- don't rebuild under someone typing
		local Typing = false
		for _, D in ipairs(Rows:GetDescendants()) do
			if D:IsA("TextBox") and D:IsFocused() then Typing = true end
		end
		if not Typing then AdminUI.Redraw(not Live) end
	end
end

-- ===== build =====
local function Build()
	local Gui = UIState.Gui
	Root = Gui.Settings:Clone()
	Root.Name = "Admin"
	Main = Root.MainFrame
	Rows = Main.Container
	Sections = Main.Sections
	Main.Header.Head.Text = "ADMIN"
	-- Settings never fills its list; the admin tabs do, so they scroll inside the frame
	Rows.ClipsDescendants = true
	Rows.ScrollingEnabled = true
	Rows.ScrollBarThickness = 4
	Rows.ScrollBarImageColor3 = GOLD
	Rows.AutomaticCanvasSize = Enum.AutomaticSize.Y
	Rows.CanvasSize = UDim2.new()

	-- prototypes from the authored rows
	local Toggle = Rows.CameraShake
	local Key = Rows.Dash
	RowProto = Toggle:Clone()
	for _, C in ipairs(RowProto.Controls:GetChildren()) do
		if C:IsA("GuiObject") then C:Destroy() end
	end
	RowProto:SetAttribute("Tab", nil)
	RowProto:SetAttribute("Kind", nil)
	ButtonProto = Toggle.Controls.Enable:Clone()
	DangerProto = Toggle.Controls.Disable:Clone()
	BoxProto = Key.Controls.Bind:Clone()
	for _, R in ipairs(Rows:GetChildren()) do
		if R:IsA("GuiObject") then R:Destroy() end
	end

	-- tabs: the Settings tab art, relabelled
	local Old = {}
	for _, T in ipairs(Sections:GetChildren()) do if T:IsA("ImageButton") then table.insert(Old, T) end end
	table.sort(Old, function(X, Y) return X.Position.X.Scale < Y.Position.X.Scale end)
	local Plain = Gui.Settings.MainFrame.Sections.Graphics.Image -- the art without a baked-in word
	for I, T in ipairs(Old) do
		local Name = TABS[I]
		if Name then
			T.Name = Name
			T.Image = Plain
			T.LayoutOrder = I
			if T:FindFirstChild("Head") then T.Head.Text = Name end
			T.Activated:Connect(function()
				Tab = Name
				Rows.CanvasPosition = Vector2.zero
				AdminUI.Redraw(true)
				task.spawn(Refresh, true)
			end)
		else
			T:Destroy()
		end
	end

	Root.Parent = Gui
	UIState.RegisterMenu("Admin", Root, function()
		State = State or {Players = {}, Enemies = {}, Items = {}, Log = {}, ClockTime = 0, ActiveEnemies = 0, AdminSpawns = 0}
		AdminUI.Redraw()
		task.spawn(Refresh)
	end, true)

	-- live numbers (health, log) while it's open
	task.spawn(function()
		while Root.Parent do
			task.wait(2)
			if Root.Visible and Tab ~= "Self" then Refresh(true) end
		end
	end)

	ContextActionService:BindAction("RenseiAdmin", function(_, InputState)
		if InputState == Enum.UserInputState.Begin then UIState.ToggleMenu("Admin") end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.F2)
	ContextActionService:SetTitle("RenseiAdmin", "Admin")
	ContextActionService:SetPosition("RenseiAdmin", UDim2.new(1, -70 - 4 * 62, 0, 10))
end

function AdminUI.Start()
	local Built = false
	local function Check()
		if Built or not Player:GetAttribute("RenseiAdmin") then return end
		Remote = ReplicatedStorage.Remotes:WaitForChild("AdminRemote", 10)
		if not Remote then return end
		Built = true
		Build()
	end
	Player:GetAttributeChangedSignal("RenseiAdmin"):Connect(function() task.spawn(Check) end)
	task.spawn(Check)
end

return AdminUI

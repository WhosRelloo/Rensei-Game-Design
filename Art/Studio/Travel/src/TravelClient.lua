-- TravelClient (World plan 1, 2026-10-20): ticket window, departure boards, the ride's scenery and fades, the
-- teleport screen, and (Task 8) the road's travel card and journey screen. Server: StationService and RoadService
-- (Remotes.Travel / Remotes.TravelEvent). Every number is a PROPOSAL.
-- Owner rule (2026-10-21): every visual here is built ONLY from the game's existing UI art, cloned from the
-- StarterGui.Uis templates (no new panels, corner blobs or drawn shapes):
--   * ticket window   = a look-alike of the NPC dialogue box (Uis.Dialogue: the box, its choice plates and highlight);
--   * departure board = the Party Invitation panel (HUD2.Party) on the board's SurfaceGui;
--   * rail messages   = the game's own toast (HUD2.Notification, through UIState "Toast", as the server's toasts);
--   * teleport screen = the menus' backdrop (bg) and the area panel (HUD2.NewAreaDiscovered);
--   * the road's card and journey screen (Task 8), below.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local Travel = require(ReplicatedStorage.Modules.Data.Rensei.Travel)
local Places = require(ReplicatedStorage.Modules.Data.Rensei.Places)

local Player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Remote = Remotes:WaitForChild("Travel")
local Event = Remotes:WaitForChild("TravelEvent")
local Here = Places.RegionOf(game.PlaceId) or "Lindenmoor"

local Gui = Instance.new("ScreenGui")
Gui.Name, Gui.ResetOnSpawn, Gui.IgnoreGuiInset, Gui.DisplayOrder = "TravelUI", false, true, 50
Gui.Parent = Player:WaitForChild("PlayerGui")

-- the full-screen black used to fade in and out of the ride (a transition, not a panel)
local Fade = Instance.new("Frame")
Fade.Size, Fade.BackgroundColor3, Fade.BackgroundTransparency, Fade.ZIndex = UDim2.fromScale(1, 1), Color3.new(0, 0, 0), 1, 50
Fade.Parent = Gui
local function FadeTo(Alpha, Time)
	TweenService:Create(Fade, TweenInfo.new(Time), {BackgroundTransparency = Alpha}):Play()
end

-- ===== the game's own UI art =====
local function Template(Path) -- an untouched copy from StarterGui.Uis (else the player's live Uis)
	local Root = game:GetService("StarterGui"):FindFirstChild("Uis") or Player.PlayerGui:WaitForChild("Uis", 10)
	local I = Root
	for Name in string.gmatch(Path, "[^%.]+") do I = I and I:FindFirstChild(Name) end
	if not I then return nil end
	local C = I:Clone()
	C.Visible = true
	return C
end
-- raise a cloned piece and everything in it by Z (TravelUI uses global ZIndex order: a clone's children must stay
-- above its own art, and above the fade)
local function Lift(Root, Z)
	for _, D in ipairs(Root:GetDescendants()) do
		if D:IsA("GuiObject") then D.ZIndex += Z end
	end
	Root.ZIndex += Z
end
local function SetText(Parent, Path, Text)
	local I = Parent
	for Name in string.gmatch(Path, "[^%.]+") do I = I and I:FindFirstChild(Name) end
	if I and I:IsA("TextLabel") then I.RichText = true I.Text = Text end
end
local function Escape(S) -- player names into RichText
	return (tostring(S):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end
local function AreaPanel(Dest, Line, Title) -- HUD2.NewAreaDiscovered, relabelled
	local P = Template("HUD2.NewAreaDiscovered")
	if not P then return nil end
	P.AnchorPoint, P.Position = Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.22)
	SetText(P, "Header.Title", Title or "ON THE ROAD")
	SetText(P, "Header.Head", Escape(Dest))
	SetText(P, "MainText", Line)
	return P
end
-- the game's own toast (PopupUI shows UIState's "Toast" on HUD2.Notification, the same lane the server's
-- UIService.Notify toasts use)
local UIState
local function Toast(Text)
	if not UIState then
		local Ok, M = pcall(require, ReplicatedStorage.Modules.UI.UIState)
		if not Ok then return end
		UIState = M
	end
	UIState.Emit("Toast", {Text = Escape(Text)})
end

local Busy = false
local function Ask(Op, Args)
	if Busy or not Remote:GetAttribute("Ready") then return false, "The clerk is busy." end
	Busy = true
	local Mine = {}
	local Token = Mine
	task.delay(10, function() if Token == Mine then Busy = false end end) -- never stuck if the server doesn't answer
	local Ok, A, B = pcall(function() return Remote:InvokeServer(Op, Args) end)
	Token = nil
	Busy = false
	if not Ok then return false, "No answer from the clerk." end
	return A, B
end

local function RegionName(Id)
	return Id and Places.Regions[Id] and Places.Regions[Id].Name or Id or "?"
end

-- ===== the ticket window: a look-alike of the NPC dialogue box (fix rounds 1-2, controller's rulings) =====
-- Cloned from Uis.Dialogue (not wired into DialogueService): the clerk "says" the line in MainFrame (97950998740350,
-- speaker "Ticket clerk"), and the answers are its choice plates (Choices.Choice1, 92726496845615, with the
-- Selected highlight 107749049761613 on hover), in the dialogue's own lettering. Choices: "Ticket for: <name>"
-- (cycles me -> each other player, sent by UserId), one per class with its price, and "Never mind". A station with
-- several lines first asks "Where to?" with one choice per line. Placed like the real box (text above the choices,
-- at 66% of the screen); UIMotion opens and settles it. No number keys (they'd also reach the hotbar: HUDUI only
-- checks the real dialogue). It closes on Esc, another menu (Uis.bg), a real conversation (Uis.Dialogue), death,
-- respawn, and walking out of the clerk's reach. On a small or touch screen every choice is at least MIN_TOUCH px
-- tall; the box moves up to stay on screen, never past the top, and past that the choices scroll.
local Window
local OpenToken = 0
local Opening = nil -- the token of an open waiting for the clerk's prices
local JourneyActive = function() return false end -- set once the journey screen's state exists (below)
local HiddenHud -- the HUD parts this window hid (the real dialogue hides them too: its choices sit there)
local Conns = {} -- this window's connections, cut when it closes
local MIN_TOUCH = 40 -- PROPOSAL: a choice's minimum height in px on a phone
local CLERK_REACH = 14 -- StationService.ClerkReach: past this from every clerk, the window closes
local ASK_TIMEOUT = 10 -- as Ask's own busy release
local function LiveUis() return Player.PlayerGui:FindFirstChild("Uis") end
local UIMotion
local function Motion()
	if not UIMotion then
		local Ok, M = pcall(require, ReplicatedStorage.Modules.UI.UIMotion)
		UIMotion = Ok and M or false
	end
	return UIMotion or nil
end
local function CloseTickets()
	OpenToken += 1
	for _, C in ipairs(Conns) do C:Disconnect() end
	table.clear(Conns)
	local S = Window
	Window = nil
	if S then
		local Box = S:FindFirstChild("Box")
		local M = Motion()
		if M and Box and Box.Visible then
			M.Close(Box) -- settles out (0.14 s), as the menus do; the choices are already dead (Window ~= S)
			task.delay(0.2, function() S:Destroy() end)
		else
			S:Destroy()
		end
	end
	local Uis = LiveUis()
	if HiddenHud and Uis then
		local Talk = Uis:FindFirstChild("Dialogue")
		if not (Talk and Talk.Visible) then -- a real conversation keeps them hidden
			for _, G in ipairs(HiddenHud) do G.Visible = true end
		end
	end
	HiddenHud = nil
end
Player.CharacterAdded:Connect(function() if Window then CloseTickets() end end) -- respawned: the clerk is gone
local function NearClerk()
	local Root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
	if not Root then return false end
	for _, C in ipairs(CollectionService:GetTagged("RenseiTicketClerk")) do
		if C:IsA("BasePart") and C:IsDescendantOf(workspace) and (C.Position - Root.Position).Magnitude <= CLERK_REACH then return true end
	end
	return false
end
local function OpenTickets()
	if Opening then return end -- one is already on its way (a double press): let it finish
	CloseTickets()
	local Mine = OpenToken
	local Wait = {}
	Opening = Wait
	task.delay(ASK_TIMEOUT, function() if Opening == Wait then Opening = nil end end) -- never stuck on a lost answer
	local Rows = Ask("Prices")
	if Opening == Wait then Opening = nil end
	-- the clerk answered: still wanted? (closed, reopened, a ride or road fade, or the journey screen meanwhile)
	if OpenToken ~= Mine or type(Rows) ~= "table" then return end
	if Fade.BackgroundTransparency < 0.99 or JourneyActive() or not NearClerk() then return end
	local Box = Template("Dialogue")
	local Main = Box and Box:FindFirstChild("MainFrame")
	local Authored = Box and Box:FindFirstChild("Choices")
	local RowArt = Authored and Authored:FindFirstChild("Choice1")
	if not (Main and Main:FindFirstChild("maintext") and RowArt and RowArt:FindFirstChild("Head")) then -- no Uis art here
		if Box then Box:Destroy() end
		return
	end
	local S = Instance.new("ScreenGui")
	S.Name, S.ResetOnSpawn, S.DisplayOrder, S.ZIndexBehavior = "Tickets", false, 49, Enum.ZIndexBehavior.Sibling
	S.IgnoreGuiInset, S.ScreenInsets = false, Enum.ScreenInsets.CoreUISafeInsets -- as Uis
	Window = S
	Box.Name = "Box"
	RowArt.Parent = nil
	-- the choices sit in a transparent scrolling frame where the authored Choices frame was (layout only: it scrolls
	-- only when a phone can't fit them all), with the authored list layout
	local Layout = Authored:FindFirstChildOfClass("UIListLayout")
	local List = Instance.new("ScrollingFrame")
	List.Name, List.AnchorPoint, List.Position, List.ZIndex = "Choices", Authored.AnchorPoint, Authored.Position, Authored.ZIndex
	List.BackgroundTransparency, List.BorderSizePixel, List.ScrollBarThickness = 1, 0, 0
	List.ScrollingDirection, List.AutomaticCanvasSize, List.ClipsDescendants = Enum.ScrollingDirection.Y, Enum.AutomaticSize.None, true
	if Layout then Layout.Parent = List end
	Authored:Destroy()
	List.Parent = Box
	SetText(Main, "Title", "Ticket clerk")
	local function Say(Text) SetText(Main, "maintext", Text) end

	-- the box's size and place: the real dialogue's proportions, with taller choices on a small or touch screen.
	-- Measured on the box's parent (the ScreenGui), not the box: UIMotion's pop scales the box itself.
	local Count = 0
	local Base = {Row = RowArt.Size, Pad = Layout and Layout.Padding}
	local function Fit()
		local Host = Box.Parent
		if not (Host and Host:IsA("GuiBase2d")) then return end
		local VW, VH = Host.AbsoluteSize.X, Host.AbsoluteSize.Y
		if VW < 1 or VH < 1 then return end
		local ListH = 0.178657413 * VH -- the authored Choices height (its width was 4.56x that)
		local RowH = Base.Row.Y.Scale * ListH
		local RowW = Base.Row.X.Scale * ListH * 4.563876628875732
		if UserInputService.TouchEnabled or VH < 500 then
			local K = math.max(1, MIN_TOUCH / RowH)
			K = math.min(K, 0.96 * VW / RowW) -- never wider than the screen
			RowH, RowW = RowH * K, RowW * K
		end
		RowH, RowW = math.floor(RowH), math.floor(RowW)
		local Pad = math.floor((Base.Pad and Base.Pad.Scale or 0.044) * RowH / Base.Row.Y.Scale)
		if Layout then Layout.Padding = UDim.new(0, Pad) end
		for _, C in ipairs(List:GetChildren()) do
			if C:IsA("GuiButton") then C.Size = UDim2.fromOffset(RowW, RowH) end
		end
		local H = Count * RowH + math.max(Count - 1, 0) * Pad
		local W = math.floor(RowW / Base.Row.X.Scale)
		-- the box text ends at 66% and the choices start at 66.5%, as authored; both move up if the choices would
		-- run off the bottom, but the text box never goes past the top: past that the choices scroll
		local MainH = 0.174722224 * VH -- the authored MainFrame height
		local Lift = math.clamp(0.665 * VH + H + 8 - VH, 0, math.max(0, 0.66 * VH - MainH - 4))
		Main.Position = UDim2.new(0.5, 0, 0.66, -Lift)
		List.Position = UDim2.new(0.5, 0, 0.665, -Lift)
		local Room = math.max(RowH, VH - (0.665 * VH - Lift) - 8)
		List.Size = UDim2.fromOffset(W, math.min(H, Room))
		List.CanvasSize = UDim2.fromOffset(0, H)
	end

	local For = nil -- nil = me, else a Player
	local Picked = #Rows == 1 and Rows[1] or nil -- the line being bought for (one line: straight to its classes)
	local Show
	local function Choice(Text, Fn)
		Count += 1
		local Art = RowArt:Clone()
		local B = Instance.new("ImageButton") -- the choice plate as a button, so UIMotion's press springs apply to it
		B.Name, B.LayoutOrder, B.AutoButtonColor, B.BackgroundTransparency = "Choice" .. Count, Count, false, 1
		B.Image, B.ScaleType, B.ImageColor3, B.ImageTransparency = Art.Image, Art.ScaleType, Art.ImageColor3, Art.ImageTransparency
		B.AnchorPoint, B.Size, B.ZIndex = Art.AnchorPoint, Art.Size, Art.ZIndex
		for _, C in ipairs(Art:GetChildren()) do C.Parent = B end
		Art:Destroy()
		SetText(B, "Head", Text)
		local Sel = B:FindFirstChild("Selected")
		if Sel then
			Sel.Visible = false
			B.MouseEnter:Connect(function() Sel.Visible = true end)
			B.MouseLeave:Connect(function() Sel.Visible = false end)
		end
		B.Activated:Connect(function() if Window == S then Fn() end end) -- dead while it settles out
		B.Parent = List
		local M = Motion()
		if M then M.Button(B) end
		return B
	end
	local function Clear()
		Count = 0
		for _, C in ipairs(List:GetChildren()) do
			if C:IsA("GuiButton") then C:Destroy() end
		end
		List.CanvasPosition = Vector2.zero
	end
	local function ForText()
		return "Ticket for: " .. (For and Escape(For.DisplayName) or "me")
	end
	local function ForChoice()
		local B
		B = Choice(ForText(), function() -- cycles me -> each other player -> me
			local Others = {}
			for _, Q in ipairs(Players:GetPlayers()) do
				if Q ~= Player then table.insert(Others, Q) end
			end
			local Next = nil
			if not For then
				Next = Others[1]
			else
				for I, Q in ipairs(Others) do
					if Q == For then Next = Others[I + 1] break end
				end
			end
			For = Next
			SetText(B, "Head", ForText())
		end)
	end
	function Show(Line)
		Clear()
		if #Rows == 0 then
			Say("No trains run from here yet.")
		elseif not Line then -- several lines: where to?
			Say("Where to?")
			ForChoice()
			for _, L in ipairs(Rows) do
				Choice("To " .. Escape(RegionName(L.To)), function() Picked = L Show(L) end)
			end
		else
			local Held = Line.Held and Travel.Classes[Line.Held]
			Say(("Tickets to %s. Which class?%s"):format(Escape(RegionName(Line.To)),
				Held and (" You're holding a " .. Held.Name .. " ticket for it.") or ""))
			ForChoice()
			for _, C in ipairs(Travel.ClassOrder) do
				Choice(("%s - $%d"):format(Travel.Classes[C].Name, Line.Prices[C] or 0), function()
					local Ok, Why = Ask("Buy", {Route = Line.Route, Class = C, For = For and For.Parent and For.UserId or nil})
					if Window == S then Say(Ok and "Bought. Board when the doors open." or Escape(Why or "Couldn't buy that.")) end
				end)
			end
			if #Rows > 1 then Choice("Another line", function() Picked = nil Show(nil) end) end
		end
		Choice("Never mind", CloseTickets)
		Fit()
	end
	Box.Parent = S
	S.Parent = Player:WaitForChild("PlayerGui")
	Show(Picked)
	local function On(Signal, Fn) table.insert(Conns, Signal:Connect(Fn)) end
	local Camera = workspace.CurrentCamera
	if Camera then On(Camera:GetPropertyChangedSignal("ViewportSize"), function() task.defer(Fit) end) end
	On(Box.AncestryChanged, function() task.defer(Fit) end) -- (moved into another host)
	-- the real dialogue hides the vitals and hotbar while it's up; so does this
	local Uis = LiveUis()
	local Hud = Uis and Uis:FindFirstChild("HUD")
	HiddenHud = {}
	for _, Name in ipairs({"Stats", "Bottom"}) do
		local G = Hud and Hud:FindFirstChild(Name)
		if G and G.Visible then G.Visible = false table.insert(HiddenHud, G) end
	end
	-- closes on: another menu (its backdrop shows), a real conversation, Esc, death, and leaving the clerk
	for _, Name in ipairs({"bg", "Dialogue"}) do
		local G = Uis and Uis:FindFirstChild(Name)
		if G then On(G:GetPropertyChangedSignal("Visible"), function() if G.Visible and Window == S then CloseTickets() end end) end
	end
	On(UserInputService.InputBegan, function(Input)
		if Input.KeyCode == Enum.KeyCode.Escape and Window == S then CloseTickets() end
	end)
	local Hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
	if Hum then On(Hum.Died, function() if Window == S then CloseTickets() end end) end
	task.spawn(function()
		while Window == S do
			task.wait(0.5)
			if Window == S and not NearClerk() then CloseTickets() end
		end
	end)
	local M = Motion()
	if M then M.Open(Box) end
end

-- departure boards: parts tagged RenseiDepartureBoard (named DepartureBoard) get a SurfaceGui with the next train on
-- each line that runs from here (the server lists them in Remotes.Travel's "Lines" attribute), written on the Party
-- Invitation panel (HUD2.Party, without its buttons)
local function BoardCard(B)
	local SG = B:FindFirstChild("Board")
	if SG and not SG:FindFirstChild("Card") then SG:Destroy() SG = nil end -- an older board's plain label
	if SG then return SG.Card end
	local Card = Template("HUD2.Party")
	if not Card then return nil end
	SG = Instance.new("SurfaceGui")
	SG.Name, SG.Face, SG.SizingMode, SG.PixelsPerStud = "Board", Enum.NormalId.Front, Enum.SurfaceGuiSizingMode.PixelsPerStud, 40
	SG.ZIndexBehavior, SG.LightInfluence = Enum.ZIndexBehavior.Sibling, 0
	Card.Name, Card.AnchorPoint, Card.Position, Card.Size = "Card", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1)
	local Buttons = Card:FindFirstChild("Buttons")
	if Buttons then Buttons:Destroy() end
	SetText(Card, "Head", "DEPARTURES")
	Card.Parent = SG
	SG.Parent = B
	return Card
end
local function Boards()
	while true do
		local Now = workspace:GetServerTimeNow()
		local Lines = {}
		for RouteId in string.gmatch(Remote:GetAttribute("Lines") or "", "[^,]+") do
			local D = Travel.NextDeparture(RouteId, Now)
			if D then
				local Left = math.max(0, math.floor(D - Now))
				table.insert(Lines, ("%s  %d:%02d%s"):format(Escape(RegionName(Travel.Other(RouteId, Here))), Left // 60, Left % 60,
					Travel.BoardingOpen(RouteId, Now) and '  <font color="#D6C85A">BOARDING</font>' or ""))
			end
		end
		local Text = #Lines > 0 and table.concat(Lines, "<br />") or "NO SERVICE"
		for _, B in ipairs(CollectionService:GetTagged("RenseiDepartureBoard")) do
			if B:IsA("BasePart") and B:IsDescendantOf(workspace) then
				local Card = BoardCard(B)
				if Card then SetText(Card, "MainText", Text) end
			end
		end
		task.wait(1)
	end
end

-- the ride: scenery blocks scroll past the ride train's windows
local Scenery
local function RideTrainOf(Route)
	for _, T in ipairs(CollectionService:GetTagged("RenseiRideTrain")) do
		if T:GetAttribute("Route") == Route and T:IsDescendantOf(workspace) then return T end
	end
	return nil
end
local function Ride(Seconds, Route)
	FadeTo(0, 0.5)
	task.wait(0.7)
	FadeTo(1, 0.8)
	local Train = RideTrainOf(Route)
	local T0 = os.clock()
	while not Train and os.clock() - T0 < 2 do task.wait(0.1) Train = RideTrainOf(Route) end
	if not Train then return end
	if Scenery then Scenery:Destroy() end
	local Length = Train:GetAttribute("Length") or 440
	local CF = Train:GetPivot() * CFrame.new(0, 0, -Length / 2) -- the pivot is the nose; the train runs back along -Z
	local Mine = Instance.new("Folder")
	Mine.Name = "RideScenery"
	Mine.Parent = workspace
	Scenery = Mine
	local Span = Length / 2 + 60
	local Blocks = {}
	local Rnd = Random.new()
	for I = 1, 60 do
		local P = Instance.new("Part")
		P.Anchored, P.CanCollide, P.CanQuery, P.CanTouch, P.CastShadow = true, false, false, false, false
		local Tree = Rnd:NextNumber() < 0.6
		P.Size = Tree and Vector3.new(6, Rnd:NextNumber(12, 24), 6) or Vector3.new(Rnd:NextNumber(10, 30), Rnd:NextNumber(2, 8), 8)
		P.Material = Tree and Enum.Material.LeafyGrass or Enum.Material.Grass
		P.Color = Tree and Color3.fromRGB(58, 86, 44) or Color3.fromRGB(96, 118, 64)
		local Side = (I % 2 == 0) and 1 or -1
		local Along = Rnd:NextNumber(-Span, Span)
		local Across = Side * Rnd:NextNumber(20, 90)
		P.CFrame = CF * CFrame.new(Across, P.Size.Y / 2 - 6, Along)
		P.Parent = Mine
		table.insert(Blocks, {Part = P, Across = Across, Along = Along, H = P.Size.Y / 2 - 6})
	end
	local Ground = Instance.new("Part")
	Ground.Anchored, Ground.CanCollide, Ground.CanQuery, Ground.CanTouch, Ground.Size = true, false, false, false, Vector3.new(400, 1, Span * 2 + 40)
	Ground.Material, Ground.Color, Ground.CFrame = Enum.Material.Grass, Color3.fromRGB(82, 106, 54), CF * CFrame.new(0, -7, 0)
	Ground.Parent = Mine
	local Speed, Start = 70, os.clock()
	local Conn
	Conn = RunService.RenderStepped:Connect(function(Dt)
		if os.clock() - Start > Seconds + 2 or Scenery ~= Mine then Conn:Disconnect() return end
		for _, B in ipairs(Blocks) do
			B.Along -= Speed * Dt -- the train runs nose-first (+Z), so the land goes by towards -Z
			if B.Along < -Span then B.Along += Span * 2 end
			B.Part.CFrame = CF * CFrame.new(B.Across, B.H, B.Along)
		end
	end)
	task.delay(Seconds + 6, function() -- if RideEnd never comes (the server put us back), tidy up
		if Scenery == Mine then Mine:Destroy() Scenery = nil end
	end)
end

-- the rail's teleport screen (TeleportGui): the menus' backdrop and the area panel, as the road's
local function TeleportScreen(Dest)
	local S = Instance.new("ScreenGui")
	S.IgnoreGuiInset = true
	local B = Template("bg")
	if B then
		local P = AreaPanel(Dest or "the station", ("Pulling into %s..."):format(Escape(Dest or "the station")), "ON THE RAILS")
		if P then P.Parent = B end
		B.Parent = S
		TeleportService:SetTeleportGui(S)
	end
	FadeTo(0, 0.5)
end

-- ===== Road journeys (RoadService, World plan 1 Task 8) =====
-- Built only from the game's own UI art (owner rule 2026-10-21), cloned from the Uis templates:
--   * travel card    = the Party Invitation panel (HUD2.Party: Head, MainText, Buttons.Accept / Decline);
--   * journey screen = the menu backdrop (bg, with its vignettes), the area panel (HUD2.NewAreaDiscovered) and the
--                      boss bar (HUD.BossHealth) as the road: From on its left, the destination on its right, the
--                      party's progress as its fill (Modules.UI.Fill), the time left in the middle;
--   * teleport screen (TeleportGui) = the same backdrop and area panel.
-- (Template, Lift, SetText, Escape and AreaPanel are at the top: the ticket window and boards use them too.)
-- "Set off" only asks: the server checks the road, the exit, the leader and the level, and rolls the ambush.
local Fill = require(ReplicatedStorage.Modules.UI.Fill)
local Card
local function CloseCard()
	if Card then Card:Destroy() Card = nil end
end
local function RoadCard(Data)
	CloseCard()
	CloseTickets()
	local F = Template("HUD2.Party")
	if not F then return end
	F.Name = "RoadCard"
	F.AnchorPoint, F.Position, F.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.4), UDim2.fromScale(0.3, 1) -- PROPOSAL: 0.3 of the
	-- screen wide; the art's own 2.34:1 ratio constraint sets the height
	Lift(F, 45)
	local Names = {}
	for _, N in ipairs(type(Data.Party) == "table" and Data.Party or {}) do table.insert(Names, Escape(N)) end
	local Body = ("To %s, about %d s<br />Ambush risk %d%%<br />Coming: %s"):format(Escape(Data.Dest or "?"),
		tonumber(Data.Seconds) or 0, tonumber(Data.Risk) or 0, #Names > 0 and table.concat(Names, ", ") or "you")
	SetText(F, "Head", "THE ROAD")
	SetText(F, "MainText", Body)
	SetText(F, "Buttons.Accept.Vitality", "Set off")
	SetText(F, "Buttons.Decline.Strengh", "Not yet")
	F.Parent = Gui
	Card = F
	local Buttons = F:FindFirstChild("Buttons")
	local Go, No = Buttons and Buttons:FindFirstChild("Accept"), Buttons and Buttons:FindFirstChild("Decline")
	if Go then
		Go.Activated:Connect(function()
			local Ok, Why = Ask("Road", {Route = Data.Route})
			if Ok then CloseCard() elseif Card == F then SetText(F, "MainText", Escape(Why or "You can't set off yet.")) end
		end)
	end
	if No then No.Activated:Connect(CloseCard) end
end

local Journey, JourneyShown, RoadTeleportGui
JourneyActive = function() return Journey ~= nil end -- the ticket window won't open over the journey screen
local function CloseJourney()
	if Journey then Journey:Destroy() Journey = nil end
	if RoadTeleportGui then -- the road's teleport screen goes with it (a later teleport sets its own)
		pcall(function() TeleportService:SetTeleportGui(nil) end)
		RoadTeleportGui:Destroy()
		RoadTeleportGui = nil
	end
end
local function JourneyScreen(Data)
	CloseCard()
	CloseJourney()
	local Seconds = math.max(tonumber(Data.Seconds) or 40, 1) -- the route's trip time (the text)
	local Total = math.max(tonumber(Data.Total) or Seconds, 0.1) -- the whole road in real seconds (the bar)
	local Ends = tonumber(Data.Ends) or (workspace:GetServerTimeNow() + Total) -- server time the road ends (resumed
	-- after an ambush, it carries on from where it stopped)
	local Dest, From = tostring(Data.Dest or "the road's end"), tostring(Data.From or "here")
	local S = Template("bg") -- the menus' backdrop, full screen
	if not S then return end
	S.Name = "Journey"
	local Line = ("From %s, about %d seconds on the road."):format(Escape(From), Seconds)
	local Panel = AreaPanel(Dest, Line)
	if Panel then Panel.Parent = S end
	local Bar = Template("HUD.BossHealth") -- the road: the party's progress fills it
	if Bar then
		Bar.AnchorPoint, Bar.Position = Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.66)
		SetText(Bar, "Head", Escape(From))
		SetText(Bar, "Text", Escape(Dest))
		Bar.Parent = S
	end
	Lift(S, 60) -- over the fade
	S.Parent = Gui
	Journey, JourneyShown = S, os.clock()
	task.spawn(function()
		while Journey == S do
			local Rest = math.max(0, Ends - workspace:GetServerTimeNow())
			local Left = math.ceil(Rest / Total * Seconds) -- in the route's seconds (Studio tests run it faster)
			if Bar and Bar:FindFirstChild("Bar") then Fill.Set(Bar.Bar, 1 - Rest / Total) end
			if Bar then SetText(Bar, "HP", ("%d:%02d"):format(Left // 60, Left % 60)) end
			task.wait(0.1)
		end
	end)
	-- what shows while the teleport runs (the TeleportGui carries over until the next place loads)
	local G = Instance.new("ScreenGui")
	G.IgnoreGuiInset = true
	local B = Template("bg")
	if B then
		local P = AreaPanel(Dest, Line)
		if P then P.Parent = B end
		B.Parent = G
		TeleportService:SetTeleportGui(G)
		RoadTeleportGui = G
	end
	task.delay(math.max(0, Ends - workspace:GetServerTimeNow()) + 10, function() -- never stuck behind it if the arrival never comes
		if Journey == S then CloseJourney() FadeTo(1, 0.3) end
	end)
end
local function EndJourney()
	local S = Journey
	if not S then return end
	task.delay(math.max(0, 3 - (os.clock() - (JourneyShown or 0))), function() -- PROPOSAL: shown at least 3 s
		if Journey == S then CloseJourney() end
	end)
end

Event.OnClientEvent:Connect(function(Kind, Data)
	Data = type(Data) == "table" and Data or {}
	if Kind == "RoadCard" then
		RoadCard(Data)
	elseif Kind == "RoadStart" then
		JourneyScreen(Data)
	elseif Kind == "RoadEnd" then
		EndJourney()
	elseif Kind == "RoadAmbush" then
		CloseCard()
		CloseJourney()
		FadeTo(0, 0.15)
		task.delay(0.4, function() FadeTo(1, 0.5) end) -- the words come as the game's own toast (RoadService)
	elseif Kind == "RoadCancel" then
		CloseJourney()
		FadeTo(1, 0.3) -- the reason comes as the game's own toast (RoadService)
	elseif Kind == "OpenTickets" then
		task.spawn(OpenTickets)
	elseif Kind == "Board" then
		local Left = math.max(0, math.floor((Data.Departs or 0) - workspace:GetServerTimeNow()))
		Toast(("All aboard. Departs in %d:%02d."):format(Left // 60, Left % 60))
	elseif Kind == "RideStart" then
		CloseTickets()
		task.spawn(Ride, Data.Seconds or 50, Data.Route)
	elseif Kind == "RideEnd" then
		TeleportScreen(Data.Dest or RegionName(Travel.Other(Data.Route, Here)))
		if Scenery then Scenery:Destroy() Scenery = nil end
		task.delay(3, function() FadeTo(1, 0.5) end) -- Studio loopback (or a failed hop): fade back in
	elseif Kind == "RideCancel" then
		task.delay(0.8, function()
			if Scenery then Scenery:Destroy() Scenery = nil end
			FadeTo(1, 0.3)
		end)
		if type(Data.Text) == "string" then Toast(Data.Text) end
	elseif Kind == "Message" then
		-- nothing more to show: StationService sends these same words as the game's toast (UIService.Notify)
	end
end)

task.spawn(Boards)

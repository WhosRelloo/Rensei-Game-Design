-- TravelClient (World plan 1, 2026-10-20): ticket window, departure boards, the ride's scenery and fades, the
-- teleport screen, and (Task 8b) roads on foot: the passage's banner and the crossing's walk, camera and darkness.
-- Server: StationService and RoadService (Remotes.Travel / Remotes.TravelEvent). Every number is a PROPOSAL.
-- Owner rule (2026-10-21): every visual here is built ONLY from the game's existing UI art, cloned from the
-- StarterGui.Uis templates (no new panels, corner blobs or drawn shapes):
--   * ticket window   = a look-alike of the NPC dialogue box (Uis.Dialogue: the box, its choice plates and highlight);
--   * papers check    = the same dialogue look-alike, the gate guard speaking: "Pay $X" / "Get searched" (Task 9);
--   * departure board = the Party Invitation panel (HUD2.Party) on the board's SurfaceGui;
--   * rail messages   = the game's own toast (HUD2.Notification, through UIState "Toast", as the server's toasts);
--   * teleport screen = the menus' backdrop (bg) and the area panel (HUD2.NewAreaDiscovered);
--   * roads on foot (Task 8b), below: the area panel as the passage's banner, the ride's black fade as the darkness;
--   * train countdown (2026-10-23) = the toast's plate (HUD2.Notification), small, under the compass.
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
-- the party roster (World plan 1 Task 10): PartyService sends it through UIService "Party" ({Members = {{Name,
-- UserId, Leader}}}, an empty list when the party ends). The ticket window's "Ticket for" choice offers these members,
-- the riders StationService.Buy accepts (For = a party member's UserId).
local Roster = {}
task.spawn(function() -- UIState waits for PlayerGui.Uis: don't hold the rest of this script up
	local Ok, M = pcall(require, ReplicatedStorage.Modules.UI.UIState)
	if not Ok then return end
	M.On("Party", function(P)
		Roster = (type(P) == "table" and type(P.Members) == "table") and P.Members or {}
	end)
end)

local Busy = false
-- (2026-10-23, the train countdown below) its own ticket check ("Prices") shares the server's rate limit
-- (StationService.AskGap, 0.25 s a player): it never goes out within 0.3 s of a request here, and a request here waits
-- out one that has just gone
local Querying, QueriedAt, LastAskAt = false, 0, 0
local ASK_GAP = 0.3 -- StationService.AskGap (0.25) plus slack
local function Ask(Op, Args)
	if Busy or not Remote:GetAttribute("Ready") then return false, "The clerk is busy." end
	Busy = true
	local T0 = os.clock()
	while (Querying or os.clock() - QueriedAt < ASK_GAP) and os.clock() - T0 < 3 do task.wait(0.05) end
	LastAskAt = os.clock()
	local Mine = {}
	local Token = Mine
	task.delay(10, function() if Token == Mine then Busy = false end end) -- never stuck if the server doesn't answer
	local Ok, A, B = pcall(function() return Remote:InvokeServer(Op, Args) end)
	Token = nil
	Busy = false
	LastAskAt = os.clock()
	if not Ok then return false, "No answer from the clerk." end
	return A, B
end

-- the train countdown's view of the tickets this player holds (the countdown itself is further down)
local Held = {} -- [RouteId] = true: a ticket held for that line, as the clerk's "Prices" answer last said (Held)
local CheckAt = 0 -- os.clock() of the countdown's next ticket check
local function SetHeld(Rows) -- a "Prices" answer: {{Route, Held = class or nil}, ...}
	table.clear(Held)
	for _, R in ipairs(Rows) do
		if type(R) == "table" and type(R.Route) == "string" and R.Held then Held[R.Route] = true end
	end
end
local function CheckSoon(Delay) CheckAt = math.min(CheckAt, os.clock() + (Delay or 0)) end

local function RegionName(Id)
	return Id and Places.Regions[Id] and Places.Regions[Id].Name or Id or "?"
end

-- ===== the ticket window: a look-alike of the NPC dialogue box (fix rounds 1-2, controller's rulings) =====
-- Cloned from Uis.Dialogue (not wired into DialogueService): the clerk "says" the line in MainFrame (97950998740350,
-- speaker "Ticket clerk"), and the answers are its choice plates (Choices.Choice1, 92726496845615, with the
-- Selected highlight 107749049761613 on hover), in the dialogue's own lettering. Choices: "Ticket for: <name>"
-- (cycles me -> each party member, sent by UserId; Task 10), one per class with its price, and "Never mind". A station with
-- several lines first asks "Where to?" with one choice per line. Placed like the real box (text above the choices,
-- at 66% of the screen); UIMotion opens and settles it. No number keys (they'd also reach the hotbar: HUDUI only
-- checks the real dialogue). It closes on Esc, another menu (Uis.bg), a real conversation (Uis.Dialogue), death,
-- respawn, and walking out of the clerk's reach. On a small or touch screen every choice is at least MIN_TOUCH px
-- tall; the box moves up to stay on screen, never past the top, and past that the choices scroll.
local Window
local OpenToken = 0
local Opening = nil -- the token of an open waiting for the clerk's prices
local CrossingActive = function() return false end -- set once the road crossing's state exists (below)
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
-- the dialogue look-alike (Task 9: shared by the ticket window and the papers check). Speaker: the name over the line;
-- Near(): false once the player has walked away (it closes); Fill(W) puts the first line and choices in, with
-- W = {S = the ScreenGui, Say(Text), Choice(Text, Fn) -> button, Clear(), Fit()}. Returns W, or nil without the Uis art.
local function DialogueWindow(Name, Speaker, Near, Fill)
	local Box = Template("Dialogue")
	local Main = Box and Box:FindFirstChild("MainFrame")
	local Authored = Box and Box:FindFirstChild("Choices")
	local RowArt = Authored and Authored:FindFirstChild("Choice1")
	if not (Main and Main:FindFirstChild("maintext") and RowArt and RowArt:FindFirstChild("Head")) then -- no Uis art here
		if Box then Box:Destroy() end
		return
	end
	local S = Instance.new("ScreenGui")
	S.Name, S.ResetOnSpawn, S.DisplayOrder, S.ZIndexBehavior = Name, false, 49, Enum.ZIndexBehavior.Sibling
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
	SetText(Main, "Title", Speaker)
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
	Box.Parent = S
	S.Parent = Player:WaitForChild("PlayerGui")
	local W = {S = S, Say = Say, Choice = Choice, Clear = Clear, Fit = Fit}
	Fill(W)
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
	-- closes on: another menu (its backdrop shows), a real conversation, Esc, death, and walking away
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
			if Window == S and not Near() then CloseTickets() end
		end
	end)
	local M = Motion()
	if M then M.Open(Box) end
	return W
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
	-- the clerk answered: still wanted? (closed, reopened, a ride or road fade, or a road crossing meanwhile)
	if OpenToken ~= Mine or type(Rows) ~= "table" then return end
	SetHeld(Rows) -- (the countdown: the clerk's answer is the freshest word on the tickets held)
	if Fade.BackgroundTransparency < 0.99 or CrossingActive() or not NearClerk() then return end
	DialogueWindow("Tickets", "Ticket clerk", NearClerk, function(W)
		local S, Say, Choice, Clear, Fit = W.S, W.Say, W.Choice, W.Clear, W.Fit
		local For = nil -- nil = me, else a party roster entry {Name, UserId}
		local Picked = #Rows == 1 and Rows[1] or nil -- the line being bought for (one line: straight to its classes)
		local Show
		local function ForText()
			local Q = For and Players:GetPlayerByUserId(For.UserId)
			return "Ticket for: " .. (For and Escape(Q and Q.DisplayName or tostring(For.Name)) or "me")
		end
		local function ForChoice()
			local B
			B = Choice(ForText(), function() -- cycles me -> each party member -> me (Task 10: the party, not everyone)
				local Others = {}
				for _, M in ipairs(Roster) do
					if type(M) == "table" and type(M.UserId) == "number" and M.UserId ~= Player.UserId then table.insert(Others, M) end
				end
				local Next = nil
				if not For then
					Next = Others[1]
				else
					for I, M in ipairs(Others) do
						if M.UserId == For.UserId then Next = Others[I + 1] break end
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
						local ForMe = For == nil
						local Ok, Why = Ask("Buy", {Route = Line.Route, Class = C, For = For and For.UserId or nil})
						if Ok and ForMe then Held[Line.Route] = true end -- the countdown shows at once
						CheckSoon(0.5)
						if Window == S then Say(Ok and "Bought. Board when the doors open." or Escape(Why or "Couldn't buy that.")) end
					end)
				end
				if #Rows > 1 then Choice("Another line", function() Picked = nil Show(nil) end) end
			end
			Choice("Never mind", CloseTickets)
			Fit()
		end
		Show(Picked)
	end)
end

-- ===== the papers check (Task 9): the gate guard asks a Wanted 1-2 player for a bribe, or to be searched =====
-- StationService pushes them back off the gate and sends "GateBribe" {Route, Cost}. "Pay $X" asks the server ("Bribe");
-- "Get searched" asks "Search". Either clears the gate for 10 minutes; then they walk on through. A refusal (Wanted 3+)
-- is only the guard's line, as the game's own toast (the server's UIService.Notify).
local GATE_REACH = 16 -- StationService.GateReach
local function NearGate()
	local Root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
	if not Root then return false end
	for _, G in ipairs(CollectionService:GetTagged("RenseiStationGate")) do
		if G:IsA("BasePart") and G:IsDescendantOf(workspace) and (G.Position - Root.Position).Magnitude <= GATE_REACH then return true end
	end
	return false
end
local function OpenBribe(Data)
	if Window and Window.Name == "GateBribe" then return end -- already asking (the guard pushes on every touch)
	if Opening or Fade.BackgroundTransparency < 0.99 or CrossingActive() or not NearGate() then return end
	CloseTickets()
	local Cost = math.floor(tonumber(Data.Cost) or 0)
	DialogueWindow("GateBribe", "Gate guard", NearGate, function(W)
		local Done = false
		local function After(Line) -- the answer, then the window settles out
			Done = true
			W.Clear()
			W.Say(Line)
			W.Fit()
			task.delay(1.6, function() if Window == W.S then CloseTickets() end end)
		end
		W.Say(("Papers... Hm. Your face is familiar. $%d and I never saw you. Or I search you."):format(Cost))
		W.Choice(("Pay $%d"):format(Cost), function()
			if Done then return end
			local Ok, Why = Ask("Bribe", {Route = Data.Route})
			if Window ~= W.S then return end
			if Ok then After("Go on, then. Quickly.") else W.Say(Escape(Why or "Guard: \"No.\"")) end
		end)
		W.Choice("Get searched", function()
			if Done then return end
			local Ok, Why = Ask("Search")
			if Window ~= W.S then return end
			if Ok then After("Clean. Go on through.") else W.Say(Escape(Why or "Guard: \"No.\"")) end
		end)
		W.Fit()
	end)
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

-- the rail's teleport screen (TeleportGui): the menus' backdrop and the area panel
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

-- ===== Roads on foot (World plan 1 Task 8b, world spec §3b; server: RoadService) =====
-- Built only from what the game already has (owner rule 2026-10-21):
--   * the passage's banner = the area panel (the live Uis.HUD2.NewAreaDiscovered), shown when you walk onto a passage:
--     UIMotion's own HUD2 hook punches it in (Pop + SlideIn), and UIMotion.Fade takes it out;
--   * the crossing's darkness = the ride's full-screen black fade (Fade, above); the TeleportGui is the same black, so
--     the teleport is hidden;
--   * the camera: a low follow shot down the road, eased in and out (no UI).
-- While crossing, the character walks on down the road by itself (Humanoid:Move, with the controls taken over) in the
-- game's own walk or run: a running sprint keeps running (ClientHandler.Run), and WalkSpeed is never touched.
local Controls
local function SetControls(On) -- the PlayerModule's controls (move keys, thumbstick)
	if Controls == nil then
		local Ok, PM = pcall(function() return require(Player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)) end)
		Controls = Ok and PM and PM:GetControls() or false
	end
	if Controls then pcall(function() if On then Controls:Enable() else Controls:Disable() end end) end
end
local function RunModule() -- ClientHandler's sprint (the same module table: one client VM)
	local PS = Player:FindFirstChild("PlayerScripts")
	local CH = PS and PS:FindFirstChild("ClientHandler")
	local M = CH and CH:FindFirstChild("Run")
	if not M then return nil end
	local Ok, Run = pcall(require, M)
	return Ok and type(Run) == "table" and Run or nil
end
local function Slow() -- Studio only: Player attribute CrossingSlow stretches the crossing's timings (for screenshots)
	return RunService:IsStudio() and math.max(tonumber(Player:GetAttribute("CrossingSlow")) or 1, 1) or 1
end
local function Smooth(T) T = math.clamp(T, 0, 1) return T * T * (3 - 2 * T) end
local function Flat(V) V = Vector3.new(V.X, 0, V.Z) return V.Magnitude > 1e-3 and V.Unit or Vector3.new(0, 0, -1) end
-- the low follow shot: behind the hip and a little to the right, looking down the road
local function FollowShot(Root, Dir)
	local Right = Dir:Cross(Vector3.yAxis)
	local Eye = Root.Position - Dir * 9 + Vector3.new(0, 1.2, 0) + Right * 2.2 -- PROPOSAL
	return CFrame.lookAt(Eye, Root.Position + Dir * 40 + Vector3.new(0, 1.5, 0))
end

local Cross = nil -- the crossing being shown: {Dir, Zoom, Conn}
local CrossGui -- the TeleportGui (the same black)
local BannerQuietUntil = 0 -- no passage banner until then (arriving by road)
CrossingActive = function() return Cross ~= nil end
local function Body()
	local C = Player.Character
	return C and C:FindFirstChildOfClass("Humanoid"), C and C:FindFirstChild("HumanoidRootPart")
end
local function DropCrossGui()
	if CrossGui then
		pcall(function() TeleportService:SetTeleportGui(nil) end)
		CrossGui:Destroy()
		CrossGui = nil
	end
end
local function EndCrossing(Lift) -- control back, and the player's own camera
	local C = Cross
	Cross = nil
	if C and C.Conn then C.Conn:Disconnect() end
	local Hum = Body()
	if Hum then Hum:Move(Vector3.zero) end
	local Cam = workspace.CurrentCamera
	if Cam then Cam.CameraType = Enum.CameraType.Custom end
	SetControls(true)
	DropCrossGui()
	if Lift then FadeTo(1, 0.4) end
end
Player.CharacterAdded:Connect(function() if Cross then EndCrossing(true) end end)

-- "Crossing": walk on into the threshold, the camera into the follow shot, the road's darkness over the teleport
local function Crossing(Data)
	CloseTickets()
	if Cross then EndCrossing(false) end
	local Hum, Root = Body()
	local Cam = workspace.CurrentCamera
	if not (Hum and Root and Cam) then return end
	local Dir = Flat(typeof(Data.Dir) == "Vector3" and Data.Dir or Root.CFrame.LookVector)
	local K = Slow()
	local Mine = {Dir = Dir, Zoom = math.clamp((Cam.CFrame.Position - Cam.Focus.Position).Magnitude, 4, 30)}
	Cross = Mine
	SetControls(false)
	local From = Cam.CFrame
	Cam.CameraType = Enum.CameraType.Scriptable
	local T0 = os.clock()
	Mine.Conn = RunService.RenderStepped:Connect(function()
		if Cross ~= Mine then return end
		local H, R = Body()
		if not (H and R) then return end
		H:Move(Dir, false) -- on down the road, in whatever gait they had
		Cam.CFrame = From:Lerp(FollowShot(R, Dir), Smooth((os.clock() - T0) / (0.8 * K))) -- PROPOSAL: 0.8 s ease
	end)
	-- the road darkening under the trees, done by the time the server sends them (CrossDelay 1.2 s)
	task.delay(0.3 * K, function() if Cross == Mine then FadeTo(0, 0.85 * K) end end)
	DropCrossGui()
	local G = Instance.new("ScreenGui")
	G.Name, G.IgnoreGuiInset, G.DisplayOrder = "RoadDark", true, 100
	local Black = Fade:Clone()
	Black.BackgroundTransparency = 0
	Black.Parent = G
	pcall(function() TeleportService:SetTeleportGui(G) end)
	CrossGui = G
	task.delay(20 * K, function() if Cross == Mine then EndCrossing(true) end end) -- never stuck in the dark
end

-- "CrossingIn": arrived at RoadStart. Walk in from the same shot, lift the darkness, ease back to the player's camera.
local function CrossingIn(Data)
	local Prev = Cross
	if Prev and Prev.Conn then Prev.Conn:Disconnect() end
	Cross = nil
	DropCrossGui()
	local C = Player.Character or Player.CharacterAdded:Wait()
	local Hum, Root = C:WaitForChild("Humanoid", 5), C:WaitForChild("HumanoidRootPart", 5)
	local Cam = workspace.CurrentCamera
	BannerQuietUntil = os.clock() + 5 -- already on the passage: no "The North Road" banner for arriving
	if not (Hum and Root and Cam) then FadeTo(1, 0.5) SetControls(true) return end
	local Dir = Flat(typeof(Data.Dir) == "Vector3" and Data.Dir or Root.CFrame.LookVector)
	local K = Slow()
	local Mine = {Dir = Dir, Zoom = Prev and Prev.Zoom or 12.5}
	Cross = Mine
	Fade.BackgroundTransparency = 0 -- (it already is: the crossing out, or a road arrival's load)
	SetControls(false)
	local Run = RunModule() -- a live arrival with Shift still held (or the RUN toggle) comes in running
	if Run and Run.IsActive and Run.Wanted and not Run:IsActive() and Run:Wanted() then pcall(Run.OnStartClient, Run) end
	Cam.CameraType = Enum.CameraType.Scriptable
	local Walk, Ease = 1.5 * K, 0.6 * K -- PROPOSAL (brief): walked in for about 1.5 s; the camera eases back in its last 0.6
	local T0 = os.clock()
	FadeTo(1, 0.8 * K)
	Mine.Conn = RunService.RenderStepped:Connect(function()
		if Cross ~= Mine then return end
		local H, R = Body()
		if not (H and R) then return end
		local T = os.clock() - T0
		H:Move(Dir, false)
		local Shot = FollowShot(R, Dir)
		local Focus = R.Position + Vector3.new(0, 1.5, 0)
		local Own = CFrame.lookAt(Focus - Dir * Mine.Zoom * 0.94 + Vector3.new(0, Mine.Zoom * 0.34, 0), Focus) -- behind, at their zoom
		Cam.CFrame = Shot:Lerp(Own, Smooth((T - (Walk - Ease)) / Ease))
		if T >= Walk then EndCrossing(false) end
	end)
	task.delay(Walk + 3, function() if Cross == Mine then EndCrossing(true) end end)
end

-- a live road arrival loads in the dark (the TeleportGui's black is gone by now): stay dark until CrossingIn
do
	local Ok, TD = pcall(function() return TeleportService:GetLocalPlayerTeleportData() end)
	if Ok and type(TD) == "table" and type(TD.Travel) == "table" and TD.Travel.Arrive == "RoadStart" then
		Fade.BackgroundTransparency = 0
		BannerQuietUntil = math.huge
		task.delay(15, function() -- no CrossingIn (the arrival went elsewhere): light back
			if BannerQuietUntil == math.huge then BannerQuietUntil = 0 FadeTo(1, 0.5) end
		end)
	end
end

-- the passage's banner: walking onto a passage shows "ON THE ROAD / The North Road / to the Foundry Yard" on the area
-- panel. Turning back is just walking back.
local BannerToken
local function Banner(Part)
	local Uis = LiveUis()
	local HUD2 = Uis and Uis:FindFirstChild("HUD2")
	local F = HUD2 and HUD2:FindFirstChild("NewAreaDiscovered")
	if not F then return end
	SetText(F, "Header.Title", "ON THE ROAD")
	SetText(F, "Header.Head", Escape(Part:GetAttribute("RoadName") or "The Road"))
	SetText(F, "MainText", "to " .. Escape(RegionName(Part:GetAttribute("To"))))
	local Mine = {}
	BannerToken = Mine
	F.Visible = false
	F.Visible = true -- UIMotion's HUD2 hook punches it in
	task.delay(4, function() -- PROPOSAL: shown for 4 s, like the area card
		if BannerToken ~= Mine then return end
		local M = Motion()
		if M and M.Fade then M.Fade(F, false, 0.4) else F.Visible = false end
	end)
end
local function InPart(P, Pos)
	local L = P.CFrame:PointToObjectSpace(Pos)
	return math.abs(L.X) <= P.Size.X / 2 and math.abs(L.Y) <= P.Size.Y / 2 and math.abs(L.Z) <= P.Size.Z / 2
end
task.spawn(function()
	local On = nil -- the route of the passage we're on
	while true do
		task.wait(0.25)
		local _, R = Body()
		local Part
		if R then
			for _, P in ipairs(CollectionService:GetTagged("RenseiRoadPassage")) do
				if P:IsA("BasePart") and P:IsDescendantOf(workspace) and InPart(P, R.Position) then Part = P break end
			end
		end
		local Route = Part and Part:GetAttribute("Route")
		if Route ~= On then
			local Was = On
			On = Route
			if Route and not Was and not Cross and os.clock() >= BannerQuietUntil then Banner(Part) end
		end
	end
end)

-- ===== the train countdown (2026-10-23, owner: "when players buy a train ticket, they see how much time it has until
-- it leaves LIVE on their screen") =====
-- A slim plate under the compass: "Train to <destination> leaves in M:SS", and once the doors open (Travel.BoardingWindow
-- before departure) "Boarding now — doors close in M:SS" (PROPOSAL wording). It ticks every second on the shared clock
-- with the timetable maths the server departs on (Travel.NextDeparture: StationService's Clock departs on the same
-- slots of os.time(); the departure boards use workspace:GetServerTimeNow() too). A missed train rolls on to the next
-- departure (tickets stay valid). Shown while this player holds a ticket for a line that runs from here (Remotes.Travel
-- "Lines") and is at the station; hidden while riding (RideStart to the ride's end), with no ticket held, away from the
-- station, in a menu / a conversation / a cutscene / a road crossing / the ride's fade, and while dead.
-- The tickets held come from the clerk's own "Prices" answer (its Held per line; no new server code): asked on reaching
-- the station, after a purchase, a profile sync or a toast (a ticket bought for you), after a ride is cancelled or ends,
-- and every HELD_POLL seconds while at the station.
-- Art: the game's own toast plate (HUD2.Notification, cloned) with its own lettering, smaller; UIMotion fades, slides
-- and pops it in and fades it out. It sits under the compass strip, like the In Combat badge (CombatLogUI), and moves
-- down under the boss bar, the In Combat badge or a toast that would cover it.
local GuiService = game:GetService("GuiService")
local HELD_POLL = 8 -- PROPOSAL: seconds between ticket checks while at the station
local STATION_REACH = 90 -- PROPOSAL: studs from the clerk, the departure board or the gate that count as the station
local TRAIN_REACH = 30 -- PROPOSAL: studs from the platform train's box that count as the station
local CD_GOLD = "#E6CD78" -- the time, in the gold the HUD's popups use
local Riding = false -- from RideStart until the ride is over (cancelled, or ended and gone)
local BoardedFor = nil -- {Route, Departs}: the server's "Board" (aboard for that departure)
local function CheckHeld() -- one "Prices" check, if the remote is free; true when it answered
	if Querying or Busy or Opening or not Remote:GetAttribute("Ready") then return false end
	if os.clock() - LastAskAt < ASK_GAP then return false end
	Querying = true
	local Ok, Rows = pcall(function() return Remote:InvokeServer("Prices") end)
	Querying, QueriedAt = false, os.clock()
	if not (Ok and type(Rows) == "table") then return false end -- ("One moment.": try again shortly)
	SetHeld(Rows)
	return true
end
task.spawn(function() -- a purchase syncs the profile; a ticket bought for you comes with a toast
	local Ok, M = pcall(require, ReplicatedStorage.Modules.UI.UIState)
	if not Ok then return end
	M.On("Toast", function() CheckSoon(0.5) end)
	M.Changed:Connect(function() CheckSoon(0.5) end)
end)

local TrainBoxes, BoxesAt = {}, -math.huge
local function AtStation()
	local _, Root = Body()
	if not Root then return false end
	local Pos = Root.Position
	for _, Tag in ipairs({"RenseiTicketClerk", "RenseiDepartureBoard", "RenseiStationGate"}) do
		for _, P in ipairs(CollectionService:GetTagged(Tag)) do
			if P:IsA("BasePart") and P:IsDescendantOf(workspace) and (P.Position - Pos).Magnitude <= STATION_REACH then return true end
		end
	end
	if os.clock() - BoxesAt > 5 then -- the platform trains are anchored: their boxes, now and then
		BoxesAt = os.clock()
		table.clear(TrainBoxes)
		for _, T in ipairs(CollectionService:GetTagged("RenseiPlatformTrain")) do
			if T:IsA("Model") and T:IsDescendantOf(workspace) then
				local Ok, CF, Size = pcall(function() return T:GetBoundingBox() end)
				if Ok then table.insert(TrainBoxes, {CF, Size / 2}) end
			end
		end
	end
	for _, B in ipairs(TrainBoxes) do
		local L, H = B[1]:PointToObjectSpace(Pos), B[2]
		local Out = Vector3.new(math.max(math.abs(L.X) - H.X, 0), math.max(math.abs(L.Y) - H.Y, 0), math.max(math.abs(L.Z) - H.Z, 0))
		if Out.Magnitude <= TRAIN_REACH then return true end
	end
	return false
end

local function CountdownHidden()
	if Fade.BackgroundTransparency < 0.99 or CrossingActive() then return true end
	local Uis = LiveUis()
	for _, Name in ipairs({"bg", "Dialogue"}) do -- a menu's backdrop, a real conversation
		local G = Uis and Uis:FindFirstChild(Name)
		if G and G.Visible then return true end
	end
	local Cam = workspace.CurrentCamera
	if Cam and Cam.CameraType == Enum.CameraType.Scriptable then return true end -- cutscenes
	local Hum = Body()
	return not Hum or Hum.Health <= 0
end

local CdGui, CdHolder, CdPlate, CdAspect, CdY
local function BuildCountdown()
	local P = Template("HUD2.Notification")
	if not (P and P:FindFirstChild("Head")) then
		if P then P:Destroy() end
		return false
	end
	CdGui = Instance.new("ScreenGui")
	CdGui.Name, CdGui.ResetOnSpawn, CdGui.IgnoreGuiInset, CdGui.DisplayOrder = "TrainCountdown", false, true, 5 -- (as the compass)
	CdGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- where the plate sits (layout only, transparent); UIMotion slides the plate itself inside it
	CdHolder = Instance.new("Frame")
	CdHolder.Name, CdHolder.BackgroundTransparency, CdHolder.AnchorPoint = "Holder", 1, Vector2.new(0.5, 0)
	CdHolder.Position, CdHolder.Size = UDim2.new(0.5, 0, 0, 42), UDim2.fromOffset(400, 27)
	CdHolder.Parent = CdGui
	local A = P:FindFirstChildOfClass("UIAspectRatioConstraint")
	CdAspect = A and A.AspectRatio or 14.842
	P.Name, P.AnchorPoint, P.Position, P.Size, P.Visible = "Plate", Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0), UDim2.fromScale(1, 1), false
	P.Head.Size = UDim2.fromScale(0.78, 0.66) -- PROPOSAL: the line between the plate's end ornaments (the toast's is narrower)
	SetText(P, "Head", "")
	P.Parent = CdHolder
	CdGui.Parent = Player:WaitForChild("PlayerGui")
	CdPlate = P
	return true
end

-- the plate's top (screen pixels): under the compass strip (CompassUI: top 6, 32 tall; 12 with the compass off), as
-- the In Combat badge sits; under the boss bar (HUDUI's BossBarBottom), the badge, or a toast that would cover it
local function CountdownY(H)
	local Y = Player:GetAttribute("ShowCompass") == false and 12 or 42
	local Boss = Player:GetAttribute("BossBarBottom")
	if type(Boss) == "number" then Y = math.max(Y, Boss + 6) end
	local PG = Player:FindFirstChild("PlayerGui")
	local Log = PG and PG:FindFirstChild("CombatLog")
	local Badge = Log and Log:FindFirstChild("Badge")
	if Badge and Badge:IsA("GuiObject") and Badge.Visible then Y += 74 end -- (the badge is 72 tall, at this same top)
	local Uis = LiveUis()
	local HUD2 = Uis and Uis:FindFirstChild("HUD2")
	local Toast = HUD2 and HUD2:FindFirstChild("Notification")
	if Toast and Toast.Visible and Uis.Enabled then
		-- where the toast comes to rest (its authored place, not mid-slide)
		local Inset = Uis.IgnoreGuiInset and 0 or GuiService:GetGuiInset().Y
		local Top = HUD2.AbsolutePosition.Y + Inset + Toast.Position.Y.Scale * HUD2.AbsoluteSize.Y
		if Top < Y + H and Top + Toast.AbsoluteSize.Y > Y then Y = math.ceil(Top + Toast.AbsoluteSize.Y + 4) end
	end
	return Y
end

local function Layout()
	local VW = CdGui.AbsoluteSize.X
	if VW < 1 then return end
	local W = math.floor(math.min(math.clamp(VW * 0.3, 340, 460), VW - 32)) -- PROPOSAL: 30% of the screen, 340-460 px
	local H = math.floor(W / CdAspect)
	if CdHolder.Size.X.Offset ~= W then CdHolder.Size = UDim2.fromOffset(W, H) end
	local Y = CountdownY(H)
	if Y ~= CdY then
		CdY = Y
		if CdPlate.Visible then
			TweenService:Create(CdHolder, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Position = UDim2.new(0.5, 0, 0, Y)}):Play()
		else
			CdHolder.Position = UDim2.new(0.5, 0, 0, Y)
		end
	end
end

local function ShowCountdown(On)
	local M = Motion()
	if not M then CdPlate.Visible = On return end
	if On then
		M.Fade(CdPlate, true, 0.25)
		M.SlideIn(CdPlate, 0, -20)
		M.Pop(CdPlate, 0.85)
	else
		M.Fade(CdPlate, false, 0.3)
	end
end

local function MinSec(S)
	S = math.max(0, math.floor(S))
	return ("%d:%02d"):format(S // 60, S % 60)
end

-- what the plate says now (nil: nothing to show). Exposed for tests on the Player as attribute TrainCountdown.
local function CountdownText(Now)
	local Route, Departs
	for RouteId in string.gmatch(Remote:GetAttribute("Lines") or "", "[^,]+") do
		if Held[RouteId] then
			local D = Travel.NextDeparture(RouteId, Now)
			-- aboard: hold the departure boarded for through the second the server takes to depart (no flash of the
			-- next train's time before RideStart)
			local B = BoardedFor
			if B and B.Route == RouteId and Now >= B.Departs and Now < B.Departs + 3 then D = B.Departs end
			if D and (not Departs or D < Departs) then Route, Departs = RouteId, D end
		end
	end
	if not Route then return nil end
	local Left = Departs - Now
	if Left <= Travel.BoardingWindow then
		return ('Boarding now — doors close in <font color="%s">%s</font>'):format(CD_GOLD, MinSec(Left))
	end
	return ('Train to %s leaves in <font color="%s">%s</font>'):format(Escape(RegionName(Travel.Other(Route, Here))), CD_GOLD, MinSec(Left))
end

task.spawn(function()
	if not BuildCountdown() then return end
	local Shown, LastText, WasAt, Warned = false, nil, false, false
	while true do
		task.wait(0.25)
		local Ok, Err = pcall(function()
			local At = AtStation()
			if At and not WasAt then CheckSoon(0) end -- reached the station (or arrived): ask at once
			WasAt = At
			if At and os.clock() >= CheckAt then
				CheckAt = os.clock() + (CheckHeld() and HELD_POLL or 1)
			end
			local Text = CountdownText(workspace:GetServerTimeNow())
			local Want = Text ~= nil and At and not Riding and not CountdownHidden()
			if Want and Text ~= LastText then
				LastText = Text
				SetText(CdPlate, "Head", Text)
			end
			if RunService:IsStudio() then Player:SetAttribute("TrainCountdown", Want and Text or nil) end
			Layout()
			if Want ~= Shown then
				Shown = Want
				ShowCountdown(Want)
			end
		end)
		if not Ok and not Warned then
			Warned = true
			warn("[TravelClient] countdown: " .. tostring(Err))
		end
	end
end)

Event.OnClientEvent:Connect(function(Kind, Data)
	Data = type(Data) == "table" and Data or {}
	if Kind == "Crossing" then
		Crossing(Data)
	elseif Kind == "CrossingIn" then
		task.spawn(CrossingIn, Data)
	elseif Kind == "CrossingCancel" then
		EndCrossing(true) -- the reason comes as the game's own toast (RoadService)
	elseif Kind == "OpenTickets" then
		task.spawn(OpenTickets)
	elseif Kind == "GateBribe" then
		task.spawn(OpenBribe, Data)
	elseif Kind == "Board" then
		local Left = math.max(0, math.floor((Data.Departs or 0) - workspace:GetServerTimeNow()))
		Toast(("All aboard. Departs in %d:%02d."):format(Left // 60, Left % 60))
		if type(Data.Route) == "string" and type(Data.Departs) == "number" then BoardedFor = {Route = Data.Route, Departs = Data.Departs} end
	elseif Kind == "RideStart" then
		CloseTickets()
		Riding = true -- (the countdown hides for the ride)
		task.spawn(Ride, Data.Seconds or 50, Data.Route)
	elseif Kind == "RideEnd" then
		TeleportScreen(Data.Dest or RegionName(Travel.Other(Data.Route, Here)))
		if Scenery then Scenery:Destroy() Scenery = nil end
		task.delay(3, function() FadeTo(1, 0.5) end) -- Studio loopback (or a failed hop): fade back in
		task.delay(4, function() Riding = false CheckSoon(0) end) -- (still here: the ticket was used, or kept)
	elseif Kind == "RideCancel" then
		Riding = false
		BoardedFor = nil
		CheckSoon(1)
		task.delay(0.8, function()
			if Scenery then Scenery:Destroy() Scenery = nil end
			FadeTo(1, 0.3)
		end)
		if type(Data.Text) == "string" then Toast(Data.Text) end
	elseif Kind == "Message" then
		-- nothing more to show: StationService sends these same words as the game's toast (UIService.Notify)
		CheckSoon(1) -- (put back on the platform: the ticket is kept)
	end
end)

task.spawn(Boards)

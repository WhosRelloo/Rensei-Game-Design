-- TravelClient (World plan 1, 2026-10-20): ticket window, departure boards, the ride's scenery and fades, the
-- teleport screen, and (Task 8) the road's travel card and journey screen. Server: StationService and RoadService
-- (Remotes.Travel / Remotes.TravelEvent). Style matches Modules.UI (Rensei palette: dark panel, brass accents).
-- Every number is a PROPOSAL.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local CollectionService = game:GetService("CollectionService")
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

local PANEL, BRASS, INK = Color3.fromRGB(21, 26, 28), Color3.fromRGB(176, 138, 60), Color3.fromRGB(236, 226, 212)

local Fade = Instance.new("Frame")
Fade.Size, Fade.BackgroundColor3, Fade.BackgroundTransparency, Fade.ZIndex = UDim2.fromScale(1, 1), Color3.new(0, 0, 0), 1, 50
Fade.Parent = Gui
local function FadeTo(Alpha, Time)
	TweenService:Create(Fade, TweenInfo.new(Time), {BackgroundTransparency = Alpha}):Play()
end

-- a short notice under the top of the screen ("Board" / "Message")
local Notice = Instance.new("TextLabel")
Notice.Size, Notice.Position, Notice.AnchorPoint = UDim2.fromOffset(420, 36), UDim2.new(0.5, 0, 0, 90), Vector2.new(0.5, 0)
Notice.BackgroundColor3, Notice.BackgroundTransparency, Notice.TextColor3 = PANEL, 0.15, INK
Notice.Font, Notice.TextScaled, Notice.Visible, Notice.ZIndex = Enum.Font.Gotham, true, false, 40
Notice.Parent = Gui
Instance.new("UICorner", Notice).CornerRadius = UDim.new(0, 6)
local NoticeStroke = Instance.new("UIStroke", Notice)
NoticeStroke.Color, NoticeStroke.ApplyStrokeMode = BRASS, Enum.ApplyStrokeMode.Border
local NoticeToken
local function Say(Text, Seconds)
	local Token = {}
	NoticeToken = Token
	Notice.Text, Notice.Visible = Text, true
	task.delay(Seconds or 4, function() if NoticeToken == Token then Notice.Visible = false end end)
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

local Window
local function Label(Parent, Text, Size, Pos, Bold)
	local L = Instance.new("TextLabel")
	L.BackgroundTransparency, L.Text, L.TextColor3, L.Size, L.Position = 1, Text, INK, Size, Pos
	L.Font, L.TextScaled, L.TextXAlignment = Bold and Enum.Font.GothamBold or Enum.Font.Gotham, true, Enum.TextXAlignment.Left
	L.Parent = Parent
	return L
end
local function RegionName(Id)
	return Id and Places.Regions[Id] and Places.Regions[Id].Name or Id or "?"
end
local function OpenTickets()
	if Window then Window:Destroy() Window = nil end
	local Rows = Ask("Prices")
	if type(Rows) ~= "table" then return end
	Window = Instance.new("Frame")
	Window.Name = "Tickets"
	Window.Size, Window.Position, Window.AnchorPoint = UDim2.fromOffset(460, 80 + math.max(#Rows, 1) * 70), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5)
	Window.BackgroundColor3 = PANEL
	Window.Parent = Gui
	Instance.new("UICorner", Window).CornerRadius = UDim.new(0, 6)
	local Stroke = Instance.new("UIStroke", Window)
	Stroke.Color = BRASS
	Label(Window, "Tickets", UDim2.fromOffset(300, 30), UDim2.fromOffset(16, 10), true)
	local Status = Label(Window, #Rows == 0 and "No trains run from here yet." or "", UDim2.fromOffset(428, 20), UDim2.new(0, 16, 1, -28), false)
	-- who the ticket is for: you, or another player (the server only allows party members), sent by UserId
	local For = nil -- nil = me, else a Player
	local ForButton = Instance.new("TextButton")
	ForButton.Size, ForButton.Position = UDim2.fromOffset(170, 26), UDim2.new(1, -214, 0, 10)
	ForButton.BackgroundColor3, ForButton.TextColor3, ForButton.Font, ForButton.TextScaled = Color3.fromRGB(36, 44, 47), INK, Enum.Font.Gotham, true
	ForButton.Text = "For: me"
	ForButton.Parent = Window
	Instance.new("UICorner", ForButton).CornerRadius = UDim.new(0, 4)
	ForButton.Activated:Connect(function() -- cycles me -> each other player -> me
		local List = {}
		for _, Q in ipairs(Players:GetPlayers()) do
			if Q ~= Player then table.insert(List, Q) end
		end
		local Next = nil
		if not For then
			Next = List[1]
		else
			for I, Q in ipairs(List) do
				if Q == For then Next = List[I + 1] break end
			end
		end
		For = Next
		ForButton.Text = For and ("For: " .. For.DisplayName) or "For: me"
	end)
	for I, Row in ipairs(Rows) do
		local Y = 50 + (I - 1) * 70
		local Held = Row.Held and Travel.Classes[Row.Held] and ("  (holding " .. Travel.Classes[Row.Held].Name .. ")") or ""
		Label(Window, "To " .. RegionName(Row.To) .. Held, UDim2.fromOffset(428, 22), UDim2.fromOffset(16, Y), false)
		for J, C in ipairs(Travel.ClassOrder) do
			local B = Instance.new("TextButton")
			B.Size, B.Position = UDim2.fromOffset(136, 32), UDim2.fromOffset(16 + (J - 1) * 144, Y + 26)
			B.BackgroundColor3, B.TextColor3, B.Font, B.TextScaled = Color3.fromRGB(36, 44, 47), INK, Enum.Font.Gotham, true
			B.Text = ("%s  $%d"):format(Travel.Classes[C].Name, Row.Prices[C] or 0)
			B.Parent = Window
			Instance.new("UICorner", B).CornerRadius = UDim.new(0, 4)
			B.Activated:Connect(function()
				local Ok, Why = Ask("Buy", {Route = Row.Route, Class = C, For = For and For.Parent and For.UserId or nil})
				Status.Text = Ok and "Bought. Board when the doors open." or (Why or "Couldn't buy that.")
			end)
		end
	end
	local Close = Instance.new("TextButton")
	Close.Size, Close.Position, Close.Text = UDim2.fromOffset(28, 28), UDim2.new(1, -36, 0, 8), "X"
	Close.BackgroundColor3, Close.TextColor3 = Color3.fromRGB(36, 44, 47), INK
	Close.Parent = Window
	Close.Activated:Connect(function() if Window then Window:Destroy() Window = nil end end)
end

-- departure boards: parts tagged RenseiDepartureBoard (named DepartureBoard) get a SurfaceGui with the next train on
-- each line that runs from here (the server lists them in Remotes.Travel's "Lines" attribute)
local function Boards()
	while true do
		local Now = workspace:GetServerTimeNow()
		local Lines = {}
		for RouteId in string.gmatch(Remote:GetAttribute("Lines") or "", "[^,]+") do
			local D = Travel.NextDeparture(RouteId, Now)
			if D then
				local Left = math.max(0, math.floor(D - Now))
				table.insert(Lines, ("%-20s %d:%02d%s"):format(RegionName(Travel.Other(RouteId, Here)), Left // 60, Left % 60, Travel.BoardingOpen(RouteId, Now) and "  BOARDING" or ""))
			end
		end
		local Text = #Lines > 0 and table.concat(Lines, "\n") or "NO SERVICE"
		for _, B in ipairs(CollectionService:GetTagged("RenseiDepartureBoard")) do
			if B:IsA("BasePart") and B:IsDescendantOf(workspace) then
				local SG = B:FindFirstChild("Board")
				if not SG then
					SG = Instance.new("SurfaceGui")
					SG.Name, SG.Face, SG.SizingMode, SG.PixelsPerStud = "Board", Enum.NormalId.Front, Enum.SurfaceGuiSizingMode.PixelsPerStud, 40
					local T = Instance.new("TextLabel")
					T.Name, T.Size, T.BackgroundColor3, T.TextColor3, T.TextScaled, T.Font = "T", UDim2.fromScale(1, 1), PANEL, BRASS, true, Enum.Font.Code
					T.Parent = SG
					SG.Parent = B
				end
				SG.T.Text = "DEPARTURES\n" .. Text
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

local function TeleportScreen(Dest)
	local S = Instance.new("ScreenGui")
	S.IgnoreGuiInset = true
	local F = Instance.new("Frame")
	F.Size, F.BackgroundColor3 = UDim2.fromScale(1, 1), Color3.fromRGB(12, 14, 15)
	F.Parent = S
	local T = Instance.new("TextLabel")
	T.Size, T.Position, T.AnchorPoint = UDim2.fromScale(0.6, 0.1), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5)
	T.BackgroundTransparency, T.TextColor3, T.TextScaled, T.Font = 1, INK, true, Enum.Font.GothamBold
	T.Text = "Pulling into " .. (Dest or "the station") .. "..."
	T.Parent = F
	TeleportService:SetTeleportGui(S)
	FadeTo(0, 0.5)
end

-- ===== Road journeys (RoadService, World plan 1 Task 8) =====
-- Built only from the game's own UI art (owner rule 2026-10-21), cloned from the Uis templates:
--   * travel card    = the Party Invitation panel (HUD2.Party: Head, MainText, Buttons.Accept / Decline);
--   * journey screen = the menu backdrop (bg, with its vignettes), the area panel (HUD2.NewAreaDiscovered) and the
--                      boss bar (HUD.BossHealth) as the road: From on its left, the destination on its right, the
--                      party's progress as its fill (Modules.UI.Fill), the time left in the middle;
--   * teleport screen (TeleportGui) = the same backdrop and area panel.
-- "Set off" only asks: the server checks the road, the exit, the leader and the level, and rolls the ambush.
local Fill = require(ReplicatedStorage.Modules.UI.Fill)
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

local Card
local function CloseCard()
	if Card then Card:Destroy() Card = nil end
end
local function RoadCard(Data)
	CloseCard()
	if Window then Window:Destroy() Window = nil end
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
local function CloseJourney()
	if Journey then Journey:Destroy() Journey = nil end
	if RoadTeleportGui then -- the road's teleport screen goes with it (a later teleport sets its own)
		pcall(function() TeleportService:SetTeleportGui(nil) end)
		RoadTeleportGui:Destroy()
		RoadTeleportGui = nil
	end
end
local function AreaPanel(Dest, Line) -- HUD2.NewAreaDiscovered, relabelled
	local P = Template("HUD2.NewAreaDiscovered")
	if not P then return nil end
	P.AnchorPoint, P.Position = Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.22)
	SetText(P, "Header.Title", "ON THE ROAD")
	SetText(P, "Header.Head", Escape(Dest))
	SetText(P, "MainText", Line)
	return P
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
		Say(("All aboard. Departs in %d:%02d."):format(Left // 60, Left % 60), 4)
	elseif Kind == "RideStart" then
		if Window then Window:Destroy() Window = nil end
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
		if type(Data.Text) == "string" then Say(Data.Text, 5) end
	elseif Kind == "Message" then
		if type(Data.Text) == "string" then Say(Data.Text, 5) end
	end
end)

task.spawn(Boards)

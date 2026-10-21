-- TravelClient (World plan 1, 2026-10-20): ticket window, departure boards, the ride's scenery and fades, the
-- teleport screen. Server: StationService (Remotes.Travel / Remotes.TravelEvent). Style matches Modules.UI (Rensei
-- palette: dark panel, brass accents). Every number is a PROPOSAL.
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

Event.OnClientEvent:Connect(function(Kind, Data)
	Data = type(Data) == "table" and Data or {}
	if Kind == "OpenTickets" then
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

-- FieldNotesUI (2026-10-18): the one-time Field Notes (Rensei.FieldNotes). A small card at the right of the
-- screen, once per account, the first time a player meets a system the Tutorial doesn't teach: an inspect
-- point, their first clue, a puzzle mechanism, an unknown subject, a Forgotten Site, a boss, a Mastery
-- Point. Click it (or wait) to dismiss. Seen notes are saved through Requests.Hint (profile Flow.Hints).
-- Display only: nothing here grants or changes anything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local UIState = require(script.Parent.UIState)
local Notes = require(ReplicatedStorage.Modules.Data.Rensei.FieldNotes)

local Player = Players.LocalPlayer
local FieldNotesUI = {}

local GOLD = Color3.fromRGB(230, 205, 120)
local TEXT = Color3.fromRGB(225, 220, 210)
local PANEL = "rbxassetid://119335349346175" -- HUD.Server.main, the leaderboard card's panel
local FONT = Font.new("rbxasset://fonts/families/Guru.json")
local BOLD = Font.new("rbxasset://fonts/families/Guru.json", Enum.FontWeight.Bold)
local SHOW_FOR = 11 -- seconds before a note slides away by itself

local Seen = {} -- this session (plus the profile's Flow.Hints)
local Queue = {}
local Showing = false
local Card, Title, Body

local function Data() return UIState.Data end
local function SeenBefore(Id)
	local D = Data()
	return Seen[Id] or (D and D.Flow and D.Flow.Hints and D.Flow.Hints[Id]) == true
end

local function Fill(Text)
	local Keys = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and Notes.Keys.Touch or Notes.Keys.Keyboard
	return (Text:gsub("{(%w+)}", function(K)
		local V = Keys[K]
		return V and ('<font color="#E6CD78">%s</font>'):format(V) or K
	end))
end

local function Build()
	local Gui = Instance.new("ScreenGui")
	Gui.Name = "FieldNotes"
	Gui.ResetOnSpawn = false
	Gui.DisplayOrder = 5
	Gui.Parent = Player:WaitForChild("PlayerGui")
	Card = Instance.new("ImageButton")
	Card.Name = "Card"
	Card.AutoButtonColor = false
	Card.BackgroundTransparency = 1
	Card.Image = PANEL
	Card.ScaleType = Enum.ScaleType.Stretch
	Card.AnchorPoint = Vector2.new(1, 0)
	Card.Size = UDim2.fromOffset(320, 112)
	Card.Position = UDim2.new(1, 360, 0.16, 0) -- off screen until shown
	Card.Visible = false
	Card.Parent = Gui
	local Scale = Instance.new("UIScale")
	Scale.Parent = Card
	local function Fit()
		local W = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.X or 1280
		Scale.Scale = math.clamp(W / 1500, 0.75, 1.15)
	end
	Fit()
	if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(Fit) end
	local Tag = Instance.new("TextLabel")
	Tag.Name = "Tag"
	Tag.BackgroundTransparency = 1
	Tag.FontFace = FONT
	Tag.TextColor3 = Color3.fromRGB(160, 150, 130)
	Tag.TextSize = 12
	Tag.TextXAlignment = Enum.TextXAlignment.Left
	Tag.Text = "FIELD NOTES"
	Tag.Position = UDim2.fromOffset(18, 10)
	Tag.Size = UDim2.new(1, -36, 0, 14)
	Tag.Parent = Card
	Title = Instance.new("TextLabel")
	Title.Name = "Title"
	Title.BackgroundTransparency = 1
	Title.FontFace = BOLD
	Title.TextColor3 = GOLD
	Title.TextSize = 19
	Title.TextXAlignment = Enum.TextXAlignment.Left
	Title.Position = UDim2.fromOffset(18, 24)
	Title.Size = UDim2.new(1, -36, 0, 22)
	Title.Parent = Card
	Body = Instance.new("TextLabel")
	Body.Name = "Body"
	Body.BackgroundTransparency = 1
	Body.FontFace = FONT
	Body.TextColor3 = TEXT
	Body.TextSize = 14
	Body.RichText = true
	Body.TextWrapped = true
	Body.TextXAlignment = Enum.TextXAlignment.Left
	Body.TextYAlignment = Enum.TextYAlignment.Top
	Body.Position = UDim2.fromOffset(18, 48)
	Body.Size = UDim2.new(1, -36, 1, -56)
	Body.Parent = Card
end

local function Hide()
	if not Showing then return end
	local Token = Showing
	TweenService:Create(Card, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(1, 360, 0.16, 0)}):Play()
	task.delay(0.32, function()
		if Showing ~= Token then return end
		Card.Visible = false
		Showing = false
		if #Queue > 0 then FieldNotesUI.Show(table.remove(Queue, 1)) end
	end)
end

-- show a note once (queued behind the one on screen)
function FieldNotesUI.Show(Id)
	local Def = Notes.List[Id]
	if not Def or not Card then return end
	if Showing then
		if not table.find(Queue, Id) then table.insert(Queue, Id) end
		return
	end
	if SeenBefore(Id) then return end
	Seen[Id] = true
	UIState.Request("Hint", "Seen", Id)
	local Token = {}
	Showing = Token
	Title.Text = Def.Title
	Body.Text = Fill(Def.Text)
	Card.Visible = true
	Card.Position = UDim2.new(1, 360, 0.16, 0)
	TweenService:Create(Card, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(1, -16, 0.16, 0)}):Play()
	task.delay(SHOW_FOR, function() if Showing == Token then Hide() end end)
end

local function Want(Id) if not SeenBefore(Id) then FieldNotesUI.Show(Id) end end

local function Count(T) local N = 0 for _ in pairs(T or {}) do N += 1 end return N end

function FieldNotesUI.Start()
	Build()
	Card.Activated:Connect(Hide)

	-- prompts: an inspect point, a puzzle mechanism
	ProximityPromptService.PromptShown:Connect(function(Prompt)
		if Prompt.Name == "InspectPrompt" then Want("Inspect")
		elseif Prompt.Name == "MechanismPrompt" then Want("Mechanism") end
	end)

	-- the profile: a first clue, a first identity record, a Mastery Point (counted from the first sync,
	-- so a returning player isn't told about clues they already hold)
	local Base = nil
	UIState.Changed:Connect(function()
		local D = Data()
		if not D or not D.Story then return end
		if D.Mastery and (D.Mastery.Unspent or 0) > 0 then Want("Mastery") end
		local Ev = Count(D.Story.Evidence)
		local Ids = Count(((D.Identities or {}).Records))
		if not Base then Base = {Ev = Ev, Ids = Ids} return end
		if Ev > Base.Ev then Want("Journal") end
		if Ids > Base.Ids then Want("Identities") end
		Base.Ev, Base.Ids = math.max(Base.Ev, Ev), math.max(Base.Ids, Ids)
	end)

	-- a boss bar (HUDUI publishes where it ends while one is up)
	Player:GetAttributeChangedSignal("BossBarBottom"):Connect(function()
		if Player:GetAttribute("BossBarBottom") then Want("Boss") end
	end)

	-- inside a Forgotten Site (an area part tagged RenseiArea with the ForgottenSite attribute)
	task.spawn(function()
		while true do
			task.wait(1)
			local Root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
			if Root and not SeenBefore("Site") then
				for _, A in ipairs(CollectionService:GetTagged("RenseiArea")) do
					if A:IsA("BasePart") and A:GetAttribute("ForgottenSite") then
						local P = A.CFrame:PointToObjectSpace(Root.Position)
						if math.abs(P.X) <= A.Size.X / 2 and math.abs(P.Y) <= A.Size.Y / 2 and math.abs(P.Z) <= A.Size.Z / 2 then
							Want("Site")
							break
						end
					end
				end
			end
		end
	end)
end

return FieldNotesUI

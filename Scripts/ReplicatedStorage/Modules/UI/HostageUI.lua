-- HostageUI (hostages plan Task 12, 2026-10-28; spec Documents/specs/2026-10-21-hostage-design.md sections 3, 4 and 8;
-- pre-flight P7, P19, P26, P28): the hostage HUD and the hostage's and the captor's keys. Display and input only:
-- HostageService (server) decides everything (Requests.Hostage), and every toast comes from it through UIService.Notify.
-- Owner rule: ONLY existing UI assets -- the bars are clones of HUD.BossHealth, the plate a clone of
-- Templates.NpcTemplate, the captor menu the emote wheel's own drawing code (EmoteWheelUI.Menu); no new image or id.
--   * HIDDEN WHILE HOSTAGES ARE OFF: nothing shows and no key is bound unless TakedownUI.HostagesOn() (Rensei.Hostage
--     .Enabled, or the Studio TestNoSave test bypass, as HostageService.Allowed() decides it on the server).
--   * UIState.On("Hostage", fn) keeps the server's last payload as HostageUI.Now = {State, Role, Captor, Hostage, Until,
--     Ends, Struggle, Options}. Role is derived (P28): "Captor" when Captor is the local player's name, "Hostage" when
--     Hostage is, else the payload's own Role.
--   * THE BARS, while the local character is Holding or HeldBy and the payload is Held or Grabbing: one clone of
--     HUD.BossHealth named HostageTime (Head "Holding" for the captor, "Held" for the hostage; Text the other side's
--     name; HP the seconds left; Fill.Set(Bar, left / total) -- Until while Held, the grab's Ends while Grabbing; total
--     is the time left when that end was first seen). For the hostage, a second clone HostageStruggle (Head "Struggle",
--     Text the struggle key; Fill.Set(Bar, the character's Struggle attribute)). Both are centred as the boss bar is and
--     stacked (one bar height + GAP apart) from just under the lower of the boss bar -- while it shows, HUDUI's
--     BossBarBottom -- and the toast banner (HUD2.Notification), so neither covers them. Each bar's Fill attribute is
--     the ratio it was last given (the client checks read it). The clones come from StarterGui's untouched Uis.
--   * THE PLATE, for the hostage: a clone of Templates.NpcTemplate named HostagePlate reading "Held by <name>" (the
--     captor's display name). (fix round 1, review M1) It is the stack's first row, above the bars (so it is never over
--     the player's own head), sized from the boss bar (PLATE_W x PLATE_H of it); its name is one line (Head centred,
--     scaled, never wrapped) and its own bar is hidden (a full red bar read as a health bar). The clone's aspect
--     constraint and its Text label go; no art is added.
--   * THE CAPTOR'S KEY (P7): while Holding, a ContextActionService bind on the takedown key (TakedownUI.Key(),
--     Settings > Keybinds > Takedown, N by default; rebinds follow Keybinds.Changed) at High priority toggles the captor
--     menu. (fix round 1, review M7) The same bind also takes the gamepad button the takedown/hostage prompt itself
--     answers to (TakedownUI's prompt leaves ProximityPrompt.GamepadKeyCode at its default, which TakedownUI.Offered
--     relies on for an unbound key; GAMEPAD_KEY reads that default, no new choice), and the touch HOSTAGE button runs
--     the same toggle, so a captor whose takedown key is unbound can still open it on a gamepad or a touch screen (a
--     keyboard-only player with the key unbound gets no hostage prompt either, as for takedowns). The menu: EmoteWheelUI.Menu("Hostage", Options, ...) with the Options of the last Notify (they come with each one; none
--     while Grabbing: nothing opens). It works in Combat Mode (the wheel's menu mode never closes for it, and never asks
--     Emotes.Blocked). Picking Ransom opens a second wheel of its Tiers ("$" .. amount) and sends
--     Request("Hostage", "Menu", "Ransom", index); any other pick sends Request("Hostage", "Menu", Id). Only the Id and
--     a tier index ever go to the server (which range-checks the tier). A Free notify closes a menu of ours.
--   * THE HOSTAGE'S STRUGGLE: while HeldBy, a ContextActionService bind on Keybinds.Get("Block") (F by default) at High
--     priority (so the held player's F never reaches Block) counts presses. (fix round 1, review M8) When the bind is
--     made, a block the player was holding is let go (ClientActions "Block" false: ClientHandler's own release), since
--     the bind will swallow that key's release. They are flushed at most
--     Hostage.SendsPerSecond times a second (each send at least 1 / SendsPerSecond after the last) as
--     Request("Hostage", "Struggle", n), n at most Hostage.MaxPressesPerSend (P26; presses beyond it before a send are
--     dropped). The server stays authoritative (its own MaxPressesPerSecond, stamina, gain).
--   * TOUCH: MobileControls' HOSTAGE button runs ClientActions "Hostage" (the menu toggled, as the key) and STRUGGLE runs
--     "Struggle" (one press).
--   * HostageUI._Sent: Struggle messages sent since Start (the client checks read it).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

local UIState = require(script.Parent.UIState)
local Fill = require(script.Parent.Fill)
local EmoteWheelUI = require(script.Parent.EmoteWheelUI)
local TakedownUI = require(script.Parent.TakedownUI)
local Keybinds = require(ReplicatedStorage.Modules.Managers.Keybinds)
local ClientActions = require(ReplicatedStorage.Modules.Managers.ClientActions)
local Hostage = require(ReplicatedStorage.Modules.Data.Rensei.Hostage)

local Player = Players.LocalPlayer

local HostageUI = {}
HostageUI.Now = {State = "Free"}
HostageUI._Sent = 0

-- the texts this HUD draws (PROPOSAL, fix round 1 M4: invented here, not the spec's, except "Held by <name>", spec 8)
local MENU_TITLE, TIERS_TITLE = "Hostage", "Ransom"
local TEXT = {Holding = "Holding", Held = "Held", Struggle = "Struggle", Press = "Press %s", Seconds = "%d s",
	Percent = "%d%%", HeldBy = "Held by %s", Tier = "$%s"}
local GAP = 6 -- pixels between the stacked rows (PROPOSAL; CombatLogUI's gap under the boss bar)
-- (fix round 1, M1) the held-by plate's size as shares of the boss bar's width and height (PROPOSAL)
local PLATE_W, PLATE_H = 0.6, 0.42
local MENU_ACTION, STRUGGLE_ACTION = "RenseiHostageMenu", "RenseiHostageStruggle"
-- (fix round 1, M7) the gamepad button a ProximityPrompt answers to by default (TakedownUI's prompt keeps it)
local GAMEPAD_KEY = Instance.new("ProximityPrompt").GamepadKeyCode

local TimeBar, StruggleBar, Plate
local Total, TotalFor = nil, nil -- the bar's full length in seconds, and the end time it was measured for
local Pending, LastSend, FlushQueued = 0, -math.huge, false
local MenuKey, StruggleKey = nil, nil -- the keys bound now (nil: unbound)

local function Character() return Player.Character end

local function RoleOf(P)
	if P.Captor ~= nil and P.Captor == Player.Name then return "Captor" end
	if P.Hostage ~= nil and P.Hostage == Player.Name then return "Hostage" end
	return P.Role
end

-- a character name's display name: the Player's, else a rig's DisplayName attribute in World.Live, else the name
local function DisplayOf(Name)
	if type(Name) ~= "string" then return "" end
	local P = Players:FindFirstChild(Name)
	if P and P:IsA("Player") then return P.DisplayName end
	local Live = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Live")
	local M = Live and Live:FindFirstChild(Name)
	return M and tostring(M:GetAttribute("DisplayName") or Name) or Name
end

local function SetText(Parent, Child, Text)
	local L = Parent:FindFirstChild(Child)
	if L and L:IsA("TextLabel") then L.Text = Text end
end

local function MenuOurs()
	local M = EmoteWheelUI.MenuOpen()
	return M ~= nil and (M.Title == MENU_TITLE or M.Title == TIERS_TITLE)
end

-- ===== the captor menu =====
local function OptionOf(Id)
	for _, O in ipairs(HostageUI.Now.Options or {}) do
		if O.Id == Id then return O end
	end
	return nil
end

local function OnPick(Id)
	if Id == nil then return end
	local C = Character()
	if not (C and C:GetAttribute("Holding")) then return end
	local O = OptionOf(Id)
	if not O or O.Locked then return end
	if Id == "Ransom" then
		local Items = {}
		for I, Amount in ipairs(type(O.Tiers) == "table" and O.Tiers or {}) do
			table.insert(Items, {Id = I, Text = TEXT.Tier:format(tostring(Amount))})
		end
		if #Items == 0 then return end
		EmoteWheelUI.Menu(TIERS_TITLE, Items, function(Index)
			if type(Index) == "number" then UIState.Request("Hostage", "Menu", "Ransom", Index) end
		end)
		return
	end
	UIState.Request("Hostage", "Menu", Id)
end

function HostageUI.OpenMenu()
	local C = Character()
	if not (TakedownUI.HostagesOn() and C and C:GetAttribute("Holding")) then return false end
	local Options = HostageUI.Now.Options
	if HostageUI.Now.State ~= "Held" or type(Options) ~= "table" or #Options == 0 then return false end
	return EmoteWheelUI.Menu(MENU_TITLE, Options, OnPick)
end

function HostageUI.ToggleMenu()
	if MenuOurs() then EmoteWheelUI.CloseMenu() return end
	HostageUI.OpenMenu()
end

-- ===== the struggle =====
local function Flush()
	FlushQueued = false
	if Pending <= 0 then return end
	local C = Character()
	if not (C and C:GetAttribute("HeldBy")) then Pending = 0 return end
	local Interval = 1 / Hostage.SendsPerSecond
	local Wait = LastSend + Interval - os.clock()
	if Wait > 0 then
		FlushQueued = true
		task.delay(Wait, Flush)
		return
	end
	local N = Pending
	Pending, LastSend = 0, os.clock()
	HostageUI._Sent += 1
	UIState.Request("Hostage", "Struggle", N)
end

function HostageUI.Press()
	local C = Character()
	if not (TakedownUI.HostagesOn() and C and C:GetAttribute("HeldBy")) then return end
	Pending = math.min(Pending + 1, Hostage.MaxPressesPerSend)
	if not FlushQueued then Flush() end
end

-- ===== the keys (bound only while they mean something) =====
-- Keys: the KeyCodes to bind (Unknown ones skipped); MenuKey / StruggleKey keep the bound set's signature
local function Bind(Want, Keys, Action, Fn)
	local List, Names = {}, {}
	if Want then
		for _, K in ipairs(Keys) do
			if K ~= Enum.KeyCode.Unknown and not table.find(List, K) then
				table.insert(List, K)
				table.insert(Names, K.Name)
			end
		end
	end
	local Now = #List > 0 and table.concat(Names, ",") or nil
	local Was = Action == MENU_ACTION and MenuKey or StruggleKey
	if Now == Was then return false end
	if Was then ContextActionService:UnbindAction(Action) end
	if Now then
		ContextActionService:BindActionAtPriority(Action, function(_, State)
			if State == Enum.UserInputState.Begin then Fn() end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value, table.unpack(List))
	end
	if Action == MENU_ACTION then MenuKey = Now else StruggleKey = Now end
	return Now ~= nil
end

-- ===== the bars and the plate =====
-- the art to clone: StarterGui's untouched copy of Uis (Fill.Set wraps a bar's image in a clip the first time it fills
-- it, so the live boss bar may already be wrapped -- a clone of that would be wrapped twice), else the live one
local function Art(Path)
	local Src = game:GetService("StarterGui"):FindFirstChild("Uis")
	for _, Root in ipairs({Src, UIState.Gui}) do
		local X = Root
		for _, Name in ipairs(Path) do X = X and X:FindFirstChild(Name) end
		if X then return X end
	end
	return nil
end

local function Build()
	local HUD = UIState.Gui:FindFirstChild("HUD")
	local Boss = HUD and Art({"HUD", "BossHealth"})
	if Boss then
		TimeBar = Boss:Clone()
		TimeBar.Name = "HostageTime"
		TimeBar.Visible = false
		TimeBar.Parent = HUD
		StruggleBar = Boss:Clone()
		StruggleBar.Name = "HostageStruggle"
		StruggleBar.Visible = false
		StruggleBar.Parent = HUD
	else
		warn("[HostageUI] no HUD.BossHealth to clone: the hostage bars won't show")
	end
	local Npc = Art({"Templates", "NpcTemplate"})
	if Npc and HUD then
		Plate = Npc:Clone()
		Plate.Name = "HostagePlate"
		Plate.Visible = false
		-- (fix round 1, M1) one readable line: no aspect lock (sized from the boss bar instead), no bar, no level text
		for _, X in ipairs(Plate:GetChildren()) do
			if X:IsA("UIAspectRatioConstraint") then X:Destroy() end
		end
		if Plate:FindFirstChild("Bar") then Plate.Bar.Visible = false end
		if Plate:FindFirstChild("Text") then Plate.Text.Visible = false end
		local Head = Plate:FindFirstChild("Head")
		if Head and Head:IsA("TextLabel") then
			Head.AnchorPoint, Head.Position, Head.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.94, 0.8)
			Head.TextScaled, Head.TextWrapped, Head.TextXAlignment = true, false, Enum.TextXAlignment.Center
		end
		Plate.Parent = HUD
	else
		warn("[HostageUI] no Templates.NpcTemplate to clone: the held-by plate won't show")
	end
end

-- the bars' and the plate's places: centred where the boss bar is, stacked from just under the lowest of the boss bar
-- (while it shows: HUDUI's BossBarBottom) and the toast banner (HUD2.Notification, PopupUI's), so neither covers them
local function Place(ShowStruggle)
	local Gui = UIState.Gui
	local HUD = Gui.HUD
	local Boss = HUD.BossHealth
	local Top = 0
	if Player:GetAttribute("BossBarBottom") and Boss.Visible then Top = Boss.AbsolutePosition.Y + Boss.AbsoluteSize.Y end
	local Banner = Gui:FindFirstChild("HUD2") and Gui.HUD2:FindFirstChild("Notification")
	if Banner and Banner:IsA("GuiObject") then Top = math.max(Top, Banner.AbsolutePosition.Y + Banner.AbsoluteSize.Y) end
	local Y = Top + GAP - HUD.AbsolutePosition.Y
	-- (fix round 1, M1) the hostage's plate first, above the bars
	if Plate and ShowStruggle then
		local H = math.floor(Boss.AbsoluteSize.Y * PLATE_H + 0.5)
		Plate.AnchorPoint = Vector2.new(Boss.AnchorPoint.X, 0)
		Plate.Size = UDim2.fromOffset(math.floor(Boss.AbsoluteSize.X * PLATE_W + 0.5), H)
		Plate.Position = UDim2.new(Boss.Position.X.Scale, Boss.Position.X.Offset, 0, Y)
		Y += H + GAP
	end
	for _, B in ipairs({TimeBar, ShowStruggle and StruggleBar or nil}) do
		B.AnchorPoint, B.Size = Vector2.new(Boss.AnchorPoint.X, 0), Boss.Size
		B.Position = UDim2.new(Boss.Position.X.Scale, Boss.Position.X.Offset, 0, Y)
		Y += Boss.AbsoluteSize.Y + GAP
	end
end

local function Hide()
	for _, X in ipairs({TimeBar, StruggleBar, Plate}) do
		if X then X.Visible = false end
	end
end

local function Draw()
	local C = Character()
	local On = TakedownUI.HostagesOn() and C ~= nil
	local Holding = On and C:GetAttribute("Holding") ~= nil
	local Held = On and C:GetAttribute("HeldBy") ~= nil
	Bind(Holding, {TakedownUI.Key(), GAMEPAD_KEY}, MENU_ACTION, HostageUI.ToggleMenu)
	if Bind(Held, {Keybinds.Get("Block")}, STRUGGLE_ACTION, HostageUI.Press) and ClientActions.Has("Block") then
		-- (fix round 1, M8) a block held as the hold began is let go: the bind swallows that key's release
		ClientActions.Run("Block", false)
	end
	if not Holding and MenuOurs() then EmoteWheelUI.CloseMenu() end
	local N = HostageUI.Now
	local Live = (N.State == "Held" or N.State == "Grabbing") and (Holding or Held)
	if not (Live and TimeBar) then Hide() return end
	local Ends = tonumber(N.State == "Held" and (C:GetAttribute("HostageUntil") or N.Until) or N.Ends)
	local Left = Ends and math.max(0, Ends - workspace:GetServerTimeNow()) or 0
	if Ends ~= TotalFor then Total, TotalFor = math.max(Left, 1e-3), Ends end
	Place(Held)
	TimeBar.Visible = true
	SetText(TimeBar, "Head", Holding and TEXT.Holding or TEXT.Held)
	SetText(TimeBar, "Text", DisplayOf(Holding and C:GetAttribute("Holding") or C:GetAttribute("HeldBy")))
	SetText(TimeBar, "HP", TEXT.Seconds:format(math.ceil(Left)))
	local Ratio = math.clamp(Left / Total, 0, 1)
	if TimeBar:FindFirstChild("Bar") then Fill.Set(TimeBar.Bar, Ratio) end
	TimeBar:SetAttribute("Fill", Ratio) -- (what Fill.Set was given: the client checks read it)
	StruggleBar.Visible = Held
	if Plate then Plate.Visible = Held end
	if Held then
		local Bar = math.clamp(tonumber(C:GetAttribute("Struggle")) or 0, 0, 1)
		SetText(StruggleBar, "Head", TEXT.Struggle)
		SetText(StruggleBar, "Text", TEXT.Press:format(tostring(Keybinds.Keys.Block)))
		SetText(StruggleBar, "HP", TEXT.Percent:format(math.floor(Bar * 100 + 0.5)))
		if StruggleBar:FindFirstChild("Bar") then Fill.Set(StruggleBar.Bar, Bar) end
		StruggleBar:SetAttribute("Fill", Bar)
		if Plate then
			SetText(Plate, "Head", TEXT.HeldBy:format(DisplayOf(C:GetAttribute("HeldBy"))))
		end
	end
end

function HostageUI.Start()
	Build()
	UIState.On("Hostage", function(P)
		if type(P) ~= "table" then return end
		local Now = {State = P.State, Role = RoleOf(P), Captor = P.Captor, Hostage = P.Hostage, Until = P.Until, Ends = P.Ends,
			Struggle = P.Struggle, Options = type(P.Options) == "table" and P.Options or {}, Outcome = P.Outcome}
		HostageUI.Now = Now
		if Now.State ~= "Held" or Now.Role ~= "Captor" then
			if MenuOurs() then EmoteWheelUI.CloseMenu() end
		else
			-- the captor's options changed while the menu of options is open: drawn again
			local M = EmoteWheelUI.MenuOpen()
			if M and M.Title == MENU_TITLE then HostageUI.OpenMenu() end
		end
	end)
	ClientActions.Register("Hostage", function(Began) if Began then HostageUI.ToggleMenu() end end)
	ClientActions.Register("Struggle", function(Began) if Began then HostageUI.Press() end end)
	Keybinds.Changed:Connect(function(Name)
		-- a rebind: the bound key let go, so the next frame binds the new one
		if Name == "Takedown" and MenuKey then ContextActionService:UnbindAction(MENU_ACTION) MenuKey = nil end
		if Name == "Block" and StruggleKey then ContextActionService:UnbindAction(STRUGGLE_ACTION) StruggleKey = nil end
	end)
	RunService.RenderStepped:Connect(function()
		local Ok, Err = pcall(Draw)
		if not Ok then
			pcall(Hide)
			if not HostageUI._Warned then HostageUI._Warned = true warn("[HostageUI] " .. tostring(Err)) end
		end
	end)
end

return HostageUI

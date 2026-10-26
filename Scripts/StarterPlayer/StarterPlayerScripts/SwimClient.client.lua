-- SwimClient: swimming on your own character (owner decision 6, 2026-10-18; swimming revamp 2026-10-26). The server
-- owns the swim STATE (SwimService -> character attribute Traversal = "Swim"); Roblox's Swimming humanoid state also
-- counts, so swimming starts the moment you're in the water. Everything here replicates (your client owns your
-- character).
-- SWIMMING REVAMP (2026-10-26; Documents/specs/2026-10-25-swimming-revamp-design.md, all PROPOSAL): the movement is
-- Modules.Managers.SwimController (level at the surface, camera-relative in 3D after a dive). This script starts and
-- stops it and feeds it the keys:
--   * Ctrl: pressed at the surface = dive (where the water is deep enough); held underwater = sink.
--   * Space: at the surface = climb out onto a low ledge in front of you, else the old swim hop; held underwater = rise.
--   * Shift: sprint (asks the server, Requests.Swim; the controller swims x SprintMult while the server's SwimSprint
--     attribute is on; stamina is the server's). WalkSpeed is no longer changed for it.
--   * the loop animation: Swim_Sprint / Swim_Forward / Swim_Idle, at the surface and underwater (the owner: the
--     underwater idle is Swim_Idle). The dive and surfacing one-shots and the climb-out are the controller's.
--   * the air meter (owner rule: existing UI assets only): a run-time clone of the HUD's own Meter bar
--     (StarterGui.Uis.HUD.Stats.BlueBar, cyan) named AirBar, in the HUD's Stats list under the vitals, filled through
--     Modules.UI.Fill. It shows while you're under water (attribute Submerged) or short of air (Breath), labelled
--     "AIR" (a clone of the HUD's own CashFrame.Display text, as HUDUI's hover values), "DROWNING" and blinking at 0.
--     The old code-built SwimHUD bar is gone. Nothing in StarterGui is edited.
--   * touch: MobileControls' SPRINT / RISE / DIVE buttons (shown only while swimming) run the actions "SwimSprint",
--     "SwimRise" and "SwimDive" registered here: held = the same as holding Shift / Space / Ctrl.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UserInputService = game:GetService("UserInputService")

local AnimationManager = require(ReplicatedStorage.Modules.Managers.AnimationManager)
local ClientActions = require(ReplicatedStorage.Modules.Managers.ClientActions)
local ResourceManager = require(ReplicatedStorage.Modules.Managers.ResourceManager)
local SwimController = require(ReplicatedStorage.Modules.Managers.SwimController)
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig).Swim
local Remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RequestRemote")

local Player = Players.LocalPlayer

-- touch buttons (MobileControls): held state
local TouchSprint, TouchRise, TouchDive = false, false, false
local function Typing() return UserInputService:GetFocusedTextBox() ~= nil end

-- a press: dive at the surface (Ctrl / DIVE); climb out, else hop, at the surface (Space / RISE)
local function DivePressed()
	if SwimController.Mode == "Surface" then SwimController.Dive() end
end
local function RisePressed()
	if SwimController.Mode == "Surface" and not SwimController.ClimbOut() then SwimController.Hop() end
end
ClientActions.Register("SwimSprint", function(Began) TouchSprint = Began == true end)
ClientActions.Register("SwimRise", function(Began)
	TouchRise = Began == true
	if Began then RisePressed() end
end)
ClientActions.Register("SwimDive", function(Began)
	TouchDive = Began == true
	if Began then DivePressed() end
end)
UserInputService.InputBegan:Connect(function(Input)
	if Typing() or not SwimController.Mode then return end
	if Input.KeyCode == Enum.KeyCode.LeftControl then DivePressed()
	elseif Input.KeyCode == Enum.KeyCode.Space then RisePressed() end
end)

-- ===== the air meter: a clone of the HUD's own Meter bar (made on first need, again if the HUD was rebuilt) =====
local Fill = require(ReplicatedStorage.Modules.UI.Fill)
local AirBar, AirLabel = nil, nil
local function Air()
	if AirBar and AirBar.Parent then return AirBar end
	local Uis = Player:FindFirstChild("PlayerGui") and Player.PlayerGui:FindFirstChild("Uis")
	local HUD = Uis and Uis:FindFirstChild("HUD")
	local Stats = HUD and HUD:FindFirstChild("Stats")
	local SUis = game:GetService("StarterGui"):FindFirstChild("Uis")
	local Src = SUis and SUis:FindFirstChild("HUD") and SUis.HUD:FindFirstChild("Stats") and SUis.HUD.Stats:FindFirstChild("BlueBar")
	if not (Stats and Src) then return nil end
	AirBar = Src:Clone() -- the pristine bar (the HUD's live one is already wrapped by Fill)
	AirBar.Name = "AirBar"
	local Last = 0
	for _, C in ipairs(Stats:GetChildren()) do
		if C:IsA("GuiObject") then Last = math.max(Last, C.LayoutOrder) end
	end
	AirBar.LayoutOrder = Last + 1 -- the next slot in the Stats list, under the vitals
	AirBar.Visible = false
	local Display = HUD:FindFirstChild("CashFrame") and HUD.CashFrame:FindFirstChild("Display")
	if Display then
		AirLabel = Display:Clone()
		for _, K in ipairs(AirLabel:GetChildren()) do if not K:IsA("UIStroke") then K:Destroy() end end
		AirLabel.Name = "AirLabel"
		AirLabel.BackgroundTransparency = 1
		AirLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		AirLabel.Position = UDim2.fromScale(0.5, 0.5)
		AirLabel.Size = UDim2.fromScale(0.6, 1.6)
		AirLabel.TextColor3 = Color3.new(1, 1, 1)
		AirLabel.ZIndex = AirBar.ZIndex + 5
		AirLabel.Text = "AIR"
		AirLabel.Parent = AirBar
	end
	AirBar.Parent = Stats
	return AirBar
end

local function Hook(Character)
	local Humanoid = Character:WaitForChild("Humanoid", 10)
	if not Humanoid then return end
	local Playing = nil
	local function Set(Name)
		if Playing == Name then return end
		if Playing then AnimationManager.Stop(Character, Playing) end
		Playing = nil
		if Name and AnimationManager.Has(Character, Name) then
			AnimationManager.Play(Character, Name, {Looped = true, Priority = Enum.AnimationPriority.Movement})
			Playing = Name
		end
	end
	local Asked = false -- the sprint request we last sent
	local function Ask(On)
		if Asked == On then return end
		Asked = On
		Remote:FireServer("Swim", On)
	end
	local Conn
	Conn = RunService.Heartbeat:Connect(function()
		if not Character.Parent then
			Conn:Disconnect()
			SwimController.Stop()
			return
		end
		local ServerSwim = Character:GetAttribute("Traversal") == "Swim"
		local Swimming = Humanoid.Health > 0 and (ServerSwim or Humanoid:GetState() == Enum.HumanoidStateType.Swimming)
		if Swimming then SwimController.Start(Character) elseif SwimController.Mode then SwimController.Stop() end
		local Moving = Humanoid.MoveDirection.Magnitude > Tuning.MoveThreshold
		-- sprint: Shift held while swimming and moving (and not typing)
		local WantSprint = ServerSwim and Moving and not Typing()
			and (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) or TouchSprint)
		if WantSprint and not Asked and ResourceManager.Get(Character, "Stamina") < Tuning.SprintMinStamina then WantSprint = false end
		Ask(WantSprint == true)
		local Sprinting = WantSprint and Character:GetAttribute("SwimSprint") == true
		if not Swimming then TouchSprint, TouchRise, TouchDive = false, false, false end
		-- underwater: Space / RISE rises, Ctrl / DIVE sinks
		local Under = SwimController.Mode == "Under"
		SwimController.Input.Up = Under and ((UserInputService:IsKeyDown(Enum.KeyCode.Space) and not Typing()) or TouchRise)
		SwimController.Input.Down = Under and ((UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and not Typing()) or TouchDive)
		SwimController.Input.Sprint = Sprinting == true
		if Swimming then
			Set(Sprinting and AnimationManager.Has(Character, Tuning.AnimSprint) and Tuning.AnimSprint
				or Moving and Tuning.AnimMove or (Under and Tuning.AnimUnderIdle) or Tuning.AnimIdle)
		else
			Set(nil)
		end
		-- the air meter
		local Breath = Character:GetAttribute("Breath")
		local Show = (Breath ~= nil or Character:GetAttribute("Submerged") == true) and Humanoid.Health > 0
		local Bar = (Show or (AirBar and AirBar.Parent)) and Air()
		if Bar then
			Bar.Visible = Show
			if Show then
				local Drowning = Character:GetAttribute("Drowning") == true
				local Inner = Bar:FindFirstChild("Bar")
				if Inner then Fill.Set(Inner, (Breath or Tuning.BreathMax) / Tuning.BreathMax) end
				-- drowning: the bar blinks (its own transparency, every 0.25 s)
				Bar.ImageTransparency = (Drowning and math.floor(os.clock() / 0.25) % 2 == 1) and 0.7 or 0
				if AirLabel then AirLabel.Text = Drowning and "DROWNING" or "AIR" end
			end
		end
	end)
end

if Player.Character then task.spawn(Hook, Player.Character) end
Player.CharacterAdded:Connect(Hook)

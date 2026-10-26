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
--   * the breath bar: a thin bar under the centre of the screen while you're short of air (attribute Breath), red
--     while drowning (Task 6 replaces it with the HUD's own bar).
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

-- ===== breath bar (minimal: a thin gold bar, red while drowning) =====
local Gui = Instance.new("ScreenGui")
Gui.Name = "SwimHUD"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.Parent = Player:WaitForChild("PlayerGui")
local Bar = Instance.new("Frame")
Bar.Name = "Breath"
Bar.AnchorPoint = Vector2.new(0.5, 0)
Bar.Position = UDim2.fromScale(0.5, 0.62)
Bar.Size = UDim2.fromOffset(170, 4)
Bar.BackgroundColor3 = Color3.fromRGB(20, 18, 16)
Bar.BackgroundTransparency = 0.35
Bar.BorderSizePixel = 0
Bar.Visible = false
Bar.Parent = Gui
local Fill = Instance.new("Frame")
Fill.Name = "Fill"
Fill.Size = UDim2.fromScale(1, 1)
Fill.BackgroundColor3 = Color3.fromRGB(230, 205, 120)
Fill.BorderSizePixel = 0
Fill.Parent = Bar
local Label = Instance.new("TextLabel")
Label.Name = "Label"
Label.BackgroundTransparency = 1
Label.AnchorPoint = Vector2.new(0.5, 1)
Label.Position = UDim2.new(0.5, 0, 0, -3)
Label.Size = UDim2.fromOffset(170, 14)
Label.Font = Enum.Font.Garamond
Label.TextSize = 13
Label.TextColor3 = Color3.fromRGB(225, 220, 210)
Label.TextStrokeTransparency = 0.6
Label.Text = "BREATH"
Label.Parent = Bar

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
		-- breath bar
		local Breath = Character:GetAttribute("Breath")
		Bar.Visible = Breath ~= nil and Humanoid.Health > 0
		if Breath then
			Fill.Size = UDim2.fromScale(math.clamp(Breath / Tuning.BreathMax, 0, 1), 1)
			local Drowning = Character:GetAttribute("Drowning") == true
			Fill.BackgroundColor3 = Drowning and Color3.fromRGB(220, 80, 70) or Color3.fromRGB(230, 205, 120)
			Label.Text = Drowning and "DROWNING" or "BREATH"
		end
	end)
end

if Player.Character then task.spawn(Hook, Player.Character) end
Player.CharacterAdded:Connect(Hook)

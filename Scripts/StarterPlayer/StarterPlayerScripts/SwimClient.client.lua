-- SwimClient: the swim animations (owner decision 6, 2026-10-18). The server owns the swim STATE (SwimService ->
-- character attribute Traversal = "Swim"); this only animates it on your own character (which replicates to
-- everyone): the owner's Swim_Idle treading water, Swim_Forward while moving (TuningConfig.Swim). Roblox's
-- Swimming humanoid state also counts, so the animation starts the moment you're in the water.
-- EXTRAS (owner 2026-10-18, "add swimming extras"):
--   * sprint: hold Shift while swimming and moving -> asks the server (Requests.Swim); while the server's
--     SwimSprint attribute is on, swim speed x SprintMult and the Swim_Sprint stroke. Stamina is the server's.
--   * diving: Roblox swims along the camera, so look down and swim to dive; hold Space to rise.
--   * breath bar: a thin bar under the centre of the screen while you're short of air (attribute Breath),
--     red while drowning.
--   * touch (2026-10-18): MobileControls' SPRINT / RISE buttons (shown only while swimming) run the actions
--     "SwimSprint" / "SwimRise" registered here: held = the same as holding Shift / Space.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UserInputService = game:GetService("UserInputService")

local AnimationManager = require(ReplicatedStorage.Modules.Managers.AnimationManager)
local ClientActions = require(ReplicatedStorage.Modules.Managers.ClientActions)
local ResourceManager = require(ReplicatedStorage.Modules.Managers.ResourceManager)
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig).Swim
local Remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RequestRemote")

local Player = Players.LocalPlayer
local DefaultWS = game:GetService("StarterPlayer"):FindFirstChild("StarterCharacter")
	and game.StarterPlayer.StarterCharacter:FindFirstChildOfClass("Humanoid")
	and game.StarterPlayer.StarterCharacter.Humanoid.WalkSpeed or 16

-- touch buttons (MobileControls): held state
local TouchSprint, TouchRise = false, false
ClientActions.Register("SwimSprint", function(Began) TouchSprint = Began == true end)
ClientActions.Register("SwimRise", function(Began) TouchRise = Began == true end)

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
	local SprintSpeed = nil -- the WalkSpeed we set for the sprint (put back only if nothing changed it since)
	local function Ask(On)
		if Asked == On then return end
		Asked = On
		Remote:FireServer("Swim", On)
	end
	local function Same(A, B) return A and B and math.abs(A - B) < 0.01 end -- (WalkSpeed is stored as a 32-bit float)
	local function EndSprintSpeed()
		if SprintSpeed and Same(Humanoid.WalkSpeed, SprintSpeed) then
			Humanoid.WalkSpeed = DefaultWS * (Character:GetAttribute("SpeedMultiplier") or 1)
		end
		SprintSpeed = nil
	end
	local Conn
	Conn = RunService.Heartbeat:Connect(function()
		if not Character.Parent then Conn:Disconnect() return end
		local ServerSwim = Character:GetAttribute("Traversal") == "Swim"
		local Swimming = Humanoid.Health > 0 and (ServerSwim or Humanoid:GetState() == Enum.HumanoidStateType.Swimming)
		local Moving = Humanoid.MoveDirection.Magnitude > Tuning.MoveThreshold
		-- sprint: Shift held while swimming and moving (and not typing)
		local WantSprint = ServerSwim and Moving and not UserInputService:GetFocusedTextBox()
			and (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) or TouchSprint)
		if WantSprint and not Asked and ResourceManager.Get(Character, "Stamina") < Tuning.SprintMinStamina then WantSprint = false end
		Ask(WantSprint == true)
		local Sprinting = WantSprint and Character:GetAttribute("SwimSprint") == true
		if Sprinting then
			local Want = DefaultWS * (Character:GetAttribute("SpeedMultiplier") or 1) * Tuning.SprintMult
			if not Same(Humanoid.WalkSpeed, Want) then Humanoid.WalkSpeed = Want end
			SprintSpeed = Want
		else
			-- (if the server stopped it -- out of stamina -- the request stays "on": let go of Shift to try again)
			EndSprintSpeed()
		end
		-- rise: hold Space while swimming (the game's own Space action doesn't jump in water)
		if not Swimming then TouchSprint, TouchRise = false, false end
		if Swimming and ((UserInputService:IsKeyDown(Enum.KeyCode.Space) and not UserInputService:GetFocusedTextBox()) or TouchRise) then
			Humanoid.Jump = true
		end
		if Swimming then
			Set(Sprinting and AnimationManager.Has(Character, Tuning.AnimSprint) and Tuning.AnimSprint
				or Moving and Tuning.AnimMove or Tuning.AnimIdle)
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

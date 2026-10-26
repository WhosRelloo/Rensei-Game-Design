-- Settings panel + the client effects each setting controls. The resolved settings are sent to
-- the server (Requests.Settings validates and saves them) so they persist across sessions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")

local UIState = require(script.Parent.UIState)
local LockOn = require(script.Parent.LockOn)
local Keybinds = require(ReplicatedStorage.Modules.Managers.Keybinds)
local JumpManager = require(ReplicatedStorage.Modules.Managers.JumpManager)
local SettingsDef = require(ReplicatedStorage.Modules.Data.Rensei.Settings)

local Player = Players.LocalPlayer
local Gui = UIState.Gui
local Panel = Gui.Settings
local Main = Panel.MainFrame
local Rows = Main.Container

local SettingsUI = {}

local Current = SettingsDef.Resolve(nil)
local Loaded = false
local Tab = "Gameplay"
local ActiveTabImage, InactiveTabImage
local Capturing = nil
local SaveToken = 0

local function Save()
	SaveToken += 1
	local Token = SaveToken
	task.delay(0.6, function() -- debounce slider drags
		if Token == SaveToken then UIState.Request("Settings", Current) end
	end)
end

-- ===== Effects =====
local SprintConn, ShiftConn
local GameSettings = UserSettings():GetService("UserGameSettings")
local BaseWalk = game.StarterPlayer.StarterCharacter.Humanoid.WalkSpeed

-- the swim plan's guard: swimming under water, the body keeps its own facing (SwimController, when the place has it)
local function SwimActive()
	local M = ReplicatedStorage.Modules.Managers:FindFirstChild("SwimController")
	return M ~= nil and require(M).Active()
end

-- the shift-lock camera (Alt), shared with guns' shooting mode (GunAimUI, gun rework 2026-10-25)
function SettingsUI.CameraFree(Humanoid)
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	if Humanoid then Humanoid.CameraOffset = Vector3.zero end
	pcall(function() GameSettings.RotationType = Enum.RotationType.MovementRelative end)
end
-- Offset: Humanoid.CameraOffset. SprintTurns: while sprinting, turn with movement (shift lock) instead of the camera.
function SettingsUI.CameraLock(Character, Humanoid, Offset, SprintTurns)
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
	Humanoid.CameraOffset = Offset
	-- On a wall (climbing / wall running / a ledge) or swimming under water, the body keeps its own facing
	if JumpManager.ClimbConn or JumpManager.WallRunConn or JumpManager.LedgeConn or SwimActive() then return end
	Humanoid.AutoRotate = true
	-- (a shift-lock dash keeps facing the camera: Roll sets Dashing)
	local Sprinting = SprintTurns and not Character:GetAttribute("Dashing")
		and Humanoid.WalkSpeed > BaseWalk * (Character:GetAttribute("SpeedMultiplier") or 1) * 1.5
	pcall(function()
		GameSettings.RotationType = Sprinting and Enum.RotationType.MovementRelative or Enum.RotationType.CameraRelative
	end)
end
local PostAuthored = {} -- [effect] = Enabled as authored (restored when Post Effects goes back on)
local function Apply()
	Player:SetAttribute("CameraShake", Current.CameraShake)
	pcall(function() Lighting.GlobalShadows = Current.Shadows end)
	-- 2026-10-15 settings update: read by CombatLogUI / UIMotion
	Player:SetAttribute("ShowCombatLog", Current.CombatLog)
	Player:SetAttribute("ShowCompass", Current.Compass) -- CompassUI (and CombatLogUI sits higher without it)
	Player:SetAttribute("ReducedMotion", not Current.UIAnimations)
	Player:SetAttribute("UISounds", Current.UISounds)
	for _, Effect in ipairs(Lighting:GetChildren()) do
		if Effect:IsA("BloomEffect") or Effect:IsA("SunRaysEffect") or Effect:IsA("DepthOfFieldEffect") then
			if PostAuthored[Effect] == nil then PostAuthored[Effect] = Effect.Enabled end
			Effect.Enabled = Current.PostEffects and PostAuthored[Effect]
		end
	end
	workspace.CurrentCamera.FieldOfView = SettingsDef.FOV(Current.FieldOfView)
	local SFX = SoundService:FindFirstChild("SFX")
	local Music = SoundService:FindFirstChild("Music")
	if SFX then SFX.Volume = Current.SFXVolume end
	if Music then Music.Volume = Current.MusicVolume end
	for Name, Key in pairs(Current.Keys) do Keybinds.Set(Name, Key) end

	-- Auto Sprint: start the existing Run ability whenever you move at walking pace.
	if Current.AutoSprint and not SprintConn then
		local Run = require(Player.PlayerScripts.ClientHandler.Run)
		local Base = game.StarterPlayer.StarterCharacter.Humanoid.WalkSpeed
		SprintConn = task.spawn(function()
			while true do
				task.wait(0.25)
				local Character = Player.Character
				local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
				if Humanoid and Humanoid.MoveDirection.Magnitude > 0.1 then
					local Walk = Base * (Character:GetAttribute("SpeedMultiplier") or 1)
					if math.abs(Humanoid.WalkSpeed - Walk) < 0.05 then
						pcall(Run.OnStartClient, Run)
					end
				end
			end
		end)
	elseif not Current.AutoSprint and SprintConn then
		task.cancel(SprintConn)
		SprintConn = nil
	end

	-- Shift Lock (Alt), Devil Hunter style: mouse locked to the centre, the camera raised over the
	-- character (Humanoid.CameraOffset 0,1.5,0.5 -- the value Devil Hunter uses), and the character
	-- turned with Roblox's native camera-relative rotation (movement-relative while sprinting).
	-- Roblox's own shift lock is disabled (it sat on Shift = Run). The system cursor is hidden and
	-- the small Rensei marker (Uis.Crosshair) shows the centre. The camera itself is SettingsUI.CameraLock /
	-- CameraFree (above), which guns' shooting mode shares; while ShootingMode is on, GunAimUI owns the camera.
	-- On a wall (climbing / wall running) the body keeps facing the wall: the camera turns freely and the
	-- character does not follow it (JumpManager owns AutoRotate there).
	if Current.ShiftLock and not ShiftConn then
		ShiftConn = RunService.RenderStepped:Connect(function()
			local Character = Player.Character
			local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
			if Player.Character and Player.Character:GetAttribute("ShootingMode") then return end -- GunAimUI owns the camera
			if Gui.bg.Visible or Gui.Dialogue.Visible or LockOn.Target or not Humanoid then
				SettingsUI.CameraFree(Humanoid) Gui.Crosshair.Visible = false return
			end
			Gui.Crosshair.Visible = true
			SettingsUI.CameraLock(Character, Humanoid, Vector3.new(0, 1.5, 0.5), true)
		end)
	elseif not Current.ShiftLock and ShiftConn then
		ShiftConn:Disconnect()
		ShiftConn = nil
		local Humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
		SettingsUI.CameraFree(Humanoid)
		Gui.Crosshair.Visible = false
		if Humanoid and not LockOn.Target then Humanoid.AutoRotate = true end
	end
end

-- ===== Panel =====
local function KeyLabel(Name)
	return Name:gsub("(%l)(%u)", "%1 %2")
end

local function Render()
	for _, T in ipairs(Main.Sections:GetChildren()) do
		if T:IsA("ImageButton") then
			-- The authored "active" tab art has the word Gameplay baked in, so every tab uses the
			-- plain art and the selected one is marked by tint and text colour instead.
			local Active = T.Name == Tab
			T.Image = InactiveTabImage
			T.ImageColor3 = Active and Color3.new(1, 1, 1) or Color3.fromRGB(150, 150, 150)
			local Head = T:FindFirstChild("Head")
			if Head then Head.TextColor3 = Active and Color3.fromRGB(230, 205, 120) or Color3.fromRGB(190, 190, 190) end
		end
	end
	for _, Row in ipairs(Rows:GetChildren()) do
		if Row:IsA("GuiObject") then
			Row.Visible = Row:GetAttribute("Tab") == Tab
			local Kind = Row:GetAttribute("Kind")
			local C = Row:FindFirstChild("Controls")
			if Kind == "Toggle" then
				local On = Current[Row.Name]
				C.Enable.ImageTransparency = On and 0 or 0.65
				C.Disable.ImageTransparency = On and 0.65 or 0
				C.Enable.Head.TextTransparency = On and 0 or 0.5
				C.Disable.Head.TextTransparency = On and 0.5 or 0
			elseif Kind == "Slider" then
				local V = Current[Row.Name]
				C.Display.Text = Row.Name == "FieldOfView" and (SettingsDef.FOV(V) .. "\u{00B0}") or (math.floor(V * 100 + 0.5) .. "%")
				C.Bar.Hitter.AnchorPoint = Vector2.new(0.5, 0.5)
				C.Bar.Hitter.Position = UDim2.fromScale(V, 0.5)
			elseif Kind == "Key" then
				C.Bind.Head.Text = (Capturing == Row.Name) and "Press Any Key" or KeyLabel(Current.Keys[Row.Name])
			end
		end
	end
end

local function SliderAt(Row, X)
	local Bar = Row.Controls.Bar
	local V = math.clamp((X - Bar.AbsolutePosition.X) / math.max(1, Bar.AbsoluteSize.X), 0, 1)
	Current[Row.Name] = math.floor(V * 100 + 0.5) / 100
	Apply() Render() Save()
end

function SettingsUI.Start()
	local Tabs = {}
	for _, T in ipairs(Main.Sections:GetChildren()) do if T:IsA("ImageButton") then Tabs[T.Name] = T end end
	ActiveTabImage = Tabs.Gameplay.Image
	InactiveTabImage = Tabs.Graphics.Image
	for Name, T in pairs(Tabs) do
		T.Activated:Connect(function() Tab = Name Capturing = nil Render() end)
	end

	for _, Row in ipairs(Rows:GetChildren()) do
		if Row:IsA("GuiObject") then
			local Kind = Row:GetAttribute("Kind")
			local C = Row:FindFirstChild("Controls")
			if Kind == "Toggle" then
				C.Enable.Activated:Connect(function() Current[Row.Name] = true Apply() Render() Save() end)
				C.Disable.Activated:Connect(function() Current[Row.Name] = false Apply() Render() Save() end)
			elseif Kind == "Slider" then
				local Dragging = false
				local function Begin(Input)
					if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
						Dragging = true
						SliderAt(Row, Input.Position.X)
					end
				end
				C.Bar.Hitter.InputBegan:Connect(Begin)
				C.Bar.InputBegan:Connect(Begin)
				C.Bar.Active = true
				UserInputService.InputChanged:Connect(function(Input)
					if Dragging and (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch) then
						SliderAt(Row, Input.Position.X)
					end
				end)
				UserInputService.InputEnded:Connect(function(Input)
					if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
						Dragging = false
					end
				end)
			elseif Kind == "Key" then
				C.Bind.Activated:Connect(function()
					Capturing = Row.Name
					Render()
				end)
			end
		end
	end

	UserInputService.InputBegan:Connect(function(Input)
		if not Capturing or Input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		local Name = Input.KeyCode.Name
		if Input.KeyCode == Enum.KeyCode.Escape then
			Capturing = nil
		elseif SettingsDef.IsBindableKey(Name) then
			-- one key per action: swap with whichever action already used it
			for Other, Key in pairs(Current.Keys) do
				if Key == Name and Other ~= Capturing then Current.Keys[Other] = Current.Keys[Capturing] end
			end
			Current.Keys[Capturing] = Name
			Capturing = nil
			Apply() Save()
		else
			return -- reserved key: keep waiting for a bindable one
		end
		Render()
	end)

	UIState.RegisterMenu("Settings", Panel, function() Capturing = nil Render() end)

	UIState.Changed:Connect(function(Data)
		if Loaded then return end -- the server copy is authoritative only on load
		Loaded = true
		Current = SettingsDef.Resolve(Data.Settings)
		Apply()
		Render()
	end)

	-- Alt toggles Shift Lock (controls doc). The toggle is saved like the Settings switch.
	ContextActionService:BindAction("RenseiShiftLock", function(_, State)
		if State == Enum.UserInputState.Begin then
			Current.ShiftLock = not Current.ShiftLock
			Apply() Render() Save()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.LeftAlt, Enum.KeyCode.RightAlt)

	-- Lock Target key
	local function BindLock()
		ContextActionService:UnbindAction("RenseiLockTarget")
		ContextActionService:BindAction("RenseiLockTarget", function(_, State)
			if State == Enum.UserInputState.Begin then LockOn.Toggle() end
			return Enum.ContextActionResult.Pass
		end, true, Keybinds.Get("LockTarget"))
		ContextActionService:SetTitle("RenseiLockTarget", "Lock")
	end
	BindLock()
	Keybinds.Changed:Connect(function(Name) if Name == "LockTarget" then BindLock() end end)

	Apply()
	Render()
end

return SettingsUI

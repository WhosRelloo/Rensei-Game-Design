-- Mobile controls (controls doc: "mobile buttons"): a touch button cluster in Rensei's slot-plate art,
-- bottom-right, that runs the very same actions as the keyboard (Managers.ClientActions).
--   always:            Jump (hold = wall run, tap at a wall = climb), Dash, Fight / Calm, Run (toggle)
--   in Combat Mode:    Attack (hold = keep swinging), Heavy, Block (hold; tap = parry), Feint, Upper(cut),
--                      Skill (weapon skill, when holding a weapon), Z / X / C / V alchemy (hold = keep
--                      the clap), with cooldowns, once the player has an alchemy path
--   out of combat:     Slide
--   near a knocked body: Grip (V carries: it's the V button); not while holding a hostage
--   (hostages Task 12, spec section 2 "mobile gets a button in the existing touch cluster"; pre-flight P19) holding a
--                      hostage: HOSTAGE in Grip's spot (the captor menu, HostageUI); held: STRUGGLE in Block's spot (one
--                      struggle press per tap; BLOCK hides while held, so the two never share the spot). Both only
--                      while hostages are on (TakedownUI.HostagesOn).
--   swimming (2026-10-18): SPRINT (hold) and RISE (hold; tap at a low ledge = climb out) in Dash's and Jump's spots,
--                      and DIVE (swimming revamp 2026-10-26: tap at the surface = dive, hold underwater = sink) in
--                      Slide's spot; the on-foot buttons that do nothing in water (Jump, Dash, Fight, Run, Slide)
--                      hide meanwhile. Actions: SwimClient.
-- Shown on touch screens (Player attribute MobileControls is set while it shows, and the desktop
-- alchemy slot bar hides). In Studio, set the Player attribute ForceMobileControls = true to test it
-- on a PC. Roblox's own jump button is hidden: ours also climbs and wall-runs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local ClientActions = require(ReplicatedStorage.Modules.Managers.ClientActions)
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)
local Registry = require(ReplicatedStorage.Modules.Data.Rensei.Alchemy)
local ResourceManager = require(ReplicatedStorage.Modules.Managers.ResourceManager)
local TakedownUI = require(script.Parent.TakedownUI) -- (hostages Task 12: HostagesOn)

local Player = Players.LocalPlayer

local SLOT_IMAGE = "rbxassetid://108980512067469" -- Rensei hotbar slot plate
local CIRCLE_IMAGE = "rbxassetid://132299053523633" -- Rensei transmutation circle
local FONT = Font.new("rbxasset://fonts/families/Guru.json", Enum.FontWeight.Bold)
local TEXT = Color3.fromRGB(240, 230, 215)
local ElementColor = {
	Flame = Color3.fromRGB(255, 120, 40), Ice = Color3.fromRGB(140, 210, 255), Earth = Color3.fromRGB(190, 140, 90),
	Wind = Color3.fromRGB(170, 240, 190), Metal = Color3.fromRGB(200, 205, 215),
}

-- Layout: centre (x, y) inside the cluster and size (fraction of its height). The cluster is 1.25
-- wide per 1 high and takes 55% of the screen's height in the bottom-right corner (on a ~390px-tall
-- phone: Attack ~73px, the main buttons ~45px, the small ones ~34px). Spacing checked so no two
-- buttons touch.
local CLUSTER_HEIGHT = 0.55
local Layout = {
	Attack = {0.84, 0.76, 0.34, "ATTACK", "Combat"},
	Heavy = {0.84, 0.40, 0.21, "HEAVY", "Combat"},
	Block = {0.62, 0.48, 0.21, "BLOCK", "Combat"},
	Feint = {0.965, 0.52, 0.16, "FEINT", "Combat"},
	Uppercut = {0.43, 0.64, 0.16, "UPPER", "Combat"},
	WeaponSkill = {0.42, 0.36, 0.16, "SKILL", "Weapon"},
	Dash = {0.60, 0.80, 0.21, "DASH", "Always"},
	Jump = {0.42, 0.90, 0.21, "JUMP", "Always"},
	CombatMode = {0.20, 0.36, 0.16, "FIGHT", "Always"},
	Sprint = {0.20, 0.62, 0.16, "RUN", "Always"},
	Slide = {0.20, 0.88, 0.16, "SLIDE", "Calm"},
	Grip = {0.62, 0.20, 0.16, "GRIP", "Knocked"},
	-- hostages (Task 12): Grip's and Block's spots; Grip hides while Holding and Block while Held
	Hostage = {0.62, 0.20, 0.16, "HOSTAGE", "Holding"},
	Struggle = {0.62, 0.48, 0.21, "STRUGGLE", "Held"},
	-- guns (2026-10-17): AIM toggles shooting mode (in Slide's spot, which is hidden in Combat Mode); FIRE
	-- only shows while shooting. The ATTACK button stays the pistol whip.
	Aim = {0.20, 0.88, 0.16, "AIM", "Gun"},
	Fire = {0.84, 0.13, 0.18, "FIRE", "Shooting"},
	-- alchemy: a column down the left edge (the top-right corner belongs to the leaderboard)
	AlchemyZ = {0.05, 0.20, 0.17, "Z", "Alchemy"},
	AlchemyX = {0.05, 0.42, 0.17, "X", "Alchemy"},
	AlchemyC = {0.05, 0.64, 0.17, "C", "Alchemy"},
	AlchemyV = {0.05, 0.86, 0.17, "V", "Alchemy"},
	-- swimming only (owner 2026-10-18): hold to sprint-swim (stamina) / hold to rise to the surface
	SwimSprint = {0.60, 0.80, 0.21, "SPRINT", "Swim"},
	SwimRise = {0.42, 0.90, 0.21, "RISE", "Swim"},
	-- swimming revamp (2026-10-26, PROPOSAL): tap at the surface = dive; hold underwater = sink. In Slide's spot
	-- (Slide and Aim are hidden while swimming)
	SwimDive = {0.20, 0.88, 0.16, "DIVE", "Swim"},
}
local TOGGLES = {Sprint = true} -- tap on / tap off (sprinting is held Shift on a keyboard)

local MobileControls = {}

local Gui, Cluster
local Buttons = {} -- [Name] = {Frame, Label, Circle, Cool, Seconds, Held, Input}
local SprintOn = false

local function Label(Parent, Props)
	local L = Instance.new("TextLabel")
	L.BackgroundTransparency = 1
	L.FontFace = FONT
	L.TextScaled = true
	L.TextColor3 = TEXT
	L.ZIndex = 4
	local Stroke = Instance.new("UIStroke")
	Stroke.Thickness = 1.5
	Stroke.Color = Color3.fromRGB(15, 10, 8)
	Stroke.Parent = L
	for K, V in pairs(Props) do L[K] = V end
	L.Parent = Parent
	return L
end

local function Press(Name, B, Began)
	if TOGGLES[Name] then
		if not Began then return end
		SprintOn = not SprintOn
		ClientActions.Run(Name, SprintOn)
		return
	end
	if B.Held == Began then return end
	B.Held = Began
	B.Frame.ImageColor3 = Began and Color3.fromRGB(255, 225, 190) or Color3.new(1, 1, 1)
	ClientActions.Run(Name, Began)
end

local function MakeButton(Name, Spec)
	local X, Y, Size, Text = Spec[1], Spec[2], Spec[3], Spec[4]
	local F = Instance.new("ImageButton")
	F.Name = Name
	F.BackgroundTransparency = 1
	F.Image = SLOT_IMAGE
	F.AutoButtonColor = false
	F.AnchorPoint = Vector2.new(0.5, 0.5)
	F.Position = UDim2.fromScale(X, Y)
	F.Size = UDim2.fromScale(1, Size)
	local Ratio = Instance.new("UIAspectRatioConstraint")
	Ratio.AspectRatio = 1
	Ratio.DominantAxis = Enum.DominantAxis.Height
	Ratio.Parent = F
	local Circle = Instance.new("ImageLabel")
	Circle.Name = "Circle"
	Circle.BackgroundTransparency = 1
	Circle.Image = CIRCLE_IMAGE
	Circle.ImageTransparency = 0.75
	Circle.ImageColor3 = Color3.fromRGB(230, 200, 160)
	Circle.AnchorPoint = Vector2.new(0.5, 0.5)
	Circle.Position = UDim2.fromScale(0.5, 0.5)
	Circle.Size = UDim2.fromScale(0.8, 0.8)
	Circle.Parent = F
	local Main = Label(F, {Name = "Text", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.72, #Text <= 2 and 0.42 or 0.26), Text = Text})
	local Sub = Label(F, {Name = "Sub", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.92),
		Size = UDim2.fromScale(0.85, 0.18), Text = ""})
	local Cool = Instance.new("Frame")
	Cool.Name = "Cooldown"
	Cool.BackgroundColor3 = Color3.fromRGB(10, 6, 6)
	Cool.BackgroundTransparency = 0.3
	Cool.BorderSizePixel = 0
	Cool.AnchorPoint = Vector2.new(0.5, 1)
	Cool.Position = UDim2.fromScale(0.5, 0.9)
	Cool.Size = UDim2.fromScale(0.8, 0)
	Cool.ZIndex = 3
	Cool.Visible = false
	Cool.Parent = F
	local Seconds = Label(F, {Name = "Seconds", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.6, 0.3), Text = "", ZIndex = 5, Visible = false})
	local B = {Frame = F, Text = Main, Sub = Sub, Circle = Circle, Cool = Cool, Seconds = Seconds, Held = false, Group = Spec[5]}
	-- press / release, following the finger that pressed it (it may slide off the button)
	F.InputBegan:Connect(function(Input)
		if Input.UserInputType ~= Enum.UserInputType.Touch and Input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		B.Input = Input
		Press(Name, B, true)
		local Conn
		Conn = Input:GetPropertyChangedSignal("UserInputState"):Connect(function()
			if Input.UserInputState == Enum.UserInputState.End or Input.UserInputState == Enum.UserInputState.Cancel then
				Conn:Disconnect()
				if B.Input == Input then B.Input = nil Press(Name, B, false) end
			end
		end)
	end)
	F.InputEnded:Connect(function(Input)
		if B.Input == Input then B.Input = nil Press(Name, B, false) end
	end)
	F.Parent = Cluster
	Buttons[Name] = B
end

local function Active()
	if Player:GetAttribute("ForceMobileControls") then return true end
	return UserInputService.TouchEnabled and (not UserInputService.KeyboardEnabled
		or UserInputService:GetLastInputType() == Enum.UserInputType.Touch)
end
-- the touch test the rest of the game uses (GunAimUI's touch assist, HUDUI's hint; gun rework 2026-10-25)
MobileControls.Active = Active

local function KnockedNearby(Character)
	local Root = Character and Character:FindFirstChild("HumanoidRootPart")
	if not Root then return false end
	local Range = (Tuning.Downed and Tuning.Downed.GripRange or 6) + 2
	-- (townsfolk in World.Live.Townsfolk too: a knocked townsperson shows the Grip button, Task 6b)
	for _, M in ipairs(require(ReplicatedStorage.Modules.Managers.DownedManager).LiveModels()) do
		if M ~= Character and M:GetAttribute("Knocked") then
			local R = M:FindFirstChild("HumanoidRootPart")
			if R and (R.Position - Root.Position).Magnitude <= Range then return true end
		end
	end
	return false
end

-- Roblox's own touch jump button: ours replaces it (it also climbs and wall-runs)
local function HideDefaultJump(Hide)
	local TouchGui = Player:FindFirstChild("PlayerGui") and Player.PlayerGui:FindFirstChild("TouchGui")
	local Jump = TouchGui and TouchGui:FindFirstChild("JumpButton", true)
	if Jump then Jump.Visible = not Hide end
end

-- The Server Info readout (Uis.HUD.Server) sits where the cluster goes: hidden while the touch
-- controls show, back as it was when they hide.
local ServerPanelWas = nil
local function MakeRoom(On)
	local Uis = Player.PlayerGui:FindFirstChild("Uis")
	local Panel = Uis and Uis:FindFirstChild("HUD") and Uis.HUD:FindFirstChild("Server")
	if not Panel then return end
	if On then
		if ServerPanelWas == nil then ServerPanelWas = Panel.Visible end
		Panel.Visible = false
	elseif ServerPanelWas ~= nil then
		Panel.Visible = ServerPanelWas
		ServerPanelWas = nil
	end
end

function MobileControls.Start()
	Gui = Instance.new("ScreenGui")
	Gui.Name = "MobileControls"
	Gui.ResetOnSpawn = false
	Gui.IgnoreGuiInset = true
	Gui.DisplayOrder = 5
	Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	Gui.Enabled = false
	Cluster = Instance.new("Frame")
	Cluster.Name = "Cluster"
	Cluster.BackgroundTransparency = 1
	Cluster.AnchorPoint = Vector2.new(1, 1)
	Cluster.Position = UDim2.fromScale(0.99, 0.97)
	Cluster.Size = UDim2.fromScale(1, CLUSTER_HEIGHT)
	local Ratio = Instance.new("UIAspectRatioConstraint")
	Ratio.AspectRatio = 1.25
	Ratio.DominantAxis = Enum.DominantAxis.Height
	Ratio.Parent = Cluster
	Cluster.Parent = Gui
	for Name, Spec in pairs(Layout) do MakeButton(Name, Spec) end
	Gui.Parent = Player:WaitForChild("PlayerGui")

	local ShownAffinity = nil
	local Built = {}
	RunService.RenderStepped:Connect(function()
		local On = Active()
		if Gui.Enabled ~= On then
			Gui.Enabled = On
			Player:SetAttribute("MobileControls", On or nil)
			if not On then
				-- let go of anything held, and stop a toggled run
				for Name, B in pairs(Buttons) do if B.Held then Press(Name, B, false) end end
				if SprintOn then SprintOn = false ClientActions.Run("Sprint", false) end
			end
		end
		HideDefaultJump(On)
		MakeRoom(On)
		if not On then return end
		local Character = Player.Character
		local Combat = Character ~= nil and Character:GetAttribute("CombatMode") == true
		local Affinity = Player:GetAttribute("Affinity")
		local Weapon = Character ~= nil and Character:GetAttribute("Weapon") ~= nil
		local Gun = Character ~= nil and Character:GetAttribute("Weapon") == "Guns"
		local Shooting = Character ~= nil and Character:GetAttribute("ShootingMode") == true
		local Knocked = KnockedNearby(Character)
		local Swimming = Character ~= nil and Character:GetAttribute("Traversal") == "Swim"
		local HostagesOn = Character ~= nil and TakedownUI.HostagesOn()
		local Holding = HostagesOn and Character:GetAttribute("Holding") ~= nil
		local Held = HostagesOn and Character:GetAttribute("HeldBy") ~= nil
		if Affinity ~= ShownAffinity then
			ShownAffinity = Affinity
			local Color = ElementColor[Affinity or ""] or Color3.fromRGB(230, 200, 160)
			for _, Def in ipairs(Affinity and Registry.ForAffinity(Affinity) or {}) do
				local B = Buttons["Alchemy" .. Def.Key]
				if B then
					Built[Def.Key] = Tuning.Alchemy.Abilities[Def.Id] ~= nil
					B.Sub.Text = Def.Name
					B.Circle.ImageColor3 = Color
					B.Circle.ImageTransparency = Built[Def.Key] and 0.45 or 0.85
				end
			end
		end
		Buttons.CombatMode.Text.Text = Combat and "CALM" or "FIGHT"
		Buttons.Aim.Text.Text = Shooting and "STOP" or "AIM"
		Buttons.Sprint.Circle.ImageTransparency = SprintOn and 0.3 or 0.75
		local Now = workspace:GetServerTimeNow()
		local Meter = Character and ResourceManager.Get(Character, "Meter") or 0
		for Name, B in pairs(Buttons) do
			local Show = (B.Group == "Always" and not Swimming) or (B.Group == "Combat" and Combat) or (B.Group == "Calm" and not Combat and not Swimming)
				or (B.Group == "Swim" and Swimming)
				or (B.Group == "Weapon" and Combat and Weapon) or (B.Group == "Alchemy" and Combat and Affinity ~= nil)
				or (B.Group == "Knocked" and Knocked and not Holding)
				or (B.Group == "Gun" and Combat and Gun) or (B.Group == "Shooting" and Combat and Shooting)
				or (B.Group == "Holding" and Holding) or (B.Group == "Held" and Held)
			if Name == "Block" and Held then Show = false end -- (P19: STRUGGLE has Block's spot while held)
			if B.Frame.Visible ~= Show then
				B.Frame.Visible = Show
				if not Show and B.Held then Press(Name, B, false) end
				-- into the water: a toggled run stops (its button hides)
				if not Show and Name == "Sprint" and SprintOn then SprintOn = false ClientActions.Run("Sprint", false) end
			end
			if Show and B.Group == "Alchemy" then
				local Key = Name:sub(-1)
				local Left = Character and (Character:GetAttribute("Alchemy" .. Key .. "ReadyAt") or 0) - Now or 0
				if Left > 0.05 then
					local Full = Character:GetAttribute("Alchemy" .. Key .. "Cooldown") or Left
					B.Cool.Visible = true
					B.Cool.Size = UDim2.fromScale(0.8, 0.8 * math.clamp(Left / Full, 0, 1))
					B.Seconds.Visible = true
					B.Seconds.Text = ("%.1f"):format(Left)
				else
					B.Cool.Visible = false
					B.Seconds.Visible = false
				end
				local Cost = Tuning.Alchemy.MeterCost[Key] or 0
				B.Frame.ImageColor3 = (B.Held and Color3.fromRGB(255, 225, 190)) or (Built[Key] and Meter >= Cost and Color3.new(1, 1, 1)) or Color3.fromRGB(130, 120, 120)
			end
		end
	end)
end

return MobileControls

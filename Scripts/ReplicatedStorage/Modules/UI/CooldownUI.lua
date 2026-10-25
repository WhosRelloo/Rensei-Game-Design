-- Cooldown list, Rensei style: one plate per move that is cooling down (name, seconds left, a
-- crimson bar draining as it recovers). Sits just right of the vitals bars. Reads the server's
-- cooldown attributes (server time) and the dash's own client timer; display only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UIState = require(script.Parent.UIState)
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)

local Player = Players.LocalPlayer
local Gui = UIState.Gui
local HUD = Gui.HUD

local PLATE_IMAGE = "rbxassetid://122177696782315" -- the plain tab art used across the Rensei UI

-- Attribute = server-time "ready at" on the character; Duration = full cooldown for the bar.
-- DurationAttribute: the server writes the full cooldown there when it varies (weapon heavies/skills).
-- NameAttribute: the label comes from the character (the weapon skill's name).
-- Ammo: shown while a gun is held (rounds left / magazine).
local Entries = {
	{Name = "Ammo", Ammo = true},
	{Name = "Reload", Attribute = "ReloadingUntil", DurationAttribute = "ReloadTime", Duration = 1.8},
	{Name = "Dash", Client = true, Duration = Tuning.Dash.Cooldown},
	{Name = "Heavy", Attribute = "HeavyReadyAt", DurationAttribute = "HeavyCooldown", Duration = Tuning.Heavy.Cooldown},
	{Name = "Weapon Skill", Attribute = "WeaponSkillReadyAt", DurationAttribute = "WeaponSkillCooldown", NameAttribute = "WeaponSkillName", Duration = 6},
	{Name = "Feint", Attribute = "FeintReadyAt", Duration = Tuning.Feint.Cooldown},
	{Name = "Uppercut", Attribute = "UppercutReadyAt", Duration = Tuning.Uppercut.Cooldown},
	{Name = "Dash Attack", Attribute = "DashAttackReadyAt", Duration = Tuning.DashAttack.Cooldown},
	{Name = "Parry", Attribute = "ParryReadyAt", Duration = Tuning.Parry.FailLockout},
	-- (alchemy cooldowns show on the alchemy slot bar, AlchemyUI)
}

local CooldownUI = {}

local Container
local Rows = {}

local function MakeRow(Entry, Order)
	local Row = Instance.new("ImageLabel")
	Row.Name = Entry.Name
	Row.BackgroundTransparency = 1
	Row.Image = PLATE_IMAGE
	Row.ImageColor3 = Color3.fromRGB(200, 200, 200)
	Row.Size = UDim2.fromScale(1, 0.15)
	Row.LayoutOrder = Order
	Row.Visible = false
	local Label = HUD.CashFrame.Display:Clone()
	for _, K in ipairs(Label:GetChildren()) do if not K:IsA("UIStroke") then K:Destroy() end end
	Label.Name = "Label"
	Label.BackgroundTransparency = 1
	Label.AnchorPoint = Vector2.new(0, 0.5)
	Label.Position = UDim2.fromScale(0.06, 0.43)
	Label.Size = UDim2.fromScale(0.88, 0.62) -- readability pass: larger text
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.TextColor3 = Color3.fromRGB(235, 225, 215)
	Label.Parent = Row
	local Track = Instance.new("Frame")
	Track.Name = "Track"
	Track.BackgroundColor3 = Color3.fromRGB(20, 12, 12)
	Track.BackgroundTransparency = 0.3
	Track.BorderSizePixel = 0
	Track.AnchorPoint = Vector2.new(0, 1)
	Track.Position = UDim2.fromScale(0.08, 0.86)
	Track.Size = UDim2.fromScale(0.84, 0.09)
	Track.Parent = Row
	local Bar = Instance.new("Frame")
	Bar.Name = "Bar"
	Bar.BackgroundColor3 = Color3.fromRGB(170, 28, 34)
	Bar.BorderSizePixel = 0
	Bar.Size = UDim2.fromScale(1, 1)
	Bar.Parent = Track
	Row.Parent = Container
	return Row
end

local function Place()
	local Stats = HUD.Stats
	local W, H = HUD.AbsoluteSize.X, HUD.AbsoluteSize.Y
	if W <= 0 or H <= 0 then return end
	local Right = Stats.AbsolutePosition.X + Stats.AbsoluteSize.X - HUD.AbsolutePosition.X
	local Bottom = Stats.AbsolutePosition.Y + Stats.AbsoluteSize.Y - HUD.AbsolutePosition.Y
	Container.Position = UDim2.fromScale(Right / W + 0.006, Bottom / H)
end

function CooldownUI.Start()
	Container = Instance.new("Frame")
	Container.Name = "Cooldowns"
	Container.BackgroundTransparency = 1
	Container.AnchorPoint = Vector2.new(0, 1)
	Container.Size = UDim2.fromScale(0.15, 0.25) -- readability pass: was 0.12 x 0.2
	local AR = Instance.new("UIAspectRatioConstraint")
	AR.AspectRatio = 1.2
	AR.DominantAxis = Enum.DominantAxis.Height
	AR.Parent = Container
	local List = Instance.new("UIListLayout")
	List.SortOrder = Enum.SortOrder.LayoutOrder
	List.VerticalAlignment = Enum.VerticalAlignment.Bottom
	List.Padding = UDim.new(0.015, 0)
	List.Parent = Container
	Container.Parent = HUD
	for I, Entry in ipairs(Entries) do Rows[Entry] = MakeRow(Entry, I) end

	local Roll = require(Player.PlayerScripts:WaitForChild("ClientHandler"):WaitForChild("Roll"))
	HUD.Stats:GetPropertyChangedSignal("AbsoluteSize"):Connect(Place)
	HUD.Stats:GetPropertyChangedSignal("AbsolutePosition"):Connect(Place)
	Place()

	RunService.RenderStepped:Connect(function()
		local Character = Player.Character
		local Now = workspace:GetServerTimeNow()
		for Entry, Row in pairs(Rows) do
			local Left = 0
			if Entry.Ammo then
				local Max = Character and Character:GetAttribute("MaxAmmo")
				Row.Visible = Max ~= nil
				if Max then
					local Ammo = Character:GetAttribute("Ammo") or 0
					Row.Label.Text = ("%s  %d / %d"):format(Character:GetAttribute("WeaponItem") or "Ammo", Ammo, Max)
					Row.Track.Bar.Size = UDim2.fromScale(math.clamp(Ammo / Max, 0, 1), 1)
				end
				continue
			end
			local Duration = Entry.DurationAttribute and Character and Character:GetAttribute(Entry.DurationAttribute) or Entry.Duration
			local Label = Entry.NameAttribute and Character and Character:GetAttribute(Entry.NameAttribute) or Entry.Name
			if Character then
				if Entry.Client then
					Left = (Roll.ReadyAt or 0) - os.clock()
				else
					Left = (Character:GetAttribute(Entry.Attribute) or 0) - Now
				end
			end
			if Left > 0.05 then
				Row.Visible = true
				Row.Label.Text = ("%s  %.1fs"):format(Label, Left)
				Row.Track.Bar.Size = UDim2.fromScale(math.clamp(Left / Duration, 0, 1), 1)
			else
				Row.Visible = false
			end
		end
	end)
end

return CooldownUI

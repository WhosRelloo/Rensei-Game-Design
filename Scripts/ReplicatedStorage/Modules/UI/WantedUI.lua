-- WantedUI (2026-10-20, Morality × Reputation spec §14; Plan 2): a small Wanted badge to the right of the compass,
-- one per jurisdiction you're wanted in (State blue, Militia brown, Circle dark red), with five pips for the level.
-- Hidden at Wanted 0, and with the compass's rules (menus, dialogue, cutscenes, death). Reads the Player
-- attributes Wanted_<J> that HeatService publishes; it never decides anything.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIState = require(script.Parent.UIState)
local Heat = require(ReplicatedStorage.Modules.Data.Rensei.Heat)

local Player = Players.LocalPlayer

local INK = Color3.fromRGB(236, 228, 206)
local FONT = Font.new("rbxasset://fonts/families/Guru.json", Enum.FontWeight.Bold)
local TOP = 6 -- the compass strip's top (CompassUI)
local W, H, GAP = 74, 20, 6

local WantedUI = {}

local function Make(Class, Props, Parent)
	local O = Instance.new(Class)
	for K, V in pairs(Props) do O[K] = V end
	O.Parent = Parent
	return O
end

local Gui, Row
local Badges = {} -- [J] = {Frame, Pips = {...}}

local function Build()
	Gui = Make("ScreenGui", {Name = "Wanted", ResetOnSpawn = false, DisplayOrder = 5, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, Player:WaitForChild("PlayerGui"))
	Row = Make("CanvasGroup", {Name = "Row", AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0.5, 190, 0, TOP),
		Size = UDim2.fromOffset((W + GAP) * 3, H), BackgroundTransparency = 1, GroupTransparency = 0}, Gui)
	Make("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, GAP),
		SortOrder = Enum.SortOrder.LayoutOrder}, Row)
	for I, J in ipairs(Heat.Order) do
		local Color = Heat.Colors[J]
		local F = Make("Frame", {Name = J, Size = UDim2.fromOffset(W, H), BackgroundColor3 = Color3.fromRGB(14, 13, 16),
			BackgroundTransparency = 0.25, BorderSizePixel = 0, LayoutOrder = I, Visible = false}, Row)
		Make("UICorner", {CornerRadius = UDim.new(0, 4)}, F)
		Make("UIStroke", {Color = Color, Thickness = 1, Transparency = 0.2}, F)
		-- the jurisdiction's colour as a seal on the left
		local Seal = Make("Frame", {Name = "Seal", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 5, 0.5, 0),
			Size = UDim2.fromOffset(8, 8), Rotation = 45, BackgroundColor3 = Color, BorderSizePixel = 0}, F)
		Make("UIStroke", {Color = INK, Thickness = 1, Transparency = 0.5}, Seal)
		Make("TextLabel", {Name = "Name", Position = UDim2.fromOffset(17, 1), Size = UDim2.fromOffset(W - 20, 10),
			BackgroundTransparency = 1, FontFace = FONT, TextSize = 10, TextColor3 = INK, TextXAlignment = Enum.TextXAlignment.Left,
			Text = string.upper(Heat.Names[J])}, F)
		local Pips = {}
		for P = 1, #Heat.Thresholds do
			local Pip = Make("Frame", {Name = "Pip" .. P, Position = UDim2.fromOffset(17 + (P - 1) * 10, 12), Size = UDim2.fromOffset(7, 4),
				BackgroundColor3 = Color, BackgroundTransparency = 0.8, BorderSizePixel = 0}, F)
			Pips[P] = Pip
		end
		Badges[J] = {Frame = F, Pips = Pips}
	end
end

local function Hidden()
	local G = UIState.Gui
	if (G:FindFirstChild("bg") and G.bg.Visible) or (G:FindFirstChild("Dialogue") and G.Dialogue.Visible) then return true end
	if workspace.CurrentCamera.CameraType == Enum.CameraType.Scriptable then return true end
	local C = Player.Character
	local Hum = C and C:FindFirstChildOfClass("Humanoid")
	return not Hum or Hum.Health <= 0
end

local Last = {}
function WantedUI.Refresh()
	if not Row then return end
	Row.GroupTransparency = Hidden() and 1 or 0
	for _, J in ipairs(Heat.Order) do
		local B = Badges[J]
		local Level = tonumber(Player:GetAttribute("Wanted_" .. J)) or 0
		B.Frame.Visible = Level > 0
		for P, Pip in ipairs(B.Pips) do Pip.BackgroundTransparency = P <= Level and 0 or 0.8 end
		-- a short pulse when the level rises
		if Level > (Last[J] or 0) then
			B.Frame.Size = UDim2.fromOffset(W + 8, H + 4)
			TweenService:Create(B.Frame, TweenInfo.new(0.4, Enum.EasingStyle.Back), {Size = UDim2.fromOffset(W, H)}):Play()
		end
		Last[J] = Level
	end
end

function WantedUI.Start()
	Build()
	for _, J in ipairs(Heat.Order) do
		Player:GetAttributeChangedSignal("Wanted_" .. J):Connect(function() pcall(WantedUI.Refresh) end)
	end
	task.spawn(function()
		while true do
			local Ok, Err = pcall(WantedUI.Refresh)
			if not Ok and not WantedUI._Warned then WantedUI._Warned = true warn("[WantedUI] " .. tostring(Err)) end
			task.wait(0.25)
		end
	end)
end

return WantedUI

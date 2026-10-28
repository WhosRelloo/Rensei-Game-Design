-- E toggles Combat Mode. E is also Interact (controls doc): while an interact prompt on E is showing and
-- you are not in combat, E goes to the prompt instead (a prompt on another key, the takedown's N, doesn't take E).
-- The server owns the CombatMode attribute.

local ContextActionService = game:GetService("ContextActionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Players = game:GetService("Players")

local UIState = require(script.Parent.UIState)
local ClientActions = require(game:GetService("ReplicatedStorage").Modules.Managers.ClientActions)
local Styles = require(game:GetService("ReplicatedStorage").Modules.Data.Rensei.Styles)

local Player = Players.LocalPlayer
local Gui = UIState.Gui

local CombatModeUI = {}

local Shown = {} -- the interact prompts on E currently visible
local Indicator = nil

local function Enabled()
	local Character = Player.Character
	return Character ~= nil and Character:GetAttribute("CombatMode") == true
end

-- "COMBAT MODE", or "COMBAT MODE · BOXING" with a style other than the base one (Rensei.Styles)
local function TagText()
	local Id, S = Styles.Active(Player.Character)
	return (Id ~= Styles.Default and S) and ("COMBAT MODE · " .. S.Name:upper()) or "COMBAT MODE"
end

local function Refresh()
	if Indicator then
		Indicator.Visible = Enabled()
		Indicator.Text = TagText()
	end
	ContextActionService:SetTitle("RenseiCombatMode", Enabled() and "Calm" or "Fight")
end

local function MakeIndicator()
	-- Small "COMBAT MODE" tag above the vitals bars, built from the HUD's own label style.
	local Style = Gui.HUD.CashFrame.Display
	local L = Style:Clone()
	for _, K in ipairs(L:GetChildren()) do if not K:IsA("UIStroke") then K:Destroy() end end
	L.Name = "CombatModeTag"
	L.Text = "COMBAT MODE"
	L.TextColor3 = Color3.fromRGB(225, 70, 70)
	L.BackgroundTransparency = 1
	-- Lives in HUD, NOT inside HUD.Stats: that frame's UIListLayout would stack it as a bar.
	-- Positioned just above the vitals block; height-dominant aspect like the rest of the HUD.
	local Stats = Gui.HUD.Stats
	L.AnchorPoint = Vector2.new(0.5, 1)
	L.Position = UDim2.fromScale(0.5, Stats.Position.Y.Scale - Stats.Size.Y.Scale - 0.004)
	L.Size = UDim2.fromScale(0.3, 0.026)
	local AR = Instance.new("UIAspectRatioConstraint")
	AR.AspectRatio = 14 -- room for the style name
	AR.DominantAxis = Enum.DominantAxis.Height
	AR.Parent = L
	L.Visible = false
	L.Parent = Gui.HUD
	return L
end

-- an E prompt is showing (one destroyed while shown is dropped here)
local function EPromptShown()
	for Prompt in pairs(Shown) do
		if Prompt.Parent then return true end
		Shown[Prompt] = nil
	end
	return false
end

function CombatModeUI.Start()
	Indicator = MakeIndicator()

	-- only a prompt on E itself takes E from Combat Mode: a takedown prompt on its own key (N by default; rebindable,
	-- never to E, which Rensei.Settings reserves) must not stop E (assassinations spec A8, decision 17, 2026-10-25)
	ProximityPromptService.PromptShown:Connect(function(Prompt)
		if Prompt.KeyboardKeyCode == Enum.KeyCode.E then Shown[Prompt] = true end
	end)
	ProximityPromptService.PromptHidden:Connect(function(Prompt) Shown[Prompt] = nil end)

	ContextActionService:BindAction("RenseiCombatMode", function(_, State)
		if State ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
		if EPromptShown() and not UIState.InCombat() then
			return Enum.ContextActionResult.Pass -- interact takes priority
		end
		if Gui.Dialogue.Visible then return Enum.ContextActionResult.Pass end
		UIState.Request("CombatMode", not Enabled())
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.E) -- touch: the Fight / Calm button of Modules.UI.MobileControls
	ClientActions.Register("CombatMode", function(Began)
		if Began and not Gui.Dialogue.Visible then UIState.Request("CombatMode", not Enabled()) end
	end)

	local function Watch(Character)
		Character:GetAttributeChangedSignal("CombatMode"):Connect(function()
			Refresh()
			if Enabled() then
				-- crouch/slide is out-of-combat only
				local Crouch = Player.PlayerScripts:FindFirstChild("ClientHandler") and Player.PlayerScripts.ClientHandler:FindFirstChild("Crouch")
				if Crouch then task.spawn(pcall, function() local C = require(Crouch) C:OnEndClient() end) end
			end
			local _, S = Styles.Active(Character)
			local Name = (Styles.Active(Character) ~= Styles.Default and S) and (" · " .. S.Name) or ""
			UIState.Emit("Banner", {Text = Enabled() and ("Combat Mode" .. Name) or "Combat Mode Off"})
		end)
		Character:GetAttributeChangedSignal("Style"):Connect(Refresh)
		Character:GetAttributeChangedSignal("Weapon"):Connect(Refresh)
		Refresh()
	end
	if Player.Character then Watch(Player.Character) end
	Player.CharacterAdded:Connect(Watch)
end

return CombatModeUI

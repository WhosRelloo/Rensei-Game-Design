-- Boots the Rensei UI. Menu keys per the controls doc: ` Inventory, M Stats. Settings is not in
-- the doc and uses P; the Mastery skill tree uses K (free in the controls); the Journal uses J; admins get F2 (AdminUI). All menus are disabled in
-- combat (UIState). Touch buttons on mobile.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local UI = ReplicatedStorage.Modules.UI
local UIState = require(UI.UIState)

for _, Name in ipairs({"HUDUI", "PopupUI", "PartyUI", "DialogueUI", "InventoryUI", "SettingsUI", "CombatModeUI", "CooldownUI", "AlchemyUI", "MobileControls", "PromptUI", "ChatUI", "IntroCutscene", "MasteryUI", "CombatLogUI", "CompassUI", "TruthUI", "AutomailUI", "AdminUI", "JournalUI", "PuzzleClient", "MinigameUI", "EmoteWheelUI", "FieldNotesUI", "WantedUI", "StealthUI", "TakedownUI"}) do -- EmoteWheelUI: hold H; FieldNotesUI: one-time hints; WantedUI / StealthUI: Plan 2 HUD (Wanted badge, eye sigil); TakedownUI: the takedown prompt on N (assassinations)
	require(UI[Name]).Start()
end
require(UI.StatsUI).Initiate()
-- walk / run animations follow the character's real speed (the speed audit, 2026-10-18)
require(ReplicatedStorage.Modules.Managers.LocomotionSync).Start()
UIState.Start()
-- after every module has built its frames: hover/press springs, menu + popup motion
require(UI.UIMotion).Start(UIState.Gui)

local Menus = {
	{Action = "RenseiInventory", Menu = "Inventory", Key = Enum.KeyCode.Backquote, Title = "Bag"},
	{Action = "RenseiStats", Menu = "Stats", Key = Enum.KeyCode.M, Title = "Stats"},
	{Action = "RenseiSettings", Menu = "Settings", Key = Enum.KeyCode.P, Title = "Menu"},
	{Action = "RenseiMastery", Menu = "Mastery", Key = Enum.KeyCode.K, Title = "Mastery"},
}
for I, M in ipairs(Menus) do
	ContextActionService:BindAction(M.Action, function(_, State)
		if State == Enum.UserInputState.Begin then UIState.ToggleMenu(M.Menu) end
		return Enum.ContextActionResult.Sink
	end, true, M.Key)
	ContextActionService:SetTitle(M.Action, M.Title)
	ContextActionService:SetPosition(M.Action, UDim2.new(1, -70 - (I - 1) * 62, 0, 10))
end

script:SetAttribute("Started", os.time())

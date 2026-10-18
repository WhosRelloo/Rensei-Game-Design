-- UIState: the client's shared UI plumbing.
--   * Data:   last profile the server sent (DataRemote) + Changed signal
--   * On():   subscribe to server UI events (UIRemote)
--   * Menus:  one full-screen menu at a time, with the bg backdrop behind it
-- Presentation only. Nothing here decides game state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local Remotes = ReplicatedStorage.Remotes
local UIMotion = require(script.Parent.UIMotion)

local UIState = {}

UIState.Data = nil
UIState.Gui = Player:WaitForChild("PlayerGui"):WaitForChild("Uis")

local ChangedEvent = Instance.new("BindableEvent")
UIState.Changed = ChangedEvent.Event

local Handlers = {}

function UIState.On(Kind, Fn)
	Handlers[Kind] = Handlers[Kind] or {}
	table.insert(Handlers[Kind], Fn)
end

-- Fire a UI event locally (same handlers the server's UIRemote events use).
function UIState.Emit(Kind, Payload)
	for _, Fn in ipairs(Handlers[Kind] or {}) do
		task.spawn(Fn, Payload)
	end
end

function UIState.Request(Module, ...)
	Remotes.RequestRemote:FireServer(Module, ...)
end

-- ===== Menus =====
local Menus = {}
local OpenMenu = nil

-- AllowInCombat: the menu may open (and stays open) while InCombat (the admin panel)
function UIState.RegisterMenu(Name, Frame, OnOpen, AllowInCombat)
	Menus[Name] = {Frame = Frame, OnOpen = OnOpen, AllowInCombat = AllowInCombat}
	Frame.Visible = false
end

function UIState.IsOpen(Name)
	return OpenMenu == Name
end

function UIState.CloseMenus()
	if not OpenMenu then return end
	if Menus[OpenMenu] then UIMotion.Close(Menus[OpenMenu].Frame) end
	OpenMenu = nil
	UIMotion.Fade(UIState.Gui.bg, false, 0.18)
end

function UIState.InCombat()
	local Character = Player.Character
	return Character ~= nil and Character:GetAttribute("InCombat") == true
end

function UIState.ToggleMenu(Name)
	local Menu = Menus[Name]
	if not Menu then return end
	if OpenMenu ~= Name and UIState.InCombat() and not Menu.AllowInCombat then return end -- menus are disabled in combat
	-- (2026-10-18, Phase 9 finding 1) no menu opens over an NPC conversation: finish or leave it first
	local Talk = UIState.Gui:FindFirstChild("Dialogue")
	if OpenMenu ~= Name and Talk and Talk.Visible then return end
	if OpenMenu == Name then
		UIState.CloseMenus()
		return
	end
	-- switching straight between menus: the old one goes at once, the backdrop stays
	if OpenMenu and Menus[OpenMenu] then Menus[OpenMenu].Frame.Visible = false end
	local Backdrop = OpenMenu == nil
	OpenMenu = Name
	if Backdrop then UIMotion.Fade(UIState.Gui.bg, true, 0.22) end
	UIMotion.Open(Menu.Frame)
	if Menu.OnOpen then task.spawn(Menu.OnOpen) end
end

function UIState.Format(N)
	local S = tostring(math.floor(N))
	local Sign = ""
	if S:sub(1, 1) == "-" then Sign, S = "-", S:sub(2) end
	return Sign .. S:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

function UIState.Start()
	-- bg is a transparent backdrop with an edge vignette (authored in StarterGui.Uis.bg).
	UIState.Gui.bg.Visible = false
	Remotes.DataRemote.OnClientEvent:Connect(function(Profile)
		UIState.Data = Profile
		local Cache = Player.PlayerScripts:FindFirstChild("PlayerData")
		if Cache then require(Cache).Data = Profile end
		ChangedEvent:Fire(Profile)
	end)
	Remotes.UIRemote.OnClientEvent:Connect(function(Kind, Payload)
		for _, Fn in ipairs(Handlers[Kind] or {}) do
			task.spawn(Fn, Payload)
		end
	end)
	Remotes.RequestRemote:FireServer("Sync")

	-- Combat lock: close any open menu and turn off Interact prompts while in combat.
	local function WatchCombat(Character)
		local function Changed()
			local Fighting = Character:GetAttribute("InCombat") == true
			if Fighting and not (OpenMenu and Menus[OpenMenu] and Menus[OpenMenu].AllowInCombat) then UIState.CloseMenus() end
			pcall(function() game:GetService("ProximityPromptService").Enabled = not Fighting end)
		end
		Character:GetAttributeChangedSignal("InCombat"):Connect(Changed)
		Changed()
	end
	if Player.Character then WatchCombat(Player.Character) end
	Player.CharacterAdded:Connect(WatchCombat)

	-- Combat Mode (E): NPC Talk prompts (DialogueService) hide and an open conversation closes.
	-- Other prompts stay usable. The server refuses dialogue in Combat Mode too.
	local TalkHidden = false
	local function SetTalk(Prompt)
		if Prompt:IsA("ProximityPrompt") and Prompt.Name == "TalkPrompt" then
			Prompt.Enabled = not TalkHidden
		end
	end
	workspace.DescendantAdded:Connect(SetTalk)
	local function WatchCombatMode(Character)
		local function Changed()
			local On = Character:GetAttribute("CombatMode") == true
			if On == TalkHidden then return end
			TalkHidden = On
			if On then UIState.Request("Dialogue", "Close") end
			for _, D in ipairs(workspace:GetDescendants()) do SetTalk(D) end
		end
		Character:GetAttributeChangedSignal("CombatMode"):Connect(Changed)
		Changed()
	end
	if Player.Character then WatchCombatMode(Player.Character) end
	Player.CharacterAdded:Connect(WatchCombatMode)
end

return UIState

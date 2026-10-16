-- Emote wheel (Modules.UI.EmoteWheelUI): ("Play", EmoteId) / ("Stop"). The server owns the
-- check (Rensei.Emotes.Blocked: not in combat, not down, hands free, on the ground) and the
-- cooldown, sets the character attribute Emote = id while one runs, and plays it through
-- AnimationManager (the client's track replicates to everyone). Moving, jumping, attacking or
-- entering Combat Mode ends it (the client asks for "Stop"; Combat Mode is also checked here).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Emotes = require(ReplicatedStorage.Modules.Data.Rensei.Emotes)
local AnimationManager = require(ReplicatedStorage.Modules.Managers.AnimationManager)
local UIService = require(game:GetService("ServerScriptService").UIService)

local LastStart = {} -- [Player] = os.clock() (plain table, cleared on leave)
Players.PlayerRemoving:Connect(function(Player) LastStart[Player] = nil end)

local function StopCurrent(Character)
	local Current = Character:GetAttribute("Emote")
	local Def = Current and Emotes.List[Current]
	if Def then AnimationManager.Stop(Character, Def.Anim) end
	Character:SetAttribute("Emote", nil)
end

return function(Player, Action, Id)
	local Character = Player.Character
	if not Character then return end
	if Action == "Stop" then
		StopCurrent(Character)
		return
	end
	if Action ~= "Play" or type(Id) ~= "string" then return end
	local Def = Emotes.List[Id]
	if not Def then return end
	local Why = Emotes.Blocked(Character)
	if Why then
		if Why ~= "" then UIService.Notify(Player, "Toast", {Text = Why}) end
		return
	end
	local Now = os.clock()
	if LastStart[Player] and Now - LastStart[Player] < Emotes.Cooldown then return end
	LastStart[Player] = Now
	StopCurrent(Character)
	Character:SetAttribute("Emote", Id)
	AnimationManager.Play(Character, Def.Anim, {Looped = Def.Looped, Priority = Enum.AnimationPriority.Action})
	-- Combat Mode (or being hit, which turns it on) always ends an emote
	local Conn
	Conn = Character:GetAttributeChangedSignal("CombatMode"):Connect(function()
		if Character:GetAttribute("CombatMode") and Character:GetAttribute("Emote") == Id then StopCurrent(Character) end
		Conn:Disconnect()
	end)
	Character:GetAttributeChangedSignal("Emote"):Once(function() if Conn.Connected then Conn:Disconnect() end end)
end

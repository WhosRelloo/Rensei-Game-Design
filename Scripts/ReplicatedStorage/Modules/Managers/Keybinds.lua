-- Client-side rebindable keys (Dash, Block, LockTarget, WeaponSkill, Aim = guns' shooting mode, Takedown = the takedown
-- prompt, 2026-10-28). Settings writes them; input code reads them and listens to Changed to rebind. A key name may be
-- "Unknown": Rensei.Settings.Resolve leaves an action free when it has no key of its own (Get then returns
-- Enum.KeyCode.Unknown).
local Keybinds = {}

Keybinds.Keys = {Dash = "Q", Block = "F", LockTarget = "G", WeaponSkill = "T", Aim = "Y", Takedown = "N"}

local ChangedEvent = Instance.new("BindableEvent")
Keybinds.Changed = ChangedEvent.Event

function Keybinds.Get(Name)
	return Enum.KeyCode[Keybinds.Keys[Name]]
end

function Keybinds.Set(Name, KeyName)
	if Keybinds.Keys[Name] == nil or Keybinds.Keys[Name] == KeyName then return end
	Keybinds.Keys[Name] = KeyName
	ChangedEvent:Fire(Name, KeyName)
end

return Keybinds

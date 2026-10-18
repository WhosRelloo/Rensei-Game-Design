-- Client-side rebindable keys (Dash, Block, LockTarget, WeaponSkill, Aim = guns' shooting mode). Settings writes them; input code reads
-- them and listens to Changed to rebind.
local Keybinds = {}

Keybinds.Keys = {Dash = "Q", Block = "F", LockTarget = "G", WeaponSkill = "T", Aim = "Y"}

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

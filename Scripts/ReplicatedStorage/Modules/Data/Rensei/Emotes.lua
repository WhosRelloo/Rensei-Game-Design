-- Emotes for the emote wheel (Modules.UI.EmoteWheelUI; the server checks them in Requests.Emote).
-- Animations are the Animation ID's sheet entries (Assets.Animations.Shared.Emotes / Misc /
-- NPCIdles). Page names and display names are PLACEHOLDERS until the owner names them.
--   List[Id] = {Name = wheel label, Anim = animation name, Looped = keeps going until you move}
--   Pages = the wheel's rings, 8 slots each, in clockwise order from the top.

local Emotes = {}

Emotes.List = {
	-- Composure: quiet gestures (an alchemist at rest)
	bow = {Name = "Bow", Anim = "Misc_Bow", Looped = false},
	meditate = {Name = "Meditate", Anim = "Misc_Meditate", Looped = true},
	lean = {Name = "Lean", Anim = "Emote_LeanIdle", Looped = true},
	kneel = {Name = "Kneel", Anim = "NPC_Kneel", Looped = true},
	sit = {Name = "Sit", Anim = "NPC_Sit3", Looped = true},
	sleep = {Name = "Rest", Anim = "NPC_Sleep2", Looped = true},
	pushups = {Name = "Pushups", Anim = "Misc_Pushups", Looped = true},
	laugh = {Name = "Laugh", Anim = "Emote_LoudLaugh", Looped = false},
	-- Revelry: dances
	aero_step = {Name = "Aero Step", Anim = "Emote_AeroStep", Looped = true},
	anthony = {Name = "Anthony", Anim = "Emote_Anthony", Looped = true},
	clean_groove = {Name = "Clean Groove", Anim = "Emote_CleanGroove", Looped = true},
	default_dance = {Name = "Dance", Anim = "Emote_DefaultDance", Looped = true},
	floss = {Name = "Floss", Anim = "Emote_Floss", Looped = true},
	kazotsky = {Name = "Kazotsky Kick", Anim = "Emote_KazotskyKick", Looped = true},
	peter_parker = {Name = "Peter Parker", Anim = "Emote_PeterParker", Looped = true},
	thriller = {Name = "Thriller", Anim = "Emote_Thriller", Looped = true},
}

Emotes.Pages = {
	{Name = "Composure", Emotes = {"bow", "meditate", "lean", "kneel", "sit", "sleep", "pushups", "laugh"}},
	{Name = "Revelry", Emotes = {"aero_step", "anthony", "clean_groove", "default_dance", "floss", "kazotsky", "peter_parker", "thriller"}},
}

Emotes.Key = Enum.KeyCode.H -- hold to open the wheel (free in the controls doc)
Emotes.Cooldown = 0.75 -- seconds between emotes (PROPOSAL)

-- Why an emote can't start right now (nil = it can). Shared by the wheel (to grey it out) and the
-- server (the real check).
function Emotes.Blocked(Character)
	local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid or Humanoid.Health <= 0 then return "" end
	if Character:GetAttribute("CombatMode") or Character:GetAttribute("InCombat") then return "Not in combat" end
	if Character:GetAttribute("Knocked") or Character:GetAttribute("CarriedBy") or Character:GetAttribute("GrippedBy") then return "Not while down" end
	if Character:GetAttribute("Carrying") or Character:GetAttribute("Gripping") then return "Your hands are full" end
	if Character:GetAttribute("CombatState") ~= nil then return "Not while attacking" end
	if Humanoid.FloorMaterial == Enum.Material.Air then return "Not in the air" end
	return nil
end

return Emotes

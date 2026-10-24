-- Health (Rensei): replaces Roblox's default character "Health" regen script. A Script named Health in
-- StarterCharacterScripts stops Roblox inserting its own copy (only player characters get it; NPCs never did).
-- Owner 2026-10-23: "Players shouldn't be able to regen health until out of combat."
--   * Same rate as Roblox's default: 1% of MaxHealth per second, ticked once a second. Drowning
--     (TuningConfig.Swim.DrownFraction, 6%/s through DownedManager.Damage, which does not mark combat)
--     is tuned against this rate, so it is unchanged.
--   * No regen while in combat: the server-written character attributes InCombat / CombatUntil
--     (WorldService.MarkCombat: 12 s after dealing or taking a hit), nor for REGEN_DELAY seconds after
--     combat ends, nor while Knocked (DownedManager: they get RecoverHealth when they stand up).
-- Runs on the server (a Script parented into the character).

local Character = script.Parent
local Humanoid = Character:WaitForChild("Humanoid")

local REGEN_RATE = 1 / 100 -- fraction of MaxHealth per second (Roblox's default)
local REGEN_STEP = 1 -- seconds between regen ticks (Roblox's default)
local REGEN_DELAY = 2 -- PROPOSAL: seconds after combat ends before regen resumes

local function CanRegen()
	if Character:GetAttribute("InCombat") == true then return false end
	if Character:GetAttribute("Knocked") == true then return false end
	local Until = Character:GetAttribute("CombatUntil")
	if typeof(Until) == "number" and workspace:GetServerTimeNow() < Until + REGEN_DELAY then return false end
	return true
end

while Character.Parent do
	while Humanoid.Health > 0 and Humanoid.Health < Humanoid.MaxHealth do
		local Dt = task.wait(REGEN_STEP)
		if Humanoid.Health > 0 and CanRegen() then
			Humanoid.Health = math.min(Humanoid.Health + Dt * REGEN_RATE * Humanoid.MaxHealth, Humanoid.MaxHealth)
		end
	end
	Humanoid.HealthChanged:Wait()
end

-- HostageKit (hostages plan Task 4, 2026-10-27; pre-flight P16): the hostage suites' shared fixture. Required, never
-- copied. Run in the game VM (LMRunSuite), never in Edit. Task 4 gives it Guard only; Task 5 extends it. It builds on
-- TakedownKit (its floor, Guard, Spawn, Deed and the cases' helpers), required, never re-implemented.
--   * Kit.Guard(Body): every hostage case runs inside it. It REFUSES, with an error and before anything runs or mutates,
--     unless both hold:
--       - the hook's save snapshot is armed for the test player (TakedownKit.SnapshotArmed: LMTestHook installed and
--         ServerStorage.LMSnapTaken = their name), so the hook's restore takes back whatever a case credits or records;
--       - DataManager.IsNoSave() is true, asked here in the game VM (never the ReplicatedStorage attribute): the session
--         loaded a mock copy of the profile (the Studio-only TestNoSave switch), so nothing a case does reaches the save.
--     Then TakedownKit.Guard (the y 3000 floor, the clean-up, the character put back) around Body, with (pre-flight P3)
--     today's count of the eight hostage deeds and executed_bandit reset first (TakedownKit.Deed), so a deed's daily cap
--     never decides a case. Afterwards (even when Body failed), the hostage clean-up: Holding and HeldBy cleared on the
--     player's character, a knock a case left on the player ended (DownedManager.Recover), and the player's Health,
--     KnockedTime, SecondWindUsed and SecondWindActive put back as they were. Re-raises Body's error.
--   * Kit._NoSave: the function Guard asks, DataManager.IsNoSave. A test swaps it (and puts it back) to prove the refusal,
--     so the data layer itself is never touched (as pre-flight P24 rules for HostageService).
local SSS = game:GetService("ServerScriptService")
local DownedManager = require(game:GetService("ReplicatedStorage").Modules.Managers.DownedManager)
local DataManager = require(SSS:WaitForChild("CharacterHandler"):WaitForChild("DataManager"))
local TakedownKit = require(script.Parent.TakedownKit)

local Kit = {}

Kit._NoSave = DataManager.IsNoSave

-- the eight hostage deeds (Rensei.Deeds, hostages Task 2) and the grip's executed_bandit (pre-flight P3), written by hand
Kit.DEEDS = {"took_hostage", "attempted_hostage", "released_hostage", "killed_hostage", "used_human_shield",
	"paid_ransom", "took_ransom", "turned_in_fugitive", "executed_bandit"}

local PUT_BACK = {"KnockedTime", "SecondWindUsed", "SecondWindActive"} -- the player's knock attributes a case may set

function Kit.Guard(Body)
	if not TakedownKit.SnapshotArmed() then
		error("HostageKit.Guard: the hook's save snapshot isn't armed (ServerStorage.LMSnapTaken, LMTestHook); "
			.. "refusing a case that can credit or record on the profile", 0)
	end
	local Ok, NoSave = pcall(Kit._NoSave)
	if not Ok or NoSave ~= true then
		error("HostageKit.Guard: DataManager.IsNoSave() isn't true in this VM (" .. tostring(NoSave) .. "); "
			.. "refusing a case outside a TestNoSave session", 0)
	end
	TakedownKit.Guard(function()
		local C = TakedownKit.Player().Character
		local H = C:FindFirstChildOfClass("Humanoid")
		local Was = {Health = H.Health}
		for _, K in ipairs(PUT_BACK) do Was[K] = C:GetAttribute(K) end
		for _, Id in ipairs(Kit.DEEDS) do TakedownKit.Deed(Id) end
		local BodyOk, Err = pcall(Body)
		-- the hostage clean-up, each step on its own so one failing never skips the rest
		local Steps = {
			function() C:SetAttribute("Holding", nil) C:SetAttribute("HeldBy", nil) end,
			function() if DownedManager.IsKnocked(C) then DownedManager.Recover(C) end end,
			function()
				for _, K in ipairs(PUT_BACK) do C:SetAttribute(K, Was[K]) end
				if H.Parent and H.Health > 0 then H.Health = Was.Health end
			end,
		}
		for _, Step in ipairs(Steps) do
			local StepOk, StepErr = pcall(Step)
			if not StepOk then warn("HostageKit.Guard clean-up:", StepErr) end
		end
		if not BodyOk then error(Err, 0) end
	end)
end

return Kit

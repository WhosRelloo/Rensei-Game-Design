-- Play_GunReload (gun rework Task 7, 2026-10-25): the reload, in the Play VM (LMRunSuite). Every case uses GunKit's
-- shooters (NPC rigs) at GunKit.Spot(), inside SmokeKit.Guarded with GunKit.Clean as After, after GunKit.Unequip
-- (Ruling 4c). Every expected number is worked by hand below, as a constant; nothing is read from the code under test
-- to choose an input or an answer.
--   Revolver (TuningConfig PROPOSAL, 2026-10-25, Task 3): Magazine 6, Reload 1.8 s. A GunKit shooter has no Marksman
--   ranks (SkillMods GunReload x 1), so its reload takes 1.8 s.
--   The interrupt rule (PROPOSAL): things done to you (a WCS Stun, Knocked, a grip, a carry, the water) cancel a reload,
--   which starts again once they end; your own actions (an attack) don't.
--   The slot (Art/Studio/Guns/reload_slot.lua, applied in Edit before Play): Assets.Animations.Weapons.Guns.Guns_Reload
--   holding the owner's id 97563934064498 (Task 1: it loads, 4.07 s, Rensei group).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LogService = game:GetService("LogService")
local SmokeKit = require(script.Parent.SmokeKit)
local GunKit = require(script.Parent.GunKit)
local WCS = require(ReplicatedStorage.Modules.Framework.WCS)
local WeaponManager = require(ReplicatedStorage.Modules.Managers.WeaponManager)
local AnimationManager = require(ReplicatedStorage.Modules.Managers.AnimationManager)
local AttackRunner = require(ReplicatedStorage.Modules.Managers.AttackRunner)
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)
local Stun = require(ReplicatedStorage.Modules.Skills.States.Stun)
local Player = game.Players:GetPlayers()[1]

local AHEAD = Vector3.new(0, 0, -1) -- every shooter faces -Z; its shots go straight ahead at nothing
local MAG = 6 -- the Revolver's magazine
local RELOAD = 1.8 -- the Revolver's reload, seconds
local RELOAD_EPS = 0.05 -- EmptyReloadsInTime's slack
local AFTER = 1.9 -- seconds after a reload starts by which it has finished (RELOAD + 0.1)
local STUN_AT, STUN_FOR = 0.5, 0.4 -- StunCancelsAndRestarts: the stun lands 0.5 s into the reload and lasts 0.4 s
local RESTART_EPS = 0.1 -- the restarted reload ends RELOAD after the stun's end, +- this
local WHIP_AT = 0.3 -- OwnActionsDoNotCancel: the whip starts 0.3 s into the reload
local TOPUP_SHOTS = 2 -- TopUpOnModeOff: 2 shots leave 4 rounds
local STARTS_WITHIN = 0.2 -- seconds for a reload to start after the event that starts it
local SLOT = "Guns_Reload" -- TuningConfig Weapons.Guns.Reload.Anim (the slot's name)
local OWNER_ID = "rbxassetid://97563934064498" -- the owner's reload animation
local PLAYS_WITHIN = 0.3 -- seconds for the reload's track to be playing
local NOT_FOUND = "Animation not found"

local function Guard(Body, After)
	SmokeKit.Guarded(Player, Body, function() GunKit.Unequip(Player) end, function()
		local Ok, Err = true, nil
		if After then Ok, Err = pcall(After) end
		GunKit.Clean()
		if not Ok then error(Err, 0) end
	end)
end

-- a Revolver shooter at the spot facing -Z
local function Shooter()
	return GunKit.Shooter(Vector3.zero, GunKit.Spot() + AHEAD * 10, "Revolver")
end

-- N shots straight ahead (at nothing); each must spend a round
local function Shoot(T, S, N)
	for I = 1, N do
		local Was = S:GetAttribute("Ammo")
		GunKit.Shot(S, AHEAD)
		T.Eq(S:GetAttribute("Ammo"), Was - 1, "shot " .. I .. " spends a round")
	end
end

-- one server frame: the next Heartbeat, then the end of that resumption cycle (every Heartbeat waiter has run)
local function Frame()
	RunService.Heartbeat:Wait()
	local Me = coroutine.running()
	task.defer(Me)
	coroutine.yield()
end

-- waits until Fn() is truthy or Within seconds pass; returns Fn()'s last value
local function Until(Fn, Within)
	local T0 = os.clock()
	local V = Fn()
	while not V and os.clock() - T0 < Within do
		task.wait()
		V = Fn()
	end
	return V
end

-- the slot in this (Play) world
local function Slot()
	for _, A in ipairs(ReplicatedStorage.Assets.Animations:GetDescendants()) do
		if A:IsA("Animation") and A.Name == SLOT then return A end
	end
end

-- wraps AnimationManager.Play (Play only; the case removes it): counts SLOT calls for Rig. Returns Count(), Remove().
local function CountSlotPlays(Rig)
	local Orig = AnimationManager.Play
	local N = 0
	AnimationManager.Play = function(Character, Name, ...)
		if Character == Rig and Name == SLOT then N += 1 end
		return Orig(Character, Name, ...)
	end
	return function() return N end, function() AnimationManager.Play = Orig end
end

local function NotFoundLines()
	local N = 0
	for _, E in ipairs(LogService:GetLogHistory()) do
		if string.find(E.message, NOT_FOUND, 1, true) then N += 1 end
	end
	return N
end

return {
	-- guard (the reload time is 1.8 since Task 3): an empty Revolver reloads in 1.8 s
	EmptyReloadsInTime = function(T)
		Guard(function()
			local S = Shooter()
			GunKit.Settle()
			Shoot(T, S, MAG)
			local Left = (S:GetAttribute("ReloadingUntil") or 0) - workspace:GetServerTimeNow()
			T.Near(Left, RELOAD, RELOAD_EPS, "ReloadingUntil - now after the last round")
			task.wait(AFTER)
			T.Eq(S:GetAttribute("Ammo"), MAG, "Ammo " .. AFTER .. " s later")
			T.Eq(S:GetAttribute("ReloadingUntil"), nil, "ReloadingUntil once the reload is done")
		end)
	end,

	-- RED today: a stun leaves the reload running (task.delay); now it cancels it within a frame, and the reload starts
	-- again when the stun ends
	StunCancelsAndRestarts = function(T)
		Guard(function()
			local S = Shooter()
			GunKit.Settle()
			Shoot(T, S, MAG)
			T.True(S:GetAttribute("ReloadingUntil") ~= nil, "the reload started on the last round")
			task.wait(STUN_AT)
			local WC = WCS.Character.GetCharacterFromInstance(S)
			T.True(WC ~= nil, "the shooter's WCS character")
			Stun.new(WC):Start(STUN_FOR)
			local StunEnd = workspace:GetServerTimeNow() + STUN_FOR
			Frame()
			T.Eq(S:GetAttribute("ReloadingUntil"), nil, "ReloadingUntil one frame after the stun")
			T.Eq(S:GetAttribute("Ammo"), 0, "Ammo while stunned")
			local NewUntil = Until(function() return S:GetAttribute("ReloadingUntil") end, STUN_FOR + STARTS_WITHIN)
			T.True(NewUntil ~= nil, "a new reload after the stun")
			if not NewUntil then return end
			T.Near(NewUntil - StunEnd, RELOAD, RESTART_EPS, "the new ReloadingUntil - the stun's end")
			T.Eq(S:GetAttribute("Ammo"), 0, "Ammo as the new reload starts")
			task.wait(math.max(0, NewUntil - workspace:GetServerTimeNow() - RESTART_EPS * 2))
			T.Eq(S:GetAttribute("Ammo"), 0, "Ammo just before the new reload ends")
			task.wait(RESTART_EPS * 4)
			T.Eq(S:GetAttribute("Ammo"), MAG, "Ammo after the new reload")
		end)
	end,

	-- guard: your own action (the whip, Guns_Light1 through AttackRunner) doesn't touch the reload
	OwnActionsDoNotCancel = function(T)
		Guard(function()
			local S = Shooter()
			GunKit.Settle()
			Shoot(T, S, MAG)
			local Started = os.clock()
			local Until0 = S:GetAttribute("ReloadingUntil")
			T.True(Until0 ~= nil, "the reload started on the last round")
			task.wait(WHIP_AT)
			local WC = WCS.Character.GetCharacterFromInstance(S)
			local Outcome
			task.spawn(function()
				Outcome = AttackRunner.Run(WC, Tuning.Weapons.Guns.Light.Hits[1], "Guns_Light1", {Feintable = true})
			end)
			Frame()
			T.True(S:GetAttribute("CombatState") ~= nil, "the whip is running")
			T.Eq(S:GetAttribute("ReloadingUntil"), Until0, "ReloadingUntil while the whip runs")
			Until(function() return Outcome ~= nil end, AFTER)
			T.True(Outcome ~= nil, "the whip finished")
			T.Eq(S:GetAttribute("ReloadingUntil"), Until0, "ReloadingUntil after the whip")
			task.wait(math.max(0, AFTER - (os.clock() - Started)))
			T.Eq(S:GetAttribute("Ammo"), MAG, "Ammo " .. AFTER .. " s after the reload started")
		end)
	end,

	-- RED today: nothing listens; turning shooting mode off now tops up a part-used magazine
	TopUpOnModeOff = function(T)
		Guard(function()
			local S = Shooter()
			GunKit.Settle()
			Shoot(T, S, TOPUP_SHOTS)
			T.Eq(S:GetAttribute("Ammo"), MAG - TOPUP_SHOTS, "Ammo after " .. TOPUP_SHOTS .. " shots")
			S:SetAttribute("ShootingMode", true)
			task.wait(0.1)
			T.Eq(S:GetAttribute("ReloadingUntil"), nil, "no reload while shooting mode is on")
			S:SetAttribute("ShootingMode", nil)
			local Started = Until(function() return S:GetAttribute("ReloadingUntil") end, STARTS_WITHIN)
			T.True(Started ~= nil, "a reload " .. STARTS_WITHIN .. " s after shooting mode turned off")
			task.wait(AFTER)
			T.Eq(S:GetAttribute("Ammo"), MAG, "Ammo " .. AFTER .. " s later")
		end)
	end,

	-- RED today: nothing plays the slot. With the slot as applied (the owner's id), one reload plays it once.
	FilledSlotPlays = function(T)
		local Remove
		Guard(function()
			local A = Slot()
			T.True(A ~= nil, "the slot " .. SLOT .. " exists (reload_slot.lua applied)")
			T.Eq(A.AnimationId, OWNER_ID, "the slot holds the owner's id")
			local S = Shooter()
			GunKit.Settle()
			local Count
			Count, Remove = CountSlotPlays(S)
			Shoot(T, S, MAG)
			local Track = Until(function()
				for _, Tr in ipairs(S.Humanoid.Animator:GetPlayingAnimationTracks()) do
					if Tr.Animation and Tr.Animation.AnimationId == OWNER_ID then return Tr end
				end
			end, PLAYS_WITHIN)
			T.Eq(Count(), 1, "AnimationManager.Play(" .. SLOT .. ") calls during the reload")
			T.True(Track ~= nil, "a playing track with the owner's id on the shooter")
			task.wait(AFTER)
			T.Eq(Count(), 1, "calls after the reload")
			T.Eq(S:GetAttribute("Ammo"), MAG, "Ammo after the reload")
		end, function()
			if Remove then Remove() end
		end)
	end,

	-- the control for FilledSlotPlays (it can't fail alone: today's code also plays nothing): an empty slot plays nothing
	-- and logs no "Animation not found"
	EmptySlotPlaysNothing = function(T)
		local Remove
		local A = Slot()
		Guard(function()
			T.True(A ~= nil, "the slot " .. SLOT .. " exists (reload_slot.lua applied)")
			A.AnimationId = "" -- the Play world is a copy; After puts it back
			local S = Shooter()
			GunKit.Settle()
			local Count
			Count, Remove = CountSlotPlays(S)
			local Before = NotFoundLines()
			Shoot(T, S, MAG)
			T.True(S:GetAttribute("ReloadingUntil") ~= nil, "the reload started")
			task.wait(PLAYS_WITHIN)
			T.Eq(Count(), 0, "AnimationManager.Play(" .. SLOT .. ") calls with an empty slot")
			T.Eq(NotFoundLines() - Before, 0, "new '" .. NOT_FOUND .. "' log lines")
			task.wait(AFTER - PLAYS_WITHIN)
			T.Eq(S:GetAttribute("Ammo"), MAG, "Ammo after the reload (the reload still works)")
		end, function()
			if Remove then Remove() end
			if A then A.AnimationId = OWNER_ID end
		end)
	end,
}

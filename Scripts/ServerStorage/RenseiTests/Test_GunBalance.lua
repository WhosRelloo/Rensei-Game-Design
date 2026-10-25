-- Test_GunBalance (gun rework 2026-10-25, Task 3): the gun numbers in TuningConfig.Weapons.Guns, Fan the Hammer through
-- WeaponManager.Resolve, and the shot meter. The bands below are the plan's PROPOSAL targets, fixed here as constants;
-- nothing is read from the thing under test to choose them. Runs in the Play VM (LMRunSuite).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)
local GunAim = require(ReplicatedStorage.Modules.Data.Rensei.GunAim)
local WeaponManager = require(ReplicatedStorage.Modules.Managers.WeaponManager)

local BURST_MAX = 37 -- PROPOSAL: damage a second while the magazine lasts (melee lights are 30-37)
local SUSTAINED = {20, 26} -- PROPOSAL: damage a second with reloads
local FAN = 12 -- PROPOSAL: Fan the Hammer's damage a shot, the same for every gun
local ANIM_LENGTH = 4.07 -- the owner's reload 97563934064498, measured in Task 1 (2026-10-25)
local FAN_LAST_HIT = 0.42 -- Fan the Hammer's last HitTime after its request
local GUN_NAMES = {"Revolver", "Renetti", "Forge Tac", "Sykov"} -- the four guns (ItemData), so no loop passes empty
-- Worked by hand for the plan's numbers (Shots[1]: Startup 0.12 + Active 0.02 + the gun's Recovery):
--   Revolver  20 / 0.56 = 35.7 burst, 120 / (6 * 0.56 + 1.8) = 23.3 sustained
--   Renetti   10 / 0.34 = 29.4,       120 / (12 * 0.34 + 1.6) = 21.1
--   Forge Tac 26 / 0.76 = 34.2,       130 / (5 * 0.76 + 1.8)  = 23.2
--   Sykov     13 / 0.38 = 34.2,       130 / (10 * 0.38 + 1.7) = 23.6
-- Today's (2026-10-18) numbers fail: Revolver 40.0 burst; Forge Tac 40.7 burst, 27.4 sustained.

local function Guns() return Tuning.Weapons.Guns end

-- A gun's Range, or the shot's (Shots[1].Range, 90) when the gun has none.
local function RangeOf(Stats) return Stats.Range or Guns().Shots[1].Range end

local function Items(T)
	local G = Guns()
	for _, Name in ipairs(GUN_NAMES) do T.True(G.Items[Name] ~= nil, "Guns.Items." .. Name .. " exists") end
	local N = 0
	for _ in pairs(G.Items) do N += 1 end
	T.Eq(N, #GUN_NAMES, "the number of guns")
	return G.Items
end

return {
	BurstAndSustainedInBand = function(T)
		local I, Bad = Items(T), {}
		for _, Name in ipairs(GUN_NAMES) do
			local Burst, Sustained = GunAim.DPS(Guns().Shots[1], I[Name])
			if Burst > BURST_MAX or Sustained < SUSTAINED[1] or Sustained > SUSTAINED[2] then
				table.insert(Bad, string.format("%s %.1f / %.1f", Name, Burst, Sustained))
			end
		end
		T.Eq(table.concat(Bad, "; "), "", "guns outside burst <= 37, sustained 20-26")
	end,

	Identities = function(T)
		local I = Items(T)
		local Shot = Guns().Shots[1]
		for _, Name in ipairs(GUN_NAMES) do
			if Name ~= "Forge Tac" then
				T.True(RangeOf(I["Forge Tac"]) > RangeOf(I[Name]),
					string.format("Forge Tac's range %s strictly over %s's %s", RangeOf(I["Forge Tac"]), Name, RangeOf(I[Name])))
			end
			if Name ~= "Renetti" then
				T.True(GunAim.Interval(Shot, I.Renetti) < GunAim.Interval(Shot, I[Name]), "Renetti's interval smallest vs " .. Name)
			end
			if Name ~= "Revolver" then
				local A, B = GunAim.DPS(Shot, I.Revolver), GunAim.DPS(Shot, I[Name])
				T.True(A > B, string.format("Revolver's burst %.1f strictly over %s's %.1f", A, Name, B))
			end
		end
	end,

	NoGunDominates = function(T)
		local I = Items(T)
		for _, A in ipairs(GUN_NAMES) do
			for _, B in ipairs(GUN_NAMES) do
				if A ~= B then
					local SA, SB = I[A], I[B]
					local RA, RB = RangeOf(SA), RangeOf(SB)
					local AtLeast = SA.Damage >= SB.Damage and SA.Magazine >= SB.Magazine and RA >= RB and SA.Reload <= SB.Reload
					local Strict = SA.Damage > SB.Damage or SA.Magazine > SB.Magazine or RA > RB or SA.Reload < SB.Reload
					T.True(not (AtLeast and Strict), A .. " dominates " .. B)
				end
			end
		end
	end,

	FanSameForEveryGun = function(T)
		Items(T)
		for _, Name in ipairs(GUN_NAMES) do
			local Fake = {GetAttribute = function(_, K) return ({Weapon = "Guns", WeaponItem = Name})[K] end}
			T.Eq(WeaponManager.Resolve(Fake, Guns().Skill).Damage, FAN, "Fan the Hammer's damage with the " .. Name)
		end
	end,

	ShotMeter = function(T)
		T.Eq(Tuning.Meter.OnShotHit, 2, "Meter.OnShotHit")
		T.Eq(Tuning.Meter.OnLightHit, 4, "Meter.OnLightHit")
	end,

	ShotsNoWhiff = function(T)
		local Shots = Guns().Shots
		T.Eq(#Shots, 4, "four shots")
		for I, S in ipairs(Shots) do T.Eq(S.NoWhiffPenalty, true, "Shots[" .. I .. "].NoWhiffPenalty") end
	end,

	AimFreshCoversFan = function(T)
		local Aim = Guns().Aim
		T.True(Aim ~= nil, "Guns.Aim exists")
		T.True(type(Aim.AimFresh) == "number" and Aim.AimFresh >= FAN_LAST_HIT + 0.2,
			"AimFresh " .. tostring(Aim.AimFresh) .. " >= " .. (FAN_LAST_HIT + 0.2))
	end,

	ReloadAnimLength = function(T)
		local Reload = Guns().Reload
		T.True(Reload ~= nil, "Guns.Reload exists")
		if ANIM_LENGTH == nil then
			T.Eq(Reload.AnimLength, nil, "AnimLength")
		else
			T.True(type(Reload.AnimLength) == "number", "AnimLength is a number")
			T.Near(Reload.AnimLength, ANIM_LENGTH, 0.01, "AnimLength")
		end
	end,
}

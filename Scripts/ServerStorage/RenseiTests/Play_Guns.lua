-- Play_Guns (gun rework Task 5, 2026-10-25): the server shot path, in the Play VM (LMRunSuite). Every case uses GunKit's
-- rigs at GunKit.Spot(), inside SmokeKit.Guarded with GunKit.Clean as After, after GunKit.Unequip (Ruling 4c).
-- Shooters stand at the spot facing -Z; targets stand straight ahead on the same floor. Every expected number is worked by
-- hand below, as a constant; nothing is read from the code under test to choose a spot or an answer.
--   Revolver (TuningConfig PROPOSAL, 2026-10-25): Damage 20, Range 70, Falloff {Start 20, End 70, Min 0.5}, Magazine 6.
--   A target 45 studs ahead: the shot meets its box face 44 studs out (the box is 2 deep), so the falloff is
--   1 - 0.5 * (44 - 20) / (70 - 20) = 0.76 and the damage 20 * 0.76 = 15.2 -- 15 +- 0.5 (20 x 0.75 at the root's 45).
--   Today's class falloff {25, 90, 0.5} would give 1 - 0.5 * (44 - 25) / 65 = 0.854 -> 17.1 (outside the band).
--   Weapon Mastery (SkillTree AR_Mastery): 2 ranks x 0.25 = Mod_WeaponPassive 0.5 at most; no ranks = no attribute.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SmokeKit = require(script.Parent.SmokeKit)
local GunKit = require(script.Parent.GunKit)
local WCS = require(ReplicatedStorage.Modules.Framework.WCS)
local WeaponManager = require(ReplicatedStorage.Modules.Managers.WeaponManager)
local States = ReplicatedStorage.Modules.Skills.States
local Stun = require(States.Stun)
local Blocking = require(States.Blocking)
local Player = game.Players:GetPlayers()[1]

local MUZZLE_UP = Vector3.new(0, 1.5, 0) -- the shot leaves 1.5 above the root (the muzzle, since 2026-10-17)
local AHEAD = Vector3.new(0, 0, -1) -- every shooter faces -Z
local FALLOFF_DAMAGE, FALLOFF_EPS = 15, 0.5 -- the Revolver at 45 studs (worked above)
local MASTERY_MAX = 0.5 -- Mod_WeaponPassive at AR_Mastery's 2 ranks (worked above)
local REVOLVER_MAG = 6
local MODE_ENDS_WITHIN = 0.2 -- seconds

local function Guard(Body, After)
	SmokeKit.Guarded(Player, Body, function() GunKit.Unequip(Player) end, function()
		if After then pcall(After) end
		GunKit.Clean()
	end)
end

-- a shooter at the spot facing -Z, with Item
local function Shooter(Item)
	return GunKit.Shooter(Vector3.zero, GunKit.Spot() + AHEAD * 10, Item)
end

-- a target Dist studs straight ahead of the shooter
local function Target(Dist, Name)
	return GunKit.Dummy(AHEAD * Dist, Name or ("GunKit_Target" .. Dist))
end

-- from the shooter's muzzle to the target's root
local function AimAt(Shooter, Target)
	return (Target.HumanoidRootPart.Position - (Shooter.HumanoidRootPart.Position + MUZZLE_UP)).Unit
end

-- a used target stepped out of the lane (still the kit's; Clean removes it)
local function Aside(M)
	M:PivotTo(M:GetPivot() + Vector3.new(40, 0, 0))
end

local function Stunned(M)
	local WC = WCS.Character.GetCharacterFromInstance(M)
	return WC ~= nil and WC:HasStatusEffects({Stun})
end

-- one shot at Target: the results, and the Health it lost
local function ShootAt(Shooter, Target)
	local Results, Lost = GunKit.Shot(Shooter, AimAt(Shooter, Target))
	return Results, Lost[Target] or 0
end

return {
	-- guard: the plain hit still lands
	HitsWhatItAimsAt = function(T)
		Guard(function()
			local S = Shooter("Revolver")
			local Tg = Target(30)
			GunKit.Settle()
			local Results = ShootAt(S, Tg)
			T.Eq(#Results, 1, "results of a shot at a target 30 ahead")
			T.Eq(Results[1].Victim, Tg, "the victim")
			T.Eq(Results[1].Result, "Hit", "the result")
		end)
	end,

	-- RED today: an aim behind you fired straight ahead and spent a round
	BehindIsRefused = function(T)
		Guard(function()
			local S = Shooter("Revolver")
			GunKit.Dummy(-AHEAD * 20, "GunKit_Behind") -- where the refused aim points
			GunKit.Settle()
			T.Eq(S:GetAttribute("Ammo"), REVOLVER_MAG, "a full magazine first")
			local Before = S:GetAttribute("LastShotAt")
			local Results = GunKit.Shot(S, -AHEAD)
			T.Eq(#Results, 0, "results of an aim straight behind")
			T.Eq(S:GetAttribute("Ammo"), REVOLVER_MAG, "Ammo after a refused aim")
			T.Eq(S:GetAttribute("LastShotAt"), Before, "LastShotAt after a refused aim")
		end)
	end,

	-- guard (green since Task 3: Resolve copies the gun's Range): Renetti 60 misses at 65, Forge Tac 110 reaches
	RangePerGun = function(T)
		Guard(function()
			local S = Shooter("Renetti")
			local Tg = Target(65)
			GunKit.Settle()
			T.Eq(#ShootAt(S, Tg), 0, "the Renetti (range 60) at 65 studs")
			assert(WeaponManager.Give(S, "Forge Tac"), "the Forge Tac")
			local Results = ShootAt(S, Tg)
			T.Eq(#Results, 1, "the Forge Tac (range 110) at 65 studs")
			T.Eq(Results[1].Victim, Tg, "the Forge Tac's victim")
		end)
	end,

	-- RED today: Fire sets no Info.Falloff, so the class falloff applies (about 17)
	Falloff = function(T)
		Guard(function()
			local S = Shooter("Revolver")
			local Tg = Target(45)
			GunKit.Settle()
			local Results, Lost = ShootAt(S, Tg)
			T.Eq(#Results, 1, "a hit at 45")
			T.Near(Lost, FALLOFF_DAMAGE, FALLOFF_EPS, "the Revolver's damage at 45 studs")
		end)
	end,

	-- RED today for the falloff reason; its control (equal with and without Mastery) passes since Task 3
	MasteryDoesNotDeepen = function(T)
		Guard(function()
			local S = Shooter("Revolver")
			local A = Target(45, "GunKit_TargetMax")
			GunKit.Settle()
			S:SetAttribute("Mod_WeaponPassive", MASTERY_MAX) -- the Managers.SkillMods attribute, on the dummy only
			local RA, Max = ShootAt(S, A)
			T.Eq(#RA, 1, "a hit with Mastery at its max")
			Aside(A)
			local B = Target(45, "GunKit_TargetMin")
			GunKit.Settle()
			S:SetAttribute("Mod_WeaponPassive", nil) -- no ranks
			local RB, Min = ShootAt(S, B)
			T.Eq(#RB, 1, "a hit with no Mastery")
			T.Near(Max, Min, 0.01, "Mastery leaves the falloff alone (max vs none)")
			T.Near(Max, FALLOFF_DAMAGE, FALLOFF_EPS, "the damage at 45 with Mastery at its max")
			T.Near(Min, FALLOFF_DAMAGE, FALLOFF_EPS, "the damage at 45 with no Mastery")
		end)
	end,

	-- RED today: every hit flinches
	FlinchOnlyClose = function(T)
		Guard(function()
			local S = Shooter("Revolver")
			local Near = Target(10)
			GunKit.Settle()
			T.True(not Stunned(Near), "the near target isn't stunned before the shot")
			T.Eq(#ShootAt(S, Near), 1, "a hit at 10")
			T.True(Stunned(Near), "a hit at 10 studs stuns")
			Aside(Near)
			local Far = Target(40)
			GunKit.Settle()
			T.Eq(#ShootAt(S, Far), 1, "a hit at 40")
			T.True(not Stunned(Far), "a hit at 40 studs doesn't stun")
		end)
	end,

	-- RED today: there's no LastShotResult
	WallStops = function(T)
		Guard(function()
			local S = Shooter("Revolver")
			local Tg = Target(15)
			SmokeKit.TempPart({ -- 10 x 10 x 1, halfway, from the floor up past the muzzle
				Name = "GunKit_Wall",
				Size = Vector3.new(10, 10, 1),
				CFrame = CFrame.new(GunKit.Spot() + AHEAD * 7.5 + Vector3.new(0, 5, 0)),
			})
			GunKit.Settle()
			T.Eq(#ShootAt(S, Tg), 0, "results through a wall")
			T.Eq(S:GetAttribute("LastShotResult"), "Miss", "LastShotResult through a wall")
		end)
	end,

	-- RED today: there's no LastShotResult
	ResultAttribute = function(T)
		Guard(function()
			local S = Shooter("Revolver")
			local A = Target(20, "GunKit_TargetOpen")
			GunKit.Settle()
			local RA = ShootAt(S, A)
			T.Eq(RA[1] and RA[1].Result, "Hit", "the open target's result")
			T.Eq(S:GetAttribute("LastShotResult"), "Hit", "LastShotResult after a hit")
			Aside(A)
			local B = Target(20, "GunKit_TargetBlocking")
			local At = B:GetPivot().Position
			local From = S:GetPivot().Position
			B:PivotTo(CFrame.lookAt(At, Vector3.new(From.X, At.Y, From.Z))) -- facing the shooter
			Blocking.new(WCS.Character.GetCharacterFromInstance(B)):Start()
			GunKit.Settle()
			local RB = ShootAt(S, B)
			T.Eq(RB[1] and RB[1].Result, "Blocked", "the blocking target's result")
			T.Eq(S:GetAttribute("LastShotResult"), "Blocked", "LastShotResult after a blocked hit")
		end)
	end,

	-- RED today: Traversal isn't watched. Watch hooks players' characters, so this uses the test player's.
	ShootingModeEndsInWater = function(T)
		local C = Player.Character
		local WasCombat = C:GetAttribute("CombatMode")
		local Gun
		Guard(function()
			T.Eq(C:FindFirstChildOfClass("Tool"), nil, "no Tool held after Unequip")
			C:SetAttribute("CombatMode", true)
			Gun = WeaponManager.Give(C, "Revolver")
			T.True(Gun ~= nil, "the Revolver given")
			C:SetAttribute("ShootingMode", true)
			task.wait(0.1)
			T.Eq(C:GetAttribute("ShootingMode"), true, "shooting mode on dry land")
			C:SetAttribute("Traversal", "Swim") -- as MovementState publishes it
			local T0 = os.clock()
			while C:GetAttribute("ShootingMode") and os.clock() - T0 < MODE_ENDS_WITHIN do task.wait() end
			T.Eq(C:GetAttribute("ShootingMode"), nil, "shooting mode " .. MODE_ENDS_WITHIN .. " s after Traversal = Swim")
		end, function()
			C:SetAttribute("Traversal", nil)
			C:SetAttribute("ShootingMode", nil)
			if Gun then Gun:Destroy() end -- the test's own Revolver (Give's clone), never the player's item
			C:SetAttribute("CombatMode", WasCombat)
		end)
	end,
}

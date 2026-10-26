-- Play_Guns (gun rework Task 5, 2026-10-25): the server shot path, in the Play VM (LMRunSuite). Every case uses GunKit's
-- rigs at GunKit.Spot(), inside SmokeKit.Guarded with GunKit.Clean as After, after GunKit.Unequip (Ruling 4c).
-- Shooters stand at the spot facing -Z; targets stand straight ahead on the same floor. Every expected number is worked by
-- hand below, as a constant; nothing is read from the code under test to choose a spot or an answer.
--   Revolver (TuningConfig PROPOSAL, 2026-10-25): Damage 20, Range 70, Falloff {Start 20, End 70, Min 0.5}, Magazine 6.
--   A target 45 studs ahead: the shot meets its box face 44 studs out (the box is 2 deep), so the falloff is
--   1 - 0.5 * (44 - 20) / (70 - 20) = 0.76 and the damage 20 * 0.76 = 15.2 -- 15 +- 0.5 (20 x 0.75 at the root's 45).
--   The old path (the class falloff {25, 90, 0.5}, the ray stopping on the root part 44.5 out) gave
--   1 - 0.5 * (44.5 - 25) / 65 = 0.85 -> about 17.0 (outside the band; RED measured 16.996).
--   Weapon Mastery (SkillTree AR_Mastery): 2 ranks x 0.25 = Mod_WeaponPassive 0.5 at most; no ranks = no attribute.
-- Lag compensation (Task 6): a target the test moves along +X for 1 s (PivotTo every Heartbeat, its path worked from x0
-- by the test's own clock, workspace:GetServerTimeNow()), with the shooter 30 studs off the path on Z. The hit box is 4
-- wide on X (TuningConfig Aim.HitBox, PROPOSAL), 2 either side of the root.
--   At 16 studs/s (HistoryTracksAMover, RewindCapped): 0.25 s back (the MaxRewind cap) it was 16 x 0.25 = 4 studs
--   behind, 0.6 s back 9.6; 0.2 s back 3.2.
--   At 24 studs/s (RewindHitsWhereItWas, Ruling 15): 0.2 s back it was 24 x 0.2 = 4.8 studs behind, so a ray at the old
--   place misses where it stands now by 4.8 - 2 = 2.8 studs, 2.4 with a frame's slack (24 / 60 = 0.4).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SmokeKit = require(script.Parent.SmokeKit)
local GunKit = require(script.Parent.GunKit)
local WCS = require(ReplicatedStorage.Modules.Framework.WCS)
local WeaponManager = require(ReplicatedStorage.Modules.Managers.WeaponManager)
local GunAim = require(ReplicatedStorage.Modules.Data.Rensei.GunAim)
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)
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
local SPEED, MOVE_FOR = 16, 1 -- the moving target: studs/s along +X, seconds
local FAST = 24 -- studs/s: RewindHitsWhereItWas's mover (Ruling 15: a wider margin for its control)
local MOVE_FROM = -8 -- its start, studs along X from the spot (it stops at +8, or +16 at FAST)
local REWIND_EPS = 0.01 -- seconds: RewindAtIsPingCapped's slack
local OFF_PATH = 30 -- the shooter's distance from the path on Z
local BACK = 0.2 -- seconds back for the rewind cases (3.2 studs at SPEED, 4.8 at FAST)
local HISTORY_EPS = 0.6 -- studs: a frame's slack (16 studs/s x one ~25 ms Studio server frame = 0.4); the 20 Hz sampling
-- adds nothing on a straight path (the history interpolates linearly between samples)
local CAP = 0.25 -- seconds: GunAim.RewindTime(2.0, Aim) = clamp(2.0 + Interp 0.1, 0, MaxRewind 0.25) (TuningConfig PROPOSAL)
local FAR_BACK = 0.6 -- seconds: past the cap (9.6 studs back)
local SHOT_REACH = 200 -- ShotTarget's MaxT in these cases
-- The snap log (Ruling 13; TuningConfig Aim.SnapDeg 120, SnapWindow 0.1, PROPOSAL): two aimed Fire requests SNAP_GAP s
-- apart, SNAP_WIDE degrees apart (+-65 from the facing: inside MaxYaw 100, and 130 > 120) count once; SNAP_NARROW apart
-- (+-5) don't. The pairs are SNAP_PAUSE s apart, past the window.
local SNAP_GAP, SNAP_WIDE, SNAP_NARROW, SNAP_PAUSE = 0.05, 130, 10, 0.3
local FLINCH_ANIM = ReplicatedStorage.Assets.Animations.Shared.Combat.Fist.BlockIdle -- any looped, non-Core track will do

local function Guard(Body, After)
	SmokeKit.Guarded(Player, Body, function() GunKit.Unequip(Player) end, function()
		local Ok, Err = true, nil
		if After then Ok, Err = pcall(After) end
		GunKit.Clean()
		if not Ok then error(Err, 0) end
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

-- a looped, non-Core animation playing on M (a hit reaction stops it; Ruling 12)
local function Looping(M)
	local Track = M:FindFirstChildOfClass("Humanoid").Animator:LoadAnimation(FLINCH_ANIM)
	Track.Looped = true
	Track.Priority = Enum.AnimationPriority.Action
	Track:Play()
	return Track
end

-- the Shoot request handler the server runs (ServerHandler.Requests.Shoot, the same module instance and state)
local function ShootRequest()
	local SH = game:GetService("ServerScriptService"):FindFirstChild("ServerHandler")
	local M = SH and SH:FindFirstChild("Requests") and SH.Requests:FindFirstChild("Shoot")
	assert(M, "no ServerScriptService.ServerHandler.Requests.Shoot")
	return require(M)
end

-- one shot at Target: the results, and the Health it lost
local function ShootAt(Shooter, Target)
	local Results, Lost = GunKit.Shot(Shooter, AimAt(Shooter, Target))
	return Results, Lost[Target] or 0
end

-- PositionHistory where the server runs it: ServerScriptService (RenseiBoot copies the RenseiServer package there)
local function PositionHistory()
	local M = game:GetService("ServerScriptService"):FindFirstChild("PositionHistory")
	assert(M, "no PositionHistory module in ServerScriptService")
	return require(M)
end

-- A target at MOVE_FROM on the path and a Revolver shooter OFF_PATH studs off it on Z, ShooterAlong studs along X from
-- the spot, facing the path (-Z). After Settle the target moves along +X at Speed (SPEED by default) for MOVE_FOR s,
-- PivotTo every Heartbeat. Returns the target, the shooter, the muzzle, and Where(t): where the test put the target's
-- root at server time t (from x0, read once before it moves, and the test's own clock; nothing read back from the rig
-- after that).
local function MovingTarget(ShooterAlong, Speed)
	Speed = Speed or SPEED
	local Tg = GunKit.Dummy(Vector3.new(MOVE_FROM, 0, 0), "GunKit_Mover")
	local S = GunKit.Shooter(Vector3.new(ShooterAlong, 0, OFF_PATH), GunKit.Spot() + Vector3.new(ShooterAlong, 0, 0), "Revolver")
	GunKit.Settle()
	local Start = Tg:GetPivot()
	local Root0 = Tg.HumanoidRootPart.Position
	local T0 = workspace:GetServerTimeNow()
	local function Along(t) return Speed * math.clamp(t - T0, 0, MOVE_FOR) end
	local Done = false
	local Conn = RunService.Heartbeat:Connect(function()
		local X = Along(workspace:GetServerTimeNow())
		Tg:PivotTo(Start + Vector3.new(X, 0, 0))
		if X >= Speed * MOVE_FOR then Done = true end
	end)
	local Wait0 = os.clock()
	while not Done and os.clock() - Wait0 < MOVE_FOR + 2 do task.wait() end
	Conn:Disconnect()
	assert(Done, "the moving target finished its path")
	local function Where(t) return Root0 + Vector3.new(Along(t), 0, 0) end
	return Tg, S, S.HumanoidRootPart.Position + MUZZLE_UP, Where
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
			local NearTrack = Looping(Near)
			T.True(not Stunned(Near), "the near target isn't stunned before the shot")
			T.True(NearTrack.IsPlaying, "the near target's looped track plays before the shot")
			T.Eq(#ShootAt(S, Near), 1, "a hit at 10")
			T.True(Stunned(Near), "a hit at 10 studs stuns")
			task.wait(0.2)
			T.True(not NearTrack.IsPlaying, "a hit at 10 studs stops the target's looped track (control: the hit reaction)")
			Aside(Near)
			local Far = Target(40)
			GunKit.Settle()
			local FarTrack = Looping(Far)
			T.True(FarTrack.IsPlaying, "the far target's looped track plays before the shot")
			T.Eq(#ShootAt(S, Far), 1, "a hit at 40")
			T.True(not Stunned(Far), "a hit at 40 studs doesn't stun")
			task.wait(0.2)
			T.True(FarTrack.IsPlaying, "a hit at 40 studs leaves the target's looped track playing (no hit reaction)")
		end)
	end,

	-- RED today: there's no LastShotResult
	WallStops = function(T)
		Guard(function()
			local S = Shooter("Revolver")
			local Tg = Target(15)
			local Wall = SmokeKit.TempPart({ -- 10 x 10 x 1, halfway, from the floor up past the muzzle
				Name = "GunKit_Wall",
				Size = Vector3.new(10, 10, 1),
				CFrame = CFrame.new(GunKit.Spot() + AHEAD * 7.5 + Vector3.new(0, 5, 0)),
			})
			GunKit.Settle()
			T.Eq(#ShootAt(S, Tg), 0, "results through a wall")
			T.Eq(S:GetAttribute("LastShotResult"), "Miss", "LastShotResult through a wall")
			Wall:Destroy() -- only the wall (ClearTemp would take the floor too)
			local Results = ShootAt(S, Tg)
			T.Eq(Results[1] and Results[1].Result, "Hit", "the same shot with the wall gone (control)")
			T.Eq(S:GetAttribute("LastShotResult"), "Hit", "LastShotResult with the wall gone")
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
			C:SetAttribute("Traversal", "Climb") -- control: a Traversal change that isn't the water
			task.wait(MODE_ENDS_WITHIN)
			T.Eq(C:GetAttribute("ShootingMode"), true, "shooting mode " .. MODE_ENDS_WITHIN .. " s after Traversal = Climb (control)")
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

	-- RED before Task 6: there's no PositionHistory
	HistoryTracksAMover = function(T)
		Guard(function()
			local H = PositionHistory()
			local Tg, _, _, Where = MovingTarget(0)
			local At = workspace:GetServerTimeNow() - BACK
			local CF = H.At(Tg, At)
			T.True(CF ~= nil, "a history for the moving target")
			if CF == nil then return end
			T.Near((CF.Position - Where(At)).Magnitude, 0, HISTORY_EPS, "the history " .. BACK .. " s back vs the test's own path")
		end)
	end,

	-- RED before Task 6: without a history ShotTarget tests where the target stands now, whatever At is
	RewindHitsWhereItWas = function(T)
		Guard(function()
			local Tg, S, Origin, Where = MovingTarget(MOVE_FROM + FAST * MOVE_FOR - FAST * BACK, FAST) -- x1 - 4.8
			local Now = workspace:GetServerTimeNow()
			local Dir = (Where(Now - BACK) - Origin).Unit
			T.Eq(WeaponManager.ShotTarget(S, Origin, Dir, SHOT_REACH, Now - BACK), Tg, "a ray at where it was " .. BACK .. " s back, rewound " .. BACK .. " s")
			T.Eq(WeaponManager.ShotTarget(S, Origin, Dir, SHOT_REACH, Now), nil, "the same ray at At = now (control: it has moved on 4.8 studs)")
		end)
	end,

	-- RED before Task 6 on its positive control; the guard is the cap (a ray at 0.6 s back misses a 0.25 s rewind)
	RewindCapped = function(T)
		Guard(function()
			local Back = GunAim.RewindTime(2.0, Tuning.Weapons.Guns.Aim)
			T.Near(Back, CAP, 1e-6, "the rewind for a 2 s ping")
			local Tg, S, Origin, Where = MovingTarget(MOVE_FROM + SPEED * MOVE_FOR - SPEED * CAP) -- x1 - 4
			local Now = workspace:GetServerTimeNow()
			local At = Now - Back
			T.Eq(WeaponManager.ShotTarget(S, Origin, (Where(Now - CAP) - Origin).Unit, SHOT_REACH, At), Tg, "a ray at where it was " .. CAP .. " s back, rewound by the cap (positive control)")
			T.Eq(WeaponManager.ShotTarget(S, Origin, (Where(Now - FAR_BACK) - Origin).Unit, SHOT_REACH, At), nil, "a ray at where it was " .. FAR_BACK .. " s back, rewound by the cap")
		end)
	end,

	-- Ruling 17 (new in Task 6's fix round): an NPC's shot isn't rewound; a player's is rewound by ping + Interp, capped
	-- at MaxRewind (Studio's ping is about 0, so about Interp)
	RewindAtIsPingCapped = function(T)
		Guard(function()
			local Cfg = Tuning.Weapons.Guns.Aim
			local Rig = GunKit.Dummy(Vector3.zero, "GunKit_Npc")
			GunKit.Settle()
			local NpcBack = workspace:GetServerTimeNow() - WeaponManager.RewindAt(Rig)
			T.Near(NpcBack, 0, REWIND_EPS, "an NPC rig's rewind")
			local C = Player.Character
			T.True(C ~= nil and game:GetService("Players"):GetPlayerFromCharacter(C) == Player, "the test player's character")
			local Back = workspace:GetServerTimeNow() - WeaponManager.RewindAt(C)
			T.True(Back >= Cfg.Interp - REWIND_EPS and Back <= Cfg.MaxRewind + REWIND_EPS,
				string.format("the player's rewind %.4f s within [Interp %.2f, MaxRewind %.2f] +- %.2f", Back, Cfg.Interp, Cfg.MaxRewind, REWIND_EPS))
		end)
	end,

	-- Ruling 13: every aimed Fire request is compared with the previous one, before the mode gates (the test player is in
	-- no shooting mode, so these requests fire nothing). Driven through the server's own Shoot request handler.
	SnapLogCountsTurns = function(T)
		local C = Player.Character
		local Was = C:GetAttribute("GunSnapCount")
		local WasAnchored = C.HumanoidRootPart.Anchored
		Guard(function()
			local Shoot = ShootRequest()
			T.Eq(C:GetAttribute("ShootingMode"), nil, "the test player isn't in shooting mode")
			local Root = C.HumanoidRootPart
			Root.Anchored = true -- its facing holds still for the pairs (Guarded puts the character back)
			local L = Root.CFrame.LookVector
			L = Vector3.new(L.X, 0, L.Z).Unit
			local function Turned(Deg) return CFrame.Angles(0, math.rad(Deg), 0):VectorToWorldSpace(L) end
			C:SetAttribute("GunSnapCount", nil)
			task.wait(SNAP_PAUSE) -- past the window of any earlier request
			Shoot(Player, "Fire", Turned(-SNAP_WIDE / 2))
			task.wait(SNAP_GAP)
			Shoot(Player, "Fire", Turned(SNAP_WIDE / 2))
			T.Eq(C:GetAttribute("GunSnapCount"), 1, SNAP_WIDE .. " degrees in " .. SNAP_GAP .. " s")
			task.wait(SNAP_PAUSE)
			Shoot(Player, "Fire", Turned(-SNAP_NARROW / 2))
			task.wait(SNAP_GAP)
			Shoot(Player, "Fire", Turned(SNAP_NARROW / 2))
			T.Eq(C:GetAttribute("GunSnapCount"), 1, SNAP_NARROW .. " degrees in " .. SNAP_GAP .. " s (control: no count)")
		end, function()
			C.HumanoidRootPart.Anchored = WasAnchored
			C:SetAttribute("GunSnapCount", Was)
		end)
	end,
}

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
local ResourceManager = require(ReplicatedStorage.Modules.Managers.ResourceManager)
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
-- The flick grace (Ruling 28; TuningConfig Aim.FlickGrace 0.4, PROPOSAL): a Fire request aimed straight behind the test
-- player (180 degrees, past MaxYaw 100) is held 0.4 s; with no turn nothing has fired GRACE_PAST s later. Its control: the
-- same request, with the root turned to face the aim TURN_AT s later (inside the grace), fires: the Revolver's Startup is
-- 0.12 s, so LastShotAt has changed and one round is gone by GRACE_PAST.
local GRACE_PAST, TURN_AT = 0.5, 0.1
-- A guard broken by a shot (Ruling 11; the shot shows as a Hit, Ruling 9): the shot drains its Posture, Shots[1].Posture
-- 3 (TuningConfig PROPOSAL; x1: the Guns passive has no BlockedPostureMult and the rig no PostureMult). From the full
-- 100 (Posture.Max) a blocked shot leaves 97 -- "Blocked" (the control); with the posture set to GUARD_LEFT 2 it leaves
-- max(0, 2 - 3) = 0, under BlockManager.Check's floor 0.17 -- "GuardBroken". (Posture regen waits RegenDelay 1.5 s after
-- a change, and both shots are synchronous, so nothing regenerates in between.)
local POSTURE_FULL, SHOT_POSTURE, GUARD_LEFT, POSTURE_EPS = 100, 3, 2, 0.01
-- The shot ticket (final fix A1): a player's shot is rewound from its REQUEST, not from its strike. The test player fires
-- through the real Shoot request at a mover going +X at FAST (24 studs/s), OFF_PATH studs away, standing level with
-- where the mover will be so the shot meets the box face on (its half-width 2, Aim.HitBox PROPOSAL). Studio's ping is
-- about 0, so a request at time t is rewound to t - INTERP (Aim.Interp 0.1, PROPOSAL); the Revolver's strike comes
-- STARTUP (Shots[1].Startup 0.12, PROPOSAL) after the request.
--   Shot 1, aimed at Where(t - INTERP): rewound from the request it meets the box dead centre; rewound from the strike
--   (the old rule) the box stands 24 x 0.12 = 2.88 studs further on: a miss by 0.88 at least (later frames: more).
--   Shot 2 (control), aimed at Where(t + STARTUP - INTERP), where the old rule looks: rewound from the request, the box
--   is 2.88 behind that line (a miss); the old rule hits it (0 to ~0.6 off, a frame's lateness).
-- The mover starts at TICKET_FROM and runs TICKET_FOR s; shot 1 goes TICKET_FIRST s after it starts (its line at
-- TICKET_FROM + 24 x (0.6 - 0.1) = -24 = TICKET_X1), shot 2 TICKET_SECOND s after (-36 + 24 x (1.8 + 0.02) = 7.7 =
-- TICKET_X2), past shot 1's Startup + Active + Recovery (0.12 + 0.02 + 0.42 = 0.56 s).
local INTERP, STARTUP = 0.1, 0.12
local TICKET_FROM, TICKET_FOR, TICKET_FIRST, TICKET_SECOND = -36, 3, 0.6, 1.8
local TICKET_X1, TICKET_X2 = -24, 7.7
local SHOT_WITHIN = 0.5 -- seconds for an accepted Fire request to have fired (Startup 0.12 + frames)
-- Fan the Hammer (final fix A2; TuningConfig Guns.Skill PROPOSAL): Stamina 15, three strikes (HitTimes 0.12 / 0.27 /
-- 0.42), one round each. Stamina regen waits RegenDelay 0.8 s, so FAN_LOOK after the press nothing has regenerated yet.
-- With FAN_LEFT 2 rounds the strikes spend 1, 1 and then nothing (the second empties the gun and starts the reload).
local FAN_STAMINA, FAN_SHOTS, FAN_LEFT, FAN_LOOK, STAMINA_EPS = 15, 3, 2, 0.2, 0.01
local FAN_DONE = 1.0 -- seconds: the Fan's Startup + Active + Recovery 0.78 s, and a margin
-- The flick hold (final fix A3, Ruling 29): HOLD_PEEK s after a held Fire request, a valid Requests.Aim; HOLD_LOOK s
-- later (several Heartbeats of the hold) the stored aim must still be the valid one.
local HOLD_PEEK, HOLD_LOOK = 0.05, 0.15
-- The limiter (Aim.FireRate 5 / FireBurst 5, PROPOSAL): BURST + 3 requests at once take BURST aims; REFILL s later 1.5
-- tokens are back, so 1 of 3 more gets through.
local RATE, BURST, REFILL = 5, 5, 0.3

-- the test player's attributes a case may change, put back by PlayerGun (final fix A8: LastShotAt, LastShotResult and
-- Traversal too)
local PLAYER_KEEP = {"CombatMode", "ShootingMode", "LastShotAt", "LastShotResult", "Traversal", "WeaponSkillReadyAt",
	"WeaponSkillCooldown", "WeaponSkillName", "GunSnapCount"}

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

-- a request handler the server runs (ServerHandler.Requests.<Name>: Shoot, Aim, WeaponSkill), the same module instance
-- and state
local function Request(Name)
	local SH = game:GetService("ServerScriptService"):FindFirstChild("ServerHandler")
	local M = SH and SH:FindFirstChild("Requests") and SH.Requests:FindFirstChild(Name)
	assert(M, "no ServerScriptService.ServerHandler.Requests." .. Name)
	return require(M)
end
local function ShootRequest() return Request("Shoot") end

-- the test player stood on GunKit's floor at Spot() + Offset, root anchored, facing -Z
local function PutPlayer(Offset)
	local At = GunKit.Spot() + Offset + Vector3.new(0, 3, 0)
	Player.Character:PivotTo(CFrame.lookAt(At, At + AHEAD))
end

-- The test player armed for a case (the Shoot / Aim / WeaponSkill requests read the player's own character): stood at
-- Offset (PutPlayer), in Combat Mode, holding the test's own Revolver (WeaponManager.Give's clone) with a full
-- magazine, not in shooting mode. Body(C, Root). After (optional) runs first; then shooting mode goes, the Revolver is
-- destroyed, PLAYER_KEEP's attributes and Stamina are put back (the root's anchoring and pivot: SmokeKit.Guarded).
local function PlayerGun(Body, After, Offset)
	local C = Player.Character
	local Root = C.HumanoidRootPart
	local Kept = {}
	for I, A in ipairs(PLAYER_KEEP) do Kept[I] = C:GetAttribute(A) end
	local Stamina = ResourceManager.Get(C, "Stamina")
	local Gun
	Guard(function()
		Root.Anchored = true
		PutPlayer(Offset or Vector3.zero)
		C:SetAttribute("CombatMode", true)
		Gun = WeaponManager.Give(C, "Revolver")
		assert(Gun ~= nil, "the Revolver given")
		GunKit.Settle()
		local T0 = os.clock()
		while (C:GetAttribute("ReloadingUntil") or 0) > workspace:GetServerTimeNow() and os.clock() - T0 < 3 do task.wait() end
		C:SetAttribute("Ammo", REVOLVER_MAG)
		Body(C, Root)
	end, function()
		local Ok, Err = true, nil
		if After then Ok, Err = pcall(After) end
		C:SetAttribute("ShootingMode", nil)
		if Gun then
			Gun:Destroy() -- the test's own Revolver (Give's clone), never the player's item
			-- its detach is a deferred signal: let it run now. Left for later, it ran after the next case's Give and, the
			-- name being the same, cleared that new Revolver's Weapon / Ammo / ShootingMode (seen in the RED session)
			task.wait()
		end
		for I, A in ipairs(PLAYER_KEEP) do C:SetAttribute(A, Kept[I]) end
		ResourceManager.Set(C, "Stamina", Stamina)
		if not Ok then error(Err, 0) end
	end)
end

-- A target at From (an offset from the spot) and Go(): from now it moves along +X at Speed for For s (PivotTo every
-- Heartbeat; it stops if the kit removes it). Go returns Where(t) -- where the test puts the target's root at server
-- time t, from x0 read once before it moves and the test's own clock; nothing read back from the rig after that -- and
-- Finish(), which waits for the end of the path.
local function Mover(From, Speed, For)
	local Tg = GunKit.Dummy(From, "GunKit_Mover")
	local function Go()
		local Start = Tg:GetPivot()
		local Root0 = Tg.HumanoidRootPart.Position
		local T0 = workspace:GetServerTimeNow()
		local function Along(t) return Speed * math.clamp(t - T0, 0, For) end
		local Done = false
		local Conn
		Conn = RunService.Heartbeat:Connect(function()
			if not Tg.Parent then Conn:Disconnect() return end
			local X = Along(workspace:GetServerTimeNow())
			Tg:PivotTo(Start + Vector3.new(X, 0, 0))
			if X >= Speed * For then Done = true end
		end)
		local function Finish()
			local Wait0 = os.clock()
			while not Done and os.clock() - Wait0 < For + 2 do task.wait() end
			Conn:Disconnect()
			assert(Done, "the moving target finished its path")
		end
		return function(t) return Root0 + Vector3.new(Along(t), 0, 0) end, Finish
	end
	return Tg, Go
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
	local Tg, Go = Mover(Vector3.new(MOVE_FROM, 0, 0), Speed or SPEED, MOVE_FOR)
	local S = GunKit.Shooter(Vector3.new(ShooterAlong, 0, OFF_PATH), GunKit.Spot() + Vector3.new(ShooterAlong, 0, 0), "Revolver")
	GunKit.Settle()
	local Where, Finish = Go()
	Finish()
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
		-- through the Shoot request (Ruling 28): behind with no turn is still refused once the flick grace has run out;
		-- turning to face the aim inside the grace fires it (the control). The test player, anchored on GunKit's floor
		-- (PlayerGun puts LastShotAt and LastShotResult back after; final fix A8).
		PlayerGun(function(C, Root)
			local Shoot = ShootRequest()
			C:SetAttribute("ShootingMode", true)
			local Was = C:GetAttribute("LastShotAt")
			Shoot(Player, "Fire", -AHEAD)
			task.wait(GRACE_PAST)
			T.Eq(C:GetAttribute("Ammo"), REVOLVER_MAG, "Ammo " .. GRACE_PAST .. " s after a Fire request aimed behind (no turn)")
			T.Eq(C:GetAttribute("LastShotAt"), Was, "LastShotAt " .. GRACE_PAST .. " s after a Fire request aimed behind (no turn)")
			Shoot(Player, "Fire", -AHEAD)
			task.wait(TURN_AT)
			C:PivotTo(CFrame.lookAt(Root.Position, Root.Position - AHEAD)) -- the turn reaches the server inside the grace
			task.wait(GRACE_PAST - TURN_AT)
			T.True(C:GetAttribute("LastShotAt") ~= Was, "control: the request aimed behind fired once the root turned to it " .. TURN_AT .. " s later")
			T.Eq(C:GetAttribute("Ammo"), REVOLVER_MAG - 1, "control: Ammo after that shot")
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

	-- RED today: every hit flinches. Final fix A4 (Ruling 20): the far victim gets no hitstop either (a Play-only wrapper
	-- on AnimationManager.Hitstop, removed by After, counts its calls per model; DamageManager defers them, so they are
	-- read after the 0.2 s wait; the near hit's hitstop is the control)
	FlinchOnlyClose = function(T)
		local AnimationManager = require(ReplicatedStorage.Modules.Managers.AnimationManager)
		local Hitstop = AnimationManager.Hitstop
		local Stops = {}
		Guard(function()
			AnimationManager.Hitstop = function(M, ...)
				Stops[M] = (Stops[M] or 0) + 1
				return Hitstop(M, ...)
			end
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
			T.True((Stops[Near] or 0) >= 1, "a hit at 10 studs gives the target a hitstop (control)")
			Aside(Near)
			local Far = Target(40)
			GunKit.Settle()
			local FarTrack = Looping(Far)
			T.True(FarTrack.IsPlaying, "the far target's looped track plays before the shot")
			T.Eq(#ShootAt(S, Far), 1, "a hit at 40")
			T.True(not Stunned(Far), "a hit at 40 studs doesn't stun")
			task.wait(0.2)
			T.True(FarTrack.IsPlaying, "a hit at 40 studs leaves the target's looped track playing (no hit reaction)")
			T.Eq(Stops[Far], nil, "hitstops on the target hit at 40 studs")
			T.True((Stops[S] or 0) >= 2, "the shooter's own hitstop still plays on both hits")
		end, function()
			AnimationManager.Hitstop = Hitstop
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

	-- Ruling 11 (a guard: Ruling 9's mapping is in WeaponManager.Fire since Task 5): a shot that breaks a blocking
	-- target's guard sets LastShotResult "Hit"; its control, the same target at full posture, shows "Blocked"
	GuardBrokenShowsHit = function(T)
		Guard(function()
			local S = Shooter("Revolver")
			local B = Target(20, "GunKit_TargetGuard")
			local At = B:GetPivot().Position
			local From = S:GetPivot().Position
			B:PivotTo(CFrame.lookAt(At, Vector3.new(From.X, At.Y, From.Z))) -- facing the shooter
			Blocking.new(WCS.Character.GetCharacterFromInstance(B)):Start()
			GunKit.Settle()
			T.Near(ResourceManager.Get(B, "Posture"), POSTURE_FULL, POSTURE_EPS, "the blocking target's posture before the shots")
			local R1 = ShootAt(S, B)
			T.Eq(R1[1] and R1[1].Result, "Blocked", "control: the result at full posture")
			T.Eq(S:GetAttribute("LastShotResult"), "Blocked", "control: LastShotResult at full posture")
			T.Near(ResourceManager.Get(B, "Posture"), POSTURE_FULL - SHOT_POSTURE, POSTURE_EPS, "the posture after one blocked shot")
			ResourceManager.Set(B, "Posture", GUARD_LEFT)
			local R2 = ShootAt(S, B)
			T.Eq(R2[1] and R2[1].Result, "GuardBroken", "the result with the posture at " .. GUARD_LEFT)
			T.Eq(S:GetAttribute("LastShotResult"), "Hit", "LastShotResult after a shot that broke the guard")
		end)
	end,

	-- RED today: Traversal isn't watched. Watch hooks players' characters, so this uses the test player's.
	-- (PlayerGun puts the captured Traversal back; final fix A8)
	ShootingModeEndsInWater = function(T)
		PlayerGun(function(C)
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

	-- RED before final fix A1: the shot was rewound from its strike (STARTUP after the request), so a shot aimed where
	-- the shooter saw the mover at the request missed it. Through the real Shoot request, the test player in shooting
	-- mode; the numbers are worked in the header. The control (shot 2) is aimed where the strike-time rewind looks.
	TicketRewindsFromRequest = function(T)
		PlayerGun(function(C, Root)
			local Shoot = ShootRequest()
			local Tg, Go = Mover(Vector3.new(TICKET_FROM, 0, 0), FAST, TICKET_FOR)
			C:SetAttribute("ShootingMode", true)
			GunKit.Settle()
			local Health = Tg.Humanoid.Health
			local Where, Finish = Go()
			local Go0 = os.clock()
			-- one Fire request aimed at the mover's root at server time Look(t), from the root's muzzle; waits for the shot.
			-- Returns whether it fired, LastShotResult, and the rewind RewindAt gave at the request (for the message only).
			local function FireAt(StandX, After, Look)
				PutPlayer(Vector3.new(StandX, 0, OFF_PATH))
				task.wait(math.max(0, After - (os.clock() - Go0)))
				local Was = C:GetAttribute("LastShotAt")
				local Tr = workspace:GetServerTimeNow()
				local Back = Tr - WeaponManager.RewindAt(C)
				Shoot(Player, "Fire", (Where(Look(Tr)) - (Root.Position + MUZZLE_UP)).Unit)
				local T0 = os.clock()
				while C:GetAttribute("LastShotAt") == Was and os.clock() - T0 < SHOT_WITHIN do task.wait() end
				return C:GetAttribute("LastShotAt") ~= Was, C:GetAttribute("LastShotResult"), Back
			end
			local Fired, Result, Back = FireAt(TICKET_X1, TICKET_FIRST, function(Tr) return Tr - INTERP end)
			T.True(Fired, "the Fire request aimed where the mover was at the request fired")
			T.Eq(Result, "Hit", ("LastShotResult, aimed at Where(request - %.2f) (the player's rewind at the request: %.3f s)"):format(INTERP, Back))
			T.True(Tg.Humanoid.Health < Health, "the mover lost Health")
			Fired, Result = FireAt(TICKET_X2, TICKET_SECOND, function(Tr) return Tr + STARTUP - INTERP end)
			T.True(Fired, "control: the second Fire request fired")
			T.Eq(Result, "Miss", ("control: LastShotResult, aimed at Where(request + %.2f - %.2f), where a strike-time rewind looks"):format(STARTUP, INTERP))
			Finish()
		end)
	end,

	-- RED before final fix A2: a Fan the Hammer pressed with a fresh refused aim spent its Stamina and cooldown and fired
	-- nothing. Through the real Aim and WeaponSkill requests; the control (a forward aim) spends them and three rounds.
	FanRefusedCostsNothing = function(T)
		PlayerGun(function(C)
			local Aim, Skill = Request("Aim"), Request("WeaponSkill")
			C:SetAttribute("WeaponSkillReadyAt", nil)
			local Max = ResourceManager.Max(C, "Stamina")
			ResourceManager.Set(C, "Stamina", Max)
			Aim(Player, -AHEAD) -- straight behind: refused
			task.spawn(Skill, Player)
			task.wait(FAN_LOOK)
			T.Near(ResourceManager.Get(C, "Stamina"), Max, STAMINA_EPS, "Stamina after a Fan the Hammer aimed behind")
			T.Eq(C:GetAttribute("WeaponSkillReadyAt"), nil, "WeaponSkillReadyAt after a Fan the Hammer aimed behind")
			T.Eq(C:GetAttribute("Ammo"), REVOLVER_MAG, "Ammo after a Fan the Hammer aimed behind")
			task.wait(FAN_DONE)
			C:SetAttribute("WeaponSkillReadyAt", nil) -- (RED: the refused press spent these: the control starts afresh)
			ResourceManager.Set(C, "Stamina", Max)
			Aim(Player, AHEAD)
			task.spawn(Skill, Player)
			task.wait(FAN_LOOK)
			T.Near(ResourceManager.Get(C, "Stamina"), Max - FAN_STAMINA, STAMINA_EPS, "control: Stamina after a Fan aimed ahead")
			T.True(C:GetAttribute("WeaponSkillReadyAt") ~= nil, "control: the Fan's cooldown runs")
			task.wait(FAN_DONE)
			T.Eq(C:GetAttribute("Ammo"), REVOLVER_MAG - FAN_SHOTS, "control: Ammo after a Fan aimed ahead")
		end)
	end,

	-- RED before final fix A3 (Ruling 29): the flick hold re-ran SetAim with its refused aim every Heartbeat, so a valid
	-- Requests.Aim sent meanwhile was overwritten with a refused one; and a Mode request didn't drop the held Fire (it
	-- fired once the root turned). BehindIsRefused's control shows the same turn fires a held request.
	FlickHoldKeepsNewerAim = function(T)
		PlayerGun(function(C, Root)
			local Shoot, Aim = ShootRequest(), Request("Aim")
			C:SetAttribute("ShootingMode", true)
			Shoot(Player, "Fire", -AHEAD) -- behind: held by the flick grace
			task.wait(HOLD_PEEK)
			Aim(Player, AHEAD)
			task.wait(HOLD_LOOK)
			T.Eq(WeaponManager.AimRefused(C), false, "a valid Requests.Aim " .. HOLD_LOOK .. " s into a held flick is still the stored aim")
			task.wait(GRACE_PAST) -- that hold runs out
			local Was, Ammo = C:GetAttribute("LastShotAt"), C:GetAttribute("Ammo")
			Shoot(Player, "Fire", -AHEAD)
			task.wait(HOLD_PEEK)
			Shoot(Player, "Mode", true) -- (already on: it stays on)
			T.Eq(C:GetAttribute("ShootingMode"), true, "shooting mode after the Mode request")
			task.wait(TURN_AT - HOLD_PEEK)
			C:PivotTo(CFrame.lookAt(Root.Position, Root.Position - AHEAD)) -- the turn the held request waited for
			task.wait(GRACE_PAST - TURN_AT)
			T.Eq(C:GetAttribute("LastShotAt"), Was, "LastShotAt: a Mode request drops the held Fire")
			T.Eq(C:GetAttribute("Ammo"), Ammo, "Ammo: a Mode request drops the held Fire")
		end)
	end,

	-- RED before final fix A5: SetAim didn't track the character, and the tables were only emptied on Destroying, so an
	-- unarmed character that left the world kept its stored aim. The control: the refused aim is there before it leaves.
	TablesGoWithTheCharacter = function(T)
		Guard(function()
			local Rig = GunKit.Dummy(AHEAD * 30, "GunKit_Unarmed") -- faces -Z, holds no gun
			GunKit.Settle()
			WeaponManager.SetAim(Rig, -AHEAD) -- straight behind: refused, and remembered
			T.Eq(WeaponManager.AimRefused(Rig), true, "control: the refused aim is stored")
			Rig.Parent = nil -- it leaves the world (not destroyed; GunKit.Clean still destroys it)
			task.wait(0.1)
			T.Eq(WeaponManager.AimRefused(Rig), false, "the stored aim once the character has left the world")
		end)
	end,

	-- RED before final fix A6 (Ruling 33, PROPOSAL): a knocked body took the shot (DamageManager calls it IFramed). Its
	-- control: the same body standing takes the shot meant for the target behind it.
	KnockedIsNoShield = function(T)
		Guard(function()
			local S = Shooter("Revolver")
			local Front = Target(10, "GunKit_Front")
			local Back = Target(20, "GunKit_Back")
			GunKit.Settle()
			local R1 = GunKit.Shot(S, AimAt(S, Back))
			T.Eq(R1[1] and R1[1].Victim, Front, "control: a standing body in front takes the shot")
			Front:SetAttribute("Knocked", true)
			local R2 = GunKit.Shot(S, AimAt(S, Back))
			T.Eq(R2[1] and R2[1].Victim, Back, "the victim with a knocked body in front")
			T.Eq(R2[1] and R2[1].Result, "Hit", "the result behind a knocked body")
		end)
	end,

	-- RED before final fix A7: every Model under World.Live marked the cached candidates dirty, the Models inside a gun's
	-- Tool too (a Revolver holds 2, a Renetti 3). The control: a new character in Live does mark it.
	MarkIgnoresTools = function(T)
		Guard(function()
			local H = PositionHistory()
			local S = Shooter("Revolver")
			GunKit.Settle()
			local N0 = H.DirtyMarks()
			assert(WeaponManager.Give(S, "Renetti"), "the Renetti") -- a Tool swap inside a character in Live, while sampling runs
			task.wait(0.1)
			T.Eq(H.DirtyMarks() - N0, 0, "dirty marks from a Tool Give inside a character in World.Live")
			GunKit.Dummy(AHEAD * 20, "GunKit_NewInLive")
			task.wait(0.1)
			T.True(H.DirtyMarks() > N0, "control: a new character in World.Live marks the list dirty")
		end)
	end,

	-- guard (Task 7): Fan the Hammer with FAN_LEFT rounds fires them and starts the reload; its third strike spends
	-- nothing. Through the real WeaponSkill request; a Play-only wrapper on WeaponManager.Fire (removed by After) records
	-- the rounds each strike spent. The control is FanRefusedCostsNothing's three-round Fan.
	FanUnderThreeRounds = function(T)
		local Fire = WeaponManager.Fire
		PlayerGun(function(C)
			local Aim, Skill = Request("Aim"), Request("WeaponSkill")
			C:SetAttribute("WeaponSkillReadyAt", nil)
			ResourceManager.Set(C, "Stamina", ResourceManager.Max(C, "Stamina"))
			C:SetAttribute("Ammo", FAN_LEFT)
			local Spent = {}
			WeaponManager.Fire = function(Character, ...)
				local Was = Character:GetAttribute("Ammo") or 0
				local Results = Fire(Character, ...)
				if Character == C then table.insert(Spent, tostring(Was - (Character:GetAttribute("Ammo") or 0))) end
				return Results
			end
			Aim(Player, AHEAD)
			Skill(Player) -- (AttackRunner.Run waits for the whole Fan)
			T.Eq(table.concat(Spent, ","), "1,1,0", "rounds spent by each of the Fan's strikes")
			T.Eq(C:GetAttribute("Ammo"), 0, "Ammo after the Fan")
			T.True((C:GetAttribute("ReloadingUntil") or 0) > workspace:GetServerTimeNow(), "the reload is running")
		end, function()
			WeaponManager.Fire = Fire
		end)
	end,

	-- guard (Task 5 fix): shooting mode can't be turned on in the water; the control turns it on out of the water
	ModeOnRefusedWhileSwimming = function(T)
		PlayerGun(function(C)
			local Shoot = ShootRequest()
			C:SetAttribute("Traversal", "Swim")
			Shoot(Player, "Mode", true)
			T.Eq(C:GetAttribute("ShootingMode"), nil, "shooting mode after a Mode request while Traversal = Swim")
			C:SetAttribute("Traversal", nil)
			Shoot(Player, "Mode", true)
			T.Eq(C:GetAttribute("ShootingMode"), true, "control: shooting mode after a Mode request on dry land")
		end)
	end,

	-- guard (Task 5): the Fire request's own limiter is wired into the real handler. Its aims are counted by a Play-only
	-- wrapper on WeaponManager.SetAim (removed by After): a refused request returns before SetAim. Not in shooting mode,
	-- so nothing fires. The control: REFILL s later one more gets through.
	ShootLimiterWired = function(T)
		local SetAim = WeaponManager.SetAim
		PlayerGun(function(C)
			local Shoot = ShootRequest()
			local Aims = 0
			WeaponManager.SetAim = function(Character, ...)
				if Character == C then Aims += 1 end
				return SetAim(Character, ...)
			end
			task.wait(BURST / RATE) -- a full bucket
			for _ = 1, BURST + 3 do Shoot(Player, "Fire", AHEAD) end
			T.Eq(Aims, BURST, "aims taken from " .. (BURST + 3) .. " Fire requests at once")
			task.wait(REFILL)
			Aims = 0
			for _ = 1, 3 do Shoot(Player, "Fire", AHEAD) end
			T.Eq(Aims, 1, "control: aims taken from 3 more requests " .. REFILL .. " s later")
		end, function()
			WeaponManager.SetAim = SetAim
		end)
	end,
}

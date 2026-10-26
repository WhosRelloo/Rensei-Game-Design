-- Test_GunAim (gun rework 2026-10-25, Task 2): the pure maths of a shot (Rensei.GunAim). Every expected number is worked
-- by hand here, as a constant. Settings passed in (MaxYaw 100, MaxPitch 70, TouchAssist 2.5) are the plan's PROPOSAL
-- TuningConfig.Weapons.Guns.Aim values, used here as fixed test inputs.
local GunAim = require(game.ReplicatedStorage.Modules.Data.Rensei.GunAim)

local MAX_YAW, MAX_PITCH = 100, 70 -- PROPOSAL (the plan's Aim.MaxYaw / Aim.MaxPitch)
local ASSIST_DEG, ASSIST_DIST = 2.5, 60 -- PROPOSAL (Aim.TouchAssist; 60 = the Renetti's range)

local function Off(Deg, Dist) -- a point Dist studs out, Deg degrees right of -Z
	local R = math.rad(Deg)
	return Vector3.new(math.sin(R), 0, -math.cos(R)) * Dist
end

return {
	ParallaxShotMeetsCrosshair = function(T)
		local M = Vector3.new(0, 6.5, 0) -- the muzzle
		local C = Vector3.new(1.75, 8, 12) -- an over-the-shoulder camera
		local P = Vector3.new(0, 6.5, -40) -- the crosshair's target: a head's centre
		local BoxCF, Size = CFrame.new(P), Vector3.new(2, 2, 2)
		local CamDir = (P - C).Unit
		local Cast = function(From, Vec)
			local Tt = GunAim.RayBox(From, Vec.Unit, Vec.Magnitude, BoxCF, Size)
			return Tt and (From + Vec.Unit * Tt) or nil
		end
		-- Control: a shot parallel to the camera ray, from the muzzle, misses. At z = -40 it is at x = -1.75 * 40/52
		-- = -1.346 and y = 6.5 - 1.5 * 40/52 = 5.346, outside the box's x in [-1, 1] and y in [5.5, 7.5].
		T.Eq(GunAim.RayBox(M, CamDir, 120, BoxCF, Size), nil, "control: the parallel shot misses")
		local Point = GunAim.AimPoint(C, CamDir, M, 120, Cast)
		T.Near(Point.Z, -39, 1e-4, "the aim point is on the box's near face")
		local Dir = GunAim.Direction(M, Point, CamDir)
		T.True(GunAim.RayBox(M, Dir, 120, BoxCF, Size) ~= nil, "the shot from the muzzle to the aim point hits the head")
	end,

	AimPointSkipsBehindShooter = function(T)
		local M = Vector3.new(0, 6.5, 0)
		local C = Vector3.new(0, 8, 12)
		local CamDir = Vector3.new(0, 0, -1)
		local Wall = function(From, Vec) -- a wall at z = 9: 3 studs in front of the camera, between it and the muzzle
			local Z0, Z1 = From.Z, From.Z + Vec.Z
			if Z0 >= 9 and Z1 <= 9 then return Vector3.new(From.X, From.Y, 9) end
			return nil
		end
		T.Eq(Wall(C, CamDir * 120), Vector3.new(0, 8, 9), "control: a cast from the camera meets the wall")
		-- The ray starts level with the muzzle (z = 0), so it ends at z = -120 with nothing hit.
		T.Eq(GunAim.AimPoint(C, CamDir, M, 120, Wall), Vector3.new(0, 8, -120))
	end,

	DirectionFallsBackWhenClose = function(T)
		-- Guard (passes with today's rule too); ParallaxShotMeetsCrosshair is its control.
		local M = Vector3.new(0, 6.5, 0)
		local Close = M + Vector3.new(0.6, 0, -0.8) -- 1 stud ahead, off the camera's line
		T.Eq(GunAim.Direction(M, Close, Vector3.new(0, 0, -2)), Vector3.new(0, 0, -1))
	end,

	ValidateAccepts = function(T)
		local D = GunAim.Validate(Vector3.new(0, 0, -1), Vector3.new(0, 0, -1), MAX_YAW, MAX_PITCH)
		T.True(typeof(D) == "Vector3", "a Vector3")
		T.Near(D.Magnitude, 1, 1e-6, "unit")
		T.Near(D.Z, -1, 1e-6)
	end,

	ValidateRefuses = function(T)
		local Look = Vector3.new(0, 0, -1)
		local R80 = math.rad(80)
		local R150 = math.rad(150)
		local Cases = {
			{Vector3.new(0 / 0, 0, 1), "malformed"},
			{Vector3.zero, "length"},
			{Vector3.new(0, 0, -3), "length"},
			{Vector3.new(0, math.sin(R80), -math.cos(R80)), "pitch"}, -- 80 degrees up
			{Vector3.new(-math.sin(R150), 0, -math.cos(R150)), "behind"}, -- 150 degrees from the look
		}
		for _, Case in ipairs(Cases) do
			local D, Why = GunAim.Validate(Case[1], Look, MAX_YAW, MAX_PITCH)
			T.Eq(D, nil, Case[2])
			T.Eq(Why, Case[2])
		end
	end,

	RayBoxHits = function(T)
		local O, D, Size = Vector3.new(0, 0, 10), Vector3.new(0, 0, -1), Vector3.new(2, 2, 2)
		T.Near(GunAim.RayBox(O, D, 100, CFrame.new(), Size), 9, 1e-6, "face on")
		T.Near(GunAim.RayBox(O, D, 100, CFrame.Angles(0, math.rad(45), 0), Size), 10 - math.sqrt(2), 1e-6, "corner on")
		T.Near(GunAim.RayBox(Vector3.zero, D, 100, CFrame.new(), Size), 0, 1e-6, "from inside")
		T.Eq(GunAim.RayBox(Vector3.new(5, 0, 10), D, 100, CFrame.new(), Size), nil, "parallel, outside")
	end,

	RewindInterpolates = function(T)
		local H = {{T = 0, CF = CFrame.new(0, 0, 0)}, {T = 1, CF = CFrame.new(10, 0, 0)}}
		T.Near(GunAim.Rewind(H, 0.25).Position.X, 2.5, 1e-6, "between")
		T.Near(GunAim.Rewind(H, -1).Position.X, 0, 1e-6, "before the first")
		T.Near(GunAim.Rewind(H, 5).Position.X, 10, 1e-6, "after the last")
		T.Eq(GunAim.Rewind({}, 0.5), nil, "empty")
	end,

	RewindTimeCapped = function(T)
		local Cfg = {Interp = 0.1, MaxRewind = 0.25}
		T.Near(GunAim.RewindTime(0.05, Cfg), 0.15)
		T.Near(GunAim.RewindTime(0.4, Cfg), 0.25)
		T.Near(GunAim.RewindTime("x", Cfg), 0.1)
	end,

	RangeMult = function(T)
		local Passive = {Range = 12, Mult = 1.2}
		local F = {Start = 20, End = 70, Min = 0.5}
		T.Near(GunAim.RangeMult(5, Passive, F), 1.2)
		T.Near(GunAim.RangeMult(20, Passive, F), 1)
		T.Near(GunAim.RangeMult(45, Passive, F), 0.75)
		T.Near(GunAim.RangeMult(80, Passive, F), 0.5)
	end,

	MasteredNeverDeepens = function(T)
		local Old = 1 + (0.5 - 1) * 1.75 -- control: the old rule deepens a 0.5 falloff to 0.125
		T.Near(Old, 0.125)
		T.Near(GunAim.Mastered(0.5, 1.75), 0.5)
		T.Near(GunAim.Mastered(1.2, 1.75), 1.35)
	end,

	Flinch = function(T)
		local Cfg = {FlinchRange = 25}
		T.Eq(GunAim.Flinches(24.9, Cfg), true)
		T.Eq(GunAim.Flinches(25.1, Cfg), false)
	end,

	AssistPicks = function(T)
		local O, Dir = Vector3.zero, Vector3.new(0, 0, -1)
		local A, B = Off(2, 30), Off(-1, 30)
		T.Eq(GunAim.Assist(O, Dir, {A, B}, ASSIST_DEG, ASSIST_DIST), B, "the nearer one")
		T.Eq(GunAim.Assist(O, Dir, {Off(3, 30)}, ASSIST_DEG, ASSIST_DIST), nil, "3 degrees is too far off")
		T.Eq(GunAim.Assist(O, Dir, {Off(2, 70)}, ASSIST_DEG, ASSIST_DIST), nil, "beyond MaxDist")
	end,

	SpreadBounded = function(T)
		local Rng = Random.new(7)
		local Dir = Vector3.new(0, 0, -1)
		local Limit = 2.5 + 1e-6
		local Wide = false
		for _ = 1, 200 do
			local V = GunAim.Spread(Dir, 2.5, Rng)
			local Yaw = math.deg(math.asin(math.clamp(math.abs(V.X), 0, 1)))
			local Pitch = math.abs(math.deg(math.atan2(V.Y, -V.Z)))
			T.True(Yaw <= Limit, "yaw " .. Yaw)
			T.True(Pitch <= Limit, "pitch " .. Pitch)
			if Yaw > 1.25 or Pitch > 1.25 then Wide = true end
		end
		T.True(Wide, "some sample spreads past half the cone")
		T.Eq(GunAim.Spread(Dir, 0, Rng), Dir, "Deg 0")
	end,

	DPS = function(T)
		local Shot = {Startup = 0.12, Active = 0.02, Recovery = 0.2}
		local Stats = {Damage = 20, Magazine = 6, Reload = 2.0, Recovery = 0.36}
		T.Near(GunAim.Interval(Shot, Stats), 0.5)
		local Burst, Sustained = GunAim.DPS(Shot, Stats)
		T.Near(Burst, 40)
		T.Near(Sustained, 24)
	end,

	LimiterCaps = function(T)
		local Allow, Forget = GunAim.Limiter(5, 5)
		for I = 1, 5 do T.Eq(Allow("a", 0), true, "shot " .. I) end
		T.Eq(Allow("a", 0), false, "the 6th")
		T.Eq(Allow("a", 0.2), true, "one token back")
		T.Eq(Allow("a", 0.2), false, "and spent")
		T.Eq(Allow("b", 0.2), true, "a separate key")
		Forget("a")
		T.Eq(Allow("a", 0.2), true, "forgotten")
	end,

	-- guards (final fix A9: Task 2's review minors). They pass with today's GunAim; each pairs an accept with a refuse (or
	-- a hit with a miss) a hair apart, so a moved limit or a dropped branch fails one side.
	RewindThreeSamples = function(T)
		local H = {{T = 0, CF = CFrame.new(0, 0, 0)}, {T = 1, CF = CFrame.new(10, 0, 0)}, {T = 2, CF = CFrame.new(30, 0, 0)}}
		T.Near(GunAim.Rewind(H, 0.5).Position.X, 5, 1e-6, "between the first two")
		T.Near(GunAim.Rewind(H, 1).Position.X, 10, 1e-6, "on the middle sample")
		T.Near(GunAim.Rewind(H, 1.5).Position.X, 20, 1e-6, "between the last two (10 + 20 x 0.5)")
	end,

	ValidateJustInside = function(T)
		local Look = Vector3.new(0, 0, -1)
		local function At(YawDeg, PitchDeg)
			local Y, P = math.rad(YawDeg), math.rad(PitchDeg)
			return Vector3.new(-math.sin(Y) * math.cos(P), math.sin(P), -math.cos(Y) * math.cos(P))
		end
		T.True(GunAim.Validate(At(99.9, 0), Look, MAX_YAW, MAX_PITCH) ~= nil, "yaw 99.9 (MaxYaw 100)")
		T.Eq(select(2, GunAim.Validate(At(100.1, 0), Look, MAX_YAW, MAX_PITCH)), "behind", "yaw 100.1")
		T.True(GunAim.Validate(At(0, 69.9), Look, MAX_YAW, MAX_PITCH) ~= nil, "pitch 69.9 up (MaxPitch 70)")
		T.True(GunAim.Validate(At(0, -69.9), Look, MAX_YAW, MAX_PITCH) ~= nil, "pitch 69.9 down")
		T.Eq(select(2, GunAim.Validate(At(0, 70.1), Look, MAX_YAW, MAX_PITCH)), "pitch", "pitch 70.1 up")
		T.True(GunAim.Validate(Look * 0.51, Look, MAX_YAW, MAX_PITCH) ~= nil, "length 0.51")
		T.True(GunAim.Validate(Look * 1.49, Look, MAX_YAW, MAX_PITCH) ~= nil, "length 1.49")
		T.Eq(select(2, GunAim.Validate(Look * 0.49, Look, MAX_YAW, MAX_PITCH)), "length", "length 0.49")
		T.Eq(select(2, GunAim.Validate(Look * 1.51, Look, MAX_YAW, MAX_PITCH)), "length", "length 1.51")
	end,

	RayBoxBehindAndBeyond = function(T)
		local D, Size = Vector3.new(0, 0, -1), Vector3.new(2, 2, 2)
		T.Eq(GunAim.RayBox(Vector3.zero, D, 100, CFrame.new(0, 0, 10), Size), nil, "a box behind the origin")
		T.Near(GunAim.RayBox(Vector3.zero, D, 100, CFrame.new(0, 0, -10), Size), 9, 1e-6, "control: the same box ahead")
		T.Eq(GunAim.RayBox(Vector3.zero, D, 8.9, CFrame.new(0, 0, -10), Size), nil, "its face (9 out) beyond MaxDist 8.9")
		T.Near(GunAim.RayBox(Vector3.zero, D, 9.1, CFrame.new(0, 0, -10), Size), 9, 1e-6, "control: MaxDist 9.1")
	end,

	AssistNearestListedFirst = function(T)
		local O, Dir = Vector3.zero, Vector3.new(0, 0, -1)
		local A, B = Off(2, 30), Off(-1, 30)
		T.Eq(GunAim.Assist(O, Dir, {B, A}, ASSIST_DEG, ASSIST_DIST), B, "the nearer one, listed first")
	end,

	DirectionBehindFallsBack = function(T)
		local M = Vector3.new(0, 6.5, 0)
		local CamDir = Vector3.new(0, 0, -1)
		-- an aim point 10 studs behind the muzzle (past MinDist 2): the camera's direction
		T.Eq(GunAim.Direction(M, M + Vector3.new(3, 0, 10).Unit * 10, CamDir), CamDir, "an aim point behind the muzzle")
		-- control: the mirror point ahead gives the line to it
		local Ahead = Vector3.new(3, 0, -10).Unit
		local Got = GunAim.Direction(M, M + Ahead * 10, CamDir)
		T.Near((Got - Ahead).Magnitude, 0, 1e-6, "control: an aim point ahead gives the line to it")
	end,

	CandidatesTwoLevels = function(T)
		local Live = Instance.new("Folder")
		local function Rig(Name, Parent, WithHumanoid)
			local M = Instance.new("Model")
			M.Name = Name
			if WithHumanoid then Instance.new("Humanoid").Parent = M end
			M.Parent = Parent
			return M
		end
		local A = Rig("A", Live, true)
		Rig("B", Live, false)
		local Townsfolk = Instance.new("Folder")
		Townsfolk.Name = "Townsfolk"
		Townsfolk.Parent = Live
		local C = Rig("C", Townsfolk, true)
		local Ok, Err = pcall(function()
			local All = GunAim.Candidates(Live)
			T.Eq(#All, 2, "two candidates")
			T.True((All[1] == A and All[2] == C) or (All[1] == C and All[2] == A), "A and C")
			local Direct = GunAim.Candidates(Live, true)
			T.Eq(#Direct, 1, "direct only")
			T.Eq(Direct[1], A)
		end)
		Live:Destroy()
		if not Ok then error(Err, 0) end
	end,
}

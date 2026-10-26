-- SwimLogic (swim revamp Task 2, 2026-10-26): the PURE maths of swimming, shared by the client's swim controller
-- (Modules.Managers.SwimController) and the server (SwimService). No services and no Instances: it takes Vector3 and
-- CFrame values and TuningConfig.Swim (T), so Test_SwimLogic checks it without a character.
--
--   Surface: W A S D are level, relative to the camera's YAW only (looking down never pulls you under).
--   Under:   W follows the camera's full look vector (pitch clamped to +-MaxPitch); A / D strafe level; Up / Down
--            (Space / Ctrl) rise and sink; with no input you drift up slowly (Drift).
-- Every number is in TuningConfig.Swim and is a PROPOSAL (Documents/specs/2026-10-25-swimming-revamp-design.md).
local SwimLogic = {}

-- the camera's horizontal forward and right; a camera looking straight up or down uses its up vector for the yaw
local function Flat(CamCF)
	local Look = CamCF.LookVector
	local F = Vector3.new(Look.X, 0, Look.Z)
	if F.Magnitude < 1e-4 then
		local Up = CamCF.UpVector * (Look.Y < 0 and 1 or -1)
		F = Vector3.new(Up.X, 0, Up.Z)
	end
	if F.Magnitude < 1e-6 then F = Vector3.new(0, 0, -1) end
	F = F.Unit
	local R = Vector3.new(-F.Z, 0, F.X) -- F rotated 90 degrees to the right (for -Z forward, +X right)
	return F, R
end

-- Velocity(Mode, Move, CamCF, Input, Speed, T) -> Vector3
--   Mode "Surface" | "Under"; Move = the control module's move vector (x = right, z = -forward, |Move| <= 1);
--   Input = {Up, Down, Sprint}; Speed = the walk speed x SpeedMultiplier.
function SwimLogic.Velocity(Mode, Move, CamCF, Input, Speed, T)
	Input = Input or {}
	local F, R = Flat(CamCF)
	local Mult = Input.Sprint and T.SprintMult or 1
	local Fwd, Side = -Move.Z, Move.X
	if Mode ~= "Under" then
		local V = F * Fwd + R * Side
		if V.Magnitude > 1 then V = V.Unit end
		return V * Speed * Mult
	end
	-- underwater: forward is the look vector, its pitch clamped
	local Max = math.rad(T.MaxPitch)
	local Pitch = math.clamp(math.asin(math.clamp(CamCF.LookVector.Y, -1, 1)), -Max, Max)
	local Look = F * math.cos(Pitch) + Vector3.new(0, math.sin(Pitch), 0)
	local V = Look * Fwd + R * Side
	if V.Magnitude > 1 then V = V.Unit end
	V = V * Speed * T.UnderSpeedMult * Mult
	local Y = 0
	if Input.Up then Y += T.AscendSpeed end
	if Input.Down then Y -= T.DescendSpeed end
	if Move.Magnitude < T.MoveThreshold and not Input.Up and not Input.Down then Y += T.Drift end
	return V + Vector3.new(0, Y, 0)
end

-- the vertical speed that holds the root RootBelowSurface under the water's surface
function SwimLogic.SurfaceHold(RootY, SurfaceY, T)
	local Target = SurfaceY - T.RootBelowSurface
	return math.clamp((Target - RootY) * T.SurfaceHoldGain, -T.SurfaceHoldMax, T.SurfaceHoldMax)
end

-- HeadDepth = the surface's Y - the head's Y (positive = under). Surface -> Under only by a dive, or when something
-- else (a knockback) has sunk the head well under; Under -> Surface when the head breaks the surface.
function SwimLogic.ModeFor(Current, HeadDepth, T)
	if Current == "Under" then
		return HeadDepth <= 0 and "Surface" or "Under"
	end
	if HeadDepth > T.SurfaceBand * 4 then return "Under" end
	return "Surface"
end

function SwimLogic.CanDive(WaterDepth, T)
	return WaterDepth >= T.DiveMinDepth
end

-- V's pitch in radians (negative = down), clamped to +-MaxPitch; 0 for a level or zero V
function SwimLogic.Pitch(V, T)
	if V.Magnitude < 1e-6 then return 0 end
	local H = Vector3.new(V.X, 0, V.Z).Magnitude
	local Max = math.rad(T.MaxPitch)
	return math.clamp(math.atan2(V.Y, H), -Max, Max)
end

-- one step of the air meter: drains under water (faster sprinting), refills above it, clamped to 0..BreathMax
function SwimLogic.BreathStep(Breath, Under, Sprint, Dt, T)
	if Under then
		Breath -= Dt * (Sprint and T.UnderSprintBreathMult or 1)
	else
		Breath += T.BreathRefill * Dt
	end
	return math.clamp(Breath, 0, T.BreathMax)
end

-- a ledge LedgeAbove studs over the water and Distance studs away can be climbed onto from the surface
function SwimLogic.CanClimbOut(LedgeAbove, Distance, T)
	return LedgeAbove > 0 and LedgeAbove <= T.ClimbOutHeight and Distance <= T.ClimbOutReach
end

-- the fastest a swimmer may go: the base walk speed x SpeedMultiplier (x SprintMult while sprinting)
function SwimLogic.MaxSpeed(Base, Mult, Sprinting, T)
	return Base * Mult * (Sprinting and T.SprintMult or 1)
end

-- the server's speed check: one more strike when a step moved further than allowed (with slack), else back to 0
function SwimLogic.SpeedStrike(Strikes, Moved, Dt, MaxSpeed, T)
	if Moved > MaxSpeed * T.SpeedSlackMult * Dt + T.SpeedSlackFlat then return Strikes + 1 end
	return 0
end

return SwimLogic

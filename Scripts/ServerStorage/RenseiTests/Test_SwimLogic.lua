-- Test_SwimLogic (swim revamp Task 2, 2026-10-26): pure checks of Rensei.SwimLogic, the swim maths the client
-- controller (Managers.SwimController) and the server (SwimService) share. No character, no services: run with
-- TestKit.Run(require(Test_SwimLogic)) in the Play VM (LMRunSuite) or in Edit. Every input and every expected number
-- is written here by hand (from the PROPOSAL tuning in TuningConfig.Swim), never read back from SwimLogic itself.
local SL = require(game.ReplicatedStorage.Modules.Data.Rensei.SwimLogic)
local Sw = require(game.ReplicatedStorage.Modules.Data.Rensei.TuningConfig).Swim

local O = Vector3.new(0, 10, 0)
-- a camera at O looking along -Z, pitched Deg degrees down (negative = up)
local function Cam(Deg)
	return CFrame.new(O) * CFrame.Angles(-math.rad(Deg), 0, 0)
end
local W = Vector3.new(0, 0, -1) -- the control module's "forward" (z = -forward)
local Still = Vector3.zero
local None = {Up = false, Down = false, Sprint = false}

return {
	SurfaceIgnoresPitch = function(T)
		local V = SL.Velocity("Surface", W, Cam(60), None, 16, Sw)
		T.Near(V.Y, 0, 1e-9, "level at the surface")
		T.Near(V.Magnitude, 16, 1e-6, "full speed")
		T.True(V.Z < -15.9, "forward along the camera's yaw")
	end,
	UnderFollowsPitch = function(T)
		local CF = Cam(45)
		local V = SL.Velocity("Under", W, CF, None, 16, Sw)
		T.True(V.Magnitude > 0 and V.Unit:Dot(CF.LookVector) > 0.99, "along the look vector: " .. tostring(V))
		T.True(V.Y < 0, "going down")
		T.Near(V.Magnitude, 16 * 0.85, 1e-6, "underwater speed")
	end,
	UnderStrafeIsLevel = function(T)
		local V = SL.Velocity("Under", Vector3.new(1, 0, 0), Cam(45), None, 16, Sw)
		T.Near(V.Y, 0, 1e-9, "strafe stays level")
		T.True(V.X > 13, "to the camera's right: " .. tostring(V))
	end,
	UpAndDown = function(T)
		T.Near(SL.Velocity("Under", Still, Cam(0), {Up = true}, 16, Sw).Y, 10, 1e-9, "Up")
		T.Near(SL.Velocity("Under", Still, Cam(0), {Down = true}, 16, Sw).Y, -10, 1e-9, "Down")
		T.Near(SL.Velocity("Under", Still, Cam(0), {Up = true, Down = true}, 16, Sw).Y, 0, 1e-9, "both cancel")
		T.Near(SL.Velocity("Surface", Still, Cam(0), {Up = true, Down = true}, 16, Sw).Y, 0, 1e-9, "ignored at the surface")
	end,
	Drift = function(T)
		local V = SL.Velocity("Under", Still, Cam(30), None, 16, Sw)
		T.Near(V.X, 0, 1e-9) T.Near(V.Z, 0, 1e-9)
		T.Near(V.Y, 1.5, 1e-9, "a slow drift up with no input")
		local M = SL.Velocity("Under", Vector3.new(1, 0, 0), Cam(0), None, 16, Sw)
		T.Near(M.Y, 0, 1e-9, "no drift while moving")
	end,
	Sprint = function(T)
		local V = SL.Velocity("Surface", W, Cam(0), {Sprint = true}, 16, Sw)
		T.Near(V.Magnitude, 16 * 1.6, 1e-6, "sprint x1.6")
		local U = SL.Velocity("Under", W, Cam(0), {Sprint = true}, 16, Sw)
		T.Near(U.Magnitude, 16 * 0.85 * 1.6, 1e-6, "underwater sprint")
	end,
	PitchClamp = function(T)
		local V = SL.Velocity("Under", W, Cam(90), None, 16, Sw)
		T.True(V.Magnitude > 1, "still moves looking straight down")
		T.True(math.abs(SL.Pitch(V, Sw)) <= math.rad(80) + 1e-6, "pitch within 80: " .. math.deg(SL.Pitch(V, Sw)))
		T.Near(SL.Pitch(Vector3.new(0, 0, -5), Sw), 0, 1e-9, "level")
		T.Near(SL.Pitch(Vector3.zero, Sw), 0, 1e-9, "zero")
		T.Near(SL.Pitch(Vector3.new(0, -10, 0), Sw), -math.rad(80), 1e-6, "straight down clamps")
		T.Near(SL.Pitch(Vector3.new(0, -1, -1), Sw), -math.rad(45), 1e-6, "45 down")
	end,
	CanDive = function(T)
		T.Eq(SL.CanDive(4.4, Sw), false, "4.4")
		T.Eq(SL.CanDive(4.5, Sw), true, "4.5")
		T.Eq(SL.CanDive(5.2, Sw), true, "a Ye pool")
		T.Eq(SL.CanDive(4.2, Sw), false, "a creek channel")
	end,
	ModeFor = function(T)
		T.Eq(SL.ModeFor("Under", -0.1, Sw), "Surface", "head breaks the surface")
		T.Eq(SL.ModeFor("Under", 1.0, Sw), "Under", "still under")
		T.Eq(SL.ModeFor("Surface", 1.0, Sw), "Surface", "a bob is not a dive")
		T.Eq(SL.ModeFor("Surface", 3.0, Sw), "Under", "sunk well under by something else")
		T.Eq(SL.ModeFor(nil, 0, Sw), "Surface", "starts at the surface")
	end,
	BreathStep = function(T)
		T.Near(SL.BreathStep(15, true, false, 1, Sw), 14, 1e-9, "drain")
		T.Near(SL.BreathStep(15, true, true, 1, Sw), 13.5, 1e-9, "sprint drain")
		T.Near(SL.BreathStep(10, false, false, 1, Sw), 15, 1e-9, "refill")
		T.Near(SL.BreathStep(14, false, false, 1, Sw), 15, 1e-9, "refill caps at the maximum")
		T.Near(SL.BreathStep(0.2, true, false, 1, Sw), 0, 1e-9, "floors at 0")
	end,
	CanClimbOut = function(T)
		T.Eq(SL.CanClimbOut(4.5, 3, Sw), true, "at the limits")
		T.Eq(SL.CanClimbOut(4.6, 1, Sw), false, "too high")
		T.Eq(SL.CanClimbOut(2, 3.1, Sw), false, "too far")
		T.Eq(SL.CanClimbOut(0, 1, Sw), false, "no ledge above the water")
	end,
	SpeedStrike = function(T)
		local Max = 16
		T.Eq(SL.SpeedStrike(0, 3, 0.15, Max, Sw), 0, "a normal step")
		local S = SL.SpeedStrike(0, 20, 0.15, Max, Sw) -- over 16 x 1.5 x 0.15 + 8 = 11.6
		T.Eq(S, 1, "one strike")
		S = SL.SpeedStrike(S, 20, 0.15, Max, Sw)
		S = SL.SpeedStrike(S, 20, 0.15, Max, Sw)
		T.Eq(S, 3, "three in a row")
		T.Eq(SL.SpeedStrike(S, 11, 0.15, Max, Sw), 0, "a normal step resets")
		T.Near(SL.MaxSpeed(16, 1.25, true, Sw), 16 * 1.25 * 1.6, 1e-9, "MaxSpeed with sprint")
		T.Near(SL.MaxSpeed(16, 1, false, Sw), 16, 1e-9, "MaxSpeed")
	end,
	SurfaceHold = function(T)
		local Target = 5.2 - Sw.RootBelowSurface
		T.Near(SL.SurfaceHold(Target - 2, 5.2, Sw), 8, 1e-9, "2 below: up, clamped to 8")
		T.Near(SL.SurfaceHold(Target, 5.2, Sw), 0, 1e-9, "at the target")
		T.Near(SL.SurfaceHold(Target + 0.5, 5.2, Sw), -3, 1e-9, "0.5 above: down at 6/stud")
	end,
}

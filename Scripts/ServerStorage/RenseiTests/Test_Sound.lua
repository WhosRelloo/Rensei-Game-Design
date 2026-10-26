-- Plan 2 (S2): the pure sound / light / crouch maths in Rensei.Perception.
local P = require(game.ReplicatedStorage.Modules.Data.Rensei.Perception)
return {
	FootstepsByFloor = function(T)
		T.Eq(P.StepNoise("Grass", 1, false), 4, "walking on grass")
		T.Eq(P.StepNoise("Wood", 1, false), 7, "walking on wood")
		T.Eq(P.StepNoise("Metal", 1, false), 9, "walking on metal")
		T.Eq(P.StepNoise("Pebble", 1, false), 9, "walking on gravel")
		T.Eq(P.StepNoise("Metal", 1.5, false), 18, "running on metal: x2")
		T.Eq(P.StepNoise("Metal", 2, true), 0, "crouched: silent")
		T.Eq(P.StepNoise("Concrete", 1, false), P.StepRadius, "any other floor")
		T.True(P.StepNoise("Metal", 1.5, false) > P.StepNoise("Grass", 1, false), "running on metal carries further than walking on grass")
	end,
	WallsMuffle = function(T)
		T.Near(P.Muffled(20, 0), 20)
		T.Near(P.Muffled(20, 1), 12, 1e-6, "one wall: -40%")
		T.Near(P.Muffled(20, 2), 7.2, 1e-6, "two walls")
		T.Near(P.Muffled(20, 9), P.Muffled(20, P.MaxWalls), 1e-9, "capped at MaxWalls")
	end,
	SoundRadii = function(T)
		T.Eq(P.Sounds.Gunshot, 60)
		T.Eq(P.Sounds.Cast, 30)
		T.Eq(P.Sounds.Hit, 20)
		T.Eq(P.Sounds.Land, 12)
		T.Eq(P.Sounds.Roll, 10)
		T.Eq(P.Sounds.Splash, 12)
	end,
	ExposureToSight = function(T)
		T.Near(P.ExposureMult(0), 0.2, 1e-9, "deep shadow")
		T.Near(P.ExposureMult(1), 1.2, 1e-9, "bright light")
		T.Near(P.ExposureMult(0.5), 0.7, 1e-9)
		T.Near(P.ExposureMult(5), 1.2, 1e-9, "clamped")
	end,
	Daylight = function(T)
		T.Eq(P.Daylight(14.5), 1, "afternoon (the game's fixed clock)")
		T.Eq(P.Daylight(0), P.NightFloor, "midnight")
		T.True(P.Daylight(7.5) > P.NightFloor and P.Daylight(7.5) < 1, "dawn ramps")
		T.True(P.Daylight(18.5) > P.NightFloor and P.Daylight(18.5) < 1, "dusk ramps")
	end,
	LampFalloff = function(T)
		T.Near(P.LampLight(0, 16, 1), 1)
		T.Near(P.LampLight(4, 16, 1), 0.75)
		T.Near(P.LampLight(4, 16, 0.5), 0.375)
		T.Eq(P.LampLight(16, 16, 1), 0, "nothing at the radius")
	end,
	-- Plan 1 follow-up: a speed buff scales the gaits, so a buffed walk doesn't read as sprinting
	SpeedBuffIsNotSprinting = function(T)
		T.Eq(P.MoveMult(30), 2, "an unbuffed sprint")
		T.Eq(P.MoveMult(30, 1.5), 1, "a x1.5 buffed walk at 30 (30 / 1.5 = 20)")
		T.Eq(P.MoveMult(36, 1.5), 1.5, "a x1.5 buffed run")
		T.Eq(P.MoveMult(16, nil), 1, "no attribute")
	end,
	CrouchHalves = function(T)
		local Stand = P.Rate("Grunt", 12, 1, 1, 1, 1, false)
		local Crouch = P.Rate("Grunt", 12, 1, 1, P.CrouchMult, 1, false)
		T.Near(Crouch, Stand * 0.5, 1e-9)
	end,
	-- swimming revamp (2026-10-26): surfacing after a dive and sprint strokes at the surface make noise
	SwimSounds = function(T)
		T.Eq(P.Sounds.Surface, 6, "surfacing")
		T.Eq(P.Sounds.Stroke, 8, "a sprint stroke")
		T.Eq(P.StrokeEvery, 0.8, "strokes every 0.8 s")
		T.True(P.Sounds.Surface < P.Sounds.Splash, "surfacing is quieter than jumping in")
	end,
}

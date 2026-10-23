-- Play_Clock (Region Foundation Task 2, 2026-10-23): the world clock. The time of day comes from real time
-- (one real minute = one game hour, PROPOSAL 24-minute day); Hold / Release freeze and free it; NightOnly lamps
-- light only at night. Run inside the game VM (LMRunSuite), where WorldClock.Start's loop is running.
local Lighting = game:GetService("Lighting")
local SSS = game:GetService("ServerScriptService")
return {
	HourFollowsRealTime = function(T)
		local C = require(SSS.WorldClock)
		T.Near(C.Hour(0), 0, 1e-6)
		T.Near(C.Hour(60), 1, 1e-6) -- one real minute = one game hour (PROPOSAL 24-minute day)
		T.Near(C.Hour(24 * 60 + 90), 1.5, 1e-6)
	end,
	HoldAndRelease = function(T)
		local C = require(SSS.WorldClock)
		local Ok, Err = pcall(function()
			C.Hold(3)
			task.wait(1.2)
			T.Near(Lighting.ClockTime, 3, 0.01, "held")
			C.Release()
			task.wait(1.2)
			T.Near(Lighting.ClockTime, C.Hour(), 0.05, "released follows real time")
		end)
		C.Release() -- never leave the clock held after a failure
		if not Ok then error(Err, 0) end
	end,
	NightLamps = function(T)
		local C = require(SSS.WorldClock)
		local P = Instance.new("Part") P.Anchored = true P.Position = Vector3.new(0, -400, 0)
		P.Material = Enum.Material.Neon P.Parent = workspace
		P:SetAttribute("NightOnly", true)
		local L = Instance.new("PointLight", P)
		local Ok, Err = pcall(function()
			C.Hold(13) task.wait(1.2)
			T.Eq(L.Enabled, false, "off by day")
			T.True(P.Material ~= Enum.Material.Neon, "no Neon glow by day")
			C.Hold(23) task.wait(1.2)
			T.Eq(L.Enabled, true, "on at night")
			T.Eq(P.Material, Enum.Material.Neon, "its own Neon at night")
		end)
		C.Release() P:Destroy()
		if not Ok then error(Err, 0) end
	end,
	IsNight = function(T)
		local C = require(SSS.WorldClock)
		T.True(C.IsNight(2) and C.IsNight(18) and not C.IsNight(6) and not C.IsNight(12))
	end,
	-- controller ruling 1: Now() is the hour the world shows (the held hour while held, real time otherwise);
	-- the townsfolk schedules (Task 5) read it
	NowFollowsHold = function(T)
		local C = require(SSS.WorldClock)
		C.Hold(7.25)
		T.True(C.IsHeld(), "held")
		T.Eq(C.Now(), 7.25, "held: the held hour")
		C.Release()
		T.True(not C.IsHeld(), "released")
		T.Near(C.Now(), C.Hour(), 1e-6, "running: real time")
	end,
}

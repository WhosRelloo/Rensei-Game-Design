-- Test_Guard (stealth missions Plan 1 Task 2): the pure rules of Rensei.Guard. No Instance is read.
-- Every module is loaded inside each test (Test_Takedown's pattern), so with Rensei.Guard missing each test fails on
-- its own (RED) instead of the whole suite erroring once.
local function Load(Name)
	local M = game.ReplicatedStorage.Modules.Data.Rensei:FindFirstChild(Name)
	assert(M, "Rensei." .. Name .. " is missing")
	return require(M)
end
return {
	Numbers = function(T)
		local G = Load("Guard")
		T.Eq(G.CheckInEvery, 45); T.Eq(G.CheckInGrace, 30); T.Eq(G.RadioTime, 2); T.Eq(G.RadioDelay, 3)
		T.Eq(G.TightSeconds, 600); T.Eq(G.Reinforcements, 2); T.Eq(G.MaxReinforcements, 4); T.Eq(G.ReinforceDelay, 6)
		T.Eq(G.PatrolSpeed, 8); T.Eq(G.PatrolPause, 3); T.Eq(G.FeedRange, 60); T.Eq(G.FeedCount, 8)
	end,
	Types = function(T)
		local G = Load("Guard")
		local P = Load("Perception")
		local Tk = Load("Takedown")
		local Tuning = Load("TuningConfig")
		T.Eq(P.Types.Sentry.Range, 60); T.Eq(P.Types.Sentry.Fill, 0.6)
		T.Eq(P.Types.Officer.Range, 40); T.Eq(P.Types.Officer.Fill, 1.2)
		T.Eq(P.EnemyTypes.StateGuard, "Grunt"); T.Eq(P.EnemyTypes.StateSentry, "Sentry"); T.Eq(P.EnemyTypes.StateOfficer, "Officer")
		T.Eq(Tk.ClassByPerception.Sentry, "Full"); T.Eq(Tk.ClassByPerception.Officer, "Full")
		for _, Name in ipairs({"StateGuard", "StateSentry", "StateOfficer"}) do
			local D = Tuning.Enemies[Name]
			T.True(D ~= nil, Name .. " exists")
			T.Eq(D.Faction, "Authority", Name .. " is Authority")
			T.True(Tk.IsLawFaction(D.Faction), Name .. " is a law faction (assassinated_guard)")
			T.Eq(D.LeashRange, 120, Name .. " leash")
			T.True(G.EnemyTypes[Name] == true, Name .. " listed")
		end
		T.Eq(Tuning.Enemies.StateOfficer.ParryChance, 0.25, "the Officer defends like an Elite")
		T.Eq(Tuning.Enemies.Grunt.Faction, nil, "a bandit has no faction (unchanged)")
	end,
	NextPoint = function(T)
		local G = Load("Guard")
		-- ping-pong over 3 points: 1 2 3 2 1 2
		local I, D = 1, 1
		local Seen = {}
		for _ = 1, 5 do I, D = G.NextPoint(3, I, D, false); table.insert(Seen, I) end
		T.Eq(table.concat(Seen, ","), "2,3,2,1,2")
		-- loop over 3 points: 1 2 3 1 2
		I, D, Seen = 1, 1, {}
		for _ = 1, 4 do I, D = G.NextPoint(3, I, D, true); table.insert(Seen, I) end
		T.Eq(table.concat(Seen, ","), "2,3,1,2")
		-- one point: stays
		T.Eq((G.NextPoint(1, 1, 1, false)), 1)
	end,
	CheckIn = function(T)
		local G = Load("Guard")
		T.Eq(G.CheckInDue(0, 44.9), false); T.Eq(G.CheckInDue(0, 45), true)
		T.Eq(G.Missed(0, 74.9), false); T.Eq(G.Missed(0, 75), true)
	end,
	Sweep = function(T)
		local G = Load("Guard")
		T.Near(G.Sweep(0), 0, 0.01); T.Near(G.Sweep(1.5), 45, 0.01); T.Near(G.Sweep(4.5), -45, 0.01); T.Near(G.Sweep(6), 0, 0.01)
	end,
	Quantize = function(T)
		local G = Load("Guard")
		T.Eq(G.Quantize(0), 0); T.Eq(G.Quantize(0.024), 0); T.Eq(G.Quantize(0.026), 0.05); T.Eq(G.Quantize(1.2), 1); T.Eq(G.Quantize(-1), 0)
	end,
	Tint = function(T)
		local G = Load("Guard")
		local function Same(A, B) return math.abs(A.R - B.R) < 0.01 and math.abs(A.G - B.G) < 0.01 and math.abs(A.B - B.B) < 0.01 end
		T.True(Same(G.Tint(0, "Unaware"), Color3.fromRGB(230, 226, 214)), "pale at 0")
		T.True(Same(G.Tint(0.35, "Suspicious"), Color3.fromRGB(240, 176, 64)), "amber at Suspicion")
		T.True(Same(G.Tint(0.2, "Alert"), Color3.fromRGB(214, 64, 52)), "red at Alert, whatever the meter")
		local Mid = G.Tint(0.175, "Unaware")
		T.True(Mid.G < 226 / 255 and Mid.G > 176 / 255, "between pale and amber on the way up")
	end,
	Marker = function(T)
		local G = Load("Guard")
		local M = G.Marker(0, "Unaware"); T.Eq(M.Show, false)
		M = G.Marker(0.2, "Unaware"); T.Eq(M.Show, true); T.Near(M.Fill, 0.2, 0.001); T.Eq(M.Ring, false); T.Eq(M.Solid, false)
		M = G.Marker(0.5, "Suspicious"); T.Eq(M.Ring, true); T.Eq(M.Solid, false)
		M = G.Marker(0.4, "Alert"); T.Eq(M.Show, true); T.Eq(M.Fill, 1); T.Eq(M.Ring, true); T.Eq(M.Solid, true)
		M = G.Marker(0, "Alert"); T.Eq(M.Show, true, "an Alert guard shows even with no meter for you")
	end,
	ConeFan = function(T)
		local G = Load("Guard")
		local Tris = G.ConeFan(30, 110, 4)
		T.Eq(#Tris, 4)
		local A, B, C = Tris[1][1], Tris[1][2], Tris[4][3]
		T.Near(A.Magnitude, 0, 0.001, "every triangle starts at the feet")
		T.Near(B.Magnitude, 30, 0.01, "the rim is at range")
		-- the fan's edges are 55 degrees either side of straight ahead (-Z)
		T.Near(math.deg(math.atan2(-B.X, -B.Z)), 55, 0.1)
		T.Near(math.deg(math.atan2(-C.X, -C.Z)), -55, 0.1)
		T.Eq(B.Y, 0); T.Eq(C.Y, 0)
	end,
	Nearest = function(T)
		local G = Load("Guard")
		local I, D = G.Nearest({Vector3.new(10, 0, 0), Vector3.new(0, 0, 3), Vector3.new(-5, 0, 0)}, Vector3.zero)
		T.Eq(I, 2); T.Near(D, 3, 0.001)
		T.Eq((G.Nearest({}, Vector3.zero)), nil)
	end,
	Lines = function(T)
		local G = Load("Guard")
		for _, K in ipairs({"Suspicious", "Search", "Radio", "Calm", "Missing"}) do
			T.True(#G.Lines[K] >= 2, K .. " has lines")
			local L = G.Line(K, Random.new(1))
			T.True(type(L) == "string" and #L > 0 and #L <= 60, K .. " line is short")
		end
		T.Eq(G.Line("Nope", Random.new(1)), nil)
	end,
}

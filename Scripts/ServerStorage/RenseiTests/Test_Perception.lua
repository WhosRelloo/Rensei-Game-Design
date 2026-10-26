local P = require(game.ReplicatedStorage.Modules.Data.Rensei.Perception)
local Fwd = Vector3.new(0, 0, -1)
local function Dir(Deg) local R = math.rad(Deg) return Vector3.new(math.sin(R), 0, -math.cos(R)) end
return {
	Cone = function(T)
		T.Eq(P.ConeMult(Fwd, Dir(0)), 1, "ahead")
		T.Eq(P.ConeMult(Fwd, Dir(54)), 1, "inside the 110 cone")
		T.Eq(P.ConeMult(Fwd, Dir(70)), 0.5, "peripheral")
		T.Eq(P.ConeMult(Fwd, Dir(90)), 0, "beside: outside 160")
		T.Eq(P.ConeMult(Fwd, Dir(180)), 0, "behind")
		T.Eq(P.ConeMult(Fwd, Vector3.new(0, 10, 0)), 1, "straight above counts as seen")
	end,
	Movement = function(T)
		T.Eq(P.MoveMult(0), 1); T.Eq(P.MoveMult(16), 1, "walk"); T.Eq(P.MoveMult(24), 1.5, "run")
		T.Eq(P.MoveMult(24.4), 1.5, "run with jitter"); T.Eq(P.MoveMult(30), 2, "sprint")
	end,
	RateFallsOffAndStopsAtRange = function(T)
		local Near = P.Rate("Grunt", 0, 1, 1, 1, 1, false)
		T.Near(Near, P.Types.Grunt.Fill, 1e-9)
		T.Near(P.Rate("Grunt", 15, 1, 1, 1, 1, false), P.Types.Grunt.Fill * (1 - P.Falloff * 0.5), 1e-9)
		T.Eq(P.Rate("Grunt", 31, 1, 1, 1, 1, false), 0, "beyond range")
		T.Eq(P.Rate("Grunt", 5, 0, 1, 1, 1, false), 0, "behind")
		T.Near(P.Rate("Grunt", 0, 1, 1 / 3, 1, 1, false), Near / 3, 1e-9, "a third visible")
		T.Near(P.Rate("Grunt", 0, 1, 1, 1, 1, true), Near * P.CautiousMult, 1e-9, "cautious")
	end,
	TypesCovered = function(T)
		for Enemy, Type in pairs(P.EnemyTypes) do T.True(P.Types[Type] ~= nil, Enemy .. " -> " .. Type) end
		T.True(P.AlwaysAware.TrialFlame and P.AlwaysAware.Sparring, "arena foes keep distance aggro")
	end,
	-- swimming revamp (2026-10-26): a diver (Submerged) is seen at x0.3 of a walking swimmer, not at 0
	SubmergedSight = function(T)
		local Dry = P.Rate("Grunt", 12, 1, 1, P.MoveMult(16), 1, false)
		T.True(type(P.SubmergedMult) == "number", "SubmergedMult exists")
		local Under = P.Rate("Grunt", 12, 1, 1, P.SubmergedMult, 1, false)
		T.Near(Under / Dry, 0.3 / P.MoveMult(16), 1e-6, "x0.3 of the walking rate")
		T.True(Under > 0, "seen, not invisible")
	end,
}

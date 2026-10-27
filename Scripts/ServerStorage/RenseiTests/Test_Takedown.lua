-- Test_Takedown (assassinations Task 2, 2026-10-27): Rensei.Takedown's numbers and pure rules. Every expected value
-- is written by hand here, never read from the module. The module is loaded inside each test, so with it missing
-- every test fails on its own (RED) instead of the whole suite erroring once.
local function Load()
	local M = game.ReplicatedStorage.Modules.Data.Rensei:FindFirstChild("Takedown")
	assert(M, "Rensei.Takedown is missing")
	return require(M)
end

local Look = Vector3.new(0, 0, -1) -- the victim faces -Z, so straight behind it is +Z
local function FromBack(Deg, Dist) -- a point Deg degrees off straight behind the victim, Dist studs away
	local R = math.rad(Deg)
	return Vector3.new(math.sin(R), 0, math.cos(R)) * (Dist or 3)
end

-- every gate passes
local function Good()
	return {
		IsPlayer = false, IsTownsfolk = false, IsEnemy = true, Alive = true, Kind = "Assassinate", Class = "Full",
		Ready = true, PlayerFree = true, PlayerCalm = true, TargetFree = true, Phase = "Unaware", AwareOfYou = 0,
		Dist = 3, Height = 0, Range = 4, Behind = true, Clear = true,
	}
end

return {
	BehindArc = function(T)
		local K = Load()
		T.Eq(K.Behind(Look, Vector3.new(0, 0, 3)), true, "straight behind")
		T.Eq(K.Behind(Look, FromBack(70)), true, "70 degrees off: the arc's edge")
		T.Eq(K.Behind(Look, FromBack(-70)), true, "70 degrees off, the other side")
		T.Eq(K.Behind(Look, FromBack(71)), false, "71 degrees off")
		T.Eq(K.Behind(Look, Vector3.new(3, 0, 0)), false, "the side")
		T.Eq(K.Behind(Look, Vector3.new(0, 0, -3)), false, "in front")
		T.Eq(K.Behind(Look, FromBack(75), 10), true, "75 degrees with 10 slack")
		T.Eq(K.Behind(Look, FromBack(81), 10), false, "81 degrees with 10 slack")
		T.Eq(K.Behind(Look, Vector3.zero), false, "zero offset")
		T.Eq(K.Behind(Vector3.zero, Vector3.new(0, 0, 3)), false, "zero look")
		T.Eq(K.Behind(Look, Vector3.new(0, 5, 3)), true, "height is ignored (ground plane)")
		T.Eq(K.Behind(Vector3.new(0, 1, 0), Vector3.new(0, 0, 3)), false, "a look straight up has no ground direction")
	end,

	Classes = function(T)
		local K = Load()
		T.Eq(K.ClassOf("Grunt", {}), "Full")
		T.Eq(K.ClassOf("Agent", {}), "Full")
		T.Eq(K.ClassOf("Elite", {}), "Chunk")
		T.Eq(K.ClassOf("Hunter", {}), "Chunk")
		T.Eq(K.ClassOf(nil, {}), "Immune", "not tracked by perception")
		T.Eq(K.ClassOf("Grunt", {Boss = true}), "Immune", "boss")
		T.Eq(K.ClassOf("Elite", {TrialFoe = true}), "Immune", "trial foe")
		T.Eq(K.ClassOf("Grunt", {TakedownClass = "Chunk"}), "Chunk", "forced")
		T.Eq(K.ClassOf("Elite", {TakedownClass = "Bogus"}), "Chunk", "a bogus override is ignored")
		T.Eq(K.ClassOf("Grunt", {Boss = true, TakedownClass = "Full"}), "Full", "the override wins over Boss")
		T.Eq(K.ClassOf("Grunt"), "Full", "no Attrs")
	end,

	-- R16 (D4): one derivation of ClassOf's PerceptionType for the server and the client
	PerceptionTypes = function(T)
		local K = Load()
		T.Eq(K.PerceptionTypeOf("Grunt"), "Grunt")
		T.Eq(K.PerceptionTypeOf("AditScavenger"), "Grunt")
		T.Eq(K.PerceptionTypeOf("Elite"), "Elite")
		T.Eq(K.PerceptionTypeOf("FieldAlchemist"), "Agent")
		T.Eq(K.PerceptionTypeOf("WardAlchemist"), "Agent")
		T.Eq(K.PerceptionTypeOf("NoSuchEnemyType"), "Grunt", "unlisted: Grunt (as EnemyService registers it)")
		T.Eq(K.PerceptionTypeOf("TrialFlame"), nil, "a trial foe is not tracked")
		T.Eq(K.PerceptionTypeOf("Sparring"), nil, "an arena foe is not tracked")
		T.Eq(K.PerceptionTypeOf(nil), nil, "no type")
		T.Eq(K.ClassOf(K.PerceptionTypeOf("TrialMetal"), {}), "Immune", "trial foe end to end")
		T.Eq(K.ClassOf(K.PerceptionTypeOf("Elite"), {}), "Chunk", "Elite end to end")
		T.Eq(K.ClassOf(K.PerceptionTypeOf("StoneAlchemist"), {}), "Full", "Agent end to end")
	end,

	-- R8 (spec §18.3): the law factions are the State's (Authority) and the Militia's (Townsfolk); never the Circle
	LawFactions = function(T)
		local K = Load()
		T.Eq(K.IsLawFaction("Authority"), true, "State law")
		T.Eq(K.IsLawFaction("Townsfolk"), true, "Militia law")
		T.Eq(K.IsLawFaction("Circle"), false, "the Circle is not a law")
		T.Eq(K.IsLawFaction("Foundry"), false)
		T.Eq(K.IsLawFaction(nil), false)
		T.Eq(K.IsLawFaction(""), false)
	end,

	CheckOrder = function(T)
		local K = Load()
		local Ok, Why = K.Check(Good())
		T.Eq(Ok, true, "every gate passes (" .. tostring(Why) .. ")")
		T.Eq(Why, nil, "no reason when it passes")
		T.Eq(K.Check((function() local C = Good() C.Kind = "Knockout" return C end)()), true, "a Full knockout passes")
		local Cases = {
			{"IsPlayer", true, "player"},
			{"IsTownsfolk", true, "townsfolk"},
			{"IsEnemy", false, "not_enemy"},
			{"Alive", false, "dead"},
			{"Kind", "Bogus", "kind"},
			{"Class", "Immune", "immune"},
			{"Ready", false, "cooldown"},
			{"PlayerFree", false, "busy"},
			{"PlayerCalm", false, "combat"},
			{"TargetFree", false, "target_busy"},
			{"Phase", "Alert", "alert"},
			{"AwareOfYou", 1, "alert"},
			{"Dist", 4.01, "far"},
			{"Height", -3.01, "far"},
			{"Behind", false, "front"},
			{"Clear", false, "blocked"},
		}
		T.Eq(#Cases, 16, "16 gates")
		for _, Case in ipairs(Cases) do
			local C = Good()
			C[Case[1]] = Case[2]
			local O, W = K.Check(C)
			T.Eq(O, false, Case[1] .. " broken: refused")
			T.Eq(W, Case[3], Case[1] .. " broken: reason")
		end
		-- edges that pass
		for Field, Value in pairs({Dist = 4, Height = -3, AwareOfYou = 0.99, Phase = "Cautious"}) do
			local C = Good()
			C[Field] = Value
			T.Eq(K.Check(C), true, Field .. " = " .. tostring(Value) .. " still passes")
		end
		local C = Good()
		C.Dist, C.Range = 5.5, 5.5 -- the server's Range + RangeSlack
		T.Eq(K.Check(C), true, "the server's slack range")
		C.Dist, C.Range = 4.01, nil
		T.Eq(select(2, K.Check(C)), "far", "no Range given: 4 studs")
	end,

	PlayerFirst = function(T)
		local K = Load()
		local C = {
			IsPlayer = true, IsTownsfolk = true, IsEnemy = false, Alive = false, Kind = "Bogus", Class = "Immune",
			Ready = false, PlayerFree = false, PlayerCalm = false, TargetFree = false, Phase = "Alert", AwareOfYou = 1,
			Dist = 99, Height = 99, Range = 4, Behind = false, Clear = false,
		}
		local Ok, Why = K.Check(C)
		T.Eq(Ok, false)
		T.Eq(Why, "player", "the PvE rule is checked first")
		local Pass = Good()
		Pass.IsPlayer = true
		T.Eq(select(2, K.Check(Pass)), "player", "a player is refused even when everything else passes")
	end,

	ChunkNoKnockout = function(T)
		local K = Load()
		local C = Good()
		C.Class, C.Kind = "Chunk", "Knockout"
		local Ok, Why = K.Check(C)
		T.Eq(Ok, false)
		T.Eq(Why, "kind", "an Elite can't be knocked out")
		C.Kind = "Assassinate"
		T.Eq(K.Check(C), true, "an Elite can be backstabbed")
	end,

	-- a guard against an accidental edit: the owner changes these here and in the module together
	Numbers = function(T)
		local K = Load()
		T.Eq(K.Key, "N")
		T.Eq(K.Range, 4)
		T.Eq(K.Height, 3)
		T.Eq(K.BehindAngle, 70)
		T.Eq(K.HoldToKill, 0.6)
		T.Eq(K.KnockoutTime, 2.0)
		T.Eq(K.LethalTime, 1.0)
		T.Eq(K.KnockoutSeconds, 300)
		T.Eq(K.BodySeconds, 120)
		T.Eq(K.Cooldown, 4)
		T.Eq(K.ChunkShare, 0.45)
	end,

	-- Task 1's measurements (2026-10-27) of the owner's animations
	Measured = function(T)
		local K = Load()
		T.Eq(K.AnimLength.Assassinate, 1.133, "Assassinate (83505608395055)")
		T.Eq(K.AnimLength.Knockout, 1.25, "Knock out (72960497872371)")
		T.Eq(K.SnapKeyframe, "Snap", "a named Keyframe, not a KeyframeMarker")
		T.Eq(K.SnapAt, 0.683)
		T.Near(K.KillAt, 0.6028, 1e-4, "Snap / length")
		T.Near(K.KillAt * K.LethalTime * K.Speed("Assassinate"), 0.683, 1e-3, "the kill lands on the Snap at 1x time")
	end,

	Speeds = function(T)
		local K = Load()
		T.Near(K.Speed("Assassinate"), 1.133, 1e-9, "1.133 s in 1.0 s")
		T.Near(K.Speed("Knockout"), 0.625, 1e-9, "1.25 s in 2.0 s")
		T.Eq(K.Speed("Bogus"), 1, "unknown kind plays at 1x")
	end,

	Hidden = function(T)
		local K = Load()
		T.Eq(K.IsHidden(nil), false, "nothing is hidden until stealth missions (M3)")
	end,
}

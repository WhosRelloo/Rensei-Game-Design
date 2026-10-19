-- Perception (2026-10-19, Morality × Reputation spec §17.1, §17.2, §17.10): the numbers and the pure maths
-- of what NPCs notice. PerceptionService (server) runs it; the eye-sigil HUD (Plan 2) will read it too.
-- Every number is a PROPOSAL (spec §18.7). Light (Exposure) and crouching arrive in Plan 2 (S2).

local Perception = {}

Perception.Tick = 0.2 -- seconds between updates
Perception.ActiveRange = 80 -- only NPCs this close to some player perceive at all
Perception.RaysPerNpc = 3 -- sight rays per NPC per tick
Perception.RaysPerTick = 120 -- for every NPC together
Perception.Primary = 110 -- degrees of the full-rate view cone
Perception.Peripheral = 160 -- degrees of the half-rate cone; behind it, nothing
Perception.Suspicious = 0.35 -- awareness at which an NPC goes to look
Perception.Drain = 0.25 -- awareness lost per second while it perceives nothing
Perception.Memory = 3 -- seconds an Alert NPC keeps fighting someone it can't see
Perception.InvestigateTime = 8 -- a Suspicious NPC gives up after this long
Perception.SearchTime = 25 -- an Alert NPC that lost you searches this long, then turns Cautious
Perception.CautiousTime = 180
Perception.CautiousMult = 1.3 -- sight (and, in Plan 2, hearing) while Cautious
Perception.CallRadius = 40 -- an Alert NPC brings in the NPCs this close
Perception.Falloff = 0.75 -- at the edge of its range an NPC fills at 1 - 0.75 = 25% of the point-blank rate

-- movement by horizontal root speed: walking x1, running x1.5, sprinting x2. The breakpoints are the
-- midpoints between the game's gaits (walk 16, run 24, sprint 30; Run.lua), so physics jitter and speed
-- bonuses don't flip a runner into a sprinter.
Perception.Move = {{Max = 20, Mult = 1}, {Max = 27, Mult = 1.5}, {Max = math.huge, Mult = 2}}

-- Range in studs; Fill = awareness per second at point blank, fully visible, in the primary cone
Perception.Types = {
	Grunt = {Range = 30, Fill = 0.8}, -- slow to notice
	Elite = {Range = 45, Fill = 1.4},
	Agent = {Range = 40, Fill = 1.4}, -- State alchemists / enforcers (they hear alchemy x2 in Plan 2)
	Hunter = {Range = 50, Fill = 1.8},
	Witness = {Range = 30, Fill = 1.0}, -- townsfolk and other watchers (tag RenseiWatcher)
}

-- TuningConfig.Enemies type -> perception type (unlisted: Grunt)
Perception.EnemyTypes = {
	Grunt = "Grunt", AditScavenger = "Grunt", Elite = "Elite",
	FieldAlchemist = "Agent", FrostAlchemist = "Agent", GaleAlchemist = "Agent",
	StoneAlchemist = "Agent", WardAlchemist = "Agent",
}

-- arena / trial foes keep the old distance aggro (spec: "always aware")
Perception.AlwaysAware = {
	Sparring = true, TrialEarth = true, TrialFlame = true, TrialIce = true, TrialMetal = true, TrialWind = true,
}

-- 1 inside the primary cone, 0.5 in the peripheral band, 0 behind. Horizontal angle only, so someone
-- straight above or below (a ledge, a drop) counts as ahead.
function Perception.ConeMult(Look, To)
	local L = Vector3.new(Look.X, 0, Look.Z)
	local D = Vector3.new(To.X, 0, To.Z)
	if D.Magnitude < 0.01 then return 1 end
	if L.Magnitude < 0.01 then return 0 end
	local Angle = math.deg(math.acos(math.clamp(L.Unit:Dot(D.Unit), -1, 1)))
	if Angle <= Perception.Primary / 2 then return 1 end
	if Angle <= Perception.Peripheral / 2 then return 0.5 end
	return 0
end

function Perception.MoveMult(Speed)
	for _, M in ipairs(Perception.Move) do
		if Speed <= M.Max then return M.Mult end
	end
	return 1
end

-- awareness per second. Visible = the fraction of head / torso / feet in clear line of sight (0..1).
function Perception.Rate(Type, Dist, Cone, Visible, Move, Exposure, Cautious)
	local T = Perception.Types[Type] or Perception.Types.Grunt
	if Dist > T.Range or Cone <= 0 or Visible <= 0 then return 0 end
	local Falloff = 1 - Perception.Falloff * (Dist / T.Range)
	return T.Fill * Falloff * Cone * Visible * Move * (Exposure or 1) * (Cautious and Perception.CautiousMult or 1)
end

return Perception

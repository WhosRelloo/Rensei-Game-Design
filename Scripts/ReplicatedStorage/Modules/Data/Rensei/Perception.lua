-- Perception (2026-10-19, Morality × Reputation spec §17.1, §17.2, §17.10): the numbers and the pure maths
-- of what NPCs notice. PerceptionService (server) runs it; the eye-sigil HUD (Plan 2) will read it too.
-- Every number is a PROPOSAL (spec §18.7). Plan 2 (S2, 2026-10-20) adds light (Exposure), crouching, sounds
-- (radii, footsteps by floor, wall muffling) and how bright a place is by the time of day.

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

-- SpeedMult (optional): the character's SpeedMultiplier attribute. A speed buff scales the gaits too, so a
-- buffed walk still reads as walking (Plan 1 follow-up).
function Perception.MoveMult(Speed, SpeedMult)
	Speed = Speed / math.max(0.25, SpeedMult or 1)
	for _, M in ipairs(Perception.Move) do
		if Speed <= M.Max then return M.Mult end
	end
	return 1
end

-- ===== Plan 2 (S2): crouching, light, sound =====
Perception.CrouchMult = 0.5 -- sight while crouching (replaces the movement multiplier)
-- swimming revamp (2026-10-26, PROPOSAL): sight of a diver (attribute Submerged, set by SwimService). It wins over
-- crouching. A strong stealth tool, not invisibility: an NPC close by can still spot you.
Perception.SubmergedMult = 0.3

-- Exposure 0..1 (LightService) -> sight multiplier: x0.2 in deep shadow up to x1.2 in bright light
Perception.ExposureMin = 0.2
Perception.ExposureMax = 1.2
function Perception.ExposureMult(Exposure)
	local E = math.clamp(tonumber(Exposure) or 1, 0, 1)
	return Perception.ExposureMin + (Perception.ExposureMax - Perception.ExposureMin) * E
end

-- daylight by Lighting.ClockTime: full from 9 to 17, none from 20 to 6, ramps between (outdoors only;
-- under a roof a place gets IndoorDay of it)
Perception.IndoorDay = 0.35
Perception.NightFloor = 0.05
function Perception.Daylight(Clock)
	local C = (tonumber(Clock) or 14) % 24
	if C >= 9 and C <= 17 then return 1 end
	if C <= 6 or C >= 20 then return Perception.NightFloor end
	local T = C < 9 and (C - 6) / 3 or (20 - C) / 3
	return Perception.NightFloor + (1 - Perception.NightFloor) * T
end

-- a tagged lamp's light on a point Dist away (Radius, Strength 0..1): full at the lamp, none at its radius
function Perception.LampLight(Dist, Radius, Strength)
	if Radius <= 0 or Dist >= Radius then return 0 end
	return (Strength or 1) * (1 - Dist / Radius)
end

-- sounds (studs). An NPC within the radius goes to look at the spot: it learns where, not who.
Perception.Sounds = {
	Cast = 30, Clap = 8, Gunshot = 60, Hit = 20, Land = 12, Roll = 10, Splash = 12, Break = 25, LockPick = 6,
	-- swimming revamp (2026-10-26, PROPOSAL): a head breaking the surface after a dive; a sprint stroke at the surface
	Surface = 6, Stroke = 8,
	-- assassinations (2026-10-27, PROPOSAL; spec §7.2): the choke at the start of a knockout; the body dropping after a takedown
	Choke = 6, Takedown = 4,
}
Perception.StrokeEvery = 0.8 -- seconds between sprint-stroke sounds at the surface (PROPOSAL)
Perception.LoudAlchemy = {Cast = true, Clap = true} -- Agents hear these from twice as far
Perception.AgentHearing = 2
Perception.WallCut = 0.4 -- each wall between the sound and the NPC takes 40% off the radius
Perception.MaxWalls = 3 -- walls counted per NPC per sound (one ray each); more count as 3

-- footsteps by floor (Enum.Material name). Crouched: 0. Running or sprinting: x2.
Perception.StepRadius = 5 -- any floor not listed
Perception.Steps = {
	Grass = 4, LeafyGrass = 4, Ground = 4, Mud = 4, Sand = 4, Snow = 4, Fabric = 4,
	Wood = 7, WoodPlanks = 7,
	Metal = 9, CorrodedMetal = 9, DiamondPlate = 9, Foil = 9, Pebble = 9, Cobblestone = 9,
}
Perception.RunSteps = 2
function Perception.StepNoise(Material, Move, Crouching)
	if Crouching then return 0 end
	local R = Perception.Steps[Material] or Perception.StepRadius
	return (Move or 1) > 1 and R * Perception.RunSteps or R
end

-- the radius a sound reaches through Walls walls
function Perception.Muffled(Radius, Walls)
	return Radius * (1 - Perception.WallCut) ^ math.min(Walls, Perception.MaxWalls)
end

-- awareness per second. Visible = the fraction of head / torso / feet in clear line of sight (0..1).
function Perception.Rate(Type, Dist, Cone, Visible, Move, Exposure, Cautious)
	local T = Perception.Types[Type] or Perception.Types.Grunt
	if Dist > T.Range or Cone <= 0 or Visible <= 0 then return 0 end
	local Falloff = 1 - Perception.Falloff * (Dist / T.Range)
	return T.Fill * Falloff * Cone * Visible * Move * (Exposure or 1) * (Cautious and Perception.CautiousMult or 1)
end

return Perception

-- Takedown (assassinations, 2026-10-25; spec Documents/specs/2026-10-25-assassinations-design.md): the numbers, the
-- animation slot names and the pure rules of a stealth takedown. PvE only: Check refuses a player's character first.
-- TakedownService (server) decides; TakedownUI (client) only shows the prompt. Every number is a PROPOSAL unless it
-- says it was measured.
-- No Instance is read here except through the arguments, so RenseiTests.Test_Takedown checks it without a game.
-- Notes for the later tasks (assassinations ledger, 2026-10-27):
--   * the assassination victim's animation (4.717 s) is cut at the player animation's "Snap": a named Keyframe, so
--     time it with AnimationTrack.KeyframeReached ("Snap") or KillAt x LethalTime. It is NOT a KeyframeMarker, so
--     GetMarkerReachedSignal("Snap") never fires.
--   * server code that moves a knocked PLAYER on purpose must call DownedManager.RebaseCrawl, or the crawl clamp
--     (about 4.5 studs/s) pulls the move back. Knocked enemies aren't clamped.
--   * a test that checks the assassination's EXP reads Data.LifetimeExp (Data.Exp rolls over on a level-up) and
--     resets the deed's DayCount first (ruling R17).
local Perception = require(script.Parent.Perception)
local Heat = require(script.Parent.Heat)

local Takedown = {}

Takedown.Key = "N" -- tap: knock out; hold HoldToKill: assassinate (reserved in Rensei.Settings)
Takedown.HoldToKill = 0.6 -- seconds
Takedown.Range = 4 -- studs, root to root on the ground plane
Takedown.RangeSlack = 1.5 -- server only: lag
Takedown.Height = 3 -- studs up or down
Takedown.BehindAngle = 70 -- degrees either side of straight behind (a 140 degree rear arc)
Takedown.AngleSlack = 10 -- server only
Takedown.BreakDistance = 6 -- farther apart mid-takedown: interrupted
Takedown.KnockoutTime = 2.0 -- seconds the choke takes
Takedown.LethalTime = 1.0 -- seconds the assassination takes
Takedown.KnockoutSeconds = 300 -- knocked out this long
Takedown.BodySeconds = 120 -- a takedown's dead body stays this long
Takedown.Cooldown = 4
Takedown.RefusedCooldown = 0.5
Takedown.ChunkShare = 0.45 -- an Elite's backstab: this share of its max health
Takedown.ChunkStun = 1.2

-- Measured in Studio (Task 1, 2026-10-27) from the owner's animations, not proposals:
--   Misc_Assassinate 83505608395055: 1.133 s, one named Keyframe "Snap" at 0.683 s (the kill), no KeyframeMarkers;
--   Takedown_Choke 72960497872371 ("Knock out"): 1.25 s; Takedown_ChokeVictim 131914091661838 ("Hold"): a one-keyframe
--   looped pose (not timed); Misc_AssassinateVictim 132728216355683 ("Victim", "HammerChoking"): 4.717 s, cut at the
--   Snap. Every root is in place (the HumanoidRootPart pose is the identity at every keyframe).
Takedown.AnimLength = {Assassinate = 1.133, Knockout = 1.25} -- the player animations' lengths (measured)
Takedown.SnapKeyframe = "Snap" -- the Keyframe name in Misc_Assassinate (KeyframeReached, not a marker)
Takedown.SnapAt = 0.683 -- seconds into Misc_Assassinate (measured)
Takedown.KillAt = Takedown.SnapAt / Takedown.AnimLength.Assassinate -- share of LethalTime: the Snap's share of the
-- animation (about 0.603). TakedownService kills at LethalTime x KillAt on its own clock: the player's track plays on the
-- client, so the server can't hear its KeyframeReached("Snap"); the two land together at the retimed speed.
-- the victim's root in the player's root space. PROPOSAL: the animations carry no root offset (in place), and Task 1's
-- 1.6 studs overlapped the bodies, so it starts at 2.0 studs in front; Tasks 3 / 5 tune it by screenshot.
Takedown.Offset = CFrame.new(0, 0, -2.0)
Takedown.SpeedClamp = {0.6, 1.6} -- animation speed = length / time, clamped (as DownedManager.Grip)

Takedown.Kinds = {Knockout = true, Assassinate = true}
Takedown.Phases = {Unaware = true, Suspicious = true, Cautious = true} -- Alert: never
Takedown.ClassByPerception = {Grunt = "Full", Agent = "Full", Elite = "Chunk", Hunter = "Chunk"}

-- slots (Assets.Animations.Shared.Takedown, Task 3). Task 3 fills the slots with the owner's ids above (owner update,
-- 2026-10-25); a slot left empty plays the fallback. No id is ever invented.
Takedown.Anims = {
	Assassinate = {Player = "Misc_Assassinate", PlayerFallback = "Gripping", Victim = "Misc_AssassinateVictim", VictimFallback = "Gripped"},
	Knockout = {Player = "Takedown_Choke", PlayerFallback = "Fist_BearHug", Victim = "Takedown_ChokeVictim", VictimFallback = "Fist_BearHugVictim"},
}

local Times = {Assassinate = "LethalTime", Knockout = "KnockoutTime"}

local function Flat(V) return Vector3.new(V.X, 0, V.Z) end

-- Is the player in the victim's rear arc? VictimLook = its LookVector; ToPlayer = player root - victim root.
-- Vector3 is single precision, so the edge gets 1e-3 degrees of tolerance (70 degrees exactly is inside).
function Takedown.Behind(VictimLook, ToPlayer, Slack)
	local L, D = Flat(VictimLook), Flat(ToPlayer)
	if L.Magnitude < 1e-3 or D.Magnitude < 1e-3 then return false end
	local FromBack = math.deg(math.acos(math.clamp((-L.Unit):Dot(D.Unit), -1, 1)))
	return FromBack <= Takedown.BehindAngle + (Slack or 0) + 1e-3
end

-- The animation speed for a Kind: its length over the time it takes, clamped to SpeedClamp; 1 for an unknown Kind.
function Takedown.Speed(Kind)
	local Length, Time = Takedown.AnimLength[Kind], Times[Kind] and Takedown[Times[Kind]]
	if not (Length and Time and Time > 0) then return 1 end
	return math.clamp(Length / Time, Takedown.SpeedClamp[1], Takedown.SpeedClamp[2])
end

-- The perception type PerceptionService tracks an enemy of this TuningConfig type as (EnemyService registers it the
-- same way), or nil when it isn't tracked (arena / trial foes, Perception.AlwaysAware). ClassOf's first argument, so the
-- server and TakedownUI derive it once (ruling R16).
function Takedown.PerceptionTypeOf(EnemyType)
	if type(EnemyType) ~= "string" or Perception.AlwaysAware[EnemyType] then return nil end
	return Perception.EnemyTypes[EnemyType] or "Grunt"
end

-- "Full" | "Chunk" | "Immune". PerceptionType: the type PerceptionService tracks the rig as, or nil when it doesn't
-- track it (arena / trial foes). Attrs = {Boss, TrialFoe, TakedownClass} gathered by the caller: Boss and TakedownClass
-- from the rig's attributes, TrialFoe from the enemy type's TuningConfig definition (no rig carries a TrialFoe
-- attribute; Task 2 review minor 4).
function Takedown.ClassOf(PerceptionType, Attrs)
	Attrs = Attrs or {}
	local Forced = Attrs.TakedownClass
	if Forced == "Full" or Forced == "Chunk" or Forced == "Immune" then return Forced end
	if Attrs.Boss or Attrs.TrialFoe or PerceptionType == nil then return "Immune" end
	return Takedown.ClassByPerception[PerceptionType] or "Full"
end

-- Is this faction a law (a guard's faction, spec §18.3)? The State's (Heat.Law.State) and the Militia's
-- (Heat.Law.Militia); the Circle is not a law. Task 6's assassinated_guard deed uses it.
function Takedown.IsLawFaction(Faction)
	if type(Faction) ~= "string" then return false end
	return Faction == Heat.Law.State or Faction == Heat.Law.Militia
end

-- Ctx: plain values the caller gathered. Returns true, or false and the first failing reason. The PvE rule is first.
-- Fails closed (Task 7, the Task 2 review's minor 1): a Class other than Full or Chunk (missing too) is "immune", a
-- missing Phase or a NaN AwareOfYou is "alert", a NaN Dist or Height is "far". (A missing AwareOfYou reads 0: the client
-- never knows it.)
--   IsPlayer, IsTownsfolk, IsEnemy, Alive, Kind, Class, Ready, PlayerFree, PlayerCalm, TargetFree,
--   Phase, AwareOfYou (0..1), Dist, Height, Range (Range, or Range + RangeSlack on the server; nil: Range), Behind, Clear
function Takedown.Check(Ctx)
	if Ctx.IsPlayer then return false, "player" end
	if Ctx.IsTownsfolk then return false, "townsfolk" end
	if not Ctx.IsEnemy then return false, "not_enemy" end
	if not Ctx.Alive then return false, "dead" end
	if not Takedown.Kinds[Ctx.Kind] then return false, "kind" end
	if Ctx.Class ~= "Full" and Ctx.Class ~= "Chunk" then return false, "immune" end
	if Ctx.Class == "Chunk" and Ctx.Kind ~= "Assassinate" then return false, "kind" end
	if not Ctx.Ready then return false, "cooldown" end
	if not Ctx.PlayerFree then return false, "busy" end
	if not Ctx.PlayerCalm then return false, "combat" end
	if not Ctx.TargetFree then return false, "target_busy" end
	local Aware = tonumber(Ctx.AwareOfYou) or 0
	if not Takedown.Phases[Ctx.Phase] or Aware ~= Aware or Aware >= 1 then return false, "alert" end
	local Dist, Height = tonumber(Ctx.Dist) or math.huge, tonumber(Ctx.Height) or math.huge
	if Dist ~= Dist or Dist > (tonumber(Ctx.Range) or Takedown.Range) then return false, "far" end
	if Height ~= Height or math.abs(Height) > Takedown.Height then return false, "far" end
	if not Ctx.Behind then return false, "front" end
	if not Ctx.Clear then return false, "blocked" end
	return true
end

-- Hiding spots come with stealth missions (slice M3). Until then nothing is hidden.
function Takedown.IsHidden(Body) return false end

return Takedown

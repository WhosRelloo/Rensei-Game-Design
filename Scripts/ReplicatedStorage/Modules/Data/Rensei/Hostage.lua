-- Hostage (hostages plan, 2026-10-27; spec Documents/specs/2026-10-21-hostage-design.md, owner-approved 2026-10-25):
-- the numbers, the animation slot names and the pure rules of player-on-player hostages. PvP only: CheckTake refuses
-- an NPC before anything else. HostageService (server) decides; TakedownUI / HostageUI (client) only show.
-- Every number is a PROPOSAL unless it says it was measured. No Instance is read here except through the arguments,
-- so RenseiTests.Test_Hostage checks it without a game.
local Takedown = require(script.Parent.Takedown)

local Hostage = {}

-- (Task 5 fix, controller ruling K1: publish safety) hostages are switched OFF until the plan is done: flipped by Task 14.
-- While false, Requests.Hostage and HostageService.Take refuse everything outside the Studio TestNoSave test bypass.
Hostage.Enabled = false
Hostage.Key = "N" -- shared with takedowns: an enemy target is a takedown, a player target a hostage (controller ruling)
-- taking
Hostage.BindTime = 1.5 -- seconds to bind a knocked player (channelled, like Grip)
Hostage.BindRange = 6 -- studs, root to root (Grip's reach, TuningConfig.Downed.GripRange)
Hostage.GrabRange = 4 -- studs behind the target (spec §2)
Hostage.Height = 3 -- studs up or down
Hostage.RangeSlack = 1.5 -- server only: lag
Hostage.AngleSlack = 10 -- server only: degrees added to Takedown.BehindAngle
Hostage.GrabStart = 0.4 -- a grab's struggle bar starts here (spec §2)
Hostage.GrabWindow = 3 -- seconds the grabbed target has to fill it
Hostage.ShoveStun = 1.0 -- the captor's stun when a grab is shoved off
Hostage.BreakStun = 1.5 -- the captor's stun when a hostage struggles free
Hostage.MinHealthShare = 0.15 -- a bound hostage keeps at least this share of max health
Hostage.MinLevel = 5 -- never a player under level 5
Hostage.MaxGap = 15 -- never a target this many levels below the captor
Hostage.Cooldown = 4 -- seconds between a captor's takes
Hostage.RefusedCooldown = 0.5
Hostage.ImmuneAfter = 5 -- grab immunity after any release (spec §4)
-- holding
Hostage.LeadSpeed = 12 -- the captor's walk while holding (Carry is 11)
Hostage.Offset = CFrame.new(0, 0, -1.5) -- the hostage's root in the captor's root space: in front, same facing
Hostage.HoldTime = 180 -- seconds
Hostage.RetakeWindow = 600 -- a re-take of the same hostage within this halves the time
Hostage.MinHoldTime = 20
Hostage.StunPad = 1 -- seconds: the hostage's Stun lasts the hold's time plus this (Task 5; pre-flight P26)
-- struggle (the Block key)
-- Rensei.Stats name. The spec's "Body" isn't a stat: Stats.Order is Strength, Intelligence, Speed, Vitality, Alchemy
-- (Task 1's survey), so Strength (controller ruling P1 / T1-3; owner question: Strength or Vitality)
Hostage.StruggleStat = "Strength"
Hostage.StrugglePress = 0.06 -- bar per press at an even Strength
Hostage.StruggleRatio = {0.5, 2} -- clamp of (1 + own Strength) / (1 + captor's Strength)
Hostage.StruggleDrain = 0.05 -- bar lost per second
Hostage.StruggleStamina = 4 -- stamina per press
Hostage.MaxPressesPerSecond = 8 -- counted on the server
Hostage.SendsPerSecond = 4 -- the client batches presses into at most this many messages
Hostage.MaxPressesPerSend = 3 -- presses one message may carry (Task 12; pre-flight P26)
Hostage.StrugglePoseTime = 0.3 -- seconds the struggle pose plays after a counted press (Task 7; pre-flight P26)
-- the pair held for real (lesson I1): the server's watch
Hostage.WatchTick = 0.1
Hostage.LeadMult = 1.5
Hostage.LeadSlack = 2.5 -- studs/s
Hostage.LeadWindow = 1 -- seconds: a hitch's longest counted gap
Hostage.RiseSlack = 3 -- studs the pair may rise above its last allowed point (stairs) before it is put back
Hostage.PairSlack = 1.5 -- studs the hostage's root may be from the captor's root x Offset
Hostage.TeleportBreak = 40 -- a jump further than this ends the hold ("teleport") instead of a snap back
-- shield
Hostage.ShieldArc = 70 -- degrees either side of the captor's front
-- money
Hostage.RansomMin = 50
Hostage.RansomPerLevel = 100 -- spec: 10 x level x 10
Hostage.RansomCap = 5000
Hostage.MissingShare = 0.10 -- "goes missing" (a money sink)
Hostage.RansomWait = 60
Hostage.BountyShare = 0.5 -- of a fine actually paid
Hostage.DeskRange = 12 -- studs from a State desk's root
Hostage.DeskRefresh = 30 -- seconds between HostageService's desk scans (Task 11; pre-flight P26)
-- safe zones (ruling R6)
Hostage.SafeTag = "RenseiSafeZone"
-- studs from a ticket clerk or station gate. PROPOSAL (controller ruling T1-1), not a measurement: Task 1 measured
-- 285.7 studs from a clerk to the far corner of its platform train (290 rounded up), but the train's box + TrainMargin
-- already covers the platform and the train, and 290 would cover much of Lindenmoor west. So 50 around the markers.
Hostage.StationSafeRadius = 50
Hostage.TrainMargin = 4 -- studs around a platform train's bounding box

-- slots (Assets.Animations.Shared.Hostage, Task 3). Empty slots play the fallback; no id is ever invented.
-- Stand-ins (rulings T1-6, decision 9): Gripping's slot is empty in both places, so the bind plays Takedown_Choke (the
-- owner's "Knock out", 72960497872371); the hostage plays Takedown_ChokeVictim, not the spec's Carried (a body over the
-- shoulder); leading plays Carrying, as the spec says.
Hostage.Anims = {
	Bind = {Name = "Hostage_Bind", Fallback = "Takedown_Choke"},
	Hold = {Name = "Hostage_Hold", Fallback = "Carrying"},
	Held = {Name = "Hostage_Held", Fallback = "Takedown_ChokeVictim"},
	Struggle = {Name = "Hostage_Struggle", Fallback = "Takedown_ChokeVictim"},
}

Hostage.Kinds = {Bind = true, Grab = true}

local function Flat(V) return Vector3.new(V.X, 0, V.Z) end

-- the captor is in the target's rear arc: the takedowns' own rule (Takedown.Behind), never a copy
function Hostage.Behind(TargetLook, ToCaptor, Slack)
	return Takedown.Behind(TargetLook, ToCaptor, Slack)
end

-- Other is in front of the captor: within ShieldArc of its look (the shield side). Vector3 is single precision, so the
-- edge gets the same 1e-3 degrees of tolerance as Takedown.Behind (70 degrees exactly is inside; pre-flight P10).
function Hostage.InFront(CaptorLook, ToOther)
	local L, D = Flat(CaptorLook), Flat(ToOther)
	if L.Magnitude < 1e-3 or D.Magnitude < 1e-3 then return false end
	return math.deg(math.acos(math.clamp(L.Unit:Dot(D.Unit), -1, 1))) <= Hostage.ShieldArc + 1e-3
end

-- seconds this hold may last, given how many times this hostage was taken in the last RetakeWindow
function Hostage.HoldTimeFor(Retakes)
	return math.max(Hostage.MinHoldTime, Hostage.HoldTime / 2 ^ math.max(0, Retakes or 0))
end

-- bar per press: StrugglePress x clamp((1 + Mine) / (1 + Theirs)); Mine and Theirs are each side's StruggleStat
function Hostage.StruggleGain(Mine, Theirs)
	local R = (1 + math.max(0, tonumber(Mine) or 0)) / (1 + math.max(0, tonumber(Theirs) or 0))
	return Hostage.StrugglePress * math.clamp(R, Hostage.StruggleRatio[1], Hostage.StruggleRatio[2])
end

-- studs the captor may cover across the ground in Dt seconds
function Hostage.LeadAllowance(Dt)
	return (Hostage.LeadSpeed * Hostage.LeadMult + Hostage.LeadSlack) * math.min(math.max(Dt, 0), Hostage.LeadWindow)
end

local function Round10(X) return math.floor(X / 10 + 0.5) * 10 end

function Hostage.RansomMax(Level)
	return math.min(Hostage.RansomPerLevel * math.max(1, math.floor(tonumber(Level) or 1)), Hostage.RansomCap)
end

-- the captor's choices, lowest first: RansomMin, then a quarter, a half and all of RansomMax (rounded to 10), each
-- kept only when it is above the last and within [RansomMin, RansomMax]
function Hostage.RansomTiers(Level)
	local Max = Hostage.RansomMax(Level)
	local Out = {}
	for _, V in ipairs({Hostage.RansomMin, Round10(Max / 4), Round10(Max / 2), Max}) do
		if V >= Hostage.RansomMin and V <= Max and (#Out == 0 or V > Out[#Out]) then table.insert(Out, V) end
	end
	return Out
end

-- what the captor receives of a paid ransom
function Hostage.Net(Amount) return math.floor(Amount * (1 - Hostage.MissingShare)) end

-- the captor's bounty for a fugitive whose fine was paid (decision 8: nothing for an unpaid one)
function Hostage.Bounty(FinePaid) return math.floor(math.max(0, tonumber(FinePaid) or 0) * Hostage.BountyShare) end

-- Ctx: plain values the caller gathered. Returns true, or false and the first failing reason. The PvP rule is first.
--   IsNpc, IsPlayer, Self, Kind, Safe, InDialogue, TargetLevel, CaptorLevel, Ready, Immune, CaptorFree, TargetFree,
--   TargetKnocked, Dist, Height, Range, Behind, Clear
-- IsNpc is the caller's NPC test (HostageService: EnemyType, TownsfolkId, DialogueId or an EnemyService entry;
-- pre-flight P25). TargetLevel and CaptorLevel are each player's Data.Level, never the Level attribute, which
-- ProgressionService.Sync rewrites (pre-flight P2). Range is BindRange or GrabRange (+ RangeSlack on the server); nil
-- reads the Kind's own range. Fails closed: a NaN or missing Dist or Height is "far".
function Hostage.CheckTake(Ctx)
	if Ctx.IsNpc then return false, "not_player" end
	if not Ctx.IsPlayer then return false, "not_player" end
	if Ctx.Self then return false, "self" end
	if not Hostage.Kinds[Ctx.Kind] then return false, "kind" end
	if Ctx.Safe then return false, "safe" end
	if Ctx.InDialogue then return false, "dialogue" end
	if (tonumber(Ctx.TargetLevel) or 0) < Hostage.MinLevel then return false, "level_low" end
	if (tonumber(Ctx.CaptorLevel) or 0) - (tonumber(Ctx.TargetLevel) or 0) >= Hostage.MaxGap then return false, "level_gap" end
	if not Ctx.Ready then return false, "cooldown" end
	if Ctx.Immune then return false, "immune" end
	if not Ctx.CaptorFree then return false, "busy" end
	if not Ctx.TargetFree then return false, "target_busy" end
	if (Ctx.Kind == "Bind") ~= (Ctx.TargetKnocked == true) then return false, "kind" end
	local Range = tonumber(Ctx.Range) or (Ctx.Kind == "Bind" and Hostage.BindRange or Hostage.GrabRange)
	local Dist, Height = tonumber(Ctx.Dist) or math.huge, tonumber(Ctx.Height) or math.huge
	if Dist ~= Dist or Dist > Range then return false, "far" end
	if Height ~= Height or math.abs(Height) > Hostage.Height then return false, "far" end
	if Ctx.Kind == "Grab" and not Ctx.Behind then return false, "seen" end
	if not Ctx.Clear then return false, "blocked" end
	return true
end

return Hostage

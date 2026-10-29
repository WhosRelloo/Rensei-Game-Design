-- Guard (stealth missions Plan 1, 2026-10-29; spec Documents/specs/2026-10-25-stealth-missions-design.md §3-4): the
-- numbers, the lines and the pure rules of guards that think and of seeing what they see. GuardService (server) runs
-- the routine and the radio; SightFeed (server) sends each player their own awareness rows; GuardSightUI (client)
-- draws the cones and markers. No Instance is read here, so RenseiTests.Test_Guard checks it without a game.
-- Every number, name and line is a PROPOSAL (spec: inspired by stealth classics, never copied).
local Guard = {}

-- the radio (spec §3.1, §3.3)
Guard.CheckInEvery = 45 -- seconds between a guard's check-ins
Guard.CheckInGrace = 30 -- a check-in this late is missed: the net searches the guard's post
Guard.RadioTime = 2 -- seconds an Alert guard stands still to radio the net; knocked out meanwhile = no alarm
Guard.RadioDelay = 3 -- a noise only look-outs heard reaches the nearest free guard this much later
Guard.TightSeconds = 600 -- after an alarm the net calms to Cautious, never Normal, this long
Guard.Reinforcements = 2 -- per barracks, per alarm
Guard.MaxReinforcements = 4 -- alive per net at once
Guard.ReinforceDelay = 6 -- seconds from the alarm to the barracks door opening

-- the routine
Guard.PatrolSpeed = 8 -- a patrol stroll (enemies walk 14-15 when they fight)
Guard.PatrolPause = 3 -- seconds at each patrol point (a point's Pause attribute wins)
Guard.PostSlack = 3 -- a post guard further than this from its post walks back
Guard.LookoutSweep = 45 -- degrees either side of the post's facing
Guard.LookoutPeriod = 6 -- seconds for one full sweep (there and back)
Guard.MaxWalkFails = 3 -- failed legs in a row before a guard stands where it is
Guard.LineCooldown = 8 -- seconds between two lines from one guard

-- seeing what they see (spec §4.1)
Guard.FeedRange = 60 -- studs: the enemies whose awareness of you is sent to you
Guard.FeedCount = 8 -- at most this many, the nearest
Guard.FeedHz = 5
Guard.FeedKeepAlive = 1 -- seconds: the rows are sent again this often even when unchanged (unreliable events drop)
Guard.MarkerHeight = 4.2 -- studs above the Head (the speech bubble is at 2.6)
Guard.Colours = {
	Pale = Color3.fromRGB(230, 226, 214), -- knows nothing
	Amber = Color3.fromRGB(240, 176, 64), -- suspicion building
	Red = Color3.fromRGB(214, 64, 52), -- Alert
}
Guard.ConeAlpha = {Full = 0.78, Half = 0.9} -- transparency of the full-rate cone and the fainter half-rate band
Guard.ConeSegments = {Full = 6, Half = 2} -- triangles in the full cone; in each half-rate band

Guard.EnemyTypes = {StateGuard = true, StateSentry = true, StateOfficer = true}

Guard.Lines = {
	Suspicious = {"Hm? Who's there?", "Did something move?", "I heard that.", "Show yourself."},
	Search = {"Spread out. Find them.", "Check the corners.", "They can't have gone far."},
	Radio = {"Intruder! All posts, respond!", "Contact! Sending word to every post!"},
	Calm = {"Nothing. Just the wind.", "Must be the night playing tricks.", "Back to it."},
	Missing = {"No word from that post. Going to look.", "Someone's not answering. Checking."},
}

function Guard.Line(Kind, Rng)
	local L = Guard.Lines[Kind]
	if not L or #L == 0 then return nil end
	return L[(Rng or Random.new()):NextInteger(1, #L)]
end

-- the patrol point after Index on a route of Count points. Loop: 1..Count, then 1 again; else back and forth.
function Guard.NextPoint(Count, Index, Dir, Loop)
	if Count <= 1 then return 1, 1 end
	if Loop then return Index % Count + 1, 1 end
	local Next = Index + Dir
	if Next > Count or Next < 1 then Dir = -Dir; Next = Index + Dir end
	return Next, Dir
end

function Guard.CheckInDue(Last, Now) return Now - Last >= Guard.CheckInEvery end
function Guard.Missed(Last, Now) return Now - Last >= Guard.CheckInEvery + Guard.CheckInGrace end

-- a look-out's facing offset (degrees) T seconds into its sweep: a triangle wave 0 -> +Sweep -> -Sweep -> 0
function Guard.Sweep(T)
	local P = (T % Guard.LookoutPeriod) / Guard.LookoutPeriod
	local S = Guard.LookoutSweep
	if P < 0.25 then return S * P * 4 end
	if P < 0.75 then return S * (1 - (P - 0.25) * 4) end
	return -S * (1 - (P - 0.75) * 4)
end

function Guard.Quantize(A)
	return math.clamp(math.floor((tonumber(A) or 0) * 20 + 0.5) / 20, 0, 1)
end

-- the cone's colour: pale -> amber as the meter goes 0 -> Suspicious (0.35), amber above it, red at Alert
local SUSPICIOUS = 0.35 -- Perception.Suspicious (Test_Guard checks the tint at this value by hand)
function Guard.Tint(Aware, Phase)
	if Phase == "Alert" then return Guard.Colours.Red end
	return Guard.Colours.Pale:Lerp(Guard.Colours.Amber, math.clamp((Aware or 0) / SUSPICIOUS, 0, 1))
end

-- the marker over a guard's head: shown while its meter for you is above zero (or it is Alert); the fill follows the
-- meter; a ring from Suspicion on and a solid red fill at Alert, so colour is never the only signal (spec §4.1)
function Guard.Marker(Aware, Phase)
	local A = math.clamp(Aware or 0, 0, 1)
	if Phase == "Alert" then return {Show = true, Fill = 1, Ring = true, Solid = true} end
	return {Show = A > 0, Fill = A, Ring = Phase == "Suspicious" or A >= SUSPICIOUS, Solid = false}
end

-- a flat fan of Segments triangles from the feet (the origin) to Range, Degrees wide, centred on -Z (forward), in
-- the guard's local space at its feet. Each triangle is {feet, rim point (left), rim point (right)}.
function Guard.ConeFan(Range, Degrees, Segments)
	local Out = {}
	local Half = math.rad(Degrees / 2)
	local function Rim(A) return Vector3.new(-math.sin(A) * Range, 0, -math.cos(A) * Range) end
	for I = 0, Segments - 1 do
		local A0 = Half - (2 * Half) * I / Segments
		local A1 = Half - (2 * Half) * (I + 1) / Segments
		table.insert(Out, {Vector3.zero, Rim(A0), Rim(A1)})
	end
	return Out
end

-- the nearest of Points (Vector3s) to Where, on the ground plane: index, distance; nil for an empty list
function Guard.Nearest(Points, Where)
	local Best, BestD = nil, math.huge
	for I, Pt in ipairs(Points) do
		local D = Vector3.new(Pt.X - Where.X, 0, Pt.Z - Where.Z).Magnitude
		if D < BestD then Best, BestD = I, D end
	end
	return Best, Best and BestD or nil
end

return Guard

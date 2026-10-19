-- Player Identities (2026-10-18): the rules for an investigator's records of other players' characters.
-- Shared by IdentityService (the only writer) and JournalUI (the Identities tab). Numbers are PROPOSALS.
--
-- A record is created by a real, server-seen event (a fight between the two, or witnessing the other's
-- alchemy within sight) and grows only from what the investigator could see: the weapon used on them,
-- the technique cast in front of them, the dress they wear. The name is only ever revealed by the
-- subject introducing themselves, or by naming them correctly once there's enough to go on.
-- Nothing here is account data: records are keyed by the subject's random CharacterId.

local Identities = {}

Identities.MaxRecords = 40 -- per investigator; the oldest unnamed record is dropped first
Identities.MaxLog = 4 -- documented encounters kept per record
Identities.MaxLinks = 3 -- evidence links kept per record
Identities.EncounterGap = 120 -- seconds: meetings closer together than this are one encounter
Identities.WitnessRange = 60 -- studs: how far away a cast can be seen
Identities.IntroduceRange = 8 -- studs: the Introduce prompt
Identities.WrongLock = 600 -- seconds a record stays locked after a wrong name
Identities.SuspectSeen = 2 -- encounters needed (with two kinds of observation) before naming them

-- the stages, in order (Rensei Player Identities brief: Unknown -> Observed -> Suspected -> Identified -> Investigated)
Identities.Stages = {"Unknown", "Observed", "Suspected", "Identified", "Investigated"}
Identities.StageText = {
	Unknown = "Someone you crossed paths with. Nothing reliable yet.",
	Observed = "You've seen enough to recognise them again, not enough to name them.",
	Suspected = "Your observations point somewhere. You could try to name them, but a wrong name costs time.",
	Identified = "Confirmed. What you know beyond the name is still only what you've seen.",
	Investigated = "A documented subject: several encounters, or evidence that ties to them.",
}
-- what moves a record on from each stage (the journal shows it under the stage track)
Identities.NextStep = {
	Unknown = "Watch for their weapon, their alchemy or how they dress.",
	Observed = "Cross paths with them again and notice something new about them.",
	Suspected = "Name them below, or get them to introduce themselves.",
	Identified = "Meet them again, or find evidence of the alchemy they use.",
}

-- observation kinds: what a fact looks like in the record
Identities.Kinds = {
	Technique = {Order = 1, Label = "Technique", Text = "Seen using %s alchemy."},
	Weapon = {Order = 2, Label = "Weapon", Text = "Fought with %s."},
	Dress = {Order = 3, Label = "Dress", Text = "Wears %s dress."},
}

-- how sure a line is (the journal tags each line with one)
Identities.Confidence = {
	Observed = "observed", -- the investigator saw it
	Inferred = "inferred", -- an evidence link: a hypothesis, never proof
	Confirmed = "confirmed", -- an introduction or a correct naming
}

local function Count(T) local N = 0 for _ in pairs(T or {}) do N += 1 end return N end
Identities.Count = Count

function Identities.Stage(R)
	local Kinds = Count(R.Obs)
	if (R.Name or "") ~= "" then
		if (R.Seen or 0) >= 3 or Count(R.Links) > 0 or Kinds >= 3 then return "Investigated" end
		return "Identified"
	end
	if Kinds >= 2 and (R.Seen or 0) >= Identities.SuspectSeen then return "Suspected" end
	if Kinds >= 1 then return "Observed" end
	return "Unknown"
end

function Identities.CanName(R)
	local S = Identities.Stage(R)
	return S == "Suspected"
end

function Identities.Number(R) return ("Subject %02d"):format(R.N or 0) end

-- what the journal and the combat log call them
function Identities.Label(R)
	if not R then return "Unknown subject" end
	return (R.Name or "") ~= "" and R.Name or Identities.Number(R)
end

return Identities

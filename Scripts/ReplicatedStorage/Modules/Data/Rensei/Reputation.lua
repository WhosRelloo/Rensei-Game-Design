-- Reputation (2026-10-19, Morality × Reputation spec §2-§5, §13): standing place by place. A deed's
-- Standing counts in a region only for the factions there that have heard of it:
--   Morality.Places[Region].Known[DeedId][Faction] = os.time() it was heard (once per faction per place).
-- The global Standing that conditions and the UI read stays a cache: each faction's standing summed over
-- the regions and divided by how many regions it's present in (equal weights, PROPOSAL), so a deed heard
-- everywhere its factions live counts in full, and one heard in half of them counts half.
-- Repeatable deeds (Rensei.Deeds Repeat = {Cap}): a place that has heard of the deed counts every repeat
-- (the ledger's Count), so after word of the first one reaches a place, later repeats count there at once.
-- Accepted for small capped deeds (owner can switch to per-place counts later).
-- Pure functions over a profile's Morality table: MoralityService and RumourService call them.

local Regions = require(script.Parent.Regions)

local Reputation = {}

local function Place(M, Region)
	M.Places = M.Places or {}
	local P = M.Places[Region]
	if not P then P = {Known = {}}; M.Places[Region] = P end
	P.Known = P.Known or {}
	return P
end

-- DeedId heard by those Factions in Region; returns the factions that heard it just now
function Reputation.Land(M, Region, DeedId, Factions, Now)
	local P = Place(M, Region)
	local Heard = P.Known[DeedId] or {}
	local New = {}
	for _, F in ipairs(Factions) do
		if Regions.Present(Region, F) and Heard[F] == nil then
			Heard[F] = Now
			table.insert(New, F)
		end
	end
	if #New > 0 then P.Known[DeedId] = Heard end
	return New
end

function Reputation.LandEverywhere(M, DeedId, Now)
	for Id in pairs(Regions.Regions) do Reputation.Land(M, Id, DeedId, Regions.FactionsAt(Id), Now) end
end

function Reputation.Landed(M, DeedId)
	for _, P in pairs(M.Places or {}) do
		local Heard = P.Known and P.Known[DeedId]
		if Heard and next(Heard) ~= nil then return true end
	end
	return false
end

function Reputation.PlaceStanding(M, Deeds, Region)
	local Out = {}
	local P = (M.Places or {})[Region]
	for DeedId, Heard in pairs(P and P.Known or {}) do
		local Def, E = Deeds[DeedId], M.Deeds and M.Deeds[DeedId]
		if type(Def) == "table" and E then
			for F, V in pairs(Def.Standing or {}) do
				if Heard[F] ~= nil then Out[F] = (Out[F] or 0) + V * (E.Count or 0) end
			end
		end
	end
	return Out
end

function Reputation.GlobalStanding(M, Deeds)
	local Sum = {}
	for Region in pairs(Regions.Regions) do
		for F, V in pairs(Reputation.PlaceStanding(M, Deeds, Region)) do Sum[F] = (Sum[F] or 0) + V end
	end
	local Out = {}
	for F, V in pairs(Sum) do Out[F] = V / math.max(1, Regions.Count(F)) end
	return Out
end

-- Renown: Public deeds (or deeds discovered as Public) count once they've been heard anywhere
function Reputation.Renown(M, Deeds)
	local R = 0
	for Id, E in pairs(M.Deeds or {}) do
		local Def = Deeds[Id]
		if type(Def) == "table" and (E.Known or Def.Scope) == "Public" and Reputation.Landed(M, Id) then
			R += (Def.Renown or 0) * (E.Count or 0)
		end
	end
	return R
end

-- Schema 5, once per profile: deeds that already counted in full before places existed (Local / Public or
-- discovered) are heard everywhere, stamped with the deed's own time, so no old save loses standing.
function Reputation.Seed(M, Deeds, Now)
	if M.Seeded then return false end
	for Id, E in pairs(M.Deeds or {}) do
		local Def = Deeds[Id]
		if type(Def) == "table" and (E.Known or Def.Scope or "Private") ~= "Private" then
			Reputation.LandEverywhere(M, Id, E.At or Now)
		end
	end
	M.Seeded = true
	return true
end

return Reputation

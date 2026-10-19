-- RumourService.Core (2026-10-19, Morality × Reputation spec §5): how word of a deed travels the region
-- graph (Rensei.Regions). Pure: it works on a profile's Morality table and a time you pass in, so the same
-- code runs the online tick, the offline catch-up on join, and the tests with a fake clock.
--   * A rumour starts where the deed happened (already heard there) with a Strength (WitnessService).
--   * It sends a front down every link from its origin. A front arriving at a region lands the deed for the
--     factions its carrier reaches there (Rensei.Reputation: once per faction per place), then the rumour
--     sends that carrier on from there (gossip spreads gossip, dispatch relays dispatch).
--   * Each hop costs 1 Strength: a front lands only while Strength - Hops > 0.
--   * Fronts are processed in arrival-time order, so catching up after hours offline gives exactly what
--     being online would have.
--   * At most 20 live rumours (the oldest finished ones go first); the last 10 arrivals are kept as News
--     (the reason lines: "Word reached the City").

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rensei = ReplicatedStorage.Modules.Data.Rensei
local Regions = require(Rensei.Regions)
local Reputation = require(Rensei.Reputation)

local Core = {}
Core.MaxLive = 20
Core.MaxNews = 10

local function Ensure(M)
	M.Rumours = M.Rumours or {}
	M.Places = M.Places or {}
	M.News = M.News or {}
	return M
end

local function News(M, Item)
	table.insert(M.News, 1, Item)
	while #M.News > Core.MaxNews do table.remove(M.News) end
end

-- fronts down the links from Region (only Carrier's links when given), Hops hops from the origin
local function Push(R, Region, Now, Carrier, Hops)
	if R.Strength - Hops <= 0 then return end
	for _, L in ipairs(Regions.Links(Region)) do
		local Key = L.To .. "/" .. L.Carrier
		if (not Carrier or L.Carrier == Carrier) and not R.Sent[Key] then
			R.Sent[Key] = true
			table.insert(R.Fronts, {Place = L.To, Carrier = L.Carrier, ArrivesAt = Now + L.Minutes * 60, Hops = Hops})
		end
	end
end

local function Trim(M)
	while #M.Rumours > Core.MaxLive do
		local Drop = 1
		for I, R in ipairs(M.Rumours) do
			if #R.Fronts == 0 or R.Suppressed then Drop = I break end
		end
		table.remove(M.Rumours, Drop)
	end
end

function Core.Spawn(M, DeedId, Origin, Strength, Now)
	Ensure(M)
	if not Strength or Strength <= 0 or not Regions.Regions[Origin] then return nil end
	for _, R in ipairs(M.Rumours) do
		if R.Deed == DeedId and R.Origin == Origin and not R.Suppressed and #R.Fronts > 0 then return R end
	end
	local R = {
		Id = DeedId .. "@" .. Origin .. "@" .. tostring(Now), Deed = DeedId, Origin = Origin, Strength = Strength,
		Born = Now, Reached = {[Origin] = Now}, Fronts = {}, Sent = {}, Suppressed = false,
	}
	Push(R, Origin, Now, nil, 1)
	table.insert(M.Rumours, R)
	Trim(M)
	return R
end

function Core.Advance(M, Now)
	Ensure(M)
	local Out = {}
	while true do
		local BestR, BestI, BestT
		for _, R in ipairs(M.Rumours) do
			if not R.Suppressed then
				for I, F in ipairs(R.Fronts) do
					if F.ArrivesAt <= Now and (not BestT or F.ArrivesAt < BestT) then BestR, BestI, BestT = R, I, F.ArrivesAt end
				end
			end
		end
		if not BestR then break end
		local F = table.remove(BestR.Fronts, BestI)
		if BestR.Strength - F.Hops > 0 then
			local Heard = Reputation.Land(M, F.Place, BestR.Deed, Regions.Reach(F.Place, F.Carrier), F.ArrivesAt)
			BestR.Reached[F.Place] = BestR.Reached[F.Place] or F.ArrivesAt
			Push(BestR, F.Place, F.ArrivesAt, F.Carrier, F.Hops + 1)
			if #Heard > 0 then
				News(M, {At = F.ArrivesAt, Place = F.Place, Deed = BestR.Deed, Heard = Heard})
				table.insert(Out, {Rumour = BestR, Place = F.Place, Carrier = F.Carrier, Heard = Heard, At = F.ArrivesAt})
			end
		end
	end
	return Out
end

-- a witness silenced: the rumour loses that witness's weight; at 0 it's dead, fronts on the road included
function Core.Silence(M, RumourId, Weight)
	for _, R in ipairs(Ensure(M).Rumours) do
		if R.Id == RumourId then
			R.Strength -= Weight
			if R.Strength <= 0 then R.Suppressed = true; R.Fronts = {} end
			return R
		end
	end
	return nil
end

-- a player witness reported the deed at a desk: it lands at once there, for that desk's faction
function Core.LandReport(M, DeedId, Region, Faction, Now)
	Ensure(M)
	local Heard = Reputation.Land(M, Region, DeedId, {Faction}, Now)
	if #Heard > 0 then News(M, {At = Now, Place = Region, Deed = DeedId, Heard = Heard, Report = true}) end
	return Heard
end

return Core

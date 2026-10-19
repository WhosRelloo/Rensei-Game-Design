-- Regions (2026-10-19, Morality × Reputation spec §3): the graph of places that word of a deed travels.
-- (Rensei.Places is the teleport place ids, so the graph lives here.) Each region lists the factions present
-- (they react when word arrives), its jurisdiction (whose Heat rises, Plan 2), whether it's a safe zone, and
-- its links: which carrier takes word to which region, in real minutes. Every region, link and minute is a
-- PROPOSAL; Wilds (the Forgotten Sites) is (new).
-- Carriers: Gossip reaches every faction present, slowly; Dispatch (the State's couriers) is fast but only
-- reaches the Authority; Whisper (the Circle's whisper-net) is fast but only reaches the Circle.
-- Communities (Factions.Communities) are diaspora: present in every region.

local Factions = require(script.Parent.Factions)

local Regions = {}

Regions.Carriers = {
	Gossip = {Name = "gossip"}, -- Reaches = nil: everyone present
	Dispatch = {Name = "State dispatch", Reaches = {"Authority"}},
	Whisper = {Name = "the Circle's whisper-net", Reaches = {"Circle"}},
}

Regions.Regions = {
	City = {
		Name = "the City", Factions = {"Authority", "Townsfolk", "Circle"}, Hidden = {Circle = true},
		Jurisdiction = "State", Safe = false,
		Links = {
			{To = "Foundry", Carrier = "Gossip", Minutes = 10}, {To = "Foundry", Carrier = "Dispatch", Minutes = 2},
			{To = "Lindenmoor", Carrier = "Gossip", Minutes = 20}, {To = "Lindenmoor", Carrier = "Dispatch", Minutes = 5},
			{To = "Lindenmoor", Carrier = "Whisper", Minutes = 3},
			{To = "Wilds", Carrier = "Gossip", Minutes = 30},
		},
	},
	Foundry = {
		Name = "the Foundry Yard", Factions = {"Foundry", "Townsfolk"},
		Jurisdiction = "State", Safe = false,
		Links = {{To = "City", Carrier = "Gossip", Minutes = 10}, {To = "City", Carrier = "Dispatch", Minutes = 2}},
	},
	Lindenmoor = {
		Name = "Lindenmoor", Factions = {"Townsfolk", "Circle"}, Hidden = {Circle = true},
		Jurisdiction = "Militia", Safe = false,
		Links = {
			{To = "City", Carrier = "Gossip", Minutes = 20}, {To = "City", Carrier = "Dispatch", Minutes = 5},
			{To = "City", Carrier = "Whisper", Minutes = 3},
			{To = "Adit", Carrier = "Gossip", Minutes = 30},
		},
	},
	Adit = {
		Name = "Halvard's Adit", Factions = {},
		Jurisdiction = "None", Safe = false,
		Links = {{To = "Lindenmoor", Carrier = "Gossip", Minutes = 30}},
	},
	Wilds = { -- (new) the Forgotten Sites
		Name = "the wilds", Factions = {},
		Jurisdiction = "None", Safe = false,
		Links = {{To = "City", Carrier = "Gossip", Minutes = 30}},
	},
}
Regions.Default = "City" -- anywhere outside an area volume is the City (the hub has no AreaName)

-- WorldService area names (AreaName attribute) -> region
Regions.Areas = {
	["Foundry Yard"] = "Foundry",
	["Lindenmoor"] = "Lindenmoor", ["Cypress Ridge"] = "Lindenmoor", ["Mill Creek Bridge"] = "Lindenmoor",
	["Workshop Hill"] = "Lindenmoor", ["Lindenmoor Station"] = "Lindenmoor", ["Bramble Hollow"] = "Lindenmoor",
	["Gorge Lookout"] = "Lindenmoor",
	["Halvard's Adit"] = "Adit",
	["Frozen Research Station"] = "Wilds", ["Cracked Footbridge"] = "Wilds", ["Burned Laboratory"] = "Wilds",
	["Silent Forge"] = "Wilds", ["Silent Observatory"] = "Wilds",
}

function Regions.OfArea(AreaName)
	return (AreaName and Regions.Areas[AreaName]) or Regions.Default
end

local function Diaspora(Faction)
	local F = Factions.Factions[Faction]
	return F ~= nil and F.Diaspora == true
end

function Regions.Present(Region, Faction)
	local R = Regions.Regions[Region]
	if not R then return false end
	return Diaspora(Faction) or table.find(R.Factions, Faction) ~= nil
end

function Regions.FactionsAt(Region)
	local Out = {}
	for _, F in ipairs(Factions.Order) do
		if Regions.Present(Region, F) then table.insert(Out, F) end
	end
	return Out
end

function Regions.Count(Faction)
	local N = 0
	for Id in pairs(Regions.Regions) do if Regions.Present(Id, Faction) then N += 1 end end
	return N
end

-- the factions in Region that word brought by Carrier reaches
function Regions.Reach(Region, Carrier)
	local C = Regions.Carriers[Carrier]
	local Out = {}
	for _, F in ipairs(Regions.FactionsAt(Region)) do
		if not C or not C.Reaches or table.find(C.Reaches, F) then table.insert(Out, F) end
	end
	return Out
end

function Regions.Links(Region)
	local R = Regions.Regions[Region]
	return R and R.Links or {}
end

return Regions

-- Regions (2026-10-19, Morality × Reputation spec §3): the graph of places that word of a deed travels.
-- (Rensei.Places is the teleport place ids, so the graph lives here.) Each region lists the factions present
-- (they react when word arrives), its jurisdiction (whose Heat rises, Plan 2), whether it's a safe zone, and
-- its links: which carrier takes word to which region, in real minutes. Every region, link and minute is a
-- PROPOSAL; Wilds (the Forgotten Sites) is (new).
-- Carriers: Gossip reaches every faction present, slowly; Dispatch (the State's couriers) is fast but only
-- reaches the Authority; Whisper (the Circle's whisper-net) is fast but only reaches the Circle;
-- Rail (World plan 1, 2026-10-23: rumours travel by train) rides the timetable and reaches everyone present.
-- The four region places of World plan 1 (Aerugo, Ishval, North, Corrupted) join the graph; their factions,
-- jurisdictions and links are PROPOSAL.
-- Communities (Factions.Communities) are diaspora: present in every region.

local Factions = require(script.Parent.Factions)

local Regions = {}

Regions.Carriers = {
	Gossip = {Name = "gossip"}, -- Reaches = nil: everyone present
	Dispatch = {Name = "State dispatch", Reaches = {"Authority"}},
	Whisper = {Name = "the Circle's whisper-net", Reaches = {"Circle"}},
	Rail = {Name = "the railway"}, -- World plan 1: word rides the timetable; reaches everyone present
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
			-- World plan 1 (PROPOSAL minutes)
			{To = "Foundry", Carrier = "Rail", Minutes = 3}, {To = "Ishval", Carrier = "Rail", Minutes = 4},
			{To = "Aerugo", Carrier = "Gossip", Minutes = 25}, {To = "Aerugo", Carrier = "Dispatch", Minutes = 6},
			{To = "Ishval", Carrier = "Gossip", Minutes = 40}, {To = "Ishval", Carrier = "Whisper", Minutes = 8},
			{To = "North", Carrier = "Gossip", Minutes = 30}, {To = "North", Carrier = "Dispatch", Minutes = 6},
			{To = "Corrupted", Carrier = "Whisper", Minutes = 5},
		},
	},
	Foundry = {
		Name = "the Foundry Yard", Factions = {"Foundry", "Townsfolk"},
		Jurisdiction = "State", Safe = false,
		Links = {
			{To = "City", Carrier = "Gossip", Minutes = 10}, {To = "City", Carrier = "Dispatch", Minutes = 2},
			{To = "Lindenmoor", Carrier = "Rail", Minutes = 3}, {To = "City", Carrier = "Rail", Minutes = 3}, -- World plan 1 (PROPOSAL)
		},
	},
	Lindenmoor = {
		Name = "Lindenmoor", Factions = {"Townsfolk", "Circle"}, Hidden = {Circle = true},
		Jurisdiction = "Militia", Safe = false,
		Links = {
			{To = "City", Carrier = "Gossip", Minutes = 20}, {To = "City", Carrier = "Dispatch", Minutes = 5},
			{To = "City", Carrier = "Whisper", Minutes = 3},
			{To = "Adit", Carrier = "Gossip", Minutes = 30},
			{To = "Foundry", Carrier = "Rail", Minutes = 3}, -- World plan 1 (PROPOSAL)
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
	-- World plan 1 (2026-10-23): the region places. Factions and jurisdictions are PROPOSAL.
	Aerugo = {Name = "the Aerugo Borderlands", Factions = {"Authority", "Townsfolk"}, Jurisdiction = "State", Safe = false,
		Links = {{To = "City", Carrier = "Gossip", Minutes = 25}, {To = "City", Carrier = "Dispatch", Minutes = 6}, {To = "Corrupted", Carrier = "Gossip", Minutes = 45}}},
	Ishval = {Name = "Ishval", Factions = {"Townsfolk"}, Jurisdiction = "None", Safe = false,
		Links = {{To = "City", Carrier = "Gossip", Minutes = 40}, {To = "City", Carrier = "Rail", Minutes = 4}}},
	North = {Name = "the Northern Wall", Factions = {"Authority"}, Jurisdiction = "State", Safe = false,
		Links = {{To = "City", Carrier = "Gossip", Minutes = 30}, {To = "City", Carrier = "Dispatch", Minutes = 6}, {To = "Corrupted", Carrier = "Gossip", Minutes = 45}}},
	Corrupted = {Name = "the Corrupted Lands", Factions = {"Circle"}, Hidden = {Circle = true}, Jurisdiction = "None", Safe = false,
		Links = {{To = "City", Carrier = "Whisper", Minutes = 5}, {To = "North", Carrier = "Gossip", Minutes = 45}, {To = "Aerugo", Carrier = "Gossip", Minutes = 45}}},
}
-- Outside every area volume: this place's own region (World plan 1 Task 10). HubLaw names the region a place's unnamed
-- ground counts as when that isn't the place's own. Ye: the 2026-10-23 ruling ("Keep State law") kept the hub the
-- City; with the hub gone into the Lindenmoor expansion, the owner chose Lindenmoor's law for Ye's unnamed ground
-- (2026-10-24, "Lindenmoor's (Recommended)"; Lindenmoor import Task 8): Militia jurisdiction, deeds land in Lindenmoor.
local Places = require(script.Parent.Places)
Regions.HubLaw = {[Places.Regions.Lindenmoor.PlaceId] = "Lindenmoor"} -- [PlaceId] = the region its unnamed ground counts as
Regions.Default = Regions.HubLaw[game.PlaceId] or Places.RegionOf(game.PlaceId) or "City"

-- North per place (Lindenmoor import Task 8 fix round 4, Ruling 38b): each place declares which world axis is north;
-- a place not listed keeps -Z (the compass of 2026-10-18). East is always north turned 90 degrees clockwise seen from
-- above, and Roblox is right-handed: +Z north means east is -X, and -Z north means east is +X. So the compass is only
-- ever a rotation (it reads W . N . E as usual, with marks on the side of the screen they are on). Ye (Lindenmoor's
-- expansion) is laid out with +Z north; the Foundry place uses -Z. CompassUI and the MasteryUI Guide read this.
Regions.NorthAxis = {[Places.Regions.Lindenmoor.PlaceId] = "+Z"} -- [PlaceId] = "+Z" or "-Z"
function Regions.NorthOf(PlaceId)
	return Regions.NorthAxis[PlaceId or game.PlaceId] or "-Z"
end
-- the compass bearing of a flat world offset (X, Z): degrees clockwise from north seen from above, in (-180, 180]
-- (0 north, 90 east, 180 south, -90 west), for this place's north (or the given "+Z" / "-Z")
function Regions.Bearing(X, Z, North)
	local S = (North or Regions.NorthOf()) == "+Z" and 1 or -1 -- the sign of Z that points north
	return math.deg(math.atan2(-S * X, S * Z))
end

-- WorldService area names (AreaName attribute) -> region
Regions.Areas = {
	["Foundry Yard"] = "Foundry",
	["Lindenmoor"] = "Lindenmoor", ["Cypress Ridge"] = "Lindenmoor", ["Mill Creek Bridge"] = "Lindenmoor",
	["Workshop Hill"] = "Lindenmoor", ["Lindenmoor Station"] = "Lindenmoor", ["Bramble Hollow"] = "Lindenmoor",
	["Gorge Lookout"] = "Lindenmoor",
	-- the Lindenmoor expansion's areas (Lindenmoor import Task 8, 2026-10-24; Art/Regions/Lindenmoor/layout.json)
	["Outlying Farmsteads"] = "Lindenmoor", ["Mine Approach"] = "Lindenmoor", ["Mill Creek Gorge"] = "Lindenmoor",
	["West Lookout"] = "Lindenmoor", ["Bramble Woods"] = "Lindenmoor", ["Training Field"] = "Lindenmoor",
	["Ridge Marker"] = "Lindenmoor", ["North Meadows"] = "Lindenmoor", ["Cypress Ridge Rim"] = "Lindenmoor",
	["Northwest Gap"] = "Lindenmoor", -- (fix round 4, Ruling 38b: +Z is north in Ye, so +X is west; were East Lookout
	-- and Northeast Gap, named in the layout's x = east frame)
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

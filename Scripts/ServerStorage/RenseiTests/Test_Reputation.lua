local Rensei = game.ReplicatedStorage.Modules.Data.Rensei
local Reputation = require(Rensei.Reputation)
local Regions = require(Rensei.Regions)
local Deeds = {
	d_local = {Text = "x", Standing = {Authority = 12, Foundry = -6, Circle = -8}, Scope = "Local"},
	d_public = {Text = "y", Standing = {Townsfolk = 4}, Renown = 10, Scope = "Public"},
	d_private = {Text = "z", Standing = {Circle = 20}, Scope = "Private"},
	d_birth = {Text = "b", Standing = {IshvalanCommunity = 20, Authority = -15}, Scope = "Public", Birth = true},
}
local function Fresh(Ledger)
	return {Deeds = Ledger or {}, Places = {}, Standing = {}, Renown = 0}
end
return {
	LandIsOncePerFactionPerPlace = function(T)
		local M = Fresh({d_local = {At = 0, Count = 1}})
		T.Same(Reputation.Land(M, "Foundry", "d_local", {"Foundry", "Townsfolk"}, 5), {"Foundry", "Townsfolk"})
		T.Same(Reputation.Land(M, "Foundry", "d_local", {"Foundry", "Townsfolk"}, 9), {})
		T.Eq(M.Places.Foundry.Known.d_local.Foundry, 5, "first time kept")
	end,
	LandIgnoresAbsentFactions = function(T)
		local M = Fresh({d_local = {At = 0, Count = 1}})
		T.Same(Reputation.Land(M, "Foundry", "d_local", {"Authority"}, 1), {}, "no Authority in the Foundry")
	end,
	PlaceAndGlobalStanding = function(T)
		local M = Fresh({d_local = {At = 0, Count = 2}})
		Reputation.Land(M, "Foundry", "d_local", Regions.FactionsAt("Foundry"), 1)
		T.Same(Reputation.PlaceStanding(M, Deeds, "Foundry"), {Foundry = -12})
		T.Near(Reputation.GlobalStanding(M, Deeds).Foundry, -12, 1e-9, "Foundry is only in the Foundry")
		Reputation.Land(M, "City", "d_local", {"Authority", "Circle"}, 2)
		local G = Reputation.GlobalStanding(M, Deeds)
		-- World plan 1 Task 10: the Authority is now in 3 regions (City, Aerugo, North) and the Circle in 3 (City,
		-- Lindenmoor, Corrupted), so a deed heard only in the City is a third of its full weight for both
		T.Near(G.Authority, 8, 1e-9, "Authority: heard in 1 of its 3 regions -> a third of 24")
		T.Near(G.Circle, -16 / 3, 1e-9, "Circle: heard in 1 of its 3 regions -> a third of -16")
	end,
	EverywhereIsFull = function(T)
		local M = Fresh({d_local = {At = 0, Count = 1}})
		Reputation.LandEverywhere(M, "d_local", 0)
		local G = Reputation.GlobalStanding(M, Deeds)
		T.Near(G.Authority, 12, 1e-9); T.Near(G.Foundry, -6, 1e-9); T.Near(G.Circle, -8, 1e-9)
	end,
	RenownNeedsAPublicDeedHeardSomewhere = function(T)
		local M = Fresh({d_public = {At = 0, Count = 1}, d_local = {At = 0, Count = 1}})
		T.Eq(Reputation.Renown(M, Deeds), 0)
		Reputation.Land(M, "City", "d_public", {"Townsfolk"}, 0)
		T.Eq(Reputation.Renown(M, Deeds), 10)
	end,
	SeedSpreadsOldKnownDeedsOnce = function(T)
		local M = Fresh({d_local = {At = 3, Count = 1}, d_private = {At = 3, Count = 1}})
		T.True(Reputation.Seed(M, Deeds, 100))
		T.True(not Reputation.Seed(M, Deeds, 200), "only once")
		T.True(Reputation.Landed(M, "d_local"))
		T.True(not Reputation.Landed(M, "d_private"), "private deeds stay unheard")
		T.Eq(M.Places.City.Known.d_local.Authority, 3, "stamped with the deed's own time")
	end,
	DiscoveredPrivateCountsAsItsKnownScope = function(T)
		local M = Fresh({d_private = {At = 0, Count = 1, Known = "Local"}})
		Reputation.Seed(M, Deeds, 0)
		T.True(Reputation.Landed(M, "d_private"))
	end,
	-- World plan 1 Task 10 fix 1: a save from before the four region places joined keeps its standing. Its birth deed
	-- and its "heard everywhere" deeds were landed in the old 5 regions only; the join step lands them in the new ones.
	OldSaveKeepsStandingAfterNewRegions = function(T)
		local Real = require(Rensei.Deeds)
		local All = {born_Ishvalan = Real.born_Ishvalan, d_local = Deeds.d_local, d_public = Deeds.d_public}
		local M = Fresh({born_Ishvalan = {At = 1, Count = 1}, d_local = {At = 2, Count = 1}, d_public = {At = 3, Count = 1}})
		M.Seeded = true
		for _, Region in ipairs(Reputation.OldRegions) do -- the old LandEverywhere
			Reputation.Land(M, Region, "born_Ishvalan", Regions.FactionsAt(Region), 1)
			Reputation.Land(M, Region, "d_local", Regions.FactionsAt(Region), 2)
		end
		Reputation.Land(M, "City", "d_public", {"Townsfolk"}, 3) -- heard in one place only: not spread
		local Full = Real.born_Ishvalan.Standing.IshvalanCommunity
		T.Eq(Full, 20, "born_Ishvalan is +20 IshvalanCommunity")
		T.True(Reputation.GlobalStanding(M, All).IshvalanCommunity < Full - 1, "before: diluted by the new regions")
		T.True(Reputation.CatchUpRegions(M, All, 100))
		local G = Reputation.GlobalStanding(M, All)
		T.Near(G.IshvalanCommunity, Full, 1e-9, "birth deed counts in full again")
		local Born = Real.born_Ishvalan.Standing -- the birth deed also moves other factions
		T.Near(G.Authority, 12 + (Born.Authority or 0), 1e-9, "an old everywhere deed counts in full again")
		T.Near(G.Circle, -8 + (Born.Circle or 0), 1e-9)
		T.Eq(M.Places.Aerugo.Known.d_local.Authority, 2, "stamped with the deed's own time")
		T.Eq(M.Places.Aerugo.Known.d_public, nil, "a one-place deed isn't spread")
		T.Eq(M.SeededRegions, Reputation.RegionsVersion)
		local Before = game:GetService("HttpService"):JSONEncode(M.Places)
		local Snapshot = Reputation.GlobalStanding(M, All)
		T.True(not Reputation.CatchUpRegions(M, All, 200), "a second run changes nothing")
		T.Same(Reputation.GlobalStanding(M, All), Snapshot)
		T.Eq(game:GetService("HttpService"):JSONEncode(M.Places), Before, "places untouched")
	end,
	-- fix 2: per faction. Before Task 10 the Authority lived only in the City, so a deed it heard there counted in
	-- full; Townsfolk lived in City, Foundry and Lindenmoor, so one heard in only some of them didn't
	PerFactionReseed = function(T)
		local All = {d_local = Deeds.d_local, d_public = Deeds.d_public}
		local M = Fresh({d_local = {At = 4, Count = 1}, d_public = {At = 5, Count = 1}})
		M.Seeded = true
		M.SeededRegions = 9 -- migrated by the round-1 rule already: version 10 runs once more
		Reputation.Land(M, "City", "d_local", {"Authority"}, 4) -- the Authority's only old region
		Reputation.Land(M, "City", "d_public", {"Townsfolk"}, 5) -- Townsfolk: City only, not Foundry / Lindenmoor
		Reputation.Land(M, "Foundry", "d_public", {"Townsfolk"}, 5)
		T.Near(Reputation.GlobalStanding(M, All).Authority, 12 / 3, 1e-9, "before: a third (City of City, Aerugo, North)")
		T.True(Reputation.CatchUpRegions(M, All, 100))
		local G = Reputation.GlobalStanding(M, All)
		T.Near(G.Authority, 12, 1e-9, "a City deed the Authority heard counts in full again")
		T.Eq(M.Places.Aerugo.Known.d_local.Authority, 4, "stamped with the deed's own time")
		T.Eq(M.Places.North.Known.d_local.Authority, 4)
		T.Eq(M.Places.Aerugo.Known.d_local.Townsfolk, nil, "only the faction that heard it everywhere it lived")
		T.True(M.Places.Aerugo.Known.d_public == nil and (M.Places.Ishval == nil or M.Places.Ishval.Known.d_public == nil),
			"Townsfolk heard d_public in only some of its old regions: not spread")
		T.Eq(M.SeededRegions, Reputation.RegionsVersion)
		local Before = game:GetService("HttpService"):JSONEncode(M.Places)
		T.True(not Reputation.CatchUpRegions(M, All, 200), "a second run changes nothing")
		T.Eq(game:GetService("HttpService"):JSONEncode(M.Places), Before, "places untouched")
	end,
	BirthDeedLandsInNewRegionsEvenAfterTheReseed = function(T)
		local Real = require(Rensei.Deeds)
		local All = {born_Ishvalan = Real.born_Ishvalan}
		local M = Fresh({born_Ishvalan = {At = 1, Count = 1}})
		M.SeededRegions = Reputation.RegionsVersion
		Reputation.Land(M, "City", "born_Ishvalan", Regions.FactionsAt("City"), 1)
		T.True(Reputation.CatchUpRegions(M, All, 5))
		T.Near(Reputation.GlobalStanding(M, All).IshvalanCommunity, 20, 1e-9)
	end,
}

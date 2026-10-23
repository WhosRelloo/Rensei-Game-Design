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
}

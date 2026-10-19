local Rensei = game.ReplicatedStorage.Modules.Data.Rensei
local Regions = require(Rensei.Regions)
local Factions = require(Rensei.Factions)
local Deeds = require(Rensei.Deeds)
return {
	LinksPointAtRealRegions = function(T)
		for Id, R in pairs(Regions.Regions) do
			for _, L in ipairs(R.Links) do
				T.True(Regions.Regions[L.To] ~= nil, Id .. " -> " .. L.To)
				T.True(Regions.Carriers[L.Carrier] ~= nil, Id .. " carrier " .. L.Carrier)
				T.True(L.Minutes > 0, Id .. " minutes")
			end
		end
	end,
	AreasMapToRegions = function(T)
		T.Eq(Regions.OfArea("Foundry Yard"), "Foundry")
		T.Eq(Regions.OfArea("Workshop Hill"), "Lindenmoor")
		T.Eq(Regions.OfArea("Halvard's Adit"), "Adit")
		T.Eq(Regions.OfArea("Silent Forge"), "Wilds")
		T.Eq(Regions.OfArea(nil), "City")
		T.Eq(Regions.OfArea("Somewhere New"), "City")
	end,
	PresenceAndCounts = function(T)
		T.True(Regions.Present("City", "Authority"))
		T.True(not Regions.Present("Foundry", "Authority"))
		T.True(Regions.Present("Lindenmoor", "Circle"))
		T.Eq(Regions.Count("Circle"), 2)
		T.True(Regions.Present("Adit", "IshvalanCommunity"), "communities live everywhere")
		T.Eq(Regions.Count("IshvalanCommunity"), 5)
	end,
	CarriersReachTheirFactions = function(T)
		T.Same(Regions.Reach("City", "Dispatch"), {"Authority"})
		T.Same(Regions.Reach("Foundry", "Dispatch"), {})
		local G = Regions.Reach("City", "Gossip")
		T.True(table.find(G, "Townsfolk") and table.find(G, "Circle") and table.find(G, "Authority"), "gossip reaches all")
		T.Same(Regions.Reach("Lindenmoor", "Whisper"), {"Circle"})
	end,
	EveryOriginHasABoundedBirthDeed = function(T)
		local Customization = require(Rensei.Customization)
		for Origin in pairs(Customization.Nations) do
			local D = Deeds["born_" .. Origin]
			T.True(D and D.Birth and D.Text, "born_" .. Origin)
			local Sum = 0
			for F, V in pairs(D.Standing) do
				T.True(Factions.Factions[F] ~= nil, F .. " is a faction")
				T.True(math.abs(V) <= 20, Origin .. " " .. F .. " within +-20")
				Sum += V
			end
			T.True(Sum >= 0, Origin .. " offsets add up to >= 0")
			T.True(D.Standing[Factions.Communities[Origin]] ~= nil, Origin .. " touches its own community")
		end
	end,
}

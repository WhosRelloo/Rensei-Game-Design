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
		-- World plan 1 Task 10: outside every area volume is this place's own region (Ye: Lindenmoor)
		local Own = require(game.ReplicatedStorage.Modules.Data.Rensei.Places).RegionOf(game.PlaceId) or "City"
		T.Eq(Regions.OfArea(nil), Own)
		T.Eq(Regions.OfArea("Somewhere New"), Own)
	end,
	PresenceAndCounts = function(T)
		T.True(Regions.Present("City", "Authority"))
		T.True(not Regions.Present("Foundry", "Authority"))
		T.True(Regions.Present("Lindenmoor", "Circle"))
		T.Eq(Regions.Count("Circle"), 3) -- City, Lindenmoor and (World plan 1 Task 10) the Corrupted Lands
		T.True(Regions.Present("Adit", "IshvalanCommunity"), "communities live everywhere")
		T.Eq(Regions.Count("IshvalanCommunity"), 9) -- 5 regions plus Aerugo, Ishval, North and Corrupted (Task 10)
	end,
	NewRegionsAndRail = function(T)
		for _, Id in ipairs({"Aerugo", "Ishval", "North", "Corrupted"}) do T.True(Regions.Regions[Id] ~= nil, Id) end
		T.True(Regions.Carriers.Rail ~= nil and Regions.Carriers.Rail.Reaches == nil, "rail reaches everyone")
		local Rail = false
		for _, L in ipairs(Regions.Regions.Lindenmoor.Links) do if L.To == "Foundry" and L.Carrier == "Rail" then Rail = true end end
		T.True(Rail, "Lindenmoor -> Foundry by rail")
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

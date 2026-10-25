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
		-- World plan 1 Task 10: outside every area volume is this place's own region. Lindenmoor import Task 8 (owner
		-- 2026-10-24, "Lindenmoor's (Recommended)"): the hub is gone, so Ye's unnamed ground follows Lindenmoor's law
		-- (it was the City, State law, under the 2026-10-23 "Keep State law" ruling)
		local Places = require(game.ReplicatedStorage.Modules.Data.Rensei.Places)
		local Own = Regions.HubLaw[game.PlaceId] or Places.RegionOf(game.PlaceId) or "City"
		T.Eq(Regions.OfArea(nil), Own)
		T.Eq(Regions.OfArea("Somewhere New"), Own)
		if game.PlaceId == 106992859583940 then
			T.Eq(Regions.Default, "Lindenmoor", "Ye's unnamed ground is Lindenmoor")
			T.Eq(Regions.Regions[Regions.Default].Jurisdiction, "Militia", "under Lindenmoor's law, not the State's")
			T.Eq(Places.RegionOf(game.PlaceId), "Lindenmoor", "Ye itself is Lindenmoor (TravelService.Here)")
		end
		-- only Ye has an entry: every other region place's unnamed ground is its own region
		for Id, R in pairs(Places.Regions) do
			if Id ~= "Lindenmoor" then T.Eq(Regions.HubLaw[R.PlaceId], nil, Id .. " has no hub exception") end
		end
		T.Eq(Regions.HubLaw[Places.Regions.Lindenmoor.PlaceId], "Lindenmoor", "Ye's unnamed ground: Lindenmoor's law")
	end,
	-- Lindenmoor import Task 8: the expansion's ten areas are Lindenmoor's
	ExpansionAreasAreLindenmoor = function(T)
		-- (fix round 4, Ruling 38b: West Lookout and Northwest Gap were East Lookout and Northeast Gap)
		for _, Name in ipairs({"Outlying Farmsteads", "Mine Approach", "Mill Creek Gorge", "West Lookout", "Bramble Woods",
			"Training Field", "Ridge Marker", "North Meadows", "Cypress Ridge Rim", "Northwest Gap"}) do
			T.Eq(Regions.Areas[Name], "Lindenmoor", Name)
			T.Eq(Regions.OfArea(Name), "Lindenmoor", Name)
		end
		-- the trial sites moved into those areas keep their own region (their smaller boxes win, WorldService.AreaAt)
		T.Eq(Regions.OfArea("Burned Laboratory"), "Wilds")
		T.Eq(Regions.Areas["East Lookout"], nil, "the old name is gone")
		T.Eq(Regions.Areas["Northeast Gap"], nil, "the old name is gone")
	end,
	-- Lindenmoor import Task 8 fix round 4 (Ruling 38b): north per place, and the compass is never mirrored
	NorthPerPlace = function(T)
		local Places = require(Rensei.Places)
		T.Eq(Regions.NorthOf(Places.Regions.Lindenmoor.PlaceId), "+Z", "Ye: north is +Z")
		T.Eq(Regions.NorthOf(Places.Regions.Foundry.PlaceId), "-Z", "Foundry: north is -Z")
		T.Eq(Regions.NorthOf(123), "-Z", "a place not listed keeps -Z")
		if game.PlaceId == Places.Regions.Lindenmoor.PlaceId then T.Eq(Regions.NorthOf(), "+Z", "here (Ye)") end
		for _, N in ipairs({"+Z", "-Z"}) do
			local S = N == "+Z" and 1 or -1
			local function B(X, Z) return Regions.Bearing(X, Z, N) end
			T.Near(B(0, S), 0, 1e-6, N .. ": north")
			T.Near(B(-S, 0), 90, 1e-6, N .. ": east is " .. (S == 1 and "-X" or "+X"))
			T.Near(math.abs(B(0, -S)), 180, 1e-6, N .. ": south")
			T.Near(B(S, 0), -90, 1e-6, N .. ": west")
			-- facing north, east is on the right of the screen (a rotation, not a mirror)...
			local Face = CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, S))
			T.Near(B(Face.RightVector.X, Face.RightVector.Z), 90, 1e-4, N .. ": facing north, the screen's right is east")
			-- ...and turning right turns the heading clockwise
			local Turned = (Face * CFrame.Angles(0, -math.rad(10), 0)).LookVector
			T.Near(B(Turned.X, Turned.Z), 10, 1e-4, N .. ": a 10-degree right turn reads 10")
		end
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

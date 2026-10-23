local Rensei = game.ReplicatedStorage.Modules.Data.Rensei
-- server modules live in ServerStorage.RenseiServer in Edit mode (World Plan 1 Task 3); ServerScriptService at runtime
local Core = require((game.ServerScriptService:FindFirstChild("RumourService") or game.ServerStorage.RenseiServer.RumourService).Core)
local Reputation = require(Rensei.Reputation)
local Regions = require(Rensei.Regions)
local function Fresh()
	local M = {Deeds = {d = {At = 0, Count = 1}}, Places = {}, Rumours = {}, News = {}}
	Reputation.Land(M, "Foundry", "d", Regions.FactionsAt("Foundry"), 0) -- heard where it happened
	return M
end
local function Heard(M, Region, F)
	local P = M.Places[Region]
	return P ~= nil and P.Known.d ~= nil and P.Known.d[F] ~= nil
end
return {
	-- World plan 1 Task 10: the railway carries word too. From the Foundry the train reaches the City and Lindenmoor
	-- in 3 min, everyone present, so the old "gossip at 10 min" now finds the City already knows.
	DispatchThenRail = function(T)
		local M = Fresh()
		T.True(Core.Spawn(M, "d", "Foundry", 2, 0) ~= nil)
		T.Eq(#Core.Advance(M, 119), 0, "nothing before 2 min")
		local A = Core.Advance(M, 120)
		T.Eq(#A, 1); T.Eq(A[1].Place, "City"); T.Same(A[1].Heard, {"Authority"}, "dispatch: only the Authority")
		T.True(not Heard(M, "City", "Townsfolk"))
		T.Eq(#Core.Advance(M, 179), 0)
		local B = Core.Advance(M, 180)
		T.Eq(#B, 2, "the train at 3 min: Lindenmoor and the City")
		local City = B[1].Place == "City" and B[1] or B[2]
		T.Eq(City.Place, "City"); T.Eq(City.Carrier, "Rail")
		T.True(table.find(City.Heard, "Circle") and table.find(City.Heard, "Townsfolk"), "rail reaches the Circle and Townsfolk")
		T.True(table.find(City.Heard, "IshvalanCommunity") ~= nil, "and the communities (present everywhere)")
		T.True(not table.find(City.Heard, "Authority"), "the Authority heard already, by dispatch")
		T.True(Heard(M, "Lindenmoor", "Townsfolk"), "the train took it to Lindenmoor too")
		T.Eq(#Core.Advance(M, 100000), 0, "strength 2: one hop, no further (the 10 min gossip finds no one new)")
		T.True(not M.Places.Ishval, "never reached Ishval (two hops)")
		T.Eq(#M.News, 3)
	end,
	-- the old DispatchThenGossip, from a place no train serves (Aerugo: dispatch 6 min, gossip 25 min to the City)
	DispatchThenGossipOffTheRails = function(T)
		local M = Fresh()
		T.True(Core.Spawn(M, "d", "Aerugo", 2, 0) ~= nil)
		T.Eq(#Core.Advance(M, 359), 0, "nothing before 6 min")
		local A = Core.Advance(M, 360)
		T.Eq(#A, 1); T.Eq(A[1].Place, "City"); T.Same(A[1].Heard, {"Authority"}, "dispatch: only the Authority")
		T.Eq(#Core.Advance(M, 1499), 0)
		local B = Core.Advance(M, 1500)
		T.Eq(#B, 1, "gossip at 25 min")
		T.True(table.find(B[1].Heard, "Circle") and table.find(B[1].Heard, "Townsfolk"), "gossip reaches the Circle and Townsfolk")
		T.True(table.find(B[1].Heard, "IshvalanCommunity") ~= nil, "and the communities (present everywhere)")
		T.True(not table.find(B[1].Heard, "Authority"), "the Authority heard already, by dispatch")
	end,
	OncePerPlace = function(T)
		local M = Fresh()
		Core.Spawn(M, "d", "Foundry", 5, 0)
		-- counted from Advance's arrivals: with the new regions strength 5 lands 11 times, more than News keeps (10)
		local Count = 0
		for _, N in ipairs(Core.Advance(M, 100000)) do if N.Place == "City" then Count += 1 end end
		T.Eq(Count, 2, "City: dispatch once + rail once (the gossip finds no one new), never repeated")
		T.True(Heard(M, "Ishval", "Townsfolk"), "strength 5 goes further (Foundry -> City -> Ishval by rail)")
	end,
	OfflineCatchUpMatchesOnline = function(T)
		local A, B = Fresh(), Fresh()
		Core.Spawn(A, "d", "Foundry", 4, 0); Core.Spawn(B, "d", "Foundry", 4, 0)
		for Now = 0, 7200, 60 do Core.Advance(A, Now) end
		Core.Advance(B, 7200)
		T.Same(A.Places, B.Places, "same places")
		T.Same(A.News, B.News, "same news, same order")
	end,
	SilencingStopsIt = function(T)
		local M = Fresh()
		local R = Core.Spawn(M, "d", "Foundry", 2, 0)
		Core.Silence(M, R.Id, 1)
		T.Eq(#Core.Advance(M, 100000), 0, "strength 1: hop 1 lands nothing")
		local M2 = Fresh()
		local R2 = Core.Spawn(M2, "d", "Foundry", 2, 0)
		Core.Silence(M2, R2.Id, 2)
		T.True(R2.Suppressed, "suppressed at 0")
	end,
	SameDeedSameOriginReusesTheLiveRumour = function(T)
		local M = Fresh()
		local R1 = Core.Spawn(M, "d", "Foundry", 2, 0)
		local R2 = Core.Spawn(M, "d", "Foundry", 2, 30)
		T.Eq(R1, R2); T.Eq(#M.Rumours, 1)
	end,
	ReportLandsAtOnceForTheDesk = function(T)
		local M = Fresh()
		T.Same(Core.LandReport(M, "d", "City", "Authority", 50), {"Authority"})
		T.Same(Core.LandReport(M, "d", "City", "Authority", 60), {}, "once")
		T.True(M.News[1].Report)
	end,
	AtMostTwentyLive = function(T)
		local M = Fresh()
		for I = 1, 25 do
			M.Deeds["d" .. I] = {At = 0, Count = 1}
			Core.Spawn(M, "d" .. I, "Foundry", 3, I)
		end
		T.Eq(#M.Rumours, Core.MaxLive)
		T.Eq(M.Rumours[#M.Rumours].Deed, "d25", "newest kept")
	end,
	-- Plan 2: every landing is reported (HeatService), even where nobody hears the deed for the first time
	LandingsIncludeRepeats = function(T)
		local M = Fresh()
		Reputation.Land(M, "City", "d", {"Authority"}, 0) -- the City's Authority knew already (an earlier crime)
		Core.Spawn(M, "d", "Foundry", 2, 0)
		local Arrivals, Landings = Core.Advance(M, 120)
		T.Eq(#Arrivals, 0, "nothing new heard")
		T.Eq(#Landings, 1, "but the dispatch landed")
		T.Eq(Landings[1].Place, "City")
		T.Same(Landings[1].Reach, {"Authority"}, "dispatch reaches the Authority")
	end,
	NewsIsBounded = function(T)
		local M = Fresh()
		for I = 1, 15 do Core.LandReport(M, "x" .. I, "City", "Authority", I) end
		T.Eq(#M.News, Core.MaxNews)
		T.Eq(M.News[1].Deed, "x15", "newest first")
	end,
}

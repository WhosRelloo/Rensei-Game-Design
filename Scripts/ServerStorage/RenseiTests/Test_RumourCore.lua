local Rensei = game.ReplicatedStorage.Modules.Data.Rensei
local Core = require(game.ServerScriptService.RumourService.Core)
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
	DispatchThenGossip = function(T)
		local M = Fresh()
		T.True(Core.Spawn(M, "d", "Foundry", 2, 0) ~= nil)
		T.Eq(#Core.Advance(M, 119), 0, "nothing before 2 min")
		local A = Core.Advance(M, 120)
		T.Eq(#A, 1); T.Eq(A[1].Place, "City"); T.Same(A[1].Heard, {"Authority"}, "dispatch: only the Authority")
		T.True(not Heard(M, "City", "Townsfolk"))
		T.Eq(#Core.Advance(M, 599), 0)
		local B = Core.Advance(M, 600)
		T.Eq(#B, 1, "gossip at 10 min")
		T.True(table.find(B[1].Heard, "Circle") and table.find(B[1].Heard, "Townsfolk"), "gossip reaches the Circle and Townsfolk")
		T.True(table.find(B[1].Heard, "IshvalanCommunity") ~= nil, "and the communities (present everywhere)")
		T.True(not table.find(B[1].Heard, "Authority"), "the Authority heard already, by dispatch")
		T.Eq(#Core.Advance(M, 100000), 0, "strength 2: one hop, no further")
		T.True(not M.Places.Lindenmoor, "never reached Lindenmoor")
		T.Eq(#M.News, 2)
	end,
	OncePerPlace = function(T)
		local M = Fresh()
		Core.Spawn(M, "d", "Foundry", 5, 0)
		Core.Advance(M, 100000)
		local Count = 0
		for _, N in ipairs(M.News) do if N.Place == "City" then Count += 1 end end
		T.Eq(Count, 2, "City: dispatch once + gossip once, never repeated")
		T.True(Heard(M, "Lindenmoor", "Townsfolk"), "strength 5 goes further")
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
	NewsIsBounded = function(T)
		local M = Fresh()
		for I = 1, 15 do Core.LandReport(M, "x" .. I, "City", "Authority", I) end
		T.Eq(#M.News, Core.MaxNews)
		T.Eq(M.News[1].Deed, "x15", "newest first")
	end,
}

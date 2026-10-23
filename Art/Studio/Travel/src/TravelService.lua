-- TravelService (World plan 1, 2026-10-20; world spec §2–3): getting a group from this region to another.
--   * Depart(List, RouteId, ArriveAt) YIELDS (up to ReleaseWait s): the players that can go (not already teleporting,
--     profile loaded) get Data.Travel.Trip = {Route, To, Arrive, Class} written into their save, their saves are
--     released in parallel (DataManager:Release), and the whole group goes in ONE teleport (FlowTeleport.SendGroup).
--     A trip that still fails kicks (the save was released); the ticket is only used on arrival, so nothing is lost.
--   * Arrival trusts only the SAVE, never TeleportData (it passes through the client; review fix 2026-10-21):
--       - a saved Trip whose To is this region -> Arrive: spawn at the RenseiArrival part whose Point matches, burn
--         exactly the Trip's ticket class, Data.Travel.Region = this region, Trip cleared;
--       - a Trip to anywhere else (a failed trip that rejoined the origin, ...) -> Trip cleared, the ticket kept;
--       - no Trip: the player stays only if Data.Travel.Region is this region, or Region is empty / unknown and this
--         is Lindenmoor (new and legacy saves). Anyone else is sent to Places.ResumePlace (live) or warned (Studio).
--     Joins that FlowService bounces to the menu (live: not an in-flow teleport, or not Ready) are left alone, so
--     nothing here writes a region into a save that FlowService is about to release.
--   * Studio can't teleport: Depart writes the Trip as usual, then runs Arrive from it in this place ("loopback").
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Places = require(ReplicatedStorage.Modules.Data.Rensei.Places)
local Travel = require(ReplicatedStorage.Modules.Data.Rensei.Travel)
local DataManager = require(ServerScriptService.CharacterHandler.DataManager)
local FlowTeleport = require(ServerScriptService.FlowTeleport)
local ProgressionService = require(ServerScriptService.ProgressionService)
local UIService = require(ServerScriptService.UIService)

local TravelService = {}
TravelService.Arrived = Instance.new("BindableEvent") -- (Player, RegionId, RouteId)
TravelService.ReleaseWait = 7 -- PROPOSAL: seconds Depart waits for the parallel save releases before teleporting
TravelService.ProfileWait = 30 -- PROPOSAL: seconds a join waits for the profile
TravelService.SpawnLift = 3 -- PROPOSAL: studs above the arrival part the character is placed

function TravelService.Here()
	return Places.RegionOf(game.PlaceId) or "Lindenmoor"
end

function TravelService.ArrivalPoint(Point)
	for _, P in ipairs(CollectionService:GetTagged("RenseiArrival")) do
		if P:GetAttribute("Point") == Point and P:IsDescendantOf(workspace) then return P end
	end
	return nil
end

local function TravelData(Player)
	local D = ProgressionService.GetData(Player)
	if not D then return nil end
	D.Travel = D.Travel or {Region = "", Tickets = {}}
	D.Travel.Tickets = D.Travel.Tickets or {}
	return D.Travel
end

function TravelService.Tickets(Player)
	local T = TravelData(Player)
	return T and T.Tickets or {}
end

-- the best class the player holds a ticket for on RouteId (Cabin > Second > Third), or nil
function TravelService.HasTicket(Player, RouteId)
	local Tickets = TravelService.Tickets(Player)
	for I = #Travel.ClassOrder, 1, -1 do
		local C = Travel.ClassOrder[I]
		if (Tickets[Travel.TicketKey(RouteId, C)] or 0) > 0 then return C end
	end
	return nil
end

function TravelService.AddTicket(Player, RouteId, ClassId)
	local T = TravelData(Player)
	if not T or not Travel.Routes[RouteId] or not Travel.Classes[ClassId] then return false end
	local K = Travel.TicketKey(RouteId, ClassId)
	T.Tickets[K] = (T.Tickets[K] or 0) + 1
	return true
end

-- Burn one ticket for RouteId: of ClassId when given, else of the best class held. Returns the class, or nil.
function TravelService.UseTicket(Player, RouteId, ClassId)
	local C = ClassId or TravelService.HasTicket(Player, RouteId)
	if not C then return nil end
	local T = TravelData(Player)
	if not T then return nil end
	local K = Travel.TicketKey(RouteId, C)
	if (T.Tickets[K] or 0) <= 0 then return nil end
	T.Tickets[K] -= 1
	if T.Tickets[K] <= 0 then T.Tickets[K] = nil end
	return C
end

local function Spawn(Player, Point)
	local Character = Player.Character or Player.CharacterAdded:Wait()
	local Root = Character:WaitForChild("HumanoidRootPart", 10)
	local At = TravelService.ArrivalPoint(Point) or TravelService.ArrivalPoint("Platform")
	if Root and At then Character:PivotTo(At.CFrame + Vector3.new(0, TravelService.SpawnLift, 0)) end
end

-- Info = a saved Trip {Route = RouteId, To = RegionId, Arrive = Point, Class = ClassId?}. The caller has checked it.
function TravelService.Arrive(Player, Info)
	local Here = TravelService.Here()
	local T = TravelData(Player)
	if T then
		T.Region = Here
		T.Trip = nil
	end
	if Info.Class and Info.Route and Travel.Routes[Info.Route] and Travel.Routes[Info.Route].Kind == "Rail" then
		TravelService.UseTicket(Player, Info.Route, Info.Class)
	end
	Spawn(Player, Info.Arrive or "Platform")
	local Name = Places.Regions[Here] and Places.Regions[Here].Name or Here
	UIService.Notify(Player, "Toast", {Text = "You arrive in " .. Name .. "."})
	TravelService.Arrived:Fire(Player, Here, Info.Route)
	-- World plan 1 Task 10: arriving somewhere is a quest objective ({Kind = "Arrive", Target = <region id>}), signalled
	-- once per arrival, after the save is settled and the arrival announced; spawned, so quest banners (and rewards,
	-- which can yield) never hold up the arrival.
	if T then
		task.spawn(function()
			local Ok, Err = pcall(function() require(ServerScriptService.QuestService).Signal(Player, "Arrive", Here, 1) end)
			if not Ok then warn("TravelService: Arrive quest signal failed:", Err) end
		end)
	end
end

-- Returns "sent" | "loopback", and the players that actually left (busy or unloaded ones are dropped).
-- Opts (optional, Task 8b): {Join = a server (JobId) of the destination place to try first (a road party's stragglers
-- follow their party there; if it's full or gone, FlowTeleport falls back to the normal teleport), Nonce = the road
-- crossing's id, passed on in TeleportData.Travel (the arriving server shares it with the party's stragglers)}.
function TravelService.Depart(List, RouteId, ArriveAt, Opts)
	Opts = type(Opts) == "table" and Opts or {}
	local Join = type(Opts.Join) == "string" and Opts.Join or nil
	local Here = TravelService.Here()
	local Dest = Travel.Other(RouteId, Here)
	assert(Dest, "route " .. tostring(RouteId) .. " doesn't leave " .. Here)
	local Rail = Travel.Routes[RouteId].Kind == "Rail"
	local Going = {}
	for _, P in ipairs(List) do
		local T = P.Parent and not FlowTeleport.Busy(P) and not FlowTeleport.InGroup(P) and TravelData(P)
		if T then
			T.Trip = {Route = RouteId, To = Dest, Arrive = ArriveAt or "Platform", Class = Rail and TravelService.HasTicket(P, RouteId) or nil}
			table.insert(Going, P)
		end
	end
	if RunService:IsStudio() then
		for _, P in ipairs(Going) do
			task.spawn(function()
				local T = TravelData(P)
				local Trip = T and T.Trip
				if Trip then TravelService.Arrive(P, Trip) end
			end)
		end
		return "loopback", Going
	end
	local Left = #Going
	for _, P in ipairs(Going) do
		task.spawn(function()
			local Ok, Err = pcall(DataManager.Release, DataManager, P)
			if not Ok then warn("[TravelService] release failed for " .. P.Name .. ": " .. tostring(Err)) end
			Left -= 1
		end)
	end
	local Deadline = os.clock() + TravelService.ReleaseWait
	while Left > 0 and os.clock() < Deadline do task.wait(0.1) end
	local Name = Places.Regions[Dest].Name
	-- TeleportData.Travel is informational only (logging); the destination reads the saved Trip
	FlowTeleport.SendGroup(Going, Places.Regions[Dest].PlaceId, {Travel = {Route = RouteId, Arrive = ArriveAt, From = Here, Nonce = Opts.Nonce}},
		function(P)
			P:Kick(("The journey to %s couldn't be completed. Your ticket is still valid; please rejoin."):format(Name))
		end, Join and {ServerInstanceId = Join} or nil)
	return "sent", Going
end

-- The join decision, from the save only. Info (TeleportData.Travel) is for logging. The profile must be loaded.
-- Returns "arrived" | "kept" | "refused" | "noprofile".
function TravelService._Join(Player, Info)
	local D = ProgressionService.GetData(Player)
	local T = D and TravelData(Player)
	if not T then return "noprofile" end
	local Here = TravelService.Here()
	local Trip = T.Trip
	if type(Trip) == "table" then
		if Trip.To == Here then
			TravelService.Arrive(Player, Trip)
			return "arrived"
		end
		T.Trip = nil -- a trip that never got here: forget it, the ticket stays unused
	end
	local Region = T.Region
	local Known = type(Region) == "string" and Places.Regions[Region] ~= nil
	if Region == Here or (not Known and Here == "Lindenmoor") then
		T.Region = Here
		return "kept"
	end
	local Claimed = type(Info) == "table" and tostring(Info.Route) or "none"
	if RunService:IsStudio() then
		warn(("[TravelService] %s's save is in %s, not %s (TeleportData route: %s); Studio keeps them here"):format(Player.Name, tostring(Region), Here, Claimed))
		return "refused"
	end
	warn(("[TravelService] %s's save is in %s, not %s (TeleportData route: %s); sending them there"):format(Player.Name, tostring(Region), Here, Claimed))
	local To = Places.ResumePlace(D)
	DataManager:Release(Player) -- saved now; the next place loads it (as FlowService does before a bounce)
	FlowTeleport.Send(Player, To, {From = Here}, function(P)
		P:Kick("Couldn't reach your last region. Please rejoin.")
	end)
	return "refused"
end

local function PlayerAdded(Player)
	local Join = Player:GetJoinData()
	local Data = Join and Join.TeleportData
	local InFlow = type(Data) == "table" and Data.Flow == Places.FlowTag
	local Profile = DataManager:WaitProfile(Player, TravelService.ProfileWait)
	if not Profile then return end
	-- the same gate as FlowService.PlayerAdded: a join it bounces to the menu is not ours to touch
	local D = Profile.Data
	local Ready = D.Identity and D.Identity.CharacterCreated and D.Flow and D.Flow.TutorialDone
	if not RunService:IsStudio() and (not InFlow or not Ready) then return end
	TravelService._Join(Player, type(Data) == "table" and Data.Travel or nil)
end

function TravelService.Start()
	Players.PlayerAdded:Connect(PlayerAdded)
	for _, P in ipairs(Players:GetPlayers()) do task.spawn(PlayerAdded, P) end
end

return TravelService

-- TravelService (World plan 1, 2026-10-20; world spec §2–3): getting a group from this region to another.
--   * Depart(List, RouteId, ArriveAt): the save is released (DataManager:Release) and the whole group goes in ONE
--     teleport (FlowTeleport.SendGroup) with TeleportData.Travel = {Route, Arrive, From}. A trip that still fails
--     kicks (the save was released); the ticket is only used on arrival, so nothing is lost.
--   * Arrival: a player who joins with TeleportData.Travel spawns at the RenseiArrival part whose Point matches,
--     uses one ticket for the route, and Data.Travel.Region becomes this region (a rejoin comes back here).
--   * Studio can't teleport: Depart runs Arrive in this place instead ("loopback"), at its own arrival point.
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

function TravelService.UseTicket(Player, RouteId)
	local C = TravelService.HasTicket(Player, RouteId)
	if not C then return nil end
	local T = TravelData(Player)
	local K = Travel.TicketKey(RouteId, C)
	T.Tickets[K] -= 1
	if T.Tickets[K] <= 0 then T.Tickets[K] = nil end
	return C
end

local function Spawn(Player, Point)
	local Character = Player.Character or Player.CharacterAdded:Wait()
	local Root = Character:WaitForChild("HumanoidRootPart", 10)
	local At = TravelService.ArrivalPoint(Point) or TravelService.ArrivalPoint("Platform")
	if Root and At then Character:PivotTo(At.CFrame + Vector3.new(0, 3, 0)) end
end

-- Info = {Route = RouteId, Arrive = Point, From = RegionId}
function TravelService.Arrive(Player, Info)
	local Here = TravelService.Here()
	local T = TravelData(Player)
	if T then T.Region = Here end
	if Info.Route and Travel.Routes[Info.Route] and Travel.Routes[Info.Route].Kind == "Rail" then
		TravelService.UseTicket(Player, Info.Route)
	end
	Spawn(Player, Info.Arrive or "Platform")
	local Name = Places.Regions[Here] and Places.Regions[Here].Name or Here
	UIService.Notify(Player, "Toast", {Text = "You arrive in " .. Name .. "."})
	TravelService.Arrived:Fire(Player, Here, Info.Route)
end

function TravelService.Depart(List, RouteId, ArriveAt)
	local Here = TravelService.Here()
	local Dest = Travel.Other(RouteId, Here)
	assert(Dest, "route " .. tostring(RouteId) .. " doesn't leave " .. Here)
	if RunService:IsStudio() then
		for _, P in ipairs(List) do task.spawn(TravelService.Arrive, P, {Route = RouteId, Arrive = ArriveAt, From = Here}) end
		return "loopback"
	end
	local Name = Places.Regions[Dest].Name
	for _, P in ipairs(List) do DataManager:Release(P) end
	FlowTeleport.SendGroup(List, Places.Regions[Dest].PlaceId, {Travel = {Route = RouteId, Arrive = ArriveAt, From = Here}},
		function(P)
			P:Kick(("The journey to %s couldn't be completed. Your ticket is still valid; please rejoin."):format(Name))
		end)
	return "sent"
end

local function PlayerAdded(Player)
	local Join = Player:GetJoinData()
	local Data = Join and Join.TeleportData
	local Info = type(Data) == "table" and type(Data.Travel) == "table" and Data.Travel
	if not Info then
		-- a plain join into this region still records where they are, so a rejoin comes back here
		if DataManager:WaitProfile(Player, 30) then
			local T = TravelData(Player)
			if T then T.Region = TravelService.Here() end
		end
		return
	end
	if not DataManager:WaitProfile(Player, 30) then return end
	TravelService.Arrive(Player, Info)
end

function TravelService.Start()
	Players.PlayerAdded:Connect(PlayerAdded)
	for _, P in ipairs(Players:GetPlayers()) do task.spawn(PlayerAdded, P) end
end

return TravelService

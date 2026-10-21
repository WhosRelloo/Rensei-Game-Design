-- RideEvents (World plan 1, 2026-10-20; world spec §2): one event per ride, picked by weight (Travel.RideEvents).
--   Inspection: the conductor checks tickets; anyone aboard without one (a stowaway) pays a fine (3x base) or is
--               thrown off at the next fade (sent back to this station's platform). Never below $0: the fine is
--               ProgressionService.SpendMoney, which takes all of it or nothing. (Only the ThrownOff attribute is set
--               here; the stowaway task makes StationService act on it. Today every rider has a ticket.)
--   Rumour:     a passenger mentions a real rumour about a rider (preferring one already heard in the destination),
--               else a lore line. Read-only on Data.Morality.Rumours.
--   Pickpocket: $5-15 lifted from one rider (never more than they carry). The chase (a PROPOSAL: a 6 s prompt to
--               catch the thief) is not built yet.
--   Holdup:     2 bandits (EnemyService.Spawn, type "Grunt") appear in the ride train's dining car aisle. They are
--               kept inside the train (a watchdog puts them back) and are gone when the ride ends, or when nobody
--               is left aboard.
--   Quiet:      nothing.
-- Every number is a PROPOSAL.
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Travel = require(ReplicatedStorage.Modules.Data.Rensei.Travel)
local ProgressionService = require(ServerScriptService.ProgressionService)
local UIService = require(ServerScriptService.UIService)

local RideEvents = {}
RideEvents.MaxDelay = 8 -- PROPOSAL: seconds into the ride the event happens, at most...
RideEvents.DelayShare = 0.3 -- PROPOSAL: ...or this share of a short ride
RideEvents.Pickpocket = {5, 15} -- PROPOSAL: dollars lifted
RideEvents.BanditCount = 2 -- world spec §2
RideEvents.BanditType = "Grunt" -- TuningConfig.Enemies.Grunt is the "Bandit"
RideEvents.BanditGap = 6 -- PROPOSAL: studs between the bandits, along the aisle
RideEvents.FallCatch = 20 -- PROPOSAL: a bandit this far below the ride train is put back (as StationService does for riders)
RideEvents.Force = nil -- Studio tests only: the next ride's event (used once; a live server ignores it)

local Bandits = {} -- [RouteId] = {{Rig = Model, Home = CFrame}}
local LORE = {
	"\"They say the Foundry smelters never go cold, not even at night.\"",
	"\"A State alchemist rode this line last week. Didn't say a word the whole way.\"",
	"\"Bandits have been hitting the roads north of Lindenmoor. Glad I took the train.\"",
}

local function Say(P, Text) UIService.Notify(P, "Toast", {Text = Text}) end

local function RideTrain(RouteId)
	for _, T in ipairs(CollectionService:GetTagged("RenseiRideTrain")) do
		if T:GetAttribute("Route") == RouteId and T:IsDescendantOf(workspace) then return T end
	end
	return nil
end

-- the dining car of a ride train (by its CarKind, read the way StationService reads it)
local function DiningCar(Ride)
	local StationService = require(ServerScriptService.StationService)
	for _, Car in ipairs(Ride:GetChildren()) do
		if Car:IsA("Model") and StationService.CarKind(Car) == "DiningCar" then return Car end
	end
	return nil
end

-- a deed line in the second person ("promised Tobin you'd keep quiet") reads wrong after "someone who": skipped.
-- Whole words, any case; "you" also catches "you'd" / "you're" / "you’d" (the apostrophe ends the word).
local function SecondPerson(Text)
	local L = Text:lower()
	for _, W in ipairs({"you", "your", "yours", "yourself"}) do
		if L:find("%f[%a]" .. W .. "%f[%A]") then return true end
	end
	return false
end
RideEvents.SecondPerson = SecondPerson

-- a rumour about one of the riders, preferring one that has already reached the destination
local function RumourLine(RouteId, List)
	local Deeds = require(ReplicatedStorage.Modules.Data.Rensei.Deeds)
	local Here = require(ServerScriptService.TravelService).Here()
	local Dest = Travel.Other(RouteId, Here)
	local There, Any = {}, {}
	for _, P in ipairs(List) do
		local D = ProgressionService.GetData(P)
		local Rumours = D and D.Morality and D.Morality.Rumours
		if type(Rumours) == "table" then
			for _, R in ipairs(Rumours) do
				local Def = type(R) == "table" and Deeds[R.Deed]
				if type(Def) == "table" and type(Def.Text) == "string" and not Def.Birth and not R.Suppressed
					and not SecondPerson(Def.Text) then
					table.insert(Any, Def.Text)
					if Dest and type(R.Reached) == "table" and R.Reached[Dest] then table.insert(There, Def.Text) end
				end
			end
		end
	end
	local Pool = #There > 0 and There or Any
	if #Pool == 0 then return nil end
	local Text = Pool[math.random(1, #Pool)]
	-- only the first letter lowered: the deed lines carry names ("Reported Lise ... to the Authority")
	return "A passenger whispers: \"Heard about someone who " .. Text:sub(1, 1):lower() .. Text:sub(2) .. ".\""
end

local function RemoveBandit(Rig)
	local EnemyService = require(ServerScriptService.EnemyService)
	local E = EnemyService.Active[Rig]
	EnemyService.Active[Rig] = nil -- not a kill: no Died, so no credit and no respawn
	if E and E.WCS then pcall(function() E.WCS:Destroy() end) end
	if Rig.Parent then Rig:Destroy() end -- CombatDirector and PerceptionService drop it on removal
end

-- keeps a route's bandits inside its ride train until they are cleared (the StationService watchdog covers players only)
local function Contain(RouteId, Ride, List)
	local StationService = require(ServerScriptService.StationService)
	local Floor = Ride:GetPivot().Position.Y - RideEvents.FallCatch
	while Bandits[RouteId] == List do
		for _, B in ipairs(List) do
			local Root = B.Rig.Parent and B.Rig:FindFirstChild("HumanoidRootPart")
			if Root and (Root.Position.Y < Floor or not StationService.CarAt(Ride, Root.Position)) then
				Root.AssemblyLinearVelocity = Vector3.zero
				B.Rig:PivotTo(B.Home)
			end
		end
		task.wait(0.5)
	end
end

function RideEvents.Run(EventId, RouteId, List, HasTicket)
	HasTicket = HasTicket or {}
	if EventId == "Inspection" then
		for _, P in ipairs(List) do
			if HasTicket[P] == false then
				local Fine = Travel.Fine(RouteId)
				if ProgressionService.SpendMoney(P, Fine) then
					Say(P, ("Conductor: \"No ticket? That's a $%d fine.\""):format(Fine))
				else
					P:SetAttribute("ThrownOff", true)
					Say(P, "Conductor: \"No ticket and no money. Off at the next stop.\"")
				end
			else
				Say(P, "The conductor clips your ticket.")
			end
		end
		return true
	elseif EventId == "Rumour" then
		local Line = RumourLine(RouteId, List) or ("A passenger says: " .. LORE[math.random(1, #LORE)])
		for _, Q in ipairs(List) do Say(Q, Line) end
		return Line
	elseif EventId == "Pickpocket" then
		if #List == 0 then return 0 end
		local P = List[math.random(1, #List)]
		local D = ProgressionService.GetData(P)
		local Amount = math.min(math.random(RideEvents.Pickpocket[1], RideEvents.Pickpocket[2]), D and math.floor(D.Money or 0) or 0)
		if Amount > 0 and ProgressionService.SpendMoney(P, Amount) then
			Say(P, ("Someone brushes past you... $%d is gone."):format(Amount))
			return Amount
		end
		return 0
	elseif EventId == "Holdup" then
		local EnemyService = require(ServerScriptService.EnemyService)
		local Ride = RideTrain(RouteId)
		local Car = Ride and DiningCar(Ride)
		local N = 0
		if Car then
			RideEvents.ClearHoldup(RouteId)
			local CF = Car:GetBoundingBox() -- X along the car, at the car's middle height
			local Ray = RaycastParams.new()
			Ray.FilterType = Enum.RaycastFilterType.Include
			Ray.FilterDescendantsInstances = {Car}
			local Mine = {}
			Bandits[RouteId] = Mine -- tracked from the first spawn, so a later failure can't orphan an earlier bandit
			for I = 1, RideEvents.BanditCount do
				local X = (I - (RideEvents.BanditCount + 1) / 2) * RideEvents.BanditGap
				local From = CF * CFrame.new(X, 0, 0) -- the aisle runs down the car's centre line
				local Hit = workspace:Raycast(From.Position, -CF.UpVector * 12, Ray)
				if Hit then
					-- an unparented spawn part: EnemyService only respawns from a part that still has a parent
					local Mark = Instance.new("Part")
					Mark.Anchored, Mark.CanCollide, Mark.Transparency = true, false, 1
					local Out = CF.RightVector * (X >= 0 and 1 or -1) -- back to back, each facing one end of the car
					Mark.CFrame = CFrame.lookAt(Hit.Position, Hit.Position + Out)
					Mark:SetAttribute("EnemyType", RideEvents.BanditType)
					local Ok, Rig = pcall(EnemyService.Spawn, Mark)
					if not Ok then
						warn("[RideEvents] bandit " .. I .. " failed to spawn on " .. RouteId .. ": " .. tostring(Rig))
					elseif typeof(Rig) == "Instance" then
						table.insert(Mine, {Rig = Rig, Home = Rig:GetPivot()})
						N += 1
					end
				end
			end
			if N > 0 then
				task.spawn(Contain, RouteId, Ride, Mine)
				for _, P in ipairs(List) do Say(P, "\"Nobody move! Hand over your valuables!\"") end
			elseif Bandits[RouteId] == Mine then
				Bandits[RouteId] = nil
			end
		end
		return N
	end
	return nil
end

-- the rigs of a route's holdup still standing (tests)
function RideEvents.BanditsOf(RouteId)
	local Out = {}
	for _, B in ipairs(Bandits[RouteId] or {}) do
		if B.Rig.Parent then table.insert(Out, B.Rig) end
	end
	return Out
end

-- RouteId nil: every route
function RideEvents.ClearHoldup(RouteId)
	for R, List in pairs(Bandits) do
		if RouteId == nil or R == RouteId then
			Bandits[R] = nil -- stops its Contain loop
			for _, B in ipairs(List) do RemoveBandit(B.Rig) end
		end
	end
end

function RideEvents.Start()
	local StationService = require(ServerScriptService.StationService)
	local TravelService = require(ServerScriptService.TravelService)
	local function StillAboard(RouteId, List)
		local Out = {}
		for _, P in ipairs(List) do
			if P.Parent and StationService.Riding(P) == RouteId then table.insert(Out, P) end
		end
		return Out
	end
	-- Stow (from the stowaway task, when it lands): [Player] = true for riders who boarded without a ticket
	StationService.Departing.Event:Connect(function(RouteId, List, Seconds, Stow)
		local Ends = os.clock() + Seconds
		local Has = {}
		for _, P in ipairs(List) do
			if type(Stow) == "table" then Has[P] = not Stow[P] else Has[P] = TravelService.HasTicket(P, RouteId) ~= nil end
		end
		task.wait(math.min(RideEvents.MaxDelay, Seconds * RideEvents.DelayShare))
		List = StillAboard(RouteId, List)
		if #List == 0 then return end
		local Id = Travel.PickRideEvent(math.random())
		if RideEvents.Force and RunService:IsStudio() then Id = RideEvents.Force end
		RideEvents.Force = nil
		local Ok, Err = pcall(RideEvents.Run, Id, RouteId, List, Has)
		if not Ok then warn("[RideEvents] " .. tostring(Id) .. " on " .. RouteId .. " failed: " .. tostring(Err)) end
		if Id == "Holdup" then
			-- the bandits go at arrival (StationService clears Riding when the ride ends) or once nobody is aboard
			while os.clock() < Ends and #StillAboard(RouteId, List) > 0 and #RideEvents.BanditsOf(RouteId) > 0 do task.wait(0.5) end
			RideEvents.ClearHoldup(RouteId)
		end
	end)
end

return RideEvents

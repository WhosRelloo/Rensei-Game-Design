-- RoadService (World plan 1, 2026-10-20; world spec §3): road exits and road journeys, with ambushes.
--   * A road exit is a RenseiRoadExit part (attributes Route, Arrive) under a gate arch. Its ProximityPrompt (a
--     deliberate hold, never a Touched teleport, so arriving at a gate can't chain into leaving) opens the travel
--     card on the client: the destination, the trip time, the ambush risk and who's coming. "Set off" asks the
--     server (Remotes.Travel "Road" -> StationService -> RoadService.Request), which checks it all again: a road
--     that leaves this place, the asker standing at that road's exit, the party leader, the level, nobody already
--     travelling, and a per-player gap between requests. The client only asks.
--   * Journey(Leader, RouteId, ForceAmbush?): the leader and the party members near them go together: free, no
--     papers. The server rolls the ambush (Travel.AmbushChance: night, winter, the party's highest State Wanted).
--     No ambush: TravelService.Depart (the clients show the journey screen). Ambush: the party is moved into this
--     place's ambush arena (RenseiAmbushArena) with 2-3 enemies (Elite if anyone is Wanted).
--   * The arena (controller ruling 2026-10-21, over the spec's "or flee by leaving the arena's edge"): nobody leaves
--     until every enemy is down. A watchdog puts anyone who gets out back on their spot (the enemies too). When
--     the enemies are beaten, the journey continues for whoever is still standing in the arena.
--       - Death in the arena: the player respawns in town as usual and is off the journey (no travel, no pull-back).
--       - Leaving the server, or another teleport taking them: off the journey.
--       - Nobody left in the arena: the enemies are removed (not killed: no reward) and the ambush ends.
--       - One ambush per arena at a time: while it is in use, a roll that hits is skipped.
-- Every number is a PROPOSAL.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local Travel = require(ReplicatedStorage.Modules.Data.Rensei.Travel)
local Places = require(ReplicatedStorage.Modules.Data.Rensei.Places)
local TravelService = require(ServerScriptService.TravelService)
local PartyService = require(ServerScriptService.PartyService)
local ProgressionService = require(ServerScriptService.ProgressionService)
local UIService = require(ServerScriptService.UIService)
local FlowTeleport = require(ServerScriptService.FlowTeleport)

local RoadService = {}
RoadService.ArenaCleared = Instance.new("BindableEvent") -- (RouteId, {Player}): the ambush was beaten; they travel on
RoadService.Season = function() return "Summer" end -- the seasons plan replaces this
RoadService.PromptReach = 12 -- PROPOSAL (brief): the exit's prompt shows within this many studs
RoadService.ExitReach = 16 -- PROPOSAL: a "Set off" is only accepted this close to the road's exit
RoadService.GatherRadius = 60 -- PROPOSAL: party members this close to the leader come along; the rest stay
RoadService.AskGap = 3 -- PROPOSAL: seconds between one player's accepted road requests
RoadService.ClearDelay = 2 -- PROPOSAL (brief): seconds after the last enemy dies before the journey continues
RoadService.KnockedGrace = 8 -- PROPOSAL: with every enemy down but some only knocked, seconds to finish them first
RoadService.Margin = 4 -- PROPOSAL: studs past the arena's edge before the watchdog puts someone back
RoadService.Tick = 0.25 -- PROPOSAL: seconds between watchdog checks
RoadService.Gap = 12 -- PROPOSAL: the party stands this far from the arena's centre, the enemies as far on the other side
RoadService.Force = nil -- Studio tests only: true / false forces the next Request's ambush roll (a live server ignores it)

local DIED = "You came to back in town. The road will have to wait."

local Event -- Remotes.TravelEvent (made by StationService)
local Ambushes = {} -- [Player] = the ambush they're in
local InUse = {} -- [arena part] = its ambush
local OnRoad = {} -- [Player] = true while their Depart runs
local LastAsk = {}

local function Notify(P, Text) UIService.Notify(P, "Toast", {Text = Text}) end
local function Send(P, Kind, Data) if Event and P.Parent then Event:FireClient(P, Kind, Data) end end
local function RegionName(Id) return Places.Regions[Id] and Places.Regions[Id].Name or tostring(Id) end

local function Level(P)
	local D = ProgressionService.GetData(P)
	return D and D.Level or 1
end

local function Wanted(P)
	local Ok, W = pcall(function() return require(ServerScriptService.HeatService).Wanted(P, "State") end)
	return Ok and tonumber(W) or 0
end

-- the root of P's living character, or nil
local function Root(P)
	local C = P.Character
	local H = C and C:FindFirstChildOfClass("Humanoid")
	local R = C and C:FindFirstChild("HumanoidRootPart")
	return H and R and H.Health > 0 and R or nil
end

local function ExitFor(RouteId)
	for _, E in ipairs(CollectionService:GetTagged("RenseiRoadExit")) do
		if E:IsA("BasePart") and E:GetAttribute("Route") == RouteId and E:IsDescendantOf(workspace) then return E end
	end
	return nil
end

local function ArenaPart()
	for _, A in ipairs(CollectionService:GetTagged("RenseiAmbushArena")) do
		if A:IsA("BasePart") and A:IsDescendantOf(workspace) then return A end
	end
	return nil
end

-- free to travel: not already on the road, in an ambush, on a train, or in a teleport
local function Free(P)
	if Ambushes[P] or OnRoad[P] or FlowTeleport.Busy(P) or FlowTeleport.InGroup(P) then return false end
	local Ok, Riding = pcall(function() return require(ServerScriptService.StationService).Riding(P) end)
	return not (Ok and Riding)
end

-- who goes: the leader, plus each party member near the leader who is free and may take the road
local function Gather(Leader, RouteId)
	local Party = PartyService.Get(Leader)
	local Out, Left = {Leader}, {}
	local LR = Root(Leader)
	for _, M in ipairs(Party and Party.Members or {}) do
		if M ~= Leader and M.Parent then
			local R = Root(M)
			if LR and R and (R.Position - LR.Position).Magnitude <= RoadService.GatherRadius and Free(M)
				and Travel.CanTake(Level(M), RouteId) then
				table.insert(Out, M)
			else
				table.insert(Left, M)
			end
		end
	end
	return Out, Left
end

-- off an anchored seat first: moving a seated character drags the seat along on its SeatWeld
local function Unseat(P)
	local H = P.Character and P.Character:FindFirstChildOfClass("Humanoid")
	local Seat = H and H.SeatPart
	if not Seat then return end
	H.Sit = false
	local W = Seat:FindFirstChild("SeatWeld")
	if W then W:Destroy() end
end

function RoadService.Chance(MaxWanted)
	local Night = Lighting.ClockTime < 6 or Lighting.ClockTime > 19
	return Travel.AmbushChance(Night, RoadService.Season() == "Winter", MaxWanted or 0)
end

function RoadService.InAmbush(P) return Ambushes[P] ~= nil end

-- the journey itself: the journey screen, then the teleport (Studio: the loopback). Returns Depart's mode.
local function Go(List, RouteId, Arrive)
	local Here = TravelService.Here()
	local DestName = RegionName(Travel.Other(RouteId, Here))
	for _, P in ipairs(List) do
		OnRoad[P] = true
		Unseat(P)
		Send(P, "RoadStart", {Route = RouteId, From = RegionName(Here), Dest = DestName, Seconds = Travel.Routes[RouteId].Seconds})
	end
	local Ok, Mode, Went = pcall(TravelService.Depart, List, RouteId, Arrive)
	for _, P in ipairs(List) do OnRoad[P] = nil end
	local Sent = {}
	if Ok then
		for _, P in ipairs(Went or {}) do Sent[P] = true end
	else
		warn("[RoadService] Depart failed on " .. RouteId .. ": " .. tostring(Mode))
		if not RunService:IsStudio() then -- live: their saves may already be released, so they can't stay here
			for _, P in ipairs(List) do
				if P.Parent then P:Kick(("The road to %s couldn't be travelled. Please rejoin."):format(DestName)) end
			end
			return "failed"
		end
	end
	for _, P in ipairs(List) do -- dropped by Depart (already teleporting, no save loaded): they stay here
		if not Sent[P] then Send(P, "RoadCancel", {Text = "You couldn't set off this time."}) end
	end
	return Ok and Mode or "failed"
end

-- ===== The ambush arena =====
local function RemoveEnemy(Rig)
	local EnemyService = require(ServerScriptService.EnemyService)
	local E = EnemyService.Active[Rig]
	EnemyService.Active[Rig] = nil -- not a kill: no Died, so no reward and no respawn
	if E and E.WCS then pcall(function() E.WCS:Destroy() end) end
	if Rig.Parent then Rig:Destroy() end -- CombatDirector and PerceptionService drop it on removal
end

-- A.Done ends it. Won: the journey continues for the party members still standing in the arena.
local function Finish(A, Won)
	if A.Done then return end
	A.Done = true
	if InUse[A.Arena] == A then InUse[A.Arena] = nil end
	for _, C in ipairs(A.Conns) do C:Disconnect() end
	for _, M in ipairs(A.Party) do
		if Ambushes[M] == A then Ambushes[M] = nil end
	end
	for _, E in ipairs(A.Enemies) do RemoveEnemy(E.Rig) end
	if not Won then return end
	local Still = {}
	for _, M in ipairs(A.Party) do
		if M.Parent and Root(M) and M.Character == A.Body[M] then table.insert(Still, M) end
	end
	RoadService.ArenaCleared:Fire(A.Route, Still)
	if #Still > 0 then task.spawn(Go, Still, A.Route, A.Arrive) end
end

local function Drop(A, P, Text)
	local I = table.find(A.Party, P)
	if not I then return end
	table.remove(A.Party, I)
	A.Body[P], A.Spot[P] = nil, nil
	if Ambushes[P] == A then Ambushes[P] = nil end
	if Text then Send(P, "RoadCancel", {Text = Text}) end
	if #A.Party == 0 then Finish(A, false) end -- nobody left to fight: the enemies go, nobody travels
end

-- enemies still fighting, and enemies knocked (down, not yet finished)
local function Count(A)
	local Up, Knocked = 0, 0
	for _, E in ipairs(A.Enemies) do
		local H = E.Rig.Parent and E.Rig:FindFirstChildOfClass("Humanoid")
		if H and H.Health > 0 then
			if E.Rig:GetAttribute("Knocked") then Knocked += 1 else Up += 1 end
		end
	end
	return Up, Knocked
end

local function InArena(Arena, Pos)
	local L = Arena.CFrame:PointToObjectSpace(Pos)
	local M = RoadService.Margin
	return math.abs(L.X) <= Arena.Size.X / 2 + M and math.abs(L.Z) <= Arena.Size.Z / 2 + M and L.Y > -12 and L.Y < 40
end

local function Watch(A)
	local Told = {}
	while not A.Done do
		task.wait(RoadService.Tick)
		if A.Done then break end
		for _, P in ipairs(table.clone(A.Party)) do
			if not P.Parent or FlowTeleport.Busy(P) or FlowTeleport.InGroup(P) then
				Drop(A, P)
			else
				local C = A.Body[P]
				local R = C and P.Character == C and C:FindFirstChild("HumanoidRootPart")
				if R and not InArena(A.Arena, R.Position) then -- walked, fell or was knocked out: back to their spot
					Unseat(P)
					R.AssemblyLinearVelocity = Vector3.zero
					C:PivotTo(A.Spot[P])
					if not Told[P] or os.clock() - Told[P] > 3 then
						Told[P] = os.clock()
						Notify(P, "The bandits have the road blocked. Fight your way through!")
					end
				end
			end
		end
		if A.Done then break end
		for _, E in ipairs(A.Enemies) do
			local R = E.Rig.Parent and E.Rig:FindFirstChild("HumanoidRootPart")
			if R and not InArena(A.Arena, R.Position) then
				R.AssemblyLinearVelocity = Vector3.zero
				E.Rig:PivotTo(E.Home)
			end
		end
		local Up, Knocked = Count(A)
		if Up == 0 then
			A.DownSince = A.DownSince or os.clock()
			-- all dead: on after ClearDelay; some only knocked: a few seconds to finish them (grip) first
			local Wait = Knocked == 0 and RoadService.ClearDelay or RoadService.KnockedGrace
			if os.clock() - A.DownSince >= Wait then Finish(A, true) end
		else
			A.DownSince = nil
		end
	end
end

-- Returns the ambush, or nil if it couldn't be set up (no one to move, or no enemy spawned): the caller goes on.
local function Ambush(Party, RouteId, Arrive, Arena, MaxWanted)
	local Ready = {}
	for _, M in ipairs(Party) do
		if M.Parent and Root(M) then table.insert(Ready, M) end
	end
	if #Ready == 0 then return nil end
	local A = {Route = RouteId, Arrive = Arrive, Arena = Arena, Party = {}, Enemies = {}, Body = {}, Spot = {}, Conns = {}}
	InUse[Arena] = A
	local EnemyService = require(ServerScriptService.EnemyService)
	local Kind = MaxWanted >= 1 and "Elite" or "Grunt" -- Elite = "Bandit Duelist"
	local N = 2 + (#Ready > 2 and 1 or 0) -- world spec: 2-3
	local Facing = -Arena.CFrame.LookVector -- the enemies (on the arena's -Z side) face the party (+Z side)
	for I = 1, N do
		-- an unparented spawn part: EnemyService only respawns from a part that still has a parent
		local Mark = Instance.new("Part")
		Mark.Anchored, Mark.CanCollide, Mark.Transparency = true, false, 1
		local Pos = (Arena.CFrame * CFrame.new((I - (N + 1) / 2) * 8, -Arena.Size.Y / 2, -RoadService.Gap)).Position
		Mark.CFrame = CFrame.lookAt(Pos, Pos + Facing)
		Mark:SetAttribute("EnemyType", Kind)
		local Ok, Rig = pcall(EnemyService.Spawn, Mark)
		if Ok and typeof(Rig) == "Instance" then
			table.insert(A.Enemies, {Rig = Rig, Home = Rig:GetPivot()})
		else
			warn("[RoadService] ambush enemy " .. I .. " failed to spawn: " .. tostring(Rig))
		end
	end
	if #A.Enemies == 0 then
		InUse[Arena] = nil
		return nil
	end
	for I, M in ipairs(Ready) do
		local C = M.Character
		Ambushes[M] = A
		table.insert(A.Party, M)
		A.Body[M] = C
		A.Spot[M] = Arena.CFrame * CFrame.new((I - (#Ready + 1) / 2) * 4, Arena.Size.Y / 2 + 3, RoadService.Gap)
		Unseat(M)
		task.spawn(function() pcall(M.RequestStreamAroundAsync, M, A.Spot[M].Position, 2) end)
		C:PivotTo(A.Spot[M])
		local H = C:FindFirstChildOfClass("Humanoid")
		if H then table.insert(A.Conns, H.Died:Connect(function() Drop(A, M, DIED) end)) end
		table.insert(A.Conns, M.CharacterAdded:Connect(function() Drop(A, M, DIED) end))
		Send(M, "RoadAmbush", {Route = RouteId, Text = "Ambush on the road! Fight your way through."})
		Notify(M, "Ambush on the road!")
	end
	task.spawn(Watch, A)
	return A
end

-- test hook: count P's fight as won (the journey continues)
function RoadService.ClearArena(P)
	local A = Ambushes[P]
	if A then Finish(A, true) end
end

-- test hook: the enemies of P's ambush still in the world
function RoadService.EnemiesOf(P)
	local Out = {}
	for _, E in ipairs(Ambushes[P] and Ambushes[P].Enemies or {}) do
		if E.Rig.Parent then table.insert(Out, E.Rig) end
	end
	return Out
end

-- Returns "ambush" | "sent" | "loopback" (or "failed": Depart threw). The caller has done the checks.
function RoadService.Journey(Leader, RouteId, ForceAmbush)
	local R = Travel.Routes[RouteId]
	assert(R and R.Kind == "Road", "not a road")
	assert(Travel.Other(RouteId, TravelService.Here()), "that road doesn't leave " .. TravelService.Here())
	local Party, Left = Gather(Leader, RouteId)
	for _, M in ipairs(Left) do Notify(M, "Your party set off on the road without you.") end
	local Exit = ExitFor(RouteId)
	local Arrive = Exit and Exit:GetAttribute("Arrive") or "Platform"
	local MaxWanted = 0
	for _, M in ipairs(Party) do MaxWanted = math.max(MaxWanted, Wanted(M)) end
	local Hit = ForceAmbush
	if Hit == nil then Hit = math.random() < RoadService.Chance(MaxWanted) end
	local Arena = Hit and ArenaPart()
	if Arena and not InUse[Arena] and Ambush(Party, RouteId, Arrive, Arena, MaxWanted) then return "ambush" end
	return (Go(Party, RouteId, Arrive))
end

-- everything a "Set off" (or the prompt) must pass, checked on the server
local function Check(P, RouteId)
	local R = type(RouteId) == "string" and Travel.Routes[RouteId]
	if not R or R.Kind ~= "Road" or not Travel.Other(RouteId, TravelService.Here()) then return false, "No such road from here." end
	local Exit, Me = ExitFor(RouteId), Root(P)
	if not Exit or not Me or (Me.Position - Exit.Position).Magnitude > RoadService.ExitReach then
		return false, "Walk up to the road gate to set off."
	end
	if not Free(P) then return false, "You're already on your way." end
	local Party = PartyService.Get(P)
	if Party and Party.Leader ~= P then return false, "Your party leader decides when to set off." end
	local Ok, Why = Travel.CanTake(Level(P), RouteId)
	if not Ok then return false, Why end
	return true
end

-- Remotes.Travel "Road" (through StationService): the client's "Set off". Returns ok, why.
function RoadService.Request(P, RouteId)
	local Now = os.clock()
	if LastAsk[P] and Now - LastAsk[P] < RoadService.AskGap then return false, "One moment." end
	local Ok, Why = Check(P, RouteId)
	if not Ok then return false, Why end
	LastAsk[P] = Now
	local Force = nil -- nil: the server rolls
	if RunService:IsStudio() then Force = RoadService.Force end
	RoadService.Force = nil
	task.spawn(function()
		local Ok2, Err = pcall(RoadService.Journey, P, RouteId, Force)
		if not Ok2 then
			warn("[RoadService] journey failed: " .. tostring(Err))
			Send(P, "RoadCancel", {Text = "You couldn't set off this time."})
		end
	end)
	return true
end

local function Card(P, Exit)
	local RouteId = Exit:GetAttribute("Route")
	local Party = Gather(P, RouteId)
	local Names, MaxWanted = {}, 0
	for _, M in ipairs(Party) do
		table.insert(Names, M.DisplayName)
		MaxWanted = math.max(MaxWanted, Wanted(M))
	end
	Send(P, "RoadCard", {
		Route = RouteId,
		Dest = RegionName(Travel.Other(RouteId, TravelService.Here())),
		Seconds = Travel.Routes[RouteId].Seconds,
		Risk = math.floor(RoadService.Chance(MaxWanted) * 100 + 0.5),
		Party = Names,
	})
end

local function AddPrompt(Exit)
	if not Exit:IsA("BasePart") or Exit:FindFirstChild("RoadPrompt") then return end
	local RouteId = Exit:GetAttribute("Route")
	local R = Travel.Routes[RouteId]
	local Dest = R and R.Kind == "Road" and Travel.Other(RouteId, TravelService.Here())
	if not Dest then return end -- not a road from this place
	local Prompt = Instance.new("ProximityPrompt")
	Prompt.Name = "RoadPrompt"
	Prompt.ActionText, Prompt.ObjectText = "Travel the road", "To " .. RegionName(Dest)
	Prompt.HoldDuration, Prompt.MaxActivationDistance = 1, RoadService.PromptReach
	Prompt.RequiresLineOfSight = false -- the exit part is invisible and not queryable
	Prompt.Parent = Exit
	Prompt.Triggered:Connect(function(P)
		local Ok, Why = Check(P, RouteId)
		if not Ok then Notify(P, Why) return end
		Card(P, Exit)
	end)
end

function RoadService.Start()
	Event = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TravelEvent", 30)
	for _, Exit in ipairs(CollectionService:GetTagged("RenseiRoadExit")) do AddPrompt(Exit) end
	CollectionService:GetInstanceAddedSignal("RenseiRoadExit"):Connect(AddPrompt)
	-- the journey screen closes on arrival (the Studio loopback; live, the teleport has already replaced it)
	TravelService.Arrived.Event:Connect(function(P, Region, RouteId)
		local R = RouteId and Travel.Routes[RouteId]
		if R and R.Kind == "Road" then Send(P, "RoadEnd", {Route = RouteId, Dest = RegionName(Region)}) end
	end)
	Players.PlayerRemoving:Connect(function(P)
		local A = Ambushes[P]
		if A then Drop(A, P) end
		Ambushes[P], OnRoad[P], LastAsk[P] = nil, nil, nil
	end)
end

return RoadService

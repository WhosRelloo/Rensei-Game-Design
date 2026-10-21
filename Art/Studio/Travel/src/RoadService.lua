-- RoadService (World plan 1, 2026-10-20; world spec §3): road exits and road journeys, with ambushes.
--   * A road exit is a RenseiRoadExit part (attributes Route, Arrive) under a gate arch. Its ProximityPrompt (a
--     deliberate hold, never a Touched teleport, so arriving at a gate can't chain into leaving) opens the travel
--     card on the client: the destination, the trip time, the ambush risk and who's coming. "Set off" asks the
--     server (Remotes.Travel "Road" -> StationService -> RoadService.Request), which checks it all again: a road
--     that leaves this place, the asker standing at that road's exit, the party leader, the level, nobody already
--     travelling, nobody down, held or mid-fight, the ambush arena free, and a per-player gap between requests.
--     The client only asks.
--   * Journey(Leader, RouteId, ForceAmbush?): the leader and the party members near the leader who are fit to go
--     travel together: free, no papers (the others are told why they stayed). The trip takes the route's Seconds:
--     the party is held out of harm (anchored, out of sight high above the exit) while the clients show the journey
--     screen with a real countdown, then TravelService.Depart sends them. The server rolls the ambush at the start
--     (Travel.AmbushChance: night, winter, the party's highest State Wanted) and reserves the arena; partway along
--     (AmbushAt) "the trip stops": the party is put in this place's ambush arena (RenseiAmbushArena) with 2-3
--     enemies (Elite if anyone is Wanted).
--   * The arena (world spec §3: "When you win, or flee by leaving the arena's edge, the journey continues"):
--       - Win: every enemy down -> the journey continues for whoever is still standing in the arena, for the time
--         that was left (ArenaCleared fires).
--       - Flee: walking out past the edge (a plausible step from inside, then staying out for FleeHold s) -> that
--         member's journey continues for the time left. A far jump (a teleport) or being held is put back instead.
--       - Death in the arena: the player respawns in town as usual and is off the journey (no travel, no pull-back).
--       - Leaving the server, or another teleport taking them: off the journey.
--       - Nobody left in the arena: the enemies are removed (not killed: no reward).
--       - One ambush per arena at a time: while it is reserved or in use, new road requests are refused.
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
RoadService.AmbushAt = 0.4 -- PROPOSAL: share of the trip after which an ambush stops it
RoadService.HoldHeight = 1500 -- PROPOSAL: studs above the exit the party is held (anchored) during the trip
RoadService.HoldGap = 8 -- PROPOSAL: studs between held party members
RoadService.ClearDelay = 2 -- PROPOSAL (brief): seconds after the last enemy dies before the journey continues
RoadService.KnockedGrace = 8 -- PROPOSAL: with every enemy down but some only knocked, seconds to finish them first
RoadService.Margin = 4 -- PROPOSAL: studs past the arena's edge that still count as inside
RoadService.FleeBand = 20 -- PROPOSAL: a first step out must land within this many studs past Margin to start a flee
RoadService.FleeHold = 0.75 -- PROPOSAL: seconds outside before it counts as fleeing (a knockback that comes back isn't)
RoadService.MaxStep = 16 -- PROPOSAL: studs per watchdog tick a walk / sprint / dash can cover; more is a teleport
RoadService.Tick = 0.25 -- PROPOSAL: seconds between watchdog checks
RoadService.Gap = 12 -- PROPOSAL: the party stands this far from the arena's centre, the enemies as far on the other side
RoadService.TimeScale = 1 -- Studio tests only: road time x this (e.g. 0.02); a live server always uses 1
RoadService.Force = nil -- Studio tests only: true / false forces the next Request's ambush roll (a live server ignores it)

local DIED = "You came to back in town. The road will have to wait."
local BLOCKED = "The road ahead is blocked. Try again shortly." -- PROPOSAL wording
local AMBUSH = "Ambush on the road! Win the fight, or flee past the edge of the clearing."
-- the downed / grip / carry attributes DownedManager sets on a character: nobody escapes those by road
local HELD = {"Knocked", "GrippedBy", "CarriedBy", "Gripping", "Carrying"}

local Event -- Remotes.TravelEvent (made by StationService)
local Ambushes = {} -- [Player] = the ambush they're in
local InUse = {} -- [arena part] = true (reserved by a trip that rolled an ambush) or the ambush in it
local OnRoad = {} -- [Player] = true from the start of a journey until it ends (departed, ambushed or dropped)
local LastAsk = {}

local function Notify(P, Text) if P.Parent then UIService.Notify(P, "Toast", {Text = Text}) end end
local function Send(P, Kind, Data) if Event and P.Parent then Event:FireClient(P, Kind, Data) end end
local function RegionName(Id) return Places.Regions[Id] and Places.Regions[Id].Name or tostring(Id) end
local function Scale() return RunService:IsStudio() and math.clamp(tonumber(RoadService.TimeScale) or 1, 0.001, 1) or 1 end

local function Level(P)
	local D = ProgressionService.GetData(P)
	return D and D.Level or 1
end

local function Wanted(P)
	local Ok, W = pcall(function() return require(ServerScriptService.HeatService).Wanted(P, "State") end)
	return Ok and tonumber(W) or 0
end

local function Held(C)
	for _, Name in ipairs(HELD) do
		local V = C:GetAttribute(Name)
		if V ~= nil and V ~= false then return true end
	end
	return false
end

-- the root of P's living character that isn't down, gripped or carried (or gripping / carrying someone), or nil
local function Root(P)
	local C = P.Character
	local H = C and C:FindFirstChildOfClass("Humanoid")
	local R = C and C:FindFirstChild("HumanoidRootPart")
	return H and R and H.Health > 0 and not Held(C) and R or nil
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

-- why P can't set off on RouteId right now, or nil
local function Unfit(P, RouteId)
	local C = P.Character
	local H = C and C:FindFirstChildOfClass("Humanoid")
	if not (H and H.Health > 0 and C:FindFirstChild("HumanoidRootPart")) then return "You can't travel right now." end
	if Held(C) then return "You can't set off while you're down, held or holding someone." end
	if C:GetAttribute("InCombat") then return "You can't set off in the middle of a fight." end -- WorldService's combat lock
	if Ambushes[P] or OnRoad[P] or FlowTeleport.Busy(P) or FlowTeleport.InGroup(P) then return "You're already on your way." end
	local Ok, Riding = pcall(function() return require(ServerScriptService.StationService).Riding(P) end)
	if Ok and Riding then return "You're already on your way." end
	local Can, Why = Travel.CanTake(Level(P), RouteId)
	if not Can then return Why end
	return nil
end

-- who goes: the leader, plus each party member near the leader who is fit to go. Left = {{Player, why}}.
local function Gather(Leader, RouteId)
	local Party = PartyService.Get(Leader)
	local Out, Left = {Leader}, {}
	local LR = Root(Leader)
	for _, M in ipairs(Party and Party.Members or {}) do
		if M ~= Leader and M.Parent then
			local R = M.Character and M.Character:FindFirstChild("HumanoidRootPart")
			local Why = Unfit(M, RouteId)
			if not Why and not (LR and R and (R.Position - LR.Position).Magnitude <= RoadService.GatherRadius) then
				Why = "You were too far away."
			end
			if Why then table.insert(Left, {M, Why}) else table.insert(Out, M) end
		end
	end
	return Out, Left
end

-- off an anchored seat first: moving a seated character drags the seat along on its SeatWeld
local function Unseat(P)
	local H = P.Character and P.Character:FindFirstChildOfClass("Humanoid")
	local Seat = H and H.SeatPart
	if not Seat then return false end
	H.Sit = false
	local W = Seat:FindFirstChild("SeatWeld")
	if W then W:Destroy() end
	return true
end

local function Release(C)
	local R = C and C:FindFirstChild("HumanoidRootPart")
	if R then R.Anchored = false end
end

-- back at the exit, on the town side (a trip that couldn't go)
local function PutBack(P, Exit)
	local C = P.Character
	if C and Exit then C:PivotTo(Exit.CFrame * CFrame.new(0, -1, 8)) end
end

function RoadService.Chance(MaxWanted)
	local Night = Lighting.ClockTime < 6 or Lighting.ClockTime > 19
	return Travel.AmbushChance(Night, RoadService.Season() == "Winter", MaxWanted or 0)
end

function RoadService.InAmbush(P) return Ambushes[P] ~= nil end
function RoadService.OnRoad(P) return OnRoad[P] == true end

local Ambush -- defined below (the trip and the ambush call each other)

-- The road: Left seconds held out of harm, then the teleport. With AmbushIn (the arena is reserved), the trip stops
-- after AmbushIn seconds and the party is put in the arena. Returns "sent" | "loopback" | "ambush" | "none" | "failed".
local function Trip(List, RouteId, Arrive, Left, AmbushIn, Arena, MaxWanted)
	local Here = TravelService.Here()
	local Dest = RegionName(Travel.Other(RouteId, Here))
	local Seconds = Travel.Routes[RouteId].Seconds
	local K = Scale()
	local Exit = ExitFor(RouteId)
	local Base = (Exit and Exit.Position or Vector3.zero) + Vector3.new(0, RoadService.HoldHeight, 0)
	local Members, Body, Conns = {}, {}, {}
	local function Off(P, Text) -- dropped from the road: they stay here; the road is free, so nothing is lost
		local I = table.find(Members, P)
		if not I then return end
		table.remove(Members, I)
		Release(Body[P])
		Body[P] = nil
		OnRoad[P] = nil
		if Text then Send(P, "RoadCancel", {Route = RouteId}) Notify(P, Text) end
	end
	local Seated = false
	for _, P in ipairs(List) do
		if P.Parent and P.Character then Seated = Unseat(P) or Seated end
	end
	if Seated then task.wait(0.3) end -- PROPOSAL: the client owns the character; let the stand-up land first
	local Now = workspace:GetServerTimeNow()
	for I, P in ipairs(List) do
		local C = P.Character
		local R = C and C:FindFirstChild("HumanoidRootPart")
		local H = C and C:FindFirstChildOfClass("Humanoid")
		if P.Parent and R and H and H.Health > 0 then
			table.insert(Members, P)
			Body[P] = C
			OnRoad[P] = true
			-- held high above the exit, anchored: out of sight and out of reach of every fight for the whole trip
			C:PivotTo(CFrame.new(Base + Vector3.new((I - 1) * RoadService.HoldGap, 0, 0)))
			R.AssemblyLinearVelocity = Vector3.zero
			R.Anchored = true
			table.insert(Conns, H.Died:Connect(function() Off(P, DIED) end))
			table.insert(Conns, P.CharacterAdded:Connect(function() Off(P, DIED) end))
			Send(P, "RoadStart", {Route = RouteId, From = RegionName(Here), Dest = Dest, Seconds = Seconds,
				Total = Seconds * K, Ends = Now + Left * K})
		else
			OnRoad[P] = nil
		end
	end
	local Stop = (AmbushIn or Left) * K
	local T0 = os.clock()
	while #Members > 0 and os.clock() - T0 < Stop do
		task.wait(math.clamp(Stop - (os.clock() - T0), 0, RoadService.Tick))
		for _, P in ipairs(table.clone(Members)) do
			if not P.Parent then
				Off(P)
			elseif FlowTeleport.Busy(P) or FlowTeleport.InGroup(P) then
				Off(P, "You were called away from the road.")
			end
		end
	end
	for _, C in ipairs(Conns) do C:Disconnect() end
	if #Members == 0 then
		if Arena and InUse[Arena] == true then InUse[Arena] = nil end
		return "none"
	end
	if AmbushIn then -- the trip stops: the ambush
		for _, P in ipairs(Members) do
			Release(Body[P])
			OnRoad[P] = nil
		end
		if InUse[Arena] == true then InUse[Arena] = nil end -- the reservation; Ambush takes the arena
		if Ambush(Members, RouteId, Arrive, Arena, MaxWanted, Left - AmbushIn) then return "ambush" end
		return Trip(Members, RouteId, Arrive, Left - AmbushIn) -- couldn't set it up: the rest of the road
	end
	local Ok, Mode, Went = pcall(TravelService.Depart, Members, RouteId, Arrive)
	if not Ok then warn("[RoadService] Depart failed on " .. RouteId .. ": " .. tostring(Mode)) end
	local Sent = {}
	for _, P in ipairs(Ok and Went or {}) do Sent[P] = true end
	for _, P in ipairs(Members) do
		OnRoad[P] = nil
		-- live, the sent stay held until the teleport takes them; Studio's loopback has already moved them
		if RunService:IsStudio() or not Sent[P] then Release(Body[P]) end
		if not Sent[P] and P.Parent then
			if not Ok and not RunService:IsStudio() then -- live: their saves may already be released
				P:Kick(("The road to %s couldn't be travelled. Please rejoin."):format(Dest))
			else -- dropped by Depart (already teleporting, no save loaded): back at the exit
				PutBack(P, Exit)
				Send(P, "RoadCancel", {Route = RouteId})
				Notify(P, "You couldn't set off this time.")
			end
		end
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

local function Forget(A, P)
	A.Body[P], A.Spot[P], A.Last[P], A.Was[P], A.OutSince[P] = nil, nil, nil, nil, nil
	if Ambushes[P] == A then Ambushes[P] = nil end
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
		if M.Parent and Root(M) and M.Character == A.Body[M] then
			table.insert(Still, M)
		elseif M.Parent then -- down or held when the fight ended: they stay
			Send(M, "RoadCancel", {Route = A.Route})
			Notify(M, "Your party went on without you.")
		end
	end
	RoadService.ArenaCleared:Fire(A.Route, Still)
	if #Still > 0 then task.spawn(Trip, Still, A.Route, A.Arrive, A.Left) end
end

local function Drop(A, P, Text)
	local I = table.find(A.Party, P)
	if not I then return end
	table.remove(A.Party, I)
	Forget(A, P)
	if Text then Send(P, "RoadCancel", {Route = A.Route}) Notify(P, Text) end
	if #A.Party == 0 then Finish(A, false) end -- nobody left to fight: the enemies go, nobody travels
end

-- out past the edge on foot: off the ambush, and on along the road for the time that was left
local function Flee(A, P)
	local I = table.find(A.Party, P)
	if not I then return end
	table.remove(A.Party, I)
	Forget(A, P)
	Notify(P, "You got away. The road goes on.")
	task.spawn(Trip, {P}, A.Route, A.Arrive, A.Left)
	if #A.Party == 0 then Finish(A, false) end -- the enemies go; no ArenaCleared for a flee
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

-- 0 = inside (edge + Margin), 1 = in the band just past it, 2 = beyond, or far above / below
local function Zone(Arena, Pos)
	local L = Arena.CFrame:PointToObjectSpace(Pos)
	if L.Y < -12 or L.Y > 40 then return 2 end
	local Out = math.max(math.abs(L.X) - Arena.Size.X / 2, math.abs(L.Z) - Arena.Size.Z / 2)
	if Out <= RoadService.Margin then return 0 end
	if Out <= RoadService.Margin + RoadService.FleeBand then return 1 end
	return 2
end

local function WatchTick(A, Told)
	for _, P in ipairs(table.clone(A.Party)) do
		if A.Done then return end
		if not P.Parent or FlowTeleport.Busy(P) or FlowTeleport.InGroup(P) then
			Drop(A, P)
		else
			local C = A.Body[P]
			local R = C and P.Character == C and C:FindFirstChild("HumanoidRootPart")
			if R then
				local Z = Zone(A.Arena, R.Position)
				local Step = A.Last[P] and (R.Position - A.Last[P]).Magnitude or 0
				if Z == 0 then
					A.OutSince[P] = nil
				elseif not Held(C) and Step <= RoadService.MaxStep and (A.OutSince[P] or (A.Was[P] == 0 and Z == 1)) then
					A.OutSince[P] = A.OutSince[P] or os.clock() -- on foot, out past the edge: fleeing?
					if os.clock() - A.OutSince[P] >= RoadService.FleeHold then
						Flee(A, P)
						continue
					end
				else -- a far jump (a teleport), or carried / knocked out: back to their spot
					Unseat(P)
					R.AssemblyLinearVelocity = Vector3.zero
					C:PivotTo(A.Spot[P])
					A.OutSince[P], Z = nil, 0
					if not Told[P] or os.clock() - Told[P] > 3 then
						Told[P] = os.clock()
						Notify(P, "Win the fight, or flee on foot past the edge of the clearing.")
					end
				end
				A.Was[P], A.Last[P] = Z, R.Position
			end
		end
	end
	if A.Done then return end
	for _, E in ipairs(A.Enemies) do
		local R = E.Rig.Parent and E.Rig:FindFirstChild("HumanoidRootPart")
		if R and Zone(A.Arena, R.Position) ~= 0 then -- enemies stay in the clearing
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

local function Watch(A)
	local Told = {}
	while not A.Done do
		task.wait(RoadService.Tick)
		if A.Done then break end
		local Ok, Err = pcall(WatchTick, A, Told)
		if not Ok then warn("[RoadService] arena watchdog: " .. tostring(Err)) end
	end
end

-- Returns the ambush, or nil if it couldn't be set up (no one to move, or no enemy spawned): the caller goes on.
function Ambush(Party, RouteId, Arrive, Arena, MaxWanted, Left)
	local Ready = {}
	for _, M in ipairs(Party) do
		if M.Parent and Root(M) then table.insert(Ready, M) end
	end
	if #Ready == 0 or InUse[Arena] then return nil end
	local A = {Route = RouteId, Arrive = Arrive, Arena = Arena, Left = Left, Party = {}, Enemies = {}, Conns = {},
		Body = {}, Spot = {}, Last = {}, Was = {}, OutSince = {}}
	InUse[Arena] = A
	local EnemyService = require(ServerScriptService.EnemyService)
	local Kind = (MaxWanted or 0) >= 1 and "Elite" or "Grunt" -- Elite = "Bandit Duelist"
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
		A.Was[M], A.Last[M] = 0, A.Spot[M].Position
		local H = C:FindFirstChildOfClass("Humanoid")
		if H then table.insert(A.Conns, H.Died:Connect(function() Drop(A, M, DIED) end)) end
		table.insert(A.Conns, M.CharacterAdded:Connect(function() Drop(A, M, DIED) end))
		Send(M, "RoadAmbush", {Route = RouteId})
		Notify(M, AMBUSH)
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

-- YIELDS for the trip (or until the ambush). Returns "ambush" | "sent" | "loopback" (or "blocked": the arena is in use;
-- "none": nobody could go; "failed": Depart threw). The caller has done the checks.
function RoadService.Journey(Leader, RouteId, ForceAmbush)
	local R = Travel.Routes[RouteId]
	assert(R and R.Kind == "Road", "not a road")
	assert(Travel.Other(RouteId, TravelService.Here()), "that road doesn't leave " .. TravelService.Here())
	local Party, Left = Gather(Leader, RouteId)
	for _, L in ipairs(Left) do Notify(L[1], "Your party set off on the road without you. " .. L[2]) end
	for _, P in ipairs(Party) do OnRoad[P] = true end
	local Ok, Res = pcall(function()
		local Exit = ExitFor(RouteId)
		local Arrive = Exit and Exit:GetAttribute("Arrive") or "Platform"
		local MaxWanted = 0
		for _, M in ipairs(Party) do MaxWanted = math.max(MaxWanted, Wanted(M)) end
		local Hit = ForceAmbush
		if Hit == nil then Hit = math.random() < RoadService.Chance(MaxWanted) end
		local Arena = Hit and ArenaPart() or nil
		if Arena then
			if InUse[Arena] then -- the road ahead is taken by another party's ambush
				for _, P in ipairs(Party) do Notify(P, BLOCKED) end
				return "blocked"
			end
			InUse[Arena] = true -- reserved for this trip's ambush
		end
		return Trip(Party, RouteId, Arrive, R.Seconds, Arena and R.Seconds * RoadService.AmbushAt or nil, Arena, MaxWanted)
	end)
	for _, P in ipairs(Party) do OnRoad[P] = nil end -- every way out of here: off the road (a resumed trip sets it again)
	if not Ok then
		warn("[RoadService] journey failed: " .. tostring(Res))
		for _, P in ipairs(Party) do
			Send(P, "RoadCancel", {Route = RouteId})
			Notify(P, "You couldn't set off this time.")
		end
		return "failed"
	end
	return Res
end

-- everything a "Set off" (or the prompt) must pass, checked on the server
local function Check(P, RouteId)
	local R = type(RouteId) == "string" and Travel.Routes[RouteId]
	if not R or R.Kind ~= "Road" or not Travel.Other(RouteId, TravelService.Here()) then return false, "No such road from here." end
	local Exit, Me = ExitFor(RouteId), P.Character and P.Character:FindFirstChild("HumanoidRootPart")
	if not Exit or not Me or (Me.Position - Exit.Position).Magnitude > RoadService.ExitReach then
		return false, "Walk up to the road gate to set off."
	end
	local Party = PartyService.Get(P)
	if Party and Party.Leader ~= P then return false, "Your party leader decides when to set off." end
	local Why = Unfit(P, RouteId)
	if Why then return false, Why end
	local Arena = ArenaPart()
	if Arena and InUse[Arena] then return false, BLOCKED end
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
	task.spawn(RoadService.Journey, P, RouteId, Force)
	return true
end

local function Card(P, Exit)
	local RouteId = Exit:GetAttribute("Route")
	local Party = Gather(P, RouteId)
	local Names, MaxWanted = {}, 0
	for _, M in ipairs(Party) do
		table.insert(Names, M.DisplayName)
		MaxWanted = math.max(MaxWanted, Wanted(M))
		if M ~= P then Notify(M, "Your leader is setting off by road.") end
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

-- RoadService (World plan 1; Task 8b, 2026-10-21; world spec §3b "Roads on foot"): the road out of a region is a
-- real stretch of road you walk, and its far end hands you over to the next place like a game cutscene.
--   * The passage (built by station_lindenmoor.lua / station_foundry.lua): RenseiRoadPassage parts (Route, To,
--     RoadName) cover it; RenseiRoadEncounter parts sit along it, each with hidden SpawnPoint attachments (Side "Out" /
--     "In"); a RenseiRoadThreshold part (Route, To) is round the last bend; the RenseiArrival "RoadStart" is on the road
--     before that bend, facing inward. Walking onto it shows the area banner (TravelClient). Turning back is just
--     walking back: nothing happens until the threshold.
--   * The crossing (server-led, client-presented): when a player's root is in the threshold, the server checks they
--     can go (not knocked, gripped, carried, gripping or carrying: nobody escapes those by road; a player in combat MAY
--     cross, fleeing over the threshold is allowed), gathers the party members on the same passage within GatherRadius,
--     tells their clients "Crossing" (the client walks them on down the road, eases the camera into a low follow shot
--     and fades to the road's darkness), and after CrossDelay calls TravelService.Depart(Group, Route, "RoadStart"):
--     the Trip is written into each save before the teleport, as for the train. Anyone who dies, respawns, leaves the
--     server, is knocked or held, or leaves the party before then drops out ("CrossingCancel").
--   * Arrival (TravelService.Arrived with a road route): the client is told "CrossingIn": it walks the character in
--     from RoadStart under the same follow shot and lifts the darkness. Studio can't teleport: Depart loops back to
--     this place's own RoadStart, so the whole crossing can be played here.
--   * Party stragglers (best effort, live only): an arriving server writes {JobId, PlaceId, Expires} to MemoryStore
--     under "Party:<UserId>:<Route>" for each road arrival (StragglerTTL s). A party member who crossed later than
--     their party looks up the key of the member who led the crossing, and Depart sends them to that server
--     (TeleportOptions.ServerInstanceId); if it's full or gone, FlowTeleport falls back to the normal teleport.
--   * Encounters: the first time a party (or a solo player) enters an encounter part on a crossing, the server rolls
--     Travel.AmbushChance(night, winter, the party's highest State Wanted) once for that passage. On a hit, bandits come
--     out from that encounter's SpawnPoints ahead of them (Grunts; an Elite Bandit Duelist leads if anyone is Wanted):
--     real EnemyService enemies from an unparented spawn mark (Task 7: they never respawn), leashed to the encounter's
--     stretch, and removed (not killed: no reward) once nobody has been within ClearRadius for ClearAfter s. Kills
--     give the normal rewards. Running past them is fine: the threshold crosses as normal.
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
RoadService.Season = function() return "Summer" end -- the seasons plan replaces this
RoadService.Tick = 0.2 -- PROPOSAL: seconds between the server's passage / threshold / encounter checks
RoadService.CrossDelay = 1.2 -- PROPOSAL (brief): the client's walk-in before Depart
RoadService.GatherRadius = 40 -- PROPOSAL (brief): party members on the same passage this close cross together
RoadService.ArriveGuard = 3 -- PROPOSAL: seconds after an arrival before the threshold can take you again
RoadService.HoldDeadline = 25 -- PROPOSAL: live, seconds after Depart a sent player may still be here before release / kick
RoadService.StragglerTTL = 120 -- PROPOSAL (brief): seconds an arriving server shares its id for a party's stragglers
RoadService.ClearRadius = 80 -- PROPOSAL (brief): an encounter's bandits stay while a player is this close
RoadService.ClearAfter = 30 -- PROPOSAL (brief): ... and are removed after this many seconds with nobody near
RoadService.Leash = 10 -- PROPOSAL: studs past the encounter's box a bandit may stray before it is put back
RoadService.RollReset = 60 -- PROPOSAL: seconds off the passage before a party's next walk counts as a new crossing
RoadService.ToastGap = 3 -- PROPOSAL: seconds between one player's refusal toasts at the threshold
RoadService.TimeScale = 1 -- Studio tests only: ClearAfter x this (e.g. 0.05); a live server always uses 1
RoadService.Force = nil -- Studio tests only: true / false forces the next encounter roll (a live server ignores it)
RoadService.Calm = false -- Studio tests only: true = no encounter rolls unless forced (a live server ignores it)

local DIED = "You came to back in town. The crossing will have to wait."
-- the downed / grip / carry attributes DownedManager sets on a character: nobody escapes those by road
local HELD = {"Knocked", "GrippedBy", "CarriedBy", "Gripping", "Carrying"}

local Event -- Remotes.TravelEvent (made by StationService)
local Crossing = {} -- [Player] = the token of the crossing that has them (until it ends)
local ArrivedAt = {} -- [Player] = os.clock() of their last road arrival
local Ahead = {} -- [Player] = {UserId = who led the party's crossing, Route, Until}: their party went on ahead
local Rolled = {} -- [party key][Route] = {Seen = os.clock()}: this crossing's encounter roll is spent
local Active = {} -- [encounter part] = {Enemies = {{Rig, Home}}, Near = os.clock()}
local LastToast = {}

local function Notify(P, Text) if P.Parent then UIService.Notify(P, "Toast", {Text = Text}) end end
local function Send(P, Kind, Data) if Event and P.Parent then Event:FireClient(P, Kind, Data) end end
local function RegionName(Id) return Places.Regions[Id] and Places.Regions[Id].Name or tostring(Id) end
local function Scale() return RunService:IsStudio() and math.clamp(tonumber(RoadService.TimeScale) or 1, 0.001, 1) or 1 end
local function Toast(P, Text) -- rate-limited (someone standing in the threshold is checked every tick)
	local Now = os.clock()
	if LastToast[P] and Now - LastToast[P] < RoadService.ToastGap then return end
	LastToast[P] = Now
	Notify(P, Text)
end

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

local function RootOf(C) return C and C:FindFirstChild("HumanoidRootPart") end

local function Inside(Part, Pos)
	local L = Part.CFrame:PointToObjectSpace(Pos)
	local H = Part.Size / 2
	return math.abs(L.X) <= H.X and math.abs(L.Y) <= H.Y and math.abs(L.Z) <= H.Z
end

local function Tagged(Tag)
	local Out = {}
	for _, P in ipairs(CollectionService:GetTagged(Tag)) do
		if P:IsA("BasePart") and P:IsDescendantOf(workspace) then table.insert(Out, P) end
	end
	return Out
end

-- a road that leaves this place
local function Leaves(RouteId)
	local R = type(RouteId) == "string" and Travel.Routes[RouteId]
	return R and R.Kind == "Road" and Travel.Other(RouteId, TravelService.Here()) ~= nil
end

-- the route of the passage Pos is on (nil when off every passage)
local function PassageAt(Pos)
	for _, P in ipairs(Tagged("RenseiRoadPassage")) do
		if Inside(P, Pos) then return P:GetAttribute("Route") end
	end
	return nil
end
RoadService.PassageAt = PassageAt

-- why P can't cross right now, or nil (a fight is no reason: fleeing over the threshold is allowed)
local function Unfit(P, RouteId)
	local C = P.Character
	local H = C and C:FindFirstChildOfClass("Humanoid")
	if not (H and H.Health > 0 and RootOf(C)) then return "You can't travel right now." end
	if Held(C) then return "You can't cross while you're down, held or holding someone." end
	if Crossing[P] or FlowTeleport.Busy(P) or FlowTeleport.InGroup(P) then return "You're already on your way." end
	local Ok, Riding = pcall(function() return require(ServerScriptService.StationService).Riding(P) end)
	if Ok and Riding then return "You're already on your way." end
	local Can, Why = Travel.CanTake(Level(P), RouteId)
	if not Can then return Why end
	return nil
end

-- who crosses with P: P, plus each party member on the same passage within GatherRadius who is fit to go.
-- Returns the group and the members left behind ({Player, why}).
function RoadService.Gather(P, RouteId)
	local Party = PartyService.Get(P)
	local Out, Left = {P}, {}
	local Me = RootOf(P.Character)
	for _, M in ipairs(Party and Party.Members or {}) do
		if M ~= P and M.Parent then
			local R = RootOf(M.Character)
			local Why = Unfit(M, RouteId)
			if not Why and not (Me and R and PassageAt(R.Position) == RouteId and (R.Position - Me.Position).Magnitude <= RoadService.GatherRadius) then
				Why = "You were too far back."
			end
			if Why then table.insert(Left, {M, Why}) else table.insert(Out, M) end
		end
	end
	return Out, Left
end

function RoadService.OnRoad(P) return Crossing[P] ~= nil end
function RoadService.Chance(MaxWanted)
	local Night = Lighting.ClockTime < 6 or Lighting.ClockTime > 19
	return Travel.AmbushChance(Night, RoadService.Season() == "Winter", MaxWanted or 0)
end

-- the party's key for its encounter roll (the party table, or the player alone)
local function KeyOf(P) return PartyService.Get(P) or P end

-- ===== Party stragglers (MemoryStore; live only, best effort) =====
local function StragglerMap()
	local Ok, Map = pcall(function() return game:GetService("MemoryStoreService"):GetSortedMap("RenseiRoadParty") end)
	return Ok and Map or nil
end
local function ShareServer(P, RouteId) -- the arriving server: "the party that came by RouteId is here"
	if RunService:IsStudio() then return end
	task.spawn(function()
		local Map = StragglerMap()
		if not Map then return end
		local Ok, Err = pcall(function()
			Map:SetAsync(("Party:%d:%s"):format(P.UserId, RouteId), {JobId = game.JobId, PlaceId = game.PlaceId,
				Expires = os.time() + RoadService.StragglerTTL}, RoadService.StragglerTTL)
		end)
		if not Ok then warn("[RoadService] couldn't share this server for " .. RouteId .. ": " .. tostring(Err)) end
	end)
end
local function PartyServer(P, RouteId) -- the straggler's server: where did my party go? (yields; nil = anywhere)
	if RunService:IsStudio() then return nil end
	local A = Ahead[P]
	if not (A and A.Route == RouteId and A.Until > os.clock()) then return nil end
	local Map = StragglerMap()
	if not Map then return nil end
	local Ok, V = pcall(function() return Map:GetAsync(("Party:%d:%s"):format(A.UserId, RouteId)) end)
	local Dest = Travel.Other(RouteId, TravelService.Here())
	if Ok and type(V) == "table" and type(V.JobId) == "string" and V.JobId ~= "" and (tonumber(V.Expires) or 0) > os.time()
		and Dest and Places.Regions[Dest] and V.PlaceId == Places.Regions[Dest].PlaceId then
		return V.JobId
	end
	return nil
end

-- ===== The crossing =====
local function Cancel(P, Token, Text)
	if Crossing[P] ~= Token then return end
	Crossing[P] = nil
	Send(P, "CrossingCancel", {})
	if Text then Notify(P, Text) end
end

local function Cross(P, Th, RouteId)
	local Group, Left = RoadService.Gather(P, RouteId)
	local Token = {}
	local Body, Conns = {}, {}
	local Dir = Th.CFrame.LookVector
	Dir = Vector3.new(Dir.X, 0, Dir.Z).Unit
	local Starts = workspace:GetServerTimeNow()
	local Dest = RegionName(Travel.Other(RouteId, TravelService.Here()))
	for _, M in ipairs(Group) do
		Crossing[M] = Token
		Body[M] = M.Character
		local H = M.Character:FindFirstChildOfClass("Humanoid")
		if H then table.insert(Conns, H.Died:Connect(function() Cancel(M, Token, DIED) end)) end
		table.insert(Conns, M.CharacterAdded:Connect(function() Cancel(M, Token, DIED) end))
		Send(M, "Crossing", {Route = RouteId, Dest = Dest, Dir = Dir, Starts = Starts, Delay = RoadService.CrossDelay})
	end
	for _, L in ipairs(Left) do -- the rest of the party: they can follow, and will be sent after them (best effort)
		Ahead[L[1]] = {UserId = P.UserId, Route = RouteId, Until = os.clock() + RoadService.StragglerTTL}
		Notify(L[1], "Your party crossed ahead on the road. " .. L[2])
	end
	task.wait(RoadService.CrossDelay)
	for _, C in ipairs(Conns) do C:Disconnect() end
	local Still = {}
	for _, M in ipairs(Group) do
		if Crossing[M] == Token then
			local C = M.Character
			if not M.Parent then
				Crossing[M] = nil
			elseif C ~= Body[M] or not RootOf(C) then
				Cancel(M, Token, DIED)
			elseif Held(C) then
				Cancel(M, Token, "You couldn't cross while down or held.")
			elseif M ~= P and not PartyService.SameParty(M, P) then
				Cancel(M, Token, "You left the party; the crossing went on without you.")
			elseif FlowTeleport.Busy(M) or FlowTeleport.InGroup(M) then
				Cancel(M, Token)
			else
				table.insert(Still, M)
			end
		end
	end
	if #Still == 0 then return "none" end
	local Join = PartyServer(P, RouteId) -- a straggler: their party's server, if it's still there
	for _, M in ipairs(Still) do Ahead[M] = nil end
	local Keys = {}
	for _, M in ipairs(Still) do Keys[KeyOf(M)] = true end
	for K in pairs(Keys) do if Rolled[K] then Rolled[K][RouteId] = nil end end -- the next walk is a new crossing
	local Ok, Mode, Went = pcall(TravelService.Depart, Still, RouteId, "RoadStart", Join)
	if not Ok then warn("[RoadService] Depart failed on " .. RouteId .. ": " .. tostring(Mode)) end
	local Sent = {}
	for _, M in ipairs(Ok and Went or {}) do Sent[M] = true end
	local Live = {}
	for _, M in ipairs(Still) do
		if not Sent[M] then
			if M.Parent and not Ok and not RunService:IsStudio() then -- live: their saves may already be released
				Crossing[M] = nil
				M:Kick(("The road to %s couldn't be travelled. Please rejoin."):format(Dest))
			else -- dropped by Depart (already teleporting, no save loaded)
				Cancel(M, Token, "You couldn't cross this time.")
			end
		elseif not RunService:IsStudio() then
			table.insert(Live, M)
		end
	end
	if #Live > 0 then -- live: no crossing without a deadline (a failed teleport also kicks, through Depart's OnFail)
		task.delay(RoadService.HoldDeadline, function()
			for _, M in ipairs(Live) do
				if M.Parent and Crossing[M] == Token then
					if ProgressionService.GetData(M) then -- the save is still here: back to the road
						Cancel(M, Token, "The road couldn't take you this time.")
					else -- the save was released for the teleport: they can't stay
						Crossing[M] = nil
						M:Kick(("The road to %s couldn't be travelled. Please rejoin."):format(Dest))
					end
				end
			end
		end)
	end
	return Ok and Mode or "failed"
end

-- the threshold: P's root is in it
local function AtThreshold(P, Th)
	local RouteId = Th:GetAttribute("Route")
	if not Leaves(RouteId) or Crossing[P] then return end
	if ArrivedAt[P] and os.clock() - ArrivedAt[P] < RoadService.ArriveGuard then return end
	local Why = Unfit(P, RouteId)
	if Why then Toast(P, Why) return end
	task.spawn(function()
		local Ok, Err = pcall(Cross, P, Th, RouteId)
		if not Ok then
			warn("[RoadService] crossing failed: " .. tostring(Err))
			for M, T in pairs(Crossing) do
				if T and (M == P or PartyService.SameParty(M, P)) then Cancel(M, T, "You couldn't cross this time.") end
			end
		end
	end)
end

-- ===== Encounters =====
local function RemoveEnemy(Rig)
	local EnemyService = require(ServerScriptService.EnemyService)
	local E = EnemyService.Active[Rig]
	EnemyService.Active[Rig] = nil -- not a kill: no Died, so no reward and no respawn
	if E and E.WCS then pcall(function() E.WCS:Destroy() end) end
	if Rig.Parent then Rig:Destroy() end -- CombatDirector and PerceptionService drop it on removal
end

local function Standing(Rig)
	local H = Rig.Parent and Rig:FindFirstChildOfClass("Humanoid")
	return H ~= nil and H.Health > 0
end

-- spawn the encounter's bandits at its SpawnPoints on the side ahead of Pos. Returns how many came out.
local function Ambush(E, Pos, Size, MaxWanted)
	if Active[E] then return 0 end -- already out
	local Ahead2 = E.CFrame:PointToObjectSpace(Pos).Z > 0 and "Out" or "In" -- came in from the town end: ahead is "Out"
	local Points = {}
	for _, A in ipairs(E:GetChildren()) do
		if A:IsA("Attachment") and A.Name == "SpawnPoint" and A:GetAttribute("Side") == Ahead2 then table.insert(Points, A) end
	end
	if #Points == 0 then return 0 end
	local EnemyService = require(ServerScriptService.EnemyService)
	local N = 2 + (Size > 2 and 1 or 0) -- world spec: 2-3
	local Mine = {Enemies = {}, Near = os.clock()}
	Active[E] = Mine
	for I = 1, N do
		local A = Points[(I - 1) % #Points + 1]
		local Kind = (MaxWanted >= 1 and I == 1) and "Elite" or "Grunt" -- Elite = "Bandit Duelist", Grunt = "Bandit"
		-- an unparented spawn part: EnemyService only respawns from a part that still has a parent
		local Mark = Instance.new("Part")
		Mark.Anchored, Mark.CanCollide, Mark.Transparency = true, false, 1
		Mark.CFrame = A.WorldCFrame * CFrame.new(((I - 1) // #Points) * 4, 0, 0) -- a third one stands beside the first
		Mark:SetAttribute("EnemyType", Kind)
		local Ok, Rig = pcall(EnemyService.Spawn, Mark)
		if Ok and typeof(Rig) == "Instance" then
			table.insert(Mine.Enemies, {Rig = Rig, Home = Rig:GetPivot()})
		else
			warn("[RoadService] road bandit " .. I .. " failed to spawn: " .. tostring(Rig))
		end
	end
	if #Mine.Enemies == 0 then Active[E] = nil end
	return #Mine.Enemies
end

-- P (in party key K) walked into encounter E: the crossing's one roll for this passage
local function AtEncounter(P, E, RouteId)
	if RunService:IsStudio() and RoadService.Calm and RoadService.Force == nil then return end
	local K = KeyOf(P)
	Rolled[K] = Rolled[K] or {}
	if Rolled[K][RouteId] then return end
	Rolled[K][RouteId] = {Seen = os.clock()}
	local Party = PartyService.Get(P)
	local Members = Party and Party.Members or {P}
	local MaxWanted = 0
	for _, M in ipairs(Members) do MaxWanted = math.max(MaxWanted, Wanted(M)) end
	local Hit
	if RunService:IsStudio() and RoadService.Force ~= nil then
		Hit = RoadService.Force
		RoadService.Force = nil
	else
		Hit = math.random() < RoadService.Chance(MaxWanted)
	end
	if not Hit then return end
	local R = RootOf(P.Character)
	local N = R and Ambush(E, R.Position, #Members, MaxWanted) or 0
	if N > 0 then
		for _, M in ipairs(Members) do
			if M.Parent and PassageAt((RootOf(M.Character) or {Position = Vector3.zero}).Position) == RouteId then
				Notify(M, "Bandits on the road ahead!")
			end
		end
	end
end

-- leash the bandits to their stretch; remove them once nobody has been near for ClearAfter s
local function WatchEncounters()
	local Now = os.clock()
	local Roots = {}
	for _, P in ipairs(Players:GetPlayers()) do
		local R = RootOf(P.Character)
		if R then table.insert(Roots, R.Position) end
	end
	for E, A in pairs(Active) do
		local Up = 0
		local Points = {E.Position}
		for _, En in ipairs(A.Enemies) do
			if Standing(En.Rig) then
				Up += 1
				local R = RootOf(En.Rig)
				if R then
					table.insert(Points, R.Position)
					local L = E.CFrame:PointToObjectSpace(R.Position)
					local H = E.Size / 2 + Vector3.one * RoadService.Leash
					if math.abs(L.X) > H.X or math.abs(L.Y) > H.Y or math.abs(L.Z) > H.Z or not E.Parent then
						R.AssemblyLinearVelocity = Vector3.zero
						En.Rig:PivotTo(En.Home)
					end
				end
			end
		end
		for _, Pos in ipairs(Roots) do
			for _, Q in ipairs(Points) do
				if (Pos - Q).Magnitude <= RoadService.ClearRadius then A.Near = Now break end
			end
		end
		if Up == 0 or not E.Parent or Now - A.Near >= RoadService.ClearAfter * Scale() then
			Active[E] = nil
			for _, En in ipairs(A.Enemies) do
				if Standing(En.Rig) then RemoveEnemy(En.Rig) end -- the fallen were credited as usual; the rest just go
			end
		end
	end
end

-- test hooks
function RoadService.EnemiesAt(E)
	local Out = {}
	for _, En in ipairs(Active[E] and Active[E].Enemies or {}) do
		if Standing(En.Rig) then table.insert(Out, En.Rig) end
	end
	return Out
end
function RoadService.ClearEncounter(E)
	local A = Active[E]
	Active[E] = nil
	for _, En in ipairs(A and A.Enemies or {}) do if En.Rig.Parent then RemoveEnemy(En.Rig) end end
end
function RoadService.ResetRolls(P) Rolled[KeyOf(P)] = nil end

-- ===== The watch: every Tick, each player's passage, encounter and threshold =====
local function TickAll()
	local Now = os.clock()
	local Thresholds, Encounters = Tagged("RenseiRoadThreshold"), Tagged("RenseiRoadEncounter")
	for _, P in ipairs(Players:GetPlayers()) do
		local R = RootOf(P.Character)
		local RouteId = R and PassageAt(R.Position)
		if RouteId then
			local K = KeyOf(P)
			if Rolled[K] and Rolled[K][RouteId] then Rolled[K][RouteId].Seen = Now end
			for _, E in ipairs(Encounters) do
				if E:GetAttribute("Route") == RouteId and Inside(E, R.Position) then AtEncounter(P, E, RouteId) end
			end
		end
		if R and not Crossing[P] then
			for _, Th in ipairs(Thresholds) do
				if Inside(Th, R.Position) then AtThreshold(P, Th) break end
			end
		end
	end
	-- a party off the passage for RollReset s starts a new crossing next time
	for K, Routes in pairs(Rolled) do
		for RouteId, V in pairs(Routes) do
			if Now - V.Seen > RoadService.RollReset then Routes[RouteId] = nil end
		end
		if next(Routes) == nil then Rolled[K] = nil end
	end
	WatchEncounters()
end

-- the client's old "Set off" (Remotes.Travel "Road", through StationService) no longer exists: the road is walked
function RoadService.Request(P, RouteId)
	return false, "Walk the road out of town to travel it."
end

function RoadService.Start()
	Event = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TravelEvent", 30)
	-- arrival by road: walk in from RoadStart (the Studio loopback too); share this server with the party's stragglers
	TravelService.Arrived.Event:Connect(function(P, Region, RouteId)
		local R = RouteId and Travel.Routes[RouteId]
		if not (R and R.Kind == "Road") then return end
		Crossing[P] = nil
		ArrivedAt[P] = os.clock()
		local At = TravelService.ArrivalPoint("RoadStart")
		local Dir = At and At.CFrame.LookVector or Vector3.new(0, 0, -1)
		Send(P, "CrossingIn", {Route = RouteId, Dir = Vector3.new(Dir.X, 0, Dir.Z).Unit, From = RegionName(Travel.Other(RouteId, Region))})
		ShareServer(P, RouteId)
	end)
	Players.PlayerRemoving:Connect(function(P)
		Crossing[P], ArrivedAt[P], Ahead[P], LastToast[P] = nil, nil, nil, nil
		if Rolled[P] then Rolled[P] = nil end
	end)
	task.spawn(function()
		while true do
			task.wait(RoadService.Tick)
			local Ok, Err = pcall(TickAll)
			if not Ok then warn("[RoadService] road watch: " .. tostring(Err)) end
		end
	end)
end

return RoadService

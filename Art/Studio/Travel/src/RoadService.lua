-- RoadService (World plan 1; Task 8b, 2026-10-21; world spec §3b "Roads on foot"): the road out of a region is a
-- real stretch of road you walk, and its far end hands you over to the next place like a game cutscene.
--   * The passage (built by station_lindenmoor.lua / station_foundry.lua): RenseiRoadPassage parts (Route, To,
--     RoadName, Leg = 1 at the mouth .. n at the threshold) cover it, with RoadPoint attachments on its centre line;
--     RenseiRoadEncounter parts (Route, Order) sit along it, each with hidden SpawnPoint attachments (Side "Out" /
--     "In"); a RenseiRoadThreshold part (Route, To) is round the last bend; the RenseiArrival "RoadStart" is on the road
--     before that bend, facing inward. Walking onto it shows the area banner (TravelClient). Turning back is just
--     walking back: nothing happens until the threshold.
--   * Walking it (fix round 1): every Tick the server keeps a track per player: the passage they're on and the furthest
--     leg reached in order from the mouth (leg 1). The track is dropped when they leave the passage, or move further in
--     one tick than MaxSpeed allows (a teleport, a respawn). A track starts only in leg 1 and in no other leg (fix
--     round 2: the boxes overlap at the bends, so a start in an overlap would skip legs), or by arriving at RoadStart;
--     it advances at most one leg per tick, and not on the tick it starts.
--     Only a player whose track has reached the last leg through the earlier ones can cross: a teleport into the
--     threshold box (to escape a fight or an arrest) doesn't cross.
--   * The crossing (server-led, client-presented): when a walker's root is in the threshold, the server checks they
--     can go (not knocked, gripped, carried, gripping or carrying: nobody escapes those by road; a player in combat MAY
--     cross, fleeing over the threshold is allowed), gathers the party members walking the same passage within
--     GatherRadius, tells their clients "Crossing" (each with the road's direction nearest them: the client walks them
--     on down the road, eases the camera into a low follow shot and fades to the road's darkness), and after CrossDelay
--     calls TravelService.Depart(Group, Route, "RoadStart"): the Trip is written into each save before the teleport, as
--     for the train. Anyone who dies, respawns, leaves the server, is knocked or held, or leaves the party before then
--     drops out ("CrossingCancel"); a cancelled player is ignored by the threshold until they step out of it (or
--     RearmTime s).
--   * Arrival (TravelService.Arrived with a road route): the group is spread across the road at RoadStart and each
--     client is told "CrossingIn": it walks the character in under the same follow shot and lifts the darkness. Studio
--     can't teleport: Depart loops back to this place's own RoadStart, so the whole crossing can be played here.
--   * Party stragglers (best effort, live only): each crossing has a nonce, carried in the TeleportData. An arriving
--     server writes {JobId, PlaceId, Expires, Nonce} to MemoryStore under "Party:<UserId>:<Route>" for each road
--     arrival (StragglerTTL s). A party member left behind remembers who led the crossing and its nonce; when they
--     cross, the lookup (started as their walk-in starts) must match that nonce, and Depart sends them to that server
--     (TeleportOptions.ServerInstanceId); if it's full or gone, FlowTeleport falls back to the normal teleport.
--   * Encounters: the first time a party (or a solo player) enters an encounter part on a crossing, the server rolls
--     Travel.AmbushChance(night, winter, the party's highest State Wanted) once for that passage (controller's ruling).
--     On a hit the ambush is set at a random encounter still ahead of them (this one included): when they reach it,
--     bandits come out from its SpawnPoints ahead of them (Grunts; an Elite Bandit Duelist leads if anyone is Wanted):
--     real EnemyService enemies from an unparented spawn mark (Task 7: they never respawn), held to the encounter's
--     stretch (past Leash, PerceptionService.Lose: the AI gives up the chase and walks home itself; a pivot home only
--     for a big overshoot), and removed (not killed: no reward) once nobody has been within ClearRadius for ClearAfter
--     s. Kills give the normal rewards.
--     Running past them is fine: the threshold crosses as normal.
-- Every number is a PROPOSAL.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

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
RoadService.MaxSpeed = 130 -- PROPOSAL: studs/s a walk, sprint or dash can reach (TuningConfig.Dash peaks at 110); a move
                           -- of more than MaxSpeed x the tick's time x 2 is a teleport and drops the track
RoadService.DtCap = 2 -- PROPOSAL (fix round 2): the tick's time counts as at most this many Ticks, so a stalled watch
                      -- doesn't allow a proportionally bigger jump
RoadService.CrossDelay = 1.2 -- PROPOSAL (brief): the client's walk-in before Depart
RoadService.GatherRadius = 40 -- PROPOSAL (brief): party members walking the same passage this close cross together
RoadService.ArriveGuard = 3 -- PROPOSAL: seconds after an arrival before the threshold can take you again
RoadService.RearmTime = 3 -- PROPOSAL: after a cancelled crossing, the threshold ignores you until you leave it or this
RoadService.HoldDeadline = 25 -- PROPOSAL: live, seconds after Depart a sent player may still be here before release / kick
RoadService.JoinDeadline = 2 -- PROPOSAL: x HoldDeadline when sending to a party's server (its fallback needs the time)
RoadService.JoinWait = 1 -- PROPOSAL: seconds past CrossDelay a straggler's server lookup may still take
RoadService.StragglerTTL = 120 -- PROPOSAL (brief): seconds an arriving server shares its id for a party's stragglers
RoadService.ArriveSpread = 4 -- PROPOSAL: studs between group members set down side by side at RoadStart
RoadService.ClearRadius = 80 -- PROPOSAL (brief): an encounter's bandits stay while a player is this close
RoadService.ClearAfter = 30 -- PROPOSAL (brief): ... and are removed after this many seconds with nobody near
RoadService.Leash = 10 -- PROPOSAL: studs past the encounter's box a bandit may stray before it is sent home
RoadService.Overshoot = 30 -- PROPOSAL: studs past the box beyond which it is put home at once (flung, fallen)
RoadService.RollReset = 60 -- PROPOSAL: seconds off the passage before a party's next walk counts as a new crossing
RoadService.ToastGap = 3 -- PROPOSAL: seconds between one player's refusal toasts at the threshold
RoadService.TimeScale = 1 -- Studio tests only: ClearAfter x this (e.g. 0.05); a live server always uses 1
RoadService.Force = nil -- Studio tests only: true / false forces the next encounter roll (a live server ignores it)
RoadService.Calm = false -- Studio tests only: true = no encounter rolls unless forced (a live server ignores it)

local DIED = "You came to back in town. The crossing will have to wait."
-- the downed / grip / carry attributes DownedManager sets on a character: nobody escapes those by road; (hostages Task
-- 10, ruling R5: journeys with a hostage are a follow-up plan) nor a captor (Holding) or a hostage (HeldBy)
local HELD = {"Knocked", "GrippedBy", "CarriedBy", "Gripping", "Carrying", "Holding", "HeldBy"}

local Event -- Remotes.TravelEvent (made by StationService)
local Crossing = {} -- [Player] = the token of the crossing that has them (until it ends)
local Track = {} -- [Player] = {Route, Leg, LastPos, LastT}: walking a passage, the furthest leg reached in order
local Rearm = {} -- [Player] = os.clock() of a cancelled crossing: the threshold ignores them until they leave it
local ArrivedAt = {} -- [Player] = os.clock() of their last road arrival
local Arrivals = {} -- [Route] = {N, T}: members set down at RoadStart in the last moments (spread across the road)
local Ahead = {} -- [Player] = {UserId = who led the party's crossing, Route, Until, Nonce}: their party went on ahead
local Rolled = {} -- [Player][Route] = the crossing's roll {Seen, Pending, MaxWanted}, shared by the party
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

-- (downed crawl fix round 2, 2026-10-27) a deliberate move of a player's character: DownedManager's crawl clamp starts
-- again from the new spot, else it would put a knocked player back where they were. (Hostages Task 10, Task 6 re-review
-- m7) so does a led hostage pair's lead clamp (HostageService.Rebase, either side of the pair; false and nothing done
-- when the character leads none), else the move ends the hold as a blink and leaves the hostage at the last lead. Both
-- optional: a place without HostageService skips it.
local function Rebased(C)
	if not C then return end
	pcall(function() require(game:GetService("ReplicatedStorage").Modules.Managers.DownedManager).RebaseCrawl(C) end)
	pcall(function()
		local HS = game:GetService("ServerScriptService"):FindFirstChild("HostageService")
		if HS then require(HS).Rebase(C) end
	end)
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

-- the route of the passage Pos is on (nil when off every passage), and the set of its legs Pos is in
local function LegsAt(Pos, Passages)
	local Route, In = nil, {}
	for _, P in ipairs(Passages or Tagged("RenseiRoadPassage")) do
		if Inside(P, Pos) then
			local R = P:GetAttribute("Route")
			if Route == nil or R == Route then
				Route = R
				In[tonumber(P:GetAttribute("Leg")) or 1] = true
			end
		end
	end
	return Route, In
end
local function PassageAt(Pos, Passages) return (LegsAt(Pos, Passages)) end
RoadService.PassageAt = function(Pos) return PassageAt(Pos) end

local function LastLeg(RouteId, Passages)
	local N = 0
	for _, P in ipairs(Passages or Tagged("RenseiRoadPassage")) do
		if P:GetAttribute("Route") == RouteId then N = math.max(N, tonumber(P:GetAttribute("Leg")) or 1) end
	end
	return N
end

-- the road's way out at the RoadPoint nearest Pos (nil if the passage has none)
local function RoadDir(Pos, RouteId)
	local Best, BD = nil, math.huge
	for _, P in ipairs(Tagged("RenseiRoadPassage")) do
		if P:GetAttribute("Route") == RouteId then
			for _, A in ipairs(P:GetChildren()) do
				if A:IsA("Attachment") and A.Name == "RoadPoint" then
					local D = (A.WorldPosition - Pos).Magnitude
					if D < BD then Best, BD = A, D end
				end
			end
		end
	end
	if not Best then return nil end
	local L = Best.WorldCFrame.LookVector
	return Vector3.new(L.X, 0, L.Z).Unit
end
RoadService.RoadDir = RoadDir

-- the walk: update P's track from where their root is now (once per Tick)
local function Walk(P, Pos, Now, Passages)
	local Route, In = LegsAt(Pos, Passages)
	local T = Track[P]
	if T then
		local Dt = math.clamp(Now - T.LastT, RoadService.Tick, RoadService.Tick * RoadService.DtCap)
		if Route ~= T.Route or (Pos - T.LastPos).Magnitude > RoadService.MaxSpeed * Dt * 2 then T = nil end
	end
	if not T then
		-- a walk starts at the mouth: in leg 1 and in no other leg (fix round 2: the boxes overlap at the bends, so a
		-- start in leg 1's overlap with leg 2 or 3, e.g. down off the bank into the first bend, would skip legs)
		local Only1 = Route ~= nil and In[1] == true
		for L in pairs(In) do if L ~= 1 then Only1 = false end end
		if Only1 then T = {Route = Route, Leg = 1} end -- (no step on: it starts in leg 1 alone)
	elseif In[T.Leg + 1] then
		T.Leg += 1 -- the legs overlap at the bends: on into the next only from the last, one leg per tick
	end
	if T then T.LastPos, T.LastT = Pos, Now end
	Track[P] = T
	return Route
end
-- walking RouteId's passage (from its mouth, or since arriving): the leg reached, or nil
local function Walking(P, RouteId)
	local T = Track[P]
	return T and T.Route == RouteId and T.Leg or nil
end
RoadService.Walking = Walking
-- test hook (stand-in party members aren't players, so the watch doesn't track them; At: the time of the last check)
function RoadService.SetTrack(P, RouteId, Leg, Pos, At)
	Track[P] = RouteId and {Route = RouteId, Leg = Leg or 1, LastPos = Pos or Vector3.zero, LastT = At or os.clock()} or nil
end

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
RoadService._Unfit = Unfit -- (hostages Task 10) test seam: the crossing's refusal, unchanged

-- who crosses with P: P, plus each party member walking the same passage within GatherRadius who is fit to go.
-- Returns the group and the members left behind ({Player, why}).
function RoadService.Gather(P, RouteId)
	local Party = PartyService.Get(P)
	local Out, Left = {P}, {}
	local Me = RootOf(P.Character)
	for _, M in ipairs(Party and Party.Members or {}) do
		if M ~= P and M.Parent then
			local R = RootOf(M.Character)
			local Why = Unfit(M, RouteId)
			-- fix round 2: walking this passage and on its last legs too, so it doesn't rest on the boxes' shape
			local Leg = Walking(M, RouteId)
			if not Why and not (Me and R and Leg and Leg >= LastLeg(RouteId) - 1 and PassageAt(R.Position) == RouteId
				and (R.Position - Me.Position).Magnitude <= RoadService.GatherRadius) then
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

-- the party's members (or P alone). Fix round 1: the encounter roll is kept per player and shared by the party.
-- PartyService.Get returns the live party record (the same table for the party's life), but a member who joins, or
-- a party formed on the road, would get a fresh key; checking every member's record keeps one roll per crossing.
local function MembersOf(P)
	local Party = PartyService.Get(P)
	return Party and Party.Members or {P}
end
local function RollOf(P, RouteId)
	for _, M in ipairs(MembersOf(P)) do
		local R = Rolled[M] and Rolled[M][RouteId]
		if R then return R end
	end
	return Rolled[P] and Rolled[P][RouteId] or nil
end

-- ===== Party stragglers (MemoryStore; live only, best effort) =====
local function StragglerMap()
	local Ok, Map = pcall(function() return game:GetService("MemoryStoreService"):GetSortedMap("RenseiRoadParty") end)
	return Ok and Map or nil
end
local function ShareServer(P, RouteId) -- the arriving server: "the party that came by RouteId is here"
	if RunService:IsStudio() then return end
	task.spawn(function()
		local Ok0, Join = pcall(function() return P:GetJoinData() end)
		local TD = Ok0 and type(Join) == "table" and Join.TeleportData
		local Nonce = type(TD) == "table" and type(TD.Travel) == "table" and TD.Travel.Nonce or nil
		local Map = StragglerMap()
		if not Map then return end
		local Ok, Err = pcall(function()
			Map:SetAsync(("Party:%d:%s"):format(P.UserId, RouteId), {JobId = game.JobId, PlaceId = game.PlaceId,
				Expires = os.time() + RoadService.StragglerTTL, Nonce = Nonce}, RoadService.StragglerTTL)
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
		and V.Nonce == A.Nonce and Dest and Places.Regions[Dest] and V.PlaceId == Places.Regions[Dest].PlaceId then
		return V.JobId
	end
	return nil
end

-- ===== The crossing =====
local function Cancel(P, Token, Text)
	if Crossing[P] ~= Token then return end
	Crossing[P] = nil
	Rearm[P] = os.clock() -- not straight back in: they must step out of the threshold first (or RearmTime)
	Send(P, "CrossingCancel", {})
	if Text then Notify(P, Text) end
end

local function Cross(P, Th, RouteId)
	-- a straggler: start looking up their party's server now, while they walk in
	local Join, Looked = nil, false
	task.spawn(function()
		local Ok, J = pcall(PartyServer, P, RouteId)
		Join, Looked = Ok and J or nil, true
	end)
	local Group, Left = RoadService.Gather(P, RouteId)
	local Token = {}
	local Nonce = HttpService:GenerateGUID(false)
	local Body, Conns = {}, {}
	local Out = Th.CFrame.LookVector
	Out = Vector3.new(Out.X, 0, Out.Z).Unit
	local Dest = RegionName(Travel.Other(RouteId, TravelService.Here()))
	for _, M in ipairs(Group) do
		Crossing[M] = Token
		Body[M] = M.Character
		local H = M.Character:FindFirstChildOfClass("Humanoid")
		if H then table.insert(Conns, H.Died:Connect(function() Cancel(M, Token, DIED) end)) end
		table.insert(Conns, M.CharacterAdded:Connect(function() Cancel(M, Token, DIED) end))
		-- each walks on along the road where they are (a member further back may still be round the bend)
		local R = RootOf(M.Character)
		local Dir = (M ~= P and R and RoadDir(R.Position, RouteId)) or Out
		Send(M, "Crossing", {Route = RouteId, Dest = Dest, Dir = Dir, Delay = RoadService.CrossDelay})
	end
	for _, L in ipairs(Left) do -- the rest of the party: they can follow, and will be sent after them (best effort)
		Ahead[L[1]] = {UserId = P.UserId, Route = RouteId, Until = os.clock() + RoadService.StragglerTTL, Nonce = Nonce}
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
	local T0 = os.clock()
	while not Looked and os.clock() - T0 < RoadService.JoinWait do task.wait(0.05) end
	for _, M in ipairs(Still) do
		Ahead[M] = nil
		if Rolled[M] then Rolled[M][RouteId] = nil end -- the next walk is a new crossing
	end
	local Ok, Mode, Went = pcall(TravelService.Depart, Still, RouteId, "RoadStart", {Join = Join, Nonce = Nonce})
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
		local Deadline = RoadService.HoldDeadline * (Join and RoadService.JoinDeadline or 1) -- a party's server: room for its fallback
		task.delay(Deadline, function()
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
local function AtThreshold(P, Th, Passages)
	local RouteId = Th:GetAttribute("Route")
	if not Leaves(RouteId) or Crossing[P] or Rearm[P] then return end
	if ArrivedAt[P] and os.clock() - ArrivedAt[P] < RoadService.ArriveGuard then return end
	local Leg = Walking(P, RouteId)
	if not Leg or Leg < LastLeg(RouteId, Passages) then return end -- only by walking the road (no teleporting in)
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

-- someone at Pos in encounter E is walking out (came in at its town end), else in
local function WalkingOut(E, Pos) return E.CFrame:PointToObjectSpace(Pos).Z > 0 end

-- spawn the encounter's bandits at its SpawnPoints on the side ahead of Pos. Returns how many came out.
local function Ambush(E, Pos, Size, MaxWanted)
	if Active[E] then return 0 end -- already out
	local Side = WalkingOut(E, Pos) and "Out" or "In"
	local Points = {}
	for _, A in ipairs(E:GetChildren()) do
		if A:IsA("Attachment") and A.Name == "SpawnPoint" and A:GetAttribute("Side") == Side then table.insert(Points, A) end
	end
	if #Points == 0 then return 0 end
	local EnemyService = require(ServerScriptService.EnemyService)
	local N = 2 + (Size > 2 and 1 or 0) -- world spec: 2-3
	local Mine = {Enemies = {}, Near = os.clock()}
	Active[E] = Mine
	for I = 1, N do
		local A = Points[(I - 1) % #Points + 1]
		local Kind = (MaxWanted >= 1 and I == 1) and "Elite" or "Grunt" -- Elite = "Bandit Duelist", Grunt = "Bandit"
		-- an unparented spawn part: EnemyService only respawns from a part that still has a parent (it is also the
		-- rig's home for EnemyService's own leash)
		local Mark = Instance.new("Part")
		Mark.Anchored, Mark.CanCollide, Mark.Transparency = true, false, 1
		Mark.CFrame = A.WorldCFrame * CFrame.new(((I - 1) // #Points) * 4, 0, 0) -- a third one stands beside the first
		Mark:SetAttribute("EnemyType", Kind)
		local Ok, Rig = pcall(EnemyService.Spawn, Mark)
		if Ok and typeof(Rig) == "Instance" then
			local Home = Rig:GetPivot()
			-- fix round 2: the encounter's range from this home (to its box's furthest corner, plus Leash), for
			-- PerceptionService.Lose
			local Range = 0
			for _, SX in ipairs({-1, 1}) do
				for _, SZ in ipairs({-1, 1}) do
					local Corner = E.CFrame:PointToWorldSpace(Vector3.new(SX * E.Size.X / 2, 0, SZ * E.Size.Z / 2))
					Range = math.max(Range, Vector3.new(Corner.X - Home.X, 0, Corner.Z - Home.Z).Magnitude)
				end
			end
			table.insert(Mine.Enemies, {Rig = Rig, Home = Home, Range = Range + RoadService.Leash})
		else
			warn("[RoadService] road bandit " .. I .. " failed to spawn: " .. tostring(Rig))
		end
	end
	if #Mine.Enemies == 0 then Active[E] = nil end
	return #Mine.Enemies
end

local function Spring(E, Pos, Members, Roll) -- the ambush comes out at E
	local N = Ambush(E, Pos, #Members, Roll.MaxWanted)
	if N > 0 then
		for _, M in ipairs(Members) do
			local R = M.Parent and RootOf(M.Character)
			if R and PassageAt(R.Position) == E:GetAttribute("Route") then Notify(M, "Bandits on the road ahead!") end
		end
	end
end

-- P walked into encounter E: the crossing's one roll for this passage, and the ambush where it falls
local function AtEncounter(P, E, RouteId, Pos, Encounters)
	local Members = MembersOf(P)
	local Roll = RollOf(P, RouteId)
	if Roll then
		if Roll.Pending == E then -- the ambush that was waiting further along the road
			Roll.Pending = nil
			Spring(E, Pos, Members, Roll)
		end
		return
	end
	if RunService:IsStudio() and RoadService.Calm and RoadService.Force == nil then return end
	local MaxWanted = 0
	for _, M in ipairs(Members) do MaxWanted = math.max(MaxWanted, Wanted(M)) end
	Roll = {Seen = os.clock(), MaxWanted = MaxWanted}
	for _, M in ipairs(Members) do -- one roll for the whole party on this crossing
		Rolled[M] = Rolled[M] or {}
		Rolled[M][RouteId] = Roll
	end
	Rolled[P] = Rolled[P] or {}
	Rolled[P][RouteId] = Roll
	local Hit
	if RunService:IsStudio() and RoadService.Force ~= nil then
		Hit = RoadService.Force
		RoadService.Force = nil
	else
		Hit = math.random() < RoadService.Chance(MaxWanted)
	end
	if not Hit then return end
	-- controller's ruling: the ambush is at a random encounter still ahead of them, this one included
	local Order, Out = tonumber(E:GetAttribute("Order")) or 1, WalkingOut(E, Pos)
	local Later = {}
	for _, X in ipairs(Encounters) do
		local O = tonumber(X:GetAttribute("Order")) or 1
		if X:GetAttribute("Route") == RouteId and ((Out and O >= Order) or (not Out and O <= Order)) then table.insert(Later, X) end
	end
	local At = #Later > 0 and Later[math.random(1, #Later)] or E
	if RunService:IsStudio() and RoadService.ForceAt then -- Studio tests: where it falls
		At = RoadService.ForceAt
		RoadService.ForceAt = nil
	end
	if At == E then Spring(E, Pos, Members, Roll) else Roll.Pending = At end
end

-- the bandits keep to their stretch; remove them once nobody has been near for ClearAfter s
local function WatchEncounters(Roots)
	local Now = os.clock()
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
					local H = E.Size / 2
					local Past = math.max(math.abs(L.X) - H.X, math.abs(L.Y) - H.Y, math.abs(L.Z) - H.Z)
					local PerceptionService = require(ServerScriptService.PerceptionService)
					if Past > RoadService.Overshoot or not E.Parent then -- flung or fallen far: home at once (the backstop)
						R.AssemblyLinearVelocity = Vector3.zero
						En.Rig:PivotTo(En.Home)
						if PerceptionService.Tracks(En.Rig) then PerceptionService.Lose(En.Rig, En.Home.Position, En.Range) end
					elseif Past > RoadService.Leash then
						-- strayed (fix round 2): its AI gives up the chase and walks home by itself (a MoveTo home
						-- from here lost to the chase AI's own MoveTo every 0.1 s); an enemy the perception doesn't
						-- track (none on the road today) is still walked home from here
						if PerceptionService.Tracks(En.Rig) then
							PerceptionService.Lose(En.Rig, En.Home.Position, En.Range)
						else
							local Hum = En.Rig:FindFirstChildOfClass("Humanoid")
							if Hum then Hum:MoveTo(En.Home.Position) end
						end
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
RoadService.ForceAt = nil -- Studio tests only: the encounter a forced hit falls at
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
function RoadService.ResetRolls(P)
	for _, M in ipairs(MembersOf(P)) do Rolled[M] = nil end
	Rolled[P] = nil
end
function RoadService.Pending(P, RouteId) local R = RollOf(P, RouteId) return R and R.Pending end

-- ===== The watch: every Tick, each player's walk, encounter and threshold =====
local function TickAll()
	local Now = os.clock()
	local Passages, Thresholds, Encounters = Tagged("RenseiRoadPassage"), Tagged("RenseiRoadThreshold"), Tagged("RenseiRoadEncounter")
	local Roots = {}
	for _, P in ipairs(Players:GetPlayers()) do
		local R = RootOf(P.Character)
		if R then
			table.insert(Roots, R.Position)
			local RouteId = Walk(P, R.Position, Now, Passages)
			if RouteId then
				for _, M in ipairs(MembersOf(P)) do
					if Rolled[M] and Rolled[M][RouteId] then Rolled[M][RouteId].Seen = Now end
				end
				for _, E in ipairs(Encounters) do
					if E:GetAttribute("Route") == RouteId and Inside(E, R.Position) then AtEncounter(P, E, RouteId, R.Position, Encounters) end
				end
			end
			local InTh
			for _, Th in ipairs(Thresholds) do
				if Inside(Th, R.Position) then InTh = Th break end
			end
			if Rearm[P] and (not InTh or Now - Rearm[P] >= RoadService.RearmTime) then Rearm[P] = nil end
			if InTh and not Crossing[P] then AtThreshold(P, InTh, Passages) end
		else
			Track[P] = nil
		end
	end
	-- a party off the passage for RollReset s starts a new crossing next time
	for K, Routes in pairs(Rolled) do
		for RouteId, V in pairs(Routes) do
			if Now - V.Seen > RoadService.RollReset then Routes[RouteId] = nil end
		end
		if next(Routes) == nil then Rolled[K] = nil end
	end
	WatchEncounters(Roots)
end

function RoadService.Start()
	Event = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TravelEvent", 30)
	-- arrival by road: set down side by side, walk in from RoadStart (the Studio loopback too); share this server with
	-- the party's stragglers
	TravelService.Arrived.Event:Connect(function(P, Region, RouteId)
		local R = RouteId and Travel.Routes[RouteId]
		if not (R and R.Kind == "Road") then return end
		Crossing[P] = nil
		Rearm[P] = nil
		local Now = os.clock()
		ArrivedAt[P] = Now
		local At = TravelService.ArrivalPoint("RoadStart")
		local In = At and At.CFrame.LookVector or Vector3.new(0, 0, -1)
		In = Vector3.new(In.X, 0, In.Z).Unit
		local C = P.Character
		local Root = RootOf(C)
		if At and Root then
			local A = Arrivals[RouteId]
			if not A or Now - A.T > 3 then A = {N = 0} end -- PROPOSAL: arrivals within 3 s of each other are one group
			A.N += 1
			A.T = Now
			Arrivals[RouteId] = A
			local K = A.N - 1 -- 0, then +1, -1, +2, -2: side by side across the road
			local Off = (K % 2 == 1 and 1 or -1) * math.ceil(K / 2) * RoadService.ArriveSpread
			if Off ~= 0 then C:PivotTo(C:GetPivot() + At.CFrame.RightVector * Off) Rebased(C) end
			local Dir = RoadDir(Root.Position, RouteId)
			if Dir then In = -Dir end
			-- arriving counts as having walked in: the track starts at the furthest leg RoadStart is in
			local _, Legs = LegsAt(At.Position)
			local Leg = 1
			for L in pairs(Legs) do Leg = math.max(Leg, L) end
			Track[P] = {Route = RouteId, Leg = Leg, LastPos = Root.Position, LastT = Now}
		end
		Send(P, "CrossingIn", {Route = RouteId, Dir = In, From = RegionName(Travel.Other(RouteId, Region))})
		ShareServer(P, RouteId)
	end)
	Players.PlayerRemoving:Connect(function(P)
		Crossing[P], Track[P], Rearm[P], ArrivedAt[P], Ahead[P], LastToast[P], Rolled[P] = nil, nil, nil, nil, nil, nil, nil
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

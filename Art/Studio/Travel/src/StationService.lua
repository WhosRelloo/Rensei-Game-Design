-- StationService (World plan 1, 2026-10-20; world spec §2, §4): the railway in this region.
--   * Ticket clerk (RenseiTicketClerk): Buy(Route, Class[, party member]) charges ProgressionService.SpendMoney.
--     Only lines with a RenseiPlatformTrain in this place are sold. The remote also checks the buyer is at a clerk.
--   * Departures run on the shared clock (Travel.NextDeparture on os.time()), so every server agrees.
--   * Boarding: from Travel.BoardingWindow seconds before departure, a player with a ticket standing inside a car of
--     the platform train (a BoardZone is inside its car) is aboard and is told so ("Board"); the conductor pushes back
--     anyone at a CarDoor whose class doesn't reach that car, and tells them why. The barrier is re-checked on the
--     server when everyone moves: a rider in a car their class doesn't reach (or in the locomotive / tender) rides in
--     the nearest car they may use; anyone no longer in the train after the fade stays behind with the ticket.
--   * At departure: a "doors closing" fade, everyone aboard moves to the same spot in the ride train (seated players
--     to the same seat), the ride runs Route.Ride seconds (events from Task 7 hook Departing), then
--     TravelService.Depart sends them all together. Anyone who can't go (already teleporting, or dropped by Depart)
--     is put back on this platform with the ticket kept. A rider who dies aboard (or whose character is replaced)
--     is off the ride, ticket kept; only the character that boarded is ever moved back into the train.
--   * Seats (owner, 2026-10-21: "the OPTION to sit on them with a prompt on each seat"): every Seat in a platform or
--     ride train has CanTouch off, so brushing past doesn't sit you, and a "Sit" ProximityPrompt (Custom style, drawn
--     by PromptUI; OnePerButton, so only the nearest shows), hidden while the seat is taken. The server checks the
--     seat is free, the sitter is alive, not down / gripped / carried, within reach, and that their ticket reaches
--     the seat's car, then Seat:Sit. Standing up is the normal jump. Fix round 1: the sitter must be inside the
--     seat's car (no sitting through the wall from the platform) and the prompt needs line of sight; a stale
--     occupant (dead, or gone) doesn't block the seat; anyone who ends up seated where their ticket doesn't reach
--     is stood up; nobody sits down while being moved (the departure fade, the end-of-ride stand-up).
--   * Papers check (Task 9, world spec §4): the State gate (a part tagged RenseiStationGate, between the ticket hall
--     and the platform, beside its guard) reads the State Wanted level (Travel.Gate). Wanted 0 walks through. Wanted
--     1-2 is pushed back and offered a bribe (2x the 3rd-class price) or a search (no contraband exists yet, so it
--     only clears you); either clears the gate for 10 minutes. Wanted 3+ is pushed back, refused with the guard's line
--     and +10 State Heat ("resisting a checkpoint"; no arrest system yet). Walking off the platform is never stopped.
--   * Stowaways (Task 9): someone without a ticket hidden in the baggage car's StowZone is aboard as a stowaway
--     (Aboard's second result, a set; Departing's 4th argument, a list). They ride in the baggage car (the conductor's barrier keeps
--     them out of the coaches) and arrive with nothing to use up. A rider the ticket inspection marks ThrownOff (no
--     ticket, no money for the fine) is put back on this platform at the ride's end instead of arriving.
--   * The freight yard (Task 9): a part tagged RenseiFreightYard covers it; the RenseiWatcher watchmen in the same model
--     watch it with PerceptionService's sight (cones, light, crouching). A watchman noticing a player there
--     (awareness >= Perception.Suspicious) raises State Heat +5, once per visit. He is anchored: a sound (footsteps)
--     turns him on the spot towards it (fix round 1), so a noisy player behind him gets seen.
--   * Fix round 1: the papers check is also enforced at boarding (Aboard): a ticket holder without papers in order is
--     not boarded ("Papers first"), unless hidden in the StowZone, where they ride as a stowaway.
-- Every number is a PROPOSAL.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local Travel = require(ReplicatedStorage.Modules.Data.Rensei.Travel)
local Places = require(ReplicatedStorage.Modules.Data.Rensei.Places)
local TravelService = require(ServerScriptService.TravelService)
local ProgressionService = require(ServerScriptService.ProgressionService)
local UIService = require(ServerScriptService.UIService)
local PartyService = require(ServerScriptService.PartyService)
local FlowTeleport = require(ServerScriptService.FlowTeleport)

local StationService = {}
StationService.Departing = Instance.new("BindableEvent") -- (RouteId, {Player}, RideSeconds, {stowaway Player})
StationService.Season = function() return "Summer" end -- the seasons plan replaces this
StationService.FadeTime = 0.6 -- PROPOSAL: the client's "doors closing" fade before everyone moves
StationService.ClerkReach = 14 -- PROPOSAL: studs from a ticket clerk a Buy request may come from (the prompt reaches 10)
StationService.CarHalfWidth = 5.6 -- PROPOSAL: inside a car = within this of its centre line (the body is about 11.4 wide)
StationService.DoorPush = 4 -- PROPOSAL: studs the conductor pushes someone back from a CarDoor
StationService.FallCatch = 20 -- PROPOSAL: a rider this far below the ride train is put back in their spot
StationService.UnseatSettle = 0.3 -- PROPOSAL: seconds after standing a rider up before moving them (the client
                                  -- owns the character; moved in the same frame, it can stay where the seat was)
StationService.Stale = 5 -- PROPOSAL: a departure slot noticed up to this many seconds late (a server hitch) still departs
StationService.AskGap = 0.25 -- PROPOSAL: seconds between a player's requests on the Travel remote
StationService.HoldClock = false -- Studio tests only: true stops scheduled departures (a live server ignores it)
StationService.SeatReach = 5 -- the Sit prompt's reach (owner brief, 2026-10-21)
StationService.SitReach = 7 -- PROPOSAL: studs from a seat a Sit request may come from (the prompt reaches 5; lag slack)
StationService.SitGap = 0.5 -- PROPOSAL: seconds between a player's Sit requests
StationService.SitPointLift = 1.5 -- PROPOSAL: the prompt sits this far above the cushion, so line of sight isn't
                                  -- blocked by the seat's own back or a table (dining-car chairs hid it otherwise)
-- Task 9: the papers check, stowaways and the freight yard
StationService.GateClearFor = 600 -- brief: a paid bribe or a search clears the gate for 10 minutes
StationService.GateReach = 16 -- PROPOSAL: studs from a gate a Bribe / Search request may come from
StationService.GatePush = 4 -- PROPOSAL: studs the guard pushes someone back from the gate (as the conductor's DoorPush)
StationService.GateAskGap = 3 -- PROPOSAL: seconds between the guard's offers / refusals to one player (touches repeat)
StationService.RefuseHeat = 10 -- brief ruling: Wanted 3+ at the gate, "resisting a checkpoint"
StationService.RefuseHeatGap = 30 -- PROPOSAL: a refusal raises Heat at most once per 30 s per player
StationService.YardHeat = 5 -- PROPOSAL (controller ruling): a yard watchman notices you in the freight yard
StationService.YardHeatGap = 60 -- PROPOSAL: and at most once a minute, even over several short visits
StationService.YardTick = 0.25 -- PROPOSAL: seconds between freight-yard checks
StationService.StowNagGap = 3 -- PROPOSAL: seconds between "stay with the baggage" lines to a stowaway
StationService.WatchTurn = 45 -- PROPOSAL: degrees a yard watchman turns per yard check (180 a second) towards a sound
local PAPERS_FIRST = "Conductor: \"Papers first — see the gate guard.\"" -- fix round 1 ruling
local GATE_REFUSED = "Guard: \"Your face is on a poster. Not on my platform.\"" -- brief

local Remote, Event
local Riding = {} -- [Player] = RouteId
local Boxes = {} -- [car Model] = {CF, Size}; the trains are anchored and never move
local Kinds = {} -- [car Model] = CarKind (read from its BoardZone / CarDoor parts) or false (locomotive, tender)
local Zones = {} -- [train Model] = {BoardZone parts}
local Told = {} -- [Player] = "Route|departure" we last sent "Board" for
local LastPush, LastAsk, LastSit = {}, {}, {}
local NoSit = {} -- [Player] = true while being moved: from the departure fade to the move, and from the end-of-ride
                 -- stand-up until Riding is cleared
local LastGate, LastRefuseHeat = {}, {} -- [Player] = os.clock() of the guard's last offer / refusal Heat
local YardVisit, LastYardHeat = {}, {} -- [Player] = the yard part they're in (false once seen there) / os.clock()
local Stows = setmetatable({}, {__mode = "k"}) -- [train Model] = {StowZone parts}
local LastPapers = {} -- [Player] = os.clock() of the conductor's last "papers first"
local YardHome = setmetatable({}, {__mode = "k"}) -- [watchman Model] = the CFrame he was placed at (his post)
local SeatTrains = setmetatable({}, {__mode = "k"}) -- [train Model or Seat] = true once set up
local SEAT_TEXT = {ThirdClass = "3rd class", DiningCar = "Dining car", SecondClass = "2nd class", CabinCar = "Private cabin"}
local DOWN = {"Knocked", "GrippedBy", "CarriedBy", "Gripping", "Carrying"} -- character attributes: can't sit down

local function Notify(P, Text) UIService.Notify(P, "Toast", {Text = Text}) end

local function Level(P)
	local D = ProgressionService.GetData(P)
	return D and D.Level or 1
end

local function FindPlayer(From, UserId)
	local Party = PartyService.Get(From)
	if not Party or type(UserId) ~= "number" then return nil end
	for _, M in ipairs(Party.Members) do
		if M.UserId == UserId then return M end -- by UserId: names and display names can be duplicated or changed
	end
	return nil
end

local function TrainOf(Tag, RouteId)
	for _, T in ipairs(CollectionService:GetTagged(Tag)) do
		if T:GetAttribute("Route") == RouteId and T:IsDescendantOf(workspace) then return T end
	end
	return nil
end

-- the rail lines that run from this place (a platform train is here)
local function Lines()
	local Out = {}
	for _, RouteId in ipairs(Travel.RoutesFrom(TravelService.Here(), "Rail")) do
		if TrainOf("RenseiPlatformTrain", RouteId) then table.insert(Out, RouteId) end
	end
	return Out
end

-- ForUserId: buy for a party member (their UserId) instead of yourself
function StationService.Buy(Player, RouteId, ClassId, ForUserId)
	local R = type(RouteId) == "string" and Travel.Routes[RouteId]
	if not R or R.Kind ~= "Rail" or type(ClassId) ~= "string" or not Travel.Classes[ClassId] then return false, "No such ticket." end
	if not Travel.Other(RouteId, TravelService.Here()) then return false, "That train doesn't stop here." end
	if not TrainOf("RenseiPlatformTrain", RouteId) then return false, "That line isn't running yet." end
	local Rider = Player
	if ForUserId and ForUserId ~= Player.UserId then
		Rider = FindPlayer(Player, ForUserId)
		if not Rider then return false, "They aren't in your party." end
	end
	-- Task 10 fix 1: the rider's save must be loaded before anyone pays (AddTicket can't issue a ticket without it)
	if not ProgressionService.GetData(Rider) then return false, "The clerk can't issue their ticket right now." end
	local Ok, Why = Travel.CanTake(Level(Rider), RouteId)
	if not Ok then return false, Why end
	local Price = Travel.Price(RouteId, ClassId, StationService.Season())
	if not ProgressionService.SpendMoney(Player, Price) then return false, ("A ticket costs $%d."):format(Price) end
	if not TravelService.AddTicket(Rider, RouteId, ClassId) then -- the save went away meanwhile: give the money back
		ProgressionService.GrantMoney(Player, Price)
		return false, "The clerk can't issue that ticket right now."
	end
	if Rider ~= Player then Notify(Rider, Player.DisplayName .. " bought you a ticket.") end
	return true
end

function StationService.CanEnter(Player, RouteId, CarKind)
	local C = TravelService.HasTicket(Player, RouteId)
	return C ~= nil and Travel.ClassReaches(C, CarKind)
end

local function CarBox(Car)
	local B = Boxes[Car]
	if not B then
		local CF, Size = Car:GetBoundingBox() -- oriented by the car's pivot: X along the car, Z across
		B = {CF = CF, Size = Size}
		Boxes[Car] = B
	end
	return B
end

-- the car of the train Pos is inside (not just the train's overall box, which reaches over the platform edge), or nil
local function InTrain(Train, Pos)
	for _, Car in ipairs(Train:GetChildren()) do
		if Car:IsA("Model") then
			local B = CarBox(Car)
			local L = B.CF:PointToObjectSpace(Pos)
			if math.abs(L.X) <= B.Size.X / 2 and math.abs(L.Y) <= B.Size.Y / 2
				and math.abs(L.Z) <= math.min(B.Size.Z / 2, StationService.CarHalfWidth) then
				return Car
			end
		end
	end
	return nil
end
StationService.CarAt = InTrain

-- a car's kind, from any part in it carrying CarKind (its BoardZones and CarDoors); nil for the locomotive and tender
local function CarKind(Car)
	local K = Kinds[Car]
	if K == nil then
		K = false
		for _, D in ipairs(Car:GetDescendants()) do
			if D:GetAttribute("CarKind") then K = D:GetAttribute("CarKind") break end
		end
		Kinds[Car] = K
	end
	return K or nil
end
StationService.CarKind = CarKind

local function ZonesOf(Train)
	local Z = Zones[Train]
	if not Z then
		Z = {}
		for _, D in ipairs(Train:GetDescendants()) do
			if D:IsA("BasePart") and D.Name:find("BoardZone") and D:GetAttribute("CarKind") then table.insert(Z, D) end
		end
		Zones[Train] = Z
	end
	return Z
end

local function InPart(Part, Pos)
	local L = Part.CFrame:PointToObjectSpace(Pos)
	return math.abs(L.X) <= Part.Size.X / 2 and math.abs(L.Y) <= Part.Size.Y / 2 and math.abs(L.Z) <= Part.Size.Z / 2
end

-- where a rider may stand: nil if Pos is fine (a car their class reaches, or a vestibule BoardZone of the car they're
-- in), else the nearest BoardZone of Train that their class reaches, or NOWHERE if there is none (fail closed)
local NOWHERE = {}
local function AllowedSpot(P, RouteId, Train, Car, Pos)
	local Kind = CarKind(Car)
	if Kind and StationService.CanEnter(P, RouteId, Kind) then return nil end
	for _, Z in ipairs(ZonesOf(Train)) do
		if Z:IsDescendantOf(Car) and InPart(Z, Pos) then return nil end
	end
	local Best, BestD
	for _, Z in ipairs(ZonesOf(Train)) do
		if StationService.CanEnter(P, RouteId, Z:GetAttribute("CarKind")) then
			local D = (Z.Position - Pos).Magnitude
			if not BestD or D < BestD then Best, BestD = Z, D end
		end
	end
	return Best or NOWHERE
end

-- the baggage car's StowZones of a train (Task 9)
local function StowsOf(Train)
	local Z = Stows[Train]
	if not Z then
		Z = {}
		for _, D in ipairs(Train:GetDescendants()) do
			if D:IsA("BasePart") and D.Name:find("StowZone") then table.insert(Z, D) end
		end
		Stows[Train] = Z
	end
	return Z
end

-- hidden in a StowZone of this platform train (2 studs of slack on Y: a crouch or a jump still counts)
local function InStowZone(P, Train)
	local Root = P.Character and P.Character:FindFirstChild("HumanoidRootPart")
	if not (Root and Train) then return false end
	for _, Z in ipairs(StowsOf(Train)) do
		local L = Z.CFrame:PointToObjectSpace(Root.Position)
		if math.abs(L.X) <= Z.Size.X / 2 and math.abs(L.Y) <= Z.Size.Y / 2 + 2 and math.abs(L.Z) <= Z.Size.Z / 2 then return true end
	end
	return false
end

-- the papers check passed: Wanted 0, or Wanted 1-2 with the gate cleared (a bribe or a search in the last 10 min)
local function PapersOk(P)
	local Verdict = StationService.Gate(P)
	return Verdict == "Pass" or (Verdict == "Bribe" and StationService.Cleared(P))
end

-- who departs: ticket holders inside a car whose papers are in order, and (Task 9) anyone hidden in the baggage car's
-- StowZone without a ticket, or (fix round 1) with a ticket but without papers. Returns the list and the stowaway set
-- {[Player] = true}. A ticket holder aboard without papers is left out and told to see the gate guard: the papers
-- check is enforced here, at boarding, as well as at the gate.
function StationService.Aboard(RouteId)
	local Train = TrainOf("RenseiPlatformTrain", RouteId)
	local Out, Stow = {}, {}
	if not Train then return Out, Stow end
	for _, P in ipairs(Players:GetPlayers()) do
		local Root = P.Character and P.Character:FindFirstChild("HumanoidRootPart")
		if Root and not Riding[P] then
			local Has = TravelService.HasTicket(P, RouteId)
			local Papers = Has and PapersOk(P)
			if not Papers and InStowZone(P, Train) then
				table.insert(Out, P)
				Stow[P] = true
			elseif Has and InTrain(Train, Root.Position) ~= nil then
				if Papers then
					table.insert(Out, P)
				else
					local Now = os.clock()
					if not LastPapers[P] or Now - LastPapers[P] >= StationService.GateAskGap then
						LastPapers[P] = Now
						Notify(P, PAPERS_FIRST)
					end
				end
			end
		end
	end
	return Out, Stow
end

-- ===== the papers check (Task 9) =====
local function StateWanted(P)
	local Ok, W = pcall(function() return require(ServerScriptService.HeatService).Wanted(P, "State") end)
	return Ok and type(W) == "number" and W or 0
end

function StationService.Gate(Player)
	return Travel.Gate(StateWanted(Player))
end

-- the line a gate's bribe is priced on: the gate's Route attribute if it runs from here, else the cheapest line here
local function GateRoute(Gate)
	local Here = Lines()
	local Want = Gate and Gate:GetAttribute("Route")
	if Want and table.find(Here, Want) then return Want end
	local Best, BestP
	for _, RouteId in ipairs(Here) do
		local P = Travel.Price(RouteId, "Third", StationService.Season())
		if not BestP or P < BestP then Best, BestP = RouteId, P end
	end
	return Best
end

local function Cleared(P)
	local At = P:GetAttribute("GateCleared")
	return type(At) == "number" and os.time() - At < StationService.GateClearFor
end
StationService.Cleared = Cleared

-- 2x the 3rd-class price of a line that runs from here; false if it's no such line or they can't pay
function StationService.PayBribe(Player, RouteId)
	if type(RouteId) ~= "string" or not table.find(Lines(), RouteId) then return false end
	local Cost = Travel.Bribe(RouteId, "Third", StationService.Season())
	if Cost <= 0 or not ProgressionService.SpendMoney(Player, Cost) then return false end
	Player:SetAttribute("GateCleared", os.time())
	return true
end

-- the search: there's no contraband yet, so it only clears the gate (a later plan takes illegal items here)
function StationService.Search(Player)
	Player:SetAttribute("GateCleared", os.time())
	return true
end

local function NearGate(P)
	local Root = P.Character and P.Character:FindFirstChild("HumanoidRootPart")
	if not Root then return nil end
	for _, G in ipairs(CollectionService:GetTagged("RenseiStationGate")) do
		if G:IsA("BasePart") and G:IsDescendantOf(workspace) and (G.Position - Root.Position).Magnitude <= StationService.GateReach then return G end
	end
	return nil
end

-- someone touched the gate (the part's LookVector points onto the platform). Returns the verdict it acted on.
function StationService.GateTouch(P, Gate)
	local Root = P.Character and P.Character:FindFirstChild("HumanoidRootPart")
	if not Root then return nil end
	local Verdict = StationService.Gate(P)
	if Verdict == "Pass" or (Verdict == "Bribe" and Cleared(P)) then return "Pass" end
	local N = Gate.CFrame.LookVector
	if Root.AssemblyLinearVelocity:Dot(N) < -1 then return "Leaving" end -- walking off the platform: never stopped
	-- back to the hall side, GatePush clear of the gate
	local Side = (Root.Position - Gate.Position):Dot(N)
	Root.CFrame += N * -(Side + Gate.Size.Z / 2 + StationService.GatePush)
	Root.AssemblyLinearVelocity = Vector3.zero
	local Now = os.clock()
	if LastGate[P] and Now - LastGate[P] < StationService.GateAskGap then return Verdict end
	LastGate[P] = Now
	if Verdict == "Bribe" then
		local RouteId = GateRoute(Gate)
		local Cost = RouteId and Travel.Bribe(RouteId, "Third", StationService.Season()) or 0
		if Event then Event:FireClient(P, "GateBribe", {Route = RouteId, Cost = Cost}) end
	else
		if not LastRefuseHeat[P] or Now - LastRefuseHeat[P] >= StationService.RefuseHeatGap then
			LastRefuseHeat[P] = Now
			local Ok, Err = pcall(function() require(ServerScriptService.HeatService).Add(P, "State", StationService.RefuseHeat, TravelService.Here()) end)
			if not Ok then warn("[StationService] gate Heat failed: " .. tostring(Err)) end
		end
		Notify(P, GATE_REFUSED)
	end
	return Verdict
end

local function GuardGate(Gate)
	if not Gate:IsA("BasePart") or Gate:GetAttribute("GateWired") then return end
	Gate:SetAttribute("GateWired", true)
	Gate.Touched:Connect(function(Hit)
		local P = Hit.Parent and Players:GetPlayerFromCharacter(Hit.Parent)
		if P then StationService.GateTouch(P, Gate) end
	end)
end

-- ===== the freight yard (Task 9): a yard watchman who notices you there raises State Heat =====
local function YardWatchers(Yard)
	local Out = {}
	local Home = Yard.Parent
	for _, M in ipairs(CollectionService:GetTagged("RenseiWatcher")) do
		if M:IsA("Model") and Home and M:IsDescendantOf(Home) then table.insert(Out, M) end
	end
	return Out
end

-- (fix round 1) footsteps count: the watchmen are anchored, so PerceptionService's "go and look" can't walk them.
-- Instead one who heard (or half-saw) something turns on the spot towards it (PerceptionService.Goal: the spot it is
-- investigating), WatchTurn degrees a check; calm again (no goal), he turns back to his post's facing. Rotation only.
local function Turn(W, PS)
	local Root = W:FindFirstChild("HumanoidRootPart")
	if not Root then return end
	local Home = YardHome[W]
	if not Home then
		Home = W:GetPivot()
		YardHome[W] = Home
	end
	local Goal = PS.Goal(W)
	local Pos = W:GetPivot().Position
	local Want
	if typeof(Goal) == "Vector3" and (Vector3.new(Goal.X, 0, Goal.Z) - Vector3.new(Pos.X, 0, Pos.Z)).Magnitude > 0.5 then
		Want = Vector3.new(Goal.X - Pos.X, 0, Goal.Z - Pos.Z).Unit
	else
		Want = Home.LookVector * Vector3.new(1, 0, 1)
		if Want.Magnitude < 1e-3 then return end
		Want = Want.Unit
	end
	local Look = W:GetPivot().LookVector * Vector3.new(1, 0, 1)
	if Look.Magnitude < 1e-3 then return end
	Look = Look.Unit
	local Angle = math.atan2(Look:Cross(Want).Y, Look:Dot(Want)) -- signed, about +Y
	if math.abs(Angle) < math.rad(1) then return end
	local Step = math.clamp(Angle, -math.rad(StationService.WatchTurn), math.rad(StationService.WatchTurn))
	W:PivotTo(CFrame.new(Pos) * CFrame.Angles(0, Step, 0) * W:GetPivot().Rotation)
end
function StationService.ResetWatch(W) -- tests: back to his post, at once
	if YardHome[W] then W:PivotTo(YardHome[W]) end
end

-- one pass over every player (the loop runs it every YardTick; the tests call it directly)
function StationService.YardCheck()
	local Yards = CollectionService:GetTagged("RenseiFreightYard")
	if #Yards == 0 then return end
	local OkP, PS = pcall(function() return require(ServerScriptService.PerceptionService) end)
	local Notice = require(ReplicatedStorage.Modules.Data.Rensei.Perception).Suspicious
	if OkP then
		for _, Y in ipairs(Yards) do
			if Y:IsA("BasePart") and Y:IsDescendantOf(workspace) then
				for _, W in ipairs(YardWatchers(Y)) do Turn(W, PS) end
			end
		end
	end
	for _, P in ipairs(Players:GetPlayers()) do
		local Root = P.Character and P.Character:FindFirstChild("HumanoidRootPart")
		local In = nil
		if Root and not Riding[P] then
			for _, Y in ipairs(Yards) do
				if Y:IsA("BasePart") and Y:IsDescendantOf(workspace) and InPart(Y, Root.Position) then In = Y break end
			end
		end
		if not In then
			YardVisit[P] = nil -- the visit is over
		elseif YardVisit[P] ~= false and OkP then
			YardVisit[P] = In
			for _, W in ipairs(YardWatchers(In)) do
				if PS.Awareness(W, P) >= Notice then
					YardVisit[P] = false -- seen: once per visit
					local Now = os.clock()
					if not LastYardHeat[P] or Now - LastYardHeat[P] >= StationService.YardHeatGap then
						LastYardHeat[P] = Now
						local Ok, Err = pcall(function() require(ServerScriptService.HeatService).Add(P, "State", StationService.YardHeat, TravelService.Here()) end)
						if not Ok then warn("[StationService] yard Heat failed: " .. tostring(Err)) end
						Notify(P, "Yard watchman: \"Oi! You there! Off the tracks!\"")
					end
					break
				end
			end
		end
	end
end
function StationService.ResetYard(P) YardVisit[P], LastYardHeat[P] = nil, nil end -- tests
function StationService.ResetGate(P) LastGate[P], LastRefuseHeat[P], LastPapers[P] = nil, nil, nil end -- tests

-- conductor: a CarDoor touched by someone whose class doesn't reach that car pushes them back the way they came
local function Guard(Door)
	Door.Touched:Connect(function(Hit)
		local Char = Hit.Parent
		local P = Char and Players:GetPlayerFromCharacter(Char)
		if not P then return end
		local Car = Door:FindFirstAncestorWhichIsA("Model")
		local Train = Car and Car:FindFirstAncestorWhichIsA("Model")
		local RouteId = Train and Train:GetAttribute("Route")
		if not RouteId then return end
		if StationService.CanEnter(P, RouteId, Door:GetAttribute("CarKind")) then return end
		local Root = Char:FindFirstChild("HumanoidRootPart")
		local Now = os.clock()
		if not Root or (LastPush[P] and Now - LastPush[P] < 0.25) then return end
		LastPush[P] = Now
		local N = Door.CFrame.RightVector -- the door is thin along its X: the way through it
		local V = Root.AssemblyLinearVelocity:Dot(N)
		local Dir = math.abs(V) > 1 and -math.sign(V) or ((Root.Position - Door.Position):Dot(N) >= 0 and 1 or -1)
		Root.CFrame += N * Dir * StationService.DoorPush
		if not P:GetAttribute("ConductorWarned") then
			P:SetAttribute("ConductorWarned", true)
			local Has = TravelService.HasTicket(P, RouteId)
			Notify(P, Has and "Conductor: \"Your ticket isn't for this car.\"" or "Conductor: \"Ticket for this car, please.\"")
			task.delay(2, function() P:SetAttribute("ConductorWarned", nil) end)
		end
	end)
end

-- off an (anchored) train seat: moving a seated character would drag the seat along on its SeatWeld
local function Unseat(P)
	local H = P.Character and P.Character:FindFirstChildOfClass("Humanoid")
	local Seat = H and H.SeatPart
	if not Seat then return nil end
	H.Sit = false
	local W = Seat:FindFirstChild("SeatWeld")
	if W then W:Destroy() end
	return Seat
end

-- the ride-train seat at the same place as a platform-train seat
local function RideSeat(Ride, Offset, Seat)
	local At = (Offset * Seat.CFrame).Position
	for _, S in ipairs(Ride:GetDescendants()) do
		if S:IsA("Seat") and (S.Position - At).Magnitude < 0.2 then return S end
	end
	return nil
end

-- seats you choose to sit in (owner, 2026-10-21)
local function TrainOfSeat(Seat)
	local X = Seat.Parent
	while X and X ~= workspace do
		if CollectionService:HasTag(X, "RenseiPlatformTrain") or CollectionService:HasTag(X, "RenseiRideTrain") then return X end
		X = X.Parent
	end
	return nil
end

local function CarOf(Train, D) -- the train's car (a direct child Model) holding D
	local X = D
	while X and X.Parent ~= Train do X = X.Parent end
	return X
end

local function LowestClass(Kind) -- the cheapest class that reaches a car kind, for the conductor's line
	for _, C in ipairs(Travel.ClassOrder) do
		if Travel.ClassReaches(C, Kind) then return Travel.Classes[C].Name end
	end
	return "ticketed"
end

-- a Sit request (the seat's prompt): every check on the server, then Seat:Sit. Returns ok, why
function StationService.TrySit(P, Seat)
	local Now = os.clock()
	if LastSit[P] and Now - LastSit[P] < StationService.SitGap then return false, "too soon" end
	LastSit[P] = Now
	if NoSit[P] then return false, "moving" end
	if typeof(Seat) ~= "Instance" or not Seat:IsA("Seat") or not Seat:IsDescendantOf(workspace) then return false, "no seat" end
	local O = Seat.Occupant
	if O then
		if O.Health > 0 and O:IsDescendantOf(workspace) then return false, "taken" end
		local W = Seat:FindFirstChild("SeatWeld") -- a stale occupant (dead, or its character gone) doesn't hold the seat
		if W then W:Destroy() end
	end
	local C = P.Character
	local H = C and C:FindFirstChildOfClass("Humanoid")
	local Root = C and C:FindFirstChild("HumanoidRootPart")
	if not (H and Root and H.Health > 0) then return false, "not alive" end
	for _, A in ipairs(DOWN) do
		if C:GetAttribute(A) then return false, "down" end
	end
	if (Root.Position - Seat.Position).Magnitude > StationService.SitReach then return false, "too far" end
	local Train = TrainOfSeat(Seat)
	if Train then
		local Car = CarOf(Train, Seat)
		-- inside the seat's own car: window seats are within reach of the platform edge, through the car wall
		if InTrain(Train, Root.Position) ~= Car then return false, "outside" end
		local Kind = Car and CarKind(Car)
		local RouteId = Train:GetAttribute("Route")
		if not (Kind and RouteId and StationService.CanEnter(P, RouteId, Kind)) then
			Notify(P, ("Conductor: \"That seat's for %s passengers.\""):format(LowestClass(Kind)))
			return false, "class"
		end
	end
	if H.SeatPart then Unseat(P) end -- moving to another seat: off the old one first
	Seat:Sit(H)
	return true
end

-- may P sit in this train seat (their ticket reaches its car)?
local function SeatAllowed(P, Train, Seat)
	local Car = CarOf(Train, Seat)
	local Kind = Car and CarKind(Car)
	local RouteId = Train:GetAttribute("Route")
	return Kind ~= nil and RouteId ~= nil and StationService.CanEnter(P, RouteId, Kind)
end

local function SetUpSeat(Train, Seat)
	if not Seat:IsA("Seat") or SeatTrains[Seat] then return end
	SeatTrains[Seat] = true
	for _, Name in ipairs({"SitPoint", "SitPrompt"}) do -- (a copy of an already set-up train: no handlers)
		local Old = Seat:FindFirstChild(Name)
		if Old then Old:Destroy() end
	end
	Seat.CanTouch = false -- touching no longer sits you; Seat:Sit (the prompt, the ride-train carry-over) still does
	local Car = CarOf(Train, Seat)
	local Prompt = Instance.new("ProximityPrompt")
	Prompt.Name = "SitPrompt"
	Prompt.ActionText = "Sit"
	Prompt.ObjectText = SEAT_TEXT[Car and CarKind(Car) or ""] or "Seat"
	Prompt.KeyboardKeyCode = Enum.KeyCode.E
	Prompt.HoldDuration = 0
	Prompt.MaxActivationDistance = StationService.SeatReach
	Prompt.RequiresLineOfSight = true -- no prompt through the car wall from the platform
	Prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton -- 64 seats a train: only the nearest shows
	Prompt.Style = Enum.ProximityPromptStyle.Custom -- drawn by Modules.UI.PromptUI in the game's own art (owner rule 2026-10-21)
	Prompt.Enabled = Seat.Occupant == nil
	local Point = Instance.new("Attachment") -- the prompt's spot, above the cushion (PromptUI's billboard sits over it)
	Point.Name = "SitPoint"
	Point.Position = Vector3.new(0, Seat.Size.Y / 2 + StationService.SitPointLift, 0)
	Point.Parent = Seat
	Prompt.Parent = Point
	Seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local H = Seat.Occupant
		Prompt.Enabled = H == nil
		-- hardening: every legitimate way in (TrySit, the ride-train carry-over) passes CanEnter; anything else that
		-- seats a player where their ticket doesn't reach is undone
		local P = H and Players:GetPlayerFromCharacter(H.Parent)
		if P and not SeatAllowed(P, Train, Seat) then
			-- after a moment: a weld destroyed before it reaches the client leaves the client-owned humanoid
			-- half-seated (the server's SeatPart never clears); one that has replicated stands them up cleanly
			task.delay(StationService.UnseatSettle, function()
				if Seat.Occupant ~= H then return end
				H.Sit = false
				local W = Seat:FindFirstChild("SeatWeld")
				if W then W:Destroy() end
			end)
		end
	end)
	Prompt.Triggered:Connect(function(P) StationService.TrySit(P, Seat) end)
end

local function SetUpSeats(Train)
	if not Train:IsA("Model") or SeatTrains[Train] then return end
	SeatTrains[Train] = true
	for _, D in ipairs(Train:GetDescendants()) do SetUpSeat(Train, D) end
	Train.DescendantAdded:Connect(function(D) SetUpSeat(Train, D) end)
end

local function Depart(RouteId, RideSeconds)
	local Platform, Ride = TrainOf("RenseiPlatformTrain", RouteId), TrainOf("RenseiRideTrain", RouteId)
	if not (Platform and Ride) then return end
	local List, Stow = StationService.Aboard(RouteId)
	if #List == 0 then return end
	local Offset = Ride:GetPivot() * Platform:GetPivot():Inverse()
	local Was = {} -- [Player] = the platform-train seat they sat in
	for _, P in ipairs(List) do
		Riding[P] = RouteId
		P:SetAttribute("ThrownOff", nil) -- (a stale mark from an earlier ride)
		NoSit[P] = true -- no sitting down from here to the move
		Was[P] = Unseat(P) -- stood up now, moved after the fade
		Event:FireClient(P, "RideStart", {Route = RouteId, Seconds = RideSeconds})
		local C = P.Character
		if C then -- stream the ride train in around them while the screen is black
			local To = (Offset * C:GetPivot()).Position
			task.spawn(function() pcall(P.RequestStreamAroundAsync, P, To, StationService.FadeTime) end)
		end
	end
	task.wait(StationService.FadeTime) -- the client fades to black ("doors closing")
	local Spot = {}
	local Body = {} -- [Player] = the character that boarded (the watchdogs only ever move that one)
	local Moved = {}
	for _, P in ipairs(List) do
		local C = P.Character
		local H = C and C:FindFirstChildOfClass("Humanoid")
		local Root = C and C.Parent and C:FindFirstChild("HumanoidRootPart")
		-- re-check after the fade: anyone who stepped off (or reset) stays behind with the ticket
		local Car = Root and Riding[P] == RouteId and InTrain(Platform, Root.Position)
		-- the class barrier, checked on the server: someone in a car their class doesn't reach (a teleported client
		-- never touches a CarDoor), or in the locomotive / tender, rides in the nearest car they may use; if no car on
		-- this train takes their ticket, they stay behind like someone who stepped off
		local Zone = nil
		if Stow[P] then
			-- a stowaway rides only if still hidden in the baggage car (no ticket reaches any other car)
			if not (Car and InStowZone(P, Platform)) then Car = nil end
		else
			Zone = Car and AllowedSpot(P, RouteId, Platform, Car, Root.Position)
			if Zone == NOWHERE then Car = nil end
		end
		if Car then
			local Seat = Unseat(P) or Was[P] -- (sat down again during the fade?)
			-- only a seat in the car that was just checked (Was[P] is from before the fade, maybe another car)
			local To = not Zone and Seat and Seat:IsDescendantOf(Car) and RideSeat(Ride, Offset, Seat)
			Spot[P] = Offset * (Zone and Zone.CFrame or C:GetPivot())
			C:PivotTo(Spot[P])
			Body[P] = C
			if To then task.defer(function() if not To.Occupant and H.Parent then To:Sit(H) end end) end
			table.insert(Moved, P)
		elseif Riding[P] == RouteId then
			Riding[P] = nil
			local Text = Stow[P] and "The train left without you." or "The train left without you. Your ticket is still good."
			if P.Parent then Event:FireClient(P, "RideCancel", {Route = RouteId, Text = Text}) end
		end
	end
	for _, P in ipairs(List) do NoSit[P] = nil end -- moved (or left behind): seats are open to them again
	List = Moved
	if #List == 0 then return end
	-- death aboard (controller ruling, 2026-10-21): a rider whose humanoid dies or whose character is replaced
	-- (respawned in town) is off the ride, keeping the ticket; nobody pulls the new character back into the train
	local Conns = {}
	local function Off(P)
		if Riding[P] ~= RouteId or not Body[P] then return end
		Riding[P], Spot[P], Was[P], Body[P] = nil, nil, nil, nil
		P:SetAttribute("ThrownOff", nil) -- (off the ride already: nothing left to throw them off)
		local Text = Stow[P] and "You came to back in town." or "You came to back in town. Your ticket is still good."
		if P.Parent then Event:FireClient(P, "RideCancel", {Route = RouteId, Text = Text}) end
	end
	for _, P in ipairs(List) do
		local H = Body[P]:FindFirstChildOfClass("Humanoid")
		if H then table.insert(Conns, H.Died:Connect(function() Off(P) end)) end
		table.insert(Conns, P.CharacterAdded:Connect(function() Off(P) end))
	end
	-- the stowaways who actually ride, as a list: a BindableEvent drops a table's Instance keys, so a {[Player] = true}
	-- set would arrive empty
	local Stowing = {}
	for _, P in ipairs(List) do
		if Stow[P] then table.insert(Stowing, P) end
	end
	StationService.Departing:Fire(RouteId, List, RideSeconds, Stowing)
	local Nag = {}
	local Ends = os.clock() + RideSeconds
	local Floor = Ride:GetPivot().Position.Y - StationService.FallCatch
	while os.clock() < Ends do
		task.wait(math.clamp(Ends - os.clock(), 0, 0.5))
		for _, P in ipairs(List) do
			local C = Body[P]
			local Root = Riding[P] == RouteId and Spot[P] and C and P.Character == C and C:FindFirstChild("HumanoidRootPart")
			if Root and Root.Position.Y < Floor then -- got out of the ride train: back to their spot
				Unseat(P)
				C:PivotTo(Spot[P])
			elseif Root and Stow[P] then -- a stowaway stays with the baggage: out in the coaches they'd be seen
				local Car = InTrain(Ride, Root.Position)
				if Car and CarKind(Car) ~= "BaggageCar" then
					Unseat(P)
					C:PivotTo(Spot[P])
					if not Nag[P] or os.clock() - Nag[P] >= StationService.StowNagGap then
						Nag[P] = os.clock()
						Notify(P, "You'd be seen out there. Better stay with the baggage.")
					end
				end
			elseif Root then -- walked (or teleported) into a car their class doesn't reach: the conductor sends them back
				local Car = InTrain(Ride, Root.Position)
				local Zone = Car and AllowedSpot(P, RouteId, Ride, Car, Root.Position)
				if Zone and Zone ~= NOWHERE then
					Unseat(P)
					Spot[P] = Zone.CFrame
					C:PivotTo(Spot[P])
					Notify(P, "Conductor: \"Your ticket isn't for this car.\"")
				end
			end
		end
	end
	for _, Conn in ipairs(Conns) do Conn:Disconnect() end
	-- who goes: still here, still riding, and not already in another teleport (Depart filters too)
	local Stood = false
	for _, P in ipairs(List) do -- the arrival (or the walk back) moves them; the ride-train seats must stay put
		if Riding[P] == RouteId then
			NoSit[P] = true -- no sitting down again until Riding is cleared below
			if Unseat(P) then Stood = true end
		end
	end
	if Stood then task.wait(StationService.UnseatSettle) end
	local Going, Back, Thrown = {}, {}, {}
	for _, P in ipairs(List) do
		if P.Parent and Riding[P] == RouteId then
			if P:GetAttribute("ThrownOff") then -- the inspection: no ticket and no money for the fine
				table.insert(Thrown, P)
			elseif FlowTeleport.Busy(P) or FlowTeleport.InGroup(P) then table.insert(Back, P) else table.insert(Going, P) end
		end
		Riding[P] = nil -- cleared before Depart, which yields while the saves are released
		NoSit[P] = nil
	end
	for _, P in ipairs(Thrown) do -- thrown off (controller ruling, Task 9): back on this platform, not arriving
		P:SetAttribute("ThrownOff", nil)
		local At = TravelService.ArrivalPoint("Platform")
		if At and P.Character then P.Character:PivotTo(At.CFrame + Vector3.new(0, TravelService.SpawnLift or 3, 0)) end
		Event:FireClient(P, "RideCancel", {Route = RouteId, Text = "The conductor put you off at the platform."})
	end
	local Here = TravelService.Here()
	local Dest = Travel.Other(RouteId, Here)
	local DestName = Dest and Places.Regions[Dest] and Places.Regions[Dest].Name or Dest
	for _, P in ipairs(Going) do Event:FireClient(P, "RideEnd", {Route = RouteId, Dest = DestName}) end
	local Sent = {}
	if #Going > 0 then
		local Ok, Mode, Went = pcall(TravelService.Depart, Going, RouteId, "Platform")
		if Ok then
			for _, P in ipairs(Went or {}) do Sent[P] = true end
		else
			warn("[StationService] Depart failed on " .. RouteId .. ": " .. tostring(Mode))
			if not RunService:IsStudio() then -- live: their saves may already be released, so they can't stay here
				for _, P in ipairs(Going) do
					local Line = Stow[P] and "The journey to %s couldn't be completed. Please rejoin." or "The journey to %s couldn't be completed. Your ticket is still valid; please rejoin."
					if P.Parent then P:Kick(Line:format(tostring(DestName))) end
				end
				Going = {} -- kicked; the Back players below still go back to the platform
			end
		end
	end
	for _, P in ipairs(Going) do
		if not Sent[P] then table.insert(Back, P) end
	end
	for _, P in ipairs(Back) do -- couldn't travel: back to this platform, the ticket kept
		if P.Parent then
			local At = TravelService.ArrivalPoint("Platform")
			if At and P.Character then P.Character:PivotTo(At.CFrame + Vector3.new(0, TravelService.SpawnLift or 3, 0)) end
			local Line = Stow[P] and "The train couldn't take you this time." or "The train couldn't take you this time. Your ticket is still good."
			Event:FireClient(P, "Message", {Text = Line})
			Notify(P, Line)
		end
	end
end

-- test hook: depart now with a short ride (Studio only; does nothing on a live server)
function StationService.DepartNow(RouteId, RideSeconds)
	if not RunService:IsStudio() then return end
	task.spawn(Depart, RouteId, RideSeconds or Travel.Routes[RouteId].Ride)
end

function StationService.Riding(Player) return Riding[Player] end
function StationService.NoSit(Player) return NoSit[Player] == true end

local function Clock()
	local Last = {}
	while true do
		local Now = os.time()
		for _, RouteId in ipairs(Lines()) do
			local R = Travel.Routes[RouteId]
			local Prev = math.floor(Now / R.Every) * R.Every -- the departure slot that just started
			if Last[RouteId] == nil then Last[RouteId] = Prev end -- seeded: a line first seen mid-slot waits for the next one
			if Prev > Last[RouteId] then
				Last[RouteId] = Prev
				-- a hitch longer than Stale skips this departure rather than leaving very late
				if Now - Prev <= StationService.Stale and not (StationService.HoldClock and RunService:IsStudio()) then
					task.spawn(Depart, RouteId, R.Ride)
				end
			elseif Travel.BoardingOpen(RouteId, Now) then
				local Next = Travel.NextDeparture(RouteId, Now)
				local Key = RouteId .. "|" .. Next
				local Aboard, Stow = StationService.Aboard(RouteId)
				for _, P in ipairs(Aboard) do
					if Told[P] ~= Key and not Stow[P] then -- (a stowaway hides; nobody calls "all aboard" to them)
						Told[P] = Key
						Event:FireClient(P, "Board", {Route = RouteId, Departs = Next})
					end
				end
			end
		end
		task.wait(1)
	end
end

local function NearClerk(P)
	local Root = P.Character and P.Character:FindFirstChild("HumanoidRootPart")
	if not Root then return false end
	for _, C in ipairs(CollectionService:GetTagged("RenseiTicketClerk")) do
		if C:IsA("BasePart") and C:IsDescendantOf(workspace) and (C.Position - Root.Position).Magnitude <= StationService.ClerkReach then return true end
	end
	return false
end

local function AddPrompt(Clerk)
	if not Clerk:IsA("BasePart") or Clerk:FindFirstChild("TicketPrompt") then return end
	local Prompt = Instance.new("ProximityPrompt")
	Prompt.Name = "TicketPrompt"
	Prompt.ActionText, Prompt.ObjectText, Prompt.MaxActivationDistance = "Buy a ticket", "Ticket clerk", 10
	Prompt.Style = Enum.ProximityPromptStyle.Custom -- drawn by Modules.UI.PromptUI in the game's own art (owner rule 2026-10-21)
	Prompt.Parent = Clerk
	Prompt.Triggered:Connect(function(P) Event:FireClient(P, "OpenTickets", {}) end)
end

function StationService.Start()
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	Remote = Remotes:FindFirstChild("Travel") or Instance.new("RemoteFunction")
	Remote.Name = "Travel"
	Remote.Parent = Remotes
	Event = Remotes:FindFirstChild("TravelEvent") or Instance.new("RemoteEvent")
	Event.Name = "TravelEvent"
	Event.Parent = Remotes
	Remote.OnServerInvoke = function(Player, Op, Args)
		local Now = os.clock()
		if LastAsk[Player] and Now - LastAsk[Player] < StationService.AskGap then return false, "One moment." end
		LastAsk[Player] = Now
		Args = type(Args) == "table" and Args or {}
		if Op == "Buy" then
			if not NearClerk(Player) then return false, "Buy tickets at the station's ticket clerk." end
			return StationService.Buy(Player, Args.Route, Args.Class, type(Args.For) == "number" and Args.For or nil)
		elseif Op == "Bribe" then -- the papers check: pay the guard (Task 9)
			local Gate = NearGate(Player)
			if not Gate then return false, "Talk to the guard at the gate." end
			if StationService.Gate(Player) ~= "Bribe" then return false, "Move along." end
			if Cleared(Player) then return true end
			local RouteId = GateRoute(Gate)
			if StationService.PayBribe(Player, RouteId) then return true end
			return false, ("That's not $%d."):format(RouteId and Travel.Bribe(RouteId, "Third", StationService.Season()) or 0)
		elseif Op == "Search" then
			if not NearGate(Player) then return false, "Talk to the guard at the gate." end
			if StationService.Gate(Player) ~= "Bribe" then return false, "Move along." end
			return StationService.Search(Player)
		elseif Op == "Prices" then
			local Out = {}
			for _, RouteId in ipairs(Lines()) do
				local Row = {Route = RouteId, To = Travel.Other(RouteId, TravelService.Here()), Prices = {}, Held = TravelService.HasTicket(Player, RouteId)}
				for _, C in ipairs(Travel.ClassOrder) do Row.Prices[C] = Travel.Price(RouteId, C, StationService.Season()) end
				table.insert(Out, Row)
			end
			return Out
		end
		return false, "Unknown request."
	end
	Remote:SetAttribute("Lines", table.concat(Lines(), ",")) -- the departure boards show only these
	Remote:SetAttribute("Ready", true)
	for _, Clerk in ipairs(CollectionService:GetTagged("RenseiTicketClerk")) do AddPrompt(Clerk) end
	CollectionService:GetInstanceAddedSignal("RenseiTicketClerk"):Connect(AddPrompt)
	for _, Tag in ipairs({"RenseiPlatformTrain", "RenseiRideTrain"}) do
		for _, T in ipairs(CollectionService:GetTagged(Tag)) do
			for _, D in ipairs(T:GetDescendants()) do
				if D:IsA("BasePart") and D.Name:find("CarDoor") and D:GetAttribute("CarKind") then
					CollectionService:AddTag(D, "RenseiCarDoor")
					Guard(D)
				end
			end
		end
		for _, T in ipairs(CollectionService:GetTagged(Tag)) do SetUpSeats(T) end -- seats: sit on request only
		CollectionService:GetInstanceAddedSignal(Tag):Connect(SetUpSeats) -- trains built (or rebuilt) later
	end
	for _, G in ipairs(CollectionService:GetTagged("RenseiStationGate")) do GuardGate(G) end -- the papers check (Task 9)
	CollectionService:GetInstanceAddedSignal("RenseiStationGate"):Connect(GuardGate)
	Players.PlayerRemoving:Connect(function(P)
		Riding[P], Told[P], LastPush[P], LastAsk[P], LastSit[P], NoSit[P] = nil, nil, nil, nil, nil, nil
		LastGate[P], LastRefuseHeat[P], YardVisit[P], LastYardHeat[P], LastPapers[P] = nil, nil, nil, nil, nil
	end)
	task.spawn(Clock)
	task.spawn(function() -- the freight yard (Task 9)
		while true do
			task.wait(StationService.YardTick)
			local Ok, Err = pcall(StationService.YardCheck)
			if not Ok then warn("[StationService] yard check: " .. tostring(Err)) end
		end
	end)
end

return StationService

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
StationService.Departing = Instance.new("BindableEvent") -- (RouteId, {Player}, RideSeconds)
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

local Remote, Event
local Riding = {} -- [Player] = RouteId
local Boxes = {} -- [car Model] = {CF, Size}; the trains are anchored and never move
local Kinds = {} -- [car Model] = CarKind (read from its BoardZone / CarDoor parts) or false (locomotive, tender)
local Zones = {} -- [train Model] = {BoardZone parts}
local Told = {} -- [Player] = "Route|departure" we last sent "Board" for
local LastPush, LastAsk = {}, {}

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
	local Ok, Why = Travel.CanTake(Level(Rider), RouteId)
	if not Ok then return false, Why end
	local Price = Travel.Price(RouteId, ClassId, StationService.Season())
	if not ProgressionService.SpendMoney(Player, Price) then return false, ("A ticket costs $%d."):format(Price) end
	TravelService.AddTicket(Rider, RouteId, ClassId)
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

function StationService.Aboard(RouteId)
	local Train = TrainOf("RenseiPlatformTrain", RouteId)
	local Out = {}
	if not Train then return Out end
	for _, P in ipairs(Players:GetPlayers()) do
		local Root = P.Character and P.Character:FindFirstChild("HumanoidRootPart")
		if Root and not Riding[P] and TravelService.HasTicket(P, RouteId) and InTrain(Train, Root.Position) ~= nil then table.insert(Out, P) end
	end
	return Out
end

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

local function Depart(RouteId, RideSeconds)
	local Platform, Ride = TrainOf("RenseiPlatformTrain", RouteId), TrainOf("RenseiRideTrain", RouteId)
	if not (Platform and Ride) then return end
	local List = StationService.Aboard(RouteId)
	if #List == 0 then return end
	local Offset = Ride:GetPivot() * Platform:GetPivot():Inverse()
	local Was = {} -- [Player] = the platform-train seat they sat in
	for _, P in ipairs(List) do
		Riding[P] = RouteId
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
		local Zone = Car and AllowedSpot(P, RouteId, Platform, Car, Root.Position)
		if Zone == NOWHERE then Car = nil end
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
			if P.Parent then Event:FireClient(P, "RideCancel", {Route = RouteId, Text = "The train left without you. Your ticket is still good."}) end
		end
	end
	List = Moved
	if #List == 0 then return end
	-- death aboard (controller ruling, 2026-10-21): a rider whose humanoid dies or whose character is replaced
	-- (respawned in town) is off the ride, keeping the ticket; nobody pulls the new character back into the train
	local Conns = {}
	local function Off(P)
		if Riding[P] ~= RouteId or not Body[P] then return end
		Riding[P], Spot[P], Was[P], Body[P] = nil, nil, nil, nil
		if P.Parent then Event:FireClient(P, "RideCancel", {Route = RouteId, Text = "You came to back in town. Your ticket is still good."}) end
	end
	for _, P in ipairs(List) do
		local H = Body[P]:FindFirstChildOfClass("Humanoid")
		if H then table.insert(Conns, H.Died:Connect(function() Off(P) end)) end
		table.insert(Conns, P.CharacterAdded:Connect(function() Off(P) end))
	end
	StationService.Departing:Fire(RouteId, List, RideSeconds)
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
		if Riding[P] == RouteId and Unseat(P) then Stood = true end
	end
	if Stood then task.wait(StationService.UnseatSettle) end
	local Going, Back = {}, {}
	for _, P in ipairs(List) do
		if P.Parent and Riding[P] == RouteId then
			if FlowTeleport.Busy(P) or FlowTeleport.InGroup(P) then table.insert(Back, P) else table.insert(Going, P) end
		end
		Riding[P] = nil -- cleared before Depart, which yields while the saves are released
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
					if P.Parent then P:Kick(("The journey to %s couldn't be completed. Your ticket is still valid; please rejoin."):format(tostring(DestName))) end
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
			Event:FireClient(P, "Message", {Text = "The train couldn't take you this time. Your ticket is still good."})
			Notify(P, "The train couldn't take you this time. Your ticket is still good.")
		end
	end
end

-- test hook: depart now with a short ride (Studio only; does nothing on a live server)
function StationService.DepartNow(RouteId, RideSeconds)
	if not RunService:IsStudio() then return end
	task.spawn(Depart, RouteId, RideSeconds or Travel.Routes[RouteId].Ride)
end

function StationService.Riding(Player) return Riding[Player] end

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
				for _, P in ipairs(StationService.Aboard(RouteId)) do
					if Told[P] ~= Key then
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
	end
	Players.PlayerRemoving:Connect(function(P)
		Riding[P], Told[P], LastPush[P], LastAsk[P] = nil, nil, nil, nil
	end)
	task.spawn(Clock)
end

return StationService

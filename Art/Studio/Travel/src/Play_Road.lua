-- Play_Road (World plan 1 Task 8b, roads on foot): run in a Studio Play server through ServerStorage.LMRunSuite.
-- Studio can't teleport: crossing the threshold loops back to this place's own RoadStart (TravelService's loopback).
-- Fix round 1: only walking the road crosses, so the tests walk it: the character is stepped along the passage's
-- RoadPoints (8 studs every 0.1 s, well under RoadService.MaxSpeed) from the mouth.
-- Fix round 2: a walk can't start where the leg boxes overlap at a bend; a stalled watch allows no bigger jump; party
-- members must be on the last legs; a bandit chased off its stretch gives up and walks home.
local SSS = game.ServerScriptService
local CS = game:GetService("CollectionService")
local ROUTE = "RoadLindenmoorFoundry"
local HELD = {"Knocked", "GrippedBy", "CarriedBy", "Gripping", "Carrying"}
-- Studio only: no random encounter rolls while the suite walks the passage (a test forces its own with RS.Force)
require(SSS.RoadService).Calm = true

local function Tagged(Tag, Name)
	for _, P in ipairs(CS:GetTagged(Tag)) do
		if P:IsA("BasePart") and P:IsDescendantOf(workspace) and P:GetAttribute("Route") == ROUTE and (not Name or P.Name == Name) then return P end
	end
	return nil
end
local function Encounter(Order)
	for _, P in ipairs(CS:GetTagged("RenseiRoadEncounter")) do
		if P:IsDescendantOf(workspace) and P:GetAttribute("Route") == ROUTE and P:GetAttribute("Order") == Order then return P end
	end
	return nil
end

-- the road's centre line, in order from the mouth: {S, CFrame}
local function RoadPoints()
	local Out = {}
	for _, P in ipairs(CS:GetTagged("RenseiRoadPassage")) do
		if P:IsDescendantOf(workspace) and P:GetAttribute("Route") == ROUTE then
			for _, A in ipairs(P:GetChildren()) do
				if A:IsA("Attachment") and A.Name == "RoadPoint" then table.insert(Out, {A:GetAttribute("S"), A.WorldCFrame}) end
			end
		end
	end
	table.sort(Out, function(A, B) return A[1] < B[1] end)
	return Out
end

-- a living character to test with
local function Ready(P)
	local t0 = os.clock()
	while os.clock() - t0 < 12 do
		local C = P.Character
		local H = C and C:FindFirstChildOfClass("Humanoid")
		if H and H.Health > 0 and C:FindFirstChild("HumanoidRootPart") then return C end
		task.wait(0.2)
	end
	return nil
end

-- not crossing (a crossing from the last test has ended)
local function Idle(P)
	local RS = require(SSS.RoadService)
	local t0 = os.clock()
	while RS.OnRoad(P) and os.clock() - t0 < 6 do task.wait(0.1) end
end

local function RoadUnder(Part, Up) return Part.Position - Vector3.new(0, Up, 0) end

-- stand P on the road at Pos facing Dir (root 3 above the road)
local function Stand(P, Pos, Dir)
	local C = P.Character
	C:PivotTo(CFrame.lookAt(Pos + Vector3.new(0, 3, 0), Pos + Vector3.new(0, 3, 0) + Dir))
	C.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
end

-- walk P along the road from S0 to S1 studs from the mouth: stepped from RoadPoint to RoadPoint (80 studs/s)
local function WalkRoad(P, S0, S1)
	for _, Pt in ipairs(RoadPoints()) do
		if Pt[1] >= S0 and Pt[1] <= S1 then
			Stand(P, Pt[2].Position, Pt[2].LookVector)
			task.wait(0.1)
		end
	end
	task.wait(0.3) -- a tick or two for the watch
end

-- studs from the mouth to the threshold
local function ThresholdS(Th)
	local Best, BD = 0, math.huge
	for _, Pt in ipairs(RoadPoints()) do
		local D = (Pt[2].Position - RoadUnder(Th, 13)).Magnitude
		if D < BD then Best, BD = Pt[1], D end
	end
	return Best
end

-- park P off the passage, on the hub road beside its mouth
local function OffRoad(P)
	Stand(P, Vector3.new(-1, 0.1, -262), Vector3.new(0, 0, 1))
	task.wait(0.3)
end

-- the passage's leg boxes by Leg, and its last leg
local function Legs()
	local Out, N = {}, 0
	for _, P in ipairs(CS:GetTagged("RenseiRoadPassage")) do
		if P:IsDescendantOf(workspace) and P:GetAttribute("Route") == ROUTE then
			Out[P:GetAttribute("Leg")] = P
			N = math.max(N, P:GetAttribute("Leg"))
		end
	end
	return Out, N
end
local function InBox(B, Pos)
	local L = B.CFrame:PointToObjectSpace(Pos)
	return math.abs(L.X) <= B.Size.X / 2 and math.abs(L.Y) <= B.Size.Y / 2 and math.abs(L.Z) <= B.Size.Z / 2
end
-- which legs Pos is in, e.g. "1+2+3"
local function LegsAt(Pos)
	local Out = {}
	for L, B in pairs((Legs())) do if InBox(B, Pos) then table.insert(Out, L) end end
	table.sort(Out)
	return table.concat(Out, "+")
end
-- the first RoadPoint S under leg L
local function FirstS(L)
	local Best = math.huge
	for _, A in ipairs((Legs())[L]:GetChildren()) do
		if A.Name == "RoadPoint" then Best = math.min(Best, A:GetAttribute("S")) end
	end
	return Best
end
-- the ground at (X, Z): the first solid, collidable, visible surface down from above the banks and trees
local function Ground(X, Z, C)
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	local Skip = {C}
	for _ = 1, 16 do
		Params.FilterDescendantsInstances = Skip
		local Hit = workspace:Raycast(Vector3.new(X, 90, Z), Vector3.new(0, -180, 0), Params)
		if not Hit then break end
		local I = Hit.Instance
		if I.CanCollide and I.CanTouch and I.Transparency < 1 and Hit.Position.Y < 20 then return Hit.Position end -- (not a canopy)
		table.insert(Skip, I)
	end
	return Vector3.new(X, 4, Z)
end
local function Flat(V) return Vector3.new(V.X, 0, V.Z).Magnitude end

local function Rig(Name, Pos)
	local D = Instance.new("HumanoidDescription")
	local M = game.Players:CreateHumanoidModelFromDescription(D, Enum.HumanoidRigType.R6)
	M.Name = Name
	M:PivotTo(CFrame.new(Pos + Vector3.new(0, 3, 0)))
	M.HumanoidRootPart.Anchored = true
	M.Parent = workspace
	return M
end

return {
	-- walking the road from its mouth into the threshold crosses (Studio: loops back) and arrives at RoadStart, with the
	-- Trip written into the save first and Arrived fired for the road; a fight is no bar; arriving doesn't chain into
	-- leaving again
	WalkingTheRoadIntoTheThresholdCrosses = function(T)
		local RS, TS = require(SSS.RoadService), require(SSS.TravelService)
		local PS = require(SSS.ProgressionService)
		local P = game.Players:GetPlayers()[1]
		local C = Ready(P)
		Idle(P)
		local Th, Start = Tagged("RenseiRoadThreshold"), TS.ArrivalPoint("RoadStart")
		T.True(Th ~= nil and Start ~= nil, "the threshold and the RoadStart arrival exist")
		T.True(#RoadPoints() > 30, "the road's centre line is marked")
		local Got, Count, At = nil, 0, nil
		local Conn = TS.Arrived.Event:Connect(function(Who, Region, Route)
			if Who == P then
				Got, Count = {Region, Route}, Count + 1
				At = Who.Character and Who.Character.HumanoidRootPart.Position
			end
		end)
		local Old, Info = TS.Arrive, nil
		TS.Arrive = function(Who, I)
			if Who == P then Info = table.clone(I) end
			return Old(Who, I)
		end
		local Ok, Err = pcall(function()
			OffRoad(P)
			C:SetAttribute("InCombat", true) -- fleeing over the threshold is allowed
			WalkRoad(P, 0, ThresholdS(Th) - 16)
			T.True(RS.Walking(P, ROUTE) ~= nil, "walking the road (leg " .. tostring(RS.Walking(P, ROUTE)) .. ")")
			local Dir = Th.CFrame.LookVector
			task.wait(0.7) -- the client owns the character: let the last step land before walking
			C.Humanoid:MoveTo(RoadUnder(Th, 13) + Dir * (Th.Size.Z / 2 + 2))
			local t0 = os.clock()
			while not RS.OnRoad(P) and not Got and os.clock() - t0 < 6 do task.wait(0.05) end
			T.True(RS.OnRoad(P) or Got ~= nil, "walking in started the crossing")
			t0 = os.clock()
			while not Got and os.clock() - t0 < 6 do task.wait(0.1) end
			T.True(Got ~= nil, "arrived")
			T.Eq(Got and Got[2], ROUTE, "Arrived fired for the road")
			T.Eq(Got and Got[1], "Lindenmoor", "in this place (the Studio loopback)")
			T.True(Info ~= nil and Info.Route == ROUTE and Info.Arrive == "RoadStart" and Info.To == "Foundry", "the saved Trip took them (" .. tostring(Info and Info.Arrive) .. ")")
			local Flat = At and Vector3.new(At.X - Start.Position.X, 0, At.Z - Start.Position.Z).Magnitude or math.huge
			T.True(Flat < 3, ("set down at RoadStart (%.1f studs off)"):format(Flat))
			T.True(RS.Walking(P, ROUTE) ~= nil, "arriving counts as having walked in")
			local D = PS.GetData(P)
			T.True(D and D.Travel and D.Travel.Trip == nil and D.Travel.Region == "Lindenmoor", "the Trip is used up")
			task.wait(2.5)
			T.Eq(Count, 1, "arriving doesn't carry you straight back out")
			T.True(not RS.OnRoad(P), "not crossing again")
		end)
		TS.Arrive = Old
		Conn:Disconnect()
		C:SetAttribute("InCombat", nil)
		Idle(P)
		T.True(Ok, tostring(Err))
	end,

	-- fix round 1: a teleport into the threshold (to escape a fight or an arrest) doesn't cross: from off the passage,
	-- or from partway along it
	TeleportingIntoTheThresholdDoesntCross = function(T)
		local RS, TS = require(SSS.RoadService), require(SSS.TravelService)
		local P = game.Players:GetPlayers()[1]
		Ready(P)
		Idle(P)
		local Th = Tagged("RenseiRoadThreshold")
		local Got
		local Conn = TS.Arrived.Event:Connect(function(Who) if Who == P then Got = true end end)
		local Ok, Err = pcall(function()
			OffRoad(P)
			T.True(RS.Walking(P, ROUTE) == nil, "off the road: not walking it")
			Stand(P, RoadUnder(Th, 13), Th.CFrame.LookVector) -- straight in from the hub road
			task.wait(1)
			T.True(not RS.OnRoad(P) and not Got, "from off the road: no crossing")
			T.True(RS.Walking(P, ROUTE) == nil, "and no walk")
			OffRoad(P)
			WalkRoad(P, 0, 60) -- a real start, 60 studs along
			T.Eq(RS.Walking(P, ROUTE), 1, "walking, in leg 1")
			Stand(P, RoadUnder(Th, 13), Th.CFrame.LookVector) -- then a jump to the end
			task.wait(1)
			T.True(not RS.OnRoad(P) and not Got, "from partway: no crossing")
			T.True(RS.Walking(P, ROUTE) == nil, "the jump dropped the walk")
		end)
		Conn:Disconnect()
		OffRoad(P)
		Idle(P)
		T.True(Ok, tostring(Err))
	end,

	-- nobody escapes a knock, a grip or a carry by road (walked up to the threshold properly)
	DownOrHeldCantCross = function(T)
		local RS, TS = require(SSS.RoadService), require(SSS.TravelService)
		local P = game.Players:GetPlayers()[1]
		local C = Ready(P)
		Idle(P)
		local Th = Tagged("RenseiRoadThreshold")
		local Got
		local Conn = TS.Arrived.Event:Connect(function(Who) if Who == P then Got = true end end)
		local Ok, Err = pcall(function()
			OffRoad(P)
			WalkRoad(P, 0, ThresholdS(Th) - 16)
			local Dir = Th.CFrame.LookVector
			local Before, In = RoadUnder(Th, 13) - Dir * 16, RoadUnder(Th, 13)
			for _, Name in ipairs(HELD) do
				C:SetAttribute(Name, Name == "Knocked" and true or "Someone")
				Stand(P, In, Dir) -- 16 studs on: into the threshold, still walking
				task.wait(0.8)
				T.True(RS.Walking(P, ROUTE) ~= nil, Name .. ": still walking the road")
				T.True(not RS.OnRoad(P) and not Got, Name .. ": didn't cross")
				Stand(P, Before, Dir) -- back out first, then let go (else they'd cross from where they stand)
				task.wait(0.3)
				C:SetAttribute(Name, nil)
				task.wait(0.2)
			end
		end)
		Conn:Disconnect()
		for _, Name in ipairs(HELD) do C:SetAttribute(Name, nil) end
		OffRoad(P)
		Idle(P)
		T.True(Ok, tostring(Err))
	end,

	-- fix round 1 (minor 3): after a cancelled crossing the threshold ignores you until you step out of it, or 3 s
	ACancelledCrossingRearmsOnlyLater = function(T)
		local RS, TS = require(SSS.RoadService), require(SSS.TravelService)
		local P = game.Players:GetPlayers()[1]
		local C = Ready(P)
		Idle(P)
		local Th = Tagged("RenseiRoadThreshold")
		local Got
		local Conn = TS.Arrived.Event:Connect(function(Who) if Who == P then Got = os.clock() end end)
		local Ok, Err = pcall(function()
			OffRoad(P)
			WalkRoad(P, 0, ThresholdS(Th) - 16)
			local Dir = Th.CFrame.LookVector
			Stand(P, RoadUnder(Th, 13), Dir)
			local t0 = os.clock()
			while not RS.OnRoad(P) and os.clock() - t0 < 2 do task.wait(0.05) end
			T.True(RS.OnRoad(P), "the crossing started")
			C.HumanoidRootPart.Anchored = true -- held where they stand, in the threshold (the walk-in would carry them out)
			C:SetAttribute("Knocked", true) -- knocked during the walk-in: dropped out
			t0 = os.clock()
			while RS.OnRoad(P) and os.clock() - t0 < 3 do task.wait(0.05) end
			local Cancelled = os.clock()
			T.True(not RS.OnRoad(P) and not Got, "cancelled")
			C:SetAttribute("Knocked", nil)
			C.HumanoidRootPart.Anchored = false
			Stand(P, RoadUnder(Th, 13), Dir) -- still in the threshold
			task.wait(1.2)
			T.True(not RS.OnRoad(P) and not Got, "not straight back in")
			t0 = os.clock()
			while not Got and os.clock() - t0 < 6 do task.wait(0.1) end
			T.True(Got ~= nil and Got - Cancelled >= RS.RearmTime, "crossed once the rearm time was up")
		end)
		Conn:Disconnect()
		C:SetAttribute("Knocked", nil)
		if C:FindFirstChild("HumanoidRootPart") then C.HumanoidRootPart.Anchored = false end
		Idle(P)
		T.True(Ok, tostring(Err))
	end,

	-- who crosses with you: party members walking the same passage within 40 studs, fit to go. Studio has one player,
	-- so the party is stand-in members with R6 rigs (PartyService.Get is wrapped, their walks set by a test hook).
	PartyWithin40CrossesWithYou = function(T)
		local RS, PartyService = require(SSS.RoadService), require(SSS.PartyService)
		local P = game.Players:GetPlayers()[1]
		Ready(P)
		Idle(P)
		local Old = PartyService.Get
		local Made, Fakes = {}, {}
		local Ok, Err = pcall(function()
			local Mid = Encounter(1)
			local Road = RoadUnder(Mid, 12)
			local Dir = Mid.CFrame.LookVector
			Stand(P, Road, Dir)
			task.wait(0.3)
			-- fix round 2: a member must also have walked to the last legs (LastLeg - 1 or on); the stand-ins' walks are
			-- set by the test hook (leg Last unless given)
			local _, Last = Legs()
			local function Member(Name, Pos, Walks, Leg)
				local M = Rig(Name, Pos)
				table.insert(Made, M)
				local F = {Name = Name, UserId = -9000 - #Made, Parent = game.Players, Character = M}
				table.insert(Fakes, F)
				if Walks then RS.SetTrack(F, ROUTE, Leg or Last, M.HumanoidRootPart.Position) end
				return F
			end
			local Near = Member("Near", Road + Dir * 25, true)
			local Far = Member("Far", Road + Dir * 60, true)
			local Down = Member("Down", Road - Dir * 15, true)
			Down.Character:SetAttribute("Knocked", true)
			local Off = Member("OffRoad", Road + Vector3.new(0, 0, -30), true) -- 30 away, in the fields south of the passage
			local Dropped = Member("Teleported", Road - Dir * 20, false) -- on the passage and near, but not walking it
			local LegBack = Member("OneLegBack", Road + Dir * 10, true, Last - 1) -- a leg behind, near: goes
			local Lagging = Member("Lagging", Road - Dir * 8, true, Last - 2) -- near by distance, but two legs back
			T.True(RS.PassageAt(Near.Character.HumanoidRootPart.Position) == ROUTE, "Near stands on the passage")
			T.True(RS.PassageAt(Off.Character.HumanoidRootPart.Position) == nil, "OffRoad is off the passage")
			local Party = {Leader = P, Members = {P, Near, Far, Down, Off, Dropped, LegBack, Lagging}}
			PartyService.Get = function(Who)
				if Who == P or table.find(Fakes, Who) then return Party end
				return Old(Who)
			end
			local Group, Left = RS.Gather(P, ROUTE)
			local In = {}
			for _, M in ipairs(Group) do In[M] = true end
			T.True(In[P] and In[Near], "you and the member 25 studs along cross together")
			T.True(not In[Far], "a member 60 studs back doesn't")
			T.True(not In[Down], "a knocked member doesn't")
			T.True(not In[Off], "a member off the passage doesn't")
			T.True(not In[Dropped], "a member who didn't walk the road doesn't")
			T.True(In[LegBack], "a member one leg back (LastLeg - 1) does")
			T.True(not In[Lagging], "a member near by distance but two legs back doesn't")
			T.Eq(#Left, 5, "five left behind, each told why")
		end)
		PartyService.Get = Old
		for _, F in ipairs(Fakes) do RS.SetTrack(F, nil) end
		for _, M in ipairs(Made) do M:Destroy() end
		T.True(Ok, tostring(Err))
	end,

	-- an encounter (forced) brings bandits out ahead; they keep to their stretch, the roll is spent for this crossing,
	-- and they're removed once nobody is near (Studio TimeScale)
	ForcedEncounterSpawnsAheadAndClears = function(T)
		local RS, ES = require(SSS.RoadService), require(SSS.EnemyService)
		local P = game.Players:GetPlayers()[1]
		Ready(P)
		Idle(P)
		local E = Encounter(1)
		local Ok, Err = pcall(function()
			OffRoad(P)
			RS.ResetRolls(P)
			RS.TimeScale = 0.05 -- ClearAfter 30 s -> 1.5 s
			RS.Force, RS.ForceAt = true, E
			local Dir = E.CFrame.LookVector
			local From = RoadUnder(E, 12) - Dir * (E.Size.Z / 2 - 4) -- in at the town end
			Stand(P, From, Dir)
			local Rigs, t0 = {}, os.clock()
			while #Rigs < 2 and os.clock() - t0 < 3 do
				task.wait(0.05)
				Rigs = RS.EnemiesAt(E)
				for _, R in ipairs(Rigs) do R:SetAttribute("AIPassive", true) end
			end
			T.True(#Rigs >= 2 and #Rigs <= 3, "2-3 bandits came out (" .. #Rigs .. ")")
			T.True(RS.Force == nil, "the forced roll was used")
			for _, R in ipairs(Rigs) do
				T.True(ES.Active[R] ~= nil, "a live EnemyService enemy")
				T.True((R.HumanoidRootPart.Position - From):Dot(Dir) > 20, "ahead of the player, down the road")
			end
			-- flung far off its stretch: put home at once
			local R1 = Rigs[1]
			R1:PivotTo(E.CFrame + E.CFrame.RightVector * 120)
			task.wait(0.8)
			local L = E.CFrame:PointToObjectSpace(R1.HumanoidRootPart.Position)
			T.True(math.abs(L.X) <= E.Size.X / 2 + RS.Leash and math.abs(L.Z) <= E.Size.Z / 2 + RS.Leash, "a flung bandit is put back")
			-- the crossing's roll is spent: in and out and in again rolls nothing more
			RS.Force = true
			Stand(P, From - Dir * 40, Dir)
			task.wait(0.5)
			Stand(P, From, Dir)
			task.wait(0.5)
			T.True(RS.Force == true, "no second roll this crossing")
			RS.Force = nil
			-- nobody near for ClearAfter: they go (removed, no reward)
			Stand(P, Vector3.new(-1, 0.1, -150), Vector3.new(0, 0, 1)) -- 100+ studs away up the hub road
			t0 = os.clock()
			local Gone = false
			while not Gone and os.clock() - t0 < 5 do
				task.wait(0.1)
				Gone = true
				for _, R in ipairs(Rigs) do if R.Parent or ES.Active[R] then Gone = false end end
			end
			T.True(Gone, "cleared after the player left")
			T.Eq(#RS.EnemiesAt(E), 0, "the encounter is empty")
		end)
		RS.Force, RS.ForceAt = nil, nil
		RS.TimeScale = 1
		RS.ClearEncounter(E)
		RS.ResetRolls(P)
		OffRoad(P)
		T.True(Ok, tostring(Err))
	end,

	-- controller's ruling: a hit can fall at an encounter further along the road; it springs when they get there. A
	-- bandit that strays a little off its stretch walks home (no pivot).
	AnAmbushFurtherAlongSpringsThere = function(T)
		local RS, ES = require(SSS.RoadService), require(SSS.EnemyService)
		local P = game.Players:GetPlayers()[1]
		Ready(P)
		Idle(P)
		local E1, E3 = Encounter(1), Encounter(3)
		local Ok, Err = pcall(function()
			OffRoad(P)
			RS.ResetRolls(P)
			RS.TimeScale = 0.05
			RS.Force, RS.ForceAt = true, E3
			local Dir1 = E1.CFrame.LookVector
			Stand(P, RoadUnder(E1, 12) - Dir1 * (E1.Size.Z / 2 - 4), Dir1)
			task.wait(0.6)
			T.Eq(#RS.EnemiesAt(E1), 0, "nothing at the first encounter")
			T.True(RS.Pending(P, ROUTE) == E3, "the ambush waits at the third")
			local Dir3 = E3.CFrame.LookVector
			local From = RoadUnder(E3, 12) - Dir3 * (E3.Size.Z / 2 - 4)
			Stand(P, From, Dir3)
			local Rigs, t0 = {}, os.clock()
			while #Rigs < 2 and os.clock() - t0 < 3 do
				task.wait(0.05)
				Rigs = RS.EnemiesAt(E3)
				for _, R in ipairs(Rigs) do R:SetAttribute("AIPassive", true) end
			end
			T.True(#Rigs >= 2, "it sprang at the third encounter (" .. #Rigs .. ")")
			T.True(RS.Pending(P, ROUTE) == nil, "and is no longer waiting")
			-- strayed a little past its stretch: walks back (no pivot)
			local R1 = Rigs[1]
			local Home = R1:GetPivot()
			local Side = E3.CFrame.RightVector * (E3.Size.X / 2 + RS.Leash + 8)
			R1:PivotTo(CFrame.new(E3.Position.X, Home.Y, E3.Position.Z) + Side)
			task.wait(0.1)
			local Was = R1.HumanoidRootPart.Position
			task.wait(3)
			local Now = R1.HumanoidRootPart.Position
			T.True((Now - Was).Magnitude > 3 and (Now - Home.Position).Magnitude < (Was - Home.Position).Magnitude,
				("a stray walks back towards home (%.0f -> %.0f studs)"):format((Was - Home.Position).Magnitude, (Now - Home.Position).Magnitude))
			for _, R in ipairs(Rigs) do T.True(ES.Active[R] ~= nil, "still a live enemy") end
		end)
		RS.Force, RS.ForceAt = nil, nil
		RS.TimeScale = 1
		RS.ClearEncounter(E1)
		RS.ClearEncounter(E3)
		RS.ResetRolls(P)
		OffRoad(P)
		T.True(Ok, tostring(Err))
	end,

	-- fix round 2: the leg boxes overlap at the first bend (legs 1+2, and 1+2+3 on its inner bank). Coming down into
	-- it from off the road (the hub baseplate, the fields) starts no walk, so walking on from there doesn't cross. A
	-- walk from the mouth steps through the legs one at a time and crosses.
	EnteringAtTheBendDoesntStartAWalk = function(T)
		local RS, TS = require(SSS.RoadService), require(SSS.TravelService)
		local P = game.Players:GetPlayers()[1]
		local C = Ready(P)
		Idle(P)
		local Th = Tagged("RenseiRoadThreshold")
		local ThS = ThresholdS(Th)
		local Got
		local Conn = TS.Arrived.Event:Connect(function(Who) if Who == P then Got = true end end)
		local function Root() return C.HumanoidRootPart.Position end
		-- walk on from S0 to the threshold's edge, then a real MoveTo into it: did it get there?
		local function OnAndIn(S0)
			WalkRoad(P, S0, ThS - 16)
			task.wait(0.7) -- the client owns the character: let the last step land before walking
			C.Humanoid:MoveTo(RoadUnder(Th, 13) + Th.CFrame.LookVector * (Th.Size.Z / 2 + 2))
			local t0, Was = os.clock(), false
			while os.clock() - t0 < 4 and not RS.OnRoad(P) and not Got do
				task.wait(0.05)
				if InBox(Th, Root()) then Was = true end
			end
			task.wait(1)
			return Was
		end
		local Ok, Err = pcall(function()
			local B = Legs()
			local Lo = function(L) return B[L].Position - B[L].Size / 2 end
			local Hi = function(L) return B[L].Position + B[L].Size / 2 end
			-- 1. the inner corner of the bend, where boxes 1, 2 and 3 meet: hop down into it off the bank above
			local CX = (math.max(Lo(1).X, Lo(2).X, Lo(3).X) + math.min(Hi(1).X, Hi(2).X, Hi(3).X)) / 2
			local CZ = (math.max(Lo(1).Z, Lo(2).Z, Lo(3).Z) + math.min(Hi(1).Z, Hi(2).Z, Hi(3).Z)) / 2
			OffRoad(P)
			Stand(P, Ground(CX + 12, CZ + 12, C), Vector3.new(-1, 0, -1)) -- up beside it, in box 2 or 3 but not 1
			task.wait(0.5)
			T.True(not LegsAt(Root()):find("1"), "up on the bank: off leg 1 (" .. LegsAt(Root()) .. ")")
			T.True(RS.Walking(P, ROUTE) == nil, "and not walking")
			Stand(P, Ground(CX, CZ, C), Vector3.new(-1, 0, -1))
			task.wait(0.6)
			T.Eq(LegsAt(Root()), "1+2+3", "down in the corner, in legs 1, 2 and 3")
			T.True(RS.Walking(P, ROUTE) == nil, "no walk starts there (was leg " .. tostring(RS.Walking(P, ROUTE)) .. ")")
			local Was = OnAndIn(FirstS(3))
			T.True(Was, "walked on into the threshold")
			T.True(not RS.OnRoad(P) and not Got, "from the corner: no crossing")
			T.True(RS.Walking(P, ROUTE) == nil, "and still no walk")
			-- 2. legs 1 and 2 overlap before the bend: walk into it from the fields
			local FX = (math.max(Lo(1).X, Lo(2).X) + Lo(3).X) / 2
			local FZ = math.max(Lo(1).Z, Lo(2).Z) + 8
			OffRoad(P)
			Stand(P, Ground(FX, FZ - 10, C), Vector3.new(0, 0, 1)) -- in the fields, just off the passage
			task.wait(0.5)
			T.Eq(LegsAt(Root()), "", "in the fields: off the passage")
			Stand(P, Ground(FX, FZ, C), Vector3.new(0, 0, 1))
			task.wait(0.6)
			T.Eq(LegsAt(Root()), "1+2", "in legs 1 and 2")
			T.True(RS.Walking(P, ROUTE) == nil, "no walk starts there (was leg " .. tostring(RS.Walking(P, ROUTE)) .. ")")
			Was = OnAndIn(FirstS(2))
			T.True(Was, "walked on into the threshold")
			T.True(not RS.OnRoad(P) and not Got, "from the fields: no crossing")
			-- 3. a walk from the mouth: the legs in order, one at a time, then it crosses
			OffRoad(P)
			local Seen = {}
			for _, Pt in ipairs(RoadPoints()) do
				if Pt[1] <= ThS - 16 then
					Stand(P, Pt[2].Position, Pt[2].LookVector)
					task.wait(0.1)
					local L = RS.Walking(P, ROUTE)
					if L and L ~= Seen[#Seen] then table.insert(Seen, L) end
				end
			end
			task.wait(0.3)
			local L = RS.Walking(P, ROUTE)
			if L and L ~= Seen[#Seen] then table.insert(Seen, L) end
			local Steps = true -- 1, 2, 3 ... with none skipped (the threshold's edge is in legs 4 and 5)
			for I, L in ipairs(Seen) do if L ~= I then Steps = false end end
			T.True(Steps and #Seen >= 4, "from the mouth: the legs one by one (" .. table.concat(Seen, ",") .. ")")
			task.wait(0.7)
			C.Humanoid:MoveTo(RoadUnder(Th, 13) + Th.CFrame.LookVector * (Th.Size.Z / 2 + 2))
			local t0 = os.clock()
			while not Got and os.clock() - t0 < 8 do task.wait(0.1) end
			T.True(Got ~= nil, "a walk from the mouth crosses")
		end)
		Conn:Disconnect()
		Idle(P)
		OffRoad(P)
		T.True(Ok, tostring(Err))
	end,

	-- fix round 2 (minor 3): a stalled watch doesn't allow a bigger jump: the time since the last check counts as at
	-- most DtCap ticks
	AStalledWatchAllowsNoBiggerJump = function(T)
		local RS = require(SSS.RoadService)
		local P = game.Players:GetPlayers()[1]
		local C = Ready(P)
		Idle(P)
		local Ok, Err = pcall(function()
			local Pts = {}
			for _, Pt in ipairs(RoadPoints()) do Pts[Pt[1]] = Pt[2] end
			OffRoad(P)
			local Here = Pts[136] -- on leg 1 alone, before the bend
			Stand(P, Here.Position, Here.LookVector)
			task.wait(0.5)
			T.Eq(LegsAt(C.HumanoidRootPart.Position), "1", "on leg 1 alone")
			T.Eq(RS.Walking(P, ROUTE), 1, "walking, in leg 1")
			local Limit = RS.MaxSpeed * RS.Tick * RS.DtCap * 2
			T.True(Limit > 48 and Limit < 120, ("the most a stalled check allows: %.0f studs"):format(Limit))
			-- the last check was 3 s ago (a stall) and 48 studs back: kept (the walk is set to leg 2 to tell)
			RS.SetTrack(P, ROUTE, 2, Pts[88].Position + Vector3.new(0, 3, 0), os.clock() - 3)
			task.wait(0.5)
			T.Eq(RS.Walking(P, ROUTE), 2, "48 studs over a 3 s stall: the walk is kept")
			-- ... and 120 studs back: once allowed (130 x 3 x 2), now a jump: dropped, and a new walk starts in leg 1
			RS.SetTrack(P, ROUTE, 2, Pts[16].Position + Vector3.new(0, 3, 0), os.clock() - 3)
			task.wait(0.5)
			T.Eq(RS.Walking(P, ROUTE), 1, "120 studs over a 3 s stall: dropped (a new walk in leg 1)")
		end)
		OffRoad(P)
		T.True(Ok, tostring(Err))
	end,

	-- fix round 2 (minor 2): a bandit that chases someone off its stretch gives up (PerceptionService.Lose) and walks
	-- home by itself, without being pivoted home at Overshoot. The chaser attacks for real (AIPassive only if all
	-- rolled guns); the player waits 70 studs down the road, out of its reach, and it is alarmed on them until it's
	-- out past its leash.
	AStrayBanditGivesUpTheChase = function(T)
		local RS, ES, PS = require(SSS.RoadService), require(SSS.EnemyService), require(SSS.PerceptionService)
		local P = game.Players:GetPlayers()[1]
		local C = Ready(P)
		Idle(P)
		local E = Encounter(1)
		local Ok, Err = pcall(function()
			OffRoad(P)
			RS.ResetRolls(P)
			RS.Force, RS.ForceAt = true, E
			local Dir = E.CFrame.LookVector
			Stand(P, RoadUnder(E, 12) - Dir * (E.Size.Z / 2 - 4), Dir) -- in at the town end
			local Rigs, t0 = {}, os.clock()
			local R1
			while #Rigs < 2 and os.clock() - t0 < 3 do
				task.wait(0.05)
				Rigs = RS.EnemiesAt(E)
				for _, R in ipairs(Rigs) do
					if not R1 and ES.Active[R] and ES.Active[R].Range == nil then R1 = R end -- a melee bandit chases
					if R ~= R1 then R:SetAttribute("AIPassive", true) end -- the rest stay out of it
				end
			end
			T.True(#Rigs >= 2, "the ambush came out (" .. #Rigs .. ")")
			local Gun = R1 == nil
			R1 = R1 or Rigs[1]
			if Gun then R1:SetAttribute("AIPassive", true) end -- all rolled guns: it still chases, it just never fires
			local Home = ES.Active[R1].Home.Position
			-- the player waits 70 studs down the road on its side: inside its own 90-stud LeashRange (so EnemyService
			-- itself doesn't give up), out of its reach once it is past RoadService's leash
			local Side = (Home - E.Position):Dot(Dir) >= 0 and 1 or -1
			local Want, Best, BD = Home + Dir * Side * 70, nil, math.huge
			for _, Pt in ipairs(RoadPoints()) do
				local D = Flat(Pt[2].Position - Want)
				if D < BD then Best, BD = Pt[2], D end
			end
			Stand(P, Best.Position, -Dir * Side)
			C.HumanoidRootPart.Anchored = true
			local Away = Flat(C.HumanoidRootPart.Position - Home)
			T.True(Away > 55 and Away < 88, ("the player waits %.0f studs from its home"):format(Away))
			local Hp = C.Humanoid.Health
			local function Past()
				local L = E.CFrame:PointToObjectSpace(R1.HumanoidRootPart.Position)
				local H = E.Size / 2
				return math.max(math.abs(L.X) - H.X, math.abs(L.Y) - H.Y, math.abs(L.Z) - H.Z)
			end
			local MaxPast, FarPos, Jump, Out, GaveUp, LastAlarm = -math.huge, nil, 0, false, false, -1
			local Last = R1.HumanoidRootPart.Position
			t0 = os.clock()
			while os.clock() - t0 < 9 and R1.Parent do
				if not Out and os.clock() - LastAlarm > 0.5 then PS.Alarm(R1, P) LastAlarm = os.clock() end
				task.wait(0.1)
				local Pos = R1.HumanoidRootPart.Position
				Jump = math.max(Jump, (Pos - Last).Magnitude)
				Last = Pos
				local X = Past()
				if X > MaxPast then MaxPast, FarPos = X, Pos end
				if X > RS.Leash then Out = true end
				if Out and PS.PhaseOf(R1) == "Cautious" then GaveUp = true end
			end
			T.True(MaxPast > RS.Leash, ("it chased out past its leash (%.1f studs past its stretch)"):format(MaxPast))
			T.True(MaxPast < RS.Overshoot and Jump < 6, ("never put home by force (furthest %.1f past, biggest step %.1f)"):format(MaxPast, Jump))
			T.True(GaveUp, "it gave up the chase (Cautious)")
			local Now = R1.HumanoidRootPart.Position
			T.True(FarPos ~= nil and Flat(Now - Home) < Flat(FarPos - Home) - 5,
				("it walked home by itself (%.0f -> %.0f studs from home)"):format(FarPos and Flat(FarPos - Home) or -1, Flat(Now - Home)))
			T.True(ES.Active[R1] ~= nil and ES.Active[R1].Target == nil, "and has no target")
			T.True(C.Humanoid.Health >= Hp, "the player was never reached" .. (Gun and " (all rolled guns: it ran AIPassive)" or ""))
		end)
		if C:FindFirstChild("HumanoidRootPart") then C.HumanoidRootPart.Anchored = false end
		RS.Force, RS.ForceAt = nil, nil
		RS.ClearEncounter(E)
		RS.ResetRolls(P)
		OffRoad(P)
		T.True(Ok, tostring(Err))
	end,

	-- turning back out of the passage does nothing; the old "Set off" request is gone
	TurningBackDoesNothing = function(T)
		local RS, TS = require(SSS.RoadService), require(SSS.TravelService)
		local PS = require(SSS.ProgressionService)
		local P = game.Players:GetPlayers()[1]
		local C = Ready(P)
		Idle(P)
		local Got
		local Conn = TS.Arrived.Event:Connect(function(Who) if Who == P then Got = true end end)
		local Ok, Err = pcall(function()
			OffRoad(P)
			Stand(P, Vector3.new(30, 1, -270), Vector3.new(1, 0, 0)) -- on the passage, 22 in from its mouth
			task.wait(1)
			T.Eq(RS.PassageAt(C.HumanoidRootPart.Position), ROUTE, "on the passage")
			T.Eq(RS.Walking(P, ROUTE), 1, "walking it")
			C.Humanoid:MoveTo(Vector3.new(-2, 0.1, -268)) -- back out onto the hub road
			local t0 = os.clock()
			while RS.PassageAt(C.HumanoidRootPart.Position) and os.clock() - t0 < 5 do task.wait(0.1) end
			T.True(RS.PassageAt(C.HumanoidRootPart.Position) == nil, "walked back off it")
			task.wait(1)
			T.True(not RS.OnRoad(P) and not Got, "nothing happened")
			T.True(RS.Walking(P, ROUTE) == nil, "the walk ended")
			local D = PS.GetData(P)
			T.True(D and D.Travel and D.Travel.Trip == nil, "no Trip written")
			T.True(RS.Request == nil, "the old Set off is gone")
		end)
		Conn:Disconnect()
		T.True(Ok, tostring(Err))
	end,
}

-- Play_Road (World plan 1 Task 8b, roads on foot): run in a Studio Play server through ServerStorage.LMRunSuite.
-- Studio can't teleport: crossing the threshold loops back to this place's own RoadStart (TravelService's loopback).
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

-- the road point under a threshold / encounter marker (they stand 13 / 12 above the road)
local function RoadUnder(Part, Up)
	return Part.Position - Vector3.new(0, Up, 0)
end

-- stand P on the road at Pos facing Dir (root 3 above the road)
local function Stand(P, Pos, Dir)
	local C = P.Character
	C:PivotTo(CFrame.lookAt(Pos + Vector3.new(0, 3, 0), Pos + Vector3.new(0, 3, 0) + Dir))
	C.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
end

-- park P on the RoadStart arrival (on the passage, clear of the threshold and of every encounter), facing in
local function Park(P)
	local TS = require(SSS.TravelService)
	local Start = TS.ArrivalPoint("RoadStart")
	Stand(P, Start.Position - Vector3.new(0, 0.5, 0), Start.CFrame.LookVector)
end

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
	-- walking into the threshold crosses (Studio: loops back) and arrives at RoadStart, with the Trip written into
	-- the save first and Arrived fired for the road; a fight is no bar; arriving doesn't chain into leaving again
	WalkingIntoTheThresholdCrosses = function(T)
		local RS, TS = require(SSS.RoadService), require(SSS.TravelService)
		local PS = require(SSS.ProgressionService)
		local P = game.Players:GetPlayers()[1]
		local C = Ready(P)
		Idle(P)
		local Th, Start = Tagged("RenseiRoadThreshold"), TS.ArrivalPoint("RoadStart")
		T.True(Th ~= nil and Start ~= nil, "the threshold and the RoadStart arrival exist")
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
			C:SetAttribute("InCombat", true) -- fleeing over the threshold is allowed
			local Dir = Th.CFrame.LookVector
			Stand(P, RoadUnder(Th, 13) - Dir * 16, Dir)
			task.wait(1) -- the client owns the character: let the move land before walking
			C.Humanoid:MoveTo(RoadUnder(Th, 13) + Dir * 3)
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

	-- nobody escapes a knock, a grip or a carry by road
	DownOrHeldCantCross = function(T)
		local RS, TS = require(SSS.RoadService), require(SSS.TravelService)
		local P = game.Players:GetPlayers()[1]
		local C = Ready(P)
		Idle(P)
		local Th = Tagged("RenseiRoadThreshold")
		local Got
		local Conn = TS.Arrived.Event:Connect(function(Who) if Who == P then Got = true end end)
		local Ok, Err = pcall(function()
			for _, Name in ipairs(HELD) do
				Park(P)
				task.wait(0.3)
				C:SetAttribute(Name, Name == "Knocked" and true or "Someone")
				Stand(P, RoadUnder(Th, 13), Th.CFrame.LookVector) -- right in the threshold
				task.wait(0.8)
				T.True(not RS.OnRoad(P) and not Got, Name .. ": didn't cross")
				Park(P) -- out first, then let go (else they'd cross from where they stand)
				task.wait(0.3)
				C:SetAttribute(Name, nil)
			end
		end)
		Conn:Disconnect()
		for _, Name in ipairs(HELD) do C:SetAttribute(Name, nil) end
		Idle(P)
		T.True(Ok, tostring(Err))
	end,

	-- who crosses with you: party members on the same passage within 40 studs, fit to go. Studio has one player, so the
	-- party is three stand-in members with R6 rigs (PartyService.Get is wrapped for the test).
	PartyWithin40CrossesWithYou = function(T)
		local RS, PartyService = require(SSS.RoadService), require(SSS.PartyService)
		local P = game.Players:GetPlayers()[1]
		Ready(P)
		Idle(P)
		local Old = PartyService.Get
		local Made = {}
		local Ok, Err = pcall(function()
			local Mid = Tagged("RenseiRoadEncounter", "Encounter1")
			local Road = RoadUnder(Mid, 12)
			local Dir = Mid.CFrame.LookVector
			Stand(P, Road, Dir)
			task.wait(0.3)
			local function Member(Name, Pos)
				local M = Rig(Name, Pos)
				table.insert(Made, M)
				return {Name = Name, UserId = -9000 - #Made, Parent = game.Players, Character = M}
			end
			local Near = Member("Near", Road + Dir * 25)
			local Far = Member("Far", Road + Dir * 60)
			local Down = Member("Down", Road - Dir * 15)
			Down.Character:SetAttribute("Knocked", true)
			local Off = Member("OffRoad", Road + Vector3.new(0, 0, -30)) -- 30 away, but in the fields south of the passage
			T.True(RS.PassageAt(Near.Character.HumanoidRootPart.Position) == ROUTE, "Near stands on the passage")
			T.True(RS.PassageAt(Off.Character.HumanoidRootPart.Position) == nil, "OffRoad is off the passage")
			local Party = {Leader = P, Members = {P, Near, Far, Down, Off}}
			PartyService.Get = function(Who) if Who == P or Who == Near or Who == Far or Who == Down or Who == Off then return Party end return Old(Who) end
			local Group, Left = RS.Gather(P, ROUTE)
			local In = {}
			for _, M in ipairs(Group) do In[M] = true end
			T.True(In[P] and In[Near], "you and the member 25 studs along cross together")
			T.True(not In[Far], "a member 60 studs back doesn't")
			T.True(not In[Down], "a knocked member doesn't")
			T.True(not In[Off], "a member off the passage doesn't")
			T.Eq(#Left, 3, "three left behind, each told why")
		end)
		PartyService.Get = Old
		for _, M in ipairs(Made) do M:Destroy() end
		T.True(Ok, tostring(Err))
	end,

	-- an encounter (forced) brings bandits out ahead; they're leashed to their stretch, the roll is spent for this
	-- crossing, and they're removed once nobody is near (Studio TimeScale)
	ForcedEncounterSpawnsAheadAndClears = function(T)
		local RS, ES = require(SSS.RoadService), require(SSS.EnemyService)
		local P = game.Players:GetPlayers()[1]
		Ready(P)
		Idle(P)
		local E = Tagged("RenseiRoadEncounter", "Encounter1")
		local Ok, Err = pcall(function()
			Park(P)
			task.wait(0.5)
			RS.ResetRolls(P)
			RS.TimeScale = 0.05 -- ClearAfter 30 s -> 1.5 s
			RS.Force = true
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
			-- leashed: one dragged 120 studs off is put back on its stretch
			local R1 = Rigs[1]
			R1:PivotTo(E.CFrame + E.CFrame.RightVector * 120)
			task.wait(0.8)
			local L = E.CFrame:PointToObjectSpace(R1.HumanoidRootPart.Position)
			T.True(math.abs(L.X) <= E.Size.X / 2 + RS.Leash and math.abs(L.Z) <= E.Size.Z / 2 + RS.Leash, "a stray bandit is put back")
			-- the crossing's roll is spent: in and out and in again rolls nothing more
			RS.Force = true
			Stand(P, From - Dir * 40, Dir)
			task.wait(0.5)
			Stand(P, From, Dir)
			task.wait(0.5)
			T.True(RS.Force == true, "no second roll this crossing")
			RS.Force = nil
			-- nobody near for ClearAfter: they go (removed, no reward)
			Park(P) -- 150+ studs away
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
		RS.Force = nil
		RS.TimeScale = 1
		RS.ClearEncounter(E)
		RS.ResetRolls(P)
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
			local Gate = Tagged("RenseiRoadPassage")
			T.True(Gate ~= nil, "the passage exists")
			Stand(P, Vector3.new(30, 1, -270), Vector3.new(1, 0, 0)) -- on the passage, 22 in from its mouth
			task.wait(1)
			T.Eq(RS.PassageAt(C.HumanoidRootPart.Position), ROUTE, "on the passage")
			C.Humanoid:MoveTo(Vector3.new(-2, 0.1, -268)) -- back out onto the hub road
			local t0 = os.clock()
			while RS.PassageAt(C.HumanoidRootPart.Position) and os.clock() - t0 < 5 do task.wait(0.1) end
			T.True(RS.PassageAt(C.HumanoidRootPart.Position) == nil, "walked back off it")
			task.wait(1)
			T.True(not RS.OnRoad(P) and not Got, "nothing happened")
			local D = PS.GetData(P)
			T.True(D and D.Travel and D.Travel.Trip == nil, "no Trip written")
			local Go, Why = RS.Request(P, ROUTE)
			T.True(not Go and type(Why) == "string", "the old Set off is gone (" .. tostring(Why) .. ")")
		end)
		Conn:Disconnect()
		T.True(Ok, tostring(Err))
	end,
}

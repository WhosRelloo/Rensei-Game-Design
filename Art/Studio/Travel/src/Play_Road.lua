local SSS = game.ServerScriptService
local ROUTE = "RoadLindenmoorFoundry"

-- a living character to test with (a death test respawns it)
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

local function ExitOf(Route)
	for _, E in ipairs(game:GetService("CollectionService"):GetTagged("RenseiRoadExit")) do
		if E:GetAttribute("Route") == Route and E:IsDescendantOf(workspace) then return E end
	end
	return nil
end

return {
	NoAmbushJourneyArrives = function(T)
		local RS, TS = require(SSS.RoadService), require(SSS.TravelService)
		local P = game.Players:GetPlayers()[1]
		local Got
		local C = TS.Arrived.Event:Connect(function(Who) if Who == P then Got = true end end)
		T.Eq(RS.Journey(P, "RoadLindenmoorFoundry", false), "loopback")
		local t0 = os.clock()
		while not Got and os.clock() - t0 < 5 do task.wait(0.1) end
		C:Disconnect()
		T.True(Got, "arrived")
	end,
	AmbushStopsInTheArenaThenContinues = function(T)
		local RS = require(SSS.RoadService)
		local P = game.Players:GetPlayers()[1]
		T.Eq(RS.Journey(P, "RoadLindenmoorFoundry", true), "ambush")
		local Arena = workspace:FindFirstChild("AmbushArena", true)
		T.True((P.Character.HumanoidRootPart.Position - Arena.Position).Magnitude < 40, "in the arena")
		RS.ClearArena(P) -- test hook: count the fight as won
		task.wait(1)
		T.True(not RS.InAmbush(P), "journey continued")
	end,
	-- added (task 8): nobody walks out of the arena before the fight is won; the enemies are kept in too
	CantLeaveTheArenaBeforeTheFightIsWon = function(T)
		local RS, ES = require(SSS.RoadService), require(SSS.EnemyService)
		local P = game.Players:GetPlayers()[1]
		Ready(P)
		local Ok, Err = pcall(function()
			T.Eq(RS.Journey(P, ROUTE, true), "ambush")
			local Arena = workspace:FindFirstChild("AmbushArena", true)
			local Rigs = RS.EnemiesOf(P)
			T.True(#Rigs >= 2 and #Rigs <= 3, "2-3 enemies (" .. #Rigs .. ")")
			for _, Rig in ipairs(Rigs) do
				T.True(ES.Active[Rig] ~= nil, "a live EnemyService enemy")
				Rig:SetAttribute("AIPassive", true)
			end
			P.Character:PivotTo(Arena.CFrame + Vector3.new(0, 3, 120)) -- walked off down the road
			Rigs[1]:PivotTo(Arena.CFrame + Vector3.new(0, 3, -120))
			task.wait(1)
			T.True((P.Character.HumanoidRootPart.Position - Arena.Position).Magnitude < 40, "put back in the arena")
			T.True(RS.InAmbush(P), "still in the ambush")
			T.True((Rigs[1].HumanoidRootPart.Position - Arena.Position).Magnitude < 40, "the enemy is put back too")
		end)
		RS.ClearArena(P)
		T.True(Ok, tostring(Err))
	end,
	-- added (task 8): beating every enemy continues the journey (ArenaCleared, then the arrival); the rigs are gone
	WinningTheFightContinuesTheJourney = function(T)
		local RS, TS, ES = require(SSS.RoadService), require(SSS.TravelService), require(SSS.EnemyService)
		local P = game.Players:GetPlayers()[1]
		Ready(P)
		local Got, Cleared
		local C1 = TS.Arrived.Event:Connect(function(Who) if Who == P then Got = true end end)
		local C2 = RS.ArenaCleared.Event:Connect(function(Route, List) if table.find(List, P) then Cleared = Route end end)
		local Ok, Err = pcall(function()
			T.Eq(RS.Journey(P, ROUTE, true), "ambush")
			local Rigs = RS.EnemiesOf(P)
			for _, Rig in ipairs(Rigs) do Rig:SetAttribute("AIPassive", true) end
			for _, Rig in ipairs(Rigs) do Rig.Humanoid.Health = 0 end
			task.wait(0.5)
			T.True(RS.InAmbush(P), "a moment before the road")
			local t0 = os.clock()
			while not Got and os.clock() - t0 < RS.ClearDelay + 4 do task.wait(0.1) end
			T.Eq(Cleared, ROUTE, "ArenaCleared fired")
			T.True(Got, "arrived")
			T.True(not RS.InAmbush(P), "journey continued")
			for _, Rig in ipairs(Rigs) do T.True(Rig.Parent == nil and ES.Active[Rig] == nil, "enemies removed") end
		end)
		C1:Disconnect()
		C2:Disconnect()
		RS.ClearArena(P)
		T.True(Ok, tostring(Err))
	end,
	-- added (task 8): dying in the arena: respawn in town, off the journey (no travel), the empty arena is cleared
	DeathInTheArenaDropsYouWithoutTravel = function(T)
		local RS, TS, ES = require(SSS.RoadService), require(SSS.TravelService), require(SSS.EnemyService)
		local P = game.Players:GetPlayers()[1]
		Ready(P)
		local Got
		local C = TS.Arrived.Event:Connect(function(Who) if Who == P then Got = true end end)
		local Ok, Err = pcall(function()
			T.Eq(RS.Journey(P, ROUTE, true), "ambush")
			local Arena = workspace:FindFirstChild("AmbushArena", true)
			local Rigs = RS.EnemiesOf(P)
			for _, Rig in ipairs(Rigs) do Rig:SetAttribute("AIPassive", true) end
			local Old = P.Character
			Old.Humanoid.Health = 0
			task.wait(0.5)
			T.True(not RS.InAmbush(P), "off the journey at death")
			for _, Rig in ipairs(Rigs) do T.True(Rig.Parent == nil and ES.Active[Rig] == nil, "the empty arena's enemies are removed") end
			local t1 = os.clock()
			while (P.Character == Old or not Ready(P)) and os.clock() - t1 < 12 do task.wait(0.2) end
			local New = P.Character
			T.True(New ~= Old and New:FindFirstChild("HumanoidRootPart"), "respawned")
			task.wait(1.5)
			T.True((New.HumanoidRootPart.Position - Arena.Position).Magnitude > 60, "in town, not pulled back into the arena")
			T.True(not Got, "no travel")
		end)
		C:Disconnect()
		RS.ClearArena(P)
		Ready(P)
		T.True(Ok, tostring(Err))
	end,
	-- added (task 8): the exit, its distance from the arrival gate, and the server's checks on "Set off"
	SetOffIsCheckedOnTheServer = function(T)
		local RS, TS = require(SSS.RoadService), require(SSS.TravelService)
		local P = game.Players:GetPlayers()[1]
		Ready(P)
		local Got
		local C = TS.Arrived.Event:Connect(function(Who) if Who == P then Got = true end end)
		local Ok, Err = pcall(function()
			local Exit = ExitOf(ROUTE)
			T.True(Exit ~= nil, "Lindenmoor's road exit")
			T.Eq(Exit:GetAttribute("Arrive"), "SouthGate", "arrives at the Foundry's south gate")
			T.True(Exit:FindFirstChild("RoadPrompt") ~= nil, "a prompt, not a touch")
			local Gate = TS.ArrivalPoint("NorthGate")
			T.True((Gate.Position - Exit.Position).Magnitude > RS.PromptReach + 4, "arriving at the gate is out of the exit's reach")
			local Ray = RaycastParams.new()
			Ray.RespectCanCollide = true
			local Hit = workspace:Raycast(Gate.Position + Vector3.new(0, 10, 0), Vector3.new(0, -40, 0), Ray)
			T.True(Hit and math.abs(Gate.Position.Y - Gate.Size.Y / 2 - Hit.Position.Y) < 1, "the NorthGate arrival sits on the road")
			P.Character:PivotTo(Gate.CFrame + Vector3.new(0, 3, 0))
			task.wait(0.2)
			local Far, Why = RS.Request(P, ROUTE)
			T.True(not Far and type(Why) == "string", "refused away from the exit")
			T.True(not RS.Request(P, "LindenmoorFoundry"), "a rail route is not a road")
			T.True(not RS.Request(P, {}), "junk is refused")
			P.Character:PivotTo(Exit.CFrame)
			task.wait(0.2)
			RS.Force = false
			local Go, Why2 = RS.Request(P, ROUTE)
			T.True(Go, "at the exit: " .. tostring(Why2))
			T.True(not RS.Request(P, ROUTE), "not twice in a row")
			local t0 = os.clock()
			while not Got and os.clock() - t0 < 5 do task.wait(0.1) end
			T.True(Got, "arrived")
		end)
		RS.Force = nil
		C:Disconnect()
		T.True(Ok, tostring(Err))
	end,
}

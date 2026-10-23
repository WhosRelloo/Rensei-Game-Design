-- S2 acceptance (spec §17.11) inside the game VM: sound through walls, Agents hearing alchemy, crouching, light,
-- and the leash fix. Perception is stepped by hand; test parts are removed afterwards.
local SSS = game.ServerScriptService
local PS = require(SSS.PerceptionService)
local ES = require(SSS.EnemyService)
local NS = require(SSS.NoiseService)
local LS = require(SSS.LightService)
local WorldClock = require(SSS.WorldClock) -- Region Foundation Task 2: the clock moves, so the test holds it
local P = require(game.ReplicatedStorage.Modules.Data.Rensei.Perception)
local Lighting = game:GetService("Lighting")
local Player = game.Players:GetPlayers()[1]
local C = Player.Character

local function Find(Type)
	for Rig in pairs(ES.Active) do
		local S = PS.Npcs[Rig]
		if S and S.Type == Type and Rig:FindFirstChild("HumanoidRootPart") then return Rig, S end
	end
end
local function Run(Seconds) for _ = 1, math.floor(Seconds / 0.2 + 0.5) do PS.Step(0.2) end end
local function Put(Rig, Local)
	local Root = Rig.HumanoidRootPart
	local Pos = Root.Position + Root.CFrame:VectorToWorldSpace(Local)
	C:PivotTo(CFrame.lookAt(Pos, Vector3.new(Root.Position.X, Pos.Y, Root.Position.Z)))
	C.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
	task.wait(0.15)
end
local Temp = {}
local function Part(Props)
	local X = Instance.new("Part")
	X.Anchored = true
	for K, V in pairs(Props) do X[K] = V end
	X.Parent = workspace
	table.insert(Temp, X)
	return X
end
local function Guard(Rig, Body)
	local Home = C:GetPivot()
	PS.SetAuto(false); LS.SetAuto(false)
	if Rig then Rig:SetAttribute("AIPassive", true); PS.Reset(Rig) end
	local Ok, Err = pcall(Body)
	for _, X in ipairs(Temp) do X:Destroy() end
	table.clear(Temp)
	if Rig then PS.Reset(Rig); Rig:SetAttribute("AIPassive", nil) end
	C:SetAttribute("Crouching", nil)
	PS.SetAuto(true); LS.SetAuto(true)
	C:PivotTo(Home)
	if not Ok then error(Err, 0) end
end

return {
	WallMuffles = function(T)
		local Rig = Find("Grunt")
		T.True(Rig ~= nil, "a Grunt")
		Guard(Rig, function()
			local Head = Rig.Head.Position
			local Spot = Head + Vector3.new(10, 0, 0)
			T.True(PS.Hear(Spot, 12, nil) >= 1 and PS.PhaseOf(Rig) == "Suspicious", "heard in the open at 10 of 12")
			PS.Reset(Rig)
			Part({Size = Vector3.new(1, 12, 12), CFrame = CFrame.new(Head + Vector3.new(5, 0, 0))})
			T.Eq(PS.Walls(Spot, Head, {Rig}), 1, "one wall between")
			PS.Hear(Spot, 12, nil)
			T.Eq(PS.PhaseOf(Rig), "Unaware", "12 through a wall reaches 7.2: not heard at 10")
			PS.Hear(Spot, 20, nil)
			T.Eq(PS.PhaseOf(Rig), "Suspicious", "a hit (20) through one wall reaches 12")
		end)
	end,
	RunningOnMetalCarriesFurther = function(T)
		local Rig = Find("Grunt")
		Guard(Rig, function()
			local Spot = Rig.Head.Position + Vector3.new(0, 0, 14)
			PS.Hear(Spot, P.StepNoise("Grass", 1, false), nil)
			T.Eq(PS.PhaseOf(Rig), "Unaware", "walking on grass at 14: unheard")
			PS.Hear(Spot, P.StepNoise("Metal", 1.5, false), nil)
			T.Eq(PS.PhaseOf(Rig), "Suspicious", "running on metal at 14: heard")
			T.True((PS.Goal(Rig) - Spot).Magnitude < 0.01, "goes to the spot")
		end)
	end,
	AgentsHearAlchemyTwiceAsFar = function(T)
		local Rig = Find("Agent")
		T.True(Rig ~= nil, "an Agent-type NPC (a camp alchemist)")
		Guard(Rig, function()
			local Spot = Rig.Head.Position + Vector3.new(0, 0, 45)
			PS.Hear(Spot, 30, nil)
			T.Eq(PS.PhaseOf(Rig), "Unaware", "a 30 sound at 45")
			PS.Hear(Spot, 30, "Cast")
			T.Eq(PS.PhaseOf(Rig), "Suspicious", "a cast (30 x2) at 45")
		end)
	end,
	GunshotPullsTheCamp = function(T)
		local Rig = Find("Grunt")
		Guard(Rig, function()
			NS.Log = {}
			local Heard = NS.Emit(Rig.Head.Position + Vector3.new(0, 0, 50), "Gunshot", nil)
			NS.Log = nil
			T.True(Heard >= 1, "heard 50 studs off")
			T.Eq(PS.PhaseOf(Rig), "Suspicious")
		end)
	end,
	CrouchHalvesNoticing = function(T)
		local Rig = Find("Grunt")
		Guard(Rig, function()
			C:SetAttribute("Exposure", 1)
			Put(Rig, Vector3.new(0, 0, -12))
			Run(0.6)
			local Stand = PS.Awareness(Rig, Player)
			PS.Reset(Rig)
			C:SetAttribute("Crouching", true)
			Run(0.6)
			local Crouch = PS.Awareness(Rig, Player)
			T.True(Stand > 0.1, "noticed standing")
			T.Near(Crouch / Stand, 0.5, 0.08, "crouching: half")
		end)
	end,
	ShadowHidesYou = function(T)
		local Rig = Find("Grunt")
		Guard(Rig, function()
			Put(Rig, Vector3.new(0, 0, -12))
			C:SetAttribute("Exposure", 1)
			Run(0.6)
			local Lit = PS.Awareness(Rig, Player)
			PS.Reset(Rig)
			C:SetAttribute("Exposure", 0)
			Run(0.6)
			local Dark = PS.Awareness(Rig, Player)
			T.Near(Dark / Lit, 0.2 / 1.2, 0.05, "deep shadow x0.2 vs bright x1.2")
		end)
	end,
	LampExposureAndShadow = function(T)
		local WasHeld = WorldClock.IsHeld() and Lighting.ClockTime
		Guard(nil, function()
			WorldClock.Hold(0) -- night
			local Base = Vector3.new(0, 400, 0) -- open sky, far above the map
			T.Near(LS.ExposureAt(Base, {}), P.NightFloor, 1e-6, "night, no lamp")
			local Lamp = Part({Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(Base + Vector3.new(4, 0, 0)), CanCollide = false})
			local L = Instance.new("PointLight"); L.Range = 16; L.Brightness = 1; L.Parent = Lamp
			Lamp:SetAttribute("LightRadius", 16); Lamp:SetAttribute("LightStrength", 1)
			game:GetService("CollectionService"):AddTag(Lamp, LS.Tag)
			task.wait()
			T.Near(LS.ExposureAt(Base, {}), 0.75, 0.01, "4 studs from a 16-stud lamp")
			local Wall = Part({Size = Vector3.new(0.5, 6, 6), CFrame = CFrame.new(Base + Vector3.new(1, 0, 0))})
			T.Near(LS.ExposureAt(Base, {}), P.NightFloor, 1e-6, "a wall between: shadow")
			Wall:Destroy()
			L.Enabled = false
			T.Near(LS.ExposureAt(Base, {}), P.NightFloor, 1e-6, "lamp put out")
			WorldClock.Hold(14.5)
			T.Near(LS.ExposureAt(Base, {}), 1, 1e-6, "afternoon in the open")
			Part({Size = Vector3.new(8, 1, 8), CFrame = CFrame.new(Base + Vector3.new(0, 6, 0))})
			T.Near(LS.ExposureAt(Base, {}), P.IndoorDay, 1e-6, "afternoon under a roof")
		end)
		if WasHeld then WorldClock.Hold(WasHeld) else WorldClock.Release() end
	end,
	LeashStopsTheChurn = function(T)
		local Rig = Find("Grunt")
		Guard(Rig, function()
			Put(Rig, Vector3.new(0, 0, -12))
			PS.Lose(Rig, Rig.HumanoidRootPart.Position, 5) -- a 5-stud leash: the player stands beyond it
			Run(2)
			T.True(PS.Awareness(Rig, Player) < 0.01, "beyond the leash: not re-noticed")
			T.True(PS.PhaseOf(Rig) ~= "Alert", "no Alert / Cautious flip-flop")
			PS.Alarm(Rig, Player)
			T.Eq(PS.PhaseOf(Rig), "Alert", "a hit still alarms it")
		end)
	end,
	CallWithoutFocusIsSafe = function(T)
		local Rig, S = Find("Grunt")
		Guard(Rig, function()
			S.Phase = "Alert"; S.Focus = nil; S.SearchUntil = nil; S.LastKnown = Rig.HumanoidRootPart.Position
			local Ok, Err = pcall(PS.Step, 0.2)
			T.True(Ok, "no error with the focus gone: " .. tostring(Err))
		end)
	end,
}

-- Play_Swim (swim revamp Task 3, 2026-10-26): the server's swim rules, in the Play VM
-- (game.ServerStorage.LMRunSuite:Invoke("Play_Swim")). Spots come from SwimKit (hard-coded from Task 1's survey).
-- Drowning and every other water rule is tested on an anchored test rig, never on the real player; the one real-
-- player case (SprintRefusedOnLand) only asks for a sprint on land. Every test removes its rig and clears what it set.
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SwimKit = require(ServerStorage.RenseiTests.SwimKit)
local Sw = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig).Swim
local MovementState = require(ReplicatedStorage.Modules.Managers.MovementState)
local function SwimService() return require(ServerScriptService:WaitForChild("SwimService", 10)) end

-- a rig at the place's main spot with its head Below studs under the surface; runs Fn(Rig, Spot), always cleans up
local function WithRig(T, Below, Fn)
	local Spot = SwimKit.Main()
	if not Spot then T.True(true, "no swim spot in this place") return end
	local Rig = SwimKit.Rig(Spot.At - Vector3.new(0, Below, 0))
	local Ok, Err = pcall(Fn, Rig, Spot)
	SwimKit.Drop(Rig)
	if not Ok then error(Err, 0) end
end

local function Steps(Rig, N)
	for _ = 1, N do SwimService().Step(Rig, true) end
end

return {
	DepthAtTheDiveSite = function(T)
		local S = SwimKit.Spots()
		local Any = false
		for _, Name in {"PondDeep", "MillPond", "GorgePool"} do
			local Spot = S[Name]
			if Spot then
				Any = true
				local Depth, Top = SwimService().WaterDepthAt(Spot.At)
				T.Near(Depth, Spot.Depth, 0.5, Name .. " depth")
				T.True(Top ~= nil and math.abs(Top - Spot.At.Y) < 0.5, Name .. " surface: " .. tostring(Top))
			end
		end
		T.True(Any, "this place has a surveyed swim spot")
		T.Eq(SwimService().WaterDepthAt(Vector3.new(0, 500, 0)), 0, "no water in the sky")
	end,
	SubmergedFollowsTheHead = function(T)
		WithRig(T, 3, function(Rig, Spot)
			Steps(Rig, 3)
			T.Eq(Rig:GetAttribute("Submerged"), true, "head 3 under")
			SwimKit.PutHead(Rig, Spot.At + Vector3.new(0, 1, 0))
			Steps(Rig, 1)
			T.Eq(Rig:GetAttribute("Submerged"), true, "one check out is not enough")
			Steps(Rig, 1)
			T.Eq(Rig:GetAttribute("Submerged"), nil, "two checks out")
		end)
	end,
	BreathDrainsForACarrier = function(T)
		WithRig(T, 3, function(Rig)
			Rig:SetAttribute("Carrying", "x")
			Steps(Rig, 7)
			T.True(MovementState.Get(Rig) ~= "Swim", "a carrier can't be in the Swim state (MovementState.Blocking)")
			local B = Rig:GetAttribute("Breath")
			T.True(type(B) == "number" and B < Sw.BreathMax, "breath drained: " .. tostring(B))
		end)
	end,
	DrowningHurtsTheRig = function(T)
		WithRig(T, 3, function(Rig)
			local H = Rig:FindFirstChildOfClass("Humanoid")
			local Before = H.Health
			Rig:SetAttribute("Breath", 0.01)
			Steps(Rig, 1)
			T.Eq(Rig:GetAttribute("Drowning"), true, "drowning")
			local Want = math.max(Sw.DrownDamage, H.MaxHealth * Sw.DrownFraction)
			T.Near(Before - H.Health, Want, 1, "one drowning tick")
			T.True(H.Health > 0, "still alive")
		end)
	end,
	SprintRefusedOnLand = function(T)
		local P = Players:GetPlayers()[1]
		local C = P and P.Character
		if not C then T.True(true, "no player") return end
		if C:GetAttribute("Traversal") == "Swim" then T.True(true, "the player is swimming: skipped") return end
		local Swim = require(ServerScriptService.ServerHandler.Requests.Swim)
		Swim(P, true)
		local Got = C:GetAttribute("SwimSprint")
		C:SetAttribute("SwimSprint", nil)
		T.Eq(Got, nil, "no swim sprint on land")
	end,
	SpeedStrikes = function(T)
		WithRig(T, 1.5, function(Rig, Spot)
			Steps(Rig, 1)
			T.Eq(MovementState.Get(Rig), "Swim", "the rig swims")
			Rig:SetAttribute("SwimSprint", true)
			-- a slow swimmer: 1 stud a step keeps 0
			for I = 1, 3 do
				SwimKit.PutHead(Rig, Spot.At - Vector3.new(0, 1.5, 0) + Vector3.new(I, 0, 0))
				Steps(Rig, 1)
				T.Eq(Rig:GetAttribute("SwimSpeedStrikes"), nil, "1 stud: no strike")
			end
			-- three 12-stud jumps in a row (back to back, so far over 8 studs + a step's allowance): strikes 1, 2, 3 ->
			-- the sprint stops and the count resets. The rig hops between +3 and -9 studs in x from the spot, both
			-- surveyed deep columns in each place.
			for I = 1, 3 do
				SwimKit.PutHead(Rig, Spot.At - Vector3.new(0, 1.5, 0) + Vector3.new(I % 2 == 1 and -9 or 3, 0, 0))
				local Before = (Rig:GetAttribute("SwimSpeedStrikes") or 0)
				T.Eq(Before, I - 1, "strikes before jump " .. I)
				T.Eq(Rig:GetAttribute("SwimSprint"), true, "still sprinting before jump " .. I)
				Steps(Rig, 1)
				if I < Sw.SpeedStrikes then T.Eq(Rig:GetAttribute("SwimSpeedStrikes"), Before + 1, "strike " .. I) end
			end
			-- the third strike reached SpeedStrikes: the count reset and the sprint stopped (a skipped check would
			-- reset the count too, but never touches SwimSprint)
			T.Eq(Rig:GetAttribute("SwimSpeedStrikes"), nil, "reset after the limit")
			T.Eq(Rig:GetAttribute("SwimSprint"), nil, "the sprint stopped")
		end)
	end,
}

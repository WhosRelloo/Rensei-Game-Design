-- S1 acceptance (spec §17.11), inside the game VM. Freezes the perception loop and steps it by hand so the
-- timings are exact; makes the test Grunt passive so it never swings at the tester.
local PS = require(game.ServerScriptService.PerceptionService)
local ES = require(game.ServerScriptService.EnemyService)
local P = require(game.ReplicatedStorage.Modules.Data.Rensei.Perception)
local Player = game.Players:GetPlayers()[1]
local C = Player.Character
local function FindGrunt()
	for Rig in pairs(ES.Active) do
		if Rig:GetAttribute("EnemyType") == "Grunt" and PS.Tracks(Rig) then return Rig end
	end
end
local function Run(Seconds) for _ = 1, math.floor(Seconds / 0.2 + 0.5) do PS.Step(0.2) end end
local function Put(Rig, Local) -- Local offset in the rig's space (-Z = in front)
	local Root = Rig.HumanoidRootPart
	local Pos = Root.Position + Root.CFrame:VectorToWorldSpace(Local)
	C:PivotTo(CFrame.lookAt(Pos, Root.Position))
	C.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
	task.wait(0.15)
end
return {
	S1 = function(T)
		local Rig = FindGrunt()
		T.True(Rig ~= nil, "a Grunt is registered with PerceptionService")
		local Home = C:GetPivot()
		Rig:SetAttribute("AIPassive", true)
		PS.SetAuto(false)
		PS.Reset(Rig) -- whatever it noticed before the test
		local Ok, Err = pcall(function()
			-- 1. behind it: unaware
			Put(Rig, Vector3.new(0, 0, 12))
			Run(3)
			T.Eq(PS.PhaseOf(Rig), "Unaware", "behind")
			T.True(PS.Awareness(Rig, Player) < 0.05, "behind: no awareness")
			-- 2. in front at 12 studs: fills at about the expected rate (Grunt 0.8 x (1 - 0.75 x 12/30) = 0.56/s)
			Put(Rig, Vector3.new(0, 0, -12))
			Run(1)
			T.Near(PS.Awareness(Rig, Player), 0.56, 0.15, "fill rate in front")
			Run(1.4)
			T.Eq(PS.PhaseOf(Rig), "Alert", "alert once full")
			T.Eq(PS.Target(Rig), C, "fights the player it sees")
			-- 3. out of sight and range: after Memory it searches, then turns Cautious
			Put(Rig, Vector3.new(0, 0, 70))
			Run(P.Memory + 0.4)
			T.Eq(PS.Target(Rig), nil, "lost")
			T.True(PS.Goal(Rig) ~= nil, "searching a spot")
			Run(P.SearchTime + 0.4)
			T.Eq(PS.PhaseOf(Rig), "Cautious", "cautious after a failed search")
		end)
		PS.Reset(Rig)
		PS.SetAuto(true)
		Rig:SetAttribute("AIPassive", nil)
		C:PivotTo(Home)
		if not Ok then error(Err, 0) end
	end,
	HitAlarms = function(T)
		local Rig = FindGrunt()
		PS.SetAuto(false)
		PS.Reset(Rig)
		PS.Alarm(Rig, Player)
		T.Eq(PS.PhaseOf(Rig), "Alert")
		PS.Lose(Rig)
		PS.SetAuto(true)
	end,
	NoiseSendsItToLook = function(T)
		local Rig = FindGrunt()
		PS.SetAuto(false)
		PS.Reset(Rig)
		local Spot = Rig.HumanoidRootPart.Position + Vector3.new(6, 0, 0)
		PS.Noise(Spot, 20)
		T.Eq(PS.PhaseOf(Rig), "Suspicious")
		T.True((PS.Goal(Rig) - Spot).Magnitude < 0.01, "goes where the sound was")
		Run(P.InvestigateTime + 0.4)
		T.True(PS.PhaseOf(Rig) ~= "Suspicious", "gives up")
		PS.Lose(Rig)
		PS.SetAuto(true)
	end,
}

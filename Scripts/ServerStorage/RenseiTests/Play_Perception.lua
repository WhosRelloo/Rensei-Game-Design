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
local function FindWatcher()
	for _, M in ipairs(game:GetService("CollectionService"):GetTagged("RenseiWatcher")) do
		local St = PS.Npcs[M]
		if St and St.Combat == false and M:FindFirstChild("HumanoidRootPart") then return M, St end
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
local Suite = {
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
	-- a player the NPC has no sight rays left for this tick is not checked: awareness holds (no drain), and the
	-- skipped time is applied at the next check (groups don't hide each other)
	HoldsWhenNotChecked = function(T)
		local Rig = FindGrunt()
		Rig:SetAttribute("AIPassive", true)
		PS.SetAuto(false)
		PS.Reset(Rig)
		local Home = C:GetPivot()
		local Ok, Err = pcall(function()
			Put(Rig, Vector3.new(0, 0, -12))
			Run(0.4)
			local A1 = PS.Awareness(Rig, Player)
			T.True(A1 > 0.1, "noticing in front")
			P.RaysPerTick = 0
			Run(1)
			T.Near(PS.Awareness(Rig, Player), A1, 1e-6, "held while unchecked")
			P.RaysPerTick = 120
			Run(0.2)
			T.Near(PS.Awareness(Rig, Player), A1 + 0.56 * 1.2, 0.15, "catches up the skipped time")
		end)
		P.RaysPerTick = 120
		PS.Reset(Rig)
		PS.SetAuto(true)
		Rig:SetAttribute("AIPassive", nil)
		C:PivotTo(Home)
		if not Ok then error(Err, 0) end
	end,
	-- watchers (Combat = false) notice and stare, but sight alone never puts them in Alert
	WatcherNeverAlertsFromSight = function(T)
		local Rig = FindWatcher()
		T.True(Rig ~= nil, "a watcher is registered with PerceptionService")
		PS.SetAuto(false)
		PS.Reset(Rig)
		local Home = C:GetPivot()
		local Ok, Err = pcall(function()
			Put(Rig, Vector3.new(0, 0, -6))
			Run(5)
			T.True(PS.PhaseOf(Rig) ~= "Alert", "not Alert from sight")
			T.True(PS.Awareness(Rig, Player) <= 0.99 + 1e-9, "awareness capped below 1")
		end)
		PS.Reset(Rig)
		PS.SetAuto(true)
		C:PivotTo(Home)
		if not Ok then error(Err, 0) end
	end,
	-- a witness must have seen the player within Memory seconds; lingering awareness isn't sight (spec §4)
	PerceivedNeedsRecentSight = function(T)
		local Rig, State = FindWatcher()
		T.True(Rig ~= nil, "a watcher is registered with PerceptionService")
		PS.SetAuto(false)
		PS.Reset(Rig)
		local Home = C:GetPivot()
		local function Has()
			for _, S in ipairs(PS.Perceived(Player)) do if S == State then return true end end
			return false
		end
		local Ok, Err = pcall(function()
			Put(Rig, Vector3.new(0, 0, -6))
			Run(1)
			T.True(Has(), "perceived while seen")
			Put(Rig, Vector3.new(0, 0, 12))
			Run(P.Memory + 0.4)
			T.True(not Has(), "not perceived once out of sight past Memory")
		end)
		PS.Reset(Rig)
		PS.SetAuto(true)
		C:PivotTo(Home)
		if not Ok then error(Err, 0) end
	end,
}

-- Region Foundation Task 2 (fix round 1): the world clock moves, and at night LightService gives the player the
-- shadow floor, so these sight tests would pass or fail with the real time of day. Each test runs in full light
-- (Exposure 1, LightService's refresh paused), as Play_Stealth does, and the old value is put back after it.
local LightService = require(game.ServerScriptService.LightService)
for Name, Test in pairs(Suite) do
	Suite[Name] = function(T)
		local Was = C:GetAttribute("Exposure")
		LightService.SetAuto(false)
		C:SetAttribute("Exposure", 1)
		local Ok, Err = pcall(Test, T)
		C:SetAttribute("Exposure", Was)
		LightService.SetAuto(true)
		if not Ok then error(Err, 0) end
	end
end
return Suite

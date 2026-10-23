-- R3 acceptance (spec §16) inside the game VM, with the real services. The tester's profile is snapshotted and
-- restored by the harness around this suite. Perception is stepped by hand; the rumour / heat clocks are faked.
local SSS = game.ServerScriptService
local HS = require(SSS.HeatService)
local MS = require(SSS.MoralityService)
local RS = require(SSS.RumourService)
local PS = require(SSS.PerceptionService)
local PG = require(SSS.ProgressionService)
local StoryLogic = require(game.ReplicatedStorage.Modules.Data.Rensei.StoryLogic)
local CS = game:GetService("CollectionService")
local Player = game.Players:GetPlayers()[1]
local C = Player.Character

local function Data() return PG.GetData(Player) end
local function Fresh()
	local D = Data()
	D.Morality.Heat = {}
	D.Morality.Rumours = {}
	for _, Id in ipairs({"unlicensed_cast", "assault_townsfolk"}) do D.Morality.Deeds[Id] = nil end
	HS.SetClock(nil); RS.SetClock(nil)
	HS.Publish(Player, true)
end
local function Watcher(Name)
	for _, M in ipairs(CS:GetTagged("RenseiWatcher")) do if M.Name == Name then return M end end
end
local function Run(Seconds) for _ = 1, math.floor(Seconds / 0.2 + 0.5) do PS.Step(0.2) end end
local function Put(Rig, Local)
	local Root = Rig.HumanoidRootPart
	local Pos = Root.Position + Root.CFrame:VectorToWorldSpace(Local)
	C:PivotTo(CFrame.lookAt(Pos, Vector3.new(Root.Position.X, Pos.Y, Root.Position.Z)))
	C.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
	task.wait(0.15)
end
local function Guard(T, Body)
	local Home = C:GetPivot()
	PS.SetAuto(false)
	local Ok, Err = pcall(Body)
	PS.SetAuto(true)
	C:PivotTo(Home)
	Fresh()
	if not Ok then error(Err, 0) end
end

local Suite = {
	-- unlicensed casting seen by an agent raises State Heat at once; 3 casts hit the cap; Wanted 1 on the HUD
	A_CastSeenByAgent = function(T)
		Guard(T, function()
			Fresh()
			Data().Level = 6
			local Brask = Watcher("Foreman Brask")
			T.True(Brask ~= nil, "Brask is a watcher")
			PS.Reset(Brask)
			Put(Brask, Vector3.new(0, 0, -8))
			Run(1)
			T.Eq(MS.RegionOf(C), "Foundry", "standing in the Foundry")
			T.True(#HS.AgentsWatching(Player) >= 1, "Brask sees the player")
			T.True(HS.OnCast(Player), "recorded")
			T.Near(HS.Value(Player, "State"), 10, 0.01, "+10 State Heat")
			T.Eq(HS.Wanted(Player, "State"), 0)
			HS.OnCast(Player); HS.OnCast(Player); HS.OnCast(Player)
			T.Near(HS.Value(Player, "State"), 30, 0.01, "capped at 30 per place per hour")
			T.Eq(HS.Wanted(Player, "State"), 1, "Wanted 1")
			T.Eq(Player:GetAttribute("Wanted_State"), 1, "published for the HUD")
		end)
	end,
	B_NoCrimeBehindTheAgentOrUnderLevel = function(T)
		Guard(T, function()
			Fresh()
			Data().Level = 6
			local Brask = Watcher("Foreman Brask")
			PS.Reset(Brask)
			Put(Brask, Vector3.new(0, 0, 10)) -- behind him
			Run(4)
			T.True(not HS.OnCast(Player), "behind his back: no crime")
			Put(Brask, Vector3.new(0, 0, -8))
			Run(1)
			Data().Level = 5
			T.True(not HS.OnCast(Player), "level 5: studying is legal")
			Data().Level = 6
			Data().Licence.Path = "State"
			T.True(not HS.OnCast(Player), "licensed")
			Data().Licence.Path = ""
			T.Eq(HS.Value(Player, "State"), 0)
		end)
	end,
	-- a crime with no agent: State Heat arrives with the word, once
	C_AssaultHeatArrivesWithTheWord = function(T)
		Guard(T, function()
			Fresh()
			local T0 = os.time()
			RS.SetClock(function() return T0 end)
			T.True(MS.Record(Player, "assault_townsfolk", true, {Region = "Foundry", Strength = 2}), "recorded")
			task.wait()
			T.Eq(HS.Value(Player, "State"), 0, "no Authority in the Foundry: nothing yet")
			RS.SetClock(function() return T0 + 121 end)
			RS.Tick(Player)
			T.Near(HS.Value(Player, "State"), 15, 0.01, "dispatch reached the City: +15")
			RS.SetClock(function() return T0 + 601 end)
			RS.Tick(Player)
			T.Near(HS.Value(Player, "State"), 15, 0.01, "gossip arriving later adds nothing more")
		end)
	end,
	D_LawPresentRaisesAtOnce = function(T)
		Guard(T, function()
			Fresh()
			MS.Record(Player, "assault_townsfolk", true, {Region = "Lindenmoor", Strength = 2})
			task.wait()
			T.Near(HS.Value(Player, "Militia"), 15, 0.01, "Townsfolk law in Lindenmoor")
			T.Eq(HS.Value(Player, "State"), 0)
			MS.Record(Player, "assault_townsfolk", true, {Region = "City", Strength = 2})
			task.wait()
			T.Near(HS.Value(Player, "State"), 15, 0.01, "the Authority is in the City")
		end)
	end,
	E_GhostCrimeIsNoCrime = function(T)
		Guard(T, function()
			Fresh()
			MS.Record(Player, "assault_townsfolk", true, {Region = "City", Strength = 0})
			task.wait()
			T.Eq(HS.Value(Player, "State"), 0, "nobody saw it")
		end)
	end,
	F_FineClearsIt = function(T)
		Guard(T, function()
			Fresh()
			Data().Level = 6
			Data().Money = 1000
			HS.Add(Player, "State", 60)
			T.Eq(HS.Wanted(Player, "State"), 2)
			T.True(StoryLogic.Meets({Heat = {State = 1}, WantedBelow = {State = 2}}, Data()), "Brask offers the fine")
			local Ok = HS.Fine(Player, "State")
			T.True(Ok, "paid")
			T.Eq(Data().Money, 400, "100 x level 6")
			T.Eq(HS.Value(Player, "State"), 0)
			T.Eq(Player:GetAttribute("Wanted_State"), 0, "badge hides")
			T.True(not StoryLogic.Meets({Heat = {State = 1}}, Data()), "no fine to pay now")
		end)
	end,
	G_NoFinePastWanted2OrWithoutMoney = function(T)
		Guard(T, function()
			Fresh()
			Data().Level = 6
			Data().Money = 5000
			HS.Add(Player, "State", 120)
			local Ok, Why = HS.Fine(Player, "State")
			T.True(not Ok, "Wanted 3: " .. tostring(Why))
			T.Eq(Data().Money, 5000, "nothing taken")
			HS.Clear(Player, "State")
			HS.Add(Player, "State", 30)
			Data().Money = 10
			Ok = HS.Fine(Player, "State")
			T.True(not Ok, "can't afford it")
			T.Near(HS.Value(Player, "State"), 30, 0.01, "Heat stays")
		end)
	end,
	H_DecaysOverTime = function(T)
		Guard(T, function()
			Fresh()
			local T0 = os.time()
			HS.SetClock(function() return T0 end)
			HS.Add(Player, "State", 22)
			T.Eq(HS.Wanted(Player, "State"), 1)
			HS.SetClock(function() return T0 + 3600 end)
			T.Near(HS.Value(Player, "State"), 17, 0.01, "-5 after an hour")
			HS.Publish(Player, true)
			T.Eq(Player:GetAttribute("Wanted_State"), 0, "no longer wanted")
		end)
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

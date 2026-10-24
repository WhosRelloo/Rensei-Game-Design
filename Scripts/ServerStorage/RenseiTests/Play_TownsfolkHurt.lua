-- Play_TownsfolkHurt (Region Foundation Task 6b, 2026-10-23): townsfolk can be hurt, inside the game VM (LMRunSuite,
-- within the save snapshot / restore harness). Owner: "The townsfolk should be hittable and integrate the heat, rep
-- system, morality, etc."; when their health runs out: "Knocked, can be finished".
-- Fixture: flat ground near the Lindenmoor square (found as Play_Townsfolk finds it), posts along an 80-stud line
-- (X = studs along it): the townsfolk's own posts, Shelter posts where a test needs them, the test player standing on
-- the line in Combat Mode. Hits are real: HitboxManager.Sweep (the test player's Light1 swing) -> DamageManager ->
-- DownedManager -> ProgressionService.RecordHit's listeners; the grip goes through DownedManager.Request. Timers are
-- shortened inside a test and put back by the fixture (KnockedSeconds, BodySeconds, HelpChance, TalkCooldown).
local SSS = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local TS = require(SSS.TownsfolkService)
local Mover = require(SSS.TownsfolkService.Mover)
local WorldClock = require(SSS.WorldClock)
local PS = require(SSS.ProgressionService)
local HS = require(SSS.HeatService)
local MS = require(SSS.MoralityService)
local QuestService = require(SSS.QuestService)
local Managers = game.ReplicatedStorage.Modules.Managers
local HitboxManager = require(Managers.HitboxManager)
local DownedManager = require(Managers.DownedManager)
local TownsfolkLogic = require(game.ReplicatedStorage.Modules.Data.Rensei.TownsfolkLogic)
local Player = game.Players:GetPlayers()[1]

local GAP = 40

-- a line of three points GAP apart on flat ground with nothing above it (Play_Townsfolk's search); CFrames or nil
local function FindGround()
	local Square = workspace.World.Map.Lindenmoor.Square
	local Centre = Square:GetBoundingBox().Position
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	local Skip = {workspace.World.Live}
	for _, P in ipairs(game.Players:GetPlayers()) do if P.Character then table.insert(Skip, P.Character) end end
	Params.FilterDescendantsInstances = Skip
	local function Ground(X, Z)
		local R = workspace:Raycast(Vector3.new(X, Centre.Y + 100, Z), Vector3.new(0, -250, 0), Params)
		return R and R.Normal.Y > 0.98 and R.Position.Y or nil
	end
	for Ring = 0, 8 do
		for _, Off in ipairs({{0, 0}, {1, 0}, {-1, 0}, {0, 1}, {0, -1}, {1, 1}, {-1, -1}, {1, -1}, {-1, 1}}) do
			for _, Dir in ipairs({Vector3.new(1, 0, 0), Vector3.new(0, 0, 1)}) do
				local Start = Centre + Vector3.new(Off[1], 0, Off[2]) * (Ring * 25)
				local Y0 = Ground(Start.X, Start.Z)
				local Ok = Y0 ~= nil
				local Side = Vector3.new(Dir.Z, 0, -Dir.X)
				for D = 0, GAP * 2, 4 do
					for _, S in ipairs({-3, 0, 3}) do
						local Q = Start + Dir * D + Side * S
						local Y = Ok and Ground(Q.X, Q.Z)
						if not Y or math.abs(Y - Y0) > 0.6 then Ok = false break end
					end
					if not Ok then break end
				end
				if Ok then
					local Out = {}
					for I = 0, 2 do
						local Pos = Vector3.new(Start.X, Y0 + 0.1, Start.Z) + Dir * (GAP * I)
						Out[I + 1] = CFrame.lookAt(Pos, Pos + Side)
					end
					return Out
				end
			end
		end
	end
	return nil
end

local Seq = 0

-- builds the fixture, runs Body(X), and always cleans up. X: At(Along, Off) -> a point on the line; Dir / Side;
-- Post(Name, Along, Kind, Facing?) -> PostId; Folk(Name, Along, Region?, Facing?, Off?) -> Def, Rig; Stand(Along,
-- Facing?) puts the test player there (facing along the line by default); Swing() -> {[Victim] = Result}
local function Fixture(T, Body)
	local CFs = FindGround()
	T.True(CFs ~= nil, "clear, flat ground near the square")
	local Origin = CFs[1].Position
	local Dir = (CFs[2].Position - CFs[1].Position).Unit
	local Side = CFs[1].LookVector
	local Tag = tostring(math.random(1e6))
	local Made, Spawned, After = {}, {}, {}
	local C = Player.Character
	local Root = C.HumanoidRootPart
	local Saved = {
		Held = WorldClock.IsHeld(), Hour = WorldClock.Now(), Home = C:GetPivot(), Anchored = Root.Anchored,
		Mode = C:GetAttribute("CombatMode"), God = C:GetAttribute("AdminGod"),
		Knocked = TS.KnockedSeconds, Body = TS.BodySeconds, Help = TS.HelpChance, Cool = TS.TalkCooldown,
	}
	local X = {Dir = Dir, Side = Side, Tag = Tag, After = After}
	function X.At(Along, Off) return Origin + Dir * Along + Side * (Off or 0) end
	function X.Post(Name, Along, Kind, Facing, Off)
		local Id = "TH_" .. Name .. "_" .. Tag
		local Pos = X.At(Along, Off)
		local P = Instance.new("Part")
		P.Name = "TestPost_" .. Id
		P.Anchored, P.CanCollide, P.CanQuery, P.CanTouch = true, false, false, false
		P.Transparency = 0.5
		P.Size = Vector3.new(2, 0.2, 2)
		P.CFrame = CFrame.lookAt(Pos, Pos + (Facing or Side))
		P:SetAttribute("PostId", Id)
		P:SetAttribute("Kind", Kind)
		CollectionService:AddTag(P, "RenseiPost")
		P.Parent = workspace
		table.insert(Made, P)
		return Id
	end
	function X.Def(Name, Schedule)
		Seq += 1
		return {
			Id = "THF_" .. Name .. "_" .. Tag, Name = "Hurt Test " .. Name, Job = "Tester", JobLine = "Just testing.",
			Faction = "Townsfolk", Idle = "NPC_CrossArms", Look = {Nation = "Amestrian", Seed = 2000 + Seq}, Schedule = Schedule,
		}
	end
	function X.Spawn(D, Region)
		task.wait() -- (the post signal is deferred)
		local Rig = TS.Spawn(D, Region or "Test")
		table.insert(Spawned, D.Id)
		return Rig
	end
	function X.Folk(Name, Along, Region, Facing, Off)
		local PostId = X.Post(Name, Along, "Work", Facing, Off)
		local D = X.Def(Name, {{0, 24, PostId}})
		return D, X.Spawn(D, Region)
	end
	function X.Stand(Along, Facing, Off)
		local P = X.At(Along, Off) + Vector3.new(0, 3, 0)
		C:PivotTo(CFrame.lookAt(P, P + (Facing or Dir)))
		Root.AssemblyLinearVelocity = Vector3.zero
	end
	function X.Swing()
		local Got = {}
		for _, R in ipairs(HitboxManager.Sweep(C, "Light1", 0)) do Got[R.Victim] = R.Result end
		return Got
	end
	-- the deeds these tests record start rumours; they're dropped afterwards so they don't travel into later suites
	-- (RumourService.Tick counts every live rumour's arrivals: Play_Rumours). The harness restores the rest of the save.
	local Morality = PS.GetData(Player).Morality
	local Rumours = table.clone(Morality.Rumours or {})
	WorldClock.Hold(8)
	Root.Anchored = false
	C:SetAttribute("CombatMode", true) -- (a player's attacks land only in Combat Mode)
	local Ok, Err = pcall(Body, X)
	task.wait(0.2) -- (a rumour is spawned by a Recorded listener in its own thread)
	Morality.Rumours = Rumours
	for _, Fn in ipairs(After) do pcall(Fn) end
	pcall(function() if C:GetAttribute("Gripping") or C:GetAttribute("Carrying") then DownedManager.Drop(C) end end)
	for _, Id in ipairs(Spawned) do pcall(TS.Despawn, Id) end
	for _, P in ipairs(Made) do pcall(function() P:Destroy() end) end
	TS.KnockedSeconds, TS.BodySeconds, TS.HelpChance, TS.TalkCooldown = Saved.Knocked, Saved.Body, Saved.Help, Saved.Cool
	pcall(function() if Saved.Held then WorldClock.Hold(Saved.Hour) else WorldClock.Release() end end)
	pcall(function()
		C:SetAttribute("CombatMode", Saved.Mode)
		C:SetAttribute("AdminGod", Saved.God)
		Root.Anchored = Saved.Anchored
		C:PivotTo(Saved.Home)
		Root.AssemblyLinearVelocity = Vector3.zero
	end)
	if not Ok then error(Err, 0) end
end

local function WaitFor(Seconds, Fn)
	local T0 = os.clock()
	while os.clock() - T0 < Seconds and not Fn() do task.wait(0.05) end
	return Fn(), os.clock() - T0
end

-- knocked through DownedManager (no hit, so the witness stays at its post watching), then gripped and executed through
-- DownedManager.Request (B). The victim's post is at 40, a witness's at 52 facing back at it, the player at 44 between
-- them facing the victim. Returns the victim's Def and rig, the witness's rig and what MoralityService.Recorded saw.
local function Murder(T, X, Region)
	local V, Rig = X.Folk("V", 40, Region)
	local _, WRig = X.Folk("W", 52, Region, -X.Dir)
	X.Stand(44, -X.Dir)
	local Info
	local function Listener(P, DeedId, _, I) if P == Player and DeedId == "murder_townsfolk" then Info = I end end
	table.insert(MS.Recorded, Listener)
	table.insert(X.After, function()
		local I = table.find(MS.Recorded, Listener)
		if I then table.remove(MS.Recorded, I) end
	end)
	task.wait(0.3)
	DownedManager.Damage(Rig, 1000)
	T.Eq(Rig:GetAttribute("Knocked"), true, "knocked through DownedManager")
	task.wait(1) -- (the witness sees the player: PerceptionService runs on its own)
	local Result = DownedManager.Request(Player.Character, "Grip")
	T.Eq(Result, "Gripped", "the grip (B) finished them")
	WaitFor(2, function() return TS.State(V.Id) == "Dead" end)
	return V, Rig, WRig, function() return Info end
end

-- QuestService.Signal swapped for a recorder while Body runs (no real quest progress), then put back
local function NoQuestSignals(Body)
	local Real = QuestService.Signal
	QuestService.Signal = function() end
	local Ok, Err = pcall(Body)
	QuestService.Signal = Real
	if not Ok then error(Err, 0) end
end

return {
	-- a melee hit lowers their health and is assault, once per cooldown; only a hit that lands counts
	HitIsAssault = function(T)
		Fixture(T, function(X)
			local D = PS.GetData(Player)
			D.Morality.Deeds.assault_townsfolk = nil
			local V, Rig = X.Folk("V", 40)
			local _, ORig = X.Folk("O", 75)
			X.Stand(36)
			task.wait(0.2)
			T.Eq(Rig.Humanoid.MaxHealth, TS.MaxHealth, "100 max health")
			local Got = X.Swing()
			T.Eq(Got[Rig], "Hit", "the swing lands on the townsperson")
			T.True(Rig.Humanoid.Health < TS.MaxHealth, "their health went down (" .. Rig.Humanoid.Health .. ")")
			task.wait(0.15) -- (the hit listeners run in their own threads)
			local E = D.Morality.Deeds.assault_townsfolk
			T.True(E ~= nil and E.Count == 1, "assault_townsfolk recorded once")
			T.Eq(X.Swing()[Rig], "Hit", "a second swing lands too (still in its stun)")
			task.wait(0.3)
			T.Eq(D.Morality.Deeds.assault_townsfolk.Count, 1, "a second hit within the cooldown: the same assault")
			-- a hit that didn't land (blocked, passed through) on another townsperson is no assault; a landed one is
			PS.RecordHit(Player.Character, ORig, "Blocked")
			PS.RecordHit(Player.Character, ORig, "IFramed")
			task.wait(0.3)
			T.Eq(D.Morality.Deeds.assault_townsfolk.Count, 1, "a hit that didn't land isn't assault")
			PS.RecordHit(Player.Character, ORig, "Hit")
			task.wait(0.3)
			T.Eq(D.Morality.Deeds.assault_townsfolk.Count, 2, "a landed one is")
			T.True(V.Id ~= nil)
		end)
	end,

	-- hit: a Hurt line, stops where it stands, then runs to the shelter away from the attacker (not the nearest one);
	-- a townsperson 15 studs off runs too and shouts for help
	HurtFleesAndOthersFlee = function(T)
		Fixture(T, function(X)
			TS.HelpChance = 1
			X.Post("ShelterNear", 10, "Shelter") -- 30 from the victim, toward the attacker
			local Far = X.Post("ShelterFar", 75, "Shelter") -- 35 from the victim, away from the attacker
			local V, Rig = X.Folk("V", 40)
			local W, WRig = X.Folk("W", 55)
			X.Stand(36)
			task.wait(0.2)
			local Got = X.Swing()
			T.Eq(Got[Rig], "Hit", "the swing lands")
			T.Eq(select(2, TS.LastLine(V.Id)), "Hurt", "a Hurt line")
			T.True(table.find(TownsfolkLogic.Chatter.Hurt, (TS.LastLine(V.Id))) ~= nil, "one of the Hurt lines")
			T.Eq(TS.State(V.Id), "Hurt", "hurt: stopped where it stands")
			T.Eq(Rig.HumanoidRootPart.Anchored, false, "the body is free, not held at the post")
			T.Eq(Rig.HumanoidRootPart.TalkPrompt.Enabled, false, "no talking while hurt")
			T.Eq(TS.State(W.Id), "Fleeing", "the townsperson 15 studs off runs too")
			T.Eq(select(2, TS.LastLine(W.Id)), "Help", "and shouts for help")
			T.Eq(TS.ShelterOf(W.Id), Far, "away from the attacker")
			local Ran, Took = WaitFor(TS.HurtMax + 1, function() return TS.State(V.Id) == "Fleeing" end)
			T.True(Ran, "then runs, once the hit's stun is over (" .. TS.State(V.Id) .. ")")
			print(("[TownsfolkHurt] the hit one ran after %.2f s"):format(Took))
			T.Eq(TS.ShelterOf(V.Id), Far, "to the shelter farthest from the attacker of the 3 nearest, not the nearest")
			T.True(Mover.Handle(Rig) ~= nil, "an urgent run")
			local D0 = (Rig.HumanoidRootPart.Position - X.At(75)).Magnitude
			task.wait(1.2)
			local D1 = (Rig.HumanoidRootPart.Position - X.At(75)).Magnitude
			T.True(D1 < D0 - 5, ("running toward it (%.1f -> %.1f studs)"):format(D0, D1))
			T.True(WRig.Parent ~= nil)
		end)
	end,

	-- 0 health: knocked (DownedManager's attributes); a hit passes through; left alone (KnockedSeconds, shortened) they
	-- get up with 30 % health and run
	KnockedThenRecovers = function(T)
		Fixture(T, function(X)
			TS.KnockedSeconds = 2
			X.Post("Shelter", 75, "Shelter")
			local V, Rig = X.Folk("V", 40)
			T.Eq(Rig:GetAttribute("KnockedTime"), 2, "the townsperson's own knock length")
			T.Eq(Rig:GetAttribute("Knockable"), true)
			X.Stand(36)
			task.wait(0.2)
			Rig.Humanoid.Health = 1
			T.Eq(X.Swing()[Rig], "Hit", "the swing lands")
			T.Eq(Rig:GetAttribute("Knocked"), true, "knocked at 0 health")
			T.True(Rig:GetAttribute("KnockedUntil") ~= nil, "KnockedUntil set")
			T.Eq(Rig.Humanoid.Health, 1, "held at 1 health, as DownedManager holds enemies")
			task.wait(0.1)
			T.Eq(TS.State(V.Id), "Knocked")
			T.Eq(Rig.HumanoidRootPart.TalkPrompt.Enabled, false, "no talking while knocked")
			T.True(DownedManager.Nearest(Player.Character, 6) == Rig, "the grip (B) finds them (World.Live.Townsfolk)")
			T.Eq(X.Swing()[Rig], "IFramed", "a hit on a knocked body passes through")
			TS.Step()
			T.Eq(TS.State(V.Id), "Knocked", "Step leaves them be")
			local Up = WaitFor(4, function() return Rig:GetAttribute("Knocked") == nil end)
			T.True(Up, "up again after the shortened knock")
			T.Near(Rig.Humanoid.Health, TS.MaxHealth * TS.RecoverShare, 0.5, "with 30 % health")
			local Ran = WaitFor(TS.HurtMax + 1, function() return TS.State(V.Id) == "Fleeing" end)
			T.True(Ran, "and running for shelter (" .. tostring(TS.State(V.Id)) .. ")")
			T.Eq(select(2, TS.LastLine(V.Id)), "Hurt", "with a Hurt line")
		end)
	end,

	-- knock, grip and execute through the real DownedManager path: murder_townsfolk, witnessed, Heat in a State region,
	-- no EXP / money / training; the body lies BodySeconds (shortened), never settled, then is removed
	ExecuteIsMurder = function(T)
		Fixture(T, function(X)
			TS.BodySeconds = 4
			local D = PS.GetData(Player)
			D.Morality.Deeds.murder_townsfolk = nil
			D.Morality.Heat = {}
			HS.Publish(Player, true)
			local Before = {Exp = D.LifetimeExp, Money = D.Money, Level = D.Level, Mastery = D.Mastery.Progress}
			local V, Rig, WRig, InfoOf = Murder(T, X, "City")
			T.Eq(TS.State(V.Id), "Dead", "dead")
			T.Eq(Rig.Humanoid.Health, 0)
			local E = D.Morality.Deeds.murder_townsfolk
			T.True(E ~= nil and E.Count == 1, "murder_townsfolk recorded for the test player")
			local Info = InfoOf()
			T.True(Info ~= nil and Info.Region == "City", "in the townsperson's region")
			local Saw = false
			for _, N in ipairs((Info.Witnesses and Info.Witnesses.Npcs) or {}) do if N.Rig == WRig then Saw = true end end
			T.True(Saw, "witnessed by the townsperson who watched")
			task.wait(0.3)
			T.True(HS.Value(Player, "State") >= 59, ("State Heat rose in a State region (%.1f)"):format(HS.Value(Player, "State")))
			T.Eq(D.LifetimeExp, Before.Exp, "no EXP")
			T.Eq(D.Money, Before.Money, "no money")
			T.Eq(D.Level, Before.Level)
			T.Eq(D.Mastery.Progress, Before.Mastery, "no training")
			-- the body: nothing walks or places it (a settle would anchor it at its post)
			task.wait(1.1)
			TS.Step()
			T.Eq(TS.State(V.Id), "Dead", "still dead after a Step")
			T.True(TS.Get(V.Id) == Rig and Rig.Parent ~= nil, "the body lies there")
			T.Eq(Rig.HumanoidRootPart.Anchored, false, "never settled at its post")
			T.Eq(Mover.Handle(Rig), nil, "no walk")
			local Gone = WaitFor(4, function() return Rig.Parent == nil end)
			T.True(Gone, "removed after BodySeconds")
		end)
	end,

	-- after the murder, another townsperson of the region tells of it
	Gossip = function(T)
		Fixture(T, function(X)
			local D = PS.GetData(Player)
			D.Morality.Deeds.murder_townsfolk = nil
			Murder(T, X, "City")
			T.True(D.Morality.Deeds.murder_townsfolk ~= nil, "the murder was recorded")
			local L = X.Folk("L", 0, "City") -- (a fresh, calm townsperson of the same region)
			TS.TalkCooldown = 0
			local Lines = {}
			NoQuestSignals(function()
				for I = 1, 4 do Lines[I] = TS.Talk(Player, L.Id) or "" end
			end)
			local Got = nil
			for _, Line in ipairs(Lines) do if Line:find("killed a townsperson", 1, true) then Got = Line end end
			T.True(Got ~= nil, "a line about the killing: " .. table.concat(Lines, " | "))
			print("[TownsfolkHurt] gossip: " .. tostring(Got))
		end)
	end,

	-- a death; held at 05:59 nothing changes; at 06:00 the slot respawns: same Id, job, faction, nation and schedule,
	-- a new name from the nation's newcomer list and a new look seed
	NewcomerAtSix = function(T)
		Fixture(T, function(X)
			local V, Rig = X.Folk("V", 40)
			local OldName, OldSeed = V.Name, V.Look.Seed
			Rig.Humanoid.Health = 0
			T.True(WaitFor(2, function() return TS.State(V.Id) == "Dead" end), "dead")
			WorldClock.Hold(5.98)
			WorldClock.Tick()
			task.wait(0.1)
			T.Eq(TS.State(V.Id), "Dead", "05:59: still dead")
			T.Eq(TS.Get(V.Id), Rig, "the body still lies there")
			WorldClock.Hold(6)
			WorldClock.Tick()
			T.True(WaitFor(1, function() return TS.State(V.Id) ~= "Dead" end), "06:00: the slot is filled")
			local New = TS.Def(V.Id)
			local NewRig = TS.Get(V.Id)
			T.True(NewRig ~= nil and NewRig ~= Rig, "a new person")
			T.Eq(Rig.Parent, nil, "the old body is gone")
			T.True(New.Name ~= OldName, "a different name: " .. tostring(New.Name))
			T.True(table.find(TownsfolkLogic.NewcomerNames.Amestrian, New.Name) ~= nil, "from the nation's newcomer names")
			T.Eq(New.Id, V.Id, "the same Id")
			T.Eq(New.Job, V.Job, "the same job")
			T.Eq(New.Faction, V.Faction)
			T.Eq(New.Look.Nation, V.Look.Nation, "the same nation")
			T.Eq(New.Schedule, V.Schedule, "the same schedule")
			T.True(New.Look.Seed ~= OldSeed, "a new look")
			T.Eq(NewRig:GetAttribute("DisplayName"), New.Name)
			T.Eq(NewRig.Humanoid.Health, TS.MaxHealth, "whole")
			T.Eq(TS.State(V.Id), "AtPost")
		end)
	end,

	-- one melee sweep through a townsperson and an enemy side by side damages both, with no errors
	SweepStillHitsEnemies = function(T)
		Fixture(T, function(X)
			local C = Player.Character
			C:SetAttribute("AdminGod", true) -- (the bandit can't hurt the test player meanwhile)
			local _, Rig = X.Folk("V", 40, nil, nil, -1.6)
			local Part = Instance.new("Part")
			Part.Name = "TH_EnemySpawn_" .. X.Tag
			Part.Anchored, Part.CanCollide, Part.CanQuery, Part.CanTouch = true, false, false, false
			Part.Transparency = 1
			Part.Size = Vector3.new(2, 1, 2)
			local At = X.At(40, 1.6)
			Part.CFrame = CFrame.lookAt(At, At - X.Dir)
			Part:SetAttribute("EnemyType", "Grunt")
			Part:SetAttribute("RespawnTime", 1e9)
			Part.Parent = workspace
			local ES = require(SSS.EnemyService)
			local Enemy = ES.Spawn(Part)
			table.insert(X.After, function()
				ES.Active[Enemy] = nil
				pcall(function() require(SSS.CombatDirector).Unregister(Enemy, "Died") end)
				pcall(function() require(SSS.PerceptionService).Unregister(Enemy) end)
				if Enemy.Parent then Enemy:Destroy() end
				Part:Destroy()
			end)
			T.True(Enemy ~= nil, "a bandit")
			Enemy:SetAttribute("AIPassive", true)
			Enemy.HumanoidRootPart.Anchored = true -- (held still beside the townsperson)
			Enemy:PivotTo(CFrame.lookAt(At + Vector3.new(0, 3, 0), At + Vector3.new(0, 3, 0) - X.Dir))
			local EH0 = Enemy.Humanoid.Health
			X.Stand(36)
			task.wait(0.2)
			local Ok, Got = pcall(X.Swing)
			T.True(Ok, "no errors: " .. tostring(Got))
			T.Eq(Got[Rig], "Hit", "the townsperson is hit")
			T.Eq(Got[Enemy], "Hit", "the bandit is hit")
			T.True(Rig.Humanoid.Health < TS.MaxHealth, "the townsperson is hurt")
			T.True(Enemy.Humanoid.Health < EH0, "the bandit is hurt")
		end)
	end,

	-- the walk and combat (the 5b review): a walk whose rig is pinned (MoverManager's Movement) is held -- no steering,
	-- the facing constraint off, never re-anchored -- and resumes after; a player's hit mid-walk ends the walk where
	-- they stand (Mover.Stop), facing off; a death mid-walk is never settled at the post
	WalkAndCombat = function(T)
		Fixture(T, function(X)
			local A = X.Post("A", 0, "Work")
			local B = X.Post("B", 80, "Counter")
			local KA = X.Post("KA", 8, "Work")
			local KB = X.Post("KB", 72, "Counter")
			local D = X.Def("V", {{0, 12, A}, {12, 24, B}})
			local Rig = X.Spawn(D)
			local K = X.Def("K", {{0, 12, KA}, {12, 24, KB}})
			local KRig = X.Spawn(K)
			X.Stand(40, nil, 15) -- (15 studs off the middle of the line: near enough that they walk)
			task.wait(0.2)
			local Root = Rig.HumanoidRootPart
			WorldClock.Hold(14)
			TS.Step()
			T.Eq(TS.State(D.Id), "Walking", "walking to B")
			T.Eq(TS.State(K.Id), "Walking", "K walking to KB")
			task.wait(1)
			local H = Mover.Handle(Rig)
			T.True(H ~= nil, "a live walk")
			Rig:SetAttribute("Movement", 1) -- (a hit's slow / pin, as MoverManager.Movement sets it)
			task.wait(0.4)
			T.True(H.Suspended == true, "held while pinned")
			T.Eq(Root.MoverFacing.Enabled, false, "the facing constraint is off")
			T.Eq(Root.Anchored, false, "not re-anchored")
			Rig:SetAttribute("Movement", 0)
			task.wait(0.4)
			T.True(H.Suspended == false and H.Status == "walking", "walking on")
			T.Eq(Root.MoverFacing.Enabled, true, "facing again")
			T.Eq(Rig.Humanoid.WalkSpeed, TS.WalkSpeed, "at its own speed")
			-- a death mid-walk (K): the body stays where it falls; nothing settles it at its post
			local KH = Mover.Handle(KRig)
			T.True(KH ~= nil and TS.State(K.Id) == "Walking", "K still walking")
			KRig.Humanoid.Health = 0
			T.True(WaitFor(2, function() return TS.State(K.Id) == "Dead" end), "K dead")
			T.Eq(KH.Status, "cancelled", "the walk ended")
			task.wait(1.1)
			TS.Step()
			T.Eq(TS.State(K.Id), "Dead", "still dead after the watchdog's Step")
			T.Eq(KRig.HumanoidRootPart.Anchored, false, "never settled")
			T.Eq(Mover.Handle(KRig), nil, "no walk")
			local Post = X.At(72) + Vector3.new(0, 3, 0)
			T.True((KRig.HumanoidRootPart.Position - Post).Magnitude > 3, "not at its post")
			-- a player's hit mid-walk (the real listener; the swing itself is covered above)
			TS.OnHit(Player.Character, Rig, "Hit")
			T.Eq(TS.State(D.Id), "Hurt", "hurt")
			T.Eq(H.Status, "cancelled", "the walk ended where it stands")
			T.Eq(Mover.Handle(Rig), nil)
			T.Eq(Root.MoverFacing.Enabled, false, "the facing constraint is off")
			T.Eq(Root.Anchored, false, "not anchored")
		end)
	end,
}

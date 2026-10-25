-- Play_QuestEngine (Foundry data plan Task 2, 2026-10-24): the quest engine's revised quests, quest deeds and clue
-- evidence, inside the game VM (LMRunSuite) with the Play client connected and the test hook installed.
--   * StartRecordsRevision: a quest started now records its definition's Revision.
--   * UpgradeAllMovesOldStates: QuestService.UpgradeAll moves a saved state from an older revision past the stages
--     put in front of it.
--   * RewardsDeedsAreRecorded: Rewards.Deeds are recorded (MoralityService) when rewards are paid.
--   * ClueLineGivesEvidence: a townsperson's clue line with Clue.Evidence gives that evidence before it signals
--     Clue.Signal, so a quest needing both completes on that one Talk. The townsperson stands on a temporary post on a
--     temporary floor at y 300, on the first free site (Play_TownsfolkCrowd's fixture pattern).
--   * BootWaitsForTheSnapshot: QuestService.WaitForSnapshot (Boot's wait for the hook's save snapshot) still waits
--     after 1 s for a player who isn't the LMSnapTaken one, stops when that player leaves, and returns at once for
--     the real player, whose snapshot is taken.
-- Every test puts back what it changed: the injected defs, Data.Quests, Data.Story and Data.Morality (deep copies
-- taken first, put back in place), the fixture parts and the townsperson; the clock hold and TalkCooldown too.
local SSS = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local Rensei = game.ReplicatedStorage.Modules.Data.Rensei
local PS = require(SSS.ProgressionService)
local QuestService = require(SSS.QuestService)
local Defs = QuestService.Definitions

-- empty spots far outside the maps (tried in order; the first with nothing in its box is used: Play_TownsfolkCrowd)
local SITES = {Vector3.new(-700, 300, 700), Vector3.new(700, 300, 700), Vector3.new(-700, 300, -3300)}
local FLOOR = 40

local function Copy(T)
	if type(T) ~= "table" then return T end
	local R = {}
	for K, V in pairs(T) do R[K] = Copy(V) end
	return R
end

-- runs Body(Player, Data, OnCleanup) with the player's Quests / Story / Morality copied first and put back after (in
-- place, the same tables), then every OnCleanup function (last first); a failure is raised after the cleanup
local function Guarded(T, Body)
	local Player = game.Players:GetPlayers()[1]
	T.True(Player ~= nil, "a player in the game")
	local Data = PS.GetData(Player)
	T.True(type(Data) == "table" and type(Data.Quests) == "table" and type(Data.Story) == "table", "the player's save is loaded")
	local Saved = {}
	for _, K in ipairs({"Quests", "Story", "Morality"}) do Saved[K] = {Was = Data[K], Copy = Copy(Data[K])} end
	local Cleanups = {}
	local Ok, Err = pcall(Body, Player, Data, function(Fn) table.insert(Cleanups, Fn) end)
	local ROk, RErr = pcall(function()
		for K, S in pairs(Saved) do
			if type(S.Was) == "table" then
				for Key in pairs(S.Was) do S.Was[Key] = nil end
				for Key, V in pairs(S.Copy) do S.Was[Key] = Copy(V) end
			end
			Data[K] = S.Was
		end
	end)
	for I = #Cleanups, 1, -1 do
		local COk, CErr = pcall(Cleanups[I])
		if not COk then warn("Play_QuestEngine cleanup failed:", CErr) end
	end
	pcall(PS.Sync, Player)
	if not ROk then error("the save was not put back: " .. tostring(RErr), 0) end
	if not Ok then error(Err, 0) end
end

local function OneStage(Id, Objectives) return {Id = Id, Text = "Test stage " .. Id, Objectives = Objectives} end

return {
	StartRecordsRevision = function(T)
		Guarded(T, function(Player, Data, OnCleanup)
			Defs.__fy_q = {Title = "Test", Revision = 3, Stages = {{Id = "s1", Text = "t", Objectives = {
				{Id = "o", Text = "o", Kind = "Signal", Target = "__fy_sig"}}}}}
			OnCleanup(function() Defs.__fy_q = nil end)
			Data.Quests.Active.__fy_q, Data.Quests.Completed.__fy_q = nil, nil
			T.Eq(QuestService.Start(Player, "__fy_q"), true, "the test quest starts")
			local State = Data.Quests.Active.__fy_q
			T.True(type(State) == "table", "it is active")
			T.Eq(State.Stage, 1, "on stage 1")
			T.Eq(State.Revision, 3, "the state records the definition's Revision")
		end)
	end,

	UpgradeAllMovesOldStates = function(T)
		Guarded(T, function(Player, Data, OnCleanup)
			local function Sig(N) return {{Id = "o" .. N, Text = "o", Kind = "Signal", Target = "__fy_never_" .. N}} end
			Defs.__fy_q2 = {Title = "Test 2", Revision = 2, Prepended = {[2] = 1},
				Stages = {OneStage("s1", Sig(1)), OneStage("s2", Sig(2)), OneStage("s3", Sig(3))}}
			OnCleanup(function() Defs.__fy_q2 = nil end)
			Data.Quests.Active.__fy_q2 = {Stage = 1, Progress = {}}
			T.True(type(QuestService.UpgradeAll) == "function", "QuestService.UpgradeAll exists")
			T.Eq(QuestService.UpgradeAll(Data), true, "an old-revision state changed")
			T.Eq(Data.Quests.Active.__fy_q2.Stage, 2, "moved past the one stage put in front")
			T.Eq(Data.Quests.Active.__fy_q2.Revision, 2, "now at revision 2")
		end)
	end,

	RewardsDeedsAreRecorded = function(T)
		Guarded(T, function(Player, Data, OnCleanup)
			local MoralityService = require(SSS.MoralityService)
			local DeedDefs = require(Rensei.Deeds)
			DeedDefs.__fy_deed = {Text = "Test deed", Conduct = {Order = 1}, Scope = "Private"}
			OnCleanup(function() DeedDefs.__fy_deed = nil end) -- (after the save is put back: no ledger entry is left)
			T.True(not MoralityService.Has(Player, "__fy_deed"), "not on the ledger before")
			QuestService.Grant(Player, {Deeds = {"__fy_deed"}})
			T.True(MoralityService.Has(Player, "__fy_deed"), "Rewards.Deeds recorded the deed")
		end)
	end,

	ClueLineGivesEvidence = function(T)
		Guarded(T, function(Player, Data, OnCleanup)
			local TS = require(SSS.TownsfolkService)
			local WorldClock = require(SSS.WorldClock)
			local EvidenceDefs = require(Rensei.Evidence)
			-- the clock held (Ruling 14) and the Talk cooldown off, both put back
			local WasHeld, WasHour, Cool = WorldClock.IsHeld(), WorldClock.Now(), TS.TalkCooldown
			OnCleanup(function()
				TS.TalkCooldown = Cool
				if WasHeld then WorldClock.Hold(WasHour) else WorldClock.Release() end
			end)
			WorldClock.Hold(10)
			TS.TalkCooldown = 0

			EvidenceDefs.__fy_ev = {Title = "Test Evidence", Text = "A test."}
			OnCleanup(function() EvidenceDefs.__fy_ev = nil end)
			Defs.__fy_q3 = {Title = "Test 3", Stages = {OneStage("s1", {
				{Id = "ev", Text = "Hold the test evidence", Kind = "Evidence", Target = "__fy_ev"},
				{Id = "sig", Text = "Be told", Kind = "Signal", Target = "__fy_sig"},
			})}}
			OnCleanup(function() Defs.__fy_q3 = nil end)
			Data.Story.Evidence.__fy_ev = nil
			Data.Quests.Active.__fy_q3, Data.Quests.Completed.__fy_q3 = nil, nil

			-- the fixture: a floor and a post on the first free site
			local O
			for _, C in ipairs(SITES) do
				if #workspace:GetPartBoundsInBox(CFrame.new(C + Vector3.new(0, 30, 0)), Vector3.new(FLOOR + 20, 80, FLOOR + 20)) == 0 then
					O = C
					break
				end
			end
			T.True(O ~= nil, "an empty spot for the test floor")
			local Folder = Instance.new("Folder")
			Folder.Name = "QuestEngineTest"
			OnCleanup(function() Folder:Destroy() end)
			local Floor = Instance.new("Part")
			Floor.Name = "Floor"
			Floor.Anchored = true
			Floor.Size = Vector3.new(FLOOR, 2, FLOOR)
			Floor.CFrame = CFrame.new(O)
			Floor.Material = Enum.Material.Concrete
			Floor.Parent = Folder
			local PostId = "__fy_post_" .. math.random(1e6)
			local Post = Instance.new("Part")
			Post.Name = PostId
			Post.Anchored, Post.CanCollide, Post.CanQuery, Post.CanTouch = true, false, false, false
			Post.Transparency = 0.5
			Post.Size = Vector3.new(2, 0.2, 2)
			Post.CFrame = CFrame.lookAt(O + Vector3.new(0, 1.1, 0), O + Vector3.new(1, 1.1, 0))
			Post:SetAttribute("PostId", PostId)
			Post:SetAttribute("Kind", "Counter")
			CollectionService:AddTag(Post, "RenseiPost")
			Post.Parent = Folder
			Folder.Parent = workspace
			task.wait() -- the post signal is deferred
			T.True(TS.Posts[PostId] == Post, "the test post is registered")

			local Id = "__fy_teller_" .. math.random(1e6)
			OnCleanup(function() TS.Despawn(Id) end)
			TS.Spawn({
				Id = Id, Name = "Test Teller", Job = "Tester", JobLine = "Just testing.", Faction = "Townsfolk",
				Idle = "NPC_CrossArms", Look = {Nation = "Amestrian", Seed = 4242}, Schedule = {{0, 24, PostId}},
				Clue = {Quest = "__fy_q3", Stage = 1, Signal = "__fy_sig", Evidence = "__fy_ev", Text = "x"},
			}, "Test")
			T.True(TS.Get(Id) ~= nil, "the test townsperson is spawned")

			T.Eq(QuestService.Start(Player, "__fy_q3"), true, "the test quest starts")
			T.Eq(Data.Quests.Active.__fy_q3.Progress.ev, 0, "the evidence isn't held yet")
			local Text, Kind = TS.Talk(Player, Id)
			T.Eq(Kind, "Clue", "the clue line")
			T.Eq(Text, "x")
			T.True(Data.Story.Evidence.__fy_ev ~= nil, "the clue line gave the evidence")
			T.True(Data.Quests.Active.__fy_q3 == nil and Data.Quests.Completed.__fy_q3 ~= nil,
				"the quest completed on that Talk (evidence first, then the signal)")
		end)
	end,

	BootWaitsForTheSnapshot = function(T)
		local Player = game.Players:GetPlayers()[1]
		T.True(Player ~= nil, "a player in the game")
		T.True(type(QuestService.WaitForSnapshot) == "function", "QuestService.WaitForSnapshot exists")
		T.Eq(game.ServerStorage:GetAttribute("LMSnapTaken"), Player.Name, "the hook has taken the real player's snapshot")
		-- a stand-in whose snapshot is never taken: still waiting after 1 s; it leaves, and the wait ends (false)
		local Stand = {Name = "__fy_not_snapped", Parent = game.Players}
		local Done, Result = false, nil
		task.spawn(function()
			Result = QuestService.WaitForSnapshot(Stand)
			Done = true
		end)
		task.wait(1)
		local StillWaiting = not Done
		Stand.Parent = nil
		local T0 = os.clock()
		repeat task.wait(0.05) until Done or os.clock() - T0 > 2
		T.True(StillWaiting, "still waiting after 1 s for a player whose snapshot isn't taken")
		T.True(Done, "the wait ends when that player leaves")
		T.Eq(Result, false, "and says it didn't wait through")
		-- the real player: at once
		local T1 = os.clock()
		T.Eq(QuestService.WaitForSnapshot(Player), true, "the real player's snapshot is taken")
		T.True(os.clock() - T1 < 0.1, "returned at once (" .. string.format("%.3f", os.clock() - T1) .. " s)")
	end,
}

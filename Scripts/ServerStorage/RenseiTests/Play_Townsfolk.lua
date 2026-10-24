-- Play_Townsfolk (Region Foundation Task 5, 2026-10-23): TownsfolkService inside the game VM (LMRunSuite).
-- The fixture finds clear, flat ground near the Lindenmoor square by raycasting, puts three test posts there 40 studs
-- apart, and removes everything afterwards (posts, rigs, the clock hold, the moved player). The service's own 1 Hz
-- loop keeps running during the tests; it reads the same held hour, so it agrees with the hand-called Step().
-- Task 6: fleeing fights (a held hour, a Shelter post 30 studs off, NoiseService.Emit), the witness tag, and talk
-- (Talk / LastLine): greeting by standing (Reputation.PlaceStanding patched), the rumour step, the clue line, the
-- passing remark. Patches and injected data are put back in the same test, with no yield while any of the player's
-- own data is swapped.
local SSS = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local TS = require(SSS.TownsfolkService)
local WorldClock = require(SSS.WorldClock)
local Customization = require(game.ReplicatedStorage.Modules.Data.Rensei.Customization)
local Player = game.Players:GetPlayers()[1]
local Managers = game.ReplicatedStorage.Modules.Managers
local Rensei = game.ReplicatedStorage.Modules.Data.Rensei
local TownsfolkLogic = require(Rensei.TownsfolkLogic)
local Reputation = require(Rensei.Reputation)
local Deeds = require(Rensei.Deeds)
local NoiseService = require(SSS.NoiseService)
local QuestService = require(SSS.QuestService)
local PS = require(SSS.ProgressionService)

local GAP = 40 -- studs between the test posts (the brief)

-- a line of three posts GAP apart on flat ground with nothing above it; returns their CFrames or nil
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
						Out[I + 1] = CFrame.lookAt(Pos, Pos + Side) -- each post faces sideways off the line
					end
					return Out
				end
			end
		end
	end
	return nil
end

local Made = {}
local function Post(Id, CF, Kind)
	local P = Instance.new("Part")
	P.Name = "TestPost_" .. Id
	P.Anchored, P.CanCollide, P.CanQuery, P.CanTouch = true, false, false, false
	P.Transparency = 0.5
	P.Size = Vector3.new(2, 0.2, 2)
	P.CFrame = CF
	P:SetAttribute("PostId", Id)
	P:SetAttribute("Kind", Kind)
	CollectionService:AddTag(P, "RenseiPost")
	P.Parent = workspace
	table.insert(Made, P)
	return P
end

local Seq = 0
local function Def(Schedule, Nation)
	Seq += 1
	return {
		Id = "TestFolk_" .. Seq .. "_" .. math.random(1e6), Name = "Test Townsperson " .. Seq, Job = "Tester",
		JobLine = "Just testing.", Faction = "Townsfolk", Idle = "NPC_CrossArms",
		Look = {Nation = Nation or "Amestrian", Seed = 1000 + Seq}, Schedule = Schedule,
	}
end

-- builds the fixture, runs Body(Posts, Ids), and always cleans up
local function Fixture(T, Body)
	local CFs = FindGround()
	T.True(CFs ~= nil, "clear, flat ground near the square")
	local Tag = tostring(math.random(1e6))
	local Ids = {A = "TF_A_" .. Tag, B = "TF_B_" .. Tag, C = "TF_C_" .. Tag}
	local Posts = {A = Post(Ids.A, CFs[1], "Work"), B = Post(Ids.B, CFs[2], "Counter"), C = Post(Ids.C, CFs[3], "Seat")}
	local Spawned = {}
	local WasHeld, WasHour = WorldClock.IsHeld(), WorldClock.Now()
	local C = Player and Player.Character
	local Home = C and C:GetPivot()
	local Root = C and C:FindFirstChild("HumanoidRootPart")
	local WasAnchored = Root and Root.Anchored
	task.wait() -- the post signal is deferred
	local Ok, Err = pcall(Body, Posts, Ids, Spawned)
	for _, Id in ipairs(Spawned) do pcall(TS.Despawn, Id) end
	for _, P in ipairs(Made) do pcall(function() P:Destroy() end) end
	table.clear(Made)
	pcall(function()
		if WasHeld then WorldClock.Hold(WasHour) else WorldClock.Release() end
	end)
	pcall(function()
		if Root then Root.Anchored = WasAnchored end
		if C and Home then C:PivotTo(Home) Root.AssemblyLinearVelocity = Vector3.zero end
	end)
	if not Ok then error(Err, 0) end
end

local function Stand(PostPart) return (PostPart.CFrame * CFrame.new(0, 3, 0)).Position end
local function Flat(V) return Vector3.new(V.X, 0, V.Z).Unit end

-- Task 6: the test player beside the line (20 studs off the middle post): near enough that townsfolk walk, out of
-- their way, and more than PassRadius from every post
local function BesideLine(Posts)
	local C = Player.Character
	C:PivotTo(CFrame.new(Stand(Posts.B) + Posts.B.CFrame.LookVector * 20))
	C.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
	task.wait(0.2)
end

-- Task 6: QuestService.Signal swapped for a recorder while Body runs (no real quest progress), then put back. The
-- Talk cooldown is off meanwhile (these tests talk several times in a row; TalkCooldown has its own test).
local function RecordSignals(Body)
	local Real, Cool = QuestService.Signal, TS.TalkCooldown
	local Calls = {}
	QuestService.Signal = function(P, Kind, Target) table.insert(Calls, {P, Kind, Target}) end
	TS.TalkCooldown = 0
	local Ok, Err = pcall(Body, Calls)
	QuestService.Signal, TS.TalkCooldown = Real, Cool
	if not Ok then error(Err, 0) end
end

-- fix round 1: DamageManager used to throw on a townsperson (no WCS character before Task 6b), aborting the whole
-- sweep. Puts a townsperson beside the training Dummy in World.Live, runs Body(Rig, Dummy, Attacker) with the
-- "Parry" training dummy as the attacker (an NPC: no player, so no assault / morality record and no save change), and
-- puts both dummies back.
local function BesideDummy(T, Body)
	Fixture(T, function(_, _, Spawned)
		local Live = workspace.World.Live
		local Dummy, Attacker = Live:FindFirstChild("Dummy"), Live:FindFirstChild("Parry")
		T.True(Dummy and Dummy:FindFirstChild("HumanoidRootPart") and Attacker and Attacker:FindFirstChild("HumanoidRootPart"), "the training dummies")
		local DRoot = Dummy.HumanoidRootPart
		local Right = Flat(DRoot.CFrame.RightVector)
		local At = DRoot.Position + Right * 4 - Vector3.new(0, 3, 0)
		local Id = "TF_Dummy_" .. math.random(1e6)
		Post(Id, CFrame.lookAt(At, At + Flat(DRoot.CFrame.LookVector)), "Work")
		task.wait()
		local D = Def({{0, 24, Id}})
		local Rig = TS.Spawn(D, "Test")
		table.insert(Spawned, D.Id)
		local Homes = {[Dummy] = Dummy:GetPivot(), [Attacker] = Attacker:GetPivot()}
		local Ok, Err = pcall(Body, Rig, Dummy, Attacker)
		task.wait(0.5)
		for M, CF in pairs(Homes) do
			pcall(function() M:PivotTo(CF) M.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero end)
		end
		if not Ok then error(Err, 0) end
	end)
end

return {
	SpawnsAtCurrentPost = function(T)
		Fixture(T, function(Posts, Ids, Spawned)
			WorldClock.Hold(8)
			local D = Def({{0, 12, Ids.A}, {12, 24, Ids.B}})
			local Rig = TS.Spawn(D, "Test")
			table.insert(Spawned, D.Id)
			T.True(Rig ~= nil and Rig.Parent == workspace.World.Live.Townsfolk, "lives in World.Live.Townsfolk")
			T.Eq(TS.Get(D.Id), Rig, "Get")
			local Root = Rig.HumanoidRootPart
			T.True((Root.Position - Stand(Posts.A)).Magnitude < 4, "within 4 studs of its post")
			T.True(Flat(Root.CFrame.LookVector):Dot(Flat(Posts.A.CFrame.LookVector)) > 0.95, "faces the post's way")
			T.True(CollectionService:HasTag(Rig, "RenseiWatcher") and CollectionService:HasTag(Rig, "RenseiTownsfolk"), "tags")
			T.Eq(Rig:GetAttribute("WatcherType"), "Witness")
			T.Eq(Rig:GetAttribute("TownsfolkId"), D.Id)
			T.Eq(Rig:GetAttribute("Carrier"), false)
			T.Eq(Rig:GetAttribute("Faction"), "Townsfolk")
			T.Eq(Rig.Humanoid.DisplayName, D.Name)
			T.Eq(Rig:GetAttribute("IdleAnim"), D.Idle, "a Work post plays the townsperson's own idle")
			-- owner 2026-10-23: dressed from their own nation's outfit pool (read at spawn, so new variants count)
			local Ish = Def({{0, 24, Ids.C}}, "Ishvalan")
			local IRig = TS.Spawn(Ish, "Test")
			table.insert(Spawned, Ish.Id)
			local Shirt, Pants = IRig:FindFirstChildOfClass("Shirt"), IRig:FindFirstChildOfClass("Pants")
			local Match = false
			for _, Key in ipairs(Customization.NationLooks.Ishvalan.Outfits) do
				local Fit = Customization.Outfits[Key]
				if Fit and Shirt and Pants and Fit.Shirt == Shirt.ShirtTemplate and Fit.Pants == Pants.PantsTemplate then Match = true end
			end
			T.True(Match, "an Ishvalan wears an outfit from the Ishvalan pool")
			T.Eq(IRig:GetAttribute("Nation"), "Ishvalan")
			T.Eq(TS.State(Ish.Id) ~= nil, true, "has a state")
		end)
	end,

	WalksToNextPostOnScheduleChange = function(T)
		Fixture(T, function(Posts, Ids, Spawned)
			WorldClock.Hold(8)
			local D = Def({{0, 12, Ids.A}, {12, 24, Ids.B}})
			local Rig = TS.Spawn(D, "Test")
			table.insert(Spawned, D.Id)
			-- the test player stands 20 studs off the line, beside the middle post (within 50 of everything)
			local C = Player.Character
			local Side = Posts.B.CFrame.LookVector
			C:PivotTo(CFrame.new(Stand(Posts.B) + Side * 20))
			C.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
			task.wait(0.2)
			WorldClock.Hold(14)
			TS.Step()
			T.Eq(TS.State(D.Id), "Walking", "walks when someone is near")
			local T0 = os.clock()
			while os.clock() - T0 < 15 and TS.State(D.Id) ~= "AtPost" do task.wait(0.25) end
			T.Eq(TS.State(D.Id), "AtPost", "arrived within 15 s")
			local Root = Rig.HumanoidRootPart
			T.True((Root.Position - Stand(Posts.B)).Magnitude < 1, "on the new post")
			T.True(Flat(Root.CFrame.LookVector):Dot(Flat(Posts.B.CFrame.LookVector)) > 0.99, "faces the new post's way")
			T.True(Root.Anchored, "held at the post")
			T.Eq(Rig:GetAttribute("IdleAnim"), "NPC_CrossArms", "a Counter post's idle")
			T.True(os.clock() - T0 > 2, "it walked (took " .. string.format("%.1f", os.clock() - T0) .. " s)")
		end)
	end,

	-- fix round 1 (minors 3-5): broken walks end settled. A post removed mid-walk -> held where it stands; a walk
	-- cancelled behind the service's back -> the Step watchdog settles it; an error inside a walk -> "failed" with the
	-- rig held still; a townsperson whose Step throws doesn't stop the others.
	RecoversFromBrokenWalks = function(T)
		Fixture(T, function(Posts, Ids, Spawned)
			local Mover = require(SSS.TownsfolkService.Mover)
			WorldClock.Hold(8)
			local A, B, Bad = Def({{0, 12, Ids.A}, {12, 24, Ids.C}}), Def({{0, 12, Ids.B}, {12, 24, Ids.A}}), Def({{0, 24, Ids.B}})
			for _, D in ipairs({A, B, Bad}) do TS.Spawn(D, "Test") table.insert(Spawned, D.Id) end
			local C = Player.Character
			C:PivotTo(CFrame.new(Stand(Posts.B) + Posts.B.CFrame.LookVector * 20))
			task.wait(0.2)
			Bad.Schedule = "broken" -- its Step throws from now on
			WorldClock.Hold(14)
			TS.Step()
			T.Eq(TS.State(A.Id), "Walking", "A walks despite the broken one")
			T.Eq(TS.State(B.Id), "Walking", "B walks despite the broken one")
			-- B: cancelled behind the service's back -> with the player near, the watchdog walks it on to its target
			-- (Task 6b: nobody may see a teleport, the same 60-stud gate as a failed walk); it arrives
			Mover.Place(TS.Get(B.Id), TS.Get(B.Id).HumanoidRootPart.CFrame)
			TS.Step()
			T.Eq(TS.State(B.Id), "Walking", "watchdog: B walks on (a player is near)")
			T.True(Mover.Handle(TS.Get(B.Id)) ~= nil, "with a live walk")
			local TB = os.clock()
			while os.clock() - TB < 15 and TS.State(B.Id) ~= "AtPost" do task.wait(0.25) end
			T.Eq(TS.State(B.Id), "AtPost", "B arrived")
			T.True((TS.Get(B.Id).HumanoidRootPart.Position - Stand(Posts.A)).Magnitude < 1, "at its post")
			-- A: its target post is removed mid-walk -> held where it stands, upright, with an idle
			task.wait(1)
			Posts.C:Destroy()
			local T0 = os.clock()
			while os.clock() - T0 < 15 and TS.State(A.Id) ~= "AtPost" do task.wait(0.25) end
			local RA = TS.Get(A.Id)
			T.Eq(TS.State(A.Id), "AtPost", "A settled")
			T.True(RA.HumanoidRootPart.Anchored and RA:GetAttribute("IdleAnim") ~= nil, "A held still, posed")
			T.True(math.abs(RA.HumanoidRootPart.CFrame.LookVector.Y) < 0.01, "upright")
			-- an error inside a walk: "failed", rig held still
			local Result
			local H = Mover.WalkTo(RA, RA.HumanoidRootPart.CFrame * CFrame.new(0, 0, -10), {Agent = {AgentRadius = "not a number"}, OnDone = function(R) Result = R end})
			T0 = os.clock()
			while os.clock() - T0 < 3 and not Result do task.wait(0.1) end
			T.Eq(Result, "failed", "an error ends the walk as failed")
			T.Eq(H.Status, "failed")
			T.True(RA.HumanoidRootPart.Anchored, "held still after the error")
		end)
	end,

	SleepsWithNoPlayerNear = function(T)
		Fixture(T, function(Posts, Ids, Spawned)
			WorldClock.Hold(8)
			local D = Def({{0, 12, Ids.A}, {12, 24, Ids.C}})
			local Rig = TS.Spawn(D, "Test")
			table.insert(Spawned, D.Id)
			local C = Player.Character
			C.HumanoidRootPart.Anchored = true
			C:PivotTo(C:GetPivot() + Vector3.new(0, TS.SleepRadius + 200, 0))
			WorldClock.Hold(14)
			TS.Step()
			T.Eq(TS.State(D.Id), "Asleep", "asleep with nobody near")
			T.True((Rig.HumanoidRootPart.Position - Stand(Posts.C)).Magnitude < 1, "placed at the new post at once")
			T.Eq(Rig:GetAttribute("IdleAnim"), "NPC_Chill", "a Seat post's idle")
		end)
	end,

	-- fix round 1: a melee sweep through a townsperson still lands on the Dummy beside it, without errors. Task 6b:
	-- townsfolk have a WCS character now, but only players hurt them, so this NPC's hit on the townsperson is still a
	-- no-hit with no side effects (Play_TownsfolkHurt covers a player's sweep)
	MeleeSweepThroughTownsperson = function(T)
		BesideDummy(T, function(Rig, Dummy, Attacker)
			local HitboxManager = require(Managers.HitboxManager)
			local SkillData = require(game.ReplicatedStorage.Modules.Data.SkillData)
			-- the attacker stands 3.5 studs behind the gap between them, facing it: Light1's 6x6x7 box covers both
			local Mid = (Dummy.HumanoidRootPart.Position + Rig.HumanoidRootPart.Position) / 2
			local From = Mid - Flat(Dummy.HumanoidRootPart.CFrame.LookVector) * 3.5
			Attacker:PivotTo(CFrame.lookAt(From, Mid))
			local Box = HitboxManager.CreateHitbox(Attacker, SkillData.Light1)
			T.True(table.find(Box, Dummy) ~= nil and table.find(Box, Rig) ~= nil, "the box takes in both")
			local Results = HitboxManager.Sweep(Attacker, "Light1", 0)
			local Got = {}
			for _, R in ipairs(Results) do Got[R.Victim] = R.Result end
			T.True(Got[Dummy] ~= nil and Got[Dummy] ~= "IFramed", "the Dummy is hit (" .. tostring(Got[Dummy]) .. ")")
			T.Eq(Got[Rig], "IFramed", "the townsperson: no hit")
			T.Eq(Rig:GetAttribute("LastHitAt"), nil, "no side effects on the townsperson")
		end)
	end,

	ValidRosterOnly = function(T)
		Fixture(T, function(Posts, Ids)
			local function Count() local F = workspace.World.Live:FindFirstChild("Townsfolk") return F and #F:GetChildren() or 0 end
			local Before = Count()
			local Good = Def({{0, 24, Ids.A}})
			local Bad = Def({{0, 12, Ids.A}, {12, 24, "NoSuchPost_" .. Ids.A}})
			local Ok = TS.LoadRegion("Test", {Good, Bad})
			T.Eq(Ok, false, "a roster naming a missing post is refused")
			T.Eq(Count(), Before, "spawns nothing")
			T.Eq(TS.Get(Good.Id), nil, "not even the valid one")
			T.Eq(TS.LoadRegion("Test", {Good, 5}), false, "a non-table entry is refused, not thrown")
		end)
	end,
	-- Task 6: a fight nearby sends them to the nearest shelter (Fleeing, then Sheltering, curled up, no Talk); calm
	-- again CalmSeconds after the last combat sound, they walk back to their post
	FleesOnCombatNoiseAndReturns = function(T)
		Fixture(T, function(Posts, Ids, Spawned)
			local WasCalm = TS.CalmSeconds
			local Ok, Err = pcall(function()
				WorldClock.Hold(8)
				-- a Shelter post 30 studs along the line from A (the fixture checked that ground is flat)
				local Along = (Posts.B.Position - Posts.A.Position).Unit
				local ShelterId = "TF_Shelter_" .. math.random(1e6)
				local SPos = Posts.A.Position + Along * 30
				local Shelter = Post(ShelterId, CFrame.lookAt(SPos, SPos + Posts.A.CFrame.LookVector), "Shelter")
				task.wait()
				local D = Def({{0, 24, Ids.A}})
				local Rig = TS.Spawn(D, "Test")
				table.insert(Spawned, D.Id)
				BesideLine(Posts)
				-- (Task 6b fix round 1: longer than the ~3.1 s run, so the service's own Step can't end Sheltering before the
				-- poll below sees it; with 2 s it sometimes did, once in about 6 runs)
				TS.CalmSeconds = 6
				T.True(Rig.HumanoidRootPart.TalkPrompt.Enabled, "the Talk prompt is on at the post")
				local Before = select(3, TS.LastLine(D.Id))
				NoiseService.Emit(Rig.HumanoidRootPart.Position + Vector3.new(5, 0, 0), "Hit", nil)
				TS.Step()
				T.Eq(TS.State(D.Id), "Fleeing", "a hit 5 studs off: fleeing")
				local Line, Kind, N = TS.LastLine(D.Id)
				T.Eq(Kind, "Flee", "a Flee line")
				T.True(N == Before + 1 and table.find(TownsfolkLogic.Chatter.Flee, Line) ~= nil, "one of the Flee lines: " .. tostring(Line))
				T.Eq(Rig.HumanoidRootPart.TalkPrompt.Enabled, false, "no talking while fleeing")
				T.Eq(Rig.Humanoid.WalkSpeed, TS.FleeSpeed, "runs at FleeSpeed")
				local T0 = os.clock()
				while os.clock() - T0 < 10 and TS.State(D.Id) ~= "Sheltering" do task.wait(0.1) end
				local Took = os.clock() - T0
				T.Eq(TS.State(D.Id), "Sheltering", "sheltering within 10 s")
				print(("[Townsfolk] fled 30 studs in %.1f s"):format(Took))
				T.True((Rig.HumanoidRootPart.Position - Stand(Shelter)).Magnitude < 1.5, "at the shelter")
				T.Eq(Rig:GetAttribute("IdleAnim"), "NPC_CurledUp", "curled up")
				T.Eq(Rig.HumanoidRootPart.TalkPrompt.Enabled, false, "no talking while sheltering")
				T.Eq(TS.Talk(Player, D.Id), nil, "Talk says nothing while sheltering")
				-- calm: back to the post within 17 s (the rest of the 6 s calm, then the walk back)
				T0 = os.clock()
				local SawReturn = false
				while os.clock() - T0 < 17 and not (TS.State(D.Id) == "AtPost" and (Rig.HumanoidRootPart.Position - Stand(Posts.A)).Magnitude < 1) do
					TS.Step()
					if select(2, TS.LastLine(D.Id)) == "Return" then SawReturn = true end
					task.wait(0.25)
				end
				T.Eq(TS.State(D.Id), "AtPost", "back at the post within 17 s")
				T.True((Rig.HumanoidRootPart.Position - Stand(Posts.A)).Magnitude < 1, "on its own post")
				T.True(SawReturn, "a Return line on the way back")
				T.Eq(Rig:GetAttribute("IdleAnim"), D.Idle, "its own idle again")
				T.True(Rig.HumanoidRootPart.TalkPrompt.Enabled, "the Talk prompt is back")
				T.Eq(Rig.Humanoid.WalkSpeed, TS.WalkSpeed, "strolling again")
				-- a sound that isn't a fight (footsteps) or is out of range changes nothing
				NoiseService.Emit(Rig.HumanoidRootPart.Position + Vector3.new(3, 0, 0), 9, nil)
				NoiseService.Emit(Rig.HumanoidRootPart.Position + Vector3.new(20 + TS.FleeMargin + 5, 0, 0), "Hit", nil)
				T.Eq(TS.State(D.Id), "AtPost", "footsteps and far fights don't scare them")
			end)
			TS.CalmSeconds = WasCalm
			if not Ok then error(Err, 0) end
		end)
	end,

	-- Task 6: townsfolk are witnesses (PerceptionService tracks them)
	WitnessTagged = function(T)
		Fixture(T, function(Posts, Ids, Spawned)
			WorldClock.Hold(8)
			local D = Def({{0, 24, Ids.A}})
			local Rig = TS.Spawn(D, "Test")
			table.insert(Spawned, D.Id)
			task.wait(0.1)
			T.True(CollectionService:HasTag(Rig, "RenseiWatcher"), "tagged RenseiWatcher")
			T.True(require(SSS.PerceptionService).Tracks(Rig), "PerceptionService registered it")
		end)
	end,

	-- Task 6: the first line is the greeting for the player's standing tier with the townsperson's faction here
	TalkGreetsByStanding = function(T)
		Fixture(T, function(Posts, Ids, Spawned)
			WorldClock.Hold(8)
			local D = Def({{0, 24, Ids.A}})
			local Rig = TS.Spawn(D, "Test")
			table.insert(Spawned, D.Id)
			local Prompt = Rig.HumanoidRootPart:FindFirstChild("TalkPrompt")
			T.True(Prompt ~= nil and Prompt:IsA("ProximityPrompt"), "a TalkPrompt on the root")
			T.Eq(Prompt.ActionText, "Talk") T.Eq(Prompt.ObjectText, D.Name) T.Eq(Prompt.MaxActivationDistance, 10)
			T.Eq(Rig:GetAttribute("DialogueId"), nil, "no DialogueId: not the dialogue box")
			local Real = Reputation.PlaceStanding
			local Ok, Err = pcall(function()
				RecordSignals(function(Calls)
					Reputation.PlaceStanding = function() return {Townsfolk = 70} end
					local Text, Kind = TS.Talk(Player, D.Id)
					Reputation.PlaceStanding = Real
					T.Eq(Kind, "Greeting")
					T.Eq(Text, TownsfolkLogic.Greeting("Honoured", D), "70 with the Townsfolk: Honoured")
					T.Eq(TS.LastLine(D.Id), TownsfolkLogic.Greeting("Honoured", D), "LastLine")
					T.True(#Calls >= 1 and Calls[1][1] == Player and Calls[1][2] == "Talk" and Calls[1][3] == D.Id, "QuestService.Signal(Player, \"Talk\", Id)")
				end)
			end)
			Reputation.PlaceStanding = Real
			if not Ok then error(Err, 0) end
		end)
	end,

	-- Task 6: greeting -> a rumour the region has heard -> the job line -> greeting -> (rumour told) the job line
	RumourIsTheSecondLine = function(T)
		Fixture(T, function(Posts, Ids, Spawned)
			WorldClock.Hold(8)
			local D = Def({{0, 24, Ids.A}})
			TS.Spawn(D, "Test")
			table.insert(Spawned, D.Id)
			Deeds.__test_t6_rumour = {Text = "Kicked over a market stall", Standing = {}, Scope = "Local"}
			local M = PS.GetData(Player).Morality
			local Saved = M.News
			local Lines = {}
			local Ok, Err = pcall(function()
				RecordSignals(function()
					-- (no yield from here until News is put back)
					M.News = table.clone(Saved or {})
					table.insert(M.News, {At = os.time() + 100000, Place = "Test", Deed = "__test_t6_rumour", Heard = {"Townsfolk"}})
					for I = 1, 5 do Lines[I] = {TS.Talk(Player, D.Id)} end
					M.News = Saved
				end)
			end)
			M.News = Saved
			Deeds.__test_t6_rumour = nil
			if not Ok then error(Err, 0) end
			T.Eq(Lines[1][2], "Greeting", "1: greeting")
			T.Eq(Lines[2][2], "Rumour", "2: a rumour")
			T.Eq(Lines[2][1], "They say you kicked over a market stall.", "the deed, about the listener")
			T.Eq(Lines[3][2], "Job", "3: the job line") T.Eq(Lines[3][1], D.JobLine)
			T.Eq(Lines[4][2], "Greeting", "4: greeting again")
			T.Eq(Lines[5][2], "Job", "5: the rumour was told already: the job line")
		end)
	end,

	-- Fix round 1 (owner 2026-10-23: "Name if known, else 'someone'"): a rumour names someone else by the name the
	-- listener has identified them by, otherwise "someone"; never the journal's "Subject 03". HeardIn and IdentityService
	-- are patched (one player in the test server), then put back.
	RumourNamesKnownOrSomeone = function(T)
		Fixture(T, function(Posts, Ids, Spawned)
			WorldClock.Hold(8)
			local D = Def({{0, 24, Ids.A}})
			TS.Spawn(D, "Test")
			table.insert(Spawned, D.Id)
			local RumourService = require(SSS.RumourService)
			local IdentityService = require(SSS.IdentityService)
			local Other = Instance.new("Folder") -- (stands in for another player: only its identity matters here)
			local RealHeard, RealKnown, RealLabel = RumourService.HeardIn, IdentityService.KnownNameFor, IdentityService.LabelFor
			local Known = nil
			local Lines = {}
			local Ok, Err = pcall(function()
				RecordSignals(function()
					RumourService.HeardIn = function() return {{At = 1, Text = "Struck a townsperson", Subject = Other}} end
					IdentityService.KnownNameFor = function(Viewer, Subject) return Subject == Other and Known or nil end
					IdentityService.LabelFor = function() return "Subject 03" end -- (the journal's label must not be spoken)
					for I = 1, 2 do Lines[I] = {TS.Talk(Player, D.Id)} end -- greeting, then the rumour, unidentified
					Known = "Ansel"
					local D2 = Def({{0, 24, Ids.B}}) -- (a fresh townsperson: this rumour is new to the player again)
					TS.Spawn(D2, "Test")
					table.insert(Spawned, D2.Id)
					for I = 3, 4 do Lines[I] = {TS.Talk(Player, D2.Id)} end
				end)
			end)
			RumourService.HeardIn, IdentityService.KnownNameFor, IdentityService.LabelFor = RealHeard, RealKnown, RealLabel
			Other:Destroy()
			if not Ok then error(Err, 0) end
			T.Eq(Lines[2][1], "They say someone struck a townsperson.", "not identified: someone")
			T.Eq(Lines[4][1], "They say Ansel struck a townsperson.", "identified: the name they know")
		end)
	end,

	-- Fix round 2 (controller ruling): rumour and clue lines go only to the talker; greetings, job lines and chatter go
	-- to everyone near. Talk's own sends (one player in Studio), then Recipients over two stand-in players (a talker and
	-- a bystander, real character models at real distances) and one out of range.
	PrivateRumoursPublicGreetings = function(T)
		Fixture(T, function(Posts, Ids, Spawned)
			WorldClock.Hold(8)
			local D = Def({{0, 24, Ids.A}})
			D.Clue = {Quest = "__t6_quest2", Stage = 1, Text = "Ask the ferryman.", Signal = "__t6_signal2"}
			local Rig = TS.Spawn(D, "Test")
			table.insert(Spawned, D.Id)
			BesideLine(Posts)
			Deeds.__test_t6_private = {Text = "Kicked over a market stall", Standing = {}, Scope = "Local"}
			local M = PS.GetData(Player).Morality
			local Data = PS.GetData(Player)
			local Saved = M.News
			local Got = {}
			local Ok, Err = pcall(function()
				RecordSignals(function()
					-- (no yield from here until News and the quest entry are put back)
					M.News = table.clone(Saved or {})
					table.insert(M.News, {At = os.time() + 100000, Place = "Test", Deed = "__test_t6_private", Heard = {"Townsfolk"}})
					for I = 1, 3 do
						local Text, Kind = TS.Talk(Player, D.Id)
						local To, Only = TS.LastRecipients(D.Id)
						Got[I] = {Kind = Kind, To = To, Only = Only}
					end
					Data.Quests.Active.__t6_quest2 = {Stage = 1, Progress = {}}
					local _, Kind = TS.Talk(Player, D.Id)
					local To, Only = TS.LastRecipients(D.Id)
					Got[4] = {Kind = Kind, To = To, Only = Only}
					Data.Quests.Active.__t6_quest2 = nil
					M.News = Saved
				end)
			end)
			M.News = Saved
			Data.Quests.Active.__t6_quest2 = nil
			Deeds.__test_t6_private = nil
			if not Ok then error(Err, 0) end
			T.Eq(Got[1].Kind, "Greeting") T.Eq(Got[1].Only, nil, "a greeting is public")
			T.Eq(Got[2].Kind, "Rumour") T.Eq(Got[2].Only, Player, "a rumour is the talker's alone")
			T.Eq(#Got[2].To, 1) T.Eq(Got[2].To[1], Player)
			T.Eq(Got[3].Kind, "Job") T.Eq(Got[3].Only, nil, "the job line is public")
			T.Eq(Got[4].Kind, "Clue") T.Eq(Got[4].Only, Player, "a clue is the talker's alone")
			-- two stand-in players: the talker 6 studs off, a bystander 12 off, someone 150 off
			local Here = Rig.HumanoidRootPart.Position
			local Made = {}
			local function Stand(Name, Off)
				local Model = Instance.new("Model")
				Model.Name = Name
				local R = Instance.new("Part")
				R.Name = "HumanoidRootPart"
				R.Position = Here + Off
				R.Parent = Model
				table.insert(Made, Model)
				return {Name = Name, Character = Model}
			end
			local Talker, Bystander, Far = Stand("Talker", Vector3.new(6, 0, 0)), Stand("Bystander", Vector3.new(0, 0, 12)), Stand("Far", Vector3.new(150, 0, 0))
			local List = {Talker, Bystander, Far}
			local function Names(Out) local N = {} for _, P in ipairs(Out) do table.insert(N, P.Name) end return table.concat(N, ",") end
			T.Eq(Names(TS.Recipients(Here, nil, List)), "Talker,Bystander", "public: everyone within SayRadius")
			T.Eq(Names(TS.Recipients(Here, {Only = Talker}, List)), "Talker", "private: the talker only, not the bystander")
			T.Eq(Names(TS.Recipients(Here, {Only = Far}, List)), "", "private and out of range: nobody")
			for _, Model in ipairs(Made) do Model:Destroy() end
		end)
	end,

	-- Fix round 2 (review N1): the real IdentityService.KnownNameFor. A record with no name yet -> nil; named -> the
	-- name. (One player in Studio: the record is put in the player's own book under their own id, then removed.)
	KnownNameForIsTheIdentifiedName = function(T)
		local IdentityService = require(SSS.IdentityService)
		local D = PS.GetData(Player)
		local Key = IdentityService.CharacterIdOf(Player)
		IdentityService.KnownNameFor(Player, Player) -- (makes the book if the save has none yet, as LabelFor does)
		T.True(Key ~= nil and type(D.Identities) == "table" and type(D.Identities.Records) == "table", "the player has an identity book")
		local Records = D.Identities.Records
		local Saved = Records[Key]
		local A, B
		local Ok, Err = pcall(function()
			-- (no yield while the test record is in the book)
			Records[Key] = {N = 99, First = 0, Last = 0, Seen = 1, Obs = {}, Name = "", Src = "", Links = {}, Log = {}, Lock = 0}
			A = IdentityService.KnownNameFor(Player, Player)
			Records[Key].Name = "Ansel"
			B = IdentityService.KnownNameFor(Player, Player)
		end)
		Records[Key] = Saved
		if not Ok then error(Err, 0) end
		T.Eq(A, nil, "a record with no name: nil")
		T.Eq(B, "Ansel", "named: the name")
	end,

	-- Fix round 1: one player's Talks are at least TalkCooldown apart (server side)
	TalkCooldown = function(T)
		Fixture(T, function(Posts, Ids, Spawned)
			WorldClock.Hold(8)
			local D = Def({{0, 24, Ids.A}})
			TS.Spawn(D, "Test")
			table.insert(Spawned, D.Id)
			RecordSignals(function()
				TS.TalkCooldown = 0.5
				task.wait(0.6) -- (clear of the earlier tests' Talks)
				local First = TS.Talk(Player, D.Id)
				local Second = TS.Talk(Player, D.Id)
				task.wait(0.6)
				local Third, Kind = TS.Talk(Player, D.Id)
				T.True(First ~= nil, "the first Talk speaks")
				T.Eq(Second, nil, "a second Talk within 0.5 s says nothing")
				T.True(Third ~= nil and Kind == "Job", "after the cooldown, the next line (" .. tostring(Kind) .. ")")
			end)
		end)
	end,

	-- Task 6: on the clue's quest stage the clue line comes first, then QuestService.Signal(Player, "Signal", ...)
	ClueLineOnTheStage = function(T)
		Fixture(T, function(Posts, Ids, Spawned)
			WorldClock.Hold(8)
			local D = Def({{0, 24, Ids.A}})
			D.Clue = {Quest = "__t6_quest", Stage = 2, Text = "I saw a cart by the gate after dark.", Signal = "__t6_signal"}
			TS.Spawn(D, "Test")
			table.insert(Spawned, D.Id)
			local Data = PS.GetData(Player)
			local Ok, Err = pcall(function()
				RecordSignals(function(Calls)
					-- (no yield from here until the quest entry is removed)
					Data.Quests.Active.__t6_quest = {Stage = 1, Progress = {}}
					local _, K1 = TS.Talk(Player, D.Id)
					Data.Quests.Active.__t6_quest.Stage = 2
					local Text, K2 = TS.Talk(Player, D.Id)
					Data.Quests.Active.__t6_quest = nil
					T.Eq(K1, "Greeting", "another stage: the usual rotation")
					T.Eq(K2, "Clue") T.Eq(Text, D.Clue.Text)
					local Got = false
					for _, C in ipairs(Calls) do if C[2] == "Signal" and C[3] == "__t6_signal" then Got = true end end
					T.True(Got, "the clue's signal")
				end)
			end)
			Data.Quests.Active.__t6_quest = nil
			if not Ok then error(Err, 0) end
		end)
	end,

	-- Task 6: a player first coming within PassRadius gets one remark, and not again within PassEvery
	PassChatterOnce = function(T)
		Fixture(T, function(Posts, Ids, Spawned)
			WorldClock.Hold(8)
			local D = Def({{0, 24, Ids.A}})
			local Rig = TS.Spawn(D, "Test")
			table.insert(Spawned, D.Id)
			local C = Player.Character
			local Root = C.HumanoidRootPart
			Root.Anchored = true -- (held where it is put)
			local Far = Stand(Posts.A) + Posts.A.CFrame.LookVector * 30
			local NearBy = Stand(Posts.A) + Posts.A.CFrame.LookVector * 8
			C:PivotTo(CFrame.new(Far)) TS.Step()
			local N0 = select(3, TS.LastLine(D.Id))
			C:PivotTo(CFrame.new(NearBy)) TS.Step()
			local Line, Kind, N1 = TS.LastLine(D.Id)
			T.Eq(Kind, "Pass", "a passing remark")
			T.True(N1 == N0 + 1 and table.find(TownsfolkLogic.Chatter.Pass, Line) ~= nil, "one Pass line: " .. tostring(Line))
			TS.Step()
			T.Eq(select(3, TS.LastLine(D.Id)), N1, "nothing more while still near")
			C:PivotTo(CFrame.new(Far)) TS.Step()
			C:PivotTo(CFrame.new(NearBy)) TS.Step()
			T.Eq(select(3, TS.LastLine(D.Id)), N1, "not again within PassEvery")
			T.True(Rig.Parent ~= nil)
		end)
	end,
}

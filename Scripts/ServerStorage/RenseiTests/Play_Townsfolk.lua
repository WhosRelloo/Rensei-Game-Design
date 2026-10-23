-- Play_Townsfolk (Region Foundation Task 5, 2026-10-23): TownsfolkService inside the game VM (LMRunSuite).
-- The fixture finds clear, flat ground near the Lindenmoor square by raycasting, puts three test posts there 40 studs
-- apart, and removes everything afterwards (posts, rigs, the clock hold, the moved player). The service's own 1 Hz
-- loop keeps running during the tests; it reads the same held hour, so it agrees with the hand-called Step().
local SSS = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local TS = require(SSS.TownsfolkService)
local WorldClock = require(SSS.WorldClock)
local Customization = require(game.ReplicatedStorage.Modules.Data.Rensei.Customization)
local Player = game.Players:GetPlayers()[1]
local Managers = game.ReplicatedStorage.Modules.Managers

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

-- fix round 1: a townsperson has no WCS character yet (Task 6b), and DamageManager used to throw on one, aborting the
-- whole sweep. Puts a townsperson beside the training Dummy in World.Live, runs Body(Rig, Dummy, Attacker) with the
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
			-- B: cancelled behind the service's back -> the watchdog settles it at its target
			Mover.Place(TS.Get(B.Id), TS.Get(B.Id).HumanoidRootPart.CFrame)
			TS.Step()
			T.Eq(TS.State(B.Id), "AtPost", "watchdog settled B")
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

	-- fix round 1: a melee sweep through a townsperson (no WCS character) still lands on the Dummy beside it, without
	-- errors, and the townsperson's hit is a no-hit with no side effects
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
}

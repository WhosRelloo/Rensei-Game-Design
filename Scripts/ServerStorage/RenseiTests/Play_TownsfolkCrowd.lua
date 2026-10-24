-- Play_TownsfolkCrowd (Region Foundation Task 5b, 2026-10-23): crowd-quality townsfolk movement (TownsfolkService.Mover)
-- inside the game VM (LMRunSuite). Owner: "I don't want them to walk through each other."
-- Each test builds its own fixture on a clear, flat test floor (a 200 x 200 Concrete slab put on an empty spot of Ye,
-- checked empty first), spawns test-only townsfolk through TownsfolkService.LoadRegion, makes them walk by moving the
-- held clock from 8 to 14 (their schedules change post at 12), samples every root at 10 Hz, and removes everything
-- afterwards in pcall-guarded cleanup (rigs, posts, walls, the floor, the clock hold, the moved player).
-- Measurements are printed as "[Crowd] ..." lines (read them from the console).
local SSS = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local TS = require(SSS.TownsfolkService)
local Mover = require(SSS.TownsfolkService.Mover)
local WorldClock = require(SSS.WorldClock)
local Player = game.Players:GetPlayers()[1]

-- empty spots of Ye, far outside the map (tried in order; the first with nothing in its box is used)
local SITES = {Vector3.new(-700, 300, 700), Vector3.new(700, 300, 700), Vector3.new(-700, 300, -3300)}
local FLOOR = 200

local function Site()
	for _, C in ipairs(SITES) do
		if #workspace:GetPartBoundsInBox(CFrame.new(C + Vector3.new(0, 30, 0)), Vector3.new(FLOOR + 20, 80, FLOOR + 20)) == 0 then return C end
	end
	return nil
end

local function Flat(V) return Vector3.new(V.X, 0, V.Z) end

-- builds the fixture, runs Body(Ctx), and always cleans up
local function Fixture(T, Name, Body)
	local O = Site()
	T.True(O ~= nil, "an empty spot for the test floor")
	local Folder = Instance.new("Folder")
	Folder.Name = "CrowdTest_" .. Name
	Folder.Parent = workspace
	local Ground = O.Y + 1
	local Ids, Extra = {}, {}
	local WasHeld, WasHour = WorldClock.IsHeld(), WorldClock.Now()
	local C = Player and Player.Character
	local Home = C and C:GetPivot()
	local Root = C and C:FindFirstChild("HumanoidRootPart")
	local WasAnchored = Root and Root.Anchored
	local Ctx = {O = O, Ground = Ground, Ids = Ids, Folder = Folder, Extra = Extra}

	function Ctx.At(X, Z) return Vector3.new(O.X + X, Ground, O.Z + Z) end
	function Ctx.Part(Pos, Size, Props)
		local P = Instance.new("Part")
		P.Anchored = true
		P.Size = Size
		P.CFrame = CFrame.new(Pos)
		P.Material = Enum.Material.Concrete
		P.Color = Color3.fromRGB(150, 150, 150)
		for K, V in pairs(Props or {}) do P[K] = V end
		P.Parent = Folder
		return P
	end
	-- a wall standing on the floor: centre (X, Z), length along X = SX, along Z = SZ
	function Ctx.Wall(X, Z, SX, SZ, H)
		H = H or 8
		return Ctx.Part(Ctx.At(X, Z) + Vector3.new(0, H / 2, 0), Vector3.new(SX, H, SZ), {Color = Color3.fromRGB(120, 95, 80), Material = Enum.Material.Brick})
	end
	local PostN = 0
	function Ctx.Post(X, Z, Face)
		PostN += 1
		local Id = "Crowd_" .. Name .. "_" .. PostN .. "_" .. math.random(1e6)
		local Pos = Ctx.At(X, Z) + Vector3.new(0, 0.1, 0)
		local P = Ctx.Part(Pos, Vector3.new(2, 0.2, 2), {CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 0.5,
			Color = Color3.fromRGB(80, 160, 255)})
		P.CFrame = CFrame.lookAt(Pos, Pos + Flat(Face or Vector3.new(1, 0, 0)))
		P.Name = Id
		P:SetAttribute("PostId", Id)
		P:SetAttribute("Kind", "Counter")
		CollectionService:AddTag(P, "RenseiPost")
		return Id, P
	end
	local function Stand(P) return (P.CFrame * CFrame.new(0, 3, 0)).Position end

	-- Walkers {{From = {X, Z}, To = {X, Z}}, ...}: one post per distinct spot (a swap shares posts, at different hours),
	-- facing the way its first walker travels; the roster is loaded at hour 8 (everyone at their start post).
	-- Returns the list of {Id, Rig, End (standing position at the end post)}.
	local ByKey = {}
	function Ctx.Walkers(List)
		local function PostOf(Spec, Dir)
			local Key = Spec[1] .. "," .. Spec[2]
			if not ByKey[Key] then ByKey[Key] = Ctx.Post(Spec[1], Spec[2], Dir) end
			return ByKey[Key]
		end
		local Roster, Out = {}, {}
		for _, W in ipairs(List) do
			local Dir = Ctx.At(W.To[1], W.To[2]) - Ctx.At(W.From[1], W.From[2])
			W.FromId = PostOf(W.From, Dir)
			W.ToId = PostOf(W.To, Dir)
		end
		task.wait() -- the post signal is deferred
		for I, W in ipairs(List) do
			local Id = string.format("Crowd%s_%02d_%d", Name, I, math.random(1e6))
			table.insert(Ids, Id)
			table.insert(Roster, {
				Id = Id, Name = "Crowd " .. I, Job = "Tester", JobLine = "Just testing.", Faction = "Townsfolk", Idle = "NPC_CrossArms",
				Look = {Nation = ({"Amestrian", "Xingnese", "Ishvalan", "Xerxian", "Aerugonian"})[(I - 1) % 5 + 1], Seed = 2000 + I},
				Schedule = {{0, 12, W.FromId}, {12, 24, W.ToId}},
			})
			W.Id = Id
		end
		WorldClock.Hold(8)
		T.Eq(TS.LoadRegion("Test", Roster), true, "the test roster loads")
		for _, W in ipairs(List) do
			table.insert(Out, {Id = W.Id, Rig = TS.Get(W.Id), End = Stand(TS.Posts[W.ToId])})
			T.True(Out[#Out].Rig ~= nil, "spawned " .. W.Id)
		end
		return Out
	end

	-- the schedule moves on: everyone walks (a player is on the floor, so nobody is asleep)
	function Ctx.Go()
		WorldClock.Hold(14)
		TS.Step()
	end

	-- samples every walker (and Extra models) at 10 Hz until all have arrived or Timeout s pass.
	-- Returns {Arrived = {[Id] = s}, All = bool, Min = closest pair, MinTo = {[Model] = closest walker}, Below = {[pair] = s},
	-- MaxBelow = the worst pair's total time under Thresh, States = {[state] = true}}
	function Ctx.Track(Walkers, Timeout, Thresh, ExtraModels)
		Thresh = Thresh or 2.2
		local T0 = os.clock()
		local Last = T0
		local R = {Arrived = {}, All = false, Min = math.huge, MinTo = {}, Below = {}, MaxBelow = 0, States = {}}
		while true do
			local Now = os.clock()
			local Dt = Now - Last
			Last = Now
			local Pos = {}
			for I, W in ipairs(Walkers) do
				local Rt = W.Rig and W.Rig:FindFirstChild("HumanoidRootPart")
				Pos[I] = Rt and Rt.Position
				local St = TS.State(W.Id)
				R.States[tostring(St)] = true
				if not R.Arrived[W.Id] and St == "AtPost" and Pos[I] and (Pos[I] - W.End).Magnitude < 1.5 then
					R.Arrived[W.Id] = Now - T0
				end
			end
			for I = 1, #Walkers do
				for J = I + 1, #Walkers do
					if Pos[I] and Pos[J] then
						local D = (Pos[I] - Pos[J]).Magnitude
						if D < R.Min then R.Min = D end
						if D < Thresh then
							local K = I .. "-" .. J
							R.Below[K] = (R.Below[K] or 0) + Dt
							R.MaxBelow = math.max(R.MaxBelow, R.Below[K])
						end
					end
				end
				for _, M in ipairs(ExtraModels or {}) do
					local Rt = M:FindFirstChild("HumanoidRootPart")
					if Pos[I] and Rt then
						local D = (Pos[I] - Rt.Position).Magnitude
						R.MinTo[M] = math.min(R.MinTo[M] or math.huge, D)
					end
				end
			end
			local All = true
			for _, W in ipairs(Walkers) do if not R.Arrived[W.Id] then All = false end end
			R.All = All
			if All or Now - T0 > Timeout then break end
			task.wait(0.1)
		end
		local Worst = 0
		for _, S in pairs(R.Arrived) do Worst = math.max(Worst, S) end
		R.Last = Worst
		return R
	end

	-- the test player stands still in a far corner of the floor: near enough that townsfolk walk (not asleep), far
	-- enough that it is in nobody's way
	pcall(function()
		if Root then
			Root.Anchored = true
			C:PivotTo(CFrame.new(O + Vector3.new(FLOOR / 2 - 8, 4, FLOOR / 2 - 8)))
		end
	end)
	workspace:SetAttribute("RenseiCrowdTest", Name)
	local Floor = Ctx.Part(O, Vector3.new(FLOOR, 2, FLOOR), {Color = Color3.fromRGB(110, 110, 105)})
	Floor.Name = "Floor"
	task.wait(0.5) -- the navmesh picks up the new floor
	local Ok, Err = pcall(Body, Ctx)
	workspace:SetAttribute("RenseiCrowdTest", nil)
	for _, Id in ipairs(Ids) do pcall(TS.Despawn, Id) end
	for _, M in ipairs(Extra) do pcall(function() M:Destroy() end) end
	pcall(function() Folder:Destroy() end)
	pcall(function()
		if WasHeld then WorldClock.Hold(WasHour) else WorldClock.Release() end
	end)
	pcall(function()
		if Root then Root.Anchored = WasAnchored end
		if C and Home then C:PivotTo(Home) Root.AssemblyLinearVelocity = Vector3.zero end
	end)
	if not Ok then error(Err, 0) end
end

local function Say(Name, Fmt, ...) print(("[Crowd] %s: " .. Fmt):format(Name, ...)) end

-- an R6 body standing in for a player: the same template as the townsfolk, scripts stripped, root anchored. It goes in
-- World.Live, where player characters live.
local function Dummy(Ctx, X, Z)
	local Rig = game.StarterPlayer.StarterCharacter:Clone()
	for _, S in ipairs(Rig:GetDescendants()) do if S:IsA("LuaSourceContainer") then S:Destroy() end end
	Rig.Name = "CrowdTestDummy"
	Rig:PivotTo(CFrame.lookAt(Ctx.At(X, Z) + Vector3.new(0, 3, 0), Ctx.At(X, Z + 1) + Vector3.new(0, 3, 0)))
	Rig.HumanoidRootPart.Anchored = true
	Rig.Parent = workspace.World.Live
	table.insert(Ctx.Extra, Rig)
	return Rig
end

local function Arrivals(R)
	local S = {}
	for _, T in pairs(R.Arrived) do table.insert(S, ("%.1f"):format(T)) end
	table.sort(S, function(A, B) return tonumber(A) < tonumber(B) end)
	return table.concat(S, " ")
end

local function Count(Map) local N = 0 for _ in pairs(Map) do N += 1 end return N end

return {
	-- an 8-wide, 60-long corridor; two walkers swap ends
	CorridorPassing = function(T)
		Fixture(T, "Corridor", function(Ctx)
			Ctx.Wall(0, -5, 64, 2) -- inner faces at z = -4 and +4: 8 studs wide
			Ctx.Wall(0, 5, 64, 2)
			local W = Ctx.Walkers({{From = {-27, 0}, To = {27, 0}}, {From = {27, 0}, To = {-27, 0}}})
			local S0 = Mover.Stats()
			Ctx.Go()
			local R = Ctx.Track(W, 25, 2.5)
			local S1 = Mover.Stats()
			Say("CorridorPassing", "closest %.2f, arrived %s s, yields %d, replans %d", R.Min, Arrivals(R), S1.Yields - S0.Yields, S1.Replans - S0.Replans)
			T.True(R.All and R.Last <= 20, "both arrive within 20 s (" .. Arrivals(R) .. ")")
			T.Eq(S1.Fails - S0.Fails, 0, "no walk failed (a failed walk is placed, not walked)")
			T.True(R.Min >= 2.5, ("roots never closer than 2.5 (closest %.2f)"):format(R.Min))
		end)
	end,

	-- a wall with a 5-wide door; two walkers cross it in opposite directions at the same moment: exactly one yields
	Doorway = function(T)
		Fixture(T, "Doorway", function(Ctx)
			Ctx.Wall(0, -51.25, 2, 97.5) -- the door runs from z = -2.5 to +2.5; the wall reaches the floor's edges
			Ctx.Wall(0, 51.25, 2, 97.5)
			local W = Ctx.Walkers({{From = {-14, 0}, To = {14, 0}}, {From = {14, 0}, To = {-14, 0}}})
			local S0 = Mover.Stats()
			workspace:SetAttribute("RenseiCrowdPhase", "walking")
			Ctx.Go()
			local R = Ctx.Track(W, 30, 2.2)
			workspace:SetAttribute("RenseiCrowdPhase", nil)
			local S1 = Mover.Stats()
			local Yields = S1.Yields - S0.Yields
			Say("Doorway", "closest %.2f, arrived %s s, yields %d, replans %d, sidesteps %d", R.Min, Arrivals(R), Yields,
				S1.Replans - S0.Replans, S1.Sidesteps - S0.Sidesteps)
			T.True(R.All and R.Last <= 25, "both arrive within 25 s (" .. Arrivals(R) .. ")")
			T.Eq(S1.Fails - S0.Fails, 0, "no walk failed")
			T.True(R.Min >= 2.2, ("roots never closer than 2.2 (closest %.2f)"):format(R.Min))
			T.Eq(Yields, 1, "exactly one yields")
		end)
	end,

	-- 8 walkers from a 30-stud ring to 8 posts 3 studs apart near the centre
	Converging = function(T)
		Fixture(T, "Converging", function(Ctx)
			local Posts = {}
			for _, X in ipairs({-4.5, -1.5, 1.5, 4.5}) do
				for _, Z in ipairs({-1.5, 1.5}) do table.insert(Posts, {X, Z}) end
			end
			local function Angle(P) return math.atan2(P[2], P[1]) end
			table.sort(Posts, function(A, B) return Angle(A) < Angle(B) end)
			local List = {}
			for I = 1, 8 do
				local A = -math.pi + (I - 0.5) * math.pi / 4 -- ring spots 45 degrees apart, matched to the posts by angle
				local function R1(V) return math.floor(V * 10 + 0.5) / 10 end
				table.insert(List, {From = {R1(math.cos(A) * 15), R1(math.sin(A) * 15)}, To = Posts[I]})
			end
			local W = Ctx.Walkers(List)
			local S0 = Mover.Stats()
			Ctx.Go()
			local R = Ctx.Track(W, 35, 2.2)
			local S1 = Mover.Stats()
			Say("Converging", "closest %.2f, worst pair under 2.2 for %.2f s, arrived %s s, yields %d, replans %d, post waits %d", R.Min,
				R.MaxBelow, Arrivals(R), S1.Yields - S0.Yields, S1.Replans - S0.Replans, S1.PostWaits - S0.PostWaits)
			T.True(R.All and R.Last <= 30, "all 8 arrive within 30 s (" .. Arrivals(R) .. ")")
			T.Eq(S1.Fails - S0.Fails, 0, "no walk failed")
			T.True(R.MaxBelow <= 0.2, ("no pair under 2.2 studs for more than 0.2 s (worst %.2f s)"):format(R.MaxBelow))
		end)
	end,

	-- a stationary R6 body (standing in for a player) on the straight line between start and post
	PlayerInTheWay = function(T)
		Fixture(T, "Player", function(Ctx)
			local D = Dummy(Ctx, 0, 0)
			local W = Ctx.Walkers({{From = {-20, 0}, To = {20, 0}}})
			local S0 = Mover.Stats()
			Ctx.Go()
			local R = Ctx.Track(W, 20, 2.2, {D})
			T.Eq(Mover.Stats().Fails - S0.Fails, 0, "no walk failed")
			Say("PlayerInTheWay", "closest to the body %.2f, arrived %s s", R.MinTo[D] or -1, Arrivals(R))
			T.True(R.All, "arrives (" .. Arrivals(R) .. ")")
			T.True((R.MinTo[D] or 0) >= 2.5, ("passes the body at 2.5 or more (closest %.2f)"):format(R.MinTo[D] or 0))
		end)
	end,

	-- after the path is computed, a wall drops across it: the walker re-plans and arrives, never failing
	BlockedRepath = function(T)
		Fixture(T, "Blocked", function(Ctx)
			local W = Ctx.Walkers({{From = {-30, 0}, To = {30, 0}}})
			local S0 = Mover.Stats()
			Ctx.Go()
			local Root = W[1].Rig.HumanoidRootPart
			local Start = Root.Position
			local T0 = os.clock()
			while os.clock() - T0 < 5 and (Root.Position - Start).Magnitude < 4 do task.wait(0.1) end
			T.True((Root.Position - Start).Magnitude >= 4, "it set off")
			-- the wall drops from above onto the line, 14 studs ahead of the walker
			local Wall = Ctx.Wall(Root.Position.X - Ctx.O.X + 14, 0, 2, 24)
			local Down = Wall.CFrame
			Wall.CFrame = Down + Vector3.new(0, 30, 0)
			task.wait()
			Wall.CFrame = Down
			local R = Ctx.Track(W, 30, 2.2)
			local S1 = Mover.Stats()
			local States = {}
			for K in pairs(R.States) do table.insert(States, K) end
			table.sort(States)
			Say("BlockedRepath", "arrived %s s, replans %d, fails %d, states seen %s", Arrivals(R), S1.Replans - S0.Replans,
				S1.Fails - S0.Fails, table.concat(States, ","))
			T.True(R.All and R.Last <= 30, "arrives within 30 s (" .. Arrivals(R) .. ")")
			T.Eq(S1.Fails - S0.Fails, 0, "the walk never failed")
			T.True(S1.Replans - S0.Replans >= 1, "it re-planned")
			for _, St in ipairs(States) do T.True(St == "Walking" or St == "AtPost", "state " .. St) end
		end)
	end,

	-- a diagonal walk across an open 60 x 60 plaza keeps at most 3 waypoints after smoothing
	Smoothing = function(T)
		Fixture(T, "Smoothing", function(Ctx)
			local W = Ctx.Walkers({{From = {-25, -25}, To = {25, 25}}})
			local Rig = W[1].Rig
			Rig:SetAttribute("IdleAnim", nil) -- (what TownsfolkService does before a walk)
			local Result
			local Target = CFrame.lookAt(W[1].End, W[1].End + Vector3.new(1, 0, 1))
			local H = Mover.WalkTo(Rig, Target, {Speed = 8, OnDone = function(Res) Result = Res end})
			local T0 = os.clock()
			while os.clock() - T0 < 5 and not H.Waypoints and not Result do task.wait(0.05) end
			T.True(H.Waypoints ~= nil, "a path was planned")
			Say("Smoothing", "raw %d waypoints -> smoothed %d", H.RawWaypoints or -1, #H.Waypoints)
			T.True(#H.Waypoints <= 3, "at most 3 waypoints after smoothing (got " .. #H.Waypoints .. ")")
			T.True((H.RawWaypoints or 0) > 3, "the raw path had more (" .. tostring(H.RawWaypoints) .. ")")
			while os.clock() - T0 < 20 and not Result do task.wait(0.1) end
			T.Eq(Result, "arrived", "it arrives")
			T.True((Rig.HumanoidRootPart.Position - W[1].End).Magnitude < 1, "on the post")
		end)
	end,

	-- 20 walkers crossing a plaza in interleaved, opposite lanes: the steering stays cheap
	Performance = function(T)
		Fixture(T, "Performance", function(Ctx)
			local List = {}
			for I = 0, 9 do
				local Z = -18 + I * 4
				table.insert(List, {From = {-25, Z}, To = {25, Z + 2}})
				table.insert(List, {From = {27, Z - 2}, To = {-27, Z}})
			end
			local W = Ctx.Walkers(List)
			Ctx.Go()
			Mover.ResetStats()
			local R = Ctx.Track(W, 45, 2.2)
			local S = Mover.Stats()
			Say("Performance", "StepMs avg %.3f (max %.3f, per Heartbeat %.4f) over %d ticks, peak walkers %d, closest %.2f, worst pair under 2.2 for %.2f s, arrived %d/20 by %.1f s, yields %d, replans %d",
				S.StepMs, S.MaxStepMs, S.HeartbeatMs, S.Ticks, S.PeakWalkers, R.Min, R.MaxBelow, Count(R.Arrived), R.Last, S.Yields, S.Replans)
			T.True(S.PeakWalkers >= 20, "20 walkers steered at once (" .. S.PeakWalkers .. ")")
			T.Eq(S.Fails, 0, "no walk failed")
			T.True(S.StepMs <= 1.5, ("average steering step %.3f ms <= 1.5"):format(S.StepMs))
			T.True(R.All, "all 20 arrive")
		end)
	end,
}

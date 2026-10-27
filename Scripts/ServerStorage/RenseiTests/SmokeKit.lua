-- SmokeKit (Foundry Yard plan Task 8, Ruling 6 and Ruling 31, 2026-10-25): the helpers more than one Play suite uses,
-- in one module (the global "no duplicated test logic" rule). Run in the game VM (LMRunSuite), never in Edit.
--   * SmokeKit.Copy(V): a deep copy of a table (anything else comes back as it is).
--   * SmokeKit.PutBack(Tbl, Old) (Task 9): puts Old's keys back into Tbl in place (keys Old lacks are removed), so a
--     save table keeps its identity; Old is a copy taken first (SmokeKit.Copy) and is used as it is.
--   * SmokeKit.Stand(Player, Pos): the player's character held still (anchored) 5 studs off and 3 up from Pos, for an
--     inspect or a Talk; returns the root. The caller puts the character back.
--   * SmokeKit.Ask(Player, Character, Kind): asks the server for a traversal (as JumpRemote "TraversalState" does) and
--     waits up to 2 s for its answer for this session: the published Kind ("Climb" / "WallRun" when accepted, "None"
--     when refused) and the reason, as Play_NoGrip reads them.
--   * SmokeKit.WithRoot(Player, Fn): runs Fn(Character, Root), then always clears the traversal and puts the root's
--     CFrame and anchoring back; re-raises Fn's error.
--   * SmokeKit.EnemiesStandInTheWorld(T, Opts): the Lindenmoor final review C1 check (2026-10-24). Every enemy
--     EnemyService has live has its Home (the part it spawned from) in workspace, or outside the DataModel altogether
--     (a runtime mark: RoadService's ambushes, RideEvents' holdups); never in the DataModel outside workspace. No
--     tagged spawn outside workspace has an enemy; every live enemy model is one of EnemyService's; a downward ray from
--     each RenseiEnemySpawn in use meets ground within SPAWN_GROUND studs. Opts (both optional; the Foundry suite
--     uses them, Task 9):
--       ExpectSpawns = {[EnemyType] = count}: the RenseiEnemySpawns in workspace, counted by EnemyType, are exactly
--                      these (no other type, no other count);
--       AreaOf = function(Part) -> AreaName or nil: WorldService.AreaAt at each workspace spawn is that name.
-- (Moved here from Play_LindenmoorSmoke and Play_FoundryLedger with the same behaviour; Task 9, Ruling 37: the Copy
-- helpers of Play_Exams, Play_FoundryForge, Play_QuestEngine and Test_QuestRevision too.)
--   * SmokeKit.TempPart(Props) (gun rework Task 4, 2026-10-25; moved from Play_Stealth's Part): an anchored Part with
--     Props, in workspace, remembered until SmokeKit.ClearTemp() destroys every remembered part.
--   * SmokeKit.Guarded(Player, Body, Before, After) (gun rework Task 4; the clean-up half of Play_Stealth's Guard):
--     remembers the player's character pivot and root anchoring, then (gun rework final fix A8, in this order):
--     pcall(Before) (optional; when it fails Body is skipped), pcall(Body), pcall(After) (optional, while the temp parts
--     still stand), ClearTemp, and the character put back -- anchored, pivoted home, velocity zeroed, then its anchoring
--     from before the case restored (pcall too). Re-raises the first error: Before's or Body's, then After's, then the
--     put-back's.
-- (Assassinations Task 4, 2026-10-27, pre-flight Ruling R5: moved from Play_Stealth with the same behaviour, so
-- TakedownKit builds on them instead of copying them; game VM only.)
--   * SmokeKit.Run(Seconds): PerceptionService stepped by hand, 0.2 s at a time (the caller holds PS.SetAuto(false)).
--   * SmokeKit.Put(Player, Rig, Local): the player's character at Local (in the rig's root space; -Z is in front of
--     it), facing the rig level, velocity zeroed, then 0.15 s to settle.
--   * SmokeKit.SpawnEnemy(Type, At): EnemyService.Spawn from a runtime mark at At (a Vector3) that is never parented, so
--     the enemy never respawns (RoadService's ambushes spawn the same way); asserts a rig came back and returns it.
--   * SmokeKit.RemoveEnemy(Rig): the enemy taken out of EnemyService.Active (not a kill: no Died, so no reward and no
--     respawn), then its WCS character, then the rig (CombatDirector and PerceptionService drop it on removal).
--   * SmokeKit.SweepEnemies(At, Radius) (Ruling 36): RemoveEnemy for every live enemy whose root is within Radius of
--     At, for a Spawn that threw after parenting its rig.
--   * SmokeKit.OwnGrunt(Player, Body) (gun rework Rulings 6 and 38): Body(Rig, S) with a Grunt of its own on a Play-only
--     floor (a TempPart) at GRUNT_AT high above the map, its root anchored there facing -Z, AIPassive and PS.Reset, inside
--     Guarded with perception and light stepped by hand; afterwards the Grunt and anything else on the floor are removed,
--     Crouching is cleared and both loops run again.
local CollectionService = game:GetService("CollectionService")
local SSS = game:GetService("ServerScriptService")
local MovementState = require(game:GetService("ReplicatedStorage").Modules.Managers.MovementState)

local SmokeKit = {}

SmokeKit.SPAWN_GROUND = 6 -- PROPOSAL: studs from a spawn's centre down to the ground under it (Ye's spawns: 0.5..1.5)

local Temp = {} -- the parts TempPart made, until ClearTemp

function SmokeKit.TempPart(Props)
	local X = Instance.new("Part")
	X.Anchored = true
	for K, V in pairs(Props) do X[K] = V end
	X.Parent = workspace
	table.insert(Temp, X)
	return X
end

function SmokeKit.ClearTemp()
	for _, X in ipairs(Temp) do X:Destroy() end
	table.clear(Temp)
end

function SmokeKit.Guarded(Player, Body, Before, After)
	local C = Player.Character
	local Home = C:GetPivot()
	local Root = C:FindFirstChild("HumanoidRootPart")
	local WasAnchored = Root and Root.Anchored
	-- (gun rework final fix A8) Before runs under pcall too: when it fails, Body is skipped and the clean-up still runs
	local Ok, Err = true, nil
	if Before then Ok, Err = pcall(Before) end
	if Ok then Ok, Err = pcall(Body) end
	-- After runs while the temp parts (a test floor) are still there, so whatever it un-anchors stands on them
	local AfterOk, AfterErr = true, nil
	if After then AfterOk, AfterErr = pcall(After) end
	SmokeKit.ClearTemp()
	-- home, held anchored for the move and the velocity reset; the root's anchoring from before the case comes back last
	local HomeOk, HomeErr = pcall(function()
		if Root and Root.Parent then Root.Anchored = true end
		C:PivotTo(Home)
		if Root and Root.Parent then
			Root.AssemblyLinearVelocity = Vector3.zero
			Root.Anchored = WasAnchored
		end
	end)
	if not Ok then error(Err, 0) end
	if not AfterOk then error(AfterErr, 0) end
	if not HomeOk then error(HomeErr, 0) end
end

-- ===== perception fixtures (assassinations Task 4, R5; moved from Play_Stealth) =====
-- required when called, so the suites that never use them don't load the services
local function PS() return require(SSS.PerceptionService) end
local function ES() return require(SSS.EnemyService) end
local function LS() return require(SSS.LightService) end

function SmokeKit.Run(Seconds)
	local Perception = PS()
	for _ = 1, math.floor(Seconds / 0.2 + 0.5) do Perception.Step(0.2) end
end

function SmokeKit.Put(Player, Rig, Local)
	local C = Player.Character
	local Root = Rig.HumanoidRootPart
	local Pos = Root.Position + Root.CFrame:VectorToWorldSpace(Local)
	C:PivotTo(CFrame.lookAt(Pos, Vector3.new(Root.Position.X, Pos.Y, Root.Position.Z)))
	C.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
	task.wait(0.15)
end

function SmokeKit.SpawnEnemy(Type, At)
	local Mark = Instance.new("Part") -- a runtime mark, never parented
	Mark.Anchored, Mark.CanCollide, Mark.Transparency = true, false, 1
	Mark.CFrame = CFrame.new(At)
	Mark:SetAttribute("EnemyType", Type)
	local Rig = ES().Spawn(Mark)
	assert(typeof(Rig) == "Instance", "the case's own " .. tostring(Type) .. " spawned")
	return Rig
end

function SmokeKit.RemoveEnemy(Rig)
	local Enemies = ES()
	local E = Enemies.Active[Rig]
	Enemies.Active[Rig] = nil -- not a kill: no Died, so no reward and no respawn
	if E and E.WCS then pcall(function() E.WCS:Destroy() end) end
	if Rig.Parent then Rig:Destroy() end -- CombatDirector and PerceptionService drop it on removal
end

function SmokeKit.SweepEnemies(At, Radius)
	local Near = {}
	for Other in pairs(ES().Active) do
		local Root = Other:FindFirstChild("HumanoidRootPart")
		if Root and (Root.Position - At).Magnitude <= Radius then table.insert(Near, Other) end
	end
	for _, Other in ipairs(Near) do SmokeKit.RemoveEnemy(Other) end
end

SmokeKit.GRUNT_AT = Vector3.new(0, 2500, 0) -- PROPOSAL: the floor's top centre (both maps' tops are under y 430; GunKit's floor is at 2000)
SmokeKit.GRUNT_FLOOR = Vector3.new(80, 1, 80) -- PROPOSAL
SmokeKit.GRUNT_SWEEP = 60 -- PROPOSAL: studs from GRUNT_AT; the clean-up removes any enemy this near (a Spawn that threw half-way)

function SmokeKit.OwnGrunt(Player, Body)
	local At = SmokeKit.GRUNT_AT
	local Rig
	SmokeKit.Guarded(Player, function()
		SmokeKit.TempPart({Name = "Stealth_Floor", Size = SmokeKit.GRUNT_FLOOR,
			CFrame = CFrame.new(At - Vector3.new(0, SmokeKit.GRUNT_FLOOR.Y / 2, 0))})
		Rig = SmokeKit.SpawnEnemy("Grunt", At)
		Rig.HumanoidRootPart.Anchored = true
		Rig:PivotTo(CFrame.new(At + Vector3.new(0, 3, 0)))
		Rig:SetAttribute("AIPassive", true)
		local S = PS().Npcs[Rig]
		assert(S ~= nil and S.Type == "Grunt", "the Grunt is a perceiving Grunt")
		PS().Reset(Rig)
		Body(Rig, S)
	end, function()
		PS().SetAuto(false); LS().SetAuto(false)
	end, function()
		if Rig then SmokeKit.RemoveEnemy(Rig) end
		SmokeKit.SweepEnemies(At, SmokeKit.GRUNT_SWEEP)
		Player.Character:SetAttribute("Crouching", nil)
		PS().SetAuto(true); LS().SetAuto(true)
	end)
end

function SmokeKit.Copy(V)
	if type(V) ~= "table" then return V end
	local R = {}
	for K, X in pairs(V) do R[K] = SmokeKit.Copy(X) end
	return R
end

function SmokeKit.PutBack(Tbl, Old)
	for K in pairs(Tbl) do if Old[K] == nil then Tbl[K] = nil end end
	for K, V in pairs(Old) do Tbl[K] = V end
end

function SmokeKit.Stand(Player, Pos)
	local C = Player.Character
	local Root = C and C:FindFirstChild("HumanoidRootPart")
	assert(Root, "the player has a character")
	Root.Anchored = true
	C:PivotTo(CFrame.new(Pos + Vector3.new(0, 3, 5)))
	Root.AssemblyLinearVelocity = Vector3.zero
	task.wait(0.1)
	return Root
end

local NextSeq = 900000
function SmokeKit.Ask(Player, Character, Kind)
	NextSeq += 1
	local Seq = NextSeq
	MovementState.Request(Player, true, Kind, Seq)
	local T0 = os.clock()
	while os.clock() - T0 < 2 do
		local S, K, Why = MovementState.ParseSession(Character:GetAttribute("TraversalSession"))
		if S == Seq then
			MovementState.Clear(Character, "Test")
			return K, Why
		end
		task.wait(0.05)
	end
	return "Timeout", ""
end

function SmokeKit.WithRoot(Player, Fn)
	local Character = Player and Player.Character
	local Root = Character and Character:FindFirstChild("HumanoidRootPart")
	assert(Root, "no test player character")
	local Saved = {CFrame = Root.CFrame, Anchored = Root.Anchored}
	local Ok, Err = pcall(Fn, Character, Root)
	pcall(MovementState.Clear, Character, "Test")
	Root.Anchored = Saved.Anchored
	Root.CFrame = Saved.CFrame
	if not Ok then error(Err, 0) end
end

function SmokeKit.EnemiesStandInTheWorld(T, Opts)
	Opts = Opts or {}
	local ES = require(SSS.EnemyService)
	local Live = workspace.World:FindFirstChild("Live")
	-- the spawns in use: the Home of every live enemy
	local Used, Homes, N, Marks = {}, {}, 0, 0
	for Rig, E in pairs(ES.Active) do
		N += 1
		local Home = E.Home
		T.True(Home ~= nil, Rig.Name .. " has a Home")
		if Home:IsDescendantOf(game) then
			T.True(Home:IsDescendantOf(workspace), ("%s's Home %s is in workspace"):format(Rig.Name, Home:GetFullName()))
			if not Used[Home] then Used[Home] = true table.insert(Homes, Home) end
		else
			Marks += 1 -- (a runtime mark outside the DataModel: an ambush or holdup; it never respawns)
		end
	end
	T.True(N > 0, "EnemyService has live enemies")
	-- a tagged spawn outside workspace (a backup) has no enemy
	local Out = 0
	for _, P in ipairs(CollectionService:GetTagged("RenseiEnemySpawn")) do
		if not P:IsDescendantOf(workspace) then
			Out += 1
			T.True(not Used[P], P:GetFullName() .. " (not in workspace) has no enemy")
		end
	end
	-- no live enemy model stands on a spawn EnemyService doesn't know (a Grunt from a backup, before its Home check)
	if Live then
		for _, M in ipairs(Live:GetDescendants()) do
			if M:IsA("Model") and M:GetAttribute("EnemyType") and M:FindFirstChildOfClass("Humanoid")
				and M:FindFirstChildOfClass("Humanoid").Health > 0 and not M:GetAttribute("TownsfolkId") then
				T.True(ES.Active[M] ~= nil, M:GetFullName() .. " is one of EnemyService's live enemies")
			end
		end
	end
	-- each spawn in use stands on ground (not on a live rig or a player)
	local Skip = {Live}
	for _, Pl in ipairs(game.Players:GetPlayers()) do if Pl.Character then table.insert(Skip, Pl.Character) end end
	local RP = RaycastParams.new()
	RP.FilterType = Enum.RaycastFilterType.Exclude
	for _, Home in ipairs(Homes) do
		if not CollectionService:HasTag(Home, "RenseiEnemySpawn") then continue end -- (a trial / admin / test mark)
		local Where = Home:IsA("BasePart") and Home.Position or Home:GetPivot().Position
		local Ex = table.clone(Skip)
		table.insert(Ex, Home)
		RP.FilterDescendantsInstances = Ex
		local Hit = workspace:Raycast(Where, Vector3.new(0, -SmokeKit.SPAWN_GROUND, 0), RP)
		T.True(Hit ~= nil, ("%s at (%.0f, %.1f, %.0f): ground within %d studs below"):format(Home:GetFullName(),
			Where.X, Where.Y, Where.Z, SmokeKit.SPAWN_GROUND))
	end
	-- (Opts) the spawns in workspace by type, and the area each stands in
	if Opts.ExpectSpawns or Opts.AreaOf then
		local Count = {}
		for _, P in ipairs(CollectionService:GetTagged("RenseiEnemySpawn")) do
			if P:IsDescendantOf(workspace) then
				local Kind = tostring(P:GetAttribute("EnemyType"))
				Count[Kind] = (Count[Kind] or 0) + 1
				if Opts.AreaOf then
					local Want = Opts.AreaOf(P)
					if Want ~= nil then
						local Where = P:IsA("BasePart") and P.Position or P:GetPivot().Position
						-- (Task 9: AreaAt returns the area's part; its name is compared, as WorldService names areas)
						local A = require(SSS.WorldService).AreaAt(Where)
						T.Eq(A and (A:GetAttribute("AreaName") or A.Name), Want, P:GetFullName() .. "'s area")
					end
				end
			end
		end
		if Opts.ExpectSpawns then
			for Kind, Want in pairs(Opts.ExpectSpawns) do T.Eq(Count[Kind] or 0, Want, Kind .. " spawns in workspace") end
			for Kind, Have in pairs(Count) do
				T.True(Opts.ExpectSpawns[Kind] ~= nil, ("%d %s spawns in workspace (not expected)"):format(Have, Kind))
			end
		end
	end
	print(("[SmokeKit] EnemiesStandInTheWorld: %d live enemies on %d spawns (+%d runtime marks); %d tagged spawns outside workspace")
		:format(N, #Homes, Marks, Out))
end

return SmokeKit

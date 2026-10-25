-- SmokeKit (Foundry Yard plan Task 8, Ruling 6 and Ruling 31, 2026-10-25): the helpers more than one Play suite uses,
-- in one module (the global "no duplicated test logic" rule). Run in the game VM (LMRunSuite), never in Edit.
--   * SmokeKit.Copy(V): a deep copy of a table (anything else comes back as it is).
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
-- (Moved here from Play_LindenmoorSmoke and Play_FoundryLedger with the same behaviour.)
local CollectionService = game:GetService("CollectionService")
local SSS = game:GetService("ServerScriptService")
local MovementState = require(game:GetService("ReplicatedStorage").Modules.Managers.MovementState)

local SmokeKit = {}

SmokeKit.SPAWN_GROUND = 6 -- PROPOSAL: studs from a spawn's centre down to the ground under it (Ye's spawns: 0.5..1.5)

function SmokeKit.Copy(V)
	if type(V) ~= "table" then return V end
	local R = {}
	for K, X in pairs(V) do R[K] = SmokeKit.Copy(X) end
	return R
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
						T.Eq(require(SSS.WorldService).AreaAt(Where), Want, P:GetFullName() .. "'s area")
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

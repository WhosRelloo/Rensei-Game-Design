-- Play_RegionSmoke (Region Foundation final fix pass, 2026-10-24): a real region import, played. Run by
-- Art/Studio/Regions/smoke.py in Foundry Yard (109591196441030), never in Ye: the Testbed is imported with kit.py
-- --place 109591196441030 --map-child TestbedSmoke --keep Foundry --offset 4000,0,4000 (clear of Foundry's own map),
-- finish.lua's real run, then this suite in the game VM (LMRunSuite, inside the save snapshot / restore hook), then
-- Stop, setup.lua and the contract test, and restore.lua. The suite is installed in ServerStorage.RenseiTests only for
-- the Play session and removed afterwards.
-- It checks, on the imported map (workspace.World.Map.TestbedSmoke):
--   * every marker part has CanCollide, CanQuery and CanTouch off (final review I3), and WorldService.AreaAt finds the
--     Testbed area inside its box;
--   * rays across the area box's faces are not blocked: an Include ray aimed only at the box, a sight ray down through
--     its top (PerceptionService's kind: Exclude the character), and one through its side in the east road mouth;
--   * the server's climb check (MovementState.Request): accepted on a plain fixture wall (the control), refused on a
--     RenseiNoGrip edge wall, and refused against the area box's face where no wall stands (the old CanQuery bug);
--   * the test_work post (Yaw 90) faces -X;
--   * a NightOnly lamp follows WorldClock.Hold (off and not Neon by day, on and Neon at night);
--   * the clue marker becomes an inspect point with its InspectPrompt (a test inspect def is injected for the run:
--     the Testbed's test_clue has no content), although the part can't be queried.
-- Play-mode changes are thrown away on Stop; the player's root is put back after each move and the clock released.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local MovementState = require(ReplicatedStorage.Modules.Managers.MovementState)
local Player = game.Players:GetPlayers()[1]

local function Root() return workspace.World.Map:FindFirstChild("TestbedSmoke") end
local function Area()
	for _, P in ipairs(CollectionService:GetTagged("RenseiArea")) do
		if P:IsDescendantOf(Root()) and P:GetAttribute("AreaName") == "Testbed" then return P end
	end
end
-- the import's origin: the area box is [[-128, -10, -128], [128, 80, 128]] in region coordinates
local function Origin() return Area().Position - Vector3.new(0, 35, 0) end

-- the player's root, moved for Fn(Character, Root) and always put back
local function WithRoot(Fn)
	local Character = Player and Player.Character
	local R = Character and Character:FindFirstChild("HumanoidRootPart")
	assert(R, "no test player character")
	local Saved = {CFrame = R.CFrame, Anchored = R.Anchored}
	local Ok, Err = pcall(Fn, Character, R)
	pcall(MovementState.Clear, Character, "Test")
	R.Anchored = Saved.Anchored
	R.CFrame = Saved.CFrame
	if not Ok then error(Err, 0) end
end

-- as Play_NoGrip: ask the server for a climb and wait for its published answer ("Climb" or "None") and the reason
local NextSeq = 710000
local function Ask(Character)
	NextSeq += 1
	local Seq = NextSeq
	MovementState.Request(Player, true, "Climb", Seq)
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
local function Stand(R, Pos, Look)
	R.Anchored = true
	R.CFrame = CFrame.lookAt(Pos, Pos + Look)
	task.wait(0.15)
end

local Suite = {}

function Suite.A_MarkersAndAreaLookup(T)
	T.True(Root() ~= nil, "workspace.World.Map.TestbedSmoke (the import) exists")
	local A = Area()
	T.True(A ~= nil, "the Testbed RenseiArea is in the import")
	local N = 0
	for _, D in ipairs(Root():GetDescendants()) do
		if D:IsA("BasePart") and D.Transparency >= 1 then
			N += 1
			T.True(not D.CanCollide and not D.CanQuery and not D.CanTouch,
				D:GetFullName() .. ": a marker must not collide, query or touch")
		end
	end
	T.Eq(N, 4, "marker parts (the area, the clue, two posts)")
	local WorldService = require(SSS.WorldService)
	T.Eq(WorldService.AreaAt(Origin() + Vector3.new(0, 20, 0)), A, "AreaAt inside the box")
	T.Eq(WorldService.AreaAt(Origin() + Vector3.new(60, 70, -60)), A, "AreaAt near the box's top")
	T.True(WorldService.AreaAt(Origin() + Vector3.new(0, 200, 0)) ~= A, "AreaAt above the box is not the Testbed")
end

function Suite.B_RaysCrossTheAreaBox(T)
	local A, O = Area(), Origin()
	local Only = RaycastParams.new()
	Only.FilterType = Enum.RaycastFilterType.Include
	Only.FilterDescendantsInstances = {A}
	T.Eq(workspace:Raycast(O + Vector3.new(0, 140, 0), Vector3.new(0, -100, 0), Only), nil,
		"a ray aimed only at the area box passes through its top face")
	T.Eq(workspace:Raycast(O + Vector3.new(200, 40, 0), Vector3.new(-100, 0, 0), Only), nil,
		"and through its side face")
	local Sight = RaycastParams.new() -- PerceptionService's sight rays: Exclude the rigs only
	Sight.FilterType = Enum.RaycastFilterType.Exclude
	Sight.FilterDescendantsInstances = {Player.Character}
	local Down = workspace:Raycast(O + Vector3.new(100, 120, -100), Vector3.new(0, -60, 0), Sight)
	T.True(Down == nil or Down.Instance ~= A, "a sight ray down through the top face is not stopped by the area box")
	local Side = workspace:Raycast(O + Vector3.new(160, 40, 0), Vector3.new(-60, 0, 0), Sight)
	T.True(Side == nil or Side.Instance ~= A, "a sight ray in through the east road mouth is not stopped by the area box")
end

function Suite.C_ClimbChecks(T)
	local O = Origin()
	-- the control: a plain wall far above the import is climbable
	local F = Instance.new("Folder")
	F.Name = "RegionSmokeFixture"
	local W = Instance.new("Part")
	W.Name, W.Size, W.Anchored = "PlainWall", Vector3.new(40, 60, 4), true
	W.CFrame = CFrame.new(O + Vector3.new(0, 630, 0))
	W.Parent = F
	F.Parent = workspace.World.Map
	local Ok, Err = pcall(WithRoot, function(Character, R)
		Stand(R, O + Vector3.new(0, 603, -4), Vector3.new(0, 0, 1))
		local K = Ask(Character)
		T.Eq(K, "Climb", "a climb on a plain wall (the control)")
		-- a RenseiNoGrip edge wall: find the east wall's outer face at z 60 and stand 2 studs off it
		local EdgeOnly = RaycastParams.new()
		EdgeOnly.FilterType = Enum.RaycastFilterType.Include
		EdgeOnly.FilterDescendantsInstances = {Root():FindFirstChild("Edges")}
		local Hit = workspace:Raycast(O + Vector3.new(220, 30, 60), Vector3.new(-120, 0, 0), EdgeOnly)
		T.True(Hit ~= nil, "the east edge wall is there")
		T.Eq(MovementState.Grippable(Hit.Instance), false, "the edge wall is RenseiNoGrip")
		Stand(R, Hit.Position + Hit.Normal * 2, -Hit.Normal)
		local K2, Why2 = Ask(Character)
		T.Eq(K2, "None", "a climb on the RenseiNoGrip edge is refused (" .. tostring(Why2) .. ")")
		-- the area box's side face, in the east road mouth (an EdgeGap: no wall there): nothing to climb
		Stand(R, O + Vector3.new(130, 40, 0), Vector3.new(-1, 0, 0))
		local K3, Why3 = Ask(Character)
		T.Eq(K3, "None", "a climb on the invisible area face is refused (" .. tostring(Why3) .. ")")
	end)
	F:Destroy()
	if not Ok then error(Err, 0) end
end

function Suite.D_PostFacesItsYaw(T)
	local Post
	for _, P in ipairs(CollectionService:GetTagged("RenseiPost")) do
		if P:IsDescendantOf(Root()) and P:GetAttribute("PostId") == "test_work" then Post = P end
	end
	T.True(Post ~= nil, "the test_work post")
	local L = Post.CFrame.LookVector
	T.True(L:FuzzyEq(Vector3.new(-1, 0, 0), 1e-3), "Yaw 90 faces -X, got " .. tostring(L))
end

function Suite.E_LampFollowsTheClock(T)
	local C = require(SSS.WorldClock)
	local Lamp, Light
	for _, D in ipairs(Root():GetDescendants()) do
		if D:IsA("BasePart") and D:GetAttribute("NightOnly") == true then
			local L = D:FindFirstChildWhichIsA("Light")
			if L then Lamp, Light = D, L break end
		end
	end
	T.True(Lamp ~= nil, "a NightOnly lamp with a light in the import")
	local Ok, Err = pcall(function()
		C.Hold(13) task.wait(1.5)
		T.Eq(Light.Enabled, false, "off by day")
		T.True(Lamp.Material ~= Enum.Material.Neon, "no Neon glow by day")
		C.Hold(23) task.wait(1.5)
		T.Eq(Light.Enabled, true, "on at night")
		T.Eq(Lamp.Material, Enum.Material.Neon, "its own Neon at night")
	end)
	C.Release()
	if not Ok then error(Err, 0) end
end

function Suite.F_CluePrompt(T)
	local Content = require(ReplicatedStorage.Modules.Data.Rensei.Investigation)
	local Clue
	for _, P in ipairs(CollectionService:GetTagged("RenseiClue")) do
		if P:IsDescendantOf(Root()) then Clue = P end
	end
	T.True(Clue ~= nil, "the clue marker in the import")
	T.Eq(Clue:GetAttribute("ClueId"), "test_clue", "its ClueId")
	local Injected = Content.Inspects.test_clue == nil
	if Injected then Content.Inspects.test_clue = {Title = "Smoke Clue", Text = "Region smoke test."} end
	local Ok, Err = pcall(function()
		require(SSS.InvestigationService).Scan() -- what Start() runs first, now with a def for test_clue
		local T0 = os.clock()
		repeat task.wait(0.1) until Clue:FindFirstChild("InspectPrompt") or os.clock() - T0 > 3
		local Prompt = Clue:FindFirstChild("InspectPrompt")
		T.True(Prompt ~= nil and Prompt:IsA("ProximityPrompt"), "the clue has its InspectPrompt")
		T.True(Prompt.Enabled and Prompt.RequiresLineOfSight == false, "enabled, no line of sight needed")
		T.Eq(Clue:GetAttribute("InspectId"), "test_clue", "mapped to an inspect point")
		T.True(not Clue.CanQuery, "on a part that can't be queried")
	end)
	if Injected then Content.Inspects.test_clue = nil end
	if not Ok then error(Err, 0) end
end

return Suite

-- Play_NoGrip (Region Foundation Task 10b, 2026-10-24): ungrippable edges, in the game VM (LMRunSuite, inside the
-- save snapshot / restore harness). Owner: "Ungrippable edges": a part tagged TuningConfig.Parkour.NoGripTag
-- (RenseiNoGrip), or inside a Model with it, keeps its look and collision but no climb or wall run can grab it. The
-- client's grab paths share one helper, JumpManager.Grippable (= MovementState.Grippable); the server's wall-in-reach
-- check (MovementState.Request, for a climb or a wall run) ignores tagged parts, as if no wall were there.
-- Fixture: a tagged wall (the tag on its Model) and an untagged wall 100 studs apart, on one floor, built in
-- workspace.World.Map 600 studs over the test player and always removed; the player's root is anchored 2 studs in
-- front of a wall, facing it, for each request, and put back afterwards.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)
local MovementState = require(ReplicatedStorage.Modules.Managers.MovementState)
local JumpManager = require(ReplicatedStorage.Modules.Managers.JumpManager)
local Player = game.Players:GetPlayers()[1]

local TAG = "RenseiNoGrip"

local function Block(Name, Size, Pos, Parent)
	local P = Instance.new("Part")
	P.Name, P.Size, P.Anchored = Name, Size, true
	P.CFrame = CFrame.new(Pos)
	P.Parent = Parent
	return P
end

-- builds the fixture, runs Fn(F, Character, Root), and always clears the traversal, puts the root back and removes
-- the fixture (errors are re-raised after the cleanup)
local function Fixture(Fn)
	local Character = Player and Player.Character
	local Root = Character and Character:FindFirstChild("HumanoidRootPart")
	assert(Root, "no test player character")
	local Folder = Instance.new("Folder")
	Folder.Name = "NoGripTest"
	local Base = Root.Position + Vector3.new(0, 600, 0)
	local F = {Folder = Folder, Base = Base}
	local Model = Instance.new("Model")
	Model.Name = "TaggedWall"
	Model.Parent = Folder
	CollectionService:AddTag(Model, TAG)
	-- walls 40 x 60 x 4, faces toward -Z 2 studs in front of Base, 100 studs apart (each far beyond the other's ValidateReach)
	F.Tagged = Block("Wall", Vector3.new(40, 60, 4), Base + Vector3.new(-50, 30, 0), Model)
	F.Plain = Block("PlainWall", Vector3.new(40, 60, 4), Base + Vector3.new(50, 30, 0), Folder)
	Block("Floor", Vector3.new(160, 2, 40), Base + Vector3.new(0, -1, -20), Folder)
	Folder.Parent = workspace.World.Map
	local Saved = {CFrame = Root.CFrame, Anchored = Root.Anchored}
	local Ok, Err = pcall(Fn, F, Character, Root)
	pcall(MovementState.Clear, Character, "Test")
	Root.Anchored = Saved.Anchored
	Root.CFrame = Saved.CFrame
	Folder:Destroy()
	if not Ok then error(Err, 0) end
end

-- anchor the root 2 studs in front of Wall's face, facing it, standing on the floor
local function Face(Root, Wall, F)
	local Pos = Vector3.new(Wall.Position.X, F.Base.Y + 3, F.Base.Z - 4)
	Root.Anchored = true
	Root.CFrame = CFrame.lookAt(Pos, Pos + Vector3.new(0, 0, 1))
	task.wait(0.1)
end

-- asks the server for a traversal (as JumpRemote "TraversalState" does) and waits for its answer for this session:
-- returns the published Kind ("Climb" / "WallRun" when accepted, "None" when refused) and the reason
local NextSeq = 700000
local function Ask(Character, Kind)
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

local Suite = {}

function Suite.Grippable_OneSharedHelper(T)
	T.Eq(Tuning.Parkour.NoGripTag, TAG, "TuningConfig.Parkour.NoGripTag")
	T.Eq(type(JumpManager.Grippable), "function", "JumpManager.Grippable")
	T.True(JumpManager.Grippable == MovementState.Grippable, "the client and the server share one Grippable")
end

function Suite.Grippable_TaggedPartsAndDescendants(T)
	local Folder = Instance.new("Folder")
	local ok, err = pcall(function()
		local Tagged = Block("Tagged", Vector3.one, Vector3.zero, Folder)
		CollectionService:AddTag(Tagged, TAG)
		local Model = Instance.new("Model")
		Model.Parent = Folder
		CollectionService:AddTag(Model, TAG)
		local Child = Block("Child", Vector3.one, Vector3.zero, Model)
		local Sub = Instance.new("Folder")
		Sub.Parent = Model
		local Deep = Block("Deep", Vector3.one, Vector3.zero, Sub)
		local Plain = Block("Plain", Vector3.one, Vector3.zero, Folder)
		local PlainModel = Instance.new("Model")
		PlainModel.Parent = Folder
		local PlainChild = Block("PlainChild", Vector3.one, Vector3.zero, PlainModel)
		Folder.Parent = workspace.World.Map
		T.Eq(JumpManager.Grippable(Tagged), false, "a tagged part")
		T.Eq(JumpManager.Grippable(Model), false, "a tagged Model")
		T.Eq(JumpManager.Grippable(Child), false, "a part in a tagged Model")
		T.Eq(JumpManager.Grippable(Deep), false, "a part deeper inside a tagged Model")
		T.Eq(JumpManager.Grippable(Plain), true, "an untagged part")
		T.Eq(JumpManager.Grippable(PlainChild), true, "a part in an untagged Model")
		T.Eq(JumpManager.Grippable(nil), false, "nothing")
	end)
	Folder:Destroy()
	if not ok then error(err, 0) end
end

function Suite.Server_ClimbOnPlainWallAccepted(T)
	Fixture(function(F, Character, Root)
		Face(Root, F.Plain, F)
		local Kind, Why = Ask(Character, "Climb")
		T.Eq(Kind, "Climb", "climb facing the untagged wall (" .. tostring(Why) .. ")")
	end)
end

function Suite.Server_ClimbOnTaggedWallRefused(T)
	Fixture(function(F, Character, Root)
		Face(Root, F.Tagged, F)
		local Kind, Why = Ask(Character, "Climb")
		T.Eq(Kind, "None", "climb facing the tagged wall")
		T.Eq(Why, "Refused:NoWall", "refused as if no wall were there")
	end)
end

function Suite.Server_WallRunOnPlainWallAccepted(T)
	Fixture(function(F, Character, Root)
		Face(Root, F.Plain, F)
		local Kind, Why = Ask(Character, "WallRun")
		T.Eq(Kind, "WallRun", "wall run beside the untagged wall (" .. tostring(Why) .. ")")
	end)
end

function Suite.Server_WallRunOnTaggedWallRefused(T)
	Fixture(function(F, Character, Root)
		Face(Root, F.Tagged, F)
		local Kind, Why = Ask(Character, "WallRun")
		T.Eq(Kind, "None", "wall run beside the tagged wall")
		T.Eq(Why, "Refused:NoWall", "refused as if no wall were there")
	end)
end

return Suite

-- TownsfolkService (Region Foundation Task 5, 2026-10-23; region builds spec §5): the people of a town. Each one is
-- spawned at a post, follows a day schedule (TownsfolkLogic.PostAt on WorldClock.Now()), walks between posts with
-- pathfinding while a player is near, and is held still (Asleep) when nobody is.
--   * Posts: BaseParts tagged RenseiPost with PostId (string) and Kind (Work / Seat / Counter / Home / Shelter). The
--     post's LookVector is the way the townsperson faces there.
--   * Rosters: Townsfolk.Regions[RegionId]; Start loads this place's (TravelService.Here()), after checking it with
--     TownsfolkLogic.Validate against the posts that exist.
--   * Rigs: the same R6 template EnemyService uses (StarterPlayer.StarterCharacter, scripts stripped), dressed with
--     Customization.RandomLook(Def.Look.Nation, Random.new(Def.Look.Seed)): always the townsperson's OWN nation's
--     pool, read at spawn, so outfit variants added to Customization.NationLooks later are worn without changes here
--     (owner 2026-10-23). An unknown nation is refused, never replaced by a random one.
--   * Watchers: tagged RenseiWatcher (WatcherType "Witness", Faction, Carrier = false), so PerceptionService registers
--     them as non-combat witnesses. Townsfolk are not hittable or killable here (an open owner decision).
--   * Idles: the IdleAnim attribute (NpcIdles.server.lua plays it and keeps only the root anchored). At a post the
--     root is anchored; to walk, IdleAnim is cleared and the root unanchored (NpcIdles only re-anchors while an idle
--     is playing); on arrival the root is anchored again and the post's idle set.
--   * Walking: ONLY through the child module Mover (Mover.WalkTo / Mover.Place), so the pathfinding follow-up (Task 5b)
--     can replace it without touching spawning or schedules. A walk's handle is cancellable; a newer WalkTo or Place
--     on the same rig cancels it, so a newer schedule change (or a flee) wins.
--   * Collision: the rigs are in the "Townsfolk" collision group (created if missing), which collides with Default
--     and with itself: townsfolk don't pass through each other or through players.
--   * States: AtPost, Walking, Asleep; Fleeing and Sheltering are reserved for later tasks (Step leaves them alone).
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local Rensei = ReplicatedStorage.Modules.Data.Rensei
local TownsfolkLogic = require(Rensei.TownsfolkLogic)
local Townsfolk = require(Rensei.Townsfolk)
local Customization = require(Rensei.Customization)
local AppearanceService = require(ServerScriptService.AppearanceService)
local WorldClock = require(ServerScriptService.WorldClock)
local Mover = require(script.Mover)

local TownsfolkService = {}
TownsfolkService.SleepRadius = 300 -- PROPOSAL: no player this close -> held still, placed at posts instead of walking
TownsfolkService.WalkSpeed = 8 -- PROPOSAL: an unhurried stroll (players walk 16)
TownsfolkService.GenderTries = 64 -- seeds tried to find a look of Def.Look.Gender

local POST_TAG = "RenseiPost"
local FOLK_TAG = "RenseiTownsfolk"
local WATCHER_TAG = "RenseiWatcher"
local LIFT = CFrame.new(0, 3, 0) -- R6 root height above the post

local Posts = {} -- [PostId] = BasePart
local Folk = {} -- [Id] = {Id, Def, Region, Rig, Root, Humanoid, Post, Target, State, Walk (Mover handle)}
local Warned = {} -- [key] = true: warn once
TownsfolkService.Posts = Posts

local function WarnOnce(Key, ...)
	if Warned[Key] then return end
	Warned[Key] = true
	warn("TownsfolkService:", ...)
end

-- ===== posts =====
local function AddPost(P)
	local Id = P:GetAttribute("PostId")
	if P:IsA("BasePart") and type(Id) == "string" and Id ~= "" then Posts[Id] = P end
end
local function RemovePost(P)
	local Id = P:GetAttribute("PostId")
	if Id and Posts[Id] == P then Posts[Id] = nil end
end

local function Folder()
	local Live = workspace:WaitForChild("World"):WaitForChild("Live")
	local F = Live:FindFirstChild("Townsfolk")
	if not F then
		F = Instance.new("Folder")
		F.Name = "Townsfolk"
		F.Parent = Live
	end
	return F
end

-- where a townsperson stands at a post: 3 studs up, facing the post's (flattened) LookVector
local function StandAt(Post)
	local Pos = (Post.CFrame * LIFT).Position
	local L = Post.CFrame.LookVector
	local Flat = Vector3.new(L.X, 0, L.Z)
	if Flat.Magnitude < 1e-3 then Flat = Vector3.new(0, 0, -1) end
	return CFrame.lookAt(Pos, Pos + Flat)
end

local function IdleFor(Def, Post)
	local Kind = Post:GetAttribute("Kind")
	if Kind == "Work" then return Def.Idle or TownsfolkLogic.KindIdles.Home end
	return TownsfolkLogic.KindIdles[Kind] or Def.Idle or TownsfolkLogic.KindIdles.Home
end

local function SetState(F, State)
	if F.State == State then return end
	F.State = State
	F.Rig:SetAttribute("TownsfolkState", State)
end

-- held still at a post with its idle (used on arrival, when placed while asleep, and when a walk fails)
local function Settle(F, PostId, State)
	local Post = Posts[PostId]
	if not Post or not F.Rig.Parent then return end
	Mover.Place(F.Rig, StandAt(Post)) -- (cancels a walk in progress)
	F.Post, F.Target, F.Walk = PostId, PostId, nil
	F.Rig:SetAttribute("PostId", PostId)
	F.Rig:SetAttribute("IdleAnim", IdleFor(F.Def, Post))
	SetState(F, State)
end

-- walks to PostId through the Mover; a newer Walk / Settle / Despawn cancels it
local function Walk(F, PostId)
	F.Target = PostId
	SetState(F, "Walking")
	F.Rig:SetAttribute("IdleAnim", nil) -- NpcIdles stops the pose and stops re-anchoring the root
	local H
	local function Done(Result)
		if Result == "failed" then
			WarnOnce("walk " .. F.Id .. ">" .. PostId, F.Id, "couldn't walk to post", PostId, "- placed there instead")
		end
		Settle(F, PostId, "AtPost")
	end
	H = Mover.WalkTo(F.Rig, StandAt(Posts[PostId]), {Speed = TownsfolkService.WalkSpeed, OnDone = function(Result)
		if Result == "cancelled" or H == nil or F.Walk ~= H then return end -- (H == nil: it ended at once, see below)
		Done(Result)
	end})
	if H.Status == "walking" then F.Walk = H elseif H.Status ~= "cancelled" then Done(H.Status) end
end

-- ===== the rig =====
local function Look(Def)
	local L = Def.Look
	local Nation = L.Nation
	local Seed = tonumber(L.Seed) or 0
	local Got, GotNation, GotGender = Customization.RandomLook(Nation, Random.new(Seed))
	if L.Gender then -- RandomLook takes no gender: try the next seeds until one matches
		for I = 1, TownsfolkService.GenderTries do
			if GotGender == L.Gender then break end
			Got, GotNation, GotGender = Customization.RandomLook(Nation, Random.new(Seed + I))
		end
	end
	return Got, GotNation, GotGender
end

local function BuildRig(Def)
	local Rig = StarterPlayer.StarterCharacter:Clone()
	for _, S in ipairs(Rig:GetDescendants()) do
		if S:IsA("LuaSourceContainer") then S:Destroy() end
	end
	Rig.Name = Def.Name or Def.Id
	local Humanoid = Rig:FindFirstChildOfClass("Humanoid")
	if not Humanoid:FindFirstChildOfClass("Animator") then Instance.new("Animator", Humanoid) end
	Humanoid.WalkSpeed = TownsfolkService.WalkSpeed
	Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	Humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	Humanoid.AutoJumpEnabled = false
	local L, Nation, Gender = Look(Def)
	AppearanceService.Apply(Rig, L, Def.Name)
	Rig:SetAttribute("Nation", Nation)
	Rig:SetAttribute("Gender", Gender)
	Rig:SetAttribute("Outfit", L.Outfit)
	return Rig, Humanoid
end

-- the "Townsfolk" collision group: collides with Default and with itself (no walking through each other or players)
local GROUP = "Townsfolk"
local function Collide(Rig)
	local PhysicsService = game:GetService("PhysicsService")
	if not PhysicsService:IsCollisionGroupRegistered(GROUP) then PhysicsService:RegisterCollisionGroup(GROUP) end
	PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, true)
	PhysicsService:CollisionGroupSetCollidable(GROUP, "Default", true)
	local function Set(P) if P:IsA("BasePart") then P.CollisionGroup = GROUP end end
	for _, P in ipairs(Rig:GetDescendants()) do Set(P) end
	Rig.DescendantAdded:Connect(Set) -- hair and accessories load after the look is applied
end

-- ===== API =====
function TownsfolkService.Get(Id)
	local F = Folk[Id]
	return F and F.Rig.Parent and F.Rig or nil
end

function TownsfolkService.State(Id)
	local F = Folk[Id]
	return F and F.State or nil
end

function TownsfolkService.Despawn(Id)
	local F = Folk[Id]
	if not F then return end
	Folk[Id] = nil
	if F.Walk then F.Walk:Cancel() end
	if F.Rig.Parent then F.Rig:Destroy() end
end

function TownsfolkService.Spawn(Def, Region)
	assert(type(Def) == "table" and type(Def.Id) == "string", "TownsfolkService.Spawn: Def needs a string Id")
	assert(type(Def.Look) == "table" and Customization.NationLooks[Def.Look.Nation],
		"TownsfolkService.Spawn: " .. Def.Id .. " needs Look.Nation, one of Customization.NationLooks")
	local PostId = TownsfolkLogic.PostAt(Def.Schedule, WorldClock.Now())
	local Post = Posts[PostId]
	assert(Post, "TownsfolkService.Spawn: " .. Def.Id .. "'s post " .. tostring(PostId) .. " doesn't exist")
	TownsfolkService.Despawn(Def.Id)
	local Rig, Humanoid = BuildRig(Def)
	Collide(Rig)
	Rig:SetAttribute("TownsfolkId", Def.Id)
	Rig:SetAttribute("DisplayName", Def.Name)
	Rig:SetAttribute("Region", Region)
	Rig:SetAttribute("WatcherType", "Witness")
	Rig:SetAttribute("Faction", Def.Faction)
	Rig:SetAttribute("Carrier", false)
	Rig:SetAttribute("IdleAnim", IdleFor(Def, Post))
	Rig:SetAttribute("PostId", PostId)
	Rig:SetAttribute("TownsfolkState", "AtPost")
	CollectionService:AddTag(Rig, FOLK_TAG)
	CollectionService:AddTag(Rig, WATCHER_TAG) -- attributes first: PerceptionService reads them when the tag lands
	local Root = Rig:FindFirstChild("HumanoidRootPart")
	Rig:PivotTo(StandAt(Post))
	Rig.Parent = Folder()
	pcall(Root.SetNetworkOwner, Root, nil)
	Mover.Place(Rig, StandAt(Post)) -- held still at the post (root anchored)
	local F = {Id = Def.Id, Def = Def, Region = Region, Rig = Rig, Root = Root, Humanoid = Humanoid,
		Post = PostId, Target = PostId, State = "AtPost"}
	Folk[Def.Id] = F
	Rig.Destroying:Once(function()
		if Folk[Def.Id] == F then Folk[Def.Id] = nil end
		if F.Walk then F.Walk:Cancel() end
	end)
	return Rig
end

-- Validates a roster against the posts that exist and spawns everyone, or warns and spawns nobody.
function TownsfolkService.LoadRegion(Region, Roster)
	if type(Roster) ~= "table" then warn("TownsfolkService: no roster for", Region) return false end
	local PostIds = {}
	for Id in pairs(Posts) do PostIds[Id] = true end
	local Ok, Errs = TownsfolkLogic.Validate(Roster, PostIds)
	if not Ok then
		warn("TownsfolkService: roster for " .. tostring(Region) .. " refused:\n  " .. table.concat(Errs, "\n  "))
		return false
	end
	for _, Def in ipairs(Roster) do
		local SOk, Err = pcall(TownsfolkService.Spawn, Def, Region)
		if not SOk then warn("TownsfolkService: couldn't spawn", Def.Id, Err) end
	end
	return true
end

-- One update for every townsperson (the 1 Hz loop calls it; tests call it directly). Never yields.
function TownsfolkService.Step(Hour)
	Hour = Hour or WorldClock.Now()
	local Roots = {}
	for _, P in ipairs(Players:GetPlayers()) do
		local R = P.Character and P.Character:FindFirstChild("HumanoidRootPart")
		if R then table.insert(Roots, R.Position) end
	end
	local Radius = TownsfolkService.SleepRadius
	local function Near(Pos)
		for _, R in ipairs(Roots) do
			if (R - Pos).Magnitude <= Radius then return true end
		end
		return false
	end
	for Id, F in pairs(Folk) do
		if not F.Rig.Parent then
			Folk[Id] = nil
		elseif F.State ~= "Fleeing" and F.State ~= "Sheltering" then
			local Want = TownsfolkLogic.PostAt(F.Def.Schedule, Hour)
			local Here = Near(F.Root.Position)
			if Want ~= F.Target then
				local Post = Posts[Want]
				if not Post then
					WarnOnce("post " .. tostring(Want), Id, "is due at missing post", Want)
				elseif Here or Near(Post.Position) then
					Walk(F, Want)
				else
					Settle(F, Want, "Asleep") -- (cancels a walk in progress)
				end
			elseif F.State == "Asleep" and Here then
				SetState(F, "AtPost") -- already at the right post
			elseif F.State == "AtPost" and not Here then
				SetState(F, "Asleep")
			end
		end
	end
end

local Started = false
function TownsfolkService.Start()
	if Started then return end
	Started = true
	for _, P in ipairs(CollectionService:GetTagged(POST_TAG)) do AddPost(P) end
	CollectionService:GetInstanceAddedSignal(POST_TAG):Connect(AddPost)
	CollectionService:GetInstanceRemovedSignal(POST_TAG):Connect(RemovePost)
	-- (World.Live.Townsfolk is made on the first spawn, not here: CharacterHandler's start-up loop over World.Live's
	-- children sets up every non-enemy child as a training dummy, so an empty folder made at boot could reach it)
	local Here = require(ServerScriptService.TravelService).Here()
	local Roster = Townsfolk.Regions[Here]
	if Roster then TownsfolkService.LoadRegion(Here, Roster) end
	task.spawn(function()
		while true do
			task.wait(1)
			local Ok, Err = pcall(TownsfolkService.Step)
			if not Ok then warn("TownsfolkService:", Err) end
		end
	end)
end

return TownsfolkService

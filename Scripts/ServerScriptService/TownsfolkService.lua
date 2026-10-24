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
--     them as non-combat witnesses.
--   * Combat: attacks can pick townsfolk (owner 2026-10-23: they will be hittable, with heat, standing and morality).
--     They have no WCS character yet, so DamageManager answers a hit on one with "IFramed" (no damage, no side
--     effects); HeatService still treats a player's hit on a watcher as assault. Task 6b makes them real targets.
--   * Idles: the IdleAnim attribute (NpcIdles.server.lua plays it and keeps only the root anchored). At a post the
--     root is anchored; to walk, IdleAnim is cleared and the root unanchored (NpcIdles only re-anchors while an idle
--     is playing); on arrival the root is anchored again and the post's idle set.
--   * Walking: ONLY through the child module Mover (Mover.WalkTo / Mover.Place): crowd-quality movement (Task 5b:
--     smoothed paths, steering around each other and players, giving way in doorways, re-planning). A walk's handle
--     is cancellable; a newer WalkTo or Place on the same rig cancels it, so a newer schedule change (or a flee) wins.
--     A walk that fails is finished by placing the townsperson at its post only when no player is within
--     PlaceRadius (nobody sees a teleport); otherwise it tries the walk again every RetryDelay seconds.
--   * Collision: the rigs are in the "Townsfolk" collision group (created if missing), which collides with Default
--     and with itself: townsfolk don't pass through each other or through players.
--   * States: AtPost, Walking, Asleep, Fleeing, Sheltering.
--   * Fights (Task 6): a combat sound (NoiseService.Listen: Hit, Cast, Gunshot) within its radius + FleeMargin of a
--     townsperson sends them running (Mover Urgent: never gives way, FleeSpeed) to the nearest Shelter post nobody
--     else has taken (state Fleeing), where they curl up (Sheltering, idle NPC_CurledUp). With no Shelter post, or if
--     the run fails, they curl up where they stand. CalmSeconds after the last combat sound in that range, Step sends
--     them back to their schedule. The Talk prompt is off while they flee or shelter.
--   * Talk (Task 6; owner 2026-10-23: speech over their heads in Special Elite, no reply choices): a TalkPrompt on
--     the root. Talk(Player, Id) signals the quest "Talk", then says ONE line (TownsfolkLogic.NextTalk): the clue line
--     while the player is on Def.Clue's quest stage (then signals Def.Clue.Signal), otherwise that player's rotation
--     with this townsperson: greeting by standing tier -> a rumour they haven't heard from them (RumourService.HeardIn)
--     -> the job line -> greeting... The rotation lives in memory only. No DialogueService: townsfolk carry no
--     DialogueId.
--   * Say(Id, Text): Remotes.TownsfolkSay:FireClient(Player, Rig, Text, Seconds) to every player within SayRadius;
--     TownsfolkClient draws the bubble. LastLine(Id) -> Text, Kind, Count (tests).
--   * Chatter (TownsfolkLogic.Chatter): Pass (a player first comes within PassRadius; once per player per PassEvery),
--     Shift (the schedule moves them on; ShiftChance), Flee (running for shelter), Return (coming back).
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
local Reputation = require(Rensei.Reputation)
local Factions = require(Rensei.Factions)
local Deeds = require(Rensei.Deeds)
local WorldClock = require(ServerScriptService.WorldClock)
local Mover = require(script.Mover)

local TownsfolkService = {}
TownsfolkService.SleepRadius = 300 -- PROPOSAL: no player this close -> held still, placed at posts instead of walking
TownsfolkService.WalkSpeed = 8 -- PROPOSAL: an unhurried stroll (players walk 16)
TownsfolkService.GenderTries = 64 -- seeds tried to find a look of Def.Look.Gender
TownsfolkService.PlaceRadius = 60 -- PROPOSAL (Task 5b): a failed walk is placed at its post only with no player this close
TownsfolkService.RetryDelay = 5 -- PROPOSAL (Task 5b): ...otherwise the walk is tried again after this many seconds
-- Task 6 (all PROPOSALS)
TownsfolkService.FleeSpeed = 16 -- running for shelter
TownsfolkService.FleeMargin = 20 -- a combat sound within its radius + this many studs sends them running
TownsfolkService.CalmSeconds = 20 -- back to the day this long after the last combat sound in that range
TownsfolkService.FleeKinds = {Hit = true, Cast = true, Gunshot = true} -- combat sounds (Rensei.Perception.Sounds)
TownsfolkService.SayRadius = 100 -- players this close see the bubble
TownsfolkService.PassRadius = 12 -- a player first coming this close gets a passing remark...
TownsfolkService.PassEvery = 300 -- ...at most once per player per townsperson in this many seconds
TownsfolkService.ShiftChance = 0.5 -- a remark when the schedule moves them on
TownsfolkService.TalkRange = 10 -- the Talk prompt's reach
TownsfolkService.TalkCooldown = 0.5 -- s between one player's Talks (server side: no spamming the rotation)
TownsfolkService.Rng = Random.new()

local POST_TAG = "RenseiPost"
local FOLK_TAG = "RenseiTownsfolk"
local WATCHER_TAG = "RenseiWatcher"
local LIFT = CFrame.new(0, 3, 0) -- R6 root height above the post

local Posts = {} -- [PostId] = BasePart
-- [Id] = {Id, Def, Region, Rig, Root, Humanoid, Post, Target, State, Walk (Mover handle), Prompt, Shelter (PostId while
-- fleeing / sheltering), LastNoise (os.clock), Talks ([UserId] = rotation state), PassAt / Close ([UserId])}
local Folk = {}
local LastLines = {} -- [Id] = {Text, Kind, N}
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

local function Calm(State) return State ~= "Fleeing" and State ~= "Sheltering" end

local function SetState(F, State)
	if F.State == State then return end
	F.State = State
	F.Rig:SetAttribute("TownsfolkState", State)
	if F.Prompt then F.Prompt.Enabled = Calm(State) end -- (no talking while they run or hide)
end

-- held still at a post with its idle (used on arrival, when placed while asleep, and when a walk fails)
local function Settle(F, PostId, State)
	if not F.Rig.Parent then return end
	local Post = Posts[PostId]
	local At
	if Post then
		At = StandAt(Post)
	else -- the post was removed (mid-walk, say): hold still where it stands, upright
		WarnOnce("gone " .. F.Id .. ">" .. tostring(PostId), F.Id, "'s post", PostId, "is gone - held where it stands")
		local L = F.Root.CFrame.LookVector
		local Flat = Vector3.new(L.X, 0, L.Z)
		At = CFrame.lookAt(F.Root.Position, F.Root.Position + (Flat.Magnitude > 1e-3 and Flat or Vector3.new(0, 0, -1)))
	end
	Mover.Place(F.Rig, At) -- (cancels a walk in progress)
	F.Post, F.Target, F.Walk, F.RetryAt = PostId, PostId, nil, nil
	F.Rig:SetAttribute("PostId", PostId)
	F.Rig:SetAttribute("IdleAnim", Post and IdleFor(F.Def, Post) or F.Def.Idle or TownsfolkLogic.KindIdles.Home)
	SetState(F, State)
end

-- is a player within Radius of the townsperson or of the post? (Task 5b: nobody may see a teleport)
local function PlayerWithin(F, PostId, Radius)
	local Post = Posts[PostId]
	for _, P in ipairs(Players:GetPlayers()) do
		local R = P.Character and P.Character:FindFirstChild("HumanoidRootPart")
		if R and ((R.Position - F.Root.Position).Magnitude <= Radius or (Post and (R.Position - Post.Position).Magnitude <= Radius)) then
			return true
		end
	end
	return false
end

-- walks to PostId through the Mover; a newer Walk / Settle / Despawn cancels it
local function Walk(F, PostId)
	F.Target, F.RetryAt = PostId, nil
	SetState(F, "Walking")
	F.Rig:SetAttribute("IdleAnim", nil) -- NpcIdles stops the pose and stops re-anchoring the root
	local H
	local function Done(Result)
		if Result == "failed" then
			if PlayerWithin(F, PostId, TownsfolkService.PlaceRadius) then
				-- someone would see the teleport: stand where it is and try again shortly (Step, below)
				WarnOnce("retry " .. F.Id .. ">" .. PostId, F.Id, "couldn't walk to post", PostId, "- trying again")
				F.Walk, F.RetryAt = nil, os.clock() + TownsfolkService.RetryDelay
				return
			end
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

-- ===== speech (Task 6) =====
local SayRemote
function TownsfolkService.Say(Id, Text, Kind)
	local F = Folk[Id]
	if not F or not F.Rig.Parent or type(Text) ~= "string" or Text == "" then return false end
	local Prev = LastLines[Id]
	LastLines[Id] = {Text = Text, Kind = Kind, N = (Prev and Prev.N or 0) + 1}
	if not (SayRemote and SayRemote.Parent) then
		local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
		SayRemote = Remotes and Remotes:FindFirstChild("TownsfolkSay")
	end
	if not SayRemote then WarnOnce("remote", "Remotes.TownsfolkSay is missing - townsfolk lines aren't shown") return true end
	local Seconds = TownsfolkLogic.SpeechSeconds(Text)
	for _, P in ipairs(Players:GetPlayers()) do
		local R = P.Character and P.Character:FindFirstChild("HumanoidRootPart")
		if R and (R.Position - F.Root.Position).Magnitude <= TownsfolkService.SayRadius then
			SayRemote:FireClient(P, F.Rig, Text, Seconds)
		end
	end
	return true
end

-- the last line a townsperson said: Text, Kind, how many lines it has said (tests)
function TownsfolkService.LastLine(Id)
	local L = LastLines[Id]
	if not L then return nil, nil, 0 end
	return L.Text, L.Kind, L.N
end

local function Chat(F, Kind)
	local Line = TownsfolkLogic.Chat(Kind, TownsfolkService.Rng)
	if Line then TownsfolkService.Say(F.Id, Line, Kind) end
end

-- how Listener knows Subject, for a rumour. Owner 2026-10-23: "Name if known, else 'someone'": the name once the
-- listener has identified them (IdentityService.KnownNameFor), otherwise "someone", never the journal's "Subject 03"
local function NameOf(Listener, Subject)
	if typeof(Subject) ~= "Instance" then return "someone" end
	local Ok, Name = pcall(function() return require(ServerScriptService.IdentityService).KnownNameFor(Listener, Subject) end)
	return (Ok and type(Name) == "string" and Name ~= "") and Name or "someone"
end

local LastTalk = {} -- [UserId] = os.clock() of their last Talk (the cooldown)

-- Player talks to townsperson Id: one line over their head. Returns Text, Kind (nil while they flee or shelter, or
-- within TalkCooldown of this player's last Talk)
function TownsfolkService.Talk(Player, Id)
	local F = Folk[Id]
	if not F or not F.Rig.Parent or not Calm(F.State) then return nil end
	local Now = os.clock()
	if Now - (LastTalk[Player.UserId] or -math.huge) < TownsfolkService.TalkCooldown then return nil end
	LastTalk[Player.UserId] = Now
	local Def = F.Def
	local QuestService = require(ServerScriptService.QuestService)
	local SOk, SErr = pcall(QuestService.Signal, Player, "Talk", Def.Id)
	if not SOk then warn("TownsfolkService: Talk signal failed:", SErr) end
	local Data = require(ServerScriptService.ProgressionService).GetData(Player)
	-- the clue line: while the player is on the clue's quest, at its stage
	local Clue, OnClue = Def.Clue, false
	if type(Clue) == "table" and Data and type(Data.Quests) == "table" and type(Data.Quests.Active) == "table" then
		local Q = Data.Quests.Active[Clue.Quest]
		OnClue = type(Q) == "table" and (Clue.Stage == nil or Q.Stage == Clue.Stage)
	end
	-- standing with their faction in this region
	local Tier = "Neutral"
	if Data and type(Data.Morality) == "table" then
		local Standing = Reputation.PlaceStanding(Data.Morality, Deeds, F.Region) or {}
		Tier = Factions.TierOf(Standing[Def.Faction] or 0)
	end
	-- what the region has heard (each (subject, deed) once; worded for this listener)
	local HOk, Heard = pcall(function() return require(ServerScriptService.RumourService).HeardIn(F.Region, 3) end)
	if not HOk then warn("TownsfolkService: HeardIn failed:", Heard) Heard = {} end
	local Rumours = TownsfolkLogic.Rumours(Heard, Player, function(Subject) return NameOf(Player, Subject) end)
	F.Talks = F.Talks or {}
	local State = F.Talks[Player.UserId] or {}
	F.Talks[Player.UserId] = State
	local Kind, Text = TownsfolkLogic.NextTalk(Def, State, {Tier = Tier, Rumours = Rumours, Clue = OnClue})
	TownsfolkService.Say(Id, Text, Kind)
	if Kind == "Clue" and Clue.Signal ~= nil then
		local COk, CErr = pcall(QuestService.Signal, Player, "Signal", Clue.Signal)
		if not COk then warn("TownsfolkService: clue signal failed:", CErr) end
	end
	return Text, Kind
end

-- ===== fights (Task 6) =====
-- the nearest Shelter post nobody else is running to or hiding at (else the nearest one)
local function NearestShelter(F)
	local Taken = {}
	for _, O in pairs(Folk) do
		if O ~= F and O.Shelter then Taken[O.Shelter] = true end
	end
	local Best, BestD, Any, AnyD
	for Id, P in pairs(Posts) do
		if P.Parent and P:GetAttribute("Kind") == "Shelter" then
			local D = (P.Position - F.Root.Position).Magnitude
			if not Any or D < AnyD then Any, AnyD = Id, D end
			if not Taken[Id] and (not Best or D < BestD) then Best, BestD = Id, D end
		end
	end
	return Best or Any
end

-- curls up where it stands (no shelter post, or the run failed)
local function Cower(F)
	if not F.Rig.Parent then return end
	local L = F.Root.CFrame.LookVector
	local Flat = Vector3.new(L.X, 0, L.Z)
	Mover.Place(F.Rig, CFrame.lookAt(F.Root.Position, F.Root.Position + (Flat.Magnitude > 1e-3 and Flat or Vector3.new(0, 0, -1))))
	F.Walk, F.RetryAt = nil, nil
	F.Shelter = nil -- (a failed run releases the shelter it was running to)
	F.Rig:SetAttribute("IdleAnim", TownsfolkLogic.KindIdles.Shelter)
	SetState(F, "Sheltering")
end

local function Flee(F)
	F.Shelter = NearestShelter(F)
	F.Target, F.RetryAt = nil, nil -- (so the schedule walks them back to wherever they are due once it's calm)
	F.Rig:SetAttribute("IdleAnim", nil)
	SetState(F, "Fleeing")
	Chat(F, "Flee")
	local Post = F.Shelter and Posts[F.Shelter]
	if not Post then Cower(F) return end
	local H
	H = Mover.WalkTo(F.Rig, StandAt(Post), {Speed = TownsfolkService.FleeSpeed, Urgent = true, OnDone = function(Result)
		if Result == "cancelled" or H == nil or F.Walk ~= H then return end
		F.Walk = nil
		if Result == "arrived" and F.Shelter and Posts[F.Shelter] then Settle(F, F.Shelter, "Sheltering") else Cower(F) end
	end})
	if H.Status == "walking" then F.Walk = H elseif H.Status ~= "cancelled" then Cower(F) end
end

-- NoiseService.Listen: a combat sound in range sends every calm townsperson there running; any in range keeps them
-- hiding (LastNoise)
local function OnNoise(Position, Radius, Kind)
	if not TownsfolkService.FleeKinds[Kind] or typeof(Position) ~= "Vector3" then return end
	local Reach = (tonumber(Radius) or 0) + TownsfolkService.FleeMargin
	local Now = os.clock()
	for Id, F in pairs(Folk) do
		if F.Rig.Parent and F.Root.Parent and (F.Root.Position - Position).Magnitude <= Reach then
			F.LastNoise = Now
			if Calm(F.State) then
				local Ok, Err = pcall(Flee, F)
				if not Ok then WarnOnce("flee " .. Id, Id, "couldn't flee:", Err) end
			end
		end
	end
end
TownsfolkService.OnNoise = OnNoise -- (tests)

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
	LastLines[Id] = nil
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
		Post = PostId, Target = PostId, State = "AtPost", Talks = {}, PassAt = {}, Close = {}}
	Folk[Def.Id] = F
	-- Talk (Task 6): the same prompt as DialogueService's NPCs (drawn in Rensei's art by Modules.UI.PromptUI)
	local Prompt = Instance.new("ProximityPrompt")
	Prompt.Name = "TalkPrompt"
	Prompt.ActionText = "Talk"
	Prompt.ObjectText = Def.Name or Def.Id
	Prompt.MaxActivationDistance = TownsfolkService.TalkRange
	Prompt.RequiresLineOfSight = false
	Prompt.Style = Enum.ProximityPromptStyle.Custom
	Prompt.Parent = Root
	Prompt.Triggered:Connect(function(Player)
		local Ok, Err = pcall(TownsfolkService.Talk, Player, Def.Id)
		if not Ok then warn("TownsfolkService: Talk failed:", Err) end
	end)
	F.Prompt = Prompt
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
	local Roots, Who = {}, {}
	for _, P in ipairs(Players:GetPlayers()) do
		local R = P.Character and P.Character:FindFirstChild("HumanoidRootPart")
		if R then
			table.insert(Roots, R.Position)
			table.insert(Who, P)
		end
	end
	local Radius = TownsfolkService.SleepRadius
	local function Near(Pos)
		for _, R in ipairs(Roots) do
			if (R - Pos).Magnitude <= Radius then return true end
		end
		return false
	end
	local function One(Id, F)
		if not F.Rig.Parent then
			Folk[Id] = nil
			return
		end
		if F.State == "Fleeing" then
			-- watchdog: running with no run in progress (it ended without settling) -> curl up where it is
			if not (F.Walk and F.Walk.Status == "walking") then Cower(F) end
			return
		end
		local Back = false
		if F.State == "Sheltering" then
			if os.clock() - (F.LastNoise or 0) <= TownsfolkService.CalmSeconds then return end
			-- calm again: back to the day (the schedule below walks them to the post they're due at, or places them)
			F.Shelter = nil
			Back = true
			SetState(F, "AtPost")
			Chat(F, "Return")
		end
		-- a passing remark: a player first comes within PassRadius (once per player per PassEvery)
		for I, R in ipairs(Roots) do
			local Key = Who[I].UserId
			local Close = (R - F.Root.Position).Magnitude <= TownsfolkService.PassRadius
			if Close and not F.Close[Key] and os.clock() - (F.PassAt[Key] or -math.huge) >= TownsfolkService.PassEvery then
				F.PassAt[Key] = os.clock()
				Chat(F, "Pass")
			end
			F.Close[Key] = Close or nil
		end
		if F.State == "Walking" and not (F.Walk and F.Walk.Status == "walking") then
			if F.RetryAt then
				-- a failed walk with a player near: try again (or place it, once nobody is near)
				if os.clock() >= F.RetryAt then
					if PlayerWithin(F, F.Target, TownsfolkService.PlaceRadius) then Walk(F, F.Target) else Settle(F, F.Target, "AtPost") end
				end
			else
				-- watchdog: "Walking" with no live walk (it ended without settling) -> settle at the post it was walking to
				WarnOnce("watchdog " .. Id, Id, "was Walking with no walk in progress - settled at", F.Target)
				Settle(F, F.Target, "AtPost")
			end
		end
		local Want = TownsfolkLogic.PostAt(F.Def.Schedule, Hour)
		local Here = Near(F.Root.Position)
		if Want ~= F.Target then
			local Post = Posts[Want]
			if not Post then
				WarnOnce("post " .. tostring(Want), Id, "is due at missing post", Want)
			elseif Here or Near(Post.Position) then
				local Shift = not Back and F.Target ~= nil
				Walk(F, Want)
				if Shift and TownsfolkService.Rng:NextNumber() < TownsfolkService.ShiftChance then Chat(F, "Shift") end
			else
				Settle(F, Want, "Asleep") -- (cancels a walk in progress)
			end
		elseif Back then
			Settle(F, Want, Here and "AtPost" or "Asleep") -- (it sheltered at its own post: just its idle back)
		elseif F.State == "Asleep" and Here then
			SetState(F, "AtPost") -- already at the right post
		elseif F.State == "AtPost" and not Here then
			SetState(F, "Asleep")
		end
	end
	for Id, F in pairs(Folk) do
		local Ok, Err = pcall(One, Id, F) -- one bad townsperson doesn't stop the others
		if not Ok then WarnOnce("step " .. Id, Id, "Step failed:", Err) end
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
	require(ServerScriptService.NoiseService).Listen(OnNoise)
	Players.PlayerRemoving:Connect(function(Player)
		LastTalk[Player.UserId] = nil
		for _, F in pairs(Folk) do
			F.Talks[Player.UserId], F.PassAt[Player.UserId], F.Close[Player.UserId] = nil, nil, nil
		end
	end)
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

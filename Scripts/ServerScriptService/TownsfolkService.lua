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
--   * Combat (Task 6b; owner 2026-10-23: "The townsfolk should be hittable and integrate the heat, rep system,
--     morality, etc."; at 0 health "Knocked, can be finished"): each rig gets a WCS character the way EnemyService
--     gives its enemies one (WCS.Character.new, default props, BlockManager.Initiate), MaxHealth 100 and no
--     regeneration (the rig carries no Health script), Knockable, and its own knock length / recovery
--     (attributes KnockedTime / RecoverHealth, read by DownedManager). Only players hurt them (DamageManager).
--       - Hit (a landed player hit, ProgressionService.HitListeners, run FIRST so the generic "Hit" sound finds them
--         already reacting): the walk stops where they stand (Mover.Stop: no steering, facing or re-anchoring while
--         the combat code owns the body), a Hurt line, state Hurt; once the hit's stun / pin is over they run
--         (Urgent) to the shelter farthest from the attacker among the ShelterChoices nearest. Every other
--         townsperson within HelpRadius runs too (HelpChance of them shout a Help line). The assault deed is
--         HeatService's (a landed hit on a RenseiWatcher).
--       - Knocked at 0 health (DownedManager, as enemies): state Knocked, can be gripped (B) and carried (V). Left
--         alone KnockedSeconds, they get up with RecoverShare of their health, say a Hurt line and run for shelter.
--       - Death (a grip's execution, or anything that kills outright): state Dead. The killer is the last player to
--         hit, grip or execute them within KillerSeconds: murder_townsfolk, witnessed, in their region. No
--         defeat rewards of any kind (WorldService and ProgressionService skip a TownsfolkId). The body lies
--         BodySeconds, then is removed; nothing settles or walks a dead townsperson.
--       - Newcomers: at the next NewcomerHour (06:00, WorldClock.Changed) every dead townsperson's slot is filled
--         again: same Id, job, faction, nation, schedule, a new Name (TownsfolkLogic.NewcomerName: none alive in the
--         region has it) and a new look seed. They greet people as anyone does; the killer's deed stands. With a
--         player within PlaceRadius of the post (or the old body), that newcomer waits for a later Step (fix round 1).
--   * Idles: the IdleAnim attribute (NpcIdles.server.lua plays it and keeps only the root anchored). At a post the
--     root is anchored; to walk, IdleAnim is cleared and the root unanchored (NpcIdles only re-anchors while an idle
--     is playing); on arrival the root is anchored again and the post's idle set.
--   * Walking: ONLY through the child module Mover (Mover.WalkTo / Mover.Place): crowd-quality movement (Task 5b:
--     smoothed paths, steering around each other and players, giving way in doorways, re-planning). A walk's handle
--     is cancellable; a newer WalkTo or Place on the same rig cancels it, so a newer schedule change (or a flee) wins.
--     A walk that fails (Foundry Yard plan Task 4b, Ruling 30) is never finished by a teleport anyone could see: with
--     no player within SleepRadius of the townsperson or of the post it is placed there; otherwise it holds where it
--     stands with its idle and tries the walk again after RetryDelays (5, 10, 20, 40, then 40 s), placed at the post
--     only once nobody is within SleepRadius of either. Every failure is warned and counted (WalkFailures).
--   * Collision: the rigs are in the "Townsfolk" collision group (created if missing), which collides with Default
--     and with itself: townsfolk don't pass through each other or through players.
--   * States: AtPost, Walking, Asleep (calm), Fleeing, Sheltering, and (Task 6b) Hurt, Knocked, Dead.
--   * Fights (Task 6): a combat sound (NoiseService.Listen: Hit, Cast, Gunshot) within its radius + FleeMargin of a
--     townsperson sends them running (Mover Urgent: never gives way, FleeSpeed) to the nearest Shelter post nobody
--     else has taken (state Fleeing), where they curl up (Sheltering, idle NPC_CurledUp). With no Shelter post, or if
--     the run fails, they curl up where they stand. CalmSeconds after the last combat sound in that range, Step sends
--     them back to their schedule. The Talk prompt is off while they flee or shelter.
--   * Takedowns (assassinations Task 9, spec §18.2, owner 2026-10-27 "Flee and report"): Startle(Id, From) -- a calm
--     townsperson who saw a takedown (TakedownService: PerceptionService.Glimpse's result) runs the same way, away from
--     From, and hides CalmSeconds. (A knockout and an assassination are quiet: their Choke / Takedown sounds aren't
--     FleeKinds, so only the ones who saw it run. An Elite's backstab is a real hit: its 20-stud Hit sound sends the
--     townsfolk in range running too, seen or not, through OnNoise.) Reporting it is the deed's witness capture
--     (MoralityService / WitnessService / RumourService).
--   * Talk (Task 6; owner 2026-10-23: speech over their heads in Special Elite, no reply choices): a TalkPrompt on
--     the root. Talk(Player, Id) is refused (nil) when the player's root is more than TalkRange + TalkMargin studs from
--     the townsperson's (Foundry Yard plan Task 4b, Ruling 31: the server's own range check; the margin is for lag).
--     Otherwise it signals the quest "Talk", then says ONE line (TownsfolkLogic.NextTalk): the clue line
--     while the player is on Def.Clue's quest stage (then gives Def.Clue.Evidence, if any, through
--     StoryService.GiveEvidence, and only then signals Def.Clue.Signal, so the next stage's catch-up already sees the
--     evidence: Foundry Yard plan Task 2), otherwise that player's rotation
--     with this townsperson: greeting by standing tier -> a rumour they haven't heard from them (RumourService.HeardIn)
--     -> the job line -> greeting... The rotation lives in memory only. No DialogueService: townsfolk carry no
--     DialogueId.
--   * Say(Id, Text, Kind, Opts): Remotes.TownsfolkSay:FireClient(Player, Rig, Text, Seconds) to every player within
--     SayRadius (Recipients); TownsfolkClient draws the bubble. Opts.Only = a player: only that player sees it (fix
--     round 2, controller ruling: rumour and clue lines are worded for the talker - names only they know, "They say
--     you ..." - so they are private; greetings, job lines and chatter are public). LastLine(Id) -> Text, Kind, Count;
--     LastRecipients(Id) -> the players it was fired to, Only (tests).
--   * Chatter (TownsfolkLogic.Chatter): Pass (a player first comes within PassRadius; once per player per PassEvery),
--     Shift (the schedule moves them on; ShiftChance), Flee (running for shelter), Return (coming back), Hurt (hit,
--     or getting up after a knock) and Help (near someone who was hit).
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
local StoryLogic = require(Rensei.StoryLogic) -- (Foundry Yard plan Task 2 fix round 1: StoryLogic.Stale)
local WorldClock = require(ServerScriptService.WorldClock)
local Mover = require(script.Mover)

local TownsfolkService = {}
TownsfolkService.SleepRadius = 300 -- PROPOSAL: no player this close -> held still, placed at posts instead of walking
TownsfolkService.WalkSpeed = 8 -- PROPOSAL: an unhurried stroll (players walk 16)
TownsfolkService.GenderTries = 64 -- seeds tried to find a look of Def.Look.Gender
TownsfolkService.PlaceRadius = 60 -- PROPOSAL (Task 5b): a newcomer appears only with no player this close to its post
-- (Foundry Yard plan Task 4b, Ruling 30) a failed walk holds and tries again after these many seconds (the last one
-- repeats); it is placed at its post only with no player within SleepRadius of it or of the post. PROPOSAL
TownsfolkService.RetryDelays = {5, 10, 20, 40}
TownsfolkService.WalkFailures = 0 -- (Task 4b) failed walks since the server started (each one is warned)
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
TownsfolkService.TalkMargin = 4 -- PROPOSAL (Task 4b, Ruling 31): the server refuses a Talk from beyond TalkRange + this
TownsfolkService.TalkCooldown = 0.5 -- s between one player's Talks (server side: no spamming the rotation)
-- Task 6b (all PROPOSALS)
TownsfolkService.MaxHealth = 100
TownsfolkService.HelpRadius = 30 -- a player hits a townsperson: everyone else this close runs too...
TownsfolkService.HelpChance = 0.5 -- ...and this share of them shouts a Help line
TownsfolkService.ShelterChoices = 3 -- a hurt townsperson runs to the shelter farthest from the attacker of this many nearest
TownsfolkService.ShelterRadius = 150 -- PROPOSAL (Lindenmoor import Task 8 fix round 3): only a shelter this close is run to,
-- whether fleeing a fight or hurt; with none this close they curl up where they stand (no 800-stud sprint to the mill)
TownsfolkService.HurtMax = 5 -- s: the longest a hurt townsperson waits for the hit's stun / pin to end before it runs
TownsfolkService.KnockedSeconds = 30 -- knocked at 0 health; left alone this long, they get up...
TownsfolkService.RecoverShare = 0.3 -- ...with this share of their health, and run for shelter
TownsfolkService.KillerSeconds = 10 -- the killer: the last player to hit, grip or execute them within this long
TownsfolkService.BodySeconds = 60 -- a body lies this long, then it's removed
TownsfolkService.NewcomerHour = 6 -- a dead townsperson's job is taken at the next 06:00
TownsfolkService.Rng = Random.new()

local POST_TAG = "RenseiPost"
local FOLK_TAG = "RenseiTownsfolk"
local WATCHER_TAG = "RenseiWatcher"
local LIFT = CFrame.new(0, 3, 0) -- R6 root height above the post

local Posts = {} -- [PostId] = BasePart
-- [Id] = {Id, Def, Region, Rig, Root, Humanoid, Post, Target, State, Walk (Mover handle), Prompt, Shelter (PostId while
-- fleeing / sheltering), LastNoise (os.clock), Talks ([UserId] = rotation state), PassAt / Close ([UserId]);
-- Task 6b: WC (WCS character), LastBy ({Player, At}: the last player to hit or grip them), HurtGen (a newer hurt
-- or knock supersedes the run a hurt one is waiting to make), Dead}
local Folk = {}
local Dead = {} -- [Id] = {Def, Region}: killed; a newcomer takes the slot at the next NewcomerHour (Task 6b)
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
	-- in workspace only (final review M1, 2026-10-24): a post kept in a backup keeps its tag
	if P:IsA("BasePart") and P:IsDescendantOf(workspace) and type(Id) == "string" and Id ~= "" then Posts[Id] = P end
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

-- going about the day (not running, hiding, hurt, knocked or dead)
local function Calm(State) return State == "AtPost" or State == "Walking" or State == "Asleep" end

local function SetState(F, State)
	if F.State == State then return end
	F.State = State
	F.Rig:SetAttribute("TownsfolkState", State)
	if F.Prompt then F.Prompt.Enabled = Calm(State) end -- (no talking while they run or hide)
end

-- ===== combat (Task 6b) =====
local Combat -- the combat modules, required on first use
local function CombatModules()
	if not Combat then
		local Modules = ReplicatedStorage.Modules
		Combat = {
			WCS = require(Modules.Framework.WCS),
			BlockManager = require(Modules.Managers.BlockManager),
			Stun = require(Modules.Skills.States.Stun),
		}
	end
	return Combat
end

-- a WCS character, as EnemyService gives each enemy (WCS.Character.new, default props, BlockManager.Initiate):
-- DamageManager needs one to land a hit. WCS refuses characters until its server has started (CharacterHandler's
-- WCSStarted attribute); until then the townsperson can't be hurt, and Step tries again.
local function EnsureCombat(F)
	if F.WC or F.Dead or not F.Rig.Parent then return F.WC end
	local Handler = ServerScriptService:FindFirstChild("CharacterHandler")
	if not (Handler and Handler:GetAttribute("WCSStarted")) then return nil end
	local C = CombatModules()
	local Ok, WC = pcall(function()
		return C.WCS.Character.GetCharacterFromInstance(F.Rig) or C.WCS.Character.new(F.Rig)
	end)
	if not Ok or not WC then
		WarnOnce("wcs " .. F.Id, F.Id, "has no combat character:", WC)
		return nil
	end
	-- (WCS puts these back whenever a status effect with humanoid data starts or ends)
	pcall(function()
		WC:SetDefaultProps({WalkSpeed = TownsfolkService.WalkSpeed, JumpPower = F.Humanoid.JumpPower,
			JumpHeight = F.Humanoid.JumpHeight, AutoRotate = true})
	end)
	C.BlockManager.Initiate(F.Rig)
	F.WC = WC
	return WC
end

-- knocked, gripped, carried or dead: DownedManager / death own the body
local function Down(F)
	local R = F.Rig
	return F.Dead == true or F.Humanoid.Health <= 0 or R:GetAttribute("Knocked") == true
		or R:GetAttribute("GrippedBy") ~= nil or R:GetAttribute("CarriedBy") ~= nil
end

-- free to run: up, not pinned (Mover.Pinned: knocked / gripped / carried, slowed or pinned by a hit, tripped or
-- ragdolled) and not stunned (WCS)
local function Free(F)
	if not F.Rig.Parent or Down(F) or Mover.Pinned(F.Rig) then return false end
	if F.WC then
		local Ok, Stunned = pcall(function() return F.WC:HasStatusEffects({CombatModules().Stun}) end)
		if Ok and Stunned then return false end
	end
	return true
end

-- whatever it was doing stops where it stands, and the combat code owns the body: the walk ends without a placement
-- (Mover.Stop: no steering, the facing constraint off, never re-anchored), the idle pose stops (NpcIdles anchors
-- the root only while a pose plays), the root is free to be knocked about
local function Halt(F)
	F.Walk, F.Target, F.RetryAt, F.Shelter = nil, nil, nil, nil
	Mover.Stop(F.Rig)
	F.Rig:SetAttribute("IdleAnim", nil)
	-- (a body held by a grip or a carry is welded to the holder, who owns the pair's physics: left as it is)
	if F.Root.Parent and not (F.Rig:GetAttribute("GrippedBy") or F.Rig:GetAttribute("CarriedBy")) then
		F.Root.Anchored = false
		pcall(F.Root.SetNetworkOwner, F.Root, nil)
	end
end

local function PosOf(Model)
	local R = typeof(Model) == "Instance" and Model:FindFirstChild("HumanoidRootPart")
	return R and R.Position or nil
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
	F.Post, F.Target, F.Walk, F.RetryAt, F.RetryDelay = PostId, PostId, nil, nil, nil -- (Task 9: the backoff's delay too)
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

-- (Task 4b) a failed walk: held still where it stands, upright, with its own idle (it tries again later)
local function HoldHere(F)
	local L = F.Root.CFrame.LookVector
	local Flat = Vector3.new(L.X, 0, L.Z)
	Mover.Place(F.Rig, CFrame.lookAt(F.Root.Position, F.Root.Position + (Flat.Magnitude > 1e-3 and Flat or Vector3.new(0, 0, -1))))
	F.Rig:SetAttribute("IdleAnim", F.Def.Idle or TownsfolkLogic.KindIdles.Home)
end

-- walks to PostId through the Mover; a newer Walk / Settle / Despawn cancels it
local function Walk(F, PostId)
	if F.FailPost ~= PostId then F.FailPost, F.Fails = PostId, 0 end -- (the backoff counts failures on one post)
	F.Target, F.RetryAt = PostId, nil
	SetState(F, "Walking")
	F.Rig:SetAttribute("IdleAnim", nil) -- NpcIdles stops the pose and stops re-anchoring the root
	local H
	local function Done(Result)
		if Result == "failed" then
			-- (Task 4b, Ruling 30) never a teleport a player within SleepRadius could see: hold, and try again later
			F.Fails += 1
			TownsfolkService.WalkFailures += 1
			-- (a post removed meanwhile: Settle holds it where it stands, as before)
			local Seen = Posts[PostId] ~= nil and PlayerWithin(F, PostId, TownsfolkService.SleepRadius)
			local Delays = TownsfolkService.RetryDelays
			local Delay = Delays[math.min(F.Fails, #Delays)]
			warn(("TownsfolkService: %s couldn't walk to post %s (%s; failure %d in a row) - %s"):format(F.Id, PostId,
				tostring(H and H.Why or "no walk"), F.Fails, Seen and ("holding, trying again in " .. Delay .. " s") or "placed there (nobody near)"))
			if Seen then
				F.Walk, F.RetryAt, F.RetryDelay = nil, os.clock() + Delay, Delay
				HoldHere(F)
				return
			end
		end
		F.Fails = 0
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
-- who sees a line said at Pos: every player (of List, default everyone in the server) within SayRadius, or only
-- Opts.Only (if within SayRadius) for a private line
function TownsfolkService.Recipients(Pos, Opts, List)
	local Out = {}
	local Only = Opts and Opts.Only
	for _, P in ipairs(List or Players:GetPlayers()) do
		local C = P.Character
		local R = C and C:FindFirstChild("HumanoidRootPart")
		if R and (Only == nil or P == Only) and (R.Position - Pos).Magnitude <= TownsfolkService.SayRadius then
			table.insert(Out, P)
		end
	end
	return Out
end

function TownsfolkService.Say(Id, Text, Kind, Opts)
	local F = Folk[Id]
	if not F or not F.Rig.Parent or type(Text) ~= "string" or Text == "" then return false end
	local Prev = LastLines[Id]
	local To = TownsfolkService.Recipients(F.Root.Position, Opts)
	LastLines[Id] = {Text = Text, Kind = Kind, N = (Prev and Prev.N or 0) + 1, To = To, Only = Opts and Opts.Only}
	if not (SayRemote and SayRemote.Parent) then
		local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
		SayRemote = Remotes and Remotes:FindFirstChild("TownsfolkSay")
	end
	if not SayRemote then WarnOnce("remote", "Remotes.TownsfolkSay is missing - townsfolk lines aren't shown") return true end
	local Seconds = TownsfolkLogic.SpeechSeconds(Text)
	for _, P in ipairs(To) do SayRemote:FireClient(P, F.Rig, Text, Seconds) end
	return true
end

-- the players the last line was fired to, and its Only (nil for a public line) (tests)
function TownsfolkService.LastRecipients(Id)
	local L = LastLines[Id]
	if not L then return {}, nil end
	return L.To, L.Only
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
	-- (Task 4b, Ruling 31) the server's own range check: the prompt's reach plus a margin for lag
	local Char = Player.Character
	local Me = Char and Char:FindFirstChild("HumanoidRootPart")
	if not (Me and (Me.Position - F.Root.Position).Magnitude <= TownsfolkService.TalkRange + TownsfolkService.TalkMargin) then return nil end
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
		-- (Foundry Yard plan Task 2 fix round 1) a stale-revision state is on no known stage until Boot upgrades it
		OnClue = type(Q) == "table" and not StoryLogic.Stale(QuestService.Definitions[Clue.Quest], Q)
			and (Clue.Stage == nil or Q.Stage == Clue.Stage)
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
	-- rumours and clues are worded for this player (names only they know, "They say you ..."): theirs alone
	local Private = Kind == "Rumour" or Kind == "Clue"
	TownsfolkService.Say(Id, Text, Kind, Private and {Only = Player} or nil)
	-- (Foundry Yard plan Task 2) the clue line's evidence, given BEFORE its signal: the next stage's catch-up sees it
	if Kind == "Clue" and type(Clue.Evidence) == "string" then
		local EOk, EErr = pcall(function() require(ServerScriptService.StoryService).GiveEvidence(Player, Clue.Evidence) end)
		if not EOk then warn("TownsfolkService: clue evidence failed:", EErr) end
	end
	if Kind == "Clue" and Clue.Signal ~= nil then
		local COk, CErr = pcall(QuestService.Signal, Player, "Signal", Clue.Signal)
		if not COk then warn("TownsfolkService: clue signal failed:", CErr) end
	end
	return Text, Kind
end

-- ===== fights (Task 6) =====
-- the nearest Shelter post within ShelterRadius nobody else is running to or hiding at (else the nearest one within it;
-- nil when none is)
local function NearestShelter(F)
	local Taken = {}
	for _, O in pairs(Folk) do
		if O ~= F and O.Shelter then Taken[O.Shelter] = true end
	end
	local Best, BestD, Any, AnyD
	for Id, P in pairs(Posts) do
		if P.Parent and P:GetAttribute("Kind") == "Shelter" then
			local D = (P.Position - F.Root.Position).Magnitude
			if D > TownsfolkService.ShelterRadius then continue end
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

-- (Task 6b) the shelter a townsperson runs to from an attacker at From: the farthest from it of the ShelterChoices
-- nearest within ShelterRadius (TownsfolkLogic.AwayShelter)
local function AwayShelter(F, From)
	local List = {}
	for Id, P in pairs(Posts) do
		if P.Parent and P:GetAttribute("Kind") == "Shelter" then table.insert(List, {Id = Id, Pos = P.Position}) end
	end
	return TownsfolkLogic.AwayShelter(List, F.Root.Position, From, TownsfolkService.ShelterChoices, TownsfolkService.ShelterRadius)
end

-- runs for shelter: away from From (an attacker's position, Task 6b) when given, else to the nearest free one.
-- Quiet: no Flee line (a hurt one has said its Hurt line, a helper its Help line)
local function Flee(F, From, Quiet)
	F.Shelter = (typeof(From) == "Vector3" and AwayShelter(F, From)) or NearestShelter(F)
	F.Target, F.RetryAt = nil, nil -- (so the schedule walks them back to wherever they are due once it's calm)
	F.Rig:SetAttribute("IdleAnim", nil)
	SetState(F, "Fleeing")
	if not Quiet then Chat(F, "Flee") end
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

-- (assassinations Task 9, spec §18.2, pre-flight R10) a townsperson who saw a takedown at From (a position: the
-- player's) runs for shelter as from a fight (Flee: away from From), and keeps hiding CalmSeconds as after a combat
-- sound. Only a calm one that is up (not already running, hiding, hurt, knocked, held or dead). Returns true when it ran.
function TownsfolkService.Startle(Id, From)
	local F = Folk[Id]
	if not (F and F.Rig.Parent and F.Root.Parent) or Down(F) or not Calm(F.State) then return false end
	F.LastNoise = os.clock()
	local Ok, Err = pcall(Flee, F, typeof(From) == "Vector3" and From or nil)
	if not Ok then WarnOnce("startle " .. Id, Id, "couldn't flee:", Err) end
	return Ok
end

-- ===== hurt, knocked, dead (Task 6b) =====
-- a hurt townsperson runs once it can (the hit's stun / pin over, HurtMax at most), away from the attacker as they
-- stand then. A newer hit, a knock or death supersedes the wait (HurtGen).
local function RunWhenFree(F, Attacker)
	F.HurtGen = (F.HurtGen or 0) + 1
	local Gen = F.HurtGen
	local From = PosOf(Attacker)
	task.spawn(function()
		local T0 = os.clock()
		repeat task.wait(0.1)
		until F.HurtGen ~= Gen or not F.Rig.Parent or Down(F) or Free(F) or os.clock() - T0 >= TownsfolkService.HurtMax
		if F.HurtGen ~= Gen or not F.Rig.Parent or Down(F) or F.State ~= "Hurt" then return end
		local Ok, Err = pcall(TownsfolkService.HurtFlee, F, PosOf(Attacker) or From, true)
		if not Ok then
			-- (fix round 1) never left frozen in Hurt: curl up where it stands, as a failed run does
			WarnOnce("hurtflee " .. F.Id, F.Id, "couldn't flee:", Err)
			local COk, CErr = pcall(Cower, F)
			if not COk then WarnOnce("hurtcower " .. F.Id, F.Id, "couldn't curl up either:", CErr) end
		end
	end)
end
TownsfolkService.HurtFlee = Flee -- (the hurt one's run; a field so a test can make it throw and check the fallback)

-- a player's hit landed on F (Attacker = their character): F reacts unless the hit knocked it (OnKnockedChanged
-- takes that), and everyone else within HelpRadius runs too
local function OnHurt(F, Attacker)
	local Now = os.clock()
	F.LastNoise = Now -- (sheltering lasts CalmSeconds past the last hit, as past the last combat sound)
	Halt(F)
	if not Down(F) then
		SetState(F, "Hurt")
		Chat(F, "Hurt")
		RunWhenFree(F, Attacker)
	end
	local From = PosOf(Attacker)
	for Id, O in pairs(Folk) do
		if O ~= F and O.Rig.Parent and O.Root.Parent and not Down(O)
			and (O.Root.Position - F.Root.Position).Magnitude <= TownsfolkService.HelpRadius then
			O.LastNoise = Now
			if Calm(O.State) then
				if TownsfolkService.Rng:NextNumber() < TownsfolkService.HelpChance then Chat(O, "Help") end
				local Ok, Err = pcall(Flee, O, From, true)
				if not Ok then WarnOnce("flee " .. Id, Id, "couldn't flee:", Err) end
			end
		end
	end
end

-- ProgressionService.HitListeners (inserted FIRST, in Start): a landed player hit on a townsperson
local function OnHit(Attacker, Victim, Result)
	if typeof(Victim) ~= "Instance" or Result ~= "Hit" then return end
	local Id = Victim:GetAttribute("TownsfolkId")
	local F = Id and Folk[Id]
	if not F or F.Rig ~= Victim or F.Dead then return end
	local Player = typeof(Attacker) == "Instance" and Players:GetPlayerFromCharacter(Attacker)
	if not Player then return end
	F.LastBy = {Player = Player, At = os.clock()}
	OnHurt(F, Attacker)
end
TownsfolkService.OnHit = OnHit -- (tests)

-- the Knocked attribute changed (DownedManager): knocked -> state Knocked; up again (left alone KnockedSeconds:
-- RecoverShare of their health) -> a Hurt line and a run for shelter, away from whoever did it. Deferred: a grip's
-- execution clears Knocked just before it sets Health to 0, so it must not read as getting up.
local function OnKnockedChanged(F)
	task.defer(function()
		if Folk[F.Id] ~= F or F.Dead or not F.Rig.Parent or F.Humanoid.Health <= 0 then return end
		if F.Rig:GetAttribute("Knocked") then
			F.HurtGen = (F.HurtGen or 0) + 1
			F.LastNoise = os.clock()
			Halt(F)
			SetState(F, "Knocked")
		elseif F.State == "Knocked" then
			F.LastNoise = os.clock()
			SetState(F, "Hurt")
			Chat(F, "Hurt")
			local By = F.LastBy and F.LastBy.Player
			RunWhenFree(F, By and By.Character)
		end
	end)
end

-- a player took hold of them for a grip (the GrippedBy attribute is the gripper's character name)
local function OnGripped(F)
	local Name = F.Rig:GetAttribute("GrippedBy")
	local P = Name and Players:FindFirstChild(Name)
	if P and P:IsA("Player") and P.Character and P.Character.Name == Name then F.LastBy = {Player = P, At = os.clock()} end
end

local function Remove(F) -- (the rig and its state; Despawn also forgets a death)
	if Folk[F.Id] == F then Folk[F.Id] = nil end
	LastLines[F.Id] = nil
	F.HurtGen = (F.HurtGen or 0) + 1
	if F.Walk then F.Walk:Cancel() F.Walk = nil end
	if F.WC then pcall(function() F.WC:Destroy() end) F.WC = nil end
	if F.Rig.Parent then F.Rig:Destroy() end
end

-- died (an execution, or killed outright): nothing walks or places the body; the killer's murder; the body lies
-- BodySeconds; a newcomer at the next NewcomerHour
local function OnDied(F)
	if F.Dead or Folk[F.Id] ~= F then return end
	F.Dead = true
	F.HurtGen = (F.HurtGen or 0) + 1
	Halt(F) -- (the body falls where it is: an anchored one, at a post or hiding, is let go)
	SetState(F, "Dead")
	Dead[F.Id] = {Def = F.Def, Region = F.Region}
	local By = F.LastBy
	if By and os.clock() - By.At <= TownsfolkService.KillerSeconds and By.Player.Parent == Players then
		F.Killer = By.Player
		local Ok, Err = pcall(function()
			require(ServerScriptService.MoralityService).Record(By.Player, "murder_townsfolk", false, {Witness = true, Region = F.Region})
		end)
		if not Ok then warn("TownsfolkService: couldn't record the murder of", F.Id, Err) end
	end
	task.delay(TownsfolkService.BodySeconds, function()
		if Folk[F.Id] == F then Remove(F) end
	end)
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
	-- Task 6b: hittable, knocked at 0 like an enemy (no Health script: no regeneration)
	Humanoid.MaxHealth = TownsfolkService.MaxHealth
	Humanoid.Health = TownsfolkService.MaxHealth
	Humanoid.BreakJointsOnDeath = false -- (the body lies whole, as an enemy's does)
	Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false) -- (a hit never trips them; WorldService does
	Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false) -- the same for every NPC it watches)
	Rig:SetAttribute("Knockable", true)
	Rig:SetAttribute("KnockedTime", TownsfolkService.KnockedSeconds) -- (DownedManager: this one's knock length...)
	Rig:SetAttribute("RecoverHealth", TownsfolkService.RecoverShare) -- (...and the health they get up with)
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

-- (Task 6b; tests) the townsperson's current definition (a newcomer's carries its own Name and Look), and the shelter
-- post it is running to or hiding at
function TownsfolkService.Def(Id)
	local F = Folk[Id]
	return F and F.Def or (Dead[Id] and Dead[Id].Def) or nil
end
-- (Task 4b fix round 1; tests) a failed walk's retry: RetryAt (os.clock), failures in a row on that post, the delay
-- used for the last retry
function TownsfolkService.Retry(Id)
	local F = Folk[Id]
	if not F then return nil, 0, nil end
	return F.RetryAt, F.Fails or 0, F.RetryDelay
end
function TownsfolkService.ShelterOf(Id)
	local F = Folk[Id]
	return F and F.Shelter or nil
end

-- removes the townsperson (and forgets a death: no newcomer for that slot)
function TownsfolkService.Despawn(Id)
	Dead[Id] = nil
	local F = Folk[Id]
	if F then Remove(F) end
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
		F.HurtGen = (F.HurtGen or 0) + 1
		if F.Walk then F.Walk:Cancel() end
		if F.WC then pcall(function() F.WC:Destroy() end) F.WC = nil end
	end)
	-- Task 6b: hittable (a WCS character), knocked / got up, gripped, died
	EnsureCombat(F)
	Rig:GetAttributeChangedSignal("Knocked"):Connect(function() OnKnockedChanged(F) end)
	Rig:GetAttributeChangedSignal("GrippedBy"):Connect(function() OnGripped(F) end)
	local function Died()
		local Ok, Err = pcall(OnDied, F)
		if not Ok then warn("TownsfolkService: death of", F.Id, "failed:", Err) end
	end
	Humanoid.Died:Once(Died)
	-- (a Humanoid whose root is anchored -- at a post, hiding -- doesn't run its state machine, so Died never fires
	-- for it: health reaching 0 is the death)
	Humanoid.HealthChanged:Connect(function(Health) if Health <= 0 and not F.Dead then Died() end end)
	return Rig
end

-- is a player within Radius of Pos?
local function PlayerNear(Pos, Radius)
	for _, P in ipairs(Players:GetPlayers()) do
		local R = P.Character and P.Character:FindFirstChild("HumanoidRootPart")
		if R and (R.Position - Pos).Magnitude <= Radius then return true end
	end
	return false
end

-- Task 6b: every dead townsperson's slot gets a newcomer (WorldClock.Changed at NewcomerHour; tests call it): the same
-- Id, job, faction, nation and schedule, a new Name nobody alive in the region has and a new look seed. Fix round 1:
-- nobody sees one appear -- with a player within PlaceRadius of the post it starts at (or of the old body), that
-- newcomer is due but waits (Dead[Id] kept, Due set), and Step tries again (OnlyDue) once nobody is near. Returns how
-- many came and how many are waiting.
function TownsfolkService.Newcomers(OnlyDue)
	local Came, Waiting = 0, 0
	local Ids = {}
	for Id, D in pairs(Dead) do
		if not OnlyDue or D.Due then table.insert(Ids, Id) end
	end
	table.sort(Ids)
	for _, Id in ipairs(Ids) do
		local D = Dead[Id]
		if not D then continue end -- (another pass already brought this one)
		local Old = D.Def
		D.Due = true
		local Post = Posts[TownsfolkLogic.PostAt(Old.Schedule, WorldClock.Now()) or ""]
		local Body = Folk[Id] and Folk[Id].Rig.Parent and Folk[Id].Root
		local Radius = TownsfolkService.PlaceRadius
		if (Post and PlayerNear(Post.Position, Radius)) or (Body and PlayerNear(Body.Position, Radius)) then
			Waiting += 1
			continue
		end
		local Taken = {[Old.Name or ""] = true}
		for _, O in pairs(Folk) do
			if O.Region == D.Region and not O.Dead and O.Def.Name then Taken[O.Def.Name] = true end
		end
		local Nation = type(Old.Look) == "table" and Old.Look.Nation or nil
		local New = table.clone(Old)
		New.Name = TownsfolkLogic.NewcomerName(Nation, Taken, TownsfolkService.Rng)
			or ("New " .. tostring(Old.Job or "townsperson")) -- (every name in the nation's list is taken)
		New.Look = table.clone(type(Old.Look) == "table" and Old.Look or {})
		New.Look.Seed = TownsfolkService.Rng:NextInteger(1, 2 ^ 30)
		New.Newcomer = true
		local Ok, Err = pcall(TownsfolkService.Spawn, New, D.Region) -- (Spawn clears the death and removes the body)
		if Ok then
			Came += 1
		else
			D.Due = nil -- (tried again at the next NewcomerHour, not every Step)
			WarnOnce("newcomer " .. Id .. tostring(Err), "no newcomer for", Id, Err)
		end
	end
	return Came, Waiting
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

local NewcomersBusy = false -- (a due-newcomer pass from Step is running)
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
		-- Task 6b: the dead lie where they fell; the hurt and the knocked are the combat code's (and RunWhenFree's)
		if F.Dead or F.State == "Dead" then return end
		if F.Humanoid.Health <= 0 then OnDied(F) return end -- (a death no signal reported)
		if not F.WC then EnsureCombat(F) end
		if F.State == "Hurt" or F.State == "Knocked" or Down(F) then return end
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
				-- a failed walk, held: try again (or place it, once nobody is within SleepRadius: Task 4b)
				if os.clock() >= F.RetryAt then
					if PlayerWithin(F, F.Target, TownsfolkService.SleepRadius) then
						Walk(F, F.Target)
					else
						F.Fails = 0 -- (fix round 1: placed, the backoff starts over)
						Settle(F, F.Target, "AtPost")
					end
				end
			elseif F.Target and Posts[F.Target] and PlayerWithin(F, F.Target, TownsfolkService.SleepRadius) then
				-- watchdog: "Walking" with no live walk (it ended without settling) and a player near (Task 6b: nobody
				-- may see a teleport, the same gate as a failed walk; Task 4b: SleepRadius) -> walk on to the post
				WarnOnce("watchdog " .. Id, Id, "was Walking with no walk in progress - walking on to", F.Target)
				Walk(F, F.Target)
			else
				-- ...with nobody near -> settle at that post
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
	-- (fix round 1) newcomers who were due while a player was watching their post
	for _, D in pairs(Dead) do
		if D.Due then
			if not NewcomersBusy then
				NewcomersBusy = true
				task.spawn(function() -- (in its own thread: Step never yields, a spawn may)
					local Ok, Err = pcall(TownsfolkService.Newcomers, true)
					NewcomersBusy = false
					if not Ok then WarnOnce("newcomers", "newcomers failed:", Err) end
				end)
			end
			break
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
	require(ServerScriptService.NoiseService).Listen(OnNoise)
	-- Task 6b: a landed player hit on a townsperson. FIRST in the list (the listeners run in order), so the hurt one
	-- and its neighbours are already reacting when NoiseService's listener sounds the "Hit" (OnNoise then only keeps
	-- them hiding). Newcomers at NewcomerHour.
	table.insert(require(ServerScriptService.ProgressionService).HitListeners, 1, function(...)
		local Ok, Err = pcall(OnHit, ...)
		if not Ok then warn("TownsfolkService: hit:", Err) end
	end)
	WorldClock.Changed.Event:Connect(function(Hour)
		if Hour ~= TownsfolkService.NewcomerHour then return end
		local Ok, Err = pcall(TownsfolkService.Newcomers)
		if not Ok then warn("TownsfolkService: newcomers:", Err) end
	end)
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

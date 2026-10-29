-- DownedManager: knocked state, Grip (B) and Carry (V). Numbers: TuningConfig.Downed (PROPOSALS).
--
-- * All combat damage goes through DownedManager.Damage. A hit that would bring a knockable
--   character (any player; an enemy with attribute Knockable) to 0 leaves them at 1 HP and
--   KNOCKED instead: slumped, stunned, immune to further damage; a knocked PLAYER can only crawl (see CRAWL), anyone
--   else can't move.
-- * After KnockedTime they recover with RecoverHealth of max health. Knock(Victim, Seconds) (assassinations Task 6):
--   Seconds, when it is a positive number, is this knock's length and wins over the KnockedTime attribute and
--   TuningConfig.Downed.KnockedTime (the takedown's knockout passes Rensei.Takedown.KnockoutSeconds); every other call
--   passes none. Second Wind (a player's keystone) still shortens it to 12 s.
-- * GRIP (B): finish a knocked target in range over GripTime. Getting stunned cancels it; completing it
--   kills the target (an ordinary death -- PvP / permadeath consequences are not decided yet).
--   Grip styles (owner 2026-10-15: "add different grips"; PROPOSAL): with a weapon drawn, an
--   EXECUTION with that weapon's heavy (or the weapon's own grip pair, TuningConfig.Downed.Grips); unarmed, always
--   the paired CLASSIC grip (both share a root, as the animations were authored; hotfix 2026-10-23). The STOMP
--   (down-slam) is only reached through the attribute GripStyle on the gripper, which forces a style (tests).
--   After a grip the gripper gets back exactly what it had: walk speed / jump, which parts were
--   massless (hair, accessories, the weapon), and it steps clear of the body instead of being
--   released inside it.
-- * CARRY (V): pick up a knocked target, welded over the carrier's LEFT shoulder (its root at
--   TuningConfig.Downed.CarryOffset in the carrier's root space, 2026-10-27, for the owner's Carry / Carried
--   animations; grips keep the shared root). The carrier walks at CarryWalkSpeed; V again, attacking, getting
--   stunned or the target recovering drops them.
--   Assassinations Task 6 (owner 2026-10-27, "Yes, carry bodies"; pre-flight R6): V also picks up a takedown's dead
--   body (IsTakedownBody: dead, TakenDownBy set, still in the world), carried and set down like a knocked one; its
--   despawn timer keeps running and it stays a body to PerceptionService. Only Carry's lookup takes bodies
--   (Nearest's Opts.Bodies); Grip never does. A carry holds its exact body: removed while held (a corpse's 120 s, a
--   despawn), it is dropped at once and its weld goes with it; nothing is ever looked up by name in its place.
--   Lock, Attach (with the caller's own offset) and Detach are shared with TakedownService (pre-flight R16 / D3).
--   A body something else has welded (Welds) is never taken (Task 6 review). (Assassinations final fix F2) A player
--   taking someone down (attribute TakingDown) can't grip or carry; IsLocked(Model) tells whether a lock entry is held
--   (F7: a gripper removed mid-grip leaves none).
-- * RAGDOLL (assassinations Task 6b, owner 2026-10-27): a finished grip makes the body a ragdoll (Modules.Managers.Ragdoll,
--   Apply, just before Health 0) -- enemies, townsfolk and players gripped by players. Carry lets a ragdolled body go
--   (Ragdoll.Hold: unanchored, held by the carrier; its limbs hang from it) and Drop sets it down limp to settle again.
-- * FINISH (assassinations Task 7, owner 2026-10-27: "gripped bandit bodies should stay 120 seconds like takedown
--   bodies", "Gripped bodies can be used as clues too"): Finish(Target, Killer, Info) is the one way a finisher kills --
--   a finished grip and TakedownService's assassination. An NPC's body is marked FinishedBy (the killer's name) BEFORE
--   its health hits 0, so EnemyService's Died handler keeps it Takedown.BodySeconds (120 s) instead of 4; it ragdolls
--   (Ragdoll.Apply, before the death); and it is registered with PerceptionService as a "Dead" body (By = the killer's
--   Player, nil for an NPC killer; Info's fields added), so a patrol that finds it searches there. A player's body is
--   neither marked nor registered. (Townsfolk keep TownsfolkService.BodySeconds, 60 s.)
-- * HOSTAGES (hostages plan Task 4): Holding / HeldBy are a hold like Gripping / GrippedBy: Free, Takeable and CanCrawl
--   refuse them; EndKnock(Victim, MinShare) ends a knock without Recover's heal (HostageService binds a knocked player at
--   their own HP, at least MinShare). The knock's timer (Recover) waits for a bind in progress (HeldBy), as for a grip.
-- Attributes (server-written): Knocked, KnockedUntil, GrippedBy, Gripping, CarriedBy, Carrying. Read: Holding, HeldBy
-- (HostageService writes them).
-- * CRAWL (owner 2026-10-27: "Yes, slow crawl"): a knocked PLAYER crawls at TuningConfig.Downed.CrawlSpeed (PROPOSAL
--   3) instead of lying still; knocked enemies and townsfolk (the assassinations' knockout too) keep WalkSpeed 0, and
--   nobody crawls while gripped, carried or in deep water. KnockedSpeed(Model) is the rule (shared, so MoverManager
--   hands it back after a movement change); the server keeps it with a watch while the knock lasts. Everything else
--   a knock blocks stays blocked (no jump, attack, skill, alchemy, sprint, dash, climb, swim, grip or carry). The
--   client shows Downed Idle (the Knocked slot) still and Downed Crawl (the DownedCrawl slot) moving: AnimationManager.
--   Fix round 1 (2026-10-27): attribute KnockedStill (server-written) = the server holds this knocked player at 0
--   (gripped, carried, deep water), so KnockedSpeed reads 0 on the client too (MoverManager, Crouch). And the watch
--   clamps the crawl's distance (ClampCrawl): a knocked player's root that moved further across the ground than a
--   crawl could is put back at the last allowed point. A script that moves a player's character on purpose calls
--   RebaseCrawl(Model) afterwards (fix round 2: Drop, StationService, RoadService, TravelService, AdminService), which
--   pins that point to the server's spot (fix round 3). The knock's own first CrawlClampGrace seconds are pinned at
--   the knock point too, with a momentum allowance (assassinations Task 6).
-- Per-character knock (Region Foundation Task 6b; townsfolk set them): attributes KnockedTime (s) and
-- RecoverHealth (share of max health) replace TuningConfig.Downed's KnockedTime / RecoverHealth for that one.
-- Listeners (server): functions called ("Grip", Gripper, Target) after a grip finishes someone
-- (MoralityService records the deed).
-- Live characters (Task 6b): the knocked / grip / carry lookups see World.Live's Model children AND the Models in
-- its Folder children (townsfolk live in World.Live.Townsfolk). LiveModels() lists them; LiveModel(Part) is the
-- character a part belongs to (AlchemyService's hit resolution uses it too).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)

local IsServer = RunService:IsServer()
local Cfg = Tuning.Downed

local DownedManager = {}
DownedManager.Listeners = {}

function DownedManager.IsKnocked(Model)
	return Model ~= nil and Model:GetAttribute("Knocked") == true
end

function DownedManager.Knockable(Model)
	return Players:GetPlayerFromCharacter(Model) ~= nil or Model:GetAttribute("Knockable") == true
end

-- the downed crawl (owner 2026-10-27): only a knocked player who is neither gripped nor carried may crawl; (hostages
-- Task 4) nor held as a hostage (HeldBy), so a player being bound stops crawling at once
function DownedManager.CanCrawl(Model)
	return Model ~= nil and DownedManager.IsKnocked(Model) and Players:GetPlayerFromCharacter(Model) ~= nil
		and not Model:GetAttribute("GrippedBy") and not Model:GetAttribute("CarriedBy") and not Model:GetAttribute("HeldBy")
end

-- the walk speed a knocked character has: CrawlSpeed (PROPOSAL) for a player who may crawl, else 0; 0 too while the
-- server holds them still (attribute KnockedStill: deep water, gripped, carried), on the client as on the server
function DownedManager.KnockedSpeed(Model)
	if not DownedManager.CanCrawl(Model) or Model:GetAttribute("KnockedStill") then return 0 end
	return Cfg.CrawlSpeed or 0
end

local function LiveFolder()
	local World = workspace:FindFirstChild("World")
	return World and World:FindFirstChild("Live")
end

-- the character models in World.Live: its Model children, then the Models inside its Folder children (a
-- townsperson in World.Live.Townsfolk, Region Foundation Task 6b)
function DownedManager.LiveModels()
	local Out = {}
	local Live = LiveFolder()
	if not Live then return Out end
	local Folders = {}
	for _, M in ipairs(Live:GetChildren()) do
		if M:IsA("Model") then table.insert(Out, M) elseif M:IsA("Folder") then table.insert(Folders, M) end
	end
	for _, F in ipairs(Folders) do
		for _, M in ipairs(F:GetChildren()) do
			if M:IsA("Model") then table.insert(Out, M) end
		end
	end
	return Out
end

-- the character a part in World.Live belongs to: its ancestor that is a direct child of World.Live, or of a Folder
-- directly in World.Live (a townsperson). nil for anything outside World.Live. (Before Task 6b the callers climbed
-- to the direct child of World.Live, which for a townsperson was the Townsfolk folder: no Humanoid, so no hit.)
function DownedManager.LiveModel(Inst)
	local Live = LiveFolder()
	if not Live or typeof(Inst) ~= "Instance" or not Inst:IsDescendantOf(Live) then return nil end
	local M = Inst
	while M.Parent ~= Live and not (M.Parent:IsA("Folder") and M.Parent.Parent == Live) do M = M.Parent end
	return M
end

if not IsServer then return DownedManager end

-- lazily required (they require this module)
local function Mods()
	local Managers = ReplicatedStorage.Modules.Managers
	return require(ReplicatedStorage.Modules.Framework.WCS), require(Managers.AnimationManager),
		require(ReplicatedStorage.Modules.Skills.States.Stun), require(Managers.AttackRunner)
end

-- Plain tables, emptied explicitly (a weak-keyed table can drop a live Instance key).
local KnockStun = {} -- [Model] = Stun status running for the knock
local Welds = {} -- [Model being gripped / carried] = Weld
local MasslessWas = {} -- [Model] = {[BasePart] = its Massless before Attach}
local LockedFrom = {} -- [Model] = {WalkSpeed, JumpHeight} before Lock
local DefaultWS = game:GetService("StarterPlayer").StarterCharacter.Humanoid.WalkSpeed
local DefaultJH = game:GetService("StarterPlayer").StarterCharacter.Humanoid.JumpHeight

local function Hum(Model) return Model and Model:FindFirstChildOfClass("Humanoid") end
local function Root(Model) return Model and Model:FindFirstChild("HumanoidRootPart") end
local function Alive(Model) local H = Hum(Model) return H ~= nil and Model.Parent ~= nil and H.Health > 0 end

local function Lock(Model, On, WalkSpeed)
	local H = Hum(Model)
	if not H then
		-- (hostages final fix round, parked T5) a character with no Humanoid left (destroyed) has nothing to give back,
		-- but its lock entry still goes, so none is left behind
		if not On then LockedFrom[Model] = nil end
		return
	end
	if On then
		LockedFrom[Model] = LockedFrom[Model] or {H.WalkSpeed, H.JumpHeight}
		H.WalkSpeed = WalkSpeed or 0
		H.JumpHeight = 0
	else
		-- what it had before the lock (a drawn weapon / buff speed survives a grip or carry)
		local Was = LockedFrom[Model]
		LockedFrom[Model] = nil
		local Speed = Model:GetAttribute("EnemyType") and Tuning.Enemies[Model:GetAttribute("EnemyType")].WalkSpeed
			or DefaultWS * (Model:GetAttribute("SpeedMultiplier") or 1)
		H.WalkSpeed = Was and Was[1] > 0 and Was[1] or Speed
		H.JumpHeight = Was and Was[2] > 0 and Was[2] or DefaultJH
	end
end

local function OwnerOf(Model)
	return Players:GetPlayerFromCharacter(Model)
end

-- deep water (SwimService's own test, and the Humanoid's Swimming state): a knocked body there is not swimming
-- (MovementState refuses Swim while knocked) and must not paddle across at crawl speed, so it floats still as before
local function InDeepWater(Model)
	local H = Hum(Model)
	if H and H:GetState() == Enum.HumanoidStateType.Swimming then return true end
	local S = game:GetService("ServerScriptService"):FindFirstChild("SwimService")
	if not S then return false end
	local Ok, Deep = pcall(function() return require(S).InDeepWater(Model) end)
	return Ok and Deep == true
end

-- the knocked character's walk speed now (KnockedSpeed, 0 in deep water) with no jump. Called at the knock, when a
-- grip or carry starts or ends, and by the knock's watch every CrawlCheck seconds (it also undoes any other writer).
local function SetKnockedSpeed(Model)
	local H = Hum(Model)
	if not H or not DownedManager.IsKnocked(Model) then return end
	local Want = DownedManager.CanCrawl(Model) and (Cfg.CrawlSpeed or 0) or 0
	if Want > 0 and InDeepWater(Model) then Want = 0 end
	-- (players only: an enemy's KnockedSpeed is 0 anyway)
	local Still = OwnerOf(Model) ~= nil and Want == 0 or nil
	if Model:GetAttribute("KnockedStill") ~= Still then Model:SetAttribute("KnockedStill", Still) end
	if H.WalkSpeed ~= Want then H.WalkSpeed = Want end
	if H.JumpHeight ~= 0 then H.JumpHeight = 0 end
end
DownedManager.SetKnockedSpeed = SetKnockedSpeed

-- The crawl's distance clamp (fix rounds 1 and 2, 2026-10-27), run by the knock's watch. A knocked player's root may
-- travel across the ground (x / z) at most (CrawlSpeed x CrawlClampMult + CrawlClampSlack) studs per second since the
-- last allowed point, the time capped at CrawlClampWindow: with the PROPOSAL numbers 3 x 1.5 + 2.5 = 7 studs/s over at
-- most 1 s (a hitch). Further, the root is put back AT the last allowed point (its full position, so it never ends up
-- inside geometry or mid-air). Not clamped (the point just follows): a grounded / anchored assembly (a script holds
-- it), a root welded into another assembly (a latch, a grip or carry weld), PlatformStand, a seat, GrippedBy /
-- CarriedBy. Every deliberate server move of a player's character calls RebaseCrawl (StationService, RoadService,
-- TravelService, AdminService, Drop), which pins the last allowed point to the server's own spot right after the move
-- (fix round 3: it used to follow the client for a grace, so a rebase could be ridden anywhere). For CrawlClampGrace
-- seconds after a rebase a snap back to that spot is not counted in CrawlClamped: it is the owning client's stale echo
-- of where it was before the move (seen when a carry is set down).
-- The knock's own grace (assassinations Task 6; it used to follow the client, one free reposition per knock): for the
-- first CrawlClampGrace seconds the point is PINNED at the knock point. The body may still be carried by what it was
-- doing (a sprint, a dash, the hit's knockback), so the whole way since the knock may be KnockMomentum x (the time since
-- it + one CrawlCheck tick) + CrawlClampSlack (Task 6 review: a hitch's slack); farther, it is put back at the knock
-- point (counted). An unclamped tick (carried, welded, seated) inside the grace keeps the pin. Once the grace is over, the crawl's clamp goes on from
-- wherever the momentum left it.
-- Weak-keyed (Task 6): a test that sets Knocked directly (no Knock, so no watch to forget them) and calls RebaseCrawl
-- leaves nothing behind. While a knock lasts, its watch holds the character (an upvalue), so the entry stays.
local ClampFrom = setmetatable({}, {__mode = "k"}) -- [Model] = {Pos = Vector3, T = os.clock(), Pin = the knock's grace}
local RebasedAt = setmetatable({}, {__mode = "k"}) -- [Model] = os.clock() of the last RebaseCrawl (knocked players only)
local WatchToken = {} -- [Model] = the running knock watch's token (a re-knock's old watch clears nothing of the new one)
-- the knock's momentum allowance (Task 6, PROPOSAL): the game's fastest legitimate speed, the dash's peak
-- (TuningConfig.Dash.MaxSpeed 110 studs/s), above the dash attack's lunge (DashAttack.Lunge 65) and the speedy sprint
-- (Locomotion.Design.SpeedyRun 30; ClientHandler.Run sprints at 24 / 30). DamageManager's default hit knockback (75) is
-- below it too.
local KnockMomentum = math.max((Tuning.Dash or {}).MaxSpeed or 0, (Tuning.DashAttack or {}).Lunge or 0,
	((Tuning.Locomotion or {}).Design or {}).SpeedyRun or 0)
local function Unclamped(Victim, R)
	local H = Hum(Victim)
	return R:IsGrounded() or R.AssemblyRootPart ~= R or (H ~= nil and (H.PlatformStand or H.SeatPart ~= nil))
		or Victim:GetAttribute("GrippedBy") ~= nil or Victim:GetAttribute("CarriedBy") ~= nil
end
local function ClampCrawl(Victim)
	local R = Root(Victim)
	if not R then return end
	local Now = os.clock()
	local C = ClampFrom[Victim]
	if not C or Unclamped(Victim, R) then
		-- (Task 6 review) an unclamped tick inside the knock's grace keeps the pin and the knock's time: the point follows,
		-- but the grace still ends CrawlClampGrace after the knock and its momentum allowance still applies
		local Keep = C ~= nil and C.Pin == true and Now - C.T < (Cfg.CrawlClampGrace or 0.5)
		ClampFrom[Victim] = Keep and {Pos = R.Position, T = C.T, Pin = true} or {Pos = R.Position, T = Now}
		return
	end
	local D = Vector3.new(R.Position.X - C.Pos.X, 0, R.Position.Z - C.Pos.Z).Magnitude
	if C.Pin then
		local Since = Now - C.T
		-- (Task 6 review) with a hitch's slack: one watch tick late (CrawlCheck) plus the crawl clamp's CrawlClampSlack
		if D > KnockMomentum * (Since + (Cfg.CrawlCheck or 0.1)) + (Cfg.CrawlClampSlack or 2.5) then
			-- further than any momentum could carry it: back at the knock point (the pin stays)
			R.CFrame += C.Pos - R.Position
			R.AssemblyLinearVelocity = Vector3.zero
			Victim:SetAttribute("CrawlClamped", (Victim:GetAttribute("CrawlClamped") or 0) + 1)
		elseif Since >= (Cfg.CrawlClampGrace or 0.5) then
			ClampFrom[Victim] = {Pos = R.Position, T = Now} -- the momentum is spent: the crawl's clamp from here
		end
		return
	end
	if D < 0.05 then return end -- (still: the window keeps growing, up to its cap)
	local Dt = math.min(Now - C.T, Cfg.CrawlClampWindow or 1)
	local Max = ((Cfg.CrawlSpeed or 0) * (Cfg.CrawlClampMult or 1.5) + (Cfg.CrawlClampSlack or 2.5)) * Dt
	if D > Max then
		R.CFrame += C.Pos - R.Position
		R.AssemblyLinearVelocity = Vector3.zero
		C.T = Now
		-- (a counter for tests; a snap inside a rebase's grace is the client's stale echo, not counted)
		if Now - (RebasedAt[Victim] or -math.huge) >= (Cfg.CrawlClampGrace or 0.5) then
			Victim:SetAttribute("CrawlClamped", (Victim:GetAttribute("CrawlClamped") or 0) + 1)
		end
	else
		C.Pos, C.T = R.Position, Now
	end
end
-- a script moved a player's character on purpose: a knocked player's clamp starts again from the server's own spot right
-- after the move. Players only (knocked NPCs have no watch, so nothing is kept for them); call it AFTER the move.
function DownedManager.RebaseCrawl(Model)
	if not Model or not OwnerOf(Model) or not DownedManager.IsKnocked(Model) then return end
	local R = Root(Model)
	if not R then return end
	ClampFrom[Model] = {Pos = R.Position, T = os.clock()}
	RebasedAt[Model] = os.clock()
end

-- (hostages Task 10 fix round 1, review m4) THE call for a deliberate server move of a player's character (server only;
-- call it AFTER the move): the knocked crawl's clamp (RebaseCrawl) and, when the character is either side of a led
-- hostage pair, that pair's lead clamp (HostageService.Rebase; Task 6 re-review m7: else the move ends the hold as a
-- blink and leaves the hostage at the last lead) start again from the new spot. StationService, RoadService,
-- TravelService and AdminService call it (it replaces their four copied Rebased helpers). Each half runs in its own
-- pcall and warns if it fails; HostageService is optional (a place without it skips that half).
function DownedManager.MovedOnPurpose(Model)
	if not Model or not IsServer then return end
	local Ok, Err = pcall(DownedManager.RebaseCrawl, Model)
	if not Ok then warn("DownedManager.MovedOnPurpose: RebaseCrawl failed:", Err) end
	local HS = game:GetService("ServerScriptService"):FindFirstChild("HostageService")
	if HS then
		local HOk, HErr = pcall(function() require(HS).Rebase(Model) end)
		if not HOk then warn("DownedManager.MovedOnPurpose: HostageService.Rebase failed:", HErr) end
	end
end

-- weld Target's root onto Holder's root (shared root, as the grip animations expect). Offset (a carry only:
-- TuningConfig.Downed.CarryOffset) moves the Target's root in the Holder's root space: the Carried animation (owner's id,
-- 2026-10-27) lays the body across a shoulder line through the shared root, which buried the carrier's head in it; the
-- offset puts it over the carrier's LEFT shoulder, where the Carry animation's raised left arm holds the legs.
local function Attach(Holder, Target, Offset)
	local HR, TR = Root(Holder), Root(Target)
	if not HR or not TR then return false end
	Offset = typeof(Offset) == "CFrame" and Offset or CFrame.identity
	TR.CFrame = HR.CFrame * Offset
	local W = Instance.new("Weld")
	W.Name = "DownedWeld"
	W.C0 = Offset
	W.Part0 = HR
	W.Part1 = TR
	W.Parent = HR
	Welds[Target] = W
	local Was = {}
	for _, P in ipairs(Target:GetDescendants()) do
		if P:IsA("BasePart") then Was[P] = P.Massless P.Massless = true end
	end
	MasslessWas[Target] = Was
	local H = Hum(Target)
	if H then H.PlatformStand = true end
	-- one physics owner for the joined pair: the holder's client (or the server for NPCs)
	pcall(function() TR:SetNetworkOwner(OwnerOf(Holder)) end)
	return true
end

local function Detach(Target)
	local W = Welds[Target]
	Welds[Target] = nil
	if W then W:Destroy() end
	local Was = MasslessWas[Target] or {}
	MasslessWas[Target] = nil
	if not Target.Parent then return end
	-- each part back to what it was (hair, accessories and weapons stay massless)
	for _, P in ipairs(Target:GetDescendants()) do
		if P:IsA("BasePart") then
			if Was[P] ~= nil then P.Massless = Was[P] elseif P.Name ~= "HumanoidRootPart" then P.Massless = false end
		end
	end
	local H = Hum(Target)
	if H then H.PlatformStand = false end
	local TR = Root(Target)
	if TR then pcall(function() TR:SetNetworkOwner(OwnerOf(Target)) end) end
end

-- shared with TakedownService (pre-flight R16 / D3): the same lock, weld and release, never copied. Attach's Offset is
-- the caller's own (a takedown passes its own; only Carry passes CarryOffset).
DownedManager.Lock = Lock
DownedManager.Attach = Attach
DownedManager.Detach = Detach
-- (assassinations final fix F7) is a lock's entry held for this character (tests: none is left behind)
function DownedManager.IsLocked(Model) return LockedFrom[Model] ~= nil end

-- (Task 6b) the shared ragdoll (Modules.Managers.Ragdoll), required on first use. Without it (a place it hasn't reached)
-- the body lies whole as before, with one warning; (Task 6b review, Task 7) an error inside it always warns.
local RagdollMissingWarned = false
local function RagdollDo(Fn, ...)
	local M = ReplicatedStorage.Modules.Managers:FindFirstChild("Ragdoll")
	if not M then
		if not RagdollMissingWarned then
			RagdollMissingWarned = true
			warn("DownedManager: no Modules.Managers.Ragdoll here; bodies lie whole")
		end
		return
	end
	local Ok, Err = pcall(function(...) return require(M)[Fn](...) end, ...)
	if not Ok then warn("DownedManager: Ragdoll." .. Fn .. " failed:", Err) end
end

-- (Task 7) a finisher's kill: see FINISH in the header. Killer: the character that finished it (or nil). Info (optional):
-- extra fields for the body's PerceptionService entry (TakedownService: the deed, its witness strength, the faction).
function DownedManager.Finish(Target, Killer, Info)
	local H = Hum(Target)
	if not H then return end
	local IsNpc = OwnerOf(Target) == nil
	if IsNpc then Target:SetAttribute("FinishedBy", Killer and Killer.Name or "?") end -- (before the death: Died reads it)
	-- before the death, so a player's joints don't break apart (BreakJointsOnDeath) and an NPC never stands dead a frame
	RagdollDo("Apply", Target)
	H.Health = 0
	if not IsNpc then return end
	local PS = game:GetService("ServerScriptService"):FindFirstChild("PerceptionService")
	if not PS then return end
	local Body = {Kind = "Dead", By = Killer and OwnerOf(Killer) or nil}
	for K, V in pairs(Info or {}) do if Body[K] == nil then Body[K] = V end end
	local Ok, Err = pcall(function() require(PS).AddBody(Target, Body) end)
	if not Ok then warn("DownedManager: couldn't register the body:", Err) end
end

-- ===== Knock / recover =====
local Recover

function DownedManager.Knock(Victim, Seconds)
	if DownedManager.IsKnocked(Victim) or not Alive(Victim) then return end
	local WCS, AnimationManager, Stun = Mods()
	-- the knock's length: Seconds when it's a positive number (assassinations Task 6), else the character's own
	-- KnockedTime (townsfolk, Task 6b), else TuningConfig.Downed.KnockedTime
	local KnockedTime = (type(Seconds) == "number" and Seconds > 0 and Seconds < math.huge and Seconds)
		or tonumber(Victim:GetAttribute("KnockedTime")) or Cfg.KnockedTime
	-- Second Wind (skill tree keystone): once per life, a shorter knock and a stronger recovery
	local SkillMods = require(game:GetService("ReplicatedStorage").Modules.Managers.SkillMods)
	if SkillMods.Get(Victim, "SecondWind") > 0 and not Victim:GetAttribute("SecondWindUsed") then
		Victim:SetAttribute("SecondWindUsed", true)
		Victim:SetAttribute("SecondWindActive", true)
		KnockedTime = 12 -- PROPOSAL (spec: 12s instead of 20s)
	end
	Victim:SetAttribute("Knocked", true)
	Victim:SetAttribute("KnockedUntil", workspace:GetServerTimeNow() + KnockedTime)
	Victim:SetAttribute("CombatState", nil)
	Victim:SetAttribute("CombatAttack", nil)
	local WC = WCS.Character.GetCharacterFromInstance(Victim)
	if WC then
		for _, S in ipairs(WC:GetAllActiveStatusEffects()) do
			if S.Name == "Blocking" or S.Name == "PerfectParry" then pcall(function() S:Stop() end) end
		end
		local S = Stun.new(WC)
		S:Start(KnockedTime)
		if not KnockStun[Victim] then
			Victim.Destroying:Once(function()
				KnockStun[Victim] = nil
				-- (Task 6) a carry's weld sits on the CARRIER's root: destroy it, don't just forget it
				local W = Welds[Victim]
				Welds[Victim] = nil
				if W then W:Destroy() end
			end)
		end
		KnockStun[Victim] = S
	end
	Lock(Victim, true)
	SetKnockedSpeed(Victim) -- a player crawls (CrawlSpeed); anyone else stays at 0
	AnimationManager.StopAllAnims(Victim)
	AnimationManager.Play(Victim, "Knocked", {Looped = true, Priority = Enum.AnimationPriority.Action4})
	local Until = Victim:GetAttribute("KnockedUntil")
	task.delay(KnockedTime, function()
		if Victim:GetAttribute("KnockedUntil") == Until then Recover(Victim) end
	end)
	-- the crawl's watch (players only): keeps the speed rule for as long as this knock lasts
	if OwnerOf(Victim) then
		task.spawn(function()
			local Token = {}
			WatchToken[Victim] = Token
			-- (Task 6) the knock's grace is pinned at the knock point
			local R = Root(Victim)
			ClampFrom[Victim] = R and {Pos = R.Position, T = os.clock(), Pin = true} or nil
			RebasedAt[Victim] = nil
			Victim:SetAttribute("CrawlClamped", nil)
			while Victim.Parent and DownedManager.IsKnocked(Victim) and Victim:GetAttribute("KnockedUntil") == Until do
				SetKnockedSpeed(Victim)
				ClampCrawl(Victim)
				task.wait(Cfg.CrawlCheck or 0.1)
			end
			-- (fix round 3) only this knock's own state: a re-knock during the last wait has its own watch and token
			if WatchToken[Victim] == Token then
				WatchToken[Victim] = nil
				ClampFrom[Victim], RebasedAt[Victim] = nil, nil
				Victim:SetAttribute("CrawlClamped", nil)
				if not DownedManager.IsKnocked(Victim) then Victim:SetAttribute("KnockedStill", nil) end
			end
		end)
	end
end

-- (hostages Task 4) ends a knock, the victim keeping at least MinShare of max health (their own HP when it is more):
-- Recover's body with the share passed in. Refused (false) for a victim not knocked, dead, or gripped (a grip in progress
-- decides it). A carry is dropped first; Knocked, KnockedUntil and KnockedStill cleared; the knock's Stun stopped; the
-- walk lock given back; the Knocked animation stopped. HostageService binds a knocked player through it (no heal).
function DownedManager.EndKnock(Victim, MinShare)
	if not DownedManager.IsKnocked(Victim) or not Alive(Victim) then return false end
	if Victim:GetAttribute("GrippedBy") then return false end -- a grip in progress decides it
	local _, AnimationManager = Mods()
	local Carrier = Victim:GetAttribute("CarriedBy")
	if Carrier then DownedManager.Drop(DownedManager.Find(Carrier)) end
	Victim:SetAttribute("Knocked", nil)
	Victim:SetAttribute("KnockedUntil", nil)
	Victim:SetAttribute("KnockedStill", nil)
	local S = KnockStun[Victim]
	KnockStun[Victim] = nil
	if S then pcall(function() S:Stop() end) end
	Lock(Victim, false)
	AnimationManager.Stop(Victim, "Knocked")
	local H = Hum(Victim)
	H.Health = math.max(H.Health, H.MaxHealth * (tonumber(MinShare) or 0))
	return true
end

function Recover(Victim)
	if not DownedManager.IsKnocked(Victim) or not Alive(Victim) then return end
	if Victim:GetAttribute("GrippedBy") then return end -- a grip in progress decides it
	-- (hostages Task 4) so does a bind in progress: the binder ends the knock (EndKnock), or recovers one whose time ran
	-- out when the bind fails (HostageService's Release, as Grip does below)
	if Victim:GetAttribute("HeldBy") then return end
	local Share = Victim:GetAttribute("SecondWindActive") and 0.30 -- Second Wind (PROPOSAL 30%)
		or tonumber(Victim:GetAttribute("RecoverHealth")) or Cfg.RecoverHealth -- (per character: townsfolk, Task 6b)
	Victim:SetAttribute("SecondWindActive", nil)
	DownedManager.EndKnock(Victim, Share)
end
DownedManager.Recover = Recover

-- All combat damage comes through here.
function DownedManager.Damage(Victim, Amount)
	local H = Hum(Victim)
	-- trial armour / openings (TrialService): the victim's DamageTakenMult scales every hit
	local Mult = Victim:GetAttribute("DamageTakenMult")
	if type(Mult) == "number" and Mult >= 0 then Amount *= Mult end
	if not H or H.Health <= 0 or Amount <= 0 then return end
	if DownedManager.IsKnocked(Victim) then return end -- only a grip finishes a knocked target
	if Amount >= H.Health and DownedManager.Knockable(Victim) then
		H.Health = 1
		DownedManager.Knock(Victim)
	else
		H:TakeDamage(Amount)
	end
end

-- character model by name among the live characters (townsfolk included, Task 6b)
function DownedManager.Find(Name)
	if not Name then return nil end
	for _, M in ipairs(DownedManager.LiveModels()) do
		if M.Name == Name then return M end
	end
	return nil
end

-- the body this carrier is actually holding. Enemies share names ("Bandit Duelist"), so a name
-- lookup can return a different, healthy one; the CarriedBy link is exact. With that link gone (the body was
-- removed) there is none: no name fallback (assassinations Task 6, pre-flight R6).
function DownedManager.Carried(Carrier)
	local Name = Carrier and Carrier:GetAttribute("Carrying")
	if not Name then return nil end
	for _, M in ipairs(DownedManager.LiveModels()) do
		if M.Name == Name and M:GetAttribute("CarriedBy") == Carrier.Name then return M end
	end
	return nil
end

-- a takedown's dead body (assassinations, spec §18.1): a dead rig a takedown marked (TakenDownBy), still in the world.
-- Carry can take one; Grip never does.
function DownedManager.IsTakedownBody(Model)
	local H = Hum(Model)
	return H ~= nil and Model.Parent ~= nil and H.Health <= 0 and Model:GetAttribute("TakenDownBy") ~= nil
end

-- can a grip or a carry take M: knocked, alive and held by nobody (no hold attribute, no weld of ours); with Bodies (Carry only), a takedown's body too.
-- (hostages Task 4) a hostage (HeldBy) or a captor (Holding) is never taken: both ways, like a grip
local function Takeable(M, Bodies)
	if M:GetAttribute("GrippedBy") or M:GetAttribute("CarriedBy") then return false end
	if M:GetAttribute("HeldBy") or M:GetAttribute("Holding") then return false end
	if Welds[M] then return false end -- (Task 6 review) another holder's weld (a takedown's) is never overwritten
	return (DownedManager.IsKnocked(M) and Alive(M)) or (Bodies == true and DownedManager.IsTakedownBody(M))
end

-- nearest knocked, free target within Range of Actor. Opts.Bodies (Carry only): a takedown's dead body counts too.
function DownedManager.Nearest(Actor, Range, Opts)
	local AR = Root(Actor)
	if not AR then return nil end
	local Bodies = type(Opts) == "table" and Opts.Bodies == true
	local Best, BestD = nil, Range
	for _, M in ipairs(DownedManager.LiveModels()) do
		if M ~= Actor and Takeable(M, Bodies) then
			local R = Root(M)
			local D = R and (R.Position - AR.Position).Magnitude
			if D and D <= BestD then Best, BestD = M, D end
		end
	end
	return Best
end

-- (assassinations final fix F2, review I2) a player taking someone down (TakingDown, TakedownService) is busy too: a
-- grip would teleport them, victim and all, and a carry would stack a second hold on the takedown's. (Hostages Task 4)
-- So is a captor (Holding) and a hostage (HeldBy)
local function Free(Actor)
	local WCS, _, Stun, AttackRunner = Mods()
	local WC = WCS.Character.GetCharacterFromInstance(Actor)
	return Alive(Actor) and not DownedManager.IsKnocked(Actor) and not Actor:GetAttribute("Gripping")
		and not Actor:GetAttribute("Carrying") and not Actor:GetAttribute("TakingDown")
		and not Actor:GetAttribute("Holding") and not Actor:GetAttribute("HeldBy") and not AttackRunner.IsRunning(Actor)
		and not (WC and WC:HasStatusEffects({Stun}))
end

-- ===== Grip =====
-- Which finisher: an execution with a drawn weapon, else the classic paired grip or a stomp.
local function GripStyle(Gripper)
	local Forced = Gripper:GetAttribute("GripStyle")
	if Forced == "Classic" or Forced == "Stomp" or Forced == "Execution" or Forced == "Weapon" then return Forced end
	local Armed = Gripper:GetAttribute("Weapon") and (Gripper:GetAttribute("WeaponDrawn") or Gripper:GetAttribute("EnemyType"))
	-- the weapon's own grip pair from the sheet (TuningConfig.Downed.Grips), else its heavy as an execution
	if Armed then return Tuning.Downed.Grips[Gripper:GetAttribute("Weapon")] and "Weapon" or "Execution" end
	-- Hotfix 2026-10-23 (owner: "grip animations sometimes not activating"): unarmed grips used to roll Classic
	-- or Stomp 50/50, and the Stomp plays no grip animation (two fist downslams over a body that stays
	-- slumped), so about half the grips looked like the grip animation never started. Unarmed is now always
	-- the paired Classic grip; the Stomp stays available through the GripStyle attribute.
	return "Classic"
end

-- stand the gripper beside the body, facing it (the unpaired grips)
local function StandOver(Gripper, Target, Distance)
	local GR, TR = Root(Gripper), Root(Target)
	if not GR or not TR then return end
	local Away = Vector3.new(GR.Position.X - TR.Position.X, 0, GR.Position.Z - TR.Position.Z)
	Away = Away.Magnitude > 0.1 and Away.Unit or Vector3.new(0, 0, 1)
	local At = Vector3.new(TR.Position.X, GR.Position.Y, TR.Position.Z) + Away * Distance
	GR.CFrame = CFrame.lookAt(At, Vector3.new(TR.Position.X, At.Y, TR.Position.Z))
end

function DownedManager.Grip(Gripper, Target)
	-- Hotfix 2026-10-23: B pressed during the recovery of the hit that knocked the target was refused outright
	-- (the grip silently never started). A short attack recovery is waited out first (PROPOSAL 0.6s).
	local WaitUntil = os.clock() + 0.6
	while select(4, Mods()).IsRunning(Gripper) and os.clock() < WaitUntil do RunService.Heartbeat:Wait() end
	Target = Target or DownedManager.Nearest(Gripper, Cfg.GripRange)
	-- (Task 6) a target handed in is checked like a found one: knocked, alive, held by nobody (never a dead body)
	if not Target or Target == Gripper or not Takeable(Target, false) or not Free(Gripper) then return false end
	local WCS, AnimationManager, Stun = Mods()
	local WC = WCS.Character.GetCharacterFromInstance(Gripper)
	local Style = GripStyle(Gripper)
	Target:SetAttribute("GrippedBy", Gripper.Name)
	SetKnockedSpeed(Target) -- gripped: the crawl stops at once
	Gripper:SetAttribute("Gripping", Target.Name)
	Gripper:SetAttribute("GripStyleUsed", Style)
	-- the animation pair: bare-handed Classic = the Caestus (Fists) pair, Weapon = the weapon's (sheet, 2026-10-18)
	local Grips = Tuning.Downed.Grips
	local Pair = (Style == "Classic" and Grips.Fists) or (Style == "Weapon" and Grips[Gripper:GetAttribute("Weapon") or ""]) or nil
	if Style == "Weapon" and not Pair then Style = "Execution" end
	local Attached = Style == "Classic" or (Pair ~= nil and not Pair.Standing)
	if Attached then
		-- the gripper takes the target's root position (the grip animations were authored that way)
		if not Attach(Target, Gripper) then
			Target:SetAttribute("GrippedBy", nil)
			SetKnockedSpeed(Target)
			Gripper:SetAttribute("Gripping", nil)
			return false
		end
	else
		StandOver(Gripper, Target, Style == "Stomp" and 1.6 or 2.6)
	end
	Lock(Gripper, true)
	-- Executioner (skill tree): faster grips
	local GripTime = Cfg.GripTime / require(game:GetService("ReplicatedStorage").Modules.Managers.SkillMods).Mult(Gripper, "GripSpeed")
	if Pair then
		-- the pair plays at its length / the grip time, so it fills the grip
		local Speed = math.clamp(Pair.Length / GripTime, 0.6, 1.6)
		if Pair.Victim then
			AnimationManager.Stop(Target, "Knocked")
			AnimationManager.Play(Target, Pair.Victim, {Priority = Enum.AnimationPriority.Action4, Speed = Speed, Fallback = "Gripped"})
		end
		AnimationManager.Play(Gripper, Pair.Grip, {Priority = Enum.AnimationPriority.Action4, Speed = Speed, Fallback = "Gripping"})
	else
		-- the body stays slumped; the gripper finishes it standing
		local Weapon = Style == "Execution" and Tuning.Weapons[Gripper:GetAttribute("Weapon") or ""]
		local Anim = Style == "Stomp" and "FistDownslam" or (Weapon and Weapon.Heavy.Anim or "FistHeavy")
		task.spawn(function()
			-- one wind-up and strike per half of the grip, so the finisher reads as two blows
			for I = 1, 2 do
				if Gripper:GetAttribute("Gripping") ~= Target.Name then return end
				AnimationManager.Play(Gripper, Anim, {Priority = Enum.AnimationPriority.Action4, Fallback = "FistHeavy"})
				task.wait(Cfg.GripTime / 2)
			end
		end)
	end

	local Start, Done = os.clock(), false
	while os.clock() - Start < GripTime do
		RunService.Heartbeat:Wait()
		if not Alive(Gripper) or not Alive(Target) or (WC and WC:HasStatusEffects({Stun})) then break end
	end
	Done = os.clock() - Start >= GripTime and Alive(Gripper) and Alive(Target)

	if Attached then
		Detach(Gripper)
		-- step clear of the body (it was released inside the target's root before)
		if Gripper.Parent and Target.Parent then StandOver(Gripper, Target, 2.6) end
	end
	Gripper:SetAttribute("Gripping", nil)
	Target:SetAttribute("GrippedBy", nil)
	if not Done then SetKnockedSpeed(Target) end -- (a finished grip leaves the body at 0)
	if Gripper.Parent then
		Lock(Gripper, false)
		AnimationManager.Stop(Gripper, "Gripping")
		if Pair then AnimationManager.Stop(Gripper, Pair.Grip) end
	else
		LockedFrom[Gripper] = nil -- (assassinations final fix F7, review M6) a gripper gone mid-grip leaves no entry
	end
	if Pair and Pair.Victim and Target.Parent then AnimationManager.Stop(Target, Pair.Victim) end
	if Done then
		-- credit the gripper like a final hit, then finish
		local SSS = game:GetService("ServerScriptService")
		local PS = SSS:FindFirstChild("ProgressionService") and require(SSS.ProgressionService)
		if PS and PS.RecordHit then pcall(PS.RecordHit, Gripper, Target, "Hit") end
		Target:SetAttribute("Knocked", nil)
		Target:SetAttribute("KnockedStill", nil)
		KnockStun[Target] = nil
		-- (Task 6b, owner 2026-10-27) a gripped body ragdolls; (Task 7, owner) an NPC's stays 120 s and is a body (a clue)
		DownedManager.Finish(Target, Gripper)
		for _, Listener in ipairs(DownedManager.Listeners) do
			local Ok, Err = pcall(Listener, "Grip", Gripper, Target)
			if not Ok then warn("DownedManager grip listener failed:", Err) end
		end
	elseif Alive(Target) then
		AnimationManager.Stop(Target, "Gripped")
		AnimationManager.Play(Target, "Knocked", {Looped = true, Priority = Enum.AnimationPriority.Action4})
		if (Target:GetAttribute("KnockedUntil") or 0) <= workspace:GetServerTimeNow() then Recover(Target) end
	end
	return Done
end

-- ===== Carry =====
-- [Carrier] = {Target = the exact body held, Conns = its removal hooks} (Task 6: a removed body still has its weld on
-- the carrier, and a name lookup could find another rig). Plain, emptied by Drop.
local Held = {}

function DownedManager.Drop(Carrier)
	if not Carrier then return end
	local Hold = Held[Carrier]
	Held[Carrier] = nil
	if not Hold and not Carrier:GetAttribute("Carrying") then return end -- (not carrying: nothing to undo)
	if Hold then
		for _, Conn in ipairs(Hold.Conns) do Conn:Disconnect() end
	end
	-- the exact body held, even one already removed (its weld is still on the carrier); else the CarriedBy link
	local Target = Hold and Hold.Target or DownedManager.Carried(Carrier)
	Carrier:SetAttribute("Carrying", nil)
	local _, AnimationManager = Mods()
	if Carrier.Parent then
		Lock(Carrier, false)
		AnimationManager.Stop(Carrier, "Carrying")
	end
	if Target then
		Target:SetAttribute("CarriedBy", nil)
		Detach(Target) -- (the weld goes even when the body is gone)
		if not Target.Parent then return end
		SetKnockedSpeed(Target) -- set down: a knocked player may crawl again
		local CR, TR = Root(Carrier), Root(Target)
		if CR and TR then TR.CFrame = CR.CFrame * CFrame.new(0, 0, -2.5) end -- set down in front
		DownedManager.RebaseCrawl(Target)
		if Target:GetAttribute("Ragdolled") then
			-- (Task 6b) a ragdoll falls where it is set down, limp, and settles again (no pose)
			AnimationManager.Stop(Target, "Carried")
			RagdollDo("Hold", Target, false)
		elseif Alive(Target) and DownedManager.IsKnocked(Target) then
			AnimationManager.Stop(Target, "Carried")
			AnimationManager.Play(Target, "Knocked", {Looped = true, Priority = Enum.AnimationPriority.Action4})
			if (Target:GetAttribute("KnockedUntil") or 0) <= workspace:GetServerTimeNow() then Recover(Target) end
		elseif DownedManager.IsTakedownBody(Target) then
			-- a body lies as it lay before it was picked up (the Knocked pose)
			AnimationManager.Stop(Target, "Carried")
			AnimationManager.Play(Target, "Knocked", {Looped = true, Priority = Enum.AnimationPriority.Action4})
		end
	end
end

function DownedManager.Carry(Carrier, Target)
	Target = Target or DownedManager.Nearest(Carrier, Cfg.CarryRange, {Bodies = true})
	-- (Task 6) a target handed in is checked like a found one: knocked and alive, or a takedown's body; held by nobody
	if not Target or Target == Carrier or not Takeable(Target, true) or not Free(Carrier) then return false end
	local WCS, AnimationManager, Stun = Mods()
	-- (Task 6b) a ragdolled body is let go of first (a settled one is anchored where it lies) and held by the carrier
	local Limp = Target:GetAttribute("Ragdolled") == true
	if Limp then RagdollDo("Hold", Target, true, OwnerOf(Carrier)) end
	if not Attach(Carrier, Target, Cfg.CarryOffset) then
		if Limp then RagdollDo("Hold", Target, false) end
		return false
	end
	Target:SetAttribute("CarriedBy", Carrier.Name)
	SetKnockedSpeed(Target) -- carried: no crawl
	Carrier:SetAttribute("Carrying", Target.Name)
	Lock(Carrier, true, Cfg.CarryWalkSpeed)
	AnimationManager.Stop(Target, "Knocked")
	AnimationManager.Play(Target, "Carried", {Looped = true, Priority = Enum.AnimationPriority.Action4})
	AnimationManager.Play(Carrier, "Carrying", {Looped = true, Priority = Enum.AnimationPriority.Action})
	-- held exactly; a body removed while held (a corpse's 120 s, a despawn) is dropped at once
	local Hold = {Target = Target, Conns = {}}
	Held[Carrier] = Hold
	local function Gone()
		if Held[Carrier] == Hold then DownedManager.Drop(Carrier) end
	end
	table.insert(Hold.Conns, Target.Destroying:Connect(Gone))
	table.insert(Hold.Conns, Target.AncestryChanged:Connect(function()
		if not Target:IsDescendantOf(workspace) then Gone() end
	end))
	local WC = WCS.Character.GetCharacterFromInstance(Carrier)
	task.spawn(function()
		while Held[Carrier] == Hold do
			task.wait(0.1)
			if Held[Carrier] ~= Hold then break end
			-- still a body to hold: knocked and alive, or (Task 6) a takedown's dead body
			local Holdable = Target.Parent ~= nil and ((Alive(Target) and DownedManager.IsKnocked(Target))
				or DownedManager.IsTakedownBody(Target))
			if not Alive(Carrier) or not Holdable or Carrier:GetAttribute("Carrying") ~= Target.Name
				or DownedManager.IsKnocked(Carrier) or (WC and WC:HasStatusEffects({Stun}))
				or Carrier:GetAttribute("CombatState") ~= nil then
				DownedManager.Drop(Carrier)
				break
			end
		end
	end)
	return true
end

-- Requests.Downed: V = Carry (drop if already carrying; Ultimate when there is nothing to carry),
-- B = Grip.
function DownedManager.Request(Character, Action)
	if Action == "Carry" then
		if Character:GetAttribute("Carrying") then
			DownedManager.Drop(Character)
			return "Dropped"
		end
		if DownedManager.Carry(Character) then return "Carry" end
		return "Ultimate" -- the alchemy Ultimate is not built yet
	elseif Action == "Grip" then
		return DownedManager.Grip(Character) and "Gripped" or nil
	end
end

return DownedManager

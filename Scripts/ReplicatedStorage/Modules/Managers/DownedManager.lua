-- DownedManager: knocked state, Grip (B) and Carry (V). Numbers: TuningConfig.Downed (PROPOSALS).
--
-- * All combat damage goes through DownedManager.Damage. A hit that would bring a knockable
--   character (any player; an enemy with attribute Knockable) to 0 leaves them at 1 HP and
--   KNOCKED instead: slumped, stunned, immune to further damage; a knocked PLAYER can only crawl (see CRAWL), anyone
--   else can't move.
-- * After KnockedTime they recover with RecoverHealth of max health.
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
-- Attributes (server-written): Knocked, KnockedUntil, GrippedBy, Gripping, CarriedBy, Carrying.
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
--   RebaseCrawl(Model) afterwards (fix round 2: Drop, StationService, RoadService, TravelService, AdminService).
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

-- the downed crawl (owner 2026-10-27): only a knocked player who is neither gripped nor carried may crawl
function DownedManager.CanCrawl(Model)
	return Model ~= nil and DownedManager.IsKnocked(Model) and Players:GetPlayerFromCharacter(Model) ~= nil
		and not Model:GetAttribute("GrippedBy") and not Model:GetAttribute("CarriedBy")
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
	if not H then return end
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
-- CarriedBy, or the first CrawlClampGrace seconds of the knock (momentum) or after a RebaseCrawl (the owning client can
-- still echo its old position once after a server move: seen when a carry is set down). Every deliberate server move of
-- a player's character calls RebaseCrawl (StationService, RoadService, TravelService, AdminService, Drop).
local ClampFrom = {} -- [Model] = {Pos = Vector3, T = os.clock()}: the last allowed point
local RebasedAt = {} -- [Model] = os.clock() of the last RebaseCrawl
local function Unclamped(Victim, R, KnockedAt, Now)
	local H = Hum(Victim)
	local Grace = Cfg.CrawlClampGrace or 0.5
	return R:IsGrounded() or R.AssemblyRootPart ~= R or (H ~= nil and (H.PlatformStand or H.SeatPart ~= nil))
		or Victim:GetAttribute("GrippedBy") ~= nil or Victim:GetAttribute("CarriedBy") ~= nil
		or Now - KnockedAt < Grace or Now - (RebasedAt[Victim] or -math.huge) < Grace
end
local function ClampCrawl(Victim, KnockedAt)
	local R = Root(Victim)
	if not R then return end
	local Now = os.clock()
	local C = ClampFrom[Victim]
	if not C or Unclamped(Victim, R, KnockedAt, Now) then
		ClampFrom[Victim] = {Pos = R.Position, T = Now}
		return
	end
	local D = Vector3.new(R.Position.X - C.Pos.X, 0, R.Position.Z - C.Pos.Z).Magnitude
	if D < 0.05 then return end -- (still: the window keeps growing, up to its cap)
	local Dt = math.min(Now - C.T, Cfg.CrawlClampWindow or 1)
	local Max = ((Cfg.CrawlSpeed or 0) * (Cfg.CrawlClampMult or 1.5) + (Cfg.CrawlClampSlack or 2.5)) * Dt
	if D > Max then
		R.CFrame += C.Pos - R.Position
		R.AssemblyLinearVelocity = Vector3.zero
		C.T = Now
		Victim:SetAttribute("CrawlClamped", (Victim:GetAttribute("CrawlClamped") or 0) + 1) -- (a counter for tests)
	else
		C.Pos, C.T = R.Position, Now
	end
end
-- a script moved a knocked player on purpose: the clamp starts again from where they are now
function DownedManager.RebaseCrawl(Model)
	ClampFrom[Model] = nil
	-- (only while that player is knocked: the watch's end forgets it, so the table never grows)
	if DownedManager.IsKnocked(Model) then RebasedAt[Model] = os.clock() end
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

-- ===== Knock / recover =====
local Recover

function DownedManager.Knock(Victim)
	if DownedManager.IsKnocked(Victim) or not Alive(Victim) then return end
	local WCS, AnimationManager, Stun = Mods()
	-- Second Wind (skill tree keystone): once per life, a shorter knock and a stronger recovery
	local KnockedTime = tonumber(Victim:GetAttribute("KnockedTime")) or Cfg.KnockedTime -- (per character: townsfolk, Task 6b)
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
			Victim.Destroying:Once(function() KnockStun[Victim], Welds[Victim] = nil, nil end)
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
			local KnockedAt = os.clock()
			ClampFrom[Victim] = nil
			while Victim.Parent and DownedManager.IsKnocked(Victim) and Victim:GetAttribute("KnockedUntil") == Until do
				SetKnockedSpeed(Victim)
				ClampCrawl(Victim, KnockedAt)
				task.wait(Cfg.CrawlCheck or 0.1)
			end
			ClampFrom[Victim] = nil
			RebasedAt[Victim] = nil
			Victim:SetAttribute("CrawlClamped", nil)
			if not DownedManager.IsKnocked(Victim) then Victim:SetAttribute("KnockedStill", nil) end
		end)
	end
end

function Recover(Victim)
	if not DownedManager.IsKnocked(Victim) or not Alive(Victim) then return end
	if Victim:GetAttribute("GrippedBy") then return end -- a grip in progress decides it
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
	local Share = Victim:GetAttribute("SecondWindActive") and 0.30 -- Second Wind (PROPOSAL 30%)
		or tonumber(Victim:GetAttribute("RecoverHealth")) or Cfg.RecoverHealth -- (per character: townsfolk, Task 6b)
	Victim:SetAttribute("SecondWindActive", nil)
	H.Health = math.max(H.Health, H.MaxHealth * Share)
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
-- lookup can return a different, healthy one; the CarriedBy link is exact.
function DownedManager.Carried(Carrier)
	local Name = Carrier and Carrier:GetAttribute("Carrying")
	if not Name then return nil end
	for _, M in ipairs(DownedManager.LiveModels()) do
		if M.Name == Name and M:GetAttribute("CarriedBy") == Carrier.Name then return M end
	end
	return DownedManager.Find(Name)
end

-- nearest knocked, free target within Range of Actor
function DownedManager.Nearest(Actor, Range)
	local AR = Root(Actor)
	if not AR then return nil end
	local Best, BestD = nil, Range
	for _, M in ipairs(DownedManager.LiveModels()) do
		if M ~= Actor and DownedManager.IsKnocked(M) and Alive(M) and not M:GetAttribute("GrippedBy")
			and not M:GetAttribute("CarriedBy") then
			local R = Root(M)
			local D = R and (R.Position - AR.Position).Magnitude
			if D and D <= BestD then Best, BestD = M, D end
		end
	end
	return Best
end

local function Free(Actor)
	local WCS, _, Stun, AttackRunner = Mods()
	local WC = WCS.Character.GetCharacterFromInstance(Actor)
	return Alive(Actor) and not DownedManager.IsKnocked(Actor) and not Actor:GetAttribute("Gripping")
		and not Actor:GetAttribute("Carrying") and not AttackRunner.IsRunning(Actor)
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
	if not Target or not Free(Gripper) then return false end
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
		Hum(Target).Health = 0
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
function DownedManager.Drop(Carrier)
	if not Carrier then return end
	local Target = DownedManager.Carried(Carrier)
	Carrier:SetAttribute("Carrying", nil)
	local _, AnimationManager = Mods()
	if Carrier.Parent then
		Lock(Carrier, false)
		AnimationManager.Stop(Carrier, "Carrying")
	end
	if Target then
		Target:SetAttribute("CarriedBy", nil)
		Detach(Target)
		SetKnockedSpeed(Target) -- set down: a knocked player may crawl again
		local CR, TR = Root(Carrier), Root(Target)
		if CR and TR then TR.CFrame = CR.CFrame * CFrame.new(0, 0, -2.5) end -- set down in front
		DownedManager.RebaseCrawl(Target)
		if Alive(Target) and DownedManager.IsKnocked(Target) then
			AnimationManager.Stop(Target, "Carried")
			AnimationManager.Play(Target, "Knocked", {Looped = true, Priority = Enum.AnimationPriority.Action4})
			if (Target:GetAttribute("KnockedUntil") or 0) <= workspace:GetServerTimeNow() then Recover(Target) end
		end
	end
end

function DownedManager.Carry(Carrier, Target)
	Target = Target or DownedManager.Nearest(Carrier, Cfg.CarryRange)
	if not Target or not Free(Carrier) then return false end
	local WCS, AnimationManager, Stun = Mods()
	if not Attach(Carrier, Target, Cfg.CarryOffset) then return false end
	Target:SetAttribute("CarriedBy", Carrier.Name)
	SetKnockedSpeed(Target) -- carried: no crawl
	Carrier:SetAttribute("Carrying", Target.Name)
	Lock(Carrier, true, Cfg.CarryWalkSpeed)
	AnimationManager.Stop(Target, "Knocked")
	AnimationManager.Play(Target, "Carried", {Looped = true, Priority = Enum.AnimationPriority.Action4})
	AnimationManager.Play(Carrier, "Carrying", {Looped = true, Priority = Enum.AnimationPriority.Action})
	local WC = WCS.Character.GetCharacterFromInstance(Carrier)
	task.spawn(function()
		while Carrier:GetAttribute("Carrying") == Target.Name do
			task.wait(0.1)
			if not Alive(Carrier) or not Alive(Target) or not DownedManager.IsKnocked(Target)
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

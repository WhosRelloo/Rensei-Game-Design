-- TakedownService (assassinations plan Task 7, 2026-10-27; spec Documents/specs/2026-10-25-assassinations-design.md,
-- owner-approved 2026-10-27): the server side of a stealth takedown. The client only shows the prompt (TakedownUI,
-- Task 10) and sends Requests.Takedown(Kind, Target); every rule is checked here, with the server's own positions.
-- Numbers and the gate maths: Rensei.Takedown (every number a PROPOSAL unless it says it was measured).
--
-- PvE ONLY (owner rule): a player's character is never a target. Context computes IsPlayer first and
-- Rensei.Takedown.Check refuses it before anything else, so no takedown path ever holds, marks or kills a player.
--
-- * Check(Player, Target, Kind) -> ok, reason: Takedown.Check(Context(...)). Never yields. Context gathers the gates
--   (spec §3, §11) fail-closed: the real perception phase (nil for a rig perception doesn't track, never defaulted to
--   Unaware), the class always set (Takedown.ClassOf; TrialFoe from the enemy type's TuningConfig definition), the
--   player's own state (alive, not knocked / gripping / carrying / taking down / attacking, no Stun but the crouch's own
--   -- finding A15 --, on the ground, not swimming), Calm (CombatMode off), the target free (not knocked, gripped,
--   carried, being taken down or swimming), the rear arc, the range (+ RangeSlack) and one clear ray torso to torso.
-- * Request(Player, Kind, Target) -> ok, reason: refused -> the next allowed time is at least now + RefusedCooldown and
--   LastTakedownResult = "<Kind>:<reason>". Accepted -> in the same step, with no yield, the target is marked
--   TakenDownBy and the player TakingDown (one takedown per target, spec §11), then the takedown runs on its own thread.
--   "Knockout" and Chunk (Elite) targets are refused "todo" until Tasks 8-9, before anything is marked.
-- * The ASSASSINATION of a Full target (spec §4-§7):
--     1. PerceptionService.Glimpse(Player, Target): every NPC but the victim takes one quick look (spec §6);
--     2. the player is locked (DownedManager.Lock); the victim takes no damage (DamageTakenMult 0), is stunned (WCS Stun
--        for LethalTime) and stops its animations;
--     3. the player is put behind it (Target root * Takedown.Offset:Inverse()) and the victim's root is welded to the
--        player's (DownedManager.Attach with Takedown.Offset: massless, PlatformStand, owned by the player). A rig with an
--        anchored root (test rigs) is un-anchored for the weld;
--     4. Anims.Assassinate: the player's and the victim's animations, each with its fallback, Action4, at
--        Takedown.Speed (length / LethalTime, clamped);
--     5. every Heartbeat until LethalTime x KillAt (the "Snap" keyframe's share): interrupted when either is gone or
--        dead, the player leaves, is knocked or has a Stun other than the crouch's, or the roots are more than
--        BreakDistance apart;
--     6. the kill: WorldService.Credit (once; it respects Credited), then the deed with witnesses (assassinated_guard
--        for a law-faction victim, pre-flight R8: its Faction attribute or its perception faction; else
--        Deeds.Finishers[EnemyType].Assassinate when there is one), then the weld is let go (Takeable refuses a welded
--        body, so V could never carry it) and DownedManager.Finish: FinishedBy, the ragdoll (owner 2026-10-27, after the
--        Snap), Health 0, and the body registered with PerceptionService ("Dead", By = the player, with the deed, its
--        witness strength and the faction); then a "Takedown" sound (4 studs) at the body. No RecordHit (finding A4: no
--        20-stud Hit sound, no alarm);
--     7. release: the player's lock back (not when knocked: the knock's lock and crawl own the walk speed then), the
--        animations stopped, TakingDown cleared. TakenDownBy STAYS on the corpse (the body mark: it lies
--        Takedown.BodySeconds, EnemyService);
--     8. the cooldown: the next allowed time = now + Cooldown, TakedownReadyAt, LastTakedownResult "Assassinate:ok",
--        then the Done listeners.
-- * INTERRUPTED (any kind): released as in 7, and TakenDownBy cleared, DamageTakenMult and the root's anchoring put
--   back, the victim's Stun stopped, the victim Alert on the player (PerceptionService.Alarm), the cooldown as in 8,
--   LastTakedownResult "<Kind>:interrupted", then Failed(Player, Rig, "interrupted").
-- * Heat when a guard's body is found (pre-flight R9, spec §18.3): a "Dead" body whose assassinated_guard deed was
--   recorded with witness strength 0 (nobody saw it) raises its law's Heat once when an NPC finds it, through the same
--   rule the witness path uses (Heat.Raised for the body's region, heard by the victim's own faction -> HeatService.Add).
--   A witnessed guard killing already raised Heat when it was recorded (HeatService), so it never raises it twice. A
--   gripped body carries no deed, so finding one raises nothing.
-- * Start(): the Recorded and BodyFound listeners; PlayerRemoving forgets the player's cooldown and releases any
--   takedown they're in (as an interrupt, without the Alarm). Forget(Player) clears the cooldown (tests use it too).
-- Listeners (each in a pcall): Done(Kind, Player, Rig) after a finished takedown; Failed(Player, Rig, Reason).
--
-- Attributes. Victim: TakenDownBy (the player's name; kept on an assassinated corpse), DamageTakenMult (0 while held),
-- FinishedBy (DownedManager.Finish), read: Faction, TakedownClass, Boss, EnemyType, TownsfolkId, Knocked, GrippedBy,
-- CarriedBy, Traversal. Player's character: TakingDown (the victim's name), TakedownReadyAt (server time), and
-- LastTakedownResult (for tests and logs); read: CombatMode, Knocked, Gripping, Carrying, Traversal.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage.Modules
local Rensei = Modules.Data.Rensei
local Takedown = require(Rensei.Takedown)
local Deeds = require(Rensei.Deeds)
local Heat = require(Rensei.Heat)
local Regions = require(Rensei.Regions)
local Tuning = require(Rensei.TuningConfig)
local WCS = require(Modules.Framework.WCS)
local Stun = require(Modules.Skills.States.Stun)
local AttackRunner = require(Modules.Managers.AttackRunner)
local AnimationManager = require(Modules.Managers.AnimationManager)
local DownedManager = require(Modules.Managers.DownedManager)
local PerceptionService = require(ServerScriptService.PerceptionService)
local EnemyService = require(ServerScriptService.EnemyService)

local TakedownService = {}
TakedownService.Done = {} -- listeners (Kind, Player, Rig)
TakedownService.Failed = {} -- listeners (Player, Rig, Reason)

local NextAt = {} -- [Player] = os.clock() from which a request is allowed again
local Running = {} -- [Player] = the takedown in progress
local Recorded = {} -- [Player] = {Deed, Strength} of the last deed MoralityService recorded for them (its listener)

local function Hum(M) return M and M:FindFirstChildOfClass("Humanoid") end
local function Root(M) return M and M:FindFirstChild("HumanoidRootPart") end
local function Torso(M) return M:FindFirstChild("Torso") or M:FindFirstChild("UpperTorso") or Root(M) end
local function Alive(M) local H = Hum(M) return H ~= nil and M.Parent ~= nil and H.Health > 0 end
local function Flat(V) return Vector3.new(V.X, 0, V.Z) end
local function Label(Kind) return type(Kind) == "string" and Kind:sub(1, 24) or "?" end

local function Fire(List, ...)
	for _, Fn in ipairs(List) do
		local Ok, Err = pcall(Fn, ...)
		if not Ok then warn("TakedownService listener:", Err) end
	end
end

-- a Stun on this character other than the one its crouch runs (finding A15: crouching is a real WCS Stun)
local function Stunned(Character)
	local WC = WCS.Character.GetCharacterFromInstance(Character)
	if not WC then return false end
	local Crouch = AttackRunner.CrouchStuns[WC]
	for _, S in ipairs(WC:GetAllActiveStatusEffectsOfType(Stun)) do
		if S ~= Crouch then return true end
	end
	return false
end

local function PlayerFree(Character)
	local H = Hum(Character)
	if not H or H.Health <= 0 or DownedManager.IsKnocked(Character) then return false end
	if Character:GetAttribute("Gripping") or Character:GetAttribute("Carrying") or Character:GetAttribute("TakingDown") then return false end
	if AttackRunner.IsRunning(Character) or Stunned(Character) then return false end
	return H.FloorMaterial ~= Enum.Material.Air and Character:GetAttribute("Traversal") ~= "Swim"
end

local ClearRays = RaycastParams.new()
ClearRays.FilterType = Enum.RaycastFilterType.Exclude
ClearRays.RespectCanCollide = true
ClearRays.IgnoreWater = true

function TakedownService.Context(Player, Target, Kind)
	local Ctx = {Kind = Kind, Range = Takedown.Range + Takedown.RangeSlack}
	Ctx.IsPlayer = Players:GetPlayerFromCharacter(Target) ~= nil -- (first: the PvE rule)
	local Character = Player and Player.Character
	Ctx.IsTownsfolk = Target:GetAttribute("TownsfolkId") ~= nil
	Ctx.IsEnemy = EnemyService.Active[Target] ~= nil
	Ctx.Alive = Alive(Target)
	local S = PerceptionService.Npcs[Target]
	local Def = Tuning.Enemies[Target:GetAttribute("EnemyType") or ""]
	Ctx.Class = Takedown.ClassOf(S and S.Type or nil, {
		Boss = Target:GetAttribute("Boss") == true or (Def ~= nil and Def.Boss == true),
		TrialFoe = Def ~= nil and Def.TrialFoe == true,
		TakedownClass = Target:GetAttribute("TakedownClass"),
	})
	Ctx.Ready = os.clock() >= (NextAt[Player] or 0)
	Ctx.PlayerFree = Character ~= nil and PlayerFree(Character)
	Ctx.PlayerCalm = Character ~= nil and Character:GetAttribute("CombatMode") ~= true
	Ctx.TargetFree = not (Target:GetAttribute("Knocked") or Target:GetAttribute("GrippedBy") or Target:GetAttribute("CarriedBy")
		or Target:GetAttribute("TakenDownBy") or Target:GetAttribute("Traversal") == "Swim")
	Ctx.Phase = S and S.Phase or nil -- (nil for an untracked rig: refused, never read as Unaware)
	Ctx.AwareOfYou = S and PerceptionService.Awareness(Target, Player) or nil
	local PR, TR = Root(Character), Root(Target)
	if PR and TR then
		local D = PR.Position - TR.Position
		Ctx.Dist, Ctx.Height = Flat(D).Magnitude, D.Y
		Ctx.Behind = Takedown.Behind(TR.CFrame.LookVector, D, Takedown.AngleSlack)
		ClearRays.FilterDescendantsInstances = {Character, Target}
		local A, B = Torso(Character).Position, Torso(Target).Position
		Ctx.Clear = workspace:Raycast(A, B - A, ClearRays) == nil
	end
	return Ctx
end

function TakedownService.Check(Player, Target, Kind)
	return Takedown.Check(TakedownService.Context(Player, Target, Kind))
end

-- the deed for killing this rig (pre-flight R8): a guard's when its faction is a law, else its type's finisher deed
local function DeedFor(Target)
	local S = PerceptionService.Npcs[Target]
	local Faction = Target:GetAttribute("Faction") or (S and S.Faction) or nil
	if Takedown.IsLawFaction(Faction) then return "assassinated_guard", Faction end
	local F = Deeds.Finishers[Target:GetAttribute("EnemyType") or ""]
	return F and F.Assassinate or nil, Faction
end

-- the end of a takedown, once: "ok" (after the kill) or "interrupted" (Quiet: no Alarm, the player left)
local function Release(S, Outcome, Quiet)
	if S.Over then return end
	S.Over = true
	if Running[S.Player] == S then Running[S.Player] = nil end
	local C, T, Kind = S.Character, S.Target, S.Kind
	local A = Takedown.Anims[Kind] or {}
	-- the victim, let go on every end (Takeable refuses a body with a weld; the kill lets go before the ragdoll)
	if not S.Detached then
		S.Detached = true
		DownedManager.Detach(T)
	end
	pcall(function()
		T:SetAttribute("DamageTakenMult", S.Mult)
		if Outcome ~= "ok" then
			T:SetAttribute("TakenDownBy", nil)
			local TR = Root(T)
			if TR and S.Anchored ~= nil then TR.Anchored = S.Anchored end
			if A.Victim then AnimationManager.Stop(T, A.Victim) AnimationManager.Stop(T, A.VictimFallback) end
			if Alive(T) then AnimationManager.Play(T, "Idle", {Looped = true, Priority = Enum.AnimationPriority.Core}) end
		end
	end)
	if S.Stun then pcall(function() S.Stun:Stop() end) end
	-- the player: unlocked unless a knock has taken over the walk (its lock nests on ours and Recover gives it back)
	pcall(function()
		if S.Locked and C.Parent and not DownedManager.IsKnocked(C) then DownedManager.Lock(C, false) end
		if A.Player then AnimationManager.Stop(C, A.Player) AnimationManager.Stop(C, A.PlayerFallback) end
		C:SetAttribute("TakingDown", nil)
	end)
	if Outcome ~= "ok" and not Quiet and Alive(T) then PerceptionService.Alarm(T, S.Player) end
	NextAt[S.Player] = os.clock() + Takedown.Cooldown
	pcall(function()
		C:SetAttribute("TakedownReadyAt", workspace:GetServerTimeNow() + Takedown.Cooldown)
		C:SetAttribute("LastTakedownResult", Kind .. ":" .. (Outcome == "ok" and "ok" or "interrupted"))
	end)
	if Outcome == "ok" then Fire(TakedownService.Done, Kind, S.Player, T) else Fire(TakedownService.Failed, S.Player, T, "interrupted") end
end

-- steps 1-4: the look, the lock and the protection, the placement and the weld, the animations
local function Hold(S)
	local Player, C, T, Kind = S.Player, S.Character, S.Target, S.Kind
	PerceptionService.Glimpse(Player, T)
	DownedManager.Lock(C, true)
	S.Locked = true
	S.Mult = T:GetAttribute("DamageTakenMult")
	T:SetAttribute("DamageTakenMult", 0)
	local VWC = WCS.Character.GetCharacterFromInstance(T)
	if VWC then
		S.Stun = Stun.new(VWC)
		S.Stun:Start(Takedown[Kind == "Knockout" and "KnockoutTime" or "LethalTime"])
	end
	AnimationManager.StopAllAnims(T)
	local PR, TR = Root(C), Root(T)
	S.Anchored = TR.Anchored
	TR.Anchored = false -- (a test rig's anchored root would hold the player in place through the weld)
	PR.CFrame = TR.CFrame * Takedown.Offset:Inverse()
	PR.AssemblyLinearVelocity = Vector3.zero
	if not DownedManager.Attach(C, T, Takedown.Offset) then error("the weld failed") end
	local A = Takedown.Anims[Kind]
	local Speed = Takedown.Speed(Kind)
	AnimationManager.Play(C, A.Player, {Priority = Enum.AnimationPriority.Action4, Speed = Speed, Fallback = A.PlayerFallback})
	AnimationManager.Play(T, A.Victim, {Priority = Enum.AnimationPriority.Action4, Speed = Speed, Fallback = A.VictimFallback})
end

local function Broken(S)
	local C, T = S.Character, S.Target
	if S.Player.Parent ~= Players or not Alive(C) or not Alive(T) then return true end
	if DownedManager.IsKnocked(C) or Stunned(C) then return true end
	local A, B = Root(C), Root(T)
	return not (A and B) or (A.Position - B.Position).Magnitude > Takedown.BreakDistance
end

-- step 6 then 7-8: the kill at the Snap
local function Kill(S)
	local Player, C, T = S.Player, S.Character, S.Target
	local Where = Root(T).Position
	require(ServerScriptService.WorldService).Credit(T, Player)
	local DeedId, Faction = DeedFor(T)
	local Body = {Faction = Faction}
	if DeedId then
		Recorded[Player] = nil
		if require(ServerScriptService.MoralityService).Record(Player, DeedId, false, {Witness = true}) then
			local R = Recorded[Player]
			Body.Deed = DeedId
			Body.Strength = R and R.Deed == DeedId and R.Strength or nil
		end
	end
	S.Detached = true
	DownedManager.Detach(T) -- (let go first: the body falls as a ragdoll, and V can carry it)
	DownedManager.Finish(T, C, Body)
	require(ServerScriptService.NoiseService).Emit(Where, "Takedown", C)
	Release(S, "ok")
end

local function Run(Player, Target, Kind)
	local S = {Player = Player, Character = Player.Character, Target = Target, Kind = Kind}
	Running[Player] = S
	local Ok, Err = pcall(Hold, S)
	if not Ok then
		warn("TakedownService: the takedown couldn't start:", Err)
		Release(S, "interrupted")
		return
	end
	local KillAt = Takedown[Kind == "Knockout" and "KnockoutTime" or "LethalTime"] * Takedown.KillAt
	local T0 = os.clock()
	while true do
		RunService.Heartbeat:Wait()
		if S.Over then return end
		if Broken(S) then Release(S, "interrupted") return end
		if os.clock() - T0 >= KillAt then break end
	end
	local KillOk, KillErr = pcall(Kill, S)
	if not KillOk then
		warn("TakedownService: the kill failed:", KillErr)
		Release(S, "interrupted")
	end
end

function TakedownService.Request(Player, Kind, Target)
	local Character = Player and Player.Character
	if not (Root(Character) and typeof(Target) == "Instance" and Target:IsA("Model") and Root(Target)) then return false, "missing" end
	local Ctx = TakedownService.Context(Player, Target, Kind)
	local Ok, Reason = Takedown.Check(Ctx)
	-- the knockout (Task 8) and an Elite's backstab (Task 9) don't exist yet: refused before anything is marked
	if Ok and (Kind == "Knockout" or Ctx.Class == "Chunk") then Ok, Reason = false, "todo" end
	if not Ok then
		NextAt[Player] = math.max(NextAt[Player] or 0, os.clock() + Takedown.RefusedCooldown) -- (never shortens a cooldown)
		Character:SetAttribute("LastTakedownResult", Label(Kind) .. ":" .. tostring(Reason))
		return false, Reason
	end
	-- the same step as the last check, no yield between: one takedown per target
	Target:SetAttribute("TakenDownBy", Player.Name)
	Character:SetAttribute("TakingDown", Target.Name)
	task.spawn(Run, Player, Target, Kind)
	return true, "started"
end

function TakedownService.Forget(Player)
	NextAt[Player] = nil
end

-- (pre-flight R9) a found guard's body that nobody saw killed raises its law's Heat once
local function OnBodyFound(Body, _, Info)
	if Info.Kind ~= "Dead" or Info.Deed ~= "assassinated_guard" or Info.Strength ~= 0 or Info.Heated then return end
	local Player = Info.By
	if typeof(Player) ~= "Instance" or Player.Parent ~= Players then return end
	Info.Heated = true
	local Def = Deeds.assassinated_guard
	local Region = require(ServerScriptService.MoralityService).RegionOf(Body)
	local HeatService = require(ServerScriptService.HeatService)
	for _, X in ipairs(Heat.Raised(Regions.Regions[Region], {Info.Faction}, Def)) do
		HeatService.Add(Player, X.J, X.Amount, Region, Def.HeatCap)
	end
end

local Started = false
function TakedownService.Start()
	if Started then return end
	Started = true
	table.insert(require(ServerScriptService.MoralityService).Recorded, function(Player, DeedId, _, Info)
		Recorded[Player] = {Deed = DeedId, Strength = Info and Info.Strength}
	end)
	table.insert(PerceptionService.BodyFound, OnBodyFound)
	Players.PlayerRemoving:Connect(function(Player)
		TakedownService.Forget(Player)
		Recorded[Player] = nil
		local S = Running[Player]
		if S then Release(S, "interrupted", true) end
	end)
end

return TakedownService

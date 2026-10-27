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
--   A Full target is assassinated or knocked out (below); a Chunk target (an Elite, spec §8) can only be backstabbed:
--   Takedown.Check refuses its knockout ("kind"), an Immune one (a boss, a trial foe, anything perception doesn't track)
--   and a townsperson ("townsfolk", PvE) before anything is marked.
-- * The ASSASSINATION of a Full target (spec §4-§7):
--     1. PerceptionService.Glimpse(Player, Target): every NPC but the victim takes one quick look (spec §6); each
--        townsperson that saw it runs (Task 9, spec §18.2, pre-flight R10: TownsfolkService.Startle, away from the
--        player) and reports it as a witness of the deed (step 6's capture);
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
-- * The KNOCKOUT of a Full target (Task 8, spec §4-§5): steps 1-2 as above, then a "Choke" sound (6 studs) at the victim;
--   placed, welded and Anims.Knockout played (Takedown.Speed("Knockout")) for the whole KnockoutTime, with the same
--   interrupts. At the end the victim is released (DamageTakenMult, the Stun, TakenDownBy and the root's anchoring given
--   back), knocked out (DownedManager.Knock for Takedown.KnockoutSeconds: a knocked enemy lies still), marked
--   KnockedOutBy (the player's UserId) and registered as an "Out" body (By = the player); then the cooldown,
--   "Knockout:ok" and Done. No credit, no deed (Deeds.Finishers has no Knockout).
--   WAKING UP (watched from the knockout until it wakes or dies): when Knocked clears and the rig is alive (not
--   finished: a grip clears Knocked a moment before it kills), it is no longer a body, KnockedOutBy is cleared and,
--   unless Takedown.IsHidden, PerceptionService.Raise puts it Alert searching where it woke (and calls others in). When it
--   dies instead (a grip, a delivery) its "Out" body is dropped and KnockedOutBy cleared; a grip stays the loud
--   finisher it was, with its own deed and its own "Dead" body (spec §4).
-- * The BACKSTAB of a Chunk target (Task 9, spec §8; "Assassinate" only): step 1's look (townsfolk who saw it run); the
--   player locked and playing Anims.Assassinate's player animation (its fallback as ever) up to the Snap
--   (LethalTime x KillAt), with step 5's interrupts, then stopped. No weld, no protection, no victim animation. Then one
--   hit through the normal hit path: TakenDownBy cleared (so a hit that kills leaves an ordinary corpse, not a takedown's
--   body), DownedManager.Damage(Target, MaxHealth x ChunkShare) -- the 45% that takes it to 0 knocks a knockable rig, as
--   any hit does -- and ProgressionService.RecordHit(Character, Target, "Hit"): the 20-stud Hit sound, the Alarm (Alert
--   on the player) and the last-hit credit, as for any hit; a WCS Stun on it for ChunkStun (while it lives). Then the
--   release (as in 7), the cooldown, LastTakedownResult "Assassinate:backstab", and, when it is alive and not knocked,
--   Failed(Player, Rig, "survived") (the Nemesis hook, spec §13), else Done("Assassinate", Player, Rig). No credit of
--   its own, no deed, no body.
-- * INTERRUPTED (any kind): released as in 7, and (the victim living) TakenDownBy cleared and the root's anchoring put
--   back, DamageTakenMult (when it was saved) and the victim's Stun, the victim Alert on the player
--   (PerceptionService.Alarm), the cooldown as in 8, LastTakedownResult "<Kind>:interrupted", then Failed(Player, Rig,
--   "interrupted"). Broken also when the victim is knocked or gripped by something else (Task 7 review).
-- * ERROR (Task 7 review): a takedown whose kill fails part-way (after the credit, the deed or the death) is no
--   interrupt: released as in 7, a victim still alive given back, no Alarm, the cooldown, "<Kind>:error", and neither Done
--   nor Failed. A corpse keeps TakenDownBy and its root as it lies.
-- * Heat when a guard's body is found (pre-flight R9, spec §18.3; Task 8: keyed on the body, not the deed): a "Dead"
--   body of a law-faction NPC (Takedown.IsLawFaction: its Faction attribute, else its perception faction) that a player
--   killed -- assassinated or gripped -- raises its law's Heat once when an NPC finds it, through the same rule the
--   witness path uses (Heat.Raised for the body's region, heard by the victim's own faction, Deeds.assassinated_guard's
--   Crime -> HeatService.Add). Unless the kill's own deed was a crime recorded with a witness strength other than 0: that
--   raised Heat already (HeatService), so it never rises twice. A grip's deed (executed_bandit) is no crime, so a gripped
--   guard's Heat comes from here; so does an assassinated guard's whose deed was past its daily cap (Record counted
--   nothing, so its body carries no deed: found, it raises the Heat once, like any guard's body nobody saw killed). A
--   townsperson's body (TownsfolkId) never raises Heat here (Task 8 review): TownsfolkService owns a townsperson's murder
--   and its Heat (murder_townsfolk, witnessed), and the body carries none of that service's deed to tell a witnessed
--   murder from an unseen one, so it would be counted twice.
-- * Start(): the Recorded and BodyFound listeners, and PlayerRemoving -> PlayerLeft(Player): Cancel(Player, true) -- any
--   takedown they're in released as an interrupt, without the Alarm -- THEN their cooldown is forgotten (Task 7 review:
--   the release writes it). Cancel(Player, Quiet) -> true when a takedown was running. Forget(Player) clears the
--   cooldown (tests use it too).
-- Listeners (each in a pcall): Done(Kind, Player, Rig) after a finished takedown; Failed(Player, Rig, Reason), Reason
-- "interrupted" or (an Elite that lived through a backstab) "survived".
--
-- Attributes. Victim: TakenDownBy (the player's name; kept on an assassinated corpse), DamageTakenMult (0 while held),
-- KnockedOutBy (the player's UserId while knocked out), FinishedBy (DownedManager.Finish), read: Faction, TakedownClass,
-- Boss, EnemyType, TownsfolkId, Knocked, GrippedBy, CarriedBy, Traversal. Player's character: TakingDown (the victim's
-- name), TakedownReadyAt (server time), and LastTakedownResult (for tests and logs); read: CombatMode, Knocked,
-- Gripping, Carrying, Traversal.

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

-- (Task 9, spec §18.2, pre-flight R10) each townsperson among Saw (Glimpse's rigs) runs from the takedown, away from the
-- player; a failure is warned and never stops the takedown
local function Startle(Saw, Character)
	local R = Root(Character)
	local From = R and R.Position
	for _, Rig in ipairs(Saw) do
		local Id = Rig:GetAttribute("TownsfolkId")
		if Id ~= nil then
			local Ok, Err = pcall(function() require(ServerScriptService.TownsfolkService).Startle(Id, From) end)
			if not Ok then warn("TakedownService: a witness couldn't run:", Err) end
		end
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

-- a rig's faction (pre-flight R8): its Faction attribute (EnemyService writes it), else its perception faction
local function FactionOf(Target)
	local S = PerceptionService.Npcs[Target]
	return Target:GetAttribute("Faction") or (S and S.Faction) or nil
end

-- the deed for killing this rig (pre-flight R8): a guard's when its faction is a law, else its type's finisher deed
local function DeedFor(Target)
	local Faction = FactionOf(Target)
	if Takedown.IsLawFaction(Faction) then return "assassinated_guard", Faction end
	local F = Deeds.Finishers[Target:GetAttribute("EnemyType") or ""]
	return F and F.Assassinate or nil, Faction
end

-- (Task 8) a knocked-out rig, watched until it wakes or dies: see WAKING UP in the header
local function WatchWake(T)
	local Conns = {}
	local function Over()
		for _, X in ipairs(Conns) do X:Disconnect() end
		table.clear(Conns)
		local Info = PerceptionService.Bodies[T]
		if Info and Info.Kind == "Out" then PerceptionService.RemoveBody(T) end -- (a grip's "Dead" body stays)
		T:SetAttribute("KnockedOutBy", nil)
	end
	table.insert(Conns, T:GetAttributeChangedSignal("Knocked"):Connect(function()
		if T:GetAttribute("Knocked") then return end
		-- decided once the step that cleared it is over: a finished grip clears Knocked just before it kills
		task.defer(function()
			if T:GetAttribute("KnockedOutBy") == nil or T:GetAttribute("Knocked") then return end
			local Woke = Alive(T) and T:GetAttribute("FinishedBy") == nil
			Over()
			local R = Root(T)
			if Woke and R and not Takedown.IsHidden(T) then PerceptionService.Raise(T, R.Position) end
		end)
	end))
	local H = Hum(T)
	if H then table.insert(Conns, H.Died:Connect(Over)) end
	table.insert(Conns, T.Destroying:Connect(Over))
end

-- (Task 8) the knockout's end, once the victim is given back: knocked out, marked, a body, watched until it wakes
local function KnockOut(S)
	local Player, T = S.Player, S.Target
	DownedManager.Knock(T, Takedown.KnockoutSeconds)
	if not DownedManager.IsKnocked(T) then return end
	T:SetAttribute("KnockedOutBy", Player.UserId)
	PerceptionService.AddBody(T, {Kind = "Out", By = Player})
	WatchWake(T)
end

-- the end of a takedown, once. Outcome: "ok" (after the kill, or the knockout's whole hold), "backstab" (after a Chunk
-- target's hit: Done, or Failed "survived"), "interrupted" (Quiet: no Alarm, the player left), or "error" (the kill
-- failed part-way: no Alarm, neither Done nor Failed)
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
	-- a victim that lives on (an interrupt, an error before the death, a knockout) is given back as it was; a corpse
	-- keeps TakenDownBy (its body mark) and its root as it lies
	local Lives = Alive(T) and (Outcome ~= "ok" or Kind == "Knockout")
	pcall(function()
		if S.MultSaved then T:SetAttribute("DamageTakenMult", S.Mult) end
		if Lives then
			T:SetAttribute("TakenDownBy", nil)
			local TR = Root(T)
			if TR and S.Anchored ~= nil then TR.Anchored = S.Anchored end
			if A.Victim then AnimationManager.Stop(T, A.Victim) AnimationManager.Stop(T, A.VictimFallback) end
			-- (Task 9: only when the hold stopped its animations; a backstab never touches them)
			if Outcome ~= "ok" and S.Stopped and not DownedManager.IsKnocked(T) then
				AnimationManager.Play(T, "Idle", {Looped = true, Priority = Enum.AnimationPriority.Core})
			end
		end
	end)
	if S.Stun then pcall(function() S.Stun:Stop() end) end
	-- the player: unlocked unless a knock has taken over the walk (its lock nests on ours and Recover gives it back)
	pcall(function()
		if S.Locked and C.Parent and not DownedManager.IsKnocked(C) then DownedManager.Lock(C, false) end
		if A.Player then AnimationManager.Stop(C, A.Player) AnimationManager.Stop(C, A.PlayerFallback) end
		C:SetAttribute("TakingDown", nil)
	end)
	if Outcome == "ok" and Kind == "Knockout" and Lives then
		local Ok, Err = pcall(KnockOut, S)
		if not Ok then warn("TakedownService: the knockout failed:", Err) end
	end
	if Outcome == "interrupted" and not Quiet and Alive(T) then PerceptionService.Alarm(T, S.Player) end
	NextAt[S.Player] = os.clock() + Takedown.Cooldown
	pcall(function()
		C:SetAttribute("TakedownReadyAt", workspace:GetServerTimeNow() + Takedown.Cooldown)
		C:SetAttribute("LastTakedownResult", Kind .. ":" .. Outcome)
	end)
	if Outcome == "ok" then
		Fire(TakedownService.Done, Kind, S.Player, T)
	elseif Outcome == "interrupted" then
		Fire(TakedownService.Failed, S.Player, T, "interrupted")
	elseif Outcome == "backstab" then
		if Alive(T) and not DownedManager.IsKnocked(T) then
			Fire(TakedownService.Failed, S.Player, T, "survived") -- (the Nemesis hook, spec §13)
		else
			Fire(TakedownService.Done, Kind, S.Player, T)
		end
	end
end

-- steps 1-4: the look, the lock and the protection, the placement and the weld, the animations (the knockout: a Choke)
local function Hold(S)
	local Player, C, T, Kind = S.Player, S.Character, S.Target, S.Kind
	-- (Task 7 review) saved first, so a takedown that can't start never writes over what the victim had
	S.Mult, S.MultSaved = T:GetAttribute("DamageTakenMult"), true
	Startle(PerceptionService.Glimpse(Player, T), C)
	DownedManager.Lock(C, true)
	S.Locked = true
	T:SetAttribute("DamageTakenMult", 0)
	local VWC = WCS.Character.GetCharacterFromInstance(T)
	if VWC then
		S.Stun = Stun.new(VWC)
		S.Stun:Start(Takedown[Kind == "Knockout" and "KnockoutTime" or "LethalTime"])
	end
	AnimationManager.StopAllAnims(T)
	S.Stopped = true
	if Kind == "Knockout" then require(ServerScriptService.NoiseService).Emit(Root(T).Position, "Choke", C) end
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

-- (Task 9) a Chunk target's backstab, up to the hit: the look, the player locked and playing the assassination
local function Backstab(S)
	local Player, C, T = S.Player, S.Character, S.Target
	S.Detached = true -- (never welded: nothing to let go)
	Startle(PerceptionService.Glimpse(Player, T), C)
	DownedManager.Lock(C, true)
	S.Locked = true
	local A = Takedown.Anims.Assassinate
	AnimationManager.Play(C, A.Player, {Priority = Enum.AnimationPriority.Action4, Speed = Takedown.Speed("Assassinate"),
		Fallback = A.PlayerFallback})
end

-- (Task 9) the backstab's hit at the Snap: the normal hit path, the stun, then the release
local function Stab(S)
	local Player, C, T = S.Player, S.Character, S.Target
	local A = Takedown.Anims.Assassinate
	AnimationManager.Stop(C, A.Player)
	AnimationManager.Stop(C, A.PlayerFallback)
	T:SetAttribute("TakenDownBy", nil) -- (first: a hit that kills leaves an ordinary corpse, not a takedown's body)
	DownedManager.Damage(T, Hum(T).MaxHealth * Takedown.ChunkShare)
	require(ServerScriptService.ProgressionService).RecordHit(C, T, "Hit")
	local VWC = Alive(T) and WCS.Character.GetCharacterFromInstance(T)
	if VWC then Stun.new(VWC):Start(Takedown.ChunkStun) end
	Release(S, "backstab")
end

local function Broken(S)
	local C, T = S.Character, S.Target
	if S.Player.Parent ~= Players or not Alive(C) or not Alive(T) then return true end
	if DownedManager.IsKnocked(C) or Stunned(C) then return true end
	if DownedManager.IsKnocked(T) or T:GetAttribute("GrippedBy") then return true end -- (Task 7 review: taken by something else)
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

local function Run(Player, Target, Kind, Chunk)
	local S = {Player = Player, Character = Player.Character, Target = Target, Kind = Kind}
	Running[Player] = S
	local Ok, Err = pcall(Chunk and Backstab or Hold, S)
	if not Ok then
		warn("TakedownService: the takedown couldn't start:", Err)
		Release(S, "interrupted")
		return
	end
	-- the knockout holds for its whole KnockoutTime; the assassination kills (a backstab hits) at the Snap (LethalTime x KillAt)
	local EndAt = Kind == "Knockout" and Takedown.KnockoutTime or Takedown.LethalTime * Takedown.KillAt
	local T0 = os.clock()
	while true do
		RunService.Heartbeat:Wait()
		if S.Over then return end
		if Broken(S) then Release(S, "interrupted") return end
		if os.clock() - T0 >= EndAt then break end
	end
	if Kind == "Knockout" then
		Release(S, "ok")
		return
	end
	local KillOk, KillErr = pcall(Chunk and Stab or Kill, S)
	if not KillOk then
		-- (Task 7 review) past the point of no return (the credit, the deed, the death may be done): no interrupt
		warn("TakedownService: the kill failed:", KillErr)
		Release(S, "error")
	end
end

function TakedownService.Request(Player, Kind, Target)
	local Character = Player and Player.Character
	if not (Root(Character) and typeof(Target) == "Instance" and Target:IsA("Model") and Root(Target)) then return false, "missing" end
	local Ctx = TakedownService.Context(Player, Target, Kind)
	local Ok, Reason = Takedown.Check(Ctx)
	if not Ok then
		NextAt[Player] = math.max(NextAt[Player] or 0, os.clock() + Takedown.RefusedCooldown) -- (never shortens a cooldown)
		Character:SetAttribute("LastTakedownResult", Label(Kind) .. ":" .. tostring(Reason))
		return false, Reason
	end
	-- the same step as the last check, no yield between: one takedown per target
	Target:SetAttribute("TakenDownBy", Player.Name)
	Character:SetAttribute("TakingDown", Target.Name)
	task.spawn(Run, Player, Target, Kind, Ctx.Class == "Chunk") -- (a Chunk target: Check let only "Assassinate" through)
	return true, "started"
end

function TakedownService.Forget(Player)
	NextAt[Player] = nil
end

-- (pre-flight R9; Task 8: keyed on the body) a found law-faction body a player killed raises its law's Heat once, unless
-- its kill's own deed was a crime someone saw (that raised the Heat already)
local function OnBodyFound(Body, _, Info)
	-- (Task 8 review) a townsperson's body is TownsfolkService's: it owns the murder's Heat (see the header)
	if Body:GetAttribute("TownsfolkId") ~= nil then return end
	if Info.Kind ~= "Dead" or Info.Heated then return end
	local Player = Info.By
	if typeof(Player) ~= "Instance" or Player.Parent ~= Players then return end
	local Faction = Info.Faction or FactionOf(Body)
	if not Takedown.IsLawFaction(Faction) then return end
	local Own = Info.Deed and Deeds[Info.Deed]
	if Own and (Own.Crime or 0) > 0 and Info.Strength ~= 0 then return end
	Info.Heated = true
	local Def = Deeds.assassinated_guard -- (a gripped guard weighs the same: its Crime 60, PROPOSAL)
	local Region = require(ServerScriptService.MoralityService).RegionOf(Body)
	local HeatService = require(ServerScriptService.HeatService)
	for _, X in ipairs(Heat.Raised(Regions.Regions[Region], {Faction}, Def)) do
		HeatService.Add(Player, X.J, X.Amount, Region, Def.HeatCap)
	end
end

-- the player's running takedown released as an interrupt (Quiet: no Alarm); true when one was running
function TakedownService.Cancel(Player, Quiet)
	local S = Running[Player]
	if not S then return false end
	Release(S, "interrupted", Quiet == true)
	return true
end

-- the player left: any takedown they're in is released (an interrupt, without the Alarm), THEN their cooldown is
-- forgotten (Task 7 review: the release writes the cooldown, so forgetting it first left it behind)
function TakedownService.PlayerLeft(Player)
	Recorded[Player] = nil
	TakedownService.Cancel(Player, true)
	TakedownService.Forget(Player)
end

local Started = false
function TakedownService.Start()
	if Started then return end
	Started = true
	table.insert(require(ServerScriptService.MoralityService).Recorded, function(Player, DeedId, _, Info)
		Recorded[Player] = {Deed = DeedId, Strength = Info and Info.Strength}
	end)
	table.insert(PerceptionService.BodyFound, OnBodyFound)
	Players.PlayerRemoving:Connect(TakedownService.PlayerLeft)
end

return TakedownService

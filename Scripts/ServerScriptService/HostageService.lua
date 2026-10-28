-- HostageService (hostages plan Task 5, 2026-10-27; spec Documents/specs/2026-10-21-hostage-design.md, owner-approved
-- 2026-10-25): the server side of a player-on-player hostage. The client only asks (Requests.Hostage); every rule is
-- checked here, with the server's own positions. Numbers and the gate maths: Rensei.Hostage (every number a PROPOSAL
-- unless it says it was measured). Tasks 6-11 extend it (the pair policed, the grab and the struggle, the captor menu,
-- the shield and rescue, ransom and turn-in).
--
-- PvP ONLY (owner rule): a hostage and a captor are always players. IsNpc (EnemyType, TownsfolkId, DialogueId or an
-- EnemyService entry; pre-flight P25) is asked FIRST, before a character is ever looked up as a player: PlayerOf never
-- returns one for an NPC, StandIn refuses an NPC rig, Take refuses an NPC captor or target ("not_player") before
-- anything is marked, and Rensei.Hostage.CheckTake refuses IsNpc before every other gate. No path holds an NPC.
--
-- * THE PLAYER-LIKE ("PL"). Every function takes a real Player or (tests only) a stand-in table
--   {IsStandIn = true, Name, DisplayName, UserId, Character, Level, Data = {Money, Stats}, Party}. Only the helpers
--   below tell them apart: Char, Present, LevelOf (Data.Level, never the Level attribute that ProgressionService.Sync
--   rewrites; pre-flight P2), DataOf, PartyOf, Notify, Record, Key (the UserId).
-- * THE SEAMS (tests only). StandIn(Model, Info) registers a rig as a player-like; PartyOf answers from HostageService
--   ._PartyOf when a test sets it (ruling T1-4). Both are honoured ONLY while SeamOpen(): RunService:IsStudio() AND
--   DataManager.IsNoSave() AND HostageService._NoSave() (the swappable copy; pre-flight P24 -- a test swaps it to
--   close the seam, never the data layer's own function, and swapping it can only close the seam, never open it). A
--   live server never reads either. StandIn refuses any NPC rig (IsNpc).
-- * Context(Captor, TargetModel, Kind) -> Ctx: Rensei.Hostage.CheckTake's fields, with the server's slack (IsNpc
--   first; IsPlayer; Self; Safe for either; InDialogue for either real player; the levels; Ready / Immune; CaptorFree
--   -- alive, not Knocked / Gripping / Carrying / TakingDown / Holding / HeldBy, not attacking, no Stun but the crouch's
--   (TakedownService.Stunned, called, never copied), on the ground, not swimming --; TargetFree -- alive, none of
--   GrippedBy / CarriedBy / TakenDownBy / HeldBy / Holding / Gripping / Carrying / TakingDown, not swimming --;
--   TargetKnocked; Dist on the ground plane, Height; Range = the Kind's range + RangeSlack; Behind (rear arc +
--   AngleSlack); Clear = one torso-to-torso ray). Check(Captor, TargetModel, Kind) -> ok, reason.
-- * InSafeZone(Character) (ruling R6): the region's Safe flag; inside a part tagged Hostage.SafeTag (point in box); within
--   StationSafeRadius (3D) of a RenseiTicketClerk / RenseiStationGate in workspace; inside a RenseiPlatformTrain's
--   bounding box grown by TrainMargin.
-- * SWITCHED OFF (Task 5 fix, ruling K1: publish safety) until Task 14 flips Rensei.Hostage.Enabled. Allowed() is
--   Enabled, or else the tests' bypass: RunService:IsStudio() (asked first) AND DataManager.IsNoSave() AND
--   HostageService._TestBypass() (a test swaps it to shut the bypass; it can only make Allowed stricter). Take refuses
--   "disabled" before anything else while not Allowed; Requests.Hostage refuses too. Nothing else starts a session.
-- * Take(Captor, TargetModel) -> ok, reason. The kind is "Bind" for a knocked target, else "Grab". A non-player either
--   side is "not_player" first; a Grab is "todo" until Task 7 (refused before anything is marked). Refused: the next
--   allowed time >= now + RefusedCooldown and LastHostageResult = "<Kind>:<reason>" on the captor's character. Accepted:
--   in the SAME step, no yield, HeldBy on the target and Holding on the captor (one captor per hostage, one hostage per
--   captor), the session made and indexed, its exits connected; then Run on its own thread; true, "started".
-- * Run (the bind, spec §2), each step in a pcall (an error releases "error"):
--     1. the captor's walk locked; S.BindAt = its root; Anims.Bind (fallback) on the captor. No sound: a bind is quiet
--        (PROPOSAL);
--     2. every Heartbeat for BindTime: Broken, the hostage no longer knocked, the captor's root more than BIND_SLACK from
--        S.BindAt, or the captor stunned -> "interrupted";
--     3. the HOLD, in one step: the knock ended at the hostage's own HP, at least MinHealthShare (DownedManager.EndKnock;
--        HeldBy was set at the take, so neither the knock's timer nor a carry's Drop can Recover-heal it first: Task 4
--        review hand-off 1), SecondWindActive cleared (ruling: a bind isn't a recovery); the hostage locked
--        (DownedManager.Lock), stunned (WCS) for its hold time + StunPad, tools unequipped; the pair welded at once
--        (DownedManager.Attach(CC, HC, Offset): the captor is the holder and its client owns the pair, ruling R1; the
--        knock ended in the same step, so the crawl clamp never sees an unwelded, unknocked hostage: hand-off 2); the
--        captor re-locked at LeadSpeed; Anims.Hold / Anims.Held looped at Action4; State "Held", S.Until (os.clock)
--        and HostageUntil (server time) on both; this take counted in Taken (pre-flight P22: only a hold is a re-take);
--        Watch started; Notify both; took_hostage recorded (a real captor, witnessed).
-- * Broken(S) -> outcome | nil (public, a test seam): "left" (either not Present), "died" (either character dead or
--   replaced), "knocked" (the captor knocked; while Held, the hostage knocked: decision 5), "safe" (the captor in a safe
--   zone), "timeout" (Held and os.clock() >= S.Until). Task 6 adds the pair checks, Task 7 the struggle.
-- * Watch(S): every WatchTick while not S.Over, pcall(HostageService.Broken, S); an outcome -> Release(S, outcome), an
--   error -> Release(S, "error").
-- * Release(S, Outcome): THE ONE EXIT of a session (lesson: TakedownService's Release). Guarded by S.Over and the
--   session's identity (ByCaptor[Key(Captor)] == S); every step in its own pcall, so one failing never skips the rest:
--     1. S.Over; unindexed; its connections dropped;
--     2. the weld let go (DownedManager.Detach: PlatformStand off, the hostage's root back to its own client), only when
--        this session welded the pair (S.Attached; Task 5 fix, review I1: a Detach of a pair never attached would set
--        every part of the knocked hostage non-massless -- hair, accessories, a weapon -- and PlatformStand off);
--     3. the hostage: its lock given back when the hold locked it (not while knocked: the knock's lock nests on ours and
--        its Recover gives ours back); its Stun stopped; animations stopped; HeldBy, HostageUntil and Struggle cleared;
--        immune for ImmuneAfter (GrabImmuneUntil, server time, and ImmuneUntil). A hostage still knocked whose
--        KnockedUntil has passed is recovered (DownedManager.Recover: its timer found HeldBy and waited), as Grip does:
--        a knocked player is never left stuck (hand-off 3);
--     4. the captor: the lock given back (also for a character already gone: the entry goes, as TakedownService's F7;
--        not while knocked, as for the hostage); animations stopped; Holding and HostageUntil cleared;
--     5. the captor's cooldown (now + Cooldown) and LastHostageResult = "<Kind>:<Outcome>";
--     6. Notify both ({State = "Free", Outcome, Role}) and a toast;
--     7. the Released listeners (S, Outcome), each in a pcall;
--     8. (Task 11) a running ransom demand of this session is voided.
--   A bind slower than BindTime + SLOW_PAST, or a release whose steps 1-6 take longer than SLOW_RELEASE (the
--   listeners, which may yield, aren't timed), warns its phase timings once.
-- * EXITS (Start): Players.PlayerRemoving -> _Left(P) ("left"); each session's characters' Humanoid.Died and Destroying
--   and a real owner's CharacterAdded -> "died"; game:BindToClose -> _Shutdown() ("shutdown"). Every other end goes
--   through Watch (Broken) or Free.
-- * Free(PL, Outcome) -> bool: that PL's session (either side) released. SessionOf(PL) -> S | nil. Forget(PL, Only):
--   the PL's cooldown (NextAt), immunity (ImmuneUntil) and re-take times (Taken) forgotten; Only (a set, e.g.
--   {ImmuneUntil = true}) forgets just those. Released: listeners (S, Outcome).
--
-- Attributes. Captor's character: Holding (the hostage's name), HostageUntil (server time, while Held),
-- LastHostageResult ("<Kind>:<reason or outcome>"; tests and logs). Hostage's character: HeldBy (the captor's name),
-- HostageUntil, Struggle (Task 7), GrabImmuneUntil (server time). Read: Knocked, KnockedUntil, GrippedBy, Gripping,
-- CarriedBy, Carrying, TakenDownBy, TakingDown, Traversal, SecondWindActive, EnemyType, TownsfolkId, DialogueId.
-- Session times (NextAt, ImmuneUntil, Taken, S.T0, S.Until) are os.clock(); the attributes are server time.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage.Modules
local Rensei = Modules.Data.Rensei
local Hostage = require(Rensei.Hostage)
local Regions = require(Rensei.Regions)
local WCS = require(Modules.Framework.WCS)
local Stun = require(Modules.Skills.States.Stun)
local AttackRunner = require(Modules.Managers.AttackRunner)
local AnimationManager = require(Modules.Managers.AnimationManager)
local DownedManager = require(Modules.Managers.DownedManager)
local EnemyService = require(ServerScriptService.EnemyService)
local DataManager = require(ServerScriptService.CharacterHandler.DataManager)

local HostageService = {}
HostageService.Released = {} -- listeners (S, Outcome)
-- (pre-flight P24) the seam's own copy of the no-save switch: a test swaps THIS (and puts it back) to close the seam;
-- SeamOpen asks DataManager.IsNoSave() as well, so a swap can only close it
HostageService._NoSave = DataManager.IsNoSave
-- (ruling T1-4, tests only) function(PL) -> a list of PLs, or nil for the normal answer; read only while SeamOpen()
HostageService._PartyOf = nil
-- (Task 5 fix, ruling K1) the tests' bypass of the switch, read only in Studio with IsNoSave; a test swaps it to false to
-- see what a live server does. It can only shut the bypass, never open one.
HostageService._TestBypass = function() return true end

local BIND_SLACK = 1.0 -- PROPOSAL (the takedowns' HOLD_SLACK): studs the binding captor's root may move
local SLOW_PAST = 0.5 -- PROPOSAL: seconds past BindTime before a bind's phase timings are warned
local SLOW_RELEASE = 0.25 -- PROPOSAL: seconds a release may take before its timings are warned

local StandIns = {} -- [Model] = PL (tests only; read only while SeamOpen)
local ByCaptor = {} -- [Key] = S
local ByHostage = {} -- [Key] = S
local NextAt = {} -- [Key] = os.clock() from which this captor may take again
local ImmuneUntil = {} -- [Key] = os.clock() until which this PL can't be taken
local Taken = {} -- [hostage Key] = {os.clock() of each hold, any captor} (R8: memory only, no save field)

-- ===== the player-like helpers (the only places that tell a Player from a stand-in) =====
local function Hum(M) return M and M:FindFirstChildOfClass("Humanoid") end
local function Root(M) return M and M:FindFirstChild("HumanoidRootPart") end
local function Torso(M) return M:FindFirstChild("Torso") or M:FindFirstChild("UpperTorso") or Root(M) end
local function Alive(M) local H = Hum(M) return H ~= nil and M.Parent ~= nil and H.Health > 0 end
local function Flat(V) return Vector3.new(V.X, 0, V.Z) end
local function IsPlayer(PL) return typeof(PL) == "Instance" and PL:IsA("Player") end

local function SeamOpen()
	if not RunService:IsStudio() then return false end
	local Ok, NoSave = pcall(DataManager.IsNoSave)
	if not Ok or NoSave ~= true then return false end
	local SeamOk, Seam = pcall(HostageService._NoSave)
	return SeamOk and Seam == true
end

-- (ruling K1) may a session start: the switch, or the tests' bypass (Studio first, then the no-save switch, then the seam)
function HostageService.Allowed()
	if Hostage.Enabled == true then return true end
	if not RunService:IsStudio() then return false end
	local Ok, NoSave = pcall(DataManager.IsNoSave)
	if not Ok or NoSave ~= true then return false end
	local BypassOk, Bypass = pcall(HostageService._TestBypass)
	return BypassOk and Bypass == true
end

local function IsNpc(M)
	return M:GetAttribute("EnemyType") ~= nil or M:GetAttribute("TownsfolkId") ~= nil
		or M:GetAttribute("DialogueId") ~= nil or EnemyService.Active[M] ~= nil
end

-- a real Player, or a stand-in this service registered (and only while the seam is open)
local function IsPL(PL)
	if IsPlayer(PL) then return true end
	return type(PL) == "table" and PL.IsStandIn == true and SeamOpen() and typeof(PL.Character) == "Instance"
		and StandIns[PL.Character] == PL
end

local function Char(PL) return PL and PL.Character end
local function Key(PL) return PL.UserId end
local function Present(PL)
	if IsPlayer(PL) then return PL.Parent == Players end
	local C = Char(PL)
	return C ~= nil and C:IsDescendantOf(workspace)
end
local function DataOf(PL)
	if IsPlayer(PL) then return require(ServerScriptService.ProgressionService).GetData(PL) end
	return PL.Data
end
local function LevelOf(PL)
	if IsPlayer(PL) then
		local D = DataOf(PL)
		return D and D.Level or PL:GetAttribute("Level") -- (P2: Data.Level; the attribute only without a profile)
	end
	return PL.Level
end
local function Notify(PL, Kind, Data)
	if not IsPlayer(PL) or PL.Parent ~= Players then return end
	local Ok, Err = pcall(function() require(ServerScriptService.UIService).Notify(PL, Kind, Data) end)
	if not Ok then warn("HostageService: couldn't notify", PL.Name, Err) end
end
local function Record(PL, Deed, Ctx)
	if not IsPlayer(PL) then return nil end -- (a stand-in has no profile)
	local Ok, Res = pcall(function() return require(ServerScriptService.MoralityService).Record(PL, Deed, false, Ctx) end)
	if not Ok then warn("HostageService: couldn't record", Deed, Res) return nil end
	return Res
end

-- (tests only) a rig stands in for a player; refused outside a Studio TestNoSave session, and for any NPC rig
function HostageService.StandIn(Model, Info)
	if not SeamOpen() then return nil, "seam closed" end
	if typeof(Model) ~= "Instance" or not Model:IsA("Model") or IsNpc(Model) then return nil, "not a stand-in" end
	Info = type(Info) == "table" and Info or {}
	if type(Info.UserId) ~= "number" then return nil, "no UserId" end -- (the sessions are keyed by it)
	local PL = {IsStandIn = true, Character = Model, Name = Info.Name or Model.Name, DisplayName = Info.DisplayName or Model.Name,
		UserId = Info.UserId, Level = Info.Level or 20, Data = {Money = Info.Money or 0, Stats = Info.Stats or {}, Level = Info.Level or 20},
		Party = Info.Party}
	StandIns[Model] = PL
	Model.Destroying:Once(function() if StandIns[Model] == PL then StandIns[Model] = nil end end)
	return PL
end
function HostageService.ClearStandIns() table.clear(StandIns) end

-- the player-like a character belongs to; never one for an NPC (PvP only)
function HostageService.PlayerOf(Model)
	if typeof(Model) ~= "Instance" or not Model:IsA("Model") or IsNpc(Model) then return nil end
	local P = Players:GetPlayerFromCharacter(Model)
	if P then return P end
	return SeamOpen() and StandIns[Model] or nil
end

-- the PL's party in this server, PL first among them (always included). Live: PartyService.Get(P).Members (nil for a
-- solo player: there are no solo parties). Tests: the stand-in's Party, or HostageService._PartyOf while SeamOpen.
function HostageService.PartyOf(PL)
	if HostageService._PartyOf and SeamOpen() then
		local Ok, List = pcall(HostageService._PartyOf, PL)
		if Ok and type(List) == "table" then
			local Out = {PL}
			for _, X in ipairs(List) do if X ~= PL then table.insert(Out, X) end end
			return Out
		end
	end
	local Out = {PL}
	local Members
	if IsPlayer(PL) then
		local Ok, Party = pcall(function() return require(ServerScriptService.PartyService).Get(PL) end)
		Members = Ok and type(Party) == "table" and Party.Members or nil
	else
		Members = PL.Party
	end
	for _, X in ipairs(Members or {}) do if X ~= PL then table.insert(Out, X) end end
	return Out
end

-- A and B are two different PLs in one party (as PartyService.SameParty: never a PL with itself)
function HostageService.SameParty(A, B)
	if A == nil or B == nil or A == B then return false end
	if IsPlayer(A) and IsPlayer(B) and not (HostageService._PartyOf and SeamOpen()) then
		local Ok, Same = pcall(function() return require(ServerScriptService.PartyService).SameParty(A, B) end)
		return Ok and Same == true
	end
	for _, X in ipairs(HostageService.PartyOf(A)) do if X == B then return true end end
	return false
end

-- ===== the gates =====
local function InBox(Pos, CF, Size)
	local P = CF:PointToObjectSpace(Pos)
	return math.abs(P.X) <= Size.X / 2 and math.abs(P.Y) <= Size.Y / 2 and math.abs(P.Z) <= Size.Z / 2
end
local function PosOf(X)
	if X:IsA("BasePart") then return X.Position end
	if X:IsA("Model") then return X:GetPivot().Position end
	return nil
end

function HostageService.InSafeZone(Character)
	local R = Root(Character)
	if not R then return false end
	local Pos = R.Position
	local Ok, Region = pcall(function() return require(ServerScriptService.MoralityService).RegionOf(Character) end)
	local Def = Ok and Regions.Regions[Region]
	if Def and Def.Safe == true then return true end
	for _, P in ipairs(CollectionService:GetTagged(Hostage.SafeTag)) do
		if P:IsA("BasePart") and P:IsDescendantOf(workspace) and InBox(Pos, P.CFrame, P.Size) then return true end
	end
	for _, Tag in ipairs({"RenseiTicketClerk", "RenseiStationGate"}) do
		for _, X in ipairs(CollectionService:GetTagged(Tag)) do
			local At = X:IsDescendantOf(workspace) and PosOf(X)
			if At and (At - Pos).Magnitude <= Hostage.StationSafeRadius then return true end
		end
	end
	for _, X in ipairs(CollectionService:GetTagged("RenseiPlatformTrain")) do
		if X:IsDescendantOf(workspace) then
			local CF, Size
			if X:IsA("Model") then CF, Size = X:GetBoundingBox() elseif X:IsA("BasePart") then CF, Size = X.CFrame, X.Size end
			if CF and InBox(Pos, CF, Size + Vector3.one * (2 * Hostage.TrainMargin)) then return true end
		end
	end
	return false
end

local function Stunned(Character)
	return require(ServerScriptService.TakedownService).Stunned(Character)
end

local function CaptorFree(C)
	local H = Hum(C)
	if not H or not Alive(C) or DownedManager.IsKnocked(C) then return false end
	for _, A in ipairs({"Gripping", "Carrying", "TakingDown", "Holding", "HeldBy"}) do
		if C:GetAttribute(A) then return false end
	end
	if AttackRunner.IsRunning(C) or Stunned(C) then return false end
	return H.FloorMaterial ~= Enum.Material.Air and C:GetAttribute("Traversal") ~= "Swim"
end

local function TargetFree(T)
	if not Alive(T) then return false end
	for _, A in ipairs({"GrippedBy", "CarriedBy", "TakenDownBy", "HeldBy", "Holding", "Gripping", "Carrying", "TakingDown"}) do
		if T:GetAttribute(A) then return false end
	end
	return T:GetAttribute("Traversal") ~= "Swim"
end

local function InDialogue(PL)
	if not IsPlayer(PL) then return false end
	local Ok, Open = pcall(function() return require(ServerScriptService.DialogueService).IsOpen(PL) end)
	return Ok and Open == true
end

local ClearRays = RaycastParams.new()
ClearRays.FilterType = Enum.RaycastFilterType.Exclude
ClearRays.RespectCanCollide = true
ClearRays.IgnoreWater = true

function HostageService.Context(Captor, TargetModel, Kind)
	local Ctx = {Kind = Kind}
	Ctx.IsNpc = IsNpc(TargetModel) -- (first: the PvP rule)
	local Target = HostageService.PlayerOf(TargetModel)
	Ctx.IsPlayer = Target ~= nil
	local C = Char(Captor)
	Ctx.Self = TargetModel == C
	Ctx.Safe = (C ~= nil and HostageService.InSafeZone(C)) or HostageService.InSafeZone(TargetModel)
	Ctx.InDialogue = InDialogue(Captor) or (Target ~= nil and InDialogue(Target))
	Ctx.CaptorLevel = LevelOf(Captor)
	Ctx.TargetLevel = Target and LevelOf(Target) or nil
	local Now = os.clock()
	Ctx.Ready = Now >= (NextAt[Key(Captor)] or 0)
	Ctx.Immune = Target ~= nil and Now < (ImmuneUntil[Key(Target)] or 0)
	Ctx.CaptorFree = C ~= nil and CaptorFree(C)
	Ctx.TargetFree = TargetFree(TargetModel)
	Ctx.TargetKnocked = DownedManager.IsKnocked(TargetModel)
	Ctx.Range = (Kind == "Bind" and Hostage.BindRange or Hostage.GrabRange) + Hostage.RangeSlack
	local CR, TR = Root(C), Root(TargetModel)
	if CR and TR then
		local D = CR.Position - TR.Position
		Ctx.Dist, Ctx.Height = Flat(D).Magnitude, D.Y
		Ctx.Behind = Hostage.Behind(TR.CFrame.LookVector, D, Hostage.AngleSlack)
		ClearRays.FilterDescendantsInstances = {C, TargetModel}
		local A, B = Torso(C).Position, Torso(TargetModel).Position
		Ctx.Clear = workspace:Raycast(A, B - A, ClearRays) == nil
	end
	return Ctx
end

function HostageService.Check(Captor, TargetModel, Kind)
	return Hostage.CheckTake(HostageService.Context(Captor, TargetModel, Kind))
end

-- ===== sessions =====
function HostageService.SessionOf(PL)
	if PL == nil or PL.UserId == nil then return nil end
	return ByCaptor[Key(PL)] or ByHostage[Key(PL)]
end

local function Each(Fn)
	local List = {}
	for _, S in pairs(ByCaptor) do table.insert(List, S) end
	for _, S in ipairs(List) do Fn(S) end
end

local function Step(What, Fn, ...)
	local Ok, Err = pcall(Fn, ...)
	if not Ok then warn("HostageService: " .. What .. " failed:", Err) end
	return Ok
end

local function StopAnim(M, A)
	if not M then return end
	AnimationManager.Stop(M, A.Name)
	AnimationManager.Stop(M, A.Fallback)
end

local function Toast(PL, Text) Notify(PL, "Toast", {Text = Text}) end

-- the one exit (see the header). Returns true when this call released the session.
local function Release(S, Outcome)
	if S.Over or ByCaptor[Key(S.Captor)] ~= S then return false end
	local R0 = os.clock()
	-- 1. over, unindexed, its connections dropped
	S.Over = true
	S.Outcome = Outcome
	if ByCaptor[Key(S.Captor)] == S then ByCaptor[Key(S.Captor)] = nil end
	if ByHostage[Key(S.Hostage)] == S then ByHostage[Key(S.Hostage)] = nil end
	Step("dropping the connections", function()
		for _, Conn in ipairs(S.Conns) do Conn:Disconnect() end
		table.clear(S.Conns)
	end)
	local CC, HC = S.CC, S.HC
	local NowServer = workspace:GetServerTimeNow()
	-- 2. the weld let go
	if S.Attached then Step("letting the hostage go", DownedManager.Detach, HC) end
	-- 3. the hostage
	Step("unlocking the hostage", function()
		if S.HLocked and (HC.Parent == nil or not DownedManager.IsKnocked(HC)) then DownedManager.Lock(HC, false) end
	end)
	if S.Stun then Step("stopping the hostage's stun", function() S.Stun:Stop() end) end
	Step("stopping the hostage's animations", function()
		if HC.Parent then StopAnim(HC, Hostage.Anims.Held) StopAnim(HC, Hostage.Anims.Struggle) end
	end)
	Step("clearing the hostage", function()
		HC:SetAttribute("HeldBy", nil)
		HC:SetAttribute("HostageUntil", nil)
		HC:SetAttribute("Struggle", nil)
		HC:SetAttribute("GrabImmuneUntil", NowServer + Hostage.ImmuneAfter)
	end)
	ImmuneUntil[Key(S.Hostage)] = os.clock() + Hostage.ImmuneAfter
	Step("recovering a knock that ran out", function()
		if HC.Parent and Alive(HC) and DownedManager.IsKnocked(HC)
			and (HC:GetAttribute("KnockedUntil") or 0) <= workspace:GetServerTimeNow() then
			DownedManager.Recover(HC)
		end
	end)
	-- 4. the captor
	Step("unlocking the captor", function()
		if S.CLocked and (CC.Parent == nil or not DownedManager.IsKnocked(CC)) then DownedManager.Lock(CC, false) end
	end)
	Step("stopping the captor's animations", function()
		if CC.Parent then StopAnim(CC, Hostage.Anims.Bind) StopAnim(CC, Hostage.Anims.Hold) end
	end)
	Step("clearing the captor", function()
		CC:SetAttribute("Holding", nil)
		CC:SetAttribute("HostageUntil", nil)
	end)
	-- 5. the cooldown and the result
	NextAt[Key(S.Captor)] = os.clock() + Hostage.Cooldown
	Step("writing the result", function() CC:SetAttribute("LastHostageResult", S.Kind .. ":" .. tostring(Outcome)) end)
	-- 6. both told
	Step("notifying", function()
		Notify(S.Captor, "Hostage", {State = "Free", Outcome = Outcome, Role = "Captor"})
		Notify(S.Hostage, "Hostage", {State = "Free", Outcome = Outcome, Role = "Hostage"})
		Toast(S.Captor, ("%s is free."):format(S.Hostage.DisplayName or S.Hostage.Name)) -- PROPOSAL (text)
		Toast(S.Hostage, "You're free.") -- PROPOSAL (text)
	end)
	local R6 = os.clock() -- (steps 1-6: the listeners below may yield, so they aren't timed)
	-- 7. the listeners
	for _, Fn in ipairs(HostageService.Released) do Step("a Released listener", Fn, S, Outcome) end
	-- 8. (Task 11) a running ransom demand of this session is voided here
	-- phase timings of a slow bind or a slow release
	local Now = os.clock()
	if (S.State ~= "Held" and Now - S.T0 > Hostage.BindTime + SLOW_PAST) or R6 - R0 > SLOW_RELEASE then
		local function At(X) return X and ("%.2f"):format(X - S.T0) or "-" end
		warn(("HostageService: a slow hold (%s, %s): take 0, bind start %s, held %s, release start %s, release done %s s"):format(
			S.Kind, tostring(Outcome), At(S.BindStarted), At(S.HeldAt), At(R0), At(Now)))
	end
	return true
end

-- the session's ends, a test seam: see the header
function HostageService.Broken(S)
	if not Present(S.Captor) or not Present(S.Hostage) then return "left" end
	if not Alive(S.CC) or not Alive(S.HC) or Char(S.Captor) ~= S.CC or Char(S.Hostage) ~= S.HC then return "died" end
	if DownedManager.IsKnocked(S.CC) then return "knocked" end
	if S.State == "Held" and DownedManager.IsKnocked(S.HC) then return "knocked" end
	if HostageService.InSafeZone(S.CC) then return "safe" end
	if S.State == "Held" and os.clock() >= S.Until then return "timeout" end
	return nil
end

local function Watch(S)
	while not S.Over do
		task.wait(Hostage.WatchTick)
		if S.Over then return end
		local Ok, Outcome = pcall(HostageService.Broken, S)
		if not Ok then
			warn("HostageService: Broken failed:", Outcome)
			Release(S, "error")
		elseif Outcome then
			Release(S, Outcome)
		end
	end
end

-- re-takes of this hostage within RetakeWindow (any captor), the old ones dropped
local function Retakes(HKey)
	local Now, Out = os.clock(), {}
	for _, T in ipairs(Taken[HKey] or {}) do
		if Now - T < Hostage.RetakeWindow then table.insert(Out, T) end
	end
	Taken[HKey] = Out
	return #Out
end

-- step 1: the bind starts
local function BindStart(S)
	DownedManager.Lock(S.CC, true)
	S.CLocked = true
	S.BindAt = Root(S.CC).Position
	S.BindStarted = os.clock()
	local A = Hostage.Anims.Bind
	Step("the bind animation", AnimationManager.Play, S.CC, A.Name, {Priority = Enum.AnimationPriority.Action4, Fallback = A.Fallback})
end

-- step 2: true when the bind must end as an interrupt
local function BindBroken(S)
	if HostageService.Broken(S) then return true end
	if not DownedManager.IsKnocked(S.HC) then return true end -- (a bind needs a knocked hostage)
	local CR = Root(S.CC)
	if not CR or (CR.Position - S.BindAt).Magnitude > BIND_SLACK then return true end
	return Stunned(S.CC)
end

-- step 3: the hold, in one step (no yield until Watch is running)
local function Hold(S)
	local CC, HC = S.CC, S.HC
	if not DownedManager.EndKnock(HC, Hostage.MinHealthShare) then error("the knock couldn't be ended") end
	if HC:GetAttribute("SecondWindActive") then HC:SetAttribute("SecondWindActive", nil) end
	local HKey = Key(S.Hostage)
	local N = Retakes(HKey)
	local Time = Hostage.HoldTimeFor(N)
	local H = Hum(HC)
	S.Saved = {WalkSpeed = H.WalkSpeed, JumpHeight = H.JumpHeight} -- (what Lock saves too; kept for the log)
	DownedManager.Lock(HC, true)
	S.HLocked = true
	local HWC = WCS.Character.GetCharacterFromInstance(HC)
	if HWC then
		S.Stun = Stun.new(HWC)
		S.Stun:Start(Time + Hostage.StunPad)
	end
	Step("putting the hostage's tools away", function() H:UnequipTools() end)
	if not DownedManager.Attach(CC, HC, Hostage.Offset) then error("the weld failed") end
	S.Attached = true
	DownedManager.Lock(CC, false)
	DownedManager.Lock(CC, true, Hostage.LeadSpeed)
	StopAnim(CC, Hostage.Anims.Bind)
	Step("the hold animation", AnimationManager.Play, CC, Hostage.Anims.Hold.Name,
		{Looped = true, Priority = Enum.AnimationPriority.Action4, Fallback = Hostage.Anims.Hold.Fallback})
	Step("the held animation", AnimationManager.Play, HC, Hostage.Anims.Held.Name,
		{Looped = true, Priority = Enum.AnimationPriority.Action4, Fallback = Hostage.Anims.Held.Fallback})
	local Now = os.clock()
	S.State = "Held"
	S.HeldAt = Now
	S.Until = Now + Time
	local UntilServer = workspace:GetServerTimeNow() + Time
	CC:SetAttribute("HostageUntil", UntilServer)
	HC:SetAttribute("HostageUntil", UntilServer)
	table.insert(Taken[HKey], Now) -- (P22: counted once the hold is Held)
	task.spawn(Watch, S)
	if Now - S.T0 > Hostage.BindTime + SLOW_PAST then
		warn(("HostageService: a slow bind: take 0, bind start %.2f, held %.2f s"):format((S.BindStarted or Now) - S.T0, Now - S.T0))
	end
	-- each told its own Role (pre-flight P28)
	for _, X in ipairs({{S.Captor, "Captor"}, {S.Hostage, "Hostage"}}) do
		Notify(X[1], "Hostage", {State = "Held", Role = X[2], Captor = S.Captor.Name, Hostage = S.Hostage.Name, Until = UntilServer})
	end
	Record(S.Captor, "took_hostage", {Witness = true})
end

local function Run(S)
	local Ok, Err = pcall(BindStart, S)
	if not Ok then
		warn("HostageService: the bind couldn't start:", Err)
		Release(S, "error")
		return
	end
	local RunOk, RunErr = pcall(function()
		while true do
			RunService.Heartbeat:Wait()
			if S.Over then return end
			if BindBroken(S) then Release(S, "interrupted") return end
			if os.clock() - S.BindStarted >= Hostage.BindTime then break end
		end
		if S.Over then return end
		Hold(S)
	end)
	if not RunOk then
		warn("HostageService: the hold failed:", RunErr)
		Release(S, "error")
	end
end

-- a session's characters' own ends: died, destroyed, or a real owner's new character
local function Connect(S)
	local function Died() Release(S, "died") end
	for _, M in ipairs({S.CC, S.HC}) do
		local H = Hum(M)
		if H then table.insert(S.Conns, H.Died:Connect(Died)) end
		table.insert(S.Conns, M.Destroying:Connect(Died))
	end
	for _, PL in ipairs({S.Captor, S.Hostage}) do
		if IsPlayer(PL) then table.insert(S.Conns, PL.CharacterAdded:Connect(Died)) end
	end
end

function HostageService.Take(Captor, TargetModel)
	if not HostageService.Allowed() then return false, "disabled" end -- (ruling K1: switched off until Task 14)
	if not IsPL(Captor) then return false, "not_player" end
	local CC = Char(Captor)
	if not (Root(CC) and typeof(TargetModel) == "Instance" and TargetModel:IsA("Model")) then return false, "missing" end
	if IsNpc(CC) then return false, "not_player" end -- (never an NPC captor)
	local Kind = DownedManager.IsKnocked(TargetModel) and "Bind" or "Grab"
	-- (review M4) a non-player target is refused before the Context's rays and scans
	local Ctx = (IsNpc(TargetModel) or not HostageService.PlayerOf(TargetModel)) and {IsNpc = true}
		or HostageService.Context(Captor, TargetModel, Kind)
	local Ok, Reason
	if Ctx.IsNpc or not Ctx.IsPlayer then
		Ok, Reason = false, "not_player" -- (first: the PvP rule, before the grab's placeholder)
	elseif Kind == "Grab" then
		Ok, Reason = false, "todo" -- (Task 7 builds the grab)
	else
		Ok, Reason = Hostage.CheckTake(Ctx)
	end
	if not Ok then
		local K = Key(Captor)
		NextAt[K] = math.max(NextAt[K] or 0, os.clock() + Hostage.RefusedCooldown) -- (never shortens a cooldown)
		CC:SetAttribute("LastHostageResult", Kind .. ":" .. tostring(Reason))
		return false, Reason
	end
	local Target = HostageService.PlayerOf(TargetModel)
	-- the same step as the last check, no yield between: one captor per hostage, one hostage per captor
	TargetModel:SetAttribute("HeldBy", Captor.Name)
	CC:SetAttribute("Holding", Target.Name)
	local S = {Id = HttpService:GenerateGUID(false), Captor = Captor, Hostage = Target, CC = CC, HC = TargetModel,
		Kind = Kind, State = "Binding", T0 = os.clock(), Until = nil, Struggle = 0, Over = false, Conns = {}, Saved = {}}
	ByCaptor[Key(Captor)] = S
	ByHostage[Key(Target)] = S
	Connect(S)
	task.spawn(Run, S)
	return true, "started"
end

function HostageService.Free(PL, Outcome)
	local S = HostageService.SessionOf(PL)
	if not S then return false end
	return Release(S, Outcome or "freed")
end

function HostageService.Forget(PL, Only)
	if PL == nil or PL.UserId == nil then return end
	local K = Key(PL)
	if not Only or Only.NextAt then NextAt[K] = nil end
	if not Only or Only.ImmuneUntil then ImmuneUntil[K] = nil end
	if not Only or Only.Taken then Taken[K] = nil end
end

-- (Task 7 builds the struggle, Task 8 the captor menu; Requests.Hostage already routes them)
function HostageService.Struggle(_PL, _Count) end
function HostageService.Menu(_Captor, _Choice, _Arg) end

-- the PlayerRemoving handler (a test seam): every session of that PL released as "left" (its cooldown, immunity and
-- re-take times are kept: a rejoin doesn't reset them)
function HostageService._Left(PL)
	Each(function(S)
		if S.Captor == PL or S.Hostage == PL then Release(S, "left") end
	end)
end

-- the BindToClose handler (a test seam): every session released as "shutdown"
function HostageService._Shutdown()
	Each(function(S) Release(S, "shutdown") end)
end

local Started = false
function HostageService.Start()
	if Started then return end
	Started = true
	Players.PlayerRemoving:Connect(HostageService._Left)
	game:BindToClose(HostageService._Shutdown)
end

return HostageService

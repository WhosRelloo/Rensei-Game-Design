-- CombatDirector (server): coordinated enemy squads (owner prompt "Advanced Swarm NPC Combat AI", 2026-10-18).
--
-- ENCOUNTERS: one per target player character. An enemy belongs to at most one encounter: its current target's
-- (EnemyService's brain reports the target every tick through SetTarget). Encounters are created on the first
-- member and dissolved when empty, or when the target dies, is knocked, leaves or is removed.
--
-- ATTACK TOKEN: each encounter has at most one Holder. Only the holder may hurt that player: EnemyService only
-- starts attacks / casts while Holds() is true, and DamageManager drops any enemy hit on a player whose
-- encounter token that enemy doesn't hold (MayHit). Exceptions: a short Grace after a NORMAL release (the last
-- swing of a finished turn), and a reactive counter the player's own hit triggered (AllowReactive). After a
-- FORCED release (knockback, death, long stun...) the old holder gets no grace: its remaining hitboxes,
-- projectiles, traps and explosions can no longer hurt that player.
-- Grant / release never yield, so every token change is atomic for the rest of the server.
--
-- HANDOFF (forced unless noted): the holder dies or is removed; is knocked / gripped / carried; is hit by a
-- knockback >= KnockbackHandoff; stays stunned >= StunHandoff (parry, guard break, long hitstun); is separated
-- (beyond attack range + Separation for SeparatedFor seconds: stuck or knocked away); starts swimming; becomes
-- passive; switches target. Tenure (normal): after Tenure seconds, at a moment it isn't mid-attack, if another
-- member is ready. The next holder is granted HandoffDelay after the release, and only once the old holder's
-- AttackRunner has stopped (or is dead), so two attacks never overlap; it then waits CommitDelay before striking.
--
-- SELECTION: eligible members (alive, not stunned / knocked / passive / swimming / recovering) scored by distance
-- beyond their own waiting ring (melee ring, or the ranged ring for casters / gunners), +BehindPenalty when behind
-- the player, +RecentPenalty if it had a turn in the last RecentFor seconds, plus its personality's Bias, minus a
-- fairness credit for time since its last turn (FairnessWeight per second, up to FairnessCap). Lowest score wins,
-- so brawlers and casters take turns.
--
-- POSITIONS: every SlotTick each waiting member gets a point on a ring around the player (TuningConfig.Squad.Slots:
-- angles relative to the holder's side, never in the holder's lane; slow Drift = circling). The best next
-- candidate gets the closer Prepare spot. Points are pulled in front of walls (raycast) and must have ground.
-- Members keep their slot unless another is SlotHysteresis degrees better (no jitter). Members beyond
-- MaxMembers wait on the outer Reserve ring.
--
-- HUMAN SHIELD (hostages Task 9): CanStrike is false while the line to the target runs through a hostage the target
-- holds in front of it (HostageService.LineBlocked), so a holder in front holds its attack.
--
-- DEBUG (Studio only): TuningConfig.Squad.Debug or workspace attribute SquadDebug = true draws slot markers and
-- role labels. Every member always carries attributes SquadEncounter / SquadRole / SquadReason.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)
local WCS = require(ReplicatedStorage.Modules.Framework.WCS)
local AttackRunner = require(ReplicatedStorage.Modules.Managers.AttackRunner)
local Stun = require(ReplicatedStorage.Modules.Skills.States.Stun)

local Cfg = Tuning.Squad

local CombatDirector = {}

local Members = {} -- [Rig] = member record (plain tables; removed on death / despawn)
local Encounters = {} -- [Target character] = encounter record
local Reactive = {} -- [Rig] = {Victim, Until}
local NextId = 0
local Stats = {Allowed = 0, Blocked = 0, Grants = 0, Releases = {}, Conflicts = 0}
CombatDirector.Stats = Stats

local function Now() return os.clock() end
local function Flat(V) return Vector3.new(V.X, 0, V.Z) end
local function Root(M) return M and M:FindFirstChild("HumanoidRootPart") end
local function Alive(M)
	local H = M and M.Parent and M:FindFirstChildOfClass("Humanoid")
	return H ~= nil and H.Health > 0
end
local function Stunned(Rig)
	local C = WCS.Character.GetCharacterFromInstance(Rig)
	return C ~= nil and C:HasStatusEffects({Stun})
end
local function Disabled(Rig)
	return Rig:GetAttribute("Knocked") or Rig:GetAttribute("GrippedBy") or Rig:GetAttribute("CarriedBy")
		or Rig:GetAttribute("Gripping") or Rig:GetAttribute("Carrying")
end

local function SetAttrs(Rig, Enc, Role, Reason)
	if not Rig.Parent then return end
	Rig:SetAttribute("SquadEncounter", Enc and Enc.Id or nil)
	Rig:SetAttribute("SquadRole", Role)
	if Reason then Rig:SetAttribute("SquadReason", Reason) end
end

-- ===== membership =====

-- EnemyService.Spawn: Info = {Range, Type}
function CombatDirector.Register(Rig, Info)
	if Members[Rig] then return end
	local PName = Cfg.PersonalityOf[Info.Type or ""] or (Info.Ranged and "Gunner") or "Aggressor"
	local P = Cfg.Personalities[PName] or Cfg.Personalities.Aggressor
	Members[Rig] = {
		Rig = Rig, Range = Info.Range or 5, Personality = PName, P = P, Ranged = P.Ranged or Info.Ranged or false,
		Encounter = nil, RecoverUntil = 0, LastHeldAt = -1e9, LastCastAt = -1e9, Phase = math.random() * math.pi * 2,
		SlotIndex = nil, SlotPos = nil, SepSince = nil, StunSince = nil,
	}
	Rig:SetAttribute("SquadPersonality", PName)
	Rig.AncestryChanged:Connect(function(_, Parent)
		if not Parent then CombatDirector.Unregister(Rig, "Removed") end
	end)
end

local function Release(Enc, Reason, Forced)
	local R = Enc.Holder
	if not R then return end
	Enc.Holder = nil
	Enc.ReleasedAt = Now()
	Enc.LastHolder = R
	Enc.Reason = Reason
	Stats.Releases[Reason] = (Stats.Releases[Reason] or 0) + 1
	local M = Members[R]
	if M then
		M.LastHeldAt = Now()
		if Forced then M.RecoverUntil = Now() + Cfg.Recover end
	end
	if Forced then
		Enc.GraceRig, Enc.GraceUntil = nil, 0
	else
		Enc.GraceRig, Enc.GraceUntil = R, Now() + Cfg.Grace
	end
	if R.Parent then SetAttrs(R, M and M.Encounter, Forced and "Recover" or "Flank", "Lost token: " .. Reason) end
end

local function Grant(Enc, Rig, Why)
	if Enc.Holder then Stats.Conflicts += 1 return false end -- (never happens: grants only run with no holder)
	Enc.Holder = Rig
	Enc.GrantedAt = Now()
	Enc.GraceRig, Enc.GraceUntil = nil, 0
	Stats.Grants += 1
	local M = Members[Rig]
	if M then M.SepSince, M.StunSince = nil, nil end
	SetAttrs(Rig, Enc, "Attacker", "Took token: " .. Why)
	return true
end

local function Leave(Rig, Reason)
	local M = Members[Rig]
	local Enc = M and M.Encounter
	if not Enc then return end
	if Enc.Holder == Rig then Release(Enc, Reason, true) end
	if Enc.GraceRig == Rig then Enc.GraceRig = nil end
	Enc.Members[Rig] = nil
	Enc.Count -= 1
	M.Encounter, M.SlotIndex, M.SlotPos = nil, nil, nil
	if Rig.Parent then SetAttrs(Rig, nil, nil, "Left: " .. Reason) end
	if Enc.Count <= 0 then Encounters[Enc.Target] = nil end
end

function CombatDirector.Unregister(Rig, Reason)
	if not Members[Rig] then return end
	Leave(Rig, Reason or "Unregistered")
	Members[Rig] = nil
	Reactive[Rig] = nil
end

-- EnemyService brain, every tick: the enemy's current target (nil = none). Joins / leaves encounters.
function CombatDirector.SetTarget(Rig, Target)
	local M = Members[Rig]
	if not M or not Cfg.Enabled then return end
	if M.Encounter and M.Encounter.Target == Target then return end
	if M.Encounter then Leave(Rig, Target and "Switched target" or "Lost target") end
	if not Target then return end
	local Enc = Encounters[Target]
	if not Enc then
		NextId += 1
		Enc = {Id = NextId, Target = Target, Members = {}, Count = 0, Holder = nil, GrantedAt = 0, ReleasedAt = -1e9,
			LastHolder = nil, GraceRig = nil, GraceUntil = 0, Reason = ""}
		Encounters[Target] = Enc
	end
	Enc.Members[Rig] = true
	Enc.Count += 1
	M.Encounter = Enc
	SetAttrs(Rig, Enc, "Flank", "Joined")
end

-- ===== queries for EnemyService =====

function CombatDirector.Holds(Rig, Target)
	local M = Members[Rig]
	if not M then return true end -- (not a squad enemy: unrestricted)
	if not Cfg.Enabled then return true end
	local Enc = M.Encounter
	return Enc ~= nil and Enc.Holder == Rig and (Target == nil or Enc.Target == Target)
end

-- (hostages Task 9, spec §3) the line from Rig to Target runs through a hostage: HostageService.LineBlocked, looked up
-- at call time (HostageService requires EnemyService, which requires this module), in a pcall
local function LineBlocked(Rig, Target)
	local HS = Target ~= nil and game:GetService("ServerScriptService"):FindFirstChild("HostageService")
	if not HS then return false end
	local Ok, Blocked = pcall(function() return require(HS).LineBlocked(Rig, Target) end)
	return Ok and Blocked == true
end

-- the holder may start a hit (past its commit delay); never through a hostage held in front of its target (the human
-- shield: it holds its attack, and the tenure handoff gives the turn to a member that isn't in front)
function CombatDirector.CanStrike(Rig, Target)
	if not CombatDirector.Holds(Rig, Target) then return false end
	if LineBlocked(Rig, Target) then return false end
	local M = Members[Rig]
	return not M or not M.Encounter or Now() >= M.Encounter.GrantedAt + Cfg.CommitDelay
end

function CombatDirector.NoteCast(Rig)
	local M = Members[Rig]
	if M then M.LastCastAt = Now() end
end

-- where a waiting member should stand (nil = no slot; it holds its ground)
function CombatDirector.SlotFor(Rig)
	local M = Members[Rig]
	return M and M.SlotPos or nil
end

-- DamageManager: a strong knockback on a holder hands the token on at once
function CombatDirector.OnKnockback(Victim, Force)
	local M = Members[Victim]
	local Enc = M and M.Encounter
	if Enc and Enc.Holder == Victim and (Force or 0) >= Cfg.KnockbackHandoff then Release(Enc, "Knockback", true) end
end

-- DamageManager: Rig's counter was triggered by Victim's own hit -> its riposte may land without the token
function CombatDirector.AllowReactive(Rig, Victim)
	if Members[Rig] then Reactive[Rig] = {Victim = Victim, Until = Now() + Cfg.ReactiveWindow} end
end

-- DamageManager: may this enemy's hit hurt this player?
function CombatDirector.MayHit(Character, Victim)
	if not Cfg.Enabled then return true end
	local M = Members[Character]
	if not M or not Players:GetPlayerFromCharacter(Victim) then return true end
	local Enc = Encounters[Victim]
	if not Enc then
		Stats.Allowed += 1
		return true -- (the player isn't anyone's target: incidental contact)
	end
	local R = Reactive[Character]
	local Ok = Enc.Holder == Character
		or (Enc.GraceRig == Character and Now() < Enc.GraceUntil)
		or (R ~= nil and R.Victim == Victim and Now() < R.Until)
	if Ok then Stats.Allowed += 1 else Stats.Blocked += 1 end
	return Ok
end

-- ===== selection =====

local function Eligible(M, Enc)
	local Rig = M.Rig
	if not Alive(Rig) or Disabled(Rig) then return false end
	if Rig:GetAttribute("AIPassive") or Rig:GetAttribute("Traversal") == "Swim" then return false end
	if Now() < M.RecoverUntil or Stunned(Rig) then return false end
	return Root(Rig) ~= nil and Root(Enc.Target) ~= nil
end

local function Score(M, Enc)
	local R, TR = Root(M.Rig), Root(Enc.Target)
	local To = Flat(R.Position - TR.Position)
	-- distance beyond this member's own waiting ring: a caster on its ring is as ready as a brawler on the melee ring
	local Reach = M.Ranged and Cfg.Ring.Ranged * (M.P.Ring or 1) * 0.8 or Cfg.Ring.Melee * (M.P.Ring or 1)
	local S = math.max(0, To.Magnitude - Reach) + (M.P.Bias or 0)
	-- fairness: the longer since a member's last turn, the better its claim (so casters aren't shut out by two brawlers)
	S -= math.min(Now() - M.LastHeldAt, Cfg.FairnessCap or 8) * (Cfg.FairnessWeight or 0.6)
	local Look = Flat(TR.CFrame.LookVector)
	if To.Magnitude > 0.1 and Look.Magnitude > 0.1 and To.Unit:Dot(Look.Unit) < -0.3 then S += Cfg.BehindPenalty end
	if Now() - M.LastHeldAt < Cfg.RecentFor then S += Cfg.RecentPenalty end
	return S
end

local function Best(Enc, Except)
	local BestM, BestS = nil, math.huge
	for Rig in pairs(Enc.Members) do
		local M = Members[Rig]
		if M and Rig ~= Except and Eligible(M, Enc) then
			local S = Score(M, Enc)
			if S < BestS then BestM, BestS = M, S end
		end
	end
	return BestM, BestS
end

-- ===== the per-encounter tick =====

local function TargetValid(T)
	return T.Parent ~= nil and Alive(T) and not T:GetAttribute("Knocked") and Players:GetPlayerFromCharacter(T) ~= nil
end

local function Dissolve(Enc, Reason)
	local List = {}
	for Rig in pairs(Enc.Members) do table.insert(List, Rig) end
	for _, Rig in ipairs(List) do Leave(Rig, Reason) end
	Encounters[Enc.Target] = nil
end

local function TickEncounter(Enc)
	if not TargetValid(Enc.Target) then Dissolve(Enc, "Target gone") return end
	-- members that died / vanished without telling us
	for Rig in pairs(Enc.Members) do
		if not Members[Rig] or not Alive(Rig) then Leave(Rig, "Dead") end
	end
	if not Encounters[Enc.Target] then return end
	local H = Enc.Holder
	if H then
		local M = Members[H]
		local TR, HR = Root(Enc.Target), Root(H)
		if not M or not Alive(H) or not HR then Release(Enc, "Dead", true)
		elseif Disabled(H) then Release(Enc, "Knocked out", true)
		elseif H:GetAttribute("AIPassive") then Release(Enc, "Passive", true)
		elseif H:GetAttribute("Traversal") == "Swim" then Release(Enc, "Swimming", true)
		else
			-- a long stun (parry, guard break, long hitstun)
			if Stunned(H) then M.StunSince = M.StunSince or Now() else M.StunSince = nil end
			-- separated: too far to keep engaging (stuck, or knocked away)
			local Dist = TR and (Flat(HR.Position - TR.Position)).Magnitude or math.huge
			if Dist > M.Range + Cfg.Separation then M.SepSince = M.SepSince or Now() else M.SepSince = nil end
			local Busy = AttackRunner.IsRunning(H) or Now() - M.LastCastAt < Cfg.CastLinger
			if M.StunSince and Now() - M.StunSince >= Cfg.StunHandoff then Release(Enc, "Stunned", true)
			elseif M.SepSince and Now() - M.SepSince >= Cfg.SeparatedFor then Release(Enc, "Separated", true)
			elseif not Busy and Now() - Enc.GrantedAt >= Cfg.Tenure * (M.P.Tenure or 1) and Best(Enc, H) then
				Release(Enc, "Turn over", false)
			end
		end
	end
	if not Enc.Holder and Now() >= Enc.ReleasedAt + Cfg.HandoffDelay then
		-- never while the previous attacker's swing / cast is still running (it can't hurt anyone after a forced
		-- release anyway, but the next one shouldn't start on top of it); give up waiting after 2s
		local Prev = Enc.LastHolder
		local PrevBusy = Prev and Alive(Prev) and AttackRunner.IsRunning(Prev) and Now() - Enc.ReleasedAt < 2
		if not PrevBusy then
			local M = Best(Enc)
			if M then Grant(Enc, M.Rig, Enc.LastHolder and ("handoff after " .. Enc.Reason) or "first in") end
		end
	end
end

-- ===== positions =====

local WallParams = RaycastParams.new()
WallParams.FilterType = Enum.RaycastFilterType.Exclude
local function WallFilter()
	local List = {}
	local World = workspace:FindFirstChild("World")
	if World then
		for _, N in ipairs({"Live", "Visuals"}) do if World:FindFirstChild(N) then table.insert(List, World[N]) end end
	end
	WallParams.FilterDescendantsInstances = List
end

-- a reachable point near the wanted one: pulled in front of walls, and with ground under it
local function Reachable(From, Want)
	local Dir = Want - From
	local Hit = workspace:Raycast(From, Dir, WallParams)
	local P = Want
	if Hit then
		local Back = Hit.Position - Dir.Unit * 2
		if (Flat(Back - From)).Magnitude < 3 then return nil end
		P = Back
	end
	local Down = workspace:Raycast(P + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), WallParams)
	if not Down then return nil end
	return Vector3.new(P.X, Down.Position.Y + 3, P.Z)
end

local function AngleOf(V) return math.atan2(V.X, V.Z) end
local function AngleDiff(A, B)
	local D = (A - B + math.pi) % (2 * math.pi) - math.pi
	return math.abs(D)
end

local function SlotEncounter(Enc, T)
	local TR = Root(Enc.Target)
	if not TR then return end
	local Center = TR.Position
	-- the side the attack comes from: the holder's, else the player's front
	local BaseAngle
	local HR = Enc.Holder and Root(Enc.Holder)
	if HR and (Flat(HR.Position - Center)).Magnitude > 0.5 then
		BaseAngle = AngleOf(Flat(HR.Position - Center))
	else
		local L = Flat(TR.CFrame.LookVector)
		BaseAngle = AngleOf(L.Magnitude > 0.1 and L or Vector3.new(0, 0, 1))
	end
	-- the waiting members, in a stable order; the best next attacker prepares
	local Waiting = {}
	for Rig in pairs(Enc.Members) do
		if Rig ~= Enc.Holder and Members[Rig] then table.insert(Waiting, Members[Rig]) end
	end
	table.sort(Waiting, function(A, B) return A.Phase < B.Phase end)
	local Next = Best(Enc, Enc.Holder)
	local Taken = {}
	local Inner = #Cfg.Slots
	for I, M in ipairs(Waiting) do
		local R = Root(M.Rig)
		if R then
			local MyAngle = AngleOf(Flat(R.Position - Center))
			local Role, Angle, Radius
			if Now() < M.RecoverUntil then
				Role = "Recover"
			end
			if M == Next and not Role then
				-- prepare: the closer spot beside the holder's lane, on the member's own side
				local Side = AngleDiff(MyAngle, BaseAngle + math.rad(45)) < AngleDiff(MyAngle, BaseAngle - math.rad(45)) and 1 or -1
				Role, Angle, Radius = "Prepare", BaseAngle + Side * math.rad(45), M.Ranged and Cfg.Ring.Ranged or Cfg.Ring.Prepare
			elseif I > Cfg.MaxMembers then
				Role = Role or "Reserve"
				Angle, Radius = MyAngle, Cfg.Ring.Reserve * 1.6
			else
				-- the free slot nearest this member's current angle; keep the old one unless clearly worse
				local BestIdx, BestD = nil, math.huge
				for Idx, Deg in ipairs(Cfg.Slots) do
					if not Taken[Idx] then
						local A = BaseAngle + math.rad(Deg)
						local D = AngleDiff(MyAngle, A)
						if Idx == M.SlotIndex then D -= math.rad(Cfg.SlotHysteresis) end
						if D < BestD then BestIdx, BestD = Idx, D end
					end
				end
				if BestIdx then
					Taken[BestIdx] = true
					M.SlotIndex = BestIdx
					Angle = BaseAngle + math.rad(Cfg.Slots[BestIdx]) + math.rad(Cfg.Drift) * math.sin(T * Cfg.DriftSpeed + M.Phase)
					Radius = M.Ranged and Cfg.Ring.Ranged or Cfg.Ring.Melee * (M.P.Ring or 1)
					Role = Role or (BestIdx <= Inner and "Flank" or "Reserve")
				else
					Angle, Radius, Role = MyAngle, Cfg.Ring.Reserve, Role or "Reserve"
				end
			end
			if Role == "Recover" then Radius = math.max(Radius or 0, Cfg.Ring.Reserve) Angle = Angle or MyAngle end
			local Want = Center + Vector3.new(math.sin(Angle), 0, math.cos(Angle)) * Radius
			M.SlotPos = Reachable(Center + Vector3.new(0, 1, 0), Want) or M.SlotPos
			SetAttrs(M.Rig, Enc, Role)
		end
	end
	if Enc.Holder and Members[Enc.Holder] then Members[Enc.Holder].SlotPos = nil end
end

-- ===== debug drawing (Studio only) =====
local DebugFolder
local function DebugOn()
	return RunService:IsStudio() and (Cfg.Debug or workspace:GetAttribute("SquadDebug") == true)
end
local RoleColor = {Attacker = Color3.fromRGB(230, 60, 50), Prepare = Color3.fromRGB(240, 190, 60), Flank = Color3.fromRGB(80, 160, 240),
	Reserve = Color3.fromRGB(150, 150, 150), Recover = Color3.fromRGB(170, 90, 220)}
local function DrawDebug()
	if not DebugOn() then
		if DebugFolder then DebugFolder:Destroy() DebugFolder = nil end
		for Rig in pairs(Members) do local B = Rig:FindFirstChild("SquadDebugLabel") if B then B:Destroy() end end
		return
	end
	if not DebugFolder or not DebugFolder.Parent then
		DebugFolder = Instance.new("Folder")
		DebugFolder.Name = "SquadDebug"
		DebugFolder.Parent = workspace
	end
	DebugFolder:ClearAllChildren()
	for Rig, M in pairs(Members) do
		local Role = Rig:GetAttribute("SquadRole") or "-"
		if M.SlotPos then
			local P = Instance.new("Part")
			P.Anchored, P.CanCollide, P.CanQuery, P.CanTouch = true, false, false, false
			P.Shape = Enum.PartType.Cylinder
			P.Size = Vector3.new(0.2, 2, 2)
			P.CFrame = CFrame.new(M.SlotPos - Vector3.new(0, 2.9, 0)) * CFrame.Angles(0, 0, math.rad(90))
			P.Material = Enum.Material.Neon
			P.Color = RoleColor[Role] or Color3.new(1, 1, 1)
			P.Parent = DebugFolder
		end
		local Head = Rig:FindFirstChild("Head")
		if Head then
			local B = Rig:FindFirstChild("SquadDebugLabel")
			if not B then
				B = Instance.new("BillboardGui")
				B.Name = "SquadDebugLabel"
				B.Size = UDim2.fromOffset(160, 36)
				B.StudsOffset = Vector3.new(0, 3.2, 0)
				B.AlwaysOnTop = true
				local L = Instance.new("TextLabel")
				L.Name = "Text"
				L.Size = UDim2.fromScale(1, 1)
				L.BackgroundTransparency = 1
				L.TextScaled = true
				L.Font = Enum.Font.Code
				L.TextStrokeTransparency = 0.3
				L.Parent = B
				B.Adornee = Head
				B.Parent = Rig
			end
			B.Text.TextColor3 = RoleColor[Role] or Color3.new(1, 1, 1)
			B.Text.Text = ("#%s %s\n%s"):format(tostring(Rig:GetAttribute("SquadEncounter") or "-"), Role, tostring(Rig:GetAttribute("SquadReason") or ""))
		end
	end
end

-- ===== snapshot (tests / debugging) =====
function CombatDirector.Snapshot()
	local Out = {}
	for Target, Enc in pairs(Encounters) do
		local Ms = {}
		for Rig in pairs(Enc.Members) do table.insert(Ms, Rig.Name .. "(" .. tostring(Rig:GetAttribute("SquadRole")) .. ")") end
		table.insert(Out, {Id = Enc.Id, Target = Target.Name, Holder = Enc.Holder and Enc.Holder.Name or nil, Members = Ms, Reason = Enc.Reason})
	end
	return Out
end
function CombatDirector.EncounterOf(Target) return Encounters[Target] end
function CombatDirector.MemberOf(Rig) return Members[Rig] end

local Started = false
function CombatDirector.Start()
	if Started then return end
	Started = true
	task.spawn(function()
		local NextSlots = 0
		while true do
			task.wait(Cfg.Tick)
			if Cfg.Enabled then
				local List = {}
				for _, Enc in pairs(Encounters) do table.insert(List, Enc) end
				for _, Enc in ipairs(List) do
					local Ok, Err = pcall(TickEncounter, Enc)
					if not Ok then warn("CombatDirector tick:", Err) end
				end
				if Now() >= NextSlots then
					NextSlots = Now() + Cfg.SlotTick
					WallFilter()
					local T = Now()
					for _, Enc in pairs(Encounters) do
						local Ok, Err = pcall(SlotEncounter, Enc, T)
						if not Ok then warn("CombatDirector slots:", Err) end
					end
					pcall(DrawDebug)
				end
			end
		end
	end)
end

return CombatDirector

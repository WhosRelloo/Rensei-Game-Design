-- DownedManager: knocked state, Grip (B) and Carry (V). Numbers: TuningConfig.Downed (PROPOSALS).
--
-- * All combat damage goes through DownedManager.Damage. A hit that would bring a knockable
--   character (any player; an enemy with attribute Knockable) to 0 leaves them at 1 HP and
--   KNOCKED instead: slumped, stunned, can't move, immune to further damage.
-- * After KnockedTime they recover with RecoverHealth of max health.
-- * GRIP (B): finish a knocked target in range over GripTime. Getting stunned cancels it; completing it
--   kills the target (an ordinary death -- PvP / permadeath consequences are not decided yet).
--   Grip styles (owner 2026-10-15: "add different grips"; PROPOSAL): with a weapon drawn, an
--   EXECUTION with that weapon's heavy; unarmed, the paired CLASSIC grip (both share a root, as
--   the animations were authored) or a STOMP (down-slam), at random. Attribute GripStyle on the
--   gripper forces one (tests).
--   After a grip the gripper gets back exactly what it had: walk speed / jump, which parts were
--   massless (hair, accessories, the weapon), and it steps clear of the body instead of being
--   released inside it.
-- * CARRY (V): pick up a knocked target (welded root-to-root, piggyback). The carrier walks at
--   CarryWalkSpeed; V again, attacking, getting stunned or the target recovering drops them.
-- Attributes (server-written): Knocked, KnockedUntil, GrippedBy, Gripping, CarriedBy, Carrying.
-- Listeners (server): functions called ("Grip", Gripper, Target) after a grip finishes someone
-- (MoralityService records the deed).

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

-- weld Target's root onto Holder's root (shared root, as the grip / carry animations expect)
local function Attach(Holder, Target)
	local HR, TR = Root(Holder), Root(Target)
	if not HR or not TR then return false end
	TR.CFrame = HR.CFrame
	local W = Instance.new("Weld")
	W.Name = "DownedWeld"
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
	local KnockedTime = Cfg.KnockedTime
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
	AnimationManager.StopAllAnims(Victim)
	AnimationManager.Play(Victim, "Knocked", {Looped = true, Priority = Enum.AnimationPriority.Action4})
	local Until = Victim:GetAttribute("KnockedUntil")
	task.delay(KnockedTime, function()
		if Victim:GetAttribute("KnockedUntil") == Until then Recover(Victim) end
	end)
end

function Recover(Victim)
	if not DownedManager.IsKnocked(Victim) or not Alive(Victim) then return end
	if Victim:GetAttribute("GrippedBy") then return end -- a grip in progress decides it
	local _, AnimationManager = Mods()
	local Carrier = Victim:GetAttribute("CarriedBy")
	if Carrier then DownedManager.Drop(DownedManager.Find(Carrier)) end
	Victim:SetAttribute("Knocked", nil)
	Victim:SetAttribute("KnockedUntil", nil)
	local S = KnockStun[Victim]
	KnockStun[Victim] = nil
	if S then pcall(function() S:Stop() end) end
	Lock(Victim, false)
	AnimationManager.Stop(Victim, "Knocked")
	local H = Hum(Victim)
	local Share = Victim:GetAttribute("SecondWindActive") and 0.30 or Cfg.RecoverHealth -- Second Wind (PROPOSAL 30%)
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

-- character model by name among the live characters
function DownedManager.Find(Name)
	return Name and workspace.World.Live:FindFirstChild(Name)
end

-- the body this carrier is actually holding. Enemies share names ("Bandit Duelist"), so a name
-- lookup can return a different, healthy one; the CarriedBy link is exact.
function DownedManager.Carried(Carrier)
	local Name = Carrier and Carrier:GetAttribute("Carrying")
	if not Name then return nil end
	for _, M in ipairs(workspace.World.Live:GetChildren()) do
		if M.Name == Name and M:GetAttribute("CarriedBy") == Carrier.Name then return M end
	end
	return DownedManager.Find(Name)
end

-- nearest knocked, free target within Range of Actor
function DownedManager.Nearest(Actor, Range)
	local AR = Root(Actor)
	if not AR then return nil end
	local Best, BestD = nil, Range
	for _, M in ipairs(workspace.World.Live:GetChildren()) do
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
		local CR, TR = Root(Carrier), Root(Target)
		if CR and TR then TR.CFrame = CR.CFrame * CFrame.new(0, 0, -2.5) end -- set down in front
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
	if not Attach(Carrier, Target) then return false end
	Target:SetAttribute("CarriedBy", Carrier.Name)
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

-- EnemyService: PvE enemies (controls doc: "Dummy, Grunt, Elite (block/parry AI). Uses the same
-- combat rules as players.").
--
-- Spawns: any BasePart tagged "RenseiEnemySpawn" with attribute EnemyType ("Grunt" | "Elite"), in workspace only
-- (final review C1, 2026-10-24): a retired spawn kept in ServerStorage.RenseiBackups keeps its tag, and must not spawn.
-- Spawn() also takes a part outside the DataModel (RoadService's ambush marks and RideEvents' holdup marks are
-- unparented on purpose, so they never respawn); it refuses only a part that sits in the DataModel outside workspace.
-- Looks (owner 2026-10-15): every spawn is dressed from the character creator's assets, true to a
-- nation (Customization.RandomLook): the spawn part's Nation attribute, else the enemy type's Nation,
-- else a random nation. The rig carries Nation / Gender attributes.
-- Weapons (owner 2026-10-15): every spawn is armed with one of the character creator's starting
-- weapons (Customization.CommonWeapons), at random -- or the spawn part's Weapon attribute ("" = fists).
-- Gun users (Renetti, Sykov) keep their distance (GUN_RANGE) and fire shots instead of a melee string.
-- Numbers: TuningConfig.Enemies (all PROPOSALS).
--
-- Same rules as players:
--   * attacks run through AttackRunner (startup / active / recovery, server hitbox sweep,
--     DamageManager block / parry / posture / stun) with the fist attacks or the enemy's weapon
--   * enemies have a WCS character, posture and stamina, and get stunned, guard-broken and
--     parried exactly like players
--   * the Elite defends with the players' own Block skill: a tap opens the parry window, a hold
--     blocks (and drains posture). It reacts to the attacker's windup (CombatState = "Startup")
--     and times the tap to the attack's real startup, after a human-ish reaction delay.
-- Kills are credited by WorldService (EXP / money / codex / quests) from the Level and
-- DisplayName attributes set here.
--
-- Alchemists (TuningConfig.Enemies.<Type>.Alchemy; 2026-10-17): cast real abilities through AlchemyService.CastAs
-- on the player's rules (meter from fighting, cooldowns, telegraphs, hitboxes) when the target is in a slot's
-- range and in line of sight; a Guard slot answers a nearby windup (Ward Alchemist: Steel Guard).
--
-- Rig attribute AIPassive = true: the enemy still chases, faces and defends but never attacks
-- (sparring / training targets, tests).
--
-- SQUADS (2026-10-18, owner prompt "Advanced Swarm NPC Combat AI"): every enemy is a member of
-- ServerScriptService.CombatDirector. Enemies on the same player form one encounter; only the holder of its
-- attack token starts attacks or casts (CanStrike) and only its hits land (DamageManager). The others go to the
-- surround position the director gives them (SlotFor), face the player and still defend (block / parry / guard
-- casts). A string stops between hits if the token is taken away. Target changes need TargetSwitchMargin.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local StarterPlayer = game:GetService("StarterPlayer")

local Modules = ReplicatedStorage.Modules
local Managers = Modules.Managers
local States = Modules.Skills.States

local WCS = require(Modules.Framework.WCS)
local Customization = require(Modules.Data.Rensei.Customization)
local AppearanceService = require(game:GetService("ServerScriptService").AppearanceService)
local Tuning = require(Modules.Data.Rensei.TuningConfig)
local GunAim = require(Modules.Data.Rensei.GunAim)
local AttackRunner = require(Managers.AttackRunner)
local BlockManager = require(Managers.BlockManager)
local WeaponManager = require(Managers.WeaponManager)
local BlockSkill = require(Modules.Skills.Combat.Block)
local Stun = require(States.Stun)
local Attacking = require(States.Attacking)
local Blocking = require(States.Blocking)
local CombatDirector = require(game:GetService("ServerScriptService"):WaitForChild("CombatDirector"))
local PerceptionService = require(game:GetService("ServerScriptService").PerceptionService)
local Perception = require(ReplicatedStorage.Modules.Data.Rensei.Perception)
local Takedown = require(ReplicatedStorage.Modules.Data.Rensei.Takedown)
local Hostage = require(ReplicatedStorage.Modules.Data.Rensei.Hostage) -- (hostages Task 9 fix round 1: the shield arc)

-- (hostages Task 9 fix round 1, review I3; spec §3: NPCs facing a human shield "circle for an angle instead") the unit
-- direction from the target's root toward where a holder whose line runs through a held hostage should stand: round the
-- target on the side it is already on, at most FLANK_STEP further than now each brain tick, until FLANK_PAST beyond the
-- shield arc. PROPOSAL numbers.
local FLANK_STEP = math.rad(60)
local FLANK_PAST = math.rad(20)
local function Flank(TRoot, FromTarget)
	local Look = Vector3.new(TRoot.CFrame.LookVector.X, 0, TRoot.CFrame.LookVector.Z)
	if Look.Magnitude < 0.1 then return FromTarget end
	Look = Look.Unit
	local Side = Look:Cross(FromTarget).Y >= 0 and 1 or -1
	local Now = math.acos(math.clamp(Look:Dot(FromTarget), -1, 1))
	local Want = math.min(Now + FLANK_STEP, math.rad(Hostage.ShieldArc) + FLANK_PAST)
	return CFrame.fromAxisAngle(Vector3.yAxis, Side * Want):VectorToWorldSpace(Look)
end

local SPAWN_TAG = "RenseiEnemySpawn"
local function Alchemy() return require(game:GetService("ServerScriptService").AlchemyService) end -- (lazy: it requires us)
-- (stealth Plan 1 Task 4) GuardService, required on first use: it requires this service (Task 5), as PerceptionService
-- reaches SwimService. If it can't load, every enemy is no guard (a stub answers), so enemies without a net are untouched.
-- (Task 4 fix round 1, ruling T4-own) a miss isn't cached: the next call tries again (RenseiBoot may move the module in
-- after the first enemy spawned), with one warn in all.
local GuardMod = nil
local GuardWarned = false
local NO_GUARDS = {Guards = {}, Idle = function() return nil end, Interrupt = function() end,
	Track = function() return nil end, RouteFor = function() return nil end}
local function Guard()
	if GuardMod then return GuardMod end
	local M = game:GetService("ServerScriptService"):FindFirstChild("GuardService")
	local Ok, G = pcall(function() return M and require(M) end)
	if Ok and G then
		GuardMod = G
		return G
	end
	if not GuardWarned then
		GuardWarned = true
		warn("EnemyService: GuardService didn't load, no enemy is a guard for now:", Ok and "missing" or G)
	end
	return NO_GUARDS
end
local SightParams = RaycastParams.new()
SightParams.FilterType = Enum.RaycastFilterType.Include
local CORPSE_SECONDS = 4 -- a takedown's body (attribute TakenDownBy) stays Takedown.BodySeconds instead (assassinations Task 5),
-- and so does any finisher's (FinishedBy: a finished grip, DownedManager.Finish; owner 2026-10-27, Task 7)

local EnemyService = {}
EnemyService.Active = {} -- [Rig] = enemy record

-- Startup time of every attack a player can throw, for timing the Elite's parry.
local StartupOf = {}
for I, Hit in ipairs(Tuning.Light.Hits) do StartupOf["Light" .. I] = Hit.Startup end
for _, Name in ipairs({"Heavy", "Uppercut", "Aerial", "DashAttack"}) do StartupOf[Name] = Tuning[Name].Startup end
for Class, W in pairs(Tuning.Weapons) do
	for I, Hit in ipairs(W.Light.Hits) do StartupOf[Class .. "_Light" .. I] = Hit.Startup end
	StartupOf[Class .. "_Heavy"] = W.Heavy.Startup
	StartupOf[Class .. "_Skill"] = W.Skill.Startup
	StartupOf[Class .. "_DashAttack"] = W.DashAttack.Startup
end

local function Rand(Range) return Range[1] + math.random() * (Range[2] - Range[1]) end

-- in deep water (SwimService sets the Swim traversal state): no attacks, casts, blocks or parries (owner 2026-10-18)
local function Swimming(Model) return Model:GetAttribute("Traversal") == "Swim" end

local function Alive(Model)
	local H = Model and Model.Parent and Model:FindFirstChildOfClass("Humanoid")
	return H ~= nil and H.Health > 0
end

local function Flat(V) return Vector3.new(V.X, 0, V.Z) end

local SPACING = 4.5 -- PROPOSAL: enemies keep this far apart around a target instead of stacking
local GUN_RANGE = 18 -- PROPOSAL: how far a gun-armed enemy stands from its target

-- the weapon a spawn gets: the part's Weapon attribute, else any Common weapon (guns included)
local function PickWeapon(Part)
	local Fixed = Part:GetAttribute("Weapon")
	if type(Fixed) == "string" then return Fixed ~= "" and Fixed or nil end
	local Pool = {}
	for _, W in ipairs(Customization.CommonWeapons or Customization.StartWeapons) do if W ~= "" then table.insert(Pool, W) end end
	return #Pool > 0 and Pool[math.random(1, #Pool)] or nil
end

-- ===== Rig =====
local function LoadTrack(Rig, Name, Looped)
	local Source = ReplicatedStorage.Assets.Animations.Shared:FindFirstChild(Name, true)
	if not Source then return nil end
	local Track = Rig.Humanoid.Animator:LoadAnimation(Source)
	Track.Looped = Looped
	Track.Priority = Enum.AnimationPriority.Core
	return Track
end

local function BuildRig(Type, Def, Spawn)
	local Rig = StarterPlayer.StarterCharacter:Clone()
	for _, S in ipairs(Rig:GetDescendants()) do
		if S:IsA("LuaSourceContainer") then S:Destroy() end
	end
	Rig.Name = Def.DisplayName
	local Humanoid = Rig:FindFirstChildOfClass("Humanoid")
	if not Humanoid:FindFirstChildOfClass("Animator") then Instance.new("Animator", Humanoid) end
	Humanoid.DisplayName = Def.DisplayName
	Humanoid.MaxHealth = Def.Health
	Humanoid.Health = Def.Health
	Humanoid.WalkSpeed = Def.WalkSpeed
	Humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	Humanoid.BreakJointsOnDeath = false
	-- a fit, face, hair and body true to the enemy's nation
	local Look, Nation, Gender = Customization.RandomLook(Spawn:GetAttribute("Nation") or Def.Nation)
	AppearanceService.Apply(Rig, Look)
	Rig:SetAttribute("Nation", Nation)
	Rig:SetAttribute("Gender", Gender)
	Rig:SetAttribute("EnemyType", Type)
	Rig:SetAttribute("DisplayName", Def.DisplayName)
	Rig:SetAttribute("Level", Def.Level)
	Rig:SetAttribute("PhysicalMultiplier", Def.DamageMult)
	Rig:SetAttribute("CombatMode", true) -- weapon drawn, same as a player in Combat Mode
	-- (assassinations Task 7, pre-flight R8) a faction enemy carries it on the rig: a law faction's is a guard's (TakedownService)
	if Def.Faction then Rig:SetAttribute("Faction", Def.Faction) end
	if Def.Knockable ~= false then Rig:SetAttribute("Knockable", true) end -- every enemy is knocked at 0 HP, grip (B) to finish (owner 2026-10-20); Knockable = false opts out
	if Def.Boss then -- the top-of-screen boss bar (HUDUI): name, title, health
		Rig:SetAttribute("Boss", true)
		Rig:SetAttribute("BossName", Def.BossName or Def.DisplayName)
		Rig:SetAttribute("Title", Def.Title or "")
	end
	Rig:PivotTo(Spawn.CFrame * CFrame.new(0, 3, 0))
	Rig.Parent = workspace.World.Live
	return Rig
end

local NpcRandom = Random.new() -- enemy gunshots' spread (GunAim.Spread)

-- Root turned flat to face TRoot (a target's root), unless they stand (nearly) on top of each other. Brain's Face and
-- GunShot share it.
local function FaceToward(Root, TRoot)
	local To = Flat(TRoot.Position - Root.Position)
	if To.Magnitude > 0.1 then
		Root.CFrame = CFrame.lookAt(Root.Position, Root.Position + To)
	end
end

-- one enemy gunshot (gun rework 2026-10-25, PROPOSAL): a 0.35 s windup with the crit telegraph, aimed at the target's centre
-- (was the root's flat look: it missed anyone higher or lower), 2.5 deg spread. Exported for Play_GunNpc.
-- (The root is turned to face the target first, before SetAim, whose check is against the root's facing. The aim is set
-- at the windup's start and fires 0.35 s later, inside Aim.AimFresh: the shot goes where the target stood when the
-- telegraph showed, so it can be dodged.)
-- Contract (final fix A10): the caller checks WeaponManager.CanFire first (a shot with no round or mid-reload runs its
-- windup and fires nothing). When the target's root is within 1 stud of the muzzle (To.Magnitude <= 1) no new aim is
-- set: the previous one is used while it is fresh, else the root's flat look (WeaponManager.Fire).
function EnemyService.GunShot(Rig, WC, Target, Shot)
	local Root = Rig:FindFirstChild("HumanoidRootPart")
	local TRoot = Target:FindFirstChild("HumanoidRootPart")
	local Weapon = WeaponManager.Def(Rig)
	if not (Root and TRoot and Weapon and Weapon.Shots) then return end
	FaceToward(Root, TRoot)
	local N = Tuning.Weapons.Guns.NpcShot
	local To = TRoot.Position - GunAim.Muzzle(Root.Position)
	if To.Magnitude > 1 then WeaponManager.SetAim(Rig, GunAim.Spread(To.Unit, N.Spread, NpcRandom)) end
	local Def = table.clone(WeaponManager.Resolve(Rig, Weapon.Shots[Shot]))
	Def.Startup, Def.Telegraph = N.Startup, N.Telegraph
	return AttackRunner.Run(WC, Def, Weapon.Class .. "_Shot" .. Shot, {WalkSpeed = 6, Strike = WeaponManager.Fire})
end

-- ===== Spawning =====
local Spawn -- forward

local function Brain(E)
	local Rig, Def = E.Rig, E.Def
	local Humanoid = Rig.Humanoid
	local Root = Rig.HumanoidRootPart
	local WC = E.WCS
	local NextAttack = 0
	local NextCast = 0
	local Walking = false

	-- the walk's rate follows the enemy's own walk speed (TuningConfig.Locomotion: the shared walk is
	-- designed at 12; a 19-speed duelist strides faster, a slowed one slower) instead of a flat 1x
	local function WalkRate()
		local L = Tuning.Locomotion
		return math.clamp(Humanoid.WalkSpeed / L.Design.Walk, L.Min, L.Max)
	end
	local function SetWalking(On)
		if On and Walking and E.WalkTrack and math.abs(E.WalkTrack.Speed - WalkRate()) > 0.05 then E.WalkTrack:AdjustSpeed(WalkRate()) end
		if On == Walking then return end
		Walking = On
		if E.WalkTrack then
			if On then E.WalkTrack:Play(0.15, 1, WalkRate()) else E.WalkTrack:Stop(0.15) end
		end
	end

	local function Face(Target)
		FaceToward(Root, Target.HumanoidRootPart)
	end

	local function Busy()
		-- (assassinations Task 7) being taken down (TakenDownBy): it neither moves nor fights while TakedownService holds it
		return Rig:GetAttribute("Knocked") or Rig:GetAttribute("Gripping") or Rig:GetAttribute("Carrying")
			or Rig:GetAttribute("TakenDownBy")
			or AttackRunner.IsRunning(Rig) or WC:HasStatusEffects({Stun, Attacking, Blocking})
	end

	-- the nearest player in aggro range (inside the leash); the current target is kept unless another player is
	-- TargetSwitchMargin studs closer (no flip-flopping between two players standing near each other)
	local function NearestTarget()
		local Margin = Tuning.Squad and Tuning.Squad.TargetSwitchMargin or 0
		local Cur, CurDist = nil, math.huge
		local Best, BestDist = nil, Def.AggroRange
		for _, Player in ipairs(Players:GetPlayers()) do
			local C = Player.Character
			local R = C and C:FindFirstChild("HumanoidRootPart")
			if R and Alive(C) and not C:GetAttribute("Knocked") and (Flat(R.Position - E.Home.Position)).Magnitude <= Def.LeashRange then
				local D = (R.Position - Root.Position).Magnitude
				if C == E.Target and D < Def.LeashRange then Cur, CurDist = C, D end
				if D < BestDist then Best, BestDist = C, D end
			end
		end
		if Cur and (not Best or Best == Cur or BestDist > CurDist - Margin) then return Cur end
		return Best
	end
	-- who to fight: perceived players only (PerceptionService), still inside the leash; arena / trial foes
	-- use the nearest player as before
	local function PickTarget()
		if not PerceptionService.Tracks(Rig) then return NearestTarget() end
		local C = PerceptionService.Target(Rig)
		local R = C and C:FindFirstChild("HumanoidRootPart")
		if not R then return nil end
		if (Flat(R.Position - E.Home.Position)).Magnitude > Def.LeashRange then
			PerceptionService.Lose(Rig, E.Home.Position, Def.LeashRange) -- beyond the leash: give up, warily (and stop re-noticing them out there)
			return nil
		end
		return C
	end

	-- Alchemists: nothing between the caster and the target (no casting through walls)
	local function InSight(Target)
		SightParams.FilterDescendantsInstances = {workspace.World.Map}
		local From = Root.Position + Vector3.new(0, 1.5, 0)
		local To = Target.HumanoidRootPart.Position + Vector3.new(0, 1.5, 0)
		return workspace:Raycast(From, To - From, SightParams) == nil
	end
	-- the first slot that's in range, in sight and affordable: cast it (blocks while the cast runs)
	local function TryCast(Target, Dist)
		local A = Def.Alchemy
		for _, S in ipairs(A.Slots) do
			if Dist >= (S.Min or 0) and Dist <= S.Max and Alchemy().CanCastAs(Rig, A.Affinity, S.Slot) and InSight(Target) then
				Humanoid:MoveTo(Root.Position)
				SetWalking(false)
				Face(Target)
				local Aim = Target.HumanoidRootPart.Position - Root.Position
				Alchemy().CastAs(Rig, A.Affinity, S.Slot, Aim.Magnitude > 0.1 and Aim.Unit or Root.CFrame.LookVector)
				CombatDirector.NoteCast(Rig) -- its projectile / explosion may still be out: the token stays a moment
				return true
			end
		end
		return false
	end

	-- One string of lights (and maybe a heavy), re-facing the target between hits.
	local Range = E.Range or Def.AttackRange

	local function Attack(Target)
		local Weapon = WeaponManager.Def(Rig)
		-- guns: a few shots (empty -> WeaponManager reloads by itself; nothing fires meanwhile)
		if Weapon and Weapon.Ranged then
			for I = 1, math.random(Def.Combo[1], Def.Combo[2]) do
				if not Alive(Rig) or not Alive(Target) or WC:HasStatusEffects({Stun}) or Swimming(Rig) then return end
				if not CombatDirector.Holds(Rig, Target) then return end -- the token moved on mid-string
				if not WeaponManager.CanFire(Rig) then return end
				if (Target.HumanoidRootPart.Position - Root.Position).Magnitude > Range + 6 then return end
				-- (a gun's M1 is the pistol whip now; its shots are Weapons.Guns.Shots, as in the players' shooting mode)
				EnemyService.GunShot(Rig, WC, Target, (I - 1) % #Weapon.Shots + 1)
			end
			return
		end
		local Hits = Weapon and Weapon.Light.Hits or Tuning.Light.Hits
		local Prefix = Weapon and (Weapon.Class .. "_Light") or "Light"
		local Count = math.min(#Hits, math.random(Def.Combo[1], Def.Combo[2]))
		for I = 1, Count do
			if not Alive(Rig) or not Alive(Target) or WC:HasStatusEffects({Stun}) or Swimming(Rig) then return end
			if not CombatDirector.Holds(Rig, Target) then return end -- the token moved on mid-string
			if (Target.HumanoidRootPart.Position - Root.Position).Magnitude > Range + 2 then return end
			Face(Target)
			local Outcome = AttackRunner.Run(WC, Hits[I], Prefix .. I, {WalkSpeed = 4})
			if Outcome == "Interrupted" or Outcome == "Whiff" then return end
		end
		if math.random() < Def.HeavyChance and Alive(Target) and not WC:HasStatusEffects({Stun}) and not Swimming(Rig) and CombatDirector.Holds(Rig, Target) then
			local Heavy = Weapon and Weapon.Heavy or Tuning.Heavy
			Face(Target)
			AttackRunner.Run(WC, Heavy, Weapon and (Weapon.Class .. "_Heavy") or "Heavy", {WalkSpeed = 3})
		end
	end

	while Alive(Rig) do
		task.wait(0.1)
		if not Alive(Rig) then break end
		if Busy() then SetWalking(false) continue end

		local Target = PickTarget()
		E.Target = Target
		CombatDirector.SetTarget(Rig, Target) -- joins / leaves that player's encounter
		if not Target then
			-- investigating a noise / sighting, or sweeping where it lost a player (inside the leash)
			local Goal = PerceptionService.Goal(Rig)
			if Goal and (Flat(Goal - E.Home.Position)).Magnitude <= Def.LeashRange then
				Guard().Interrupt(Rig) -- (stealth Plan 1 Task 4) a guard's routine walk stops before this MoveTo (A4: one walker at a time)
				if (Flat(Goal - Root.Position)).Magnitude > 3 then
					Humanoid:MoveTo(Goal)
					SetWalking(true)
				else
					Humanoid:MoveTo(Root.Position)
					SetWalking(false)
				end
				continue
			end
			local Routine = Guard().Idle(Rig) -- (stealth Plan 1 Task 4) a guard on a net keeps its routine; nil = not a guard
			-- (Task 4 fix round 1, controller ruling T4-walk, against the plan's literal SetWalking(Routine == "walking")):
			-- the Mover plays its own walk track on a routine walk (Mover.lua Animate), so this one stays off; two tracks
			-- blended out of phase, and this one kept playing through the arrival turn
			if Routine then SetWalking(false) continue end
			-- leash: walk home and recover
			local Home = E.Home.Position
			if Flat(Home - Root.Position).Magnitude > 4 then
				Humanoid:MoveTo(Home)
				SetWalking(true)
			else
				SetWalking(false)
				if Humanoid.Health < Humanoid.MaxHealth then Humanoid.Health = Humanoid.MaxHealth end
			end
			continue
		end
		if Guard().Guards[Rig] then Guard().Interrupt(Rig) end -- (stealth Plan 1 Task 4) a target: the routine walk stops, the def's speed back

		local TRoot = Target.HumanoidRootPart
		local Dist = (TRoot.Position - Root.Position).Magnitude
		-- spread out around the target: steer away from other enemies close by (they used to all walk to
		-- the same spot in front of the player and pile into one clump)
		local Push = Vector3.zero
		for Other in pairs(EnemyService.Active) do
			local ORoot = Other ~= Rig and Other:FindFirstChild("HumanoidRootPart")
			if ORoot then
				local Away = Flat(Root.Position - ORoot.Position)
				if Away.Magnitude < SPACING then
					Push += (Away.Magnitude > 0.05 and Away.Unit or Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit) * (SPACING - Away.Magnitude)
				end
			end
		end
		local ReadyToAttack = os.clock() >= NextAttack and not Rig:GetAttribute("AIPassive") and not Swimming(Rig)
			and CombatDirector.CanStrike(Rig, Target) -- only the encounter's attack-token holder attacks
		-- waiting squad members: go to the surround position, face the player, keep apart; never attack
		if not CombatDirector.Holds(Rig, Target) then
			local Slot = CombatDirector.SlotFor(Rig)
			if not Slot then
				-- no position yet: close to the waiting ring on the side it's already on
				local FromTarget = Flat(Root.Position - TRoot.Position)
				FromTarget = FromTarget.Magnitude > 0.1 and FromTarget.Unit or Vector3.new(1, 0, 0)
				Slot = TRoot.Position + FromTarget * ((Tuning.Squad and Tuning.Squad.Ring.Melee) or (Range + 3))
			end
			local Goal = Slot + Push * 0.6 -- local avoidance on top of the slot
			if (Flat(Goal - Root.Position)).Magnitude > 2.5 then
				Humanoid:MoveTo(Goal)
				SetWalking(true)
			else
				Humanoid:MoveTo(Root.Position)
				SetWalking(false)
				Face(Target)
			end
			continue
		end
		-- alchemists cast when they can (range, sight, meter, cooldown); otherwise they close in and fight
		if Def.Alchemy and ReadyToAttack and os.clock() >= NextCast and TryCast(Target, Dist) then
			NextCast = os.clock() + Rand(Def.Alchemy.Gap)
			NextAttack = os.clock() + 0.5
			continue
		end
		-- crowding only steers: in range and ready, the enemy attacks even with an ally beside it
		-- (hostages Task 9 fix round 1) a hostage held in front of the target blocks the line: circle to its flank instead
		local Blocked = CombatDirector.LineBlocked(Rig, Target)
		if Dist > Range or Blocked or (Push.Magnitude > 1 and not ReadyToAttack) then
			local FromTarget = Flat(Root.Position - TRoot.Position)
			FromTarget = FromTarget.Magnitude > 0.1 and FromTarget.Unit or Vector3.new(1, 0, 0)
			local Approach = TRoot.Position + FromTarget * (Range - 1.5)
			if Blocked then
				Approach = TRoot.Position + Flank(TRoot, FromTarget) * (Range - 1.5)
			elseif Push.Magnitude > 0 then
				-- step around the target (along the circle), away from the ally that's too close
				local Tangent = Vector3.new(-FromTarget.Z, 0, FromTarget.X)
				local Side = Tangent:Dot(Push) >= 0 and 1 or -1
				local Around = FromTarget + Tangent * Side * 0.9
				Approach = TRoot.Position + Around.Unit * (Range - 1.5)
			end
			Humanoid:MoveTo(Approach)
			SetWalking(true)
			-- (hostages Task 9 fix round 1) not while circling: Face writes the root's CFrame, which stops the walk there
			if Dist <= Range and not Blocked then Face(Target) end
		else
			Humanoid:MoveTo(Root.Position)
			SetWalking(false)
			Face(Target)
			if ReadyToAttack then
				Attack(Target)
				NextAttack = os.clock() + Rand(Def.Pause)
			end
		end
	end
	SetWalking(false)
end

-- Elite defence: a player near the Elite that it is fighting started an attack.
local function OnWindup(Attacker)
	local Started = os.clock()
	local Name = Attacker:GetAttribute("CombatAttack")
	local Startup = StartupOf[Name or ""] or 0.25
	for Rig, E in pairs(EnemyService.Active) do
		local Def = E.Def
		-- Ward Alchemist: a windup close by -> raise its Guard move (Steel Guard), the real ability, if it can
		local Guard = Def.Alchemy and Def.Alchemy.Guard
		if Guard and E.Target == Attacker and Alive(Rig) and not Rig:GetAttribute("AIPassive") and not Rig:GetAttribute("Knocked") and not Swimming(Rig) then
			local ARoot, Root = Attacker:FindFirstChild("HumanoidRootPart"), Rig:FindFirstChild("HumanoidRootPart")
			if ARoot and Root and (ARoot.Position - Root.Position).Magnitude <= 12 and Alchemy().CanCastAs(Rig, Def.Alchemy.Affinity, Guard) then
				task.spawn(function()
					local To = Flat(ARoot.Position - Root.Position)
					if To.Magnitude > 0.1 then Root.CFrame = CFrame.lookAt(Root.Position, Root.Position + To) end
					Alchemy().CastAs(Rig, Def.Alchemy.Affinity, Guard, To.Magnitude > 0.1 and To.Unit or Root.CFrame.LookVector)
				end)
			end
		end
		-- GuardDown (TrialService): a telegraphed opening -- no blocks or parries while it's set
	if Def.ParryChance and E.Target == Attacker and Alive(Rig) and E.Block and not Rig:GetAttribute("GuardDown") and not Rig:GetAttribute("Knocked") and not Swimming(Rig) then
			local ARoot, Root = Attacker:FindFirstChild("HumanoidRootPart"), Rig:FindFirstChild("HumanoidRootPart")
			if ARoot and Root and (ARoot.Position - Root.Position).Magnitude <= 12
				and not AttackRunner.IsRunning(Rig) and not E.WCS:HasStatusEffects({Stun, Attacking}) then
				local Roll = math.random()
				local Reaction = Rand(Def.Reaction)
				local Left = Startup - (os.clock() - Started) -- time until the attacker's active frames
				local Choice = nil
				if Roll < Def.ParryChance and Left - 0.05 >= Reaction then
					Choice = "Parry"
				elseif Roll < Def.ParryChance + Def.BlockChance and Left >= Reaction then
					-- Guard as soon as it reacts. Like a player pressing F, the press itself opens the
					-- parry window, so against a fast attack this can still turn into a parry; against a
					-- slow one (heavies) the guard is up in time and it blocks.
					Choice = "Block"
				end
				if Choice then
					E.Defending = os.clock()
					-- parry: press so the window (Parry.Window) straddles the attacker's first active frame
					local PressIn = Choice == "Parry" and math.max(Reaction, Left - 0.05) or Reaction
					local Hold = Choice == "Parry" and 0.05 or Rand(Def.BlockHold)
					task.delay(PressIn, function()
						if not Alive(Rig) or AttackRunner.IsRunning(Rig) or E.WCS:HasStatusEffects({Stun}) or Swimming(Rig) then return end
						local To = Flat(ARoot.Position - Root.Position)
						if To.Magnitude > 0.1 then Root.CFrame = CFrame.lookAt(Root.Position, Root.Position + To) end
						E.LastDefence = Choice
						-- a real press (Fresh = true): the Block skill only opens a parry window on one
						pcall(function() E.Block:Start(true) end)
						task.delay(Hold, function()
							pcall(function() E.Block:End() end)
						end)
					end)
				end
			end
		end
	end
end

-- A rig made fight-ready (gun rework Task 4, 2026-10-25; moved out of Spawn, no behaviour change): its WCS character,
-- WCS's default props and BlockManager. GunKit's test dummies use it too, so DamageManager doesn't call them IFramed.
-- Returns the WCS character.
function EnemyService.MakeCombatant(Rig, WalkSpeed)
	local WC = WCS.Character.new(Rig)
	-- WCS's default props (walk 16) would replace the enemy's own walk speed whenever a status effect
	-- ends; its tuned speed is the default instead (speed audit 2026-10-18)
	WC:SetDefaultProps({WalkSpeed = WalkSpeed, JumpPower = Rig.Humanoid.JumpPower, JumpHeight = Rig.Humanoid.JumpHeight, AutoRotate = true})
	BlockManager.Initiate(Rig)
	return WC
end

function Spawn(Part)
	-- a part in the DataModel but not in workspace is a backup (RenseiBackups keep their tags): never spawn from it.
	-- (An unparented mark, not in the DataModel at all, is a runtime spawn: allowed.)
	if Part:IsDescendantOf(game) and not Part:IsDescendantOf(workspace) then return nil end
	local Type = Part:GetAttribute("EnemyType")
	local Def = Type and Tuning.Enemies[Type]
	if not Def then
		warn("EnemyService: spawn", Part:GetFullName(), "has unknown EnemyType", Type)
		return
	end
	local Rig = BuildRig(Type, Def, Part)
	local WC = EnemyService.MakeCombatant(Rig, Def.WalkSpeed)
	local E = {Rig = Rig, Def = Def, Type = Type, Home = Part, WCS = WC}
	E.Block = Def.ParryChance and BlockSkill.new(WC) or nil
	local WeaponName = PickWeapon(Part)
	if WeaponName and WeaponManager.Give(Rig, WeaponName) then
		local Armed = WeaponManager.Def(Rig)
		if Armed and Armed.Ranged then E.Range = GUN_RANGE end
		-- keep the weapon held naturally under attacks that don't animate it (same as players)
		local W = WeaponManager.Def(Rig)
		if W and W.HoldAnim then
			require(Managers.AnimationManager).Play(Rig, W.HoldAnim, {Looped = true, Priority = Enum.AnimationPriority.Core})
		end
	end
	CombatDirector.Register(Rig, {Range = E.Range or Def.AttackRange, Type = Type, Ranged = E.Range ~= nil})
	E.WalkTrack = LoadTrack(Rig, "Walk", true)
	E.IdleTrack = LoadTrack(Rig, "Idle", true)
	if E.IdleTrack then E.IdleTrack:Play() end
	EnemyService.Active[Rig] = E

	Rig.Humanoid.Died:Once(function()
		EnemyService.Active[Rig] = nil
		CombatDirector.Unregister(Rig, "Died") -- its token (if any) passes on now
		local Kept = Rig:GetAttribute("TakenDownBy") or Rig:GetAttribute("FinishedBy") -- (both set before the death)
		task.delay(Kept and Takedown.BodySeconds or CORPSE_SECONDS, function()
			pcall(function() WC:Destroy() end)
			if Rig.Parent then Rig:Destroy() end
		end)
		-- dungeon enemies (Def.Dungeon: Forgotten Sites) come back slowly, and never while someone is still
		-- in the site, so a cleared site stays cleared while you explore it (owner 2026-10-18)
		local Dungeon = Def.Dungeon == true
		local Wait = Part:GetAttribute("RespawnTime") or (Dungeon and Tuning.DungeonRespawn.Time) or Def.RespawnTime
		task.delay(Wait, function()
			while Dungeon and Part:IsDescendantOf(workspace) do
				local Near = false
				for _, P in ipairs(Players:GetPlayers()) do
					local Root = P.Character and P.Character:FindFirstChild("HumanoidRootPart")
					if Root and (Root.Position - Part.Position).Magnitude <= Tuning.DungeonRespawn.ClearRadius then Near = true break end
				end
				if not Near then break end
				task.wait(10)
			end
			if Part:IsDescendantOf(workspace) then Spawn(Part) end -- (a spawn retired since then stays retired)
		end)
	end)
	-- notices players through sight and alert phases (PerceptionService); arena / trial foes keep distance aggro
	if not Perception.AlwaysAware[Type] then
		PerceptionService.Register(Rig, {Type = Perception.EnemyTypes[Type] or "Grunt", Faction = Def.Faction, Combat = true})
	end
	-- (stealth Plan 1 Task 4) a spawn on a radio net makes a guard (GuardService: its patrol route, post or look-out). Net,
	-- Route and Lookout are read off RenseiEnemySpawn parts only (travel parts carry an unrelated Route attribute). No Post:
	-- Track takes the root where BuildRig stood it on the part. A spawn without a Net is untouched.
	local Net = CollectionService:HasTag(Part, SPAWN_TAG) and Part:GetAttribute("Net")
	if type(Net) == "string" and Net ~= "" then
		local Ok, Err = pcall(function()
			local RouteName = Part:GetAttribute("Route")
			local R = Guard().RouteFor(RouteName)
			if RouteName ~= nil and not R then warn("EnemyService: spawn", Part:GetFullName(), "names an unknown patrol route", RouteName) end
			Guard().Track(Rig, {Net = Net, Route = R and R.Points, Pauses = R and R.Pauses, Loop = R and R.Loop,
				Lookout = Part:GetAttribute("Lookout") == true, Speed = Def.WalkSpeed})
		end)
		if not Ok then warn("EnemyService: couldn't make", Rig.Name, "a guard on", Net, Err) end
	end
	task.spawn(Brain, E)
	return Rig
end
EnemyService.Spawn = Spawn

local function WatchPlayer(Player)
	local function Hook(Character)
		Character:GetAttributeChangedSignal("CombatState"):Connect(function()
			if Character:GetAttribute("CombatState") == "Startup" then OnWindup(Character) end
		end)
	end
	if Player.Character then Hook(Player.Character) end
	Player.CharacterAdded:Connect(Hook)
end

function EnemyService.Start()
	-- WCS refuses characters until its server has started (CharacterHandler sets WCSStarted);
	-- spawning earlier left enemies without a combat character.
	local Handler = game:GetService("ServerScriptService"):WaitForChild("CharacterHandler")
	local T0 = os.clock()
	while not Handler:GetAttribute("WCSStarted") and os.clock() - T0 < 15 do task.wait(0.1) end
	Players.PlayerAdded:Connect(WatchPlayer)
	for _, Player in ipairs(Players:GetPlayers()) do WatchPlayer(Player) end
	-- only spawns in workspace: a tagged spawn in a backup (ServerStorage.RenseiBackups) stays retired
	for _, Part in ipairs(CollectionService:GetTagged(SPAWN_TAG)) do
		if Part:IsDescendantOf(workspace) then task.spawn(Spawn, Part) end
	end
	CollectionService:GetInstanceAddedSignal(SPAWN_TAG):Connect(function(Part)
		if Part:IsDescendantOf(workspace) then task.spawn(Spawn, Part) end
	end)
end

return EnemyService

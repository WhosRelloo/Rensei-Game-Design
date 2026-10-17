-- EnemyService: PvE enemies (controls doc: "Dummy, Grunt, Elite (block/parry AI). Uses the same
-- combat rules as players.").
--
-- Spawns: any BasePart tagged "RenseiEnemySpawn" with attribute EnemyType ("Grunt" | "Elite").
-- Looks (owner 2026-10-15): every spawn is dressed from the character creator's assets, true to a
-- nation (Customization.RandomLook): the spawn part's Nation attribute, else the enemy type's Nation,
-- else a random nation. The rig carries Nation / Gender attributes.
-- Weapons (owner 2026-10-15): every spawn is armed with one of the character creator's starting
-- weapons (Customization.StartWeapons), at random -- or the spawn part's Weapon attribute ("" = fists).
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
-- Rig attribute AIPassive = true: the enemy still chases, faces and defends but never attacks
-- (sparring / training targets, tests).

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
local AttackRunner = require(Managers.AttackRunner)
local BlockManager = require(Managers.BlockManager)
local WeaponManager = require(Managers.WeaponManager)
local BlockSkill = require(Modules.Skills.Combat.Block)
local Stun = require(States.Stun)
local Attacking = require(States.Attacking)
local Blocking = require(States.Blocking)

local SPAWN_TAG = "RenseiEnemySpawn"
local CORPSE_SECONDS = 4

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

local function Alive(Model)
	local H = Model and Model.Parent and Model:FindFirstChildOfClass("Humanoid")
	return H ~= nil and H.Health > 0
end

local function Flat(V) return Vector3.new(V.X, 0, V.Z) end

local SPACING = 4.5 -- PROPOSAL: enemies keep this far apart around a target instead of stacking
local GUN_RANGE = 18 -- PROPOSAL: how far a gun-armed enemy stands from its target

-- the weapon a spawn gets: the part's Weapon attribute, else one of the creator's starting weapons
local function PickWeapon(Part)
	local Fixed = Part:GetAttribute("Weapon")
	if type(Fixed) == "string" then return Fixed ~= "" and Fixed or nil end
	local Pool = {}
	for _, W in ipairs(Customization.StartWeapons) do if W ~= "" then table.insert(Pool, W) end end
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
	if Def.Knockable then Rig:SetAttribute("Knockable", true) end -- knocked at 0 HP, grip (B) to finish
	Rig:PivotTo(Spawn.CFrame * CFrame.new(0, 3, 0))
	Rig.Parent = workspace.World.Live
	return Rig
end

-- ===== Spawning =====
local Spawn -- forward

local function Brain(E)
	local Rig, Def = E.Rig, E.Def
	local Humanoid = Rig.Humanoid
	local Root = Rig.HumanoidRootPart
	local WC = E.WCS
	local NextAttack = 0
	local Walking = false

	local function SetWalking(On)
		if On == Walking then return end
		Walking = On
		if E.WalkTrack then
			if On then E.WalkTrack:Play(0.15) else E.WalkTrack:Stop(0.15) end
		end
	end

	local function Face(Target)
		local To = Flat(Target.HumanoidRootPart.Position - Root.Position)
		if To.Magnitude > 0.1 then
			Root.CFrame = CFrame.lookAt(Root.Position, Root.Position + To)
		end
	end

	local function Busy()
		return Rig:GetAttribute("Knocked") or Rig:GetAttribute("Gripping") or Rig:GetAttribute("Carrying")
			or AttackRunner.IsRunning(Rig) or WC:HasStatusEffects({Stun, Attacking, Blocking})
	end

	local function PickTarget()
		local Best, BestDist = nil, Def.AggroRange
		for _, Player in ipairs(Players:GetPlayers()) do
			local C = Player.Character
			local R = C and C:FindFirstChild("HumanoidRootPart")
			if R and Alive(C) and not C:GetAttribute("Knocked") and (Flat(R.Position - E.Home.Position)).Magnitude <= Def.LeashRange then
				local D = (R.Position - Root.Position).Magnitude
				if D < BestDist or C == E.Target and D < Def.LeashRange then Best, BestDist = C, D end
			end
		end
		return Best
	end

	-- One string of lights (and maybe a heavy), re-facing the target between hits.
	local Range = E.Range or Def.AttackRange

	local function Attack(Target)
		local Weapon = WeaponManager.Def(Rig)
		-- guns: a few shots (empty -> WeaponManager reloads by itself; nothing fires meanwhile)
		if Weapon and Weapon.Ranged then
			for I = 1, math.random(Def.Combo[1], Def.Combo[2]) do
				if not Alive(Rig) or not Alive(Target) or WC:HasStatusEffects({Stun}) then return end
				if not WeaponManager.CanFire(Rig) then return end
				if (Target.HumanoidRootPart.Position - Root.Position).Magnitude > Range + 6 then return end
				Face(Target)
				local Shot = (I - 1) % #Weapon.Light.Hits + 1
				AttackRunner.Run(WC, WeaponManager.Resolve(Rig, Weapon.Light.Hits[Shot]), Weapon.Class .. "_Light" .. Shot,
					{WalkSpeed = 6, Strike = WeaponManager.Fire})
			end
			return
		end
		local Hits = Weapon and Weapon.Light.Hits or Tuning.Light.Hits
		local Prefix = Weapon and (Weapon.Class .. "_Light") or "Light"
		local Count = math.min(#Hits, math.random(Def.Combo[1], Def.Combo[2]))
		for I = 1, Count do
			if not Alive(Rig) or not Alive(Target) or WC:HasStatusEffects({Stun}) then return end
			if (Target.HumanoidRootPart.Position - Root.Position).Magnitude > Range + 2 then return end
			Face(Target)
			local Outcome = AttackRunner.Run(WC, Hits[I], Prefix .. I, {WalkSpeed = 4})
			if Outcome == "Interrupted" or Outcome == "Whiff" then return end
		end
		if math.random() < Def.HeavyChance and Alive(Target) and not WC:HasStatusEffects({Stun}) then
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
		if not Target then
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
		local ReadyToAttack = os.clock() >= NextAttack and not Rig:GetAttribute("AIPassive")
		-- crowding only steers: in range and ready, the enemy attacks even with an ally beside it
		if Dist > Range or (Push.Magnitude > 1 and not ReadyToAttack) then
			local FromTarget = Flat(Root.Position - TRoot.Position)
			FromTarget = FromTarget.Magnitude > 0.1 and FromTarget.Unit or Vector3.new(1, 0, 0)
			local Approach = TRoot.Position + FromTarget * (Range - 1.5)
			if Push.Magnitude > 0 then
				-- step around the target (along the circle), away from the ally that's too close
				local Tangent = Vector3.new(-FromTarget.Z, 0, FromTarget.X)
				local Side = Tangent:Dot(Push) >= 0 and 1 or -1
				local Around = FromTarget + Tangent * Side * 0.9
				Approach = TRoot.Position + Around.Unit * (Range - 1.5)
			end
			Humanoid:MoveTo(Approach)
			SetWalking(true)
			if Dist <= Range then Face(Target) end
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
		-- GuardDown (TrialService): a telegraphed opening -- no blocks or parries while it's set
	if Def.ParryChance and E.Target == Attacker and Alive(Rig) and E.Block and not Rig:GetAttribute("GuardDown") then
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
						if not Alive(Rig) or AttackRunner.IsRunning(Rig) or E.WCS:HasStatusEffects({Stun}) then return end
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

function Spawn(Part)
	local Type = Part:GetAttribute("EnemyType")
	local Def = Type and Tuning.Enemies[Type]
	if not Def then
		warn("EnemyService: spawn", Part:GetFullName(), "has unknown EnemyType", Type)
		return
	end
	local Rig = BuildRig(Type, Def, Part)
	local WC = WCS.Character.new(Rig)
	BlockManager.Initiate(Rig)
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
	E.WalkTrack = LoadTrack(Rig, "Walk", true)
	E.IdleTrack = LoadTrack(Rig, "Idle", true)
	if E.IdleTrack then E.IdleTrack:Play() end
	EnemyService.Active[Rig] = E

	Rig.Humanoid.Died:Once(function()
		EnemyService.Active[Rig] = nil
		task.delay(CORPSE_SECONDS, function()
			pcall(function() WC:Destroy() end)
			if Rig.Parent then Rig:Destroy() end
		end)
		task.delay(Part:GetAttribute("RespawnTime") or Def.RespawnTime, function()
			if Part.Parent then Spawn(Part) end
		end)
	end)
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
	for _, Part in ipairs(CollectionService:GetTagged(SPAWN_TAG)) do task.spawn(Spawn, Part) end
	CollectionService:GetInstanceAddedSignal(SPAWN_TAG):Connect(function(Part) task.spawn(Spawn, Part) end)
end

return EnemyService

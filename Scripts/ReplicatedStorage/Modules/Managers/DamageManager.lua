local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local CombatFX = ReplicatedStorage.Modules.Effects.Combat

local AnimManager = require(ReplicatedStorage.Modules.Managers.AnimationManager)
local MoverManager = require(ReplicatedStorage.Modules.Managers.MoverManager)
local BlockManager = require(ReplicatedStorage.Modules.Managers.BlockManager)
local WCS = require(ReplicatedStorage.Modules.Framework.WCS)
local HitFX = require(CombatFX.Hit)
local BlockFX = require(CombatFX.Block)
local BlockBreakFX = require(CombatFX.BlockBreak)
local ParryFX = require(CombatFX.ParryFX)
local PerfectParryFX = require(CombatFX.PerfectParryFX)
local DazedFX = require(CombatFX.Dazed)
local KnockbackEffect = require(CombatFX.KnockbackVFX)
local GroundSmash = require(CombatFX.GroundSmash)
local ResourceManager = require(ReplicatedStorage.Modules.Managers.ResourceManager)
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)
local WeaponManager = require(ReplicatedStorage.Modules.Managers.WeaponManager)
local DownedManager = require(ReplicatedStorage.Modules.Managers.DownedManager)
local CounterManager = require(ReplicatedStorage.Modules.Managers.CounterManager)
local ShieldManager = require(ReplicatedStorage.Modules.Managers.ShieldManager)
local SkillMods = require(ReplicatedStorage.Modules.Managers.SkillMods) -- the Mastery skill tree

-- Duelist (skill tree): only one other living fighter within DUEL_RANGE
local DUEL_RANGE = 20
local function OneOnOne(Character)
	local Root = Character:FindFirstChild("HumanoidRootPart")
	if not Root then return false end
	local Count = 0
	for _, M in ipairs(workspace.World.Live:GetChildren()) do
		local R, H = M:FindFirstChild("HumanoidRootPart"), M:FindFirstChildOfClass("Humanoid")
		if M ~= Character and R and H and H.Health > 0 and (R.Position - Root.Position).Magnitude <= DUEL_RANGE then
			Count += 1
			if Count > 1 then return false end
		end
	end
	return Count == 1
end

-- Coordinated squads (ServerScriptService.CombatDirector, 2026-10-18): only the attack-token holder of a player's
-- encounter may hurt that player. Lazy, server-only require (this module is shared).
local DirectorModule = nil
local function Director()
	if DirectorModule == nil then
		local Ok, M = false, nil
		if game:GetService("RunService"):IsServer() then
			Ok, M = pcall(require, game:GetService("ServerScriptService"):FindFirstChild("CombatDirector"))
		end
		DirectorModule = Ok and M or false
	end
	return DirectorModule or nil
end

local StateModules = {}

-- loop through movesetmodules and require them
for _,Module in pairs(ReplicatedStorage.Modules.Skills.States:GetDescendants()) do
	if Module:IsA("ModuleScript") then
		StateModules[Module.Name] = require(Module)
	end
end

-- Damage resistance window (Victim attributes DamageResist = fraction, DamageResistUntil = server time).
-- TrueDamage attacks (Alloy Divider) ignore it.
local function Resist(Victim, IgnoreResist)
	if IgnoreResist then return 0 end
	if (Victim:GetAttribute("DamageResistUntil") or 0) <= workspace:GetServerTimeNow() then return 0 end
	return math.clamp(Victim:GetAttribute("DamageResist") or 0, 0, 0.9)
end

return function(Character,Victim,SkillInfo)
	if not SkillInfo then return end
	-- A knocked target can't be hurt or moved by attacks; only a grip finishes it.
	if DownedManager.IsKnocked(Victim) or DownedManager.IsKnocked(Character) then return "IFramed" end
	-- admin god mode (AdminService "God")
	if Victim:GetAttribute("AdminGod") then return "IFramed" end
	-- enemies don't hurt each other (their swings used to cut down the enemies beside them)
	if Character ~= Victim and Character:GetAttribute("EnemyType") and Victim:GetAttribute("EnemyType") then return "IFramed" end
	-- squads: an enemy without its encounter's attack token can't hurt that player (no hidden second attacker:
	-- lingering hitboxes, projectiles, traps or explosions included)
	if Character ~= Victim and Character:GetAttribute("EnemyType") then
		local D = Director()
		if D and not D.MayHit(Character, Victim) then return "IFramed" end
	end
	local Player = Players:GetPlayerFromCharacter(Character)
	local VictimPlayer = Players:GetPlayerFromCharacter(Victim)
	local CharacterState = WCS.Character.GetCharacterFromInstance(Character)
	local VictimState = WCS.Character.GetCharacterFromInstance(Victim)
	
	local CharacterPos = Character:GetPivot().Position
	local Root = Character.HumanoidRootPart
	local VictimPos = Victim:GetPivot().Position
	local VictimRoot = Victim.HumanoidRootPart
	
	local Angle = -.5 -- change smth to do with weapon later on
	
	local VictimHumanoid = Victim.Humanoid
	-- being attacked keeps you "in combat" a moment (the skill tree can't be changed meanwhile)
	Victim:SetAttribute("LastHitAt", workspace:GetServerTimeNow())

	-- Attack classification (definitions in Modules.Data.Rensei.Alchemy.Classes).
	--   PARRYABLE   (default for untagged attacks, i.e. existing behaviour): block mitigates, parry counters.
	--   BLOCKABLE   block mitigates; an active parry window only counts as a block, never a counter.
	--   UNBLOCKABLE ignores block and parry; dodge and i-frames still avoid it.
	local Class = SkillInfo.Class or "PARRYABLE"
	-- a reactive counter (Cryo Shift) catches the first hit that isn't UNBLOCKABLE
	if Character ~= Victim and Class ~= "UNBLOCKABLE" and CounterManager.Try(Victim, Character, SkillInfo) then
		-- the counter's riposte answers this hit: it may land without the attack token
		local D = Victim:GetAttribute("EnemyType") and Director()
		if D then D.AllowReactive(Victim, Character) end
		return "Countered"
	end
	local TrueHit = SkillInfo.TrueDamage == true
	-- a shield (Steel Guard) soaks hits from the front; shield breakers shatter it and land
	if Character ~= Victim and Class ~= "UNBLOCKABLE" and not TrueHit then
		local Amount = (SkillInfo.Damage or 0) * (Character:GetAttribute(SkillInfo.Alchemy and "AlchemyMultiplier" or "PhysicalMultiplier") or 1)
		if ShieldManager.Try(Victim, SkillInfo, SkillInfo.FromPosition or Character:GetPivot().Position, Amount) then
			return "Shielded"
		end
	end
	local Guardable = Class ~= "UNBLOCKABLE"
	local Counterable = Class == "PARRYABLE"
	local Result = nil
	
	-- The parry window (first frames of pressing block) takes priority over the guard itself.
	local ParryWindow = Counterable and VictimState:HasStatusEffects({StateModules["PerfectParry"]})
	-- A guard faces the attack's SOURCE: projectiles pass FromPosition (where they came from), so a
	-- fireball from the side isn't blocked just because the caster stands in front.
	local SourcePos = SkillInfo.FromPosition or CharacterPos
	if Guardable and not ParryWindow and VictimState:HasStatusEffects({StateModules["Blocking"]}) and (SourcePos - VictimPos).Unit:Dot(Victim:GetPivot().LookVector) >= Angle then
		BlockFX.new(Victim):Start(Players:GetPlayers())
		-- Block reduces damage to chip and drains posture (TuningConfig.Block / Posture).
		-- PostureMult: Guard Breaker on heavies (AttackRunner, skill tree)
		BlockManager.Negate(Victim, (SkillInfo.Posture or SkillInfo.Damage * 0.5) * WeaponManager.BlockedPostureMult(Character, SkillInfo) * (Character:GetAttribute("PostureMult") or 1))
		local Chip = SkillInfo.Damage * Tuning.Block.DamageTaken * (Character:GetAttribute(SkillInfo.Alchemy and "AlchemyMultiplier" or "PhysicalMultiplier") or 1) * (1 - Resist(Victim, TrueHit))
		Chip *= math.max(0.5, SkillMods.Mult(Victim, "DamageTaken")) -- Iron Skin / Fortitude
		if Chip > 0 then DownedManager.Damage(Victim, Chip) end
		ResourceManager.Add(Character, "Meter", Tuning.Meter.OnBlockedHit)

		Result = "Blocked"
		if not BlockManager.Check(Victim) then
			Result = "GuardBroken"
			BlockBreakFX.new(Victim):Start(Players:GetPlayers())
			local BreakStun = Tuning.Posture.BreakStun * SkillMods.Mult(Victim, "GuardBreakStun") -- Unbroken
			StateModules["Stun"].new(VictimState):Start(BreakStun)
			Victim:SetAttribute("GuardBrokenUntil", workspace:GetServerTimeNow() + BreakStun) -- no parrying out of it
			
			for _,Status in pairs(VictimState:GetAllActiveStatusEffectsOfType(StateModules["Blocking"])) do
				Status:Stop()
				break
			end
			
			AnimManager.StopAllAnims(Victim)

			AnimManager.Play(Victim,"DazedStart",{After = "DazedLoop"})

			MoverManager.Movement(Victim,{JH = 0,WS = 0,D = BreakStun})
			
		else
			BlockFX.new(Victim):Start(Players:GetPlayers())
		end
	elseif Counterable and VictimState:HasStatusEffects({StateModules["PerfectParry"]}) then
		Result = "PerfectParried"
		local AnimData = nil--not VictimPlayer and Victim.Name == "Parry" and {Stop = "BlockIdle",After = "BlockIdle"}
		-- Devil Hunter parry (TuningConfig.Parry): the attacker is pushed back away from the
		-- parrier, loses posture and is parry-stunned (their swing and combo are cancelled); the
		-- parrier pays a little posture, gains meter, and the landed parry skips the cooldown.
		local Away = Vector3.new(Root.Position.X - VictimRoot.Position.X, 0, Root.Position.Z - VictimRoot.Position.Z)
		Away = Away.Magnitude > 0.01 and Away.Unit or -Root.CFrame.LookVector
		MoverManager.CreateMover(Character,"Velocity",{D = Tuning.Parry.AttackerPushTime, V = Away * Tuning.Parry.AttackerPush, Clear = true})
		
		PerfectParryFX.new(Victim):Start(Players:GetPlayers())
		AnimManager.Play(Victim,"Parry"..math.random(1,2),AnimData)

		Victim:SetAttribute("ParrySuccessAt", workspace:GetServerTimeNow())
		-- Riposte (skill tree): the parrier's next hit within 2s is a crit
		if SkillMods.Get(Victim, "Riposte") > 0 then Victim:SetAttribute("RiposteUntil", workspace:GetServerTimeNow() + 2) end
		BlockManager.Negate(Character, Tuning.Parry.AttackerPostureDamage)
		BlockManager.Negate(Victim, Tuning.Parry.DefenderPostureCost)
		ResourceManager.Add(Victim, "Meter", Tuning.Meter.OnParry)

		AnimManager.StopAllAnims(Character)
		AnimManager.Play(Character,"ParryFlinch")

		StateModules["Stun"].new(CharacterState):Start(Tuning.Parry.AttackerStun)
		Character:SetAttribute("ParryStunnedUntil", workspace:GetServerTimeNow() + Tuning.Parry.AttackerStun)
	elseif Counterable and VictimState:HasStatusEffects({StateModules["Parry"]}) then
		Result = "Parried"
		local AnimData = nil--not VictimPlayer and Victim.Name == "Parry" and {Stop = "BlockIdle",After = "BlockIdle"}
		ParryFX.new(Victim):Start(Players:GetPlayers())
		AnimManager.Play(Victim,"Parry"..math.random(1,2),AnimData)
		
		local CFrameTarget = CFrame.new(Root.Position,VictimRoot.Position)

		MoverManager.CreateMover(Character,"Velocity",{D = 0.1,V = CFrameTarget.LookVector * -20})
		--MoverManager.CreateMover(Victim,"Velocity",{D = 0.1,V = CFrameTarget.LookVector * 10})
		
		BlockManager.Negate(Character,10)
		
		AnimManager.StopAllAnims(Character)
		AnimManager.Play(Character,"ParryFlinch")
		
		MoverManager.Movement(Character,{JH = 0,WS = 0,D = 0.5})
		StateModules["Stun"].new(CharacterState):Start(.5)
	elseif Guardable and (VictimState:HasStatusEffects({StateModules["PerfectParry"]}) or VictimState:HasStatusEffects({StateModules["Parry"]})) then
		-- A BLOCKABLE attack into a parry window: treated as an ordinary block.
		Result = "Blocked"
		BlockFX.new(Victim):Start(Players:GetPlayers())
		BlockManager.Negate(Victim,25)
	elseif VictimState:HasStatusEffects({StateModules["Dodge"]}) then
		Result = "Dodged"
	elseif not VictimState:HasStatusEffects({StateModules["IFrame"]}) then
		Result = "Hit"
		-- Stat scaling comes from Formulas via the attacker's server-written multiplier.
		local Damage = SkillInfo.Damage * (Character:GetAttribute(SkillInfo.Alchemy and "AlchemyMultiplier" or "PhysicalMultiplier") or 1)
		-- Weapon passives (PROPOSALS, TuningConfig.Weapons.<Class>.Passive).
		Damage *= WeaponManager.DamageMult(Character, Victim, SkillInfo)
		if SkillInfo.Alchemy then
			-- the cast's skill-tree damage (AlchemyService: Potency, Charged Clap, Overflow)
			Damage *= Character:GetAttribute("CastMult") or 1
			-- Equivalent Exchange: the first landed hit of a cast refunds part of its meter
			local Refund = Character:GetAttribute("CastRefund")
			if Refund and Refund > 0 then
				Character:SetAttribute("CastRefund", nil)
				ResourceManager.Add(Character, "Meter", Refund)
			end
		end
		Damage *= 1 - Resist(Victim, TrueHit) -- e.g. Cryo Shift's 20% after a counter
		-- the Mastery skill tree (Managers.SkillMods)
		if not SkillInfo.Alchemy then
			Damage *= Character:GetAttribute("AttackMult") or 1 -- Bladework / Finisher / Relentless / Momentum Strike
		end
		if (Character:GetAttribute("RiposteUntil") or 0) > workspace:GetServerTimeNow() then
			Character:SetAttribute("RiposteUntil", nil)
			Damage *= 1.5 -- Riposte crit (PROPOSAL)
		end
		if SkillMods.Get(Character, "DuelDamage") > 0 and OneOnOne(Character) then
			Damage *= SkillMods.Mult(Character, "DuelDamage")
		end
		Damage *= math.max(0.5, SkillMods.Mult(Victim, "DamageTaken")) -- Iron Skin / Fortitude
		-- Hyper armour (e.g. greatsword heavy windup): the hit lands but does not stun or move.
		local Armored = Victim:GetAttribute("HyperArmor") ~= nil
		local VelocityType = not Armored and SkillInfo.VelocityType or nil
		
		if VictimState:HasStatusEffects({StateModules["Blocking"]}) then
			for _,Status in pairs(VictimState:GetAllActiveStatusEffectsOfType(StateModules["Blocking"])) do
				Status:Stop()
				break
			end
		end
		
		DownedManager.Damage(Victim, Damage)
		if DownedManager.IsKnocked(Victim) then
			-- this hit knocked them: no stun / knockback / hit reaction on top of the knock
			Armored = true
			VelocityType = nil
		end
		-- Alchemic Momentum (skill tree): +meter on every non-alchemy hit
		ResourceManager.Add(Character, "Meter", SkillInfo.Meter or (Tuning.Meter.OnLightHit + SkillMods.Get(Character, "MeterOnHit")))
		ResourceManager.Add(Victim, "Meter", Tuning.Meter.OnHitTaken)

		WeaponManager.OnHit(Character, Victim, SkillInfo)

		HitFX.new(Victim,Damage):Start(Players:GetPlayers())
		
		local StunTime = SkillInfo.StunTime or 0.5
		if Armored then StunTime = 0 end
		if StunTime ~= 0 then
			-- hitstun: no jumping, a slow shuffle (Devil Hunter); knockbacks below still pin the victim
			MoverManager.Movement(Victim,{D = StunTime,JH = 0,WS = Tuning.HitStun.WalkSpeed})
			StateModules["Stun"].new(VictimState):Start(StunTime)
		end
		
		-- NPC physics stays on the server (it used to be handed to the attacker's client, where
		-- Roblox's falling-down states could tip the NPC over).
		
		if VelocityType == "Pull" then
			local Unitvector = (VictimRoot.CFrame.p - Root.CFrame.p).Unit
			local ForwardVelocity = Vector3.new(Unitvector.X,0, Unitvector.Z) * 8
			local VPos = VictimRoot.Position
			local Pos = Root.Position
			
			if CharacterState:HasStatusEffects({StateModules["AirCombo"]}) then
				MoverManager.CreateMover(Character,"DeadVelocity",{V = ForwardVelocity,D = .6, T = 0.3,Clear = true})
				MoverManager.CreateMover(Victim,"DeadVelocity",{V = ForwardVelocity,D = .6,T = 0.3,Clear = true})
			else
				MoverManager.CreateMover(Character,"Velocity",{V = ForwardVelocity,D = .3,Clear = true})
				MoverManager.CreateMover(Victim,"Velocity",{V = ForwardVelocity,D = .3,Clear = true})
			end
			
			MoverManager.CreateMover(Victim,"LookAt",{V = Root.Position,D = 0.5})
		elseif VelocityType == "Knockback" then
			local VelocityForce = SkillInfo.Velocity or 75
			local Duration = SkillInfo.VelocityDuration or 0.5
			local RootLookVector = Root.CFrame.LookVector 
			
			local Velocity = Vector3.new(RootLookVector.X,0,RootLookVector.Z) * VelocityForce * SkillMods.Mult(Victim, "KnockbackTaken") -- Heavy Frame
			-- a strong knockback on a squad's attacker hands its attack token on
			if Victim:GetAttribute("EnemyType") then
				local D = Director()
				if D then D.OnKnockback(Victim, Velocity.Magnitude) end
			end
			
			MoverManager.Knockback(Victim,{V = Velocity,D = Duration,RL = 7,Clear = true,LandAction = function(Position,Normal)
				KnockbackEffect.new(Victim,"End"):Start(Players:GetPlayers())
				MoverManager.Movement(Victim,{D = StunTime,JH = 0,WS = 0})
				StateModules["Stun"].new(VictimState):Start(StunTime)
				GroundSmash.new(Position,Normal):Start(Players:GetPlayers())
			end,})
			
			KnockbackEffect.new(Victim):Start(Players:GetPlayers())
			
			MoverManager.CreateMover(Victim,"Knockback",{V = Velocity,D = Duration,Clear = true})
			
			task.delay(Duration,function()
				KnockbackEffect.new(Victim,"End"):Start(Players:GetPlayers())
			end)
			
		elseif VelocityType == "Downslam" then
			local VelocityForce = SkillInfo.Velocity or 100
			local Duration = SkillInfo.VelocityDuration or 1
			local RootLookVector = (Root.CFrame * CFrame.fromOrientation(-math.rad(60),0,0)).LookVector 

			local Velocity = RootLookVector * VelocityForce
			if Victim:GetAttribute("EnemyType") then
				local D = Director()
				if D then D.OnKnockback(Victim, Velocity.Magnitude) end
			end
			
			MoverManager.Knockback(Victim,{V = Velocity,D = Duration,RL = 7,Clear = true,LandAction = function(Position,Normal)
				MoverManager.Movement(Victim,{D = StunTime,JH = 0,WS = 0})
				StateModules["Stun"].new(VictimState):Start(StunTime)
				GroundSmash.new(Position,Normal):Start(Players:GetPlayers())
			end,})

			--MoverManager.CreateMover(Victim,"Knockback",{V = Velocity,D = Duration,RL = 7,Clear = true})
		elseif VelocityType == "Uptilt" then
			local VPos = VictimRoot.Position
			local Pos = Root.Position
			local UserPosition = (CFrame.new(Pos,VPos) * CFrame.new(0,11,0)).Position
			local VictimPosition = (CFrame.new(VPos,Pos) * CFrame.new(0,11,0)).Position
			
			MoverManager.CreateMover(Character,"AlignPosition",{P = UserPosition,R = 21,D = 1,Clear = true})
			MoverManager.CreateMover(Victim,"AlignPosition",{P = VictimPosition,R = 21,D = 1,Clear = true})
			
			StateModules["AirCombo"].new(VictimState):Start()
			StateModules["AirCombo"].new(CharacterState):Start()
		end
		
		if Armored then
			-- no flinch through hyper armour
		elseif VelocityType == "Knockback" then
			VictimHumanoid.Animator:LoadAnimation(ReplicatedStorage.Assets.Animations.Shared.Combat.HitReaction["Knockback"]):Play()
		else
			for _,Anim in pairs(VictimHumanoid.Animator:GetPlayingAnimationTracks()) do
				Anim:Stop()
			end
			
			local HitReactionNumber = math.random(1,3)

			VictimHumanoid.Animator:LoadAnimation(ReplicatedStorage.Assets.Animations.Shared.Combat.HitReaction["HitReaction"..HitReactionNumber]):Play()
		end
		
		if SkillInfo.Hitstop then
			task.defer(function()
				AnimManager.Hitstop(Character, SkillInfo.Hitstop)
				AnimManager.Hitstop(Victim, SkillInfo.Hitstop)
			end)
		end

		if Player then
			
			local CurrentTime = workspace:GetServerTimeNow()
			local Combo = Player:FindFirstChild("Combo")
			Combo.Value += 1
			Combo:SetAttribute("LastChanged",CurrentTime)
			task.delay(2,function()
				if CurrentTime == Combo:GetAttribute("LastChanged") then
					Combo.Value = 0
				end
			end)
		end
		
		
	end
	
	
	return Result or "IFramed"
end

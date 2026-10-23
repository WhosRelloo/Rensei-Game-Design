-- AttackRunner: the server-side attack state machine (controls doc: "state machine,
-- startup/active/recovery frames").
--
--   Idle -> Startup -> Active -> Recovery -> Idle
--
-- * Startup: windup. Getting stunned cancels the attack (no hitbox), so the faster hit wins.
--            A light attack in Startup can be FEINTED (Feint()).
-- * Active:  the hitbox is live and re-sampled every server frame (HitboxManager.Sweep).
-- * Recovery: endlag. Stun also cancels it.
--
-- The phase is published as character attributes for other systems and the client:
--   CombatState = "Startup" | "Active" | "Recovery" (nil when idle), CombatAttack = attack name.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Managers = ReplicatedStorage.Modules.Managers
local States = ReplicatedStorage.Modules.Skills.States

local HitboxManager = require(Managers.HitboxManager)
local AnimationManager = require(Managers.AnimationManager)
local MoverManager = require(Managers.MoverManager)
local ResourceManager = require(Managers.ResourceManager)
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)
local Stun = require(States.Stun)
local Attacking = require(States.Attacking)

local AttackRunner = {}

-- [WCSCharacter] = the Stun status a crouch started (CharacterHandler). Uppercut clears it.
AttackRunner.CrouchStuns = setmetatable({}, {__mode = "k"})

-- (a plain table: a weak-keyed one can drop a live Instance key; Finish always clears the entry)
local Runs = {} -- [Character] = token of the current run

local function Stunned(WCSCharacter)
	return WCSCharacter:HasStatusEffects({Stun})
end

local function SetPhase(Character, Token, Phase, Name)
	if Runs[Character] ~= Token then return end
	Character:SetAttribute("CombatState", Phase)
	Character:SetAttribute("CombatAttack", Phase and Name or nil)
end

-- Wait Duration seconds; returns false if the attacker got stunned or the run was superseded.
local function Hold(WCSCharacter, Token, Duration, AllowFeint)
	local Character = WCSCharacter.Instance
	local Elapsed = 0
	while Elapsed < Duration do
		Elapsed += RunService.Heartbeat:Wait()
		if Runs[Character] ~= Token or not Character.Parent or Stunned(WCSCharacter) then
			return false, "Interrupted"
		end
		if AllowFeint and Character:GetAttribute("FeintRequested") then
			Character:SetAttribute("FeintRequested", nil)
			return false, "Feinted"
		end
	end
	return true
end

-- Animation playback speed. AnimSpeed wins; otherwise AnimPeak (the measured swing moment of the
-- source animation) is lined up with the middle of the active window.
local function AnimSpeed(Def)
	if Def.AnimSpeed then return Def.AnimSpeed end
	if Def.AnimPeak then
		return math.clamp(Def.AnimPeak / (Def.Startup + Def.Active * 0.5), 0.6, 2.2)
	end
	return 1
end
AttackRunner.AnimSpeed = AnimSpeed

-- Def: a TuningConfig attack table. SkillName: its SkillData key.
-- Opts: {Feintable = bool, OnStartup = fn(Character), OnActive = fn(Character), WalkSpeed = n,
--        Strike = fn(Character, SkillName, Def) -> Results  (replaces the hitbox sweep, e.g. a gunshot)}
-- Active-window variants:
--   Def.MultiHit = n     the active window is split into n sweeps; each can hit the same target
--   Def.HitTimes = {t..} one short strike at each time (seconds from the attack's start); the last
--                        uses <SkillName>Final when SkillData has it
--   Def.HyperArmor       no stun / knockback from hits taken during Startup + Active
--   Def.NoWhiffPenalty   no extra whiff recovery (projectiles: their hits land after the attack ends)
-- Opts.AfterStrike = fn(Index, Results) -> false to skip the remaining HitTimes and go straight to
--   Recovery (a class-skill grab that missed: Requests.ClassSkill).
-- Opts.Prelude = fn(Character, Alive, Slow) -> ok: a variable-length lead-in run at the START of
--   Startup, before the attack's own animation and windup (alchemy: clap, optional hold, ground
--   slam). Alive() is false once the attacker is stunned / superseded; Slow(D) keeps the attack
--   walk speed for D more seconds. Returning false interrupts the attack. Opts.PreludeMax caps it.
-- Returns Outcome ("Hit" | "Whiff" | "Interrupted" | "Feinted"), Results.
local RunBody -- the attack itself (below)

-- Runs the attack in ITS OWN thread and waits for it. Holdable WCS skills (Heavy = R) cancel
-- their thread the moment the key is released; when the attack ran in that thread, releasing R
-- mid-heavy killed it before cleanup and left CombatState stuck on "Recovery" -- which cancels
-- every dash on its first frame and keeps the AI / idle animations thinking you're attacking.
-- Now cancelling the caller only stops the wait; the attack always finishes and cleans up.
-- The caller is woken by an event when the attack ends (M1 speed pass 2026-10-19). It used to poll Heartbeat,
-- and that poll ran before the attack's own last Heartbeat, so Run returned a frame late: one dead frame
-- between every two swings of a string.
function AttackRunner.Run(WCSCharacter, Def, SkillName, Opts)
	local Result = nil
	local Done = Instance.new("BindableEvent")
	task.spawn(function()
		local Ok, Outcome, Results = pcall(RunBody, WCSCharacter, Def, SkillName, Opts)
		if not Ok then
			warn("AttackRunner", SkillName, "failed:", Outcome)
			local Character = WCSCharacter and WCSCharacter.Instance
			if Character then
				Runs[Character] = nil
				Character:SetAttribute("CombatState", nil)
				Character:SetAttribute("CombatAttack", nil)
			end
			Outcome, Results = "Interrupted", {}
		end
		Result = {Outcome, Results}
		Done:Fire()
	end)
	if not Result then Done.Event:Wait() end
	Done:Destroy()
	return Result[1], Result[2]
end

function RunBody(WCSCharacter, Def, SkillName, Opts)
	Opts = Opts or {}
	local Character = WCSCharacter.Instance
	local Token = {}
	Runs[Character] = Token
	Character:SetAttribute("FeintRequested", nil)
	-- the Mastery skill tree (Managers.SkillMods): this attack's damage / posture multipliers, read
	-- by DamageManager while the attack runs. Light string: Bladework, Finisher (last hit), Relentless
	-- (ramps per hit); dash attack: Momentum Strike; heavies: Guard Breaker (posture).
	do
		local SkillMods = require(Managers.SkillMods)
		local Mult, PostureMult = 1, 1
		local Index = tonumber(tostring(SkillName):match("Light(%d+)$"))
		if Index then
			Mult += SkillMods.Get(Character, "LightDamage")
			local W = require(Managers.WeaponManager).Def(Character)
			local Hits = W and W.Light and W.Light.Hits or Tuning.Light.Hits
			if Index >= #Hits then Mult += SkillMods.Get(Character, "FinisherDamage") end
			Mult += math.min(Index - 1, 3) * SkillMods.Get(Character, "StringRamp")
		elseif SkillName == "DashAttack" or SkillName:match("_DashAttack$") then
			Mult += SkillMods.Get(Character, "DashAttackDamage")
		elseif tostring(SkillName):match("Heavy$") then
			PostureMult += SkillMods.Get(Character, "HeavyPosture")
			-- Automail Piston Strike (Rensei.Automail): a fitted, ready arm puts the piston behind the BARE-HANDED heavy
			-- (SkillName "Heavy"); AutomailService adds the heat (server only)
			if SkillName == "Heavy" and Character:GetAttribute("AutomailReady") and RunService:IsServer() then
				local Ok, AS = pcall(require, game:GetService("ServerScriptService"):FindFirstChild("AutomailService"))
				local Spec = Ok and AS and AS.StrikeBonus(Character)
				if Spec then
					PostureMult += Spec.PostureBonus
					Mult += Spec.DamageBonus
					AS.OnStrike(Character)
				end
			end
		end
		Character:SetAttribute("AttackMult", Mult ~= 1 and Mult or nil)
		Character:SetAttribute("PostureMult", PostureMult ~= 1 and PostureMult or nil)
	end
	-- attacking before the draw animation reached the grab: weapon straight into the hand
	if Character:GetAttribute("Weapon") and not Character:GetAttribute("WeaponDrawn") then
		require(Managers.WeaponManager).ForceDraw(Character)
	end

	local Total = Def.Startup + Def.Active + Def.Recovery
	local WalkSpeed = Opts.WalkSpeed or Tuning.Light.AttackWalkSpeed
	local AttackingState = Attacking.new(WCSCharacter)
	AttackingState:Start(Total + Tuning.Light.WhiffRecovery + (Opts.Prelude and (Opts.PreludeMax or 5) or 0))
	if not Opts.Prelude then
		MoverManager.Movement(Character, {JH = 0, WS = WalkSpeed, D = Total})
	end

	-- the attack's own animation + telegraph (after the prelude, when there is one)
	local function BeginAttack()
		if Def.Anim then
			-- lights and heavies: the follow-through after the impact is re-timed to end with the attack (fluidity
			-- pass 2026-10-18; AnimationManager Retime). Skills keep their authored timing (grab pairs stay in sync).
			local Follow = Opts.Feintable or tostring(SkillName):match("Heavy$") ~= nil
			AnimationManager.Play(Character, Def.Anim, {
				Priority = Enum.AnimationPriority.Action3, Speed = AnimSpeed(Def), Fallback = Def.Fallback,
				FollowAt = Follow and (Def.Startup + Def.Active * (Def.AnimPeak and 0.5 or 1)) or nil,
				EndAt = Follow and Total or nil,
			})
		end
		-- crit telegraph: heavies warn the defender for the whole windup
		if Def.Telegraph then
			local Ok, CritFX = pcall(require, ReplicatedStorage.Modules.Effects.Combat.CritTelegraph)
			if Ok then pcall(function() CritFX.new(Character, Def.Startup):Start(Players:GetPlayers()) end) end
		end
	end
	if not Opts.Prelude then BeginAttack() end

	local ArmorId = tostring(Token) -- attributes cannot hold tables
	if Def.HyperArmor then Character:SetAttribute("HyperArmor", ArmorId) end

	local function Finish(Outcome, Results)
		local Current = Runs[Character] == Token -- no newer attack has taken over this character
		if Current then
			SetPhase(Character, Token, nil)
			Runs[Character] = nil
			Character:SetAttribute("AttackMult", nil)
			Character:SetAttribute("PostureMult", nil)
		end
		if Character:GetAttribute("HyperArmor") == ArmorId then Character:SetAttribute("HyperArmor", nil) end
		pcall(function() AttackingState:Stop() end)
		-- the attack's animation ends with the attack (Track:Stop's short default fade). Several animations run
		-- longer than their attack (speed audit 2026-10-18: up to 1.6 s on class skills) and kept the attack pose
		-- over walking after you could already move. A newer attack that took over keeps its own animation.
		if Outcome == "Interrupted" or Outcome == "Feinted" or (Current and Def.Anim) then
			pcall(function() AnimationManager.Stop(Character, Def.Anim) end)
			if Def.Fallback then pcall(function() AnimationManager.Stop(Character, Def.Fallback) end) end
		end
		return Outcome, Results or {}
	end

	-- Startup
	SetPhase(Character, Token, "Startup", SkillName)
	if Opts.Prelude then
		local function Alive()
			return Runs[Character] == Token and Character.Parent ~= nil and not Stunned(WCSCharacter)
		end
		local function Slow(D)
			MoverManager.Movement(Character, {JH = 0, WS = WalkSpeed, D = D})
		end
		local PreludeOk, Done = pcall(Opts.Prelude, Character, Alive, Slow)
		if not PreludeOk then warn("AttackRunner prelude", SkillName, "failed:", Done) end
		if not (PreludeOk and Done and Alive()) then return Finish("Interrupted") end
		MoverManager.Movement(Character, {JH = 0, WS = WalkSpeed, D = Total})
		BeginAttack()
	end
	if Opts.OnStartup then task.spawn(Opts.OnStartup, Character) end
	-- a feint pressed a moment before this windup reached the server (Requests.Feint queues it)
	if Opts.Feintable then
		local Queued = Character:GetAttribute("FeintQueuedAt")
		Character:SetAttribute("FeintQueuedAt", nil)
		if Queued and workspace:GetServerTimeNow() - Queued <= 0.15 then AttackRunner.Feint(Character) end
	end
	local PhaseStart = os.clock() -- the attack's own clock (Recovery below)
	local Ok, Why = Hold(WCSCharacter, Token, Def.Startup, Opts.Feintable)
	if not Ok then return Finish(Why) end

	-- Active
	SetPhase(Character, Token, "Active", SkillName)
	if Opts.OnActive then task.spawn(Opts.OnActive, Character) end
	local Results = {}
	local function Strike(Name, Duration)
		-- pcall: a failing strike must not leave the attacker stuck in this attack's state
		local Ok, Got = pcall(function()
			return Opts.Strike and Opts.Strike(Character, Name, Def) or HitboxManager.Sweep(Character, Name, Duration)
		end)
		if not Ok then
			warn("AttackRunner strike", Name, "failed:", Got)
			return
		end
		for _, R in ipairs(Got) do table.insert(Results, R) end
	end
	if Def.HitTimes then
		local Start = Def.Startup
		local Final = SkillName .. "Final"
		local Stopped = false
		local ActiveAt = os.clock()
		for I, At in ipairs(Def.HitTimes) do
			-- on the attack's own clock (hotfix 2026-10-23): each 0.06 s strike plus a frame of overshoot used to push every
			-- later hit ~0.075 s late (the Rapier Flurry's final stab landed 0.3 s after its marker)
			local Wait = math.max(0, At - Def.Startup - (os.clock() - ActiveAt))
			if Wait > 0 and not Hold(WCSCharacter, Token, Wait, false) then return Finish("Interrupted", Results) end
			Start = math.max(Start, At)
			local Name = (I == #Def.HitTimes and require(ReplicatedStorage.Modules.Data.SkillData)[Final]) and Final or SkillName
			Strike(Name, 0.06)
			if Runs[Character] ~= Token then return Finish("Interrupted", Results) end
			if Opts.AfterStrike and Opts.AfterStrike(I, Results) == false then Stopped = true break end
		end
		local Rest = Def.Startup + Def.Active - Start
		if not Stopped and Rest > 0 and not Hold(WCSCharacter, Token, Rest, false) then return Finish("Interrupted", Results) end
	else
		local Count = Def.MultiHit or 1
		for _ = 1, Count do
			Strike(SkillName, Def.Active / Count)
			if Runs[Character] ~= Token then return Finish("Interrupted", Results) end
		end
	end
	if Character:GetAttribute("HyperArmor") == ArmorId then Character:SetAttribute("HyperArmor", nil) end
	local Landed = false
	for _, R in ipairs(Results) do
		if R.Result ~= "IFramed" and R.Result ~= "Dodged" then Landed = true end
	end

	-- Recovery (hit confirm: a whiff costs extra recovery)
	SetPhase(Character, Token, "Recovery", SkillName)
	local Recovery = Def.Recovery + ((Landed or Def.NoWhiffPenalty) and 0 or Tuning.Light.WhiffRecovery)
	-- the recovery ends on the attack's own clock (M1 speed pass 2026-10-19): each phase's wait ends on the first
	-- frame past its time, and those overshoots added up (about a frame per hit). HitTimes attacks keep their
	-- timing (their strikes run longer than the active window by design). Capped at 0.05 s.
	if not Def.HitTimes then
		Recovery -= math.clamp((os.clock() - PhaseStart) - (Def.Startup + Def.Active), 0, 0.05)
	end
	Ok = Hold(WCSCharacter, Token, Recovery, false)
	return Finish(Ok and (Landed and "Hit" or "Whiff") or "Interrupted", Results)
end

-- Cancel the attacker's current light attack if it is still in Startup.
function AttackRunner.CanFeint(Character)
	return Character:GetAttribute("CombatState") == "Startup"
		and tostring(Character:GetAttribute("CombatAttack") or ""):match("Light%d+$") ~= nil
end

function AttackRunner.Feint(Character)
	if not AttackRunner.CanFeint(Character) then return false end
	local Now = workspace:GetServerTimeNow()
	if (Character:GetAttribute("FeintReadyAt") or 0) > Now then return false end
	-- Feint Discipline (skill tree): cheaper feints
	local Cost = Tuning.Feint.Stamina * require(Managers.SkillMods).Mult(Character, "FeintCost")
	if not ResourceManager.Spend(Character, "Stamina", Cost) then return false end
	Character:SetAttribute("FeintReadyAt", Now + Tuning.Feint.Cooldown)
	Character:SetAttribute("FeintRequested", true)
	return true
end

function AttackRunner.IsRunning(Character)
	return Runs[Character] ~= nil
end

return AttackRunner

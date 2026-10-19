-- F: tap = Parry, hold = Block (controls doc). Parry rules follow Devil Hunter (TuningConfig.Parry):
-- pressing F opens the parry window (longer at high ping, slightly longer right after a landed
-- parry). Every attempt starts the parry cooldown unless it landed (DamageManager sets
-- ParrySuccessAt), so landed parries chain and mashing doesn't work. Keep holding and the guard
-- comes up after Block.StartDelay -- the guard works even while the parry is on cooldown.
-- Releasing F never parries, and neither does the guard re-raising itself while F is held: only a
-- fresh press (the client passes Fresh = true) opens a window.
-- Getting hit doesn't stop a parry (Devil Hunter; Parry.HitParry): a fresh press during hitstun opens
-- the window at a posture cost and always starts the cooldown. Keep holding and the guard comes up
-- once the stun ends.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Managers = ReplicatedStorage.Modules.Managers
local States = ReplicatedStorage.Modules.Skills.States

local BlockManager = require(Managers.BlockManager)
local AnimManager = require(Managers.AnimationManager)
local WCS = require(ReplicatedStorage.Modules.Framework.WCS)
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)
local Styles = require(ReplicatedStorage.Modules.Data.Rensei.Styles)
-- every style's guard pose name (Rensei.Styles ... .Block), so ending a block stops whichever was used
local STYLE_BLOCKS = {}
for _, C in pairs(Styles.Classes) do for _, S in pairs(C.Styles) do if S.Block then STYLE_BLOCKS[S.Block] = true end end end
local Attacking = require(States.Attacking)
local BlockState = require(States.Blocking)
local Climbing = require(States.Climbing)
local PerfectParry = require(States.PerfectParry)
local Stun = require(States.Stun)

local DefaultWS = game.StarterPlayer.StarterCharacter.Humanoid.WalkSpeed
local DefaultJH = game.StarterPlayer.StarterCharacter.Humanoid.JumpHeight

local Block = WCS.RegisterHoldableSkill("Block")

function Block:OnConstructServer()
	self:SetMaxHoldTime(nil)
	self:SetMetadata(0)
	self.MutualExclusives = {Attacking, Climbing} -- Stun is handled in OnStartServer (hit-parry)
	self.BlockLoop = nil
end

function Block:OnConstructClient()
end

local function ParryWindow(Character, Chained)
	local P = Tuning.Parry
	local Window = P.Window + (Chained and P.ChainBonus or 0)
	local Player = Players:GetPlayerFromCharacter(Character)
	if Player then
		local Ok, Ping = pcall(Player.GetNetworkPing, Player)
		if Ok and Ping and Ping >= P.PingThreshold then
			Window = math.max(Window, P.PingBase + math.clamp(Ping * 1000, 0, P.PingClampMs) * P.PingPerMs)
		end
	end
	return Window
end

-- Opens the parry window if the cooldown allows. HitParry = pressed during hitstun.
local function OpenParry(self, Character, HitParry)
	local Now = workspace:GetServerTimeNow()
	if (Character:GetAttribute("ParryReadyAt") or 0) > Now then return end -- cooldown
	if HitParry then
		local H = Tuning.Parry.HitParry
		-- not out of a guard break, a parry stun, a freeze, a knock -- and it needs the posture
		if (Character:GetAttribute("GuardBrokenUntil") or 0) > Now or (Character:GetAttribute("ParryStunnedUntil") or 0) > Now
			or (Character:GetAttribute("StatusFreeze") or 0) > Now or Character:GetAttribute("Knocked")
			or not BlockManager.Check(Character, H.PostureCost) then
			return
		end
		BlockManager.Negate(Character, H.PostureCost)
	end
	local Chained = Character:GetAttribute("ParryChained") == true
	Character:SetAttribute("ParryChained", nil)
	local Window = ParryWindow(Character, Chained)
	Character:SetAttribute("ParryReadyAt", Now + Tuning.Parry.Cooldown)
	PerfectParry.new(self.Character):Start(Window)
	task.delay(Window, function()
		if HitParry and Tuning.Parry.HitParry.AlwaysCooldown then return end
		if (Character:GetAttribute("ParrySuccessAt") or 0) >= Now then
			-- landed: no cooldown, and the next window gets the chain bonus
			Character:SetAttribute("ParryReadyAt", nil)
			Character:SetAttribute("ParryChained", true)
		end
	end)
end

function Block:OnStartServer(Fresh)
	local Character = self.Character.Instance
	local Humanoid = Character.Humanoid
	Fresh = Fresh == true

	if self.Character:HasStatusEffects({Stun}) then
		-- getting hit: a fresh press can still parry; holding on, the guard comes up after the stun
		if Fresh then OpenParry(self, Character, true) end
		while self:GetState().IsActive and self.Character:HasStatusEffects({Stun}) do task.wait() end
		if not self:GetState().IsActive then return end
		Fresh = false
	end
	if not BlockManager.Check(Character) then return end

	self.Guarding = true
	Humanoid.WalkSpeed = Tuning.Block.WalkSpeed
	Humanoid.JumpHeight = 0
	self.AttackingState = Attacking.new(self.Character)
	self.AttackingState:Start()

	-- Parry window on a fresh press (skipped while the parry cooldown runs; a landed parry clears it)
	if Fresh then OpenParry(self, Character, false) end

	task.wait(Tuning.Block.StartDelay)
	if not self:GetState().IsActive then return end -- tapped: parry only

	self.BlockState = BlockState.new(self.Character)
	self.BlockState:Start()
	self.BlockLoop = RunService.Heartbeat:Connect(function()
		if not BlockManager.Check(Character) or not self.Character:HasStatusEffects({BlockState}) then
			self:Stop()
		end
	end)
end

function Block:OnStartClient()
	local Character = self.Character
	local Humanoid = Character.Humanoid
	-- a hit-parry keeps the hit reaction; the guard pose comes once the stun is over (if still held)
	while self:GetState().IsActive and self.Character:HasStatusEffects({Stun}) do task.wait() end
	if not self:GetState().IsActive then return end
	-- every track but the base layer (Core: the Animate idle / walk, which carries the legs -- the guard
	-- poses don't key them -- and the weapon hold). Stopping those too froze the legs straight. (2026-10-19)
	for _, Anim in pairs(Humanoid.Animator:GetPlayingAnimationTracks()) do
		if Anim.Priority ~= Enum.AnimationPriority.Core then Anim:Stop() end
	end
	-- the active style's guard pose when it has one (Boxing / Lethwei bare-handed), else the shared one
	local _, Style = Styles.Active(Character.Instance)
	local Pose = Style and Style.Block and AnimManager.Has(Character.Instance, Style.Block) and Style.Block or "BlockIdle"
	AnimManager.Play(Character.Instance, Pose, {Looped = true})
end

function Block:OnEndServer()
	local Character = self.Character.Instance
	local Humanoid = Character.Humanoid
	if self.BlockState then
		self.BlockState:Stop()
		self.BlockState = nil
	end
	if self.BlockLoop then
		self.BlockLoop:Disconnect()
		self.BlockLoop = nil
	end
	if self.AttackingState then
		self.AttackingState:Stop()
		self.AttackingState = nil
	end
	AnimManager.Stop(Character, "BlockIdle")
	for Name in pairs(STYLE_BLOCKS) do AnimManager.Stop(Character, Name) end
	if not self.Guarding then return end -- a hit-parry never took over the walk speed
	self.Guarding = false
	Humanoid.WalkSpeed = DefaultWS * (Character:GetAttribute("SpeedMultiplier") or 1)
	Humanoid.JumpHeight = DefaultJH
end

function Block:OnEndClient()
end

return Block

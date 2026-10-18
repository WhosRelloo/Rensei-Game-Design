-- Hotbar key 1-4 in Combat Mode (or tapping hotbar slot 1-4): use the class skill in that slot of the
-- current class family's loadout (Rensei.ClassSkills; learned in the Mastery menu's Class tab).
-- The client names only the SLOT. The server finds the skill and checks it: learned, fits the class you're
-- fighting as, Combat Mode on, alive, free to act (not stunned, attacking, blocking, on a wall / ledge,
-- knocked, gripped or carried), off cooldown, enough stamina. Then it runs through AttackRunner: the
-- existing hitbox, damage, block / parry, hitstop, interrupts and recovery. Numbers: TuningConfig.ClassSkills.
-- Cooldowns are kept here per player and skill (dying doesn't reset them) and published as character
-- attributes ClassSkillReadyAt_<Id> / ClassSkillCooldown_<Id> for the HUD.
-- LATCH (owner 2026-10-18, Devil Hunter / VV Ultimatum skill logic): once a skill's hit LANDS (not blocked,
-- not parried), the victim sticks to the attacker for the rest of the move: welded in front (it follows the
-- attacker's lunges), kept stunned between hits, so the remaining hits connect. Released just before the
-- final hit (its knockback still sends them flying), or when the move ends / is interrupted / either dies.
-- A blocked or parried hit never latches; grabs (victim animations) latch from the grab.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local Managers = ReplicatedStorage.Modules.Managers
local States = ReplicatedStorage.Modules.Skills.States

local WCS = require(ReplicatedStorage.Modules.Framework.WCS)
local AttackRunner = require(Managers.AttackRunner)
local ResourceManager = require(Managers.ResourceManager)
local MoverManager = require(Managers.MoverManager)
local AnimationManager = require(Managers.AnimationManager)
local HitboxManager = require(Managers.HitboxManager)
local StatusManager = require(Managers.StatusManager)
local MovementState = require(Managers.MovementState)
local ClassSkills = require(ReplicatedStorage.Modules.Data.Rensei.ClassSkills)
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)
local DataManager = require(ServerScriptService.CharacterHandler.DataManager)
local UIService = require(ServerScriptService.UIService)
local Stun = require(States.Stun)
local Attacking = require(States.Attacking)
local Blocking = require(States.Blocking)
local Climbing = require(States.Climbing)

local ReadyAt = {} -- [Player] = {[Id] = server time}
Players.PlayerRemoving:Connect(function(P) ReadyAt[P] = nil end)

local function Publish(Player, Character)
	for Id, At in pairs(ReadyAt[Player] or {}) do
		Character:SetAttribute("ClassSkillReadyAt_" .. Id, At)
	end
end
-- cooldowns carry over a respawn
local function Hook(P) P.CharacterAdded:Connect(function(C) task.defer(Publish, P, C) end) end
for _, P in ipairs(Players:GetPlayers()) do Hook(P) end
Players.PlayerAdded:Connect(Hook)

local function Toast(Player, Text) UIService.Notify(Player, "Toast", {Text = Text}) end

-- ===== latch: a landed skill hit sticks the victim to the attacker until the move's final hit =====
local LATCH_OFFSET = 2.8 -- studs in front of the attacker (PROPOSAL)
local function OwnerOf(Character) return Players:GetPlayerFromCharacter(Character) end
local function Latch(Character, Victim, Latched, StunFor)
	local Root, VRoot = Character:FindFirstChild("HumanoidRootPart"), Victim:FindFirstChild("HumanoidRootPart")
	local VHum = Victim:FindFirstChildOfClass("Humanoid")
	if not Root or not VRoot or not VHum or VHum.Health <= 0 or VRoot.Anchored then return end
	local VS = WCS.Character.GetCharacterFromInstance(Victim)
	if VS and StunFor > 0 then Stun.new(VS):Start(StunFor) end -- no acting (or blocking) between the hits
	if Latched[Victim] then return end
	local Offset = CFrame.new(0, 0, -LATCH_OFFSET) * CFrame.Angles(0, math.pi, 0)
	-- never through a wall: if the spot in front is blocked, latch where they are
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = {Character, Victim, workspace.World.Live, workspace.World.Visuals}
	if workspace:Raycast(Root.Position, (Root.CFrame * Offset).Position - Root.Position, Params) then
		Offset = Root.CFrame:ToObjectSpace(VRoot.CFrame)
	end
	VRoot.AssemblyLinearVelocity = Vector3.zero
	local W = Instance.new("Weld")
	W.Name = "SkillLatch"
	W.Part0, W.Part1, W.C0 = Root, VRoot, Offset
	W.Parent = Root
	local Was = {}
	for _, P in ipairs(Victim:GetDescendants()) do if P:IsA("BasePart") then Was[P] = P.Massless P.Massless = true end end
	VHum.PlatformStand = true
	-- one physics owner for the joined pair: the attacker's client (or the server for NPCs)
	pcall(function() VRoot:SetNetworkOwner(OwnerOf(Character)) end)
	Latched[Victim] = {Weld = W, Massless = Was}
end
local function Release(Victim, Latched)
	local L = Latched[Victim]
	if not L then return end
	Latched[Victim] = nil
	if L.Weld then L.Weld:Destroy() end
	for P, M in pairs(L.Massless) do if P.Parent then P.Massless = M end end
	local VHum = Victim:FindFirstChildOfClass("Humanoid")
	if VHum then VHum.PlatformStand = false end
	local VRoot = Victim:FindFirstChild("HumanoidRootPart")
	if VRoot and VRoot.Parent then pcall(function() VRoot:SetNetworkOwner(OwnerOf(Victim)) end) end
end

-- Hold a grabbed victim: placed in front of the grabber (unless a wall is in between) playing its
-- reaction. The grab hit's own stun (Grab.Hold) keeps it from acting.
local function Hold(Character, Victim, Grab)
	local Root, VRoot = Character:FindFirstChild("HumanoidRootPart"), Victim:FindFirstChild("HumanoidRootPart")
	if not Root or not VRoot or VRoot.Anchored then return end
	local Target = Root.CFrame * CFrame.new(0, 0, -2.6) * CFrame.Angles(0, math.pi, 0)
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = {Character, Victim, workspace.World.Live, workspace.World.Visuals}
	if not workspace:Raycast(Root.Position, Target.Position - Root.Position, Params) then
		VRoot.CFrame = Target
		VRoot.AssemblyLinearVelocity = Vector3.zero
	end
	AnimationManager.Play(Victim, Grab.VictimAnim, {Priority = Enum.AnimationPriority.Action4})
end

return function(Player, Slot)
	if type(Slot) ~= "number" or Slot % 1 ~= 0 or Slot < 1 or Slot > ClassSkills.Slots then return end
	local Profile = DataManager:GetProfile(Player)
	local Character = Player.Character
	if not Profile or not Character or Character:GetAttribute("CombatMode") ~= true then return end
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid or Humanoid.Health <= 0 then return end

	local Family = ClassSkills.CharacterFamily(Character)
	if not Family then return end
	local Id = ClassSkills.Loadout(Profile.Data, Family)[Slot]
	if Id == "" then
		Toast(Player, ("No skill on %d. Equip one in the Mastery menu (K), Class tab."):format(Slot))
		return
	end
	local Def = ClassSkills.Def(Id)
	if not Def or not ClassSkills.Compatible(Character, Id) then return end

	-- free to act
	if MovementState.Blocked(Character) or MovementState.Get(Character) then return end
	local WCSCharacter = WCS.Character.GetCharacterFromInstance(Character)
	if not WCSCharacter or AttackRunner.IsRunning(Character)
		or WCSCharacter:HasStatusEffects({Stun, Attacking, Blocking, Climbing}) then
		return
	end
	local Now = workspace:GetServerTimeNow()
	local Mine = ReadyAt[Player] or {}
	ReadyAt[Player] = Mine
	if (Mine[Id] or 0) > Now then return end
	if not ResourceManager.Spend(Character, "Stamina", Def.Stamina or 0) then return end
	Mine[Id] = Now + Def.Cooldown
	Character:SetAttribute("ClassSkillReadyAt_" .. Id, Mine[Id])
	Character:SetAttribute("ClassSkillCooldown_" .. Id, Def.Cooldown)

	local Name = "Class_" .. Def.Id
	local HitIndex = 0
	local Held = {} -- grabbed victims
	local Latched = {} -- [Victim] = latch (see Latch)
	local Outcome = AttackRunner.Run(WCSCharacter, Def, Name, {
		WalkSpeed = Def.WalkSpeed,
		OnStartup = Def.Lunge and function()
			task.wait(Def.LungeAt or 0)
			if Character:GetAttribute("CombatAttack") == Name then
				MoverManager.CreateMover(Character, "Lunge", {Speed = Def.Lunge, D = Def.LungeTime or 0.2, StopAt = Def.LungeStopAt})
			end
		end or nil,
		Strike = function(_, StrikeName)
			HitIndex += 1
			local Times = Def.HitTimes or {}
			local Last = HitIndex >= #Times
			-- the final hit lands on a free body, so its knockback works
			if Last then for Victim in pairs(Latched) do Release(Victim, Latched) end end
			local Use = (HitIndex == 1 and Def.Grab) and (Name .. "Grab") or StrikeName
			local Results = HitboxManager.Sweep(Character, Use, 0.06)
			for _, R in ipairs(Results) do
				if R.Result == "Hit" then
					if HitIndex == 1 and Def.Grab then
						Held[R.Victim] = true
						Hold(Character, R.Victim, Def.Grab)
					end
					-- stick to them until the final hit (stunned until just after it)
					if not Last then
						Latch(Character, R.Victim, Latched, (Times[#Times] - (Times[HitIndex] or 0)) + 0.25)
					end
					if Def.Status then
						local S = Tuning.Status[Def.Status.Name]
						if S then StatusManager.Apply(R.Victim, Def.Status.Name, table.clone(S)) end
					end
				end
			end
			return Results
		end,
		AfterStrike = Def.Grab and function(Index)
			if Index == 1 and next(Held) == nil then
				-- missed the grab: the move ends in its whiff
				AnimationManager.Stop(Character, Def.Anim)
				AnimationManager.Play(Character, "Skill_GrabWhiff", {Priority = Enum.AnimationPriority.Action3})
				return false
			end
			return true
		end or nil,
	})
	-- the move is over (or was interrupted): let every latched victim go
	for Victim in pairs(Latched) do Release(Victim, Latched) end
	-- interrupted mid-hold: let the victims go (their stun runs out by itself)
	if Def.Grab and Outcome == "Interrupted" then
		for Victim in pairs(Held) do
			if Victim.Parent then
				AnimationManager.Stop(Victim, Def.Grab.VictimAnim)
			end
		end
	end
end

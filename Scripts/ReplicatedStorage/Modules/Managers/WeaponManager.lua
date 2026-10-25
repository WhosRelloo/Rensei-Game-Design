-- WeaponManager (Phase 2): weapon equip, weapon lookup, guns and weapon passives.
--
-- A weapon is an inventory item (ItemData.Weapon, field Class) equipped from the inventory
-- (ServerScriptService.LoadoutService; never the hotbar). Equipping it puts its Tool (ReplicatedStorage.Assets.Items.Weapon.<Item>) in the character; the SERVER then
-- attaches it and publishes two character attributes that every combat system reads:
--   Weapon     = the weapon class (TuningConfig.Weapons key), nil when unarmed
--   WeaponItem = the item name (guns read their per-item stats from it)
-- Only the server writes them, and only for an item that is in the player's saved inventory
-- (LoadoutService checks), so a client cannot fake a weapon.
--
-- Tool layout: grip Parts carry attributes Arm + MotorC0/MotorC1 -> a Motor6D from that arm to
-- the part. The part is named after the animation pose that moves the weapon (Hilt for the katana and
-- the rapier: the sheet's animations animate the animator rig's Hilt bone; Greatsword, Dagger,
-- Right Hand for the pistols), so the weapon animations drive it. An animation whose weapon track
-- uses another bone name leaves the weapon in its hold pose (Documents/Animations.md, weapon bones). Parts with WeldC0/WeldC1 are
-- welded straight to their arm (Caestus).
--
-- Combat Mode = drawn. Outside Combat Mode a held weapon sits in its holster (grip attribute
-- HolsterC0, relative to the Torso; PROPOSAL spots). Turning Combat Mode on plays the weapon's
-- equip animation and moves it to the hand at Draw.SwapAt; turning it off plays the unequip
-- animation and moves it back at Draw.UnequipSwapAt. Attribute WeaponDrawn tracks which. Starting
-- an attack mid-draw snaps the weapon into the hand (ForceDraw).
-- The holster is a separate Weld ("HolsterWeld", in the grip part): animations only move Motor6Ds,
-- so a holstered weapon can't be pushed around by a weapon pose still playing. Swapping enables
-- one joint and disables the other; every client eases the jump between the two poses (client
-- section below, Tuning.WeaponSwapBlend).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)
local Styles = require(ReplicatedStorage.Modules.Data.Rensei.Styles) -- bare-hand style stances (client)
local ItemData = require(ReplicatedStorage.Modules.Data.ItemData)
local SkillMods = require(ReplicatedStorage.Modules.Managers.SkillMods) -- the Mastery skill tree
local GunAim = require(ReplicatedStorage.Modules.Data.Rensei.GunAim) -- a shot's range multiplier, the Mastery rule

local IsServer = RunService:IsServer()

local WeaponManager = {}

function WeaponManager.ClassOfItem(ItemName)
	local Info = ItemData[ItemName]
	local Class = Info and Info.Type == "Weapon" and Info.Class
	return Class and Tuning.Weapons[Class] and Class or nil
end

-- The TuningConfig weapon table for the character's current weapon (nil = unarmed / fists).
function WeaponManager.Def(Character)
	local Class = Character and Character:GetAttribute("Weapon")
	return Class and Tuning.Weapons[Class] or nil
end

-- Per-item stats (guns), or nil.
function WeaponManager.ItemStats(Character)
	local W = WeaponManager.Def(Character)
	local Item = Character:GetAttribute("WeaponItem")
	return W and W.Items and Item and W.Items[Item] or nil
end

-- Copy of a gun SHOT's def with the held gun's damage, fire rate, range and falloff (gun rework 2026-10-25). Skills (Fan the
-- Hammer) keep their own numbers: the same for every gun. (They were scaled by the gun against Light.Hits[1], which has been the
-- pistol whip since 2026-10-17, so a Forge Tac's fan did 72.)
function WeaponManager.Resolve(Character, Def)
	local Stats = WeaponManager.ItemStats(Character)
	if not Stats or not Def.Shot then return Def end
	local Out = table.clone(Def)
	Out.Damage = Stats.Damage or Def.Damage
	Out.Recovery = Stats.Recovery or Def.Recovery
	Out.Range = Stats.Range or Def.Range
	Out.Falloff = Stats.Falloff
	return Out
end

if IsServer then
	-- ===== Equip =====
	-- Plain tables, emptied explicitly. (They were weak-keyed: a weak table drops an Instance key
	-- once Lua holds no other reference to it, even while the Instance still exists -- a held tool
	-- could vanish from them, leaving its joints behind and its draw / sheathe dead.)
	local Attached = {} -- [Tool] = {joints}
	local Grips = {} -- [Tool] = {{Motor, Weld, Part, Arm}}
	local ToolConns = {} -- [Tool] = connection that detaches it when it leaves the character
	local DrawToken = {} -- [Character] = token of the running draw/sheathe

	local function HeldTool(Character)
		for _, T in ipairs(Character:GetChildren()) do
			if T:IsA("Tool") and Grips[T] then return T end
		end
	end

	-- Heavy weapons slow you while drawn (TuningConfig.Weapons.<Class>.MoveSpeedMult). The shared
	-- SpeedMultiplier attribute (read by every walk-speed writer) = Speed stat x this.
	local function ApplyWeight(Character, Mult)
		Mult = Mult or 1
		if (Character:GetAttribute("WeaponSpeedMultiplier") or 1) == Mult then return end
		local Old = Character:GetAttribute("SpeedMultiplier") or 1
		local Base = Character:GetAttribute("StatSpeedMultiplier") or (Old / (Character:GetAttribute("WeaponSpeedMultiplier") or 1))
		local New = Base * Mult
		Character:SetAttribute("WeaponSpeedMultiplier", Mult ~= 1 and Mult or nil)
		Character:SetAttribute("SpeedMultiplier", New)
		local Humanoid = Character:FindFirstChildOfClass("Humanoid")
		if Humanoid and Old > 0 then Humanoid.WalkSpeed = Humanoid.WalkSpeed / Old * New end
	end

	-- Move the weapon to the hand (Drawn) or its holster.
	local function Place(Character, Tool, Drawn)
		for _, G in ipairs(Grips[Tool] or {}) do
			-- holstered: the holster weld holds it; drawn (or no holster): the arm motor
			local Holstered = G.Weld ~= nil and not Drawn
			if G.Weld then G.Weld.Enabled = Holstered end
			G.Motor.Enabled = not Holstered
		end
		Character:SetAttribute("WeaponDrawn", Drawn)
		local W = WeaponManager.Def(Character)
		ApplyWeight(Character, Drawn and W and W.MoveSpeedMult or 1)
	end

	-- Combat Mode changed: play the draw / sheathe animation and swap at the right moment.
	local function Transition(Character, Drawn)
		local Tool = HeldTool(Character)
		local W = WeaponManager.Def(Character)
		if not Tool or not W then return end
		DrawToken[Character] = nil -- toggling back mid-transition cancels the pending swap
		if (Character:GetAttribute("WeaponDrawn") == true) == Drawn then return end
		local Token = {}
		DrawToken[Character] = Token
		local D = W.Draw or {}
		local Anim = Drawn and D.Equip or (not Drawn and D.Unequip)
		-- Drawn Steel (skill tree): faster draw / sheathe
		local DrawMult = SkillMods.Mult(Character, "DrawSpeed")
		local Speed = ((Drawn and D.EquipSpeed or not Drawn and D.UnequipSpeed) or 1) * DrawMult
		local SwapAt = ((Drawn and D.SwapAt or not Drawn and D.UnequipSwapAt) or 0) / DrawMult
		if Anim then
			local AnimationManager = require(ReplicatedStorage.Modules.Managers.AnimationManager)
			AnimationManager.Play(Character, Anim, {
				Priority = Enum.AnimationPriority.Action2, Speed = Speed,
				Reverse = not Drawn and D.UnequipReverse or nil,
			})
		else
			SwapAt = 0
		end
		local function Swap()
			if DrawToken[Character] ~= Token or HeldTool(Character) ~= Tool then return end
			DrawToken[Character] = nil
			Place(Character, Tool, Drawn)
		end
		if SwapAt <= 0 then Swap() else task.delay(SwapAt, Swap) end
	end

	-- An attack started while still holstered / mid-draw: weapon straight into the hand.
	function WeaponManager.ForceDraw(Character)
		local Tool = HeldTool(Character)
		if not Tool or Character:GetAttribute("WeaponDrawn") then return end
		DrawToken[Character] = nil
		Place(Character, Tool, true)
	end
	local AmmoLeft = {} -- [Character] = {[Item] = rounds}
	local Aim = {} -- [Character] = {Dir, At} (guns, below)

	-- per-character entries go when the character does
	local Tracked = {}
	local function Track(Character)
		if Tracked[Character] then return end
		Tracked[Character] = true
		Character.Destroying:Once(function()
			Tracked[Character], DrawToken[Character], AmmoLeft[Character], Aim[Character] = nil, nil, nil, nil
		end)
	end

	local function Detach(Character, Tool)
		if not Attached[Tool] then return end -- already detached
		for _, Joint in ipairs(Attached[Tool]) do Joint:Destroy() end
		if ToolConns[Tool] then ToolConns[Tool]:Disconnect() end
		Attached[Tool] = nil
		Grips[Tool] = nil
		ToolConns[Tool] = nil
		if Character:GetAttribute("WeaponItem") == Tool.Name then ApplyWeight(Character, 1) end
		if Character:GetAttribute("WeaponItem") == Tool.Name then
			local Ammo = Character:GetAttribute("Ammo")
			if Ammo then
				AmmoLeft[Character] = AmmoLeft[Character] or {}
				AmmoLeft[Character][Tool.Name] = Ammo
			end
			for _, A in ipairs({"Weapon", "WeaponItem", "WeaponDrawn", "Ammo", "MaxAmmo", "ReloadingUntil", "ReloadTime", "ShootingMode"}) do Character:SetAttribute(A, nil) end
		end
	end

	local function Attach(Character, Tool)
		local Class = WeaponManager.ClassOfItem(Tool.Name)
		if not Class or Attached[Tool] then return end
		local Joints = {}
		local ToolGrips = {}
		for _, Part in ipairs(Tool:GetDescendants()) do
			if Part:IsA("BasePart") then
				local Arm = Part:GetAttribute("Arm") and Character:FindFirstChild(Part:GetAttribute("Arm"))
				if Arm and Part:GetAttribute("MotorC0") then
					local M = Instance.new("Motor6D")
					M.Name = Part.Name
					M.Part0 = Arm
					M.Part1 = Part
					M.C0 = Part:GetAttribute("MotorC0")
					M.C1 = Part:GetAttribute("MotorC1")
					M.Parent = Arm
					table.insert(Joints, M)
					local Weld = nil
					local Holster = Part:GetAttribute("HolsterC0")
					local HolsterPart = Holster and Character:FindFirstChild(Part:GetAttribute("HolsterPart") or "Torso")
					if HolsterPart then
						Weld = Instance.new("Weld")
						Weld.Name = "HolsterWeld"
						Weld.Part0 = HolsterPart
						Weld.Part1 = Part
						Weld.C0 = Holster
						Weld.Enabled = false
						Weld.Parent = Part
						table.insert(Joints, Weld)
					end
					table.insert(ToolGrips, {Motor = M, Weld = Weld, Part = Part, Arm = Arm})
				elseif Arm and Part:GetAttribute("WeldC0") then
					local W = Instance.new("Weld")
					W.Name = Part.Name
					W.Part0 = Arm
					W.Part1 = Part
					W.C0 = Part:GetAttribute("WeldC0")
					W.C1 = Part:GetAttribute("WeldC1")
					W.Parent = Arm
					table.insert(Joints, W)
				end
			end
		end
		Attached[Tool] = Joints
		Grips[Tool] = ToolGrips
		Track(Character)
		-- unequipped, destroyed, or the character itself removed (NPC deaths included)
		ToolConns[Tool] = Tool.AncestryChanged:Connect(function()
			if Tool.Parent ~= Character or not Character.Parent then Detach(Character, Tool) end
		end)
		Character:SetAttribute("WeaponItem", Tool.Name)
		Character:SetAttribute("Weapon", Class)
		Place(Character, Tool, Character:GetAttribute("CombatMode") == true)
		local Stats = WeaponManager.ItemStats(Character)
		if Stats and Stats.Magazine then
			local Saved = AmmoLeft[Character] and AmmoLeft[Character][Tool.Name]
			Character:SetAttribute("MaxAmmo", Stats.Magazine)
			Character:SetAttribute("Ammo", Saved or Stats.Magazine)
			if Saved == 0 then WeaponManager.Reload(Character) end
		end
	end

	local function Watch(Character)
		Character:GetAttributeChangedSignal("CombatMode"):Connect(function()
			Transition(Character, Character:GetAttribute("CombatMode") == true)
		end)
		Character.ChildAdded:Connect(function(Child)
			if Child:IsA("Tool") then Attach(Character, Child) end
		end)
		Character.ChildRemoved:Connect(function(Child)
			if Child:IsA("Tool") then Detach(Character, Child) end
		end)
		for _, Child in ipairs(Character:GetChildren()) do
			if Child:IsA("Tool") then Attach(Character, Child) end
		end
	end

	function WeaponManager.Start()
		local function PlayerAdded(Player)
			if Player.Character then Watch(Player.Character) end
			Player.CharacterAdded:Connect(Watch)
		end
		Players.PlayerAdded:Connect(PlayerAdded)
		for _, Player in ipairs(Players:GetPlayers()) do PlayerAdded(Player) end
	end

	-- NPCs / tests: arm a character directly with an item's Tool.
	function WeaponManager.Give(Character, ItemName)
		local Source = ReplicatedStorage.Assets.Items.Weapon:FindFirstChild(ItemName)
		if not Source then return nil end
		for _, T in ipairs(Character:GetChildren()) do if T:IsA("Tool") then T:Destroy() end end
		local Tool = Source:Clone()
		Tool.Parent = Character
		Attach(Character, Tool) -- immediately (ChildAdded is deferred)
		return Tool
	end

	-- ===== Guns =====
	local MAX_AIM_ANGLE = math.rad(100) -- aim may not point behind the character

	function WeaponManager.SetAim(Character, Dir)
		if typeof(Dir) ~= "Vector3" or Dir ~= Dir or Dir.Magnitude < 0.5 or Dir.Magnitude > 1.5 then return end
		Aim[Character] = {Dir = Dir.Unit, At = os.clock()}
	end

	local function AimDirection(Character, Root)
		local Look = Root.CFrame.LookVector
		local A = Aim[Character]
		if A and os.clock() - A.At < 2 then
			local Flat = Vector3.new(A.Dir.X, 0, A.Dir.Z)
			local FlatLook = Vector3.new(Look.X, 0, Look.Z)
			if Flat.Magnitude < 1e-3 or FlatLook.Magnitude < 1e-3
				or math.acos(math.clamp(Flat.Unit:Dot(FlatLook.Unit), -1, 1)) <= MAX_AIM_ANGLE then
				return A.Dir
			end
		end
		return Look
	end

	function WeaponManager.CanFire(Character)
		if (Character:GetAttribute("ReloadingUntil") or 0) > workspace:GetServerTimeNow() then return false end
		return (Character:GetAttribute("Ammo") or 0) > 0
	end

	function WeaponManager.Reload(Character)
		local Stats = WeaponManager.ItemStats(Character)
		if not Stats or not Stats.Magazine then return end
		if (Character:GetAttribute("ReloadingUntil") or 0) > workspace:GetServerTimeNow() then return end
		if (Character:GetAttribute("Ammo") or 0) >= Stats.Magazine then return end
		local Item = Character:GetAttribute("WeaponItem")
		local ReloadTime = Stats.Reload * SkillMods.Mult(Character, "GunReload") -- Marksman
		Character:SetAttribute("ReloadTime", ReloadTime)
		Character:SetAttribute("ReloadingUntil", workspace:GetServerTimeNow() + ReloadTime)
		task.delay(ReloadTime, function()
			if Character.Parent and Character:GetAttribute("WeaponItem") == Item then
				Character:SetAttribute("Ammo", Stats.Magazine)
				Character:SetAttribute("ReloadingUntil", nil)
			end
		end)
	end

	local function Tracer(From, To)
		local Length = (To - From).Magnitude
		if Length < 0.1 then return end
		local P = Instance.new("Part")
		P.Name = "Tracer"
		P.Anchored = true
		P.CanCollide = false
		P.CanQuery = false
		P.CanTouch = false
		P.Material = Enum.Material.Neon
		P.Color = Color3.fromRGB(255, 214, 140)
		P.Size = Vector3.new(0.06, 0.06, Length)
		P.CFrame = CFrame.lookAt(From, To) * CFrame.new(0, 0, -Length / 2)
		P.Parent = workspace.World.Visuals
		Debris:AddItem(P, 0.06)
	end

	-- a flash, sparks and a puff of smoke at the barrel's tip, along the shot (Assets.VFX.Guns.Muzzle: the
	-- owner's "Bullet" emitters from ASSETS TO EXPORT, 2026-10-18; each emitter's Emit attribute = particles)
	local function MuzzleFlash(Barrel, Dir)
		local FX = ReplicatedStorage.Assets.VFX:FindFirstChild("Guns")
		FX = FX and FX:FindFirstChild("Muzzle")
		if not FX or not Barrel then return end
		local Tip = Barrel.Position + Dir * (math.max(Barrel.Size.X, Barrel.Size.Y, Barrel.Size.Z) / 2)
		local A = Instance.new("Attachment")
		A.Name = "MuzzleFlash"
		A.WorldCFrame = CFrame.lookAt(Tip, Tip + Dir)
		A.Parent = workspace.Terrain
		for _, E in ipairs(FX:GetChildren()) do
			if E:IsA("ParticleEmitter") then
				local C = E:Clone()
				C.Parent = A
				C:Emit(E:GetAttribute("Emit") or 6)
			end
		end
		Debris:AddItem(A, 2.5)
	end

	-- One hitscan shot. Uses a round; empty -> automatic reload. Returns {Victim, Result} pairs.
	function WeaponManager.Fire(Character, SkillName, Def)
		local Results = {}
		local Root = Character:FindFirstChild("HumanoidRootPart")
		if not Root or not WeaponManager.CanFire(Character) then return Results end
		Character:SetAttribute("Ammo", Character:GetAttribute("Ammo") - 1)

		local Dir = AimDirection(Character, Root)
		if Def.Spread and Def.Spread > 0 then
			local S = math.rad(Def.Spread)
			Dir = (CFrame.lookAt(Vector3.zero, Dir) * CFrame.Angles((math.random() * 2 - 1) * S, (math.random() * 2 - 1) * S, 0)).LookVector
		end
		local Origin = Root.Position + Vector3.new(0, 1.5, 0)
		local Params = RaycastParams.new()
		Params.FilterType = Enum.RaycastFilterType.Exclude
		Params.FilterDescendantsInstances = {Character, workspace.World.Visuals}
		local Range = (Def.Range or 80) * SkillMods.Mult(Character, "GunRange") -- Marksman
		local Ray = workspace:Raycast(Origin, Dir * Range, Params)
		-- the tracer starts at the gun's barrel
		local Tool = HeldTool(Character) -- the gun (a held hotbar item may sit beside it)
		local Barrel = Tool and Tool:FindFirstChild("Barrel", true)
		Tracer(Barrel and Barrel:IsA("BasePart") and Barrel.Position or Origin, Ray and Ray.Position or Origin + Dir * Range)
		MuzzleFlash(Barrel and Barrel:IsA("BasePart") and Barrel or nil, Dir)

		if Ray then
			local Model = Ray.Instance:FindFirstAncestorOfClass("Model")
			while Model and not Model:FindFirstChildOfClass("Humanoid") and Model.Parent ~= workspace do
				Model = Model.Parent:FindFirstAncestorOfClass("Model")
			end
			local Humanoid = Model and Model:FindFirstChildOfClass("Humanoid")
			if Humanoid and Humanoid.Health > 0 and Model:IsDescendantOf(workspace.World.Live) then
				local SkillData = require(ReplicatedStorage.Modules.Data.SkillData)
				local DamageManager = require(ReplicatedStorage.Modules.Managers.DamageManager)
				local Info = table.clone(SkillData[SkillName])
				Info.Damage = Def.Damage
				Info.Ranged = true
				Info.ShotDistance = (Ray.Position - Origin).Magnitude
				local Result = DamageManager(Character, Model, Info)
				table.insert(Results, {Victim = Model, Result = Result})
			end
		end
		if Character:GetAttribute("Ammo") <= 0 then WeaponManager.Reload(Character) end
		return Results
	end

	-- ===== Passives (all PROPOSALS; numbers in TuningConfig.Weapons.<Class>.Passive) =====
	local function PassiveOf(SkillInfo)
		local W = SkillInfo and SkillInfo.Weapon and Tuning.Weapons[SkillInfo.Weapon]
		return W and W.Passive, W and W.Class
	end

	-- Damage multiplier for a clean hit. Weapon Mastery (skill tree) strengthens the passive's bonus, never a penalty
	-- (GunAim.Mastered; gun rework 2026-10-25: Mastery used to deepen a gun's falloff too).
	local PassiveDamageMult
	function WeaponManager.DamageMult(Attacker, Victim, SkillInfo)
		return GunAim.Mastered(PassiveDamageMult(Attacker, Victim, SkillInfo), SkillMods.Mult(Attacker, "WeaponPassive"))
	end
	function PassiveDamageMult(Attacker, Victim, SkillInfo)
		local P, Class = PassiveOf(SkillInfo)
		if not P then return 1 end
		if Class == "Rapier" then
			local State = Victim:GetAttribute("CombatState")
			if State == "Startup" or State == "Recovery" then return P.CounterHitMult end
		elseif Class == "Gauntlets" then
			local Player = Players:GetPlayerFromCharacter(Attacker)
			local Combo = Player and Player:FindFirstChild("Combo")
			local Stacks = math.min(Combo and Combo.Value or 0, P.MaxStacks)
			return 1 + P.PerStack * Stacks
		elseif Class == "Guns" then
			-- Point Blank, else falloff: the gun's own (SkillInfo.Falloff) or the class one; full damage to Start, Min at End
			if SkillInfo.Ranged then return GunAim.RangeMult(SkillInfo.ShotDistance or math.huge, P, SkillInfo.Falloff) end
		end
		return 1
	end

	-- Posture multiplier when the hit was blocked.
	function WeaponManager.BlockedPostureMult(Attacker, SkillInfo)
		local P = PassiveOf(SkillInfo)
		return P and P.BlockedPostureMult or 1
	end

	function WeaponManager.OnHit(Attacker, Victim, SkillInfo)
		local P, Class = PassiveOf(SkillInfo)
		if Class == "Daggers" and P then
			-- Lacerate: the Bleed status (StatusManager: the user's Bleed VFX; a new hit refreshes it)
			require(ReplicatedStorage.Modules.Managers.StatusManager).Apply(Victim, "Bleed", {
				Duration = P.BleedTicks * P.BleedEvery, Every = P.BleedEvery, Damage = P.BleedDamage * SkillMods.Mult(Attacker, "WeaponPassive"),
			})
		end
	end
else
	-- ===== Client: weapon idle / equip animations =====
	function WeaponManager.StartClient()
		local AnimationManager = require(ReplicatedStorage.Modules.Managers.AnimationManager)
		local Player = Players.LocalPlayer
		local IdleTrack, IdleName = nil, nil

		local function StopIdle()
			if IdleTrack then IdleTrack:Stop(0.2) end
			IdleTrack, IdleName = nil, nil
		end
		-- weapon walk (TuningConfig.Weapons.<Class>.WalkAnim): replaces the default walk while drawn
		local WalkTrack, WalkName = nil, nil
		local function StopWalk()
			if WalkTrack then WalkTrack:Stop(0.15) end
			WalkTrack, WalkName = nil, nil
		end

		-- (draw / sheathe animations are started by the server on Combat Mode changes)
		local function Hook(Character)
			StopIdle()
			StopWalk()
			Character:GetAttributeChangedSignal("Weapon"):Connect(function() StopIdle() StopWalk() end)
		end
		if Player.Character then Hook(Player.Character) end
		Player.CharacterAdded:Connect(Hook)

		-- Draw / sheathe swap the weapon between its holster weld and the hand motor in one frame,
		-- and the two poses can be far apart (the katana's blade turns ~140 degrees). Every client eases
		-- that jump out locally, for every armed character it sees: the joint that just took over
		-- starts at the pose the weapon had last frame and slides to its real C0 (the tool's
		-- MotorC0 / HolsterC0 attribute) over Tuning.WeaponSwapBlend seconds -- longer for a big turn,
		-- at most WeaponSwapTurnRate degrees/s. Visual only: hitboxes never read weapon parts.
		local BlendTime = Tuning.WeaponSwapBlend or 0.15
		local TurnRate = Tuning.WeaponSwapTurnRate or 720
		local Joints = {} -- [Joint] = grip Part
		local LastWorld = {} -- [grip Part] = its CFrame last frame
		local Blends = {} -- [Joint] = {From, To, Start, Duration}

		-- Part1 relative to Part0 = C0 * Transform * C1:Inverse() (a Weld has no Transform)
		local function Anim(Joint)
			return Joint:IsA("Motor6D") and Joint.Transform or CFrame.identity
		end

		local function StartBlend(Joint)
			local Part = Joints[Joint]
			local Was = Part and LastWorld[Part]
			local To = Part and Part:GetAttribute(Joint:IsA("Motor6D") and "MotorC0" or "HolsterC0")
			if not Was or typeof(To) ~= "CFrame" or not Joint.Part0 then return end
			-- where the weapon was, relative to the joint's Part0
			local From = Joint.Part0.CFrame:Inverse() * Was
			local _, Angle = (From:Inverse() * To * Anim(Joint) * Joint.C1:Inverse()):ToAxisAngle()
			local Duration = math.clamp(math.deg(math.abs(Angle)) / TurnRate, BlendTime, BlendTime * 2)
			Blends[Joint] = {From = From, To = To, Start = os.clock(), Duration = Duration}
			Joint.C0 = From * Joint.C1 * Anim(Joint):Inverse()
		end

		local function AddJoint(Joint)
			if Joints[Joint] or not (Joint:IsA("Motor6D") or (Joint:IsA("Weld") and Joint.Name == "HolsterWeld")) then return end
			local Part = Joint.Part1
			if not Part then
				-- the grip part can replicate after its joint
				Joint:GetPropertyChangedSignal("Part1"):Once(function() AddJoint(Joint) end)
				return
			end
			if not Part:GetAttribute("MotorC0") then return end
			Joints[Joint] = Part
			Joint:GetPropertyChangedSignal("Enabled"):Connect(function()
				if Joint.Enabled then StartBlend(Joint) end
			end)
		end
		local Live = workspace:WaitForChild("World"):WaitForChild("Live")
		Live.DescendantAdded:Connect(AddJoint)
		for _, D in ipairs(Live:GetDescendants()) do AddJoint(D) end

		-- After the animation step (PreSimulation): blend from the old pose toward where the joint
		-- would put the weapon THIS frame, so weapon poses that are still fading in or out (the
		-- draw animation's own weapon keys) carry on smoothly under the blend.
		RunService.PreSimulation:Connect(function()
			local Now = os.clock()
			for Joint, B in pairs(Blends) do
				local A = math.clamp((Now - B.Start) / B.Duration, 0, 1)
				if A >= 1 or not Joint.Parent then
					Blends[Joint] = nil
					if Joint.Parent then Joint.C0 = B.To end
				else
					local T = Anim(Joint)
					local Shown = B.From:Lerp(B.To * T * Joint.C1:Inverse(), A * A * (3 - 2 * A)) -- smoothstep
					Joint.C0 = Shown * Joint.C1 * T:Inverse()
				end
			end
		end)
		-- the pose each weapon ended the frame in (where a swap blends from)
		RunService.PostSimulation:Connect(function()
			for Joint, Part in pairs(Joints) do
				if not Joint.Parent or not Part.Parent then
					Joints[Joint], LastWorld[Part], Blends[Joint] = nil, nil, nil
				else
					LastWorld[Part] = Part.CFrame
				end
			end
		end)

		-- Weapon hold pose (weapon joint only, lowest priority) whenever the weapon is drawn, so
		-- attacks that don't animate the weapon still hold it naturally.
		local HoldTrack, HoldName = nil, nil
		local CarryTrack, CarryTrackName = nil, nil
		local function SetHold(Character, Name)
			-- (also re-played when something stopped it: a ragdoll stops every track)
			if Name == HoldName and (not HoldTrack or HoldTrack.IsPlaying) then return end
			if HoldTrack then HoldTrack:Stop(0.15) end
			HoldTrack, HoldName = nil, nil
			if Name and AnimationManager.Has(Character, Name) then
				HoldTrack = AnimationManager.Play(Character, Name, {Looped = true, Priority = Enum.AnimationPriority.Core})
				HoldName = HoldTrack and Name
			end
		end

		-- Weapon idle pose while standing still and not attacking.
		task.spawn(function()
			while true do
				task.wait(0.1)
				local Character = Player.Character
				local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
				local Class = Character and Character:GetAttribute("Weapon")
				local Def = Class and Tuning.Weapons[Class]
				-- "drawn": the weapon is out. Bare-handed, the active style's stance (Rensei.Styles: Boxing /
				-- Lethwei idle + walk) shows while in Combat Mode.
				local Drawn = Character and Character:GetAttribute("WeaponDrawn")
				if Character and not Def then
					local _, S = Styles.Active(Character)
					if S and (S.Idle or S.Walk) then
						Def = {IdleAnim = S.Idle, WalkAnim = S.Walk}
						Drawn = Character:GetAttribute("CombatMode") == true
					end
				end
				local Name = Def and Def.IdleAnim
				if Character then
					SetHold(Character, Def and Drawn and Def.HoldAnim or nil)
					-- carry pose (greatsword on the shoulder) while idle / walking / running / falling;
					-- attacks, blocking, climbing, wall runs and draw/sheathe take the arm instead
					local CarryName = Def and Def.CarryAnim
					local Blocking = false
					for _, T in ipairs(Humanoid and Humanoid.Animator:GetPlayingAnimationTracks() or {}) do
						if T.Name == "BlockIdle" or T.Name:find("_Equip") or T.Name:find("_Unequip") then Blocking = true end
					end
					local WantCarry = CarryName and Humanoid and Drawn
						and Character:GetAttribute("CombatState") == nil and Humanoid.AutoRotate and not Blocking
						and not Character:GetAttribute("Knocked") and not Character:GetAttribute("Carrying")
					if WantCarry and CarryName ~= CarryTrackName then
						if CarryTrack then CarryTrack:Stop(0.2) end
						CarryTrack = AnimationManager.Has(Character, CarryName) and AnimationManager.Play(Character, CarryName, {Looped = true, Priority = Enum.AnimationPriority.Action})
						CarryTrackName = CarryTrack and CarryName or nil
					elseif not WantCarry and CarryTrack then
						CarryTrack:Stop(0.12)
						CarryTrack, CarryTrackName = nil, nil
					end
				end
				local Want = Humanoid and Name and Drawn and AnimationManager.Has(Character, Name)
					and Humanoid.MoveDirection.Magnitude < 0.1 and Character:GetAttribute("CombatState") == nil
					and Humanoid.FloorMaterial ~= Enum.Material.Air
				-- (or it was stopped from outside: a block / heavy / hit reaction stops the non-base tracks)
				if Want and (IdleName ~= Name or not (IdleTrack and IdleTrack.IsPlaying)) then
					StopIdle()
					IdleTrack = AnimationManager.Play(Character, Name, {Looped = true, Priority = Enum.AnimationPriority.Idle})
					IdleName = IdleTrack and Name
				elseif not Want and IdleName then
					StopIdle()
				end
				-- walking (not sprinting: the Run module owns the run / weapon run) with the weapon drawn
				local Walk = Def and Def.WalkAnim
				local Sprinting = false
				for _, T in ipairs(Walk and Humanoid and Humanoid.Animator:GetPlayingAnimationTracks() or {}) do
					if T.Name == "Run" or T.Name == "SpeedyRun" or T.Name == Def.RunAnim then Sprinting = true end
				end
				local WantWalk = Humanoid and Walk and Drawn and AnimationManager.Has(Character, Walk)
					and Humanoid.MoveDirection.Magnitude >= 0.1 and not Sprinting and Character:GetAttribute("CombatState") == nil
					and Humanoid.FloorMaterial ~= Enum.Material.Air and not Character:GetAttribute("Carrying")
				if WantWalk and (WalkName ~= Walk or not (WalkTrack and WalkTrack.IsPlaying)) then
					StopWalk()
					WalkTrack = AnimationManager.Play(Character, Walk, {Looped = true, Priority = Enum.AnimationPriority.Movement})
					WalkName = WalkTrack and Walk
				elseif not WantWalk and WalkName then
					StopWalk()
				end
			end
		end)
	end
end

return WeaponManager

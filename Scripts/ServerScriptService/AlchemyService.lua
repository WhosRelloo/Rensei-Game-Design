-- AlchemyService: casting alchemy (controls doc: Z primary, X secondary, C utility, V ultimate --
-- meter based, cooldowns, telegraphed, utility/control focused, not the main damage source).
--
-- Flow: key DOWN (client) -> Requests.Alchemy(Slot, Aim) -> AlchemyService.Cast, which re-checks
-- EVERYTHING on the server: alive, Combat Mode, free to act, an affinity, a BUILT ability in that
-- slot, the clan rule (Clans.CanUseAbility -- the Marcoh restriction), the slot's cooldown and the
-- meter cost. V reaches here only when there is nothing to carry (Requests.Downed: Carry first).
-- Key UP -> Requests.Alchemy(Slot, Aim, "End") -> AlchemyService.Release.
-- The cast (user request 2026-10-14): CLAP -> while the key is still held the clap keeps going
-- (TuningConfig.Alchemy.Transmute.MaxHold) -> on release the hands SLAM the ground (or the arm
-- extends) -> the move's own animation and windup (the sheet's Cast) -> release. The hands burn
-- from the clap until the release. It all runs as the attack's Startup (AttackRunner Prelude), so a
-- stun anywhere in it cancels the ability. Cost and cooldown are paid when the cast STARTS, with no
-- refund, so a read cast can be punished. The aim is taken when the key is released.
--
-- Affinity = the profile's Identity.Affinity. Nothing assigns one yet (character creation isn't
-- built). In Studio ONLY, this script's attribute StudioTestAffinity stands in for an empty one;
-- it is never saved and never applies on a live server.
--
-- Numbers: the design sheet's rows (Modules.Data.Rensei.Alchemy) + PROPOSALS in
-- TuningConfig.Alchemy. Built: all five kits -- Flame, Ice, Wind, Metal and Earth (Earth from the
-- approved proposal; Cryo Shift's counter and Steel Guard's wall have no slam: they are up from the clap).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage.Modules
local Managers = Modules.Managers
local States = Modules.Skills.States
local Rensei = Modules.Data.Rensei

local WCS = require(Modules.Framework.WCS)
local Tuning = require(Rensei.TuningConfig)
local Registry = require(Rensei.Alchemy)
local Clans = require(Rensei.Clans)
local SkillData = require(Modules.Data.SkillData)
local AttackRunner = require(Managers.AttackRunner)
local ResourceManager = require(Managers.ResourceManager)
local MoverManager = require(Managers.MoverManager)
local DamageManager = require(Managers.DamageManager)
local DownedManager = require(Managers.DownedManager)
local Stun = require(States.Stun)
local Attacking = require(States.Attacking)
local Blocking = require(States.Blocking)
local Climbing = require(States.Climbing)

local HitFX = require(Modules.Effects.Combat.Hit)
local AnimationManager = require(Managers.AnimationManager)
local Transmute = require(Modules.Effects.Alchemy.Transmute)
local Burst = require(Modules.Effects.Alchemy.Burst)
local PhoenixFX = require(Modules.Effects.Alchemy.Phoenix)
local Warning = require(Modules.Effects.Alchemy.Warning)
local Sigil = require(Modules.Effects.Alchemy.Sigil)
local IFrame = require(States.IFrame)
local Fireball = require(Modules.Effects.Alchemy.Fireball)
local StatusManager = require(Managers.StatusManager)
local HitboxManager = require(Managers.HitboxManager)
local CounterManager = require(Managers.CounterManager)
local IceSpikes = require(Modules.Effects.Alchemy.IceSpikes)
local IceAxe = require(Modules.Effects.Alchemy.IceAxe)
local IceTrap = require(Modules.Effects.Alchemy.IceTrap)
local FrostNova = require(Modules.Effects.Alchemy.FrostNova)
local IceGuard = require(Modules.Effects.Alchemy.IceGuard)
local AirSlashFX = require(Modules.Effects.Alchemy.AirSlash)
local GaleBurstFX = require(Modules.Effects.Alchemy.GaleBurst)
local UpdraftFX = require(Modules.Effects.Alchemy.Updraft)
local TornadoFX = require(Modules.Effects.Alchemy.Tornado)
local SteelGuardFX = require(Modules.Effects.Alchemy.SteelGuard)
local SteelSpikesFX = require(Modules.Effects.Alchemy.SteelSpikes)
local AnvilDropFX = require(Modules.Effects.Alchemy.AnvilDrop)
local SteelLanceFX = require(Modules.Effects.Alchemy.SteelLance)
local AlloyBladeFX = require(Modules.Effects.Alchemy.AlloyBlade)
local LineWarningFX = require(Modules.Effects.Alchemy.LineWarning)
local ShieldManager = require(Managers.ShieldManager)
local SkillMods = require(Managers.SkillMods) -- the Mastery skill tree's effects (Mod_<Key>)
local EarthSpikesFX = require(Modules.Effects.Alchemy.EarthSpikes)
local EarthWallFX = require(Modules.Effects.Alchemy.EarthWall)
local EarthPillarsFX = require(Modules.Effects.Alchemy.EarthPillars)

-- projectile visuals by Impl.Visual (default: Ignite's fireball); same client contract
local ProjectileVisuals = {Fireball = Fireball, AirSlash = AirSlashFX}

local UIService = require(ServerScriptService.UIService)
local ProgressionService = require(ServerScriptService.ProgressionService)

local Cfg = Tuning.Alchemy
local Slots = {Z = true, X = true, C = true, V = true}

local AlchemyService = {}

-- ===== Feedback =====
-- The same message at most once per 2s per player (mashing a key never floods the banner queue).
local LastTold = {} -- [Player] = {[Text] = os.clock()}
Players.PlayerRemoving:Connect(function(Player) LastTold[Player] = nil end)
local function Tell(Player, Text)
	local Told = LastTold[Player] or {}
	LastTold[Player] = Told
	if Told[Text] and os.clock() - Told[Text] < 2 then return end
	Told[Text] = os.clock()
	UIService.Notify(Player, "Toast", {Text = Text})
end

-- ===== Who can cast what =====
function AlchemyService.AffinityOf(Player)
	local Data = ProgressionService.GetData(Player)
	local Affinity = Data and Data.Identity and Data.Identity.Affinity or ""
	if Affinity == "" and RunService:IsStudio() then
		Affinity = script:GetAttribute("StudioTestAffinity") or ""
	end
	return table.find(Registry.Affinities, Affinity) and Affinity or nil
end

-- The alchemy slot bar (Modules.UI.AlchemyUI) shows only for a player with an alchemy path: publish
-- it as the Player attribute Affinity once the profile is loaded. Call PublishAffinity again
-- whenever the affinity changes (character creation, when it exists).
function AlchemyService.PublishAffinity(Player)
	Player:SetAttribute("Affinity", AlchemyService.AffinityOf(Player))
end
local function WatchPlayer(Player)
	task.spawn(function()
		for _ = 1, 60 do
			if not Player.Parent then return end
			if ProgressionService.GetData(Player) then break end
			task.wait(1)
		end
		AlchemyService.PublishAffinity(Player)
	end)
end
Players.PlayerAdded:Connect(WatchPlayer)
for _, Player in ipairs(Players:GetPlayers()) do WatchPlayer(Player) end
script:GetAttributeChangedSignal("StudioTestAffinity"):Connect(function()
	for _, Player in ipairs(Players:GetPlayers()) do AlchemyService.PublishAffinity(Player) end
end)

local function ClanOf(Player)
	local Data = ProgressionService.GetData(Player)
	local Clan = Data and Data.Identity and Data.Identity.Clan
	return Clan ~= "" and Clan or nil
end

local function AbilityFor(Affinity, Slot)
	for _, Def in ipairs(Registry.ForAffinity(Affinity)) do
		if Def.Key == Slot then return Def end
	end
end

local function CanAct(Character, WC)
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid or Humanoid.Health <= 0 or not WC then return false end
	if DownedManager.IsKnocked(Character) or Character:GetAttribute("Carrying") or Character:GetAttribute("Gripping") then
		return false
	end
	return not AttackRunner.IsRunning(Character) and not WC:HasStatusEffects({Stun, Attacking, Blocking, Climbing})
end

-- Where the cast goes: the client's camera direction, clamped -- at most AimMaxYaw away from where
-- you face (else straight ahead) and AimMaxPitch up / down. Anything malformed = straight ahead.
local function AimDirection(Root, Aim)
	local Look = Root.CFrame.LookVector
	local Flat = Vector3.new(Look.X, 0, Look.Z)
	Flat = Flat.Magnitude > 1e-3 and Flat.Unit or Vector3.new(0, 0, -1)
	if typeof(Aim) ~= "Vector3" or Aim ~= Aim or Aim.Magnitude < 0.5 or Aim.Magnitude > 1.5 then return Flat end
	Aim = Aim.Unit
	local AimFlat = Vector3.new(Aim.X, 0, Aim.Z)
	if AimFlat.Magnitude < 1e-3 then return Flat end
	AimFlat = AimFlat.Unit
	if math.deg(math.acos(math.clamp(AimFlat:Dot(Flat), -1, 1))) > Cfg.AimMaxYaw then return Flat end
	local Pitch = math.rad(math.clamp(math.deg(math.asin(math.clamp(Aim.Y, -1, 1))), -Cfg.AimMaxPitch, Cfg.AimMaxPitch))
	return (AimFlat * math.cos(Pitch) + Vector3.new(0, math.sin(Pitch), 0)).Unit
end

-- ===== Burn =====
-- The Burn status (StatusManager: the user's Fire status VFX, damage every tick, refreshes on re-hit),
-- scaled by the caster's alchemy damage.
local function Burn(Caster, Victim, B)
	StatusManager.Apply(Victim, "Burn", {
		Duration = B.Ticks * B.Every, Every = B.Every, Damage = B.Damage,
		Mult = Caster:GetAttribute("AlchemyMultiplier") or 1,
	})
end

-- The move's on-hit status (owner: alchemy hits apply their element's status): Impl.Burn (Flame),
-- Impl.Freeze = seconds frozen (Ice). Only on a clean hit.
local function ApplyOnHit(Caster, Victim, Impl, Result)
	if Result ~= "Hit" or not Victim.Parent then return end
	if Impl.Burn then Burn(Caster, Victim, Impl.Burn) end
	if Impl.Freeze then StatusManager.Apply(Victim, "Freeze", {Duration = Impl.Freeze}) end
	if Impl.Bleed then -- Earth (Rising Thorn)
		StatusManager.Apply(Victim, "Bleed", {
			Duration = Impl.Bleed.Duration, Every = Impl.Bleed.Every, Damage = Impl.Bleed.Damage,
			Mult = Caster:GetAttribute("AlchemyMultiplier") or 1,
		})
	end
end

-- ===== Projectile (Ignite) =====
-- Server-authoritative: a sphere swept along the line every server frame from the caster's chest
-- (so point-blank targets can't be skipped). The first character or world surface it touches ends
-- it. Clients only draw it (Effects.Alchemy.Fireball).
local function Launch(Caster, Impl, SkillName, Direction)
	local Root = Caster:FindFirstChild("HumanoidRootPart")
	if not Root then return end
	local Info = SkillData[SkillName]
	local Facing = CFrame.lookAt(Root.Position, Root.Position + Vector3.new(Direction.X, 0, Direction.Z))
	local Hand = (Facing * CFrame.new(Impl.SpawnOffset)).Position
	local Pos = Root.Position + Vector3.new(0, Impl.SpawnOffset.Y, 0)
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = {Caster, workspace.World.Visuals}

	local VisualFX = ProjectileVisuals[Impl.Visual or "Fireball"] or Fireball
	local Visual = VisualFX.new(Hand, Direction, Impl.Speed, Impl.Range, workspace:GetServerTimeNow()):Start(Players:GetPlayers())
	local Traveled = 0
	local Conn
	Conn = RunService.Heartbeat:Connect(function(Dt)
		local Step = math.min(Impl.Speed * Dt, Impl.Range - Traveled)
		if Step <= 0 then
			Conn:Disconnect() -- out of range: the clients fizzle it themselves
			return
		end
		local Hit = workspace:Spherecast(Pos, Impl.Radius, Direction * Step, Params)
		if not Hit then
			Pos += Direction * Step
			Traveled += Step
			return
		end
		Conn:Disconnect()
		local At = Pos + Direction * Hit.Distance
		local Victim = nil
		if Hit.Instance:IsDescendantOf(workspace.World.Live) then
			Victim = Hit.Instance
			while Victim.Parent ~= workspace.World.Live do Victim = Victim.Parent end
		end
		local Humanoid = Victim and Victim:FindFirstChildOfClass("Humanoid")
		if Humanoid and Humanoid.Health > 0 and Victim:FindFirstChild("HumanoidRootPart") then
			local HitInfo = table.clone(Info)
			HitInfo.FromPosition = At - Direction * 4 -- a guard must face where the ball came from
			local Result = DamageManager(Caster, Victim, HitInfo)
			ProgressionService.RecordHit(Caster, Victim, Result)
			ApplyOnHit(Caster, Victim, Impl, Result)
		end
		pcall(function() Visual:Impact(At) end)
	end)
end

-- ===== Area / cone / lunge / phoenix (the rest of the Flame kit) =====
local function VictimsNear(Caster, Center, Radius)
	local Params = OverlapParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = {workspace.World.Live}
	local Seen, List = {}, {}
	for _, Part in ipairs(workspace:GetPartBoundsInRadius(Center, Radius, Params)) do
		local M = Part
		while M and M.Parent ~= workspace.World.Live do M = M.Parent end
		if M and M ~= Caster and not Seen[M] then
			Seen[M] = true
			local H = M:FindFirstChildOfClass("Humanoid")
			if H and H.Health > 0 and M:FindFirstChild("HumanoidRootPart") then table.insert(List, M) end
		end
	end
	return List
end

-- nothing solid of the map between the two points (no hitting through walls)
local MapParams = RaycastParams.new()
MapParams.FilterType = Enum.RaycastFilterType.Include
local function Clear(From, To)
	MapParams.FilterDescendantsInstances = {workspace.World.Map}
	return workspace:Raycast(From, To - From, MapParams) == nil
end

local function HitWith(Caster, Victim, SkillName, From)
	if not Caster.Parent or not Caster:FindFirstChild("HumanoidRootPart") then return nil end
	local Info = table.clone(SkillData[SkillName])
	Info.FromPosition = From -- a guard must face where the alchemy came from
	local Result = DamageManager(Caster, Victim, Info)
	ProgressionService.RecordHit(Caster, Victim, Result)
	return Result
end

local Sweep -- (below)

local function Flat(V)
	local F = Vector3.new(V.X, 0, V.Z)
	return F.Magnitude > 1e-3 and F.Unit or Vector3.new(0, 0, -1)
end

local Kinds = {}

-- The attack's own server hitbox (Impl.Hitbox / Reach), re-sampled every server frame for Duration
-- (default: the active window); each victim is hit once and gets the move's on-hit status. Stops if
-- the caster is stunned.
function Sweep(Ctx, Duration)
	local Character, Impl = Ctx.Character, Ctx.Impl
	local Info = SkillData[Ctx.SkillName]
	local Results, Seen = {}, {}
	local Start = os.clock()
	Duration = Duration or Impl.Active
	repeat
		if not Character.Parent or not Character:FindFirstChild("HumanoidRootPart") then break end
		if Ctx.WC and Ctx.WC:HasStatusEffects({Stun}) then break end
		for _, Victim in ipairs(HitboxManager.CreateHitbox(Character, Info)) do
			if not Seen[Victim] and typeof(Victim) == "Instance" and Victim:IsA("Model") and Victim:FindFirstChildOfClass("Humanoid") then
				Seen[Victim] = true
				local Result = DamageManager(Character, Victim, Info)
				ProgressionService.RecordHit(Character, Victim, Result)
				ApplyOnHit(Character, Victim, Impl, Result)
				table.insert(Results, {Victim = Victim, Result = Result})
			end
		end
		if os.clock() - Start >= Duration then break end
		RunService.Heartbeat:Wait()
	until false
	return Results
end

-- Fireball (Ignite)
Kinds.Projectile = {
	Strike = function(Ctx)
		Launch(Ctx.Character, Ctx.Impl, Ctx.SkillName, Ctx.Direction)
	end,
}

-- Scorching Wave: everyone inside the cone in front of the caster, once, with a small knockback.
Kinds.Cone = {
	Strike = function(Ctx)
		local Root, Impl = Ctx.Root, Ctx.Impl
		local Dir = Flat(Ctx.Direction)
		local Hands = Root.Position + Dir * 2 + Vector3.new(0, 0.3, 0)
		Burst.new("FireElement/scorchingwave/conefire", CFrame.lookAt(Hands, Hands + Dir)):Start(Players:GetPlayers())
		local Ground = Root.Position + Dir * 4 - Vector3.new(0, 2.6, 0)
		Burst.new("FireElement/scorchingwave/groundimpact", CFrame.lookAt(Ground, Ground + Dir)):Start(Players:GetPlayers())
		for _, Victim in ipairs(VictimsNear(Ctx.Character, Root.Position, Impl.Range)) do
			local To = Victim.HumanoidRootPart.Position - Root.Position
			local ToFlat = Vector3.new(To.X, 0, To.Z)
			local Inside = ToFlat.Magnitude < 2
				or math.deg(math.acos(math.clamp(ToFlat.Unit:Dot(Dir), -1, 1))) <= Impl.HalfAngle
			if Inside and Clear(Root.Position, Victim.HumanoidRootPart.Position) then
				ApplyOnHit(Ctx.Character, Victim, Impl, HitWith(Ctx.Character, Victim, Ctx.SkillName, Root.Position))
			end
		end
	end,
}

-- Inferno Lance: a burning dash with i-frames as it starts; the attack's own hitbox sweeps along it.
Kinds.Lunge = {
	OnActive = function(Ctx)
		local Impl, Character, Root = Ctx.Impl, Ctx.Character, Ctx.Root
		if Ctx.WC and Impl.IFrames then pcall(function() IFrame.new(Ctx.WC):Start(Impl.IFrames) end) end
		MoverManager.CreateMover(Character, "Lunge", {Speed = Impl.Lunge, D = Impl.LungeTime})
		Burst.new("FireElement/infernolance/Dash", Root.CFrame):Start(Players:GetPlayers())
	end,
	-- the dash runs on the caster's client, so the server sees it arrive a moment late: keep the hitbox
	-- sweeping for the whole dash as the server sees it (LungeTime + HitLag), in the background
	Strike = function(Ctx)
		task.spawn(Sweep, Ctx, Ctx.Impl.LungeTime + (Ctx.Impl.HitLag or 0.35))
		return {}
	end,
}

-- Phoenix Drive: the alchemy circle opens under the caster for the summoning (owner request); the
-- crash point is fixed when the windup starts and marked for everyone (danger ring); the phoenix
-- flies there, crashes (Crash + burn), and the ground explodes ExplosionDelay later (Explosion).
Kinds.Phoenix = {
	OnStartup = function(Ctx)
		local Impl, Root = Ctx.Impl, Ctx.Root
		Ctx.Sigil = Sigil.new(Ctx.Character, Impl.SigilRadius or 8, Impl.Element):Start(Players:GetPlayers())
		local Params = RaycastParams.new()
		Params.FilterType = Enum.RaycastFilterType.Exclude
		Params.FilterDescendantsInstances = {workspace.World.Live, workspace.World.Visuals}
		-- the aim stops under the first character it crosses (as Rising Thorn's does), so a level aim at someone
		-- close lands on them instead of 45 studs behind them (2026-10-18)
		local AimParams = RaycastParams.new()
		AimParams.FilterType = Enum.RaycastFilterType.Exclude
		AimParams.FilterDescendantsInstances = {Ctx.Character, workspace.World.Visuals}
		local Chest = Root.Position + Vector3.new(0, 1.5, 0)
		local Ray = workspace:Raycast(Chest, Ctx.Direction * Impl.Range, AimParams)
		local Point = Ray and Ray.Position or Chest + Ctx.Direction * Impl.Range
		-- aimed at your own feet: the phoenix still flies out at least MinRange
		local Out = Vector3.new(Point.X - Root.Position.X, 0, Point.Z - Root.Position.Z)
		if Out.Magnitude < (Impl.MinRange or 0) then
			Point = Root.Position + Flat(Ctx.Direction) * Impl.MinRange
		end
		local Down = workspace:Raycast(Point + Vector3.new(0, 3, 0), Vector3.new(0, -80, 0), Params)
		Ctx.Target = Down and Down.Position or Point
		local Lead = Ctx.Def.Cast + Impl.Active + Impl.FlightTime + Impl.ExplosionDelay
		Ctx.Warning = Warning.new(Ctx.Target, Impl.ExplosionRadius, Lead):Start(Players:GetPlayers())
	end,
	Strike = function(Ctx)
		local Impl, Caster, Target = Ctx.Impl, Ctx.Character, Ctx.Target
		if Ctx.Sigil then pcall(function() Ctx.Sigil:Destroy() end) Ctx.Sigil = nil end -- the phoenix leaves the circle
		if not Target then return end
		local From = Ctx.Root.Position + Vector3.new(0, 4, 0)
		PhoenixFX.new(From, Target, Impl.FlightTime, workspace:GetServerTimeNow()):Start(Players:GetPlayers())
		local Above = Target + Vector3.new(0, 2.5, 0)
		task.delay(Impl.FlightTime, function()
			Burst.new("FireElement/scorchingwave/groundimpact", CFrame.new(Target)):Start(Players:GetPlayers())
			for _, Victim in ipairs(VictimsNear(Caster, Target, Impl.CrashRadius)) do
				if Clear(Above, Victim.HumanoidRootPart.Position) then
					ApplyOnHit(Caster, Victim, Impl, HitWith(Caster, Victim, Ctx.SkillName .. "Crash", Above))
				end
			end
			task.delay(Impl.ExplosionDelay, function()
				Burst.new("FireElement/phoenixdrive/explosion", CFrame.new(Target)):Start(Players:GetPlayers())
				for _, Victim in ipairs(VictimsNear(Caster, Target, Impl.ExplosionRadius)) do
					if Clear(Above, Victim.HumanoidRootPart.Position) then
						HitWith(Caster, Victim, Ctx.SkillName .. "Explosion", Above)
					end
				end
			end)
		end)
	end,
	OnInterrupted = function(Ctx)
		if Ctx.Warning then pcall(function() Ctx.Warning:Destroy() end) end
		if Ctx.Sigil then pcall(function() Ctx.Sigil:Destroy() end) end
	end,
}

-- ===== Ice =====
local function GroundBelow(Position)
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = {workspace.World.Live, workspace.World.Visuals}
	local Down = workspace:Raycast(Position + Vector3.new(0, 3, 0), Vector3.new(0, -80, 0), Params)
	return Down and Down.Position or Position - Vector3.new(0, 3, 0)
end

-- Cryo Shift: a reactive counter. It is up from the clap for Window seconds (the caster glazed in
-- frost, readable). The first hit that reaches them (not UNBLOCKABLE) is cancelled: the attacker
-- takes the counter hit and is frozen, the caster gets damage resist for a moment.
Kinds.Counter = {
	OnClap = function(Ctx)
		local Impl, Caster = Ctx.Impl, Ctx.Character
		Ctx.Guard = IceGuard.new(Caster, Impl.Window):Start(Players:GetPlayers())
		CounterManager.Open(Caster, Impl.Window, function(Attacker)
			Ctx.Triggered = true
			pcall(function() Ctx.Guard:Trigger() end)
			AnimationManager.Play(Caster, "Parry" .. math.random(1, 2), {Priority = Enum.AnimationPriority.Action4})
			local Resist = Impl.Resist
			if Resist then
				Caster:SetAttribute("DamageResist", Resist.Amount)
				Caster:SetAttribute("DamageResistUntil", workspace:GetServerTimeNow() + Resist.Duration)
			end
			local ARoot = Attacker and Attacker.Parent and Attacker:FindFirstChild("HumanoidRootPart")
			if not ARoot or Attacker == Caster then return end
			IceSpikes.new(GroundBelow(ARoot.Position), 2.6, 7, 4.5, Impl.Freeze or 1, true):Start(Players:GetPlayers())
			local Result = HitWith(Caster, Attacker, Ctx.SkillName .. "Counter", Ctx.Root.Position)
			ApplyOnHit(Caster, Attacker, Impl, Result)
		end)
	end,
	OnClapEnd = function(Ctx)
		CounterManager.Close(Ctx.Character)
		if not Ctx.Triggered and Ctx.Guard then pcall(function() Ctx.Guard:Destroy() end) end
	end,
	Strike = function() return {} end, -- the counter itself is the move
	OnInterrupted = function(Ctx)
		CounterManager.Close(Ctx.Character)
		if Ctx.Guard then pcall(function() Ctx.Guard:Destroy() end) end
	end,
}

-- Coldsteel Smash: an ice greataxe forms in the hand; a step in and a heavy swing (the attack's own
-- hitbox), freezing what it hits.
-- (also Rising Wind: Impl.Updraft = a column of wind instead of the axe; its launch is the hit's Uptilt)
Kinds.Melee = {
	OnStartup = function(Ctx)
		local Impl = Ctx.Impl
		if Impl.Element == "IceElement" then
			Ctx.Axe = IceAxe.new(Ctx.Character, Ctx.Def.Cast + Impl.Active + Impl.Recovery * 0.6):Start(Players:GetPlayers())
		end
	end,
	OnActive = function(Ctx)
		local Impl = Ctx.Impl
		if Impl.Step then MoverManager.CreateMover(Ctx.Character, "Lunge", {Speed = Impl.Step, D = Impl.StepTime or 0.15}) end
		if Impl.Updraft then
			local Front = Ctx.Root.Position + Flat(Ctx.Root.CFrame.LookVector) * (Impl.Reach or 4)
			UpdraftFX.new(GroundBelow(Front), 16, 4):Start(Players:GetPlayers())
		end
	end,
	Strike = function(Ctx) return Sweep(Ctx) end,
	OnInterrupted = function(Ctx)
		if Ctx.Axe then pcall(function() Ctx.Axe:Destroy() end) end
	end,
}

-- Ice Shards: a frost circle is sent to the aimed spot (Range, at least MinRange out); after ArmTime it
-- waits up to Life seconds for an enemy to step in. Then shards erupt: everyone inside is hit and
-- frozen. One trap per caster.
local Traps = {} -- [Caster] = token of their live trap (cleared when it springs / melts)
Kinds.Trap = {
	Strike = function(Ctx)
		local Impl, Caster, Root = Ctx.Impl, Ctx.Character, Ctx.Root
		local Params = RaycastParams.new()
		Params.FilterType = Enum.RaycastFilterType.Exclude
		Params.FilterDescendantsInstances = {workspace.World.Live, workspace.World.Visuals}
		local Chest = Root.Position + Vector3.new(0, 1.5, 0)
		local Ray = workspace:Raycast(Chest, Ctx.Direction * Impl.Range, Params)
		local Point = Ray and Ray.Position or Chest + Ctx.Direction * Impl.Range
		local Out = Vector3.new(Point.X - Root.Position.X, 0, Point.Z - Root.Position.Z)
		if Out.Magnitude < Impl.MinRange then Point = Root.Position + Flat(Ctx.Direction) * Impl.MinRange end
		local Spot = GroundBelow(Point)
		local Token = {}
		Traps[Caster] = Token
		local Visual = IceTrap.new(Spot, Impl.Radius, Impl.Life):Start(Players:GetPlayers())
		local Above = Spot + Vector3.new(0, 2.5, 0)
		task.spawn(function()
			local Start = os.clock()
			while os.clock() - Start < Impl.Life do
				if Traps[Caster] ~= Token or not Caster.Parent then break end
				if os.clock() - Start >= Impl.ArmTime then
					local Inside = {}
					for _, Victim in ipairs(VictimsNear(Caster, Spot, Impl.Radius)) do
						if Clear(Above, Victim.HumanoidRootPart.Position) then table.insert(Inside, Victim) end
					end
					if #Inside > 0 then
						Traps[Caster] = nil
						pcall(function() Visual:Trigger() end)
						IceSpikes.new(Spot, Impl.Radius, 14, 5, Impl.Freeze, false):Start(Players:GetPlayers())
						for _, Victim in ipairs(Inside) do
							ApplyOnHit(Caster, Victim, Impl, HitWith(Caster, Victim, Ctx.SkillName, Above))
						end
						return
					end
				end
				task.wait(0.05)
			end
			if Traps[Caster] == Token then Traps[Caster] = nil end
			pcall(function() Visual:Destroy() end) -- melted (or replaced by a newer trap)
		end)
		return {}
	end,
}

-- Absolute Zero: the circle opens under the caster and the area around them is marked (danger ring);
-- when the cast completes the ground freezes over and ice erupts across the whole area -- everyone
-- inside is hit and frozen solid.
Kinds.Nova = {
	OnStartup = function(Ctx)
		local Impl = Ctx.Impl
		Ctx.Sigil = Sigil.new(Ctx.Character, Impl.SigilRadius or 8, Impl.Element):Start(Players:GetPlayers())
		Ctx.Center = GroundBelow(Ctx.Root.Position)
		Ctx.Warning = Warning.new(Ctx.Center, Impl.Radius, Ctx.Def.Cast + Impl.Active):Start(Players:GetPlayers())
	end,
	Strike = function(Ctx)
		local Impl, Caster, Center = Ctx.Impl, Ctx.Character, Ctx.Center
		if Ctx.Sigil then pcall(function() Ctx.Sigil:Destroy() end) Ctx.Sigil = nil end
		if not Center then return {} end
		FrostNova.new(Center, Impl.Radius, Impl.Freeze):Start(Players:GetPlayers())
		IceSpikes.new(Center, Impl.Radius, 18, 7, Impl.Freeze - 0.4, true):Start(Players:GetPlayers())
		IceSpikes.new(Center, Impl.Radius * 0.75, 14, 5, Impl.Freeze - 0.4, false):Start(Players:GetPlayers())
		local Above = Center + Vector3.new(0, 3, 0)
		for _, Victim in ipairs(VictimsNear(Caster, Center, Impl.Radius)) do
			if Clear(Above, Victim.HumanoidRootPart.Position) then
				ApplyOnHit(Caster, Victim, Impl, HitWith(Caster, Victim, Ctx.SkillName, Above))
			end
		end
		return {}
	end,
	OnInterrupted = function(Ctx)
		if Ctx.Warning then pcall(function() Ctx.Warning:Destroy() end) end
		if Ctx.Sigil then pcall(function() Ctx.Sigil:Destroy() end) end
	end,
}

-- ===== Wind =====
-- Gale Burst: Pulses blasts of wind around the caster, Every seconds apart (the multi-hit split);
-- every blast stuns, the last one shoves everyone away from the caster.
Kinds.Burst = {
	Strike = function(Ctx)
		local Impl, Caster, Root = Ctx.Impl, Ctx.Character, Ctx.Root
		local Visual = GaleBurstFX.new(GroundBelow(Root.Position), Impl.Radius, Impl.Pulses * Impl.Every + 0.5):Start(Players:GetPlayers())
		for I = 1, Impl.Pulses do
			if I > 1 then task.wait(Impl.Every) end
			if not Caster.Parent or (Ctx.WC and Ctx.WC:HasStatusEffects({Stun})) then break end
			local Final = I == Impl.Pulses
			pcall(function() Visual:Pulse(Final) end)
			local Center = Root.Position
			for _, Victim in ipairs(VictimsNear(Caster, Center, Impl.Radius)) do
				local VRoot = Victim.HumanoidRootPart
				if Clear(Center, VRoot.Position) then
					local Result = HitWith(Caster, Victim, Ctx.SkillName .. (Final and "Final" or "Pulse"), Center)
					if Final and Result == "Hit" and Victim.Parent then
						local Out = Flat(VRoot.Position - Center)
						MoverManager.CreateMover(Victim, "Velocity", {V = Out * Impl.Push + Vector3.new(0, 10, 0), D = Impl.PushTime, Clear = true})
					end
				end
			end
		end
		return {}
	end,
}

-- Everyone inside a vertical column (a tornado lifts its victims: a sphere around the ground point
-- would lose them as they rise)
local function VictimsInColumn(Caster, Base, Radius, Height)
	local List = {}
	for _, Victim in ipairs(VictimsNear(Caster, Base + Vector3.new(0, Height / 2, 0), math.sqrt(Radius ^ 2 + (Height / 2) ^ 2))) do
		local P = Victim.HumanoidRootPart.Position
		local Flat2 = Vector3.new(P.X - Base.X, 0, P.Z - Base.Z).Magnitude
		if Flat2 <= Radius and P.Y >= Base.Y - 4 and P.Y <= Base.Y + Height then table.insert(List, Victim) end
	end
	return List
end

-- Tempest Break: the circle opens under the caster and the spot is marked (Range, at least MinRange
-- out); a tornado rises there, drags everyone within PullRadius toward its centre (lifting those
-- inside it) and hits everyone within Radius Ticks times; the last hit throws them up and out.
Kinds.Tornado = {
	OnStartup = function(Ctx)
		local Impl, Root = Ctx.Impl, Ctx.Root
		Ctx.Sigil = Sigil.new(Ctx.Character, Impl.SigilRadius or 8, Impl.Element):Start(Players:GetPlayers())
		local Params = RaycastParams.new()
		Params.FilterType = Enum.RaycastFilterType.Exclude
		Params.FilterDescendantsInstances = {workspace.World.Live, workspace.World.Visuals}
		local Chest = Root.Position + Vector3.new(0, 1.5, 0)
		local Ray = workspace:Raycast(Chest, Ctx.Direction * Impl.Range, Params)
		local Point = Ray and Ray.Position or Chest + Ctx.Direction * Impl.Range
		local Out = Vector3.new(Point.X - Root.Position.X, 0, Point.Z - Root.Position.Z)
		if Out.Magnitude < Impl.MinRange then Point = Root.Position + Flat(Ctx.Direction) * Impl.MinRange end
		Ctx.Target = GroundBelow(Point)
		Ctx.Warning = Warning.new(Ctx.Target, Impl.Radius, Ctx.Def.Cast + Impl.Active + Impl.Every):Start(Players:GetPlayers())
	end,
	Strike = function(Ctx)
		local Impl, Caster, Target = Ctx.Impl, Ctx.Character, Ctx.Target
		if Ctx.Sigil then pcall(function() Ctx.Sigil:Destroy() end) Ctx.Sigil = nil end
		if not Target then return {} end
		local Life = Impl.Ticks * Impl.Every + 0.3
		TornadoFX.new(Target, Impl.Radius, Impl.Height, Life):Start(Players:GetPlayers())
		local Above = Target + Vector3.new(0, 3, 0)
		task.spawn(function()
			local Start, Tick = os.clock(), 0
			local NextPull = 0
			while os.clock() - Start < Life do
				if not Caster.Parent then break end
				-- the pull: drag everyone close toward the centre, lift those inside
				if os.clock() >= NextPull then
					NextPull = os.clock() + 0.1
					for _, Victim in ipairs(VictimsInColumn(Caster, Target, Impl.PullRadius, Impl.Height)) do
						local VRoot = Victim.HumanoidRootPart
						local To = Flat(Target - VRoot.Position)
						local Dist = Vector3.new(Target.X - VRoot.Position.X, 0, Target.Z - VRoot.Position.Z).Magnitude
						if Clear(Above, VRoot.Position) and not DownedManager.IsKnocked(Victim) then
							local Lift = Dist <= Impl.Radius and Impl.Lift or 0
							local Pull = Dist > 1.5 and Impl.Pull or 0
							MoverManager.CreateMover(Victim, "Velocity", {V = To * Pull + Vector3.new(0, Lift, 0), D = 0.12, Max = Vector3.new(4e4, 4e4, 4e4)})
						end
					end
				end
				-- the ticks
				if Tick < Impl.Ticks and os.clock() - Start >= (Tick + 1) * Impl.Every - 0.2 then
					Tick += 1
					local Final = Tick == Impl.Ticks
					for _, Victim in ipairs(VictimsInColumn(Caster, Target, Impl.Radius, Impl.Height)) do
						if Clear(Above, Victim.HumanoidRootPart.Position) then
							local Result = HitWith(Caster, Victim, Ctx.SkillName .. (Final and "Final" or "Tick"), Above)
							if Final and Result == "Hit" and Victim.Parent then
								local Out = Flat(Victim.HumanoidRootPart.Position - Target)
								MoverManager.CreateMover(Victim, "Velocity", {V = Out * 30 + Vector3.new(0, 45, 0), D = 0.25, Clear = true, Max = Vector3.new(4e4, 4e4, 4e4)})
							end
						end
					end
				end
				RunService.Heartbeat:Wait()
			end
		end)
		return {}
	end,
	OnInterrupted = function(Ctx)
		if Ctx.Warning then pcall(function() Ctx.Warning:Destroy() end) end
		if Ctx.Sigil then pcall(function() Ctx.Sigil:Destroy() end) end
	end,
}

-- ===== Metal =====
-- Steel Guard: the wall is up from the clap for Window seconds (the clap pose held); it soaks up to
-- Absorb damage from the front, then breaks (and the stance ends early).
Kinds.Shield = {
	OnClap = function(Ctx)
		local Impl, Caster = Ctx.Impl, Ctx.Character
		Ctx.Wall = SteelGuardFX.new(Caster, Impl.Window):Start(Players:GetPlayers())
		ShieldManager.Open(Caster, {
			Duration = Impl.Window, Absorb = Impl.Absorb, Arc = Impl.Arc,
			OnAbsorb = function() pcall(function() Ctx.Wall:Absorb() end) end,
			OnBreak = function()
				Ctx.Triggered = true -- the stance ends with the wall
				pcall(function() Ctx.Wall:Break() end)
			end,
		})
	end,
	OnClapEnd = function(Ctx)
		ShieldManager.Close(Ctx.Character)
		if Ctx.Wall then pcall(function() Ctx.Wall:Lower() end) end
	end,
	Strike = function() return {} end,
	OnInterrupted = function(Ctx)
		ShieldManager.Close(Ctx.Character)
		if Ctx.Wall then pcall(function() Ctx.Wall:Lower() end) end
	end,
}

-- Crushing Anvil: steel races along the ground from the caster; after HomeDelay it homes on the nearest
-- enemy ahead (TurnRate); reaching someone (Contact) or the end of its Range drops an anvil there,
-- hitting everyone within SlamRadius.
Kinds.Tracker = {
	Strike = function(Ctx)
		local Impl, Caster, Root = Ctx.Impl, Ctx.Character, Ctx.Root
		local Dir = Flat(Ctx.Direction)
		local Head = GroundBelow(Root.Position + Dir * 2.5)
		task.spawn(function()
			local Start, Traveled, LastSpike = os.clock(), 0, -10
			local Target, Closest = nil, nil
			while Traveled < Impl.Range and Caster.Parent do
				local Dt = RunService.Heartbeat:Wait()
				if os.clock() - Start >= Impl.HomeDelay then
					-- home on the nearest enemy ahead (re-picked while none is locked)
					if not Target or not Target.Parent or not Target:FindFirstChild("HumanoidRootPart") then
						Target = nil
						local Best = Impl.SeekRange
						for _, V in ipairs(VictimsNear(Caster, Head, Impl.SeekRange)) do
							local To = Flat(V.HumanoidRootPart.Position - Head)
							local D = (V.HumanoidRootPart.Position - Head).Magnitude
							if math.deg(math.acos(math.clamp(To:Dot(Dir), -1, 1))) <= Impl.SeekArc and D < Best then Target, Best = V, D end
						end
					end
					if Target then
						local Want = Flat(Target.HumanoidRootPart.Position - Head)
						local Angle = math.acos(math.clamp(Dir:Dot(Want), -1, 1))
						local Max = math.rad(Impl.TurnRate) * Dt
						if Angle > 1e-3 then
							local Sign = Dir:Cross(Want).Y >= 0 and 1 or -1
							Dir = (CFrame.Angles(0, Sign * math.min(Angle, Max), 0) * Dir).Unit
						end
					end
				end
				local Next = Head + Dir * Impl.Speed * Dt
				if not Clear(Head + Vector3.new(0, 1, 0), Next + Vector3.new(0, 1, 0)) then break end -- a wall stops it
				Head = GroundBelow(Next)
				Traveled += Impl.Speed * Dt
				if Traveled - LastSpike >= 2.2 then
					LastSpike = Traveled
					SteelSpikesFX.new(Head, Dir, "Trail", 2, 2.6, 0.45, 1.6):Start(Players:GetPlayers())
				end
				if Target then
					local Gap = Vector3.new(Target.HumanoidRootPart.Position.X - Head.X, 0, Target.HumanoidRootPart.Position.Z - Head.Z).Magnitude
					-- reached them -- or swung past them close by (a target that sidesteps late)
					if Gap <= Impl.Contact or (Closest and Closest <= 6 and Gap > Closest + 0.5) then break end
					Closest = math.min(Closest or math.huge, Gap)
				end
			end
			if not Caster.Parent then return end
			local Yaw = math.atan2(-Dir.X, -Dir.Z)
			AnvilDropFX.new(Head, Yaw):Start(Players:GetPlayers())
			task.wait(0.14) -- it lands
			local Above = Head + Vector3.new(0, 3, 0)
			for _, Victim in ipairs(VictimsNear(Caster, Head, Impl.SlamRadius + 2)) do
				local P = Victim.HumanoidRootPart.Position
				if Vector3.new(P.X - Head.X, 0, P.Z - Head.Z).Magnitude <= Impl.SlamRadius and Clear(Above, P) then
					HitWith(Caster, Victim, Ctx.SkillName, Above)
				end
			end
		end)
		return {}
	end,
}

-- Metal Bind: a steel lance from the hands to the first enemy in line (Range); a clean hit pins them
-- (stunned and rooted for Pin seconds, spikes closing over them).
Kinds.Thrust = {
	Strike = function(Ctx)
		local Impl, Caster, Root = Ctx.Impl, Ctx.Character, Ctx.Root
		local Dir = Ctx.Direction
		local Facing = CFrame.lookAt(Root.Position, Root.Position + Flat(Dir))
		local From = (Facing * CFrame.new(0.4, 0.7, -1.2)).Position
		local Params = RaycastParams.new()
		Params.FilterType = Enum.RaycastFilterType.Exclude
		Params.FilterDescendantsInstances = {Caster, workspace.World.Visuals}
		local Hit = workspace:Spherecast(From, Impl.Radius, Dir * Impl.Range, Params)
		local End = Hit and (From + Dir * Hit.Distance) or (From + Dir * Impl.Range)
		SteelLanceFX.new(From, End):Start(Players:GetPlayers())
		local Victim = nil
		if Hit and Hit.Instance:IsDescendantOf(workspace.World.Live) then
			Victim = Hit.Instance
			while Victim.Parent ~= workspace.World.Live do Victim = Victim.Parent end
		end
		local Humanoid = Victim and Victim:FindFirstChildOfClass("Humanoid")
		if not Humanoid or Humanoid.Health <= 0 or not Victim:FindFirstChild("HumanoidRootPart") then return {} end
		local Result = HitWith(Caster, Victim, Ctx.SkillName, From)
		if Result == "Hit" and Victim.Parent then
			-- pinned: rooted for the pin (the hit's own stun covers attacking / blocking)
			MoverManager.Movement(Victim, {WS = 0, JH = 0, D = Impl.Pin})
			MoverManager.CreateMover(Victim, "Velocity", {V = Vector3.zero, D = 0.1, Clear = true})
			Victim:SetAttribute("PinnedUntil", workspace:GetServerTimeNow() + Impl.Pin)
			SteelSpikesFX.new(GroundBelow(Victim.HumanoidRootPart.Position), Vector3.zero, "Bind", 6, 4.2, Impl.Pin - 0.2, 2.2):Start(Players:GetPlayers())
		end
		return {{Victim = Victim, Result = Result}}
	end,
}

-- Alloy Divider: a giant blade forms over the caster while the line ahead is marked (the whole cast +
-- CastDelay); then it cleaves down the line: everyone in it takes the hit (true damage, unblockable).
Kinds.Cleave = {
	OnStartup = function(Ctx)
		local Impl, Root = Ctx.Impl, Ctx.Root
		Ctx.Sigil = Sigil.new(Ctx.Character, Impl.SigilRadius or 8, Impl.Element):Start(Players:GetPlayers())
		local Dir = Flat(Ctx.Direction)
		Ctx.LineFrom = GroundBelow(Root.Position + Dir * 1.5)
		Ctx.LineDir = Dir
		local Lead = Ctx.Def.Cast + (Ctx.Def.CastDelay or 0) + Impl.Active
		Ctx.Warning = LineWarningFX.new(Ctx.LineFrom, Dir, Impl.Length, Impl.Width, Lead):Start(Players:GetPlayers())
		Ctx.Blade = AlloyBladeFX.new(GroundBelow(Root.Position), Dir, Impl.Length):Start(Players:GetPlayers())
	end,
	Strike = function(Ctx)
		local Impl, Caster = Ctx.Impl, Ctx.Character
		if Ctx.Sigil then pcall(function() Ctx.Sigil:Destroy() end) Ctx.Sigil = nil end
		if Ctx.Blade then pcall(function() Ctx.Blade:Slam() end) end
		local From, Dir = Ctx.LineFrom, Ctx.LineDir
		if not From then return {} end
		task.wait(0.16) -- the blade comes down
		local Box = CFrame.lookAt(From, From + Dir) * CFrame.new(0, 3, -Impl.Length / 2)
		local Params = OverlapParams.new()
		Params.FilterType = Enum.RaycastFilterType.Include
		Params.FilterDescendantsInstances = {workspace.World.Live}
		local Seen = {}
		for _, Part in ipairs(workspace:GetPartBoundsInBox(Box, Vector3.new(Impl.Width, 8, Impl.Length), Params)) do
			local M = Part
			while M and M.Parent ~= workspace.World.Live do M = M.Parent end
			if M and M ~= Caster and not Seen[M] and M:FindFirstChild("HumanoidRootPart") then
				Seen[M] = true
				local H = M:FindFirstChildOfClass("Humanoid")
				if H and H.Health > 0 then HitWith(Caster, M, Ctx.SkillName, From) end
			end
		end
		return {}
	end,
	OnInterrupted = function(Ctx)
		for _, K in ipairs({"Warning", "Sigil", "Blade"}) do
			if Ctx[K] then pcall(function() Ctx[K]:Destroy() end) end
		end
	end,
}

-- ===== Earth =====
-- A spot on the ground along the aim, between MinRange and Range (Rising Thorn): under the first
-- character the aim crosses, else where it meets the ground, else at Range.
local function AimedSpot(Ctx, Range, MinRange)
	local Root = Ctx.Root
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = {Ctx.Character, workspace.World.Visuals}
	local Chest = Root.Position + Vector3.new(0, 1.5, 0)
	local Ray = workspace:Raycast(Chest, Ctx.Direction * Range, Params)
	local Point = Ray and Ray.Position or Chest + Ctx.Direction * Range
	local Out = Vector3.new(Point.X - Root.Position.X, 0, Point.Z - Root.Position.Z)
	if Out.Magnitude < MinRange then Point = Root.Position + Flat(Ctx.Direction) * MinRange end
	return GroundBelow(Point)
end

local function Pop(Victim, V, D)
	if Victim.Parent and not DownedManager.IsKnocked(Victim) then
		MoverManager.CreateMover(Victim, "Velocity", {V = V, D = D or 0.18, Clear = true, Max = Vector3.new(4e4, 4e4, 4e4)})
	end
end

-- Rising Thorn: the circle marks the aimed spot for the windup; a spike bursts from the ground there,
-- hitting everyone over it: a short knock-up and a bleed.
Kinds.Thorn = {
	OnStartup = function(Ctx)
		local Impl = Ctx.Impl
		Ctx.Target = AimedSpot(Ctx, Impl.Range, Impl.MinRange)
		if Ctx.Target then
			Ctx.Warning = Warning.new(Ctx.Target, Impl.Radius, Ctx.Def.Cast + Impl.Active):Start(Players:GetPlayers())
		end
	end,
	Strike = function(Ctx)
		local Impl, Caster, Target = Ctx.Impl, Ctx.Character, Ctx.Target
		if not Target then return {} end
		local Lean = Flat(Target - Ctx.Root.Position)
		EarthSpikesFX.new(Target, Lean, "Thorn", 1, Impl.Height, Impl.Life, Impl.Radius):Start(Players:GetPlayers())
		local Above = Target + Vector3.new(0, 3, 0)
		local Results = {}
		for _, Victim in ipairs(VictimsInColumn(Caster, Target, Impl.Radius, Impl.Height)) do
			if Clear(Above, Victim.HumanoidRootPart.Position) then
				local Result = HitWith(Caster, Victim, Ctx.SkillName, Above)
				ApplyOnHit(Caster, Victim, Impl, Result)
				if Result == "Hit" then Pop(Victim, Vector3.new(0, Impl.Lift, 0) + Lean * 6) end
				table.insert(Results, {Victim = Victim, Result = Result})
			end
		end
		return Results
	end,
	OnInterrupted = function(Ctx)
		if Ctx.Warning then pcall(function() Ctx.Warning:Destroy() end) end
	end,
}

-- Tectonic Shift: a ring of spikes erupts around the caster -- everyone inside is hit, stunned and
-- shoved out to the ring.
Kinds.Ring = {
	Strike = function(Ctx)
		local Impl, Caster, Root = Ctx.Impl, Ctx.Character, Ctx.Root
		local Center = GroundBelow(Root.Position) or Root.Position - Vector3.new(0, 3, 0)
		EarthSpikesFX.new(Center, Flat(Ctx.Direction), "Ring", Impl.Count, Impl.Height, Impl.Life, Impl.Radius):Start(Players:GetPlayers())
		local From = Root.Position
		local Results = {}
		for _, Victim in ipairs(VictimsNear(Caster, From, Impl.Radius)) do
			local VRoot = Victim.HumanoidRootPart
			if Clear(From, VRoot.Position) then
				local Result = HitWith(Caster, Victim, Ctx.SkillName, From)
				if Result == "Hit" then Pop(Victim, Flat(VRoot.Position - From) * Impl.Push + Vector3.new(0, 12, 0), 0.2) end
				table.insert(Results, {Victim = Victim, Result = Result})
			end
		end
		return Results
	end,
}

-- Earth Wall: a wall of rock rises Distance ahead, across the aim: a solid, climbable collider in
-- World.Map (so it blocks movement, projectiles and line of sight) for Life seconds; anyone standing
-- where it rises is thrown up (and hit). One wall per caster -- a new one crumbles the old.
local Walls = {} -- [Caster] = {Collider, FX}
local function DropWall(Caster)
	local W = Walls[Caster]
	Walls[Caster] = nil
	if not W then return end
	if W.Collider then W.Collider:Destroy() end
	if W.FX then pcall(function() W.FX:Crumble() end) end
end
Players.PlayerRemoving:Connect(function(P) if P.Character then DropWall(P.Character) end end)

Kinds.Wall = {
	Strike = function(Ctx)
		local Impl, Caster, Root = Ctx.Impl, Ctx.Character, Ctx.Root
		local Dir = Flat(Ctx.Direction)
		local Base = GroundBelow(Root.Position + Dir * Impl.Distance)
		if not Base then return {} end
		DropWall(Caster)
		local CF = CFrame.lookAt(Base, Base + Dir)
		local FX = EarthWallFX.new(CF, Impl.Width, Impl.Height, Impl.Thickness, Impl.Life):Start(Players:GetPlayers())
		-- whoever stands on the spot is thrown up
		local Params = OverlapParams.new()
		Params.FilterType = Enum.RaycastFilterType.Include
		Params.FilterDescendantsInstances = {workspace.World.Live}
		local Seen, Results = {}, {}
		for _, Part in ipairs(workspace:GetPartBoundsInBox(CF * CFrame.new(0, Impl.Height / 2, 0), Vector3.new(Impl.Width + 1, Impl.Height, Impl.Thickness + 2.5), Params)) do
			local M = Part
			while M and M.Parent ~= workspace.World.Live do M = M.Parent end
			if M and M ~= Caster and not Seen[M] and M:FindFirstChild("HumanoidRootPart") then
				Seen[M] = true
				local H = M:FindFirstChildOfClass("Humanoid")
				if H and H.Health > 0 then
					local Result = HitWith(Caster, M, Ctx.SkillName .. "Lift", Base)
					Pop(M, Vector3.new(0, Impl.Lift, 0) + Dir * 8, 0.22)
					table.insert(Results, {Victim = M, Result = Result})
				end
			end
		end
		local Entry = {FX = FX}
		Walls[Caster] = Entry
		task.delay(0.15, function()
			if Walls[Caster] ~= Entry then return end
			local Collider = Instance.new("Part")
			Collider.Name = "EarthWall"
			Collider.Anchored, Collider.CanCollide, Collider.CanQuery, Collider.CanTouch = true, true, true, false
			Collider.Transparency = 1
			Collider.Size = Vector3.new(Impl.Width, Impl.Height, Impl.Thickness)
			Collider.CFrame = CF * CFrame.new(0, Impl.Height / 2, 0)
			Collider:SetAttribute("Caster", Caster.Name)
			Collider.Parent = workspace.World.Map
			Entry.Collider = Collider
		end)
		task.delay(Impl.Life + 0.2, function()
			if Walls[Caster] == Entry then
				Walls[Caster] = nil
				if Entry.Collider then Entry.Collider:Destroy() end
			end
		end)
		Caster.Destroying:Once(function() if Walls[Caster] == Entry then DropWall(Caster) end end)
		return Results
	end,
}

-- Earth Pillars: the line ahead is marked for the whole cast; then Waves of pillars race along it
-- (each crossing the line in Travel seconds, Every apart). Each wave hits everyone in the line once and
-- pops them up; the last wave throws them. UNBLOCKABLE (the sheet class), telegraphed by the line.
Kinds.Fault = {
	OnStartup = function(Ctx)
		local Impl, Root = Ctx.Impl, Ctx.Root
		Ctx.Sigil = Sigil.new(Ctx.Character, Impl.SigilRadius or 8, Impl.Element):Start(Players:GetPlayers())
		local Dir = Flat(Ctx.Direction)
		Ctx.LineFrom = GroundBelow(Root.Position + Dir * 1.5) or (Root.Position - Vector3.new(0, 3, 0))
		Ctx.LineDir = Dir
		Ctx.Warning = LineWarningFX.new(Ctx.LineFrom, Dir, Impl.Length, Impl.Width, Ctx.Def.Cast + Impl.Active):Start(Players:GetPlayers())
	end,
	Strike = function(Ctx)
		local Impl, Caster = Ctx.Impl, Ctx.Character
		if Ctx.Sigil then pcall(function() Ctx.Sigil:Destroy() end) Ctx.Sigil = nil end
		local From, Dir = Ctx.LineFrom, Ctx.LineDir
		if not From then return {} end
		EarthPillarsFX.new(From, Dir, Impl.Length, Impl.Width, Impl.Waves, Impl.Every, Impl.Travel):Start(Players:GetPlayers())
		local Right = Dir:Cross(Vector3.yAxis).Unit
		local Box = CFrame.lookAt(From, From + Dir) * CFrame.new(0, 6, -Impl.Length / 2)
		local Params = OverlapParams.new()
		Params.FilterType = Enum.RaycastFilterType.Include
		Params.FilterDescendantsInstances = {workspace.World.Live}
		for W = 1, Impl.Waves do
			task.delay((W - 1) * Impl.Every, function()
				local Final = W == Impl.Waves
				local Skill = Ctx.SkillName .. (Final and "Final" or "Wave")
				local Seen = {}
				local Start = os.clock()
				while Caster.Parent do
					local Elapsed = os.clock() - Start
					local Reach = math.min(1, Elapsed / Impl.Travel) * Impl.Length
					for _, Part in ipairs(workspace:GetPartBoundsInBox(Box, Vector3.new(Impl.Width, 16, Impl.Length), Params)) do
						local M = Part
						while M and M.Parent ~= workspace.World.Live do M = M.Parent end
						if M and M ~= Caster and not Seen[M] and M:FindFirstChild("HumanoidRootPart") then
							local Rel = M.HumanoidRootPart.Position - From
							local Along = Rel:Dot(Dir)
							local H = M:FindFirstChildOfClass("Humanoid")
							if Along <= Reach + 1 and math.abs(Rel:Dot(Right)) <= Impl.Width / 2 + 1 and H and H.Health > 0 then
								Seen[M] = true
								local Result = HitWith(Caster, M, Skill, From + Dir * math.max(0, Along - 4) + Vector3.new(0, 3, 0))
								if Result == "Hit" then
									Pop(M, Final and (Vector3.new(0, 48, 0) + Dir * 22) or Vector3.new(0, 22, 0), Final and 0.25 or 0.14)
								end
							end
						end
					end
					if Elapsed >= Impl.Travel then break end
					RunService.Heartbeat:Wait()
				end
			end)
		end
		return {}
	end,
	OnInterrupted = function(Ctx)
		for _, K in ipairs({"Warning", "Sigil"}) do
			if Ctx[K] then pcall(function() Ctx[K]:Destroy() end) end
		end
	end,
}

-- ===== Cast =====
local Casts = {} -- [Character] = {Slot, Released, Aim} while a cast is running (cleared after)

-- The cast key was let go: the held clap moves on (and the aim updates to where you look now).
function AlchemyService.Release(Player, Slot, Aim)
	local State = Player.Character and Casts[Player.Character]
	if not State or State.Slot ~= Slot then return end
	State.Released = true
	if typeof(Aim) == "Vector3" then State.Aim = Aim end
end

-- Waits D seconds (or until the key is released, with UntilReleased), keeping the cast walk speed;
-- false once the cast is interrupted.
local function CastWait(D, Alive, Slow, State, UntilReleased)
	local Start, NextSlow = os.clock(), 0
	while true do
		if not Alive() then return false end
		if (UntilReleased and State.Released) or os.clock() - Start >= D then return true end
		if os.clock() >= NextSlow then
			Slow(0.3)
			NextSlow = os.clock() + 0.2
		end
		RunService.Heartbeat:Wait()
	end
end

-- The cast itself, shared by players (Cast) and NPC alchemists (CastAs): cooldown, meter, the clap -> slam ->
-- move prelude, the move's kind, hitboxes and damage rules. Player = nil for an NPC (no puzzle reactions,
-- no messages). AutoRelease (NPCs): let go of the clap after that many seconds (0 = a tap).
local function RunCast(Player, Character, Root, WC, Affinity, Slot, Def, Impl, Aim, AutoRelease)
	local Now = workspace:GetServerTimeNow()
	local Prefix = "Alchemy" .. Slot
	if (Character:GetAttribute(Prefix .. "ReadyAt") or 0) > Now then return end -- the cooldown plate shows it
	local Cost = Cfg.MeterCost[Slot] or 0
	-- Puzzle casts (PROPOSAL, 2026-10-15): out of combat, a cast next to a mechanism that reacts to this
	-- element costs no meter -- the meter only fills in fights, and no puzzle should need one first.
	-- optional: the Tutorial place runs this file without PuzzleService (Tutorial sync 2026-10-20)
	local PuzzleModule = game:GetService("ServerScriptService"):FindFirstChild("PuzzleService")
	local Puzzles = PuzzleModule and require(PuzzleModule) or nil
	if Player and Puzzles and not Character:GetAttribute("InCombat") and Puzzles.ReactsNear(Affinity, Root.Position) then Cost = 0 end
	local MeterBefore = ResourceManager.Get(Character, "Meter")
	if not ResourceManager.Spend(Character, "Meter", Cost) then
		-- Blood Price (keystone): out of meter, pay the rest in health
		local Blood = SkillMods.Get(Character, "BloodCast")
		local Humanoid = Character:FindFirstChildOfClass("Humanoid")
		local HealthCost = (Cost - MeterBefore) * Blood
		if Blood > 0 and Humanoid and Humanoid.Health > HealthCost + 1 then
			ResourceManager.Set(Character, "Meter", 0)
			Humanoid.Health -= HealthCost
		else
			if Player then Tell(Player, ("Not enough Transmutation Meter: %s needs %d."):format(Def.Name, Cost)) end
			return
		end
	end
	local Cooldown = Def.Cooldown * SkillMods.Mult(Character, Slot .. "Cooldown")
	Character:SetAttribute(Prefix .. "ReadyAt", Now + Cooldown)
	Character:SetAttribute(Prefix .. "Cooldown", Cooldown)
	Character:SetAttribute(Prefix .. "Name", Def.Name)
	-- skill-tree damage for this cast (DamageManager reads CastMult on the cast's alchemy hits):
	-- <Slot> Potency, Overflow (80+ meter when cast); Charged Clap adds below when the clap is held
	local CastMult = SkillMods.Mult(Character, Slot .. "Damage")
		+ (MeterBefore >= 80 and SkillMods.Get(Character, "OverflowDamage") or 0)
	local CastId = (Character:GetAttribute("CastId") or 0) + 1
	Character:SetAttribute("CastId", CastId)
	Character:SetAttribute("CastMult", CastMult)
	-- Equivalent Exchange (keystone): the first landed hit refunds part of the meter
	local Refund = Cost * SkillMods.Get(Character, "MeterRefund")
	Character:SetAttribute("CastRefund", Refund > 0 and Refund or nil)

	local State = {Slot = Slot, Released = false, Aim = Aim}
	Casts[Character] = State
	-- an NPC lets go of the clap by itself: at once, or after AutoRelease seconds
	if AutoRelease then
		if AutoRelease <= 0 then State.Released = true else task.delay(AutoRelease, function() State.Released = true end) end
	end
	local T = Cfg.Transmute
	local NoRelease = Impl.Release == "None" -- the move happens on the clap itself (Cryo Shift)
	local Release = T.Releases[Impl.Release or "GroundSlam"] or T.Releases.GroundSlam
	local Speed = (T.Speed or 1) * SkillMods.Mult(Character, "ClapSpeed") -- Quick Clap
	local Direction = AimDirection(Root, Aim)
	local SkillName = "Alchemy_" .. Def.Id
	-- the windup = the sheet's Cast (+ its CastDelay where it has one: Alloy Divider)
	local Windup = (Def.Cast + (Def.CastDelay or 0)) * SkillMods.Mult(Character, "Windup") -- Swift Array
		* (Character:GetAttribute("TruthClap") or 1) -- the Truth clap: faster once the caster has passed a Gate trial (Rensei.Truth)
	-- Steady Array: walk at full speed while casting
	local CastWalk = SkillMods.Get(Character, "CastWalkSpeed") > 0
		and game:GetService("StarterPlayer").StarterCharacter.Humanoid.WalkSpeed * (Character:GetAttribute("SpeedMultiplier") or 1) -- the base walk
		or Cfg.CastWalkSpeed
	local Attack = {
		Startup = Windup, Active = Impl.Active, Recovery = Impl.Recovery,
		Anim = Impl.Anim, Fallback = Impl.Fallback,
		-- the animation's release lands exactly at the end of the windup
		AnimSpeed = Impl.AnimPeak and Windup > 0 and Impl.AnimPeak / Windup or nil,
		NoWhiffPenalty = true,
	}
	local Visual = nil
	local Action3 = Enum.AnimationPriority.Action3
	local Kind = Kinds[Impl.Kind or "Projectile"] or Kinds.Projectile
	local Ctx = {Character = Character, Root = Root, WC = WC, Impl = Impl, Def = Def, SkillName = SkillName, Direction = Direction}
	local Outcome = AttackRunner.Run(WC, Attack, SkillName, {
		WalkSpeed = CastWalk,
		PreludeMax = T.ClapHit / Speed + T.MaxHold + Release.Hit / Speed + 0.5,
		-- clap -> (hold) -> slam
		Prelude = function(_, Alive, Slow)
			AnimationManager.Play(Character, T.Clap, {Priority = Action3, Speed = Speed})
			if not CastWait(T.ClapHit / Speed, Alive, Slow, State) then return false end
			Visual = Transmute.new(Character, Impl.Element):Start(Players:GetPlayers()) -- the hands catch fire
			if NoRelease then
				-- the move is up from the clap: hold the clap pose for its window (or until it triggers)
				if Kind.OnClap then Kind.OnClap(Ctx) end
				AnimationManager.Play(Character, T.Hold, {Priority = Action3, Looped = true})
				local Start = os.clock()
				local Ok = true
				while os.clock() - Start < (Impl.Window or 1) and not Ctx.Triggered do
					if not Alive() and not Ctx.Triggered then Ok = false break end
					Slow(0.3)
					RunService.Heartbeat:Wait()
				end
				AnimationManager.Stop(Character, T.Hold)
				AnimationManager.Stop(Character, T.Clap)
				if Kind.OnClapEnd then Kind.OnClapEnd(Ctx) end
				pcall(function() Visual:Slam(nil) end)
				return Ok
			end
			if not State.Released then
				AnimationManager.Play(Character, T.Hold, {Priority = Action3, Looped = true})
				local HoldStart = os.clock()
				local Held = CastWait(T.MaxHold, Alive, Slow, State, true)
				AnimationManager.Stop(Character, T.Hold)
				if not Held then return false end
				-- Charged Clap: held 1s+ -> the move hits harder
				if os.clock() - HoldStart >= 1 and Character:GetAttribute("CastId") == CastId then
					Character:SetAttribute("CastMult", CastMult + SkillMods.Get(Character, "HeldClapDamage"))
				end
			end
			AnimationManager.Stop(Character, T.Clap)
			AnimationManager.Play(Character, Release.Anim, {Priority = Action3, Speed = Speed})
			if not CastWait(Release.Hit / Speed, Alive, Slow, State) then return false end
			if Release == T.Releases.GroundSlam then
				local Look = Root.CFrame.LookVector
				pcall(function()
					Visual:Slam(Root.Position + Vector3.new(Look.X, 0, Look.Z) * 1.5 - Vector3.new(0, 2.9, 0))
				end)
			else
				pcall(function() Visual:Slam(nil) end) -- arm extend: the hand circle bursts, no ground flash
			end
			AnimationManager.Stop(Character, Release.Anim) -- the move's animation takes over
			return true
		end,
		OnStartup = function()
			-- the move's windup: face where the caster aimed when they let go of the key
			Direction = AimDirection(Root, State.Aim)
			Ctx.Direction = Direction
			local FlatDir = Vector3.new(Direction.X, 0, Direction.Z)
			if FlatDir.Magnitude > 1e-3 then
				MoverManager.CreateMover(Character, "LookAt", {C = CFrame.lookAt(Vector3.zero, FlatDir.Unit), D = Windup})
			end
			if Kind.OnStartup then Kind.OnStartup(Ctx) end
		end,
		OnActive = function()
			if Visual then pcall(function() Visual:Destroy() end) Visual = nil end -- the fire leaves the hands
			if Kind.OnActive then Kind.OnActive(Ctx) end
			-- environmental reactions (PuzzleService): any move of this element, in front of the caster
			if Player and Puzzles then pcall(Puzzles.React, Player, Affinity, Root.Position, Ctx.Direction) end
		end,
		-- moves without their own Strike (the lunge) use the attack's server hitbox sweep
		Strike = Kind.Strike and function()
			local Results = Kind.Strike(Ctx)
			return type(Results) == "table" and Results or {}
		end or nil,
	})
	Casts[Character] = nil
	if Outcome == "Interrupted" then
		-- cast broken: drop the clap / hold / slam and put the hands out
		for _, Name in ipairs({T.Clap, T.Hold, Release.Anim}) do AnimationManager.Stop(Character, Name) end
		if Kind.OnInterrupted then Kind.OnInterrupted(Ctx) end
	end
	if Visual then pcall(function() Visual:Destroy() end) end
	-- the cast's skill-tree damage lasts a moment past the cast (projectiles, waves, ticks)
	task.delay(4, function()
		if Character.Parent and Character:GetAttribute("CastId") == CastId then
			Character:SetAttribute("CastMult", nil)
			Character:SetAttribute("CastRefund", nil)
		end
	end)
	return Outcome
end

function AlchemyService.Cast(Player, Slot, Aim)
	if not Slots[Slot] then return end
	local Character = Player.Character
	if not Character or Character:GetAttribute("CombatMode") ~= true or Casts[Character] then return end
	local Root = Character:FindFirstChild("HumanoidRootPart")
	local WC = WCS.Character.GetCharacterFromInstance(Character)
	if not Root or not CanAct(Character, WC) then return end

	local Affinity = AlchemyService.AffinityOf(Player)
	if not Affinity then
		Tell(Player, "You have no alchemy affinity yet.")
		return
	end
	local Def = AbilityFor(Affinity, Slot)
	local Impl = Def and Cfg.Abilities[Def.Id]
	if not Impl then
		Tell(Player, Def and (Def.Name .. " isn't available yet.") or ("No " .. Affinity .. " alchemy on " .. Slot .. " yet."))
		return
	end
	local Allowed, Why = Clans.CanUseAbility(ClanOf(Player), Def)
	if not Allowed then
		Tell(Player, Why)
		return
	end
	-- the Mastery skill tree: Z comes with every path; X, C and V are bought (Move nodes)
	if Slot ~= "Z" and SkillMods.Get(Character, "Unlock" .. Slot) < 1 then
		Tell(Player, ("Unlock %s in the Mastery tree (K)."):format(Def.Name))
		return
	end

	local Outcome = RunCast(Player, Character, Root, WC, Affinity, Slot, Def, Impl, Aim, nil)
	-- Player Identities: players who could see the cast note the technique (IdentityService.Witness)
	if Outcome then
		task.spawn(function() pcall(function() require(ServerScriptService.IdentityService).Witness(Player, Affinity) end) end)
		-- Plan 2 (2026-10-20): a cast is loud (NoiseService), and unlicensed casting in front of the Authority is a
		-- crime (HeatService). Both optional, like PuzzleService, so the Tutorial runs this file without them.
		local SSS = game:GetService("ServerScriptService")
		local Noise, Heat = SSS:FindFirstChild("NoiseService"), SSS:FindFirstChild("HeatService")
		if Noise then task.spawn(pcall, function() require(Noise).Emit(Root.Position, "Cast", Character) end) end
		if Heat then task.spawn(pcall, function() require(Heat).OnCast(Player) end) end
	end
	return Outcome
end

-- NPC alchemists (EnemyService, 2026-10-17): the SAME cast a player makes -- Transmutation Meter (earned by
-- fighting, like a player's), the slot's cooldown, the clap / slam telegraph, the move's hitboxes and the
-- block / parry / dodge rules -- for a non-player character with the given affinity. Players are refused
-- (they always go through Cast and its checks). NPCs have no clan and no Mastery tree, so those two player
-- rules don't apply; which slots an NPC uses is its TuningConfig.Enemies entry's Alchemy.Slots.
-- Aim: a direction (like the player's camera look). Opts.HoldFor: hold the clap before releasing (default 0).
function AlchemyService.CastAs(Character, Affinity, Slot, Aim, Opts)
	if not Slots[Slot] or type(Affinity) ~= "string" or not Character then return end
	if Players:GetPlayerFromCharacter(Character) then return end
	if Character:GetAttribute("CombatMode") ~= true or Casts[Character] then return end
	local Root = Character:FindFirstChild("HumanoidRootPart")
	local WC = WCS.Character.GetCharacterFromInstance(Character)
	if not Root or not WC or not CanAct(Character, WC) then return end
	local Def = AbilityFor(Affinity, Slot)
	local Impl = Def and Cfg.Abilities[Def.Id]
	if not Impl then return end
	return RunCast(nil, Character, Root, WC, Affinity, Slot, Def, Impl, Aim, (Opts and Opts.HoldFor) or 0)
end

-- What an NPC can cast right now (the same checks CastAs makes up front), for its brain.
function AlchemyService.CanCastAs(Character, Affinity, Slot)
	local Def = AbilityFor(Affinity, Slot)
	if not Def or not Cfg.Abilities[Def.Id] or Casts[Character] then return false end
	-- free to act too (not mid-swing, stunned, blocking...), or a reflex would pass here and CastAs refuse
	local WC = WCS.Character.GetCharacterFromInstance(Character)
	if not WC or not CanAct(Character, WC) then return false end
	if (Character:GetAttribute("Alchemy" .. Slot .. "ReadyAt") or 0) > workspace:GetServerTimeNow() then return false end
	return ResourceManager.Get(Character, "Meter") >= (Cfg.MeterCost[Slot] or 0), Def
end

return AlchemyService

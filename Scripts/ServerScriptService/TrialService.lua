-- TrialService: the alchemy trials (Rensei.Trials). A trial is a fight in an arena: a part tagged
-- "RenseiTrial" with attribute TrialId marks the arena's centre and carries the "Begin Trial" prompt.
-- * PER-PLAYER RUNS, one at a time per arena: the run belongs to the player who started it. Their foe
--   (a TuningConfig.Enemies trial type, spawned through EnemyService.Spawn) carries TrialOwner.
-- * The foe's "alchemy" is the arena's hazards, run here: telegraphed rings / lines / gusts (the
--   telegraph is always visible before anything hurts), then damage through DownedManager.Damage and
--   statuses through StatusManager. Hazards hurt the owner AND the foe (lure it into its own fire).
-- * OPENINGS: after every hazard wave the foe drops its guard for Opening.For seconds (attribute
--   GuardDown: no blocks or parries) and its armour cracks (DamageTakenMult). The run tells the
--   player once what the opening looks like.
-- * WIN: the foe dies or is knocked -> flag Trial_<Id> (StoryService.SetFlag: quests advance, and
--   the result survives a rejoin) + QuestService.Signal("Trial", Id). Only the owner is credited.
-- * FAIL (recoverable, retry at the arena): the owner is knocked or dies, leaves the arena, runs out
--   of time, or leaves the game. After two failures the player gets the trial's Hint.
-- Begin(Player, TrialId) re-checks everything: the definition's Requires (StoryLogic), distance, not
-- already won, not in another run, the arena free.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local Defs = require(ReplicatedStorage.Modules.Data.Rensei.Trials)
local StoryLogic = require(ReplicatedStorage.Modules.Data.Rensei.StoryLogic)
local ProgressionService = require(ServerScriptService.ProgressionService)
local UIService = require(ServerScriptService.UIService)

local TAG = "RenseiTrial"
local START_RANGE = 14 -- studs from the arena marker to start a run
local OUTSIDE_GRACE = 6 -- seconds a player may spend outside the arena (knocked out of it) before failing
local WATCH = 0.4 -- seconds between end-condition checks

local TrialService = {}
TrialService.Runs = {} -- [ArenaPart] = Run
local ByPlayer = {} -- [Player] = Run
local Failures = {} -- [Player] = {[TrialId] = n} (this session; drives the hint)
local Arenas = {} -- [TrialId] = arena part

local function Root(Character) return Character and Character:FindFirstChild("HumanoidRootPart") end
local function Humanoid(Character) return Character and Character:FindFirstChildOfClass("Humanoid") end
local function Toast(Player, Text) UIService.Notify(Player, "Toast", {Text = Text}) end

local function Mods()
	local Managers = ReplicatedStorage.Modules.Managers
	return require(Managers.DownedManager), require(Managers.StatusManager)
end

-- ===== telegraph visuals =====
local COLORS = {
	Flame = Color3.fromRGB(255, 110, 40), Ice = Color3.fromRGB(150, 220, 255), Earth = Color3.fromRGB(170, 130, 90),
	Wind = Color3.fromRGB(210, 240, 230), Metal = Color3.fromRGB(200, 205, 215),
}

local function Part(Run, Props)
	local P = Instance.new("Part")
	P.Anchored, P.CanCollide, P.CanQuery, P.CanTouch, P.CastShadow = true, false, false, false, false
	P.Material = Enum.Material.Neon
	for K, V in pairs(Props) do P[K] = V end
	P.Parent = Run.Folder
	return P
end

-- a flat ring on the ground that fills in over Warn seconds
local function RingTelegraph(Run, Position, Radius, Warn, Color)
	local Ground = Position - Vector3.new(0, Position.Y - Run.FloorY, 0)
	local Rim = Part(Run, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, Radius * 2, Radius * 2), Color = Color,
		Transparency = 0.45, CFrame = CFrame.new(Ground + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))})
	local Fill = Part(Run, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 0.5, 0.5), Color = Color,
		Transparency = 0.25, CFrame = Rim.CFrame})
	game:GetService("TweenService"):Create(Fill, TweenInfo.new(Warn, Enum.EasingStyle.Linear), {Size = Vector3.new(0.2, Radius * 2, Radius * 2)}):Play()
	Debris:AddItem(Rim, Warn + 0.1)
	Debris:AddItem(Fill, Warn + 0.1)
	return Ground
end

-- a marked strip (Metal's cleave lines, Wind's gust lanes)
local function LineTelegraph(Run, From, Dir, Length, Width, Warn, Color)
	local Mid = From + Dir * (Length / 2)
	Mid = Vector3.new(Mid.X, Run.FloorY + 0.1, Mid.Z)
	local CF = CFrame.lookAt(Mid, Mid + Vector3.new(Dir.X, 0, Dir.Z))
	local Strip = Part(Run, {Size = Vector3.new(Width, 0.15, Length), Color = Color, Transparency = 0.5, CFrame = CF})
	Debris:AddItem(Strip, Warn + 0.1)
	return CF
end

local function InsideCircle(Character, Centre, Radius)
	local R = Root(Character)
	if not R then return false end
	local D = Vector3.new(R.Position.X - Centre.X, 0, R.Position.Z - Centre.Z)
	return D.Magnitude <= Radius and math.abs(R.Position.Y - Centre.Y) < 8
end

local function InsideStrip(Character, CF, Length, Width)
	local R = Root(Character)
	if not R then return false end
	local L = CF:PointToObjectSpace(R.Position)
	return math.abs(L.X) <= Width / 2 and math.abs(L.Z) <= Length / 2 and math.abs(L.Y) < 8
end

-- everyone a hazard can hurt in this run: the owner and their foe
local function Victims(Run)
	local List = {}
	if Run.Player.Character then table.insert(List, Run.Player.Character) end
	if Run.Foe and Run.Foe.Parent then table.insert(List, Run.Foe) end
	return List
end

local function Hurt(Run, Character, H)
	local DownedManager, StatusManager = Mods()
	local Damage = H.Damage or 0
	if Character == Run.Foe then
		if (H.FoeMult or 1) <= 0 then return end -- immune to its own hazard
		Damage *= (H.FoeMult or 1)
	end
	if Damage > 0 then DownedManager.Damage(Character, Damage) end
	if H.Status then StatusManager.Apply(Character, H.Status, {Duration = H.StatusTime}) end
end

-- ===== hazard kinds (one per discipline) =====
local Hazards = {}

-- Flame: bursts of fire at and around the owner, then burning ground that keeps hurting
function Hazards.Flame(Run, H)
	local Owner = Root(Run.Player.Character)
	if not Owner then return end
	local Spots = {}
	for I = 1, H.Count do
		local Off = I == 1 and Vector3.zero or Vector3.new(Run.Rng:NextNumber(-1, 1), 0, Run.Rng:NextNumber(-1, 1)).Unit * Run.Rng:NextNumber(5, 11)
		table.insert(Spots, RingTelegraph(Run, Run:Clamp(Owner.Position + Off), H.Radius, H.Warn, COLORS.Flame))
	end
	task.wait(H.Warn)
	if not Run.Active then return end
	for _, Spot in ipairs(Spots) do
		local Fire = Part(Run, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, H.Radius * 2, H.Radius * 2), Color = Color3.fromRGB(255, 80, 20),
			Transparency = 0.35, CFrame = CFrame.new(Spot + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))})
		local Flames = Instance.new("Fire") Flames.Size = H.Radius * 1.4 Flames.Heat = 6 Flames.Parent = Fire
		Debris:AddItem(Fire, H.Linger or 0.4)
		for _, C in ipairs(Victims(Run)) do if InsideCircle(C, Spot, H.Radius) then Hurt(Run, C, H) end end
	end
	-- the ground keeps burning: standing in it hurts every second
	local Until = os.clock() + (H.Linger or 0)
	while Run.Active and os.clock() < Until do
		task.wait(1)
		for _, Spot in ipairs(Spots) do
			for _, C in ipairs(Victims(Run)) do
				if InsideCircle(C, Spot, H.Radius) then Hurt(Run, C, {Damage = H.LingerDamage, FoeMult = H.FoeMult}) end
			end
		end
	end
end

-- Ice: frost patches that freeze whoever is still standing in them, and slow the ground after
function Hazards.Ice(Run, H)
	local Owner = Root(Run.Player.Character)
	if not Owner then return end
	local Spots = {}
	for I = 1, H.Count do
		local Off = I == 1 and Vector3.zero or Vector3.new(Run.Rng:NextNumber(-1, 1), 0, Run.Rng:NextNumber(-1, 1)).Unit * Run.Rng:NextNumber(6, 12)
		table.insert(Spots, RingTelegraph(Run, Run:Clamp(Owner.Position + Off), H.Radius, H.Warn, COLORS.Ice))
	end
	task.wait(H.Warn)
	if not Run.Active then return end
	for _, Spot in ipairs(Spots) do
		local Frost = Part(Run, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, H.Radius * 2, H.Radius * 2), Color = COLORS.Ice,
			Material = Enum.Material.Ice, Transparency = 0.2, CFrame = CFrame.new(Spot + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))})
		Debris:AddItem(Frost, (H.Linger or 0) + 0.3)
		for _, C in ipairs(Victims(Run)) do if InsideCircle(C, Spot, H.Radius) then Hurt(Run, C, H) end end
	end
	-- frost stays slick: a slow while you stand in it (the client walks the character, so the server
	-- slows it through the humanoid)
	local Until = os.clock() + (H.Linger or 0)
	while Run.Active and os.clock() < Until do
		task.wait(0.5)
		local Char = Run.Player.Character
		local Hum = Humanoid(Char)
		if Hum then
			local Inside = false
			for _, Spot in ipairs(Spots) do if InsideCircle(Char, Spot, H.Radius) then Inside = true end end
			if Inside and not Char:GetAttribute("TrialSlowed") then
				Char:SetAttribute("TrialSlowed", Hum.WalkSpeed)
				Hum.WalkSpeed = Hum.WalkSpeed * (H.Slow or 0.5)
			elseif not Inside and Char:GetAttribute("TrialSlowed") then
				Hum.WalkSpeed = Char:GetAttribute("TrialSlowed")
				Char:SetAttribute("TrialSlowed", nil)
			end
		end
	end
	Run:Unslow()
end

-- Earth: rockfall where the owner stands (and two more), then a tremor ring around the foe
function Hazards.Earth(Run, H)
	local Owner = Root(Run.Player.Character)
	if not Owner then return end
	local Spots = {}
	for I = 1, H.Count do
		local Off = I == 1 and Vector3.zero or Vector3.new(Run.Rng:NextNumber(-1, 1), 0, Run.Rng:NextNumber(-1, 1)).Unit * Run.Rng:NextNumber(5, 12)
		table.insert(Spots, RingTelegraph(Run, Run:Clamp(Owner.Position + Off), H.Radius, H.Warn, COLORS.Earth))
	end
	task.wait(H.Warn)
	if not Run.Active then return end
	for _, Spot in ipairs(Spots) do
		local Rock = Part(Run, {Shape = Enum.PartType.Ball, Size = Vector3.one * H.Radius * 1.2, Color = Color3.fromRGB(105, 95, 85),
			Material = Enum.Material.Slate, Transparency = 0, CFrame = CFrame.new(Spot + Vector3.new(0, H.Radius * 0.4, 0))})
		Debris:AddItem(Rock, 1.2)
		for _, C in ipairs(Victims(Run)) do if InsideCircle(C, Spot, H.Radius) then Hurt(Run, C, H) end end
	end
	-- the tremor: a band around the foe that hits whoever is IN the band (close to it or far away is safe)
	if H.Tremor and Run.Foe and Root(Run.Foe) then
		local Centre = Root(Run.Foe).Position
		local Inner, Outer = H.Tremor.Inner, H.Tremor.Outer
		RingTelegraph(Run, Centre, Outer, H.Tremor.Warn, COLORS.Earth)
		local Hole = Part(Run, {Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, Inner * 2, Inner * 2), Color = Color3.fromRGB(40, 35, 30),
			Transparency = 0.2, CFrame = CFrame.new(Centre.X, Run.FloorY + 0.12, Centre.Z) * CFrame.Angles(0, 0, math.rad(90))})
		Debris:AddItem(Hole, H.Tremor.Warn + 0.1)
		task.wait(H.Tremor.Warn)
		if not Run.Active then return end
		local Char = Run.Player.Character
		if InsideCircle(Char, Centre, Outer) and not InsideCircle(Char, Centre, Inner) then Hurt(Run, Char, H.Tremor) end
	end
end

-- Wind: gust lanes across the arena; a lane shoves whoever is in it sideways and hurts them
function Hazards.Wind(Run, H)
	local Owner = Root(Run.Player.Character)
	if not Owner then return end
	local Lanes = {}
	for I = 1, H.Count do
		local Angle = Run.Rng:NextNumber(0, math.pi * 2)
		local Dir = Vector3.new(math.cos(Angle), 0, math.sin(Angle))
		local Through = I == 1 and Owner.Position or Run:Clamp(Owner.Position + Vector3.new(Run.Rng:NextNumber(-10, 10), 0, Run.Rng:NextNumber(-10, 10)))
		local From = Through - Dir * (H.Length / 2)
		local CF = LineTelegraph(Run, From, Dir, H.Length, H.Width, H.Warn, COLORS.Wind)
		table.insert(Lanes, {CF = CF, Dir = Dir})
	end
	task.wait(H.Warn)
	if not Run.Active then return end
	for _, Lane in ipairs(Lanes) do
		local Streak = Part(Run, {Size = Vector3.new(H.Width, 3, H.Length), Color = COLORS.Wind, Transparency = 0.75, CFrame = Lane.CF + Vector3.new(0, 1.5, 0)})
		Debris:AddItem(Streak, 0.35)
		for _, C in ipairs(Victims(Run)) do
			if InsideStrip(C, Lane.CF, H.Length, H.Width) then
				Hurt(Run, C, H)
				local R = Root(C)
				if R then
					-- the gust: a brief push along the lane (a server-made constraint replicates to the
					-- client that simulates the character)
					local Att = Instance.new("Attachment") Att.Parent = R
					local V = Instance.new("LinearVelocity")
					V.Attachment0 = Att
					V.MaxForce = 6e4
					V.VectorVelocity = Lane.Dir * (H.Push or 45) + Vector3.new(0, 12, 0)
					V.Parent = R
					Debris:AddItem(V, 0.25)
					Debris:AddItem(Att, 0.3)
				end
			end
		end
	end
end

-- Metal: cleave lines from the foe toward the owner (the Alloy Divider telegraph, smaller)
function Hazards.Metal(Run, H)
	local Owner = Root(Run.Player.Character)
	local FoeRoot = Run.Foe and Root(Run.Foe)
	if not Owner or not FoeRoot then return end
	local Lines = {}
	for I = 1, H.Count do
		local ToOwner = Vector3.new(Owner.Position.X - FoeRoot.Position.X, 0, Owner.Position.Z - FoeRoot.Position.Z)
		if ToOwner.Magnitude < 1 then ToOwner = Vector3.new(0, 0, 1) end
		local Spread = (I - (H.Count + 1) / 2) * math.rad(H.Spread or 25)
		local Dir = (CFrame.Angles(0, Spread, 0) * CFrame.new(Vector3.zero, ToOwner.Unit)).LookVector
		local CF = LineTelegraph(Run, FoeRoot.Position, Dir, H.Length, H.Width, H.Warn, COLORS.Metal)
		table.insert(Lines, CF)
	end
	task.wait(H.Warn)
	if not Run.Active then return end
	for _, CF in ipairs(Lines) do
		local Blade = Part(Run, {Size = Vector3.new(H.Width * 0.5, 4, H.Length), Color = COLORS.Metal, Material = Enum.Material.Metal,
			Transparency = 0.1, CFrame = CF + Vector3.new(0, 2, 0)})
		Debris:AddItem(Blade, 0.4)
		local C = Run.Player.Character
		if InsideStrip(C, CF, H.Length, H.Width) then Hurt(Run, C, H) end
	end
end

-- ===== the run =====
local Run = {}
Run.__index = Run

function Run:Clamp(Position)
	local C = self.Centre
	local D = Vector3.new(Position.X - C.X, 0, Position.Z - C.Z)
	local Max = self.Def.Radius - 4
	if D.Magnitude > Max then D = D.Unit * Max end
	return Vector3.new(C.X + D.X, self.FloorY, C.Z + D.Z)
end

function Run:Unslow()
	local Char = self.Player.Character
	local Hum = Humanoid(Char)
	if Char and Hum and Char:GetAttribute("TrialSlowed") then
		Hum.WalkSpeed = Char:GetAttribute("TrialSlowed")
		Char:SetAttribute("TrialSlowed", nil)
	end
end

function Run:SetGuard(Open)
	local Foe = self.Foe
	if not Foe or not Foe.Parent then return end
	local O = self.Def.Opening or {}
	Foe:SetAttribute("GuardDown", Open or nil)
	Foe:SetAttribute("DamageTakenMult", Open and (O.DamageMult or 1.25) or (O.GuardedMult or 1))
	if self.Highlight then
		self.Highlight.FillColor = Open and Color3.fromRGB(255, 70, 50) or (O.ShellColor or Color3.fromRGB(255, 255, 255))
		self.Highlight.FillTransparency = Open and 0.55 or (O.ShellColor and 0.65 or 1)
		self.Highlight.OutlineTransparency = Open and 0 or (O.ShellColor and 0.4 or 1)
	end
end

function Run:End(Won, Why)
	if not self.Active then return end
	self.Active = false
	local Player, Def = self.Player, self.Def
	TrialService.Runs[self.Arena] = nil
	if ByPlayer[Player] == self then ByPlayer[Player] = nil end
	for _, C in ipairs(self.Conns) do C:Disconnect() end
	self:Unslow()
	if self.Foe and self.Foe.Parent then
		self.Foe:SetAttribute("GuardDown", nil)
		local Foe = self.Foe
		-- a knocked foe can still be gripped for a few seconds; then the arena is cleared
		task.delay(Won and 8 or 0, function() if Foe.Parent then Foe:Destroy() end end)
	end
	if self.SpawnPart then self.SpawnPart:Destroy() end
	task.delay(1.5, function() if self.Folder then self.Folder:Destroy() end end)
	if Won then
		require(ServerScriptService.StoryService).SetFlag(Player, "Trial_" .. Def.Id, os.time())
		require(ServerScriptService.QuestService).Signal(Player, "Trial", Def.Id)
		UIService.Notify(Player, "Banner", {Text = "Trial Passed - [" .. Def.Title .. "]"})
		if Def.WinText then Toast(Player, Def.WinText) end
	elseif Player.Parent then
		local F = Failures[Player] or {}
		Failures[Player] = F
		F[Def.Id] = (F[Def.Id] or 0) + 1
		Toast(Player, (Why or "The trial is over.") .. " Try again at the arena.")
		if F[Def.Id] >= 2 and Def.Hint then
			task.delay(2.5, function() if Player.Parent then Toast(Player, Def.Hint) end end)
		end
	end
end

-- the end conditions, checked every WATCH seconds by Run:Watch (true = the run has ended)
function Run:Check()
	local Def = self.Def
	local Char = self.Player.Character
	local R = Root(Char)
	local Hum = Humanoid(Char)
	if not self.Player.Parent then self:End(false) return true end
	if not Hum or Hum.Health <= 0 or (Char and Char:GetAttribute("Knocked")) then self:End(false, Def.FailText or "You were brought down.") return true end
	-- outside the arena (a knockback can throw you out): a warning, and a fail only after OUTSIDE_GRACE s
	if not R or (Vector3.new(R.Position.X - self.Centre.X, 0, R.Position.Z - self.Centre.Z)).Magnitude > Def.Radius * 1.35 then
		if not self.OutsideSince then
			self.OutsideSince = os.clock()
			Toast(self.Player, "Get back into the arena!")
		elseif os.clock() - self.OutsideSince > OUTSIDE_GRACE then
			self:End(false, "You left the arena.") return true
		end
	else
		self.OutsideSince = nil
	end
	if os.clock() - self.Started > (Def.TimeLimit or 240) then self:End(false, "Too slow: the trial is over.") return true end
	local Foe = self.Foe
	local FH = Humanoid(Foe)
	if not Foe or not Foe.Parent or not FH or FH.Health <= 0 or Foe:GetAttribute("Knocked") then self:End(true) return true end
	return false
end

function Run:Watch()
	while self.Active do
		task.wait(WATCH)
		if self.Active and self:Check() then return end
	end
end

-- the hazard waves, each followed by the foe's opening; ends when the run does
function Run:Loop()
	local Def = self.Def
	local H = Def.Hazard
	local Shown = false
	task.wait(Def.FirstHazard or 3)
	while self.Active do
		local Ok, Err = pcall(Hazards[H.Kind], self, H)
		if not Ok then warn("TrialService hazard failed:", Err) end
		if not self.Active then return end
		if Def.Opening then
			self:SetGuard(true)
			if not Shown and Def.Opening.Text then Shown = true Toast(self.Player, Def.Opening.Text) end
			local Until = os.clock() + Def.Opening.For
			while self.Active and os.clock() < Until do task.wait(0.25) end
			self:SetGuard(false)
		end
		-- the gap before the next wave (the foe still fights)
		local Until = os.clock() + Run.RandomBetween(self.Rng, H.Every)
		while self.Active and os.clock() < Until do task.wait(0.25) end
	end
end

function Run.RandomBetween(Rng, Pair)
	if type(Pair) == "number" then return Pair end
	return Rng:NextNumber(Pair[1], Pair[2])
end

-- ===== start =====
function TrialService.CanStart(Player, TrialId)
	local Def = Defs[TrialId]
	local Arena = Arenas[TrialId]
	if not Def or not Arena then return false, "This trial isn't ready." end
	local Data = ProgressionService.GetData(Player)
	if not Data then return false, "Your data isn't loaded yet." end
	if (Data.Story.Flags or {})["Trial_" .. TrialId] then return false, "You've already passed this trial." end
	if not StoryLogic.Meets(Def.Requires, Data, Player) then return false, Def.Locked or "You aren't ready for this trial." end
	if ByPlayer[Player] then return false, "You're already in a trial." end
	if TrialService.Runs[Arena] then return false, "Someone else is facing this trial. Wait for them to finish." end
	local R = Root(Player.Character)
	if not R or (R.Position - Arena.Position).Magnitude > START_RANGE + 4 then return false, "Stand at the arena to begin." end
	local Char = Player.Character
	if Char:GetAttribute("Knocked") or Char:GetAttribute("InCombat") then return false, "Catch your breath first." end
	return true
end

function TrialService.Begin(Player, TrialId)
	local Ok, Why = TrialService.CanStart(Player, TrialId)
	if not Ok then Toast(Player, Why) return false, Why end
	local Def = Defs[TrialId]
	local Arena = Arenas[TrialId]
	local Folder = Instance.new("Folder")
	Folder.Name = "Trial_" .. TrialId .. "_" .. Player.UserId
	Folder.Parent = workspace.World.Visuals
	local Self = setmetatable({
		Player = Player, Def = Def, Arena = Arena, Folder = Folder, Active = true, Conns = {},
		Centre = Arena.Position, FloorY = Arena.Position.Y - Arena.Size.Y / 2, Rng = Random.new(),
	}, Run)
	TrialService.Runs[Arena] = Self
	ByPlayer[Player] = Self

	-- the foe, through the normal enemy pipeline
	local SpawnPart = Instance.new("Part")
	SpawnPart.Name = "TrialSpawn_" .. TrialId
	SpawnPart.Anchored, SpawnPart.CanCollide, SpawnPart.CanQuery, SpawnPart.CanTouch, SpawnPart.Transparency = true, false, false, false, 1
	SpawnPart.Size = Vector3.new(2, 1, 2)
	local At = Self.Centre + (Arena.CFrame.LookVector * (Def.FoeDistance or 14))
	SpawnPart.CFrame = CFrame.lookAt(Vector3.new(At.X, Self.FloorY + 0.5, At.Z), Vector3.new(Self.Centre.X, Self.FloorY + 0.5, Self.Centre.Z))
	SpawnPart:SetAttribute("EnemyType", Def.Foe)
	SpawnPart:SetAttribute("RespawnTime", 1e9)
	if Def.Nation then SpawnPart:SetAttribute("Nation", Def.Nation) end
	if Def.Weapon ~= nil then SpawnPart:SetAttribute("Weapon", Def.Weapon) end
	SpawnPart.Parent = Folder
	Self.SpawnPart = SpawnPart
	local Foe = require(ServerScriptService.EnemyService).Spawn(SpawnPart)
	if not Foe then
		Self:End(false, "The trial couldn't start.")
		return false
	end
	Self.Foe = Foe
	Foe:SetAttribute("TrialOwner", Player.UserId)
	Foe:SetAttribute("QuestTarget", "Trial_" .. TrialId)
	local HL = Instance.new("Highlight")
	HL.DepthMode = Enum.HighlightDepthMode.Occluded
	HL.FillTransparency, HL.OutlineTransparency = 1, 1
	HL.Parent = Foe
	Self.Highlight = HL
	Self:SetGuard(false)

	table.insert(Self.Conns, Players.PlayerRemoving:Connect(function(P) if P == Player then Self:End(false) end end))
	UIService.Notify(Player, "Banner", {Text = "Trial - [" .. Def.Title .. "]"})
	if Def.Intro then Toast(Player, Def.Intro) end
	Self.Started = os.clock()
	task.spawn(function()
		local Ok2, Err = pcall(Run.Watch, Self)
		if not Ok2 then warn("TrialService watch failed:", Err) Self:End(false, "The trial was interrupted.") end
	end)
	task.spawn(function()
		local Ok2, Err = pcall(Run.Loop, Self)
		if not Ok2 then warn("TrialService run failed:", Err) Self:End(false, "The trial was interrupted.") end
	end)
	return true
end

-- ===== arenas =====
local function Attach(Arena)
	if not Arena:IsA("BasePart") or not Arena:IsDescendantOf(workspace) then return end
	local Id = Arena:GetAttribute("TrialId")
	local Def = Id and Defs[Id]
	if not Def then warn("TrialService: arena", Arena:GetFullName(), "has unknown TrialId", Id) return end
	Def.Id = Id
	Arenas[Id] = Arena
	local Prompt = Instance.new("ProximityPrompt")
	Prompt.Name = "TrialPrompt"
	Prompt.ActionText = "Begin Trial"
	Prompt.ObjectText = Def.Title
	Prompt.HoldDuration = 0.6
	Prompt.MaxActivationDistance = START_RANGE
	Prompt.RequiresLineOfSight = false
	Prompt.Style = Enum.ProximityPromptStyle.Custom -- drawn by Modules.UI.PromptUI
	Prompt.Parent = Arena
	Prompt.Triggered:Connect(function(Player) TrialService.Begin(Player, Id) end)
end

function TrialService.InRun(Player)
	return ByPlayer[Player] ~= nil
end

function TrialService.Start()
	for Id, Def in pairs(Defs) do Def.Id = Id end
	for _, A in ipairs(CollectionService:GetTagged(TAG)) do Attach(A) end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(A) task.defer(Attach, A) end)
	Players.PlayerRemoving:Connect(function(P) Failures[P] = nil end)
end

return TrialService

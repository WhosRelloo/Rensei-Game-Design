-- ProgressionService: the only writer of stats, EXP, Mastery Points and Truth/Gate state.
-- Every client request lands here and is re-validated; the client UI is a courtesy only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Rensei = ReplicatedStorage.Modules.Data.Rensei
local Stats = require(Rensei.Stats)
local Progression = require(Rensei.Progression)
local Formulas = require(Rensei.Formulas)

local DataManager = require(ServerScriptService.CharacterHandler.DataManager)
local UIService = require(ServerScriptService.UIService)

local Training = Progression.Training

local ProgressionService = {}

-- [Player] = {LastPos = Vector3, LastMoved = number, Targets = {[Model] = {Hits, Since}}}
local Session = {}

local function GetData(Player)
	local Profile = DataManager:GetProfile(Player)
	return Profile and Profile.Data
end
ProgressionService.GetData = GetData

local function Sync(Player)
	local Profile = DataManager:GetProfile(Player)
	if Profile then
		-- Public, read-only mirrors other clients need (leaderboard).
		Player:SetAttribute("Level", Profile.Data.Level)
		DataManager:SendData(Player)
	end
end
ProgressionService.Sync = Sync

local function SessionOf(Player)
	local S = Session[Player]
	if not S then
		-- Targets is a plain table pruned in TargetMultiplier (a weak-keyed table can drop a live
		-- Instance key, which would reset the same-target diminishing returns)
		S = {LastPos = nil, LastMoved = os.clock(), Targets = {}}
		Session[Player] = S
	end
	return S
end

-- ===== Stats =====

-- Allocation = {[StatName] = PointsToAdd}. Returns ok, reason.
function ProgressionService.AllocateStats(Player, Allocation)
	local Data = GetData(Player)
	if not Data then return false, "Profile not loaded" end
	if type(Allocation) ~= "table" then return false, "Malformed request" end

	local Total, Count = 0, 0
	for Name, Amount in pairs(Allocation) do
		Count += 1
		if Count > #Stats.Order then return false, "Malformed request" end
		if not Stats.IsStat(Name) then return false, "Unknown stat" end
		if type(Amount) ~= "number" or Amount ~= Amount or Amount % 1 ~= 0 or Amount < 1 then
			return false, "Malformed request"
		end
		if Data.Stats[Name] + Amount > Stats.Cap then return false, Name .. " is capped" end
		Total += Amount
	end
	if Total == 0 then return false, "Nothing to allocate" end
	if Total > Data.StatPoints then return false, "Not enough points" end

	for Name, Amount in pairs(Allocation) do
		Data.Stats[Name] += Amount
	end
	Data.StatPoints -= Total
	ProgressionService.ApplyCharacter(Player)
	Sync(Player)
	return true
end

-- ===== EXP =====

function ProgressionService.GrantExp(Player, Amount, Source)
	local Data = GetData(Player)
	if not Data or type(Amount) ~= "number" or Amount <= 0 then return 0 end
	Amount = math.floor(Amount)
	Data.LifetimeExp += Amount

	local Levels = 0
	local OldHealth = Formulas.MaxHealth(Data.Level, Data.Stats)
	if Data.Level < Progression.MaxLevel then
		Data.Exp += Amount
		while Data.Level < Progression.MaxLevel and Data.Exp >= Progression.ExpToNext(Data.Level) do
			Data.Exp -= Progression.ExpToNext(Data.Level)
			Data.Level += 1
			Data.StatPoints += Progression.StatPointsPerLevel
			Levels += 1
		end
		if Data.Level >= Progression.MaxLevel then Data.Exp = 0 end
	end
	if Levels > 0 then
		ProgressionService.ApplyCharacter(Player)
		UIService.Notify(Player, "LevelUp", {
			Level = Data.Level,
			StatPoints = Levels * Progression.StatPointsPerLevel,
			Health = Formulas.MaxHealth(Data.Level, Data.Stats) - OldHealth,
		})
	end
	Sync(Player)
	return Levels
end

-- ===== Money =====

function ProgressionService.GrantMoney(Player, Amount)
	local Data = GetData(Player)
	if not Data or type(Amount) ~= "number" or Amount ~= Amount or Amount <= 0 then return false end
	Data.Money += math.floor(Amount)
	Sync(Player)
	return true
end

function ProgressionService.SpendMoney(Player, Amount)
	local Data = GetData(Player)
	if not Data or type(Amount) ~= "number" or Amount ~= Amount or Amount <= 0 then return false end
	Amount = math.floor(Amount)
	if Data.Money < Amount then return false end
	Data.Money -= Amount
	Sync(Player)
	return true
end

-- ===== Transmutation Meter =====
-- Alchemy's resource (controls doc): filled by fighting only, spent by alchemy abilities.
-- Lives in ResourceManager ("Meter"); this is the server entry point abilities should use.
local ResourceManager = require(ReplicatedStorage.Modules.Managers.ResourceManager)

function ProgressionService.SpendMeter(Player, Amount)
	local Character = Player.Character
	if not Character or type(Amount) ~= "number" or Amount < 0 then return false end
	return ResourceManager.Spend(Character, "Meter", Amount)
end

-- ===== Mastery training =====

local function IsIdle(Player)
	local S = SessionOf(Player)
	return os.clock() - S.LastMoved > Training.IdleSeconds
end

-- Pays training progress (TP) from a named source after idle, window and stage checks.
-- Returns the TP actually credited.
function ProgressionService.AddTraining(Player, Source, Multiplier)
	local Data = GetData(Player)
	local Rule = Training.Sources[Source]
	if not Data or not Rule then return 0 end
	if IsIdle(Player) then return 0 end

	local Mastery = Data.Mastery
	if Mastery.StageEarned >= Progression.MasteryPerStage then
		return 0 -- stage full: the only way forward is spending and the trial
	end

	local Now = os.time()
	local Window = Mastery.Windows[Source]
	if not Window or Now - Window.Start >= Training.WindowSeconds then
		Window = {Start = Now, Amount = 0}
		Mastery.Windows[Source] = Window
	end

	local Amount = Rule.Base * (Multiplier or 1)
	if Window.Amount >= Rule.WindowAllowance then
		Amount *= Rule.OverflowRate
	end
	Window.Amount += Amount
	Mastery.Progress += Amount

	local Gained = 0
	while Mastery.Progress >= Training.PointsPerMastery and Mastery.StageEarned < Progression.MasteryPerStage do
		Mastery.Progress -= Training.PointsPerMastery
		Mastery.StageEarned += 1
		Mastery.Unspent += 1
		Mastery.LifetimeEarned += 1
		Gained += 1
	end
	if Mastery.StageEarned >= Progression.MasteryPerStage then
		Mastery.Progress = 0
	end
	if Gained > 0 then Sync(Player) end
	return Amount
end

-- Only real opponents train you. Dummies (infinite health) and NPCs without a finite health
-- pool pay nothing; the same opponent pays less after Training.SameTarget.FreeHits.
local function TargetMultiplier(Player, Victim)
	local Humanoid = Victim and Victim:FindFirstChildOfClass("Humanoid")
	if not Humanoid or Humanoid.MaxHealth == math.huge or Humanoid.MaxHealth > 1e7 then
		return 0
	end
	local Rule = Training.SameTarget
	local S = SessionOf(Player)
	local Now = os.clock()
	for Target, R in pairs(S.Targets) do
		if Now - R.Since > Rule.ResetSeconds or not Target.Parent then S.Targets[Target] = nil end
	end
	local Record = S.Targets[Victim]
	if not Record or Now - Record.Since > Rule.ResetSeconds then
		Record = {Hits = 0, Since = Now}
		S.Targets[Victim] = Record
	end
	Record.Hits += 1
	return Record.Hits > Rule.FreeHits and Rule.Rate or 1
end

-- Called by the combat pipeline with the resolved outcome of every hit.
ProgressionService.HitListeners = {}

function ProgressionService.RecordHit(Attacker, Victim, Result)
	local AttackerPlayer = Players:GetPlayerFromCharacter(Attacker)
	local VictimPlayer = Players:GetPlayerFromCharacter(Victim)
	for _, Listener in ipairs(ProgressionService.HitListeners) do
		task.spawn(Listener, Attacker, Victim, Result)
	end

	if AttackerPlayer and Result == "Hit" then
		local Mult = TargetMultiplier(AttackerPlayer, Victim)
		if Mult > 0 then
			ProgressionService.AddTraining(AttackerPlayer, "CombatHit", Mult)
		end
	end
	if VictimPlayer and (Result == "Parried" or Result == "PerfectParried") then
		local Mult = TargetMultiplier(VictimPlayer, Attacker)
		if Mult > 0 then
			ProgressionService.AddTraining(VictimPlayer, "Parry", Mult)
		end
	end
end

-- Spending is called by the skill tree when it exists. Returns ok, reason.
function ProgressionService.SpendMastery(Player, Cost)
	local Data = GetData(Player)
	if not Data then return false, "Profile not loaded" end
	if type(Cost) ~= "number" or Cost % 1 ~= 0 or Cost < 1 then return false, "Malformed cost" end
	if Data.Mastery.Unspent < Cost then return false, "Not enough Mastery Points" end
	Data.Mastery.Unspent -= Cost
	Data.Mastery.Spent += Cost
	Sync(Player)
	return true
end

-- ===== Truth/Gate =====

function ProgressionService.GateStatus(Player)
	local Data = GetData(Player)
	if not Data then return false, {"Profile not loaded"} end
	return Progression.GateCheck(Data)
end

-- The player asks to undergo the trial. Validated here; the trial itself is not built yet.
function ProgressionService.BeginTrial(Player)
	local Data = GetData(Player)
	local Eligible, Reasons = ProgressionService.GateStatus(Player)
	if not Eligible then return false, Reasons end
	Data.Gate.PendingTrial = Data.Mastery.Stage
	Sync(Player)
	return true
end

-- SERVER ONLY. Called by the trial encounter when it resolves. Passing opens the next stage
-- with a fresh 20 MP allowance. Failure consequences are UNRESOLVED, so failing only clears
-- the pending flag.
function ProgressionService.CompleteTrial(Player, Passed)
	local Data = GetData(Player)
	if not Data or Data.Gate.PendingTrial ~= Data.Mastery.Stage or Data.Gate.PendingTrial == 0 then
		return false
	end
	table.insert(Data.Gate.History, {Stage = Data.Mastery.Stage, Passed = Passed == true, At = os.time()})
	Data.Gate.PendingTrial = 0
	if Passed == true then
		Data.Gate.TrialsPassed += 1
		Data.Mastery.Stage += 1
		Data.Mastery.StageEarned = 0
		Data.Mastery.Progress = 0
	end
	Sync(Player)
	return true
end

-- ===== Character =====

function ProgressionService.ApplyCharacter(Player)
	local Data = GetData(Player)
	local Character = Player.Character
	local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
	if not Data or not Humanoid then return end
	if not Formulas.Live then return end
	local Derived = Formulas.Derived(Data.Level, Data.Stats)
	-- Server-written caches of Formulas output. Combat and movement read these; they are never
	-- computed anywhere else.
	Character:SetAttribute("PhysicalMultiplier", Derived.Physical)
	Character:SetAttribute("AlchemyMultiplier", Derived.Alchemy)
	local OldSpeed = Character:GetAttribute("SpeedMultiplier") or 1
	-- SpeedMultiplier (read by every walk-speed writer) = the Speed stat x the held weapon's
	-- weight (WeaponSpeedMultiplier, set by WeaponManager while a heavy weapon is drawn).
	Character:SetAttribute("StatSpeedMultiplier", Derived.Speed)
	local NewSpeed = Derived.Speed * (Character:GetAttribute("WeaponSpeedMultiplier") or 1)
	Character:SetAttribute("SpeedMultiplier", NewSpeed)
	local Ratio = Humanoid.MaxHealth > 0 and Humanoid.Health / Humanoid.MaxHealth or 1
	-- the skill tree's Toughness / Vigor (Modules.Data.Rensei.SkillTree) -- as in Ye (Tutorial sync 2026-10-20)
	local SkillTree = require(Rensei.SkillTree)
	local MaxHealth = Derived.MaxHealth * (1 + (SkillTree.Modifiers(Data).MaxHealth or 0))
	Humanoid.MaxHealth = MaxHealth
	Humanoid.Health = MaxHealth * math.clamp(Ratio, 0, 1)
	-- every other skill-tree effect: Mod_<Key> attributes + resource maxima (the player's Ye unlocks, e.g. X)
	require(ServerScriptService.SkillTreeService).Publish(Player)
	-- Rescale whatever speed is current (walking, sprinting, slowed) rather than forcing walk.
	Humanoid.WalkSpeed = Humanoid.WalkSpeed / OldSpeed * NewSpeed
end

function ProgressionService.Start()
	Players.PlayerRemoving:Connect(function(Player)
		Session[Player] = nil
	end)

	-- Idle tracking: sampled, not per-frame.
	task.spawn(function()
		while true do
			task.wait(5)
			for _, Player in ipairs(Players:GetPlayers()) do
				local Root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
				if Root then
					local S = SessionOf(Player)
					if not S.LastPos or (Root.Position - S.LastPos).Magnitude >= Training.IdleDistance then
						S.LastPos = Root.Position
						S.LastMoved = os.clock()
					end
				end
			end
		end
	end)
	ServerScriptService:SetAttribute("ProgressionServiceStarted", os.time())
end

return ProgressionService

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
		-- rank, title, clan (RankService; the leaderboard reads these)
		require(ServerScriptService.RankService).Publish(Player)
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

-- (data-storage audit 2026-10-18: a NaN or infinite amount is refused -- one in the save stops it from saving)
local function Finite(N) return type(N) == "number" and N == N and N ~= math.huge and N ~= -math.huge end

function ProgressionService.GrantExp(Player, Amount, Source)
	local Data = GetData(Player)
	if not Data or not Finite(Amount) or Amount <= 0 then return 0 end
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
	if not Data or not Finite(Amount) or Amount <= 0 then return false end
	Data.Money += math.floor(Amount)
	Sync(Player)
	return true
end

function ProgressionService.SpendMoney(Player, Amount)
	local Data = GetData(Player)
	if not Data or not Finite(Amount) or Amount <= 0 then return false end
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
-- Active = true: the caller saw the player doing something the whole time (a trainer's drill or lesson),
-- so the idle check is skipped. The stage cap and the per-source allowance still apply.
function ProgressionService.AddTraining(Player, Source, Multiplier, Active)
	local Data = GetData(Player)
	local Rule = Training.Sources[Source]
	if not Data or not Rule then return 0 end
	if Multiplier ~= nil and (not Finite(Multiplier) or Multiplier < 0) then return 0 end
	if not Active and IsIdle(Player) then return 0 end

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
	-- townsfolk train nothing (Region Foundation Task 6b: hurting them pays no reward of any kind)
	if Victim:GetAttribute("TownsfolkId") then return 0 end
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

-- Spending / refunds are called by SkillTreeService. Returns ok, reason.
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

-- A skill-tree refund (only of this stage's purchases; SkillTreeService checks which).
function ProgressionService.RefundMastery(Player, Cost)
	local Data = GetData(Player)
	if not Data then return false, "Profile not loaded" end
	if type(Cost) ~= "number" or Cost % 1 ~= 0 or Cost < 1 then return false, "Malformed cost" end
	if (Data.Mastery.Spent or 0) < Cost then return false, "Nothing to refund" end
	Data.Mastery.Spent -= Cost
	Data.Mastery.Unspent += Cost
	Sync(Player)
	return true
end

-- ===== Truth/Gate =====

function ProgressionService.GateStatus(Player)
	local Data = GetData(Player)
	if not Data then return false, {"Profile not loaded"} end
	return Progression.GateCheck(Data)
end

-- The trial is opened (TruthService summons the player into the Gate). Validated here.
function ProgressionService.BeginTrial(Player)
	local Data = GetData(Player)
	local Eligible, Reasons = ProgressionService.GateStatus(Player)
	if not Eligible then return false, Reasons end
	Data.Gate.PendingTrial = Data.Mastery.Stage
	Sync(Player)
	return true
end

-- SERVER ONLY. Called by the trial encounter (TruthService) when it resolves. Passing opens the next
-- stage with a fresh 20 MP allowance. The Gate's own rule (design doc §6): failing a test does not
-- cancel progression, it makes the Acquisition Flawed, so TruthService always passes Passed = true and
-- describes the result in Acquisition = {Test, Quality, Corrupted}. Applied exactly once: the pending
-- stage must match, and it is cleared here.
function ProgressionService.CompleteTrial(Player, Passed, Acquisition)
	local Data = GetData(Player)
	if not Data or Data.Gate.PendingTrial ~= Data.Mastery.Stage or Data.Gate.PendingTrial == 0 then
		return false
	end
	table.insert(Data.Gate.History, {Stage = Data.Mastery.Stage, Passed = Passed == true, At = os.time()})
	Data.Gate.PendingTrial = 0
	Data.Gate.ActiveTest = {}
	if Passed == true and type(Acquisition) == "table" then
		Data.Gate.Acquisitions = Data.Gate.Acquisitions or {}
		table.insert(Data.Gate.Acquisitions, {Stage = Data.Mastery.Stage, Test = tostring(Acquisition.Test or ""),
			Quality = Acquisition.Quality == "Clean" and "Clean" or "Flawed", Corrupted = Acquisition.Corrupted == true, At = os.time()})
		if Acquisition.Corrupted == true then Data.Gate.Corruption = (Data.Gate.Corruption or 0) + 1 end
	end
	if Passed == true then
		Data.Gate.TrialsPassed += 1
		Data.Mastery.Stage += 1
		Data.Mastery.StageEarned = 0
		Data.Mastery.Progress = 0
		Data.Mastery.StageSpend = {} -- the stage's skill-tree choices are sealed for good
	end
	ProgressionService.ApplyCharacter(Player) -- the Truth clap (below)
	Sync(Player)
	return true
end

-- SERVER ONLY (TruthService): the test in progress, saved as it happens so a rejoin can't undo a choice.
function ProgressionService.SetGateTest(Player, Fields)
	local Data = GetData(Player)
	if not Data or Data.Gate.PendingTrial == 0 then return false end
	Data.Gate.ActiveTest = Data.Gate.ActiveTest or {}
	for K, V in pairs(Fields) do Data.Gate.ActiveTest[K] = V end
	return true
end

-- SERVER ONLY (TruthService): a death inside the Gate (counted; Permadeath below then erases the character).
function ProgressionService.NoteGateDeath(Player)
	local Data = GetData(Player)
	if not Data then return end
	Data.Gate.GateDeaths = (Data.Gate.GateDeaths or 0) + 1
end

-- SERVER ONLY (TruthService): death inside the Gate is permanent (owner 2026-10-19). Erases the character in this
-- save slot by resetting the profile to the template, in place (the same ProfileService profile, saved as usual):
-- the slot goes back to character creation. Kept: SchemaVersion, Settings, the tutorial / intro flags (the player
-- has seen them), the clan-roll counters that track purchases and pity, and Fallen (+ this character's memorial).
-- Returns the memorial record, or nil if there was no profile or no created character.
local KEEP = {SchemaVersion = true, Settings = true, Flow = true, Fallen = true}
local KEEP_IDENTITY = {"FreeClanRollUsed", "PaidClanRolls", "ClanPity", "MythicBonus"}
local function Copy(T)
	if type(T) ~= "table" then return T end
	local N = {}
	for K, V in pairs(T) do N[K] = Copy(V) end
	return N
end
function ProgressionService.Permadeath(Player, Cause)
	local Data = GetData(Player)
	if not Data or not Data.Identity or not Data.Identity.CharacterCreated then return nil end
	local Template = require(ReplicatedStorage.Modules.Data.ProfileData)
	local Id = Data.Identity
	local Memorial = {Name = Id.Name, Clan = Id.Clan, Affinity = Id.Affinity, Stage = Data.Mastery.Stage,
		TrialsPassed = Data.Gate.TrialsPassed, LifetimeExp = Data.LifetimeExp, At = os.time(), Cause = tostring(Cause or "Gate")}
	local Kept = {}
	for _, K in ipairs(KEEP_IDENTITY) do Kept[K] = Id[K] end
	for K in pairs(Data) do
		if not KEEP[K] then Data[K] = nil end
	end
	for K, V in pairs(Template) do
		if not KEEP[K] then Data[K] = Copy(V) end
	end
	for K, V in pairs(Kept) do Data.Identity[K] = V end
	Data.Fallen = type(Data.Fallen) == "table" and Data.Fallen or {}
	table.insert(Data.Fallen, Memorial)
	while #Data.Fallen > 20 do table.remove(Data.Fallen, 1) end
	Data.Flow = type(Data.Flow) == "table" and Data.Flow or {}
	Data.Flow.TutorialDone, Data.Flow.IntroSeen = true, true -- a new character skips straight past them
	pcall(function() require(ServerScriptService.AlchemyService).PublishAffinity(Player) end)
	Sync(Player)
	return Memorial
end

-- The clap of someone who has seen the Gate: the best Acquisition's windup multiplier (Rensei.Truth.ClapWindup).
function ProgressionService.TruthClap(Data)
	local Best = nil
	for _, A in ipairs((Data and Data.Gate and Data.Gate.Acquisitions) or {}) do
		if A.Quality == "Clean" then return "Clean" end
		Best = "Flawed"
	end
	return Best
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
	-- the skill tree's Toughness / Vigor (Modules.Data.Rensei.SkillTree)
	local SkillTree = require(Rensei.SkillTree)
	local MaxHealth = Derived.MaxHealth * (1 + (SkillTree.Modifiers(Data).MaxHealth or 0))
	Humanoid.MaxHealth = MaxHealth
	Humanoid.Health = MaxHealth * math.clamp(Ratio, 0, 1)
	-- every other skill-tree effect: Mod_<Key> attributes + resource maxima
	require(ServerScriptService.SkillTreeService).Publish(Player)
	-- the Truth clap: a faster clap once the player has passed a Gate trial (AlchemyService reads it)
	local Clap = ProgressionService.TruthClap(Data)
	Character:SetAttribute("TruthClap", Clap and require(Rensei.Truth).Config.ClapWindup[Clap] or nil)
	Character:SetAttribute("TruthTouched", Clap ~= nil or nil)
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

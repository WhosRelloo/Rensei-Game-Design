-- QuestService: quest state lives in the profile (Quests.Active / Quests.Completed). Progress only
-- moves through Signal(), which server systems call; the client can only ask to abandon or track.
-- Completion is idempotent: a quest leaves Active BEFORE rewards are paid, so a repeated signal
-- or request can never pay twice.
-- Quests have ordered Stages (Rensei.StoryLogic); only the current stage's objectives advance.
-- When a stage starts, objectives that are already true (evidence held, puzzle solved, flag set...)
-- are filled in at once (CatchUp), so the order a player finds things in never matters.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Definitions = require(ReplicatedStorage.Modules.Data.Rensei.Quests)
local StoryLogic = require(ReplicatedStorage.Modules.Data.Rensei.StoryLogic)
local ProgressionService = require(ServerScriptService.ProgressionService)
local UIService = require(ServerScriptService.UIService)

local QuestService = {}
QuestService.Definitions = Definitions

local function Valid(Def)
	if type(Def) ~= "table" or type(Def.Title) ~= "string" then return false end
	local Stages = StoryLogic.Stages(Def)
	return #Stages > 0 and #Stages[1].Objectives > 0
end

-- ===== catch-up: objectives whose condition is already true =====
local function AlreadyTrue(Data, O)
	local S = Data.Story or {}
	if O.Kind == "Evidence" then return (S.Evidence or {})[O.Target] ~= nil end
	if O.Kind == "Deduce" then return (S.Deductions or {})[O.Target] ~= nil end
	if O.Kind == "Puzzle" then return (S.Puzzles or {})[O.Target] ~= nil end
	if O.Kind == "Flag" then return (S.Flags or {})[O.Target] ~= nil end
	if O.Kind == "Minigame" then return (S.Minigames or {})[O.Target] ~= nil and S.Minigames[O.Target].Passed ~= nil end
	return false
end

local function CatchUp(Data, Def, State)
	local Stage = StoryLogic.Stage(Def, State)
	for _, O in ipairs(Stage.Objectives) do
		if AlreadyTrue(Data, O) then State.Progress[O.Id] = O.Count or 1 end
	end
end

local function GiveRewards(Player, Data, Rewards, Source)
	Rewards = Rewards or {}
	if (Rewards.Money or 0) > 0 then ProgressionService.GrantMoney(Player, Rewards.Money) end
	if (Rewards.Exp or 0) > 0 then ProgressionService.GrantExp(Player, Rewards.Exp, Source or "Quest") end
	for _, Item in ipairs(Rewards.Items or {}) do
		require(ServerScriptService.ItemService).Give(Player, Item.Name or Item[1], Item.Amount or Item[2] or 1)
	end
	for _, Entry in ipairs(Rewards.Codex or {}) do
		if not Data.Codex[Entry] then
			Data.Codex[Entry] = os.time()
			UIService.Notify(Player, "Banner", {Text = "New Entry Unlocked - [" .. Entry .. "]"})
		end
	end
end

-- ===== start / abandon / track =====
function QuestService.CanStart(Player, QuestId)
	local Data = ProgressionService.GetData(Player)
	local Def = Definitions[QuestId]
	if not Data or not Valid(Def) then return false, "Unknown quest" end
	if Data.Quests.Active[QuestId] then return false, "Already active" end
	local Done = Data.Quests.Completed[QuestId]
	if Done and not Def.Repeatable then return false, "Already completed" end
	if Done and Def.Cooldown and os.time() - Done < Def.Cooldown then
		return false, ("Available again in %d min"):format(math.ceil((Def.Cooldown - (os.time() - Done)) / 60))
	end
	if not StoryLogic.Meets(Def.Requires, Data, Player) then return false, "Not available yet" end
	return true
end

function QuestService.Start(Player, QuestId)
	local Ok, Why = QuestService.CanStart(Player, QuestId)
	if not Ok then
		if Why and Why ~= "Unknown quest" and Why ~= "Already active" then UIService.Notify(Player, "Toast", {Text = Why}) end
		return false, Why
	end
	local Data = ProgressionService.GetData(Player)
	local Def = Definitions[QuestId]
	local Progress = {}
	for _, Objective in ipairs(StoryLogic.AllObjectives(Def)) do Progress[Objective.Id] = 0 end
	local State = {Stage = 1, Progress = Progress, Started = os.time()}
	Data.Quests.Active[QuestId] = State
	if (Data.Quests.Tracked or "") == "" or not Data.Quests.Active[Data.Quests.Tracked] then Data.Quests.Tracked = QuestId end
	UIService.Notify(Player, "Banner", {Text = "Quest Accepted - [" .. Def.Title .. "]"})
	CatchUp(Data, Def, State)
	QuestService.Advance(Player, Data, QuestId)
	ProgressionService.Sync(Player)
	return true
end

function QuestService.Abandon(Player, QuestId)
	local Data = ProgressionService.GetData(Player)
	if not Data or type(QuestId) ~= "string" or not Data.Quests.Active[QuestId] then return false end
	-- evidence and flags are knowledge: abandoning a quest keeps them (and CatchUp re-uses them)
	Data.Quests.Active[QuestId] = nil
	if Data.Quests.Tracked == QuestId then Data.Quests.Tracked = "" end
	ProgressionService.Sync(Player)
	return true
end

function QuestService.Track(Player, QuestId)
	local Data = ProgressionService.GetData(Player)
	if not Data or type(QuestId) ~= "string" or not Data.Quests.Active[QuestId] then return false end
	Data.Quests.Tracked = QuestId
	ProgressionService.Sync(Player)
	return true
end

-- ===== stages / completion =====
local function Complete(Player, Data, QuestId)
	local Def = Definitions[QuestId]
	if not Data.Quests.Active[QuestId] then return end
	Data.Quests.Active[QuestId] = nil -- leave Active first: rewards can only ever pay once
	Data.Quests.Completed[QuestId] = os.time()
	if Data.Quests.Tracked == QuestId then Data.Quests.Tracked = "" end
	UIService.Notify(Player, "Banner", {Text = "Quest Complete - [" .. Def.Title .. "]"})
	GiveRewards(Player, Data, Def.Rewards, "Quest")
	local Outcome = Def.Outcomes and Data.Story and Data.Story.Flags["Outcome_" .. QuestId]
	local Extra = Outcome and Def.Outcomes[Outcome]
	if Extra then
		GiveRewards(Player, Data, Extra.Rewards, "Quest")
		-- the ending's deeds (MoralityService records each once ever)
		for _, Deed in ipairs(Extra.Deeds or {}) do require(ServerScriptService.MoralityService).Record(Player, Deed) end
	end
end

-- Moves the quest through every stage that is already done; completes it after the last.
function QuestService.Advance(Player, Data, QuestId)
	local Def = Definitions[QuestId]
	local State = Data.Quests.Active[QuestId]
	if not Def or not State then return end
	local Stages = StoryLogic.Stages(Def)
	State.Stage = State.Stage or 1
	while Data.Quests.Active[QuestId] and StoryLogic.StageDone(Stages[State.Stage], State.Progress) do
		if State.Stage >= #Stages then
			Complete(Player, Data, QuestId)
			return
		end
		State.Stage += 1
		CatchUp(Data, Def, State)
		UIService.Notify(Player, "Banner", {Text = "Journal Updated - " .. (Stages[State.Stage].Text or Def.Title)})
	end
end

-- Kind/Target match objective definitions. Only the CURRENT stage's objectives advance.
-- Returns true if anything advanced.
function QuestService.Signal(Player, Kind, Target, Amount)
	local Data = ProgressionService.GetData(Player)
	if not Data then return false end
	local Changed = false
	local Ids = {}
	for QuestId in pairs(Data.Quests.Active) do table.insert(Ids, QuestId) end
	for _, QuestId in ipairs(Ids) do
		local State = Data.Quests.Active[QuestId]
		local Def = Definitions[QuestId]
		if Def and State then
			local Stage = StoryLogic.Stage(Def, State)
			for _, Objective in ipairs(Stage.Objectives) do
				local Need = Objective.Count or 1
				local Have = State.Progress[Objective.Id] or 0
				if Objective.Kind == Kind and Objective.Target == Target and Have < Need then
					State.Progress[Objective.Id] = math.min(Need, Have + (Amount or 1))
					Changed = true
				end
			end
			if Changed then QuestService.Advance(Player, Data, QuestId) end
		end
	end
	if Changed then ProgressionService.Sync(Player) end
	return Changed
end

return QuestService

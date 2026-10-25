-- StoryLogic: the rules shared by the server (QuestService, DialogueService, InvestigationService,
-- PuzzleService) and the client UI (HUD tracker, Journal), so both read quests and conditions the
-- same way. Pure functions over the profile data; nothing here writes anything.
--
-- Conditions (`Requires` tables in Quests / Dialogues / Investigation / Puzzles). Every key present
-- must pass:
--   Flag = "id" | {"a", "b"}        flags set (any truthy value)
--   FlagIs = {Id = value}             a flag equals a value (e.g. Outcome_chalk = "Report")
--   NotFlag = "id" | {...}            flags NOT set
--   Evidence = "id" | {...}           evidence held
--   NotEvidence = "id" | {...}
--   Deduction = "id" | {...}          deductions made
--   Puzzle = "id" | {...}             per-player puzzles solved
--   Quest = {Id = "q", Is = "Active" | "Completed" | "NotStarted" | "NotCompleted" | "NotActive", Stage = n, StageAtLeast = n}
--   Quests = {{...}, {...}}           several Quest conditions
--   Affinity = "Flame" | {...}        the alchemy path (Identity.Affinity, or the Player attribute)
--   NoAffinity = true                 no SAVED path yet (Identity.Affinity empty; Studio's stand-in doesn't count)
--   SavedAffinity = "Flame" | {...}   the SAVED path is one of these (not Studio's stand-in)
--   Level = n                         minimum level
--   Item = "name"                     holds an inventory item
--   StyleReady = "Boxing"             meets that style's trainer requirements (Rensei.Styles.Unlock)
--   StyleUnlocked / NotStyleUnlocked = "Boxing"   the style is / isn't learned yet
-- Morality (MoralityService; Rensei.Factions / Rensei.Deeds):
--   Deed = "id" | {...}               deeds on the ledger
--   NotDeed = "id" | {...}            deeds NOT on the ledger
--   Standing = {Authority = "Trusted" | 20}       at least that tier / value
--   StandingBelow = {Foundry = "Distrusted" | -20} at most that tier / value
--   Trait = {Mercy = "Merciful"}      the conduct word showing on that axis
--   Trust = {Lise = 30}               at least; TrustBelow = {Lise = -30}: at most
--   Renown = n                        at least
-- Heat and Wanted (Plan 2, 2026-10-20; Rensei.Heat, decayed to now):
--   Heat = {State = n}                at least that much Heat; HeatBelow = {State = n}: less than
--   Wanted = {State = n}              at least Wanted n; WantedBelow = {State = n}: at most Wanted n

local Factions = require(script.Parent.Factions)

local StoryLogic = {}

local function List(V)
	if V == nil then return {} end
	return type(V) == "table" and V or {V}
end
StoryLogic.List = List

-- ===== quest stages =====
-- A definition either has Stages = {{Id, Text, Objectives}} or the original flat Objectives list
-- (one stage). A revised definition carries Revision / Prepended (UpgradeQuest, below).
function StoryLogic.Stages(Def)
	if Def.Stages then return Def.Stages end
	Def.__Stages = Def.__Stages or {{Id = "s1", Text = Def.Description, Objectives = Def.Objectives or {}}}
	return Def.__Stages
end

function StoryLogic.Stage(Def, State)
	local Stages = StoryLogic.Stages(Def)
	return Stages[math.clamp((State and State.Stage) or 1, 1, #Stages)], #Stages
end

-- the index of the stage with this Id in Def's stage list, or nil (Foundry Yard plan: data modules name stages by id)
function StoryLogic.StageIndex(Def, StageId)
	if type(Def) ~= "table" then return nil end
	for I, S in ipairs(StoryLogic.Stages(Def)) do
		if S.Id == StageId then return I end
	end
	return nil
end

-- all objectives across every stage (unique ids are required across the whole quest)
function StoryLogic.AllObjectives(Def)
	local Out = {}
	for _, S in ipairs(StoryLogic.Stages(Def)) do
		for _, O in ipairs(S.Objectives) do table.insert(Out, O) end
	end
	return Out
end

function StoryLogic.Done(Objective, Progress)
	return ((Progress or {})[Objective.Id] or 0) >= (Objective.Count or 1)
end

-- every required (non-Optional) objective of the stage is done
function StoryLogic.StageDone(Stage, Progress)
	for _, O in ipairs(Stage.Objectives) do
		if not O.Optional and not StoryLogic.Done(O, Progress) then return false end
	end
	return true
end

-- Saved quest states follow a revised quest (Foundry Yard plan, 2026-10-24). A definition with Revision = n and
-- Prepended = {[r] = k} put k new stages in front of its stage list at revision r. A saved Active state from an older
-- revision (State.Revision missing = 1) moves forward past those stages, so the player stays on the stage they were
-- on. Returns true when it changed State. (Fix round 1, Ruling 22: the new stage is clamped to the last stage, and a
-- non-number Prepended value counts as 0. Final review I1: and never below stage 1.)
function StoryLogic.UpgradeQuest(Def, State)
	if type(Def) ~= "table" or type(State) ~= "table" or type(Def.Revision) ~= "number" then return false end
	local From = type(State.Revision) == "number" and State.Revision or 1
	if From >= Def.Revision then return false end
	local Shift = 0
	for R = From + 1, Def.Revision do
		local K = type(Def.Prepended) == "table" and Def.Prepended[R]
		if type(K) == "number" then Shift += K end
	end
	local Stage = (type(State.Stage) == "number" and State.Stage or 1) + Shift
	local Count = (type(Def.Stages) == "table" and #Def.Stages) or (type(Def.Objectives) == "table" and 1) or 0
	if Count > 0 then Stage = math.min(Stage, Count) end
	Stage = math.max(Stage, 1) -- (final review I1) never below stage 1, even for a negative Prepended
	State.Stage = Stage
	State.Revision = Def.Revision
	return true
end

-- (Fix round 1, Ruling 22) a saved state from an older revision of a revised quest, not yet upgraded (QuestService.Boot
-- upgrades it on join). Until then its Stage means an older stage list: nothing may read or move it (QuestService
-- skips it; stage conditions treat it as not yet known).
function StoryLogic.Stale(Def, State)
	if type(Def) ~= "table" or type(Def.Revision) ~= "number" or type(State) ~= "table" then return false end
	return (type(State.Revision) == "number" and State.Revision or 1) < Def.Revision
end

-- the current stage's objectives the journal should show (Hidden ones appear once started)
function StoryLogic.Visible(Def, State)
	local Stage = StoryLogic.Stage(Def, State)
	local Out = {}
	for _, O in ipairs(Stage.Objectives) do
		if not O.Hidden or ((State.Progress or {})[O.Id] or 0) > 0 then table.insert(Out, O) end
	end
	return Out, Stage
end

-- ===== conditions =====
local function Story(Data) return Data.Story or {} end

local QuestDefs -- (Rensei.Quests, required on first use)
local function QuestIs(Data, Q)
	local Active = Data.Quests and Data.Quests.Active[Q.Id]
	local Completed = Data.Quests and Data.Quests.Completed[Q.Id]
	-- (fix round 1) a stale-revision state's stage is not yet known: it meets no Stage / StageAtLeast condition
	local Known = Active
	if Active and (Q.Stage or Q.StageAtLeast) then
		QuestDefs = QuestDefs or require(script.Parent.Quests)
		if StoryLogic.Stale(QuestDefs[Q.Id], Active) then Known = nil end
	end
	local Is = Q.Is or "Active"
	if Is == "Active" and not Active then return false end
	if Is == "Completed" and not Completed then return false end
	if Is == "NotStarted" and (Active or Completed) then return false end
	if Is == "NotCompleted" and Completed then return false end
	if Is == "NotActive" and Active then return false end
	if Q.Stage and not (Known and (Known.Stage or 1) == Q.Stage) then return false end
	if Q.StageAtLeast and not (Completed or (Known and (Known.Stage or 1) >= Q.StageAtLeast)) then return false end
	return true
end

-- Player is optional (used for the live Affinity attribute in Studio test setups)
function StoryLogic.Meets(Requires, Data, Player)
	if not Requires then return true end
	if not Data then return false end
	local S = Story(Data)
	for _, F in ipairs(List(Requires.Flag)) do if not (S.Flags or {})[F] then return false end end
	for K, V in pairs(Requires.FlagIs or {}) do if (S.Flags or {})[K] ~= V then return false end end
	for _, F in ipairs(List(Requires.NotFlag)) do if (S.Flags or {})[F] then return false end end
	for _, E in ipairs(List(Requires.Evidence)) do if not (S.Evidence or {})[E] then return false end end
	for _, E in ipairs(List(Requires.NotEvidence)) do if (S.Evidence or {})[E] then return false end end
	for _, D in ipairs(List(Requires.Deduction)) do if not (S.Deductions or {})[D] then return false end end
	for _, P in ipairs(List(Requires.Puzzle)) do if not (S.Puzzles or {})[P] then return false end end
	if Requires.Quest and not QuestIs(Data, Requires.Quest) then return false end
	for _, Q in ipairs(Requires.Quests or {}) do if not QuestIs(Data, Q) then return false end end
	if Requires.Affinity then
		local Mine = (Player and Player:GetAttribute("Affinity")) or (Data.Identity and Data.Identity.Affinity) or ""
		if not table.find(List(Requires.Affinity), Mine) then return false end
	end
	if Requires.StyleReady or Requires.StyleUnlocked or Requires.NotStyleUnlocked then
		local Styles = require(script.Parent.Styles)
		if Requires.StyleReady and not Styles.Ready(Data, Requires.StyleReady) then return false end
		if Requires.StyleUnlocked and not Styles.Unlocked(Data, Requires.StyleUnlocked) then return false end
		if Requires.NotStyleUnlocked and Styles.Unlocked(Data, Requires.NotStyleUnlocked) then return false end
	end
	if Requires.NoAffinity and ((Data.Identity and Data.Identity.Affinity) or "") ~= "" then return false end
	if Requires.SavedAffinity and not table.find(List(Requires.SavedAffinity), (Data.Identity and Data.Identity.Affinity) or "") then return false end
	if Requires.Level and (Data.Level or 1) < Requires.Level then return false end
	-- Automail fitted (true) / not fitted (false) (2026-10-19, the Lindenmoor mechanic); Money = at least n
	if Requires.Automail ~= nil and ((Data.Automail and Data.Automail.Installed) == true) ~= (Requires.Automail == true) then return false end
	if Requires.Money and (Data.Money or 0) < Requires.Money then return false end
	if Requires.Item then
		local Has = false
		for _, I in ipairs(Data.Inventory or {}) do if I.ItemName == Requires.Item then Has = true end end
		if not Has then return false end
	end
	local M = Data.Morality or {}
	for _, D in ipairs(List(Requires.Deed)) do if not (M.Deeds or {})[D] then return false end end
	for _, D in ipairs(List(Requires.NotDeed)) do if (M.Deeds or {})[D] then return false end end
	for F, V in pairs(Requires.Standing or {}) do
		if Factions.Clamp((M.Standing or {})[F]) < Factions.Threshold(V) then return false end
	end
	for F, V in pairs(Requires.StandingBelow or {}) do
		if Factions.Clamp((M.Standing or {})[F]) > Factions.Threshold(V, true) then return false end
	end
	for Axis, Word in pairs(Requires.Trait or {}) do
		if Factions.Word(Axis, (M.Conduct or {})[Axis]) ~= Word then return false end
	end
	for N, V in pairs(Requires.Trust or {}) do if Factions.Clamp((M.Trust or {})[N]) < V then return false end end
	for N, V in pairs(Requires.TrustBelow or {}) do if Factions.Clamp((M.Trust or {})[N]) > V then return false end end
	if Requires.Renown and (M.Renown or 0) < Requires.Renown then return false end
	if Requires.Heat or Requires.HeatBelow or Requires.Wanted or Requires.WantedBelow then
		local Heat = require(script.Parent.Heat)
		local Now = os.time()
		for J, N in pairs(Requires.Heat or {}) do if Heat.ValueOf(M.Heat, J, Now) < N then return false end end
		for J, N in pairs(Requires.HeatBelow or {}) do if Heat.ValueOf(M.Heat, J, Now) >= N then return false end end
		for J, N in pairs(Requires.Wanted or {}) do if Heat.WantedOf(M.Heat, J, Now) < N then return false end end
		for J, N in pairs(Requires.WantedBelow or {}) do if Heat.WantedOf(M.Heat, J, Now) > N then return false end end
	end
	return true
end

-- A short reason for a locked dialogue choice ("[Evidence: Boot Prints]")
function StoryLogic.LockLabel(Requires, EvidenceDefs)
	if not Requires then return "" end
	local E = List(Requires.Evidence)[1]
	if E then return "[Evidence: " .. ((EvidenceDefs and EvidenceDefs[E] and EvidenceDefs[E].Title) or E) .. "]" end
	local A = List(Requires.Affinity)[1]
	if A then return "[" .. A .. " Alchemy]" end
	if Requires.StyleReady then
		local S = require(script.Parent.Styles).Def(Requires.StyleReady)
		local U = S and S.Unlock or {}
		local Parts = {}
		if U.Level then table.insert(Parts, "Level " .. U.Level) end
		for Stat, Need in pairs(U.Stats or {}) do table.insert(Parts, Stat .. " " .. Need) end
		return "[Needs " .. table.concat(Parts, ", ") .. "]"
	end
	if Requires.Level then return "[Level " .. Requires.Level .. "]" end
	if Requires.Item then return "[Item: " .. Requires.Item .. "]" end
	for F, V in pairs(Requires.Standing or {}) do
		return "[" .. ((Factions.Factions[F] and Factions.Factions[F].Name) or F) .. ": " .. (type(V) == "string" and V or Factions.TierOf(V)) .. "]"
	end
	for _, Word in pairs(Requires.Trait or {}) do return "[" .. Word .. "]" end
	for N in pairs(Requires.Trust or {}) do return "[Trust: " .. N .. "]" end
	if Requires.Renown then return "[Renown: " .. Factions.RankOf(Requires.Renown) .. "]" end
	return "[Locked]"
end

return StoryLogic

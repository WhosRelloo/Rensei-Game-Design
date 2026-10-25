-- Play_FoundryLedger (Foundry data plan Task 6, 2026-10-25): the shift-ledger quest (spec §7.3), end to end in Foundry,
-- inside the game VM (LMRunSuite) with the Play client connected, inside the snapshot / restore runner. It needs
-- Foundry's two clue markers (Map.Foundry.Markers, RenseiClue) and Foundry's roster, so it runs in Foundry only.
--   * The flow (one run, in order; a step after a failed one fails as skipped):
--       DocketIsLockedFirst           with no quest, the docket is inspected but gives nothing: the player reads its
--                                     Locked line (the inspect handler, as the prompt does).
--       LedgerStartsTheQuest          the ledger gives foundry_full_shift and starts foundry_ledger at stage 1 with
--                                     "ledger" caught up; at stage 1 the docket is still locked.
--       CrewAndClerkAnswer            Rusk, Marsh and the clerk each say their clue line (Kind "Clue", the roster's
--                                     text), give their evidence and signal their objective; stage 2 only after
--                                     the third.
--       DocketFound                   at stage 2 the docket gives foundry_scraped_docket; stage 3.
--       DeductionNeedsTheRightPieces  a wrong board is refused with the Wrong line and leaves the quest active; the
--                                     right one gives the Conclusion and completes the quest.
--       RewardsAsDesigned             (the real Rewards back) 300 Exp, 100 Money, the deed foundry_ledger_cleared
--                                     with Foundry standing 10; QuestService.Grant records the deed.
--     The flow's rewards are switched off (Rewards = {}) while it runs.
--   * IdsExist (Ruling 2 / Task 2 review Minor 7): across all the data, every evidence id a quest objective, an inspect
--     def, a deduction or a townsperson's clue line names is an Evidence def, and every deed id a quest's Rewards or
--     Outcomes name is a Deeds def; foundry_ledger's own ids are among those checked.
--   * CompassFindsTheClues: ReplicatedStorage.CompassPoints has an Inspect point for each clue, within 0.5 studs of
--     its part, labelled with the clue's title and naming its evidence.
-- Set-up (Ruling 14, Ruling 8): deep copies of Data.Quests, Data.Story and Data.Morality; the Talk cooldown 0; the clock
-- held at 10:00 and Foundry's roster loaded (TownsfolkService.LoadRegion), so nobody walks and Rusk is at furnace_1,
-- Marsh at workers_row_6, the clerk at shift_clerk. The test never waits for a walk: it moves the player, not them.
-- Everything is put back afterwards: the save tables (in place), the Rewards, the cooldown, the clock, the player's
-- position and the dialogue box.
local SSS = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local Rensei = game.ReplicatedStorage.Modules.Data.Rensei

local QUEST = "foundry_ledger"
local DEDUCTION = "foundry_ledger_who"
local DEED = "foundry_ledger_cleared"
local LEDGER, DOCKET = "foundry_shift_ledger", "foundry_altered_docket"
local CLUES = {
	[LEDGER] = {Evidence = "foundry_full_shift", Title = "Shift Ledger"},
	[DOCKET] = {Evidence = "foundry_scraped_docket", Title = "Shift Docket"},
}
local EVIDENCE = {"foundry_full_shift", "foundry_banked_early", "foundry_short_pay", "foundry_docket_round", "foundry_scraped_docket"}
-- who answers, where they stand at 10:00 (Task 5's schedules), and what they give
local TELLERS = {
	{Id = "fy_furnace_d1", Post = "furnace_1", Signal = "foundry_ledger_rusk", Evidence = "foundry_banked_early", Objective = "rusk"},
	{Id = "fy_furnace_l1", Post = "workers_row_6", Signal = "foundry_ledger_marsh", Evidence = "foundry_short_pay", Objective = "marsh"},
	{Id = "fy_clerk", Post = "shift_clerk", Signal = "foundry_ledger_clerk", Evidence = "foundry_docket_round", Objective = "clerk"},
}
local HOUR = 10
local CALM_WAIT = 5 -- s for a townsperson to be AtPost or Asleep before a Talk

local function Copy(T)
	if type(T) ~= "table" then return T end
	local R = {}
	for K, V in pairs(T) do R[K] = Copy(V) end
	return R
end

-- the clue parts in the world: {[ClueId] = Part}
local function CluePart(Id)
	for _, P in ipairs(CollectionService:GetTagged("RenseiClue")) do
		if P:IsDescendantOf(workspace) and P:GetAttribute("ClueId") == Id then return P end
	end
end

-- the player's character held still beside Pos (anchored; 5 studs off, 3 up), for an inspect or a Talk
local function Stand(Player, Pos)
	local C = Player.Character
	local Root = C and C:FindFirstChild("HumanoidRootPart")
	assert(Root, "the player has a character")
	Root.Anchored = true
	C:PivotTo(CFrame.new(Pos + Vector3.new(0, 3, 5)))
	Root.AssemblyLinearVelocity = Vector3.zero
	task.wait(0.1)
	return Root
end

-- ===== the flow =====
local STEPS = {"DocketIsLockedFirst", "LedgerStartsTheQuest", "CrewAndClerkAnswer", "DocketFound",
	"DeductionNeedsTheRightPieces", "RewardsAsDesigned"}
local INDEPENDENT = {RewardsAsDesigned = true} -- (runs whatever happened before it)

-- Body[Name](T, Ctx): one step. Ctx = {Player, Data, Said}
local Body = {}

Body.DocketIsLockedFirst = function(T, Ctx)
	local Investigation = require(SSS.InvestigationService)
	local Def = require(Rensei.Investigation).Inspects[DOCKET]
	T.True(Def ~= nil, DOCKET .. " has an inspect def")
	local Part = CluePart(DOCKET)
	T.True(Part ~= nil, DOCKET .. " is in the place")
	Stand(Ctx.Player, Part.Position)
	table.clear(Ctx.Said)
	T.True(Investigation.Inspect(Ctx.Player, DOCKET, Part), "the docket was inspected")
	T.True(Ctx.Data.Story.Evidence.foundry_scraped_docket == nil, "no evidence from the docket before the quest")
	T.Eq(Ctx.Said[#Ctx.Said], Def.Locked, "the player reads the docket's Locked line")
	T.True(Def.Locked ~= Def.Text, "the Locked line is not the docket's text")
end

Body.LedgerStartsTheQuest = function(T, Ctx)
	local Investigation = require(SSS.InvestigationService)
	local Part = CluePart(LEDGER)
	T.True(Part ~= nil, LEDGER .. " is in the place")
	Stand(Ctx.Player, Part.Position)
	T.True(Investigation.Inspect(Ctx.Player, LEDGER, Part), "the ledger was inspected")
	T.True(Ctx.Data.Story.Evidence.foundry_full_shift ~= nil, "the ledger gave foundry_full_shift")
	local State = Ctx.Data.Quests.Active[QUEST]
	T.True(State ~= nil, "the ledger started " .. QUEST)
	T.Eq(State.Stage, 1, QUEST .. " at stage 1")
	T.Eq(State.Progress.ledger, 1, "the ledger objective is done")
	for _, Teller in ipairs(TELLERS) do T.Eq(State.Progress[Teller.Objective], 0, Teller.Objective .. " not asked yet") end
	-- the docket's gate is stage 2: at stage 1 it still gives nothing
	local Docket = CluePart(DOCKET)
	T.True(Docket ~= nil, DOCKET .. " is in the place")
	Stand(Ctx.Player, Docket.Position)
	T.True(Investigation.Inspect(Ctx.Player, DOCKET, Docket), "the docket was inspected at stage 1")
	T.True(Ctx.Data.Story.Evidence.foundry_scraped_docket == nil, "no evidence from the docket at stage 1")
end

Body.CrewAndClerkAnswer = function(T, Ctx)
	local TS = require(SSS.TownsfolkService)
	local Roster = require(Rensei.Townsfolk).Regions.Foundry
	local ById = {}
	for _, D in ipairs(Roster) do ById[D.Id] = D end
	for I, Teller in ipairs(TELLERS) do
		local Def = ById[Teller.Id]
		T.True(Def ~= nil, Teller.Id .. " is in Foundry's roster")
		T.True(type(Def.Clue) == "table", Teller.Id .. " has a clue line")
		T.Eq(Def.Clue.Quest, QUEST, Teller.Id .. "'s clue quest")
		T.Eq(Def.Clue.Stage, 1, Teller.Id .. "'s clue stage")
		T.Eq(Def.Clue.Signal, Teller.Signal, Teller.Id .. "'s clue signal")
		T.Eq(Def.Clue.Evidence, Teller.Evidence, Teller.Id .. "'s clue evidence")
		local Rig = TS.Get(Teller.Id)
		T.True(Rig ~= nil, Teller.Id .. " is spawned")
		T.Eq(Rig:GetAttribute("PostId"), Teller.Post, Teller.Id .. " is at its 10:00 post")
		local Root = Rig:FindFirstChild("HumanoidRootPart")
		T.True(Root ~= nil, Teller.Id .. " has a root")
		local Me = Stand(Ctx.Player, Root.Position)
		T.True((Me.Position - Root.Position).Magnitude <= TS.TalkRange, Teller.Id .. ": the player is within the talk range")
		local T0 = os.clock()
		while not (TS.State(Teller.Id) == "AtPost" or TS.State(Teller.Id) == "Asleep") and os.clock() - T0 < CALM_WAIT do
			task.wait(0.1)
		end
		local St = TS.State(Teller.Id)
		T.True(St == "AtPost" or St == "Asleep", Teller.Id .. " is calm (" .. tostring(St) .. ")")
		local Text, Kind = TS.Talk(Ctx.Player, Teller.Id)
		T.Eq(Kind, "Clue", Teller.Id .. " says the clue line")
		T.Eq(Text, Def.Clue.Text, Teller.Id .. "'s clue text")
		T.True(Ctx.Data.Story.Evidence[Teller.Evidence] ~= nil, Teller.Id .. " gave " .. Teller.Evidence)
		local State = Ctx.Data.Quests.Active[QUEST]
		T.True(State ~= nil, QUEST .. " still active after " .. Teller.Id)
		T.Eq(State.Progress[Teller.Objective], 1, Teller.Objective .. " is done")
		T.Eq(State.Stage, I < #TELLERS and 1 or 2, "the stage after " .. Teller.Id)
	end
end

Body.DocketFound = function(T, Ctx)
	local Investigation = require(SSS.InvestigationService)
	local State = Ctx.Data.Quests.Active[QUEST]
	T.True(State ~= nil and State.Stage == 2, QUEST .. " at stage 2")
	local Part = CluePart(DOCKET)
	T.True(Part ~= nil, DOCKET .. " is in the place")
	Stand(Ctx.Player, Part.Position)
	T.True(Investigation.Inspect(Ctx.Player, DOCKET, Part), "the docket was inspected at stage 2")
	T.True(Ctx.Data.Story.Evidence.foundry_scraped_docket ~= nil, "the docket gave foundry_scraped_docket")
	State = Ctx.Data.Quests.Active[QUEST]
	T.True(State ~= nil, QUEST .. " still active")
	T.Eq(State.Stage, 3, QUEST .. " at stage 3")
	T.Eq(State.Progress.docket, 1, "the docket objective is done")
end

Body.DeductionNeedsTheRightPieces = function(T, Ctx)
	local Investigation = require(SSS.InvestigationService)
	local Def = require(Rensei.Investigation).Deductions[DEDUCTION]
	T.True(Def ~= nil, DEDUCTION .. " has a deduction def")
	local Ok, Text = Investigation.Deduce(Ctx.Player, DEDUCTION, {"foundry_banked_early", "foundry_short_pay", "foundry_scraped_docket"})
	T.Eq(Ok, false, "a wrong board is refused")
	T.Eq(Text, Def.Wrong, "the Wrong line")
	T.True(Ctx.Data.Story.Deductions[DEDUCTION] == nil, "no deduction from a wrong board")
	T.True(Ctx.Data.Quests.Active[QUEST] ~= nil, QUEST .. " is still active after a wrong board")
	Ok, Text = Investigation.Deduce(Ctx.Player, DEDUCTION, {"foundry_full_shift", "foundry_short_pay", "foundry_scraped_docket"})
	T.Eq(Ok, true, "the right board")
	T.Eq(Text, Def.Conclusion, "the Conclusion")
	T.True(Ctx.Data.Quests.Active[QUEST] == nil, QUEST .. " has left Active")
	T.True(Ctx.Data.Quests.Completed[QUEST] ~= nil, QUEST .. " is Completed")
end

Body.RewardsAsDesigned = function(T, Ctx)
	local Def = require(SSS.QuestService).Definitions[QUEST]
	T.True(Def ~= nil, QUEST .. " has a quest def")
	local R = Def.Rewards
	T.True(type(R) == "table", QUEST .. " has Rewards")
	T.Eq(R.Exp, 300, "Exp")
	T.Eq(R.Money, 100, "Money")
	T.True(type(R.Deeds) == "table", "Rewards.Deeds")
	T.Eq(R.Deeds[1], DEED, "the deed")
	local Deed = require(Rensei.Deeds)[DEED]
	T.True(Deed ~= nil, DEED .. " has a deed def")
	T.Eq(Deed.Standing and Deed.Standing.Foundry, 10, DEED .. "'s Foundry standing")
	local Morality = require(SSS.MoralityService)
	T.True(Ctx.Data.Morality.Deeds[DEED] == nil, DEED .. " not yet recorded (cleared by the set-up)")
	require(SSS.QuestService).Grant(Ctx.Player, {Deeds = {DEED}})
	T.True(Morality.Has(Ctx.Player, DEED), "Grant recorded " .. DEED)
end

local function RunFlow(T)
	local PS = require(SSS.ProgressionService)
	local TS = require(SSS.TownsfolkService)
	local WorldClock = require(SSS.WorldClock)
	local DialogueService = require(SSS.DialogueService)
	local Defs = require(SSS.QuestService).Definitions
	local Results = {}
	local Player = game.Players:GetPlayers()[1]
	local Data = Player and PS.GetData(Player)
	if not (Data and type(Data.Quests) == "table" and type(Data.Story) == "table" and type(Data.Morality) == "table") then
		for _, Name in ipairs(STEPS) do Results[Name] = "no player with a loaded save" end
		return Results
	end
	local Char = Player.Character
	local Root = Char and Char:FindFirstChild("HumanoidRootPart")
	local Home, WasAnchored = Char and Char:GetPivot(), Root and Root.Anchored
	local Saved = {}
	for _, K in ipairs({"Quests", "Story", "Morality"}) do Saved[K] = {Was = Data[K], Copy = Copy(Data[K])} end
	local HadDef = Defs[QUEST] ~= nil
	-- the def's own Rewards table goes back itself, not a copy (anything holding it keeps seeing the real one), with
	-- its contents as they were before the run
	local RealRewards = HadDef and Defs[QUEST].Rewards
	local RewardsCopy = HadDef and Copy(RealRewards)
	local OldCooldown = TS.TalkCooldown
	local WasHeld, WasHour = WorldClock.IsHeld(), WorldClock.Now()
	local RealSay = DialogueService.Say
	local Ctx = {Player = Player, Data = Data, Said = {}}

	local SetupOk, SetupErr = pcall(function()
		-- (Ruling 14) no cooldown between the three Talks; (Ruling 8) the clock held and the roster at its posts
		TS.TalkCooldown = 0
		WorldClock.Hold(HOUR)
		assert(TS.LoadRegion("Foundry", require(Rensei.Townsfolk).Regions.Foundry), "LoadRegion accepted Foundry's roster")
		if HadDef then Defs[QUEST].Rewards = {} end
		DialogueService.Say = function(P, Model, Speaker, Text)
			if P == Player then table.insert(Ctx.Said, Text) end
			return RealSay(P, Model, Speaker, Text)
		end
		-- a clean start: none of the quest's state in the save
		Data.Quests.Active[QUEST], Data.Quests.Completed[QUEST] = nil, nil
		for _, Id in ipairs(EVIDENCE) do Data.Story.Evidence[Id] = nil end
		Data.Story.Deductions[DEDUCTION] = nil
		if type(Data.Morality.Deeds) == "table" then Data.Morality.Deeds[DEED] = nil end
	end)
	local Failed = nil
	for _, Name in ipairs(STEPS) do
		if not SetupOk then
			Results[Name] = "set-up failed: " .. tostring(SetupErr)
		else
			if Name == "RewardsAsDesigned" and HadDef then Defs[QUEST].Rewards = RealRewards end -- (the real ones)
			if Failed and not INDEPENDENT[Name] then
				Results[Name] = "skipped: " .. Failed .. " failed"
			else
				local Ok, Err = pcall(Body[Name], T, Ctx)
				Results[Name] = Ok or tostring(Err)
				if not Ok and not INDEPENDENT[Name] then Failed = Name end
			end
		end
	end

	-- finally: everything back
	DialogueService.Say = RealSay
	local Back = {}
	local function Try(What, Fn)
		local Ok, Err = pcall(Fn)
		if not Ok then table.insert(Back, What .. ": " .. tostring(Err)) end
	end
	task.wait(0.2) -- (MoralityService's Recorded listeners run in spawned threads)
	Try("save", function()
		for K, S in pairs(Saved) do
			if type(S.Was) == "table" then
				for Key in pairs(S.Was) do S.Was[Key] = nil end
				for Key, V in pairs(S.Copy) do S.Was[Key] = Copy(V) end
			end
			Data[K] = S.Was
		end
	end)
	Try("rewards", function()
		if HadDef then
			if type(RealRewards) == "table" then
				for Key in pairs(RealRewards) do RealRewards[Key] = nil end
				for Key, V in pairs(RewardsCopy) do RealRewards[Key] = Copy(V) end
			end
			Defs[QUEST].Rewards = RealRewards
		end
	end)
	Try("cooldown", function() TS.TalkCooldown = OldCooldown end)
	Try("clock", function() if WasHeld then WorldClock.Hold(WasHour) else WorldClock.Release() end end)
	Try("player", function()
		if Char and Char.Parent and Home then
			Char:PivotTo(Home)
			Root.AssemblyLinearVelocity = Vector3.zero
			Root.Anchored = WasAnchored
		end
	end)
	Try("dialogue", function() DialogueService.Close(Player) end)
	Try("sync", function() PS.Sync(Player) end)
	if #Back > 0 then
		-- a failed put-back fails every step: the save may be wrong
		for _, Name in ipairs(STEPS) do Results[Name] = "NOT PUT BACK: " .. table.concat(Back, " | ") end
	end
	return Results
end

local Suite = {}
local Cache = nil
local Sorted = table.clone(STEPS)
table.sort(Sorted)
-- TestKit runs tests sorted by name: the first of the flow's names (sorted) runs the whole flow once; each step's test
-- reports its own result
for _, Name in ipairs(STEPS) do
	Suite[Name] = function(T)
		if Name == Sorted[1] then Cache = RunFlow(T) end
		local R = Cache and Cache[Name]
		if Name == Sorted[#Sorted] then Cache = nil end
		if R == nil then error("the flow didn't run (run the suite through TestKit)", 0) end
		if R ~= true then error(R, 0) end
	end
end

Suite.IdsExist = function(T)
	local Evidence = require(Rensei.Evidence)
	local Deeds = require(Rensei.Deeds)
	local Quests = require(Rensei.Quests)
	local Investigation = require(Rensei.Investigation)
	local Rosters = require(Rensei.Townsfolk).Regions
	local Checked, Bad = {}, {}
	local function Ev(Id, Where)
		Checked[Id] = true
		if type(Id) ~= "string" or Evidence[Id] == nil then table.insert(Bad, "evidence " .. tostring(Id) .. " (" .. Where .. ")") end
	end
	local function Deed(Id, Where)
		Checked[Id] = true
		if type(Id) ~= "string" or type(Deeds[Id]) ~= "table" then table.insert(Bad, "deed " .. tostring(Id) .. " (" .. Where .. ")") end
	end
	for QId, Q in pairs(Quests) do
		for SI, S in ipairs(Q.Stages or {{Objectives = Q.Objectives or {}}}) do
			for _, O in ipairs(S.Objectives or {}) do
				if O.Kind == "Evidence" then Ev(O.Target, QId .. " stage " .. SI .. " " .. tostring(O.Id)) end
			end
		end
		for _, D in ipairs(Q.Rewards and Q.Rewards.Deeds or {}) do Deed(D, QId .. " Rewards") end
		for K, O in pairs(Q.Outcomes or {}) do
			for _, D in ipairs(O.Deeds or {}) do Deed(D, QId .. " Outcomes." .. tostring(K)) end
			for _, D in ipairs(O.Rewards and O.Rewards.Deeds or {}) do Deed(D, QId .. " Outcomes." .. tostring(K) .. ".Rewards") end
		end
	end
	for Id, D in pairs(Investigation.Inspects) do
		if D.Evidence ~= nil then Ev(D.Evidence, "inspect " .. Id) end
	end
	for Id, D in pairs(Investigation.Deductions) do
		for _, E in ipairs(D.Requires and D.Requires.Evidence or {}) do Ev(E, "deduction " .. Id .. " Requires") end
		for I, S in ipairs(D.Slots or {}) do Ev(S.Answer, "deduction " .. Id .. " slot " .. I) end
	end
	for Region, Roster in pairs(Rosters) do
		for _, D in ipairs(Roster) do
			if type(D.Clue) == "table" and D.Clue.Evidence ~= nil then Ev(D.Clue.Evidence, Region .. " " .. tostring(D.Id) .. " clue") end
		end
	end
	table.sort(Bad)
	T.Eq(#Bad, 0, "ids with no def: " .. table.concat(Bad, ", "))
	-- the shift ledger's own ids were among those checked (so the sweep covered them)
	local Missing = {}
	for _, Id in ipairs(EVIDENCE) do if not Checked[Id] then table.insert(Missing, Id) end end
	if not Checked[DEED] then table.insert(Missing, DEED) end
	T.Eq(#Missing, 0, "the shift ledger's ids the sweep never met: " .. table.concat(Missing, ", "))
end

Suite.CompassFindsTheClues = function(T)
	local Points = game.ReplicatedStorage:FindFirstChild("CompassPoints")
	T.True(Points ~= nil, "ReplicatedStorage.CompassPoints exists")
	for Id, Want in pairs(CLUES) do
		local Part = CluePart(Id)
		T.True(Part ~= nil, Id .. " is in the place")
		local Found = nil
		for _, F in ipairs(Points:GetChildren()) do
			if F:GetAttribute("Kind") == "Inspect" and F:GetAttribute("Key") == Id then Found = F end
		end
		T.True(Found ~= nil, "an Inspect compass point for " .. Id)
		local P = Found:GetAttribute("Position")
		T.True(typeof(P) == "Vector3" and (P - Part.Position).Magnitude <= 0.5, Id .. "'s point is at its part")
		T.Eq(Found:GetAttribute("Label"), Want.Title, Id .. "'s point label")
		T.Eq(Found:GetAttribute("Evidence"), Want.Evidence, Id .. "'s point names its evidence")
	end
end

return Suite

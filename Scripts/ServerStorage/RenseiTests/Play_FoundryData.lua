-- Play_FoundryData (Foundry Yard plan Task 9, Ruling 9, 2026-10-25): acq_metal end to end in Foundry, through the real
-- services, in the game VM (LMRunSuite) with the Play client connected, inside the snapshot / restore runner. No
-- objective is set by hand. Foundry only (its forge rooms, its Brannoc).
--   * AcqMetalFromFoundry   with acq_* cleared, no path, the Silent Forge undiscovered and acq_metal's story pieces
--                           cleared (its four evidence, the forge_failure deduction, the two minigame passes, the trial
--                           flag, the bench's saved state), and acq_metal's Rewards {} for the run:
--       1. beside Brannoc, the conversation (DialogueService.Open) and "Teach me." then "I'll go."
--          (DialogueService.Choose, the Dialogue remote's own call): acq_metal is Active on stage 2 (invite), its
--          travel stage already done (TravelService.Here() is Foundry);
--       2. the player pivoted into the Silent Forge (SilentForgeFloor + (0, 3, 4)): WorldService's discovery moves it
--          to stage 3 (fieldwork) within 6 s;
--       3. the four metal_* points inspected from within 9 studs (InvestigationService.Inspect, as the prompt does),
--          then InvestigationService.Deduce(forge_failure, the three right pieces): stage 4 (experiment);
--       4. beside the material bench, its mechanism prompt's handler as PuzzleService runs it (in range, not in
--          combat, the bench not already Fitted -> MinigameService.Open(metal_match, {Mechanism, PassState})):
--          metal_match is open; the server's own answer (MinigameService.Solve) is submitted through
--          MinigameService.Submit, the path the remote takes (made public in Task 9): stage 5 (trial);
--       5. from 3 studs off the marker TrialService.Begin(metal_experiment) is true; the foe is knocked through
--          DownedManager.Damage (the damage call TrialService's hazards use on it); TrialService sets
--          Trial_metal_experiment itself and the quest moves to stage 6 (exam);
--       6. beside Brannoc, the conversation's exam choice opens metal_exam (as Play_Exams does); solved and submitted
--          the same way: stage 7 (recognition). The exam is passed; recognition isn't run.
--       RED (Task 9 Step 1): run before MinigameService.Submit existed, it failed at step 4.
--   * AcqMetalFromYeSave    a save from Ye mid-way ({Stage = 3, Progress = {}}, no Revision) goes to stage 4 through
--                           QuestService.UpgradeAll, and Brannoc's conversation then opens on his "experiment" node
--                           (the Starts entry for stage 4: the text the dialogue box is sent).
-- Everything is put back: Data.Quests, Story, Identity and Areas (deep copies, in place), acq_metal's Rewards, the
-- bench's state for this player, any trial run, any open minigame or conversation, the player's position.
local SSS = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rensei = ReplicatedStorage.Modules.Data.Rensei
local SmokeKit = require(script.Parent.SmokeKit)
local TestKit = require(script.Parent.TestKit)

local QUEST = "acq_metal"
local TRIAL = "metal_experiment"
local BENCH = "metal_bench"
local INSPECTS = {"metal_shaft", "metal_samples", "metal_gear", "metal_note"}
local PICKS = {"sheared_shaft", "sample_rack", "bad_weld"}
local EVIDENCE = {"sheared_shaft", "sample_rack", "bad_weld", "experiment_record"}
local DISCOVER_WAIT = 6 -- s (the brief)
local KNOCK_WAIT = 10 -- s, PROPOSAL: the foe knocked
local END_WAIT = 4 -- s, PROPOSAL: TrialService's watch sees it and ends the run
local CALM_WAIT = 20 -- s, PROPOSAL: InCombat cleared before the exam (the conversation refuses a fighter)

local function f1(V) return ("(%.1f, %.1f, %.1f)"):format(V.X, V.Y, V.Z) end
local function Brannoc()
	for _, D in ipairs(workspace:GetDescendants()) do
		if D:IsA("Model") and D:GetAttribute("DialogueId") == "trainer_metal" then return D end
	end
end
local function OneTagged(T, Tag, Attr, Value)
	local L = {}
	for _, I in ipairs(CollectionService:GetTagged(Tag)) do
		if I:IsDescendantOf(workspace) and I:GetAttribute(Attr) == Value then table.insert(L, I) end
	end
	T.Eq(#L, 1, ("%s with %s = %s in workspace"):format(Tag, Attr, tostring(Value)))
	return L[1]
end

-- runs Body(Player, Data, Ctx) with the save set up and everything put back after
local function Guarded(T, Body)
	local PS = require(SSS.ProgressionService)
	local QuestService = require(SSS.QuestService)
	local PuzzleService = require(SSS.PuzzleService)
	local MinigameService = require(SSS.MinigameService)
	local DialogueService = require(SSS.DialogueService)
	local TS = require(SSS.TrialService)
	local Player = game.Players:GetPlayers()[1]
	local Data = Player and PS.GetData(Player)
	local C = Player and Player.Character
	local Root = C and C:FindFirstChild("HumanoidRootPart")
	T.True(Data ~= nil and Root ~= nil, "a player with a save and a character")
	local Saved = {}
	for _, K in ipairs({"Quests", "Story", "Identity", "Areas"}) do Saved[K] = {Was = Data[K], Copy = SmokeKit.Copy(Data[K])} end
	local Def = QuestService.Definitions[QUEST]
	local OldRewards = Def.Rewards
	local OldBench = PuzzleService.StateOf(Player, BENCH)
	local Pivot, Anchored = C:GetPivot(), Root.Anchored
	local Ok, Err = pcall(function()
		Def.Rewards = {}
		Data.Identity = Data.Identity or {}
		Data.Identity.Affinity = ""
		for _, Box in ipairs({Data.Quests.Active, Data.Quests.Completed}) do
			for Id in pairs(Box) do if string.sub(Id, 1, 4) == "acq_" then Box[Id] = nil end end
		end
		Data.Areas["Silent Forge"] = nil
		local S = Data.Story
		for _, E in ipairs(EVIDENCE) do S.Evidence[E] = nil end
		S.Deductions.forge_failure = nil
		S.Minigames.metal_match, S.Minigames.metal_exam = nil, nil
		S.Flags["Trial_" .. TRIAL], S.Flags["Mech_" .. BENCH] = nil, nil
		if PuzzleService.StateOf(Player, BENCH) ~= "Idle" then PuzzleService.SetState(Player, BENCH, "Idle") end
		Body(Player, Data, C, Root)
	end)
	local Back = {}
	local function Try(What, Fn)
		local K, E = pcall(Fn)
		if not K then table.insert(Back, What .. ": " .. tostring(E)) end
	end
	Try("trial", function() for _, R in pairs(TS.Runs) do if R.Player == Player then R:End(false, "Test over.") end end end)
	Try("minigame", function() if MinigameService.Current(Player) then MinigameService.Cancel(Player, nil) end end)
	Try("dialogue", function() DialogueService.Close(Player) end)
	Try("rewards", function() Def.Rewards = OldRewards end)
	Try("save", function()
		for K, S in pairs(Saved) do
			if type(S.Was) == "table" then SmokeKit.PutBack(S.Was, S.Copy) end
			Data[K] = S.Was
		end
	end)
	-- (after the save: the bench's saved Mech_ flag is gone again, so a plain state change is allowed)
	Try("bench", function() if PuzzleService.StateOf(Player, BENCH) ~= OldBench then PuzzleService.SetState(Player, BENCH, OldBench) end end)
	Try("player", function()
		C:PivotTo(Pivot)
		Root.AssemblyLinearVelocity = Vector3.zero
		Root.Anchored = Anchored
	end)
	Try("sync", function() PS.Sync(Player) end)
	if not Ok then error(Err, 0) end
	T.Eq(#Back, 0, "NOT PUT BACK: " .. table.concat(Back, " | "))
	T.Eq(Def.Rewards, OldRewards, "acq_metal's Rewards are back")
end

-- the quest's stage id now (nil when not active)
local function StageId(Data)
	local Quests = require(Rensei.Quests)
	local StoryLogic = require(Rensei.StoryLogic)
	local State = Data.Quests.Active[QUEST]
	return State and StoryLogic.Stages(Quests[QUEST])[State.Stage].Id, State and State.Stage
end
local function Expect(T, Data, Step, Want)
	local Id, N = StageId(Data)
	T.Eq(Id, Want, ("step %d: acq_metal's stage (%s)"):format(Step, tostring(N)))
end
local function Hold(Root, C, CF)
	Root.Anchored = true
	C:PivotTo(CF)
	Root.AssemblyLinearVelocity = Vector3.zero
	task.wait(0.1)
end
-- the open minigame Id, solved by the server and submitted through MinigameService.Submit (the remote's own path)
local function SolveAndSubmit(T, Player, Id, Step)
	local MinigameService = require(SSS.MinigameService)
	T.Eq(MinigameService.Current(Player), Id, ("step %d: %s is open"):format(Step, Id))
	local Answer = MinigameService.Solve(Player)
	T.True(Answer ~= nil, ("step %d: the server solves %s"):format(Step, Id))
	T.True(type(MinigameService.Submit) == "function", ("step %d: MinigameService.Submit (the remote's own path) is public"):format(Step))
	MinigameService.Submit(Player, Answer)
	T.Eq(MinigameService.Current(Player), nil, ("step %d: %s passed and closed"):format(Step, Id))
end

local Suite = {}

function Suite.AcqMetalFromFoundry(T)
	local DialogueService = require(SSS.DialogueService)
	local Investigation = require(SSS.InvestigationService)
	local PuzzleService = require(SSS.PuzzleService)
	local MinigameService = require(SSS.MinigameService)
	local TrialService = require(SSS.TrialService)
	local TravelService = require(SSS.TravelService)
	local DownedManager = require(ReplicatedStorage.Modules.Managers.DownedManager)
	local Puzzles = require(Rensei.Puzzles)
	T.Eq(TravelService.Here(), "Foundry", "TravelService.Here()")
	local Model = Brannoc()
	T.True(Model ~= nil, "Brannoc (DialogueId trainer_metal) in workspace")
	Guarded(T, function(Player, Data, C, Root)
		-- 1. Brannoc sends the player
		TestKit.Beside(Player, Model, function()
			T.Eq(DialogueService.Open(Player, Model), true, "step 1: the conversation opens")
			T.Eq(DialogueService.Choose(Player, 1), true, "step 1: \"Teach me.\"")
			T.Eq(DialogueService.Choose(Player, 1), true, "step 1: \"I'll go.\"")
			DialogueService.Close(Player)
		end)
		T.True(Data.Quests.Active[QUEST] ~= nil, "step 1: acq_metal is Active")
		Expect(T, Data, 1, "invite") -- (the travel stage is already done: the player is in the Foundry)

		-- 2. the Silent Forge, discovered by WorldService
		local Rooms = workspace.World.Map.Foundry:FindFirstChild("ForgeRooms")
		local Floor = workspace.World.Map.Foundry.Landmarks.GreatHall_great_hall:FindFirstChild("SilentForgeFloor")
		T.True(Floor ~= nil, "step 2: GreatHall_great_hall.SilentForgeFloor")
		Hold(Root, C, CFrame.new(Floor.Position + Vector3.new(0, 3, 4)))
		local T0 = os.clock()
		while StageId(Data) == "invite" and os.clock() - T0 < DISCOVER_WAIT do task.wait(0.1) end
		Expect(T, Data, 2, "fieldwork")

		-- 3. the four inspects, then the board
		for _, Id in ipairs(INSPECTS) do
			local Part = OneTagged(T, "RenseiInspect", "InspectId", Id)
			T.True(Rooms ~= nil and Part:IsDescendantOf(Rooms), "step 3: " .. Id .. " is in ForgeRooms")
			local Me = SmokeKit.Stand(Player, Part.Position)
			T.True((Me.Position - Part.Position).Magnitude <= 9, "step 3: within 9 studs of " .. Id)
			T.Eq(Investigation.Inspect(Player, Id, Part), true, "step 3: " .. Id .. " inspected")
		end
		local Ok, Text = Investigation.Deduce(Player, "forge_failure", PICKS)
		T.Eq(Ok, true, "step 3: the forge_failure deduction (" .. tostring(Text) .. ")")
		Expect(T, Data, 3, "experiment")

		-- 4. the experiment: the bench's prompt handler, as PuzzleService runs it
		local Bench = OneTagged(T, "RenseiMechanism", "MechanismId", BENCH)
		T.True(Bench:FindFirstChild("MechanismPrompt") ~= nil, "step 4: PuzzleService attached the bench's MechanismPrompt") -- (Ruling 39)
		local P = Puzzles.Mechanisms[BENCH].Prompt
		T.Eq(P.Minigame, "metal_match", "step 4: the bench's prompt opens metal_match")
		local Me = SmokeKit.Stand(Player, Bench.Position)
		T.True((Bench.Position - Me.Position).Magnitude <= 12, "step 4: within the handler's 12 studs of the bench")
		T.True(not C:GetAttribute("InCombat"), "step 4: not in combat")
		T.True(PuzzleService.StateOf(Player, BENCH) ~= P.PassState, "step 4: the bench isn't " .. P.PassState .. " yet")
		T.Eq(MinigameService.Open(Player, P.Minigame, {Mechanism = P.Target, PassState = P.PassState}), true, "step 4: metal_match opens")
		SolveAndSubmit(T, Player, "metal_match", 4)
		Expect(T, Data, 4, "trial")
		T.Eq(PuzzleService.StateOf(Player, BENCH), P.PassState, "step 4: the bench is " .. P.PassState)

		-- 5. the trial
		local Marker = OneTagged(T, "RenseiTrial", "TrialId", TRIAL)
		Hold(Root, C, CFrame.lookAt(Marker.Position + Vector3.new(0, 3, 3), Marker.Position + Vector3.new(0, 3, 0)))
		local Began, Why = TrialService.Begin(Player, TRIAL)
		T.Eq(Began, true, "step 5: TrialService.Begin (" .. tostring(Why) .. ")")
		local Run
		for _, R in pairs(TrialService.Runs) do if R.Player == Player then Run = R end end
		local Foe = Run and Run.Foe
		local Hum = Foe and Foe:FindFirstChildOfClass("Humanoid")
		T.True(Hum ~= nil, "step 5: the trial's foe")
		T0 = os.clock()
		while not (Foe:GetAttribute("Knocked") or Hum.Health <= 0) and os.clock() - T0 < KNOCK_WAIT do
			DownedManager.Damage(Foe, Hum.MaxHealth)
			task.wait(0.2)
		end
		T.True(Foe:GetAttribute("Knocked") or Hum.Health <= 0, "step 5: the foe is knocked or dead")
		T0 = os.clock()
		while TrialService.InRun(Player) and os.clock() - T0 < END_WAIT do task.wait(0.1) end
		T.Eq(TrialService.InRun(Player), false, "step 5: the run ended")
		T.True(Data.Story.Flags["Trial_" .. TRIAL] ~= nil, "step 5: TrialService set Trial_" .. TRIAL)
		Expect(T, Data, 5, "exam")

		-- 6. the exam, from the conversation
		T0 = os.clock()
		while C:GetAttribute("InCombat") and os.clock() - T0 < CALM_WAIT do task.wait(0.25) end
		T.True(not C:GetAttribute("InCombat"), "step 6: out of combat")
		TestKit.Beside(Player, Model, function()
			T.Eq(DialogueService.Open(Player, Model), true, "step 6: the conversation opens")
			T.Eq(DialogueService.Choose(Player, 1), true, "step 6: \"I'm ready for the examination.\"")
			SolveAndSubmit(T, Player, "metal_exam", 6)
		end)
		Expect(T, Data, 6, "recognition") -- the exam is passed (recognition isn't run)
		print(("[FoundryData] AcqMetalFromFoundry: Brannoc -> invite -> fieldwork -> experiment -> trial -> exam -> recognition; the trial's foe at %s")
			:format(Foe.Parent and f1(Foe:GetPivot().Position) or "(cleared)"))
	end)
end

function Suite.AcqMetalFromYeSave(T)
	local DialogueService = require(SSS.DialogueService)
	local QuestService = require(SSS.QuestService)
	local UIService = require(SSS.UIService)
	local Dialogues = require(Rensei.Dialogues)
	local Model = Brannoc()
	T.True(Model ~= nil, "Brannoc in workspace")
	Guarded(T, function(Player, Data)
		Data.Quests.Active[QUEST] = {Stage = 3, Progress = {}} -- (a save from Ye, before the travel stage: no Revision)
		T.Eq(QuestService.UpgradeAll(Data), true, "UpgradeAll moves the old save")
		Expect(T, Data, 0, "experiment")
		T.Eq(Data.Quests.Active[QUEST].Stage, 4, "old stage 3 is stage 4")
		-- the text the dialogue box is sent on Open
		local Sent
		local Real = UIService.Notify
		UIService.Notify = function(P, Kind, Payload)
			if P == Player and Kind == "Dialogue" then Sent = Payload and Payload.Text end
			return Real(P, Kind, Payload)
		end
		local Ok, Err = pcall(function()
			TestKit.Beside(Player, Model, function()
				T.Eq(DialogueService.Open(Player, Model), true, "the conversation opens")
				DialogueService.Close(Player)
			end)
		end)
		UIService.Notify = Real
		if not Ok then error(Err, 0) end
		T.Eq(Sent, Dialogues.trainer_metal.Nodes.experiment.Text, "Brannoc opens on his experiment node")
	end)
end

return Suite

-- Play_Exams (Region Foundation Task 1, 2026-10-23): the five alchemy trainers' examinations open from the
-- conversation. Run inside the game VM (LMRunSuite) with the Play client connected, inside the snapshot / restore
-- runner (Conventions §S).
-- For each exam: the acquisition quest on its exam stage (Act V) and no saved path, the player beside the trainer. Open
-- the conversation (DialogueService.Open, as the Talk prompt does), take the exam choice through
-- DialogueService.Choose (the function the Dialogue remote calls), then check:
--   * the conversation was already closed when the minigame opened (the client's UIState refuses a menu over an
--     open conversation, so the panel closed at once and the server cancelled the exam);
--   * a moment later the exam is still running (the client kept the panel instead of sending "Close").
-- Quest state, the saved path and the character's position are put back after each test.
-- Foundry data plan Task 3 (2026-10-24): the exam stage is read by id (StoryLogic.StageIndex), since acq_metal gained a
-- travel stage; the fixture state carries the quest's Revision (a state without it is stale and on no stage, Ruling
-- 22). Each trainer is tested in the place that has them (WHERE, against TravelService.Here()); in any other place the
-- test checks that no model with that trainer's DialogueId is in the workspace (the trainer moved away).
local SSS = game.ServerScriptService
local DialogueService = require(SSS.DialogueService)
local MinigameService = require(SSS.MinigameService)
local PS = require(SSS.ProgressionService)
local TravelService = require(SSS.TravelService)
local StoryLogic = require(game.ReplicatedStorage.Modules.Data.Rensei.StoryLogic)
local Quests = require(game.ReplicatedStorage.Modules.Data.Rensei.Quests)
local Player = game.Players:GetPlayers()[1]

-- where each trainer teaches (a region id, TravelService.Here())
local WHERE = {flame = "Lindenmoor", ice = "Lindenmoor", earth = "Lindenmoor", wind = "Lindenmoor", metal = "Foundry"}

local function Copy(V)
	if type(V) ~= "table" then return V end
	local R = {}
	for K, X in pairs(V) do R[K] = Copy(X) end
	return R
end

local function Trainer(Id)
	for _, D in ipairs(workspace:GetDescendants()) do
		if D:IsA("Model") and D:GetAttribute("DialogueId") == Id then return D end
	end
end

local function ExamOpens(T, Path)
	local Exam, Quest = Path .. "_exam", "acq_" .. Path
	local Data = PS.GetData(Player)
	local Character = Player.Character
	T.True(Data ~= nil and Character ~= nil and Character:FindFirstChild("HumanoidRootPart") ~= nil, "a player with a save and a character")
	local Model = Trainer("trainer_" .. Path)
	T.True(Model ~= nil, "trainer_" .. Path .. " is in the world")

	local OldQuests = Copy(Data.Quests)
	Data.Identity = Data.Identity or {}
	local OldAffinity = Data.Identity.Affinity
	local OldPivot = Character:GetPivot()
	local RealOpen = MinigameService.Open
	local Opened, TalkOpenThen
	local Ok, Err = pcall(function()
		-- Act V of the questline. Set directly: QuestService has no stage setter, and Start's catch-up could run a
		-- finished questline forward and pay its rewards again on a save that already passed it.
		Data.Identity.Affinity = "" -- with a saved path the trainers open on their mentor / other-path lines instead
		Data.Quests.Completed[Quest] = nil
		local Stage = StoryLogic.StageIndex(Quests[Quest], "exam")
		T.True(Stage ~= nil, Quest .. " has an exam stage")
		Data.Quests.Active[Quest] = {Stage = Stage, Progress = {}, Started = os.time(), Revision = Quests[Quest].Revision}
		-- beside the trainer: DialogueService needs 16 studs, MinigameService 22
		local At = Model:GetPivot().Position + Vector3.new(-6, 0, 0)
		Character:PivotTo(CFrame.lookAt(At, Model:GetPivot().Position))
		MinigameService.Open = function(P, Id, Context)
			if P == Player then Opened, TalkOpenThen = Id, DialogueService.IsOpen(P) end
			return RealOpen(P, Id, Context)
		end
		T.True(DialogueService.Open(Player, Model), "the conversation opened")
		T.True(DialogueService.Choose(Player, 1), "the exam choice was taken")
		MinigameService.Open = RealOpen
		T.Eq(Opened, Exam, "the exam choice opened the exam")
		T.Eq(TalkOpenThen, false, "the conversation was closed before the exam opened")
		T.Eq(DialogueService.IsOpen(Player), false, "no conversation left open")
		task.wait(1.5) -- the client answers: a panel it can't show closes at once and the server cancels the exam
		T.Eq(MinigameService.Current(Player), Exam, "the exam is still running a moment later")
	end)
	MinigameService.Open = RealOpen
	pcall(function()
		if MinigameService.Current(Player) then MinigameService.Cancel(Player, "Test over.") end -- "Done" closes the panel
		DialogueService.Close(Player)
	end)
	pcall(function()
		for K in pairs(Data.Quests) do if OldQuests[K] == nil then Data.Quests[K] = nil end end
		for K, V in pairs(OldQuests) do Data.Quests[K] = V end
		Data.Identity.Affinity = OldAffinity
		PS.Sync(Player)
		Character:PivotTo(OldPivot)
	end)
	task.wait(1.6) -- let the client's panel close before the next exam
	if not Ok then error(Err, 0) end
end

-- the exam where the trainer teaches; elsewhere, the trainer is not in this place's world
local function ExamOrMovedAway(T, Path)
	local Here = TravelService.Here()
	if WHERE[Path] == Here then return ExamOpens(T, Path) end
	T.Eq(Trainer("trainer_" .. Path), nil, "trainer_" .. Path .. " teaches in " .. WHERE[Path] .. ", not here (" .. tostring(Here) .. ")")
end

return {
	FlameExamOpens = function(T) ExamOrMovedAway(T, "flame") end,
	IceExamOpens = function(T) ExamOrMovedAway(T, "ice") end,
	EarthExamOpens = function(T) ExamOrMovedAway(T, "earth") end,
	WindExamOpens = function(T) ExamOrMovedAway(T, "wind") end,
	MetalExamOpens = function(T) ExamOrMovedAway(T, "metal") end,
}

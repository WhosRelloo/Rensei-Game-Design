-- Play_Exams (Region Foundation Task 1, 2026-10-23): the five alchemy trainers' examinations open from the
-- conversation. Run inside the game VM (LMRunSuite) with the Play client connected, inside the snapshot / restore
-- runner (Conventions §S).
-- For each exam: the acquisition quest at stage 5 (Act V) and no saved path, the player beside the trainer. Open
-- the conversation (DialogueService.Open, as the Talk prompt does), take the exam choice through
-- DialogueService.Choose (the function the Dialogue remote calls), then check:
--   * the conversation was already closed when the minigame opened (the client's UIState refuses a menu over an
--     open conversation, so the panel closed at once and the server cancelled the exam);
--   * a moment later the exam is still running (the client kept the panel instead of sending "Close").
-- Quest state, the saved path and the character's position are put back after each test.
local SSS = game.ServerScriptService
local DialogueService = require(SSS.DialogueService)
local MinigameService = require(SSS.MinigameService)
local PS = require(SSS.ProgressionService)
local Player = game.Players:GetPlayers()[1]

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
		Data.Quests.Active[Quest] = {Stage = 5, Progress = {}, Started = os.time()}
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

return {
	FlameExamOpens = function(T) ExamOpens(T, "flame") end,
	IceExamOpens = function(T) ExamOpens(T, "ice") end,
	EarthExamOpens = function(T) ExamOpens(T, "earth") end,
	WindExamOpens = function(T) ExamOpens(T, "wind") end,
	MetalExamOpens = function(T) ExamOpens(T, "metal") end,
}

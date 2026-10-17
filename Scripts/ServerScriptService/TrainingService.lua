-- TrainingService: practice with an alchemy trainer after acquisition (Rensei.Training).
--   Lesson(Player, Id): opens the lesson's exam-grade minigame (MinigameService, Context.Lesson); a pass
--     (OnLessonPassed, called by MinigameService) pays ProgressionService.AddTraining once per day.
--   Exercise(Player, Id): a timed drill. The server plays the animation and checks every 0.5s that the
--     player is alive, out of combat and still within 2.5 studs of where they started; finishing pays
--     AddTraining, PerDay times a day.
-- Daily counts live in Story.Flags ("Lesson_<Id>" / "Exercise_<Id>" = "<day>:<count>", day = UTC day
-- number), so they survive a rejoin. All payouts go through AddTraining: the stage's 20 MP cap and the
-- Truth/Gate stay in force, and its per-source hourly allowance throttles grinding.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Defs = require(ReplicatedStorage.Modules.Data.Rensei.Training)
local StoryLogic = require(ReplicatedStorage.Modules.Data.Rensei.StoryLogic)
local ProgressionService = require(ServerScriptService.ProgressionService)
local UIService = require(ServerScriptService.UIService)

local TrainingService = {}
local Busy = {} -- [Player] = true while an exercise runs

local function Toast(Player, Text) UIService.Notify(Player, "Toast", {Text = Text}) end
local function Today() return math.floor(os.time() / 86400) end

local function Count(Data, Key)
	local V = (Data.Story.Flags or {})[Key]
	if type(V) ~= "string" then return 0 end
	local Day, N = V:match("^(%d+):(%d+)$")
	if tonumber(Day) ~= Today() then return 0 end
	return tonumber(N) or 0
end

local function Bump(Player, Key, Data)
	local N = Count(Data, Key) + 1
	require(ServerScriptService.StoryService).SetFlag(Player, Key, Today() .. ":" .. N, true)
	return N
end

local function Check(Player, Def, Key)
	local Data = ProgressionService.GetData(Player)
	if not Data then return nil, "Your data isn't loaded yet." end
	if not StoryLogic.Meets(Def.Requires, Data, Player) then return nil, "This trainer only teaches their own students." end
	if Count(Data, Key) >= (Def.PerDay or 1) then return nil, "That's enough of that for today. Come back tomorrow." end
	return Data
end

-- The stage is full: until the Truth/Gate trial, no practice pays (and nothing is used up).
local function StageFull(Data)
	local Progression = require(ReplicatedStorage.Modules.Data.Rensei.Progression)
	return Data.Mastery.StageEarned >= Progression.MasteryPerStage
end
local GATE_LINE = "You've learned all you can at this stage. Only the Gate opens the next."

-- Pays the practice. Active: the player was doing something the whole time (a lesson, a drill), so
-- AddTraining's idle check is skipped -- the stage cap and the Gate still apply. Returns the TP paid.
local function Pay(Player, Data, Def, Key)
	if StageFull(Data) then Toast(Player, GATE_LINE) return 0 end
	local Amount = ProgressionService.AddTraining(Player, Def.Source, Def.Mult or 1, true)
	if Amount > 0 then
		Bump(Player, Key, Data) -- a use only counts when it paid
		if Def.Done then Toast(Player, Def.Done) end
	end
	ProgressionService.Sync(Player)
	return Amount
end

function TrainingService.Lesson(Player, Id)
	local Def = Defs.Lessons[Id]
	if not Def then return false end
	local Data, Why = Check(Player, Def, "Lesson_" .. Id)
	if not Data then Toast(Player, Why) return false end
	if StageFull(Data) then Toast(Player, GATE_LINE) return false end
	return require(ServerScriptService.MinigameService).Open(Player, Def.Minigame, {Lesson = Id})
end

-- MinigameService calls this on a pass whose Context names a lesson.
function TrainingService.OnLessonPassed(Player, Id)
	local Def = Defs.Lessons[Id]
	if not Def then return end
	local Data = Check(Player, Def, "Lesson_" .. Id)
	if not Data then return end -- (already paid today: the pass still counts as practice, but pays nothing)
	Pay(Player, Data, Def, "Lesson_" .. Id)
end

function TrainingService.Exercise(Player, Id)
	local Def = Defs.Exercises[Id]
	if not Def or Busy[Player] then return false end
	local Data, Why = Check(Player, Def, "Exercise_" .. Id)
	if not Data then Toast(Player, Why) return false end
	if StageFull(Data) then Toast(Player, GATE_LINE) return false end
	local Character = Player.Character
	local Root = Character and Character:FindFirstChild("HumanoidRootPart")
	local Hum = Character and Character:FindFirstChildOfClass("Humanoid")
	if not Root or not Hum or Hum.Health <= 0 or Character:GetAttribute("Knocked") then return false end
	if Character:GetAttribute("InCombat") or Character:GetAttribute("CombatMode") then
		Toast(Player, "Not in combat.")
		return false
	end
	Busy[Player] = true
	local AnimationManager = require(ReplicatedStorage.Modules.Managers.AnimationManager)
	local Start = Root.Position
	if Def.Start then Toast(Player, Def.Start) end
	AnimationManager.Play(Character, Def.Anim, {Looped = true, Priority = Enum.AnimationPriority.Action})
	local Ok = true
	local Until = os.clock() + Def.Seconds
	while os.clock() < Until do
		task.wait(0.5)
		local R = Character.Parent and Character:FindFirstChild("HumanoidRootPart")
		if not Player.Parent or Player.Character ~= Character or not R or Hum.Health <= 0
			or Character:GetAttribute("Knocked") or Character:GetAttribute("InCombat") or Character:GetAttribute("CombatMode")
			or (R.Position - Start).Magnitude > 2.5 then
			Ok = false
			break
		end
	end
	if Character.Parent then AnimationManager.Stop(Character, Def.Anim) end
	Busy[Player] = nil
	if not Ok then
		if Player.Parent then Toast(Player, "You broke off. Start again when you're ready.") end
		return false
	end
	return Pay(Player, Data, Def, "Exercise_" .. Id) > 0
end

function TrainingService.Start()
	Players.PlayerRemoving:Connect(function(P) Busy[P] = nil end)
end

return TrainingService

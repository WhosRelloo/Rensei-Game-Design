-- InvestigationService: inspect points and the Case Board (Rensei.Investigation).
--   Inspect: any BasePart / Model tagged "RenseiInspect" with attribute InspectId gets an "Inspect"
--     prompt. The server checks distance, shows the text in the dialogue box (DialogueService.Say),
--     and gives the evidence when its Requires pass. Signals "Inspect" for quests.
--   Deduce: Requests.Investigation("Deduce", Id, Answers) with Answers[slot] = evidence id. Only
--     evidence the player holds counts; a wrong answer costs nothing (fair, recoverable).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")

local Content = require(ReplicatedStorage.Modules.Data.Rensei.Investigation)
local StoryLogic = require(ReplicatedStorage.Modules.Data.Rensei.StoryLogic)
local ProgressionService = require(ServerScriptService.ProgressionService)
local StoryService = require(ServerScriptService.StoryService)
local QuestService = require(ServerScriptService.QuestService)
local UIService = require(ServerScriptService.UIService)

local TAG = "RenseiInspect"
local MAX_DISTANCE = 14

local InvestigationService = {}

local function PartOf(Inst)
	if Inst:IsA("BasePart") then return Inst end
	if Inst:IsA("Model") then return Inst.PrimaryPart or Inst:FindFirstChildWhichIsA("BasePart", true) end
end

function InvestigationService.Inspect(Player, Id, Inst)
	local Def = Content.Inspects[Id]
	local Part = Inst and PartOf(Inst)
	local Root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
	if not Def or not Part or not Root then return false end
	if (Part.Position - Root.Position).Magnitude > MAX_DISTANCE then return false end
	local Data = ProgressionService.GetData(Player)
	if not Data then return false end

	local Text = Def.Text
	if Def.Evidence then
		if Data.Story.Evidence[Def.Evidence] then
			Text = Def.AfterText or Def.Text
		elseif StoryLogic.Meets(Def.Requires, Data, Player) then
			StoryService.GiveEvidence(Player, Def.Evidence)
		else
			Text = Def.Locked or Def.Text
		end
	end
	require(ServerScriptService.DialogueService).Say(Player, Part, Def.Title or "Inspect", Text)
	QuestService.Signal(Player, "Inspect", Id)
	return true
end

-- Answers = {[slot index] = evidence id}. Returns ok, text.
function InvestigationService.Deduce(Player, Id, Answers)
	local Def = Content.Deductions[Id]
	local Data = ProgressionService.GetData(Player)
	if not Def or not Data or type(Answers) ~= "table" then return false, "Bad request" end
	if Data.Story.Deductions[Id] then return true, Def.Conclusion end
	if not StoryLogic.Meets(Def.Requires, Data, Player) then return false, "You don't have enough to go on yet." end
	for I, Slot in ipairs(Def.Slots) do
		local Given = Answers[I] or Answers[tostring(I)]
		if type(Given) ~= "string" or not Data.Story.Evidence[Given] or Given ~= Slot.Answer then
			return false, Def.Wrong or "That doesn't hold together."
		end
	end
	StoryService.GiveDeduction(Player, Id, Def.Title)
	return true, Def.Conclusion
end

local Attached = {} -- [Instance] = true (plain table: ARCHITECTURE.md rule), cleared on Destroying
local function Attach(Inst)
	if Attached[Inst] or not CollectionService:HasTag(Inst, TAG) then return end
	local Id = Inst:GetAttribute("InspectId")
	local Part = PartOf(Inst)
	if type(Id) ~= "string" or not Part or not Content.Inspects[Id] then
		warn("InvestigationService: inspect point", Inst:GetFullName(), "has unknown InspectId", Id)
		return
	end
	Attached[Inst] = true
	Inst.Destroying:Once(function() Attached[Inst] = nil end)
	local Prompt = Instance.new("ProximityPrompt")
	Prompt.Name = "InspectPrompt"
	Prompt.ActionText = "Inspect"
	Prompt.ObjectText = Content.Inspects[Id].Title or ""
	Prompt.MaxActivationDistance = 9
	Prompt.RequiresLineOfSight = false
	Prompt.Style = Enum.ProximityPromptStyle.Custom -- drawn by Modules.UI.PromptUI
	Prompt.Parent = Part
	Prompt.Triggered:Connect(function(Player) InvestigationService.Inspect(Player, Id, Inst) end)
end

function InvestigationService.Start()
	for _, Inst in ipairs(CollectionService:GetTagged(TAG)) do Attach(Inst) end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(Inst) task.defer(Attach, Inst) end)
end

return InvestigationService

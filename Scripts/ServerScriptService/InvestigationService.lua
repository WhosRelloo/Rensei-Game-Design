-- InvestigationService: inspect points and the Case Board (Rensei.Investigation).
--   Inspect: any BasePart / Model tagged "RenseiInspect" with attribute InspectId gets an "Inspect"
--     prompt. The server checks distance, shows the text in the dialogue box (DialogueService.Say),
--     and gives the evidence when its Requires pass. Signals "Inspect" for quests.
--   Clues (Region Foundation, 2026-10-23): a part tagged "RenseiClue" with attribute ClueId (the region maps' Blender
--     "markers" stage) is made an inspect point: it gets the RenseiInspect tag and InspectId = ClueId (ClueId wins
--     over an InspectId it already carries).
--   StartsQuest: an inspect def's StartsQuest quest starts after an inspect whose Requires pass (so never a Locked
--     one, and a no-Evidence def's Requires gates it too), if QuestService.CanStart allows.
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
local CLUE_TAG = "RenseiClue"
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
	local Met = StoryLogic.Meets(Def.Requires, Data, Player)
	if Def.Evidence then
		if Data.Story.Evidence[Def.Evidence] then
			Text = Def.AfterText or Def.Text
		elseif Met then
			StoryService.GiveEvidence(Player, Def.Evidence)
		else
			Text = Def.Locked or Def.Text
		end
	end
	require(ServerScriptService.DialogueService).Say(Player, Part, Def.Title or "Inspect", Text)
	-- after the evidence (the new quest's CatchUp counts it) and before the Inspect signal (its Inspect objectives count);
	-- a failed Requires (a Locked inspect, or a no-Evidence def's Requires) never starts it
	if Met and Def.StartsQuest and QuestService.CanStart(Player, Def.StartsQuest) then
		local Ok, Err = pcall(QuestService.Start, Player, Def.StartsQuest)
		if not Ok then warn("InvestigationService: starting", Def.StartsQuest, "from", Id, "failed:", Err) end
	end
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
	-- a clue marker's ClueId wins, whichever tag's added signal arrives first
	local Clue = CollectionService:HasTag(Inst, CLUE_TAG) and Inst:GetAttribute("ClueId")
	if type(Clue) == "string" then Inst:SetAttribute("InspectId", Clue) end
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

-- a clue marker becomes an inspect point. Attach directly: on an instance that already had TAG, AddTag fires nothing
local function MapClue(Inst)
	local Id = Inst:GetAttribute("ClueId")
	if type(Id) ~= "string" then
		warn("InvestigationService: clue", Inst:GetFullName(), "has no ClueId")
		return
	end
	Inst:SetAttribute("InspectId", Id)
	CollectionService:AddTag(Inst, TAG)
	Attach(Inst)
end

-- Start's first pass: the clue markers and inspect points already in the place (an imported region map's clues)
function InvestigationService.Scan()
	for _, Inst in ipairs(CollectionService:GetTagged(CLUE_TAG)) do MapClue(Inst) end
	for _, Inst in ipairs(CollectionService:GetTagged(TAG)) do Attach(Inst) end
end

function InvestigationService.Start()
	InvestigationService.Scan()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(Inst) task.defer(Attach, Inst) end)
	CollectionService:GetInstanceAddedSignal(CLUE_TAG):Connect(function(Inst) task.defer(MapClue, Inst) end)
end

return InvestigationService

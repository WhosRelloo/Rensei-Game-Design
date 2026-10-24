-- Play_Clue (Region Foundation Task 7, 2026-10-23): region-map clue markers are inspect points, and an inspect def's
-- StartsQuest starts that quest. Run inside the game VM (LMRunSuite) with the Play client connected, inside the
-- snapshot / restore runner (Conventions §S).
-- Fixture: a test inspect def, a test evidence def and a one-stage test quest are injected into the live content
-- tables. A part tagged RenseiClue with ClueId (what the Blender "markers" stage emits) is made 5 studs in front of
-- the player; InvestigationService must tag it RenseiInspect with InspectId = ClueId and give it the Inspect prompt.
-- The inspect handler is then called as the prompt's Triggered does. The quest's second objective (a flag no one
-- sets) keeps the quest active, so its Evidence objective can be checked as filled in by CatchUp.
-- Also: a Locked inspect (Requires failed) of a clue with the same StartsQuest must not start the quest.
-- Every injected def, the parts, the evidence and the quest state are removed afterwards.
local SSS = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local Modules = game.ReplicatedStorage.Modules.Data.Rensei
local InvestigationService = require(SSS.InvestigationService)
local QuestService = require(SSS.QuestService)
local DialogueService = require(SSS.DialogueService)
local PS = require(SSS.ProgressionService)
local Content = require(Modules.Investigation)
local EvidenceDefs = require(Modules.Evidence)
local Quests = require(Modules.Quests)
local Player = game.Players:GetPlayers()[1]

local QUEST = "test_clue_quest"

local function Clue(Root, Id, Offset)
	local Part = Instance.new("Part")
	Part.Name = "TestClue_" .. Id
	Part.Size = Vector3.new(1, 1, 1)
	Part.Anchored = true
	Part.CanCollide = false
	Part.Transparency = 1
	Part.CFrame = Root.CFrame * CFrame.new(Offset, 0, -5)
	Part:SetAttribute("ClueId", Id)
	CollectionService:AddTag(Part, "RenseiClue")
	Part.Parent = workspace
	return Part
end

local function Prompted(Part)
	local T0 = os.clock()
	repeat task.wait(0.1) until Part:FindFirstChild("InspectPrompt") or os.clock() - T0 > 3
	return Part:FindFirstChild("InspectPrompt") ~= nil
end

return {
	ClueStartsQuest = function(T)
		local Data = PS.GetData(Player)
		local Root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
		T.True(Data ~= nil and Root ~= nil, "a player with a save and a character")
		local OldTracked = Data.Quests.Tracked
		local Parts = {}
		local Ok, Err = pcall(function()
			Content.Inspects.test_clue = {Title = "Ledger", Text = "Lines scratched out.", Evidence = "test_ev", StartsQuest = QUEST}
			Content.Inspects.test_clue_locked = {Title = "Locked Ledger", Text = "Lines scratched out.", Evidence = "test_ev_locked",
				Requires = {Flag = "test_clue_never"}, Locked = "A ledger behind bars.", StartsQuest = QUEST}
			EvidenceDefs.test_ev = {Title = "Test Evidence", Text = "Scratched-out lines."}
			EvidenceDefs.test_ev_locked = {Title = "Test Locked Evidence", Text = "Behind bars."}
			Quests[QUEST] = {Title = "Test Clue Quest", Stages = {
				{Id = "s1", Text = "Follow the ledger.", Objectives = {
					{Id = "o1", Text = "Read the ledger", Kind = "Evidence", Target = "test_ev"},
					{Id = "o2", Text = "Never done", Kind = "Flag", Target = "test_clue_never"},
				}},
			}}
			Data.Story.Evidence.test_ev = nil
			Data.Story.Evidence.test_ev_locked = nil
			Data.Story.Flags.test_clue_never = nil
			Data.Quests.Active[QUEST] = nil
			Data.Quests.Completed[QUEST] = nil

			-- a Locked inspect (Requires failed) does not start the quest
			local Locked = Clue(Root, "test_clue_locked", 2)
			table.insert(Parts, Locked)
			T.True(Prompted(Locked), "the locked clue got an Inspect prompt")
			T.True(InvestigationService.Inspect(Player, Locked:GetAttribute("InspectId"), Locked), "the locked clue was inspected")
			T.True(Data.Story.Evidence.test_ev_locked == nil, "no evidence from a locked clue")
			T.True(Data.Quests.Active[QUEST] == nil, "a locked clue doesn't start the quest")

			-- the clue marker becomes an inspect point
			local Part = Clue(Root, "test_clue", 0)
			table.insert(Parts, Part)
			T.True(Prompted(Part), "the clue got an Inspect prompt")
			T.True(CollectionService:HasTag(Part, "RenseiInspect"), "the clue is tagged RenseiInspect")
			T.Eq(Part:GetAttribute("InspectId"), "test_clue", "InspectId = ClueId")

			-- inspecting it (as the prompt does) gives the evidence and starts the quest, the objective caught up
			T.True(InvestigationService.Inspect(Player, Part:GetAttribute("InspectId"), Part), "the clue was inspected")
			T.True(Data.Story.Evidence.test_ev ~= nil, "the player holds the evidence")
			local State = Data.Quests.Active[QUEST]
			T.True(State ~= nil, "the quest is active")
			T.Eq(State.Stage, 1, "on its one stage")
			T.Eq(State.Progress.o1, 1, "the Evidence objective is already done (CatchUp)")
			T.Eq(State.Progress.o2, 0, "the other objective is not")
		end)
		pcall(function() DialogueService.Close(Player) end)
		pcall(function()
			for _, P in ipairs(Parts) do P:Destroy() end
			Content.Inspects.test_clue = nil
			Content.Inspects.test_clue_locked = nil
			EvidenceDefs.test_ev = nil
			EvidenceDefs.test_ev_locked = nil
			Quests[QUEST] = nil
			Data.Story.Evidence.test_ev = nil
			Data.Story.Evidence.test_ev_locked = nil
			Data.Quests.Active[QUEST] = nil
			Data.Quests.Completed[QUEST] = nil
			Data.Quests.Tracked = OldTracked
			PS.Sync(Player)
		end)
		if not Ok then error(Err, 0) end
	end,
}

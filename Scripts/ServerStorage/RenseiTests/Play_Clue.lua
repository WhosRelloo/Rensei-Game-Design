-- Play_Clue (Region Foundation Task 7, 2026-10-23; fix round 1): region-map clue markers are inspect points, and an
-- inspect def's StartsQuest starts that quest. Run inside the game VM (LMRunSuite) with the Play client connected,
-- inside the snapshot / restore runner (Conventions §S).
-- Fixture: test inspect defs, test evidence defs and a one-stage test quest are injected into the live content
-- tables. Parts tagged RenseiClue with ClueId (what the Blender "markers" stage emits) are made 5 studs in front of
-- the player. The inspect handler is called as the prompt's Triggered does. The quest's second objective (a flag no
-- one sets) keeps the quest active, so its Evidence objective can be checked as filled in by CatchUp.
--   * signal path (a clue added after Start): a Locked inspect and a no-Evidence def whose Requires fail don't start
--     the quest; a part tagged both RenseiInspect and RenseiClue with a different InspectId gets ClueId.
--   * Start path (a clue already in the place, an imported region map): the part is parented and, before the
--     thread yields (so the deferred added-signal handler hasn't run), InvestigationService.Scan() - the pass
--     Start() runs first - must map it and give it the prompt.
--   * a repeat inspect doesn't restart the active quest and toasts nothing; once the quest is gone from Active, an
--     AfterText inspect starts it again, the objective caught up.
-- Every injected def, the parts, the evidence and the quest state are removed afterwards.
local SSS = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local Modules = game.ReplicatedStorage.Modules.Data.Rensei

local QUEST = "test_clue_quest"

local function Clue(Root, Id, Offset, Extra)
	local Part = Instance.new("Part")
	Part.Name = "TestClue_" .. Id
	Part.Size = Vector3.new(1, 1, 1)
	Part.Anchored = true
	Part.CanCollide = false
	Part.Transparency = 1
	Part.CFrame = Root.CFrame * CFrame.new(Offset, 0, -5)
	Part:SetAttribute("ClueId", Id)
	CollectionService:AddTag(Part, "RenseiClue")
	if Extra then Extra(Part) end
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
		local InvestigationService = require(SSS.InvestigationService)
		local DialogueService = require(SSS.DialogueService)
		local UIService = require(SSS.UIService)
		local PS = require(SSS.ProgressionService)
		local Content = require(Modules.Investigation)
		local EvidenceDefs = require(Modules.Evidence)
		local Quests = require(Modules.Quests)
		local Player = game.Players:GetPlayers()[1]
		T.True(Player ~= nil, "a player in the game")
		local Data = PS.GetData(Player)
		T.True(type(Data) == "table" and type(Data.Story) == "table" and type(Data.Quests) == "table", "the player's save is loaded")
		local Root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
		T.True(Root ~= nil, "the player has a character")

		local OldTracked = Data.Quests.Tracked
		local RealNotify = UIService.Notify
		local Parts = {}
		local Ok, Err = pcall(function()
			Content.Inspects.test_clue = {Title = "Ledger", Text = "Lines scratched out.", Evidence = "test_ev", StartsQuest = QUEST}
			Content.Inspects.test_clue_locked = {Title = "Locked Ledger", Text = "Lines scratched out.", Evidence = "test_ev_locked",
				Requires = {Flag = "test_clue_never"}, Locked = "A ledger behind bars.", StartsQuest = QUEST}
			Content.Inspects.test_clue_noev = {Title = "Notice", Text = "A notice.", Requires = {Flag = "test_clue_never"}, StartsQuest = QUEST}
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

			-- a no-Evidence def whose Requires fail does not start it either. The part is tagged both ways with a
			-- different InspectId: ClueId wins
			local NoEv = Clue(Root, "test_clue_noev", -2, function(P)
				P:SetAttribute("InspectId", "test_clue")
				CollectionService:AddTag(P, "RenseiInspect")
			end)
			table.insert(Parts, NoEv)
			T.True(Prompted(NoEv), "the double-tagged clue got an Inspect prompt")
			T.Eq(NoEv:GetAttribute("InspectId"), "test_clue_noev", "ClueId wins over the InspectId it carried")
			T.Eq(NoEv.InspectPrompt.ObjectText, "Notice", "the prompt is the clue's")
			T.True(InvestigationService.Inspect(Player, NoEv:GetAttribute("InspectId"), NoEv), "the no-Evidence clue was inspected")
			T.True(Data.Quests.Active[QUEST] == nil, "a no-Evidence clue with failing Requires doesn't start the quest")

			-- Start's pass maps a clue already in the place. No yield between parenting and Scan: the deferred
			-- added-signal handler can't have run yet
			local Part = Clue(Root, "test_clue", 0)
			table.insert(Parts, Part)
			T.True(Part:FindFirstChild("InspectPrompt") == nil, "not yet mapped by the added signal")
			InvestigationService.Scan()
			T.True(Part:FindFirstChild("InspectPrompt") ~= nil, "Start's pass gave the clue an Inspect prompt")
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

			-- a repeat inspect (AfterText) doesn't restart the active quest and toasts nothing
			local Toasts = {}
			UIService.Notify = function(P, Kind, Payload)
				if P == Player and Kind == "Toast" then table.insert(Toasts, Payload and Payload.Text or "?") end
				return RealNotify(P, Kind, Payload)
			end
			T.True(InvestigationService.Inspect(Player, "test_clue", Part), "inspected again")
			UIService.Notify = RealNotify
			T.True(Data.Quests.Active[QUEST] == State, "the same quest state: not restarted")
			T.Eq(#Toasts, 0, "no toast on a repeat inspect (" .. table.concat(Toasts, " | ") .. ")")

			-- with the quest gone from Active, an AfterText inspect starts it again, caught up
			Data.Quests.Active[QUEST] = nil
			T.True(InvestigationService.Inspect(Player, "test_clue", Part), "inspected a third time")
			local Again = Data.Quests.Active[QUEST]
			T.True(Again ~= nil and Again ~= State, "an AfterText inspect started the quest again")
			T.Eq(Again.Progress.o1, 1, "caught up again")
		end)
		UIService.Notify = RealNotify
		pcall(function() DialogueService.Close(Player) end)
		pcall(function()
			for _, P in ipairs(Parts) do P:Destroy() end
			Content.Inspects.test_clue = nil
			Content.Inspects.test_clue_locked = nil
			Content.Inspects.test_clue_noev = nil
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

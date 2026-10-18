-- DialogueService: NPC conversations. Any model carrying the attribute DialogueId gets a talk
-- prompt. The server holds each player's position in the tree; the client only sends which
-- choice index it picked, and actions (start quest...) run here after validation.
-- Conditions (Rensei.StoryLogic): a definition's Starts = {{Requires, Node}} picks the opening node;
-- a node's Alt = {{Requires, Text}} swaps its text; a choice's Requires hides it, or with
-- Show = "Locked" shows it greyed with the reason. The server keeps the list of choices it
-- actually showed, so a forged index can never reach a hidden or locked choice.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Definitions = require(ReplicatedStorage.Modules.Data.Rensei.Dialogues)
local StoryLogic = require(ReplicatedStorage.Modules.Data.Rensei.StoryLogic)
local EvidenceDefs = require(ReplicatedStorage.Modules.Data.Rensei.Evidence)
local UIService = require(ServerScriptService.UIService)
local QuestService = require(ServerScriptService.QuestService)
local ProgressionService = require(ServerScriptService.ProgressionService)
local StoryService = require(ServerScriptService.StoryService)

local MAX_DISTANCE = 16

local DialogueService = {}
DialogueService.Definitions = Definitions

local Sessions = {} -- [Player] = {Id, Node, Model}

local function RootOf(Model)
	if Model:IsA("BasePart") then return Model end -- inspect points / mechanisms can be plain parts
	return Model:FindFirstChild("HumanoidRootPart") or Model.PrimaryPart or Model:FindFirstChildWhichIsA("BasePart")
end

-- The player is still close enough to the NPC / inspect point to keep talking.
local function InRange(Player, Session)
	local Root = Session.Model and Session.Model.Parent and RootOf(Session.Model)
	local PRoot = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
	return Root ~= nil and PRoot ~= nil and (Root.Position - PRoot.Position).Magnitude <= MAX_DISTANCE
end

local function Show(Player, Session)
	if Session.Inline then -- DialogueService.Say: one line, no tree
		Session.Shown = {{Choice = {}, Locked = false}}
		UIService.Notify(Player, "Dialogue", {Speaker = Session.Inline.Speaker, Text = Session.Inline.Text, Choices = {"Leave"}, Locked = {false}})
		return
	end
	local Def = Definitions[Session.Id]
	local Node = Def.Nodes[Session.Node]
	local Data = ProgressionService.GetData(Player)
	local Text = Node.Text
	for _, Alt in ipairs(Node.Alt or {}) do
		if StoryLogic.Meets(Alt.Requires, Data, Player) then Text = Alt.Text break end
	end
	local Labels, Locked, Shown = {}, {}, {}
	for _, Choice in ipairs(Node.Choices or {}) do
		local Ok = StoryLogic.Meets(Choice.Requires, Data, Player)
		-- ShowIf: hide the choice entirely unless these conditions pass (e.g. once a style is learned)
		local Visible = StoryLogic.Meets(Choice.ShowIf, Data, Player)
		if Visible and (Ok or Choice.Show == "Locked") then
			table.insert(Shown, {Choice = Choice, Locked = not Ok})
			local Label = Choice.Text
			if Choice.Requires and Choice.Requires.Evidence and Ok then
				Label = StoryLogic.LockLabel(Choice.Requires, EvidenceDefs) .. " " .. Label -- "[Evidence: X]" marks a presented clue
			elseif not Ok then
				Label = StoryLogic.LockLabel(Choice.Requires, EvidenceDefs) .. " " .. Label
			end
			table.insert(Labels, Label)
			table.insert(Locked, not Ok) -- a full true/false list (sparse tables don't survive remotes)
		end
	end
	if #Labels == 0 then table.insert(Labels, "Leave") end
	Session.Shown = Shown
	UIService.Notify(Player, "Dialogue", {Speaker = Def.Speaker or Session.Model.Name, Text = Text, Choices = Labels, Locked = Locked})
end

local function StartNode(Player, Def)
	local Data = ProgressionService.GetData(Player)
	for _, S in ipairs(Def.Starts or {}) do
		if Def.Nodes[S.Node] and StoryLogic.Meets(S.Requires, Data, Player) then return S.Node end
	end
	return Def.Start or "start"
end

-- No talking while fighting: in combat (tagged) or with Combat Mode (E) on.
local function Fighting(Player)
	local Character = Player.Character
	return Character ~= nil and (Character:GetAttribute("InCombat") == true or Character:GetAttribute("CombatMode") == true)
end

function DialogueService.Open(Player, Model)
	if Fighting(Player) then
		UIService.Notify(Player, "Toast", {Text = "You can't do that in combat"})
		return false
	end
	local Id = Model:GetAttribute("DialogueId")
	local Def = Definitions[Id]
	if not Def or not Def.Nodes or not Def.Nodes[Def.Start or "start"] then return false end
	Sessions[Player] = {Id = Id, Node = StartNode(Player, Def), Model = Model}
	QuestService.Signal(Player, "Talk", Id)
	Show(Player, Sessions[Player])
	return true
end

-- A single line in the dialogue box (inspect points, puzzle hints). Model = what the player is
-- looking at (for the distance check). Returns false while fighting.
function DialogueService.Say(Player, Model, Speaker, Text)
	if Fighting(Player) then
		UIService.Notify(Player, "Toast", {Text = "You can't do that in combat"})
		return false
	end
	local Session = {Inline = {Speaker = Speaker, Text = Text}, Model = Model}
	Sessions[Player] = Session
	Show(Player, Session)
	return true
end

-- Always tells the client to close, session or not: a box left open with no session here would
-- otherwise ignore every key and click (DialogueUI ignores the event when its box is shut).
function DialogueService.Close(Player)
	Sessions[Player] = nil
	UIService.Notify(Player, "DialogueEnd", {})
end

local Actions = {
	StartQuest = function(Player, Action, Session)
		if QuestService.Start(Player, Action.Quest) then
			-- The Talk signal fired when this conversation opened, before the quest existed.
			QuestService.Signal(Player, "Talk", Session.Id)
		end
	end,
	CompleteSignal = function(Player, Action) QuestService.Signal(Player, "Signal", Action.Target) end,
	Signal = function(Player, Action) QuestService.Signal(Player, "Signal", Action.Target) end,
	-- story choices: recorded once (SetFlag never overwrites an existing value)
	SetFlag = function(Player, Action) StoryService.SetFlag(Player, Action.Flag, Action.Value) end,
	GiveEvidence = function(Player, Action) StoryService.GiveEvidence(Player, Action.Evidence) end,
	GiveItem = function(Player, Action)
		require(ServerScriptService.ItemService).Give(Player, Action.Item, Action.Amount or 1)
	end,
	StartMinigame = function(Player, Action)
		require(ServerScriptService.MinigameService).Open(Player, Action.Minigame, Action.Context)
	end,
	-- morality: records a deed (Rensei.Deeds) once; repeatables follow their daily cap
	Deed = function(Player, Action) require(ServerScriptService.MoralityService).Record(Player, Action.Deed) end,
	-- a style trainer teaches a weapon style (Rensei.Styles; StyleService re-checks the requirements)
	UnlockStyle = function(Player, Action)
		local Ok, Message = require(ServerScriptService.StyleService).Unlock(Player, Action.Style)
		if Message then UIService.Notify(Player, "Toast", {Text = Message}) end
		if Ok then ProgressionService.Sync(Player) end
	end,
	-- alchemy trainers (TrainingService re-checks the path and the daily limit): the conversation closes
	-- first, so the minigame / drill has the screen
	Lesson = function(Player, Action)
		DialogueService.Close(Player)
		require(ServerScriptService.TrainingService).Lesson(Player, Action.Lesson)
	end,
	Exercise = function(Player, Action)
		DialogueService.Close(Player)
		task.spawn(require(ServerScriptService.TrainingService).Exercise, Player, Action.Exercise)
	end,
}

local function RunActions(Player, Choice, Session)
	local List = Choice.Actions or (Choice.Action and {Choice.Action}) or {}
	for _, Action in ipairs(List) do
		local Fn = Actions[Action.Kind]
		if Fn then
			local Ok, Err = pcall(Fn, Player, Action, Session)
			if not Ok then warn("Dialogue action", Action.Kind, "failed:", Err) end
		end
	end
end

function DialogueService.Choose(Player, Index)
	local Session = Sessions[Player]
	if not Session then -- the client is showing a conversation the server no longer has
		DialogueService.Close(Player)
		return false
	end
	if type(Index) ~= "number" or Index % 1 ~= 0 then return false end
	if Fighting(Player) then
		DialogueService.Close(Player)
		return false
	end
	if not InRange(Player, Session) then
		DialogueService.Close(Player)
		return false
	end
	if Session.Inline then DialogueService.Close(Player) return true end
	-- the index refers to the choices this player was SHOWN (hidden ones never reach here)
	local Entry = (Session.Shown or {})[Index]
	if not Entry then DialogueService.Close(Player) return true end
	if Entry.Locked then return false end -- greyed out: nothing happens
	local Choice = Entry.Choice
	RunActions(Player, Choice, Session)
	if Sessions[Player] ~= Session then return true end -- an action closed the conversation (minigame)
	if Choice.Next and Definitions[Session.Id].Nodes[Choice.Next] then
		Session.Node = Choice.Next
		Show(Player, Session)
	else
		DialogueService.Close(Player)
	end
	return true
end

local Prompted = setmetatable({}, {__mode = "k"})
local function Attach(Model)
	if Prompted[Model] or not Model:IsA("Model") or not Model:GetAttribute("DialogueId") then return end
	local Root = RootOf(Model)
	if not Root then return end
	Prompted[Model] = true
	-- Story NPCs can wear a nation look like enemies do: attributes LookNation, LookGender
	-- ("Male"/"Female", so it matches their lines) and LookSeed (the same look on every server).
	if Model:GetAttribute("LookNation") then
		pcall(function()
			local Customization = require(ReplicatedStorage.Modules.Data.Rensei.Customization)
			local Rng = Random.new(Model:GetAttribute("LookSeed") or 1)
			local Want = Model:GetAttribute("LookGender")
			local Look, Nation, Gender
			for _ = 1, 40 do
				Look, Nation, Gender = Customization.RandomLook(Model:GetAttribute("LookNation"), Rng)
				if not Want or Gender == Want then break end
			end
			require(ServerScriptService.AppearanceService).Apply(Model, Look)
			Model:SetAttribute("Gender", Gender)
		end)
	end
	local Prompt = Instance.new("ProximityPrompt")
	Prompt.Name = "TalkPrompt"
	Prompt.ActionText = "Talk"
	Prompt.ObjectText = Model:GetAttribute("DisplayName") or Model.Name
	Prompt.MaxActivationDistance = 10
	Prompt.RequiresLineOfSight = false
	Prompt.Style = Enum.ProximityPromptStyle.Custom -- drawn in Rensei's art by Modules.UI.PromptUI
	Prompt.Parent = Root
	Prompt.Triggered:Connect(function(Player)
		DialogueService.Open(Player, Model)
	end)
end

function DialogueService.Start()
	for _, D in ipairs(workspace:GetDescendants()) do
		if D:IsA("Model") and D:GetAttribute("DialogueId") then Attach(D) end
	end
	workspace.DescendantAdded:Connect(function(D)
		if D:IsA("Model") then task.defer(Attach, D) end
	end)
	Players.PlayerRemoving:Connect(function(Player) Sessions[Player] = nil end)
	-- Walking away (or the NPC / character going away) ends the conversation.
	task.spawn(function()
		while true do
			task.wait(0.5)
			for Player, Session in pairs(Sessions) do
				if not InRange(Player, Session) then DialogueService.Close(Player) end
			end
		end
	end)
end

return DialogueService

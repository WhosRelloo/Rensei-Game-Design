-- JournalUI (J): quests, evidence, the Case Board and the codex, built with MenuKit (Settings art).
-- Reads the profile the server syncs (UIState.Data); the only things it sends are Track / Abandon
-- (Requests.Quest) and Case Board answers (Requests.Investigation "Deduce"), all re-checked there.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local UIState = require(script.Parent.UIState)
local MenuKit = require(script.Parent.MenuKit)
local Rensei = ReplicatedStorage.Modules.Data.Rensei
local QuestDefs = require(Rensei.Quests)
local EvidenceDefs = require(Rensei.Evidence)
local Investigation = require(Rensei.Investigation)
local StoryLogic = require(Rensei.StoryLogic)

local JournalUI = {}

local Kit
local Picks = {} -- [DeductionId] = {[slot] = index into the held-evidence list}
local Results = {} -- [DeductionId] = {Ok, Text} (last Case Board answer)

local function Data() return UIState.Data end

local function HeldEvidence(D)
	local List = {}
	for Id, At in pairs((D.Story or {}).Evidence or {}) do
		if EvidenceDefs[Id] then table.insert(List, {Id = Id, At = At}) end
	end
	table.sort(List, function(A, B) return A.At < B.At end)
	return List
end

local Draw = {}

function Draw.Quests(D)
	local Active, Tracked = {}, D.Quests.Tracked
	for Id, State in pairs(D.Quests.Active) do
		if QuestDefs[Id] then table.insert(Active, {Id = Id, State = State}) end
	end
	table.sort(Active, function(A, B)
		if (A.Id == Tracked) ~= (B.Id == Tracked) then return A.Id == Tracked end
		return A.State.Started < B.State.Started
	end)
	Kit:Heading(#Active > 0 and "Active" or "No active quests. People with problems tend to say so.")
	for _, Q in ipairs(Active) do
		local Def = QuestDefs[Q.Id]
		local _, C = Kit:Row(Def.Title .. (Q.Id == Tracked and "  (tracked)" or ""), 0.6)
		if Q.Id ~= Tracked then Kit:Button(C, "Track", function() UIState.Request("Quest", "Track", Q.Id) end) end
		Kit:Button(C, "Abandon", function() UIState.Request("Quest", "Abandon", Q.Id) end, true)
		local Objectives, Stage = StoryLogic.Visible(Def, Q.State)
		Kit:Paragraph(Stage.Text or Def.Description or "", 2)
		for _, O in ipairs(Objectives) do
			local Need, Have = O.Count or 1, Q.State.Progress[O.Id] or 0
			local Mark = Have >= Need and "[done] " or "- "
			Kit:Row(Mark .. O.Text .. (Need > 1 and (" (%d/%d)"):format(Have, Need) or "") .. (O.Optional and " (optional)" or ""), 0.92)
		end
	end
	local Done = {}
	for Id, At in pairs(D.Quests.Completed) do
		if QuestDefs[Id] then table.insert(Done, {Id = Id, At = At}) end
	end
	table.sort(Done, function(A, B) return A.At > B.At end)
	if #Done > 0 then Kit:Heading("Completed") end
	for _, Q in ipairs(Done) do
		local Def = QuestDefs[Q.Id]
		Kit:Row(Def.Title .. (Def.Repeatable and "  (repeatable)" or ""), 0.92)
		local Outcome = Def.Outcomes and ((D.Story or {}).Flags or {})["Outcome_" .. Q.Id]
		if Outcome and Def.Outcomes[Outcome] then Kit:Paragraph(Def.Outcomes[Outcome].Text, 2) end
	end
end

function Draw.Evidence(D)
	local Held = HeldEvidence(D)
	if #Held == 0 then
		Kit:Paragraph("You haven't found anything yet. Look closely at things that seem out of place (Inspect).", 2)
		return
	end
	local Groups, Order = {}, {}
	for _, E in ipairs(Held) do
		local Q = EvidenceDefs[E.Id].Quest or ""
		if not Groups[Q] then Groups[Q] = {} table.insert(Order, Q) end
		table.insert(Groups[Q], E.Id)
	end
	for _, Q in ipairs(Order) do
		Kit:Heading(QuestDefs[Q] and QuestDefs[Q].Title or "Other")
		for _, Id in ipairs(Groups[Q]) do
			local R = Kit:Row(EvidenceDefs[Id].Title .. (EvidenceDefs[Id].Research and "  (research note)" or ""), 0.92)
			R.Title.TextColor3 = MenuKit.Gold
			Kit:Paragraph(EvidenceDefs[Id].Text, 2)
		end
	end
end

function Draw.CaseBoard(D)
	local Story = D.Story or {}
	local Held = HeldEvidence(D)
	local Names, Ids = {"(nothing)"}, {""}
	for _, E in ipairs(Held) do table.insert(Names, EvidenceDefs[E.Id].Title) table.insert(Ids, E.Id) end
	local Shown = 0
	for Id, Def in pairs(Investigation.Deductions) do
		-- a case appears once you hold any evidence it needs (or have solved it)
		local Relevant = (Story.Deductions or {})[Id] ~= nil
		for _, Slot in ipairs(Def.Slots) do if (Story.Evidence or {})[Slot.Answer] then Relevant = true end end
		if Relevant then
			Shown += 1
			Kit:Heading(Def.Title)
			Kit:Paragraph(Def.Question, 2)
			if (Story.Deductions or {})[Id] then
				local R = Kit:Paragraph("Solved: " .. Def.Conclusion, 2)
				R.Title.TextColor3 = MenuKit.Gold
			else
				Picks[Id] = Picks[Id] or {}
				for I, Slot in ipairs(Def.Slots) do
					local _, C = Kit:Row(Slot.Label, 0.44)
					Kit:Cycler(C, Names, Picks[Id][I] or 1, function(N) Picks[Id][I] = N JournalUI.Redraw() end, 0.3)
				end
				local _, C = Kit:Row("Does it hold together?", 0.6)
				Kit:Button(C, "Submit", function()
					local Answers = {}
					for I = 1, #Def.Slots do Answers[I] = Ids[Picks[Id][I] or 1] or "" end
					UIState.Request("Investigation", "Deduce", Id, Answers)
				end)
				if Results[Id] and not Results[Id].Ok then
					local R = Kit:Paragraph(Results[Id].Text, 2)
					R.Title.TextColor3 = Color3.fromRGB(220, 120, 110)
				end
			end
		end
	end
	if Shown == 0 then
		Kit:Paragraph("Nothing to piece together yet. Evidence you find will gather here.", 2)
	end
end

function Draw.Codex(D)
	local List = {}
	for Entry, At in pairs(D.Codex or {}) do table.insert(List, {Entry = Entry, At = At}) end
	table.sort(List, function(A, B) return A.At > B.At end)
	Kit:Heading(#List > 0 and ("%d entries"):format(#List) or "No entries yet.")
	for _, E in ipairs(List) do Kit:Row(E.Entry, 0.92) end
end

local TabDraw = {Quests = Draw.Quests, Evidence = Draw.Evidence, ["Case Board"] = Draw.CaseBoard, Codex = Draw.Codex}

-- Animate: only on open and tab changes (UIMotion pops rows); data refreshes swap rows in place
function JournalUI.Redraw(Animate)
	local D = Data()
	if not Kit or not D or not D.Quests then return end
	Kit:Clear(Animate)
	TabDraw[Kit.Tab](D)
	if not Animate then Kit:KeepScroll() end
end

function JournalUI.Start()
	Kit = MenuKit.new("Journal", "JOURNAL", {"Quests", "Evidence", "Case Board", "Codex"}, function()
		JournalUI.Redraw(true)
	end)
	UIState.RegisterMenu("Journal", Kit.Root, function() JournalUI.Redraw(true) end)
	UIState.Changed:Connect(function()
		if Kit.Root.Visible then JournalUI.Redraw() end
	end)
	UIState.On("CaseResult", function(P)
		Results[P.Id] = {Ok = P.Ok, Text = P.Text}
		if not P.Ok then UIState.Emit("Toast", {Text = P.Text}) end
		if Kit.Root.Visible then JournalUI.Redraw() end
	end)
	ContextActionService:BindAction("RenseiJournal", function(_, State)
		if State == Enum.UserInputState.Begin then UIState.ToggleMenu("Journal") end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.J)
	ContextActionService:SetTitle("RenseiJournal", "Journal")
	ContextActionService:SetPosition("RenseiJournal", UDim2.new(1, -70 - 5 * 62, 0, 10))
end

return JournalUI

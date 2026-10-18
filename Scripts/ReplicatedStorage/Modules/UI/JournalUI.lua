-- JournalUI (J): quests, evidence, the Case Board, the codex and Player Identities, built with MenuKit
-- (Settings art). Reads the profile the server syncs (UIState.Data); the only things it sends are Track /
-- Abandon (Requests.Quest), Case Board answers (Requests.Investigation "Deduce") and namings
-- (Requests.Investigation "Identify"), all re-checked there.
-- 2026-10-18 revamp: Evidence is a ledger (clue list + the selected clue's record) and the Case Board a
-- workspace (cases, clue cards, the case's lines, threads from pinned cards); see the section above Draw.Identities.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local UIState = require(script.Parent.UIState)
local MenuKit = require(script.Parent.MenuKit)
local Rensei = ReplicatedStorage.Modules.Data.Rensei
local QuestDefs = require(Rensei.Quests)
local EvidenceDefs = require(Rensei.Evidence)
local Investigation = require(Rensei.Investigation)
local StoryLogic = require(Rensei.StoryLogic)
local Identities = require(Rensei.Identities)

local JournalUI = {}

local Kit
local Picks = {} -- [DeductionId] = {[slot] = evidence id pinned on the Case Board}
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

function Draw.Codex(D)
	local List = {}
	for Entry, At in pairs(D.Codex or {}) do table.insert(List, {Entry = Entry, At = At}) end
	table.sort(List, function(A, B) return A.At > B.At end)
	Kit:Heading(#List > 0 and ("%d entries"):format(#List) or "No entries yet.")
	for _, E in ipairs(List) do Kit:Row(E.Entry, 0.92) end
end

-- ===== Player Identities (2026-10-18): a compact register of the people you've crossed paths with =====
-- Desktop: the subject list and the selected record side by side (two clones of the journal's own row
-- container). Narrow screens: the list, then one record with a Back row. Drawn by DrawList / DrawRecord
-- (above Draw.Identities), which share the ledger helpers with Evidence and the Case Board.
local Ident = {Selected = nil, Detail = false, Picks = {}, Results = {}}
local Split -- {Left, Right}
local Tags = {observed = "[observed]  ", inferred = "[inferred]  ", confirmed = "[confirmed]  "}
local DIM_TEXT = Color3.fromRGB(165, 160, 150)
local RED_TEXT = Color3.fromRGB(220, 120, 110)

local function Ago(T)
	local S = os.time() - (T or 0)
	if S < 3600 then return math.max(1, math.floor(S / 60)) .. " min ago" end
	if S < 86400 then return math.floor(S / 3600) .. " h ago" end
	return math.floor(S / 86400) .. " d ago"
end

local function SortedRecords(D)
	local List = {}
	for Key, R in pairs(((D.Identities or {}).Records) or {}) do table.insert(List, {Key = Key, R = R}) end
	table.sort(List, function(A, B) return (A.R.Last or 0) > (B.R.Last or 0) end)
	return List
end

-- draw MenuKit rows into another container
local function Into(Container, Fn)
	local Saved, Order = Kit.Rows, Kit.Order
	Kit.Rows, Kit.Order = Container, 0
	Fn()
	Kit.Rows, Kit.Order = Saved, Order
end

local function MakeSplit()
	if Split then return Split end
	local Rows = Kit.Rows
	local function Column(Name, From, Share)
		local C = Rows:Clone()
		for _, Child in ipairs(C:GetChildren()) do if Child:IsA("GuiObject") then Child:Destroy() end end
		C.Name = Name
		local W = Rows.Size.X.Scale
		local Left = Rows.Position.X.Scale - Rows.AnchorPoint.X * W
		C.Size = UDim2.new(W * Share, 0, Rows.Size.Y.Scale, Rows.Size.Y.Offset)
		C.Position = UDim2.new(Left + W * From + C.AnchorPoint.X * W * Share, 0, Rows.Position.Y.Scale, Rows.Position.Y.Offset)
		C.CanvasPosition = Vector2.zero
		C.Visible = false
		C.Parent = Rows.Parent
		return C
	end
	-- shared by Identities, Evidence and the Case Board (each tab sizes them with UseSplit)
	Split = {Left = Column("SplitList", 0, 0.4), Right = Column("SplitDetail", 0.42, 0.58)}
	return Split
end

local function Clickable(Row, Fn)
	local B = Instance.new("TextButton")
	B.Name = "Pick"
	B.BackgroundTransparency = 1
	B.Text = ""
	B.Size = UDim2.fromScale(1, 1)
	B.ZIndex = Row.ZIndex + 5
	B.Parent = Row
	B.Activated:Connect(Fn)
end

-- ===== shared by the Evidence ledger and the Case Board (2026-10-18 revamp) =====
-- Both use the Identities layout: list on the left, the selected item on the right (two clones of the
-- journal's own row container); narrow screens show the list, then one item with a Back row.
local Animating = false -- this redraw pops its rows (open / tab change)
local TEXT_ON = Color3.fromRGB(225, 220, 210)

local function Wide()
	local Viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	-- (the Journal's ForceNarrow attribute shows the phone layout on a desktop, for testing)
	return Viewport.X >= 1000 and not Kit.Root:GetAttribute("ForceNarrow")
end

-- the two columns sized for this tab; returns them and a function that restores their scroll after a refresh
local function UseSplit(LeftShare)
	local S = MakeSplit()
	local Rows = Kit.Rows
	local W = Rows.Size.X.Scale
	local Left = Rows.Position.X.Scale - Rows.AnchorPoint.X * W
	local function Place(C, From, Share)
		C.Size = UDim2.new(W * Share, 0, Rows.Size.Y.Scale, Rows.Size.Y.Offset)
		C.Position = UDim2.new(Left + W * From + C.AnchorPoint.X * W * Share, 0, Rows.Position.Y.Scale, Rows.Position.Y.Offset)
	end
	Place(S.Left, 0, LeftShare)
	Place(S.Right, LeftShare + 0.02, 1 - LeftShare - 0.02)
	Rows.Visible = false
	local Keep = {S.Left.CanvasPosition, S.Right.CanvasPosition}
	for _, Col in ipairs({S.Left, S.Right}) do
		Col.Visible = true
		for _, Child in ipairs(Col:GetChildren()) do if Child:IsA("GuiObject") then Child:Destroy() end end
	end
	return S, function()
		if Animating then
			S.Left.CanvasPosition, S.Right.CanvasPosition = Vector2.zero, Vector2.zero
		else
			S.Left.CanvasPosition, S.Right.CanvasPosition = Keep[1], Keep[2]
		end
	end
end

-- selected rows: gold title, a warmer plate and a thin gold bar at the left edge (the journal's own row art)
local function Mark(Row, On, Dim)
	Row.Title.TextColor3 = On and MenuKit.Gold or (Dim and DIM_TEXT or TEXT_ON)
	Row.ImageColor3 = On and Color3.fromRGB(255, 236, 190) or Color3.new(1, 1, 1)
	if On then
		local Bar = Instance.new("Frame")
		Bar.Name = "Selected"
		Bar.BorderSizePixel = 0
		Bar.BackgroundColor3 = MenuKit.Gold
		Bar.AnchorPoint = Vector2.new(0, 0.5)
		Bar.Position = UDim2.new(0, 3, 0.5, 0)
		Bar.Size = UDim2.new(0, 3, 0.56, 0)
		Bar.ZIndex = Row.ZIndex + 2
		Bar.Parent = Row
	end
end

-- paragraph height (in authored rows) for a text at this width
local function Units(Text, Narrow)
	local Lines = math.ceil(#(Text or "") / (Narrow and 62 or 40))
	return math.clamp(math.ceil(Lines / 1.9), 2, 7)
end

local function CaseTitle(QuestId) return QuestDefs[QuestId] and QuestDefs[QuestId].Title or "Other" end

-- the quest a Case Board case belongs to (its clues' quest)
local function CaseQuest(Def)
	for _, Slot in ipairs(Def.Slots) do
		local E = EvidenceDefs[Slot.Answer]
		if E and E.Quest then return E.Quest end
	end
end

-- where a clue comes from, read from the same content the server gives it from (never invented)
local SourceCache = nil
local function SourcesOf(Id)
	if not SourceCache then
		SourceCache = {}
		local function Add(Ev, Text)
			if not Ev then return end
			SourceCache[Ev] = SourceCache[Ev] or {}
			table.insert(SourceCache[Ev], Text)
		end
		-- inspect points, with the area they sit in when the compass list knows it (CompassService)
		local Points = ReplicatedStorage:FindFirstChild("CompassPoints")
		local function Near(InspectId)
			if not Points then return "" end
			local At
			for _, P in ipairs(Points:GetChildren()) do
				if P:GetAttribute("Kind") == "Inspect" and P:GetAttribute("Key") == InspectId then At = P:GetAttribute("Position") break end
			end
			if typeof(At) ~= "Vector3" then return "" end
			local Best, BestD
			for _, P in ipairs(Points:GetChildren()) do
				local Pos = P:GetAttribute("Position")
				if P:GetAttribute("Kind") == "Area" and typeof(Pos) == "Vector3" then
					local Dist = Vector3.new(Pos.X - At.X, 0, Pos.Z - At.Z).Magnitude
					if Dist <= (P:GetAttribute("Radius") or 0) * 1.2 and (not BestD or Dist < BestD) then Best, BestD = P:GetAttribute("Key"), Dist end
				end
			end
			return Best and (", " .. Best) or ""
		end
		for InspectId, Def in pairs(Investigation.Inspects or {}) do
			if Def.Evidence then Add(Def.Evidence, "Examined: " .. (Def.Title or InspectId) .. Near(InspectId)) end
		end
		local Ok, Minigames = pcall(require, Rensei.Minigames)
		for MgId, Def in pairs(Ok and Minigames or {}) do
			if type(Def) == "table" and Def.Evidence then Add(Def.Evidence, "Worked out at: " .. (Def.Title or MgId)) end
		end
		local Ok2, Puzzles = pcall(require, Rensei.Puzzles)
		for PId, Def in pairs(Ok2 and (Puzzles.Puzzles or Puzzles) or {}) do
			if type(Def) == "table" and Def.Evidence then Add(Def.Evidence, "Found by solving: " .. (Def.Title or PId)) end
		end
		-- dialogue actions (GiveEvidence) anywhere in a conversation
		local Ok3, Dialogues = pcall(require, Rensei.Dialogues)
		for _, Def in pairs(Ok3 and Dialogues or {}) do
			if type(Def) == "table" then
				local Seen, Found = {}, {}
				local function Walk(T, Depth)
					if Depth > 10 or Seen[T] then return end
					Seen[T] = true
					if T.Kind == "GiveEvidence" and type(T.Evidence) == "string" then Found[T.Evidence] = true end
					for _, V in pairs(T) do if type(V) == "table" then Walk(V, Depth + 1) end end
				end
				Walk(Def, 0)
				for Ev in pairs(Found) do Add(Ev, "Told by: " .. tostring(Def.Speaker or "someone you spoke to")) end
			end
		end
	end
	return SourceCache[Id] or {}
end

local function Held(D, Id) return (((D.Story or {}).Evidence) or {})[Id] ~= nil end

-- ===== the Evidence ledger =====
local Ev = {Selected = nil, Detail = false, Seen = nil} -- Seen: clues already looked at (this session)

local function NewCount(D)
	if not Ev.Seen then return 0 end
	local N = 0
	for Id in pairs(((D.Story or {}).Evidence) or {}) do
		if EvidenceDefs[Id] and not Ev.Seen[Id] then N += 1 end
	end
	return N
end

local function EvidenceList(D)
	local List = HeldEvidence(D)
	Kit:Heading(("%d %s collected"):format(#List, #List == 1 and "clue" or "clues"))
	local Groups, Order = {}, {}
	for _, E in ipairs(List) do
		local Q = EvidenceDefs[E.Id].Quest or ""
		if not Groups[Q] then Groups[Q] = {} table.insert(Order, Q) end
		table.insert(Groups[Q], E.Id)
	end
	for _, Q in ipairs(Order) do
		local Sub = Kit:Row(CaseTitle(Q):upper(), 0.92)
		Sub.ImageTransparency = 0.8
		Sub.Title.TextColor3 = DIM_TEXT
		for _, Id in ipairs(Groups[Q]) do
			local Def = EvidenceDefs[Id]
			local IsNew = Ev.Seen ~= nil and not Ev.Seen[Id]
			local Row, C = Kit:Row(Def.Title, IsNew and 0.66 or 0.92)
			if IsNew then Kit:Label(C, "NEW", 0.3).Head.TextColor3 = MenuKit.Gold end
			Mark(Row, Id == Ev.Selected)
			Clickable(Row, function()
				Ev.Selected, Ev.Detail = Id, true
				if Ev.Seen then Ev.Seen[Id] = true end
				JournalUI.Redraw()
			end)
		end
	end
end

local Case -- (the Case Board's state, below)

local function EvidenceDetail(D, Id, Narrow)
	if Narrow then
		local _, C = Kit:Row("", 0.05)
		Kit:Button(C, "< Back", function() Ev.Detail = false JournalUI.Redraw() end)
	end
	local Def = Id and EvidenceDefs[Id]
	local At = Id and (((D.Story or {}).Evidence) or {})[Id]
	if not Def or not At then
		Kit:Paragraph("Pick a clue from the list.", 2)
		return
	end
	Kit:Heading(Def.Title)
	local _, C = Kit:Row(Def.Research and "Research note" or "Clue", 0.45)
	Kit:Label(C, "Found " .. Ago(At), 0.5)
	Kit:Paragraph(Def.Text or "", Units(Def.Text, Narrow))
	if Def.Technique then Kit:Row(("Describes %s alchemy"):format(tostring(Def.Technique)), 0.92).Title.TextColor3 = DIM_TEXT end
	local Sources = SourcesOf(Id)
	if #Sources > 0 then
		Kit:Heading("Source")
		for _, S in ipairs(Sources) do
			if #S > (Narrow and 60 or 44) then Kit:Paragraph(S, 2) else Kit:Row(S, 0.92) end
		end
	end
	-- the case it belongs to, and what the Case Board made of it
	Kit:Heading("Case")
	Kit:Row(CaseTitle(Def.Quest or ""), 0.92)
	local Story = D.Story or {}
	for DId, DDef in pairs(Investigation.Deductions) do
		if CaseQuest(DDef) == Def.Quest then
			local Solved = (Story.Deductions or {})[DId] ~= nil
			local Row, C2 = Kit:Row(DDef.Title .. (Solved and "  (solved)" or ""), 0.62)
			Row.Title.TextColor3 = Solved and MenuKit.Gold or TEXT_ON
			Kit:Button(C2, "Case Board", function()
				Case.Selected, Case.Detail, Case.ActiveSlot, Case.Card = DId, true, 1, nil
				Kit.Tab = "Case Board"
				Kit:PaintTabs()
				JournalUI.Redraw(true)
			end)
			local Used = false
			for _, Slot in ipairs(DDef.Slots) do if Slot.Answer == Id then Used = true end end
			if Solved and Used then
				Kit:Paragraph(Tags.confirmed .. "It helped prove: " .. (DDef.Conclusion or ""), Units(DDef.Conclusion, Narrow)).Title.TextColor3 = MenuKit.Gold
			end
		end
	end
	-- Player Identities: a technique this clue describes, seen on someone you've met (a lead, not proof)
	for _, R in pairs(((D.Identities or {}).Records) or {}) do
		if (R.Links or {})[Id] then
			local Known = (R.Name or "") ~= ""
			Kit:Paragraph(Tags.inferred .. "Possible link: " .. (Known and R.Name or "???") .. " " .. Identities.Number(R)
				.. ", who uses " .. tostring(Def.Technique) .. " alchemy. A lead, not proof.", 2).Title.TextColor3 = DIM_TEXT
		end
	end
end

function Draw.Evidence(D)
	local List = HeldEvidence(D)
	if #List == 0 then
		if Split then Split.Left.Visible, Split.Right.Visible = false, false end
		Kit.Rows.Visible = true
		Kit:Paragraph("You haven't found anything yet. Look closely at things that seem out of place (Inspect).", 2)
		return
	end
	if not Ev.Selected or not Held(D, Ev.Selected) then Ev.Selected = List[#List].Id end -- the newest clue
	if Wide() then
		local S, Restore = UseSplit(0.42)
		Into(S.Left, function() EvidenceList(D) end)
		Into(S.Right, function() EvidenceDetail(D, Ev.Selected, false) end)
		if Ev.Seen then Ev.Seen[Ev.Selected] = true end
		Restore()
	elseif Ev.Detail then
		EvidenceDetail(D, Ev.Selected, true)
		if Ev.Seen then Ev.Seen[Ev.Selected] = true end
	else
		EvidenceList(D)
	end
end

-- ===== the Case Board =====
-- A case's clue cards (every clue you hold from its investigation, so the board never hints which ones matter),
-- the case's lines to fill, and threads from each pinned card to its line. Pick a line, then the card that
-- answers it (or a card, then a line). Submit sends the pins to the server (Requests.Investigation "Deduce"),
-- which checks them against the case data and pays out through QuestService; a solved case shows its answers
-- with solid threads. Nothing here decides a result.
Case = {Selected = nil, Detail = false, ActiveSlot = 1, Card = nil, Hint = nil}
local CardArt = nil -- the Stats panel's ornate header plate, as the clue-card art

local function CardImage()
	if CardArt == nil then
		local Ok, Head = pcall(function() return UIState.Gui.Stats.MainFrame.Left.Head end)
		CardArt = Ok and Head and {Image = Head.Image, ScaleType = Head.ScaleType, SliceCenter = Head.SliceCenter} or false
	end
	return CardArt
end

local function RelevantCases(D)
	local Story = D.Story or {}
	local List = {}
	for Id, Def in pairs(Investigation.Deductions) do
		local Solved = (Story.Deductions or {})[Id] ~= nil
		local Relevant = Solved
		for _, Slot in ipairs(Def.Slots) do if Held(D, Slot.Answer) then Relevant = true end end
		if Relevant then table.insert(List, {Id = Id, Def = Def, Solved = Solved}) end
	end
	table.sort(List, function(A, B)
		if A.Solved ~= B.Solved then return not A.Solved end
		return A.Def.Title < B.Def.Title
	end)
	return List
end

local function CaseClues(D, Def)
	local Q = CaseQuest(Def)
	local List = {}
	for _, E in ipairs(HeldEvidence(D)) do
		if Q == nil or EvidenceDefs[E.Id].Quest == Q then table.insert(List, E.Id) end
	end
	return List
end

local function CaseList(D, Cases)
	Kit:Heading(("%d %s"):format(#Cases, #Cases == 1 and "case" or "cases"))
	for _, E in ipairs(Cases) do
		-- (the clue count shows on the board itself; the list stays readable in its narrow column)
		local Row = Kit:Row(E.Def.Title .. (E.Solved and "  (solved)" or ""), 0.92)
		Mark(Row, E.Id == Case.Selected, E.Solved)
		Clickable(Row, function()
			if Case.Selected ~= E.Id then Case.ActiveSlot, Case.Card, Case.Hint = 1, nil, nil end
			Case.Selected, Case.Detail = E.Id, true
			JournalUI.Redraw()
		end)
	end
end

-- a thread between two points of the board (a rotated 1-2 px line; MasteryUI draws its links the same way)
local function Thread(Parent, A, B, Solid)
	local Dlt = B - A
	local L = Instance.new("Frame")
	L.Name = "Thread"
	L.BorderSizePixel = 0
	L.BackgroundColor3 = MenuKit.Gold
	L.BackgroundTransparency = Solid and 0.15 or 0.5
	L.AnchorPoint = Vector2.new(0.5, 0.5)
	L.Size = UDim2.fromOffset(Dlt.Magnitude, Solid and 2 or 1)
	L.Position = UDim2.fromOffset((A.X + B.X) / 2, (A.Y + B.Y) / 2)
	L.Rotation = math.deg(math.atan2(Dlt.Y, Dlt.X))
	L.ZIndex = 1
	L.Parent = Parent
	return L
end

local function NextEmpty(Def, Picks, From)
	for Step = 0, #Def.Slots - 1 do
		local I = (From - 1 + Step) % #Def.Slots + 1
		if not Picks[I] then return I end
	end
	return nil
end

local function DrawBoard(D, Id, Narrow)
	if Narrow then
		local _, C = Kit:Row("", 0.05)
		Kit:Button(C, "< Cases", function() Case.Detail = false JournalUI.Redraw() end)
	end
	local Def = Id and Investigation.Deductions[Id]
	if not Def then
		Kit:Paragraph("Pick a case from the list.", 2)
		return
	end
	local Story = D.Story or {}
	local Solved = (Story.Deductions or {})[Id] ~= nil
	local Clues = CaseClues(D, Def)
	local _, HC = Kit:Row(Def.Title, 0.62)
	Kit.Rows:FindFirstChild("Row" .. Kit.Order).Title.TextColor3 = MenuKit.Gold
	Kit:Label(HC, Solved and "SOLVED" or (("%d %s"):format(#Clues, #Clues == 1 and "CLUE" or "CLUES")), 0.34).Head.TextColor3 = Solved and MenuKit.Gold or TEXT_ON
	Kit:Paragraph(Def.Question or "", Units(Def.Question, Narrow))
	Picks[Id] = Picks[Id] or {}
	local P = Picks[Id]
	for I in pairs(P) do if not Held(D, P[I]) then P[I] = nil end end
	if Solved then for I, Slot in ipairs(Def.Slots) do P[I] = Slot.Answer end end
	if not Solved then
		Kit:Row(Case.Card and "Now pick the line it answers." or "Pick a line, then the clue that answers it.", 0.92).Title.TextColor3 = DIM_TEXT
	end

	-- the board: clue cards, the case's lines under them, threads between
	local Col = Kit.Rows
	local W = math.floor(Col.AbsoluteSize.X * 0.94)
	if W < 120 then W = 300 end
	local RowH = math.max(34, Col.AbsoluteSize.Y * 0.0913)
	local Cols = W >= 330 and 3 or 2
	local Gap = 8
	local CardW = (W - Gap * (Cols - 1)) / Cols
	local CardH = math.floor(RowH * 1.2)
	local CardRows = math.max(1, math.ceil(#Clues / Cols))
	local SlotTop = CardRows * (CardH + Gap) + 16
	local SlotH = math.floor(RowH * 1.15) -- a little taller: a case's line labels can run to two lines
	Kit.Order += 1
	local Board = Instance.new("Frame")
	Board.Name = "Board"
	Board.BackgroundTransparency = 1
	Board.Size = UDim2.fromOffset(W, SlotTop + #Def.Slots * (SlotH + 5))
	Board.LayoutOrder = Kit.Order
	if Kit.Quiet then Board:SetAttribute("NoPop", true) end
	Board.Parent = Col
	local Font = Kit.RowProto.Title.FontFace

	local Anchor = {}
	local Art = CardImage()
	for I, EId in ipairs(Clues) do
		local X = ((I - 1) % Cols) * (CardW + Gap)
		local Y = math.floor((I - 1) / Cols) * (CardH + Gap)
		local Pinned = {}
		for S = 1, #Def.Slots do if P[S] == EId then table.insert(Pinned, tostring(S)) end end
		local Picked = Case.Card == EId
		local Card = Instance.new("ImageButton")
		Card.Name = "Clue_" .. EId
		Card.AutoButtonColor = not Solved
		Card.BackgroundTransparency = 1
		if Art then
			Card.Image, Card.ScaleType, Card.SliceCenter = Art.Image, Art.ScaleType, Art.SliceCenter
		else
			Card.BackgroundTransparency, Card.BackgroundColor3 = 0.2, Color3.fromRGB(20, 18, 16)
		end
		Card.ScaleType = Enum.ScaleType.Stretch
		Card.ImageColor3 = (Picked or #Pinned > 0) and Color3.fromRGB(255, 226, 150) or Color3.new(1, 1, 1)
		Card.Size = UDim2.fromOffset(CardW, CardH)
		Card.Position = UDim2.fromOffset(X, Y)
		Card.ZIndex = 3
		Card.Parent = Board
		if Picked then
			local Stroke = Instance.new("UIStroke")
			Stroke.Color = MenuKit.Gold
			Stroke.Thickness = 2
			Stroke.Parent = Card
		end
		local T = Instance.new("TextLabel")
		T.BackgroundTransparency = 1
		T.Size = UDim2.new(1, -16, 1, -10)
		T.Position = UDim2.fromOffset(8, 5)
		T.FontFace = Font
		T.Text = EvidenceDefs[EId].Title
		T.TextWrapped = true
		T.TextScaled = true
		T.TextColor3 = (#Pinned > 0 or Picked) and MenuKit.Gold or TEXT_ON
		T.ZIndex = 4
		T.Parent = Card
		local Cap = Instance.new("UITextSizeConstraint")
		Cap.MaxTextSize = 14
		Cap.Parent = T
		if #Pinned > 0 then
			local Badge = Kit.BoxProto:Clone()
			Badge.Name = "Pinned"
			Badge.Head.Text = table.concat(Pinned, ",")
			Badge.Active, Badge.AutoButtonColor = false, false
			Badge.AnchorPoint = Vector2.new(1, 0)
			Badge.Position = UDim2.new(1, 2, 0, -6)
			Badge.Size = UDim2.fromOffset(math.max(28, 14 * #Pinned), 22)
			Badge.Head.TextScaled = true
			Badge.ZIndex = 6
			for _, X2 in ipairs(Badge:GetDescendants()) do if X2:IsA("GuiObject") then X2.ZIndex = 7 end end
			Badge.Parent = Card
		end
		Anchor[EId] = Vector2.new(X + CardW / 2, Y + CardH)
		Card.Activated:Connect(function()
			if Solved then
				Case.Card = (Case.Card ~= EId) and EId or nil
			elseif Case.ActiveSlot then
				P[Case.ActiveSlot] = EId
				Case.Card = nil
				Case.ActiveSlot = NextEmpty(Def, P, Case.ActiveSlot) -- on to the next empty line
			else
				Case.Card = (Case.Card ~= EId) and EId or nil
			end
			Case.Hint = nil
			JournalUI.Redraw()
		end)
	end

	for I, Slot in ipairs(Def.Slots) do
		local Y = SlotTop + (I - 1) * (SlotH + 5)
		local R = Kit.RowProto:Clone()
		R.Name = "Line" .. I
		R.AnchorPoint = Vector2.zero -- (the journal's rows are centred for its list layout)
		R.Size = UDim2.fromOffset(W, SlotH)
		R.Position = UDim2.fromOffset(0, Y)
		R.ZIndex = 3
		R.Visible = true
		R:SetAttribute("NoPop", true)
		R.Title.Text = ("%d. %s"):format(I, Slot.Label)
		R.Title.Size = UDim2.new(0.4, 0, 0.8, 0) -- the authored title share, clear of the box; wraps to two lines
		R.Title.TextWrapped = true
		local Cap = R.Title:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
		Cap.MaxTextSize = 14
		Cap.Parent = R.Title
		R.Parent = Board
		local Active = not Solved and Case.ActiveSlot == I
		Mark(R, Active)
		local Pick = P[I]
		local Box = Kit:Label(R.Controls, Pick and EvidenceDefs[Pick].Title or (Active and "pick a clue" or "-"), Pick and not Solved and 0.5 or 0.62)
		Box.Head.TextColor3 = Pick and MenuKit.Gold or DIM_TEXT
		if Pick and not Solved then
			Kit:Button(R.Controls, "X", function()
				P[I] = nil
				Case.ActiveSlot = I
				JournalUI.Redraw()
			end, true, 0.12)
		end
		if not Solved then
			Clickable(R, function()
				if Case.Card then
					P[I] = Case.Card
					Case.Card = nil
					Case.ActiveSlot = NextEmpty(Def, P, I)
				else
					Case.ActiveSlot = I
				end
				Case.Hint = nil
				JournalUI.Redraw()
			end)
			R.Pick.Size = UDim2.fromScale(0.56, 1) -- the title side, so the X button stays clickable
		end
		-- the thread from the pinned card down to this line's box
		if Pick and Anchor[Pick] then Thread(Board, Anchor[Pick], Vector2.new(W * 0.74, Y), Solved) end
	end

	if Solved then
		local R = Kit:Paragraph("Solved: " .. (Def.Conclusion or ""), Units(Def.Conclusion, Narrow))
		R.Title.TextColor3 = MenuKit.Gold
	else
		local Filled = 0
		for I = 1, #Def.Slots do if P[I] then Filled += 1 end end
		local _, C = Kit:Row(("%d of %d lines pinned. Does it hold together?"):format(Filled, #Def.Slots), 0.66)
		local Submit = Kit:Button(C, "Submit", function()
			if Filled < #Def.Slots then
				Case.Hint = "Pin a clue to every line first."
				JournalUI.Redraw()
				return
			end
			local Answers = {}
			for I = 1, #Def.Slots do Answers[I] = P[I] or "" end
			UIState.Request("Investigation", "Deduce", Id, Answers)
		end)
		if Filled < #Def.Slots then Submit.ImageTransparency = 0.5 end
		local Note = Case.Hint or (Results[Id] and not Results[Id].Ok and Results[Id].Text)
		if Note then Kit:Paragraph(Note, 2).Title.TextColor3 = RED_TEXT end
	end
	-- the picked card's own words (inspect without pinning)
	if Case.Card and EvidenceDefs[Case.Card] then
		local E = EvidenceDefs[Case.Card]
		Kit:Row(E.Title, 0.92).Title.TextColor3 = MenuKit.Gold
		Kit:Paragraph(E.Text or "", Units(E.Text, Narrow))
	end
end

function Draw.CaseBoard(D)
	local Cases = RelevantCases(D)
	if #Cases == 0 then
		if Split then Split.Left.Visible, Split.Right.Visible = false, false end
		Kit.Rows.Visible = true
		Kit:Paragraph("Nothing to piece together yet. Evidence you find will gather here.", 2)
		return
	end
	local Found = false
	for _, E in ipairs(Cases) do if E.Id == Case.Selected then Found = true end end
	if not Found then Case.Selected, Case.ActiveSlot, Case.Card = Cases[1].Id, 1, nil end
	if Wide() then
		local S, Restore = UseSplit(0.34)
		Into(S.Left, function() CaseList(D, Cases) end)
		Into(S.Right, function() DrawBoard(D, Case.Selected, false) end)
		Restore()
	elseif Case.Detail then
		DrawBoard(D, Case.Selected, true)
	else
		CaseList(D, Cases)
	end
end

-- ===== the Identities register: subjects grouped by stage, and one subject's record =====
-- The record keeps what's certain apart from what isn't: Confirmed (a name from an introduction or a
-- correct naming), Seen (what you watched them do or wear) and Leads (evidence that only might fit).
local LIST_ORDER = {"Investigated", "Identified", "Suspected", "Observed", "Unknown"}
local GROUP_TITLE = {Suspected = "SUSPECTED  (CAN BE NAMED)"}
local TRACK = {"Observed", "Suspected", "Identified", "Investigated"}
local TRACK_OFF = Color3.fromRGB(95, 90, 82)

local function Records(D) return ((D.Identities or {}).Records) or {} end
local function Named(R) return (R.Name or "") ~= "" end

local function DrawList(D)
	local List = SortedRecords(D)
	Kit:Heading(#List > 0 and ("%d %s"):format(#List, #List == 1 and "subject" or "subjects") or "No subjects yet.")
	if #List == 0 then
		Kit:Paragraph("People you fight, or watch work alchemy, get a record here. A name only comes from an introduction or from naming them right.", 3)
		return
	end
	local Groups = {}
	for _, E in ipairs(List) do
		local S = Identities.Stage(E.R)
		Groups[S] = Groups[S] or {}
		table.insert(Groups[S], E)
	end
	for _, S in ipairs(LIST_ORDER) do
		if Groups[S] then
			local Sub = Kit:Row(GROUP_TITLE[S] or S:upper(), 0.92)
			Sub.ImageTransparency = 0.8
			Sub.Title.TextColor3 = DIM_TEXT
			for _, E in ipairs(Groups[S]) do
				local Row = Kit:Row(Named(E.R) and E.R.Name or Identities.Number(E.R), 0.92)
				Mark(Row, E.Key == Ident.Selected, not Named(E.R))
				Clickable(Row, function()
					Ident.Selected, Ident.Detail = E.Key, true
					JournalUI.Redraw()
				end)
			end
		end
	end
end

-- Observed > Suspected > Identified > Investigated: a bar per stage, lit up to where the record is
local function StageTrack(Stage)
	local R = Kit:Row("", 0.02, 1.3)
	R.ImageTransparency = 0.35
	local At = (table.find(Identities.Stages, Stage) or 1) - 1 -- 0 (Unknown) to 4 (Investigated)
	for I, Name in ipairs(TRACK) do
		local Done, Here = I <= At, I == At
		local X = 0.04 + (I - 1) * 0.235
		local Bar = Instance.new("Frame")
		Bar.Name = "Step" .. I
		Bar.BorderSizePixel = 0
		Bar.BackgroundColor3 = Done and MenuKit.Gold or TRACK_OFF
		Bar.BackgroundTransparency = (Done and not Here) and 0.45 or 0
		Bar.Position = UDim2.new(X, 0, 0.28, 0)
		Bar.Size = UDim2.new(0.215, 0, 0, Here and 4 or 2)
		Bar.ZIndex = R.ZIndex + 2
		Bar.Parent = R
		local T = Instance.new("TextLabel")
		T.Name = "Name" .. I
		T.BackgroundTransparency = 1
		T.FontFace = R.Title.FontFace
		T.Text = Name
		T.TextScaled = true
		T.TextColor3 = Here and MenuKit.Gold or (Done and TEXT_ON or DIM_TEXT)
		T.Position = UDim2.new(X, 0, 0.42, 0)
		T.Size = UDim2.new(0.215, 0, 0.36, 0)
		T.ZIndex = R.ZIndex + 2
		T.Parent = R
		local Cap = Instance.new("UITextSizeConstraint")
		Cap.Name = "Cap"
		Cap.MaxTextSize = 14
		Cap.Parent = T
	end
	-- one text size for all four (the longest name sets it), so the track reads evenly
	local function Even()
		local Size = R:FindFirstChild("Name4") and R.Name4.TextBounds.Y or 0
		if Size <= 0 then return false end
		for I = 1, #TRACK do R["Name" .. I].Cap.MaxTextSize = math.min(14, math.floor(Size)) end
		return true
	end
	if not Even() then task.defer(Even) end
	return R
end

-- one line of the record: what it is on the left, the value in a box on the right
local function Fact(Label, Value, Color)
	local Row, C = Kit:Row(Label, 0.34)
	Kit:Label(C, Value, 0.62).Head.TextColor3 = Color or TEXT_ON
	return Row
end

local function Capital(S) return (S:gsub("^an? ", ""):gsub("^%l", string.upper)) end
local FactValue = {
	Technique = function(V) return Capital(V) .. " alchemy" end,
	Weapon = Capital,
	Dress = Capital,
}

local function DrawRecord(D, Key, Narrow)
	if Narrow then
		local _, C = Kit:Row("", 0.05)
		Kit:Button(C, "< Back", function() Ident.Detail = false JournalUI.Redraw() end)
	end
	local R = Key and Records(D)[Key]
	if not R then
		Kit:Paragraph("Pick a subject from the list.", 2)
		return
	end
	local Stage = Identities.Stage(R)
	local Known = Named(R)
	local Head, HC = Kit:Row(Known and R.Name or "Unknown subject", 0.58)
	Head.Title.TextColor3 = MenuKit.Gold
	Kit:Label(HC, Identities.Number(R), 0.38).Head.TextColor3 = DIM_TEXT
	StageTrack(Stage)
	Kit:Paragraph(Identities.StageText[Stage], 2)
	local Next = Identities.NextStep[Stage]
	if Next then Kit:Paragraph("Next: " .. Next, 2).Title.TextColor3 = MenuKit.Gold end

	if Known then
		Kit:Heading("Confirmed")
		Fact("Name", R.Name, MenuKit.Gold)
		Fact("How", R.Src == "Introduced" and "Introduced" or "Named by you")
		if Stage == "Investigated" and R.Standing then Fact("Standing", R.Standing) end
	end

	Kit:Heading("Seen")
	local Kinds = {}
	for Kind, K in pairs(Identities.Kinds) do table.insert(Kinds, {Kind = Kind, K = K}) end
	table.sort(Kinds, function(A, B) return A.K.Order < B.K.Order end)
	for _, E in ipairs(Kinds) do
		local V = (R.Obs or {})[E.Kind]
		if V then Fact(E.K.Label, FactValue[E.Kind](tostring(V))) else Fact(E.K.Label, "Not seen yet", DIM_TEXT) end
	end

	local Links = {}
	for Id in pairs(R.Links or {}) do if EvidenceDefs[Id] then table.insert(Links, Id) end end
	table.sort(Links)
	if #Links > 0 then
		Kit:Heading("Leads  (not proof)")
		for _, Id in ipairs(Links) do
			local Def = EvidenceDefs[Id]
			local Text = ("%s describes %s alchemy, the same as you saw them use."):format(Def.Title, tostring(Def.Technique))
			Kit:Paragraph(Text, Units(Text, Narrow)).Title.TextColor3 = DIM_TEXT
		end
	end

	Kit:Heading(("Encounters  (%d)"):format(R.Seen or 0))
	for _, L in ipairs(R.Log or {}) do
		local _, C = Kit:Row((L.Kind or "Met") .. (L.Area and ("  -  " .. L.Area) or ""), 0.62)
		Kit:Label(C, Ago(L.At), 0.34).Head.TextColor3 = DIM_TEXT
	end

	if not Known then
		Kit:Heading("Name them")
		if os.time() < (R.Lock or 0) then
			Kit:Paragraph(("Wrong name. You can try again in %d min."):format(math.ceil(((R.Lock or 0) - os.time()) / 60)), 2).Title.TextColor3 = RED_TEXT
		elseif not Identities.CanName(R) then
			Kit:Paragraph("Not enough to go on yet: two kinds of detail across two separate encounters. Or they can simply introduce themselves.", 2).Title.TextColor3 = DIM_TEXT
		else
			local Names = {}
			for _, P in ipairs(Players:GetPlayers()) do
				local N = P ~= Players.LocalPlayer and P:GetAttribute("CharacterName")
				if type(N) == "string" and N ~= "" then table.insert(Names, N) end
			end
			table.sort(Names)
			if #Names == 0 then
				Kit:Paragraph("They're not in this world right now. A name can only be confirmed while they're here.", 2).Title.TextColor3 = DIM_TEXT
			else
				local Pick = math.clamp(Ident.Picks[Key] or 1, 1, #Names)
				local _, NC = Kit:Row("Who is it?", 0.28)
				Kit:Cycler(NC, Names, Pick, function(I) Ident.Picks[Key] = I JournalUI.Redraw() end, 0.34)
				Kit:Button(NC, "Name", function() UIState.Request("Investigation", "Identify", Key, Names[Pick]) end)
				Kit:Paragraph(("A wrong name locks this record for %d min."):format(Identities.WrongLock // 60), 2).Title.TextColor3 = DIM_TEXT
			end
		end
		local Result = Ident.Results[Key]
		if Result and not Result.Ok then Kit:Paragraph(Result.Text, 2).Title.TextColor3 = RED_TEXT end
	end
end

function Draw.Identities(D)
	local List = SortedRecords(D)
	if Ident.Selected and not Records(D)[Ident.Selected] then Ident.Selected = nil end
	if not Ident.Selected and List[1] then Ident.Selected = List[1].Key end -- the most recent
	if #List == 0 then
		DrawList(D)
	elseif Wide() then
		local S, Restore = UseSplit(0.38)
		Into(S.Left, function() DrawList(D) end)
		Into(S.Right, function() DrawRecord(D, Ident.Selected, false) end)
		Restore()
	elseif Ident.Detail and Ident.Selected then
		DrawRecord(D, Ident.Selected, true)
	else
		DrawList(D)
	end
end

local TabDraw = {Quests = Draw.Quests, Evidence = Draw.Evidence, ["Case Board"] = Draw.CaseBoard, Codex = Draw.Codex, Identities = Draw.Identities}

-- Animate: only on open and tab changes (UIMotion pops rows); data refreshes swap rows in place
function JournalUI.Redraw(Animate)
	local D = Data()
	if not Kit or not D or not D.Quests then return end
	Kit:Clear(Animate)
	Animating = Animate == true
	Kit.Rows.Visible = true -- the split layout (Identities, Evidence, Case Board) hides it again
	if Split then Split.Left.Visible, Split.Right.Visible = false, false end
	TabDraw[Kit.Tab](D)
	if not Animate then Kit:KeepScroll() end
	-- the Evidence tab counts clues you haven't looked at yet
	local EvTab = Kit.Sections:FindFirstChild("Evidence")
	local New = NewCount(D)
	if EvTab and EvTab:FindFirstChild("Head") then EvTab.Head.Text = New > 0 and ("Evidence (%d)"):format(New) or "Evidence" end
end

function JournalUI.Start()
	Kit = MenuKit.new("Journal", "JOURNAL", {"Quests", "Evidence", "Case Board", "Codex", "Identities"}, function()
		JournalUI.Redraw(true)
	end)
	UIState.RegisterMenu("Journal", Kit.Root, function() JournalUI.Redraw(true) end)
	-- clues held when you join count as seen; later ones are NEW until you look at them (this session)
	local function NoteSeen()
		local D = Data()
		if Ev.Seen or not D or not D.Story then return end
		Ev.Seen = {}
		for Id in pairs(D.Story.Evidence or {}) do Ev.Seen[Id] = true end
	end
	NoteSeen()
	UIState.Changed:Connect(function()
		NoteSeen()
		if Kit.Root.Visible then JournalUI.Redraw() end
	end)
	-- the split layout depends on the screen width
	local Camera = workspace.CurrentCamera
	if Camera then
		local WasWide = nil
		Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			local Now = Camera.ViewportSize.X >= 1000
			if Now ~= WasWide then WasWide = Now if Kit.Root.Visible then JournalUI.Redraw() end end
		end)
	end
	UIState.On("CaseResult", function(P)
		Results[P.Id] = {Ok = P.Ok, Text = P.Text}
		if not P.Ok then UIState.Emit("Toast", {Text = P.Text}) end
		if Kit.Root.Visible then JournalUI.Redraw() end
	end)
	UIState.On("IdentifyResult", function(P)
		Ident.Results[P.Id] = {Ok = P.Ok, Text = P.Text}
		if not P.Ok then UIState.Emit("Toast", {Text = P.Text}) end
		if Kit.Root.Visible then JournalUI.Redraw() end
	end)
	-- the Introduce prompt is on every character; your own is never shown to you (IdentityService)
	local function HideOwnPrompt(Character)
		local Root = Character:WaitForChild("HumanoidRootPart", 10)
		local Prompt = Root and Root:WaitForChild("IntroducePrompt", 20)
		if not Prompt then return end
		Prompt.Enabled = false
		Prompt:GetPropertyChangedSignal("Enabled"):Connect(function() if Prompt.Enabled then Prompt.Enabled = false end end)
	end
	if Players.LocalPlayer.Character then task.spawn(HideOwnPrompt, Players.LocalPlayer.Character) end
	Players.LocalPlayer.CharacterAdded:Connect(function(C) task.spawn(HideOwnPrompt, C) end)
	ContextActionService:BindAction("RenseiJournal", function(_, State)
		if State == Enum.UserInputState.Begin then UIState.ToggleMenu("Journal") end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.J)
	ContextActionService:SetTitle("RenseiJournal", "Journal")
	ContextActionService:SetPosition("RenseiJournal", UDim2.new(1, -70 - 5 * 62, 0, 10))
end

return JournalUI

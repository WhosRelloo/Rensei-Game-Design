-- CompassUI (owner 2026-10-18): a minimal directional compass strip at the top of the screen. The combat log
-- badge drops in just under it (CombatLogUI.TopY). Deliberately sparse, at most three marks:
--   * one gold diamond: the tracked quest's nearest unfinished objective (the Journal's tracked quest, else the
--     oldest active one). It stays pinned to the strip's edge when it's behind you, so you can always turn to it.
--   * up to two faint rings: the nearest areas you haven't discovered yet, within AREA_RANGE. Their names stay
--     hidden ("Unexplored") until the discovery popup reveals them.
-- A name and distance appear under the strip only for the mark nearest the centre of view.
-- Where things are comes from ReplicatedStorage.CompassPoints (CompassService); what matters to you comes from
-- your profile copy (UIState.Data). Hidden during menus, dialogue, cutscenes and death; Settings > Compass
-- turns it off. North is world -Z.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIState = require(script.Parent.UIState)
local QuestDefs = require(ReplicatedStorage.Modules.Data.Rensei.Quests)
local StoryLogic = require(ReplicatedStorage.Modules.Data.Rensei.StoryLogic)
local PuzzleData = require(ReplicatedStorage.Modules.Data.Rensei.Puzzles)
local PuzzleDefs = PuzzleData.Puzzles or PuzzleData

local Player = Players.LocalPlayer

-- PROPOSAL numbers
local SPAN = 150 -- degrees of view across the strip
local AREA_RANGE = 320 -- unexplored areas within this many studs (from their edge) get a ring
local MAX_AREAS = 2
local ARRIVED = 14 -- a mark hides once you're this close
local LABEL_WITHIN = 9 -- degrees from the centre for a mark's name to show
local REFRESH = 0.5 -- seconds between target picks (drawing is every frame)
local TOP, STRIP_H, LABEL_H = 6, 18, 14

local INK = Color3.fromRGB(236, 228, 206)
local GOLD = Color3.fromRGB(222, 184, 104)
local FONT = Font.new("rbxasset://fonts/families/Guru.json", Enum.FontWeight.Bold)
local FONT_LABEL = Font.new("rbxasset://fonts/families/Guru.json", Enum.FontWeight.Medium)

local CompassUI = {}

local function Make(Class, Props, Parent)
	local O = Instance.new(Class)
	for K, V in pairs(Props) do O[K] = V end
	O.Parent = Parent
	return O
end

-- ===== build =====
local Gui, Root, Strip, Label, LabelStroke
local Ticks = {} -- {Frame, Angle}
local QuestMark, AreaMarks = nil, {}

local function Build()
	Gui = Make("ScreenGui", {Name = "Compass", ResetOnSpawn = false, DisplayOrder = 5, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, Player:WaitForChild("PlayerGui"))
	Root = Make("CanvasGroup", {Name = "Root", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, TOP),
		Size = UDim2.fromOffset(300, STRIP_H + LABEL_H), BackgroundTransparency = 1, GroupTransparency = 1}, Gui)

	-- the strip: ticks and letters fade out toward both ends, so it never reads as a box
	Strip = Make("CanvasGroup", {Name = "Strip", Size = UDim2.new(1, 0, 0, STRIP_H), BackgroundTransparency = 1}, Root)
	Make("UIGradient", {Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0), NumberSequenceKeypoint.new(0.8, 0),
		NumberSequenceKeypoint.new(1, 1)})}, Strip)
	-- a soft dark band behind the ticks: readable over a bright sky (it fades out with the strip's ends)
	Make("Frame", {Name = "Band", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 10, 12),
		BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 0}, Strip)
	Make("Frame", {Name = "Line", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = INK, BackgroundTransparency = 0.6, BorderSizePixel = 0}, Strip)
	local Cardinal = {[0] = "N", [90] = "E", [180] = "S", [270] = "W"}
	for A = 0, 345, 15 do
		local T
		if Cardinal[A] then
			T = Make("TextLabel", {AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(16, STRIP_H - 2), BackgroundTransparency = 1,
				FontFace = FONT, TextSize = A == 0 and 15 or 13, Text = Cardinal[A], TextColor3 = A == 0 and GOLD or INK,
				TextTransparency = 0.05}, Strip)
			Make("UIStroke", {Thickness = 1, Transparency = 0.2}, T)
		else
			local Major = A % 45 == 0
			T = Make("Frame", {AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(1, Major and 6 or 3), BorderSizePixel = 0,
				BackgroundColor3 = INK, BackgroundTransparency = Major and 0.35 or 0.55}, Strip)
		end
		table.insert(Ticks, {T, A})
	end
	-- the centre notch
	Make("Frame", {Name = "Notch", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(2, 5),
		BackgroundColor3 = GOLD, BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 3}, Root)

	-- marks sit outside the faded strip, so the quest mark stays visible pinned at an edge
	QuestMark = Make("Frame", {Name = "Quest", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(8, 8), Rotation = 45,
		BackgroundColor3 = GOLD, BorderSizePixel = 0, Visible = false, ZIndex = 4}, Root)
	Make("UIStroke", {Thickness = 1, Transparency = 0.35}, QuestMark)
	for I = 1, MAX_AREAS do
		local M = Make("Frame", {Name = "Area" .. I, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(7, 7),
			BackgroundTransparency = 1, Visible = false, ZIndex = 4}, Root)
		Make("UICorner", {CornerRadius = UDim.new(1, 0)}, M)
		Make("UIStroke", {Color = INK, Thickness = 1.3, Transparency = 0.3}, M)
		AreaMarks[I] = M
	end

	Label = Make("TextLabel", {Name = "Label", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, STRIP_H + 1),
		Size = UDim2.fromOffset(220, LABEL_H - 1), BackgroundTransparency = 1, FontFace = FONT_LABEL, TextSize = 12,
		TextColor3 = INK, TextTransparency = 1, Text = "", ZIndex = 4}, Root)
	LabelStroke = Make("UIStroke", {Thickness = 1, Transparency = 1}, Label)
end

-- ===== what to point at =====
local Points = {} -- {Kind, Key, Label, Position, Evidence, Names, Radius}
local function ReadPoints()
	table.clear(Points)
	local Folder = ReplicatedStorage:FindFirstChild("CompassPoints")
	if not Folder then return end
	for _, F in ipairs(Folder:GetChildren()) do
		local A = F:GetAttributes()
		if A.Kind and typeof(A.Position) == "Vector3" then table.insert(Points, A) end
	end
end

local function Matching(Kind, Test)
	local Out = {}
	for _, P in ipairs(Points) do
		if P.Kind == Kind and Test(P) then table.insert(Out, P) end
	end
	return Out
end

-- the places that can complete one objective (empty for objectives done in the Journal: Deduce, Signal...)
local function Candidates(O)
	local T = tostring(O.Target or "")
	if O.Kind == "Visit" then return Matching("Area", function(P) return P.Key == T end) end
	if O.Kind == "Talk" then return Matching("Talk", function(P) return P.Key == T end) end
	if O.Kind == "Evidence" then return Matching("Inspect", function(P) return P.Evidence == T end) end
	if O.Kind == "Minigame" then return Matching("Minigame", function(P) return P.Key == T end) end
	if O.Kind == "Defeat" then return Matching("Spawn", function(P) return (P.Names or ""):find("|" .. T .. "|", 1, true) ~= nil end) end
	if O.Kind == "Mechanism" then
		local Id = T:match("^([^:]+)") or T
		return Matching("Mechanism", function(P) return P.Key == Id end)
	end
	if O.Kind == "Puzzle" then
		local Def = PuzzleDefs[T]
		local Ids = {}
		for _, M in ipairs(type(Def) == "table" and Def.Mechanisms or {}) do Ids[type(M) == "table" and (M.Id or M[1]) or M] = true end
		return Matching("Mechanism", function(P) return Ids[P.Key] == true end)
	end
	if O.Kind == "Flag" then
		local Trial = T:match("^Trial_(.+)")
		if Trial then return Matching("Trial", function(P) return P.Key == Trial end) end
	end
	return {}
end

local function TrackedQuest(D)
	local Active = D.Quests and D.Quests.Active
	if not Active then return end
	local Id = D.Quests.Tracked
	if Id and Id ~= "" and Active[Id] and QuestDefs[Id] then return Id end
	local Best
	for QId, S in pairs(Active) do
		if QuestDefs[QId] and (not Best or (S.Started or 0) < (Active[Best].Started or 0)) then Best = QId end
	end
	return Best
end

local function PickQuest(D, From)
	local Id = TrackedQuest(D)
	if not Id then return end
	local Def, State = QuestDefs[Id], D.Quests.Active[Id]
	local Best, BestD
	local function Consider(List)
		for _, P in ipairs(List) do
			local Dist = (P.Position - From).Magnitude
			if not BestD or Dist < BestD then Best, BestD = P, Dist end
		end
	end
	local Ok, Visible = pcall(StoryLogic.Visible, Def, State)
	for _, O in ipairs(Ok and Visible or {}) do
		if (State.Progress[O.Id] or 0) < (O.Count or 1) then Consider(Candidates(O)) end
	end
	-- nothing placeable (a Journal step): point home, the quest's first area, unless you're already there
	if not Best then
		local Ok2, Stages = pcall(StoryLogic.Stages, Def)
		for _, St in ipairs(Ok2 and Stages or {}) do
			for _, O in ipairs(St.Objectives or {}) do
				if O.Kind == "Visit" and not Best and Player:GetAttribute("Area") ~= O.Target then Consider(Candidates(O)) end
			end
		end
	end
	return Best
end

local function PickAreas(D, From, Skip)
	local Seen, Nearest = D.Areas or {}, {}
	for _, P in ipairs(Points) do
		if P.Kind == "Area" and not Seen[P.Key] and P ~= Skip then
			local Dist = math.max(0, (P.Position - From).Magnitude - (P.Radius or 0))
			if Dist <= AREA_RANGE and (not Nearest[P.Key] or Dist < Nearest[P.Key].D) then Nearest[P.Key] = {P = P, D = Dist} end
		end
	end
	local List = {}
	for _, E in pairs(Nearest) do table.insert(List, E) end
	table.sort(List, function(A, B) return A.D < B.D end)
	local Out = {}
	for I = 1, math.min(MAX_AREAS, #List) do Out[I] = List[I].P end
	return Out
end

-- ===== draw =====
local QuestTarget, AreaTargets = nil, {}
local Shown = false
local LabelText = ""

local function Hidden()
	if Player:GetAttribute("ShowCompass") == false then return true end
	local G = UIState.Gui
	if (G:FindFirstChild("bg") and G.bg.Visible) or (G:FindFirstChild("Dialogue") and G.Dialogue.Visible) then return true end
	if workspace.CurrentCamera.CameraType == Enum.CameraType.Scriptable then return true end -- cutscenes
	local C = Player.Character
	local H = C and C:FindFirstChildOfClass("Humanoid")
	return not H or H.Health <= 0 or not C:FindFirstChild("HumanoidRootPart")
end

local function SetShown(On)
	if On == Shown then return end
	Shown = On
	TweenService:Create(Root, TweenInfo.new(0.35), {GroupTransparency = On and 0 or 1}):Play()
end

local function Wrap(A) return (A + 180) % 360 - 180 end

local function Draw()
	if Hidden() then SetShown(false) return end
	SetShown(true)
	local Cam = workspace.CurrentCamera
	local W = math.clamp(Cam.ViewportSize.X * 0.34, 220, 360)
	if Root.Size.X.Offset ~= W then Root.Size = UDim2.fromOffset(W, STRIP_H + LABEL_H) end
	local Look = Cam.CFrame.LookVector
	if Look.X * Look.X + Look.Z * Look.Z < 1e-4 then Look = Cam.CFrame.UpVector end -- looking straight down
	local Heading = math.deg(math.atan2(Look.X, -Look.Z))
	local PerDeg = W / SPAN
	local Half = SPAN / 2

	for _, T in ipairs(Ticks) do
		local D = Wrap(T[2] - Heading)
		local On = math.abs(D) <= Half
		T[1].Visible = On
		if On then T[1].Position = UDim2.new(0.5, D * PerDeg, 1, -1) end
	end

	local From = Player.Character.HumanoidRootPart.Position
	local Closest, ClosestD, ClosestText, ClosestGold = nil, LABEL_WITHIN, nil, false
	local function Place(Mark, P, Pin)
		if not P then Mark.Visible = false return end
		local Off = P.Position - From
		local Dist = Vector3.new(Off.X, 0, Off.Z).Magnitude
		if Dist < ARRIVED then Mark.Visible = false return end
		local D = Wrap(math.deg(math.atan2(Off.X, -Off.Z)) - Heading)
		local Edge = math.abs(D) > Half - 4
		if Edge and not Pin then Mark.Visible = false return end
		Mark.Visible = true
		local X = math.clamp(D, -(Half - 4), Half - 4) * PerDeg
		Mark.Position = UDim2.new(0.5, X, 0, STRIP_H / 2)
		if Pin then Mark.Size = Edge and UDim2.fromOffset(6, 6) or UDim2.fromOffset(8, 8) end
		if math.abs(D) < ClosestD then
			Closest, ClosestD = Mark, math.abs(D)
			ClosestText = (Pin and P.Label or "Unexplored") .. "  \u{00B7}  " .. math.floor(Dist + 0.5)
			ClosestGold = Pin
		end
	end
	Place(QuestMark, QuestTarget, true)
	for I, M in ipairs(AreaMarks) do Place(M, AreaTargets[I], false) end

	local Want = Closest and ClosestText or ""
	if Want ~= "" then
		Label.Text = Want
		Label.TextColor3 = ClosestGold and GOLD or INK
		Label.Position = UDim2.new(0.5, math.clamp(Closest.Position.X.Offset, -W / 2 + 110, W / 2 - 110), 0, STRIP_H + 1)
	end
	if (Want ~= "") ~= (LabelText ~= "") then
		TweenService:Create(Label, TweenInfo.new(0.2), {TextTransparency = Want ~= "" and 0.05 or 1}):Play()
		TweenService:Create(LabelStroke, TweenInfo.new(0.2), {Transparency = Want ~= "" and 0.15 or 1}):Play()
	end
	LabelText = Want
end

local function Refresh()
	ReadPoints()
	local D = UIState.Data
	local Root_ = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
	if not D or not Root_ then QuestTarget, AreaTargets = nil, {} return end
	QuestTarget = PickQuest(D, Root_.Position)
	AreaTargets = PickAreas(D, Root_.Position, QuestTarget)
end

function CompassUI.Start()
	Build()
	task.spawn(function()
		while true do
			local Ok, Err = pcall(Refresh)
			if not Ok then warn("[CompassUI] " .. tostring(Err)) end
			task.wait(REFRESH)
		end
	end)
	RunService.RenderStepped:Connect(function()
		local Ok, Err = pcall(Draw)
		if not Ok then
			SetShown(false)
			if not CompassUI._Warned then CompassUI._Warned = true warn("[CompassUI] " .. tostring(Err)) end
		end
	end)
end

-- exposed for tests
CompassUI.Debug = function() return {Quest = QuestTarget, Areas = AreaTargets, Points = #Points, Shown = Shown, Label = LabelText} end

return CompassUI

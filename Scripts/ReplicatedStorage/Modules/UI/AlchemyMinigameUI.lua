-- AlchemyMinigameUI: the client panels for the alchemy trainers' minigame kinds (rules:
-- Rensei.AlchemyMinigames, shared with the server). MinigameUI calls Builders[Kind](Ctx, Def, Params);
-- each returns Answer() (what "submit" sends) and Reset(). The panels preview every move with the shared
-- Simulate functions; the server re-runs the same rules on submit, so a preview can never claim a pass.
-- Every control is a kit button (click or tap), so the panels work the same on PC and mobile.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Rules = require(ReplicatedStorage.Modules.Data.Rensei.AlchemyMinigames)

local Builders = {}

local DIM = Color3.fromRGB(150, 145, 135)
local DARK = Color3.fromRGB(28, 26, 26)
local EDGE = Color3.fromRGB(90, 80, 60)

-- a horizontal 0..100 gauge with a green band, red danger zones and a needle
local function Gauge(Ctx, Label, Y, Band, DangerAbove, DangerBelow)
	local C = Ctx
	C.Text(C.Canvas, Label, UDim2.fromScale(0.04, Y), UDim2.fromScale(0.3, 0.045), C.GOLD).TextXAlignment = Enum.TextXAlignment.Left
	local Value = C.Text(C.Canvas, "", UDim2.fromScale(0.7, Y), UDim2.fromScale(0.26, 0.045))
	Value.TextXAlignment = Enum.TextXAlignment.Right
	local Track = C.Make("Frame", {Position = UDim2.fromScale(0.04, Y + 0.05), Size = UDim2.fromScale(0.92, 0.05),
		BackgroundColor3 = DARK, BorderSizePixel = 0}, C.Canvas)
	C.Make("UIStroke", {Color = EDGE, Thickness = 1.5}, Track)
	if DangerAbove then
		C.Make("Frame", {Position = UDim2.fromScale(DangerAbove / 100, 0), Size = UDim2.fromScale(1 - DangerAbove / 100, 1),
			BackgroundColor3 = Color3.fromRGB(150, 40, 35), BorderSizePixel = 0, BackgroundTransparency = 0.25}, Track)
	end
	if DangerBelow then
		C.Make("Frame", {Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(DangerBelow / 100, 1),
			BackgroundColor3 = Color3.fromRGB(150, 40, 35), BorderSizePixel = 0, BackgroundTransparency = 0.25}, Track)
	end
	C.Make("Frame", {Position = UDim2.fromScale(Band[1] / 100, 0), Size = UDim2.fromScale((Band[2] - Band[1]) / 100, 1),
		BackgroundColor3 = Color3.fromRGB(70, 150, 80), BorderSizePixel = 0, BackgroundTransparency = 0.15}, Track)
	local Ghost = C.Make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(0, 3, 1.3, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 3}, Track)
	local Needle = C.Make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(0, 4, 1.7, 0),
		BackgroundColor3 = C.GOLD, BorderSizePixel = 0, ZIndex = 4}, Track)
	return function(Now, Next)
		local InBand = Now >= Band[1] and Now <= Band[2]
		TweenService:Create(Needle, TweenInfo.new(0.25, Enum.EasingStyle.Back), {Position = UDim2.fromScale(math.clamp(Now / 100, 0, 1), 0.5)}):Play()
		Needle.BackgroundColor3 = InBand and Color3.fromRGB(120, 230, 130) or C.GOLD
		Ghost.Visible = Next ~= nil
		if Next then Ghost.Position = UDim2.fromScale(math.clamp(Next / 100, 0, 1), 0.5) end
		Value.Text = Next and ("%d  ->  %d"):format(Now, Next) or tostring(Now)
		Value.TextColor3 = InBand and C.GREEN or Color3.fromRGB(225, 220, 210)
	end
end

-- a row of choice buttons; returns Set(value) to highlight one
local function Choice(Ctx, Label, Y, Options, OnPick)
	local C = Ctx
	C.Text(C.Canvas, Label, UDim2.fromScale(0.04, Y), UDim2.fromScale(0.18, 0.06), C.GOLD).TextXAlignment = Enum.TextXAlignment.Left
	local Buttons = {}
	for I, O in ipairs(Options) do
		local X = 0.22 + (I - 0.5) * (0.74 / #Options)
		Buttons[I] = C.KitButton(C.Canvas, O.Label, UDim2.fromScale(X, Y + 0.03), UDim2.fromScale(0.72 / #Options - 0.02, 0.07), function() OnPick(O.Value) end)
	end
	return function(Value)
		-- the chosen option: gold text (the kit button's own art stays as it is)
		for I, O in ipairs(Options) do
			Buttons[I].Head.TextColor3 = O.Value == Value and C.GOLD or Color3.fromRGB(150, 145, 135)
		end
	end
end

-- ===== ReactionControl (Flame) =====
function Builders.ReactionControl(Ctx, Def, P)
	local C = Ctx
	local RC = Rules.ReactionControl
	local Moves = {}
	local Heat, Vent = 0, 0
	C.Text(C.Canvas, Def.Hint, UDim2.fromScale(0.04, 0.0), UDim2.fromScale(0.92, 0.1))
	local TempGauge = Gauge(C, "HEAT", 0.11, P.Ign, P.MaxT, nil)
	local AirGauge = Gauge(C, "AIR", 0.24, P.Air, nil, P.MinO)
	local TurnLabel = C.Text(C.Canvas, "", UDim2.fromScale(0.04, 0.37), UDim2.fromScale(0.5, 0.045))
	TurnLabel.TextXAlignment = Enum.TextXAlignment.Left
	local Legend = C.Text(C.Canvas, ("Raise +%d, Hold +%d, Lower %d heat.  Vent open: %d heat, +%d air.  Vent closed: %d air.")
		:format(RC.Effects.Heat[1], RC.Effects.Heat[0], RC.Effects.Heat[-1], RC.Effects.VentOpen.T, RC.Effects.VentOpen.O, RC.Effects.VentClosed.O),
		UDim2.fromScale(0.04, 0.42), UDim2.fromScale(0.92, 0.05), DIM)
	Legend.TextXAlignment = Enum.TextXAlignment.Left
	local History = C.Text(C.Canvas, "", UDim2.fromScale(0.04, 0.73), UDim2.fromScale(0.92, 0.05), DIM)

	local SetHeat, SetVent
	local Failed = nil
	local function Paint()
		local R = RC.Simulate(P, Moves)
		local Now = R.States[#R.States]
		local Preview
		if not R.Fail and #Moves < P.Turns then
			local Try = table.clone(Moves)
			table.insert(Try, {Heat, Vent})
			local N = RC.Simulate(P, Try)
			Preview = N.States[#N.States]
		end
		TempGauge(Now.T, Preview and Preview.T)
		AirGauge(Now.O, Preview and Preview.O)
		TurnLabel.Text = ("Turn %d of %d"):format(#Moves, P.Turns)
		local Words = {}
		for I, M in ipairs(Moves) do
			table.insert(Words, ({[-1] = "Lower", [0] = "Hold", [1] = "Raise"})[M[1]] .. (M[2] == 1 and "+vent" or ""))
		end
		History.Text = #Words > 0 and table.concat(Words, "  >  ") or "No turns taken yet."
		Failed = R.Fail
		if R.Fail then C.Result(R.Fail .. " Reset to try again.", C.RED) end
		SetHeat(Heat)
		SetVent(Vent)
	end
	SetHeat = Choice(C, "HEAT", 0.49, {{Label = "Lower", Value = -1}, {Label = "Hold", Value = 0}, {Label = "Raise", Value = 1}},
		function(V) Heat = V Paint() end)
	SetVent = Choice(C, "VENT", 0.59, {{Label = "Closed", Value = 0}, {Label = "Open", Value = 1}}, function(V) Vent = V Paint() end)
	C.KitButton(C.Canvas, "Next Turn", UDim2.fromScale(0.5, 0.82), UDim2.fromScale(0.32, 0.07), function()
		if Failed then return end
		if #Moves >= P.Turns then C.Result("No turns left: ignite now, or reset.", C.RED) return end
		table.insert(Moves, {Heat, Vent})
		C.Result("", C.GOLD)
		Paint()
	end)
	Paint()
	return function()
		if #Moves == 0 then return nil end
		return {Moves = Moves}
	end, function()
		table.clear(Moves)
		Heat, Vent = 0, 0
		C.Result("", C.GOLD)
		Paint()
	end
end

-- a small labelled tile (pipes, columns, vents)
local function Tile(Ctx, Parent, Pos, Size, Color, Label)
	local C = Ctx
	local F = C.Make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = Pos, Size = Size, BackgroundColor3 = Color, BorderSizePixel = 0}, Parent)
	C.Make("UIStroke", {Color = EDGE, Thickness = 1.5}, F)
	local L = C.Text(F, Label or "", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
	return F, L
end

-- ===== PhaseSequence (Ice) =====
local WATER = Color3.fromRGB(40, 80, 120)
local ICE = Color3.fromRGB(175, 220, 245)
function Builders.PhaseSequence(Ctx, Def, P)
	local Paint -- (set below; the buttons call it)
	local C = Ctx
	local PS = Rules.PhaseSequence
	local Moves = {}
	C.Text(C.Canvas, Def.Hint, UDim2.fromScale(0.04, 0.0), UDim2.fromScale(0.92, 0.1))
	local Legend = C.Text(C.Canvas, "Freeze: that pipe, and frost spreads one pipe DOWNSTREAM (right).  Thaw: that pipe, and meltwater runs one pipe UPSTREAM (left).  Three ice pipes in a row crack.",
		UDim2.fromScale(0.04, 0.1), UDim2.fromScale(0.92, 0.08), DIM)
	C.Text(C.Canvas, "NEEDED", UDim2.fromScale(0.04, 0.2), UDim2.fromScale(0.2, 0.045), C.GOLD).TextXAlignment = Enum.TextXAlignment.Left
	C.Text(C.Canvas, "NOW", UDim2.fromScale(0.04, 0.34), UDim2.fromScale(0.2, 0.045), C.GOLD).TextXAlignment = Enum.TextXAlignment.Left
	local Now = {}
	for I = 1, P.N do
		local X = 0.1 + (I - 0.5) * (0.84 / P.N)
		Tile(C, C.Canvas, UDim2.fromScale(X, 0.28), UDim2.fromScale(0.84 / P.N - 0.02, 0.06), P.Target[I] and ICE or WATER, P.Target[I] and "ice" or "water")
		Now[I] = {Tile(C, C.Canvas, UDim2.fromScale(X, 0.43), UDim2.fromScale(0.84 / P.N - 0.02, 0.09), WATER, "")}
		C.KitButton(C.Canvas, "Freeze", UDim2.fromScale(X, 0.55), UDim2.fromScale(0.84 / P.N - 0.02, 0.065), function()
			table.insert(Moves, {I, "F"}) C.Result("", C.GOLD) Paint()
		end)
		C.KitButton(C.Canvas, "Thaw", UDim2.fromScale(X, 0.63), UDim2.fromScale(0.84 / P.N - 0.02, 0.065), function()
			table.insert(Moves, {I, "T"}) C.Result("", C.GOLD) Paint()
		end)
	end
	local MovesLabel = C.Text(C.Canvas, "", UDim2.fromScale(0.04, 0.71), UDim2.fromScale(0.92, 0.05))
	Paint = function()
		local R = PS.Simulate(P, Moves)
		local S = R.States[#R.States]
		for I = 1, P.N do
			Now[I][1].BackgroundColor3 = S[I] and ICE or WATER
			Now[I][2].Text = S[I] and "ice" or "water"
			Now[I][2].TextColor3 = (S[I] or false) == (P.Target[I] or false) and C.GREEN or Color3.fromRGB(225, 220, 210)
		end
		MovesLabel.Text = ("Moves %d of %d"):format(#Moves, P.MaxMoves)
		if R.Fail then C.Result(R.Fail .. " Reset to try again.", C.RED)
		elseif #Moves > P.MaxMoves then C.Result("Too many moves. Reset.", C.RED) end
	end
	Paint()
	return function() if #Moves == 0 then return nil end return {Moves = Moves} end,
		function() table.clear(Moves) C.Result("", C.GOLD) Paint() end
end

-- ===== LoadPaths (Earth) =====
function Builders.LoadPaths(Ctx, Def, P)
	local Paint -- (set below; the buttons call it)
	local C = Ctx
	local LP = Rules.LoadPaths
	local Supports = {}
	C.Text(C.Canvas, Def.Hint, UDim2.fromScale(0.04, 0.0), UDim2.fromScale(0.92, 0.1))
	C.Text(C.Canvas, ("Each load rests on its NEAREST support (a tie splits it). A support reaches %d columns either side, holds %d, and sinks on soft ground. You have %d.")
		:format(P.Span, P.Capacity, P.K), UDim2.fromScale(0.04, 0.1), UDim2.fromScale(0.92, 0.08), DIM)
	local Beam = C.Make("Frame", {Position = UDim2.fromScale(0.06, 0.32), Size = UDim2.fromScale(0.88, 0.035), BackgroundColor3 = Color3.fromRGB(120, 95, 70), BorderSizePixel = 0}, C.Canvas)
	C.Make("UIStroke", {Color = EDGE, Thickness = 1.5}, Beam)
	local Cols = {}
	for I = 1, P.N do
		local X = 0.06 + (I - 0.5) * (0.88 / P.N)
		local W = 0.88 / P.N - 0.015
		-- the load sitting on the beam
		if (P.Loads[I] or 0) > 0 then
			Tile(C, C.Canvas, UDim2.fromScale(X, 0.27), UDim2.fromScale(W * 0.8, 0.045 + P.Loads[I] * 0.006), Color3.fromRGB(95, 80, 60), tostring(P.Loads[I]))
		end
		-- the ground under it
		Tile(C, C.Canvas, UDim2.fromScale(X, 0.58), UDim2.fromScale(W, 0.05), P.Soft[I] and Color3.fromRGB(95, 70, 45) or Color3.fromRGB(70, 70, 72), P.Soft[I] and "soft" or "rock")
		local Post, PostLabel = Tile(C, C.Canvas, UDim2.fromScale(X, 0.45), UDim2.fromScale(W * 0.45, 0.19), Color3.fromRGB(150, 145, 135), "")
		Post.Visible = false
		local Btn = C.KitButton(C.Canvas, "Col " .. I, UDim2.fromScale(X, 0.66), UDim2.fromScale(W, 0.065), function()
			local At = table.find(Supports, I)
			if At then table.remove(Supports, At) else table.insert(Supports, I) end
			C.Result("", C.GOLD)
			Paint()
		end)
		Cols[I] = {Post = Post, Label = PostLabel, Btn = Btn}
	end
	local Status = C.Text(C.Canvas, "", UDim2.fromScale(0.04, 0.73), UDim2.fromScale(0.92, 0.05))
	Paint = function()
		local R, Why = LP.Carry(P, Supports)
		for I = 1, P.N do
			local On = table.find(Supports, I) ~= nil
			Cols[I].Post.Visible = On
			Cols[I].Btn.Head.TextColor3 = On and C.GOLD or Color3.new(1, 1, 1)
			if On then
				local L = R.Carried[I] or 0
				Cols[I].Label.Text = (L % 1 == 0) and tostring(L) or ("%.1f"):format(L)
				Cols[I].Post.BackgroundColor3 = (L > P.Capacity or P.Soft[I]) and Color3.fromRGB(190, 70, 60) or Color3.fromRGB(150, 145, 135)
			end
		end
		Status.Text = ("Supports %d of %d"):format(#Supports, P.K) .. (Why and ("  -  " .. Why) or "")
		Status.TextColor3 = Why and C.RED or Color3.fromRGB(225, 220, 210)
	end
	Paint()
	return function() if #Supports == 0 then return nil end return {Supports = Supports} end,
		function() table.clear(Supports) C.Result("", C.GOLD) Paint() end
end

-- ===== PressureRouting (Wind) =====
function Builders.PressureRouting(Ctx, Def, P)
	local Paint -- (set below; the buttons call it)
	local C = Ctx
	local PR = Rules.PressureRouting
	local NV = PR.Valves(P.Depth)
	local Modes = {}
	for V = 1, NV do Modes[V] = "S" end
	C.Text(C.Canvas, Def.Hint, UDim2.fromScale(0.04, 0.0), UDim2.fromScale(0.92, 0.1))
	C.Text(C.Canvas, ("Air enters at the top (%d). Each valve sends it Left, Right, or Splits it in half. Tap a valve to change it."):format(P.Source),
		UDim2.fromScale(0.04, 0.1), UDim2.fromScale(0.92, 0.07), DIM)
	local Buttons, Flows = {}, {}
	local Rows = P.Depth
	for V = 1, NV do
		local Row = math.floor(math.log(V, 2) + 1e-9) -- 0-based row
		local First = 2 ^ Row
		local Slot = V - First
		local Count = 2 ^ Row
		local X = 0.06 + (Slot + 0.5) * (0.88 / Count)
		local Y = 0.27 + Row * (0.36 / (Rows + 1)) -- (below the rules line: the root's flow label sits above it)
		Buttons[V] = C.KitButton(C.Canvas, "Split", UDim2.fromScale(X, Y), UDim2.fromScale(math.min(0.2, 0.86 / Count), 0.065), function()
			Modes[V] = ({S = "L", L = "R", R = "S"})[Modes[V]]
			C.Result("", C.GOLD)
			Paint()
		end)
		Flows[V] = C.Text(C.Canvas, "", UDim2.new(X - 0.06, 0, Y - 0.07, 0), UDim2.fromScale(0.12, 0.035), DIM)
	end
	local Vents = {}
	local NVents = NV + 1
	for I = 1, NVents do
		local X = 0.06 + (I - 0.5) * (0.88 / NVents)
		local F, L = Tile(C, C.Canvas, UDim2.fromScale(X, 0.68), UDim2.fromScale(0.86 / NVents, 0.09), DARK, "")
		Vents[I] = {Frame = F, Label = L}
	end
	Paint = function()
		local F = PR.Flow(P, Modes)
		for V = 1, NV do
			Buttons[V].Head.Text = ({S = "Split", L = "Left", R = "Right"})[Modes[V]]
			Flows[V].Text = tostring(F.Valves[V] or 0)
		end
		for I = 1, NVents do
			local Got, Need = F.Vents[I] or 0, P.Targets[I] or 0
			Vents[I].Label.Text = ("%s / %s"):format(tostring(Got), tostring(Need))
			Vents[I].Label.TextColor3 = math.abs(Got - Need) < 1e-6 and C.GREEN or Color3.fromRGB(225, 220, 210)
		end
	end
	C.Text(C.Canvas, "VENTS (now / needed)", UDim2.fromScale(0.04, 0.6), UDim2.fromScale(0.4, 0.04), C.GOLD).TextXAlignment = Enum.TextXAlignment.Left
	Paint()
	return function() return {Modes = Modes} end,
		function() for V = 1, NV do Modes[V] = "S" end C.Result("", C.GOLD) Paint() end
end

-- ===== MaterialMatch (Metal) =====
function Builders.MaterialMatch(Ctx, Def, P)
	local Paint -- (set below; the buttons call it)
	local C = Ctx
	local MM = Rules.MaterialMatch
	local Pick = {}
	C.Text(C.Canvas, Def.Hint, UDim2.fromScale(0.04, 0.0), UDim2.fromScale(0.92, 0.08))
	-- the sample table
	local Cols = {"MATERIAL", "STRENGTH", "FLEX", "HEAT", "WEIGHT"}
	for J, H in ipairs(Cols) do
		C.Text(C.Canvas, H, UDim2.fromScale(0.04 + (J - 1) * 0.18, 0.09), UDim2.fromScale(J == 1 and 0.2 or 0.16, 0.04), C.GOLD)
	end
	for I, Mat in ipairs(P.Materials) do
		local Y = 0.135 + (I - 1) * 0.045
		C.Text(C.Canvas, Mat.Name, UDim2.fromScale(0.04, Y), UDim2.fromScale(0.2, 0.04))
		for J, Prop in ipairs(MM.Props) do C.Text(C.Canvas, tostring(Mat[Prop]), UDim2.fromScale(0.04 + J * 0.18, Y), UDim2.fromScale(0.16, 0.04)) end
	end
	local Top = 0.15 + #P.Materials * 0.045
	local Labels = {}
	for I, Part in ipairs(P.Parts) do
		local Y = Top + (I - 1) * 0.13
		local Words = {}
		for _, N in ipairs(Part.Needs) do table.insert(Words, ("%s %s %d"):format(N[1]:lower(), N[2] == "Min" and "at least" or "at most", N[3])) end
		C.Text(C.Canvas, Part.Name:upper() .. ":  " .. table.concat(Words, ",  "), UDim2.fromScale(0.04, Y), UDim2.fromScale(0.92, 0.04), C.GOLD).TextXAlignment = Enum.TextXAlignment.Left
		Labels[I] = C.Text(C.Canvas, "", UDim2.fromScale(0.04, Y + 0.045), UDim2.fromScale(0.26, 0.05))
		C.KitButton(C.Canvas, "<", UDim2.fromScale(0.37, Y + 0.07), UDim2.fromScale(0.12, 0.06), function()
			Pick[I] = ((Pick[I] or 1) - 2) % #P.Materials + 1 C.Result("", C.GOLD) Paint()
		end)
		C.KitButton(C.Canvas, ">", UDim2.fromScale(0.51, Y + 0.07), UDim2.fromScale(0.12, 0.06), function()
			Pick[I] = (Pick[I] or 0) % #P.Materials + 1 C.Result("", C.GOLD) Paint()
		end)
	end
	Paint = function()
		for I, Part in ipairs(P.Parts) do
			local Mat = Pick[I] and P.Materials[Pick[I]]
			Labels[I].Text = Mat and Mat.Name or "(choose)"
			Labels[I].TextColor3 = Mat and (MM.Fits(Mat, Part) and C.GREEN or C.RED) or DIM
		end
	end
	Paint()
	return function()
		for I = 1, #P.Parts do if not Pick[I] then return nil end end
		return {Pick = Pick}
	end, function() table.clear(Pick) C.Result("", C.GOLD) Paint() end
end

-- the label on the submit button, per kind
Builders.SubmitLabel = {ReactionControl = "Ignite", PhaseSequence = "Seal", LoadPaths = "Brace", PressureRouting = "Open Line", MaterialMatch = "Forge"}

return Builders

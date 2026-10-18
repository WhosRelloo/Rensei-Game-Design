-- MinigameUI: draws the in-world minigames MinigameService opens (Pressure Board, Array
-- Restoration, Assay Bench, Ledger Cipher) inside an on-theme panel (MenuKit: the Settings frame
-- and header, kit buttons). It sends only the answer (valve positions / ring moves / the row it
-- picked / the decoded place); the server decides pass or fail. Assay tests are asked of the
-- server one at a time ("Act" -> "Reply"): the client never knows the sample.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIState = require(script.Parent.UIState)
local MenuKit = require(script.Parent.MenuKit)
local Defs = require(ReplicatedStorage.Modules.Data.Rensei.Minigames)
local Builders = require(script.Parent.AlchemyMinigameUI) -- the alchemy trainers' kinds

local CIRCLE = "rbxassetid://132299053523633" -- the game's transmutation circle texture
local GOLD = Color3.fromRGB(230, 205, 120)
local FONT = Font.new("rbxasset://fonts/families/Guru.json", Enum.FontWeight.Bold)
local NUMBERS = {"1", "2", "3", "4", "5"} -- (Guru renders "II" as a ligature, so plain numbers)

local MinigameUI = {}

local Kit, Canvas, Remote
local Current = nil -- {Id, Def, Params, ...}
local ResultLabel

local function Make(Class, Props, Parent)
	local O = Instance.new(Class)
	for K, V in pairs(Props) do O[K] = V end
	O.Parent = Parent
	return O
end

local function Text(Parent, T, Pos, Size, Color, Scaled)
	local L = Make("TextLabel", {BackgroundTransparency = 1, Position = Pos, Size = Size, FontFace = FONT,
		Text = T, TextColor3 = Color or Color3.fromRGB(225, 220, 210), TextScaled = Scaled ~= false, TextWrapped = true}, Parent)
	Make("UIStroke", {Thickness = 1, Transparency = 0.4}, L)
	Make("UITextSizeConstraint", {MaxTextSize = 18}, L)
	return L
end

local function KitButton(Parent, Label, Pos, Size, OnClick, Danger)
	local B = (Danger and Kit.DangerProto or Kit.ButtonProto):Clone()
	B.Name = Label
	B.Head.Text = Label
	B.AnchorPoint = Vector2.new(0.5, 0.5)
	B.Position = Pos
	B.Size = Size
	B.Parent = Parent
	B.Activated:Connect(OnClick)
	return B
end

local function Shake(Gui)
	local P = Gui.Position
	for _, X in ipairs({-8, 7, -5, 3, 0}) do
		TweenService:Create(Gui, TweenInfo.new(0.05), {Position = P + UDim2.fromOffset(X, 0)}):Play()
		task.wait(0.05)
	end
	Gui.Position = P
end

-- ===== Pressure Board =====
local function PressureBoard(Def, P)
	local Values = table.clone(P.Start)
	Text(Canvas, Def.Hint, UDim2.fromScale(0.04, 0.0), UDim2.fromScale(0.92, 0.14))

	Text(Canvas, "PRESSURE", UDim2.fromScale(0.04, 0.16), UDim2.fromScale(0.3, 0.05), GOLD)
	local Track = Make("Frame", {Position = UDim2.fromScale(0.06, 0.22), Size = UDim2.fromScale(0.88, 0.06),
		BackgroundColor3 = Color3.fromRGB(28, 26, 26), BorderSizePixel = 0}, Canvas)
	Make("UIStroke", {Color = Color3.fromRGB(90, 80, 60), Thickness = 1.5}, Track)
	Make("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(P.Target, 0), Size = UDim2.fromScale(P.Band, 1),
		BackgroundColor3 = Color3.fromRGB(70, 150, 80), BorderSizePixel = 0, BackgroundTransparency = 0.15}, Track)
	local Needle = Make("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(0, 4, 1.6, 0),
		BackgroundColor3 = GOLD, BorderSizePixel = 0, ZIndex = 3}, Track)

	local function Gauge()
		local Sum = 0
		for I = 1, P.Valves do Sum += P.Weights[I] * Values[I] end
		return (Sum - P.Min) / (P.Max - P.Min)
	end
	local Wheels, Labels = {}, {}
	local function Refresh()
		local G = math.clamp(Gauge(), 0, 1)
		TweenService:Create(Needle, TweenInfo.new(0.25, Enum.EasingStyle.Back), {Position = UDim2.fromScale(G, 0.5)}):Play()
		Needle.BackgroundColor3 = math.abs(G - P.Target) <= P.Band / 2 and Color3.fromRGB(120, 230, 130) or GOLD
		for I = 1, P.Valves do
			Labels[I].Text = tostring(Values[I])
			TweenService:Create(Wheels[I], TweenInfo.new(0.2), {Rotation = Values[I] * 36}):Play()
		end
	end
	for I = 1, P.Valves do
		local X = (I - 0.5) / P.Valves
		local Col = Make("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(X, 0.33), Size = UDim2.fromScale(0.28, 0.46), BackgroundTransparency = 1}, Canvas)
		Text(Col, "VALVE " .. NUMBERS[I], UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.14), GOLD)
		local Wheel = Make("ImageLabel", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.62, 0.62),
			BackgroundTransparency = 1, Image = CIRCLE, ImageColor3 = Color3.fromRGB(190, 170, 120)}, Col)
		Make("UIAspectRatioConstraint", {}, Wheel)
		Make("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.08, 0.22),
			BackgroundColor3 = GOLD, BorderSizePixel = 0}, Wheel) -- the spoke that shows the turn
		Wheels[I] = Wheel
		Labels[I] = Text(Col, "0", UDim2.fromScale(0.35, 0.72), UDim2.fromScale(0.3, 0.12))
		KitButton(Col, "-", UDim2.fromScale(0.22, 0.9), UDim2.fromScale(0.42, 0.17), function()
			Values[I] = math.max(0, Values[I] - 1) Refresh()
		end)
		KitButton(Col, "+", UDim2.fromScale(0.78, 0.9), UDim2.fromScale(0.42, 0.17), function()
			Values[I] = math.min(P.Steps, Values[I] + 1) Refresh()
		end)
	end
	Refresh()
	return function() return Values end
end

-- ===== Array Restoration =====
local function ArrayRestoration(Def, P)
	local Offsets = table.clone(P.Offsets)
	local Moves = {}
	Text(Canvas, Def.Hint, UDim2.fromScale(0.04, 0.0), UDim2.fromScale(0.92, 0.14))
	local Disk = Make("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.17), Size = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1}, Canvas)
	Make("UIAspectRatioConstraint", {}, Disk)
	-- the notch every mark has to point at
	local Notch = Make("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.02), Size = UDim2.fromScale(0.05, 0.07),
		BackgroundColor3 = GOLD, BorderSizePixel = 0, Rotation = 0, ZIndex = 5}, Disk)
	local Rings = {}
	local Sizes = {1, 0.7, 0.42, 0.24}
	local Tints = {Color3.fromRGB(200, 180, 130), Color3.fromRGB(170, 150, 110), Color3.fromRGB(140, 125, 95), Color3.fromRGB(120, 105, 80)}
	for I = 1, P.Rings do
		local R = Make("ImageLabel", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(Sizes[I], Sizes[I]),
			BackgroundTransparency = 1, Image = CIRCLE, ImageColor3 = Tints[I], ZIndex = I + 1}, Disk)
		Make("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.01), Size = UDim2.fromScale(0.045 / Sizes[I], 0.1),
			BackgroundColor3 = Color3.fromRGB(255, 120, 80), BorderSizePixel = 0, ZIndex = I + 2}, R) -- this ring's mark
		Rings[I] = R
	end
	local function Refresh(Animate)
		local Done = true
		for I = 1, P.Rings do
			local Goal = Offsets[I] * (360 / P.Positions)
			-- turn the short way round from where it is now
			local Now = Rings[I].Rotation
			local Delta = ((Goal - Now + 180) % 360) - 180
			TweenService:Create(Rings[I], TweenInfo.new(Animate and 0.18 or 0), {Rotation = Now + Delta}):Play()
			if Offsets[I] ~= 0 then Done = false end
		end
		Notch.BackgroundColor3 = Done and Color3.fromRGB(120, 230, 130) or GOLD
	end
	local function Turn(I, Dir)
		table.insert(Moves, {I, Dir})
		Offsets[I] = (Offsets[I] + Dir) % P.Positions
		if I < P.Rings then Offsets[I + 1] = (Offsets[I + 1] + Dir) % P.Positions end
		Refresh(true)
	end
	local Names = {"OUTER", "MIDDLE", "INNER", "CORE"}
	for I = 1, P.Rings do
		local X = (I - 0.5) / P.Rings
		Text(Canvas, Names[I] .. " RING", UDim2.new(X - 0.14, 0, 0.69, 0), UDim2.fromScale(0.28, 0.05), GOLD)
		KitButton(Canvas, "<", UDim2.fromScale(X - 0.08, 0.79), UDim2.fromScale(0.15, 0.09), function() Turn(I, -1) end)
		KitButton(Canvas, ">", UDim2.fromScale(X + 0.08, 0.79), UDim2.fromScale(0.15, 0.09), function() Turn(I, 1) end)
	end
	Refresh(false)
	return function() return Moves end, function()
		Offsets = table.clone(P.Offsets)
		table.clear(Moves)
		Refresh(true)
	end
end

-- ===== Assay Bench =====
local RED = Color3.fromRGB(230, 120, 110)
local GREEN = Color3.fromRGB(140, 230, 140)

local function AssayBench(Def, P)
	local Rows = {}
	for _, Row in ipairs(Def.Table) do Rows[Row.Id] = Row end
	local Results = {} -- [Test] = reaction the server reported
	local Selected
	Text(Canvas, Def.Hint, UDim2.fromScale(0.04, 0.0), UDim2.fromScale(0.92, 0.12))

	-- left: the sample and its tests
	Text(Canvas, "WALL CHALK", UDim2.fromScale(0.03, 0.14), UDim2.fromScale(0.34, 0.05), GOLD)
	local ChipsLabel = Text(Canvas, "", UDim2.fromScale(0.03, 0.2), UDim2.fromScale(0.34, 0.045))
	local ResultLabels = {}
	for I, Test in ipairs(P.Tests) do
		local Y = 0.3 + (I - 1) * 0.12
		KitButton(Canvas, Test, UDim2.fromScale(0.11, Y), UDim2.fromScale(0.15, 0.085), function()
			Remote:FireServer("Act", Test)
		end)
		ResultLabels[Test] = Text(Canvas, "-", UDim2.new(0.2, 0, Y - 0.025, 0), UDim2.fromScale(0.17, 0.05))
	end

	-- right: the reference table (rows in the order the server dealt them)
	local X0, W = 0.4, 0.57
	Text(Canvas, "REFERENCE", UDim2.fromScale(X0, 0.14), UDim2.fromScale(W * 0.36, 0.05), GOLD)
	for I, Test in ipairs(P.Tests) do
		Text(Canvas, Test, UDim2.fromScale(X0 + W * (0.36 + (I - 1) * 0.16), 0.14), UDim2.fromScale(W * 0.16, 0.05), GOLD)
	end
	local Cells, Buttons = {}, {}
	local function Paint()
		local Left = P.ChipsLeft
		ChipsLabel.Text = "Chips left: " .. tostring(Left)
		for _, Test in ipairs(P.Tests) do
			ResultLabels[Test].Text = Results[Test] or "-"
			ResultLabels[Test].TextColor3 = Results[Test] and GOLD or Color3.fromRGB(150, 150, 150)
		end
		for Id, Row in pairs(Cells) do
			for Test, Cell in pairs(Row) do
				local R = Results[Test]
				Cell.TextColor3 = R == nil and Color3.fromRGB(215, 210, 200) or (R == Rows[Id][Test] and GREEN or RED)
			end
			Buttons[Id].Head.TextColor3 = Selected == Id and GOLD or Color3.new(1, 1, 1)
			Buttons[Id].Parent.BackgroundTransparency = Selected == Id and 0.55 or 1
		end
	end
	for I, Id in ipairs(P.Order) do
		local Y = 0.21 + (I - 1) * 0.1
		local Line = Make("Frame", {Name = "Row_" .. Id, Position = UDim2.fromScale(X0, Y), Size = UDim2.fromScale(W, 0.09),
			BackgroundColor3 = Color3.fromRGB(90, 75, 45), BackgroundTransparency = 1, BorderSizePixel = 0}, Canvas)
		Buttons[Id] = KitButton(Line, Rows[Id].Name, UDim2.fromScale(0.18, 0.5), UDim2.fromScale(0.35, 0.9), function()
			Selected = Id
			Paint()
		end)
		Cells[Id] = {}
		for J, Test in ipairs(P.Tests) do
			Cells[Id][Test] = Text(Line, Rows[Id][Test], UDim2.fromScale(0.365 + (J - 1) * 0.16, 0.2), UDim2.fromScale(0.15, 0.6))
		end
	end
	P.ChipsLeft = P.Chips
	Paint()

	Current.OnReply = function(R)
		if type(R) ~= "table" then return end
		if R.Empty then
			ResultLabel.Text = "No sample left. Name it from what you've seen."
			ResultLabel.TextColor3 = RED
		elseif R.Test and R.Result then
			Results[R.Test] = R.Result
			ResultLabel.Text = R.Test .. ": " .. R.Result
			ResultLabel.TextColor3 = GOLD
		end
		P.ChipsLeft = R.Left or P.ChipsLeft
		Paint()
	end
	Current.OnFail = function()
		-- the server refilled the chips; start the tests over
		table.clear(Results)
		P.ChipsLeft = P.Chips
		Paint()
	end
	return function() return Selected end
end

-- ===== Ledger Cipher =====
local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

-- spaced letters (a cipher reads letter by letter; also keeps Guru from joining "II")
local function Spaced(Line)
	local Words = {}
	for Word in string.gmatch(Line, "%S+") do
		table.insert(Words, (string.gsub(Word, "(.)", "%1 ")))
	end
	return table.concat(Words, "  ")
end

local function LedgerCipher(Def, P)
	Text(Canvas, Def.Hint, UDim2.fromScale(0.04, 0.0), UDim2.fromScale(0.92, 0.12))
	local Page = Make("Frame", {Position = UDim2.fromScale(0.04, 0.14), Size = UDim2.fromScale(0.92, 0.36),
		BackgroundColor3 = Color3.fromRGB(52, 46, 36), BackgroundTransparency = 0.2, BorderSizePixel = 0}, Canvas)
	Make("UIStroke", {Color = Color3.fromRGB(110, 95, 65), Thickness = 1.5}, Page)
	for I, Line in ipairs(P.Lines) do
		local H = 1 / #P.Lines
		local L = Text(Page, Spaced(Line), UDim2.fromScale(0.03, (I - 1) * H + H * 0.15), UDim2.fromScale(0.94, H * 0.7),
			I == P.Marked and Color3.fromRGB(240, 150, 130) or nil)
		L.TextXAlignment = Enum.TextXAlignment.Left
		if I == P.Marked then
			-- struck out in red wax
			Make("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.55), Size = UDim2.new(1, 0, 0, 2),
				BackgroundColor3 = Color3.fromRGB(170, 30, 30), BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 3}, L)
		end
	end

	-- the clerks' cipher ring: WRITTEN letters over what they READ as, for the shift you set
	local Dial = 0
	Text(Canvas, "WRITTEN", UDim2.fromScale(0.0, 0.53), UDim2.fromScale(0.1, 0.045), GOLD)
	Text(Canvas, "READS", UDim2.fromScale(0.0, 0.59), UDim2.fromScale(0.1, 0.045), GOLD)
	local ReadLabels = {}
	for I = 1, 26 do
		local X = 0.1 + (I - 1) * 0.0345
		Text(Canvas, string.sub(ALPHABET, I, I), UDim2.fromScale(X, 0.53), UDim2.fromScale(0.033, 0.045))
		ReadLabels[I] = Text(Canvas, "", UDim2.fromScale(X, 0.59), UDim2.fromScale(0.033, 0.045), GOLD)
	end
	local DialLabel
	local function Paint()
		for I = 1, 26 do
			local J = (I - 1 - Dial) % 26 + 1
			ReadLabels[I].Text = string.sub(ALPHABET, J, J)
		end
		DialLabel.Text = "Shift " .. tostring(Dial)
	end
	KitButton(Canvas, "<", UDim2.fromScale(0.36, 0.69), UDim2.fromScale(0.1, 0.07), function() Dial = (Dial - 1) % 26 Paint() end)
	DialLabel = Text(Canvas, "", UDim2.fromScale(0.42, 0.665), UDim2.fromScale(0.16, 0.05))
	KitButton(Canvas, ">", UDim2.fromScale(0.64, 0.69), UDim2.fromScale(0.1, 0.07), function() Dial = (Dial + 1) % 26 Paint() end)
	Paint()

	-- the answer box (the Settings key-bind box, as in the admin panel)
	local Frame = Kit.BoxProto:Clone()
	Frame.Name = "Answer"
	Frame.AnchorPoint = Vector2.new(0.5, 0.5)
	Frame.Position = UDim2.fromScale(0.5, 0.79)
	Frame.Size = UDim2.fromScale(0.5, 0.07)
	local Head = Frame.Head
	local Box = Instance.new("TextBox")
	Box.Name = "Input"
	for _, Prop in ipairs({"Size", "Position", "AnchorPoint", "FontFace", "TextColor3", "TextScaled", "BackgroundTransparency"}) do
		Box[Prop] = Head[Prop]
	end
	Box.ClearTextOnFocus = false
	Box.PlaceholderText = "Where did it go?"
	Box.PlaceholderColor3 = Color3.fromRGB(140, 130, 100)
	Box.Text = ""
	for _, C in ipairs(Head:GetChildren()) do C.Parent = Box end
	Head:Destroy()
	Box.Parent = Frame
	Frame.Parent = Canvas
	return function() return string.sub(Box.Text, 1, 40) end
end

-- ===== open / close =====
local function Clear()
	for _, C in ipairs(Canvas:GetChildren()) do C:Destroy() end
end

local function Close(Silent)
	if Current and not Silent then Remote:FireServer("Close") end
	Current = nil
	if UIState.IsOpen("Minigame") then UIState.ToggleMenu("Minigame") end
end

local function Open(Id, Params)
	local Def = Defs[Id]
	if not Def then return end
	Clear()
	Current = {Id = Id}
	Kit.Main.Header.Head.Text = Def.Title
	local Answer, Reset
	if Def.Kind == "PressureBoard" then
		Answer = PressureBoard(Def, Params)
	elseif Def.Kind == "ArrayRestoration" then
		Answer, Reset = ArrayRestoration(Def, Params)
	elseif Def.Kind == "AssayBench" then
		ResultLabel = Text(Canvas, "", UDim2.fromScale(0.04, 0.86), UDim2.fromScale(0.92, 0.05))
		Answer = AssayBench(Def, Params)
	elseif Def.Kind == "LedgerCipher" then
		Answer = LedgerCipher(Def, Params)
	elseif Builders[Def.Kind] then
		ResultLabel = Text(Canvas, "", UDim2.fromScale(0.04, 0.88), UDim2.fromScale(0.92, 0.05))
		local Ctx = {Canvas = Canvas, Make = Make, Text = Text, KitButton = KitButton, GOLD = GOLD, RED = RED, GREEN = GREEN,
			Current = Current, Result = function(T, Color) ResultLabel.Text = T ResultLabel.TextColor3 = Color or GOLD end}
		Answer, Reset = Builders[Def.Kind](Ctx, Def, Params)
	end
	ResultLabel = ResultLabel and ResultLabel.Parent and ResultLabel or Text(Canvas, "", UDim2.fromScale(0.04, 0.86), UDim2.fromScale(0.92, 0.05))
	local SubmitLabel = ({PressureBoard = "Seal Line", AssayBench = "Name It", LedgerCipher = "Submit"})[Def.Kind]
		or Builders.SubmitLabel[Def.Kind] or "Seal"
	local Buttons = Reset and {"SEAL", "RESET", "LEAVE"} or {"SEAL", "LEAVE"}
	for I, Label in ipairs(Buttons) do
		local X = (I - 0.5) / #Buttons
		KitButton(Canvas, Label == "SEAL" and SubmitLabel or (Label == "RESET" and "Reset" or "Leave"),
			UDim2.fromScale(X, 0.95), UDim2.fromScale(0.26, 0.075), function()
				if Label == "SEAL" then
					local A = Answer()
					if A == nil or A == "" then
						ResultLabel.Text = Def.Kind == "AssayBench" and "Pick a row of the table first."
							or (Builders[Def.Kind] and (Def.Empty or "Make a move first.")) or "Write something first."
						ResultLabel.TextColor3 = RED
					else
						Remote:FireServer("Submit", A)
					end
				elseif Label == "RESET" then Reset()
				else Close() end
			end, Label == "LEAVE")
	end
	if not UIState.IsOpen("Minigame") then UIState.ToggleMenu("Minigame") end
	if not UIState.IsOpen("Minigame") then Close() end -- refused (in combat)
end

-- ===== World challenges (Combat Read, Movement Gauntlet): a HUD tracker, not a panel =====
-- The fight / the run happens in the world, so nothing may cover the screen or take input: a slim strip at
-- the top shows the title, the tier, the server's latest objective, and a Give up button.
local Tracker
local function BuildTracker()
	local Gui = UIState.Gui
	Tracker = Make("Frame", {Name = "ChallengeTracker", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.115),
		Size = UDim2.fromScale(0.36, 0.085), BackgroundColor3 = Color3.fromRGB(16, 14, 12), BackgroundTransparency = 0.2, Visible = false, ZIndex = 20}, Gui)
	Make("UICorner", {CornerRadius = UDim.new(0, 6)}, Tracker)
	Make("UIStroke", {Color = GOLD, Transparency = 0.35, Thickness = 1.5}, Tracker)
	Make("UISizeConstraint", {MinSize = Vector2.new(300, 56)}, Tracker)
	local Title = Text(Tracker, "", UDim2.fromScale(0.03, 0.06), UDim2.fromScale(0.72, 0.4))
	Title.Name = "Title" Title.TextColor3 = GOLD Title.ZIndex = 21 Title.TextXAlignment = Enum.TextXAlignment.Left
	local Line = Text(Tracker, "", UDim2.fromScale(0.03, 0.5), UDim2.fromScale(0.94, 0.42))
	Line.Name = "Objective" Line.ZIndex = 21 Line.TextXAlignment = Enum.TextXAlignment.Left
	local Quit = Make("TextButton", {Name = "GiveUp", Text = "GIVE UP", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(0.98, 0.08),
		Size = UDim2.fromScale(0.2, 0.36), BackgroundColor3 = Color3.fromRGB(40, 22, 20), TextColor3 = Color3.fromRGB(230, 200, 190),
		TextScaled = true, FontFace = Title.FontFace, ZIndex = 22}, Tracker)
	Make("UICorner", {CornerRadius = UDim.new(0, 4)}, Quit)
	Quit.Activated:Connect(function() if Current and Current.World then Remote:FireServer("Close") end end)
end
local function OpenWorld(Id, Params)
	local Def = Defs[Id]
	if not Def then return end
	if not Tracker then BuildTracker() end
	Current = {Id = Id, World = true}
	Tracker.Title.Text = Def.Title .. (Params.TierName and ("  ·  " .. string.upper(Params.TierName)) or "")
	Tracker.Objective.Text = Params.Hint or Def.Hint or ""
	Tracker.Objective.TextColor3 = Color3.fromRGB(235, 228, 215)
	Tracker.GiveUp.Visible = true
	Tracker.Visible = true
end
local function WorldUpdate(Progress)
	if not Tracker or type(Progress) ~= "table" then return end
	Tracker.Objective.Text = tostring(Progress.Text or "")
	Tracker.Objective.TextColor3 = Progress.Good == true and Color3.fromRGB(150, 230, 150)
		or (Progress.Good == false and Color3.fromRGB(235, 130, 120)) or Color3.fromRGB(235, 228, 215)
end
local function WorldResult(Ok, Line)
	if not Tracker then return end
	local Was = Current
	Current = nil
	Tracker.Objective.Text = tostring(Line or "")
	Tracker.Objective.TextColor3 = Ok and Color3.fromRGB(150, 230, 150) or Color3.fromRGB(235, 130, 120)
	Tracker.GiveUp.Visible = false
	task.delay(4, function() if Current == nil or Current ~= Was then if not Current then Tracker.Visible = false end end end)
end

function MinigameUI.Start()
	Kit = MenuKit.new("Minigame", "", {})
	Kit.Rows.Visible = false
	Canvas = Make("Frame", {Name = "Canvas", BackgroundTransparency = 1, AnchorPoint = Kit.Rows.AnchorPoint,
		Position = Kit.Rows.Position, Size = Kit.Rows.Size}, Kit.Main)
	Make("UIPadding", {PaddingTop = UDim.new(0.02, 0), PaddingBottom = UDim.new(0.02, 0)}, Canvas)
	UIState.RegisterMenu("Minigame", Kit.Root)
	-- closed some other way (another menu, combat): let the server drop the session
	Kit.Root:GetPropertyChangedSignal("Visible"):Connect(function()
		task.defer(function()
			if not Kit.Root.Visible and Current then Close() end
		end)
	end)
	task.spawn(function()
		Remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MinigameRemote", 30)
		if not Remote then return end
		Remote.OnClientEvent:Connect(function(Kind, A, B, Done)
			if Kind == "Open" then
				if type(B) == "table" and B.World then OpenWorld(A, B) else Open(A, B) end
			elseif Current and Current.World then
				if Kind == "Reply" then WorldUpdate(A) elseif Kind == "Result" then WorldResult(A, B) end
			elseif Kind == "Reply" and Current then
				if Current.OnReply then Current.OnReply(A) end
			elseif Kind == "Result" and Current then
				if not A and not Done and Current.OnFail then Current.OnFail() end
				ResultLabel.Text = B or ""
				ResultLabel.TextColor3 = A and Color3.fromRGB(140, 230, 140) or Color3.fromRGB(230, 120, 110)
				if A or Done then
					local Was = Current
					task.delay(1.4, function() if Current == Was then Close(true) end end)
				else
					task.spawn(Shake, Canvas)
				end
			end
		end)
	end)
end

return MinigameUI

-- NPC dialogue box. The server drives the conversation (DialogueService); this only draws the
-- current node and sends back which choice was picked. Number keys 1-9 also pick a choice.
-- The NPC's line types out letter by letter and the choices appear once it finishes. Clicking or
-- tapping the text box, or pressing a number key, shows the whole line at once.
-- The X on the box's top-right corner leaves the conversation (owner 2026-10-18; Esc belongs to
-- Roblox's own menu, so it can't be relied on). Its tap area is larger than the icon, for touch.

local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local UIState = require(script.Parent.UIState)

local Gui = UIState.Gui
local Dialogue = Gui.Dialogue

local CHAR_DELAY = 0.022 -- seconds per letter
local PAUSES = {["."] = 0.22, ["!"] = 0.22, ["?"] = 0.22, [","] = 0.09, [";"] = 0.12, [":"] = 0.12}
local TICK_SOUND = "rbxassetid://10066936758"
local TICK_EVERY = 3 -- letters per tick, so the sound reads as speech rather than a buzz
local CLOSE_ICON = "rbxassetid://74304540828981" -- the kit's round X (HUD2.Infos.Search.DeletButton)

local DialogueUI = {}

local Template = nil
local Open = false
local Typing = false
local TypeToken = 0 -- bumped to cancel the line currently typing
local Tick = nil

local function Clear()
	for _, C in ipairs(Dialogue.Choices:GetChildren()) do
		if C:IsA("GuiObject") and C ~= Template then C:Destroy() end
	end
end

-- Show the whole line and the choices.
local function Finish()
	TypeToken += 1
	Typing = false
	Dialogue.MainFrame.maintext.MaxVisibleGraphemes = -1
	Dialogue.Choices.Visible = true
end

local function TypeOut(Text)
	TypeToken += 1
	local Token = TypeToken
	local Label = Dialogue.MainFrame.maintext
	-- The full text goes in up front and MaxVisibleGraphemes reveals it, so wrapping and TextScaled
	-- are worked out once (words never jump lines) and rich text tags are never shown half-typed.
	Label.Text = Text
	Label.MaxVisibleGraphemes = 0
	local Plain = Text:gsub("<br%s*/?>", "\n"):gsub("<[^>]->", ""):gsub("&lt;", "<"):gsub("&gt;", ">")
		:gsub("&quot;", "\""):gsub("&apos;", "'"):gsub("&amp;", "&")
	local Graphemes = {}
	for First, Last in utf8.graphemes(Plain) do table.insert(Graphemes, Plain:sub(First, Last)) end
	Dialogue.Choices.Visible = false
	Typing = true
	task.spawn(function()
		for I, G in ipairs(Graphemes) do
			if TypeToken ~= Token then return end
			Label.MaxVisibleGraphemes = I
			if Tick and I % TICK_EVERY == 1 and G:match("%S") then SoundService:PlayLocalSound(Tick) end
			task.wait(PAUSES[G] or CHAR_DELAY)
		end
		if TypeToken == Token then Finish() end
	end)
end

local function Close()
	-- the server sends DialogueEnd on every close request, open box or not; leave the HUD alone then
	if not Open and not Dialogue.Visible then return end
	TypeToken += 1
	Typing = false
	Open = false
	Dialogue.Visible = false
	Gui.HUD.Stats.Visible = true
	Gui.HUD.Bottom.Visible = true
end

function DialogueUI.Start()
	-- Choice1 is the template; Choice2 is redundant once choices are generated.
	Template = Dialogue.Choices.Choice1
	Template.Parent = nil
	local Extra = Dialogue.Choices:FindFirstChild("Choice2")
	if Extra then Extra:Destroy() end
	Dialogue.Visible = false

	Tick = Instance.new("Sound")
	Tick.Name = "TypeTick"
	Tick.SoundId = TICK_SOUND
	Tick.Volume = 0.25
	Tick.Parent = Dialogue

	-- Click / tap anywhere on the text box to skip the typing.
	local Skip = Instance.new("TextButton")
	Skip.Name = "Skip"
	Skip.Text = ""
	Skip.BackgroundTransparency = 1
	Skip.Size = UDim2.fromScale(1, 1)
	Skip.ZIndex = 10
	Skip.Activated:Connect(function()
		if Typing then Finish() end
	end)
	Skip.Parent = Dialogue.MainFrame

	-- X: leave the conversation (mouse or tap)
	local CloseHit = Instance.new("TextButton")
	CloseHit.Name = "Close"
	CloseHit.Text = ""
	CloseHit.BackgroundTransparency = 1
	CloseHit.AnchorPoint = Vector2.new(0.5, 0.5)
	CloseHit.Position = UDim2.fromScale(0.975, 0.1) -- on the frame's top-right corner, clear of the text
	CloseHit.Size = UDim2.fromScale(0.15, 0.66) -- the tap area (~45 px on a landscape phone)
	CloseHit.ZIndex = 12
	CloseHit.Parent = Dialogue.MainFrame
	local CloseAspect = Instance.new("UIAspectRatioConstraint")
	CloseAspect.AspectRatio = 1
	CloseAspect.Parent = CloseHit
	local Icon = Instance.new("ImageLabel")
	Icon.Name = "Icon"
	Icon.BackgroundTransparency = 1
	Icon.Image = CLOSE_ICON
	Icon.ScaleType = Enum.ScaleType.Fit
	Icon.AnchorPoint = Vector2.new(0.5, 0.5)
	Icon.Position = UDim2.fromScale(0.5, 0.5)
	Icon.Size = UDim2.fromScale(0.46, 0.46)
	Icon.ZIndex = 13
	Icon.Parent = CloseHit
	CloseHit.MouseEnter:Connect(function() Icon.ImageColor3 = Color3.fromRGB(255, 225, 160) end)
	CloseHit.MouseLeave:Connect(function() Icon.ImageColor3 = Color3.new(1, 1, 1) end)
	CloseHit.Activated:Connect(function()
		if Open then UIState.Request("Dialogue", "Close") end
	end)

	UIState.On("Dialogue", function(P)
		UIState.CloseMenus()
		Clear()
		Dialogue.MainFrame.Title.Text = P.Speaker or ""
		for I, Text in ipairs(P.Choices or {}) do
			local Row = Template:Clone()
			Row.Name = "Choice" .. I
			Row.LayoutOrder = I
			Row.Head.Text = Text
			Row.Selected.Visible = false
			-- a locked choice (DialogueService: Show = "Locked") is shown greyed with its reason
			local Locked = P.Locked and (P.Locked[I] or P.Locked[tostring(I)])
			if Locked then
				Row.Head.TextTransparency = 0.55
				if Row:IsA("ImageLabel") or Row:IsA("ImageButton") then Row.ImageTransparency = math.max(Row.ImageTransparency, 0.5) end
			end
			local Button = Instance.new("TextButton")
			Button.Name = "Hit" Button.Text = "" Button.BackgroundTransparency = 1
			Button.Size = UDim2.fromScale(1, 1) Button.ZIndex = Row.ZIndex + 3
			Button.MouseEnter:Connect(function() Row.Selected.Visible = true end)
			Button.MouseLeave:Connect(function() Row.Selected.Visible = false end)
			Button.Activated:Connect(function() UIState.Request("Dialogue", "Choose", I) end)
			Button.Parent = Row
			Row.Parent = Dialogue.Choices
		end
		Open = true
		Dialogue.Visible = true
		TypeOut(P.Text or "")
		-- The choices sit where the vitals bars are; hide those while talking.
		Gui.HUD.Stats.Visible = false
		Gui.HUD.Bottom.Visible = false
	end)
	UIState.On("DialogueEnd", Close)

	UserInputService.InputBegan:Connect(function(Input, Processed)
		if not Open or Processed then return end
		if Input.KeyCode == Enum.KeyCode.Escape then
			UIState.Request("Dialogue", "Close")
			return
		end
		local N = Input.KeyCode.Value - Enum.KeyCode.One.Value + 1
		if N >= 1 and N <= 9 and Typing then
			Finish() -- the first press only finishes the line; press again to choose
			return
		end
		if N >= 1 and N <= 9 and Dialogue.Choices:FindFirstChild("Choice" .. N) then
			UIState.Request("Dialogue", "Choose", N)
		end
	end)
end

DialogueUI.IsOpen = function() return Open end
return DialogueUI

-- TownsfolkClient (Region Foundation Task 6, 2026-10-23): what townsfolk say, as a speech bubble over their heads.
-- A plain LocalScript in StarterPlayer.StarterPlayerScripts, copied into each region place (like TravelClient).
-- Owner 2026-10-23: "Make the townsfolk chat appear above their head with a custom font": Special Elite, bubbles only
-- (no reply choices).
--   * Server: TownsfolkService.Say fires Remotes.TownsfolkSay(Rig, Text, Seconds) to players near the rig.
--   * The bubble: a BillboardGui "SpeechBubble" on the rig's Head (StudsOffset 0, 2.6, 0; MaxDistance 60; no light
--     influence; not on top of the world). Its background is the dialogue's own choice plate (Uis.Dialogue's
--     Choices.Choice1 image), drawn 9-sliced so it grows with the text; no new art and no drawn shapes. The plate is
--     authored as a fitted image without slice settings, so the slice rect here was measured from its native size
--     (about 577 x 34 px). The text is Special Elite, wrapped, at most MaxWidth px wide; the bubble grows in height.
--   * UIMotion fades and pops it in and fades it out after Seconds. A new line on the same rig replaces the old one.
--   * The font is checked once at start (TextService:GetTextBoundsAsync). If Special Elite doesn't load, this says so
--     in the output (and the SpeechFontOk attribute on this script is false) rather than quietly using another font.
-- Every number here is a PROPOSAL.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Player = Players.LocalPlayer
local Remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TownsfolkSay")

local FONT = Font.new("rbxasset://fonts/families/SpecialElite.json")
local TEXT_SIZE = 16
local MAX_WIDTH = 260 -- px, the whole bubble
local PAD_X, PAD_Y = 14, 9 -- px between the plate's edge and the text
local OFFSET = Vector3.new(0, 2.6, 0)
local MAX_DISTANCE = 60
local PLATE_ID = "rbxassetid://92726496845615" -- Uis.Dialogue.Choices.Choice1's image (read live below when present)
local SLICE = Rect.new(12, 12, 565, 22) -- (the plate's ends and edges stay crisp; its middle stretches)
local SLICE_SCALE = 0.7

-- the plate art, read from the dialogue itself (so a new plate image is picked up). StarterGui's copy: DialogueUI takes
-- the live Choice1 out of the player's Uis to use as its row template.
local function PlateImage()
	for _, Root in ipairs({game:GetService("StarterGui"), Player:FindFirstChild("PlayerGui")}) do
		local Uis = Root and Root:FindFirstChild("Uis")
		local Dialogue = Uis and Uis:FindFirstChild("Dialogue")
		local Choices = Dialogue and Dialogue:FindFirstChild("Choices")
		local Plate = Choices and Choices:FindFirstChild("Choice1")
		if Plate and Plate:IsA("ImageLabel") and Plate.Image ~= "" then return Plate.Image end
	end
	return PLATE_ID
end

local UIMotion
local function Motion()
	if UIMotion == nil then
		local Ok, M = pcall(require, ReplicatedStorage.Modules.UI.UIMotion)
		UIMotion = Ok and M or false
	end
	return UIMotion or nil
end

-- the font check (once)
task.spawn(function()
	local Params = Instance.new("GetTextBoundsParams")
	Params.Text = "Afternoon. Need something?"
	Params.Font = FONT
	Params.Size = TEXT_SIZE
	local Ok, Res = pcall(TextService.GetTextBoundsAsync, TextService, Params)
	local Good = Ok and typeof(Res) == "Vector2" and Res.X > 0
	script:SetAttribute("SpeechFontOk", Good)
	if not Good then warn("TownsfolkClient: the Special Elite font didn't load (" .. tostring(Res) .. "); speech bubbles show in Roblox's fallback font") end
end)

local function Measure(Text)
	local Params = Instance.new("GetTextBoundsParams")
	Params.Text = Text
	Params.Font = FONT
	Params.Size = TEXT_SIZE
	Params.Width = MAX_WIDTH - PAD_X * 2
	local Ok, Res = pcall(TextService.GetTextBoundsAsync, TextService, Params)
	if Ok and typeof(Res) == "Vector2" then return Res end
	-- (no measurement: a rough guess from the length)
	local Lines = math.max(1, math.ceil(#Text * TEXT_SIZE * 0.55 / (MAX_WIDTH - PAD_X * 2)))
	return Vector2.new(MAX_WIDTH - PAD_X * 2, Lines * TEXT_SIZE * 1.2)
end

local Tokens = {} -- [Head] = the newest line's token (a newer line replaces an older one, even mid-measure)
local function Show(Rig, Text, Seconds)
	if typeof(Rig) ~= "Instance" or not Rig:IsDescendantOf(workspace) or type(Text) ~= "string" or Text == "" then return end
	local Head = Rig:FindFirstChild("Head")
	if not (Head and Head:IsA("BasePart")) then return end
	local Token = {}
	Tokens[Head] = Token
	local Size = Measure(Text) -- (yields)
	if Tokens[Head] ~= Token or not Head.Parent then return end
	local Old = Head:FindFirstChild("SpeechBubble")
	if Old then Old:Destroy() end

	local Bubble = Instance.new("BillboardGui")
	Bubble.Name = "SpeechBubble"
	Bubble.Adornee = Head
	Bubble.StudsOffset = OFFSET
	Bubble.MaxDistance = MAX_DISTANCE
	Bubble.LightInfluence = 0
	Bubble.AlwaysOnTop = false
	Bubble.ResetOnSpawn = false
	-- (+2 px: a label exactly as wide as the measured line can wrap its last word on rounding)
	Bubble.Size = UDim2.fromOffset(math.min(MAX_WIDTH, math.ceil(Size.X) + 2 + PAD_X * 2), math.ceil(Size.Y) + PAD_Y * 2)

	local Plate = Instance.new("ImageLabel")
	Plate.Name = "Plate"
	Plate.Size = UDim2.fromScale(1, 1)
	Plate.BackgroundTransparency = 1
	Plate.Image = PlateImage()
	Plate.ScaleType = Enum.ScaleType.Slice
	Plate.SliceCenter = SLICE
	Plate.SliceScale = SLICE_SCALE
	Plate.Parent = Bubble

	local Label = Instance.new("TextLabel")
	Label.Name = "Text"
	Label.BackgroundTransparency = 1
	Label.AnchorPoint = Vector2.new(0.5, 0.5)
	Label.Position = UDim2.fromScale(0.5, 0.5)
	Label.Size = UDim2.new(1, -PAD_X * 2, 1, -PAD_Y * 2)
	Label.FontFace = FONT
	Label.TextSize = TEXT_SIZE
	Label.TextWrapped = true
	Label.TextColor3 = Color3.new(1, 1, 1)
	Label.Text = Text
	Label.Parent = Plate

	Bubble.Parent = Head
	local M = Motion()
	if M then
		M.Fade(Plate, true, 0.18)
		M.Pop(Plate, 0.85)
	end
	task.delay(tonumber(Seconds) or 4, function()
		if Tokens[Head] ~= Token or not Bubble.Parent then return end
		Tokens[Head] = nil
		local Mo = Motion()
		if Mo then
			Mo.Fade(Plate, false, 0.3)
			task.delay(0.35, function() if Bubble.Parent then Bubble:Destroy() end end)
		else
			Bubble:Destroy()
		end
	end)
end

Remote.OnClientEvent:Connect(function(Rig, Text, Seconds)
	local Ok, Err = pcall(Show, Rig, Text, Seconds)
	if not Ok then warn("TownsfolkClient:", Err) end
end)

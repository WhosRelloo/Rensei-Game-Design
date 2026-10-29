-- Rensei main menu + save slots + character creation (client). Builds the UI in code; the server
-- (ServerScriptService.MenuServer) validates and saves. Preview: a local copy of
-- ReplicatedStorage.PreviewRig on the dais, dressed by Modules.AppearanceService, idling.
-- Layout follows the owner's reference (deck slide 12, "Character Customization Menu SHOWCASE"):
-- a slot screen, then one step at a time -- Facial Features, Traits, Weapon, Finalize. The frames,
-- plates and buttons are the game's own UI kit (RSEI StarterGui.Uis; ids in KIT below).
-- The painted menu (owner 2026-10-28; Documents/specs/2026-10-28-main-menu-painted-design.md): with Workspace.PaintedStage
-- and Modules.Data.Rensei.MenuStage in the place, the menu stands in the painted foundry hall: each slot's character in
-- its own alcove, the slot cards top right, and picking an empty slot (or EDIT on a made one) pans the camera into that
-- alcove and opens the creator there (MenuPan). The hall's life is MenuBackdrop. Without them, the old dais menu runs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")

local Customization = require(ReplicatedStorage.Modules.Data.Rensei.Customization)
local WeaponStats = require(ReplicatedStorage.Modules.Data.Rensei.WeaponStats)
local Clans = require(ReplicatedStorage.Modules.Data.Rensei.Clans)
local Slots = require(ReplicatedStorage.Modules.Data.Rensei.Slots)
local CreatorPlus = require(ReplicatedStorage.Modules.Data.Rensei.CreatorPlus)
local Appearance = require(ReplicatedStorage.Modules.AppearanceService)
local Remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MenuRemote")
local RenseiData = ReplicatedStorage.Modules.Data.Rensei
if not game:IsLoaded() then game.Loaded:Wait() end -- (the first replication done, so a missing module really is missing)
local StageMarkers = RenseiData:FindFirstChild("MenuStage")
-- (persistent streaming sends the stage soon after joining, not at once: wait for it when its markers are here)
local PaintedStage = StageMarkers and workspace:WaitForChild("PaintedStage", 30) or nil
local Art = RenseiData:FindFirstChild("MenuArt") and require(RenseiData.MenuArt) or {} -- uploaded ids (0 = not yet)
-- live, only once its art is uploaded (MenuArt's backdrop ids): a place published early keeps the old menu
local Painted = PaintedStage ~= nil and StageMarkers ~= nil
	and (RunService:IsStudio() or (type(Art.Backdrop) == "table" and (Art.Backdrop[1] or 0) ~= 0))
local Markers = Painted and require(StageMarkers) or nil
local MenuPan = require(script:WaitForChild("MenuPan"))
local MenuBackdrop = Painted and require(script:WaitForChild("MenuBackdrop")) or nil
local function V3(T) return Vector3.new(T[1], T[2], T[3]) end

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ===== The game's UI kit (RSEI StarterGui.Uis) =====
local function Asset(Id) return "rbxassetid://" .. Id end
local KIT = {
	PanelTall = Asset(92258720364887), -- Settings panel (~0.91 : 1)
	PanelWide = Asset(75368106381802), -- Inventory panel (~1.52 : 1)
	Title = Asset(121370259624731), -- Settings title plate
	Chip = Asset(116949651608707), -- Inventory category tab
	Field = Asset(72215823566264), -- Inventory search bar
	Plate = Asset(99406615400872), -- keybind plate
	Gold = Asset(122322687865995), -- party Accept
	Red = Asset(96683854946403), -- party Decline
	Glow = Asset(107749049761613), -- dialogue choice highlight
	Knob = Asset(128415338450308), -- settings slider knob
	Popup = Asset(113461270613481), -- party invite frame
	Notice = Asset(77443838607606), -- notification bar
	Close = Asset(74304540828981), -- round X (also: delete)
	Add = Asset(95124452394131), -- round plus (HUD2.Infos.Search.AddButton)
	Eye = Asset(123791308611610), -- round eye (Stats.Left.Head.EyeButton): edit a look
	Box = Asset(82831116484275), -- quest task status box (Templates.QuestTask.Status): the favourite toggle
	Tick = Asset(131162468888379), -- its checkmark (QuestTask.Status.Checkmark)
	Chevron = Asset(93094632665405), -- quest header arrow, pointing up (Templates.QuestHeader.Arrows.Top)
	BarFrame = Asset(115089601400579), -- level bar (Stats.MainFrame.LevelBar)
	BarFill = Asset(120303756099496), -- its fill (LevelBar.Bar)
	Frame = { -- item rarity frames
		Common = Asset(107439985664209), Rare = Asset(103069874398717), Epic = Asset(135582023783036), Legendary = Asset(85590690711772),
	},
}
-- clan tier -> {frame, tint} (the kit has no green or red frame: tinted grey ones stand in)
local TIER_FRAME = {
	Common = {KIT.Frame.Common, Color3.new(1, 1, 1)},
	Uncommon = {KIT.Frame.Common, Color3.fromRGB(150, 230, 140)},
	Rare = {KIT.Frame.Rare, Color3.new(1, 1, 1)},
	Legendary = {KIT.Frame.Legendary, Color3.new(1, 1, 1)},
	Mythic = {KIT.Frame.Common, Color3.fromRGB(255, 110, 100)},
}

-- ===== Style (Guru font, warm white on the kit's black) =====
local GURU = "rbxasset://fonts/families/Guru.json"
local FONT = Font.new(GURU, Enum.FontWeight.Regular)
local FONT_B = Font.new(GURU, Enum.FontWeight.Bold)
local GOLD = Color3.fromRGB(230, 205, 120)
local TEXT = Color3.fromRGB(225, 220, 210)
local DIM = Color3.fromRGB(150, 142, 130)
local LINE = Color3.fromRGB(90, 80, 62)
local MIN_TEXT = 15 -- (owner 2026-10-28, the menu audit: no words smaller than this)
local IDLE = "rbxassetid://99650759123617" -- RSEI Animations.Shared.Movement.Default.Idle
local CLAP = "rbxassetid://115558611088872" -- RSEI Animations.Shared.Alchemy.Alchemy_Clap

local function New(Class, Props, Children)
	local I = Instance.new(Class)
	for K, V in pairs(Props or {}) do I[K] = V end
	for _, C in ipairs(Children or {}) do C.Parent = I end
	return I
end
local function Corner(R) return New("UICorner", {CornerRadius = UDim.new(0, R or 4)}) end

local function Label(Text, Props)
	local L = New("TextLabel", {BackgroundTransparency = 1, Text = Text, FontFace = FONT, TextColor3 = TEXT, TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 22), TextWrapped = true})
	for K, V in pairs(Props or {}) do L[K] = V end
	if not L.TextScaled and L.TextSize < MIN_TEXT then L.TextSize = MIN_TEXT end
	return L
end

local function Plate(Image, Props, Children)
	local I = New("ImageLabel", {BackgroundTransparency = 1, Image = Image, ScaleType = Enum.ScaleType.Stretch}, Children)
	for K, V in pairs(Props or {}) do I[K] = V end
	return I
end

-- a kit button: an image plate with a text label on it
local function Button(Text, Image, Props)
	local B = New("ImageButton", {BackgroundTransparency = 1, Image = Image or KIT.Chip, ScaleType = Enum.ScaleType.Stretch,
		AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 36)})
	Label(Text, {Name = "Label", FontFace = FONT_B, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1), TextWrapped = false, Parent = B})
	for K, V in pairs(Props or {}) do
		if K == "TextSize" then B.Label.TextSize = math.max(V, MIN_TEXT)
		elseif K == "TextColor3" then B.Label[K] = V else B[K] = V end
	end
	B.MouseEnter:Connect(function() if not B:GetAttribute("On") then B.ImageColor3 = Color3.fromRGB(255, 240, 210) B.Label.TextColor3 = GOLD end end)
	B.MouseLeave:Connect(function() if not B:GetAttribute("On") then B.ImageColor3 = Color3.new(1, 1, 1) B.Label.TextColor3 = B:GetAttribute("Color") or TEXT end end)
	return B
end
local function SetText(B, Text) B.Label.Text = Text end

-- one of the kit's round icons as a button (gold on hover); Tick = the checkmark drawn in it (the favourite box)
local function IconButton(Image, Props, Tick)
	local B = New("ImageButton", {BackgroundTransparency = 1, Image = Image, ScaleType = Enum.ScaleType.Fit, AutoButtonColor = false})
	for K, V in pairs(Props) do B[K] = V end
	if Tick then
		New("ImageLabel", {Name = "Tick", BackgroundTransparency = 1, Image = KIT.Tick, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromScale(0.8, 0.8),
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.55, 0.45), ZIndex = B.ZIndex + 1, Parent = B})
	end
	B.MouseEnter:Connect(function() B.ImageColor3 = Color3.fromRGB(255, 220, 150) end)
	B.MouseLeave:Connect(function() B.ImageColor3 = Color3.new(1, 1, 1) end)
	return B
end

local function SetOn(B, On)
	B:SetAttribute("On", On)
	B.ImageColor3 = On and Color3.fromRGB(255, 215, 140) or Color3.new(1, 1, 1)
	B.Label.TextColor3 = On and GOLD or (B:GetAttribute("Color") or TEXT)
	local G = B:FindFirstChild("Glow")
	if On and not G then
		Plate(KIT.Glow, {Name = "Glow", Size = UDim2.new(1, 8, 0, 6), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -2), Parent = B})
	elseif not On and G then
		G:Destroy()
	end
end

local function List(Parent, Pad)
	return New("UIListLayout", {Padding = UDim.new(0, Pad or 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Parent})
end

local function Field(Props)
	local P = Plate(KIT.Field, {Size = UDim2.new(1, 0, 0, 32)})
	local B = New("TextBox", {Name = "Box", BackgroundTransparency = 1, Text = "", PlaceholderColor3 = DIM, FontFace = FONT, TextColor3 = TEXT,
		TextSize = 16, ClearTextOnFocus = false, Size = UDim2.new(1, -24, 1, 0), Position = UDim2.fromOffset(12, 0),
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = P})
	for K, V in pairs(Props or {}) do
		if K == "Size" or K == "Position" or K == "LayoutOrder" or K == "Parent" or K == "AnchorPoint" then P[K] = V else B[K] = V end
	end
	return B, P
end

-- ===== Screen =====
-- the menu is the whole screen: no Roblox chat / player list over it (Esc menu stays)
for _, T in ipairs({Enum.CoreGuiType.Chat, Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Health}) do
	pcall(function() game:GetService("StarterGui"):SetCoreGuiEnabled(T, false) end)
end
pcall(function() game:GetService("TextChatService").ChatWindowConfiguration.Enabled = false end)
pcall(function() game:GetService("TextChatService").ChatInputBarConfiguration.Enabled = false end)
local Gui = New("ScreenGui", {Name = "RenseiMenu", IgnoreGuiInset = true, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = Player:WaitForChild("PlayerGui")})
local Scale = New("UIScale", {Parent = Gui})
-- Phones (owner 2026-10-28: "build a phone/touch layout for the menu so text stays readable on small screens"): a short
-- screen gets its own layout, PHONE_H layout pixels tall, instead of the 1100 x 720 one shrunk to fit (that halved every
-- word: 15 px read as 8 on a phone). Relayout (near the end) moves and resizes the pieces for it. In Studio,
-- ReplicatedStorage's MenuPhonePreview attribute (a Vector2, e.g. 844, 390) lays the menu out as that phone would,
-- magnified to fill the viewport, for checking by eye; a live server never reads it.
local PHONE_H = 430
local Phone = false
local Relayout -- (defined once the screens exist)
local LayoutWidth = 0
local function PhonePreview()
	local Pv = RunService:IsStudio() and ReplicatedStorage:GetAttribute("MenuPhonePreview")
	return typeof(Pv) == "Vector2" and Pv or nil
end
local function Rescale()
	local V = Camera.ViewportSize
	local Pv = PhonePreview()
	local Was = Phone
	Phone = Pv ~= nil or V.Y < 560
	if Phone then
		local Ref = Pv or V
		Scale.Scale = V.Y / (Ref.Y / math.clamp(Ref.Y / PHONE_H, 0.8, 1)) -- (the phone's own layout height, filling this screen)
	else
		-- capped at 1 (2026-10-18): the art was drawn for this 1100 x 720 layout; scaling it up (1.5x at 1080p)
		-- stretched the plates past their pixels and blurred them. Smaller screens still scale down.
		Scale.Scale = math.clamp(math.min(V.Y / 720, V.X / 1100), 0.5, 1)
	end
	-- (a new layout when the kind of screen flips, or a phone's width in layout pixels changes)
	local Width = math.floor(V.X / Scale.Scale / 8)
	if Relayout and (Phone ~= Was or (Phone and Width ~= LayoutWidth)) then LayoutWidth = Width Relayout() end
end
Camera:GetPropertyChangedSignal("ViewportSize"):Connect(Rescale)
ReplicatedStorage:GetAttributeChangedSignal("MenuPhonePreview"):Connect(Rescale)
Rescale()

-- ===== Preview rig (idles; claps a transmutation now and then) =====
local Rig = ReplicatedStorage:WaitForChild("PreviewRig"):Clone()
-- Spot = where the creator's rig stands: {Foot, Face = the flat direction to the camera}. The painted menu moves it to
-- the picked slot's alcove (SetSpot); the old dais is the fallback.
local Spot, CamFar, CamFarFov
if Painted then
	local M = Markers.menu_camera
	CamFar, CamFarFov = CFrame.lookAt(V3(M.pos), V3(M.look)), M.fov
	Spot = {Foot = V3(Markers.alcoves[1].foot), Face = V3(Markers.alcoves[1].face)}
else
	local Stage = workspace:WaitForChild("MenuStage")
	local Dais = Stage:WaitForChild("Dais")
	local CamMark = Stage:WaitForChild("CameraMark") -- the menu's camera (owner 2026-10-15: trees + log behind the dais)
	CamFar, CamFarFov = CamMark.CFrame, Camera.FieldOfView
	Spot = {Foot = Dais.Position + Vector3.new(0, Dais.Size.X / 2, 0), Face = ((CamMark.Position - Dais.Position) * Vector3.new(1, 0, 1)).Unit}
end
-- the rig starts facing that camera; drag to turn. (The painted menu keeps it out of sight until a slot is picked:
-- the alcoves show each slot's own figure.)
local Facing = math.atan2(-Spot.Face.X, -Spot.Face.Z)
local RigShown = not Painted
local function PlaceRig()
	local At = RigShown and Spot.Foot or Spot.Foot - Vector3.new(0, 400, 0)
	Rig.HumanoidRootPart.CFrame = CFrame.new(At + Vector3.new(0, 3, 0)) * CFrame.Angles(0, Facing, 0)
end
Rig.Parent = workspace
PlaceRig()
task.spawn(function()
	local Animator = Rig:FindFirstChildOfClass("Humanoid"):FindFirstChildOfClass("Animator")
	if not Animator then return end
	local function Load(Id, Priority)
		local A = New("Animation", {AnimationId = Id})
		local Ok, Track = pcall(function() return Animator:LoadAnimation(A) end)
		if Ok then Track.Priority = Priority end
		return Ok and Track or nil
	end
	local Idle = Load(IDLE, Enum.AnimationPriority.Idle)
	local Clap = Load(CLAP, Enum.AnimationPriority.Action)
	if Idle then Idle.Looped = true Idle:Play(0.3) end
	while Clap and Rig.Parent do
		task.wait(math.random(9, 15))
		Clap:Play(0.15)
	end
end)

Camera.CameraType = Enum.CameraType.Scriptable
-- creator views (owner 2026-10-18: "a face cam ... so players can see their character up close and full body"):
-- FACE = a tight shot of the head, BODY = the whole character; the panel sits on the left, so both frame the
-- rig right of centre. CamNear (the old close-up) stays as a fallback. The painted menu has them per alcove (MenuStage).
local CamNear, CamFace, CamBody, FovFace, FovBody
local function SpotViews(Slot)
	if Painted and Slot then
		local A = Markers.alcoves[Slot]
		CamBody, FovBody = CFrame.lookAt(V3(A.body.pos), V3(A.body.look)), A.body.fov
		CamFace, FovFace = CFrame.lookAt(V3(A.face_view.pos), V3(A.face_view.look)), A.face_view.fov
		CamNear = CamFace
		return
	end
	local Top = Spot.Foot
	local Head, Mid = Top + Vector3.new(0, 4.5, 0), Top + Vector3.new(0, 3, 0)
	local Dir = Spot.Face
	local Right = Dir:Cross(Vector3.yAxis)
	CamNear = CFrame.lookAt(Head + Dir * 6.3 + Vector3.new(0, 0.1, 0) - Right * 1.6, Head - Right * 0.8 + Vector3.new(0, -0.6, 0))
	CamFace = CFrame.lookAt(Head + Dir * 4.4 + Vector3.new(0, 0.15, 0) - Right * 1.1, Head - Right * 0.55 + Vector3.new(0, -0.15, 0))
	CamBody = CFrame.lookAt(Mid + Dir * 11.5 + Vector3.new(0, 1.2, 0) - Right * 2.6, Mid - Right * 1.3 + Vector3.new(0, 0.3, 0))
	FovFace, FovBody = CamFarFov, CamFarFov
end
SpotViews(nil)
-- the painted menu: the creator's rig into a slot's alcove
local function SetSpot(Slot)
	local A = Markers.alcoves[Slot]
	Spot = {Foot = V3(A.foot), Face = V3(A.face)}
	Facing = math.atan2(-Spot.Face.X, -Spot.Face.Z)
	SpotViews(Slot)
	PlaceRig()
end
local View = nil -- nil = the step's default; "Face" / "Body" once the player picks one
local CamTarget, CamFov = CamFar, CamFarFov
Camera.CFrame = CamFar
Camera.FieldOfView = CamFarFov
local Panning = false -- (MenuPan drives the camera while true)
-- depth of field: the menu's scenic values on the title / slots, focused on the character while creating
local DOF = game:GetService("Lighting"):FindFirstChildOfClass("DepthOfFieldEffect")
local DOFBase = DOF and {FocusDistance = DOF.FocusDistance, InFocusRadius = DOF.InFocusRadius, NearIntensity = DOF.NearIntensity, FarIntensity = DOF.FarIntensity}
if DOF and Painted then -- the painted hall: the alcoves sharp, the lantern and chains near the lens soft
	DOFBase = {FocusDistance = (V3(Markers.alcoves[3].foot) - CamFar.Position).Magnitude, InFocusRadius = 20, NearIntensity = 0.35, FarIntensity = 0.18}
end
local Creating = false
RunService.RenderStepped:Connect(function(Dt)
	if not Panning then
		local Target = CamTarget
		if Painted and CamTarget == CamFar then -- the menu view breathes (a slow sway, as in the preview)
			local T = os.clock()
			Target = CamFar * CFrame.new(0.09 * math.sin(T * math.pi / 4), 0.04 * math.sin(T * math.pi / 2), 0)
		end
		Camera.CFrame = Camera.CFrame:Lerp(Target, math.clamp(Dt * 6, 0, 1))
		Camera.FieldOfView += (CamFov - Camera.FieldOfView) * math.clamp(Dt * 6, 0, 1)
	end
	if DOF and DOFBase then
		local HeadPart = Rig:FindFirstChild("Head")
		if Creating and HeadPart then
			local D = (Camera.CFrame.Position - HeadPart.Position).Magnitude
			DOF.FocusDistance = D
			DOF.InFocusRadius = math.max(3, D * 0.45)
			DOF.NearIntensity = 0
			DOF.FarIntensity = 0.35
		else
			for K, V in pairs(DOFBase) do DOF[K] = V end
		end
	end
end)

-- hold left click (or a finger) on the character -- or anywhere off the UI -- and drag to turn it.
-- Uses the change in Position: an unlocked mouse's InputObject.Delta stays zero.
local DragX = nil
local WheelDrag = nil -- set while the hair-colour wheel is being dragged (it handles the move)
local RigRay = RaycastParams.new()
RigRay.FilterType = Enum.RaycastFilterType.Include
local function OnRig(Pos)
	RigRay.FilterDescendantsInstances = {Rig}
	local Ray = Camera:ViewportPointToRay(Pos.X, Pos.Y)
	return workspace:Raycast(Ray.Origin, Ray.Direction * 100, RigRay) ~= nil
end
UserInputService.InputBegan:Connect(function(I, Processed)
	if not (I.UserInputType == Enum.UserInputType.MouseButton1 or I.UserInputType == Enum.UserInputType.Touch) then return end
	if not Processed or OnRig(I.Position) then DragX = I.Position.X end
end)
UserInputService.InputEnded:Connect(function(I)
	if I.UserInputType == Enum.UserInputType.MouseButton1 or I.UserInputType == Enum.UserInputType.Touch then DragX = nil WheelDrag = nil end
end)
UserInputService.InputChanged:Connect(function(I)
	if not (I.UserInputType == Enum.UserInputType.MouseMovement or I.UserInputType == Enum.UserInputType.Touch) then return end
	if WheelDrag then WheelDrag(I) return end
	if DragX then
		Facing += (I.Position.X - DragX) * 0.012
		DragX = I.Position.X
		PlaceRig()
	end
end)
local Spin = 0 -- held turn buttons: -1 / 0 / 1
RunService.RenderStepped:Connect(function(Dt)
	if Spin ~= 0 then Facing += Spin * Dt * 3 PlaceRig() end
end)

-- ===== Choices =====
local function Fresh()
	local A = Customization.Default("Amestrian")
	return {Origin = "Amestrian", FirstName = "", Gender = "Male", Weapon = "", Appearance = A}
end
local Choice = Fresh()
local Server = nil -- State of the open slot ({Slot, Next, Identity})
-- Live prices: Managed Pricing can show a player a different price than the config's list price, so
-- the buttons use what Roblox reports (falling back to the config until it answers).
local LivePrice = {}
local function PriceOf(Id, Fallback)
	if Id and Id ~= 0 and LivePrice[Id] == nil then
		LivePrice[Id] = false
		task.spawn(function()
			local Ok, Info = pcall(function() return MarketplaceService:GetProductInfo(Id, Enum.InfoType.Product) end)
			if Ok and Info and Info.PriceInRobux then LivePrice[Id] = Info.PriceInRobux end
		end)
	end
	return LivePrice[Id] or Fallback
end
PriceOf(Slots.ProductId)
local Plus = nil -- Creator Plus state from the server ({Owned, PassId, Looks})
local OpenLooks -- opens the saved-looks panel (or the Creator Plus pitch)
local function Surname()
	local Clan = Server and Clans.Roster[Server.Identity.Clan or ""]
	return Clan and Clan.Surname or ""
end
-- undo / redo (owner 2026-10-18, creator QOL): every look change goes through Refresh, which records a
-- snapshot of nation + gender + look a moment later (so a colour-wheel drag is one step, not hundreds)
local History, HistoryAt = {}, 0 -- entries: {Key = a canonical string, Data = a deep copy}
local SyncTools = function() end
local function DeepCopy(V)
	if type(V) ~= "table" then return V end
	local T = {}
	for K, X in pairs(V) do T[K] = DeepCopy(X) end
	return T
end
local function Canon(V) -- (sorted keys, so equal looks give equal strings)
	if type(V) ~= "table" then return tostring(V) end
	local Keys = {}
	for K in pairs(V) do table.insert(Keys, K) end
	table.sort(Keys, function(A, B) return tostring(A) < tostring(B) end)
	local Out = {}
	for _, K in ipairs(Keys) do table.insert(Out, tostring(K) .. "=" .. Canon(V[K])) end
	return "{" .. table.concat(Out, ",") .. "}"
end
local function Snap()
	local Data = {Origin = Choice.Origin, Gender = Choice.Gender, Appearance = Choice.Appearance}
	return {Key = Canon(Data), Data = DeepCopy(Data)}
end
local function Commit()
	local S = Snap()
	if History[HistoryAt] and History[HistoryAt].Key == S.Key then return end
	for I = #History, HistoryAt + 1, -1 do History[I] = nil end
	table.insert(History, S)
	if #History > 60 then table.remove(History, 1) end
	HistoryAt = #History
	SyncTools()
end
local CommitToken = 0
local function Refresh()
	Appearance.Apply(Rig, Choice.Appearance, Customization.FullName(Choice.FirstName ~= "" and Choice.FirstName or "?", Surname()))
	CommitToken += 1
	local T = CommitToken
	task.delay(0.35, function() if T == CommitToken then Commit() end end)
end
local function ResetHistory()
	CommitToken += 1
	History, HistoryAt = {Snap()}, 1
	SyncTools()
end
local function RandomFrom(T) return T[math.random(1, #T)] end

-- ===== Toast (the kit's notification bar) =====
local Toast = Plate(KIT.Notice, {Size = UDim2.fromOffset(600, 48), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 18),
	Visible = false, ZIndex = 40, Parent = Gui})
local ToastText = Label("", {TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = GOLD, TextSize = 18, Size = UDim2.fromScale(1, 1),
	ZIndex = 41, Parent = Toast})
local ToastToken = 0
local function Say(Text)
	ToastToken += 1
	local T = ToastToken
	ToastText.Text = Text
	Toast.Visible = true
	task.delay(4, function() if ToastToken == T then Toast.Visible = false end end)
end

-- a modal panel: the kit's frame, title plate on top, round X to close
local function Modal(Name, Image, W, H, Title)
	local M = Plate(Image, {Name = Name, Size = UDim2.fromOffset(W, H), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52),
		Visible = false, ZIndex = 30, Active = true, Parent = Gui})
	local T = Plate(KIT.Title, {Size = UDim2.fromOffset(230, 62), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 4), ZIndex = 32, Parent = M})
	Label(Title, {FontFace = FONT_B, TextColor3 = TEXT, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 33, Parent = T})
	local X = New("ImageButton", {Name = "Close", BackgroundTransparency = 1, Image = KIT.Close, Size = UDim2.fromOffset(34, 34),
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 14), ZIndex = 33, Parent = M})
	X.Activated:Connect(function() M.Visible = false end)
	return M
end

-- ===== Title =====
local MainMenu = New("Frame", {Name = "MainMenu", BackgroundTransparency = 1, Size = UDim2.new(0, 460, 1, 0), Position = UDim2.new(0, 70, 0, 0), Parent = Gui})
-- the owner's Rensei logo (decal 108616489098661 -> its image)
New("ImageLabel", {Name = "Logo", BackgroundTransparency = 1, Image = "rbxassetid://130654945285755", ScaleType = Enum.ScaleType.Fit,
	Size = UDim2.new(0, 420, 0, 180), Position = UDim2.new(0, -10, 0.15, 12), Parent = MainMenu})
-- (owner 2026-10-28: the logo and buttons sit lower, clear of Roblox's top bar)
local MenuButtons = New("Frame", {Name = "Buttons", BackgroundTransparency = 1, Size = UDim2.new(0, 300, 0, 200), Position = UDim2.new(0, 10, 0.4, 40), Parent = MainMenu})
List(MenuButtons, 10)
local PlayBtn = Button("PLAY", KIT.Gold, {Name = "Play", TextSize = 26, Size = UDim2.new(1, 0, 0, 58), LayoutOrder = 1, Parent = MenuButtons})
local IndexBtn = Button("CLAN INDEX", KIT.Plate, {Name = "Index", TextSize = 16, Size = UDim2.new(0.8, 0, 0, 40), LayoutOrder = 2, Parent = MenuButtons})
-- the painted menu's own thin button frame once uploaded (9-slice on its 700 x 76 art), the kit's plates until then
if Painted and Art.ButtonFrame and Art.ButtonFrame ~= 0 then
	for _, B in ipairs({PlayBtn, IndexBtn}) do
		B.Image = "rbxassetid://" .. Art.ButtonFrame
		B.ScaleType, B.SliceCenter, B.SliceScale = Enum.ScaleType.Slice, Rect.new(60, 10, 640, 66), B.Size.Y.Offset / 76
	end
end
local SubLine = Label("Pick a save slot to begin.", {TextColor3 = TEXT, LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 44), Parent = MenuButtons})
New("UIStroke", {Color = Color3.new(0, 0, 0), Thickness = 1.5, Transparency = 0.3, Parent = SubLine})

-- the tip line (bottom left, the painted menu): each tip true of the game
local TipLine
if Painted then
	local TIPS = {
		{"[EQUIVALENT EXCHANGE]", "Nothing is made from nothing. Every transmutation is paid for, now or later."},
		{"[WORD ON THE RAILS]", "Heat cools on its own, even while you're away. Lie low and the State forgets."},
		{"[STATE NOTICE]", "Casting without a licence in front of the Authority is a crime."},
	}
	TipLine = Label("", {Name = "Tip", RichText = true, TextSize = 15, TextColor3 = Color3.fromRGB(200, 194, 184), TextWrapped = false,
		AnchorPoint = Vector2.new(0, 1), Size = UDim2.new(1, -60, 0, 20), Position = UDim2.new(0, 26, 1, -16), ZIndex = 4, Parent = Gui})
	New("UIStroke", {Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.4, Parent = TipLine})
	task.spawn(function()
		local I = 0
		while TipLine.Parent do
			I = I % #TIPS + 1
			TipLine.Text = ("<font color='#c44634'>%s</font>  %s"):format(TIPS[I][1], TIPS[I][2])
			TweenService:Create(TipLine, TweenInfo.new(0.6), {TextTransparency = 0}):Play()
			task.wait(9)
			TweenService:Create(TipLine, TweenInfo.new(0.6), {TextTransparency = 1}):Play()
			task.wait(0.7)
		end
	end)
end

-- ===== Save slots =====
local SlotScreen = New("Frame", {Name = "Slots", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 5, Parent = Gui})
do
	local T = Plate(KIT.Title, {Name = "Title", Size = UDim2.fromOffset(280, 76), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.12, 0), ZIndex = 6, Parent = SlotScreen})
	Label("SAVE SLOTS", {FontFace = FONT_B, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 7, Parent = T})
end
local SlotRow = New("Frame", {Name = "Row", BackgroundTransparency = 1, Size = UDim2.new(1, -80, 0, 220), AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.48), ZIndex = 6, Parent = SlotScreen})
New("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = SlotRow})
local SlotBack = Button("GO BACK", KIT.Plate, {Name = "Back", Size = UDim2.fromOffset(190, 40), AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.48, 132), ZIndex = 6, Parent = SlotScreen})

-- ===== Creation panel (the kit's tall frame) =====
local Panel = Plate(KIT.PanelTall, {Name = "Creation", Size = UDim2.fromOffset(470, 540), AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 26, 0.5, 8), Visible = false, Active = true, Parent = Gui})
local HeaderPlate = Plate(KIT.Title, {Size = UDim2.fromOffset(260, 66), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 6), ZIndex = 3, Parent = Panel})
local Header = Label("", {FontFace = FONT_B, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = HeaderPlate})
local StepTabs = New("Frame", {Name = "Steps", BackgroundTransparency = 1, Size = UDim2.new(1, -60, 0, 28), Position = UDim2.fromOffset(30, 46), Parent = Panel})
New("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = StepTabs})
local Body = New("ScrollingFrame", {Name = "Body", BackgroundTransparency = 1, Size = UDim2.new(1, -56, 1, -150), Position = UDim2.fromOffset(28, 84),
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = GOLD,
	BorderSizePixel = 0, Parent = Panel})
local Nav = New("Frame", {Name = "Nav", BackgroundTransparency = 1, Size = UDim2.new(1, -60, 0, 40), Position = UDim2.new(0, 30, 1, -58), Parent = Panel})
local NextBtn = Button("NEXT", KIT.Gold, {Name = "Next", TextSize = 18, Size = UDim2.new(0.48, 0, 1, 0), Parent = Nav})
local BackBtn = Button("BACK", KIT.Plate, {Name = "Back", TextSize = 16, Size = UDim2.new(0.48, 0, 1, 0), Position = UDim2.new(0.52, 0, 0, 0), Parent = Nav})

-- turn buttons under the rig (while creating)
local TurnBar = New("Frame", {Name = "Turn", BackgroundTransparency = 1, Size = UDim2.new(0, 300, 0, 40), AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.56, 0, 1, -40), Visible = false, Parent = Gui})
for _, T in ipairs({{"TurnLeft", -90, 1, 0}, {"TurnRight", 90, -1, 1}}) do
	local B = Button("", KIT.Plate, {Name = T[1], Size = UDim2.new(0, 60, 1, 0), Position = UDim2.new(T[4], T[4] == 1 and -60 or 0, 0, 0), Parent = TurnBar})
	New("ImageLabel", {Name = "Arrow", BackgroundTransparency = 1, Image = KIT.Chevron, ScaleType = Enum.ScaleType.Fit, Rotation = T[2],
		Size = UDim2.fromOffset(24, 24), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = B})
	B.MouseButton1Down:Connect(function() Spin = T[3] end)
	B.MouseButton1Up:Connect(function() Spin = 0 end)
	B.MouseLeave:Connect(function() Spin = 0 end)
end
UserInputService.InputEnded:Connect(function(I)
	if I.UserInputType == Enum.UserInputType.MouseButton1 or I.UserInputType == Enum.UserInputType.Touch then Spin = 0 end
end)
-- FACE / BODY: the creator camera (taps work on mobile)
local ViewButtons = {}
local function SetView(V)
	View = V
	CamTarget = (V == "Face" and CamFace) or CamBody
	CamFov = (V == "Face" and FovFace) or FovBody
	for Name, B in pairs(ViewButtons) do SetOn(B, Name == V) end
end
for I, V in ipairs({"Face", "Body"}) do
	local B = Button(V:upper(), KIT.Plate, {Name = V .. "View", TextSize = 15, Size = UDim2.new(0, 80, 1, 0),
		Position = UDim2.new(0.5, I == 1 and -84 or 4, 0, 0), Parent = TurnBar})
	ViewButtons[V] = B
	B.Activated:Connect(function() SetView(V) end)
end

-- summary card (right side, Finalize step): framed in the clan's rarity
local Card = Plate(KIT.Frame.Common, {Name = "Summary", Size = UDim2.fromOffset(340, 340), AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -30, 0.5, 0), Visible = false, Parent = Gui})
local CardBody = New("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, -70, 1, -70), Position = UDim2.fromOffset(35, 35), Parent = Card})
List(CardBody, 5)

local Editing = false -- the painted menu's EDIT: only the look (Facial, Traits without nation and gender), then SAVE LOOK
local Steps = {
	{Id = "Facial", Title = "FACIAL FEATURES", Tab = "FACE", Near = true},
	{Id = "Traits", Title = "TRAITS", Tab = "TRAITS"},
	{Id = "Weapon", Title = "STARTING WEAPON", Tab = "WEAPON"},
	{Id = "Finalize", Title = "FINALIZE", Tab = "FINALIZE"},
}
local Pages = {}
local Step = 1
local Syncers = {}
local function SyncAll() for _, F in ipairs(Syncers) do F() end end

local function Page(Id)
	local P = New("Frame", {Name = Id, BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, Parent = Body})
	List(P, 8)
	Pages[Id] = P
	return P
end

-- a sub-heading with the kit's glow line under it
local function Section(Parent, Text, Order)
	local F = New("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = Order, Parent = Parent})
	Label(Text, {FontFace = FONT_B, TextColor3 = GOLD, TextSize = 17, Size = UDim2.new(1, 0, 0, 22), Parent = F})
	Plate(KIT.Glow, {Size = UDim2.new(1, 0, 0, 6), Position = UDim2.new(0, 0, 1, -6), ImageTransparency = 0.3, Parent = F})
	return F
end

local function Grid(Parent, Order, Cell, Pad)
	local G = New("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = Order, Parent = Parent})
	New("UIGridLayout", {CellSize = Cell, CellPadding = UDim2.fromOffset(Pad or 6, Pad or 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = G})
	return G
end

-- text option buttons on the kit's tab plates; Get() = current value, Set(v) on click
local function Choices(Parent, Order, Options, Get, Set, Columns, Height)
	local G = Grid(Parent, Order, UDim2.new(1 / (Columns or 2), -6, 0, Height or 36))
	local Buttons = {}
	local function Sync() for V, B in pairs(Buttons) do SetOn(B, Get() == V) end end
	for I, O in ipairs(Options) do
		local B = Button(O.Text, KIT.Chip, {Name = O.Value == "" and "Fists" or O.Value, LayoutOrder = I, Parent = G, TextSize = 15})
		Buttons[O.Value] = B
		B.Activated:Connect(function() Set(O.Value) SyncAll() end)
	end
	Sync()
	return Sync
end

-- face-part tiles: the decal on a skin-coloured tile inside the kit's item frame
local function Thumbs(Parent, Order, OrderList, Map, Field)
	local G = Grid(Parent, Order, UDim2.fromOffset(72, 72), 4)
	local Tiles = {}
	for I, Id in ipairs(OrderList) do
		local T = New("ImageButton", {Name = Id, BackgroundTransparency = 1, Image = KIT.Frame.Common, ScaleType = Enum.ScaleType.Stretch,
			AutoButtonColor = false, LayoutOrder = I, Parent = G})
		local Skin = New("Frame", {Name = "Skin", BorderSizePixel = 0, Size = UDim2.fromScale(0.7, 0.7), Position = UDim2.fromScale(0.15, 0.15), ZIndex = 0, Parent = T})
		New("ImageLabel", {BackgroundTransparency = 1, Image = Map[Id], ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromScale(1, 1), Parent = Skin})
		Tiles[Id] = T
		T.Activated:Connect(function()
			Choice.Appearance[Field] = Id
			SyncAll()
			Refresh()
		end)
	end
	return function()
		local Skin = Customization.SkinColorOf(Choice.Appearance)
		for Id, T in pairs(Tiles) do
			local On = Choice.Appearance[Field] == Id
			T.Skin.BackgroundColor3 = Skin
			T.Image = On and KIT.Frame.Legendary or KIT.Frame.Common
		end
	end
end

-- colour swatches
local function Swatches(Parent, Order, OrderList, Colors, Field, OnPick)
	local G = Grid(Parent, Order, UDim2.fromOffset(46, 46))
	local Tiles = {}
	for I, Id in ipairs(OrderList) do
		local T = New("ImageButton", {Name = Id, BackgroundTransparency = 1, Image = KIT.Frame.Common, ScaleType = Enum.ScaleType.Stretch,
			AutoButtonColor = false, LayoutOrder = I, Parent = G})
		New("Frame", {Name = "Swatch", BackgroundColor3 = Colors[Id], BorderSizePixel = 0, Size = UDim2.fromScale(0.62, 0.62),
			Position = UDim2.fromScale(0.19, 0.19), ZIndex = 0, Parent = T}, {Corner(3)})
		Tiles[Id] = T
		T.Activated:Connect(function()
			Choice.Appearance[Field] = Id
			if OnPick then OnPick(Id) end
			SyncAll()
			Refresh()
		end)
	end
	return function()
		for Id, T in pairs(Tiles) do
			T.Image = Choice.Appearance[Field] == Id and KIT.Frame.Legendary or KIT.Frame.Common
		end
	end
end

-- "< value >" cycler over an ordered id list
local function Cycler(Parent, Order, OrderList, Field, Pretty)
	local Row = New("Frame", {Name = Field, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = Order, Parent = Parent})
	local Prev = Button("<", KIT.Chip, {Name = "Prev", Size = UDim2.new(0, 44, 1, 0), Parent = Row})
	local Mid = Plate(KIT.Plate, {Size = UDim2.new(1, -100, 1, 0), Position = UDim2.new(0, 50, 0, 0), Parent = Row})
	local Value = Label("", {Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 16, Parent = Mid})
	local Next = Button(">", KIT.Chip, {Name = "NextValue", Size = UDim2.new(0, 44, 1, 0), Position = UDim2.new(1, -44, 0, 0), Parent = Row})
	local function Move(D)
		local I = table.find(OrderList, Choice.Appearance[Field]) or 1
		Choice.Appearance[Field] = OrderList[(I - 1 + D) % #OrderList + 1]
		SyncAll()
		Refresh()
	end
	Prev.Activated:Connect(function() Move(-1) end)
	Next.Activated:Connect(function() Move(1) end)
	return function() Value.Text = Pretty(Choice.Appearance[Field]) end
end

-- ===== 1. Facial features =====
do
	local P = Page("Facial")
	Section(P, "HAIRS", 1)
	-- three catalog hair IDs, worn together (the server loads and checks each)
	local IdBoxes = {}
	local function SyncIds()
		local Ids = Choice.Appearance.HairIds
		for I, B in ipairs(IdBoxes) do
			if not B:IsFocused() then B.Text = Ids[I] and tostring(Ids[I]) or "" end
		end
	end
	for I = 1, Customization.HairIdSlots do
		local B, Holder = Field({Name = "Box", PlaceholderText = "Hair ID " .. I .. " here...", LayoutOrder = 1 + I, Parent = P})
		Holder.Name = "HairId" .. I
		IdBoxes[I] = B
		B.FocusLost:Connect(function()
			local Ids = Choice.Appearance.HairIds
			local Text = B.Text
			if Text:match("^%s*$") then
				if Ids[I] then table.remove(Ids, I) SyncAll() Refresh() end
				return
			end
			local Id = Customization.ParseHairId(Text)
			if not Id then Say("Paste a hair's Roblox ID (the number in its catalog link).") SyncIds() return end
			if Id == Ids[I] then return end
			B.Text = "loading..."
			local Ok, Msg = Remote:InvokeServer("Hair", Id)
			if Ok then
				if Ids[I] then Ids[I] = Id else table.insert(Ids, Id) end
				Choice.Appearance.HairIds = Customization.HairIdsOf(Choice.Appearance)
			else
				Say(Msg or "That hair didn't load.")
			end
			SyncAll()
			Refresh()
		end)
	end
	table.insert(Syncers, SyncIds)
	Label("Any Roblox hair accessory; up to three are worn together. They take your hair colour (Traits).", {TextColor3 = DIM, TextSize = 13,
		Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 5}).Parent = P
	Label("Or a preset (used when no ID is set):", {TextColor3 = DIM, TextSize = 14, LayoutOrder = 6}).Parent = P
	table.insert(Syncers, Cycler(P, 7, Customization.HairOrder, "Hair", function(Id) return Customization.Hair[Id].Name end))

	Section(P, "EYES", 10)
	table.insert(Syncers, Thumbs(P, 11, Customization.EyeOrder, Customization.Eyes, "Eyes"))
	Section(P, "EYEBROWS", 12)
	table.insert(Syncers, Thumbs(P, 13, Customization.BrowOrder, Customization.Brows, "Brows"))
	Section(P, "MOUTH", 14)
	table.insert(Syncers, Thumbs(P, 15, Customization.MouthOrder, Customization.Mouths, "Mouth"))
	local Rnd = Button("RANDOMIZE FACE", KIT.Plate, {LayoutOrder = 20, Size = UDim2.new(1, 0, 0, 38), Parent = P})
	Rnd.Activated:Connect(function()
		local A = Choice.Appearance
		A.Eyes, A.Brows, A.Mouth = RandomFrom(Customization.EyeOrder), RandomFrom(Customization.BrowOrder), RandomFrom(Customization.MouthOrder)
		SyncAll()
		Refresh()
	end)
end

-- ===== colour wheel (hue around, white at the centre; brightness on the slider) =====
-- Field = the appearance field it writes ("HairColor", or "Skin" for Creator Plus), ColorOf = its reader.
-- Only a real pick writes the field, so showing a preset colour on the wheel never turns it into a hex.
local function ColorWheel(Parent, Order, Field, ColorOf)
	local IsHair = Field == "HairColor"
	local R = 72
	local Row = New("Frame", {Name = Field .. "Wheel", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, R * 2 + 30), LayoutOrder = Order, Parent = Parent})
	local Wheel = New("Frame", {Name = "Wheel", BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(R * 2, R * 2), Position = UDim2.fromOffset(4, 4),
		ClipsDescendants = false, Parent = Row}, {New("UICorner", {CornerRadius = UDim.new(1, 0)})})
	-- full-width spokes through the centre (GUI rotation pivots on an element's centre): each one is
	-- hue H at the top, white in the middle, hue H + 0.5 at the bottom
	local N = 90
	local W = math.ceil(math.pi * R / N) + 3
	for I = 0, N - 1 do
		local H = I / (N * 2)
		New("Frame", {BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(W, R * 2),
			Position = UDim2.fromScale(0.5, 0.5), Rotation = H * 360, Parent = Wheel},
			{New("UIGradient", {Rotation = 90, Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromHSV(H, 1, 1)),
				ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, Color3.fromHSV((H + 0.5) % 1, 1, 1))})})})
	end
	local Shade = New("Frame", {Name = "Shade", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		ZIndex = 2, Parent = Wheel}, {New("UICorner", {CornerRadius = UDim.new(1, 0)})})
	local Ring = Plate(KIT.Knob, {Size = UDim2.fromOffset(20, 20), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3, Parent = Wheel})
	local Hit = New("TextButton", {Name = "Hit", Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = Wheel})
	-- brightness slider: black -> the picked colour, with the kit's knob
	local Track = New("Frame", {BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Size = UDim2.fromOffset(R * 2, 10),
		Position = UDim2.fromOffset(4, R * 2 + 15), Parent = Row}, {Corner(5), New("UIStroke", {Color = LINE, Thickness = 1})})
	local TrackGrad = New("UIGradient", {Parent = Track})
	local Knob = Plate(KIT.Knob, {Size = UDim2.fromOffset(22, 22), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(1, 0.5), ZIndex = 2, Parent = Track})
	local KHit = New("TextButton", {Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, -9), ZIndex = 3, Parent = Track})
	-- the colour + the ID-hair option
	local Side = New("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, -(R * 2 + 24), 1, 0), Position = UDim2.fromOffset(R * 2 + 20, 0), Parent = Row})
	List(Side, 8)
	-- the picked colour, in the kit's item frame (as the swatches are)
	local ChipFrame = Plate(KIT.Frame.Legendary, {Size = UDim2.fromOffset(58, 58), LayoutOrder = 1, Parent = Side})
	local Chip = New("Frame", {BorderSizePixel = 0, Size = UDim2.fromScale(0.62, 0.62), Position = UDim2.fromScale(0.19, 0.19), ZIndex = 0, Parent = ChipFrame}, {Corner(3)})
	local Hex = Label("", {TextColor3 = DIM, TextSize = 14, LayoutOrder = 2, Parent = Side})
	local Own = Button("", KIT.Plate, {Name = "OwnColors", TextSize = 13, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 3, Visible = IsHair, Parent = Side})
	Label(IsHair and "ID hairs: tinted with this colour, or kept in their own colours." or "Any skin colour. Pick a swatch above to go back to a preset.",
		{TextColor3 = DIM, TextSize = 12, Size = UDim2.new(1, 0, 0, 42), LayoutOrder = 4, Parent = Side})
	Own.Activated:Connect(function()
		Choice.Appearance.HairOwnColors = not Choice.Appearance.HairOwnColors
		SyncAll()
		Refresh()
	end)

	local Hue, Sat, Val = 0, 0, 1
	local function Apply(Live)
		if Live then Choice.Appearance[Field] = Color3.fromHSV(Hue, Sat, Val):ToHex() end
		Shade.BackgroundTransparency = Val
		Ring.Position = UDim2.new(0.5, math.sin(Hue * 2 * math.pi) * Sat * R, 0.5, -math.cos(Hue * 2 * math.pi) * Sat * R)
		Knob.Position = UDim2.fromScale(Val, 0.5)
		local C = Color3.fromHSV(Hue, Sat, Val)
		TrackGrad.Color = ColorSequence.new(Color3.new(0, 0, 0), Color3.fromHSV(Hue, Sat, 1))
		Chip.BackgroundColor3 = C
		Hex.Text = "#" .. C:ToHex():upper()
		if Live then
			Refresh()
			if not IsHair then SyncAll() end -- (the skin swatches and face tiles follow the skin)
		end
	end
	local function Point(I) -- (this ScreenGui ignores the inset, so input positions already match it)
		return Vector2.new(I.Position.X, I.Position.Y)
	end
	local function PickWheel(I)
		local C = Wheel.AbsolutePosition + Wheel.AbsoluteSize / 2
		local D = Point(I) - C
		local Rad = Wheel.AbsoluteSize.X / 2
		Sat = math.clamp(D.Magnitude / Rad, 0, 1)
		Hue = (math.atan2(D.X, -D.Y) / (2 * math.pi)) % 1
		Apply(true)
	end
	local function PickVal(I)
		Val = math.clamp((Point(I).X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
		Apply(true)
	end
	Hit.InputBegan:Connect(function(I)
		if I.UserInputType == Enum.UserInputType.MouseButton1 or I.UserInputType == Enum.UserInputType.Touch then PickWheel(I) WheelDrag = PickWheel end
	end)
	KHit.InputBegan:Connect(function(I)
		if I.UserInputType == Enum.UserInputType.MouseButton1 or I.UserInputType == Enum.UserInputType.Touch then PickVal(I) WheelDrag = PickVal end
	end)
	return function()
		if not WheelDrag then
			Hue, Sat, Val = ColorOf(Choice.Appearance):ToHSV()
			Apply(false)
		end
		SetText(Own, Choice.Appearance.HairOwnColors and "ID HAIRS: OWN COLOURS" or "ID HAIRS: TINTED")
	end
end

-- ===== 2. Traits =====
local TraitsLocked = {}
do
	local P = Page("Traits")
	Section(P, "NATION", 1)
	local Opts = {}
	for _, N in ipairs(Customization.NationOrder) do table.insert(Opts, {Text = Customization.Nations[N].Name, Value = N}) end
	table.insert(Syncers, Choices(P, 2, Opts, function() return Choice.Origin end, function(V)
		if V == Choice.Origin then return end
		Choice.Origin = V
		local D = Customization.Default(V)
		local A = Choice.Appearance
		A.Skin, A.HairColor, A.Eyes = D.Skin, D.HairColor, D.Eyes
		A.Outfit = Customization.OutfitFor(V)
		Refresh()
	end, 3, 36))
	-- nation card (the reference's race card) on the kit's popup frame
	local NCard = Plate(KIT.Popup, {Size = UDim2.new(1, 0, 0, 118), LayoutOrder = 3, Parent = P})
	local NTitle = Label("", {FontFace = FONT_B, TextColor3 = GOLD, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -40, 0, 22), Position = UDim2.fromOffset(20, 12), Parent = NCard})
	local NText = Label("", {TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, -44, 1, -44), Position = UDim2.fromOffset(22, 36), Parent = NCard})
	table.insert(Syncers, function()
		NTitle.Text = "- " .. Customization.Nations[Choice.Origin].Name:upper() .. " -"
		NText.Text = (Customization.NationBlurb[Choice.Origin] or "") .. "\nStarter outfit: " .. Customization.Outfits[Customization.OutfitFor(Choice.Origin)].Name
	end)

	Section(P, "GENDER", 4)
	local GOpts = {}
	for _, G in ipairs(Customization.Genders) do table.insert(GOpts, {Text = G, Value = G}) end
	table.insert(Syncers, Choices(P, 5, GOpts, function() return Choice.Gender end, function(V)
		if V == Choice.Gender then return end
		-- the body follows the gender; so does the preset hair unless the player picked their own
		local A = Choice.Appearance
		if A.Hair == Customization.GenderHair[Choice.Gender] then A.Hair = Customization.GenderHair[V] end
		A.Body = V
		Choice.Gender = V
		Refresh()
	end, 2, 36))

	Section(P, "HAIR COLOR", 6)
	table.insert(Syncers, ColorWheel(P, 7, "HairColor", Customization.HairColorOf))
	Section(P, "SKIN COLOR", 8)
	table.insert(Syncers, Swatches(P, 9, Customization.SkinOrder, Customization.Skins, "Skin"))
	-- Creator Plus: any skin colour on a wheel (locked otherwise)
	Section(P, "CUSTOM SKIN COLOR", 10)
	local Lock = Button("UNLOCK WITH CREATOR PLUS", KIT.Plate, {Name = "UnlockSkin", TextSize = 14, Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 11, Parent = P})
	Lock.Activated:Connect(function() if OpenLooks then OpenLooks() end end)
	table.insert(Syncers, ColorWheel(P, 12, "Skin", Customization.SkinColorOf))
	local SkinWheel = P:FindFirstChild("SkinWheel")
	-- (Edit mode hides the nation and gender rows: a made character keeps both)
	TraitsLocked = {}
	for _, C in ipairs(P:GetChildren()) do
		if C:IsA("GuiObject") and C.LayoutOrder >= 1 and C.LayoutOrder <= 5 then table.insert(TraitsLocked, C) end
	end
	table.insert(Syncers, function()
		local Owned = Plus ~= nil and Plus.Owned == true
		Lock.Visible = not Owned
		SkinWheel.Visible = Owned
	end)
end

-- ===== 3. Weapon (stats: Modules.Data.Rensei.WeaponStats) =====
do
	local P = Page("Weapon")
	Label("Fight with your fists, or start with a weapon. You can find others later.", {TextColor3 = DIM, TextSize = 15, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 1}).Parent = P
	local function Combo(S) local T = 0 for _, D in ipairs(S.Light) do T += D end return T end
	local MaxCombo, MaxHeavy, MinSpeed = 0, 0, math.huge
	for _, W in ipairs(Customization.StartWeapons) do
		local S = WeaponStats[W]
		if S then MaxCombo, MaxHeavy, MinSpeed = math.max(MaxCombo, Combo(S)), math.max(MaxHeavy, S.Heavy), math.min(MinSpeed, S.Speed) end
	end
	local WCard = Plate(KIT.Popup, {Name = "Stats", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4, Parent = P},
		{New("UIPadding", {PaddingTop = UDim.new(0, 16), PaddingBottom = UDim.new(0, 18), PaddingLeft = UDim.new(0, 22), PaddingRight = UDim.new(0, 22)})})
	List(WCard, 6)
	local Name = Label("", {FontFace = FONT_B, TextColor3 = GOLD, TextSize = 20, LayoutOrder = 1, Parent = WCard})
	local Kind = Label("", {TextColor3 = DIM, TextSize = 14, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 2, Parent = WCard})
	local Desc = Label("", {TextSize = 15, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = WCard})
	local function Bar(Order, Text)
		local Row = New("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = Order, Parent = WCard})
		Label(Text, {Size = UDim2.new(0.28, 0, 1, 0), TextColor3 = DIM, TextSize = 14, Parent = Row})
		local Track = Plate(KIT.BarFrame, {Size = UDim2.new(0.44, 0, 0, 14), Position = UDim2.new(0.28, 0, 0.5, -7), Parent = Row})
		local Fill = Plate(KIT.BarFill, {Size = UDim2.new(0, 0, 1, -6), Position = UDim2.new(0, 3, 0, 3), ScaleType = Enum.ScaleType.Stretch, Parent = Track})
		local Value = Label("", {Size = UDim2.new(0.28, -6, 1, 0), Position = UDim2.new(0.72, 6, 0, 0), TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Right, Parent = Row})
		return function(Frac, Txt)
			TweenService:Create(Fill, TweenInfo.new(0.2), {Size = UDim2.new(math.clamp(Frac, 0.04, 1), -6, 1, -6)}):Play()
			Value.Text = Txt
		end
	end
	local ComboBar, HeavyBar, SpeedBar, ReachBar = Bar(4, "Combo"), Bar(5, "Heavy"), Bar(6, "Speed"), Bar(7, "Reach")
	local Extra = Label("", {TextSize = 14, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, RichText = true, LayoutOrder = 8, Parent = WCard})
	local function ShowStats()
		local S = WeaponStats[Choice.Weapon]
		WCard.Visible = S ~= nil
		if not S then return end
		Name.Text = S.Display:upper()
		Kind.Text = S.Class .. (S.Rarity ~= "-" and ("  ·  " .. S.Rarity) or "")
		Desc.Text = S.Description
		local C = Combo(S)
		ComboBar(C / MaxCombo, S.Gun and (S.Light[1] .. " / shot") or (C .. " (4 hits)"))
		HeavyBar(S.Heavy / MaxHeavy, tostring(S.Heavy))
		SpeedBar(MinSpeed / S.Speed, S.Speed .. "s")
		ReachBar(S.Gun and 1 or S.Reach / 5, S.Gun and (S.Reach .. " (ranged)") or tostring(S.Reach))
		local Lines = {}
		if S.Gun then
			table.insert(Lines, ("<font color='#E6CD78'>Ammo</font>  %d rounds, %.1fs reload, %.2fs between shots"):format(S.Gun.Magazine, S.Gun.Reload, S.Gun.FireDelay))
		end
		if S.Skill then
			table.insert(Lines, ("<font color='#E6CD78'>Skill</font>  %s: %d damage, %ds cooldown"):format(S.Skill.Name, S.Skill.Damage, S.Skill.Cooldown))
		end
		if S.Passive then table.insert(Lines, "<font color='#E6CD78'>Passive</font>  " .. S.Passive) end
		Extra.Text = table.concat(Lines, "\n")
		Extra.Visible = #Lines > 0
	end
	local Opts = {}
	for _, W in ipairs(Customization.StartWeapons) do table.insert(Opts, {Text = W == "" and "Fists" or W, Value = W}) end
	table.insert(Syncers, Choices(P, 3, Opts, function() return Choice.Weapon end, function(V) Choice.Weapon = V end, 2, 36))
	table.insert(Syncers, ShowStats)
end

-- ===== Clan index (every clan, its rarity, buffs and lore; the odds and pity) =====
local Index = Modal("ClanIndex", KIT.PanelWide, 800, 526, "CLAN INDEX")
local OpenIndex
do
	local Left = New("ScrollingFrame", {Name = "List", BackgroundTransparency = 1, Size = UDim2.new(0, 400, 1, -96), Position = UDim2.fromOffset(34, 60),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = GOLD, BorderSizePixel = 0,
		ZIndex = 31, Parent = Index})
	List(Left, 6)
	local Right = New("Frame", {Name = "Detail", BackgroundTransparency = 1, Size = UDim2.new(1, -490, 1, -100), Position = UDim2.fromOffset(456, 62),
		ZIndex = 31, Parent = Index})
	List(Right, 6)
	local DName = Label("", {FontFace = FONT_B, TextSize = 24, Size = UDim2.new(1, 0, 0, 30), ZIndex = 32, LayoutOrder = 1, Parent = Right})
	local DTier = Label("", {FontFace = FONT_B, TextSize = 15, ZIndex = 32, LayoutOrder = 2, Parent = Right})
	local DText = Label("", {TextSize = 15, RichText = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 32, LayoutOrder = 3, Parent = Right})
	Plate(KIT.Glow, {Size = UDim2.new(1, 0, 0, 6), ImageTransparency = 0.3, ZIndex = 32, LayoutOrder = 4, Parent = Right})
	local Rules = Label("", {TextSize = 13, TextColor3 = DIM, RichText = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 32, LayoutOrder = 5, Parent = Right})
	local function Show(Id)
		local C = Clans.Roster[Id]
		DName.Text = C.Name
		DName.TextColor3 = Clans.TierColor[C.Rarity]
		DTier.Text = C.Rarity:upper() .. "  ·  " .. Clans.Odds[C.Rarity] .. "% tier  ·  surname \"" .. C.Surname .. "\""
		DTier.TextColor3 = Clans.TierColor[C.Rarity]
		local L = {"<b>Buffs</b>"}
		for _, B in ipairs(C.Buffs) do table.insert(L, "<font color='#8FD07A'>+ " .. B .. "</font>") end
		table.insert(L, "<b>Debuffs</b>")
		for _, D in ipairs(C.Debuffs) do table.insert(L, "<font color='#E08070'>- " .. D .. "</font>") end
		if C.Lore ~= "" then table.insert(L, "<b>Lore</b>") table.insert(L, "<i>" .. C.Lore .. "</i>") end
		DText.Text = table.concat(L, "\n")
	end
	local Order = 0
	for _, Tier in ipairs(Clans.Tiers) do
		Order += 1
		local Head = New("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 24), LayoutOrder = Order, ZIndex = 31, Parent = Left})
		Label(Tier:upper() .. "  —  " .. Clans.Odds[Tier] .. "%" .. (Tier == "Mythic" and "  (animated)" or ""), {FontFace = FONT_B,
			TextColor3 = Clans.TierColor[Tier], TextSize = 16, Size = UDim2.fromScale(1, 1), ZIndex = 32, Parent = Head})
		Order += 1
		local G = Grid(Left, Order, UDim2.fromOffset(92, 92), 6)
		G.ZIndex = 31
		local Ids = Clans.InTier(Tier)
		if #Ids == 0 then
			Label("No clans in this tier yet.", {TextColor3 = DIM, TextSize = 14, ZIndex = 32, Parent = G})
		end
		for I, Id in ipairs(Ids) do
			local F = TIER_FRAME[Tier]
			local B = New("ImageButton", {Name = Id, BackgroundTransparency = 1, Image = F[1], ImageColor3 = F[2], ScaleType = Enum.ScaleType.Stretch,
				AutoButtonColor = false, LayoutOrder = I, ZIndex = 32, Parent = G})
			Label(Clans.Roster[Id].Name, {FontFace = FONT_B, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, -20, 1, -20),
				Position = UDim2.fromOffset(10, 10), ZIndex = 33, Parent = B})
			B.Activated:Connect(function() Show(Id) end)
		end
	end
	OpenIndex = function()
		local I = Server and Server.Identity
		Rules.Text = "<b>Odds</b>  Common 50%, Uncommon 28%, Rare 15%, Legendary 6%, Mythic 1%. Tiers with no clans yet " ..
			"share their odds with the others.\n<b>Pity</b>  +1 every roll. From 20, Rare odds climb; the 30th roll is always Rare or " ..
			"better; a Rare or better resets it." .. (I and ("\n<font color='#E6CD78'>Your pity: " .. (I.Pity or 0) .. " / 30</font>") or "")
		Show(Clans.Order[1])
		Index.Visible = true
	end
end

-- ===== Rerolls: Robux packs + codes =====
local Shop = Modal("Rerolls", KIT.PanelTall, 400, 438, "CLAN REROLLS")
local OpenShop
do
	local Body2 = New("ScrollingFrame", {BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, -70, 1, -100), Position = UDim2.fromOffset(35, 60), ZIndex = 31,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = GOLD, Parent = Shop})
	List(Body2, 8)
	local Have = Label("", {FontFace = FONT_B, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 32, LayoutOrder = 1, Parent = Body2})
	for I, Pack in ipairs(Clans.RerollPacks) do
		local B = Button(("%d REROLL%s  ·  %d R$"):format(Pack.Rolls, Pack.Rolls == 1 and "" or "S", Pack.Price), KIT.Gold,
			{Name = "Pack" .. I, TextSize = 16, Size = UDim2.new(1, 0, 0, 42), LayoutOrder = 1 + I, ZIndex = 32, Parent = Body2})
		B.Label.ZIndex = 33
		if Pack.Id ~= 0 then
			task.spawn(function()
				local Ok, Info = pcall(function() return MarketplaceService:GetProductInfo(Pack.Id, Enum.InfoType.Product) end)
				if Ok and Info and Info.PriceInRobux and B.Parent then
					SetText(B, ("%d REROLL%s  ·  %d R$"):format(Pack.Rolls, Pack.Rolls == 1 and "" or "S", Info.PriceInRobux))
				end
			end)
		end
		B.Activated:Connect(function()
			if Pack.Id == 0 then Say("Reroll purchases aren't set up yet.") return end
			MarketplaceService:PromptProductPurchase(Player, Pack.Id)
		end)
	end
	Plate(KIT.Glow, {Size = UDim2.new(1, 0, 0, 6), ImageTransparency = 0.3, ZIndex = 32, LayoutOrder = 10, Parent = Body2})
	Label("HAVE A CODE?", {FontFace = FONT_B, TextColor3 = GOLD, TextSize = 15, ZIndex = 32, LayoutOrder = 11, Parent = Body2})
	local CodeBox, CodeHolder = Field({PlaceholderText = "Enter code", LayoutOrder = 12, Parent = Body2})
	CodeHolder.ZIndex = 32 CodeBox.ZIndex = 33
	local Redeem = Button("REDEEM", KIT.Plate, {Name = "Redeem", TextSize = 15, Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 13, ZIndex = 32, Parent = Body2})
	Redeem.Label.ZIndex = 33
	Redeem.Activated:Connect(function()
		SetText(Redeem, "...")
		local Ok, Msg, Identity = Remote:InvokeServer("Redeem", CodeBox.Text)
		SetText(Redeem, "REDEEM")
		if Ok and Identity and Server then Server.Identity = Identity CodeBox.Text = "" end
		Say(Msg or (Ok and "Code redeemed." or "That code didn't work."))
		SyncAll()
	end)
	table.insert(Syncers, function()
		local I = Server and Server.Identity
		Have.Text = I and ("You have " .. (I.PaidRolls or 0) .. " reroll" .. ((I.PaidRolls or 0) == 1 and "" or "s")) or ""
	end)
	OpenShop = function()
		if not Server then Say("Pick a save slot first.") return end
		Shop.Visible = true
		SyncAll()
	end
end
-- ===== Creator tools (owner 2026-10-18 QOL): undo / redo / random look / reset (free), saved looks (Creator Plus) =====
local function LoadState(Data)
	Data = DeepCopy(Data)
	if not Editing then Choice.Origin, Choice.Gender = Data.Origin, Data.Gender end -- (a made character's are fixed)
	Choice.Appearance = Data.Appearance
	if Editing then Choice.Appearance.Body = Choice.Gender Choice.Appearance.Outfit = Customization.OutfitFor(Choice.Origin) end
	SyncAll()
	Refresh()
end
local function Undo()
	Commit() -- (a change still waiting to be recorded counts first)
	if HistoryAt <= 1 then return end
	HistoryAt -= 1
	LoadState(History[HistoryAt].Data)
	SyncTools()
end
local function Redo()
	Commit()
	if HistoryAt >= #History then return end
	HistoryAt += 1
	LoadState(History[HistoryAt].Data)
	SyncTools()
end
-- random look true to your nation and gender; typed hair IDs stay
local function RandomLook()
	local Old = Choice.Appearance
	local L = Customization.RandomLook(Choice.Origin)
	L.Body = Choice.Gender
	L.Hair = RandomFrom(Customization.GenderHairs[Choice.Gender])
	L.Outfit = Customization.OutfitFor(Choice.Origin)
	L.HairIds, L.HairOwnColors = Old.HairIds, Old.HairOwnColors
	Choice.Appearance = L
	SyncAll()
	Refresh()
end
-- back to the nation's default look (nation, gender and name stay)
local function ResetLook()
	local D = Customization.Default(Choice.Origin)
	D.Body = Choice.Gender
	D.Hair = Customization.GenderHair[Choice.Gender] or D.Hair
	Choice.Appearance = D
	SyncAll()
	Refresh()
end

local Tools = New("Frame", {Name = "Tools", BackgroundTransparency = 1, Size = UDim2.new(0, 360, 0, 34), AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0, -8), Parent = TurnBar})
New("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Tools})
local ToolButtons = {}
for I, T in ipairs({{"Undo", "UNDO", Undo}, {"Redo", "REDO", Redo}, {"Random", "RANDOM", RandomLook}, {"Reset", "RESET", ResetLook}, {"Looks", "LOOKS", function() OpenLooks() end}}) do
	local B = Button(T[2], KIT.Plate, {Name = T[1], TextSize = 13, Size = UDim2.new(0, 68, 1, 0), LayoutOrder = I, Parent = Tools})
	ToolButtons[T[1]] = B
	B.Activated:Connect(T[3])
end
SyncTools = function()
	ToolButtons.Undo.ImageTransparency = HistoryAt > 1 and 0 or 0.5
	ToolButtons.Undo.Label.TextTransparency = HistoryAt > 1 and 0 or 0.5
	ToolButtons.Redo.ImageTransparency = HistoryAt < #History and 0 or 0.5
	ToolButtons.Redo.Label.TextTransparency = HistoryAt < #History and 0 or 0.5
	SetText(ToolButtons.Looks, (Plus and Plus.Owned) and "LOOKS" or "LOOKS +")
end
-- Ctrl+Z / Ctrl+Y (Ctrl+Shift+Z) while creating, not while typing
UserInputService.InputBegan:Connect(function(I, Processed)
	if Processed or not Creating or UserInputService:GetFocusedTextBox() then return end
	if not (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then return end
	local Shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
	if I.KeyCode == Enum.KeyCode.Z then if Shift then Redo() else Undo() end
	elseif I.KeyCode == Enum.KeyCode.Y then Redo() end
end)

-- Saved looks / the Creator Plus pitch
local LooksPanel = Modal("Looks", KIT.PanelTall, 420, 470, "SAVED LOOKS")
LooksPanel.AnchorPoint, LooksPanel.Position = Vector2.new(1, 0.5), UDim2.new(1, -30, 0.5, 0) -- right side: the character stays in view
local LooksBody = New("ScrollingFrame", {Name = "Body", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, -70, 1, -100), Position = UDim2.fromOffset(35, 62), ZIndex = 31,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3, ScrollBarImageColor3 = GOLD, Parent = LooksPanel})
List(LooksBody, 8)
local function Z(G, N) -- the modal's layers (built after the ZIndex pass below)
	G.ZIndex = N
	if G:FindFirstChild("Label") then G.Label.ZIndex = N + 1 end
	return G
end
local function FetchPlus()
	local Ok, State = pcall(function() return Remote:InvokeServer("Plus") end)
	if Ok and type(State) == "table" then Plus = State end
	SyncAll()
	SyncTools()
end
local function BuyPlus()
	if Plus and Plus.Owned then Say("You already have Creator Plus.") return end
	if CreatorPlus.ProductId ~= 0 then MarketplaceService:PromptProductPurchase(Player, CreatorPlus.ProductId) return end
	if CreatorPlus.PassId == 0 then Say("Creator Plus isn't on sale yet.") return end
	MarketplaceService:PromptGamePassPurchase(Player, CreatorPlus.PassId)
end
local BuildLooks
BuildLooks = function()
	for _, C in ipairs(LooksBody:GetChildren()) do if C:IsA("GuiObject") then C:Destroy() end end
	if not (Plus and Plus.Owned) then
		LooksPanel:FindFirstChildOfClass("ImageLabel"):FindFirstChildOfClass("TextLabel").Text = "CREATOR PLUS"
		Label("Extra creator tools. Cosmetic only: no stats, no accessories.", {TextColor3 = DIM, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 40), ZIndex = 32, LayoutOrder = 1, Parent = LooksBody})
		Label(("<font color='#E6CD78'>+ Custom skin colour</font>\nAny colour on a wheel, not just the 8 swatches.\n\n<font color='#E6CD78'>+ %d saved looks</font>\nKeep looks on your account and load them into any new character."):format(CreatorPlus.LookSlots),
			{TextSize = 15, RichText = true, Size = UDim2.new(1, 0, 0, 150), TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 32, LayoutOrder = 2, Parent = LooksBody})
		Label("Free for everyone: undo / redo (Ctrl+Z / Ctrl+Y), random look, reset.", {TextColor3 = DIM, TextSize = 13,
			Size = UDim2.new(1, 0, 0, 36), ZIndex = 32, LayoutOrder = 3, Parent = LooksBody})
		local Buy = Z(Button("GET CREATOR PLUS", KIT.Gold, {Name = "BuyPlus", TextSize = 18, Size = UDim2.new(1, 0, 0, 48), LayoutOrder = 4, Parent = LooksBody}), 32)
		Buy.Activated:Connect(BuyPlus)
		local SaleId = CreatorPlus.ProductId ~= 0 and CreatorPlus.ProductId or CreatorPlus.PassId
		if SaleId ~= 0 then
			task.spawn(function()
				local Kind = CreatorPlus.ProductId ~= 0 and Enum.InfoType.Product or Enum.InfoType.GamePass
				local Ok, Info = pcall(function() return MarketplaceService:GetProductInfo(SaleId, Kind) end)
				if Ok and Info and Info.PriceInRobux and Buy.Parent then SetText(Buy, ("GET CREATOR PLUS  ·  %d R$"):format(Info.PriceInRobux)) end
			end)
		end
		return
	end
	LooksPanel:FindFirstChildOfClass("ImageLabel"):FindFirstChildOfClass("TextLabel").Text = "SAVED LOOKS"
	Label("Save the look you're making, or load a saved one. Loading sets the nation, gender and look; your name and clan stay.",
		{TextColor3 = DIM, TextSize = 13, Size = UDim2.new(1, 0, 0, 44), ZIndex = 32, LayoutOrder = 0, Parent = LooksBody})
	for I = 1, CreatorPlus.LookSlots do
		local L = Plus.Looks and Plus.Looks[I]
		local Row = Plate(KIT.Popup, {Name = "Look" .. I, Size = UDim2.new(1, 0, 0, 92), ZIndex = 32, LayoutOrder = I, Parent = LooksBody})
		Label("LOOK " .. I, {FontFace = FONT_B, TextColor3 = GOLD, TextSize = 16, Size = UDim2.new(1, -40, 0, 20), Position = UDim2.fromOffset(20, 12), ZIndex = 33, Parent = Row})
		Label(L and (Customization.Nations[L.Origin].Name .. "  ·  " .. L.Gender .. (Customization.IsCustomSkin(L.Appearance) and "  ·  custom skin" or "")) or "Empty",
			{TextColor3 = L and TEXT or DIM, TextSize = 14, Size = UDim2.new(1, -40, 0, 18), Position = UDim2.fromOffset(20, 32), ZIndex = 33, Parent = Row})
		local Btns = New("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, -40, 0, 30), Position = UDim2.new(0, 20, 1, -42), ZIndex = 33, Parent = Row})
		New("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Btns})
		local function Act(Name, Text, Order, F)
			local B = Z(Button(Text, KIT.Chip, {Name = Name, TextSize = 13, Size = UDim2.new(1 / 3, -4, 1, 0), LayoutOrder = Order, Parent = Btns}), 34)
			B.Activated:Connect(F)
			return B
		end
		local Load = Act("Load", "LOAD", 1, function()
			if not L then return end
			LoadState({Origin = L.Origin, Gender = L.Gender, Appearance = L.Appearance})
			Say("Look " .. I .. " loaded.")
		end)
		Act("Save", L and "OVERWRITE" or "SAVE HERE", 2, function()
			local Ok, Msg, Looks = Remote:InvokeServer("SaveLook", {Index = I, Look = {Origin = Choice.Origin, Gender = Choice.Gender, Appearance = Choice.Appearance}})
			if Looks then Plus.Looks = Looks end
			Say(Msg or (Ok and "Look saved." or "Couldn't save that look."))
			BuildLooks()
		end)
		local Clear = Act("Clear", "CLEAR", 3, function()
			if not L then return end
			local Ok, Msg, Looks = Remote:InvokeServer("ClearLook", I)
			if Looks then Plus.Looks = Looks end
			Say(Msg or (Ok and "Look cleared." or "Couldn't clear that look."))
			BuildLooks()
		end)
		if not L then Load.ImageTransparency, Load.Label.TextTransparency, Clear.ImageTransparency, Clear.Label.TextTransparency = 0.5, 0.5, 0.5, 0.5 end
	end
end
OpenLooks = function()
	if not Plus then FetchPlus() end
	BuildLooks()
	LooksPanel.Visible = true
end
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(P, PassId, Bought)
	if P ~= Player or not Bought or PassId ~= CreatorPlus.PassId then return end
	task.wait(0.5)
	FetchPlus()
	if LooksPanel.Visible then BuildLooks() end
	Say("Creator Plus unlocked.")
end)

for _, M in ipairs({Index, Shop, LooksPanel}) do
	for _, D in ipairs(M:GetDescendants()) do if D:IsA("GuiObject") and D.ZIndex < 31 then D.ZIndex = 31 end end
end

-- ===== 4. Finalize: first name + clan (the surname) =====
local FirstBox, RollBtn, FinishBtn
local ShowSummary
do
	local P = Page("Finalize")
	Section(P, "FIRST NAME", 1)
	local Row = New("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 2, Parent = P})
	local Holder
	FirstBox, Holder = Field({PlaceholderText = "Type a name", TextSize = 18, Size = UDim2.new(1, -104, 1, 0), Parent = Row})
	FirstBox.Name = "FirstName"
	local Rnd = Button("RANDOM", KIT.Plate, {Name = "RandomName", Size = UDim2.new(0, 96, 1, 0), Position = UDim2.new(1, -96, 0, 0), TextSize = 14, Parent = Row})
	-- name suggestions from the nation's list, filtered by what's typed (the reference's name list)
	local Suggest = Grid(P, 3, UDim2.new(1 / 3, -6, 0, 28), 4)
	local function SyncSuggest()
		for _, C in ipairs(Suggest:GetChildren()) do if C:IsA("GuiButton") then C:Destroy() end end
		local Typed = FirstBox.Text:lower()
		local N = 0
		for _, Name in ipairs(Customization.Names[Choice.Origin] or {}) do
			if N >= 9 then break end
			if Typed == "" or Name:lower():sub(1, #Typed) == Typed then
				N += 1
				local B = Button(Name, KIT.Chip, {Name = Name, TextSize = 14, LayoutOrder = N, Parent = Suggest})
				SetOn(B, Name == Choice.FirstName)
				B.Activated:Connect(function() FirstBox.Text = Name end)
			end
		end
	end
	Rnd.Activated:Connect(function() FirstBox.Text = RandomFrom(Customization.Names[Choice.Origin]) end)
	FirstBox:GetPropertyChangedSignal("Text"):Connect(function()
		Choice.FirstName = FirstBox.Text:sub(1, Customization.NameMax)
		SyncSuggest()
		if ShowSummary then ShowSummary() end
		Refresh()
	end)
	table.insert(Syncers, SyncSuggest)

	Section(P, "CLAN (YOUR SURNAME)", 5)
	Label("Your clan is rolled, not chosen. One free roll; more from rerolls.", {TextColor3 = DIM, TextSize = 13,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 6}).Parent = P
	RollBtn = Button("ROLL CLAN", KIT.Gold, {Name = "RollClan", TextSize = 19, Size = UDim2.new(1, 0, 0, 46), LayoutOrder = 7, Parent = P})
	local Row2 = New("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 8, Parent = P})
	local IndexB = Button("CLAN INDEX", KIT.Plate, {Name = "ClanIndex", TextSize = 14, Size = UDim2.new(0.49, 0, 1, 0), Parent = Row2})
	local ShopB = Button("GET REROLLS", KIT.Plate, {Name = "GetRerolls", TextSize = 14, Size = UDim2.new(0.49, 0, 1, 0), Position = UDim2.fromScale(0.51, 0), Parent = Row2})
	IndexB.Activated:Connect(function() OpenIndex() end)
	ShopB.Activated:Connect(function() OpenShop() end)
	local Rolling = false
	RollBtn.Activated:Connect(function()
		if Rolling then return end
		Rolling = true
		SetText(RollBtn, "ROLLING...")
		local Ok, Msg, Identity = Remote:InvokeServer("RollClan")
		Rolling = false
		if Ok and Identity and Server then
			Server.Identity = Identity
			local Clan = Clans.Roster[Identity.Clan]
			if Clan then Say(Clan.Rarity:upper() .. "  ·  " .. Clan.Name) end
		elseif Msg then
			Say(Msg)
			if Msg == "No clan rolls left." then OpenShop() end
		end
		SyncAll()
		Refresh()
	end)
	table.insert(Syncers, function()
		local I = Server and Server.Identity
		if not I then return end
		SetText(RollBtn, I.FreeRoll and "ROLL CLAN (FREE)" or (I.PaidRolls > 0 and ("REROLL  ·  " .. I.PaidRolls .. " LEFT") or "NO ROLLS LEFT"))
		RollBtn.ImageTransparency = (I.FreeRoll or I.PaidRolls > 0) and 0 or 0.45
	end)
	FinishBtn = Button("FINISH", KIT.Gold, {Name = "Finish", TextSize = 22, Size = UDim2.new(1, 0, 0, 50), LayoutOrder = 9, Parent = P})
	Label("Your character can't be remade after this.", {TextColor3 = DIM, TextSize = 13, LayoutOrder = 10}).Parent = P
end

-- the summary card: name, clan (by rarity), nation, weapon
do
	local NameL = Label("", {FontFace = FONT_B, TextColor3 = GOLD, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 1, Parent = CardBody})
	local ClanTier = Label("", {FontFace = FONT_B, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2, Parent = CardBody})
	local ClanText = Label("", {TextSize = 13, RichText = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 3, Parent = CardBody})
	Plate(KIT.Glow, {Size = UDim2.new(1, 0, 0, 6), ImageTransparency = 0.3, LayoutOrder = 4, Parent = CardBody})
	local Info = Label("", {TextSize = 14, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 5, Parent = CardBody})
	local Glow = 0
	RunService.RenderStepped:Connect(function(Dt) -- Mythic clans shimmer (the slide's "Animated")
		local Clan = Server and Clans.Roster[Server.Identity.Clan or ""]
		if Card.Visible and Clan and Clan.Animated then
			Glow += Dt
			local T = (math.sin(Glow * 3) + 1) / 2
			ClanTier.TextColor3 = Clans.TierColor.Mythic:Lerp(GOLD, T)
			Card.ImageColor3 = TIER_FRAME.Mythic[2]:Lerp(Color3.fromRGB(255, 220, 140), T)
		end
	end)
	ShowSummary = function()
		local Clan = Server and Clans.Roster[Server.Identity.Clan or ""]
		local First = Choice.FirstName ~= "" and Choice.FirstName or "?"
		NameL.Text = "+ " .. Customization.FullName(First, Clan and Clan.Surname or "") .. " +"
		local F = TIER_FRAME[Clan and Clan.Rarity or "Common"]
		Card.Image, Card.ImageColor3 = F[1], F[2]
		if Clan then
			ClanTier.Text = Clan.Name:upper() .. "  ·  " .. Clan.Rarity:upper()
			ClanTier.TextColor3 = Clans.TierColor[Clan.Rarity]
			local Lines = {}
			for _, B in ipairs(Clan.Buffs) do table.insert(Lines, "<font color='#8FD07A'>+ " .. B .. "</font>") end
			for _, D in ipairs(Clan.Debuffs) do if D ~= "N/A" then table.insert(Lines, "<font color='#E08070'>- " .. D .. "</font>") end end
			ClanText.Text = table.concat(Lines, "\n")
		else
			ClanTier.Text = "NO CLAN YET"
			ClanTier.TextColor3 = DIM
			ClanText.Text = "Roll your clan on the left."
		end
		Info.Text = table.concat({
			Customization.Nations[Choice.Origin].Name .. "  ·  " .. Choice.Gender,
			"Weapon: " .. (Choice.Weapon == "" and "Fists" or Choice.Weapon),
			"Outfit: " .. Customization.Outfits[Customization.OutfitFor(Choice.Origin)].Name,
		}, "\n")
	end
	table.insert(Syncers, ShowSummary)
end

-- step tabs (the kit's plates; its section-tab image has "Gameplay" printed on it)
local ShowStep
local TabButtons = {}
for I, S in ipairs(Steps) do
	local B = Button(S.Tab, KIT.Plate, {Name = S.Id, LayoutOrder = I, Size = UDim2.new(1 / #Steps, -4, 1, 0), TextSize = 13, Parent = StepTabs})
	TabButtons[I] = B
	B.Activated:Connect(function() ShowStep(I) end)
end

function ShowStep(N)
	local Last = Editing and 2 or #Steps -- (Edit: Facial and Traits only)
	Step = math.clamp(N, 1, Last)
	for I, S in ipairs(Steps) do
		Pages[S.Id].Visible = I == Step
		SetOn(TabButtons[I], I == Step)
		TabButtons[I].Visible = I <= Last
	end
	for _, C in ipairs(TraitsLocked) do C.Visible = not Editing end
	Header.Text = Editing and Step == 1 and "EDIT LOOK" or Steps[Step].Title
	Body.CanvasPosition = Vector2.zero
	SetText(BackBtn, Step == 1 and "SLOTS" or "BACK")
	NextBtn.Visible = Step < Last or Editing
	SetText(NextBtn, Editing and Step == Last and "SAVE LOOK" or "NEXT")
	Card.Visible = Steps[Step].Id == "Finalize"
	-- the step's default view (Facial = FACE, the rest = BODY) unless the player picked one
	local Want = View or (Steps[Step].Near and "Face" or "Body")
	CamTarget = Want == "Face" and CamFace or CamBody
	CamFov = Want == "Face" and FovFace or FovBody
	for Name, B in pairs(ViewButtons) do SetOn(B, Name == Want) end
	SyncAll()
end

-- ===== Screens =====
local function ShowTitle()
	Panel.Visible, TurnBar.Visible, Card.Visible, SlotScreen.Visible, Index.Visible, Shop.Visible = false, false, false, false, false, false
	LooksPanel.Visible = false
	MainMenu.Visible = true
	CamTarget, CamFov = CamFar, CamFarFov
	Creating = false
end
local function ShowCreation()
	MainMenu.Visible, SlotScreen.Visible = false, false
	if TipLine then TipLine.Visible = false end
	Panel.Visible, TurnBar.Visible = true, true
	Creating = true
	View = nil
	ShowStep(1)
	Refresh()
	ResetHistory()
	task.spawn(FetchPlus)
end

local function Play()
	local Ok, Msg, Where = Remote:InvokeServer("Play")
	if Msg then Say(Msg) end
	if Ok and Where then SubLine.Text = "Heading to the " .. Where .. "..." end
	return Ok
end

-- a freshly opened slot: its saved look (if made) or a new character's defaults
local function Adopt(State)
	Server = State
	local I = State.Identity
	if I.CharacterCreated and I.Appearance then
		Choice.Appearance = I.Appearance
		Choice.Origin = I.Origin
		Choice.Gender = I.Gender or Choice.Gender
		Choice.FirstName = I.FirstName or ""
		Appearance.Apply(Rig, I.Appearance, I.Name)
	else
		Choice = Fresh()
		FirstBox.Text = ""
		SyncAll()
		Refresh()
	end
end

local ShowSlots
local function SlotCard(Order, Tier, Title, Lines, OnClick)
	local F = TIER_FRAME[Tier] or TIER_FRAME.Common
	local B = New("ImageButton", {Name = "Slot" .. Order, BackgroundTransparency = 1, Image = F[1], ImageColor3 = F[2], ScaleType = Enum.ScaleType.Stretch,
		Size = UDim2.fromOffset(200, 200), LayoutOrder = Order, AutoButtonColor = false, ZIndex = 6, Parent = SlotRow})
	Label(Title, {FontFace = FONT_B, TextColor3 = Title == "+" and DIM or TEXT, TextSize = Title == "+" and 54 or 19,
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, -50, 0, Title == "+" and 60 or 48), Position = UDim2.new(0, 25, 0.22, 0), ZIndex = 7, Parent = B})
	Label(Lines, {TextColor3 = DIM, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, -50, 0, 64),
		Position = UDim2.new(0, 25, 0.52, 0), RichText = true, ZIndex = 7, Parent = B})
	B.MouseEnter:Connect(function() B.ImageColor3 = F[2]:Lerp(Color3.fromRGB(255, 230, 170), 0.35) end)
	B.MouseLeave:Connect(function() B.ImageColor3 = F[2] end)
	B.Activated:Connect(OnClick)
	return B
end

-- small round icon button in a slot card's corner (star / trash)
-- (Image = a kit icon; Ticked: the favourite box with its checkmark)
local function CardIcon(Holder, Name, Image, Ticked, Right, OnClick)
	local B = IconButton(Image, {Name = Name, Size = UDim2.fromOffset(26, 26), AnchorPoint = Vector2.new(Right and 1 or 0, 0),
		Position = UDim2.new(Right and 1 or 0, Right and -18 or 18, 0, 18), ZIndex = 8, Parent = Holder}, Ticked)
	B.Activated:Connect(OnClick)
	return B
end

-- "are you sure" box for deleting a slot (the kit's popup + Accept/Decline)
local Confirm = Plate(KIT.Popup, {Name = "Confirm", Size = UDim2.fromOffset(430, 180), AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5), Visible = false, ZIndex = 20, Active = true, Parent = SlotScreen})
local ConfirmText = Label("", {TextXAlignment = Enum.TextXAlignment.Center, TextSize = 18, RichText = true, Size = UDim2.new(1, -50, 0, 70),
	Position = UDim2.fromOffset(25, 22), ZIndex = 21, Parent = Confirm})
local ConfirmYes = Button("DELETE", KIT.Red, {Name = "Yes", Size = UDim2.new(0.5, -40, 0, 40), Position = UDim2.new(0, 30, 1, -64), ZIndex = 21, Parent = Confirm})
local ConfirmNo = Button("CANCEL", KIT.Gold, {Name = "No", Size = UDim2.new(0.5, -40, 0, 40), Position = UDim2.new(0.5, 10, 1, -64), ZIndex = 21, Parent = Confirm})
ConfirmYes.Label.ZIndex, ConfirmNo.Label.ZIndex = 22, 22
local Pending = nil -- slot waiting for the confirm
ConfirmNo.Activated:Connect(function() Pending = nil Confirm.Visible = false end)
ConfirmYes.Activated:Connect(function()
	local Slot = Pending
	if not Slot then return end
	SetText(ConfirmYes, "...")
	local Ok, Msg = Remote:InvokeServer("Delete", Slot)
	SetText(ConfirmYes, "DELETE")
	Pending = nil
	Confirm.Visible = false
	Say(Ok and "Slot " .. Slot .. " deleted." or (Msg or "Couldn't delete that slot."))
	ShowSlots()
end)

local Opening = false

-- ===== The painted menu: the alcoves, the slot cards, the pan =====
local Backdrop = Painted and MenuBackdrop.Start(PaintedStage, Markers, Art) or nil
local Figures = {} -- [slot] = the alcove's figure: a PreviewRig copy in that slot's look, or the plain grey blank
local AlcoveSlot = nil -- the slot whose alcove the creator is in
local RegionNames = (function()
	local M = RenseiData:FindFirstChild("Regions")
	local Ok, R = pcall(function() return M and require(M) end)
	return Ok and type(R) == "table" and type(R.Regions) == "table" and R.Regions or {}
end)()
local RARITY_HEX = {}
for Tier, C in pairs(Clans.TierColor or {}) do RARITY_HEX[Tier] = C:ToHex() end

-- each alcove's own pieces (built per niche by build_stage.py): the gate, the lamp, the chalk circles
local AlcoveParts = {}
if Painted then
	for I = 1, #Markers.alcoves do AlcoveParts[I] = {Gate = {}, Lights = {}, Circles = {}} end
	for _, D in ipairs(PaintedStage:GetDescendants()) do
		local N = D.Name
		local G = N:match("^Gate(%d)_") or N:match("^Spike(%d)_") or N:match("^GateBar(%d)$")
		local L = N:match("^Light_NicheLamp(%d)$") or N:match("^Light_NicheFill(%d)$")
		local B = N:match("^Bulb(%d)$")
		local C = N:match("^NicheCircle(%d)$") or N:match("^FootCircle(%d)$")
		local A = AlcoveParts[tonumber(G or L or B or C or "") or 0]
		if A then
			if G then table.insert(A.Gate, D) elseif L then table.insert(A.Lights, D) elseif B then A.Bulb = D else table.insert(A.Circles, D) end
		end
	end
end

-- owned slots: gate open, lamp lit, chalk circles drawn; the rest stay dark behind their gates
local function SetAlcoves(Owned)
	for I, A in ipairs(AlcoveParts) do
		local Open = I <= Owned
		for _, P in ipairs(A.Gate) do
			P.Transparency = Open and 1 or 0
			for _, T in ipairs(P:GetChildren()) do if T:IsA("Decal") then T.Transparency = Open and 1 or 0 end end -- (Textures too)
		end
		for _, P in ipairs(A.Lights) do
			for _, L in ipairs(P:GetChildren()) do if L:IsA("Light") then L.Enabled = Open end end
		end
		if A.Bulb then A.Bulb.Material = Open and Enum.Material.Neon or Enum.Material.Metal A.Bulb.Color = Open and Color3.fromRGB(255, 196, 130) or Color3.fromRGB(40, 36, 34) end
		for _, P in ipairs(A.Circles) do
			local Img = P:FindFirstChild("Image")
			if Img then Img.Transparency = Open and 0 or 1 end
		end
	end
end

-- idle poses an R6 can hold (owner 2026-10-28: "cool idle poses that don't overlap into the buildings"): shoulder
-- and neck offsets. Odd slots fold their arms, even slots stand at ease. No idle animation on these figures (Rensei's
-- idle holds the arms in its own stance, which fights the pose): they breathe instead (Breathe, below).
local function Pose(Fig, Kind)
	local T = Fig:FindFirstChild("Torso")
	local RSh, LSh, Neck = T and T:FindFirstChild("Right Shoulder"), T and T:FindFirstChild("Left Shoulder"), T and T:FindFirstChild("Neck")
	if not (RSh and LSh and Neck) then return end
	-- R turns the limb about its joint in the torso's own frame (+X right, +Y up, -Z forward)
	local function Turn(Motor, R) Motor.C0 = CFrame.new(Motor.C0.Position) * R * Motor.C0.Rotation end
	if Kind == "Crossed" then
		-- both arms raised forward and turned in, so the forearms fold across the chest, the left over the right
		Turn(RSh, CFrame.new(-0.25, -0.3, -0.45) * CFrame.Angles(0, math.rad(48), 0) * CFrame.Angles(math.rad(82), 0, 0))
		Turn(LSh, CFrame.new(0.25, -0.05, -0.85) * CFrame.Angles(0, math.rad(-48), 0) * CFrame.Angles(math.rad(78), 0, 0))
		Turn(Neck, CFrame.Angles(math.rad(-3), 0, math.rad(9))) -- head cocked
	elseif Kind == "Rest" then
		-- at ease: arms back and in, hands together behind, chin up
		Turn(RSh, CFrame.new(0, 0, 0.12) * CFrame.Angles(0, 0, math.rad(-9)) * CFrame.Angles(math.rad(-20), 0, 0))
		Turn(LSh, CFrame.new(0, 0, 0.12) * CFrame.Angles(0, 0, math.rad(9)) * CFrame.Angles(math.rad(-20), 0, 0))
		Turn(Neck, CFrame.Angles(math.rad(7), 0, 0))
	end
end

-- the alcove figures breathe: a slow rise of the chest and a drift of the head (their joints' Transform, every frame)
local function Breathe()
	local T = os.clock()
	for Slot, Fig in pairs(Figures) do
		local Root = Fig:FindFirstChild("HumanoidRootPart") and Fig.HumanoidRootPart:FindFirstChild("RootJoint")
		local Neck = Fig:FindFirstChild("Torso") and Fig.Torso:FindFirstChild("Neck")
		if Root then Root.Transform = CFrame.Angles(0.012 * math.sin(T * math.pi / 2 + Slot), 0, 0) * CFrame.new(0, 0, 0.03 * math.sin(T * math.pi / 2 + Slot)) end
		if Neck then Neck.Transform = CFrame.Angles(0, 0, 0.035 * math.sin(T * math.pi / 4 + Slot * 2.3)) end
	end
end
if Painted then RunService.RenderStepped:Connect(Breathe) end

local function Figure(Slot, S)
	if Figures[Slot] then Figures[Slot]:Destroy() end
	local A = Markers.alcoves[Slot]
	local Fig = ReplicatedStorage.PreviewRig:Clone()
	Fig.Name = "Slot" .. Slot
	local Face = V3(A.face)
	Fig.HumanoidRootPart.Anchored = true
	Fig.HumanoidRootPart.CFrame = CFrame.new(V3(A.foot) + Vector3.new(0, 3, 0)) * CFrame.Angles(0, math.atan2(-Face.X, -Face.Z), 0)
	if S.Created and S.Appearance then
		for _, Id in ipairs(S.Appearance.HairIds or {}) do task.spawn(function() Remote:InvokeServer("Hair", Id) end) end -- (into HairCache)
		Fig.Parent = PaintedStage
		Appearance.Apply(Fig, S.Appearance, S.Name)
		Pose(Fig, Slot % 2 == 1 and "Crossed" or "Rest")
	else
		-- Roblox's plain grey figure: a character not made yet
		local BC = Fig:FindFirstChildOfClass("BodyColors")
		if BC then BC:Destroy() end
		for _, C in ipairs(Fig:GetChildren()) do
			if C:IsA("BasePart") and C.Name ~= "HumanoidRootPart" then C.Color = Color3.fromRGB(163, 162, 165) end
			if C:IsA("Shirt") or C:IsA("Pants") or C:IsA("ShirtGraphic") or C:IsA("Accessory") or C:IsA("CharacterMesh") then C:Destroy() end
		end
		local F = Fig.Head:FindFirstChildOfClass("Decal")
		if F then F:Destroy() end
		Fig.Parent = PaintedStage
	end
	Figures[Slot] = Fig
	return Fig
end

-- a card's bust: a live copy of the slot's figure in a ViewportFrame (rebuilt when its hair arrives)
local function Bust(Parent, Fig)
	local VPF = New("ViewportFrame", {BackgroundTransparency = 1, Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(16, 6),
		Ambient = Color3.fromRGB(150, 130, 120), LightColor = Color3.fromRGB(255, 214, 170), LightDirection = Vector3.new(-0.4, -0.6, -1),
		ZIndex = 8, Parent = Parent}, {New("UICorner", {CornerRadius = UDim.new(1, 0)})})
	local WM = New("WorldModel", {Parent = VPF})
	local Cam = New("Camera", {FieldOfView = 32, Parent = VPF})
	VPF.CurrentCamera = Cam
	local function Build()
		WM:ClearAllChildren()
		Fig.Archivable = true
		local C = Fig:Clone()
		for _, D in ipairs(C:GetDescendants()) do if D:IsA("Script") or D:IsA("LocalScript") then D:Destroy() end end
		C.Parent = WM
		local Head = C:FindFirstChild("Head")
		if Head then
			local Front = Head.CFrame.LookVector
			Cam.CFrame = CFrame.lookAt(Head.Position + Front * 4.2 + Vector3.new(0, 0.1, 0), Head.Position - Vector3.new(0, 0.55, 0))
		end
	end
	Build()
	local Pending = false
	Fig.ChildAdded:Connect(function(Ch)
		if not Ch:IsA("Accessory") or Pending then return end
		Pending = true
		task.delay(0.4, function() Pending = false if VPF.Parent then Build() end end)
	end)
end

local Grid = New("ScrollingFrame", {Name = "Grid", BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -26, 0, 28),
	Size = UDim2.fromOffset(2 * 330 + 12, 3 * 74), Visible = false, ZIndex = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 0, ScrollBarImageColor3 = GOLD, Parent = SlotScreen})
local GridLayout = New("UIGridLayout", {CellSize = UDim2.fromOffset(330, 64), CellPadding = UDim2.fromOffset(12, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Grid})

-- the painted card frames once uploaded (9-slice), the kit's rarity frames until then
local function CardImage(Hover)
	local Id = Hover and Art.CardFrameHover or Art.CardFrame
	if Id and Id ~= 0 then return "rbxassetid://" .. Id, true end
	return Hover and KIT.Frame.Legendary or KIT.Frame.Common, false
end

local function PaintedCard(Order, OnClick)
	local Img, Sliced = CardImage(false)
	local B = New("ImageButton", {Name = "Card" .. Order, BackgroundTransparency = 1, Image = Img, AutoButtonColor = false, LayoutOrder = Order, ZIndex = 6, Parent = Grid})
	if Sliced then B.ScaleType, B.SliceCenter, B.SliceScale = Enum.ScaleType.Slice, Rect.new(60, 40, 800, 110), 64 / 150 else B.ScaleType = Enum.ScaleType.Stretch end
	B.MouseEnter:Connect(function() B.Image = CardImage(true) end)
	B.MouseLeave:Connect(function() B.Image = CardImage(false) end)
	B.Activated:Connect(OnClick)
	return B
end

local function CardText(B, Text, Props)
	local L = Label(Text, {ZIndex = 8, Parent = B, TextWrapped = false, RichText = true})
	for K, X in pairs(Props) do L[K] = X end
	return L
end

-- a card's kit icon (bottom right, right to left): delete, edit, favourite
local function SmallIcon(B, Name, Image, Index, OnClick, Ticked)
	local Sz = Phone and 30 or 22 -- (big enough for a thumb on a phone)
	local I = IconButton(Image, {Name = Name, Size = UDim2.fromOffset(Sz, Sz), AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14 - (Index - 1) * (Sz + 4), 1, -4), ZIndex = 9, Parent = B}, Ticked)
	I.Activated:Connect(OnClick)
	return I
end

-- into a slot's alcove: the camera pans there (the reaction flaring), then the creator opens on that spot
local function EnterCreator(Slot, Edit)
	Editing = Edit
	AlcoveSlot = Slot
	MainMenu.Visible, SlotScreen.Visible = false, false
	if TipLine then TipLine.Visible = false end
	if Figures[Slot] then Figures[Slot].Parent = nil end
	SetSpot(Slot)
	RigShown = true
	PlaceRig()
	Refresh()
	Panning = true
	MenuPan.Run(Camera, Camera.CFrame, Camera.FieldOfView, CamBody, FovBody, MenuPan.Seconds, function(P)
		if Backdrop then Backdrop:Surge(Slot, P) end
	end)
	Panning = false
	if Backdrop then Backdrop:Surge(Slot, 0.35) end
	CamTarget, CamFov = CamBody, FovBody
	ShowCreation()
end

-- and back out to the menu view
local function LeaveCreator()
	Panel.Visible, TurnBar.Visible, Card.Visible, LooksPanel.Visible = false, false, false, false
	Creating = false
	Panning = true
	MenuPan.Run(Camera, Camera.CFrame, Camera.FieldOfView, CamFar, CamFarFov, 2.6)
	Panning = false
	if Backdrop and AlcoveSlot then Backdrop:Surge(AlcoveSlot, 0) end
	Editing, AlcoveSlot = false, nil
	ShowSlots()
end

local function SaveLook()
	SetText(NextBtn, "...")
	local Ok, Msg = Remote:InvokeServer("Edit", {Appearance = Choice.Appearance})
	SetText(NextBtn, "SAVE LOOK")
	if not Ok then Say(Msg or "Couldn't save that look.") return end
	Say("Look saved.")
	LeaveCreator()
end

local CardsBuild = 0
local function ShowPainted()
	Panel.Visible, TurnBar.Visible, Card.Visible, LooksPanel.Visible, Confirm.Visible = false, false, false, false, false
	MainMenu.Visible, SlotScreen.Visible = true, true
	if TipLine then TipLine.Visible = true end
	SlotScreen.Title.Visible, SlotRow.Visible, SlotBack.Visible = false, false, false
	Grid.Visible = true
	CamTarget, CamFov = CamFar, CamFarFov
	Creating = false
	RigShown = false
	PlaceRig()
	-- (a newer call wins: two at once, e.g. a layout change while the list loads, would otherwise both fill the grid)
	CardsBuild += 1
	local Build = CardsBuild
	local Info = Remote:InvokeServer("Slots")
	if Build ~= CardsBuild then return end
	for _, C in ipairs(Grid:GetChildren()) do if C:IsA("GuiObject") then C:Destroy() end end
	if not Info then Say("Couldn't load your save slots. Rejoin to try again.") return end
	table.sort(Info.List, function(A, B)
		if (A.Slot == Info.Favorite) ~= (B.Slot == Info.Favorite) then return A.Slot == Info.Favorite end
		return A.Slot < B.Slot
	end)
	SetAlcoves(Info.Owned)
	for Slot = Info.Owned + 1, #Markers.alcoves do
		if Figures[Slot] then Figures[Slot]:Destroy() Figures[Slot] = nil end
	end
	local Empty = {}
	for Order, S in ipairs(Info.List) do
		local Fig = Figure(S.Slot, S)
		local B
		if S.Created then
			B = PaintedCard(Order, function()
				if Opening then return end
				Opening = true
				local Ok, Msg, State = Remote:InvokeServer("Open", S.Slot)
				Opening = false
				if not Ok then Say(Msg or "That slot didn't open.") return end
				Adopt(State)
				if State.Next == "Customize" then EnterCreator(S.Slot, false) return end
				ShowTitle()
				SubLine.Text = "Slot " .. S.Slot .. ": " .. State.Identity.Name
				Play()
			end)
			Bust(B, Fig)
			local Clan = Clans.Roster[S.Clan]
			local Tier = Clan and Clan.Rarity
			CardText(B, S.Name, {FontFace = FONT_B, TextSize = 17, TextColor3 = Color3.fromRGB(232, 226, 214), Size = UDim2.new(0, 170, 0, 20), Position = UDim2.fromOffset(76, 10)})
			local NationName = Customization.Nations[S.Origin] and Customization.Nations[S.Origin].Name or ""
			CardText(B, ("Lv %d%s"):format(S.Level, Tier and (" · <font color='#%s'>%s</font>"):format(RARITY_HEX[Tier] or "e0d8c8", Clan.Name) or "")
				.. (Phone and NationName ~= "" and (" · " .. NationName) or ""), -- (on a phone the nation shares this line: the icons are bigger)
				{TextSize = 15, TextColor3 = DIM, Size = UDim2.new(0, Phone and 150 or 160, 0, 18), Position = UDim2.fromOffset(76, 33)})
			local Region = RegionNames[S.Region] and RegionNames[S.Region].Name or (S.Region ~= "" and S.Region or "")
			CardText(B, Region, {TextSize = 15, TextColor3 = TEXT, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0, 110, 0, 18), Position = UDim2.new(1, -124, 0, 8)})
			if not Phone then
				CardText(B, NationName, {TextSize = 15, TextColor3 = DIM,
					TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0, 84, 0, 18), Position = UDim2.new(1, -176, 0, 33)})
			end
			local Fav = S.Slot == Info.Favorite
			SmallIcon(B, "Trash", KIT.Close, 1, function()
				Pending = S.Slot
				ConfirmText.Text = ("Delete <b>%s</b> in slot %d?\nThis can't be undone."):format(S.Name, S.Slot)
				Confirm.Visible = true
			end)
			SmallIcon(B, "Edit", KIT.Eye, 2, function()
				if Opening then return end
				Opening = true
				local Ok, Msg, State = Remote:InvokeServer("Open", S.Slot)
				Opening = false
				if not Ok then Say(Msg or "That slot didn't open.") return end
				Adopt(State)
				EnterCreator(S.Slot, State.Identity.CharacterCreated == true)
			end)
			SmallIcon(B, "Star", KIT.Box, 3, function()
				local Ok, Msg = Remote:InvokeServer("Favorite", S.Slot)
				if not Ok then Say(Msg or "Couldn't star that slot.") end
				ShowSlots()
			end, Fav)
		else
			table.insert(Empty, S.Slot)
			B = PaintedCard(Order, function()
				if Opening then return end
				Opening = true
				local Ok, Msg, State = Remote:InvokeServer("Open", S.Slot)
				Opening = false
				if not Ok then Say(Msg or "That slot didn't open.") return end
				Adopt(State)
				EnterCreator(S.Slot, false)
			end)
			CardText(B, "CREATE CHARACTER", {FontFace = FONT_B, TextSize = 17, TextColor3 = TEXT, Size = UDim2.new(0, 220, 0, 22), Position = UDim2.fromOffset(28, 21)})
			CardText(B, "Slot " .. S.Slot, {TextSize = 15, TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0, 80, 0, 18), Position = UDim2.new(1, -96, 0, 23)})
		end
	end
	if Backdrop then Backdrop:SetAlcoves(Markers.alcoves, Empty) end
	if Info.Owned < Info.Max then
		local B = PaintedCard(99, function()
			if not Info.CanBuy then Say("Slot purchases aren't set up yet.") return end
			MarketplaceService:PromptProductPurchase(Player, Slots.ProductId)
		end)
		New("ImageLabel", {Name = "Add", BackgroundTransparency = 1, Image = KIT.Add, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromOffset(28, 28),
			Position = UDim2.fromOffset(24, 18), ZIndex = 8, Parent = B})
		CardText(B, "NEW SLOT", {FontFace = FONT_B, TextSize = 17, TextColor3 = DIM, Size = UDim2.new(0, 160, 0, 22), Position = UDim2.fromOffset(60, 21)})
		CardText(B, ("R$ %d"):format(PriceOf(Slots.ProductId, Info.Price)), {FontFace = FONT_B, TextSize = 16, TextColor3 = GOLD,
			TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0, 90, 0, 20), Position = UDim2.new(1, -106, 0, 22)})
	end
end
ShowSlots = function()
	if Painted then ShowPainted() return end
	MainMenu.Visible, Panel.Visible, TurnBar.Visible, Card.Visible = false, false, false, false
	SlotScreen.Visible = true
	Confirm.Visible = false
	LooksPanel.Visible = false
	CamTarget = CamFar
	Creating = false
	for _, C in ipairs(SlotRow:GetChildren()) do if C:IsA("GuiObject") then C:Destroy() end end
	local Info = Remote:InvokeServer("Slots")
	if not Info then Say("Couldn't load your save slots. Rejoin to try again.") return end
	-- the starred slot comes first, the rest in slot order
	table.sort(Info.List, function(A, B)
		if (A.Slot == Info.Favorite) ~= (B.Slot == Info.Favorite) then return A.Slot == Info.Favorite end
		return A.Slot < B.Slot
	end)
	for Order, S in ipairs(Info.List) do
		local Clan = Clans.Roster[S.Clan]
		local Title = S.Created and S.Name or "+"
		local Lines = S.Created and (("Level %d\n%s"):format(S.Level, Customization.Nations[S.Origin] and Customization.Nations[S.Origin].Name or "")
			.. (Clan and ("\n<font color='#%s'>%s</font>"):format(Clans.TierColor[Clan.Rarity]:ToHex(), Clan.Rarity) or "")) or "EMPTY"
		local SlotB = SlotCard(Order, S.Created and Clan and Clan.Rarity or "Common", Title, Lines, function()
			if Opening then return end
			Opening = true
			local Ok, Msg, State = Remote:InvokeServer("Open", S.Slot)
			Opening = false
			if not Ok then Say(Msg or "That slot didn't open.") return end
			Adopt(State)
			if State.Next == "Customize" then
				ShowCreation()
			else
				ShowTitle()
				SubLine.Text = "Slot " .. S.Slot .. ": " .. State.Identity.Name
				Play()
			end
		end)
		SlotB.Name = "Slot" .. S.Slot
		local Fav = S.Slot == Info.Favorite
		CardIcon(SlotB, "Star", KIT.Box, Fav, false, function()
			local Ok, Msg = Remote:InvokeServer("Favorite", S.Slot)
			if not Ok then Say(Msg or "Couldn't star that slot.") end
			ShowSlots()
		end)
		CardIcon(SlotB, "Trash", KIT.Close, false, true, function()
			if not S.Created then Say("That slot is already empty.") return end
			Pending = S.Slot
			ConfirmText.Text = ("Delete <b>%s</b> in slot %d?\nThis can't be undone."):format(S.Name, S.Slot)
			Confirm.Visible = true
		end)
	end
	if Info.Owned < Info.Max then
		local B = SlotCard(99, "Legendary", "NEW SLOT", ("— %d R$ —"):format(PriceOf(Slots.ProductId, Info.Price)), function()
			if not Info.CanBuy then Say("Slot purchases aren't set up yet.") return end
			MarketplaceService:PromptProductPurchase(Player, Slots.ProductId)
		end)
		B.ImageTransparency = 0.25
	end
end
MarketplaceService.PromptProductPurchaseFinished:Connect(function(UserId, ProductId, Bought)
	if UserId ~= Player.UserId or not Bought then return end
	if CreatorPlus.ProductId ~= 0 and ProductId == CreatorPlus.ProductId then
		-- the server records it in ProcessReceipt; ask until it shows (a few seconds at most)
		for _ = 1, 8 do
			task.wait(1)
			FetchPlus()
			if Plus and Plus.Owned then break end
		end
		if LooksPanel.Visible then BuildLooks() end
		Say(Plus and Plus.Owned and "Creator Plus unlocked." or "Purchase received. Creator Plus will unlock in a moment.")
		return
	end
	task.wait(1) -- (the server grants it in ProcessReceipt)
	if ProductId == Slots.ProductId and SlotScreen.Visible then ShowSlots() return end
	local State = Remote:InvokeServer("State")
	if State and Server then Server.Identity = State.Identity SyncAll() Say("Rerolls added.") end
end)

SlotBack.Activated:Connect(ShowTitle)
BackBtn.Activated:Connect(function()
	if Step > 1 then ShowStep(Step - 1) return end
	if Painted and AlcoveSlot then LeaveCreator() else ShowSlots() end
end)
NextBtn.Activated:Connect(function()
	if Editing and Step == 2 then SaveLook() else ShowStep(Step + 1) end
end)
PlayBtn.Activated:Connect(ShowSlots)
IndexBtn.Activated:Connect(function() OpenIndex() end)

FinishBtn.Activated:Connect(function()
	if Choice.FirstName == "" then Say("Give your character a first name.") return end
	if not (Server and Clans.Roster[Server.Identity.Clan or ""]) then Say("Roll your clan first.") return end
	SetText(FinishBtn, "...")
	local Ok, Msg = Remote:InvokeServer("Create", Choice)
	SetText(FinishBtn, "FINISH")
	if not Ok then Say(Msg or "Couldn't create the character.") return end
	Adopt(Remote:InvokeServer("State"))
	ShowTitle()
	Play()
	if Painted and RunService:IsStudio() then AlcoveSlot = nil ShowSlots() end -- (Studio doesn't teleport: back to the cards)
end)

-- ===== Layout: the phone and desktop places of the pieces (Rescale decides which; the desktop values are the originals) =====
Relayout = function()
	local P = Phone
	local Logo = MainMenu:FindFirstChild("Logo")
	MainMenu.Size, MainMenu.Position = P and UDim2.new(0, 330, 1, 0) or UDim2.new(0, 460, 1, 0), P and UDim2.new(0, 34, 0, 0) or UDim2.new(0, 70, 0, 0)
	if Logo then
		-- (below Roblox's top bar either way)
		Logo.Size, Logo.Position = P and UDim2.new(0, 300, 0, 128) or UDim2.new(0, 420, 0, 180), P and UDim2.new(0, -6, 0, 52) or UDim2.new(0, -10, 0.15, 12)
	end
	MenuButtons.Size, MenuButtons.Position = P and UDim2.new(0, 270, 0, 200) or UDim2.new(0, 300, 0, 200), P and UDim2.new(0, 8, 0, 192) or UDim2.new(0, 10, 0.4, 40)
	-- the slot cards: one scrolling column on the right on a phone, two columns top right on a desktop
	Grid.Size, Grid.Position = P and UDim2.new(0, 340, 1, -86) or UDim2.fromOffset(2 * 330 + 12, 3 * 74), P and UDim2.new(1, -12, 0, 22) or UDim2.new(1, -26, 0, 28)
	GridLayout.CellSize = P and UDim2.fromOffset(330, 68) or UDim2.fromOffset(330, 64)
	Grid.ScrollBarThickness = P and 4 or 0
	-- the creator: the panel full height and narrower, the turn bar and tools clear of it, the summary card above them
	-- (on a phone the panel's title plate stays below Roblox's top bar, which sits over the top left there)
	Panel.Size, Panel.Position = P and UDim2.new(0, 360, 1, -70) or UDim2.fromOffset(470, 540), P and UDim2.new(0, 10, 0.5, 28) or UDim2.new(0, 26, 0.5, 8)
	TurnBar.Position = P and UDim2.new(1, -200, 1, -10) or UDim2.new(0.56, 0, 1, -40) -- (on a phone: from the right edge, clear of the panel)
	Card.Size, Card.Position = P and UDim2.fromOffset(270, 270) or UDim2.fromOffset(340, 340), P and UDim2.new(1, -12, 0.42, 0) or UDim2.new(1, -30, 0.5, 0)
	-- the windows: never taller than the screen (their contents scroll)
	local LW = Camera.ViewportSize.X / Scale.Scale -- (the screen's width in layout pixels)
	Index.Size = P and UDim2.fromOffset(math.min(800, LW - 24), 410) or UDim2.fromOffset(800, 526)
	Shop.Size = P and UDim2.fromOffset(400, 410) or UDim2.fromOffset(400, 438)
	LooksPanel.Size = P and UDim2.fromOffset(400, 410) or UDim2.fromOffset(420, 470)
	Toast.Size = P and UDim2.fromOffset(560, 44) or UDim2.fromOffset(600, 48)
	if Painted and SlotScreen.Visible and Grid.Visible then ShowSlots() end -- (the cards are built for the layout)
end
Relayout()

-- start
ShowTitle()
if Painted then ShowSlots() end -- (the painted menu shows the cards beside the title, as the reference does)
SyncAll()
Refresh()

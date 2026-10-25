-- Gun rework Task 1 (plan Documents/plans/2026-10-25-gun-rework.md; spec §9): the read-only survey.
-- Run in Edit, in each place (Ye 106992859583940, Foundry 109591196441030):
--   python -I Art/Tools/rbxc.py luau "placeId: <id>" Edit @Art/Studio/Guns/survey_guns.lua
-- It changes nothing: no instance is created, moved or edited, no attribute is set. It refuses while Play runs.
-- It returns one JSON string (the caller writes survey_ye.json / survey_foundry.json from it):
--   Places      game.PlaceId, the experience's creator, ServerStorage's PlayLock
--   Scripts     each gun script's Studio path (found or not, class, NormHash), CooldownUI's path, the "Aim" request
--               handler (or "none"), Requests.WeaponSkill (does it call WeaponManager.Resolve; does Fan need ShootingMode)
--   LockOn      where the lock-on camera sits, AutoRotate / attributes while locked, and touch (from the sources)
--   UI          StarterGui's Crosshair marker and its ScreenGui's IgnoreGuiInset; the HUD ScreenGui's IgnoreGuiInset
--   Animations  Assets.Animations.Weapons' children (a Guns folder?), anything named Guns_Reload, Assets' PackageLink
--   ReloadId    the owner's reload animation 97563934064498: KeyframeSequenceProvider (loads? length = the largest
--               Keyframe.Time, to 0.01) and MarketplaceService:GetProductInfo (creator, asset type) -> plays live?
--   R6          StarterCharacter's body parts around its HumanoidRootPart: min / max corner, to 0.1
--   CameraShake where client code reads Settings > Camera Shake (script and line)
--   Packages    Modules' PackageLink (does this place carry the Modules package)
--   TestSpot    the gun suites' 200 x 200 spot (the fixed rules below), or none
local MODE = "survey"

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

if MODE ~= "survey" then return "REFUSED: MODE must be \"survey\" (read-only)" end
if RunService:IsRunning() then return "REFUSED: Play is running (the survey runs in Edit)" end

local RELOAD_ID = 97563934064498 -- the owner's id (2026-10-25)
local RENSEI_GROUP = 206818864 -- owns the game

-- (the Foundry plan's Global Constraints) the normalised hash: CRLF -> LF, then two rolling hashes
local function NormHash(S)
	S = S:gsub("\r\n", "\n")
	local H1, H2 = 0, 0
	for I = 1, #S do
		local B = string.byte(S, I)
		H1 = (H1 * 31 + B) % 1000000007
		H2 = (H2 * 131 + B) % 998244353
	end
	return #S .. ":" .. H1 .. ":" .. H2
end

local function At(Path) -- "Service/A/B" -> the one instance, or nil, why
	local Bits = string.split(Path, "/")
	local Node = game:GetService(Bits[1])
	for I = 2, #Bits do
		local Kids = {}
		for _, C in Node:GetChildren() do
			if C.Name == Bits[I] then table.insert(Kids, C) end
		end
		if #Kids ~= 1 then return nil, #Kids .. " named " .. Bits[I] .. " under " .. Node:GetFullName() end
		Node = Kids[1]
	end
	return Node
end

local function Live(I) return not I:GetFullName():find("RenseiBackups", 1, true) end -- not a backup copy

local function V3(V, P) P = P or 0.01 local function R(X) return math.floor(X / P + 0.5) * P end return {R(V.X), R(V.Y), R(V.Z)} end
local function Short(X) return math.floor(X * 100 + 0.5) / 100 end

local Out = {Mode = MODE}

-- ===== Places =====
Out.Places = {
	PlaceId = game.PlaceId,
	CreatorType = tostring(game.CreatorType),
	CreatorId = game.CreatorId,
	PlayLock = SS:GetAttribute("PlayLock") == nil and "nil" or tostring(SS:GetAttribute("PlayLock")),
}

-- ===== Scripts =====
local SCRIPTS = {
	["Rensei.TuningConfig"] = "ReplicatedStorage/Modules/Data/Rensei/TuningConfig",
	["Managers.WeaponManager"] = "ReplicatedStorage/Modules/Managers/WeaponManager",
	["Managers.AttackRunner"] = "ReplicatedStorage/Modules/Managers/AttackRunner",
	["Managers.DamageManager"] = "ReplicatedStorage/Modules/Managers/DamageManager",
	["Managers.AnimationManager"] = "ReplicatedStorage/Modules/Managers/AnimationManager",
	["Managers.SkillMods"] = "ReplicatedStorage/Modules/Managers/SkillMods",
	["UI.HUDUI"] = "ReplicatedStorage/Modules/UI/HUDUI",
	["UI.SettingsUI"] = "ReplicatedStorage/Modules/UI/SettingsUI",
	["UI.MobileControls"] = "ReplicatedStorage/Modules/UI/MobileControls",
	["UI.LockOn"] = "ReplicatedStorage/Modules/UI/LockOn",
	["UI.CooldownUI"] = "ReplicatedStorage/Modules/UI/CooldownUI",
	["Requests.Shoot"] = "ServerStorage/RenseiServer/ServerHandler/Requests/Shoot",
	["Requests.WeaponSkill"] = "ServerStorage/RenseiServer/ServerHandler/Requests/WeaponSkill",
	["Requests.Aim"] = "ServerStorage/RenseiServer/ServerHandler/Requests/Aim",
	["SPScripts.ClientHandler"] = "StarterPlayer/StarterPlayerScripts/ClientHandler",
	["RenseiTests.Play_Stealth"] = "ServerStorage/RenseiTests/Play_Stealth",
	-- §9.1's other scripts (already sync pairs; listed so the survey shows their hashes too)
	["RenseiServer.EnemyService"] = "ServerStorage/RenseiServer/EnemyService",
	["RenseiServer.ServerHandler"] = "ServerStorage/RenseiServer/ServerHandler",
}
Out.Scripts = {}
for Label, Path in SCRIPTS do
	local S, Why = At(Path)
	Out.Scripts[Label] = S and S:IsA("LuaSourceContainer")
		and {Path = Path, Found = true, Class = S.ClassName, NormHash = NormHash(S.Source)}
		or {Path = Path, Found = false, Why = Why or ("a " .. S.ClassName)}
end

-- every live (non-backup) script with one of these names, wherever it sits
local function FindAll(Name, Under)
	local Hits = {}
	for _, Svc in Under do
		for _, D in Svc:GetDescendants() do
			if D.Name == Name and D:IsA("LuaSourceContainer") and Live(D) then table.insert(Hits, D:GetFullName()) end
		end
	end
	table.sort(Hits)
	return Hits
end
local ALL = {RS, SS, game:GetService("ServerScriptService"), game:GetService("StarterPlayer"), game:GetService("StarterGui"), game:GetService("ReplicatedFirst")}
Out.Found = {CooldownUI = FindAll("CooldownUI", ALL), WeaponSkill = FindAll("WeaponSkill", ALL)}
local AimHandlers = {}
for _, P in FindAll("Aim", ALL) do
	if P:find(".Requests.Aim", 1, true) then table.insert(AimHandlers, P) end
end
Out.Found.AimRequestHandler = #AimHandlers > 0 and AimHandlers or "none"

local WS = At(SCRIPTS["Requests.WeaponSkill"])
local function Code(S) -- the source without comment lines
	local Keep = {}
	for Line in (S.Source .. "\n"):gmatch("(.-)\n") do
		if not Line:match("^%s*%-%-") then table.insert(Keep, Line) end
	end
	return table.concat(Keep, "\n")
end
if WS then
	local C = Code(WS)
	Out.WeaponSkill = {
		CallsResolve = C:find("WeaponManager.Resolve(", 1, true) ~= nil,
		-- Fan the Hammer is Weapons.Guns.Skill; the handler gates every weapon skill the same way
		ReadsShootingMode = C:find("ShootingMode", 1, true) ~= nil,
		ReadsCombatMode = C:find("CombatMode", 1, true) ~= nil,
		RangedNeedsCanFire = C:find("Weapon.Ranged and not WeaponManager.CanFire", 1, true) ~= nil,
	}
	Out.WeaponSkill.FanNeedsShootingMode = Out.WeaponSkill.ReadsShootingMode
end

-- ===== The lock-on camera (from LockOn's and SettingsUI's sources) =====
local LO, SUI = At(SCRIPTS["UI.LockOn"]), At(SCRIPTS["UI.SettingsUI"])
if LO then
	local C = Code(LO)
	local Cam = {}
	for _, K in {"Distance", "Height", "Shoulder", "LookHeight", "Smoothing"} do
		Cam[K] = tonumber(LO.Source:match("\n%s*" .. K .. "%s*=%s*([%d%.]+)"))
	end
	Out.LockOn = {
		Path = LO:GetFullName(),
		CameraType = C:find("Enum.CameraType.Scriptable", 1, true) and "Scriptable while locked (Custom on release)" or "?",
		Rig = Cam, -- studs: behind the player, above the root, to the right; aim point over the target's root
		BindToRenderStep = C:match('BindToRenderStep%("([^"]+)"'),
		SetsAutoRotateFalse = C:find("Humanoid.AutoRotate = false", 1, true) ~= nil,
		SetsAttribute = C:find("SetAttribute(", 1, true) ~= nil,
		TurnsRootToTarget = C:find("Root.CFrame = CFrame.lookAt(Root.Position, Flat)", 1, true) ~= nil,
		Exposes = {Target = C:find("LockOn.Target", 1, true) ~= nil, Release = C:find("LockOn.Release", 1, true) ~= nil},
		OwnInput = C:find("UserInputService", 1, true) ~= nil or C:find("ContextActionService", 1, true) ~= nil,
	}
	if SUI then
		local S = Code(SUI)
		local Bind = S:match('BindAction%("RenseiLockTarget",.-end,%s*(%w+),%s*Keybinds%.Get%("LockTarget"%)%)')
		Out.LockOn.ToggledBy = "SettingsUI ContextActionService RenseiLockTarget"
		Out.LockOn.CreateTouchButton = Bind -- "true": CAS makes an on-screen touch button
		Out.LockOn.TouchTitle = S:match('SetTitle%("RenseiLockTarget",%s*"([^"]*)"%)')
		Out.LockOn.WorksOnTouch = Bind == "true"
	end
	local MC = At(SCRIPTS["UI.MobileControls"])
	Out.LockOn.MobileControlsMentionsLock = MC and (Code(MC):find("Lock", 1, true) ~= nil) or false
end

-- ===== UI =====
local SG = game:GetService("StarterGui")
local Cross = {}
for _, D in SG:GetDescendants() do
	if D.Name == "Crosshair" and D:IsA("GuiObject") then table.insert(Cross, D) end
end
Out.UI = {CrosshairCount = #Cross}
local X = Cross[1]
if X then
	local Screen = X:FindFirstAncestorWhichIsA("ScreenGui")
	local function U2(U) return string.format("{%g, %g}, {%g, %g}", U.X.Scale, U.X.Offset, U.Y.Scale, U.Y.Offset) end
	local function C3(C) return {math.floor(C.R * 255 + 0.5), math.floor(C.G * 255 + 0.5), math.floor(C.B * 255 + 0.5)} end
	Out.UI.Crosshair = {
		Path = X:GetFullName(), Class = X.ClassName, Visible = X.Visible,
		AnchorPoint = {X.AnchorPoint.X, X.AnchorPoint.Y}, Position = U2(X.Position), Size = U2(X.Size),
		BackgroundColor3 = C3(X.BackgroundColor3), BackgroundTransparency = Short(X.BackgroundTransparency),
		ScreenGui = Screen and Screen:GetFullName(), IgnoreGuiInset = Screen and Screen.IgnoreGuiInset,
		ScreenInsets = Screen and tostring(Screen.ScreenInsets),
	}
	if X:IsA("ImageLabel") then
		Out.UI.Crosshair.Image = X.Image
		Out.UI.Crosshair.ImageColor3 = C3(X.ImageColor3)
		Out.UI.Crosshair.ImageTransparency = Short(X.ImageTransparency)
	end
end
-- HUDUI reads UIState.Gui.HUD, UIState.Gui = PlayerGui.Uis (StarterGui.Uis)
local Uis = SG:FindFirstChild("Uis")
local HUD = Uis and Uis:FindFirstChild("HUD")
Out.UI.HUD = {Path = HUD and HUD:GetFullName() or "none", ScreenGui = Uis and Uis:GetFullName() or "none"}
if Uis and Uis:IsA("ScreenGui") then Out.UI.HUD.IgnoreGuiInset = Uis.IgnoreGuiInset end

-- ===== Animations =====
local Assets = RS:FindFirstChild("Assets")
local Weapons = Assets and Assets:FindFirstChild("Animations") and Assets.Animations:FindFirstChild("Weapons")
Out.Animations = {WeaponsChildren = {}, Guns = {}, GunsReloadAnywhere = {}}
if Weapons then
	for _, C in Weapons:GetChildren() do table.insert(Out.Animations.WeaponsChildren, C.Name .. " [" .. C.ClassName .. "]") end
	table.sort(Out.Animations.WeaponsChildren)
	local Guns = Weapons:FindFirstChild("Guns")
	Out.Animations.HasGunsFolder = Guns ~= nil
	if Guns then
		for _, C in Guns:GetChildren() do
			table.insert(Out.Animations.Guns, C.Name .. " [" .. C.ClassName .. "]" .. (C:IsA("Animation") and (" " .. C.AnimationId) or ""))
		end
		table.sort(Out.Animations.Guns)
	end
end
for _, Svc in {RS, SS, workspace, game:GetService("StarterPlayer"), game:GetService("ServerScriptService")} do
	for _, D in Svc:GetDescendants() do
		if D.Name == "Guns_Reload" then
			table.insert(Out.Animations.GunsReloadAnywhere, D:GetFullName() .. " [" .. D.ClassName .. "]"
				.. (D:IsA("Animation") and (" " .. D.AnimationId) or ""))
		end
	end
end
table.sort(Out.Animations.GunsReloadAnywhere)
local function Pkg(I)
	local L = I and I:FindFirstChildOfClass("PackageLink")
	return L and {PackageId = L.PackageId, VersionNumber = L.VersionNumber} or "not a package"
end
Out.Animations.AssetsPackage = Pkg(Assets)

-- ===== The owner's reload id (read-only) =====
local Reload = {Id = RELOAD_ID}
local Ok, KS = pcall(function()
	return game:GetService("KeyframeSequenceProvider"):GetKeyframeSequenceAsync("rbxassetid://" .. RELOAD_ID)
end)
Reload.Loads = Ok and KS ~= nil
if Ok and KS then
	local Max, N = 0, 0
	for _, K in KS:GetKeyframes() do N += 1 Max = math.max(Max, K.Time) end
	Reload.Length = Short(Max)
	Reload.Keyframes = N
	Reload.Loop = KS.Loop
	Reload.Priority = tostring(KS.Priority)

else
	Reload.LoadError = tostring(KS)
end
local OkI, Info = pcall(function()
	return game:GetService("MarketplaceService"):GetProductInfo(RELOAD_ID, Enum.InfoType.Asset)
end)
if OkI and Info then
	Reload.Name = Info.Name
	Reload.AssetTypeId = Info.AssetTypeId
	Reload.CreatorType = Info.Creator and Info.Creator.CreatorType
	Reload.CreatorTargetId = Info.Creator and Info.Creator.CreatorTargetId
	local Mine = (Reload.CreatorType == "Group" and Reload.CreatorTargetId == RENSEI_GROUP)
		or (Reload.CreatorTargetId == game.CreatorId
			and ((game.CreatorType == Enum.CreatorType.Group and Reload.CreatorType == "Group")
				or (game.CreatorType == Enum.CreatorType.User and Reload.CreatorType == "User")))
	Reload.PlaysLive = Mine and "yes" or "may not play live"
else
	Reload.InfoError = tostring(Info)
	Reload.PlaysLive = "may not play live"
end
Out.ReloadId = Reload

-- ===== R6 extents around the root =====
local SC = game:GetService("StarterPlayer"):FindFirstChild("StarterCharacter")
local HRP = SC and SC:FindFirstChild("HumanoidRootPart")
if HRP then
	local Lo, Hi = Vector3.one * math.huge, -Vector3.one * math.huge
	local Parts = {}
	for _, P in SC:GetChildren() do
		if P:IsA("BasePart") then
			table.insert(Parts, P.Name)
			local Rel = HRP.CFrame:ToObjectSpace(P.CFrame)
			for _, SX in {-1, 1} do for _, SY in {-1, 1} do for _, SZ in {-1, 1} do
				local C = Rel * (P.Size / 2 * Vector3.new(SX, SY, SZ))
				Lo, Hi = Lo:Min(C), Hi:Max(C)
			end end end
		end
	end
	table.sort(Parts)
	local Hum = SC:FindFirstChildOfClass("Humanoid")
	Out.R6 = {Min = V3(Lo, 0.1), Max = V3(Hi, 0.1), Parts = Parts, RigType = Hum and tostring(Hum.RigType),
		HipHeight = Hum and Short(Hum.HipHeight)}
else
	Out.R6 = "no StarterPlayer.StarterCharacter.HumanoidRootPart"
end

-- ===== Settings > Camera Shake on the client =====
Out.CameraShake = {}
for _, Svc in {RS, game:GetService("StarterPlayer"), SG, game:GetService("ReplicatedFirst")} do
	for _, D in Svc:GetDescendants() do
		if D:IsA("LuaSourceContainer") and Live(D) then
			local N = 0
			for Line in (D.Source .. "\n"):gmatch("(.-)\n") do
				N += 1
				if Line:find('GetAttribute("CameraShake")', 1, true) then
					table.insert(Out.CameraShake, D:GetFullName() .. ":" .. N .. ": " .. Line:gsub("^%s+", ""))
				end
			end
		end
	end
end
table.sort(Out.CameraShake)

-- ===== Packages =====
Out.Packages = {Modules = Pkg(RS:FindFirstChild("Modules")), RenseiServer = Pkg(SS:FindFirstChild("RenseiServer")),
	ClientHandler = Pkg(game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("ClientHandler")),
	Assets = Pkg(Assets)}

-- ===== The gun suites' test spot =====
-- Rules (the brief; nothing about the suites is read): candidate centres on a 50-stud grid (multiples of 50 in X and
-- Z) inside World.Map's bounding box (its BaseParts), tried nearest the world origin first (ties: X, then Z); the first that passes:
--   * the 200 x 200 square (centre +-100 in X and Z) overlaps no RenseiArea box's footprint (XZ, separating axes);
--   * every RenseiPost and RenseiEnemySpawn is at least 120 studs (XZ) from the square;
--   * a ray down at every 10-stud grid point of the square (21 x 21) hits, not water, within 0.5 of the centre's height;
--   * a ray up 12 studs from each of those hits hits nothing (PathKit.Params: World.Live and characters left out,
--     colliding parts only).
local SIDE, STEP, GRID, CLEAR, POST_GAP, FLAT = 200, 50, 10, 12, 120, 0.5
local PathKit = require(SS.RenseiTests.PathKit)
local Ray = PathKit.Params()
local Wet = PathKit.Params()
Wet.IgnoreWater = false
local Map = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map")
local Spot = {Rules = string.format("side %d, grid %d, centres every %d, flat %.1f, clear %d up, %d from posts/spawns, outside RenseiArea",
	SIDE, GRID, STEP, FLAT, CLEAR, POST_GAP)}
if Map then
	-- World.Map is a Folder: its box is the union of its BaseParts' (axis-aligned, rotation ignored: a search range only)
	local MLo, MHi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, P in Map:GetDescendants() do
		if P:IsA("BasePart") then MLo, MHi = MLo:Min(P.Position - P.Size / 2), MHi:Max(P.Position + P.Size / 2) end
	end
	local BB, BS = CFrame.new((MLo + MHi) / 2), MHi - MLo
	local Top, Bottom = BB.Y + BS.Y / 2 + 20, BB.Y - BS.Y / 2 - 20
	local Areas, Points = {}, {}
	for _, A in CollectionService:GetTagged("RenseiArea") do
		if A:IsA("BasePart") and A:IsDescendantOf(workspace) then
			local Corners = {}
			for _, SX in {-1, 1} do for _, SY in {-1, 1} do for _, SZ in {-1, 1} do
				local C = A.CFrame * (A.Size / 2 * Vector3.new(SX, SY, SZ))
				table.insert(Corners, Vector2.new(C.X, C.Z))
			end end end
			local Axes = {Vector2.new(1, 0), Vector2.new(0, 1)}
			for _, V in {A.CFrame.RightVector, A.CFrame.UpVector, A.CFrame.LookVector} do
				local F = Vector2.new(V.X, V.Z)
				if F.Magnitude > 1e-3 then table.insert(Axes, Vector2.new(-F.Y, F.X).Unit) table.insert(Axes, F.Unit) end
			end
			table.insert(Areas, {Corners = Corners, Axes = Axes})
		end
	end
	for _, T in {"RenseiPost", "RenseiEnemySpawn"} do
		for _, P in CollectionService:GetTagged(T) do
			local Pos = P:IsA("BasePart") and P.Position or (P:IsA("Model") and P:GetPivot().Position) or (P:IsA("Attachment") and P.WorldPosition)
			if Pos and P:IsDescendantOf(workspace) then table.insert(Points, Vector2.new(Pos.X, Pos.Z)) end
		end
	end
	local function Overlaps(C, Area)
		local Sq = {C + Vector2.new(-100, -100), C + Vector2.new(100, -100), C + Vector2.new(100, 100), C + Vector2.new(-100, 100)}
		for _, Ax in Area.Axes do
			local A0, A1, B0, B1 = math.huge, -math.huge, math.huge, -math.huge
			for _, P in Area.Corners do local D = P:Dot(Ax) A0, A1 = math.min(A0, D), math.max(A1, D) end
			for _, P in Sq do local D = P:Dot(Ax) B0, B1 = math.min(B0, D), math.max(B1, D) end
			if A1 < B0 or B1 < A0 then return false end
		end
		return true
	end
	local function GapToSquare(C, P)
		local DX = math.max(math.abs(P.X - C.X) - SIDE / 2, 0)
		local DZ = math.max(math.abs(P.Y - C.Y) - SIDE / 2, 0)
		return math.sqrt(DX * DX + DZ * DZ)
	end
	local Cands = {}
	for X = math.ceil((BB.X - BS.X / 2) / STEP) * STEP, BB.X + BS.X / 2, STEP do
		for Z = math.ceil((BB.Z - BS.Z / 2) / STEP) * STEP, BB.Z + BS.Z / 2, STEP do
			table.insert(Cands, Vector2.new(X, Z))
		end
	end
	table.sort(Cands, function(A, B)
		if A.Magnitude ~= B.Magnitude then return A.Magnitude < B.Magnitude end
		if A.X ~= B.X then return A.X < B.X end
		return A.Y < B.Y
	end)
	local Why = {Area = 0, Post = 0, NoGround = 0, Water = 0, NotFlat = 0, Blocked = 0}
	-- Near misses (diagnostics only; they never pass): candidates outside the areas and far enough from posts and
	-- spawns whose 441 rays all hit dry ground, kept by their largest height step from the centre (then blocked count).
	local Near = {}
	local function Try(C)
		for _, A in Areas do if Overlaps(C, A) then Why.Area += 1 return end end
		for _, P in Points do if GapToSquare(C, P) < POST_GAP then Why.Post += 1 return end end
		local Mid = workspace:Raycast(Vector3.new(C.X, Top, C.Y), Vector3.new(0, Bottom - Top, 0), Ray)
		if not Mid then Why.NoGround += 1 return end
		local Y0, Lo, Hi = Mid.Position.Y, math.huge, -math.huge
		local Hits = {}
		for I = -SIDE / 2, SIDE / 2, GRID do
			for J = -SIDE / 2, SIDE / 2, GRID do
				local From = Vector3.new(C.X + I, Top, C.Y + J)
				local H = workspace:Raycast(From, Vector3.new(0, Bottom - Top, 0), Ray)
				if not H then Why.NoGround += 1 return end
				local W = workspace:Raycast(From, Vector3.new(0, Bottom - Top, 0), Wet)
				if W and W.Material == Enum.Material.Water then Why.Water += 1 return end
				Lo, Hi = math.min(Lo, H.Position.Y), math.max(Hi, H.Position.Y)
				table.insert(Hits, H)
			end
		end
		local Step = math.max(Hi - Y0, Y0 - Lo)
		local Blocked = 0
		for _, H in Hits do
			if workspace:Raycast(H.Position + Vector3.new(0, 0.05, 0), Vector3.new(0, CLEAR, 0), Ray) then Blocked += 1 end
		end
		local Grounds = {}
		for _, H in Hits do Grounds[H.Instance:GetFullName() .. (H.Instance:IsA("Terrain") and (" " .. H.Material.Name) or "")] = true end
		local G = {}
		for K in Grounds do table.insert(G, K) end
		table.sort(G)
		local NG = #G
		while #G > 4 do table.remove(G) end -- the first 4 ground names, sorted, and the count
		local R = {Grounds = NG, Centre = {C.X, Short(Y0), C.Y}, MinY = Short(Lo), MaxY = Short(Hi), Step = Short(Step), Blocked = Blocked, Ground = G}
		if Step > FLAT then Why.NotFlat += 1 elseif Blocked > 0 then Why.Blocked += 1 else return R end
		table.insert(Near, R)
		table.sort(Near, function(A, B) if A.Step ~= B.Step then return A.Step < B.Step end return A.Blocked < B.Blocked end)
		if #Near > 5 then table.remove(Near) end
	end
	local Tried = 0
	for _, C in Cands do
		Tried += 1
		local R = Try(C)
		if R then Spot.Found = R break end
	end
	Spot.NearMisses = Near
	Spot.Tried = Tried
	Spot.Candidates = #Cands
	Spot.Rejected = Why
	Spot.MapBox = {Centre = V3(BB.Position, 1), Size = V3(BS, 1)}
	Spot.Areas, Spot.PostsAndSpawns = #Areas, #Points
	if not Spot.Found then Spot.Found = "none" end
else
	Spot.Found = "none (no workspace.World.Map)"
end
Out.TestSpot = Spot

return HttpService:JSONEncode(Out)

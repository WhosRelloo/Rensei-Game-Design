-- Assassinations Task 1 (plan Documents/plans/2026-10-25-assassinations.md; spec §17): the read-only survey.
-- Run in Edit, in each place (Ye 106992859583940, Foundry 109591196441030):
--   python -I Art/Tools/rbxc.py luau "placeId: <id>" Edit @Art/Studio/Takedown/survey_takedown.lua
-- It never writes: no instance is created, moved, parented or edited, and no attribute is set. A KeyframeSequence it
-- loads is only read and never parented. It refuses while Play runs. It returns one JSON string (the caller writes
-- survey_ye.json / survey_foundry.json from it):
--   Place      game.PlaceId and ServerStorage's PlayLock
--   Scripts    each label the plan pairs: does the Studio path exist, and its class
--   Anims      where the takedown / fallback animations sit under Assets.Animations (full name, AnimationId, Save child)
--              and whether the three new slot names are still absent (a present one blocks Task 3); the Downed slots;
--              and where each owner id is used today
--   Sequences  the owner's and the sheet's ids, read with KeyframeSequenceProvider (pcall): length, markers, pose names,
--              HumanoidRootPart / Torso pose translation at the first and last keyframe, the Torso's largest offset
--              and largest turn (Pose CFrames are joint-local: for R6 the Torso pose is the RootJoint transform),
--              and the asset's creator (an animation plays live only when the game's owner made it)
--   KeyN       every script whose Source binds N (KeyCode.N, or "N" on a KeyCode / Keys line), skipping
--              ServerStorage.RenseiBackups and any Pre-* folder (preflight ruling R12); the skipped hits are listed apart
--   Spot       one test spot by the fixed search below (it never looks at enemies, light or perception)
--   Assets     ReplicatedStorage.Assets' PackageLink

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

if RunService:IsRunning() then return "REFUSED: Play is running (the survey runs in Edit)" end

local RENSEI_GROUP = 206818864 -- owns the game
local SEQUENCES = {
	{Id = 83505608395055, What = "Misc_Assassinate (sheet: Assassination)"},
	{Id = 72960497872371, What = "owner: Knock out (Takedown_Choke)"},
	{Id = 131914091661838, What = "owner: Hold (Takedown_ChokeVictim)"},
	{Id = 132728216355683, What = "owner: Victim (Misc_AssassinateVictim)"},
	{Id = 140607038476506, What = "Fist_BearHug (fallback)"},
	{Id = 76737043223431, What = "Fist_BearHugVictim (fallback)"},
}
local PRESENT = {"Misc_Assassinate", "Fist_BearHug", "Fist_BearHugVictim", "Gripping", "Gripped", "Knocked",
	"Gauntlets_Grip", "Gauntlets_Gripped"}
local ABSENT = {"Misc_AssassinateVictim", "Takedown_Choke", "Takedown_ChokeVictim"}
local SCRIPTS = { -- label -> Studio path (sync_manifest.json)
	{"Rensei.Perception", "ReplicatedStorage/Modules/Data/Rensei/Perception"},
	{"Rensei.Settings", "ReplicatedStorage/Modules/Data/Rensei/Settings"},
	{"Rensei.Deeds", "ReplicatedStorage/Modules/Data/Rensei/Deeds"},
	{"Managers.DownedManager", "ReplicatedStorage/Modules/Managers/DownedManager"},
	{"UI.CombatModeUI", "ReplicatedStorage/Modules/UI/CombatModeUI"},
	{"UI.PromptUI", "ReplicatedStorage/Modules/UI/PromptUI"},
	{"SPScripts.UIHandler", "StarterPlayer/StarterPlayerScripts/UIHandler"},
	{"RenseiServer.PerceptionService", "ServerStorage/RenseiServer/PerceptionService"},
	{"RenseiServer.EnemyService", "ServerStorage/RenseiServer/EnemyService"},
	{"RenseiServer.ServerHandler", "ServerStorage/RenseiServer/ServerHandler"},
	{"RenseiTests.Test_Perception", "ServerStorage/RenseiTests/Test_Perception"},
	{"RenseiTests.Test_Sound", "ServerStorage/RenseiTests/Test_Sound"},
	{"RenseiTests.Play_Stealth", "ServerStorage/RenseiTests/Play_Stealth"},
	{"RenseiTests.Play_Perception", "ServerStorage/RenseiTests/Play_Perception"},
	{"RenseiTests.Play_Morality", "ServerStorage/RenseiTests/Play_Morality"},
	{"RenseiTests.Play_Heat", "ServerStorage/RenseiTests/Play_Heat"},
	{"RenseiTests.Play_Rumours", "ServerStorage/RenseiTests/Play_Rumours"},
	{"RenseiTests.Play_TownsfolkHurt", "ServerStorage/RenseiTests/Play_TownsfolkHurt"},
	-- the new files later tasks create: each must be absent today
	{"Rensei.Takedown (new, Task 2)", "ReplicatedStorage/Modules/Data/Rensei/Takedown"},
	{"UI.TakedownUI (new, Task 10)", "ReplicatedStorage/Modules/UI/TakedownUI"},
	{"RenseiServer.TakedownService (new, Task 7)", "ServerStorage/RenseiServer/TakedownService"},
	{"RenseiTests.TakedownKit (new, Task 4)", "ServerStorage/RenseiTests/TakedownKit"},
}

local function R(X, P) P = P or 0.01 return math.floor(X / P + 0.5) * P end
local function V3(V, P) return {R(V.X, P), R(V.Y, P), R(V.Z, P)} end

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

local Out = {}
Out.Place = {PlaceId = game.PlaceId, PlayLock = tostring(SS:GetAttribute("PlayLock"))}

-- ===== Scripts =====
Out.Scripts = {}
for _, P in SCRIPTS do
	local I, Why = At(P[2])
	Out.Scripts[P[1]] = I and {Path = P[2], Exists = true, Class = I.ClassName} or {Path = P[2], Exists = false, Why = Why}
end

-- ===== Anims =====
local Assets = RS:FindFirstChild("Assets")
local Root = Assets and Assets:FindFirstChild("Animations")
local ByName, ById = {}, {}
local OwnerIds = {}
for _, S in SEQUENCES do OwnerIds["rbxassetid://" .. S.Id] = S.Id end
if Root then
	for _, A in Root:GetDescendants() do
		if A:IsA("Animation") then
			ByName[A.Name] = ByName[A.Name] or {}
			local Save = A:FindFirstChild("Save")
			table.insert(ByName[A.Name], {
				FullName = A:GetFullName(),
				AnimationId = A.AnimationId,
				Save = Save and Save.ClassName or nil,
				Unpublished = A:GetAttribute("Unpublished"),
				Fallback = A:GetAttribute("Fallback"),
			})
		end
	end
end
-- every Animation anywhere in the game with one of the six ids (where each is used today)
for _, A in game:GetDescendants() do
	local Ok, IsAnim = pcall(function() return A:IsA("Animation") end)
	if Ok and IsAnim then
		local Id = OwnerIds[A.AnimationId] or OwnerIds[(A.AnimationId:gsub("^http.-id=", "rbxassetid://"))]
		if Id then
			ById[tostring(Id)] = ById[tostring(Id)] or {}
			table.insert(ById[tostring(Id)], A:GetFullName())
		end
	end
end
for _, L in ById do table.sort(L) end
Out.Anims = {Root = Root and Root:GetFullName() or "none", Present = {}, MustBeAbsent = {}, Downed = {}, IdsUsedAt = {}}
for _, N in PRESENT do Out.Anims.Present[N] = ByName[N] or "absent" end
for _, N in ABSENT do
	if ByName[N] then
		local L = {}
		for _, E in ByName[N] do table.insert(L, E.FullName) end
		Out.Anims.MustBeAbsent[N] = L -- a blocker for Task 3
	else
		Out.Anims.MustBeAbsent[N] = "absent"
	end
end
local DownedFolder = Root and Root:FindFirstChild("Shared") and Root.Shared:FindFirstChild("Combat")
	and Root.Shared.Combat:FindFirstChild("Downed")
if DownedFolder then
	for _, A in DownedFolder:GetChildren() do
		Out.Anims.Downed[A.Name] = A:IsA("Animation") and A.AnimationId or A.ClassName
	end
else
	Out.Anims.Downed = "no Shared.Combat.Downed"
end
local Takedown = Root and Root:FindFirstChild("Shared") and Root.Shared:FindFirstChild("Takedown")
Out.Anims.SharedTakedown = Takedown and Takedown:GetFullName() or "absent"
for _, S in SEQUENCES do Out.Anims.IdsUsedAt[tostring(S.Id)] = ById[tostring(S.Id)] or "not in the game" end

-- ===== Sequences (read only; never parented) =====
local KSP = game:GetService("KeyframeSequenceProvider")
local MPS = game:GetService("MarketplaceService")
local function PoseOf(K, Name)
	for _, P in K:GetDescendants() do
		if P:IsA("Pose") and P.Name == Name then return P end
	end
end
local function PoseInfo(P)
	if not P then return "no pose" end
	local X, Y, Z = P.CFrame:ToOrientation()
	return {Pos = V3(P.CFrame.Position), RotDeg = {R(math.deg(X), 0.1), R(math.deg(Y), 0.1), R(math.deg(Z), 0.1)}}
end
Out.Sequences = {}
for _, S in SEQUENCES do
	local E = {What = S.What}
	local Ok, KS = pcall(function() return KSP:GetKeyframeSequenceAsync("rbxassetid://" .. S.Id) end)
	E.Loads = Ok and KS ~= nil
	if Ok and KS then
		local Keys = KS:GetKeyframes()
		table.sort(Keys, function(A, B) return A.Time < B.Time end)
		E.Keyframes = #Keys
		E.Length = Keys[#Keys] and R(Keys[#Keys].Time, 0.001) or 0
		E.Loop = KS.Loop
		E.Priority = tostring(KS.Priority)
		E.Markers, E.NamedKeyframes = {}, {}
		local Poses = {}
		local MaxTorso, MaxTorsoAt = 0, 0
		local MaxTilt, MaxTiltAt = 0, 0
		for _, K in Keys do
			for _, M in K:GetMarkers() do
				table.insert(E.Markers, {Name = M.Name, Value = M.Value, Time = R(K.Time, 0.001)})
			end
			if K.Name ~= "Keyframe" then table.insert(E.NamedKeyframes, {Name = K.Name, Time = R(K.Time, 0.001)}) end
			for _, P in K:GetDescendants() do
				if P:IsA("Pose") then Poses[P.Name] = true end
			end
			local T = PoseOf(K, "Torso") or PoseOf(K, "LowerTorso")
			if T and T.CFrame.Position.Magnitude > MaxTorso then
				MaxTorso, MaxTorsoAt = T.CFrame.Position.Magnitude, K.Time
			end
			if T then
				local _, Angle = T.CFrame:ToAxisAngle()
				if math.abs(Angle) > MaxTilt then MaxTilt, MaxTiltAt = math.abs(Angle), K.Time end
			end
		end
		local Names = {}
		for N in Poses do table.insert(Names, N) end
		table.sort(Names)
		E.Poses = Names
		local First, Last = Keys[1], Keys[#Keys]
		if First then
			E.First = {Time = R(First.Time, 0.001), HumanoidRootPart = PoseInfo(PoseOf(First, "HumanoidRootPart")),
				Torso = PoseInfo(PoseOf(First, "Torso") or PoseOf(First, "LowerTorso"))}
			E.Last = {Time = R(Last.Time, 0.001), HumanoidRootPart = PoseInfo(PoseOf(Last, "HumanoidRootPart")),
				Torso = PoseInfo(PoseOf(Last, "Torso") or PoseOf(Last, "LowerTorso"))}
		end
		E.TorsoMaxOffset = {Studs = R(MaxTorso), Time = R(MaxTorsoAt, 0.001)}
		E.TorsoMaxTurn = {Deg = R(math.deg(MaxTilt), 0.1), Time = R(MaxTiltAt, 0.001)}
	else
		E.LoadError = tostring(KS)
	end
	local OkI, Info = pcall(function() return MPS:GetProductInfo(S.Id, Enum.InfoType.Asset) end)
	if OkI and Info then
		E.Name = Info.Name
		E.AssetTypeId = Info.AssetTypeId
		E.CreatorType = Info.Creator and Info.Creator.CreatorType
		E.CreatorTargetId = Info.Creator and Info.Creator.CreatorTargetId
		local Mine = (E.CreatorType == "Group" and E.CreatorTargetId == RENSEI_GROUP)
			or (E.CreatorTargetId == game.CreatorId
				and ((game.CreatorType == Enum.CreatorType.Group and E.CreatorType == "Group")
					or (game.CreatorType == Enum.CreatorType.User and E.CreatorType == "User")))
		E.PlaysLive = Mine and "yes" or "may not play live"
	else
		E.InfoError = tostring(Info)
		E.PlaysLive = "unknown"
	end
	Out.Sequences[tostring(S.Id)] = E
end

-- ===== KeyN =====
local function Skipped(I) -- a backup copy that never runs (R12)
	local P = I.Parent
	while P and P ~= game do
		if P.Name == "RenseiBackups" or P.Name:sub(1, 4) == "Pre-" then return true end
		P = P.Parent
	end
	return false
end
local KeyN = {Hits = {}, SkippedHits = {}, Scanned = 0, SkippedScripts = 0, Unreadable = 0}
for _, I in game:GetDescendants() do
	local Ok, IsScript = pcall(function() return I:IsA("LuaSourceContainer") end)
	if Ok and IsScript then
		local OkS, Src = pcall(function() return I.Source end)
		if not OkS or type(Src) ~= "string" then
			KeyN.Unreadable += 1
		else
			local Skip = Skipped(I)
			if Skip then KeyN.SkippedScripts += 1 else KeyN.Scanned += 1 end
			local LineNo = 0
			for Line in (Src:gsub("\r\n", "\n") .. "\n"):gmatch("([^\n]*)\n") do
				LineNo += 1
				local Hit = (Line .. " "):find("KeyCode%.N[^%w]")
					or ((Line:find('"N"', 1, true) or Line:find("'N'", 1, true))
						and (Line:find("KeyCode", 1, true) or Line:find("Keys", 1, true)))
				if Hit then
					local E = {Path = I:GetFullName(), Line = LineNo, Text = Line:gsub("^%s+", ""):sub(1, 120)}
					table.insert(Skip and KeyN.SkippedHits or KeyN.Hits, E)
				end
			end
		end
	end
end
Out.KeyN = KeyN

-- ===== Spot (the fixed search) =====
-- From the first SpawnLocation in workspace (GetDescendants order), walk a 16-stud grid outwards in square rings to
-- 400 studs. A point is the spot when: a ray down (from the spawn's height + 40, 200 long, Normal.Y > 0.6, not water)
-- meets ground; 5 rays (the point and +-6 on X and Z) all meet ground within 1 stud of each other; and a 24 x 24 box
-- from 0.5 to 8 studs above the ground holds no part (GetPartBoundsInBox; characters excluded).
local GRID, REACH, UP, DOWN, LEVEL, HALF = 16, 400, 40, 200, 1, 6
local Spot = {Rules = string.format("first SpawnLocation; %d-stud grid in rings to %d; ray from +%d, %d long; level %d over a %d-stud cross; 24x24 box 0.5-8 up clear",
	GRID, REACH, UP, DOWN, LEVEL, HALF * 2)}
local Spawn
local Spawns = 0
for _, I in workspace:GetDescendants() do
	if I:IsA("SpawnLocation") then
		Spawns += 1
		Spawn = Spawn or I
	end
end
Spot.Spawns = Spawns
if Spawn then
	Spot.From = {Name = Spawn:GetFullName(), Position = V3(Spawn.Position, 0.1)}
	local Chars = {}
	for _, H in workspace:GetDescendants() do
		if H:IsA("Humanoid") and H.Parent then table.insert(Chars, H.Parent) end
	end
	local RP = RaycastParams.new()
	RP.FilterType = Enum.RaycastFilterType.Exclude
	RP.FilterDescendantsInstances = Chars
	RP.IgnoreWater = false
	local OP = OverlapParams.new()
	OP.FilterType = Enum.RaycastFilterType.Exclude
	OP.FilterDescendantsInstances = Chars
	local Y0 = Spawn.Position.Y
	local function Ground(X, Z)
		local H = workspace:Raycast(Vector3.new(X, Y0 + UP, Z), Vector3.new(0, -DOWN, 0), RP)
		if not H or H.Normal.Y <= 0.6 or H.Material == Enum.Material.Water then return nil, H end
		return H
	end
	local Why = {NoGround = 0, NotLevel = 0, Blocked = 0}
	local Tried = 0
	local Found
	for Ring = 0, math.floor(REACH / GRID) do
		for DX = -Ring, Ring do
			for DZ = -Ring, Ring do
				if not Found and math.max(math.abs(DX), math.abs(DZ)) == Ring then
					Tried += 1
					local X, Z = Spawn.Position.X + DX * GRID, Spawn.Position.Z + DZ * GRID
					local C = Ground(X, Z)
					if not C then
						Why.NoGround += 1
					else
						local Lo, Hi, Ok = C.Position.Y, C.Position.Y, true
						for _, O in {{HALF, 0}, {-HALF, 0}, {0, HALF}, {0, -HALF}} do
							local G = Ground(X + O[1], Z + O[2])
							if not G then Ok = false break end
							Lo, Hi = math.min(Lo, G.Position.Y), math.max(Hi, G.Position.Y)
						end
						if not Ok or Hi - Lo > LEVEL then
							Why.NotLevel += 1
						else
							local Top = C.Position.Y
							local Parts = workspace:GetPartBoundsInBox(CFrame.new(X, Top + 0.5 + 3.75, Z), Vector3.new(24, 7.5, 24), OP)
							if #Parts > 0 then
								Why.Blocked += 1
							else
								Found = {X = R(X, 0.1), Y = R(Top, 0.1), Z = R(Z, 0.1), Ring = Ring,
									Ground = C.Instance and C.Instance:GetFullName() or "?", Material = tostring(C.Material.Name)}
							end
						end
					end
				end
			end
		end
	end
	Spot.Tried, Spot.Rejected = Tried, Why
	Spot.Found = Found or "none"
else
	Spot.Found = "none (no SpawnLocation in workspace)"
end
Out.Spot = Spot

-- ===== Assets =====
local Link = Assets and Assets:FindFirstChildOfClass("PackageLink")
Out.Assets = Link and {Package = true, PackageId = Link.PackageId, VersionNumber = Link.VersionNumber} or {Package = false}

return HttpService:JSONEncode(Out)

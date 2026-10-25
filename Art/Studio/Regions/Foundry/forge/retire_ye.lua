--!nocheck
-- retire_ye.lua: Foundry Yard game-data plan Task 8 (hand-written; Ye only). Brannoc and the forge rooms leave Ye: their
-- copies live in Foundry since Task 7 (build_forge.lua). Reversible, and nothing is cloned: the four pieces are MOVED
-- into a backup, so undo returns the very same instances.
--   World.Map.SilentForge                                  (the workshop room: 4 metal_* inspects, its area, a mechanism)
--   World.Map.ForgeFloor                                   (the metal_experiment trial floor)
--   World.NPCs["Alchemy Trainers"]["Metal Alchemist"]      (Brannoc)
--   World.Map.AlchemistSpawns.WardAlchemist_SilentForge    (the Ward Alchemist's spawn)
-- World.Map.FoundryYard stays (owner decision A), untouched; check compares it with the baseline apply recorded.
-- In their place a notice (owner decision D): World.Map.BrannocNotice, a post and a board at Ye's Metal TrainerSpot
-- (-130, 5, -135), tagged RenseiInspect with InspectId "brannoc_moved" (Rensei.Investigation: it starts acq_metal at its
-- travel stage for a player with no path). Ye's compass: north +Z, east -X; the board faces -Z, toward the training
-- field (the trainers face -Z; the field lies to their south), 2.5 studs south of the spot (Ruling 15).
-- Runs in Ye (placeId 106992859583940), Edit only:
--   python -I Art/Tools/rbxc.py luau "placeId: 106992859583940" Edit @<a scratch copy with its MODE line set>
-- Flag: World.Map's FoundryMove = "applied". Marks: FoundryMoveAdd = true on what apply creates (the notice and its
-- parts, the backup folder if it made it, each FoundryMoveFrom ObjectValue); each moved piece carries a child
-- ObjectValue FoundryMoveFrom (its old parent) and the attribute FoundryMoveFromPath (its old full name, a fallback).
-- A backup this plan makes carries no live CollectionService tags: every tag on a piece and its descendants is removed
-- and written as JSON into that instance's RegionKitTags (the import/unstrip.lua convention); undo puts them back.
-- MODE = "plan"   read-only: the four pieces, their tags, the baseline apply would record.
-- MODE = "apply"  refuses, changing nothing, while Play runs, while ServerStorage's PlayLock is set, when World.Map has
--                 FoundryMove, when a piece is missing (or not exactly one), when BrannocNotice exists, or when the
--                 backup already holds anything of this script's. Records the baseline on the backup folder first
--                 (BaselineInspect, BaselineTrainers, BaselineYardParts, BaselineYardPivot, StrippedTags), then, in a
--                 pcall with a journal (an error half-way is rolled back) and one ChangeHistory recording: strips and
--                 moves each piece, builds the notice, sets the flag; then runs check.
-- MODE = "undo"   refuses while Play runs or PlayLock is set, or unless the flag is "applied". Destroys the notice
--                 (only one carrying FoundryMoveAdd: Ruling 38),
--                 moves each piece back to its FoundryMoveFrom parent (else its FoundryMoveFromPath parent) with its
--                 tags restored from RegionKitTags, clears the baseline, deletes the backup folder if this script made
--                 it, clears the flag. Journalled and rolled back on an error, like apply. Undo this BEFORE prep_ye.lua's
--                 undo: prep_ye refuses while FoundryMove is set.
-- MODE = "check"  read-only failure list (see checks()); PASS n / FAIL n. (Ruling 38 adds: NoticePost exists, the board
--                 faces -Z, and no RenseiInspect in workspace has a metal_* InspectId.)
-- MODE = "test"   (only while not applied) snapshot -> apply -> check -> undo -> snapshot; the two must be equal (by
--                 instance: full name, class, sorted attributes, sorted tags, a part's CFrame; plus every tag's count,
--                 workspace's BasePart count and the RenseiBackups children). check and snapshot run inside a pcall.
local MODE = "plan" -- "plan", "apply", "undo", "check" or "test"

local CS = game:GetService("CollectionService")
local CHS = game:GetService("ChangeHistoryService")
local HS = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local SS = game:GetService("ServerStorage")

local FLAG, ADD, FROM, FROMPATH = "FoundryMove", "FoundryMoveAdd", "FoundryMoveFrom", "FoundryMoveFromPath"
local KITTAGS = "RegionKitTags"
local BACKUP = "Pre-FoundryMove_2026-10-24"
local NOTICE_ID = "brannoc_moved"
local SPOT = Vector3.new(-130, 5, -135) -- Ye's Metal TrainerSpot (RenseiMarker, Element Metal; measured 2026-10-25)
local NOTICE_REACH = 6 -- the board within this many studs of the spot (as a trainer within 6 of its spot)
-- the notice (PROPOSAL dressing; the brief's values): the post stands on Ye's ground at 4, 2.5 studs south (-Z) of the spot
local POST_CF, POST_SIZE = CFrame.new(-130, 6.5, -137.5), Vector3.new(0.6, 5, 0.6)
local BOARD_CF = CFrame.lookAt(Vector3.new(-130, 8.2, -137.9), Vector3.new(-130, 8.2, -138.9))
local BOARD_SIZE = Vector3.new(2.4, 1.6, 0.2)
local POST_COLOR, BOARD_COLOR = Color3.fromRGB(105, 76, 50), Color3.fromRGB(160, 132, 92) -- PROPOSAL

local function refuse(why) return "retire_ye " .. MODE .. " REFUSED: " .. why end
if game.PlaceId ~= 106992859583940 then return refuse("this is not Ye") end
if RunService:IsRunning() then return refuse("Play is running; Edit only") end
local World = workspace:FindFirstChild("World")
local Map = World and World:FindFirstChild("Map")
if not Map then return refuse("no workspace.World.Map") end

-- ------------------------------------------------------------------ helpers
local function f3(V) return ("(%.2f, %.2f, %.2f)"):format(V.X, V.Y, V.Z) end
local function cfNums(CF)
	local C = {CF:GetComponents()}
	for I = 1, 12 do C[I] = ("%.4f"):format(C[I]) end
	return table.concat(C, ",")
end
local function cfParse(S)
	local N = {}
	for X in string.gmatch(S, "[^,]+") do table.insert(N, tonumber(X)) end
	if #N ~= 12 then error("not 12 numbers: " .. tostring(S)) end
	return CFrame.new(table.unpack(N))
end
local function partCount(Inst)
	local N = Inst:IsA("BasePart") and 1 or 0
	for _, D in ipairs(Inst:GetDescendants()) do if D:IsA("BasePart") then N += 1 end end
	return N
end
local function withDesc(Inst)
	local L = Inst:GetDescendants()
	table.insert(L, 1, Inst)
	return L
end
local function inspectCount()
	local N = 0
	for _, P in ipairs(CS:GetTagged("RenseiInspect")) do if P:IsDescendantOf(workspace) then N += 1 end end
	return N
end
local function trainersFolder()
	local NPCs = World:FindFirstChild("NPCs")
	return NPCs and NPCs:FindFirstChild("Alchemy Trainers")
end
local function backupFolder()
	local RB = SS:FindFirstChild("RenseiBackups")
	return RB and RB:FindFirstChild(BACKUP), RB
end
-- the unique instance at a full name ("Workspace.World.Map..."), or nil
local function resolve(Path)
	local Node = game
	for Name in string.gmatch(Path, "[^%.]+") do
		local Found = nil
		for _, C in ipairs(Node:GetChildren()) do
			if C.Name == Name then
				if Found then return nil end
				Found = C
			end
		end
		if not Found then
			if Node == game then Found = game:FindFirstChildOfClass(Name) or (Name == "Workspace" and workspace) end
			if not Found then return nil end
		end
		Node = Found
	end
	return Node
end

-- the four pieces where they live before apply: {Name, Get() -> instance or nil, why}
local PIECES = {
	{Name = "SilentForge", Get = function() return Map:FindFirstChild("SilentForge") end},
	{Name = "ForgeFloor", Get = function() return Map:FindFirstChild("ForgeFloor") end},
	{Name = "Metal Alchemist", Get = function() local F = trainersFolder() return F and F:FindFirstChild("Metal Alchemist") end},
	{Name = "WardAlchemist_SilentForge", Get = function()
		local A = Map:FindFirstChild("AlchemistSpawns")
		return A and A:FindFirstChild("WardAlchemist_SilentForge")
	end},
}
local function countNamed(Parent, Name)
	local N = 0
	if Parent then for _, C in ipairs(Parent:GetChildren()) do if C.Name == Name then N += 1 end end end
	return N
end

local function locked()
	if RunService:IsRunning() then return "Play is running" end
	local L = SS:GetAttribute("PlayLock")
	if L ~= nil then return "PlayLock is set (" .. tostring(L) .. ")" end
	return nil
end

-- ------------------------------------------------------------------ check (a failure list)
local function checks()
	local Fails, Passes, Out = 0, 0, {}
	local function cond(Failed, What)
		if Failed then Fails += 1 table.insert(Out, "  FAIL " .. What) else Passes += 1 end
	end
	local BK = backupFolder()
	cond(Map:GetAttribute(FLAG) ~= "applied", "World.Map's " .. FLAG .. " is " .. tostring(Map:GetAttribute(FLAG)) .. ", not applied")
	cond(BK == nil, "no ServerStorage.RenseiBackups." .. BACKUP)
	local B = {}
	for _, K in ipairs({"BaselineInspect", "BaselineTrainers", "BaselineYardParts", "BaselineYardPivot", "StrippedTags"}) do
		B[K] = BK and BK:GetAttribute(K)
		cond(B[K] == nil, "the backup folder has no " .. K)
	end
	-- the four pieces are in the backup, with no live tag; their tags are set aside
	local Kept = 0
	for _, P in ipairs(PIECES) do
		local X = BK and BK:FindFirstChild(P.Name)
		cond(not X or countNamed(BK, P.Name) ~= 1, P.Name .. " is not (exactly once) in the backup")
		if X then
			local Ov = X:FindFirstChild(FROM)
			cond(not (Ov and Ov:IsA("ObjectValue") and Ov.Value), P.Name .. " has no " .. FROM .. " ObjectValue with its old parent")
			cond(type(X:GetAttribute(FROMPATH)) ~= "string", P.Name .. " has no " .. FROMPATH)
			local Left = {}
			for _, D in ipairs(withDesc(X)) do
				for _, T in ipairs(CS:GetTags(D)) do table.insert(Left, D.Name .. ":" .. T) end
				local J = D:GetAttribute(KITTAGS)
				if J then Kept += #HS:JSONDecode(J) end
			end
			cond(#Left > 0, P.Name .. " still carries live tags: " .. table.concat(Left, ", "))
		end
	end
	cond(B.StrippedTags ~= nil and Kept ~= B.StrippedTags, ("the backup's %s hold %d tags, apply stripped %s"):format(KITTAGS, Kept, tostring(B.StrippedTags)))
	-- Brannoc and the trial are gone from Ye's world
	local Brannoc = {}
	for _, D in ipairs(workspace:GetDescendants()) do
		if D:IsA("Model") and D:GetAttribute("DialogueId") == "trainer_metal" then table.insert(Brannoc, D:GetFullName()) end
	end
	cond(#Brannoc > 0, "a model with DialogueId trainer_metal is in Ye's workspace: " .. table.concat(Brannoc, ", "))
	local Trial = {}
	for _, P in ipairs(CS:GetTagged("RenseiTrial")) do
		if P:GetAttribute("TrialId") == "metal_experiment" then table.insert(Trial, P:GetFullName()) end
	end
	cond(#Trial > 0, "a RenseiTrial with TrialId metal_experiment is in the DataModel: " .. table.concat(Trial, ", "))
	-- (Ruling 38) none of the forge's metal_* inspects is left in Ye's world
	local Metal = {}
	for _, P in ipairs(CS:GetTagged("RenseiInspect")) do
		local Id = P:GetAttribute("InspectId")
		if P:IsDescendantOf(workspace) and type(Id) == "string" and string.sub(Id, 1, 6) == "metal_" then
			table.insert(Metal, Id .. " at " .. P:GetFullName())
		end
	end
	cond(#Metal > 0, "a RenseiInspect with a metal_* InspectId is in Ye's workspace: " .. table.concat(Metal, ", "))
	-- the notice
	local Notice = Map:FindFirstChild("BrannocNotice")
	local Board = Notice and Notice:FindFirstChild("NoticeBoard")
	cond(not Board, "World.Map.BrannocNotice.NoticeBoard is missing")
	-- (Ruling 38) the post is there, and the board faces -Z (toward the training field, Ye's south)
	local Post = Notice and Notice:FindFirstChild("NoticePost")
	cond(not (Post and Post:IsA("BasePart")), "World.Map.BrannocNotice.NoticePost is missing")
	if Board then
		local L = Board.CFrame.LookVector
		cond(L:Dot(Vector3.new(0, 0, -1)) <= 0.99, ("the NoticeBoard faces (%.2f, %.2f, %.2f), not -Z"):format(L.X, L.Y, L.Z))
		cond(not CS:HasTag(Board, "RenseiInspect"), "the NoticeBoard is not tagged RenseiInspect")
		cond(Board:GetAttribute("InspectId") ~= NOTICE_ID, "the NoticeBoard's InspectId is " .. tostring(Board:GetAttribute("InspectId")) .. ", not " .. NOTICE_ID)
		local Spot
		for _, P in ipairs(CS:GetTagged("RenseiMarker")) do
			if P:IsDescendantOf(workspace) and P:GetAttribute("Piece") == "TrainerSpot" and P:GetAttribute("Element") == "Metal" then Spot = P end
		end
		cond(not Spot, "no Metal TrainerSpot in workspace")
		if Spot then
			local D = (Board.Position - Spot.Position).Magnitude
			cond(D > NOTICE_REACH, ("the NoticeBoard is %.2f studs from the Metal TrainerSpot (at most %d)"):format(D, NOTICE_REACH))
		end
	end
	-- the counts against the baseline
	local F = trainersFolder()
	local Have = F and #F:GetChildren() or -1
	cond(B.BaselineTrainers ~= nil and Have ~= B.BaselineTrainers - 1, ("Alchemy Trainers holds %d, not BaselineTrainers - 1 = %s"):format(Have, tostring(B.BaselineTrainers and B.BaselineTrainers - 1)))
	local Ins = inspectCount()
	cond(B.BaselineInspect ~= nil and Ins ~= B.BaselineInspect - 4 + 1, ("workspace has %d RenseiInspect, not BaselineInspect - 4 + 1 = %s"):format(Ins, tostring(B.BaselineInspect and B.BaselineInspect - 3)))
	-- (owner decision A) FoundryYard stays as it was
	local FY = Map:FindFirstChild("FoundryYard")
	cond(not FY, "World.Map.FoundryYard is missing")
	if FY and B.BaselineYardParts then
		cond(partCount(FY) ~= B.BaselineYardParts, ("FoundryYard has %d BaseParts, baseline %d"):format(partCount(FY), B.BaselineYardParts))
	end
	if FY and B.BaselineYardPivot then
		local Ok, Was = pcall(cfParse, B.BaselineYardPivot)
		cond(not Ok, "BaselineYardPivot doesn't parse: " .. tostring(Was))
		if Ok then
			local Now = {FY:GetPivot():GetComponents()}
			local Old = {Was:GetComponents()}
			local Worst = 0
			for I = 1, 12 do Worst = math.max(Worst, math.abs(Now[I] - Old[I])) end
			cond(Worst > 0.01, ("FoundryYard's pivot moved (largest component change %.4f)"):format(Worst))
		end
	end
	return Fails, ("check: PASS %d / FAIL %d"):format(Passes, Fails), Out
end

-- ------------------------------------------------------------------ snapshot (test mode)
local function r3(V) return math.floor(V * 1000 + 0.5) / 1000 end
local function row(D)
	local A = {}
	for K, V in pairs(D:GetAttributes()) do
		if typeof(V) == "CFrame" then V = cfNums(V) end
		table.insert(A, K .. "=" .. tostring(V))
	end
	table.sort(A)
	local T = CS:GetTags(D)
	table.sort(T)
	local C = ""
	if D:IsA("BasePart") then
		local N = {D.CFrame:GetComponents()}
		for K = 1, 12 do N[K] = r3(N[K]) end
		C = table.concat(N, ",")
	elseif D:IsA("ObjectValue") then
		C = D.Value and D.Value:GetFullName() or "nil"
	end
	return D:GetFullName() .. "|" .. D.ClassName .. "|" .. C .. "|" .. table.concat(A, ",") .. "|" .. table.concat(T, ",")
end
local function snapshot()
	local Rows = {}
	local function take(Root) for _, D in ipairs(withDesc(Root)) do Rows[D] = row(D) end end
	take(World)
	local BK, RB = backupFolder()
	if BK then take(BK) end
	local Extra = {}
	local Tags = {}
	for _, T in ipairs(CS:GetAllTags()) do
		local N = #CS:GetTagged(T)
		if N > 0 then table.insert(Tags, T .. "=" .. N) end
	end
	table.sort(Tags)
	table.insert(Extra, "tags " .. table.concat(Tags, ","))
	local Kids = {}
	if RB then for _, C in ipairs(RB:GetChildren()) do table.insert(Kids, C.Name .. ":" .. #C:GetDescendants()) end end
	table.insert(Extra, "RenseiBackups " .. table.concat(Kids, ","))
	local NB = 0
	for _, D in ipairs(workspace:GetDescendants()) do if D:IsA("BasePart") then NB += 1 end end
	table.insert(Extra, "workspace BaseParts " .. NB)
	table.insert(Extra, "flag " .. tostring(Map:GetAttribute(FLAG)))
	return Rows, table.concat(Extra, "\n")
end
local function compare(A, AX, B, BX)
	local Diff, N = {}, 0
	for I, R in pairs(A) do
		N += 1
		if B[I] ~= R then table.insert(Diff, "before: " .. R .. "\n    after: " .. tostring(B[I])) end
	end
	for I, R in pairs(B) do if A[I] == nil then table.insert(Diff, "new after: " .. R) end end
	if AX ~= BX then table.insert(Diff, "totals before:\n" .. AX .. "\n  after:\n" .. BX) end
	return Diff, N
end

-- ------------------------------------------------------------------ apply / undo
local function apply()
	local Lk = locked()
	if Lk then return false, Lk end
	if Map:GetAttribute(FLAG) ~= nil then return false, "already applied (World.Map's " .. FLAG .. " is " .. tostring(Map:GetAttribute(FLAG)) .. ")" end
	if Map:FindFirstChild("BrannocNotice") then return false, "World.Map.BrannocNotice already exists" end
	local Got = {}
	for _, P in ipairs(PIECES) do
		local X = P.Get()
		if not X then return false, P.Name .. " is missing" end
		if countNamed(X.Parent, P.Name) ~= 1 then return false, P.Name .. " is not the only child of its name in " .. X.Parent:GetFullName() end
		for _, D in ipairs(withDesc(X)) do
			if D:GetAttribute(KITTAGS) ~= nil then return false, D:GetFullName() .. " already carries " .. KITTAGS end
		end
		if X:FindFirstChild(FROM) or X:GetAttribute(FROMPATH) ~= nil then return false, X:GetFullName() .. " already carries " .. FROM end
		table.insert(Got, X)
	end
	local FY = Map:FindFirstChild("FoundryYard")
	if not FY then return false, "World.Map.FoundryYard is missing (owner decision A keeps it)" end
	local F = trainersFolder()
	local BK0, RB0 = backupFolder()
	if BK0 then
		for _, P in ipairs(PIECES) do if BK0:FindFirstChild(P.Name) then return false, "the backup already holds " .. P.Name end end
	end

	local Journal = {}
	local function did(Fn) table.insert(Journal, Fn) end
	local Rec
	pcall(function() Rec = CHS:TryBeginRecording("retire_ye apply") end)
	local Report = {}
	local Ok, Err = pcall(function()
		-- the backup folder (and RenseiBackups), marked when this script makes them
		local RB = RB0
		if not RB then
			RB = Instance.new("Folder")
			RB.Name = "RenseiBackups"
			RB:SetAttribute(ADD, true)
			did(function() RB:Destroy() end) -- (Ruling 38: the journal entry before the Parent)
			RB.Parent = SS
		end
		local BK = BK0
		if not BK then
			BK = Instance.new("Folder")
			BK.Name = BACKUP
			BK:SetAttribute(ADD, true)
			did(function() BK:Destroy() end) -- (Ruling 38: the journal entry before the Parent)
			BK.Parent = RB
		end
		-- the baseline, before anything moves (Ruling 5)
		local Stripped = 0
		for _, X in ipairs(Got) do for _, D in ipairs(withDesc(X)) do Stripped += #CS:GetTags(D) end end
		local Base = {BaselineInspect = inspectCount(), BaselineTrainers = #F:GetChildren(), BaselineYardParts = partCount(FY),
			BaselineYardPivot = cfNums(FY:GetPivot()), StrippedTags = Stripped}
		for K, V in pairs(Base) do
			local Was = BK:GetAttribute(K)
			did(function() BK:SetAttribute(K, Was) end)
			BK:SetAttribute(K, V)
		end
		table.insert(Report, ("baseline inspect %d, trainers %d, yard parts %d, stripped tags %d"):format(Base.BaselineInspect,
			Base.BaselineTrainers, Base.BaselineYardParts, Stripped))
		-- each piece: its old parent and path, its tags set aside, then moved
		for _, X in ipairs(Got) do
			local OldParent, OldPath = X.Parent, X:GetFullName()
			local Ov = Instance.new("ObjectValue")
			Ov.Name = FROM
			Ov.Value = OldParent
			Ov:SetAttribute(ADD, true)
			did(function() Ov:Destroy() end)
			Ov.Parent = X
			did(function() X:SetAttribute(FROMPATH, nil) end)
			X:SetAttribute(FROMPATH, OldPath)
			local N = 0
			for _, D in ipairs(withDesc(X)) do
				local Tags = CS:GetTags(D)
				if #Tags > 0 then
					did(function()
						for _, T in ipairs(Tags) do CS:AddTag(D, T) end
						D:SetAttribute(KITTAGS, nil)
					end)
					D:SetAttribute(KITTAGS, HS:JSONEncode(Tags))
					for _, T in ipairs(Tags) do CS:RemoveTag(D, T) end
					N += #Tags
				end
			end
			did(function() X.Parent = OldParent end)
			X.Parent = BK
			table.insert(Report, ("%s -> backup (%d tags set aside)"):format(OldPath, N))
		end
		-- the notice (owner decision D)
		local Notice = Instance.new("Model")
		Notice.Name = "BrannocNotice"
		Notice:SetAttribute(ADD, true)
		local Post = Instance.new("Part")
		Post.Name = "NoticePost"
		Post.Material = Enum.Material.Wood
		Post.Color = POST_COLOR
		Post.Size = POST_SIZE
		Post.CFrame = POST_CF
		Post.Anchored, Post.CanCollide = true, true
		Post.TopSurface, Post.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		Post:SetAttribute(ADD, true)
		Post.Parent = Notice
		local Board = Instance.new("Part")
		Board.Name = "NoticeBoard"
		Board.Material = Enum.Material.WoodPlanks
		Board.Color = BOARD_COLOR
		Board.Size = BOARD_SIZE
		Board.CFrame = BOARD_CF
		Board.Anchored, Board.CanCollide = true, true
		Board.TopSurface, Board.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		Board:SetAttribute(ADD, true)
		Board:SetAttribute("InspectId", NOTICE_ID)
		Board.Parent = Notice
		Notice.PrimaryPart = Post
		did(function() Notice:Destroy() end)
		Notice.Parent = Map
		CS:AddTag(Board, "RenseiInspect")
		table.insert(Report, ("BrannocNotice: post at %s, board at %s facing -Z"):format(f3(Post.Position), f3(Board.Position)))
		did(function() Map:SetAttribute(FLAG, nil) end)
		Map:SetAttribute(FLAG, "applied")
	end)
	if not Ok then
		local Errs = {}
		for I = #Journal, 1, -1 do
			local K, E = pcall(Journal[I])
			if not K then table.insert(Errs, tostring(E)) end
		end
		if Rec then pcall(function() CHS:FinishRecording(Rec, Enum.FinishRecordingOperation.Cancel) end) end
		return false, ("error: %s (rolled back %d steps%s)"):format(tostring(Err), #Journal, #Errs > 0 and (", " .. #Errs .. " rollback errors: " .. table.concat(Errs, "; ")) or "")
	end
	if Rec then pcall(function() CHS:FinishRecording(Rec, Enum.FinishRecordingOperation.Commit) end)
	else pcall(function() CHS:SetWaypoint("retire_ye apply") end) end
	return true, "applied: " .. table.concat(Report, "; ")
end

local function undo()
	local Lk = locked()
	if Lk then return false, Lk end
	if Map:GetAttribute(FLAG) ~= "applied" then return false, "not applied (World.Map's " .. FLAG .. " is " .. tostring(Map:GetAttribute(FLAG)) .. ")" end
	local BK, RB = backupFolder()
	if not BK then return false, "no ServerStorage.RenseiBackups." .. BACKUP end
	-- plan: every piece back to its old parent (checked before anything changes)
	local Back = {}
	for _, P in ipairs(PIECES) do
		local X = BK:FindFirstChild(P.Name)
		if not X then return false, P.Name .. " is not in the backup" end
		local Ov = X:FindFirstChild(FROM)
		local Parent = Ov and Ov:IsA("ObjectValue") and Ov.Value
		if not (Parent and Parent:IsDescendantOf(game)) then
			local Path = X:GetAttribute(FROMPATH)
			local ParentPath = type(Path) == "string" and string.match(Path, "^(.*)%.[^%.]+$")
			Parent = ParentPath and resolve(ParentPath)
		end
		if not Parent then return false, P.Name .. ": its old parent is gone and its " .. FROMPATH .. " names no unique parent" end
		if Parent:FindFirstChild(P.Name) then return false, Parent:GetFullName() .. " already has a " .. P.Name end
		for _, D in ipairs(withDesc(X)) do
			local J = D:GetAttribute(KITTAGS)
			if J ~= nil then
				local K, L = pcall(HS.JSONDecode, HS, J)
				if not (K and type(L) == "table") then return false, D:GetFullName() .. "'s " .. KITTAGS .. " is not a JSON list" end
			end
		end
		table.insert(Back, {X = X, Parent = Parent, Ov = Ov})
	end
	local Journal = {}
	local function did(Fn) table.insert(Journal, Fn) end
	local Rec
	pcall(function() Rec = CHS:TryBeginRecording("retire_ye undo") end)
	local Gone = {} -- destroyed at the end, once nothing can fail
	local Ok, Err = pcall(function()
		local Notice = Map:FindFirstChild("BrannocNotice")
		-- (Ruling 38) only the notice apply made (FoundryMoveAdd): a BrannocNotice someone else built stays
		if Notice and Notice:GetAttribute(ADD) == true then
			did(function() Notice.Parent = Map end)
			Notice.Parent = nil
			table.insert(Gone, Notice)
		end
		for _, B in ipairs(Back) do
			local X = B.X
			did(function() X.Parent = BK end)
			X.Parent = B.Parent
			for _, D in ipairs(withDesc(X)) do
				local J = D:GetAttribute(KITTAGS)
				if J ~= nil then
					local Tags = HS:JSONDecode(J)
					did(function()
						for _, T in ipairs(Tags) do CS:RemoveTag(D, T) end
						D:SetAttribute(KITTAGS, J)
					end)
					for _, T in ipairs(Tags) do CS:AddTag(D, T) end
					D:SetAttribute(KITTAGS, nil)
				end
			end
			local Path = X:GetAttribute(FROMPATH)
			did(function() X:SetAttribute(FROMPATH, Path) end)
			X:SetAttribute(FROMPATH, nil)
			if B.Ov then
				local Ov = B.Ov
				did(function() Ov.Parent = X end)
				Ov.Parent = nil
				table.insert(Gone, Ov)
			end
		end
		for _, K in ipairs({"BaselineInspect", "BaselineTrainers", "BaselineYardParts", "BaselineYardPivot", "StrippedTags"}) do
			local Was = BK:GetAttribute(K)
			did(function() BK:SetAttribute(K, Was) end)
			BK:SetAttribute(K, nil)
		end
		if BK:GetAttribute(ADD) then
			if #BK:GetChildren() ~= 0 then error("the backup folder is not empty after the move back") end
			did(function() BK.Parent = RB end)
			BK.Parent = nil
			table.insert(Gone, BK)
			if RB:GetAttribute(ADD) and #RB:GetChildren() == 0 then
				did(function() RB.Parent = SS end)
				RB.Parent = nil
				table.insert(Gone, RB)
			end
		end
		did(function() Map:SetAttribute(FLAG, "applied") end)
		Map:SetAttribute(FLAG, nil)
	end)
	if not Ok then
		local Errs = {}
		for I = #Journal, 1, -1 do
			local K, E = pcall(Journal[I])
			if not K then table.insert(Errs, tostring(E)) end
		end
		if Rec then pcall(function() CHS:FinishRecording(Rec, Enum.FinishRecordingOperation.Cancel) end) end
		return false, ("error: %s (rolled back %d steps%s)"):format(tostring(Err), #Journal, #Errs > 0 and (", " .. #Errs .. " rollback errors: " .. table.concat(Errs, "; ")) or "")
	end
	for _, G in ipairs(Gone) do G:Destroy() end
	if Rec then pcall(function() CHS:FinishRecording(Rec, Enum.FinishRecordingOperation.Commit) end)
	else pcall(function() CHS:SetWaypoint("retire_ye undo") end) end
	local Names = {}
	for _, B in ipairs(Back) do table.insert(Names, B.X:GetFullName()) end
	return true, "undone: the notice removed; back with their tags: " .. table.concat(Names, ", ") .. "; " .. FLAG .. " cleared"
end

-- ------------------------------------------------------------------ run
local Out = {}
if MODE == "plan" then
	table.insert(Out, ("retire_ye plan: World.Map's %s is %s; PlayLock %s"):format(FLAG, tostring(Map:GetAttribute(FLAG)), tostring(SS:GetAttribute("PlayLock"))))
	for _, P in ipairs(PIECES) do
		local X = P.Get()
		if X then
			local Tags = {}
			for _, D in ipairs(withDesc(X)) do for _, T in ipairs(CS:GetTags(D)) do table.insert(Tags, T) end end
			table.insert(Out, ("  %s: %d BaseParts, %d descendants, tags [%s]"):format(X:GetFullName(), partCount(X), #X:GetDescendants(), table.concat(Tags, ",")))
		else
			table.insert(Out, "  " .. P.Name .. ": not in the world")
		end
	end
	local FY, F = Map:FindFirstChild("FoundryYard"), trainersFolder()
	table.insert(Out, ("  baseline now: inspect %d, trainers %s, FoundryYard parts %s pivot %s"):format(inspectCount(),
		F and #F:GetChildren() or "-", FY and partCount(FY) or "-", FY and cfNums(FY:GetPivot()) or "-"))
	table.insert(Out, ("  notice: post %s, board %s"):format(f3(POST_CF.Position), f3(BOARD_CF.Position)))
elseif MODE == "apply" then
	local Ok, Msg = apply()
	if not Ok then return refuse(Msg) end
	local _, Head, Lines = checks()
	table.insert(Out, "retire_ye apply: " .. Msg)
	table.insert(Out, Head)
	for _, L in ipairs(Lines) do table.insert(Out, L) end
elseif MODE == "undo" then
	local Ok, Msg = undo()
	if not Ok then return refuse(Msg) end
	table.insert(Out, "retire_ye undo: " .. Msg)
elseif MODE == "check" then
	local _, Head, Lines = checks()
	table.insert(Out, "retire_ye " .. Head .. " (" .. FLAG .. " is " .. tostring(Map:GetAttribute(FLAG)) .. ")")
	for _, L in ipairs(Lines) do table.insert(Out, L) end
elseif MODE == "test" then
	if Map:GetAttribute(FLAG) ~= nil then return refuse("applied; undo first or run check") end
	local Lk = locked()
	if Lk then return refuse(Lk) end
	local SOk0, Before, BeforeX = pcall(snapshot)
	if not SOk0 then return refuse("snapshot failed: " .. tostring(Before)) end
	local Ok, Msg = apply()
	if not Ok then return refuse(Msg) end
	local COk, Fails, Head, Lines = pcall(checks)
	-- (Ruling 38) undo in a pcall: an error in it is reported, not raised past the report
	local PUOk, UOk, UMsg = pcall(undo)
	if not PUOk then UOk, UMsg = false, "error: " .. tostring(UOk) end
	local SOk, After, AfterX = pcall(snapshot)
	local Diff, N = {}, 0
	if SOk then Diff, N = compare(Before, BeforeX, After, AfterX) end
	table.insert(Out, ("retire_ye test: %s\n%s\n%s\nround trip %s (%d instances)"):format(Msg,
		COk and Head or ("CHECK ERROR: " .. tostring(Fails)), UOk and UMsg or ("UNDO FAILED: " .. tostring(UMsg)),
		SOk and (#Diff == 0 and "EXACT" or ("DIFFERS in " .. #Diff)) or ("SNAPSHOT ERROR: " .. tostring(After)), N))
	if COk then for _, L in ipairs(Lines) do table.insert(Out, L) end end
	for I = 1, math.min(#Diff, 8) do table.insert(Out, "  diff " .. Diff[I]) end
else
	return refuse("unknown MODE " .. tostring(MODE))
end
return table.concat(Out, "\n")

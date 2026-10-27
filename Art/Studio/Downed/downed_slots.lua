--!nocheck
-- downed_slots.lua (downed crawl side task, owner 2026-10-27). Fills the Downed animation slots in
-- ReplicatedStorage.Assets.Animations.Shared.Combat.Downed with the owner's ids (given in chat; not in the Animation
-- ID's sheet yet):
--   Knocked      <- Downed Idle   140397797689506 (replaces the questionable Greatsword grip-victim stand-in; the old
--                                 SheetId is kept in PreviousSheetId)
--   DownedCrawl  <- Downed Crawl  140556271258345 (a NEW slot; AnimationManager plays it while a knocked player moves)
--   Carrying     <- Carry         70888533900445  (the carrier; was an unpublished Save placeholder)
--   Carried      <- Carried       124248460861263 (the one carried; was an unpublished Save placeholder)
-- Each filled slot gets AnimationId, SheetId and DownedSlots = "2026-10-27"; the old values go into PreviousSheetId /
-- PreviousAnimationId / PreviousUnpublished, and Unpublished is cleared (the Save child stays, unused while an id is
-- set). AnimationManager keys animations by NAME, so apply refuses if "DownedCrawl" exists anywhere else.
-- Assets is a Package in Ye and Foundry Yard: the owner publishes it. The Tutorial's Assets is not a Package.
-- Runs in Edit only (python -I Art/Tools/rbxc.py luau "placeId: <id>" Edit @<copy with MODE set>):
-- MODE = "apply"  refuses while Play runs or this place's ServerStorage PlayLock is set. Clones the Downed folder
--                 once into ServerStorage.RenseiBackups["Pre-DownedCrawl_2026-10-27"].Assets_Downed first.
--                 Re-running is safe ("same" when already applied).
-- MODE = "check"  read-only: "PASS n / FAIL n" and a line per failure.
-- MODE = "undo"   puts the backed-up folder back (refuses without the backup).
local MODE = "check"

local RunService = game:GetService("RunService")
local SS = game:GetService("ServerStorage")
local BACKUP = "Pre-DownedCrawl_2026-10-27"
local STAMP = "2026-10-27"
local SLOTS = {
	{Name = "Knocked", Id = 140397797689506, Label = "Downed Idle"},
	{Name = "DownedCrawl", Id = 140556271258345, Label = "Downed Crawl", New = true},
	{Name = "Carrying", Id = 70888533900445, Label = "Carry (the carrier)"},
	{Name = "Carried", Id = 124248460861263, Label = "Carried (the one being carried)"},
}

local function refuse(Why) return "downed_slots " .. MODE .. " REFUSED: " .. Why end
if RunService:IsRunning() then return refuse("Play is running; Edit only") end
local Anims = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
Anims = Anims and Anims:FindFirstChild("Animations")
local Dir = Anims and Anims:FindFirstChild("Shared") and Anims.Shared:FindFirstChild("Combat")
	and Anims.Shared.Combat:FindFirstChild("Downed")
if not Dir then return refuse("no Assets.Animations.Shared.Combat.Downed") end

local function byName(Name)
	local L = {}
	for _, D in ipairs(Anims:GetDescendants()) do if D.Name == Name then table.insert(L, D) end end
	return L
end
local function backupFolder()
	local Root = SS:FindFirstChild("RenseiBackups")
	return Root and Root:FindFirstChild(BACKUP)
end

if MODE == "check" then
	local Out, P, F = {}, 0, 0
	local function line(Ok, S) if Ok then P += 1 else F += 1 table.insert(Out, "  FAIL " .. S) end end
	for _, S in ipairs(SLOTS) do
		local L = byName(S.Name)
		line(#L == 1, S.Name .. ": exactly one under Assets.Animations (" .. #L .. ")")
		local A = L[1]
		if A then
			line(A.Parent == Dir and A:IsA("Animation"), S.Name .. ": an Animation in Shared.Combat.Downed")
			line(A.AnimationId == "rbxassetid://" .. S.Id, S.Name .. ": AnimationId " .. A.AnimationId)
			line(tostring(A:GetAttribute("SheetId")) == tostring(S.Id), S.Name .. ": SheetId " .. tostring(A:GetAttribute("SheetId")))
			line(A:GetAttribute("DownedSlots") == STAMP, S.Name .. ": DownedSlots stamp")
			line(A:GetAttribute("Unpublished") == nil, S.Name .. ": Unpublished cleared")
		end
	end
	local K = Dir:FindFirstChild("Knocked")
	-- (the Tutorial's Knocked had no SheetId: its old values are PreviousAnimationId / PreviousUnpublished only)
	line(K ~= nil and (K:GetAttribute("PreviousSheetId") ~= nil or K:GetAttribute("PreviousAnimationId") ~= nil),
		"Knocked: the old id recorded (PreviousSheetId / PreviousAnimationId)")
	line(backupFolder() ~= nil and backupFolder():FindFirstChild("Assets_Downed") ~= nil, "backup Assets_Downed exists")
	return string.format("PASS %d / FAIL %d", P, F) .. (#Out > 0 and ("\n" .. table.concat(Out, "\n")) or "")
end

if SS:GetAttribute("PlayLock") then return refuse("PlayLock is set: " .. tostring(SS:GetAttribute("PlayLock"))) end

if MODE == "undo" then
	local B = backupFolder()
	local Saved = B and B:FindFirstChild("Assets_Downed")
	if not Saved then return refuse("no backup Assets_Downed") end
	local Parent = Dir.Parent
	local New = Saved:Clone()
	New.Name = "Downed"
	Dir:Destroy()
	New.Parent = Parent
	return "downed_slots undo: the Downed folder is back as backed up"
end

if MODE ~= "apply" then return refuse("unknown MODE " .. tostring(MODE)) end
-- a name clash elsewhere would make AnimationManager pick either one
for _, S in ipairs(SLOTS) do
	for _, D in ipairs(byName(S.Name)) do
		if D.Parent ~= Dir then return refuse(S.Name .. " already exists at " .. D:GetFullName()) end
	end
	if not S.New and not Dir:FindFirstChild(S.Name) then return refuse("no slot " .. S.Name) end
end
local Root = SS:FindFirstChild("RenseiBackups") or Instance.new("Folder")
Root.Name = "RenseiBackups"
Root.Parent = SS
local B = Root:FindFirstChild(BACKUP) or Instance.new("Folder")
B.Name = BACKUP
B.Parent = Root
if not B:FindFirstChild("Assets_Downed") then
	local C = Dir:Clone()
	C.Name = "Assets_Downed"
	C.Parent = B
end
local Done = {}
for _, S in ipairs(SLOTS) do
	local A = Dir:FindFirstChild(S.Name)
	if A and A:GetAttribute("DownedSlots") == STAMP and A.AnimationId == "rbxassetid://" .. S.Id then
		table.insert(Done, "same " .. S.Name)
	else
		if not A then
			A = Instance.new("Animation")
			A.Name = S.Name
			A:SetAttribute("DownedSlotAdd", true)
			A.Parent = Dir
		else
			if A:GetAttribute("SheetId") ~= nil then A:SetAttribute("PreviousSheetId", tostring(A:GetAttribute("SheetId"))) end
			A:SetAttribute("PreviousAnimationId", A.AnimationId)
			if A:GetAttribute("Unpublished") ~= nil then A:SetAttribute("PreviousUnpublished", A:GetAttribute("Unpublished")) end
			if A:GetAttribute("SheetStatus") ~= nil then A:SetAttribute("PreviousSheetStatus", A:GetAttribute("SheetStatus")) end
		end
		A.AnimationId = "rbxassetid://" .. S.Id
		A:SetAttribute("SheetId", tostring(S.Id))
		A:SetAttribute("Unpublished", nil)
		A:SetAttribute("SheetStatus", S.Label .. ": the owner's id (chat, 2026-10-27); not in the Animation ID's sheet yet")
		A:SetAttribute("DownedSlots", STAMP)
		table.insert(Done, "set " .. S.Name)
	end
end
return "downed_slots apply: " .. table.concat(Done, ", ")

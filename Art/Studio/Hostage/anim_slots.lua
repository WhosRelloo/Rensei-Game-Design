--!nocheck
-- anim_slots.lua: hostages Task 3 (2026-10-27). The four hostage animation slots, in both places, reversible.
-- It makes the Folder ReplicatedStorage.Assets.Animations.Shared.Hostage (HostageAdd = true) and four Animations in it,
-- each with HostageAdd = true and a Fallback attribute. Under Shared the client preloads them (AnimationManager
-- preloads Shared and Weapons by NAME). An Animation with an empty AnimationId and no KeyframeSequence is skipped by
-- AnimationManager (Playable returns nil), so AnimationManager.Has(Character, slot) is false and Play(..., {Fallback})
-- plays the fallback: that is what an empty slot is for. Pasting an id into the slot later makes it play with no code change.
--   Hostage_Bind      Fallback "Takedown_Choke"        (controller ruling: "Gripping" is an empty slot in both places)
--   Hostage_Hold      Fallback "Carrying"
--   Hostage_Held      Fallback "Takedown_ChokeVictim"
--   Hostage_Struggle  Fallback "Takedown_ChokeVictim"
-- The Fallback attribute duplicates Rensei.Hostage.Anims[*].Fallback (that module is the source the code uses;
-- AnimationManager doesn't read the attribute). Accepted duplication (pre-flight D1); check asserts the two agree.
-- Task 1 found no hostage rows on the owner's sheets, so every slot is empty (AnimationId "") and SHEET is empty.
-- If a row is found later, put its id in SHEET ({Hostage_Hold = 123, ...}): apply then writes "rbxassetid://<id>" and a
-- SheetId attribute for that slot.
-- Assets is a Package in both places: this changes both places' Assets copies; publishing is the owner's.
-- Runs in Ye (106992859583940) or Foundry Yard (109591196441030), Edit only:
--   python -I Art/Tools/rbxc.py luau "placeId: <id>" Edit @<a scratch copy with its MODE line set>
-- To run another MODE, copy this file to a scratch folder and change only the MODE line there. Before a Foundry
-- apply or undo, the runner checks that Ye's ServerStorage PlayLock is nil (this script can't read another place).
-- MODE = "plan"   read-only: where each name is, the flag, and what apply would do.
-- MODE = "apply"  refuses, changing nothing, while Play runs, while this place's PlayLock is set, when the flag
--                 HostageAnimSlots (on Assets.Animations) is set, when Shared.Hostage or any of the four slot names
--                 exists anywhere under Assets.Animations, or when a Fallback target isn't one Animation under Shared
--                 or Weapons. Records the names of Shared's, Weapons' and Registry's direct children in
--                 HostageAnimSlotsBase, then makes the changes in a pcall with a journal (an error mid-way is rolled
--                 back) inside one ChangeHistory recording (cancelled on an error). Then runs check.
-- MODE = "undo"   refuses while Play runs or PlayLock is set, and refuses (naming the slot) when a slot no longer
--                 holds the id apply wrote (the owner pasted one: never delete an owner's id), or when the folder
--                 holds anything apply didn't put there. Destroys exactly the HostageAdd instances and clears the
--                 flag and the baseline.
-- MODE = "check"  read-only failure list: the folder; the four names in it once each (and nowhere else), each an
--                 Animation with HostageAdd and its Fallback; each AnimationId "" or rbxassetid://<digits>; the
--                 Fallback attributes equal the constants and Rensei.Hostage.Anims; each fallback target once as an
--                 Animation under Shared or Weapons; Shared's, Weapons' and Registry's direct children equal the
--                 baseline apply recorded. Returns "PASS n / FAIL n".
-- MODE = "test"   (only while not applied) snapshot -> apply -> check -> undo -> snapshot; the two must be equal.
local MODE = "plan" -- "plan", "apply", "undo", "check" or "test"

local SHEET = {} -- Task 1 found no hostage rows on the owner's sheets; a found row goes here, e.g. {Hostage_Hold = 123456}
local SLOTS = { -- Fallback = Rensei.Hostage.Anims[*].Fallback (checked against the module)
	{Name = "Hostage_Bind", Fallback = "Takedown_Choke"},
	{Name = "Hostage_Hold", Fallback = "Carrying"},
	{Name = "Hostage_Held", Fallback = "Takedown_ChokeVictim"},
	{Name = "Hostage_Struggle", Fallback = "Takedown_ChokeVictim"},
}
local DIR = "Hostage" -- Shared.Hostage
local FLAG, BASE = "HostageAnimSlots", "HostageAnimSlotsBase" -- on Assets.Animations
local MARK = "HostageAdd"
local TOPS = {"Shared", "Weapons", "Registry"}
local PLACES = {[106992859583940] = "Ye", [109591196441030] = "Foundry"}

local CHS = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local function refuse(why) return "anim_slots " .. MODE .. " REFUSED: " .. why end
local Where = PLACES[game.PlaceId]
if not Where then return refuse("this is neither Ye nor Foundry Yard (" .. tostring(game.PlaceId) .. ")") end
if RunService:IsRunning() then return refuse("Play is running; Edit only") end
local Anims = RS:FindFirstChild("Assets") and RS.Assets:FindFirstChild("Animations")
local Shared = Anims and Anims:FindFirstChild("Shared")
if not (Shared and Anims:FindFirstChild("Weapons") and Anims:FindFirstChild("Registry")) then
	return refuse("no Assets.Animations with Shared, Weapons and Registry")
end

-- what apply writes for a slot: the sheet's id when Task 1 found the row, else ""
local function want(S)
	local Id = SHEET[S.Name]
	return Id and ("rbxassetid://" .. tostring(Id)) or ""
end
local function byName(Name)
	local L = {}
	for _, D in ipairs(Anims:GetDescendants()) do if D.Name == Name then table.insert(L, D) end end
	return L
end
local function underClient(X) return X:IsDescendantOf(Shared) or X:IsDescendantOf(Anims.Weapons) end
local function targetOk(Name) -- one Animation under Shared or Weapons
	local F = byName(Name)
	return #F == 1 and F[1]:IsA("Animation") and underClient(F[1]), #F
end
local function tops() -- the names of Shared's, Weapons' and Registry's direct children (not this script's folder)
	local T = {}
	for _, Top in ipairs(TOPS) do
		local L = {}
		for _, C in ipairs(Anims[Top]:GetChildren()) do
			if C:GetAttribute(MARK) ~= true then table.insert(L, C.Name .. "[" .. C.ClassName .. "]") end
		end
		table.sort(L)
		table.insert(T, Top .. ":" .. table.concat(L, ","))
	end
	return HttpService:JSONEncode(T)
end
local function locked()
	local L = SS:GetAttribute("PlayLock")
	return L ~= nil and ("PlayLock is set (" .. tostring(L) .. ")") or nil
end

-- ------------------------------------------------------------------ check (a failure list)
local function checks()
	local Out, Fails, Passes = {}, 0, 0
	local function line(Ok, S) if Ok then Passes += 1 else Fails += 1 table.insert(Out, "  FAIL " .. S) end end
	local Dir = Shared:FindFirstChild(DIR)
	line(Dir ~= nil and Dir:IsA("Folder") and Dir:GetAttribute(MARK) == true, "Shared." .. DIR .. ": a Folder with " .. MARK)
	line(#byName(DIR) == 1, DIR .. ": exactly one under Assets.Animations (" .. #byName(DIR) .. ")")
	for _, S in ipairs(SLOTS) do
		local L = byName(S.Name)
		line(#L == 1, S.Name .. ": exactly one under Assets.Animations (" .. #L .. ")")
		local A = L[1]
		if A then
			line(Dir ~= nil and A.Parent == Dir and A:IsA("Animation") and A:GetAttribute(MARK) == true, S.Name .. ": an Animation in Shared." .. DIR .. " with " .. MARK)
			local Id = A:IsA("Animation") and A.AnimationId or "?"
			line(Id == "" or Id:match("^rbxassetid://%d+$") ~= nil, S.Name .. ": AnimationId " .. ("%q"):format(Id) .. " is neither empty nor rbxassetid://<digits>")
			line(A:GetAttribute("Fallback") == S.Fallback, S.Name .. ": Fallback " .. tostring(A:GetAttribute("Fallback")) .. ", not " .. S.Fallback)
			line(#A:GetChildren() == 0, S.Name .. ": no children (" .. #A:GetChildren() .. ")")
		end
		local Ok, N = targetOk(S.Fallback)
		line(Ok, S.Name .. "'s Fallback " .. S.Fallback .. ": one Animation under Shared or Weapons (" .. N .. ")")
		line(#byName(S.Fallback) == 0 or byName(S.Fallback)[1].Name ~= S.Name, S.Name .. "'s Fallback isn't itself")
	end
	-- the slot attributes agree with the module the code uses
	local M = RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("Data") and RS.Modules.Data:FindFirstChild("Rensei")
	M = M and M:FindFirstChild("Hostage")
	local MOk, H = false, nil
	if M and M:IsA("ModuleScript") then MOk, H = pcall(require, M) end
	line(MOk and type(H) == "table" and type(H.Anims) == "table", "Rensei.Hostage.Anims readable (" .. tostring(MOk and "no Anims" or H) .. ")")
	if MOk and type(H) == "table" and type(H.Anims) == "table" then
		local Count, ByName = 0, {}
		for _, E in pairs(H.Anims) do Count += 1 ByName[E.Name] = E.Fallback end
		line(Count == #SLOTS, "Rensei.Hostage.Anims has " .. Count .. " entries, not " .. #SLOTS)
		for _, S in ipairs(SLOTS) do
			local A = byName(S.Name)[1]
			line(ByName[S.Name] == S.Fallback and (A == nil or A:GetAttribute("Fallback") == ByName[S.Name]),
				S.Name .. ": Fallback attribute " .. tostring(A and A:GetAttribute("Fallback")) .. " vs Rensei.Hostage.Anims " .. tostring(ByName[S.Name]))
		end
	end
	if Dir then
		local Extra = {}
		for _, C in ipairs(Dir:GetChildren()) do
			local Known = false
			for _, S in ipairs(SLOTS) do Known = Known or C.Name == S.Name end
			if not Known then table.insert(Extra, C.Name) end
		end
		line(#Extra == 0, "Shared." .. DIR .. " holds only the four slots (also: " .. table.concat(Extra, ",") .. ")")
	end
	local Base = Anims:GetAttribute(BASE)
	line(Base ~= nil and Base == tops(), "Shared's, Weapons' and Registry's direct children are as recorded at apply")
	line(Anims:GetAttribute(FLAG) == true, FLAG .. " is " .. tostring(Anims:GetAttribute(FLAG)) .. ", not true")
	return Fails, Passes, Out
end

-- ------------------------------------------------------------------ snapshot (test mode)
local function attrs(X)
	local A = {}
	for K, V in pairs(X:GetAttributes()) do table.insert(A, K .. "=" .. tostring(V)) end
	table.sort(A)
	return table.concat(A, ",")
end
local function snapshot() -- every Folder, Animation and KeyframeSequence (not the poses inside) with its attributes
	local Rows = {}
	for _, D in ipairs(Anims:GetDescendants()) do
		if D:IsA("Folder") or D:IsA("Animation") or D:IsA("KeyframeSequence") then
			table.insert(Rows, D:GetFullName() .. "|" .. D.ClassName .. "|" .. (D:IsA("Animation") and D.AnimationId or "") .. "|" .. attrs(D))
		end
	end
	table.sort(Rows)
	return table.concat(Rows, "\n") .. "\n#descendants " .. #Anims:GetDescendants() .. "\n#Animations " .. attrs(Anims)
end

-- ------------------------------------------------------------------ apply / undo
local function apply()
	local Lk = locked()
	if Lk then return false, Lk end
	if Anims:GetAttribute(FLAG) ~= nil then return false, "already applied (" .. FLAG .. " is " .. tostring(Anims:GetAttribute(FLAG)) .. ")" end
	if #byName(DIR) > 0 then return false, byName(DIR)[1]:GetFullName() .. " already exists" end
	for _, S in ipairs(SLOTS) do
		local L = byName(S.Name)
		if #L > 0 then return false, S.Name .. " already exists (" .. L[1]:GetFullName() .. ")" end
		local Ok, N = targetOk(S.Fallback)
		if not Ok then return false, S.Name .. "'s Fallback " .. S.Fallback .. " isn't one Animation under Shared or Weapons (" .. N .. ")" end
	end
	local Journal = {}
	local Rec
	pcall(function() Rec = CHS:TryBeginRecording("Hostage anim slots apply") end)
	local Ok, Err = pcall(function()
		table.insert(Journal, {"attr", Anims, BASE, Anims:GetAttribute(BASE)})
		Anims:SetAttribute(BASE, tops())
		local Dir = Instance.new("Folder")
		Dir.Name = DIR
		Dir:SetAttribute(MARK, true)
		table.insert(Journal, {"inst", Dir}) -- (journalled before it is parented)
		Dir.Parent = Shared
		for _, S in ipairs(SLOTS) do
			local A = Instance.new("Animation")
			A.Name = S.Name
			A.AnimationId = want(S)
			A:SetAttribute(MARK, true)
			A:SetAttribute("Fallback", S.Fallback)
			if SHEET[S.Name] then A:SetAttribute("SheetId", SHEET[S.Name]) end
			A.Parent = Dir -- (destroyed with the folder on a rollback)
		end
		table.insert(Journal, {"attr", Anims, FLAG, nil})
		Anims:SetAttribute(FLAG, true)
	end)
	if not Ok then
		for I = #Journal, 1, -1 do
			local J = Journal[I]
			pcall(function()
				if J[1] == "inst" then J[2]:Destroy()
				elseif J[1] == "attr" then J[2]:SetAttribute(J[3], J[4]) end
			end)
		end
		if Rec then pcall(function() CHS:FinishRecording(Rec, Enum.FinishRecordingOperation.Cancel) end) end
		return false, "error: " .. tostring(Err) .. " (rolled back " .. #Journal .. " steps)"
	end
	if Rec then pcall(function() CHS:FinishRecording(Rec, Enum.FinishRecordingOperation.Commit) end)
	else pcall(function() CHS:SetWaypoint("Hostage anim slots apply") end) end
	return true, ("made Shared.%s with %d slots (%d with a sheet id); %s = true"):format(DIR, #SLOTS, (function()
		local N = 0 for _ in pairs(SHEET) do N += 1 end return N end)(), FLAG)
end

local function undo()
	local Lk = locked()
	if Lk then return false, Lk end
	local Dir = Shared:FindFirstChild(DIR)
	local Made = {}
	if Dir then
		if Dir:GetAttribute(MARK) ~= true then return false, Dir:GetFullName() .. " doesn't carry " .. MARK end
		for _, C in ipairs(Dir:GetChildren()) do
			if C:GetAttribute(MARK) ~= true then return false, C:GetFullName() .. " wasn't put there by apply: move it out first" end
			local Slot
			for _, S in ipairs(SLOTS) do if S.Name == C.Name then Slot = S end end
			if not Slot then return false, C:GetFullName() .. " carries " .. MARK .. " but isn't one of this script's slots" end
			if not C:IsA("Animation") or C.AnimationId ~= want(Slot) then
				return false, ("%s: slot %s holds AnimationId %q, not the %q apply wrote (changed since apply): not deleted"):format(
					C:GetFullName(), Slot.Name, C:IsA("Animation") and C.AnimationId or "?", want(Slot))
			end
			table.insert(Made, C)
		end
	end
	local Rec
	pcall(function() Rec = CHS:TryBeginRecording("Hostage anim slots undo") end)
	local Ok, Err = pcall(function()
		for _, C in ipairs(Made) do C:Destroy() end
		if Dir then Dir:Destroy() end
		Anims:SetAttribute(FLAG, nil)
		Anims:SetAttribute(BASE, nil)
	end)
	if Rec then pcall(function() CHS:FinishRecording(Rec, Ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel) end)
	elseif Ok then pcall(function() CHS:SetWaypoint("Hostage anim slots undo") end) end
	if not Ok then return false, "error: " .. tostring(Err) end
	return true, ("destroyed %d slots and %s; %s and %s cleared"):format(#Made, Dir and ("Shared." .. DIR) or "no folder", FLAG, BASE)
end

-- ------------------------------------------------------------------ run
local Out = {}
local Head = "anim_slots " .. MODE .. " (" .. Where .. ")"
if MODE == "plan" then
	local Rows = {}
	for _, N in ipairs({SLOTS[1].Name, SLOTS[2].Name, SLOTS[3].Name, SLOTS[4].Name, SLOTS[1].Fallback, SLOTS[2].Fallback, SLOTS[3].Fallback, DIR}) do
		local W = {}
		for _, X in ipairs(byName(N)) do table.insert(W, X:GetFullName() .. (X:IsA("Animation") and (" " .. X.AnimationId) or "")) end
		table.insert(Rows, N .. ": " .. (#W > 0 and table.concat(W, "; ") or "absent"))
	end
	table.insert(Out, ("%s: %s is %s; PlayLock %s; %s. Apply would make Shared.%s with %s, %s, %s and %s."):format(
		Head, FLAG, tostring(Anims:GetAttribute(FLAG)), tostring(SS:GetAttribute("PlayLock")), table.concat(Rows, " | "),
		DIR, SLOTS[1].Name, SLOTS[2].Name, SLOTS[3].Name, SLOTS[4].Name))
elseif MODE == "apply" then
	local Ok, Msg = apply()
	if not Ok then return refuse(Msg) end
	local Fails, Passes, Lines = checks()
	table.insert(Out, ("%s: %s; check PASS %d / FAIL %d"):format(Head, Msg, Passes, Fails))
	for _, L in ipairs(Lines) do table.insert(Out, L) end
elseif MODE == "undo" then
	local Ok, Msg = undo()
	if not Ok then return refuse(Msg) end
	table.insert(Out, Head .. ": " .. Msg)
elseif MODE == "check" then
	local Fails, Passes, Lines = checks()
	table.insert(Out, ("%s: PASS %d / FAIL %d (%s is %s)"):format(Head, Passes, Fails, FLAG, tostring(Anims:GetAttribute(FLAG))))
	for _, L in ipairs(Lines) do table.insert(Out, L) end
elseif MODE == "test" then
	if Anims:GetAttribute(FLAG) ~= nil then return refuse("applied; test runs only while not applied") end
	local Before = snapshot()
	local Ok, Msg = apply()
	if not Ok then return refuse("apply: " .. Msg) end
	local COk, Fails, Passes, Lines = pcall(checks)
	local PUOk, UOk, UMsg = pcall(undo)
	if not PUOk then UOk, UMsg = false, "error: " .. tostring(UOk) end
	local SOk, After = pcall(snapshot)
	local Same = SOk and Before == After
	table.insert(Out, ("%s: apply: %s; check %s; undo: %s; snapshots equal: %s (%d rows); %s"):format(Head, Msg,
		COk and ("PASS " .. Passes .. " / FAIL " .. Fails) or ("ERROR " .. tostring(Fails)),
		UOk and UMsg or ("FAILED " .. tostring(UMsg)), SOk and tostring(Same) or ("ERROR " .. tostring(After)),
		select(2, Before:gsub("\n", "")) + 1,
		(COk and Fails == 0 and UOk and Same) and "TEST PASSED" or "TEST FAILED"))
	if COk then for _, L in ipairs(Lines) do table.insert(Out, L) end end
	if SOk and not Same then
		local B, A = {}, {}
		for L in Before:gmatch("[^\n]+") do B[L] = true end
		for L in After:gmatch("[^\n]+") do A[L] = true end
		for L in pairs(B) do if not A[L] then table.insert(Out, "  only before: " .. L) end end
		for L in pairs(A) do if not B[L] then table.insert(Out, "  only after: " .. L) end end
	end
else
	return refuse("unknown MODE " .. tostring(MODE))
end
return table.concat(Out, "\n")

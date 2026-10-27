--!nocheck
-- anim_slots.lua: assassinations Task 3 (2026-10-27). The takedown animation slots, in both places, reversible.
-- It makes the Folder ReplicatedStorage.Assets.Animations.Shared.Takedown (TakedownAdd = true) and:
--   MOVES Misc_Assassinate (the "Animation ID's" sheet, Misc. "Assassination: 83505608395055") into it from where
--     Task 1 found it (Registry.Misc), marked TakedownFrom = <the old parent's full name>. Under Shared the client
--     preloads it (AnimationManager preloads Shared and Weapons; Registry resolves only on the server). Nothing is
--     copied, so no name appears twice (AnimationManager keys animations by NAME across all of Assets.Animations).
--   CREATES three Animations with the owner's ids (owner update 2026-10-25; ruling R2; the sheet now lists all
--     three; Task 1: each loads, Rensei group), each with TakedownAdd = true, SheetId and a Fallback attribute:
--       Misc_AssassinateVictim  132728216355683 ("Victim", asset "HammerChoking", 4.717 s)  Fallback "Gripped"
--       Takedown_Choke          72960497872371  ("Knock out", 1.25 s)                       Fallback "Fist_BearHug"
--       Takedown_ChokeVictim    131914091661838 ("Hold", a one-keyframe looped pose)        Fallback "Fist_BearHugVictim"
--     The Fallback attribute documents Rensei.Takedown.Anims[*].PlayerFallback / VictimFallback (that module is the
--     source the code uses; AnimationManager doesn't read the attribute). Keep the two in step.
-- Ruling R3: Fist_BearHug and Fist_BearHugVictim stay in Shared.ClassSkills (already preloaded); this script never
-- moves them. The fallbacks Gripping and Gripped stay in Shared.Combat.Downed (the downed-crawl side task's folder).
-- Assets is a Package in both places: this changes both places' Assets copies; publishing is the owner's.
-- Runs in Ye (106992859583940) or Foundry Yard (109591196441030), Edit only:
--   python -I Art/Tools/rbxc.py luau "placeId: <id>" Edit @<a scratch copy with its MODE line set>
-- To run another MODE, copy this file to a scratch folder and change only the MODE line there. Before a Foundry
-- apply or undo, the runner checks that Ye's ServerStorage PlayLock is nil (this script can't read another place).
-- MODE = "plan"   read-only: where each name is, the flag, and what apply would do.
-- MODE = "apply"  refuses, changing nothing, while Play runs, while this place's PlayLock is set, when the flag
--                 TakedownAnimSlots (on Assets.Animations) is set, when Shared.Takedown or any of the three new names
--                 exists anywhere under Assets.Animations, when Misc_Assassinate isn't there exactly once or doesn't
--                 hold SHEET_ID, or when a Fallback target isn't under Shared or Weapons exactly once. Records the
--                 names of Shared's, Weapons' and Registry's direct children in TakedownAnimSlotsBase, then makes the
--                 changes in a pcall with a journal (an error mid-way is rolled back) inside one ChangeHistory
--                 recording (cancelled on an error). Then runs check.
-- MODE = "undo"   refuses while Play runs or PlayLock is set, and refuses (naming it) when a new slot no longer holds
--                 the id apply wrote (the owner changed it: never delete an owner's id), or when the folder holds
--                 anything apply didn't put there. Moves Misc_Assassinate back to its TakedownFrom parent (clearing
--                 TakedownFrom), destroys exactly the TakedownAdd instances and clears the flag and the baseline.
-- MODE = "check"  read-only failure list, against the constants below and the baseline apply recorded:
--                 the folder; the four names in it once each (and nowhere else); Misc_Assassinate holds SHEET_ID and
--                 carries TakedownFrom; each new slot holds its constant id and carries its Fallback and TakedownAdd;
--                 Fist_BearHug / Fist_BearHugVictim once each in Shared.ClassSkills (R3); Gripping / Gripped once each
--                 in Shared.Combat.Downed; every Fallback target once under Shared or Weapons; Shared's, Weapons' and
--                 Registry's direct children equal the baseline (direct children only: the downed-crawl slots are
--                 grandchildren, preflight section 6). Returns "PASS n / FAIL n".
-- MODE = "test"   (only while not applied) snapshot -> apply -> check -> undo -> snapshot; the two must be equal.
local MODE = "plan" -- "plan", "apply", "undo", "check" or "test"

local SHEET_ID = "rbxassetid://83505608395055" -- the sheet's Assassination (Misc_Assassinate), already in the game
local MOVE = "Misc_Assassinate"
local NEW = { -- the owner's ids (owner update 2026-10-25, R2); Fallback = Rensei.Takedown.Anims' fallbacks
	{Name = "Misc_AssassinateVictim", Id = "rbxassetid://132728216355683", Sheet = 132728216355683, Fallback = "Gripped"},
	{Name = "Takedown_Choke", Id = "rbxassetid://72960497872371", Sheet = 72960497872371, Fallback = "Fist_BearHug"},
	{Name = "Takedown_ChokeVictim", Id = "rbxassetid://131914091661838", Sheet = 131914091661838, Fallback = "Fist_BearHugVictim"},
}
local STAY = { -- names this script never moves, and where Task 1 found them (R3; section 6)
	{Name = "Fist_BearHug", Path = {"Shared", "ClassSkills"}},
	{Name = "Fist_BearHugVictim", Path = {"Shared", "ClassSkills"}},
	{Name = "Gripping", Path = {"Shared", "Combat", "Downed"}},
	{Name = "Gripped", Path = {"Shared", "Combat", "Downed"}},
}
local DIR = "Takedown" -- Shared.Takedown
local FLAG, BASE = "TakedownAnimSlots", "TakedownAnimSlotsBase" -- on Assets.Animations
local MARK, FROM = "TakedownAdd", "TakedownFrom"
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

local function byName(Name)
	local L = {}
	for _, D in ipairs(Anims:GetDescendants()) do if D.Name == Name then table.insert(L, D) end end
	return L
end
local function at(Path) -- a folder by its path under Assets.Animations
	local X = Anims
	for _, P in ipairs(Path) do X = X and X:FindFirstChild(P) end
	return X
end
local function underClient(X) return X:IsDescendantOf(Shared) or X:IsDescendantOf(Anims.Weapons) end
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
local function resolve(Full) -- an old parent's full name back to the instance (names here contain no dots)
	local Prefix = Anims:GetFullName()
	if Full == Prefix then return Anims end
	if Full:sub(1, #Prefix + 1) ~= Prefix .. "." then return nil end
	local X = Anims
	for Part in Full:sub(#Prefix + 2):gmatch("[^%.]+") do
		X = X:FindFirstChild(Part)
		if not X then return nil end
	end
	return X
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
	local M = byName(MOVE)
	line(#M == 1, MOVE .. ": exactly one under Assets.Animations (" .. #M .. ")")
	if M[1] then
		line(Dir ~= nil and M[1].Parent == Dir and M[1]:IsA("Animation"), MOVE .. ": an Animation in Shared." .. DIR .. " (" .. M[1]:GetFullName() .. ")")
		line(M[1].AnimationId == SHEET_ID, MOVE .. ": AnimationId " .. ("%q"):format(M[1].AnimationId) .. ", not " .. SHEET_ID)
		line(type(M[1]:GetAttribute(FROM)) == "string", MOVE .. ": carries " .. FROM)
		line(M[1]:GetAttribute(MARK) == nil, MOVE .. ": moved, not created (no " .. MARK .. ")")
	end
	for _, S in ipairs(NEW) do
		local L = byName(S.Name)
		line(#L == 1, S.Name .. ": exactly one under Assets.Animations (" .. #L .. ")")
		local A = L[1]
		if A then
			line(Dir ~= nil and A.Parent == Dir and A:IsA("Animation") and A:GetAttribute(MARK) == true, S.Name .. ": an Animation in Shared." .. DIR .. " with " .. MARK)
			line(A.AnimationId == S.Id, S.Name .. ": AnimationId " .. ("%q"):format(A.AnimationId) .. ", not " .. S.Id)
			line(A:GetAttribute("Fallback") == S.Fallback, S.Name .. ": Fallback " .. tostring(A:GetAttribute("Fallback")) .. ", not " .. S.Fallback)
			line(#A:GetChildren() == 0, S.Name .. ": no children (" .. #A:GetChildren() .. ")")
		end
		local F = byName(S.Fallback)
		line(#F == 1 and F[1]:IsA("Animation") and underClient(F[1]), S.Name .. "'s Fallback " .. S.Fallback .. ": one Animation under Shared or Weapons (" .. #F .. ")")
	end
	for _, S in ipairs(STAY) do
		local L = byName(S.Name)
		local Home = at(S.Path)
		line(#L == 1 and Home ~= nil and L[1].Parent == Home, S.Name .. ": once, in " .. table.concat(S.Path, ".") .. " (" .. #L .. (L[1] and (", " .. L[1]:GetFullName()) or "") .. ")")
	end
	if Dir then
		local Extra = {}
		for _, C in ipairs(Dir:GetChildren()) do
			local Known = C.Name == MOVE
			for _, S in ipairs(NEW) do Known = Known or C.Name == S.Name end
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
	for _, S in ipairs(NEW) do
		local L = byName(S.Name)
		if #L > 0 then return false, S.Name .. " already exists (" .. L[1]:GetFullName() .. ")" end
		local F = byName(S.Fallback)
		if not (#F == 1 and F[1]:IsA("Animation") and underClient(F[1])) then
			return false, S.Name .. "'s Fallback " .. S.Fallback .. " isn't one Animation under Shared or Weapons (" .. #F .. ")"
		end
	end
	local M = byName(MOVE)
	if #M ~= 1 then return false, MOVE .. " is missing or not unique (" .. #M .. " under Assets.Animations)" end
	M = M[1]
	if not M:IsA("Animation") then return false, M:GetFullName() .. " isn't an Animation" end
	if M.AnimationId ~= SHEET_ID then return false, M:GetFullName() .. ".AnimationId is " .. ("%q"):format(M.AnimationId) .. ", not the sheet's " .. SHEET_ID end
	if M:GetAttribute(FROM) ~= nil then return false, M:GetFullName() .. " already carries " .. FROM end
	local OldParent = M.Parent
	local Journal = {}
	local Rec
	pcall(function() Rec = CHS:TryBeginRecording("Takedown anim slots apply") end)
	local Ok, Err = pcall(function()
		table.insert(Journal, {"attr", Anims, BASE, Anims:GetAttribute(BASE)})
		Anims:SetAttribute(BASE, tops())
		local Dir = Instance.new("Folder")
		Dir.Name = DIR
		Dir:SetAttribute(MARK, true)
		table.insert(Journal, {"inst", Dir}) -- (journalled before it is parented)
		Dir.Parent = Shared
		table.insert(Journal, {"move", M, OldParent})
		M:SetAttribute(FROM, OldParent:GetFullName())
		M.Parent = Dir
		for _, S in ipairs(NEW) do
			local A = Instance.new("Animation")
			A.Name = S.Name
			A.AnimationId = S.Id
			A:SetAttribute(MARK, true)
			A:SetAttribute("Fallback", S.Fallback)
			A:SetAttribute("SheetId", S.Sheet)
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
				elseif J[1] == "move" then J[2].Parent = J[3] J[2]:SetAttribute(FROM, nil)
				elseif J[1] == "attr" then J[2]:SetAttribute(J[3], J[4]) end
			end)
		end
		if Rec then pcall(function() CHS:FinishRecording(Rec, Enum.FinishRecordingOperation.Cancel) end) end
		return false, "error: " .. tostring(Err) .. " (rolled back " .. #Journal .. " steps)"
	end
	if Rec then pcall(function() CHS:FinishRecording(Rec, Enum.FinishRecordingOperation.Commit) end)
	else pcall(function() CHS:SetWaypoint("Takedown anim slots apply") end) end
	return true, ("made Shared.%s; moved %s from %s; made %d slots with the owner's ids; %s = true"):format(
		DIR, MOVE, OldParent:GetFullName(), #NEW, FLAG)
end

local function undo()
	local Lk = locked()
	if Lk then return false, Lk end
	local Dir = Shared:FindFirstChild(DIR)
	local Made, Moved = {}, {}
	if Dir then
		for _, C in ipairs(Dir:GetChildren()) do
			if C:GetAttribute(MARK) == true then
				local Want
				for _, S in ipairs(NEW) do if S.Name == C.Name then Want = S end end
				if not Want then return false, C:GetFullName() .. " carries " .. MARK .. " but isn't one of this script's slots" end
				if not C:IsA("Animation") or C.AnimationId ~= Want.Id then
					return false, ("%s.AnimationId is %q, not the %s apply wrote (changed since apply): not deleted"):format(
						C:GetFullName(), C:IsA("Animation") and C.AnimationId or "?", Want.Id)
				end
				table.insert(Made, C)
			elseif type(C:GetAttribute(FROM)) == "string" then
				local P = resolve(C:GetAttribute(FROM))
				if not P then return false, C:GetFullName() .. "'s " .. FROM .. " (" .. C:GetAttribute(FROM) .. ") no longer exists" end
				if P:FindFirstChild(C.Name) then return false, P:GetFullName() .. " already holds a " .. C.Name end
				table.insert(Moved, {C, P})
			else
				return false, C:GetFullName() .. " wasn't put there by apply: move it out first"
			end
		end
		if Dir:GetAttribute(MARK) ~= true then return false, Dir:GetFullName() .. " doesn't carry " .. MARK end
	end
	local Rec
	pcall(function() Rec = CHS:TryBeginRecording("Takedown anim slots undo") end)
	local Ok, Err = pcall(function()
		for _, X in ipairs(Moved) do
			X[1].Parent = X[2]
			X[1]:SetAttribute(FROM, nil)
		end
		for _, C in ipairs(Made) do C:Destroy() end
		if Dir then Dir:Destroy() end
		Anims:SetAttribute(FLAG, nil)
		Anims:SetAttribute(BASE, nil)
	end)
	if Rec then pcall(function() CHS:FinishRecording(Rec, Ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel) end)
	elseif Ok then pcall(function() CHS:SetWaypoint("Takedown anim slots undo") end) end
	if not Ok then return false, "error: " .. tostring(Err) end
	local Back = {}
	for _, X in ipairs(Moved) do table.insert(Back, X[1].Name .. " -> " .. X[2]:GetFullName()) end
	return true, ("moved back %s; destroyed %d slots and %s; %s and %s cleared"):format(
		#Back > 0 and table.concat(Back, ", ") or "nothing", #Made, Dir and ("Shared." .. DIR) or "no folder", FLAG, BASE)
end

-- ------------------------------------------------------------------ run
local Out = {}
local Head = "anim_slots " .. MODE .. " (" .. Where .. ")"
if MODE == "plan" then
	local Rows = {}
	for _, N in ipairs({MOVE, NEW[1].Name, NEW[2].Name, NEW[3].Name, STAY[1].Name, STAY[2].Name, STAY[3].Name, STAY[4].Name, DIR}) do
		local L = byName(N)
		local W = {}
		for _, X in ipairs(L) do table.insert(W, X:GetFullName() .. (X:IsA("Animation") and (" " .. X.AnimationId) or "")) end
		table.insert(Rows, N .. ": " .. (#W > 0 and table.concat(W, "; ") or "absent"))
	end
	table.insert(Out, ("%s: %s is %s; PlayLock %s; %s. Apply would make Shared.%s, move %s into it, and make %s, %s and %s with the owner's ids."):format(
		Head, FLAG, tostring(Anims:GetAttribute(FLAG)), tostring(SS:GetAttribute("PlayLock")), table.concat(Rows, " | "),
		DIR, MOVE, NEW[1].Name, NEW[2].Name, NEW[3].Name))
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

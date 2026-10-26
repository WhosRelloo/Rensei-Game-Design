--!nocheck
-- reload_slot.lua: gun rework Task 7 (2026-10-25). The reload animation's slot: one Animation named Guns_Reload in
-- ReplicatedStorage.Assets.Animations.Weapons.Guns (Task 1's survey found that Guns folder in both places), holding the
-- owner's reload animation 97563934064498 ("Reloaded", Rensei group; Task 1: loads in both places, Track.Length 4.07 s).
-- WeaponManager.Reload plays it by name (TuningConfig Weapons.Guns.Reload.Anim) only when the slot holds an id.
-- Runs in Ye (placeId 106992859583940) and Foundry (109591196441030), Edit only, with Ye's ServerStorage PlayLock nil:
--   python -I Art/Tools/rbxc.py luau "placeId: <id>" Edit @<a scratch copy with its MODE line set>
-- MODE = "plan"   read-only: the slot's folder, any Guns_Reload already there, the flag, and what apply would make.
-- MODE = "apply"  refuses, changing nothing, while Play runs, while this place's PlayLock is set, when the flag
--                 (Assets.Animations' GunReloadSlot) is set, or when any Animation named Guns_Reload already exists under
--                 Assets.Animations. Then, in a pcall with a journal (an error half-way is rolled back) and one
--                 ChangeHistory recording (cancelled on an error): makes the Animation (AnimationId = WANT_ID, no
--                 children, GunReworkAdd = true) in Weapons.Guns, then sets the flag to WANT_ID (the value it wrote);
--                 then runs check.
-- MODE = "undo"   (refuses while Play runs or PlayLock is set) destroys only the Guns_Reload carrying GunReworkAdd and
--                 clears the flag. It refuses only when that slot's AnimationId differs from the flag's recorded value
--                 (someone changed it since).
-- MODE = "check"  read-only failure list, against the constants below (never against what it reads from the slot):
--                 not exactly one Guns_Reload under Assets.Animations; it isn't in Weapons.Guns; it has a child; its
--                 AnimationId isn't WANT_ID; it doesn't carry GunReworkAdd; the flag isn't WANT_ID. Returns PASS n / FAIL n.
-- MODE = "test"   (only while not applied) snapshot -> apply -> check -> undo -> snapshot; the two must be equal. The
--                 check, the undo and the snapshot run inside pcalls, so an error between apply and undo still undoes.
-- Assets is a package: the slot changes both places' Assets copies; publishing it is the owner's (Task 13's checkpoint).
local MODE = "plan" -- "plan", "apply", "undo", "check" or "test"

local WANT_ID = "rbxassetid://97563934064498" -- the owner's reload (Task 1: loads, 4.07 s, Rensei group)

local CHS = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local NAME = "Guns_Reload" -- TuningConfig Weapons.Guns.Reload.Anim
local FLAG = "GunReloadSlot" -- on Assets.Animations: the id apply wrote
local MARK = "GunReworkAdd"
local PLACES = {[106992859583940] = "Ye", [109591196441030] = "Foundry"}

local function refuse(why) return "reload_slot " .. MODE .. " REFUSED: " .. why end
if not PLACES[game.PlaceId] then return refuse("this is neither Ye nor Foundry (" .. tostring(game.PlaceId) .. ")") end
if RunService:IsRunning() then return refuse("Play is running; Edit only") end
local Assets = RS:FindFirstChild("Assets")
local Anims = Assets and Assets:FindFirstChild("Animations")
local Weapons = Anims and Anims:FindFirstChild("Weapons")
local Guns = Weapons and Weapons:FindFirstChild("Guns")
if not (Guns and Guns:IsA("Folder")) then return refuse("no ReplicatedStorage.Assets.Animations.Weapons.Guns folder") end

local function slots() -- every Animation named Guns_Reload under Assets.Animations
	local Out = {}
	for _, A in ipairs(Anims:GetDescendants()) do
		if A:IsA("Animation") and A.Name == NAME then table.insert(Out, A) end
	end
	return Out
end
local function marked() -- the slots this script made
	local Out = {}
	for _, A in ipairs(slots()) do if A:GetAttribute(MARK) == true then table.insert(Out, A) end end
	return Out
end

-- ------------------------------------------------------------------ check (a failure list)
local function checks()
	local Fails, Passes, Out = 0, 0, {}
	local function cond(Failed, What)
		if Failed then Fails += 1 table.insert(Out, "  FAIL " .. What) else Passes += 1 end
	end
	local L = slots()
	cond(#L ~= 1, #L .. " Animations named " .. NAME .. " under Assets.Animations, not 1")
	local A = L[1]
	if A then
		cond(not A:IsDescendantOf(Weapons), A:GetFullName() .. " isn't under Assets.Animations.Weapons")
		cond(A.Parent ~= Guns, A:GetFullName() .. " isn't in Weapons.Guns")
		cond(#A:GetChildren() > 0, A:GetFullName() .. " has " .. #A:GetChildren() .. " children")
		cond(A.AnimationId ~= WANT_ID, A:GetFullName() .. ".AnimationId is " .. ("%q"):format(A.AnimationId) .. ", not " .. WANT_ID)
		cond(A:GetAttribute(MARK) ~= true, A:GetFullName() .. " doesn't carry " .. MARK)
	end
	cond(Anims:GetAttribute(FLAG) ~= WANT_ID, FLAG .. " is " .. tostring(Anims:GetAttribute(FLAG)) .. ", not " .. WANT_ID)
	return Fails, ("check: PASS %d / FAIL %d"):format(Passes, Fails), Out
end

-- ------------------------------------------------------------------ snapshot (test mode)
local function snapshot()
	local Rows = {}
	local A = {}
	for K, V in pairs(Anims:GetAttributes()) do table.insert(A, K .. "=" .. tostring(V)) end
	table.sort(A)
	table.insert(Rows, "#Animations " .. table.concat(A, ","))
	local C = {}
	for _, X in ipairs(Guns:GetChildren()) do table.insert(C, X.Name .. "[" .. X.ClassName .. "]") end
	table.sort(C)
	table.insert(Rows, "#Guns " .. #C .. " " .. table.concat(C, ","))
	for _, X in ipairs(slots()) do table.insert(Rows, "#slot " .. X:GetFullName() .. " " .. X.AnimationId) end
	table.insert(Rows, "#Animations descendants " .. #Anims:GetDescendants())
	return table.concat(Rows, "\n")
end

-- ------------------------------------------------------------------ apply / undo
local function locked()
	if RunService:IsRunning() then return "Play is running" end
	local L = SS:GetAttribute("PlayLock")
	if L ~= nil then return "PlayLock is set (" .. tostring(L) .. ")" end
	return nil
end

local function apply()
	local Lk = locked()
	if Lk then return false, Lk end
	if Anims:GetAttribute(FLAG) ~= nil then return false, "already applied (" .. FLAG .. " is " .. tostring(Anims:GetAttribute(FLAG)) .. ")" end
	local L = slots()
	if #L > 0 then return false, L[1]:GetFullName() .. " already exists (" .. #L .. " Animations named " .. NAME .. ")" end
	local Journal = {}
	local Rec
	pcall(function() Rec = CHS:TryBeginRecording("Gun rework reload slot apply") end)
	local Made
	local Ok, Err = pcall(function()
		Made = Instance.new("Animation")
		Made.Name = NAME
		Made.AnimationId = WANT_ID
		Made:SetAttribute(MARK, true)
		table.insert(Journal, {"inst", Made}) -- (journalled before it is parented)
		Made.Parent = Guns
		table.insert(Journal, {"flag"}) -- (the flag's journal entry before the flag)
		Anims:SetAttribute(FLAG, WANT_ID)
	end)
	if not Ok then
		for I = #Journal, 1, -1 do
			local J = Journal[I]
			pcall(function()
				if J[1] == "inst" then J[2]:Destroy()
				elseif J[1] == "flag" then Anims:SetAttribute(FLAG, nil) end
			end)
		end
		if Rec then pcall(function() CHS:FinishRecording(Rec, Enum.FinishRecordingOperation.Cancel) end) end
		return false, "error: " .. tostring(Err) .. " (rolled back " .. #Journal .. " steps)"
	end
	if Rec then pcall(function() CHS:FinishRecording(Rec, Enum.FinishRecordingOperation.Commit) end)
	else pcall(function() CHS:SetWaypoint("Gun rework reload slot apply") end) end
	return true, ("applied: %s (AnimationId %s, %s); %s = %s"):format(Made:GetFullName(), Made.AnimationId, MARK, FLAG, tostring(Anims:GetAttribute(FLAG)))
end

local function undo()
	local Lk = locked()
	if Lk then return false, Lk end
	local Rec_ = Anims:GetAttribute(FLAG)
	local L = marked()
	for _, A in ipairs(L) do
		if A.AnimationId ~= Rec_ then
			return false, ("%s.AnimationId is %q, not the flag's recorded %s (changed since apply)"):format(A:GetFullName(), A.AnimationId, tostring(Rec_))
		end
	end
	local Rec
	pcall(function() Rec = CHS:TryBeginRecording("Gun rework reload slot undo") end)
	local Ok, Err = pcall(function()
		for _, A in ipairs(L) do A:Destroy() end
		Anims:SetAttribute(FLAG, nil)
	end)
	if Rec then pcall(function() CHS:FinishRecording(Rec, Ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel) end)
	elseif Ok then pcall(function() CHS:SetWaypoint("Gun rework reload slot undo") end) end
	if not Ok then return false, "error: " .. tostring(Err) end
	return true, ("undone: %d slot(s) carrying %s destroyed; %s cleared"):format(#L, MARK, FLAG)
end

-- ------------------------------------------------------------------ run
local Out = {}
local Where = PLACES[game.PlaceId]
if MODE == "plan" then
	local L = slots()
	local Names = {}
	for _, A in ipairs(L) do table.insert(Names, A:GetFullName() .. " " .. ("%q"):format(A.AnimationId) .. (A:GetAttribute(MARK) and " (" .. MARK .. ")" or "")) end
	table.insert(Out, ("reload_slot plan (%s): %s is %s; %d Guns_Reload [%s]; Guns has %d children; PlayLock %s; apply would make %s.%s with AnimationId %s, %s = true, and set %s = %s"):format(
		Where, FLAG, tostring(Anims:GetAttribute(FLAG)), #L, table.concat(Names, "; "), #Guns:GetChildren(),
		tostring(SS:GetAttribute("PlayLock")), Guns:GetFullName(), NAME, WANT_ID, MARK, FLAG, WANT_ID))
elseif MODE == "apply" then
	local Ok, Msg = apply()
	if not Ok then return refuse(Msg) end
	local _, Head, Lines = checks()
	table.insert(Out, "reload_slot apply (" .. Where .. "): " .. Msg)
	table.insert(Out, Head)
	for _, L in ipairs(Lines) do table.insert(Out, L) end
elseif MODE == "undo" then
	local Ok, Msg = undo()
	if not Ok then return refuse(Msg) end
	table.insert(Out, "reload_slot undo (" .. Where .. "): " .. Msg)
elseif MODE == "check" then
	local _, Head, Lines = checks()
	table.insert(Out, "reload_slot " .. Head .. " (" .. Where .. "; " .. FLAG .. " is " .. tostring(Anims:GetAttribute(FLAG)) .. ")")
	for _, L in ipairs(Lines) do table.insert(Out, L) end
elseif MODE == "test" then
	if Anims:GetAttribute(FLAG) ~= nil then return refuse("applied; undo first or run check") end
	local Before = snapshot()
	local Ok, Msg = apply()
	if not Ok then return refuse(Msg) end
	local COk, Fails, Head, Lines = pcall(checks)
	local PUOk, UOk, UMsg = pcall(undo)
	if not PUOk then UOk, UMsg = false, "error: " .. tostring(UOk) end
	local SOk, After = pcall(snapshot)
	table.insert(Out, ("reload_slot test (%s): %s; %s; %s; round trip %s (%d chars)"):format(Where, Msg,
		COk and Head or ("CHECK ERROR: " .. tostring(Fails)), UOk and UMsg or ("UNDO FAILED: " .. tostring(UMsg)),
		SOk and (Before == After and "EXACT" or "DIFFERS") or ("SNAPSHOT ERROR: " .. tostring(After)), #Before))
	if COk then for _, L in ipairs(Lines) do table.insert(Out, L) end end
	if SOk and Before ~= After then table.insert(Out, "  before:\n" .. Before .. "\n  after:\n" .. After) end
else
	return refuse("unknown MODE " .. tostring(MODE))
end
return table.concat(Out, "\n")

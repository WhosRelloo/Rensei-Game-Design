--!nocheck
-- anim_slots.lua: swim revamp Task 4 (2026-10-26), with the owner's update of 2026-10-25 ("Use placeholders for the
-- other 2 animations"; climbing out uses the ledge climb, Vault1 / Vault2; the underwater idle is Swim_Idle). It adds
-- TWO animation slots to ReplicatedStorage.Assets.Animations.Shared.Movement.Swim, FILLED with placeholders:
--   Swim_Dive     copies Swim_Forward's AnimationId (the controller pitches the body down while it plays)
--   Swim_Surface  copies Swim_Idle's AnimationId (played once, briefly)
-- Each carries Placeholder = true, Copies = <the animation it copies> and SwimSlotAdd = true. To swap in a real
-- animation later: paste its id into the slot's AnimationId and clear Placeholder. No code changes.
-- AnimationManager keys animations by NAME across all of Assets.Animations, so apply refuses if either name exists.
-- Assets is a Package in both places: the owner publishes it with the others (World Travel.md section 10).
-- Runs in Ye (106992859583940) or Foundry Yard (109591196441030), Edit only:
--   python -I Art/Tools/rbxc.py luau "placeId: <id>" Edit @Art/Studio/Swim/anim_slots.lua
-- To run another MODE, copy this file to a scratch folder and change only the MODE line there.
-- MODE = "plan"   read-only: the folder, the two names, the ids they would copy.
-- MODE = "apply"  refuses (changing nothing) when the flag SwimAnimSlots is set on the folder, while Play runs, while
--                 this place's ServerStorage PlayLock is set, or when either name exists anywhere under
--                 Assets.Animations. (A Foundry run: the runner first checks Ye's PlayLock is nil.) Records the folder's
--                 other children (name and id) in the attribute SwimAnimSlotsBase. One ChangeHistory recording; an
--                 error mid-way is rolled back.
-- MODE = "undo"   refuses while Play runs or PlayLock is set. Deletes exactly the SwimSlotAdd slots and clears the
--                 flags, but refuses (naming it) if a slot no longer holds its placeholder (the owner pasted a real id
--                 and cleared Placeholder): an owner's upload is never deleted.
-- MODE = "check"  read-only, failure conditions only: both slots exist once, as Animations with SwimSlotAdd; while
--                 Placeholder is true each holds exactly its source's current id, else an rbxassetid://<digits> id;
--                 Copies names the source; the folder's other children equal SwimAnimSlotsBase. "PASS n / FAIL n".
-- MODE = "test"   (only while not applied) snapshot -> apply -> check -> undo -> snapshot equal.
local MODE = "plan" -- "plan", "apply", "undo", "check" or "test"

local CHS = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local FLAG, BASE, MARK = "SwimAnimSlots", "SwimAnimSlotsBase", "SwimSlotAdd"
local SLOTS = {
	{Name = "Swim_Dive", Copies = "Swim_Forward"},
	{Name = "Swim_Surface", Copies = "Swim_Idle"},
}

local function refuse(why) return "anim_slots " .. MODE .. " REFUSED: " .. why end
if game.PlaceId ~= 106992859583940 and game.PlaceId ~= 109591196441030 then return refuse("not Ye or Foundry Yard") end
if RunService:IsRunning() then return refuse("Play is running; Edit only") end
local RS = game:GetService("ReplicatedStorage")
local Anims = RS:FindFirstChild("Assets") and RS.Assets:FindFirstChild("Animations")
local Dir = Anims and Anims:FindFirstChild("Shared") and Anims.Shared:FindFirstChild("Movement")
	and Anims.Shared.Movement:FindFirstChild("Swim")
if not Dir then return refuse("no Assets.Animations.Shared.Movement.Swim") end

local function byName(Name)
	local L = {}
	for _, D in ipairs(Anims:GetDescendants()) do if D.Name == Name then table.insert(L, D) end end
	return L
end
local function source(Name) local S = Dir:FindFirstChild(Name) return S and S:IsA("Animation") and S or nil end
local function others()
	local L = {}
	for _, C in ipairs(Dir:GetChildren()) do
		if C:GetAttribute(MARK) ~= true then
			table.insert(L, C.Name .. "|" .. C.ClassName .. "|" .. (C:IsA("Animation") and C.AnimationId or ""))
		end
	end
	table.sort(L)
	return L
end
local function locked() return game:GetService("ServerStorage"):GetAttribute("PlayLock") end

local function checks()
	local Out, Fails, Passes = {}, 0, 0
	local function line(ok, s) if ok then Passes += 1 else Fails += 1 table.insert(Out, "  FAIL " .. s) end end
	for _, S in ipairs(SLOTS) do
		local L = byName(S.Name)
		line(#L == 1, S.Name .. ": exactly one under Assets.Animations (" .. #L .. ")")
		local A = L[1]
		if A then
			line(A.Parent == Dir and A:IsA("Animation") and A:GetAttribute(MARK) == true, S.Name .. ": an Animation in Swim with " .. MARK)
			line(A:GetAttribute("Copies") == S.Copies, S.Name .. ": Copies = " .. S.Copies)
			if A:GetAttribute("Placeholder") == true then
				local Src = source(S.Copies)
				line(Src ~= nil and A.AnimationId == Src.AnimationId and A.AnimationId ~= "", S.Name .. ": the placeholder holds " .. S.Copies .. "'s id (" .. A.AnimationId .. ")")
			else
				line(A.AnimationId:match("^rbxassetid://%d+$") ~= nil, S.Name .. ": an uploaded id (" .. A.AnimationId .. ")")
			end
		end
	end
	local Base = Dir:GetAttribute(BASE)
	line(Base ~= nil and Base == HttpService:JSONEncode(others()), "the folder's other children are as at apply")
	return Fails, Passes, Out
end

local function snapshot()
	local Rows = {}
	for _, C in ipairs(Dir:GetChildren()) do
		local A = {}
		for K, V in pairs(C:GetAttributes()) do table.insert(A, K .. "=" .. tostring(V)) end
		table.sort(A)
		table.insert(Rows, C.Name .. "|" .. C.ClassName .. "|" .. (C:IsA("Animation") and C.AnimationId or "") .. "|" .. table.concat(A, ","))
	end
	table.sort(Rows)
	local F = {}
	for K, V in pairs(Dir:GetAttributes()) do table.insert(F, K .. "=" .. tostring(V)) end
	table.sort(F)
	return table.concat(Rows, "\n") .. "\n#" .. #Anims:GetDescendants() .. "\n" .. table.concat(F, ",")
end

local function recorded(Name, Fn)
	local Rec
	pcall(function() Rec = CHS:TryBeginRecording(Name) end)
	local Ok, Err = pcall(Fn)
	if Rec then pcall(function() CHS:FinishRecording(Rec, Ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel) end)
	else pcall(function() CHS:SetWaypoint(Name) end) end
	if not Ok then error(Err, 0) end
end

local function apply()
	if Dir:GetAttribute(FLAG) then return false, "already applied (" .. FLAG .. " is set)" end
	if locked() then return false, "PlayLock is " .. tostring(locked()) end
	for _, S in ipairs(SLOTS) do
		if #byName(S.Name) > 0 then return false, S.Name .. " already exists under Assets.Animations" end
		local Src = source(S.Copies)
		if not Src or Src.AnimationId == "" then return false, "no " .. S.Copies .. " with an id to copy" end
	end
	local Made = {}
	local Ok, Err = pcall(function()
		recorded("Swim anim slots apply", function()
			local Base = HttpService:JSONEncode(others())
			for _, S in ipairs(SLOTS) do
				local A = Instance.new("Animation")
				A.Name = S.Name
				A.AnimationId = source(S.Copies).AnimationId
				A:SetAttribute("Placeholder", true)
				A:SetAttribute("Copies", S.Copies)
				A:SetAttribute(MARK, true)
				A.Parent = Dir
				table.insert(Made, A)
			end
			Dir:SetAttribute(BASE, Base)
			Dir:SetAttribute(FLAG, true)
		end)
	end)
	if not Ok then
		for _, A in ipairs(Made) do pcall(function() A:Destroy() end) end
		pcall(function() Dir:SetAttribute(FLAG, nil) Dir:SetAttribute(BASE, nil) end)
		return false, "error, undone: " .. tostring(Err)
	end
	return true, ("added %d placeholder slots"):format(#Made)
end

local function undo()
	if locked() then return false, "PlayLock is " .. tostring(locked()) end
	local L = {}
	for _, C in ipairs(Dir:GetChildren()) do
		if C:GetAttribute(MARK) == true then
			local Src = source(C:GetAttribute("Copies") or "")
			if C:GetAttribute("Placeholder") ~= true or not Src or C.AnimationId ~= Src.AnimationId then
				return false, C.Name .. " no longer holds its placeholder (an owner upload?): not deleted"
			end
			table.insert(L, C)
		end
	end
	recorded("Swim anim slots undo", function()
		for _, C in ipairs(L) do C:Destroy() end
		Dir:SetAttribute(FLAG, nil)
		Dir:SetAttribute(BASE, nil)
	end)
	return true, ("removed %d slots"):format(#L)
end

local Out = {"anim_slots " .. MODE .. " (place " .. game.PlaceId .. ")"}
if MODE == "plan" then
	table.insert(Out, "folder " .. Dir:GetFullName() .. ", flag " .. tostring(Dir:GetAttribute(FLAG)))
	for _, S in ipairs(SLOTS) do
		local Src = source(S.Copies)
		table.insert(Out, ("%s: %d existing; would copy %s (%s)"):format(S.Name, #byName(S.Name), S.Copies, Src and Src.AnimationId or "MISSING"))
	end
	table.insert(Out, "other children: " .. table.concat(others(), "; "))
elseif MODE == "apply" then
	local Ok, Why = apply()
	if not Ok then return refuse(Why) end
	local Fails, Passes, Lines = checks()
	table.insert(Out, Why .. "; check PASS " .. Passes .. " / FAIL " .. Fails)
	for _, L in ipairs(Lines) do table.insert(Out, L) end
elseif MODE == "undo" then
	local Ok, Why = undo()
	if not Ok then return refuse(Why) end
	table.insert(Out, Why)
elseif MODE == "check" then
	local Fails, Passes, Lines = checks()
	table.insert(Out, "PASS " .. Passes .. " / FAIL " .. Fails)
	for _, L in ipairs(Lines) do table.insert(Out, L) end
elseif MODE == "test" then
	if Dir:GetAttribute(FLAG) then return refuse("test only while not applied") end
	local Before = snapshot()
	local Ok, Why = apply()
	if not Ok then return refuse("apply: " .. Why) end
	local Fails, Passes = checks()
	local UOk, UWhy = undo()
	local After = snapshot()
	table.insert(Out, ("apply: %s; check PASS %d / FAIL %d; undo: %s; snapshots equal: %s"):format(Why, Passes, Fails,
		tostring(UWhy), tostring(Before == After)))
	if not UOk or Before ~= After or Fails > 0 then table.insert(Out, "TEST FAILED") end
else
	return refuse("unknown MODE")
end
return table.concat(Out, "\n")

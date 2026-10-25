--!nocheck
-- hide_anvil.lua: Foundry Yard game-data plan Task 9 (Ruling 35). The great hall's shell has a cover anvil in each forge
-- room, GreatHall_great_hall.ForgeFloorAnvil and .SilentForgeAnvil (3 x 2.6 x 1.6, solid). Measured 2026-10-25 in
-- Foundry's Edit session: ForgeFloorAnvil stands at (325, 6, -360.5), 4.0 studs (flat) from the metal_experiment
-- TrialMarker (325, 5.2, -364.5), inside the trial's FoeDistance 14 and its Radius 24, and its box (z -361.3..-359.7)
-- overlaps the spot Play_FoundryForge's trial tests put the player (3 studs +Z of the marker, z -361.5, a 2 x 2 root):
-- it obstructs the arena. Nothing else colliding stands within 14 studs of the marker at body height (the hearth is 19.3
-- off, the side walls 20.2). So it is hidden, reversibly: Transparency 1, CanCollide, CanQuery, CanTouch and
-- CastShadow off. It is not moved or destroyed (the builder made it: a re-import brings it back as it was).
-- SilentForgeAnvil (373, 6, -360.5) is NOT changed: it stands in the workshop beside the kit's own Anvil
-- (ForgeRooms.SilentForge.Anvil, (377, 5.9, -366)), a duplicate listed for the owner's eye, and check asserts it is as
-- measured.
-- Runs in Foundry (placeId 109591196441030), Edit only, with Ye's ServerStorage PlayLock nil (read it first):
--   python -I Art/Tools/rbxc.py luau "placeId: 109591196441030" Edit @<a scratch copy with its MODE line set>
-- MODE = "plan"   read-only: the two anvils as they are, and what apply would change.
-- MODE = "apply"  refuses, changing nothing, while Play runs, while this place's PlayLock is set, when Map.Foundry has
--                 FoundryAnvil, when anything carries FoundryAnvilFrom, or when ForgeFloorAnvil is not exactly one part
--                 where it was measured or is hidden already. Then, in a pcall with a journal (an error half-way is
--                 rolled back) and one ChangeHistory recording (cancelled on an error): writes FoundryAnvilFrom (its
--                 five old values, JSON), hides it, then sets Map.Foundry's FoundryAnvil = "applied"; then runs check.
-- MODE = "undo"   (refuses while Play runs or PlayLock is set) puts every FoundryAnvilFrom part's five values back,
--                 clears the attribute and FoundryAnvil. No later fix builds on this one: nothing guards it.
-- MODE = "check"  read-only failure list (against the measured values below, never against what it reads from the
--                 anvil's own mark): FoundryAnvil not "applied"; ForgeFloorAnvil not where it was measured, not
--                 hidden (Transparency 1, CanCollide, CanQuery, CanTouch, CastShadow off) or without FoundryAnvilFrom;
--                 its FoundryAnvilFrom not the measured old values; SilentForgeAnvil changed (place, size, Transparency,
--                 CanCollide). Returns PASS n / FAIL n.
-- MODE = "test"   (only while not applied) snapshot -> apply -> check -> undo -> snapshot; the two must be equal. The
--                 check, the undo and the snapshot run inside pcalls, so an error between apply and undo still undoes.
-- import/restore.lua refuses while FoundryAnvil is set (the region file's RestoreRefuseFlags).
local MODE = "plan" -- "plan", "apply", "undo", "check" or "test"

local CHS = game:GetService("ChangeHistoryService")
local HS = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local SS = game:GetService("ServerStorage")

local FLAG, FROM = "FoundryAnvil", "FoundryAnvilFrom"
local HIDE, KEEP = "ForgeFloorAnvil", "SilentForgeAnvil"
-- measured 2026-10-25 in Foundry's Edit session
local HIDE_AT, KEEP_AT = Vector3.new(325, 6, -360.5), Vector3.new(373, 6, -360.5)
local SIZE = Vector3.new(3, 2.6, 1.6)
local WAS = {Transparency = 0, CanCollide = true, CanQuery = true, CanTouch = true, CastShadow = true} -- (both anvils)
local HIDDEN = {Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false}
local PROPS = {"Transparency", "CanCollide", "CanQuery", "CanTouch", "CastShadow"}

local function refuse(why) return "hide_anvil " .. MODE .. " REFUSED: " .. why end
if game.PlaceId ~= 109591196441030 then return refuse("this is not Foundry") end
if RunService:IsRunning() then return refuse("Play is running; Edit only") end
local Map = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map")
local FD = Map and Map:FindFirstChild("Foundry")
if not FD then return refuse("no World.Map.Foundry") end
local GH = FD:FindFirstChild("Landmarks") and FD.Landmarks:FindFirstChild("GreatHall_great_hall")
if not GH then return refuse("no Map.Foundry.Landmarks.GreatHall_great_hall") end
local function only(Name)
	local N, Found = 0, nil
	for _, C in ipairs(GH:GetChildren()) do
		if C.Name == Name then N += 1 Found = C end
	end
	return (N == 1 and Found:IsA("BasePart")) and Found or nil, N
end
local Hide, NH = only(HIDE)
local Keep, NK = only(KEEP)
if not Hide then return refuse(("GreatHall_great_hall.%s: %d parts, not 1"):format(HIDE, NH)) end
if not Keep then return refuse(("GreatHall_great_hall.%s: %d parts, not 1"):format(KEEP, NK)) end

local function f1(v) return ("(%.2f, %.2f, %.2f)"):format(v.X, v.Y, v.Z) end
local function values(P)
	local V = {}
	for _, K in ipairs(PROPS) do V[K] = P[K] end
	return V
end
local function same(A, B)
	for _, K in ipairs(PROPS) do
		if type(A[K]) == "number" then
			if math.abs(A[K] - B[K]) > 1e-3 then return false end
		elseif A[K] ~= B[K] then return false end
	end
	return true
end
local function show(V)
	local L = {}
	for _, K in ipairs(PROPS) do table.insert(L, K .. "=" .. tostring(V[K])) end
	return table.concat(L, " ")
end
local function at(P, Want) return (P.Position - Want).Magnitude <= 0.05 and (P.Size - SIZE).Magnitude <= 0.05 end

-- ------------------------------------------------------------------ check (a failure list)
local function checks()
	local Fails, Passes, Out = 0, 0, {}
	local function cond(Failed, What)
		if Failed then Fails += 1 table.insert(Out, "  FAIL " .. What) else Passes += 1 end
	end
	cond(FD:GetAttribute(FLAG) ~= "applied", FLAG .. " is " .. tostring(FD:GetAttribute(FLAG)) .. ", not applied")
	cond(not at(Hide, HIDE_AT), HIDE .. " is at " .. f1(Hide.Position) .. " size " .. f1(Hide.Size) .. ", not as measured")
	cond(not same(values(Hide), HIDDEN), HIDE .. " is not hidden: " .. show(values(Hide)))
	local J = Hide:GetAttribute(FROM)
	local Ok, Old = pcall(HS.JSONDecode, HS, J or "")
	cond(not (Ok and type(Old) == "table"), HIDE .. " carries no " .. FROM .. " (JSON)")
	if Ok and type(Old) == "table" then cond(not same(Old, WAS), HIDE .. "'s " .. FROM .. " is not the measured old values: " .. tostring(J)) end
	cond(not at(Keep, KEEP_AT), KEEP .. " moved: " .. f1(Keep.Position) .. " size " .. f1(Keep.Size))
	cond(not same(values(Keep), WAS), KEEP .. " changed: " .. show(values(Keep)))
	cond(Keep:GetAttribute(FROM) ~= nil, KEEP .. " carries " .. FROM)
	return Fails, ("check: PASS %d / FAIL %d"):format(Passes, Fails), Out
end

-- ------------------------------------------------------------------ snapshot (test mode)
local function snapshot()
	local Rows = {}
	for _, P in ipairs({Hide, Keep}) do
		local C = {P.CFrame:GetComponents()}
		for K = 1, 12 do C[K] = ("%.3f"):format(C[K]) end
		local A = {}
		for K, V in pairs(P:GetAttributes()) do table.insert(A, K .. "=" .. tostring(V)) end
		table.sort(A)
		table.insert(Rows, P:GetFullName() .. "|" .. table.concat(C, ",") .. "|" .. show(values(P)) .. "|" .. table.concat(A, ","))
	end
	local A = {}
	for K, V in pairs(FD:GetAttributes()) do table.insert(A, K .. "=" .. tostring(V)) end
	table.sort(A)
	table.insert(Rows, "#Map.Foundry " .. table.concat(A, ","))
	local N = 0
	for _, I in ipairs(FD:GetDescendants()) do if I:GetAttribute(FROM) ~= nil then N += 1 end end
	table.insert(Rows, "#" .. FROM .. " " .. N)
	return table.concat(Rows, "\n")
end

-- ------------------------------------------------------------------ apply / undo
local function locked()
	if RunService:IsRunning() then return "Play is running" end
	local L = SS:GetAttribute("PlayLock")
	if L ~= nil then return "PlayLock is set (" .. tostring(L) .. ")" end
	return nil
end
local function marked()
	local Out = {}
	for _, I in ipairs(FD:GetDescendants()) do if I:GetAttribute(FROM) ~= nil then table.insert(Out, I) end end
	return Out
end

local function apply()
	local Lk = locked()
	if Lk then return false, Lk end
	if FD:GetAttribute(FLAG) ~= nil then return false, "already applied (" .. FLAG .. " is " .. tostring(FD:GetAttribute(FLAG)) .. ")" end
	if #marked() > 0 then return false, #marked() .. " instances still carry " .. FROM .. " (undo first)" end
	if not at(Hide, HIDE_AT) then return false, HIDE .. " is not where it was measured (" .. f1(Hide.Position) .. ")" end
	if not same(values(Hide), WAS) then return false, HIDE .. " is not as measured: " .. show(values(Hide)) end
	local Journal = {}
	local Rec
	pcall(function() Rec = CHS:TryBeginRecording("Foundry hide anvil apply") end)
	local Ok, Err = pcall(function()
		local Old = values(Hide)
		table.insert(Journal, {"part", Hide, Old}) -- (journalled before the change: Ruling 26)
		Hide:SetAttribute(FROM, HS:JSONEncode(Old))
		for K, V in pairs(HIDDEN) do Hide[K] = V end
		table.insert(Journal, {"flag"}) -- (Ruling 35: the flag's journal entry before the flag)
		FD:SetAttribute(FLAG, "applied")
	end)
	if not Ok then
		for I = #Journal, 1, -1 do
			local J = Journal[I]
			pcall(function()
				if J[1] == "part" then
					for K, V in pairs(J[3]) do J[2][K] = V end
					J[2]:SetAttribute(FROM, nil)
				elseif J[1] == "flag" then FD:SetAttribute(FLAG, nil) end
			end)
		end
		if Rec then pcall(function() CHS:FinishRecording(Rec, Enum.FinishRecordingOperation.Cancel) end) end
		return false, "error: " .. tostring(Err) .. " (rolled back " .. #Journal .. " steps)"
	end
	if Rec then pcall(function() CHS:FinishRecording(Rec, Enum.FinishRecordingOperation.Commit) end)
	else pcall(function() CHS:SetWaypoint("Foundry hide anvil apply") end) end
	return true, ("applied: %s at %s hidden (%s)"):format(HIDE, f1(Hide.Position), show(values(Hide)))
end

local function undo()
	local Lk = locked()
	if Lk then return false, Lk end
	local L = marked()
	local Plan = {}
	for _, I in ipairs(L) do
		local Ok, Old = pcall(HS.JSONDecode, HS, I:GetAttribute(FROM))
		if not (Ok and type(Old) == "table" and I:IsA("BasePart")) then return false, I:GetFullName() .. "'s " .. FROM .. " is not a JSON table on a part" end
		table.insert(Plan, {I, Old})
	end
	local Rec
	pcall(function() Rec = CHS:TryBeginRecording("Foundry hide anvil undo") end)
	local Ok, Err = pcall(function()
		for _, X in ipairs(Plan) do
			for _, K in ipairs(PROPS) do if X[2][K] ~= nil then X[1][K] = X[2][K] end end
			X[1]:SetAttribute(FROM, nil)
		end
		FD:SetAttribute(FLAG, nil)
	end)
	if Rec then pcall(function() CHS:FinishRecording(Rec, Ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel) end)
	elseif Ok then pcall(function() CHS:SetWaypoint("Foundry hide anvil undo") end) end
	if not Ok then return false, "error: " .. tostring(Err) end
	return true, ("undone: %d parts shown as they were; %s cleared"):format(#Plan, FLAG)
end

-- ------------------------------------------------------------------ run
local Out = {}
if MODE == "plan" then
	table.insert(Out, ("hide_anvil plan: %s is %s; %s at %s size %s [%s]; %s at %s size %s [%s]; apply would hide %s (%s)"):format(
		FLAG, tostring(FD:GetAttribute(FLAG)), HIDE, f1(Hide.Position), f1(Hide.Size), show(values(Hide)),
		KEEP, f1(Keep.Position), f1(Keep.Size), show(values(Keep)), HIDE, show(HIDDEN)))
elseif MODE == "apply" then
	local Ok, Msg = apply()
	if not Ok then return refuse(Msg) end
	local _, Head, Lines = checks()
	table.insert(Out, "hide_anvil apply: " .. Msg)
	table.insert(Out, Head)
	for _, L in ipairs(Lines) do table.insert(Out, L) end
elseif MODE == "undo" then
	local Ok, Msg = undo()
	if not Ok then return refuse(Msg) end
	table.insert(Out, "hide_anvil undo: " .. Msg)
elseif MODE == "check" then
	local _, Head, Lines = checks()
	table.insert(Out, "hide_anvil " .. Head .. " (" .. FLAG .. " is " .. tostring(FD:GetAttribute(FLAG)) .. ")")
	for _, L in ipairs(Lines) do table.insert(Out, L) end
elseif MODE == "test" then
	if FD:GetAttribute(FLAG) ~= nil then return refuse("applied; undo first or run check") end
	local Before = snapshot()
	local Ok, Msg = apply()
	if not Ok then return refuse(Msg) end
	local COk, Fails, Head, Lines = pcall(checks)
	local PUOk, UOk, UMsg = pcall(undo)
	if not PUOk then UOk, UMsg = false, "error: " .. tostring(UOk) end
	local SOk, After = pcall(snapshot)
	table.insert(Out, ("hide_anvil test: %s %s; %s; round trip %s (%d chars)"):format(Msg,
		COk and Head or ("CHECK ERROR: " .. tostring(Fails)), UOk and UMsg or ("UNDO FAILED: " .. tostring(UMsg)),
		SOk and (Before == After and "EXACT" or "DIFFERS") or ("SNAPSHOT ERROR: " .. tostring(After)), #Before))
	if COk then for _, L in ipairs(Lines) do table.insert(Out, L) end end
	if SOk and Before ~= After then table.insert(Out, "  before:\n" .. Before .. "\n  after:\n" .. After) end
else
	return refuse("unknown MODE " .. tostring(MODE))
end
return table.concat(Out, "\n")

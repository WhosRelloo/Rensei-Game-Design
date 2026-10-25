--!nocheck
-- walk_fixes.lua: Foundry Yard game-data plan Task 4b (Rulings 27b, 30). The townsfolk Mover now repairs paths that
-- cut corners (Mover.lua, header 1b), but one squeeze is in the map itself: the crate stack Cover_yard_spine_west_2_0
-- stands in the middle of the 11-stud alley between House_spine_west_11 (its wall at z -303) and House_spine_west_12
-- (its wall at z -292, back-door leaf to -292.3), leaving 2.55 studs on the north side and 2.25 on the south. Six
-- canteen walks (crane_bay_1, furnace_1, furnace_2, furnace_3, hall_gantry and casting_floor to the canteen seats) run
-- through the north gap (measured 2026-10-25: corridor 2.45-2.49, against the 3.2 the walks need).
--   (a) the stack moves 2 studs +Z (Foundry's south: north is -Z): 4.55 studs from House_spine_west_11, and the south
--       gap shuts (0.25 to the back-door leaf, which it doesn't cover: the door is at x 29.9..33.1, the crates start at
--       x 33.5). The brief said "about 3 studs north (-Z)", but House_spine_west_11 IS the north side: -Z closes on it,
--       and 3 studs +Z would overlap House_spine_west_12. Measured with the repaired Mover in Edit: all 70 schedule
--       changes then pass Test_FoundryPaths' checks (the six canteen walks at corridor 4.45).
--   (b) the boiler Cover_freight_path_32 (-500, 93) was measured and is NOT moved: no colliding part stands within 10
--       studs of it at body height, and pair #66 (runner_2, lower_home_2 -> errand_row) now plans at radius 2.5 with a
--       corridor that is never boxed in (the investigation's failure there was the old Mover's corner cut, which the
--       repair fixes). The check below asserts it is where it was.
--   (c) the four trader stalls (MarketStall_stall_1, _3, _10, _12): each one's Counter and the three Goods on it slide
--       SLIDE (0.6) studs toward the stall's front posts (the counter's own -Z). Every stall has the same layout: its
--       side entries, between the counter's back and the back corner posts, were 2.7 studs, and trader_3 leaving
--       stall_10 got stuck in one (Play_FoundryWalks, 2026-10-25); they are 3.3 now (the investigation's "widen the
--       stall side entries"). The counter still holds its front posts; the trader's own space grows from 2.3 to 2.9.
-- Runs in Foundry (placeId 109591196441030), Edit only, with Ye's ServerStorage PlayLock nil (read it first):
--   python -I Art/Tools/rbxc.py luau "placeId: 109591196441030" Edit @Art/Studio/Regions/Foundry/walk_fixes.lua
-- MODE = "plan"   read-only: the stack's gaps now and where it would go.
-- MODE = "apply"  refuses, changing nothing, while Play runs, while this place's PlayLock is set, when Map.Foundry has
--                 FoundryWalks, when anything carries FoundryWalkFrom, or when the stack, the boiler or a stall's
--                 counter is not where it was measured. Then, in a pcall with a journal (an error half-way is rolled
--                 back) and one ChangeHistory recording (cancelled on an error): (a), (c), then Map.Foundry's
--                 FoundryWalks = "applied", then check. The moved model and parts carry FoundryWalkFrom (the old pivot
--                 or CFrame, a CFrame attribute: its 12 numbers).
-- MODE = "undo"   (refuses while Play runs or PlayLock is set) puts every FoundryWalkFrom model and part back where it
--                 was, clears the attribute and FoundryWalks. No later fix builds on this one: nothing guards it.
-- MODE = "check"  read-only failure list (against the measured baselines below, never against what it reads from
--                 the moved parts): FoundryWalks not "applied"; the stack not at its new pivot or without
--                 FoundryWalkFrom; its gap to House_spine_west_11 under 3.2; a crate overlapping another colliding part;
--                 the boiler moved; a stall's counter not SLIDE from its measured spot, a sliding part without
--                 FoundryWalkFrom, a side entry under 3.2, or a counter or goods part overlapping a colliding part of
--                 anything but its own stall. Returns PASS n / FAIL n.
-- MODE = "test"   (only while not applied) snapshot -> apply -> check -> undo -> snapshot; the two must be equal. The
--                 check and the snapshot run inside a pcall, so an error between apply and undo still undoes.
-- import/restore.lua refuses while FoundryWalks is set (the region file's RestoreRefuseFlags).
local MODE = "plan" -- "plan", "apply", "undo", "check" or "test"

local CHS = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")
local SS = game:GetService("ServerStorage")

local FLAG, FROM = "FoundryWalks", "FoundryWalkFrom"
local STACK, HOUSE, BOILER = "Cover_yard_spine_west_2_0", "House_spine_west_11", "Cover_freight_path_32"
-- measured 2026-10-25 in Foundry's Edit session (Model:GetPivot())
local STACK_AT = Vector3.new(36.5, 4, -297.5)
local BOILER_AT = Vector3.new(-500, 4, 93)
local MOVE = Vector3.new(0, 0, 2) -- PROPOSAL (a): +Z, away from House_spine_west_11 (see the header)
local GAP = 3.2 -- the corridor the walks need (Task 4b brief)
-- (c) the trader stalls' counters, measured 2026-10-25 (X, Z; the counter's yaw)
local STALLS = {
	{Name = "MarketStall_stall_1", X = -250, Z = -313.6, Yaw = 0},
	{Name = "MarketStall_stall_3", X = -214, Z = -313.6, Yaw = 0},
	{Name = "MarketStall_stall_10", X = -232, Z = -346.4, Yaw = 180},
	{Name = "MarketStall_stall_12", X = -196, Z = -346.4, Yaw = 180},
}
local SLIDE = 0.6 -- PROPOSAL (c): toward the stall's front posts (the counter's -Z): side entries 2.7 -> 3.3
local SLIDING = {"Counter", "Goods0", "Goods1", "Goods2"}

local function refuse(why) return "walk_fixes " .. MODE .. " REFUSED: " .. why end
if game.PlaceId ~= 109591196441030 then return refuse("this is not Foundry") end
if RunService:IsRunning() then return refuse("Play is running; Edit only") end
local Map = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map")
local FD = Map and Map:FindFirstChild("Foundry")
if not FD then return refuse("no World.Map.Foundry") end
local Cover = FD:FindFirstChild("Cover")
local Buildings = FD:FindFirstChild("Buildings")
if not (Cover and Buildings) then return refuse("no Map.Foundry.Cover / Buildings") end

local function only(Parent, Name)
	local N, Found = 0, nil
	for _, C in ipairs(Parent:GetChildren()) do
		if C.Name == Name then N += 1 Found = C end
	end
	return N == 1 and Found or nil, N
end
local Stack, NS = only(Cover, STACK)
local Boiler, NB = only(Cover, BOILER)
local House, NH = only(Buildings, HOUSE)
if not (Stack and Stack:IsA("Model")) then return refuse(("Cover.%s: %d models, not 1"):format(STACK, NS)) end
if not (Boiler and Boiler:IsA("Model")) then return refuse(("Cover.%s: %d models, not 1"):format(BOILER, NB)) end
if not (House and House:IsA("Model") and House:FindFirstChild("Body")) then return refuse(("Buildings.%s: %d, not 1 with a Body"):format(HOUSE, NH)) end
local Body = House.Body
local Stalls = {}
for _, D in ipairs(STALLS) do
	local Found = {}
	for _, M in ipairs(FD:GetDescendants()) do
		if M:IsA("Model") and M.Name == D.Name then table.insert(Found, M) end
	end
	if #Found ~= 1 then return refuse(("%s: %d models, not 1"):format(D.Name, #Found)) end
	for _, N in ipairs(SLIDING) do
		if not (Found[1]:FindFirstChild(N) and Found[1][N]:IsA("BasePart")) then return refuse(D.Name .. " has no part " .. N) end
	end
	if not (Found[1]:FindFirstChild("Post-1+1") and Found[1]:FindFirstChild("Post+1+1")) then return refuse(D.Name .. " has no back posts") end
	Stalls[D.Name] = Found[1]
end

local function f1(v) return ("(%.2f, %.2f, %.2f)"):format(v.X, v.Y, v.Z) end

-- the world box of a part
local function box(P)
	local S, R, U, L = P.Size / 2, P.CFrame.RightVector, P.CFrame.UpVector, P.CFrame.LookVector
	local E = Vector3.new(math.abs(R.X) * S.X + math.abs(U.X) * S.Y + math.abs(L.X) * S.Z,
		math.abs(R.Y) * S.X + math.abs(U.Y) * S.Y + math.abs(L.Y) * S.Z,
		math.abs(R.Z) * S.X + math.abs(U.Z) * S.Y + math.abs(L.Z) * S.Z)
	return P.Position - E, P.Position + E
end
-- the stack's gap to House_spine_west_11's body (the clear studs between their boxes, along Z: the house is north)
local function houseGap()
	local Lo, Hi = box(Body)
	local Min = math.huge
	for _, P in ipairs(Stack:GetDescendants()) do
		if P:IsA("BasePart") and P.CanCollide then
			local PL = box(P)
			Min = math.min(Min, PL.Z - Hi.Z)
		end
	end
	return Min
end
-- colliding parts (outside the stack) that a crate overlaps
local op = OverlapParams.new()
op.FilterType = Enum.RaycastFilterType.Exclude
op.RespectCanCollide = true
local function overlaps()
	op.FilterDescendantsInstances = {Stack}
	local Out = {}
	for _, P in ipairs(Stack:GetDescendants()) do
		if P:IsA("BasePart") and P.CanCollide then
			for _, X in ipairs(workspace:GetPartsInPart(P, op)) do
				if not X:IsA("Terrain") then table.insert(Out, P.Name .. "/" .. X.Parent.Name .. "." .. X.Name) end
			end
		end
	end
	return Out
end

-- ------------------------------------------------------------------ check (a failure list)
local function checks()
	local Fails, Passes, Out = 0, 0, {}
	local function cond(Failed, What)
		if Failed then Fails += 1 table.insert(Out, "  FAIL " .. What) else Passes += 1 end
	end
	cond(FD:GetAttribute(FLAG) ~= "applied", FLAG .. " is " .. tostring(FD:GetAttribute(FLAG)) .. ", not applied")
	local At = Stack:GetPivot().Position
	cond((At - (STACK_AT + MOVE)).Magnitude > 0.05, STACK .. " is at " .. f1(At) .. ", not " .. f1(STACK_AT + MOVE))
	cond(typeof(Stack:GetAttribute(FROM)) ~= "CFrame", STACK .. " carries no " .. FROM)
	local G = houseGap()
	cond(G < GAP, ("%s is %.2f from %s.Body (under %.1f)"):format(STACK, G, HOUSE, GAP))
	local O = overlaps()
	cond(#O > 0, STACK .. " overlaps: " .. table.concat(O, ", "))
	cond((Boiler:GetPivot().Position - BOILER_AT).Magnitude > 0.05, BOILER .. " moved (" .. f1(Boiler:GetPivot().Position) .. ")")
	local Narrow = math.huge
	for _, D in ipairs(STALLS) do
		local M = Stalls[D.Name]
		local C = M.Counter
		local Want = Vector3.new(D.X, C.Position.Y, D.Z) + (CFrame.Angles(0, math.rad(D.Yaw), 0) * Vector3.new(0, 0, -SLIDE))
		cond(Vector3.new(C.Position.X - Want.X, 0, C.Position.Z - Want.Z).Magnitude > 0.05, D.Name .. ".Counter is at " .. f1(C.Position) .. ", not " .. f1(Want))
		for _, N in ipairs(SLIDING) do cond(typeof(M[N]:GetAttribute(FROM)) ~= "CFrame", D.Name .. "." .. N .. " carries no " .. FROM) end
		-- each side entry: from the counter's back face to the back corner post's front face, along the counter's Z
		for _, PN in ipairs({"Post-1+1", "Post+1+1"}) do
			local Post = M[PN]
			local W = (C.CFrame:PointToObjectSpace(Post.Position).Z - Post.Size.Z / 2) - C.Size.Z / 2
			Narrow = math.min(Narrow, W)
			cond(W < GAP, ("%s: side entry by %s is %.2f (under %.1f)"):format(D.Name, PN, W, GAP))
		end
		op.FilterDescendantsInstances = {M}
		for _, N in ipairs(SLIDING) do
			local Hit = {}
			for _, X in ipairs(workspace:GetPartsInPart(M[N], op)) do
				if not X:IsA("Terrain") then table.insert(Hit, X.Parent.Name .. "." .. X.Name) end
			end
			cond(#Hit > 0, D.Name .. "." .. N .. " overlaps " .. table.concat(Hit, ", "))
		end
	end
	return Fails, ("check: PASS %d / FAIL %d; gap to %s %.2f; narrowest stall side entry %.2f"):format(Passes, Fails, HOUSE, G, Narrow), Out
end

-- ------------------------------------------------------------------ snapshot (test mode)
local function r3(V) return math.floor(V * 1000 + 0.5) / 1000 end
local function snapshot()
	local Rows = {}
	local function attrs(I)
		local A = {}
		for K, V in pairs(I:GetAttributes()) do table.insert(A, K .. "=" .. tostring(V)) end
		table.sort(A)
		return table.concat(A, ",")
	end
	local Ms = {Stack, Boiler}
	for _, D in ipairs(STALLS) do table.insert(Ms, Stalls[D.Name]) end
	for _, M in ipairs(Ms) do
		table.insert(Rows, M:GetFullName() .. "|" .. attrs(M))
		for _, P in ipairs(M:GetDescendants()) do
			if P:IsA("BasePart") then
				local C = {P.CFrame:GetComponents()}
				for K = 1, 12 do C[K] = r3(C[K]) end
				table.insert(Rows, P:GetFullName() .. "|" .. table.concat(C, ",") .. "|" .. tostring(P.CanCollide) .. "|" .. attrs(P))
			end
		end
	end
	table.sort(Rows)
	table.insert(Rows, "#Map.Foundry " .. attrs(FD))
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
	if (Stack:GetPivot().Position - STACK_AT).Magnitude > 0.05 then return false, STACK .. " is not at " .. f1(STACK_AT) end
	if (Boiler:GetPivot().Position - BOILER_AT).Magnitude > 0.05 then return false, BOILER .. " is not at " .. f1(BOILER_AT) end
	for _, D in ipairs(STALLS) do
		local C = Stalls[D.Name].Counter
		if Vector3.new(C.Position.X - D.X, 0, C.Position.Z - D.Z).Magnitude > 0.05 then return false, D.Name .. ".Counter is not at (" .. D.X .. ", " .. D.Z .. ")" end
	end
	local Journal = {}
	local Rec
	pcall(function() Rec = CHS:TryBeginRecording("Foundry walk fixes apply") end)
	local Ok, Err = pcall(function()
		local Old = Stack:GetPivot()
		table.insert(Journal, {"moved", Stack, Old}) -- (journalled before the change: Ruling 26)
		Stack:SetAttribute(FROM, Old)
		Stack:PivotTo(Old + MOVE)
		for _, D in ipairs(STALLS) do
			local M = Stalls[D.Name]
			local Shift = M.Counter.CFrame:VectorToWorldSpace(Vector3.new(0, 0, -SLIDE))
			for _, N in ipairs(SLIDING) do
				local P = M[N]
				local Was = P.CFrame
				table.insert(Journal, {"part", P, Was})
				P:SetAttribute(FROM, Was)
				P.CFrame = Was + Shift
			end
		end
		table.insert(Journal, {"flag"})
		FD:SetAttribute(FLAG, "applied")
	end)
	if not Ok then
		for I = #Journal, 1, -1 do
			local J = Journal[I]
			pcall(function()
				if J[1] == "moved" then J[2]:PivotTo(J[3]) J[2]:SetAttribute(FROM, nil)
				elseif J[1] == "part" then J[2].CFrame = J[3] J[2]:SetAttribute(FROM, nil)
				elseif J[1] == "flag" then FD:SetAttribute(FLAG, nil) end
			end)
		end
		if Rec then pcall(function() CHS:FinishRecording(Rec, Enum.FinishRecordingOperation.Cancel) end) end
		return false, "error: " .. tostring(Err) .. " (rolled back " .. #Journal .. " steps)"
	end
	if Rec then pcall(function() CHS:FinishRecording(Rec, Enum.FinishRecordingOperation.Commit) end)
	else pcall(function() CHS:SetWaypoint("Foundry walk fixes apply") end) end
	return true, ("applied: %s %s -> %s; %d stall counters and their goods %.1f toward their fronts"):format(STACK,
		f1(STACK_AT), f1(Stack:GetPivot().Position), #STALLS, SLIDE)
end

local function undo()
	local Lk = locked()
	if Lk then return false, Lk end
	local L = marked()
	local Rec
	pcall(function() Rec = CHS:TryBeginRecording("Foundry walk fixes undo") end)
	local Ok, Err = pcall(function()
		for _, I in ipairs(L) do
			local CF = I:GetAttribute(FROM)
			if typeof(CF) ~= "CFrame" then error(I:GetFullName() .. "'s " .. FROM .. " is not a CFrame") end
			if I:IsA("BasePart") then I.CFrame = CF else I:PivotTo(CF) end
			I:SetAttribute(FROM, nil)
		end
		FD:SetAttribute(FLAG, nil)
	end)
	if Rec then pcall(function() CHS:FinishRecording(Rec, Ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel) end)
	elseif Ok then pcall(function() CHS:SetWaypoint("Foundry walk fixes undo") end) end
	if not Ok then return false, "error: " .. tostring(Err) end
	return true, ("undone: %d models and parts back where they were; %s cleared"):format(#L, FLAG)
end

-- ------------------------------------------------------------------ run
local Out = {}
if MODE == "plan" then
	local G = houseGap()
	local Lo12 = nil
	local House12 = only(Buildings, "House_spine_west_12")
	if House12 and House12:FindFirstChild("Body") then Lo12 = box(House12.Body) end
	local SLo, SHi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, P in ipairs(Stack:GetDescendants()) do
		if P:IsA("BasePart") then local L, H = box(P) SLo, SHi = SLo:Min(L), SHi:Max(H) end
	end
	table.insert(Out, ("walk_fixes plan: %s is %s; %s at %s (box z %.2f..%.2f); gap to %s.Body %.2f; to House_spine_west_12.Body %s; it would move by %s to %s (gap %.2f); %s at %s, not moved"):format(
		FLAG, tostring(FD:GetAttribute(FLAG)), STACK, f1(Stack:GetPivot().Position), SLo.Z, SHi.Z, HOUSE, G,
		Lo12 and ("%.2f"):format(Lo12.Z - SHi.Z) or "?", f1(MOVE), f1(STACK_AT + MOVE), G + MOVE.Z, BOILER, f1(Boiler:GetPivot().Position)))
elseif MODE == "apply" then
	local Ok, Msg = apply()
	if not Ok then return refuse(Msg) end
	local _, Head, Lines = checks()
	table.insert(Out, "walk_fixes apply: " .. Msg)
	table.insert(Out, Head)
	for _, L in ipairs(Lines) do table.insert(Out, L) end
elseif MODE == "undo" then
	local Ok, Msg = undo()
	if not Ok then return refuse(Msg) end
	table.insert(Out, "walk_fixes undo: " .. Msg)
elseif MODE == "check" then
	local _, Head, Lines = checks()
	table.insert(Out, "walk_fixes " .. Head .. " (" .. FLAG .. " is " .. tostring(FD:GetAttribute(FLAG)) .. ")")
	for _, L in ipairs(Lines) do table.insert(Out, L) end
elseif MODE == "test" then
	if FD:GetAttribute(FLAG) ~= nil then return refuse("applied; undo first or run check") end
	local Before = snapshot()
	local Ok, Msg = apply()
	if not Ok then return refuse(Msg) end
	local COk, Fails, Head, Lines = pcall(checks)
	local UOk, UMsg = undo()
	local SOk, After = pcall(snapshot)
	table.insert(Out, ("walk_fixes test: %s %s; %s; round trip %s (%d chars)"):format(Msg,
		COk and Head or ("CHECK ERROR: " .. tostring(Fails)), UOk and UMsg or ("UNDO FAILED: " .. tostring(UMsg)),
		SOk and (Before == After and "EXACT" or "DIFFERS") or ("SNAPSHOT ERROR: " .. tostring(After)), #Before))
	if COk then for _, L in ipairs(Lines) do table.insert(Out, L) end end
else
	return refuse("unknown MODE " .. tostring(MODE))
end
return table.concat(Out, "\n")

--!nocheck
-- post_fixes.lua: Foundry Yard game-data plan Task 4b (Ruling 30), extended in Task 8 (Ruling 32). Five of Lindenmoor's
-- RenseiPost markers stand inside solid parts, so a townsperson can't stand there and walks to and from them fail
-- (Test_YePaths' Stands rule: a standing rig's body axis within 0.5 of a colliding part):
--   lm_lookout_seat      inside Lookout_lookout.Base (the minehand's night seat: mine_carts -> it, it -> mine_winder)
--   lm_haybarn_shelter   inside Barn_hay_barn_east.Body and Plinth (a Shelter post: flee walks end there)
--   lm_farm4_field       inside Farmhouse_farm_4.StoneFloor (farm4's day post: no path from it to lm_farm4_home, and
--                        the walk to it ends against the stone floor)
--   lm_farm1_home        on the rim of Farmyard_farm_1's well (Well6, 1 stud high, through the rig's legs: 0.01 from
--                        its body axis)
--   lm_signal_box        inside SignalBox_signal_box's Base and Cabin (the signalman's post, 0-24: no schedule change
--                        walks to it, but he spawns there and stood inside the box; Task 8, Ruling 32). Its new spot is
--                        3.5 studs -Z (south on Ye's compass) of the old one, on the ground in front of the box's base,
--                        clear of the stair (measured 2026-10-25: waist clearance 2.38). Its reach check starts 30 studs
--                        further -Z (it has no partner post).
-- Each moves to the nearest spot outside its part where a rig can stand (measured 2026-10-25, every spot a PROPOSAL):
-- walkable ground at the old foot's height, nothing solid in the 3 x 5.5 x 3 box a standing rig fills, a waist
-- clearance of 1.25 or more, and (measured with the repaired Mover in Edit) the post's own schedule walks passing every
-- Test_YePaths check. The yaw (facing) is kept. The same spots are in Art/Regions/Lindenmoor/layout.json.
-- Runs in Ye (placeId 106992859583940), Edit only:
--   python -I Art/Tools/rbxc.py luau "placeId: 106992859583940" Edit @Art/Studio/Regions/Lindenmoor/post_fixes.lua
-- MODE = "plan"   read-only: each post, what it stands in, and its new spot (ground, what is solid there).
-- MODE = "apply"  refuses, changing nothing, while Play runs, while ServerStorage's PlayLock is set, when
--                 LindenmoorExpansion has LindenmoorPostFixes, when anything carries LindenmoorPostFrom, or when a post
--                 is not exactly one RenseiPost at its measured old spot. Then, in a pcall with a journal (an error half-
--                 way is rolled back) and one ChangeHistory recording: moves the five posts (each carries
--                 LindenmoorPostFrom, its old CFrame as a CFrame attribute: 12 numbers), sets LindenmoorPostFixes =
--                 "applied", then runs check.
-- MODE = "undo"   (refuses while Play runs or PlayLock is set) puts every LindenmoorPostFrom post back on its old
--                 CFrame, clears the attribute and the flag. No other fix depends on it; it is the FIRST step of the
--                 Lindenmoor Kit's rollback order.
-- MODE = "check"  read-only failure list (against the measured spots below): the flag not "applied"; a post not
--                 exactly one, not at its new spot, without LindenmoorPostFrom, off the ground, with something solid
--                 where a townsperson stands, or with no path to it from its partner post. Returns PASS n / FAIL n.
-- MODE = "test"   (only while not applied) snapshot -> apply -> check -> undo -> snapshot; the two must be equal. The
--                 check and the snapshot run inside a pcall.
local MODE = "plan" -- "plan", "apply", "undo", "check" or "test"

local CS = game:GetService("CollectionService")
local CHS = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")
local PFS = game:GetService("PathfindingService")
local SS = game:GetService("ServerStorage")

local FLAG, FROM = "LindenmoorPostFixes", "LindenmoorPostFrom"
-- Old: the post's centre as found (2-stud markers: the foot is 1 below). New: the centre of its new spot (the ground
-- top + 1). Partner: a post a townsperson walks there from (the reach check).
local POSTS = {
	{Id = "lm_lookout_seat", Old = Vector3.new(716, 33, -446), New = Vector3.new(715.0, 33, -447.7), Partner = "lm_mine_carts", In = "Lookout_lookout.Base"},
	{Id = "lm_haybarn_shelter", Old = Vector3.new(646, 5, 112), New = Vector3.new(641.2, 5, 110.5), Partner = nil, In = "Barn_hay_barn_east.Body"},
	{Id = "lm_farm4_field", Old = Vector3.new(-640, 23, -470), New = Vector3.new(-631.2, 23, -468.0), Partner = "lm_farm4_home", In = "Farmhouse_farm_4.StoneFloor"},
	{Id = "lm_farm1_home", Old = Vector3.new(-876, 23, -876), New = Vector3.new(-880.0, 23, -875.5), Partner = "lm_farm1_field", In = "Farmyard_farm_1.Well6"},
	-- (Task 8, Ruling 32; PROPOSAL spot)
	{Id = "lm_signal_box", Old = Vector3.new(660, 5, 826), New = Vector3.new(660.0, 5, 822.5), Partner = nil, Hub = Vector3.new(660, 8, 792.5), In = "SignalBox_signal_box.Base"},
}
-- the haybarn shelter's reach check starts 30 studs out from its new spot, away from the barn (no roster post is
-- within 150 studs of it; it is a shelter for whoever passes by)
local HAYBARN_HUB = Vector3.new(611.2, 7, 110.5)
local RADII = {2.5, 2, 1.5, 1} -- the Mover's agent radii (Mover.Agent, NarrowRadii, SqueezeRadius)
local COSTS = {Cobblestone = 1, Brick = 1, Concrete = 1, Pavement = 1, Ground = 1.5, WoodPlanks = 1.5, Grass = 3,
	LeafyGrass = 3, Water = 20, Mud = 20}
local ARRIVE = 2.5 -- a path counts when its last waypoint is this close to the post's foot (as foundry_posts.lua)

local function refuse(why) return "post_fixes " .. MODE .. " REFUSED: " .. why end
if game.PlaceId ~= 106992859583940 then return refuse("this is not Ye") end
if RunService:IsRunning() then return refuse("Play is running; Edit only") end
local EX = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map") and workspace.World.Map:FindFirstChild("LindenmoorExpansion")
if not EX then return refuse("no World.Map.LindenmoorExpansion") end
local Markers = EX:FindFirstChild("Markers") and EX.Markers:FindFirstChild("Markers_Expansion")
if not Markers then return refuse("no Markers.Markers_Expansion") end

local function f1(v) return ("(%.2f, %.2f, %.2f)"):format(v.X, v.Y, v.Z) end
local function postsById()
	local Out = {}
	for _, P in ipairs(CS:GetTagged("RenseiPost")) do
		if P:IsDescendantOf(workspace) and P:IsA("BasePart") then
			local Id = P:GetAttribute("PostId")
			Out[Id] = Out[Id] or {}
			table.insert(Out[Id], P)
		end
	end
	return Out
end
local function one(ById, Id) local L = ById[Id] return L and #L == 1 and L[1] or nil end

-- geometry around a spot: everything but the posts and the characters
local Skip = {}
local function skipList()
	table.clear(Skip)
	for _, P in ipairs(CS:GetTagged("RenseiPost")) do table.insert(Skip, P) end
	local Live = workspace.World:FindFirstChild("Live")
	if Live then table.insert(Skip, Live) end
	return Skip
end
local rpG = RaycastParams.new()
rpG.FilterType = Enum.RaycastFilterType.Exclude
rpG.RespectCanCollide = true
local opB = OverlapParams.new()
opB.FilterType = Enum.RaycastFilterType.Exclude
opB.RespectCanCollide = true
-- the ground top under a post centre C (a ray from 6 over the foot), and what it is
local function groundAt(C)
	rpG.FilterDescendantsInstances = skipList()
	local Hit = workspace:Raycast(Vector3.new(C.X, C.Y - 1 + 6, C.Z), Vector3.new(0, -12, 0), rpG)
	return Hit and Hit.Position.Y, Hit and Hit.Instance
end
-- the colliding parts in the 3 x 5.5 x 3 box a rig standing on a post's foot fills
local function solidAt(C)
	opB.FilterDescendantsInstances = skipList()
	local Out = {}
	for _, P in ipairs(workspace:GetPartBoundsInBox(CFrame.new(C.X, C.Y - 1 + 0.2 + 2.75, C.Z), Vector3.new(3, 5.5, 3), opB)) do
		if not P:IsA("Terrain") then table.insert(Out, P.Parent.Name .. "." .. P.Name) end
	end
	return Out
end
-- a Mover-like path from From to a post centre C, at the Mover's radii: the radius, or nil and how far it ended off
local function reach(From, C)
	local Foot = C - Vector3.new(0, 1, 0)
	local Miss
	for _, R in ipairs(RADII) do
		local Path = PFS:CreatePath({AgentRadius = R, AgentHeight = 5.5, AgentCanJump = false, AgentCanClimb = false,
			WaypointSpacing = 4, Costs = COSTS})
		local Ok = pcall(Path.ComputeAsync, Path, From, C + Vector3.new(0, 3, 0))
		if Ok and Path.Status == Enum.PathStatus.Success then
			local W = Path:GetWaypoints()
			local Last = W[#W]
			if Last then
				local D = (Last.Position - Foot).Magnitude
				if D <= ARRIVE then return R, D end
				Miss = D
			end
		end
	end
	return nil, Miss
end
local function hubFor(ById, D)
	if D.Hub then return D.Hub end
	if not D.Partner then return HAYBARN_HUB end
	local P = one(ById, D.Partner)
	return P and (P.CFrame * CFrame.new(0, 3, 0)).Position
end

-- ------------------------------------------------------------------ check (a failure list)
local function checks()
	local Fails, Passes, Out = 0, 0, {}
	local function cond(Failed, What)
		if Failed then Fails += 1 table.insert(Out, "  FAIL " .. What) else Passes += 1 end
	end
	cond(EX:GetAttribute(FLAG) ~= "applied", FLAG .. " is " .. tostring(EX:GetAttribute(FLAG)) .. ", not applied")
	local ById = postsById()
	for _, D in ipairs(POSTS) do
		local P = one(ById, D.Id)
		cond(not P, D.Id .. ": not exactly one RenseiPost (" .. (ById[D.Id] and #ById[D.Id] or 0) .. ")")
		if P then
			cond((P.Position - D.New).Magnitude > 0.05, D.Id .. " is at " .. f1(P.Position) .. ", not " .. f1(D.New))
			cond(typeof(P:GetAttribute(FROM)) ~= "CFrame", D.Id .. " carries no " .. FROM)
			local Top, On = groundAt(P.Position)
			cond(not (Top and math.abs(P.Position.Y - 1 - Top) <= 0.3),
				("%s: not on the ground (foot %.2f, ground %s)"):format(D.Id, P.Position.Y - 1, Top and ("%.2f on %s"):format(Top, On.Name) or "none"))
			local Solid = solidAt(P.Position)
			cond(#Solid > 0, D.Id .. ": solid where a townsperson stands [" .. table.concat(Solid, ", ") .. "]")
			local Hub = hubFor(ById, D)
			local R, Miss = nil, nil
			if Hub then R, Miss = reach(Hub, P.Position) end
			cond(not R, ("%s: no path to it from %s%s"):format(D.Id, D.Partner or "its hub", Miss and (" (ends %.2f off)"):format(Miss) or ""))
		end
	end
	return Fails, ("check: PASS %d / FAIL %d"):format(Passes, Fails), Out
end

-- ------------------------------------------------------------------ snapshot (test mode)
local function r3(V) return math.floor(V * 1000 + 0.5) / 1000 end
local function snapshot()
	local Rows = {}
	for _, P in ipairs(Markers:GetChildren()) do
		local A = {}
		for K, V in pairs(P:GetAttributes()) do table.insert(A, K .. "=" .. tostring(V)) end
		table.sort(A)
		local C = P:IsA("BasePart") and {P.CFrame:GetComponents()} or {}
		for K = 1, #C do C[K] = r3(C[K]) end
		table.insert(Rows, P.Name .. "|" .. P.ClassName .. "|" .. table.concat(C, ",") .. "|" .. table.concat(A, ",") .. "|" .. table.concat(CS:GetTags(P), ","))
	end
	table.sort(Rows)
	return table.concat(Rows, "\n") .. "\n#RenseiPost=" .. #CS:GetTagged("RenseiPost") .. "\n" .. tostring(EX:GetAttribute(FLAG))
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
	for _, P in ipairs(Markers:GetDescendants()) do if P:GetAttribute(FROM) ~= nil then table.insert(Out, P) end end
	return Out
end

local function apply()
	local Lk = locked()
	if Lk then return false, Lk end
	if EX:GetAttribute(FLAG) ~= nil then return false, "already applied (" .. FLAG .. " is " .. tostring(EX:GetAttribute(FLAG)) .. ")" end
	if #marked() > 0 then return false, #marked() .. " posts still carry " .. FROM .. " (undo first)" end
	local ById = postsById()
	local Ps = {}
	for _, D in ipairs(POSTS) do
		local P = one(ById, D.Id)
		if not P then return false, D.Id .. " is not exactly one RenseiPost" end
		if not P:IsDescendantOf(Markers) then return false, D.Id .. " is not in Markers_Expansion" end
		if (P.Position - D.Old).Magnitude > 0.05 then return false, D.Id .. " is at " .. f1(P.Position) .. ", not " .. f1(D.Old) end
		Ps[D.Id] = P
	end
	local Journal, Report = {}, {}
	local Rec
	pcall(function() Rec = CHS:TryBeginRecording("Lindenmoor post fixes apply") end)
	local Ok, Err = pcall(function()
		for _, D in ipairs(POSTS) do
			local P = Ps[D.Id]
			local Old = P.CFrame
			table.insert(Journal, {"moved", P, Old}) -- (journalled before the change)
			P:SetAttribute(FROM, Old)
			P.CFrame = (Old - Old.Position) + D.New -- (the same yaw)
			table.insert(Report, ("%s %s -> %s"):format(D.Id, f1(Old.Position), f1(D.New)))
		end
		table.insert(Journal, {"flag"})
		EX:SetAttribute(FLAG, "applied")
	end)
	if not Ok then
		for I = #Journal, 1, -1 do
			local J = Journal[I]
			pcall(function()
				if J[1] == "moved" then J[2].CFrame = J[3] J[2]:SetAttribute(FROM, nil)
				elseif J[1] == "flag" then EX:SetAttribute(FLAG, nil) end
			end)
		end
		if Rec then pcall(function() CHS:FinishRecording(Rec, Enum.FinishRecordingOperation.Cancel) end) end
		return false, "error: " .. tostring(Err) .. " (rolled back " .. #Journal .. " steps)"
	end
	if Rec then pcall(function() CHS:FinishRecording(Rec, Enum.FinishRecordingOperation.Commit) end)
	else pcall(function() CHS:SetWaypoint("Lindenmoor post fixes apply") end) end
	return true, "applied: " .. table.concat(Report, "; ")
end

local function undo()
	local Lk = locked()
	if Lk then return false, Lk end
	local L = marked()
	local Rec
	pcall(function() Rec = CHS:TryBeginRecording("Lindenmoor post fixes undo") end)
	local Ok, Err = pcall(function()
		for _, P in ipairs(L) do
			local CF = P:GetAttribute(FROM)
			if typeof(CF) ~= "CFrame" then error(P:GetFullName() .. "'s " .. FROM .. " is not a CFrame") end
			P.CFrame = CF
			P:SetAttribute(FROM, nil)
		end
		EX:SetAttribute(FLAG, nil)
	end)
	if Rec then pcall(function() CHS:FinishRecording(Rec, Ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel) end)
	elseif Ok then pcall(function() CHS:SetWaypoint("Lindenmoor post fixes undo") end) end
	if not Ok then return false, "error: " .. tostring(Err) end
	return true, ("undone: %d posts back on their old CFrames; %s cleared"):format(#L, FLAG)
end

-- ------------------------------------------------------------------ run
local Out = {}
if MODE == "plan" then
	local ById = postsById()
	table.insert(Out, ("post_fixes plan: %s is %s"):format(FLAG, tostring(EX:GetAttribute(FLAG))))
	for _, D in ipairs(POSTS) do
		local P = one(ById, D.Id)
		local Top, On = groundAt(D.New)
		table.insert(Out, ("  %s now %s, solid there [%s]; new spot %s: ground %s, solid [%s]"):format(D.Id,
			P and f1(P.Position) or "MISSING", P and table.concat(solidAt(P.Position), ", ") or "-", f1(D.New),
			Top and ("%.2f on %s"):format(Top, On.Name) or "none", table.concat(solidAt(D.New), ", ")))
	end
elseif MODE == "apply" then
	local Ok, Msg = apply()
	if not Ok then return refuse(Msg) end
	local _, Head, Lines = checks()
	table.insert(Out, "post_fixes apply: " .. Msg)
	table.insert(Out, Head)
	for _, L in ipairs(Lines) do table.insert(Out, L) end
elseif MODE == "undo" then
	local Ok, Msg = undo()
	if not Ok then return refuse(Msg) end
	table.insert(Out, "post_fixes undo: " .. Msg)
elseif MODE == "check" then
	local _, Head, Lines = checks()
	table.insert(Out, "post_fixes " .. Head .. " (" .. FLAG .. " is " .. tostring(EX:GetAttribute(FLAG)) .. ")")
	for _, L in ipairs(Lines) do table.insert(Out, L) end
elseif MODE == "test" then
	if EX:GetAttribute(FLAG) ~= nil then return refuse("applied; undo first or run check") end
	local Before = snapshot()
	local Ok, Msg = apply()
	if not Ok then return refuse(Msg) end
	local COk, Fails, Head, Lines = pcall(checks)
	local UOk, UMsg = undo()
	local SOk, After = pcall(snapshot)
	table.insert(Out, ("post_fixes test: %s %s; %s; round trip %s (%d chars)"):format(Msg,
		COk and Head or ("CHECK ERROR: " .. tostring(Fails)), UOk and UMsg or ("UNDO FAILED: " .. tostring(UMsg)),
		SOk and (Before == After and "EXACT" or "DIFFERS") or ("SNAPSHOT ERROR: " .. tostring(After)), #Before))
	if COk then for _, L in ipairs(Lines) do table.insert(Out, L) end end
else
	return refuse("unknown MODE " .. tostring(MODE))
end
return table.concat(Out, "\n")

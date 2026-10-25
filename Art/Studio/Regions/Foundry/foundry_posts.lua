--!nocheck
-- foundry_posts.lua: Foundry Yard game-data plan Task 4. Foundry's townsfolk posts (Map.Foundry.Markers.Markers_Foundry,
-- tagged RenseiPost) had 7 Shelter posts, so 37 posts had no shelter within TownsfolkService.ShelterRadius (150) and
-- 6 posts could not be walked to: yard_hand_2 / yard_hand_3 stand on the goods platform (top y 8, no ramp), and the
-- four market traders stand boxed in between their stall's Counter, its Shelf and its corner posts. This:
--   (a) adds 12 Shelter posts (FoundryShelter_<PostId>), so every post has a shelter within 145 studs (straight line;
--       PROPOSAL margin under the 150 cap);
--   (b) moves yard_hand_2 / yard_hand_3 off the goods platform onto the ground in front of it (z 164, else z 144);
--   (c) makes the four traders' stall Shelf parts walk-through (CanCollide false), and only if a trader still has no
--       path, moves that post 0.8 (then 1.6) studs back toward the shelf;
--   (d) (measured 2026-10-24, not in the plan's brief: a refusal under (c) otherwise) if a trader still has no path,
--       puts a PathfindingModifier with PassThrough under that stall's Canopy (FoundryCanopyPassThrough): the
--       canopy's underside is about 6.7 studs over the ground, so a rig fits under it, but it shuts the navmesh under
--       it; then tries the post where it is, then 0.8 / 1.6 back. The canopy stays solid for players.
-- The same posts are recorded in Art/Regions/Foundry/layout.json (the shelf and canopy changes in its "Notes").
-- Foundry's compass: -Z is north, +X is east (Regions.NorthOf "-Z"): row_north_shelter is the north (-Z) end of
-- Workers' Row, square_south_shelter the south (+Z) end of the square.
-- Runs in Foundry (placeId 109591196441030), Edit only, with Ye's ServerStorage PlayLock nil (read it first):
--   python -I Art/Tools/rbxc.py luau "placeId: 109591196441030" Edit @Art/Studio/Regions/Foundry/foundry_posts.lua
-- MODE = "plan"   read-only: the spot each new shelter would take, the two yard posts' spots, the traders' stalls.
-- MODE = "apply"  refuses, changing nothing, while Play runs, while this place's PlayLock is set, when Map.Foundry has
--                 FoundryPosts, when any new PostId or FoundryShelter_* part already exists, or when any part still
--                 carries FoundryPostAdd / FoundryPostFrom / FoundryShelfFrom. Then, in a pcall with a journal (an
--                 error or a refusal half-way is rolled back) and one ChangeHistory recording (cancelled on a
--                 refusal): (c) shelves, (b) yard posts, (c) trader nudges if needed, (a) shelters, then sets
--                 Map.Foundry's FoundryPosts = "applied" and runs check. Created parts carry FoundryPostAdd = true;
--                 moved posts carry FoundryPostFrom (the old CFrame: its 12 numbers, as a CFrame attribute); changed
--                 shelves carry FoundryShelfFrom = true (their old CanCollide was true); the canopy modifiers are
--                 created instances, so they carry FoundryPostAdd = true.
-- MODE = "undo"   (refuses while Play runs or PlayLock is set) destroys the FoundryPostAdd instances, puts every
--                 FoundryPostFrom part back and clears the attribute, sets every FoundryShelfFrom Shelf back to
--                 CanCollide true, clears FoundryPosts. No other fix guards it: nothing later builds on these posts.
-- MODE = "check"  read-only failure list: post count not 88, a post unreachable from the hub, a post whose nearest
--                 Shelter is over 145 studs away, a duplicate PostId, a new shelter missing / untagged / off the
--                 ground / with something solid where a townsperson stands. Returns PASS n / FAIL n.
-- MODE = "test"   (only while not applied) snapshot -> apply -> check -> undo -> snapshot; the two must be equal.
--                 check (and the second snapshot) run in a pcall, so undo always runs (Ruling 26, Foundry data Task 7).
--                 Leaves Foundry as it was.
-- import/restore.lua refuses while FoundryPosts is set (the region file's RestoreRefuseFlags).
local MODE = "plan" -- "plan", "apply", "undo", "check" or "test"

local CS = game:GetService("CollectionService")
local CHS = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")
local PFS = game:GetService("PathfindingService")
local SS = game:GetService("ServerStorage")

local FLAG, ADD, FROM, SHELF = "FoundryPosts", "FoundryPostAdd", "FoundryPostFrom", "FoundryShelfFrom"
local REACH = 145 -- PROPOSAL: a shelter within this of every post (TownsfolkService.ShelterRadius 150, Ruling 37)
local POST_COUNT = 88 -- 76 imported posts + the 12 shelters
local GROUND_LO, GROUND_HI = 3.9, 4.6 -- the walkable ground tops (y 4 plain, 4.4 the hall and court floors)
-- the Mover's agent (TownsfolkService/Mover.lua: Mover.Agent radius 2.5, NarrowRadii 2 and 1.5, SqueezeRadius 1;
-- height 5.5, no jumping or climbing, WaypointSpacing 4; Mover.Costs), copied here: an Edit script requires no module
local RADII = {2.5, 2, 1.5, 1}
local COSTS = {Cobblestone = 1, Brick = 1, Concrete = 1, Pavement = 1, Ground = 1.5, WoodPlanks = 1.5, Grass = 3,
	LeafyGrass = 3, Water = 20, Mud = 20}
local ARRIVE = 2.5 -- a path counts when its last waypoint is this close to the post's foot (see reach())

-- (a) PROPOSAL targets (Yaw 0). The spot is the target, or the first point of a 2-stud spiral within 6 studs of it,
-- that passes spotTest().
local SHELTERS = {
	{Id = "freight_shelter", X = 300, Z = 180},
	{Id = "crane_shelter", X = 303, Z = -150},
	{Id = "stack_shelter", X = 350, Z = -515},
	{Id = "casting_shelter", X = 600, Z = -610},
	{Id = "square_south_shelter", X = -90, Z = -340}, -- the square spans z -768..-250: z -340 is its south end
	{Id = "boarding_shelter", X = -400, Z = -370},
	{Id = "row_south_shelter", X = -560, Z = -330}, -- the south (+Z) end of Workers' Row
	{Id = "row_north_shelter", X = -480, Z = -650}, -- the north (-Z) end of Workers' Row
	{Id = "court_shelter", X = -170, Z = 470},
	{Id = "shed_shelter", X = -200, Z = -120},
	{Id = "cinder_west_shelter", X = -400, Z = 280},
	-- (the plan's (-100, 280) is inside a Cinder Row house, roof y 39.7, with no ground within 6 studs; measured
	-- 2026-10-24: the house fronts start at about z 272, so the shelter stands on the front path in front of them)
	{Id = "cinder_east_shelter", X = -90, Z = 268},
}
-- (b) off the goods platform (top y 8), facing -Z (Yaw 0) as before
local YARD = {
	{Id = "yard_hand_2", Old = Vector3.new(420, 9, 154), X = 420, Zs = {164, 144}},
	{Id = "yard_hand_3", Old = Vector3.new(560, 9, 154), X = 560, Zs = {164, 144}},
}
-- (c)
local TRADERS = {"market_trader_1", "market_trader_2", "market_trader_3", "market_trader_4"}
local NUDGES = {0.8, 1.6}
local NAV_WAIT = 1 -- s (PROPOSAL): measured 2026-10-24, a path asked in the same frame as a collision change still
-- sees the old geometry; after a 1 s wait it sees the new

local function refuse(why) return "foundry_posts " .. MODE .. " REFUSED: " .. why end
if game.PlaceId ~= 109591196441030 then return refuse("this is not Foundry") end
if RunService:IsRunning() then return refuse("Play is running; Edit only") end
local Map = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map")
local FD = Map and Map:FindFirstChild("Foundry")
if not FD then return refuse("no World.Map.Foundry") end
local MarkersRoot = FD:FindFirstChild("Markers")
local Markers = MarkersRoot and MarkersRoot:FindFirstChild("Markers_Foundry")
if not Markers then return refuse("no Map.Foundry.Markers.Markers_Foundry") end

local function f1(v) return ("(%.1f, %.1f, %.1f)"):format(v.X, v.Y, v.Z) end
local function postsById()
	local Out = {}
	for _, P in ipairs(CS:GetTagged("RenseiPost")) do
		if P:IsDescendantOf(workspace) and P:IsA("BasePart") then
			local Id = P:GetAttribute("PostId")
			if Id then
				Out[Id] = Out[Id] or {}
				table.insert(Out[Id], P)
			end
		end
	end
	return Out
end
local function one(ById, Id) local L = ById[Id] return L and #L == 1 and L[1] or nil end
local Pattern = one(postsById(), "station_shelter")
if not (Pattern and Pattern:IsDescendantOf(Markers) and Pattern:GetAttribute("Kind") == "Shelter") then
	return refuse("station_shelter (the pattern post) is not in Markers_Foundry")
end

-- ------------------------------------------------------------------ the spot and reach tests
local rpG = RaycastParams.new()
rpG.FilterType = Enum.RaycastFilterType.Exclude
rpG.FilterDescendantsInstances = {MarkersRoot}
rpG.RespectCanCollide = true -- the ground is something a rig stands on (lamp glows and glass don't count)
local opB = OverlapParams.new()
opB.FilterType = Enum.RaycastFilterType.Exclude
opB.FilterDescendantsInstances = {MarkersRoot}

-- the ground top under (x, z): a ray down from y 60 must first meet a Map.Foundry part outside Markers
local function groundAt(X, Z)
	local Hit = workspace:Raycast(Vector3.new(X, 60, Z), Vector3.new(0, -120, 0), rpG)
	if not Hit then return nil, "nothing under it" end
	if not Hit.Instance:IsDescendantOf(FD) then return nil, "first hit " .. Hit.Instance:GetFullName() .. " is not Map.Foundry's" end
	return Hit.Position.Y, Hit.Instance
end
-- the CanCollide parts in the 3 x 5.5 x 3 box a rig standing on (x, top, z) fills
local function solidAt(X, Top, Z)
	local Solid = {}
	for _, P in ipairs(workspace:GetPartBoundsInBox(CFrame.new(X, Top + 3.25, Z), Vector3.new(3, 5.5, 3), opB)) do
		if P.CanCollide then table.insert(Solid, P.Name) end
	end
	return Solid
end

local function hubFor(ById, Id)
	local H = one(ById, Id == "errand_square" and "guard_square" or "errand_square")
	return H and H.Position + Vector3.new(0, 2, 0)
end
-- a path from the hub to a stand point at the Mover's radii (2.5, then 2, 1.5, 1). Success: the last waypoint is
-- within ARRIVE of the post's foot (the ground under the stand point, stand - 3). Roblox puts the last waypoint on the
-- navmesh, 2 to 3 studs under a rig's stand point (measured 2026-10-24 on all 70 reachable posts: 2.00 to 3.00), so
-- the foot, not the stand point, is what a waypoint can be near. Returns the radius used (nil: no path) and the miss.
local function reach(Hub, Stand)
	local Foot = Stand - Vector3.new(0, 3, 0)
	local Miss
	for _, R in ipairs(RADII) do
		local Path = PFS:CreatePath({AgentRadius = R, AgentHeight = 5.5, AgentCanJump = false, AgentCanClimb = false,
			WaypointSpacing = 4, Costs = COSTS})
		local Ok = pcall(Path.ComputeAsync, Path, Hub, Stand)
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
-- the spot test for a post standing on (x, z): returns the ground top (nil: fails) and why
local function spotTest(Hub, X, Z)
	local Top, On = groundAt(X, Z)
	if not Top then return nil, On end
	if Top < GROUND_LO or Top > GROUND_HI then return nil, ("ground top %.2f (on %s) is not %.1f..%.1f"):format(Top, On.Name, GROUND_LO, GROUND_HI) end
	local Solid = solidAt(X, Top, Z)
	if #Solid > 0 then return nil, "solid where a rig stands [" .. table.concat(Solid, ",") .. "]" end
	local R, Miss = reach(Hub, Vector3.new(X, Top + 3, Z))
	if not R then return nil, "no path from the hub" .. (Miss and (" (ends %.2f off)"):format(Miss) or "") end
	return Top, ("ground %.2f on %s, path at radius %.1f"):format(Top, On.Name, R)
end
-- the target, then rings of radius 2, 4 and 6 (points about 2 studs apart, from +X round towards +Z)
local function spiral(X, Z)
	local Pts = {{X, Z}}
	for _, R in ipairs({2, 4, 6}) do
		local N = math.floor(2 * math.pi * R / 2 + 0.5)
		for K = 0, N - 1 do
			local A = 2 * math.pi * K / N
			table.insert(Pts, {X + R * math.cos(A), Z + R * math.sin(A)})
		end
	end
	return Pts
end
local function findSpot(Hub, D)
	local Tried, Why = 0, nil
	for _, Pt in ipairs(spiral(D.X, D.Z)) do
		Tried += 1
		local Top, W = spotTest(Hub, Pt[1], Pt[2])
		if Top then return Pt[1], Pt[2], Top, Tried, W end
		if Tried == 1 then Why = W end
	end
	return nil, nil, nil, Tried, Why
end
-- the MarketStall_* models whose Counter is within 3 studs (XZ) of a post
local function stallsFor(P)
	local Out = {}
	for _, M in ipairs(FD:GetDescendants()) do
		if M:IsA("Model") and M.Name:match("^MarketStall_") then
			local C = M:FindFirstChild("Counter")
			if C and C:IsA("BasePart") and Vector2.new(C.Position.X - P.Position.X, C.Position.Z - P.Position.Z).Magnitude <= 3 then
				table.insert(Out, M)
			end
		end
	end
	return Out
end

-- ------------------------------------------------------------------ check (a failure list)
local function group(Id) return (Id:gsub("_%d+$", "")) end
local function checks()
	local Fails, Passes, Out = 0, 0, {}
	local function cond(Failed, What)
		if Failed then
			Fails += 1
			table.insert(Out, "  FAIL " .. What)
		else
			Passes += 1
		end
	end
	local ById = postsById()
	local All, Shelters = {}, {}
	for Id, L in pairs(ById) do
		for _, P in ipairs(L) do
			table.insert(All, P)
			if P:GetAttribute("Kind") == "Shelter" then table.insert(Shelters, P) end
		end
	end
	table.sort(All, function(A, B) return A:GetAttribute("PostId") < B:GetAttribute("PostId") end)
	cond(#All ~= POST_COUNT, ("%d RenseiPost posts in workspace, not %d"):format(#All, POST_COUNT))
	-- duplicate PostIds
	local Ids = {}
	for Id in pairs(ById) do table.insert(Ids, Id) end
	table.sort(Ids)
	for _, Id in ipairs(Ids) do cond(#ById[Id] > 1, ("duplicate PostId %s (%d posts)"):format(Id, #ById[Id])) end
	-- the new shelters
	for _, D in ipairs(SHELTERS) do
		local L = ById[D.Id]
		local P = L and #L == 1 and L[1]
		cond(not P, D.Id .. ": not exactly one post in the place (" .. (L and #L or 0) .. ")")
		if P then
			cond(not (P.Name == "FoundryShelter_" .. D.Id and P.Parent == Markers and CS:HasTag(P, "RenseiPost")
				and P:GetAttribute("Kind") == "Shelter" and P:GetAttribute(ADD) == true),
				D.Id .. ": not FoundryShelter_" .. D.Id .. " in Markers_Foundry, tagged RenseiPost, Kind Shelter, " .. ADD)
			local Top, On = groundAt(P.Position.X, P.Position.Z)
			cond(not (Top and Top >= GROUND_LO and Top <= GROUND_HI and math.abs(P.Position.Y - 1 - Top) <= 0.05),
				("%s: not on the ground (post foot %.2f, ground %s)"):format(D.Id, P.Position.Y - 1, Top and ("%.2f"):format(Top) or tostring(On)))
			if Top then
				local Solid = solidAt(P.Position.X, Top, P.Position.Z)
				cond(#Solid > 0, D.Id .. ": solid where a townsperson stands [" .. table.concat(Solid, ",") .. "]")
			end
		end
	end
	-- every post: a shelter within REACH (from where a rig's root stands, 3 over the post, as TownsfolkService and
	-- Play_LindenmoorData measure) and a path from the hub
	local Worst, WorstOrder = {}, {}
	local Unreached, Far = 0, 0
	for _, P in ipairs(All) do
		local Id = P:GetAttribute("PostId")
		local At = (P.CFrame * CFrame.new(0, 3, 0)).Position
		local Best, BestId = math.huge, "-"
		for _, S in ipairs(Shelters) do
			local D = (S.Position - At).Magnitude
			if D < Best then Best, BestId = D, S:GetAttribute("PostId") end
		end
		if Best > REACH then Far += 1 end
		cond(Best > REACH, ("%s: nearest shelter %s at %.1f (over %d)"):format(Id, BestId, Best, REACH))
		local G = group(Id)
		if not Worst[G] then table.insert(WorstOrder, G) end
		if not Worst[G] or Best > Worst[G][1] then Worst[G] = {Best, Id, BestId} end
		local Hub = hubFor(ById, Id)
		local R, Miss = nil, nil
		if Hub then R, Miss = reach(Hub, P.Position + Vector3.new(0, 2, 0)) end
		if not R then Unreached += 1 end
		cond(not R, ("%s: unreachable from the hub at %s%s"):format(Id, f1(P.Position), Miss and (" (path ends %.2f off)"):format(Miss) or ""))
	end
	table.sort(WorstOrder, function(A, B) return Worst[A][1] > Worst[B][1] end)
	local Table = {}
	for _, G in ipairs(WorstOrder) do table.insert(Table, ("%s %.1f (%s->%s)"):format(G, Worst[G][1], Worst[G][2], Worst[G][3])) end
	local Head = ("check: PASS %d / FAIL %d; %d posts, %d shelters, %d unreachable, %d over %d from a shelter; worst per group: %s")
		:format(Passes, Fails, #All, #Shelters, Unreached, Far, REACH, table.concat(Table, "; "))
	return Fails, Head, Out
end

-- ------------------------------------------------------------------ snapshot (test mode)
local function r2(V) return math.floor(V * 100 + 0.5) / 100 end
local function snapshot()
	local Rows = {}
	local function attrs(I)
		local A = {}
		for K, V in pairs(I:GetAttributes()) do table.insert(A, K .. "=" .. tostring(V)) end
		table.sort(A)
		local T = CS:GetTags(I)
		table.sort(T)
		return table.concat(A, ",") .. "#" .. table.concat(T, ",")
	end
	local function row(I)
		local S = I:GetFullName() .. "|" .. I.ClassName
		if I:IsA("BasePart") then
			local C = {I.CFrame:GetComponents()}
			for K = 1, 12 do C[K] = r2(C[K]) end
			S ..= "|" .. table.concat(C, ",") .. "|" .. tostring(I.CanCollide)
		end
		table.insert(Rows, S .. "|" .. attrs(I))
	end
	-- every instance under Map.Foundry.Markers and in every MarketStall_* model (BaseParts with CFrame and CanCollide)
	for _, I in ipairs(MarkersRoot:GetDescendants()) do row(I) end
	for _, M in ipairs(FD:GetDescendants()) do
		if M:IsA("Model") and M.Name:match("^MarketStall_") then
			row(M)
			for _, I in ipairs(M:GetDescendants()) do row(I) end
		end
	end
	table.sort(Rows)
	local Tags, Parts = {}, 0
	for _, I in ipairs(workspace:GetDescendants()) do
		if I:IsA("BasePart") then Parts += 1 end
		for _, T in ipairs(CS:GetTags(I)) do Tags[T] = (Tags[T] or 0) + 1 end
	end
	local TL = {}
	for T, N in pairs(Tags) do table.insert(TL, T .. "=" .. N) end
	table.sort(TL)
	table.insert(Rows, "#tags " .. table.concat(TL, ","))
	table.insert(Rows, "#workspace BaseParts " .. Parts)
	table.insert(Rows, "#Map.Foundry " .. attrs(FD))
	return Rows
end
local function compare(A, B)
	local Diffs, First = 0, {}
	local Set = {}
	for _, S in ipairs(B) do Set[S] = (Set[S] or 0) + 1 end
	for _, S in ipairs(A) do
		if Set[S] and Set[S] > 0 then Set[S] -= 1 else Diffs += 1 if #First < 4 then table.insert(First, "before only: " .. S) end end
	end
	for S, N in pairs(Set) do
		if N > 0 then Diffs += N if #First < 8 then table.insert(First, "after only: " .. S) end end
	end
	return Diffs, First
end

-- ------------------------------------------------------------------ apply / undo
local function marked()
	local Add, From, Shelf = {}, {}, {}
	for _, I in ipairs(FD:GetDescendants()) do
		if I:GetAttribute(ADD) ~= nil then table.insert(Add, I) end
		if I:GetAttribute(FROM) ~= nil then table.insert(From, I) end
		if I:GetAttribute(SHELF) ~= nil then table.insert(Shelf, I) end
	end
	return Add, From, Shelf
end
local function locked()
	if RunService:IsRunning() then return "Play is running" end
	local L = SS:GetAttribute("PlayLock")
	if L ~= nil then return "PlayLock is set (" .. tostring(L) .. ")" end
	return nil
end

local function apply()
	local Lk = locked()
	if Lk then return false, Lk end
	if FD:GetAttribute(FLAG) ~= nil then return false, "already applied (" .. FLAG .. " is " .. tostring(FD:GetAttribute(FLAG)) .. ")" end
	local ById = postsById()
	for _, D in ipairs(SHELTERS) do
		if ById[D.Id] then return false, D.Id .. " already exists" end
		if Markers:FindFirstChild("FoundryShelter_" .. D.Id) then return false, "FoundryShelter_" .. D.Id .. " already exists" end
	end
	local A0, F0, S0 = marked()
	if #A0 + #F0 + #S0 > 0 then return false, ("%d parts still carry %s / %s / %s (undo first)"):format(#A0 + #F0 + #S0, ADD, FROM, SHELF) end
	for _, Y in ipairs(YARD) do
		local P = one(ById, Y.Id)
		if not (P and (P.Position - Y.Old).Magnitude <= 0.05) then return false, Y.Id .. " is not at " .. f1(Y.Old) end
	end
	local Traders = {}
	for _, Id in ipairs(TRADERS) do
		local P = one(ById, Id)
		if not P then return false, Id .. " is not one post" end
		local St = stallsFor(P)
		if #St ~= 1 then return false, ("%s: %d MarketStall_* counters within 3 studs, not 1"):format(Id, #St) end
		local Sh = St[1]:FindFirstChild("Shelf")
		if not (Sh and Sh:IsA("BasePart") and Sh.CanCollide) then return false, St[1].Name .. ".Shelf is not a solid part" end
		local Ca = St[1]:FindFirstChild("Canopy")
		if not (Ca and Ca:IsA("BasePart")) then return false, St[1].Name .. " has no Canopy part" end
		if Ca:FindFirstChildOfClass("PathfindingModifier") then return false, St[1].Name .. ".Canopy already has a PathfindingModifier" end
		table.insert(Traders, {Id = Id, P = P, Stall = St[1], Shelf = Sh, Canopy = Ca})
	end

	local Journal, Report = {}, {}
	local Rec
	pcall(function() Rec = CHS:TryBeginRecording("Foundry posts apply") end)
	local Ok, Err = pcall(function()
		-- (c) the shelves
		for _, T in ipairs(Traders) do
			table.insert(Journal, {"shelf", T.Shelf}) -- (Ruling 26: each journal entry before the change it undoes)
			T.Shelf.CanCollide = false
			T.Shelf:SetAttribute(SHELF, true)
		end
		task.wait(NAV_WAIT) -- (the navmesh is rebuilt on a later frame; a path asked at once still sees the shelves)
		-- (b) the yard posts
		for _, Y in ipairs(YARD) do
			local P = one(ById, Y.Id)
			local Hub = hubFor(ById, Y.Id)
			local Done = {}
			for _, Z in ipairs(Y.Zs) do
				local Top, Why = spotTest(Hub, Y.X, Z)
				if Top then
					local Old = P.CFrame
					table.insert(Journal, {"moved", P, Old})
					P:SetAttribute(FROM, Old)
					P.CFrame = CFrame.new(Y.X, Top + 1, Z) -- Yaw 0: facing -Z, as before
					table.insert(Report, ("%s -> %s (%s)"):format(Y.Id, f1(P.Position), Why))
					Done = nil
					break
				end
				table.insert(Done, ("z %d: %s"):format(Z, Why))
			end
			if Done then error({Refuse = Y.Id .. ": no spot (" .. table.concat(Done, "; ") .. ")"}) end
		end
		-- (c) a trader still boxed in moves toward the shelf
		for _, T in ipairs(Traders) do
			local Hub = hubFor(ById, T.Id)
			local Old = T.P.CFrame
			local R = reach(Hub, T.P.Position + Vector3.new(0, 2, 0))
			if R then
				table.insert(Report, ("%s reachable at radius %.1f with %s.Shelf walk-through (not moved)"):format(T.Id, R, T.Stall.Name))
			else
				local Moved
				for _, N in ipairs(NUDGES) do
					local CF = Old + (-Old.LookVector) * N
					local R2 = reach(Hub, CF.Position + Vector3.new(0, 2, 0))
					if R2 then
						table.insert(Journal, {"moved", T.P, Old})
						T.P:SetAttribute(FROM, Old)
						T.P.CFrame = CF
						Moved = ("%s moved %.1f back to %s (radius %.1f)"):format(T.Id, N, f1(CF.Position), R2)
						break
					end
				end
				if not Moved then
					-- (d) the stall's Canopy (bottom about 6.7 studs over the ground, so a rig fits under it) still shuts
					-- the navmesh under it (measured 2026-10-24: no path to the trader at any radius with the shelf
					-- gone, nor 0.8 / 1.6 back; one with the canopy passed through). A PathfindingModifier with
					-- PassThrough lets paths run under it; the canopy stays solid for players.
					local Mod = Instance.new("PathfindingModifier")
					Mod.Name = "FoundryCanopyPassThrough"
					Mod.PassThrough = true
					Mod:SetAttribute(ADD, true)
					table.insert(Journal, {"made", Mod}) -- (Ruling 26: the journal entry before the Parent)
					Mod.Parent = T.Canopy
					-- (a new modifier alone doesn't rebuild the navmesh in Edit, measured 2026-10-24; the stall's own
					-- collision change does: the shelf goes solid for a moment and walk-through again)
					T.Shelf.CanCollide = true
					task.wait(0.1)
					T.Shelf.CanCollide = false
					task.wait(NAV_WAIT)
					local R3 = reach(Hub, Old.Position + Vector3.new(0, 2, 0))
					if R3 then
						Moved = ("%s reachable at radius %.1f with %s.Shelf walk-through and its Canopy passed through (not moved)"):format(T.Id, R3, T.Stall.Name)
					else
						for _, N in ipairs(NUDGES) do
							local CF = Old + (-Old.LookVector) * N
							local R2 = reach(Hub, CF.Position + Vector3.new(0, 2, 0))
							if R2 then
								table.insert(Journal, {"moved", T.P, Old})
								T.P:SetAttribute(FROM, Old)
								T.P.CFrame = CF
								Moved = ("%s moved %.1f back to %s, canopy passed through (radius %.1f)"):format(T.Id, N, f1(CF.Position), R2)
								break
							end
						end
					end
				end
				if not Moved then error({Refuse = T.Id .. ": no path with the shelf walk-through and the canopy passed through, nor 0.8 / 1.6 studs back"}) end
				table.insert(Report, Moved)
			end
		end
		-- (a) the shelters
		for _, D in ipairs(SHELTERS) do
			local Hub = hubFor(ById, D.Id)
			local X, Z, Top, Tried, Why = findSpot(Hub, D)
			if not X then error({Refuse = ("%s: no spot within 6 studs of (%d, %d) (%d tried; the target: %s)"):format(D.Id, D.X, D.Z, Tried, tostring(Why))}) end
			local P = Instance.new("Part")
			P.Name = "FoundryShelter_" .. D.Id
			P.Size = Pattern.Size
			P.Transparency, P.Anchored = Pattern.Transparency, true
			P.CanCollide, P.CanQuery, P.CanTouch = Pattern.CanCollide, Pattern.CanQuery, Pattern.CanTouch
			P.CastShadow = Pattern.CastShadow
			P.CFrame = CFrame.new(X, Top + 1, Z) -- Yaw 0
			P:SetAttribute("PostId", D.Id)
			P:SetAttribute("Kind", "Shelter")
			P:SetAttribute(ADD, true)
			table.insert(Journal, {"made", P}) -- (Ruling 26: the journal entry before the Parent)
			P.Parent = Markers
			CS:AddTag(P, "RenseiPost")
			table.insert(Report, ("%s at (%.1f, %.2f, %.1f)%s; %s"):format(D.Id, X, Top + 1, Z,
				Tried > 1 and (" (spiral point %d)"):format(Tried) or " (the target)", Why))
		end
		table.insert(Journal, {"flag"})
		FD:SetAttribute(FLAG, "applied")
	end)
	if not Ok then
		for I = #Journal, 1, -1 do
			local J = Journal[I]
			pcall(function()
				if J[1] == "made" then J[2]:Destroy()
				elseif J[1] == "moved" then J[2].CFrame = J[3] J[2]:SetAttribute(FROM, nil)
				elseif J[1] == "shelf" then J[2].CanCollide = true J[2]:SetAttribute(SHELF, nil)
				elseif J[1] == "flag" then FD:SetAttribute(FLAG, nil) end
			end)
		end
		if Rec then pcall(function() CHS:FinishRecording(Rec, Enum.FinishRecordingOperation.Cancel) end) end
		local Why = type(Err) == "table" and Err.Refuse or ("error: " .. tostring(Err))
		return false, Why .. " (rolled back " .. #Journal .. " steps)"
	end
	if Rec then pcall(function() CHS:FinishRecording(Rec, Enum.FinishRecordingOperation.Commit) end)
	else pcall(function() CHS:SetWaypoint("Foundry posts apply") end) end
	return true, ("applied: %d steps. %s"):format(#Journal, table.concat(Report, ". "))
end

local function undo()
	local Lk = locked()
	if Lk then return false, Lk end
	local Add, From, Shelf = marked()
	local Rec
	pcall(function() Rec = CHS:TryBeginRecording("Foundry posts undo") end)
	local Ok, Err = pcall(function()
		for _, I in ipairs(From) do
			local CF = I:GetAttribute(FROM)
			if typeof(CF) ~= "CFrame" then error(I:GetFullName() .. "'s " .. FROM .. " is not a CFrame") end
			I.CFrame = CF
			I:SetAttribute(FROM, nil)
		end
		for _, I in ipairs(Shelf) do
			I.CanCollide = true
			I:SetAttribute(SHELF, nil)
		end
		for _, I in ipairs(Add) do I:Destroy() end
		FD:SetAttribute(FLAG, nil)
	end)
	if Rec then pcall(function() CHS:FinishRecording(Rec, Ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel) end)
	elseif Ok then pcall(function() CHS:SetWaypoint("Foundry posts undo") end) end
	if not Ok then return false, "error: " .. tostring(Err) end
	return true, ("undone: removed %d added instances, moved %d posts back, %d shelves solid again; %s cleared"):format(#Add, #From, #Shelf, FLAG)
end

-- ------------------------------------------------------------------ run
local Out = {}
if MODE == "plan" then
	local ById = postsById()
	local N = 0
	for _, L in pairs(ById) do N += #L end
	table.insert(Out, ("foundry_posts plan: %d posts now, %s is %s."):format(N, FLAG, tostring(FD:GetAttribute(FLAG))))
	for _, D in ipairs(SHELTERS) do
		local X, Z, Top, Tried, Why = findSpot(hubFor(ById, D.Id), D)
		table.insert(Out, X and ("  %s -> (%.1f, %.2f, %.1f) point %d; %s%s"):format(D.Id, X, Top + 1, Z, Tried, Why, ById[D.Id] and " EXISTS" or "")
			or ("  %s: NO SPOT (%d tried; target: %s)"):format(D.Id, Tried, tostring(Why)))
	end
	for _, Y in ipairs(YARD) do
		for _, Z in ipairs(Y.Zs) do
			local Top, Why = spotTest(hubFor(ById, Y.Id), Y.X, Z)
			table.insert(Out, ("  %s at (%d, %d): %s"):format(Y.Id, Y.X, Z, (Top and "OK " or "fails: ") .. Why))
		end
	end
	for _, Id in ipairs(TRADERS) do
		local P = one(ById, Id)
		local St = P and stallsFor(P) or {}
		local R = P and reach(hubFor(ById, Id), P.Position + Vector3.new(0, 2, 0))
		table.insert(Out, ("  %s: stall %s; reachable now: %s"):format(Id, #St == 1 and St[1].Name or (#St .. " stalls"), R and ("radius " .. R) or "no"))
	end
elseif MODE == "apply" then
	local Ok, Msg = apply()
	if not Ok then return refuse(Msg) end
	local Fails, Head, Lines = checks()
	table.insert(Out, "foundry_posts apply: " .. Msg)
	table.insert(Out, Head)
	for _, L in ipairs(Lines) do table.insert(Out, L) end
elseif MODE == "undo" then
	local Ok, Msg = undo()
	if not Ok then return refuse(Msg) end
	table.insert(Out, "foundry_posts undo: " .. Msg)
elseif MODE == "check" then
	local Fails, Head, Lines = checks()
	table.insert(Out, "foundry_posts " .. Head .. " (" .. FLAG .. " is " .. tostring(FD:GetAttribute(FLAG)) .. ")")
	for _, L in ipairs(Lines) do table.insert(Out, L) end
elseif MODE == "test" then
	if FD:GetAttribute(FLAG) ~= nil then return refuse("applied; undo first or run check") end
	local Before = snapshot()
	local Ok, Msg = apply()
	if not Ok then return refuse(Msg) end
	-- (Ruling 26) check runs in a pcall between apply and undo, so undo always runs
	local COk, Fails, Head, Lines = pcall(checks)
	if not COk then Head, Lines = "check ERROR: " .. tostring(Fails), {} end
	local UOk, UMsg = undo()
	local SOk, After = pcall(snapshot)
	local Diffs, First = 0, {}
	if SOk then Diffs, First = compare(Before, After) else Diffs, First = -1, {"snapshot ERROR: " .. tostring(After)} end
	table.insert(Out, ("foundry_posts test: %s %s; %s; round trip %s (%d rows, %d differ)"):format(Msg, Head,
		UOk and UMsg or ("UNDO FAILED: " .. UMsg), Diffs == 0 and "EXACT" or "DIFFERS", #Before, Diffs))
	for _, L in ipairs(Lines) do table.insert(Out, L) end
	for _, L in ipairs(First) do table.insert(Out, "  " .. L) end
else
	return refuse("unknown MODE " .. tostring(MODE))
end
return table.concat(Out, "\n")

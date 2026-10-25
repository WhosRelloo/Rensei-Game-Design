-- PathKit (Foundry Yard plan Task 4b, 2026-10-25): the measures Test_FoundryPaths and Test_YePaths share (one module:
-- the global "no duplicated test logic" rule). It plans every schedule change of a region's roster with
-- TownsfolkService.Mover.PlanPath and measures the result with its own geometry code, not the Mover's:
--   * Pairs: each change of post in each schedule (A -> B, once per distinct pair), from where a rig's root stands at A
--     to B's standing CFrame (3 over the post, as TownsfolkService.StandAt).
--   * Valid: a waist-height ray (2.5 over the ground point) along every leg of the planned path, the goal leg too, with
--     the Mover's filters (characters left out, colliding parts only, the Townsfolk collision group). Any hit fails.
--   * Vertices: every vertex the repair inserted has a clearance (signed distance from its waist point to the nearest
--     colliding part at body height) of at least VERTEX (1.25, the brief).
--   * Corridor: every stud along the planned path, waist rays SIDE (4) studs to both sides, across the leg; where both
--     hit, the width between them must be at least WIDTH (3.2, the brief).
--   * Sight: along the smoothed path (what the walker walks), every stud, a ray from the waist to the waist over the
--     leg's end, SIGHT (12) studs at most (the Mover's sight rule): 0 hits.
--   * Body: along the planned and the smoothed path, a sphere of BODY (1: half a rig's 2-stud root) swept at waist
--     height down every leg hits nothing, outside END (3) studs of the path's own two ends (walkers got stuck on lamp
--     posts, stall posts and house plinths their centre line passed: Play_FoundryWalks, 2026-10-25).
--   * Stands: at every post a schedule change uses and every Shelter post of the region's map (flee walks end there),
--     the standing rig's body axis (from 1 stud over the ground under its root, above a kerb or a step, to 5.5, a
--     head's height) is AXIS (0.5, half an R6 torso's depth) or more from every colliding part: a post inside a
--     building, or with a well's rim through the rig's legs, can't be walked to or from.
-- Survey(Region, Opts) -> {Pairs = n, Rows = {{Id, From, To, Status, Why, Radius, Inserted, Fails = {...}}}, Ms}.
-- Suite(Region, Pairs, MapOf) -> the test table both path suites return (one survey per run, shared by its tests).
local SSS = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")

local PathKit = {}
PathKit.WIDTH = 3.2 -- (the brief) the narrowest corridor a path may use
PathKit.VERTEX = 1.25 -- (the brief) an inserted vertex's clearance at least
PathKit.SIGHT = 12 -- (Mover.SightRange) the sight ray's reach
PathKit.SIDE = 4 -- corridor rays this far to each side
PathKit.WAIST = 2.5 -- (Mover.WaistHeight) over the ground
PathKit.BODY = 1 -- PROPOSAL (Mover.BodyRadius): a walker's body half-width at waist height
PathKit.END = 3 -- PROPOSAL (Mover.BodyEndClear): the body check leaves out this much round the path's ends
PathKit.AXIS = 0.5 -- PROPOSAL: a standing rig's body axis is at least this far from anything solid (half a torso's depth)
local W = Vector3.new(0, PathKit.WAIST, 0)

local function Flat(V) return Vector3.new(V.X, 0, V.Z) end

-- the Mover's geometry filters: World.Live (townsfolk, enemies) and player characters left out, colliding parts only
function PathKit.Params()
	local Skip = {}
	local World = workspace:FindFirstChild("World")
	local Live = World and World:FindFirstChild("Live")
	if Live then table.insert(Skip, Live) end
	for _, P in ipairs(game.Players:GetPlayers()) do if P.Character then table.insert(Skip, P.Character) end end
	local Group = PhysicsService:IsCollisionGroupRegistered("Townsfolk") and "Townsfolk" or "Default"
	local Ray = RaycastParams.new()
	Ray.FilterType = Enum.RaycastFilterType.Exclude
	Ray.FilterDescendantsInstances = Skip
	Ray.RespectCanCollide = true
	Ray.IgnoreWater = true
	Ray.CollisionGroup = Group
	local Box = OverlapParams.new()
	Box.FilterType = Enum.RaycastFilterType.Exclude
	Box.FilterDescendantsInstances = Skip
	Box.RespectCanCollide = true
	Box.CollisionGroup = Group
	return Ray, Box
end

-- the RenseiPosts in workspace (under Under, if given): {[PostId] = Part}
function PathKit.Posts(Under)
	local Out = {}
	for _, P in ipairs(CollectionService:GetTagged("RenseiPost")) do
		if P:IsA("BasePart") and P:IsDescendantOf(Under or workspace) and type(P:GetAttribute("PostId")) == "string" then
			Out[P:GetAttribute("PostId")] = P
		end
	end
	return Out
end

-- where a rig's root stands at a post, and the standing CFrame (TownsfolkService.StandAt)
function PathKit.Stand(Post)
	local Pos = (Post.CFrame * CFrame.new(0, 3, 0)).Position
	local L = Flat(Post.CFrame.LookVector)
	if L.Magnitude < 1e-3 then L = Vector3.new(0, 0, -1) end
	return Pos, CFrame.lookAt(Pos, Pos + L)
end

-- every distinct change of post in the roster's schedules (the last entry wraps to the first): {{Id, From, To}}
function PathKit.Pairs(Roster)
	local Out, Seen = {}, {}
	for _, D in ipairs(Roster) do
		local S = D.Schedule
		for I = 1, #S do
			local A, B = S[I][3], S[I % #S + 1][3]
			if A ~= B and not Seen[A .. ">" .. B] then
				Seen[A .. ">" .. B] = true
				table.insert(Out, {D.Id, A, B})
			end
		end
	end
	return Out
end

-- signed distance from X to a part (blocks, balls and cylinders by shape; anything else by its box)
local function SD(Part, X)
	local Q = Part.CFrame:PointToObjectSpace(X)
	local H = Part.Size / 2
	if Part:IsA("Part") and Part.Shape == Enum.PartType.Cylinder then
		local R = math.min(H.Y, H.Z)
		local Ax = math.abs(Q.X) - H.X
		local Rad = math.sqrt(Q.Y * Q.Y + Q.Z * Q.Z) - R
		return Vector2.new(math.max(Ax, 0), math.max(Rad, 0)).Magnitude + math.min(math.max(Ax, Rad), 0)
	elseif Part:IsA("Part") and Part.Shape == Enum.PartType.Ball then
		return Q.Magnitude - math.min(H.X, H.Y, H.Z)
	end
	local D = Vector3.new(math.abs(Q.X), math.abs(Q.Y), math.abs(Q.Z)) - H
	return Vector3.new(math.max(D.X, 0), math.max(D.Y, 0), math.max(D.Z, 0)).Magnitude + math.min(math.max(D.X, D.Y, D.Z), 0)
end

-- the clearance of a ground point G: the signed distance from its waist point to the nearest colliding part at body
-- height (1 to 5.5 over the ground) within 4 studs, and that part. Exact: only blocks, cylinders and balls (whose
-- distance is exact; a wedge or a mesh is measured by its box, which a ramp's walkers stand inside)
function PathKit.Clearance(G, Box, Exact)
	local Ps = workspace:GetPartBoundsInBox(CFrame.new(G + Vector3.new(0, 3.25, 0)), Vector3.new(8, 4.5, 8), Box)
	local Best, Who = math.huge, nil
	for _, P in ipairs(Ps) do
		if not P:IsA("Terrain") and not (Exact and not (P.ClassName == "Part" and (P.Shape == Enum.PartType.Block
			or P.Shape == Enum.PartType.Cylinder or P.Shape == Enum.PartType.Ball))) then
			local D = SD(P, G + W)
			if D < Best then Best, Who = D, P end
		end
	end
	return Best, Who
end

local function Name(I)
	if not I then return "-" end
	return (I.Parent and I.Parent.Name or "?") .. "." .. I.Name
end

-- the legs of Pts (ground points) whose waist ray hits: {"leg k: Part at (x, z)"}
function PathKit.ValidHits(Pts, Ray)
	local Out = {}
	for I = 1, #Pts - 1 do
		local H = workspace:Raycast(Pts[I] + W, Pts[I + 1] - Pts[I], Ray)
		if H then table.insert(Out, ("leg %d: %s at (%.0f, %.0f)"):format(I, Name(H.Instance), H.Position.X, H.Position.Z)) end
	end
	return Out
end

-- the legs of Pts whose body sweep (a BODY sphere at waist height) hits something, outside END of Pts' first and last
-- points (flat), the sweep's own start included (its clearance under BODY): {"leg k: Part at (x, z)"}
function PathKit.BodyHits(Pts, Ray, Box)
	local Out = {}
	local From, To = Pts[1], Pts[#Pts]
	for I = 1, #Pts - 1 do
		local A, B = Pts[I], Pts[I + 1]
		local F = Flat(B - A)
		local L = F.Magnitude
		if L > 1e-3 then
			-- the part of the leg outside both end circles: sample it at 0.1-stud steps
			local T0, T1 = nil, nil
			local N = math.max(1, math.ceil(L / 0.1))
			for K = 0, N do
				local P = A:Lerp(B, K / N)
				if Flat(P - From).Magnitude >= PathKit.END and Flat(P - To).Magnitude >= PathKit.END then
					T0 = T0 or K / N
					T1 = K / N
				end
			end
			if T0 and T1 > T0 then
				local S, E = A:Lerp(B, T0), A:Lerp(B, T1)
				-- (a cast ignores what it starts inside: the body where the sweep starts is measured too)
				local C, Who = PathKit.Clearance(S, Box, true)
				if C < PathKit.BODY then
					table.insert(Out, ("leg %d: starts %.2f from %s at (%.0f, %.0f)"):format(I, C, Name(Who), S.X, S.Z))
				else
					local H = workspace:Spherecast(S + W, PathKit.BODY, E - S, Ray)
					if H then table.insert(Out, ("leg %d: %s at (%.0f, %.0f)"):format(I, Name(H.Instance), H.Position.X, H.Position.Z)) end
				end
			end
		end
	end
	return Out
end

-- the narrowest corridor along Pts: every stud of each leg, waist rays SIDE studs to both sides; where both hit, the
-- width. Returns the width (math.huge when never boxed in), where and between what
function PathKit.Corridor(Pts, Ray)
	local Min, Where = math.huge, ""
	for I = 1, #Pts - 1 do
		local A, B = Pts[I], Pts[I + 1]
		local F = Flat(B - A)
		if F.Magnitude > 0.1 then
			local Right = Vector3.new(-F.Unit.Z, 0, F.Unit.X)
			local K = math.max(1, math.floor(F.Magnitude))
			for S = 0, K do
				local O = A:Lerp(B, S / K) + W
				local L = workspace:Raycast(O, Right * PathKit.SIDE, Ray)
				local R = workspace:Raycast(O, -Right * PathKit.SIDE, Ray)
				if L and R then
					local Wd = (L.Position - O).Magnitude + (R.Position - O).Magnitude
					if Wd < Min then Min, Where = Wd, ("%s | %s at (%.0f, %.0f)"):format(Name(L.Instance), Name(R.Instance), O.X, O.Z) end
				end
			end
		end
	end
	return Min, Where
end

-- the sight ray's hits along the smoothed path: from every stud of each leg to the waist over the leg's end
function PathKit.SightHits(Wps, Ray)
	local N, First = 0, nil
	for I = 1, #Wps - 1 do
		local A, B = Wps[I], Wps[I + 1]
		local K = math.max(1, math.floor(Flat(B - A).Magnitude))
		for S = 0, K - 1 do
			local P = A:Lerp(B, S / K) + W
			local Look = B + W - P
			local Len = math.min(Look.Magnitude, PathKit.SIGHT)
			if Len > 1 then
				local H = workspace:Raycast(P, Look.Unit * Len, Ray)
				if H then
					N += 1
					First = First or ("%s at (%.0f, %.0f)"):format(Name(H.Instance), H.Position.X, H.Position.Z)
				end
			end
		end
	end
	return N, First
end

-- measures one PlanPath result R (Status "ok") into Row: Inserted, MinVertex, Width, Sight, and Row.Fails (a line per
-- failed check: "valid: ...", "vertex: ...", "corridor: ...", "sight: ...", "body: ...")
function PathKit.Measure(R, Row, Ray, Box)
	if not Ray then Ray, Box = PathKit.Params() end
	Row.Fails = Row.Fails or {}
	Row.Inserted = #R.Inserted
	local Hits = PathKit.ValidHits(R.Raw, Ray)
	if #Hits > 0 then table.insert(Row.Fails, "valid: " .. table.concat(Hits, "; ")) end
	for _, V in ipairs(R.Inserted) do
		local C, Who = PathKit.Clearance(V, Box)
		Row.MinVertex = math.min(Row.MinVertex or math.huge, C)
		if C < PathKit.VERTEX then
			table.insert(Row.Fails, ("vertex: (%.1f, %.1f) clearance %.2f to %s"):format(V.X, V.Z, C, Name(Who)))
		end
	end
	local Wd, Where = PathKit.Corridor(R.Raw, Ray)
	local SWd, SWhere = PathKit.Corridor(R.Waypoints, Ray)
	Row.Width = math.min(Wd, SWd)
	if Wd < PathKit.WIDTH then table.insert(Row.Fails, ("corridor: %.2f (%s)"):format(Wd, Where)) end
	if SWd < PathKit.WIDTH then table.insert(Row.Fails, ("corridor (smoothed): %.2f (%s)"):format(SWd, SWhere)) end
	local NS, FirstS = PathKit.SightHits(R.Waypoints, Ray)
	Row.Sight = NS
	if NS > 0 then table.insert(Row.Fails, ("sight: %d hits (first %s)"):format(NS, FirstS)) end
	local BR, BS = PathKit.BodyHits(R.Raw, Ray, Box), PathKit.BodyHits(R.Waypoints, Ray, Box)
	if #BR > 0 then table.insert(Row.Fails, "body: " .. table.concat(BR, "; ")) end
	if #BS > 0 then table.insert(Row.Fails, "body (smoothed): " .. table.concat(BS, "; ")) end
	return Row
end

-- plans and measures every schedule change of Townsfolk.Regions[Region]
function PathKit.Survey(Region, Opts)
	Opts = Opts or {}
	-- (Opts.Mover / Opts.Roster: another copy of either, for an Edit-mode survey of a changed module)
	local Mover = Opts.Mover or require(SSS.TownsfolkService.Mover)
	local Roster = Opts.Roster or require(game.ReplicatedStorage.Modules.Data.Rensei.Townsfolk).Regions[Region] or {}
	local Posts = PathKit.Posts()
	local Ray, Box = PathKit.Params()
	local Out = {Pairs = 0, Rows = {}}
	local T0 = os.clock()
	for _, Pr in ipairs(PathKit.Pairs(Roster)) do
		Out.Pairs += 1
		local Row = {Id = Pr[1], From = Pr[2], To = Pr[3], Fails = {}}
		table.insert(Out.Rows, Row)
		local A, B = Posts[Pr[2]], Posts[Pr[3]]
		if not (A and B) then
			Row.Status = "no post"
			table.insert(Row.Fails, "plan: a post is missing")
			continue
		end
		local From = PathKit.Stand(A)
		local _, Goal = PathKit.Stand(B)
		local Ok, R = pcall(Mover.PlanPath, From, Goal, nil, {Attempts = Opts.Attempts})
		if not Ok then R = {Status = "error", Why = tostring(R)} end
		Row.Status, Row.Why, Row.Radius = R.Status, R.Why, R.Radius
		if R.Status ~= "ok" then
			table.insert(Row.Fails, "plan: " .. tostring(R.Status) .. " (" .. tostring(R.Why) .. ")")
			continue
		end
		PathKit.Measure(R, Row, Ray, Box)
	end
	Out.Ms = (os.clock() - T0) * 1000
	return Out
end

-- the rows failing one kind of check ("plan", "valid", "vertex", "corridor", "sight"): {"#n Id From>To: why"}
function PathKit.Failing(Survey, Kind)
	local Out = {}
	for I, Row in ipairs(Survey.Rows) do
		for _, F in ipairs(Row.Fails) do
			if F:sub(1, #Kind) == Kind then table.insert(Out, ("#%d %s %s>%s: %s"):format(I, Row.Id, Row.From, Row.To, F)) end
		end
	end
	return Out
end

-- what a rig standing at Post would be in: the colliding parts within AXIS of its body axis (the vertical line from 1
-- over the ground under its standing root to 5.5 over it), each with its distance; "no ground" when nothing is within
-- 5 studs under the root (posts and characters left out)
function PathKit.Solid(Post)
	local Ray, Box = PathKit.Params()
	local Skip = Box.FilterDescendantsInstances
	for _, P in ipairs(CollectionService:GetTagged("RenseiPost")) do table.insert(Skip, P) end
	Box.FilterDescendantsInstances = Skip
	Ray.FilterDescendantsInstances = Skip
	Ray.IgnoreWater = false
	local Root = PathKit.Stand(Post)
	local Down = workspace:Raycast(Root, Vector3.new(0, -5, 0), Ray)
	if not Down then return {"no ground"} end
	local G = Down.Position
	local Out = {}
	for _, P in ipairs(workspace:GetPartBoundsInBox(CFrame.new(G + Vector3.new(0, 3.25, 0)), Vector3.new(3, 5.5, 3), Box)) do
		if not P:IsA("Terrain") then
			local Min = math.huge
			for H = 1, 5.5, 0.25 do Min = math.min(Min, SD(P, G + Vector3.new(0, H, 0))) end
			if Min < PathKit.AXIS then table.insert(Out, ("%s (%.2f)"):format(Name(P), Min)) end
		end
	end
	return Out
end

-- the test table of Test_FoundryPaths / Test_YePaths: Region's roster, Pairs changes expected, MapOf() -> the region's
-- map model (its Shelter posts are stand-checked). TestKit runs tests sorted by name: the first plans everything once
-- (Survey), each test reads its share, the last forgets it.
function PathKit.Suite(Region, Pairs, MapOf)
	local Cache = nil
	local Names = {"Body", "Corridor", "Plans", "Sight", "Stands", "Valid", "Vertices"}
	local function Get(Name)
		if Name == Names[1] or not Cache then Cache = PathKit.Survey(Region) end
		local S = Cache
		if Name == Names[#Names] then Cache = nil end
		return S
	end
	local function Expect(T, Name, Kind, What)
		local S = Get(Name)
		local Bad = PathKit.Failing(S, Kind)
		-- (a change that didn't plan can't be measured: it fails this check too, never passes it unseen)
		for I, Row in ipairs(S.Rows) do
			if Row.Status ~= "ok" then table.insert(Bad, ("#%d %s %s>%s: not planned (%s)"):format(I, Row.Id, Row.From, Row.To, tostring(Row.Why))) end
		end
		T.Eq(#Bad, 0, ("%s: %s; failing %d of %d: %s"):format(Region, What, #Bad, S.Pairs, table.concat(Bad, " | ")))
	end
	return {
		Plans = function(T)
			local S = Get("Plans")
			T.Eq(S.Pairs, Pairs, Region .. ": schedule changes")
			local Bad = PathKit.Failing(S, "plan")
			T.Eq(#Bad, 0, ("%s: every change plans (PlanPath ok); failing %d: %s"):format(Region, #Bad, table.concat(Bad, " | ")))
		end,
		Valid = function(T) Expect(T, "Valid", "valid", "every planned leg clear at waist height (Valid)") end,
		Vertices = function(T) Expect(T, "Vertices", "vertex", "every repair vertex at clearance " .. PathKit.VERTEX .. " or more") end,
		Corridor = function(T) Expect(T, "Corridor", "corridor", "a corridor at least " .. PathKit.WIDTH .. " wide everywhere") end,
		Sight = function(T) Expect(T, "Sight", "sight", "no sight-ray hit along the smoothed path") end,
		Body = function(T) Expect(T, "Body", "body", "the walker's body (radius " .. PathKit.BODY .. " at waist) clears every leg") end,
		Stands = function(T)
			Get("Stands")
			local Map = MapOf()
			T.True(Map ~= nil, Region .. "'s map is in workspace")
			local Posts = PathKit.Posts()
			local Want, Seen = {}, {}
			for _, Pr in ipairs(PathKit.Pairs(require(game.ReplicatedStorage.Modules.Data.Rensei.Townsfolk).Regions[Region] or {})) do
				for K = 2, 3 do
					if not Seen[Pr[K]] then Seen[Pr[K]] = true table.insert(Want, Pr[K]) end
				end
			end
			for Id, P in pairs(Posts) do
				if not Seen[Id] and P:IsDescendantOf(Map) and P:GetAttribute("Kind") == "Shelter" then Seen[Id] = true table.insert(Want, Id) end
			end
			table.sort(Want)
			local Bad = {}
			for _, Id in ipairs(Want) do
				local P = Posts[Id]
				if not P then table.insert(Bad, Id .. ": no such post") continue end
				local Solid = PathKit.Solid(P)
				if #Solid > 0 then table.insert(Bad, Id .. " stands in " .. table.concat(Solid, ", ")) end
			end
			T.Eq(#Bad, 0, ("%s: a rig can stand at every post of a schedule change and every shelter (%d posts); not: %s"):format(Region, #Want, table.concat(Bad, " | ")))
		end,
	}
end

return PathKit

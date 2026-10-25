-- Test_MoverRepair (Foundry Yard plan Task 4b, 2026-10-25): the Mover's corner repair (Mover.lua header 1b) on
-- synthetic geometry, through Mover.RepairPath (the repair exactly as a plan runs it: Valid first). Each test builds its
-- own fixture on a 120 x 120 Concrete floor at an empty spot far outside the map (checked empty first) and removes it
-- afterwards. The checks measure with their own code: a waist-height ray (2.5 over the floor) per leg, and the signed
-- distance from a vertex's waist point to the fixture's blocks. Run in the Play VM (LMRunSuite), in either place.
--   * CornerCutGetsAVertex   a line cutting a 10 x 8 x 10 box's corner 1 stud deep: repaired, with a vertex, every leg
--                            clear, every new vertex 1.25 or more from the box, the ends kept.
--   * WallStaysStale         a line through the middle of an 8-stud wall (8 long, 8 high, 1 thick): stays stale.
--   * PostIsRoutedRound      a line through a 0.6-stud post: repaired round it, clear, the vertices 1.25 or more off it.
--   * NarrowGapIsRefused     a line through a 2.4-stud gap between two 6 x 8 x 6 boxes, clipping one: stays stale (a
--                            vertex there could only be 1.2 from the walls, under the 1.25 minimum).
--   * ValidPathUnchanged     a line over open floor: the same points back, no vertex.
--   * BodyGoesRoundAPost     (the body rule) a line passing 0.5 studs from a 0.6-stud post: its centre line is clear,
--                            but a walker's body (radius 1 at waist) isn't: repaired round it, every leg's body sweep
--                            clear, the vertices 1.25 or more off it.
--   * HuggingPointIsEased    (the body rule) a waypoint 0.3 studs from a wall: moved off the wall to 1.25 or more,
--                            every leg's body sweep clear, the ends kept.
--   * TrenchIsNotCrossed     (fix round 1) a line clipping a post with a 1-stud trench across the floor on the side the
--                            repair pushes to: refused, or routed round with floor under every leg (rays every 0.5).
--   * CentredPostIsRoutedRound (fix round 1) a line dead through the middle of a 0.6-stud post (no gradient there):
--                            repaired round it, as PostIsRoutedRound.
--   * DearGroundIsRefused    (Task 9, the 4b re-review) a line through a post on a 2-stud Concrete strip with Grass
--                            either side; the points' labels are Concrete except the first, far leg's ("Grass": the
--                            path crosses a lawn somewhere else). A new vertex clear of the post lands on Grass, dearer
--                            than the leg's own ground: refused (stale), or routed round with Concrete under every leg.
--                            (The repair's cost cap is the leg's neighbouring labels, not the dearest on the path.)
--   * GrassLegMayUseGrass    (Task 9, Ruling 39: DearGroundIsRefused's positive case) the same post and strip, but the
--                            leg through the post is labelled Grass at both ends (the planned path walks a lawn there):
--                            the repair may push onto Grass: repaired, with a vertex, every leg clear of the post.
--   * EaseKeepsItsGround     (Task 9) a waypoint hugging a wall on a Concrete strip with Grass beyond 1.6 studs from
--                            the wall, all labels Concrete: the eased point (1.25+ off the wall) would stand on Grass, so
--                            the ease is refused; the path stays stale or keeps Concrete under every leg.
local SSS = game:GetService("ServerScriptService")
local Mover = require(SSS.TownsfolkService.Mover)

local SITES = {Vector3.new(-700, 300, -700), Vector3.new(700, 300, -700), Vector3.new(-700, 300, 700), Vector3.new(700, 300, 700)}
local FLOOR = 120
local WAIST = Vector3.new(0, 2.5, 0)
local MIN_CLEAR = 1.25 -- (the brief: Ruling 30's minimum clearance)
local BODY, END = 1, 3 -- (Mover.BodyRadius, Mover.BodyEndClear: PROPOSALS) the body sweep and the ends it leaves out

local function Site()
	for _, C in ipairs(SITES) do
		if #workspace:GetPartBoundsInBox(CFrame.new(C + Vector3.new(0, 30, 0)), Vector3.new(FLOOR + 20, 80, FLOOR + 20)) == 0 then return C end
	end
	return nil
end

-- builds the floor, runs Body(Ctx), always removes the fixture. Ctx.At(X, Z) = a floor point; Ctx.Box(X, Z, SX, SZ,
-- H?) = a block standing on the floor (centre X, Z; sizes along X and Z)
local function Fixture(T, Body, Opts)
	local O = Site()
	T.True(O ~= nil, "an empty spot for the test floor")
	local Folder = Instance.new("Folder")
	Folder.Name = "MoverRepairTest"
	local Ctx = {Boxes = {}, Floors = {}}
	local Top = O.Y + 1
	function Ctx.At(X, Z) return Vector3.new(O.X + X, Top, O.Z + Z) end
	local function Part(CF, Size)
		local P = Instance.new("Part")
		P.Anchored = true
		P.Size = Size
		P.CFrame = CF
		P.Material = Enum.Material.Concrete
		P.Parent = Folder
		return P
	end
	local Tr = Opts and Opts.Trench -- {Z0, Z1}: no floor between them, across the whole floor
	local St = Opts and Opts.Strip -- {Z0, Z1}: Concrete between them, Grass on either side (across the whole floor)
	if St then
		local Lo, Hi = -FLOOR / 2, FLOOR / 2
		local G1 = Part(CFrame.new(O + Vector3.new(0, 0, (Lo + St[1]) / 2)), Vector3.new(FLOOR, 2, St[1] - Lo))
		local G2 = Part(CFrame.new(O + Vector3.new(0, 0, (St[2] + Hi) / 2)), Vector3.new(FLOOR, 2, Hi - St[2]))
		G1.Material, G2.Material = Enum.Material.Grass, Enum.Material.Grass
		table.insert(Ctx.Floors, G1)
		table.insert(Ctx.Floors, Part(CFrame.new(O + Vector3.new(0, 0, (St[1] + St[2]) / 2)), Vector3.new(FLOOR, 2, St[2] - St[1])))
		table.insert(Ctx.Floors, G2)
	elseif Tr then
		local Lo, Hi = -FLOOR / 2, FLOOR / 2
		table.insert(Ctx.Floors, Part(CFrame.new(O + Vector3.new(0, 0, (Lo + Tr[1]) / 2)), Vector3.new(FLOOR, 2, Tr[1] - Lo)))
		table.insert(Ctx.Floors, Part(CFrame.new(O + Vector3.new(0, 0, (Tr[2] + Hi) / 2)), Vector3.new(FLOOR, 2, Hi - Tr[2])))
	else
		table.insert(Ctx.Floors, Part(CFrame.new(O), Vector3.new(FLOOR, 2, FLOOR)))
	end
	function Ctx.Box(X, Z, SX, SZ, H)
		H = H or 8
		local P = Part(CFrame.new(Ctx.At(X, Z) + Vector3.new(0, H / 2, 0)), Vector3.new(SX, H, SZ))
		table.insert(Ctx.Boxes, P)
		return P
	end
	Folder.Parent = workspace
	local Ok, Err = pcall(Body, Ctx)
	Folder:Destroy()
	if not Ok then error(Err, 0) end
end

-- the test's own measures
local Ray = RaycastParams.new()
Ray.FilterType = Enum.RaycastFilterType.Include
local function ClearLegs(Ctx, Pts) -- {"leg k hits X"} with the fixture's blocks as the only obstacles
	Ray.FilterDescendantsInstances = Ctx.Boxes
	local Out = {}
	for I = 1, #Pts - 1 do
		local H = workspace:Raycast(Pts[I] + WAIST, Pts[I + 1] - Pts[I], Ray)
		if H then table.insert(Out, ("leg %d hits %s"):format(I, H.Instance.Name)) end
	end
	return Out
end
local function BoxDist(P, X) -- signed distance from X to a block
	local Q = P.CFrame:PointToObjectSpace(X)
	local D = Vector3.new(math.abs(Q.X), math.abs(Q.Y), math.abs(Q.Z)) - P.Size / 2
	return Vector3.new(math.max(D.X, 0), math.max(D.Y, 0), math.max(D.Z, 0)).Magnitude + math.min(math.max(D.X, D.Y, D.Z), 0)
end
local function Clearance(Ctx, V)
	local M = math.huge
	for _, P in ipairs(Ctx.Boxes) do M = math.min(M, BoxDist(P, V + WAIST)) end
	return M
end
local function Same(A, B) return (A - B).Magnitude < 1e-3 end
-- {"leg k: no floor at (x, z)"}: a ray down every 0.5 studs of each leg must meet the fixture's floor within 3
local Down = RaycastParams.new()
Down.FilterType = Enum.RaycastFilterType.Include
local function GroundLegs(Ctx, Pts)
	Down.FilterDescendantsInstances = Ctx.Floors
	local Out = {}
	for I = 1, #Pts - 1 do
		local A, B = Pts[I], Pts[I + 1]
		local N = math.max(1, math.ceil((B - A).Magnitude / 0.5))
		for K = 0, N do
			local P = A:Lerp(B, K / N)
			if not workspace:Raycast(P + Vector3.new(0, 1.5, 0), Vector3.new(0, -4.5, 0), Down) then
				table.insert(Out, ("leg %d: no floor at (%.1f, %.1f)"):format(I, P.X, P.Z))
				break
			end
		end
	end
	return Out
end
local function Flat(V) return Vector3.new(V.X, 0, V.Z) end
-- {"leg k: Grass at (x, z)"}: a ray down every 0.5 studs of each leg must meet Concrete floor
local function ConcreteLegs(Ctx, Pts)
	Down.FilterDescendantsInstances = Ctx.Floors
	local Out = {}
	for I = 1, #Pts - 1 do
		local A, B = Pts[I], Pts[I + 1]
		local N = math.max(1, math.ceil((B - A).Magnitude / 0.5))
		for K = 0, N do
			local P = A:Lerp(B, K / N)
			local H = workspace:Raycast(P + Vector3.new(0, 1.5, 0), Vector3.new(0, -4.5, 0), Down)
			if not H or H.Material ~= Enum.Material.Concrete then
				table.insert(Out, ("leg %d: %s at (%.1f, %.1f)"):format(I, H and H.Material.Name or "no floor", P.X, P.Z))
				break
			end
		end
	end
	return Out
end
-- {"leg k body hits X"}: a BODY sphere swept at waist height down each leg, outside END of the path's two ends
local function BodyLegs(Ctx, Pts)
	Ray.FilterDescendantsInstances = Ctx.Boxes
	local Out = {}
	for I = 1, #Pts - 1 do
		local A, B = Pts[I], Pts[I + 1]
		local T0, T1
		for K = 0, 100 do
			local P = A:Lerp(B, K / 100)
			if Flat(P - Pts[1]).Magnitude >= END and Flat(P - Pts[#Pts]).Magnitude >= END then T0 = T0 or K / 100 T1 = K / 100 end
		end
		if T0 and T1 > T0 then
			local S = A:Lerp(B, T0)
			local H = workspace:Spherecast(S + WAIST, BODY, A:Lerp(B, T1) - S, Ray)
			if H then table.insert(Out, ("leg %d body hits %s"):format(I, H.Instance.Name)) end
		end
	end
	return Out
end

-- a repaired path: valid by the test's own rays, every new vertex MIN_CLEAR or more from the blocks, the ends kept
local function Repaired(T, Ctx, Pts, What, Labels)
	local Out, Added = Mover.RepairPath(Pts, Labels) -- (Labels: optional, the points' labels)
	T.True(Out ~= nil, What .. ": repaired (not stale: " .. tostring(Added) .. ")")
	T.True(#Added >= 1, What .. ": at least one vertex was inserted")
	T.Eq(#Out, #Pts + #Added, What .. ": the path is the old points plus the vertices")
	local Hits = ClearLegs(Ctx, Out)
	T.Eq(#Hits, 0, What .. ": every leg clear at waist height (" .. table.concat(Hits, ", ") .. ")")
	for _, V in ipairs(Added) do
		local C = Clearance(Ctx, V)
		T.True(C >= MIN_CLEAR - 1e-3, ("%s: vertex clearance %.2f (at least %.2f)"):format(What, C, MIN_CLEAR))
	end
	T.True(Same(Out[1], Pts[1]) and Same(Out[#Out], Pts[#Pts]), What .. ": the same start and end")
	return Out, Added
end

return {
	CornerCutGetsAVertex = function(T)
		Fixture(T, function(Ctx)
			Ctx.Box(0, 0, 10, 10) -- x, z -5..5: its corner at (5, 5)
			-- the line x + z = 10 - sqrt(2): 1 stud inside the corner
			local K = 10 - math.sqrt(2)
			local Pts = {Ctx.At(-6, K + 6), Ctx.At(K + 6, -6)}
			T.True(#ClearLegs(Ctx, Pts) > 0, "the line does cut the box")
			Repaired(T, Ctx, Pts, "corner cut")
		end)
	end,

	WallStaysStale = function(T)
		Fixture(T, function(Ctx)
			Ctx.Box(0, 0, 8, 1) -- 8 long (x), 1 thick (z), 8 high
			local Out, Why = Mover.RepairPath({Ctx.At(0, -10), Ctx.At(0, 10)})
			T.Eq(Out, nil, "a path through the middle of the wall is not repaired")
			T.Eq(Why, "stale", "it stays stale")
		end)
	end,

	PostIsRoutedRound = function(T)
		Fixture(T, function(Ctx)
			Ctx.Box(0, 0, 0.6, 0.6) -- a lamp post
			local Pts = {Ctx.At(-12, 0.1), Ctx.At(12, 0.1)}
			T.True(#ClearLegs(Ctx, Pts) > 0, "the line does run through the post")
			Repaired(T, Ctx, Pts, "post")
		end)
	end,

	NarrowGapIsRefused = function(T)
		Fixture(T, function(Ctx)
			Ctx.Box(-4.2, 0, 6, 6) -- x -7.2..-1.2
			Ctx.Box(4.2, 0, 6, 6) -- x 1.2..7.2: a 2.4-stud gap at x -1.2..1.2, z -3..3
			local Pts = {Ctx.At(-3, -10), Ctx.At(1.5, 10)} -- through the gap, clipping the first box's corner
			T.True(#ClearLegs(Ctx, Pts) > 0, "the line does clip a box")
			local Out, Why = Mover.RepairPath(Pts)
			T.Eq(Out, nil, "no repair squeezes through a 2.4-stud gap")
			T.Eq(Why, "stale", "it stays stale")
		end)
	end,

	BodyGoesRoundAPost = function(T)
		Fixture(T, function(Ctx)
			Ctx.Box(0, 0, 0.6, 0.6) -- a lamp post: its surface at z 0.3
			local Pts = {Ctx.At(-14, 0.8), Ctx.At(14, 0.8)} -- 0.5 off it
			T.Eq(#ClearLegs(Ctx, Pts), 0, "the centre line is clear")
			T.True(#BodyLegs(Ctx, Pts) > 0, "the body isn't")
			local Out = Repaired(T, Ctx, Pts, "body past a post")
			local B = BodyLegs(Ctx, Out)
			T.Eq(#B, 0, "every leg clear for the body (" .. table.concat(B, ", ") .. ")")
		end)
	end,

	HuggingPointIsEased = function(T)
		Fixture(T, function(Ctx)
			local Wall = Ctx.Box(0, 0, 20, 1) -- x -10..10, its face at z 0.5
			local Pts = {Ctx.At(-14, 4), Ctx.At(0, 0.8), Ctx.At(14, 4)} -- the middle point 0.3 off the wall
			T.Eq(#ClearLegs(Ctx, Pts), 0, "the centre line is clear")
			T.True(#BodyLegs(Ctx, Pts) > 0, "the body isn't")
			local Out = Mover.RepairPath(Pts)
			T.True(Out ~= nil, "repaired (not stale)")
			T.True(Same(Out[1], Pts[1]) and Same(Out[#Out], Pts[#Pts]), "the same start and end")
			-- the point that replaced the hugging one: the one nearest it
			local Near, D = nil, math.huge
			for I = 2, #Out - 1 do
				local Dd = Flat(Out[I] - Pts[2]).Magnitude
				if Dd < D then Near, D = Out[I], Dd end
			end
			T.True(Near ~= nil and not Same(Near, Pts[2]), "the hugging point moved")
			T.True(Clearance(Ctx, Near) >= MIN_CLEAR - 1e-3, ("now %.2f off the wall (at least %.2f)"):format(Clearance(Ctx, Near), MIN_CLEAR))
			T.Eq(#ClearLegs(Ctx, Out), 0, "every leg's centre line clear")
			local B = BodyLegs(Ctx, Out)
			T.Eq(#B, 0, "every leg clear for the body (" .. table.concat(B, ", ") .. ")")
		end)
	end,

	TrenchIsNotCrossed = function(T)
		Fixture(T, function(Ctx)
			Ctx.Box(0, 0, 0.6, 0.6) -- a post: its surface at z 0.3, the repair pushes to +z...
			local Pts = {Ctx.At(-12, 0.1), Ctx.At(12, 0.1)}
			T.True(#ClearLegs(Ctx, Pts) > 0, "the line runs through the post")
			T.Eq(#GroundLegs(Ctx, Pts), 0, "the line itself has floor all along")
			local Out, Why = Mover.RepairPath(Pts)
			if Out then
				local G = GroundLegs(Ctx, Out)
				T.Eq(#G, 0, "a repair routed round keeps floor under every leg (" .. table.concat(G, ", ") .. ")")
				T.Eq(#ClearLegs(Ctx, Out), 0, "and clears the post")
			else
				T.Eq(Why, "stale", "or the repair is refused")
			end
		end, {Trench = {0.8, 1.8}}) -- ...where a 1-stud trench crosses the floor (z 0.8..1.8)
	end,

	CentredPostIsRoutedRound = function(T)
		Fixture(T, function(Ctx)
			Ctx.Box(0, 0, 0.6, 0.6)
			local Pts = {Ctx.At(-12, 0), Ctx.At(12, 0)} -- dead through its middle
			local Out = Repaired(T, Ctx, Pts, "centred post")
			local B = BodyLegs(Ctx, Out)
			T.Eq(#B, 0, "every leg clear for the body (" .. table.concat(B, ", ") .. ")")
		end)
	end,

	DearGroundIsRefused = function(T)
		Fixture(T, function(Ctx)
			Ctx.Box(0, 4, 0.6, 0.6) -- a post: x -0.3..0.3, z 3.7..4.3, in the middle of the Concrete strip (z 3..5)
			local Pts = {Ctx.At(-40, 4.1), Ctx.At(-12, 4.1), Ctx.At(12, 4.1), Ctx.At(30, 4.1)}
			local Labels = {"Grass", "Concrete", "Concrete", "Concrete"} -- (the far first leg crosses a lawn elsewhere)
			T.True(#ClearLegs(Ctx, Pts) > 0, "the line runs through the post")
			T.Eq(#ConcreteLegs(Ctx, {Pts[2], Pts[3]}), 0, "the leg through the post runs on Concrete")
			local Out, Why = Mover.RepairPath(Pts, Labels)
			if Out then
				local G = ConcreteLegs(Ctx, {table.unpack(Out, 2, #Out - 1)})
				T.Eq(#G, 0, "a repair keeps Concrete under the legs round the post, as the leg's own labels (" .. table.concat(G, ", ") .. ")")
				T.Eq(#ClearLegs(Ctx, Out), 0, "and clears the post")
			else
				T.Eq(Why, "stale", "or the repair is refused")
			end
		end, {Strip = {3, 5}})
	end,

	GrassLegMayUseGrass = function(T)
		Fixture(T, function(Ctx)
			Ctx.Box(0, 4, 0.6, 0.6) -- the same post on the same Concrete strip (z 3..5), Grass either side
			local Pts = {Ctx.At(-40, 4.1), Ctx.At(-12, 4.1), Ctx.At(12, 4.1), Ctx.At(30, 4.1)}
			local Labels = {"Concrete", "Grass", "Grass", "Concrete"} -- (the leg's own ends are Grass)
			T.True(#ClearLegs(Ctx, Pts) > 0, "the line runs through the post")
			local Out, Added = Repaired(T, Ctx, Pts, "a Grass leg past a post", Labels)
			local OnGrass = 0
			for _, L in ipairs(ConcreteLegs(Ctx, Out)) do if string.find(L, "Grass", 1, true) then OnGrass += 1 end end
			T.True(OnGrass > 0, "the repaired legs use the Grass beside the strip (" .. #Added .. " vertices)")
		end, {Strip = {3, 5}})
	end,

	EaseKeepsItsGround = function(T)
		Fixture(T, function(Ctx)
			Ctx.Box(0, 0, 20, 1) -- x -10..10, its face at z 0.5
			local Pts = {Ctx.At(-14, 1.0), Ctx.At(0, 0.8), Ctx.At(14, 1.0)} -- the middle point 0.3 off the wall
			local Labels = {"Concrete", "Concrete", "Concrete"}
			T.Eq(#ClearLegs(Ctx, Pts), 0, "the centre line is clear")
			T.True(#BodyLegs(Ctx, Pts) > 0, "the body isn't")
			T.Eq(#ConcreteLegs(Ctx, Pts), 0, "the path runs on Concrete")
			local Out, Why = Mover.RepairPath(Pts, Labels)
			if Out then
				local G = ConcreteLegs(Ctx, Out)
				T.Eq(#G, 0, "an eased or repaired path keeps Concrete under every leg (" .. table.concat(G, ", ") .. ")")
			else
				T.Eq(Why, "stale", "or the ease is refused and the path stays stale")
			end
		end, {Strip = {-30, 1.6}}) -- Concrete from z -30 to 1.6 (1.1 off the wall's face); Grass beyond
	end,

	ValidPathUnchanged = function(T)
		Fixture(T, function(Ctx)
			Ctx.Box(0, 20, 6, 6) -- (something on the floor, well away from the line)
			local Pts = {Ctx.At(-20, 0), Ctx.At(0, 6), Ctx.At(20, 0)}
			T.Eq(#ClearLegs(Ctx, Pts), 0, "the line is clear")
			local Out, Added = Mover.RepairPath(Pts)
			T.True(Out ~= nil, "not stale")
			T.Eq(#Added, 0, "no vertex")
			T.Eq(#Out, #Pts, "the same number of points")
			for I = 1, #Pts do T.True(Same(Out[I], Pts[I]), "point " .. I .. " unchanged") end
		end)
	end,
}

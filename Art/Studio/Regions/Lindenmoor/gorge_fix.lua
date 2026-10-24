--!nocheck
-- gorge_fix.lua — Lindenmoor import, Ruling 23 (owner, 2026-10-24: "fix this bridge & gorge part, it's too it's weird
-- and uncentered. Also make sure the water is covering the bottom of the gorge. I don't want to see the ground here").
-- Runs in Ye (placeId 106992859583940), Edit, through the MCP bridge:
--   python -I Art/Tools/rbxc.py luau "placeId: 106992859583940" Edit @<this file or a bundle>
-- (bundle_gorge_fix.py sets MODE; or edit the MODE line by hand.)
--
-- MODE = "plan"  read-only: measures and prints the bridge plan (old -> new) and the water plan. Changes nothing.
-- MODE = "apply" refuses if LindenmoorExpansion has the attribute LindenmoorGorgeFix or the backup folder exists.
--   (a) Footbridge_footbridge: every original piece (13 Deck, 14 Post, 4 Rope, 4 Tower, 2 Lintel) moves into
--       ServerStorage.RenseiBackups[BACKUP].Pieces (same instances, so tags/attributes stay; GorgeFixFrom = old full
--       path; Parents/Refs ObjectValues record where each came from). Clones of the same parts are laid as one straight
--       span, square to the gorge (along Z) and centred on the measured rims' midline, bearing BEAR studs on each rim,
--       its top PROUD above the rim ground at each end (the rims differ: south 34, north 30, so the straight deck has
--       an even ~3.8 degree grade instead of the old sag and the 3.4-stud stagger); vertical posts and two rope rails
--       per side, plus a timber handrail per side (2 new clones of the posts); vertical gate arches (towers + lintel)
--       at the deck ends.
--   (b) Landings: the gorge-crossing route stopped 26-28 studs short of the new deck ends, and the north end ran down
--       Ribbon184 into a 6-stud route pit (ground tops 24-28). The pit's top cells are rebuilt (clones, originals to
--       the backup) up to the north rim height; Ribbon184 is re-laid level from the deck's north end to Ribbon185; a
--       new clone of Ribbon183 links the south path to the deck's south end.
--   (c) Water: for the gorge (Gorge Pool seam to the waterfall) and the west creek channel, every 4-stud cell whose
--       expansion ground top is below TOP (5.2) and that is connected to the existing channel water but not already
--       covered (Terrain:ReadVoxels: water occupancy >= 0.74 in voxel row y 0-4 and >= 0.29 in row y 4-8) is filled
--       with Water from BED (1) to TOP, in rects aligned to the 4-stud voxel grid. The terrain under each region is
--       snapshotted first (Terrain:CopyRegion into the backup). Cells left alone: the village (Ye's own creek; gorge
--       x < 336, creek x > -336), pockets not connected to the channel, and cells under the waterfall's Rock.
--   Every change is journaled; any error rolls the journal back. One ChangeHistory recording/waypoint.
-- MODE = "undo"  puts every original back where it was, removes the clones, pastes the terrain snapshots back,
--   clears the attribute, removes the backup folder (and RenseiBackups if apply created it and it is empty).
-- MODE = "check" read-only: the post-apply checks (water grid, deck straight/level/centred/walkable, arches, the
--   ledge walk and waterfall signatures recorded at apply).
-- Every invented number below is a PROPOSAL.
local MODE = "plan" -- "plan", "apply", "undo" or "check"

local SS = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")
local Terrain = workspace.Terrain

local BACKUP = "Pre-GorgeFix_2026-10-24"
local ATTR = "LindenmoorGorgeFix"
local NEW = "GorgeFixNew" -- on every part this script adds
local FROM = "GorgeFixFrom" -- on every original while it is in the backup: its old full path
local TOP, BED = 5.2, 1.0 -- the channel water surface and bed (water_segments.json, world studs)
local CELL = 4 -- terrain voxel and ground cell size; both grids sit on multiples of 4
-- bridge (PROPOSAL)
local BRIDGE_X = 772 -- the gorge walls run straight along X for x 768..800 (south lip z -568, north lip z -520)
local CROSS_Z = -544 -- a point on the gorge floor under the crossing (rim search starts here)
local BEAR = 6 -- deck bears this far onto each rim past the lip
local PROUD = 0.25 -- deck top above the rim ground at each end
local DECK_T, DECK_W = 0.5, 5
local POST_H, POST_X, POST_N = 4, 2.6, 7 -- per side, evenly from lip to lip
local ROPE_H = {1.2, 2.4} -- rope centres above the deck top
local RAIL_H = 3.25 -- handrail centre above the deck top (its top = the post tops)
local TOWER_X, TOWER_SINK, TOWER_H = 3.2, 1, 9
local LINTEL_UP = 9.2 -- lintel centre above the tower bottom (as built: end_y - 1 + 9.2)
local PIT_BOX = {752, 776, -502, -482} -- x0, x1, z0, z1: the route pit at the old north landing
local RIBBON_OVERLAP = 0.3
-- water regions (world studs, multiples of 4); keep(x0) says whether a cell (x0..x0+4) is the expansion's
local WATER = {
	{Id = "gorge", x0 = 328, x1 = 1024, z0 = -624, z1 = -468, keep = function(x0) return x0 >= 336 end},
	{Id = "west", x0 = -1024, x1 = -316, z0 = -576, z1 = -476, keep = function(x0) return x0 + CELL <= -336 end},
}

local function f1(v) return string.format("(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z) end
local function refuse(why) return "GorgeFix " .. MODE .. " REFUSED: " .. why end

local World = workspace:FindFirstChild("World")
local Map = World and World:FindFirstChild("Map")
local E = Map and Map:FindFirstChild("LindenmoorExpansion")
if not E then return refuse("no workspace.World.Map.LindenmoorExpansion") end
local Gorge, Routes, Ground, Edging = E:FindFirstChild("Gorge"), E:FindFirstChild("Routes"), E:FindFirstChild("Ground"), E:FindFirstChild("Edging")
if not (Gorge and Routes and Ground and Edging) then return refuse("LindenmoorExpansion lacks Gorge/Routes/Ground/Edging") end
local FB = Gorge:FindFirstChild("Footbridge_footbridge")
local RC = Routes:FindFirstChild("Route_gorge_crossing")
local Ledge = Gorge:FindFirstChild("GorgeLedge_gorge_ledge")
local Falls = Gorge:FindFirstChild("Waterfall_waterfall")
if not (FB and RC and Ledge and Falls) then return refuse("missing Footbridge_footbridge / Route_gorge_crossing / GorgeLedge / Waterfall") end

-- ---------------------------------------------------------------- measuring
local rpG = RaycastParams.new()
rpG.FilterType = Enum.RaycastFilterType.Include
rpG.FilterDescendantsInstances = {Ground, Edging}
local function top(x, z)
	local r = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), rpG)
	return r and r.Position.Y or nil
end

local function lips(x) -- the floor run (top < TOP) through CROSS_Z: its south and north edges, 0.25 resolution
	local t = top(x, CROSS_Z)
	if not t or t >= TOP then return nil end
	local zs, zn = CROSS_Z, CROSS_Z
	while true do local tt = top(x, zs - 0.25); if not tt or tt >= TOP then break end; zs -= 0.25; if zs < CROSS_Z - 80 then return nil end end
	while true do local tt = top(x, zn + 0.25); if not tt or tt >= TOP then break end; zn += 0.25; if zn > CROSS_Z + 80 then return nil end end
	return zs - 0.125, zn + 0.125
end

local function signature(model) -- order-free fingerprint of a model's parts (name, CFrame, size, material, colour)
	local rows = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local c = {d.CFrame:GetComponents()}
			for i = 1, #c do c[i] = string.format("%.3f", c[i]) end
			table.insert(rows, d.Name .. "|" .. table.concat(c, ",") .. "|" .. f1(d.Size) .. "|" .. d.Material.Name .. "|" .. d.Color:ToHex())
		end
	end
	table.sort(rows)
	local s = table.concat(rows, ";")
	local h = 0
	for i = 1, #s do h = (h * 31 + string.byte(s, i)) % 2147483647 end
	return string.format("%d parts, %d chars, h%d", #rows, #s, h)
end

-- the bridge plan: every original piece -> its new CFrame/size; the new parts; the landing changes
local function planBridge()
	local P = {moves = {}, adds = {}, lines = {}}
	local L = P.lines
	-- rims at the deck centreline and both deck edges
	local s0, n0 = lips(BRIDGE_X)
	if not s0 then return nil, string.format("no gorge floor at (%d, %d)", BRIDGE_X, CROSS_Z) end
	for _, dx in ipairs({-DECK_W / 2, DECK_W / 2}) do
		local s1, n1 = lips(BRIDGE_X + dx)
		if not s1 or math.abs(s1 - s0) > 0.5 or math.abs(n1 - n0) > 0.5 then
			return nil, string.format("the rims are not square to the deck at x %.1f (lips %s/%s vs %.2f/%.2f)", BRIDGE_X + dx, tostring(s1), tostring(n1), s0, n0)
		end
	end
	local zc = (s0 + n0) / 2
	local zS, zN = s0 - BEAR, n0 + BEAR
	P.lipS, P.lipN, P.zc, P.zS, P.zN = s0, n0, zc, zS, zN
	local function endTop(z0, z1)
		local m = -1e9
		for _, dx in ipairs({-DECK_W / 2, 0, DECK_W / 2}) do
			for z = z0, z1, 0.5 do local t = top(BRIDGE_X + dx, z); if t then m = math.max(m, t) end end
		end
		return m
	end
	local gS, gN = endTop(zS, zS + 2), endTop(zN - 2, zN)
	local yS, yN = gS + PROUD, gN + PROUD
	P.gS, P.gN, P.yS, P.yN = gS, gN, yS, yN
	local function deckTop(z) return yS + (yN - yS) * (z - zS) / (zN - zS) end
	P.deckTop = deckTop
	local rimS, rimN = top(BRIDGE_X, s0 - 0.5), top(BRIDGE_X, n0 + 0.5)
	table.insert(L, string.format("rims at x %d: south lip z %.2f (top %.1f; %.1f behind), north lip z %.2f (top %.1f); gorge %.1f wide along X; midline z %.2f",
		BRIDGE_X, s0, rimS, gS, n0, rimN, n0 - s0, zc))
	-- clearance: the deck bottom clears the ground between its bearing ends
	for _, dx in ipairs({-DECK_W / 2, 0, DECK_W / 2}) do
		for z = zS + 2, zN - 2, 0.5 do
			local t = top(BRIDGE_X + dx, z)
			if t and t > deckTop(z) - DECK_T + 0.3 then
				return nil, string.format("ground %.2f at (%.1f, %.1f) is above the planned deck bottom %.2f", t, BRIDGE_X + dx, z, deckTop(z) - DECK_T)
			end
		end
	end
	-- the originals
	local byName, n = {}, 0
	for _, c in ipairs(FB:GetChildren()) do
		if not c:IsA("BasePart") then return nil, "Footbridge has a non-part child " .. c.Name end
		if byName[c.Name] then return nil, "Footbridge has two parts named " .. c.Name end
		byName[c.Name] = c
		n += 1
	end
	local function need(name)
		local p = byName[name]
		if not p then error("Footbridge lacks " .. name) end
		return p
	end
	local ok, err = pcall(function()
		local function seg(p0, p1, w, t, offsetDown) -- a box whose top-centre line (or centre line) runs p0 -> p1
			local mid = (p0 + p1) / 2
			local cf = CFrame.lookAt(mid, p1)
			if offsetDown then cf = cf * CFrame.new(0, -t / 2, 0) end
			return cf, Vector3.new(w, t, (p1 - p0).Magnitude)
		end
		-- deck: 13 planks end to end on one straight line
		local ND = 13
		for i = 0, ND - 1 do
			local za, zb = zS + (zN - zS) * i / ND, zS + (zN - zS) * (i + 1) / ND
			local cf, sz = seg(Vector3.new(BRIDGE_X, deckTop(za), za), Vector3.new(BRIDGE_X, deckTop(zb), zb), DECK_W, DECK_T, true)
			table.insert(P.moves, {orig = need("Deck" .. i), cf = cf, size = sz})
		end
		-- posts: 7 per side from lip to lip, vertical, standing through the deck
		local postNames = {}
		for k = 0, 12, 2 do table.insert(postNames, k) end
		for _, s in ipairs({-1, 1}) do
			for j, k in ipairs(postNames) do
				local z = s0 + (n0 - s0) * (j - 1) / (POST_N - 1)
				local cy = deckTop(z) - DECK_T + POST_H / 2
				table.insert(P.moves, {orig = need(string.format("Post%d_%d", k, s)), cf = CFrame.new(BRIDGE_X + s * POST_X, cy, z), size = Vector3.new(0.5, POST_H, 0.5)})
			end
		end
		-- gate arches at the deck ends: tower faces flush with the deck ends
		local zT = {[0] = zS + 0.6, [1] = zN - 0.6}
		P.zT = zT
		for e = 0, 1 do
			local gmax = -1e9
			for _, s in ipairs({-1, 1}) do
				local x = BRIDGE_X + s * TOWER_X
				local g = -1e9
				for _, o in ipairs({{-0.5, -0.5}, {0.5, -0.5}, {-0.5, 0.5}, {0.5, 0.5}, {0, 0}}) do
					local t = top(x + o[1], zT[e] + o[2]); if t then g = math.max(g, t) end
				end
				gmax = math.max(gmax, g)
				table.insert(P.moves, {orig = need(string.format("Tower%d_%d", e, s)), cf = CFrame.new(x, g - TOWER_SINK + TOWER_H / 2, zT[e]), size = Vector3.new(1.2, TOWER_H, 1.2)})
			end
			table.insert(P.moves, {orig = need("Lintel" .. e), cf = CFrame.new(BRIDGE_X, gmax - TOWER_SINK + LINTEL_UP, zT[e]), size = Vector3.new(8, 1, 1)})
		end
		-- rails between the arch towers: two ropes per side (originals) and one timber handrail per side (new clones)
		local r0, r1 = zT[0] + 0.6, zT[1] - 0.6
		for _, s in ipairs({-1, 1}) do
			local x = BRIDGE_X + s * POST_X
			for _, h in ipairs(ROPE_H) do
				local name = string.format("Rope%d_%s", s, h == ROPE_H[1] and "2.2" or "3.6")
				local cf, sz = seg(Vector3.new(x, deckTop(r0) + h, r0), Vector3.new(x, deckTop(r1) + h, r1), 0.25, 0.25, false)
				table.insert(P.moves, {orig = need(name), cf = cf, size = sz})
			end
			local cf, sz = seg(Vector3.new(x, deckTop(r0) + RAIL_H, r0), Vector3.new(x, deckTop(r1) + RAIL_H, r1), 0.5, 0.5, false)
			table.insert(P.adds, {src = need(string.format("Post0_%d", s)), name = string.format("Handrail%d", s), parent = FB, cf = cf, size = sz})
		end
		-- landings
		local R183, R184, R185 = RC:FindFirstChild("Ribbon183"), RC:FindFirstChild("Ribbon184"), RC:FindFirstChild("Ribbon185")
		if not (R183 and R184 and R185) then error("Route_gorge_crossing lacks Ribbon183/184/185") end
		local function ribbonEnd(r, pick) -- the top-centre point of a ribbon's end; pick(a, b) -> true to take a
			local a = r.CFrame:PointToWorldSpace(Vector3.new(0, r.Size.Y / 2, -r.Size.Z / 2))
			local b = r.CFrame:PointToWorldSpace(Vector3.new(0, r.Size.Y / 2, r.Size.Z / 2))
			if pick(a, b) then return a end
			return b
		end
		local A = ribbonEnd(R183, function(a, b) return a.Z > b.Z end) -- its north end
		local lift = A.Y - (top(A.X, A.Z) or A.Y) -- how proud the path sits on the ground
		local B = Vector3.new(BRIDGE_X, gS + lift, zS + 1)
		local dirA = (B - A).Unit
		local cf, sz = seg(A - dirA * RIBBON_OVERLAP, B, R183.Size.X, R183.Size.Y, true)
		table.insert(P.adds, {src = R183, name = "Ribbon183_Link", parent = RC, cf = cf, size = sz})
		local A2 = ribbonEnd(R185, function(a, b) return a.Z < b.Z end) -- its south-east end, toward the bridge
		local B2 = Vector3.new(BRIDGE_X, gN + lift, zN - 1)
		local dirB = (A2 - B2).Unit
		cf, sz = seg(B2, A2 + dirB * RIBBON_OVERLAP, R183.Size.X, R183.Size.Y, true)
		table.insert(P.moves, {orig = R184, cf = cf, size = sz})
		-- the pit: top cells below the north rim height rise to it (bottom kept)
		local pit = {}
		for _, d in ipairs(Ground:GetDescendants()) do
			if d:IsA("BasePart") and string.sub(d.Name, 1, 1) == "T" then
				local p = d.Position
				if p.X > PIT_BOX[1] and p.X < PIT_BOX[2] and p.Z > PIT_BOX[3] and p.Z < PIT_BOX[4] then
					local rx, ry, rz = d.CFrame:ToEulerAnglesYXZ()
					local t = p.Y + d.Size.Y / 2
					if math.abs(rx) + math.abs(ry) + math.abs(rz) < 1e-3 and t < gN - 0.5 then
						local bot = p.Y - d.Size.Y / 2
						table.insert(pit, d)
						table.insert(P.moves, {orig = d, cf = CFrame.new(p.X, (gN + bot) / 2, p.Z), size = Vector3.new(d.Size.X, gN - bot, d.Size.Z), pit = true})
					end
				end
			end
		end
		if #pit > 12 then error(#pit .. " pit cells (expected about 6)") end
		P.pitN = #pit
	end)
	if not ok then return nil, tostring(err) end
	if n ~= 37 then return nil, "Footbridge has " .. n .. " parts (expected 37)" end
	-- report rows
	table.insert(L, string.format("deck: z %.2f..%.2f (span %.1f, centre %.2f = midline), top %.2f -> %.2f (grade %.2f deg), x %d, 13 planks end to end",
		zS, zN, zN - zS, (zS + zN) / 2, yS, yN, math.deg(math.atan((yS - yN) / (zN - zS))), BRIDGE_X))
	table.insert(L, string.format("arches: towers at x %d +- %.1f, z %.2f (south, ground %.1f) and %.2f (north, ground %.1f); lintels on top",
		BRIDGE_X, TOWER_X, P.zT[0], gS, P.zT[1], gN))
	for _, m in ipairs(P.moves) do
		local o = m.orig
		table.insert(L, string.format("  %-14s %s %s -> %s %s", o.Name, f1(o.Position), f1(o.Size), f1(m.cf.Position), f1(m.size)))
	end
	for _, a in ipairs(P.adds) do
		table.insert(L, string.format("  + %-12s (clone of %s) %s %s", a.name, a.src.Name, f1(a.cf.Position), f1(a.size)))
	end
	return P
end

-- the water plan
local function planWater()
	local out = {}
	for _, R in ipairs(WATER) do
		local nx, nz = (R.x1 - R.x0) / CELL, (R.z1 - R.z0) / CELL
		local mats, occ = Terrain:ReadVoxels(Region3.new(Vector3.new(R.x0, 0, R.z0), Vector3.new(R.x1, 8, R.z1)), CELL)
		local rock = Falls:FindFirstChild("Rock")
		local rcf, rsz = rock and rock.CFrame, rock and rock.Size
		local function underRock(x, z)
			if not rock then return false end
			local l = rcf:PointToObjectSpace(Vector3.new(x, rcf.Y, z))
			return math.abs(l.X) < rsz.X / 2 and math.abs(l.Z) < rsz.Z / 2
		end
		local cells = {} -- [i][k] = {floor=bool, covered=bool, tmin}
		local solid = {} -- [i][k] = true: every sample hits expansion ground at or above TOP (wall / bank)
		local nFloor, nCov, nEdge = 0, 0, 0
		for i = 1, nx do
			cells[i] = {}
			solid[i] = {}
			for k = 1, nz do
				local x0, z0 = R.x0 + (i - 1) * CELL, R.z0 + (k - 1) * CELL
				if R.keep(x0) then
					local tmax, tmin, miss = -1e9, 1e9, false
					for _, o in ipairs({{1, 1}, {3, 1}, {1, 3}, {3, 3}, {2, 2}}) do
						local t = top(x0 + o[1], z0 + o[2])
						if t then tmax = math.max(tmax, t); tmin = math.min(tmin, t) else miss = true end
					end
					if miss then
						-- no expansion ground under part of the cell (the village, or off the map): not channel
					elseif tmax < TOP then
						local w0 = mats[i][1][k] == Enum.Material.Water and occ[i][1][k] or 0
						local w1 = mats[i][2][k] == Enum.Material.Water and occ[i][2][k] or 0
						local c = {floor = true, covered = (w0 >= 0.74 and w1 >= 0.29), tmin = tmin, rock = underRock(x0 + 2, z0 + 2)}
						cells[i][k] = c
						nFloor += 1
						if c.covered then nCov += 1 end
					elseif tmin < TOP then
						nEdge += 1
					else
						solid[i][k] = true
					end
				end
			end
		end
		-- flood from the covered cells through floor cells (4-neighbour)
		local reach, queue = {}, {}
		for i = 1, nx do reach[i] = {} end
		for i = 1, nx do for k = 1, nz do
			local c = cells[i][k]
			if c and c.covered then reach[i][k] = true; table.insert(queue, {i, k}) end
		end end
		local h = 1
		while h <= #queue do
			local i, k = queue[h][1], queue[h][2]
			h += 1
			for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
				local a, b = i + d[1], k + d[2]
				if a >= 1 and a <= nx and b >= 1 and b <= nz and not reach[a][b] and cells[a][b] then
					reach[a][b] = true
					table.insert(queue, {a, b})
				end
			end
		end
		local fill, pocket, rockN, bottom = {}, 0, 0, BED
		for i = 1, nx do fill[i] = {} end
		for i = 1, nx do for k = 1, nz do
			local c = cells[i][k]
			if c and not c.covered then
				if not reach[i][k] then pocket += 1
				elseif c.rock then rockN += 1
				else fill[i][k] = true; bottom = math.min(bottom, c.tmin) end
			end
		end end
		-- the ring: wall/bank cells (tops >= TOP) touching a channel cell (8-neighbour) also get water up to TOP,
		-- hidden inside the wall, so the water's rounded edge sits inside the wall instead of baring the floor's rim
		local nRing = 0
		for i = 1, nx do for k = 1, nz do
			if solid[i][k] then
				local touch, dryNext = false, false
				for a = math.max(1, i - 1), math.min(nx, i + 1) do
					for b = math.max(1, k - 1), math.min(nz, k + 1) do
						if reach[a][b] then touch = true end
						if cells[a][b] and not reach[a][b] then dryNext = true end -- a dry pocket beside it: no ring here
					end
				end
				if touch and not dryNext then
					local x0, z0 = R.x0 + (i - 1) * CELL, R.z0 + (k - 1) * CELL
					local w0 = mats[i][1][k] == Enum.Material.Water and occ[i][1][k] or 0
					local w1 = mats[i][2][k] == Enum.Material.Water and occ[i][2][k] or 0
					if not (w0 >= 0.74 and w1 >= 0.29) and not underRock(x0 + 2, z0 + 2) then fill[i][k] = true; nRing += 1 end
				end
			end
		end end
		-- merge: runs along x per row, then identical runs down consecutive rows
		local rects, open = {}, {}
		for k = 1, nz do
			local runs, i = {}, 1
			while i <= nx do
				if fill[i][k] then
					local j = i
					while j + 1 <= nx and fill[j + 1][k] do j += 1 end
					table.insert(runs, {i, j})
					i = j + 1
				else i += 1 end
			end
			local nextOpen = {}
			for _, r in ipairs(runs) do
				local key = r[1] .. ":" .. r[2]
				local o = open[key]
				if o then o.k1 = k else o = {i0 = r[1], i1 = r[2], k0 = k, k1 = k}; table.insert(rects, o) end
				nextOpen[key] = o
			end
			open = nextOpen
		end
		local boxes, area, nFill = {}, 0, 0
		local bx0, bx1, bz0, bz1 = 1e9, -1e9, 1e9, -1e9
		for _, r in ipairs(rects) do
			local x0, x1 = R.x0 + (r.i0 - 1) * CELL, R.x0 + r.i1 * CELL
			local z0, z1 = R.z0 + (r.k0 - 1) * CELL, R.z0 + r.k1 * CELL
			table.insert(boxes, {x0 = x0, x1 = x1, z0 = z0, z1 = z1})
			area += (x1 - x0) * (z1 - z0)
			nFill += (r.i1 - r.i0 + 1) * (r.k1 - r.k0 + 1)
			bx0, bx1, bz0, bz1 = math.min(bx0, x0), math.max(bx1, x1), math.min(bz0, z0), math.max(bz1, z1)
		end
		table.insert(out, {Id = R.Id, boxes = boxes, area = area, nFill = nFill, nRing = nRing, nFloor = nFloor, nCov = nCov, nEdge = nEdge,
			pocket = pocket, rockN = rockN, bottom = bottom, bbox = {bx0, bx1, bz0, bz1}})
	end
	return out
end

local function waterLines(WP)
	local L = {}
	for _, w in ipairs(WP) do
		table.insert(L, string.format("water %s: channel floor cells %d (covered %d); to fill %d cells (%d of them the wall/bank ring) in %d boxes = %d sq studs, Water y %.1f..%.1f; bbox x %s..%s z %s..%s; left dry: %d pocket cells not connected to the channel, %d under the waterfall rock; wall-edge cells %d",
			w.Id, w.nFloor, w.nCov, w.nFill, w.nRing, #w.boxes, w.area, w.bottom, TOP, tostring(w.bbox[1]), tostring(w.bbox[2]), tostring(w.bbox[3]), tostring(w.bbox[4]), w.pocket, w.rockN, w.nEdge))
	end
	return L
end

-- ---------------------------------------------------------------- journal
local journal = {}
local function did(undoFn) table.insert(journal, undoFn) end
local function rollback()
	local errs = {}
	for i = #journal, 1, -1 do
		local ok, e = pcall(journal[i])
		if not ok then table.insert(errs, tostring(e)) end
	end
	journal = {}
	return errs
end
local recording
local function beginRecording() pcall(function() recording = CHS:TryBeginRecording("LindenmoorGorgeFix " .. MODE) end) end
local function cancelRecording()
	if recording then pcall(function() CHS:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel) end); recording = nil end
end
local function waypoint()
	if recording then pcall(function() CHS:FinishRecording(recording, Enum.FinishRecordingOperation.Commit) end)
	else pcall(function() CHS:SetWaypoint("LindenmoorGorgeFix " .. MODE) end) end
end

local function cfString(cf) local c = {cf:GetComponents()}; for i = 1, #c do c[i] = string.format("%.6f", c[i]) end; return table.concat(c, ",") end
local function cfParse(s) local c = {}; for v in string.gmatch(s, "[^,]+") do table.insert(c, tonumber(v)) end; return CFrame.new(table.unpack(c)) end

-- ---------------------------------------------------------------- apply
local function doApply(P, WP)
	local rb = SS:FindFirstChild("RenseiBackups")
	local createdRb = false
	if not rb then
		rb = Instance.new("Folder"); rb.Name = "RenseiBackups"; rb.Parent = SS; createdRb = true
		did(function() rb:Destroy() end)
	end
	local bk = Instance.new("Folder")
	bk.Name = BACKUP
	bk:SetAttribute("Note", "Lindenmoor import Ruling 23: gorge fix (footbridge rebuilt from clones of its own parts; route landings; terrain water). Undo: gorge_fix.lua MODE undo")
	if createdRb then bk:SetAttribute("CreatedRenseiBackups", true) end
	bk:SetAttribute("FootbridgePivot", cfString(FB.WorldPivot))
	bk:SetAttribute("LedgeSig", signature(Ledge))
	bk:SetAttribute("FallsSig", signature(Falls))
	local Pieces, Parents, Refs, TR = Instance.new("Folder"), Instance.new("Folder"), Instance.new("Folder"), Instance.new("Folder")
	Pieces.Name, Parents.Name, Refs.Name, TR.Name = "Pieces", "Parents", "Refs", "Terrain"
	Pieces.Parent, Parents.Parent, Refs.Parent, TR.Parent = bk, bk, bk, bk
	bk.Parent = rb
	did(function() bk:Destroy() end)
	-- (a)+(b): clones replace the originals
	local nMoved, nAdded, nPit = 0, 0, 0
	for idx, m in ipairs(P.moves) do
		local o = m.orig
		local parent = o.Parent
		local c = o:Clone()
		c:SetAttribute(NEW, true)
		c.Size = m.size
		c.CFrame = m.cf
		c.Parent = parent
		did(function() c:Destroy() end)
		local pv, rv = Instance.new("ObjectValue"), Instance.new("ObjectValue")
		pv.Name, rv.Name = tostring(idx), tostring(idx)
		pv.Value, rv.Value = parent, o
		pv.Parent, rv.Parent = Parents, Refs
		o:SetAttribute(FROM, o:GetFullName())
		o.Parent = Pieces
		did(function() o.Parent = parent; o:SetAttribute(FROM, nil) end)
		nMoved += 1
		if m.pit then nPit += 1 end
	end
	for _, a in ipairs(P.adds) do
		local c = a.src:Clone()
		c.Name = a.name
		c:SetAttribute(NEW, true)
		c.Size = a.size
		c.CFrame = a.cf
		c.Parent = a.parent
		did(function() c:Destroy() end)
		nAdded += 1
	end
	local oldPivot = FB.WorldPivot
	FB.WorldPivot = CFrame.new(BRIDGE_X, P.deckTop(P.zc), P.zc)
	did(function() FB.WorldPivot = oldPivot end)
	-- (c) water: snapshot each region's box (padded one voxel, rows y 0..12), then fill
	local nBoxes = 0
	for _, w in ipairs(WP) do
		if #w.boxes > 0 then
			local lo = Vector3int16.new(w.bbox[1] / CELL - 1, 0, w.bbox[3] / CELL - 1)
			local hi = Vector3int16.new(w.bbox[2] / CELL, 2, w.bbox[4] / CELL)
			local snap = Terrain:CopyRegion(Region3int16.new(lo, hi))
			snap.Name = w.Id
			snap:SetAttribute("Corner", string.format("%d,%d,%d", lo.X, lo.Y, lo.Z))
			snap.Parent = TR
			did(function() Terrain:PasteRegion(snap, lo, true) end)
			for _, b in ipairs(w.boxes) do
				local bot = math.min(BED, w.bottom)
				Terrain:FillBlock(CFrame.new((b.x0 + b.x1) / 2, (bot + TOP) / 2, (b.z0 + b.z1) / 2), Vector3.new(b.x1 - b.x0, TOP - bot, b.z1 - b.z0), Enum.Material.Water)
				nBoxes += 1
			end
		end
	end
	E:SetAttribute(ATTR, "applied 2026-10-24")
	did(function() E:SetAttribute(ATTR, nil) end)
	return nMoved, nAdded, nPit, nBoxes
end

-- ---------------------------------------------------------------- undo
local function doUndo(bk)
	local Pieces, Parents, Refs, TR = bk:FindFirstChild("Pieces"), bk:FindFirstChild("Parents"), bk:FindFirstChild("Refs"), bk:FindFirstChild("Terrain")
	assert(Pieces and Parents and Refs and TR, "backup folder is incomplete")
	-- the clones leave first (parked, destroyed only after success)
	local park = Instance.new("Folder")
	park.Name = "GorgeFixUndoPark"
	park.Parent = bk
	local nNew = 0
	for _, root in ipairs({FB, RC, Ground}) do
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("BasePart") and d:GetAttribute(NEW) then
				local parent = d.Parent
				d.Parent = park
				did(function() d.Parent = parent end)
				nNew += 1
			end
		end
	end
	local nBack = 0
	for _, rv in ipairs(Refs:GetChildren()) do
		local o, pv = rv.Value, Parents:FindFirstChild(rv.Name)
		assert(o and pv and pv.Value, "backup reference " .. rv.Name .. " is broken")
		local from = o:GetAttribute(FROM)
		o.Parent = pv.Value
		o:SetAttribute(FROM, nil)
		did(function() o.Parent = Pieces; o:SetAttribute(FROM, from) end)
		nBack += 1
	end
	local piv = bk:GetAttribute("FootbridgePivot")
	if piv then
		local old = FB.WorldPivot
		FB.WorldPivot = cfParse(piv)
		did(function() FB.WorldPivot = old end)
	end
	local nTer = 0
	for _, snap in ipairs(TR:GetChildren()) do
		local c = {}
		for v in string.gmatch(snap:GetAttribute("Corner"), "[^,]+") do table.insert(c, tonumber(v)) end
		local lo = Vector3int16.new(c[1], c[2], c[3])
		local size = snap.SizeInCells
		local now = Terrain:CopyRegion(Region3int16.new(lo, Vector3int16.new(lo.X + size.X - 1, lo.Y + size.Y - 1, lo.Z + size.Z - 1)))
		Terrain:PasteRegion(snap, lo, true)
		did(function() Terrain:PasteRegion(now, lo, true) end)
		nTer += 1
	end
	E:SetAttribute(ATTR, nil)
	did(function() E:SetAttribute(ATTR, "applied 2026-10-24") end)
	-- last, not journaled
	local rb, created = bk.Parent, bk:GetAttribute("CreatedRenseiBackups")
	bk:Destroy()
	if created and rb and #rb:GetChildren() == 0 then rb:Destroy() end
	return nNew, nBack, nTer
end

-- ---------------------------------------------------------------- check (read-only, after apply)
local function doCheck()
	local L, fails = {}, 0
	local function res(ok, s) if not ok then fails += 1 end; table.insert(L, (ok and "PASS " or "FAIL ") .. s) end
	-- water: no channel cell left uncovered; a 2-stud raycast grid over every channel floor point hits water at the surface
	local WP = planWater()
	local rpW = RaycastParams.new()
	rpW.FilterType = Enum.RaycastFilterType.Include
	rpW.FilterDescendantsInstances = {Ground, Edging, Terrain}
	rpW.IgnoreWater = false
	for _, w in ipairs(WP) do
		res(w.nFill == 0, string.format("water %s: %d channel cells, %d still uncovered by voxels", w.Id, w.nFloor, w.nFill))
	end
	for _, R in ipairs(WATER) do
		local n, bad, low, ex, nLow = 0, 0, 1e9, nil, 0
		for x = R.x0 + 1, R.x1 - 1, 2 do
			if R.keep(math.floor(x / CELL) * CELL) then
				for z = R.z0 + 1, R.z1 - 1, 2 do
					local t = top(x, z)
					if t and t < TOP then
						local r = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), rpW)
						local okHit = r and r.Instance == Terrain and r.Material == Enum.Material.Water
						-- points in pockets/under the rock are not channel: count only those with water within 4 studs
						if okHit then n += 1; low = math.min(low, r.Position.Y); if r.Position.Y < TOP - 0.3 then nLow += 1 end
						else
							local near = false
							for _, d in ipairs({{4, 0}, {-4, 0}, {0, 4}, {0, -4}}) do
								local r2 = workspace:Raycast(Vector3.new(x + d[1], 300, z + d[2]), Vector3.new(0, -600, 0), rpW)
								if r2 and r2.Instance == Terrain and r2.Material == Enum.Material.Water then near = true end
							end
							if near then bad += 1; ex = ex or string.format("(%d, %d) hit %s at %.2f", x, z, r and r.Instance.Name or "nothing", r and r.Position.Y or 0) end
						end
					end
				end
			end
		end
		res(bad == 0, string.format("water %s raycast grid (2 studs): %d floor points hit water (lowest surface %.2f; %d below %.1f); %d floor-ground hits beside water%s", R.Id, n, low, nLow, TOP - 0.3, bad, ex and (", e.g. " .. ex) or ""))
	end
	-- deck: one straight span, centred, walkable
	local s0, n0 = lips(BRIDGE_X)
	local mid = s0 and (s0 + n0) / 2 or 0
	local decks = {}
	for i = 0, 12 do local d = FB:FindFirstChild("Deck" .. i); if d then table.insert(decks, d) end end
	local first, last = decks[1], decks[#decks]
	local dirs, straight = first and first.CFrame.LookVector, #decks == 13
	for _, d in ipairs(decks) do
		if dirs and d.CFrame.LookVector:Dot(dirs) < 0.99999 then straight = false end
		local rx, ry, rz = d.CFrame:ToEulerAnglesYXZ()
		if math.abs(math.deg(rz)) > 0.01 or math.abs(d.Position.X - BRIDGE_X) > 0.01 then straight = false end
	end
	local zA = first and first.CFrame:PointToWorldSpace(Vector3.new(0, 0, first.Size.Z / 2)).Z
	local zB = first and first.CFrame:PointToWorldSpace(Vector3.new(0, 0, -first.Size.Z / 2)).Z
	local zLo = first and math.min(zA, zB)
	local zC = last and last.CFrame:PointToWorldSpace(Vector3.new(0, 0, last.Size.Z / 2)).Z
	local zD = last and last.CFrame:PointToWorldSpace(Vector3.new(0, 0, -last.Size.Z / 2)).Z
	local zHi = last and math.max(zC, zD)
	res(straight, string.format("deck: %d planks, one direction, no roll, x = %d", #decks, BRIDGE_X))
	res(zLo and math.abs((zLo + zHi) / 2 - mid) <= 0.5, string.format("deck centred: ends z %.2f..%.2f, centre %.2f, rims' midline %.2f (lips %.2f / %.2f)", zLo or 0, zHi or 0, zLo and (zLo + zHi) / 2 or 0, mid, s0 or 0, n0 or 0))
	-- walk: centreline raycasts on deck planks + route ribbons + ground, from Ribbon183 to Ribbon185
	local rpD = RaycastParams.new()
	rpD.FilterType = Enum.RaycastFilterType.Include
	local inc = {Ground, RC}
	for _, d in ipairs(decks) do table.insert(inc, d) end
	rpD.FilterDescendantsInstances = inc
	local prev, maxStep, at, n = nil, 0, 0, 0
	for z = (zLo or 0) - 6, (zHi or 0) + 6, 0.5 do
		local r = workspace:Raycast(Vector3.new(BRIDGE_X, 60, z), Vector3.new(0, -100, 0), rpD)
		if r then
			n += 1
			if prev and math.abs(r.Position.Y - prev) > maxStep then maxStep = math.abs(r.Position.Y - prev); at = z end
			prev = r.Position.Y
		end
	end
	res(maxStep <= 0.5, string.format("deck walkable: %d centreline samples from z %.1f to %.1f, largest step %.2f (at z %.1f)", n, (zLo or 0) - 6, (zHi or 0) + 6, maxStep, at))
	-- arches
	local okA, txt = true, {}
	for e, zEnd in pairs({[0] = zLo, [1] = zHi}) do
		local tA, tB, li = FB:FindFirstChild("Tower" .. e .. "_-1"), FB:FindFirstChild("Tower" .. e .. "_1"), FB:FindFirstChild("Lintel" .. e)
		if not (tA and tB and li and zEnd) then okA = false
		else
			local want = zEnd + (e == 0 and 0.6 or -0.6)
			local good = math.abs(tA.Position.Z - want) < 0.05 and math.abs(tB.Position.Z - want) < 0.05 and math.abs(li.Position.Z - want) < 0.05
				and math.abs((tA.Position.X + tB.Position.X) / 2 - BRIDGE_X) < 0.05 and math.abs(li.Position.X - BRIDGE_X) < 0.05
				and tA.CFrame.UpVector.Y > 0.9999 and tB.CFrame.UpVector.Y > 0.9999
			okA = okA and good
			table.insert(txt, string.format("%s arch z %.2f (deck end %.2f)", e == 0 and "south" or "north", tA.Position.Z, zEnd))
		end
	end
	res(okA, "arches line up with the deck ends: " .. table.concat(txt, ", "))
	-- the ledge walk and the waterfall are unchanged since apply
	local rb = SS:FindFirstChild("RenseiBackups")
	local bk = rb and rb:FindFirstChild(BACKUP)
	if bk then
		res(signature(Ledge) == bk:GetAttribute("LedgeSig"), "ledge walk unchanged: " .. signature(Ledge))
		res(signature(Falls) == bk:GetAttribute("FallsSig"), "waterfall unchanged: " .. signature(Falls))
	else
		table.insert(L, "INFO no backup folder: ledge " .. signature(Ledge) .. "; falls " .. signature(Falls))
	end
	return string.format("GorgeFix check: %d FAIL\n%s", fails, table.concat(L, "\n"))
end

-- ================================================================ run
if MODE == "plan" then
	if E:GetAttribute(ATTR) then return "GorgeFix plan: already applied (" .. tostring(E:GetAttribute(ATTR)) .. ")" end
	local P, why = planBridge()
	if not P then return refuse(why) end
	local WP = planWater()
	local L = {"GorgeFix plan (read-only)"}
	for _, s in ipairs(P.lines) do table.insert(L, s) end
	table.insert(L, string.format("landings: Ribbon183_Link (new) south path -> deck; Ribbon184 re-laid deck -> Ribbon185; %d pit cells raised to %.1f", P.pitN, P.gN))
	for _, s in ipairs(waterLines(WP)) do table.insert(L, s) end
	table.insert(L, "ledge " .. signature(Ledge) .. "; falls " .. signature(Falls))
	return table.concat(L, "\n")
elseif MODE == "check" then
	return doCheck()
elseif MODE == "apply" then
	if E:GetAttribute(ATTR) then return refuse("already applied (" .. tostring(E:GetAttribute(ATTR)) .. ")") end
	local rb = SS:FindFirstChild("RenseiBackups")
	if rb and rb:FindFirstChild(BACKUP) then return refuse("ServerStorage.RenseiBackups." .. BACKUP .. " already exists") end
	local P, why = planBridge()
	if not P then return refuse(why) end
	local okW, WP = pcall(planWater)
	if not okW then return refuse("water plan: " .. tostring(WP)) end
	beginRecording()
	local ok, a, b, c, d = pcall(doApply, P, WP)
	if not ok then
		local errs = rollback()
		waypoint()
		return string.format("GorgeFix apply FAILED (rolled back%s): %s", #errs > 0 and (", " .. #errs .. " rollback errors: " .. table.concat(errs, "; ")) or "", tostring(a))
	end
	journal = {}
	waypoint()
	local L = {string.format("GorgeFix apply OK: %d originals to RenseiBackups.%s (bridge 37, Ribbon184, %d pit cells) replaced by clones; %d new parts (2 handrails, Ribbon183_Link); %d water boxes filled",
		a, BACKUP, c, b, d)}
	for _, s in ipairs(P.lines) do if string.sub(s, 1, 2) ~= "  " then table.insert(L, s) end end
	for _, s in ipairs(waterLines(WP)) do table.insert(L, s) end
	return table.concat(L, "\n")
elseif MODE == "undo" then
	local rb = SS:FindFirstChild("RenseiBackups")
	local bk = rb and rb:FindFirstChild(BACKUP)
	if not bk then return refuse("no ServerStorage.RenseiBackups." .. BACKUP) end
	if not E:GetAttribute(ATTR) then return refuse("LindenmoorExpansion has no " .. ATTR .. " attribute") end
	beginRecording()
	local ok, a, b, c = pcall(doUndo, bk)
	if not ok then
		local errs = rollback()
		waypoint()
		return string.format("GorgeFix undo FAILED (rolled back%s): %s", #errs > 0 and (", " .. #errs .. " rollback errors: " .. table.concat(errs, "; ")) or "", tostring(a))
	end
	journal = {}
	waypoint()
	return string.format("GorgeFix undo OK: %d clones removed, %d originals back, %d terrain snapshots pasted back", a, b, c)
end
return refuse("MODE must be plan, apply, undo or check")

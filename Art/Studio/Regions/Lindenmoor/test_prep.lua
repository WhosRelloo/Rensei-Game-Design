-- test_prep.lua: Lindenmoor import Task 5's test. Proves prep_ye.lua's apply and undo in Ye (Edit) and leaves Ye
-- exactly as it found it. Run the bundle, never this file alone:
--   python -I Art/Studio/Regions/Lindenmoor/bundle_prep.py test <out.lua>
--   python -I Art/Tools/rbxc.py luau "placeId: 106992859583940" Edit @<out.lua>
-- The bundle defines PADS_JSON (pads.json) and Prep(mode) (prep_ye.lua; nil before it exists).
-- 1. snapshots all of workspace.World plus every other workspace child (not the camera or terrain): each
--    descendant's full name, class, pivot (0.01) and sorted attributes, plus per-tag counts in workspace;
-- 2. runs apply; 3. checks the result, including a collateral diff: a second snapshot right after apply may differ
--    from the first only in rows of the instances apply is meant to touch (block members, riders, spawns, the
--    elite, trainers, lifted items, retired pieces, and World.Map's own row for LindenmoorPrep) or their
--    descendants (Ruling 18); 4. runs undo (always, once apply succeeded); 5. checks the snapshot equals the start.
-- Returns "PASS ..." or "FAIL ..." with the failures.
local HttpService = game:GetService("HttpService")
local CS = game:GetService("CollectionService")
local SS = game:GetService("ServerStorage")
local BACKUP = "Pre-LindenmoorExpansion_2026-10-24"
local TOL = 0.05

if game:GetService("RunService"):IsRunning() then return "FAIL: run in Edit, not Play" end
if SS:GetAttribute("PlayLock") then return "FAIL: PlayLock is set (" .. tostring(SS:GetAttribute("PlayLock")) .. ")" end

local World = workspace:FindFirstChild("World")
local Map = World and World:FindFirstChild("Map")
if not Map then return "FAIL: no workspace.World.Map" end
local PADS = PADS_JSON and HttpService:JSONDecode(PADS_JSON) or nil

local fails, notes = {}, {}
local function check(ok, msg)
	if not ok then table.insert(fails, msg) end
	return ok
end
local function near(a, b, tol) return math.abs(a - b) <= (tol or TOL) end

-- ---------------------------------------------------------------- snapshot
local function fmt(n)
	local s = string.format("%.2f", n)
	return s == "-0.00" and "0.00" or s
end
-- exp (optional): {tree = {[inst] = true}, exact = {[inst] = true}}: rows of a tree instance or its descendants, or
-- of an exact instance itself, are "expected" to change; the rest are returned again as nrows (collateral check)
local function snapshot(exp)
	local rows, nrows = {}, {}
	local function expected(d)
		if not exp then return false end
		if exp.exact[d] then return true end
		local a = d
		while a do
			if exp.tree[a] then return true end
			a = a.Parent
		end
		return false
	end
	local function add(d)
		local head, pivot, tail = d:GetFullName() .. "|" .. d.ClassName, "", ""
		if d:IsA("PVInstance") then
			local c = { d:GetPivot():GetComponents() }
			for i = 1, 12 do c[i] = fmt(c[i]) end
			pivot = "|" .. table.concat(c, ",")
		end
		local attrs, keys = d:GetAttributes(), {}
		for k in pairs(attrs) do table.insert(keys, k) end
		if #keys > 0 then
			table.sort(keys)
			for i, k in ipairs(keys) do
				local v = attrs[k]
				keys[i] = k .. "=" .. (type(v) == "number" and string.format("%.6g", v) or tostring(v))
			end
			tail = "|@" .. table.concat(keys, ";")
		end
		table.insert(rows, head .. pivot .. tail)
		if not expected(d) then
			-- a model without a WorldPivot reports its bounding-box centre, which moves when a retired child
			-- leaves (Lindenmoor, Station): for those ancestors only the pivot may change
			table.insert(nrows, head .. (exp and exp.pivotOnly[d] and "|(pivot not compared)" or pivot) .. tail)
		end
	end
	-- all of World, and everything else in workspace the lift step may touch (not the camera or terrain)
	add(World)
	for _, d in ipairs(World:GetDescendants()) do add(d) end
	for _, c in ipairs(workspace:GetChildren()) do
		if c ~= World and not c:IsA("Camera") and not c:IsA("Terrain") then
			add(c)
			for _, d in ipairs(c:GetDescendants()) do add(d) end
		end
	end
	table.sort(rows)
	table.sort(nrows)
	local tags = {}
	for _, t in ipairs(CS:GetAllTags()) do
		local n = 0
		for _, x in ipairs(CS:GetTagged(t)) do
			if x:IsDescendantOf(workspace) then n += 1 end
		end
		if n > 0 then tags[t] = n end
	end
	return rows, tags, nrows
end
local function diffRows(a, b, limit)
	local i, j, onlyA, onlyB = 1, 1, {}, {}
	while i <= #a or j <= #b do
		if j > #b or (i <= #a and a[i] < b[j]) then
			table.insert(onlyA, a[i]); i += 1
		elseif i > #a or b[j] < a[i] then
			table.insert(onlyB, b[j]); j += 1
		else
			i += 1; j += 1
		end
	end
	local out = {}
	for k = 1, math.min(limit, #onlyA) do table.insert(out, "  before only: " .. onlyA[k]) end
	for k = 1, math.min(limit, #onlyB) do table.insert(out, "  after only:  " .. onlyB[k]) end
	return #onlyA, #onlyB, out
end

-- ---------------------------------------------------------------- helpers (independent of prep_ye.lua)
local function partsOf(inst)
	local t = {}
	if inst:IsA("BasePart") then table.insert(t, inst) end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(t, d) end
	end
	return t
end
local function boxOf(list) -- world AABB of every part in the instances: {x0, y0, z0, x1, y1, z1}
	local b = { math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge }
	for _, inst in ipairs(list) do
		for _, p in ipairs(partsOf(inst)) do
			local c = { p.CFrame:GetComponents() }
			local s = p.Size
			local e = {
				math.abs(c[4]) * s.X / 2 + math.abs(c[5]) * s.Y / 2 + math.abs(c[6]) * s.Z / 2,
				math.abs(c[7]) * s.X / 2 + math.abs(c[8]) * s.Y / 2 + math.abs(c[9]) * s.Z / 2,
				math.abs(c[10]) * s.X / 2 + math.abs(c[11]) * s.Y / 2 + math.abs(c[12]) * s.Z / 2,
			}
			for k = 1, 3 do
				b[k] = math.min(b[k], c[k] - e[k])
				b[k + 3] = math.max(b[k + 3], c[k] + e[k])
			end
		end
	end
	return b
end
local function members(block)
	local want, got = {}, {}
	for _, n in ipairs(block.Members) do want[n] = true end
	for _, c in ipairs(Map:GetChildren()) do
		if want[c.Name] then table.insert(got, c) end
	end
	return got
end
local function rider(path)
	local folder, name = string.match(path, "^([^/]+)/(.+)$")
	local f = World:FindFirstChild(folder)
	return f and f:FindFirstChild(name)
end
local function pads()
	local t = {}
	for k, v in pairs(PADS or {}) do
		if string.sub(k, 1, 4) == "res_" then t[k] = v end
	end
	return t
end
local byName -- full name -> every PVInstance with it (names repeat, e.g. the two Power Lines; names hold dots,
-- e.g. "Emotes,etc.", so paths are matched whole, never split)
local function findAll(path)
	if not byName then
		byName = {}
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("PVInstance") then
				local f = d:GetFullName()
				byName[f] = byName[f] or {}
				table.insert(byName[f], d)
			end
		end
	end
	return byName[path] or {}
end
local function liftItem(e) -- the instance for a pads.json Lift entry: same path, same XZ (a lift moves only in Y)
	local hit, n = nil, 0
	for _, c in ipairs(findAll(e.Path)) do
		local p = c:GetPivot().Position
		if math.abs(p.X - e.Pivot[1]) <= 0.5 and math.abs(p.Z - e.Pivot[3]) <= 0.5 then hit, n = c, n + 1 end
	end
	return n == 1 and hit or nil
end
local function overlapXZ(a, b) return a[1] < b[4] and b[1] < a[4] and a[3] < b[6] and b[3] < a[6] end

-- ---------------------------------------------------------------- 1. snapshot and the "before" values
local pre = { blocks = {}, riders = {}, spawns = {}, elite = nil, adit = {} }
local ES = World:FindFirstChild("EnemySpawns")
for pid, pad in pairs(pads()) do
	for _, b in ipairs(pad.Blocks) do
		pre.blocks[pid .. "/" .. b.Name] = boxOf(members(b))
		for _, r in ipairs(b.Riders) do
			local m = rider(r)
			if check(m ~= nil, "rider missing before apply: " .. r) then pre.riders[r] = m:GetPivot() end
		end
	end
end
for _, s in ipairs(Map.AlchemistSpawns:GetChildren()) do pre.spawns[s.Name] = s.CFrame end
for _, s in ipairs(ES:GetChildren()) do
	if s.Name == "EliteSpawn" then pre.elite = s.CFrame end
	if string.find(s.Name, "^AditScavengerSpawn") then pre.adit[s.Name] = s.CFrame end
end
pre.lift = {}
for _, e in ipairs(PADS and PADS.Lift or {}) do
	if e.Top ~= nil then
		local m = liftItem(e)
		if check(m ~= nil, "lift item not found before apply: " .. e.Path) then pre.lift[e] = { inst = m, low = boxOf({ m })[2], pivot = m:GetPivot() } end
	end
end

-- what apply is meant to touch (Ruling 18's collateral check): these instances and their descendants, and
-- World.Map's own row (its LindenmoorPrep attribute)
local exp = { tree = {}, exact = { [Map] = true } }
for _, pad in pairs(pads()) do
	for _, b in ipairs(pad.Blocks) do
		for _, m in ipairs(members(b)) do exp.tree[m] = true end
		for _, r in ipairs(b.Riders) do
			local m = rider(r)
			if m then exp.tree[m] = true end
		end
	end
end
for _, s in ipairs(Map.AlchemistSpawns:GetChildren()) do exp.tree[s] = true end
for _, m in ipairs(World.NPCs["Alchemy Trainers"]:GetChildren()) do exp.tree[m] = true end
for _, s in ipairs(ES:GetChildren()) do
	if s.Name == "EliteSpawn" or s.Name == "GruntSpawn" then exp.tree[s] = true end
end
for e, p0 in pairs(pre.lift) do
	if p0.low < e.Top + 0.05 - 0.001 then exp.tree[p0.inst] = true end
end
local L0 = Map.Lindenmoor
for _, n in ipairs({ "NorthRoad", "HubRoad" }) do
	if L0:FindFirstChild(n) then exp.tree[L0[n]] = true end
end
for _, c in ipairs(L0.Station:GetChildren()) do
	if c.Name == "BufferStop" and (c:GetPivot().Position - Vector3.new(-270, 10, -369)).Magnitude <= 5 then exp.tree[c] = true end
end
exp.pivotOnly = {}
for inst in pairs(exp.tree) do
	if inst.Name == "NorthRoad" or inst.Name == "HubRoad" or inst.Name == "BufferStop" or inst.Name == "GruntSpawn" then
		local a = inst.Parent
		while a and a ~= game do
			exp.pivotOnly[a] = true
			a = a.Parent
		end
	end
end
local rows0, tags0, nrows0 = snapshot(exp)

-- ---------------------------------------------------------------- 2. apply
local applied = false
if not check(Prep ~= nil, "prep_ye.lua is not built (no Prep in the bundle)") then
	-- RED: nothing to run
elseif not check(PADS ~= nil, "pads.json is not in the bundle") then
	-- nothing to check against
else
	local ok, res = pcall(Prep, "apply")
	table.insert(notes, "apply: " .. tostring(res))
	applied = Map:GetAttribute("LindenmoorPrep") == "applied"
	check(ok and type(res) == "string" and string.find(res, " OK:") ~= nil, "apply did not succeed: " .. tostring(res))
end

-- ---------------------------------------------------------------- 3. checks after apply
if applied then
	-- collateral: nothing outside the expected instances changed (Ruling 18)
	local _, _, nrows1 = snapshot(exp)
	local cA, cB, cdiff = diffRows(nrows0, nrows1, 10)
	check(cA == 0 and cB == 0, string.format("collateral: unexpected rows changed by apply (before-only %d, after-only %d)\n%s",
		cA, cB, table.concat(cdiff, "\n")))
	table.insert(notes, string.format("collateral diff after apply: %d of %d rows outside the expected set, %d changed",
		#nrows0, #rows0, cA + cB))

	local L = Map.Lindenmoor
	local backup = SS:FindFirstChild("RenseiBackups") and SS.RenseiBackups:FindFirstChild(BACKUP)
	if check(backup ~= nil, "backup folder missing after apply") then
		local n = 0
		for _, c in ipairs(backup:GetChildren()) do
			n += 1
			check(type(c:GetAttribute("FromPath")) == "string", "backup child without FromPath: " .. c.Name)
		end
		check(n == 5, "backup holds " .. n .. " pieces, expected 5 (NorthRoad, HubRoad, BufferStop, GruntSpawn x2)")
	end
	check(L:FindFirstChild("NorthRoad") == nil, "NorthRoad still in Lindenmoor")
	check(L:FindFirstChild("HubRoad") == nil, "HubRoad still in Lindenmoor")
	local stops = {}
	for _, c in ipairs(L.Station:GetChildren()) do
		if c.Name == "BufferStop" then table.insert(stops, c) end
	end
	check(#stops == 1 and near(stops[1].Position.Z, -891, 1), "expected one BufferStop left, at z -891 (found " .. #stops .. ")")
	local passages, roadStarts = 0, 0
	for _, x in ipairs(CS:GetTagged("RenseiRoadPassage")) do
		if x:IsDescendantOf(L) then passages += 1 end
	end
	for _, x in ipairs(CS:GetTagged("RenseiArrival")) do
		if x:IsDescendantOf(workspace) and x:GetAttribute("Point") == "RoadStart" then roadStarts += 1 end
	end
	check(passages == 0, passages .. " RenseiRoadPassage left under Map.Lindenmoor")
	check(roadStarts == 0, roadStarts .. " RoadStart arrivals left in workspace")
	local grunts = 0
	for _, s in ipairs(ES:GetChildren()) do
		if s.Name == "GruntSpawn" then grunts += 1 end
		if pre.adit[s.Name] then check(s.CFrame == pre.adit[s.Name], s.Name .. " moved (it should stay)") end
	end
	check(grunts == 0, grunts .. " GruntSpawn left in World.EnemySpawns")

	-- pads: each block at pad + slot, risen by the pad's height; the pad group within its radius; riders with it
	local placed = {}
	for pid, pad in pairs(pads()) do
		local px, py, pz = pad.At[1], pad.At[2], pad.At[3]
		local worst = 0
		placed[pid] = {}
		for _, b in ipairs(pad.Blocks) do
			local key = pid .. "/" .. b.Name
			local b0, b1 = pre.blocks[key], boxOf(members(b))
			table.insert(placed[pid], b1)
			local cx, cz = (b1[1] + b1[4]) / 2, (b1[3] + b1[6]) / 2
			check(near(cx, px + b.Slot[1]) and near(cz, pz + b.Slot[2]),
				string.format("%s centre (%.2f, %.2f), expected (%.2f, %.2f)", key, cx, cz, px + b.Slot[1], pz + b.Slot[2]))
			local dy = py - PADS.Ground
			check(near(b1[2], b0[2] + dy), string.format("%s lowest %.2f, expected %.2f", key, b1[2], b0[2] + dy))
			check(near(b1[4] - b1[1], b0[4] - b0[1]) and near(b1[6] - b1[3], b0[6] - b0[3]) and near(b1[5] - b1[2], b0[5] - b0[2]),
				key .. " changed size")
			for _, xz in ipairs({ { b1[1], b1[3] }, { b1[4], b1[3] }, { b1[1], b1[6] }, { b1[4], b1[6] } }) do
				worst = math.max(worst, math.sqrt((xz[1] - px) ^ 2 + (xz[2] - pz) ^ 2))
			end
			local delta = Vector3.new(cx - (b0[1] + b0[4]) / 2, b1[2] - b0[2], cz - (b0[3] + b0[6]) / 2)
			for _, r in ipairs(b.Riders) do
				local m, p0 = rider(r), pre.riders[r]
				if m and p0 then
					local d = m:GetPivot().Position - (p0.Position + delta)
					check(d.Magnitude <= TOL, string.format("rider %s off its block by %.2f", r, d.Magnitude))
					check(type(m:GetAttribute("LindenmoorPrepFrom")) == "string", "rider " .. r .. " has no LindenmoorPrepFrom")
				end
			end
			for _, m in ipairs(members(b)) do
				check(type(m:GetAttribute("LindenmoorPrepFrom")) == "string", "block member " .. m:GetFullName() .. " has no LindenmoorPrepFrom")
			end
		end
		check(worst <= pad.Radius + TOL, string.format("%s group reaches %.1f, pad radius %.1f", pid, worst, pad.Radius))
		table.insert(notes, string.format("%s: group reach %.1f / %.1f", pid, worst, pad.Radius))
	end

	-- alchemist spawns: at their spot, on their pad, clear of every block on it
	for _, s in ipairs(Map.AlchemistSpawns:GetChildren()) do
		local want = PADS.Spawns[s.Name]
		if check(want ~= nil, "AlchemistSpawns." .. s.Name .. " not in pads.json") then
			local pad, p, p0 = PADS[want.Pad], s.Position, pre.spawns[s.Name]
			check(near(p.X, want.XZ[1]) and near(p.Z, want.XZ[2]) and near(p.Y, p0.Y + want.DY),
				string.format("%s at %s, expected (%.2f, %.2f, %.2f)", s.Name, tostring(p), want.XZ[1], p0.Y + want.DY, want.XZ[2]))
			local r = math.sqrt((p.X - pad.At[1]) ^ 2 + (p.Z - pad.At[3]) ^ 2)
			check(r <= pad.Radius - 8 + TOL, string.format("%s %.1f from its pad centre (limit %.1f)", s.Name, r, pad.Radius - 8))
			local sb = boxOf({ s })
			local gap = math.huge
			for _, b in ipairs(placed[want.Pad]) do
				check(not overlapXZ(sb, b), s.Name .. " overlaps a block on " .. want.Pad)
				local gx = math.max(b[1] - sb[4], sb[1] - b[4], 0)
				local gz = math.max(b[3] - sb[6], sb[3] - b[6], 0)
				gap = math.min(gap, math.sqrt(gx * gx + gz * gz))
			end
			check(s.CFrame.Rotation == p0.Rotation, s.Name .. " rotated")
			check(type(s:GetAttribute("LindenmoorPrepFrom")) == "string", s.Name .. " has no LindenmoorPrepFrom")
			table.insert(notes, string.format("%s -> (%.1f, %.1f, %.1f) r %.1f, block gap %.1f", s.Name, p.X, p.Y, p.Z, r, gap))
		end
	end

	-- the EliteSpawn: at its Bramble Woods spot
	local elite = ES:FindFirstChild("EliteSpawn")
	if check(elite ~= nil and pre.elite ~= nil, "EliteSpawn missing") then
		local e, p = PADS.EliteSpawn, elite.Position
		check(near(p.X, e.XZ[1]) and near(p.Z, e.XZ[2]) and near(p.Y, pre.elite.Y + e.DY),
			"EliteSpawn at " .. tostring(p) .. ", expected its Bramble Woods spot")
		check(type(elite:GetAttribute("LindenmoorPrepFrom")) == "string", "EliteSpawn has no LindenmoorPrepFrom")
		table.insert(notes, string.format("EliteSpawn -> (%.1f, %.1f, %.1f)", p.X, p.Y, p.Z))
	end

	-- trainers: on their spot (feet on the ground there), facing the spot's Yaw (0 = -Z, into the training field)
	local trainers = 0
	for _, m in ipairs(World.NPCs["Alchemy Trainers"]:GetChildren()) do
		local el = string.match(tostring(m:GetAttribute("DialogueId")), "^trainer_(%a+)$")
		local spot = el and PADS["trainer_" .. el]
		if check(spot ~= nil, "trainer " .. m.Name .. " has no spot") then
			trainers += 1
			local pv, b = m:GetPivot(), boxOf({ m })
			check(near(pv.Position.X, spot.At[1]) and near(pv.Position.Z, spot.At[3]),
				string.format("%s at (%.2f, %.2f), spot (%.2f, %.2f)", m.Name, pv.Position.X, pv.Position.Z, spot.At[1], spot.At[3]))
			check(near(b[2], spot.At[2]), string.format("%s feet at %.2f, ground %.2f", m.Name, b[2], spot.At[2]))
			local want = CFrame.Angles(0, math.rad(spot.Yaw), 0).LookVector
			check(pv.LookVector:Dot(want) > 0.999, m.Name .. " faces " .. tostring(pv.LookVector))
			local hrp = m:FindFirstChild("HumanoidRootPart")
			check(hrp ~= nil and hrp.CFrame.LookVector:Dot(want) > 0.999,
				m.Name .. "'s HumanoidRootPart faces " .. tostring(hrp and hrp.CFrame.LookVector))
			check(type(m:GetAttribute("LindenmoorPrepFrom")) == "string", m.Name .. " has no LindenmoorPrepFrom")
		end
	end
	check(trainers == 5, trainers .. " trainers placed, expected 5")

	-- Ruling 17: nothing on the new ground is left below its planned top; items already above it did not move
	for e, p0 in pairs(pre.lift) do
		local m = p0.inst
		local low, pv = boxOf({ m })[2], m:GetPivot()
		local want = e.Top + 0.05
		check(low >= want - 0.001, string.format("%s lowest %.2f, below the planned top %.2f + 0.05", e.Path, low, e.Top))
		if p0.low < want - 0.001 then
			check(near(low, want, 0.01), string.format("%s lifted to %.3f, expected %.3f", e.Path, low, want))
			check(near(pv.X, p0.pivot.X, 0.001) and near(pv.Z, p0.pivot.Z, 0.001), e.Path .. " moved sideways")
			check(type(m:GetAttribute("LindenmoorPrepFrom")) == "string", e.Path .. " lifted without LindenmoorPrepFrom")
			table.insert(notes, string.format("lifted %s: lowest y %.2f -> %.2f", e.Path, p0.low, low))
		else
			check(pv == p0.pivot and m:GetAttribute("LindenmoorPrepFrom") == nil, e.Path .. " moved, though already above the ground")
			table.insert(notes, string.format("not lifted (already above) %s: lowest y %.2f, top %.2f", e.Path, low, e.Top))
		end
	end
end

-- ---------------------------------------------------------------- 4. undo
if applied then
	local ok, res = pcall(Prep, "undo")
	table.insert(notes, "undo: " .. tostring(res))
	check(ok and type(res) == "string" and string.find(res, " OK:") ~= nil, "undo did not succeed: " .. tostring(res))
end

-- ---------------------------------------------------------------- 5. Ye as it started
check(Map:GetAttribute("LindenmoorPrep") == nil, "LindenmoorPrep still set")
check(not (SS:FindFirstChild("RenseiBackups") and SS.RenseiBackups:FindFirstChild(BACKUP)), "backup folder left behind")
local stray = 0
for _, d in ipairs(workspace:GetDescendants()) do
	if d:GetAttribute("LindenmoorPrepFrom") ~= nil or d:GetAttribute("FromPath") ~= nil then stray += 1 end
end
check(stray == 0, stray .. " instances still carry LindenmoorPrepFrom / FromPath")
local rows1, tags1 = snapshot()
local nA, nB, diff = diffRows(rows0, rows1, 6)
check(nA == 0 and nB == 0, string.format("snapshot differs: %d rows only before, %d only after\n%s", nA, nB, table.concat(diff, "\n")))
for t, n in pairs(tags0) do
	check(tags1[t] == n, string.format("tag %s: %d before, %s after", t, n, tostring(tags1[t])))
end
for t, n in pairs(tags1) do
	check(tags0[t] ~= nil, string.format("tag %s: new after the test (%d)", t, n))
end
local ntags = 0
for _ in pairs(tags0) do ntags += 1 end
table.insert(notes, string.format("snapshot: %d rows before, %d after, equal = %s; %d tags in workspace", #rows0, #rows1,
	tostring(nA == 0 and nB == 0), ntags))

return (#fails == 0 and "PASS" or ("FAIL (" .. #fails .. ")\n" .. table.concat(fails, "\n"))) .. "\n--\n" .. table.concat(notes, "\n")

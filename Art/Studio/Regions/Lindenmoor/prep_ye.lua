-- prep_ye.lua: Lindenmoor import Task 5. Readies Ye (placeId 106992859583940) for the expansion, reversibly.
-- Run the bundle (pads.json inlined), Edit, never in Play:
--   python -I Art/Studio/Regions/Lindenmoor/bundle_prep.py prep <out.lua> apply|undo
--   python -I Art/Tools/rbxc.py luau "placeId: 106992859583940" Edit @<out.lua>
--
-- apply (refused if the backup folder or World.Map's LindenmoorPrep attribute already exists):
--   1. retires World.Map.Lindenmoor.NorthRoad (RoadStart arrival + the five road-passage legs), .HubRoad, the
--      Station BufferStop within 5 studs of (-270, 10, -369) (the one at z -891 stays) and World.EnemySpawns'
--      two GruntSpawns (Ruling 8): each is MOVED (not cloned, so nothing non-archivable is lost and references
--      stay valid) into ServerStorage.RenseiBackups[BACKUP] with its old full path in the attribute FromPath and
--      its old parent in a child ObjectValue, LindenmoorPrepParent (undo prefers it; the path is the fallback);
--   2. moves each pad's blocks (pads.json, from pad_layout.arrange: Rulings 4, 5) so a block's XZ centre (its
--      parts' world box) sits at pad centre + slot, raised by pad height - GROUND (the Baseplate top the hub
--      stands on today), with the models standing on it (pads.json Riders) by the same offset;
--   3. moves each AlchemistSpawns child to its pads.json spot (site slot, pulled in, nudged clear: Ruling 7);
--   4. moves World.EnemySpawns.EliteSpawn to its Bramble Woods spot (Ruling 8; PROPOSAL);
--   5. stands each trainer (World.NPCs["Alchemy Trainers"], by DialogueId trainer_<element>) on its TrainerSpot,
--      feet on the ground, facing the spot's Yaw (0 = -Z: into the training field, per the spec);
--   6. lifts every other item outside World.Map (workspace root, World.NPCs / EnemySpawns / Live ...) that stands on
--      the expansion's new ground (pads.json Lift, from lift_survey.lua + make_pads.py: Ruling 17): its lowest point
--      goes to the highest planned top under its XZ box + 0.05, if it is below that. The summary lists each lift;
--   7. sets World.Map's LindenmoorPrep = "applied".
--   Every moved instance records its old CFrame (Parts) or pivot (Models) in LindenmoorPrepFrom, a 12-number CFrame string.
-- undo (refused while World.Map has FoundryMove: undo Art/Studio/Regions/Foundry/forge/retire_ye.lua first; refused unless applied): moves every workspace instance with LindenmoorPrepFrom back and clears it, returns every backup
--   child to its LindenmoorPrepParent (else FromPath) parent and clears both, deletes the backup folder (and
--   RenseiBackups, if apply created it and it is now empty), clears LindenmoorPrep. Apply's summary names the
--   pads.json it ran (PADS_HASH: first 8 hex of its sha256; bundle_prep.py refuses a stale pads.json).
-- Both modes check everything before changing anything, journal each change, and roll the journal back if any
-- step errors. They return one summary line (" OK:", "REFUSED:" or "FAILED").
local MODE = "apply" -- "apply" or "undo"
local PADS_JSON = nil -- pads.json, inlined by bundle_prep.py (run the bundle, not this file)

local HttpService = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local BACKUP = "Pre-LindenmoorExpansion_2026-10-24"
local TOL = 0.3 -- studs: a block's live box may differ this much from the survey's before apply refuses (survey rounds to 0.1)

local function refuse(msg) return "LindenmoorPrep " .. tostring(MODE) .. " REFUSED: " .. msg end

if MODE ~= "apply" and MODE ~= "undo" then return refuse("MODE must be apply or undo") end
if game:GetService("RunService"):IsRunning() then return refuse("run in Edit, not Play") end
if SS:GetAttribute("PlayLock") then return refuse("PlayLock is set (" .. tostring(SS:GetAttribute("PlayLock")) .. ")") end
if type(PADS_JSON) ~= "string" or type(PADS_HASH) ~= "string" then return refuse("pads.json is not inlined: run bundle_prep.py's bundle") end
local PADS = HttpService:JSONDecode(PADS_JSON)
local World = workspace:FindFirstChild("World")
local Map = World and World:FindFirstChild("Map")
if not Map then return refuse("no workspace.World.Map") end

-- ---------------------------------------------------------------- helpers
local function cfString(cf)
	local c = { cf:GetComponents() }
	for i = 1, 12 do c[i] = string.format("%.17g", c[i]) end
	return table.concat(c, ",")
end
local function cfParse(s)
	local t = string.split(s, ",")
	assert(#t == 12, "bad LindenmoorPrepFrom: " .. s)
	local n = {}
	for i, v in ipairs(t) do n[i] = assert(tonumber(v), "bad LindenmoorPrepFrom number: " .. v) end
	return CFrame.new(table.unpack(n))
end
-- a Part moves by its CFrame and a Model by its pivot, so undo puts back exactly what apply read
local function pivotOf(inst) return inst:IsA("BasePart") and inst.CFrame or inst:GetPivot() end
local function setPivot(inst, cf)
	if inst:IsA("BasePart") then inst.CFrame = cf else inst:PivotTo(cf) end
end
local function boxOf(list) -- world AABB of every part in the instances: {x0, y0, z0, x1, y1, z1}
	local b = { math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge }
	local function add(p)
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
	for _, inst in ipairs(list) do
		if inst:IsA("BasePart") then add(inst) end
		for _, d in ipairs(inst:GetDescendants()) do
			if d:IsA("BasePart") then add(d) end
		end
	end
	assert(b[1] < math.huge, "no parts")
	return b
end
local function resolve(path) -- "Workspace.World.Map..." or "World.Map...": the unique instance at that path, or nil
	local parts = string.split(path, ".")
	local node, i = workspace, 1
	if parts[1] == "Workspace" then i = 2 end
	for k = i, #parts do
		local hit, n = nil, 0
		for _, c in ipairs(node:GetChildren()) do
			if c.Name == parts[k] then hit, n = c, n + 1 end
		end
		if n ~= 1 then return nil end
		node = hit
	end
	return node
end
local function namedChildren(parent, name)
	local t = {}
	for _, c in ipairs(parent:GetChildren()) do
		if c.Name == name then table.insert(t, c) end
	end
	return t
end
local function backupsFolder() return SS:FindFirstChild("RenseiBackups") end

-- LIFT WALK BEGIN (lift_survey.lua carries an identical copy)
local function liftCandidates()
	local out = {}
	local function walk(node)
		for _, c in ipairs(node:GetChildren()) do
			if c:IsA("PVInstance") then
				if not (c:IsA("Terrain") or c:IsA("Camera")) then table.insert(out, c) end
			elseif #c:GetChildren() > 0 then
				walk(c)
			end
		end
	end
	local World = workspace:FindFirstChild("World")
	for _, c in ipairs(workspace:GetChildren()) do
		if c == World then
			for _, w in ipairs(World:GetChildren()) do
				if w.Name ~= "Map" then
					if w:IsA("PVInstance") then table.insert(out, w) else walk(w) end
				end
			end
		elseif c:IsA("PVInstance") then
			if not (c:IsA("Terrain") or c:IsA("Camera")) then table.insert(out, c) end
		elseif c.Name ~= "Cameras" and #c:GetChildren() > 0 then
			walk(c)
		end
	end
	return out
end
-- LIFT WALK END

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

local CHS = game:GetService("ChangeHistoryService")
local recording
pcall(function() recording = CHS:TryBeginRecording("LindenmoorPrep " .. MODE) end)
local function cancelRecording() -- a refusal changed nothing: close the recording without a history entry
	if recording then
		pcall(function() CHS:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel) end)
		recording = nil
	end
end
local function waypoint()
	if recording then
		pcall(function() CHS:FinishRecording(recording, Enum.FinishRecordingOperation.Commit) end)
	else
		pcall(function() CHS:SetWaypoint("LindenmoorPrep " .. MODE) end)
	end
end

local moved, retired, trainers, restored = 0, 0, 0, 0
local lifted = {} -- "path y old -> new" (lowest point), for the summary
local LIFT_CLEAR = 0.05 -- Ruling 17 (make_pads.py's LIFT_CLEAR)
local function moveTo(inst, cf)
	local old = pivotOf(inst)
	assert(inst:GetAttribute("LindenmoorPrepFrom") == nil, inst:GetFullName() .. " already has LindenmoorPrepFrom")
	did(function()
		setPivot(inst, old)
		inst:SetAttribute("LindenmoorPrepFrom", nil)
	end)
	inst:SetAttribute("LindenmoorPrepFrom", cfString(old))
	setPivot(inst, cf)
	moved += 1
end

-- ================================================================ apply
local function planApply()
	-- every check before any change; returns the work list or an error string
	if Map:GetAttribute("LindenmoorPrep") ~= nil then return nil, "World.Map already has LindenmoorPrep = " .. tostring(Map:GetAttribute("LindenmoorPrep")) end
	local rb = backupsFolder()
	if rb and rb:FindFirstChild(BACKUP) then return nil, "ServerStorage.RenseiBackups." .. BACKUP .. " already exists" end
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:GetAttribute("LindenmoorPrepFrom") ~= nil or d:GetAttribute("FromPath") ~= nil then
			return nil, d:GetFullName() .. " already carries LindenmoorPrepFrom / FromPath"
		end
	end
	local W = { retire = {}, blocks = {}, spawns = {}, trainers = {} }

	-- retire list (pads.json Retire): a path plus a count, or one near a point
	for _, r in ipairs(PADS.Retire) do
		local parentPath, name = string.match(r.Path, "^(.*)%.([^%.]+)$")
		local parent = resolve(parentPath)
		if not parent then return nil, "retire: no unique " .. parentPath end
		local hits = namedChildren(parent, name)
		if r.Near then
			local p, keep = Vector3.new(r.Near[1], r.Near[2], r.Near[3]), {}
			for _, h in ipairs(hits) do
				if (h:GetPivot().Position - p).Magnitude <= r.Within then table.insert(keep, h) end
			end
			hits = keep
		end
		if #hits ~= r.Count then return nil, string.format("retire: %d of %s, expected %d", #hits, r.Path, r.Count) end
		for _, h in ipairs(hits) do table.insert(W.retire, h) end
	end

	-- pads: blocks (by instance: the two Walls are told apart by being instances, both in the TestArena block)
	local children = Map:GetChildren()
	local claimed = {}
	for pid, pad in pairs(PADS) do
		if type(pad) == "table" and string.sub(pid, 1, 4) == "res_" then
			for _, b in ipairs(pad.Blocks) do
				local list = {}
				for _, mname in ipairs(b.Members) do
					local n = 0
					for _, c in ipairs(children) do
						if c.Name == mname then
							if claimed[c] then return nil, c:GetFullName() .. " is in two blocks" end
							claimed[c] = true
							n += 1
							table.insert(list, c)
						end
					end
					if n ~= b.Counts[mname] then return nil, string.format("block %s: %d Map children named %s, expected %d", b.Name, n, mname, b.Counts[mname]) end
				end
				local box = boxOf(list)
				local cx, cz = (box[1] + box[4]) / 2, (box[3] + box[6]) / 2
				if math.abs(cx - b.Center[1]) > TOL or math.abs(cz - b.Center[2]) > TOL or math.abs(box[2] - b.MinY) > TOL then
					return nil, string.format("block %s: live box centre (%.2f, %.2f) lowest %.2f, survey (%.2f, %.2f) %.2f: re-survey",
						b.Name, cx, cz, box[2], b.Center[1], b.Center[2], b.MinY)
				end
				local delta = Vector3.new(pad.At[1] + b.Slot[1] - cx, pad.At[2] - PADS.Ground, pad.At[3] + b.Slot[2] - cz)
				local riders = {}
				for _, r in ipairs(b.Riders) do
					local folder, name = string.match(r, "^([^/]+)/(.+)$")
					local f = World:FindFirstChild(folder)
					local hits = f and namedChildren(f, name) or {}
					if #hits ~= 1 then return nil, string.format("rider %s: found %d", r, #hits) end
					local p = hits[1]:GetPivot().Position
					if p.X < box[1] or p.X > box[4] or p.Z < box[3] or p.Z > box[6] then
						return nil, "rider " .. r .. " is no longer on block " .. b.Name
					end
					table.insert(riders, hits[1])
				end
				table.insert(W.blocks, { pad = pid, block = b, list = list, riders = riders, delta = delta,
					box = { box[1] + delta.X, box[2] + delta.Y, box[3] + delta.Z, box[4] + delta.X, box[5] + delta.Y, box[6] + delta.Z } })
			end
		end
	end

	-- alchemist spawns: every child must have a spot (none left behind on the old hub)
	local AS = Map:FindFirstChild("AlchemistSpawns")
	if not AS then return nil, "no World.Map.AlchemistSpawns" end
	local seen = {}
	for _, s in ipairs(AS:GetChildren()) do
		local want = PADS.Spawns[s.Name]
		if not want or not s:IsA("BasePart") then return nil, "AlchemistSpawns." .. s.Name .. " has no pads.json spot" end
		if seen[s.Name] then return nil, "two AlchemistSpawns named " .. s.Name end
		local p, f = s.Position, want.From
		if math.abs(p.X - f[1]) > TOL or math.abs(p.Y - f[2]) > TOL or math.abs(p.Z - f[3]) > TOL then
			return nil, string.format("AlchemistSpawns.%s at %s, survey (%.1f, %.1f, %.1f): re-survey", s.Name, tostring(p), f[1], f[2], f[3])
		end
		seen[s.Name] = true
		table.insert(W.spawns, { inst = s, want = want })
	end
	for name in pairs(PADS.Spawns) do
		if not seen[name] then return nil, "AlchemistSpawns." .. name .. " is missing" end
	end
	local ES = World:FindFirstChild("EnemySpawns")
	local elites = ES and namedChildren(ES, "EliteSpawn") or {}
	if #elites ~= 1 then return nil, #elites .. " World.EnemySpawns.EliteSpawn, expected 1" end
	W.elite = elites[1]
	local ep, ef = W.elite.Position, PADS.EliteSpawn.From
	if math.abs(ep.X - ef[1]) > TOL or math.abs(ep.Y - ef[2]) > TOL or math.abs(ep.Z - ef[3]) > TOL then
		return nil, string.format("EliteSpawn at %s, survey (%.1f, %.1f, %.1f): re-survey", tostring(ep), ef[1], ef[2], ef[3])
	end

	-- trainers, by element
	local folder = World:FindFirstChild("NPCs") and World.NPCs:FindFirstChild("Alchemy Trainers")
	if not folder then return nil, "no World.NPCs[\"Alchemy Trainers\"]" end
	local used = {}
	for _, m in ipairs(folder:GetChildren()) do
		local el = string.match(tostring(m:GetAttribute("DialogueId")), "^trainer_(%a+)$")
		local spot = el and PADS["trainer_" .. el]
		if not (m:IsA("Model") and spot) then return nil, "trainer " .. m.Name .. " has no TrainerSpot" end
		if used[el] then return nil, "two trainers for " .. el end
		used[el] = true
		table.insert(W.trainers, { inst = m, spot = spot })
	end
	if #W.trainers ~= 5 then return nil, #W.trainers .. " trainers, expected 5" end

	-- Ruling 17: items outside World.Map on the expansion's new ground (pads.json Lift). Every candidate the prep
	-- doesn't already move must be in pads.json (same path, pivot within 0.5), or the list is stale.
	local planned = {}
	for _, i in ipairs(W.retire) do planned[i] = true end
	for _, w in ipairs(W.blocks) do
		for _, i in ipairs(w.riders) do planned[i] = true end
	end
	for _, t in ipairs(W.trainers) do planned[t.inst] = true end
	planned[W.elite] = true
	W.lift = {}
	for _, c in ipairs(liftCandidates()) do
		if not planned[c] then
			local p, hit, n = c:GetPivot().Position, nil, 0
			for _, e in ipairs(PADS.Lift) do
				if e.Path == c:GetFullName() and (Vector3.new(e.Pivot[1], e.Pivot[2], e.Pivot[3]) - p).Magnitude <= 0.5 then
					hit, n = e, n + 1
				end
			end
			if n ~= 1 then
				return nil, string.format("%s at %s: %d pads.json Lift entries (re-run lift_survey.lua, then make_pads.py)", c:GetFullName(), tostring(p), n)
			end
			if hit.Top ~= nil then table.insert(W.lift, { inst = c, top = hit.Top }) end
		end
	end
	return W
end

local function doApply(W)
	-- the backup folder
	local rb, createdRb = backupsFolder(), false
	if not rb then
		rb = Instance.new("Folder")
		rb.Name = "RenseiBackups"
		rb.Parent = SS
		did(function() rb:Destroy() end)
		createdRb = true
	end
	local bk = Instance.new("Folder")
	bk.Name = BACKUP
	bk:SetAttribute("Note", "Lindenmoor import Task 5: pieces retired by prep_ye.lua apply; undo puts them back (LindenmoorPrepParent, else FromPath)")
	if createdRb then bk:SetAttribute("CreatedRenseiBackups", true) end -- undo removes RenseiBackups again if left empty
	bk.Parent = rb
	did(function() bk:Destroy() end)

	-- 1. retire
	for _, inst in ipairs(W.retire) do
		local parent = inst.Parent
		local ov = Instance.new("ObjectValue") -- the parent by identity; FromPath is the fallback (names can repeat or hold dots)
		ov.Name = "LindenmoorPrepParent"
		ov.Value = parent
		did(function()
			ov:Destroy()
			inst.Parent = parent
			inst:SetAttribute("FromPath", nil)
		end)
		inst:SetAttribute("FromPath", inst:GetFullName())
		ov.Parent = inst
		inst.Parent = bk
		retired += 1
	end

	-- 2. blocks and riders (a pure translation keeps each block's own layout)
	for _, w in ipairs(W.blocks) do
		for _, inst in ipairs(w.list) do moveTo(inst, pivotOf(inst) + w.delta) end
		for _, inst in ipairs(w.riders) do moveTo(inst, pivotOf(inst) + w.delta) end
	end

	-- 3. alchemist spawns, then the no-overlap check against every block on the spawn's pad
	local onPad = {}
	for _, w in ipairs(W.blocks) do
		onPad[w.pad] = onPad[w.pad] or {}
		table.insert(onPad[w.pad], w)
	end
	for _, s in ipairs(W.spawns) do
		local cf = s.inst.CFrame
		moveTo(s.inst, cf.Rotation + Vector3.new(s.want.XZ[1], cf.Position.Y + s.want.DY, s.want.XZ[2]))
		local sb = boxOf({ s.inst })
		for _, w in ipairs(onPad[s.want.Pad] or {}) do
			local b = w.box
			if sb[1] < b[4] and b[1] < sb[4] and sb[3] < b[6] and b[3] < sb[6] then
				error(s.inst.Name .. " would overlap block " .. w.block.Name)
			end
		end
	end

	-- 4. the EliteSpawn
	local e = W.elite.CFrame
	moveTo(W.elite, e.Rotation + Vector3.new(PADS.EliteSpawn.XZ[1], e.Position.Y + PADS.EliteSpawn.DY, PADS.EliteSpawn.XZ[2]))

	-- 5. trainers: feet (lowest part) on the spot's ground, facing its Yaw
	for _, t in ipairs(W.trainers) do
		local pv = t.inst:GetPivot()
		local lift = pv.Position.Y - boxOf({ t.inst })[2]
		local a = t.spot.At
		moveTo(t.inst, CFrame.new(a[1], a[2] + lift, a[3]) * CFrame.Angles(0, math.rad(t.spot.Yaw), 0))
		trainers += 1
	end

	-- 6. lift what the new ground would bury (Ruling 17): lowest point to the planned top + LIFT_CLEAR
	for _, l in ipairs(W.lift) do
		local base = boxOf({ l.inst })[2]
		local want = l.top + LIFT_CLEAR
		if base < want then
			moveTo(l.inst, pivotOf(l.inst) + Vector3.new(0, want - base, 0))
			table.insert(lifted, string.format("%s y %.2f -> %.2f", l.inst:GetFullName(), base, want))
		end
	end

	-- 7. done
	did(function() Map:SetAttribute("LindenmoorPrep", nil) end)
	Map:SetAttribute("LindenmoorPrep", "applied")
end

-- ================================================================ undo
local function planUndo()
	-- (Foundry Yard plan Task 8, Ruling 12) Brannoc, the forge rooms and the Ward spawn sit in the Foundry move's backup:
	-- undo that first, or this undo would act on a half-moved world. Refuses before anything is planned or changed.
	if Map:GetAttribute("FoundryMove") ~= nil then return nil, "World.Map has FoundryMove (" .. tostring(Map:GetAttribute("FoundryMove")) .. "): undo the Foundry move first (Art/Studio/Regions/Foundry/forge/retire_ye.lua undo)" end
	if Map:GetAttribute("LindenmoorPrep") ~= "applied" then return nil, "World.Map's LindenmoorPrep is not \"applied\"" end
	local rb = backupsFolder()
	local bk = rb and rb:FindFirstChild(BACKUP)
	if not bk then return nil, "no ServerStorage.RenseiBackups." .. BACKUP end
	local W = { bk = bk, moves = {}, back = {} }
	for _, d in ipairs(workspace:GetDescendants()) do
		local s = d:GetAttribute("LindenmoorPrepFrom")
		if s ~= nil then
			if type(s) ~= "string" then return nil, d:GetFullName() .. ": LindenmoorPrepFrom is not a string" end
			local ok, cf = pcall(cfParse, s)
			if not ok then return nil, d:GetFullName() .. ": " .. tostring(cf) end
			table.insert(W.moves, { inst = d, cf = cf })
		end
	end
	for _, c in ipairs(bk:GetChildren()) do
		local path = c:GetAttribute("FromPath")
		local ov = c:FindFirstChild("LindenmoorPrepParent")
		local parent = ov and ov:IsA("ObjectValue") and ov.Value
		if not (parent and parent:IsDescendantOf(game)) then -- the original parent is gone: fall back to the path
			local parentPath = type(path) == "string" and string.match(path, "^(.*)%.[^%.]+$")
			parent = parentPath and resolve(parentPath)
		end
		if not parent then return nil, "backup child " .. c.Name .. ": no live LindenmoorPrepParent and no unique parent for FromPath " .. tostring(path) end
		table.insert(W.back, { inst = c, parent = parent, path = path, ov = ov })
	end
	return W
end

local function doUndo(W)
	for _, m in ipairs(W.moves) do
		local cur, s = pivotOf(m.inst), m.inst:GetAttribute("LindenmoorPrepFrom")
		did(function()
			setPivot(m.inst, cur)
			m.inst:SetAttribute("LindenmoorPrepFrom", s)
		end)
		setPivot(m.inst, m.cf)
		m.inst:SetAttribute("LindenmoorPrepFrom", nil)
		moved += 1
	end
	for _, b in ipairs(W.back) do
		local ov = b.ov
		did(function()
			b.inst.Parent = W.bk
			b.inst:SetAttribute("FromPath", b.path)
			if ov then ov.Parent = b.inst end
		end)
		b.inst.Parent = b.parent
		b.inst:SetAttribute("FromPath", nil)
		if ov then ov.Parent = nil end
		restored += 1
	end
	for _, m in ipairs(W.moves) do
		if m.inst.Parent and m.inst.Parent.Name == "Alchemy Trainers" then trainers += 1 end
	end
	did(function() Map:SetAttribute("LindenmoorPrep", "applied") end)
	Map:SetAttribute("LindenmoorPrep", nil)
	if #W.bk:GetChildren() ~= 0 then error("backup folder not empty after restoring") end
	-- last, and not journaled: nothing is left in it
	local rb, created = W.bk.Parent, W.bk:GetAttribute("CreatedRenseiBackups")
	W.bk:Destroy()
	if created and rb and #rb:GetChildren() == 0 then rb:Destroy() end -- apply made RenseiBackups: leave none behind
end

-- ================================================================ run
local W, why
if MODE == "apply" then W, why = planApply() else W, why = planUndo() end
if not W then
	cancelRecording()
	return refuse(why)
end
local ok, err = pcall(MODE == "apply" and doApply or doUndo, W)
if not ok then
	local errs = rollback()
	waypoint()
	return string.format("LindenmoorPrep %s FAILED (rolled back%s): %s", MODE,
		#errs > 0 and (", " .. #errs .. " rollback errors: " .. table.concat(errs, "; ")) or "", tostring(err))
end
journal = {}
waypoint()
if MODE == "apply" then
	return string.format("LindenmoorPrep apply OK: moved %d, retired %d, trainers %d (blocks %d, spawns %d, elite 1, lifted %d; pads.json %s)%s",
		moved, retired, trainers, #W.blocks, #W.spawns, #lifted, PADS_HASH, #lifted > 0 and ("\n  lifted: " .. table.concat(lifted, "\n  lifted: ")) or "")
end
return string.format("LindenmoorPrep undo OK: moved back %d, restored %d, trainers %d", moved, restored, trainers)

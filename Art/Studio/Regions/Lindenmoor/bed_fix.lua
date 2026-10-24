--!nocheck
-- bed_fix.lua — Lindenmoor import, Ruling 28 (follow-up to the gorge fix, Ruling 23). The owner: "I don't want to see
-- the ground here". After gorge_fix.lua filled the channels with water to y 5.2, the Grass channel bed (top y 1)
-- still reads green through the clear water beside the dark walls. This changes the Grass ground parts whose top face
-- is the channel bed — under the water, in the gorge and the west creek — to a creek-bed material.
-- Runs in Ye (placeId 106992859583940), Edit:
--   python -I Art/Tools/rbxc.py luau "placeId: 106992859583940" Edit @<this file, MODE/PICK edited>
-- MODE = "plan"    read-only: lists the parts that would change (count, materials, extent).
-- MODE = "bed"     refuses if LindenmoorExpansion has the attribute LindenmoorGorgeBed. Each chosen part keeps its
--                  instance; its original Material, Color and MaterialVariant go into the attribute GorgeBedFrom
--                  ("Material|RRGGBB|Variant"), then it takes CANDIDATES[PICK]. Journaled; one ChangeHistory waypoint.
-- MODE = "bedundo" restores every part with GorgeBedFrom and clears the attributes.
-- MODE = "check"   read-only: a 2-stud top-down raycast grid over both channels; wherever water lies on top, the
--                  ground face below 5.2 must not be Grass.
-- MODE = "test"    snapshot (every Ground/Edging part's material, colour, variant, attributes) -> bed -> check ->
--                  bedundo -> snapshot equal. Leaves Ye as it was.
-- Selection: a part of LindenmoorExpansion.Ground whose material is Grass or Ground (Ruling 29) and whose top face (the first ground hit
-- under a point where a top-down ray meets Water first) is at or below TOP, inside the two water regions of
-- gorge_fix.lua. Banks (tops above 5.2), the ledge walk and the Edging rocks are not touched.
local MODE = "plan" -- "plan", "bed", "bedundo", "check" or "test"
local PICK = "slate" -- a key of CANDIDATES (PROPOSAL; chosen from lit screenshots)

local CHS = game:GetService("ChangeHistoryService")
local CANDIDATES = { -- PROPOSAL: walls are Slate #423c34
	slate = {Material = Enum.Material.Slate, Color = Color3.fromHex("423c34")},
	mud = {Material = Enum.Material.Mud, Color = Color3.fromHex("3d3328")},
	pebble = {Material = Enum.Material.Pebble, Color = Color3.fromHex("4b4438")},
}
local ATTR, FROM = "LindenmoorGorgeBed", "GorgeBedFrom"
local TOP = 5.2
local BEDMATS = {[Enum.Material.Grass] = true, [Enum.Material.Ground] = true} -- Ruling 29: the brown dirt bed too
local REGIONS = {{336, 1024, -624, -468}, {-1024, -336, -576, -476}} -- gorge_fix.lua's WATER regions (x0, x1, z0, z1)

local function refuse(why) return "GorgeBed " .. MODE .. " REFUSED: " .. why end
local E = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Map") and workspace.World.Map:FindFirstChild("LindenmoorExpansion")
if not E then return refuse("no LindenmoorExpansion") end
local Ground, Edging = E:FindFirstChild("Ground"), E:FindFirstChild("Edging")
if not (Ground and Edging) then return refuse("no Ground/Edging") end
local pick = CANDIDATES[PICK]
if not pick then return refuse("PICK " .. tostring(PICK) .. " is not a candidate") end

local rpG = RaycastParams.new()
rpG.FilterType = Enum.RaycastFilterType.Include
rpG.FilterDescendantsInstances = {Ground, Edging}
local rpW = RaycastParams.new()
rpW.FilterType = Enum.RaycastFilterType.Include
rpW.FilterDescendantsInstances = {Ground, Edging, workspace.Terrain}
rpW.IgnoreWater = false

-- calls fn(groundHit, x, z) for every grid point where a top-down ray meets Water before the ground
local function scan(fn)
	for _, R in ipairs(REGIONS) do
		for x = R[1] + 1, R[2] - 1, 2 do
			for z = R[3] + 1, R[4] - 1, 2 do
				local w = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), rpW)
				if w and w.Instance == workspace.Terrain and w.Material == Enum.Material.Water then
					local g = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), rpG)
					if g and g.Position.Y <= TOP then fn(g, x, z) end
				end
			end
		end
	end
end

local function select()
	local set, list = {}, {}
	scan(function(g)
		local p = g.Instance
		if not set[p] and p:IsDescendantOf(Ground) and BEDMATS[p.Material] then
			set[p] = true
			table.insert(list, p)
		end
	end)
	return list
end

local function check()
	local n, bad, ex = 0, 0, nil
	local mats = {}
	scan(function(g, x, z)
		n += 1
		mats[g.Instance.Material.Name] = (mats[g.Instance.Material.Name] or 0) + 1
		if BEDMATS[g.Instance.Material] then bad += 1; ex = ex or string.format("(%d, %d) %s", x, z, g.Instance:GetFullName()) end
	end)
	local m = {}
	for k, v in pairs(mats) do table.insert(m, k .. " " .. v) end
	table.sort(m)
	-- every changed part: its top, sampled on a 2-stud grid, lies under water (none shows in the open)
	local nP, dry, dex = 0, 0, nil
	for _, p in ipairs(Ground:GetDescendants()) do
		if p:IsA("BasePart") and p:GetAttribute(FROM) then
			nP += 1
			for dx = -p.Size.X / 2 + 1, p.Size.X / 2 - 1, 2 do
				for dz = -p.Size.Z / 2 + 1, p.Size.Z / 2 - 1, 2 do
					local x, z = p.Position.X + dx, p.Position.Z + dz
					local g = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), rpG)
					if g and g.Instance == p then
						local w = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), rpW)
						if not (w and w.Instance == workspace.Terrain and w.Material == Enum.Material.Water) then
							dry += 1; dex = dex or string.format("(%.0f, %.0f) %s", x, z, p.Name)
						end
					end
				end
			end
		end
	end
	if dry > 0 then bad += dry end
	return bad, string.format("%s bed check: %d grid points under water; %d hit Grass/Ground below %.1f%s; bed faces: %s; changed parts %d, dry top points %d%s",
		bad == 0 and "PASS" or "FAIL", n, bad - dry, TOP, ex and (" (e.g. " .. ex .. ")") or "", table.concat(m, ", "), nP, dry, dex and (" (e.g. " .. dex .. ")") or "")
end

local journal = {}
local function rollback()
	for i = #journal, 1, -1 do pcall(journal[i]) end
	journal = {}
end
local function withRecording(name, fn)
	local rec
	pcall(function() rec = CHS:TryBeginRecording(name) end)
	local ok, a, b = pcall(fn)
	if not ok then rollback() end
	journal = {}
	if rec then pcall(function() CHS:FinishRecording(rec, ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel) end)
	else pcall(function() CHS:SetWaypoint(name) end) end
	return ok, a, b
end

local function doBed()
	if E:GetAttribute(ATTR) then return nil, "already applied (" .. tostring(E:GetAttribute(ATTR)) .. ")" end
	local list = select()
	if #list == 0 then return nil, "no Grass bed parts found" end
	local ok, err = withRecording("LindenmoorGorgeBed bed", function()
		for _, p in ipairs(list) do
			local m, c, v = p.Material, p.Color, p.MaterialVariant
			p:SetAttribute(FROM, m.Name .. "|" .. c:ToHex() .. "|" .. v)
			p.Material, p.Color, p.MaterialVariant = pick.Material, pick.Color, ""
			table.insert(journal, function() p.Material, p.Color, p.MaterialVariant = m, c, v; p:SetAttribute(FROM, nil) end)
		end
		E:SetAttribute(ATTR, PICK .. " " .. #list .. " parts, 2026-10-24")
		table.insert(journal, function() E:SetAttribute(ATTR, nil) end)
	end)
	if not ok then return nil, "FAILED (rolled back): " .. tostring(err) end
	return #list
end

local function doBedUndo()
	if not E:GetAttribute(ATTR) then return nil, "LindenmoorExpansion has no " .. ATTR end
	local n = 0
	local ok, err = withRecording("LindenmoorGorgeBed bedundo", function()
		for _, p in ipairs(Ground:GetDescendants()) do
			local s = p:IsA("BasePart") and p:GetAttribute(FROM)
			if s then
				local m, c, v = string.match(s, "^([^|]*)|([^|]*)|(.*)$")
				local om, oc, ov = p.Material, p.Color, p.MaterialVariant
				p.Material, p.Color, p.MaterialVariant = Enum.Material[m], Color3.fromHex(c), v
				p:SetAttribute(FROM, nil)
				table.insert(journal, function() p.Material, p.Color, p.MaterialVariant = om, oc, ov; p:SetAttribute(FROM, s) end)
				n += 1
			end
		end
		local a = E:GetAttribute(ATTR)
		E:SetAttribute(ATTR, nil)
		table.insert(journal, function() E:SetAttribute(ATTR, a) end)
	end)
	if not ok then return nil, "FAILED (rolled back): " .. tostring(err) end
	return n
end

local function snapshot()
	local rows = {}
	for _, root in ipairs({Ground, Edging}) do
		for _, p in ipairs(root:GetDescendants()) do
			if p:IsA("BasePart") then
				local a = {}
				for k, v in pairs(p:GetAttributes()) do table.insert(a, k .. "=" .. tostring(v)) end
				table.sort(a)
				table.insert(rows, p:GetFullName() .. "|" .. p.Material.Name .. "|" .. p.Color:ToHex() .. "|" .. p.MaterialVariant .. "|" .. table.concat(a, ","))
			end
		end
	end
	table.sort(rows)
	table.insert(rows, "E " .. tostring(E:GetAttribute(ATTR)))
	return rows
end

if MODE == "plan" then
	local list = select()
	local x0, x1, z0, z1, ys = 1e9, -1e9, 1e9, -1e9, {}
	for _, p in ipairs(list) do
		x0, x1 = math.min(x0, p.Position.X - p.Size.X / 2), math.max(x1, p.Position.X + p.Size.X / 2)
		z0, z1 = math.min(z0, p.Position.Z - p.Size.Z / 2), math.max(z1, p.Position.Z + p.Size.Z / 2)
		local t = string.format("%.1f", p.Position.Y + p.Size.Y / 2)
		ys[t] = (ys[t] or 0) + 1
	end
	local yl = {}
	for k, v in pairs(ys) do table.insert(yl, k .. ":" .. v) end
	table.sort(yl)
	local _, c = check()
	return string.format("GorgeBed plan (read-only): %d Grass/Ground bed parts -> %s (%s #%s); extent x %.0f..%.0f z %.0f..%.0f; tops %s\nnow: %s",
		#list, PICK, pick.Material.Name, pick.Color:ToHex(), x0, x1, z0, z1, table.concat(yl, " "), c)
elseif MODE == "check" then
	local _, c = check()
	return c
elseif MODE == "bed" then
	local n, why = doBed()
	if not n then return refuse(why) end
	local _, c = check()
	return string.format("GorgeBed bed OK: %d parts -> %s (%s #%s)\n%s", n, PICK, pick.Material.Name, pick.Color:ToHex(), c)
elseif MODE == "bedundo" then
	local n, why = doBedUndo()
	if not n then return refuse(why) end
	return string.format("GorgeBed bedundo OK: %d parts restored", n)
elseif MODE == "test" then
	if E:GetAttribute(ATTR) then return refuse("already applied") end
	local s0 = snapshot()
	local n, why = doBed()
	if not n then return "TEST: bed refused/failed: " .. tostring(why) end
	local _, c = check()
	local m, why2 = doBedUndo()
	if not m then return "TEST: bedundo failed: " .. tostring(why2) .. "\n" .. c end
	local s1 = snapshot()
	local same = #s0 == #s1
	local diff
	if same then for i = 1, #s0 do if s0[i] ~= s1[i] then same = false; diff = s0[i] .. " vs " .. s1[i]; break end end end
	return string.format("TEST: bed %d parts; %s; bedundo %d; ROUND TRIP %s (%d rows)%s", n, c, m, same and "EQUAL" or "DIFFERS", #s0, diff and (": " .. diff) or "")
end
return refuse("MODE must be plan, bed, bedundo, check or test")

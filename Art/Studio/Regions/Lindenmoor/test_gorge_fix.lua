--!nocheck
-- test_gorge_fix.lua — Ruling 23 round trip in Ye (Edit): snapshot, apply, check, undo, compare the snapshot.
-- Bundle with: python -I Art/Studio/Regions/Lindenmoor/bundle_gorge_fix.py test <out.lua>
-- Snapshot = every instance under World.Map.LindenmoorExpansion (path, class, CFrame, size, look, attributes, tags,
-- model pivots), LindenmoorExpansion's attributes, the RenseiBackups child names, and the terrain voxels (rows y 0..12)
-- over both water regions, padded. Ye ends as it started unless the result says otherwise.
--[[GORGE_FIX]]

local CS = game:GetService("CollectionService")
local SS = game:GetService("ServerStorage")
local E = workspace.World.Map.LindenmoorExpansion
local REGIONS = {{324, 1028, -628, -464}, {-908, -312, -580, -472}}

local function attrs(i)
	local a = {}
	for k, v in pairs(i:GetAttributes()) do table.insert(a, k .. "=" .. tostring(v)) end
	table.sort(a)
	return table.concat(a, ",")
end
local function snapshot()
	local rows = {}
	for _, d in ipairs(E:GetDescendants()) do
		local s = d:GetFullName() .. "|" .. d.ClassName .. "|" .. attrs(d) .. "|" .. table.concat(CS:GetTags(d), ",")
		if d:IsA("BasePart") then
			local c = {d.CFrame:GetComponents()}
			for i = 1, #c do c[i] = string.format("%.4f", c[i]) end
			s ..= "|" .. table.concat(c, ",") .. string.format("|%.4f,%.4f,%.4f|%s|%s|%.3f|%s|%s|%s", d.Size.X, d.Size.Y, d.Size.Z,
				d.Material.Name, d.Color:ToHex(), d.Transparency, tostring(d.CanCollide), tostring(d.Anchored), d.MaterialVariant)
		elseif d:IsA("Model") then
			local c = {d.WorldPivot:GetComponents()}
			for i = 1, #c do c[i] = string.format("%.4f", c[i]) end
			s ..= "|pivot " .. table.concat(c, ",")
		end
		table.insert(rows, s)
	end
	table.sort(rows)
	table.insert(rows, "E attrs " .. attrs(E))
	local rb = SS:FindFirstChild("RenseiBackups")
	local names = {}
	if rb then for _, c in ipairs(rb:GetChildren()) do table.insert(names, c.Name) end end
	table.sort(names)
	table.insert(rows, "RenseiBackups " .. table.concat(names, ","))
	local vox = {}
	for _, R in ipairs(REGIONS) do
		local m, o = workspace.Terrain:ReadVoxels(Region3.new(Vector3.new(R[1], 0, R[3]), Vector3.new(R[2], 12, R[4])), 4)
		table.insert(vox, {m = m, o = o})
	end
	return rows, vox
end
local function same(a, b, va, vb)
	if #a ~= #b then
		-- first differing row
		local n = math.min(#a, #b)
		for i = 1, n do if a[i] ~= b[i] then return false, string.format("row count %d vs %d; first diff at %d:\n  %s\n  %s", #a, #b, i, a[i], b[i]) end end
		return false, string.format("row count %d vs %d", #a, #b)
	end
	for i = 1, #a do if a[i] ~= b[i] then return false, string.format("row %d:\n  %s\n  %s", i, a[i], b[i]) end end
	local nv = 0
	for r = 1, #va do
		local A, B = va[r], vb[r]
		for x = 1, #A.m do for y = 1, #A.m[x] do for z = 1, #A.m[x][y] do
			nv += 1
			if A.m[x][y][z] ~= B.m[x][y][z] or A.o[x][y][z] ~= B.o[x][y][z] then
				return false, string.format("voxel region %d [%d][%d][%d]: %s %.4f vs %s %.4f", r, x, y, z, A.m[x][y][z].Name, A.o[x][y][z], B.m[x][y][z].Name, B.o[x][y][z])
			end
		end end end
	end
	return true, string.format("%d rows, %d voxels equal", #a, nv)
end

local out = {}
local rows0, vox0 = snapshot()
local r1 = GorgeFix("apply")
table.insert(out, "apply: " .. string.sub(r1, 1, 400))
if not string.find(r1, "apply OK", 1, true) then
	local rowsF, voxF = snapshot()
	local okF, whyF = same(rows0, rowsF, vox0, voxF)
	return "TEST STOPPED (apply did not succeed); place unchanged: " .. tostring(okF) .. " " .. whyF .. "\n" .. table.concat(out, "\n")
end
local rowsA = snapshot()
local changed = 0
do
	local set = {}
	for _, s in ipairs(rows0) do set[s] = (set[s] or 0) + 1 end
	for _, s in ipairs(rowsA) do if set[s] and set[s] > 0 then set[s] -= 1 else changed += 1 end end
end
table.insert(out, string.format("after apply: %d snapshot rows new or changed (expected 50: 44 clones replacing 37 bridge pieces + Ribbon184 + 6 pit cells, 3 added parts, the footbridge pivot, E's attributes, the RenseiBackups list)", changed))
local r2 = GorgeFix("check")
table.insert(out, r2)
local r3 = GorgeFix("undo")
table.insert(out, "undo: " .. r3)
local rows1, vox1 = snapshot()
local ok, why = same(rows0, rows1, vox0, vox1)
table.insert(out, (ok and "ROUND TRIP EQUAL: " or "ROUND TRIP DIFFERS: ") .. why)
return table.concat(out, "\n")

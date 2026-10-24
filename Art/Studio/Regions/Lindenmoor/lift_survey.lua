-- lift_survey.lua: Lindenmoor import Task 5, Ruling 17. Read-only. Lists every item outside World.Map that prep_ye.lua
-- may have to lift off the expansion's new ground: the first Part or Model on each branch under workspace (not World,
-- Terrain or Cameras) and under World's children other than Map. Returns JSON:
--   [{"Path", "Class", "Pivot": [x, y, z], "Box": [x0, y0, z0, x1, y1, z1] or null}]
-- Save the output as lift_items.json (make_pads.py reads it):
--   python -I Art/Tools/rbxc.py luau "placeId: 106992859583940" Edit @lift_survey.lua > lift_items.json
-- prep_ye.lua finds candidates with this same walk and refuses if one is not in pads.json (re-run this, then make_pads.py).
local HttpService = game:GetService("HttpService")

local function boxOf(inst)
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
	if inst:IsA("BasePart") then add(inst) end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then add(d) end
	end
	if b[1] == math.huge then return nil end
	for k = 1, 6 do b[k] = math.floor(b[k] * 100 + 0.5) / 100 end
	return b
end

-- LIFT WALK BEGIN (prep_ye.lua carries an identical copy)
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

local rows = {}
for _, inst in ipairs(liftCandidates()) do
	local p = inst:GetPivot().Position
	table.insert(rows, { Path = inst:GetFullName(), Class = inst.ClassName,
		Pivot = { math.floor(p.X * 100 + 0.5) / 100, math.floor(p.Y * 100 + 0.5) / 100, math.floor(p.Z * 100 + 0.5) / 100 },
		Box = boxOf(inst) or HttpService:JSONDecode("null") })
end
return HttpService:JSONEncode(rows)

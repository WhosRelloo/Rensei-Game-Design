-- Lindenmoor settle pass (2026-10-20, owner: "Fix areas in the map that are out of place"). Run in Ye (Edit) after
-- ground.lua. Removed pieces go to RenseiBackups["Pre-Settle_2026-10-20"]. Every number is a PROPOSAL.
--   1. every kit model sits on the part ground (World.Map.Ground): trees on the lowest point under the trunk with the
--      trunk and roots extended down to the ground, stones / terraces / lamps / camp / barn on the ground under them
--   2. clipping: bank stones inside the station trestle or the gorge rocks, lamp bases in the road fence, fence
--      pieces inside the barn, ridge terraces through tree trunks (nudged, else removed), camp props in the tents,
--      big forest trunks inside other trunks
--   3. the workshop's three Prop_LowStoneWalls (single 30-47 stud beams lying on the slope) become dry-stone walls
--      along the same lines, each 3-4 stud stone seated on the ground
--   4. fence posts reach the ground
local SS = game:GetService("ServerStorage")
local Map = workspace.World.Map
local L = Map.Lindenmoor
local Ground = Map.Ground
local Backups = SS.RenseiBackups
local BK = Backups:FindFirstChild("Pre-Settle_2026-10-20") or Instance.new("Folder")
BK.Name = "Pre-Settle_2026-10-20"
BK.Parent = Backups
local rng = Random.new(9)
local log = {moved = 0, removed = 0, trunks = 0, nudged = 0, walls = 0, posts = 0}

local GR = RaycastParams.new()
GR.FilterType = Enum.RaycastFilterType.Include
GR.FilterDescendantsInstances = {Ground}
local function ground(x, z, fromY)
	local h = workspace:Raycast(Vector3.new(x, (fromY or 120) + 40, z), Vector3.new(0, -400, 0), GR)
	return h and h.Position.Y
end
local function backup(inst, why)
	inst:SetAttribute("RemovedBecause", why)
	inst.Parent = BK
	log.removed += 1
end
local function kitModels()
	local list = {}
	for _, d in ipairs(L:GetDescendants()) do
		if d:IsA("Model") and d:GetAttribute("LindenmoorKit") then table.insert(list, d) end
	end
	return list
end

-- 1. seat
for _, m in ipairs(kitModels()) do
	local kind = m:GetAttribute("LindenmoorKit")
	if kind ~= "Farmhouse" and kind ~= "Square" then
		local piv = m:GetPivot()
		local p = piv.Position
		local trunk = m:FindFirstChild("Trunk")
		local r = trunk and math.min(trunk.Size.X, trunk.Size.Z) * 0.45 or 0
		if not trunk then
			local _, size = m:GetBoundingBox()
			r = math.min(size.X, size.Z) * (kind == "RidgeTerrace" and 0.35 or 0.25)
		end
		local lo, hi = math.huge, -math.huge
		for _, d in ipairs({{0, 0}, {r, 0}, {-r, 0}, {0, r}, {0, -r}}) do
			local g = ground(p.X + d[1], p.Z + d[2], p.Y)
			if g then lo, hi = math.min(lo, g), math.max(hi, g) end
		end
		if lo < math.huge then
			-- trees and terraces stand on the lowest point (their trunk / slabs reach down); small things on the middle
			local target = (trunk or kind == "RidgeTerrace") and lo or (lo + hi) / 2
			local dy = target - p.Y
			if math.abs(dy) > 0.05 then
				m:PivotTo(piv + Vector3.new(0, dy, 0))
				log.moved += 1
			end
			if trunk then
				-- trunk bottom 0.5 under the lowest ground, top unchanged
				local topY = trunk.Position.Y + trunk.Size.Y / 2
				local want = lo - 0.5
				local botY = trunk.Position.Y - trunk.Size.Y / 2
				if botY > want then
					trunk.Size = Vector3.new(trunk.Size.X, topY - want, trunk.Size.Z)
					trunk.CFrame = trunk.CFrame - trunk.CFrame.Position + Vector3.new(trunk.Position.X, (topY + want) / 2, trunk.Position.Z)
					log.trunks += 1
				end
				for _, root in ipairs(m:GetChildren()) do
					if root:IsA("BasePart") and root.Name:sub(1, 4) == "Root" then
						local g = ground(root.Position.X, root.Position.Z, root.Position.Y)
						if g then root.CFrame = root.CFrame + Vector3.new(0, g - (root.Position.Y - root.Size.Y / 2) - 0.3, 0) end
					end
				end
			end
		end
	end
end
task.wait()

-- helper: does a part overlap anything in a list of containers
local function overlapsIn(part, containers)
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Include
	op.FilterDescendantsInstances = containers
	local hits = workspace:GetPartsInPart(part, op)
	return #hits > 0, hits
end

-- 2a. bank stones inside the station trestle or the gorge rocks
for _, m in ipairs(L.Scenery.CreekBanks:GetChildren()) do
	for _, part in ipairs(m:GetChildren()) do
		if part:IsA("BasePart") and overlapsIn(part, {L.Station, L.Gorge, L.Bridge}) then backup(m, "inside the station trestle / gorge / bridge") break end
	end
end
-- 2b. lamp bases in the road fence: slimmer base, else none
for _, m in ipairs(L.Lamps:GetChildren()) do
	local base = m:FindFirstChild("Base")
	if base and overlapsIn(base, {L.Fences}) then
		base.Size = Vector3.new(0.9, base.Size.Y, 0.9)
		if overlapsIn(base, {L.Fences}) then backup(base, "base in the fence") end
	end
end
-- 2c. fence pieces inside the barn body; hay stacks in the fence
local barn = L.Farm:FindFirstChild("Barn_Main")
if barn then
	for _, n in ipairs({"Body", "Plinth"}) do
		local b = barn:FindFirstChild(n)
		if b then
			local _, hits = overlapsIn(b, {L.Fences})
			for _, h in ipairs(hits) do if h.Parent then backup(h, "fence piece inside the barn") end end
		end
	end
	for _, h in ipairs(barn:GetChildren()) do
		if h:IsA("BasePart") and h.Name:sub(1, 8) == "HayStack" and overlapsIn(h, {L.Fences}) then backup(h, "hay stack in the fence") end
	end
end
-- 2d. ridge terraces through tree trunks: nudge up to 12 studs, else remove
local trunks = {}
for _, m in ipairs(kitModels()) do
	local t = m:FindFirstChild("Trunk")
	if t then table.insert(trunks, t) end
end
local function terraceHitsTrunk(m)
	for _, s in ipairs(m:GetChildren()) do
		if s:IsA("BasePart") and overlapsIn(s, trunks) then return true end
	end
	return false
end
for _, m in ipairs(L.Scenery.Ridge:GetChildren()) do
	if terraceHitsTrunk(m) then
		local piv = m:GetPivot()
		local done = false
		for _, off in ipairs({{6, 0}, {-6, 0}, {0, -6}, {9, -4}, {-9, -4}, {12, 0}, {-12, 0}, {0, -10}}) do
			local x, z = piv.Position.X + off[1], piv.Position.Z + off[2]
			local g = ground(x, z, piv.Position.Y) or piv.Position.Y
			m:PivotTo(CFrame.new(x, g, z) * piv.Rotation)
			if not terraceHitsTrunk(m) then done = true log.nudged += 1 break end
		end
		if not done then m:PivotTo(piv) backup(m, "terrace through tree trunks") end
	end
end
-- 2e. camp props clear of the tents
local props = L.Camp:FindFirstChild("CampProps_Main")
if props then
	local tents = {}
	for _, t in ipairs(L.Camp:GetChildren()) do if t.Name:sub(1, 8) == "TentHalf" then table.insert(tents, t) end end
	local function hit()
		for _, s in ipairs(props:GetChildren()) do if s:IsA("BasePart") and overlapsIn(s, tents) then return true end end
		return false
	end
	local piv = props:GetPivot()
	for step = 1, 8 do
		if not hit() then break end
		local p = piv.Position + Vector3.new(step * 2, 0, -step * 1.5)
		props:PivotTo(CFrame.new(p.X, ground(p.X, p.Z, p.Y) or p.Y, p.Z) * piv.Rotation)
	end
end
-- 2f. big forest trunks inside other trunks
for _, m in ipairs(L.Scenery.Forest:GetChildren()) do
	local t = m:FindFirstChild("Trunk")
	if t then
		local others = {}
		for _, o in ipairs(trunks) do if o ~= t and o.Parent then table.insert(others, o) end end
		if overlapsIn(t, others) then backup(m, "trunk inside another trunk") end
	end
end
task.wait()

-- 3. workshop walls: dry-stone stones along each old beam, seated on the ground
local W = L.Workshop.AutomailWorkshop
local wallsModel = L.Workshop:FindFirstChild("YardWalls")
if wallsModel then wallsModel:Destroy() end
wallsModel = Instance.new("Model")
wallsModel.Name = "YardWalls"
local STONES = {Color3.fromRGB(124, 127, 112), Color3.fromRGB(112, 116, 102), Color3.fromRGB(132, 132, 118)}
local beams = {}
for _, b in ipairs(W:GetChildren()) do if b:IsA("BasePart") and b.Name == "Prop_LowStoneWalls" then table.insert(beams, b) end end
for _, b in ipairs(BK:GetChildren()) do if b:IsA("BasePart") and b.Name == "Prop_LowStoneWalls" then table.insert(beams, b) end end -- re-runs
for _, beam in ipairs(beams) do
	do
		-- the beam's long axis
		local axes = {{beam.CFrame.RightVector, beam.Size.X}, {beam.CFrame.UpVector, beam.Size.Y}, {beam.CFrame.LookVector, beam.Size.Z}}
		table.sort(axes, function(a, b) return a[2] > b[2] end)
		local dir, len = axes[1][1], axes[1][2]
		dir = Vector3.new(dir.X, 0, dir.Z).Unit
		local a = beam.Position - dir * len / 2
		local t = 0
		while t < len - 0.5 do
			local seg = math.min(rng:NextNumber(2.8, 4.2), len - t)
			local c = a + dir * (t + seg / 2)
			local g = ground(c.X, c.Z, c.Y)
			if g then
				local h = rng:NextNumber(2.2, 2.9)
				local s = Instance.new("Part")
				s.Name = "WallStone"
				-- long side (Z) along the wall line
				s.Size = Vector3.new(rng:NextNumber(1.7, 2.2), h, seg)
				local at = Vector3.new(c.X, g + h / 2 - 0.4, c.Z)
				s.CFrame = CFrame.lookAt(at, at + dir) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-3, 3)))
				s.Material = Enum.Material.Cobblestone
				s.Color = STONES[rng:NextInteger(1, #STONES)]
				s.Anchored = true
				s.TopSurface, s.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
				s.Parent = wallsModel
				-- a capstone on every other stone
				if rng:NextNumber() < 0.5 then
					local cap = s:Clone()
					cap.Name = "WallCap"
					cap.Size = Vector3.new(s.Size.X + 0.3, 0.6, seg * 0.8)
					cap.CFrame = s.CFrame * CFrame.new(0, h / 2 + 0.25, 0)
					cap.Color = Color3.fromRGB(96, 112, 74) -- mossy top
					cap.Material = Enum.Material.Grass
					cap.Parent = wallsModel
				end
				log.walls += 1
			end
			t += seg + 0.15
		end
		if beam.Parent ~= BK then backup(beam, "replaced by YardWalls (dry-stone, follows the slope)") end
	end
end
wallsModel.Parent = L.Workshop

-- 4. fence posts down to the ground
for _, p in ipairs(L.Fences:GetChildren()) do
	if p:IsA("BasePart") and p.Name == "FencePost" then
		local g = ground(p.Position.X, p.Position.Z, p.Position.Y)
		local bot = p.Position.Y - p.Size.Y / 2
		if g and bot > g - 0.3 then
			local topY = p.Position.Y + p.Size.Y / 2
			p.Size = Vector3.new(p.Size.X, topY - (g - 0.5), p.Size.Z)
			p.Position = Vector3.new(p.Position.X, (topY + g - 0.5) / 2, p.Position.Z)
			log.posts += 1
		end
	end
end

return string.format("settled: %d models moved, %d trunks extended, %d terraces nudged, %d removed to backup, %d wall stones, %d fence posts lengthened",
	log.moved, log.trunks, log.nudged, log.removed, log.walls, log.posts)

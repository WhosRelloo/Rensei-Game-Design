-- Halvard's Adit dressing (2026-10-20): the owner's teal mine reference (stacked angular stone blocks, chains, lanterns).
-- Run in Ye (Edit) with Art/Tools/rbxc.py. It reads the cave from TERRAIN voxels, so it ran once before ground.lua
-- replaced the terrain with parts (2026-10-20); do NOT re-run it now (it would find no cave and clear the dressing).
--   * every cave wall / ceiling face (terrain voxels around the route) gets an angular slate block, so the carved
--     terrain reads as stacked stone; blocks stay out of puzzle pieces, doors and lights (3.5 studs) and barely
--     protrude where the cave is tight
--   * stepped stone ledges along both sides of the entrance tunnel (the reference's corridor layout), rails left clear
--   * chains: two crossing chains under the ceiling of the lift hall, the sump and the lab; a chain above every
--     hanging lantern
--   * teal fill light inside Attachments, so LightService (stealth) does not count it as a lamp
--   * the cave's surface terrain voxels become Basalt (unused anywhere else in Ye) coloured teal-grey, so the stone
--     between blocks matches; a TerrainRegion copy of the cave is kept in RenseiBackups["Pre-AditDress_2026-10-20"]
--   * floors re-coloured teal-grey (old colour kept as attribute PreDressColor); Lighting.Ambient teal (old value on
--     the Dressing folder)
-- Every number is a PROPOSAL.
local O = Vector3.new(0, 4, -650)
local A = workspace.World.Map.HalvardsAdit
local T = workspace.Terrain
local Lighting = game:GetService("Lighting")
local rng = Random.new(2026)

local old = A:FindFirstChild("Dressing")
local oldAmbient = old and old:GetAttribute("PreDressAmbient")
if old then old:Destroy() end
local D = Instance.new("Folder")
D.Name = "Dressing"
D:SetAttribute("PreDressAmbient", oldAmbient or Lighting.Ambient)
D.Parent = A
local Groups = {}
local function group(name)
	if not Groups[name] then
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = D
		Groups[name] = f
	end
	return Groups[name]
end
local pending, made = {}, 0
local function flush()
	for _, p in ipairs(pending) do p[1].Parent = p[2] end
	pending = {}
	task.wait()
end
local function part(g, name, size, cf, mat, color, collide)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Material = mat
	p.Color = color
	p.Anchored = true
	p.CanCollide = collide ~= false
	p.CanQuery = collide ~= false
	p.CastShadow = size.X * size.Y * size.Z > 4
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	table.insert(pending, {p, group(g)})
	made += 1
	if #pending >= 250 then flush() end
	return p
end

-- keep-clear boxes: puzzle pieces, doors, lights
local Keep = {}
for _, f in ipairs({A.Interactables, A.Doors, A.Lights}) do
	for _, p in ipairs(f:GetDescendants()) do
		if p:IsA("BasePart") then table.insert(Keep, {p.CFrame, p.Size / 2}) end
	end
end
local function nearKeep(pos, margin)
	for _, k in ipairs(Keep) do
		local l = k[1]:PointToObjectSpace(pos)
		local dx = math.max(math.abs(l.X) - k[2].X, 0)
		local dy = math.max(math.abs(l.Y) - k[2].Y, 0)
		local dz = math.max(math.abs(l.Z) - k[2].Z, 0)
		if dx * dx + dy * dy + dz * dz < margin * margin then return true end
	end
	return false
end

-- palette (slate blocks read teal under the fill light; a few warmer stones near lanterns)
local STONE = {Color3.fromRGB(62, 74, 80), Color3.fromRGB(70, 82, 88), Color3.fromRGB(56, 67, 73), Color3.fromRGB(78, 88, 92)}
local function stoneColor() return STONE[rng:NextInteger(1, #STONE)] end

-- 1. voxel shell
local lo = O + Vector3.new(280, -8, -84)
local hi = O + Vector3.new(524, 36, 64)
local reg = Region3.new(lo, hi):ExpandToGrid(4)
local mats, occs = T:ReadVoxels(reg, 4)
local sx, sy, sz = mats.Size.X, mats.Size.Y, mats.Size.Z
local base = reg.CFrame.Position - reg.Size / 2
local function solid(i, j, k)
	if i < 1 or j < 1 or k < 1 or i > sx or j > sy or k > sz then return true end
	local m = mats[i][j][k]
	return m ~= Enum.Material.Air and m ~= Enum.Material.Water and occs[i][j][k] > 0.5
end
local Ray = RaycastParams.new()
Ray.FilterType = Enum.RaycastFilterType.Exclude
Ray.FilterDescendantsInstances = {D, A:FindFirstChild("Halvard's AditArea")}
Ray.IgnoreWater = true
local function clearance(from, dir, len)
	local h = workspace:Raycast(from, dir * len, Ray)
	return h and (h.Position - from).Magnitude or len
end
local DIRS = {Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1), Vector3.new(0, 1, 0)}
local shell = 0
for i = 1, sx do
	for k = 1, sz do
		for j = 1, sy do
			if not solid(i, j, k) then
				local roof = false
				for jj = j + 1, math.min(sy, j + 10) do if solid(i, jj, k) then roof = true break end end
				if roof then
					local c = base + Vector3.new((i - 0.5) * 4, (j - 0.5) * 4, (k - 0.5) * 4)
					for _, v in ipairs(DIRS) do
						if solid(i + v.X, j + v.Y, k + v.Z) then
							local n = -v -- face normal, into the cave
							local face = c + v * 2
							if not nearKeep(face, 3.5) then
								-- how much room in front of this face: protrude less where it is tight
								local room = clearance(face + n * 0.2, n, 16)
								local protrude = math.clamp((room - 7) * 0.25, 0.2, 1.7)
								local big = v.Y > 0 and rng:NextNumber() < 0.25
								local w = big and rng:NextNumber(8, 11) or rng:NextNumber(4.6, 7.2)
								local h = big and rng:NextNumber(6, 9) or rng:NextNumber(4.6, 7.2)
								local depth = rng:NextNumber(3, 5)
								local jitter = Vector3.new(rng:NextNumber(-0.8, 0.8), rng:NextNumber(-0.8, 0.8), rng:NextNumber(-0.8, 0.8)) * (Vector3.one - Vector3.new(math.abs(n.X), math.abs(n.Y), math.abs(n.Z)))
								local centre = face + jitter + n * (protrude - depth / 2)
								local up = math.abs(n.Y) > 0.5 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
								local cf = CFrame.lookAt(centre, centre + n, up)
									* CFrame.Angles(math.rad(rng:NextNumber(-9, 9)), math.rad(rng:NextNumber(-9, 9)), math.rad(rng:NextInteger(0, 3) * 90 + rng:NextNumber(-6, 6)))
								if big then cf = cf * CFrame.Angles(math.rad(rng:NextNumber(12, 22)) * (rng:NextNumber() < 0.5 and -1 or 1), 0, 0) end
								part("Shell", v.Y > 0 and "CeilingBlock" or "WallBlock", Vector3.new(w, h, depth), cf, Enum.Material.Slate, stoneColor())
								shell += 1
							end
						end
					end
				end
			end
		end
	end
end
flush()

-- 1b. cave surface terrain -> Basalt (teal-grey); backup first (once)
local Backups = game:GetService("ServerStorage"):FindFirstChild("RenseiBackups")
local BK = Backups:FindFirstChild("Pre-AditDress_2026-10-20")
if not BK then
	BK = Instance.new("Folder")
	BK.Name = "Pre-AditDress_2026-10-20"
	local copy = T:CopyRegion(Region3int16.new(Vector3int16.new(math.floor(reg.CFrame.Position.X / 4 - reg.Size.X / 8), math.floor(reg.CFrame.Position.Y / 4 - reg.Size.Y / 8), math.floor(reg.CFrame.Position.Z / 4 - reg.Size.Z / 8)),
		Vector3int16.new(math.floor(reg.CFrame.Position.X / 4 + reg.Size.X / 8) - 1, math.floor(reg.CFrame.Position.Y / 4 + reg.Size.Y / 8) - 1, math.floor(reg.CFrame.Position.Z / 4 + reg.Size.Z / 8) - 1)))
	copy.Name = "AditTerrain"
	copy.Parent = BK
	BK:SetAttribute("CornerVoxel", Vector3.new(math.floor(reg.CFrame.Position.X / 4 - reg.Size.X / 8), math.floor(reg.CFrame.Position.Y / 4 - reg.Size.Y / 8), math.floor(reg.CFrame.Position.Z / 4 - reg.Size.Z / 8)))
	BK:SetAttribute("BasaltColor", T:GetMaterialColor(Enum.Material.Basalt))
	BK.Parent = Backups
end
local recolored = 0
for i = 1, sx do
	for k = 1, sz do
		for j = 1, sy do
			if not solid(i, j, k) then
				local roof = false
				for jj = j + 1, math.min(sy, j + 10) do if solid(i, jj, k) then roof = true break end end
				if roof then
					for _, v in ipairs({Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1), Vector3.new(0, 1, 0), Vector3.new(0, -1, 0)}) do
						local a, b, c = i + v.X, j + v.Y, k + v.Z
						if a >= 1 and b >= 1 and c >= 1 and a <= sx and b <= sy and c <= sz and solid(a, b, c) and mats[a][b][c] ~= Enum.Material.Basalt then
							mats[a][b][c] = Enum.Material.Basalt
							recolored += 1
						end
					end
					-- partly filled air voxels (the smooth surface itself) too
					if occs[i][j][k] > 0 and mats[i][j][k] ~= Enum.Material.Air and mats[i][j][k] ~= Enum.Material.Water then
						mats[i][j][k] = Enum.Material.Basalt
					end
				end
			end
		end
	end
end
T:WriteVoxels(reg, 4, mats, occs)
T:SetMaterialColor(Enum.Material.Basalt, Color3.fromRGB(58, 70, 76))
task.wait()

-- 2. stepped ledges along the entrance tunnel walls (floor top local Y 5, centre Z -10, width 12; rails at Z -9 / -11)
local steps = 0
local x = 302
while x < 368 do
	for _, side in ipairs({-1, 1}) do
		local len = rng:NextNumber(4, 7)
		local tiers = rng:NextInteger(1, 3)
		for t = 1, tiers do
			local depth = 3.2 - (t - 1) * 0.9
			local hgt = rng:NextNumber(1.2, 2.4)
			local z = -10 + side * (6 - depth / 2 + 0.6)
			local y = 5 + (t - 1) * 1.8 + hgt / 2 - 0.3
			local pos = O + Vector3.new(x + rng:NextNumber(-0.6, 0.6), y, z)
			if not nearKeep(pos, 2) then
				part("Ledges", "Ledge", Vector3.new(len - (t - 1) * 1.2, hgt, depth), CFrame.new(pos) * CFrame.Angles(0, math.rad(rng:NextNumber(-4, 4)), math.rad(rng:NextNumber(-3, 3))), Enum.Material.Slate, stoneColor())
				steps += 1
			end
		end
	end
	x += rng:NextNumber(5, 8)
end
-- loose rubble on the floor edges (no collision)
for _, f in ipairs(A.Structure:GetChildren()) do
	if f:IsA("BasePart") and f.Name:sub(1, 5) == "Floor" and f.Name ~= "Floor_SumpPit" then
		local n = math.floor(f.Size.X * f.Size.Z / 60)
		for r = 1, n do
			local edge = rng:NextNumber() < 0.5
			local lx = (edge and (rng:NextNumber() < 0.5 and -1 or 1) * rng:NextNumber(0.35, 0.48) or rng:NextNumber(-0.45, 0.45)) * f.Size.X
			local lz = (edge and rng:NextNumber(-0.45, 0.45) or (rng:NextNumber() < 0.5 and -1 or 1) * rng:NextNumber(0.35, 0.48)) * f.Size.Z
			local s = rng:NextNumber(0.5, 1.6)
			local pos = f.CFrame * Vector3.new(lx, f.Size.Y / 2 + s * 0.35, lz)
			if not nearKeep(pos, 2.5) then
				part("Rubble", "Rubble", Vector3.new(s, s * rng:NextNumber(0.5, 0.9), s * rng:NextNumber(0.7, 1.2)), CFrame.new(pos) * CFrame.Angles(math.rad(rng:NextNumber(-20, 20)), rng:NextNumber(0, math.pi), math.rad(rng:NextNumber(-20, 20))), Enum.Material.Slate, stoneColor(), false)
			end
		end
	end
end
flush()

-- 3. chains
local CHAIN = Color3.fromRGB(58, 60, 62)
local function link(cf, L, W, th)
	-- one oval-ish link from four bars, centred on cf, long axis = cf.LookVector
	part("Chains", "Link", Vector3.new(th, th, L), cf * CFrame.new(W / 2 - th / 2, 0, 0), Enum.Material.Metal, CHAIN, false)
	part("Chains", "Link", Vector3.new(th, th, L), cf * CFrame.new(-W / 2 + th / 2, 0, 0), Enum.Material.Metal, CHAIN, false)
	part("Chains", "Link", Vector3.new(W, th, th), cf * CFrame.new(0, 0, L / 2 - th / 2), Enum.Material.Metal, CHAIN, false)
	part("Chains", "Link", Vector3.new(W, th, th), cf * CFrame.new(0, 0, -L / 2 + th / 2), Enum.Material.Metal, CHAIN, false)
end
local function chain(a, b, sag, L, W, th)
	local pitch = L - th * 2.2
	local function at(t) return a:Lerp(b, t) - Vector3.new(0, 4 * sag * t * (1 - t), 0) end
	local length = 0
	local prev = a
	for s = 1, 40 do local p = at(s / 40) length += (p - prev).Magnitude prev = p end
	local n = math.max(2, math.floor(length / pitch))
	for s = 0, n - 1 do
		local t0, t1 = s / n, (s + 1) / n
		local p0, p1 = at(t0), at(t1)
		local mid = (p0 + p1) / 2
		local cf = CFrame.lookAt(mid, p1)
		if s % 2 == 1 then cf = cf * CFrame.Angles(0, 0, math.rad(90)) end
		link(cf, L, W, th)
	end
	return n
end
local function ceilingAbove(p)
	local h = workspace:Raycast(p, Vector3.new(0, 40, 0), Ray)
	return h and h.Position
end
local links = 0
-- crossing chains: (room floor centre X, Z, floor top Y, half-size X, Z) in local coords
local ROOMS = {
	{358, -10, 5, 9, 16},   -- lift hall
	{413, -10, -1, 13, 20}, -- sump
	{469, -10, -1, 17, 30}, -- lab
}
for _, r in ipairs(ROOMS) do
	local corners = {{-1, -1}, {1, 1}, {-1, 1}, {1, -1}}
	for c = 1, 3, 2 do
		local p1 = O + Vector3.new(r[1] + corners[c][1] * r[4], r[3] + 3, r[2] + corners[c][2] * r[5])
		local p2 = O + Vector3.new(r[1] + corners[c + 1][1] * r[4], r[3] + 3, r[2] + corners[c + 1][2] * r[5])
		local c1, c2 = ceilingAbove(p1), ceilingAbove(p2)
		if c1 and c2 then
			local a, b = c1 - Vector3.new(0, 1.2, 0), c2 - Vector3.new(0, 1.2, 0)
			local floorY = O.Y + r[3]
			local sag = math.min(3.5, math.min(a.Y, b.Y) - floorY - 9)
			if sag > 0.5 then links += chain(a, b, sag, 2.8, 1.5, 0.32) end
		end
	end
end
-- a chain above every hanging lantern cap
for _, cap in ipairs(A.Lights:GetChildren()) do
	if cap.Name == "LanternCap" then
		local top = ceilingAbove(cap.Position + Vector3.new(0, 0.3, 0))
		if top and (top - cap.Position).Magnitude > 2 then
			links += chain(cap.Position + Vector3.new(0, 0.1, 0), top, 0, 1.4, 0.7, 0.16)
		end
	end
end
flush()

-- 4. teal fill light (inside Attachments: LightService only counts lights parented to a part)
local Fill = Instance.new("Part")
Fill.Name = "FillAnchor"
Fill.Size = Vector3.new(1, 1, 1)
Fill.Transparency = 1
Fill.Anchored, Fill.CanCollide, Fill.CanQuery, Fill.CanTouch = true, false, false, false
Fill.CFrame = CFrame.new(O + Vector3.new(400, 8, -10))
Fill.Parent = group("Light")
local FILL = {{306, 11, -10}, {330, 11, -10}, {354, 11, -10}, {358, 11, -26}, {358, 11, 6}, {384, 8, -10}, {406, 7, -30}, {406, 7, 10},
	{420, 7, -10}, {440, 6, -10}, {460, 7, -38}, {460, 7, 18}, {478, 7, -10}, {478, 7, 20}, {500, 4, -10}, {465, 4, -59}}
for _, p in ipairs(FILL) do
	local at = Instance.new("Attachment")
	at.Parent = Fill -- parent first: WorldPosition is relative to the parent part
	at.WorldPosition = O + Vector3.new(p[1], p[2], p[3])
	local L = Instance.new("PointLight")
	L.Color = Color3.fromRGB(80, 138, 160)
	L.Brightness = 1.2
	L.Range = 26
	L.Shadows = false -- with shadows the shell blocks hide these lights
	L.Parent = at
end
-- warm the existing lanterns a little (they already exist and are LightService lamps; brightness kept)
for _, l in ipairs(A.Lights:GetDescendants()) do
	if l:IsA("PointLight") then l.Color = Color3.fromRGB(255, 170, 90) l.Shadows = true end
end

-- 5. floors and ambient
for _, f in ipairs(A.Structure:GetChildren()) do
	if f:IsA("BasePart") and f.Name:sub(1, 5) == "Floor" and f.Name ~= "Floor_SumpPit" then
		if f:GetAttribute("PreDressColor") == nil then
			f:SetAttribute("PreDressColor", f.Color)
			f:SetAttribute("PreDressMaterial", f.Material.Name)
		end
		f.Material = Enum.Material.Slate
		f.Color = Color3.fromRGB(70, 84, 90)
	end
end
Lighting.Ambient = Color3.fromRGB(46, 64, 72)

return string.format("Adit dressed: %d shell blocks, %d ledges, %d chain links, %d fill lights, %d parts in all; %d terrain voxels to Basalt", shell, steps, links, #FILL, made, recolored)

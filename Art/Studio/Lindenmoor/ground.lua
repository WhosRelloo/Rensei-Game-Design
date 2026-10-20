-- Part ground v4 (2026-10-20). Owner: "I don't want to use roblox's terrain. Make it like the references I sent you."
-- (approved), then tried tilted slopes and chose: "Go back to the style we just had ... I just wanted the walk-ways
-- to connect". So: flat mossy slabs stacked in 1-stud steps over dark stone (the reference's terraces), a
-- block-built Adit cave, and continuous walkways: a cell is path if any of 5 samples in it is path, then gaps up to
-- 2 cells along a path are closed (dilate 2, erode 2). Where a path climbs, its cells are dirt ramps on the real
-- slope (one tilted slab per 4-stud cell) so every walkway is walkable through the stepped terraces.
-- Source heights come from the original terrain: if it was already cleared, the backup in
-- RenseiBackups["Pre-PartGround_2026-10-20"] is pasted back first, sampled, then cleared again. Terrain WATER stays
-- (SwimService reads it). Re-runnable: rebuilds World.Map.Ground. Every colour is a PROPOSAL.
local T = workspace.Terrain
local rng = Random.new(77)
local X0, X1 = -392, 532
local Z0, Z1 = -1004, -288
local Y0, Y1 = -12, 76
local reg = Region3.new(Vector3.new(X0, Y0, Z0), Vector3.new(X1, Y1, Z1))
local Map = workspace.World.Map
local Backups = game:GetService("ServerStorage"):FindFirstChild("RenseiBackups")

-- 0. original terrain: make a backup the first time; otherwise paste it back to sample it
local BK = Backups:FindFirstChild("Pre-PartGround_2026-10-20")
if not BK then
	BK = Instance.new("Folder")
	BK.Name = "Pre-PartGround_2026-10-20"
	local copy = T:CopyRegion(Region3int16.new(Vector3int16.new(X0 / 4, Y0 / 4, Z0 / 4), Vector3int16.new(X1 / 4 - 1, Y1 / 4 - 1, Z1 / 4 - 1)))
	copy.Name = "Terrain"
	copy.Parent = BK
	BK:SetAttribute("CornerVoxel", Vector3.new(X0 / 4, Y0 / 4, Z0 / 4))
	BK:SetAttribute("Note", "Restore: workspace.Terrain:PasteRegion(Terrain, Vector3int16.new(CornerVoxel), true), then delete World.Map.Ground")
	BK.Parent = Backups
else
	T:PasteRegion(BK.Terrain, Vector3int16.new(X0 / 4, Y0 / 4, Z0 / 4), true)
end
local old = Map:FindFirstChild("Ground")
if old then old:Destroy() end
task.wait()

local mats, occs = T:ReadVoxels(reg, 4)
local NX, NY, NZ = mats.Size.X, mats.Size.Y, mats.Size.Z
local function solid(i, j, k)
	if i < 1 or j < 1 or k < 1 or i > NX or j > NY or k > NZ then return false end
	local m = mats[i][j][k]
	return m ~= Enum.Material.Air and m ~= Enum.Material.Water and occs[i][j][k] > 0.5
end
local function roofedAir(i, j, k)
	if solid(i, j, k) or mats[i][j][k] == Enum.Material.Water then return false end
	for jj = j + 1, math.min(NY, j + 10) do if solid(i, jj, k) then return true end end
	return false
end

-- 1. per column: top surface, material (5 samples), cave ceiling below it
local Ray = RaycastParams.new()
Ray.FilterType = Enum.RaycastFilterType.Include
Ray.FilterDescendantsInstances = {T}
Ray.IgnoreWater = true
local function sample(x, z)
	return workspace:Raycast(Vector3.new(x, Y1 + 40, z), Vector3.new(0, -(Y1 - Y0 + 80), 0), Ray)
end
local function kindOf(m)
	if m == Enum.Material.Grass or m == Enum.Material.LeafyGrass then return "grass"
	elseif m == Enum.Material.Mud or m == Enum.Material.Ground or m == Enum.Material.Sand then return "path"
	elseif m == Enum.Material.Cobblestone then return "cobble"
	else return "stone" end
end
local H = {} -- corner heights: H[i][k] at (X0 + (i-1)*4, Z0 + (k-1)*4)
for i = 1, NX + 1 do
	H[i] = {}
	for k = 1, NZ + 1 do
		local h = sample(X0 + (i - 1) * 4, Z0 + (k - 1) * 4)
		H[i][k] = h and h.Position.Y
	end
	if i % 25 == 0 then task.wait() end
end
local top, kind, cave = {}, {}, {}
for i = 1, NX do
	top[i], kind[i], cave[i] = {}, {}, {}
	for k = 1, NZ do
		local x, z = X0 + (i - 0.5) * 4, Z0 + (k - 0.5) * 4
		local h = sample(x, z)
		if h then
			top[i][k] = math.floor(h.Position.Y + 0.5)
			local kd = kindOf(h.Material)
			if kd == "grass" then
				for _, o in ipairs({{1.3, 1.3}, {-1.3, 1.3}, {1.3, -1.3}, {-1.3, -1.3}}) do
					local s2 = sample(x + o[1], z + o[2])
					if s2 and kindOf(s2.Material) == "path" then kd = "path" break end
				end
			end
			kind[i][k] = kd
			local jTop = math.clamp(math.floor((h.Position.Y - Y0) / 4) + 1, 1, NY)
			for j = jTop - 1, 1, -1 do
				if roofedAir(i, j, k) then cave[i][k] = Y0 + j * 4 break end
			end
		end
	end
	if i % 20 == 0 then task.wait() end
end
-- close gaps in walkways: dilate path by 2 cells into grass, then erode back (only cells added by the dilation)
local function isPath(i, k) return kind[i] and kind[i][k] == "path" end
local dil = {}
for i = 1, NX do
	dil[i] = {}
	for k = 1, NZ do
		local p = isPath(i, k)
		if not p and kind[i][k] == "grass" then
			for a = -2, 2 do for b = -2, 2 do if isPath(i + a, k + b) then p = true end end end
		end
		dil[i][k] = p
	end
end
for i = 1, NX do
	for k = 1, NZ do
		if dil[i][k] and kind[i][k] == "grass" then
			local keep = true
			for a = -2, 2 do for b = -2, 2 do
				local ii, kk = i + a, k + b
				if ii >= 1 and kk >= 1 and ii <= NX and kk <= NZ and kind[ii][kk] and not dil[ii][kk] then keep = false end
			end end
			if keep then kind[i][k] = "path" end
		end
	end
end

-- 2. columns closed down to the lowest neighbour (every step shows a stone face), stopping above caves
local bottom = {}
for i = 1, NX do
	bottom[i] = {}
	for k = 1, NZ do
		local t = top[i][k]
		if t then
			local lo = t - 2
			for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
				local n = top[i + d[1]] and top[i + d[1]][k + d[2]]
				lo = math.min(lo, (n or t - 12) - 1)
			end
			if cave[i][k] then lo = math.max(lo, cave[i][k]) end
			bottom[i][k] = lo
		end
	end
end

-- 2b. keep the Adit's route open (fix 2026-10-20: the boarded mouth sits under the hillside's overhang, which the
-- cave test above doesn't count as a cave, so two 17-stud columns filled the entrance). No column may fill the
-- walkable space over the Adit's floors and ramp, or the boarded mouth's opening; a column that rises above that
-- space keeps only its part over it, and one whose top is inside it becomes a 1-stud surface slab.
local function aabb(cf, size)
	local function ext(a) return math.abs(cf.RightVector[a]) * size.X + math.abs(cf.UpVector[a]) * size.Y + math.abs(cf.LookVector[a]) * size.Z end
	local half = Vector3.new(ext("X"), ext("Y"), ext("Z")) / 2
	return cf.Position - half, cf.Position + half
end
local Clear = {} -- {min, max} world boxes
local AditMap = Map:FindFirstChild("HalvardsAdit")
if AditMap then
	for _, f in ipairs(AditMap.Structure:GetChildren()) do
		if f:IsA("BasePart") and (f.Name:sub(1, 5) == "Floor" or f.Name == "Ramp") then
			local lo, hi = aabb(f.CFrame, f.Size)
			local floorTop = f.Name == "Ramp" and lo.Y or hi.Y
			table.insert(Clear, {Vector3.new(lo.X, floorTop, lo.Z), Vector3.new(hi.X, hi.Y + 9, hi.Z)})
		end
	end
	-- the mouth's opening: between the two FramePosts' inner faces, from the tunnel floor to the lintel's underside
	local mouth = AditMap:FindFirstChild("Interactables") and AditMap.Interactables:FindFirstChild("BoardedMouth")
	if mouth then
		local posts, lintel = {}, mouth:FindFirstChild("FrameLintel")
		for _, c in ipairs(mouth:GetChildren()) do if c.Name == "FramePost" then table.insert(posts, c) end end
		if #posts == 2 and lintel then
			local a1, b1 = aabb(posts[1].CFrame, posts[1].Size)
			local a2, b2 = aabb(posts[2].CFrame, posts[2].Size)
			local zlo, zhi = math.min(b1.Z, b2.Z), math.max(a1.Z, a2.Z)
			local llo = aabb(lintel.CFrame, lintel.Size)
			local x = posts[1].Position.X
			table.insert(Clear, {Vector3.new(x - 4, math.min(a1.Y, a2.Y), zlo), Vector3.new(x + 4, llo.Y, zhi)})
		end
	end
end
local cleared = 0
for i = 1, NX do
	for k = 1, NZ do
		local t = top[i][k]
		if t then
			local x, z = X0 + (i - 0.5) * 4, Z0 + (k - 0.5) * 4
			for _, B in ipairs(Clear) do
				local ox = math.min(x + 2, B[2].X) - math.max(x - 2, B[1].X)
				local oz = math.min(z + 2, B[2].Z) - math.max(z - 2, B[1].Z)
				if ox > 1 and oz > 1 and t > B[1].Y and bottom[i][k] < B[2].Y then -- the cell overlaps the route by more than 1 stud
					if t >= B[2].Y + 1 then
						bottom[i][k] = math.max(bottom[i][k], math.ceil(B[2].Y))
					else
						bottom[i][k] = t - 1
					end
					cleared += 1
				end
			end
		end
	end
end

-- 3. path cells on a slope become ramps; the rest merge into slabs of equal (top, bottom, kind)
local used = {}
for i = 1, NX do used[i] = {} end
local ramps = {}
for i = 1, NX do
	for k = 1, NZ do
		if kind[i][k] == "path" and top[i][k] then
			local a, b, c, d = H[i][k], H[i + 1][k], H[i][k + 1], H[i + 1][k + 1]
			if a and b and c and d and math.max(a, b, c, d) - math.min(a, b, c, d) > 0.6 then
				used[i][k] = true
				table.insert(ramps, {i, k, a, b, c, d})
			end
		end
	end
end
local rects = {}
for k = 1, NZ do
	for i = 1, NX do
		local t = top[i][k]
		if t and not used[i][k] and bottom[i][k] < t then
			local b, kd = bottom[i][k], kind[i][k]
			local function same(ii, kk)
				return top[ii] and top[ii][kk] == t and bottom[ii][kk] == b and not used[ii][kk] and kind[ii][kk] == kd
			end
			local w = 1
			while i + w <= NX and same(i + w, k) and w < 40 do w += 1 end
			local d, ok = 1, true
			while ok and k + d <= NZ and d < 40 do
				for ii = i, i + w - 1 do if not same(ii, k + d) then ok = false break end end
				if ok then d += 1 end
			end
			for ii = i, i + w - 1 do for kk = k, k + d - 1 do used[ii][kk] = true end end
			table.insert(rects, {i, k, w, d, t, b, kd})
		end
	end
end

-- 4. cave shell (east of the village: the Adit)
local shell = {}
for k = 1, NZ do
	for j = 1, NY do
		local run
		for i = 1, NX + 1 do
			local want = false
			if i <= NX and X0 + (i - 0.5) * 4 >= 270 and solid(i, j, k) then
				for _, v in ipairs({{1, 0, 0}, {-1, 0, 0}, {0, 0, 1}, {0, 0, -1}, {0, 1, 0}, {0, -1, 0}}) do
					local a, b, c = i + v[1], j + v[2], k + v[3]
					if a >= 1 and b >= 1 and c >= 1 and a <= NX and b <= NY and c <= NZ and roofedAir(a, b, c) then want = true break end
				end
			end
			if want then
				run = run or i
			elseif run then
				table.insert(shell, {run, j, k, i - run})
				run = nil
			end
		end
	end
end

-- 5. build
local G = Instance.new("Model")
G.Name = "Ground"
G.Parent = Map
local function folder(n)
	local f = Instance.new("Folder")
	f.Name = n
	f.Parent = G
	return f
end
local Tops, Sides, Cave = folder("Tops"), folder("Sides"), folder("Cave")
local TOP = {
	grass = {Enum.Material.Grass, {Color3.fromRGB(74, 98, 50), Color3.fromRGB(82, 106, 54), Color3.fromRGB(68, 92, 48), Color3.fromRGB(90, 112, 58)}},
	path = {Enum.Material.Ground, {Color3.fromRGB(98, 84, 64), Color3.fromRGB(90, 78, 60)}},
	cobble = {Enum.Material.Cobblestone, {Color3.fromRGB(122, 118, 108)}},
	stone = {Enum.Material.Slate, {Color3.fromRGB(86, 90, 88), Color3.fromRGB(78, 82, 80), Color3.fromRGB(92, 94, 90)}},
}
local SIDE = {Color3.fromRGB(66, 60, 52), Color3.fromRGB(60, 56, 50), Color3.fromRGB(72, 66, 56)}
local made, batch = 0, {}
local function put(p, parent)
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	table.insert(batch, {p, parent})
	made += 1
	if #batch >= 400 then
		for _, x in ipairs(batch) do x[1].Parent = x[2] end
		batch = {}
		task.wait()
	end
end
local function block(name, size, cf, material, color, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Material = material
	p.Color = color
	put(p, parent)
	return p
end
-- flat slabs
for _, r in ipairs(rects) do
	local i, k, w, d, t, b, kd = r[1], r[2], r[3], r[4], r[5], r[6], r[7]
	local cx, cz = X0 + (i - 1 + w / 2) * 4, Z0 + (k - 1 + d / 2) * 4
	local spec = TOP[kd]
	block("Top", Vector3.new(w * 4, 1, d * 4), CFrame.new(cx, t - 0.5, cz), spec[1], spec[2][rng:NextInteger(1, #spec[2])], Tops)
	if t - 1 > b then
		block("Side", Vector3.new(w * 4, t - 1 - b, d * 4), CFrame.new(cx, (t - 1 + b) / 2, cz), Enum.Material.Slate, SIDE[rng:NextInteger(1, #SIDE)], Sides)
	end
end
-- dirt ramps (tilted per cell) with stone under them
for _, r in ipairs(ramps) do
	local i, k, a, b, c, d = r[1], r[2], r[3], r[4], r[5], r[6]
	local cx, cz = X0 + (i - 0.5) * 4, Z0 + (k - 0.5) * 4
	local gx = ((b + d) - (a + c)) / 8
	local gz = ((c + d) - (a + b)) / 8
	local mid = (a + b + c + d) / 4
	local right = Vector3.new(1, gx, 0).Unit
	local up = Vector3.new(0, gz, 1):Cross(Vector3.new(1, gx, 0)).Unit
	if up.Y < 0 then up = -up end
	local back = right:Cross(up).Unit
	local thick = 1.2
	local spec = TOP.path
	block("Ramp", Vector3.new(4 * math.sqrt(1 + gx * gx) + 0.25, thick, 4 * math.sqrt(1 + gz * gz) + 0.25),
		CFrame.fromMatrix(Vector3.new(cx, mid, cz) - up * (thick / 2), right, up, back), spec[1], spec[2][rng:NextInteger(1, #spec[2])], Tops)
	local hi = math.min(a, b, c, d) - 0.6
	local lo = bottom[i][k]
	if hi - lo > 0.3 then
		block("Side", Vector3.new(4, hi - lo, 4), CFrame.new(cx, (hi + lo) / 2, cz), Enum.Material.Slate, SIDE[rng:NextInteger(1, #SIDE)], Sides)
	end
end
for _, r in ipairs(shell) do
	local i, j, k, w = r[1], r[2], r[3], r[4]
	block("CaveStone", Vector3.new(w * 4, 4, 4), CFrame.new(X0 + (i - 1 + w / 2) * 4, Y0 + (j - 0.5) * 4, Z0 + (k - 0.5) * 4), Enum.Material.Slate, Color3.fromRGB(58, 70, 76), Cave)
end
for _, x in ipairs(batch) do x[1].Parent = x[2] end
task.wait()

-- 6. clear solid terrain; water stays
for i = 1, NX do
	for j = 1, NY do
		for k = 1, NZ do
			if mats[i][j][k] ~= Enum.Material.Water then
				mats[i][j][k] = Enum.Material.Air
				occs[i][j][k] = 0
			end
		end
	end
end
T:WriteVoxels(reg, 4, mats, occs)
local paths = 0
for _, r in ipairs(rects) do if r[7] == "path" then paths += 1 end end
return string.format("ground v4: %d parts (%d slabs, %d of them path, %d path ramps, %d cave runs, %d columns kept off the Adit route); solid terrain cleared, water kept", made, #rects, paths, #ramps, #shell, cleared)

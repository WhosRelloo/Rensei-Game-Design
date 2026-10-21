-- Foundry Yard placeholder (World Plan 1 Task 4, 2026-10-20): run in the Foundry Yard place (109591196441030), Edit.
-- The same World skeleton as Ye (Live, Visuals, Map, EnemySpawns, NPCs), a 400x400 part ground, a cobbled platform
-- with rails, two RenseiArrival points (Platform, SouthGate) with a gate arch, a spawn and the "Foundry Yard" area.
-- The template Baseplate and SpawnLocation go to ServerStorage.RenseiBackups["Pre-WorldPlan1_2026-10-20"].
-- Re-runnable: rebuilds World.Map.Foundry. The real region is a later plan; every size is a PROPOSAL.
local CS = game:GetService("CollectionService")
local SS = game:GetService("ServerStorage")
local Backups = SS:FindFirstChild("RenseiBackups") or Instance.new("Folder")
Backups.Name = "RenseiBackups"
Backups.Parent = SS
local B = Backups:FindFirstChild("Pre-WorldPlan1_2026-10-20") or Instance.new("Folder")
B.Name = "Pre-WorldPlan1_2026-10-20"
B.Parent = Backups
for _, n in ipairs({"Baseplate", "SpawnLocation"}) do
	local o = workspace:FindFirstChild(n)
	if o then o.Parent = B end
end
local World = workspace:FindFirstChild("World") or Instance.new("Folder")
World.Name = "World"
World.Parent = workspace
for _, n in ipairs({"Live", "Visuals", "Map", "EnemySpawns", "NPCs"}) do
	if not World:FindFirstChild(n) then
		local f = Instance.new("Folder")
		f.Name = n
		f.Parent = World
	end
end
local old = World.Map:FindFirstChild("Foundry")
if old then old:Destroy() end
local F = Instance.new("Model")
F.Name = "Foundry"
local function part(name, size, cf, mat, color)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Material, p.Color = name, size, cf, mat, color
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = F
	return p
end
part("Ground", Vector3.new(400, 4, 400), CFrame.new(0, 2, 0), Enum.Material.Grass, Color3.fromRGB(82, 106, 54))
part("Platform", Vector3.new(12, 2.4, 340), CFrame.new(0, 5.2, 0), Enum.Material.Cobblestone, Color3.fromRGB(122, 118, 108))
for _, x in ipairs({-12.6, -7.4}) do
	part("Rail", Vector3.new(0.5, 0.6, 400), CFrame.new(x, 4.3, 0), Enum.Material.Metal, Color3.fromRGB(58, 56, 53))
end
local function arrival(point, pos)
	local a = part("Arrival_" .. point, Vector3.new(4, 1, 4), CFrame.new(pos), Enum.Material.SmoothPlastic, Color3.new(1, 1, 1))
	a.Transparency, a.CanCollide, a.CanQuery, a.CanTouch = 1, false, false, false
	a:SetAttribute("Point", point)
	CS:AddTag(a, "RenseiArrival")
end
arrival("Platform", Vector3.new(0, 7, 0))
arrival("SouthGate", Vector3.new(150, 5, 190))
for _, x in ipairs({144, 156}) do
	part("GatePillar", Vector3.new(3, 12, 3), CFrame.new(x, 10, 190), Enum.Material.Cobblestone, Color3.fromRGB(141, 133, 119))
end
part("GateLintel", Vector3.new(15, 2.5, 3.5), CFrame.new(150, 17, 190), Enum.Material.Cobblestone, Color3.fromRGB(141, 133, 119))
local sp = Instance.new("SpawnLocation")
sp.Name, sp.Size, sp.CFrame, sp.Anchored, sp.Neutral, sp.Duration = "Spawn", Vector3.new(8, 1, 8), CFrame.new(0, 6.9, 20), true, true, 0
sp.Transparency, sp.CanCollide = 1, false
sp.Parent = F
local area = part("Foundry YardArea", Vector3.new(400, 120, 400), CFrame.new(0, 60, 0), Enum.Material.SmoothPlastic, Color3.new(1, 1, 1))
area.Transparency, area.CanCollide, area.CanQuery, area.CanTouch = 1, false, false, false
area:SetAttribute("AreaName", "Foundry Yard")
CS:AddTag(area, "RenseiArea")
F.Parent = World.Map
return "foundry placeholder built; template baseplate + spawn backed up"

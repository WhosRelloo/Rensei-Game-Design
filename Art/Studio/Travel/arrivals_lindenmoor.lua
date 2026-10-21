-- Lindenmoor arrival points (World Plan 1 Task 5, 2026-10-21): run in Ye (106992859583940), Edit.
-- Two RenseiArrival parts under World.Map.Lindenmoor (TravelService.ArrivalPoint / Spawn read them):
--   Platform  = on the station platform, local (-259, 7.5, 0) = world (-259, 11.5, -650)
--   NorthGate = on the north road,       local (0, 6, 330)    = world (0, 10, -320)
-- Same arrival() helper as station_foundry.lua: an invisible, non-colliding 4x1x4 part with a Point attribute.
-- Re-runnable: replaces the two parts. The positions are the plan's; the part size is a PROPOSAL.
local CS = game:GetService("CollectionService")
local O = Vector3.new(0, 4, -650) -- the village's local frame (Art/Blender/lindenmoor/world.py)
local L = workspace.World.Map.Lindenmoor
local function arrival(point, pos)
	local old = L:FindFirstChild("Arrival_" .. point)
	if old then old:Destroy() end
	local a = Instance.new("Part")
	a.Name, a.Size, a.CFrame, a.Material, a.Color = "Arrival_" .. point, Vector3.new(4, 1, 4), CFrame.new(pos), Enum.Material.SmoothPlastic, Color3.new(1, 1, 1)
	a.Anchored = true
	a.TopSurface, a.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	a.Transparency, a.CanCollide, a.CanQuery, a.CanTouch = 1, false, false, false
	a:SetAttribute("Point", point)
	CS:AddTag(a, "RenseiArrival")
	a.Parent = L
	return a
end
local p = arrival("Platform", O + Vector3.new(-259, 7.5, 0))
local n = arrival("NorthGate", O + Vector3.new(0, 6, 330))
return ("arrivals: Platform %s, NorthGate %s"):format(tostring(p.Position), tostring(n.Position))

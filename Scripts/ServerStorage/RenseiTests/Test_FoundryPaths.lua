-- Test_FoundryPaths (Foundry Yard plan Task 4b, 2026-10-25): every one of the 70 schedule changes of Foundry's roster
-- (Townsfolk.Regions.Foundry), planned by TownsfolkService.Mover.PlanPath (the real Compute, corner repair and Smooth,
-- with no rig) from where the rig stands at one post to the next, must give a path that passes Valid, whose repair
-- vertices all have a clearance of 1.25 or more, whose corridor is at least 3.2 studs wide everywhere, and that the
-- Mover's sight ray never hits along its smoothed waypoints; and a rig can stand at every post used and every shelter.
-- The measures are RenseiTests.PathKit's (shared with Test_YePaths). Run in Foundry, in the Play VM (LMRunSuite).
return require(script.Parent.PathKit).Suite("Foundry", 70, function()
	local World = workspace:FindFirstChild("World")
	local Map = World and World:FindFirstChild("Map")
	return Map and Map:FindFirstChild("Foundry")
end)

-- Test_YePaths (Foundry Yard plan Task 4b, 2026-10-25): Test_FoundryPaths' checks for Ye's roster
-- (Townsfolk.Regions.Lindenmoor, 17 schedule changes) and Lindenmoor's shelters (Map.LindenmoorExpansion), through
-- RenseiTests.PathKit. Run in Ye, in the Play VM (LMRunSuite).
return require(script.Parent.PathKit).Suite("Lindenmoor", 17, function()
	local World = workspace:FindFirstChild("World")
	local Map = World and World:FindFirstChild("Map")
	return Map and Map:FindFirstChild("LindenmoorExpansion")
end)

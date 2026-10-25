-- Townsfolk rosters per region (region builds spec §5). Format: see TownsfolkLogic / the Region Foundation plan, Task 4.
-- Townsfolk.Regions[RegionId] = { {Id, Name, Job, JobLine, Faction, Look, Idle?, Schedule, Greetings?, Clue?}, ... }
-- Foundry Yard's roster arrives with the Foundry plan.
--
-- Lindenmoor (Lindenmoor import Task 8, 2026-10-24): the people of the expansion, on its 18 RenseiPosts
-- (Art/Regions/Lindenmoor/layout.json). Every name, job, line, hour, idle and look seed is a PROPOSAL.
--   * Lindenmoor is in Amestris: everyone is dressed from the Amestrian pool (Look.Nation; owner 2026-10-23).
--   * A post is one townsperson's at a time (TownsfolkLogic.Validate), and there are 4 Home and 2 Shelter posts for
--     11 Work / Counter posts, so the day is shared out: two farmers keep the market stalls in the morning and work
--     their fields after; the mine hand runs the winder, then the carts, and sits up at the lookout at night; the
--     Shelter posts go to the miller (beside the mill) and the groundskeeper (the field's stand, fix round 4); the
--     signalman keeps his box round the clock. Every post but the Shelter posts is used.
--   * Shelters (fix round 4, Ruling 39): seven more Shelter posts (Art/Studio/Regions/Lindenmoor/shelters.lua) at the
--     farmsteads, the mine head, the lookout, the signal box and the training field put a shelter within
--     TownsfolkService.ShelterRadius (150) of every post here; the east hay barn's is now nobody's at night.
--   * Clue (Rensei.Investigation's expansion clues): the groundskeeper answers lm_ridge, the mine hand lm_mine; the
--     line signals the quest's Signal objective (Rensei.Quests).
-- Hours (world clock):        0    6 7     12      18 19 20   24
--   lm_farm1  stall_1 / field / home      home | stall 7-12 | field 12-19 | home
--   lm_farm2  stall_2 / field / home      home | stall 7-12 | field 12-19 | home
--   lm_farm3  field / home                home | field 6-18 | home
--   lm_farm4  field / home                home | field 6-18 | home
--   lm_miller mill / mill shelter         shelter | mill 6-20 | shelter
--   lm_minehand winder / carts / lookout  lookout | winder 6-12 | carts 12-18 | lookout
--   lm_groundskeeper drill / field shelter  shelter | training field 6-19 | shelter
--   lm_signalman signal box               signal box all day
local Lindenmoor = {
	{Id = "lm_farm1", Name = "Garrick Ashby", Job = "Farmer", Faction = "Townsfolk", Idle = "NPC_HandInPocket",
		JobLine = "Market first, while the eggs are fresh. The wheat'll still be there after noon.",
		Look = {Nation = "Amestrian", Gender = "Male", Seed = 2401},
		Schedule = {{7, 12, "lm_market_stall_1"}, {12, 19, "lm_farm1_field"}, {19, 7, "lm_farm1_home"}}},
	{Id = "lm_farm2", Name = "Marta Quill", Job = "Farmer", Faction = "Townsfolk", Idle = "NPC_Kneel",
		JobLine = "Cabbages, onions, a jar of honey if you're lucky. Fair prices, and I don't haggle.",
		Look = {Nation = "Amestrian", Gender = "Female", Seed = 2402},
		Schedule = {{7, 12, "lm_market_stall_2"}, {12, 19, "lm_farm2_field"}, {19, 7, "lm_farm2_home"}}},
	{Id = "lm_farm3", Name = "Osric Penhale", Job = "Farmer", Faction = "Townsfolk", Idle = "NPC_Kneel",
		JobLine = "Three dry weeks and then it rains the day we cut. Every year.",
		Look = {Nation = "Amestrian", Gender = "Male", Seed = 2403},
		Schedule = {{6, 18, "lm_farm3_field"}, {18, 6, "lm_farm3_home"}}},
	{Id = "lm_farm4", Name = "Ilse Dunmore", Job = "Farmer", Faction = "Townsfolk", Idle = "NPC_HandInPocket",
		JobLine = "Hay's in the barn by the meadows. Mind you shut the gate behind you.",
		Look = {Nation = "Amestrian", Gender = "Female", Seed = 2404},
		Schedule = {{6, 18, "lm_farm4_field"}, {18, 6, "lm_farm4_home"}}},
	{Id = "lm_miller", Name = "Jory Fallow", Job = "Miller", Faction = "Townsfolk", Idle = "NPC_CrossArms",
		JobLine = "While the creek runs, the wheel turns. When it freezes, we all go hungry together.",
		Look = {Nation = "Amestrian", Gender = "Male", Seed = 2405},
		Schedule = {{6, 20, "lm_mill"}, {20, 6, "lm_mill_shelter"}}},
	{Id = "lm_minehand", Name = "Bess Kettering", Job = "Mine Hand", Faction = "Townsfolk", Idle = "NPC_Blacksmith",
		JobLine = "Winder in the morning, carts after. Come dark I sit up at the lookout and watch the gorge.",
		Look = {Nation = "Amestrian", Gender = "Female", Seed = 2406},
		Clue = {Quest = "lm_mine", Stage = 1, Signal = "lm_mine_told",
			Text = "That shaft? The year we sank it, it flooded. The pumps couldn't keep up, so the company boarded it and set us to sorting spoil. There's good ore down there still, under forty feet of water."},
		Schedule = {{6, 12, "lm_mine_winder"}, {12, 18, "lm_mine_carts"}, {18, 6, "lm_lookout_seat"}}},
	{Id = "lm_groundskeeper", Name = "Ned Harrow", Job = "Groundskeeper", Faction = "Townsfolk", Idle = "NPC_HandInPocket",
		JobLine = "Dummies don't stand themselves back up, you know.",
		Look = {Nation = "Amestrian", Gender = "Male", Seed = 2407},
		Clue = {Quest = "lm_ridge", Stage = 1, Signal = "lm_ridge_told",
			Text = "The marker? I look after that. The surveyors cut the arrow when the rails came through, and every field boundary in the valley is measured off it. Let it weather and there'd be a quarrel over every hedge."},
		Schedule = {{6, 19, "lm_training_drill"}, {19, 6, "lm_field_shelter"}}}, -- (fix round 4, Ruling 39: nights by the
		-- field's stand, 87 studs from the drill; was the east hay barn, an 810-stud walk each way)
	{Id = "lm_signalman", Name = "Abel Crane", Job = "Signalman", Faction = "Townsfolk", Idle = "NPC_CrossArms",
		JobLine = "Every train through the gap goes past my levers first, day or night. Somebody has to be at them.",
		Look = {Nation = "Amestrian", Gender = "Male", Seed = 2408},
		Schedule = {{0, 24, "lm_signal_box"}}},
}

return {Regions = {Lindenmoor = Lindenmoor}}

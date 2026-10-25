-- Townsfolk rosters per region (region builds spec §5). Format: see TownsfolkLogic / the Region Foundation plan, Task 4.
-- Townsfolk.Regions[RegionId] = { {Id, Name, Job, JobLine, Faction, Look, Idle?, Schedule, Greetings?, Clue?}, ... }
-- Foundry Yard's roster: Townsfolk.Regions.Foundry, below (Foundry data plan Task 5).
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


-- Foundry (Foundry data plan Task 5, 2026-10-25): Foundry Yard's 26 townsfolk on two shifts, on the RenseiPosts of
-- workspace.World.Map.Foundry (Art/Regions/Foundry/layout.json; Task 4's 88 posts). Every name, job, line, hour, idle and
-- look seed is a PROPOSAL.
--   * Names (Ruling 3): all original; no first name is already the game's (Dialogues speakers, enemy and NPC display
--     names, Lindenmoor's roster, TownsfolkLogic.NewcomerNames). Test_FoundryRoster checks it.
--   * The rigs are adult R6s (there is no child rig), so the two runners are errand runners.
--   * The two off-duty guards are Townsfolk, not Authority (PROPOSAL): an Authority agent counts as law and adds Heat on
--     sight, and these two are off duty.
--   * A post is one townsperson's at a time (TownsfolkLogic.Validate; slots are half-open, so back to back is fine): the
--     canteen seats, crane_bay_1/3, furnace_1/2 and square_seat_2 are shared at different hours; canteen_seat_4 has the
--     keeper 06-07 and 21-22, the casting hand 13-14 and 22-23 and the gantry hand 14-15.
--   * All 24 Home posts are used. Unused (allowed): crane_bay_2/4, canteen_cook_2, forge_wing_1/2, stack_yard, slag_lane,
--     casting_shed_1/2, shed_hand_1/2, court_hand, shift_office_work (Ruling 16), yard_hand_2/3 and every Shelter.
--   * Every post used has a Shelter within 145 studs (Task 4; the worst is yard_hand_4 at 140).
--   * Clue lines (fy_furnace_d1, fy_furnace_l1, fy_clerk) come with Task 6.
-- The day (world clock; PROPOSAL hours):
--   day crew        works 06-14, eats 14-15 (canteen or square), home 15-06
--   late crew       eats 13-14, works 14-22, eats 22-23, home 23-13 (fy_crane_l2: square 13-14, no supper)
--   furnace keeper  holds the banked fires 22-06 at furnace_3; canteen 06-07 and 21-22; boarding house 07-21
--   yard hands      yard_hand_1 06-14 / yard_hand_4 14-22, home otherwise
--   station porter  platform 06-14, freight side 14-22, home 22-06
--   shift clerk     shift office 06-18, home 18-06
--   canteen cooks   05-14 and 14-23 (the canteen is served 05-23)
--   market          the four traders keep their stalls 08-20
--   boarding keeper keeps the desk round the clock
--   errand runners  08-19: square / row / court seat / square or row, home 19-08
--   off-duty guards 08-20 on the square and at the station; nights on a square bench or at home
local Foundry = {
	{Id = "fy_crane_d1", Name = "Hollis Brandt", Job = "Crane hand", Faction = "Foundry", Idle = "NPC_HandInPocket",
		JobLine = "Bay one, mornings. If the hook's moving, you're not standing under it.",
		Look = {Nation = "Amestrian", Gender = "Male", Seed = 3101},
		Schedule = {{6, 14, "crane_bay_1"}, {14, 15, "canteen_seat_1"}, {15, 6, "workers_row_1"}}},
	{Id = "fy_crane_l1", Name = "Maud Coller", Job = "Crane hand", Faction = "Foundry", Idle = "NPC_HandInPocket",
		JobLine = "I take the bay crane after Hollis. He leaves the cab warm and the levers sticky.",
		Look = {Nation = "Amestrian", Gender = "Female", Seed = 3102},
		Schedule = {{13, 14, "canteen_seat_1"}, {14, 22, "crane_bay_1"}, {22, 23, "canteen_seat_1"}, {23, 13, "workers_row_2"}}},
	{Id = "fy_crane_d2", Name = "Piotr Sabelev", Job = "Crane hand", Faction = "Foundry", Idle = "NPC_HandInPocket",
		JobLine = "Came south for the wages. Stayed for the canteen, heaven help me.",
		Look = {Nation = "Drachman", Gender = "Male", Seed = 3103},
		Schedule = {{6, 14, "crane_bay_3"}, {14, 15, "square_seat_1"}, {15, 6, "workers_row_3"}}},
	{Id = "fy_crane_l2", Name = "Agna Thorley", Job = "Crane hand", Faction = "Foundry", Idle = "NPC_CrossArms",
		JobLine = "Bay three, afternoons. Don't wave at the cab. I can't wave back.",
		Look = {Nation = "Amestrian", Gender = "Female", Seed = 3104},
		Schedule = {{13, 14, "square_seat_2"}, {14, 22, "crane_bay_3"}, {22, 13, "workers_row_4"}}},
	{Id = "fy_furnace_d1", Name = "Edmund Rusk", Job = "Furnace hand", Faction = "Foundry", Idle = "NPC_Blacksmith",
		JobLine = "Furnace One, mornings. Twelve years, and she's never once let me forget it's her shift, not mine.",
		Look = {Nation = "Amestrian", Gender = "Male", Seed = 3105},
		Schedule = {{6, 14, "furnace_1"}, {14, 15, "canteen_seat_2"}, {15, 6, "workers_row_5"}}},
	{Id = "fy_furnace_l1", Name = "Sella Marsh", Job = "Furnace hand", Faction = "Foundry", Idle = "NPC_Blacksmith",
		JobLine = "Late shift at Furnace One. You get used to the heat. You never get used to the noise.",
		Look = {Nation = "Amestrian", Gender = "Female", Seed = 3106},
		Schedule = {{13, 14, "canteen_seat_2"}, {14, 22, "furnace_1"}, {22, 23, "canteen_seat_2"}, {23, 13, "workers_row_6"}}},
	{Id = "fy_furnace_d2", Name = "Gideon Pell", Job = "Furnace hand", Faction = "Foundry", Idle = "NPC_Blacksmith",
		JobLine = "Furnace Two. Keep back from the mouth, unless you fancy losing your eyebrows.",
		Look = {Nation = "Amestrian", Gender = "Male", Seed = 3107},
		Schedule = {{6, 14, "furnace_2"}, {14, 15, "canteen_seat_3"}, {15, 6, "workers_row_7"}}},
	{Id = "fy_furnace_l2", Name = "Tamsin Hale", Job = "Furnace hand", Faction = "Foundry", Idle = "NPC_Blacksmith",
		JobLine = "Afternoons on Two. I'll eat when the pour's done.",
		Look = {Nation = "Amestrian", Gender = "Female", Seed = 3108},
		Schedule = {{13, 14, "canteen_seat_3"}, {14, 22, "furnace_2"}, {22, 23, "canteen_seat_3"}, {23, 13, "workers_row_8"}}},
	{Id = "fy_keeper", Name = "Oswin Tarr", Job = "Furnace keeper", Faction = "Foundry", Idle = "NPC_CrossArms",
		JobLine = "Somebody keeps the fires in overnight. Banked, not out. Out is a week's work to light again.",
		Look = {Nation = "Amestrian", Gender = "Male", Seed = 3109},
		Schedule = {{22, 6, "furnace_3"}, {6, 7, "canteen_seat_4"}, {7, 21, "boarding_home_1"}, {21, 22, "canteen_seat_4"}}},
	{Id = "fy_gantry_d", Name = "Rhea Calloway", Job = "Gantry hand", Faction = "Foundry", Idle = "NPC_HandInPocket",
		JobLine = "Up on the gantry you see everything. Mostly you see people standing where they shouldn't.",
		Look = {Nation = "Amestrian", Gender = "Female", Seed = 3110},
		Schedule = {{6, 14, "hall_gantry"}, {14, 15, "canteen_seat_4"}, {15, 6, "workers_row_9"}}},
	{Id = "fy_casting_l", Name = "Bram Okonek", Job = "Casting hand", Faction = "Foundry", Idle = "NPC_Blacksmith",
		JobLine = "Pour's at four. If you're on the floor when the ladle tips, you'd best be quick.",
		Look = {Nation = "Amestrian", Gender = "Male", Seed = 3111},
		Schedule = {{13, 14, "canteen_seat_4"}, {14, 22, "casting_floor"}, {22, 23, "canteen_seat_4"}, {23, 13, "workers_row_10"}}},
	{Id = "fy_yard_d", Name = "Nell Ashgrove", Job = "Yard hand", Faction = "Foundry", Idle = "NPC_HandInPocket",
		JobLine = "Wagons in, wagons out. Count them twice. The Authority counts them three times.",
		Look = {Nation = "Amestrian", Gender = "Female", Seed = 3112},
		Schedule = {{6, 14, "yard_hand_1"}, {14, 6, "cinder_home_1"}}},
	{Id = "fy_yard_l", Name = "Ivo Kettle", Job = "Yard hand", Faction = "Foundry", Idle = "NPC_HandInPocket",
		JobLine = "Evening freight's the worst. Nobody signs for anything after dark.",
		Look = {Nation = "Amestrian", Gender = "Male", Seed = 3113},
		Schedule = {{14, 22, "yard_hand_4"}, {22, 14, "cinder_home_2"}}},
	{Id = "fy_porter", Name = "Dunstan Rook", Job = "Station porter", Faction = "Townsfolk", Idle = "NPC_CrossArms",
		JobLine = "Platform in the morning, the freight side after. Bags, crates, lost children. I've carried all three.",
		Look = {Nation = "Amestrian", Gender = "Male", Seed = 3114},
		Schedule = {{6, 14, "station_porter_platform"}, {14, 22, "station_porter_yard"}, {22, 6, "lower_home_1"}}},
	{Id = "fy_clerk", Name = "Aldous Merriweather", Job = "Shift clerk", Faction = "Foundry", Idle = "NPC_CrossArms",
		JobLine = "Every hour worked in this yard goes through my pen. Every hour.",
		Look = {Nation = "Amestrian", Gender = "Male", Seed = 3115},
		Schedule = {{6, 18, "shift_clerk"}, {18, 6, "lower_home_3"}}},
	{Id = "fy_cook_1", Name = "Su Ling Pao", Job = "Canteen cook", Faction = "Townsfolk", Idle = "NPC_CrossArms",
		JobLine = "Breakfast at five, and the day crew eats it whether they're awake or not.",
		Look = {Nation = "Xingnese", Gender = "Female", Seed = 3116},
		Schedule = {{5, 14, "canteen_cook"}, {14, 5, "boarding_home_2"}}},
	{Id = "fy_cook_2", Name = "Barnaby Dace", Job = "Canteen cook", Faction = "Townsfolk", Idle = "NPC_CrossArms",
		JobLine = "Stew at two, stew at ten. Ask what's in it and you'll get less.",
		Look = {Nation = "Amestrian", Gender = "Male", Seed = 3117},
		Schedule = {{14, 23, "canteen_cook"}, {23, 14, "boarding_home_3"}}},
	{Id = "fy_trader_1", Name = "Ottilie Brack", Job = "Market trader", Faction = "Townsfolk", Idle = "NPC_CrossArms",
		JobLine = "Gloves, aprons, goggles. Everything the Foundry wears out, I sell back to it.",
		Look = {Nation = "Amestrian", Gender = "Female", Seed = 3118},
		Schedule = {{8, 20, "market_trader_1"}, {20, 8, "boarding_home_4"}}},
	{Id = "fy_trader_2", Name = "Cassio Benedetti", Job = "Market trader", Faction = "Townsfolk", Idle = "NPC_CrossArms",
		JobLine = "Oil and olives from the south. The olives are real. The oil is mostly real.",
		Look = {Nation = "Aerugonian", Gender = "Male", Seed = 3119},
		Schedule = {{8, 20, "market_trader_2"}, {20, 8, "cinder_home_4"}}},
	{Id = "fy_trader_3", Name = "Mabel Ferris", Job = "Market trader", Faction = "Townsfolk", Idle = "NPC_CrossArms",
		JobLine = "Bread from the bakehouse on Mill Street. Still warm if you're early.",
		Look = {Nation = "Amestrian", Gender = "Female", Seed = 3120},
		Schedule = {{8, 20, "market_trader_3"}, {20, 8, "cinder_home_5"}}},
	{Id = "fy_trader_4", Name = "Jonas Abernathy", Job = "Market trader", Faction = "Townsfolk", Idle = "NPC_CrossArms",
		JobLine = "Pots, pans, kettles, all cast in the hall. Seconds, mind. That's why they're cheap.",
		Look = {Nation = "Amestrian", Gender = "Male", Seed = 3121},
		Schedule = {{8, 20, "market_trader_4"}, {20, 8, "cinder_home_6"}}},
	{Id = "fy_boarding", Name = "Winifred Tull", Job = "Boarding-house keeper", Faction = "Townsfolk", Idle = "NPC_CrossArms",
		JobLine = "Rooms by the week, paid in advance. No cooking in the rooms, and no alchemy anywhere.",
		Look = {Nation = "Amestrian", Gender = "Female", Seed = 3122},
		Schedule = {{0, 24, "boarding_keeper"}}},
	{Id = "fy_runner_1", Name = "Pip Garrow", Job = "Errand runner", Faction = "Townsfolk", Idle = "NPC_HandInPocket",
		JobLine = "A copper a message, two if it's heavy, three if it's for the shift office.",
		Look = {Nation = "Amestrian", Gender = "Male", Seed = 3123},
		Schedule = {{8, 11, "errand_square"}, {11, 14, "errand_row"}, {14, 17, "court_seat_2"}, {17, 19, "errand_square"}, {19, 8, "workers_row_11"}}},
	{Id = "fy_runner_2", Name = "Tilly Mace", Job = "Errand runner", Faction = "Townsfolk", Idle = "NPC_HandInPocket",
		JobLine = "I run for the canteen and the market both. They both pay late.",
		Look = {Nation = "Amestrian", Gender = "Female", Seed = 3124},
		Schedule = {{8, 11, "errand_row"}, {11, 14, "errand_square"}, {14, 17, "court_seat_1"}, {17, 19, "errand_row"}, {19, 8, "lower_home_2"}}},
	{Id = "fy_guard_1", Name = "Ewan Stroud", Job = "Off-duty guard", Faction = "Townsfolk", Idle = "NPC_CrossArms",
		JobLine = "Off duty. If you need the watch, the watch is somewhere else.",
		Look = {Nation = "Amestrian", Gender = "Male", Seed = 3125},
		Schedule = {{8, 20, "guard_square"}, {20, 8, "square_seat_2"}}},
	{Id = "fy_guard_2", Name = "Hester Quayle", Job = "Off-duty guard", Faction = "Townsfolk", Idle = "NPC_CrossArms",
		JobLine = "I watch the trains come in. Habit. Don't read anything into it.",
		Look = {Nation = "Amestrian", Gender = "Female", Seed = 3126},
		Schedule = {{8, 20, "guard_station"}, {20, 8, "cinder_home_3"}}},
}

return {Regions = {Lindenmoor = Lindenmoor, Foundry = Foundry}}

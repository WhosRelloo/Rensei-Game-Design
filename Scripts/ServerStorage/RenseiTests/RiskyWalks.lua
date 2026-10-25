-- RiskyWalks (Foundry Yard plan Task 9, owner request, 2026-10-25): the routes Play_FoundryWalks' quick mode walks
-- (ServerStorage attribute WalksQuick = true): {Id, From, To}, one schedule change of Foundry's roster each. A route
-- is listed when its walk needed the Mover's corner repair or failed in a recorded run. Seeded from Task 4b's
-- G8-G10 failures (#36, #42, #55, #63 in the walkability investigation's numbering, and Rusk's furnace_1 ->
-- canteen_seat_2) and from
-- the three full acceptance runs of Task 9 (each 73/73 arrived; every route below needed a repair in at least one).
-- To update: after a full run, copy the lines Play_FoundryWalks prints ("[FoundryWalks] risky: ...", also
-- ServerStorage's attribute FoundryWalksRisky) in here, keeping the seeds. An empty list fails quick mode.
-- (Data only; a ModuleScript so the Play VM can read it: synced to Foundry with the other RenseiTests.)
return {
	Routes = {
		{"fy_yard_d", "yard_hand_1", "cinder_home_1"}, -- Task 4b #36 (corner cut at lane_5.Boiler)
		{"fy_porter", "lower_home_1", "station_porter_platform"}, -- Task 4b #42 (Station torso, a lamp post in sight); repaired in 3 of 3 Task 9 runs
		{"fy_trader_4", "market_trader_4", "cinder_home_6"}, -- Task 4b #55 (stall_6 / stall_12 posts); repaired in 3 of 3 Task 9 runs
		{"fy_runner_2", "errand_square", "court_seat_1"}, -- Task 4b #63 (Test_FoundryPaths G8-G10); repaired in 2 of 3 Task 9 runs
		{"fy_furnace_d1", "furnace_1", "canteen_seat_2"}, -- Task 4b (G8-G10); repaired in 3 of 3 Task 9 runs
		{"fy_casting_l", "canteen_seat_4", "casting_floor"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_casting_l", "canteen_seat_4", "workers_row_10"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_casting_l", "casting_floor", "canteen_seat_4"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_casting_l", "workers_row_10", "canteen_seat_4"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_crane_d1", "crane_bay_1", "canteen_seat_1"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_crane_d1", "workers_row_1", "crane_bay_1"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_crane_d2", "square_seat_1", "workers_row_3"}, -- repaired in 2 of 3 Task 9 runs
		{"fy_crane_d2", "workers_row_3", "crane_bay_3"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_crane_l1", "crane_bay_1", "canteen_seat_1"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_crane_l2", "crane_bay_3", "workers_row_4"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_crane_l2", "workers_row_4", "square_seat_2"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_furnace_d1", "canteen_seat_2", "workers_row_5"}, -- repaired in 2 of 3 Task 9 runs
		{"fy_furnace_d1", "workers_row_5", "furnace_1"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_furnace_d2", "canteen_seat_3", "workers_row_7"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_furnace_d2", "furnace_2", "canteen_seat_3"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_furnace_d2", "workers_row_7", "furnace_2"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_furnace_l1", "canteen_seat_2", "furnace_1"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_furnace_l1", "canteen_seat_2", "workers_row_6"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_furnace_l1", "furnace_1", "canteen_seat_2"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_furnace_l1", "workers_row_6", "canteen_seat_2"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_furnace_l2", "canteen_seat_3", "furnace_2"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_furnace_l2", "canteen_seat_3", "workers_row_8"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_furnace_l2", "furnace_2", "canteen_seat_3"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_furnace_l2", "workers_row_8", "canteen_seat_3"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_gantry_d", "canteen_seat_4", "workers_row_9"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_gantry_d", "hall_gantry", "canteen_seat_4"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_gantry_d", "workers_row_9", "hall_gantry"}, -- repaired in 2 of 3 Task 9 runs
		{"fy_guard_2", "cinder_home_3", "guard_station"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_guard_2", "guard_station", "cinder_home_3"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_keeper", "canteen_seat_4", "furnace_3"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_keeper", "furnace_3", "canteen_seat_4"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_runner_1", "court_seat_2", "errand_square"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_runner_1", "errand_row", "court_seat_2"}, -- repaired in 2 of 3 Task 9 runs
		{"fy_runner_1", "errand_square", "errand_row"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_runner_1", "errand_square", "workers_row_11"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_runner_1", "workers_row_11", "errand_square"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_runner_2", "court_seat_1", "errand_row"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_runner_2", "errand_row", "errand_square"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_runner_2", "errand_row", "lower_home_2"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_runner_2", "lower_home_2", "errand_row"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_trader_1", "boarding_home_4", "market_trader_1"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_trader_2", "market_trader_2", "cinder_home_4"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_trader_3", "cinder_home_5", "market_trader_3"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_trader_3", "market_trader_3", "cinder_home_5"}, -- repaired in 2 of 3 Task 9 runs
		{"fy_trader_4", "cinder_home_6", "market_trader_4"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_yard_d", "cinder_home_1", "yard_hand_1"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_yard_l", "cinder_home_2", "yard_hand_4"}, -- repaired in 3 of 3 Task 9 runs
		{"fy_yard_l", "yard_hand_4", "cinder_home_2"}, -- repaired in 3 of 3 Task 9 runs
	},
}

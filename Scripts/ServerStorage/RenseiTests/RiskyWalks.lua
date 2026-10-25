-- RiskyWalks (Foundry Yard plan Task 9, owner request, 2026-10-25): the routes Play_FoundryWalks' quick mode walks
-- (ServerStorage attribute WalksQuick = true): {Id, From, To}, one schedule change of Foundry's roster each. A route
-- is listed only when its walk FAILED or NEEDED A REPLAN in a recorded run (owner: "only recheck routes that failed or
-- needed a replan, not routine corner repairs"). Seeded from Task 4b's G8-G10 failures (#36, #42, #55, #63 in the
-- walkability investigation's numbering, and Rusk's furnace_1 -> canteen_seat_2) and from the three full acceptance
-- runs of Task 9 (each 73/73 arrived, none failed; the routes below re-planned at least once).
-- To update: after a full run, copy the lines Play_FoundryWalks prints ("[FoundryWalks] risky: ...", also
-- ServerStorage's attribute FoundryWalksRisky) in here, keeping the seeds. An empty list fails quick mode.
-- (Data only; a ModuleScript so the Play VM can read it: synced to Foundry with the other RenseiTests.)
return {
	Routes = {
		{"fy_yard_d", "yard_hand_1", "cinder_home_1"}, -- Task 4b #36 (corner cut at lane_5.Boiler)
		{"fy_porter", "lower_home_1", "station_porter_platform"}, -- Task 4b #42 (Station torso, a lamp post in sight)
		{"fy_trader_4", "market_trader_4", "cinder_home_6"}, -- Task 4b #55 (stall_6 / stall_12 posts)
		{"fy_runner_2", "errand_square", "court_seat_1"}, -- Task 4b #63 (Test_FoundryPaths G8-G10)
		{"fy_furnace_d1", "furnace_1", "canteen_seat_2"}, -- Task 4b (G8-G10)
		{"fy_trader_4", "cinder_home_6", "market_trader_4"}, -- re-planned in 3 of 3 Task 9 runs
		{"fy_runner_1", "errand_row", "court_seat_2"}, -- re-planned in 2 of 3 Task 9 runs
		{"fy_runner_2", "errand_row", "lower_home_2"}, -- re-planned in 2 of 3 Task 9 runs
		{"fy_gantry_d", "hall_gantry", "canteen_seat_4"}, -- re-planned in 1 of 3 Task 9 runs
		{"fy_gantry_d", "canteen_seat_4", "workers_row_9"}, -- re-planned in 1 of 3 Task 9 runs
		{"fy_furnace_d2", "furnace_2", "canteen_seat_3"}, -- re-planned in 1 of 3 Task 9 runs
		{"fy_trader_3", "market_trader_3", "cinder_home_5"}, -- re-planned in 1 of 3 Task 9 runs
		{"fy_furnace_d1", "canteen_seat_2", "workers_row_5"}, -- re-planned in 1 of 3 Task 9 runs
		{"fy_furnace_l2", "canteen_seat_3", "workers_row_8"}, -- re-planned in 1 of 3 Task 9 runs
	},
}

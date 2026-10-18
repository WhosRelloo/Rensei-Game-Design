# Starter map: Countryside farm village (Phase 7 layout)

**Owner choice (2026-10-17):** "Build the starter map as the Resembool-style Countryside farm village."

**Reference:** the slideshow's Countryside mood board (a farm village, fenced dirt roads, a stone bridge, cypress hills). The board gives no layout or scale, so **everything below is PROPOSAL**: the name, the positions and the sizes.

**Working name: Lindenmoor** (PROPOSAL; an original name, not Resembool).

## Placement

- **Location:** a new terrain region **south of the current graybox hub**, centred on world **(0, 4, -650)**. It spans about x −330..330 and z −980..−300. The hub occupies x ±230, z −130..260, so they don't overlap.
- **Hub link:** the village's north road leaves the terrain at z ≈ −300 and runs over the baseplate to the hub (the training ground, the Drillmaster and the bandit spawns at z ≈ −80).
- **Terrain level:** 8 studs (the baseplate top is 0), with the creek bed at 4. It ramps down to the baseplate at the north edge.
- **Players start in the village square.** The old origin `SpawnLocation` is disabled, not deleted. Setting its `Enabled` back to true restores the old start.

## Layout (local coordinates from the village centre; +Z is north, toward the hub)

| Feature | Where | Notes |
|---|---|---|
| Village square | (0, 0), r ≈ 34 | Cobblestone, a well, a notice board, the spawn |
| Main road (N–S) | x = 0, z −20 → 350 | Dirt, 12 wide, fenced past the houses, leads to the hub |
| Village lane (E–W) | z = 0, x −240 → 240 | Dirt, 10 wide; houses on both sides |
| Mill Creek | z ≈ 110 ± 14 (meanders) | **Shallow**: about 1.2 deep and wadeable. At 2.4 deep characters swam, and swimming isn't designed. Banks drop 4 studs |
| Stone arch bridge | where the main road crosses the creek | Deck about 2 above the banks |
| Houses (×9) | around the square and along both roads | Stone ground floor, timber/plaster upper floor, red tile roofs. Each is its own Model with its pivot at the door, so it can be swapped for a Blender mesh later |
| Automail workshop | Workshop Hill, (195, −95), hill +16, flat top r 50 | **The owner's Blender model** (RockbellHouse), as authored, with its yard walls and utility pole. A path climbs from the lane. (Moved from (150, −60) so the yard fits on the hilltop.) |
| Station | west end of the lane, (−245, 0) | Platform, station house, N–S rails (scenery; no train) |
| Fields | SW (−160..−60, −200..−80) and SE (60..170, −200..−110) | Fenced wheat rows; a barn and hay at the end of the farm track (0, −200) |
| Cypress Ridge | south and west edges, up to +35 | Rows of cypress along the ridge and the north road; oaks near the houses |
| Creek gorge ledge | east creek bend (x ≈ 200..250) | A rock cliff on the north bank with an **authored `RenseiLedge`** strip 6 above the water, with a shelf at each end. A shortcut from the creek up toward Workshop Hill |
| Bramble Hollow | the SE woods, (215, −235) | A small bandit camp: 2 `Grunt` spawns (`RenseiEnemySpawn`), a tent and a fire pit |

## Discovery areas (`RenseiArea`, no overlaps)

| Area | Description |
|---|---|
| Lindenmoor | Square, houses, lanes |
| Lindenmoor Station | |
| Mill Creek Bridge | |
| Workshop Hill | |
| Cypress Ridge | South hills |
| Bramble Hollow | Bandit camp |

All area descriptions are PROPOSAL text.

## How it's built

- **Built in Studio** with Terrain (`WriteVoxels`, smooth heightmap) plus anchored Parts.
- **No Blender** connection exists in this environment. Buildings are modular Models (stone base, upper floor, roof, chimney, door, windows) that can be replaced by Blender meshes one by one.
- **Performance target:** fewer than 3,000 parts. Small props don't cast shadows. Invisible volumes have `CanCollide` / `CanQuery` / `CanTouch` off, so ledge, aim and hitbox raycasts ignore them.

## Not in scope here

- Dialogue NPCs for villagers. There's no written content, and inventing quest content isn't part of this pass.
- A train, and interiors (the houses are closed shells).
- ~~Swimming~~ **Added 2026-10-18 (owner decision 6).** The creek stays shallow and wadeable. The deep **Mill Pond** on the creek west of the bridge (world −110, −553, 5.2 deep) is swimmable. See `Changelog.md`.

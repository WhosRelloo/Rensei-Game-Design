-- ProfileData (ReplicatedStorage.Modules.Data.ProfileData) addition, World plan 1 Task 5 (2026-10-21).
-- Spliced in right after the `Licence = {...}` line; additive, so ProfileService's Reconcile fills old saves
-- (no SchemaVersion bump). Keep ProfileData the same in every place.
	Travel = {Region = "", Tickets = {}}, -- World plan 1: last region (rejoin goes there) and unused tickets ["Route|Class"] = count

-- World Plan 1 Task 5 Step 9 (2026-10-21): run in the Main Menu place (123967384111466), Edit.
-- Syncs Places (Task 1, embedded below) and sends a returning player to Places.ResumePlace(Data), the region they were last in.
-- The same Places sync without the MenuServer change was run in the Tutorial place. Backups: RenseiBackups["Pre-TravelService_2026-10-21"].
local SS = game.ServerStorage
local Backups = SS:FindFirstChild("RenseiBackups") or Instance.new("Folder")
Backups.Name = "RenseiBackups" Backups.Parent = SS
local B = Backups:FindFirstChild("Pre-TravelService_2026-10-21") or Instance.new("Folder")
B.Name = "Pre-TravelService_2026-10-21" B.Parent = Backups
local out = {}
local P = game.ReplicatedStorage.Modules.Data.Rensei.Places
if not B:FindFirstChild("Places") then P:Clone().Parent = B end
P.Source = [=====[-- Rensei places (one experience, 9509447316) and the start flow (owner 2026-10-14):
--   Main Menu + Customize (Menu) -> Tutorial -> cutscene -> Main game (Ye)
-- World plan 1 (2026-10-20): one place per region (ids from the owner). Region ids match Rensei.Regions.
-- Keep this file the same in every place.
local Places = {
	Menu = 123967384111466, -- "Character Customization": main menu + character creation
	Tutorial = 74257385894576,
	Main = 106992859583940, -- "RSEI" (Ye) = Lindenmoor
}

-- Climate drives seasons (world spec §5): Temperate, Desert, Frozen, Eclipse
Places.Regions = {
	Lindenmoor = {PlaceId = 106992859583940, Name = "Lindenmoor", Climate = "Temperate", Station = "Lindenmoor Station"},
	Foundry = {PlaceId = 109591196441030, Name = "the Foundry Yard", Climate = "Temperate", Station = "Foundry Junction"},
	City = {PlaceId = 74075793529314, Name = "Central City", Climate = "Temperate", Station = "Central Terminal"},
	Aerugo = {PlaceId = 72020960130134, Name = "the Aerugo Borderlands", Climate = "Temperate"},
	Ishval = {PlaceId = 133625615147752, Name = "Ishval", Climate = "Desert", Station = "Ishval Rail Halt"},
	North = {PlaceId = 132378034692557, Name = "the Northern Wall", Climate = "Frozen"},
	Corrupted = {PlaceId = 138436167547886, Name = "the Corrupted Lands", Climate = "Eclipse"},
}

function Places.RegionOf(PlaceId)
	for Id, R in pairs(Places.Regions) do
		if R.PlaceId == PlaceId then return Id end
	end
	return nil
end

-- Where a returning player goes: the region they were last in (Data.Travel.Region), else Lindenmoor.
function Places.ResumePlace(Data)
	local Region = Data and Data.Travel and Data.Travel.Region
	local R = type(Region) == "string" and Places.Regions[Region]
	return R and R.PlaceId or Places.Main
end

-- Where a profile should go next from the menu.
function Places.NextFor(Data)
	local Identity = Data and Data.Identity
	if not Identity or not Identity.CharacterCreated then return "Customize" end
	if not (Data.Flow and Data.Flow.TutorialDone) then return "Tutorial" end
	return "Main"
end

-- TeleportData every in-flow teleport carries, so a place can tell a flow arrival from a direct join.
Places.FlowTag = "RenseiFlow"

return Places
]=====]
table.insert(out, "Places updated (" .. #P.Source .. ")")
local M = game.ServerScriptService.MenuServer
local Old = "\tlocal PlaceId = Places[Next]\n"
local New = "\tlocal PlaceId = Next == \"Main\" and Places.ResumePlace(Profile.Data) or Places[Next] -- World plan 1: back to the region they were last in\n"
local s = M.Source
if s:find(New, 1, true) then
	table.insert(out, "MenuServer already done")
else
	local a, b = s:find(Old, 1, true)
	assert(a and not s:find(Old, b + 1, true), "anchor not unique")
	if not B:FindFirstChild("MenuServer") then M:Clone().Parent = B end
	M.Source = s:sub(1, a - 1) .. New .. s:sub(b + 1)
	table.insert(out, "MenuServer line changed")
end
return table.concat(out, "; ")

-- Hint: {"Seen", Id} from FieldNotesUI once a one-time Field Note has been shown. Only known ids are
-- stored (Rensei.FieldNotes), on the profile's Flow.Hints, so a note never shows twice on an account.
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FieldNotes = require(ReplicatedStorage.Modules.Data.Rensei.FieldNotes)
local ProgressionService = require(ServerScriptService.ProgressionService)

return function(Player, Action, Id)
	if Action ~= "Seen" or type(Id) ~= "string" or not FieldNotes.List[Id] then return end
	local Data = ProgressionService.GetData(Player)
	if not Data then return end
	Data.Flow = Data.Flow or {}
	Data.Flow.Hints = Data.Flow.Hints or {}
	Data.Flow.Hints[Id] = true
end

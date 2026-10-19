-- Investigation requests: {"Deduce", DeductionId, Answers} from the Case Board (JournalUI).
-- The result goes back as the UI event "CaseResult".
local ServerScriptService = game:GetService("ServerScriptService")

local InvestigationService = require(ServerScriptService.InvestigationService)
local UIService = require(ServerScriptService.UIService)

-- {"Identify", RecordKey, Name} from the Identities tab: name a Suspected subject (IdentityService checks it
-- against the live subject). The result goes back as the UI event "IdentifyResult".
return function(Player, Action, Id, Answers)
	if Action == "Deduce" and type(Id) == "string" then
		local Ok, Text = InvestigationService.Deduce(Player, Id, Answers)
		UIService.Notify(Player, "CaseResult", {Id = Id, Ok = Ok, Text = Text})
	elseif Action == "Identify" and type(Id) == "string" and #Id <= 64 then
		local Ok, Text = require(ServerScriptService.IdentityService).Identify(Player, Id, Answers)
		UIService.Notify(Player, "IdentifyResult", {Id = Id, Ok = Ok, Text = Text})
	end
end

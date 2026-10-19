-- StoryService: the only writer of profile Story.Flags / Story.Evidence / Story.Deductions.
-- Every write that matters to a quest fires QuestService.Signal so objectives follow.
-- Flags are never silently overwritten: SetFlag refuses to change an existing value unless
-- Overwrite is passed (story choices are recorded once).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local EvidenceDefs = require(ReplicatedStorage.Modules.Data.Rensei.Evidence)
local ProgressionService = require(ServerScriptService.ProgressionService)
local UIService = require(ServerScriptService.UIService)

local StoryService = {}

local function Story(Player)
	local Data = ProgressionService.GetData(Player)
	return Data and Data.Story, Data
end
StoryService.Story = Story

local function Quests() return require(ServerScriptService.QuestService) end -- lazy: no require cycle

function StoryService.Flag(Player, Id)
	local S = Story(Player)
	return S and S.Flags[Id]
end

function StoryService.SetFlag(Player, Id, Value, Overwrite)
	local S = Story(Player)
	if not S or type(Id) ~= "string" then return false end
	if Value == nil then Value = true end
	if S.Flags[Id] ~= nil and not Overwrite then return S.Flags[Id] == Value end
	S.Flags[Id] = Value
	Quests().Signal(Player, "Flag", Id)
	ProgressionService.Sync(Player)
	return true
end

function StoryService.HasEvidence(Player, Id)
	local S = Story(Player)
	return S ~= nil and S.Evidence[Id] ~= nil
end

-- Returns true if this is new evidence.
function StoryService.GiveEvidence(Player, Id)
	local S = Story(Player)
	local Def = EvidenceDefs[Id]
	if not S or not Def then return false end
	if S.Evidence[Id] then return false end
	S.Evidence[Id] = os.time()
	UIService.Notify(Player, "Banner", {Text = "Evidence Found - [" .. Def.Title .. "]"})
	Quests().Signal(Player, "Evidence", Id)
	-- Player Identities: evidence that describes a technique links (as a hypothesis) to subjects seen using it
	if Def.Technique then pcall(function() require(ServerScriptService.IdentityService).OnEvidence(Player, Id) end) end
	ProgressionService.Sync(Player)
	return true
end

function StoryService.GiveDeduction(Player, Id, Title)
	local S = Story(Player)
	if not S or S.Deductions[Id] then return false end
	S.Deductions[Id] = os.time()
	UIService.Notify(Player, "Banner", {Text = "Deduction - [" .. (Title or Id) .. "]"})
	Quests().Signal(Player, "Deduce", Id)
	ProgressionService.Sync(Player)
	return true
end

return StoryService

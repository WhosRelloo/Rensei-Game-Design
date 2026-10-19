-- RumourService (2026-10-19, Morality × Reputation spec §5; slice R2): word of a player's deeds travels
-- between regions over real time. The spread itself is RumourService.Core (pure); this runs it:
--   * a Local / Public deed that someone perceived (MoralityService.Recorded, Strength > 0) starts a rumour;
--   * every 60 s, and once on join (offline catch-up), each player's rumours advance to the current time
--     and MoralityService.Refresh rebuilds standing (tier banners for any change);
--   * Report: a player the server recorded as a witness (WitnessService) reports the deed at a State desk
--     or a Circle drop; it lands there at once. Reports for deeds they didn't witness are refused.
-- Silencing witnesses and vouching are the next plans' content (they call Core.Silence); the clock can be
-- swapped for tests (SetClock).

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Core = require(script.Core)
local ProgressionService = require(ServerScriptService.ProgressionService)

local RumourService = {Core = Core}
RumourService.TickSeconds = 60

local Clock = os.time
function RumourService.SetClock(Fn) Clock = Fn or os.time end
function RumourService.Now() return Clock() end

local function Morality(Player)
	local Data = ProgressionService.GetData(Player)
	return Data and Data.Morality
end

function RumourService.Tick(Player)
	local M = Morality(Player)
	if not M then return 0 end
	local Arrivals = Core.Advance(M, Clock())
	if #Arrivals > 0 then require(ServerScriptService.MoralityService).Refresh(Player) end
	return #Arrivals
end

function RumourService.Report(Reporter, Subject, DeedId, Region, Faction)
	local WitnessService = require(ServerScriptService.WitnessService)
	local Now = Clock()
	if not WitnessService.CanReport(Reporter.UserId, Subject.UserId, DeedId, Now) then
		return false, "You didn't witness that."
	end
	local M = Morality(Subject)
	if not M then return false, "They aren't here." end
	local Heard = Core.LandReport(M, DeedId, Region, Faction, Now)
	WitnessService.Forget(Reporter.UserId, Subject.UserId, DeedId)
	if #Heard > 0 then require(ServerScriptService.MoralityService).Refresh(Subject) end
	return true
end

local function OnRecorded(Player, DeedId, Def, Info)
	if Def.Birth or Info.Scope == "Private" or (Info.Strength or 0) <= 0 then return end
	local M = Morality(Player)
	if M then Core.Spawn(M, DeedId, Info.Region, Info.Strength, Clock()) end
end

function RumourService.Start()
	table.insert(require(ServerScriptService.MoralityService).Recorded, OnRecorded)
	task.spawn(function()
		while true do
			task.wait(RumourService.TickSeconds)
			for _, Player in ipairs(Players:GetPlayers()) do
				local Ok, Err = pcall(RumourService.Tick, Player)
				if not Ok then warn("RumourService:", Err) end
			end
		end
	end)
end

return RumourService

-- RumourService (2026-10-19, Morality × Reputation spec §5; slice R2): word of a player's deeds travels
-- between regions over real time. The spread itself is RumourService.Core (pure); this runs it:
--   * a Local / Public deed that someone perceived (MoralityService.Recorded, Strength > 0) starts a rumour;
--   * every 60 s, and once on join (offline catch-up), each player's rumours advance to the current time
--     and MoralityService.Refresh rebuilds standing (tier banners for any change);
--   * Report: a player the server recorded as a witness (WitnessService) reports the deed at a State desk
--     or a Circle drop; it lands there at once. Reports for deeds they didn't witness are refused.
-- Silencing witnesses and vouching are the next plans' content (they call Core.Silence); the clock can be
-- swapped for tests (SetClock).
-- Plan 2 (2026-10-20): every landing goes to HeatService (crimes raise Heat where the law hears them), and
-- word that reached somewhere new shows as a toast with its reason line ("Word reached the City: ...").

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Core = require(script.Core)
local ProgressionService = require(ServerScriptService.ProgressionService)
local UIService = require(ServerScriptService.UIService)
local Regions = require(game:GetService("ReplicatedStorage").Modules.Data.Rensei.Regions)
local Deeds = require(game:GetService("ReplicatedStorage").Modules.Data.Rensei.Deeds)

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
	local Arrivals, Landings = Core.Advance(M, Clock())
	if #Arrivals > 0 then
		require(ServerScriptService.MoralityService).Refresh(Player)
		-- the newest arrival's reason line (one toast per tick, however many arrived)
		local A = Arrivals[#Arrivals]
		local Def = Deeds[A.Rumour.Deed]
		local Place = Regions.Regions[A.Place]
		if type(Def) == "table" and Def.Text and Place then
			UIService.Notify(Player, "Toast", {Text = ("Word reached %s: %s"):format(Place.Name, Def.Text)})
		end
	end
	if Landings and #Landings > 0 then
		local Ok, Err = pcall(function() require(ServerScriptService.HeatService).OnArrivals(Player, Landings) end)
		if not Ok then warn("RumourService: heat on arrival failed:", Err) end
	end
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

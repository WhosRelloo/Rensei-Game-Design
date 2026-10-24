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

-- HeardIn (region builds spec §5): the latest word in Region, across everyone in this server, newest first, at
-- most N: {{At, Text, Subject}, ...}. Rumour state is per player, so this reads each player's Morality. Read-only.
--   * word that reached Region from elsewhere (Data.Morality.News);
--   * (Task 6 ruling) deeds done in Region itself: they land there at once and write no News, but they are what the
--     town talks about. Read from Morality.Places[Region].Known (deed -> faction -> time heard); At is the earliest
--     time any faction there knew it.
-- Only deeds with a reason line (Deeds[Id].Text); origin (Birth) deeds are never rumours. The same deed lands once
-- per faction, so each (Subject, Text) is listed once, at its newest.
function RumourService.HeardIn(Region, N)
	local All = {}
	local function Add(At, Def, P)
		if type(At) == "number" and type(Def) == "table" and type(Def.Text) == "string" and not Def.Birth then
			table.insert(All, {At = At, Text = Def.Text, Subject = P})
		end
	end
	for _, P in ipairs(Players:GetPlayers()) do
		local D = ProgressionService.GetData(P)
		local M = D and D.Morality
		for _, A in ipairs(M and M.News or {}) do
			if A.Place == Region then Add(A.At, Deeds[A.Deed], P) end
		end
		local Place = M and type(M.Places) == "table" and M.Places[Region]
		for DeedId, Heard in pairs(type(Place) == "table" and type(Place.Known) == "table" and Place.Known or {}) do
			local At = nil
			for _, T in pairs(type(Heard) == "table" and Heard or {}) do
				if type(T) == "number" and (At == nil or T < At) then At = T end
			end
			Add(At, Deeds[DeedId], P)
		end
	end
	table.sort(All, function(a, b) return a.At > b.At end)
	local Out, Seen = {}, {}
	for _, R in ipairs(All) do
		if #Out >= (N or 3) then break end
		local Key = tostring(R.Subject.UserId) .. "|" .. R.Text
		if not Seen[Key] then
			Seen[Key] = true
			table.insert(Out, R)
		end
	end
	return Out
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

-- WorldClock (Region Foundation Task 2, 2026-10-23; region builds spec §4): the time of day comes from real time,
-- so every place and server shows the same hour. DayMinutes real minutes = one game day (PROPOSAL 24). Hold(h)
-- freezes it (admin Time command, tests); Release() lets it run. Lamps whose part has NightOnly = true light at night.
--   * Hour(Now?) is the real-time hour (Now = os.time() by default); Now() is the hour the world shows (the held
--     hour while held). Townsfolk schedules (Task 5) read Now().
--   * Changed fires with the whole hour each time it changes.
--   * Readers of Lighting.ClockTime (LightService's daylight, RoadService's night ambushes) just see it move.
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local WorldClock = {DayMinutes = 24} -- PROPOSAL
WorldClock.Changed = Instance.new("BindableEvent")
local Held, LastWhole
local Sweep = false -- a Hold / Release asks for a lamp sweep on the next tick, even within the same hour

function WorldClock.Hour(Now)
	Now = Now or os.time()
	return ((Now / 60) * (24 / WorldClock.DayMinutes)) % 24
end
-- the hour the world shows: the held hour while held, real time otherwise (controller ruling 1)
function WorldClock.Now()
	if Held then return Lighting.ClockTime end
	return WorldClock.Hour()
end
function WorldClock.IsNight(H)
	H = H or Lighting.ClockTime
	return H < 6 or H >= 18 -- PROPOSAL
end
function WorldClock.Hold(H) Held = H % 24 Lighting.ClockTime = Held Sweep = true end
function WorldClock.Release() Held = nil Sweep = true end
function WorldClock.IsHeld() return Held ~= nil end

local function Lamps(Night)
	for _, P in ipairs(CollectionService:GetTagged("RenseiLight")) do
		if P:GetAttribute("NightOnly") then
			for _, L in ipairs(P:GetChildren()) do if L:IsA("Light") then L.Enabled = Night end end
		end
	end
	-- NightOnly lamps that LightService hasn't tagged yet (no tag before LightService.Start)
	for _, L in ipairs(workspace:GetDescendants()) do
		if L:IsA("Light") and L.Parent:GetAttribute("NightOnly") and not CollectionService:HasTag(L.Parent, "RenseiLight") then L.Enabled = Night end
	end
end

function WorldClock.Tick()
	local H = Held or WorldClock.Hour()
	Lighting.ClockTime = H
	local Whole = math.floor(H)
	if Whole ~= LastWhole or Sweep then
		Sweep = false
		Lamps(WorldClock.IsNight(H))
		if Whole ~= LastWhole then
			LastWhole = Whole
			WorldClock.Changed:Fire(Whole)
		end
	end
end

function WorldClock.Start()
	task.spawn(function()
		while true do
			local Ok, Err = pcall(WorldClock.Tick)
			if not Ok then warn("WorldClock:", Err) end
			task.wait(1)
		end
	end)
end

return WorldClock

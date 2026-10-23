-- WorldClock (Region Foundation Task 2, 2026-10-23; region builds spec §4): the time of day comes from real time,
-- so every place and server shows the same hour. DayMinutes real minutes = one game day (PROPOSAL 24). Hold(h)
-- freezes it (admin Time command, tests); Release() lets it run. Lamps whose part has NightOnly = true light at night.
--   * Hour(Now?) is the real-time hour (Now = os.time() by default); Now() is the hour the world shows (the held
--     hour while held). Townsfolk schedules (Task 5) read Now().
--   * Changed fires with the whole hour each time it changes.
--   * NightOnly parts: their lights are on only at night, and by day the part's material becomes DayMaterial (so a
--     Neon lamp head doesn't glow at noon); at night it gets back its own material, kept in the NightMaterial
--     attribute. The parts are kept in a set (one scan at Start, then DescendantAdded / DescendantRemoving), so a
--     sweep never walks the whole workspace.
--   * Readers of Lighting.ClockTime (LightService's daylight, RoadService's night ambushes) just see it move.
local Lighting = game:GetService("Lighting")

local WorldClock = {DayMinutes = 24} -- PROPOSAL
WorldClock.DayMaterial = Enum.Material.SmoothPlastic -- PROPOSAL: a NightOnly part's material by day (owner may pick another)
WorldClock.Changed = Instance.new("BindableEvent")
local Held, LastWhole
local Sweep = false -- a Hold / Release asks for a lamp sweep on the next tick, even within the same hour
local NightParts = {} -- [BasePart] = true: parts in the workspace with NightOnly
WorldClock.NightParts = NightParts

function WorldClock.Hour(Now)
	Now = Now or os.time()
	return ((Now / 60) * (24 / WorldClock.DayMinutes)) % 24
end
-- the hour the world shows: the held hour while held, real time otherwise (controller ruling 1)
function WorldClock.Now()
	if Held then return Held end
	return WorldClock.Hour()
end
function WorldClock.IsNight(H)
	H = H or Lighting.ClockTime
	return H < 6 or H >= 18 -- PROPOSAL
end
function WorldClock.Hold(H) Held = H % 24 Lighting.ClockTime = Held Sweep = true end
function WorldClock.Release() Held = nil Sweep = true end
function WorldClock.IsHeld() return Held ~= nil end

-- a part with NightOnly, or a light added under one (catches a part parented before its attribute was set)
local function Watch(D)
	local P = D:IsA("Light") and D.Parent or D
	if P and P:IsA("BasePart") and P:GetAttribute("NightOnly") then NightParts[P] = true end
end

local function NightMaterial(P)
	local Name = P:GetAttribute("NightMaterial")
	if Name == nil then
		Name = P.Material.Name
		P:SetAttribute("NightMaterial", Name)
	end
	local Ok, M = pcall(function() return Enum.Material[Name] end)
	return Ok and M or P.Material
end

local function Lamps(Night)
	for P in pairs(NightParts) do
		if P.Parent and P:GetAttribute("NightOnly") then
			local M = NightMaterial(P)
			P.Material = Night and M or WorldClock.DayMaterial
			for _, L in ipairs(P:GetChildren()) do if L:IsA("Light") then L.Enabled = Night end end
		else
			NightParts[P] = nil
		end
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

local Started = false
function WorldClock.Start()
	if Started then return end
	Started = true
	for _, D in ipairs(workspace:GetDescendants()) do Watch(D) end
	workspace.DescendantAdded:Connect(function(D)
		local Ok, Err = pcall(Watch, D)
		if not Ok then warn("WorldClock:", Err) return end
		if NightParts[D] or NightParts[D.Parent] then Sweep = true end -- a new lamp gets the hour's state next tick
	end)
	workspace.DescendantRemoving:Connect(function(D) NightParts[D] = nil end)
	task.spawn(function()
		while true do
			local Ok, Err = pcall(WorldClock.Tick)
			if not Ok then warn("WorldClock:", Err) end
			task.wait(1)
		end
	end)
end

return WorldClock

-- LightService (2026-10-20, Morality × Reputation spec §17.4; Plan 2, slice S2): Exposure, how lit a player is,
-- 0 (deep shadow) .. 1 (bright light). PerceptionService scales sight by it (x0.2 .. x1.2, Rensei.Perception).
--   * Lamps are parts tagged RenseiLight with attributes LightRadius / LightStrength (0..1). On Start every part
--     in the world holding an enabled PointLight / SpotLight / SurfaceLight (outside characters and rigs) is
--     tagged, with Radius = the light's Range and Strength from its Brightness. A lamp whose light is turned
--     off gives nothing (Plan 5's snuffing / shuttering just disables it).
--   * A lamp lights a point only with a clear line between them (shadow), fading to 0 at its radius.
--   * Daylight (Lighting.ClockTime, Perception.Daylight) counts in full in the open (nothing solid overhead),
--     and IndoorDay of it under a roof.
--   * Every ExposureEvery seconds each player's character gets the attribute Exposure (the eye sigil reads it).
-- Tagged lamps are cached; no engine lighting queries (spec §17.10). Every number is a PROPOSAL.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local P = require(ReplicatedStorage.Modules.Data.Rensei.Perception)

local LightService = {}
LightService.Tag = "RenseiLight"
LightService.ExposureEvery = 0.5
LightService.RoofCheck = 80 -- studs straight up: anything solid there is a roof

local Lamps = {} -- [Part] = true
LightService.Lamps = Lamps

local function LightOf(Part)
	for _, C in ipairs(Part:GetChildren()) do
		if C:IsA("Light") then return C end
	end
	return nil
end

-- inside a character or NPC rig (the StarterCharacter test models carry lights too): not a lamp
local function InRig(Inst)
	local M = Inst:FindFirstAncestorOfClass("Model")
	while M do
		if M:FindFirstChildOfClass("Humanoid") then return true end
		M = M:FindFirstAncestorOfClass("Model")
	end
	return false
end

local function Add(Part)
	if Part:IsA("BasePart") and Part:IsDescendantOf(workspace) then Lamps[Part] = true end
end

-- tags every lamp in the world that isn't tagged yet; returns how many were added
function LightService.TagLamps()
	local N = 0
	for _, L in ipairs(workspace:GetDescendants()) do
		if L:IsA("Light") and L.Parent and L.Parent:IsA("BasePart") and not InRig(L)
			and not CollectionService:HasTag(L.Parent, LightService.Tag) then
			local Part = L.Parent
			if Part:GetAttribute("LightRadius") == nil then Part:SetAttribute("LightRadius", L.Range) end
			if Part:GetAttribute("LightStrength") == nil then
				Part:SetAttribute("LightStrength", math.clamp(L.Brightness, 0.4, 1))
			end
			CollectionService:AddTag(Part, LightService.Tag)
			N += 1
		end
	end
	return N
end

local Rays = RaycastParams.new()
Rays.FilterType = Enum.RaycastFilterType.Exclude
Rays.RespectCanCollide = true

-- 0..1 at a point; Ignore = instances that never block (the character itself)
function LightService.ExposureAt(Point, Ignore)
	local Day = P.Daylight(Lighting.ClockTime)
	Rays.FilterDescendantsInstances = Ignore or {}
	local Roof = workspace:Raycast(Point, Vector3.new(0, LightService.RoofCheck, 0), Rays)
	local Best = Roof and Day * P.IndoorDay or Day
	-- lamps, brightest possible first; the first one in line of sight decides
	local Cands = {}
	for Part in pairs(Lamps) do
		local L = Part.Parent and LightOf(Part)
		if L and L.Enabled then
			local Light = P.LampLight((Part.Position - Point).Magnitude, Part:GetAttribute("LightRadius") or L.Range,
				Part:GetAttribute("LightStrength") or 1)
			if Light > Best then table.insert(Cands, {Part = Part, Light = Light}) end
		end
	end
	table.sort(Cands, function(A, B) return A.Light > B.Light end)
	for _, C in ipairs(Cands) do
		local Skip = table.clone(Ignore or {})
		table.insert(Skip, C.Part)
		Rays.FilterDescendantsInstances = Skip
		-- stop 2 studs short, so the lantern's own frame and glass don't shadow it
		local To = C.Part.Position - Point
		local Len = math.max(0, To.Magnitude - 2)
		if Len <= 0 or not workspace:Raycast(Point, To.Unit * Len, Rays) then
			Best = C.Light
			break
		end
	end
	return math.clamp(Best, 0, 1)
end

function LightService.ExposureOf(Character)
	local Torso = Character and (Character:FindFirstChild("Torso") or Character:FindFirstChild("UpperTorso") or Character:FindFirstChild("HumanoidRootPart"))
	if not Torso then return nil end
	-- players: the value worked out every ExposureEvery seconds; anyone else: now
	local Cached = Players:GetPlayerFromCharacter(Character) and Character:GetAttribute("Exposure")
	if Cached then return Cached end
	return LightService.ExposureAt(Torso.Position, {Character})
end

function LightService.Refresh(Character)
	local Torso = Character and (Character:FindFirstChild("Torso") or Character:FindFirstChild("UpperTorso") or Character:FindFirstChild("HumanoidRootPart"))
	if not Torso then return nil end
	local E = LightService.ExposureAt(Torso.Position, {Character})
	E = math.floor(E * 20 + 0.5) / 20 -- 0.05 steps: no attribute churn
	Character:SetAttribute("Exposure", E)
	return E
end

local Auto = true
function LightService.SetAuto(On) Auto = On end

function LightService.Start()
	LightService.TagLamps()
	for _, Part in ipairs(CollectionService:GetTagged(LightService.Tag)) do Add(Part) end
	CollectionService:GetInstanceAddedSignal(LightService.Tag):Connect(Add)
	CollectionService:GetInstanceRemovedSignal(LightService.Tag):Connect(function(Part) Lamps[Part] = nil end)
	require(ServerScriptService.PerceptionService).ExposureOf = LightService.ExposureOf
	task.spawn(function()
		while true do
			task.wait(LightService.ExposureEvery)
			if Auto then
				for _, Player in ipairs(Players:GetPlayers()) do
					local Ok, Err = pcall(LightService.Refresh, Player.Character)
					if not Ok then warn("LightService:", Err) end
				end
			end
		end
	end)
end

return LightService

-- PositionHistory (gun rework 2026-10-25): the last KEEP seconds of every live character's root CFrame, so a player's shot is
-- tested where its shooter saw the target (lag compensation, capped by TuningConfig.Weapons.Guns.Aim.MaxRewind). PROPOSAL.
-- The characters are GunAim.Candidates -- the same list WeaponManager.ShotTarget tests -- kept as a cached list of
-- {Model, Root} (Ruling 14: walking World.Live every sample cost ~0.2 ms). Live.DescendantAdded / DescendantRemoving of
-- a Model, Humanoid or Folder only marks the list dirty (Removing fires before the instance leaves, so it is never
-- rebuilt inside the handler); the next Sample rebuilds it, and it is rebuilt at least every REBUILD seconds anyway.
-- A rebuild drops the history of anything no longer a candidate, so Samples never outgrows the candidates.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GunAim = require(ReplicatedStorage.Modules.Data.Rensei.GunAim)
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)

local PositionHistory = {}
-- seconds kept: twice the deepest rewind (Aim.MaxRewind), so a capped rewind always lands inside the history with
-- room to spare for a late or skipped sample
local KEEP = 2 * Tuning.Weapons.Guns.Aim.MaxRewind
local STEP = 1 / 30 -- PROPOSAL: seconds between samples (30 a second)
local REBUILD = 1 -- PROPOSAL: seconds; the cached candidates are rebuilt at least this often
local Samples = {} -- [Model] = {{T, CF}, ...} oldest first
local Started = false

local Cached = {} -- {{Model = M, Root = HumanoidRootPart or nil}, ...}: GunAim.Candidates(Live) at the last rebuild
local Dirty = true
local BuiltAt = -math.huge
local Watched = nil -- the World.Live the connections below watch
local Watching = {}

local function Mark(D)
	if D:IsA("Model") or D:IsA("Humanoid") or D:IsA("Folder") then Dirty = true end
end

local function Watch(Live)
	if Watched == Live then return end
	for _, C in ipairs(Watching) do C:Disconnect() end
	table.clear(Watching)
	Watched = Live
	Dirty = true
	if Live then
		table.insert(Watching, Live.DescendantAdded:Connect(Mark))
		table.insert(Watching, Live.DescendantRemoving:Connect(Mark))
	end
end

local function Rebuild(Live, Now)
	table.clear(Cached)
	local Keep = {}
	for _, M in ipairs(Live and GunAim.Candidates(Live) or {}) do
		Keep[M] = true
		table.insert(Cached, {Model = M, Root = M:FindFirstChild("HumanoidRootPart")})
	end
	for M in pairs(Samples) do
		if not Keep[M] then Samples[M] = nil end
	end
	Dirty = false
	BuiltAt = Now
end

function PositionHistory.Sample(Now)
	local World = workspace:FindFirstChild("World")
	local Live = World and World:FindFirstChild("Live")
	Watch(Live)
	if Dirty or Now - BuiltAt >= REBUILD then Rebuild(Live, Now) end
	for _, E in ipairs(Cached) do
		local M = E.Model
		if M.Parent then
			local Root = E.Root
			if not Root or Root.Parent ~= M then
				Root = M:FindFirstChild("HumanoidRootPart")
				E.Root = Root
			end
			if Root then
				local H = Samples[M]
				if not H then
					H = {}
					Samples[M] = H
				end
				table.insert(H, {T = Now, CF = Root.CFrame})
				while #H > 1 and Now - H[1].T > KEEP do table.remove(H, 1) end
			end
		end
	end
end

-- Where Model's root was at server time At: nil when At is nil or Model has no history yet. When At is newer than the
-- newest sample and LiveCF (the root's CFrame now) and Now are given, the live root is the newest sample (Ruling 16):
-- a lerp from the last sample toward {T = Now, CF = LiveCF}, clamped at Now. Otherwise GunAim.Rewind over the samples.
function PositionHistory.At(Model, At, LiveCF, Now)
	if At == nil then return nil end
	local H = Samples[Model]
	if not H or #H == 0 then return nil end
	local Last = H[#H]
	if LiveCF and Now and At > Last.T then
		if Now <= Last.T then return LiveCF end
		return Last.CF:Lerp(LiveCF, math.clamp((At - Last.T) / (Now - Last.T), 0, 1))
	end
	return GunAim.Rewind(H, At)
end

function PositionHistory.Start()
	if Started then return end
	Started = true
	local Last = -math.huge
	RunService.Heartbeat:Connect(function()
		local Now = workspace:GetServerTimeNow()
		if Now - Last >= STEP then
			Last += STEP -- a steady 30 a second, not "a frame after each STEP"
			if Now - Last > STEP * 2 then Last = Now end -- catch up after a stall (and at the start)
			PositionHistory.Sample(Now)
		end
	end)
end

return PositionHistory

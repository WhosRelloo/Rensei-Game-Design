-- PositionHistory (gun rework 2026-10-25): the last KEEP seconds of every live character's root CFrame, so a player's shot is
-- tested where its shooter saw the target (lag compensation, capped by TuningConfig.Weapons.Guns.Aim.MaxRewind). PROPOSAL.
-- The characters are GunAim.Candidates -- the same list WeaponManager.ShotTarget tests -- kept as a cached list of
-- {Model, Root} (Ruling 14: walking World.Live every sample cost ~0.2 ms). A Live.DescendantAdded / DescendantRemoving
-- that can change the candidates (Mark, below) only marks the list dirty (it is never rebuilt inside the handler); the
-- next Sample rebuilds it, and it is rebuilt at least every REBUILD seconds anyway.
-- A rebuild drops the history of anything no longer a candidate, so Samples never outgrows the candidates.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GunAim = require(ReplicatedStorage.Modules.Data.Rensei.GunAim)
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)

local PositionHistory = {}
-- seconds kept: twice the deepest rewind (Aim.MaxRewind), so a capped rewind always lands inside the history with
-- room to spare for a late or skipped sample
local KEEP = 2 * Tuning.Weapons.Guns.Aim.MaxRewind
-- PROPOSAL (Ruling 21): seconds between samples, 20 a second (was 30; 30 cost ~0.28 ms/frame at 58 characters in
-- Studio). With the live root as the newest sample (At), sample age no longer matters for NPC or near-now shots, and a
-- player's rewind interpolates across the 50 ms gaps.
local STEP = 1 / 20
local REBUILD = 1 -- PROPOSAL: seconds; the cached candidates are rebuilt at least this often
local Samples = {} -- [Model] = {{T, CF}, ...} oldest first
local Started = false

local Cached = {} -- {{Model = M, Root = HumanoidRootPart or nil}, ...}: GunAim.Candidates(Live) at the last rebuild
local IsCached = {} -- [Model] = true for the Models in Cached
local Dirty = true
local BuiltAt = -math.huge
local Watched = nil -- the World.Live the connections below watch
local Watching = {}

local Marks = 0 -- times Mark set Dirty (a test seam: PositionHistory.DirtyMarks)

-- Only an add / remove that can change GunAim.Candidates marks the list dirty (gun rework final fix A7): a Model or
-- Folder whose Parent is Live, a Model in a Folder in Live, or a Humanoid directly inside one of those Models -- and a
-- cached candidate itself (a removal's signal is deferred, so it may come after the Model has left: no Parent to read).
-- A Tool given to a character (its Models), effects parented inside a character and the like don't.
local function Level(M) -- 1: a child of Live; 2: a child of a Folder in Live; nil: anything deeper
	local P = M.Parent
	if P == Watched then return 1 end
	if P and P:IsA("Folder") and P.Parent == Watched then return 2 end
	return nil
end

local function Mark(D)
	local Counts
	if D:IsA("Model") then
		Counts = IsCached[D] or Level(D) ~= nil
	elseif D:IsA("Folder") then
		Counts = D.Parent == Watched
	elseif D:IsA("Humanoid") then
		local M = D.Parent
		Counts = M ~= nil and M:IsA("Model") and (IsCached[M] or Level(M) ~= nil)
	end
	if Counts then
		Dirty = true
		Marks += 1
	end
end

-- how many adds / removes under World.Live have marked the cached candidates dirty so far (Play_Guns' MarkIgnoresTools)
function PositionHistory.DirtyMarks()
	return Marks
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
	table.clear(IsCached)
	for _, M in ipairs(Live and GunAim.Candidates(Live) or {}) do
		IsCached[M] = true
		table.insert(Cached, {Model = M, Root = M:FindFirstChild("HumanoidRootPart")})
	end
	for M in pairs(Samples) do
		if not IsCached[M] then Samples[M] = nil end
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
			Last += STEP -- a steady 20 a second, not "a frame after each STEP"
			if Now - Last > STEP * 2 then Last = Now end -- catch up after a stall (and at the start)
			PositionHistory.Sample(Now)
		end
	end)
end

return PositionHistory

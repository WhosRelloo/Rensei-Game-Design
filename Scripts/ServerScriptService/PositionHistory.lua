-- PositionHistory (gun rework 2026-10-25): the last KEEP seconds of every live character's root CFrame, so a player's shot is
-- tested where its shooter saw the target (lag compensation, capped by TuningConfig.Weapons.Guns.Aim.MaxRewind). PROPOSAL.
-- The characters are GunAim.Candidates -- the same list WeaponManager.ShotTarget tests.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GunAim = require(ReplicatedStorage.Modules.Data.Rensei.GunAim)

local PositionHistory = {}
local KEEP = 0.5 -- seconds kept (PROPOSAL: twice MaxRewind)
local STEP = 1 / 30 -- seconds between samples
local Samples = {} -- [Model] = {{T, CF}, ...} oldest first
local Started = false

function PositionHistory.Sample(Now)
	local World = workspace:FindFirstChild("World")
	local Live = World and World:FindFirstChild("Live")
	if Live then
		for _, M in ipairs(GunAim.Candidates(Live)) do
			local Root = M:FindFirstChild("HumanoidRootPart")
			if Root then
				local H = Samples[M]
				if not H then
					H = {}
					Samples[M] = H
					M.Destroying:Once(function() Samples[M] = nil end)
				end
				table.insert(H, {T = Now, CF = Root.CFrame})
				while #H > 1 and Now - H[1].T > KEEP do table.remove(H, 1) end
			end
		end
	end
	for M in pairs(Samples) do
		if not M.Parent then Samples[M] = nil end
	end
end

-- Where Model's root was at server time At (nil when it has no history yet).
function PositionHistory.At(Model, At)
	local H = Samples[Model]
	return H and GunAim.Rewind(H, At) or nil
end

function PositionHistory.Start()
	if Started then return end
	Started = true
	local Last = 0
	RunService.Heartbeat:Connect(function()
		local Now = workspace:GetServerTimeNow()
		if Now - Last >= STEP then
			Last = Now
			PositionHistory.Sample(Now)
		end
	end)
end

return PositionHistory

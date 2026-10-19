-- LocomotionSync (2026-10-18 speed audit): the local character's walk / run animations play at the rate
-- that matches how fast the character is really moving, relative to each animation's design speed
-- (TuningConfig.Locomotion). Without it every locomotion animation played at a fixed rate: a +25% Speed
-- stat slid the feet, hitstun at 4 studs/s ran in place, the greatsword's slower gait didn't slow down.
-- Client only; track speed replicates to other players with the animation. Climbing, swimming and
-- ledge walking keep their own speed matching (JumpManager, SwimClient, LedgeWalk).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)

local LocomotionSync = {}

local Cfg = Tuning.Locomotion
local Rates = {} -- [AnimationTrack] = the rate it was last set to (smoothed)

-- the design speed of a playing track: by its Animation's name (AnimationManager / Animate use the
-- Animation instance's name), or by id for the Animate script's walk (its Animation is "WalkAnim")
local ById = {}
for _, A in ipairs(ReplicatedStorage.Assets.Animations:GetDescendants()) do
	if A:IsA("Animation") and Cfg.Design[A.Name] and A.AnimationId ~= "" then ById[A.AnimationId] = Cfg.Design[A.Name] end
end
local function DesignOf(Track)
	local A = Track.Animation
	return A and (Cfg.Design[A.Name] or ById[A.AnimationId])
end

function LocomotionSync.Start()
	RunService.RenderStepped:Connect(function(Dt)
		local Character = Players.LocalPlayer.Character
		local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
		local Root = Character and Character:FindFirstChild("HumanoidRootPart")
		local Animator = Humanoid and Humanoid:FindFirstChildOfClass("Animator")
		if not Animator or not Root then return end
		local V = Root.AssemblyLinearVelocity
		local Speed = Vector3.new(V.X, 0, V.Z).Magnitude
		for _, Track in ipairs(Animator:GetPlayingAnimationTracks()) do
			local Design = DesignOf(Track)
			-- (standing still: leave it; the walk stops on its own a moment later)
			if Design and Speed > 0.5 then
				local Want = math.clamp(Speed / Design, Cfg.Min, Cfg.Max)
				local Rate = Rates[Track] or Track.Speed
				Rate += (Want - Rate) * math.min(1, Dt * 10)
				Rates[Track] = Rate
				if math.abs(Track.Speed - Rate) > 0.01 then Track:AdjustSpeed(Rate) end
			end
		end
		-- forget finished tracks
		for Track in pairs(Rates) do
			if not Track.IsPlaying then Rates[Track] = nil end
		end
	end)
end

return LocomotionSync

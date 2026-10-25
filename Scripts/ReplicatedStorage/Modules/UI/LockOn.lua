-- Lock Target: press the Lock Target key to lock onto the nearest enemy in front of you; press
-- again (or let it die / leave range) to release.
-- While locked the camera sits over the player's right shoulder, raised so the target reads above
-- the character, and eases into place. A raycast pulls it in front of walls.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local ACQUIRE_RANGE = 60
local BREAK_RANGE = 80

-- Camera framing (studs). Tune here.
local CAMERA = {
	Distance = 10, -- behind the player
	Height = 4.6, -- above the HumanoidRootPart
	Shoulder = 3.2, -- to the player's right
	LookHeight = 1.2, -- aim point above the target's root
	Smoothing = 14, -- higher = snappier
}

local LockOn = {}
LockOn.Target = nil

local function Candidates()
	local Root = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
	local Live = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Live")
	if not Root or not Live then return end
	local Best, BestScore = nil, math.huge
	local Look = Camera.CFrame.LookVector
	for _, Model in ipairs(Live:GetChildren()) do
		local Humanoid = Model:IsA("Model") and Model:FindFirstChildOfClass("Humanoid")
		local MRoot = Humanoid and Model:FindFirstChild("HumanoidRootPart")
		if MRoot and Model ~= Player.Character and Humanoid.Health > 0 then
			local Offset = MRoot.Position - Root.Position
			local Dist = Offset.Magnitude
			if Dist <= ACQUIRE_RANGE then
				-- prefer what the camera is pointing at, then distance
				local Facing = Offset.Unit:Dot(Look)
				local Score = Dist * (1.6 - Facing)
				if Score < BestScore then Best, BestScore = Model, Score end
			end
		end
	end
	return Best
end

local function Release()
	LockOn.Target = nil
	RunService:UnbindFromRenderStep("RenseiLockOn")
	local Humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
	if Humanoid then Humanoid.AutoRotate = true end
	Camera.CameraType = Enum.CameraType.Custom
end

local Params = RaycastParams.new()
Params.FilterType = Enum.RaycastFilterType.Exclude

function LockOn.Toggle()
	if LockOn.Target then Release() return end
	local Target = Candidates()
	if not Target then return end
	LockOn.Target = Target
	Camera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep("RenseiLockOn", Enum.RenderPriority.Camera.Value + 1, function(Dt)
		local Character = Player.Character
		local Root = Character and Character:FindFirstChild("HumanoidRootPart")
		local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
		local T = LockOn.Target
		local TRoot = T and T.Parent and T:FindFirstChild("HumanoidRootPart")
		local THum = T and T:FindFirstChildOfClass("Humanoid")
		if not Root or not Humanoid or not TRoot or not THum or THum.Health <= 0
			or (TRoot.Position - Root.Position).Magnitude > BREAK_RANGE then
			Release()
			return
		end

		-- Face the target (yaw only).
		Humanoid.AutoRotate = false
		local Flat = Vector3.new(TRoot.Position.X, Root.Position.Y, TRoot.Position.Z)
		if (Flat - Root.Position).Magnitude > 0.5 then
			Root.CFrame = CFrame.lookAt(Root.Position, Flat)
		end

		-- Over-the-shoulder rig: behind the player along the player->target line.
		local Toward = Flat - Root.Position
		Toward = Toward.Magnitude > 0.01 and Toward.Unit or Root.CFrame.LookVector
		local Basis = CFrame.lookAt(Root.Position, Root.Position + Toward)
		local Pivot = Root.Position + Vector3.new(0, CAMERA.Height, 0)
		local Desired = Pivot - Toward * CAMERA.Distance + Basis.RightVector * CAMERA.Shoulder

		-- Keep the camera in front of walls between the pivot and the desired spot.
		Params.FilterDescendantsInstances = {Character, T}
		local Hit = workspace:Raycast(Pivot, Desired - Pivot, Params)
		if Hit then
			Desired = Hit.Position + (Pivot - Hit.Position).Unit * 0.6
		end

		local Goal = CFrame.lookAt(Desired, TRoot.Position + Vector3.new(0, CAMERA.LookHeight, 0))
		local Alpha = 1 - math.exp(-CAMERA.Smoothing * Dt)
		Camera.CFrame = Camera.CFrame:Lerp(Goal, Alpha)
	end)
end

LockOn.Release = Release
LockOn.Camera = CAMERA
return LockOn

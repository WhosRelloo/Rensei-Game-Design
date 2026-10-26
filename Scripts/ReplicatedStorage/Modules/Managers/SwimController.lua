-- SwimController (swim revamp Task 5, 2026-10-26; Documents/specs/2026-10-25-swimming-revamp-design.md, all PROPOSAL):
-- the CLIENT movement of a swimmer. StarterPlayerScripts.SwimClient starts it while the server's Swim state is on (or
-- the humanoid swims) and feeds it Input; the maths is Rensei.SwimLogic. It replaces Roblox's own swim steering:
--   * Surface: W A S D are level, relative to the camera's yaw; the controller holds you at the surface (looking down
--     never pulls you under).
--   * Under (after a dive): W swims where the camera looks (pitch included, clamped to MaxPitch); A / D strafe level;
--     Space rises, Ctrl sinks; with no input you drift up slowly. The body turns to the swim direction and pitches.
--   * Dive(): from the surface, where the water is at least DiveMinDepth deep: a DiveTime push down at DiveSpeed.
--   * ClimbOut(): from the surface, facing a ledge at most ClimbOutHeight above the water within ClimbOutReach: the
--     ledge climb (Vault1 / Vault2, JumpManager's pull-up) and an up-and-forward push.
--   * Hop(): the old swim hop (Humanoid.Jump), with the controller let go for a moment.
-- How it moves you: a LinearVelocity and an AlignOrientation on the root's own attachment, SwimAttachment, so a
-- knockback's MoverManager.ClearMovers (VelocityAttachment) can't delete them. Their force is finite (MaxForce), and
-- they let go (force 0) while you're stunned, dashing, or while any MoverManager mover is on VelocityAttachment, so a
-- hit in the water still throws you. Your client owns your character, so the pitch and the animations replicate.
-- The server keeps every rule (SwimService): the Swim state, Submerged, breath, drowning, SwimSprint and its stamina.
-- SwimController.TestMove (a Vector3) replaces the control module's move vector while set: TESTS ONLY
-- (Art/Studio/Swim/client_checks.lua).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SwimLogic = require(ReplicatedStorage.Modules.Data.Rensei.SwimLogic)
local T = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig).Swim
local AnimationManager = require(ReplicatedStorage.Modules.Managers.AnimationManager)

local Player = Players.LocalPlayer
local DefaultWS = game:GetService("StarterPlayer"):FindFirstChild("StarterCharacter")
	and game.StarterPlayer.StarterCharacter:FindFirstChildOfClass("Humanoid")
	and game.StarterPlayer.StarterCharacter.Humanoid.WalkSpeed or 16

local SwimController = {
	Mode = nil, -- nil (not started), "Surface" or "Under"
	Input = {Up = false, Down = false, Sprint = false}, -- set by SwimClient each frame
	TestMove = nil, -- tests only
}

local State = nil -- {Character, Humanoid, Root, Head, Att, LV, AO, Conn, DiveUntil, PauseUntil, Surface}

local Controls = nil
local function MoveVector(Humanoid)
	if SwimController.TestMove then return SwimController.TestMove end
	if Controls == nil then
		local Ok, C = pcall(function()
			return require(Player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)):GetControls()
		end)
		Controls = Ok and C or false
	end
	if Controls then
		local Ok, V = pcall(function() return Controls:GetMoveVector() end)
		if Ok and V then return V end
	end
	-- fallback: the humanoid's world move direction, in camera space
	local CF = workspace.CurrentCamera.CFrame
	local F = Vector3.new(CF.LookVector.X, 0, CF.LookVector.Z)
	F = F.Magnitude > 1e-4 and F.Unit or Vector3.new(0, 0, -1)
	local R = Vector3.new(-F.Z, 0, F.X)
	local MD = Humanoid.MoveDirection
	return Vector3.new(MD:Dot(R), 0, -MD:Dot(F))
end

-- the water's surface Y over a point (the first terrain hit of a ray down from 20 studs above it, when it is Water)
local SurfRay = RaycastParams.new()
SurfRay.FilterType = Enum.RaycastFilterType.Include
SurfRay.IgnoreWater = false
local function SurfaceY(At)
	SurfRay.FilterDescendantsInstances = {workspace.Terrain}
	local Hit = workspace:Raycast(At + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), SurfRay)
	return Hit and Hit.Material == Enum.Material.Water and Hit.Position.Y or nil
end

-- the map and the terrain, water ignored (beds and ledges)
local SolidRay = RaycastParams.new()
SolidRay.FilterType = Enum.RaycastFilterType.Include
SolidRay.IgnoreWater = true
local function Solids()
	local World = workspace:FindFirstChild("World")
	local Map = World and World:FindFirstChild("Map")
	SolidRay.FilterDescendantsInstances = Map and {Map, workspace.Terrain} or {workspace.Terrain}
	return SolidRay
end

local function Stunned(Character)
	local Ok, Yes = pcall(function()
		local WCS = require(ReplicatedStorage.Modules.Framework.WCS)
		local Stun = require(ReplicatedStorage.Modules.Skills.States.Stun)
		local CS = WCS.Character.GetCharacterFromInstance(Character)
		return CS ~= nil and CS:HasStatusEffects({Stun})
	end)
	return Ok and Yes == true
end

-- a MoverManager mover (knockback, lunge, the climb-out push) is driving the root
local function Moved(Root)
	local VA = Root:FindFirstChild("VelocityAttachment")
	if not VA then return false end
	for _, M in ipairs(VA:GetChildren()) do
		if M:IsA("LinearVelocity") or M:IsA("AlignPosition") then return true end
	end
	return false
end

local function Once(Character, Name, Fade)
	if Name and AnimationManager.Has(Character, Name) then
		AnimationManager.Play(Character, Name, {Priority = Enum.AnimationPriority.Action, Fade = Fade})
		return true
	end
	return false
end

local function Speed(Character)
	return DefaultWS * (Character:GetAttribute("SpeedMultiplier") or 1)
end

local function Facing(Root)
	local L = Root.CFrame.LookVector
	local F = Vector3.new(L.X, 0, L.Z)
	if F.Magnitude < 1e-3 then
		local C = workspace.CurrentCamera.CFrame.LookVector
		F = Vector3.new(C.X, 0, C.Z)
	end
	return F.Magnitude > 1e-3 and F.Unit or Vector3.new(0, 0, -1)
end

local function Step()
	local S = State
	if not S or not S.Character.Parent or not S.Root.Parent or S.Humanoid.Health <= 0 then
		SwimController.Stop()
		return
	end
	local Now = os.clock()
	local Surf = SurfaceY(S.Root.Position)
	S.Surface = Surf
	local Hold = Surf == nil or Now < (S.PauseUntil or 0) or Stunned(S.Character) or S.Character:GetAttribute("Dashing")
		or Moved(S.Root)
	if Hold then
		S.LV.MaxForce = 0
		S.AO.Enabled = false
		if Surf == nil or SwimController.Mode ~= "Under" then S.Humanoid.AutoRotate = true end
		return
	end
	-- the mode: a dive keeps you Under until it ends; the head breaking the surface brings you back
	local HeadDepth = Surf - S.Head.Position.Y
	local Was = SwimController.Mode
	local Diving = Now < (S.DiveUntil or 0)
	SwimController.Mode = Diving and "Under" or SwimLogic.ModeFor(Was, HeadDepth, T)
	if Was == "Under" and SwimController.Mode == "Surface" then Once(S.Character, T.AnimSurface) end

	local Move = MoveVector(S.Humanoid)
	local Input = SwimController.Input
	local V
	if Diving then
		local F = Facing(S.Root)
		local A = math.rad(60)
		V = (F * math.cos(A) - Vector3.new(0, math.sin(A), 0)) * T.DiveSpeed
	else
		V = SwimLogic.Velocity(SwimController.Mode, Move, workspace.CurrentCamera.CFrame, Input, Speed(S.Character), T)
		if SwimController.Mode == "Surface" then
			V = Vector3.new(V.X, SwimLogic.SurfaceHold(S.Root.Position.Y, Surf, T), V.Z)
		end
	end
	S.LV.VectorVelocity = V
	S.LV.MaxForce = T.MaxForce

	if SwimController.Mode == "Under" then
		-- the body turns to the swim direction and pitches into it (level while idle or only drifting)
		S.Humanoid.AutoRotate = false
		local Flat = Vector3.new(V.X, 0, V.Z)
		local Yaw = Flat.Magnitude > 0.5 and Flat.Unit or Facing(S.Root)
		local Steering = Diving or Move.Magnitude >= T.MoveThreshold or Input.Up or Input.Down
		local Pitch = Steering and SwimLogic.Pitch(V, T) or 0
		S.AO.CFrame = CFrame.lookAt(Vector3.zero, Yaw) * CFrame.Angles(Pitch, 0, 0)
		S.AO.Enabled = true
	else
		S.AO.Enabled = false
		S.Humanoid.AutoRotate = true
	end
end

function SwimController.Start(Character)
	if State and State.Character == Character then return end
	SwimController.Stop()
	local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
	local Root = Character and Character:FindFirstChild("HumanoidRootPart")
	local Head = Character and Character:FindFirstChild("Head")
	if not (Humanoid and Root and Head) then return end
	local Att = Instance.new("Attachment")
	Att.Name = "SwimAttachment"
	Att.Parent = Root
	local LV = Instance.new("LinearVelocity")
	LV.Name = "SwimVelocity"
	LV.Attachment0 = Att
	LV.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	LV.RelativeTo = Enum.ActuatorRelativeTo.World
	LV.MaxForce = 0
	LV.VectorVelocity = Vector3.zero
	LV.Parent = Att
	local AO = Instance.new("AlignOrientation")
	AO.Name = "SwimAlign"
	AO.Mode = Enum.OrientationAlignmentMode.OneAttachment
	AO.Attachment0 = Att
	AO.Responsiveness = T.TurnResponsiveness
	AO.MaxTorque = 1e6
	AO.Enabled = false
	AO.Parent = Att
	SwimController.Mode = "Surface"
	State = {Character = Character, Humanoid = Humanoid, Root = Root, Head = Head, Att = Att, LV = LV, AO = AO}
	State.Conn = RunService.RenderStepped:Connect(Step)
end

function SwimController.Stop()
	local S = State
	State = nil
	SwimController.Mode = nil
	if not S then return end
	if S.Conn then S.Conn:Disconnect() end
	if S.Att then S.Att:Destroy() end
	if S.Humanoid and S.Humanoid.Parent then S.Humanoid.AutoRotate = true end
end

-- true while swimming under water (SettingsUI's shift lock leaves the facing to the controller then)
function SwimController.Active()
	return SwimController.Mode == "Under"
end

-- the water's depth under the swimmer (surface to bed), or 0
function SwimController.Depth()
	local S = State
	if not S then return 0 end
	local Surf = SurfaceY(S.Root.Position)
	if not Surf then return 0 end
	local Bed = workspace:Raycast(Vector3.new(S.Root.Position.X, Surf, S.Root.Position.Z), Vector3.new(0, -60, 0), Solids())
	return Bed and Surf - Bed.Position.Y or 60
end

function SwimController.Dive()
	local S = State
	if not S or SwimController.Mode ~= "Surface" or os.clock() < (S.PauseUntil or 0) then return false end
	if not SwimLogic.CanDive(SwimController.Depth(), T) then return false end
	SwimController.Mode = "Under"
	S.DiveUntil = os.clock() + T.DiveTime
	Once(S.Character, T.AnimDive, 0.1)
	return true
end

function SwimController.ClimbOut()
	local S = State
	if not S or SwimController.Mode ~= "Surface" then return false end
	local Surf = S.Surface or SurfaceY(S.Root.Position)
	if not Surf then return false end
	local F = Facing(S.Root)
	local From = Vector3.new(S.Head.Position.X, Surf + 0.2, S.Head.Position.Z)
	local Wall = workspace:Raycast(From, F * T.ClimbOutReach, Solids())
	if not Wall then return false end
	local Dist = (Vector3.new(Wall.Position.X, 0, Wall.Position.Z) - Vector3.new(From.X, 0, From.Z)).Magnitude
	local Probe = Wall.Position + F * 1 + Vector3.new(0, T.ClimbOutHeight + 1, 0)
	local Top = workspace:Raycast(Probe, Vector3.new(0, -(T.ClimbOutHeight + 2), 0), Solids())
	if not Top or Top.Normal.Y < 0.6 then return false end
	if not SwimLogic.CanClimbOut(Top.Position.Y - Surf, Dist, T) then return false end
	S.PauseUntil = os.clock() + 0.4
	S.LV.MaxForce = 0
	S.AO.Enabled = false
	local MoverManager = require(ReplicatedStorage.Modules.Managers.MoverManager)
	MoverManager.Velocity(S.Character, {D = 0.2, V = F * T.ClimbOutForward + Vector3.new(0, T.ClimbOutUp, 0),
		Max = Vector3.new(4e4, 4e4, 4e4)})
	-- the ledge climb: Vault1 or Vault2 (JumpManager's pull-up), at JumpManager's priority
	local Name = T.AnimClimbOut == "Vault1" and ("Vault" .. math.random(1, 2)) or T.AnimClimbOut
	if AnimationManager.Has(S.Character, Name) then
		AnimationManager.Play(S.Character, Name, {Priority = Enum.AnimationPriority.Action4})
	end
	return true
end

-- the old swim hop out of the water at a low lip: let the controller go for a moment and jump
function SwimController.Hop()
	local S = State
	if not S or SwimController.Mode ~= "Surface" then return false end
	S.PauseUntil = os.clock() + 0.35
	S.Humanoid.Jump = true
	return true
end

return SwimController

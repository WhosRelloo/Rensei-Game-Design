-- Ragdoll (assassinations Task 6b, owner 2026-10-27: "When people are dead, make them ragdoll so it's easier to spot a
-- body, looks smoother", "by dead I mean after they get gripped"): the body of anyone a finished Grip (B) kills goes limp.
-- DownedManager.Grip calls Ragdoll.Apply just before it sets Health to 0; the assassinations' assassinate kill (Task 7)
-- calls the same. Every other death is unchanged: an NPC killed by a hit, a fall or drowning still lies whole
-- (BreakJointsOnDeath = false, EnemyService / TownsfolkService).
--
-- SERVER: Ragdoll.Apply(Model) -> true the first time, false after (idempotent) or for a model with no Humanoid / root.
--   * Each Motor6D between two of the rig's body parts (the R6 limbs, head and torso: BaseParts directly in the model),
--     except the RootJoint, is disabled (kept, not destroyed) and replaced by a BallSocketConstraint between two
--     Attachments at the joint's C0 / C1 points, limits on (Ragdoll.Joints, all PROPOSAL). A weapon's or an accessory's
--     own Motor6D (its part is not a body part) stays as it is, so a held sword doesn't flop.
--   * The RootJoint stays, so HumanoidRootPart follows the torso. The root doesn't collide; the head, torso and limbs do,
--     with a NoCollisionConstraint between every two of them so the body's own parts never fight each other (the
--     parts keep their collision group). Nothing stays anchored (test rigs anchor their root).
--   * The Humanoid: BreakJointsOnDeath and RequiresNeck off (a player's would otherwise break apart / die on the neck),
--     PlatformStand on, AutoRotate off, the Physics state while it is still alive; every playing animation track
--     stopped (the Animator's and AnimationManager's).
--   * Physics owner: an NPC's parts the server's (everyone sees the same fall). A player's character keeps its own
--     client, whose ClientHandler hook (Ragdoll.Watch) puts its Humanoid in Physics too.
--   * Settling: after Ragdoll.Settle seconds, once the body is nearly still (it keeps checking), its root, torso, head
--     and limbs are anchored where they lie (attribute RagdollSettled): a settled body costs nothing, never jitters and
--     can't be shoved. A carried body is never settled.
--   * Attribute Ragdolled = true on the model.
-- SERVER: Ragdoll.Hold(Model, On, Owner): a carry of a ragdolled body (DownedManager.Carry / Drop). On, BEFORE the
--   carry's weld: unanchored, its parts not colliding (the limbs hang from the carrier without shoving it), settling
--   stopped, and Owner (the carrier's Player, or nil = the server) owns every part. Off, after the set-down: colliding
--   again, PlatformStand back on (Detach turned it off), the body's own owner back, and settling starts again.
-- CLIENT: Ragdoll.Watch(Model): the client's hook for its own character (ClientHandler, every CharacterAdded). When the
--   server marks the model Ragdolled, this client (its physics owner) puts its Humanoid in Physics with PlatformStand,
--   so the Humanoid doesn't fight the joints, and stops the animation tracks it plays. Ragdoll.IsWatched(Model) for the
--   client check.
-- Nothing here is a respawn, a death penalty or a save: a ragdolled player respawns as before, and a knocked (downed)
-- player is not dead and doesn't ragdoll.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Ragdoll = {}

Ragdoll.Settle = 4 -- PROPOSAL: seconds after the fall before a still body is anchored where it lies
Ragdoll.SettleCheck = 0.25 -- PROPOSAL: how often a body that is still moving is looked at again
Ragdoll.StillSpeed = 0.6 -- PROPOSAL: studs/s; every part slower than this ...
Ragdoll.StillSpin = 1.5 -- PROPOSAL: ... and turning slower than this (rad/s) is "nearly still"
Ragdoll.Friction = 1.5 -- PROPOSAL: each ball socket's MaxFrictionTorque, so limbs swing out and stop instead of flailing

-- The joint limits (all PROPOSAL, degrees), for an R6 rig as it stands: Axis is the centre of the limb's cone, in the
-- torso's space (the torso faces -Z, its right is +X); the limb hangs straight along its own -Y (the head stands along
-- +Y), so at rest it sits Axis's tilt off that centre. Cone is the widest angle from the centre; Twist (lower, upper) the
-- turn about the limb's own length. The hips' centre leans forward 31 degrees with a 50 degree cone: a leg swings 81
-- forward but only 19 back, so it never folds backwards. The shoulders' centre leans 19 degrees outward with 70: 89 out,
-- 51 in. The neck: 35 any way, 50 of twist.
Ragdoll.Joints = {
	Neck = {Axis = Vector3.new(0, 1, 0), Limb = Vector3.new(0, 1, 0), Cone = 35, Twist = {-50, 50}},
	["Right Shoulder"] = {Axis = Vector3.new(0.35, -1, 0).Unit, Cone = 70, Twist = {-60, 60}},
	["Left Shoulder"] = {Axis = Vector3.new(-0.35, -1, 0).Unit, Cone = 70, Twist = {-60, 60}},
	["Right Hip"] = {Axis = Vector3.new(0, -1, -0.6).Unit, Cone = 50},
	["Left Hip"] = {Axis = Vector3.new(0, -1, -0.6).Unit, Cone = 50},
}
-- any other joint between two body parts (not an R6 joint): hangs down, 45 any way, 30 of twist (PROPOSAL)
Ragdoll.Default = {Axis = Vector3.new(0, -1, 0), Cone = 45, Twist = {-30, 30}}

local DOWN = Vector3.new(0, -1, 0)
local FORWARD = Vector3.new(0, 0, -1)

local function Hum(Model) return Model:FindFirstChildOfClass("Humanoid") end

-- the rig's body parts: the BaseParts directly in the model (R6: Head, Torso, the arms and legs, HumanoidRootPart)
local function BodyParts(Model)
	local Out = {}
	for _, P in ipairs(Model:GetChildren()) do
		if P:IsA("BasePart") then table.insert(Out, P) end
	end
	return Out
end

-- an Attachment at Pos in Part's space whose primary axis (Attachment.Axis, its X) is Axis and whose secondary (its Y)
-- is the part's forward made square to it, so two attachments built from the same rest pose line up
local function Socket(Part, Pos, Axis)
	local Second = FORWARD - Axis * FORWARD:Dot(Axis)
	if Second.Magnitude < 1e-3 then Second = Vector3.new(1, 0, 0) - Axis * Axis.X end
	local A = Instance.new("Attachment")
	A.Name = "RagdollSocket"
	A.CFrame = CFrame.fromMatrix(Pos, Axis, Second.Unit)
	A.Parent = Part
	return A
end

local function StopTracks(Model)
	local H = Hum(Model)
	local Animator = H and H:FindFirstChildOfClass("Animator")
	if Animator then
		for _, Track in ipairs(Animator:GetPlayingAnimationTracks()) do pcall(function() Track:Stop(0) end) end
	end
	-- (AnimationManager's own bookkeeping too; required here, lazily: it requires DownedManager, which requires this)
	pcall(function()
		require(game:GetService("ReplicatedStorage").Modules.Managers.AnimationManager).StopAllAnims(Model)
	end)
end

if not RunService:IsServer() then
	-- ===== client =====
	local Watched = setmetatable({}, {__mode = "k"}) -- [Model] = true

	local function Limp(Model)
		local H = Hum(Model)
		if not H then return end
		H.PlatformStand = true
		H.AutoRotate = false
		if H:GetState() ~= Enum.HumanoidStateType.Dead then H:ChangeState(Enum.HumanoidStateType.Physics) end
		local Animator = H:FindFirstChildOfClass("Animator")
		if Animator then
			for _, Track in ipairs(Animator:GetPlayingAnimationTracks()) do pcall(function() Track:Stop(0) end) end
		end
	end

	function Ragdoll.Watch(Model)
		if not Model or Watched[Model] then return end
		Watched[Model] = true
		Model:GetAttributeChangedSignal("Ragdolled"):Connect(function()
			if Model:GetAttribute("Ragdolled") then Limp(Model) end
		end)
		if Model:GetAttribute("Ragdolled") then Limp(Model) end
	end

	function Ragdoll.IsWatched(Model) return Watched[Model] == true end

	return Ragdoll
end

-- ===== server =====
local SettleGen = setmetatable({}, {__mode = "k"}) -- [Model] = the running settle watch's token (Hold / Apply replace it)

local function SetOwner(Model, Owner)
	for _, P in ipairs(BodyParts(Model)) do
		pcall(function() P:SetNetworkOwner(Owner) end)
	end
end

-- the owner a ragdolled body goes back to when nobody holds it: its player, or the server for an NPC
local function OwnOwner(Model) return Players:GetPlayerFromCharacter(Model) end

local function NearlyStill(Model)
	for _, P in ipairs(BodyParts(Model)) do
		if P.AssemblyLinearVelocity.Magnitude > Ragdoll.StillSpeed
			or P.AssemblyAngularVelocity.Magnitude > Ragdoll.StillSpin then
			return false
		end
	end
	return true
end

local function Settle(Model)
	local Token = {}
	SettleGen[Model] = Token
	Model:SetAttribute("RagdollSettled", nil)
	task.delay(Ragdoll.Settle, function()
		while SettleGen[Model] == Token and Model.Parent do
			if not Model:GetAttribute("CarriedBy") and NearlyStill(Model) then
				for _, P in ipairs(BodyParts(Model)) do
					P.AssemblyLinearVelocity = Vector3.zero
					P.AssemblyAngularVelocity = Vector3.zero
					P.Anchored = true
				end
				Model:SetAttribute("RagdollSettled", true)
				return
			end
			task.wait(Ragdoll.SettleCheck)
		end
	end)
end

function Ragdoll.Apply(Model)
	if typeof(Model) ~= "Instance" or Model:GetAttribute("Ragdolled") then return false end
	local H = Hum(Model)
	local Root = Model:FindFirstChild("HumanoidRootPart")
	if not H or not Root then return false end
	Model:SetAttribute("Ragdolled", true)
	H.BreakJointsOnDeath = false
	H.RequiresNeck = false
	H.PlatformStand = true
	H.AutoRotate = false
	if H.Health > 0 then pcall(function() H:ChangeState(Enum.HumanoidStateType.Physics) end) end
	StopTracks(Model)

	local Parts = BodyParts(Model)
	local IsBody = {}
	for _, P in ipairs(Parts) do IsBody[P] = true end
	for _, J in ipairs(Model:GetDescendants()) do
		if J:IsA("Motor6D") and J.Name ~= "RootJoint" and J.Enabled and IsBody[J.Part0] and IsBody[J.Part1] then
			local Def = Ragdoll.Joints[J.Name] or Ragdoll.Default
			local A0 = Socket(J.Part0, J.C0.Position, Def.Axis)
			local A1 = Socket(J.Part1, J.C1.Position, Def.Limb or DOWN)
			local B = Instance.new("BallSocketConstraint")
			B.Name = "Ragdoll_" .. J.Name
			B.Attachment0, B.Attachment1 = A0, A1
			B.LimitsEnabled = true
			B.UpperAngle = Def.Cone
			B.Restitution = 0
			B.MaxFrictionTorque = Ragdoll.Friction
			if Def.Twist then
				B.TwistLimitsEnabled = true
				B.TwistLowerAngle, B.TwistUpperAngle = Def.Twist[1], Def.Twist[2]
			end
			B.Parent = J.Parent
			J.Enabled = false
		end
	end

	-- the root follows the torso without colliding; the rest collides with the world but never with itself
	for I, P in ipairs(Parts) do
		P.Anchored = false
		P.CanCollide = P ~= Root
		if P ~= Root then
			for K = I + 1, #Parts do
				local Q = Parts[K]
				if Q ~= Root then
					local N = Instance.new("NoCollisionConstraint")
					N.Name = "RagdollNoCollide"
					N.Part0, N.Part1 = P, Q
					N.Parent = P
				end
			end
		end
	end
	-- an NPC falls on the server; a player's character stays its client's (Ragdoll.Watch)
	if not OwnOwner(Model) then SetOwner(Model, nil) end
	Settle(Model)
	return true
end

function Ragdoll.Hold(Model, On, Owner)
	if typeof(Model) ~= "Instance" or not Model:GetAttribute("Ragdolled") then return end
	local Root = Model:FindFirstChild("HumanoidRootPart")
	if On then
		SettleGen[Model] = nil -- (no settling while held)
		Model:SetAttribute("RagdollSettled", nil)
		for _, P in ipairs(BodyParts(Model)) do
			P.Anchored = false
			P.CanCollide = false
		end
		SetOwner(Model, Owner)
	else
		if not Model.Parent then return end
		for _, P in ipairs(BodyParts(Model)) do
			P.Anchored = false
			P.CanCollide = P ~= Root
		end
		local H = Hum(Model)
		if H then H.PlatformStand = true end
		SetOwner(Model, OwnOwner(Model))
		Settle(Model)
	end
end

return Ragdoll

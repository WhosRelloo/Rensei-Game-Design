-- GunAimUI (gun rework 2026-10-25): guns' shooting mode on the client. While ShootingMode is on:
--   * the aim camera (PROPOSAL): SettingsUI.CameraLock with the shoulder offset (no sprint turn), unless locked on;
--   * the crosshair is the game's own marker (UIState.Gui.Crosshair), drawn where the shot will go;
--   * AimDirection(): from the muzzle through what the crosshair covers, or at the lock-on target;
--   * FireInput(Began): hold to fire, buffered, capped at one request every Aim.HoldGap (under ServerHandler's shared limit).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)
local GunAim = require(ReplicatedStorage.Modules.Data.Rensei.GunAim)
local WeaponManager = require(ReplicatedStorage.Modules.Managers.WeaponManager)
local UIState = require(script.Parent.UIState)
local SettingsUI = require(script.Parent.SettingsUI)

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Cfg = Tuning.Weapons.Guns.Aim
local RequestRemote = ReplicatedStorage.Remotes.RequestRemote
-- Sends / HoldGap / ForceAim / FlickDefer: client_checks seams
local GunAimUI = {Sends = 0, HoldGap = Cfg.HoldGap, ForceAim = nil, FlickDefer = true}
local FLICK_DEFER_DEG = 60 -- PROPOSAL (gun rework Ruling 23): a snap turning the character more than this defers the send a frame

local function Char() return Player.Character end
local function Shooting()
	local C = Char()
	return C ~= nil and C:GetAttribute("ShootingMode") == true
end
-- the lock-on target's root, or nil (ClientHandler's AlchemyAim uses this too)
local LockOnModule = script.Parent:FindFirstChild("LockOn")
function GunAimUI.LockedRoot()
	local Ok, LockOn = pcall(function() return LockOnModule and require(LockOnModule) end)
	local T = Ok and LockOn and LockOn.Target
	return T and T.Parent and T:FindFirstChild("HumanoidRootPart") or nil
end
local function Crosshair() return UIState.Gui:FindFirstChild("Crosshair") end
local HomePosition = nil

-- the crosshair's centre as a camera ray (its ScreenGui decides whether the top-bar inset counts)
function GunAimUI.CrosshairRay()
	local Cross = Crosshair()
	local Gui = Cross and Cross:FindFirstAncestorOfClass("ScreenGui")
	local V = Camera.ViewportSize
	if not (Cross and Gui and Cross.Visible) then return Camera:ViewportPointToRay(V.X / 2, V.Y / 2) end
	local P = Cross.AbsolutePosition + Cross.AbsoluteSize / 2
	if Gui.IgnoreGuiInset then return Camera:ViewportPointToRay(P.X, P.Y) end
	return Camera:ScreenPointToRay(P.X, P.Y)
end

local function Cast(From, Vec)
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = {Char(), workspace.World.Visuals}
	local R = workspace:Raycast(From, Vec, Params)
	return R and R.Position or nil
end
GunAimUI.Cast = Cast

function GunAimUI.AimDirection()
	if GunAimUI.ForceAim then return GunAimUI.ForceAim end
	local C = Char()
	local Root = C and C:FindFirstChild("HumanoidRootPart")
	if not Root then return Camera.CFrame.LookVector end
	local Muzzle = GunAim.Muzzle(Root.Position)
	local Target = GunAimUI.LockedRoot()
	if Target then
		local To = Target.Position - Muzzle
		if To.Magnitude > 1 then return To.Unit end
	end
	local Ray = GunAimUI.CrosshairRay()
	local Stats = WeaponManager.ItemStats(C)
	local Point = GunAim.AimPoint(Ray.Origin, Ray.Direction, Muzzle, (Stats and Stats.Range or 90) + 10, Cast)
	Point = GunAimUI.Assist(Ray, Point) -- Task 10 (touch); Point unchanged until then
	return GunAim.Direction(Muzzle, Point, Ray.Direction.Unit, 2)
end
function GunAimUI.Assist(_, Point) return Point end
function GunAimUI.Kick() end -- Task 9

-- hold to fire (PROPOSAL): Began true = press (false when not shooting, so RMB falls back to Feint); false = release
local FireHeld, FireWanted, FireLoop = false, 0, nil
local function GunReady(C)
	return C:GetAttribute("CombatState") == nil and (C:GetAttribute("Ammo") or 0) > 0
		and (C:GetAttribute("ReloadingUntil") or 0) <= workspace:GetServerTimeNow()
end
local function SendShot(C)
	local Dir = GunAimUI.AimDirection()
	local Root = C:FindFirstChild("HumanoidRootPart")
	local Flat = Vector3.new(Dir.X, 0, Dir.Z)
	local Flick = false
	-- face the shot (the aim camera already turns you; this keeps the server's facing check safe), not while locked on
	if Root and Flat.Magnitude > 0.1 and not GunAimUI.LockedRoot() then
		local Look = Root.CFrame.LookVector
		local Was = Vector3.new(Look.X, 0, Look.Z)
		Flick = Was.Magnitude > 1e-3 and Was.Unit:Dot(Flat.Unit) < math.cos(math.rad(FLICK_DEFER_DEG))
		Root.CFrame = CFrame.lookAt(Root.Position, Root.Position + Flat)
	end
	GunAimUI.Sends += 1
	-- flick-and-fire (gun rework Ruling 23, PROPOSAL): after a big turn the request waits for the next Heartbeat, so the
	-- server sees the new facing first (it checks the shot against its own copy of the root, Aim.MaxYaw)
	if Flick and GunAimUI.FlickDefer then RunService.Heartbeat:Wait() end
	RequestRemote:FireServer("Shoot", "Fire", Dir)
	GunAimUI.Kick()
end
function GunAimUI.FireInput(Began)
	if Began == false then FireHeld = false return true end
	local C = Char()
	if not C or C:GetAttribute("Knocked") or not Shooting() then return false end
	FireHeld, FireWanted = true, os.clock()
	if FireLoop then return true end
	FireLoop = task.spawn(function()
		local Sent = -math.huge
		while Shooting() and not C:GetAttribute("Knocked") and (FireHeld or os.clock() - FireWanted <= Cfg.Buffer) do
			if GunReady(C) and os.clock() - Sent >= GunAimUI.HoldGap then
				Sent, FireWanted = os.clock(), 0
				SendShot(C)
			end
			RunService.Heartbeat:Wait()
		end
		FireLoop = nil
	end)
	return true
end

local Owned = false
local function Release()
	if not Owned then return end
	Owned = false
	local C = Char()
	SettingsUI.CameraFree(C and C:FindFirstChildOfClass("Humanoid"))
	local Cross = Crosshair()
	if Cross then
		Cross.Visible = false
		if HomePosition then Cross.Position = HomePosition end
	end
end

function GunAimUI.Start()
	local Cross = Crosshair()
	HomePosition = Cross and Cross.Position
	RunService:BindToRenderStep("RenseiGunAim", Enum.RenderPriority.Camera.Value + 1, function()
		local Gui = UIState.Gui
		local MenuOpen = (Gui:FindFirstChild("bg") and Gui.bg.Visible) or (Gui:FindFirstChild("Dialogue") and Gui.Dialogue.Visible)
		local C = Char()
		local H = C and C:FindFirstChildOfClass("Humanoid")
		if not Shooting() or MenuOpen or not H then Release() return end
		Owned = true
		local CrossNow = Crosshair()
		if CrossNow then CrossNow.Visible = true end
		local Target = GunAimUI.LockedRoot()
		if Target then
			SettingsUI.CameraFree(H) -- LockOn owns the camera; the marker goes onto the target
			if CrossNow then
				local G = CrossNow:FindFirstAncestorOfClass("ScreenGui")
				local P = (G and G.IgnoreGuiInset) and Camera:WorldToViewportPoint(Target.Position) or Camera:WorldToScreenPoint(Target.Position)
				CrossNow.Position = UDim2.fromOffset(P.X, P.Y)
			end
			return
		end
		if CrossNow and HomePosition then CrossNow.Position = HomePosition end
		SettingsUI.CameraLock(C, H, Cfg.ShoulderOffset, false)
	end)
end

return GunAimUI

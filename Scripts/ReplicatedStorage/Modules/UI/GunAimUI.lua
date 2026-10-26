-- GunAimUI (gun rework 2026-10-25): guns' shooting mode on the client. While ShootingMode is on:
--   * the aim camera (PROPOSAL): SettingsUI.CameraLock with the shoulder offset (no sprint turn), unless locked on;
--   * the crosshair is the game's own marker (UIState.Gui.Crosshair), drawn where the shot will go;
--   * AimDirection(): from the muzzle through what the crosshair covers, or at the lock-on target;
--   * FireInput(Began): hold to fire, buffered, capped at one request every Aim.HoldGap (under ServerHandler's shared limit);
--   * feedback on the same marker (Task 9; no new images, fonts or sounds): every shot kicks the camera up (Items.Kick, only
--     with Settings > Camera Shake on) and blooms the marker; the shot's result (LastShotResult) tints it; it dims while
--     something blocks the line of fire from the muzzle to the aim point.
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
local GunAimUI = {Sends = 0, HoldGap = Cfg.HoldGap, ForceAim = nil} -- Sends / HoldGap / ForceAim: client_checks seams
-- the feedback's numbers (gun rework plan, Task 9) -- PROPOSAL (gun rework 2026-10-25)
local FX = {
	KickTime = 0.18, -- s: a kick's pitch (Items[WeaponItem].Kick degrees) falls linearly back to 0 -- PROPOSAL
	Bloom = 1.25, BloomTime = 0.1, -- every shot: the marker's size x Bloom for BloomTime s -- PROPOSAL
	HitColor = Color3.fromRGB(255, 90, 70), BlockedColor = Color3.fromRGB(170, 170, 170), -- the result's tint -- PROPOSAL
	TintTime = 0.15, -- s the tint shows before the marker's own colour comes back -- PROPOSAL (Task 9's implementer)
	Pulse = 1.35, PulseTime = 0.15, -- a Hit: the size pulses Pulse x -> 1 over PulseTime s -- PROPOSAL
	DimShort = 1.5, Dim = 0.6, -- the line of fire stops more than DimShort studs short of the aim point: this transparency -- PROPOSAL
}

local function Char() return Player.Character end
local function Shooting()
	local C = Char()
	return C ~= nil and C:GetAttribute("ShootingMode") == true
end
-- the lock-on target's root, or nil (ClientHandler's AlchemyAim uses this too)
local LockOnModule = script.Parent:FindFirstChild("LockOn")
local LockOn = LockOnModule and require(LockOnModule) or nil -- (nil in a place without it: never locked)
function GunAimUI.LockedRoot()
	local T = LockOn and LockOn.Target
	return T and T.Parent and T:FindFirstChild("HumanoidRootPart") or nil
end
local function Crosshair() return UIState.Gui:FindFirstChild("Crosshair") end
-- a full-screen menu (the bg backdrop) or a dialogue is open: no aim camera, no firing
local function MenuOpen()
	local Gui = UIState.Gui
	return (Gui:FindFirstChild("bg") and Gui.bg.Visible) or (Gui:FindFirstChild("Dialogue") and Gui.Dialogue.Visible) or false
end
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

-- Also: one more instance (or nil) the ray passes through
local function Cast(From, Vec, Also)
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = {Char(), workspace.World.Visuals, Also}
	local R = workspace:Raycast(From, Vec, Params)
	return R and R.Position or nil
end
GunAimUI.Cast = Cast

-- where the shot is aimed from the muzzle: the lock-on target's root, or what the crosshair covers (then also its ray)
local function AimPoint(C, Muzzle)
	local Target = GunAimUI.LockedRoot()
	if Target and (Target.Position - Muzzle).Magnitude > 1 then return Target.Position, nil end
	local Ray = GunAimUI.CrosshairRay()
	local Stats = WeaponManager.ItemStats(C)
	local Point = GunAim.AimPoint(Ray.Origin, Ray.Direction, Muzzle, (Stats and Stats.Range or 90) + 10, Cast)
	return GunAimUI.Assist(Ray, Point), Ray -- Assist: Task 10 (touch); Point unchanged until then
end

function GunAimUI.AimDirection()
	if GunAimUI.ForceAim then return GunAimUI.ForceAim end
	local C = Char()
	local Root = C and C:FindFirstChild("HumanoidRootPart")
	if not Root then return Camera.CFrame.LookVector end
	local Muzzle = GunAim.Muzzle(Root.Position)
	local Point, Ray = AimPoint(C, Muzzle)
	if not Ray then return (Point - Muzzle).Unit end -- locked on
	return GunAim.Direction(Muzzle, Point, Ray.Direction.Unit, 2)
end
function GunAimUI.Assist(_, Point) return Point end

-- Settings > Camera Shake, read as BasicVFX reads it (SettingsUI sets the Player attribute; off only when false). A
-- function so client_checks can stub the read (never the Settings).
function GunAimUI.ShakeOn()
	return Player:GetAttribute("CameraShake") ~= false
end
-- a shot left: the bloom always; the kick when the gun has one (applied in Start's render steps, with Camera Shake on)
local KickLeft, KickAt, KickApplied = 0, -math.huge, 0
local BloomUntil = -math.huge
function GunAimUI.Kick()
	BloomUntil = os.clock() + FX.BloomTime
	local C = Char()
	local Item = C and C:GetAttribute("WeaponItem")
	local Def = Item and Tuning.Weapons.Guns.Items[Item]
	if Def and Def.Kick then KickLeft, KickAt = Def.Kick, os.clock() end
end

-- hold to fire (PROPOSAL): Began true = press (false when not shooting, so RMB falls back to Feint); false = release.
-- FireLoop is true while the loop's thread runs; it is always cleared when the loop ends, even on an error.
local FireHeld, FireWanted, FireLoop = false, 0, false
local function GunReady(C)
	return C:GetAttribute("CombatState") == nil and (C:GetAttribute("Ammo") or 0) > 0
		and (C:GetAttribute("ReloadingUntil") or 0) <= workspace:GetServerTimeNow()
end
local function SendShot(C)
	local Dir = GunAimUI.AimDirection()
	local Root = C:FindFirstChild("HumanoidRootPart")
	local Flat = Vector3.new(Dir.X, 0, Dir.Z)
	-- face the shot (the aim camera already turns you; this keeps the server's facing check safe), not while locked on.
	-- After a big flick the server's copy of the root lags (about 0.2-0.27 s, measured 2026-10-25): Requests.Shoot holds
	-- such a shot for Aim.FlickGrace until its facing catches up (gun rework Ruling 28).
	if Root and Flat.Magnitude > 0.1 and not GunAimUI.LockedRoot() then
		Root.CFrame = CFrame.lookAt(Root.Position, Root.Position + Flat)
	end
	GunAimUI.Sends += 1
	RequestRemote:FireServer("Shoot", "Fire", Dir)
	GunAimUI.Kick()
end
function GunAimUI.FireInput(Began)
	if Began == false then FireHeld = false return true end
	local C = Char()
	if not C or C:GetAttribute("Knocked") or not Shooting() then return false end
	FireHeld, FireWanted = true, os.clock()
	if FireLoop then return true end
	FireLoop = true
	task.spawn(function()
		local Ok, Err = pcall(function()
			local Sent = -math.huge
			while Shooting() and not C:GetAttribute("Knocked") and not MenuOpen()
				and (FireHeld or os.clock() - FireWanted <= Cfg.Buffer) do
				if GunReady(C) and os.clock() - Sent >= GunAimUI.HoldGap then
					Sent, FireWanted = os.clock(), 0
					SendShot(C)
				end
				RunService.Heartbeat:Wait()
			end
		end)
		FireLoop = false
		if not Ok then warn("GunAimUI fire loop:", Err) end
	end)
	return true
end

-- the marker's own look (saved at Start) and which properties carry it (Task 1's survey: Uis.Crosshair is an ImageLabel)
local HomeSize, HomeColor, HomeTransparency, ColorProp, TransparencyProp = nil, nil, nil, nil, nil
local TintColor, TintUntil, PulseAt = nil, -math.huge, -math.huge
local SeenChar, SeenShot = nil, nil -- the character and LastShotAt the hit marker has seen
local function Scaled(S, K)
	return UDim2.new(S.X.Scale * K, math.round(S.X.Offset * K), S.Y.Scale * K, math.round(S.Y.Offset * K))
end
-- the line of fire from the muzzle to the aim point stops more than DimShort short of it. Characters (World.Live) never
-- block it, as on the server's wall ray (WeaponManager.Fire): a shot that meets one has hit someone.
local function LineBlocked(C)
	local Root = C:FindFirstChild("HumanoidRootPart")
	if not Root then return false end
	local Muzzle = GunAim.Muzzle(Root.Position)
	local Point = AimPoint(C, Muzzle)
	local To = Point - Muzzle
	if To.Magnitude <= FX.DimShort then return false end
	local Hit = Cast(Muzzle, To, workspace.World.Live)
	return Hit ~= nil and (Point - Hit).Magnitude > FX.DimShort
end
-- each frame in shooting mode: the hit marker, the bloom and the blocked line, on the marker
local function Feedback(Cross, C)
	if not HomeSize then return end
	local Now = os.clock()
	local Shot = C:GetAttribute("LastShotAt")
	if SeenChar ~= C then
		SeenChar, SeenShot = C, Shot -- just into shooting mode: an earlier shot doesn't flash
	elseif Shot ~= SeenShot then
		SeenShot = Shot
		local Result = C:GetAttribute("LastShotResult")
		if Result == "Hit" then
			TintColor, TintUntil, PulseAt = FX.HitColor, Now + FX.TintTime, Now
		elseif Result == "Blocked" then
			TintColor, TintUntil = FX.BlockedColor, Now + FX.TintTime
		end
	end
	local K = Now < BloomUntil and FX.Bloom or 1
	local P = (Now - PulseAt) / FX.PulseTime
	if P >= 0 and P < 1 then K = math.max(K, FX.Pulse + (1 - FX.Pulse) * P) end
	Cross.Size = Scaled(HomeSize, K)
	Cross[ColorProp] = Now < TintUntil and TintColor or HomeColor
	Cross[TransparencyProp] = LineBlocked(C) and FX.Dim or HomeTransparency
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
		if HomeSize then
			Cross.Size, Cross[ColorProp], Cross[TransparencyProp] = HomeSize, HomeColor, HomeTransparency
		end
	end
	SeenChar, TintUntil, PulseAt, BloomUntil = nil, -math.huge, -math.huge, -math.huge
end

function GunAimUI.Start()
	local Cross = Crosshair()
	HomePosition = Cross and Cross.Position
	if Cross then
		local Image = Cross:IsA("ImageLabel") or Cross:IsA("ImageButton")
		ColorProp = Image and "ImageColor3" or "BackgroundColor3"
		TransparencyProp = Image and "ImageTransparency" or "BackgroundTransparency"
		HomeSize, HomeColor, HomeTransparency = Cross.Size, Cross[ColorProp], Cross[TransparencyProp]
	end
	RunService:BindToRenderStep("RenseiGunAim", Enum.RenderPriority.Camera.Value + 1, function()
		local C = Char()
		local H = C and C:FindFirstChildOfClass("Humanoid")
		if not Shooting() or MenuOpen() or not H then Release() return end
		Owned = true
		local CrossNow = Crosshair()
		if CrossNow then CrossNow.Visible = true end
		local Target = GunAimUI.LockedRoot()
		if Target then
			SettingsUI.CameraFree(H) -- LockOn owns the camera; the marker goes onto the target
			if CrossNow then
				local G = CrossNow:FindFirstAncestorOfClass("ScreenGui")
				local P = (G and G.IgnoreGuiInset) and Camera:WorldToViewportPoint(Target.Position) or Camera:WorldToScreenPoint(Target.Position)
				if P.Z <= 0 then
					CrossNow.Visible = false -- the target is behind the camera: no marker rather than a mirrored one
				else
					CrossNow.Position = UDim2.fromOffset(P.X, P.Y)
				end
			end
		else
			if CrossNow and HomePosition then CrossNow.Position = HomePosition end
			SettingsUI.CameraLock(C, H, Cfg.ShoulderOffset, false)
		end
		if CrossNow then Feedback(CrossNow, C) end
	end)
	-- the kick: KickLeft x K degrees of pitch, K = 1 - (time since the shot) / KickTime clamped to 0..1, added after the
	-- camera (Camera + 2). The camera module builds each frame's look from the last frame's Camera.CFrame
	-- (PlayerModule BaseCamera:GetCameraLookVector), so the pitch added is taken off again before it runs (Camera - 1);
	-- otherwise every frame's kick would stay and the view would never come back down.
	RunService:BindToRenderStep("RenseiGunKickUndo", Enum.RenderPriority.Camera.Value - 1, function()
		if KickApplied ~= 0 then
			Camera.CFrame *= CFrame.Angles(math.rad(-KickApplied), 0, 0)
			KickApplied = 0
		end
	end)
	RunService:BindToRenderStep("RenseiGunKick", Enum.RenderPriority.Camera.Value + 2, function()
		local K = math.clamp(1 - (os.clock() - KickAt) / FX.KickTime, 0, 1)
		if K > 0 and GunAimUI.ShakeOn() then
			KickApplied = KickLeft * K
			Camera.CFrame *= CFrame.Angles(math.rad(KickApplied), 0, 0)
		end
	end)
end

return GunAimUI

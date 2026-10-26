-- GunAimUI (gun rework 2026-10-25): guns' shooting mode on the client. While ShootingMode is on:
--   * the aim camera (PROPOSAL): SettingsUI.CameraLock with the shoulder offset (no sprint turn), unless locked on;
--   * the crosshair is the game's own marker (UIState.Gui.Crosshair), drawn where the shot will go;
--   * AimDirection(): from the muzzle through what the crosshair covers, or at the lock-on target;
--   * FireInput(Began): hold to fire, buffered, capped at one request every Aim.HoldGap (under ServerHandler's shared limit);
--   * feedback on the same marker (Task 9; no new images, fonts or sounds): every shot kicks the camera up (Items.Kick, only
--     with Settings > Camera Shake on) and blooms the marker; the shot's result (LastShotResult) tints it; it dims while
--     something blocks the line of fire from the muzzle to the aim point;
--   * touch screens (Task 10): Assist() moves the aim point onto the character nearest the crosshair (Aim.TouchAssist).
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
-- Sends / HoldGap / ForceAim / FaceWait: client_checks seams. FaceWait (FaceAim, below): how long a press waits after a
-- turn past Aim.MaxYaw, so the server's copy of the facing has followed -- Aim.FlickGrace, the longest the server's
-- facing is known to lag a big client turn (0.20-0.27 s measured 2026-10-25; Ruling 28) -- PROPOSAL (final fix B4)
local GunAimUI = {Sends = 0, HoldGap = Cfg.HoldGap, ForceAim = nil, FaceWait = Cfg.FlickGrace}
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

-- how far the crosshair looks (and the touch assist reaches): the held gun's range + 10
local function AimRange(C)
	local Stats = C and WeaponManager.ItemStats(C)
	return (Stats and Stats.Range or 90) + 10
end

-- where the shot is aimed from the muzzle: the lock-on target's root, or what the crosshair covers (then also its ray)
local function AimPoint(C, Muzzle)
	local Target = GunAimUI.LockedRoot()
	if Target and (Target.Position - Muzzle).Magnitude > 1 then return Target.Position, nil end
	local Ray = GunAimUI.CrosshairRay()
	local Point = GunAim.AimPoint(Ray.Origin, Ray.Direction, Muzzle, AimRange(C), Cast)
	return GunAimUI.Assist(Ray, Point), Ray
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
-- Touch aim assist (Task 10): only on a touch screen (MobileControls.Active) with Aim.TouchAssist on. The aim point
-- moves onto the root of the character nearest the crosshair ray, within TouchAssist degrees and the crosshair's reach,
-- that is alive, not you, and seen from the camera (Cast reaches it). Never townsfolk: only World.Live's own children
-- (GunAim.Candidates' direct-only list, so nothing in a Folder), and never a Model carrying TownsfolkId (as
-- DamageManager tells them apart; final fix B1). Else Point. A pure function of (Ray, Point), no state: it
-- runs every frame (the blocked-line dim) as well as for each shot, and it casts only for the pick (and again only when
-- that one is hidden).
function GunAimUI.Assist(Ray, Point)
	if (Cfg.TouchAssist or 0) <= 0 or not require(script.Parent.MobileControls).Active() then return Point end
	local C = Char()
	local Centres, Models = {}, {}
	for _, M in ipairs(GunAim.Candidates(workspace.World.Live, true)) do
		local H = M:FindFirstChildOfClass("Humanoid")
		local Root = M:FindFirstChild("HumanoidRootPart")
		if M ~= C and Root and H and H.Health > 0 and M:GetAttribute("TownsfolkId") == nil then
			table.insert(Centres, Root.Position)
			table.insert(Models, M)
		end
	end
	local Range = AimRange(C)
	while true do
		local Pick = GunAim.Assist(Ray.Origin, Ray.Direction, Centres, Cfg.TouchAssist, Range)
		if not Pick then return Point end
		local I = table.find(Centres, Pick)
		if Cast(Ray.Origin, Pick - Ray.Origin, Models[I]) == nil then return Pick end
		table.remove(Centres, I) -- hidden: the next nearest
		table.remove(Models, I)
	end
end

-- Settings > Camera Shake, read as BasicVFX reads it (SettingsUI sets the Player attribute; off only when false). A
-- function so client_checks can stub the read (never the Settings).
function GunAimUI.ShakeOn()
	return Player:GetAttribute("CameraShake") ~= false
end
-- a shot left: the bloom always; the kick when the gun has one (applied in Start's render steps, with Camera Shake on)
local KickLeft, KickAt, KickApplied, KickedCF = 0, -math.huge, 0, nil
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
-- turn the root flat toward Dir (the client owns its root; the server's copy follows). False when Dir is (near) vertical.
local function FaceFlat(Root, Dir)
	local Flat = Vector3.new(Dir.X, 0, Dir.Z)
	if Flat.Magnitude <= 0.1 then return false end
	Root.CFrame = CFrame.lookAt(Root.Position, Root.Position + Flat)
	return true
end
-- A weapon skill press (Fan the Hammer: ClientHandler's WeaponSkillInput) sends the aim right before it. An aim past
-- Aim.MaxYaw from your facing would be refused, and the Fan with it, so (not while locked on, not knocked) the root
-- turns flat toward the aim first, as SendShot does (final fix B4). Returns how long the press should wait before it is
-- sent -- FaceWait after such a turn (the server's copy of the facing lags it), else 0.
function GunAimUI.FaceAim()
	local C = Char()
	local Root = C and C:FindFirstChild("HumanoidRootPart")
	if not Root or C:GetAttribute("Knocked") or GunAimUI.LockedRoot() then return 0 end
	local Dir = GunAimUI.AimDirection()
	local _, Why = GunAim.Validate(Dir, Root.CFrame.LookVector, Cfg.MaxYaw, Cfg.MaxPitch)
	if Why ~= "behind" or not FaceFlat(Root, Dir) then return 0 end
	return GunAimUI.FaceWait or 0
end
local function SendShot(C)
	local Dir = GunAimUI.AimDirection()
	local Root = C:FindFirstChild("HumanoidRootPart")
	-- face the shot (the aim camera already turns you; this keeps the server's facing check safe), not while locked on.
	-- After a big flick the server's copy of the root lags (about 0.2-0.27 s, measured 2026-10-25): Requests.Shoot holds
	-- such a shot for Aim.FlickGrace until its facing catches up (gun rework Ruling 28).
	if Root and not GunAimUI.LockedRoot() then FaceFlat(Root, Dir) end
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

-- the marker's own look and place, noted once: at Start, or on the first frame it exists (it may load after Start).
-- Called at the top of every frame, before anything writes to the marker; it returns at once when already noted.
local function NoteHome(Cross)
	if not Cross or HomeSize then return end
	local Image = Cross:IsA("ImageLabel") or Cross:IsA("ImageButton")
	ColorProp = Image and "ImageColor3" or "BackgroundColor3"
	TransparencyProp = Image and "ImageTransparency" or "BackgroundTransparency"
	HomePosition, HomeSize, HomeColor, HomeTransparency = Cross.Position, Cross.Size, Cross[ColorProp], Cross[TransparencyProp]
end

function GunAimUI.Start()
	NoteHome(Crosshair())
	RunService:BindToRenderStep("RenseiGunAim", Enum.RenderPriority.Camera.Value + 1, function()
		local CrossNow = Crosshair()
		NoteHome(CrossNow) -- (before this frame moves or tints it)
		local C = Char()
		local H = C and C:FindFirstChildOfClass("Humanoid")
		if not Shooting() or MenuOpen() or not H then Release() return end
		Owned = true
		if CrossNow then CrossNow.Visible = true end
		local Target = GunAimUI.LockedRoot()
		if Target then
			SettingsUI.CameraFree(H) -- LockOn owns the camera; the marker goes onto the target (RenseiGunAimMarker)
		else
			if CrossNow and HomePosition then CrossNow.Position = HomePosition end
			SettingsUI.CameraLock(C, H, Cfg.ShoulderOffset, false)
		end
		if CrossNow then Feedback(CrossNow, C) end
	end)
	-- locked on, the marker goes onto the target through the camera this frame renders: after LockOn's own step (Camera
	-- + 1 too, bound at each lock; the order of equal priorities isn't set, so it could run after this module's and the
	-- marker trailed its lerp by a frame) and after the kick (Camera + 2) -- final fix B2
	RunService:BindToRenderStep("RenseiGunAimMarker", Enum.RenderPriority.Camera.Value + 3, function()
		local Target = Owned and GunAimUI.LockedRoot()
		local CrossNow = Target and Crosshair()
		if not CrossNow then return end
		local G = CrossNow:FindFirstAncestorOfClass("ScreenGui")
		local P = (G and G.IgnoreGuiInset) and Camera:WorldToViewportPoint(Target.Position) or Camera:WorldToScreenPoint(Target.Position)
		if P.Z <= 0 then
			CrossNow.Visible = false -- the target is behind the camera: no marker rather than a mirrored one
		else
			CrossNow.Position = UDim2.fromOffset(P.X, P.Y)
		end
	end)
	-- the kick: KickLeft x K degrees of pitch, K = 1 - (time since the shot) / KickTime clamped to 0..1, added after the
	-- camera (Camera + 2). The camera module builds each frame's look from the last frame's Camera.CFrame
	-- (PlayerModule BaseCamera:GetCameraLookVector), so the pitch added is taken off again before it runs (Camera - 1);
	-- otherwise every frame's kick would stay and the view would never come back down.
	-- The undo only applies while the camera still is the CFrame the kick wrote: a script that set the camera outright
	-- in between (MasteryUI's lookAt, say) has already dropped the kick, and must not get it taken off again.
	-- A RELATIVE write in between would also fail the guard and leave the kick on. None is there (final fix B3, read in
	-- Studio 2026-10-25, Ye and Foundry alike): BasicVFX's camera shake (its CameraShaker) writes Camera.CFrame *= shake
	-- at RenderPriority.Camera (200) -- after this undo (Camera - 1) and before the kick (Camera + 2), never between the
	-- kick and the next frame's undo -- so the CFrame guard stands. A relative writer bound after Camera + 2 would need a
	-- pitch-delta undo here instead.
	RunService:BindToRenderStep("RenseiGunKickUndo", Enum.RenderPriority.Camera.Value - 1, function()
		if KickApplied ~= 0 then
			if KickedCF and Camera.CFrame:FuzzyEq(KickedCF, 1e-4) then
				Camera.CFrame *= CFrame.Angles(math.rad(-KickApplied), 0, 0)
			end
			KickApplied, KickedCF = 0, nil
		end
	end)
	RunService:BindToRenderStep("RenseiGunKick", Enum.RenderPriority.Camera.Value + 2, function()
		local K = math.clamp(1 - (os.clock() - KickAt) / FX.KickTime, 0, 1)
		if K > 0 and GunAimUI.ShakeOn() then
			KickApplied = KickLeft * K
			Camera.CFrame *= CFrame.Angles(math.rad(KickApplied), 0, 0)
			KickedCF = Camera.CFrame
		end
	end)
end

return GunAimUI

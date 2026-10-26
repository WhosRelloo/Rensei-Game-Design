-- client_checks.lua (gun rework Task 8, 2026-10-25; Tasks 9-10 add their checks here): the CLIENT checks of guns' shooting
-- mode (GunAimUI: the aim camera, the crosshair marker, lock-on aim, hold to fire). Play only, run from the Server:
--   python -I Art/Tools/rbxc.py luau "placeId: <id>" Server @Art/Studio/Guns/client_checks.lua
-- It needs the Play protocol's hook (ServerStorage.LMRunSuite) and the test player's character holding no Tool.
-- What it does (everything it makes is a Play copy and vanishes at Stop; it also removes it all before returning):
--   * makes the RemoteEvent ReplicatedStorage.GunChecks_TEMP_Remote (the two halves talk over it);
--   * makes the LocalScript GunChecks_TEMP (CLIENT below; plugin security sets Source) in the player's PlayerGui -- never
--     in StarterPlayerScripts;
--   * makes the ModuleScript ServerStorage.RenseiTests.GunChecks_TEMP_Suite (SERVER below) and runs it through
--     LMRunSuite, so its server-side setup (GunKit, SmokeKit, WeaponManager.Give) runs in the GAME VM like every suite;
--   * returns TestKit's "PASS n / FAIL n" lines.
-- The results come back over the RemoteEvent: a value a LocalScript writes (a StringValue in ReplicatedStorage) never
-- replicates to the server.
-- Every case wraps its body in SmokeKit.Guarded (the character is put back) with GunKit.Unequip first (Ruling 4c: the
-- player's Tool goes to the Backpack, never destroyed); the player stands on GunKit's Play-only floor, facing -Z, with
-- the test's own Revolver (WeaponManager.Give), CombatMode and ShootingMode set on the Server (Step 1).
-- Before GunAimUI exists the client falls back (pcall) to a stand-in: Camera.CFrame.LookVector for AimDirection, the
-- viewport centre for CrosshairRay, ClientActions "Fire" for FireInput -- and the first two checks reproduce shift lock's
-- camera (Humanoid.CameraOffset (0, 1.5, 0.5), MouseBehavior LockCenter) inside the check and put both back. Nothing
-- reads or writes the owner's Settings except ReleaseRestores' precondition (it reads the save's ShiftLock).
--
-- RED seams (0 / false = off; a copy in the scratch folder sets them, as dumphelper's MODE line):
--   HOLD_GAP: GunAimUI.HoldGap for HoldLoopUnderBucket (0.1 = the first draft's loop: about 9 requests a second at 60 Hz
--     Heartbeats, just over the shared bucket's refill of 8 a second, so its 16-token burst lasts the 10 s hold -- the
--     RED fails on the request count, not on a dropped Mode request; measured 2026-10-25: 90 and 91 requests);
--   NO_FLICK_GRACE: Aim.FlickGrace = 0 on the Server for FlickAndFire (no flick grace: Requests.Shoot refuses a shot
--     whose yaw is past MaxYaw at once, as before gun rework Ruling 28); put back after the case.
-- Task 9 (feedback: the kick, the bloom, the hit marker, the blocked line) adds HitMarkerFlashes, BlockedLineDims,
-- KickRecovers, KickRespectsCameraShake and RealShotFlashesAndKicks. Settings > Camera Shake is read, never written: a
-- check that needs the other value stubs GunAimUI.ShakeOn (the seam) and puts it back.
-- Task 10 (touch screens) adds AssistOnTouchOnly, AssistIgnoresTownsfolk, AssistSkipsHiddenAndDead and TouchHintAndHold,
-- and (Task 9's review) KickUndoAfterCameraWrite.
-- The touch screen is MobileControls' own seam, the Player attribute ForceMobileControls, set on the client by each
-- check and cleared after it (Reset clears it too); nothing else is set.
-- The final-review fix (half B) adds AssistIgnoresTownsfolkId (B1), LockOnMarkerOnTarget (B2) and FanFacesAim (B4).
-- Every case puts back the character's LastShotAt / LastShotResult (and the weapon skill's cooldown attributes) it
-- found (B5); AssistIgnoresTownsfolk makes World.Live.Townsfolk in the Play copy when the place has none, and removes it
-- after (B6: Foundry).
--   FACE_WAIT: -1 = off; else GunAimUI.FaceWait for FanFacesAim (0 = the turn, but no wait for the server's facing).
-- ONLY: "" runs every check; else a comma list of check names.
local ONLY = ""
local HOLD_GAP = 0
local NO_FLICK_GRACE = false
local FACE_WAIT = -1

local CLIENT = [==[
-- GunChecks_TEMP (Play only; made by Art/Studio/Guns/client_checks.lua, gone at Stop): the client half of the gun checks.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local Remote = ReplicatedStorage:WaitForChild("GunChecks_TEMP_Remote", 30)
local GunAim = require(ReplicatedStorage.Modules.Data.Rensei.GunAim)
local UIState = require(ReplicatedStorage.Modules.UI.UIState)
local LockOn = require(ReplicatedStorage.Modules.UI.LockOn)
local ClientActions = require(ReplicatedStorage.Modules.Managers.ClientActions)
local SettingsDef = require(ReplicatedStorage.Modules.Data.Rensei.Settings)
local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local RequestRemote = ReplicatedStorage.Remotes.RequestRemote

-- GunAimUI when it exists, else today's stand-in (the RED runs)
local Module = ReplicatedStorage.Modules.UI:FindFirstChild("GunAimUI")
local Ok, GunAimUI = pcall(function() return Module and require(Module) end)
if not Ok then GunAimUI = nil end
local StandIn = GunAimUI == nil
local HomeHoldGap = GunAimUI and GunAimUI.HoldGap
local HomeFaceWait = GunAimUI and GunAimUI.FaceWait

local function Char() return Player.Character end
local function Root() local C = Char() return C and C:FindFirstChild("HumanoidRootPart") end
local function Hum() local C = Char() return C and C:FindFirstChildOfClass("Humanoid") end
local function Frames(N) for _ = 1, N or 3 do RunService.RenderStepped:Wait() end end
local function Deg(A, B) return math.deg(math.acos(math.clamp(A.Unit:Dot(B.Unit), -1, 1))) end
local function Cross() return UIState.Gui:FindFirstChild("Crosshair") end

local function CrosshairRay()
	if GunAimUI then return GunAimUI.CrosshairRay() end
	local V = Camera.ViewportSize
	return Camera:ViewportPointToRay(V.X / 2, V.Y / 2)
end
local function AimDirection()
	if GunAimUI then return GunAimUI.AimDirection() end
	return Camera.CFrame.LookVector
end
local function FireInput(Began)
	if GunAimUI then return GunAimUI.FireInput(Began) end
	ClientActions.Run("Fire", Began) -- today's path (one shot per press)
	return nil
end

-- the stand-in's shift-lock camera (RED geometry), put back by Reset
local Saved = nil
local function RedGeometry()
	if not StandIn or Saved then return end
	local H = Hum()
	Saved = {Offset = H.CameraOffset, Mouse = UIS.MouseBehavior}
	H.CameraOffset = Vector3.new(0, 1.5, 0.5)
	UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
	Frames(3)
end

local function WaitMode(Want, Timeout)
	local T0 = os.clock()
	while Char() and (Char():GetAttribute("ShootingMode") == true) ~= Want and os.clock() - T0 < (Timeout or 2) do Frames(1) end
	return Char() ~= nil and (Char():GetAttribute("ShootingMode") == true) == Want
end

local function CameraState()
	local H = Hum()
	local X = Cross()
	return {
		MouseBehavior = UIS.MouseBehavior.Name,
		Offset = H and H.CameraOffset,
		MarkerVisible = X ~= nil and X.Visible,
		ShiftLock = SettingsDef.Resolve(UIState.Data and UIState.Data.Settings).ShiftLock == true,
	}
end

local Checks = {}

function Checks.Ping() return true end

-- the character reached the test floor (it streams in); the camera is levelled to look along the character's facing
function Checks.Arrive(Args)
	local T0 = os.clock()
	while not (workspace:FindFirstChild(Args.Floor) and Root() and Root().Position.Y > Args.MinY) and os.clock() - T0 < 10 do
		Frames(1)
	end
	assert(workspace:FindFirstChild(Args.Floor), "the test floor never streamed in")
	assert(Root() and Root().Position.Y > Args.MinY, "the character never reached the test floor")
	Frames(10) -- the camera catches up with the character
	local P = Camera.CFrame.Position
	Camera.CFrame = CFrame.lookAt(P, P + Args.Look)
	Frames(3)
	return {StandIn = StandIn}
end

-- the shooting mode is on (as the Server set it), and GunAimUI has had a few frames to take the camera
function Checks.Shooting()
	assert(WaitMode(true, 3), "ShootingMode never reached the client")
	Frames(5)
	return true
end

function Checks.CrosshairMatch()
	RedGeometry()
	local X = Cross()
	local Ray = CrosshairRay()
	local P = Ray.Origin + Ray.Direction.Unit * 50
	local Gui = X and X:FindFirstAncestorOfClass("ScreenGui")
	if not (X and Gui) then return {NoMarker = true, Dist = -1} end
	local S = Gui.IgnoreGuiInset and Camera:WorldToViewportPoint(P) or Camera:WorldToScreenPoint(P)
	local Centre = X.AbsolutePosition + X.AbsoluteSize / 2
	return {NoMarker = not X.Visible, Dist = (Vector2.new(S.X, S.Y) - Centre).Magnitude, StandIn = StandIn}
end

function Checks.Ray()
	RedGeometry()
	local R = CrosshairRay()
	return {Origin = R.Origin, Dir = R.Direction.Unit, StandIn = StandIn}
end

function Checks.AimHitsMarker(Args)
	RedGeometry()
	local Marker = workspace:WaitForChild(Args.Marker, 5)
	assert(Marker, "the marker part never streamed in")
	Frames(2)
	local Muzzle = GunAim.Muzzle(Root().Position)
	local Dir = AimDirection()
	return {
		Hit = GunAim.RayBox(Muzzle, Dir, 120, Args.CFrame, Args.Size) ~= nil,
		ControlHit = GunAim.RayBox(Muzzle, Camera.CFrame.LookVector, 120, Args.CFrame, Args.Size) ~= nil,
		StandIn = StandIn,
	}
end

function Checks.LockOnAim(Args)
	local Live = workspace.World.Live
	local Target = Live:WaitForChild(Args.Target, 5)
	assert(Target and Target:WaitForChild("HumanoidRootPart", 5), "the lock-on dummy never streamed in")
	assert(LockOn.Target == nil, "precondition: nothing locked")
	LockOn.Toggle() -- the module's own API (the Lock Target key)
	Frames(10)
	local Locked = LockOn.Target == Target
	local Muzzle = GunAim.Muzzle(Root().Position)
	local Off = Deg(AimDirection(), Target.HumanoidRootPart.Position - Muzzle)
	if LockOn.Target then LockOn.Release() end
	return {Locked = Locked, Deg = Off, StandIn = StandIn}
end

function Checks.CameraState(Args)
	assert(WaitMode(Args.Shooting, 3), "ShootingMode never became " .. tostring(Args.Shooting) .. " on the client")
	Frames(3)
	return CameraState()
end

-- hold the fire input for Seconds with an aim the server refuses every time, then Y (Mode off). The aim is straight down
-- (past Aim.MaxPitch whatever the facing): an aim behind the character would not stay refused, because SendShot turns the
-- root to face the shot and the server's facing then follows it.
function Checks.HoldLoop(Args)
	assert(GunAimUI, "no GunAimUI")
	GunAimUI.ForceAim = Vector3.new(0, -1, 0)
	if Args.HoldGap and Args.HoldGap > 0 then GunAimUI.HoldGap = Args.HoldGap end
	local From = GunAimUI.Sends
	FireInput(true)
	task.wait(Args.Seconds)
	FireInput(false)
	Frames(3)
	local Sends = GunAimUI.Sends - From
	RequestRemote:FireServer("Shoot", "Mode", false)
	GunAimUI.ForceAim = nil
	GunAimUI.HoldGap = HomeHoldGap
	return {Sends = Sends, HoldGap = GunAimUI.HoldGap}
end

-- flick: turn the camera (and so the character, which faces the camera in shooting mode) Args.Deg about the focus and
-- fire in that same frame, aimed level along the new facing
function Checks.Flick(Args)
	assert(GunAimUI, "no GunAimUI")
	local L = Root().CFrame.LookVector
	local Was = Vector3.new(L.X, 0, L.Z).Unit
	local Turn = CFrame.Angles(0, math.rad(Args.Deg), 0)
	local Aim = Turn:VectorToWorldSpace(Was)
	local F = Camera.Focus.Position
	Camera.CFrame = CFrame.new(F) * Turn * CFrame.new(-F) * Camera.CFrame
	GunAimUI.ForceAim = Aim
	local Began = FireInput(true)
	FireInput(false)
	task.wait(0.3)
	GunAimUI.ForceAim = nil
	return {Began = Began, Turned = Deg(Was, Aim)}
end

-- RMB held for Args.Seconds (FireInput, as the RMB branch calls it; the stand-in: ClientActions "Fire")
function Checks.Hold(Args)
	local Began = FireInput(true)
	task.wait(Args.Seconds)
	FireInput(false)
	return {Began = Began, StandIn = StandIn}
end

-- Y: the client's own Mode-off request; then the camera state, and what RMB does out of shooting mode
function Checks.ModeOff()
	RequestRemote:FireServer("Shoot", "Mode", false)
	assert(WaitMode(false, 3), "ShootingMode still on 3 s after the Mode-off request")
	Frames(3)
	local S = CameraState()
	S.Began = FireInput(true)
	FireInput(false)
	return S
end

-- ===== Task 9: the feedback on the marker and the camera =====
local LAST = Enum.RenderPriority.Last.Value -- samples are taken after everything else in the frame (camera, marker, kick)
local HomeShakeOn = GunAimUI and GunAimUI.ShakeOn
local function Pitch()
	return math.deg(math.asin(math.clamp(Camera.CFrame.LookVector.Y, -1, 1)))
end
local function IsImage(X) return X:IsA("ImageLabel") or X:IsA("ImageButton") end
local function Tint(X) return IsImage(X) and X.ImageColor3 or X.BackgroundColor3 end
local function Transp(X) return IsImage(X) and X.ImageTransparency or X.BackgroundTransparency end
local function SameColor(A, B)
	return math.abs(A.R - B.R) + math.abs(A.G - B.G) + math.abs(A.B - B.B) < 3 / 255
end
-- the marker's size over its size at Home (the scale, or the offset when it has no scale)
local function SizeRatio(S, Home)
	if Home.X.Scale ~= 0 then return S.X.Scale / Home.X.Scale end
	return S.X.Offset / Home.X.Offset
end
-- Fn(t) every frame (after everything else in it) for Seconds
local function Sample(Seconds, Fn)
	local T0, Done, Err = os.clock(), false, nil
	RunService:BindToRenderStep("GunChecks_TEMP_Sample", LAST, function()
		local T = os.clock() - T0
		local Ok, E = pcall(Fn, T)
		if not Ok then Err = E end
		if T >= Seconds or Err then Done = true end
	end)
	while not Done do task.wait() end
	RunService:UnbindFromRenderStep("GunChecks_TEMP_Sample")
	if Err then error(Err, 0) end
end
-- Settings > Camera Shake as the game reads it (BasicVFX: the Player attribute CameraShake, off only when false)
local function ShakeSetting() return Player:GetAttribute("CameraShake") ~= false end
-- run Fn with GunAimUI's Camera Shake read giving Want: the real read when the setting already is Want, else the seam
-- stubbed (never the owner's Settings) and put back
local function WithShake(Want, Fn)
	local Real = ShakeSetting()
	local Seam = GunAimUI ~= nil and type(GunAimUI.ShakeOn) == "function"
	local Info = {Real = Real, Seam = Seam, Read = nil, Stubbed = false}
	if Seam then Info.Read = GunAimUI.ShakeOn() end -- (false stays false)
	if Want ~= nil and Want ~= Real then
		assert(Seam, "no GunAimUI.ShakeOn seam to stub Camera Shake " .. (Want and "on" or "off"))
		GunAimUI.ShakeOn = function() return Want end
		Info.Stubbed = true
	end
	local Ok, R = pcall(Fn)
	if Info.Stubbed then GunAimUI.ShakeOn = HomeShakeOn end
	if not Ok then error(R, 0) end
	R.Shake = Info
	return R
end

-- Kick() (Args.Shake: true / false = Camera Shake on / off): the pitch and the marker's size over 0.3 s
function Checks.Kick(Args)
	assert(GunAimUI, "no GunAimUI")
	return WithShake(Args.Shake, function()
		local X = Cross()
		assert(X, "no marker")
		local Home = X.Size
		Frames(3)
		local P0 = Pitch()
		local R = {Rise = 0, Late = 0, Bloom = 1, BloomLate = 0}
		GunAimUI.Kick()
		Sample(Args.Seconds or 0.3, function(T)
			local D = Pitch() - P0
			if T <= Args.KickTime then R.Rise = math.max(R.Rise, D) end
			if T >= Args.BackAt then R.Late = math.max(R.Late, math.abs(D)) end
			local K = SizeRatio(X.Size, Home)
			if T <= Args.BloomWithin then R.Bloom = math.max(R.Bloom, K) end
			if T >= Args.BloomBackAt then R.BloomLate = math.max(R.BloomLate, math.abs(K - 1)) end
		end)
		return R
	end)
end

-- Kick(), then in the kick's first frame an absolute camera write (as MasteryUI's lookAt does) of the camera as it was
-- before the kick: the kick seen when it was written, and the pitch Args.At s later, both from before the kick
function Checks.KickThenWrite(Args)
	assert(GunAimUI, "no GunAimUI")
	return WithShake(true, function()
		Frames(3)
		local Before, P0 = Camera.CFrame, Pitch()
		local R = {Kicked = nil, Off = nil}
		GunAimUI.Kick()
		RunService:BindToRenderStep("GunChecks_TEMP_Write", LAST, function()
			if R.Kicked then return end
			R.Kicked = Pitch() - P0
			Camera.CFrame = Before
		end)
		task.wait(Args.At)
		RunService:UnbindFromRenderStep("GunChecks_TEMP_Write")
		R.Off = Pitch() - P0
		return R
	end)
end

-- the hit marker: WatchFlash notes the marker's colour, then each frame after the character's LastShotAt changes on
-- this client: the first colour that isn't its own (and when), and the colour Args.BackAt s after the change
local Flash = nil
function Checks.WatchFlash(Args)
	local X = Cross()
	assert(X, "no marker")
	local C = Char()
	local F = {Home = Tint(X), HomeTransparency = Transp(X)}
	Flash = F
	local Conn = C:GetAttributeChangedSignal("LastShotAt"):Connect(function()
		if not F.SeenAt then F.SeenAt, F.Result = os.clock(), C:GetAttribute("LastShotResult") end
	end)
	local T0 = os.clock()
	RunService:BindToRenderStep("GunChecks_TEMP_Flash", LAST, function()
		local Now = os.clock()
		if F.SeenAt then
			local Col = Tint(X)
			if not F.TintAt and not SameColor(Col, F.Home) then F.TintAt, F.First = Now, Col end
			if not F.Back and Now - F.SeenAt >= Args.BackAt then F.Back = Col end
		end
		if F.Back or Now - T0 > (Args.Timeout or 5) then
			RunService:UnbindFromRenderStep("GunChecks_TEMP_Flash")
			Conn:Disconnect()
			F.Done = true
		end
	end)
	return {Home = F.Home, HomeTransparency = F.HomeTransparency}
end
function Checks.FlashResult()
	local F = Flash
	assert(F, "WatchFlash first")
	while not F.Done do Frames(1) end
	Flash = nil
	return {Seen = F.SeenAt ~= nil, Result = F.Result, Delay = F.TintAt and F.SeenAt and (F.TintAt - F.SeenAt) or nil,
		First = F.First, Back = F.Back, Home = F.Home}
end

-- a real shot: the press (FireInput, as RMB) with the flash watched and the pitch sampled, Camera Shake on
function Checks.RealShot(Args)
	assert(GunAimUI, "no GunAimUI")
	return WithShake(true, function()
		Checks.WatchFlash(Args)
		Frames(3)
		local P0 = Pitch()
		local Rise = 0
		RunService:BindToRenderStep("GunChecks_TEMP_Pitch", LAST, function() Rise = math.max(Rise, Pitch() - P0) end)
		local Pressed = os.clock()
		local Began = FireInput(true)
		FireInput(false)
		local Ok, R = pcall(Checks.FlashResult)
		RunService:UnbindFromRenderStep("GunChecks_TEMP_Pitch")
		if not Ok then error(R, 0) end
		R.Began, R.Rise = Began, Rise
		return R
	end)
end

-- the line of fire: where the muzzle and the aim camera are (computed here, never from the marker)
function Checks.LineGeometry()
	Frames(3)
	return {Muzzle = GunAim.Muzzle(Root().Position), CamPos = Camera.CFrame.Position, Look = Camera.CFrame.LookVector}
end

-- the marker's transparency once the wall Args.Wall has streamed in (or Args.Gone has left), and which line meets it
function Checks.Dim(Args)
	if Args.Wall then assert(workspace:WaitForChild(Args.Wall, 5), "the wall never streamed in") end
	if Args.Gone then
		local T0 = os.clock()
		while workspace:FindFirstChild(Args.Gone) and os.clock() - T0 < 5 do Frames(1) end
		assert(not workspace:FindFirstChild(Args.Gone), "the wall never left the client")
	end
	Frames(5)
	local X = Cross()
	assert(X, "no marker")
	local R = {Transparency = Transp(X)}
	if Args.CFrame then
		local Ray = CrosshairRay()
		local Muzzle = GunAim.Muzzle(Root().Position)
		R.CameraMeets = GunAim.RayBox(Ray.Origin, Ray.Direction.Unit, 200, Args.CFrame, Args.Size) ~= nil
		R.MuzzleMeets = GunAim.RayBox(Muzzle, AimDirection(), 200, Args.CFrame, Args.Size) ~= nil
	end
	return R
end

-- ===== Task 10: touch screens (MobileControls.Active, the aim assist, the hint, FIRE held) =====
-- The touch screen is MobileControls' own test seam, the Player attribute ForceMobileControls: set here on this client
-- (it never reaches the server), only for the length of one check, and cleared after it (and again by Reset).
local MobileControls = require(ReplicatedStorage.Modules.UI.MobileControls)
local function SetTouch(On)
	Player:SetAttribute("ForceMobileControls", On or nil)
	Frames(2)
end
local function TouchActive() -- (nil: not exported; false stays false)
	if type(MobileControls.Active) ~= "function" then return nil end
	return MobileControls.Active()
end
local function HintText()
	local F = UIState.Gui.HUD:FindFirstChild("ShootingMode")
	local L = F and F:FindFirstChild("Hint")
	return L and L.Text
end
local function WaitGone(Name)
	local T0 = os.clock()
	while workspace:FindFirstChild(Name) and os.clock() - T0 < 5 do Frames(1) end
	assert(not workspace:FindFirstChild(Name), Name .. " never left the client")
end
-- the dummy Args.Target where the server put it: in Args.In ("Live": a child of World.Live; "Townsfolk": in its townsfolk
-- folder), its root at Args.At, carrying a TownsfolkId attribute exactly when Args.Folk
local function AssistDummy(Args)
	local Live = workspace.World.Live
	local Parent = Args.In == "Townsfolk" and Live:WaitForChild("Townsfolk", 5) or Live
	assert(Parent, "no World.Live.Townsfolk on the client")
	local function There(M, R)
		return R ~= nil and (R.Position - Args.At).Magnitude < 0.05 and (M:GetAttribute("TownsfolkId") ~= nil) == (Args.Folk == true)
	end
	local T0 = os.clock()
	local M = Parent:FindFirstChild(Args.Target)
	local R = M and M:FindFirstChild("HumanoidRootPart")
	while not There(M, R) and os.clock() - T0 < 5 do
		Frames(1)
		M = Parent:FindFirstChild(Args.Target)
		R = M and M:FindFirstChild("HumanoidRootPart")
	end
	assert(There(M, R), "the dummy " .. Args.Target .. " never reached " .. Parent:GetFullName()
		.. " at its spot on the client" .. (Args.Folk and " with its TownsfolkId" or " without a TownsfolkId"))
	return M, R
end

-- GunAimUI.Assist(the crosshair ray, a point 80 studs along it) with the touch screen on or off (Args.Touch), the dummy
-- in place; Args.Wall: a part that must have streamed in first; Args.Gone: one that must have left; Args.Health: the
-- dummy's Health on THIS client only during the call (the server's dummy is untouched), then put back
function Checks.Assist(Args)
	assert(GunAimUI, "no GunAimUI")
	assert(Player:GetAttribute("ForceMobileControls") == nil, "precondition: ForceMobileControls isn't set before the check")
	local M, R = AssistDummy(Args)
	if Args.Wall then assert(workspace:WaitForChild(Args.Wall, 5), "the wall never streamed in") end
	if Args.Gone then WaitGone(Args.Gone) end
	local H = M:FindFirstChildOfClass("Humanoid")
	local Health = H.Health
	SetTouch(Args.Touch)
	if Args.Health then H.Health = Args.Health end
	local Active = TouchActive()
	local Ray = CrosshairRay()
	local Point = Ray.Origin + Ray.Direction.Unit * 80
	local Ok, Got = pcall(GunAimUI.Assist, Ray, Point)
	if Args.Health then H.Health = Health end
	SetTouch(nil)
	if not Ok then error(Got, 0) end
	return {
		Exported = type(MobileControls.Active) == "function", Active = Active,
		Deg = Deg(Ray.Direction, R.Position - Ray.Origin), Dist = (R.Position - Ray.Origin).Magnitude,
		Picked = typeof(Got) == "Vector3" and (Got - R.Position).Magnitude < 1e-3, Unchanged = Got == Point,
	}
end

-- MobileControls' button Name (its ImageButton and the label on it)
local function TouchButton(Name)
	local Gui = Player.PlayerGui:FindFirstChild("MobileControls")
	local B = Gui and Gui:FindFirstChild(Name, true)
	return Gui, B, B and B:FindFirstChild("Text") and B.Text.Text
end
-- the touch screen in shooting mode: the hint (touch, then the PC's as the control), the buttons, then FIRE held
-- Args.Seconds through ClientActions as MobileControls' Press sends it (Began true; Began false on the release)
function Checks.TouchHold(Args)
	local Ok, R = pcall(function()
		local Out = {}
		SetTouch(true)
		task.wait(Args.HintWait)
		Out.Active, Out.TouchHint = TouchActive(), HintText()
		local Gui, Fire, _ = TouchButton("Fire")
		local _, _, AimText = TouchButton("Aim")
		Out.Enabled, Out.FireShown, Out.AimText = Gui ~= nil and Gui.Enabled, Fire ~= nil and Fire.Visible, AimText
		SetTouch(nil)
		task.wait(Args.HintWait)
		Out.DeskHint = HintText()
		SetTouch(true)
		ClientActions.Run("Fire", true)
		task.wait(Args.Seconds)
		ClientActions.Run("Fire", false)
		return Out
	end)
	ClientActions.Run("Fire", false)
	SetTouch(nil)
	if not Ok then error(R, 0) end
	return R
end
-- STOP on the touch screen: the AIM button's action ("Aim", press and release); then shooting mode and the button's label
function Checks.TouchStop()
	local Ok, R = pcall(function()
		SetTouch(true)
		ClientActions.Run("Aim", true)
		ClientActions.Run("Aim", false)
		local Left = WaitMode(false, 3)
		Frames(3)
		local _, _, AimText = TouchButton("Aim")
		return {Left = Left, AimText = AimText}
	end)
	SetTouch(nil)
	if not Ok then error(R, 0) end
	return R
end

-- ===== The final-review fix (half B) =====
-- B2: lock on to Args.Target and, every frame for Args.Seconds (after everything else in it), how far the marker's
-- centre sits from the target's root as the frame's own camera projects it: the larger of the two axes, in pixels.
-- Only frames with the marker shown and placed on the target (an offset position) count.
function Checks.LockOnMarker(Args)
	local Target = workspace.World.Live:WaitForChild(Args.Target, 5)
	local TRoot = Target and Target:WaitForChild("HumanoidRootPart", 5)
	assert(TRoot, "the lock-on dummy never streamed in")
	assert(LockOn.Target == nil, "precondition: nothing locked")
	local X = Cross()
	assert(X, "no marker")
	local Gui = X:FindFirstAncestorOfClass("ScreenGui")
	local R = {Frames = 0, Max = 0, Locked = false}
	local Ok, Err = pcall(function()
		LockOn.Toggle() -- the module's own API (the Lock Target key)
		Sample(Args.Seconds, function()
			if LockOn.Target ~= Target then return end
			R.Locked = true
			local Pos = X.Position
			if not X.Visible or Pos.X.Scale ~= 0 or Pos.Y.Scale ~= 0 then return end
			local P = TRoot.Position
			local S = Gui.IgnoreGuiInset and Camera:WorldToViewportPoint(P) or Camera:WorldToScreenPoint(P)
			if S.Z <= 0 then return end
			R.Frames += 1
			R.Max = math.max(R.Max, math.abs(S.X - Pos.X.Offset), math.abs(S.Y - Pos.Y.Offset))
		end)
	end)
	if LockOn.Target then LockOn.Release() end
	if not Ok then error(Err, 0) end
	return R
end

-- B4: the weapon skill pressed (ClientActions "WeaponSkill", the key's and the touch button's path) with the aim Args.Deg
-- degrees from the root's facing (ForceAim, as Flick), out of shooting mode; ForceAim stays Args.Hold s (past FaceWait).
-- Args.FaceWait >= 0: GunAimUI.FaceWait for this press (the seam), put back after.
function Checks.FanTurn(Args)
	assert(WaitMode(false, 3), "precondition: ShootingMode off on the client")
	local L = Root().CFrame.LookVector
	local Was = Vector3.new(L.X, 0, L.Z).Unit
	local Aim = CFrame.Angles(0, math.rad(Args.Deg), 0):VectorToWorldSpace(Was)
	local Ok, Err = pcall(function()
		assert(GunAimUI, "no GunAimUI")
		if Args.FaceWait and Args.FaceWait >= 0 then GunAimUI.FaceWait = Args.FaceWait end
		GunAimUI.ForceAim = Aim
		ClientActions.Run("WeaponSkill", true)
		ClientActions.Run("WeaponSkill", false)
		task.wait(Args.Hold)
	end)
	if GunAimUI then
		GunAimUI.ForceAim = nil
		GunAimUI.FaceWait = HomeFaceWait
	end
	if not Ok then error(Err, 0) end
	local L2 = Root().CFrame.LookVector
	return {Turned = Deg(Was, Aim), FacingOff = Deg(Vector3.new(L2.X, 0, L2.Z), Aim)}
end

-- put everything the checks touched back
function Checks.Reset()
	for _, Name in ipairs({"GunChecks_TEMP_Sample", "GunChecks_TEMP_Flash", "GunChecks_TEMP_Pitch", "GunChecks_TEMP_Write"}) do
		pcall(function() RunService:UnbindFromRenderStep(Name) end)
	end
	Player:SetAttribute("ForceMobileControls", nil)
	Flash = nil
	if GunAimUI then
		GunAimUI.FireInput(false)
		GunAimUI.ForceAim = nil
		GunAimUI.HoldGap = HomeHoldGap
		GunAimUI.ShakeOn = HomeShakeOn
		GunAimUI.FaceWait = HomeFaceWait
	end
	if LockOn.Target then LockOn.Release() end
	if Saved then
		local H = Hum()
		if H then H.CameraOffset = Saved.Offset end
		UIS.MouseBehavior = Saved.Mouse
		Saved = nil
	end
	return true
end

Remote.OnClientEvent:Connect(function(Id, Name, Args)
	task.spawn(function()
		local Fn = Checks[Name]
		local Done, Data = pcall(function()
			assert(Fn, "no client check " .. tostring(Name))
			return Fn(Args or {})
		end)
		Remote:FireServer(Id, Done, Data)
	end)
end)
]==]

local SERVER = [==[
-- GunChecks_TEMP_Suite (Play only; made by Art/Studio/Guns/client_checks.lua, gone at Stop): the server half of the gun
-- client checks, a TestKit suite run through LMRunSuite. Expected numbers, worked by hand (TuningConfig PROPOSALs,
-- 2026-10-25), as constants:
--   SHOULDER: Aim.ShoulderOffset (1.75, 0.5, 0), the aim camera's Humanoid.CameraOffset.
--   MAX_SENDS 41: Aim.HoldGap 0.25 s -> at most 10 / 0.25 = 40 requests in a 10 s hold, +1 for the press itself (4 a
--     second, well under the shared bucket's refill of 8: the Mode-off request after the hold always gets through). The
--     hold aims straight down (90 degrees, past Aim.MaxPitch 70), so the server refuses every shot and the loop never
--     waits on a shot: it sends as fast as HoldGap lets it.
--   HOLD_SHOTS 3..4: the Revolver's shot takes Startup 0.12 + Active 0.02 + Recovery 0.42 = 0.56 s, and the next request
--     waits for it (CombatState nil) and for HoldGap: shots at about 0, 0.56+, 1.12+, 1.68+ in a 2 s hold -> 3 or 4.
--   MARKER_AT 40, the marker 1 x 1 x 1: the aim camera's look line runs 1.75 studs right of the muzzle (SHOULDER.X), the
--     stand-in's 1.5 above it, both wider than the marker's 0.5 half-size: the control (the camera's look from the muzzle)
--     misses.
--   LOCK_AT 15 studs ahead (inside LockOn's 60-stud acquire range; the floor is 2000 up, nothing else is near).
--   FLICK 150 degrees: past Aim.MaxYaw 100, so the server refuses the shot unless its root facing has caught up: its copy
--     of the root lags the client's turn by about 0.20-0.27 s (measured 2026-10-25), inside Aim.FlickGrace 0.4 (Ruling 28).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SmokeKit = require(script.Parent.SmokeKit)
local GunKit = require(script.Parent.GunKit)
local WeaponManager = require(ReplicatedStorage.Modules.Managers.WeaponManager)
local Tuning = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig)
local Remote = ReplicatedStorage:WaitForChild("GunChecks_TEMP_Remote")
local Player = Players:GetPlayers()[1]

local SHOULDER = Vector3.new(1.75, 0.5, 0)
local MAX_SENDS = 41
local HOLD_SECONDS, HOLD_MIN, HOLD_MAX = 2, 3, 4
local SHOT_LANDS = 0.4 -- s after the release: a request sent just before it reaches its Strike (Startup 0.12) + replication
local MARKER_AT = 40
local LOCK_AT, LOCK_DEG = 15, 0.5
local FLICK, FLICK_EPS = 150, 1
local FLICK_WAIT = 1.5 -- s: the grace (up to 0.4) + Startup 0.12 + replication, with room
local MODE_NIL_WITHIN = 0.5
local PIXEL = 1
local AHEAD = Vector3.new(0, 0, -1)
local UP = Vector3.new(0, 3, 0) -- an R6 root stands 3 over the floor
-- Task 9 (the plan's numbers, PROPOSAL; GunAimUI's FX table):
--   HOME_COLOR (230, 205, 190), HOME_TRANSPARENCY 0.35: the marker's own ImageColor3 / ImageTransparency (Task 1's
--     survey: Uis.Crosshair is an ImageLabel).
--   HIT_COLOR (255, 90, 70), BLOCKED_COLOR (170, 170, 170): the tints. TINT_WITHIN 0.05 s after LastShotAt reaches the
--     client (GunAimUI reads it in its next render step, one frame: 0.017 s at 60 fps), BACK_AT 0.3 s (the tint lasts
--     0.15). REAL_TINT_WITHIN 0.1 s for a real shot (Ruling: the by-hand flash, measured the same way).
--   The kick (the Revolver's Items.Kick 1.5 degrees, fading to 0 over 0.18 s): the first frame after Kick() shows
--     1.5 x (1 - 0.017 / 0.18) = 1.36 degrees at 60 fps (1.08 even at 20 fps), so a rise of KICK_RISE 0.5 within
--     KICK_TIME 0.18 s; from BACK_AT_KICK 0.25 s (past 0.18) the pitch is back within KICK_BACK 0.1 degrees; with
--     Camera Shake off the pitch never moves more than KICK_NONE 0.1.
--   The bloom: the marker's size x BLOOM 1.25 within BLOOM_WITHIN 0.05 s of Kick() (it lasts 0.1), back to x1 (within
--     BLOOM_EPS) from BLOOM_BACK_AT 0.2 s.
--   The blocked line: a WALL 10 x 10 x 1, WALL_AHEAD 3 studs in front of the muzzle, its right edge halfway between the
--     muzzle's line and the aim camera's (the camera sits SHOULDER.X 1.75 right of the muzzle; the muzzle's line to an
--     aim point 80 studs out is 1.75 x 3 / 80 = 0.07 right at the wall, the camera's 1.75): the muzzle's line meets the
--     wall 3 studs out, about 77 short of the aim point (> 1.5), and the camera's line passes 0.875 clear of it.
--     DIM 0.6 with the wall; HOME_TRANSPARENCY without it.
--   SHOT_AT 15 studs: the real shot's dummy, straight ahead (inside FlinchRange; the shot meets its 4-wide box).
local HOME_COLOR = Color3.fromRGB(230, 205, 190)
local HOME_TRANSPARENCY, DIM, TRANSPARENCY_EPS = 0.35, 0.6, 0.01
local HIT_COLOR, BLOCKED_COLOR = Color3.fromRGB(255, 90, 70), Color3.fromRGB(170, 170, 170)
local TINT_WITHIN, BACK_AT, REAL_TINT_WITHIN = 0.05, 0.3, 0.1
local KICK_RISE, KICK_TIME, BACK_AT_KICK, KICK_BACK, KICK_NONE = 0.5, 0.18, 0.25, 0.1, 0.1
local BLOOM, BLOOM_WITHIN, BLOOM_BACK_AT, BLOOM_EPS = 1.25, 0.05, 0.2, 0.01
local WALL, WALL_AHEAD = Vector3.new(10, 10, 1), 3
local SHOT_AT = 15
local KICK_ARGS = {KickTime = KICK_TIME, BackAt = BACK_AT_KICK, BloomWithin = BLOOM_WITHIN, BloomBackAt = BLOOM_BACK_AT, Seconds = 0.3}
-- Task 10 (touch; the plan's numbers):
--   The assist reaches Aim.TouchAssist 2.5 degrees and the gun's Range + 10 (the Revolver's 70: 80 studs). ASSIST_DEG 2
--     at ASSIST_AT 30 studs from the camera is inside both (0.5 degrees spare, 1.05 studs off the ray); NEAR_DEG 1 (0.52
--     studs off) for the cases that must NOT pick. DEG_EPS 0.2: the measured angle's precondition (the camera may settle
--     a little between the server's placement and the client's call).
--   The dummy's root is put exactly there: turned about the ray's own up (so the angle is exact), facing the player.
--   TOWNSFOLK "Townsfolk": the townsfolk folder in World.Live (Task 1's survey: Workspace.World.Live.Townsfolk).
--   ASSIST_WALL 4 x 4 x 1 at WALL_AT 0.8 of the way from the camera to the dummy (24 studs out, past the player, so the
--     camera's own occlusion never pulls the camera in front of it).
--   HINT_TOUCH / HINT_DESK: HUDUI's hint texts (the brief's touch hint; the PC one unchanged since Task 8). HINT_WAIT
--     0.3 s: HUDUI's UpdateShooting runs every 0.1 s.
--   The FIRE hold: HOLD_SECONDS 2 -> 3-4 shots (as RmbFiresNotFeints: FIRE runs the same FireInput through
--     ClientActions), then none from SHOT_LANDS until AFTER_RELEASE 1 s more (the release stops the loop; Aim.Buffer 0.2).
local ASSIST_DEG, NEAR_DEG, ASSIST_AT, DEG_EPS = 2, 1, 30, 0.2
local TOWNSFOLK = "Townsfolk"
local ASSIST_WALL, WALL_AT = Vector3.new(4, 4, 1), 0.8
local HINT_TOUCH = "SHOOTING MODE · hold FIRE to shoot · STOP to leave"
local HINT_DESK = "SHOOTING MODE  ·  RMB fire  ·  Y leave  ·  M1 still pistol-whips"
local HINT_WAIT, AFTER_RELEASE = 0.3, 1
--   KICK_SETTLE 0.3 s (past KickTime 0.18): KickUndoAfterCameraWrite's look. The camera written back to its pre-kick
--     CFrame in the kick's first frame: the old undo then took the first frame's kick (1.36 degrees at 60 fps) off that
--     level camera, and the view stayed 1.36 down; the guarded undo leaves it level (within KICK_BACK 0.1).
local KICK_SETTLE = 0.3
-- The final-review fix (half B):
--   FOLK_ID: the TownsfolkId a direct child of World.Live carries in AssistIgnoresTownsfolkId (any value marks
--     townsfolk, as DamageManager reads it); the dummy NEAR_DEG 1 off the crosshair, as AssistIgnoresTownsfolk's.
--   LOCK_SECONDS 0.6: LockOnMarkerOnTarget samples from the lock until the camera has settled (LockOn lerps toward its
--     goal each frame); every sampled frame's marker must sit less than PIXEL 1 from the target's root as that frame's
--     camera projects it, on each axis, over at least LOCK_FRAMES 10 frames (0.6 s is 36 at 60 fps). Per axis, because
--     a UDim offset is a whole pixel, truncated toward zero (UDim2.fromOffset(10.7, -3.6) is (10, -3), read in Studio
--     2026-10-25): a marker placed through the right camera is off by [0, 1) on each axis, up to 1.41 px diagonally.
--   FanFacesAim: the aim FLICK 150 degrees from the facing (past Aim.MaxYaw 100), out of shooting mode. FAN_HOLD 0.6 s:
--     ForceAim stays past FaceWait (Aim.FlickGrace 0.4). FAN_WAIT 1.5 s more for the Fan's first shot (its Startup +
--     replication, with room). One shot spends one round: Ammo below the magazine's MaxAmmo.
--   RESTORE: the character attributes every case puts back (B5).
local FOLK_ID = "GunChecks_TEMP"
local LOCK_SECONDS, LOCK_FRAMES = 0.6, 10
local FAN_HOLD, FAN_WAIT = 0.6, 1.5
local RESTORE = {"LastShotAt", "LastShotResult", "WeaponSkillReadyAt", "WeaponSkillCooldown", "WeaponSkillName"}
local function SameColor(A, B)
	return typeof(A) == "Color3" and math.abs(A.R - B.R) + math.abs(A.G - B.G) + math.abs(A.B - B.B) < 3 / 255
end
local function Rgb(C)
	return typeof(C) == "Color3" and ("(%d, %d, %d)"):format(math.round(C.R * 255), math.round(C.G * 255), math.round(C.B * 255)) or tostring(C)
end
local function ShakeNote(S)
	return S and ((" [Camera Shake %s%s]"):format(S.Real and "on" or "off", S.Stubbed and ", stubbed through the seam" or "")) or ""
end
local HOLD_GAP = Remote:GetAttribute("HoldGap") or 0
local NO_FLICK_GRACE = Remote:GetAttribute("NoFlickGrace") == true
local FACE_WAIT = Remote:GetAttribute("FaceWait") or -1

local Replies = {}
Remote.OnServerEvent:Connect(function(P, Id, Done, Data)
	if P == Player and type(Id) == "number" then Replies[Id] = {Done = Done, Data = Data} end
end)
local NextId = 0
local function Send(Name, Args, Timeout)
	NextId += 1
	local Id = NextId
	Remote:FireClient(Player, Id, Name, Args or {})
	local T0 = os.clock()
	while not Replies[Id] and os.clock() - T0 < (Timeout or 10) do task.wait() end
	local R = Replies[Id]
	Replies[Id] = nil
	return R
end
local function Ask(Name, Args, Timeout)
	local R = Send(Name, Args, Timeout)
	if not R then error(Name .. ": no answer from the client in " .. (Timeout or 10) .. " s", 2) end
	if not R.Done then error(Name .. " (client): " .. tostring(R.Data), 2) end
	return R.Data
end
local function Connect()
	for _ = 1, 40 do
		if Send("Ping", nil, 0.25) then return end
	end
	error("the client checker GunChecks_TEMP never answered")
end

-- the gun ready to fire: no reload running, a full magazine
local function Loaded(C)
	local T0 = os.clock()
	while (C:GetAttribute("ReloadingUntil") or 0) > workspace:GetServerTimeNow() and os.clock() - T0 < 3 do task.wait() end
	C:SetAttribute("Ammo", C:GetAttribute("MaxAmmo"))
end

-- the player on GunKit's floor facing -Z, with the test's own Revolver, in Combat Mode and shooting mode
local function Armed(Body)
	local C = Player.Character
	local Root = C.HumanoidRootPart
	local WasCombat, WasAnchored = C:GetAttribute("CombatMode"), Root.Anchored
	local Was = {}
	for _, Name in ipairs(RESTORE) do Was[Name] = C:GetAttribute(Name) end
	local Gun
	SmokeKit.Guarded(Player, function()
		Connect()
		local Top = GunKit.Spot()
		Root.Anchored = true
		C:PivotTo(CFrame.lookAt(Top + UP, Top + UP + AHEAD))
		Ask("Arrive", {Floor = "GunKit_Floor", MinY = Top.Y, Look = AHEAD}, 15)
		Root.Anchored = WasAnchored
		C:SetAttribute("CombatMode", true)
		Gun = WeaponManager.Give(C, "Revolver")
		assert(Gun, "the Revolver given")
		C:SetAttribute("ShootingMode", true)
		Loaded(C)
		Ask("Shooting")
		Body(C)
	end, function() GunKit.Unequip(Player) end, function()
		local Ok, Err = pcall(Ask, "Reset")
		Root.Anchored = WasAnchored
		C:SetAttribute("ShootingMode", nil)
		if Gun then Gun:Destroy() end -- the test's own Revolver (Give's clone), never the player's item
		C:SetAttribute("CombatMode", WasCombat)
		for _, Name in ipairs(RESTORE) do C:SetAttribute(Name, Was[Name]) end -- (after ShootingMode: no flash)
		GunKit.Clean()
		if not Ok then error(Err, 0) end
	end)
end

-- a GunKit dummy whose root sits Dist studs from the camera along the crosshair ray turned Deg degrees, facing back
local function AssistTarget(Name, Deg)
	local R = Ask("Ray")
	local Right = R.Dir:Cross(Vector3.yAxis).Unit
	local Up = Right:Cross(R.Dir).Unit
	local At = R.Origin + CFrame.fromAxisAngle(Up, math.rad(Deg)):VectorToWorldSpace(R.Dir) * ASSIST_AT
	local D = GunKit.Dummy(AHEAD * ASSIST_AT, Name)
	local RootFromPivot = D:GetPivot():ToObjectSpace(D.HumanoidRootPart.CFrame)
	local Flat = Vector3.new(R.Origin.X, At.Y, R.Origin.Z)
	D:PivotTo(CFrame.lookAt(At, Flat) * RootFromPivot:Inverse())
	GunKit.Settle()
	return D, At
end

local Suite = {
	CrosshairRayMatchesMarker = function(T)
		Armed(function()
			local R = Ask("CrosshairMatch")
			T.True(not R.NoMarker, ("no marker: Uis.Crosshair isn't shown in shooting mode (it would be %.2f px off)%s"):format(R.Dist,
				R.StandIn and " (stand-in)" or ""))
			T.True(R.Dist >= 0 and R.Dist <= PIXEL, ("CrosshairRay 50 studs out lands %.2f px from the marker's centre (max %d)"):format(R.Dist, PIXEL))
		end)
	end,

	AimHitsMarkerUnderCrosshair = function(T)
		Armed(function()
			local R = Ask("Ray")
			local Marker = SmokeKit.TempPart({Name = "GunChecks_Marker", Size = Vector3.one, CanCollide = false,
				CFrame = CFrame.new(R.Origin + R.Dir * MARKER_AT)})
			local H = Ask("AimHitsMarker", {Marker = Marker.Name, CFrame = Marker.CFrame, Size = Marker.Size})
			T.True(H.Hit, "RayBox(muzzle, AimDirection()) misses the marker under the crosshair" .. (H.StandIn and " (stand-in)" or ""))
			T.True(not H.ControlHit, "control: RayBox(muzzle, the camera's look) hits the marker")
		end)
	end,

	LockOnAimsAtTarget = function(T)
		Armed(function()
			local D = GunKit.Dummy(AHEAD * LOCK_AT, "GunChecks_LockTarget")
			GunKit.Settle()
			local R = Ask("LockOnAim", {Target = D.Name})
			T.True(R.Locked, "LockOn.Toggle() locked onto the dummy")
			T.True(R.Deg < LOCK_DEG, ("AimDirection() is %.3f degrees off (dummy root - muzzle); max %.1f"):format(R.Deg, LOCK_DEG))
		end)
	end,

	ReleaseRestores = function(T)
		Armed(function(C)
			local On = Ask("CameraState", {Shooting = true})
			T.True(not On.ShiftLock, "precondition: the save's shift lock is off")
			-- positive control: GunAimUI owns the camera while shooting
			T.Eq(On.MouseBehavior, "LockCenter", "MouseBehavior while shooting (control)")
			T.True(On.Offset ~= nil and (On.Offset - SHOULDER).Magnitude < 1e-3, "CameraOffset while shooting (control): " .. tostring(On.Offset))
			T.Eq(On.MarkerVisible, true, "the marker while shooting (control)")
			C:SetAttribute("ShootingMode", nil)
			local Off = Ask("CameraState", {Shooting = false})
			T.Eq(Off.MouseBehavior, "Default", "MouseBehavior after ShootingMode went nil")
			T.True(Off.Offset ~= nil and Off.Offset.Magnitude < 1e-3, "CameraOffset after ShootingMode went nil: " .. tostring(Off.Offset))
			T.Eq(Off.MarkerVisible, false, "the marker after ShootingMode went nil")
		end)
	end,

	HoldLoopUnderBucket = function(T)
		Armed(function(C)
			local R = Ask("HoldLoop", {Seconds = 10, HoldGap = HOLD_GAP}, 20)
			local T0 = os.clock()
			while C:GetAttribute("ShootingMode") and os.clock() - T0 < MODE_NIL_WITHIN do task.wait() end
			local Mode = C:GetAttribute("ShootingMode")
			print(("[GunChecks] HoldLoopUnderBucket: %d Fire requests in 10 s; ShootingMode after: %s"):format(R.Sends, tostring(Mode)))
			T.True(R.Sends <= MAX_SENDS, ("Fire requests in a 10 s hold: %d (max %d)%s"):format(R.Sends, MAX_SENDS,
				HOLD_GAP > 0 and (" [seam HoldGap " .. HOLD_GAP .. "]") or ""))
			-- guard: the shared bucket still has room for the Mode-off request after the hold
			T.True(Mode == nil, ("guard: ShootingMode %s s after the hold's Mode-off request: %s (want nil)"):format(tostring(MODE_NIL_WITHIN), tostring(Mode)))
		end)
	end,

	FlickAndFire = function(T)
		Armed(function(C)
			local Aim = Tuning.Weapons.Guns.Aim
			local Grace = Aim.FlickGrace
			if NO_FLICK_GRACE then Aim.FlickGrace = 0 end
			local Was = C:GetAttribute("LastShotAt")
			local Ok, R = pcall(Ask, "Flick", {Deg = FLICK})
			local T0 = os.clock()
			while Ok and C:GetAttribute("LastShotAt") == Was and os.clock() - T0 < FLICK_WAIT do task.wait() end
			Aim.FlickGrace = Grace
			if not Ok then error(R, 0) end
			T.Eq(R.Began, true, "FireInput(true) in shooting mode")
			T.Near(R.Turned, FLICK, FLICK_EPS, "the flick's turn from the facing")
			T.True(C:GetAttribute("LastShotAt") ~= Was, "the server accepted a shot fired " .. FLICK .. " degrees from the facing in the flick's frame"
				.. (NO_FLICK_GRACE and " [seam: FlickGrace 0]" or ""))
		end)
	end,

	RmbFiresNotFeints = function(T)
		Armed(function(C)
			local N = 0
			local Conn = C:GetAttributeChangedSignal("LastShotAt"):Connect(function() N += 1 end)
			local R = Ask("Hold", {Seconds = HOLD_SECONDS}, 10)
			task.wait(SHOT_LANDS)
			Conn:Disconnect()
			print(("[GunChecks] RmbFiresNotFeints: %d shots in a %d s hold"):format(N, HOLD_SECONDS))
			T.True(N >= HOLD_MIN and N <= HOLD_MAX, ("shots in a %d s hold: %d (want %d-%d)%s"):format(HOLD_SECONDS, N, HOLD_MIN, HOLD_MAX,
				R.StandIn and " (stand-in)" or ""))
			T.Eq(R.Began, true, "FireInput(true) in shooting mode (no Feint)")
			local Off = Ask("ModeOff")
			T.Eq(C:GetAttribute("ShootingMode"), nil, "ShootingMode after the client's Mode-off request")
			T.Eq(Off.Began, false, "FireInput(true) out of shooting mode (the RMB branch feints)")
			T.True(not Off.ShiftLock, "precondition: the save's shift lock is off")
			T.Eq(Off.MouseBehavior, "Default", "MouseBehavior after Mode off")
			T.True(Off.Offset ~= nil and Off.Offset.Magnitude < 1e-3, "CameraOffset after Mode off: " .. tostring(Off.Offset))
			T.Eq(Off.MarkerVisible, false, "the marker after Mode off")
		end)
	end,

	-- Task 9. The Server sets the result and bumps LastShotAt; the marker tints, then shows its own colour again.
	HitMarkerFlashes = function(T)
		Armed(function(C)
			for _, Case in ipairs({{"Hit", HIT_COLOR}, {"Blocked", BLOCKED_COLOR}}) do
				local W = Ask("WatchFlash", {BackAt = BACK_AT})
				T.True(SameColor(W.Home, HOME_COLOR), "precondition: the marker shows its own colour " .. Rgb(HOME_COLOR) .. ", not " .. Rgb(W.Home))
				C:SetAttribute("LastShotResult", Case[1])
				C:SetAttribute("LastShotAt", workspace:GetServerTimeNow())
				local R = Ask("FlashResult")
				print(("[GunChecks] HitMarkerFlashes %s: tint %s after %s s; %.1f s later %s"):format(Case[1], Rgb(R.First),
					R.Delay and ("%.3f"):format(R.Delay) or "never", BACK_AT, Rgb(R.Back)))
				T.True(R.Seen and R.Result == Case[1], "the client saw LastShotAt change with LastShotResult " .. Case[1] .. ": " .. tostring(R.Result))
				T.True(R.Delay ~= nil and R.Delay <= TINT_WITHIN, ("%s: the marker's colour changed %s s after LastShotAt reached the client (max %.2f)")
					:format(Case[1], R.Delay and ("%.3f"):format(R.Delay) or "never", TINT_WITHIN))
				T.True(SameColor(R.First, Case[2]), Case[1] .. ": the tint is " .. Rgb(Case[2]) .. ", got " .. Rgb(R.First))
				T.True(SameColor(R.Back, HOME_COLOR), ("%s: the marker's own colour again %.1f s later, got %s"):format(Case[1], BACK_AT, Rgb(R.Back)))
				task.wait(0.2)
			end
		end)
	end,

	-- Task 9. A wall on the muzzle's line of fire but not the aim camera's: the marker dims, and clears without it.
	BlockedLineDims = function(T)
		Armed(function()
			local Before = Ask("Dim", {})
			T.Near(Before.Transparency, HOME_TRANSPARENCY, TRANSPARENCY_EPS, "control: the marker's transparency with nothing in the way")
			local G = Ask("LineGeometry")
			local Look = Vector3.new(G.Look.X, 0, G.Look.Z).Unit
			local Right = Look:Cross(Vector3.yAxis).Unit
			local CamSide = (G.CamPos - G.Muzzle):Dot(Right)
			T.True(CamSide > 1, ("precondition: the aim camera sits right of the muzzle (%.2f studs; SHOULDER.X %.2f)"):format(CamSide, SHOULDER.X))
			local Centre = G.Muzzle + Look * WALL_AHEAD + Right * (CamSide / 2 - WALL.X / 2)
			local Wall = SmokeKit.TempPart({Name = "GunChecks_Wall", Size = WALL, CFrame = CFrame.lookAt(Centre, Centre + Look)})
			local With = Ask("Dim", {Wall = Wall.Name, CFrame = Wall.CFrame, Size = Wall.Size})
			print(("[GunChecks] BlockedLineDims: camera %.2f right of the muzzle; transparency %.3f without the wall, %.3f with it")
				:format(CamSide, Before.Transparency, With.Transparency))
			T.True(With.MuzzleMeets, "precondition: the muzzle's line of fire meets the wall")
			T.True(not With.CameraMeets, "precondition: the aim camera's line passes the wall")
			T.Near(With.Transparency, DIM, TRANSPARENCY_EPS, "the marker's transparency with the line of fire blocked")
			Wall:Destroy() -- only the wall (ClearTemp would take the floor too)
			local After = Ask("Dim", {Gone = "GunChecks_Wall"})
			T.Near(After.Transparency, HOME_TRANSPARENCY, TRANSPARENCY_EPS, "the marker's own transparency again with the wall gone")
		end)
	end,

	-- Task 9. Kick() with Camera Shake on: the pitch rises, then is back.
	KickRecovers = function(T)
		Armed(function()
			local Args = table.clone(KICK_ARGS)
			Args.Shake = true
			local R = Ask("Kick", Args)
			print(("[GunChecks] KickRecovers: rise %.3f, later %.4f off%s"):format(R.Rise, R.Late, ShakeNote(R.Shake)))
			T.True(R.Rise >= KICK_RISE, ("the pitch rose %.2f degrees within %.2f s of Kick() (min %.1f)%s"):format(R.Rise, KICK_TIME, KICK_RISE, ShakeNote(R.Shake)))
			T.True(R.Late <= KICK_BACK, ("the pitch %.3f degrees off from %.2f s (max %.1f)"):format(R.Late, BACK_AT_KICK, KICK_BACK))
		end)
	end,

	-- Ruling: Camera Shake off means no kick, and the bloom still plays. The seam reads the setting as the game does; the
	-- path the owner's save doesn't have is stubbed through it (never the Settings themselves).
	KickRespectsCameraShake = function(T)
		Armed(function()
			local On = table.clone(KICK_ARGS) On.Shake = true
			local Off = table.clone(KICK_ARGS) Off.Shake = false
			local A = Ask("Kick", On)
			T.True(A.Shake.Seam, "GunAimUI.ShakeOn exists (the Camera Shake read)")
			T.Eq(A.Shake.Read, A.Shake.Real, "GunAimUI.ShakeOn() reads Settings > Camera Shake as BasicVFX does (the Player attribute CameraShake ~= false)")
			T.True(A.Rise >= KICK_RISE, ("control: Camera Shake on, the pitch rose %.2f degrees (min %.1f)%s"):format(A.Rise, KICK_RISE, ShakeNote(A.Shake)))
			task.wait(0.2)
			local B = Ask("Kick", Off)
			print(("[GunChecks] KickRespectsCameraShake: on rise %.3f%s; off rise %.4f, bloom x%.3f, later x%.4f off%s")
				:format(A.Rise, ShakeNote(A.Shake), B.Rise, B.Bloom, B.BloomLate, ShakeNote(B.Shake)))
			T.True(B.Rise <= KICK_NONE, ("Camera Shake off: the pitch rose %.3f degrees (max %.1f)%s"):format(B.Rise, KICK_NONE, ShakeNote(B.Shake)))
			T.True(B.Late <= KICK_NONE, ("Camera Shake off: the pitch %.3f degrees off later (max %.1f)"):format(B.Late, KICK_NONE))
			T.Near(B.Bloom, BLOOM, BLOOM_EPS, "Camera Shake off: the marker still blooms (size x)")
			T.True(B.BloomLate <= BLOOM_EPS, ("the marker's own size again from %.1f s (off by x%.3f)"):format(BLOOM_BACK_AT, B.BloomLate))
		end)
	end,

	-- Ruling: the by-hand "shoot a dummy, see the flash and the kick", as a real shot (RMB's FireInput) at a GunKit dummy.
	RealShotFlashesAndKicks = function(T)
		Armed(function(C)
			local D = GunKit.Dummy(AHEAD * SHOT_AT, "GunChecks_ShotTarget")
			GunKit.Settle()
			local Hum = D:FindFirstChildOfClass("Humanoid")
			local Hp = Hum.Health
			local R = Ask("RealShot", {BackAt = BACK_AT}, 15)
			print(("[GunChecks] RealShotFlashesAndKicks: %s, dummy %.1f -> %.1f; flash %s after %s s; pitch rise %.3f%s")
				:format(tostring(C:GetAttribute("LastShotResult")), Hp, Hum.Health, Rgb(R.First),
				R.Delay and ("%.3f"):format(R.Delay) or "never", R.Rise, ShakeNote(R.Shake)))
			T.Eq(R.Began, true, "FireInput(true) in shooting mode")
			T.Eq(C:GetAttribute("LastShotResult"), "Hit", "the real shot's LastShotResult")
			T.True(Hum.Health < Hp, ("the dummy lost health (%.1f -> %.1f)"):format(Hp, Hum.Health))
			T.True(R.Seen, "the client saw LastShotAt change")
			T.True(R.Delay ~= nil and R.Delay <= REAL_TINT_WITHIN, ("the marker flashed %s s after LastShotAt reached the client (max %.1f)")
				:format(R.Delay and ("%.3f"):format(R.Delay) or "never", REAL_TINT_WITHIN))
			T.True(SameColor(R.First, HIT_COLOR), "the flash is the Hit tint " .. Rgb(HIT_COLOR) .. ", got " .. Rgb(R.First))
			T.True(R.Rise >= KICK_RISE, ("the camera's pitch rose %.2f degrees after the shot (min %.1f)%s"):format(R.Rise, KICK_RISE, ShakeNote(R.Shake)))
		end)
	end,

	-- Task 10 (Task 9's review): a camera write between the kick and its undo (an absolute CFrame, as MasteryUI's lookAt)
	-- has dropped the kick already; the undo must not take it off again (the view would stay that far down).
	KickUndoAfterCameraWrite = function(T)
		Armed(function()
			local R = Ask("KickThenWrite", {At = KICK_SETTLE})
			print(("[GunChecks] KickUndoAfterCameraWrite: the kick %.3f when the camera was written; %.4f degrees off %.1f s later")
				:format(R.Kicked or -1, R.Off or -1, KICK_SETTLE))
			T.True(R.Kicked ~= nil and R.Kicked >= KICK_RISE, ("precondition: the kick was on the camera when it was written (%.2f degrees, min %.1f)")
				:format(R.Kicked or -1, KICK_RISE))
			T.True(math.abs(R.Off) <= KICK_BACK, ("the pitch %.3f degrees off %.1f s after a camera write in the kick's first frame (max %.1f)")
				:format(R.Off, KICK_SETTLE, KICK_BACK))
		end)
	end,

	-- Task 10. The touch assist works on a touch screen (ForceMobileControls, MobileControls' own seam) and nowhere else.
	AssistOnTouchOnly = function(T)
		Armed(function()
			local D, At = AssistTarget("GunChecks_AssistTarget", ASSIST_DEG)
			local On = Ask("Assist", {Target = D.Name, In = "Live", At = At, Touch = true})
			print(("[GunChecks] AssistOnTouchOnly: the dummy %.3f degrees off at %.1f studs; touch: active %s, picked %s")
				:format(On.Deg, On.Dist, tostring(On.Active), tostring(On.Picked)))
			T.True(On.Exported, "MobileControls.Active is exported")
			T.Near(On.Deg, ASSIST_DEG, DEG_EPS, "precondition: the dummy's root is off the crosshair ray by (degrees)")
			T.Near(On.Dist, ASSIST_AT, 0.1, "precondition: the dummy's root is this far from the camera (studs)")
			T.Eq(On.Active, true, "MobileControls.Active() with ForceMobileControls set")
			T.True(On.Picked, ("touch: Assist picks the dummy %d degrees off the crosshair at %d studs"):format(ASSIST_DEG, ASSIST_AT))
			local Off = Ask("Assist", {Target = D.Name, In = "Live", At = At, Touch = false})
			T.Eq(Off.Active, false, "precondition: MobileControls.Active() without ForceMobileControls (Studio on a PC)")
			T.True(Off.Unchanged and not Off.Picked, "no touch screen: Assist returns Point unchanged")
		end)
	end,

	-- Task 10. Townsfolk (World.Live's townsfolk folder) are never picked; the same dummy as a child of World.Live is.
	-- A place without the folder (Foundry) gets one in its Play copy for the case, removed after (final fix B6).
	AssistIgnoresTownsfolk = function(T)
		Armed(function()
			local Live = workspace.World.Live
			local Folk = Live:FindFirstChild(TOWNSFOLK)
			local Made = nil
			if not Folk then
				Made = Instance.new("Folder")
				Made.Name = TOWNSFOLK
				Made.Parent = Live
				Folk = Made
			end
			local Ok, Err = pcall(function()
				local D, At = AssistTarget("GunChecks_AssistFolk", NEAR_DEG)
				D.Parent = Folk
				local In = Ask("Assist", {Target = D.Name, In = "Townsfolk", At = At, Touch = true})
				print(("[GunChecks] AssistIgnoresTownsfolk: %.3f degrees off; in the townsfolk folder%s picked %s")
					:format(In.Deg, Made and " (made for the case)" or "", tostring(In.Picked)))
				T.Near(In.Deg, NEAR_DEG, DEG_EPS, "precondition: the dummy's root is off the crosshair ray by (degrees)")
				T.Eq(In.Active, true, "MobileControls.Active() with ForceMobileControls set")
				T.True(In.Unchanged and not In.Picked, ("a dummy in World.Live.%s %d degree off the crosshair isn't picked"):format(TOWNSFOLK, NEAR_DEG))
				D.Parent = Live
				local Direct = Ask("Assist", {Target = D.Name, In = "Live", At = At, Touch = true})
				T.True(Direct.Picked, "control: the same dummy as a direct child of World.Live is picked")
			end)
			if Made then Made:Destroy() end
			if not Ok then error(Err, 0) end
		end)
	end,

	-- Final fix B1. A Model carrying TownsfolkId is townsfolk wherever it sits: a direct child of World.Live with one isn't
	-- picked; the same dummy without it is (the control).
	AssistIgnoresTownsfolkId = function(T)
		Armed(function()
			local D, At = AssistTarget("GunChecks_AssistFolkId", NEAR_DEG)
			D:SetAttribute("TownsfolkId", FOLK_ID)
			local In = Ask("Assist", {Target = D.Name, In = "Live", At = At, Touch = true, Folk = true})
			print(("[GunChecks] AssistIgnoresTownsfolkId: %.3f degrees off; with TownsfolkId picked %s"):format(In.Deg, tostring(In.Picked)))
			T.Near(In.Deg, NEAR_DEG, DEG_EPS, "precondition: the dummy's root is off the crosshair ray by (degrees)")
			T.Eq(In.Active, true, "MobileControls.Active() with ForceMobileControls set")
			T.True(In.Unchanged and not In.Picked, ("a direct child of World.Live carrying TownsfolkId %d degree off the crosshair isn't picked"):format(NEAR_DEG))
			D:SetAttribute("TownsfolkId", nil)
			local Plain = Ask("Assist", {Target = D.Name, In = "Live", At = At, Touch = true, Folk = false})
			T.True(Plain.Picked, "control: the same dummy without TownsfolkId is picked")
		end)
	end,

	-- Final fix B2. Locked on, the marker sits on the target as each frame's final camera shows it (after LockOn's lerp).
	LockOnMarkerOnTarget = function(T)
		Armed(function()
			local D = GunKit.Dummy(AHEAD * LOCK_AT, "GunChecks_LockMarker")
			GunKit.Settle()
			local R = Ask("LockOnMarker", {Target = D.Name, Seconds = LOCK_SECONDS})
			print(("[GunChecks] LockOnMarkerOnTarget: %d frames; the marker at most %.2f px from the target on an axis"):format(R.Frames, R.Max))
			T.True(R.Locked, "LockOn.Toggle() locked onto the dummy")
			T.True(R.Frames >= LOCK_FRAMES, ("precondition: the marker was on the target in %d sampled frames (min %d)"):format(R.Frames, LOCK_FRAMES))
			T.True(R.Max < PIXEL, ("the marker sat %.2f px (on an axis) from the target's root through the frame's camera (under %d)"):format(R.Max, PIXEL))
		end)
	end,

	-- Final fix B4. G (the weapon skill: Fan the Hammer) with the aim 150 degrees from the facing, out of shooting mode:
	-- the client turns to face the aim first, so the server takes the aim and the Fan fires.
	FanFacesAim = function(T)
		Armed(function(C)
			C:SetAttribute("ShootingMode", nil)
			local T0 = os.clock()
			while (C:GetAttribute("WeaponSkillReadyAt") or 0) > workspace:GetServerTimeNow() and os.clock() - T0 < 5 do task.wait() end
			local Max, Was, Stamina = C:GetAttribute("MaxAmmo"), C:GetAttribute("LastShotAt"), C:GetAttribute("Stamina")
			T.Eq(C:GetAttribute("Ammo"), Max, "precondition: a full magazine")
			local R = Ask("FanTurn", {Deg = FLICK, Hold = FAN_HOLD, FaceWait = FACE_WAIT}, 10)
			T0 = os.clock()
			while C:GetAttribute("LastShotAt") == Was and os.clock() - T0 < FAN_WAIT do task.wait() end
			local Fired = C:GetAttribute("LastShotAt") ~= Was
			T0 = os.clock()
			while C:GetAttribute("CombatState") ~= nil and os.clock() - T0 < 3 do task.wait() end -- the Fan ends
			print(("[GunChecks] FanFacesAim: aim %.1f degrees from the facing; the client root then %.1f off the aim; fired %s, Ammo %s / %s; Stamina %s -> %s%s")
				:format(R.Turned, R.FacingOff, tostring(Fired), tostring(C:GetAttribute("Ammo")), tostring(Max),
				tostring(Stamina), tostring(C:GetAttribute("Stamina")),
				FACE_WAIT >= 0 and (" [seam FaceWait " .. FACE_WAIT .. "]") or ""))
			T.Near(R.Turned, FLICK, FLICK_EPS, "precondition: the aim's turn from the facing")
			T.True(Fired, ("the Fan aimed %d degrees from the facing fired (the server took the aim)%s"):format(FLICK,
				FACE_WAIT >= 0 and (" [seam FaceWait " .. FACE_WAIT .. "]") or ""))
			T.True((C:GetAttribute("Ammo") or Max) < Max, "the Fan spent rounds")
		end)
	end,

	-- Task 10. Never a target the camera can't see (a wall on the camera's line to it), nor a dead one.
	AssistSkipsHiddenAndDead = function(T)
		Armed(function()
			local D, At = AssistTarget("GunChecks_AssistHidden", NEAR_DEG)
			local Args = {Target = D.Name, In = "Live", At = At, Touch = true}
			local Seen = Ask("Assist", Args)
			T.Near(Seen.Deg, NEAR_DEG, DEG_EPS, "precondition: the dummy's root is off the crosshair ray by (degrees)")
			T.True(Seen.Picked, "control: the dummy in plain sight is picked")
			local R = Ask("Ray")
			local Mid = R.Origin + (At - R.Origin) * WALL_AT
			local Wall = SmokeKit.TempPart({Name = "GunChecks_AssistWall", Size = ASSIST_WALL, CanCollide = false,
				CFrame = CFrame.lookAt(Mid, At)})
			local Hidden = Ask("Assist", {Target = D.Name, In = "Live", At = At, Touch = true, Wall = Wall.Name})
			T.True(Hidden.Unchanged and not Hidden.Picked, "a dummy behind a wall (on the camera's line to it) isn't picked")
			Wall:Destroy() -- only the wall (ClearTemp would take the floor too)
			local Dead = Ask("Assist", {Target = D.Name, In = "Live", At = At, Touch = true, Gone = "GunChecks_AssistWall", Health = 0})
			T.True(Dead.Unchanged and not Dead.Picked, "a dead dummy (Health 0) isn't picked")
		end)
	end,

	-- Task 10. The touch screen in shooting mode: the hint, FIRE and STOP shown; FIRE held fires again and again and
	-- stops at the release; STOP leaves shooting mode.
	TouchHintAndHold = function(T)
		Armed(function(C)
			local N = 0
			local Conn = C:GetAttributeChangedSignal("LastShotAt"):Connect(function() N += 1 end)
			local Ok, R = pcall(Ask, "TouchHold", {Seconds = HOLD_SECONDS, HintWait = HINT_WAIT}, 15)
			task.wait(SHOT_LANDS)
			local Held = N
			task.wait(AFTER_RELEASE)
			Conn:Disconnect()
			if not Ok then error(R, 0) end
			print(("[GunChecks] TouchHintAndHold: touch hint %q; PC hint %q; %d shots in a %d s FIRE hold, %d more after the release")
				:format(tostring(R.TouchHint), tostring(R.DeskHint), Held, HOLD_SECONDS, N - Held))
			T.Eq(R.Active, true, "MobileControls.Active() with ForceMobileControls set")
			T.Eq(R.TouchHint, HINT_TOUCH, "the hint on a touch screen")
			T.Eq(R.DeskHint, HINT_DESK, "control: the hint on a PC")
			T.Eq(R.Enabled, true, "the touch buttons show")
			T.Eq(R.FireShown, true, "FIRE shows in shooting mode")
			T.Eq(R.AimText, "STOP", "the AIM button reads STOP in shooting mode")
			T.True(Held >= HOLD_MIN and Held <= HOLD_MAX, ("shots in a %d s FIRE hold: %d (want %d-%d)"):format(HOLD_SECONDS, Held, HOLD_MIN, HOLD_MAX))
			T.Eq(N - Held, 0, ("shots %.1f-%.1f s after FIRE's release"):format(SHOT_LANDS, SHOT_LANDS + AFTER_RELEASE))
			local S = Ask("TouchStop")
			T.True(S.Left, "STOP: ShootingMode off on the client")
			T.Eq(C:GetAttribute("ShootingMode"), nil, "STOP: ShootingMode on the server")
			T.Eq(S.AimText, "AIM", "the button reads AIM again")
		end)
	end,
}

local Only = Remote:GetAttribute("Only") or ""
if Only ~= "" then
	local Keep = {}
	for Name in Only:gmatch("[^,%s]+") do
		assert(Suite[Name], "no check " .. Name)
		Keep[Name] = Suite[Name]
	end
	Suite = Keep
end
return Suite
]==]

-- ===== The runner (Server, Play) =====
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
if not (RunService:IsRunning() and RunService:IsServer()) then return "REFUSED: run in the Server data model in Play" end
local Run = ServerStorage:FindFirstChild("LMRunSuite")
if not Run then return "REFUSED: no ServerStorage.LMRunSuite (the Play protocol's hook)" end
local P = Players:GetPlayers()[1]
if not (P and P.Character) then return "REFUSED: no test player character" end
local Held = P.Character:FindFirstChildOfClass("Tool")
if Held then return "REFUSED: the character holds a Tool (" .. Held.Name .. "); the Play protocol's step 4" end

local function Clear()
	for _, X in ipairs({ReplicatedStorage:FindFirstChild("GunChecks_TEMP_Remote"),
		ServerStorage.RenseiTests:FindFirstChild("GunChecks_TEMP_Suite"),
		P:FindFirstChild("PlayerGui") and P.PlayerGui:FindFirstChild("GunChecks_TEMP")}) do
		if X then X:Destroy() end
	end
end
Clear()
local Remote = Instance.new("RemoteEvent")
Remote.Name = "GunChecks_TEMP_Remote"
Remote:SetAttribute("Only", ONLY)
Remote:SetAttribute("HoldGap", HOLD_GAP)
Remote:SetAttribute("NoFlickGrace", NO_FLICK_GRACE)
Remote:SetAttribute("FaceWait", FACE_WAIT)
Remote.Parent = ReplicatedStorage
local Suite = Instance.new("ModuleScript")
Suite.Name = "GunChecks_TEMP_Suite"
Suite.Source = SERVER
Suite.Parent = ServerStorage.RenseiTests
local Local = Instance.new("LocalScript")
Local.Name = "GunChecks_TEMP"
Local.Source = CLIENT
Local.Parent = P:WaitForChild("PlayerGui")
local Ok, Res = pcall(function() return Run:Invoke("GunChecks_TEMP_Suite") end)
Clear()
return Ok and Res or ("ERROR " .. tostring(Res))

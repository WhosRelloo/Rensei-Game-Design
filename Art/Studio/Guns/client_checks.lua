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
--   HOLD_GAP: GunAimUI.HoldGap for HoldLoopUnderBucket (0.1 = the first draft's loop);
--   NO_FLICK_DEFER: GunAimUI.FlickDefer = false for FlickAndFire (today's same-frame send).
-- ONLY: "" runs every check; else a comma list of check names.
local ONLY = ""
local HOLD_GAP = 0
local NO_FLICK_DEFER = false

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
	if Args.NoDefer then GunAimUI.FlickDefer = false end
	local F = Camera.Focus.Position
	Camera.CFrame = CFrame.new(F) * Turn * CFrame.new(-F) * Camera.CFrame
	GunAimUI.ForceAim = Aim
	local Began = FireInput(true)
	FireInput(false)
	task.wait(0.3)
	GunAimUI.ForceAim = nil
	GunAimUI.FlickDefer = true
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

-- put everything the checks touched back
function Checks.Reset()
	if GunAimUI then
		GunAimUI.FireInput(false)
		GunAimUI.ForceAim = nil
		GunAimUI.HoldGap = HomeHoldGap
		GunAimUI.FlickDefer = true
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
--   MAX_SENDS 41: Aim.HoldGap 0.25 s -> at most 10 / 0.25 = 40 requests in a 10 s hold, +1 for the press itself. The
--     hold aims straight down (90 degrees, past Aim.MaxPitch 70), so the server refuses every shot and the loop never
--     waits on a shot: it sends as fast as HoldGap lets it.
--   HOLD_SHOTS 3..4: the Revolver's shot takes Startup 0.12 + Active 0.02 + Recovery 0.42 = 0.56 s, and the next request
--     waits for it (CombatState nil) and for HoldGap: shots at about 0, 0.56+, 1.12+, 1.68+ in a 2 s hold -> 3 or 4.
--   MARKER_AT 40, the marker 1 x 1 x 1: the aim camera's look line runs 1.75 studs right of the muzzle (SHOULDER.X), the
--     stand-in's 1.5 above it, both wider than the marker's 0.5 half-size: the control (the camera's look from the muzzle)
--     misses.
--   LOCK_AT 15 studs ahead (inside LockOn's 60-stud acquire range; the floor is 2000 up, nothing else is near).
--   FLICK 150 degrees: past Aim.MaxYaw 100, so the server refuses the shot unless its root facing has caught up.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SmokeKit = require(script.Parent.SmokeKit)
local GunKit = require(script.Parent.GunKit)
local WeaponManager = require(ReplicatedStorage.Modules.Managers.WeaponManager)
local Remote = ReplicatedStorage:WaitForChild("GunChecks_TEMP_Remote")
local Player = Players:GetPlayers()[1]

local SHOULDER = Vector3.new(1.75, 0.5, 0)
local MAX_SENDS = 41
local HOLD_SECONDS, HOLD_MIN, HOLD_MAX = 2, 3, 4
local SHOT_LANDS = 0.4 -- s after the release: a request sent just before it reaches its Strike (Startup 0.12) + replication
local MARKER_AT = 40
local LOCK_AT, LOCK_DEG = 15, 0.5
local FLICK, FLICK_EPS = 150, 1
local MODE_NIL_WITHIN = 0.5
local PIXEL = 1
local AHEAD = Vector3.new(0, 0, -1)
local UP = Vector3.new(0, 3, 0) -- an R6 root stands 3 over the floor
local HOLD_GAP = Remote:GetAttribute("HoldGap") or 0
local NO_FLICK_DEFER = Remote:GetAttribute("NoFlickDefer") == true

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
		GunKit.Clean()
		if not Ok then error(Err, 0) end
	end)
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
			-- both results in one line, so a RED run shows whether the Mode request was dropped too
			T.True(R.Sends <= MAX_SENDS and Mode == nil, ("Fire requests in a 10 s hold: %d (max %d); ShootingMode %s s after the hold's Mode-off request: %s (want nil)%s")
				:format(R.Sends, MAX_SENDS, tostring(MODE_NIL_WITHIN), tostring(Mode), HOLD_GAP > 0 and (" [seam HoldGap " .. HOLD_GAP .. "]") or ""))
		end)
	end,

	FlickAndFire = function(T)
		Armed(function(C)
			local Was = C:GetAttribute("LastShotAt")
			local R = Ask("Flick", {Deg = FLICK, NoDefer = NO_FLICK_DEFER})
			local T0 = os.clock()
			while C:GetAttribute("LastShotAt") == Was and os.clock() - T0 < 1 do task.wait() end
			T.Eq(R.Began, true, "FireInput(true) in shooting mode")
			T.Near(R.Turned, FLICK, FLICK_EPS, "the flick's turn from the facing")
			T.True(C:GetAttribute("LastShotAt") ~= Was, "the server accepted a shot fired " .. FLICK .. " degrees from the facing in the flick's frame"
				.. (NO_FLICK_DEFER and " [seam: no defer]" or ""))
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
Remote:SetAttribute("NoFlickDefer", NO_FLICK_DEFER)
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

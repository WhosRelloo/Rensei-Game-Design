-- client_checks.lua (swim revamp Task 5, 2026-10-26; Task 6 adds its checks here): the CLIENT checks of the swim
-- controller (Modules.Managers.SwimController) and SwimClient. Play only, run from the SERVER data model:
--   python -I Art/Tools/rbxc.py luau "placeId: <id>" Server @Art/Studio/Swim/client_checks.lua
-- It is a committed test script, not a RenseiTests suite, because the server VM can't see the client. What it does
-- (everything it makes is a Play copy and vanishes at Stop; it also removes it all before returning):
--   * makes the RemoteEvent ReplicatedStorage.SwimChecks_TEMP_Remote;
--   * makes the LocalScript SwimChecks_TEMP (CLIENT below) in the test player's PlayerGui, so the checks run in the
--     game's client VM and require the SAME SwimController the game runs;
--   * waits (at most 120 s) for the client's results over the RemoteEvent and returns "PASS n / FAIL n" plus one
--     line per check.
-- The client half moves the player's own character into the water at a surveyed spot (Task 1's survey, the same
-- spots as RenseiTests.SwimKit), drives the controller through its real inputs (ClientActions "SwimDive" /
-- "SwimRise", the touch path) and SwimController.TestMove (the tests-only move vector), points a Scriptable camera,
-- and ALWAYS puts back the character's CFrame and the camera. A dive stays under for well under the 15 s of air.
-- ONLY: "" runs every check; else a comma list of check names.
local ONLY = ""

local CLIENT = [==[
-- SwimChecks_TEMP (Play only; made by Art/Studio/Swim/client_checks.lua, gone at Stop): the client half of the swim checks.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remote = ReplicatedStorage:WaitForChild("SwimChecks_TEMP_Remote", 30)
local ONLY = script:GetAttribute("Only") or ""
local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Sw = require(ReplicatedStorage.Modules.Data.Rensei.TuningConfig).Swim
local ClientActions = require(ReplicatedStorage.Modules.Managers.ClientActions)
local AnimationManager = require(ReplicatedStorage.Modules.Managers.AnimationManager)

local Results = {}
local function Report() Remote:FireServer(Results) end

local Ok, SC = pcall(function() return require(ReplicatedStorage.Modules.Managers:FindFirstChild("SwimController")) end)
if not Ok or type(SC) ~= "table" or not SC.Start then
	for _, N in ipairs({"PlaceholderSlotsLoad", "LevelAtTheSurface", "DiveGoesUnder", "SteersDown", "RisesToSurface",
		"NoDiveInTheShallows", "ShiftLockYields"}) do
		table.insert(Results, {N, false, "no SwimController: " .. tostring(SC)})
	end
	Report()
	return
end

-- the surveyed spots (Art/Studio/Swim/survey_*.json; the same as RenseiTests.SwimKit). Yaw = the swim direction (+X:
-- room to swim in both places); Scale = the test's W strength (Ye's Mill Pond is small)
local SPOTS = {
	[109591196441030] = {Main = {At = Vector3.new(488, 3, -148), Deep = true, Scale = 1, DiveDepth = 2}},
	[106992859583940] = {Main = {At = Vector3.new(-112, 5.2, -552), Deep = false, Scale = 0.4, DiveDepth = 0.5},
		Creek = {At = Vector3.new(-375, 5.2, -527)}},
}
local Spots = SPOTS[game.PlaceId] or {}

local function Char() return Player.Character end
local function Root() return Char() and Char():FindFirstChild("HumanoidRootPart") end
local function Head() return Char() and Char():FindFirstChild("Head") end
local function Hum() return Char() and Char():FindFirstChildOfClass("Humanoid") end
local function Frames(N) for _ = 1, N or 1 do RunService.RenderStepped:Wait() end end
local SurfRay = RaycastParams.new()
SurfRay.FilterType = Enum.RaycastFilterType.Include
SurfRay.IgnoreWater = false
local function Surface()
	SurfRay.FilterDescendantsInstances = {workspace.Terrain}
	local H = workspace:Raycast(Root().Position + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), SurfRay)
	return H and H.Material == Enum.Material.Water and H.Position.Y or nil
end
local function HeadDepth() local S = Surface() return S and S - Head().Position.Y or -99 end

-- the camera: Scriptable, looking along +X pitched Deg down, kept on the character each frame
local CamDeg = 0
local CamConn = nil
local function Aim(Deg) CamDeg = Deg end
local function CamStart()
	Camera.CameraType = Enum.CameraType.Scriptable
	CamConn = RunService:BindToRenderStep("SwimChecksCam", Enum.RenderPriority.Camera.Value + 1, function()
		local R = Root()
		if not R then return end
		local Look = CFrame.Angles(0, -math.pi / 2, 0) * CFrame.Angles(-math.rad(CamDeg), 0, 0)
		Camera.CFrame = CFrame.new(R.Position + Vector3.new(0, 3, 0)) * Look * CFrame.new(0, 0, 10)
	end)
end
local function CamStop()
	pcall(function() RunService:UnbindFromRenderStep("SwimChecksCam") end)
	Camera.CameraType = Enum.CameraType.Custom
end

-- put the character floating at a spot and wait for the controller (Mode set) up to 4 s
local function FloatAt(Spot)
	SC.TestMove = nil
	ClientActions.Run("SwimDive", false)
	ClientActions.Run("SwimRise", false)
	local R = Root()
	R.CFrame = CFrame.lookAt(Spot.At - Vector3.new(0, Sw.RootBelowSurface, 0), Spot.At - Vector3.new(0, Sw.RootBelowSurface, 0) + Vector3.new(1, 0, 0))
	R.AssemblyLinearVelocity = Vector3.zero
	local T0 = os.clock()
	repeat Frames(1) until (SC.Mode == "Surface" and os.clock() - T0 > 1) or os.clock() - T0 > 4
	return SC.Mode == "Surface"
end
local function Tap(Action) ClientActions.Run(Action, true) Frames(2) ClientActions.Run(Action, false) end

local Checks = {}
local Order = {}
local function Check(Name, Fn) table.insert(Order, Name) Checks[Name] = Fn end

Check("PlaceholderSlotsLoad", function()
	local C = Char()
	return AnimationManager.Has(C, "Swim_Dive") and AnimationManager.Has(C, "Swim_Surface") and AnimationManager.Has(C, "Swim_Idle"),
		("Has: Swim_Dive %s, Swim_Surface %s, Swim_Idle %s"):format(tostring(AnimationManager.Has(C, "Swim_Dive")),
			tostring(AnimationManager.Has(C, "Swim_Surface")), tostring(AnimationManager.Has(C, "Swim_Idle")))
end)

Check("LevelAtTheSurface", function()
	local S = Spots.Main
	if not FloatAt(S) then return false, "the controller didn't start (Mode " .. tostring(SC.Mode) .. ")" end
	Aim(60)
	local X0 = Root().Position.X
	SC.TestMove = Vector3.new(0, 0, -S.Scale)
	local Worst = -99
	local T0 = os.clock()
	while os.clock() - T0 < 2 do Frames(1) Worst = math.max(Worst, HeadDepth()) end
	SC.TestMove = nil
	local Moved = Root().Position.X - X0
	return Worst <= Sw.SurfaceBand and Moved > 8 and SC.Mode == "Surface",
		("deepest head %.2f (band %.2f), moved %.1f along +X, mode %s"):format(Worst, Sw.SurfaceBand, Moved, tostring(SC.Mode))
end)

Check("DiveGoesUnder", function()
	local S = Spots.Main
	if not FloatAt(S) then return false, "the controller didn't start" end
	Aim(0)
	local Before = Root().Position.Y
	Tap("SwimDive")
	local Was = SC.Mode
	local Deepest, T0 = -99, os.clock()
	while os.clock() - T0 < 1 do Frames(1) Deepest = math.max(Deepest, HeadDepth()) end
	return Was == "Under" and Deepest > S.DiveDepth,
		("mode after the tap %s, deepest head %.2f (want > %.1f), root from %.2f"):format(tostring(Was), Deepest, S.DiveDepth, Before)
end)

Check("SteersDown", function()
	local S = Spots.Main
	if not S.Deep then return true, "skipped: this place's spot is too shallow (5.2) to steer down 3 studs" end
	if not FloatAt(S) then return false, "the controller didn't start" end
	Aim(0)
	Tap("SwimDive")
	-- rise to just under the surface, then W with the camera 45 down
	ClientActions.Run("SwimRise", true)
	local T0 = os.clock()
	repeat Frames(1) until (Surface() and Root().Position.Y > Surface() - 2.4) or os.clock() - T0 > 3
	ClientActions.Run("SwimRise", false)
	if SC.Mode ~= "Under" then return false, "not under before steering (mode " .. tostring(SC.Mode) .. ")" end
	Aim(45)
	local Y0, Min = Root().Position.Y, Root().Position.Y
	SC.TestMove = Vector3.new(0, 0, -1)
	T0 = os.clock()
	while os.clock() - T0 < 1 do Frames(1) Min = math.min(Min, Root().Position.Y) end
	SC.TestMove = nil
	return Y0 - Min > 3, ("root fell %.2f (want > 3), mode %s"):format(Y0 - Min, tostring(SC.Mode))
end)

Check("RisesToSurface", function()
	local S = Spots.Main
	if SC.Mode ~= "Under" then
		if not FloatAt(S) then return false, "the controller didn't start" end
		Aim(0)
		Tap("SwimDive")
		Frames(10)
	end
	if SC.Mode ~= "Under" then return false, "couldn't get under (mode " .. tostring(SC.Mode) .. ")" end
	ClientActions.Run("SwimRise", true)
	local T0 = os.clock()
	repeat Frames(1) until SC.Mode == "Surface" or os.clock() - T0 > 3
	ClientActions.Run("SwimRise", false)
	return SC.Mode == "Surface", ("mode %s after %.2f s"):format(tostring(SC.Mode), os.clock() - T0)
end)

Check("NoDiveInTheShallows", function()
	local S = Spots.Creek
	if not S then return true, "skipped: no creek spot in this place" end
	if not FloatAt(S) then return false, "the controller didn't start in the creek (mode " .. tostring(SC.Mode) .. ")" end
	local Dived = SC.Dive()
	Frames(5)
	return Dived == false and SC.Mode == "Surface", ("Dive() %s, depth %.2f, mode %s"):format(tostring(Dived), SC.Depth(), tostring(SC.Mode))
end)

Check("ShiftLockYields", function()
	local S = Spots.Main
	if not FloatAt(S) then return false, "the controller didn't start" end
	Aim(0)
	Tap("SwimDive")
	ClientActions.Run("SwimDive", true) -- hold: sink, so the swimmer stays under for the 30 frames
	local SettingsUI = require(ReplicatedStorage.Modules.UI.SettingsUI)
	local H = Hum()
	local Bad, Seen = 0, 0
	for _ = 1, 30 do
		-- what the shift-lock loop does every frame (SettingsUI.CameraLock), then the frame runs
		SettingsUI.CameraLock(Char(), H, Vector3.new(0, 1.5, 0.5), true)
		if SC.Mode == "Under" then
			Seen += 1
			if H.AutoRotate then Bad += 1 end
		end
		Frames(1)
	end
	ClientActions.Run("SwimDive", false)
	SettingsUI.CameraFree(H)
	return Seen >= 20 and Bad == 0, ("%d of 30 frames under, AutoRotate on in %d"):format(Seen, Bad)
end)

local R0 = Root()
local Home = R0 and R0.CFrame
local Cam0 = Camera.CFrame
CamStart()
for _, Name in ipairs(Order) do
	if ONLY == "" or string.find("," .. ONLY .. ",", "," .. Name .. ",", 1, true) then
		local Pass, Why = false, nil
		local OkC, Err = pcall(function() Pass, Why = Checks[Name]() end)
		table.insert(Results, {Name, OkC and Pass == true, OkC and tostring(Why) or ("error: " .. tostring(Err))})
	end
end
SC.TestMove = nil
ClientActions.Run("SwimDive", false)
ClientActions.Run("SwimRise", false)
CamStop()
Camera.CFrame = Cam0
if Home and Root() then
	Root().CFrame = Home
	Root().AssemblyLinearVelocity = Vector3.zero
end
Report()
]==]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
if not game:GetService("RunService"):IsRunning() then return "REFUSED: Play only (run from the Server data model)" end
local P = Players:GetPlayers()[1]
if not (P and P.Character and P:FindFirstChild("PlayerGui")) then return "REFUSED: no player with a character" end
for _, N in {"SwimChecks_TEMP_Remote"} do local O = ReplicatedStorage:FindFirstChild(N) if O then O:Destroy() end end
local Remote = Instance.new("RemoteEvent")
Remote.Name = "SwimChecks_TEMP_Remote"
Remote.Parent = ReplicatedStorage
local Got = nil
local Conn = Remote.OnServerEvent:Connect(function(From, Results) if From == P then Got = Results end end)
local LS = Instance.new("LocalScript")
LS.Name = "SwimChecks_TEMP"
LS.Source = CLIENT
LS:SetAttribute("Only", ONLY)
LS.Parent = P.PlayerGui
local T0 = os.clock()
repeat task.wait(0.25) until Got or os.clock() - T0 > 120
Conn:Disconnect()
LS:Destroy()
Remote:Destroy()
if not Got then return "TIMEOUT: no results from the client in 120 s" end
local Lines, Pass, Fail = {}, 0, 0
for _, R in ipairs(Got) do
	if R[2] then Pass += 1 else Fail += 1 end
	table.insert(Lines, (R[2] and "PASS " or "FAIL ") .. tostring(R[1]) .. ": " .. tostring(R[3]))
end
return ("PASS %d / FAIL %d (place %d)\n"):format(Pass, Fail, game.PlaceId) .. table.concat(Lines, "\n")

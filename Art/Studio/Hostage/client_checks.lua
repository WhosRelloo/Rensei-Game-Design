-- client_checks.lua (hostages plan Task 6, 2026-10-28; ruling R1, the assassinations' final review I1): the REAL-CLIENT
-- checks of the led pair. The server cases (Play_HostageHard: LeadClamped, TeleportEnds, ...) move the captor's root
-- from the server; these move it the way a player (or an exploiter) does, from the client that owns it. Play only, run
-- from the Server data model, with the Play protocol's hook (ServerStorage.LMRunSuite) and TestNoSave on:
--   python -I Art/Tools/rbxc.py luau "placeId: <id>" Server @Art/Studio/Hostage/client_checks.lua
-- It is the takedowns' pattern (Art/Studio/Takedown/client_checks.lua, after the gun rework's), not a new one: the
-- client half (CLIENT) and the server half (SERVER) are both in this file, and this file, run with rbxc Server, sets
-- them up and runs the server half. Everything it makes is a Play copy that vanishes at Stop, and it removes it all
-- before returning:
--   * the RemoteEvent ReplicatedStorage.HostageChecks_TEMP_Remote (the two halves talk over it);
--   * the LocalScript HostageChecks_TEMP (CLIENT below) in the test player's PlayerGui, never in StarterPlayerScripts;
--   * the ModuleScript ServerStorage.RenseiTests.HostageChecks_TEMP_Suite (SERVER below), run through LMRunSuite, so its
--     set-up runs in the GAME VM with RenseiTests.HostageKit: every case in HostageKit.Guard (the hook's snapshot armed
--     AND DataManager.IsNoSave()) on TakedownKit's Play-only floor, with stand-in players HostageKit made (never an NPC,
--     a townsperson or another real player), the character put back after;
--   * it returns TestKit's "PASS n / FAIL n" lines.
-- REAL KEYS (ruling T1-5: Humanoid:Move run through rbxc's Client context does nothing, so the walking is real W
-- presses). When a case wants one it sets the Remote's attributes Key ("W") and HoldMs, then raises KeySeq by 1; whoever
-- runs this file holds that key that long for each step, from a second process (never an Alt key: it flips ShiftLock):
--   python -I Art/Tools/rbxc.py call user_keyboard_input '{"studio_id": "<id>", "datamodel_type": "Client", "actions":
--     [{"action": "keyDown", "key_code": "W"}, {"action": "wait", "wait_time_ms": <HoldMs>}, {"action": "keyUp", "key_code": "W"}]}'
-- (poll ReplicatedStorage.HostageChecks_TEMP_Remote:GetAttribute("KeySeq") in the Server data model about once a second
-- while this file runs). With no press in KEY_WAIT seconds the case fails, saying no press arrived.
-- The cases:
--   * ClientSprintClamped (the player the captor of a stand-in): the client writes its own WalkSpeed 24 every frame and
--     W is held 2 s. The server reads the captor's ground displacement <= 42 studs (LeadAllowance(1) x 2 + 1) AND
--     HostageClamped > 0, and the hold still on. Before Task 6 (RED) it went about 48 studs (Task 1: 37.99-48.39) with no
--     counter; the displacement and the peak server-seen speed are printed either way (the re-measure).
--   (Fix round I2's fling at a release is Play_HostageHard's NoFlingAtRelease, not a client check: in Studio the server
--   sees almost none of a client's fling at the release -- 0 to 12 of 147 studs/s measured -- so a client-driven case
--   can't fail before the fix.)
--   * ClientLeadWalkOk (the clamp's real-client control, added in Task 6): W held 2 s at the server's LeadSpeed 12 ->
--     HostageClamped stays 0, at least 18 studs walked, the hold still on.
--   * ClientWeldBreakInert (the player the captor; fix round 1, ledger ruling: an inert control, not a "broken" end):
--     the client destroys ITS copy of the DownedWeld and moves the stand-in's root 5 studs. The server keeps its weld
--     and never sees the move (Task 6 measured a 0.00-stud gap for 2.5 s), so over INERT_WATCH the server's gap stays
--     <= PairSlack 1.5 and the hold stays on. The server's own "broken" path is Play_HostageHard's PairBroken.
--   * HeldClientCantMove (the R1 control; the player the HOSTAGE): the player knocked, a stand-in captor binds them
--     (HostageService.Take(StandInPL, PlayerCharacter)). Held, the client sets its root's CFrame 10 studs off and
--     PlatformStand false, W is held 1 s, then Humanoid.Jump = true: the server sees the player's root within PairSlack
--     1.5 of the stand-in's root x Offset the whole time, its owner the server, the hold still on; the client's WCS shows
--     the Stun. It passes before Task 6 too: the server owns a stand-in captor's pair.
--   * CaptorNoDash (hostages Task 10 fix round 1; spec section 2: the captor can't dash): the player the captor of a
--     stand-in. The client runs its own real dash (StarterPlayerScripts.ClientHandler.Roll:OnStartClient, Q's handler,
--     its cooldown cleared), which asks the server for the dash's i-frames (StateRemote "IFrame"; CharacterHandler
--     charges the stamina and grants them). Holding: the server grants no IFrame status and spends no stamina (the
--     dash's movement itself is the client's, bounded by the lead clamp; its displacement is noted). Control: freed,
--     the same dash gets its IFrame and costs its stamina (TuningConfig.Dash.Stamina 20, written by hand).
-- ONLY: "" runs every check; else a comma list of check names.
local ONLY = ""

local CLIENT = [==[
-- HostageChecks_TEMP (Play only; made by Art/Studio/Hostage/client_checks.lua, gone at Stop): the client half.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local Remote = ReplicatedStorage:WaitForChild("HostageChecks_TEMP_Remote", 30)
local Player = Players.LocalPlayer

local Down, Up = 0, 0 -- W presses seen since this script started (the runner's, through user_keyboard_input)
local DownAt, HeldFor = 0, 0 -- when the last W went down, and how long the last one was held (client clock)
UIS.InputBegan:Connect(function(Input) if Input.KeyCode == Enum.KeyCode.W then Down += 1 DownAt = os.clock() end end)
UIS.InputEnded:Connect(function(Input) if Input.KeyCode == Enum.KeyCode.W then Up += 1 HeldFor = os.clock() - DownAt end end)

local function Char() return Player.Character end
local function Hum() return Char():FindFirstChildOfClass("Humanoid") end
local SprintConn, WasWS = nil, nil

local Checks = {}
function Checks.Ping() return true end
function Checks.Keys() return {Down = Down, Up = Up, HeldFor = HeldFor, Fps = 1 / RunService.RenderStepped:Wait()} end

-- the client's own WalkSpeed 24, written every frame (as an exploiter, or Run's sprint, would)
function Checks.Sprint()
	local H = Hum()
	WasWS = WasWS or H.WalkSpeed
	if not SprintConn then SprintConn = RunService.Stepped:Connect(function() H.WalkSpeed = 24 end) end
	return {Was = WasWS}
end
-- the sprint stopped: the WalkSpeed it had given back (the server's writes win again from the next one)
function Checks.SprintStop()
	local H = Hum()
	local Seen = H.WalkSpeed
	if SprintConn then SprintConn:Disconnect() SprintConn = nil end
	if WasWS then H.WalkSpeed = WasWS WasWS = nil end
	return {WalkSpeed = Seen}
end

-- the captor's client breaks the pair: its own copy of the weld destroyed, the stand-in's root moved 5 studs
function Checks.BreakWeld()
	local Root = Char().HumanoidRootPart
	local W = Root:FindFirstChild("DownedWeld")
	if W then W:Destroy() end
	local Live = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Live")
	local Rig = nil
	for _, M in ipairs(Live and Live:GetChildren() or {}) do
		if M:IsA("Model") and M:GetAttribute("HeldBy") == Player.Name then Rig = M end
	end
	local HR = Rig and Rig:FindFirstChild("HumanoidRootPart")
	if not HR then return {Destroyed = W ~= nil, Moved = false, Dist = 0} end
	local P0 = HR.Position
	HR.CFrame += Vector3.new(5, 0, 0)
	return {Destroyed = W ~= nil, Moved = true, Dist = (HR.Position - P0).Magnitude}
end

-- the held client tries to get away: its root 10 studs off, PlatformStand off (W is the runner's)
function Checks.Wriggle()
	local Root = Char().HumanoidRootPart
	local P0 = Root.Position
	Root.CFrame += Vector3.new(10, 0, 0)
	Hum().PlatformStand = false
	return {Dist = (Root.Position - P0).Magnitude}
end
function Checks.Jump()
	Hum().Jump = true
	return true
end
-- the client's own WCS character shows the Stun status
function Checks.Stunned()
	local WCS = require(ReplicatedStorage.Modules.Framework.WCS)
	local Stun = require(ReplicatedStorage.Modules.Skills.States.Stun)
	local WC = WCS.Character.GetCharacterFromInstance(Char())
	return WC ~= nil and WC:HasStatusEffects({Stun}) == true
end

-- (Task 10 fix round 1) the client's own dash, exactly as Q starts it (its cooldown cleared first); returns once it ends
function Checks.Dash()
	local Roll = require(Player:WaitForChild("PlayerScripts"):WaitForChild("ClientHandler"):WaitForChild("Roll"))
	Roll.ReadyAt = 0
	Roll:OnStartClient()
	return true
end

function Checks.Reset()
	Checks.SprintStop()
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
-- HostageChecks_TEMP_Suite (Play only; made by Art/Studio/Hostage/client_checks.lua, gone at Stop): the server half, a
-- TestKit suite run through LMRunSuite. Expected values written by hand (Rensei.Hostage's PROPOSAL numbers, never read
-- from it here; pre-flight P15):
--   SPRINT_BOUND 42 studs: LeadAllowance(1) x 2 + 1 = (LeadSpeed 12 x LeadMult 1.5 + LeadSlack 2.5) x 2 s + 1.
--   SPRINT_MS 2000: the W hold of ClientSprintClamped. WRIGGLE_MS 1000: HeldClientCantMove's.
--   INERT_WATCH 2.5 s. PAIR_SLACK 1.5 studs. OFFSET: the hostage's root 1.5 studs in front of the captor's.
--   KEY_WAIT 30 s: for the runner's real W press (see the file's header). SETTLE 0.3 s after a press.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local Kit = require(script.Parent.TakedownKit)
local HK = require(script.Parent.HostageKit)
local DM = require(ReplicatedStorage.Modules.Managers.DownedManager)
local Remote = ReplicatedStorage:WaitForChild("HostageChecks_TEMP_Remote")
local Player = Kit.Player()
local C = Player.Character

local SPRINT_BOUND, SPRINT_MS, WRIGGLE_MS = 42, 2000, 1000
local INERT_WATCH, PAIR_SLACK, OFFSET = 2.5, 1.5, CFrame.new(0, 0, -1.5)
local KEY_WAIT, SETTLE = 30, 0.3
local LEAD_MIN = 18 -- studs: LeadSpeed 12 x 2 s = 24, less the start and the stop
-- (Task 10 fix round 1) a dash costs TuningConfig.Dash.Stamina 20 (by hand): refused, under NO_CHARGE is spent (regen
-- slack); granted, at least CHARGED
local NO_CHARGE, CHARGED = 5, 15

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
	error("the client checker HostageChecks_TEMP never answered")
end

local function Svc() return require(SSS.HostageService) end
local function Ground(A, B) return Vector3.new(A.X - B.X, 0, A.Z - B.Z).Magnitude end
local function F2(X) return ("%.2f"):format(X) end
local function On(S) return not S.Over and Svc().SessionOf(Player) == S end
local function Clamped() return C:GetAttribute("HostageClamped") or 0 end
-- the measured numbers, returned after TestKit's lines (the re-measure, and the numbers of the checks that pass)
local function Note(Case, Text)
	Remote:SetAttribute("Notes", (Remote:GetAttribute("Notes") or "") .. Case .. ": " .. Text .. "\n")
end

-- one real W hold from the runner (the file's header): Key, HoldMs, KeySeq + 1; true once the client saw it released
local function HoldW(Ms)
	local Before = Ask("Keys").Up
	Remote:SetAttribute("Key", "W")
	Remote:SetAttribute("HoldMs", Ms)
	Remote:SetAttribute("KeySeq", (Remote:GetAttribute("KeySeq") or 0) + 1)
	local T0 = os.clock()
	while Ask("Keys").Up <= Before and os.clock() - T0 < KEY_WAIT do task.wait(0.1) end
	return Ask("Keys").Up > Before
end

-- Fn sampled every Heartbeat until the returned stop function is called; that returns the largest value seen
local function Sample(Fn)
	local Stop, Max = false, 0
	task.spawn(function()
		while not Stop do
			Max = math.max(Max, Fn())
			RunService.Heartbeat:Wait()
		end
	end)
	return function() Stop = true return Max end
end

-- HostageKit.Guard, the client connected; Body(); the client put back
local function Case(Body)
	HK.Guard(function()
		Connect()
		local Ok, Err = pcall(Body)
		Send("Reset", nil, 2)
		if not Ok then error(Err, 0) end
	end)
end

-- (Task 10 fix round 1) the client's real dash: whether the server granted the IFrame status (sampled from before it
-- until 0.3 s after it ended) and how much stamina it spent
local function Dash()
	local WCS = require(ReplicatedStorage.Modules.Framework.WCS)
	local IFrame = require(ReplicatedStorage.Modules.Skills.States.IFrame)
	local RM = require(ReplicatedStorage.Modules.Managers.ResourceManager)
	local WC = WCS.Character.GetCharacterFromInstance(C)
	RM.Set(C, "Stamina", RM.Max(C, "Stamina"))
	local S0 = RM.Get(C, "Stamina")
	local Seen = Sample(function() return WC:HasStatusEffects({IFrame}) and 1 or 0 end)
	Ask("Dash")
	task.wait(SETTLE)
	return Seen() == 1, S0 - RM.Get(C, "Stamina")
end

local Suite = {
	-- (Task 10 fix round 1) the captor's own dash: no i-frames and no stamina while Holding; freed, both
	CaptorNoDash = function(T)
		Case(function()
			local _, _, S = HK.Held()
			HK.Loose()
			local Root = C.HumanoidRootPart
			local P0 = Root.Position
			local IFrames, Spent = Dash()
			local Disp = Ground(Root.Position, P0)
			local Held = On(S)
			Svc().Free(Player, "a")
			task.wait(1.1) -- (the server's dash interval, Dash.Cooldown 1 s, by hand)
			local CIFrames, CSpent = Dash()
			Note("CaptorNoDash", ("held: i-frames %s, stamina spent %s, displacement %s, HostageClamped %d; freed: i-frames %s, spent %s")
				:format(tostring(IFrames), F2(Spent), F2(Disp), Clamped(), tostring(CIFrames), F2(CSpent)))
			T.True(Held, "setup: the hold was on through the dash (" .. tostring(HK.Result()) .. ")")
			T.Eq(IFrames, false, "no dash i-frames while Holding")
			T.True(Spent < NO_CHARGE, "no dash stamina spent while Holding (" .. F2(Spent) .. ")")
			T.Eq(CIFrames, true, "control: freed, the dash gets its i-frames")
			T.True(CSpent >= CHARGED, "control: freed, the dash costs its stamina (" .. F2(CSpent) .. ")")
		end)
	end,

	-- the captor's own client sprints the pair: the server clamps it
	ClientSprintClamped = function(T)
		Case(function()
			local _, _, S = HK.Held()
			HK.Loose()
			local Root = C.HumanoidRootPart
			local P0 = Root.Position
			local Peak = Sample(function()
				local V = Root.AssemblyLinearVelocity
				return Vector3.new(V.X, 0, V.Z).Magnitude
			end)
			Ask("Sprint")
			local Pressed = HoldW(SPRINT_MS)
			task.wait(SETTLE)
			local Seen = Ask("SprintStop")
			local PeakV, Disp = Peak(), Ground(Root.Position, P0)
			Note("ClientSprintClamped", ("displacement %s studs, peak server-seen speed %s, HostageClamped %d, server WalkSpeed %s, held %s")
				:format(F2(Disp), F2(PeakV), Clamped(), tostring(C.Humanoid.WalkSpeed), tostring(On(S))))
			T.True(Pressed, "the runner's W press arrived (held " .. SPRINT_MS .. " ms)")
			T.Eq(Seen.WalkSpeed, 24, "the client walked at its own WalkSpeed 24")
			T.True(Disp <= SPRINT_BOUND, ("ground displacement <= %d studs: %s (peak server-seen speed %s, server WalkSpeed %s)")
				:format(SPRINT_BOUND, F2(Disp), F2(PeakV), tostring(C.Humanoid.WalkSpeed)))
			T.True(Clamped() > 0, "HostageClamped > 0 (" .. Clamped() .. ")")
			T.True(On(S), "the hold is still on (" .. tostring(HK.Result()) .. ")")
		end)
	end,

	-- (the clamp's real-client control, added in Task 6) the captor walks the pair at the server's own LeadSpeed 12 for
	-- 2 s: never put back, the hold still on, and it really went (at least LEAD_MIN of the 24 studs)
	ClientLeadWalkOk = function(T)
		Case(function()
			local _, _, S = HK.Held()
			HK.Loose()
			local Root = C.HumanoidRootPart
			local P0 = Root.Position
			local Pressed = HoldW(SPRINT_MS)
			task.wait(SETTLE)
			local Disp = Ground(Root.Position, P0)
			local K = Ask("Keys")
			Note("ClientLeadWalkOk", ("displacement %s studs, HostageClamped %d, client WalkSpeed %s, held %s; client-seen W held %s s at %s fps")
				:format(F2(Disp), Clamped(), tostring(C.Humanoid.WalkSpeed), tostring(On(S)), F2(K.HeldFor), F2(K.Fps)))
			T.True(Pressed, "the runner's W press arrived (held " .. SPRINT_MS .. " ms)")
			T.Eq(Clamped(), 0, "never put back")
			T.True(Disp >= LEAD_MIN, "it walked at least " .. LEAD_MIN .. " studs (" .. F2(Disp) .. ")")
			T.True(On(S), "the hold is still on (" .. tostring(HK.Result()) .. ")")
		end)
	end,

	-- (ledger ruling, fix round 1: an inert control) the captor's client breaks its own copy of the weld and moves the
	-- stand-in: the server never sees it (it keeps the weld), so the pair stays where the weld holds it and the hold on
	ClientWeldBreakInert = function(T)
		Case(function()
			local Rig, _, S = HK.Held()
			HK.Loose()
			local HR, CR = Rig.HumanoidRootPart, C.HumanoidRootPart
			local Gap = Sample(function()
				if S.Over then return math.huge end
				return (HR.Position - (CR.CFrame * OFFSET).Position).Magnitude
			end)
			local R = Ask("BreakWeld")
			task.wait(INERT_WATCH)
			local MaxGap = Gap()
			Note("ClientWeldBreakInert", ("client weld destroyed %s, client-seen move %s; over %s s: server gap max %s, server weld %s, held %s")
				:format(tostring(R.Destroyed), F2(R.Dist), tostring(INERT_WATCH), F2(MaxGap),
				tostring(CR:FindFirstChild("DownedWeld") ~= nil), tostring(On(S))))
			T.True(R.Destroyed, "setup: the client destroyed its DownedWeld")
			T.True(R.Moved, "setup: the client moved the stand-in's root (it saw " .. F2(R.Dist) .. " studs)")
			T.True(MaxGap <= PAIR_SLACK, "the server's pair never moved: gap max " .. F2(MaxGap) .. " <= 1.5")
			T.True(On(S), "the hold is still on (" .. tostring(HK.Result()) .. ")")
		end)
	end,

	-- (the R1 control) the player held by a stand-in captor: its client can't move the pair, which the server owns
	HeldClientCantMove = function(T)
		Case(function()
			local Rig, PL = HK.StandIn(Kit.At(0, 3)) -- (facing -Z: the player at the spot, 3 studs in front of it)
			Kit.PutPlayer(Kit.At(0, 0) + Vector3.new(0, 3, 0))
			T.True(HK.KnockPlayer(), "setup: the player is knocked")
			HK.Loose()
			local Ok, Why = Svc().Take(PL, C)
			T.Eq(Ok, true, "setup: the stand-in's take starts (" .. tostring(Why) .. ")")
			T.True(Kit.WaitFor(2.0, function()
				local X = Svc().SessionOf(Player)
				return X ~= nil and X.State == "Held"
			end), "setup: held within 2 s (" .. tostring(HK.Result(Rig)) .. ")")
			local S = Svc().SessionOf(Player)
			local SR, PR = Rig.HumanoidRootPart, C.HumanoidRootPart
			local Gap = Sample(function()
				if S.Over then return math.huge end
				return (PR.Position - (SR.CFrame * OFFSET).Position).Magnitude
			end)
			local SR0 = SR.Position
			local W = Ask("Wriggle")
			local Pressed = HoldW(WRIGGLE_MS)
			Ask("Jump")
			task.wait(SETTLE)
			local Stunned = Ask("Stunned")
			local MaxGap = Gap()
			local OwnerOk, Owner = pcall(function() return PR:GetNetworkOwner() end)
			Note("HeldClientCantMove", ("client-seen root move %s; server gap max %s; captor moved %s; owner %s; held %s; stun %s")
				:format(F2(W.Dist), F2(MaxGap), F2(Ground(SR.Position, SR0)), tostring(Owner), tostring(On(S)), tostring(Stunned)))
			T.True(W.Dist >= 9.9, "setup: the client set its root 10 studs off (it saw " .. F2(W.Dist) .. ")")
			T.True(Pressed, "the runner's W press arrived (held " .. WRIGGLE_MS .. " ms)")
			T.True(MaxGap <= PAIR_SLACK, "server: the player's root within 1.5 studs of the stand-in's root x Offset (max "
				.. F2(MaxGap) .. ")")
			T.True(Ground(SR.Position, SR0) <= 0.5, "the stand-in captor didn't move (" .. F2(Ground(SR.Position, SR0)) .. ")")
			T.Eq(OwnerOk and tostring(Owner) or "error", "nil", "the player's root is the server's")
			T.True(On(S), "the hold is still on (" .. tostring(HK.Result(Rig)) .. ")")
			T.Eq(Stunned, true, "the client's WCS shows the Stun")
			T.Eq(DM.IsKnocked(C), false, "the bind ended the player's knock")
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

local function Clear()
	for _, X in ipairs({ReplicatedStorage:FindFirstChild("HostageChecks_TEMP_Remote"),
		ServerStorage.RenseiTests:FindFirstChild("HostageChecks_TEMP_Suite"),
		P:FindFirstChild("PlayerGui") and P.PlayerGui:FindFirstChild("HostageChecks_TEMP")}) do
		if X then X:Destroy() end
	end
end
Clear()
local Remote = Instance.new("RemoteEvent")
Remote.Name = "HostageChecks_TEMP_Remote"
Remote:SetAttribute("Only", ONLY)
Remote:SetAttribute("KeySeq", 0)
Remote.Parent = ReplicatedStorage
local Suite = Instance.new("ModuleScript")
Suite.Name = "HostageChecks_TEMP_Suite"
Suite.Source = SERVER
Suite.Parent = ServerStorage.RenseiTests
local Local = Instance.new("LocalScript")
Local.Name = "HostageChecks_TEMP"
Local.Source = CLIENT
Local.Parent = P:WaitForChild("PlayerGui")
local Ok, Res = pcall(function() return Run:Invoke("HostageChecks_TEMP_Suite") end)
local Notes = Remote:GetAttribute("Notes") or ""
Clear()
return (Ok and tostring(Res) or ("ERROR " .. tostring(Res))) .. "\n-- measured:\n" .. Notes

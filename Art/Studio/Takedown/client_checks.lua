-- client_checks.lua (assassinations Task 10, 2026-10-25): the CLIENT checks of the takedown prompt (Modules.UI.TakedownUI),
-- the E fix (CombatModeUI: only a prompt on E takes E from Combat Mode, spec A8) and N reserved (Rensei.Settings). Play
-- only, run from the Server data model, with the Play protocol's hook (ServerStorage.LMRunSuite):
--   python -I Art/Tools/rbxc.py luau "placeId: <id>" Server @Art/Studio/Takedown/client_checks.lua
-- It is the gun rework's pattern (Art/Studio/Guns/client_checks.lua), not a new one. Everything it makes is a Play copy
-- that vanishes at Stop, and it removes it all before returning:
--   * the RemoteEvent ReplicatedStorage.TakedownChecks_TEMP_Remote (the two halves talk over it);
--   * the LocalScript TakedownChecks_TEMP (CLIENT below) in the test player's PlayerGui, never in StarterPlayerScripts. It
--     requires nothing this task changes: it only reads TakedownUI's prompt from the workspace (TakedownPrompt under a
--     rig's HumanoidRootPart) and drives it as a player's key would (ProximityPrompt:InputHoldBegin / InputHoldEnd);
--   * the ModuleScript ServerStorage.RenseiTests.TakedownChecks_TEMP_Suite (SERVER below), run through LMRunSuite, so
--     its setup runs in the GAME VM with RenseiTests.TakedownKit: every case in Kit.Guard on the kit's Play-only floor,
--     with Grunts it spawned itself (never a world enemy, a townsperson or the player), the character put back after;
--   * it returns TestKit's "PASS n / FAIL n" lines.
-- EStillDraws needs a REAL E press, which only the Studio MCP can make. When the case wants one it raises the Remote's
-- attribute KeySeq by 1 (Key = "E"); whoever runs this file presses that key once for each step, from a second process:
--   python -I Art/Tools/rbxc.py call user_keyboard_input
--     '{"studio_id": "<id>", "datamodel_type": "Client", "actions": [{"action": "keyPress", "key_code": "E"}]}'
-- (poll ReplicatedStorage.TakedownChecks_TEMP_Remote:GetAttribute("KeySeq") in the Server data model about once a
-- second while this file runs). With no press in KEY_WAIT seconds the case fails, saying no press arrived.
-- RED (before TakedownUI): no TakedownPrompt exists, so EStillDraws stands a TEMP prompt on N in for it
-- (TakedownChecks_TEMP_Prompt, made and removed by the client half): today any shown prompt stops E.
-- ONLY: "" runs every check; else a comma list of check names.
local ONLY = ""

local CLIENT = [==[
-- TakedownChecks_TEMP (Play only; made by Art/Studio/Takedown/client_checks.lua, gone at Stop): the client half.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UIS = game:GetService("UserInputService")
local Remote = ReplicatedStorage:WaitForChild("TakedownChecks_TEMP_Remote", 30)
local Player = Players.LocalPlayer

-- the prompts shown right now, whoever made them (PromptShown / PromptHidden, from this script's start)
local ShownNow = {}
ProximityPromptService.PromptShown:Connect(function(P) ShownNow[P] = true end)
ProximityPromptService.PromptHidden:Connect(function(P) ShownNow[P] = nil end)
local EPresses = 0
UIS.InputBegan:Connect(function(Input) if Input.KeyCode == Enum.KeyCode.E then EPresses += 1 end end)

local StandIn = nil -- the TEMP prompt on N (RED only), until Reset

local function PromptOf(Rig)
	local Root = Rig and Rig:FindFirstChild("HumanoidRootPart")
	return Root and Root:FindFirstChild("TakedownPrompt")
end
local function Count()
	local N = 0
	for _, D in ipairs(workspace:GetDescendants()) do
		if D.Name == "TakedownPrompt" and D:IsA("ProximityPrompt") then N += 1 end
	end
	return N
end
local function Shown(Want)
	for P in pairs(ShownNow) do
		if P.Parent and Want(P) then return true end
	end
	return false
end

local Checks = {}
function Checks.Ping() return true end

-- Args: Rig, Want (true: a TakedownPrompt under its root, whose ObjectText ends with Ends when given; false: none),
-- Within seconds. Polled every frame from the request.
function Checks.Prompt(Args)
	local T0 = os.clock()
	local function Met()
		local P = PromptOf(Args.Rig)
		if not Args.Want then return P == nil end
		return P ~= nil and (Args.Ends == nil or P.ObjectText:sub(-#Args.Ends) == Args.Ends)
	end
	while not Met() and os.clock() - T0 < Args.Within do RunService.RenderStepped:Wait() end
	local P = PromptOf(Args.Rig)
	return {Ok = Met(), After = os.clock() - T0, Count = Count(), ObjectText = P and P.ObjectText, ActionText = P and P.ActionText,
		Key = P and P.KeyboardKeyCode.Name, Hold = P and P.HoldDuration, Style = P and P.Style.Name,
		LineOfSight = P and P.RequiresLineOfSight, MaxDistance = P and P.MaxActivationDistance}
end

-- Args: Rig, Hold seconds: the prompt held as a key would hold it, then let go
function Checks.Press(Args)
	local P = PromptOf(Args.Rig)
	assert(P, "no TakedownPrompt under the rig to press")
	P:InputHoldBegin()
	task.wait(Args.Hold)
	P:InputHoldEnd()
	return true
end

-- a prompt on another key than E shows (TakedownUI's on N; with none, the TEMP stand-in on N), and none on E
function Checks.EReady(Args)
	local Using = "TakedownPrompt"
	if not PromptOf(Args.Rig) then
		Using = "stand-in"
		StandIn = Instance.new("ProximityPrompt")
		StandIn.Name = "TakedownChecks_TEMP_Prompt"
		StandIn.KeyboardKeyCode = Enum.KeyCode.N
		StandIn.RequiresLineOfSight = false
		StandIn.MaxActivationDistance = 6
		StandIn.ActionText = "TEMP (takedown checks)"
		StandIn.Parent = Args.Rig.HumanoidRootPart
	end
	local T0 = os.clock()
	local function NShown() return Shown(function(P) return P.KeyboardKeyCode ~= Enum.KeyCode.E end) end
	while not NShown() and os.clock() - T0 < 1 do RunService.RenderStepped:Wait() end
	return {Using = Using, Shown = NShown(), EShown = Shown(function(P) return P.KeyboardKeyCode == Enum.KeyCode.E end)}
end

function Checks.EPresses() return EPresses end

function Checks.Reset()
	if StandIn then StandIn:Destroy() StandIn = nil end
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
-- TakedownChecks_TEMP_Suite (Play only; made by Art/Studio/Takedown/client_checks.lua, gone at Stop): the server half, a
-- TestKit suite run through LMRunSuite. Expected values written by hand (the plan's numbers, PROPOSAL, 2026-10-25; never
-- read from Rensei.Takedown here):
--   WITHIN 0.5 s: the prompt appears / goes (TakedownUI picks every 0.1 s, plus replication).
--   AT 3 studs: straight behind / in front of the Grunt (inside the 4-stud range).
--   The prompt: key N, HoldDuration 0.6 (HoldToKill), Style Custom (PromptUI draws it), no line of sight,
--     MaxActivationDistance 6 (Range 4 + 2), ActionText "Knock out · hold to kill" for a Grunt (Full), ObjectText
--     "<name> (<phase>)".
--   TAP 0.1 s: a tap (under HoldToKill 0.6). KNOCKOUT_WAIT 3 s: KnockoutTime 2 + 1.
--   HOLD 0.8 s: HoldToKill 0.6 + 0.2. KILL_WAIT 3 s: LethalTime 1, with room for the release and replication.
--   KEY_WAIT 30 s: for the runner's real E press (see the file's header).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local PS = require(SSS.PerceptionService)
local Kit = require(script.Parent.TakedownKit)
local Settings = require(ReplicatedStorage.Modules.Data.Rensei.Settings)
local Remote = ReplicatedStorage:WaitForChild("TakedownChecks_TEMP_Remote")
local Player = Kit.Player()

local WITHIN, AT = 0.5, 3
local KEY, HOLD_TO_KILL, STYLE, MAX_DISTANCE = "N", 0.6, "Custom", 6
local FULL_ACTION = "Knock out · hold to kill"
local TAP, KNOCKOUT_WAIT = 0.1, 3
local HOLD, KILL_WAIT = 0.8, 3
local KEY_WAIT = 30

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
	error("the client checker TakedownChecks_TEMP never answered")
end

local function Char() return Player.Character end
local function Result() return Char():GetAttribute("LastTakedownResult") end
local function Shows(Rig, Ends) return Ask("Prompt", {Rig = Rig, Want = true, Within = WITHIN, Ends = Ends}) end
local function Goes(Rig) return Ask("Prompt", {Rig = Rig, Want = false, Within = WITHIN}) end
local function Secs(R) return ("%.2f s"):format(R.After) end

-- a kit Grunt with the player 3 studs straight behind it, Calm, the client connected; Body(Rig); the client put back
local function Case(Body)
	Kit.Guard(function()
		Connect()
		local Ok, Err = pcall(function() Body(Kit.Behind()) end)
		Send("Reset", nil, 2)
		if not Ok then error(Err, 0) end
	end)
end

-- one real key press from the runner (the file's header): KeySeq + 1, then wait for Done()
local function PressE(Done)
	Remote:SetAttribute("Key", "E")
	Remote:SetAttribute("KeySeq", (Remote:GetAttribute("KeySeq") or 0) + 1)
	local T0 = os.clock()
	while not Done() and os.clock() - T0 < KEY_WAIT do task.wait(0.1) end
	return Done()
end

local Suite = {
	-- behind a Grunt: one TakedownPrompt under its root, as the plan sets it; in front: gone
	PromptBehindOnly = function(T)
		Case(function(Rig)
			local R = Shows(Rig)
			T.True(R.Ok, "3 studs behind: a TakedownPrompt under the Grunt's root within 0.5 s (" .. Secs(R) .. ")")
			T.Eq(R.Count, 1, "one TakedownPrompt in the workspace")
			T.Eq(R.Key, KEY, "on N")
			T.Near(R.Hold, HOLD_TO_KILL, 1e-6, "HoldDuration")
			T.Eq(R.Style, STYLE, "Style (PromptUI draws it)")
			T.Eq(R.LineOfSight, false, "RequiresLineOfSight")
			T.Near(R.MaxDistance, MAX_DISTANCE, 1e-6, "MaxActivationDistance")
			T.Eq(R.ActionText, FULL_ACTION, "ActionText")
			Kit.PutInFront(Rig, AT)
			local G = Goes(Rig)
			T.True(G.Ok, "3 studs in front: gone within 0.5 s (" .. Secs(G) .. ")")
			T.Eq(G.Count, 0, "no TakedownPrompt left")
		end)
	end,
	-- the prompt names the Grunt's phase, and follows it
	PromptStateWord = function(T)
		Case(function(Rig)
			local R = Shows(Rig, "(unaware)")
			T.True(R.Ok, "ObjectText ends \"(unaware)\": " .. tostring(R.ObjectText))
			local Root = Rig.HumanoidRootPart
			T.True(PS.Hear(Root.Position + Root.CFrame.LookVector * 10, 20, nil) >= 1, "setup: it heard a noise in front of it")
			T.Eq(PS.PhaseOf(Rig), "Suspicious", "setup: Suspicious")
			local S = Shows(Rig, "(suspicious)")
			T.True(S.Ok, "ObjectText ends \"(suspicious)\" within 0.5 s: " .. tostring(S.ObjectText))
		end)
	end,
	-- an Alert Grunt has no prompt
	PromptHidesOnAlert = function(T)
		Case(function(Rig)
			T.True(Shows(Rig).Ok, "setup: the prompt shows")
			PS.Alarm(Rig, Player)
			T.Eq(Rig:GetAttribute("Awareness"), "Alert", "setup: Alert")
			local G = Goes(Rig)
			T.True(G.Ok, "Alert: gone within 0.5 s (" .. Secs(G) .. ")")
		end)
	end,
	-- Calm only: Combat Mode on hides it, off brings it back
	PromptCalmOnly = function(T)
		Case(function(Rig)
			T.True(Shows(Rig).Ok, "setup: the prompt shows")
			Char():SetAttribute("CombatMode", true)
			local G = Goes(Rig)
			T.True(G.Ok, "Combat Mode on: gone within 0.5 s (" .. Secs(G) .. ")")
			Char():SetAttribute("CombatMode", nil)
			local R = Shows(Rig)
			T.True(R.Ok, "Combat Mode off: back within 0.5 s (" .. Secs(R) .. ")")
		end)
	end,
	-- a tap on the prompt asks for a knockout, which the server runs
	TapKnocksOut = function(T)
		Case(function(Rig)
			T.True(Shows(Rig).Ok, "setup: the prompt shows")
			Ask("Press", {Rig = Rig, Hold = TAP})
			local Ok = Kit.WaitFor(KNOCKOUT_WAIT, function() return Result() == "Knockout:ok" end)
			T.True(Ok, "a 0.1 s tap: \"Knockout:ok\" within 3 s (got " .. tostring(Result()) .. ")")
			T.Eq(Rig:GetAttribute("Knocked"), true, "the Grunt is knocked out")
		end)
	end,
	-- a full hold asks for an assassination, and only that (no knockout first)
	HoldAssassinates = function(T)
		Case(function(Rig)
			T.True(Shows(Rig).Ok, "setup: the prompt shows")
			Ask("Press", {Rig = Rig, Hold = HOLD})
			local Ok = Kit.WaitFor(KILL_WAIT, function() return Result() == "Assassinate:ok" end)
			T.True(Ok, "a 0.8 s hold: \"Assassinate:ok\" within 3 s (got " .. tostring(Result()) .. ")")
			T.True(Rig.Humanoid.Health <= 0, "the Grunt is dead")
		end)
	end,
	-- with a prompt on N showing, a real E press still draws (Combat Mode on), and E again puts it back
	EStillDraws = function(T)
		Case(function(Rig)
			Shows(Rig)
			local R = Ask("EReady", {Rig = Rig})
			T.True(R.Shown, "setup: a prompt on N shows (" .. tostring(R.Using) .. ")")
			T.Eq(R.EShown, false, "setup: no prompt on E shows")
			T.Eq(Char():GetAttribute("CombatMode"), nil, "setup: Calm")
			local Before = Ask("EPresses")
			local On = PressE(function() return Char():GetAttribute("CombatMode") == true end)
			T.True(Ask("EPresses") > Before, "a real E press arrived (the runner presses it, see the header)")
			T.True(On, "E with the " .. tostring(R.Using) .. " prompt showing: Combat Mode on")
			local Off = PressE(function() return Char():GetAttribute("CombatMode") ~= true end)
			T.True(Off, "E again: Combat Mode off")
		end)
	end,
	-- N is reserved: no action can be bound to it (pure; control: a free key is bindable)
	NReserved = function(T)
		T.Eq(Settings.IsBindableKey("N"), false, "N is not bindable")
		T.Eq(Settings.IsBindableKey("U"), true, "control: U (free) is bindable")
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
	for _, X in ipairs({ReplicatedStorage:FindFirstChild("TakedownChecks_TEMP_Remote"),
		ServerStorage.RenseiTests:FindFirstChild("TakedownChecks_TEMP_Suite"),
		P:FindFirstChild("PlayerGui") and P.PlayerGui:FindFirstChild("TakedownChecks_TEMP")}) do
		if X then X:Destroy() end
	end
end
Clear()
local Remote = Instance.new("RemoteEvent")
Remote.Name = "TakedownChecks_TEMP_Remote"
Remote:SetAttribute("Only", ONLY)
Remote:SetAttribute("KeySeq", 0)
Remote.Parent = ReplicatedStorage
local Suite = Instance.new("ModuleScript")
Suite.Name = "TakedownChecks_TEMP_Suite"
Suite.Source = SERVER
Suite.Parent = ServerStorage.RenseiTests
local Local = Instance.new("LocalScript")
Local.Name = "TakedownChecks_TEMP"
Local.Source = CLIENT
Local.Parent = P:WaitForChild("PlayerGui")
local Ok, Res = pcall(function() return Run:Invoke("TakedownChecks_TEMP_Suite") end)
Clear()
return Ok and Res or ("ERROR " .. tostring(Res))

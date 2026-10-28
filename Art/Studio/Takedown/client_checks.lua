-- client_checks.lua (assassinations Task 10, 2026-10-25): the CLIENT checks of the takedown prompt (Modules.UI.TakedownUI)
-- and the E fix (CombatModeUI: only a prompt on E takes E from Combat Mode, spec A8). (2026-10-28, the takedown key made
-- rebindable; owner: "Yes it should rebindable") N is no longer reserved: the pure rules are Test_Settings, and
-- TakedownKeyFollowsBinding / UnboundHidesKeyboardPrompt / ServerSavesTakedownKey here check the prompt and the server's
-- save path. Each puts the player's own binding and saved Settings back before it returns (Reset restores the client's
-- binding too). Play only, run from the Server data model, with the Play protocol's hook (ServerStorage.LMRunSuite):
--   python -I Art/Tools/rbxc.py luau "placeId: <id>" Server @Art/Studio/Takedown/client_checks.lua
-- It is the gun rework's pattern (Art/Studio/Guns/client_checks.lua), not a new one. Everything it makes is a Play copy
-- that vanishes at Stop, and it removes it all before returning:
--   * the RemoteEvent ReplicatedStorage.TakedownChecks_TEMP_Remote (the two halves talk over it);
--   * the LocalScript TakedownChecks_TEMP (CLIENT below) in the test player's PlayerGui, never in StarterPlayerScripts. It
--     reads TakedownUI's prompt from the workspace (TakedownPrompt under a rig's HumanoidRootPart) and drives it as a
--     player's key would (ProximityPrompt:InputHoldBegin / InputHoldEnd). (Task 11) It also opens and closes the game's
--     menus through UIState.ToggleMenu, as their keys do (PromptHidesInMenu), and reads TakedownUI's one-shot error flag
--     _Warned (PromptRebuiltPerTarget); it closes any menu it opened in Reset;
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
-- (Task 11) the client's own copies of these modules (one VM: the same tables UIHandler started)
local UIState = require(ReplicatedStorage.Modules.UI.UIState)
local TakedownUI = require(ReplicatedStorage.Modules.UI.TakedownUI)
local Kept = nil -- a TakedownPrompt Remember kept, until Reset
local Opened = {} -- the menus Menu opened, closed again in Reset
-- (2026-10-28) the client's Keybinds (the table SettingsUI writes and TakedownUI reads), and the player's own takedown
-- binding before the first Bind, put back by Bind {Key = Was} or by Reset
local Keybinds = require(ReplicatedStorage.Modules.Managers.Keybinds)
local Original = nil

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
-- the key labels PromptUI draws for the rig's prompt right now (its BillboardGui RenseiPrompt, adorning the root)
local function Labels(Rig)
	local Root = Rig and Rig:FindFirstChild("HumanoidRootPart")
	local Out = {}
	for _, G in ipairs(Player.PlayerGui:GetChildren()) do
		if G.Name == "RenseiPrompt" and G:IsA("BillboardGui") and Root and G.Adornee == Root then
			local H = G:FindFirstChild("Holder")
			local K = H and H:FindFirstChild("Key") and H.Key:FindFirstChild("KeyText")
			if K then table.insert(Out, K.Text) end
		end
	end
	return Out
end
local function Shown(Want)
	for P in pairs(ShownNow) do
		if P.Parent and Want(P) then return true end
	end
	return false
end

local Checks = {}
function Checks.Ping() return true end

-- Args: Rig, Want (true: a TakedownPrompt under its root, whose ObjectText ends with Ends when given, on the key named
-- Key when given, and drawn by PromptUI with the key label Label when given; false: none), Within seconds. Polled every
-- frame from the request.
function Checks.Prompt(Args)
	local T0 = os.clock()
	local function Met()
		local P = PromptOf(Args.Rig)
		if not Args.Want then return P == nil end
		return P ~= nil and (Args.Ends == nil or P.ObjectText:sub(-#Args.Ends) == Args.Ends)
			and (Args.Key == nil or P.KeyboardKeyCode.Name == Args.Key)
			and (Args.Label == nil or table.find(Labels(Args.Rig), Args.Label) ~= nil)
	end
	while not Met() and os.clock() - T0 < Args.Within do RunService.RenderStepped:Wait() end
	local P = PromptOf(Args.Rig)
	return {Ok = Met(), After = os.clock() - T0, Count = Count(), ObjectText = P and P.ObjectText, ActionText = P and P.ActionText,
		Key = P and P.KeyboardKeyCode.Name, Hold = P and P.HoldDuration, Style = P and P.Style.Name,
		LineOfSight = P and P.RequiresLineOfSight, MaxDistance = P and P.MaxActivationDistance,
		Labels = table.concat(Labels(Args.Rig), ",")}
end

-- (2026-10-28) Args: Key: bind the takedown to that key name in the client's Keybinds, as SettingsUI's Apply does
-- (Keybinds.Set; its Changed rebinds TakedownUI). The player's own binding is kept before the first Bind.
function Checks.Bind(Args)
	if Original == nil then Original = Keybinds.Keys.Takedown end
	local Was = Original
	Keybinds.Set("Takedown", Args.Key)
	if Args.Key == Original then Original = nil end -- put back: nothing left for Reset
	return {Was = Was, Now = Keybinds.Keys.Takedown, LastInput = UIS:GetLastInputType().Name}
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

-- (Task 11) Args: Rig: keep the TakedownPrompt under its root now (true when there is one)
function Checks.Remember(Args)
	Kept = PromptOf(Args.Rig)
	return Kept ~= nil
end
-- Args: Rig: the TakedownPrompt under its root is not the one Remember kept, and that one is gone (destroyed)
function Checks.Fresh(Args)
	local P = PromptOf(Args.Rig)
	return {New = P ~= nil and P ~= Kept, OldGone = Kept == nil or Kept.Parent == nil}
end
-- Args: Reset: clear TakedownUI's one-shot error flag first. Returns whether TakedownUI has warned of an error since.
function Checks.Warned(Args)
	if Args.Reset then TakedownUI._Warned = nil end
	return TakedownUI._Warned == true
end
-- Args: Name, Open: open or close that menu as its key does (UIState.ToggleMenu); returns whether it is open now
function Checks.Menu(Args)
	if UIState.IsOpen(Args.Name) ~= Args.Open then
		UIState.ToggleMenu(Args.Name)
		if Args.Open then Opened[Args.Name] = true end
	end
	return UIState.IsOpen(Args.Name)
end

function Checks.Reset()
	if StandIn then StandIn:Destroy() StandIn = nil end
	if Original ~= nil then Keybinds.Set("Takedown", Original) Original = nil end
	Kept = nil
	for Name in pairs(Opened) do
		if UIState.IsOpen(Name) then UIState.ToggleMenu(Name) end
	end
	table.clear(Opened)
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
--   (Task 11) TAP_GRACE 0.1 s: TakedownUI's wait for a Triggered after a hold ends; HoldAssassinates waits it + 0.2 s more
--     and the result must still be "Assassinate:ok" (no knockout after the kill).
--   (Task 11) MENUS: the full-screen menus UIHandler binds (` Bag = "Inventory", M "Stats", P Menu = "Settings", K
--     "Mastery") and the Journal (J): each hides the prompt while open (ruling, PROPOSAL).
--   (Task 11) NEAR_X, NEAR_Z: a second Grunt at At(1.2, 1.2), facing -Z as the first: the player (3 studs behind the
--     first, at At(0, 3)) is 2.16 studs from it, 34 degrees off its back, so it is nearer and the target.
--   (2026-10-28) REBIND "H": a free key (in no Reserved list, bound by nothing); PromptUI labels it "H", and N "N".
--     RESERVED "LeftShift": a key the server refuses for any action (run). UNBOUND "Unknown": the name Settings leaves
--     for an action with no key.
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
local TAP_GRACE = 0.1
local MENUS = {"Inventory", "Stats", "Settings", "Mastery", "Journal"}
local NEAR_X, NEAR_Z = 1.2, 1.2
local REBIND, RESERVED, UNBOUND = "H", "LeftShift", "Unknown"
local Progression = require(SSS.ProgressionService)
local SmokeKit = require(script.Parent.SmokeKit)

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
local function Shows(Rig, Ends, Key, Label)
	return Ask("Prompt", {Rig = Rig, Want = true, Within = WITHIN, Ends = Ends, Key = Key, Label = Label})
end
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
			-- (Task 11) a tap's knockout leaves TapGrace after the release: none may follow the kill
			task.wait(TAP_GRACE + 0.2)
			T.Eq(Result(), "Assassinate:ok", "still \"Assassinate:ok\" " .. (TAP_GRACE + 0.2) .. " s later (no knockout followed)")
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
	-- (Task 11) a new prompt for each target, never the old one moved: a second Grunt nearer gets a fresh prompt (the
	-- first is destroyed); then that Grunt is removed with its prompt, and the prompt comes back to the first with no error
	PromptRebuiltPerTarget = function(T)
		Case(function(A)
			T.True(Shows(A).Ok, "setup: the prompt shows on the first Grunt")
			Ask("Warned", {Reset = true})
			T.True(Ask("Remember", {Rig = A}), "setup: its prompt kept")
			local B = Kit.Spawn("Grunt", Kit.At(NEAR_X, NEAR_Z))
			local R = Shows(B)
			T.True(R.Ok, "a nearer Grunt: the prompt on it within 0.5 s (" .. Secs(R) .. ")")
			T.Eq(R.Count, 1, "one TakedownPrompt in the workspace")
			local F = Ask("Fresh", {Rig = B})
			T.True(F.New, "it is a new prompt, not the first one moved")
			T.True(F.OldGone, "the first one is destroyed")
			Ask("Remember", {Rig = B})
			SmokeKit.RemoveEnemy(B) -- its prompt goes with it
			local G = Shows(A)
			T.True(G.Ok, "the nearer Grunt removed: the prompt back on the first within 0.5 s (" .. Secs(G) .. ")")
			T.True(Ask("Fresh", {Rig = A}).New, "a new prompt again")
			T.Eq(Ask("Warned"), false, "TakedownUI raised no error (a gone prompt is never reparented)")
		end)
	end,
	-- (Task 11, ruling, PROPOSAL) the prompt hides while a menu is open; control: it shows before each menu opens, and
	-- comes back once they are all closed
	PromptHidesInMenu = function(T)
		Case(function(Rig)
			for _, Name in ipairs(MENUS) do
				local S = Shows(Rig)
				T.True(S.Ok, "control, no menu open: the prompt shows (before " .. Name .. ", " .. Secs(S) .. ")")
				T.Eq(Ask("Menu", {Name = Name, Open = true}), true, "setup: " .. Name .. " is open")
				local G = Goes(Rig)
				T.True(G.Ok, Name .. " open: the prompt is gone within 0.5 s (" .. Secs(G) .. ")")
				T.Eq(Ask("Menu", {Name = Name, Open = false}), false, "setup: " .. Name .. " is closed again")
			end
			local R = Shows(Rig)
			T.True(R.Ok, "control, every menu closed: the prompt back within 0.5 s (" .. Secs(R) .. ")")
		end)
	end,
	-- (2026-10-28) the prompt follows the player's binding: rebound to H, a fresh prompt on H with PromptUI's label "H",
	-- with no respawn; bound back, on N again. The player's own binding is put back (here, and by Reset on a failure).
	TakedownKeyFollowsBinding = function(T)
		Case(function(Rig)
			local R0 = Shows(Rig, nil, KEY, KEY)
			T.True(R0.Ok, "control: on N, labelled N (" .. Secs(R0) .. ", key " .. tostring(R0.Key) .. ", labels "
				.. tostring(R0.Labels) .. ")")
			T.True(Ask("Remember", {Rig = Rig}), "setup: its prompt kept")
			local B = Ask("Bind", {Key = REBIND})
			T.Eq(B.Was, KEY, "the player's own binding is N")
			T.Eq(B.Now, REBIND, "Keybinds: the takedown on H")
			local R = Shows(Rig, nil, REBIND, REBIND)
			T.True(R.Ok, "rebound: the prompt on H, labelled H, within 0.5 s (" .. Secs(R) .. ", key " .. tostring(R.Key)
				.. ", labels " .. tostring(R.Labels) .. ")")
			T.Eq(R.Key, REBIND, "KeyboardKeyCode H")
			T.Eq(R.Count, 1, "one TakedownPrompt in the workspace")
			T.True(Ask("Fresh", {Rig = Rig}).New, "a fresh prompt for the new key")
			T.Near(R.Hold, HOLD_TO_KILL, 1e-6, "HoldDuration unchanged")
			T.Eq(R.ActionText, FULL_ACTION, "ActionText unchanged")
			local Back = Ask("Bind", {Key = B.Was})
			T.Eq(Back.Now, KEY, "bound back: Keybinds on N")
			local N = Shows(Rig, nil, KEY, KEY)
			T.True(N.Ok, "bound back: the prompt on N, labelled N, within 0.5 s (" .. Secs(N) .. ", key " .. tostring(N.Key) .. ")")
			T.Eq(N.Key, KEY, "KeyboardKeyCode N again")
		end)
	end,
	-- (2026-10-28) unbound (Unknown) on keyboard and mouse: no prompt; bound again, it comes back
	UnboundHidesKeyboardPrompt = function(T)
		Case(function(Rig)
			T.True(Shows(Rig, nil, KEY).Ok, "control: the prompt shows on N")
			local B = Ask("Bind", {Key = UNBOUND})
			T.Eq(B.Now, UNBOUND, "Keybinds: the takedown unbound")
			T.True(B.LastInput ~= "Touch" and B.LastInput:sub(1, 7) ~= "Gamepad",
				"setup: keyboard and mouse input (last input " .. tostring(B.LastInput) .. ")")
			local G = Goes(Rig)
			T.True(G.Ok, "unbound: no prompt within 0.5 s (" .. Secs(G) .. ")")
			task.wait(0.3)
			T.True(Goes(Rig).Ok, "unbound: still none 0.3 s later (no prompt is made again)")
			Ask("Bind", {Key = B.Was})
			local R = Shows(Rig, nil, KEY, KEY)
			T.True(R.Ok, "bound back: the prompt on N within 0.5 s (" .. Secs(R) .. ")")
		end)
	end,
	-- (2026-10-28) the server's save path (Requests.Settings -> Settings.Resolve): a saved H is kept; a reserved key and
	-- a name that is no key fall back to N. The player's Settings table is put back (the same table) before it returns.
	ServerSavesTakedownKey = function(T)
		Kit.Guard(function()
			local SH = game:GetService("ServerScriptService"):FindFirstChild("ServerHandler")
			local M = SH and SH:FindFirstChild("Requests") and SH.Requests:FindFirstChild("Settings")
			assert(M, "setup: no ServerScriptService.ServerHandler.Requests.Settings")
			local Request = require(M)
			local Data = Progression.GetData(Player)
			assert(Data, "setup: no profile data for the test player")
			local Orig = Data.Settings
			local Ok, Err = pcall(function()
				local Saved = Settings.Resolve(Orig)
				Saved.Keys.Takedown = REBIND
				Request(Player, Saved)
				T.True(Data.Settings ~= Orig, "setup: the request replaced the Settings table")
				T.Eq(Data.Settings.Keys.Takedown, REBIND, "the server kept the saved H")
				Saved.Keys.Takedown = RESERVED
				Request(Player, Saved)
				T.Eq(Data.Settings.Keys.Takedown, KEY, "a reserved LeftShift falls back to N")
				Saved.Keys.Takedown = "NotAKey"
				Request(Player, Saved)
				T.Eq(Data.Settings.Keys.Takedown, KEY, "a name that is no key falls back to N")
			end)
			Data.Settings = Orig
			if not Ok then error(Err, 0) end
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

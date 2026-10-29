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
-- (hostages Task 12) OTHER REAL INPUT: when the Remote's attribute Input is set (JSON {"kind": "keyboard" | "mouse",
-- "actions": [...]}) as KeySeq rises, the runner sends those actions instead of the W hold, through user_keyboard_input
-- or user_mouse_input (datamodel Client; a mouse action may name an instance_path such as
-- "LocalPlayer.PlayerGui.Uis.EmoteWheel.Slot1"), and then sets the Remote's attribute InputDone to that KeySeq (the
-- runner sets InputDone after a W hold too). A case waits for InputDone, up to KEY_WAIT.
-- (hostages Task 12) STAND-IN PLAYERS FOR THE PROMPT: the server half registers each stand-in rig's name in the
-- ReplicatedStorage StringValue HostageTestPlayers (comma list; made and removed by this file), which the client half
-- copies into TakedownUI.TestPlayers (read in Studio only), so the player prompt sees the rig as a player.
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
-- (hostages Task 12: the client -- TakedownUI's player prompt, HostageUI, EmoteWheelUI.Menu, MobileControls; pre-flight
-- P7, P8, P19, P26. Every expectation is written by hand: BindRange 6, GrabRange 4, BindTime 1.5 s, the texts.)
--   * PromptOnKnockedPlayer: a knocked stand-in 3 studs away -> a TakedownPrompt on the takedown key with ActionText
--     "Take hostage", ObjectText the rig's name and HoldDuration 0 within 0.5 s; the player moved 9 studs away -> gone.
--   * PromptInCombatMode (P8): the same with the player in Combat Mode -> "Take hostage" (CheckTake has no calm gate).
--   * PromptGrabBehindOnly: a standing stand-in with the player 3 studs behind -> "Grab"; in front -> none; behind again
--     but the rig GrabImmuneUntil 5 s from now -> none.
--   * PromptHiddenWhileOff: a knocked stand-in in reach, the client's own copy of ReplicatedStorage's TestNoSave set
--     false (as a live game, where Rensei.Hostage.Enabled is false, sees it) -> no prompt; put back -> the prompt.
--   * EnemyWins: a kit Grunt with the player 3 studs behind it AND a knocked stand-in 3 studs from the player -> the
--     prompt sits on the Grunt (its takedown text), none on the stand-in.
--   * TriggerTakes: Prompt:InputHoldBegin(), InputHoldEnd() -> within BindTime + 1 = 2.5 s the character has Holding.
--   * BarsShow: the captor: HostageTime visible, Head "Holding", its fill in (0, 1]; no struggle bar. The hostage:
--     HostageTime Head "Held", HostageStruggle visible (Head "Struggle", its fill the Struggle attribute's), the plate
--     "Held by <rig name>".
--   * CaptorWheel: a real press of the takedown key while Held -> the wheel open as "Hostage" with Release, Finish and
--     Ransom (Ransom locked: no party); the pointer on Release shows "Let them go" (gold, never "Your hands are full",
--     P7); a real click on it -> the hold ends "released" (LastHostageResult "Bind:released").
--   * CaptorWheelInCombat (P7): the same with the player in Combat Mode: the wheel stays open and the click releases.
--   * CaptorRansomTiers: a stand-in of the hostage's party present -> Ransom open; a real click on it -> a second wheel
--     "Ransom" of "$50", "$500", "$1000", "$2000" (level 20); a real click on "$500" -> the server's demand is $500.
--   * StrugglePresses (the real player as the hostage): ten real F presses within 2 s (the runner asks for them 40 ms
--     apart; MCP overhead spreads them to about 1.5 s, which the client's own clock must see within 2 s, a setup
--     check) -> the server's Struggle grew
--     and it received at least 1 and at most 8 Struggle messages (HostageService._Sends, read only; P9), fewer than 10.
--   (hostages Task 12 fix round 1)
--   * CaptorWheelDirectionClick (review I1): in Combat Mode, the pointer moved in Release's direction but OFF its label
--     (inside the disc, a quarter of the wheel from its centre) and a real left click there: the hold ends "released",
--     a spy bound on MouseButton1 / MouseButton2 just above ClientHandler's own binds (ContextActionService priority
--     Default + 1, passing everything on) sees no press, and the server sees no light attack (the CombatState
--     attribute never set) and no Feint request.
--   * CaptorWheelCloses (review M3): in Combat Mode, four close paths, each with no Hostage request sent and the hold
--     still on: a real right click on the disc off every label (and the spy sees no M2, the server no Feint); a real
--     right click on an item's label (Finish: nothing picked); a real Esc (Roblox's own menu opens; a second Esc shuts
--     it); a second real press of the takedown key.
--   * MenuSlotsEven (review M6): EmoteWheelUI.Menu with 4, 5 and 6 items puts them in slots 1,3,5,7 / 1,2,4,5,7 /
--     1,2,3,5,6,7 (floor((I - 1) x 8 / N) + 1, written by hand).
--   * GamepadOpensMenu (review M7): the client's takedown key unbound (Keybinds.Set "Unknown", put back after): a real
--     N press opens nothing; a real ButtonX press (the prompt's own default gamepad button) opens the captor menu.
--   * BlockReleasedAtHold (review M8): in Combat Mode the Block key held down (a real keyDown), the player captured
--     (knocked, a stand-in binds them), the key let go, the player freed: over the next 1.5 s the client's Block skill
--     is never active (a stuck hold would raise it again by itself).
--   * BarsShow also checks the plate (review M1): its bar hidden, its name one line (not wrapped, one line tall) at
--     least as tall as the time bar's own name text, and its bottom above the player's head on screen.
--   * TouchButtons (P19): the Player attribute ForceMobileControls = true. Free: neither HOSTAGE nor STRUGGLE. The
--     captor: HOSTAGE (GRIP hidden); a real click on it opens the wheel. The hostage in Combat Mode: STRUGGLE, BLOCK
--     hidden; a real click on STRUGGLE sends one Struggle message.
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
-- (Task 12) the Block key's presses as the client saw them (client clock): StrugglePresses reads how many and their span
local Presses = {}
UIS.InputBegan:Connect(function(Input)
	if Input.KeyCode == require(ReplicatedStorage.Modules.Managers.Keybinds).Get("Block") then table.insert(Presses, os.clock()) end
end)

local function Char() return Player.Character end
local function Hum() return Char():FindFirstChildOfClass("Humanoid") end
local SprintConn, WasWS = nil, nil

-- (Task 12) the client's own UI modules (the tables UIHandler started); nil before they exist (RED)
local function UI(Name)
	local M = ReplicatedStorage.Modules.UI:FindFirstChild(Name)
	return M and require(M) or nil
end
local function Need(Name) return assert(UI(Name), "no " .. Name .. " module") end
local OffWas = nil -- the TestNoSave attribute's replicated value, while HostagesOff has the client's copy set false
local function PromptOf(Rig)
	local Root = Rig and Rig:FindFirstChild("HumanoidRootPart")
	local P = Root and Root:FindFirstChild("TakedownPrompt")
	return P and P:IsA("ProximityPrompt") and P or nil
end

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

-- (Task 12) the stand-in names the server half registered, copied into TakedownUI.TestPlayers
function Checks.TestPlayers()
	local TD = Need("TakedownUI")
	local V = ReplicatedStorage:FindFirstChild("HostageTestPlayers")
	local Set = {}
	for Name in ((V and V.Value) or ""):gmatch("[^,]+") do Set[Name] = true end
	TD.TestPlayers = Set
	return true
end
function Checks.KeyName()
	return Need("TakedownUI").Key().Name
end
-- Args: Rig, Want (true: a TakedownPrompt under its root whose ActionText is Action when given; false: none), Within s
function Checks.Prompt(Args)
	local T0 = os.clock()
	local function Met()
		local P = PromptOf(Args.Rig)
		if not Args.Want then return P == nil end
		return P ~= nil and (Args.Action == nil or P.ActionText == Args.Action)
	end
	while not Met() and os.clock() - T0 < Args.Within do RunService.RenderStepped:Wait() end
	local P = PromptOf(Args.Rig)
	return {Ok = Met(), After = os.clock() - T0, ObjectText = P and P.ObjectText, ActionText = P and P.ActionText,
		Key = P and P.KeyboardKeyCode.Name, Hold = P and P.HoldDuration, Style = P and P.Style.Name}
end
-- Args: Rig: its prompt pressed as a key would press it, then let go
function Checks.Press(Args)
	local P = PromptOf(Args.Rig)
	assert(P, "no TakedownPrompt under the rig to press")
	P:InputHoldBegin()
	task.wait(0.05)
	P:InputHoldEnd()
	return true
end
-- Args: Off: the client's own copy of ReplicatedStorage's TestNoSave set false (true), or put back (false)
function Checks.HostagesOff(Args)
	if Args.Off then
		if OffWas == nil then OffWas = ReplicatedStorage:GetAttribute("TestNoSave") end
		ReplicatedStorage:SetAttribute("TestNoSave", false)
	elseif OffWas ~= nil then
		ReplicatedStorage:SetAttribute("TestNoSave", OffWas)
		OffWas = nil
	end
	return ReplicatedStorage:GetAttribute("TestNoSave")
end
-- Args: State, Within: HostageUI's last payload reaches that State
function Checks.Hostage(Args)
	local H = Need("HostageUI")
	local T0 = os.clock()
	while H.Now.State ~= Args.State and os.clock() - T0 < (Args.Within or 0) do task.wait() end
	return {State = H.Now.State, Role = H.Now.Role, Options = #(H.Now.Options or {})}
end
-- the bars and the plate as drawn now (Args.Within: wait that long for the time bar to show)
function Checks.Bars(Args)
	local HUD = Player.PlayerGui.Uis.HUD
	local T0 = os.clock()
	local function Bar(Name)
		local B = HUD:FindFirstChild(Name)
		local Head = B and B:FindFirstChild("Head")
		local Sub = B and B:FindFirstChild("Text")
		local Inner = B and B:FindFirstChild("Bar")
		return {Exists = B ~= nil, Visible = B ~= nil and B.Visible, Head = Head and Head.Text, Fill = B and B:GetAttribute("Fill"),
			BarShown = Inner ~= nil and Inner.Visible and Inner.AbsoluteSize.X > 1, Wrapped = Head and Head.TextWrapped,
			TextH = Head and Head.TextBounds.Y, TextSize = Head and Head.TextSize, SubH = Sub and Sub.TextBounds.Y,
			Bottom = B and (B.AbsolutePosition.Y + B.AbsoluteSize.Y)}
	end
	while not Bar("HostageTime").Visible and os.clock() - T0 < (Args.Within or 0) do RunService.RenderStepped:Wait() end
	RunService.RenderStepped:Wait()
	-- the player's head on screen, in the HUD's coordinates (the viewport point less the gui inset)
	local HeadPart = Char():FindFirstChild("Head")
	local V = HeadPart and workspace.CurrentCamera:WorldToViewportPoint(HeadPart.Position + Vector3.new(0, HeadPart.Size.Y / 2, 0))
	local HeadY = V and V.Y - game:GetService("GuiService"):GetGuiInset().Y
	return {Time = Bar("HostageTime"), Struggle = Bar("HostageStruggle"), Plate = Bar("HostagePlate"), HeadY = HeadY}
end
-- Args: Title, Within: the wheel's open menu (EmoteWheelUI.MenuOpen) once it has that Title
function Checks.Menu(Args)
	local W = Need("EmoteWheelUI")
	assert(W.MenuOpen, "EmoteWheelUI has no menu mode")
	local T0 = os.clock()
	local function Got()
		local M = W.MenuOpen()
		return M ~= nil and (Args.Title == nil or M.Title == Args.Title) and M or nil
	end
	while not Got() and os.clock() - T0 < (Args.Within or 0) do RunService.RenderStepped:Wait() end
	local M = Got()
	if not M then return {Open = false, Title = W.MenuOpen() and W.MenuOpen().Title} end
	local Ids, Texts, Locked, Slots = {}, {}, {}, {}
	for _, It in ipairs(M.Items) do
		table.insert(Ids, tostring(It.Id))
		table.insert(Texts, It.Text)
		Locked[tostring(It.Id)] = It.Locked
		Slots[tostring(It.Id)] = "LocalPlayer.PlayerGui.Uis.EmoteWheel.Slot" .. It.Slot
	end
	return {Open = true, Title = M.Title, Ids = table.concat(Ids, ","), Texts = table.concat(Texts, ","), Locked = Locked,
		Slots = Slots, Hover = M.Hover, HoverRed = M.HoverRed}
end
-- (fix round 1) Args.Within: wait that long for no menu to be open (input reaches the client a little after the runner's
-- call returns); true once none is
function Checks.NoMenu(Args)
	local W = Need("EmoteWheelUI")
	local T0 = os.clock()
	while W.MenuOpen() and os.clock() - T0 < (Args.Within or 0) do RunService.RenderStepped:Wait() end
	return W.MenuOpen() == nil
end
function Checks.CloseMenu()
	local W = UI("EmoteWheelUI")
	if W and W.CloseMenu then W.CloseMenu() end
	return true
end
function Checks.Sent()
	return Need("HostageUI")._Sent
end
function Checks.Presses(Args)
	if Args.Clear then table.clear(Presses) end
	return {N = #Presses, Span = #Presses > 1 and Presses[#Presses] - Presses[1] or 0}
end
function Checks.BlockKey()
	return require(ReplicatedStorage.Modules.Managers.Keybinds).Get("Block").Name
end
-- Args: Names: each MobileControls button's visibility (and whether the cluster shows), Within: wait that long for the
-- cluster to show
function Checks.Touch(Args)
	local G = Player.PlayerGui:FindFirstChild("MobileControls")
	local T0 = os.clock()
	while not (G and G.Enabled) and os.clock() - T0 < (Args.Within or 0) do
		RunService.RenderStepped:Wait()
		G = Player.PlayerGui:FindFirstChild("MobileControls")
	end
	RunService.RenderStepped:Wait()
	RunService.RenderStepped:Wait()
	local Out = {Enabled = G ~= nil and G.Enabled}
	for _, N in ipairs(Args.Names) do
		local B = G and G.Cluster:FindFirstChild(N)
		Out[N] = B ~= nil and B.Visible
	end
	return Out
end

-- (fix round 1, I1 / M3) a spy on the mouse buttons just above ClientHandler's own ContextActionService binds (they
-- use BindAction's Default priority): it counts each press it sees and passes it on. Args.On: bind (counts cleared) or
-- unbind; returns the counts.
local SpyCounts = {M1 = 0, M2 = 0}
local SPY = "HostageChecks_TEMP_MouseSpy"
function Checks.Spy(Args)
	local CAS = game:GetService("ContextActionService")
	CAS:UnbindAction(SPY)
	if Args.On then
		SpyCounts = {M1 = 0, M2 = 0}
		CAS:BindActionAtPriority(SPY, function(_, State, Input)
			if State == Enum.UserInputState.Begin then
				local K = Input.UserInputType == Enum.UserInputType.MouseButton1 and "M1" or "M2"
				SpyCounts[K] += 1
			end
			return Enum.ContextActionResult.Pass
		end, false, Enum.ContextActionPriority.Default.Value + 1, Enum.UserInputType.MouseButton1,
			Enum.UserInputType.MouseButton2)
	end
	return {M1 = SpyCounts.M1, M2 = SpyCounts.M2}
end
-- (fix round 1, I1) a point in slot Slot's direction, Frac of the wheel's size from its centre (inside the disc, off
-- the slot's label), in user_mouse_input's coordinates: the HUD's own (measured: the tool adds the gui inset itself)
function Checks.DiscPoint(Args)
	local Root = Player.PlayerGui.Uis:FindFirstChild("EmoteWheel")
	assert(Root and Root.Visible, "the wheel isn't open")
	local A = math.rad((Args.Slot - 1) * 45)
	local C = Root.AbsolutePosition + Root.AbsoluteSize / 2
	local P = C + Vector2.new(math.sin(A), -math.cos(A)) * Args.Frac * Root.AbsoluteSize.Y
	return {X = math.floor(P.X + 0.5), Y = math.floor(P.Y + 0.5)}
end
function Checks.Mouse()
	local M = UIS:GetMouseLocation()
	return {X = M.X, Y = M.Y}
end
-- (fix round 1, M6) a test menu of N items opened on the wheel: their slots, then closed
function Checks.MenuSlots(Args)
	local W = Need("EmoteWheelUI")
	local Items = {}
	for I = 1, Args.N do table.insert(Items, {Id = "T" .. I, Text = "Item " .. I}) end
	local Opened = W.Menu("Slots test", Items, function() end)
	local M = W.MenuOpen()
	local Slots = {}
	for _, It in ipairs(M and M.Items or {}) do table.insert(Slots, It.Slot) end
	table.sort(Slots)
	W.CloseMenu()
	return {Opened = Opened, Slots = table.concat(Slots, ",")}
end
-- (fix round 1, M7) the takedown key bound to Key in the client's Keybinds, as Settings does; Reset puts it back
local KeyWas = nil
function Checks.BindTakedown(Args)
	local K = require(ReplicatedStorage.Modules.Managers.Keybinds)
	if KeyWas == nil then KeyWas = K.Keys.Takedown end
	K.Set("Takedown", Args.Key)
	return K.Keys.Takedown
end
-- (fix round 1, M8) whether the client's own Block skill is active now; Args.For: sample that long, true if it ever was
function Checks.BlockActive(Args)
	local WCS = require(ReplicatedStorage.Modules.Framework.WCS)
	local T0, Ever = os.clock(), false
	repeat
		local WC = WCS.Character.GetCharacterFromInstance(Char())
		local Skill = WC and WC:GetSkillFromString("Block")
		if Skill and Skill:GetState().IsActive then Ever = true end
		RunService.Heartbeat:Wait()
	until os.clock() - T0 >= (Args.For or 0)
	return Ever
end
-- (fix round 1) the input the client saw since Args.Clear, as "Type/processed" words (for the failure messages)
local InputLog = {}
UIS.InputBegan:Connect(function(I, Gp) table.insert(InputLog, I.UserInputType.Name .. (I.KeyCode ~= Enum.KeyCode.Unknown and (":" .. I.KeyCode.Name) or "") .. "/" .. tostring(Gp)) end)
function Checks.InputLog(Args)
	if Args.Clear then table.clear(InputLog) end
	return table.concat(InputLog, " ")
end
function Checks.MenuIsOpen()
	return game:GetService("GuiService").MenuIsOpen
end

function Checks.Reset()
	Checks.SprintStop()
	Checks.CloseMenu()
	Checks.HostagesOff({Off = false})
	Checks.Spy({On = false})
	if KeyWas ~= nil then require(ReplicatedStorage.Modules.Managers.Keybinds).Set("Takedown", KeyWas) KeyWas = nil end
	local TD = UI("TakedownUI")
	if TD then TD.TestPlayers = {} end
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
-- (Task 12) written by hand: BindTime 1.5 + 1 s; a prompt within 0.5 s; F presses asked 40 ms apart (MCP overhead
-- spreads ten of them to ~1.5 s, measured); at most 8 messages (SendsPerSecond 4 over those ~1.5 s, plus one); the
-- level-20 tiers; the menu's texts. (fix round 1) DISC_FRAC: a quarter of the wheel's size from its centre -- outside the
-- centre plate (0.18) and inside the slot labels (0.37 less half their height, 0.05)
local TAKE_WITHIN, PROMPT_WITHIN, PRESS_GAP, MAX_SENDS = 2.5, 0.5, 40, 8
local TIERS_20 = "$50,$500,$1000,$2000"
local DISC_FRAC = 0.25
-- (fix round 1) the player's RequestRemote messages the server receives, by first argument, while Watching (a listener
-- beside the game's own; it changes nothing)
local Heard, Watching = {}, false
ReplicatedStorage.Remotes.RequestRemote.OnServerEvent:Connect(function(P, Kind, A)
	if not Watching or P ~= Player then return end
	local K = tostring(Kind) .. (Kind == "Hostage" and ("." .. tostring(A)) or "")
	Heard[K] = (Heard[K] or 0) + 1
end)
local function Listen() table.clear(Heard) Watching = true end
local function Count(K) return Heard[K] or 0 end
local HttpService = game:GetService("HttpService")
local Tested = ReplicatedStorage:WaitForChild("HostageTestPlayers")
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

-- (Task 12) one real input from the runner (the file's header): Kind "keyboard" | "mouse", its actions; true once the
-- runner says it was sent
local function Input(Kind, Actions)
	local Seq = (Remote:GetAttribute("KeySeq") or 0) + 1
	Remote:SetAttribute("Input", HttpService:JSONEncode({kind = Kind, actions = Actions}))
	Remote:SetAttribute("KeySeq", Seq)
	local T0 = os.clock()
	while (Remote:GetAttribute("InputDone") or 0) < Seq and os.clock() - T0 < KEY_WAIT do task.wait(0.1) end
	Remote:SetAttribute("Input", nil)
	return (Remote:GetAttribute("InputDone") or 0) >= Seq
end
local function PressKey(Name, Times, GapMs)
	local A = {}
	for I = 1, Times or 1 do
		if I > 1 then table.insert(A, {action = "wait", wait_time_ms = GapMs or 100}) end
		table.insert(A, {action = "keyPress", key_code = Name})
	end
	return Input("keyboard", A)
end
local function Point(Path) return Input("mouse", {{action = "moveTo", instance_path = Path}, {action = "wait", wait_time_ms = 300}}) end
local function Click(Path)
	return Input("mouse", {{action = "moveTo", instance_path = Path}, {action = "wait", wait_time_ms = 300},
		{action = "mouseButtonClick", mouse_button = "left"}})
end
-- (Task 12) a rig registered as a stand-in player for the client's prompt (HostageTestPlayers -> TakedownUI.TestPlayers)
local function Register(Rig)
	Tested.Value = Tested.Value == "" and Rig.Name or (Tested.Value .. "," .. Rig.Name)
	Ask("TestPlayers")
	return Rig
end

-- HostageKit.Guard, the client connected; Body(); the client put back
local function Case(Body)
	HK.Guard(function()
		Connect()
		local Ok, Err = pcall(Body)
		Tested.Value = ""
		Send("Reset", nil, 2)
		if not Ok then error(Err, 0) end
	end)
end

-- (Task 12) a knocked stand-in at the spot, registered, the player 3 studs from it (HostageKit.FRONT)
local function KnockedNear()
	local Rig, PL = HK.StandIn(Kit.At(0, 0))
	DM.Knock(Rig)
	Register(Rig)
	Kit.PutPlayer(HK.FRONT)
	return Rig, PL
end
local function Prompt(Rig, Want, Action, Within)
	return Ask("Prompt", {Rig = Rig, Want = Want, Action = Action, Within = Within or PROMPT_WITHIN})
end
-- (Task 12) the captor's menu opened by a real press of the takedown key, once the client has the Held payload
local function OpenWheel(T)
	local H = Ask("Hostage", {State = "Held", Within = 2})
	T.Eq(H.State, "Held", "setup: the client has the Held payload (role " .. tostring(H.Role) .. ", " .. tostring(H.Options) .. " options)")
	T.True(PressKey(Ask("KeyName")), "the runner's press of the takedown key arrived")
	return Ask("Menu", {Title = "Hostage", Within = 1})
end
-- (fix round 1) the pointer to a screen point and, when Press, a real click of Button there
local function MouseAt(P, Press, Button)
	local A = {{action = "moveTo", x = P.X, y = P.Y}, {action = "wait", wait_time_ms = 300}}
	if Press then table.insert(A, {action = "mouseButtonClick", mouse_button = Button or "left"}) end
	return Input("mouse", A)
end
local function Fighting(T)
	C:SetAttribute("CombatMode", true)
	T.Eq(C:GetAttribute("CombatMode"), true, "setup: in Combat Mode")
end
local function NotAttacking()
	return Sample(function() return C:GetAttribute("CombatState") ~= nil and 1 or 0 end)
end

-- (Task 12) the shared body of CaptorWheel and CaptorWheelInCombat
local function WheelReleases(T, Fight)
	local _, _, S = HK.Held()
	if Fight then C:SetAttribute("CombatMode", true) end
	local M = OpenWheel(T)
	T.True(M.Open, "the wheel is open as the captor menu (" .. tostring(M.Title) .. ")")
	T.Eq(M.Ids, "Release,Finish,Ransom", "its items")
	T.Eq(M.Locked and M.Locked.Ransom, true, "Ransom locked (no party here)")
	T.True(Point(M.Slots.Release), "the runner's pointer move arrived")
	local Hov = Ask("Menu", {Title = "Hostage"})
	T.Eq(Hov.Hover, "Let them go", "pointing at Release shows its text (never Emotes.Blocked's reason)")
	T.Eq(Hov.HoverRed, false, "in gold, not as a refusal")
	if Fight then T.Eq(C:GetAttribute("CombatMode"), true, "setup: still in Combat Mode with the wheel open") end
	T.True(Click(M.Slots.Release), "the runner's click arrived")
	T.True(Kit.WaitFor(2, function() return S.Over end), "the hold ended (" .. tostring(HK.Result()) .. ")")
	T.Eq(HK.Result(), "Bind:released", "released through the menu")
	T.Eq(Ask("Menu", {}).Open, false, "the wheel closed")
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
	-- ===== (Task 12 fix round 1) =====
	CaptorWheelDirectionClick = function(T)
		Case(function()
			local _, _, S = HK.Held()
			Fighting(T)
			local M = OpenWheel(T)
			T.True(M.Open, "setup: the captor menu is open")
			local Slot = tonumber((M.Slots.Release or ""):match("Slot(%d+)$"))
			local P = Ask("DiscPoint", {Slot = Slot, Frac = DISC_FRAC})
			T.True(MouseAt(P), "the runner's pointer move arrived")
			local Hov = Ask("Menu", {Title = "Hostage"})
			T.Eq(Hov.Hover, "Let them go", ("setup: the pointer, off the label at (%d, %d), is in Release's direction"):format(P.X, P.Y))
			Ask("Spy", {On = true})
			Listen()
			local Swing = NotAttacking()
			T.True(MouseAt(P, true), "the runner's click arrived")
			T.True(Kit.WaitFor(2, function() return S.Over end), "the click picked Release (" .. tostring(HK.Result()) .. ")")
			task.wait(0.6)
			local Swung, Spy = Swing(), Ask("Spy", {On = false})
			Note("CaptorWheelDirectionClick", ("spy M1 %d M2 %d; CombatState seen %s; Feint %d; result %s")
				:format(Spy.M1, Spy.M2, tostring(Swung == 1), Count("Feint"), tostring(HK.Result())))
			T.Eq(HK.Result(), "Bind:released", "released through the menu")
			T.Eq(Spy.M1, 0, "the click never reached the combat binds (M1)")
			T.Eq(Swung, 0, "no light attack on the server (CombatState never set)")
			T.Eq(Count("Feint"), 0, "no Feint")
		end)
	end,

	CaptorWheelCloses = function(T)
		Case(function()
			local _, _, S = HK.Held()
			Fighting(T)
			Listen()
			-- a right click inside the disc
			local M = OpenWheel(T)
			T.True(M.Open, "setup: the menu is open (1)")
			-- (slot 2's direction: between Release and Finish, on the disc, no label there)
			local P = Ask("DiscPoint", {Slot = 2, Frac = DISC_FRAC})
			Ask("Spy", {On = true})
			Ask("InputLog", {Clear = true})
			T.True(MouseAt(P, true, "right"), "the runner's right click arrived")
			T.True(Ask("NoMenu", {Within = 1}), ("a right click on the disc at (%d, %d) closed it (the client saw: %s)")
				:format(P.X, P.Y, Ask("InputLog", {})))
			local Spy = Ask("Spy", {On = false})
			T.Eq(Spy.M2, 0, "the right click never reached the combat binds (M2)")
			T.Eq(Count("Feint"), 0, "no Feint")
			-- a right click on an item's own label
			M = OpenWheel(T)
			T.True(M.Open, "setup: the menu is open (1b)")
			Ask("InputLog", {Clear = true})
			T.True(Input("mouse", {{action = "moveTo", instance_path = M.Slots.Finish}, {action = "wait", wait_time_ms = 300},
				{action = "mouseButtonClick", mouse_button = "right"}}), "the runner's right click on Finish's label arrived")
			T.True(Ask("NoMenu", {Within = 1}), ("a right click on a label closed it and picked nothing (the client saw: %s; mouse %s)")
				:format(Ask("InputLog", {}), tostring(Ask("Mouse").X) .. "," .. tostring(Ask("Mouse").Y)))
			-- Esc
			M = OpenWheel(T)
			T.True(M.Open, "setup: the menu is open (2)")
			T.True(PressKey("Escape"), "the runner's Esc arrived")
			local Esc = Ask("NoMenu", {Within = 1})
			local SysMenu = Ask("MenuIsOpen")
			if SysMenu then PressKey("Escape") task.wait(0.3) end
			T.True(Esc, "Esc closed it")
			T.Eq(Ask("MenuIsOpen"), false, "setup: Roblox's own menu shut again")
			-- the key again
			M = OpenWheel(T)
			T.True(M.Open, "setup: the menu is open (3)")
			T.True(PressKey(Ask("KeyName")), "the runner's second press arrived")
			T.True(Ask("NoMenu", {Within = 1}), "the key again closed it")
			task.wait(0.3)
			Note("CaptorWheelCloses", ("spy M2 %d; Hostage.Menu %d; Feint %d; held %s"):format(Spy.M2, Count("Hostage.Menu"),
				Count("Feint"), tostring(not S.Over)))
			T.Eq(Count("Hostage.Menu"), 0, "no close sent a menu request")
			T.True(not S.Over, "the hold is still on (" .. tostring(HK.Result()) .. ")")
		end)
	end,

	MenuSlotsEven = function(T)
		Case(function()
			for N, Want in pairs({[4] = "1,3,5,7", [5] = "1,2,4,5,7", [6] = "1,2,3,5,6,7"}) do
				local R = Ask("MenuSlots", {N = N})
				T.True(R.Opened, "setup: a " .. N .. "-item menu opened")
				T.Eq(R.Slots, Want, N .. " items spread evenly")
			end
		end)
	end,

	GamepadOpensMenu = function(T)
		Case(function()
			HK.Held()
			T.Eq(Ask("BindTakedown", {Key = "Unknown"}), "Unknown", "setup: the takedown key unbound")
			Ask("Hostage", {State = "Held", Within = 2})
			T.True(PressKey("N"), "the runner's N press arrived")
			task.wait(0.3)
			T.Eq(Ask("Menu", {}).Open, false, "unbound: N opens nothing")
			T.True(PressKey("ButtonX"), "the runner's ButtonX press arrived")
			local M = Ask("Menu", {Title = "Hostage", Within = 1})
			T.True(M.Open, "the prompt's gamepad button opens the captor menu")
		end)
	end,

	BlockReleasedAtHold = function(T)
		Case(function()
			Fighting(T)
			local Key = Ask("BlockKey")
			T.True(Input("keyboard", {{action = "keyDown", key_code = Key}}), "the runner's " .. Key .. " down arrived")
			task.wait(0.4)
			T.True(Ask("BlockActive", {For = 0.2}), "setup: blocking with the key held")
			local _, _, S = HK.Captive()
			Ask("Hostage", {State = "Held", Within = 2})
			T.True(Input("keyboard", {{action = "keyUp", key_code = Key}}), "the runner's " .. Key .. " up arrived")
			task.wait(0.3)
			Svc().Free(Player, "a")
			T.True(S.Over, "setup: freed")
			Fighting(T)
			local Stuck = Ask("BlockActive", {For = 1.5}, 5)
			Note("BlockReleasedAtHold", "block active after the release: " .. tostring(Stuck))
			T.Eq(Stuck, false, "no block raised by itself after the hold (the held key was let go)")
		end)
	end,

	-- ===== (Task 12) the client =====
	PromptOnKnockedPlayer = function(T)
		Case(function()
			local Rig = KnockedNear()
			local P = Prompt(Rig, true, "Take hostage")
			T.True(P.Ok, ("a 'Take hostage' prompt within 0.5 s (%s, %s)"):format(tostring(P.ActionText), tostring(P.After)))
			T.Eq(P.ObjectText, Rig.Name, "its ObjectText is the target's name")
			T.Eq(P.Key, Ask("KeyName"), "on the takedown key")
			T.Eq(P.Hold, 0, "HoldDuration 0")
			T.Eq(P.Style, "Custom", "PromptUI's custom style")
			Kit.PutPlayer(Kit.At(0, 9) + Vector3.new(0, 3, 0))
			T.True(Prompt(Rig, false).Ok, "9 studs away: no prompt")
		end)
	end,

	PromptInCombatMode = function(T)
		Case(function()
			local Rig = KnockedNear()
			C:SetAttribute("CombatMode", true)
			local P = Prompt(Rig, true, "Take hostage")
			T.True(P.Ok, "in Combat Mode: 'Take hostage' (" .. tostring(P.ActionText) .. ")")
		end)
	end,

	PromptGrabBehindOnly = function(T)
		Case(function()
			local Rig = Register((HK.StandIn(Kit.At(0, 0))))
			Kit.PutBehind(Rig, 3)
			local P = Prompt(Rig, true, "Grab")
			T.True(P.Ok, "3 studs behind: 'Grab' (" .. tostring(P.ActionText) .. ")")
			Kit.PutInFront(Rig, 3)
			T.True(Prompt(Rig, false).Ok, "in front: no prompt")
			Kit.PutBehind(Rig, 3)
			T.True(Prompt(Rig, true, "Grab").Ok, "setup: behind again, 'Grab'")
			Rig:SetAttribute("GrabImmuneUntil", workspace:GetServerTimeNow() + 5)
			T.True(Prompt(Rig, false).Ok, "grab-immune: no prompt")
		end)
	end,

	PromptHiddenWhileOff = function(T)
		Case(function()
			local Rig = KnockedNear()
			T.True(Prompt(Rig, true, "Take hostage").Ok, "setup: the prompt shows in this TestNoSave session")
			T.Eq(Ask("HostagesOff", {Off = true}), false, "setup: the client's TestNoSave reads false")
			T.True(Prompt(Rig, false).Ok, "hostages off (as in a live game): no prompt")
			Ask("HostagesOff", {Off = false})
			T.True(Prompt(Rig, true, "Take hostage").Ok, "put back: the prompt again")
		end)
	end,

	EnemyWins = function(T)
		Case(function()
			local Grunt = Kit.Behind()
			local Rig = HK.StandIn(Kit.At(3, 3))
			DM.Knock(Rig)
			Register(Rig)
			local P = Prompt(Grunt, true)
			T.True(P.Ok, "a prompt on the Grunt (" .. tostring(P.ActionText) .. ")")
			T.Eq(P.ActionText, "Knock out · hold to kill", "the takedown's text")
			T.True(Prompt(Rig, false, nil, 0).Ok, "none on the knocked stand-in")
		end)
	end,

	TriggerTakes = function(T)
		Case(function()
			local Rig = KnockedNear()
			T.True(Prompt(Rig, true, "Take hostage").Ok, "setup: the prompt")
			Ask("Press", {Rig = Rig})
			T.True(Kit.WaitFor(TAKE_WITHIN, function() return C:GetAttribute("Holding") ~= nil end),
				"the character has Holding within 2.5 s (" .. tostring(HK.Result()) .. ")")
			T.Eq(C:GetAttribute("Holding"), Rig.Name, "holding the stand-in")
		end)
	end,

	BarsShow = function(T)
		Case(function()
			HK.Held()
			local B = Ask("Bars", {Within = 1})
			T.True(B.Time.Visible, "captor: HostageTime visible")
			T.Eq(B.Time.Head, "Holding", "captor: its head")
			T.True(type(B.Time.Fill) == "number" and B.Time.Fill > 0 and B.Time.Fill <= 1, "captor: fill in (0, 1]: " .. tostring(B.Time.Fill))
			T.Eq(B.Struggle.Visible, false, "captor: no struggle bar")
			T.Eq(B.Plate.Visible, false, "captor: no held-by plate")
			Svc().Free(Player, "a")
			HK.Clean()
			local Cap = HK.Captive()
			local H = Ask("Bars", {Within = 1})
			T.True(H.Time.Visible, "hostage: HostageTime visible")
			T.Eq(H.Time.Head, "Held", "hostage: its head")
			T.True(type(H.Time.Fill) == "number" and H.Time.Fill > 0 and H.Time.Fill <= 1, "hostage: fill in (0, 1]: " .. tostring(H.Time.Fill))
			T.True(H.Struggle.Visible, "hostage: HostageStruggle visible")
			T.Eq(H.Struggle.Head, "Struggle", "hostage: its head")
			T.True(type(H.Struggle.Fill) == "number" and H.Struggle.Fill >= 0 and H.Struggle.Fill <= 1, "hostage: struggle fill in [0, 1]: " .. tostring(H.Struggle.Fill))
			T.True(H.Plate.Visible, "hostage: the plate shows")
			T.Eq(H.Plate.Head, "Held by " .. Cap.Name, "hostage: 'Held by <name>'")
			-- (fix round 1, review M1) legible: no bar, one line, as tall as the time bar's own name text, above the head
			Note("BarsShow", ("plate text %s px (size %s, wrapped %s), time bar name text %s px; plate bottom %s, head %s")
				:format(tostring(H.Plate.TextH), tostring(H.Plate.TextSize), tostring(H.Plate.Wrapped), tostring(H.Time.SubH),
				tostring(H.Plate.Bottom), tostring(H.HeadY)))
			T.Eq(H.Plate.BarShown, false, "hostage: the plate has no bar")
			T.Eq(H.Plate.Wrapped, false, "hostage: the plate's name isn't wrapped")
			T.True(H.Plate.TextH ~= nil and H.Plate.TextSize ~= nil and H.Plate.TextH < H.Plate.TextSize * 1.6,
				"hostage: the plate's name is one line")
			T.True(H.Plate.TextH ~= nil and H.Time.SubH ~= nil and H.Plate.TextH >= H.Time.SubH,
				"hostage: the plate's name is at least as tall as the time bar's name text")
			T.True(H.HeadY ~= nil and H.Plate.Bottom ~= nil and H.Plate.Bottom < H.HeadY,
				"hostage: the plate is above the player's head on screen")
		end)
	end,

	CaptorWheel = function(T)
		Case(function() WheelReleases(T, false) end)
	end,

	CaptorWheelInCombat = function(T)
		Case(function() WheelReleases(T, true) end)
	end,

	CaptorRansomTiers = function(T)
		Case(function()
			local _, Payer = HK.StandIn(Kit.At(12, 0))
			local _, _, S = HK.Held({Party = {Payer}})
			local M = OpenWheel(T)
			T.True(M.Open, "the captor menu is open")
			T.Eq(M.Locked and M.Locked.Ransom, false, "Ransom open (a party member here)")
			T.True(Click(M.Slots.Ransom), "the runner's click on Ransom arrived")
			local R = Ask("Menu", {Title = "Ransom", Within = 1})
			T.True(R.Open, "a second wheel: the tiers (" .. tostring(R.Title) .. ")")
			T.Eq(R.Texts, TIERS_20, "the level-20 tiers")
			T.True(Click(R.Slots["2"]), "the runner's click on $500 arrived")
			T.True(Kit.WaitFor(2, function() return S.Demand ~= nil end), "a demand was made")
			T.Eq(S.Demand and S.Demand.Amount, 500, "for tier 2, $500")
		end)
	end,

	StrugglePresses = function(T)
		Case(function()
			local _, _, S = HK.Captive()
			local RM = require(ReplicatedStorage.Modules.Managers.ResourceManager)
			RM.Set(C, "Stamina", RM.Max(C, "Stamina"))
			Ask("Hostage", {State = "Held", Within = 2})
			local Bar0, Sends0 = S.Struggle, Svc()._Sends(Player)
			local Key = Ask("BlockKey")
			Ask("Presses", {Clear = true})
			T.True(PressKey(Key, 10, PRESS_GAP), "the runner's ten presses of " .. Key .. " arrived")
			task.wait(0.8) -- (the last batch's send, at most 1 / SendsPerSecond later, and its arrival)
			local Sends = Svc()._Sends(Player) - Sends0
			local Seen = Ask("Presses", {})
			Note("StrugglePresses", ("messages %d, bar %s -> %s, client sent %s, client saw %d presses over %s s")
				:format(Sends, F2(Bar0), F2(S.Struggle), tostring(Ask("Sent")), Seen.N, F2(Seen.Span)))
			T.Eq(Seen.N, 10, "setup: the client saw the ten presses")
			T.True(Seen.Span <= 2, "setup: the ten presses came within 2 s (" .. F2(Seen.Span) .. " s)")
			T.True(not S.Over, "setup: still held (" .. tostring(HK.Result()) .. ")")
			T.True(S.Struggle > Bar0, ("the server's Struggle grew: %s -> %s"):format(F2(Bar0), F2(S.Struggle)))
			T.True(Sends >= 1 and Sends <= MAX_SENDS, ("1 to 8 Struggle messages received: %d"):format(Sends))
			T.True(Sends < 10, "fewer messages than presses (batched): " .. Sends)
		end)
	end,

	TouchButtons = function(T)
		Case(function()
			local Names = {"Hostage", "Struggle", "Grip", "Block"}
			Player:SetAttribute("ForceMobileControls", true)
			local Ok, Err = pcall(function()
				local F = Ask("Touch", {Names = Names, Within = 2})
				T.True(F.Enabled, "setup: the touch controls show")
				T.Eq(F.Hostage, false, "free: no HOSTAGE")
				T.Eq(F.Struggle, false, "free: no STRUGGLE")
				HK.Held()
				Ask("Hostage", {State = "Held", Within = 2})
				local Cap = Ask("Touch", {Names = Names})
				T.Eq(Cap.Hostage, true, "captor: HOSTAGE")
				T.Eq(Cap.Grip, false, "captor: no GRIP")
				T.Eq(Cap.Struggle, false, "captor: no STRUGGLE")
				T.True(Click("LocalPlayer.PlayerGui.MobileControls.Cluster.Hostage"), "the runner's click on HOSTAGE arrived")
				T.True(Ask("Menu", {Title = "Hostage", Within = 1}).Open, "HOSTAGE opens the captor menu")
				Ask("CloseMenu")
				Svc().Free(Player, "a")
				HK.Clean()
				HK.Captive()
				C:SetAttribute("CombatMode", true)
				Ask("Hostage", {State = "Held", Within = 2})
				local Hos = Ask("Touch", {Names = Names})
				T.Eq(Hos.Struggle, true, "hostage: STRUGGLE")
				T.Eq(Hos.Block, false, "hostage in Combat Mode: no BLOCK (P19)")
				T.Eq(Hos.Hostage, false, "hostage: no HOSTAGE")
				local Sends0 = Svc()._Sends(Player)
				T.True(Click("LocalPlayer.PlayerGui.MobileControls.Cluster.Struggle"), "the runner's click on STRUGGLE arrived")
				T.True(Kit.WaitFor(1, function() return Svc()._Sends(Player) > Sends0 end), "STRUGGLE sends a Struggle message")
			end)
			Player:SetAttribute("ForceMobileControls", nil)
			if not Ok then error(Err, 0) end
		end)
	end,
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
			-- (hostages Task 12) the stand-in's root held still through the bind only, as HostageKit.Captive does (Task 10:
			-- a rig just let go still settles up to 0.85 studs, near the bind's 1-stud slack; in the longer Task 12 run
			-- that ended the setup's bind "interrupted" 3 times in 5), then let go again, so the held pair the client
			-- tries to move is a free, server-owned assembly as before
			Rig.HumanoidRootPart.Anchored = true
			T.Eq(Ok, true, "setup: the stand-in's take starts (" .. tostring(Why) .. ")")
			T.True(Kit.WaitFor(2.0, function()
				local X = Svc().SessionOf(Player)
				return X ~= nil and X.State == "Held"
			end), "setup: held within 2 s (" .. tostring(HK.Result(Rig)) .. ")")
			Rig.HumanoidRootPart.Anchored = false
			task.wait(SETTLE)
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
		ReplicatedStorage:FindFirstChild("HostageTestPlayers"),
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
local Tested = Instance.new("StringValue") -- (Task 12) the stand-in names for TakedownUI.TestPlayers
Tested.Name = "HostageTestPlayers"
Tested.Parent = ReplicatedStorage
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

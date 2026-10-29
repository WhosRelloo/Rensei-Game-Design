-- TakedownUI (assassinations Task 10, 2026-10-25; spec Documents/specs/2026-10-25-assassinations-design.md): the
-- takedown prompt. Display and input only: TakedownService (server) decides every takedown, and refuses a player's
-- character first (PvE only).
--   * Every Tick seconds it picks a candidate: the nearest enemy in World.Live (a direct child Model with an EnemyType
--     attribute, never a player's character or a townsperson) that is alive; not Knocked, TakenDownBy, GrippedBy or
--     CarriedBy; in a phase a takedown allows (Takedown.Phases: never Alert); not Immune (Takedown.ClassOf, from
--     Takedown.PerceptionTypeOf: an untracked AlwaysAware type is Immune); with the player in its rear arc
--     (Takedown.Behind, no slack: the server's AngleSlack and RangeSlack are only for lag), within Takedown.Range on the
--     ground plane and Takedown.Height up or down.
--   * Only while the player can take one down: alive; not Knocked, Gripping, Carrying, TakingDown, (hostages Task 12)
--     Holding or HeldBy; Calm (not in
--     Combat Mode); not swimming; off cooldown (workspace:GetServerTimeNow() >= TakedownReadyAt); no conversation open
--     (Gui.Dialogue, as CombatModeUI checks), no cutscene (a Scriptable camera) and (Task 11) no menu open (Menus).
--   * One ProximityPrompt, TakedownPrompt, made here on the client under the candidate's HumanoidRootPart, Style Custom
--     (drawn by PromptUI, the game's existing prompt art: no new UI assets), on the player's takedown key,
--     TakedownUI.Key() (Settings > Keybinds > Takedown; N by default, Takedown.Key; rebindable since 2026-10-28). (Task 11)
--     A new candidate gets a new prompt (the old one is destroyed, never moved: it may have gone with its rig); it is
--     destroyed when there is none. A rebind (Keybinds.Changed "Takedown") destroys it too, so the next pick makes a
--     fresh one on the new key and PromptUI draws the new key's label (PromptUI reads the key only when a prompt shows).
--   * Unbound (the key is "Unknown"): no prompt while the player is on keyboard and mouse; on touch or a gamepad
--     (UserInputService:GetLastInputType) the prompt is offered as always.
--   * Input: a tap (the hold ends and no Triggered follows within TapGrace) asks for a knockout; a full hold (Triggered)
--     asks for an assassination. A Chunk target (an Elite) can only be backstabbed: a tap does nothing. Touch: PromptUI's own
--     tap button holds the prompt (tap / hold), so the prompt is the touch control too.
-- * (hostages plan Task 12, 2026-10-28; spec Documents/specs/2026-10-21-hostage-design.md section 8; pre-flight P8) THE
--   PLAYER PROMPT on the same key. With no enemy candidate (an enemy always wins: decision 2), PlayerCandidate() picks
--   the nearest other player's character in World.Live (Players:GetPlayerFromCharacter, never the local one; in Studio
--   also a rig named in TakedownUI.TestPlayers, the client checks' stand-ins; never a model with EnemyType, TownsfolkId
--   or DialogueId) that is alive, not GrippedBy / CarriedBy / TakenDownBy / HeldBy / Holding / Gripping / Carrying /
--   TakingDown, not swimming, not grab-immune (GrabImmuneUntil, server time), and either
--     - knocked, within Hostage.BindRange on the ground plane and Hostage.Height up or down -> "Bind", "Take hostage";
--     - or standing, with the player in its rear arc (Hostage.Behind, no slack) within Hostage.GrabRange and Height ->
--       "Grab", "Grab".
--   Its readiness is the takedown's MINUS Calm and the takedown cooldown (P8: the server's CheckTake has neither, and a
--   PvP knock leaves the player in Combat Mode). The prompt is the same TakedownPrompt (Style Custom, the takedown key
--   TakedownUI.Key(), so PromptUI draws the bound key; HoldDuration 0) with ObjectText the target's display name and
--   ActionText the kind's text; Triggered asks UIState.Request("Hostage", "Take", Rig) -- never "Takedown": PvE
--   takedowns never accept a player. One prompt at a time, so a takedown prompt and a hostage prompt never share the
--   key, and both follow TakedownUI.Offered(). HIDDEN WHILE HOSTAGES ARE OFF: only while TakedownUI.HostagesOn()
--   (Rensei.Hostage.Enabled, or the Studio TestNoSave test bypass HostageService.Allowed() also has: RunService:IsStudio()
--   first, then ReplicatedStorage's TestNoSave attribute, which DataManager sets only in a no-save session). The server
--   refuses every hostage request while off regardless.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local UIState = require(script.Parent.UIState)
local Keybinds = require(ReplicatedStorage.Modules.Managers.Keybinds)
local Rensei = ReplicatedStorage.Modules.Data.Rensei
local Takedown = require(Rensei.Takedown)
local Hostage = require(Rensei.Hostage)
local Tuning = require(Rensei.TuningConfig)

local Player = Players.LocalPlayer

local TakedownUI = {}
TakedownUI.Tick = 0.1 -- seconds between candidate picks (the plan's 0.1 s)

local Prompt = nil -- the TakedownPrompt, while there is a candidate
local Rig = nil -- the candidate it sits on
local RigClass = nil -- its class: "Full" | "Chunk"; (Task 12) a player candidate's kind: "Bind" | "Grab"
local PromptFor = nil -- (Task 12) what the prompt was made for: "Enemy" | "Player"
local HoldRig = nil -- the rig a hold began on (nil: no hold, or the prompt moved since)
local HoldAt = 0 -- when that hold began
local Fired = false -- Triggered since the hold began
-- A completed hold fires PromptButtonHoldEnded just BEFORE Triggered (measured in Ye Play, 2026-10-27: 4 ms apart), so a
-- hold's end waits this long for a Triggered before it counts as a tap. PROPOSAL.
TakedownUI.TapGrace = 0.1
-- (Task 11, ruling) the full-screen menus (UIState.RegisterMenu names; UIHandler's Bag is "Inventory", its Menu
-- "Settings"): no prompt while one is open. PROPOSAL.
TakedownUI.Menus = {"Inventory", "Stats", "Settings", "Mastery", "Journal", "Minigame", "Admin"}
-- (hostages Task 12) Studio only: rig names the client checks register as stand-in players ([Name] = true)
TakedownUI.TestPlayers = {}
-- the player prompt's texts per kind (spec section 8: "Take hostage (N)"; PromptUI draws the key itself; "Grab" is
-- PROPOSAL, hostages fix round 1 M4)
TakedownUI.HostageText = {Bind = "Take hostage", Grab = "Grab"}

-- The player's takedown key now (an Enum.KeyCode): their Settings binding, N by default; Enum.KeyCode.Unknown when they
-- left it unbound. Everything that offers the takedown action on a key reads it here (hostages Task 12 too).
function TakedownUI.Key()
	return Enum.KeyCode[Keybinds.Keys.Takedown or Takedown.Key]
end

-- whether the prompt can be offered with the player's input now: always with a key; unbound, only on touch or a gamepad
function TakedownUI.Offered()
	if TakedownUI.Key() ~= Enum.KeyCode.Unknown then return true end
	local Last = UserInputService:GetLastInputType()
	return Last == Enum.UserInputType.Touch or Last.Name:sub(1, 7) == "Gamepad"
end

-- (hostages Task 12) whether any hostage UI may show: the switch, or the Studio TestNoSave test bypass, as
-- HostageService.Allowed() decides it on the server (IsStudio first; ReplicatedStorage's TestNoSave is DataManager's
-- copy of the no-save mode). A live game shows nothing until the owner's go-live step (Changelog 2026-10-29) sets
-- Rensei.Hostage.Enabled.
function TakedownUI.HostagesOn()
	if Hostage.Enabled == true then return true end
	return RunService:IsStudio() and ReplicatedStorage:GetAttribute("TestNoSave") == true
end

local function Alive(Model)
	local H = Model:FindFirstChildOfClass("Humanoid")
	return H ~= nil and H.Health > 0
end

local function Flat(V) return Vector3.new(V.X, 0, V.Z) end

-- the player can take one down now (the server checks all of it again). (Task 12, pre-flight P8) ForHostage: the
-- player prompt's readiness, without the Calm rule and the takedown cooldown
local function PlayerReady(ForHostage)
	local C = Player.Character
	local Root = C and C:FindFirstChild("HumanoidRootPart")
	local H = C and C:FindFirstChildOfClass("Humanoid")
	if not (Root and H and H.Health > 0) then return nil end
	for _, K in ipairs({"Knocked", "Gripping", "Carrying", "TakingDown", "Holding", "HeldBy"}) do
		if C:GetAttribute(K) then return nil end
	end
	if not ForHostage and C:GetAttribute("CombatMode") then return nil end
	if C:GetAttribute("Traversal") == "Swim" or H:GetState() == Enum.HumanoidStateType.Swimming then return nil end
	if not ForHostage and workspace:GetServerTimeNow() < (tonumber(C:GetAttribute("TakedownReadyAt")) or 0) then return nil end
	local G = UIState.Gui
	if G:FindFirstChild("Dialogue") and G.Dialogue.Visible then return nil end
	if workspace.CurrentCamera.CameraType == Enum.CameraType.Scriptable then return nil end
	for _, Name in ipairs(TakedownUI.Menus) do
		if UIState.IsOpen(Name) then return nil end
	end
	return Root
end

-- "Full" | "Chunk" | "Immune" for an enemy rig, as TakedownService.Context derives it
local function ClassOf(M)
	local Type = M:GetAttribute("EnemyType")
	local Def = Tuning.Enemies[Type or ""]
	return Takedown.ClassOf(Takedown.PerceptionTypeOf(Type), {
		Boss = M:GetAttribute("Boss") == true or (Def ~= nil and Def.Boss == true),
		TrialFoe = Def ~= nil and Def.TrialFoe == true,
		TakedownClass = M:GetAttribute("TakedownClass"),
	})
end

-- the nearest enemy the player could take down from where they stand, and its class
function TakedownUI.Candidate()
	local PR = PlayerReady()
	local World = workspace:FindFirstChild("World")
	local Live = World and World:FindFirstChild("Live")
	if not (PR and Live) then return nil end
	local Best, BestClass, BestDist = nil, nil, math.huge
	for _, M in ipairs(Live:GetChildren()) do
		local TR = M:IsA("Model") and M:GetAttribute("EnemyType") ~= nil and M:FindFirstChild("HumanoidRootPart")
		if TR and TR:IsA("BasePart") and not Players:GetPlayerFromCharacter(M) and M:GetAttribute("TownsfolkId") == nil
			and Alive(M) and not (M:GetAttribute("Knocked") or M:GetAttribute("TakenDownBy") or M:GetAttribute("GrippedBy")
			or M:GetAttribute("CarriedBy")) and Takedown.Phases[M:GetAttribute("Awareness")] then
			local D = PR.Position - TR.Position
			local Dist = Flat(D).Magnitude
			if Dist <= Takedown.Range and math.abs(D.Y) <= Takedown.Height and Dist < BestDist
				and Takedown.Behind(TR.CFrame.LookVector, D) then
				local Class = ClassOf(M)
				if Class ~= "Immune" then Best, BestClass, BestDist = M, Class, Dist end
			end
		end
	end
	return Best, BestClass
end

-- (Task 12) a model the player prompt may sit on: another player's character, or in Studio a registered stand-in rig;
-- never an NPC (PvP only)
local function IsTarget(M)
	if not M:IsA("Model") or M == Player.Character then return false end
	if M:GetAttribute("EnemyType") ~= nil or M:GetAttribute("TownsfolkId") ~= nil or M:GetAttribute("DialogueId") ~= nil then
		return false
	end
	local P = Players:GetPlayerFromCharacter(M)
	if P then return P ~= Player end
	return RunService:IsStudio() and TakedownUI.TestPlayers[M.Name] == true
end

local HOSTAGE_BUSY = {"GrippedBy", "CarriedBy", "TakenDownBy", "HeldBy", "Holding", "Gripping", "Carrying", "TakingDown"}

-- (Task 12) the nearest player the local player could take hostage from where they stand, and its kind ("Bind" |
-- "Grab"); nil while hostages are off
function TakedownUI.PlayerCandidate()
	if not TakedownUI.HostagesOn() then return nil end
	local PR = PlayerReady(true)
	local World = workspace:FindFirstChild("World")
	local Live = World and World:FindFirstChild("Live")
	if not (PR and Live) then return nil end
	local Now = workspace:GetServerTimeNow()
	local Best, BestKind, BestDist = nil, nil, math.huge
	for _, M in ipairs(Live:GetChildren()) do
		local TR = IsTarget(M) and M:FindFirstChild("HumanoidRootPart")
		if TR and TR:IsA("BasePart") and Alive(M) and M:GetAttribute("Traversal") ~= "Swim"
			and Now >= (tonumber(M:GetAttribute("GrabImmuneUntil")) or 0) then
			local Busy = false
			for _, K in ipairs(HOSTAGE_BUSY) do
				if M:GetAttribute(K) then Busy = true break end
			end
			local D = PR.Position - TR.Position
			local Dist = Flat(D).Magnitude
			if not Busy and math.abs(D.Y) <= Hostage.Height and Dist < BestDist then
				if M:GetAttribute("Knocked") then
					if Dist <= Hostage.BindRange then Best, BestKind, BestDist = M, "Bind", Dist end
				elseif Dist <= Hostage.GrabRange and Hostage.Behind(TR.CFrame.LookVector, D) then
					Best, BestKind, BestDist = M, "Grab", Dist
				end
			end
		end
	end
	return Best, BestKind
end

local function Request(Kind, Target)
	UIState.Request("Takedown", Kind, Target)
end

local function Clear()
	HoldRig = nil
	if Prompt then Prompt:Destroy() end
	Prompt, Rig, RigClass, PromptFor = nil, nil, nil, nil
end

-- (Task 12) the player prompt: a press asks for the take at once (HoldDuration 0: no hold to guard)
local function MakePlayer()
	local P = Instance.new("ProximityPrompt")
	P.Name = "TakedownPrompt"
	P.Style = Enum.ProximityPromptStyle.Custom
	P.KeyboardKeyCode = TakedownUI.Key()
	P.HoldDuration = 0
	P.RequiresLineOfSight = false
	P.MaxActivationDistance = math.max(Hostage.BindRange, Hostage.GrabRange) + 2
	P.Triggered:Connect(function()
		if Prompt == P and PromptFor == "Player" and Rig then UIState.Request("Hostage", "Take", Rig) end
	end)
	return P
end

local function Make()
	local P = Instance.new("ProximityPrompt")
	P.Name = "TakedownPrompt"
	P.Style = Enum.ProximityPromptStyle.Custom
	P.KeyboardKeyCode = TakedownUI.Key()
	P.HoldDuration = Takedown.HoldToKill
	P.RequiresLineOfSight = false
	P.MaxActivationDistance = Takedown.Range + 2
	P.PromptButtonHoldBegan:Connect(function()
		HoldRig, HoldAt, Fired = Rig, os.clock(), false
	end)
	P.Triggered:Connect(function()
		if HoldRig == nil or HoldRig ~= Rig then return end
		Fired = true
		Request("Assassinate", Rig)
	end)
	P.PromptButtonHoldEnded:Connect(function()
		local Target, At = HoldRig, HoldAt
		if not Target then return end
		task.delay(TakedownUI.TapGrace, function()
			if HoldAt ~= At then return end -- a newer hold began: it decides
			HoldRig = nil
			-- a tap: the hold ended on the same rig and no Triggered came. A Chunk target has no knockout.
			if not Fired and Target == Rig and RigClass ~= "Chunk" then Request("Knockout", Target) end
		end)
	end)
	return P
end

-- (Task 12) the display name a player prompt shows: the Player's DisplayName, else the rig's own
local function NameOf(M)
	local P = Players:GetPlayerFromCharacter(M)
	return P and P.DisplayName or tostring(M:GetAttribute("DisplayName") or M.Name)
end

function TakedownUI.Update()
	local Next, Class = TakedownUI.Candidate()
	local For = "Enemy"
	if not Next then
		-- (Task 12) no enemy candidate: a player one (an enemy candidate always wins, decision 2)
		Next, Class = TakedownUI.PlayerCandidate()
		For = "Player"
	end
	if not (Next and TakedownUI.Offered()) then Clear() return end
	if Next ~= Rig or For ~= PromptFor or not (Prompt and Prompt.Parent) then
		-- (Task 11) a fresh prompt per target: the old one may have gone with its rig, so it is never reparented; Clear
		-- also drops any hold (a hold never carries over to another rig). (Task 12) and a fresh one per kind of target
		Clear()
		Prompt = For == "Player" and MakePlayer() or Make()
		Rig, PromptFor = Next, For
		Prompt.Parent = Next.HumanoidRootPart
	end
	RigClass = Class
	if For == "Player" then
		Prompt.ObjectText = NameOf(Next)
		Prompt.ActionText = TakedownUI.HostageText[Class]
		return
	end
	Prompt.ObjectText = tostring(Next:GetAttribute("DisplayName") or Next.Name) .. " (" .. tostring(Next:GetAttribute("Awareness")):lower() .. ")"
	Prompt.ActionText = Class == "Chunk" and "Backstab (hold)" or "Knock out · hold to kill"
end

function TakedownUI.Start()
	-- a rebind: drop the prompt (and any hold on it); the next pick makes it again on the new key
	Keybinds.Changed:Connect(function(Name)
		if Name == "Takedown" then Clear() end
	end)
	task.spawn(function()
		while true do
			local Ok, Err = pcall(TakedownUI.Update)
			if not Ok then
				pcall(Clear)
				if not TakedownUI._Warned then TakedownUI._Warned = true warn("[TakedownUI] " .. tostring(Err)) end
			end
			task.wait(TakedownUI.Tick)
		end
	end)
end

return TakedownUI

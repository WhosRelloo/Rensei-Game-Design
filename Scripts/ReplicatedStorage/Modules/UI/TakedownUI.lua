-- TakedownUI (assassinations Task 10, 2026-10-25; spec Documents/specs/2026-10-25-assassinations-design.md): the
-- takedown prompt. Display and input only: TakedownService (server) decides every takedown, and refuses a player's
-- character first (PvE only).
--   * Every Tick seconds it picks a candidate: the nearest enemy in World.Live (a direct child Model with an EnemyType
--     attribute, never a player's character or a townsperson) that is alive; not Knocked, TakenDownBy, GrippedBy or
--     CarriedBy; in a phase a takedown allows (Takedown.Phases: never Alert); not Immune (Takedown.ClassOf, from
--     Takedown.PerceptionTypeOf: an untracked AlwaysAware type is Immune); with the player in its rear arc
--     (Takedown.Behind, no slack: the server's AngleSlack and RangeSlack are only for lag), within Takedown.Range on the
--     ground plane and Takedown.Height up or down.
--   * Only while the player can take one down: alive; not Knocked, Gripping, Carrying or TakingDown; Calm (not in
--     Combat Mode); not swimming; off cooldown (workspace:GetServerTimeNow() >= TakedownReadyAt); no conversation open
--     (Gui.Dialogue, as CombatModeUI checks) and no cutscene (a Scriptable camera).
--   * One ProximityPrompt, TakedownPrompt, made here on the client under the candidate's HumanoidRootPart, Style Custom
--     (drawn by PromptUI, the game's existing prompt art: no new UI assets), on Takedown.Key (N, reserved in
--     Rensei.Settings). It moves to a new candidate, and is destroyed when there is none.
--   * Input: a tap (the hold ends and no Triggered follows within TapGrace) asks for a knockout; a full hold (Triggered)
--     asks for an assassination. A Chunk target (an Elite) can only be backstabbed: a tap does nothing. Touch: PromptUI's own
--     tap button holds the prompt (tap / hold), so the prompt is the touch control too.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIState = require(script.Parent.UIState)
local Rensei = ReplicatedStorage.Modules.Data.Rensei
local Takedown = require(Rensei.Takedown)
local Tuning = require(Rensei.TuningConfig)

local Player = Players.LocalPlayer

local TakedownUI = {}
TakedownUI.Tick = 0.1 -- seconds between candidate picks (the plan's 0.1 s)

local Prompt = nil -- the TakedownPrompt, while there is a candidate
local Rig = nil -- the candidate it sits on
local RigClass = nil -- its class: "Full" | "Chunk"
local HoldRig = nil -- the rig a hold began on (nil: no hold, or the prompt moved since)
local HoldAt = 0 -- when that hold began
local Fired = false -- Triggered since the hold began
-- A completed hold fires PromptButtonHoldEnded just BEFORE Triggered (measured in Ye Play, 2026-10-27: 4 ms apart), so a
-- hold's end waits this long for a Triggered before it counts as a tap. PROPOSAL.
TakedownUI.TapGrace = 0.1

local function Alive(Model)
	local H = Model:FindFirstChildOfClass("Humanoid")
	return H ~= nil and H.Health > 0
end

local function Flat(V) return Vector3.new(V.X, 0, V.Z) end

-- the player can take one down now (the server checks all of it again)
local function PlayerReady()
	local C = Player.Character
	local Root = C and C:FindFirstChild("HumanoidRootPart")
	local H = C and C:FindFirstChildOfClass("Humanoid")
	if not (Root and H and H.Health > 0) then return nil end
	for _, K in ipairs({"Knocked", "Gripping", "Carrying", "TakingDown", "CombatMode"}) do
		if C:GetAttribute(K) then return nil end
	end
	if C:GetAttribute("Traversal") == "Swim" or H:GetState() == Enum.HumanoidStateType.Swimming then return nil end
	if workspace:GetServerTimeNow() < (tonumber(C:GetAttribute("TakedownReadyAt")) or 0) then return nil end
	local G = UIState.Gui
	if G:FindFirstChild("Dialogue") and G.Dialogue.Visible then return nil end
	if workspace.CurrentCamera.CameraType == Enum.CameraType.Scriptable then return nil end
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

local function Request(Kind, Target)
	UIState.Request("Takedown", Kind, Target)
end

local function Clear()
	HoldRig = nil
	if Prompt then Prompt:Destroy() end
	Prompt, Rig, RigClass = nil, nil, nil
end

local function Make()
	local P = Instance.new("ProximityPrompt")
	P.Name = "TakedownPrompt"
	P.Style = Enum.ProximityPromptStyle.Custom
	P.KeyboardKeyCode = Enum.KeyCode[Takedown.Key]
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

function TakedownUI.Update()
	local Next, Class = TakedownUI.Candidate()
	if not Next then Clear() return end
	if Next ~= Rig then
		HoldRig = nil -- a hold never carries over to another rig
		Prompt = Prompt or Make()
		Rig = Next
		Prompt.Parent = Next.HumanoidRootPart
	end
	RigClass = Class
	Prompt.ObjectText = tostring(Next:GetAttribute("DisplayName") or Next.Name) .. " (" .. tostring(Next:GetAttribute("Awareness")):lower() .. ")"
	Prompt.ActionText = Class == "Chunk" and "Backstab (hold)" or "Knock out · hold to kill"
end

function TakedownUI.Start()
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

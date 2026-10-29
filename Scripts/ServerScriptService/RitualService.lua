-- RitualService (2026-10-19): the Alchemic Binding between two players. Rules and numbers: Rensei.Ritual (header).
-- Everything is decided here; clients only see a circle, prompts, the dialogue box and toasts.
--
-- FLOW
--   1. DRAW: the caster uses Transmutation Chalk (ItemService.Use -> BeginCircle). Checks: an alchemist (saved path)
--      who has passed a Truth/Gate trial, holding chalk, not fighting / knocked / held / swimming / at the Gate.
--      A circle appears at their feet with Ritual.Marks inscription marks around it; the caster holds each one.
--   2. PERFORM: the caster holds the circle's centre prompt. Exactly one other living player must stand inside.
--      The kind follows from the target: a target with no alchemy -> BINDING; a target bound to the armor ->
--      RESTORATION (always succeeds). Anyone else is refused with the reason.
--   3. CONSENT: the target gets a question in the dialogue box with the full terms and the odds (both players see
--      the odds); "I consent" / "Refuse". No answer within Ritual.ConsentWindow, walking away, fighting, leaving or
--      another conversation all count as a refusal. A refusal blocks that caster asking that target again for a while.
--   4. ACTIVE: Ritual.ActiveSeconds. Either player hit, knocked, dying or leaving, the target stepping out or the caster
--      walking away aborts it (no roll, no chalk spent, no cooldown).
--   5. RESOLVE (exactly once; the circle is closed before it runs, nothing yields between the check and the writes):
--      one chalk spent; cooldowns set; one server roll against the chance shown.
--        success -> QuestService.Grant {Affinity = the caster's path} (the trainers' route: one path, set once)
--        failure -> Binding.Armor saved; the target becomes the Alchemic Armor; the caster takes a rebound
--      Restoration clears Binding.Armor and gives the body back.
-- PERSISTENCE: Binding.Armor lives in the profile; every spawn (death, respawn, rejoin) puts the armor back on until
--   a restoration (or Ritual.AutoRestoreSeconds pass). While bound: Character attributes AlchemicArmor and
--   ArmorResist (DamageManager reads it), and Truth won't summon (TruthService Safe).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Ritual = require(ReplicatedStorage.Modules.Data.Rensei.Ritual)
local Truth = require(ReplicatedStorage.Modules.Data.Rensei.Truth)
local Registry = require(ReplicatedStorage.Modules.Data.Rensei.Alchemy) -- the five paths (Affinities)
local ProgressionService = require(ServerScriptService.ProgressionService)
local UIService = require(ServerScriptService.UIService)
local DataManager = require(ServerScriptService.CharacterHandler.DataManager)
local DownedManager = require(ReplicatedStorage.Modules.Managers.DownedManager)

local RitualService = {}
local Circles = {} -- [Caster] = circle
local Refused = {} -- ["casterId:targetId"] = os.clock() until which that caster can't ask that target again
local Rng = Random.new()

local CHALK = Color3.fromRGB(240, 238, 228)
local GLOW = Color3.fromRGB(150, 205, 255)

local function Toast(Player, Text) UIService.Notify(Player, "Toast", {Text = Text}) end
local function Data(Player) return ProgressionService.GetData(Player) end
local function Root(C) return C and C:FindFirstChild("HumanoidRootPart") end
local function Alive(C)
	local H = C and C:FindFirstChildOfClass("Humanoid")
	return H ~= nil and H.Health > 0
end
local function PathOf(D) return (D and type(D.Identity) == "table" and D.Identity.Affinity) or "" end
local function Flat(V) return Vector3.new(V.X, 0, V.Z).Magnitude end
local function Span(Seconds)
	Seconds = math.max(0, math.floor(Seconds))
	if Seconds >= 3600 then return ("%dh %dm"):format(Seconds // 3600, (Seconds % 3600) // 60) end
	return ("%dm"):format(math.max(1, Seconds // 60))
end

-- what stops someone taking part right now (nil = nothing)
local function Busy(C)
	if not Alive(C) or not Root(C) then return "not able to" end
	if C:GetAttribute("InCombat") or C:GetAttribute("CombatMode") then return "fighting" end
	if C:GetAttribute("InGate") then return "at the Gate" end
	if DownedManager.IsKnocked(C) then return "knocked down" end
	-- (hostages Task 13, the shared exclusion) a captor (Holding) or a hostage (HeldBy) takes part in no binding either
	for _, A in ipairs({"GrippedBy", "CarriedBy", "Gripping", "Carrying", "Holding", "HeldBy"}) do
		if C:GetAttribute(A) then return "held" end
	end
	if C:GetAttribute("Traversal") == "Swim" then return "swimming" end
	return nil
end

-- ===== chalk (the inventory entry; ItemService's rules) =====
local function ChalkIndex(Player)
	local Profile = DataManager:GetProfile(Player)
	if not Profile then return nil end
	for I, Item in ipairs(Profile.Data.Inventory) do
		if Item.ItemName == Ritual.Item and (Item.Amount or 1) > 0 then return I, Profile end
	end
	return nil
end

local function SpendChalk(Player)
	local I, Profile = ChalkIndex(Player)
	if not I then return false end
	local Item = Profile.Data.Inventory[I]
	if (Item.Amount or 1) > 1 then
		Item.Amount = (Item.Amount or 1) - 1
	else
		require(ServerScriptService.ItemService).RemoveIndex(Profile.Data, I)
		for _, Where in ipairs({Player.Character, Player:FindFirstChildOfClass("Backpack")}) do
			local T = Where and Where:FindFirstChild(Ritual.Item)
			if T and T:IsA("Tool") then T:Destroy() end
		end
	end
	DataManager:SendData(Player)
	return true
end

-- ===== the odds, explained (both players see this) =====
local function Odds(CasterData)
	local C = Ritual.Chance
	local Chance = Ritual.SuccessChance(CasterData)
	local Trials = CasterData.Gate.TrialsPassed or 0
	local Alchemy = (CasterData.Stats and CasterData.Stats.Alchemy) or 1
	return Chance, ("%d%% (base %d%%, +%d%% for %d Gate trial%s, +%.1f%% for Alchemy %d; max %d%%)"):format(
		math.floor(Chance * 100 + 0.5), C.Base * 100, math.floor(C.PerTrial * Trials * 100 + 0.5), Trials, Trials == 1 and "" or "s",
		C.PerAlchemy * (Alchemy - 1) * 100, Alchemy, C.Max * 100)
end

-- ===== the Alchemic Armor =====
local function ArmorAsset()
	local A = ReplicatedStorage:FindFirstChild("Assets")
	A = A and A:FindFirstChild("RELLO IMPORTED ASSETS")
	A = A and A:FindFirstChild("ArmourSet (FULL METAL ALCHEMIST)")
	return A and A:FindFirstChild("ArmourSet")
end

-- R6 limbs at rest, in Torso space
local REST = {
	Torso = CFrame.identity, Head = CFrame.new(0, 1.5, 0),
	["Right Arm"] = CFrame.new(1.5, 0, 0), ["Left Arm"] = CFrame.new(-1.5, 0, 0),
	["Right Leg"] = CFrame.new(0.5, -2, 0), ["Left Leg"] = CFrame.new(-0.5, -2, 0),
}
local LIMB_OF = {Hair = "Head", Apron = "Torso", Coverup = "Torso"} -- anything else: its own name, else the nearest limb
local FACE = CFrame.Angles(0, math.rad(-90), 0) -- the asset faces -X; R6 faces -Z

local function Hide(Character, Inst, Armor)
	if Inst:IsDescendantOf(Armor) or Inst.Name == "HumanoidRootPart" then return end
	if Inst:IsA("BasePart") or Inst:IsA("Decal") then
		if Inst:GetAttribute("ArmorPrevT") == nil then Inst:SetAttribute("ArmorPrevT", Inst.Transparency) end
		Inst.Transparency = 1
	end
end

local Hooks = {} -- [Character] = DescendantAdded connection (keeps new accessories hidden)

local function ApplyArmor(Character)
	if not Character or Character:FindFirstChild("AlchemicArmor") then return end
	local Torso = Character:FindFirstChild("Torso")
	local Asset = ArmorAsset()
	if not Torso or not Asset or not Asset:FindFirstChild("Torso") then warn("[RitualService] armor asset or Torso missing") return end
	local S = Ritual.Armor.Scale
	local ATorso = Asset.Torso.Position
	local M = Instance.new("Model")
	M.Name = "AlchemicArmor"
	for _, Src in ipairs(Asset:GetDescendants()) do
		if Src:IsA("BasePart") then
			local P = Src:Clone()
			P:ClearAllChildren()
			for _, Ch in ipairs(Src:GetChildren()) do -- keep looks (textures, surface appearance), drop welds / scripts
				if Ch:IsA("SurfaceAppearance") or Ch:IsA("Decal") or Ch:IsA("Texture") or Ch:IsA("SpecialMesh") then Ch:Clone().Parent = P end
			end
			P.Size = Src.Size * S
			P.Anchored, P.CanCollide, P.CanQuery, P.CanTouch, P.Massless = false, false, false, false, true
			-- the part in Torso space: offset from the asset's Torso (world axes), scaled, turned to face -Z
			local Rel = FACE * CFrame.new((Src.Position - ATorso) * S) * Src.CFrame.Rotation
			local Limb = LIMB_OF[Src.Name] or (REST[Src.Name] and Src.Name)
			if not Limb then
				local Best = math.huge
				for Name, CF in pairs(REST) do
					local D = (CF.Position - Rel.Position).Magnitude
					if D < Best then Best, Limb = D, Name end
				end
			end
			local Part0 = Character:FindFirstChild(Limb) or Torso
			local W = Instance.new("Weld")
			W.Part0, W.Part1 = Part0, P
			W.C0 = (REST[Part0.Name] or CFrame.identity):Inverse() * Rel
			W.Parent = P
			P.CFrame = Part0.CFrame * W.C0
			P.Parent = M
		end
	end
	M.Parent = Character
	for _, D in ipairs(Character:GetDescendants()) do Hide(Character, D, M) end
	if Hooks[Character] then Hooks[Character]:Disconnect() end
	Hooks[Character] = Character.DescendantAdded:Connect(function(D)
		if M.Parent then Hide(Character, D, M) end
	end)
	Character:SetAttribute("AlchemicArmor", true)
	Character:SetAttribute("ArmorResist", Ritual.Armor.DamageResist)
end

local function RemoveArmor(Character)
	if not Character then return end
	local M = Character:FindFirstChild("AlchemicArmor")
	if M then M:Destroy() end
	if Hooks[Character] then Hooks[Character]:Disconnect() Hooks[Character] = nil end
	for _, D in ipairs(Character:GetDescendants()) do
		local T = D:GetAttribute("ArmorPrevT")
		if T ~= nil then D.Transparency = T D:SetAttribute("ArmorPrevT", nil) end
	end
	Character:SetAttribute("AlchemicArmor", nil)
	Character:SetAttribute("ArmorResist", nil)
end
RitualService.ApplyArmor, RitualService.RemoveArmor = ApplyArmor, RemoveArmor

function RitualService.Bound(Player)
	local D = Data(Player)
	return D ~= nil and D.Binding ~= nil and D.Binding.Armor == true
end

-- ===== resolution (exactly once per performed circle) =====
-- Run = {Caster, Target, Kind = "Binding" | "Restoration", Path, Chance}. Returns outcome, roll (or nil, reason).
function RitualService.Resolve(Run)
	local CD, TD = Data(Run.Caster), Data(Run.Target)
	if not CD or not TD then return nil, "profile not loaded" end
	-- the state that decides the outcome, checked right before it's written
	if Run.Kind == "Restoration" then
		if not TD.Binding.Armor then return nil, "nothing to restore" end
	elseif TD.Binding.Armor or PathOf(TD) ~= "" then
		return nil, "the target changed"
	elseif not table.find(Registry.Affinities, Run.Path) then
		return nil, "unknown path " .. tostring(Run.Path) -- never roll for a path the grant would refuse
	end
	if not SpendChalk(Run.Caster) then return nil, "no chalk" end
	local Now = os.time()
	if Run.Kind == "Restoration" then
		TD.Binding.Armor = false
		CD.Binding.CasterCooldownUntil = math.max(CD.Binding.CasterCooldownUntil or 0, Now + Ritual.RestoreCooldown)
		RemoveArmor(Run.Target.Character)
		ProgressionService.Sync(Run.Target)
		if Run.Caster ~= Run.Target then ProgressionService.Sync(Run.Caster) end
		return "Restored", 0
	end
	CD.Binding.CasterCooldownUntil = Now + Ritual.CasterCooldown
	TD.Binding.TargetCooldownUntil = Now + Ritual.TargetCooldown
	local Roll = Rng:NextNumber()
	local Outcome
	if Roll < Run.Chance then
		Outcome = "Success"
		TD.Binding.Granted = Run.Path
		require(ServerScriptService.QuestService).Grant(Run.Target, {Affinity = Run.Path}, "AlchemicBinding")
	else
		Outcome = "Failure"
		TD.Binding.Armor, TD.Binding.At, TD.Binding.By = true, Now, tostring(Run.Caster.UserId)
		ApplyArmor(Run.Target.Character)
		local H = Run.Caster.Character and Run.Caster.Character:FindFirstChildOfClass("Humanoid")
		if H and H.Health > 0 then H.Health = math.max(1, H.Health - H.MaxHealth * Ritual.Rebound) end
	end
	ProgressionService.Sync(Run.Target)
	if Run.Caster ~= Run.Target then ProgressionService.Sync(Run.Caster) end
	return Outcome, Roll
end

-- ===== the circle =====
local function Folder()
	local F = workspace:FindFirstChild("RitualCircles")
	if not F then F = Instance.new("Folder") F.Name = "RitualCircles" F.Parent = workspace end
	return F
end

local function Ground(Player)
	local R = Root(Player.Character)
	local Skip = {Folder()}
	for _, P in ipairs(Players:GetPlayers()) do if P.Character then table.insert(Skip, P.Character) end end
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = Skip
	local Hit = workspace:Raycast(R.Position, Vector3.new(0, -12, 0), Params)
	return Hit and Hit.Position
end

local function Cancel(Circle, Why)
	if Circle.Closed then return end
	Circle.Closed = true
	if Circles[Circle.Caster] == Circle then Circles[Circle.Caster] = nil end
	for _, P in ipairs({Circle.Caster, Circle.Target}) do
		if P and P.Character then P.Character:SetAttribute("InRitual", nil) end
	end
	if Why and Circle.Caster.Parent then Toast(Circle.Caster, Why) end
	if Circle.Model then Circle.Model:Destroy() end
end

local function Prompt(Parent, Action, Object, Hold, Range)
	local P = Instance.new("ProximityPrompt")
	P.ActionText, P.ObjectText, P.HoldDuration = Action, Object, Hold
	P.MaxActivationDistance, P.RequiresLineOfSight = Range, false
	P.Style = Enum.ProximityPromptStyle.Custom -- drawn in Rensei's art by Modules.UI.PromptUI (click / tap / key)
	P.Parent = Parent
	return P
end

local function Glow(Circle, Color, Brightness)
	Circle.Decal.Color3, Circle.Decal.Transparency = Color, 0.05
	Circle.Light.Color, Circle.Light.Brightness = Color, Brightness
	Circle.Sparks.Color = ColorSequence.new(Color)
end

-- why the active transmutation must stop (nil = carry on)
local function ActiveProblem(Circle, Since)
	local C, T = Circle.Caster, Circle.Target
	if not C.Parent or not T.Parent then return "Someone left. The circle goes dark." end
	local CC, TC = C.Character, T.Character
	if not Alive(CC) or not Alive(TC) or not Root(CC) or not Root(TC) then return "The transmutation broke: someone fell." end
	if DownedManager.IsKnocked(CC) or DownedManager.IsKnocked(TC) then return "The transmutation broke: someone was knocked down." end
	if (CC:GetAttribute("LastHitAt") or 0) > Since or (TC:GetAttribute("LastHitAt") or 0) > Since then return "The transmutation broke: someone was hit." end
	if Flat(Root(TC).Position - Circle.Center) > Ritual.Radius then return "The transmutation broke: the target left the circle." end
	if Flat(Root(CC).Position - Circle.Center) > Ritual.CasterRange then return "The transmutation broke: you stepped away from the circle." end
	return nil
end

local function Perform(Circle)
	if Circle.Phase ~= "Ready" or Circle.Closed then return end
	local Caster = Circle.Caster
	local Problem = Busy(Caster.Character)
	if Problem then Toast(Caster, "You can't perform it while " .. Problem .. ".") return end
	local Inside = {}
	for _, P in ipairs(Players:GetPlayers()) do
		local R = P ~= Caster and Root(P.Character)
		if R and Alive(P.Character) and Flat(R.Position - Circle.Center) <= Ritual.Radius and math.abs(R.Position.Y - Circle.Center.Y) < 6 then
			table.insert(Inside, P)
		end
	end
	if #Inside == 0 then Toast(Caster, "Nobody is standing in the circle.") return end
	if #Inside > 1 then Toast(Caster, "Only one person may stand in the circle.") return end
	local Target = Inside[1]
	local CD, TD = Data(Caster), Data(Target)
	if not CD or not TD then Toast(Caster, "They aren't ready yet.") return end
	local Kind = TD.Binding.Armor and "Restoration" or "Binding"
	if Kind == "Binding" then
		if PathOf(TD) ~= "" then Toast(Caster, Target.DisplayName .. " already has alchemy. A binding can only give it to someone without.") return end
		if (TD.Binding.TargetCooldownUntil or 0) > os.time() then
			Toast(Caster, ("%s's soul is still settling from a binding (%s)."):format(Target.DisplayName, Span(TD.Binding.TargetCooldownUntil - os.time()))) return
		end
		if (CD.Binding.CasterCooldownUntil or 0) > os.time() then
			Toast(Caster, ("You can't attempt another binding for %s."):format(Span(CD.Binding.CasterCooldownUntil - os.time()))) return
		end
	end
	local TBusy = Busy(Target.Character)
	if TBusy then Toast(Caster, ("%s is %s."):format(Target.DisplayName, TBusy)) return end
	local Key = Caster.UserId .. ":" .. Target.UserId
	if (Refused[Key] or 0) > os.clock() then Toast(Caster, Target.DisplayName .. " just refused. Give them some time.") return end
	if not ChalkIndex(Caster) then Toast(Caster, "You're out of chalk.") return end

	-- CONSENT
	Circle.Phase, Circle.Target = "Consent", Target
	Caster.Character:SetAttribute("InRitual", true)
	Target.Character:SetAttribute("InRitual", true)
	local Chance, OddsText, Text = 1, "", nil
	local Path = PathOf(CD)
	if Kind == "Binding" then
		Chance, OddsText = Odds(CD)
		-- the dialogue box shrinks long text to unreadable: the question stays short, the full terms go in a toast
		Text = ("%s offers an Alchemic Binding. %d%% chance: success gives you %s Alchemy for good; failure binds your soul to armor. Consent?")
			:format(Caster.DisplayName, math.floor(Chance * 100 + 0.5), Path)
		Toast(Target, ("Binding terms: success = %s Alchemy (your one path). Failure = bound to the armor until an alchemist who has seen the Gate restores you, or %s pass. Odds: %s.")
			:format(Path, Span(Ritual.AutoRestoreSeconds), OddsText))
		Toast(Caster, ("Waiting for %s's answer. Chance of success: %s."):format(Target.DisplayName, OddsText))
	else
		Text = ("%s offers a Restoration: your soul goes back to your body. It always succeeds. Consent?"):format(Caster.DisplayName)
		Toast(Caster, ("Waiting for %s's answer (restoration)."):format(Target.DisplayName))
	end
	local DialogueService = require(ServerScriptService.DialogueService)
	local Answer, Answered = nil, false
	DialogueService.Ask(Target, Circle.Core, "Transmutation Circle", Text, {"I consent", "Refuse"}, function(I) Answer, Answered = I, true end)
	local Until = os.clock() + Ritual.ConsentWindow
	while not Answered and os.clock() < Until and not Circle.Closed and Caster.Parent and Target.Parent do task.wait(0.2) end
	if not Answered and Target.Parent then DialogueService.Close(Target) end -- still our question: take it down
	if Circle.Closed then return end
	if Answer ~= 1 then
		Refused[Key] = os.clock() + Ritual.RefuseCooldown
		if Target.Character then Target.Character:SetAttribute("InRitual", nil) end
		if Caster.Character then Caster.Character:SetAttribute("InRitual", nil) end
		Circle.Phase, Circle.Target = "Ready", nil
		if Caster.Parent then Toast(Caster, Target.DisplayName .. " did not consent.") end
		return
	end

	-- ACTIVE
	Circle.Phase = "Active"
	Circle.PerformPrompt.Enabled = false
	Glow(Circle, GLOW, 3)
	Circle.Sparks.Enabled = true
	Toast(Caster, "The circle answers. Hold still.")
	Toast(Target, "The circle answers. Hold still.")
	local Since = workspace:GetServerTimeNow()
	local Start = os.clock()
	while os.clock() - Start < Ritual.ActiveSeconds do
		task.wait(0.2)
		if Circle.Closed then return end
		local Why = ActiveProblem(Circle, Since)
		if Why then
			if Target.Parent then Toast(Target, Why) end
			Cancel(Circle, Why)
			return
		end
	end

	-- RESOLVE: the circle is closed first, so nothing can run this twice
	Circle.Closed = true
	Circles[Caster] = nil
	Caster.Character:SetAttribute("InRitual", nil)
	Target.Character:SetAttribute("InRitual", nil)
	local Outcome, Roll = RitualService.Resolve({Caster = Caster, Target = Target, Kind = Kind, Path = Path, Chance = Chance})
	if not Outcome then
		Toast(Caster, "The circle fizzles (" .. tostring(Roll) .. ").")
		Circle.Model:Destroy()
		return
	end
	local Lines = {
		Success = {Color3.fromRGB(120, 200, 255), ("The binding holds. %s now has %s Alchemy."):format(Target.DisplayName, Path), ("The binding holds. You have %s Alchemy."):format(Path)},
		Failure = {Color3.fromRGB(230, 70, 60), ("The binding fails. %s's soul is bound to the armor - and the circle takes its toll on you."):format(Target.DisplayName),
			("The binding fails. Your soul is bound to the armor. An alchemist who has seen the Gate can restore you with a circle (or wait %s)."):format(Span(Ritual.AutoRestoreSeconds))},
		Restored = {Color3.fromRGB(255, 236, 170), ("%s is restored."):format(Target.DisplayName), "Your soul returns to your body."},
	}
	local L = Lines[Outcome]
	Glow(Circle, L[1], 6)
	Circle.Sparks:Emit(40)
	Toast(Caster, L[2] .. (Kind == "Binding" and (" (rolled %d vs %d%%)"):format(math.floor(Roll * 100), math.floor(Chance * 100 + 0.5)) or ""))
	Toast(Target, L[3])
	print(("[RitualService] %s: %s -> %s, %s (roll %.3f, chance %.2f)"):format(Kind, Caster.Name, Target.Name, Outcome, Roll, Chance))
	task.delay(1.5, function() Circle.Model:Destroy() end)
end

-- a mark's prompt (also callable by Studio tests: script-held prompts don't reach the server)
function RitualService.Inscribe(Who, Circle, K)
	local Player = Circle.Caster
	if Who ~= Player then Toast(Who, "Only the alchemist who drew this circle can inscribe it.") return false end
	if Circle.Closed or Circle.Phase ~= "Drawing" then return false end
	local Mark = Circle.Model:FindFirstChild("Mark" .. K)
	local P = Mark and Mark:FindFirstChildOfClass("ProximityPrompt")
	if not P then return false end -- already inscribed
	local R = Root(Player.Character)
	if not R or (R.Position - Mark.Position).Magnitude > P.MaxActivationDistance + 2 then return false end
	P:Destroy()
	Mark.Transparency = 0
	Circle.Marks += 1
	Circle.Decal.Transparency = 0.8 - 0.6 * (Circle.Marks / Ritual.Marks)
	if Circle.Marks >= Ritual.Marks then
		Circle.Phase = "Ready"
		Circle.Expires = os.clock() + Ritual.DrawWindow
		Circle.PerformPrompt = Prompt(Circle.Core, "Perform transmutation", Player.DisplayName .. "'s circle", Ritual.PerformHold, Ritual.CasterRange + 1)
		Circle.PerformPrompt.Triggered:Connect(function(W) RitualService.PerformBy(W, Circle) end)
		local _, OddsText = Odds(Data(Player))
		Toast(Player, "Circle complete. One person stands inside, then hold Perform. Binding odds: " .. OddsText .. ". A bound soul can be restored the same way.")
	end
	return true
end

-- the centre's prompt (also callable by Studio tests)
function RitualService.PerformBy(Who, Circle)
	if Who ~= Circle.Caster then Toast(Who, "Only the alchemist who drew this circle can perform it.") return end
	Perform(Circle)
end

function RitualService.CircleOf(Player) return Circles[Player] end

-- ItemService.Use (Transmutation Chalk): start a circle at the caster's feet
function RitualService.BeginCircle(Player)
	local Existing = Circles[Player]
	if Existing then Toast(Player, "You already have a circle drawn.") return false end
	local D = Data(Player)
	if not D then return false end
	if not table.find(Registry.Affinities, PathOf(D)) then Toast(Player, "Only an alchemist can draw a working circle.") return false end
	if (D.Gate.TrialsPassed or 0) < Ritual.CasterTrialsPassed then
		Toast(Player, "You haven't seen the Gate. A circle like this would eat you alive.") return false
	end
	local Problem = Busy(Player.Character)
	if Problem then Toast(Player, "You can't draw a circle while " .. Problem .. ".") return false end
	if not ChalkIndex(Player) then Toast(Player, "You're out of chalk.") return false end
	local Center = Ground(Player)
	if not Center then Toast(Player, "There's no ground here to draw on.") return false end
	for _, Other in pairs(Circles) do
		if Flat(Other.Center - Center) < Ritual.Radius * 2 then Toast(Player, "Too close to another circle.") return false end
	end

	local Circle = {Caster = Player, Center = Center, Phase = "Drawing", Marks = 0, Expires = os.clock() + Ritual.DrawWindow}
	local M = Instance.new("Model")
	M.Name = "TransmutationCircle_" .. Player.UserId
	local Base = Instance.new("Part")
	Base.Name = "Circle"
	Base.Size = Vector3.new(Ritual.Radius * 2, 0.05, Ritual.Radius * 2)
	Base.CFrame = CFrame.new(Center + Vector3.new(0, 0.04, 0))
	Base.Transparency, Base.Anchored, Base.CanCollide, Base.CanQuery, Base.CanTouch = 1, true, false, false, false
	Base.Parent = M
	local Decal = Instance.new("Decal")
	Decal.Face, Decal.Texture, Decal.Color3, Decal.Transparency = Enum.NormalId.Top, Truth.CircleTexture, CHALK, 0.8
	Decal.Parent = Base
	local Core = Instance.new("Part")
	Core.Name = "Core"
	Core.Size = Vector3.new(1, 1, 1)
	Core.CFrame = CFrame.new(Center + Vector3.new(0, 1.2, 0))
	Core.Transparency, Core.Anchored, Core.CanCollide, Core.CanQuery, Core.CanTouch = 1, true, false, false, false
	Core.Parent = M
	local Light = Instance.new("PointLight")
	Light.Range, Light.Brightness, Light.Color = Ritual.Radius * 2.5, 0, GLOW
	Light.Parent = Core
	local Sparks = Instance.new("ParticleEmitter")
	Sparks.Enabled, Sparks.Rate = false, 30
	Sparks.Lifetime, Sparks.Speed = NumberRange.new(0.4, 0.9), NumberRange.new(4, 9)
	Sparks.SpreadAngle = Vector2.new(180, 180)
	Sparks.LightEmission, Sparks.Size = 1, NumberSequence.new(0.15, 0)
	Sparks.Parent = Core
	Circle.Model, Circle.Decal, Circle.Core, Circle.Light, Circle.Sparks = M, Decal, Core, Light, Sparks

	for K = 1, Ritual.Marks do
		local A = (K - 1) * (2 * math.pi / Ritual.Marks)
		local Mark = Instance.new("Part")
		Mark.Name = "Mark" .. K
		Mark.Size = Vector3.new(0.7, 0.08, 0.7)
		Mark.CFrame = CFrame.new(Center + Vector3.new(math.cos(A) * Ritual.Radius, 0.06, math.sin(A) * Ritual.Radius)) * CFrame.Angles(0, A, 0)
		Mark.Color, Mark.Material, Mark.Transparency = CHALK, Enum.Material.Neon, 0.65
		Mark.Anchored, Mark.CanCollide, Mark.CanQuery, Mark.CanTouch = true, false, false, false
		Mark.Parent = M
		local P = Prompt(Mark, "Inscribe", ("%s's circle - mark %d/%d"):format(Player.DisplayName, K, Ritual.Marks), Ritual.MarkHold, 6)
		P.Triggered:Connect(function(Who) RitualService.Inscribe(Who, Circle, K) end)
	end
	M.Parent = Folder()
	Circles[Player] = Circle
	Toast(Player, ("You draw a circle. Inscribe its %d marks (hold each)."):format(Ritual.Marks))

	-- the caster has to stay with it; it fades if left unused
	task.spawn(function()
		while not Circle.Closed do
			task.wait(0.5)
			if Circle.Closed then break end
			if not Player.Parent then Cancel(Circle) break end
			local R = Root(Player.Character)
			if not Alive(Player.Character) or not R then Cancel(Circle, "Your circle fades.") break end
			if Circle.Phase ~= "Active" and Circle.Phase ~= "Consent" then
				if Flat(R.Position - Center) > Ritual.CasterRange + 4 then Cancel(Circle, "You walked away; your circle fades.") break end
				if os.clock() > Circle.Expires then Cancel(Circle, "Your circle fades unused.") break end
			end
		end
	end)
	return true
end

-- ===== persistence: the armor comes back with every spawn until restored =====
local function CheckSeal(Player)
	local D = Data(Player)
	if not D or not D.Binding or not D.Binding.Armor then return false end
	if os.time() - (D.Binding.At or 0) >= Ritual.AutoRestoreSeconds then
		D.Binding.Armor = false
		RemoveArmor(Player.Character)
		ProgressionService.Sync(Player)
		Toast(Player, "The seal has faded. Your soul is back in your body.")
		return false
	end
	return true
end

local function OnSpawn(Player, Character)
	task.spawn(function()
		-- the profile may still be loading on a fresh join; the look is applied just after spawn
		local Waited = 0
		while not Data(Player) and Waited < 30 and Player.Character == Character do Waited += task.wait(0.5) end
		task.wait(2)
		if Player.Character ~= Character or not CheckSeal(Player) then return end
		ApplyArmor(Character)
		local D = Data(Player)
		Toast(Player, ("Your soul is bound to the armor (you take %d%% less damage). An alchemist who has seen the Gate can restore you with a circle; otherwise the seal fades in %s.")
			:format(Ritual.Armor.DamageResist * 100, Span(Ritual.AutoRestoreSeconds - (os.time() - (D.Binding.At or 0)))))
	end)
end

function RitualService.Start()
	local function Hook(Player)
		if Player.Character then OnSpawn(Player, Player.Character) end
		Player.CharacterAdded:Connect(function(C) OnSpawn(Player, C) end)
	end
	for _, P in ipairs(Players:GetPlayers()) do Hook(P) end
	Players.PlayerAdded:Connect(Hook)
	Players.PlayerRemoving:Connect(function(Player)
		local C = Circles[Player]
		if C then Cancel(C) end
		for Key in pairs(Refused) do
			if Key:find("^" .. Player.UserId .. ":") or Key:find(":" .. Player.UserId .. "$") then Refused[Key] = nil end
		end
	end)
	task.spawn(function() -- the seal can fade while they're online
		while true do
			task.wait(60)
			for _, P in ipairs(Players:GetPlayers()) do
				if P.Character and P.Character:GetAttribute("AlchemicArmor") then CheckSeal(P) end
			end
		end
	end)
end

return RitualService

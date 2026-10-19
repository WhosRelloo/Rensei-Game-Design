-- PerceptionService (2026-10-19, Morality × Reputation spec §17.1-17.2, §17.10; slice S1): what NPCs notice.
-- Every registered NPC keeps an awareness 0..1 per player. It fills while the NPC sees them (view cone, clear
-- lines to head / torso / feet, distance, movement; light in Plan 2) and drains otherwise. The NPC's phase:
--   Unaware -> Suspicious (>= 0.35): walks to what it noticed; gives up after 8 s
--   -> Alert (1): fights a player it sees (through EnemyService / CombatDirector, unchanged); if it loses
--      them it searches around the last known spot and brings in NPCs within 40 studs
--   -> Cautious (after a failed search): 3 min with sight x1.3, then Unaware.
-- Being hit puts an NPC straight to Alert on the attacker. Enemies ask Target(Rig) / Goal(Rig) instead of
-- the old distance aggro; arena and trial foes (Perception.AlwaysAware) keep the old rule. WitnessService
-- asks Perceived(Player). Watchers placed in the world (townsfolk, guards) are tagged RenseiWatcher with
-- attributes WatcherType / Faction / Carrier. Cost: only NPCs within 80 studs of a player update, every
-- 0.2 s, at most 3 sight rays each and 120 per tick (spec §17.10).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local P = require(ReplicatedStorage.Modules.Data.Rensei.Perception)

local PerceptionService = {}
local Npcs = {} -- [Rig] = state
PerceptionService.Npcs = Npcs

-- the light on a character, 0..1 (Plan 2 replaces this with lamps, daylight and shadow)
PerceptionService.ExposureOf = function() return 1 end

local Rays = RaycastParams.new()
Rays.FilterType = Enum.RaycastFilterType.Exclude
local Budget = 0 -- sight rays left this tick (all NPCs)

-- perception time: advanced by Step(Dt), so every timer (memory, investigate, search, cautious) follows the
-- steps exactly -- the live loop passes real time, the tests step it by hand
local Clock = 0
local function Now() return Clock end

local function Alive(Model)
	local H = Model and Model:FindFirstChildOfClass("Humanoid")
	return H ~= nil and H.Health > 0
end

local function SetPhase(S, Phase)
	if S.Phase == Phase then return end
	S.Phase = Phase
	S.Since = Now()
	S.Rig:SetAttribute("Awareness", Phase)
end

function PerceptionService.Register(Rig, Info)
	if Npcs[Rig] then return Npcs[Rig] end
	local S = {
		Rig = Rig, Type = Info.Type or "Grunt", Faction = Info.Faction, Carrier = Info.Carrier == true,
		Combat = Info.Combat ~= false,
		Aware = {}, Seen = {}, Spot = {}, -- [Player] = awareness / os.clock() last seen / position last seen
		Phase = "Unaware", Since = Now(), Focus = nil, LastKnown = nil,
		InvestigateUntil = 0, SearchUntil = nil, CautiousUntil = 0, Turn = 0, Seed = math.random() * math.pi * 2,
	}
	Npcs[Rig] = S
	Rig:SetAttribute("Awareness", "Unaware")
	Rig.Destroying:Once(function() Npcs[Rig] = nil end)
	return S
end

function PerceptionService.Unregister(Rig) Npcs[Rig] = nil end
function PerceptionService.Tracks(Rig) return Npcs[Rig] ~= nil end
function PerceptionService.Awareness(Rig, Player) local S = Npcs[Rig] return S and S.Aware[Player] or 0 end
function PerceptionService.PhaseOf(Rig) local S = Npcs[Rig] return S and S.Phase or "Unaware" end

-- head, torso and feet of a character
local function Points(Character)
	local Head = Character:FindFirstChild("Head")
	local Torso = Character:FindFirstChild("Torso") or Character:FindFirstChild("UpperTorso")
	local Root = Character:FindFirstChild("HumanoidRootPart")
	if not (Head and Torso and Root) then return nil end
	return {Head.Position, Torso.Position, Root.Position - Vector3.new(0, 2.6, 0)}
end

-- the fraction (0, 1/3, 2/3, 1) of those points the NPC has a clear line to, within its own ray budget
local function Visible(S, Eye, Character, Allowance)
	local Pts = Points(Character)
	if not Pts then return 0, Allowance end
	Rays.FilterDescendantsInstances = {S.Rig, Character}
	local Clear = 0
	for _, Pt in ipairs(Pts) do
		if Budget <= 0 or Allowance <= 0 then break end
		Budget -= 1
		Allowance -= 1
		if not workspace:Raycast(Eye, Pt - Eye, Rays) then Clear += 1 end
	end
	return Clear / 3, Allowance
end

-- an Alert NPC brings in the others close by: they come to look at Where
local function Call(S, Player, Where)
	local Root = S.Rig:FindFirstChild("HumanoidRootPart")
	if not Root or not Where then return end
	for Rig, O in pairs(Npcs) do
		local R = O ~= S and Rig:FindFirstChild("HumanoidRootPart")
		if R and (R.Position - Root.Position).Magnitude <= P.CallRadius and O.Phase ~= "Alert" then
			O.Aware[Player] = math.max(O.Aware[Player] or 0, P.Suspicious)
			O.LastKnown = Where
			O.InvestigateUntil = Now() + P.InvestigateTime
			SetPhase(O, "Suspicious")
		end
	end
end

local function Calm(S, T)
	for K, A in pairs(S.Aware) do S.Aware[K] = math.min(A, P.Suspicious - 0.01) end
	S.LastKnown = nil
	SetPhase(S, T < S.CautiousUntil and "Cautious" or "Unaware")
end

local function Decide(S, Best, BestPlayer, T)
	if S.Phase == "Alert" then
		local Seen = S.Focus and S.Seen[S.Focus]
		if Seen and T - Seen <= P.Memory then S.SearchUntil = nil return end
		if not S.SearchUntil then
			S.SearchUntil = T + P.SearchTime
			S.LastKnown = (S.Focus and S.Spot[S.Focus]) or S.LastKnown
			Call(S, S.Focus, S.LastKnown)
		elseif T >= S.SearchUntil then
			for K in pairs(S.Aware) do S.Aware[K] = 0 end
			S.Focus, S.SearchUntil, S.LastKnown = nil, nil, nil
			S.CautiousUntil = T + P.CautiousTime
			SetPhase(S, "Cautious")
		end
		return
	end
	if Best >= 1 then
		S.Focus, S.SearchUntil = BestPlayer, nil
		S.LastKnown = S.Spot[BestPlayer] or S.LastKnown
		SetPhase(S, "Alert")
		Call(S, BestPlayer, S.LastKnown)
	elseif Best >= P.Suspicious or (S.Phase == "Suspicious" and T < S.InvestigateUntil) then
		if S.Phase ~= "Suspicious" then
			SetPhase(S, "Suspicious")
			S.InvestigateUntil = T + P.InvestigateTime
		end
		if BestPlayer and Best >= P.Suspicious and S.Spot[BestPlayer] then S.LastKnown = S.Spot[BestPlayer] end
		if T >= S.InvestigateUntil then Calm(S, T) end
	elseif S.Phase == "Suspicious" then
		Calm(S, T)
	elseif S.Phase == "Cautious" and T >= S.CautiousUntil then
		SetPhase(S, "Unaware")
	end
end

local function Update(S, Dt, PlayerList)
	local Rig = S.Rig
	local Head = Rig:FindFirstChild("Head")
	local Root = Rig:FindFirstChild("HumanoidRootPart")
	if not (Head and Root) or not Alive(Rig) or Rig:GetAttribute("Knocked") then return end
	local T = Now()
	local Cautious = T < S.CautiousUntil
	local Type = P.Types[S.Type] or P.Types.Grunt
	local Allowance = P.RaysPerNpc
	local Best, BestPlayer = 0, nil
	-- rotate which player is checked first, so the ray allowance is shared fairly
	S.Turn = (S.Turn % math.max(1, #PlayerList)) + 1
	for I = 0, #PlayerList - 1 do
		local Player = PlayerList[((S.Turn + I - 1) % #PlayerList) + 1]
		local C = Player.Character
		local CR = C and C:FindFirstChild("HumanoidRootPart")
		local A = S.Aware[Player] or 0
		local Gain = 0
		if CR and Alive(C) and not C:GetAttribute("Knocked") then
			local To = CR.Position - Head.Position
			local Dist = To.Magnitude
			local Cone = Dist <= Type.Range and P.ConeMult(Root.CFrame.LookVector, To) or 0
			if Cone > 0 then
				local Vis
				Vis, Allowance = Visible(S, Head.Position, C, Allowance)
				if Vis > 0 then
					S.Seen[Player] = T
					S.Spot[Player] = CR.Position
					local V = CR.AssemblyLinearVelocity
					Gain = P.Rate(S.Type, Dist, Cone, Vis, P.MoveMult(Vector3.new(V.X, 0, V.Z).Magnitude),
						PerceptionService.ExposureOf(C), Cautious)
				end
			end
		end
		if Gain > 0 then
			A = math.min(1, A + Gain * Dt)
		elseif S.Phase ~= "Alert" then
			A = math.max(0, A - P.Drain * Dt)
		end
		S.Aware[Player] = A
		if A > Best then Best, BestPlayer = A, Player end
	end
	Decide(S, Best, BestPlayer, T)
end

function PerceptionService.Step(Dt)
	Clock += Dt
	Budget = P.RaysPerTick
	local List, Roots = {}, {}
	for _, Player in ipairs(Players:GetPlayers()) do
		local R = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
		if R then table.insert(List, Player); table.insert(Roots, R.Position) end
	end
	if #List == 0 then return end
	for Rig, S in pairs(Npcs) do
		local R = Rig:FindFirstChild("HumanoidRootPart")
		local Near = false
		if R then
			for _, Pos in ipairs(Roots) do
				if (Pos - R.Position).Magnitude <= P.ActiveRange then Near = true break end
			end
		end
		if Near or S.Phase ~= "Unaware" then Update(S, Dt, List) end
	end
end

local Auto = true
function PerceptionService.SetAuto(On) Auto = On end

-- the character this NPC fights now: Alert, and seen within the last Memory seconds
function PerceptionService.Target(Rig)
	local S = Npcs[Rig]
	if not S or S.Phase ~= "Alert" or not S.Focus then return nil end
	local Seen = S.Seen[S.Focus]
	if not Seen or Now() - Seen > P.Memory then return nil end
	local C = S.Focus.Character
	if C and Alive(C) and not C:GetAttribute("Knocked") then return C end
	return nil
end

-- where an NPC that isn't fighting should walk: the spot it's investigating, or a widening sweep around
-- where it lost you. nil = its own routine (home, patrol).
function PerceptionService.Goal(Rig)
	local S = Npcs[Rig]
	if not S then return nil end
	if S.Phase == "Suspicious" then return S.LastKnown end
	if S.Phase == "Alert" and S.SearchUntil and S.LastKnown then
		local Elapsed = P.SearchTime - (S.SearchUntil - Now())
		local Radius = 4 + Elapsed * 0.8
		local Angle = S.Seed + Elapsed * 0.9
		return S.LastKnown + Vector3.new(math.cos(Angle) * Radius, 0, math.sin(Angle) * Radius)
	end
	return nil
end

-- gave up on its target for good (the leash): Cautious
function PerceptionService.Lose(Rig)
	local S = Npcs[Rig]
	if not S then return end
	for K in pairs(S.Aware) do S.Aware[K] = 0 end
	S.Focus, S.SearchUntil, S.LastKnown = nil, nil, nil
	S.CautiousUntil = Now() + P.CautiousTime
	SetPhase(S, "Cautious")
end

-- back to a fresh, calm state (tests; a respawned NPC)
function PerceptionService.Reset(Rig)
	local S = Npcs[Rig]
	if not S then return end
	S.Aware, S.Seen, S.Spot = {}, {}, {}
	S.Focus, S.SearchUntil, S.LastKnown = nil, nil, nil
	S.InvestigateUntil, S.CautiousUntil = 0, 0
	SetPhase(S, "Unaware")
end

-- it was hit by this player: straight to Alert on them
function PerceptionService.Alarm(Rig, Player)
	local S = Npcs[Rig]
	local CR = S and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
	if not CR then return end
	local T = Now()
	S.Aware[Player], S.Seen[Player], S.Spot[Player] = 1, T, CR.Position
	S.Focus, S.SearchUntil, S.LastKnown = Player, nil, CR.Position
	SetPhase(S, "Alert")
end

-- a sound at Position: NPCs within Radius (x1.3 when Cautious) that aren't fighting go to look. They learn
-- where, not who (spec §17.3; Plan 2 adds the sound sources and wall muffling).
function PerceptionService.Noise(Position, Radius)
	local T = Now()
	for Rig, S in pairs(Npcs) do
		local R = Rig:FindFirstChild("HumanoidRootPart")
		local Reach = Radius * ((T < S.CautiousUntil) and P.CautiousMult or 1)
		if R and S.Phase ~= "Alert" and (R.Position - Position).Magnitude <= Reach then
			S.LastKnown = Position
			S.InvestigateUntil = T + P.InvestigateTime
			SetPhase(S, "Suspicious")
		end
	end
end

-- NPCs that perceive this player right now (they saw them in the last second, or are at least Suspicious
-- of them): the witnesses of whatever the player does (WitnessService)
function PerceptionService.Perceived(Player)
	local Out = {}
	local T = Now()
	for Rig, S in pairs(Npcs) do
		if Alive(Rig) and not Rig:GetAttribute("Knocked") then
			local Seen = S.Seen[Player]
			if (Seen and T - Seen <= 1) or (S.Aware[Player] or 0) >= P.Suspicious then table.insert(Out, S) end
		end
	end
	return Out
end

function PerceptionService.Start()
	local Acc = 0
	RunService.Heartbeat:Connect(function(Dt)
		if not Auto then return end
		Acc += Dt
		if Acc < P.Tick then return end
		local Step = math.min(Acc, 1)
		Acc = 0
		local Ok, Err = pcall(PerceptionService.Step, Step)
		if not Ok then warn("PerceptionService:", Err) end
	end)
	table.insert(require(ServerScriptService.ProgressionService).HitListeners, function(Attacker, Victim)
		local Player = Players:GetPlayerFromCharacter(Attacker)
		if Player and Npcs[Victim] then PerceptionService.Alarm(Victim, Player) end
	end)
	Players.PlayerRemoving:Connect(function(Player)
		for _, S in pairs(Npcs) do
			S.Aware[Player], S.Seen[Player], S.Spot[Player] = nil, nil, nil
			if S.Focus == Player then S.Focus = nil end
		end
	end)
	local function Watch(Model)
		if not Model:IsA("Model") then return end
		PerceptionService.Register(Model, {
			Type = Model:GetAttribute("WatcherType") or "Witness", Faction = Model:GetAttribute("Faction"),
			Carrier = Model:GetAttribute("Carrier") == true, Combat = false,
		})
	end
	for _, M in ipairs(CollectionService:GetTagged("RenseiWatcher")) do Watch(M) end
	CollectionService:GetInstanceAddedSignal("RenseiWatcher"):Connect(Watch)
end

return PerceptionService

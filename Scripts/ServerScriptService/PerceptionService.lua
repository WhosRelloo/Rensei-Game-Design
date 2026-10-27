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
-- Plan 2 (S2, 2026-10-20): sight is scaled by the target's light (ExposureOf, set by LightService: x0.2 in deep
-- shadow to x1.2 in bright light) and by crouching (x0.5, the Crouching attribute CharacterHandler sets); a
-- speed buff no longer reads as sprinting. Sounds come through Hear (NoiseService): walls muffle them, and
-- Agents hear alchemy from twice as far. An enemy that gave up at its leash (Lose with its home and range)
-- stops re-noticing players who stay beyond it, so it no longer flips Alert <-> Cautious at the edge.
-- Swimming revamp (2026-10-26, PROPOSAL): sight rays ignore water (the surface used to block every ray to a diver,
-- an accidental total cloak: Play_Swim's RED measured 0 awareness under water), and a diver (the Submerged attribute
-- SwimService sets) is seen at Perception.SubmergedMult (x0.3) in place of the movement multiplier; it wins over
-- crouching.
-- Assassinations Task 4 (2026-10-27): a rig being taken down (attribute TakenDownBy) perceives nothing: it doesn't see,
-- hear or witness (Update, Hear, Perceived). Glimpse(Player, Except) is the one quick look every NPC takes at an attack
-- (no light or movement multiplier): those that see it remember where the player was, and enemies are alarmed. Raise(Rig,
-- Where) puts an NPC Alert with nobody to fight, searching around Where, and calls NPCs within CallRadius to look there
-- (Call takes no player for that). An Alert NPC with no focus -- a raised one, or one whose focus left the server --
-- now takes a player it fully notices as its focus (before, it could only search, never fight them).
-- Assassinations Task 5 (2026-10-27): bodies. AddBody(Model, {Kind = "Dead" | "Out", By = Player}) registers a body
-- (TakedownService, Tasks 7-8); it leaves the list when the model is destroyed, or by RemoveBody. At the end of each
-- Step, an enemy (never a townsperson: spec decision 8) that isn't Alert and has a body's torso within its sight range
-- and view cone casts one ray at it from the tick's budget; while the line is clear it fills toward finding it at the
-- normal sight rate, scaled by the light on the body (dark is slower) and x SubmergedMult when the body is under water
-- (pre-flight R7, as a diver). At 1 it finds it: Raise at the body, and the BodyFound listeners run. One finder per
-- body. Takedown.IsHidden bodies are never found (a stealth-missions hook; nothing is hidden yet).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local P = require(ReplicatedStorage.Modules.Data.Rensei.Perception)
local Takedown = require(ReplicatedStorage.Modules.Data.Rensei.Takedown)

local PerceptionService = {}
local Npcs = {} -- [Rig] = state
PerceptionService.Npcs = Npcs

-- the light on a character, 0..1, or nil = unknown (sight x1). LightService replaces this on Start.
PerceptionService.ExposureOf = function() return nil end

local Rays = RaycastParams.new()
Rays.FilterType = Enum.RaycastFilterType.Exclude
Rays.IgnoreWater = true -- water no longer hides a diver by blocking rays (swimming revamp, finding A11)
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
		Aware = {}, Seen = {}, Spot = {}, Pending = {}, -- [Player] = awareness / os.clock() last seen / position last seen -- Pending: seconds since that player was last checked
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

-- how many of the first N points (Pts, from Points) Rig has a clear line to from Eye: one ray each. Visible and
-- Glimpse share it, so both judge sight the same way (the same Rays params and filter).
local function ClearLines(Rig, Eye, Character, Pts, N)
	Rays.FilterDescendantsInstances = {Rig, Character}
	local Clear = 0
	for I = 1, N do
		if not workspace:Raycast(Eye, Pts[I] - Eye, Rays) then Clear += 1 end
	end
	return Clear
end

-- the fraction (0, 1/3, 2/3, 1) of those points the NPC has a clear line to, within its own ray budget
local function Visible(S, Eye, Character, Allowance)
	local Pts = Points(Character)
	if not Pts then return 0, Allowance end
	if Budget <= 0 or Allowance <= 0 then return nil, Allowance end -- no rays left: not checked this tick
	local N = math.min(#Pts, Budget, Allowance)
	Budget -= N
	Allowance -= N
	return ClearLines(S.Rig, Eye, Character, Pts, N) / 3, Allowance
end

-- an Alert NPC brings in the others close by: they come to look at Where. Player: who it saw (they grow suspicious of
-- them); nil for a spot with nobody seen (Raise), where they learn where, not who.
local function Call(S, Player, Where)
	local Root = S.Rig:FindFirstChild("HumanoidRootPart")
	if not Root or not Where then return end
	for Rig, O in pairs(Npcs) do
		local R = O ~= S and Rig:FindFirstChild("HumanoidRootPart")
		-- enemies call enemies, watchers call watchers (spec §17.1: guards are called in, not bandits)
		if R and O.Combat == S.Combat and (R.Position - Root.Position).Magnitude <= P.CallRadius and O.Phase ~= "Alert" then
			if Player then O.Aware[Player] = math.max(O.Aware[Player] or 0, P.Suspicious) end
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
		-- Alert with nobody in focus (raised at a spot, or the focus left the server): a player it fully notices becomes the focus
		if not S.Focus and Best >= 1 then
			S.Focus, S.SearchUntil = BestPlayer, nil
			S.LastKnown = S.Spot[BestPlayer] or S.LastKnown
			Call(S, BestPlayer, S.LastKnown)
			return
		end
		local Seen = S.Focus and S.Seen[S.Focus]
		if Seen and T - Seen <= P.Memory then S.SearchUntil = nil return end
		if not S.SearchUntil then
			S.SearchUntil = T + P.SearchTime
			S.LastKnown = (S.Focus and S.Spot[S.Focus]) or S.LastKnown
			if S.Focus then Call(S, S.Focus, S.LastKnown) end -- (the focus may have left mid-fight: nobody to call about)
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
	if not (Head and Root) or not Alive(Rig) or Rig:GetAttribute("Knocked") or Rig:GetAttribute("TakenDownBy") then return end -- (being taken down: perceives nothing)
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
		local Checked = true
		S.Pending[Player] = (S.Pending[Player] or 0) + Dt
		-- an enemy that gave up at its leash doesn't keep noticing someone who stays out there
		local Beyond = S.Leash and CR and Vector3.new(CR.Position.X - S.Leash.Home.X, 0, CR.Position.Z - S.Leash.Home.Z).Magnitude > S.Leash.Range
		if CR and not Beyond and Alive(C) and not C:GetAttribute("Knocked") then
			local To = CR.Position - Head.Position
			local Dist = To.Magnitude
			local Cone = Dist <= Type.Range and P.ConeMult(Root.CFrame.LookVector, To) or 0
			if Cone > 0 then
				local Vis
				Vis, Allowance = Visible(S, Head.Position, C, Allowance)
				if Vis == nil then
					Checked = false -- no rays left for this player this tick: hold, catch up next time
				elseif Vis > 0 then
					S.Seen[Player] = T
					S.Spot[Player] = CR.Position
					local V = CR.AssemblyLinearVelocity
					local Move = C:GetAttribute("Submerged") and P.SubmergedMult
						or C:GetAttribute("Crouching") and P.CrouchMult
						or P.MoveMult(Vector3.new(V.X, 0, V.Z).Magnitude, C:GetAttribute("SpeedMultiplier"))
					local Exposure = PerceptionService.ExposureOf(C)
					Gain = P.Rate(S.Type, Dist, Cone, Vis, Move, Exposure and P.ExposureMult(Exposure) or 1, Cautious)
				end
			end
		end
		if Checked then
			local Elapsed = S.Pending[Player]
			S.Pending[Player] = 0
			if Gain > 0 then
				A = math.min(1, A + Gain * Elapsed)
			elseif S.Phase ~= "Alert" then
				A = math.max(0, A - P.Drain * Elapsed)
			end
		end
		if not S.Combat then A = math.min(A, 0.99) end -- watchers notice and stare (Suspicious) but sight alone never alarms them; being hit does (Alarm)
		S.Aware[Player] = A
		if A > Best then Best, BestPlayer = A, Player end
	end
	Decide(S, Best, BestPlayer, T)
end

-- ===== bodies (assassinations Task 5) =====
local Bodies = {} -- [Model] = Info: {Kind, By, Found, Fill = {[Rig] = 0..1}}
PerceptionService.Bodies = Bodies
PerceptionService.BodyFound = {} -- listeners (Body, Finder, Info), each run in a pcall

-- Info = {Kind = "Dead" | "Out", By = Player}. Registering a model again starts its finding over.
function PerceptionService.AddBody(Model, Info)
	local Again = Bodies[Model] ~= nil
	Info.Found, Info.Fill = false, {}
	Bodies[Model] = Info
	if not Again then Model.Destroying:Once(function() Bodies[Model] = nil end) end
	return Info
end

function PerceptionService.RemoveBody(Model) Bodies[Model] = nil end

local Swim = nil -- SwimService, required on first use (it loads after this service)
local function Underwater(Model)
	if not Swim then
		local M = ServerScriptService:FindFirstChild("SwimService")
		local Ok, S = pcall(function() return M and require(M) end)
		if not (Ok and S) then return false end
		Swim = S
	end
	local Ok, Yes = pcall(Swim.HeadUnderwater, Model)
	return Ok and Yes == true
end

local function Found(Body, Rig, Info, Where)
	Info.Found = true
	PerceptionService.Raise(Rig, Where)
	for _, Listener in ipairs(PerceptionService.BodyFound) do
		local Ok, Err = pcall(Listener, Body, Rig, Info)
		if not Ok then warn("PerceptionService BodyFound:", Err) end
	end
end

-- after the NPC updates, with the rays left in the tick's budget: one per enemy that has a body in view
local function FindBodies(Dt)
	for Body, Info in pairs(Bodies) do
		local Torso = Body:FindFirstChild("Torso") or Body:FindFirstChild("UpperTorso") or Body:FindFirstChild("HumanoidRootPart")
		if not Info.Found and Torso and not Takedown.IsHidden(Body) then
			local Light, Water -- worked out once per body per tick, when an NPC first has a clear line to it
			for Rig, S in pairs(Npcs) do
				local Head, Root = Rig:FindFirstChild("Head"), Rig:FindFirstChild("HumanoidRootPart")
				if S.Combat and S.Phase ~= "Alert" and Head and Root and Alive(Rig) and not Rig:GetAttribute("Knocked")
					and not Rig:GetAttribute("TakenDownBy") then
					local To = Torso.Position - Head.Position
					local Dist = To.Magnitude
					local Cone = Dist <= (P.Types[S.Type] or P.Types.Grunt).Range and P.ConeMult(Root.CFrame.LookVector, To) or 0
					if Cone > 0 then
						if Budget <= 0 then return end -- no rays left: the rest look next tick
						Budget -= 1
						Rays.FilterDescendantsInstances = {Rig, Body}
						if not workspace:Raycast(Head.Position, To, Rays) then
							if not Light then
								Light = P.ExposureMult(PerceptionService.ExposureOf(Body) or 1)
								Water = Underwater(Body) and P.SubmergedMult or 1 -- (in Rate's movement slot, as for a diver)
							end
							local Fill = (Info.Fill[Rig] or 0) + P.Rate(S.Type, Dist, Cone, 1, Water, Light, Now() < S.CautiousUntil) * Dt
							Info.Fill[Rig] = Fill
							if Fill >= 1 then
								Found(Body, Rig, Info, Torso.Position)
								break -- one finder per body
							end
						end
					end
				end
			end
		end
	end
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
	FindBodies(Dt)
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

-- gave up on its target for good (the leash): Cautious. Home / Range (optional): its leash; from now on it
-- ignores the sight of players beyond it (a hit still alarms it).
function PerceptionService.Lose(Rig, Home, Range)
	local S = Npcs[Rig]
	if not S then return end
	if typeof(Home) == "Vector3" and type(Range) == "number" then S.Leash = {Home = Home, Range = Range} end
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
	S.Pending = {}
	S.Focus, S.SearchUntil, S.LastKnown, S.Leash = nil, nil, nil, nil
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
local function Investigate(S, Position, T)
	S.LastKnown = Position
	S.InvestigateUntil = T + P.InvestigateTime
	SetPhase(S, "Suspicious")
end

function PerceptionService.Noise(Position, Radius)
	local T = Now()
	for Rig, S in pairs(Npcs) do
		local R = Rig:FindFirstChild("HumanoidRootPart")
		local Reach = Radius * ((T < S.CautiousUntil) and P.CautiousMult or 1)
		if R and S.Phase ~= "Alert" and (R.Position - Position).Magnitude <= Reach then Investigate(S, Position, T) end
	end
end

local WallRays = RaycastParams.new()
WallRays.FilterType = Enum.RaycastFilterType.Exclude
WallRays.RespectCanCollide = true

-- walls (solid parts) between a sound and an ear, up to P.MaxWalls, one ray per wall
local function Walls(From, To, Ignore)
	local Skip = table.clone(Ignore)
	local N = 0
	while N < P.MaxWalls do
		WallRays.FilterDescendantsInstances = Skip
		local Hit = workspace:Raycast(From, To - From, WallRays)
		if not Hit then break end
		N += 1
		table.insert(Skip, Hit.Instance)
	end
	return N
end
PerceptionService.Walls = Walls

-- a sound (NoiseService) of Radius at Position: NPCs that hear it through the walls between (each takes
-- P.WallCut off the radius), x1.3 while Cautious and x2 for Agents hearing alchemy, go to look at the spot.
-- Source (optional): the character that made it (never blocks its own sound). Returns how many heard it.
function PerceptionService.Hear(Position, Radius, Kind, Source)
	local T = Now()
	local Heard = 0
	for Rig, S in pairs(Npcs) do
		local Head = Rig:FindFirstChild("Head")
		if Head and S.Phase ~= "Alert" and Rig ~= Source and Alive(Rig) and not Rig:GetAttribute("Knocked") and not Rig:GetAttribute("TakenDownBy") then
			local Reach = Radius * ((T < S.CautiousUntil) and P.CautiousMult or 1)
				* ((S.Type == "Agent" and P.LoudAlchemy[Kind or ""]) and P.AgentHearing or 1)
			local Dist = (Head.Position - Position).Magnitude
			if Dist <= Reach then
				local N = Walls(Position, Head.Position, {Rig, Source})
				if Dist <= P.Muffled(Reach, N) then
					Investigate(S, Position, T)
					Heard += 1
				end
			end
		end
	end
	return Heard
end

-- NPCs that saw this player within the last Memory seconds: the witnesses of whatever the player does
-- (WitnessService). Only what an NPC actually perceived witnesses (spec §4): awareness alone isn't sight.
function PerceptionService.Perceived(Player)
	local Out = {}
	local T = Now()
	for Rig, S in pairs(Npcs) do
		if Alive(Rig) and not Rig:GetAttribute("Knocked") and not Rig:GetAttribute("TakenDownBy") then
			local Seen = S.Seen[Player]
			if Seen and T - Seen <= P.Memory then table.insert(Out, S) end
		end
	end
	return Out
end

-- one quick look at Player by every NPC but Except (the victim), at an attack (spec §6): an NPC that isn't dead,
-- knocked or being taken down sees it when the player's root is within its type's range, inside its view cone, and it
-- has a clear line to the player's head, torso or feet -- three rays of its own (never the tick's budget), no light
-- or movement multiplier. Each that sees remembers when and where; an enemy is alarmed on the player. Returns their rigs.
function PerceptionService.Glimpse(Player, Except)
	local Out = {}
	local C = Player and Player.Character
	local CR = C and C:FindFirstChild("HumanoidRootPart")
	local Pts = C and Points(C)
	if not (CR and Pts) then return Out end
	local T = Now()
	for Rig, S in pairs(Npcs) do
		local Head = Rig:FindFirstChild("Head")
		local Root = Rig:FindFirstChild("HumanoidRootPart")
		if Rig ~= Except and Head and Root and Alive(Rig) and not Rig:GetAttribute("Knocked") and not Rig:GetAttribute("TakenDownBy") then
			local To = CR.Position - Head.Position
			local Type = P.Types[S.Type] or P.Types.Grunt
			if To.Magnitude <= Type.Range and P.ConeMult(Root.CFrame.LookVector, To) > 0
				and ClearLines(Rig, Head.Position, C, Pts, #Pts) > 0 then
				S.Seen[Player], S.Spot[Player] = T, CR.Position
				if S.Combat then PerceptionService.Alarm(Rig, Player) end
				table.insert(Out, Rig)
			end
		end
	end
	return Out
end

-- an Alert search at Where with nobody to fight (a body found, an NPC waking from a knockout): it sweeps around the
-- spot for SearchTime, then turns Cautious as after any failed search; NPCs of its kind within CallRadius come to look.
-- An NPC already Alert on someone keeps that fight and isn't raised (Task 4 review: otherwise its next tick takes the
-- player back as its focus and Where is lost anyway).
function PerceptionService.Raise(Rig, Where)
	local S = Npcs[Rig]
	if not S or typeof(Where) ~= "Vector3" then return end
	if S.Phase == "Alert" and S.Focus then return end
	S.Focus, S.LastKnown, S.SearchUntil = nil, Where, Now() + P.SearchTime
	SetPhase(S, "Alert")
	Call(S, nil, Where)
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
			S.Pending[Player] = nil
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

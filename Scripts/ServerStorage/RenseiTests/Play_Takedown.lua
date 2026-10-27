-- Play_Takedown (assassinations Task 4, 2026-10-27): takedowns inside the game VM (LMRunSuite). Every case runs in
-- TakedownKit.Guard on the kit's own floor high above the map, with rigs it spawned itself (never a world enemy, a
-- townsperson's real rig or the player), perception stepped by hand. Tasks 5-9 add their cases here.
-- Task 4: perception about takedowns -- a rig being taken down perceives nothing (Update, Hear, Perceived: pre-flight
-- R14); Glimpse, the one quick look every NPC takes at an attack; Raise, an Alert search at a spot with nobody to fight.
-- Task 5: bodies -- an enemy finds a registered body by sight (one ray, the tick's budget; light counts; under water
-- x0.3, pre-flight R7) and searches there, once per body; a takedown's corpse stays (Takedown.BodySeconds, not 4 s).
-- Task 6: DownedManager -- Knock takes an optional length; V carries a takedown's dead body (pre-flight R6, spec §18.1),
-- B never grips one, and a body removed mid-carry is dropped cleanly; Lock / Attach / Detach are shared (R16 / D3).
-- Task 6b (owner 2026-10-27): a body a finished Grip killed ragdolls (Modules.Managers.Ragdoll), lies on the floor,
-- settles (anchored), is still found by a patrol, and is carried and set down limp. Every case goes through the real
-- Grip path: DownedManager.Knock(Body), then DownedManager.Grip(Gripper, Body) with a second kit Grunt as the gripper
-- (never the player: a player gripper records deeds, and the player is never the victim).
-- Task 6 review: Knock's Seconds beats the KnockedTime attribute; V refuses a body another holder has welded.
-- Task 7: the server takedown (TakedownService, Requests.Takedown): the gates and their reasons (PvE first: a player is
-- never a target), the assassination from behind (the kill credited once, the deed, a Takedown sound of 4 and no Hit, a
-- ragdolled body that stays, is found and can be carried), witnesses, the cooldown, one takedown per target, the
-- interrupt (a Stun, a knock: the crawl kept), the victim protected; a guard's deed and Heat (pre-flight R8 / R9);
-- a carried corpse is no prisoner (CheckDeliveries); Glimpse sees past the victim; Call skips the dead; a body outside
-- the world is never found. Owner 2026-10-27: a gripped body stays 120 s and is a body (a clue) like a takedown's.
-- Task 8: the knockout (a 300 s knock, a Choke sound of 6, no deed, an "Out" body that is found and can be carried, the
-- interrupt), waking up (DownedManager.Recover, the timer's own path) raises the alarm where it woke; and (carried from
-- Task 7) a law-faction body the player gripped raises the law's Heat once when found, a bandit's raises none.
-- Task 8 fix round: the Task 7 / 8 review cases moved to Play_TakedownHard, and the helpers both suites use to TakedownKit
-- (unchanged).
-- Task 9: an Elite's backstab (a Chunk target: 45% of its max health through the normal hit path, a Hit sound, Alert,
-- a stun, Failed "survived"), no knockout of an Elite, a trial boss immune, TakedownClass overriding the type, a real
-- townsperson refused (read-only), the Done hook; and (spec §18.2, pre-flight R10 / R11) a townsperson who sees a
-- takedown flees and reports it (the deed's witnesses, a rumour).
local SSS = game.ServerScriptService
local DM = require(game.ReplicatedStorage.Modules.Managers.DownedManager)
local PS = require(SSS.PerceptionService)
local LS = require(SSS.LightService)
local WorldClock = require(SSS.WorldClock) -- the clock moves, so the light cases hold it (as Play_Stealth does)
local Kit = require(script.Parent.TakedownKit)
local SmokeKit = require(script.Parent.SmokeKit) -- (Task 6b) RemoveEnemy: the gripper goes once its grip is done
local Modules = game.ReplicatedStorage.Modules
local WCS = require(Modules.Framework.WCS) -- (Task 7) a Stun on the player mid-takedown
local Stun = require(Modules.Skills.States.Stun)
local NS = require(SSS.NoiseService)
local Progression = require(SSS.ProgressionService)
local HS = require(SSS.HeatService)
local Player = Kit.Player()
local C = Player.Character

-- (Task 8 fix round) the helpers Play_TakedownHard shares live in TakedownKit, moved there unchanged
local At, AWAY, NEAR, AtHour, AddBody, DeadBody = Kit.At, Kit.AWAY, Kit.NEAR, Kit.AtHour, Kit.AddBody, Kit.DeadBody
local CarryWeld, Free, WaitFor, Service, Result, Calm = Kit.CarryWeld, Kit.Free, Kit.WaitFor, Kit.Service, Kit.Result, Kit.Calm
local Assassinate, KnockOut, Finished, Behind, Deed, LAW = Kit.Assassinate, Kit.KnockOut, Kit.Finished, Kit.Behind, Kit.Deed, Kit.LAW
local GrippedBodyHeat = Kit.GrippedBodyHeat

local function Has(List, Rig)
	for _, X in ipairs(List) do
		if X == Rig or (type(X) == "table" and X.Rig == Rig) then return true end
	end
	return false
end

-- Glimpse with the function checked first, so a missing one fails as such
local function Glimpse(Except)
	assert(type(PS.Glimpse) == "function", "PerceptionService.Glimpse exists")
	return PS.Glimpse(Player, Except)
end
local function Raise(Rig, Where)
	assert(type(PS.Raise) == "function", "PerceptionService.Raise exists")
	PS.Raise(Rig, Where)
end

-- ===== Task 5: bodies =====

local function TorsoOf(Body) return Body:FindFirstChild("Torso") or Body:FindFirstChild("UpperTorso") or Body.HumanoidRootPart end

-- Body(Got) with a BodyFound listener that collects {Body, Finder, Info}; the listener comes out afterwards
local function Listen(Body)
	assert(type(PS.BodyFound) == "table", "PerceptionService.BodyFound exists")
	local Got = {}
	local function L(B, Finder, Info) table.insert(Got, {Body = B, Finder = Finder, Info = Info}) end
	table.insert(PS.BodyFound, L)
	local Ok, Err = pcall(Body, Got)
	local I = table.find(PS.BodyFound, L)
	if I then table.remove(PS.BodyFound, I) end
	if not Ok then error(Err, 0) end
end

-- perception stepped 0.2 s at a time until the body is found: the seconds it took, or nil within Max
local function TimeToFind(Info, Max)
	local Took = 0
	while not Info.Found and Took < Max - 1e-6 do
		Kit.Run(0.2)
		Took += 0.2
	end
	return Info.Found and Took or nil
end

-- terrain water over the kit spot: 16 x 8 x 16 on the 4-stud grid (the survey X / Z are multiples of 4), from the
-- floor's top up; On = false clears it
local function Water(On)
	workspace.Terrain:FillBlock(CFrame.new(Kit.Spot() + Vector3.new(0, 4, 0)), Vector3.new(16, 8, 16),
		On and Enum.Material.Water or Enum.Material.Air)
end

-- ===== Task 6: carrying =====
local function Flat(V) return Vector3.new(V.X, 0, V.Z).Magnitude end

-- ===== Task 6b: a gripped body ragdolls =====
local SETTLE = 4 -- Ragdoll.Settle (PROPOSAL), written here by hand, never read from the module
-- the R6 joints a ragdoll replaces (StarterCharacter, read in Ye's Edit 2026-10-27); the RootJoint is kept
local LIMB_JOINTS = {"Neck", "Right Shoulder", "Left Shoulder", "Right Hip", "Left Hip"}
-- the torso's height above the kit floor's top
local function Height(Body) return TorsoOf(Body).Position.Y - Kit.Spot().Y end
-- the body's own parts (the BaseParts directly in the rig)
local function BodyParts(Body)
	local Out = {}
	for _, P in ipairs(Body:GetChildren()) do if P:IsA("BasePart") then table.insert(Out, P) end end
	return Out
end
-- the name of a body part that is anchored, or nil
local function AnchoredPart(Body)
	for _, P in ipairs(BodyParts(Body)) do if P.Anchored then return P.Name end end
	return nil
end
-- a BallSocketConstraint joining the joint's two parts
local function SocketFor(Body, J)
	for _, B in ipairs(Body:GetDescendants()) do
		if B:IsA("BallSocketConstraint") and B.Attachment0 and B.Attachment1 and B.Attachment0.Parent == J.Part0
			and B.Attachment1.Parent == J.Part1 then
			return B
		end
	end
	return nil
end
-- a kit Grunt at (X, Z), knocked, then finished by a second kit Grunt's grip from 4 studs in front (the real Grip
-- path), which is removed once its grip is done (so it never looks at the body). TakenDown: TakenDownBy set first, so
-- the body stays (Takedown.BodySeconds) and V can carry it. Returns the body.
local function Gripped(X, Z, TakenDown)
	local Body = Kit.Spawn("Grunt", At(X, Z))
	if TakenDown then Body:SetAttribute("TakenDownBy", Player.Name) end
	local Gripper = Kit.Spawn("Grunt", At(X, Z + 4))
	DM.Knock(Body)
	assert(DM.IsKnocked(Body), "setup: the body is knocked")
	local Done = DM.Grip(Gripper, Body)
	SmokeKit.RemoveEnemy(Gripper)
	assert(Done == true, "setup: the grip finished")
	assert(Body.Humanoid.Health <= 0, "setup: the grip killed it")
	return Body
end

-- ===== Task 7: the server takedown =====
local function RequestModule()
	local H = SSS:FindFirstChild("ServerHandler")
	local Requests = H and H:FindFirstChild("Requests")
	local M = Requests and Requests:FindFirstChild("Takedown")
	assert(M, "Requests.Takedown exists")
	return require(M)
end
-- a refusal: the reason in LastTakedownResult, and nothing marked
local function Refused(T, Rig, Want, What)
	local Ok, Why = Assassinate(Rig)
	T.Eq(Ok, false, What .. ": refused")
	T.Eq(Why, Want, What .. ": the reason")
	T.Eq(Result(), "Assassinate:" .. Want, What .. ": LastTakedownResult")
	T.Eq(Rig:GetAttribute("TakenDownBy"), nil, What .. ": the target isn't marked")
	T.Eq(C:GetAttribute("TakingDown"), nil, What .. ": the player isn't marked")
end
local function Count(Id)
	local M = Progression.GetData(Player).Morality
	local E = M and M.Deeds[Id]
	return E and E.Count or 0
end
local function Mercy() return Progression.GetData(Player).Morality.Conduct.Mercy or 0 end

-- ===== Task 8: the knockout =====
-- every deed in the save with its count and times seen, as one string (a deed recorded changes it)
local function DeedsKey()
	local M = Progression.GetData(Player).Morality
	local Out = {}
	for Id, E in pairs((M and M.Deeds) or {}) do table.insert(Out, Id .. "=" .. tostring(E.Count) .. "/" .. tostring(E.Seen)) end
	table.sort(Out)
	return table.concat(Out, ",")
end
-- ===== Task 9: Elites, bosses, townsfolk, the hooks =====
local CollectionService = game:GetService("CollectionService")
-- Body(Got) with a Done and a Failed listener of the case's own (Got.Done: {Kind, P, R}; Got.Failed: {P, R, Reason});
-- both come out afterwards
local function Hooks(Body)
	local S = Service()
	local Got = {Done = {}, Failed = {}}
	local function D(Kind, P, R) table.insert(Got.Done, {Kind = Kind, P = P, R = R}) end
	local function F(P, R, Reason) table.insert(Got.Failed, {P = P, R = R, Reason = Reason}) end
	table.insert(S.Done, D)
	table.insert(S.Failed, F)
	local Ok, Err = pcall(Body, Got)
	local I = table.find(S.Done, D)
	if I then table.remove(S.Done, I) end
	I = table.find(S.Failed, F)
	if I then table.remove(S.Failed, I) end
	if not Ok then error(Err, 0) end
end
-- a WCS Stun is running on the rig
local function HasStun(Rig)
	local WC = WCS.Character.GetCharacterFromInstance(Rig)
	return WC ~= nil and #WC:GetAllActiveStatusEffectsOfType(Stun) > 0
end
-- the real townsperson nearest the player that stands still at its post (AtPost, or Asleep: held there with no player
-- near), or nil. Read only.
local function NearestTownsperson()
	local Best, BestD = nil, math.huge
	for _, Rig in ipairs(CollectionService:GetTagged("RenseiTownsfolk")) do
		local R = Rig:FindFirstChild("HumanoidRootPart")
		local H = Rig:FindFirstChildOfClass("Humanoid")
		if R and H and H.Health > 0 and Rig:GetAttribute("TownsfolkId") ~= nil and (Rig:GetAttribute("TownsfolkState") == "AtPost"
			or Rig:GetAttribute("TownsfolkState") == "Asleep") and Rig:IsDescendantOf(workspace) then
			local D = (R.Position - C.HumanoidRootPart.Position).Magnitude
			if D < BestD then Best, BestD = Rig, D end
		end
	end
	return Best
end
-- a CFrame on the kit floor at (X, Z) facing Dir (level)
local function Facing(X, Z, Dir)
	local Pos = At(X, Z).Position
	return CFrame.lookAt(Pos, Pos + Vector3.new(Dir.X, 0, Dir.Z))
end

return {
	SkipWhileTakenDown = function(T)
		Kit.Guard(function()
			local Rig = Kit.Spawn("Grunt", At(0, 0))
			Kit.PutInFront(Rig, 8)
			C:SetAttribute("Exposure", 1)
			Rig:SetAttribute("TakenDownBy", Player.Name)
			Kit.Run(2)
			T.Eq(PS.Awareness(Rig, Player), 0, "taken down: notices nothing at 8 studs in the open")
			T.Eq(PS.PhaseOf(Rig), "Unaware", "taken down: still Unaware")
			Rig:SetAttribute("TakenDownBy", nil)
			Kit.Run(2)
			T.True(PS.Awareness(Rig, Player) > 0, "control: free again, it notices the player")
		end)
	end,
	-- (pre-flight R14) the victim neither hears its own choke nor witnesses its own takedown
	TakenDownHearsNothing = function(T)
		Kit.Guard(function()
			local Rig = Kit.Spawn("Grunt", At(0, 0))
			local Sound = Rig.Head.Position + Vector3.new(6, 0, 0)
			Rig:SetAttribute("TakenDownBy", Player.Name)
			T.Eq(PS.Hear(Sound, 12, nil), 0, "taken down: hears nothing at 6 of 12")
			T.Eq(PS.PhaseOf(Rig), "Unaware", "taken down: not sent to look")
			Rig:SetAttribute("TakenDownBy", nil)
			T.True(PS.Hear(Sound, 12, nil) >= 1 and PS.PhaseOf(Rig) == "Suspicious", "control: free, it hears it")
		end)
	end,
	TakenDownWitnessesNothing = function(T)
		Kit.Guard(function()
			local Rig = Kit.Spawn("Grunt", At(0, 0))
			PS.Alarm(Rig, Player) -- it has just seen the player
			Rig:SetAttribute("TakenDownBy", Player.Name)
			T.True(not Has(PS.Perceived(Player), Rig), "taken down: not a witness")
			Rig:SetAttribute("TakenDownBy", nil)
			T.True(Has(PS.Perceived(Player), Rig), "control: free, it is a witness")
		end)
	end,
	GlimpseFront = function(T)
		Kit.Guard(function()
			local Rig = Kit.Spawn("Grunt", At(0, 0))
			Kit.PutInFront(Rig, 8)
			local Seen = Glimpse(nil)
			T.True(Has(Seen, Rig), "facing the player at 8: it sees the attack")
			T.Eq(PS.PhaseOf(Rig), "Alert", "a combat NPC that sees it is alarmed")
			T.Eq(PS.Target(Rig), C, "and fights the player")
		end)
	end,
	GlimpseBehind = function(T)
		Kit.Guard(function()
			local Rig = Kit.Spawn("Grunt", At(0, 0))
			Kit.PutInFront(Rig, 8)
			Kit.Face(Rig, Vector3.new(0, 0, 1)) -- turned away from the player
			local Seen = Glimpse(nil)
			T.True(not Has(Seen, Rig), "turned away: it doesn't see")
			T.Eq(PS.PhaseOf(Rig), "Unaware", "still Unaware")
		end)
	end,
	GlimpseWall = function(T)
		Kit.Guard(function()
			local Rig = Kit.Spawn("Grunt", At(0, 0))
			Kit.PutInFront(Rig, 8)
			-- a 1 x 12 x 12 wall halfway, standing on the floor, its 1-stud side along the line between them
			local Mid = Kit.Spot() + Vector3.new(0, 6, -4)
			Kit.Wall(CFrame.lookAt(Mid, Mid + Vector3.new(0, 0, -1)) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(1, 12, 12))
			local Seen = Glimpse(nil)
			T.True(not Has(Seen, Rig), "a wall between: it doesn't see")
			T.Eq(PS.PhaseOf(Rig), "Unaware", "still Unaware")
		end)
	end,
	GlimpseExcept = function(T)
		Kit.Guard(function()
			local Rig = Kit.Spawn("Grunt", At(0, 0))
			Kit.PutInFront(Rig, 8)
			local Seen = Glimpse(Rig)
			T.True(not Has(Seen, Rig), "the excepted rig (the victim) takes no look")
			T.Eq(PS.PhaseOf(Rig), "Unaware", "still Unaware")
		end)
	end,
	RaiseSearches = function(T)
		Kit.Guard(function()
			local Rig = Kit.Spawn("Grunt", At(0, 0))
			local Near = Kit.Spawn("Grunt", At(0, 30)) -- inside the 40-stud call
			local Far = Kit.Spawn("Grunt", At(0, 60)) -- outside it
			local Where = Kit.Spot() + Vector3.new(10, 0, 0)
			Raise(Rig, Where)
			T.Eq(PS.PhaseOf(Rig), "Alert", "raised: Alert")
			T.Eq(PS.Target(Rig), nil, "nobody to fight")
			local Goal = PS.Goal(Rig)
			T.True(Goal ~= nil and (Goal - Where).Magnitude <= 20, "searches around the spot: " .. tostring(Goal))
			T.Eq(PS.PhaseOf(Near), "Suspicious", "a Grunt 30 studs off is called in")
			local NearGoal = PS.Goal(Near)
			T.True(NearGoal ~= nil and (NearGoal - Where).Magnitude < 0.01, "and comes to look at the spot: " .. tostring(NearGoal))
			T.Eq(PS.PhaseOf(Far), "Unaware", "a Grunt 60 studs off is not")
		end)
	end,
	RaiseThenSees = function(T)
		Kit.Guard(function()
			local Rig = Kit.Spawn("Grunt", At(0, 0))
			Raise(Rig, Kit.Spot() + Vector3.new(10, 0, 0))
			Kit.PutInFront(Rig, 6)
			C:SetAttribute("Exposure", 1)
			Kit.Run(3)
			T.Eq(PS.Target(Rig), C, "a raised NPC fights the player it then sees")
		end)
	end,
	-- (Task 4 review) Raise doesn't take an NPC off a fight it is in
	RaiseKeepsAFight = function(T)
		Kit.Guard(function()
			local Rig = Kit.Spawn("Grunt", At(0, 0))
			Kit.PutInFront(Rig, 8)
			PS.Alarm(Rig, Player) -- Alert on the player
			Raise(Rig, Kit.Spot() + Vector3.new(0, 0, 30))
			T.Eq(PS.Target(Rig), C, "still fights the player after a Raise elsewhere")
		end)
	end,

	-- ===== Task 5: bodies =====
	BodyFoundInView = function(T)
		Kit.Guard(function() AtHour(12, function() Listen(function(Got)
			local Body, Info = DeadBody(0, 0)
			local Rig = Kit.Spawn("Grunt", At(0, 10)) -- 10 studs off, facing it (-Z), in the open at noon
			Kit.PutPlayer(AWAY)
			Kit.Run(4)
			T.Eq(PS.PhaseOf(Rig), "Alert", "it found the body: Alert")
			local Goal = PS.Goal(Rig)
			local Torso = TorsoOf(Body)
			T.True(Goal ~= nil and (Goal - Torso.Position).Magnitude <= 20, "searching around the body: " .. tostring(Goal))
			T.True(Info ~= nil and Info.Found == true, "the body is marked found")
			T.Eq(#Got, 1, "BodyFound fired once")
			T.True(Got[1] ~= nil and Got[1].Body == Body and Got[1].Finder == Rig, "for that body, found by that Grunt")
		end) end) end)
	end,
	BodyNotBehind = function(T)
		Kit.Guard(function() AtHour(12, function() Listen(function(Got)
			local _, Info = DeadBody(0, 0)
			local Rig = Kit.Spawn("Grunt", At(0, 10))
			Kit.Face(Rig, Vector3.new(0, 0, 1)) -- its back to the body
			Kit.PutPlayer(AWAY)
			Kit.Run(4)
			T.Eq(PS.PhaseOf(Rig), "Unaware", "its back to the body: still Unaware")
			T.True(Info ~= nil and not Info.Found, "not found")
			T.Eq(#Got, 0, "BodyFound didn't fire")
		end) end) end)
	end,
	BodyDarkIsSlower = function(T)
		-- the spot must be dark at night: no lamp (LightService's) and no light of any part within 60 studs
		local Spot, Lamps = Kit.Spot(), 0
		for Part in pairs(LS.Lamps) do
			if Part.Parent and (Part.Position - Spot).Magnitude <= 60 then Lamps += 1 end
		end
		for _, Part in ipairs(workspace:GetPartBoundsInRadius(Spot, 60)) do
			if Part:FindFirstChildWhichIsA("Light") then Lamps += 1 end
		end
		T.Eq(Lamps, 0, "no lamp within 60 studs of the spot")
		if Lamps > 0 then return end
		Kit.Guard(function() AtHour(12, function()
			local Body, Info = DeadBody(0, 0)
			local Rig = Kit.Spawn("Grunt", At(0, 10))
			Kit.PutPlayer(AWAY)
			local T1 = TimeToFind(Info, 4)
			T.True(T1 ~= nil, "noon: found within 4 s (" .. tostring(T1) .. ")")
			if not T1 then return end
			-- the same body and Grunt, the same distance, at midnight
			PS.RemoveBody(Body)
			PS.Reset(Rig)
			WorldClock.Hold(0)
			local Night = AddBody(Body, {Kind = "Dead", By = Player})
			T.Eq(TimeToFind(Night, 3 * T1), nil, ("midnight: not found within 3 x %.1f s"):format(T1))
			T.True((Night.Fill[Rig] or 0) > 0, "but it is seen, only more slowly: " .. tostring(Night.Fill[Rig]))
			T.Eq(PS.PhaseOf(Rig), "Unaware", "and the Grunt isn't searching")
		end) end)
	end,
	-- (pre-flight R7) a body under water is seen at x0.3, as a diver is (Perception.SubmergedMult)
	BodyUnderWaterIsSlower = function(T)
		Kit.Guard(function() AtHour(12, function()
			local Body, Info = DeadBody(0, 0)
			local Rig = Kit.Spawn("Grunt", At(0, 12)) -- outside the water (it reaches 8 studs from the spot)
			Kit.PutPlayer(AWAY)
			Kit.Run(1)
			local Dry = Info.Fill[Rig] or 0
			T.True(Dry > 0 and not Info.Found, "dry: filling, not found yet in 1 s: " .. tostring(Dry))
			PS.RemoveBody(Body)
			PS.Reset(Rig)
			Water(true)
			local Ok, Err = pcall(function()
				local Swim = require(SSS.SwimService)
				T.True(Swim.HeadUnderwater(Body), "setup: the body is under the water")
				local Wet = AddBody(Body, {Kind = "Dead", By = Player})
				Kit.Run(1)
				T.Near((Wet.Fill[Rig] or 0) / math.max(Dry, 1e-6), 0.3, 0.05, "under water: x0.3 of the dry fill")
			end)
			Water(false)
			if not Ok then error(Err, 0) end
		end) end)
	end,
	FoundOnce = function(T)
		Kit.Guard(function() AtHour(12, function() Listen(function(Got)
			local Body, Info = DeadBody(0, 0)
			local First = Kit.Spawn("Grunt", At(0, 10))
			Kit.PutPlayer(AWAY)
			Kit.Run(4)
			T.True(Info ~= nil and Info.Found == true, "the first Grunt found it")
			local Second = Kit.Spawn("Grunt", At(10, 0)) -- 10 studs to the side
			Kit.Face(Second, Vector3.new(-1, 0, 0)) -- facing the body
			Kit.Run(4)
			T.Eq(#Got, 1, "BodyFound fired once in all")
			T.True(Got[1] ~= nil and Got[1].Body == Body and Got[1].Finder == First, "by the first Grunt")
			T.Eq(PS.PhaseOf(Second), "Unaware", "the second isn't raised by a found body")
		end) end) end)
	end,
	TakedownBodyStays = function(T)
		Kit.Guard(function()
			local Kept = Kit.Spawn("Grunt", At(0, 0))
			local Plain = Kit.Spawn("Grunt", At(10, 0))
			Kept:SetAttribute("TakenDownBy", Player.Name)
			Kept.Humanoid.Health = 0
			Plain.Humanoid.Health = 0
			task.wait(6)
			T.True(Plain.Parent == nil, "control: a plain kill's body is gone by 6 s")
			T.True(Kept.Parent ~= nil, "a takedown's body is still there after 6 s")
		end)
	end,

	-- ===== Task 6 =====
	-- Knock(Victim, Seconds): the length wins over KnockedTime (TuningConfig.Downed.KnockedTime 20 when none is given)
	KnockLength = function(T)
		Kit.Guard(function()
			local Control = Kit.Spawn("Grunt", At(0, 0))
			DM.Knock(Control)
			T.Near((Control:GetAttribute("KnockedUntil") or 0) - workspace:GetServerTimeNow(), 20, 0.2, "control: no length, 20 s")
			local Rig = Kit.Spawn("Grunt", At(10, 0))
			DM.Knock(Rig, 7)
			T.Near((Rig:GetAttribute("KnockedUntil") or 0) - workspace:GetServerTimeNow(), 7, 0.2, "Knock(Rig, 7): 7 s")
			-- (Task 6 review) the length beats the character's own KnockedTime attribute too (control: the attribute alone)
			local Own = Kit.Spawn("Grunt", At(-10, 0))
			Own:SetAttribute("KnockedTime", 30)
			DM.Knock(Own)
			T.Near((Own:GetAttribute("KnockedUntil") or 0) - workspace:GetServerTimeNow(), 30, 0.2, "control: KnockedTime 30 alone, 30 s")
			local Both = Kit.Spawn("Grunt", At(-20, 0))
			Both:SetAttribute("KnockedTime", 30)
			DM.Knock(Both, 7)
			T.Near((Both:GetAttribute("KnockedUntil") or 0) - workspace:GetServerTimeNow(), 7, 0.2, "KnockedTime 30 with Knock(Rig, 7): 7 s")
		end)
	end,
	-- (pre-flight R6, spec §18.1) V picks up a takedown's dead body like a knocked one; it stays carried over 20 studs, is
	-- set down in front, and is still a body: a patrol finds it at the new spot
	CarryTakedownBody = function(T)
		Kit.Guard(function() AtHour(12, function() Listen(function(Got)
			local Body, Info = DeadBody(0, 0)
			Free(Body)
			Kit.PutPlayer(NEAR)
			local Root, H = C.HumanoidRootPart, C.Humanoid
			local WS = H.WalkSpeed
			local From = TorsoOf(Body).Position
			T.Eq(DM.Request(C, "Carry"), "Carry", "V picks up the takedown body")
			T.Eq(Body:GetAttribute("CarriedBy"), C.Name, "CarriedBy")
			for _ = 1, 10 do -- 20 studs in 1 s (-Z) while the carry loop runs
				Root.CFrame += Vector3.new(0, 0, -2)
				task.wait(0.1)
			end
			task.wait(0.2)
			T.Eq(C:GetAttribute("Carrying"), Body.Name, "still carried after 20 studs: a dead takedown body is held")
			local Rel = Root.CFrame:PointToObjectSpace(Body.HumanoidRootPart.Position)
			T.True((Rel - Vector3.new(-1.5, 0.1, 0)).Magnitude < 0.1, "over the left shoulder (CarryOffset): " .. tostring(Rel))
			T.Eq(DM.Request(C, "Carry"), "Dropped", "V again sets it down")
			T.Eq(Body:GetAttribute("CarriedBy"), nil, "CarriedBy cleared")
			T.Eq(C:GetAttribute("Carrying"), nil, "Carrying cleared")
			T.Eq(CarryWeld(), nil, "no weld left on the carrier")
			T.Near(H.WalkSpeed, WS, 1e-3, "the carrier walks as before")
			task.wait(0.5) -- (it settles on the floor)
			local Torso = TorsoOf(Body)
			T.True(Flat(Torso.Position - From) >= 18, ("it went with the carrier: %.1f studs"):format(Flat(Torso.Position - From)))
			-- a patrol 10 studs off the new spot, facing it
			local P = Vector3.new(Torso.Position.X, Kit.Spot().Y, Torso.Position.Z + 10)
			local Patrol = Kit.Spawn("Grunt", CFrame.lookAt(P, P + Vector3.new(0, 0, -1)))
			Kit.PutPlayer(AWAY)
			Kit.Run(4)
			T.True(Info.Found == true, "the patrol found the body at its new spot")
			T.True(Got[1] ~= nil and Got[1].Body == Body and Got[1].Finder == Patrol, "BodyFound: that body, by that patrol")
			local Goal = PS.Goal(Patrol)
			T.True(Goal ~= nil and (Goal - Torso.Position).Magnitude <= 20, "searching around the new spot: " .. tostring(Goal))
		end) end) end)
	end,
	-- (pre-flight R6) B never takes a dead body, not even one handed to it; only V's lookup (Bodies) sees one
	GripRefusesCorpse = function(T)
		Kit.Guard(function()
			local Body = DeadBody(0, 0)
			Free(Body)
			Kit.PutPlayer(NEAR)
			local Where = C.HumanoidRootPart.Position
			local Gripped = false
			local Conn = Body:GetAttributeChangedSignal("GrippedBy"):Connect(function() Gripped = true end)
			local Ok, Err = pcall(function()
				T.Eq(DM.Grip(C), false, "B: nothing to grip")
				T.Eq(DM.Grip(C, Body), false, "B handed the body: refused")
			end)
			Conn:Disconnect()
			if not Ok then error(Err, 0) end
			T.Eq(Gripped, false, "the body was never gripped")
			T.True((C.HumanoidRootPart.Position - Where).Magnitude < 0.05, "the player wasn't moved onto it")
			T.Eq(C:GetAttribute("Gripping"), nil, "not gripping")
			T.Eq(DM.Nearest(C, 6), nil, "Grip's lookup skips the body")
			T.Eq(DM.Nearest(C, 6, {Bodies = true}), Body, "V's lookup (Bodies) finds it")
		end)
	end,
	-- (pre-flight R6) a carried body removed mid-carry (a knocked rig despawned, a corpse's 120 s) is dropped at once and
	-- cleanly: no weld left on the carrier, its walk back, and no other rig of the same name grabbed in its place
	DespawnMidCarry = function(T)
		Kit.Guard(function()
			local H = C.Humanoid
			local WS = H.WalkSpeed
			local Other = Kit.Spawn("Grunt", At(30, 30)) -- a live bandit of the same name, elsewhere
			local OtherAt = Other.HumanoidRootPart.Position
			local function Case(Target, What)
				T.Eq(Target.Name, Other.Name, "setup: " .. What .. " shares the other's name")
				Free(Target)
				Kit.PutPlayer(NEAR)
				T.True(DM.Carry(C, Target), What .. ": carried")
				Target:Destroy()
				task.wait(0.3)
				T.Eq(C:GetAttribute("Carrying"), nil, What .. ": dropped")
				T.Eq(CarryWeld(), nil, What .. ": no weld left on the carrier")
				T.Near(H.WalkSpeed, WS, 1e-3, What .. ": the carrier walks as before")
				T.True((Other.HumanoidRootPart.Position - OtherAt).Magnitude < 0.05, What .. ": the same-named bandit wasn't moved")
			end
			local Knocked = Kit.Spawn("Grunt", At(0, 0))
			DM.Knock(Knocked)
			Case(Knocked, "a knocked bandit")
			Case((DeadBody(0, 0)), "a takedown body")
		end)
	end,
	-- (pre-flight R16 / D3) Lock, Attach (with its own offset, never the carry's) and Detach are DownedManager's, shared
	SharedWeldAndLock = function(T)
		Kit.Guard(function()
			T.True(type(DM.Lock) == "function" and type(DM.Attach) == "function" and type(DM.Detach) == "function",
				"DownedManager.Lock / Attach / Detach exist")
			local Holder = Kit.Spawn("Grunt", At(0, 0))
			local Target = Free(Kit.Spawn("Grunt", At(10, 0)))
			T.True(DM.Attach(Holder, Target, CFrame.new(0, 0, -2)), "attached")
			local Rel = Holder.HumanoidRootPart.CFrame:PointToObjectSpace(Target.HumanoidRootPart.Position)
			T.True((Rel - Vector3.new(0, 0, -2)).Magnitude < 0.05, "at the given offset: " .. tostring(Rel))
			T.Eq(Target.Humanoid.PlatformStand, true, "held")
			DM.Detach(Target)
			T.Eq(Holder.HumanoidRootPart:FindFirstChild("DownedWeld"), nil, "Detach removes the weld")
			T.Eq(Target.Humanoid.PlatformStand, false, "let go")
			local HH = Holder.Humanoid
			local WS = HH.WalkSpeed
			DM.Lock(Holder, true, 5)
			T.Eq(HH.WalkSpeed, 5, "locked to the given speed")
			T.Eq(HH.JumpHeight, 0, "no jump")
			DM.Lock(Holder, false)
			T.Near(HH.WalkSpeed, WS, 1e-3, "unlocked: its own speed back")
			-- (Task 6 review) a knocked body another holder has welded (a takedown's weld) is never taken by V
			local Welded = Free(Kit.Spawn("Grunt", At(-10, 0)))
			DM.Knock(Welded)
			T.True(DM.Attach(Holder, Welded, CFrame.new(0, 0, -2)), "another holder's weld on a knocked bandit")
			Kit.PutPlayer(NEAR)
			T.Eq(DM.Carry(C, Welded), false, "V refuses the welded body")
			T.Eq(C:GetAttribute("Carrying"), nil, "the player carries nothing")
			T.Eq(CarryWeld(), nil, "and has no carry weld")
			DM.Detach(Welded)
		end)
	end,

	-- ===== Task 6b: a gripped body ragdolls =====
	GripRagdolls = function(T)
		Kit.Guard(function()
			-- control first: a plain Health = 0 kill is not a ragdoll (it lies whole, as before)
			local Plain = Free(Kit.Spawn("Grunt", At(10, 0)))
			Plain.Humanoid.Health = 0
			task.wait(0.5)
			T.Eq(Plain:GetAttribute("Ragdolled"), nil, "control: a plain kill is not Ragdolled")
			T.True(Plain.Torso.Neck.Enabled and Plain.Torso["Right Hip"].Enabled, "control: its joints are untouched")
			local Body = Gripped(0, 0)
			T.Eq(Body:GetAttribute("Ragdolled"), true, "the gripped body is Ragdolled")
			for _, Name in ipairs(LIMB_JOINTS) do
				local J = Body.Torso:FindFirstChild(Name)
				T.True(J ~= nil and J:IsA("Motor6D"), Name .. " is still there (disabled, not destroyed)")
				T.Eq(J.Enabled, false, Name .. " is disabled")
				T.True(SocketFor(Body, J) ~= nil, Name .. " has a BallSocketConstraint between its parts")
			end
			-- and every other Motor6D between two body parts too, except the RootJoint
			for _, J in ipairs(Body:GetDescendants()) do
				if J:IsA("Motor6D") and J.Part0 and J.Part1 and J.Part0.Parent == Body and J.Part1.Parent == Body then
					if J.Name == "RootJoint" then
						T.Eq(J.Enabled, true, "the RootJoint stays")
					else
						T.True(not J.Enabled and SocketFor(Body, J) ~= nil, J.Name .. ": disabled, with a ball socket")
					end
				end
			end
			T.True(WaitFor(2, function() return Height(Body) <= 1.5 end),
				("within 2 s the torso lies within 1.5 studs of the floor: %.2f"):format(Height(Body)))
			T.Eq(AnchoredPart(Body), nil, "nothing anchored while it falls")
		end)
	end,
	-- after Settle (4 s, PROPOSAL) + 1 s the body is anchored where it lies and doesn't move. (A takedown body, which
	-- stays Takedown.BodySeconds; since Task 7 a plain gripped body stays as long, owner 2026-10-27.)
	RagdollSettles = function(T)
		Kit.Guard(function()
			local Body = Gripped(0, 0, true)
			T.Eq(Body:GetAttribute("Ragdolled"), true, "Ragdolled")
			task.wait(SETTLE + 1)
			local Torso = TorsoOf(Body)
			T.Eq(Torso.Anchored, true, "settled: the torso is anchored")
			for _, P in ipairs(BodyParts(Body)) do T.Eq(P.Anchored, true, "settled: " .. P.Name .. " anchored") end
			local Was = Torso.Position
			task.wait(1)
			T.True((Torso.Position - Was).Magnitude <= 0.1, ("still over the next 1 s: %.3f"):format((Torso.Position - Was).Magnitude))
			T.True(Height(Body) <= 1.5, ("settled on the floor: %.2f"):format(Height(Body)))
		end)
	end,
	-- (Task 5's finding) a ragdolled body lies low; a Grunt 10 studs off, facing it at noon, still finds it
	RagdollBodyIsFound = function(T)
		Kit.Guard(function() AtHour(12, function() Listen(function(Got)
			local Body = Gripped(0, 0, true)
			T.Eq(Body:GetAttribute("Ragdolled"), true, "Ragdolled")
			T.True(WaitFor(2, function() return Height(Body) <= 1.5 end), ("lying down: %.2f"):format(Height(Body)))
			local Info = AddBody(Body, {Kind = "Dead", By = Player})
			local Rig = Kit.Spawn("Grunt", At(0, 10)) -- 10 studs off, facing it (-Z), in the open at noon
			Kit.PutPlayer(AWAY)
			Kit.Run(4)
			T.True(Info ~= nil and Info.Found == true, "a Grunt at 10 studs found the ragdolled body")
			T.True(Got[1] ~= nil and Got[1].Body == Body and Got[1].Finder == Rig, "BodyFound: that body, by that Grunt")
		end) end) end)
	end,
	-- Task 6's dead-body carry of a ragdolled takedown body: a settled (anchored) one is let go of, carried with
	-- nothing anchored, and set down limp, then settles again
	RagdollCarry = function(T)
		Kit.Guard(function()
			local Body = Gripped(0, 0, true)
			T.Eq(Body:GetAttribute("Ragdolled"), true, "Ragdolled")
			T.True(WaitFor(SETTLE + 3, function() return TorsoOf(Body).Anchored end), "settled before the carry")
			local Torso = TorsoOf(Body)
			local P = Vector3.new(Torso.Position.X, Kit.Spot().Y + 3, Torso.Position.Z + 3)
			Kit.PutPlayer(CFrame.lookAt(P, P + Vector3.new(0, 0, -1)))
			local Root = C.HumanoidRootPart
			T.Eq(DM.Request(C, "Carry"), "Carry", "V picks up the ragdolled takedown body")
			local Stuck = AnchoredPart(Body)
			for _ = 1, 10 do -- 20 studs in 1 s (-Z)
				Root.CFrame += Vector3.new(0, 0, -2)
				task.wait(0.1)
				Stuck = Stuck or AnchoredPart(Body)
			end
			T.Eq(Stuck, nil, "nothing of the body anchored mid-carry")
			T.Eq(C:GetAttribute("Carrying"), Body.Name, "still carried after 20 studs")
			local Off = Flat(Torso.Position - Root.Position)
			T.True(Off < 4, ("the body went with the carrier: %.1f studs off"):format(Off))
			T.Eq(DM.Request(C, "Carry"), "Dropped", "V again sets it down")
			T.Eq(CarryWeld(), nil, "no weld left on the carrier")
			T.Eq(AnchoredPart(Body), nil, "set down: nothing anchored")
			T.Eq(Body.Humanoid.PlatformStand, true, "set down limp (PlatformStand)")
			T.True(WaitFor(2, function() return Height(Body) <= 1.5 end), ("it falls to the floor: %.2f"):format(Height(Body)))
			T.True(WaitFor(SETTLE + 3, function() return Torso.Anchored end), "and settles again")
		end)
	end,

	-- ===== Task 7: the server takedown =====
	-- the refusals: each reason in LastTakedownResult, nothing marked
	RefuseFront = function(T)
		Kit.Guard(function()
			local Rig = Kit.Spawn("Grunt", At(0, 0))
			Kit.PutInFront(Rig, 3)
			Calm()
			Refused(T, Rig, "front", "3 studs in front")
		end)
	end,
	RefuseSide = function(T)
		Kit.Guard(function()
			local Rig = Kit.Spawn("Grunt", At(0, 0))
			Kit.PutBehind(Rig, 3, 90)
			Calm()
			Refused(T, Rig, "front", "3 studs at 90 degrees")
		end)
	end,
	RefuseFar = function(T)
		Kit.Guard(function()
			local Rig = Kit.Spawn("Grunt", At(0, 0))
			Kit.PutBehind(Rig, 6)
			Calm()
			Refused(T, Rig, "far", "6 studs behind")
		end)
	end,
	RefuseWall = function(T)
		Kit.Guard(function()
			local Rig = Behind()
			-- a 6 x 8 x 0.4 wall standing on the floor halfway between them (the player is at +Z)
			Kit.Wall(CFrame.new(Kit.Spot() + Vector3.new(0, 4, 1.5)), Vector3.new(6, 8, 0.4))
			Refused(T, Rig, "blocked", "a wall between")
		end)
	end,
	RefuseAlert = function(T)
		Kit.Guard(function()
			local Rig = Behind()
			PS.Alarm(Rig, Player)
			Refused(T, Rig, "alert", "Alert on the player")
		end)
	end,
	RefuseCombat = function(T)
		Kit.Guard(function()
			local Rig = Behind()
			C:SetAttribute("CombatMode", true)
			Refused(T, Rig, "combat", "in Combat Mode")
		end)
	end,
	-- PvE only (owner): the player's own character is refused first, and never marked
	RefuseSelf = function(T)
		Kit.Guard(function()
			Calm()
			local Ok, Why = Service().Request(Player, "Assassinate", C)
			T.Eq(Ok, false, "a player's character: refused")
			T.Eq(Why, "player", "the PvE rule")
			T.Eq(Result(), "Assassinate:player", "LastTakedownResult")
			T.Eq(C:GetAttribute("TakenDownBy"), nil, "the character has no TakenDownBy")
			T.Eq(C:GetAttribute("TakingDown"), nil, "nor TakingDown")
		end)
	end,
	-- the request module: wrong types are dropped quietly before the service; an unknown kind reaches it and is refused
	RefuseMalformed = function(T)
		Kit.Guard(function()
			local Rig = Behind()
			local Req = RequestModule()
			local Ok1, E1 = pcall(Req, Player, 5, Rig)
			T.True(Ok1, "a number for the kind: no error " .. tostring(E1))
			T.Eq(Result(), nil, "a number for the kind never reaches the service")
			local Ok2, E2 = pcall(Req, Player, "Assassinate", "x")
			T.True(Ok2, "a string for the target: no error " .. tostring(E2))
			T.Eq(Result(), nil, "a string for the target never reaches the service")
			local Ok3, E3 = pcall(Req, Player, "Fly", Rig)
			T.True(Ok3, "an unknown kind: no error " .. tostring(E3))
			T.Eq(Result(), "Fly:kind", "an unknown kind: refused as such")
			T.Eq(Rig:GetAttribute("TakenDownBy"), nil, "nothing marked")
			T.Eq(C:GetAttribute("TakingDown"), nil, "nothing marked on the player")
		end)
	end,

	-- 3 studs straight behind an Unaware Grunt, crouched (the crouch's own Stun doesn't count): dead within LethalTime + 1,
	-- one Takedown sound of 4 and no Hit; the body stays marked, ragdolled and registered; the player released
	AssassinateFromBehind = function(T)
		Kit.Guard(function()
			local Rig = Behind()
			Kit.Crouch(true)
			local H = C.Humanoid
			local WS, JH = H.WalkSpeed, H.JumpHeight
			local Log = {}
			NS.Log = Log
			local Ok, Err = pcall(function()
				local Started, Why = Assassinate(Rig)
				T.Eq(Started, true, "started (" .. tostring(Why) .. ")")
				T.Eq(Rig:GetAttribute("TakenDownBy"), Player.Name, "the target is marked at once")
				T.Eq(C:GetAttribute("TakingDown"), Rig.Name, "the player is marked at once")
				T.True(WaitFor(2, function() return Rig.Humanoid.Health <= 0 end), "dead within LethalTime + 1 s")
				T.True(Finished(1), "the takedown ended")
			end)
			NS.Log = nil
			if not Ok then error(Err, 0) end
			T.Eq(Result(), "Assassinate:ok", "LastTakedownResult")
			local Takedowns, Hits = 0, 0
			for _, E in ipairs(Log) do
				if E.Kind == "Takedown" then
					Takedowns += 1
					T.Eq(E.Radius, 4, "the Takedown sound's radius")
				elseif E.Kind == "Hit" then
					Hits += 1
				end
			end
			T.Eq(Takedowns, 1, "one Takedown sound")
			T.Eq(Hits, 0, "no Hit sound (finding A4)")
			T.Eq(Rig:GetAttribute("TakenDownBy"), Player.Name, "TakenDownBy stays on the corpse")
			T.Eq(Rig:GetAttribute("Ragdolled"), true, "the corpse is a ragdoll (owner)")
			local Info = PS.Bodies[Rig]
			T.True(Info ~= nil and Info.Kind == "Dead" and Info.By == Player, "registered as a Dead body by the player")
			T.Eq(C.HumanoidRootPart:FindFirstChild("DownedWeld"), nil, "no takedown weld left on the player")
			T.Near(H.WalkSpeed, WS, 1e-3, "the player walks as before")
			T.Near(H.JumpHeight, JH, 1e-3, "and jumps as before")
			local Ready = C:GetAttribute("TakedownReadyAt")
			T.True(type(Ready) == "number", "TakedownReadyAt written")
			T.Near(Ready - workspace:GetServerTimeNow(), 4, 0.5, "ready again in the 4 s cooldown")
		end)
	end,
	-- the kill is credited once, straight to the player (no hit path), and the deed recorded. QuestService.Signal is
	-- held (counted, not run) for the case, so a bounty the kill would finish adds no reward EXP: only the kill's own
	-- EXP is measured (Foundry, a session's earlier kills: a "Defeat bandits" bounty completed here and gave 150 more)
	AssassinateCredit = function(T)
		local QuestService = require(SSS.QuestService)
		local Real = QuestService.Signal
		local Defeats = 0
		QuestService.Signal = function(_, Kind) if Kind == "Defeat" then Defeats += 1 end end
		local Ok, Err = pcall(Kit.Guard, function()
			local Rig = Behind({Credit = true})
			Deed("assassinated_bandit")
			local D = Progression.GetData(Player)
			local Exp0, Count0 = D.LifetimeExp, Count("assassinated_bandit")
			local Started, Why = Assassinate(Rig)
			T.Eq(Started, true, "started (" .. tostring(Why) .. ")")
			T.True(Finished(), "ended")
			T.Eq(Result(), "Assassinate:ok")
			T.Eq(D.LifetimeExp - Exp0, 50, "EXP: the Grunt's 25 x level 2")
			T.Eq(Defeats, 1, "one Defeat signalled for quests")
			T.Eq(Count("assassinated_bandit") - Count0, 1, "assassinated_bandit counted once")
			task.wait(1)
			T.Eq(D.LifetimeExp - Exp0, 50, "still credited once a second later")
			T.Eq(Defeats, 1, "still one Defeat")
		end)
		QuestService.Signal = Real
		if not Ok then error(Err, 0) end
	end,
	-- a Suspicious Grunt (sent to look at a noise 10 studs in front of it) can be taken down
	AssassinateSuspicious = function(T)
		Kit.Guard(function()
			local Rig = Behind()
			local Root = Rig.HumanoidRootPart
			T.True(PS.Hear(Root.Position + Root.CFrame.LookVector * 10, 20, nil) >= 1, "setup: it heard the noise")
			T.Eq(PS.PhaseOf(Rig), "Suspicious", "setup: Suspicious")
			local Started, Why = Assassinate(Rig)
			T.Eq(Started, true, "a Suspicious Grunt: allowed (" .. tostring(Why) .. ")")
			T.True(Finished(), "ended")
			T.Eq(Result(), "Assassinate:ok")
		end)
	end,
	-- the one quick look (spec §6): a Grunt facing the player turns Alert on them; one facing away doesn't
	WitnessAlerts = function(T)
		Kit.Guard(function()
			local Rig = Kit.Spawn("Grunt", At(0, 0))
			local Watcher = Kit.Spawn("Grunt", At(10, 3))
			Kit.Face(Watcher, Vector3.new(-1, 0, 0)) -- 10 studs off the player, facing them
			local Away = Kit.Spawn("Grunt", At(-10, 3))
			Kit.Face(Away, Vector3.new(-1, 0, 0)) -- 10 studs off, facing away
			Kit.PutBehind(Rig, 3)
			Calm()
			T.Eq(Assassinate(Rig), true, "started")
			T.True(Finished(), "ended")
			T.Eq(PS.PhaseOf(Watcher), "Alert", "the Grunt that saw it: Alert")
			T.Eq(PS.Target(Watcher), C, "on the player")
			T.Eq(PS.PhaseOf(Away), "Unaware", "the Grunt facing away: still Unaware")
		end)
	end,
	-- 4 s after a finished takedown: 1 s later refused (cooldown), 4.2 s later allowed
	Cooldown = function(T)
		Kit.Guard(function()
			local A = Behind()
			local B = Kit.Spawn("Grunt", At(0, -20)) -- 20 studs ahead of A, its back to the player
			T.Eq(Assassinate(A), true, "the first started")
			T.True(Finished(), "the first ended")
			local Done = os.clock()
			T.Eq(Result(), "Assassinate:ok")
			Kit.PutBehind(B, 3)
			task.wait(math.max(0, Done + 1 - os.clock()))
			local Ok, Why = Assassinate(B)
			T.Eq(Ok, false, "1 s later: refused")
			T.Eq(Why, "cooldown", "the reason")
			T.Eq(Result(), "Assassinate:cooldown")
			task.wait(math.max(0, Done + 4.2 - os.clock()))
			local Ok2, Why2 = Assassinate(B)
			T.Eq(Ok2, true, "4.2 s later: allowed (" .. tostring(Why2) .. ")")
			T.True(Finished(), "the second ended")
		end)
	end,
	-- two requests for one Grunt in the same frame: the target is marked in the request's own step, so the second is
	-- target_busy. (One player in the test: the second request stands for another player by clearing this one's
	-- TakingDown for the call and putting it back in the same frame.)
	OneTakedownPerTarget = function(T)
		Kit.Guard(function()
			local Rig = Behind()
			local S = Service()
			local Ok1 = S.Request(Player, "Assassinate", Rig)
			local Was = C:GetAttribute("TakingDown")
			C:SetAttribute("TakingDown", nil)
			local Ok2, Why2 = S.Request(Player, "Assassinate", Rig)
			C:SetAttribute("TakingDown", Was)
			T.Eq(Ok1, true, "the first started")
			T.Eq(Ok2, false, "the second, the same frame: refused")
			T.Eq(Why2, "target_busy", "the target is already being taken down")
			T.True(Finished(), "the first ended")
			T.Eq(Result(), "Assassinate:ok", "the first one finished")
		end)
	end,
	-- a Stun on the player mid-takedown: interrupted; the Grunt lives, unmarked, Alert on the player; Failed once
	InterruptByStun = function(T)
		Kit.Guard(function()
			local Rig = Behind()
			local S = Service()
			local Fails = {}
			local function L(P, R, Reason) table.insert(Fails, {P = P, R = R, Reason = Reason}) end
			table.insert(S.Failed, L)
			local Held = nil
			local Ok, Err = pcall(function()
				T.Eq(S.Request(Player, "Assassinate", Rig), true, "started")
				task.wait(0.2)
				Held = Stun.new(WCS.Character.GetCharacterFromInstance(C))
				Held:Start(0.3)
				T.True(Finished(1), "ended")
			end)
			-- (Task 7 review) the test's Stun stopped here, so an aborted case leaks no "busy" into the next
			if Held then pcall(function() Held:Stop() end) end
			local I = table.find(S.Failed, L)
			if I then table.remove(S.Failed, I) end
			if not Ok then error(Err, 0) end
			T.Eq(Result(), "Assassinate:interrupted", "LastTakedownResult")
			T.True(Rig.Humanoid.Health > 0, "the Grunt is alive")
			T.Eq(Rig:GetAttribute("TakenDownBy"), nil, "and unmarked")
			T.Eq(PS.PhaseOf(Rig), "Alert", "Alert")
			T.Eq(PS.Target(Rig), C, "on the player")
			T.Eq(#Fails, 1, "Failed fired once")
			T.True(Fails[1] ~= nil and Fails[1].P == Player and Fails[1].R == Rig and Fails[1].Reason == "interrupted",
				"Failed(Player, Rig, \"interrupted\")")
			T.Eq(C.HumanoidRootPart:FindFirstChild("DownedWeld"), nil, "no weld left")
			T.Eq(Rig.Humanoid.PlatformStand, false, "the Grunt let go")
			T.Eq(Rig:GetAttribute("DamageTakenMult"), nil, "its damage taken as before")
		end)
	end,
	-- (pre-flight, the downed side task's row for Task 7) a player knocked mid-takedown keeps the crawl: the release
	-- never writes a walk speed over the knock's
	KnockedMidTakedown = function(T)
		Kit.Guard(function()
			local Rig = Behind()
			local H = C.Humanoid
			local WS = H.WalkSpeed
			local Highest = nil
			local Conn
			local Ok, Err = pcall(function()
				T.Eq(Assassinate(Rig), true, "started")
				task.wait(0.2)
				DM.Knock(C)
				T.True(DM.IsKnocked(C), "setup: the player is knocked")
				Highest = H.WalkSpeed
				Conn = H:GetPropertyChangedSignal("WalkSpeed"):Connect(function() Highest = math.max(Highest, H.WalkSpeed) end)
				T.True(Finished(1), "ended")
				T.Eq(Result(), "Assassinate:interrupted", "a knock interrupts it")
				task.wait(0.3)
				T.True(Highest <= 3 + 1e-3, ("the walk speed never rose above the crawl's 3 after the knock (%.2f)"):format(Highest))
			end)
			if Conn then Conn:Disconnect() end
			if DM.IsKnocked(C) then DM.Recover(C) end
			task.wait(0.2)
			if not Ok then error(Err, 0) end
			T.Near(H.WalkSpeed, WS, 1e-3, "recovered: the walk from before the takedown")
		end)
	end,
	-- the victim takes no damage from anyone during the takedown
	VictimProtected = function(T)
		Kit.Guard(function()
			local Rig = Behind()
			local Health = Rig.Humanoid.Health
			T.Eq(Assassinate(Rig), true, "started")
			DM.Damage(Rig, 999)
			T.Eq(Rig.Humanoid.Health, Health, "999 damage mid-takedown: health unchanged")
			T.Eq(DM.IsKnocked(Rig), false, "and not knocked")
			T.True(Finished(), "ended")
		end)
	end,
	-- (pre-flight R8, spec §18.3) a law-faction victim: assassinated_guard (Mercy -5), and Heat in this place's law when a
	-- same-faction guard (an agent, Carrier) saw it
	AssassinateGuard = function(T)
		assert(LAW, "a law faction for this place")
		Kit.Guard(function()
			Deed("assassinated_guard")
			Deed("assassinated_bandit")
			local Guard0, Bandit0, Mercy0 = Count("assassinated_guard"), Count("assassinated_bandit"), Mercy()
			local Heat0 = HS.Value(Player, LAW.J)
			local Rig = Kit.Spawn("Grunt", At(0, 0))
			Rig:SetAttribute("Faction", LAW.Faction)
			local Witness = Kit.Spawn("Grunt", At(10, 3))
			Kit.Face(Witness, Vector3.new(-1, 0, 0)) -- facing the player
			PS.Npcs[Witness].Faction, PS.Npcs[Witness].Carrier = LAW.Faction, true -- (as Register takes a watcher's)
			Kit.PutBehind(Rig, 3)
			Calm()
			T.Eq(Assassinate(Rig), true, "started")
			T.True(Finished(), "ended")
			T.Eq(Result(), "Assassinate:ok")
			task.wait(0.3)
			T.Eq(Count("assassinated_guard") - Guard0, 1, "assassinated_guard recorded")
			T.Eq(Count("assassinated_bandit") - Bandit0, 0, "not a bandit's deed")
			T.Eq(Mercy() - Mercy0, -5, "Mercy -5")
			T.Near(HS.Value(Player, LAW.J) - Heat0, 60, 1, LAW.J .. " Heat: the guard deed's 60, witnessed")
		end)
	end,
	-- (pre-flight R9) a guard assassinated unseen raises no Heat; when its body is found, the law's Heat rises once
	GuardBodyFoundHeat = function(T)
		assert(LAW, "a law faction for this place")
		Kit.Guard(function() AtHour(12, function()
			Deed("assassinated_guard")
			local Heat0 = HS.Value(Player, LAW.J)
			local Rig = Kit.Spawn("Grunt", At(0, 0))
			Rig:SetAttribute("Faction", LAW.Faction)
			Kit.PutBehind(Rig, 3)
			Calm()
			T.Eq(Assassinate(Rig), true, "started")
			T.True(Finished(), "ended")
			T.Eq(Result(), "Assassinate:ok")
			task.wait(0.3)
			T.Near(HS.Value(Player, LAW.J) - Heat0, 0, 0.5, "nobody saw it: no Heat yet")
			local Info = PS.Bodies[Rig]
			T.True(Info ~= nil, "the body is registered")
			T.True(WaitFor(2, function() return Height(Rig) <= 1.5 end), "it lies down")
			local Torso = TorsoOf(Rig)
			local P = Vector3.new(Torso.Position.X, Kit.Spot().Y, Torso.Position.Z + 10)
			Kit.Spawn("Grunt", CFrame.lookAt(P, P + Vector3.new(0, 0, -1))) -- a patrol 10 studs off, facing it
			Kit.PutPlayer(AWAY)
			Kit.Run(4)
			T.True(Info.Found == true, "the patrol found the body")
			task.wait(0.3)
			T.Near(HS.Value(Player, LAW.J) - Heat0, 60, 1, LAW.J .. " Heat: 60 when the body is found")
			Kit.Run(2)
			T.Near(HS.Value(Player, LAW.J) - Heat0, 60, 1, "once")
		end) end)
	end,
	-- (Task 5's carry: finding checked on a real ragdoll) an assassinated bandit lies down, a patrol finds it, and the
	-- corpse is still there after 6 s (TakenDownBy before Health 0: Takedown.BodySeconds)
	AssassinatedBodyIsFound = function(T)
		Kit.Guard(function() AtHour(12, function() Listen(function(Got)
			local Rig = Behind()
			T.Eq(Assassinate(Rig), true, "started")
			T.True(Finished(), "ended")
			local Died = os.clock()
			T.True(WaitFor(2, function() return Height(Rig) <= 1.5 end), ("the ragdoll lies down: %.2f"):format(Height(Rig)))
			local Patrol = Kit.Spawn("Grunt", At(0, 10)) -- 10 studs off, facing it (-Z)
			Kit.PutPlayer(AWAY)
			Kit.Run(4)
			T.True(PS.Bodies[Rig] ~= nil and PS.Bodies[Rig].Found == true, "the patrol found the assassinated body")
			T.True(Got[1] ~= nil and Got[1].Body == Rig and Got[1].Finder == Patrol, "BodyFound: that body, by that patrol")
			task.wait(math.max(0, Died + 6 - os.clock()))
			T.True(Rig.Parent ~= nil, "the corpse is still there after 6 s")
		end) end) end)
	end,
	-- (Task 6b review) every takedown end lets go of the victim (Detach), the kill included: V can carry the body
	AssassinatedBodyCarried = function(T)
		Kit.Guard(function()
			local Rig = Behind()
			T.Eq(Assassinate(Rig), true, "started")
			T.True(Finished(), "ended")
			T.True(WaitFor(2, function() return Height(Rig) <= 1.5 end), "it lies down")
			local Torso = TorsoOf(Rig)
			local P = Vector3.new(Torso.Position.X, Kit.Spot().Y + 3, Torso.Position.Z + 3)
			Kit.PutPlayer(CFrame.lookAt(P, P + Vector3.new(0, 0, -1)))
			T.Eq(DM.Request(C, "Carry"), "Carry", "V picks up the assassinated body")
			T.Eq(Rig:GetAttribute("CarriedBy"), C.Name, "carried")
			T.Eq(DM.Request(C, "Carry"), "Dropped", "and sets it down")
		end)
	end,
	-- (Task 6's finding) a carried corpse is no prisoner: CheckDeliveries hands over only a knocked, living enemy
	CorpseIsNoPrisoner = function(T)
		Kit.Guard(function()
			local NPCs = workspace.World:FindFirstChild("NPCs")
			T.True(NPCs ~= nil, "setup: World.NPCs")
			local Captor = Instance.new("Model")
			Captor.Name = "Takedown_TestCaptor"
			Captor:SetAttribute("TakesPrisoners", true)
			local R = Instance.new("Part")
			R.Name, R.Anchored, R.CanCollide, R.Transparency = "HumanoidRootPart", true, false, 1
			R.Size = Vector3.new(2, 2, 1)
			R.Parent = Captor
			local Ok, Err = pcall(function()
				-- control: a knocked bandit carried within 10 studs of the captor is handed over
				local Knocked = Free(Kit.Spawn("Grunt", At(0, 0)))
				DM.Knock(Knocked)
				Kit.PutPlayer(NEAR)
				T.True(DM.Carry(C, Knocked), "setup: carrying a knocked bandit")
				R.CFrame = C.HumanoidRootPart.CFrame * CFrame.new(0, 0, -5)
				Captor.Parent = NPCs
				T.True(WaitFor(1.5, function() return Knocked:GetAttribute("Arrested") == true end), "control: the knocked bandit is taken prisoner")
				Captor.Parent = nil
				-- a takedown's corpse carried the same way is not
				local Body = DeadBody(20, 0)
				Free(Body)
				Kit.PutPlayer(At(20, 4) + Vector3.new(0, 3, 0))
				T.True(DM.Carry(C, Body), "setup: carrying a takedown's corpse")
				R.CFrame = C.HumanoidRootPart.CFrame * CFrame.new(0, 0, -5)
				Captor.Parent = NPCs
				task.wait(1.5)
				T.Eq(Body:GetAttribute("Arrested"), nil, "the corpse is not taken prisoner")
				T.Eq(C:GetAttribute("Carrying"), Body.Name, "and is still carried")
			end)
			Captor:Destroy()
			if not Ok then error(Err, 0) end
		end)
	end,
	-- (Task 4 review) Glimpse looks past the victim (Except): a guard in front of the victim sees the player behind it
	GlimpseThroughVictim = function(T)
		Kit.Guard(function()
			local Victim = Kit.Spawn("Grunt", At(0, 0))
			local Witness = Kit.Spawn("Grunt", At(0, -10))
			Kit.Face(Witness, Vector3.new(0, 0, 1)) -- facing the victim, and the player behind it
			Kit.PutBehind(Victim, 3)
			T.True(not Has(Glimpse(nil), Witness), "control: with nobody excepted, the victim's body hides the player")
			PS.Reset(Witness)
			T.True(Has(Glimpse(Victim), Witness), "the victim excepted: the witness sees past it")
		end)
	end,
	-- (Task 4 review; regression guards, the code already skips these) a knocked NPC takes no look; one beyond its
	-- type's range (a Grunt's 30 studs) doesn't see; the control, 8 studs off facing the player, does
	GlimpseSkipsAndRange = function(T)
		Kit.Guard(function()
			local Knocked = Kit.Spawn("Grunt", At(0, 0))
			Kit.PutInFront(Knocked, 8) -- the player at (0, -8), facing it
			DM.Knock(Knocked)
			local Far = Kit.Spawn("Grunt", At(0, -43)) -- 35 studs off the player
			Kit.Face(Far, Vector3.new(0, 0, 1))
			local Near = Kit.Spawn("Grunt", At(8, -8)) -- 8 studs off the player
			Kit.Face(Near, Vector3.new(-1, 0, 0))
			local Seen = Glimpse(nil)
			T.True(Has(Seen, Near), "control: 8 studs off, facing the player: sees")
			T.True(not Has(Seen, Knocked), "a knocked NPC takes no look")
			T.True(not Has(Seen, Far), "35 studs off (beyond 30): doesn't see")
		end)
	end,
	-- (Task 5 review) a call for help brings in the living only
	CallSkipsDead = function(T)
		Kit.Guard(function()
			local Rig = Kit.Spawn("Grunt", At(0, 0))
			local Dead = Free(Kit.Spawn("Grunt", At(0, 30)))
			Dead.Humanoid.Health = 0
			local Live = Kit.Spawn("Grunt", At(30, 0))
			task.wait(0.2)
			Raise(Rig, Kit.Spot() + Vector3.new(10, 0, 0))
			T.Eq(PS.PhaseOf(Live), "Suspicious", "control: a living Grunt 30 studs off is called")
			T.Eq(PS.PhaseOf(Dead), "Unaware", "a dead one is not")
		end)
	end,
	-- (Task 5 review) a body that isn't in the world (taken out of workspace) is never found
	BodyOutsideWorldIgnored = function(T)
		Kit.Guard(function() AtHour(12, function()
			local Body, Info = DeadBody(0, 0)
			local Live = Body.Parent
			Body.Parent = game:GetService("ServerStorage")
			local Ok, Err = pcall(function()
				Kit.Spawn("Grunt", At(0, 10)) -- 10 studs off, facing it
				Kit.PutPlayer(AWAY)
				Kit.Run(4)
				T.True(not Info.Found, "outside workspace: not found")
				Body.Parent = Live
				Kit.Run(4)
				T.True(Info.Found == true, "control: back in the world, found")
			end)
			if Body.Parent ~= Live then Body.Parent = Live end
			if not Ok then error(Err, 0) end
		end) end)
	end,

	-- ===== owner 2026-10-27: gripped bodies stay 120 s and are bodies (clues) =====
	GrippedBodyStays = function(T)
		Kit.Guard(function()
			local Plain = Free(Kit.Spawn("Grunt", At(10, 0)))
			Plain.Humanoid.Health = 0
			local Body = Gripped(0, 0)
			task.wait(6)
			T.True(Plain.Parent == nil, "control: a plain kill's body is gone by 6 s")
			T.True(Body.Parent ~= nil, "a gripped body is still there after 6 s")
			T.Eq(Body:GetAttribute("Ragdolled"), true, "and a ragdoll")
		end)
	end,
	GrippedBodyIsFound = function(T)
		Kit.Guard(function() AtHour(12, function() Listen(function(Got)
			local Plain = Free(Kit.Spawn("Grunt", At(20, 0)))
			Plain.Humanoid.Health = 0
			task.wait(0.3)
			T.Eq(PS.Bodies[Plain], nil, "control: a plain death registers no body")
			local Body = Gripped(0, 0)
			local Info = PS.Bodies[Body]
			T.True(Info ~= nil and Info.Kind == "Dead", "the gripped body is registered (Dead)")
			local Rig = Kit.Spawn("Grunt", At(0, 10)) -- 10 studs off, facing it (-Z), at noon
			Kit.PutPlayer(AWAY)
			Kit.Run(4)
			T.True(Info ~= nil and Info.Found == true, "found")
			local Mine = nil
			for _, G in ipairs(Got) do if G.Body == Body then Mine = G end end
			T.True(Mine ~= nil and Mine.Finder == Rig, "BodyFound: the gripped body, by that Grunt")
		end) end) end)
	end,
	-- ===== Task 8: the knockout; waking up raises the alarm =====
	-- 3 studs straight behind an Unaware Grunt: "Knockout:ok" after KnockoutTime (2 s); knocked out 300 s, lying still at
	-- WalkSpeed 0 (pre-flight: a crawl never reaches an enemy); one Choke sound of 6 at the start; no deed; KnockedOutBy;
	-- an "Out" body by the player; the victim let go
	KnockoutFromBehind = function(T)
		Kit.Guard(function()
			local Rig = Behind()
			local Deeds0, Mercy0 = DeedsKey(), Mercy()
			local Log = {}
			NS.Log = Log
			local T0 = os.clock()
			local Took = nil
			local Ok, Err = pcall(function()
				local Started, Why = KnockOut(Rig)
				T.Eq(Started, true, "started (" .. tostring(Why) .. ")")
				task.wait(0.3)
				T.Eq(C:GetAttribute("TakingDown"), Rig.Name, "still choking at 0.3 s")
				local Early = 0
				for _, E in ipairs(Log) do if E.Kind == "Choke" then Early += 1 end end
				T.Eq(Early, 1, "a Choke sound at the start")
				T.True(Finished(3), "ended")
				Took = os.clock() - T0
			end)
			NS.Log = nil
			if not Ok then error(Err, 0) end
			T.Eq(Result(), "Knockout:ok", "LastTakedownResult")
			T.True(Took ~= nil and Took >= 1.9 and Took <= 2.6, "it took KnockoutTime (2 s): " .. tostring(Took))
			local Chokes = 0
			for _, E in ipairs(Log) do
				if E.Kind == "Choke" then
					Chokes += 1
					T.Eq(E.Radius, 6, "the Choke sound's radius")
				end
			end
			T.Eq(Chokes, 1, "one Choke sound in all")
			T.True(Rig.Humanoid.Health > 0, "alive")
			T.Eq(DM.IsKnocked(Rig), true, "knocked")
			T.Near((Rig:GetAttribute("KnockedUntil") or 0) - workspace:GetServerTimeNow(), 300, 1, "knocked out for 300 s")
			T.Eq(Rig.Humanoid.WalkSpeed, 0, "lying still (WalkSpeed 0)")
			T.Eq(Rig:GetAttribute("KnockedOutBy"), Player.UserId, "KnockedOutBy = the player's UserId")
			T.Eq(Rig:GetAttribute("TakenDownBy"), nil, "no longer being taken down")
			T.Eq(Rig:GetAttribute("DamageTakenMult"), nil, "its damage taken as before")
			local Info = PS.Bodies[Rig]
			T.True(Info ~= nil and Info.Kind == "Out" and Info.By == Player, "an Out body, by the player")
			T.Eq(DeedsKey(), Deeds0, "no deed recorded")
			T.Eq(Mercy(), Mercy0, "Mercy unchanged")
			T.Eq(CarryWeld(), nil, "no takedown weld left on the player")
			T.Eq(Rig.Humanoid.PlatformStand, false, "the Grunt let go")
		end)
	end,
	KnockedOutCanBeCarried = function(T)
		Kit.Guard(function()
			local Rig = Behind()
			T.Eq(KnockOut(Rig), true, "started")
			T.True(Finished(3), "ended")
			T.Eq(Result(), "Knockout:ok")
			T.Eq(DM.Carry(C), true, "V picks up the knocked-out Grunt")
			T.Eq(Rig:GetAttribute("CarriedBy"), C.Name, "carried")
			DM.Drop(C)
			T.Eq(Rig:GetAttribute("CarriedBy"), nil, "set down")
			T.Eq(CarryWeld(), nil, "no carry weld left")
			T.Eq(DM.IsKnocked(Rig), true, "still knocked out")
		end)
	end,
	-- waking (DownedManager.Recover, the path the 300 s timer takes): Alert with nobody to fight, searching where it woke;
	-- a Grunt 25 studs off (inside the 40-stud call) comes to look; no longer a body
	WakeRaisesAlarm = function(T)
		Kit.Guard(function()
			local Rig = Behind()
			T.Eq(KnockOut(Rig), true, "started")
			T.True(Finished(3), "ended")
			T.Eq(Result(), "Knockout:ok")
			T.Eq(DM.IsKnocked(Rig), true, "setup: knocked out")
			local Second = Kit.Spawn("Grunt", At(-25, 0))
			local Woke = Rig.HumanoidRootPart.Position
			DM.Recover(Rig)
			T.True(WaitFor(1, function() return PS.PhaseOf(Rig) == "Alert" end), "awake: Alert (" .. PS.PhaseOf(Rig) .. ")")
			T.Eq(PS.Target(Rig), nil, "with nobody to fight")
			local Goal = PS.Goal(Rig)
			T.True(Goal ~= nil and (Goal - Woke).Magnitude <= 20, "searching around where it woke: " .. tostring(Goal))
			T.Eq(PS.PhaseOf(Second), "Suspicious", "a Grunt 25 studs off is called in")
			T.Eq(Rig:GetAttribute("KnockedOutBy"), nil, "KnockedOutBy cleared")
			T.Eq(PS.Bodies[Rig], nil, "no longer a body")
		end)
	end,
	KnockedOutBodyFound = function(T)
		Kit.Guard(function() AtHour(12, function() Listen(function(Got)
			local Rig = Behind()
			T.Eq(KnockOut(Rig), true, "started")
			T.True(Finished(3), "ended")
			T.Eq(Result(), "Knockout:ok")
			Kit.PutPlayer(AWAY)
			local Patrol = Kit.Spawn("Grunt", At(0, 10)) -- 10 studs off, facing it (-Z), at noon
			Kit.Run(4)
			local Mine = nil
			for _, G in ipairs(Got) do if G.Body == Rig then Mine = G end end
			T.True(Mine ~= nil and Mine.Finder == Patrol, "BodyFound: the knocked-out Grunt, by the patrol")
			T.True(Mine ~= nil and Mine.Info.Kind == "Out", "Info.Kind == \"Out\"")
		end) end) end)
	end,
	-- a Stun on the player at 1 s: interrupted; the Grunt not knocked, not a body, Alert on the player
	InterruptKnockout = function(T)
		Kit.Guard(function()
			local Rig = Behind()
			local Held = nil
			local Ok, Err = pcall(function()
				T.Eq(KnockOut(Rig), true, "started")
				task.wait(1)
				T.Eq(C:GetAttribute("TakingDown"), Rig.Name, "still choking at 1 s")
				Held = Stun.new(WCS.Character.GetCharacterFromInstance(C))
				Held:Start(0.3)
				T.True(Finished(1), "ended")
			end)
			if Held then pcall(function() Held:Stop() end) end -- (Task 7 review: no Stun leaks into the next case)
			if not Ok then error(Err, 0) end
			T.Eq(Result(), "Knockout:interrupted", "LastTakedownResult")
			T.True(Rig.Humanoid.Health > 0, "the Grunt is alive")
			T.Eq(DM.IsKnocked(Rig), false, "and not knocked")
			T.Eq(Rig:GetAttribute("TakenDownBy"), nil, "unmarked")
			T.Eq(Rig:GetAttribute("KnockedOutBy"), nil, "no KnockedOutBy")
			T.Eq(PS.Bodies[Rig], nil, "not a body")
			T.Eq(PS.PhaseOf(Rig), "Alert", "Alert")
			T.Eq(PS.Target(Rig), C, "on the player")
		end)
	end,
	-- (carried from Task 7) the found-body Heat keys on the body: a law-faction NPC a player killed, gripped as well as
	-- assassinated. The control: a gripped bandit's body raises none.
	GrippedGuardBodyFoundHeat = function(T) GrippedBodyHeat(T, LAW and LAW.Faction, 60) end,
	GrippedBanditBodyNoHeat = function(T) GrippedBodyHeat(T, nil, 0) end,

	-- ===== Task 9: Elites, bosses, townsfolk, the hooks =====
	-- (spec §8) an Elite at full health, from behind: a backstab -- 45% of its max health through the normal hit path (one
	-- Hit sound of 20, Alert on the player), a stun, TakenDownBy cleared, no deed, no body, no weld; it survives, so
	-- Failed(Player, Rig, "survived") (the Nemesis hook) and no Done
	EliteBackstab = function(T)
		Kit.Guard(function() Hooks(function(Got)
			local Rig = Kit.Spawn("Elite", At(0, 0))
			Kit.PutBehind(Rig, 3)
			Calm()
			local H = Rig.Humanoid
			T.Near(H.Health, H.MaxHealth, 1e-3, "setup: full health")
			local Deeds0 = DeedsKey()
			local Log = {}
			NS.Log = Log
			local Ok, Err = pcall(function()
				local Started, Why = Assassinate(Rig)
				T.Eq(Started, true, "started (" .. tostring(Why) .. ")")
				T.True(Finished(2), "ended")
			end)
			NS.Log = nil
			if not Ok then error(Err, 0) end
			T.Eq(Result(), "Assassinate:backstab", "LastTakedownResult")
			T.True(HasStun(Rig), "the Elite is stunned")
			T.Near(H.Health, H.MaxHealth * 0.55, 1, "45% of its max health gone")
			T.Eq(DM.IsKnocked(Rig), false, "not knocked (45% can't from full health)")
			T.Eq(PS.PhaseOf(Rig), "Alert", "Alert")
			T.Eq(PS.Target(Rig), C, "on the player")
			local Hits = 0
			for _, E in ipairs(Log) do
				if E.Kind == "Hit" then
					Hits += 1
					T.Eq(E.Radius, 20, "the Hit sound's radius")
				end
			end
			T.Eq(Hits, 1, "one Hit sound (the normal hit path)")
			T.Eq(#Got.Failed, 1, "Failed fired once")
			local F = Got.Failed[1]
			T.True(F ~= nil and F.P == Player and F.R == Rig and F.Reason == "survived", 'Failed(Player, Rig, "survived")')
			T.Eq(#Got.Done, 0, "no Done")
			T.Eq(Rig:GetAttribute("TakenDownBy"), nil, "TakenDownBy cleared")
			T.Eq(DeedsKey(), Deeds0, "no deed")
			T.Eq(PS.Bodies[Rig], nil, "not a body")
			T.Eq(C.HumanoidRootPart:FindFirstChild("DownedWeld"), nil, "no weld")
			T.True(WaitFor(2, function() return not HasStun(Rig) end), "the stun ends (ChunkStun 1.2 s)")
		end) end)
	end,
	-- (spec §8) an Elite can't be knocked out: refused "kind", nothing marked
	EliteNoKnockout = function(T)
		Kit.Guard(function()
			local Rig = Kit.Spawn("Elite", At(0, 0))
			Kit.PutBehind(Rig, 3)
			Calm()
			local Ok, Why = KnockOut(Rig)
			T.Eq(Ok, false, "refused")
			T.Eq(Why, "kind", "the reason")
			T.Eq(Result(), "Knockout:kind", "LastTakedownResult")
			T.Eq(Rig:GetAttribute("TakenDownBy"), nil, "the Elite isn't marked")
			T.Eq(C:GetAttribute("TakingDown"), nil, "the player isn't marked")
		end)
	end,
	-- (spec §8) a trial boss (Boss and TrialFoe, perception doesn't track it) is immune; it is removed after
	BossImmune = function(T)
		local Rig
		Kit.Guard(function()
			local Def = require(game.ReplicatedStorage.Modules.Data.Rensei.TuningConfig).Enemies.TrialFlame
			T.True(Def ~= nil and Def.Boss == true and Def.TrialFoe == true, "setup: TrialFlame is a trial boss")
			Rig = Kit.Spawn("TrialFlame", At(0, 0))
			T.Eq(PS.Tracks(Rig), false, "setup: perception doesn't track it")
			Kit.PutBehind(Rig, 3)
			Calm()
			Refused(T, Rig, "immune", "a trial boss")
		end)
		T.True(Rig == nil or Rig.Parent == nil, "the boss is removed after")
	end,
	-- (spec §8) the TakedownClass attribute beats the type: a Grunt marked Immune is refused, one marked Chunk backstabbed
	ClassOverride = function(T)
		Kit.Guard(function()
			local Rig = Behind()
			Rig:SetAttribute("TakedownClass", "Immune")
			Refused(T, Rig, "immune", "a Grunt with TakedownClass Immune")
		end)
		Kit.Guard(function()
			local Rig = Behind()
			Rig:SetAttribute("TakedownClass", "Chunk")
			local H = Rig.Humanoid
			local Started, Why = Assassinate(Rig)
			T.Eq(Started, true, "a Grunt with TakedownClass Chunk: started (" .. tostring(Why) .. ")")
			T.True(Finished(2), "ended")
			T.Eq(Result(), "Assassinate:backstab", "a backstab")
			T.Near(H.Health, H.MaxHealth * 0.55, 1, "45% of its max health gone")
		end)
	end,
	-- PvE (spec §3): a real townsperson of this place, the nearest standing still at its post, read only (never moved or
	-- hurt), with the player 3 studs behind it: refused "townsfolk", its health, state and place unchanged. (With the
	-- player near, an Asleep one wakes to AtPost by itself at its next Step: the case waits for that before it reads.)
	TownsfolkRefused = function(T)
		local Folk = NearestTownsperson()
		T.True(Folk ~= nil, "a townsperson at its post in this place")
		if not Folk then return end
		Kit.Guard(function()
			local H = Folk:FindFirstChildOfClass("Humanoid")
			Kit.PutBehind(Folk, 3)
			Calm()
			T.True(WaitFor(3, function() return Folk:GetAttribute("TownsfolkState") == "AtPost" end),
				"setup: at its post with the player near (" .. tostring(Folk:GetAttribute("TownsfolkState")) .. ")")
			local Health, State, Where = H.Health, Folk:GetAttribute("TownsfolkState"), Folk.HumanoidRootPart.Position
			Refused(T, Folk, "townsfolk", "a townsperson")
			task.wait(0.2)
			T.Eq(H.Health, Health, "its health unchanged")
			T.Eq(Folk:GetAttribute("TownsfolkState"), State, "its state unchanged")
			T.True((Folk.HumanoidRootPart.Position - Where).Magnitude < 0.1, "not moved")
			T.Eq(Folk:GetAttribute("DamageTakenMult"), nil, "no protection written on it")
		end)
	end,
	-- (spec §13) a Done listener added by the case sees ("Assassinate", Player, Rig) once; it is removed after
	DoneHook = function(T)
		local S = Service()
		local N0 = #S.Done
		Kit.Guard(function() Hooks(function(Got)
			local Rig = Behind()
			T.Eq(Assassinate(Rig), true, "started")
			T.True(Finished(), "ended")
			task.wait(0.1)
			T.Eq(#Got.Done, 1, "Done once")
			local D = Got.Done[1]
			T.True(D ~= nil and D.Kind == "Assassinate" and D.P == Player and D.R == Rig, 'Done("Assassinate", Player, Rig)')
			T.Eq(#Got.Failed, 0, "no Failed")
		end) end)
		T.Eq(#S.Done, N0, "the listener is removed")
	end,
	-- (spec §18.2, pre-flight R10 / R11) a townsperson of the case's own facing the takedown flees (TownsfolkService.Startle;
	-- no shelter within 150 studs up here, so it curls up where it stands: Sheltering) and reports it: the deed's witnesses
	-- include it with a strength of at least 1, and a rumour of the deed starts. One facing away sees nothing and stays at
	-- its post. (The save's rumours are emptied for the case and put back after, so an older one can't stand in.)
	TownsfolkWitnessFlees = function(T)
		local TS = require(SSS.TownsfolkService)
		local MS = require(SSS.MoralityService)
		local Morality = Progression.GetData(Player).Morality
		local Rumours = Morality.Rumours
		local Got = {}
		local function L(P, DeedId, _, Info) if P == Player then table.insert(Got, {Deed = DeedId, Info = Info}) end end
		table.insert(MS.Recorded, L)
		Morality.Rumours = {}
		local Ok, Err = pcall(Kit.Guard, function()
			Deed("assassinated_bandit")
			local Rig = Kit.Spawn("Grunt", At(0, 0))
			Kit.PutBehind(Rig, 3) -- (first: with no player near, a townsperson is held Asleep)
			Calm()
			local SawId, Saw = Kit.Folk("Saw", Facing(8, 3, Vector3.new(-1, 0, 0))) -- 8 studs off the player, facing them
			local AwayId, Away = Kit.Folk("Away", Facing(-8, 3, Vector3.new(-1, 0, 0))) -- 8 studs off, its back to them
			T.True(PS.Tracks(Saw) and PS.Tracks(Away), "setup: perception tracks both as watchers")
			T.True(WaitFor(3, function() return TS.State(SawId) == "AtPost" and TS.State(AwayId) == "AtPost" end),
				("setup: both calm at their posts (%s, %s)"):format(tostring(TS.State(SawId)), tostring(TS.State(AwayId))))
			T.Eq(Assassinate(Rig), true, "started")
			T.True(Finished(), "ended")
			T.Eq(Result(), "Assassinate:ok")
			T.True(WaitFor(1, function()
				local St = TS.State(SawId)
				return St == "Fleeing" or St == "Sheltering"
			end), "the witness flees (" .. tostring(TS.State(SawId)) .. ")")
			T.Eq(TS.State(AwayId), "AtPost", "the one facing away stays at its post")
			task.wait(0.3)
			local Rec = nil
			for _, X in ipairs(Got) do if X.Deed == "assassinated_bandit" then Rec = X end end
			T.True(Rec ~= nil, "the deed was recorded")
			local Npcs = Rec and Rec.Info.Witnesses and Rec.Info.Witnesses.Npcs or {}
			T.True(Has(Npcs, Saw), "the witness is among the deed's witnesses")
			T.Eq(Has(Npcs, Away), false, "the one facing away isn't")
			T.True((Rec and Rec.Info.Strength or 0) >= 1, "witness strength at least 1")
			local Rumour = nil
			for _, R in ipairs(Morality.Rumours or {}) do if R.Deed == "assassinated_bandit" then Rumour = R end end
			T.True(Rumour ~= nil, "a rumour of the deed started")
			T.Eq(TS.State(SawId), "Sheltering", "still hiding (no shelter up here: curled up where it stood)")
		end)
		local I = table.find(MS.Recorded, L)
		if I then table.remove(MS.Recorded, I) end
		Morality.Rumours = Rumours
		if not Ok then error(Err, 0) end
	end,
}

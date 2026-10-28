-- Play_TakedownClasses (assassinations Task 9, 2026-10-27; split out of Play_Takedown in Task 9's fix round 1, the cases
-- unchanged but for the review's minors): takedowns by target class, inside the game VM (LMRunSuite), on TakedownKit's
-- floor with rigs and townsfolk the cases spawned themselves (a real townsperson only read, never moved or hurt).
-- Spec §8 / §13 / §18.2: an Elite's backstab (a Chunk target: 45% of its max health through the normal hit path, a Hit
-- sound, Alert, a stun, Failed "survived"); no knockout of an Elite; a trial boss immune; TakedownClass overriding the
-- type; a real townsperson refused; the Done hook; a townsperson who sees a takedown flees and reports it (pre-flight
-- R10 / R11: the deed's witnesses, a rumour). Fix round 1 (ruling, owner: bodies easy to spot): a backstab that kills
-- leaves a takedown's body (120 s, a registered Dead body, Done); one that knocks an Elite fires Done and leaves none.
local SSS = game.ServerScriptService
local DM = require(game.ReplicatedStorage.Modules.Managers.DownedManager)
local PS = require(SSS.PerceptionService)
local WorldClock = require(SSS.WorldClock)
local Kit = require(script.Parent.TakedownKit)
local Modules = game.ReplicatedStorage.Modules
local WCS = require(Modules.Framework.WCS)
local Stun = require(Modules.Skills.States.Stun)
local NS = require(SSS.NoiseService)
local Progression = require(SSS.ProgressionService)
local Player = Kit.Player()
local C = Player.Character

local At, AtHour, WaitFor, Service, Result, Calm = Kit.At, Kit.AtHour, Kit.WaitFor, Kit.Service, Kit.Result, Kit.Calm
local Assassinate, KnockOut, Finished, Behind, Deed = Kit.Assassinate, Kit.KnockOut, Kit.Finished, Kit.Behind, Kit.Deed
local Has, Refused, DeedsKey = Kit.Has, Kit.Refused, Kit.DeedsKey

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
			local Hit = os.clock()
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
			task.wait(math.max(0, Hit + 1.0 - os.clock()))
			T.True(HasStun(Rig), "still stunned 1.0 s after the hit (ChunkStun 1.2 s)")
			T.True(WaitFor(1, function() return not HasStun(Rig) end), "the stun ends (ChunkStun 1.2 s)")
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
	-- player near, an Asleep one wakes to AtPost by itself at its next Step: the case waits for that before it reads.
	-- The clock is held at the hour it is for the case, so no schedule moves it on meanwhile.)
	TownsfolkRefused = function(T)
		local Folk = NearestTownsperson()
		T.True(Folk ~= nil, "a townsperson at its post in this place")
		if not Folk then return end
		Kit.Guard(function() AtHour(WorldClock.Now(), function()
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
		end) end)
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
			T.Eq(Result(), "Assassinate:ok", "the assassination finished")
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

	-- ===== fix round 1 (ruling: the owner wants bodies easy to spot) =====
	-- a backstab that kills leaves a takedown's body: a Chunk rig that can't be knocked at 40% of its health dies of the
	-- 45%; its corpse is still there 6 s later (Takedown.BodySeconds, not the 4 s of a plain kill), ragdolled, registered
	-- as a Dead body by the player, and Done("Assassinate", Player, Rig) fires (no Failed). (Every enemy type today is
	-- knocked at 0 -- EnemyService sets Knockable unless its definition opts out, as only the sparring dummy does -- so the
	-- rig is a Grunt marked Chunk with Knockable = false: a stand-in for a type that opts out.)
	BackstabKillLeavesBody = function(T)
		Kit.Guard(function() Hooks(function(Got)
			local Rig = Behind()
			Rig:SetAttribute("TakedownClass", "Chunk")
			Rig:SetAttribute("Knockable", false)
			local H = Rig.Humanoid
			T.Eq(DM.Knockable(Rig), false, "setup: it can't be knocked")
			H.Health = H.MaxHealth * 0.4
			local Started, Why = Assassinate(Rig)
			T.Eq(Started, true, "started (" .. tostring(Why) .. ")")
			T.True(Finished(2), "ended")
			T.Eq(Result(), "Assassinate:backstab", "LastTakedownResult")
			T.True(H.Health <= 0, "the backstab killed it")
			task.wait(0.1)
			T.Eq(#Got.Done, 1, "Done once")
			local D = Got.Done[1]
			T.True(D ~= nil and D.Kind == "Assassinate" and D.P == Player and D.R == Rig, 'Done("Assassinate", Player, Rig)')
			T.Eq(#Got.Failed, 0, "no Failed")
			local Info = PS.Bodies[Rig]
			T.True(Info ~= nil and Info.Kind == "Dead" and Info.By == Player, "registered as a Dead body by the player")
			T.Eq(Rig:GetAttribute("Ragdolled"), true, "ragdolled, like a grip's or an assassination's body")
			task.wait(6)
			T.True(Rig.Parent ~= nil, "the corpse is still there 6 s later")
			T.True(PS.Bodies[Rig] ~= nil, "and still a body")
		end) end)
	end,
	-- the knocked variant: an Elite (knockable) at 40% is knocked by the 45%, not killed: Done fires (it didn't survive the
	-- backstab standing), it is no body, TakenDownBy is cleared, and it can be gripped like any knocked enemy
	BackstabKnocksElite = function(T)
		Kit.Guard(function() Hooks(function(Got)
			local Rig = Kit.Spawn("Elite", At(0, 0))
			Kit.PutBehind(Rig, 3)
			Calm()
			local H = Rig.Humanoid
			T.Eq(DM.Knockable(Rig), true, "setup: an Elite can be knocked")
			H.Health = H.MaxHealth * 0.4
			local Started, Why = Assassinate(Rig)
			T.Eq(Started, true, "started (" .. tostring(Why) .. ")")
			T.True(Finished(2), "ended")
			T.Eq(Result(), "Assassinate:backstab", "LastTakedownResult")
			T.True(H.Health > 0, "alive")
			T.Eq(DM.IsKnocked(Rig), true, "knocked")
			task.wait(0.1)
			T.Eq(#Got.Done, 1, "Done once")
			local D = Got.Done[1]
			T.True(D ~= nil and D.Kind == "Assassinate" and D.P == Player and D.R == Rig, 'Done("Assassinate", Player, Rig)')
			T.Eq(#Got.Failed, 0, "no Failed")
			T.Eq(PS.Bodies[Rig], nil, "not a body")
			T.Eq(Rig:GetAttribute("TakenDownBy"), nil, "TakenDownBy cleared")
		end) end)
	end,
}

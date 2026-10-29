-- Play_Hostage (hostages plan Task 5, 2026-10-27; Tasks 7-9 extend it): a hostage taken, held and let go. Run in the
-- game VM (LMRunSuite), every case inside HostageKit.Guard (the hook's snapshot armed AND DataManager.IsNoSave()), on
-- TakedownKit's floor, with stand-in players HostageKit makes (the stand-in seam). The real player is the captor unless
-- a case says otherwise. Every expected number is written by hand (Rensei.Hostage, Task 2: BindTime 1.5, BindRange 6 +
-- RangeSlack 1.5, MinHealthShare 0.15, MinLevel 5, MaxGap 15, ImmuneAfter 5, Offset 1.5 studs in front, HoldTime 180
-- halved per re-take).
-- * Task 5: the stand-in seam (closed outside TestNoSave, never an NPC); PvP only both ways (no NPC hostage or captor,
--   no stand-in taken down); the bind from knocked and its refusals; the one Release and every exit (leave, death,
--   timeout, safe zone, error, shutdown, a knocked captor or hostage); immunity and the re-take halving (pre-flight
--   P11, moved here from Task 7); the Task 4 review's hand-offs (HeldBy before EndKnock, a knock that ran out recovered
--   at release, the held pair untakeable).
-- * Task 5 fix round 1 (review I1, I2, K1, M2, M3, M8, M10): an exit before the weld leaves the hostage's parts as they
--   were (no Detach of a pair never attached); the bound target untakeable mid-bind, each refusal reached by the hostage
--   rule itself, with controls; hostages switched off (Rensei.Hostage.Enabled = false until Task 14): a live-shaped
--   request or take is refused, the test bypass closed by HostageService._TestBypass (a seam that can only make it
--   stricter). ReleaseErrorStillRestores warns twice by design ("Broken failed" and its own error text).
-- * Task 7: the stealth grab (a standing stand-in, the player behind it, TakedownKit.PutBehind), its struggle from 40%
--   and its 3 s window; the hostage's struggle (HostageService.Struggle: rate limit, stamina, drain, a break free);
--   re-takes counted only once Held (pre-flight P22); immunity refusing a grab too; the grab's refusals (seen, far, a
--   busy target); the hostage root's network owner given back after a grab became a hold (Task 6 re-review m3: Pair
--   is idempotent). Written by hand (Rensei.Hostage, PROPOSAL): GrabStart 0.4, GrabWindow 3 s, GrabRange 4 + RangeSlack
--   1.5, the rear arc 70 + 10 degrees, ShoveStun 1 s, BreakStun 1.5 s, StrugglePress 0.06 x clamp((1 + own Strength) /
--   (1 + captor's Strength), 0.5, 2) (the kit pins Strength 5 on both sides unless a case says: 5 vs 5 -> 0.06; 30 vs 5
--   or 5 vs 0 -> clamped to 2 -> 0.12), StruggleDrain 0.05 a second, StruggleStamina 4, MaxPressesPerSecond 8.
--   RefuseNotKnocked now puts the player in FRONT of the standing stand-in (TakedownKit.PutInFront): FRONT (the spot +3
--   Z, facing -Z) is BEHIND a stand-in at the spot, which also faces -Z. ImmuneAfterRelease and RetakeHalves (binds) are
--   regression guards: they pass on Task 5's code (pre-flight P11).
-- * Task 7 fix round 1 (review I1; spec §2, "a failed grab still counts as an assault"): every grab that ends without
--   becoming Held records attempted_hostage once (a blink, a knocked hostage, a shove); only the shove stuns; a grab
--   that became a hold never records it.
-- * Task 8: the captor menu (HostageService.MenuOptions / Menu): its shape and the Options on the captor's notifies;
--   Release (released_hostage; the ruling on spec §3: a witnessed take's Heat halved at a release unharmed, through
--   HeatService.Reduce, which HeatReduceOneJurisdiction checks on its own); Finish through the normal Grip (dead within
--   GripTime 2 + 1 s, killed_hostage), cancelled by a stun mid-grip, and refused to a stunned captor; only the captor of
--   a Held session chooses; a take a kit townsperson sees is witnessed (Strength > 0, a rumour). The witnessed cases
--   step perception themselves (TakedownKit.Run) and put the player's Heat back after (KeepHeat). Written by hand:
--   took_hostage's Crime 30 heard at once in Ye (net +15 after a release; 0 in the Foundry, see the case), GripTime
--   2 s, the option texts.
-- * Task 8 fix round 1 (rulings I1 / I2): a menu Release pays out (released_hostage, the Heat halved) only after the
--   release window (HostageService._ReleaseGrace shortens it here; Kit.Clean drops any window left): release then the
--   ex-captor's knocking hit then B inside it is a kill (killed_hostage, no Mercy, no halving); a third party's hit
--   changes nothing; the ex-captor's party counts as the ex-captor. Finish is refused mid-attack, and a grip that
--   fails at once gives the knock back. A "hit" is DownedManager.Damage then ProgressionService.RecordHit (KnockingHit),
--   the pipeline's own two steps.
-- * Task 8 fix round 2 (ruling on review m2): a stun-cancelled Finish opens the same window, paying nothing; the
--   captor's own grip that kills the still-knocked hostage inside it is killed_hostage, once.
-- * Task 8 fix round 3 (re-review N1): a harmed window whose hostage is still knocked at its end stays open until the
--   knock ends, so a late knock finished after the window is still killed_hostage; _PendingCount checks nothing is left.
-- * Task 9: the human shield and the rescue. The attacker is a SECOND stand-in (a third "player"), so CombatDirector's
--   token gate on enemy hits never drops a hit before the redirect. A hit is the melee pipeline's own two steps, in its
--   order (HitboxManager.Hitbox / Sweep, AlchemyService): the DamageManager function, then ProgressionService.RecordHit
--   with its result (Hit, below). Written by hand: ShieldArc 70 degrees either side of the captor's front (60 in it, 90
--   out), a 10-damage hit with no stun, the attacker 4 studs from the captor's root. A front hit lands on the hostage
--   (used_human_shield once per hold); a rear or side hit, or a parry of the captor's attack, frees the hostage
--   ("rescued" / "parried"); a guard (an NPC of a State or Militia law faction, PROPOSAL) that rescues records the taking
--   again, witnessed; an NPC in front holds its attack (CombatDirector.CanStrike, HostageService.LineBlocked);
--   a lethal front hit knocks the hostage and ends the hold "knocked" (decision 5). HostageNotShieldedFromCaptor is a
--   regression guard: the hostage never has Holding, so the redirect can't be reached by construction (pre-flight D5).
local SSS = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local DM = require(game.ReplicatedStorage.Modules.Managers.DownedManager)
local TK = require(script.Parent.TakedownKit)
local SmokeKit = require(script.Parent.SmokeKit)
local HK = require(script.Parent.HostageKit)
local Player = TK.Player()
local C = Player.Character

local At, WaitFor = TK.At, TK.WaitFor
local FRONT = At(0, 3) + Vector3.new(0, 3, 0) -- the player 3 studs from the spot, facing it (-Z)
local OFFSET = CFrame.new(0, 0, -1.5) -- written by hand: the hostage's root 1.5 studs in front of the captor's

local function Svc()
	local M = SSS:FindFirstChild("HostageService")
	assert(M, "HostageService exists")
	return require(M)
end
local function Now() return workspace:GetServerTimeNow() end
local function Weld() return C.HumanoidRootPart:FindFirstChild("DownedWeld") end
-- a stand-in at (X, Z), knocked (Seconds: the knock's length, else KnockedTime's)
local function KnockedStandIn(X, Z, Opts, Seconds)
	local Rig, PL = HK.StandIn(At(X, Z), Opts)
	DM.Knock(Rig, Seconds)
	return Rig, PL
end
-- a knocked stand-in at the spot and the player 3 studs in front of it; the take started
local function Bind(T, Opts, Seconds)
	local Rig, PL = KnockedStandIn(0, 0, Opts, Seconds)
	TK.PutPlayer(FRONT)
	T.True(DM.IsKnocked(Rig), "setup: the stand-in is knocked")
	local Ok, Why = Svc().Take(Player, Rig)
	T.Eq(Ok, true, "setup: the take starts (" .. tostring(Why) .. ")")
	return Rig, PL
end
local function IsHeld()
	local S = Svc().SessionOf(Player)
	return S ~= nil and S.State == "Held"
end
-- Bind, then Held within BindTime + 0.5 s
local function Held(T, Opts)
	local Rig, PL = Bind(T, Opts)
	T.True(WaitFor(2.0, IsHeld), "setup: Held within 2 s")
	return Rig, PL, Svc().SessionOf(Player)
end
local function Ended(Want, Max)
	return WaitFor(Max or 0.3, function() return HK.Result() == Want end)
end
-- an invisible, non-solid 20 x 10 x 20 part around the pair, tagged RenseiSafeZone (pre-flight P20); SmokeKit removes it
local function SafeZone()
	local P = SmokeKit.TempPart({Name = "Hostage_SafeZone", Size = Vector3.new(20, 10, 20), CFrame = At(0, 1.5) + Vector3.new(0, 3, 0),
		CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1})
	CollectionService:AddTag(P, "RenseiSafeZone")
	return P
end
-- (Task 7) a deed's lifetime count on the player's (mock) profile, 0 when never recorded
local function DeedCount(Id)
	local M = require(SSS.ProgressionService).GetData(Player).Morality
	local E = M and M.Deeds[Id]
	return E and E.Count or 0
end
-- (Task 7) a WCS Stun on the character, not the crouch's (TakedownService.Stunned, called, never copied)
local function Stunned(Character) return require(SSS.TakedownService).Stunned(Character) end
-- (Task 7) seconds from now until that Stun is over, polled every frame (at most Max): a stun's length measured, so a
-- slow frame can't fail a fixed wait
local function StunLeft(Character, Max)
	local T0 = os.clock()
	while Stunned(Character) and os.clock() - T0 < Max do task.wait() end
	return os.clock() - T0
end
local function RM() return require(game.ReplicatedStorage.Modules.Managers.ResourceManager) end
local function FullStamina(Character) RM().Set(Character, "Stamina", RM().Max(Character, "Stamina")) end
-- (Task 7) the real player as the HOSTAGE: knocked at the spot, a stand-in captor 3 studs off (facing it) binds them,
-- Held within 2 s. The player's root stays anchored (PutPlayer), and the stand-in captor's root is anchored once the
-- take has started: a rig just let go still settles (measured up to 0.85 studs, near the bind's 1-stud slack), which
-- interrupted the bind in two of the first GREEN run's cases.
local function Captive(T, Opts)
	local Cap, CapPL = HK.StandIn(At(0, 3), Opts) -- (facing -Z: the player at the spot is 3 studs in front of it)
	TK.PutPlayer(At(0, 0) + Vector3.new(0, 3, 0))
	T.True(HK.KnockPlayer(), "setup: the player is knocked")
	local Ok, Why = Svc().Take(CapPL, C)
	Cap.HumanoidRootPart.Anchored = true
	T.Eq(Ok, true, "setup: the stand-in's take starts (" .. tostring(Why) .. ")")
	T.True(WaitFor(2.0, function()
		local S = Svc().SessionOf(Player)
		return S ~= nil and S.State == "Held"
	end), "setup: Held within 2 s (" .. tostring(HK.Result(Cap)) .. ")")
	return Cap, CapPL, Svc().SessionOf(Player)
end
-- a free pair: no weld, no hold marks, no lock entry on either (a stand-in still knocked keeps its knock's own lock)
local function AllLetGo(T, Rig, What)
	T.Eq(Weld(), nil, What .. ": no weld on the player's root")
	T.Eq(C:GetAttribute("Holding"), nil, What .. ": the player's Holding cleared")
	T.Eq(Rig:GetAttribute("HeldBy"), nil, What .. ": the stand-in's HeldBy cleared")
	T.Eq(DM.IsLocked(C), false, What .. ": no lock entry on the player")
	if not DM.IsKnocked(Rig) then T.Eq(DM.IsLocked(Rig), false, What .. ": no lock entry on the stand-in") end
end

-- ===== Task 8 helpers =====
local function HeatSvc() return require(SSS.HeatService) end
local function Copy(X)
	if type(X) ~= "table" then return X end
	local O = {}
	for K, V in pairs(X) do O[K] = Copy(V) end
	return O
end
-- Body run with the player's Heat (the mock save's Morality.Heat) put back after it, failed or not, so a case that
-- raises Heat leaves none for the cases and suites after it (the hook restores the whole save at the end anyway)
local function KeepHeat(Body)
	local M = require(SSS.ProgressionService).GetData(Player).Morality
	local Was = Copy(M.Heat)
	local Ok, Err = pcall(Body)
	M.Heat = Was
	pcall(HeatSvc().Publish, Player, true)
	if not Ok then error(Err, 0) end
end
local function Ids(Options)
	local Out = {}
	for _, O in ipairs(Options or {}) do table.insert(Out, O.Id) end
	return Out
end
local function StunPlayer(Seconds)
	local WCS = require(game.ReplicatedStorage.Modules.Framework.WCS)
	local Stun = require(game.ReplicatedStorage.Modules.Skills.States.Stun)
	Stun.new(WCS.Character.GetCharacterFromInstance(C)):Start(Seconds)
end
-- a take a townsperson sees (the brief's TakeIsWitnessed setup): a knocked stand-in at the spot and the player 3 studs in
-- front of it (placed first: with no player near, a townsperson is held Asleep), a kit townsperson (TakedownKit.Folk) 10
-- studs off facing the pair, at noon; perception stepped (TakedownKit.Run: the kit holds PerceptionService's own loop)
-- before the take and through the bind; Held. Body(Rig, PL, Got, Morality, Heat0) runs inside HostageKit.Guard and
-- KeepHeat: Got lists what MoralityService.Recorded saw for the player (a listener added here, removed after), the save's
-- rumours are emptied for the case and put back after (an older rumour can't stand in), and Heat0 is the player's
-- Heat in this place's jurisdiction (TakedownKit.LAW) just before the take.
local function Witnessed(T, Body, Opts)
	local MS = require(SSS.MoralityService)
	local TS = require(SSS.TownsfolkService)
	local Morality = require(SSS.ProgressionService).GetData(Player).Morality
	local Rumours = Morality.Rumours
	local Got = {}
	local function L(P, Id, _, Info) if P == Player then table.insert(Got, {Deed = Id, Info = Info}) end end
	table.insert(MS.Recorded, L)
	Morality.Rumours = {}
	local Ok, Err = pcall(HK.Guard, function() KeepHeat(function() TK.AtHour(12, function()
		local Rig, PL = KnockedStandIn(0, 0)
		TK.PutPlayer(FRONT)
		local Pos = At(10, 1.5).Position
		local Id = TK.Folk("Saw", CFrame.lookAt(Pos, At(0, 1.5).Position))
		T.True(WaitFor(3, function() return TS.State(Id) == "AtPost" end),
			"setup: the townsperson is calm at its post (" .. tostring(TS.State(Id)) .. ")")
		TK.Run(1)
		-- (fix round 1, review m1) Heat already there before the take, so a halving of all Heat can't pass for half the take's
		if Opts and Opts.Seed then HeatSvc().Add(Player, TK.LAW.J, Opts.Seed) end
		local Heat0 = HeatSvc().Value(Player, TK.LAW.J)
		T.Eq(Svc().Take(Player, Rig), true, "setup: the take starts")
		local T0 = os.clock()
		while not IsHeld() and os.clock() - T0 < 2.5 do TK.Run(0.2) task.wait(0.1) end
		T.True(IsHeld(), "setup: Held (" .. tostring(HK.Result()) .. ")")
		task.wait(0.3) -- (the Recorded listeners run in their own threads)
		Body(Rig, PL, Got, Morality, Heat0)
	end) end) end)
	local I = table.find(MS.Recorded, L)
	if I then table.remove(MS.Recorded, I) end
	Morality.Rumours = Rumours
	if not Ok then error(Err, 0) end
end
-- (fix round 1) Body with HostageService's release window shortened to Seconds (the _ReleaseGrace seam, read only while
-- the stand-in seam is open), put back after, failed or not
local function WithGrace(Seconds, Body)
	local HS = Svc()
	HS._ReleaseGrace = Seconds
	local Ok, Err = pcall(Body)
	HS._ReleaseGrace = nil
	if not Ok then error(Err, 0) end
end
-- (fix round 1) Body with Module[Field] swapped for Fn, put back after, failed or not
local function Swap(Module, Field, Fn, Body)
	local Real = Module[Field]
	Module[Field] = Fn
	local Ok, Err = pcall(Body, Real)
	Module[Field] = Real
	if not Ok then error(Err, 0) end
end
-- (fix round 1) the combat pipeline's landed hit on Victim by Attacker that knocks it: DownedManager.Damage of all its
-- health (a knockable rig is knocked at 1 HP), then ProgressionService.RecordHit's listeners with "Hit", as DamageManager
-- and the hitbox do for a real swing
local function KnockingHit(Attacker, Victim)
	DM.Damage(Victim, Victim.Humanoid.Health)
	require(SSS.ProgressionService).RecordHit(Attacker, Victim, "Hit")
end
local function Find(Got, Deed)
	local Rec = nil
	for _, X in ipairs(Got) do if X.Deed == Deed then Rec = X end end
	return Rec
end

-- ===== Task 9 helpers =====
local function Ten() return {Damage = 10, StunTime = 0} end -- (written by hand: 10 damage, no hitstun on anyone)
-- a hit as the melee pipeline lands it (HitboxManager.Hitbox / Sweep): the DamageManager function first, then
-- ProgressionService.RecordHit with its result, so the HitListeners see the hit after it landed. Returns the result.
local function Hit(Attacker, Victim, Info)
	local Result = require(game.ReplicatedStorage.Modules.Managers.DamageManager)(Attacker, Victim, Info or Ten())
	require(SSS.ProgressionService).RecordHit(Attacker, Victim, Result)
	return Result
end
-- where a rig's root goes: Dist studs from the player's root, Angle degrees round from the player's front (0 in front,
-- 90 its side, 180 behind), facing the player
local function AroundPlayer(Angle, Dist)
	local CR = C.HumanoidRootPart
	local Look = Vector3.new(CR.CFrame.LookVector.X, 0, CR.CFrame.LookVector.Z).Unit
	local Pos = CR.Position + CFrame.fromAxisAngle(Vector3.yAxis, math.rad(Angle)):VectorToWorldSpace(Look) * Dist
	return CFrame.lookAt(Pos, Vector3.new(CR.Position.X, Pos.Y, CR.Position.Z))
end
-- a second stand-in (a third "player") as the attacker, placed by AroundPlayer, its root anchored there
local function Attacker(Angle, Dist)
	local Where = AroundPlayer(Angle, Dist)
	local Rig = HK.StandIn(Where - Vector3.new(0, 3, 0))
	Rig.HumanoidRootPart.Anchored = true
	Rig:PivotTo(Where)
	return Rig
end
-- a kit Grunt taken out of the squads (CombatDirector.Unregister: Holds is unrestricted for it), placed by AroundPlayer
local function LoneGrunt(Angle, Dist)
	local Grunt = TK.Spawn("Grunt", At(30, 0))
	require(SSS.CombatDirector).Unregister(Grunt)
	Grunt:PivotTo(AroundPlayer(Angle, Dist))
	return Grunt
end
-- the player's hitstun, if a case's hit gave one, waited out so the next case doesn't start stunned
local function Unstunned() WaitFor(2, function() return not Stunned(C) end) end

return {
	-- the seam is shut when the no-save switch isn't on (HostageService._NoSave swapped, pre-flight P24; put back after)
	SeamClosedOutsideNoSave = function(T)
		HK.Guard(function()
			local Rig, PL = HK.StandIn(At(0, 0))
			local Bare = game:GetService("StarterPlayer").StarterCharacter:Clone()
			local HS = Svc()
			local Real = HS._NoSave
			HS._NoSave = function() return false end
			local Ok, Err = pcall(function()
				local Got, Why = HS.StandIn(Bare, {Name = "Bare", UserId = -1})
				T.Eq(Got, nil, "StandIn refused")
				T.Eq(Why, "seam closed", "the reason")
				T.Eq(HS.PlayerOf(Rig), nil, "a registered stand-in isn't a player while the seam is shut")
				local TakeOk, TakeWhy = HS.Take(PL, C)
				T.Eq(TakeOk, false, "a stand-in can't take while the seam is shut")
				T.Eq(TakeWhy, "not_player", "the reason")
			end)
			HS._NoSave = Real
			Bare:Destroy()
			if not Ok then error(Err, 0) end
			T.Eq(HS.PlayerOf(Rig), PL, "control: the seam open again, the stand-in is a player-like")
		end)
	end,

	-- PvP: no NPC is a stand-in, a player-like, a hostage or a captor (Task 4 review hand-off 5; P25: DialogueId)
	NpcNeverAHostage = function(T)
		HK.Guard(function()
			local HS = Svc()
			local Grunt = TK.Free(TK.Spawn("Grunt", At(0, 0)))
			DM.Knock(Grunt)
			TK.PutPlayer(FRONT)
			T.True(DM.IsKnocked(Grunt), "setup: a knocked Grunt in front of the player")
			T.Eq(HS.StandIn(Grunt, {}), nil, "a Grunt is never a stand-in")
			T.Eq(HS.PlayerOf(Grunt), nil, "nor a player-like")
			local Ok, Why = HS.Take(Player, Grunt)
			T.Eq(Ok, false, "taking the Grunt is refused")
			T.Eq(Why, "not_player", "the reason")
			T.Eq(HK.Result(), "Bind:not_player", "LastHostageResult")
			T.Eq(Grunt:GetAttribute("HeldBy"), nil, "the Grunt isn't marked")
			T.Eq(C:GetAttribute("Holding"), nil, "the player isn't marked")
			-- (Task 7; a guard: the NPC rule comes before the grab's own gates) a standing Grunt with the player behind it
			local Standing = TK.Spawn("Grunt", At(-6, 0))
			TK.PutBehind(Standing, 3)
			HS.Forget(Player, {NextAt = true})
			Ok, Why = HS.Take(Player, Standing)
			T.Eq(Ok, false, "grabbing a standing Grunt from behind is refused")
			T.Eq(Why, "not_player", "the reason")
			T.Eq(HK.Result(), "Grab:not_player", "LastHostageResult")
			T.Eq(Standing:GetAttribute("HeldBy"), nil, "the standing Grunt isn't marked")
			TK.PutPlayer(FRONT)
			-- an NPC as the captor: a player-like it would have to be, and it never is
			local Rig = KnockedStandIn(0, -3)
			local Fake = {IsStandIn = true, Character = Grunt, Name = Grunt.Name, DisplayName = Grunt.Name, UserId = -999,
				Level = 20, Data = {Stats = {}}}
			Ok, Why = HS.Take(Fake, Rig)
			T.Eq(Ok, false, "an NPC captor is refused")
			T.Eq(Why, "not_player", "the reason")
			T.Eq(Rig:GetAttribute("HeldBy"), nil, "the stand-in isn't marked")
			T.Eq(Grunt:GetAttribute("Holding"), nil, "the Grunt isn't marked")
			-- (review M2) a registered stand-in whose rig carries an NPC's mark is no captor (Take's own IsNpc check)
			local Turned, TurnedPL = HK.StandIn(At(3, 0))
			Turned:SetAttribute("EnemyType", "Grunt")
			T.Eq(HS.PlayerOf(Turned), nil, "a stand-in marked as an NPC is no player-like")
			Ok, Why = HS.Take(TurnedPL, Rig)
			T.Eq(Ok, false, "that captor is refused")
			T.Eq(Why, "not_player", "the reason")
			T.Eq(Rig:GetAttribute("HeldBy"), nil, "the stand-in isn't marked")
			Turned:SetAttribute("EnemyType", nil)
			-- rigs carrying an NPC's marks are refused by the seam
			for _, Mark in ipairs({"DialogueId", "TownsfolkId", "EnemyType"}) do
				local Bare = game:GetService("StarterPlayer").StarterCharacter:Clone()
				Bare:SetAttribute(Mark, "test")
				local Got, Not = HS.StandIn(Bare, {Name = "Bare", UserId = -2})
				Bare:Destroy()
				T.Eq(Got, nil, Mark .. ": refused as a stand-in")
				T.Eq(Not, "not a stand-in", Mark .. ": the reason")
			end
		end)
	end,

	-- PvE stays PvE: a stand-in player is never a takedown target
	StandInNeverATakedown = function(T)
		HK.Guard(function()
			local Rig = HK.StandIn(At(0, 0))
			TK.PutBehind(Rig, 3)
			TK.Calm()
			local Ok, Why = TK.Service().Request(Player, "Assassinate", Rig)
			T.Eq(Ok, false, "a takedown of a stand-in is refused")
			T.Eq(Why, "not_enemy", "the reason")
			T.Eq(Rig:GetAttribute("TakenDownBy"), nil, "the stand-in isn't marked")
		end)
	end,

	BindFromKnocked = function(T)
		HK.Guard(function()
			local Rig = HK.StandIn(At(0, 0))
			Rig.Humanoid.Health = 5 -- (review M8: below the 15% floor, so the floor is what the check sees)
			DM.Knock(Rig)
			TK.PutPlayer(FRONT)
			T.True(DM.IsKnocked(Rig), "setup: the stand-in is knocked")
			T.Eq(Svc().Take(Player, Rig), true, "setup: the take starts")
			T.True(WaitFor(2.0, function() return not DM.IsKnocked(Rig) and Weld() ~= nil end), "bound within BindTime + 0.5 s")
			T.Eq(DM.IsKnocked(Rig), false, "the stand-in isn't knocked")
			T.Eq(Rig:GetAttribute("HeldBy"), Player.Name, "HeldBy = the player")
			T.Eq(C:GetAttribute("Holding"), Rig.Name, "Holding = the stand-in")
			local H = Rig.Humanoid
			T.Near(H.Health, H.MaxHealth * 0.15, 0.5, "5 HP raised to the 15% floor (" .. H.Health .. ")")
			T.Eq(Weld().Part1, Rig.HumanoidRootPart, "DownedWeld on the player's root holds the stand-in")
			T.Eq(HK.Result(), nil, "no LastHostageResult yet")
			local Want = (C.HumanoidRootPart.CFrame * OFFSET).Position
			T.True((Rig.HumanoidRootPart.Position - Want).Magnitude <= 1.5, "the stand-in is in front of the player")
			T.True(IsHeld(), "the session is Held")
		end)
	end,

	-- (hand-off 1) HeldBy is set at the take, before EndKnock: a knock that runs out mid-bind isn't healed by Recover
	BindExpiredKnockNoHeal = function(T)
		HK.Guard(function()
			local Rig = HK.StandIn(At(0, 0))
			Rig:SetAttribute("RecoverHealth", 0.9)
			Rig.Humanoid.Health = 10
			DM.Knock(Rig, 0.5)
			TK.PutPlayer(FRONT)
			T.True(DM.IsKnocked(Rig), "setup: knocked for 0.5 s")
			T.Eq(Svc().Take(Player, Rig), true, "setup: the take starts")
			task.wait(0.8)
			T.True(DM.IsKnocked(Rig), "the knock's timer waited for the bind")
			T.True(WaitFor(1.5, IsHeld), "Held")
			T.Near(Rig.Humanoid.Health, 15, 1, "bound at 15% (MinHealthShare), not Recover's 90%")
		end)
	end,

	-- a standing target is a grab, and one the player stands in front of has seen them (Task 7: was "todo")
	RefuseNotKnocked = function(T)
		HK.Guard(function()
			local Rig = HK.StandIn(At(0, 0))
			TK.PutInFront(Rig, 3)
			local Ok, Why = Svc().Take(Player, Rig)
			T.Eq(Ok, false, "refused")
			T.Eq(Why, "seen", "the reason")
			T.Eq(HK.Result(), "Grab:seen", "LastHostageResult")
			T.Eq(Rig:GetAttribute("HeldBy"), nil, "not marked")
		end)
	end,

	RefuseFar = function(T)
		HK.Guard(function()
			local Rig = KnockedStandIn(0, 0)
			TK.PutPlayer(At(0, 9) + Vector3.new(0, 3, 0))
			T.Eq(Svc().Take(Player, Rig), false, "refused at 9 studs")
			T.Eq(HK.Result(), "Bind:far", "LastHostageResult")
		end)
	end,

	-- the levels are each side's Data.Level (pre-flight P2): the kit pins the player's at 20
	RefuseLevels = function(T)
		HK.Guard(function()
			local Low = KnockedStandIn(0, 0, {Level = 4})
			TK.PutPlayer(FRONT)
			T.Eq(Svc().Take(Player, Low), false, "a level 4 target is refused")
			T.Eq(HK.Result(), "Bind:level_low", "LastHostageResult")
			local Rig = KnockedStandIn(2, 0, {Level = 20})
			require(SSS.ProgressionService).GetData(Player).Level = 35 -- (the kit puts it back)
			T.Eq(Svc().Take(Player, Rig), false, "a target 15 levels below is refused")
			T.Eq(HK.Result(), "Bind:level_gap", "LastHostageResult")
			require(SSS.ProgressionService).GetData(Player).Level = 34
			Svc().Forget(Player, {NextAt = true})
			T.Eq(Svc().Take(Player, Rig), true, "control: 14 levels below, started")
		end)
	end,

	RefuseSafe = function(T)
		HK.Guard(function()
			local Rig = KnockedStandIn(0, 0)
			TK.PutPlayer(FRONT)
			local Zone = SafeZone()
			T.Eq(Svc().Take(Player, Rig), false, "refused in a safe zone")
			T.Eq(HK.Result(), "Bind:safe", "LastHostageResult")
			T.Eq(Rig:GetAttribute("HeldBy"), nil, "not marked")
			CollectionService:RemoveTag(Zone, "RenseiSafeZone")
			Svc().Forget(Player, {NextAt = true})
			T.Eq(Svc().Take(Player, Rig), true, "control: the same part untagged, started")
		end)
	end,

	RefuseBusyTarget = function(T)
		HK.Guard(function()
			local Rig = KnockedStandIn(0, 0)
			Rig:SetAttribute("GrippedBy", "X")
			TK.PutPlayer(FRONT)
			T.Eq(Svc().Take(Player, Rig), false, "a gripped target is refused")
			T.Eq(HK.Result(), "Bind:target_busy", "LastHostageResult")
			T.Eq(Rig:GetAttribute("HeldBy"), nil, "not marked")
			Rig:SetAttribute("GrippedBy", nil)
		end)
	end,

	-- two takes of one knocked stand-in in the same frame (the player, then a second stand-in): only the first
	OneCaptorPerHostage = function(T)
		HK.Guard(function()
			local Other, OtherPL = HK.StandIn(At(0, -3))
			local Rig = KnockedStandIn(0, 0)
			TK.PutPlayer(FRONT)
			T.True(Svc().Check(OtherPL, Rig, "Bind"), "setup: the second captor could take it alone")
			local A, B = Svc().Take(Player, Rig), table.pack(Svc().Take(OtherPL, Rig))
			T.Eq(A, true, "the first take starts")
			T.Eq(B[1], false, "the second is refused")
			T.Eq(B[2], "target_busy", "the reason")
			T.Eq(Rig:GetAttribute("HeldBy"), Player.Name, "held by the first")
			T.Eq(Other:GetAttribute("Holding"), nil, "the second holds nothing")
		end)
	end,

	BindInterruptedByMove = function(T)
		HK.Guard(function()
			local Rig = KnockedStandIn(0, 0)
			-- (review I1) a part made massless before the take (hair, accessories, a weapon) stays massless when the bind
			-- ends before the weld: Release lets go only of a pair it attached
			local Part = Rig:FindFirstChild("Left Arm") or Rig:FindFirstChild("Head")
			Part.Massless = true
			TK.PutPlayer(FRONT)
			T.Eq(Svc().Take(Player, Rig), true, "setup: the take starts")
			task.wait(0.5)
			TK.PutPlayer(FRONT + Vector3.new(3, 0, 0))
			T.True(Ended("Bind:interrupted", 1.2), "interrupted (" .. tostring(HK.Result()) .. ")")
			T.True(DM.IsKnocked(Rig), "the stand-in is still knocked")
			AllLetGo(T, Rig, "interrupted")
			T.Eq(Part.Massless, true, "the stand-in's massless part is still massless")
			T.Eq(Rig.Humanoid.PlatformStand, false, "PlatformStand untouched")
		end)
	end,

	-- (hand-off 3) an interrupted bind whose knock ran out meanwhile recovers the hostage at once: never left stuck
	InterruptedBindRecovers = function(T)
		HK.Guard(function()
			local Rig = Bind(T, nil, 0.5)
			task.wait(0.8)
			T.True(DM.IsKnocked(Rig), "setup: the knock ran out and its timer waited for the bind")
			TK.PutPlayer(FRONT + Vector3.new(3, 0, 0))
			T.True(Ended("Bind:interrupted", 1.2), "interrupted (" .. tostring(HK.Result()) .. ")")
			T.True(WaitFor(0.3, function() return not DM.IsKnocked(Rig) end), "the stand-in recovered")
			AllLetGo(T, Rig, "recovered")
		end)
	end,

	ReleaseOnLeave = function(T)
		HK.Guard(function()
			local WS0 = C.Humanoid.WalkSpeed
			local Rig, PL = Held(T)
			Svc()._Left(PL)
			T.Eq(HK.Result(), "Bind:left", "LastHostageResult")
			AllLetGo(T, Rig, "left")
			T.Near(C.Humanoid.WalkSpeed, WS0, 0.01, "the player's walk is what it was before the bind")
		end)
	end,

	ReleaseOnDeath = function(T)
		HK.Guard(function()
			local Rig = Held(T)
			Rig.Humanoid.Health = 0
			T.True(Ended("Bind:died"), "died within 0.3 s (" .. tostring(HK.Result()) .. ")")
			AllLetGo(T, Rig, "died") -- (review M3: the captor's lock entry too)
		end)
	end,

	ReleaseOnTimeout = function(T)
		HK.Guard(function()
			local Rig, _, S = Held(T)
			S.Until = os.clock() + 0.5
			T.True(Ended("Bind:timeout", 1), "timeout within 1 s (" .. tostring(HK.Result()) .. ")")
			T.Near(Rig:GetAttribute("GrabImmuneUntil") or 0, Now() + 5, 0.6, "immune for 5 s")
			AllLetGo(T, Rig, "timeout")
		end)
	end,

	ReleaseOnSafeZone = function(T)
		HK.Guard(function()
			local Rig = Held(T)
			SafeZone()
			T.True(Ended("Bind:safe", 0.5), "safe within 0.5 s (" .. tostring(HK.Result()) .. ")")
			AllLetGo(T, Rig, "safe")
		end)
	end,

	-- the watch's Broken errors: the hold still ends through the one Release, and everything is given back
	ReleaseErrorStillRestores = function(T)
		HK.Guard(function()
			local Rig = Held(T)
			local HS = Svc()
			local Real = HS.Broken
			HS.Broken = function() error("Play_Hostage: Broken made to fail") end
			local Ok, Err = pcall(function()
				T.True(Ended("Bind:error"), "error within 0.3 s (" .. tostring(HK.Result()) .. ")")
			end)
			HS.Broken = Real
			if not Ok then error(Err, 0) end
			AllLetGo(T, Rig, "error")
		end)
	end,

	ShutdownReleases = function(T)
		HK.Guard(function()
			local Rig = Held(T)
			Svc()._Shutdown()
			T.Eq(HK.Result(), "Bind:shutdown", "LastHostageResult")
			AllLetGo(T, Rig, "shutdown")
		end)
	end,

	ReleaseOnce = function(T)
		HK.Guard(function()
			local HS = Svc()
			local Fired = 0
			local function Listener() Fired += 1 end
			table.insert(HS.Released, Listener)
			local Ok, Err = pcall(function()
				Held(T)
				T.Eq(HS.Free(Player, "a"), true, "the first Free releases")
				T.Eq(HS.Free(Player, "b"), false, "the second finds nothing")
			end)
			table.remove(HS.Released, table.find(HS.Released, Listener))
			if not Ok then error(Err, 0) end
			T.Eq(HK.Result(), "Bind:a", "the first outcome stands")
			T.Eq(Fired, 1, "Released fired once")
		end)
	end,

	-- (hand-off 4) the captor knocked mid-hold ends it; the knock's recovery gives the walk from before the bind back
	CaptorKnockedReleases = function(T)
		HK.Guard(function()
			local WS0 = C.Humanoid.WalkSpeed
			local Rig = Held(T)
			T.True(HK.KnockPlayer(), "setup: the player is knocked")
			T.True(Ended("Bind:knocked"), "knocked within 0.3 s (" .. tostring(HK.Result()) .. ")")
			T.Eq(Weld(), nil, "no weld")
			T.Eq(Rig:GetAttribute("HeldBy"), nil, "the stand-in is free")
			DM.Recover(C)
			T.Near(C.Humanoid.WalkSpeed, WS0, 0.01, "recovered: the walk from before the bind")
			T.Eq(DM.IsLocked(C), false, "no lock entry left")
		end)
	end,

	-- (decision 5) the hostage knocked while held ends it; the hostage stays knocked and its own timer recovers it
	HostageKnockedEnds = function(T)
		HK.Guard(function()
			local Rig = Held(T)
			DM.Knock(Rig, 1)
			T.True(Ended("Bind:knocked"), "knocked within 0.3 s (" .. tostring(HK.Result()) .. ")")
			T.Eq(Rig:GetAttribute("HeldBy"), nil, "HeldBy cleared")
			T.True(WaitFor(1.5, function() return not DM.IsKnocked(Rig) end), "the knock's own timer recovered it")
			T.Eq(DM.IsLocked(Rig), false, "no lock entry left")
		end)
	end,

	-- (hand-off 4; review I2) nobody grips, carries or takes down either side of a hostage hold. MID-BIND, where the
	-- hostage is knocked, unwelded and in reach, so the only gate refusing each one is the hostage rule (HeldBy on the
	-- target, Holding on the captor); each refusal has its control, passing without that attribute. Then, Held, the same
	-- refusals stay (a regression guard: the weld and the standing hostage refuse them as well).
	HeldPairNotTakeable = function(T)
		HK.Guard(function()
			local Grunt = TK.Spawn("Grunt", At(2.5, 1)) -- (standing, facing -Z: the player at FRONT is behind it, 3.2 studs)
			local Other = HK.StandIn(At(-3, 0)) -- a second "player", 3 studs from the hostage
			local Spare = KnockedStandIn(-2, 3) -- a knocked "player" nobody holds: the controls' target
			local Rig = KnockedStandIn(0, 0)
			TK.PutPlayer(FRONT)
			TK.Calm()
			T.Eq(TK.Service().Check(Player, Grunt, "Assassinate"), true, "setup: the player could take the Grunt down")
			T.Eq(Svc().Take(Player, Rig), true, "setup: the take starts")
			task.wait(0.3)
			local S = Svc().SessionOf(Player)
			T.True(S ~= nil and S.State == "Binding", "setup: mid-bind")
			T.True(DM.IsKnocked(Rig) and Weld() == nil, "setup: the hostage is knocked and not welded")
			-- the target side (HeldBy)
			T.Eq(DM.Grip(Other, Rig), false, "mid-bind: a grip of the hostage is refused")
			T.True(DM.Carry(Other, Rig) ~= true, "mid-bind: a carry of the hostage is refused")
			T.Eq(Rig:GetAttribute("GrippedBy"), nil, "the hostage isn't gripped")
			T.Eq(Rig:GetAttribute("CarriedBy"), nil, "nor carried")
			T.Eq(DM.Carry(Other, Spare), true, "control: the same carrier carries a knocked player nobody holds")
			DM.Drop(Other)
			-- the captor side (Holding)
			-- (the spare named, so only the captor's own state decides: Free refuses Holding)
			T.True(DM.Carry(C, Spare) ~= true, "mid-bind: the captor can't carry the knocked spare")
			T.Eq(C:GetAttribute("Carrying"), nil, "the captor isn't carrying")
			local Ok, Why = TK.Service().Check(Player, Grunt, "Assassinate")
			T.Eq(Ok, false, "mid-bind: the captor takes nobody down")
			T.Eq(Why, "busy", "the reason")
			C:SetAttribute("Holding", nil) -- (a pure check, nothing marked; put back at once)
			local Bare = TK.Service().Check(Player, Grunt, "Assassinate")
			C:SetAttribute("Holding", Rig.Name)
			T.Eq(Bare, true, "control: the same moment without Holding, the takedown is allowed")
			T.True(S.State == "Binding" and not S.Over, "all of it mid-bind")
			-- held: still refused (regression guard)
			T.True(WaitFor(2.0, IsHeld), "Held")
			T.Eq(DM.Grip(Other, Rig), false, "held: no grip of the hostage")
			T.True(DM.Carry(Other, Rig) ~= true, "held: no carry of the hostage")
			T.True(IsHeld(), "the hold is still on")
			-- the captor's controls, once the hold has ended
			Svc().Free(Player, "released")
			Rig:PivotTo(At(-20, -20) + Vector3.new(0, 3, 0)) -- (let go in front of the player, it would block the ray)
			local Again, AgainWhy = TK.Service().Check(Player, Grunt, "Assassinate")
			T.Eq(Again, true, "control: free again, the takedown would start (" .. tostring(AgainWhy) .. ")")
			T.Eq(DM.Carry(C, Spare), true, "control: free again, the captor carries the spare")
			DM.Drop(C)
		end)
	end,

	-- (review K1) hostages are switched off until Task 14 (Rensei.Hostage.Enabled = false, written by hand here). Only
	-- the test bypass (Studio AND TestNoSave AND HostageService._TestBypass) lets a take through; with the bypass shut, a
	-- live-shaped request and a direct Take are refused and nothing is marked. The control: the bypass open again.
	DisabledRefusesLiveCall = function(T)
		HK.Guard(function()
			local Hostage = require(game.ReplicatedStorage.Modules.Data.Rensei.Hostage)
			T.Eq(Hostage.Enabled, false, "setup: hostages are switched off")
			local Handler = SSS:FindFirstChild("ServerHandler")
			local Module = Handler and Handler:FindFirstChild("Requests") and Handler.Requests:FindFirstChild("Hostage")
			T.True(Module ~= nil, "setup: Requests.Hostage exists")
			local Request = require(Module)
			local Rig = KnockedStandIn(0, 0)
			TK.PutPlayer(FRONT)
			local HS = Svc()
			local Real = HS._TestBypass
			HS._TestBypass = function() return false end
			local Ok, Err = pcall(function()
				Request(Player, "Take", Rig)
				T.Eq(Svc().SessionOf(Player), nil, "a request while switched off starts nothing")
				T.Eq(Rig:GetAttribute("HeldBy"), nil, "the target isn't marked")
				local TakeOk, Why = HS.Take(Player, Rig)
				T.Eq(TakeOk, false, "a direct Take is refused too")
				T.Eq(Why, "disabled", "the reason")
				T.Eq(C:GetAttribute("Holding"), nil, "the player isn't marked")
			end)
			HS._TestBypass = Real
			if not Ok then error(Err, 0) end
			Request(Player, "Take", Rig)
			T.Eq(Rig:GetAttribute("HeldBy"), Player.Name, "control: the bypass open, the request takes")
		end)
	end,

	-- (pre-flight P11, from Task 7; a regression guard, it passes on Task 5's code) a released hostage is immune for
	-- ImmuneAfter
	ImmuneAfterRelease = function(T)
		HK.Guard(function()
			local Rig = Held(T)
			Svc().Free(Player, "released")
			Svc().Forget(Player, {NextAt = true})
			DM.Knock(Rig)
			T.Eq(Svc().Take(Player, Rig), false, "refused right after a release")
			T.Eq(HK.Result(), "Bind:immune", "LastHostageResult")
		end)
	end,

	-- (pre-flight P11 / P22, from Task 7; a regression guard, it passes on Task 5's code) each hold of the same hostage
	-- within 10 minutes halves the next
	RetakeHalves = function(T)
		HK.Guard(function()
			local Rig, PL = Held(T)
			T.Near(C:GetAttribute("HostageUntil") - Now(), 180, 1, "the first hold: 180 s")
			for _, Want in ipairs({90, 45}) do
				Svc().Free(Player, "released")
				Svc().Forget(PL, {ImmuneUntil = true})
				Svc().Forget(Player, {NextAt = true})
				TK.PutPlayer(FRONT)
				DM.Knock(Rig)
				T.Eq(Svc().Take(Player, Rig), true, "taken again")
				T.True(WaitFor(2.0, IsHeld), "Held again")
				T.Near(C:GetAttribute("HostageUntil") - Now(), Want, 1, "re-taken: " .. Want .. " s")
			end
		end)
	end,

	-- (Task 7) the stealth grab: welded at once with no bind time, the bar at 40% at once; with no presses, Held once the
	-- 3 s window is over, the bar reset, took_hostage recorded then (not at the grab)
	GrabFromBehind = function(T)
		HK.Guard(function()
			local Took0, Att0 = DeedCount("took_hostage"), DeedCount("attempted_hostage")
			local Rig = HK.StandIn(At(0, 0))
			TK.PutBehind(Rig, 3)
			local Ok, Why = Svc().Take(Player, Rig)
			T.Eq(Ok, true, "the grab starts (" .. tostring(Why) .. ")")
			T.Eq(Why, "started", "the reason")
			local S = Svc().SessionOf(Player)
			T.True(S ~= nil and S.State == "Grabbing", "Grabbing (" .. tostring(S and S.State) .. ")")
			T.Near(Rig:GetAttribute("Struggle") or -1, 0.4, 0.001, "the bar is at 40% at once")
			T.True(Weld() ~= nil and Weld().Part1 == Rig.HumanoidRootPart, "welded at once (no bind time)")
			T.Eq(Rig:GetAttribute("HeldBy"), Player.Name, "HeldBy = the player")
			T.Eq(DM.IsKnocked(Rig), false, "the stand-in was never knocked")
			T.Eq(DeedCount("took_hostage"), Took0, "no took_hostage while grabbing")
			task.wait(3.5)
			T.True(IsHeld(), "Held after GrabWindow + 0.5 s (" .. tostring(HK.Result()) .. ")")
			T.Eq(S.Struggle, 0, "the bar reset")
			T.Eq(Rig:GetAttribute("Struggle"), 0, "the Struggle attribute reset")
			T.Eq(DeedCount("took_hostage"), Took0 + 1, "took_hostage +1 once Held")
			T.Near((C:GetAttribute("HostageUntil") or 0) - Now(), 179.5, 1, "a 180 s hold, Held about 0.5 s ago")
			-- (fix round 1; a guard) a grab that became a hold is no failed grab, now or at its release
			T.Eq(DeedCount("attempted_hostage"), Att0, "Held: no attempted_hostage")
			T.Eq(Svc().Free(Player, "released"), true, "released")
			T.Eq(DeedCount("attempted_hostage"), Att0, "released after Held: still no attempted_hostage")
		end)
	end,

	-- (ruling R3) a grab needs the rear arc (70 + 10 degrees) within GrabRange 4 + 1.5: in front or at 90 degrees it is
	-- "seen", 6 studs straight behind it is "far"; the control, 3 studs straight behind, starts
	GrabSeen = function(T)
		HK.Guard(function()
			local HS = Svc()
			local Rig = HK.StandIn(At(0, 0))
			local Cases = {
				{"in front", function() TK.PutInFront(Rig, 3) end, "Grab:seen"},
				{"at 90 degrees", function() TK.PutBehind(Rig, 3, 90) end, "Grab:seen"},
				{"6 studs behind", function() TK.PutBehind(Rig, 6) end, "Grab:far"},
			}
			for _, Case in ipairs(Cases) do
				HS.Forget(Player, {NextAt = true})
				Case[2]()
				T.Eq(HS.Take(Player, Rig), false, Case[1] .. ": refused")
				T.Eq(HK.Result(), Case[3], Case[1] .. ": LastHostageResult")
				T.Eq(Rig:GetAttribute("HeldBy"), nil, Case[1] .. ": not marked")
			end
			HS.Forget(Player, {NextAt = true})
			TK.PutBehind(Rig, 3)
			T.Eq(HS.Take(Player, Rig), true, "control: 3 studs straight behind, the grab starts")
		end)
	end,

	-- (lesson I2, both ways) a grab target that is taking someone down, gripping or carrying, or being taken down, is
	-- refused "target_busy"; the control, none of them, starts
	GrabRefusesBusyTarget = function(T)
		HK.Guard(function()
			local HS = Svc()
			local Rig = HK.StandIn(At(0, 0))
			TK.PutBehind(Rig, 3)
			for _, Mark in ipairs({"TakingDown", "Gripping", "Carrying", "TakenDownBy"}) do
				HS.Forget(Player, {NextAt = true})
				Rig:SetAttribute(Mark, "X")
				local Ok = HS.Take(Player, Rig)
				Rig:SetAttribute(Mark, nil)
				T.Eq(Ok, false, Mark .. ": refused")
				T.Eq(HK.Result(), "Grab:target_busy", Mark .. ": LastHostageResult")
				T.Eq(Rig:GetAttribute("HeldBy"), nil, Mark .. ": not marked")
			end
			HS.Forget(Player, {NextAt = true})
			T.Eq(HS.Take(Player, Rig), true, "control: a free target, the grab starts")
		end)
	end,

	-- the grabbed stand-in (Strength 30 against the player's 5: (31 / 6) clamped to 2, 0.12 a press) fills the bar from
	-- 40%: shoved off before the window ends; the player stunned about 1 s (ShoveStun); attempted_hostage, not took_hostage
	GrabShovedOff = function(T)
		HK.Guard(function()
			local Att0, Took0 = DeedCount("attempted_hostage"), DeedCount("took_hostage")
			local Rig, PL = HK.Grabbed({Strength = 30})
			local T0 = os.clock()
			for _ = 1, 3 do -- (once a second, three times; the first already fills it)
				FullStamina(Rig) -- (pre-flight P4)
				Svc().Struggle(PL, 8)
				if HK.Result() then break end
				task.wait(1)
			end
			T.Eq(HK.Result(), "Grab:grab_failed", "shoved off")
			T.True(os.clock() - T0 < 3, "before the 3 s window ended")
			T.Eq(Rig:GetAttribute("HeldBy"), nil, "the stand-in is free")
			T.Eq(Weld(), nil, "no weld")
			T.Eq(DeedCount("attempted_hostage"), Att0 + 1, "attempted_hostage +1")
			T.Eq(DeedCount("took_hostage"), Took0, "took_hostage unchanged")
			T.True(Stunned(C), "the player is stunned")
			local Len = StunLeft(C, 3)
			T.Near(Len, 1, 0.3, "stunned about 1 s (ShoveStun; " .. ("%.2f"):format(Len) .. " s)")
			T.Eq(DeedCount("attempted_hostage"), Att0 + 1, "(fix round 1) recorded once, never twice")
		end)
	end,

	-- (fix round 1, review I1; spec §2: "a failed grab still counts as an assault") a grab the captor's side ends
	-- before the window is over (here a blink of 60 studs: "teleport") still records attempted_hostage, once; only the
	-- shove stuns, so the player isn't stunned
	GrabTeleportStillAnAssault = function(T)
		HK.Guard(function()
			local Att0, Took0 = DeedCount("attempted_hostage"), DeedCount("took_hostage")
			local Rig = HK.Grabbed()
			C.HumanoidRootPart.CFrame += Vector3.new(60, 0, 0)
			T.True(Ended("Grab:teleport", 0.5), "\"teleport\" within 0.5 s (" .. tostring(HK.Result()) .. ")")
			T.Eq(Rig:GetAttribute("HeldBy"), nil, "the stand-in is free")
			T.Eq(DeedCount("attempted_hostage"), Att0 + 1, "attempted_hostage +1")
			T.Eq(DeedCount("took_hostage"), Took0, "took_hostage unchanged")
			T.Eq(Stunned(C), false, "no stun: only a shove stuns")
			task.wait(0.3)
			T.Eq(Stunned(C), false, "still no stun 0.3 s on")
			T.Eq(DeedCount("attempted_hostage"), Att0 + 1, "recorded once")
		end)
	end,

	-- (fix round 1; review "cannot verify") a grabbed hostage knocked mid-window ends the grab ("knocked"), which is a
	-- failed grab (attempted_hostage +1, no stun); the knock's own timer recovers it, with the walk it had before the
	-- grab and no lock entry left
	GrabKnockedEnds = function(T)
		HK.Guard(function()
			local Att0 = DeedCount("attempted_hostage")
			local Rig = HK.StandIn(At(0, 0))
			local WS0 = Rig.Humanoid.WalkSpeed
			TK.PutBehind(Rig, 3)
			T.Eq(Svc().Take(Player, Rig), true, "setup: the grab starts")
			T.Eq(Rig.Humanoid.WalkSpeed, 0, "setup: the grabbed stand-in is locked")
			DM.Knock(Rig, 1)
			T.True(Ended("Grab:knocked", 0.3), "\"knocked\" within 0.3 s (" .. tostring(HK.Result()) .. ")")
			T.Eq(Rig:GetAttribute("HeldBy"), nil, "HeldBy cleared")
			T.Eq(Weld(), nil, "no weld")
			T.Eq(DeedCount("attempted_hostage"), Att0 + 1, "a failed grab: attempted_hostage +1")
			T.Eq(Stunned(C), false, "no stun on the captor")
			T.True(WaitFor(1.5, function() return not DM.IsKnocked(Rig) end), "the knock's own timer recovered it")
			T.Eq(DM.IsLocked(Rig), false, "no lock entry left")
			T.Near(Rig.Humanoid.WalkSpeed, WS0, 0.01, "the walk from before the grab")
		end)
	end,

	-- (pre-flight P22) a shoved-off grab is no hold, so it doesn't halve the next one: a bind right after lasts 180 s
	GrabFailedNotARetake = function(T)
		HK.Guard(function()
			local HS = Svc()
			local Rig, PL = HK.Grabbed({Strength = 30})
			HS.Struggle(PL, 8)
			T.Eq(HK.Result(), "Grab:grab_failed", "setup: shoved off")
			T.True(WaitFor(2.0, function() return not Stunned(C) end), "setup: the shove's stun is over")
			HS.Forget(PL, {ImmuneUntil = true})
			HS.Forget(Player, {NextAt = true})
			Rig:PivotTo(At(0, 0) + Vector3.new(0, 3, 0))
			DM.Knock(Rig)
			TK.PutPlayer(FRONT)
			T.Eq(HS.Take(Player, Rig), true, "bound right after")
			T.True(WaitFor(2.0, IsHeld), "Held")
			T.Near((C:GetAttribute("HostageUntil") or 0) - Now(), 180, 1, "a full 180 s: the shoved-off grab wasn't a re-take")
		end)
	end,

	-- (Task 6 re-review m3) a grab that becomes a hold is welded once (Pair is idempotent), so the stand-in root's network
	-- owner from before the grab (the server's, not auto: set here) is what it gets back after the release, never the
	-- captor's client
	GrabOwnerGivenBack = function(T)
		HK.Guard(function()
			local HS = Svc()
			local Rig = HK.StandIn(At(0, 0))
			local HR = Rig.HumanoidRootPart
			HR:SetNetworkOwner(nil)
			TK.PutBehind(Rig, 3)
			HK.Loose() -- (the player's root let go, so its client can own the pair)
			T.Eq(HR:GetNetworkOwner(), nil, "setup: the server owns the stand-in's root")
			T.Eq(HR:GetNetworkOwnershipAuto(), false, "setup: not auto")
			T.Eq(HS.Take(Player, Rig), true, "the grab starts")
			T.True(WaitFor(1.0, function() return HR:GetNetworkOwner() == Player end), "grabbing: the player's client owns the pair")
			T.True(WaitFor(4.0, IsHeld), "Held after the window (" .. tostring(HK.Result()) .. ")")
			T.Eq(HS.Free(Player, "released"), true, "released")
			task.wait(0.5) -- (the old owner comes back 0.25 s after the release)
			T.Eq(HR:GetNetworkOwner(), nil, "the server owns the stand-in's root again, as before the grab")
			T.Eq(HR:GetNetworkOwnershipAuto(), false, "and not auto, as before the grab")
		end)
	end,

	-- (spec §4) the immunity after any release refuses a grab as well as a bind; the control: immunity forgotten, it starts
	ImmuneRefusesGrab = function(T)
		HK.Guard(function()
			local HS = Svc()
			local Rig, PL = Held(T)
			HS.Free(Player, "released")
			HS.Forget(Player, {NextAt = true})
			T.Eq(DM.IsKnocked(Rig), false, "setup: the released hostage is standing")
			TK.PutBehind(Rig, 3)
			T.Eq(HS.Take(Player, Rig), false, "a grab right after a release is refused")
			T.Eq(HK.Result(), "Grab:immune", "LastHostageResult")
			HS.Forget(Player, {NextAt = true})
			HS.Forget(PL, {ImmuneUntil = true})
			T.Eq(HS.Take(Player, Rig), true, "control: the immunity forgotten, the grab starts (" .. tostring(HK.Result()) .. ")")
		end)
	end,

	-- the real player as the hostage of a stand-in captor with Strength 0 (pre-flight P4: (1 + 5) / (1 + 0) clamped to 2,
	-- 0.12 a press): eight presses each 0.5 s, stamina full, break free within 10 s; the captor stunned about 1.5 s
	-- (BreakStun); the player free and immune for 5 s
	StruggleFrees = function(T)
		HK.Guard(function()
			local HS = Svc()
			local Cap = Captive(T, {Strength = 0})
			local T0, Freed = os.clock(), false
			while os.clock() - T0 < 10 do
				FullStamina(C)
				HS.Struggle(Player, 8)
				if HK.Result(Cap) == "Bind:struggled" then Freed = true break end
				task.wait(0.5)
			end
			local FreedAt = Now()
			T.True(Freed, "\"struggled\" within 10 s (" .. tostring(HK.Result(Cap)) .. ")")
			T.Eq(C:GetAttribute("HeldBy"), nil, "the player's HeldBy cleared")
			T.Near(C:GetAttribute("GrabImmuneUntil") or 0, FreedAt + 5, 0.3, "immune for 5 s")
			T.True(Stunned(Cap), "the stand-in captor is stunned")
			local Len = StunLeft(Cap, 3)
			T.Near(Len, 1.5, 0.3, "stunned about 1.5 s (BreakStun; " .. ("%.2f"):format(Len) .. " s)")
		end)
	end,

	-- (review M7) a message is ignored unless its Count is a whole number from 1 to MaxPressesPerSecond 8; at most 8
	-- presses a rolling second count (5 vs 5: 0.06 a press, so twenty single presses in one frame add 8 x 0.06 = 0.48);
	-- the captor's own presses never count; _Sends counts the hostage's messages (pre-flight P9) and Forget clears it
	StruggleRateLimited = function(T)
		HK.Guard(function()
			local HS = Svc()
			local _, CapPL, S = Captive(T)
			FullStamina(C)
			local Sends0 = HS._Sends(Player)
			for _, Bad in ipairs({50, 9, 0, -1, 1.5, 0 / 0, math.huge, "8"}) do HS.Struggle(Player, Bad) end
			T.Eq(S.Struggle, 0, "out of range, fractional, NaN, infinite and non-number counts are ignored")
			HS.Struggle(CapPL, 8)
			T.Eq(S.Struggle, 0, "the captor's presses don't count")
			for _ = 1, 20 do HS.Struggle(Player, 1) end
			T.Near(S.Struggle, 0.48, 0.005, "twenty single presses in one frame: 8 counted")
			T.Near(C:GetAttribute("Struggle") or -1, S.Struggle, 1e-6, "the bar is on the Struggle attribute")
			T.Eq(HS._Sends(Player) - Sends0, 28, "_Sends counted each of the hostage's 28 messages")
			HS.Forget(Player)
			T.Eq(HS._Sends(Player), 0, "Forget clears _Sends")
		end)
	end,

	-- no stamina, no press; the control: with stamina, one press adds 0.06 (5 vs 5) and spends StruggleStamina 4
	StruggleNeedsStamina = function(T)
		HK.Guard(function()
			local HS = Svc()
			local _, _, S = Captive(T)
			RM().Set(C, "Stamina", 0)
			HS.Struggle(Player, 1)
			T.Eq(S.Struggle, 0, "no stamina: the press adds nothing")
			FullStamina(C)
			local St0 = RM().Get(C, "Stamina")
			HS.Struggle(Player, 1)
			T.Near(S.Struggle, 0.06, 0.001, "control: with stamina, one press adds 0.06")
			T.Near(St0 - RM().Get(C, "Stamina"), 4, 0.01, "and spends 4 stamina")
		end)
	end,

	-- the bar drains StruggleDrain 0.05 a second: 0.5, then 2 s with no presses, 0.4
	StruggleDrains = function(T)
		HK.Guard(function()
			local Rig, _, S = HK.Held()
			S.Struggle = 0.5
			task.wait(2)
			T.Near(S.Struggle, 0.4, 0.02, "0.4 after 2 s")
			T.Near(Rig:GetAttribute("Struggle") or -1, S.Struggle, 0.01, "the attribute follows the bar")
		end)
	end,

	-- (ruling T1-4) PartyOf: a solo player is alone; a stand-in's own Party; the test stub only while the seam is open
	PartyOf = function(T)
		HK.Guard(function()
			local HS = Svc()
			local _, A = HK.StandIn(At(0, 0))
			local _, B = HK.StandIn(At(3, 0))
			A.Party = {B}
			T.Same(HS.PartyOf(Player), {Player}, "the solo player is alone (PartyService.Get is nil)")
			T.Same(HS.PartyOf(A), {A, B}, "a stand-in's Party, itself first")
			T.Eq(HS.SameParty(A, B), true, "A and B are one party")
			T.Eq(HS.SameParty(A, A), false, "never a party with itself")
			local Real = HS._NoSave
			local Ok, Err = pcall(function()
				HS._PartyOf = function(PL) if PL == Player then return {A} end return nil end
				T.Same(HS.PartyOf(Player), {Player, A}, "the stub answers while the seam is open")
				HS._NoSave = function() return false end
				T.Same(HS.PartyOf(Player), {Player}, "the stub is ignored once the seam is shut")
			end)
			HS._NoSave, HS._PartyOf = Real, nil
			if not Ok then error(Err, 0) end
		end)
	end,

	-- ===== Task 8: the captor menu's Release and Finish, and the deeds (texts written by hand from the brief) =====
	-- only the captor of a Held session has options: Release, Finish, Ransom, in that order; Ransom locked ("They have no
	-- party here" for a hostage alone, else "Not yet" until Task 11). The captor's Held notify carries them (UIService
	-- .Notify watched, put back after), and its Free notify carries {} (the session over).
	MenuOptionsShape = function(T)
		HK.Guard(function()
			local HS = Svc()
			T.Same(HS.MenuOptions(Player), {}, "not holding: no options")
			local UI = require(SSS.UIService)
			local RealNotify = UI.Notify
			local Sent = {}
			UI.Notify = function(P, Kind, Data)
				if P == Player and Kind == "Hostage" then table.insert(Sent, Data) end
				return RealNotify(P, Kind, Data)
			end
			local Ok, Err = pcall(function()
				local _, PL = Held(T)
				local O = HS.MenuOptions(Player)
				T.Same(Ids(O), {"Release", "Finish", "Ransom"}, "the ids, in order")
				T.Eq(O[1] and O[1].Text, "Let them go", "Release's text")
				T.Eq(O[1] and O[1].Locked, false, "Release is open")
				T.Eq(O[2] and O[2].Text, "Finish them", "Finish's text")
				T.Eq(O[2] and O[2].Locked, false, "Finish is open")
				T.Eq(O[3] and O[3].Text, "Demand ransom", "Ransom's text")
				T.Eq(O[3] and O[3].Locked, true, "Ransom is locked")
				T.Eq(O[3] and O[3].Why, "They have no party here", "a hostage alone: no party here")
				local _, Friend = HK.StandIn(At(8, 0))
				PL.Party = {Friend}
				T.Eq(HS.MenuOptions(Player)[3].Why, "Not yet", "a hostage with a party: locked until Task 11")
				T.Same(HS.MenuOptions(PL), {}, "the hostage has no menu")
				local HeldNote = nil
				for _, D in ipairs(Sent) do if D.State == "Held" then HeldNote = D end end
				T.True(HeldNote ~= nil, "the captor was told Held")
				T.Same(Ids(HeldNote and HeldNote.Options), {"Release", "Finish", "Ransom"}, "the Held notify carries the options")
				HS.Free(Player, "released")
				local FreeNote = Sent[#Sent]
				T.Eq(FreeNote and FreeNote.State, "Free", "then told Free")
				T.Same(FreeNote and FreeNote.Options, {}, "the Free notify carries no options")
			end)
			UI.Notify = RealNotify
			if not Ok then error(Err, 0) end
			T.Same(HS.MenuOptions(Player), {}, "released: no options")
		end)
	end,

	-- Release: the hold ends "released" at once; (fix round 1, ruling I1) the Mercy deed released_hostage +1 only once the
	-- release window (shortened to 1 s here) has run out with the player unharmed; nobody saw the take, so it raised no
	-- Heat and the release changes none (Heat_<J>, rounded to 0.1 on the attribute)
	MenuRelease = function(T)
		HK.Guard(function() WithGrace(1, function()
			local HS, J = Svc(), TK.LAW.J
			local Attr0, Heat0 = Player:GetAttribute("Heat_" .. J), HeatSvc().Value(Player, J)
			local Rig = Held(T)
			local Released0 = DeedCount("released_hostage")
			T.Eq(HS.Menu(Player, "Release"), true, "the choice acted")
			T.Eq(HK.Result(), "Bind:released", "LastHostageResult")
			AllLetGo(T, Rig, "released")
			T.Eq(DeedCount("released_hostage") - Released0, 0, "nothing paid while the window runs")
			T.Eq(HS.Menu(Player, "Release"), false, "a second Release: no session, ignored")
			T.True(WaitFor(1.5, function() return DeedCount("released_hostage") - Released0 == 1 end),
				"the window ran out unharmed: released_hostage +1")
			task.wait(0.3)
			T.Eq(DeedCount("released_hostage") - Released0, 1, "paid once")
			T.Eq(HS._PendingCount(), 0, "the window is gone once paid")
			T.Near(HeatSvc().Value(Player, J), Heat0, 0.05, J .. " Heat unchanged")
			T.Near(Player:GetAttribute("Heat_" .. J) or 0, Attr0 or 0, 0.1, "the Heat_" .. J .. " attribute unchanged")
		end) end)
	end,

	-- (ruling on spec §3, "its Heat is only half that of the original crime") a witnessed take raises took_hostage's Crime
	-- in this place's jurisdiction when that law hears it there; a release unharmed takes half of it back, and no other
	-- jurisdiction moves. Written by hand per place (Rensei.Regions, Heat.Raised): Ye's unnamed ground is Lindenmoor
	-- (Militia), where the Townsfolk are, so a townsperson's word raises Militia 30 at once (net +15 after the release);
	-- the Foundry is State land without the Authority among its factions, so a townsperson's word raises no State Heat at
	-- once (the law hears it only when word reaches it), and the release has nothing to halve (net 0).
	-- (fix round 1) 20 Heat is there before the take (review m1: half of ALL the Heat would read 25, not 15, above Heat0),
	-- and nothing is halved until the release window (1 s here) has run out
	MenuReleaseHalvesHeat = function(T)
		local Numbers = ({[106992859583940] = {30, 15}, [109591196441030] = {0, 0}})[game.PlaceId]
		if not Numbers then error("MenuReleaseHalvesHeat: no hand-written numbers for place " .. tostring(game.PlaceId), 0) end
		local RAISED, NET = Numbers[1], Numbers[2]
		WithGrace(1, function() Witnessed(T, function(_, _, _, _, Heat0)
			local J = TK.LAW.J
			local Others = {}
			for _, K in ipairs({"State", "Militia", "Circle"}) do
				if K ~= J then Others[K] = HeatSvc().Value(Player, K) end
			end
			T.Near(HeatSvc().Value(Player, J) - Heat0, RAISED, 0.5, ("the witnessed take raised %s Heat %d"):format(J, RAISED))
			local Released0 = DeedCount("released_hostage")
			T.Eq(Svc().Menu(Player, "Release"), true, "the choice acted")
			task.wait(0.2)
			T.Near(HeatSvc().Value(Player, J) - Heat0, RAISED, 0.5, "nothing halved while the window runs")
			T.True(WaitFor(1.5, function() return DeedCount("released_hostage") - Released0 == 1 end), "released_hostage +1")
			task.wait(0.2)
			T.Near(HeatSvc().Value(Player, J) - Heat0, NET, 0.5, ("released unharmed: half of it taken back (net +%d)"):format(NET))
			for K, V in pairs(Others) do T.Near(HeatSvc().Value(Player, K), V, 0.05, K .. " Heat unchanged") end
		end, {Seed = 20}) end)
	end,

	-- (fix round 1, ruling I1) release, then the ex-captor's knocking hit, then B (DownedManager.Request "Grip") inside the
	-- window (3 s here): the grip's finish records killed_hostage, as Finish would; at the window's end no Mercy and no
	-- Heat halving (the Heat after the kill is the Heat after the window)
	ReleaseThenKillIsAKill = function(T)
		WithGrace(3, function() Witnessed(T, function(Rig)
			local J = TK.LAW.J
			local Released0, Killed0 = DeedCount("released_hostage"), DeedCount("killed_hostage")
			local T0 = os.clock()
			T.Eq(Svc().Menu(Player, "Release"), true, "the choice acted")
			KnockingHit(C, Rig)
			T.True(DM.IsKnocked(Rig), "setup: the player's hit knocked the released stand-in")
			T.Eq(DM.Request(C, "Grip"), "Gripped", "B: the player's grip finished it")
			T.True(Rig.Humanoid.Health <= 0, "dead")
			T.True(os.clock() - T0 < 3, "setup: all inside the window")
			T.True(WaitFor(0.5, function() return DeedCount("killed_hostage") - Killed0 == 1 end), "killed_hostage +1")
			local Heat1 = HeatSvc().Value(Player, J)
			task.wait(math.max(0, 3.5 - (os.clock() - T0)))
			T.Eq(DeedCount("released_hostage") - Released0, 0, "no Mercy")
			T.Eq(DeedCount("killed_hostage") - Killed0, 1, "killed once")
			T.Near(HeatSvc().Value(Player, J), Heat1, 0.5, "no Heat halving at the window's end")
		end) end)
	end,

	-- (fix round 3, re-review N1) the ex-captor knocks the released stand-in at 60% of the window (2 s here) and grips it
	-- after the window would have ended: the harmed window stayed open while it was down, so the kill is killed_hostage,
	-- once, with no Mercy; then no window is left open
	LateKnockThenKillIsAKill = function(T)
		HK.Guard(function() KeepHeat(function() WithGrace(2, function()
			local HS = Svc()
			local Rig = Held(T)
			local Killed0, Released0 = DeedCount("killed_hostage"), DeedCount("released_hostage")
			local T0 = os.clock()
			T.Eq(HS.Menu(Player, "Release"), true, "the choice acted")
			task.wait(1.2)
			KnockingHit(C, Rig)
			T.True(DM.IsKnocked(Rig), "setup: the player's hit knocked the released stand-in at 1.2 s")
			task.wait(math.max(0, 2.3 - (os.clock() - T0)))
			T.True(DM.IsKnocked(Rig), "setup: still knocked after the window's 2 s")
			T.Eq(DM.Request(C, "Grip"), "Gripped", "B after the window: the player's grip finished it")
			T.True(Rig.Humanoid.Health <= 0, "dead")
			T.True(WaitFor(0.5, function() return DeedCount("killed_hostage") - Killed0 == 1 end), "killed_hostage +1")
			task.wait(0.5)
			T.Eq(DeedCount("killed_hostage") - Killed0, 1, "recorded once")
			T.Eq(DeedCount("released_hostage") - Released0, 0, "no Mercy")
			T.True(WaitFor(0.5, function() return HS._PendingCount() == 0 end), "no window left open")
		end) end) end)
	end,

	-- (fix round 1, ruling I1) someone else knocking the released player in the window changes nothing: paid at its end
	ThirdPartyHarmStillPays = function(T)
		HK.Guard(function() WithGrace(1, function()
			local Rig = Held(T)
			local Other = HK.StandIn(At(6, 0))
			local Released0 = DeedCount("released_hostage")
			T.Eq(Svc().Menu(Player, "Release"), true, "the choice acted")
			KnockingHit(Other, Rig)
			T.True(DM.IsKnocked(Rig), "setup: a third party's hit knocked the released stand-in")
			T.True(WaitFor(1.5, function() return DeedCount("released_hostage") - Released0 == 1 end),
				"released_hostage +1 at the window's end")
		end) end)
	end,

	-- (fix round 1, ruling I1) the ex-captor's party counts as the ex-captor: a party member's knocking hit in the window
	-- (HostageService._PartyOf stubbed, put back after) means no Mercy at its end
	PartyKnockCancelsPayout = function(T)
		HK.Guard(function() WithGrace(1, function()
			local HS = Svc()
			local Rig = Held(T)
			local Friend, FriendPL = HK.StandIn(At(6, 0))
			local Released0 = DeedCount("released_hostage")
			Swap(HS, "_PartyOf", function(PL) if PL == Player then return {FriendPL} end return nil end, function()
				T.Eq(HS.Menu(Player, "Release"), true, "the choice acted")
				KnockingHit(Friend, Rig)
				T.True(DM.IsKnocked(Rig), "setup: the party member's hit knocked the released stand-in")
				task.wait(1.5)
				T.Eq(DeedCount("released_hostage") - Released0, 0, "no Mercy")
			end)
		end) end)
	end,

	-- (the release Heat's own seam) HeatService.Reduce takes Heat off one jurisdiction only, returns what it took, never
	-- goes below 0, and ignores a non-finite, non-positive or non-number amount and an unknown jurisdiction
	HeatReduceOneJurisdiction = function(T)
		HK.Guard(function() KeepHeat(function()
			local HeatS, J = HeatSvc(), TK.LAW.J
			T.Eq(type(HeatS.Reduce), "function", "HeatService.Reduce exists")
			local Before = {}
			for _, K in ipairs({"State", "Militia", "Circle"}) do Before[K] = HeatS.Value(Player, K) end
			HeatS.Add(Player, J, 40)
			T.Near(HeatS.Reduce(Player, J, 15), 15, 1e-6, "Reduce returns what it took off")
			T.Near(HeatS.Value(Player, J) - Before[J], 25, 0.05, "+40 then -15: +25")
			for K, V in pairs(Before) do
				if K ~= J then T.Near(HeatS.Value(Player, K), V, 0.05, K .. " unchanged") end
			end
			local Mid = HeatS.Value(Player, J)
			for _, Bad in ipairs({0, -5, 0 / 0, math.huge, "5"}) do
				T.Eq(HeatS.Reduce(Player, J, Bad), 0, "ignored: " .. tostring(Bad))
			end
			T.Eq(HeatS.Reduce(Player, J), 0, "ignored: no amount")
			T.Eq(HeatS.Reduce(Player, "Nowhere", 5), 0, "ignored: an unknown jurisdiction")
			T.Near(HeatS.Value(Player, J), Mid, 0.05, "nothing taken by the ignored calls")
			T.Near(HeatS.Reduce(Player, J, Mid + 50), Mid, 0.05, "at most what there is")
			T.Near(HeatS.Value(Player, J), 0, 0.01, "never below 0")
			T.Eq(Player:GetAttribute("Heat_" .. J), 0, "published on the attribute")
		end) end)
	end,

	-- Finish: the hold ends "finished", the hostage knocked at its own HP and gripped by the player through the normal
	-- Grip (GrippedBy / Gripping); while it runs the grip's marks keep a take off both (guards: Task 4's exclusion); dead
	-- within GripTime 2 + 1 s; killed_hostage +1
	MenuFinish = function(T)
		HK.Guard(function() KeepHeat(function()
			local HS = Svc()
			local Rig = Held(T)
			local H = Rig.Humanoid
			local HP0 = H.Health
			local Killed0 = DeedCount("killed_hostage")
			T.Eq(HS.Menu(Player, "Finish"), true, "the choice acted")
			T.Eq(HK.Result(), "Bind:finished", "LastHostageResult")
			T.Eq(Rig:GetAttribute("HeldBy"), nil, "the hold is over")
			T.Eq(C:GetAttribute("Holding"), nil, "the player holds nobody")
			T.True(DM.IsKnocked(Rig), "the hostage is knocked for the grip")
			T.Near(H.Health, HP0, 0.5, "its HP kept (Knock only sets the state)")
			T.Eq(Rig:GetAttribute("GrippedBy"), Player.Name, "the normal grip runs on it")
			T.Eq(C:GetAttribute("Gripping"), Rig.Name, "the player is gripping")
			local _, Other = HK.StandIn(At(8, 0))
			T.Eq(HS.Context(Other, Rig, "Bind").TargetFree, false, "guard: the gripped hostage can't be taken")
			T.Eq(HS.Context(Player, Other.Character, "Grab").CaptorFree, false, "guard: the gripping player takes nobody")
			T.True(WaitFor(3, function() return H.Health <= 0 end), "dead within GripTime 2 + 1 s")
			T.True(WaitFor(0.5, function() return DeedCount("killed_hostage") - Killed0 == 1 end), "killed_hostage +1")
			T.Eq(C:GetAttribute("Gripping"), nil, "the grip is over")
		end) end)
	end,

	-- (fix round 2, ruling on review m2) a Finish cancelled by a stun (window 5 s here) opens the harm window with no
	-- payout: once the stun is over, the captor's own grip (B) that kills the still-knocked stand-in records
	-- killed_hostage once, and the window's end pays no Mercy
	FinishCancelledThenKillIsAKill = function(T)
		HK.Guard(function() KeepHeat(function() WithGrace(5, function()
			local HS = Svc()
			local Rig = Held(T)
			local Killed0, Released0 = DeedCount("killed_hostage"), DeedCount("released_hostage")
			local Ok, Err = pcall(function()
				T.Eq(HS.Menu(Player, "Finish"), true, "the choice acted")
				task.wait(0.3)
				T.Eq(Rig:GetAttribute("GrippedBy"), Player.Name, "setup: gripping")
				StunPlayer(0.5)
				T.True(WaitFor(0.5, function() return Rig:GetAttribute("GrippedBy") == nil end), "setup: the stun cancels the grip")
				T.True(WaitFor(1.5, function() return not Stunned(C) end), "setup: the stun is over")
				T.True(DM.IsKnocked(Rig) and Rig.Humanoid.Health > 0, "setup: still knocked and alive")
				T.Eq(DeedCount("killed_hostage") - Killed0, 0, "setup: no kill recorded yet")
				T.Eq(DM.Request(C, "Grip"), "Gripped", "B: the player's own grip finished it")
				T.True(Rig.Humanoid.Health <= 0, "dead")
				T.True(WaitFor(0.5, function() return DeedCount("killed_hostage") - Killed0 == 1 end), "killed_hostage +1")
				task.wait(0.5)
				T.Eq(DeedCount("killed_hostage") - Killed0, 1, "recorded once")
				T.Eq(DeedCount("released_hostage") - Released0, 0, "no Mercy")
			end)
			WaitFor(2, function() return not Stunned(C) end)
			if not Ok then error(Err, 0) end
		end) end) end)
	end,

	-- (fix round 1, I2) a captor mid-attack can't Finish (AttackRunner.IsRunning swapped to say so, put back after): the
	-- choice is ignored before any Release or knock, still Held
	FinishRefusedMidAttack = function(T)
		HK.Guard(function()
			local HS = Svc()
			local Rig = Held(T)
			local AR = require(game.ReplicatedStorage.Modules.Managers.AttackRunner)
			Swap(AR, "IsRunning", function(Ch) return Ch == C end, function()
				T.Eq(HS.Menu(Player, "Finish"), false, "a Finish mid-attack is ignored")
			end)
			T.True(IsHeld(), "still Held")
			T.Eq(DM.IsKnocked(Rig), false, "never knocked")
			T.Eq(Rig:GetAttribute("HeldBy"), Player.Name, "still held by the player")
		end)
	end,

	-- (fix round 1, I2) a grip that fails at once (DownedManager.Grip swapped to return false, put back after) gives the
	-- knock back: the released stand-in isn't left freshly knocked, its HP kept, and nothing is recorded
	FinishGripFailsUndoesKnock = function(T)
		HK.Guard(function()
			local HS = Svc()
			local Rig = Held(T)
			local HP0 = Rig.Humanoid.Health
			local Killed0 = DeedCount("killed_hostage")
			Swap(DM, "Grip", function() return false end, function()
				T.Eq(HS.Menu(Player, "Finish"), true, "the choice acted")
				T.Eq(HK.Result(), "Bind:finished", "LastHostageResult")
			end)
			task.wait(0.2)
			T.Eq(DM.IsKnocked(Rig), false, "the knock was given back")
			T.True(Rig.Humanoid.Health > 0, "alive")
			T.Near(Rig.Humanoid.Health, HP0, 0.5, "its HP kept")
			T.Eq(DeedCount("killed_hostage") - Killed0, 0, "killed_hostage unchanged")
		end)
	end,

	-- a rescue mid-grip: a WCS Stun on the player 0.3 s into the Finish cancels the grip, as for any grip; the stand-in is
	-- left alive and knocked, and killed_hostage doesn't move. First, a captor already stunned can't Finish (the grip
	-- would fail at once): ignored, still Held.
	FinishCancelledByStun = function(T)
		HK.Guard(function() KeepHeat(function()
			local HS = Svc()
			local Rig = Held(T)
			local Killed0 = DeedCount("killed_hostage")
			-- (the case's stuns are waited out even when it fails, so the next case never starts stunned: RED saw that)
			local Ok, Err = pcall(function()
				StunPlayer(0.5)
				T.Eq(HS.Menu(Player, "Finish"), false, "a stunned captor's Finish is ignored")
				T.True(IsHeld(), "still Held")
				T.True(WaitFor(1.5, function() return not Stunned(C) end), "setup: the stun is over")
				T.Eq(HS.Menu(Player, "Finish"), true, "the choice acted")
				task.wait(0.3)
				T.Eq(Rig:GetAttribute("GrippedBy"), Player.Name, "setup: gripping")
				StunPlayer(1)
				T.True(WaitFor(0.5, function() return Rig:GetAttribute("GrippedBy") == nil end), "the stun cancels the grip")
				task.wait(2.2) -- (past the grip's 2 s)
				T.True(Rig.Humanoid.Health > 0, "the stand-in is alive")
				T.True(DM.IsKnocked(Rig), "and knocked")
				T.Eq(C:GetAttribute("Gripping"), nil, "the player isn't gripping")
				T.Eq(DeedCount("killed_hostage") - Killed0, 0, "killed_hostage unchanged")
			end)
			WaitFor(2, function() return not Stunned(C) end)
			if not Ok then error(Err, 0) end
		end) end)
	end,

	-- only the captor of a Held session chooses: the hostage's own Release or Finish, an unknown or non-string choice,
	-- and any choice during a grab are ignored
	MenuNotCaptor = function(T)
		HK.Guard(function()
			local HS = Svc()
			local Rig, PL = Held(T)
			T.Eq(HS.Menu(PL, "Release"), false, "the hostage's Release is ignored")
			T.Eq(HS.Menu(PL, "Finish"), false, "the hostage's Finish is ignored")
			for _, Bad in ipairs({"Bogus", "release", 5}) do
				T.Eq(HS.Menu(Player, Bad), false, "ignored: " .. tostring(Bad))
			end
			T.True(IsHeld(), "still Held")
			T.Eq(Rig:GetAttribute("HeldBy"), Player.Name, "still held by the player")
			T.Eq(DM.IsKnocked(Rig), false, "never knocked")
		end)
		HK.Guard(function()
			local HS = Svc()
			local Rig = HK.Grabbed()
			T.Same(HS.MenuOptions(Player), {}, "no options while Grabbing")
			T.Eq(HS.Menu(Player, "Release"), false, "a Release while Grabbing is ignored")
			T.Eq(HS.Menu(Player, "Finish"), false, "a Finish while Grabbing is ignored")
			local S = HS.SessionOf(Player)
			T.True(S ~= nil and S.State == "Grabbing" and Rig:GetAttribute("HeldBy") == Player.Name, "still Grabbing")
		end)
	end,

	-- (P3: Guard reset the day counts) a townsperson facing the pair 10 studs off sees the bind: took_hostage is recorded
	-- with a witness Strength above 0 (MoralityService.Recorded), and a rumour of it starts (Data.Morality.Rumours)
	TakeIsWitnessed = function(T)
		Witnessed(T, function(_, _, Got, Morality)
			local Rec = Find(Got, "took_hostage")
			T.True(Rec ~= nil, "took_hostage was recorded")
			T.True((Rec and Rec.Info.Strength or 0) > 0, "with a witness Strength above 0 (" .. tostring(Rec and Rec.Info.Strength) .. ")")
			local Rumour = nil
			for _, R in ipairs(Morality.Rumours or {}) do if R.Deed == "took_hostage" then Rumour = R end end
			T.True(Rumour ~= nil, "a rumour of it started")
		end)
	end,

	-- ===== Task 9: the human shield and the rescue =====
	-- a hit from 4 studs in front of the captor lands on the hostage, not the captor: used_human_shield once per hold
	FrontHitLandsOnHostage = function(T)
		HK.Guard(function() KeepHeat(function()
			local Rig = Held(T)
			local Atk = Attacker(0, 4)
			local HP0, Mine0 = Rig.Humanoid.Health, C.Humanoid.Health
			local Shield0 = DeedCount("used_human_shield")
			T.Eq(Hit(Atk, C), "Hit", "the front hit lands")
			T.Near(HP0 - Rig.Humanoid.Health, 10, 1, "the hostage lost about 10")
			T.True(C.Humanoid.Health >= Mine0 - 0.01, "the captor lost nothing (" .. Mine0 .. " -> " .. C.Humanoid.Health .. ")")
			task.wait(0.3) -- (the deed is recorded on its own thread)
			T.Eq(DeedCount("used_human_shield") - Shield0, 1, "used_human_shield +1")
			T.True(IsHeld(), "still Held: a front hit frees nobody")
			T.Eq(Hit(Atk, C), "Hit", "a second front hit lands")
			T.Near(HP0 - Rig.Humanoid.Health, 20, 2, "on the hostage again")
			T.True(C.Humanoid.Health >= Mine0 - 0.01, "the captor still lost nothing")
			task.wait(0.3)
			T.Eq(DeedCount("used_human_shield") - Shield0, 1, "still +1 in total (once per hold)")
			T.True(IsHeld(), "still Held")
		end) end)
	end,

	-- a hit from 4 studs behind lands on the captor and frees the hostage at once; a player's rescue records nothing more
	RearHitRescues = function(T)
		HK.Guard(function() KeepHeat(function()
			local Rig = Held(T)
			local Atk = Attacker(180, 4)
			local HP0, Mine0 = Rig.Humanoid.Health, C.Humanoid.Health
			local Shield0, Took0 = DeedCount("used_human_shield"), DeedCount("took_hostage")
			T.Eq(Hit(Atk, C), "Hit", "the rear hit lands")
			T.True(Ended("Bind:rescued", 0.2), "rescued within 0.2 s (" .. tostring(HK.Result()) .. ")")
			T.True(C.Humanoid.Health < Mine0 - 5, "the captor took the hit (" .. Mine0 .. " -> " .. C.Humanoid.Health .. ")")
			T.Near(Rig.Humanoid.Health, HP0, 0.5, "the hostage took nothing")
			AllLetGo(T, Rig, "rescued")
			task.wait(0.3)
			T.Eq(DeedCount("used_human_shield") - Shield0, 0, "no shield deed")
			T.Eq(DeedCount("took_hostage") - Took0, 0, "a player's rescue records nothing more of the taking")
		end) end)
	end,

	-- the shield arc's edge: 60 degrees off the front is inside it (the hostage takes the hit, nobody is freed); 90
	-- degrees, the captor's side, is outside it (rescued)
	SideHitRescues = function(T)
		HK.Guard(function() KeepHeat(function()
			local Rig = Held(T)
			local Near = Attacker(60, 4)
			local HP0 = Rig.Humanoid.Health
			T.Eq(Hit(Near, C), "Hit", "the 60-degree hit lands")
			T.Near(HP0 - Rig.Humanoid.Health, 10, 1, "on the hostage (inside the shield arc)")
			task.wait(0.2)
			T.True(IsHeld(), "still Held")
			local Side = Attacker(90, 4)
			T.Eq(Hit(Side, C), "Hit", "the side hit lands")
			T.True(Ended("Bind:rescued", 0.2), "rescued within 0.2 s (" .. tostring(HK.Result()) .. ")")
			AllLetGo(T, Rig, "rescued")
		end) end)
	end,

	-- a parry of the captor's attack frees the hostage ("parried"); the captor parrying someone else's frees nobody
	ParryRescues = function(T)
		HK.Guard(function()
			local Rig = Held(T)
			local Atk = Attacker(0, 4)
			require(SSS.ProgressionService).RecordHit(Atk, C, "Parried")
			task.wait(0.2)
			T.True(IsHeld(), "the captor parrying the attacker frees nobody")
			require(SSS.ProgressionService).RecordHit(C, Atk, "Parried")
			T.True(Ended("Bind:parried", 0.2), "parried within 0.2 s (" .. tostring(HK.Result()) .. ")")
			AllLetGo(T, Rig, "parried")
		end)
		HK.Guard(function()
			local Rig = Held(T)
			local Atk = Attacker(0, 4)
			require(SSS.ProgressionService).RecordHit(C, Atk, "PerfectParried")
			T.True(Ended("Bind:parried", 0.2), "a perfect parry too (" .. tostring(HK.Result()) .. ")")
			AllLetGo(T, Rig, "perfect parry")
		end)
	end,

	-- an NPC whose line to the captor runs through the hostage holds its attack: LineBlocked true and CanStrike false 5
	-- studs in front; behind, both flip; after the release, in front again, it may strike (the control)
	NpcHoldsInFront = function(T)
		HK.Guard(function()
			local CD = require(SSS.CombatDirector)
			local HS = Svc()
			TK.PutPlayer(FRONT)
			local Grunt = LoneGrunt(0, 5)
			T.Eq(CD.CanStrike(Grunt, C), true, "setup: the lone Grunt may strike the player before the take")
			local Rig = Held(T)
			Grunt:PivotTo(AroundPlayer(0, 5))
			T.Eq(CD.CanStrike(Grunt, C), false, "5 studs in front: the Grunt holds its attack")
			T.Eq(HS.LineBlocked(Grunt, C), true, "5 studs in front: the line is blocked")
			Grunt:PivotTo(AroundPlayer(180, 5))
			T.Eq(HS.LineBlocked(Grunt, C), false, "behind: the line is clear")
			T.Eq(CD.CanStrike(Grunt, C), true, "behind: the Grunt may strike")
			T.Eq(HS.LineBlocked(Grunt, Rig), false, "the hostage itself is never a blocked target")
			T.True(HS.Free(Player, "a"), "setup: freed")
			Grunt:PivotTo(AroundPlayer(0, 5))
			T.Eq(HS.LineBlocked(Grunt, C), false, "after the release, in front: the line is clear")
			T.Eq(CD.CanStrike(Grunt, C), true, "after the release, in front: the Grunt may strike (the control)")
		end)
	end,

	-- (decision 5) a front hit for more than the hostage's health knocks the hostage, not the captor; the hold ends
	-- "knocked"
	ShieldHitKnocksHostage = function(T)
		HK.Guard(function() KeepHeat(function()
			local Rig = Held(T)
			local Atk = Attacker(0, 4)
			local Mine0 = C.Humanoid.Health
			Hit(Atk, C, {Damage = Rig.Humanoid.Health + 50, StunTime = 0})
			T.True(DM.IsKnocked(Rig), "the hostage is knocked")
			T.Eq(DM.IsKnocked(C), false, "the captor isn't")
			T.True(C.Humanoid.Health >= Mine0 - 0.01, "the captor lost nothing")
			T.True(Ended("Bind:knocked", 0.5), "the hold ends knocked (" .. tostring(HK.Result()) .. ")")
			AllLetGo(T, Rig, "knocked")
		end) end)
	end,

	-- (a regression guard, pre-flight D5) the captor's own hit on its hostage isn't redirected nor blocked: the hostage
	-- takes it, the captor nothing, no shield deed, still Held
	HostageNotShieldedFromCaptor = function(T)
		HK.Guard(function() KeepHeat(function()
			local Rig = Held(T)
			local HP0, Mine0 = Rig.Humanoid.Health, C.Humanoid.Health
			local Shield0 = DeedCount("used_human_shield")
			T.Eq(Hit(C, Rig), "Hit", "the captor's hit lands")
			T.Near(HP0 - Rig.Humanoid.Health, 10, 1, "the hostage takes it")
			T.True(C.Humanoid.Health >= Mine0 - 0.01, "the captor takes nothing")
			task.wait(0.3)
			T.Eq(DeedCount("used_human_shield") - Shield0, 0, "no shield deed")
			T.True(IsHeld(), "still Held")
		end) end)
	end,

	-- (the guards ruling, spec §4) a guard -- an NPC of a State or Militia law faction, PROPOSAL; no guards spawn yet -- that
	-- frees a hostage records the taking again, witnessed (the captor's Heat rises through the existing path); an NPC of
	-- no law faction rescues the same way and records nothing (the control)
	GuardRescueIsWitnessed = function(T)
		HK.Guard(function() KeepHeat(function()
			Held(T)
			local Took0 = DeedCount("took_hostage")
			local Grunt = LoneGrunt(180, 4)
			Grunt:SetAttribute("Faction", "Authority") -- (written by hand: the State's law faction)
			T.Eq(Hit(Grunt, C), "Hit", "the guard's rear hit lands")
			T.True(Ended("Bind:rescued", 0.2), "rescued (" .. tostring(HK.Result()) .. ")")
			task.wait(0.3)
			T.Eq(DeedCount("took_hostage") - Took0, 1, "took_hostage recorded again, witnessed")
			Unstunned()
		end) end)
		HK.Guard(function() KeepHeat(function()
			Held(T)
			local Took0 = DeedCount("took_hostage")
			local Grunt = LoneGrunt(180, 4)
			Grunt:SetAttribute("Faction", nil)
			T.Eq(Hit(Grunt, C), "Hit", "the lawless NPC's rear hit lands")
			T.True(Ended("Bind:rescued", 0.2), "rescued (" .. tostring(HK.Result()) .. ")")
			task.wait(0.3)
			T.Eq(DeedCount("took_hostage") - Took0, 0, "nothing more recorded")
			Unstunned()
		end) end)
	end,
}

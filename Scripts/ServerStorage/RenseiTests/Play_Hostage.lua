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
			local Took0 = DeedCount("took_hostage")
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
}

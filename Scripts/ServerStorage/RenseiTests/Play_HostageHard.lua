-- Play_HostageHard (hostages plan Task 4, 2026-10-27; Tasks 6 and 10 extend it): the hard edges of a hostage hold. Run
-- in the game VM (LMRunSuite), every case inside HostageKit.Guard (the hook's snapshot armed AND DataManager.IsNoSave(),
-- pre-flight P16) with rigs it spawned itself (TakedownKit's kit Grunts) on TakedownKit's floor.
-- * Task 4: grips, carries and takedowns refuse a captor (Holding) or a hostage (HeldBy), both ways; a bound player
--   doesn't crawl; the knock's timer waits for a bind; DownedManager.EndKnock ends a knock without Recover's heal; and
--   (PvE stays PvE) no takedown ever accepts a player. Nothing sets Holding or HeldBy yet (HostageService, Task 5): the
--   cases set them by hand, "X" standing for the other party's name. Every expected number is written by hand.
-- * Task 6 (ruling R1, lesson I1): the led pair policed on the server. Each case holds a stand-in hostage with the REAL
--   player as the captor (HostageKit.Held), the player's root let go (HostageKit.Loose), so its client owns the pair as
--   in a real game. Written by hand (Rensei.Hostage, PROPOSAL): LeadAllowance(0.1) = (12 x 1.5 + 2.5) x 0.1 = 2.05 studs
--   per watch tick of 0.1 s; TeleportBreak 40; Offset 1.5 studs in front. The client half (a real client walking,
--   breaking its weld, a held client trying to move) is Art/Studio/Hostage/client_checks.lua.
-- * Task 6 fix round 1 (review I1-I4): a blink (too far, or through a wall or a floor) ends "teleport" with the hostage
--   put back at the last checked spot; so does any release in a clamp fight; a release never flings the hostage; a drop
--   faster than a free fall is put back (a real fall isn't); the rise rule's floor is world geometry, never a character
--   (stairs still climb, an accomplice underneath doesn't lift the pair). Written by hand: the free fall's bound is far
--   under a 25-stud drop in 0.1 s and far over a real 30-stud fall; RiseSlack 3.
-- * Task 7 (pre-flight P5; Task 6 re-review m1): a grab's pair is policed as a hold's (GrabbingClamped); a "broken" or
--   an "error" end puts the hostage back at the last checked spot at rest; a huge move is clamped before any ray.
-- * Task 10 (spec §3, decision 14, ruling R5): a captor's hands are full (no heavy, cast, shooting mode, emote or item)
--   and a hostage can't act (no traversal); the road, the train and the papers gate refuse a pair, and Depart drops a
--   held player (pre-flight P27: TravelService.Arrive stubbed, only Going asserted, and only under TestNoSave). Task 6
--   re-review m7: the gate's push carries the pair (its Rebased helper rebases the lead clamp); m2: a Rebase opens no
--   window to walk through a wall. The stations are safe zones (a pair moved there ends "safe" at the next watch tick),
--   so those cases answer HostageService.InSafeZone false while they run (put back after), and the papers verdict
--   (StationService.Gate) "Pass" (Wanted 0, whatever the loaded profile's Heat). Written by hand: the gate is 1 stud
--   thick and pushes 4 studs clear (StationService.GatePush), so the pushed root is at most -4.5 + 0.5 studs from it.
-- * Task 10 fix round 1: GateRefusesCaptor pushes 12 studs (past any lead allowance) and spies Rebase, so it proves m7;
--   a hostage at the gate is judged as the pair (m7 of the review); a light attack leaves the captor at LeadSpeed (m6);
--   a second Rebase keeps the first's echo (m3); the no-wall-window case goes through the wall ray (m8); the heavy works
--   again after Free (m1). The captor's dash (no i-frames, no stamina) is a real-client check in client_checks.lua.
-- * Task 13 (the sweep's perception leak): an NPC off the floor that saw the player just before a case doesn't carry
--   that sighting into it (TakedownKit.Guard holds PerceptionService's clock, so a fresh sighting would otherwise stay
--   fresh for the whole case and witness kit-floor deeds: the GateGuard at the station rest spot, Tobin after Play_Assault).
local DM = require(game.ReplicatedStorage.Modules.Managers.DownedManager)
local ServerStorage = game:GetService("ServerStorage")
local SSS = game:GetService("ServerScriptService")
local TK = require(script.Parent.TakedownKit)
local SmokeKit = require(script.Parent.SmokeKit) -- RemoveEnemy: a refused case's rig goes before its control
local HK = require(script.Parent.HostageKit)
local Player = TK.Player()
local C = Player.Character

local GunKit = require(script.Parent.GunKit) -- (Task 10) Unequip: the player's own weapon put away before a test Revolver
local WCS = require(game.ReplicatedStorage.Modules.Framework.WCS)
local MovementState = require(game.ReplicatedStorage.Modules.Managers.MovementState)
local CollectionService = game:GetService("CollectionService")
local At, NEAR, Free, Behind, Calm = TK.At, TK.NEAR, TK.Free, TK.Behind, TK.Calm
local WaitFor, Finished, Result = TK.WaitFor, TK.Finished, TK.Result

-- a kit Grunt at (X, Z), lying free and knocked (Knock's own length unless Seconds)
local function KnockedGrunt(X, Z, Seconds)
	local Rig = Free(TK.Spawn("Grunt", At(X, Z)))
	DM.Knock(Rig, Seconds)
	return Rig
end
-- the player knocked on the kit floor with a 60 s knock (Second Wind marked used, so it stays 60 s); HostageKit.Guard
-- puts KnockedTime, SecondWindUsed and the health back, and ends a knock left on
local function KnockPlayer(ByDamage)
	TK.PutPlayer(At(0, 10) + Vector3.new(0, 3, 0))
	C:SetAttribute("KnockedTime", 60)
	C:SetAttribute("SecondWindUsed", true)
	if ByDamage then DM.Damage(C, C.Humanoid.Health) else DM.Knock(C) end
	return DM.IsKnocked(C)
end

-- (Task 6) the led pair: the hostage service, the player's root, the clamp's counter, the hold's state
local OFFSET = CFrame.new(0, 0, -1.5) -- written by hand: the hostage's root 1.5 studs in front of the captor's
local function Svc()
	local M = SSS:FindFirstChild("HostageService")
	assert(M, "HostageService exists")
	return require(M)
end
local function CRoot() return C.HumanoidRootPart end
local function Clamped() return C:GetAttribute("HostageClamped") or 0 end
local function Ground(A, B) return Vector3.new(A.X - B.X, 0, A.Z - B.Z).Magnitude end
local function On(S) return not S.Over and Svc().SessionOf(Player) == S end
local function Ended(Want, Max) return WaitFor(Max, function() return HK.Result() == Want end) end
local function F2(X) return ("%.2f"):format(X) end
local function Dist(A, B) return (A - B).Magnitude end
-- (fix round) the lead's window made fresh: the root stepped back 0.5 studs three times, 0.1 s apart (an honest walk),
-- so the lead's time is at most a tick or two old and a jump right after is measured against a tick's allowance, not
-- the up-to-1-s window a root left standing still earns (LeadWindow: a hitch's longest gap, by design)
local function Fresh()
	for _ = 1, 3 do
		CRoot().CFrame += CRoot().CFrame.LookVector * -0.5
		task.wait(0.1)
	end
end
-- a TEMP anchored part (SmokeKit removes it after the case)
local function Block(Size, At) return SmokeKit.TempPart({Name = "HostageHard_TEMP_Block", Size = Size, CFrame = At}) end
-- (Task 10) the travel cases' routes (rail and road; both places sit on both) and the lines they expect, by hand
local RAIL, ROAD = "LindenmoorFoundry", "RoadLindenmoorFoundry"
local NO_ROAD = "You can't cross while you're down, held or holding someone."
local NO_BOARD = "Conductor: \"You can't bring them aboard like that.\""
local NO_GATE = "Guard: \"Let them go first.\""
-- (Task 10) a deliberate server move of the led pair: the captor's root put at CF at rest, then HostageService.Rebase
local function MovePair(T, CF)
	CRoot().CFrame = CF
	CRoot().AssemblyLinearVelocity = Vector3.zero
	T.Eq(Svc().Rebase(C), true, "setup: the moved pair rebased")
end
-- (Task 10) Body with HostageService.InSafeZone answering false and StationService.Gate answering Papers.Verdict ("Pass"
-- unless the case sets another; fix round 1), both put back after (even when Body fails)
local function AtStation(Body, Papers)
	Papers = Papers or {Verdict = "Pass"}
	local HS, SS = Svc(), require(SSS.StationService)
	local RealSafe, RealGate = HS.InSafeZone, SS.Gate
	HS.InSafeZone = function() return false end
	SS.Gate = function() return Papers.Verdict end
	local Ok, Err = pcall(Body)
	HS.InSafeZone, SS.Gate = RealSafe, RealGate
	if not Ok then error(Err, 0) end
end
-- (fix round 1, review I1) the gate's push for the m7 case, by hand: 12 studs (StationService.GatePush is 4), past any
-- lead allowance in the window (LeadAllowance(<= 0.3 s) <= 6.15 studs) and under TeleportBreak 40
local GATE_PUSH = 12
local function TheGate() return CollectionService:GetTagged("RenseiStationGate")[1] end
local function HallSide(Gate) return (CRoot().Position - Gate.Position):Dot(Gate.CFrame.LookVector) end
local function BoardZone() -- a 3rd-class BoardZone inside the platform train (as Play_Station's Zone finds one)
	for _, D in ipairs(workspace:GetDescendants()) do
		if D.Name:find("BoardZone") and D:GetAttribute("CarKind") == "ThirdClass" and D:FindFirstAncestor("PlatformTrain") then return D end
	end
end

-- Held, the player's client owning the pair (its root let go); the counter starts at 0
local function Led(T)
	local Rig, PL, S = HK.Held()
	HK.Loose()
	T.True(S ~= nil and On(S), "setup: the pair is held")
	T.Eq(Clamped(), 0, "setup: nothing put back yet")
	return Rig, PL, S
end

return {
	-- B with Holding on the player (a captor) grips nothing; the control, Holding cleared, grips a fresh knocked Grunt
	GripRefusesHolder = function(T)
		HK.Guard(function()
			local Rig = KnockedGrunt(0, 0)
			TK.PutPlayer(NEAR)
			Calm()
			T.True(DM.IsKnocked(Rig), "setup: a knocked Grunt in reach")
			C:SetAttribute("Holding", "X")
			T.Eq(DM.Request(C, "Grip"), nil, "B while Holding grips nothing")
			T.Eq(Rig:GetAttribute("GrippedBy"), nil, "the Grunt isn't gripped")
			T.True(Rig.Humanoid.Health > 0, "and lives")
			C:SetAttribute("Holding", nil)
			SmokeKit.RemoveEnemy(Rig)
			local Other = KnockedGrunt(0, 0)
			TK.PutPlayer(NEAR)
			T.Eq(DM.Request(C, "Grip"), "Gripped", "control: Holding cleared, B grips")
			T.True(Other.Humanoid.Health <= 0, "control: the grip finished it")
		end)
	end,

	-- V with HeldBy on the player (a hostage) carries nothing; the control, HeldBy cleared, carries the Grunt
	CarryRefusesHeld = function(T)
		HK.Guard(function()
			local Rig = KnockedGrunt(0, 0)
			TK.PutPlayer(NEAR)
			Calm()
			T.True(DM.IsKnocked(Rig), "setup: a knocked Grunt in reach")
			C:SetAttribute("HeldBy", "X")
			local Got = DM.Request(C, "Carry")
			T.True(Got ~= "Carry", "V while HeldBy carries nothing (" .. tostring(Got) .. ")")
			T.Eq(C:GetAttribute("Carrying"), nil, "the player isn't carrying")
			T.Eq(Rig:GetAttribute("CarriedBy"), nil, "the Grunt isn't picked up")
			if C:GetAttribute("Carrying") then DM.Drop(C) end -- (RED: the control starts from no carry)
			C:SetAttribute("HeldBy", nil)
			TK.PutPlayer(NEAR)
			T.Eq(DM.Request(C, "Carry"), "Carry", "control: HeldBy cleared, V carries")
			T.Eq(Rig:GetAttribute("CarriedBy"), C.Name, "control: CarriedBy")
			DM.Drop(C)
		end)
	end,

	-- a knocked Grunt marked as a hostage (HeldBy) or a captor (Holding) is never carried (Takeable); cleared, it is
	TakeableRefusesHeld = function(T)
		HK.Guard(function()
			local Rig = KnockedGrunt(0, 0)
			TK.PutPlayer(NEAR)
			Calm()
			for _, Mark in ipairs({"HeldBy", "Holding"}) do
				Rig:SetAttribute(Mark, "X")
				T.Eq(DM.Carry(C, Rig), false, "a knocked Grunt with " .. Mark .. " isn't carried")
				T.Eq(Rig:GetAttribute("CarriedBy"), nil, Mark .. ": not CarriedBy")
				if C:GetAttribute("Carrying") then DM.Drop(C) end -- (RED: the next check starts from no carry)
				Rig:SetAttribute(Mark, nil)
				TK.PutPlayer(NEAR)
			end
			T.Eq(DM.Carry(C, Rig), true, "control: unmarked, carried")
			DM.Drop(C)
		end)
	end,

	-- the knocked player crawls at CrawlSpeed 3; marked HeldBy (being bound) it stops at once: KnockedSpeed 0 and the
	-- watch's walk 0. Cleared and recovered, the player is up.
	CrawlStopsWhenBound = function(T)
		HK.Guard(function()
			T.True(KnockPlayer(), "setup: the player is knocked")
			local H = C.Humanoid
			T.Eq(DM.KnockedSpeed(C), 3, "knocked: crawls at CrawlSpeed 3")
			C:SetAttribute("HeldBy", "X")
			T.Eq(DM.KnockedSpeed(C), 0, "HeldBy: KnockedSpeed 0")
			T.Eq(DM.CanCrawl(C), false, "HeldBy: can't crawl")
			task.wait(0.35) -- a few of the knock's watch ticks (CrawlCheck 0.1)
			T.Eq(H.WalkSpeed, 0, "HeldBy: the watch holds the walk at 0")
			C:SetAttribute("HeldBy", nil)
			DM.Recover(C)
			T.Eq(DM.IsKnocked(C), false, "cleared and recovered: up")
		end)
	end,

	-- a Grunt knocked for 0.5 s and marked HeldBy is still knocked after 1 s (a bind in progress decides it); the
	-- control, knocked for 0.5 s with no mark, has recovered
	RecoverWaitsForBind = function(T)
		HK.Guard(function()
			local Held = KnockedGrunt(-10, 0, 0.5)
			Held:SetAttribute("HeldBy", "X")
			local Plain = KnockedGrunt(10, 0, 0.5)
			T.True(DM.IsKnocked(Held) and DM.IsKnocked(Plain), "setup: both knocked")
			task.wait(1)
			T.Eq(DM.IsKnocked(Held), true, "HeldBy: still knocked after 1 s")
			T.Eq(DM.IsKnocked(Plain), false, "control: no mark, recovered after 1 s")
		end)
	end,

	-- EndKnock(C, 0.15): the player knocked at 1 HP is up at 15% of max health (+-1), not Recover's share; at 60% they
	-- stay at 60%; a gripped knocked rig, a standing one and a dead one are refused
	EndKnockKeepsHP = function(T)
		HK.Guard(function()
			local H = C.Humanoid
			T.True(KnockPlayer(true), "setup: knocked by a lethal hit")
			T.Eq(H.Health, 1, "setup: at 1 HP")
			T.Eq(DM.EndKnock(C, 0.15), true, "EndKnock")
			T.Eq(C:GetAttribute("Knocked"), nil, "Knocked cleared")
			T.Eq(C:GetAttribute("KnockedUntil"), nil, "KnockedUntil cleared")
			T.Eq(C:GetAttribute("KnockedStill"), nil, "KnockedStill cleared")
			T.Near(H.Health, 0.15 * H.MaxHealth, 1, "15% of max health")
			T.True(H.WalkSpeed > 3, "the walk lock given back: " .. H.WalkSpeed)
			T.True(KnockPlayer(), "setup: knocked again")
			H.Health = 0.6 * H.MaxHealth -- (set while knocked, right before: no regeneration in between)
			T.Eq(DM.EndKnock(C, 0.15), true, "EndKnock at 60%")
			T.Near(H.Health, 0.6 * H.MaxHealth, 1, "stays at 60%")
			local Gripped = KnockedGrunt(0, 0)
			Gripped:SetAttribute("GrippedBy", "X")
			T.Eq(DM.EndKnock(Gripped, 0.15), false, "a gripped knocked rig: refused")
			T.Eq(DM.IsKnocked(Gripped), true, "and still knocked")
			local Standing = TK.Spawn("Grunt", At(10, 0))
			T.Eq(DM.EndKnock(Standing, 0.15), false, "a rig that isn't knocked: refused")
			local Dead = KnockedGrunt(-10, 0)
			Dead.Humanoid.Health = 0
			T.Eq(DM.EndKnock(Dead, 0.15), false, "a dead rig: refused")
		end)
	end,

	-- N with Holding or HeldBy on the player: refused "busy", nothing marked; the control, cleared, takes the Grunt down
	TakedownRefusesHolder = function(T)
		HK.Guard(function()
			for _, Mark in ipairs({"Holding", "HeldBy"}) do
				local Rig = Behind()
				C:SetAttribute(Mark, "X")
				TK.Refused(T, Rig, "busy", Mark)
				C:SetAttribute(Mark, nil)
				Finished(3) -- (RED: a takedown that started ends before the next)
				SmokeKit.RemoveEnemy(Rig)
				TK.Service().Forget(Player)
			end
			local Rig = Behind()
			local Ok, Why = TK.Assassinate(Rig)
			T.Eq(Ok, true, "control: cleared, accepted")
			T.Eq(Why, "started", "control: started")
			T.True(Finished(3), "control: ended")
			T.Eq(Result(), "Assassinate:ok", "control: done")
		end)
	end,

	-- a Grunt marked HeldBy or Holding (no NPC carries them today: the "both ways" guard) is refused "target_busy"; the
	-- control, unmarked, is taken down
	TakedownRefusesHeldTarget = function(T)
		HK.Guard(function()
			for _, Mark in ipairs({"HeldBy", "Holding"}) do
				local Rig = Behind()
				Rig:SetAttribute(Mark, "X")
				TK.Refused(T, Rig, "target_busy", Mark)
				Finished(3) -- (RED: a takedown that started ends before the next)
				SmokeKit.RemoveEnemy(Rig)
				TK.Service().Forget(Player)
			end
			local Rig = Behind()
			T.Eq(TK.Assassinate(Rig), true, "control: unmarked, accepted")
			T.True(Finished(3), "control: ended")
			T.Eq(Result(), "Assassinate:ok", "control: done")
		end)
	end,

	-- PvE (owner rule): a takedown of the player's own character is refused "player", and nothing is marked. A regression
	-- guard: it passes before Task 4 too (Takedown.Check refuses a player first)
	TakedownNeverAPlayer = function(T)
		HK.Guard(function()
			Calm()
			local Ok, Why = TK.Service().Request(Player, "Assassinate", Player.Character)
			T.Eq(Ok, false, "refused")
			T.Eq(Why, "player", "the reason")
			T.Eq(C:GetAttribute("TakenDownBy"), nil, "no TakenDownBy on the character")
			T.Eq(C:GetAttribute("TakingDown"), nil, "the player isn't marked TakingDown")
		end)
	end,

	-- the save guard (pre-flight P16): HostageKit.Guard refuses, before the case runs, when DataManager.IsNoSave() isn't
	-- true (its _NoSave seam swapped, then put back) or the hook's snapshot isn't armed; the control, both true, runs
	GuardNeedsNoSaveAndSnapshot = function(T)
		local Real = HK._NoSave
		T.Eq(Real(), true, "setup: this session is TestNoSave (DataManager.IsNoSave())")
		local Ran = false
		HK._NoSave = function() return false end
		local Ok, Err = pcall(HK.Guard, function() Ran = true end)
		HK._NoSave = Real
		T.Eq(Ok, false, "refused when IsNoSave() is false")
		T.Eq(Ran, false, "the case never ran")
		T.True(tostring(Err):find("IsNoSave", 1, true) ~= nil, "it says why: " .. tostring(Err))
		local Was = ServerStorage:GetAttribute("LMSnapTaken")
		T.True(Was ~= nil, "setup: the hook's snapshot is armed for this run")
		ServerStorage:SetAttribute("LMSnapTaken", nil)
		Ok, Err = pcall(HK.Guard, function() Ran = true end)
		ServerStorage:SetAttribute("LMSnapTaken", Was)
		T.Eq(Ok, false, "refused without the snapshot")
		T.Eq(Ran, false, "the case never ran")
		T.True(tostring(Err):find("snapshot", 1, true) ~= nil, "it says why: " .. tostring(Err))
		HK.Guard(function() Ran = true end)
		T.Eq(Ran, true, "control: both true, the case runs")
	end,

	-- (Task 13) a real watcher (RenseiWatcher, tracked by PerceptionService, not one of the kit's rigs) glimpses the
	-- player from a few studs in front just before a case; inside HostageKit.Guard nobody perceives the player any more
	-- (PerceptionService.Perceived: what WitnessService.Capture reads), so no deed on the floor is witnessed from town.
	-- The watcher is reset and the player put back after.
	GuardForgetsRealSightings = function(T)
		local PS = require(SSS.PerceptionService)
		local Home = C:GetPivot()
		local W
		local function Sees()
			for _, S in ipairs(PS.Perceived(Player)) do if S.Rig == W then return true end end
			return false
		end
		local Inside
		local Ok, Err = pcall(function()
			-- the first watcher that sees the player from a few studs in front (a crate or a wall can block one)
			for _, M in ipairs(CollectionService:GetTagged("RenseiWatcher")) do
				if M:IsDescendantOf(workspace) and PS.Tracks(M) and M:FindFirstChild("Head") and M:FindFirstChild("HumanoidRootPart") then
					W = M
					local R = M.HumanoidRootPart
					for _, D in ipairs({4, 6, 8, 3}) do
						local Pos = R.Position + R.CFrame.LookVector * D
						C:PivotTo(CFrame.lookAt(Pos, Vector3.new(R.Position.X, Pos.Y, R.Position.Z)))
						task.wait(0.3)
						PS.Glimpse(Player)
						if Sees() then break end
					end
					if Sees() then break end
					PS.Reset(M)
					W = nil
				end
			end
			T.True(W ~= nil and Sees(), "setup: a real watcher saw the player just before the case")
			HK.Guard(function()
				Inside = {}
				for _, S in ipairs(PS.Perceived(Player)) do table.insert(Inside, S.Rig.Name) end
			end)
		end)
		PS.Reset(W)
		C:PivotTo(Home)
		C.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
		T.True(Ok, tostring(Err))
		T.Eq(#Inside, 0, "nobody perceives the player inside the case (" .. table.concat(Inside, ", ") .. ")")
	end,

	-- ===== Task 6: the led pair policed (R1) =====
	-- the captor's root moved 8 studs in one step (well over 2.05 a tick): put back within 1 stud of where it was within
	-- 0.3 s, counted, and the hold is still on
	LeadClamped = function(T)
		HK.Guard(function()
			local _, _, S = Led(T)
			Fresh()
			local P0 = CRoot().Position
			CRoot().CFrame += CRoot().CFrame.LookVector * 8
			local Back = WaitFor(0.3, function() return Ground(CRoot().Position, P0) <= 1 and Clamped() >= 1 end)
			T.True(Back, "put back within 0.3 s")
			T.True(Ground(CRoot().Position, P0) <= 1, "within 1 stud of where it was (" .. F2(Ground(CRoot().Position, P0)) .. ")")
			T.True(Clamped() >= 1, "HostageClamped counted (" .. Clamped() .. ")")
			T.True(On(S), "the hold is still on (" .. tostring(HK.Result()) .. ")")
		end)
	end,

	-- the captor's root moved 60 studs (over TeleportBreak 40): the hold ends "teleport"; (fix round I1) the stand-in is
	-- put back at the last checked spot (1.5 studs in front of where the captor stood), never left where the client put it
	TeleportEnds = function(T)
		HK.Guard(function()
			local Rig = Led(T)
			local Good = CRoot().CFrame
			local To = Good + Vector3.new(60, 0, 0)
			CRoot().CFrame = To
			T.True(Ended("Bind:teleport", 0.5), "\"teleport\" within 0.5 s (" .. tostring(HK.Result()) .. ")")
			T.Eq(Rig:GetAttribute("HeldBy"), nil, "the stand-in is free")
			T.Eq(CRoot():FindFirstChild("DownedWeld"), nil, "no weld on the player's root")
			local HR = Rig.HumanoidRootPart.Position
			T.True(Dist(HR, (Good * OFFSET).Position) <= 1, "the stand-in is back at the last checked spot ("
				.. F2(Dist(HR, (Good * OFFSET).Position)) .. " studs off)")
			T.True(Ground(HR, To.Position) > 50, "not left where the client put it (" .. F2(Ground(HR, To.Position)) .. " studs off)")
		end)
	end,

	-- (fix round I1) a client fighting the clamp (its spot 6 studs off re-applied every frame), then a release mid-fight:
	-- the stand-in is left at the last checked spot, not at the client's
	ClampFightSnapsBack = function(T)
		HK.Guard(function()
			local Rig = Led(T)
			Fresh()
			local Good = CRoot().CFrame
			local Fight = Good + Vector3.new(6, 0, 0)
			-- (the client's spot, written again after each put-back: twice, so the clamp has fought it)
			for _ = 1, 2 do
				CRoot().CFrame = Fight
				local Before = Clamped()
				WaitFor(0.5, function() return Clamped() > Before end)
			end
			T.True(Clamped() >= 2, "setup: the clamp fought back (" .. Clamped() .. " put-backs)")
			CRoot().CFrame = Fight -- (the client's last word, then the release in the same step)
			T.Eq(Svc().Free(Player, "released"), true, "released mid-fight")
			task.wait(0.2)
			local HR = Rig.HumanoidRootPart.Position
			T.True(Dist(HR, (Good * OFFSET).Position) <= 1, "the stand-in is at the last checked spot ("
				.. F2(Dist(HR, (Good * OFFSET).Position)) .. " studs off; " .. F2(Dist(HR, (Fight * OFFSET).Position))
				.. " from the client's)")
		end)
	end,

	-- (fix round I2) the pair moving fast at a release (100 studs/s up and a spin, the velocity a captor's client can give
	-- it): the stand-in isn't flung (it stays where it was let go, at rest, not spinning). Both sides are stand-ins here,
	-- so the server owns the pair and its velocity write is the one released (with the player as the captor, the watch
	-- keeps the pair the player's client's and the client's packets overwrite a server write). Before the fix (measured):
	-- the stand-in rose 21 studs in 0.3 s.
	NoFlingAtRelease = function(T)
		HK.Guard(function()
			local Rig = HK.StandIn(TK.At(0, 0))
			DM.Knock(Rig)
			local Cap, CapPL = HK.StandIn(TK.At(0, 3)) -- (facing -Z: the knocked stand-in 3 studs in front of it)
			local Ok, Why = Svc().Take(CapPL, Rig)
			T.Eq(Ok, true, "setup: the stand-in captor's take starts (" .. tostring(Why) .. ")")
			T.True(WaitFor(2.0, function()
				local X = Svc().SessionOf(CapPL)
				return X ~= nil and X.State == "Held"
			end), "setup: held within 2 s (" .. tostring(HK.Result(Cap)) .. ")")
			local HR, CapRoot = Rig.HumanoidRootPart, Cap.HumanoidRootPart
			CapRoot.AssemblyLinearVelocity = Vector3.new(0, 100, 0)
			CapRoot.AssemblyAngularVelocity = Vector3.new(0, 30, 0)
			local VBefore, P1 = HR.AssemblyLinearVelocity.Magnitude, HR.Position
			T.Eq(Svc().Free(CapPL, "released"), true, "released (in the same step)")
			CapRoot.AssemblyLinearVelocity, CapRoot.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
			T.True(VBefore > 50, "setup: the pair was moving fast at the release (" .. F2(VBefore) .. " studs/s)")
			task.wait(0.3)
			T.True(Dist(HR.Position, P1) < 3, "not flung (" .. F2(Dist(HR.Position, P1)) .. " studs from where it was let go)")
			T.True(HR.AssemblyLinearVelocity.Magnitude < 5, "at rest (" .. F2(HR.AssemblyLinearVelocity.Magnitude) .. " studs/s)")
			T.True(HR.AssemblyAngularVelocity.Magnitude < 2, "not spinning (" .. F2(HR.AssemblyAngularVelocity.Magnitude) .. " rad/s)")
		end)
	end,

	-- (fix round I3) the pair through the kit floor (20 studs straight down: a noclip): a blink, "teleport", and the
	-- stand-in back at the last checked spot, above the floor
	NoclipDropEnds = function(T)
		HK.Guard(function()
			local Rig = Led(T)
			local Good = CRoot().CFrame
			CRoot().CFrame = Good - Vector3.new(0, 20, 0)
			T.True(Ended("Bind:teleport", 0.3), "\"teleport\" within 0.3 s (" .. tostring(HK.Result()) .. ")")
			local HR = Rig.HumanoidRootPart.Position
			T.True(Dist(HR, (Good * OFFSET).Position) <= 1, "the stand-in is back above the floor ("
				.. F2(Dist(HR, (Good * OFFSET).Position)) .. " studs off)")
		end)
	end,

	-- (fix round I3) the pair through a wall (an anchored TEMP wall 3 studs to the side, the root moved 6 studs past it):
	-- a blink, "teleport", the stand-in back on this side (LeadClamped is the control: the same kind of move, no wall,
	-- is only put back)
	BlinkThroughWallEnds = function(T)
		HK.Guard(function()
			local Rig = Led(T)
			local Good = CRoot().CFrame
			Block(Vector3.new(0.4, 12, 12), CFrame.new(Good.Position + Vector3.new(3, 0, 0)))
			CRoot().CFrame = Good + Vector3.new(6, 0, 0)
			T.True(Ended("Bind:teleport", 0.3), "\"teleport\" within 0.3 s (" .. tostring(HK.Result()) .. ")")
			local HR = Rig.HumanoidRootPart.Position
			T.True(Dist(HR, (Good * OFFSET).Position) <= 1, "the stand-in is back on this side of the wall ("
				.. F2(Dist(HR, (Good * OFFSET).Position)) .. " studs off)")
		end)
	end,

	-- (fix round I3) the pair on a TEMP platform 30 studs up (moved there, then Rebase), the platform removed and the root
	-- at once 25 studs lower (in 0.1 s, far past a free fall): put back, counted, still held
	DropTooFastPutBack = function(T)
		HK.Guard(function()
			local _, _, S = Led(T)
			local P0 = CRoot().Position
			local Top = Block(Vector3.new(12, 1, 12), CFrame.new(P0.X, P0.Y - 3 + 30 - 0.5, P0.Z - 0.75))
			CRoot().CFrame += Vector3.new(0, 30, 0)
			T.Eq(Svc().Rebase(C), true, "setup: rebased on the platform")
			task.wait(0.8)
			Top:Destroy()
			CRoot().CFrame -= Vector3.new(0, 25, 0)
			T.True(WaitFor(0.3, function() return Clamped() >= 1 end), "put back within 0.3 s (" .. Clamped() .. ")")
			T.True(On(S), "the hold is still on (" .. tostring(HK.Result()) .. ")")
		end)
	end,

	-- (fix round I3, the control) the same platform removed with nothing else: the pair falls 30 studs for real onto the
	-- kit floor, never put back, still held
	FallOk = function(T)
		HK.Guard(function()
			local _, _, S = Led(T)
			local P0 = CRoot().Position
			local Top = Block(Vector3.new(12, 1, 12), CFrame.new(P0.X, P0.Y - 3 + 30 - 0.5, P0.Z - 0.75))
			CRoot().CFrame += Vector3.new(0, 30, 0)
			T.Eq(Svc().Rebase(C), true, "setup: rebased on the platform")
			task.wait(0.8)
			Top:Destroy()
			T.True(WaitFor(3, function() return CRoot().Position.Y - P0.Y < 1 end), "landed on the kit floor ("
				.. F2(CRoot().Position.Y - P0.Y) .. " studs above it)")
			task.wait(0.3)
			T.Eq(Clamped(), 0, "never put back")
			T.True(On(S), "the hold is still on (" .. tostring(HK.Result()) .. ")")
		end)
	end,

	-- (fix round I4, the control) six TEMP steps of 0.8 studs, 2 studs wide, the root moved up them one per 0.2 s: 4.8
	-- studs climbed (over RiseSlack 3: each step is floor), never put back
	StairsClimbOk = function(T)
		HK.Guard(function()
			local _, _, S = Led(T)
			local Good = CRoot().CFrame
			local P0 = Good.Position
			for K = 1, 6 do
				local H = 0.8 * K
				Block(Vector3.new(2, H, 8), CFrame.new(P0.X + 2 * K, P0.Y - 3 + H / 2, P0.Z - 0.75))
			end
			for K = 1, 6 do
				CRoot().CFrame = Good + Vector3.new(2 * K, 0.8 * K, 0)
				task.wait(0.2)
			end
			task.wait(0.3)
			T.Eq(Clamped(), 0, "never put back")
			T.True(CRoot().Position.Y - P0.Y >= 4, "up the stairs (" .. F2(CRoot().Position.Y - P0.Y) .. " studs)")
			T.True(On(S), "the hold is still on (" .. tostring(HK.Result()) .. ")")
		end)
	end,

	-- (fix round I4) an accomplice rig (anchored, a character) kept just under the captor's feet while the server raises
	-- the captor 2.5 studs a tick: a character is no floor, so the rise is put back by the second tick
	AccompliceNoRise = function(T)
		HK.Guard(function()
			local _, _, S = Led(T)
			local Acc = HK.StandIn(TK.At(20, 20))
			Acc.HumanoidRootPart.Anchored = true
			local Good = CRoot().CFrame
			for K = 1, 4 do
				CRoot().CFrame = Good + Vector3.new(0, 2.5 * K, 0)
				local R = CRoot().Position
				Acc:PivotTo(CFrame.new(R.X, R.Y - 5.3, R.Z)) -- (its head 0.3 under the captor's feet)
				task.wait(0.1)
			end
			Acc:PivotTo(TK.At(20, 20) + Vector3.new(0, 3, 0))
			T.True(Clamped() >= 1, "the rise was put back (" .. Clamped() .. ")")
			T.True(On(S), "the hold is still on (" .. tostring(HK.Result()) .. ")")
		end)
	end,

	-- the weld destroyed on the server: "broken" within 0.3 s
	PairBroken = function(T)
		HK.Guard(function()
			local Rig = Led(T)
			local W = CRoot():FindFirstChild("DownedWeld")
			T.True(W ~= nil, "setup: the pair is welded")
			W:Destroy()
			T.True(Ended("Bind:broken", 0.3), "\"broken\" within 0.3 s (" .. tostring(HK.Result()) .. ")")
			T.Eq(Rig:GetAttribute("HeldBy"), nil, "the stand-in is free")
		end)
	end,

	-- the stand-in's WalkSpeed 16, JumpHeight 7.2 and PlatformStand false, written by the test: all back within 0.3 s
	HostageStaysPut = function(T)
		HK.Guard(function()
			local Rig, _, S = Led(T)
			local H = Rig.Humanoid
			H.WalkSpeed, H.JumpHeight, H.PlatformStand = 16, 7.2, false
			local Back = WaitFor(0.3, function() return H.WalkSpeed == 0 and H.JumpHeight == 0 and H.PlatformStand == true end)
			T.True(Back, "written back within 0.3 s")
			T.Eq(H.WalkSpeed, 0, "WalkSpeed")
			T.Eq(H.JumpHeight, 0, "JumpHeight")
			T.Eq(H.PlatformStand, true, "PlatformStand")
			T.True(On(S), "the hold is still on")
		end)
	end,

	-- a Tool parented to the stand-in by the test: back in its Backpack (a stand-in's: a TEMP folder the test gives it)
	-- within 0.3 s, in no character
	ToolPutAway = function(T)
		HK.Guard(function()
			local Rig, PL, S = Led(T)
			local Bag = Instance.new("Folder")
			Bag.Name = "HostageHard_TEMP_Backpack"
			Bag.Parent = ServerStorage
			PL.Backpack = Bag
			local Tool = Instance.new("Tool")
			Tool.Name = "HostageHard_TEMP_Tool"
			Tool.RequiresHandle = false
			local Ok, Err = pcall(function()
				Tool.Parent = Rig
				T.True(WaitFor(0.3, function() return Tool.Parent == Bag end), "put away within 0.3 s (in "
					.. tostring(Tool.Parent and Tool.Parent:GetFullName()) .. ")")
				T.True(Tool:FindFirstAncestorOfClass("Model") == nil, "in no character")
				T.True(On(S), "the hold is still on")
			end)
			PL.Backpack = nil
			Tool:Destroy()
			Bag:Destroy()
			if not Ok then error(Err, 0) end
		end)
	end,

	-- SwimService.InDeepWater says true for the stand-in (a stub, put back after): "water" within 0.3 s
	WaterEnds = function(T)
		HK.Guard(function()
			local Rig = Led(T)
			local Swim = require(SSS.SwimService)
			local Real = Swim.InDeepWater
			Swim.InDeepWater = function(M) if M == Rig then return true end return Real(M) end
			local Ok, Err = pcall(function()
				T.True(Ended("Bind:water", 0.3), "\"water\" within 0.3 s (" .. tostring(HK.Result()) .. ")")
			end)
			Swim.InDeepWater = Real
			if not Ok then error(Err, 0) end
			T.Eq(Rig:GetAttribute("HeldBy"), nil, "the stand-in is free")
		end)
	end,

	-- the control: the captor's root moved 1 stud per 0.1 s for 2 s (10 studs/s, under the lead's 12): never put back,
	-- the hold still on, and it really went (at least 10 of the 20 studs; the client's echo may take a little back)
	NormalLeadOk = function(T)
		HK.Guard(function()
			local _, _, S = Led(T)
			local P0 = CRoot().Position
			local Dir = CRoot().CFrame.LookVector
			for _ = 1, 20 do
				CRoot().CFrame += Dir
				task.wait(0.1)
			end
			T.Eq(Clamped(), 0, "never put back")
			T.True(On(S), "the hold is still on (" .. tostring(HK.Result()) .. ")")
			T.True(Ground(CRoot().Position, P0) >= 10, "the pair went with it (" .. F2(Ground(CRoot().Position, P0)) .. " studs)")
		end)
	end,

	-- (pre-flight P6) a deliberate server move of 8 studs, then HostageService.Rebase: the pair stays where the server put
	-- it, nothing is counted, the hold is still on (LeadClamped is the control: the same move without Rebase is put back)
	RebaseKeepsTheMove = function(T)
		HK.Guard(function()
			local Rig, _, S = Led(T)
			local To = CRoot().CFrame + Vector3.new(8, 0, 0)
			CRoot().CFrame = To
			T.Eq(Svc().Rebase(C), true, "Rebase(the captor) rebased the pair")
			task.wait(0.5)
			T.True(Ground(CRoot().Position, To.Position) <= 1, "it stays where the server put it ("
				.. F2(Ground(CRoot().Position, To.Position)) .. " studs off)")
			T.Eq(Clamped(), 0, "nothing counted")
			T.True(On(S), "the hold is still on (" .. tostring(HK.Result()) .. ")")
			T.Eq(Svc().Rebase(Rig), true, "Rebase(the hostage) rebases the same pair")
			Svc().Free(Player, "released")
			T.Eq(Svc().Rebase(C), false, "control: no led pair, nothing to rebase")
		end)
	end,

	-- (Task 7, pre-flight P5) a grab's welded pair is policed as a hold's: the captor at LeadSpeed 12 from the weld, and
	-- its root moved 8 studs mid-grab is put back while the grab goes on
	GrabbingClamped = function(T)
		HK.Guard(function()
			local _, _, S = HK.Grabbed()
			T.Eq(C.Humanoid.WalkSpeed, 12, "the captor walks at LeadSpeed 12 from the weld")
			HK.Loose()
			T.Eq(Clamped(), 0, "setup: nothing put back yet")
			Fresh()
			local P0 = CRoot().Position
			CRoot().CFrame += CRoot().CFrame.LookVector * 8
			local Back = WaitFor(0.3, function() return Ground(CRoot().Position, P0) <= 1 and Clamped() >= 1 end)
			T.True(Back, "put back within 0.3 s (" .. F2(Ground(CRoot().Position, P0)) .. " studs off, " .. Clamped() .. " counted)")
			T.True(On(S) and S.State == "Grabbing", "the grab goes on (" .. tostring(S.State) .. ", " .. tostring(HK.Result()) .. ")")
		end)
	end,

	-- (Task 7, Task 6 re-review m1) a "broken" end puts the hostage back at the last checked spot x Offset, at rest: the
	-- captor's client never decides where a hostage it broke away is left, nor how fast
	BrokenSnapsBack = function(T)
		HK.Guard(function()
			local Rig = Led(T)
			local Good = CRoot().CFrame
			local HR = Rig.HumanoidRootPart
			CRoot():FindFirstChild("DownedWeld"):Destroy()
			HR.CFrame += Vector3.new(6, 0, 0)
			HR.AssemblyLinearVelocity = Vector3.new(0, 0, 40)
			T.True(Ended("Bind:broken", 0.3), "\"broken\" within 0.3 s (" .. tostring(HK.Result()) .. ")")
			local Off = Dist(HR.Position, (Good * OFFSET).Position)
			T.True(Off <= 1, "put back at the last checked spot (" .. F2(Off) .. " studs off)")
			T.True(HR.AssemblyLinearVelocity.Magnitude < 5, "at rest (" .. F2(HR.AssemblyLinearVelocity.Magnitude) .. " studs/s)")
		end)
	end,

	-- (Task 7, Task 6 re-review m1) so does an "error" end (Broken made to fail; it warns twice by design)
	ErrorSnapsBack = function(T)
		HK.Guard(function()
			local Rig = Led(T)
			local Good = CRoot().CFrame
			local HR = Rig.HumanoidRootPart
			local HS = Svc()
			local Real = HS.Broken
			local Ok, Err = pcall(function()
				HS.Broken = function() error("Play_HostageHard: Broken made to fail") end
				CRoot():FindFirstChild("DownedWeld"):Destroy()
				HR.CFrame += Vector3.new(6, 0, 0)
				HR.AssemblyLinearVelocity = Vector3.new(0, 0, 40)
				T.True(Ended("Bind:error", 0.3), "\"error\" within 0.3 s (" .. tostring(HK.Result()) .. ")")
			end)
			HS.Broken = Real
			if not Ok then error(Err, 0) end
			local Off = Dist(HR.Position, (Good * OFFSET).Position)
			T.True(Off <= 1, "put back at the last checked spot (" .. F2(Off) .. " studs off)")
			T.True(HR.AssemblyLinearVelocity.Magnitude < 5, "at rest (" .. F2(HR.AssemblyLinearVelocity.Magnitude) .. " studs/s)")
		end)
	end,

	-- (Task 7, Task 6 re-review m1; a regression guard: this engine's Raycast doesn't throw on a ray past its 15,000-stud
	-- limit, measured in Edit 2026-10-28) a move of 100,000 studs straight up is clamped before any ray: the pair is put
	-- back and the hold stays on, never "error"
	HugeMoveNoThrow = function(T)
		HK.Guard(function()
			local _, _, S = Led(T)
			local P0 = CRoot().Position
			CRoot().CFrame += Vector3.new(0, 1e5, 0)
			local Back = WaitFor(0.3, function() return Dist(CRoot().Position, P0) <= 1 and Clamped() >= 1 end)
			T.True(Back, "put back within 0.3 s (" .. F2(Dist(CRoot().Position, P0)) .. " studs off)")
			T.True(On(S), "the hold is still on (" .. tostring(HK.Result()) .. ")")
		end)
	end,

	-- ===== Task 10: hands full; a hostage can't act =====

	-- the player's own WCS Heavy started on the server while Holding: no CombatAttack within 0.3 s. A control runs first,
	-- free (it starts), and plays out before the hold; (fix round 1, review m1) and the refused start, ended, leaves the
	-- Heavy usable once freed (it starts again after Free). Heavy is a holdable skill: started by the server it stays
	-- active until it is ended (a key release, here Heavy:End()), and a Start while active does nothing (the RED session,
	-- 2026-10-28, saw a control after the refused start do nothing for that reason)
	CaptorNoHeavy = function(T)
		HK.Guard(function()
			local AR = require(game.ReplicatedStorage.Modules.Managers.AttackRunner)
			local WC = WCS.Character.GetCharacterFromInstance(C)
			local Heavy = WC and WC:GetSkillFromString("Heavy")
			T.True(Heavy ~= nil, "setup: the player's Heavy skill")
			local function Idle() return C:GetAttribute("CombatState") == nil and not AR.IsRunning(C) end
			local function Release() -- (the key let go)
				if Heavy:GetState().IsActive then Heavy:End() end
				return WaitFor(1, function() return not Heavy:GetState().IsActive end)
			end
			local Ok, Err = pcall(function()
				T.True(WaitFor(3, Idle) and Release(), "setup: the Heavy is idle")
				TK.PutPlayer(At(20, 20) + Vector3.new(0, 3, 0)) -- (clear of the stand-in made below)
				C:SetAttribute("HeavyReadyAt", nil)
				Heavy:Start()
				T.True(WaitFor(0.3, function() return C:GetAttribute("CombatAttack") ~= nil end), "control: free, the heavy starts")
				T.True(WaitFor(5, Idle) and Release(), "control: it plays out")
				task.wait(0.5) -- (the client's side of it ends too)
				HK.Held()
				C:SetAttribute("HeavyReadyAt", nil)
				Heavy:Start()
				local Started = WaitFor(0.3, function() return C:GetAttribute("CombatAttack") ~= nil end)
				T.True(not Started, "no heavy while Holding (" .. tostring(C:GetAttribute("CombatAttack")) .. ")")
				T.True(WaitFor(5, Idle) and Release(), "the refused start ended (the key let go)")
				Svc().Free(Player, "a")
				TK.PutPlayer(At(20, 20) + Vector3.new(0, 3, 0)) -- (clear of the freed stand-in)
				task.wait(0.5)
				C:SetAttribute("HeavyReadyAt", nil)
				Heavy:Start()
				T.True(WaitFor(0.3, function() return C:GetAttribute("CombatAttack") ~= nil end),
					"control: after Free, the heavy starts again")
				T.True(WaitFor(5, Idle) and Release(), "control: it plays out")
			end)
			if Heavy and Heavy:GetState().IsActive then Heavy:End() end -- (never left held down)
			C:SetAttribute("HeavyReadyAt", nil)
			C:SetAttribute("HeavyCooldown", nil)
			if not Ok then error(Err, 0) end
		end)
	end,

	-- the cast gate (AlchemyService.CanAct, the seam _CanAct) is false while Holding; true after Free
	CaptorNoAlchemy = function(T)
		HK.Guard(function()
			local AS = require(SSS.AlchemyService)
			T.True(type(AS._CanAct) == "function", "the AlchemyService._CanAct seam")
			local CanAct = AS._CanAct or function() return "no seam" end
			HK.Held()
			local WC = WCS.Character.GetCharacterFromInstance(C)
			T.Eq(CanAct(C, WC), false, "no cast while Holding")
			Svc().Free(Player, "a")
			T.Eq(CanAct(C, WC), true, "control: Free, free to cast")
		end)
	end,

	-- a Revolver drawn in Combat Mode and ShootingMode set by the test: a hold ends the mode within 0.3 s of Held.
	-- Control: set again after Free, it stays (0.3 s)
	CaptorNoShoot = function(T)
		HK.Guard(function()
			local WM = require(game.ReplicatedStorage.Modules.Managers.WeaponManager)
			GunKit.Unequip(Player)
			C:SetAttribute("CombatMode", true)
			local Gun = WM.Give(C, "Revolver")
			local Ok, Err = pcall(function()
				T.True(Gun ~= nil, "setup: the test's Revolver given")
				GunKit.Settle()
				C:SetAttribute("ShootingMode", true)
				task.wait(0.1)
				T.Eq(C:GetAttribute("ShootingMode"), true, "setup: shooting mode on, the gun drawn")
				HK.Held()
				T.True(WaitFor(0.3, function() return C:GetAttribute("ShootingMode") == nil end),
					"shooting mode ended within 0.3 s of Held (" .. tostring(C:GetAttribute("ShootingMode")) .. ")")
				Svc().Free(Player, "a")
				C:SetAttribute("ShootingMode", true)
				task.wait(0.3)
				T.Eq(C:GetAttribute("ShootingMode"), true, "control: set again after Free, it stays")
			end)
			C:SetAttribute("ShootingMode", nil)
			if Gun then
				Gun:Destroy() -- (the test's own Revolver, never the player's item; its deferred detach runs now)
				task.wait()
			end
			if not Ok then error(Err, 0) end
		end)
	end,

	-- Emotes.Blocked: the captor "Your hands are full", the stand-in hostage "Not while held"; the captor freed isn't
	CaptorNoEmote = function(T)
		HK.Guard(function()
			local Emotes = require(game.ReplicatedStorage.Modules.Data.Rensei.Emotes)
			local Rig = HK.Held()
			C:SetAttribute("CombatMode", nil)
			C:SetAttribute("InCombat", nil)
			T.Eq(Emotes.Blocked(C), "Your hands are full", "the captor")
			T.Eq(Emotes.Blocked(Rig), "Not while held", "the hostage")
			Svc().Free(Player, "a")
			T.True(Emotes.Blocked(C) ~= "Your hands are full", "control: freed (" .. tostring(Emotes.Blocked(C)) .. ")")
		end)
	end,

	-- a captor's held item (a TEMP Apple Tool, two Apples given to the mock bag) isn't used while Holding; after Free it is
	CaptorNoItem = function(T)
		HK.Guard(function()
			local IS = require(SSS.ItemService)
			local H = C.Humanoid
			HK.Held()
			local Tool = Instance.new("Tool")
			Tool.Name = "Apple" -- (ItemData's healing consumable in both places)
			Tool.RequiresHandle = false
			local R = {}
			local Ok, Err = pcall(function()
				Tool.Parent = C
				C:SetAttribute("CombatMode", nil)
				C:SetAttribute("ItemUseReadyAt", nil)
				T.True(IS.Give(Player, "Apple", 2), "setup: two Apples in the mock profile's bag")
				H.Health = H.MaxHealth - 20
				IS.Use(Player, Tool)
				R.Held = C:GetAttribute("ItemUseReadyAt")
				Svc().Free(Player, "a")
				C:SetAttribute("ItemUseReadyAt", nil)
				IS.Use(Player, Tool)
				R.Free = C:GetAttribute("ItemUseReadyAt")
			end)
			C:SetAttribute("ItemUseReadyAt", nil)
			Tool:Destroy()
			if not Ok then error(Err, 0) end
			T.Eq(R.Held, nil, "no item used while Holding")
			T.True(R.Free ~= nil, "control: Free, the Apple is used")
		end)
	end,

	-- the real player as the hostage: MovementState.Blocked is "HeldBy" (no climb, wall run, ledge walk or swim), the
	-- stand-in captor's is "Holding"; freed, nothing blocks the player
	HeldNoTraversal = function(T)
		HK.Guard(function()
			local Cap = HK.Captive()
			T.Eq(MovementState.Blocked(C), "HeldBy", "the hostage")
			T.Eq(MovementState.Blocked(Cap), "Holding", "the stand-in captor")
			Svc().Free(Player, "a")
			T.Eq(MovementState.Blocked(C), nil, "control: freed")
		end)
	end,

	-- ===== Task 10: travel refuses a pair (ruling R5) =====

	-- the road's refusal (RoadService.Unfit, the seam _Unfit) for the captor and, as the hostage, for the player. Control:
	-- freed, nothing refuses
	NoRoadCrossing = function(T)
		local RS = require(SSS.RoadService)
		T.True(type(RS._Unfit) == "function", "the RoadService._Unfit seam")
		local Unfit = RS._Unfit or function() return "no seam" end
		HK.Guard(function()
			HK.Held()
			T.Eq(Unfit(Player, ROAD), NO_ROAD, "the captor")
			Svc().Free(Player, "a")
			T.Eq(Unfit(Player, ROAD), nil, "control: freed")
		end)
		HK.Guard(function()
			HK.Captive()
			T.Eq(Unfit(Player, ROAD), NO_ROAD, "the hostage")
		end)
	end,

	-- the pair moved inside the platform train's 3rd-class car (the root anchored), a 3rd-class ticket held (one added,
	-- burnt after): StationService.Aboard leaves the captor out and the conductor's line is the hostage one. Control: Free,
	-- aboard. Scheduled departures held (HoldClock) while it runs.
	NoBoarding = function(T)
		HK.Guard(function()
			local SS, TS = require(SSS.StationService), require(SSS.TravelService)
			local Zone = BoardZone()
			T.True(Zone ~= nil, "setup: a 3rd-class BoardZone in the platform train")
			local R = {}
			SS.HoldClock = true
			local Added = TS.AddTicket(Player, RAIL, "Third")
			local Ok, Err = pcall(AtStation, function()
				T.True(Added, "setup: a 3rd-class ticket")
				HK.Held()
				MovePair(T, Zone.CFrame)
				SS.ResetGate(Player)
				local Got = HK.Toasts(function() R.In = table.find((SS.Aboard(RAIL)), Player) ~= nil end)
				R.Last = Got[#Got]
				Svc().Free(Player, "a")
				SS.ResetGate(Player)
				R.Control = table.find((SS.Aboard(RAIL)), Player) ~= nil
			end)
			SS.HoldClock = false
			SS.ResetGate(Player)
			if Added then TS.UseTicket(Player, RAIL, "Third") end
			if not Ok then error(Err, 0) end
			T.Eq(R.In, false, "the captor isn't aboard")
			T.Eq(R.Last, NO_BOARD, "the conductor's line")
			T.Eq(R.Control, true, "control: freed, aboard")
		end)
	end,

	-- the captor (the client owning the pair) moved up to the papers gate at Wanted 0: GateTouch is "Refuse", no Heat, and
	-- 0.3 s later the captor is on the hall side (pushed clear) with the hold still on and the stand-in in front (pre-flight
	-- P6 / Task 6 re-review m7: the push rebases the pair). Control: freed, the same touch is "Pass".
	-- (fix round 1, review I1) the push is made GATE_PUSH (12, put back after) so it is past any lead allowance in the
	-- window: without the gate's DownedManager.MovedOnPurpose -> HostageService.Rebase the clamp would put the captor back
	-- by the gate. A spy (put back after) also counts the Rebase calls GateTouch made for the captor.
	GateRefusesCaptor = function(T)
		HK.Guard(function()
			local SS, HeatS = require(SSS.StationService), require(SSS.HeatService)
			local Gate = TheGate()
			T.True(Gate ~= nil, "setup: a RenseiStationGate")
			local R = {Rebased = 0}
			local HS = Svc()
			local RealPush, RealRebase = SS.GatePush, HS.Rebase
			local Ok, Err = pcall(AtStation, function()
				local Rig, _, S = HK.Held()
				HK.Loose()
				local N = Gate.CFrame.LookVector
				local Spot = (Gate.CFrame * CFrame.new(0, -0.5, 0.2)).Position -- (0.2 studs hall-side of its middle)
				local Heat0 = HeatS.Value(Player, "State")
				R.Toasts = HK.Toasts(function()
					MovePair(T, CFrame.lookAt(Spot, Spot + N)) -- (facing the platform: the stand-in 1.5 studs nearer it)
					task.wait(0.3)
					Fresh() -- (1.5 studs back in honest steps: the lead's time is fresh, so the push is measured against a tick)
					CRoot().AssemblyLinearVelocity = Vector3.zero
					SS.ResetGate(Player)
					SS.GatePush = GATE_PUSH
					HS.Rebase = function(M, ...)
						if M == C then R.Rebased += 1 end
						return RealRebase(M, ...)
					end
					R.Verdict = SS.GateTouch(Player, Gate)
					HS.Rebase = RealRebase
					SS.GatePush = RealPush
					task.wait(0.3)
				end)
				R.Heat = HeatS.Value(Player, "State") - Heat0
				R.Side = HallSide(Gate)
				R.On, R.Result = On(S), HK.Result()
				R.Gap = Dist(Rig.HumanoidRootPart.Position, (CRoot().CFrame * OFFSET).Position)
				Svc().Free(Player, "a")
				SS.ResetGate(Player)
				CRoot().CFrame = CFrame.lookAt(Spot, Spot + N)
				CRoot().AssemblyLinearVelocity = Vector3.zero
				task.wait(0.1)
				R.Control = SS.GateTouch(Player, Gate)
			end)
			HS.Rebase, SS.GatePush = RealRebase, RealPush
			SS.ResetGate(Player)
			if not Ok then error(Err, 0) end
			T.Eq(R.Verdict, "Refuse", "a captor is refused at Wanted 0")
			T.Near(R.Heat, 0, 0.01, "no Heat")
			T.True(table.find(R.Toasts, NO_GATE) ~= nil, "the guard's line")
			T.True(R.Rebased >= 1, "the push rebased the pair (" .. R.Rebased .. " Rebase calls)")
			-- (by hand: the gate is 1 stud thick, so a root pushed GATE_PUSH 12 clear is at -12.5; 0.5 of slack)
			T.True(R.Side <= -12.0, "pushed 12 studs clear to the hall side (" .. F2(R.Side) .. ")")
			T.True(R.On, "the hold is still on after the push (" .. tostring(R.Result) .. ")")
			T.True(R.Gap <= 1.5, "the stand-in came with the pair (" .. F2(R.Gap) .. " studs off)")
			T.Eq(R.Control, "Pass", "control: freed, Wanted 0 walks through")
		end)
	end,

	-- (pre-flight P27) TravelService.Depart({Player}, the road) while Held, in Studio (loopback), with TravelService.Arrive
	-- stubbed (put back after) so no loopback arrival runs: Going is empty. Control: freed, Going is {Player}. The Trip
	-- Depart writes on the mock profile is put back. Refused outside TestNoSave: Depart writes the save.
	DepartDropsHeld = function(T)
		local DataManager = require(SSS.CharacterHandler.DataManager)
		assert(DataManager.IsNoSave() == true, "DepartDropsHeld runs only under TestNoSave: TravelService.Depart writes the save")
		HK.Guard(function()
			local TS = require(SSS.TravelService)
			local D = require(SSS.ProgressionService).GetData(Player)
			local TripWas = D.Travel and D.Travel.Trip
			local RealArrive = TS.Arrive
			local R = {}
			HK.Held()
			local Ok, Err = pcall(function()
				TS.Arrive = function() end
				R.Mode, R.Went = TS.Depart({Player}, ROAD, "RoadStart")
				Svc().Free(Player, "a")
				R.CMode, R.CWent = TS.Depart({Player}, ROAD, "RoadStart")
				task.wait(0.1) -- (the loopback's spawned Arrive calls, stubbed)
			end)
			TS.Arrive = RealArrive
			if D.Travel then D.Travel.Trip = TripWas end
			if not Ok then error(Err, 0) end
			T.Eq(R.Mode, "loopback", "Studio loops back")
			T.Eq(#(R.Went or {}), 0, "a captor isn't Going")
			T.Eq(#(R.CWent or {}), 1, "control: freed, Going")
		end)
	end,

	-- (fix round 1, review m7) the real player as the HOSTAGE (both roots anchored), the pair moved to the gate: GateTouch
	-- judges the hostage as part of the pair, never on their own papers. With a Wanted 3+ verdict: "Refuse", no Heat, no
	-- "poster" line; with a bribe verdict: "Refuse", no offer. Heat a RED run raised is taken back (HeatService.Reduce).
	HostageAtGateIsPartOfThePair = function(T)
		HK.Guard(function()
			local SS, HeatS = require(SSS.StationService), require(SSS.HeatService)
			local Gate = TheGate()
			T.True(Gate ~= nil, "setup: a RenseiStationGate")
			local R = {}
			local Papers = {Verdict = "Refuse"}
			local Heat0 = HeatS.Value(Player, "State")
			local Ok, Err = pcall(AtStation, function()
				local Cap = HK.Captive()
				local N = Gate.CFrame.LookVector
				local Spot = (Gate.CFrame * CFrame.new(0, -0.5, 1.7)).Position
				local CapCF = CFrame.lookAt(Spot, Spot + N) -- (the hostage 1.5 studs in front, by the gate)
				Cap.HumanoidRootPart.CFrame = CapCF
				CRoot().CFrame = CapCF * OFFSET
				T.Eq(Svc().Rebase(Cap), true, "setup: the moved pair rebased")
				SS.ResetGate(Player)
				R.Toasts = HK.Toasts(function() R.Refused = SS.GateTouch(Player, Gate) end)
				R.Heat = HeatS.Value(Player, "State") - Heat0
				SS.ResetGate(Player)
				Papers.Verdict = "Bribe"
				R.Bribe = SS.GateTouch(Player, Gate)
			end, Papers)
			local Raised = HeatS.Value(Player, "State") - Heat0
			if Raised > 0 then HeatS.Reduce(Player, "State", Raised) end
			SS.ResetGate(Player)
			if not Ok then error(Err, 0) end
			T.Eq(R.Refused, "Refuse", "Wanted 3+ papers: refused as the pair")
			T.Near(R.Heat, 0, 0.01, "no Heat for the hostage")
			T.True(table.find(R.Toasts, "Guard: \"Your face is on a poster. Not on my platform.\"") == nil, "not the poster line")
			T.Eq(R.Bribe, "Refuse", "bribe-level papers: refused, no offer")
		end)
	end,

	-- (fix round 1, review m6; spec section 2: the captor walks at LeadSpeed 12) a light attack while Holding (its strike
	-- stubbed: nothing is hit) ends with MoverManager handing the walk back: the server's WalkSpeed is still 12, JumpHeight 0
	MoverKeepsTheLeadWalk = function(T)
		HK.Guard(function()
			local AR = require(game.ReplicatedStorage.Modules.Managers.AttackRunner)
			local Tuning = require(game.ReplicatedStorage.Modules.Data.Rensei.TuningConfig)
			HK.Held()
			local H = C.Humanoid
			T.Eq(H.WalkSpeed, 12, "setup: the captor walks at 12")
			C:SetAttribute("CombatMode", nil)
			local WC = WCS.Character.GetCharacterFromInstance(C)
			task.spawn(AR.Run, WC, Tuning.Light.Hits[1], "Light1", {Strike = function() return {} end})
			T.True(WaitFor(0.3, function() return C:GetAttribute("CombatState") ~= nil end), "setup: the light runs")
			T.True(WaitFor(3, function() return C:GetAttribute("CombatState") == nil and (C:GetAttribute("Movement") or 0) == 0 end),
				"setup: the light and its movement change are over")
			task.wait(0.1)
			T.Eq(H.WalkSpeed, 12, "the captor still walks at 12")
			T.Eq(H.JumpHeight, 0, "and can't jump")
		end)
	end,

	-- (fix round 1, review m3) two server moves of 25 studs in a row (each rebased; the root anchored, so only the server
	-- moves it), then the root back at the ORIGINAL spot (the client's stale echo of the first move, 50 studs off, past
	-- TeleportBreak 40): still an echo, put back to the newest spot, the hold on (not "teleport")
	SecondRebaseKeepsTheEcho = function(T)
		HK.Guard(function()
			local _, _, S = HK.Held()
			local P0 = CRoot().CFrame
			MovePair(T, P0 + Vector3.new(25, 0, 0))
			MovePair(T, P0 + Vector3.new(50, 0, 0))
			CRoot().CFrame = P0
			task.wait(0.3)
			local Off = Ground(CRoot().Position, P0.Position + Vector3.new(50, 0, 0))
			T.True(On(S), "the hold is still on (" .. tostring(HK.Result()) .. ")")
			T.True(Off <= 1, "put back at the newest spot (" .. F2(Off) .. " studs off)")
		end)
	end,

	-- (Task 6 re-review m2; fix round 1, review m8: the wall ray itself) a Rebase opens no window to walk through a wall:
	-- the pair moved 30 studs and rebased (past the echo's reach of the old spot: at most LeadAllowance(1) 20.5 +
	-- RiseSlack 3), then 0.2 s on, inside the grace, stepped 3.5 studs through a TEMP wall 2 studs off the new spot: the
	-- wall ray ends it "teleport", and the stand-in is put back on this side
	RebaseOpensNoWallWindow = function(T)
		HK.Guard(function()
			local Rig = Led(T)
			local New = CRoot().CFrame + Vector3.new(30, 0, 0)
			MovePair(T, New)
			Block(Vector3.new(0.4, 12, 12), CFrame.new(New.Position + Vector3.new(2, 0, 0)))
			task.wait(0.2)
			CRoot().CFrame = New + Vector3.new(3.5, 0, 0)
			T.True(Ended("Bind:teleport", 0.6), "\"teleport\" within 0.6 s (" .. tostring(HK.Result()) .. ")")
			local HX = Rig.HumanoidRootPart.Position.X - New.Position.X
			T.True(HX < 2, "the stand-in is back on this side of the wall (" .. F2(HX) .. ")")
		end)
	end,
}

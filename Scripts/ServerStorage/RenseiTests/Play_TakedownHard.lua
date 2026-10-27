-- Play_TakedownHard (assassinations Task 8 fix round, 2026-10-27): the takedown review cases, split out of
-- Play_Takedown (which Task 9 extends) with no change to the moved cases. Run in the game VM (LMRunSuite), every case in
-- TakedownKit.Guard with rigs it spawned itself, as Play_Takedown's; the shared helpers are TakedownKit's.
-- * Task 7 review: the player leaving mid-takedown (PlayerLeft releases, THEN forgets the cooldown; the control runs the
--   old order), a kill that errors part-way ("<Kind>:error"), a takedown that can't start keeps DamageTakenMult, the
--   victim knocked or gripped mid-takedown interrupts it, CheckDeliveries takes a living prisoner only.
-- * Task 8 guard: a knocked-out Grunt gripped to death doesn't wake; the FinishedBy check pinned, with its control.
-- * Task 8 fix round: a townsperson's body raises no Heat when found (TownsfolkService owns it; control: a guard's +60);
--   a guard assassinated past its deed's daily cap still raises Heat once when found.
local SSS = game.ServerScriptService
local DM = require(game.ReplicatedStorage.Modules.Managers.DownedManager)
local PS = require(SSS.PerceptionService)
local Kit = require(script.Parent.TakedownKit)
local SmokeKit = require(script.Parent.SmokeKit) -- RemoveEnemy: the gripper goes once its grip is done
local Progression = require(SSS.ProgressionService)
local HS = require(SSS.HeatService)
local Player = Kit.Player()
local C = Player.Character

local At, AWAY, NEAR, AtHour, DeadBody = Kit.At, Kit.AWAY, Kit.NEAR, Kit.AtHour, Kit.DeadBody
local CarryWeld, Free, Service, Result, Calm = Kit.CarryWeld, Kit.Free, Kit.Service, Kit.Result, Kit.Calm
local Assassinate, KnockOut, Finished, Behind, LAW = Kit.Assassinate, Kit.KnockOut, Kit.Finished, Kit.Behind, Kit.LAW

return {
	-- the knocked-out Grunt gripped to death (a second kit Grunt grips it: the loud finisher, its own "Dead" body): no
	-- wake-up, so no Raise (a Grunt 25 studs off, inside the 40-stud call and outside the grip's 20-stud Hit, stays
	-- Unaware); KnockedOutBy cleared; the body is the grip's "Dead" one. (Added after GREEN: a guard of the death branch.)
	-- Fix round: the FinishedBy check pinned -- Knocked clearing on a rig still ALIVE but marked FinishedBy (a grip's kill
	-- under way) is no wake-up (no Raise); the control, the same with no FinishedBy, wakes (Alert).
	KnockedOutThenGripped = function(T)
		Kit.Guard(function()
			local Rig = Behind()
			T.Eq(KnockOut(Rig), true, "started")
			T.True(Finished(3), "ended")
			T.Eq(Result(), "Knockout:ok")
			Kit.PutPlayer(AWAY)
			local Second = Kit.Spawn("Grunt", At(-25, 0))
			local Gripper = Kit.Spawn("Grunt", At(0, -4))
			local Done = DM.Grip(Gripper, Rig)
			SmokeKit.RemoveEnemy(Gripper)
			T.Eq(Done, true, "setup: the grip finished")
			T.True(Rig.Humanoid.Health <= 0, "setup: the grip killed it")
			task.wait(0.3)
			T.Eq(Rig:GetAttribute("KnockedOutBy"), nil, "KnockedOutBy cleared")
			local Info = PS.Bodies[Rig]
			T.True(Info ~= nil and Info.Kind == "Dead", "the grip's Dead body: " .. tostring(Info and Info.Kind))
			T.Eq(PS.PhaseOf(Second), "Unaware", "no wake-up alarm: the Grunt 25 studs off isn't called")
			-- the FinishedBy check, pinned: alive, FinishedBy set, Knocked cleared
			local function KnockedOutAt(X, Z)
				Service().Forget(Player)
				local R = Kit.Spawn("Grunt", At(X, Z))
				Kit.PutBehind(R, 3)
				Calm()
				T.Eq(KnockOut(R), true, "setup: started")
				T.True(Finished(3), "setup: ended")
				T.Eq(DM.IsKnocked(R), true, "setup: knocked out")
				return R
			end
			local Pin = KnockedOutAt(30, 0)
			Pin:SetAttribute("FinishedBy", "Takedown_TestGripper")
			Pin:SetAttribute("Knocked", nil)
			task.wait(0.3)
			T.True(Pin.Humanoid.Health > 0, "pin: still alive")
			T.Eq(Pin:GetAttribute("KnockedOutBy"), nil, "pin: KnockedOutBy cleared")
			T.Eq(PS.PhaseOf(Pin), "Unaware", "pin: marked FinishedBy, it doesn't wake (no Raise)")
			local Ctl = KnockedOutAt(30, -40)
			Ctl:SetAttribute("Knocked", nil)
			task.wait(0.3)
			T.Eq(PS.PhaseOf(Ctl), "Alert", "control: no FinishedBy, it wakes (Raise)")
		end)
	end,
	-- ===== Task 7 review (folded into Task 8) =====
	-- 1. the player leaving mid-takedown: released (quietly), and their cooldown forgotten AFTER the release (it used to be
	-- forgotten first, and the release wrote it back). The control runs the old order through the same two steps
	-- (Forget, then Cancel: PlayerLeft's release) and is left on cooldown.
	LeavingForgetsCooldown = function(T)
		Kit.Guard(function()
			local S = Service()
			T.True(type(S.PlayerLeft) == "function", "TakedownService.PlayerLeft exists (the PlayerRemoving handler)")
			T.True(type(S.Cancel) == "function", "TakedownService.Cancel exists (PlayerLeft's release)")
			-- control: forgotten first, then released
			local Old = Behind()
			T.Eq(S.Request(Player, "Assassinate", Old), true, "control: started")
			T.Eq(C:GetAttribute("TakingDown"), Old.Name, "control: mid-takedown")
			S.Forget(Player)
			S.Cancel(Player, true)
			T.True(Finished(1), "control: released")
			local A = Kit.Spawn("Grunt", At(20, 0))
			Kit.PutBehind(A, 3)
			Calm()
			local Ok0, Why0 = S.Request(Player, "Assassinate", A)
			T.Eq(Ok0, false, "control: the old order leaves the release's cooldown behind")
			T.Eq(Why0, "cooldown", "control: the reason")
			S.Forget(Player)
			-- PlayerLeft: released first, then forgotten
			local B = Kit.Spawn("Grunt", At(20, -20)) -- 20 studs ahead of A, its back to the player
			T.Eq(S.Request(Player, "Assassinate", A), true, "started")
			T.Eq(C:GetAttribute("TakingDown"), A.Name, "mid-takedown") -- (no wait: a hitch can't carry it past the kill)
			S.PlayerLeft(Player)
			T.True(Finished(1), "released")
			T.Eq(Result(), "Assassinate:interrupted", "as an interrupt")
			T.True(A.Humanoid.Health > 0, "the Grunt lives")
			T.Eq(PS.PhaseOf(A), "Unaware", "quietly: no alarm")
			Kit.PutBehind(B, 3)
			Calm()
			local Ok, Why = S.Request(Player, "Assassinate", B)
			T.Eq(Ok, true, "no cooldown left behind (" .. tostring(Why) .. ")")
			T.True(Finished(), "the second ended")
		end)
	end,
	-- 2. a kill that errors part-way (here: after DownedManager.Finish) is no interrupt: no Failed, the corpse keeps
	-- TakenDownBy and isn't re-anchored; "<Kind>:error"
	KillErrorIsNoInterrupt = function(T)
		local RealFinish = DM.Finish
		local S = Service()
		local Fails = 0
		local function F() Fails += 1 end
		table.insert(S.Failed, F)
		local Ok, Err = pcall(Kit.Guard, function()
			local Rig = Behind()
			DM.Finish = function(...) RealFinish(...) error("test: the kill fails after Finish") end
			T.Eq(Assassinate(Rig), true, "started")
			T.True(Finished(), "ended")
			DM.Finish = RealFinish
			T.Eq(Result(), "Assassinate:error", "LastTakedownResult")
			T.True(Rig.Humanoid.Health <= 0, "setup: the victim died")
			T.Eq(Fails, 0, "Failed didn't fire")
			T.Eq(Rig:GetAttribute("TakenDownBy"), Player.Name, "the corpse keeps TakenDownBy")
			T.Eq(Rig.HumanoidRootPart.Anchored, false, "the corpse's root isn't re-anchored")
			T.Eq(CarryWeld(), nil, "no weld left")
			T.Eq(C:GetAttribute("TakingDown"), nil, "the player released")
		end)
		DM.Finish = RealFinish
		local I = table.find(S.Failed, F)
		if I then table.remove(S.Failed, I) end
		if not Ok then error(Err, 0) end
	end,
	-- 3. a takedown that can't start (here: Glimpse, its first step, errors) leaves the victim's DamageTakenMult as it was
	FailedStartKeepsDamageMult = function(T)
		local RealGlimpse = PS.Glimpse
		local Ok, Err = pcall(Kit.Guard, function()
			local Rig = Behind()
			Rig:SetAttribute("DamageTakenMult", 0.5)
			PS.Glimpse = function() error("test: the takedown can't start") end
			T.Eq(Assassinate(Rig), true, "requested")
			T.True(Finished(1), "ended")
			PS.Glimpse = RealGlimpse
			T.Eq(Result(), "Assassinate:interrupted", "LastTakedownResult")
			T.Eq(Rig:GetAttribute("DamageTakenMult"), 0.5, "DamageTakenMult as it was (0.5)")
			T.True(Rig.Humanoid.Health > 0, "alive")
		end)
		PS.Glimpse = RealGlimpse
		if not Ok then error(Err, 0) end
	end,
	-- 4. the victim knocked, or gripped, mid-takedown: interrupted
	VictimKnockedOrGrippedInterrupts = function(T)
		Kit.Guard(function()
			local S = Service()
			local Rig = Behind()
			T.Eq(Assassinate(Rig), true, "started")
			-- (no wait: the hold is already on when Request returns, and a server hitch can't carry it past the kill)
			T.Eq(C:GetAttribute("TakingDown"), Rig.Name, "mid-takedown")
			DM.Knock(Rig)
			T.True(Finished(1), "ended")
			T.Eq(Result(), "Assassinate:interrupted", "knocked mid-takedown: interrupted")
			T.True(Rig.Humanoid.Health > 0, "the knocked Grunt lives")
			T.Eq(Rig:GetAttribute("TakenDownBy"), nil, "unmarked")
			S.Forget(Player)
			local Other = Kit.Spawn("Grunt", At(20, 0))
			Kit.PutBehind(Other, 3)
			Calm()
			T.Eq(Assassinate(Other), true, "the second started")
			T.Eq(C:GetAttribute("TakingDown"), Other.Name, "mid-takedown")
			Other:SetAttribute("GrippedBy", "Takedown_TestGripper")
			T.True(Finished(1), "the second ended")
			T.Eq(Result(), "Assassinate:interrupted", "gripped mid-takedown: interrupted")
			T.True(Other.Humanoid.Health > 0, "the gripped Grunt lives")
		end)
	end,
	-- 6. CheckDeliveries hands over a knocked, LIVING enemy only: a dead body still marked Knocked is no prisoner
	DeadKnockedIsNoPrisoner = function(T)
		Kit.Guard(function()
			local Captor = Instance.new("Model")
			Captor.Name = "Takedown_TestCaptor"
			Captor:SetAttribute("TakesPrisoners", true)
			local R = Instance.new("Part")
			R.Name, R.Anchored, R.CanCollide, R.Transparency = "HumanoidRootPart", true, false, 1
			R.Size = Vector3.new(2, 2, 1)
			R.Parent = Captor
			local Ok, Err = pcall(function()
				local Body = DeadBody(0, 0)
				Free(Body)
				Body:SetAttribute("Knocked", true) -- (dead, yet still marked Knocked)
				Kit.PutPlayer(NEAR)
				T.True(DM.Carry(C, Body), "setup: carrying the body")
				R.CFrame = C.HumanoidRootPart.CFrame * CFrame.new(0, 0, -5)
				Captor.Parent = workspace.World.NPCs
				task.wait(1.5)
				T.Eq(Body:GetAttribute("Arrested"), nil, "a dead body is not taken prisoner")
			end)
			Captor:Destroy()
			if not Ok then error(Err, 0) end
		end)
	end,

	-- ===== Task 8 fix round =====
	-- a townsperson's body is TownsfolkService's: its murder Heat is that service's (murder_townsfolk, witnessed), so the
	-- find raises none, even with a law faction (Ye's townsfolk are Townsfolk, the Militia's law). The control, the same
	-- rig with no TownsfolkId (a guard), raises 60 once.
	GrippedTownsfolkNoFindHeat = function(T)
		Kit.GrippedBodyHeat(T, LAW and LAW.Faction, 0, {TownsfolkId = "Takedown_TestFolk"})
		Kit.GrippedBodyHeat(T, LAW and LAW.Faction, 60)
	end,
	-- an assassinated guard past its deed's daily cap (Record counts nothing, so the body carries no deed) raises its
	-- law's Heat once when found, like any guard's body nobody saw killed
	CappedGuardBodyFoundHeat = function(T)
		assert(LAW, "a law faction for this place")
		Kit.Guard(function() AtHour(12, function()
			local M = Progression.GetData(Player).Morality
			local E = M.Deeds.assassinated_guard or {At = os.time(), Count = 0, Seen = 0}
			M.Deeds.assassinated_guard = E
			E.Day, E.DayCount = math.floor(os.time() / 86400), 10 -- (assassinated_guard's Repeat.Cap 10, written by hand)
			local Count0 = E.Count
			local Heat0 = HS.Value(Player, LAW.J)
			local Rig = Kit.Spawn("Grunt", At(0, 0))
			Rig:SetAttribute("Faction", LAW.Faction)
			Kit.PutBehind(Rig, 3)
			Calm()
			T.Eq(Assassinate(Rig), true, "started")
			T.True(Finished(), "ended")
			T.Eq(Result(), "Assassinate:ok")
			task.wait(0.3)
			T.Eq(M.Deeds.assassinated_guard.Count, Count0, "setup: past the cap, the deed counts nothing")
			T.Near(HS.Value(Player, LAW.J) - Heat0, 0, 0.5, "nobody saw it: no Heat yet")
			local Info = PS.Bodies[Rig]
			T.True(Info ~= nil and Info.Deed == nil, "the body carries no deed")
			Kit.PutPlayer(AWAY)
			task.wait(1)
			Kit.Spawn("Grunt", At(0, 10)) -- a patrol 10 studs off, facing it (-Z), at noon
			Kit.Run(4)
			T.True(Info ~= nil and Info.Found == true, "the patrol found the body")
			task.wait(0.3)
			T.Near(HS.Value(Player, LAW.J) - Heat0, 60, 1, LAW.J .. " Heat: 60 when the body is found")
			Kit.Run(2)
			T.Near(HS.Value(Player, LAW.J) - Heat0, 60, 1, "once")
		end) end)
	end,
}

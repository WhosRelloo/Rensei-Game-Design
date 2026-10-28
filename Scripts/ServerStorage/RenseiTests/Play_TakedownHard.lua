-- Play_TakedownHard (assassinations Task 8 fix round, 2026-10-27): the takedown review cases, split out of
-- Play_Takedown (which Task 9 extends) with no change to the moved cases. Run in the game VM (LMRunSuite), every case in
-- TakedownKit.Guard with rigs it spawned itself, as Play_Takedown's; the shared helpers are TakedownKit's.
-- * Task 7 review: the player leaving mid-takedown (PlayerLeft releases, THEN forgets the cooldown; the control runs the
--   old order), a kill that errors part-way ("<Kind>:error"), a takedown that can't start keeps DamageTakenMult, the
--   victim knocked or gripped mid-takedown interrupts it, CheckDeliveries takes a living prisoner only.
-- * Task 8 guard: a knocked-out Grunt gripped to death doesn't wake; the FinishedBy check pinned, with its control.
-- * Task 8 fix round: a townsperson's body raises no Heat when found (TownsfolkService owns it; control: a guard's +60);
--   a guard assassinated past its deed's daily cap still raises Heat once when found.
-- * Final fix round (final-fix-brief.md, F1-F8): the player is held for real (root anchored; moved off the hold:
--   interrupted), Grip and Carry refuse a player mid-takedown, an error in the run loop still releases everything, a
--   victim killed by something else loses TakenDownBy, a crouched player keeps the crouch's speed, a rig that is gripping
--   or carrying is refused, a gripper removed mid-grip leaves no lock behind, and Kit.Guard refuses a case without the
--   hook's save snapshot. These cases free the player's root (Kit.PutPlayer anchors it) where a real game would.
local SSS = game.ServerScriptService
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
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
local WaitFor = Kit.WaitFor

-- (final fix) the player's root let go (Kit.PutPlayer anchors it), as in a real game, with 0.3 s to settle on the floor
local function Loose()
	C.HumanoidRootPart.Anchored = false
	C.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
	task.wait(0.3)
end
-- (final fix) a kit Grunt at (X, Z), knocked, in reach of the player for V / B
local function KnockedAt(X, Z)
	local Rig = Kit.Spawn("Grunt", At(X, Z))
	DM.Knock(Rig)
	return Rig
end

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
	-- 3. a takedown that can't start (here: Glimpse, its first step, errors) leaves the victim's DamageTakenMult as it was.
	-- (Final fix F3, the brief's ruling) an error in the start is released as "error" (no Alarm, no Failed), no longer as
	-- an interrupt.
	FailedStartKeepsDamageMult = function(T)
		local RealGlimpse = PS.Glimpse
		local Ok, Err = pcall(Kit.Guard, function()
			local Rig = Behind()
			Rig:SetAttribute("DamageTakenMult", 0.5)
			PS.Glimpse = function() error("test: the takedown can't start") end
			T.Eq(Assassinate(Rig), true, "requested")
			T.True(Finished(1), "ended")
			PS.Glimpse = RealGlimpse
			T.Eq(Result(), "Assassinate:error", "LastTakedownResult")
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

	-- ===== Final fix round (final-fix-brief.md) =====
	-- F1 (review I1). The player is held for real: its root is anchored for the choke, so a client walk (WalkSpeed 24 and
	-- a Move, as Shift or letting go of Ctrl gives) doesn't move it or drag the victim; the choke completes, and the root's
	-- anchoring is given back.
	PlayerHeldDuringTakedown = function(T)
		Kit.Guard(function()
			local Rig = Behind()
			Loose()
			local R, H = C.HumanoidRootPart, C.Humanoid
			T.Eq(KnockOut(Rig), true, "started")
			task.wait(0.3)
			T.Eq(C:GetAttribute("TakingDown"), Rig.Name, "setup: mid-choke")
			T.Eq(R.Anchored, true, "the player's root is held (anchored) during the choke")
			local P0, V0 = R.Position, Rig.HumanoidRootPart.Position
			local Locked = H.WalkSpeed
			H.WalkSpeed = 24
			local T0 = os.clock()
			while os.clock() - T0 < 0.5 do
				H:Move(Vector3.new(1, 0, 0))
				RunService.Heartbeat:Wait()
			end
			H:Move(Vector3.zero)
			H.WalkSpeed = Locked
			T.True((R.Position - P0).Magnitude < 0.5, ("the player didn't move (%.2f studs)"):format((R.Position - P0).Magnitude))
			T.True((Rig.HumanoidRootPart.Position - V0).Magnitude < 0.5, "nor was the victim dragged")
			T.True(Finished(3), "ended")
			T.Eq(Result(), "Knockout:ok", "the choke completes")
			T.Eq(R.Anchored, false, "released: the root's anchoring as it was (free)")
		end)
	end,
	-- F1 (review I1, check c). The player's root moved off the hold mid-choke (5 studs: what a client that owned the pair
	-- could do) interrupts the takedown; the victim isn't knocked out.
	PlayerMovedInterrupts = function(T)
		Kit.Guard(function()
			local Rig = Behind()
			Loose()
			local R = C.HumanoidRootPart
			T.Eq(KnockOut(Rig), true, "started")
			task.wait(0.3)
			T.Eq(C:GetAttribute("TakingDown"), Rig.Name, "setup: mid-choke")
			R.CFrame += Vector3.new(5, 0, 0)
			T.True(Finished(3), "ended")
			T.Eq(Result(), "Knockout:interrupted", "moved off the hold: interrupted")
			T.Eq(DM.IsKnocked(Rig), false, "the Grunt isn't knocked out")
			T.True(Rig.Humanoid.Health > 0, "the Grunt lives")
			T.Eq(R.Anchored, false, "released: the root's anchoring as it was (free)")
		end)
	end,
	-- F2 (review I2). V mid-choke, with another knocked Grunt in reach: no carry (Free refuses TakingDown); the choke
	-- completes and the walk afterwards is the one from before the takedown.
	CarryRefusedMidTakedown = function(T)
		Kit.Guard(function()
			local Rig = Behind()
			local Other = KnockedAt(3, 2) -- 3 studs beside where the hold puts the player (CarryRange 6)
			T.True(DM.IsKnocked(Other), "setup: a knocked Grunt in reach")
			Calm()
			local H = C.Humanoid
			local WS = H.WalkSpeed
			T.Eq(KnockOut(Rig), true, "started")
			task.wait(0.3)
			T.Eq(C:GetAttribute("TakingDown"), Rig.Name, "setup: mid-choke")
			local Got = DM.Request(C, "Carry")
			T.True(Got ~= "Carry", "V mid-choke carries nothing (" .. tostring(Got) .. ")")
			T.Eq(C:GetAttribute("Carrying"), nil, "the player isn't carrying")
			T.Eq(Other:GetAttribute("CarriedBy"), nil, "the knocked Grunt isn't picked up")
			T.True(Finished(3), "ended")
			T.Eq(Result(), "Knockout:ok", "the choke completes")
			T.Near(H.WalkSpeed, WS, 1e-3, "the walk from before the takedown")
		end)
	end,
	-- F2 (review I2). B mid-choke, with another knocked Grunt in reach: no grip.
	GripRefusedMidTakedown = function(T)
		Kit.Guard(function()
			local Rig = Behind()
			local Other = KnockedAt(3, 2)
			T.True(DM.IsKnocked(Other), "setup: a knocked Grunt in reach")
			Calm()
			T.Eq(KnockOut(Rig), true, "started")
			task.wait(0.3)
			T.Eq(C:GetAttribute("TakingDown"), Rig.Name, "setup: mid-choke")
			local Got = DM.Request(C, "Grip")
			T.Eq(Got, nil, "B mid-choke grips nothing")
			T.Eq(Other:GetAttribute("GrippedBy"), nil, "the knocked Grunt isn't gripped")
			T.True(Other.Humanoid.Health > 0, "and lives")
			T.True(Finished(3), "ended")
			T.Eq(Result(), "Knockout:ok", "the choke completes")
		end)
	end,
	-- F3 (review M1). An error inside the run loop (Broken, through its test seam) still releases everything: the result
	-- "<Kind>:error", no lock, no weld, the victim's DamageTakenMult back, no TakingDown, the root's anchoring back.
	LoopErrorReleases = function(T)
		local S = Service()
		local RealBroken = S.Broken
		local Ok, Err = pcall(Kit.Guard, function()
			local Rig = Behind()
			local H = C.Humanoid
			local WS, JH, Anchored = H.WalkSpeed, H.JumpHeight, C.HumanoidRootPart.Anchored
			S.Broken = function() error("test: Broken fails") end
			T.Eq(KnockOut(Rig), true, "started")
			T.True(Finished(1), "released at once")
			S.Broken = RealBroken
			T.Eq(Result(), "Knockout:error", "LastTakedownResult")
			T.Eq(C:GetAttribute("TakingDown"), nil, "TakingDown cleared")
			T.Eq(DM.IsLocked and DM.IsLocked(C), false, "the player's lock is let go (no LockedFrom left)")
			T.Near(H.WalkSpeed, WS, 1e-3, "the walk from before")
			T.Near(H.JumpHeight, JH, 1e-3, "the jump from before")
			T.Eq(CarryWeld(), nil, "no weld left on the player")
			T.Eq(Rig.Humanoid.PlatformStand, false, "the victim let go")
			T.Eq(Rig:GetAttribute("DamageTakenMult"), nil, "the victim's DamageTakenMult as before (not 0)")
			T.Eq(Rig:GetAttribute("TakenDownBy"), nil, "the living victim unmarked")
			T.Eq(C.HumanoidRootPart.Anchored, Anchored, "the player's root anchoring as before")
		end)
		S.Broken = RealBroken
		if not Ok then error(Err, 0) end
	end,
	-- F4 (review M2). A victim killed by something else mid-choke loses TakenDownBy: it is no takedown body, so V can't
	-- carry it.
	KilledElsewhereLosesMark = function(T)
		Kit.Guard(function()
			local Rig = Behind()
			T.Eq(KnockOut(Rig), true, "started")
			task.wait(0.3)
			T.Eq(C:GetAttribute("TakingDown"), Rig.Name, "setup: mid-choke")
			Rig.Humanoid.Health = 0 -- (DamageTakenMult 0 turns a hit away, so the death is set directly)
			T.True(Finished(1), "ended")
			T.Eq(Result(), "Knockout:interrupted", "LastTakedownResult")
			T.Eq(Rig:GetAttribute("TakenDownBy"), nil, "the corpse loses TakenDownBy")
			T.Eq(DM.IsTakedownBody(Rig), false, "it is no takedown body")
		end)
	end,
	-- F5 (review M4). A player still crouching after a knockout keeps the crouch's speed (6, ClientHandler.Crouch, written
	-- by hand) and no jump; once they stand up, the walk and jump from before the takedown.
	CrouchedKeepsCrouchSpeed = function(T)
		Kit.Guard(function()
			local Rig = Behind()
			Kit.Crouch(true)
			local H = C.Humanoid
			local WS, JH = H.WalkSpeed, H.JumpHeight
			T.Eq(KnockOut(Rig), true, "started")
			T.True(Finished(3), "ended")
			T.Eq(Result(), "Knockout:ok")
			T.Near(H.WalkSpeed, 6, 1e-3, "still crouching: the crouch's walk (6)")
			T.Near(H.JumpHeight, 0, 1e-3, "still crouching: no jump")
			Kit.Crouch(false)
			task.wait(0.1)
			T.Near(H.WalkSpeed, WS, 1e-3, "stood up: the walk from before the takedown")
			T.Near(H.JumpHeight, JH, 1e-3, "stood up: the jump from before")
		end)
	end,
	-- F6 (review M5). A rig that is itself gripping or carrying someone is refused ("target_busy"), nothing marked.
	BusyRigRefused = function(T)
		Kit.Guard(function()
			for I, Attr in ipairs({"Gripping", "Carrying"}) do
				Service().Forget(Player)
				local Rig = Kit.Spawn("Grunt", At(30 * (I - 1), 0))
				Kit.PutBehind(Rig, 3)
				Calm()
				Rig:SetAttribute(Attr, "Takedown_TestBody")
				Kit.Refused(T, Rig, "target_busy", Attr)
			end
		end)
	end,
	-- F7 (review M6). A gripper removed mid-grip (its Parent nil) leaves no lock entry behind.
	GripperRemovedUnlocks = function(T)
		Kit.Guard(function()
			Kit.PutPlayer(AWAY)
			local Body = KnockedAt(0, 0)
			local Gripper = Kit.Spawn("Grunt", At(0, -4))
			local Done = nil
			task.spawn(function() Done = DM.Grip(Gripper, Body) end)
			T.True(WaitFor(1, function() return Gripper:GetAttribute("Gripping") ~= nil end), "setup: gripping")
			T.True(DM.IsLocked ~= nil and DM.IsLocked(Gripper), "setup: the gripper is locked")
			Gripper.Parent = nil
			T.True(WaitFor(1, function() return Done ~= nil end), "the grip ended")
			T.Eq(Done, false, "unfinished")
			T.Eq(DM.IsLocked(Gripper), false, "the removed gripper's lock is forgotten")
			SmokeKit.RemoveEnemy(Gripper)
			Gripper:Destroy()
		end)
	end,
	-- F8 (review I3, test side). Kit.Guard refuses to run a case while the hook's save snapshot isn't armed
	-- (ServerStorage.LMSnapTaken); the control, armed, runs.
	GuardNeedsSnapshot = function(T)
		local Was = ServerStorage:GetAttribute("LMSnapTaken")
		T.True(Was ~= nil, "setup: the hook's snapshot is armed for this run")
		local Ran = false
		ServerStorage:SetAttribute("LMSnapTaken", nil)
		local Ok, Err = pcall(Kit.Guard, function() Ran = true end)
		ServerStorage:SetAttribute("LMSnapTaken", Was)
		T.Eq(Ok, false, "refused without the snapshot")
		T.Eq(Ran, false, "the case never ran")
		T.True(tostring(Err):find("snapshot", 1, true) ~= nil, "it says why: " .. tostring(Err))
		Ran = false
		Kit.Guard(function() Ran = true end)
		T.Eq(Ran, true, "control: armed, the case runs")
	end,
}

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
local DM = require(game.ReplicatedStorage.Modules.Managers.DownedManager)
local ServerStorage = game:GetService("ServerStorage")
local SSS = game:GetService("ServerScriptService")
local TK = require(script.Parent.TakedownKit)
local SmokeKit = require(script.Parent.SmokeKit) -- RemoveEnemy: a refused case's rig goes before its control
local HK = require(script.Parent.HostageKit)
local Player = TK.Player()
local C = Player.Character

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

	-- ===== Task 6: the led pair policed (R1) =====
	-- the captor's root moved 8 studs in one step (well over 2.05 a tick): put back within 1 stud of where it was within
	-- 0.3 s, counted, and the hold is still on
	LeadClamped = function(T)
		HK.Guard(function()
			local _, _, S = Led(T)
			local P0 = CRoot().Position
			CRoot().CFrame += CRoot().CFrame.LookVector * 8
			local Back = WaitFor(0.3, function() return Ground(CRoot().Position, P0) <= 1 and Clamped() >= 1 end)
			T.True(Back, "put back within 0.3 s")
			T.True(Ground(CRoot().Position, P0) <= 1, "within 1 stud of where it was (" .. F2(Ground(CRoot().Position, P0)) .. ")")
			T.True(Clamped() >= 1, "HostageClamped counted (" .. Clamped() .. ")")
			T.True(On(S), "the hold is still on (" .. tostring(HK.Result()) .. ")")
		end)
	end,

	-- the captor's root moved 60 studs (over TeleportBreak 40): the hold ends "teleport"; the stand-in is free where the
	-- move left it (1.5 studs in front of the moved root), not dragged back
	TeleportEnds = function(T)
		HK.Guard(function()
			local Rig = Led(T)
			local P0 = CRoot().Position
			local To = CRoot().CFrame + Vector3.new(60, 0, 0)
			CRoot().CFrame = To
			T.True(Ended("Bind:teleport", 0.5), "\"teleport\" within 0.5 s (" .. tostring(HK.Result()) .. ")")
			T.Eq(Rig:GetAttribute("HeldBy"), nil, "the stand-in is free")
			T.Eq(CRoot():FindFirstChild("DownedWeld"), nil, "no weld on the player's root")
			local HR = Rig.HumanoidRootPart.Position
			T.True(Ground(HR, (To * OFFSET).Position) <= 3, "the stand-in is where the move left it ("
				.. F2(Ground(HR, (To * OFFSET).Position)) .. " studs off)")
			T.True(Ground(HR, P0) > 50, "not dragged back (" .. F2(Ground(HR, P0)) .. " studs from the old spot)")
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
}

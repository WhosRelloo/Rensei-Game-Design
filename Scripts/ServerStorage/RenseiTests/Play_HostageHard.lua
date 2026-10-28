-- Play_HostageHard (hostages plan Task 4, 2026-10-27; Tasks 6 and 10 extend it): the hard edges of a hostage hold. Run
-- in the game VM (LMRunSuite), every case inside HostageKit.Guard (the hook's snapshot armed AND DataManager.IsNoSave(),
-- pre-flight P16) with rigs it spawned itself (TakedownKit's kit Grunts) on TakedownKit's floor.
-- * Task 4: grips, carries and takedowns refuse a captor (Holding) or a hostage (HeldBy), both ways; a bound player
--   doesn't crawl; the knock's timer waits for a bind; DownedManager.EndKnock ends a knock without Recover's heal; and
--   (PvE stays PvE) no takedown ever accepts a player. Nothing sets Holding or HeldBy yet (HostageService, Task 5): the
--   cases set them by hand, "X" standing for the other party's name. Every expected number is written by hand.
local DM = require(game.ReplicatedStorage.Modules.Managers.DownedManager)
local ServerStorage = game:GetService("ServerStorage")
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
}

-- HostageKit (hostages plan Task 4, 2026-10-27; pre-flight P16; Task 5 extends it): the hostage suites' shared fixture.
-- Required, never copied. Run in the game VM (LMRunSuite), never in Edit. It builds on TakedownKit (its floor, Guard,
-- Spawn, Deed and the cases' helpers), required, never re-implemented.
--   * Kit.Guard(Body): every hostage case runs inside it. It REFUSES, with an error and before anything runs or mutates,
--     unless all hold:
--       - the hook's save snapshot is armed for the test player (TakedownKit.SnapshotArmed: LMTestHook installed and
--         ServerStorage.LMSnapTaken = their name), so the hook's restore takes back whatever a case credits or records;
--       - DataManager.IsNoSave() is true, asked here in the game VM (never the ReplicatedStorage attribute): the session
--         loaded a mock copy of the profile (the Studio-only TestNoSave switch), so nothing a case does reaches the save;
--       - Kit._NoSave() is true as well (Task 5, controller ruling: the swappable seam can only make Guard stricter; a
--         test that swaps it to true can't pass a session that isn't TestNoSave).
--     Then TakedownKit.Guard (the y 3000 floor, the clean-up, the character put back) around Body, with first:
--       - (pre-flight P3) today's count of the eight hostage deeds and executed_bandit reset (TakedownKit.Deed), so a
--         deed's daily cap never decides a case;
--       - (Task 5, pre-flight P1 / P2) the player's Data.Level set to 20 and Data.Stats.Strength to 5 on the mock profile
--         (IsNoSave asserted above; the hook restores the save, and Kit.Clean puts both back), then
--         ProgressionService.Sync, so the level gates pass against a default stand-in whatever the owner's real level.
--     Afterwards (even when Body failed): Kit.Clean, then the player's Holding / HeldBy cleared, a knock a case left on
--     the player ended (DownedManager.Recover), and the player's Health, KnockedTime, SecondWindUsed and SecondWindActive
--     (Task 9 fix round 1, review m7: and CombatMode, InCombat, CombatBy, CombatUntil and LastHitAt) put back as they
--     were; each step in its own pcall. Re-raises Body's error.
--   * Kit._NoSave: the function Guard asks besides DataManager.IsNoSave itself. A test swaps it (and puts it back) to
--     prove the refusal, so the data layer itself is never touched (as pre-flight P24 rules for HostageService).
--   * (Task 5) Kit.StandIn(At, Opts) -> Rig, PL: a stand-in player (the stand-in seam, HostageService.StandIn): a clone
--     of StarterPlayer.StarterCharacter named "HostageStandIn<n>" in workspace.World.Live, standing at At (a CFrame on
--     the floor: where and which way it faces; its root 3 studs above), its root anchored for 0.2 s to settle, then
--     free; an Animator; a WCS character; Knockable and a full Stamina (pre-flight P4); registered with UserId
--     -(1000 + n), Level Opts.Level or 20, Money Opts.Money or 1000, Stats {Strength = Opts.Strength or 5} (P1) and
--     Party Opts.Party. Only inside Guard; Kit.Clean removes it.
--   * Kit.KnockPlayer(): the player knocked (DownedManager.Knock) with a 60 s knock (KnockedTime 60, SecondWindUsed),
--     which Guard puts back.
--   * Kit.Result(Character): LastHostageResult on that character (default: the player's).
--   * (Task 6) Kit.Held(Opts) -> Rig, PL, S: the player as the captor of a stand-in (Kit.StandIn(At(0, 0), Opts),
--     knocked), the player at Kit.FRONT (3 studs in front of it, facing it; TakedownKit.PutPlayer anchors the root), the
--     take started and Held within 2 s, else an error. Kit.Loose(): the player's root let go (PutPlayer anchors it), as
--     in a real game, with 0.3 s to settle (Play_TakedownHard's own Loose, for the hostage suites and client checks).
--   * (Task 7) Kit.Grabbed(Opts) -> Rig, PL, S: a standing stand-in (Kit.StandIn(At(0, 0), Opts)) grabbed by the player
--     from 3 studs straight behind it (TakedownKit.PutBehind), the session Grabbing, else an error.
--   * (Task 10; Play_Hostage's Captive since Task 7, moved here so Play_HostageHard shares it) Kit.Captive(Opts) -> Cap,
--     CapPL, S: the real player as the HOSTAGE: knocked at the kit's spot (PutPlayer anchors the root), a stand-in captor
--     (Kit.StandIn(At(0, 3), Opts), facing -Z: the player 3 studs in front of it) binds them, Held within 2 s, else an
--     error. The stand-in's root is anchored once the take has started (a rig just let go still settles, up to 0.85
--     studs measured, near the bind's 1-stud slack).
--   * (Task 10) Kit.Toasts(Body) -> {text}: the "Toast" texts UIService.Notify sends while Body runs (the real Notify
--     still runs; put back after, even when Body fails, and Body's error re-raised).
--   * Kit.Clean(): (Task 8 fix round 1) every release window dropped unpaid (HostageService._ClearPending); every
--     session of the player and of each stand-in freed with "error"; HostageService.ClearStandIns;
--     every stand-in's WCS character and rig destroyed; the player recovered if knocked; Holding, HeldBy, HostageUntil,
--     Struggle, GrabImmuneUntil, LastHostageResult and HostageClamped cleared on the player; HostageService.Forget for
--     the player and every stand-in (cooldown, immunity and re-take times). (Guard, after it, puts back the player's
--     Health, knock attributes, Data.Level and Data.Stats.Strength.)
local SSS = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DownedManager = require(ReplicatedStorage.Modules.Managers.DownedManager)
local WCS = require(ReplicatedStorage.Modules.Framework.WCS)
local DataManager = require(SSS:WaitForChild("CharacterHandler"):WaitForChild("DataManager"))
local TakedownKit = require(script.Parent.TakedownKit)

local Kit = {}

Kit._NoSave = DataManager.IsNoSave

-- the eight hostage deeds (Rensei.Deeds, hostages Task 2) and the grip's executed_bandit (pre-flight P3), written by hand
Kit.DEEDS = {"took_hostage", "attempted_hostage", "released_hostage", "killed_hostage", "used_human_shield",
	"paid_ransom", "took_ransom", "turned_in_fugitive", "executed_bandit"}

-- the player's knock attributes a case may set, and (hostages Task 9 fix round 1, review m7) the combat marks a landed
-- hit leaves on them (WorldService's CombatMode / InCombat / CombatBy / CombatUntil, DamageManager's LastHitAt)
local PUT_BACK = {"KnockedTime", "SecondWindUsed", "SecondWindActive", "CombatMode", "InCombat", "CombatBy", "CombatUntil",
	"LastHitAt"}
-- the hostage attributes cleared on the player after every case
local CLEARED = {"Holding", "HeldBy", "HostageUntil", "Struggle", "GrabImmuneUntil", "LastHostageResult", "HostageClamped"}
local LEVEL, STRENGTH = 20, 5 -- written by hand (P1 / P2): the default stand-in's level and both sides' Strength

local Made = {} -- {Rig, PL, WC} the stand-ins made, until Clean
local Count = 0 -- stand-ins made by this kit (names and UserIds)
local Was = nil -- what Guard changed on the player's profile, while a Guard runs: {Level, Strength}

local function HS()
	local M = SSS:FindFirstChild("HostageService")
	assert(M, "HostageService exists")
	return require(M)
end
local function Player() return TakedownKit.Player() end
local function Progression() return require(SSS.ProgressionService) end

function Kit.Guard(Body)
	if not TakedownKit.SnapshotArmed() then
		error("HostageKit.Guard: the hook's save snapshot isn't armed (ServerStorage.LMSnapTaken, LMTestHook); "
			.. "refusing a case that can credit or record on the profile", 0)
	end
	local DmOk, DmNoSave = pcall(DataManager.IsNoSave)
	local Ok, NoSave = pcall(Kit._NoSave)
	if not (DmOk and DmNoSave == true and Ok and NoSave == true) then
		error("HostageKit.Guard: DataManager.IsNoSave() isn't true in this VM (" .. tostring(DmNoSave) .. ", seam "
			.. tostring(NoSave) .. "); refusing a case outside a TestNoSave session", 0)
	end
	TakedownKit.Guard(function()
		local C = Player().Character
		local H = C:FindFirstChildOfClass("Humanoid")
		local Saved = {Health = H.Health}
		for _, K in ipairs(PUT_BACK) do Saved[K] = C:GetAttribute(K) end
		for _, Id in ipairs(Kit.DEEDS) do TakedownKit.Deed(Id) end
		-- (P1 / P2) the mock profile's level and Strength pinned for the case (IsNoSave asserted above)
		local D = Progression().GetData(Player())
		assert(D and D.Stats, "HostageKit.Guard: the player's profile is loaded")
		Was = {Level = D.Level, Strength = D.Stats.Strength}
		D.Level, D.Stats.Strength = LEVEL, STRENGTH
		Progression().Sync(Player())
		local BodyOk, Err = pcall(Body)
		-- the hostage clean-up, each step on its own so one failing never skips the rest
		local Steps = {
			Kit.Clean,
			function() C:SetAttribute("Holding", nil) C:SetAttribute("HeldBy", nil) end,
			function() if DownedManager.IsKnocked(C) then DownedManager.Recover(C) end end,
			function()
				for _, K in ipairs(PUT_BACK) do C:SetAttribute(K, Saved[K]) end
				if H.Parent and H.Health > 0 then H.Health = Saved.Health end
			end,
			function()
				if Was then
					local Data = Progression().GetData(Player())
					Data.Level, Data.Stats.Strength = Was.Level, Was.Strength
					Progression().Sync(Player())
				end
				Was = nil
			end,
		}
		for _, Step in ipairs(Steps) do
			local StepOk, StepErr = pcall(Step)
			if not StepOk then warn("HostageKit.Guard clean-up:", StepErr) end
		end
		if not BodyOk then error(Err, 0) end
	end)
end

function Kit.StandIn(At, Opts)
	Opts = Opts or {}
	assert(Was ~= nil, "HostageKit.StandIn runs inside Guard (its floor and its clean-up)")
	Count += 1
	local Rig = game:GetService("StarterPlayer").StarterCharacter:Clone()
	Rig.Name = "HostageStandIn" .. Count
	local H = Rig:FindFirstChildOfClass("Humanoid")
	if not H:FindFirstChildOfClass("Animator") then Instance.new("Animator").Parent = H end
	local Root = Rig.HumanoidRootPart
	Root.Anchored = true
	Rig.Parent = workspace.World.Live
	Rig:PivotTo(At + Vector3.new(0, 3, 0)) -- (the root 3 studs above the floor, as TakedownKit.Spawn's rigs stand)
	local Entry = {Rig = Rig}
	table.insert(Made, Entry)
	Entry.WC = WCS.Character.new(Rig)
	Rig:SetAttribute("Knockable", true) -- (P4, spec §9: a Knockable rig)
	local RM = require(ReplicatedStorage.Modules.Managers.ResourceManager)
	RM.Set(Rig, "Stamina", RM.Max(Rig, "Stamina"))
	task.wait(0.2)
	Root.Anchored = false
	local PL, Why = HS().StandIn(Rig, {Name = Rig.Name, UserId = -(1000 + Count), Level = Opts.Level or LEVEL,
		Money = Opts.Money or 1000, Stats = {Strength = Opts.Strength or STRENGTH}, Party = Opts.Party})
	assert(PL, "HostageKit.StandIn: the seam refused the rig (" .. tostring(Why) .. ")")
	Entry.PL = PL
	return Rig, PL
end

function Kit.KnockPlayer()
	local C = Player().Character
	C:SetAttribute("KnockedTime", 60)
	C:SetAttribute("SecondWindUsed", true)
	DownedManager.Knock(C)
	return DownedManager.IsKnocked(C)
end

function Kit.Result(Character)
	return (Character or Player().Character):GetAttribute("LastHostageResult")
end

-- (Task 6) the player 3 studs in front of the kit's spot, facing it (-Z)
Kit.FRONT = TakedownKit.At(0, 3) + Vector3.new(0, 3, 0)

function Kit.Held(Opts)
	local Rig, PL = Kit.StandIn(TakedownKit.At(0, 0), Opts)
	DownedManager.Knock(Rig)
	TakedownKit.PutPlayer(Kit.FRONT)
	assert(DownedManager.IsKnocked(Rig), "HostageKit.Held: the stand-in is knocked")
	local Ok, Why = HS().Take(Player(), Rig)
	assert(Ok, "HostageKit.Held: the take starts (" .. tostring(Why) .. ")")
	local Held = TakedownKit.WaitFor(2.0, function()
		local S = HS().SessionOf(Player())
		return S ~= nil and S.State == "Held"
	end)
	assert(Held, "HostageKit.Held: Held within 2 s (" .. tostring(Kit.Result()) .. ")")
	return Rig, PL, HS().SessionOf(Player())
end

-- (Task 7) the player grabs a standing stand-in from behind: Kit.StandIn(At(0, 0), Opts) (facing -Z), the player 3
-- studs straight behind it (TakedownKit.PutBehind), the take started and Grabbing, else an error
function Kit.Grabbed(Opts)
	local Rig, PL = Kit.StandIn(TakedownKit.At(0, 0), Opts)
	TakedownKit.PutBehind(Rig, 3)
	local Ok, Why = HS().Take(Player(), Rig)
	assert(Ok, "HostageKit.Grabbed: the grab starts (" .. tostring(Why) .. ")")
	local S = HS().SessionOf(Player())
	assert(S ~= nil and S.State == "Grabbing", "HostageKit.Grabbed: Grabbing (" .. tostring(S and S.State) .. ")")
	return Rig, PL, S
end

function Kit.Captive(Opts)
	local Cap, CapPL = Kit.StandIn(TakedownKit.At(0, 3), Opts)
	TakedownKit.PutPlayer(TakedownKit.At(0, 0) + Vector3.new(0, 3, 0))
	assert(Kit.KnockPlayer(), "HostageKit.Captive: the player is knocked")
	local Ok, Why = HS().Take(CapPL, Player().Character)
	Cap.HumanoidRootPart.Anchored = true
	assert(Ok, "HostageKit.Captive: the stand-in's take starts (" .. tostring(Why) .. ")")
	local Held = TakedownKit.WaitFor(2.0, function()
		local S = HS().SessionOf(Player())
		return S ~= nil and S.State == "Held"
	end)
	assert(Held, "HostageKit.Captive: Held within 2 s (" .. tostring(Kit.Result(Cap)) .. ")")
	return Cap, CapPL, HS().SessionOf(Player())
end

function Kit.Toasts(Body)
	local US = require(SSS.UIService)
	local Real = US.Notify
	local Got = {}
	US.Notify = function(P, Kind, Data)
		if Kind == "Toast" and type(Data) == "table" then table.insert(Got, Data.Text) end
		return Real(P, Kind, Data)
	end
	local Ok, Err = pcall(Body)
	US.Notify = Real
	if not Ok then error(Err, 0) end
	return Got
end

function Kit.Loose()
	local Root = Player().Character.HumanoidRootPart
	Root.Anchored = false
	Root.AssemblyLinearVelocity = Vector3.zero
	task.wait(0.3)
end

function Kit.Clean()
	local Found, Service = pcall(HS)
	local P = Player()
	if not Found then
		-- (no service: nothing of its to free) the rigs and the player's attributes still go
		Service = {Free = function() end, Forget = function() end, ClearStandIns = function() end}
	end
	local Steps = {
		-- (hostages Task 8 fix round 1) every release window dropped unpaid, so none pays out into a later case
		function() if Service._ClearPending then Service._ClearPending() end end,
		function() Service.Free(P, "error") end,
		function() for _, E in ipairs(Made) do if E.PL then Service.Free(E.PL, "error") end end end,
		function() for _, E in ipairs(Made) do if E.PL then Service.Forget(E.PL) end end end,
		Service.ClearStandIns,
		function()
			for _, E in ipairs(Made) do
				if E.WC then pcall(function() E.WC:Destroy() end) end
				E.Rig:Destroy()
			end
			table.clear(Made)
		end,
		function()
			local C = P.Character
			if DownedManager.IsKnocked(C) then DownedManager.Recover(C) end
			for _, K in ipairs(CLEARED) do C:SetAttribute(K, nil) end
		end,
		function() Service.Forget(P) end,
	}
	for _, Step in ipairs(Steps) do
		local Ok, Err = pcall(Step)
		if not Ok then warn("HostageKit.Clean:", Err) end
	end
end

return Kit
